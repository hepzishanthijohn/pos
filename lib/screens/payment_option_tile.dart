
import 'package:flutter/material.dart';


class PaymentOptionTile extends StatefulWidget {
  final String title;
  final double totalAmount;
  final Function(double) onAmountChanged;
  final Function(bool) onCheckboxChanged;

  const PaymentOptionTile({
    Key? key,
    required this.title,
    required this.totalAmount,
    required this.onAmountChanged,
    required this.onCheckboxChanged,
  }) : super(key: key);

  @override
  State<PaymentOptionTile> createState() => _PaymentOptionTileState();
}

class _PaymentOptionTileState extends State<PaymentOptionTile> {
  bool isChecked = false;
  bool isExpanded = false;
  final TextEditingController _amountController = TextEditingController();
  double change = 0.0;

  void _toggleCheckbox(bool? value) {
    setState(() {
      isChecked = value ?? false;
      isExpanded = isChecked;
      if (!isChecked) {
        _amountController.clear();
        widget.onAmountChanged(0.0);
      }
    });
    widget.onCheckboxChanged(isChecked);
  }

  void _onAmountChanged(String value) {
    double entered = double.tryParse(value) ?? 0.0;
    setState(() {
      change = entered - widget.totalAmount;
    });
    widget.onAmountChanged(entered);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Checkbox(
              value: isChecked,
              onChanged: _toggleCheckbox,
              activeColor: const Color(0xB3228CF0),
            ),
            Expanded(
              child: Text(widget.title, style: const TextStyle(fontSize: 16)),
            ),
            Text('₹${widget.totalAmount.toStringAsFixed(2)}',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            IconButton(
              icon: Icon(
                isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                color: Colors.teal,
              ),
              onPressed: isChecked ? () => setState(() => isExpanded = !isExpanded) : null,
            ),
          ],
        ),
        if (isExpanded)
          Padding(
            padding: const EdgeInsets.only(left: 32, right: 16, bottom: 8),
            child: Column(
              children: [
                TextField(
                  controller: _amountController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Amount',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: _onAmountChanged,
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const SizedBox(),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Text("Change"),
                        Text(
                          change.toStringAsFixed(2),
                          style: TextStyle(
                            color: change < 0 ? Colors.red : Colors.green,
                            fontWeight: FontWeight.bold,
                          ),
                        )
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
      ],
    );
  }
}
