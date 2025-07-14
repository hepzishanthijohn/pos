import 'package:flutter/material.dart';
import 'package:rcspos/components/bottonnavbar.dart';
import 'package:rcspos/components/sidebar.dart';
import 'package:rcspos/data/sampleproduct.dart';
import 'package:rcspos/screens/cartpage.dart';
import 'package:rcspos/screens/customerpage.dart';
import 'package:rcspos/screens/orderspage.dart';
import 'package:rcspos/screens/productpage.dart';
import 'package:rcspos/screens/productstablepage.dart';

class HomePage extends StatefulWidget {
  final int? categoryId;
  final String? categoryName;
  final List<dynamic>? selectedCustomers; 

  const HomePage({
    super.key,
    this.categoryId,
    this.categoryName,
    this.selectedCustomers,
  });

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final Set<int> addedProductIds = {};
  final List<Map<String, dynamic>> cart = [];
  Map<String, dynamic>? selectedCustomer;


  String _searchQuery = '';
  String _filterMode = 'in_stock'; // 'all', 'in_stock', 'out_of_stock'
  String _filterLabel = 'In Stock';
  int _selectedIndex = 0;
  // bool _showOnlyInStock = true; // This can be removed, as _filterMode dictates it now.

  void handleAddToCart(Map<String, dynamic> product) {
    final int productId = product['id'];
    final int newQty = product['quantity'] ?? 1;

    setState(() {
      if (product.containsKey('remove') && product['remove'] == true) {
        cart.removeWhere((item) => item['id'] == productId);
        addedProductIds.remove(productId);
      } else {
        final index = cart.indexWhere((item) => item['id'] == productId);
        if (index >= 0) {
          cart[index]['quantity'] = newQty;
        } else {
          cart.add(product);
          addedProductIds.add(productId);
        }
      }
    });
  }

  Future<void> selectCustomer() async {
  final result = await Navigator.push(
    context,
    MaterialPageRoute(builder: (context) => CustomerPage()),
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
      MaterialPageRoute(builder: (_) => const OrdersPage()),
    );
  } else if (index == 2) {
    final updatedCart = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => Productstablepage(
        onAddToCart: handleAddToCart,
        addedProductIds: addedProductIds,
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
  } else if (index == 3) {
    final updatedCart = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => CartPage(cart: cart)),
    );

    if (updatedCart != null && updatedCart is List<Map<String, dynamic>>) {
      setState(() {
        cart.clear();
        cart.addAll(updatedCart);
        addedProductIds.clear();
        addedProductIds.addAll(updatedCart.map((item) => item['id'] as int));
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
        preferredSize: const Size.fromHeight(106),
        child: AppBar(
          backgroundColor: const Color.fromARGB(255, 1, 139, 82),
          elevation: 0,
          automaticallyImplyLeading: false,
          flexibleSpace: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(5),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top bar
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Menu
                      IconButton(
                        icon: const Icon(Icons.menu, color: Colors.white),
                        onPressed: () => _scaffoldKey.currentState?.openDrawer(),
                      ),

                      // Title
                      const Text(
                        'RCS POS',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontFamily: 'Arial',
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      // Right-side icons
                      Row(
                        children: [
                          // Cart
                          GestureDetector(
                            onTap: () async {
                              if (isMobile) {
                                final updatedCart = await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => CartPage(cart: cart),
                                  ),
                                );

                                if (updatedCart != null &&
                                    updatedCart is List<Map<String, dynamic>>) {
                                  setState(() {
                                    cart.clear();
                                    cart.addAll(updatedCart);
                                    addedProductIds.clear();
                                    addedProductIds.addAll(updatedCart.map((item) => item['id'] as int));
                                  });
                                }
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text("Cart is visible in side panel on desktop"),
                                  ),
                                );
                              }
                            },
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
                                          fontFamily: 'Arial',
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),

                          // Filter Popup
                          PopupMenuButton<String>(
                            onSelected: (value) {
                              setState(() {
                                _filterLabel = value;
                                // Update _filterMode correctly
                                if (value == 'All') {
                                  _filterMode = 'all';
                                } else if (value == 'In Stock') {
                                  _filterMode = 'in_stock';
                                } else if (value == 'Out of Stock') {
                                  _filterMode = 'out_of_stock';
                                }
                              });
                            },
                            itemBuilder: (context) => const [
                              PopupMenuItem(value: 'All', child: Text('All')),
                              PopupMenuItem(value: 'In Stock', child: Text('In Stock')),
                              PopupMenuItem(value: 'Out of Stock', child: Text('Out of Stock')),
                            ],
                            child: Row(
                              children: [
                                const Icon(Icons.filter_list, color: Colors.white, size: 18),
                                const SizedBox(width: 6),
                                Text(
                                  _filterLabel,
                                  style: const TextStyle(color: Colors.white, fontSize: 14, fontFamily: 'Arial'),
                                ),
                                const Icon(Icons.arrow_drop_down, color: Colors.white),
                              ],
                            ),
                          ),

                          const SizedBox(width: 6),
                        ],
                      ),
                    ],
                  ),

                  // Search Bar
                  Container(
                    height: 43,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
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
                        contentPadding: EdgeInsets.symmetric(horizontal: 0, vertical: 10),
                      ),
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      drawer: const AppDrawer(),
      body: Row(
        children: [
          Expanded(
            flex: 3,
            // Pass the derived actualShowOnlyInStock
            child: ProductPage(
              categoryId: widget.categoryId,
              onAddToCart: handleAddToCart,
              addedProductIds: addedProductIds,
              searchQuery: _searchQuery,
              showOnlyInStock: actualShowOnlyInStock, // Pass the nullable bool here
            ),
          ),
          if (isDesktop) const VerticalDivider(width: 1),
          if (isDesktop)
            Expanded(
              flex: 5,
              child: CartPage(
  cart: cart,
  customerName: selectedCustomer?['name'],
),

            ),
        ],
        
      ),
       bottomNavigationBar: CustomBottomNav(
        selectedIndex: _selectedIndex,
        onTap: (index) => _onItemTapped(index),

      ),
    );
  }
  
}
