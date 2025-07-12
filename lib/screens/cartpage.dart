import 'package:flutter/material.dart';
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

      // ✅ Updated safe stock parsing
final int stock = parseStock(item['qty_available']);



      if (parsed != null) {
        if (parsed > stock) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Quantity exceeds stock (${stock.toString()})!'),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 2),
            ),
          );

          // Reset to max stock
          inputBuffer = stock.toString();
          inputController.text = inputBuffer;
          inputController.selection = TextSelection.fromPosition(
            TextPosition(offset: inputBuffer.length),
          );
          item['quantity'] = stock;

          return;
        }

        item['quantity'] = parsed;
      } else if (inputBuffer.isEmpty) {
        item['quantity'] = 1;
      }
    } else if (editingField == 'price') {
      final double? parsed = double.tryParse(inputBuffer);
      item['list_price'] = parsed ?? 0.0;
    }
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
}

Future<bool> _onWillPop() async {
  Navigator.pop(context, {
    'cart': widget.cart,
    'customerName': _customerName,
  });
  return false;
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
            color: Colors.grey.shade300,
            child: Row(
              children: const [
                Expanded(flex: 4, child: Text('ITEM NAME', style: TextStyle(fontWeight: FontWeight.bold))),
                Expanded(flex: 2, child: Text('QTY', style: TextStyle(fontWeight: FontWeight.bold))),
                Expanded(flex: 2, child: Text('PRICE', style: TextStyle(fontWeight: FontWeight.bold))),
                Expanded(flex: 2, child: Text('TOTAL', style: TextStyle(fontWeight: FontWeight.bold))),
              ],
            ),
          ),

          // Table-like rows (UNCHANGED)
          Expanded(
            child: ListView.builder(
              itemCount: widget.cart.length,
              itemBuilder: (context, index) {
               final item = widget.cart[index];

                final isSelected = index == selectedIndex;
                return GestureDetector(
                 onTap: () => setState(() {
  selectedIndex = index;
  inputBuffer = '';
  editingField = ''; // Clear current editing mode
}),

                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    color: isSelected ? Colors.tealAccent.withOpacity(0.2) : null,
                    child: Row(
                      children: [
                        Expanded(flex: 4, child: Text(item['display_name'] ?? '',
                        style: const TextStyle(fontSize: 17,fontWeight: FontWeight.w600),)),
                        Expanded(
                          flex: 2,
                          child: Text(
                            '${item['quantity']}',
                            maxLines: 1, // Prevent overflow for large quantities
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 14,fontWeight: FontWeight.w500),
                          ),
                        ),
                        Expanded(flex: 2, child: Text('₹${item['list_price'].toStringAsFixed(2)}',
                        style: const TextStyle(fontSize: 14,fontWeight: FontWeight.w500))),
                        Expanded(flex: 2, child: Text('₹${(item['quantity'] * item['list_price']).toStringAsFixed(2)}',
                        style: const TextStyle(fontSize: 14,fontWeight: FontWeight.w500))),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          // Total (UNCHANGED)
 Container(
  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
  color: Colors.grey[200],
  child: Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      // Customer info (name + phone)
      Row(
        children: [
          const Icon(Icons.person, size: 18, color: Colors.black54),
          const SizedBox(width: 6),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _customerName != null ? 'Customer: $_customerName' : 'No Customer Selected',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
              ),
              if (_customerPhone != null && _customerPhone!.isNotEmpty)
                Text(
                  'Phone: $_customerPhone',
                  style: const TextStyle(fontSize: 13, color: Colors.black54),
                ),
            ],
          ),
        ],
      ),

      // Total amount
      Row(
        children: [
          const Icon(Icons.receipt_long, size: 18, color: Colors.black54),
          const SizedBox(width: 6),
          Text(
            'Total: ₹${total.toStringAsFixed(2)}',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    ],
  ),
),

          // Keypad Area
Flexible(
  child: Container(
    height: 270,
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
  height: 40,
  padding: const EdgeInsets.symmetric(horizontal: 10),
  decoration: BoxDecoration(
    color: Colors.white,
    border: Border.all(color: Colors.grey.shade400),
  ),
  child: TextField(
    controller: inputController,
    focusNode: inputFocusNode,
    readOnly: false, // ✅ Enable full editing
    keyboardType: TextInputType.number,
    decoration: const InputDecoration(
      border: InputBorder.none,
      contentPadding: EdgeInsets.only(bottom: 12),
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
  child: Row(
    children: [
      // Left column (Customer, Payment)
      Expanded(
        flex: 1,
        child: Column(
          children: [
            Expanded(child: buildKey('Customer', onTap: onCustomerPressed, icon: Icons.person)),
            const SizedBox(height: 1),
            Expanded(child: buildKey('Payment', onTap: onPaymentPressed, icon: Icons.play_arrow)),
          ],
        ),
      ),
      const SizedBox(width: 1),

      // Right 3x4 grid
      Expanded(
        flex: 3,
        child: Column(
          children: [
            Expanded(
              child: Row(
                children: [
                  Expanded(child: buildKey('1', onTap: () => onNumberPressed('1'))),
                  const SizedBox(width: 1),
                  Expanded(child: buildKey('2', onTap: () => onNumberPressed('2'))),
                  const SizedBox(width: 1),
                  Expanded(child: buildKey('3', onTap: () => onNumberPressed('3'))),
                  const SizedBox(width: 1),
                  Expanded(child: buildKey('Qty', onTap: onQtyPressed, isActionKey: true)),
                ],
              ),
            ),
            const SizedBox(height: 1),
            Expanded(
              child: Row(
                children: [
                  Expanded(child: buildKey('4', onTap: () => onNumberPressed('4'))),
                  const SizedBox(width: 1),
                  Expanded(child: buildKey('5', onTap: () => onNumberPressed('5'))),
                  const SizedBox(width: 1),
                  Expanded(child: buildKey('6', onTap: () => onNumberPressed('6'))),
                  const SizedBox(width: 1),
                  Expanded(child: buildKey('Disc', onTap: onDiscPressed, isActionKey: true)),
                ],
              ),
            ),
            const SizedBox(height: 1),
            Expanded(
              child: Row(
                children: [
                  Expanded(child: buildKey('7', onTap: () => onNumberPressed('7'))),
                  const SizedBox(width: 1),
                  Expanded(child: buildKey('8', onTap: () => onNumberPressed('8'))),
                  const SizedBox(width: 1),
                  Expanded(child: buildKey('9', onTap: () => onNumberPressed('9'))),
                  const SizedBox(width: 1),
                  Expanded(child: buildKey('Price', onTap: onPricePressed, isActionKey: true)),
                ],
              ),
            ),
            const SizedBox(height: 1),
            Expanded(
              child: Row(
                children: [
                  Expanded(child: buildKey('')), // Empty
                  const SizedBox(width: 1),
                  Expanded(child: buildKey('0', onTap: () => onNumberPressed('0'))),
                  const SizedBox(width: 1),
                  Expanded(child: buildKey('')), // Empty
                  const SizedBox(width: 1),
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
),
     ],
      ),
    );
  }

  // Finalized buildKey for clear colors and borders
Widget buildKey(
  String label, {
  VoidCallback? onTap,
  IconData? icon,
  bool isActionKey = false,
  bool isDeleteKey = false,
}) {
  final bool isBlank = label.isEmpty && icon == null;

  Color bgColor = Colors.grey.shade300;
  Color fgColor = Colors.black;
  if (isActionKey) {
    bgColor = const Color(0xFF009688); // Teal
    fgColor = Colors.white;
  } else if (isDeleteKey) {
    fgColor = Colors.black;
  }

  return InkWell(
    onTap: isBlank ? null : onTap,
    child: Container(
      decoration: BoxDecoration(
        color: bgColor,
        border: Border.all(color: Colors.grey.shade600, width: 0.5),
      ),
      child: Center(
        child: icon != null
            ? Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 20, color: fgColor),
                  Text(label, style: TextStyle(fontSize: 14, color: fgColor, fontWeight: FontWeight.w600)),
                ],
              )
            : Text(
                label,
                style: TextStyle(fontSize: 16, color: fgColor, fontWeight: FontWeight.w600),
              ),
      ),
    ),
  );
}

}