
import 'package:flutter/material.dart';
import 'package:rcspos/data/customerdata.dart';


// Customer model class
class Customer {
  final String name;
  final String address;
  final String phone;

  Customer({required this.name, required this.address, required this.phone});
}

class SelectCustomerPage extends StatefulWidget {
  SelectCustomerPage({Key? key}) : super(key: key);

  @override
  _SelectCustomerPageState createState() => _SelectCustomerPageState();
}

class _SelectCustomerPageState extends State<SelectCustomerPage> {
  // Convert the map list to List<Customer> here
  final List<Customer> customerList = customers.map((c) => Customer(
        name: c['name'] ?? '',
        address: c['address'] ?? '',
        phone: c['phone'] ?? '',
      )).toList();

  Customer? selectedCustomer;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Color(0xB3228CF0),
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Select Customer'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              // TODO: Implement search
            },
          ),
          TextButton(
            onPressed: selectedCustomer == null
                ? null
                : () {
                    // Return the selected customer when Done is clicked
                    Navigator.pop(context, selectedCustomer);
                  },
            child: Text(
              'Done',
              style: TextStyle(
                color: selectedCustomer == null
                    ? Colors.white.withOpacity(0.5)
                    : Colors.white,
              ),
            ),
          ),
        ],
      ),
      body: ListView.builder(
        itemCount: customerList.length,
        itemBuilder: (context, index) {
          final customer = customerList[index];
          final isSelected = customer == selectedCustomer;

          return GestureDetector(
            onTap: () {
              setState(() {
                selectedCustomer = customer;
              });
            },
            child: CustomerCard(
              customer: customer,
              isSelected: isSelected,
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // TODO: Add new customer
        },
        backgroundColor: Colors.teal,
        child: const Icon(Icons.person_add, color: Colors.white),
      ),
    );
  }
}

class CustomerCard extends StatelessWidget {
  final Customer customer;
  final bool isSelected;

  const CustomerCard({
    Key? key,
    required this.customer,
    this.isSelected = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final cardColor = isSelected ? Colors.purple.withOpacity(0.1) : Colors.white;

    return Card(
      color: cardColor,
      margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 0),
      elevation: 0,
      shape: const Border(),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        customer.name,
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        customer.address,
                        style: TextStyle(
                            fontSize: 14, color: Colors.grey[700]),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        customer.phone,
                        style: TextStyle(
                            fontSize: 14, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
                Row(
                  children: [
                    if (isSelected)
                      const Icon(Icons.check_circle, color: Colors.purple),
                    TextButton(
                      onPressed: () {
                        print('Edit ${customer.name}');
                      },
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.edit, size: 18, color: Colors.grey),
                          const SizedBox(width: 4),
                          Text(
                            'Edit',
                            style: TextStyle(color: Colors.grey[700]),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const Divider(height: 16, thickness: 1, color: Colors.black12),
          ],
        ),
      ),
    );
  }
}
