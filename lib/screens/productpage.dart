// product_page.dart
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;
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
  _initializeData();
}

Future<void> _initializeData() async {
  setState(() => _loading = true);
  await fetchGstofProducts();
  await fetchProducts();
  setState(() => _loading = false);
}



Future<void> fetchGstofProducts() async {
  final box = await Hive.openBox('login');
  final rawSession = box.get('session_id');
  if (rawSession == null) {
    showError('Session ID not found. Please login again.');
    return;
  }

  final sessionId = rawSession.contains('session_id=')
      ? rawSession
      : 'session_id=$rawSession';

  final apiUrl = '$baseurl/api/account.tax';
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
        final gstList = List<Map<String, dynamic>>.from(json['result']);

        // Print GST for debugging

        // for (var tax in gstList) {
        //   debugPrint('GST: ${tax['name']} - ${tax['amount']}%');
        // }

        setState(() {
          taxes = gstList; // ✅ Store in correct variable
        });
      } else {
        showError('Invalid response format');
      }
    } else {
      showError('Failed to load GST data (${response.statusCode})');
    }
  } catch (e) {
    showError('Error fetching GST: $e');
  }
}



  Future<void> fetchProducts() async {
    final box = await Hive.openBox('login');
    final rawSession = box.get('session_id');
    if (rawSession == null) {
      showError('Session ID not found. Please login again.');
      return;
    }

    final sessionId = rawSession.contains('session_id=')
        ? rawSession
        : 'session_id=$rawSession';

    final apiUrl = widget.categoryId != null
        ? '${baseurl}api/product.template?query={id,display_name,image_128,list_price,qty_available,uom_id}&filter=[["pos_categ_ids","=",${widget.categoryId}]]'
        : '${baseurl}api/product.template?query={id,display_name,image_128,list_price,qty_available,uom_id,taxes_id}';

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
  final matchesSearch = name.contains(widget.searchQuery.toLowerCase());
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
  crossAxisSpacing: 8,
  mainAxisSpacing: 8,
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

            String unit = '';
            if (product['uom_id'] is List && product['uom_id'].length > 1) {
              unit = '/${product['uom_id'][1]}';
            }

            return Card(
              elevation: 8,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
              ),
              child: Padding(
                padding: const EdgeInsets.all(3),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(6),
                          color: Colors.grey.shade100,
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(5),
                          child: buildProductImage(product['image_128']),
                        ),
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      product['display_name'] ?? 'Unnamed',
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
                      '₹${price.toStringAsFixed(2)}$unit',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
                        fontFamily: 'Arial',
                      ),
                    ),
                    const SizedBox(height: 2),
                        Text(
                        'GST: ${gstRate.toStringAsFixed(0)}%',

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
                    const SizedBox(height: 2),
                    SizedBox(
                      width: double.infinity,
                      child: widget.addedProductIds.contains(productId)
  ? Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          icon: const Icon(Icons.remove),
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
          icon: const Icon(Icons.add),
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
  : SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: stock > 0
            ? () {
                widget.onAddToCart({...product, 'quantity': 1});
                setState(() {
                  cartQuantities[productId] = 1;
                  widget.addedProductIds.add(productId);
                });
              }
            : null,
        icon: const Icon(Icons.add_shopping_cart, size: 16),
        label: const Text('Add to Cart'),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color.fromARGB(255, 1, 139, 82),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 5),
          textStyle: const TextStyle(fontSize: 12, fontFamily: 'Arial'),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        ),
      ),
    )
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}