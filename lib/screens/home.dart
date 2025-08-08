import 'package:flutter/material.dart';

import 'package:rcspos/components/bottonnavbar.dart';
import 'package:rcspos/components/sidebar.dart';
import 'package:rcspos/data/sampleproduct.dart';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;
import 'package:rcspos/localdb/product_sqlite_helper.dart';
import 'package:rcspos/screens/cartpage.dart';
import 'package:rcspos/screens/closeSession.dart';
import 'package:rcspos/screens/customerpage.dart';
import 'package:rcspos/screens/orderslistpage.dart';
import 'package:rcspos/screens/posconfigpage.dart';
import 'dart:async';
import 'package:rcspos/screens/productpage.dart';
import 'package:rcspos/screens/productstablepage.dart';
import 'package:rcspos/utils/urls.dart';

class HomePage extends StatefulWidget {
  final int? productId;
  final Map<String, dynamic> posConfig;
  final String? categoryName;
  final int? categoryId;
  final String? shopCode;
  final bool sessionState; 
  final int posId; // Add POS ID to identify the specific POS config
  

  const HomePage({
    Key? key,
    required this.posConfig,
    this.categoryName,
    this.shopCode,
    this.productId,
    this.categoryId,
    required this.posId, // Required POS ID for the specific POS config
     required this.sessionState,
  }) : super(key: key);

  @override
  State<HomePage> createState() => _HomePageState();
}



class _HomePageState extends State<HomePage> {
  String? _customerName;
  String? _customerPhone;
 
  int totalProducts = 0;

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final Set<int> addedProductIds = {};
  final List<Map<String, dynamic>> cart = [];
  Map<String, dynamic>? selectedCustomer;


  String _searchQuery = '';
  String _filterMode = 'in_stock'; // 'all', 'in_stock', 'out_of_stock'
  String _filterLabel = 'In Stock';
  int _selectedIndex = 0;
  // bool _showOnlyInStock = true; // This can be removed, as _filterMode dictates it now.

  List<Map<String, dynamic>> taxes = [];


  void showError(String message) {
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }
 @override
  void initState() {
    super.initState();



    _customerName = widget.categoryName ?? '';
    _customerPhone = '';

    // ⏰ Sync with server every 30 minutes
    Timer.periodic(const Duration(minutes: 30), (Timer timer) {
      syncWithServer();
    });
  }

Future <void> syncWithServer() async {
  final productHelper = ProductSQLiteHelper();
 await ProductSQLiteHelper().updateStockAfterOrder(cart);



  try {
    // Fetch session
    final box = await Hive.openBox('login');
    final sessionIdRaw = box.get('session_id');
    final sessionId = sessionIdRaw?.contains('session_id=') == true
        ? sessionIdRaw
        : 'session_id=$sessionIdRaw';

    final url = '${baseurl}api/product.template'; 

    final response = await http.get(
      Uri.parse(url),
      headers: {
        HttpHeaders.cookieHeader: sessionId,
        HttpHeaders.contentTypeHeader: 'application/json',
      },
    );

    if (response.statusCode == 200) {
      // print('Shop code: ${widget.shopCode}');
      final jsonData = jsonDecode(response.body);
      final List<Map<String, dynamic>> products = List<Map<String, dynamic>>.from(jsonData['result']);
      await productHelper.insertProducts(products);
      debugPrint('✅ Products synced with central server');
    } else {
      debugPrint('❌ Failed to sync: ${response.statusCode}');
    }
  } catch (e) {
    debugPrint('❌ Sync error: $e');
  } finally {
    productHelper.close();
  }
}

void handleAddToCart(Map<String, dynamic> product) {
  final int productId = product['id'];
  final int newQty = product['quantity'] ?? 1;

  double gstRate = 0.0;
  final dynamic taxesId = product['taxes_id'];

  if (taxesId is List && taxesId.isNotEmpty) {
    final dynamic firstTax = taxesId.first;

    if (firstTax is Map<String, dynamic> && firstTax.containsKey('amount')) {
      gstRate = (firstTax['amount'] ?? 0).toDouble();
    }
  }

  final price = (product['list_price'] ?? 0).toDouble();
  final gstAmount = price * (gstRate / 100);

  final productWithGst = Map<String, dynamic>.from(product);
  productWithGst['gst'] = gstAmount;

  setState(() {
    if (product.containsKey('remove') && product['remove'] == true) {
      cart.removeWhere((item) => item['id'] == productId);
      addedProductIds.remove(productId);
    } else {
      final index = cart.indexWhere((item) => item['id'] == productId);
      if (index >= 0) {
        cart[index]['quantity'] = newQty;
        cart[index]['gst'] = gstAmount;
      } else {
        cart.add(productWithGst);
        addedProductIds.add(productId);
      }
    }
  print('shopcode: ${widget.shopCode}');
    print("🛒 Current cart: ${jsonEncode(cart)}");
  });
}

  Future<void> selectCustomer() async {
  
  final result = await Navigator.push(
    context,
    MaterialPageRoute(builder: (context) => CustomerPage(
       posId: widget.posId,
        sessionState: widget.sessionState,
    )),
  );

  if (result != null && result is Map<String, dynamic>) {
    setState(() {
      selectedCustomer = result;
    });
  }
}
 
Future<void> _onItemTapped(int index) async {
  setState(() => _selectedIndex = index);
 
  if (index == 1) {
    // Navigate to OrdersPage
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const OrderListPage()),
    );
  } else if (index == 2) {
    final updatedCart = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => Productstablepage(
       
        searchQuery: _searchQuery,
        showOnlyInStock: _filterMode == 'in_stock'
            ? true
            : _filterMode == 'out_of_stock'
                ? false
                : null,
      )),
    );

    if (updatedCart != null && updatedCart is List<Map<String, dynamic>>) {
      setState(() {
        cart.clear();
        cart.addAll(updatedCart);
        addedProductIds.clear();
        addedProductIds.addAll(updatedCart.map((item) => item['id'] as int));
      });
    }
  }  else if (index == 3) {
    // Await the result from the CartPage
    final updatedCart = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CartPage(
          shopCode: widget.shopCode ?? widget.posConfig['shop_code'],
          productId: widget.productId ?? 0,
          posId: widget.posId,
          sessionState: widget.sessionState,
          cart: cart, // Pass the current cart to CartPage
          posConfig: widget.posConfig,
        ),
      ),
    );

    // If a non-null result is received, update the cart and the addedProductIds set
    if (updatedCart != null && updatedCart is List<Map<String, dynamic>>) {
      setState(() {
        cart.clear();
        cart.addAll(updatedCart); // Update the cart with the new list
        addedProductIds.clear();
        addedProductIds.addAll(updatedCart.map((item) => item['id'] as int)); // Rebuild the set
      });
    }
  }
}


  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width >= 900;
    final isMobile = MediaQuery.of(context).size.width < 600;

    bool? actualShowOnlyInStock;
    if (_filterMode == 'in_stock') {
      actualShowOnlyInStock = true;
    } else if (_filterMode == 'out_of_stock') {
      actualShowOnlyInStock = false;
    }
    // If _filterMode is 'all', actualShowOnlyInStock remains null.


    return Scaffold(
      key: _scaffoldKey,
appBar: PreferredSize(
  preferredSize: const Size.fromHeight(70), // Adjust as needed
  child: Container(
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        colors: [Color.fromARGB(255, 44, 145, 113), Color(0xFF185A9D)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    ),
    child: SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // LEFT: Menu + Title
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.menu, color: Colors.white),
                  onPressed: () => _scaffoldKey.currentState?.openDrawer(),
                  tooltip: 'Open Menu',
                ),
                   Container(
      padding: const EdgeInsets.all(0),
      decoration: BoxDecoration(
        color: Colors.white,                     // White background
        borderRadius: BorderRadius.circular(25),// Rounded corners
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1), // subtle shadow for depth
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Image.asset(
        'assets/rcslogo.png',
        height: 32,
        width: 32,
        fit: BoxFit.contain,
      ),
    ),
    
                const SizedBox(width: 8),
                const Text(
                  'RCS POS',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontFamily: 'Arial',
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),

            // --- SPACE BETWEEN TITLE AND SEARCH ---
            const SizedBox(width: 24),

            // CENTER: Search bar (expand to fill space)
            Expanded(
              child: Container(
                height: 36,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(28),
                ),
                child: TextField(
                  onChanged: (value) {
                    setState(() => _searchQuery = value.toLowerCase());
                  },
                  decoration: const InputDecoration(
                    hintText: 'What would you like to buy?',
                    hintStyle: TextStyle(color: Colors.grey, fontFamily: 'Arial'),
                    border: InputBorder.none,
                    prefixIcon: Icon(Icons.search, color: Colors.grey),
                    contentPadding: EdgeInsets.symmetric(horizontal: 0, vertical: 5),
                  ),
                  style: const TextStyle(fontSize: 14),
                ),
              ),
            ),

            // --- RIGHT: Cart, More, etc. ---
            const SizedBox(width: 24),

            // Cart, optionally with badge
            Stack(
              alignment: Alignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.shopping_cart, color: Colors.white, size: 28),
                  onPressed: () async {
                     print('shopcode: ${widget.shopCode}');
                    if (isMobile) {
                      final updatedCart = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => CartPage(
                            shopCode: widget.shopCode ?? '',
                            productId: widget.productId ?? 0,
                            posId: widget.posId,
                            sessionState: widget.sessionState,
                            cart: cart,
                            posConfig: widget.posConfig,
                          ),
                        ),
                      );
                      if (updatedCart != null &&
                          updatedCart is List<Map<String, dynamic>>) {
                        setState(() {
                          cart.clear();
                          cart.addAll(updatedCart);
                          addedProductIds.clear();
                          addedProductIds.addAll(
                              updatedCart.map((item) => item['id'] as int));
                        });
                      }
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content:
                              Text("Cart is visible in side panel on desktop"),
                        ),
                      );
                    }
                  },
                ),
                if (cart.isNotEmpty)
                  Positioned(
                    top: 8,
                    right: 6,
                    child: Container(
                      padding: const EdgeInsets.all(0),
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 14,
                        minHeight: 14,
                      ),
                      child: Text(
                        cart.length.toString(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Arial',
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),

            const SizedBox(width: 9),

            // More Options
            PopupMenuButton<String>(
              
              icon: const Icon(Icons.more_vert, color: Colors.white),
              onSelected: (value) async {
                if (value == 'close') {
                  final result = await showDialog(
                    
                    context: context,
                    builder: (context) => CloseSessionDialog(
                      posId: widget.posId,
                      sessionState: widget.sessionState,
                    ),
                  );
                  if (result == true) {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const POSConfigPage(
                                                    )),
                    );
                  }
                }
              },
              itemBuilder: (context) => const [
                PopupMenuItem(
                  value: 'close',
                  child: Text('Close Session'),
                ),
              ],
            ),
            // Add other icons here as needed
          ],
        ),
      ),
    ),
  ),
),
   drawer: AppDrawer(
      posConfig: widget.posConfig,
      posId: widget.posId,
       sessionState: widget.sessionState,
      ),
 
body: Container(
  color: const Color.fromARGB(33, 219, 219, 219), // Set your desired background color here
  child: Row(
    children: [
      Expanded(
        flex: 3,
        child: ProductPage(
          key: ValueKey(widget.categoryId), // ✅ Forces rebuild
          categoryId: widget.categoryId,
          categoryName: widget.categoryName,
          onAddToCart: handleAddToCart,
          addedProductIds: addedProductIds,
          searchQuery: _searchQuery,
          showOnlyInStock: actualShowOnlyInStock,
          onTotalProductsChanged: (count) {
                setState(() {
                  totalProducts = count;
                });
                print('Total Products: $count'); // for debugging
              },
        ),
      ),
      if (isDesktop) const VerticalDivider(width: 1),
      if (isDesktop)
        Expanded(
          flex: 5,
          child: CartPage(
            shopCode: widget.shopCode ??'',
            productId: widget.productId ?? 0,
            posId: widget.posId,
            sessionState: widget.sessionState,
            posConfig: widget.posConfig,
            cart: cart,
            customerName: selectedCustomer?['name'],
          ),
        ),
    ],
  ),
),
     bottomNavigationBar: CustomBottomNav(
        selectedIndex: _selectedIndex,
        onTap: (index) => _onItemTapped(index),

      ),
    );
  }
  
}