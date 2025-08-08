// This is a conceptual example for sqlite3.
// NOT RECOMMENDED FOR TYPICAL FLUTTER MOBILE APP USE CASES.
import 'package:sqlite3/sqlite3.dart' as sqlite;
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

class CreditDbHelperRawSqlite {
  static sqlite.Database? _database;
  static final CreditDbHelperRawSqlite _instance = CreditDbHelperRawSqlite._internal();

  factory CreditDbHelperRawSqlite() {
    return _instance;
  }

  CreditDbHelperRawSqlite._internal();

  Future<sqlite.Database> get database async {
    if (_database != null) {
      return _database!;
    }
    _database = await _initDatabase();
    return _database!;
  }

  Future<sqlite.Database> _initDatabase() async {
    final documentsDirectory = await getApplicationDocumentsDirectory();
    final path = join(documentsDirectory.path, 'credit_customers_raw.db');

    // Delete existing database file to force schema recreation
    final file = File(path);
  
    // Open the database
    final db = sqlite.sqlite3.open(path);

 db.execute('''
      CREATE TABLE IF NOT EXISTS credit_customers(
        request_id INTEGER PRIMARY KEY,
        name TEXT,
        phone TEXT,
        status TEXT,
        requested REAL,
        approved REAL,
        approved_days INTEGER, -- Renamed from 'days' to 'approved_days'
        days_requested INTEGER,
        requestedDate TEXT,
        approvedDate TEXT
      )
    ''');
    return db;
  }

  Future<void> insertCustomers(List<Map<String, dynamic>> customers) async {
    final db = await database;
    try {
      db.execute('BEGIN TRANSACTION');
      // Clear existing data to ensure local database reflects latest server state
      db.execute('DELETE FROM credit_customers');

      final stmt = db.prepare('''
        INSERT OR REPLACE INTO credit_customers(
          request_id, name, phone, status, requested, approved, approved_days, days_requested, requestedDate, approvedDate
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      ''');

      for (var customer in customers) {
        stmt.execute([
          customer['request_id'],
          customer['name'],
          customer['phone'],
          customer['status'],
          customer['requested'] is String
              ? (double.tryParse(customer['requested'].replaceAll('₹', '')) ?? 0.0)
              : customer['requested'],
          customer['approved'] is String
              ? (double.tryParse(customer['approved'].replaceAll('₹', '')) ?? 0.0)
              : customer['approved'],
          customer['days'] is String // Still using 'days' key from customer map for approved_days value
              ? (int.tryParse(customer['days']) ?? 0)
              : customer['days'],
          customer['days_requested'] is String
              ? (int.tryParse(customer['days_requested']) ?? 0)
              : customer['days_requested'],
          customer['requestedDate'],
          customer['approvedDate'],
        ]);
      }
      stmt.dispose(); // Important: dispose the statement to free resources
      db.execute('COMMIT');
    } catch (e) {
      db.execute('ROLLBACK'); // Rollback transaction on error
      rethrow; 
    }
  }

  Future<List<Map<String, dynamic>>> getCustomers() async {
    final db = await database;
    // Selecting all columns, including approved_days and days_requested
    final sqlite.ResultSet resultSet = db.select('SELECT * FROM credit_customers');
    final List<Map<String, dynamic>> customers = [];

    for (final row in resultSet) {
      customers.add({
        'request_id': row['request_id'],
        'name': row['name'],
        'phone': row['phone'],
        'status': row['status'],
        'requested': (row['requested'] as double).toStringAsFixed(2),
        'approved': (row['approved'] as double).toStringAsFixed(2),
        'days': (row['approved_days'] as int).toString(), // Retrieve from 'approved_days' column, map to 'days' key for consistency with CreditCustomersPage
        'days_requested': (row['days_requested'] as int).toString(),
        'requestedDate': row['requestedDate'],
        'approvedDate': row['approvedDate'],
      });
    }
    return customers;
  }

  Future<void> updateCustomerCredit(int requestId, double newAmount, int newDays) async {
    final db = await database;
    // Update the 'approved_days' column
    final stmt = db.prepare('''
      UPDATE credit_customers
      SET approved = ?, approved_days = ?, approvedDate = ?, status = ?
      WHERE request_id = ?
    ''');
    stmt.execute([
      newAmount,
      newDays,
      DateTime.now().toIso8601String(),
      'approved',
      requestId,
    ]);
    stmt.dispose();
  }

  Future<void> deleteAllCustomers() async {
    final db = await database;
    db.execute('DELETE FROM credit_customers');
  }

  Future<void> close() async {
    if (_database != null) {
      _database!.dispose();
      _database = null;
    }
  }
}