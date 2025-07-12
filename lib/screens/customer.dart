// import 'dart:convert';
// import 'dart:io';
// import 'package:flutter/material.dart';
// import 'package:hive/hive.dart';
// import 'package:http/http.dart' as http;
// import 'package:rcspos/screens/editcustomer.dart';
// import 'package:rcspos/utils/urls.dart';

// class Customer {
//   final int id;
//   final String name;
//   final String? email;
//   final String? phone;
//   final String contactAddress;
//   final String companyType;

//   Customer({
//     required this.id,
//     required this.name,
//     this.email,
//     this.phone,
//     required this.contactAddress,
//     required this.companyType,
//   });

//   factory Customer.fromJson(Map<String, dynamic> json) {
//     return Customer(
//       id: json['id'],
//       name: json['name'] ?? '',
//       email: json['email'] == false ? null : json['email'],
//       phone: json['phone'] == false ? null : json['phone'],
//       contactAddress: json['contact_address'] ?? '',
//       companyType: json['company_type'] ?? '',
//     );
//   }
// }

// class CustomerPage extends StatefulWidget {
//   const CustomerPage({Key? key}) : super(key: key);

//   @override
//   State<CustomerPage> createState() => _CustomerPageState();
// }

// class _CustomerPageState extends State<CustomerPage> {
//   List<Customer> customers = [];
//   int rowsPerPage = 10;
//   int currentPage = 0;
//   int? _sortColumnIndex;
//   bool _sortAscending = true;
//   String _searchQuery = '';
//   String _companyFilter = 'all';
//   bool isLoading = false;

//   final _scrollController = ScrollController();

//   @override
//   void initState() {
//     super.initState();
//     fetchCustomers();
//   }

//   @override
//   void dispose() {
//     _scrollController.dispose();
//     super.dispose();
//   }

//   Future<void> fetchCustomers() async {
//     setState(() => isLoading = true);

//     final box = await Hive.openBox('login');
//     final rawSession = box.get('session_id');

//     if (rawSession == null) {
//       setState(() => isLoading = false);
//       return;
//     }

//     final sessionId = rawSession.contains('session_id=')
//         ? rawSession
//         : 'session_id=$rawSession';

//     final url = Uri.parse(
//         '$baseurl/api/res.partner?query={id,name,email,phone,contact_address,company_type}&filter=[["customer_rank",">=",0]]');

//     try {
//       final response = await http.get(url, headers: {
//         HttpHeaders.cookieHeader: sessionId,
//         HttpHeaders.contentTypeHeader: 'application/json',
//       });

//       if (response.statusCode == 200) {
//         final result = json.decode(response.body)['result'];
//         setState(() {
//           customers =
//               List<Customer>.from(result.map((e) => Customer.fromJson(e)));
//         });
//       }
//     } catch (e) {
//       debugPrint("Error fetching customers: $e");
//     } finally {
//       setState(() => isLoading = false);
//     }
//   }

//   void _sort<T>(
//     Comparable<T> Function(Customer c) getField,
//     int columnIndex,
//     bool ascending,
//   ) {
//     setState(() {
//       customers.sort((a, b) {
//         final aValue = getField(a);
//         final bValue = getField(b);
//         return ascending
//             ? Comparable.compare(aValue, bValue)
//             : Comparable.compare(bValue, aValue);
//       });
//       _sortColumnIndex = columnIndex;
//       _sortAscending = ascending;
//       currentPage = 0;
//     });
//   }

//   void _downloadAsPDF() {
//     debugPrint("Download as PDF tapped");
//   }

//   void _downloadAsExcel() {
//     debugPrint("Download as Excel tapped");
//   }

//   void _showDownloadOptions() {
//     showDialog(
//       context: context,
//       builder: (context) {
//         return AlertDialog(
//           title: const Text('Download as'),
//           content: Column(
//             mainAxisSize: MainAxisSize.min,
//             children: [
//               ListTile(
//                 leading: const Icon(Icons.picture_as_pdf),
//                 title: const Text('PDF'),
//                 onTap: () {
//                   Navigator.pop(context);
//                   _downloadAsPDF();
//                 },
//               ),
//               ListTile(
//                 leading: const Icon(Icons.grid_on),
//                 title: const Text('Excel'),
//                 onTap: () {
//                   Navigator.pop(context);
//                   _downloadAsExcel();
//                 },
//               ),
//             ],
//           ),
//         );
//       },
//     );
//   }

//   @override
//   Widget build(BuildContext context) {
//     final filteredCustomers = customers.where((c) {
//       final matchesSearch = c.name.toLowerCase().contains(_searchQuery) ||
//           (c.email ?? '').toLowerCase().contains(_searchQuery) ||
//           (c.phone ?? '').toLowerCase().contains(_searchQuery) ||
//           c.contactAddress.toLowerCase().contains(_searchQuery) ||
//           c.companyType.toLowerCase().contains(_searchQuery);

//       final matchesType = _companyFilter == 'all' || c.companyType == _companyFilter;

//       return matchesSearch && matchesType;
//     }).toList();

//     final total = filteredCustomers.length;
//     final totalPages = (total / rowsPerPage).ceil();
//     final startIndex = currentPage * rowsPerPage;
//     final endIndex = (startIndex + rowsPerPage).clamp(0, total);
//     final visibleCustomers = filteredCustomers.sublist(startIndex, endIndex);

//      return Scaffold(
// appBar: PreferredSize(
//   preferredSize: const Size.fromHeight(120), // Height is good for this content
//   child: AppBar(
//     backgroundColor: const Color.fromARGB(255, 1, 129, 91),
//  // Green background
//     elevation: 0, // No shadow
//     automaticallyImplyLeading: false, // You're custom handling the back button
//     flexibleSpace: SafeArea(
//       child: Padding(
//         padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0), // Consistent horizontal padding
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             // Top Row: Back arrow, title, filter aligned right
//             Row(
//               mainAxisAlignment: MainAxisAlignment.spaceBetween,
//               children: [
//                 // Left side: Arrow + Title
//                 GestureDetector( // Make the back arrow and text tappable
//                    onTap: () {
//     // This line will navigate back to the previous screen in the navigation stack.
//     Navigator.pop(context); // Enable navigation here
//     debugPrint('Back button tapped'); // You can keep this for debugging if you want
//   },
//                   child: Row(
//                     children: const [
//                       Icon(Icons.arrow_back, color: Colors.white, size: 24), // Adjust size if needed
//                       SizedBox(width: 8), // Increased spacing for better visual separation
//                       Text(
//                         'Customer Table',
//                         style: TextStyle(
//                           color: Colors.white,
//                           fontSize: 20,
//                           fontFamily: 'Arial', // Ensure this font is available or remove
//                           fontWeight: FontWeight.bold,
//                         ),
//                       ),
//                     ],
//                   ),
//                 ),

      
// Container(
//   // You might want to remove fixed height here or give it more flexibility
//   height: 40,
//   padding: const EdgeInsets.symmetric(horizontal: 12),
//   decoration: BoxDecoration(
//     borderRadius: BorderRadius.circular(6),
//     border: Border.all(
//       color: Colors.white,
//       width: 0.8,
//     ),
//   ),
//   child: DropdownButtonHideUnderline(
//     child: DropdownButton<String>(
//       value: _companyFilter,
//       dropdownColor: Colors.white,
//       // Icon is correctly placed by the DropdownButton
//       icon: const Icon(Icons.arrow_drop_down, color: Colors.white, size: 24),
//       // isExpanded: true, // <--- Consider commenting this out temporarily if issues persist

//       // Simplify selectedItemBuilder
//       selectedItemBuilder: (BuildContext context) {
//         return <String>['all', 'person', 'company'].map<Widget>((String itemValue) {
//           return Align( // Use Align instead of Center for more control if needed
//             alignment: Alignment.centerLeft, // Align left within the button area
//             child: Text(
//               itemValue.toUpperCase(),
//               style: const TextStyle(
//                 color: Colors.white,
//                 fontFamily: 'Arial',
//                 fontSize: 14,
//               ),
//               overflow: TextOverflow.ellipsis, // Prevent overflow if text is too long
//             ),
//           );
//         }).toList();
//       },

//       items: const [
//         DropdownMenuItem(
//           value: 'all',
//           child: Text(
//             'All',
//             style: TextStyle(color: Colors.black, fontFamily: 'Arial'),
//           ),
//         ),
//         DropdownMenuItem(
//           value: 'person',
//           child: Text(
//             'Person',
//             style: TextStyle(color: Colors.black, fontFamily: 'Arial'),
//           ),
//         ),
//         DropdownMenuItem(
//           value: 'company',
//           child: Text(
//             'Company',
//             style: TextStyle(color: Colors.black, fontFamily: 'Arial'),
//           ),
//         ),
//       ],
//       onChanged: (value) {
//         if (value != null) {
//           setState(() {
//             _companyFilter = value;
//             // You should also trigger a refresh of your customer data here
//             // to apply the filter. Example:
//             // fetchCustomers(); // Assuming fetchCustomers now uses _companyFilter
//           });
//         }
//       },
//     ),
//   ),
// ),             ],
//             ),

//             const SizedBox(height: 6), // Slightly more space between top row and search bar

//             // Search Bar
//             Container(
//               height: 40,
//               decoration: BoxDecoration(
//                 color: Colors.white,
//                 borderRadius: BorderRadius.circular(8),
//               ),
//               child: TextField(
//                 onChanged: (value) {
//                   setState(() => _searchQuery = value.toLowerCase());
//                   // You might want to trigger a search/filter on your table data here
//                   // controller.filter('search', _searchQuery); // If using PagedDataTableController filters
//                 },
//                 decoration: const InputDecoration(
//                   hintText: 'Search customers...',
//                   hintStyle: TextStyle(color: Colors.grey, fontFamily: 'Arial'),
//                   border: InputBorder.none, // Removes default TextField border
//                   prefixIcon: Icon(Icons.search, color: Colors.grey),
//                   // Adjusted content padding for better visual balance
//                   contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
//                 ),
//                 style: const TextStyle(fontSize: 16, fontFamily: 'Arial', color: Colors.black87), // Ensure text color is visible
//               ),
//             ),
//           ],
//         ),
//       ),
//     ),
//   ),
// ),
//      body: isLoading ?const Center(child: CircularProgressIndicator()) :
//       Padding(
//   padding: const EdgeInsets.all(16),
//   child: Column(
//     crossAxisAlignment: CrossAxisAlignment.start,
//     children: [
// Row(
//   mainAxisAlignment: MainAxisAlignment.end,
//   children: [
//     // Add Customer Button
//     ElevatedButton.icon(
//      onPressed: _showAddCustomerDialog,

//       style: ElevatedButton.styleFrom(
//         backgroundColor: const Color.fromARGB(255, 201, 202, 201),
//         padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
//         shape: RoundedRectangleBorder(
//           borderRadius: BorderRadius.circular(6),
//         ),
//       ),
//       icon: const Icon(Icons.add, color: Colors.black),
//       label: const Text(
//         'ADD CUSTOMER',
//         style: TextStyle(color: Colors.black, fontFamily: 'Arial', fontSize: 14,fontWeight: FontWeight.w600),
//       ),
//     ),

//     const SizedBox(width: 12),

//     // Download Button
// ElevatedButton.icon(
//   onPressed: _showDownloadOptions,
//   style: ElevatedButton.styleFrom(
//     backgroundColor: Colors.blueGrey[700],
//     padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
//     shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
//   ),
//   icon: const Icon(Icons.download, color: Colors.white),
//   label: const Text(
//     'DOWNLOAD',
//     style: TextStyle(color: Colors.white, fontFamily: 'Arial', fontSize: 14),
//   ),
// ),

//   ],
// ),

//      const SizedBox(height: 6),
//             _buildTableHeader(),
//             const Divider(height: 1),
// Expanded(
//   child: visibleCustomers.isEmpty
//       ? const Center(
//           child: Text(
//             'No customer found',
//             style: TextStyle(
//               fontSize: 16,
//               fontFamily: 'Arial',
//               color: Colors.grey,
              
//             ),
//           ),
//         )
//       : Scrollbar(
//           controller: _scrollController,
//           thumbVisibility: true,
//           child: ListView.builder(
//             controller: _scrollController,
//             itemCount: visibleCustomers.length,
//             itemBuilder: (context, index) {
//               final customer = visibleCustomers[index];
//               return Container(
//                 padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
//                 decoration: BoxDecoration(
//                   border: Border(
//                     bottom: BorderSide(color: Colors.grey[300]!),
//                   ),
//                 ),
//                 child: Row(
//                   children: [
//                       _buildCell('${startIndex + index + 1}', flex: 1), // Serial Number
//                     _buildCell(customer.name, flex: 2),
//                     _buildCell(customer.email ?? '-', flex: 2),
//                     _buildCell(customer.phone ?? '-', flex: 2),
//                     _buildCell(customer.contactAddress.replaceAll('\n', '-'), flex: 3),
//                    _buildCompanyTypeCell(customer.companyType),
//                     Expanded(
//   flex: 2,
//   child: Row(
//     children: [
// IconButton(
//   icon: Icon(Icons.edit, color: Colors.blue),
// onPressed: () async {
//   final result = await showDialog(
//     context: context,
//     builder: (ctx) => EditCustomerPage(customer: customer),
//   );

//   if (result == true) {
//     fetchCustomers(); // ✅ Refresh customer list if update was successful
//   }
// },

// ),

//       IconButton(
//         icon: const Icon(Icons.delete, size: 20, color: Colors.red), // Delete icon color
//         onPressed: () {
//           // TODO: Implement delete functionality
//         },
//       ),
//     ],
//   ),
// ),

//                   ],
//                 ),
              
//               );
//             },
//           ),
//         ),
// ),
//            const Divider(height: 1),
//             _buildFooter(total, startIndex, endIndex, totalPages),
//           ],
//         ),
//       ),
//     );
//     // ... UI and logic that displays the customer list without the create customer form ...
   
//   }
// }
// Widget _buildTableHeader() {
//   return ClipRRect(
//     borderRadius: const BorderRadius.vertical(top: Radius.circular(8)), // 👈 Rounded top corners
//     child: Container(
//       color: const Color.fromARGB(255, 1, 129, 91),
//       padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
//       child: Row(
//         children: [
//           _SortableHeader(
//   label: 'S.No',
//   flex: 1,
//   columnIndex: -1, // No sorting for serial number
//   sortColumnIndex: _sortColumnIndex,
//   ascending: _sortAscending,
//   onSort: (_) {}, // Do nothing
// ),

//           _SortableHeader(
//             label: 'Name',
//             flex: 2,
//             columnIndex: 0,
//             sortColumnIndex: _sortColumnIndex,
//             ascending: _sortAscending,
//             onSort: (asc) => _sort((c) => c.name.toLowerCase(), 0, asc),
//           ),
//           _SortableHeader(
//             label: 'Email',
//             flex: 2,
//             columnIndex: 1,
//             sortColumnIndex: _sortColumnIndex,
//             ascending: _sortAscending,
//             onSort: (asc) =>
//                 _sort((c) => (c.email ?? '').toLowerCase(), 1, asc),
//           ),
//           _SortableHeader(
//             label: 'Phone',
//             flex: 2,
//             columnIndex: 2,
//             sortColumnIndex: _sortColumnIndex,
//             ascending: _sortAscending,
//             onSort: (asc) =>
//                 _sort((c) => (c.phone ?? '').toLowerCase(), 2, asc),
//           ),
//           _SortableHeader(
//             label: 'Address',
//             flex: 3,
//             columnIndex: 3,
//             sortColumnIndex: _sortColumnIndex,
//             ascending: _sortAscending,
//             onSort: (asc) =>
//                 _sort((c) => c.contactAddress.toLowerCase(), 3, asc),
//           ),
//           _SortableHeader(
//             label: 'Company',
//             flex: 2,
//             columnIndex: 4,
//             sortColumnIndex: _sortColumnIndex,
//             ascending: _sortAscending,
//             onSort: (asc) =>
//                 _sort((c) => c.companyType.toLowerCase(), 4, asc),
//           ),
//              _SortableHeader(
//             label: 'Actions',
//             flex: 2,
//             columnIndex: 4,
//             sortColumnIndex: _sortColumnIndex,
//             ascending: _sortAscending,
//             onSort: (asc) =>
//                 _sort((c) => c.companyType.toLowerCase(), 4, asc),
//           ),
//         ],
//       ),
//     ),
//   );
// }

//  Widget _buildCell(String value, {int flex = 1}) {
//     return Expanded(
//       flex: flex,
//       child: Text(
//         value,
//         style: const TextStyle(fontSize: 15,
//         fontFamily: 'Arial'),
//         overflow: TextOverflow.ellipsis,
//       ),
//     );
//   }

//   Widget _buildFooter(int total, int start, int end, int totalPages) {
//     return Container(
//       color: const Color(0xFFF8F3F9),
//       padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
//       child: Row(
//         children: [
//           const Text("Rows per page:"),
//           const SizedBox(width: 8),
//           DropdownButton<int>(
//             value: rowsPerPage,
//             items: [5, 10, 20, 50].map((e) {
//               return DropdownMenuItem(value: e, child: Text(e.toString()));
//             }).toList(),
//             onChanged: (value) {
//               if (value != null) {
//                 setState(() {
//                   rowsPerPage = value;
//                   currentPage = 0;
//                 });
//               }
//             },
//           ),
//           const Spacer(),
//           Text("${start + 1}–$end of $total"),
//           IconButton(
//             icon: const Icon(Icons.chevron_left),
//             onPressed: currentPage > 0
//                 ? () => setState(() => currentPage--)
//                 : null,
//           ),
//           IconButton(
//             icon: const Icon(Icons.chevron_right),
//             onPressed: (currentPage + 1) < totalPages
//                 ? () => setState(() => currentPage++)
//                 : null,
//           ),
//         ],
//       ),
//     );
//   }

// class _SortableHeader extends StatelessWidget {
//   final String label;
//   final int flex;
//   final int columnIndex;
//   final int? sortColumnIndex;
//   final bool ascending;
//   final ValueChanged<bool> onSort;

//   const _SortableHeader({
//     required this.label,
//     required this.flex,
//     required this.columnIndex,
//     required this.sortColumnIndex,
//     required this.ascending,
//     required this.onSort,
//   });

//   @override
//   Widget build(BuildContext context) {
//     final isSorted = columnIndex == sortColumnIndex;
//     return Expanded(
//       flex: flex,
//       child: InkWell(
//         onTap: () => onSort(!(isSorted && ascending)),
//         child: Row(
//           children: [
//             Text(
//               label,
//               style: const TextStyle(fontWeight: FontWeight.w500, fontFamily: 'Arial', fontSize: 16, color: Colors.white),
//             ),
//             if (isSorted)
//               Icon(
//                 ascending ? Icons.arrow_drop_up : Icons.arrow_drop_down,
//                 size: 20,
//                 color: Colors.white,
//               ),
//           ],
//         ),
//       ),
//     );
//   }
// }
