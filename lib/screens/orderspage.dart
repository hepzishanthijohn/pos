// lib/screens/orders_page.dart

import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;
import 'package:rcspos/utils/urls.dart';

class OrdersPage extends StatefulWidget {
  const OrdersPage({super.key});

  @override
  State<OrdersPage> createState() => _OrdersPageState();
}

class _OrdersPageState extends State<OrdersPage> {
  List<dynamic> orders = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    fetchOrders();
  }

Future<void> fetchOrders() async {
  final box = await Hive.openBox('login');
  final rawSession = box.get('session_id');
  if (rawSession == null) {
    showError('Session not found. Please login again.');
    return;
  }

  final sessionId = rawSession.contains('session_id=') ? rawSession : 'session_id=$rawSession';
  final url = Uri.parse('${baseurl}/api/pos.order');

  try {
    final response = await http.get(
      url,
      headers: {
        HttpHeaders.cookieHeader: sessionId,
        HttpHeaders.contentTypeHeader: 'application/json',
      },
    );

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      setState(() {
        orders = json['result'] ?? [];
        loading = false;
      });

      // ✅ Print the fetched orders to console
      for (var order in orders) {
        print("Order ID: ${order['id']}, Name: ${order['display_name']}, Total: ₹${order['amount_total']}, State: ${order['state']}");
      }

    } else {
      showError('Failed to load orders (${response.statusCode})');
    }
  } catch (e) {
    showError('Error fetching orders: $e');
  }
}

  void showError(String message) {
    setState(() => loading = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('POS Orders',
        
        style: TextStyle(
          color: Colors.white
        ),),
        
        backgroundColor: const Color.fromARGB(255, 1, 139, 82),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: orders.length,
              itemBuilder: (context, index) {
                final order = orders[index];
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: ListTile(
                    title: Text(order['display_name'] ?? 'Unnamed Order'),
                    subtitle: Text('Date: ${order['date_order']} \nCashier: ${order['cashier']}'),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '₹${order['amount_total'].toString()}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                        Text(
                          order['state'].toString().toUpperCase(),
                          style: const TextStyle(fontSize: 12, color: Colors.black54),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
