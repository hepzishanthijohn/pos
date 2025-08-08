import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'package:rcspos/screens/customerpage.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:http/http.dart' as http;



class Customersqlitehelper {
  static final Customersqlitehelper instance = Customersqlitehelper._privateConstructor();

  static Database? _db;
  String? _dbPath;

  Customersqlitehelper._privateConstructor();

  /// Initialize the local database
  Future<void> init() async {
    if (_db != null) return;

    final dir = await getApplicationDocumentsDirectory();
    final path = p.join(dir.path, 'customers.db');
    print("🗂 DB Path: $path");

    _dbPath = path;
    _db = sqlite3.open(path);

    print("✅ DB opened");

    _db!.execute('''
      CREATE TABLE IF NOT EXISTS customers (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        remote_id INTEGER,
        name TEXT NOT NULL,
        email TEXT,
        phone TEXT,
        contact_address TEXT,
        company_type TEXT,
        is_synced INTEGER DEFAULT 0,
        synced_at TEXT
      );
    ''');

    print("✅ customers table created (if not exists)");
  }
 Future<void> insertCustomers(List<Map<String, dynamic>> customers) async {
    final now = DateTime.now().toIso8601String();
    _db!.execute('BEGIN TRANSACTION;');
    try {
      for (final customer in customers) {
        await upsertCustomer(customer, now);
      }
      _db!.execute('COMMIT;');
    } catch (e) {
      _db!.execute('ROLLBACK;');
      rethrow;
    }
  }
  /// Insert customers from API (upsert)
 Future<void> syncCustomersApi(String jsonData) async {
    final decoded = json.decode(jsonData);
    final List<dynamic>? result = decoded['result'];
    if (result == null) {
      print('syncCustomersApi: No "result" key in JSON data');
      return;
    }

    // Convert to List<Map<String, dynamic>>
    final customersList = result.cast<Map<String, dynamic>>();

    await insertCustomers(customersList);
  }



  /// Insert or update customer by remote_id or phone in the DB
   Future<void> upsertCustomer(Map<String, dynamic> customer, String now) async {
    final remoteId = customer['id'];
    final phone = customer['phone'];

    if (remoteId != null) {
      final stmt = _db!.prepare('SELECT id FROM customers WHERE remote_id = ?;');
      final result = stmt.select([remoteId]);
      stmt.dispose();

      if (result.isNotEmpty) {
        final updateStmt = _db!.prepare('''
          UPDATE customers SET name = ?, email = ?, phone = ?, contact_address = ?, company_type = ?, is_synced = 1, synced_at = ?
          WHERE remote_id = ?;
        ''');
        updateStmt.execute([
          customer['name'],
          customer['email'] is String ? customer['email'] : null,
          phone,
          customer['contact_address'],
          customer['company_type'],
          now,
          remoteId,
        ]);
        updateStmt.dispose();
        return;
      }
    }

    if (phone != null) {
      final stmt = _db!.prepare('SELECT id FROM customers WHERE phone = ?;');
      final result = stmt.select([phone]);
      stmt.dispose();

      if (result.isNotEmpty) {
        final updateStmt = _db!.prepare('''
          UPDATE customers SET remote_id = ?, name = ?, email = ?, contact_address = ?, company_type = ?, is_synced = 1, synced_at = ?
          WHERE phone = ?;
        ''');
        updateStmt.execute([
          remoteId,
          customer['name'],
          customer['email'] is String ? customer['email'] : null,
          customer['contact_address'],
          customer['company_type'],
          now,
          phone,
        ]);
        updateStmt.dispose();
        return;
      }
    }

    final insertStmt = _db!.prepare('''
      INSERT INTO customers (remote_id, name, email, phone, contact_address, company_type, is_synced, synced_at)
      VALUES (?, ?, ?, ?, ?, ?, 1, ?);
    ''');
    insertStmt.execute([
      remoteId,
      customer['name'],
      customer['email'] is String ? customer['email'] : null,
      phone,
      customer['contact_address'],
      customer['company_type'],
      now,
    ]);
    insertStmt.dispose();
  }

  /// Insert new unsynced local customer. Returns local DB id.
  Future<int> insertLocalCustomer(Map<String, dynamic> data) async {
    if (_db == null) throw Exception("DB not initialized");
    final now = DateTime.now().toIso8601String();
    final stmt = _db!.prepare('''
      INSERT INTO customers 
        (name, phone, email, contact_address, company_type, is_synced, synced_at)
      VALUES (?, ?, ?, ?, ?, 0, ?);
    ''');
    stmt.execute([
      data['name'],
      data['phone'],
      data['email'],
      data['contact_address'],
      data['company_type'],
      now,
    ]);
    stmt.dispose();

    final result = _db!.select('SELECT last_insert_rowid() AS id;');
    return result.first['id'] as int;
  }

  /// Fetch all customers from the local DB
  List<Map<String, dynamic>> fetchCustomers() {
    if (_db == null) throw Exception("DB not initialized");
    final result = _db!.select('SELECT * FROM customers;');
    return result.map((row) => {
      'id': row['id'],
      'remote_id': row['remote_id'],
      'name': row['name'],
      'email': row['email'],
      'phone': row['phone'],
      'contact_address': row['contact_address'],
      'company_type': row['company_type'],
      'is_synced': row['is_synced'],
      'synced_at': row['synced_at'],
    }).toList();
  }

  /// Fetch all unsynced customers (for upload)
List<Map<String, dynamic>> fetchUnsyncedCustomers() {
  if (_db == null) throw Exception("DB not initialized");
  final result = _db!.select('SELECT * FROM customers WHERE is_synced = 0;');
  return result.map((row) => {
    'id': row['id'],
    'name': row['name'],
    'email': row['email'],
    'phone': row['phone'],
    'contact_address': row['contact_address'],
    'company_type': row['company_type'],
  }).toList();
}


  /// Mark customer as synced after successful upload
Future<void> markCustomerAsSynced(int localId, int? remoteId) async {
  if (_db == null) throw Exception("DB not initialized");
  final now = DateTime.now().toIso8601String();
  final stmt = _db!.prepare('''
    UPDATE customers SET is_synced = 1, remote_id = ?, synced_at = ?
    WHERE id = ?;
  ''');
  stmt.execute([remoteId, now, localId]);
  stmt.dispose();
}


  /// Update local customer (typically after editing) with is_synced = 0 to force re-upload
  Future<void> updateLocalCustomer(int id, Map<String, dynamic> data) async {
    if (_db == null) throw Exception("DB not initialized");
    final now = DateTime.now().toIso8601String();
    final stmt = _db!.prepare('''
      UPDATE customers SET 
        name = ?, phone = ?, email = ?, contact_address = ?, company_type = ?, is_synced = 0, synced_at = ?
      WHERE id = ?;
    ''');
    stmt.execute([
      data['name'],
      data['phone'],
      data['email'],
      data['contact_address'],
      data['company_type'],
      now,
      id,
    ]);
    stmt.dispose();
  }

  /// Debug: print all customers in a formatted table in console
  void debugPrintAllCustomers() {
    if (_db == null) {
      print('DB not initialized');
      return;
    }
    final result = _db!.select('SELECT * FROM customers;');
    if (result.isEmpty) {
      print('❌ No customer data in database.');
      return;
    }

    print('📦 SQLite Customers Table:');
    print('| ID | Name | Email | Phone | Address | Type | Synced |');
    print('|----|------|-------|-------|---------|------|--------|');
    for (final row in result) {
      print(
          '| ${row['id']} | ${row['name']} | ${row['email']} | ${row['phone']} | ${row['contact_address']} | ${row['company_type']} | ${row['is_synced']} |');
    }
  }

  /// Dispose DB and free resources
  void close() {
    _db?.dispose();
    _db = null;
    _dbPath = null;
  }

  /// Return all customers as strong-typed list
  Future<List<Customer>> getAllCustomers() async {
    if (_db == null) throw Exception("DB not initialized");

    final result = _db!.select('SELECT * FROM customers;');
    return result.map((row) => Customer.fromMap(row)).toList();
  }

  Future<void> clearCustomersTable() async {
  _db?.execute('DELETE FROM customers;');
  print('All customer data cleared from table.');
}

}
