// lib/components/app_drawer.dart
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;
import 'package:rcspos/localdb/CategorySQLiteHelper.dart';
import 'package:rcspos/screens/home.dart';
import 'package:rcspos/screens/loginpage.dart';
import 'package:rcspos/screens/productpage.dart';
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

  final catghelper = CategorySQLiteHelper();
  await catghelper.init();

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
        HttpHeaders.cookieHeader: sessionId,
        HttpHeaders.contentTypeHeader: 'application/json',
      },
    );

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      if (json['result'] is List) {
        final List<Map<String, dynamic>> result =
            List<Map<String, dynamic>>.from(json['result']);

        await catghelper.insertCategories(result); // ✅ Save to SQLite
        // catghelper.debugPrintAllCategories(); // Debug print
        setState(() {
          categories = result;
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
  } on SocketException {
    // 🔌 Offline fallback
    final localCategories = catghelper.fetchCategories();
    if (localCategories.isNotEmpty) {
      setState(() {
        categories = localCategories;
        _loading = false;
      });
      debugPrint('Offline mode: Categories loaded from local DB');
    } else {
      setState(() => _loading = false);
      debugPrint('No categories in local DB');
    }
  } catch (e) {
    setState(() => _loading = false);
    debugPrint('Error: $e');
  } finally {
    catghelper.close();
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

  // Static "All Products" menu
  ListTile(
    leading: const Icon(Icons.all_inclusive),
    title: const Text('All Products'),
    onTap: () {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => const HomePage(
            key: ValueKey('all'), // force rebuild
            categoryId: null,
            categoryName: null,
          ),
        ),
      );
    },
  ),
  const Divider(height: 1),
  ...categories.map((cat) {
    return ListTile(
      leading: buildCategoryIcon(cat['image_128']),
      title: Text(cat['display_name'] ?? 'Unnamed'),
      onTap: () {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => HomePage(
              key: ValueKey(cat['id']),
              categoryId: cat['id'],
              categoryName: cat['display_name'],
            ),
          ),
        );
      },
    );
  }).toList(),
    const Divider(),
    
    // ✅ Logout Option
    ListTile(
      leading: const Icon(Icons.exit_to_app, color: Colors.redAccent),
      title: const Text('Logout', style: TextStyle(color: Colors.redAccent)),
      onTap: () {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const Login()),
          (route) => false,
        );
      },
    ),

              ],
            ),
    );
  }
}
