// product_page.dart
import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;
import 'package:rcspos/localdb/product_sqlite_helper.dart';
import 'package:rcspos/utils/urls.dart';

class ProductPage extends StatefulWidget {
  final Function(Map<String, dynamic>) onAddToCart;
  final Set<int> addedProductIds;
  final int? categoryId;
  final String? categoryName;
  final String searchQuery;
  final bool? showOnlyInStock;

  const ProductPage({
    super.key,
    required this.onAddToCart,
    required this.addedProductIds,
    this.categoryId,
    this.categoryName,
    required this.searchQuery,
    this.showOnlyInStock, // ✅ now nullable
  });

  @override
  State<ProductPage> createState() => _ProductPageState();
}

class _ProductPageState extends State<ProductPage> {
  List<Map<String, dynamic>> products = [];
  List<Map<String, dynamic>> taxes = [];
  bool _loading = true;
  Map<int, int> cartQuantities = {};
  bool _toggleValue = false; // true = In Stock only, false = All

@override
void initState() {
  super.initState();
  fetchProducts();       // Show only from local DB
  startSyncTimer();      // Start periodic sync
}
@override
void didUpdateWidget(ProductPage oldWidget) {
  super.didUpdateWidget(oldWidget);
  if (oldWidget.categoryId != widget.categoryId) {
    // category changed, refetch products
    fetchProducts();
  }
}


void startSyncTimer() {
  Timer.periodic(const Duration(minutes: 30), (timer) {
    syncWithServer();    // Sync only updates local DB
  });

  // Optional: sync immediately at first
  syncWithServer();
}


  Future<void> _initializeData() async {
    setState(() => _loading = true);
  
    await fetchProducts();
    setState(() => _loading = false);
  }

Future<void> fetchProducts() async {
  setState(() => _loading = true);

  final box = await Hive.openBox('login');
  final rawSession = box.get('session_id');
  if (rawSession == null) {
    showError('Session not found. Please login again.');
    return;
  }

  final sessionId = rawSession.contains('session_id=')
      ? rawSession
      : 'session_id=$rawSession';

  final int? categoryId = widget.categoryId;

  String url = '$baseurl/api/product.template'
      '?query={id,display_name,taxes_id{id,name},default_code,categ_id{id,name},list_price,qty_available,image_128}';

  if (categoryId != null) {
    url += '&filter=[["categ_id", "=", $categoryId]]';
  }

  try {
    final response = await http.get(
      Uri.parse(url),
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
        showError('Unexpected response format.');
      }
    } else {
      showError('Failed to fetch products. Status: ${response.statusCode}');
    }
  } catch (e) {
    showError('Fetch error: $e');
  }
}

Future<void> syncWithServer() async {
  final box = await Hive.openBox('login');
  final sessionId = box.get('session_id') ?? '';
  if (sessionId.isEmpty) return;

  final url = '${baseurl}api/product.template?query={id,display_name,taxes_id{id,name},default_code,categ_id{id,name},list_price,qty_available}';

  try {
    final response = await http.get(
      Uri.parse(url),
      headers: {
        HttpHeaders.cookieHeader: sessionId.startsWith('session_id=') ? sessionId : 'session_id=$sessionId',
        HttpHeaders.contentTypeHeader: 'application/json',
      },
    );

    if (response.statusCode == 200) {
      final List data = jsonDecode(response.body)['result'];
      final productDb = ProductSQLiteHelper();
      // await ProductSQLiteHelper().updateStockAfterOrder(cart);

      
      await productDb.insertProducts(List<Map<String, dynamic>>.from(data)); // Update local
    }
  } catch (e) {
    print("❌ Sync failed: $e");
  }
}



  void showError(String message) {
    setState(() => _loading = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
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
    
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    // 🔍 Apply search filtering here
    final List<Map<String, dynamic>> filteredProducts = products.where((product) {
      final name = product['display_name']?.toLowerCase() ?? '';
      final code = product['default_code'] is String
    ? product['default_code']!.toLowerCase()
    : product['default_code'] is bool
        ? product['default_code'].toString().toLowerCase()
        : ''; // Default to an empty string if neither

final searchQuery = widget.searchQuery is String
    ? widget.searchQuery!.toLowerCase()
    : widget.searchQuery is bool
        ? widget.searchQuery.toString().toLowerCase()
        : ''; // Default to empty string if neither

final matchesSearch = name.contains(searchQuery) || code.contains(searchQuery);


  
  
      final stock = product['qty_available']?.toInt() ?? 0;

      if (widget.showOnlyInStock == true) {
        return matchesSearch && stock > 0;
      } else if (widget.showOnlyInStock == false) {
        return matchesSearch && stock <= 0;
      } else {
        return matchesSearch; // null = show all
      }
    }).toList();

 return LayoutBuilder(
      builder: (context, constraints) {
        return GridView.builder(
          padding: const EdgeInsets.all(8),
          itemCount: filteredProducts.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: constraints.maxWidth < 400
                ? 2
                : constraints.maxWidth < 600
                    ? 3
                    : constraints.maxWidth < 1000
                        ? 3
                        : 4,
            crossAxisSpacing: 0,
            mainAxisSpacing: 0,
            childAspectRatio: constraints.maxWidth < 600 ? 0.65 : 0.75,
          ),
          itemBuilder: (context, index) {
            final product = filteredProducts[index];
            final price = (product['list_price'] ?? 0).toDouble();
            final dynamic taxesId = product['taxes_id']; // Use dynamic to safely check type

            double gstRate = 0.0;
            if (taxesId is List && taxesId.isNotEmpty) {
              final taxId = taxesId.first;
              final matchingTax = taxes.firstWhere(
                (tax) => tax['id'] == taxId,
                orElse: () => {},
              );
              gstRate = (matchingTax['amount'] ?? 0).toDouble();
            }

            final gstAmount = price * (gstRate / 100);

            final stock = product['qty_available']?.toInt() ?? 0;
            final productId = product['id'];
            final alreadyInCart = widget.addedProductIds.contains(productId);
             final category = product['categ_id'] is Map && product['categ_id']['name'] != null
    ? product['categ_id']['name'] as String // Explicitly cast to String
    : 'No Category';

final taxListRaw = (product['taxes_id'] is List)
    ? (product['taxes_id'] as List)
        .map((tax) {
          // Check if 'tax' element is a Map and has a 'name' key
          if (tax is Map && tax['name'] != null) {
            return tax['name'] as String; // Explicitly cast to String
          } else if (tax is int) { // Handle cases where tax might just be an ID (though your API sends map)
            return 'Tax ID: $tax'; // Or fetch its name if needed
          }
          return 'N/A Tax Item'; // Default for other unexpected types
        })
        .where((name) => name != 'N/A Tax Item' && !name.startsWith('Tax ID: ')) // Filter out internal placeholders
        .join(', '):"s";

final taxList = taxListRaw.isNotEmpty ? taxListRaw : 'No Tax';

            String unit = '';
            if (product['uom_id'] is List && product['uom_id'].length > 1) {
              unit = '/${product['uom_id'][1]}';
            }

            return InkWell( // Wrap the Card with InkWell
              onTap: stock > 0 && !alreadyInCart
                  ? () {
                      print('Selected product:');
                      print(product);
                      widget.onAddToCart({...product, 'quantity': 1});
                      setState(() {
                        cartQuantities[productId] = 1;
                        widget.addedProductIds.add(productId);
                      });
                      // ScaffoldMessenger.of(context).showSnackBar(
                      //   SnackBar(content: Text('${product['display_name']} added to cart')),
                      // );
                    }
                  : alreadyInCart
                      ? () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('${product['display_name']} is already in cart. Use quantity controls to adjust.')),
                          );
                        }
                      : null, // Disable tap if out of stock
              child: Card(
                color: Colors.white,
                  margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 16),
                elevation: 8,
             
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Expanded(
                      //   child: Container(
                      //     height: 60,
                      //     width: double.infinity,
                      //     decoration: BoxDecoration(
                      //       borderRadius: BorderRadius.circular(6),
                      //       color: Colors.grey.shade100,
                      //     ),
                      //     child: ClipRRect(
                      //       borderRadius: BorderRadius.circular(5),
                            
                      //       child: buildProductImage(product['image_128']),
                      //     ),
                      //   ),
                      // ),
                      const SizedBox(height: 1),
                      Text(
                        product['display_name'] ?? 'Unnamed',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Color.fromARGB(255, 18, 2, 80),
                          fontSize: 17,
                          fontFamily: 'Arial',
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                       const SizedBox(height: 2),
//                      Text(
//   '${product['default_code'] is bool ? (product['default_code']! ? 'Available' : 'Not Available') : (product['default_code'] ?? 'N/A')}',
//   style: const TextStyle(
//     fontSize: 13,
//     fontWeight: FontWeight.w400,
//     fontFamily: 'Arial',
//   ),
// ),

                      Text(
                        '₹${price.toStringAsFixed(2)}$unit',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w400,
                          fontFamily: 'Arial',
                        ),
                      ),
                      const SizedBox(height: 2),
                       Text(
                        "$category",
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13.5,
                          fontFamily: 'Arial',
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                       const SizedBox(height: 2),
                      Text(
                        'GST:$taxList',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w400,
                          fontFamily: 'Arial',
                        ),
                      ),
                      const SizedBox(height: 2),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                        decoration: BoxDecoration(
                          color: stock > 0 ? Colors.green.shade50 : Colors.red.shade50,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          stock > 0 ? 'In Stock: $stock' : 'Out of Stock',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w400,
                            fontFamily: 'Arial',
                            color: stock > 0 ? Colors.green : Colors.red,
                          ),
                        ),
                      ),
                   
                      // Conditional display of quantity controls or simple text
                      alreadyInCart
                          ? Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.remove, size: 20),
                                  onPressed: () {
                                    final currentQty = cartQuantities[productId] ?? 1;
                                    if (currentQty > 1) {
                                      setState(() {
                                        cartQuantities[productId] = currentQty - 1;
                                        widget.onAddToCart({...product, 'quantity': currentQty - 1});
                                      });
                                    } else {
                                      setState(() {
                                        widget.addedProductIds.remove(productId);
                                        cartQuantities.remove(productId);
                                        widget.onAddToCart({...product, 'remove': true}); // signal to remove
                                      });
                                    }
                                  },
                                ),
                                Text(
                                  '${cartQuantities[productId] ?? 1}',
                                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.add, size: 18),
                                  onPressed: (cartQuantities[productId] ?? 1) < stock
                                      ? () {
                                          final currentQty = cartQuantities[productId] ?? 1;
                                          setState(() {
                                            cartQuantities[productId] = currentQty + 1;
                                            widget.onAddToCart({...product, 'quantity': currentQty + 1});
                                          });
                                        }
                                      : null, // disable if at stock limit
                                ),
                              ],
                            )
                          : const SizedBox.shrink(), // No button, no extra space if not in cart
                    ],
                  ),
                ),
              ),
            );
    
          },
        );
      },
    );
  

  }
} 