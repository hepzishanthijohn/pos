import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';

class SQLiteHelper {
  late final Database db;

Future<void> init() async {
  final dir = await getApplicationDocumentsDirectory();
  final dbPath = p.join(dir.path, 'pos_config.db');
  db = sqlite3.open(dbPath);

  // Create the table if it doesn't exist
  db.execute('''
    CREATE TABLE IF NOT EXISTS pos_configs (
      id INTEGER PRIMARY KEY,
      name TEXT,
      shop_addrs TEXT,
      last_session_closing_cash REAL,
      last_session_closing_date TEXT,
      current_session_state INTEGER
    );
  ''');

  // ✅ Safe schema migration: Add `synced_at` if not exists
  try {
    db.execute("ALTER TABLE pos_configs ADD COLUMN synced_at TEXT;");
    print("✅ Column 'synced_at' added");
  } catch (e) {
    // Ignore error if the column already exists
    print("ℹ️ Column 'synced_at' already exists or alter failed: $e");
  }
}


void debugPrintAllConfigs() {
  final result = db.select('SELECT * FROM pos_configs;');

  if (result.isEmpty) {
    print('❌ No POS config data found in SQLite.');
    return;
  }

  print('📦 SQLite3 POS Config Data (Formatted Table):');
  print(
      '| ID  | Name                 | Journal ID | Pricelist ID | Sync Time             |');
  print(
      '|-----|----------------------|------------|--------------|------------------------|');

  for (final row in result) {
    final id = row['id'];
    final name = (row['name'] ?? '').toString().padRight(20).substring(0, 20);
    final journalId = row['journal_id']?.toString().padRight(10) ?? ''.padRight(10);
    final pricelistId = row['pricelist_id']?.toString().padRight(12) ?? ''.padRight(12);
    final syncedAt = (row['synced_at'] ?? '').toString().padRight(22).substring(0, 22);

    print('| ${id.toString().padRight(4)} | $name | $journalId | $pricelistId | $syncedAt |');
  }
}

 
 
 
  Future<void> insertConfigs(List<Map<String, dynamic>> configs) async {
    // Clear old configs
    db.execute('DELETE FROM pos_configs;');

  final now = DateTime.now().toIso8601String();

final stmt = db.prepare('''
  INSERT INTO pos_configs (
    id, name, shop_addrs, last_session_closing_cash,
    last_session_closing_date, current_session_state, synced_at
  ) VALUES (?, ?, ?, ?, ?, ?, ?);
''');

db.execute('BEGIN TRANSACTION;');
for (final config in configs) {
  stmt.execute([
    config['id'],
    config['name'],
    config['shop_addrs'],
    config['last_session_closing_cash'],
    config['last_session_closing_date'],
    config['current_session_state'] == true ? 1 : 0,
    now  // ⏱ synced_at
  ]);
}
db.execute('COMMIT;');


    stmt.dispose();
  }

List<Map<String, dynamic>> fetchConfigs() {
  final result = db.select('SELECT * FROM pos_configs;');

  return result.map((row) {
    return {
      'id': row['id'],
      'name': row['name'],
      'shop_addrs': row['shop_addrs'],
      'last_session_closing_cash': row['last_session_closing_cash'],
      'last_session_closing_date': row['last_session_closing_date'],
      'current_session_state': row['current_session_state'] == 1,
      'synced_at': row['synced_at'],  // 🆕 Include timestamp
    };
  }).toList();
}

  void close() {
    db.dispose();
  }
}
