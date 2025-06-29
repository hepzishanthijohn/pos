import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;
import 'package:rcspos/screens/home.dart';
import 'package:rcspos/utils/urls.dart';


class POSConfigPage extends StatefulWidget {
  const POSConfigPage({super.key});

  @override
  State<POSConfigPage> createState() => _POSConfigPageState();
}

class _POSConfigPageState extends State<POSConfigPage> {
  bool _loading = true;
  List<Map<String, dynamic>> _configs = [];
  
  final String apiUrl =
      '${baseurl}/api/pos.config/?query={id,name,last_session_closing_cash,last_session_closing_date,current_session_state}';

  @override
  void initState() {
    super.initState();
    fetchPOSConfigs();
  }

  String _formatDate(String value) {
    try {
      final date = DateTime.tryParse(value);
      if (date != null) {
        return '${date.day.toString().padLeft(2, '0')}-${date.month.toString().padLeft(2, '0')}-${date.year}';
      }
    } catch (_) {}
    return 'N/A';
  }

  Future<void> fetchPOSConfigs() async {
    try {
      final box = await Hive.openBox('login');
      final rawSession = box.get('session_id');
      if (rawSession == null) {
        showError('Session ID not found. Please login again.');
        return;
      }
      final sessionId = rawSession.contains('session_id=') ? rawSession : 'session_id=$rawSession';

      final response = await http.get(
        Uri.parse(apiUrl),
        headers: {
          HttpHeaders.cookieHeader: sessionId,
          HttpHeaders.contentTypeHeader: 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _configs = List<Map<String, dynamic>>.from(data['result']);
          _loading = false;
        });
      } else {
        showError('Failed to fetch POS configs (${response.statusCode})');
      }
    } catch (e) {
      showError('Error: $e');
    }
  }

  void showError(String message) {
    setState(() => _loading = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Color getStatusColor(dynamic status) {
    if (status == 'opened') return Colors.green;
    if (status == false || status == 'closed') return Colors.redAccent;
    return Colors.grey;
  }

  IconData getStatusIcon(dynamic status) {
    if (status == 'opened') return Icons.check_circle;
    if (status == false || status == 'closed') return Icons.cancel;
    return Icons.help_outline;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Point Of Sale', style: TextStyle(color: Colors.white)),
        backgroundColor: const Color.fromARGB(255, 1, 139, 82),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _configs.isEmpty
              ? const Center(child: Text('No POS configurations found.'))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _configs.length,
                  itemBuilder: (context, index) {
                    final config = _configs[index];
                    final String name = config['name'] ?? 'Unnamed POS';
                    final double cash = (config['last_session_closing_cash'] ?? 0.0).toDouble();

                   final dynamic rawDate = config['last_session_closing_date'];
final String date = (rawDate == false || rawDate == null || rawDate.toString() == 'false' || rawDate.toString().trim().isEmpty)
    ? 'N/A'  // Change this to '-' if you prefer a dash
    : _formatDate(rawDate.toString());

                    final sessionState = config['current_session_state'];

                    return Card(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 3,
                      margin: const EdgeInsets.only(bottom: 16),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  getStatusIcon(sessionState),
                                  color: getStatusColor(sessionState),
                                  size: 32,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    name,
                                    style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black87,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const Icon(Icons.settings, color: Colors.grey, size: 24),
                              ],
                            ),
                            const SizedBox(height: 16),
                            // Text(
                            //   'POS ID: ${config['id']}',
                            //   style: const TextStyle(fontSize: 15, color: Colors.black54),
                            // ),
                            const SizedBox(height: 6),
                            Text(
                              'Last Closing Cash: ₹${cash.toStringAsFixed(2)}',
                              style: const TextStyle(fontSize: 15, color: Colors.black54),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Last Closing Date: $date',
                              style: const TextStyle(fontSize: 15, color: Colors.black54),
                            ),
                            const SizedBox(height: 16),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: getStatusColor(sessionState).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(5),
                              ),
                              child: Text(
                                'Session Status: ${sessionState == false ? 'Closed' : sessionState}',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: getStatusColor(sessionState),
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),
SizedBox(
  width: double.infinity,
  child: ElevatedButton.icon(
    icon: Icon(
  sessionState == 'opened' ? Icons.storefront : Icons.lock,
  size: 22,
),

    label: Text(
      sessionState == 'opened' ? 'Continue Selling' : 'Open Session',
      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w400),
    ),
    style: ElevatedButton.styleFrom(
      backgroundColor: const Color.fromARGB(255, 1, 139, 82),
      foregroundColor: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 14),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
      elevation: 3,
    ),
    onPressed: () {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const HomePage()),
      );
    },
  ),
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