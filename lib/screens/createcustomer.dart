import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;
import 'package:rcspos/utils/urls.dart';

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

  String _selectedType = 'person';

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
    super.dispose();
  }

  Widget _buildTextField(
    TextEditingController controller,
    String labelText,
    IconData icon, {
    String? hintText,
    TextInputType keyboardType = TextInputType.text,
    int? maxLength,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
    bool required = false,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLength: maxLength,
      inputFormatters: inputFormatters,
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
      autovalidateMode: (validator != null || required) ? AutovalidateMode.onUserInteraction : AutovalidateMode.disabled,
    );
  }

  List<Widget> _buildCompanyFields({bool isMobile = false, bool? leftColumn}) {
    List<Widget> fields = [];
    if (isMobile) {
      fields = [
        _buildTextField(contactAddressController, 'Contact Address', Icons.location_on, hintText: 'Building, Street, Area', required: true),
        const SizedBox(height: 16),
        _buildTextField(street2Controller, 'Suite/Unit (optional)', Icons.meeting_room, hintText: 'Apartment, Suite, Unit, Building'),
        const SizedBox(height: 16),
        _buildTextField(cityController, 'City', Icons.location_city, hintText: 'e.g., Chennai', required: true),
        const SizedBox(height: 16),
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
        const SizedBox(height: 16),
        _buildTextField(vatController, 'VAT / GSTIN (optional)', Icons.confirmation_number, hintText: 'Enter VAT/GSTIN number'),
      ];
    } else {
      if (leftColumn == true) {
        fields = [
          _buildTextField(contactAddressController, 'Contact Address', Icons.location_on, hintText: 'Building, Street, Area', required: true),
          const SizedBox(height: 16),
          _buildTextField(cityController, 'City', Icons.location_city, hintText: 'e.g., Chennai', required: true),
        ];
      } else {
        fields = [
          _buildTextField(street2Controller, 'Suite/Unit (optional)', Icons.meeting_room, hintText: 'Apartment, Suite, Unit, Building'),
          const SizedBox(height: 16),
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

    // *********** IMPORTANT: Use the correct endpoint and content type ***********
    final uri = Uri.parse('${baseurl}/mobile/create_customers'); // Changed to create_customers
    final headers = {
      HttpHeaders.contentTypeHeader: 'application/x-www-form-urlencoded', // Changed to form-urlencoded
      HttpHeaders.cookieHeader: session,
    };

    // Convert payload for form-urlencoded
    final formBody = customerData.map((k, v) => MapEntry(k, v?.toString() ?? ''));

    try {
      final response = await http.post(uri, headers: headers, body: formBody); // Send formBody
      debugPrint('Response status: ${response.statusCode}');
      debugPrint('Response body: ${response.body}');

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Customer created successfully!', style: TextStyle(fontFamily: 'Arial')), backgroundColor: Colors.green),
        );
        return true;
      } else {
        // Attempt to parse JSON error, but be prepared for HTML (405)
        String errorMessage = 'Unknown error';
        try {
          final decodedBody = json.decode(response.body);
          errorMessage = decodedBody['error']['message'] ?? 'Unknown error (no message in JSON)';
        } catch (e) {
          errorMessage = 'Server returned non-JSON response (Status: ${response.statusCode}). Raw: ${response.body.substring(0, response.body.length > 200 ? 200 : response.body.length)}...';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to create customer: $errorMessage', style: TextStyle(fontFamily: 'Arial')), backgroundColor: Colors.red),
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
  if (!_formKey.currentState!.validate()) return;

  final name = nameController.text.trim();

  // Step 1: Confirmation Dialog with Icon
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

  // Step 2: Payload preparation
  final newCustomerData = {
    'name': name,
    'phone': phoneController.text.trim(),
     if (emailController.text.trim().isNotEmpty)
    'email': emailController.text.trim(),
    'company_type': _selectedType,
    if (_selectedType == 'company') 'contact_address': contactAddressController.text.trim(),
    if (_selectedType == 'company') 'street2': street2Controller.text.trim(),
    if (_selectedType == 'company') 'city': cityController.text.trim(),
    if (_selectedType == 'company') 'zip': zipController.text.trim(),
    if (_selectedType == 'company') 'vat': vatController.text.trim(),
  };

  debugPrint('Creating customer with: $newCustomerData');

  // Step 3: Attempt creation
  final success = await _createCustomer(newCustomerData);

  // Step 4: Success or Failure Dialog with Icon
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
      insetPadding: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 10,
      title: const Text(
        'Add New Customer',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: Color.fromARGB(255, 1, 139, 82),
          fontFamily: 'Arial',
        ),
      ),
      content: Container(
        width: isMobile ? double.infinity : 650,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 16),

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
                const SizedBox(height: 16),

                _buildTextField(nameController, 'Full Name', Icons.person, hintText: 'Enter customer\'s full name', required: true),
                const SizedBox(height: 16),
                _buildTextField(phoneController, 'Phone Number', Icons.phone,
                    keyboardType: TextInputType.phone,
                    maxLength: 10,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Phone number is required';
                      if (v.length != 10) return 'Must be exactly 10 digits';
                      return null;
                    },
                    hintText: 'e.g., 9876543210 (10 digits)'),
                const SizedBox(height: 16),
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
                const SizedBox(height: 16),

                if (_selectedType == 'company') ...[
                  const SizedBox(height: 24),
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
                            const SizedBox(height: 16),
                            _buildTextField(vatController, 'VAT / GSTIN (optional)', Icons.confirmation_number, hintText: 'Enter VAT/GSTIN number'),
                          ],
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
}