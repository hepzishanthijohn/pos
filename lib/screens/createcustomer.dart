import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'dart:async';

import 'package:flutter/services.dart';
import 'package:hive/hive.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:http/http.dart' as http;
import 'package:rcspos/components/snackbar_helper.dart';
import 'package:rcspos/data/customerdata.dart';
import 'package:rcspos/localdb/customersqlitehelper.dart';
import 'package:rcspos/screens/customerpage.dart';
import 'package:rcspos/utils/urls.dart'; // Ensure this path is correct

class CreateCustomerPage extends StatefulWidget {
  const CreateCustomerPage({super.key});

  @override
  State<CreateCustomerPage> createState() => _CreateCustomerPageState();
}

class _CreateCustomerPageState extends State<CreateCustomerPage> {
  late final Customersqlitehelper customerHelper;
  // No need for _customerDB if customerHelper is the instance
  // final _customerDB = Customersqlitehelper.instance; // Keep this if you prefer, but customerHelper is the same

  final _formKey = GlobalKey<FormState>();
  final nameController = TextEditingController();
  final phoneController = TextEditingController();
  final emailController = TextEditingController();
  final contactAddressController = TextEditingController();
  final street2Controller = TextEditingController();
  final cityController = TextEditingController();
  final zipController = TextEditingController();
  final vatController = TextEditingController(); // For GSTIN
  bool isLoading = false;
  // New controllers for credit request
  final creditDaysController = TextEditingController();
  final creditAmountController = TextEditingController();
  final reasonController = TextEditingController();

  String _selectedType = 'person';
  bool _createCreditRequest = false;
  bool _isSaving = false;

  List<Map<String, String>> tamilNaduDistricts = [
    {'district': 'Ariyalur', 'state': 'Tamil Nadu'},
    {'district': 'Chengalpattu', 'state': 'Tamil Nadu'},
    {'district': 'Chennai', 'state': 'Tamil Nadu'},
    {'district': 'Coimbatore', 'state': 'Tamil Nadu'},
    {'district': 'Cuddalore', 'state': 'Tamil Nadu'},
    {'district': 'Dharmapuri', 'state': 'Tamil Nadu'},
    {'district': 'Dindigul', 'state': 'Tamil Nadu'},
    {'district': 'Erode', 'state': 'Tamil Nadu'},
    {'district': 'Kallakurichi', 'state': 'Tamil Nadu'},
    {'district': 'Kanchipuram', 'state': 'Tamil Nadu'},
    {'district': 'Kanyakumari', 'state': 'Tamil Nadu'},
    {'district': 'Karur', 'state': 'Tamil Nadu'},
    {'district': 'Krishnagiri', 'state': 'Tamil Nadu'},
    {'district': 'Madurai', 'state': 'Tamil Nadu'},
    {'district': 'Mayiladuthurai', 'state': 'Tamil Nadu'},
    {'district': 'Nagapattinam', 'state': 'Tamil Nadu'},
    {'district': 'Namakkal', 'state': 'Tamil Nadu'},
    {'district': 'Nilgiris', 'state': 'Tamil Nadu'},
    {'district': 'Perambalur', 'state': 'Tamil Nadu'},
    {'district': 'Pudukkottai', 'state': 'Tamil Nadu'},
    {'district': 'Ramanathapuram', 'state': 'Tamil Nadu'},
    {'district': 'Ranipet', 'state': 'Tamil Nadu'},
    {'district': 'Salem', 'state': 'Tamil Nadu'},
    {'district': 'Sivaganga', 'state': 'Tamil Nadu'},
    {'district': 'Tenkasi', 'state': 'Tamil Nadu'},
    {'district': 'Thanjavur', 'state': 'Tamil Nadu'},
    {'district': 'Theni', 'state': 'Tamil Nadu'},
    {'district': 'Thoothukudi', 'state': 'Tamil Nadu'},
    {'district': 'Tiruchirappalli', 'state': 'Tamil Nadu'},
    {'district': 'Tirunelveli', 'state': 'Tamil Nadu'},
    {'district': 'Tirupathur', 'state': 'Tamil Nadu'},
    {'district': 'Tiruppur', 'state': 'Tamil Nadu'},
    {'district': 'Tiruvallur', 'state': 'Tamil Nadu'},
    {'district': 'Tiruvannamalai', 'state': 'Tamil Nadu'},
    {'district': 'Tiruvarur', 'state': 'Tamil Nadu'},
    {'district': 'Vellore', 'state': 'Tamil Nadu'},
    {'district': 'Viluppuram', 'state': 'Tamil Nadu'},
    {'district': 'Virudhunagar', 'state': 'Tamil Nadu'},
  ];

  Map<String, String>? selectedDistrict;

  final TextEditingController districtController = TextEditingController();
  final TextEditingController pincodeController = TextEditingController();

 

@override
void initState() {
  super.initState();

  customerHelper = Customersqlitehelper.instance;
   
_syncUnsyncedCustomers();
}


  @override
  void dispose() {
    nameController.dispose();
    phoneController.dispose();
    emailController.dispose();
    contactAddressController.dispose();
    street2Controller.dispose();
    cityController.dispose();
    zipController.dispose();
    vatController.dispose(); // Dispose GST controller
    creditDaysController.dispose();
    creditAmountController.dispose();
    reasonController.dispose();
    super.dispose();
  }


  Future<bool> _createCustomer(Map<String, dynamic> customerData) async {
    try {
      final localId = await customerHelper.insertLocalCustomer(customerData);
      debugPrint('✅ Customer created locally with ID: $localId');
      return true;
    } catch (e) {
      debugPrint('❌ Error creating customer locally: $e');
      return false;
    }
  }
Future<void> _syncUnsyncedCustomers() async {
  final unsyncedCustomers = customerHelper.fetchUnsyncedCustomers();

  if (unsyncedCustomers.isEmpty) {
    debugPrint('No unsynced customers to upload.');
    return;
  }

  final List<Map<String, dynamic>> payload = unsyncedCustomers.map((customer) {
    final customerData = Map<String, dynamic>.from(customer);
    customerData.remove('id');
    if (customerData['phone'] is String && customerData['phone'].isNotEmpty) {
      try {
        customerData['phone'] = int.parse(customerData['phone']);
      } catch (e) {
        debugPrint('Error parsing phone number for customer: ${customerData['name']}');
      }
    }
    return customerData;
  }).toList();
  
  debugPrint('Payload being sent to server: ${jsonEncode(payload)}');

  final box = await Hive.openBox('login');
  final sessionId = box.get('session_id');
  if (sessionId == null) {
    debugPrint('❌ No session ID available for syncing customers.');
    return;
  }

  try {
    final response = await http.post(
      Uri.parse('$baseurl/mobile/create_customers'),
      headers: {
        HttpHeaders.cookieHeader: sessionId,
        HttpHeaders.contentTypeHeader: 'application/json',
      },
      body: jsonEncode(payload),
    );

    debugPrint('Server responded with Status Code: ${response.statusCode}');
    debugPrint('Server Response Body: ${response.body}');

    if (response.statusCode == 200) {
      final List<dynamic> responseJson = json.decode(response.body);

      if (responseJson.isNotEmpty && responseJson.first is Map && responseJson.first.containsKey('id')) {
        debugPrint('✅ All unsynced customers synced successfully.');
        for (final customerResponse in responseJson) {
          final int? localId = customerResponse['local_id'];
          final int? remoteId = customerResponse['id'];

          if (localId != null && remoteId != null) {
            await customerHelper.markCustomerAsSynced(localId, remoteId);
          }
        }
      } else {
        debugPrint('❌ Sync failed despite 200 OK. Server response was invalid.');
      }
    } else {
      final responseBody = json.decode(response.body);
      final errorMessage = responseBody['error']['message'] ?? 'Unknown server error.';
      debugPrint('❌ Failed to sync customers. Status code: ${response.statusCode}');
      debugPrint('Server Error: $errorMessage');
    }
  } catch (e) {
    debugPrint('❌ Error during bulk customer sync: $e');
  }
}

void _onCreatePressed() async {
  if (!_formKey.currentState!.validate()) {
    Scrollable.ensureVisible(
      _formKey.currentContext!,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeIn,
      alignment: 0.5,
    );
    return;
  }

  final name = nameController.text.trim();

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 10),
      title: Column(
        children: const [
          Icon(Icons.help_outline, size: 48, color: Color(0xFF018B52)),
          SizedBox(height: 10),
          Text(
            'Confirmation',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Arial',
              fontWeight: FontWeight.bold,
              fontSize: 20,
              color: Color(0xFF018B52),
            ),
          ),
        ],
      ),
      content: Text(
        'Are you sure you want to create Customer "$name"?',
        textAlign: TextAlign.center,
        style: const TextStyle(fontFamily: 'Arial', fontSize: 16),
      ),
      actionsAlignment: MainAxisAlignment.center,
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          style: TextButton.styleFrom(
            foregroundColor: Colors.grey[700],
            textStyle: const TextStyle(fontFamily: 'Arial', fontSize: 16),
          ),
          child: const Text('Cancel'),
        ),
        ElevatedButton.icon(
          icon: const Icon(Icons.check_circle_outline),
          label: const Text('Yes, Create'),
          onPressed: () => Navigator.pop(ctx, true),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF018B52),
            foregroundColor: Colors.white,
            textStyle: const TextStyle(fontFamily: 'Arial', fontWeight: FontWeight.bold),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
      ],
    ),
  );

  if (confirmed != true) return;

  String fullAddress = [
    contactAddressController.text.trim(),
    street2Controller.text.trim(),
    cityController.text.trim(),
    zipController.text.trim()
  ].where((part) => part.isNotEmpty).join(', ');

  final newCustomerData = {
    'name': name.trim(),
    'phone': phoneController.text.trim().toString(),
    'email': emailController.text.trim().isNotEmpty ? emailController.text.trim() : null,
    'company_type': _selectedType,
    'contact_address': fullAddress,
    if (_selectedType == 'company' && vatController.text.trim().isNotEmpty)
      'gst_number': vatController.text.trim(),

    if (_createCreditRequest) ...{
      'create_credit_request': 'true',
      'req_credit_days': creditDaysController.text.trim(),
      'req_credit_amount': creditAmountController.text.trim(),
      'reason': reasonController.text.trim(),
    }
  };
  debugPrint('Attempting to create customer locally with: $newCustomerData');

  final localSuccess = await _createCustomer(newCustomerData);

 if (localSuccess) {
    // debugPrint('✅ Customer created locally with ID: $localId');
    final connectivityResult = await (Connectivity().checkConnectivity());

    // Call the bulk sync function instead of a single sync.
    if (connectivityResult.isNotEmpty && !connectivityResult.contains(ConnectivityResult.none)) {
      debugPrint('Device is online. Attempting to sync all unsynced customers.');
      await _syncUnsyncedCustomers();
    }
  }

  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 10),
      title: Column(
        children: [
          Icon(
            localSuccess ? Icons.check_circle_outline : Icons.error_outline,
            size: 48,
            color: localSuccess ? const Color(0xFF018B52) : Colors.red,
          ),
          const SizedBox(height: 10),
          Text(
            localSuccess ? 'Customer Created' : 'Creation Failed',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Arial',
              fontWeight: FontWeight.bold,
              fontSize: 20,
              color: localSuccess ? const Color(0xFF018B52) : Colors.red,
            ),
          ),
        ],
      ),
      content: Text(
        localSuccess
            ? 'Customer "$name" has been created locally and queued for sync.'
            : 'Failed to create customer "$name" locally. Please try again.',
        textAlign: TextAlign.center,
        style: const TextStyle(fontFamily: 'Arial', fontSize: 16),
      ),
      actionsAlignment: MainAxisAlignment.center,
      actions: [
        TextButton(
          onPressed: () {
            Navigator.pop(ctx);
            if (localSuccess) {
              Navigator.pop(context, true);
            }
          },
          style: TextButton.styleFrom(
            foregroundColor: localSuccess ? const Color(0xFF018B52) : Colors.red,
            textStyle: const TextStyle(fontFamily: 'Arial', fontSize: 16, fontWeight: FontWeight.bold),
          ),
          child: const Text('OK'),
        ),
      ],
    ),
  );
}
  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;

    return AlertDialog(
      insetPadding: const EdgeInsets.all(0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 0,
      title: const Text(
        'Create New Customer',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: Color.fromARGB(255, 9, 2, 110),
          fontFamily: 'Arial',
        ),
      ),
      content: SizedBox(
        width: isMobile ? double.maxFinite : 650,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 10),

                // Customer Type Selection
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Customer Type:',
                      style: TextStyle(
                        fontFamily: 'Arial',
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: RadioListTile<String>(
                            title: const Text('Person', style: TextStyle(fontFamily: 'Arial')),
                            value: 'person',
                            groupValue: _selectedType,
                            onChanged: (value) {
                              setState(() {
                                _selectedType = value!;
                                // Clear company-specific fields when switching to 'person'
                                contactAddressController.clear();
                                street2Controller.clear();
                                cityController.clear();
                                zipController.clear();
                                vatController.clear(); // Clear GST
                              });
                            },
                            activeColor: const Color.fromARGB(255, 1, 139, 82),
                          ),
                        ),
                        Expanded(
                          child: RadioListTile<String>(
                            title: const Text('Company', style: TextStyle(fontFamily: 'Arial')),
                            value: 'company',
                            groupValue: _selectedType,
                            onChanged: (value) {
                              setState(() {
                                _selectedType = value!;
                              });
                            },
                            activeColor: const Color.fromARGB(255, 1, 139, 82),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Basic Customer Info
                _buildTextField(nameController, 'Full Name', Icons.person,
                    hintText: 'Enter customer\'s full name', required: true),
                const SizedBox(height: 10),
                _buildTextField(phoneController, 'Phone Number', Icons.phone,
                    keyboardType: TextInputType.phone,
                    maxLength: 10,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Phone number is required';
                      if (v.length != 10) return 'Must be exactly 10 digits';
                      return null;
                    },
                    hintText: 'e.g., 9876543210 (10 digits)', required: true),
                const SizedBox(height: 10),
                _buildTextField(emailController, 'Email (optional)', Icons.email,
                    keyboardType: TextInputType.emailAddress,
                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9@._\-]'))],
                    validator: (v) {
                      final t = v?.trim() ?? '';
                      if (t.isEmpty) return null;
                      final pattern = r'^[\w.\-]+@([\w\-]+\.)+[\w]{2,4}$';
                      return RegExp(pattern).hasMatch(t) ? null : 'Enter a valid email';
                    },
                    hintText: 'e.g., customer@example.com'),

                // Company-specific fields
                if (_selectedType == 'company') ...[
                  const SizedBox(height: 10),
                  isMobile
                      ? Column(
                          children: _buildCompanyFields(isMobile: true),
                        )
                      : Column(
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(child: Column(children: _buildCompanyFields(leftColumn: true))),
                                const SizedBox(width: 16),
                                Expanded(child: Column(children: _buildCompanyFields(leftColumn: false))),
                              ],
                            ),
                            const SizedBox(height: 10),
                            _buildTextField(vatController, 'VAT / GSTIN (optional)', Icons.confirmation_number,
                                hintText: 'Enter VAT/GSTIN number'),
                          ],
                        ),
                ],

                // --- Credit Request Section ---

                CheckboxListTile(
                  title: const Text(
                    'Request Credit',
                    style: TextStyle(
                      fontFamily: 'Arial',
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  value: _createCreditRequest,
                  onChanged: (bool? value) {
                    setState(() {
                      _createCreditRequest = value!;
                      // Clear credit fields when checkbox is unchecked
                      if (!_createCreditRequest) {
                        creditDaysController.clear();
                        creditAmountController.clear();
                        reasonController.clear();
                      }
                    });
                  },
                  activeColor: const Color.fromARGB(255, 1, 139, 82),
                  checkColor: Colors.white,
                  contentPadding: EdgeInsets.zero,
                ),

                if (_createCreditRequest) ...[
                  const SizedBox(height: 1),
                  _buildTextField(
                    creditDaysController,
                    'Credit Days',
                    Icons.calendar_month,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    hintText: 'e.g., 30, 60, 90',
                    validator: (v) {
                      if (_createCreditRequest && (v == null || v.trim().isEmpty)) {
                        return 'Credit Days are required';
                      }
                      if (v != null && v.isNotEmpty && int.tryParse(v) == null) {
                        return 'Enter a valid number of days';
                      }
                      return null;
                    },
                    required: true,
                  ),
                  const SizedBox(height: 10),
                  _buildTextField(
                    creditAmountController,
                    'Credit Amount',
                    Icons.currency_rupee,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    hintText: 'e.g., 50000',
                    validator: (v) {
                      if (_createCreditRequest && (v == null || v.trim().isEmpty)) {
                        return 'Credit Amount is required';
                      }
                      if (v != null && v.isNotEmpty && double.tryParse(v) == null) {
                        return 'Enter a valid amount';
                      }
                      return null;
                    },
                    required: true,
                  ),
                  const SizedBox(height: 10),
                  _buildTextField(
                    reasonController,
                    'Reason for Credit Request',
                    Icons.info_outline,
                    hintText: 'e.g., New corporate account, long-term client',
                    keyboardType: TextInputType.multiline,
                    maxLength: 200,
                    maxLines: 3,
                    validator: (v) {
                      if (_createCreditRequest && (v == null || v.trim().isEmpty)) {
                        return 'Reason is required for credit request';
                      }
                      return null;
                    },
                    required: true,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(28, 0, 28, 28),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          style: TextButton.styleFrom(
            foregroundColor: Colors.grey[700],
            textStyle: const TextStyle(fontFamily: 'Arial', fontSize: 16),
          ),
          child: const Text('Cancel', style: TextStyle(fontFamily: 'Arial')),
        ),
        const SizedBox(width: 12),
        ElevatedButton.icon(
          icon: const Icon(Icons.add_circle_outline),
          label: const Text('Create', style: TextStyle(fontFamily: 'Arial', fontWeight: FontWeight.bold)),
          onPressed: _onCreatePressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color.fromARGB(255, 1, 139, 82),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
      ],
    );
  }


    Widget _buildTextField(
    TextEditingController controller,
    String labelText,
    IconData icon, {
    String? hintText,
    TextInputType keyboardType = TextInputType.text,
    int? maxLength,
    int? maxLines,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
    bool required = false,
    bool enabled = true,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLength: maxLength,
      inputFormatters: inputFormatters,
      enabled: enabled,
      decoration: InputDecoration(
        labelText: labelText,
        hintText: hintText,
        border: const OutlineInputBorder(),
        prefixIcon: Icon(icon),
        counterText: maxLength != null ? '' : null,
        labelStyle: const TextStyle(fontFamily: 'Arial'),
        hintStyle: const TextStyle(fontFamily: 'Arial'),
        errorStyle: const TextStyle(fontFamily: 'Arial'),
      ),
      validator: (v) {
        if (required && (v == null || v.trim().isEmpty)) {
          return '$labelText is required';
        }
        if (validator != null) {
          return validator(v);
        }
        return null;
      },
      style: const TextStyle(fontFamily: 'Arial'),
      autovalidateMode: (validator != null || required)
          ? AutovalidateMode.onUserInteraction
          : AutovalidateMode.disabled,
    );
  }

  List<Widget> _buildCompanyFields({bool isMobile = false, bool? leftColumn}) {
    List<Widget> fields = [];
    if (isMobile) {
      fields = [
        _buildTextField(contactAddressController, 'Contact Address', Icons.location_on,
            hintText: 'Building, Street, Area', required: true),
        const SizedBox(height: 10),
        _buildTextField(street2Controller, 'Street (optional)', Icons.meeting_room,
            hintText: 'Street'),
        const SizedBox(height: 10),
        DropdownButtonFormField<Map<String, String>>(
          value: selectedDistrict,
          items: tamilNaduDistricts.map((districtData) {
            final displayName = '${districtData['district']}, ${districtData['state']}';
            return DropdownMenuItem<Map<String, String>>(
              value: districtData,
              child: Text(displayName),
            );
          }).toList(),
          onChanged: (value) {
            setState(() {
              selectedDistrict = value;
              cityController.text = '${value?['district']}, ${value?['state']}';
            });
          },
          decoration: const InputDecoration(
            labelText: 'District',
            prefixIcon: Icon(Icons.location_city),
            hintText: 'e.g., Chennai, Tamil Nadu',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 10),
        _buildTextField(zipController, 'ZIP', Icons.local_post_office,
            keyboardType: TextInputType.number,
            maxLength: 6,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'ZIP is required';
              if (v.trim().length != 6) return 'ZIP must be 6 digits';
              return null;
            },
            required: true),
        const SizedBox(height: 10),
        _buildTextField(vatController, 'VAT / GSTIN (optional)', Icons.confirmation_number,
            hintText: 'Enter VAT/GSTIN number'),
      ];
    } else {
      if (leftColumn == true) {
        fields = [
          _buildTextField(contactAddressController, 'Contact Address', Icons.location_on,
              hintText: 'Building, Street, Area', required: true),
          const SizedBox(height: 10),
          DropdownButtonFormField<Map<String, String>>(
            value: selectedDistrict,
            items: tamilNaduDistricts.map((districtData) {
              final displayName = '${districtData['district']}, ${districtData['state']}';
              return DropdownMenuItem<Map<String, String>>(
                value: districtData,
                child: Text(displayName),
              );
            }).toList(),
            onChanged: (value) {
              setState(() {
                selectedDistrict = value;
                cityController.text = '${value?['district']}, ${value?['state']}';
              });
            },
            decoration: const InputDecoration(
              labelText: 'District',
              prefixIcon: Icon(Icons.location_city),
              hintText: 'e.g., Chennai, Tamil Nadu',
              border: OutlineInputBorder(),
            ),
          )
        ];
      } else {
        fields = [
          _buildTextField(street2Controller, 'Street (optional)', Icons.meeting_room,
              hintText: 'Street'),
          const SizedBox(height: 10),
          _buildTextField(zipController, 'ZIP', Icons.local_post_office,
              keyboardType: TextInputType.number,
              maxLength: 6,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'ZIP is required';
                if (v.trim().length != 6) return 'ZIP must be 6 digits';
                return null;
              },
              required: true),
        ];
      }
    }
    return fields;
  }


}