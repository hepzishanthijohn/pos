import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;
import 'package:rcspos/screens/customerpage.dart';
import 'package:rcspos/utils/urls.dart';


class EditCustomerPage extends StatefulWidget {
  final Customer customer;
  const EditCustomerPage({required this.customer, super.key});

  @override
  State<EditCustomerPage> createState() => _EditCustomerPageState();
}

class _EditCustomerPageState extends State<EditCustomerPage> {
  final _formKey = GlobalKey<FormState>(); // Form key for validation
  final nameController = TextEditingController();
  final phoneController = TextEditingController();
  final emailController = TextEditingController();
  final contactAddressController = TextEditingController(); // Renamed for consistency

  final street2Controller = TextEditingController();
  final cityController = TextEditingController();
  final zipController = TextEditingController();
  final vatController = TextEditingController();
  bool isLoading = false;
  String _selectedType = 'person'; 

  @override
  void initState() {
    super.initState();
    nameController.text = widget.customer.name;
    phoneController.text = widget.customer.phone ?? '';
    emailController.text = widget.customer.email ?? '';
    contactAddressController.text = widget.customer.contactAddress ?? '';
    _selectedType = widget.customer.companyType ?? 'person'; // Initialize selected type


    debugPrint('Editing customer with ID: ${widget.customer.id}');
  }

  @override
  void dispose() {
    // Dispose all controllers to prevent memory leaks
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

  // Re-use the helper from the AddCustomerDialog for consistency
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

  // Helper function for building the company-specific fields (adapted for Edit dialog)
  List<Widget> _buildCompanyFields({bool isMobile = false, bool? left}) {
    List<Widget> fields = [];
    if (isMobile) {
      fields = [
        _buildTextField(contactAddressController, 'Contact Address', Icons.location_on, hintText: 'Building, Street, Area'),
        const SizedBox(height: 16),
        _buildTextField(street2Controller, 'Suite/Unit (optional)', Icons.meeting_room, hintText: 'Apartment, Suite, Unit, Building'),
        const SizedBox(height: 16),
        _buildTextField(cityController, 'City', Icons.location_city, hintText: 'e.g., Chennai'),
        const SizedBox(height: 16),
        _buildTextField(zipController, 'ZIP', Icons.local_post_office,
            keyboardType: TextInputType.number,
            maxLength: 6,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            validator: (v) => (v != null && v.trim().isNotEmpty && v.trim().length != 6) ? 'ZIP must be 6 digits' : null),
        const SizedBox(height: 16),
        _buildTextField(vatController, 'VAT / GSTIN (optional)', Icons.confirmation_number, hintText: 'Enter VAT/GSTIN number'),
      ];
    } else {
      // Web/Wide layout (two columns)
      if (left == true) {
        fields = [
          _buildTextField(contactAddressController, 'Contact Address', Icons.location_on, hintText: 'Building, Street, Area'),
          const SizedBox(height: 16),
          _buildTextField(cityController, 'City', Icons.location_city, hintText: 'e.g., Chennai'),
          const SizedBox(height: 16),
        ];
      } else { // right == true
        fields = [
          _buildTextField(street2Controller, 'Suite/Unit (optional)', Icons.meeting_room, hintText: 'Apartment, Suite, Unit, Building'),
          const SizedBox(height: 16),
          _buildTextField(zipController, 'ZIP', Icons.local_post_office,
              keyboardType: TextInputType.number,
              maxLength: 6,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              validator: (v) => (v != null && v.trim().isNotEmpty && v.trim().length != 6) ? 'ZIP must be 6 digits' : null),
          const SizedBox(height: 16),
        ];
      }
    }
    return fields;
  }

  Future<bool> _updateCustomer(int id, Map<String, dynamic> updatedData) async {
    final box = await Hive.openBox('login');
    final raw = box.get('session_id') as String?;
    final session = raw!.contains('session_id=') ? raw : 'session_id=$raw';

    final uri = Uri.parse('${baseurl}/mobile/update_customer/$id');
    final headers = {
      HttpHeaders.contentTypeHeader: 'application/x-www-form-urlencoded',
      HttpHeaders.cookieHeader: session,
    };

    final body = updatedData.map((key, value) => MapEntry(key, value?.toString() ?? ''));

    try {
      final response = await http.put(uri, headers: headers, body: body);
      debugPrint('Response status: ${response.statusCode}');
      debugPrint('Response body: ${response.body}');

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Customer updated', style: TextStyle(fontFamily: 'Arial')), backgroundColor: Colors.green),
        );
        return true;
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update: ${response.body}', style: TextStyle(fontFamily: 'Arial')), backgroundColor: Colors.red),
        );
        return false;
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e', style: TextStyle(fontFamily: 'Arial')), backgroundColor: Colors.red),
      );
      return false;
    }
   finally {
  setState(() {
    isLoading = false;
  });
   }}


void _onSavePressed() async {
  if (!_formKey.currentState!.validate()) return;

  final name = nameController.text.trim();

  // Step 1: Show confirmation dialog
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text('Confirm Update', style: TextStyle(fontFamily: 'Arial', fontWeight: FontWeight.bold)),
      content: Text(
        'Are you sure you want to update "$name"?',
        style: const TextStyle(fontFamily: 'Arial', fontSize: 15),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancel', style: TextStyle(fontFamily: 'Arial')),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
            foregroundColor: Colors.white,
          ),
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Yes, Update', style: TextStyle(fontFamily: 'Arial')),
        ),
      ],
    ),
  );

  if (confirmed != true) return; // Exit if user cancels

  // Step 2: Prepare data
  final updated = {
    'name': name,
    'phone': phoneController.text.trim(),
    'email': emailController.text.trim().isNotEmpty ? emailController.text.trim() : null,
    'company_type': _selectedType,
    if (_selectedType == 'company') 'contact_address': contactAddressController.text.trim().isNotEmpty ? contactAddressController.text.trim() : null,
    if (_selectedType == 'company') 'street2': street2Controller.text.trim().isNotEmpty ? street2Controller.text.trim() : null,
    if (_selectedType == 'company') 'city': cityController.text.trim().isNotEmpty ? cityController.text.trim() : null,
    if (_selectedType == 'company') 'zip': zipController.text.trim().isNotEmpty ? zipController.text.trim() : null,
    if (_selectedType == 'company') 'vat': vatController.text.trim().isNotEmpty ? vatController.text.trim() : null,
  };

  debugPrint('Updating customer with: $updated');

  // Step 3: Update customer
  final success = await _updateCustomer(widget.customer.id, updated);

  if (success) {
    // Show success dialog
    showDialog(
      context: context,
      barrierDismissible: false, // User must tap OK to close
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 8.0, // Add some elevation for a subtle shadow effect
        contentPadding: const EdgeInsets.fromLTRB(24.0, 20.0, 24.0, 0.0), // Adjust content padding
        content: Column(
          mainAxisSize: MainAxisSize.min, // Make the column take minimum space
          children: [
            // Icon and Title on the same line using a Row
            Row(
              mainAxisAlignment: MainAxisAlignment.center, // Center the icon and title together
              mainAxisSize: MainAxisSize.min, // Keep the row size minimal
              children: [
                const Icon(
                  Icons.thumb_up, // The thumbs up icon
                  color: Colors.green, // Green color for success
                  size: 36, // Adjust size to fit well beside text
                ),
                const SizedBox(width: 10), // Space between icon and text
                const Text(
                  'Success!',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Arial',
                    fontWeight: FontWeight.bold,
                    fontSize: 22, // Keep font size consistent with previous title
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16), // Space between the icon/title row and the message

            // Content message
            Text(
              'Customer "$name" updated successfully!',
              textAlign: TextAlign.center, // Center align message
              style: const TextStyle(
                fontFamily: 'Arial',
                fontSize: 16, 
                color: Color.fromARGB(255, 38, 117, 41),
                fontWeight: FontWeight.w500, 
              ),
            ),
          ],
        ),
        actionsPadding: const EdgeInsets.fromLTRB(20.0, 30.0, 20.0, 20.0), 
        actions: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center, 
            children: [
              ElevatedButton(
              onPressed: () {
  Navigator.of(ctx).pop(); // Close the dialog first
  Future.delayed(const Duration(milliseconds: 300), () {
   Navigator.of(context).pop(
  Customer(
    id: widget.customer.id,
    name: name,
    email: emailController.text.trim().isEmpty ? null : emailController.text.trim(),
    phone: phoneController.text.trim().isEmpty ? null : phoneController.text.trim(),
    contactAddress: contactAddressController.text.trim(),
    companyType: _selectedType,
  )
);

  });
},

                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green, 
                  foregroundColor: Colors.white, 
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12), 
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8), 
                  ),
                  elevation: 6, 
                ),
                child: const Text(
                  'OK',
                  style: TextStyle(
                    fontFamily: 'Arial',
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  } else {
    // Show failure dialog
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Update Failed', style: TextStyle(fontFamily: 'Arial', fontWeight: FontWeight.bold)),
        content: const Text('Failed to update customer. Please try again.', style: TextStyle(fontFamily: 'Arial')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK', style: TextStyle(fontFamily: 'Arial')),
          ),
        ],
      ),
    );
  }
}

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;

    return AlertDialog(
      insetPadding: const EdgeInsets.all(10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 10,
      title: const Text(
        'Update Customer',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: Color.fromARGB(255, 2, 47, 88),
          fontFamily: 'Arial',
        ),
      ),
      content: Container(
        width: isMobile ? double.infinity : 650, // Consistent width
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 0), // Space below title

                // Customer Type - Display only (not usually editable for existing customers)
                // If it is editable, you'd need a StatefulBuilder and setState
                // For now, it's just a display, so no state change needed.
                Text(
                  'Customer Type: ${_selectedType == 'person' ? 'Person' : 'Company'}',
                  style: const TextStyle(
                    fontFamily: 'Arial',
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                  textAlign: isMobile ? TextAlign.left : TextAlign.center,
                ),
                const SizedBox(height: 10),

                // Common fields (using helper)
                _buildTextField(nameController, 'Full Name', Icons.person, hintText: 'Enter customer\'s full name', required: true),
                const SizedBox(height: 12),
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
                const SizedBox(height: 12),
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
                const SizedBox(height: 12),

                if (_selectedType == 'company') ...[
                 // Extra space for company section
                  isMobile
                      ? Column(
                          children: _buildCompanyFields(isMobile: true),
                        )
                      : Column( // Column to stack the Rows for wide layout
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(child: Column(children: _buildCompanyFields(left: true))),
                                const SizedBox(width: 16),
                                Expanded(child: Column(children: _buildCompanyFields(left: false))),
                              ],
                            ),
                            const SizedBox(height: 0), // Space before VAT
                            _buildTextField(vatController, 'VAT / GSTIN (optional)', Icons.confirmation_number, hintText: 'Enter VAT/GSTIN number'),
                          ],
                        ),
                ],
              ],
            ),
          ),
        ),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(28, 0, 28, 28), // Padding around action buttons
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
          icon: const Icon(Icons.save),
          label: const Text('Save', style: TextStyle(fontFamily: 'Arial', fontWeight: FontWeight.bold)),
          onPressed: _onSavePressed,
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