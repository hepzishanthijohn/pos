// import 'package:flutter/material.dart';
// import 'package:rcspos/localdb/orders_sqlite_helper.dart';
// import 'package:rcspos/screens/invoicepage.dart';

// class PaymentSuccessPage extends StatefulWidget {

//   final String orderId;
//   final double total;
//   final double gst;
//   final String customerName;
//   final String customerPhone;
//   final String paymentMode;
//   final double paidCash;
//   final double paidBank;

//   final double paidCard;
//   final List<Map<String, dynamic>> cart; // ✅ new
//   final Map<String, dynamic> posConfig;  // ✅ new

//   const PaymentSuccessPage({
//     super.key,
//     required this.orderId,
//     required this.total,
//     required this.gst,
//     required this.customerName,
//     required this.customerPhone,
//     required this.paymentMode,
//     required this.paidCash,
//     required this.paidBank,
//     required this.paidCard,
//     required this.cart,          // ✅ new
//     required this.posConfig, 
//  // ✅ new
//   });


//   @override
//   State<PaymentSuccessPage> createState() => _PaymentSuccessPageState();
// }

// class _PaymentSuccessPageState extends State<PaymentSuccessPage> {
//   bool _stored = false;

//   @override
//   void initState() {
//     super.initState();
//     _storeOrder();
//   }

//   void _storeOrder() async {
//     if (_stored) return;
//     _stored = true;

//     // Calculate total paid amount from different modes
//     final double totalPaidAmount = widget.paidCash + widget.paidBank + widget.paidCard;

//     OrderSQLiteHelper().insertOrder(
//       orderId: widget.orderId,
//       total: widget.total,
//       tax: widget.gst, // Mapped gst to tax
//       customerName: widget.customerName,
//       customerPhone: widget.customerPhone,
//       paymentMethod: widget.paymentMode, // Mapped paymentMode to paymentMethod
//       paidAmount: totalPaidAmount, // Calculated total paid amount
//       changeAmount: 0.0, // Assuming 0.0 if not passed or calculated here
//       discount: 0.0,     // Assuming 0.0 if not passed or calculated here
//       // You can add a 'date' parameter here if you want to store the exact payment time
//       // date: DateTime.now().toIso8601String(),
//     );
//     debugPrint('Order stored successfully: ${widget.orderId}');
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: Colors.white,
//       appBar: AppBar(
//         automaticallyImplyLeading: false,
//         backgroundColor: const Color.fromARGB(255, 1, 139, 82),
//         title: const Text("Payment Successful", style: TextStyle(color: Colors.white)),
//         centerTitle: true,
//       ),
//       body: Center(
//         child: Padding(
//           padding: const EdgeInsets.symmetric(horizontal: 24.0),
//           child: Column(
//             mainAxisAlignment: MainAxisAlignment.center,
//             children: [
//               const Icon(Icons.thumb_up, color: Colors.green, size: 100),
//               const SizedBox(height: 20),
//               const Text(
//                 "Payment Completed!",
//                 style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
//               ),
//               const SizedBox(height: 10),
//               Text(
//                 "Thank you, ${widget.customerName}!\nYour payment was successful.",
//                 textAlign: TextAlign.center,
//                 style: const TextStyle(fontSize: 16, color: Colors.grey),
//               ),
//               const SizedBox(height: 40),
//               ElevatedButton.icon(
//                 onPressed: () {
//                   // This pops all routes until the first one (likely the home screen)
//                   Navigator.of(context).popUntil((route) => route.isFirst);
//                 },
//                 icon: const Icon(Icons.add_shopping_cart),
//                 label: const Text("New Order"),
//                 style: ElevatedButton.styleFrom(
//                   backgroundColor: const Color(0xFF00B0FF),
//                   padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
//                   textStyle: const TextStyle(fontSize: 16),
//                 ),
//               ),
//               const SizedBox(height: 12),
//               OutlinedButton.icon(
//                 onPressed: () {
//                   // Pass widget.orderId to InvoicePage
//                   Navigator.of(context).push(
//                     MaterialPageRoute(
//                       builder: (context) => InvoicePage(
//                         orderId: widget.orderId, 
//                         cart: widget.cart,
//                         customerName: widget.customerName,
//                         customerPhone: widget.customerPhone,
//                         posConfig: widget.posConfig,
//                       ),
//                     ),
//                   );
//                 },
//                 icon: const Icon(Icons.receipt_long),
//                 label: const Text("View Invoice"),
//                 style: OutlinedButton.styleFrom(
//                   padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
//                   textStyle: const TextStyle(fontSize: 16),
//                 ),
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
// }