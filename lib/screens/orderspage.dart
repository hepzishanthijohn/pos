import 'package:flutter/material.dart';
import 'package:hive/hive.dart';

class OrdersPage extends StatelessWidget {
  const OrdersPage({super.key});

  Future<List<Map>> _getOrders() async {
    final box = await Hive.openBox('orders');
    return box.values.cast<Map>().toList().reversed.toList(); // Show recent first
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Completed Orders'),
        backgroundColor: const Color(0xFF228CF0),
      ),
      body: FutureBuilder<List<Map>>(
        future: _getOrders(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final orders = snapshot.data!;
          if (orders.isEmpty) {
            return const Center(child: Text('No completed orders yet.'));
          }

          return ListView.separated(
            itemCount: orders.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final order = orders[index];
              return ListTile(
                leading: const Icon(Icons.receipt_long, color: Colors.green),
                title: Text('₹${order['amount']} - ${order['customer_name']}'),
                subtitle: Text('Phone: ${order['customer_phone']}'),
                trailing: Text(order['timestamp'].toString().substring(0, 16)),
              );
            },
          );
        },
      ),
    );
  }
}
