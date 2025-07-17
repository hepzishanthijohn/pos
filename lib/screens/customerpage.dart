import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;
import 'package:rcspos/localdb/customersqlitehelper.dart';
import 'package:rcspos/screens/createcustomer.dart';
import 'package:rcspos/screens/editcustomer.dart';
import 'package:rcspos/screens/home.dart';
import 'package:rcspos/utils/urls.dart';
import 'package:flutter/services.dart'; 


class Customer {
  final int id;
  final String name;
  final String? email;
  final String? phone;
  final String contactAddress;
  final String companyType;

  Customer({
    required this.id,
    required this.name,
    this.email,
    this.phone,
    required this.contactAddress,
    required this.companyType,
  });

  factory Customer.fromJson(Map<String, dynamic> json) {
    return Customer(
      id: json['id'],
      name: json['name'] ?? '',
      email: json['email'] == false ? null : json['email'],
      phone: json['phone'] == false ? null : json['phone'],
      contactAddress: json['contact_address'] ?? '',
      companyType: json['company_type'] ?? 'person', // Default to 'person' if not provided
    );
  }
}

class CustomerPage extends StatefulWidget {
  const CustomerPage({Key? key}) : super(key: key);

  @override
  State<CustomerPage> createState() => _CustomerPageState();
}

class _CustomerPageState extends State<CustomerPage> {
  List<Customer> customers = [];
  int? _selectedCustomerId;
  int rowsPerPage = 10;
  int currentPage = 0;
  int? _sortColumnIndex;
  bool _sortAscending = true;
  String _searchQuery = '';
  String _companyFilter = 'all';
  bool isLoading = false;

  // State to hold IDs of selected customers
  final Set<int> _selectedCustomerIds = {};


  final ScrollController _horizontalHeaderScrollController = ScrollController();
final ScrollController _horizontalListScrollController = ScrollController();


// You might already have this for vertical scrolling, but ensure it's here
final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    fetchCustomers();
     // Synchronize horizontal scroll controllers
  _horizontalHeaderScrollController.addListener(() {
    if (_horizontalHeaderScrollController.offset != _horizontalListScrollController.offset) {
      _horizontalListScrollController.jumpTo(_horizontalHeaderScrollController.offset);
    }
  });

  _horizontalListScrollController.addListener(() {
    if (_horizontalListScrollController.offset != _horizontalHeaderScrollController.offset) {
      _horizontalHeaderScrollController.jumpTo(_horizontalListScrollController.offset);
    }
  });
  }

  @override
  void dispose() {
 _horizontalHeaderScrollController.dispose();
  _horizontalListScrollController.dispose();
  _scrollController.dispose();
    super.dispose();
  }

final Customersqlitehelper customerDbHelper = Customersqlitehelper();

Future<void> fetchCustomers() async {
  setState(() {
    isLoading = true;
    _selectedCustomerIds.clear();
  });

  final box = await Hive.openBox('login');
  final rawSession = box.get('session_id');

  if (rawSession == null) {
    setState(() => isLoading = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Session not found. Please log in again.', style: TextStyle(fontFamily: 'Arial')),
      ),
    );
    return;
  }

  await customerDbHelper.init(); // ✅ Ensure SQLite is ready

  final sessionId = rawSession.contains('session_id=') ? rawSession : 'session_id=$rawSession';
  final url = Uri.parse('$baseurl/api/res.partner?query={id,name,email,phone,contact_address,company_type}&filter=[["customer_rank",">=",0]]');

  try {
    final response = await http.get(url, headers: {
      HttpHeaders.cookieHeader: sessionId,
      HttpHeaders.contentTypeHeader: 'application/json',
    });

    if (response.statusCode == 200) {
      final result = json.decode(response.body)['result'];
      final List<Map<String, dynamic>> rawList = List<Map<String, dynamic>>.from(result);

      // ✅ Save to SQLite
      await customerDbHelper.insertCustomers(rawList);

      setState(() {
        customers = rawList.map((e) => Customer.fromJson(e)).toList();
        currentPage = 0;
        _sortColumnIndex = null;
        _sortAscending = true;
      });

     customerDbHelper.debugPrintAllCustomers();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to load customers: ${response.body}', style: const TextStyle(fontFamily: 'Arial')),
          backgroundColor: Colors.red,
        ),
      );
    }
  } catch (e) {
    debugPrint("Network error while fetching customers: $e");

    // 🔌 Offline fallback from SQLite
    final fallback = customerDbHelper.fetchCustomers();
    if (fallback.isNotEmpty) {
      setState(() {
        customers = fallback.map((e) => Customer.fromJson(e)).toList();
        currentPage = 0;
        _sortColumnIndex = null;
        _sortAscending = true;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Loaded customers from local SQLite cache.', style: TextStyle(fontFamily: 'Arial')),
          backgroundColor: Colors.orange,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Network error: $e', style: const TextStyle(fontFamily: 'Arial')),
          backgroundColor: Colors.red,
        ),
      );
    }
  } finally {
    setState(() => isLoading = false);
  }
}

  void _sort(int columnIndex, bool ascending) {
    setState(() {
      _sortColumnIndex = columnIndex;
      _sortAscending = ascending;
      currentPage = 0; // Reset pagination when sorting changes
      _selectedCustomerIds.clear(); // Clear selections on sort change
    });
  }

  void _downloadAsPDF() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Downloading as PDF...', style: TextStyle(fontFamily: 'Arial'))),
    );
    debugPrint("Download as PDF tapped");
    // TODO: Implement actual PDF generation
    // You can access selected customer IDs via _selectedCustomerIds if needed for specific downloads
  }

  void _downloadAsExcel() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Downloading as Excel...', style: TextStyle(fontFamily: 'Arial'))),
    );
    debugPrint("Download as Excel tapped");
 }

  void _showDownloadOptions() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Download as', style: TextStyle(fontFamily: 'Arial', fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.picture_as_pdf, color: Color.fromARGB(255, 1, 129, 91)),
                title: const Text('PDF', style: TextStyle(fontFamily: 'Arial')),
                onTap: () {
                  Navigator.pop(context); // close dialog
                  _downloadAsPDF(); // call your PDF logic
                },
              ),
              ListTile(
                leading: const Icon(Icons.grid_on, color: Color.fromARGB(255, 1, 129, 91)),
                title: const Text('Excel', style: TextStyle(fontFamily: 'Arial')),
                onTap: () {
                  Navigator.pop(context);
                  _downloadAsExcel(); // call your Excel logic
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _confirmDeleteCustomer(Customer customer) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Deletion', style: TextStyle(fontFamily: 'Arial', fontWeight: FontWeight.bold)),
        content: Text('Are you sure you want to delete ${customer.name}?', style: const TextStyle(fontFamily: 'Arial')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            style: TextButton.styleFrom(
              foregroundColor: Colors.grey[700],
              textStyle: const TextStyle(fontFamily: 'Arial', fontSize: 16),
            ),
            child: const Text('Cancel', style: TextStyle(fontFamily: 'Arial')),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx); // Close dialog
              await _deleteCustomer(customer.id); // Call delete API
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              textStyle: const TextStyle(fontFamily: 'Arial', fontSize: 16, fontWeight: FontWeight.bold),
            ),
            child: const Text('Delete', style: TextStyle(fontFamily: 'Arial')),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteCustomer(int customerId) async {
    final box = await Hive.openBox('login');
    final rawSession = box.get('session_id');
    if (rawSession == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Session not found.', style: TextStyle(fontFamily: 'Arial'))),
      );
      return;
    }
    final sessionId = rawSession.contains('session_id=') ? rawSession : 'session_id=$rawSession';

    final url = Uri.parse('$baseurl/mobile/delete_customer/$customerId'); // Assuming a delete endpoint
    try {
      final response = await http.delete(
        url,
        headers: {
          HttpHeaders.cookieHeader: sessionId,
          HttpHeaders.contentTypeHeader: 'application/json',
        },
      );

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Customer deleted successfully!', style: TextStyle(fontFamily: 'Arial')), backgroundColor: Colors.green),
        );
        fetchCustomers(); // Refresh the list
      } else {
        final error = json.decode(response.body)['error']['message'] ?? 'Unknown error';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete customer: $error', style: TextStyle(fontFamily: 'Arial')), backgroundColor: Colors.red),
        );
        debugPrint('Error response: ${response.body}');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('An error occurred: $e', style: TextStyle(fontFamily: 'Arial'))),
      );
      debugPrint('Exception during customer deletion: $e');
    }
  }

  void _startPaymentProcessForSelectedCustomers() {
    if (_selectedCustomerIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one customer to process payment.', style: TextStyle(fontFamily: 'Arial'))),
      );
      return;
    }

    // Get the actual Customer objects for the selected IDs if you need more than just IDs on the payment page
    final List<Customer> customersToProcess = customers
        .where((customer) => _selectedCustomerIds.contains(customer.id))
        .toList();

    debugPrint('Initiating payment process for customer IDs: ${_selectedCustomerIds.toList()}');

Navigator.pop(context, {
  'id': customersToProcess.first.id,
  'name': customersToProcess.first.name,
  'email': customersToProcess.first.email,
  'phone': customersToProcess.first.phone,
}
);
  }

  static const double checkBoxWidth = 40.0;
static const double snoWidth = 60.0;
static const double nameWidth = 150.0;
static const double emailWidth = 200.0;
static const double phoneWidth = 120.0;
static const double addressWidth = 250.0;
static const double companyTypeWidth = 120.0;
static const double actionsWidth = 100.0;
static const double minColumnWidth = 80.0;


  @override
  Widget build(BuildContext context) {
    // 1. Filtering Logic
    final filteredCustomers = customers.where((c) {
      final lowerCaseSearchQuery = _searchQuery.toLowerCase();
      final matchesSearch = c.name.toLowerCase().contains(lowerCaseSearchQuery) ||
          (c.email ?? '').toLowerCase().contains(lowerCaseSearchQuery) ||
          (c.phone ?? '').toLowerCase().contains(lowerCaseSearchQuery) ||
          c.contactAddress.toLowerCase().contains(lowerCaseSearchQuery) ||
          c.companyType.toLowerCase().contains(lowerCaseSearchQuery); // Include companyType in search

      final matchesType = _companyFilter == 'all' || c.companyType == _companyFilter;

      return matchesSearch && matchesType;
    }).toList();

    // 2. Sorting Logic (applied AFTER filtering)
    if (_sortColumnIndex != null) {
      filteredCustomers.sort((a, b) {
        Comparable aValue, bValue;
        switch (_sortColumnIndex) {
          case 0: // Checkbox column - no actual sorting logic for it, so it's a dummy index.
            return 0;
          case 1: // Name (shifted index by 1 due to new checkbox column)
            aValue = a.name.toLowerCase();
            bValue = b.name.toLowerCase();
            break;
          case 2: // Email (shifted index)
            aValue = (a.email ?? '').toLowerCase();
            bValue = (b.email ?? '').toLowerCase();
            break;
          case 3: // Phone (shifted index)
            aValue = (a.phone ?? '').toLowerCase();
            bValue = (b.phone ?? '').toLowerCase();
            break;
          case 4: // Address (shifted index)
            aValue = a.contactAddress.toLowerCase();
            bValue = b.contactAddress.toLowerCase();
            break;
          case 5: // Company Type (shifted index)
            aValue = a.companyType.toLowerCase();
            bValue = b.companyType.toLowerCase();
            break;
          default:
            return 0; // For S.No or Actions, no sorting
        }
        return _sortAscending ? Comparable.compare(aValue, bValue) : Comparable.compare(bValue, aValue);
      });
    }

    // 3. Pagination Logic (applied AFTER filtering and sorting)
    final total = filteredCustomers.length;
    final totalPages = (total / rowsPerPage).ceil();
    final startIndex = currentPage * rowsPerPage;
    final endIndex = (startIndex + rowsPerPage).clamp(0, total);
    final visibleCustomers = filteredCustomers.sublist(startIndex, endIndex);

    // Determine if all visible customers are selected for the header checkbox
    final bool allVisibleCustomersSelected =
        visibleCustomers.isNotEmpty && visibleCustomers.every((customer) => _selectedCustomerIds.contains(customer.id));

    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(120),
        child: AppBar(
          backgroundColor: const Color.fromARGB(255, 1, 129, 91),
          elevation: 0,
          automaticallyImplyLeading: false,
          flexibleSpace: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      GestureDetector(
                        onTap: () {
                          Navigator.pop(context);
                        },
                        child: Row(
                          children: const [
                            Icon(Icons.arrow_back, color: Colors.white, size: 24),
                            SizedBox(width: 8),
                            Text(
                              'Customer Table',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontFamily: 'Arial',
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        height: 40,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.white, width: 0.8),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _companyFilter,
                            dropdownColor: Colors.white,
                            icon: const Icon(Icons.arrow_drop_down, color: Colors.white, size: 24),
                            selectedItemBuilder: (BuildContext context) {
                              return <String>['all', 'person', 'company'].map<Widget>((String itemValue) {
                                return Align(
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    itemValue.toUpperCase(),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontFamily: 'Arial',
                                      fontSize: 14,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                );
                              }).toList();
                            },
                            items: const [
                              DropdownMenuItem(value: 'all', child: Text('All', style: TextStyle(color: Colors.black, fontFamily: 'Arial'))),
                              DropdownMenuItem(value: 'person', child: Text('Person', style: TextStyle(color: Colors.black, fontFamily: 'Arial'))),
                              DropdownMenuItem(value: 'company', child: Text('Company', style: TextStyle(color: Colors.black, fontFamily: 'Arial'))),
                            ],
                            onChanged: (value) {
                              if (value != null) {
                                setState(() {
                                  _companyFilter = value;
                                  currentPage = 0; // Reset pagination on filter change
                                  _selectedCustomerIds.clear(); // Clear selections on filter change
                                });
                              }
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Container(
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: TextField(
                      onChanged: (value) {
                        setState(() {
                          _searchQuery = value;
                          currentPage = 0; // Reset pagination on search change
                          _selectedCustomerIds.clear(); // Clear selections on search change
                        });
                      },
                      decoration: const InputDecoration(
                        hintText: 'Search customers...',
                        hintStyle: TextStyle(color: Colors.grey, fontFamily: 'Arial'),
                        border: InputBorder.none,
                        prefixIcon: Icon(Icons.search, color: Colors.grey),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      style: const TextStyle(fontSize: 16, fontFamily: 'Arial', color: Colors.black87),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: Color.fromARGB(255, 1, 129, 91)))
        : Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0), // Padding for the whole content
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                     Wrap(
  spacing: 12,
  runSpacing: 12,
  children: [
    ElevatedButton.icon(
      onPressed: () async {
        final result = await showDialog(
          context: context,
          barrierColor: Colors.black.withAlpha((0.5 * 255).toInt()),
          builder: (ctx) => const CreateCustomerPage(),
        );
        if (result == true) {
          fetchCustomers();
        }
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color.fromARGB(255, 201, 202, 201),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      ),
      icon: const Icon(Icons.add, color: Colors.black),
      label: const Text(
        'ADD CUSTOMER',
        style: TextStyle(
          color: Colors.black,
          fontFamily: 'Arial',
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),

    // Payment Process Button
    if (_selectedCustomerIds.isNotEmpty)
      ElevatedButton.icon(
        onPressed: _startPaymentProcessForSelectedCustomers,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color.fromARGB(255, 1, 129, 91),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        ),
        icon: const Icon(Icons.payment, color: Colors.white),
        label: Text(
          'Done',
          style: const TextStyle(
            color: Colors.white,
            fontFamily: 'Arial',
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

    // Download Button
    ElevatedButton.icon(
      onPressed: _showDownloadOptions,
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.blueGrey[700],
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      ),
      icon: const Icon(Icons.download, color: Colors.white),
      label: const Text(
        'DOWNLOAD',
        style: TextStyle(
          color: Colors.white,
          fontFamily: 'Arial',
          fontSize: 13,
        ),
      ),
    ),
  ],
)

                    ],
                  ),
                
                  const SizedBox(height: 16),

                  _buildTableHeader(allVisibleCustomersSelected, visibleCustomers.isNotEmpty, visibleCustomers, _horizontalHeaderScrollController),
                 Expanded( // This Expanded ensures the ListView takes available vertical space
                  child: visibleCustomers.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.person_off, size: 48, color: Colors.grey[400]),
                              const SizedBox(height: 8),
                              Text(
                                _searchQuery.isNotEmpty || _companyFilter != 'all'
                                    ? 'No customers match your criteria.'
                                    : 'No customers found.',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontFamily: 'Arial',
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        )
                      : Scrollbar(
  controller: _scrollController,
  thumbVisibility: true,
  child: ListView.builder(
    controller: _scrollController,
    itemCount: visibleCustomers.length,
    itemBuilder: (context, index) {
      final customer = visibleCustomers[index];
      final isSelected = _selectedCustomerId == customer.id; // Check if this customer is selected

      return InkWell(
        onTap: () {
          setState(() {
            if (isSelected) {
              _selectedCustomerId = null; // Deselect if the same customer is tapped
              _selectedCustomerIds.clear();
            } else {
              _selectedCustomerId = customer.id; // Select the tapped customer
              _selectedCustomerIds
                ..clear()
                ..add(customer.id);
            }
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? Colors.blue.withOpacity(0.1)
                : index % 2 == 0
                    ? Colors.white
                    : Colors.grey.shade50,
            border: Border(
              bottom: BorderSide(color: Colors.grey.shade300),
            ),
          ),
          child: Row(
            children: [
              _buildCell('${startIndex + index + 1}', flex: 2, width: 90),
              _buildCell(customer.name, flex: 2, width: 180),
              _buildCell(customer.email ?? '-', flex: 2, width: 250),
              _buildCell(customer.phone ?? '-', flex: 2, width: 120),
              _buildCell(customer.contactAddress.replaceAll('\n', ', '), flex: 3, width: 200),
              _buildCompanyTypeCell(customer.companyType ?? '', width: 120), // Ensure matching width here

              Expanded(
                flex: 2,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit, color: Colors.blue),
                      tooltip: 'Edit Customer',
                      onPressed: () async {
                        // Navigate to EditCustomerPage with the customer object
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => EditCustomerPage(customer: customer),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    },
  ),
)

                ),
                _buildFooter(total, startIndex, endIndex, totalPages),
              ],
            ),
          ),
  );
}

Widget _buildCompanyTypeCell(String type, {required double width}) {
  final isPerson = type.toLowerCase() == 'person';
  final capitalizedType = type[0].toUpperCase() + type.substring(1);

  return SizedBox(
    width: width,
    child: Padding( // Add padding
      padding: const EdgeInsets.symmetric(horizontal: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center, // Center icon and text
        children: [
          Icon(
            isPerson ? Icons.person : Icons.business,
            size: 18,
            color: const Color.fromARGB(255, 1, 129, 91),
          ),
          const SizedBox(width: 6),
          Expanded( // Expanded here to allow text to fill remaining space in SizedBox
            child: Text(
              capitalizedType,
              style: const TextStyle(fontSize: 14, fontFamily: 'Arial', color: Colors.black87),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    ),
  );
}
Widget _buildTableHeader(bool allVisibleCustomersSelected, bool hasVisibleCustomers, List<Customer> currentVisibleCustomers, ScrollController horizontalController) {
  return ClipRRect(
    borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
    child: Container(
      color: const Color.fromARGB(255, 1, 129, 91),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        controller: horizontalController, // Use the passed horizontal controller
        child: Row(
          children: [
            // SizedBox(
            //   width: checkBoxWidth, // Use defined constant width
            //   child: Checkbox(
            //     value: allVisibleCustomersSelected,
            //     onChanged: hasVisibleCustomers
            //         ? (bool? newValue) {
            //             setState(() {
            //               if (newValue == true) {
            //                 for (var customer in currentVisibleCustomers) {
            //                   _selectedCustomerIds.add(customer.id);
            //                 }
            //               } else {
            //                 for (var customer in currentVisibleCustomers) {
            //                   _selectedCustomerIds.remove(customer.id);
            //                 }
            //               }
            //             });
            //           }
            //         : null,
            //     activeColor: Colors.white,
            //     checkColor: const Color.fromARGB(255, 1, 129, 91),
            //   ),
            // ),
            // Pass the defined constant widths to _SortableHeader
            _SortableHeader(label: 'S.No', width: snoWidth, columnIndex: -1, sortColumnIndex: _sortColumnIndex, ascending: _sortAscending, onSort: (asc) => {}),
            _SortableHeader(label: 'Name', width: nameWidth, columnIndex: 1, sortColumnIndex: _sortColumnIndex, ascending: _sortAscending, onSort: (asc) => _sort(1, asc)),
            _SortableHeader(label: 'Email', width: emailWidth, columnIndex: 2, sortColumnIndex: _sortColumnIndex, ascending: _sortAscending, onSort: (asc) => _sort(2, asc)),
            _SortableHeader(label: 'Phone', width: phoneWidth, columnIndex: 3, sortColumnIndex: _sortColumnIndex, ascending: _sortAscending, onSort: (asc) => _sort(3, asc)),
            _SortableHeader(label: 'Address', width: addressWidth, columnIndex: 4, sortColumnIndex: _sortColumnIndex, ascending: _sortAscending, onSort: (asc) => _sort(4, asc)),
            _SortableHeader(label: 'Customer Type', width: companyTypeWidth, columnIndex: 5, sortColumnIndex: _sortColumnIndex, ascending: _sortAscending, onSort: (asc) => _sort(5, asc)),
            SizedBox( // Fixed width for actions column
              width: actionsWidth,
              child: const Text(
                'Actions',
                style: TextStyle(fontWeight: FontWeight.w500, fontFamily: 'Arial', fontSize: 16, color: Colors.white),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
Widget _buildCell(String value, {required double width, required int flex}) {
  return SizedBox(
    width: width,
    child: Padding( // Add padding for better visual spacing
      padding: const EdgeInsets.symmetric(horizontal: 4.0),
      child: Text(
        value,
        style: const TextStyle(fontSize: 14, fontFamily: 'Arial', color: Colors.black87),
        overflow: TextOverflow.ellipsis,
      ),
    ),
  );
}
  Widget _buildFooter(int total, int start, int end, int totalPages) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(8)),
        border: Border.all(color: Colors.grey.shade300, width: 1),
      ),
      child: Row(
        children: [
          Row(
            children: [
              const Text("Rows per page:", style: TextStyle(fontFamily: 'Arial', fontSize: 13, color: Colors.black87)),
              const SizedBox(width: 8),
              DropdownButton<int>(
                value: rowsPerPage,
                items: [5, 10, 20, 50].map((e) {
                  return DropdownMenuItem(value: e, child: Text(e.toString(), style: const TextStyle(fontFamily: 'Arial')));
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      rowsPerPage = value;
                      currentPage = 0; // Reset page when rows per page changes
                      _selectedCustomerIds.clear(); // Clear selections on rows per page change
                    });
                  }
                },
                style: const TextStyle(fontFamily: 'Arial', color: Colors.black87),
                icon: const Icon(Icons.arrow_drop_down, color: Color.fromARGB(255, 1, 129, 91)),
                underline: const SizedBox(),
              ),
            ],
          ),
          const Spacer(),
          Text("${start + 1}–$end of $total", style: const TextStyle(fontFamily: 'Arial', fontSize: 13, color: Colors.black87)),
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: currentPage > 0
                ? () => setState(() {
                      currentPage--;
                      _selectedCustomerIds.clear(); // Clear selections on page navigation
                    })
                : null,
            color: const Color.fromARGB(255, 1, 129, 91),
            disabledColor: Colors.grey[400],
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: (currentPage + 1) < totalPages
                ? () => setState(() {
                      currentPage++;
                      _selectedCustomerIds.clear(); // Clear selections on page navigation
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

class _SortableHeader extends StatelessWidget {
  final String label;
  final double width; // Changed from flex to width
  final int columnIndex;
  final int? sortColumnIndex;
  final bool ascending;
  final ValueChanged<bool> onSort;

  const _SortableHeader({
    super.key,
    required this.label,
    required this.width, // Now requires a width
    required this.columnIndex,
    required this.sortColumnIndex,
    required this.ascending,
    required this.onSort,
  });

  @override
  Widget build(BuildContext context) {
    final isSorted = columnIndex == sortColumnIndex;
    return SizedBox( // Use SizedBox to give it a fixed width
      width: width,
      child: InkWell(
        onTap: () {
          if (columnIndex != -1) {
            onSort(!(isSorted && ascending));
          }
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center, // Always center headers
            children: [
              Flexible( // Use Flexible to prevent text overflow in header labels
                child: Text(
                  label,
                  style: const TextStyle(fontWeight: FontWeight.w500, fontFamily: 'Arial', fontSize: 16, color: Colors.white),
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (isSorted)
                Icon(
                  ascending ? Icons.arrow_drop_up : Icons.arrow_drop_down,
                  size: 20,
                  color: Colors.white,
                ),
            ],
          ),
        ),
      ),
    );
  }
}