import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:dotted_line/dotted_line.dart';
import 'package:rcspos/screens/home.dart'; // Ensure this import is correct for your HomePage

// You might want to define these constants globally or in a config file
const double A4_WIDTH_IN_INCHES = 8.27;
const double A4_HEIGHT_IN_INCHES = 11.69;
const double DPI = 72.0; // Common DPI for screen display/PDF generation

class InvoicePage extends StatelessWidget {
  final Map<String, dynamic> posConfig; // posConfig is available here
  final List<Map<String, dynamic>> cart;
  final String customerName;
  final String customerPhone;

  const InvoicePage({
    super.key,
    required this.posConfig, // It's passed into InvoicePage
    required this.cart,
    required this.customerName,
    required this.customerPhone,
  });

  // Helper to build rows for the item table (already exists)
  TableRow _buildTableRow(List<String> cells, {bool isHeader = false}) {
    return TableRow(
      decoration: BoxDecoration(
        color: isHeader ? Colors.grey[300] : null,
      ),
      children: cells.map((cell) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4),
          child: Text(
            cell,
            style: TextStyle(
              fontWeight: isHeader ? FontWeight.bold : FontWeight.normal,
              fontFamily: 'Courier',
              fontSize: 12, // Adjusted font size for table cells
            ),
            textAlign: TextAlign.center, // Center text in cells for better alignment
          ),
        );
      }).toList(),
    );
  }

  // New helper to build rows for the tax table
  TableRow _buildTaxTableRow(List<String> cells, {bool isHeader = false, bool isTotalRow = false}) {
    return TableRow(
      decoration: BoxDecoration(
        color: isTotalRow ? Colors.grey[200] : null, // Slightly different background for total row
      ),
      children: cells.map((cell) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 4),
          child: Text(
            cell,
            style: TextStyle(
              fontWeight: isHeader || isTotalRow ? FontWeight.bold : FontWeight.normal,
              fontFamily: 'Courier',
              fontSize: isTotalRow ? 13 : 12, // Larger font for total row
            ),
            textAlign: TextAlign.right, // Align tax numbers to the right
          ),
        );
      }).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final invoiceNumber = 'INV${DateTime.now().millisecondsSinceEpoch.toString().substring(5)}';
    final invoiceDate = DateFormat('yyyy-MM-dd – kk:mm').format(DateTime.now());
    final subtotal = cart.fold(0.0, (sum, item) => sum + (item['list_price'] * item['quantity']));
    // Assuming 5% SGST and 5% CGST for a total of 10% GST
    final sgstRate = 0.05;
    final cgstRate = 0.05;

    // For a real scenario, you'd calculate base for each tax slab
    // For this example, we'll assume the whole subtotal is subject to this tax.
    final taxBase = subtotal; // Base amount on which tax is calculated
    final sgstAmount = taxBase * sgstRate;
    final cgstAmount = taxBase * cgstRate;
    final totalTaxAmount = sgstAmount + cgstAmount;

    final total = subtotal + totalTaxAmount; // Ensure total includes the calculated tax
    final totalItems = cart.fold<int>(0, (sum, item) => sum + item['quantity'] as int);

    // Calculate pixel dimensions for A4 at 72 DPI
    final double pagePixelWidth = A4_WIDTH_IN_INCHES * DPI;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Invoice',
          style: TextStyle(
            fontFamily: 'Arial',
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: const Color.fromARGB(255, 1, 139, 82),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_shopping_cart), // "New Order" icon
            tooltip: 'New Order', // Tooltip for accessibility
            onPressed: () {
              // --- CORRECTED NAVIGATION ---
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => HomePage(posConfig: posConfig), // <--- FIX: Pass posConfig here!
                ),
              );
              // REMOVED THE REDUNDANT: Navigator.of(context).pushReplacementNamed('/homepage');
            },
          ),
          IconButton(
            icon: const Icon(Icons.print),
            tooltip: 'Print',
            onPressed: () {
              // Handle print action
            },
          ),
        ],
      ),
      body: Center(
        child: Column(
          children: [
            const SizedBox(height: 40),
            Expanded(
              child: SingleChildScrollView(
                child: SizedBox(
                  width: pagePixelWidth,
                  child: Container(
                    padding: const EdgeInsets.all(34),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: Colors.grey.shade400, width: 0.5),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.5),
                          spreadRadius: 1,
                          blurRadius: 7,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 🏪 Shop Info - Centered
                        Center(
                          child: Column(
                            children: [
                              Text(
                                posConfig['name'] ?? 'Shop Name',
                                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                                textAlign: TextAlign.center,
                              ),
                              Text(
                                posConfig['shop_addrs'] ?? 'Address',
                                textAlign: TextAlign.center,
                                style: const TextStyle(fontSize: 12),
                              ),
                              Text(
                                posConfig['shop_phone_no']?.toString() ?? '',
                                textAlign: TextAlign.center,
                                style: const TextStyle(fontSize: 12),
                              ),
                              // Using DottedLine for the separator
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 8.0),
                                child: DottedLine(
                                  direction: Axis.horizontal,
                                  lineLength: double.infinity,
                                  lineThickness: 0.5,
                                  dashLength: 5.0,
                                  dashGapLength: 3.0,
                                  dashColor: Colors.black54,
                                ),
                              ),
                              Text(
                                'Served by ${posConfig['shop_owner_id']?['name'] ?? 'Admin'}',
                                textAlign: TextAlign.center,
                                style: const TextStyle(fontSize: 12),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 20), // Reduced height slightly

                        // Invoice & Date
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Bill No: $invoiceNumber', style: const TextStyle(fontSize: 12)),
                            Text(invoiceDate, style: const TextStyle(fontSize: 12)),
                          ],
                        ),

                        const SizedBox(height: 10), // Spacing below invoice info

                        DottedLine( // Another dotted line for separation
                          direction: Axis.horizontal,
                          lineLength: double.infinity,
                          lineThickness: 0.5,
                          dashLength: 5.0,
                          dashGapLength: 3.0,
                          dashColor: Colors.black54,
                        ),

                        const SizedBox(height: 20), // Spacing before table

                        // 🛒 Items Table
                        Table(
                          border: TableBorder.all(color: Colors.grey.shade300),
                          columnWidths: const {
                            0: FlexColumnWidth(4),
                            1: FlexColumnWidth(2),
                            2: FlexColumnWidth(2),
                            3: FlexColumnWidth(2),
                          },
                          children: [
                            _buildTableRow(['Item', 'Qty', 'Price', 'Total'], isHeader: true),
                            ...cart.map((item) {
                              final name = item['display_name'] ?? 'Item';
                              final qty = item['quantity'].toString();
                              final price = item['list_price'].toStringAsFixed(2);
                              final totalItem = (item['list_price'] * item['quantity']).toStringAsFixed(2);
                              return _buildTableRow([name, qty, '₹$price', '₹$totalItem']);
                            }).toList(),
                          ],
                        ),

                        const SizedBox(height: 20),

                        // Net Total Row (Left Label, Right Value)
                        Align(
                          alignment: Alignment.centerRight,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    'Net Total:',
                                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                                  ),
                                  Text(
                                    '₹${subtotal.toStringAsFixed(2)}', // This should be subtotal before tax
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                  ),
                                ],
                              ),
                              const DottedLine(
                                direction: Axis.horizontal,
                                lineLength: double.infinity,
                                lineThickness: 0.5,
                                dashLength: 5.0,
                                dashGapLength: 4.0,
                                dashColor: Colors.grey,
                              ),
                            ],
                          ),
                        ),

                        Align(
                          alignment: Alignment.centerRight,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end, // Aligns content of this column to the right
                            children: [
                              Text('Total Items: $totalItems',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                              Text('Subtotal: ₹${subtotal.toStringAsFixed(2)}', style: const TextStyle(fontSize: 12)),
                              // Removed previous tax line as it will be replaced by the table
                            ],
                          ),
                        ),
                        Center(
                          child: Column(
                            children: [
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 8.0),
                                child: DottedLine(
                                  direction: Axis.horizontal,
                                  lineLength: double.infinity,
                                  lineThickness: 0.5,
                                  dashLength: 5.0,
                                  dashGapLength: 3.0,
                                  dashColor: Colors.black54,
                                ),
                              ),
                              Text(
                                'Inclusive of GST TAX ',
                                textAlign: TextAlign.center,
                                style: const TextStyle(fontSize: 12),
                              ),
                              Text(
                                'GST Summary - Details ',
                                textAlign: TextAlign.center,
                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: 10), // Space before tax table

                              // New Tax Summary Table
                              Table(
                                border: TableBorder.all(color: Colors.grey.shade300),
                                columnWidths: const {
                                  0: FlexColumnWidth(3), // Tax Name
                                  1: FlexColumnWidth(2), // Amount
                                  2: FlexColumnWidth(2), // Base
                                  3: FlexColumnWidth(2), // Total
                                },
                                children: [
                                  _buildTaxTableRow(['Tax', 'Amount', 'Base', 'Total'], isHeader: true),
                                  _buildTaxTableRow([
                                    'SGST${(sgstRate * 100).toStringAsFixed(1)}%',
                                    sgstAmount.toStringAsFixed(2),
                                    taxBase.toStringAsFixed(2),
                                    (taxBase + sgstAmount).toStringAsFixed(2),
                                  ]),
                                  _buildTaxTableRow([
                                    'CGST${(cgstRate * 100).toStringAsFixed(1)}%',
                                    cgstAmount.toStringAsFixed(2),
                                    taxBase.toStringAsFixed(2),
                                    (taxBase + cgstAmount).toStringAsFixed(2),
                                  ]),
                                  _buildTaxTableRow([
                                    '', // Empty for the first column
                                    totalTaxAmount.toStringAsFixed(2), // Total tax amount
                                    taxBase.toStringAsFixed(2), // Re-display base if needed
                                    total.toStringAsFixed(2), // Final total after all taxes
                                  ], isTotalRow: true),
                                ],
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 30), // Increased space for professional look

                        // 🖋️ Signature Section (Aligned Center)
                        Center(
                          child: Column(
                            children: [
                              const Text(
                                'powered by RCS',
                                style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
                              ),
                              const Text(
                                '____________________________', // Simple underline for signature
                                style: TextStyle(fontSize: 12, height: 1.5),
                              ),
                              Align(
                                alignment: Alignment.center,
                                child: Text(
                                  'Note: Thank you for shopping with us!',
                                  style: TextStyle(color: Colors.grey[700], fontSize: 12, fontStyle: FontStyle.italic),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}