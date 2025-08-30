import 'package:sqlite3/sqlite3.dart' as sqlite;

class AccountRow {
  final int id;
  final String name;
  final String icon; // material icon name
  final String color; // hex string like #RRGGBB
  final String accountType; // e.g., savings, checking, etc.
  final String currencyCode; // e.g., USD, EUR, BTC

  AccountRow({
    required this.id,
    required this.name,
    required this.icon,
    required this.color,
    required this.accountType,
    required this.currencyCode,
  });
}

class AccountsRepository {
  final sqlite.Database db;
  AccountsRepository(this.db);

  List<AccountRow> listAll() {
    final result = db.select(
      'SELECT id, name, icon, color, account_type, currency_code FROM accounts ORDER BY id DESC',
    );
    return [
      for (final row in result)
        AccountRow(
          id: row['id'] as int,
          name: row['name'] as String,
          icon: row['icon'] as String,
          color: row['color'] as String,
          accountType: (row['account_type'] as String?) ?? '',
          currencyCode: (row['currency_code'] as String?) ?? 'USD',
        ),
    ];
  }

  int create({
    required String name,
    required String icon,
    required String color,
    required String accountType,
    required String currencyCode,
  }) {
    final stmt = db.prepare(
      'INSERT INTO accounts (name, icon, color, account_type, currency_code) VALUES (?, ?, ?, ?, ?)',
    );
    try {
      stmt.execute([name, icon, color, accountType, currencyCode]);
    } finally {
      stmt.dispose();
    }
    return db.lastInsertRowId;
  }

  void update({
    required int id,
    required String name,
    required String icon,
    required String color,
    required String accountType,
    required String currencyCode,
  }) {
    db.execute(
      'UPDATE accounts SET name = ?, icon = ?, color = ?, account_type = ?, currency_code = ? WHERE id = ?',
      [name, icon, color, accountType, currencyCode, id],
    );
  }

  void delete(int id) {
    db.execute('DELETE FROM accounts WHERE id = ?', [id]);
  }
}
