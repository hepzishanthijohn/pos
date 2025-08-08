import 'dart:convert';

import 'package:sqlite3/sqlite3.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'dart:io';

class posConfigSQLiteHelper {
  static final posConfigSQLiteHelper instance = posConfigSQLiteHelper._privateConstructor();
  static Database? _db;

  posConfigSQLiteHelper._privateConstructor();

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDB();
    return _db!;
  }

  Future<Database> _initDB() async {
    final documentsDir = await getApplicationDocumentsDirectory();
    final path = p.join(documentsDir.path, 'posconfig.db');
    final db = sqlite3.open(path);

    db.execute('''
      CREATE TABLE IF NOT EXISTS pos_config (
    id INTEGER PRIMARY KEY,
    name TEXT,
    shop_phone_no TEXT,
    shop_code TEXT,
    shop_addrs TEXT,
    last_session_closing_cash REAL,
    last_session_closing_date TEXT,
    current_session_state INTEGER,
    shop_gst_no TEXT,
    shop_admin_ids TEXT, 
    shop_owner_name TEXT
  )
    ''');

    return db;
  }

  // 🔁 Insert multiple configs
// Corrected insertConfigs method
Future<void> insertConfigs(List<Map<String, dynamic>> configs) async {
  final db = await database;

  for (final config in configs) {
    // ... (Your existing logic for localSessionState, shopAdminIdsJson, and shopOwnerName is correct and can be reused here)
    final local = db.select('SELECT current_session_state FROM pos_config WHERE id = ?', [config['id']]);
    int localSessionState = 0;
    if (local.isNotEmpty) {
      final value = local.first['current_session_state'];
      if (value != null) {
        localSessionState = value is int ? value : (value == 1 || value == '1' || value == true || value == 'opened' ? 1 : 0);
      }
    }

   String shopAdminIdsJson = jsonEncode(config['shop_admin_ids']);
    String shopOwnerName = '';
    final dynamic adminIds = config['shop_admin_ids'];
    if (adminIds is List && adminIds.isNotEmpty && adminIds.first is Map) {
      final ownerMap = adminIds.first as Map;
      shopOwnerName = ownerMap['name']?.toString() ?? 'Unknown';
    } else {
      shopOwnerName = 'Unknown';
    }

    // Handle current_session_state
    final dynamic stateValue = config['current_session_state'];
    int sessionState = stateValue is bool ? (stateValue ? 1 : 0) : (stateValue.toString() == 'opened' || stateValue.toString() == '1' ? 1 : 0);
    final finalSessionState = localSessionState != 0 ? localSessionState : sessionState;


    db.execute('''
      INSERT OR REPLACE INTO pos_config (
        id, name, shop_phone_no, shop_code, shop_addrs, last_session_closing_cash,
        last_session_closing_date, current_session_state, shop_gst_no,
        shop_admin_ids, shop_owner_name
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    ''', [
      int.tryParse(config['id'].toString()) ?? 0,
      config['name']?.toString() ?? '',
      config['shop_phone_no']?.toString() ?? '',
      config['shop_code']?.toString() ?? '',
      config['shop_addrs']?.toString() ?? '',
      double.tryParse(config['last_session_closing_cash'].toString()) ?? 0.0,
      config['last_session_closing_date']?.toString() ?? '',
      finalSessionState,
      config['shop_gst_no']?.toString() ?? '',
      shopAdminIdsJson, // This is value 10
      shopOwnerName,    // This is value 11
    ]);
  }
}
Future<List<Map<String, dynamic>>> getAllConfigs() async {
  final db = await database;
  final result = db.select('SELECT * FROM pos_config');

  // Convert each row to Map manually
  return result.map((row) {
    return {
      'id': row['id'],
      'name': row['name'],
      'shop_phone_no': row['shop_phone_no'],
      'shop_code': row['shop_code'],
      'shop_addrs': row['shop_addrs'],
      'last_session_closing_cash': row['last_session_closing_cash'],
      'last_session_closing_date': row['last_session_closing_date'],
      'current_session_state': row['current_session_state'],
      'shop_gst_no': row['shop_gst_no'],
      'shop_admin_ids': row['shop_admin_ids'],
      'shop_owner_name': row['shop_owner_name'],
    };
  }).toList();
}

Future<Map<String, dynamic>?> getConfigById(int id) async {
  final db = await database;
  final result = db.select('SELECT * FROM pos_config WHERE id = ? LIMIT 1', [id]);
  if (result.isEmpty) return null;
  final row = result.first;
  return {
    'id': row['id'],
    'name': row['name'],
    'current_session_state': row['current_session_state'],
    // add other fields as needed
  };
}

  // ❌ Optional: clear all
  Future<void> clearConfigs() async {
    final db = await database;
    db.execute('DELETE FROM pos_config');
  }


void _printLocalPOSConfigs() async {
  try {
    final configs = await posConfigSQLiteHelper.instance.getAllConfigs();

    for (var config in configs) {
      print('--- POS Config ---');
      print('ID: ${config['id']}');
      print('Name: ${config['name']}');
      print('Phone: ${config['shop_phone_no']}');
      print('Code: ${config['shop_code']}');
      print('Address: ${config['shop_addrs']}');
      print('Closing Cash: ${config['last_session_closing_cash']}');
      print('Closing Date: ${config['last_session_closing_date']}');
      print('Session State: ${config['current_session_state']}');
      print('GST No: ${config['shop_gst_no']}');
      print('Owner ID: ${config['shop_admin_ids']}');
      print('Owner Name: ${config['shop_owner_name']}');
    }

    if (configs.isEmpty) {
      print('⚠️ No POS config data found in local database.');
    }
  } catch (e) {
    print('❌ Error printing POS configs: $e');
  }
}
Future<void> printLocalPOSConfigs() async {
  final configs = await getAllConfigs();
  for (var config in configs) {
    print(config);
  }
}

  // New method to update session state and last_session_closing_cash for a config by id
Future<void> updateSessionState(int id, int state) async {
  final db = await database;  // Use `await database` to ensure DB is initialized
  db.execute(
    'UPDATE pos_config SET current_session_state = ? WHERE id = ?',
    [state, id],
  );
}
Future<void> updateClosingCashAndDate(int id, double cash, DateTime date) async {
  final db = await database;
  final dateString = date.toIso8601String();
  db.execute(
    'UPDATE pos_config SET last_session_closing_cash = ?, last_session_closing_date = ? WHERE id = ?',
    [cash, dateString, id],
  );
}

Future<void> deleteDatabaseFile() async {
  final documentsDir = await getApplicationDocumentsDirectory();
  final path = p.join(documentsDir.path, 'posconfig.db');

  final file = File(path);
  if (await file.exists()) {
    await file.delete();
    print('✅ posconfig.db deleted successfully.');
  } else {
    print('ℹ️ posconfig.db not found at: $path');
  }
}
  Future<void> deleteAllConfigs() async {
    final db = await database;
    db.execute('DELETE FROM pos_config');
  }

  Future<void> closeDatabase() async {
    if (_db != null) {
      _db!.dispose();
      _db = null;
    }
  }


}
