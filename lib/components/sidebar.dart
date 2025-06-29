// lib/components/app_drawer.dart
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;
import 'package:rcspos/screens/home.dart';
import 'package:rcspos/utils/urls.dart';


class AppDrawer extends StatefulWidget {
  const AppDrawer({super.key});

  @override
  State<AppDrawer> createState() => _AppDrawerState();
}

class _AppDrawerState extends State<AppDrawer> {
  List<Map<String, dynamic>> categories = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    fetchCategories();
  }

 Future<void> fetchCategories() async {
  final box = await Hive.openBox('login');
  final rawSession = box.get('session_id');

  if (rawSession == null) {
    setState(() => _loading = false);
    debugPrint('Session ID not found. Please login again.');
    return;
  }

  final sessionId = rawSession.contains('session_id=')
      ? rawSession
      : 'session_id=$rawSession';

  final url = '${baseurl}api/pos.category';

  try {
    final response = await http.get(
      Uri.parse(url),
      headers: {
        HttpHeaders.cookieHeader: sessionId, // ✅ Session sent as cookie
        HttpHeaders.contentTypeHeader: 'application/json',
      },
    );

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      if (json['result'] is List) {
        setState(() {
          categories = List<Map<String, dynamic>>.from(json['result']);
          _loading = false;
        });
      } else {
        setState(() => _loading = false);
        debugPrint('Unexpected format in response');
      }
    } else {
      setState(() => _loading = false);
      debugPrint('Failed to fetch categories (${response.statusCode})');
    }
  } catch (e) {
    setState(() => _loading = false);
    debugPrint('Error: $e');
  }
}
Widget buildCategoryIcon(dynamic imageValue) {
  if (imageValue is! String || imageValue == 'false') {
    return const Icon(Icons.category);
  }

  try {
    return CircleAvatar(
      radius: 16,
      backgroundImage: MemoryImage(base64Decode(imageValue)),
      backgroundColor: Colors.transparent,
    );
  } catch (_) {
    return const Icon(Icons.category);
  }
}


  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: EdgeInsets.zero,
              children: [
                const DrawerHeader(
                  decoration: BoxDecoration(
                    color: const Color.fromARGB(255, 1, 139, 82),
                  ),
                  child: Align(
                    alignment: Alignment.bottomLeft,
                    child: Text(
                      'Categories',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                      ),
                    ),
                  ),
                ),
                ...categories.map((cat) {
                  return ListTile(
                    leading: buildCategoryIcon(cat['image_128']),
                    title: Text(cat['display_name'] ?? 'Unnamed'),
                  onTap: () {
  Navigator.pushReplacement(
    context,
    MaterialPageRoute(
      builder: (_) => HomePage(
        categoryId: cat['id'],
        categoryName: cat['display_name'],
      ),
    ),
  );
},

                  );
                }).toList(),
              ],
            ),
    );
  }
}
