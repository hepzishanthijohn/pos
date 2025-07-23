// productstablepage.dart
import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;
import 'package:rcspos/localdb/pdtablesqlitehelper.dart'; // Assuming this is correct
import 'package:rcspos/localdb/product_sqlite_helper.dart';
import 'dart:math';
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
  // Raw data from local DB
  List<Map<String, dynamic>> _allProducts = [];
  // Products after applying search, category, and stock filters (before pagination)
  List<Map<String, dynamic>> _filteredAndSortedProducts = [];
  // Products visible on the current page
  List<Map<String, dynamic>> _paginatedProducts = [];
  int startIndex = 0; // Initialize with a default value
  int endIndex = 0;   // Initialize with a default value

  bool _loading = true;
  Map<int, int> cartQuantities = {}; // Consider if this is still needed here
  int? _sortColumnIndex;
  bool _sortAscending = true;

  final TextEditingController _searchController = TextEditingController();
  String _currentSearchQuery = '';
  String _filterLabel = 'All Products'; // Default label
  bool? _currentShowOnlyInStock; // Internal state for the stock filter
  Timer? _debounce;

  // Pagination Variables
  int _currentPage = 0;
  int _rowsPerPage = 10;
  int _totalFilteredProductsCount = 0; // Total count after filtering, before pagination

  @override
  void initState() {
    super.initState();
    _currentSearchQuery = widget.searchQuery.toLowerCase(); // Ensure lowercase
    _searchController.text = widget.searchQuery;
    _currentShowOnlyInStock = widget.showOnlyInStock; // Initialize from widget

    // Set initial filter label based on parent prop
    _updateFilterLabel(_currentShowOnlyInStock);

    _initializeData();
  }

  @override
  void didUpdateWidget(covariant Productstablepage oldWidget) {
    super.didUpdateWidget(oldWidget);
    bool shouldReapplyFilters = false;

    if (widget.searchQuery.toLowerCase() != _currentSearchQuery) {
      _currentSearchQuery = widget.searchQuery.toLowerCase();
      _searchController.text = widget.searchQuery; // Update controller text
      _currentPage = 0; // Reset page on search change
      shouldReapplyFilters = true;
    }

    if (widget.showOnlyInStock != _currentShowOnlyInStock) {
      _currentShowOnlyInStock = widget.showOnlyInStock;
      _updateFilterLabel(_currentShowOnlyInStock);
      _currentPage = 0; // Reset page on filter change
      shouldReapplyFilters = true;
    }

    if (widget.categoryId != oldWidget.categoryId) {
      _currentPage = 0; // Reset page on category change
      shouldReapplyFilters = true;
    }

    if (shouldReapplyFilters) {
      _applyAllFiltersSortAndPaginate();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  // Helper to update the filter label based on the selected stock filter
  void _updateFilterLabel(bool? showOnlyInStock) {
    if (showOnlyInStock == true) {
      _filterLabel = 'In Stock Only';
    } else if (showOnlyInStock == false) {
      _filterLabel = 'Out of Stock Only';
    } else {
      _filterLabel = 'All Products';
    }
  }


  Future<void> _initializeData() async {
    setState(() => _loading = true);
    await _fetchRawProductsFromLocalDb();
    _applyAllFiltersSortAndPaginate(); // Apply initial filters/sort/paginate
    setState(() => _loading = false);
  }

  // Fetches ALL products from local DB, does NOT apply any filters
  Future<void> _fetchRawProductsFromLocalDb() async {
    try {
      final productDb = ProductSQLiteHelper();
      final localProducts = await productDb.fetchProducts();
      setState(() {
        _allProducts = localProducts;
      });
    } catch (e) {
      showError('Failed to load products: $e');
      setState(() {
        _allProducts = []; // Ensure it's empty on error
      });
    }
  }

  // Central method to apply all filters, then sort, then paginate
  void _applyAllFiltersSortAndPaginate() {
    List<Map<String, dynamic>> tempFiltered = List.from(_allProducts);

    // 1. Apply Search Filter
    if (_currentSearchQuery.isNotEmpty) {
      tempFiltered = tempFiltered.where((product) {
        final name = product['display_name']?.toString().toLowerCase() ?? '';
        final code = product['default_code'] is String && product['default_code'] != 'false'
            ? product['default_code'].toString().toLowerCase()
            : '';
        final query = _currentSearchQuery;
        return name.contains(query) || code.contains(query);
      }).toList();
    }

    // 2. Apply Category Filter
    if (widget.categoryId != null) {
      tempFiltered = tempFiltered.where((product) {
        return product['categ_id'] is List &&
            product['categ_id'].isNotEmpty &&
            product['categ_id'][0] == widget.categoryId;
      }).toList();
    }

    if (_currentShowOnlyInStock != null) {
      tempFiltered = tempFiltered.where((p) {
        final qty = p['qty_available'];
        if (qty is num) {
          return _currentShowOnlyInStock! ? qty > 0 : qty <= 0;
        }
        return false; // Exclude if qty_available is not a number
      }).toList();
    }

    // 4. Sort the filtered products
    _sortData(tempFiltered);

    setState(() {
      _filteredAndSortedProducts = tempFiltered;
      _totalFilteredProductsCount = _filteredAndSortedProducts.length;

      // 5. Paginate
      final int totalPagesAfterFilter = (_totalFilteredProductsCount / _rowsPerPage).ceil();

      // Adjust _currentPage if it's out of bounds after filtering
      if (_currentPage >= totalPagesAfterFilter && totalPagesAfterFilter > 0) {
        _currentPage = totalPagesAfterFilter - 1;
      } else if (totalPagesAfterFilter == 0) {
        _currentPage = 0; // No pages if no products after filtering
      }

      startIndex = _currentPage * _rowsPerPage;
      endIndex = (startIndex + _rowsPerPage).clamp(0, _totalFilteredProductsCount);

      _paginatedProducts = _filteredAndSortedProducts.sublist(startIndex, endIndex);
    });
  }
// Add this method inside your _ProductstablepageState class
void _sortData(List<Map<String, dynamic>> list) {
  if (_sortColumnIndex == null) {
    return; // No column selected for sorting
  }

  list.sort((a, b) {
    dynamic aValue;
    dynamic bValue;

    // Determine values for comparison based on _sortColumnIndex
    // Ensure these column indices match your DataTable columns and their intended sort fields
    switch (_sortColumnIndex) {
      case 1: // Product Name
        aValue = (a['display_name'] as String? ?? '').toLowerCase();
        bValue = (b['display_name'] as String? ?? '').toLowerCase();
        break;
      case 2: // Product Code
        aValue = (a['default_code'] is String && a['default_code'] != 'false' ? a['default_code'] as String : '').toLowerCase();
        bValue = (b['default_code'] is String && b['default_code'] != 'false' ? b['default_code'] as String : '').toLowerCase();
        break;
      case 3: // Category
        aValue = (a['categ_id'] is Map && a['categ_id']['name'] != null)
            ? a['categ_id']['name'].toString().toLowerCase()
            : '';
        bValue = (b['categ_id'] is Map && b['categ_id']['name'] != null)
            ? b['categ_id']['name'].toString().toLowerCase()
            : '';
        break;
      case 4: // Price
        aValue = a['list_price']?.toDouble() ?? 0.0;
        bValue = b['list_price']?.toDouble() ?? 0.0;
        break;
      case 5: // GST (Tax) - sorting by concatenated tax names
        aValue = (a['taxes_id'] is List)
            ? (a['taxes_id'] as List).map((tax) => tax is Map && tax['name'] != null ? tax['name'] as String : '').join(', ')
            : '';
        bValue = (b['taxes_id'] is List)
            ? (b['taxes_id'] as List).map((tax) => tax is Map && tax['name'] != null ? tax['name'] as String : '').join(', ')
            : '';
        break;
      case 6: // Stock
        aValue = a['qty_available']?.toInt() ?? 0;
        bValue = b['qty_available']?.toInt() ?? 0;
        break;
      default:
        // For S.No or any non-sortable/unspecified columns, do nothing
        return 0;
    }

    int comparisonResult;
    if (aValue is String && bValue is String) {
      comparisonResult = aValue.compareTo(bValue);
    } else if (aValue is num && bValue is num) {
      comparisonResult = aValue.compareTo(bValue);
    } else {
      comparisonResult = 0; // Fallback for incomparable types, or handle as an error
    }

    // Apply sorting direction
    return _sortAscending ? comparisonResult : -comparisonResult;
  });
}
  void showError(String message) {
    if (mounted) {
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  // This `onSort` method now sorts `_filteredAndSortedProducts`
  void onSort(int columnIndex, bool ascending) {
    if (columnIndex == 0) return; // S.No is not directly sortable by content

    setState(() {
      _sortColumnIndex = columnIndex;
      _sortAscending = ascending;
      _applyAllFiltersSortAndPaginate(); // Re-apply sort and paginate
    });
  }

  int get _totalPages {
    if (_totalFilteredProductsCount == 0) return 1;
    return (_totalFilteredProductsCount / _rowsPerPage).ceil();
  }

  @override
  Widget build(BuildContext context) {
    final bool isCompact = MediaQuery.of(context).size.shortestSide < 600;

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
                      setState(() {
                        _currentShowOnlyInStock = value;
                        _updateFilterLabel(value); // Update the label here
                        _currentPage = 0; // Reset page on filter change
                      });
                      _applyAllFiltersSortAndPaginate(); // Re-apply all filters
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
                            _filterLabel, // Display the state-managed label
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
                  )
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
                    _currentPage = 0; // Reset page on search change
                    if (_debounce?.isActive ?? false) _debounce!.cancel();
                    _debounce = Timer(const Duration(milliseconds: 500), () {
                      final newQuery = value.toLowerCase();
                      if (_currentSearchQuery != newQuery) {
                        setState(() {
                          _currentSearchQuery = newQuery;
                        });
                        _applyAllFiltersSortAndPaginate(); // Apply filters on debounced search
                      }
                    });
                  },
                  decoration: InputDecoration(
                    hintText: 'Search products by name or code...',
                    hintStyle:
                        TextStyle(color: Colors.grey, fontFamily: 'Arial', fontSize: isCompact ? 14 : 15),
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
                              _applyAllFiltersSortAndPaginate(); // Apply filters when clearing search
                            },
                          )
                        : null,
                    contentPadding: EdgeInsets.symmetric(horizontal: 15, vertical: isCompact ? 10 : 12),
                  ),
                  style: TextStyle(fontSize: isCompact ? 15 : 16, fontFamily: 'Arial', color: Colors.black87),
                  textInputAction: TextInputAction.search,
                  onSubmitted: (value) {
                    _debounce?.cancel(); // Cancel any pending debounce
                    final newQuery = value.toLowerCase();
                    if (_currentSearchQuery != newQuery) {
                      setState(() {
                        _currentSearchQuery = newQuery;
                        _currentPage = 0;
                      });
                      _applyAllFiltersSortAndPaginate(); // Apply filters on submit
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
            child: _loading // Assuming _loading is a state variable
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(color: Color.fromARGB(255, 1, 139, 82)),
                        SizedBox(height: 16),
                        Text('Loading products...',
                            style: TextStyle(fontSize: 16, fontFamily: "Arial", color: Color.fromARGB(255, 43, 42, 42))),
                      ],
                    ),
                  )
                : _totalFilteredProductsCount == 0 && _currentSearchQuery.isEmpty && widget.categoryId == null && _currentShowOnlyInStock == null
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.widgets_outlined, size: 80, color: Colors.grey[300]),
                            const SizedBox(height: 16),
                            Text(
                              'No products available. Please check back later.',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                            ),
                          ],
                        ),
                      )
                    : _totalFilteredProductsCount == 0
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.search_off, size: 80, color: Colors.grey[300]),
                                const SizedBox(height: 16),
                                Text(
                                  _currentSearchQuery.isNotEmpty
                                      ? 'No products found for "${_searchController.text}"'
                                      : 'No products match your current filters.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                                ),
                              ],
                            ),
                          )
                        : SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: ConstrainedBox(
                              constraints: BoxConstraints(minWidth: MediaQuery.of(context).size.width),
                              child: SizedBox(
                                height: MediaQuery.of(context).size.height -
                                    AppBar().preferredSize.height -
                                    MediaQuery.of(context).padding.top -
                                    (isCompact ? 100 : 120), // Adjusted height calculation
                                child: SingleChildScrollView(
                                  scrollDirection: Axis.vertical,
                                  child: DataTable(
                                    headingRowColor: MaterialStateColor.resolveWith(
                                      (states) => const Color.fromARGB(255, 8, 72, 150),
                                    ),
                                    columnSpacing: 30,
                                    sortColumnIndex: _sortColumnIndex,
                                    sortAscending: _sortAscending,
                                    columns: [
                                      DataColumn(label: Text('S.No', style: _headerStyle)),
                                      DataColumn(label: Text('Product Name', style: _headerStyle), onSort: onSort),
                                      DataColumn(label: Text('Product Code', style: _headerStyle), onSort: onSort),
                                      DataColumn(label: Text('Category', style: _headerStyle), onSort: onSort),
                                      DataColumn(label: Text('Price', style: _headerStyle), numeric: true, onSort: onSort),
                                      DataColumn(label: Text('Gst', style: _headerStyle), numeric: true, onSort: onSort),
                                      DataColumn(label: Text('Stock', style: _headerStyle), numeric: true, onSort: onSort),
                                      DataColumn(label: Text('Actions', style: _headerStyle)),
                                    ],
                                    rows: _paginatedProducts.asMap().entries.map((entry) {
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
                                      final unit = (product['uom_id'] is List && product['uom_id'].length > 1)
                                          ? '/${product['uom_id'][1]} técnicos'
                                          : '';
                                      final category = product['categ_id'] is Map && product['categ_id']['name'] != null
                                          ? product['categ_id']['name'] as String
                                          : 'No Category';

                                      final taxListRaw = (product['taxes_id'] is List)
                                          ? (product['taxes_id'] as List)
                                              .map((tax) {
                                                if (tax is Map && tax['name'] != null) {
                                                  return tax['name'] as String;
                                                } else if (tax is int) {
                                                  return 'Tax ID: $tax';
                                                }
                                                return 'N/A Tax Item';
                                              })
                                              .where((name) => name != 'N/A Tax Item' && !name.startsWith('Tax ID: '))
                                              .join(', ')
                                          : "s";

                                      final taxList = taxListRaw.isNotEmpty ? taxListRaw : 'No Tax';

                                      return DataRow(
                                        cells: [
                                          DataCell(Text(serialNumber.toString())),
                                          DataCell(Text(product['display_name'] ?? 'Unnamed')),
                                          DataCell(Text(code)),
                                          DataCell(Text(category)),
                                          DataCell(Text('₹${price.toStringAsFixed(2)}$unit')),
                                          DataCell(Text(taxList)),
                                          DataCell(
                                            Container(
                                              padding: EdgeInsets.symmetric(
                                                  horizontal: isCompact ? 8 : 10, vertical: isCompact ? 4 : 6),
                                              decoration: BoxDecoration(
                                                color: stock > 0 ? Colors.green.shade50 : Colors.red.shade50,
                                                borderRadius: BorderRadius.circular(6),
                                                border:
                                                    Border.all(color: stock > 0 ? Colors.green.shade200 : Colors.red.shade200),
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
                                            IconButton(
                                              icon: const Icon(Icons.remove_red_eye),
                                              onPressed: () {
                                                showDialog(
                                                  context: context,
                                                  builder: (_) => AlertDialog(
                                                    title: Text(product['display_name'] ?? 'No name'),
                                                    content: Column(
                                                      mainAxisSize: MainAxisSize.min,
                                                      crossAxisAlignment: CrossAxisAlignment.start,
                                                      children: [
                                                        Text("Price: ₹${product['list_price'] ?? '0'}"),
                                                        Text(
                                                            "Category: ${category}"), // Use already parsed category
                                                        Text("Taxes: ${taxList}"), // Use already parsed taxList
                                                        Text("Stock: ${stock}"),
                                                      ],
                                                    ),
                                                    actions: [
                                                      TextButton(
                                                        onPressed: () => Navigator.pop(context),
                                                        child: const Text("Close"),
                                                      )
                                                    ],
                                                  ),
                                                );
                                              },
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
          if (!_loading && _totalFilteredProductsCount > 0)
            _buildFooter(
              _totalFilteredProductsCount,
              startIndex,
              endIndex,
              _totalPages,
              isCompact,
            ),
        ],
      ),
    );
  }

  // --- Footer Widget Method ---
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
                style: TextStyle(fontSize: isCompact ? 13 : 14, color: Colors.black87, fontFamily: "Arial"),
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
                      _currentPage = 0; // Reset to first page
                    });
                    _applyAllFiltersSortAndPaginate(); // Re-apply filters
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
                        _applyAllFiltersSortAndPaginate(); // Go to previous page
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
                        _applyAllFiltersSortAndPaginate(); // Go to next page
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

const TextStyle _headerStyle = TextStyle(
  fontFamily: "Arial",
  fontWeight: FontWeight.w500,
  fontSize: 16,
  color: Colors.white,
);