import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';

class Customersqlitehelper {
  late final Database db;

  Future<void> init() async {
    final dir = await getApplicationDocumentsDirectory();
    final dbPath = p.join(dir.path, 'customers.db'); // Optional: separate file
    db = sqlite3.open(dbPath);

    db.execute('''
    CREATE TABLE IF NOT EXISTS customers (
      id INTEGER PRIMARY KEY,
      name TEXT,
      email TEXT,
      phone TEXT,
      contact_address TEXT,
      company_type TEXT,
      synced_at TEXT
    );
  ''');

  }

Future<void> insertCustomers(List<Map<String, dynamic>> customers) async {
  db.execute('DELETE FROM customers;'); // optional: clear old data

  final now = DateTime.now().toIso8601String();
  final stmt = db.prepare('''
    INSERT INTO customers (
      id, name, email, phone, contact_address, company_type, synced_at
    ) VALUES (?, ?, ?, ?, ?, ?, ?);
  ''');

  db.execute('BEGIN TRANSACTION;');
  for (final c in customers) {
    stmt.execute([
      c['id'],
      c['name'],
      c['email'] is String ? c['email'] : null,
      c['phone'],
      c['contact_address'],
      c['company_type'],
      now
    ]);
  }
  db.execute('COMMIT;');
  stmt.dispose();
}
List<Map<String, dynamic>> fetchCustomers() {
  final result = db.select('SELECT * FROM customers;');
  return result.map((row) => {
    'id': row['id'],
    'name': row['name'],
    'email': row['email'],
    'phone': row['phone'],
    'contact_address': row['contact_address'],
    'company_type': row['company_type'],
    'synced_at': row['synced_at'],
  }).toList();
}

 void debugPrintAllCustomers() {
  final result = db.select('SELECT * FROM customers;');

  if (result.isEmpty) {
    print('❌ No customer data found in SQLite.');
    return;
  }

  print('📦 SQLite3 Customer Data (Formatted Table):');
  print(
      '| ID | Name                 | Email                  | Phone        | Company Type |');
  print(
      '|----|----------------------|------------------------|--------------|--------------|');

  for (final row in result) {
    final id = row['id'];
    final name = (row['name'] ?? '').toString().padRight(20).substring(0, 20);
    final email = (row['email'] ?? '').toString().padRight(22).substring(0, 22);
    final phone = (row['phone'] ?? '').toString().padRight(12).substring(0, 12);
    final type = (row['company_type'] ?? '').toString().padRight(12).substring(0, 12);

    print('| $id | $name | $email | $phone | $type |');
  }
}


  void close() {
    db.dispose();
  }
}
