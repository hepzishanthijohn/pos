import 'package:flutter/material.dart';

class InvoiceDetailsPage extends StatelessWidget {

  final Map<String, dynamic> invoice;
  final List<Map<String, dynamic>> cart;

  const InvoiceDetailsPage({
    super.key,
    required this.invoice,


    required this.cart,
  });

  String buildInvoiceText() {
    final StringBuffer buffer = StringBuffer();

    buffer.writeln("🧾 INVOICE DETAILS (ID: ${invoice['id']})");
    buffer.writeln("=" * 100);
    buffer.writeln("Invoice No     : ${invoice['invoice_number']}");
    buffer.writeln("Date           : ${invoice['invoice_date']}");
    buffer.writeln("Customer Name  : ${invoice['customer_name']}");
    buffer.writeln("Customer Phone : ${invoice['customer_phone']}");
    buffer.writeln("Shop Name      : ${invoice['pos_config_name'] ?? ''}");
    buffer.writeln("Shop Address   : ${invoice['pos_config_address'] ?? ''}");
    buffer.writeln("Shop Phone     : ${invoice['pos_config_phone'] ?? ''}");
    buffer.writeln("Served By      : ${invoice['served_by'] ?? ''}");
    buffer.writeln("-" * 100);
    buffer.writeln("Product                        | Qty   | Rate       | Total");
    buffer.writeln("-" * 100);

    for (final item in cart) {
      final name = item['name'].toString().padRight(30).substring(0, 30);
      final qty = item['quantity'].toString().padLeft(5);
      final rate = "₹${item['price']}".padLeft(10);
      final total = "₹${(item['quantity'] * item['price']).toStringAsFixed(2)}".padLeft(10);
      buffer.writeln('$name | $qty | $rate | $total');
    }

    buffer.writeln("-" * 100);
    buffer.writeln("Subtotal      : ₹${invoice['subtotal']}");
    buffer.writeln("SGST          : ₹${invoice['sgst_amount']}");
    buffer.writeln("CGST          : ₹${invoice['cgst_amount']}");
    buffer.writeln("TOTAL         : ₹${invoice['total_amount']}");
    buffer.writeln("=" * 100);

    return buffer.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Invoice Receipt")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: SelectableText(
          buildInvoiceText(),
          style: const TextStyle(
            fontFamily: 'Courier', // Monospace for alignment
            fontSize: 14,
          ),
        ),
      ),
    );
  }
}
