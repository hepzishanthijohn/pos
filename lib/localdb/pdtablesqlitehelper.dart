import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';

class PdtableSQLiteHelper {
  late final Database db;

  Future<void> init() async {
    final dir = await getApplicationDocumentsDirectory();
    final dbPath = p.join(dir.path, 'productstable.db'); // Optional: separate file
    db = sqlite3.open(dbPath);

    db.execute('''
      CREATE TABLE IF NOT EXISTS products (
        id INTEGER PRIMARY KEY,
        display_name TEXT,
        list_price REAL,
        qty_available REAL,
        default_code TEXT,
        category_id INTEGER,
        category_name TEXT,
        tax_id INTEGER,
        tax_name TEXT,
        synced_at TEXT
      );
    ''');
  }

  Future<void> insertProducts(List<Map<String, dynamic>> products) async {
    db.execute('DELETE FROM products;');

    final now = DateTime.now().toIso8601String();
    final stmt = db.prepare('''
      INSERT INTO products (
        id, display_name, list_price, qty_available, default_code,
        category_id, category_name, tax_id, tax_name, synced_at
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
    ''');

    db.execute('BEGIN TRANSACTION;');
    for (final product in products) {
      final categ = product['categ_id'] ?? {};
      final taxes = (product['taxes_id'] as List).isNotEmpty ? product['taxes_id'][0] : {};

      stmt.execute([
        product['id'],
        product['display_name'],
        product['list_price'],
        product['qty_available'],
        product['default_code']?.toString(),
        categ['id'],
        categ['name'],
        taxes['id'],
        taxes['name'],
        now
      ]);
    }
    db.execute('COMMIT;');
    stmt.dispose();
  }

  List<Map<String, dynamic>> fetchProducts() {
    final result = db.select('SELECT * FROM products');

    return result.map((row) => {
      'id': row['id'],
      'display_name': row['display_name'],
      'list_price': row['list_price'],
      'qty_available': row['qty_available'],
      'default_code': row['default_code'],
      'categ_id': {
        'id': row['category_id'],
        'name': row['category_name'],
      },
      'taxes_id': row['tax_id'] != null
          ? [
              {
                'id': row['tax_id'],
                'name': row['tax_name'],
              }
            ]
          : [],
      'synced_at': row['synced_at'],
    }).toList();
  }
void debugPrintAllProductstb() {
  final result = db.select('SELECT * FROM products');

  if (result.isEmpty) {
    print('❌ No product data found in SQLite.');
    return;
  }

  print('📦 SQLite3 Product Data (Formatted Table):');
  print(
      '| ID  | Name                 | Price     | Category ID | Tax ID     | Synced At            |');
  print(
      '|-----|----------------------|-----------|-------------|------------|-----------------------|');

  for (final row in result) {
    final id = row['id'];
    final name = (row['display_name'] ?? '').toString().padRight(20).substring(0, 20);
    final price = row['list_price']?.toString().padRight(9) ?? '0.00'.padRight(9);
    final categoryId = row['category_id']?.toString().padRight(11) ?? ''.padRight(11);
    final taxId = row['tax_id']?.toString().padRight(10) ?? ''.padRight(10);
    final syncedAt = (row['synced_at'] ?? '').toString().padRight(21).substring(0, 21);

    print('| ${id.toString().padRight(4)} | $name | $price | $categoryId | $taxId | $syncedAt |');
  }
}


  void close() {
    db.dispose();
  }
}
