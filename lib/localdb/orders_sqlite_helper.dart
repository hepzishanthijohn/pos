import 'package:sqlite3/sqlite3.dart';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:intl/intl.dart';

class OrderSQLiteHelper {
  static final OrderSQLiteHelper _instance = OrderSQLiteHelper._internal();
  factory OrderSQLiteHelper() => _instance;
  late Database _db;

  OrderSQLiteHelper._internal() {
    String dbPath;
    // In a real Flutter app, use path_provider for persistent storage across platforms
    // For this example, and for command-line Dart, Directory.current.path is used.
    // For actual deployed Flutter apps, change this to use `path_provider`:
    // import 'package:path_provider/path_provider.dart';
    // final documentsDirectory = await getApplicationDocumentsDirectory();
    // dbPath = p.join(documentsDirectory.path, 'orders.db');
    dbPath = p.join(Directory.current.path, 'orders.db');

    print('DEBUG: Database path: $dbPath');
    try {
      _db = sqlite3.open(dbPath);
      print('DEBUG: Database opened successfully.');
    } catch (e) {
      print('ERROR opening DB: $e');
      rethrow;
    }
    _createTable();
  }

  Database get db => _db;

  void _createTable() {
    db.execute('''
      CREATE TABLE IF NOT EXISTS orders (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        order_id TEXT UNIQUE,
        total REAL,
        tax REAL,
        customer_name TEXT,
        customer_phone TEXT,
        payment_method TEXT,
        paid_amount REAL,
        change_amount REAL,
        discount REAL,
        date TEXT
      );
    ''');
    print('DEBUG: Orders table created/checked.');
  }

  void recreateTableWithUniqueConstraint() {
    print('DEBUG: Starting table recreation...');

    final oldRowsResultSet = db.select('''
      SELECT id, order_id, total, tax, customer_name, customer_phone,
             payment_method, paid_amount, change_amount, discount, date
      FROM orders
      WHERE id IN (SELECT MIN(id) FROM orders GROUP BY order_id)
    ''');

    // Get column names from the ResultSet, then iterate rows
    final List<String> columnNames = oldRowsResultSet.columnNames;
    final List<Map<String, dynamic>> oldRows = oldRowsResultSet.map((row) {
      final Map<String, dynamic> rowMap = {};
      for (int i = 0; i < columnNames.length; i++) {
        rowMap[columnNames[i]] = row[i]; // Access by index
      }
      return rowMap;
    }).toList();


    db.execute('DROP TABLE IF EXISTS orders');
    print('DEBUG: Old table dropped.');

    _createTable();
    print('DEBUG: New table created.');

    for (var oldRow in oldRows) {
      insertOrder(
        orderId: oldRow['order_id'] as String,
        total: (oldRow['total'] as num).toDouble(),
        tax: (oldRow['tax'] as num).toDouble(),
        customerName: oldRow['customer_name'] as String,
        customerPhone: oldRow['customer_phone'] as String,
        paymentMethod: oldRow['payment_method'] as String,
        paidAmount: (oldRow['paid_amount'] as num).toDouble(),
        changeAmount: (oldRow['change_amount'] as num).toDouble(),
        discount: (oldRow['discount'] as num).toDouble(),
        date: oldRow['date'] as String,
      );
    }

    print('✅ Orders table recreated with distinct order_id.');
  }

  void insertOrder({
    required String orderId,
    required double total,
    required double tax,
    required String customerName,
    required String customerPhone,
    required String paymentMethod,
    required double paidAmount,
    required double changeAmount,
    required double discount,
    String? date,
  }) {
    final stmt = db.prepare('''
      INSERT INTO orders (
        order_id, total, tax, customer_name, customer_phone,
        payment_method, paid_amount, change_amount, discount, date
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    ''');

    try {
      stmt.execute([
        orderId,
        total,
        tax,
        customerName,
        customerPhone,
        paymentMethod,
        paidAmount,
        changeAmount,
        discount,
        date ?? DateTime.now().toIso8601String(),
      ]);
      print('✅ Order $orderId inserted.');
    } on SqliteException catch (e) {
      if (e.message.contains('UNIQUE constraint failed')) {
        print('⚠ Order $orderId already exists. Skipping insert.');
      } else {
        print('❌ Error inserting order: $e');
      }
    } finally {
      stmt.dispose();
    }
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

  void printAllOrders() {
    final results = db.select('SELECT * FROM orders ORDER BY id DESC');

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
    final result = db.select('SELECT * FROM orders ORDER BY id DESC');
    final List<String> columnNames = result.columnNames; // Get column names from ResultSet

    return result.map((row) {
      final Map<String, dynamic> rowMap = {};
      for (int i = 0; i < columnNames.length; i++) {
        rowMap[columnNames[i]] = row[i]; // Access by index
      }
      return rowMap;
    }).toList();
  }

  void close() {
    db.dispose();
    print('DEBUG: Database closed.');
  }
}