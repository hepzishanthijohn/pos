import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:rcspos/localdb/purchaseDbHelper.dart';

const sectionStyle = TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: Colors.teal);
const labelStyle = TextStyle(fontSize: 13, color: Colors.grey, fontWeight: FontWeight.w400);
const valueStyle = TextStyle(fontSize: 15, color: Colors.black87);
const summaryLabelStyle = TextStyle(fontSize: 15, color: Colors.blueGrey);
const summaryValueStyle = TextStyle(fontSize: 15, color: Colors.black87, fontWeight: FontWeight.bold);
const grandTotalLabelStyle = TextStyle(fontSize: 18, color: Colors.teal, fontWeight: FontWeight.bold);
const grandTotalValueStyle = TextStyle(fontSize: 19, color: Colors.teal, fontWeight: FontWeight.bold);

Widget _tableHeader(String text) => Padding(
  padding: const EdgeInsets.all(5),
  child: Text(text, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87)),
);

Widget _tableCell(String text) => Padding(
  padding: const EdgeInsets.all(5),
  child: Text(text, style: const TextStyle(fontSize: 13)),
);

class PurchaseDetailsPage extends StatefulWidget {
  final String orderId;
  const PurchaseDetailsPage({Key? key, required this.orderId}) : super(key: key);

  @override
  State<PurchaseDetailsPage> createState() => _PurchaseDetailsPageState();
}

class _PurchaseDetailsPageState extends State<PurchaseDetailsPage> {
  Map<String, dynamic>? purchase;
  List<Map<String, dynamic>> items = [];

  @override
  void initState() {
    super.initState();
    _loadPurchaseData();
  }

  Future<void> _loadPurchaseData() async {
    final dbHelper = PurchaseDBHelper();
    final result = await dbHelper.getPurchaseByOrderId(widget.orderId);

    if (result != null) {
      setState(() {
        purchase = result['purchase'];
        items = List<Map<String, dynamic>>.from(result['items']);
      });
    } else {
      debugPrint("❌ No purchase found for Order ID: ${widget.orderId}");
    }
  }

  String _format(dynamic value) {
    try {
      return (value ?? 0.0).toStringAsFixed(2);
    } catch (_) {
      return "0.00";
    }
  }

  @override
  Widget build(BuildContext context) {

    if (purchase == null) {
      return Scaffold(
      appBar:  AppBar(
         backgroundColor: Colors.transparent,
          elevation: 0,
          automaticallyImplyLeading: false,
            flexibleSpace: Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color.fromARGB(255, 44, 145, 113), Color(0xFF185A9D)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(5),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                   
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                      const Text(
                        'Order Details',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontFamily: 'Arial',
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                   ],
                  ),
                  const SizedBox(height: 4),
               ],
              ),
            ),
          ),
        ),
      ),
  
       body: const Center(child: Text("No details found for this order.")),
      );
    }

    return Scaffold(
      appBar:  AppBar(
         backgroundColor: Colors.transparent,
          elevation: 0,
          automaticallyImplyLeading: false,
            flexibleSpace: Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color.fromARGB(255, 44, 145, 113), Color(0xFF185A9D)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(5),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                   
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                      const Text(
                        'Order Details',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontFamily: 'Arial',
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                   ],
                  ),
                  const SizedBox(height: 4),
               ],
              ),
            ),
          ),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.only(bottom: 30),
          children: [
            // Purchase/Supplier Info Card
            Padding(
              padding: const EdgeInsets.all(16),
              child: Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 4,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Purchase Summary",
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.teal[800])),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          // Expanded(
                          //   child: Column(
                          //     crossAxisAlignment: CrossAxisAlignment.start,
                          //     children: [
                          //       Text("Purchase ID:", style: labelStyle),
                          //       Text(purchase!['purchase_id'] ?? '--', style: valueStyle),
                          //     ],
                          //   ),
                          // ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text("Order ID:", style: labelStyle),
                                Text(purchase!['order_id'] ?? "--", style: valueStyle),
                              ],
                            ),
                          ),
                                                    Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text("Date:", style: labelStyle),
                                Text(
                                  DateFormat('dd MMM yyyy, hh:mm a').format(
                                    DateTime.parse(purchase!['purchase_date']),
                                  ),
                                  style: valueStyle,
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text("Status:", style: labelStyle),
                                Chip(
                                  label: Text(
                                    purchase!['status'].toString().toUpperCase(),
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                  ),
                                  backgroundColor: purchase!['status'] == 'completed'
                                      ? Colors.green
                                      : Colors.orange,
                                ),
                              ],
                            ),
                          ),
 
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                       ],
                      ),
                      const Divider(height: 28),
                        Text("Customer Information", style: sectionStyle),
                       Row(
                        children: [
                          Expanded(
                            child: ListTile(
                              leading: const Icon(Icons.person, color: Colors.blueGrey),
                              title: Text(purchase!['supplier_name'] ?? '--', style: valueStyle),
                          
                              dense: true,
                            ),
                          ),
                          Expanded(
                            child: ListTile(
                              leading: const Icon(Icons.phone, color: Colors.teal),
                              title: Text(purchase!['supplier_phone'] ?? "", style: valueStyle),
                           
                              dense: true,
                            ),
                          ),
                        ],
                      ),
                     
                    ],
                  ),
                ),
              ),
            ),
            // Items Table
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 3,
                margin: const EdgeInsets.only(bottom: 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      decoration: BoxDecoration(
                          color: Colors.teal[50], borderRadius: BorderRadius.vertical(top: Radius.circular(12))),
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
                      child: Text(
                        "Purchase Items",
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.teal[900]),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Table(
                        border: TableBorder.all(color: Colors.grey[300]!),
                        columnWidths: const {
                          0: FlexColumnWidth(4),
                          1: FlexColumnWidth(2),
                          2: FlexColumnWidth(2),
                          3: FlexColumnWidth(2),
                        },
                        children: [
                          TableRow(
                            decoration: BoxDecoration(color: Colors.grey[200]),
                            children: [
                              _tableHeader("Item"),
                              _tableHeader("Qty"),
                              _tableHeader("Rate"),
                              _tableHeader("Total"),
                            ],
                          ),
                          ...items.map((item) => TableRow(
                                children: [
                                  _tableCell(item['product_name'].toString()),
                                  _tableCell(item['quantity'].toString()),
                                  _tableCell("₹${(item['price_per_unit'] ?? 0.0).toStringAsFixed(2)}"),
                                  _tableCell("₹${(item['item_total'] ?? 0.0).toStringAsFixed(2)}"),
                                ],
                              )),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Summary Card
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                color: Colors.grey[50],
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 22),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Financial Summary", style: sectionStyle),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text("Subtotal:", style: summaryLabelStyle),
                          Text("₹${_format(purchase!['total_amount'] - (purchase!['total_tax_amount'] ?? 0))}",
                              style: summaryValueStyle),
                        ],
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text("SGST (5%):", style: summaryLabelStyle),
                          Text("₹${_format(purchase!['sgst_amount'])}", style: summaryValueStyle),
                        ],
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text("CGST (5%):", style: summaryLabelStyle),
                          Text("₹${_format(purchase!['cgst_amount'])}", style: summaryValueStyle),
                        ],
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text("Total Tax:", style: summaryLabelStyle),
                          Text("₹${_format(purchase!['total_tax_amount'])}", style: summaryValueStyle),
                        ],
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text("Total Items:", style: summaryLabelStyle),
                          Text("${purchase!['total_items_qty'] ?? '--'}", style: summaryValueStyle),
                        ],
                      ),
                      const Divider(thickness: 1.2),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text("Grand Total:", style: grandTotalLabelStyle),
                          Text("₹${_format(purchase!['total_amount'])}", style: grandTotalValueStyle),
                        ],
                      ),
                    ],
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
