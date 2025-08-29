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

class SeedDefaultTransactionTypesMigration implements Migration {
  @override
  int get id => 8;

  @override
  String get name => 'seed_default_transaction_types';

  @override
  Future<void> up(sqlite.Database db) async {
    void insert(String name, String color, String iconKind, String iconValue, String appliesTo) {
      db.execute(
        'INSERT OR IGNORE INTO transaction_types (name, color, icon_kind, icon_value, applies_to) VALUES (?, ?, ?, ?, ?)',
        [name, color, iconKind, iconValue, appliesTo],
      );
    }

    // Common outbound (expenses)
    insert('Groceries', '#4CAF50', 'material', 'shopping_cart', 'outbound');
    insert('Rent', '#9C27B0', 'material', 'home', 'outbound');
    insert('Utilities', '#03A9F4', 'material', 'bolt', 'outbound');
    insert('Dining', '#FF7043', 'material', 'restaurant', 'outbound');
    insert('Transport', '#795548', 'material', 'directions_car', 'outbound');

    // Common inbound (income)
    insert('Work', '#1565C0', 'material', 'work', 'inbound');
    insert('Gift', '#F06292', 'material', 'card_giftcard', 'inbound');
    insert('Investments', '#2E7D32', 'material', 'show_chart', 'inbound');

    // Transfer
    insert('Transfer', '#607D8B', 'material', 'compare_arrows', 'internal');
  }
}
class CreateTransactionTypesMigration implements Migration {
  @override
  int get id => 6;

  @override
  String get name => 'create_transaction_types_table';

  @override
  Future<void> up(sqlite.Database db) async {
    db.execute('''
      CREATE TABLE IF NOT EXISTS transaction_types (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL UNIQUE,
        color TEXT NOT NULL,
        icon_kind TEXT NOT NULL CHECK(icon_kind IN ('material','emoji')),
        icon_value TEXT NOT NULL,
        applies_to TEXT NOT NULL DEFAULT 'any' CHECK(applies_to IN ('any','inbound','outbound','internal')),
        created_at TEXT NOT NULL DEFAULT (datetime('now'))
      );
    ''');
  }
}

class CreateTransactionsMigration implements Migration {
  @override
  int get id => 7;

  @override
  String get name => 'create_transactions_table';

  @override
  Future<void> up(sqlite.Database db) async {
    db.execute('''
      CREATE TABLE IF NOT EXISTS transactions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        kind TEXT NOT NULL CHECK(kind IN ('inbound','outbound','internal')),
        -- For inbound/outbound
        account_id INTEGER NULL,
        amount INTEGER NULL,
        -- For internal transfers
        from_account_id INTEGER NULL,
        to_account_id INTEGER NULL,
        out_amount INTEGER NULL,
        in_amount INTEGER NULL,
        -- Optional linkage
        type_id INTEGER NULL,
        description TEXT NULL,
        occurred_at TEXT NOT NULL,
        created_at TEXT NOT NULL DEFAULT (datetime('now')),

        -- Basic relational intent (not enforced if PRAGMA foreign_keys=OFF)
        FOREIGN KEY(account_id) REFERENCES accounts(id),
        FOREIGN KEY(from_account_id) REFERENCES accounts(id),
        FOREIGN KEY(to_account_id) REFERENCES accounts(id),
        FOREIGN KEY(type_id) REFERENCES transaction_types(id),

        -- Shape constraints to ensure valid combinations per kind
        CHECK(
          (kind = 'inbound' AND account_id IS NOT NULL AND amount IS NOT NULL AND from_account_id IS NULL AND to_account_id IS NULL AND out_amount IS NULL AND in_amount IS NULL)
          OR
          (kind = 'outbound' AND account_id IS NOT NULL AND amount IS NOT NULL AND from_account_id IS NULL AND to_account_id IS NULL AND out_amount IS NULL AND in_amount IS NULL)
          OR
          (kind = 'internal' AND account_id IS NULL AND from_account_id IS NOT NULL AND to_account_id IS NOT NULL AND from_account_id <> to_account_id AND (
              (amount IS NOT NULL AND out_amount IS NULL AND in_amount IS NULL) OR
              (amount IS NULL AND out_amount IS NOT NULL AND in_amount IS NOT NULL)
          ))
        )
      );
    ''');

    // Useful indices
    db.execute("CREATE INDEX IF NOT EXISTS idx_transactions_occurred_at ON transactions(occurred_at DESC)");
    db.execute("CREATE INDEX IF NOT EXISTS idx_transactions_account ON transactions(account_id)");
    db.execute("CREATE INDEX IF NOT EXISTS idx_transactions_from_to ON transactions(from_account_id, to_account_id)");
    db.execute("CREATE INDEX IF NOT EXISTS idx_transactions_type ON transactions(type_id)");
  }
}
