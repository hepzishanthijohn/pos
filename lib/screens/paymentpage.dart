// file: payment_page.dart

import 'package:flutter/material.dart';
import 'package:rcspos/screens/paymentsuccesspage.dart';

// ------------------ PAYMENT PAGE --------------------

class PaymentPage extends StatefulWidget {
  final double totalAmount;

  const PaymentPage({Key? key, required this.totalAmount}) : super(key: key);

  @override
  State<PaymentPage> createState() => _PaymentPageState();
}



class _PaymentPageState extends State<PaymentPage> {
  double cashAmount = 0.0;
  double bankAmount = 0.0;
  bool isCashChecked = false;
  bool isBankChecked = false;

  double get totalPaid => cashAmount + bankAmount;
  double get returnAmount => totalPaid - widget.totalAmount;

  void _onPaymentChanged(String method, double amount) {
    setState(() {
      if (method == 'Cash') {
        cashAmount = amount;
      } else if (method == 'Bank') {
        bankAmount = amount;
      }
    });
  }
    void _onCheckboxChanged(String method, bool checked) {
    setState(() {
      if (method == 'Cash') {
        isCashChecked = checked;
        if (!checked) cashAmount = 0.0;
      } else if (method == 'Bank') {
        isBankChecked = checked;
        if (!checked) bankAmount = 0.0;
      }
    });
  }

  void _handlePayment() {
  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (context) => const PaymentSuccessPage(),
    ),
  );
}


bool get isPaymentReady =>
    (isCashChecked || isBankChecked) && totalPaid >= widget.totalAmount;

  @override
  Widget build(BuildContext context) {
    final String formattedTotal = widget.totalAmount.toStringAsFixed(2);

    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        backgroundColor: const Color.fromARGB(255, 1, 139, 82)
,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Payment', style: TextStyle(color: Colors.white)),
        actions: [
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white),
            onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst),
          ),
          const SizedBox(width: 10),
        ],
      ),
 body: Column(
  children: [
    // Scrollable content
    Expanded(
      child: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 16), // Prevent keyboard overlap
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Payment Summary Section
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Payment Summary',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      TextButton(
                        onPressed: () {
                          _onCheckboxChanged('Cash', false);
                          _onCheckboxChanged('Bank', false);
                          _onPaymentChanged('Cash', 0.0);
                          _onPaymentChanged('Bank', 0.0);
                        },
                        child: const Text('Clear All',
                            style: TextStyle(color: Color(0xFF4CAF50), fontSize: 16)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                ],
              ),
            ),
            const Divider(),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  PaymentOptionTile(
                    title: 'Cash',
                    totalAmount: widget.totalAmount,
                    onAmountChanged: (amount) => _onPaymentChanged('Cash', amount),
                    onCheckboxChanged: (checked) => _onCheckboxChanged('Cash', checked),
                  ),
                  PaymentOptionTile(
                    title: 'Bank',
                    totalAmount: widget.totalAmount,
                    onAmountChanged: (amount) => _onPaymentChanged('Bank', amount),
                    onCheckboxChanged: (checked) => _onCheckboxChanged('Bank', checked),
                  ),
                ],
              ),
            ),

            // Customer Section
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Marc Demo',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      Text('Customer',
                          style: TextStyle(color: Colors.grey, fontSize: 14)),
                    ],
                  ),
                  TextButton(
                    onPressed: () => print('Change Customer'),
                    child: const Text('Change',
                        style: TextStyle(color: Color(0xFF4CAF50), fontSize: 16)),
                  ),
                ],
              ),
            ),
            const Divider(),

            // Payment Details Section
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  _buildPaymentDetailRow('Total amount to be paid',
                      '\₹${widget.totalAmount.toStringAsFixed(2)}'),
                  _buildPaymentDetailRow('Amount paid by Customer',
                      '\₹${totalPaid.toStringAsFixed(2)}'),
                _buildPaymentDetailRow(
  returnAmount < 0 ? 'Remaining Amount' : 'Return Amount',
  '\₹${returnAmount.abs().toStringAsFixed(2)}'),
       ],
              ),
            ),
          ],
        ),
      ),
    ),

    // Bottom Bar (fixed)
    Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        border: Border(top: BorderSide(color: Colors.grey[300]!, width: 1.0)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Amt. to be paid',
                  style: TextStyle(fontSize: 14, color: Colors.grey)),
              Text('\₹${widget.totalAmount.toStringAsFixed(2)}',
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            ],
          ),
          ElevatedButton(
            onPressed: isPaymentReady ? _handlePayment : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00B0FF),
              padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
            ),
            child: const Text('Make Payment',
                style: TextStyle(fontSize: 18, color: Colors.white)),
          ),
        ],
      ),
    ),
  ],
),
    );
  }

  Widget _buildPaymentDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 16)),
          Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

// ------------------ PAYMENT OPTION TILE --------------------
class PaymentOptionTile extends StatefulWidget {
  final String title;
  final double totalAmount;
  final Function(double) onAmountChanged;
  final Function(bool) onCheckboxChanged;

  const PaymentOptionTile({
    super.key,
    required this.title,
    required this.totalAmount,
    required this.onAmountChanged,
    required this.onCheckboxChanged,
  });

  @override
  State<PaymentOptionTile> createState() => _PaymentOptionTileState();
}

class _PaymentOptionTileState extends State<PaymentOptionTile> {
  bool isChecked = false;
  bool isExpanded = false;
  final TextEditingController _amountController = TextEditingController();
  double change = 0.0;

void _toggleCheckbox(bool? value) {
  setState(() {
    isChecked = value ?? false;
    isExpanded = isChecked;
    if (!isChecked) {
      _amountController.clear();
      widget.onAmountChanged(0.0);
    }
  });
  widget.onCheckboxChanged(isChecked);
}

void _onAmountChanged(String value) {
  double entered = double.tryParse(value) ?? 0.0;
  setState(() {
    change = entered - widget.totalAmount;
  });
  widget.onAmountChanged(entered);
}

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Header row
        Row(
          children: [
            Checkbox(
              value: isChecked,
              onChanged: _toggleCheckbox,
              activeColor: const Color(0xB3228CF0)
,
            ),
            Expanded(
              child: Text(widget.title, style: const TextStyle(fontSize: 16)),
            ),
            Text(
              '\₹${widget.totalAmount.toStringAsFixed(2)}',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            IconButton(
              icon: Icon(
                isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                color: Colors.teal,
              ),
              onPressed: isChecked
                  ? () => setState(() => isExpanded = !isExpanded)
                  : null,
            ),
          ],
        ),

        if (isExpanded)
          Padding(
            padding: const EdgeInsets.only(left: 32, right: 16, bottom: 8),
            child: Column(
              children: [
                TextField(
                  controller: _amountController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Amount',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: _onAmountChanged,
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const SizedBox(),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Text("Change"),
                        Text(
                          change.toStringAsFixed(2),
                          style: TextStyle(
                            color: change < 0 ? Colors.red : Colors.green,
                            fontWeight: FontWeight.bold,
                          ),
                        )
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
      ],
    );
  }
}
