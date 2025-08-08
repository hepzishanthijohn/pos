// file: localdb/orders_sqlite_helper.dart

import 'package:sqlite3/sqlite3.dart';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';

class OrderSQLiteHelper {
  static final OrderSQLiteHelper _instance = OrderSQLiteHelper._internal();
  factory OrderSQLiteHelper() => _instance;

  OrderSQLiteHelper._internal();

  late Database _db;

  Future<void> init() async {
    final Directory documentsDir = await getApplicationDocumentsDirectory();
    final String dbPath = p.join(documentsDir.path, 'orders.db');
    print("📁 Database Path: $dbPath");

    try {
      _db = sqlite3.open(dbPath);
      print("✅ Database opened successfully.");
    } catch (e) {
      print("❌ Failed to open database: $e");
      rethrow;
    }

    _ensureLatestSchema();
  }

  Database get db => _db;

  void _createTable() {
    db.execute('''
      CREATE TABLE IF NOT EXISTS orders (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        order_id TEXT UNIQUE,
        total REAL,
        tax REAL DEFAULT 0.0,
        customer_name TEXT,
        customer_phone TEXT,
        payment_method TEXT,
        paid_amount REAL,
        change_amount REAL,
        discount REAL,
        date TEXT
      );
    ''');
    print('DEBUG: Orders table created/checked (latest schema).');
  }

  void _ensureLatestSchema() {
    print('DEBUG: Checking database schema...');
    final existingColumns = db.select("PRAGMA table_info(orders);")
        .map((row) => row['name'] as String)
        .toList();

    const requiredColumns = [
      'id', 'order_id', 'total', 'tax', 'customer_name', 'customer_phone',
      'payment_method', 'paid_amount', 'change_amount', 'discount', 'date'
    ];

    bool needsMigration = false;
    if (existingColumns.isEmpty) {
      needsMigration = true;
      print('DEBUG: Orders table does not exist or is empty. Migration needed.');
    } else {
      for (var col in requiredColumns) {
        if (!existingColumns.contains(col)) {
          needsMigration = true;
          print('DEBUG: Missing column "$col". Migration needed.');
          break;
        }
      }
    }

    if (needsMigration) {
      print('DEBUG: Performing schema migration (drop and recreate)...');
      recreateTableWithUniqueConstraint();
    } else {
      print('DEBUG: Schema is up-to-date. No migration needed.');
    }
  }

  void recreateTableWithUniqueConstraint() {
    print('DEBUG: Starting table recreation/migration...');

    final List<Map<String, dynamic>> oldRows = [];
    try {
      final oldRowsResultSet = db.select('''
        SELECT id, order_id, total, customer_name, customer_phone,
               payment_method, paid_amount, change_amount, discount, date
        FROM orders
        WHERE id IN (SELECT MIN(id) FROM orders GROUP BY order_id)
      ''');
      final List<String> columnNames = oldRowsResultSet.columnNames;
      oldRows.addAll(oldRowsResultSet.map((row) {
        final Map<String, dynamic> rowMap = {};
        for (int i = 0; i < columnNames.length; i++) {
          rowMap[columnNames[i]] = row[i];
        }
        return rowMap;
      }).toList());
      print('DEBUG: Successfully retrieved old data.');
    } on SqliteException catch (e) {
      print('DEBUG: Could not retrieve old data (table might not exist or old schema): $e');
    }

    db.execute('DROP TABLE IF EXISTS orders');
    print('DEBUG: Old table dropped (if existed).');

    _createTable();
    print('DEBUG: New table created with latest schema.');

    if (oldRows.isNotEmpty) {
      for (var oldRow in oldRows) {
        insertOrderFromFields(
          orderId: oldRow['order_id'] as String,
          total: (oldRow['total'] as num?)?.toDouble() ?? 0.0,
          tax: (oldRow['tax'] as num?)?.toDouble() ?? 0.0,
          customerName: oldRow['customer_name'] as String? ?? 'Guest',
          customerPhone: oldRow['customer_phone'] as String? ?? '',
          paymentMethod: oldRow['payment_method'] as String? ?? 'Unknown',
          paidAmount: (oldRow['paid_amount'] as num?)?.toDouble() ?? 0.0,
          changeAmount: (oldRow['change_amount'] as num?)?.toDouble() ?? 0.0,
          discount: (oldRow['discount'] as num?)?.toDouble() ?? 0.0,
         date: oldRow['date'] as String? ?? '',

        );
      }
      print('DEBUG: Re-inserted ${oldRows.length} old orders.');
    } else {
      print('DEBUG: No old data to re-insert.');
    }

    print('✅ Orders table recreated/migrated with distinct order_id and updated schema.');
  }

   Future<void> insertOrderFromFields({
    required String orderId,
    required double total,
    required double tax,
    required String customerName,
    required String customerPhone,
    required String paymentMethod,
    required double paidAmount,
    required double changeAmount,
    required double discount,
    required String date,
  }) async {
    _db.execute('''
      INSERT INTO orders (
        order_id, total, tax, customer_name, customer_phone,
        payment_method, paid_amount, change_amount, discount, date
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    ''', [
      orderId,
      total,
      tax,
      customerName,
      customerPhone,
      paymentMethod,
      paidAmount,
      changeAmount,
      discount,
      date,
    ]);
  }

  void updateOrder({
    required String orderId,
    required double total,
    required double tax,
    required String customerName,
    required String customerPhone,
    required String paymentMethod,
    required double paidAmount,
    required double changeAmount,
    required double discount,
  }) {
    final stmt = db.prepare('''
      UPDATE orders SET
        total = ?, tax = ?, customer_name = ?, customer_phone = ?,
        payment_method = ?, paid_amount = ?, change_amount = ?, discount = ?, date = ?
      WHERE order_id = ?
    ''');

    stmt.execute([
      total,
      tax,
      customerName,
      customerPhone,
      paymentMethod,
      paidAmount,
      changeAmount,
      discount,
      DateTime.now().toIso8601String(),
      orderId,
    ]);

    stmt.dispose();
    print('🔄 Order $orderId updated.');
  }

  void deleteOrder(String orderId) {
    final stmt = db.prepare('DELETE FROM orders WHERE order_id = ?');
    stmt.execute([orderId]);
    stmt.dispose();
    print('🗑️ Order $orderId deleted.');
  }

  bool orderExists(String orderId) {
    final result = db.select(
      'SELECT COUNT(*) AS count FROM orders WHERE order_id = ?',
      [orderId],
    );
    return result.first['count'] > 0;
  }

  // --- MODIFIED METHOD: getTodaysPaymentMethodTotals ---
  Map<String, dynamic> getTodaysPaymentMethodTotals() {
    final String todayDateString = DateFormat('yyyy-MM-dd').format(DateTime.now());

    final Map<String, dynamic> totals = { // Changed to dynamic
      'cash': 0.0,
      'bank': 0.0,
      'card': 0.0,
      'totalOrdersAmount': 0.0,
      'totalOrdersCount': 0, // Added for count
    };

    // Query to get totals by payment method for today (sum of paid_amount)
    final paymentMethodResults = db.select('''
      SELECT payment_method, SUM(paid_amount) AS total_paid
      FROM orders
      WHERE substr(date, 1, 10) = ? -- Extract YYYY-MM-DD from date column
      GROUP BY payment_method
    ''', [todayDateString]);

    for (final row in paymentMethodResults) {
      final String? method = row['payment_method'] as String?;
      final double totalPaid = (row['total_paid'] as num?)?.toDouble() ?? 0.0;
      if (method != null) {
        final normalizedMethod = method.toLowerCase();
        if (totals.containsKey(normalizedMethod)) {
          totals[normalizedMethod] = totalPaid;
        }
      }
    }

    // Query to get overall sum of 'total' and 'count' for today
    final overallDailyResults = db.select('''
      SELECT SUM(total) AS daily_total, COUNT(id) AS daily_count
      FROM orders
      WHERE substr(date, 1, 10) = ?
    ''', [todayDateString]);

    if (overallDailyResults.isNotEmpty) {
        totals['totalOrdersAmount'] = (overallDailyResults.first['daily_total'] as num?)?.toDouble() ?? 0.0;
        totals['totalOrdersCount'] = (overallDailyResults.first['daily_count'] as int?) ?? 0; // Get the count
    }


    print('DEBUG: Today\'s Payment Totals and Count: $totals');
    return totals;
  }

  void printAllOrders() {
    final results = db.select('SELECT id, order_id, total, tax, customer_name, customer_phone, payment_method, paid_amount, change_amount, discount, date FROM orders ORDER BY id DESC');

    if (results.isEmpty) {
      print('📭 No orders found.');
      return;
    }

    print(''.padRight(120, '='));
    print(
      '${'ID'.padRight(6)} | '
      '${'Order ID'.padRight(15)} | '
      '${'Total'.padRight(10)} | '
      '${'Tax'.padRight(8)} | '
      '${'Customer Name'.padRight(20)} | '
      '${'Phone'.padRight(14)} | '
      '${'Payment Method'.padRight(14)} | '
      '${'Paid Amount'.padRight(12)} | '
      '${'Change'.padRight(12)} | '
      '${'Discount'.padRight(12)} | '
      '${'Date'}',
    );
    print(''.padRight(120, '='));

    for (final row in results) {
      String formattedDate = '';
      try {
        final DateTime dateTime = DateTime.parse(row['date'] as String);
        formattedDate = DateFormat('dd/MM/yyyy hh:mm a').format(dateTime);
      } catch (_) {
        formattedDate = 'Invalid Date';
      }

      print(
        '${(row['id'] ?? '').toString().padRight(6)} | '
        '${(row['order_id'] ?? '').toString().padRight(15)} | '
        '₹${(row['total'] ?? 0.0).toStringAsFixed(2).padRight(8)} | '
        '₹${(row['tax'] ?? 0.0).toStringAsFixed(2).padRight(6)} | '
        '${(row['customer_name'] ?? '').toString().padRight(20)} | '
        '${(row['customer_phone'] ?? '').toString().padRight(14)} | '
        '${(row['payment_method'] ?? '').toString().padRight(14)} | '
        '₹${(row['paid_amount'] ?? 0.0).toStringAsFixed(2).padRight(10)} | '
        '₹${(row['change_amount'] ?? 0.0).toStringAsFixed(2).padRight(10)} | '
        '₹${(row['discount'] ?? 0.0).toStringAsFixed(2).padRight(10)} | '
        '$formattedDate',
      );
    }

    print(''.padRight(120, '='));
  }

  List<Map<String, dynamic>> getAllOrders() {
    final result = db.select('SELECT id, order_id, total, tax, customer_name, customer_phone, payment_method, paid_amount, change_amount, discount, date FROM orders ORDER BY id DESC');
    final List<String> columnNames = result.columnNames;

    return result.map((row) {
      final Map<String, dynamic> rowMap = {};
      for (int i = 0; i < columnNames.length; i++) {
        rowMap[columnNames[i]] = row[i];
      }
      return rowMap;
    }).toList();
  }

  void close() {
    db.dispose();
    print('DEBUG: Database closed.');
  }

  void deleteAllOrders() {
  try {
    db.execute('DELETE FROM orders;');
    print('🗑️ All orders deleted successfully.');
  } catch (e) {
    print('❌ Failed to delete orders: $e');
  }
}

}