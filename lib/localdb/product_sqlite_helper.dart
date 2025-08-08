import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';

class ProductSQLiteHelper {
  static final ProductSQLiteHelper _instance = ProductSQLiteHelper._internal();
  factory ProductSQLiteHelper() => _instance;
  ProductSQLiteHelper._internal();

  Database? _db;
  bool _isInitialized = false;

  Future<void> _ensureDbInitialized() async {
    if (_isInitialized && _db != null) return;

    final dir = await getApplicationDocumentsDirectory();
    final dbPath = p.join(dir.path, 'products.db');
    _db = sqlite3.open(dbPath);

    _db!.execute('''
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

    _isInitialized = true;
  }

  Future<double> getStockForProduct(int productId) async {
    await _ensureDbInitialized();
    final result = _db!.select(
      'SELECT qty_available FROM products WHERE id = ?',
      [productId],
    );
    return result.isNotEmpty
        ? (result.first['qty_available'] as num).toDouble()
        : 0.0;
  }

  Future<void> updateStockAfterOrder(List<Map<String, dynamic>> cartItems) async {
    await _ensureDbInitialized();
    try {
      _db!.execute('BEGIN TRANSACTION;');
      for (final item in cartItems) {
        final int productId = item['id'];
        final double qtySold = (item['quantity'] ?? 0).toDouble();

        _db!.execute(
          '''
          UPDATE products
          SET qty_available = qty_available - ?
          WHERE id = ?;
          ''',
          [qtySold, productId],
        );
      }
      _db!.execute('COMMIT;');
    } catch (e) {
      _db!.execute('ROLLBACK;');
      print('⚠️ Failed to update stock: $e');
    }
  }

  Future<List<Map<String, dynamic>>> fetchProductsByCategory(int categoryId) async {
    await _ensureDbInitialized();
    final result = _db!.select(
      'SELECT * FROM products WHERE category_id = ?;',
      [categoryId],
    );

    return result.map((row) => _mapRowToProduct(row)).toList();
  }

  Future<void> insertProducts(List<Map<String, dynamic>> products) async {
    await _ensureDbInitialized();
    final db = _db!;

    for (var product in products) {
      final id = product['id'];

      final existing = db.select('SELECT qty_available FROM products WHERE id = ?', [id]);
      double qtyToInsert = (product['qty_available'] ?? 0).toDouble();

      if (existing.isNotEmpty) {
        final localQty = existing.first['qty_available'];
        qtyToInsert = (localQty is num) ? localQty.toDouble() : 0.0;
      }

final categList = product['pos_categ_ids'];
final category = (categList is List && categList.isNotEmpty && categList[0] is Map)
    ? categList[0] as Map<String, dynamic>
    : {'id': null, 'name': 'No Category'};

final taxList = product['taxes_id'];
final tax = (taxList is List && taxList.isNotEmpty && taxList[0] is Map)
    ? taxList[0] as Map<String, dynamic>
    : {'id': null, 'name': null};

db.execute('''
  INSERT OR REPLACE INTO products (
    id, display_name, list_price, qty_available, default_code,
    category_id, category_name, tax_id, tax_name, synced_at
  ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, datetime('now'))
''', [
  id,
  product['display_name'] ?? 'Unnamed',
  product['list_price'],
  qtyToInsert,
  product['default_code'] ?? '',
  category['id'],
  category['name'],
  tax['id'],
  tax['name'],
]);

    }
  }

  Future<List<Map<String, dynamic>>> fetchProducts() async {
    await _ensureDbInitialized();
    final result = _db!.select('SELECT * FROM products');
    return result.map((row) => _mapRowToProduct(row)).toList();
  }

  Map<String, dynamic> _mapRowToProduct(Row row) {
    return {
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
              {'id': row['tax_id'], 'name': row['tax_name']}
            ]
          : [],
      'synced_at': row['synced_at'],
    };
  }

Future<void> debugPrintAllProducts() async {
  await _ensureDbInitialized();
  final result = _db!.select('SELECT * FROM products');

  if (result.isEmpty) {
    print('❌ No product data found in SQLite.');
    return;
  }

  print('📦 SQLite3 Product Data (Formatted Table):');
  print('| ID  | Name                 | Price     | Category ID | Category Name      | Tax ID | Synced At            |');
  print('|-----|----------------------|-----------|-------------|---------------------|--------|-----------------------|');

  for (final row in result) {
    final id = row['id'];
    final name = (row['display_name'] ?? '').toString().padRight(22).substring(0, 22);
    final price = (row['list_price']?.toString() ?? '0.00').padRight(9);
    final categoryId = row['category_id']?.toString().padRight(11) ?? '';
    final categoryName = (row['category_name'] ?? '').toString().padRight(19).substring(0, 19);
    final taxId = row['tax_id']?.toString().padRight(6) ?? '';
    final syncedAt = (row['synced_at'] ?? '').toString().padRight(21).substring(0, 21);

    print('| ${id.toString().padRight(4)} | $name | $price | $categoryId | $categoryName | $taxId | $syncedAt |');
  }
}

Future<void> clearProducts() async {
  await _ensureDbInitialized();
  _db!.execute('DELETE FROM products;');
  print('✅ Old product data cleared successfully.');
}

  void close() {
    _db?.dispose();
    _db = null;
    _isInitialized = false;
  }
}
