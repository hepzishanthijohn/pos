import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';

class CategorySQLiteHelper {
  late final Database db;

  Future<void> init() async {
    final dir = await getApplicationDocumentsDirectory();
    final dbPath = p.join(dir.path, 'categories.db');
    db = sqlite3.open(dbPath);

    db.execute('''
      CREATE TABLE IF NOT EXISTS categories (
        id INTEGER PRIMARY KEY,
        name TEXT,
        display_name TEXT,
        sequence INTEGER
      );
    ''');
  }

  Future<void> insertCategories(List<Map<String, dynamic>> categories) async {
    db.execute('DELETE FROM categories;');
    final stmt = db.prepare('''
      INSERT INTO categories (id, name, display_name, sequence)
      VALUES (?, ?, ?, ?);
    ''');

    db.execute('BEGIN TRANSACTION;');
    for (final cat in categories) {
      stmt.execute([
        cat['id'],
        cat['name'],
        cat['display_name'],
        cat['sequence']
      ]);
    }
    db.execute('COMMIT;');
    stmt.dispose();
  }
void debugPrintAllCategories() {
  final result = db.select('SELECT * FROM categories ORDER BY sequence ASC');

  if (result.isEmpty) {
    print('❌ No category data found in SQLite.');
    return;
  }

  print('📂 SQLite3 Category Data (Formatted Table):');
  print('| ID  | Name            | Display Name      | Sequence |');
  print('|-----|------------------|--------------------|----------|');

  for (final row in result) {
    final id = row['id'].toString().padRight(4);
    final name = (row['name'] ?? '').toString().padRight(16).substring(0, 16);
    final displayName = (row['display_name'] ?? '').toString().padRight(18).substring(0, 18);
    final sequence = row['sequence'].toString().padRight(8);

    print('| $id | $name | $displayName | $sequence |');
  }
}

  List<Map<String, dynamic>> fetchCategories() {
    final result = db.select('SELECT * FROM categories ORDER BY sequence ASC');

    return result.map((row) => {
      'id': row['id'],
      'name': row['name'],
      'display_name': row['display_name'],
      'sequence': row['sequence'],
    }).toList();
  }

  void close() {
    db.dispose();
  }
}
