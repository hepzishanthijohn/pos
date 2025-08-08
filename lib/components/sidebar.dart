// lib/components/app_drawer.dart
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;
import 'package:rcspos/localdb/CategorySQLiteHelper.dart';
import 'package:rcspos/screens/customerpage.dart';
import 'package:rcspos/screens/home.dart';
import 'package:rcspos/screens/loginpage.dart';
import 'package:rcspos/screens/orderslistpage.dart';
import 'package:rcspos/screens/orderspage.dart';
import 'package:rcspos/screens/productpage.dart';
import 'package:rcspos/screens/productstablepage.dart';
import 'package:rcspos/utils/urls.dart';


class AppDrawer extends StatefulWidget {
  final Map<String, dynamic> posConfig;
  final String? searchQuery;
  final Function(Map<String, dynamic>)? onAddToCart;
  final Set<int>? addedProductIds; 
    final bool sessionState; 
  final int posId;

  const AppDrawer({
    super.key,
    required this.posConfig,
    this.searchQuery,
    this.onAddToCart,
    this.addedProductIds,
     required this.posId, // Required POS ID for the specific POS config
     required this.sessionState,
    });
   
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
    debugPrint('Session ID not found.');
    return;
  }

  final sessionId = rawSession.contains('session_id=') ? rawSession : 'session_id=$rawSession';
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
        final List<Map<String, dynamic>> result = List<Map<String, dynamic>>.from(json['result']);
        await catghelper.insertCategories(result); // 💾 Save to local SQLite

        setState(() {
          categories = result;
          _loading = false;
        });
      } else {
        throw Exception('Invalid response format');
      }
    } else {
      throw HttpException('Status code: ${response.statusCode}');
    }
  } on SocketException {
    final localCategories = catghelper.fetchCategories();
    setState(() {
      categories = localCategories;
      _loading = false;
    });
    debugPrint('Offline mode: Categories loaded from local DB');
  } catch (e) {
    final localCategories = catghelper.fetchCategories();
    setState(() {
      categories = localCategories;
      _loading = false;
    });
    debugPrint('Error loading categories: $e');
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
 decoration: const BoxDecoration(
    gradient: LinearGradient(
      colors: [Color(0xFF185A9D),Color(0xFF43CEA2), ],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
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
...categories.map((cat) {
  return ListTile(
    leading: buildCategoryIcon(cat['image_128']),
    title: Text(cat['display_name'] ?? 'Unnamed'),
   onTap: () {
  print('Category tapped: id=${cat['id']}, name=${cat['name']}');
  Navigator.pushReplacement(
    context,
    MaterialPageRoute(
      builder: (_) => HomePage(
        posId: widget.posId, 
        sessionState: widget.sessionState,
        categoryId: cat['id'],
        categoryName: cat['name'], // Make sure HomePage accepts this
        posConfig: widget.posConfig,
      ),
    ),
  );
}

  );
}).toList(),

  
ListTile(
                leading: const Icon(Icons.inventory_2), // Changed from Icons.grid_view
                title: const Text('Inventory'),
                onTap: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (_) => Productstablepage(
                       
                        searchQuery: widget.searchQuery ?? '',
                      ),
                    ),
                  );
                },
              ),
ListTile(
                leading: const Icon(Icons.people), // Changed from Icons.grid_view
                title: const Text('Customers'),
                onTap: () {
  Navigator.push( // Keeping this as Navigator.push for standard back button behavior
    context,
    MaterialPageRoute(builder: (context) => CustomerPage(
       posId: widget.posId,
        sessionState: widget.sessionState,
    )),
  );
},
              ), 
           ListTile(
                leading: const Icon(Icons.receipt_long), // Changed from Icons.people
                title: const Text('Sales'),
                onTap: () {
                  Navigator.push( // Keeping this as Navigator.push for standard back button behavior
                    context,
                    MaterialPageRoute(
                      builder: (_) => const OrderListPage(),
                    ),
                  );
                },
              ),// ✅ Logout Option
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
