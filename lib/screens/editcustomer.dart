import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;
import 'package:rcspos/localdb/customersqlitehelper.dart';
import 'package:rcspos/screens/customerpage.dart';
import 'package:rcspos/utils/urls.dart';



class EditCustomerPage extends StatefulWidget {
    final Map<String, dynamic> posConfig;
  final Customer customer;
  const EditCustomerPage({
    required this.customer,
    required this.posConfig,
   super.key});

  @override
  State<EditCustomerPage> createState() => _EditCustomerPageState();
}

class _EditCustomerPageState extends State<EditCustomerPage> {
  final _formKey = GlobalKey<FormState>(); // Form key for validation
  final nameController = TextEditingController();
  final phoneController = TextEditingController();
  final emailController = TextEditingController();
  final contactAddressController = TextEditingController();
  final vatController = TextEditingController();

  bool isLoading = false;
  String _selectedType = 'person';

  @override
  void initState() {
    super.initState();
    nameController.text = widget.customer.name;
    phoneController.text = widget.customer.phone ?? '';
    emailController.text = widget.customer.email ??"";
    // IMPORTANT: Ensure widget.customer.contactAddress contains the full, multi-line string
    // This line directly populates the controller with whatever is passed.
    contactAddressController.text = widget.customer.contactAddress;
    // Also initialize VAT if your Customer model supports it and it's being passed

    _selectedType = widget.customer.companyType;

    debugPrint('Editing customer with ID: ${widget.customer.id}');
    debugPrint('Initial Contact Address for display: "${contactAddressController.text}"');
    debugPrint('Initial Contact Address Length: ${contactAddressController.text.length}');
  }

  @override
  void dispose() {
    nameController.dispose();
    phoneController.dispose();
    emailController.dispose();
    contactAddressController.dispose();
    vatController.dispose();
    super.dispose();
  }

  // Helper function for building text fields
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
    int? maxLines, // Added for multi-line support
    int? minLines, // Added for multi-line support
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLength: maxLength,
      inputFormatters: inputFormatters,
      maxLines: maxLines, // Apply maxLines
      minLines: minLines, // Apply minLines
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


  List<Widget> _buildCompanyFields() {
    return [
      _buildTextField(
        contactAddressController,
        'Contact Address',
        Icons.location_on,
        hintText: 'Building, Street, Area',
        minLines: 3, // Allow at least 3 lines to be visible initially
        maxLines: null, // Allow unlimited lines (will scroll if content is long)
        // If you want a fixed height with scrolling, use expands: true in TextFormField and set a fixed height for its parent.
      ),
      const SizedBox(height: 16),
      _buildTextField(vatController, 'VAT / GSTIN (optional)', Icons.confirmation_number,
          hintText: 'Enter VAT/GSTIN number'),
    ];
  }
Future<bool> _updateCustomer(int id, Map<String, dynamic> updatedData) async {
  setState(() {
    isLoading = true; // Show loading indicator
  });

  try {
    // Update local database first and mark as unsynced
    await Customersqlitehelper.instance.updateLocalCustomer(id, updatedData);

    // Sync all unsynced customers (including this one)
    // await Customersqlitehelper.instance.syncAllUnsyncedCustomers;

    // Show success snackbar
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Customer updated locally and syncing...'),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );

    return true;
  } catch (e) {
    // Show error snackbar
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Error updating customer: $e'),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
    return false;
  } finally {
    setState(() {
      isLoading = false;
    });
  }
}


  void _onSavePressed() async {
    if (!_formKey.currentState!.validate()) return;

    final name = nameController.text.trim();

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

    if (confirmed != true) return;

    // Prepare data. Removed .trim() for contactAddress to preserve newlines.
    final updatedData = {
      'name': name,
      'phone': phoneController.text.trim(),
      'email': emailController.text.trim().isNotEmpty ? emailController.text.trim() : null,
      'company_type': _selectedType,
      if (_selectedType == 'company') 'contact_address': contactAddressController.text, // NO TRIM HERE
      if (_selectedType == 'company') 'vat': vatController.text.trim(),
    };

    debugPrint('Attempting to update customer with ID: ${widget.customer.id}');
    debugPrint('Payload: $updatedData');

    final success = await _updateCustomer(widget.customer.id, updatedData);

    if (success) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 8.0,
          contentPadding: const EdgeInsets.fromLTRB(24.0, 20.0, 24.0, 0.0),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.thumb_up, color: Colors.green, size: 36),
                  const SizedBox(width: 10),
                  const Text(
                    'Success!',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Arial',
                      fontWeight: FontWeight.bold,
                      fontSize: 22,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                'Customer "$name" updated successfully!',
                textAlign: TextAlign.center,
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
                    Navigator.of(ctx).pop(); // Close the success dialog
                    Future.delayed(const Duration(milliseconds: 300), () {
                      // Pass back the updated customer data to the previous screen (customerpage.dart)
                      Navigator.of(context).pop(
                        Customer(
                          id: widget.customer.id,
                          name: name,
                          email: emailController.text.trim().isEmpty ? null : emailController.text.trim(),
                          phone: phoneController.text.trim().isEmpty ? null : phoneController.text.trim(),
                          contactAddress: contactAddressController.text, // NO TRIM HERE
                          companyType: _selectedType,
                          posConfig: widget.posConfig,
                        ),
                      );
                    });
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
      content: SizedBox( // Changed from Container to SizedBox for explicit width/height
        width: isMobile ? double.infinity : 650,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 0),

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
                  // Company specific fields
                  // On mobile, they stack vertically
                  isMobile
                      ? Column(
                          children: _buildCompanyFields(),
                        )
                      // On wider screens, they are in a single column (no two-column layout for now)
                      : Column(
                          children: _buildCompanyFields(),
                        ),
                ],
                if (isLoading) const LinearProgressIndicator(), // Show loading indicator
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
          icon: const Icon(Icons.save),
          label: const Text('Save', style: TextStyle(fontFamily: 'Arial', fontWeight: FontWeight.bold)),
          onPressed: isLoading ? null : _onSavePressed, // Disable button while loading
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