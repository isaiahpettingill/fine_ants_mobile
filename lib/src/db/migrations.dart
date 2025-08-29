import 'dart:async';

import 'package:sqlite3/sqlite3.dart' as sqlite;

abstract class Migration {
  int get id;
  String get name;
  FutureOr<void> up(sqlite.Database db);
}

class MigrationRunner {
  final sqlite.Database db;
  MigrationRunner(this.db);

  void _ensureMigrationsTable() {
    db.execute('''
      CREATE TABLE IF NOT EXISTS schema_migrations (
        id INTEGER PRIMARY KEY,
        name TEXT NOT NULL,
        applied_at TEXT NOT NULL DEFAULT (datetime('now'))
      );
    ''');
  }

  Future<void> applyAll(List<Migration> migrations) async {
    _ensureMigrationsTable();
    final applied = <int>{};
    final stmt = db.prepare('SELECT id FROM schema_migrations');
    try {
      final result = stmt.select();
      for (final row in result) {
        applied.add(row['id'] as int);
      }
    } finally {
      stmt.dispose();
    }

    migrations.sort((a, b) => a.id.compareTo(b.id));
    for (final m in migrations) {
      if (applied.contains(m.id)) continue; // idempotent
      db.execute('BEGIN');
      try {
        await Future.sync(() => m.up(db));
        db.execute(
          'INSERT INTO schema_migrations (id, name) VALUES (?, ?)',
          [m.id, m.name],
        );
        db.execute('COMMIT');
      } catch (_) {
        db.execute('ROLLBACK');
        rethrow;
      }
    }
  }
}

class CreateAccountsMigration implements Migration {
  @override
  int get id => 1;

  @override
  String get name => 'create_accounts_table';

  @override
  Future<void> up(sqlite.Database db) async {
    db.execute('''
      CREATE TABLE IF NOT EXISTS accounts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        icon TEXT NOT NULL,
        color TEXT NOT NULL,
        created_at TEXT NOT NULL DEFAULT (datetime('now'))
      );
    ''');
  }
}

class AddAccountTypeToAccountsMigration implements Migration {
  @override
  int get id => 2;

  @override
  String get name => 'add_account_type_to_accounts';

  bool _columnExists(sqlite.Database db, String table, String column) {
    final result = db.select("PRAGMA table_info($table)");
    for (final row in result) {
      final name = row['name'] as String?;
      if (name == column) return true;
    }
    return false;
  }

  @override
  Future<void> up(sqlite.Database db) async {
    if (!_columnExists(db, 'accounts', 'account_type')) {
      db.execute("ALTER TABLE accounts ADD COLUMN account_type TEXT NOT NULL DEFAULT ''");
    }
  }
}

class CreateCurrenciesMigration implements Migration {
  @override
  int get id => 3;

  @override
  String get name => 'create_currencies_table';

  @override
  Future<void> up(sqlite.Database db) async {
    db.execute('''
      CREATE TABLE IF NOT EXISTS currencies (
        code TEXT PRIMARY KEY,
        symbol TEXT NULL,
        symbol_position TEXT NOT NULL DEFAULT 'before',
        decimal_places INTEGER NOT NULL DEFAULT 2
      );
    ''');
  }
}

class SeedCurrenciesMigration implements Migration {
  @override
  int get id => 4;

  @override
  String get name => 'seed_currencies';

  @override
  Future<void> up(sqlite.Database db) async {
    void insert(String code, String? symbol, String pos, int decimals) {
      db.execute(
        'INSERT OR IGNORE INTO currencies (code, symbol, symbol_position, decimal_places) VALUES (?, ?, ?, ?)',
        [code, symbol, pos, decimals],
      );
    }

    // Fiat presets
    insert('USD', '\$', 'before', 2);
    insert('EUR', '€', 'before', 2);
    insert('MXN', 'MX\$', 'before', 2);
    insert('CAD', 'CA\$', 'before', 2);

    // Crypto presets (symbol null)
    insert('BTC', null, 'before', 8);
    insert('ETH', null, 'before', 8);
    insert('XRP', null, 'before', 6);
  }
}

class AddCurrencyToAccountsMigration implements Migration {
  @override
  int get id => 5;

  @override
  String get name => 'add_currency_to_accounts';

  bool _columnExists(sqlite.Database db, String table, String column) {
    final result = db.select("PRAGMA table_info($table)");
    for (final row in result) {
      final name = row['name'] as String?;
      if (name == column) return true;
    }
    return false;
  }

  @override
  Future<void> up(sqlite.Database db) async {
    if (!_columnExists(db, 'accounts', 'currency_code')) {
      db.execute("ALTER TABLE accounts ADD COLUMN currency_code TEXT NULL");
    }
  }
}
