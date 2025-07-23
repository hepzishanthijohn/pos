// file: payment_page.dart

import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:rcspos/localdb/orders_sqlite_helper.dart';
import 'package:rcspos/localdb/product_sqlite_helper.dart';
import 'package:rcspos/screens/RazorpayPaymentPage.dart';
import 'package:rcspos/screens/invoicepage.dart';
import 'package:rcspos/screens/payment_option_tile.dart';

import 'package:rcspos/utils/razorpay_web_launcher.dart';

class PaymentPage extends StatefulWidget {
  final double totalAmount;

  final String? customerName;
  final String? customerPhone;
    final Map<String, dynamic> posConfig;  // ✅ new
final List<Map<String, dynamic>> cart;


  const PaymentPage({
    Key? key,
    required this.totalAmount,
    this.customerName,
    required this.cart,
  
    required this.posConfig, 
 
    this.customerPhone,
  }) : super(key: key);

  @override
  
  State<PaymentPage> createState() => _PaymentPageState();
}

class _PaymentPageState extends State<PaymentPage> {
  double cashAmount = 0.0;
  double bankAmount = 0.0;
  double cardAmount = 0.0;

  bool isCashChecked = false;
  bool isBankChecked = false;
  bool isCardChecked = false;

  double get totalPaid => cashAmount + bankAmount + cardAmount;
  double get returnAmount => totalPaid - widget.totalAmount;

  bool get isPaymentReady =>
      (isCashChecked || isBankChecked || isCardChecked) &&
      totalPaid >= widget.totalAmount;

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
void _handleManualPaymentSuccess() async {
  final ordersBox = Hive.box('orders');

  final newOrder = {
    'id': DateTime.now().millisecondsSinceEpoch,
    'customerName': widget.customerName ?? 'Guest',
    'customerPhone': widget.customerPhone ?? '',
    'amount': widget.totalAmount,
    'paymentMethod': 'Card',
    'timestamp': DateTime.now().toIso8601String(),
  };

  await ordersBox.add(newOrder);

  _handlePayment(); // show success screen
}

void _handlePayment() async {
  final orderId = DateTime.now().millisecondsSinceEpoch.toString();

  double paidAmountCombined = cashAmount + bankAmount + cardAmount;

  print('🧾 Order Summary:');
  print('Customer: ${widget.customerName ?? "Guest"}');
  print('Phone: ${widget.customerPhone ?? ""}');
  print('Total Amount: ₹${widget.totalAmount.toStringAsFixed(2)}');
  print('Paid - Cash: ₹$cashAmount, Bank: ₹$bankAmount, Card: ₹$cardAmount');

  print('\n🛒 Cart Items:');
  double totalTax = 0.0;

  for (var item in widget.cart) {
    final name = item['display_name'] ?? 'Unnamed Item';
    final qty = item['quantity'] ?? 1;
    final unitPrice = item['list_price'] ?? 0.0;
    final gstAmount = item['gst'] ?? 0.0;
    final gstName = (item['taxes_id'] != null && item['taxes_id'].isNotEmpty)
        ? item['taxes_id'][0]['name']
        : 'No GST';
    final subtotal = unitPrice * qty;

    totalTax += gstAmount;

    print(
      '• $name\n'
      '  Qty: $qty × ₹${unitPrice.toStringAsFixed(2)} = ₹${subtotal.toStringAsFixed(2)}\n'
      '  GST: $gstName → ₹${gstAmount.toStringAsFixed(2)}\n',
    );
  }

  print('🧾 Total GST: ₹${totalTax.toStringAsFixed(2)}');

OrderSQLiteHelper().insertOrder(
  orderId: orderId,
  total: widget.totalAmount,
  tax: totalTax,
  customerName: widget.customerName ?? 'Guest',
  customerPhone: widget.customerPhone ?? '',
  paymentMethod: isCardChecked
      ? 'Card'
      : isCashChecked
          ? 'Cash'
          : isBankChecked
              ? 'Bank'
              : 'Unknown',
  paidAmount: paidAmountCombined,
  changeAmount: 0.0,
  discount: 0.0,
  date: DateTime.now().toIso8601String(),
);


  OrderSQLiteHelper().printAllOrders();

  // ✅ UPDATE STOCK HERE
  await ProductSQLiteHelper().updateStockAfterOrder(widget.cart);

  // --- START: MODAL AND NAVIGATION LOGIC ADDED HERE ---
  // Show a success AlertDialog
  await showDialog(
    context: context,
    barrierDismissible: false,
    builder: (BuildContext dialogContext) {
      return AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        contentPadding: const EdgeInsets.all(24),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // GIF animation
            Image.asset(
              'assets/paymentsuccesslogo.gif',
              width: 120,
              height: 120,
              fit: BoxFit.contain,
            ),
            const SizedBox(height: 16),
            const Text(
              'Payment Successful!',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color.fromARGB(255, 0, 150, 12),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Your payment has been successfully completed.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14),
            ),
          ],
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          ElevatedButton.icon(
            onPressed: () {
              Navigator.of(dialogContext).pop();
            },
            icon: const Icon(Icons.check_circle_outline),
            label: const Text('OK'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.teal,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      );
    },
  );
  // After the dialog is dismissed, navigate to the invoice page
  Navigator.of(context).pushReplacement( // Use pushReplacement to prevent going back
    MaterialPageRoute(
      builder: (context) => InvoicePage(
        orderId: orderId,
        total: widget.totalAmount,
        gst: totalTax,
        customerName: widget.customerName ?? 'Guest',
        customerPhone: widget.customerPhone ?? '',
        paymentMode: isCardChecked
            ? 'Card'
            : isCashChecked
                ? 'Cash'
                : isBankChecked
                    ? 'Bank'
                    : 'Unknown',
        paidCash: cashAmount,
        paidBank: bankAmount,
        paidCard: cardAmount,
        cart: widget.cart,
        posConfig: widget.posConfig,
      ),
    ),
  );
  // --- END: MODAL AND NAVIGATION LOGIC ADDED HERE ---
}

void storeSuccessfulOrder({
  required String razorpayPaymentId,
  required double totalAmount,
  required String? customerName,
  required String? customerPhone,
}) async {
  final orderData = {
    'payment_id': razorpayPaymentId,
    'amount': totalAmount,
    'customer_name': customerName ?? 'Guest',
    'customer_phone': customerPhone ?? '',
    'timestamp': DateTime.now().toIso8601String(),
  };

 
  final box = await Hive.openBox('orders');
  await box.add(orderData);
}

void _startRazorpayPayment() {
  // Navigate to the RazorpayPaymentPage
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => RazorpayPaymentPage(
        totalAmount: widget.totalAmount, // Pass the total amount
        customerName: widget.customerName ?? 'Guest', // Pass the customer name
        customerPhone: widget.customerPhone ?? '', // Pass the customer phone
      ),
    ),
  );
}


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        backgroundColor: const Color.fromARGB(255, 1, 139, 82),
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
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(),
                  const Divider(),
                  _buildPaymentOptions(),
                  const Divider(),
                  _buildCustomerInfo(),
                  const Divider(),
                  _buildSummary(),
                ],
              ),
            ),
          ),
          _buildBottomBar(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text('Payment Summary', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          TextButton(
            onPressed: () {
              _onCheckboxChanged('Cash', false);
              _onCheckboxChanged('Bank', false);
              setState(() {
                isCardChecked = false;
                cardAmount = 0.0;
              });
              _onPaymentChanged('Cash', 0.0);
              _onPaymentChanged('Bank', 0.0);
            },
            child: const Text('Clear All', style: TextStyle(color: Color(0xFF4CAF50), fontSize: 16)),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentOptions() {
    return Padding(
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
          const SizedBox(height: 10),
          Row(
            children: [
              Checkbox(
                value: isCardChecked,
                onChanged: (checked) {
                  setState(() {
                    isCardChecked = checked ?? false;
                  });
                },
              ),
              const Expanded(child: Text("Card", style: TextStyle(fontSize: 16))),
              ElevatedButton.icon(
                onPressed: isCardChecked ? _startRazorpayPayment : null,
                icon: const Icon(Icons.payment),
                label: const Text("Pay Now"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.indigo,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCustomerInfo() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.customerName ?? 'No Customer Selected', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              Text(widget.customerPhone ?? '', style: const TextStyle(color: Colors.grey, fontSize: 14)),
            ],
          ),
          TextButton(
            onPressed: () {},
            child: const Text('Change', style: TextStyle(color: Color(0xFF4CAF50), fontSize: 16)),
          ),
        ],
      ),
    );
  }

  Widget _buildSummary() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          _buildPaymentDetailRow('Total amount to be paid', '₹${widget.totalAmount.toStringAsFixed(2)}'),
          _buildPaymentDetailRow('Amount paid by Customer', '₹${totalPaid.toStringAsFixed(2)}'),
          _buildPaymentDetailRow(
            returnAmount < 0 ? 'Remaining Amount' : 'Return Amount',
            '₹${returnAmount.abs().toStringAsFixed(2)}',
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    return Container(
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
              const Text('Amt. to be paid', style: TextStyle(fontSize: 14, color: Colors.grey)),
              Text('₹${widget.totalAmount.toStringAsFixed(2)}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            ],
          ),
          ElevatedButton(
            onPressed: isPaymentReady ? _handlePayment : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00B0FF),
              padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
            ),
            child: const Text('Make Payment', style: TextStyle(fontSize: 18, color: Colors.white)),
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
