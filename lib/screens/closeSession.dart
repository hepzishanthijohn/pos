// file: close_session_dialog.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // For FilteringTextInputFormatter
import 'package:intl/intl.dart';

import 'package:rcspos/localdb/orders_sqlite_helper.dart'; // Import your helper
import 'package:rcspos/localdb/posconfigsqlitehelper.dart';
import 'package:rcspos/screens/posconfigpage.dart'; // Import POSConfigPage

class CloseSessionDialog extends StatefulWidget {
final bool sessionState; 
  final int posId; // Add POS ID to identify the specific POS config


  const CloseSessionDialog({
    super.key,
    required this.sessionState,
    required this.posId, // Add POS ID to identify the specific POS config
  });

  @override
  State<CloseSessionDialog> createState() => _CloseSessionDialogState();
}

class _CloseSessionDialogState extends State<CloseSessionDialog> {
  final TextEditingController _countedCashController = TextEditingController();
  final TextEditingController _closingNotesController = TextEditingController();

  double _expectedTotalOrdersAmount = 0.0;
  double _expectedCash = 0.0;
  double _expectedBank = 0.0;
  double _expectedCard = 0.0;
  int _todaysOrderCount = 0;

  double _countedCash = 0.0;
  double _difference = 0.0;

  final NumberFormat _currencyFormat = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹ ',
    decimalDigits: 2,
  );

  @override
  void initState() {
    super.initState();
    _countedCashController.text = '0.00';
    _fetchTodaysExpectedTotals();
    _countedCashController.addListener(_updateDifference);
  }

  @override
  void dispose() {
    _countedCashController.removeListener(_updateDifference);
    _countedCashController.dispose();
    _closingNotesController.dispose();
    super.dispose();
  }

  Future<void> _fetchTodaysExpectedTotals() async {
    final totals = await OrderSQLiteHelper().getTodaysPaymentMethodTotals();

    setState(() {
      _expectedCash = totals['cash'] ?? 0.0;
      _expectedBank = totals['bank'] ?? 0.0;
      _expectedCard = totals['card'] ?? 0.0;
      _expectedTotalOrdersAmount = totals['totalOrdersAmount'] ?? 0.0;
      _todaysOrderCount = totals['totalOrdersCount'] ?? 0;

      _updateDifference();
    });
  }

  void _updateDifference() {
    final countedValue = double.tryParse(_countedCashController.text) ?? 0.0;
    setState(() {
      _countedCash = countedValue;
      _difference = countedValue - _expectedCash;
    });
  }

void _submitSessionClose() async {
  final double finalCountedCash = double.tryParse(_countedCashController.text) ?? 0.0;
  final String closingNotes = _closingNotesController.text;

  print("Closing Session Details:");
  print("Total Orders Today: $_todaysOrderCount orders, Total Amount: ${_currencyFormat.format(_expectedTotalOrdersAmount)}");
  print("Expected Cash: ${_currencyFormat.format(_expectedCash)}");
  print("Expected Bank: ${_currencyFormat.format(_expectedBank)}");
  print("Expected Card: ${_currencyFormat.format(_expectedCard)}");
  print("Counted Cash: ${_currencyFormat.format(finalCountedCash)}");
  print("Difference: ${_currencyFormat.format(_difference)}");
  print("Closing Notes: $closingNotes");

  // Update session state to 0 (closed) for this posId
  await posConfigSQLiteHelper.instance.updateSessionState(widget.posId, 0);

  // Optionally, update last closing cash and date (add this method in your SQLite helper if needed)
  // await POSConfigSQLiteHelper.instance.updateClosingCashAndDate(widget.posId, finalCountedCash, DateTime.now());

  // Close the dialog and return true to indicate success
  Navigator.of(context).pop(true);
}

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final dialogWidth = screenWidth * 0.5;

    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: dialogWidth < 600 ? 600 : dialogWidth),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title Section
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Closing Session',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Total $_todaysOrderCount orders: ${_currencyFormat.format(_expectedTotalOrdersAmount)}',
                    style: TextStyle(
                      fontSize: 17,
                      color: Colors.grey[700],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const Divider(height: 28, thickness: 1, color: Color(0xFFE0E0E0)),
                ],
              ),
              // Content Section (Payment Details and Notes)
              SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Payment Method Header
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12.0),
                      child: Row(
                        children: [
                          const Expanded(
                            flex: 4,
                            child: Text(
                              'Payment Method',
                              style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF616161)),
                            ),
                          ),
                          const Expanded(
                            flex: 3,
                            child: Text(
                              'Expected',
                              style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF616161)),
                              textAlign: TextAlign.right,
                            ),
                          ),
                          const Expanded(
                            flex: 4,
                            child: Text(
                              'Counted',
                              style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF616161)),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          const Expanded(
                            flex: 3,
                            child: Text(
                              'Difference',
                              style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF616161)),
                              textAlign: TextAlign.right,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Cash Row
                    _buildPaymentRow(
                      paymentMethod: 'Cash',
                      expectedAmount: _expectedCash,
                      isCash: true,
                    ),
                    // Sub-rows for Cash details
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0, left: 32.0, bottom: 12.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Opening: ${_currencyFormat.format(0.00)}',
                            style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                          ),
                          Text(
                            '+ Payments in Cash: ${_currencyFormat.format(_expectedCash)}',
                            style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    ),
                    // Bank Row
                    _buildPaymentRow(
                      paymentMethod: 'Bank',
                      expectedAmount: _expectedBank,
                      isCash: false,
                    ),
                    // Customer Account Row
                    _buildPaymentRow(
                      paymentMethod: 'Customer Account',
                      expectedAmount: _expectedCard,
                      isCash: false,
                    ),
                    const SizedBox(height: 5),
                    // Closing Note
                    const Text(
                      'Closing note',
                      style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF616161)),
                    ),
                    const SizedBox(height: 5),
                    TextField(
                      controller: _closingNotesController,
                      maxLines: 3,
                      decoration: InputDecoration(
                        hintText: 'Add a closing note...',
                        hintStyle: TextStyle(color: Colors.grey[500]),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Colors.grey[400]!),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Colors.grey[400]!),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: Color(0xFF7257A0), width: 2),
                        ),
                        contentPadding: const EdgeInsets.all(12),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 5),
              // Action Buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(), // Pop without returning true
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.grey[700],
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text('Discard', style: TextStyle(fontSize: 16)),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: _submitSessionClose,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color.fromARGB(255, 114, 87, 160),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                      elevation: 3,
                    ),
                    child: const Text('Close Session', style: TextStyle(fontSize: 16)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPaymentRow({
    required String paymentMethod,
    required double expectedAmount,
    required bool isCash, // true for Cash, false for Bank/Customer Account
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            flex: 4,
            child: Text(
              paymentMethod,
              style: const TextStyle(fontSize: 16),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              _currencyFormat.format(expectedAmount),
              style: const TextStyle(fontSize: 16),
              textAlign: TextAlign.right,
            ),
          ),
          Expanded(
            flex: 4,
            child: SizedBox(
              height: 28, // Consistent height for all rows
              child: isCash
                  ? TextField(
                      controller: _countedCashController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                      ],
                      textAlign: TextAlign.right,
                      style: const TextStyle(fontSize: 16),
                      decoration: InputDecoration(
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(4),
                          borderSide: BorderSide(color: Colors.grey[400]!),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(4),
                          borderSide: BorderSide(color: Colors.grey[400]!),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(4),
                          borderSide: const BorderSide(color: Color(0xFF7257A0), width: 1.5),
                        ),
                        prefixIcon: const Icon(Icons.money, size: 20, color: Colors.grey),
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.calculate_outlined, size: 20, color: Colors.grey),
                          onPressed: () {
                            // Implement numpad or calculator if needed
                          },
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ),
                    )
                  : const SizedBox.shrink(), // Leave this space empty for non-cash 'counted'
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              isCash ? _currencyFormat.format(_difference) : '', // Show difference for cash, empty string for others
              style: TextStyle(
                fontSize: 16,
                color: isCash
                    ? (_difference == 0 ? Colors.black : (_difference > 0 ? Colors.green[700] : Colors.red[700]))
                    : Colors.black, // Color doesn't matter much for empty string, but keep black
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}