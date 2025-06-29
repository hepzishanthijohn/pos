// lib/cart_page.dart
import 'dart:convert';


import 'package:flutter/material.dart';
import 'package:rcspos/screens/customerpage.dart';
import 'package:rcspos/screens/paymentpage.dart';


Widget buildCartImage(dynamic imageData) {
  if (imageData is String && imageData != 'false') {
    try {
      final decodedBytes = base64Decode(imageData);
      return Image.memory(
        decodedBytes,
        width: 60,
        height: 60,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) =>
            const Icon(Icons.broken_image, size: 60, color: Colors.grey),
      );
    } catch (_) {
      return const Icon(Icons.broken_image, size: 60, color: Colors.grey);
    }
  } else {
    return const Icon(Icons.image_not_supported, size: 60, color: Colors.grey);
  }
}
class CartPage extends StatefulWidget {
  final List<Map<String, dynamic>> cartItems;

  const CartPage({Key? key, required this.cartItems}) : super(key: key);

  @override
  _CartPageState createState() => _CartPageState();
}

class _CartPageState extends State<CartPage> {
  Customer? selectedCustomer;

  Widget _buildKeypadButton(String text,
      {IconData? icon,
      Color backgroundColor = Colors.white,
      Color textColor = Colors.black87,
      double fontSize = 24,
      double iconSize = 24,
      VoidCallback? onPressed,
      double aspectRatio = 1.5}) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.all(4.0),
        child: AspectRatio(
          aspectRatio: aspectRatio,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: backgroundColor,
              foregroundColor: textColor,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
              padding: EdgeInsets.zero,
            ),
            onPressed: onPressed ?? () {},
            child: icon != null
                ? Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(icon, size: iconSize),
                      Text(text,
                          style: TextStyle(fontSize: 12, color: textColor)),
                    ],
                  )
                : FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      text,
                      style: TextStyle(
                          fontSize: fontSize,
                          fontWeight: FontWeight.bold,
                          color: textColor),
                      textAlign: TextAlign.center,
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    double total = widget.cartItems.fold(
        0.0,
        (sum, item) =>
            sum + ((item['list_price'] ?? 0.0) * (item['quantity'] ?? 1)));

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color.fromARGB(255, 1, 139, 82),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context, widget.cartItems),

        ),
        title:
            const Text('Cart Items', style: TextStyle(color: Colors.white)),
        actions: [
          
          TextButton(
            onPressed: () {
               setState(() => widget.cartItems.clear());
            },
            child: const Text('Clear', style: TextStyle(color: Colors.white)),
          ),
          // IconButton(
          //   icon: const Icon(Icons.delete_forever, color: Colors.white),
          //   onPressed: () {
          //     setState(() => widget.cartItems.clear());
          //   },
          // ),
          const SizedBox(width: 10),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: widget.cartItems.isEmpty
                ? const Center(child: Text('Your cart is empty.'))
                : ListView.builder(
                    itemCount: widget.cartItems.length,
                    itemBuilder: (context, index) {
                      final item = widget.cartItems[index];
                      return Card(
                         color: Colors.white,
  margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
  elevation: 2,
  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
  child: Padding(
    padding: const EdgeInsets.all(12.0),
    child: Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Product Image
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: buildCartImage(item['image_1920']),
            ),
            const SizedBox(width: 10),

            // Name, Price & Remove
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          item['display_name'] ?? 'Unnamed',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.redAccent),
                        splashRadius: 20,
                        onPressed: () {
                          setState(() {
                            widget.cartItems.removeAt(index);
                          });
                        },
                      ),
                    ],
                  ),
                  Text(
                    'Price: ₹${(item['list_price'] ?? 0.0).toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),

        const SizedBox(height: 12),
        const Divider(),

        // Quantity and Total Row
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Quantity Controls
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade400),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline, size: 20),
                    onPressed: () {
                      setState(() {
                        if (item['quantity'] > 1) item['quantity'] -= 1;
                      });
                    },
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Text(
                      '${item['quantity'] ?? 1}',
                      style: const TextStyle(fontSize: 16),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline, size: 20),
                    onPressed: () {
                      setState(() {
                        item['quantity'] += 1;
                      });
                    },
                  ),
                ],
              ),
            ),

            // Total Price
            Text(
              'Total: ₹${((item['list_price'] ?? 0.0) * (item['quantity'] ?? 1)).toStringAsFixed(2)}',
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ],
    ),
  ),
);

                    },
                  ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (selectedCustomer != null)
                  Text('Customer: ${selectedCustomer!.name}',
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w500)),
                const SizedBox(height: 4),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text('Total: ₹${total.toStringAsFixed(2)}',
                      style: const TextStyle(
                          fontSize: 20, fontWeight: FontWeight.w500)),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(8.0),
            color: Colors.grey[200],
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    flex: 1,
                    child: Column(
                      children: [
                        Expanded(
                          child: _buildKeypadButton('Customer',
                              icon: Icons.person,
                              aspectRatio: 1.0,
                              onPressed: () async {
                            final result = await Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (context) => SelectCustomerPage()),
                            );
                            if (result != null && result is Customer) {
                              setState(() => selectedCustomer = result);
                            }
                          }),
                        ),
                        Expanded(
                          child: _buildKeypadButton('Payment',
                              icon: Icons.payment,
                              aspectRatio: 1.0,
                              onPressed: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    PaymentPage(totalAmount: total),
                              ),
                            );
                          }),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8.0),
                  Expanded(
                    flex: 3,
                    child: Column(
                      children: [
                        Row(
                          children: [
                            _buildKeypadButton('1'),
                            _buildKeypadButton('2'),
                            _buildKeypadButton('3'),
                            _buildKeypadButton('Qty',
                                backgroundColor: Colors.green,
                                textColor: Colors.white,
                                fontSize: 14),
                          ],
                        ),
                        Row(
                          children: [
                            _buildKeypadButton('4'),
                            _buildKeypadButton('5'),
                            _buildKeypadButton('6'),
                            _buildKeypadButton('Disc', fontSize: 14),
                          ],
                        ),
                        Row(
                          children: [
                            _buildKeypadButton('7'),
                            _buildKeypadButton('8'),
                            _buildKeypadButton('9'),
                            _buildKeypadButton('Price', fontSize: 14),
                          ],
                        ),
                        Row(
                          children: [
                            _buildKeypadButton(''),
                            _buildKeypadButton('0'),
                            _buildKeypadButton('Del',
                                backgroundColor: Colors.green,
                                textColor: Colors.white,
                                fontSize: 14),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          )
        ],
      ),
    );
  }
}
