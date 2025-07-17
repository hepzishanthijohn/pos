import 'package:flutter/material.dart';
import 'package:rcspos/localdb/orders_sqlite_helper.dart';
import 'package:intl/intl.dart'; // Add this import
import 'dart:io';
import 'package:csv/csv.dart';
import 'package:excel/excel.dart';
import 'package:file_saver/file_saver.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:typed_data';      
import 'package:excel/excel.dart' as xls;
import 'package:excel/excel.dart' as excel_pkg;


class OrderListPage extends StatefulWidget {
  const OrderListPage({Key? key}) : super(key: key);

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
      orderDate = DateTime.parse(order['timestamp']);
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
      final comp = aValue.toString().compareTo(bValue.toString());

      return _sortAscending ? comp : -comp;
    });
}

Future<void> _pickStartDate() async {
  final picked = await  showDatePicker(
    context: context,
    initialDate: DateTime.now(),
    firstDate: DateTime(2000),
    lastDate: DateTime.now(),
  );
  if (picked != null) {
    setState(() {
      _startDate = picked;
      currentPage = 0;
      _fetchOrders(); // Reload with new filter
    });
  }
}

Future<void> _pickEndDate() async {
  final picked = await showDatePicker(
    context: context,
    initialDate: DateTime.now(),
    firstDate: DateTime(2000),
    lastDate: DateTime.now(),
  );
  if (picked != null) {
    setState(() {
      _endDate = picked;
      currentPage = 0;
      _fetchOrders(); // Reload with new filter
    });
  }
}


void _exportCSV() async {
  final rows = <List<dynamic>>[
    ["Order ID", "Customer", "Phone", "Amount", "Date"],
    ..._filteredOrders.map((order) => [
      order['order_id'],
      order['customer_name'],
      order['customer_phone'],
      order['total'],
      order['timestamp'],
    ]),
  ];


  final csvData = const ListToCsvConverter().convert(rows);
  final directory = await getApplicationDocumentsDirectory();
  final path = "${directory.path}/orders.csv";
  final file = File(path);
  await file.writeAsString(csvData);

  await FileSaver.instance.saveFile(
    name: "orders",
    bytes: await file.readAsBytes(),
    mimeType: MimeType.csv,
  );
}

void _exportExcel() async {
  var excel = Excel.createExcel();
  Sheet sheet = excel['Orders'];
  sheet.appendRow(["Order ID", "Customer", "Phone", "Amount", "Date"]);
  for (var order in _filteredOrders) {
    sheet.appendRow([
      order['order_id'],
      order['customer_name'],
      order['customer_phone'],
      order['total'],
      order['timestamp'],
    ]);
  }

  final bytes = excel.encode()!;
  final directory = await getApplicationDocumentsDirectory();
  final path = "${directory.path}/orders.xlsx";
  File(path).writeAsBytesSync(bytes);

  await FileSaver.instance.saveFile(
    name: "orders",
    bytes: Uint8List.fromList(bytes),
    mimeType: MimeType.microsoftExcel,
  );
}

  // Helper function to get cell value based on column index
dynamic _getCellValue(Map<String, dynamic> order, int columnIndex) {
  switch (columnIndex) {
    case 0:
      return order['order_id'];
    case 1:
      return order['customer_name'];
    case 2:
      return order['customer_phone'];
    case 3:
      return order['total'];
    case 4:
      return order['timestamp'];
    default:
      return '';
  }
}

  void _onSort(int columnIndex, bool ascending) {
    setState(() {
      _sortColumnIndex = columnIndex;
      _sortAscending = ascending;
      currentPage = 0; 
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
    _fetchOrders(); // <== ADD THIS LINE TO APPLY FILTER
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
                        setState(() => _searchQuery = value.toLowerCase());
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
  child: Row(
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
  ],
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
                          // --- DataTable Sorting Properties ---
                          sortColumnIndex: _sortColumnIndex,
                          sortAscending: _sortAscending,
                          // --- End DataTable Sorting Properties ---
                          columns: [
                            DataColumn(
                              label: const Text('S.No', style: _headerStyle),
                            
                            ),
                            DataColumn(
                              label: const Text('Order ID', style: _headerStyle),
                            onSort: (columnIndex, ascending) => _onSort(columnIndex, ascending),
 // Pass the onSort handler
                            ),
                            DataColumn(
                              label: const Text('Total', style: _headerStyle),
                              numeric: true, // Mark numeric columns
                            onSort: (columnIndex, ascending) => _onSort(columnIndex, ascending),

                            ),
                            DataColumn(
                              label: const Text('GST', style: _headerStyle),
                              numeric: true, // Mark numeric columns
                            onSort: (columnIndex, ascending) => _onSort(columnIndex, ascending),

                            ),
                            DataColumn(
                              label: const Text('Customer', style: _headerStyle),
                            onSort: (columnIndex, ascending) => _onSort(columnIndex, ascending),

                            ),
                            DataColumn(
                              label: const Text('Phone', style: _headerStyle),
                            onSort: (columnIndex, ascending) => _onSort(columnIndex, ascending),

                            ),
                            DataColumn(
                              label: const Text('Mode', style: _headerStyle),
                            onSort: (columnIndex, ascending) => _onSort(columnIndex, ascending),

                            ),
                            DataColumn(
                              label: const Text('Cash', style: _headerStyle),
                              numeric: true,
                            onSort: (columnIndex, ascending) => _onSort(columnIndex, ascending),

                            ),
                            DataColumn(
                              label: const Text('Bank', style: _headerStyle),
                              numeric: true,
                            onSort: (columnIndex, ascending) => _onSort(columnIndex, ascending),

                            ),
                            DataColumn(
                              label: const Text('Card', style: _headerStyle),
                              numeric: true,
                            onSort: (columnIndex, ascending) => _onSort(columnIndex, ascending),

                            ),
                            DataColumn(
                              label: const Text('Timestamp', style: _headerStyle),
                            onSort: (columnIndex, ascending) => _onSort(columnIndex, ascending),

                            ),


                          ],
                                                 rows: _paginatedOrders.asMap().entries.map((entry) {
                            final int rowIndex = entry.key; // Index within _paginatedOrders
                            final Map<String, dynamic> order = entry.value;

                            // Calculate the S.No.
                            final int serialNumber = (currentPage * rowsPerPage) + rowIndex + 1;

 String formattedTimestamp = '';
                            if (order['timestamp'] is String && order['timestamp'].isNotEmpty) {
                              try {
                                final DateTime dateTime = DateTime.parse(order['timestamp']);
                                // Format for date (dd/MM/yyyy)
                                final String datePart = DateFormat('dd/MM/yyyy').format(dateTime);
                                // Format for time (hh:mm a) - 'a' for AM/PM
                                final String timePart = DateFormat('hh:mm a').format(dateTime);
                                formattedTimestamp = '$datePart $timePart';
                              } catch (e) {
                                // Handle parsing errors, e.g., if timestamp format is unexpected
                                formattedTimestamp = 'Invalid Date';
                                print('Error parsing timestamp: ${order['timestamp']} - $e');
                              }
                            }

          return DataRow(
                              cells: [
                             DataCell(Text(serialNumber.toString())),
                                DataCell(Text(order['order_id'].toString())),
                                DataCell(Text('₹${order['total'].toStringAsFixed(2)}')),
                                DataCell(Text('₹${order['gst'].toStringAsFixed(2)}')),
                                DataCell(Text(order['customer_name'] ?? '')),
                                DataCell(Text(order['customer_phone'] ?? '')),
                                DataCell(Text(order['payment_mode'] ?? '')),
                                DataCell(Text('₹${order['paid_cash'].toStringAsFixed(2)}')),
                                DataCell(Text('₹${order['paid_bank'].toStringAsFixed(2)}')),
                                DataCell(Text('₹${order['paid_card'].toStringAsFixed(2)}')),
                                DataCell(Text(formattedTimestamp)),
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


const TextStyle _headerStyle = TextStyle(
  fontFamily: "Arial",
  fontWeight: FontWeight.w500,
  fontSize: 16,
  color: Colors.white,
); 