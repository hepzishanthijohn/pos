import 'package:flutter/material.dart';
import 'package:rcspos/data/samplecustomers.dart';
import 'package:rcspos/screens/customerpage.dart';
import 'package:rcspos/screens/paymentpage.dart';

class CartPage extends StatefulWidget {
  final List<Map<String, dynamic>> cart;
  final bool showAppBar;
  final String? customerName;
 
  
  const CartPage({
    super.key, 
    required this.cart,
    this.customerName, 
    this.showAppBar = true});

  @override
  State<CartPage> createState() => _CartPageState();
}

class _CartPageState extends State<CartPage> {
  int? selectedIndex;
  String? _customerPhone;
  String inputBuffer = '';
  String editingField = ''; // 'qty' or 'price'
  bool isFreshEdit = true; // true = start from current value; false = appending
  final TextEditingController inputController = TextEditingController();
final FocusNode inputFocusNode = FocusNode();




int parseStock(dynamic rawStock) {
  if (rawStock == null) return 0;
  if (rawStock is int) return rawStock;
  if (rawStock is double) return rawStock.toInt();
  if (rawStock is String) return int.tryParse(rawStock) ?? 0;
  return 0;
}

void updateCartItem(String value) {
    if (selectedIndex == null || editingField.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select an item and a field (Qty/Price) first.')),
      );
      return;
    }

    final item = widget.cart[selectedIndex!];

    setState(() {
      if (editingField == 'qty') {
        final int? parsedValue = int.tryParse(value);
        if (parsedValue != null && parsedValue >= 0) {
          item['quantity'] = parsedValue;
        } else if (value.isEmpty) {
          item['quantity'] = 1; // Default to 1 if input cleared
        }
      } else if (editingField == 'price') {
        final double? parsedValue = double.tryParse(value);
        if (parsedValue != null && parsedValue >= 0) {
          item['list_price'] = parsedValue;
        } else if (value.isEmpty) {
          item['list_price'] = 0.0; // Default to 0.0 if input cleared
        }
      }
      inputBuffer = ''; // Clear buffer after applying
    });
  }

void onNumberPressed(String number) {
  if (selectedIndex == null) return;

  final item = widget.cart[selectedIndex!];
  final int stock = parseStock(item['qty_available']);

  // Always append
  String newValue = inputController.text + number;
  final int? parsed = int.tryParse(newValue);

  if (editingField == 'qty' && parsed != null && parsed > stock) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Max available stock is $stock'),
        backgroundColor: Colors.red,
        duration: Duration(seconds: 2),
      ),
    );
    return;
  }

  setState(() {
    inputController.text = newValue;
    inputController.selection = TextSelection.fromPosition(
      TextPosition(offset: inputController.text.length),
    );
    inputBuffer = newValue;
    applyValueToItem();
  });
}

void onDelPressed() {
  setState(() {
    if (inputController.text.isNotEmpty) {
      inputController.text =
          inputController.text.substring(0, inputController.text.length - 1);
      inputBuffer = inputController.text;
    } else {
      isFreshEdit = true;
    }
   inputController.selection = TextSelection.fromPosition(
  TextPosition(offset: inputController.text.length),
);
inputBuffer = inputController.text;
applyValueToItem();

  });
}

void applyValueToItem() {
  if (selectedIndex == null || editingField.isEmpty) return;

  final item = widget.cart[selectedIndex!];

  setState(() {
    if (editingField == 'qty') {
      final int? parsed = int.tryParse(inputBuffer);
      final int stock = parseStock(item['qty_available']);

      if (parsed != null) {
        if (parsed > stock) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Quantity exceeds stock ($stock)!'),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 2),
            ),
          );
          inputBuffer = stock.toString();
          inputController.text = inputBuffer;
          inputController.selection = TextSelection.fromPosition(
            TextPosition(offset: inputBuffer.length),
          );
          item['quantity'] = stock;
        } else {
          item['quantity'] = parsed;
        }
      } else if (inputBuffer.isEmpty) {
        item['quantity'] = 1;
      }
    } else if (editingField == 'price') {
      final double? parsed = double.tryParse(inputBuffer);
      item['list_price'] = parsed ?? 0.0;
    }

    // ✅ Always recalculate GST
    double gstRate = 0.0;
    final dynamic taxesId = item['taxes_id'];
    if (taxesId is List && taxesId.isNotEmpty) {
      final dynamic firstTax = taxesId.first;
      if (firstTax is Map && firstTax['amount'] != null) {
        gstRate = (firstTax['amount']).toDouble();
      }
    }
    final price = (item['list_price'] ?? 0.0).toDouble();
    final gst = price * gstRate / 100;
    item['gst'] = gst;
  });
}

void onCustomerPressed() async {
  final result = await Navigator.push(
    context,
    MaterialPageRoute(builder: (context) => CustomerPage()),
  );

  if (result != null && result is Map<String, dynamic>) {
   setState(() {
    _customerName = result['name'] ?? '';
    _customerPhone = result['phone'] ?? '';
  });
  }
}

String? _customerName;

@override
void initState() {
  super.initState();
  _customerName = widget.customerName;
  _customerPhone = ''; 
   _calculateInitialGst(); 
}

Future<bool> _onWillPop() async {
  Navigator.pop(context, {
    'cart': widget.cart,
    'customerName': _customerName,
  });
  return false;
}
void _calculateInitialGst() {
  for (var item in widget.cart) {
    if ((item['gst'] ?? 0.0) == 0.0) {
      double gstRate = 0.0;
      final taxes = item['taxes_id'];
      if (taxes is List && taxes.isNotEmpty) {
        final tax = taxes.first;
        if (tax is Map && tax.containsKey('name')) {
          final match = RegExp(r'(\d+(\.\d+)?)%').firstMatch(tax['name']);
          if (match != null) {
            gstRate = double.tryParse(match.group(1) ?? '0') ?? 0.0;
          }
        }
      }

      final price = (item['list_price'] ?? 0.0).toDouble();
      item['gst'] = price * gstRate / 100;
    }
  }
}


  void onDiscPressed() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Discount key pressed!')),
    );
  }

void onPaymentPressed() {
  double total = widget.cart.fold(
    0.0,
    (sum, item) => sum + item['list_price'] * item['quantity'],
  );

Navigator.push(
  context,
  MaterialPageRoute(
    builder: (context) => PaymentPage(
      totalAmount: total,
      customerName: _customerName,       // From your state
      customerPhone: _customerPhone,     // From your state
    ),
  ),
);

}

void onQtyPressed() {
  if (selectedIndex == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Please select an item first to set quantity.')),
    );
    return;
  }

  final item = widget.cart[selectedIndex!];

  setState(() {
    editingField = 'qty';

    if (inputBuffer.isEmpty) {
      inputBuffer = item['quantity'].toString();
      inputController.text = inputBuffer;
      inputController.selection = TextSelection.fromPosition(
        TextPosition(offset: inputBuffer.length),
      );
    }
    isFreshEdit = false; // 🟢 treat as appending
    FocusScope.of(context).requestFocus(inputFocusNode);
  });
}

void onPricePressed() {
  if (selectedIndex == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Please select an item first to set price.')),
    );
    return;
  }

  setState(() {
    editingField = 'price';
    final item = widget.cart[selectedIndex!];
    inputController.text = item['list_price'].toStringAsFixed(2);
    inputBuffer = item['list_price'].toStringAsFixed(2);
    isFreshEdit = true;
    FocusScope.of(context).requestFocus(inputFocusNode);
  });
}



  @override
  Widget build(BuildContext context) {
    double total = widget.cart.fold(0.0, (sum, item) => sum + item['list_price'] * item['quantity']);
  double totalWithGst = widget.cart.fold(0.0, (sum, item) {
  double price = (item['list_price'] ?? 0).toDouble();
  int quantity = (item['quantity'] ?? 1);
  double gst = (item['gst'] ?? 0.0).toDouble();
  return sum + ((price + gst) * quantity);
});


for (var item in widget.cart) {
  if ((item['gst'] ?? 0.0) == 0.0) {
    double gstRate = 0.0;
    final taxes = item['taxes_id'];
    if (taxes is List && taxes.isNotEmpty) {
      final tax = taxes.first;
      if (tax is Map && tax.containsKey('name')) {
        final match = RegExp(r'(\d+(\.\d+)?)%').firstMatch(tax['name']);
        if (match != null) {
          gstRate = double.tryParse(match.group(1) ?? '0') ?? 0.0;
        }
      }
    }

    final price = (item['list_price'] ?? 0).toDouble();
    item['gst'] = price * gstRate / 100;
  }
}

    String currentInputValue = '';
    if (inputBuffer.isNotEmpty) {
      currentInputValue = inputBuffer;
    } else if (selectedIndex != null) {
      final selectedItem = widget.cart[selectedIndex!];
      if (editingField == 'qty') {
        currentInputValue = selectedItem['quantity'].toString();
      } else if (editingField == 'price') {
        currentInputValue = selectedItem['list_price'].toStringAsFixed(2);
      }
    } else {
      currentInputValue = '0';
    }

    return Scaffold(
     
      body: Column(
        children: [

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: const Color.fromARGB(255, 5, 146, 165),
            child: Row(
              children: const [
                Expanded(flex: 4, child: Text('ITEM NAME', style: TextStyle(fontWeight: FontWeight.bold,color: Colors.white))),
                Expanded(flex: 2, child: Text('QTY', style: TextStyle(fontWeight: FontWeight.bold,color: Colors.white))),
                Expanded(flex: 2, child: Text('PRICE', style: TextStyle(fontWeight: FontWeight.bold,color: Colors.white))),
                Expanded(flex: 2, child: Text('TOTAL', style: TextStyle(fontWeight: FontWeight.bold,color: Colors.white))),
              ],
            ),
          ),

          // Table-like rows (UNCHANGED)
Expanded(
  child: ListView.builder(
    itemCount: widget.cart.length,
    itemBuilder: (context, index) {
      final reversedIndex = widget.cart.length - 1 - index;
      final item = widget.cart[reversedIndex];

      final isSelected = reversedIndex == selectedIndex;

      return GestureDetector(
        onTap: () => setState(() {
          selectedIndex = reversedIndex;
          inputBuffer = '';
          editingField = '';
        }),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          color: isSelected ? Colors.tealAccent.withOpacity(0.2) : null,
          child: Row(
            children: [
              Expanded(
                flex: 4,
                child: Text(
                  item['display_name'] ?? '',
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600, fontFamily: "Arial"),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  '${item['quantity']}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, fontFamily: "Arial"),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  '₹${(item['list_price'] as num? ?? 0.0).toStringAsFixed(2)}',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, fontFamily: "Arial"),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  '₹${((item['quantity'] as num? ?? 0.0) * (item['list_price'] as num? ?? 0.0)).toStringAsFixed(2)}',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, fontFamily: "Arial"),
                ),
              ),
            ],
          ),
        ),
      );
    },
  ),
) ,  // Total (UNCHANGED)

LayoutBuilder(
  builder: (context, constraints) {
    bool isMobile = constraints.maxWidth < 600;

    return isMobile
        ? _buildMobileTotalSection(total, totalWithGst)
        : _buildDesktopTotalSection(total, totalWithGst);
  },
),
 // Keypad Area
Flexible(
  child: Container(
    height:370,
    margin: const EdgeInsets.all(0),
    decoration: BoxDecoration(
      color: Colors.grey.shade200,
      border: Border.all(color: Colors.grey.shade500),
      borderRadius: BorderRadius.circular(6),
    ),
    child: Column(
      children: [
        // Input Display
Container(
  height: 30,
  padding: const EdgeInsets.symmetric(horizontal: 0),
  decoration: BoxDecoration(
    color: Colors.white,
    border: Border.all(color: const Color.fromARGB(177, 70, 69, 69)),
  ),
  child: TextField(
    controller: inputController,
    focusNode: inputFocusNode,
    readOnly: false, // ✅ Enable full editing
    keyboardType: TextInputType.number,
    decoration: const InputDecoration(
      border: InputBorder.none,
      contentPadding: EdgeInsets.only(bottom: 18),
    ),
    textAlign: TextAlign.right,
    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w500),
    onChanged: (value) {
      inputBuffer = value;
      applyValueToItem(); // ✅ live cart update
    },
  ),
),

        // Keypad Grid using Table
     
Expanded(
  child: Column( // Use a Column to properly stack the content
    children: [
    
      Expanded(
        child: Row(
          children: [
            // Left column (Customer, Payment)
Expanded(
  flex: 2,
  child: Column(
    children: [
      // ✅ Customer Button
      Expanded(
      
        child: InkWell(
          onTap: onCustomerPressed,
          borderRadius: BorderRadius.circular(4),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 0),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade300),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  offset: const Offset(1, 1),
                  blurRadius: 2,
                ),
              ],
            ),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                 Center(
  child: Row(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.center,
    children: [
      const Icon(
        Icons.person,
        size: 25,
        color: Color.fromARGB(255, 71, 1, 1),
      ),
      const SizedBox(width: 6),
      Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if ((_customerName?.isNotEmpty ?? false))
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                _customerName!,
                maxLines: 1,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  fontFamily: "Arial",
                  color: Color.fromARGB(255, 71, 1, 1),
                ),
              ),
            )
          else
            const Text(
              'Customer',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                fontFamily: "Arial",
                color: Color.fromARGB(255, 71, 1, 1),
              ),
            ),
          if (_customerPhone != null && _customerPhone!.isNotEmpty)
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                _customerPhone!,
                maxLines: 1,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w500,
                  fontFamily: "Arial",
                  color: Color.fromARGB(228, 0, 0, 0),
                ),
              ),
            ),
        ],
      ),
    ],
  ),
)

                ],
              ),
            ),
          ),
        ),
      ),
      const SizedBox(height: 3),

      // ✅ Payment Button (same size via Expanded)
      Expanded(
        child: buildKey(
          'Payment',
          onTap: onPaymentPressed,
          icon: Icons.play_arrow,
        
        ),
      ),
    ],
  ),
),
    const SizedBox(width: 1), // Increased horizontal spacing for clarity

            // Right 3x4 grid for numbers and actions
            Expanded(
              flex: 3, // Takes 3 parts of the available space (making it wider)
              child: Column(
                children: [
                  // Row 1: 1, 2, 3, Qty
                  Expanded(
                    child: Row(
                      children: [
                        Expanded(child: buildKey('1', onTap: () => onNumberPressed('1'))),
                        const SizedBox(width: 3),
                        Expanded(child: buildKey('2', onTap: () => onNumberPressed('2'))),
                        const SizedBox(width: 3),
                        Expanded(child: buildKey('3', onTap: () => onNumberPressed('3'))),
                        const SizedBox(width: 3),
                        Expanded(child: buildKey('Qty', onTap: onQtyPressed, isActionKey: true)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 2), // Vertical spacing between rows

                  // Row 2: 4, 5, 6, Disc
                  Expanded(
                    child: Row(
                      children: [
                        Expanded(child: buildKey('4', onTap: () => onNumberPressed('4'))),
                        const SizedBox(width: 3),
                        Expanded(child: buildKey('5', onTap: () => onNumberPressed('5'))),
                        const SizedBox(width: 3),
                        Expanded(child: buildKey('6', onTap: () => onNumberPressed('6'))),
                        const SizedBox(width: 3),
                        Expanded(child: buildKey('Disc', onTap: onDiscPressed, isActionKey: true)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 3), // Vertical spacing between rows

                  // Row 3: 7, 8, 9, Price
                  Expanded(
                    child: Row(
                      children: [
                        Expanded(child: buildKey('7', onTap: () => onNumberPressed('7'))),
                        const SizedBox(width: 3),
                        Expanded(child: buildKey('8', onTap: () => onNumberPressed('8'))),
                        const SizedBox(width: 3),
                        Expanded(child: buildKey('9', onTap: () => onNumberPressed('9'))),
                        const SizedBox(width: 3),
                        Expanded(
                          child: buildKey(
                            'Price',
                            // onTap: onPricePressed, // uncomment if you have this function
                            isActionKey: true,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 3), // Vertical spacing between rows

                  // Row 4: Empty, 0, Empty, Del
                  Expanded(
                    child: Row(
                      children: [
                        Expanded(child: buildKey('')), // Empty key
                        const SizedBox(width: 3),
                        Expanded(child: buildKey('0', onTap: () => onNumberPressed('0'))),
                        const SizedBox(width: 3),
                        Expanded(child: buildKey('')), // Empty key
                        const SizedBox(width: 3),
                        Expanded(child: buildKey('Del', onTap: onDelPressed, isDeleteKey: true)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ],
  ),
),   
      ],
    ),
  ),
),
     ],
      ),
    );
  }

  Widget _buildDesktopTotalSection(double total, double totalWithGst) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    color: const Color.fromARGB(255, 1, 67, 121),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('SubTotal:', style: TextStyle(fontSize: 17, color: Colors.white, fontFamily: "Arial")),
                const SizedBox(width: 8),
                Text('₹${total.toStringAsFixed(2)}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white, fontFamily: "Arial")),
              ],
            ),
            Row(
              children: [
                const Text('Tax (GST):', style: TextStyle(fontSize: 14, color: Colors.white, fontFamily: "Arial")),
                const SizedBox(width: 8),
                Text('₹${widget.cart.fold(0.0, (sum, item) => sum + (item['gst'] ?? 0.0)).toStringAsFixed(2)}',
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.white, fontFamily: "Arial")),
              ],
            ),
          ],
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFFEAF7FF),
            border: Border.all(color: const Color.fromARGB(255, 4, 111, 160)),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Total Amount:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color.fromARGB(255, 8, 106, 187), fontFamily: "Arial"),
              ),
              const SizedBox(width: 12),
              Text(
                '₹${totalWithGst.toStringAsFixed(2)}',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 22, color: Color.fromARGB(255, 2, 53, 95), fontFamily: "Arial"),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
Widget _buildMobileTotalSection(double total, double totalWithGst) {
  return Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    color: const Color.fromARGB(255, 1, 67, 121),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('SubTotal:', style: TextStyle(fontSize: 16, color: Colors.white, fontFamily: "Arial")),
            Text('₹${total.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white, fontFamily: "Arial")),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Tax (GST):', style: TextStyle(fontSize: 15, color: Colors.white, fontFamily: "Arial")),
            Text('₹${widget.cart.fold(0.0, (sum, item) => sum + (item['gst'] ?? 0.0)).toStringAsFixed(2)}',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white, fontFamily: "Arial")),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFFEAF7FF),
            border: Border.all(color: const Color.fromARGB(255, 4, 111, 160)),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Total Amount:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: Color.fromARGB(255, 8, 106, 187), fontFamily: "Arial"),
              ),
              Text(
                '₹${totalWithGst.toStringAsFixed(2)}',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: Color.fromARGB(255, 2, 53, 95), fontFamily: "Arial"),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

Widget buildKey(
  String label, {
  VoidCallback? onTap,
  IconData? icon,
  bool isActionKey = false,
  bool isDeleteKey = false,
}) {
  final bool isBlank = label.isEmpty && icon == null;

  Color bgColor = Colors.white;
  Color fgColor = const Color.fromARGB(255, 71, 1, 1); // Deep maroon

  if (isActionKey) {
    bgColor = const Color(0xFF0592A5); // Teal
    fgColor = Colors.white;
  } else if (isDeleteKey) {
    bgColor = Colors.red.shade600;
    fgColor = Colors.white;
  }

final TextStyle commonTextStyle = TextStyle(
  fontSize: 16,
  fontWeight: FontWeight.w600,
  fontFamily: "Arial",
  color: isActionKey || isDeleteKey ? Colors.white : const Color.fromARGB(255, 71, 1, 1),
);


  return Padding(
    padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 0), // ⬅️ Zero vertical spacing
    child: InkWell(
      onTap: isBlank ? null : onTap,
      borderRadius: BorderRadius.circular(4),
      child: Container(
         // ⬅️ Reduced height for even tighter vertical layout
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color.fromARGB(255, 184, 182, 182)),
          boxShadow: [
            if (!isBlank)
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                offset: const Offset(1, 1),
                blurRadius: 2,
              ),
          ],
        ),
        child: Center(
          child: icon != null
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, size: 20, color: fgColor),
                    if (label.isNotEmpty)
                      const SizedBox(height: 1),
                    if (label.isNotEmpty)
                      Text(label, style: commonTextStyle),
                  ],
                )
              : Text(label, style: commonTextStyle),
        ),
      ),
    ),
  );
}

  // Finalized buildKey for clear colors and borders

}