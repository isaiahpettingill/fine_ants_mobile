import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite3;

class DatabaseManager {
  /// Returns a Drift [QueryExecutor] for the given database file path.
  static QueryExecutor openExecutor(String dbFilePath) {
    return NativeDatabase(File(dbFilePath));
  }

  /// Creates an empty, valid SQLite database file at [dbFilePath].
  /// This does not create any tables; it only initializes a valid DB header.
  static Future<void> createEmptyDatabaseAt(String dbFilePath) async {
    final file = File(dbFilePath);
    final dir = file.parent;
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    final db = sqlite3.sqlite3.open(dbFilePath);
    // Touch the file by setting a pragma to ensure a write happens.
    db.execute('PRAGMA user_version = 1;');
    db.dispose();
  }

  /// Suggests a default path for a new account database file.
  static Future<String> suggestDefaultDbPath(String accountId) async {
    final supportDir = await getApplicationSupportDirectory();
    final folder = p.join(supportDir.path, 'accounts', accountId);
    return p.join(folder, 'fine_ants.db');
  }
}

