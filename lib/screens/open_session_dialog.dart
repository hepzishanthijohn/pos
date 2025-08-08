// lib/components/open_session_dialog.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // For FilteringTextInputFormatter
import 'package:intl/intl.dart';
import 'package:rcspos/localdb/posconfigsqlitehelper.dart';


class OpenSessionDialog extends StatefulWidget {
  final bool sessionState; 
  final int posId; // Add POS ID to identify the specific POS config

  const OpenSessionDialog({
    super.key,
    required this.posId, // Required POS ID for the specific POS config
    required this.sessionState,
  });

  @override
  State<OpenSessionDialog> createState() => _OpenSessionDialogState();
}

class _OpenSessionDialogState extends State<OpenSessionDialog> {
  final TextEditingController _openingCashController = TextEditingController();
  final TextEditingController _openingNotesController = TextEditingController();

  final NumberFormat _currencyFormat = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹ ',
    decimalDigits: 2,
  );

  @override
  void initState() {
    super.initState();
    _openingCashController.text = '0.00'; // Default opening cash
  }

  @override
  void dispose() {
    _openingCashController.dispose();
    _openingNotesController.dispose();
    super.dispose();
  }

  Future<void> _submitOpeningSession() async {
    final double openingCash = double.tryParse(_openingCashController.text) ?? 0.0;
    final String openingNotes = _openingNotesController.text;

    print("Opening Session Details:");
    print("Opening Cash: ${_currencyFormat.format(openingCash)}");
    print("Opening Notes: $openingNotes");

    await posConfigSQLiteHelper.instance.updateSessionState(widget.posId, 1);

    Navigator.of(context).pop(true); 
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final dialogWidth = screenWidth * 0.4; // Adjust width as needed

    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: dialogWidth < 400 ? 400 : dialogWidth),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Opening Cash Control',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22),
              ),
              const SizedBox(height: 20),
              Text(
                'Opening cash',
                style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF616161)),
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 48,
                child: TextField(
                  controller: _openingCashController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                  ],
                  textAlign: TextAlign.right,
                  style: const TextStyle(fontSize: 18),
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
                    suffixIcon: Row(
                      mainAxisSize: MainAxisSize.min, // Keep suffix icons close
                      children: [
                        IconButton(
                          icon: const Icon(Icons.close, size: 20, color: Colors.grey),
                          onPressed: () {
                            _openingCashController.clear();
                            _openingCashController.text = '0.00';
                          },
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.calculate_outlined, size: 20, color: Colors.grey),
                          onPressed: () {
                            // Implement numpad or calculator if needed
                          },
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                        const SizedBox(width: 8), // Add some spacing after the icon
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Opening note',
                style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF616161)),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _openingNotesController,
                maxLines: 4,
                decoration: InputDecoration(
                  hintText: 'Add an opening note...',
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
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.grey[700],
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text('Cancel', style: TextStyle(fontSize: 16)),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: _submitOpeningSession,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color.fromARGB(255, 114, 87, 160),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                      elevation: 3,
                    ),
                    child: const Text('Open Session', style: TextStyle(fontSize: 16)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}