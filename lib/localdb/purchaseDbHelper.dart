import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart' as sql;

class PurchaseDBHelper {
  static sql.Database? _db;
  static const _dbName = 'purchase_database.db';

  Future<sql.Database> get database async {
    if (_db != null) return _db!;
    return await _initDB();
  }
Future<sql.Database> _initDB() async {
  final dir = await getApplicationDocumentsDirectory();
  final path = join(dir.path, _dbName);
  final file = File(path);
  final exists = await file.exists();

  if (_db != null) {
    try {
      _db!.dispose();
    } catch (e) {
      debugPrint("⚠️ DB dispose error: $e");
    }
    _db = null;
  }

  _db = sql.sqlite3.open(path);

  if (!exists) {
    _createTables(_db!);
  } else {
    // Database already exists - perform schema migrations here
    _migrateDatabase(_db!);
  }

  return _db!;
}


void _migrateDatabase(sql.Database db) {
  try {
    // Add 'synced' column to existing purchases table if not exist
    db.execute('ALTER TABLE purchases ADD COLUMN synced INTEGER DEFAULT 0;');
    debugPrint('✅ Migrated: Added synced column');
  } catch (e) {
    // Ignore if column already exists (SQLite throws error)
    debugPrint('ℹ️ Migration check or ignored error: $e');
  }
}

  void _createTables(sql.Database db) {
    db.execute('''
      CREATE TABLE IF NOT EXISTS purchases (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        purchase_id TEXT NOT NULL UNIQUE,
        purchase_date TEXT NOT NULL,
        order_id TEXT,
        supplier_name TEXT,
        supplier_phone TEXT,
        total_amount REAL NOT NULL,
        total_items_qty INTEGER NOT NULL,
        sgst_amount REAL DEFAULT 0.0,
        cgst_amount REAL DEFAULT 0.0,
        total_tax_amount REAL DEFAULT 0.0,
        status TEXT DEFAULT 'pending',
        pos_config_name TEXT,
        pos_config_address TEXT,
        pos_config_phone TEXT,
        recorded_by TEXT,
        payment_method TEXT,
        discount_amount REAL DEFAULT 0.0,
        notes TEXT
      );
    ''');

    db.execute('''
      CREATE TABLE IF NOT EXISTS purchase_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        purchase_detail_id INTEGER NOT NULL,
        product_id INTEGER,
        product_name TEXT NOT NULL,
        quantity INTEGER NOT NULL,
        price_per_unit REAL NOT NULL,
        item_total REAL NOT NULL,
        FOREIGN KEY (purchase_detail_id) REFERENCES purchases(id) ON DELETE CASCADE
      );
    ''');
  }

  Future<int> insertPurchase(
    Map<String, dynamic> purchase,
    List<Map<String, dynamic>> items,
  ) async {
    final db = await database;
    db.execute('BEGIN TRANSACTION;');

    try {
      final purchaseStmt = db.prepare('''
        INSERT INTO purchases (
          purchase_id, purchase_date, order_id, supplier_name, supplier_phone,
          total_amount, total_items_qty, sgst_amount, cgst_amount, total_tax_amount,
          status, pos_config_name, pos_config_address, pos_config_phone, recorded_by,
          payment_method, discount_amount, notes
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      ''');

      purchaseStmt.execute([
        purchase['purchase_id'],
        purchase['purchase_date'],
        purchase['order_id'],
        purchase['supplier_name'],
        purchase['supplier_phone'],
        purchase['total_amount'],
        purchase['total_items_qty'],
        purchase['sgst_amount'] ?? 0.0,
        purchase['cgst_amount'] ?? 0.0,
        purchase['total_tax_amount'] ?? 0.0,
        purchase['status'] ?? 'pending',
        purchase['pos_config_name'],
        purchase['pos_config_address'],
        purchase['pos_config_phone'],
        purchase['recorded_by'],
        purchase['payment_method'],
        purchase['discount_amount'] ?? 0.0,
        purchase['notes'],
      ]);

      final purchaseId = db.lastInsertRowId;
      purchaseStmt.dispose();

      final itemStmt = db.prepare('''
        INSERT INTO purchase_items (
          purchase_detail_id, product_id, product_name, quantity, price_per_unit, item_total
        ) VALUES (?, ?, ?, ?, ?, ?)
      ''');

      for (final item in items) {
        itemStmt.execute([
          purchaseId,
          item['product_id'],
          item['product_name'],
          item['quantity'],
          item['price_per_unit'],
          item['item_total'],
        ]);
      }

      itemStmt.dispose();
      db.execute('COMMIT;');
      return purchaseId;
    } catch (e) {
      db.execute('ROLLBACK;');
      debugPrint('❌ Insert failed: $e');
      return -1;
    }
  }

  Future<Map<String, dynamic>?> getPurchaseById(int id) async {
    final db = await database;
    final result = db.select('SELECT * FROM purchases WHERE id = ?', [id]);
    if (result.isEmpty) return null;

    final purchase = Map<String, dynamic>.fromIterables(
      result.columnNames,
      List.generate(result.columnNames.length, (i) => result.first.columnAt(i)),
    );

    final items = db.select('SELECT * FROM purchase_items WHERE purchase_detail_id = ?', [id]);

    final itemsList = items.map((row) {
      return Map<String, dynamic>.fromIterables(
        items.columnNames,
        List.generate(items.columnNames.length, (i) => row.columnAt(i)),
      );
    }).toList();

    return {
      'purchase': purchase,
      'items': itemsList,
    };
  }

  Future<Map<String, dynamic>?> getPurchaseByOrderId(String orderId) async {
    final db = await database;
    final result = db.select('SELECT * FROM purchases WHERE order_id = ?', [orderId]);

    if (result.isEmpty) return null;

    final purchase = Map<String, dynamic>.fromIterables(
      result.columnNames,
      List.generate(result.columnNames.length, (i) => result.first.columnAt(i)),
    );

    final items = db.select('SELECT * FROM purchase_items WHERE purchase_detail_id = ?', [purchase['id']]);

    final itemsList = items.map((row) {
      return Map<String, dynamic>.fromIterables(
        items.columnNames,
        List.generate(items.columnNames.length, (i) => row.columnAt(i)),
      );
    }).toList();

    return {
      'purchase': purchase,
      'items': itemsList,
    };
  }

  Future<List<Map<String, dynamic>>> getTodaysPurchases() async {
  final db = await database;
  
  // Format YYYY-MM-DD for today
  final String todayDate = DateFormat('yyyy-MM-dd').format(DateTime.now());

  final result = db.select(
    '''
    SELECT *
    FROM purchases
    WHERE substr(purchase_date, 1, 10) = ?
    ORDER BY purchase_date DESC
    ''',
    [todayDate],
  );

  // Convert to List<Map>
  return result.map((row) {
    final Map<String, dynamic> map = {};
    for (final col in row.keys) {
      map[col] = row[col];
    }
    return map;
  }).toList();
}


  Future<void> printPurchaseData(int id) async {
    final result = await getPurchaseById(id);
    if (result == null) {
      debugPrint("❌ Purchase $id not found");
      return;
    }

    final p = result['purchase'];
    final items = result['items'] as List<Map<String, dynamic>>;

    debugPrint("🧾 PURCHASE [ID: $id]");
    debugPrint("=" * 90);
    debugPrint("Purchase ID    : ${p['purchase_id']}");
    debugPrint("Order ID       : ${p['order_id']}");
    debugPrint("Date           : ${p['purchase_date']}");
    debugPrint("Supplier Name  : ${p['supplier_name']}");
    debugPrint("Supplier Phone : ${p['supplier_phone']}");
    debugPrint("Shop Name      : ${p['pos_config_name']}");
    debugPrint("Shop Address   : ${p['pos_config_address']}");
    debugPrint("Shop Phone     : ${p['pos_config_phone']}");
    debugPrint("Recorded By    : ${p['recorded_by']}");
    debugPrint("Payment Method : ${p['payment_method']}");
    debugPrint("Status         : ${p['status']}");
    debugPrint("Notes          : ${p['notes'] ?? ''}");
    debugPrint("-" * 90);

    debugPrint("Product                        | Qty | Rate      | Total");
    debugPrint("-" * 90);

    for (final i in items) {
      final name = (i['product_name'] ?? '').toString().padRight(28).substring(0, 28);
      final qty = '${i['quantity']}'.padLeft(3);
      final rate = '₹${(i['price_per_unit'] ?? 0.0).toStringAsFixed(2)}'.padLeft(8);
      final total = '₹${(i['item_total'] ?? 0.0).toStringAsFixed(2)}'.padLeft(8);
      debugPrint("$name | $qty | $rate | $total");
    }

    debugPrint("-" * 90);
    debugPrint("Subtotal       : ₹${((p['total_amount'] ?? 0.0) - (p['total_tax_amount'] ?? 0.0)).toStringAsFixed(2)}");
    debugPrint("SGST Amount    : ₹${(p['sgst_amount'] ?? 0.0).toStringAsFixed(2)}");
    debugPrint("CGST Amount    : ₹${(p['cgst_amount'] ?? 0.0).toStringAsFixed(2)}");
    debugPrint("Total GST      : ₹${(p['total_tax_amount'] ?? 0.0).toStringAsFixed(2)}");
    debugPrint("Final Amount   : ₹${(p['total_amount'] ?? 0.0).toStringAsFixed(2)}");
    debugPrint("Total Items    : ${p['total_items_qty']}");
    debugPrint("=" * 90);
  }

Future<List<Map<String, dynamic>>> getUnsyncedPurchases() async {
  final db = await database;
  final result = db.select('SELECT * FROM purchases WHERE synced = 0 OR synced IS NULL');

  final List<Map<String, dynamic>> purchases = [];

  for (final row in result) {
    final rowMap = <String, dynamic>{};
    for (final column in row.keys) {
      rowMap[column] = row[column];
    }
    purchases.add(rowMap);
  }

  return purchases;
}

Future<void> markPurchaseAsSynced(String orderId) async {
  final db = await database;
  final stmt = db.prepare(
    'UPDATE purchases SET synced = 1, status = ? WHERE order_id = ?',
  );
  stmt.execute(['synced', orderId]);
  stmt.dispose();
}




  Future<void> close() async {
    if (_db != null) {
      _db!.dispose();
      _db = null;
    }
  }
  Future<void> deleteAllPurchases() async {
  final db = await database;

  db.execute('BEGIN TRANSACTION;');

  try {
    db.execute('DELETE FROM purchase_items;');
    db.execute('DELETE FROM purchases;');
    db.execute('COMMIT;');
    debugPrint('🗑️ All purchase data deleted');
  } catch (e) {
    db.execute('ROLLBACK;');
    debugPrint('❌ Failed to delete purchase data: $e');
  }
}

}
