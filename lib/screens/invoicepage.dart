import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:dotted_line/dotted_line.dart';
import 'package:rcspos/localdb/purchaseDbHelper.dart';
import 'package:rcspos/screens/home.dart';

const double A4_WIDTH_IN_INCHES = 8.27;
const double DPI = 72.0;

class InvoicePage extends StatelessWidget {
  final String orderId;
    final double total;
  final double gst;
  final Map<String, dynamic> posConfig;
  final List<Map<String, dynamic>> cart;
  final String customerName;
  final String customerPhone;
   final String paymentMode;
  final double paidCash;
  final double paidBank;
    final double paidCard;

  const InvoicePage({
    super.key,
     required this.paymentMode,
    required this.paidCash,
    required this.paidBank,
    required this.paidCard,
     required this.total,
    required this.gst,
    required this.orderId,
    required this.posConfig,
    required this.cart,
    required this.customerName,
    required this.customerPhone,
  });

  TableRow _buildTableRow(List<String> cells, {bool isHeader = false}) {
    return TableRow(
      decoration: BoxDecoration(color: isHeader ? Colors.grey[300] : null),
      children: cells.map((cell) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 4),
          child: Text(
            cell,
            style: TextStyle(
              fontWeight: isHeader ? FontWeight.bold : FontWeight.normal,
              fontFamily: 'Courier',
              fontSize: 12,
            ),
            textAlign: TextAlign.center,
          ),
        );
      }).toList(),
    );
  }

  TableRow _buildTaxTableRow(List<String> cells, {bool isHeader = false, bool isTotalRow = false}) {
    return TableRow(
      decoration: BoxDecoration(color: isTotalRow ? Colors.grey[200] : null),
      children: cells.map((cell) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 4),
          child: Text(
            cell,
            style: TextStyle(
              fontWeight: isHeader || isTotalRow ? FontWeight.bold : FontWeight.normal,
              fontFamily: 'Courier',
              fontSize: isTotalRow ? 13 : 12,
            ),
            textAlign: TextAlign.right,
          ),
        );
      }).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final invoiceNumber = 'INV${DateTime.now().millisecondsSinceEpoch.toString().substring(5)}';
    final invoiceDate = DateFormat('yyyy-MM-dd – kk:mm').format(DateTime.now());
    final subtotal = cart.fold(0.0, (sum, item) => sum + (item['list_price'] * item['quantity']));
    final sgstRate = 0.05;
    final cgstRate = 0.05;
    final sgstAmount = subtotal * sgstRate;
    final cgstAmount = subtotal * cgstRate;
    final totalTaxAmount = sgstAmount + cgstAmount;
    final total = subtotal + totalTaxAmount;
    final totalItems = cart.fold<int>(0, (sum, item) => sum + item['quantity'] as int);
    final pagePixelWidth = A4_WIDTH_IN_INCHES * DPI;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Invoice', style: TextStyle(color: Colors.white)),
        backgroundColor: const Color.fromARGB(255, 1, 139, 82),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
 IconButton(
  icon: const Icon(Icons.shopping_bag), // or any icon you use for order
  tooltip: 'New Order',
  onPressed: () async {
    final dbHelper = PurchaseDBHelper();
    final now = DateTime.now();
    final purchaseId = 'PUR${now.millisecondsSinceEpoch.toString().substring(5)}';
    final purchaseDate = now.toIso8601String();

    final purchase = {
      'order_id': orderId,
      'purchase_id': purchaseId,
      'purchase_date': purchaseDate,
      'supplier_name': customerName,
      'supplier_phone': customerPhone,
      'total_amount': total,
      'total_items_qty': totalItems,
      'sgst_amount': sgstAmount,
      'cgst_amount': cgstAmount,
      'total_tax_amount': totalTaxAmount,
      'status': 'completed',
      'pos_config_name': posConfig['name'],
      'pos_config_address': posConfig['shop_addrs'],
      'pos_config_phone': posConfig['shop_phone_no'],
      'recorded_by': posConfig['shop_owner_id']?['name'] ?? 'Admin',
      'payment_method': 'Cash',
      'discount_amount': 0.0,
      'notes': 'Auto-generated purchase from POS',
    };

    final items = cart.map((item) => {
      'product_id': item['id'],
      'product_name': item['display_name'],
      'quantity': item['quantity'],
      'price_per_unit': item['list_price'],
      'item_total': (item['list_price'] ?? 0.0) * (item['quantity'] ?? 0),
    }).toList();

    final result = await dbHelper.insertPurchase(purchase, items);
    if (result != -1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Purchase saved ✅')),
      );

      await dbHelper.printPurchaseData(result);

      // ✅ Navigate to purchase details page if required

              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => HomePage(posConfig: posConfig)),
              );
     
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to save ❌')),
      );
    }
  },
),

          IconButton(
            icon: const Icon(Icons.print),
            tooltip: 'Print',
            onPressed: () async {
              final dbHelper = PurchaseDBHelper();
              final now = DateTime.now();
              final purchaseId = 'PUR${now.millisecondsSinceEpoch.toString().substring(5)}';
              final purchaseDate = now.toIso8601String();

              final purchase = {
                'order_id': orderId,
                'purchase_id': purchaseId,
                'purchase_date': purchaseDate,
                'supplier_name': customerName,
                'supplier_phone': customerPhone,
                'total_amount': total,
                'total_items_qty': totalItems,
                'sgst_amount': sgstAmount,
                'cgst_amount': cgstAmount,
                'total_tax_amount': totalTaxAmount,
                'status': 'completed',
                'pos_config_name': posConfig['name'],
                'pos_config_address': posConfig['shop_addrs'],
                'pos_config_phone': posConfig['shop_phone_no'],
                'recorded_by': posConfig['shop_owner_id']?['name'] ?? 'Admin',
                'payment_method': 'Cash',
                'discount_amount': 0.0,
                'notes': 'Auto-generated purchase from POS',
              };

              final items = cart.map((item) => {
                    'product_id': item['id'],
                    'product_name': item['display_name'],
                    'quantity': item['quantity'],
                    'price_per_unit': item['list_price'],
                    'item_total': (item['list_price'] ?? 0.0) * (item['quantity'] ?? 0),
                  }).toList();

              final result = await dbHelper.insertPurchase(purchase, items);
              if (result != -1) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Purchase saved ✅')));
                await dbHelper.printPurchaseData(result);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to save ❌')));
              }
            },
          ),
        ],
      ),
      body: Center(
        child: Column(
          children: [
            const SizedBox(height: 40),
            Expanded(
              child: SingleChildScrollView(
                child: SizedBox(
                  width: pagePixelWidth,
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: Colors.grey.shade400),
                      boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.4), blurRadius: 6)],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(
                          child: Column(
                            children: [
                              Text(posConfig['name'] ?? 'Shop Name',
                                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                              Text(posConfig['shop_addrs'] ?? '', style: const TextStyle(fontSize: 12)),
                              Text(posConfig['shop_phone_no']?.toString() ?? '', style: const TextStyle(fontSize: 12)),
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 8.0),
                                child: DottedLine(dashColor: Colors.black54),
                              ),
                              Text("Served by ${posConfig['shop_owner_id']?['name'] ?? 'Admin'}",
                                  style: const TextStyle(fontSize: 12)),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Bill No: $invoiceNumber', style: const TextStyle(fontSize: 12)),
                            Text('Order Ref: $orderId', style: const TextStyle(fontSize: 12)),
                            Text('Date: $invoiceDate', style: const TextStyle(fontSize: 12)),
                          ],
                        ),
                        const SizedBox(height: 10),
                        const DottedLine(dashColor: Colors.black54),
                        const SizedBox(height: 20),
                        Table(
                          border: TableBorder.all(color: Colors.grey.shade300),
                          columnWidths: const {
                            0: FlexColumnWidth(3),
                            1: FlexColumnWidth(1.5),
                            2: FlexColumnWidth(2),
                            3: FlexColumnWidth(2),
                          },
                          children: [
                            _buildTableRow(['Item', 'Qty', 'Price', 'Total'], isHeader: true),
                            ...cart.map((item) {
                              final name = item['display_name'] ?? 'Item';
                              final qty = '${item['quantity']}';
                              final price = '₹${(item['list_price'] ?? 0.0).toStringAsFixed(2)}';
                              final total = '₹${((item['list_price'] ?? 0.0) * (item['quantity'] ?? 0)).toStringAsFixed(2)}';
                              return _buildTableRow([name, qty, price, total]);
                            }).toList(),
                          ],
                        ),
                        const SizedBox(height: 20),
                        Align(
                          alignment: Alignment.centerRight,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text('Net Total:', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                                  Text('₹${subtotal.toStringAsFixed(2)}',
                                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                                ],
                              ),
                              const DottedLine(dashColor: Colors.grey),
                            ],
                          ),
                        ),
                        Align(
                          alignment: Alignment.centerRight,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text('Total Items: $totalItems', style: const TextStyle(fontWeight: FontWeight.bold)),
                              Text('Subtotal: ₹${subtotal.toStringAsFixed(2)}'),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        Center(
                          child: Column(
                            children: [
                              const DottedLine(dashColor: Colors.black54),
                              const Text('Inclusive of GST TAX ', style: TextStyle(fontSize: 12)),
                              const Text('GST Summary - Details',
                                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                              const SizedBox(height: 10),
                              Table(
                                border: TableBorder.all(color: Colors.grey.shade300),
                                columnWidths: const {
                                  0: FlexColumnWidth(3),
                                  1: FlexColumnWidth(2),
                                  2: FlexColumnWidth(2),
                                  3: FlexColumnWidth(2),
                                },
                                children: [
                                  _buildTaxTableRow(['Tax', 'Amount', 'Base', 'Total'], isHeader: true),
                                  _buildTaxTableRow([
                                    'SGST 5%',
                                    sgstAmount.toStringAsFixed(2),
                                    subtotal.toStringAsFixed(2),
                                    (subtotal + sgstAmount).toStringAsFixed(2),
                                  ]),
                                  _buildTaxTableRow([
                                    'CGST 5%',
                                    cgstAmount.toStringAsFixed(2),
                                    subtotal.toStringAsFixed(2),
                                    (subtotal + cgstAmount).toStringAsFixed(2),
                                  ]),
                                  _buildTaxTableRow([
                                    '',
                                    totalTaxAmount.toStringAsFixed(2),
                                    subtotal.toStringAsFixed(2),
                                    total.toStringAsFixed(2),
                                  ], isTotalRow: true),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 30),
                        Center(
                          child: Column(
                            children: const [
                              Text('powered by RCS', style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic)),
                              Text('____________________________'),
                              Text('Note: Thank you for your business!',
                                  style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
