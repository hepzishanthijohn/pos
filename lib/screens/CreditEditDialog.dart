import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;
import 'package:rcspos/utils/urls.dart';
import 'package:rcspos/components/snackbar_helper.dart'; // Assuming you have this for custom snackbars

class CreditApproveDialog extends StatefulWidget {
  final int requestId;
  final String creditCustomerName;
  final double currentAmount;
  final int currentDays;
  final String status;
  final String? reason;

  const CreditApproveDialog({
    Key? key,
    required this.requestId,
    required this.currentAmount,
    required this.creditCustomerName,
    required this.currentDays,
    required this.status,
    this.reason,
  }) : super(key: key);

  @override
  State<CreditApproveDialog> createState() => _CreditApproveDialogState();
}

class _CreditApproveDialogState extends State<CreditApproveDialog> {
  late TextEditingController approvedAmountController;
  late TextEditingController approvedDaysController;

  bool isLoading = false;
  bool _canApprove = false;

  @override
  void initState() {
    super.initState();
    approvedAmountController = TextEditingController(text: widget.currentAmount.toStringAsFixed(2));
    approvedDaysController = TextEditingController(text: widget.currentDays.toString());

    // Changed _canApprove logic to include 'has_credit_request' as a state that can be approved
    _canApprove = widget.status.toLowerCase() == 'pending' ||
                  widget.status.toLowerCase() == 'new' ||
                  widget.status.toLowerCase() == 'has_credit_request';

    if (_canApprove) {
      // Ensure cursor is at the end for editable fields
      approvedAmountController.selection = TextSelection.fromPosition(TextPosition(offset: approvedAmountController.text.length));
      approvedDaysController.selection = TextSelection.fromPosition(TextPosition(offset: approvedDaysController.text.length));
    }
  }

  @override
  void dispose() {
    approvedAmountController.dispose();
    approvedDaysController.dispose();
    super.dispose();
  }

  Future<void> _confirmAndApprove() async {
    if (!_canApprove) {
      _showError("This credit request cannot be approved as it's already in '${widget.status}' status.");
      return;
    }

    final double? amount = double.tryParse(approvedAmountController.text);
    final int? days = int.tryParse(approvedDaysController.text);

    if (amount == null || days == null || amount < 0 || days < 0) {
      _showError("Please enter valid positive numbers for Approved Amount and Days.");
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Confirm Approval", style: TextStyle(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Are you sure you want to approve this credit request with the following limits?", style: TextStyle(fontSize: 16)),
            const SizedBox(height: 15),
            _buildConfirmationRow("Max Credit Amount:", "₹${amount.toStringAsFixed(2)}", Colors.green),
            _buildConfirmationRow("Max Credit Days:", "$days days", Colors.blue),
          ],
        ),
        actions: [
          TextButton(
            child: const Text("Cancel"),
            onPressed: () => Navigator.of(context).pop(false),
          ),
          ElevatedButton(
            child: const Text("Yes, Approve"),
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF185A9D), foregroundColor: Colors.white),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _approveCreditRequest(amount, days);
    }
  }

  Widget _buildConfirmationRow(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
          Text(value, style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 16)),
        ],
      ),
    );
  }

  Future<void> _approveCreditRequest(double amount, int days) async {
    setState(() => isLoading = true);

    try {
      final box = await Hive.openBox('login');
      final rawSession = box.get('session_id')?.toString().trim();
      if (rawSession == null || rawSession.isEmpty) {
        _showError("Session ID not found. Please log in again.");
        setState(() => isLoading = false);
        return;
      }

      final sessionId = rawSession.startsWith("session_id=") ? rawSession : "session_id=$rawSession";

      final url = Uri.parse("$baseurl/mobile/update_credit_request");

      final body = jsonEncode({
        "request_id": widget.requestId,
        "max_credit_amount": amount,
        "max_credit_days": days,
      });

      final response = await http.put(
        url,
        headers: {
          HttpHeaders.contentTypeHeader: "application/json",
          HttpHeaders.cookieHeader: sessionId,
        },
        body: body,
      );

      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);
        if (decoded['success'] == true) {
          // This pops the dialog and sends 'true' to the caller (CreditCustomersPage)
          if (mounted) {
            Navigator.of(context).pop(true);
          }
          // The snackbar is shown after the dialog closes.
          showCustomSnackBar(
            context: context,
            title: 'Success',
            message: 'Credit request approved and updated successfully!',
            backgroundColor: Colors.green,
          );
        } else {
          _showError(decoded['message'] ?? "Failed to approve credit request.");
        }
      } else {
        final error = json.decode(response.body);
        _showError(error['message'] ?? "Failed to approve credit request due to server error (Status: ${response.statusCode}).");
      }
    } on SocketException {
      _showError("No internet connection. Please check your network.");
    } catch (e) {
      _showError("An unexpected error occurred during approval: $e");
    } finally {
      setState(() => isLoading = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.credit_card, color: Color(0xFF185A9D), size: 28),
          SizedBox(width: 10),
          Text(
            "Credit Request Details",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: Color(0xFF185A9D)),
          ),
        ],
      ),
      contentPadding: const EdgeInsets.fromLTRB(24.0, 20.0, 24.0, 0.0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15.0)), // Rounded corners for dialog
      content: isLoading
          ? const SizedBox(
              height: 180, // Increased height for loading to avoid jumpiness
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(
                      color: Color(0xFF185A9D),
                      strokeWidth: 4,
                    ),
                    SizedBox(height: 15),
                    Text("Loading details...", style: TextStyle(color: Colors.grey, fontSize: 16)),
                  ],
                ),
              ),
            )
          : SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Request ID for reference
                  // Text(
                  //   'Request ID: ${widget.requestId}',
                  //   style: TextStyle(fontSize: 14, color: Colors.grey[700], fontStyle: FontStyle.italic),
                  // ),
                  const SizedBox(height: 12),

                  // Current Status with enhanced styling
                  Row(
                    children: [
                      // const Text('Status: ', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: _statusColor(widget.status).withOpacity(0.15),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          _formatStatus(widget.status),
                          style: TextStyle(
                            color: _statusColor(widget.status),
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Reason for credit request (if available)
                  if (widget.reason != null && widget.reason!.isNotEmpty)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Reason:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          child: Text(
                            widget.reason!,
                            style: const TextStyle(fontStyle: FontStyle.italic, color: Colors.black87),
                          ),
                        ),
                        const SizedBox(height: 10),
                      ],
                    ),

                  const Divider(height: 30), // Visual separator

                  // Text Fields for Approval
                  Text(
                    _canApprove ? "Set Approval Limits:" : "Current Approved Limits:",
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.black87),
                  ),
                  const SizedBox(height: 15),
                  TextField(
                    controller: approvedAmountController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                        labelText: "Max Credit Amount (₹)",
                        border: const OutlineInputBorder(),
                        enabledBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: _canApprove ? Colors.blue.shade300 : Colors.grey.shade400)),
                        focusedBorder: const OutlineInputBorder(
                            borderSide: BorderSide(color: Color(0xFF185A9D), width: 2)), // Focused color
                        filled: true,
                        fillColor: _canApprove ? Colors.white : Colors.grey.shade100,
                        hintText: _canApprove ? 'Enter amount' : null,
                        prefixIcon: const Icon(Icons.currency_rupee, color: Color(0xFF185A9D))),
                    enabled: _canApprove,
                    readOnly: !_canApprove,
                    style: TextStyle(color: _canApprove ? Colors.black : Colors.grey.shade700, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 15),
                  TextField(
                    controller: approvedDaysController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                        labelText: "Max Credit Days",
                        border: const OutlineInputBorder(),
                        enabledBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: _canApprove ? Colors.blue.shade300 : Colors.grey.shade400)),
                        focusedBorder: const OutlineInputBorder(
                            borderSide: BorderSide(color: Color(0xFF185A9D), width: 2)), // Focused color
                        filled: true,
                        fillColor: _canApprove ? Colors.white : Colors.grey.shade100,
                        hintText: _canApprove ? 'Enter days' : null,
                        prefixIcon: const Icon(Icons.calendar_today, color: Color(0xFF185A9D))),
                    enabled: _canApprove,
                    readOnly: !_canApprove,
                    style: TextStyle(color: _canApprove ? Colors.black : Colors.grey.shade700, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 20),

                  // Message when not approvable (enhanced)
                  if (!_canApprove)
                    Container(
                      padding: const EdgeInsets.all(12.0),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(8.0),
                        border: Border.all(color: Colors.orange.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline, color: Colors.orange.shade700, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              "This request is in '${_formatStatus(widget.status)}' status. "
                              "Approval is only allowed for 'Pending', 'New', or 'Has Credit Request' statuses.",
                              style: TextStyle(color: Colors.orange.shade800, fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 10),
                ],
              ),
            ),
      actionsPadding: const EdgeInsets.all(16.0),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          style: TextButton.styleFrom(
            foregroundColor: Colors.grey.shade700,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          ),
          child: const Text("Cancel"),
        ),
        ElevatedButton.icon(
          onPressed: isLoading || !_canApprove ? null : _confirmAndApprove,
          icon: isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
              : const Icon(Icons.check_circle_outline),
          label: Text(isLoading ? "Approving..." : "Approve Request"),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF185A9D),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            elevation: 3,
            textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }

  // Helper functions for status color and formatting (copied from CreditCustomersPage for self-containment)
  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return const Color.fromARGB(255, 255, 72, 0);
      case 'approved':
        return const Color.fromARGB(255, 7, 155, 12);
      case 'rejected':
        return Colors.red;
      case 'has_credit_request':
      case 'new':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  String _formatStatus(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return 'Pending';
      case 'approved':
        return 'Approved';
      case 'rejected':
        return 'Rejected';
      case 'has_credit_request':
      case 'new':
        return 'New';
      default:
        return status;
    }
  }
}