import 'package:sqlite3/sqlite3.dart' as sqlite;

class TransactionTypeRow {
  final int id;
  final String name;
  final String color; // hex like #RRGGBB
  final String iconKind; // 'material' | 'emoji'
  final String iconValue; // material icon name or emoji char(s)
  final String appliesTo; // 'any' | 'inbound' | 'outbound' | 'internal'

  TransactionTypeRow({
    required this.id,
    required this.name,
    required this.color,
    required this.iconKind,
    required this.iconValue,
    required this.appliesTo,
  });
}

class TransactionTypesRepository {
  final sqlite.Database db;
  TransactionTypesRepository(this.db);

  List<TransactionTypeRow> listAll() {
    final result = db.select(
      'SELECT id, name, color, icon_kind, icon_value, applies_to FROM transaction_types ORDER BY name ASC',
    );
    return [
      for (final row in result)
        TransactionTypeRow(
          id: row['id'] as int,
          name: row['name'] as String,
          color: row['color'] as String,
          iconKind: row['icon_kind'] as String,
          iconValue: row['icon_value'] as String,
          appliesTo: row['applies_to'] as String,
        ),
    ];
  }

  TransactionTypeRow? getById(int id) {
    final result = db.select(
      'SELECT id, name, color, icon_kind, icon_value, applies_to FROM transaction_types WHERE id = ? LIMIT 1',
      [id],
    );
    if (result.isEmpty) return null;
    final row = result.first;
    return TransactionTypeRow(
      id: row['id'] as int,
      name: row['name'] as String,
      color: row['color'] as String,
      iconKind: row['icon_kind'] as String,
      iconValue: row['icon_value'] as String,
      appliesTo: row['applies_to'] as String,
    );
  }

  int create({
    required String name,
    required String color,
    required String iconKind,
    required String iconValue,
    String appliesTo = 'any',
  }) {
    final stmt = db.prepare(
      'INSERT INTO transaction_types (name, color, icon_kind, icon_value, applies_to) VALUES (?, ?, ?, ?, ?)',
    );
    try {
      stmt.execute([name, color, iconKind, iconValue, appliesTo]);
    } finally {
      stmt.dispose();
    }
    return db.lastInsertRowId;
  }

  void update({
    required int id,
    required String name,
    required String color,
    required String iconKind,
    required String iconValue,
    required String appliesTo,
  }) {
    db.execute(
      'UPDATE transaction_types SET name = ?, color = ?, icon_kind = ?, icon_value = ?, applies_to = ? WHERE id = ?',
      [name, color, iconKind, iconValue, appliesTo, id],
    );
  }

  void delete(int id) {
    db.execute('DELETE FROM transaction_types WHERE id = ?', [id]);
  }
}

