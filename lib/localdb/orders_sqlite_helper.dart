// file: localdb/orders_sqlite_helper.dart

import 'package:sqlite3/sqlite3.dart';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:intl/intl.dart';
// If you're using path_provider for Flutter, uncomment this:
// import 'package:path_provider/path_provider.dart';

class OrderSQLiteHelper {
  static final OrderSQLiteHelper _instance = OrderSQLiteHelper._internal();
  factory OrderSQLiteHelper() => _instance;
  late Database _db;

  OrderSQLiteHelper._internal() {
    String dbPath;
    // For Flutter, use getApplicationDocumentsDirectory() or getExternalStorageDirectory()
    // For now, keeping Directory.current.path as per your original code's context.
    dbPath = p.join(Directory.current.path, 'orders.db');

    print('DEBUG: Database path: $dbPath');
    try {
      _db = sqlite3.open(dbPath);
      print('DEBUG: Database opened successfully.');
    } catch (e) {
      print('ERROR opening DB: $e');
      rethrow;
    }

    // --- CRITICAL CHANGE HERE ---
    // Instead of _createTable() then _performMigration() then recreateTableWithUniqueConstraint()
    // We make recreateTableWithUniqueConstraint() the primary entry point for ensuring schema.
    // It will always ensure the latest schema is applied (by dropping and recreating if needed).
    // This is good for development, less ideal for production without careful data handling.
    _ensureLatestSchema(); // Call this new method for robust migration.

    print('DEBUG: Orders table initialized/migrated.');
  }

  Database get db => _db;

  void _createTable() {
    // This defines the LATEST schema for your 'orders' table
    db.execute('''
      CREATE TABLE IF NOT EXISTS orders (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        order_id TEXT UNIQUE,
        total REAL,
        tax REAL DEFAULT 0.0, -- Ensure 'tax' column is defined here with a default
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

  // New method to check and perform migration
  void _ensureLatestSchema() {
    print('DEBUG: Checking database schema...');
    // Get existing column names for the 'orders' table
    final existingColumns = db.select("PRAGMA table_info(orders);")
        .map((row) => row['name'] as String)
        .toList();

    // Define the columns that should exist in the latest schema
    const requiredColumns = [
      'id', 'order_id', 'total', 'tax', 'customer_name', 'customer_phone',
      'payment_method', 'paid_amount', 'change_amount', 'discount', 'date'
    ];

    bool needsMigration = false;
    if (existingColumns.isEmpty) {
      // Table doesn't exist, needs creation (which _createTable handles, but recreateTable handles it robustly)
      needsMigration = true;
      print('DEBUG: Orders table does not exist or is empty. Migration needed.');
    } else {
      // Check if any required column is missing
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


  // This method now serves as the "perform migration" step
  void recreateTableWithUniqueConstraint() {
    print('DEBUG: Starting table recreation/migration...');

    // 1. Safely retrieve existing data.
    // ONLY select columns that are GUARANTEED to exist in older schemas.
    // Do NOT select 'tax' here if an old database might not have it.
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
      // If the table doesn't exist at all, or a selected column is missing,
      // this SELECT will fail. We catch it and proceed as if no old data exists.
      print('DEBUG: Could not retrieve old data (table might not exist or old schema): $e');
      // No oldRows means we'll just create a fresh table.
    }


    // 2. Drop the old table (if it exists)
    db.execute('DROP TABLE IF EXISTS orders');
    print('DEBUG: Old table dropped (if existed).');

    // 3. Create the new table with the LATEST schema
    _createTable(); // This uses the CREATE TABLE IF NOT EXISTS statement with 'tax'
    print('DEBUG: New table created with latest schema.');

    // 4. Re-insert the old data into the new table
    if (oldRows.isNotEmpty) {
      for (var oldRow in oldRows) {
        // When inserting, provide default values for new columns (like 'tax')
        // if they weren't present in the old data.
        insertOrder(
          orderId: oldRow['order_id'] as String,
          total: (oldRow['total'] as num?)?.toDouble() ?? 0.0,
          tax: (oldRow['tax'] as num?)?.toDouble() ?? 0.0, // This will be 0.0 if 'tax' wasn't in oldRow
          customerName: oldRow['customer_name'] as String? ?? 'Guest',
          customerPhone: oldRow['customer_phone'] as String? ?? '',
          paymentMethod: oldRow['payment_method'] as String? ?? 'Unknown',
          paidAmount: (oldRow['paid_amount'] as num?)?.toDouble() ?? 0.0,
          changeAmount: (oldRow['change_amount'] as num?)?.toDouble() ?? 0.0,
          discount: (oldRow['discount'] as num?)?.toDouble() ?? 0.0,
          date: oldRow['date'] as String?,
        );
      }
      print('DEBUG: Re-inserted ${oldRows.length} old orders.');
    } else {
      print('DEBUG: No old data to re-insert.');
    }

    print('✅ Orders table recreated/migrated with distinct order_id and updated schema.');
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
        tax, // Value for the 'tax' column is now guaranteed to be provided
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
    // Make sure this SELECT also lists all columns in the order expected by the print statement.
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
        '₹${(row['tax'] ?? 0.0).toStringAsFixed(2).padRight(6)} | ' // Access 'tax'
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
    // Explicitly list all columns to avoid issues if schema changes drastically later
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
}