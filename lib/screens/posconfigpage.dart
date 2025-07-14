// file: posconfigpage.dart

import 'dart:convert';
import 'dart:io'; // For HttpHeaders
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;
import 'package:rcspos/screens/home.dart'; // Make sure this path is correct
import 'package:rcspos/utils/urls.dart'; // Make sure baseurl is correctly defined here

class POSConfigPage extends StatefulWidget {
  const POSConfigPage({super.key});

  @override
  State<POSConfigPage> createState() => _POSConfigPageState();
}

class _POSConfigPageState extends State<POSConfigPage> {
  bool _loading = true;
  List<Map<String, dynamic>> _configs = [];
  String? _errorMessage; // Added for specific error messages

  final String apiUrl =
      '$baseurl/api/pos.config/?query={id,name,shop_addrs,last_session_closing_cash,last_session_closing_date,current_session_state,shop_gst_no,shop_phone_no,shop_owner_id{id,name}}';

  @override
  void initState() {
    super.initState();
    fetchPOSConfigs();
  }

  // --- Helper for Date Formatting ---
  String _formatDate(String value) {
    try {
      final date = DateTime.tryParse(value);
      if (date != null) {
        return '${date.day.toString().padLeft(2, '0')}-${date.month.toString().padLeft(2, '0')}-${date.year}';
      }
    } catch (_) {
      // Handle parsing errors gracefully
    }
    return 'N/A';
  }

  // --- API Call to Fetch POS Configurations ---
  Future<void> fetchPOSConfigs() async {
    setState(() {
      _loading = true;
      _errorMessage = null; // Clear previous errors
    });

    try {
      final box = await Hive.openBox('login');
      final rawSession = box.get('session_id');
      if (rawSession == null) {
        showError('Session ID not found. Please login again.');
        return;
      }
      final sessionId = rawSession.contains('session_id=') ? rawSession : 'session_id=$rawSession';

      final response = await http.get(
        Uri.parse(apiUrl),
        headers: {
          HttpHeaders.cookieHeader: sessionId,
          HttpHeaders.contentTypeHeader: 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List configsRaw = data['result'];

        setState(() {
          _configs = configsRaw.map((e) => Map<String, dynamic>.from(e)).toList();
          _loading = false;
        });
      } else {
        // More specific error message from Odoo if available
        final errorDetail = jsonDecode(response.body)['error']['data']['message'] ?? response.body;
        showError('Failed to fetch POS configs: ${response.statusCode} - $errorDetail');
      }
    } on SocketException {
      showError('Network error. Please check your internet connection.');
    } catch (e) {
      showError('An unexpected error occurred: $e');
      debugPrint('Error fetching POS configs: $e'); // For detailed debugging
    }
  }

  // --- Error Message Handler ---
  void showError(String message) {
    setState(() {
      _loading = false;
      _errorMessage = message; // Store the error message
    });
    // Also show a SnackBar for immediate feedback
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  // --- Status Color and Text Helpers ---
  Color getStatusColor(dynamic status) {
    if (status == 'opened') return Colors.green.shade600; // Slightly darker green
    if (status == false || status == 'closed') return Colors.red.shade600; // Slightly darker red
    return Colors.grey.shade600; // Consistent grey
  }

  String getStatusText(dynamic status) {
    if (status == 'opened') return 'In Progress';
    if (status == false || status == 'closed') return 'Closed';
    return 'Unknown';
  }

  // --- UI Build Method ---
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Point Of Sale',
            style: TextStyle(fontFamily: 'Arial', color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: const Color.fromARGB(255, 1, 139, 82),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      backgroundColor: const Color(0xFFF7F4FB),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null // Show error widget if there's an error
              ? _buildErrorWidget()
              : _configs.isEmpty
                  ? _buildNoConfigsWidget() // Show no configs widget if list is empty
: SingleChildScrollView(
                      padding: const EdgeInsets.all(5),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          int crossAxisCount = 1;
                          // Increase childAspectRatio for mobile and tablets
                          double childAspectRatio = 1.2; // Increased from 1.6
                          if (constraints.maxWidth > 800) {
                            crossAxisCount = 3;
                            childAspectRatio = 1.3; // Can keep as is or adjust if needed
                          } else if (constraints.maxWidth > 600) {
                            crossAxisCount = 2;
                            childAspectRatio = 1.5; // Increased from 1.4
                          }

                          return GridView.count(
                            crossAxisCount: crossAxisCount,
                            crossAxisSpacing: 16,
                            mainAxisSpacing: 18,
                            childAspectRatio: childAspectRatio,
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(), // Prevent GridView from scrolling independently
                            children: _configs.map((config) {
                              // Safely extract data, providing default values
                              final String name = config['name'] ?? 'Unnamed POS';
                              final String address = config['shop_addrs'] ?? 'Not set';
                              final double cash = (config['last_session_closing_cash'] ?? 0.0).toDouble();
                              final String shopGstNo = (config['shop_gst_no'] ?? 'Not set').toString();
                              final String shopPhoneNo = config['shop_phone_no']?.toString() ?? 'Not set';
                              final String shopOwnerName = config['shop_owner_id']?['name'] ?? 'Unknown';
                              final dynamic rawDate = config['last_session_closing_date'];
                              final String date =
                                  (rawDate == false || rawDate == null || rawDate.toString() == 'false')
                                      ? 'N/A'
                                      : _formatDate(rawDate.toString());
                              final sessionState = config['current_session_state'];

                              return _buildPOSConfigCard(
                                name: name,
                                address: address,
                                cash: cash,
                                shopGstNo: shopGstNo,
                                shopPhoneNo: shopPhoneNo,
                                shopOwnerName: shopOwnerName,
                                date: date,
                                sessionState: sessionState,
                              );
                            }).toList(),
                          );
                        },
                      ),
                    ),
   
    );
  }

  // --- Widgets for Error and No Data States ---

  Widget _buildErrorWidget() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, color: Colors.red.shade700, size: 80),
            const SizedBox(height: 20),
            Text(
              _errorMessage ?? 'An unknown error occurred.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey.shade700,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 30),
            ElevatedButton.icon(
              onPressed: fetchPOSConfigs, // Allows user to retry fetching data
              icon: const Icon(Icons.refresh),
              label: const Text('Try Again'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color.fromARGB(255, 1, 139, 82),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoConfigsWidget() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.info_outline, color: Colors.blueGrey.shade400, size: 80),
            const SizedBox(height: 20),
            Text(
              'No POS configurations found.\nPlease check your Odoo setup or try refreshing.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey.shade700,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 30),
            ElevatedButton.icon(
              onPressed: fetchPOSConfigs, // Allows user to refresh list
              icon: const Icon(Icons.refresh),
              label: const Text('Refresh'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color.fromARGB(255, 1, 139, 82),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- Widget for an individual POS Configuration Card ---
  Widget _buildPOSConfigCard({
    required String name,
    required String address,
    required double cash,
    required String shopGstNo,
    required String shopPhoneNo,
    required String shopOwnerName,
    required String date,
    required dynamic sessionState,
  }) {
    return Card(
      elevation: 6, // Increased elevation for a floating effect
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: Colors.grey.shade200),
        ),
        padding: const EdgeInsets.all(18), // Slightly increased padding
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              // mainAxisSize: MainAxisSize.min, // Optional: if content seems too large and causes overflow, uncomment this.
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 20, // Increased font size for name
                    fontWeight: FontWeight.w800, // Make it bolder
                    color: Color.fromARGB(255, 3, 0, 0),
                    fontFamily: 'Arial',
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis, // Prevents overflow of long names
                ),
                const SizedBox(height: 10), // Increased spacing
                _buildInfoText('Shop Incharge: ', shopOwnerName),
                const SizedBox(height: 6),
                _buildInfoText('Phone No: ', shopPhoneNo),
                const SizedBox(height: 6),
                _buildInfoText('Shop Address: ', address),
                const SizedBox(height: 6),
                _buildInfoText('Shop GST No: ', shopGstNo),
                const SizedBox(height: 6),
                _buildInfoText('Last Closing Cash: ', '₹${cash.toStringAsFixed(2)}'),
                const SizedBox(height: 6),
                _buildInfoText('Last Closing Date: ', date),
                // Fix: Removed Spacer() which was causing unbounded height errors in GridView context
                // Instead, a SizedBox is used for consistent spacing before the button.
                const SizedBox(height: 10), 

                Align(
                  alignment: Alignment.bottomRight, // Aligned to bottom-right
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color.fromARGB(255, 1, 139, 82),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 12), // Larger padding
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      elevation: 4, // Added elevation to button
                    ),
                    onPressed: () {
                      // Navigate to the HomePage when "Resume" is pressed
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(builder: (context) => const HomePage()),
                      );
                    },
                    child: const Text('Resume',
                        style: TextStyle(fontFamily: 'Arial', fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
            // Positioned status tag at the top-right corner
            Positioned(
              top: 0,
              right: 0,
              child: Container(
                decoration: BoxDecoration(
                  color: getStatusColor(sessionState),
                  borderRadius: const BorderRadius.only(
                    topRight: Radius.circular(15), // Match card radius
                    bottomLeft: Radius.circular(15), // Match card radius
                  ),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), // Slightly larger padding
                child: Text(
                  getStatusText(sessionState),
                  style: const TextStyle(color: Colors.white, fontSize: 13, fontFamily: 'Arial', fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- Helper for Info Text Rows ---
  Widget _buildInfoText(String label, String value) {
    return RichText(
      text: TextSpan(
        style: const TextStyle(
          fontSize: 15,
          fontFamily: 'Arial',
          fontWeight: FontWeight.w500,
          color: Color.fromARGB(185, 0, 0, 0),
        ),
        children: [
          TextSpan(
            text: label,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold), // Adjusted font size here too
          ),
          TextSpan(text: value),
        ],
      ),
      maxLines: 1, // Crucial: Prevents overflow on small screens
      overflow: TextOverflow.ellipsis, // Shows "..." if text is too long
    );
  }
}