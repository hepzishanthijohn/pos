import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;
import 'package:rcspos/data/customerdata.dart';
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
      id: json['id'] as int, // Explicitly cast to int
      name: json['name'] as String? ?? '', // Handle potential null and cast
      email: json['email'] == false ? null : json['email'] as String?, // Handle false and cast
      phone: json['phone'] == false ? null : json['phone'] as String?, // Handle false and cast
      contactAddress: json['contact_address'] as String? ?? '', // Handle potential null and cast
      companyType: json['company_type'] as String? ?? 'person', // Default and cast
    );
  }
}

class samplecustomerpage extends StatefulWidget {
  const samplecustomerpage({Key? key}) : super(key: key);

  @override
  State<samplecustomerpage> createState() => _samplecustomerpageState();
}

class _samplecustomerpageState extends State<samplecustomerpage> {
  // Corrected type: This should be a List of Customer objects
  List<Customer> customers = [];
  int rowsPerPage = 10;
  int currentPage = 0;
  int? _sortColumnIndex;
  bool _sortAscending = true;
  String _searchQuery = '';
  String _companyFilter = 'all';
  bool isLoading = false;


  // State to hold IDs of selected customers
  final Set<int> _selectedCustomerIds = {};

  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

    Future<void> _initializeData() async {
    setState(() => isLoading = true);
    await fetchCustomers();

    setState(() => isLoading = false);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }
 Future<void> fetchCustomers() async {
    setState(() {
      isLoading = true;
      _selectedCustomerIds.clear(); // Clear selections when data is re-fetched
    });

    // Simulating static data from 'customersList'
    final customersList = [
      {
        'id': 1,
        'name': 'John Doe',
        'email': 'john@example.com',
        'phone': '1234567890',
        'contact_address': '1234 Elm St',
        'company_type': 'person',
      },
      {
        'id': 2,
        'name': 'Jane Smith',
        'email': 'jane@example.com',
        'phone': '9597208238',
        'contact_address': '5678 Oak St',
        'company_type': 'company',
      },
      // Add more customer data here
    ];

    setState(() {
      // This line will now work correctly as 'customers' is List<Customer>
      customers = customersList.map((e) => Customer.fromJson(e)).toList();
      isLoading = false;
    });
  }

  void _startPaymentProcessForSelectedCustomers() {
    if (_selectedCustomerIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one customer to process payment.', style: TextStyle(fontFamily: 'Arial'))),
      );
      return;
    }

    final List<Customer> customersToProcess = customers
        .where((customer) => _selectedCustomerIds.contains(customer.id))
        .toList();

    // Ensure there's at least one customer to process before accessing .first
    if (customersToProcess.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selected customer not found.', style: TextStyle(fontFamily: 'Arial'))),
      );
      return;
    }

    debugPrint('Initiating payment process for customer IDs: ${_selectedCustomerIds.toList()}');

    // Pop with the first customer's details
    Navigator.pop(context, {
      'id': customersToProcess.first.id,
      'name': customersToProcess.first.name,
      'email': customersToProcess.first.email,
      'phone': customersToProcess.first.phone,
    });
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


  @override
  Widget build(BuildContext context) {
    // Ensure customers is a List<Customer>
    final List<Customer> customerList = customers;

    // 1. Filtering Logic
    final filteredCustomers = customerList.where((c) {
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
    final List<Customer> visibleCustomers = filteredCustomers.sublist(startIndex, endIndex);

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
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      ElevatedButton.icon(
                        onPressed: () async {
                          final result = await showDialog(
                            context: context,
                            barrierColor: Colors.black.withOpacity(0.5),
                            builder: (ctx) => const CreateCustomerPage(),
                          );
                          if (result == true) {
                            fetchCustomers();
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color.fromARGB(255, 201, 202, 201),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                        ),
                        icon: const Icon(Icons.add, color: Colors.black),
                        label: const Text(
                          'ADD CUSTOMER',
                          style: TextStyle(color: Colors.black, fontFamily: 'Arial', fontSize: 14, fontWeight: FontWeight.w600),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // --- NEW: Payment Process Button ---
                      if (_selectedCustomerIds.isNotEmpty) ...[
                        ElevatedButton.icon(
                          onPressed: _startPaymentProcessForSelectedCustomers,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color.fromARGB(255, 1, 129, 91), // Green for positive action
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                          ),
                          icon: const Icon(Icons.payment, color: Colors.white),
                          label: Text(
                            'PROCESS PAYMENT (${_selectedCustomerIds.length})',
                            style: const TextStyle(color: Colors.white, fontFamily: 'Arial', fontSize: 14, fontWeight: FontWeight.w600),
                          ),
                        ),
                        const SizedBox(width: 12),
                      ],
                      // --- End New Button ---
                      ElevatedButton.icon(
                        onPressed: _showDownloadOptions,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blueGrey[700],
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                        ),
                        icon: const Icon(Icons.download, color: Colors.white),
                        label: const Text(
                          'DOWNLOAD',
                          style: TextStyle(color: Colors.white, fontFamily: 'Arial', fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  _buildTableHeader(allVisibleCustomersSelected, visibleCustomers.isNotEmpty, visibleCustomers),
                  Expanded(
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
                                final isSelected = _selectedCustomerIds.contains(customer.id);
                                return Container(
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
                                      SizedBox(
                                        width: 40,
                                        child: Checkbox(
                                          value: isSelected,
                                          onChanged: (bool? newValue) {
                                            setState(() {
                                              if (newValue == true) {
                                                _selectedCustomerIds.add(customer.id);
                                              } else {
                                                _selectedCustomerIds.remove(customer.id);
                                              }
                                            });
                                          },
                                          activeColor: const Color.fromARGB(255, 1, 129, 91),
                                        ),
                                      ),
                                      _buildCell('${startIndex + index + 1}', flex: 1),
                                      _buildCell(customer.name, flex: 2),
                                      _buildCell(customer.email ?? '-', flex: 2),
                                      _buildCell(customer.phone ?? '-', flex: 2),
                                      _buildCell(customer.contactAddress.replaceAll('\n', ', '), flex: 3),
                                      _buildCompanyTypeCell(customer.companyType),
                                      Expanded(
                                        flex: 2,
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            IconButton(
                                              icon: const Icon(Icons.edit, color: Colors.blue),
                                              tooltip: 'Edit Customer',
                                              onPressed: () async {
                                                // Convert to correct Customer type if needed
                                                // final dynamic editCustomer = customer;
                                                // final result = await showDialog(
                                                //   context: context,
                                                //   builder: (ctx) => EditCustomerPage(customer: editCustomer),
                                                // );
                                                // if (result == true) {
                                                //   fetchCustomers();
                                                // }
                                              },
                                            ),
                                      
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
                  ),
                  _buildFooter(total, startIndex, endIndex, totalPages),
                ],
              ),
            ),
    );
  }

  Widget _buildCompanyTypeCell(String type) {
    final isPerson = type.toLowerCase() == 'person';
    final capitalizedType = type[0].toUpperCase() + type.substring(1);

    return Expanded(
      flex: 2,
      child: Row(
        children: [
          Icon(
            isPerson ? Icons.person : Icons.business,
            size: 18,
            color: const Color.fromARGB(255, 1, 129, 91),
          ),
          const SizedBox(width: 6),
          Text(
            capitalizedType,
            style: const TextStyle(fontSize: 14, fontFamily: 'Arial', color: Colors.black87),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildTableHeader(bool allVisibleCustomersSelected, bool hasVisibleCustomers, List<Customer> currentVisibleCustomers) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
      child: Container(
        color: const Color.fromARGB(255, 1, 129, 91),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        child: Row(
          children: [
            SizedBox(
              width: 40,
              child: Checkbox(
                value: allVisibleCustomersSelected,
                onChanged: hasVisibleCustomers
                    ? (bool? newValue) {
                        setState(() {
                          if (newValue == true) {
                            for (var customer in currentVisibleCustomers) {
                              _selectedCustomerIds.add(customer.id);
                            }
                          } else {
                            for (var customer in currentVisibleCustomers) {
                              _selectedCustomerIds.remove(customer.id);
                            }
                          }
                        });
                      }
                    : null,
                activeColor: Colors.white,
                checkColor: const Color.fromARGB(255, 1, 129, 91),
              ),
            ),
            _SortableHeader(
              label: 'S.No',
              flex: 1,
              columnIndex: -1,
              sortColumnIndex: _sortColumnIndex,
              ascending: _sortAscending,
              onSort: (asc) => {},
            ),
            _SortableHeader(
              label: 'Name',
              flex: 2,
              columnIndex: 1,
              sortColumnIndex: _sortColumnIndex,
              ascending: _sortAscending,
              onSort: (asc) => _sort(1, asc),
            ),
            _SortableHeader(
              label: 'Email',
              flex: 2,
              columnIndex: 2,
              sortColumnIndex: _sortColumnIndex,
              ascending: _sortAscending,
              onSort: (asc) => _sort(2, asc),
            ),
            _SortableHeader(
              label: 'Phone',
              flex: 2,
              columnIndex: 3,
              sortColumnIndex: _sortColumnIndex,
              ascending: _sortAscending,
              onSort: (asc) => _sort(3, asc),
            ),
            _SortableHeader(
              label: 'Address',
              flex: 3,
              columnIndex: 4,
              sortColumnIndex: _sortColumnIndex,
              ascending: _sortAscending,
              onSort: (asc) => _sort(4, asc),
            ),
            _SortableHeader(
              label: 'Company Type',
              flex: 2,
              columnIndex: 5,
              sortColumnIndex: _sortColumnIndex,
              ascending: _sortAscending,
              onSort: (asc) => _sort(5, asc),
            ),
            const Expanded(
              flex: 2,
              child: Text(
                'Actions',
                style: TextStyle(fontWeight: FontWeight.w500, fontFamily: 'Arial', fontSize: 16, color: Colors.white),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCell(String value, {int flex = 1}) {
    return Expanded(
      flex: flex,
      child: Text(
        value,
        style: const TextStyle(fontSize: 14, fontFamily: 'Arial', color: Colors.black87),
        overflow: TextOverflow.ellipsis,
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
  final int flex;
  final int columnIndex;
  final int? sortColumnIndex;
  final bool ascending;
  final ValueChanged<bool> onSort;

  const _SortableHeader({
    required this.label,
    required this.flex,
    required this.columnIndex,
    required this.sortColumnIndex,
    required this.ascending,
    required this.onSort,
  });

  @override
  Widget build(BuildContext context) {
    final isSorted = columnIndex == sortColumnIndex;
    return Expanded(
      flex: flex,
      child: InkWell(
        onTap: () {
          // Prevent sorting for dummy columns if columnIndex is -1
          if (columnIndex != -1) {
            onSort(!(isSorted && ascending));
          }
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4.0),
          child: Row(
            mainAxisAlignment: columnIndex == -1 ? MainAxisAlignment.start : MainAxisAlignment.center,
            children: [
              Text(
                label,
                style: const TextStyle(fontWeight: FontWeight.w500, fontFamily: 'Arial', fontSize: 16, color: Colors.white),
                textAlign: TextAlign.center,
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