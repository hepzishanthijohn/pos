import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;
import 'package:rcspos/localdb/customersqlitehelper.dart';
import 'package:rcspos/screens/createcustomer.dart';
import 'package:rcspos/screens/editcustomer.dart'; // Ensure this exists and expects a 'Customer' object
import 'package:rcspos/utils/urls.dart';
import 'package:flutter/services.dart';

// Assuming baseurl is defined in urls.dart
// const String baseurl = 'YOUR_BASE_URL';

// Define _headerStyle here (as it was referenced but not defined)
const TextStyle _headerStyle = TextStyle(
  fontFamily: "Arial",
  fontWeight: FontWeight.w500,
  fontSize: 16,
  color: Colors.white,
);

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
      contactAddress: (json['contact_address'] == false || json['contact_address'] == null) ? '' : json['contact_address'].toString(),
      companyType: (json['company_type'] == false || json['company_type'] == null) ? 'person' : json['company_type'].toString(), // Default to 'person'
    );
  }

  // No need for toMap() if EditCustomerPage directly accepts Customer object
  // But if it does, ensure it correctly handles the keys.
}

class CustomerPage extends StatefulWidget {
  const CustomerPage({Key? key}) : super(key: key);

  @override
  State<CustomerPage> createState() => _CustomerPageState();
}

class _CustomerPageState extends State<CustomerPage> {
  List<Customer> customers = []; // All customers fetched from network/DB
  // For DataRows, we use _selectedCustomerIds (Set) for multi-selection.
  // _selectedCustomerId is not strictly needed for DataTable's `selected` property.
  // Keeping it as null implies no single selection, which works with the Set.
  int? _selectedCustomerId; 
  final Set<int> _selectedCustomerIds = {}; // For multi-selection checkboxes

  // Pagination & Sorting state
  int rowsPerPage = 10;
  int currentPage = 0;
  int? _sortColumnIndex;
  bool _sortAscending = true;

  // Filtering state
  String _searchQuery = '';
  String _companyFilter = 'all';

  // Loading state
  bool isLoading = false;

  // Scroll Controllers (removed redundant _scrollController, DataTables usually handle their own scrolling within Expanded/SingleChildScrollViews)
  // No explicit sync needed for DataColumn / DataRow horizontal scrolls as they are part of the same table
  final ScrollController _verticalTableScrollController = ScrollController();


  @override
  void initState() {
    super.initState();
    fetchCustomers();
  }

  @override
  void dispose() {
    _verticalTableScrollController.dispose();
    super.dispose();
  }

  final Customersqlitehelper customerDbHelper = Customersqlitehelper();

  Future<void> fetchCustomers() async {
    setState(() {
      isLoading = true;
      _selectedCustomerIds.clear(); // Clear selections on data refresh
      _selectedCustomerId = null; // Clear single selection
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

    await customerDbHelper.init();

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

        await customerDbHelper.insertCustomers(rawList);

        setState(() {
          customers = rawList.map((e) => Customer.fromJson(e)).toList();
          currentPage = 0;
          _sortColumnIndex = null;
          _sortAscending = true;
        });
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

      final fallback = customerDbHelper.fetchCustomers();
      if (fallback.isNotEmpty) {
        setState(() {
          customers = fallback.map((e) => Customer.fromJson(e)).toList();
          currentPage = 0;
          _sortColumnIndex = null;
          _sortAscending = true;
        });

        // ScaffoldMessenger.of(context).showSnackBar(
        //   const SnackBar(
        //     content: Text('Loaded customers from local SQLite cache.', style: TextStyle(fontFamily: 'Arial')),
        //     backgroundColor: Colors.orange,
        //   ),
        // );
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

  void _onSort(int columnIndex, bool ascending) {
    setState(() {
      _sortColumnIndex = columnIndex;
      _sortAscending = ascending;
      currentPage = 0; // Reset pagination when sorting
      _selectedCustomerIds.clear(); // Clear selections on sort change
      _selectedCustomerId = null; // Clear single selection
    });
  }

  void _downloadAsPDF() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Downloading as PDF...', style: TextStyle(fontFamily: 'Arial'))),
    );
    debugPrint("Download as PDF tapped");
    // TODO: Implement actual PDF generation
  }

  void _downloadAsExcel() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Downloading as Excel...', style: TextStyle(fontFamily: 'Arial'))),
    );
    debugPrint("Download as Excel tapped");
    // TODO: Implement actual Excel generation
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

    final url = Uri.parse('$baseurl/mobile/delete_customer/$customerId');
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
          SnackBar(content: Text('Failed to delete customer: $error', style: const TextStyle(fontFamily: 'Arial')), backgroundColor: Colors.red),
        );
        debugPrint('Error response: ${response.body}');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('An error occurred: $e', style: const TextStyle(fontFamily: 'Arial'))),
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

    final List<Customer> customersToProcess = customers
        .where((customer) => _selectedCustomerIds.contains(customer.id))
        .toList();

    debugPrint('Initiating payment process for customer IDs: ${_selectedCustomerIds.toList()}');

    if (customersToProcess.isNotEmpty) {
      // Assuming you want to return the first selected customer's data to the previous screen
      Navigator.pop(context, {
        'id': customersToProcess.first.id,
        'name': customersToProcess.first.name,
        'email': customersToProcess.first.email,
        'phone': customersToProcess.first.phone,
      });
    } else {
       ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No selected customer found.', style: TextStyle(fontFamily: 'Arial'))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // 1. Filtering Logic
    final filteredCustomers = customers.where((c) {
      final lowerCaseSearchQuery = _searchQuery.toLowerCase();
      final matchesSearch = c.name.toLowerCase().contains(lowerCaseSearchQuery) ||
          (c.email ?? '').toLowerCase().contains(lowerCaseSearchQuery) ||
          (c.phone ?? '').toLowerCase().contains(lowerCaseSearchQuery) ||
          c.contactAddress.toLowerCase().contains(lowerCaseSearchQuery) ||
          c.companyType.toLowerCase().contains(lowerCaseSearchQuery);

      final matchesType = _companyFilter == 'all' || c.companyType == _companyFilter;

      return matchesSearch && matchesType;
    }).toList(); // <--- Important: .toList() creates a new mutable list

    // 2. Sorting Logic (APPLY HERE, AFTER FILTERING)
    if (_sortColumnIndex != null) {
      filteredCustomers.sort((a, b) { // Sort the filtered list
        Comparable aValue, bValue;
        switch (_sortColumnIndex) {
          case 0: // S.No column (not sortable, this case is likely for the actual DataColumn index, not internal data index)
            return 0; // Or better, adjust _onSort's columnIndex to skip this
          case 1: // Name (Adjusted index based on DataColumn setup: S.No is 0, Name is 1 if checkbox is removed)
            aValue = a.name.toLowerCase();
            bValue = b.name.toLowerCase();
            break;
          case 2: // Email (Adjusted index)
            aValue = (a.email ?? '').toLowerCase();
            bValue = (b.email ?? '').toLowerCase();
            break;
          case 3: // Phone (Adjusted index)
            aValue = (a.phone ?? '').toLowerCase();
            bValue = (b.phone ?? '').toLowerCase();
            break;
          case 4: // Address (Adjusted index)
            aValue = a.contactAddress.toLowerCase();
            bValue = b.contactAddress.toLowerCase();
            break;
          case 5: // Company Type (Adjusted index)
            aValue = a.companyType.toLowerCase();
            bValue = b.companyType.toLowerCase();
            break;
          default:
            return 0; // For Actions, no sorting
        }
        return _sortAscending ? Comparable.compare(aValue, bValue) : Comparable.compare(bValue, aValue);
      });
    }

    // 3. Pagination Logic (applied AFTER filtering and sorting)
    final totalFilteredCustomers = filteredCustomers.length;
    final totalPages = (totalFilteredCustomers / rowsPerPage).ceil();
    final startIndex = currentPage * rowsPerPage;
    final endIndex = (startIndex + rowsPerPage).clamp(0, totalFilteredCustomers);
    final visibleCustomers = filteredCustomers.sublist(startIndex, endIndex);


    // 3. Pagination Logic (applied AFTER filtering and sorting)
    // final totalFilteredCustomers = filteredCustomers.length;
    // final totalPages = (totalFilteredCustomers / rowsPerPage).ceil();
    // final startIndex = currentPage * rowsPerPage;
    // final endIndex = (startIndex + rowsPerPage).clamp(0, totalFilteredCustomers);
    // final visibleCustomers = filteredCustomers.sublist(startIndex, endIndex);

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
                              label: const Text(
                                'Done',
                                style: TextStyle(
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
                  if (visibleCustomers.isEmpty)
                    Expanded(
                      child: Center(
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
                      ),
                    )
                  else
                    Expanded(
                      child: SingleChildScrollView(
                        controller: _verticalTableScrollController, // Vertical scroll for the whole table content
                        scrollDirection: Axis.vertical,
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              // Ensure minimum width to allow horizontal scrolling
                              minWidth: MediaQuery.of(context).size.width - 32, // Subtract horizontal padding
                            ),
child: DataTable(
                              headingRowColor: MaterialStateProperty.resolveWith<Color>(
                                (Set<MaterialState> states) => const Color.fromARGB(255, 8, 72, 150),
                              ),
                              headingTextStyle: _headerStyle,
                              columnSpacing: 0,
                              dataRowColor: MaterialStateProperty.resolveWith<Color>((states) {
                               
                                if (states.contains(MaterialState.selected)) {
                                  return Colors.blue.withOpacity(0.2);
                                }
                                return Colors.white; // Default color
                              }),
                              sortColumnIndex: _sortColumnIndex == 0 ? null : _sortColumnIndex, // Adjust index if 0 was for checkbox
                              sortAscending: _sortAscending,
                           
                              showCheckboxColumn: false, 
                              columns: [
                        
                                DataColumn(
                                  label: SizedBox( child: const Text('S.No')),
                                
                                ),
                                DataColumn(
                                  label: const SizedBox( child: Text('Name')),
                                  onSort: (columnIndex, ascending) => _onSort(1, ascending), 
                                ),
                                DataColumn(
                                  label: const SizedBox( child: Text('Email')),
                                  onSort: (columnIndex, ascending) => _onSort(2, ascending), 
                                ),
                                DataColumn(
                                  label: const SizedBox( child: Text('Phone')),
                                  onSort: (columnIndex, ascending) => _onSort(3, ascending), 
                                ),
                                DataColumn(
                                  label: const SizedBox( child: Text('Address')),
                                  onSort: (columnIndex, ascending) => _onSort(4, ascending), 
                                ),
                                DataColumn(
                                  label: const SizedBox( child: Text('Company Type')),
                                  onSort: (columnIndex, ascending) => _onSort(5, ascending), 
                                ),
                                DataColumn(
                                  label: const SizedBox( child: Text('Actions')),
                                 
                                ),
                              ],
                              rows: visibleCustomers.asMap().entries.map((entry) {
                                final int index = entry.key;
                                final Customer customer = entry.value;
                                final bool isSelected = _selectedCustomerIds.contains(customer.id);

                                return DataRow(
                                  selected: isSelected, 
                            onSelectChanged: (selected) {
  setState(() {
    if (selected == true) {
      _selectedCustomerIds
        ..clear()
        ..add(customer.id);
    } else {
      _selectedCustomerIds.remove(customer.id);
    }
  });
},

                                  cells: [
                                    // DataCell for S.No
                                    DataCell(Text('${startIndex + index + 1}')),
                                    DataCell(Text(customer.name)),
                                    DataCell(Text(customer.email ?? '-')),
                                    DataCell(Text(customer.phone ?? '-')),
                                    DataCell(
  SizedBox(
    width: 200, // Adjust this width as needed
    child: Text(
      customer.contactAddress.replaceAll('\n', ', '),
      overflow: TextOverflow.ellipsis, // Optional: handle overflow with ellipsis
      maxLines: 2, // Optional: limit the number of lines
    ),
  ),
),
DataCell(Row(
  children: [
    Icon(
      customer.companyType == 'company' ? Icons.business : Icons.person,
      size: 18,
      color: customer.companyType == 'company' ? Colors.blue : Colors.green,
    ),
    const SizedBox(width: 6),
    Text(
      '${customer.companyType[0].toUpperCase()}${customer.companyType.substring(1).toLowerCase()}',
      style: const TextStyle(fontFamily: 'Arial'),
    ),
  ],
)),

                                    DataCell(
                                      Row(
                                        children: [
                                          IconButton(
                                            icon: const Icon(Icons.edit, color: Colors.blue),
                                            tooltip: 'Edit Customer',
                                           onPressed: () async {
final updatedCustomer = await showDialog(
  context: context,
  builder: (_) => EditCustomerPage(customer: customer),
);

if (updatedCustomer is Customer) {
  final index = customers.indexWhere((c) => c.id == updatedCustomer.id);
  if (index != -1) {
    setState(() {
      customers[index] = updatedCustomer;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Customer "${updatedCustomer.name}" updated.'),
        backgroundColor: Colors.green,
      ),
    );
  }
}

}
                                        
                                         ),
                                          IconButton(
                                            icon: const Icon(Icons.delete, color: Colors.red),
                                            tooltip: 'Delete Customer',
                                            onPressed: () => _confirmDeleteCustomer(customer),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                );
                              }).toList(),
                            ),                        ),
                        ),
                      ),
                    ),
                  // --- Pagination controls (Footer) ---
                  if (!isLoading && totalFilteredCustomers > 0)
                    _buildFooter(
                      totalFilteredCustomers,
                      startIndex,
                      endIndex,
                      totalPages,
                    ),
                ],
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