// file: posconfigpage.dart

import 'dart:convert';
import 'dart:io'; // For HttpHeaders
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;
import 'package:rcspos/components/snackbar_helper.dart';
import 'package:rcspos/localdb/CreditCustomerSQLiteHelper.dart';
import 'package:rcspos/localdb/posconfigsqlitehelper.dart';
import 'package:rcspos/localdb/product_sqlite_helper.dart';
import 'package:rcspos/localdb/purchaseDbHelper.dart';
import 'package:rcspos/screens/CreditCustomersPage.dart';
import 'package:rcspos/screens/home.dart';
import 'package:rcspos/screens/loginpage.dart';
import 'package:rcspos/screens/open_session_dialog.dart';
import 'package:rcspos/screens/orderslistpage.dart';
import 'package:rcspos/screens/productpage.dart';
import 'package:rcspos/screens/productstablepage.dart';
import 'package:rcspos/screens/purchaseDetails.dart';
import 'package:rcspos/utils/urls.dart';


class POSConfigPage extends StatefulWidget {

  const POSConfigPage({
    super.key,
 
    });

  @override
  State<POSConfigPage> createState() => _POSConfigPageState();
}

class _POSConfigPageState extends State<POSConfigPage> {
  bool _loading = true;
  int totalProducts = 0;
  int totalCreditCustomers = 0;
  int totalSalesCount = 0;
  List<Map<String, dynamic>> _configs = [];
  String? _errorMessage;

  final String apiUrl =
      '$baseurl/api/pos.config/?query={id,name,shop_addrs,shop_gst_no,shop_phone_no,shop_code,shop_admin_ids{id,name},last_session_closing_date,current_session_state}';

  @override
  void initState() {
    super.initState();
    fetchPOSConfigs();
    loadSummaryCounts();
  }
Future<void> loadSummaryCounts() async {
  final products = await ProductSQLiteHelper().fetchProducts();
  final credits = await CreditDbHelperRawSqlite().getCustomers();

  // Assuming getCustomers() returns List or count, adjust if needed
  final purchases = await PurchaseDBHelper().getTodaysPurchases(); // Or getTodaysPurchases() depending on your need

  setState(() {
    totalProducts = products.length;
    totalCreditCustomers = credits.length;
    totalSalesCount = purchases.length;  // Or .length if list, or adapt accordingly
  });
}


  Future<void> fetchPOSConfigs() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    final box = await Hive.openBox('login');
    final sqlite = posConfigSQLiteHelper.instance;

    try {
      final rawSession = box.get('session_id');

      if (rawSession == null || (rawSession as String).trim().isEmpty) {
        showError('Session ID not found. Please login again.');
        return;
      }

      final sessionId = rawSession.startsWith('session_id=')
          ? rawSession
          : 'session_id=$rawSession';

      final response = await http.get(
        Uri.parse(apiUrl),
        headers: {
          HttpHeaders.cookieHeader: sessionId,
          HttpHeaders.contentTypeHeader: 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List configsRaw = data['result'] ?? [];

        if (configsRaw.isEmpty) {
          showError("No POS configurations found in the API response.");
          setState(() => _configs = []);
          return;
        }

        final List<Map<String, dynamic>> parsedConfigs =
            configsRaw.map((e) => Map<String, dynamic>.from(e)).toList();

        await sqlite.insertConfigs(parsedConfigs);
        final updatedConfigs = await sqlite.getAllConfigs();

        setState(() {
          _configs = updatedConfigs;
        });
      } else {
        final error = jsonDecode(response.body);
        final msg = error['error']?['data']?['message'] ?? response.body;
        showError("API Error: ${response.statusCode} - $msg");

        final offlineData = await sqlite.getAllConfigs();
        if (offlineData.isNotEmpty) {
          setState(() => _configs = offlineData);
          showCustomSnackBar(
            context: context,
            title: "Using Offline Data",
            message: "Showing cached POS configurations.",
            backgroundColor: Colors.orange,
            icon: Icons.cloud_off,
          );
        } else {
          setState(() => _configs = []);
          showError("No offline POS configs available.");
        }
      }
    } catch (e, stackTrace) {
      debugPrint("❌ Exception during fetch: $e\n$stackTrace");

      final offlineData = await sqlite.getAllConfigs();
      if (offlineData.isNotEmpty) {
        setState(() => _configs = offlineData);
        showCustomSnackBar(
          context: context,
          title: "Offline Mode",
          message: "API failed. Loaded local POS configs.",
          backgroundColor: Colors.orange,
          icon: Icons.wifi_off,
        );
      } else {
        setState(() => _configs = []);
        showError("No offline POS configs available.");
      }
    } finally {
      setState(() => _loading = false);
    }
  }

  void showError(String message) {
    setState(() {
      _loading = false;
      _errorMessage = message;
    });
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  // NOTE: These helper methods are no longer needed for the new UI but are kept for reference.
  Color getStatusColor(dynamic status) {
    if (status == true) return Colors.green.shade600;
    if (status == false) return Colors.red.shade600;
    return Colors.grey.shade600;
  }

  String getStatusText(dynamic status) {
    if (status == true) return 'In Progress';
    if (status == false) return 'Closed';
    return 'Unknown';
  }

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Point Of Sale',
          style: TextStyle(
            fontFamily: 'Arial',
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color.fromARGB(255, 44, 145, 113), Color(0xFF185A9D)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        backgroundColor: Colors.transparent,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.exit_to_app),
            tooltip: 'Logout',
            onPressed: () {
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (context) => const Login()),
                (route) => false,
              );
            },
          ),
        ],
      ),
 body: Center(
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Mobile view: No Card, with a smaller horizontal padding.
          if (constraints.maxWidth < 800) {
            return SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : _errorMessage != null
                        ? _buildErrorWidget()
                        : _configs.isEmpty
                            ? _buildNoConfigsWidget()
                            : _buildProfileView(context),
              ),
            );
          } else {
            // Desktop/Tablet view: The Card widget wraps the content.
            return Padding(
              padding: const EdgeInsets.all(20.0),
              child: Card(
                color: Colors.white,
                elevation: 8,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Expanded(
                      flex: 1,
                      child: Container(
                        decoration: const BoxDecoration(
                          borderRadius: BorderRadius.only(
                            topLeft: Radius.circular(16),
                            bottomLeft: Radius.circular(16),
                          ),
                          image: DecorationImage(
                            image: AssetImage('assets/bgimage2.webp'),
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: _loading
                          ? const Center(child: CircularProgressIndicator())
                          : _errorMessage != null
                              ? _buildErrorWidget()
                              : _configs.isEmpty
                                  ? _buildNoConfigsWidget()
                                  : _buildProfileView(context),
                    ),
                  ],
                ),
              ),
            );
          }
        },
      ),
    ),
  );
  }

Widget _buildProfileView(BuildContext context) {
  final config = _configs.first;
  final String name = config['name'] ?? 'Unnamed POS';
  final String address = config['shop_addrs'] ?? 'Not set';
  final String shopCode = config['shop_code']?.toString() ?? 'Not set';
  final double cash = (config['last_session_closing_cash'] ?? 0.0).toDouble();
  final String shopGstNo = (config['shop_gst_no'] ?? 'Not set').toString();
  final String shopPhoneNo = config['shop_phone_no']?.toString() ?? '-';
   final dynamic adminIds = config['shop_admin_ids'];
  final String shopOwnerName = (adminIds is List && adminIds.isNotEmpty && adminIds.first is Map)
      ? (adminIds.first as Map)['name']?.toString() ?? 'Unknown'
      : 'Unknown';

  final dynamic rawDate = config['last_session_closing_date'];
  final String date = (rawDate == false || rawDate == null || rawDate.toString() == 'false')
      ? 'N/A'
      : _formatDate(rawDate.toString());
  final dynamic sessionRaw = config['current_session_state'];
  final bool sessionState = sessionRaw is bool ? sessionRaw : sessionRaw.toString() == 'true';

  // final bool sessionState = sessionInt == 1;


  return  Padding(
     
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Column(
     
        children: [
          // Logo and name/address section
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Logo
              Container(
                padding: const EdgeInsets.all(0),
                child: const CircleAvatar(
                  radius: 50,
                  backgroundColor: Colors.white,
                  backgroundImage: AssetImage('assets/rcslogo.png'),
                ),
              ),
              const SizedBox(width: 16),
              // Name and address
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                  ),
                  Text(
                    address,
                    style: TextStyle(color: Colors.grey[700], fontSize: 16, fontWeight: FontWeight.w500),
                  ),
                    Text(
                'GST No: $shopGstNo',
                style: const TextStyle(fontSize: 14, fontFamily: 'Arial'),
              ),
              Text(
                'Last Closed: $date',
                style: const TextStyle(fontSize: 14, fontFamily: 'Arial'),
              ),
                ],
              ),
            
            ],
          ),
          const SizedBox(height: 16), // A consistent space below the logo/text
          Divider(color: Colors.grey.shade300, thickness: 1.2, height: 1),
          const SizedBox(height: 12), // A consistent space below the divider
          // POS Info section
       
  // POS Info section
Row(
  mainAxisAlignment: MainAxisAlignment.spaceAround,
  children: [
    _infoRow(Icons.phone, 'Phone', shopPhoneNo),
    _infoRow(Icons.person, 'Owner', shopOwnerName),
    _infoRow(Icons.monetization_on, 'Closing Cash', '₹${cash.toStringAsFixed(2)}'),
  ],
),
const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ORDER SUMMARY
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                  
_buildOrderLine(context, "Total Products", totalProducts, null),
_buildOrderLine(context, "Total Customers With Credit", totalCreditCustomers, null),
_buildOrderLine(context, "Total Sales Today", totalSalesCount, null),
              
                   
                  ],
                ),
              ),

              // TOTAL PRODUCTS
             
            ],
          ),

            const SizedBox(height: 10),
        // ✅ The conditional button
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 19),
            backgroundColor: sessionState ? const Color.fromARGB(255, 20, 98, 161) : const Color.fromARGB(255, 10, 110, 14), // Change color based on state
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500,fontFamily: "Arial"),
          ),
         onPressed: () {
  // Use the correctly defined variables from your _buildProfileView method
  final posId = config['id']; 
// print("Selected POS ID: $shopCode");
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => HomePage(
        shopCode: shopCode,
        posConfig: config, // ✅ Pass the 'config' map as 'posConfig'
        posId: posId,      // ✅ Pass the 'id' from the config map
        sessionState: sessionState, // This variable is already correct
      ),
    ),
  );
},
          child: Text(
            sessionState =='opening_control' ? 'Continue Selling' : 'Start Billing',
          ),
        ),

          // Optional: Footer Info
          
        ],
      ),
    );
  
  
}
  
  

Widget _infoRow(IconData icon, String label, String value) => Padding(
  padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 0.0),
  child: Column(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      Icon(icon, color: Colors.green[600], size: 28),
      const SizedBox(height: 8),
      Text(
        label,
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
      ),
      const SizedBox(height: 4),
      Text(
        value,
        style: const TextStyle(fontSize: 15, color: Colors.black87),
      ),
    ],
  ),
);

Widget _buildOrderLine(BuildContext context, String item, int qty, double? price) {
  IconData iconData;
  Color iconColor;
  Color iconBgColor;
  Widget? destinationPage;

  if (item.toLowerCase().contains('product')) {
    iconData = Icons.inventory_2_rounded;
    iconColor = Colors.white;
    iconBgColor = Colors.green;
    destinationPage = const Productstablepage();
  } else if (item.toLowerCase().contains('credits')) {
    iconData = Icons.person;
    iconColor = Colors.white;
    iconBgColor = Colors.green;
    destinationPage = const CreditCustomersPage();
  } else if (item.toLowerCase().contains('sales')) {
    iconData = Icons.shopping_cart;
    iconColor = Colors.white;
    iconBgColor = Colors.green;
    destinationPage = const OrderListPage();
  } else {
    iconData = Icons.info;
    iconColor = Colors.white;
    iconBgColor = Colors.grey;
  }

  Widget iconCircle = Container(
    width: 40,
    height: 40,
    decoration: BoxDecoration(
      color: iconBgColor,
      shape: BoxShape.circle,
    ),
    child: Center(
      child: Icon(
        iconData,
        color: iconColor,
        size: 20,
      ),
    ),
  );

  return GestureDetector(
    onTap: () {
      if (destinationPage != null) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => destinationPage!),
        );
      }
    },
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      margin: const EdgeInsets.symmetric(vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              iconCircle,
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'Arial',
                      color: Color(0xFF4B4B7C),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$qty ',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      fontFamily: 'Arial',
                      color: Color(0xFF4B4B7C),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const Icon(
            Icons.arrow_forward,
            color: Color.fromARGB(255, 29, 29, 29),
            size: 20,
          ),
        ],
      ),
    
    
    ),
    
  );
}

 
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
              onPressed: fetchPOSConfigs,
              icon: const Icon(Icons.refresh),
              label: const Text('Try Again'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF185A9D),
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
              onPressed: fetchPOSConfigs,
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
}