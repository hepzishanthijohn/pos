import 'package:flutter/material.dart';

class InvoicePage extends StatelessWidget {
  const InvoicePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FB),
      appBar: AppBar(
        title: const Text('Invoice'),
        backgroundColor: const Color.fromARGB(255, 1, 139, 82),
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Header Section
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Company Logo',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: const [
                    Text('Invoice #INV-2025', style: TextStyle(fontSize: 16)),
                    Text('Date: 20 June 2025'),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 24),

            // From/To Info
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: const [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('From:', style: TextStyle(fontWeight: FontWeight.bold)),
                      Text('ZigmaIndia\nNamakkal\nsupport@zigma.com'),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('To:', style: TextStyle(fontWeight: FontWeight.bold)),
                      Text('Marc Demo\nCustomer City\nmarc@example.com'),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Item Table
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
                _buildTableRow(['Product A', '2', '\$50.00', '\$100.00']),
                _buildTableRow(['Product B', '1', '\$80.00', '\$80.00']),
                _buildTableRow(['Service C', '3', '\$30.00', '\$90.00']),
              ],
            ),
            const SizedBox(height: 24),

            // Total
            Align(
              alignment: Alignment.centerRight,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: const [
                  Text('Subtotal: \$270.00', style: TextStyle(fontSize: 16)),
                  Text('Tax (10%): \$27.00'),
                  Divider(),
                  Text('Total: \$297.00', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            const Spacer(),

            // Action Buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.add_shopping_cart),
                  label: const Text("New Order"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF228CF0),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.picture_as_pdf),
                  label: const Text("Download Invoice"),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  TableRow _buildTableRow(List<String> cells, {bool isHeader = false}) {
    return TableRow(
      decoration: isHeader
          ? const BoxDecoration(color: Color(0xFF228CF0))
          : null,
      children: cells.map((cell) {
        return Padding(
          padding: const EdgeInsets.all(8.0),
          child: Text(
            cell,
            style: TextStyle(
              fontWeight: isHeader ? FontWeight.bold : FontWeight.normal,
              color: isHeader ? Colors.white : Colors.black87,
            ),
          ),
        );
      }).toList(),
    );
  }
}
