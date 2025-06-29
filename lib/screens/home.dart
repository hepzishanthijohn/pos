import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;
import 'package:rcspos/components/bottonnavbar.dart';
import 'package:rcspos/components/sidebar.dart';
import 'package:rcspos/screens/cartpage.dart';
import 'package:rcspos/utils/urls.dart';


class HomePage extends StatefulWidget {
  final int? categoryId;
  final String? categoryName;

  const HomePage({super.key, this.categoryId, this.categoryName});


  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<Map<String, dynamic>> products = [];
  List<Map<String, dynamic>> cart = [];
  int _selectedIndex = 0;
  bool _loading = true;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  late Box productBox;
  Set<int> addedProductIds = {};
String _searchQuery = '';
String _filterMode = 'in_stock';
bool _useToggle = false;
bool _toggleValue = false;
String _filterLabel = 'Filter';



  
  @override
  void initState() {
    super.initState();
    fetchProducts();
  }
Future<void> fetchProducts() async {
  final box = await Hive.openBox('login');
  final rawSession = box.get('session_id');
  if (rawSession == null) {
    showError('Session ID not found. Please login again.');
    return;
  }
  final sessionId = rawSession.contains('session_id=') ? rawSession : 'session_id=$rawSession';

final apiUrl = widget.categoryId != null
    ? '${baseurl}api/product.template?query={id,display_name,image_128,list_price,qty_available}&filter=[["pos_categ_ids","=",${widget.categoryId}]]'
    : '${baseurl}api/product.template?query={id,display_name,image_128,list_price,qty_available}';

  try {
    final response = await http.get(
      Uri.parse(apiUrl),
      headers: {
        HttpHeaders.cookieHeader: sessionId,
        HttpHeaders.contentTypeHeader: 'application/json',
      },
    );

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      if (json['result'] is List) {
        setState(() {
          products = List<Map<String, dynamic>>.from(json['result']);
          _loading = false;
        });
      } else {
        showError('Invalid response format');
      }
    } else {
      showError('Failed to load products (${response.statusCode})');
    }
  } catch (e) {
    showError('Error fetching products: $e');
  }
}

  void showError(String message) {
    setState(() => _loading = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _onItemTapped(int index) async {
    setState(() => _selectedIndex = index);
  if (index == 2) {
  final updatedCart = await Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => CartPage(cartItems: cart)),
  );

  if (updatedCart != null && updatedCart is List<Map<String, dynamic>>) {
    setState(() {
      cart = updatedCart;
      addedProductIds = updatedCart
          .map((item) => item['id'] as int)
          .toSet(); // 🔁 Update product IDs
    });
  }
}

  }

Widget buildProductImage(dynamic imageData) {
  if (imageData is! String || imageData.isEmpty || imageData == 'false') {
    return const Icon(Icons.image_not_supported, size: 50, color: Colors.grey);
  }

  try {
    return Image.memory(
      base64Decode(imageData),
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) =>
          const Icon(Icons.broken_image, size: 50, color: Colors.grey),
    );
  } catch (_) {
    return const Icon(Icons.broken_image, size: 50, color: Colors.grey);
  }
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
appBar: PreferredSize(
  preferredSize: const Size.fromHeight(146),
  child: AppBar(
    backgroundColor: const Color.fromARGB(255, 1, 139, 82),
    elevation: 0,
    automaticallyImplyLeading: false,
    flexibleSpace: SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(5, 5, 5, 5),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row: Menu, Title, Cart
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.menu, color: Colors.white),
                  onPressed: () => _scaffoldKey.currentState?.openDrawer(),
                ),
                const Text(
                  'RCS POS',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
               // ✅ Cart Icon with Badge
GestureDetector(
  onTap: () async {
    final updatedCart = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CartPage(cartItems: cart),
      ),
    );
    if (updatedCart != null &&
        updatedCart is List<Map<String, dynamic>>) {
      setState(() {
        cart = updatedCart;
        addedProductIds = updatedCart
            .map((item) => item['id'] as int)
            .toSet();
      });
    }
  },
  child: SizedBox(
    width: 40,
    height: 40,
    child: Stack(
      alignment: Alignment.center,
      children: [
        const Icon(Icons.shopping_cart, color: Colors.white, size: 26),
        if (cart.isNotEmpty)
          Positioned(
            top: 4,
            right: 4,
            child: Container(
              padding: const EdgeInsets.all(2),
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
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    ),
  ),
),
  ],
            ),
            // const SizedBox(height: 0),

            // 🔍 Search bar
            Container(
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
              ),
              child: TextField(
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value.toLowerCase();
                  });
                },
                decoration: const InputDecoration(
                  hintText: 'What would you like to buy?',
                  hintStyle: TextStyle(color: Colors.grey),
                  border: InputBorder.none,
                  prefixIcon: Icon(Icons.search, color: Colors.grey),
                  contentPadding: EdgeInsets.symmetric(horizontal: 8,vertical: 7),
                ),
                style: const TextStyle(fontSize: 14),
              ),
            ),
                            Row(
  mainAxisAlignment: MainAxisAlignment.spaceBetween,
  children: [
PopupMenuButton<String>(
  onSelected: (value) {
    setState(() {
      _useToggle = false;
      _filterLabel = value; // ✅ update label

      _filterMode = value == 'All'
          ? 'all'
          : value == 'In Stock'
              ? 'in_stock'
              : 'out_of_stock';
    });
  },
  child: Row(
    children: [
      const Icon(Icons.filter_list, color: Colors.white, size: 18),
      const SizedBox(width: 6),
      Text(
        _filterLabel, // ✅ dynamic label
        style: const TextStyle(color: Colors.white, fontSize: 14),
      ),
      const Icon(Icons.arrow_drop_down, color: Colors.white),
    ],
  ),
  itemBuilder: (BuildContext context) => const [
    PopupMenuItem<String>(value: 'All', child: Text('All')),
    PopupMenuItem<String>(value: 'In Stock', child: Text('In Stock')),
    PopupMenuItem<String>(value: 'Out of Stock', child: Text('Out of Stock')),
  ],
),

Transform.scale(
  scale: 0.75,
  child: Switch(
    value: _toggleValue,
    activeColor: Colors.white,
    activeTrackColor: Colors.greenAccent,
    onChanged: (bool value) {
      setState(() {
        _toggleValue = value;
        _useToggle = true; // ✅ override dropdown when toggle used
      });
    },
  ),
),


  ],
),
 
          ],
        ),
      ),
    ),
  ),
),
drawer: const AppDrawer(),
body: _loading
    ? const Center(child: CircularProgressIndicator())
    : Builder(
        builder: (context) {
        final filteredProducts = products.where((product) {
  final name = product['display_name']?.toString().toLowerCase() ?? '';
  final stock = product['qty_available']?.toInt() ?? 0;

  // Apply toggle or dropdown filtering
  final passesStockFilter = _useToggle
      ? (_toggleValue ? stock == 0 : stock > 0)
      : (_filterMode == 'all'
          ? true
          : _filterMode == 'in_stock'
              ? stock > 0
              : stock == 0);

  // Apply search query filtering
  final matchesSearch = name.contains(_searchQuery);

  return passesStockFilter && matchesSearch;
}).toList();



          return Padding(
            padding: const EdgeInsets.all(10.0),
            child: GridView.builder(
              itemCount: filteredProducts.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 0.72,
              ),
              itemBuilder: (context, index) {
                final product = filteredProducts[index];
                final double price = (product['list_price'] ?? 0).toDouble();
                final int stock = product['qty_available']?.toInt() ?? 0;
                final productId = product['id'];
                final alreadyInCart = addedProductIds.contains(productId);

                return Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  shadowColor: Colors.black26,
                  color: Colors.white,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Container(
                            width: double.infinity,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(10),
                              color: Colors.grey.shade100,
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: buildProductImage(product['image_128']),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          product['display_name'] ?? 'Unnamed',
                          style: const TextStyle(
                            fontWeight: FontWeight.w500,
                            fontSize: 13,
                            color: Colors.black87,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 1),
                        Text(
                          '₹${price.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF228CF0),
                          ),
                        ),
                        const SizedBox(height: 1),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: stock > 0 ? Colors.green.shade50 : Colors.red.shade50,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            stock > 0 ? 'In Stock: $stock' : 'Out of Stock',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w400,
                              color: stock > 0 ? Colors.green : Colors.red,
                            ),
                          ),
                        ),
                        const SizedBox(height: 3),
                        SizedBox(
                          width: double.infinity,
                          child: alreadyInCart
                              ? Container(
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: const Color.fromARGB(255, 1, 139, 82),
                                    border: Border.all(color: Colors.green.shade700, width: 1.5),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  padding: const EdgeInsets.symmetric(horizontal: 4),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.remove_circle_outline, size: 20, color: Colors.white),
                                        onPressed: () {
                                          setState(() {
                                            final cartItem = cart.firstWhere((item) => item['id'] == productId);
                                            if (cartItem['quantity'] > 1) {
                                              cartItem['quantity'] -= 1;
                                            } else {
                                              cart.remove(cartItem);
                                              addedProductIds.remove(productId);
                                            }
                                          });
                                        },
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 4),
                                        child: Text(
                                          '${cart.firstWhere((item) => item['id'] == productId)['quantity']}',
                                          style: const TextStyle(fontSize: 16, color: Colors.white),
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.add_circle_outline, size: 20, color: Colors.white),
                                        onPressed: () {
                                          setState(() {
                                            final cartItem = cart.firstWhere((item) => item['id'] == productId);
                                            cartItem['quantity'] += 1;
                                          });
                                        },
                                      ),
                                    ],
                                  ),
                                )
                              : ElevatedButton.icon(
                                  onPressed: stock > 0
                                      ? () {
                                          setState(() {
                                            cart.add({...product, 'quantity': 1});
                                            addedProductIds.add(productId);
                                          });
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(
                                              content: Text('${product['display_name']} added to cart'),
                                              duration: const Duration(seconds: 1),
                                            ),
                                          );
                                        }
                                      : null,
                                  icon: const Icon(Icons.add_shopping_cart, size: 18),
                                  label: const Text('Add to Cart'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color.fromARGB(255, 1, 139, 82),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 8),
                                    textStyle: const TextStyle(fontSize: 14),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),

      bottomNavigationBar: CustomBottomNav(
        selectedIndex: _selectedIndex,
        // onItemTapped: _onItemTapped,
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton(
            heroTag: 'sync',
            backgroundColor: Colors.green,
            onPressed: fetchProducts,
            child: const Icon(Icons.refresh),
          ),
          // const SizedBox(height: 10),
          // FloatingActionButton(
          //   heroTag: 'search',
          //   backgroundColor: Colors.green,
          //   onPressed: () {
          //     // Search functionality placeholder
          //   },
          //   child: const Icon(Icons.search),
          // ),
        ],
      ),
    );
  }
}
