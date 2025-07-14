// productstablepage.dart
import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;
import 'package:rcspos/utils/urls.dart'; // Assuming this provides your baseurl

class Productstablepage extends StatefulWidget {
  final Function(Map<String, dynamic>) onAddToCart;
  final Set<int> addedProductIds;
  final int? categoryId;
  final String? categoryName;
  final String searchQuery;
  final bool? showOnlyInStock; // This is the filter control from parent

  const Productstablepage({
    super.key,
    required this.onAddToCart,
    required this.addedProductIds,
    this.categoryId,
    this.categoryName,
    required this.searchQuery,
    this.showOnlyInStock,
  });

  @override
  State<Productstablepage> createState() => _ProductstablepageState();
}

class _ProductstablepageState extends State<Productstablepage> {
  List<Map<String, dynamic>> products = [];
  bool _loading = true;
  Map<int, int> cartQuantities = {};
  int? _sortColumnIndex;
  bool _sortAscending = true;

  final TextEditingController _searchController = TextEditingController();
  String _currentSearchQuery = '';
  String _filterLabel = 'All';
  bool? _currentShowOnlyInStock; // Internal state for the stock filter
  Timer? _debounce;

  // Pagination Variables
  int _currentPage = 0;
  int _rowsPerPage = 10;
  int _totalProducts = 0;

  @override
  void initState() {
    super.initState();
    _currentSearchQuery = widget.searchQuery;
    _searchController.text = widget.searchQuery;
    _currentShowOnlyInStock = widget.showOnlyInStock; // Initialize from widget
    _setFilterLabel();

    _initializeData();
  }

  @override
  void didUpdateWidget(covariant Productstablepage oldWidget) {
    super.didUpdateWidget(oldWidget);
    // This is crucial for reacting to parent widget changes
    bool shouldFetch = false;

    if (widget.searchQuery != oldWidget.searchQuery) {
      _currentSearchQuery = widget.searchQuery;
      _searchController.text = widget.searchQuery;
      _currentPage = 0; // Reset page on search change
      shouldFetch = true;
    }

    if (widget.showOnlyInStock != oldWidget.showOnlyInStock) {
      _currentShowOnlyInStock = widget.showOnlyInStock;
      _setFilterLabel();
      _currentPage = 0; // Reset page on filter change
      shouldFetch = true;
    }

    if (widget.categoryId != oldWidget.categoryId) {
      _currentPage = 0; // Reset page on category change
      shouldFetch = true;
    }

    if (shouldFetch) {
      fetchProducts();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _setFilterLabel() {
    if (_currentShowOnlyInStock == true) {
      _filterLabel = 'In Stock';
    } else if (_currentShowOnlyInStock == false) {
      _filterLabel = 'Out of Stock';
    } else {
      _filterLabel = 'All';
    }
  }

  Future<void> _initializeData() async {
    setState(() => _loading = true);
    await fetchProducts();
    // _loading is set to false in fetchProducts's finally block
  }

  Future<void> fetchProducts() async {
    setState(() {
      _loading = true;
      _totalProducts = 0; // Reset total products before fetching
      products = []; // Clear previous products immediately
    });

    final box = await Hive.openBox('login');
    final rawSession = box.get('session_id');
    if (rawSession == null) {
      showError('Session ID not found. Please login again.');
      return;
    }

    final sessionId = rawSession.contains('session_id=')
        ? rawSession
        : 'session_id=$rawSession';

    // Build the base query string
    String queryFields = '{id,display_name,taxes_id{id,name},default_code,categ_id{id,name},list_price,qty_available}';
    List<List<dynamic>> filters = [];

    // Add category filter if present
    if (widget.categoryId != null) {
      filters.add(["pos_categ_ids", "=", widget.categoryId]);
    }

    // Add search query filter
    if (_currentSearchQuery.isNotEmpty) {
      filters.add([
        "|", // OR condition for display_name or default_code
        ["display_name", "ilike", _currentSearchQuery],
        ["default_code", "ilike", _currentSearchQuery]
      ]);
    }

    // Add stock filter based on _currentShowOnlyInStock
    if (_currentShowOnlyInStock == true) {
      filters.add(["qty_available", ">", 0]); // In Stock
    } else if (_currentShowOnlyInStock == false) {
      filters.add(["qty_available", "<=", 0]); // Out of Stock
    }
    // If _currentShowOnlyInStock is null, no stock filter is added (shows all)

    // Prepare pagination parameters
    final int limit = _rowsPerPage;
    final int offset = _currentPage * _rowsPerPage;

    // Construct the URL with filters, limit, and offset
    String apiUrl = '${baseurl}api/product.template?query=$queryFields';
    if (filters.isNotEmpty) {
      apiUrl += '&filter=${jsonEncode(filters)}';
    }
    apiUrl += '&limit=$limit&offset=$offset';

    // For total count (assuming your API supports returning count)
    String countApiUrl = '${baseurl}api/product.template?count=true';
    if (filters.isNotEmpty) {
      countApiUrl += '&filter=${jsonEncode(filters)}';
    }

    try {
      // Fetch products
      final response = await http.get(
        Uri.parse(apiUrl),
        headers: {
          HttpHeaders.cookieHeader: sessionId,
          HttpHeaders.contentTypeHeader: 'application/json',
        },
      );

      // Fetch total count
      final countResponse = await http.get(
        Uri.parse(countApiUrl),
        headers: {
          HttpHeaders.cookieHeader: sessionId,
          HttpHeaders.contentTypeHeader: 'application/json',
        },
      );

      if (response.statusCode == 200 && countResponse.statusCode == 200) {
        final jsonProducts = jsonDecode(response.body);
        final jsonCount = jsonDecode(countResponse.body);

        if (jsonProducts['result'] is List && jsonCount['count'] is int) {
          if (mounted) { // Check if the widget is still in the tree
            setState(() {
              products = List<Map<String, dynamic>>.from(jsonProducts['result']);
              _totalProducts = jsonCount['count']; // Set total count from API
            });
          }
        } else {
          showError('Invalid response format for products or count.');
        }
      } else {
        showError('Failed to load products (${response.statusCode}) or count (${countResponse.statusCode})');
      }
    } on SocketException {
      showError('Network unavailable. Please check your internet connection.');
    } catch (e) {
      showError('Error fetching products: $e');
      debugPrint('Error fetching products: $e');
    } finally {
      if (mounted) {
        setState(() {
          _loading = false; // Ensure loading is always set to false
        });
      }
    }
  }


  void showError(String message) {
    if (mounted) {
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  void onSort(int columnIndex, bool ascending) {
    List<Map<String, dynamic>> currentProducts = List.from(products);

    if (columnIndex == 1) { // Product Name
      currentProducts.sort((a, b) {
        final nameA = (a['display_name'] as String? ?? '').toLowerCase();
        final nameB = (b['display_name'] as String? ?? '').toLowerCase();
        return ascending ? nameA.compareTo(nameB) : nameB.compareTo(nameA);
      });
    } else if (columnIndex == 2) { // Product Code
      currentProducts.sort((a, b) {
        final codeA = (a['default_code'] is String && a['default_code'] != 'false' ? a['default_code'] as String : '').toLowerCase();
        final codeB = (b['default_code'] is String && b['default_code'] != 'false' ? b['default_code'] as String : '').toLowerCase();
        return ascending ? codeA.compareTo(codeB) : codeB.compareTo(codeA);
      });
    } else if (columnIndex == 3) { // Price
      currentProducts.sort((a, b) {
        final priceA = (a['list_price'] ?? 0.0).toDouble();
        final priceB = (b['list_price'] ?? 0.0).toDouble();
        return ascending ? priceA.compareTo(priceB) : priceB.compareTo(priceA);
      });
    } else if (columnIndex == 4) { // Stock
      currentProducts.sort((a, b) {
        final stockA = (a['qty_available'] ?? 0).toInt();
        final stockB = (b['qty_available'] ?? 0).toInt();
        return ascending ? stockA.compareTo(stockB) : stockB.compareTo(stockA);
      });
    }

    setState(() {
      products = currentProducts;
      _sortColumnIndex = columnIndex;
      _sortAscending = ascending;
    });
  }

  int get _totalPages {
    if (_totalProducts == 0) return 1;
    return (_totalProducts / _rowsPerPage).ceil();
  }

  @override
  Widget build(BuildContext context) {
    final bool isCompact = MediaQuery.of(context).size.shortestSide < 600;

    final int startIndex = _currentPage * _rowsPerPage;
    final int endIndex = startIndex + products.length;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: const Color.fromARGB(255, 1, 139, 82),
        elevation: 0,
        toolbarHeight: isCompact ? 100 : 120,
        titleSpacing: 0,
        title: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    widget.categoryName ?? 'Products',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: isCompact ? 18 : 22,
                      fontFamily: 'Arial',
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  PopupMenuButton<bool?>(
                    onSelected: (value) {
                      // Only update internal state here
                      setState(() {
                        _currentShowOnlyInStock = value;
                        _setFilterLabel();
                        _currentPage = 0; // Reset to first page when filter changes
                      });
                      fetchProducts(); // Trigger data fetch with new filter
                    },
                    itemBuilder: (context) => const [
                      PopupMenuItem<bool?>(value: null, child: Text('All Products')),
                      PopupMenuItem<bool?>(value: true, child: Text('In Stock Only')),
                      PopupMenuItem<bool?>(value: false, child: Text('Out of Stock Only')),
                    ],
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: isCompact ? 10 : 12, vertical: isCompact ? 5 : 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.25),
                        borderRadius: BorderRadius.circular(25),
                        border: Border.all(color: Colors.white.withOpacity(0.6)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.filter_list, color: Colors.white, size: isCompact ? 18 : 20),
                          SizedBox(width: isCompact ? 6 : 8),
                          Text(
                            _filterLabel,
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: isCompact ? 13 : 15,
                                fontFamily: 'Arial',
                                fontWeight: FontWeight.w500),
                          ),
                          Icon(Icons.arrow_drop_down, color: Colors.white, size: isCompact ? 18 : 20),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: isCompact ? 10 : 12),
              Container(
                height: isCompact ? 40 : 44,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.15),
                      spreadRadius: 0,
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: TextField(
                  controller: _searchController,
                  onChanged: (value) {
                    _currentPage = 0;
                    if (_debounce?.isActive ?? false) _debounce!.cancel();
                    _debounce = Timer(const Duration(milliseconds: 500), () {
                      if (_currentSearchQuery != value.toLowerCase()) {
                        setState(() {
                          _currentSearchQuery = value.toLowerCase();
                        });
                        fetchProducts();
                      }
                    });
                  },
                  decoration: InputDecoration(
                    hintText: 'Search products by name or code...',
                    hintStyle: TextStyle(color: Colors.grey, fontFamily: 'Arial', fontSize: isCompact ? 14 : 15),
                    border: InputBorder.none,
                    prefixIcon: Icon(Icons.search, color: Colors.grey, size: isCompact ? 20 : 22),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: Icon(Icons.clear, color: Colors.grey, size: isCompact ? 20 : 22),
                            onPressed: () {
                              _searchController.clear();
                              setState(() {
                                _currentSearchQuery = '';
                                _currentPage = 0;
                              });
                              fetchProducts();
                            },
                          )
                        : null,
                    contentPadding: EdgeInsets.symmetric(horizontal: 15, vertical: isCompact ? 10 : 12),
                  ),
                  style: TextStyle(fontSize: isCompact ? 15 : 16, fontFamily: 'Arial', color: Colors.black87),
                  textInputAction: TextInputAction.search,
                  onSubmitted: (value) {
                    _debounce?.cancel();
                    if (_currentSearchQuery != value.toLowerCase()) {
                      setState(() {
                        _currentSearchQuery = value.toLowerCase();
                        _currentPage = 0;
                      });
                      fetchProducts();
                    }
                  },
                ),
              ),
            ],
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: _loading
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(color: Color.fromARGB(255, 1, 139, 82)),
                        SizedBox(height: 16),
                        Text('Loading products...', style: TextStyle(fontSize: 16,fontFamily: "Arial", color: Color.fromARGB(255, 43, 42, 42))),
                      ],
                    ),
                  )
                : products.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.search_off, size: 80, color: Colors.grey[300]),
                            const SizedBox(height: 16),
                            Text(
                              _currentSearchQuery.isNotEmpty
                                  ? 'No products found for "${_searchController.text}"'
                                  : 'No products available. Please check back later.',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                            ),
                          ],
                        ),
                      )
                    : SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            minWidth: MediaQuery.of(context).size.width,
                          ),
                          child: SizedBox(
                            height: MediaQuery.of(context).size.height * 0.6,
                            child: SingleChildScrollView(
                              scrollDirection: Axis.vertical,
                              child: DataTable(
                                sortColumnIndex: _sortColumnIndex,
                                sortAscending: _sortAscending,
                                columnSpacing: isCompact ? 10 : 20,
                                dataRowHeight: isCompact ? 60 : 70,
                                headingRowHeight: isCompact ? 50 : 56,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.grey.withOpacity(0.25),
                                      spreadRadius: 1,
                                      blurRadius: 8,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                headingRowColor: MaterialStateProperty.all(Colors.grey[100]),
                                columns: [
                                   DataColumn(
                                    label: const Text('S.No', style: TextStyle(fontWeight: FontWeight.bold,fontFamily: "Arial", fontSize: 15, color: Colors.black87)),
                                  ),
                                  DataColumn(
                                    label: const Text('Product Name', style: TextStyle(fontWeight: FontWeight.bold,fontFamily: "Arial", fontSize: 15, color: Colors.black87)),
                                    onSort: onSort,
                                  ),
                                  DataColumn(
                                    label: const Text('Product Code', style: TextStyle(fontWeight: FontWeight.bold,fontFamily: "Arial", fontSize: 15, color: Colors.black87)),
                                    onSort: onSort,
                                  ),
                                  DataColumn(
                                    label: const Text('Category', style: TextStyle(fontWeight: FontWeight.bold,fontFamily: "Arial", fontSize: 15, color: Colors.black87)),
                                    onSort: onSort,
                                  ),
                                  DataColumn(
                                    label: const Text('Price', style: TextStyle(fontWeight: FontWeight.bold,fontFamily: "Arial", fontSize: 15, color: Colors.black87)),
                                    numeric: true,
                                    onSort: onSort,
                                  ),
                                  DataColumn(
                                    label: const Text('Gst', style: TextStyle(fontWeight: FontWeight.bold,fontFamily: "Arial", fontSize: 15, color: Colors.black87)),
                                    numeric: true,
                                    onSort: onSort,
                                  ),
                                  DataColumn(
                                    label: const Text('Stock', style: TextStyle(fontWeight: FontWeight.bold,fontFamily: "Arial", fontSize: 15, color: Colors.black87)),
                                    numeric: true,
                                    onSort: onSort,
                                  ),
                                  DataColumn(
                                    label: const Text('Actions', style: TextStyle(fontWeight: FontWeight.bold,fontFamily: "Arial", fontSize: 15, color: Colors.black87)),
                                  ),
                                ],
                                rows: products.asMap().entries.map((entry) {
                                  final index = entry.key;
                                  final product = entry.value;
                                  final serialNumber = _currentPage * _rowsPerPage + index + 1;
                                  final price = (product['list_price'] ?? 0.0).toDouble();
                                  final code = product['default_code'] is String && product['default_code'] != 'false'
                                      ? product['default_code'] as String
                                      : '-';
                                  final stock = (product['qty_available']?.toInt() ?? 0).toInt();
                                  final productId = product['id'];
                                  final inCart = widget.addedProductIds.contains(productId);
                                  final unit =
                                      (product['uom_id'] is List && product['uom_id'].length > 1) ? '/${product['uom_id'][1]} técnicos' : '';
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

// print('Category: $category');
// print('Tax List: $taxList');


                                  return DataRow(
                                    cells: [
                                      DataCell(Text(serialNumber.toString(),
                                          style: TextStyle(fontSize: isCompact ? 13 : 14, fontFamily: 'Arial', color: Colors.black87))),
                                     
                                
                                      DataCell(
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                product['display_name'] ?? 'Unnamed',
                                                style: TextStyle(fontSize: isCompact ? 13 : 14, fontFamily: 'Arial', color: Colors.black87),
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      DataCell(Text(code,
                                          style: TextStyle(
                                              fontSize: isCompact ? 13 : 14,
                                              fontFamily: 'Arial',
                                              color: const Color.fromARGB(255, 68, 64, 64)))),
                                      DataCell(Text(category,
                                          style: TextStyle(
                                              fontSize: isCompact ? 13 : 14,
                                              fontFamily: 'Arial',
                                              color: const Color.fromARGB(255, 68, 64, 64)))),        
                                      DataCell(Text('₹${price.toStringAsFixed(2)}$unit',
                                          style: TextStyle(
                                              fontSize: isCompact ? 13 : 14,
                                              fontFamily: 'Arial',
                                              fontWeight: FontWeight.w600,
                                              color: Colors.black87))),
                                    DataCell(Text(taxList,
                                          style: TextStyle(
                                              fontSize: isCompact ? 13 : 14,
                                              fontFamily: 'Arial',
                                              color: const Color.fromARGB(255, 68, 64, 64)))),   
                                      DataCell(
                                        Container(
                                          padding: EdgeInsets.symmetric(horizontal: isCompact ? 8 : 10, vertical: isCompact ? 4 : 6),
                                          decoration: BoxDecoration(
                                            color: stock > 0 ? Colors.green.shade50 : Colors.red.shade50,
                                            borderRadius: BorderRadius.circular(6),
                                            border: Border.all(color: stock > 0 ? Colors.green.shade200 : Colors.red.shade200),
                                          ),
                                          child: Text(
                                            stock > 0 ? '$stock In Stock' : 'Out of Stock',
                                            style: TextStyle(
                                              fontSize: isCompact ? 11 : 13,
                                              fontWeight: FontWeight.w600,
                                              fontFamily: 'Arial',
                                              color: stock > 0 ? Colors.green.shade800 : Colors.red.shade800,
                                            ),
                                          ),
                                        ),
                                      ),
                                      DataCell(
                                        inCart
                                            ? Container(
                                                padding: EdgeInsets.symmetric(horizontal: isCompact ? 10 : 12, vertical: isCompact ? 5 : 6),
                                                decoration: BoxDecoration(
                                                  color: Colors.blue.shade100,
                                                  borderRadius: BorderRadius.circular(8),
                                                  border: Border.all(color: Colors.blue.shade300),
                                                ),
                                                child: Text(
                                                  'In Cart',
                                                  style: TextStyle(
                                                    color: Colors.blueAccent,
                                                    fontSize: isCompact ? 12 : 13,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              )
                                            : ElevatedButton.icon(
                                                onPressed: stock > 0
                                                    ? () {
                                                        widget.onAddToCart({...product, 'quantity': 1});
                                                        setState(() {
                                                          widget.addedProductIds.add(productId);
                                                          cartQuantities[productId] = 1;
                                                        });
                                                      }
                                                    : null,
                                                icon: Icon(Icons.add_shopping_cart,
                                                    size: isCompact ? 16 : 18, color: stock > 0 ? Colors.white : Colors.grey[400]),
                                                label: Text('Add',
                                                    style: TextStyle(
                                                        fontSize: isCompact ? 12 : 14,
                                                        color: stock > 0 ? Colors.white : Colors.grey[400])),
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor:
                                                      stock > 0 ? const Color.fromARGB(255, 1, 139, 82) : Colors.grey[200],
                                                  foregroundColor: Colors.white,
                                                  padding: EdgeInsets.symmetric(horizontal: isCompact ? 10 : 15, vertical: isCompact ? 6 : 8),
                                                  textStyle: const TextStyle(fontFamily: 'Arial'),
                                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                                  elevation: stock > 0 ? 3 : 0,
                                                  shadowColor: Colors.black.withOpacity(0.2),
                                                ),
                                              ),
                                      ),
                                    ],
                                  );
                                }).toList(),
                              ),
                            ),
                          ),
                        ),
                      ),
          ),
          if (!_loading && _totalProducts > 0)
            _buildFooter(
              _totalProducts,
              startIndex,
              endIndex,
              _totalPages,
              isCompact,
            ),
        ],
      ),
    );
  }

  // ... (buildProductImage and _buildFooter methods are the same)
  Widget buildProductImage(dynamic imageData) {
    if (imageData is! String || imageData.isEmpty || imageData == 'false') {
      return Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: const Icon(Icons.inventory_2_outlined, size: 28, color: Colors.grey),
      );
    }
    try {
      return ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: Image.memory(
          base64Decode(imageData),
          fit: BoxFit.cover,
          width: 48,
          height: 48,
          errorBuilder: (context, error, stackTrace) => Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: const Icon(Icons.broken_image, size: 28, color: Colors.grey),
          ),
        ),
      );
    } catch (_) {
      return Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: const Icon(Icons.error_outline, size: 28, color: Colors.grey),
      );
    }
  }

  Widget _buildFooter(
    int totalCount,
    int startIndex,
    int endIndex,
    int totalPages,
    bool isCompact,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      color: Colors.white,
      height: isCompact ? 60 : 70,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Text(
                'Rows per page:',
                style: TextStyle(fontSize: isCompact ? 13 : 14, color: Colors.black87,fontFamily: "Arial",),
              ),
              SizedBox(width: isCompact ? 8 : 10),
              DropdownButton<int>(
                value: _rowsPerPage,
                items: const [
                  DropdownMenuItem(value: 5, child: Text('5')),
                  DropdownMenuItem(value: 10, child: Text('10')),
                  DropdownMenuItem(value: 20, child: Text('20')),
                  DropdownMenuItem(value: 50, child: Text('50')),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _rowsPerPage = value;
                      _currentPage = 0;
                    });
                    fetchProducts();
                  }
                },
                style: TextStyle(fontSize: isCompact ? 13 : 14, color: Colors.black87),
                underline: Container(height: 1, color: Colors.grey),
              ),
            ],
          ),
          Row(
            children: [
              Text(
                '${startIndex + 1}-${endIndex} of $totalCount',
                style: TextStyle(fontSize: isCompact ? 13 : 14, color: Colors.black87),
              ),
              SizedBox(width: isCompact ? 12 : 16),
              IconButton(
                icon: Icon(Icons.chevron_left, size: isCompact ? 24 : 28),
                onPressed: _currentPage > 0
                    ? () {
                        setState(() {
                          _currentPage--;
                        });
                        fetchProducts();
                      }
                    : null,
                color: _currentPage > 0 ? Colors.black87 : Colors.grey,
              ),
              Text(
                '${_currentPage + 1} / $_totalPages',
                style: TextStyle(fontSize: isCompact ? 13 : 14, color: Colors.black87),
              ),
              IconButton(
                icon: Icon(Icons.chevron_right, size: isCompact ? 24 : 28),
                onPressed: _currentPage < totalPages - 1
                    ? () {
                        setState(() {
                          _currentPage++;
                        });
                        fetchProducts();
                      }
                    : null,
                color: _currentPage < totalPages - 1 ? Colors.black87 : Colors.grey,
              ),
            ],
          ),
        ],
      ),
    );
  }
}