import 'package:flutter/material.dart';

import 'package:rcspos/localdb/orders_sqlite_helper.dart';
import 'package:intl/intl.dart'; // Add this import
import 'dart:io';
import 'dart:convert';
import 'package:csv/csv.dart';
import 'package:excel/excel.dart';
import 'package:file_saver/file_saver.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:typed_data';

import 'package:rcspos/screens/InvoiceDetailspage.dart';
import 'package:rcspos/screens/purchaseDetails.dart';

// Consistent header style for DataTable
const TextStyle _headerStyle = TextStyle(
  fontFamily: "Arial",
  fontWeight: FontWeight.w500,
  fontSize: 16,
  color: Colors.white,
);

class OrderListPage extends StatefulWidget {
  
  
  const OrderListPage({Key? key,}) : super(key: key);

  @override
  State<OrderListPage> createState() => _OrderListPageState();
}

class _OrderListPageState extends State<OrderListPage> {
  
  List<Map<String, dynamic>> _orders = [];
  String _searchQuery = '';
  int currentPage = 0;
  int rowsPerPage = 10;

  // --- Sorting State Variables ---
  int? _sortColumnIndex;
  bool _sortAscending = true;
  // --- End Sorting State Variables ---

  DateTime? _startDate;
  DateTime? _endDate;

  List<Map<String, dynamic>> get _filteredOrders {
    return _orders.where((order) {
      final searchMatch =
          order['order_id'].toString().toLowerCase().contains(_searchQuery) ||
              order['customer_name'].toString().toLowerCase().contains(_searchQuery) ||
              order['customer_phone'].toString().toLowerCase().contains(_searchQuery);

      DateTime orderDate;
      try {
        // Use 'date' if your database stores it as 'date', otherwise 'timestamp'
        // Based on the SQLite output, it's the 11th column, which would be 'date' if you followed my previous advice.
        orderDate = DateTime.parse(order['date'] ?? order['timestamp']); // Use 'date' preference, fallback to 'timestamp'
      } catch (_) {
        return false; // Skip invalid dates
      }

      // Convert to just the date (ignore time)
      final orderDateOnly = DateTime(orderDate.year, orderDate.month, orderDate.day);

      final withinStart = _startDate == null ||
          orderDateOnly.isAtSameMomentAs(DateTime(_startDate!.year, _startDate!.month, _startDate!.day)) ||
          orderDateOnly.isAfter(DateTime(_startDate!.year, _startDate!.month, _startDate!.day));

      final withinEnd = _endDate == null ||
          orderDateOnly.isAtSameMomentAs(DateTime(_endDate!.year, _endDate!.month, _endDate!.day)) ||
          orderDateOnly.isBefore(DateTime(_endDate!.year, _endDate!.month, _endDate!.day).add(const Duration(days: 1)));

      return searchMatch && withinStart && withinEnd;
    }).toList()
      ..sort((a, b) {
        if (_sortColumnIndex == null) return 0;

        final aValue = _getCellValue(a, _sortColumnIndex!);
        final bValue = _getCellValue(b, _sortColumnIndex!);

        // Handle specific types for robust comparison
        if (aValue is Comparable && bValue is Comparable) {
          final comp = aValue.compareTo(bValue);
          return _sortAscending ? comp : -comp;
        } else {
          // Fallback to string comparison for non-comparable types
          final comp = aValue.toString().compareTo(bValue.toString());
          return _sortAscending ? comp : -comp;
        }
      });
  }
void _showOrderDetailsDialog(BuildContext context, Map<String, dynamic> order) {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: Text("Order #${order['order_id']}"),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDetailRow("Customer Name", order['customer_name']),
            _buildDetailRow("Phone", order['customer_phone']),
            _buildDetailRow("Total Amount", order['total'].toString()),
            _buildDetailRow("Tax", order['tax'].toString()),
            _buildDetailRow("Payment Method", order['payment_method']),
            _buildDetailRow("Paid Amount", order['paid_amount'].toString()),
            _buildDetailRow("Change Amount", order['change_amount'].toString()),
            _buildDetailRow("Discount", order['discount'].toString()),
            _buildDetailRow(
              "Date",
              DateFormat('yyyy-MM-dd HH:mm:ss').format(
                DateTime.parse(order['date'] ?? order['timestamp']),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("Close"),
        ),
      ],
    ),
  );
}

  Future<void> _pickStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        _startDate = picked;
        currentPage = 0;
        // _fetchOrders() is called via _filteredOrders getter
      });
    }
  }

  Future<void> _pickEndDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _endDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        _endDate = picked;
        currentPage = 0;
        // _fetchOrders() is called via _filteredOrders getter
      });
    }
  }

  // Helper for requesting storage permissions
  Future<bool> _requestStoragePermission() async {
    if (Platform.isAndroid) {
      var status = await Permission.storage.status;
      if (!status.isGranted) {
        status = await Permission.storage.request();
        return status.isGranted;
      }
    }
    return true; // Permissions not needed for other platforms or already granted
  }

  void _exportCSV() async {
    if (!await _requestStoragePermission()) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Storage permission denied. Cannot export file.')),
        );
      }
      return;
    }

    final rows = <List<dynamic>>[
      ["Order ID", "Customer", "Phone", "Total Amount", "Tax", "Payment Method", "Paid Amount", "Change Amount", "Discount", "Date"],
      ..._filteredOrders.map((order) => [
            order['order_id'],
            order['customer_name'],
            order['customer_phone'],
            order['total'],
            order['tax'],
            order['payment_method'],
            order['paid_amount'],
            order['change_amount'],
            order['discount'],
            // Use 'date' if available, otherwise 'timestamp'
            DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.parse(order['date'] ?? order['timestamp'])),
          ]),
    ];

    final csvData = const ListToCsvConverter().convert(rows);
    final directory = await getApplicationDocumentsDirectory();
    final path = "${directory.path}/orders_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.csv";
    final file = File(path);
    await file.writeAsString(csvData);

    await FileSaver.instance.saveFile(
      name: "orders_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}",
      bytes: await file.readAsBytes(),
      mimeType: MimeType.csv,
 
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Orders exported to CSV: $path')),
      );
    }
  }

  void _exportExcel() async {
    if (!await _requestStoragePermission()) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Storage permission denied. Cannot export file.')),
        );
      }
      return;
    }

    var excel = Excel.createExcel();
    Sheet sheet = excel['Orders'];
    sheet.appendRow(["Order ID", "Customer", "Phone", "Total Amount", "Tax", "Payment Method", "Paid Amount", "Change Amount", "Discount", "Date"]);

    for (var order in _filteredOrders) {
      sheet.appendRow([
        order['order_id'],
        order['customer_name'],
        order['customer_phone'],
        order['total'],
        order['tax'],
        order['payment_method'],
        order['paid_amount'],
        order['change_amount'],
        order['discount'],
        // Use 'date' if available, otherwise 'timestamp'
        DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.parse(order['date'] ?? order['timestamp'])),
      ]);
    }

    final bytes = excel.encode()!;
    final directory = await getApplicationDocumentsDirectory();
    final path = "${directory.path}/orders_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.xlsx";
    File(path).writeAsBytesSync(bytes);

    await FileSaver.instance.saveFile(
      name: "orders_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}",
      bytes: Uint8List.fromList(bytes),
      mimeType: MimeType.microsoftExcel,
   
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Orders exported to Excel: $path')),
      );
    }
  }

  // Helper function to get cell value based on column index
  // Updated to match the DataTable columns and infer paid amounts
  dynamic _getCellValue(Map<String, dynamic> order, int columnIndex) {
    switch (columnIndex) {
      case 1: // Order ID
        return order['order_id'];
      case 2: // Total
        return order['total'];
      case 3: // GST (Tax)
        return order['tax'];
      case 4: // Customer
        return order['customer_name'];
      case 5: // Phone
        return order['customer_phone'];
      case 6: // Mode (Payment Method)
        return order['payment_method'];
      case 7: // Cash (inferred)
        return order['payment_method'] == 'Cash' ? order['paid_amount'] : 0.0;
      case 8: // Bank (inferred)
        return order['payment_method'] == 'Bank' ? order['paid_amount'] : 0.0;
      case 9: // Card (inferred)
        return order['payment_method'] == 'Card' ? order['paid_amount'] : 0.0;
      case 10: // Timestamp
        try {
          return DateTime.parse(order['date'] ?? order['timestamp']);
        } catch (_) {
          return DateTime(0); // Return a default, early date for invalid entries for sorting
        }
      default:
        return '';
    }
  }

  void _onSort(int columnIndex, bool ascending) {
    setState(() {
      _sortColumnIndex = columnIndex;
      _sortAscending = ascending;
      currentPage = 0; // Reset pagination when sorting
    });
  }

  List<Map<String, dynamic>> get _paginatedOrders {
    final start = currentPage * rowsPerPage;
    final end = (start + rowsPerPage).clamp(0, _filteredOrders.length);
    return _filteredOrders.sublist(start, end);
  }

  @override
  void initState() {
    super.initState();
    _fetchOrders();
  }

  Future<void> _fetchOrders() async {
    final orders = await OrderSQLiteHelper().getAllOrders();
    setState(() {
      _orders = orders;
    });
  }

  @override
  Widget build(BuildContext context) {
    
    return Scaffold(
      backgroundColor: Colors.grey[100],
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
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                      const Text(
                        'Orders Details',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontFamily: 'Arial',
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      PopupMenuButton<String>(
                        onSelected: (value) {
                          setState(() {
                            if (value == 'All') {
                              _startDate = null;
                              _endDate = null;
                            } else if (value == 'Today') {
                              final now = DateTime.now();
                              _startDate = DateTime(now.year, now.month, now.day);
                              _endDate = _startDate;
                            }
                            currentPage = 0; // Reset pagination
                            // _fetchOrders() is not needed here as _filteredOrders getter will re-evaluate
                          });
                        },
                        itemBuilder: (context) => const [
                          PopupMenuItem(value: 'All', child: Text('All')),
                          PopupMenuItem(value: 'Today', child: Text('Today')),
                        ],
                        child: Row(
                          children: const [
                            Icon(Icons.filter_list, color: Colors.white, size: 18),
                            SizedBox(width: 6),
                            Text('Filter', style: TextStyle(color: Colors.white)),
                            Icon(Icons.arrow_drop_down, color: Colors.white),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Container(
                    height: 43,
                    margin: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: TextField(
                      onChanged: (value) {
                        setState(() {
                          _searchQuery = value.toLowerCase();
                          currentPage = 0; // Reset pagination on search
                        });
                      },
                      decoration: const InputDecoration(
                        hintText: 'Search Orders...',
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
      body: _orders.isEmpty
          ? const Center(child: Text('No orders found.'))
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 8),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      return Wrap(
                        spacing: 12,
                        runSpacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          ElevatedButton.icon(
                            icon: const Icon(Icons.date_range),
                            label: Text(
                              _startDate != null
                                  ? DateFormat('dd/MM/yyyy').format(_startDate!)
                                  : "Start Date",
                            ),
                            onPressed: _pickStartDate,
                          ),
                          ElevatedButton.icon(
                            icon: const Icon(Icons.date_range),
                            label: Text(
                              _endDate != null
                                  ? DateFormat('dd/MM/yyyy').format(_endDate!)
                                  : "End Date",
                            ),
                            onPressed: _pickEndDate,
                          ),
                          if (_startDate != null || _endDate != null)
                            TextButton(
                              onPressed: () {
                                setState(() {
                                  _startDate = null;
                                  _endDate = null;
                                  currentPage = 0; // Reset pagination
                                });
                              },
                              child: const Text('Clear Dates'),
                            ),
                          ElevatedButton.icon(
                            icon: const Icon(Icons.file_download),
                            label: const Text("Export CSV"),
                            onPressed: _exportCSV,
                          ),
                          ElevatedButton.icon(
                            icon: const Icon(Icons.file_download),
                            label: const Text("Export Excel"),
                            onPressed: _exportExcel,
                          ),
                        ],
                      );
                    },
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.vertical,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(minWidth: MediaQuery.of(context).size.width),
                        child: DataTable(
                          headingRowColor: MaterialStateColor.resolveWith(
                            (states) => const Color.fromARGB(255, 8, 72, 150),
                          ),
                          columnSpacing: 30,
                          sortColumnIndex: _sortColumnIndex,
                          sortAscending: _sortAscending,
                          columns: [
                            DataColumn(
                              label: Text('S.No', style: _headerStyle),
                            ),
                            DataColumn(
                              label: Text('Order ID', style: _headerStyle),
                              onSort: (columnIndex, ascending) => _onSort(columnIndex, ascending),
                            ),
                            DataColumn(
                              label: Text('Total', style: _headerStyle),
                              numeric: true,
                              onSort: (columnIndex, ascending) => _onSort(columnIndex, ascending),
                            ),
                            DataColumn(
                              label: Text('GST', style: _headerStyle),
                              numeric: true,
                              onSort: (columnIndex, ascending) => _onSort(columnIndex, ascending),
                            ),
                            DataColumn(
                              label: Text('Customer', style: _headerStyle),
                              onSort: (columnIndex, ascending) => _onSort(columnIndex, ascending),
                            ),
                            DataColumn(
                              label: Text('Phone', style: _headerStyle),
                              onSort: (columnIndex, ascending) => _onSort(columnIndex, ascending),
                            ),
                            DataColumn(
                              label: Text('Mode', style: _headerStyle),
                              onSort: (columnIndex, ascending) => _onSort(columnIndex, ascending),
                            ),
                            DataColumn(
                              label: Text('Cash', style: _headerStyle),
                              numeric: true,
                              onSort: (columnIndex, ascending) => _onSort(columnIndex, ascending),
                            ),
                            DataColumn(
                              label: Text('Bank', style: _headerStyle),
                              numeric: true,
                              onSort: (columnIndex, ascending) => _onSort(columnIndex, ascending),
                            ),
                            DataColumn(
                              label: Text('Card', style: _headerStyle),
                              numeric: true,
                              onSort: (columnIndex, ascending) => _onSort(columnIndex, ascending),
                            ),
                            DataColumn(
                              label: Text('Time', style: _headerStyle),
                              onSort: (columnIndex, ascending) => _onSort(columnIndex, ascending),
                            ),
                             DataColumn(
                              label: Text('Actions', style: _headerStyle),
                              
                            ),
                          ],
                          rows: _paginatedOrders.asMap().entries.map((entry) {
                            final int rowIndex = entry.key; // Index within _paginatedOrders
                            final Map<String, dynamic> order = entry.value;

                            // Calculate the S.No.
                            final int serialNumber = (currentPage * rowsPerPage) + rowIndex + 1;

                            String formattedTimestamp = '';
                            // Try 'date' first, then 'timestamp' for consistency with potential schema changes
                            String? dateString = order['date'] ?? order['timestamp'];
                            if (dateString is String && dateString.isNotEmpty) {
                              try {
                                final DateTime dateTime = DateTime.parse(dateString);
                                final String datePart = DateFormat('dd/MM/yyyy').format(dateTime);
                                final String timePart = DateFormat('hh:mm a').format(dateTime);
                                formattedTimestamp = '$datePart $timePart';
                              } catch (e) {
                                formattedTimestamp = 'Invalid Date';
                                debugPrint('Error parsing timestamp: $dateString - $e'); // Use debugPrint for logs
                              }
                            }

                            return DataRow(
                              cells: [
                                DataCell(Text(serialNumber.toString())),
                                DataCell(Text(order['order_id']?.toString() ?? '')),
                                DataCell(Text('₹${(order['total'] ?? 0.0).toStringAsFixed(2)}')),
                                DataCell(Text('₹${(order['tax'] ?? 0.0).toStringAsFixed(2)}')),
                                DataCell(Text(order['customer_name']?.toString() ?? '')),
                                DataCell(Text(order['customer_phone']?.toString() ?? '')),
                                DataCell(Text(order['payment_method']?.toString() ?? '')),
                                // Infer paid amounts based on payment_method
                                DataCell(Text('₹${order['payment_method'] == 'Cash' ? (order['paid_amount'] ?? 0.0).toStringAsFixed(2) : '0.00'}')),
                                DataCell(Text('₹${order['payment_method'] == 'Bank' ? (order['paid_amount'] ?? 0.0).toStringAsFixed(2) : '0.00'}')),
                                DataCell(Text('₹${order['payment_method'] == 'Card' ? (order['paid_amount'] ?? 0.0).toStringAsFixed(2) : '0.00'}')),
                                DataCell(Text(formattedTimestamp)),
                                DataCell(Row(children: [const SizedBox(width: 8),
IconButton(
  icon: const Icon(Icons.visibility),
  tooltip: 'View',
 onPressed: () {
  final orderId = order['order_id'].toString();
  debugPrint("🛒 Navigating to PurchaseDetailsPage for Order ID: $orderId");

  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => PurchaseDetailsPage(orderId: orderId),
    ),
  );
},

)

],),),

                              ],
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  ),
                ),
                _buildFooter(
                  _filteredOrders.length,
                  currentPage * rowsPerPage,
                  (currentPage * rowsPerPage + _paginatedOrders.length).clamp(0, _filteredOrders.length),
                  (_filteredOrders.length / rowsPerPage).ceil(),
                ),
              ],
            ),
    );
  }

  Widget _buildFooter(int total, int start, int end, int totalPages) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(8)),
      ),
      child: Row(
        children: [
          Row(
            children: [
              const Text("Rows per page:",
                  style: TextStyle(fontFamily: 'Arial', fontSize: 13, color: Colors.black87)),
              const SizedBox(width: 8),
              DropdownButton<int>(
                value: rowsPerPage,
                items: [5, 10, 20, 50].map((e) {
                  return DropdownMenuItem(
                    value: e,
                    child: Text(e.toString(), style: const TextStyle(fontFamily: 'Arial')),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      rowsPerPage = value;
                      currentPage = 0;
                    });
                  }
                },
                style: const TextStyle(fontFamily: 'Arial', color: Colors.black87),
                icon: const Icon(Icons.arrow_drop_down, color: Color.fromARGB(255, 1, 129, 91)),
                underline: const SizedBox.shrink(),
              ),
            ],
          ),
          const Spacer(),
          Text(
            "${start + 1}–$end of $total",
            style: const TextStyle(fontFamily: 'Arial', fontSize: 13, color: Colors.black87),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: currentPage > 0
                ? () => setState(() {
                      currentPage--;
                    })
                : null,
            color: const Color.fromARGB(255, 1, 129, 91),
            disabledColor: Colors.grey[400],
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: (currentPage + 1) < (_filteredOrders.length / rowsPerPage).ceil()
                ? () => setState(() {
                      currentPage++;
                    })
                : null,
            color: const Color.fromARGB(255, 1, 129, 91),
            disabledColor: Colors.grey[400],
          ),
        ],
      ),
    );
  }
}


Widget _buildDetailRow(String title, String value) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 4.0),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "$title: ",
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        Expanded(child: Text(value)),
      ],
    ),
  );
}
