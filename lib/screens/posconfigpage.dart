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
      '$baseurl/api/pos.config/?query={id,name,shop_addrs,last_session_closing_cash,last_session_closing_date,current_session_state,shop_gst_no,shop_phone_no,shop_owner_id{id,name}}';

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
        final List configsRaw = data['result'];

        setState(() {
          _configs = configsRaw.map((e) => Map<String, dynamic>.from(e)).toList();
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

  String getStatusText(dynamic status) {
    if (status == 'opened') return 'In Progress';
    if (status == false || status == 'closed') return 'Closed';
    return 'Unknown';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Point Of Sale', style: TextStyle(fontFamily: 'Arial', color: Colors.white)),
        backgroundColor: const Color.fromARGB(255, 1, 139, 82),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      backgroundColor: const Color(0xFFF7F4FB),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _configs.isEmpty
              ? const Center(child: Text('No POS configurations found.'))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: GridView.count(
                    crossAxisCount: MediaQuery.of(context).size.width > 600 ? 2 : 1,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: 1.8,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    children: _configs.map((config) {
                      final String name = config['name'] ?? 'Unnamed POS';
                      final String address = config['shop_addrs'] ?? '-';
                      final double cash = (config['last_session_closing_cash'] ?? 0.0).toDouble();
                      final String shopGstNo = (config['shop_gst_no'] ?? '-').toString();
                      final String shopPhoneNo = config['shop_phone_no']?.toString() ?? '-';
                      final String shopOwnerName = config['shop_owner_id']?['name'] ?? 'Unknown Owner';
                      final dynamic rawDate = config['last_session_closing_date'];
                      final String date = (rawDate == false || rawDate == null || rawDate.toString() == 'false')
                          ? 'N/A'
                          : _formatDate(rawDate.toString());
                      final sessionState = config['current_session_state'];

                      return Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade300),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            )
                          ],
                        ),
                        padding: const EdgeInsets.all(16),
                        child: Stack(
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 4),
                                Text(
                                  name,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                    color: Color.fromARGB(255, 3, 0, 0),
                                    fontFamily: 'Arial',
                                  ),
                                ),
                                const SizedBox(height: 8),
                                _buildInfoText('Shop Incharge: ', shopOwnerName),
                                const SizedBox(height: 8),
                                _buildInfoText('Phone No: ', shopPhoneNo),
                                const SizedBox(height: 8),
                                 _buildInfoText('Shop Address: ', address),
                              
                                const SizedBox(height: 8),
                                 _buildInfoText('Shop GST No: ', shopGstNo),
                                const SizedBox(height: 8),
                                _buildInfoText('Last Closing Cash: ', '₹${cash.toStringAsFixed(2)}'),
                                const SizedBox(height: 8),
                                _buildInfoText('Last Closing Date: ', date),
                                const Spacer(),
                                Align(
                                  alignment: Alignment.bottomLeft,
                                  child: ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color.fromARGB(255, 1, 139, 82),
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                                    ),
                                    onPressed: () {
                                      Navigator.pushReplacement(
                                        context,
                                        MaterialPageRoute(builder: (context) => const HomePage()),
                                      );
                                    },
                                    child: const Text('Resume', style: TextStyle(fontFamily: 'Arial', fontSize: 14)),
                                  ),
                                ),
                              ],
                            ),
                            Positioned(
                              top: 0,
                              right: 0,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: getStatusColor(sessionState),
                                  borderRadius: const BorderRadius.only(
                                    topRight: Radius.circular(12),
                                    bottomLeft: Radius.circular(12),
                                  ),
                                ),
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                child: Text(
                                  getStatusText(sessionState),
                                  style: const TextStyle(color: Colors.white, fontSize: 12, fontFamily: 'Arial'),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
    );
  }

  Widget _buildInfoText(String label, String value) {
    return RichText(
      text: TextSpan(
        style: const TextStyle(
          fontSize: 15,
          fontFamily: 'Arial',
          fontWeight: FontWeight.w500,
          color: Color.fromARGB(185, 0, 0, 0),
        ),
        children: [
          TextSpan(
            text: label,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          TextSpan(text: value),
        ],
      ),
    );
  }
}
