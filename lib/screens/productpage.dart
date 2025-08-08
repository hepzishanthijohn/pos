// product_page.dart
import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:getwidget/getwidget.dart';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;
import 'package:rcspos/localdb/product_sqlite_helper.dart';
import 'package:rcspos/utils/urls.dart';

class ProductPage extends StatefulWidget {
    final Function(Map<String, dynamic>)? onAddToCart; // Made optional
  final Set<int>? addedProductIds;
  final int? categoryId;
  final String? categoryName;
  final String? searchQuery;
  final bool? showOnlyInStock;
final ValueChanged<int>? onTotalProductsChanged;
  const ProductPage({
    super.key,
    this.onAddToCart,
    this.onTotalProductsChanged,
    this.addedProductIds,
    this.categoryId,
    this.categoryName,
    this.searchQuery,
    this.showOnlyInStock, // ✅ now nullable
  });

  @override
  State<ProductPage> createState() => _ProductPageState();
}

class _ProductPageState extends State<ProductPage> {
  List<Map<String, dynamic>> products = [];
  List<Map<String, dynamic>> taxes = [];
    String _filterMode = 'in_stock'; // 'all', 'in_stock', 'out_of_stock'
  String _filterLabel = 'In Stock';
  bool _loading = true;
  Map<int, int> cartQuantities = {};
  bool _toggleValue = false; // true = In Stock only, false = All

@override
void initState() {
  super.initState();
  fetchProducts();       // Show only from local DB
  startSyncTimer();  
      // Start periodic sync
}
@override
@override
void didUpdateWidget(ProductPage oldWidget) {
  super.didUpdateWidget(oldWidget);

  // If category, stock filter, or search query changes, refetch
  if (oldWidget.categoryId != widget.categoryId ||
      oldWidget.searchQuery != widget.searchQuery ||
      oldWidget.showOnlyInStock != widget.showOnlyInStock) {
    fetchProducts(); // <-- this is your product loading function
  }
}


void startSyncTimer() {
  Timer.periodic(const Duration(minutes: 30), (timer) {
    syncWithServer();    // Sync only updates local DB
  });

  // Optional: sync immediately at first
  // syncWithServer();
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
final productHelper = ProductSQLiteHelper();

final localProducts = await productHelper.fetchProducts();

setState(() {
  products = localProducts;
  _loading = false;
});
 

  // ✅ Send total product count to parent
  widget.onTotalProductsChanged?.call(products.length);


  if (rawSession == null) {
    showError('Session not found. Please login again.');
    setState(() => _loading = false);
    return;
  }

  final sessionId = rawSession.contains('session_id=')
      ? rawSession
      : 'session_id=$rawSession';

  final int? categoryId = widget.categoryId;

  // API URL with fields
  String url = '$baseurl/api/product.template'
      '?query={id,display_name,image_128,taxes_id{id,name},default_code,pos_categ_ids{id,name},list_price,qty_available}';

  if (categoryId != null) {
    url += '&filter=[["pos_categ_ids", "=", $categoryId]]';
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
        final List<Map<String, dynamic>> productList =
            List<Map<String, dynamic>>.from(json['result']);

        // Save to local SQLite
        await productHelper.insertProducts(productList);

        setState(() {
          products = productList;
          _loading = false;
        });
      } else {
        throw Exception('Invalid API format');
      }
    } else {
      throw HttpException('Failed status: ${response.statusCode}');
    }
  } catch (e) {
    debugPrint('API fetch failed, trying local DB: $e');

    List<Map<String, dynamic>> localProducts;
    if (categoryId != null) {
      localProducts = await productHelper.fetchProductsByCategory(categoryId);
    } else {
      localProducts = await productHelper.fetchProducts();
    }

    setState(() {
      products = localProducts;
      _loading = false;
    });
  } finally {
    productHelper.close();
  }
}

Future<void> syncWithServer() async {
  final box = await Hive.openBox('login');
  final sessionId = box.get('session_id') ?? '';
  if (sessionId.isEmpty) return;

  final url = '${baseurl}api/product.template?query={id,display_name,taxes_id{id,name},default_code,pos_categ_ids{id,name},list_price,qty_available}';

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
      // print(response.body);
      // print("✅ Sync successful, updating local DB with ${data.length} products");
      // print(productDb.debugPrintAllProducts());
      
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
 bool? actualShowOnlyInStock;
if (_filterMode == 'in_stock') {
  actualShowOnlyInStock = true;
} else if (_filterMode == 'out_of_stock') {
  actualShowOnlyInStock = false;
}
// If _filterMode is 'all', actualShowOnlyInStock remains null.

final List<Map<String, dynamic>> filteredProducts = products.where((product) {
  final name = product['display_name']?.toLowerCase() ?? '';
  final code = product['default_code'] is String
      ? product['default_code']!.toLowerCase()
      : product['default_code'] is bool
          ? product['default_code'].toString().toLowerCase()
          : '';
  final searchQuery = widget.searchQuery?.toLowerCase() ?? '';
  final matchesSearch = name.contains(searchQuery) || code.contains(searchQuery);

  final stock = product['qty_available']?.toInt() ?? 0;

  if (actualShowOnlyInStock == true) {
    return matchesSearch && stock > 0;
  } else if (actualShowOnlyInStock == false) {
    return matchesSearch && stock <= 0;
  } else {
    return matchesSearch; // null = show all
  }
}).toList();


 return LayoutBuilder(
  
      builder: (context, constraints) {
        return Column(
          
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            

Padding(
  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
  child: Row(
    children: [
      
      // Left Label with Icon
      Row(
        children: const [
          Icon(Icons.filter_alt, color: Color.fromARGB(151, 2, 153, 10), size: 18),
          SizedBox(width: 6),
          Text(
            'Filter',
            style: TextStyle(
              color: Colors.black,
              fontSize: 14,
              fontFamily: 'Arial',
            ),
          ),
        ],
      ),

      const Spacer(), // Push dropdown to the right

      // Right Filter Dropdown Button
    PopupMenuButton<String>(
  onSelected: (value) {
    setState(() {
      _filterLabel = value;
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
  child: Container(
    
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
    
    decoration: BoxDecoration(
     
      border: Border.all(
        color: const Color.fromARGB(50, 2, 3, 3), // Border color matching icon
        width: 1.0,
      ),
      borderRadius: BorderRadius.circular(25), // Rounded corners
      color: const Color.fromARGB(255, 225, 241, 245), // Optional: set background color
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.filter_list, color: Color.fromARGB(160, 2, 9, 15), size: 18),
        const SizedBox(width: 6),
        Text(
          _filterLabel,
          style: const TextStyle(
            color: Color.fromARGB(255, 3, 133, 20),
            fontSize: 14,
            fontFamily: 'Arial',
          ),
        ),
        const Icon(Icons.arrow_drop_down, color: Colors.black),
      ],
    ),
  ),
)

    ],
  ),
),

        const SizedBox(height: 4),
             

         Expanded(
          child:GridView.builder(
     padding: const EdgeInsets.all(3),
          itemCount: filteredProducts.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: constraints.maxWidth < 400
                ? 2
                : constraints.maxWidth < 500
                    ? 3
                    : constraints.maxWidth < 1000
                        ? 3
                        : 4,
            crossAxisSpacing: 0,
            mainAxisSpacing: 0,
            childAspectRatio: constraints.maxWidth < 500
                ? 0.9
                : constraints.maxWidth < 600
                    ? 0.9
                    : constraints.maxWidth < 1000
                        ? 1.0
                        : 1.1,
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
          final alreadyInCart = (widget.addedProductIds ?? {}).contains(productId);
              final category = (product['pos_categ_ids'] is List && product['pos_categ_ids'].isNotEmpty)
    ? (product['pos_categ_ids'][0] is Map && product['pos_categ_ids'][0]['name'] != null
        ? product['pos_categ_ids'][0]['name'] as String
        : 'No Category')
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
          // ✅ Use the null-aware operator for safety
          widget.onAddToCart?.call({...product, 'quantity': 1});
          setState(() {
            cartQuantities[productId] = 1;
            // ✅ Use the null-aware operator for safety
            widget.addedProductIds?.add(productId);
          });
        }
      : alreadyInCart
          ? () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('${product['display_name']} is already in cart. Use quantity controls to adjust.'),
                ),
              );
            }
          : null,
                      child: SizedBox(
  height: 150, // ⬅️ Set your desired fixed height here
 
              child: Card(
                
                color: const Color.fromARGB(255, 255, 255, 255),
                  margin: const EdgeInsets.symmetric(horizontal: 3, vertical: 3),
                elevation: 3,
             
                 shape: RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(4),
    side: const BorderSide(
      color: Color.fromARGB(255, 24, 176, 236), // 👈 Set your desired border color here
      width: 1,           // 👈 Optional: thickness
    ),
  ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
             
Stack(
  children: [
    // Full width image with fixed height and rounded corners
    Container(
      width: double.infinity,
      height: 45, // Fixed height; adjust as needed
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(5),
        color: Colors.grey.shade100,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(5),
        child: buildProductImage(product['image_128']),
      ),
    ),

    // Stock status overlay positioned at top-right
    Positioned(
      top: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        decoration: BoxDecoration(
          color: stock > 0 ? Colors.green.withOpacity(0.8) : Colors.red.withOpacity(0.8),
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.25),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Text(
          stock > 0 ? 'In Stock: $stock' : 'Out of Stock',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w500,
            fontSize: 12,
            fontFamily: 'Arial',
            shadows: [
              Shadow(
                blurRadius: 3,
                color: Colors.black45,
                offset: Offset(0, 1),
              ),
            ],
          ),
        ),
      ),
    ),

    if (alreadyInCart)
      Positioned(
        top: 0,
        left: 0,
        child: GestureDetector(
          onTap: () {
            // Remove item from cart
            setState(() {
              widget.addedProductIds?.remove(productId);
              cartQuantities.remove(productId);
              widget.onAddToCart?.call({...product, 'remove': true});
            });

            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('${product['display_name']} removed from cart')),
            );
          },
          child: Container(
            decoration: BoxDecoration(
              color: const Color.fromARGB(255, 62, 224, 12),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.4),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            padding: const EdgeInsets.all(4),
            child: const Icon(
              Icons.done_all,
              size: 16,
              color: Colors.white,
              semanticLabel: 'Remove from cart',
            ),
          ),
        ),
      ),
  ],
),

      
                      Text(
                        product['display_name'] ?? 'Unnamed',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Color.fromARGB(255, 18, 2, 80),
                          fontSize: 15,
                          fontFamily: 'Arial',
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                       const SizedBox(height: 0),
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
                      const SizedBox(height: 0.5),
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
                       const SizedBox(height: 0.5),
                      Text(
                        'GST:$taxList',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w400,
                          fontFamily: 'Arial',
                        ),
                      ),
                  
                    ],
                  ),
                ),
              ),
                      ),
            );
            
          },
        ),

        ),
 
          ],
          
        );
        
     },
    );
  

  }
} 