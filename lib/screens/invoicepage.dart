import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;
import 'package:dotted_line/dotted_line.dart';
import 'package:intl/intl.dart';
import 'dart:io';
import 'package:rcspos/localdb/orders_sqlite_helper.dart';
import 'package:rcspos/localdb/purchaseDbHelper.dart';
import 'package:rcspos/screens/home.dart';
import 'package:rcspos/utils/urls.dart';
const double A4_WIDTH_IN_INCHES = 8.27;
const double DPI = 72.0;

class InvoicePage extends StatefulWidget {
  final List<Map<String, dynamic>> cart;
  final int productId;
  final double total;
  final double paidCash;
  final double paidCard;
  final double paidBank;
  final double sgstAmount;
  final double cgstAmount;
  final double totalTaxAmount;
  final String paymentMode;
  final String customerName;
  final String customerPhone;
  final Map<String, dynamic> posConfig;
  final int posId;
  final String orderId;
  final dynamic sessionState;

  const InvoicePage({
    super.key,
    required this.cart,
    required this.total,
    required this.productId,
    required this.paidCash,
    required this.paidCard,
    required this.paidBank,
    required this.sgstAmount,
     required this.cgstAmount,
    required this.totalTaxAmount,
    required this.paymentMode,
    required this.customerName,
    required this.customerPhone,
    required this.posConfig,
    required this.posId,
    required this.orderId,
    required this.sessionState,
  });


  @override
  _InvoicePageState createState() => _InvoicePageState();

}

class _InvoicePageState extends State<InvoicePage> {
 
 @override

@override
void initState() {
  super.initState();
  initializeSession(); // async logic goes here
}

Future<void> initializeSession() async {
  final box = await Hive.openBox('login');
  final rawSession = box.get('session_id');

  // Validate session presence
  if (rawSession == null || (rawSession as String).trim().isEmpty) {
    debugPrint("❌ No session ID available for posting order.");
    return;
  }

  final sessionId = rawSession.startsWith('session_id=')
      ? rawSession
      : 'session_id=$rawSession';

  if (sessionId.isNotEmpty) {
    debugPrint("✅ Session ID: $sessionId");
    syncUnsyncedOrders(); // Call your sync logic
    listenToConnectivityChanges(); // Monitor connectivity
  } else {
    debugPrint("❌ Error: session_id is null or empty");
  }
}

void listenToConnectivityChanges() {
  Connectivity().onConnectivityChanged.listen((result) {
   if (result != ConnectivityResult.none) {
  syncUnsyncedOrders(); // ✅ Pass the sessionId here too
}

  });
}




Future<void> syncUnsyncedOrders() async {
  final dbHelper = PurchaseDBHelper();
  final unsyncedOrders = await dbHelper.getUnsyncedPurchases();

  final box = await Hive.openBox('login');
  final rawSession = box.get('session_id');

  // Validate session presence
  if (rawSession == null || (rawSession as String).trim().isEmpty) {
    debugPrint("❌ No session ID available for posting order.");
    return;
  }

  final sessionId = rawSession.startsWith('session_id=')
      ? rawSession
      : 'session_id=$rawSession';

  print("🟡 Unsynced Purchases:");
  for (var order in unsyncedOrders) {
    print(order);
  }

  for (var order in unsyncedOrders) {
  try {
    final response = await http.post(
      Uri.parse('$baseurl/web/dataset/call_kw/pos.order/create_from_ui'),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        HttpHeaders.cookieHeader: sessionId,
        'Cookie': sessionId,
      },
      body: jsonEncode({'params': order}),
    );

    if (response.statusCode == 200) {
      await dbHelper.markPurchaseAsSynced(order['order_id'].toString());
      print("✅ Order ${order['order_id']} synced");
    } else {
      print("❌ Failed to sync order ${order['order_id']}: ${response.statusCode} - ${response.body}");
    }
  } catch (e, stack) {
    print("❌ Exception syncing order ${order['order_id']}: $e\n$stack");
  }
}

}

  Future<bool> isOnline() async {
  var connectivityResult = await Connectivity().checkConnectivity();
  return connectivityResult != ConnectivityResult.none;
}

Future<bool> postOrderToServer(Map<String, dynamic> order) async {
 // Replace with your config
  final url = '$baseurl/web/dataset/call_kw/pos.order/create_from_ui';

  try {
    // Open Hive box for session retrieval
    final box = await Hive.openBox('login');
    final rawSession = box.get('session_id');

    // Validate session presence
    if (rawSession == null || (rawSession as String).trim().isEmpty) {
      debugPrint("No session ID available for posting order.");
      return false;
    }

    final sessionId = (rawSession as String).startsWith('session_id=')
        ? rawSession
        : 'session_id=${rawSession.toString()}';

    // Transform the order data as per Odoo API expectations
    final odooOrder = {
      "jsonrpc": "2.0",
      "method": "call",
      "params": {
        "model": "pos.order",
        "method": "create_from_ui",
        "args": [
          [
            {
              "data": {
                "name": order['order_id'] ?? "Order ${DateTime.now().millisecondsSinceEpoch}",
                "amount_total": order['total']?.toDouble() ?? 0.0,
                "amount_tax": order['total_tax_amount']?.toDouble() ?? 0.0,
                "amount_paid": (order['paid_cash']?.toDouble() ?? 0.0) +
                    (order['paid_card']?.toDouble() ?? 0.0) +
                    (order['paid_bank']?.toDouble() ?? 0.0),
                "amount_return": 0.0,
                "sequence_number": "001",
                "date_order": DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now()),
                "statement_ids": [
                  [
                    0,
                    0,
                    {
                      "amount": (order['paid_cash']?.toDouble() ?? 0.0) +
                          (order['paid_card']?.toDouble() ?? 0.0) +
                          (order['paid_bank']?.toDouble() ?? 0.0),
                      "payment_method_id": _getPaymentMethodId(order['payment_method']),
                      "name": DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now()),
                    }
                  ]
                ],
                "partner_id": 3, // Adjust dynamically if needed
                "session_id": sessionId, // Adjust dynamically if needed
                "pricelist_id": 1,
                "pos_session_id": 1,
                "fiscal_position_id": null,
                "user_id": 8,
                "company_id": 1,
                "lines": order['items']
                        ?.map((item) => [
                              0,
                              0,
                              {
                                "product_id": item['id'] ?? 14,
                                "full_product_name": item['product_name'] ?? "Product",
                                "qty": item['quantity']?.toDouble() ?? 1.0,
                                "price_unit": item['unit_price']?.toDouble() ?? 0.0,
                                "discount": 0.0,
                                "price_subtotal": item['item_total']?.toDouble() ?? 0.0,
                                "price_subtotal_incl": item['item_total']?.toDouble() ?? 0.0,
                              }
                            ])
                        .toList() ??
                    []
              }
            }
          ]
        ],
        "kwargs": {"draft": false}
      },
      "id": 1,
    };

    final response = await http.post(
      Uri.parse(url),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        HttpHeaders.cookieHeader: sessionId,
      },
      body: jsonEncode(odooOrder),
    );

    if (response.statusCode == 200) {
      final responseData = jsonDecode(response.body);
      if (responseData['result'] != null) {
        print('✅ Order posted successfully: ${response.body}');
        return true;
      } else if (responseData['error'] != null) {
        print('❌ Odoo Error: ${responseData['error']}');
        return false;
      }
      return true;
    } else {
      print('❌ HTTP Error ${response.statusCode}: ${response.body}');
      return false;
    }
  } catch (e) {
    print('❌ Exception posting order: $e');
    return false;
  }
}


  int _getPaymentMethodId(String? paymentMethod) {
    switch (paymentMethod?.toLowerCase()) {
      case 'cash':
        return 1;
      case 'card':
        return 2;
      case 'bank':
        return 3;
      default:
        return 1;
    }
  }
 Future<void> storeOrderLocally(Map<String, dynamic> order, {bool synced = false}) async {
  final db = PurchaseDBHelper();

  final purchaseData = {
    'purchase_id': 'PUR-${DateTime.now().millisecondsSinceEpoch}',
    'purchase_date': DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now()),
    'order_id': order['order_id'] as String,
    'supplier_name': order['customer_name'] ?? '',
    'supplier_phone': order['customer_phone'] ?? '',
    'total_amount': (order['total'] as num?)?.toDouble() ?? 0.0,
    'total_items_qty': order['items']?.length ?? 0,
    'sgst_amount': (order['sgst_amount'] as num?)?.toDouble() ?? 0.0,
    'cgst_amount': (order['cgst_amount'] as num?)?.toDouble() ?? 0.0,
    'total_tax_amount': (order['total_tax_amount'] as num?)?.toDouble() ?? 0.0,
    'status': synced ? 'synced' : 'pending',
    'pos_config_name': order['pos_config_name'] ?? '',
    'pos_config_address': order['pos_config_address'] ?? '',
    'pos_config_phone': order['pos_config_phone'] ?? '',
    'recorded_by': order['recorded_by'] ?? '',
    'payment_method': order['payment_method'] ?? 'Cash',
    'discount_amount': (order['discount_amount'] as num?)?.toDouble() ?? 0.0,
    'notes': 'Order completed via POS',
  };

  final items = (order['items'] as List<dynamic>?)?.map((item) => {
    'product_id': item['product_id'] as int?,
    'product_name': item['product_name'] as String,
    'quantity': item['quantity'] as int,
    'price_per_unit': (item['unit_price'] as num?)?.toDouble() ?? 0.0,
    'item_total': (item['item_total'] as num?)?.toDouble() ?? 0.0,
  }).toList() ?? [];

  await db.insertPurchase(purchaseData, items);
}
void syncPendingOrders() async {
  final online = await isOnline();
  if (!online) return;

  final db = PurchaseDBHelper();
  final pendingOrders = await db.getUnsyncedPurchases(); // Implement this method

  for (final order in pendingOrders) {
    final success = await postOrderToServer(order);
    if (success) {
      await db.markPurchaseAsSynced(order['order_id']); // Update 'status' to 'synced'
    }
  }
}


  @override
  Widget build(BuildContext context) {
         final invoiceNumber = 'INV${DateTime.now().millisecondsSinceEpoch.toString().substring(5)}';
    final invoiceDate = DateFormat('yyyy-MM-dd – kk:mm').format(DateTime.now());
    final subtotal = widget.cart.fold(0.0, (sum, item) => sum + (item['list_price'] * item['quantity']));
    final sgstRate = 0.05;
    final cgstRate = 0.05;
    final sgstAmount = subtotal * sgstRate;
    final cgstAmount = subtotal * cgstRate;
    final totalTaxAmount = sgstAmount + cgstAmount;
    final total = subtotal + totalTaxAmount;
    final totalItems = widget.cart.fold<int>(0, (sum, item) => sum + item['quantity'] as int);
    final pagePixelWidth = A4_WIDTH_IN_INCHES * DPI;


    return Scaffold(
      appBar: AppBar(
        title: const Text('Invoice'),
        actions: [
          IconButton(
            icon: const Icon(Icons.shopping_bag),
            tooltip: 'New Order',
            onPressed: () async {
  final orderData = {
    "order_id": widget.orderId,
    "customer_name": widget.customerName,
    "customer_phone": widget.customerPhone,
    "total": total,
    "sgst_amount": sgstAmount,
    "cgst_amount": cgstAmount,
    "total_tax_amount": totalTaxAmount,
    "payment_method": widget.paymentMode,
    "paid_cash": widget.paidCash,
    "paid_card": widget.paidCard,
    "paid_bank": widget.paidBank,
    "items": widget.cart.map((item) => {
      "product_id": item["id"],
      "product_name": item["display_name"],
      "quantity": item["quantity"],
      "unit_price": item["list_price"],
      "item_total": (item["list_price"] ?? 0.0) * (item["quantity"] ?? 0),
    }).toList(),
    "pos_config_name": widget.posConfig['name'],
    "pos_config_address": widget.posConfig['shop_addrs'],
    "pos_config_phone": widget.posConfig['shop_phone_no'],
    "recorded_by": (widget.posConfig['shop_owner_id'] is Map)
        ? widget.posConfig['shop_owner_id']['name']
        : widget.posConfig['shop_owner_id'].toString()
  };

  final online = await isOnline();

  bool posted = false;
  if (online) {
    posted = await postOrderToServer(orderData);
  }

  await storeOrderLocally(orderData, synced: posted);
const JsonEncoder encoder = JsonEncoder.withIndent('  ');
print(encoder.convert(orderData));

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        posted
            ? "✅ Order posted to server and saved locally"
            : "📴 Offline: Order saved locally",
      ),
    ),
  );

  // Navigate back to home
  Navigator.pushReplacement(
    context,
    MaterialPageRoute(
      builder: (context) => HomePage(
        posConfig: widget.posConfig,
        posId: widget.posId,
        sessionState: widget.sessionState,
      ),
    ),
  );
},
          )
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
                              Text(widget.posConfig['name'] ?? 'Shop Name',
                                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                              Text(widget.posConfig['shop_addrs'] ?? '', style: const TextStyle(fontSize: 12)),
                              Text(widget.posConfig['shop_phone_no']?.toString() ?? '', style: const TextStyle(fontSize: 12)),
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 8.0),
                                child: DottedLine(dashColor: Colors.black54),
                              ),
                              Text("Served by ${(widget.posConfig['shop_owner_id'] is Map) 
    ? widget.posConfig['shop_owner_id']['name'] 
    : widget.posConfig['shop_owner_id'].toString()
}",
                                  style: const TextStyle(fontSize: 12)),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Bill No: $invoiceNumber', style: const TextStyle(fontSize: 12)),
                            // Text('Order Ref: $orderId', style: const TextStyle(fontSize: 12)),
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
                            ...widget.cart.map((item) {
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
}

