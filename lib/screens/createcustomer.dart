import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;
import 'package:rcspos/utils/urls.dart'; // Ensure this path is correct

class CreateCustomerPage extends StatefulWidget {
  const CreateCustomerPage({super.key});

  @override
  State<CreateCustomerPage> createState() => _CreateCustomerPageState();
}

class _CreateCustomerPageState extends State<CreateCustomerPage> {
  final _formKey = GlobalKey<FormState>();
  final nameController = TextEditingController();
  final phoneController = TextEditingController();
  final emailController = TextEditingController();
  final contactAddressController = TextEditingController();
  final street2Controller = TextEditingController();
  final cityController = TextEditingController();
  final zipController = TextEditingController();
  final vatController = TextEditingController();

  // New controllers for credit request
  final creditDaysController = TextEditingController();
  final creditAmountController = TextEditingController();
  final reasonController = TextEditingController();

  String _selectedType = 'person';
  bool _createCreditRequest = false; // New state for the checkbox

  @override
  void dispose() {
    nameController.dispose();
    phoneController.dispose();
    emailController.dispose();
    contactAddressController.dispose();
    street2Controller.dispose();
    cityController.dispose();
    zipController.dispose();
    vatController.dispose();
    // Dispose new controllers
    creditDaysController.dispose();
    creditAmountController.dispose();
    reasonController.dispose();
    super.dispose();
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
    bool enabled = true, // Added enabled property
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLength: maxLength,
      inputFormatters: inputFormatters,
      enabled: enabled, // Apply enabled property
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
        _buildTextField(street2Controller, 'Suite/Unit (optional)', Icons.meeting_room,
            hintText: 'Apartment, Suite, Unit, Building'),
        const SizedBox(height: 10),
        _buildTextField(cityController, 'City', Icons.location_city,
            hintText: 'e.g., Chennai', required: true),
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
          _buildTextField(cityController, 'City', Icons.location_city,
              hintText: 'e.g., Chennai', required: true),
        ];
      } else {
        fields = [
          _buildTextField(street2Controller, 'Suite/Unit (optional)', Icons.meeting_room,
              hintText: 'Apartment, Suite, Unit, Building'),
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

  Future<bool> _createCustomer(Map<String, dynamic> customerData) async {
    final box = await Hive.openBox('login');
    final raw = box.get('session_id') as String?;
    final session = raw!.contains('session_id=') ? raw : 'session_id=$raw';

    final uri = Uri.parse('${baseurl}/mobile/create_customers');
    final headers = {
      HttpHeaders.contentTypeHeader: 'application/x-www-form-urlencoded',
      HttpHeaders.cookieHeader: session,
    };

    final formBody = customerData.map((k, v) => MapEntry(k, v?.toString() ?? ''));

    try {
      final response = await http.post(uri, headers: headers, body: formBody);
      debugPrint('Response status: ${response.statusCode}');
      debugPrint('Response body: ${response.body}');

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Customer created successfully!', style: TextStyle(fontFamily: 'Arial')),
              backgroundColor: Colors.green),
        );
        return true;
      } else {
        String errorMessage = 'Unknown error';
        try {
          final decodedBody = json.decode(response.body);
          errorMessage = decodedBody['error']['message'] ?? 'Unknown error (no message in JSON)';
        } catch (e) {
          errorMessage =
              'Server returned non-JSON response (Status: ${response.statusCode}). Raw: ${response.body.substring(0, response.body.length > 200 ? 200 : response.body.length)}...';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Failed to create customer: $errorMessage', style: TextStyle(fontFamily: 'Arial')),
              backgroundColor: Colors.red),
        );
        return false;
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('An error occurred: $e', style: TextStyle(fontFamily: 'Arial')), backgroundColor: Colors.red),
      );
      debugPrint('Exception during customer creation: $e');
      return false;
    }
  }

  void _onCreatePressed() async {
    if (!_formKey.currentState!.validate()) {
      // If validation fails, scroll to the first invalid field
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

    final newCustomerData = {
      'name': name,
      'phone': phoneController.text.trim(),
      if (emailController.text.trim().isNotEmpty) 'email': emailController.text.trim(),
      'company_type': _selectedType,
      if (_selectedType == 'company') 'contact_address': contactAddressController.text.trim(),
      if (_selectedType == 'company') 'street2': street2Controller.text.trim(),
      if (_selectedType == 'company') 'city': cityController.text.trim(),
      if (_selectedType == 'company') 'zip': zipController.text.trim(),
      if (_selectedType == 'company') 'vat': vatController.text.trim(),
      // Add credit request fields conditionally
      if (_createCreditRequest) ...{
        'create_credit_request': 'true', // As a string 'true'
        'req_credit_days': creditDaysController.text.trim(), // Send as string, server will parse to int
        'req_credit_amount': creditAmountController.text.trim(), // Send as string, server will parse to float
        'reason': reasonController.text.trim(),
      }
    };

    debugPrint('Creating customer with: $newCustomerData');

    final success = await _createCustomer(newCustomerData);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 10),
        title: Column(
          children: [
            Icon(
              success ? Icons.check_circle_outline : Icons.error_outline,
              size: 48,
              color: success ? const Color(0xFF018B52) : Colors.red,
            ),
            const SizedBox(height: 10),
            Text(
              success ? 'Customer Created' : 'Creation Failed',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Arial',
                fontWeight: FontWeight.bold,
                fontSize: 20,
                color: success ? const Color(0xFF018B52) : Colors.red,
              ),
            ),
          ],
        ),
        content: Text(
          success
              ? 'Customer "$name" has been created successfully.'
              : 'Failed to create customer "$name". Please try again.',
          textAlign: TextAlign.center,
          style: const TextStyle(fontFamily: 'Arial', fontSize: 16),
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx); // Close dialog
              if (success) Navigator.pop(context, true); // Also close Create page
            },
            style: TextButton.styleFrom(
              foregroundColor: success ? const Color(0xFF018B52) : Colors.red,
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
      content: SizedBox( // Use SizedBox with explicit width for dialog content
        width: isMobile ? double.maxFinite : 650, // double.maxFinite is better than double.infinity for constraints
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
                                vatController.clear();
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
                _buildTextField(nameController, 'Full Name', Icons.person, hintText: 'Enter customer\'s full name', required: true),
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
                    hintText: 'e.g., 9876543210 (10 digits)', required: true), // Made phone required
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
                  contentPadding: EdgeInsets.zero, // Remove default padding
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
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly], // Or allow decimals if needed
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
                // --- End Credit Request Section ---
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
}