import 'dart:convert';
import 'dart:io';
import 'package:intl/intl.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:hive_flutter/hive_flutter.dart';
import 'package:rcspos/localdb/CreditCustomerSQLiteHelper.dart';
import 'package:rcspos/screens/CreditEditDialog.dart'; // This should now be CreditApproveDialog
import 'package:rcspos/utils/urls.dart';

class CreditCustomersPage extends StatefulWidget {
  const CreditCustomersPage({Key? key}) : super(key: key);

  @override
  State<CreditCustomersPage> createState() => _CreditCustomersPageState();
}

class _CreditCustomersPageState extends State<CreditCustomersPage> {
  List<Map<String, dynamic>> _customers = [];
  bool _loading = true;
  String? _error;
  int currentPage = 0;
  int? _sortColumnIndex;
  bool _sortAscending = true;
  int rowsPerPage = PaginatedDataTable.defaultRowsPerPage;

  final CreditDbHelperRawSqlite _dbHelper = CreditDbHelperRawSqlite();

  TextEditingController _searchController = TextEditingController();

  // No change to _compare
  int _compare(String? a, String? b) =>
      (a ?? '').toLowerCase().compareTo((b ?? '').toLowerCase());

  // No change to _compareNum
  int _compareNum(dynamic a, dynamic b) {
    final doubleA = double.tryParse('$a'.replaceAll('₹', '')) ?? 0;
    final doubleB = double.tryParse('$b'.replaceAll('₹', '')) ?? 0;
    return doubleA.compareTo(doubleB);
  }

  // No change to formatDateTime
  String formatDateTime(String? rawDate) {
    if (rawDate == null || rawDate.isEmpty || rawDate == '-') return '-';
    try {
      final dateTime = DateTime.parse(rawDate);
      return DateFormat('dd/MM/yyyy h:mm a').format(dateTime);
    } catch (e) {
      try {
        final dateTime = DateFormat('yyyy-MM-dd HH:mm:ss').parse(rawDate);
        return DateFormat('dd/MM/yyyy h:mm a').format(dateTime);
      } catch (e2) {
        return '-';
      }
    }
  }

  List<Map<String, dynamic>> get filteredCustomers {
    final q = _searchController.text.trim().toLowerCase();
    List<Map<String, dynamic>> filtered = q.isEmpty
        ? [..._customers]
        : _customers.where((c) {
            final n = (c['name'] ?? '').toLowerCase();
            final p = (c['phone'] ?? '').toLowerCase();
            return n.contains(q) || p.contains(q);
          }).toList();

    if (_sortColumnIndex != null) {
      filtered.sort((a, b) {
        dynamic valueA;
        dynamic valueB;

        switch (_sortColumnIndex) {
          case 1: // Name
            valueA = a['name'] ?? '';
            valueB = b['name'] ?? '';
            break;
          case 2: // Phone
            valueA = a['phone'] ?? '';
            valueB = b['phone'] ?? '';
            break;
          case 3: // Status
            valueA = a['status'] ?? '';
            valueB = b['status'] ?? '';
            break;
          case 4: // Requested (₹)
            valueA = num.tryParse((a['requested'] ?? '0').toString().replaceAll('₹', '')) ?? 0;
            valueB = num.tryParse((b['requested'] ?? '0').toString().replaceAll('₹', '')) ?? 0;
            break;
          case 5: // Approved (₹)
            valueA = num.tryParse((a['approved'] ?? '0').toString().replaceAll('₹', '')) ?? 0;
            valueB = num.tryParse((b['approved'] ?? '0').toString().replaceAll('₹', '')) ?? 0;
            break;
          case 6: // Req Days (Corresponds to days_requested from data)
            valueA = num.tryParse((a['days_requested'] ?? '0').toString()) ?? 0;
            valueB = num.tryParse((b['days_requested'] ?? '0').toString()) ?? 0;
            break;
          case 7: // Approved Days (Corresponds to days from data)
            valueA = num.tryParse((a['days'] ?? '0').toString()) ?? 0;
            valueB = num.tryParse((b['days'] ?? '0').toString()) ?? 0;
            break;
          case 8: // Requested Date
            valueA = DateTime.tryParse(a['requestedDate'] ?? '') ?? DateTime(0);
            valueB = DateTime.tryParse(b['requestedDate'] ?? '') ?? DateTime(0);
            break;
          case 9: // Approved Date
            valueA = DateTime.tryParse(a['approvedDate'] ?? '') ?? DateTime(0);
            valueB = DateTime.tryParse(b['approvedDate'] ?? '') ?? DateTime(0);
            break;
          default:
            valueA = '';
            valueB = '';
        }

        int comparison;
        if (valueA is String) {
          comparison = valueA.toLowerCase().compareTo((valueB as String).toLowerCase());
        } else if (valueA is num || valueA is DateTime) {
          comparison = (valueA as Comparable).compareTo(valueB);
        } else {
          comparison = 0;
        }

        return _sortAscending ? comparison : -comparison;
      });
    }

    return filtered;
  }

  @override
  void initState() {
    super.initState();
    _fetchCreditCustomers(fromServer: false);
    _searchController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _searchController.dispose();
    _dbHelper.close();
    super.dispose();
  }

Future<void> _fetchCreditCustomers({bool fromServer = true}) async {
  setState(() {
    _loading = true;
    _error = null;
  });

  if (!fromServer) {
    try {
      final localCustomers = await _dbHelper.getCustomers();
      if (localCustomers.isNotEmpty) {
        setState(() {
          _customers = localCustomers;
          _loading = false;
          _error = null;
        });
        return; // IMPORTANT: If local data exists, it returns here.
      }
    } catch (e) {
      // Fall through to server fetch if local fails or is empty
      print("Error fetching local data: $e"); // Debugging line
    }
  }

  try {
    final box = await Hive.openBox('login');
    final rawSession = box.get('session_id') as String?;
    if (rawSession == null) {
      setState(() {
        _error = "Session not found. Please log in again.";
        _loading = false;
      });
      return;
    }
    final sessionId = rawSession.contains('session_id=') ? rawSession : 'session_id=$rawSession';

    final url = Uri.parse('$baseurl/mobile/customers_with_credits');
    final resp = await http.get(url, headers: {
      HttpHeaders.cookieHeader: sessionId,
      HttpHeaders.contentTypeHeader: 'application/json',
    });

    if (resp.statusCode == 200) {
      final data = json.decode(resp.body);
      if (data['status'] == 'success' && data['customers'] != null) {
        final original = List<Map<String, dynamic>>.from(data['customers']);
        final filtered = original.where((cust) {
          final s = (cust['credit_status'] ?? '').toString().toLowerCase();
          return s == 'has_credit_request' || s == 'approved' || s == 'pending';
        }).map(_formatCustomerData).toList();

        await _dbHelper.insertCustomers(filtered);

        // Reload from local DB after saving server data
        final localCustomersAfterSave = await _dbHelper.getCustomers();
        setState(() {
          _customers = localCustomersAfterSave;
          _loading = false;
          _error = localCustomersAfterSave.isEmpty ? 'No credit requests found.' : null;
        });
      } else {
        setState(() {
          _error = data['message'] ?? 'Failed to retrieve credit customers.';
          _loading = false;
          _customers.clear();
        });
      }
    } else {
      setState(() {
        final err = json.decode(resp.body);
        _error = err['message'] ?? 'Server error: ${resp.statusCode}';
        _loading = false;
        _customers.clear();
      });
    }
  } on SocketException {
    try {
      final localData = await _dbHelper.getCustomers();
      if (localData.isNotEmpty) {
        setState(() {
          _customers = localData;
          _error = 'No internet (showing cached data from ${formatDateTime(DateTime.now().toIso8601String())}).';
          _loading = false;
        });
      } else {
        setState(() {
          _error = 'No internet connection. No cached data available.';
          _loading = false;
          _customers.clear();
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Error loading cached data: $e';
        _loading = false;
        _customers.clear();
      });
    }
  } catch (e) {
    setState(() {
      _error = "An unexpected error occurred: $e";
      _loading = false;
      _customers.clear();
    });
  }
}

  static Map<String, dynamic> _formatCustomerData(Map<String, dynamic> cust) {
    List<dynamic>? requests = cust['credit_requests'] as List?;
    final latest = (requests != null && requests.isNotEmpty)
        ? Map<String, dynamic>.from(requests.last)
        : null;

    final double requestedAmount = latest?['req_credit_amount'] is num
        ? (latest!['req_credit_amount'] as num).toDouble()
        : (double.tryParse(latest?['req_credit_amount']?.toString() ?? '0.0') ?? 0.0);

    final int requestedDays = latest?['req_credit_days'] is int
        ? (latest!['req_credit_days'] as int)
        : (int.tryParse(latest?['req_credit_days']?.toString() ?? '0') ?? 0);

    final double approvedAmount = latest?['approved_amount'] is num
        ? (latest!['approved_amount'] as num).toDouble()
        : (double.tryParse(latest?['approved_amount']?.toString() ?? '0.0') ?? 0.0);

    final int approvedDays = latest?['approved_days'] is int
        ? (latest!['approved_days'] as int)
        : (int.tryParse(latest?['approved_days']?.toString() ?? '0') ?? 0);

    return {
      'request_id': latest?['request_id'] ?? 0,
      'name': cust['name'] ?? 'Unknown',
      'phone': cust['phone'] ?? '',
      'status': latest?['status']?.toString().toLowerCase() ?? cust['credit_status'] ?? '',
      'requested': requestedAmount.toStringAsFixed(2),
      'days_requested': requestedDays.toString(), // This is the 'req_credit_days' from JSON
      'approved': approvedAmount.toStringAsFixed(2),
      'days': approvedDays.toString(), // This is the 'approved_days' from JSON (or 'days' from DB)
      'requestedDate': latest?['request_date']?.toString() ?? '',
      'approvedDate': latest?['approval_date']?.toString() ?? '',
      'reason': latest?['reason']?.toString() ?? '',
    };
  }

  // No change to _statusColor
  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return const Color.fromARGB(255, 255, 72, 0);
      case 'approved':
        return const Color.fromARGB(255, 7, 155, 12);
      case 'rejected':
        return Colors.red;
      case 'has_credit_request':
      case 'new':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  // No change to _formatStatus
  String _formatStatus(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return 'Pending';
      case 'approved':
        return 'Approved';
      case 'rejected':
        return 'Rejected';
      case 'has_credit_request':
      case 'new':
        return 'New';
      default:
        return status;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FC),
      appBar: AppBar(
        elevation: 0,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color.fromARGB(255, 44, 145, 113), Color(0xFF185A9D)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        title: const Text('Credit Customers', style: TextStyle(color: Colors.white)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: () => _fetchCreditCustomers(fromServer: true),
            tooltip: 'Refresh List',
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Material(
              borderRadius: BorderRadius.circular(28),
              elevation: 2,
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search by name or phone...',
                  prefixIcon: const Icon(Icons.search, color: Colors.grey),
                  suffixIcon: _searchController.text.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => _searchController.clear(),
                        ),
                  fillColor: Colors.white,
                  filled: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(28),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                ),
              ),
            ),
          ),
        ),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(
                color: Color(0xFF185A9D),
                strokeWidth: 4,
              ),
            )
          : _error != null && _customers.isEmpty
              ? _buildError(context)
              : filteredCustomers.isEmpty
                  ? _buildEmpty(context)
                  : _buildDataTable(context),
    );
  }

  Widget _buildDataTable(BuildContext context) {
    final total = filteredCustomers.length;
    final start = currentPage * rowsPerPage;
    final end = (start + rowsPerPage).clamp(0, total);
    final paginatedCustomers = filteredCustomers.sublist(start, end);
    final totalPages = (total / rowsPerPage).ceil();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 0.0, vertical: 8),
      child: Column(
        children: [
          if (_error != null)
            Container(
              padding: const EdgeInsets.all(8.0),
              margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8.0),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.wifi_off, color: Colors.orange.shade700, size: 20),
                  const SizedBox(width: 8.0),
                  Expanded(
                    child: Text(
                      _error!,
                      style: TextStyle(color: Colors.orange.shade700, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  scrollDirection: Axis.vertical,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(minWidth: MediaQuery.of(context).size.width),
                      child: DataTable(
                        columnSpacing: 15,
                        headingRowColor: MaterialStateColor.resolveWith(
                          (states) => const Color(0xFF185A9D),
                        ),
                        headingTextStyle: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w500,
                          fontSize: 16,
                        ),
                        sortColumnIndex: _sortColumnIndex,
                        sortAscending: _sortAscending,
                        dividerThickness: 1,
                        dataRowMinHeight: 50,
                        dataRowMaxHeight: 62,
                        columns: [
                          const DataColumn(label: Text('S.No')),
                          DataColumn(
                            label: const Text('Name'),
                            onSort: (index, asc) => setState(() {
                              _sortColumnIndex = 1;
                              _sortAscending = asc;
                            }),
                          ),
                          DataColumn(
                            label: const Text('Phone'),
                            onSort: (index, asc) => setState(() {
                              _sortColumnIndex = 2;
                              _sortAscending = asc;
                            }),
                          ),
                          DataColumn(
                            label: const Text('Status'),
                            onSort: (index, asc) => setState(() {
                              _sortColumnIndex = 3;
                              _sortAscending = asc;
                            }),
                          ),
                          DataColumn(
                            label: const Text('Requested (₹)'),
                            numeric: true,
                            onSort: (index, asc) => setState(() {
                              _sortColumnIndex = 4;
                              _sortAscending = asc;
                            }),
                          ),
                          DataColumn(
                            label: const Text('Approved (₹)'),
                            numeric: true,
                            onSort: (index, asc) => setState(() {
                              _sortColumnIndex = 5;
                              _sortAscending = asc;
                            }),
                          ),
                          DataColumn( // Column for Requested Days
                            label: const Text('Req Days'),
                            numeric: true,
                            onSort: (index, asc) => setState(() {
                              _sortColumnIndex = 6; // Assign a unique sort index
                              _sortAscending = asc;
                            }),
                          ),
                          DataColumn( // Column for Approved Days
                            label: const Text('Approved Days'),
                            numeric: true,
                            onSort: (index, asc) => setState(() {
                              _sortColumnIndex = 7; // Assign a unique sort index
                              _sortAscending = asc;
                            }),
                          ),
                          DataColumn(
                            label: const Text('Requested Date'),
                            onSort: (index, asc) => setState(() {
                              _sortColumnIndex = 8; // Assign a unique sort index
                              _sortAscending = asc;
                            }),
                          ),
                          DataColumn(
                            label: const Text('Approved Date'),
                            onSort: (index, asc) => setState(() {
                              _sortColumnIndex = 9; // Assign a unique sort index
                              _sortAscending = asc;
                            }),
                          ),
                          const DataColumn(label: Text('Actions')),
                        ],
                        rows: paginatedCustomers.map((customer) {
                          final index = start + paginatedCustomers.indexOf(customer);
                          final status = (customer['status'] ?? '').toString().toLowerCase();

                          // Logic for amountToPass and daysToPass based on status
                          final bool isPendingOrNew = status == 'pending' || status == 'new' || status == 'has_credit_request';
                          final double amountToPass = isPendingOrNew
                              ? double.tryParse(customer['requested'].toString().replaceAll('₹', '')) ?? 0.0
                              : double.tryParse(customer['approved'].toString().replaceAll('₹', '')) ?? 0.0;
                          final int daysToPass = isPendingOrNew
                              ? int.tryParse(customer['days_requested'].toString()) ?? 0
                              : int.tryParse(customer['days'].toString()) ?? 0; // 'days' now holds approved_days from DB

                          // Determine if the edit icon should be enabled
                          final bool isEditEnabled = status != 'approved' && status != 'rejected'; // Disable if approved or rejected


                          return DataRow(cells: [
                            DataCell(Text('${index + 1}')),
                            DataCell(Text(customer['name'] ?? '-', style: const TextStyle(fontSize: 15))),
                            DataCell(Text(customer['phone'] ?? '-', style: const TextStyle(fontSize: 15))),
                            DataCell(
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                                decoration: BoxDecoration(
                                  color: _statusColor(status).withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(18),
                                ),
                                child: Text(
                                  _formatStatus(status),
                                  style: TextStyle(
                                    color: _statusColor(status),
                                    fontWeight: FontWeight.w500,
                                    fontSize: 15,
                                  ),
                                ),
                              ),
                            ),
                            DataCell(Text('₹${customer['requested'] ?? '-'}', style: const TextStyle(fontSize: 15))),
                            DataCell(Text('₹${customer['approved'] ?? '-'}', style: const TextStyle(fontSize: 15))),
                            DataCell(Text('${customer['days_requested'] ?? '-'}', style: const TextStyle(fontSize: 15))), // Displays Req Days
                            DataCell(Text('${customer['days'] ?? '-'}', style: const TextStyle(fontSize: 15))), // Displays Approved Days
                            DataCell(Text(formatDateTime(customer['requestedDate']), style: const TextStyle(fontSize: 15))),
                            DataCell(Text(formatDateTime(customer['approvedDate']), style: const TextStyle(fontSize: 15))),
                            DataCell(
                              IconButton(
                                icon: const Icon(Icons.edit),
                                onPressed: isEditEnabled // Conditionally enable/disable
                                    ? () {
                                        showDialog(
                                          context: context,
                                          builder: (BuildContext context) {
                                            return CreditApproveDialog(
                                              status: customer['status'] ?? '',
                                              requestId: customer['request_id'] as int,
                                              creditCustomerName: customer['name'] ?? '',
                                              currentAmount: amountToPass,
                                              currentDays: daysToPass,
                                              reason: customer['reason'],
                                            );
                                          },
                                        ).then((updated) {
                                          if (updated == true) {
                                            _fetchCreditCustomers(fromServer: true);
                                          }
                                        });
                                      }
                                    : null, // Set to null to disable the button
                                color: isEditEnabled ? Theme.of(context).iconTheme.color : Colors.grey, // Grey out if disabled
                              ),
                            ),
                          ]);
                        }).toList(),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          _buildFooter(total, start, end, totalPages),
        ],
      ),
    );
  }

  Widget _buildError(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error, color: Colors.redAccent, size: 70),
            const SizedBox(height: 18),
            Text(_error!, style: const TextStyle(fontSize: 17, color: Colors.redAccent), textAlign: TextAlign.center),
            const SizedBox(height: 28),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF185A9D), foregroundColor: Colors.white),
              icon: const Icon(Icons.refresh),
              label: const Text('Try Again'),
              onPressed: () => _fetchCreditCustomers(fromServer: true),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.celebration, color: Colors.amber, size: 65),
            const SizedBox(height: 12),
            const Text(
              'No credit customers found!',
              style: TextStyle(fontSize: 16, color: Colors.black87),
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
              const Text("Rows per page:",
                  style: TextStyle(fontFamily: 'Arial', fontSize: 13, color: Colors.black87)),
              const SizedBox(width: 8),
              DropdownButton<int>(
                value: rowsPerPage,
                items: [5, 10, 20, 50].map((e) {
                  return DropdownMenuItem(
                      value: e,
                      child: Text(e.toString(), style: const TextStyle(fontFamily: 'Arial')));
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
                underline: const SizedBox(),
              ),
            ],
          ),
          const Spacer(),
          Text("${start + 1}–$end of $total",
              style: const TextStyle(fontFamily: 'Arial', fontSize: 13, color: Colors.black87)),
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
            onPressed: (currentPage + 1) < totalPages
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