import 'package:sqlite3/sqlite3.dart' as sqlite;

class BudgetRow {
  final int id;
  final int typeId;
  final String period; // 'week' | 'month' | 'year'
  final String currencyCode; // e.g., USD
  final int amountMinor; // budget amount in minor units
  final DateTime effectiveFrom; // version effective start

  BudgetRow({
    required this.id,
    required this.typeId,
    required this.period,
    required this.currencyCode,
    required this.amountMinor,
    required this.effectiveFrom,
  });
}

class BudgetsRepository {
  final sqlite.Database db;
  BudgetsRepository(this.db);

  List<BudgetRow> listAll() {
    final rows = db.select(
      'SELECT id, type_id, period, currency_code, amount, effective_from FROM budgets ORDER BY datetime(effective_from) DESC, id DESC',
    );
    return [
      for (final r in rows)
        BudgetRow(
          id: r['id'] as int,
          typeId: r['type_id'] as int,
          period: r['period'] as String,
          currencyCode: r['currency_code'] as String,
          amountMinor: r['amount'] as int,
          effectiveFrom: DateTime.parse(r['effective_from'] as String),
        ),
    ];
  }

  /// Creates a new budget version effective from [effectiveFrom].
  int create({
    required int typeId,
    required String period,
    required String currencyCode,
    required int amountMinor,
    required DateTime effectiveFrom,
  }) {
    final stmt = db.prepare(
      'INSERT INTO budgets (type_id, period, currency_code, amount, effective_from) VALUES (?, ?, ?, ?, ?)',
    );
    try {
      stmt.execute([
        typeId,
        period,
        currencyCode,
        amountMinor,
        effectiveFrom.toIso8601String(),
      ]);
    } finally {
      stmt.dispose();
    }
    return db.lastInsertRowId;
  }

  void update({
    required int id,
    required int typeId,
    required String period,
    required String currencyCode,
    required int amountMinor,
  }) {
    db.execute(
      'UPDATE budgets SET type_id = ?, period = ?, currency_code = ?, amount = ? WHERE id = ?',
      [typeId, period, currencyCode, amountMinor, id],
    );
  }

  void delete(int id) {
    db.execute('DELETE FROM budgets WHERE id = ?', [id]);
  }

  /// Computes total outbound spend (minor units) for a budget in [start, end).
  int getSpentForBudgetInRange(
    BudgetRow b,
    DateTime start,
    DateTime endExclusive,
  ) {
    final rows = db.select(
      '''
      SELECT COALESCE(SUM(t.amount), 0) AS s
      FROM transactions t
      JOIN accounts a ON a.id = t.account_id
      WHERE t.kind = 'outbound'
        AND t.type_id = ?
        AND a.currency_code = ?
        AND datetime(t.occurred_at) >= datetime(?)
        AND datetime(t.occurred_at) < datetime(?)
      ''',
      [
        b.typeId,
        b.currencyCode,
        start.toIso8601String(),
        endExclusive.toIso8601String(),
      ],
    );
    return (rows.first['s'] as int?) ?? 0;
  }

  /// Computes total outbound spend for the given key within range.
  int getSpentForKeyInRange(
    int typeId,
    String currencyCode,
    DateTime start,
    DateTime endExclusive,
  ) {
    final rows = db.select(
      '''
      SELECT COALESCE(SUM(t.amount), 0) AS s
      FROM transactions t
      JOIN accounts a ON a.id = t.account_id
      WHERE t.kind = 'outbound'
        AND t.type_id = ?
        AND a.currency_code = ?
        AND datetime(t.occurred_at) >= datetime(?)
        AND datetime(t.occurred_at) < datetime(?)
      ''',
      [
        typeId,
        currencyCode,
        start.toIso8601String(),
        endExclusive.toIso8601String(),
      ],
    );
    return (rows.first['s'] as int?) ?? 0;
  }

  /// Returns the budget version effective at [onDate] for the given key.
  BudgetRow? getForDate({
    required int typeId,
    required String period,
    required String currencyCode,
    required DateTime onDate,
  }) {
    final rows = db.select(
      '''
      SELECT id, type_id, period, currency_code, amount, effective_from
      FROM budgets
      WHERE type_id = ? AND period = ? AND currency_code = ?
        AND datetime(effective_from) <= datetime(?)
      ORDER BY datetime(effective_from) DESC, id DESC
      LIMIT 1
      ''',
      [typeId, period, currencyCode, onDate.toIso8601String()],
    );
    if (rows.isEmpty) return null;
    final r = rows.first;
    return BudgetRow(
      id: r['id'] as int,
      typeId: r['type_id'] as int,
      period: r['period'] as String,
      currencyCode: r['currency_code'] as String,
      amountMinor: r['amount'] as int,
      effectiveFrom: DateTime.parse(r['effective_from'] as String),
    );
  }

  /// Lists the latest budget version per (type_id, period, currency_code).
  List<BudgetRow> listLatestPerKey() {
    final rows = db.select('''
      SELECT b.id, b.type_id, b.period, b.currency_code, b.amount, b.effective_from
      FROM budgets b
      JOIN (
        SELECT type_id, period, currency_code, MAX(datetime(effective_from)) AS eff
        FROM budgets
        GROUP BY type_id, period, currency_code
      ) j
      ON b.type_id = j.type_id AND b.period = j.period AND b.currency_code = j.currency_code
         AND datetime(b.effective_from) = j.eff
      ORDER BY b.period ASC, b.currency_code ASC, b.type_id ASC
    ''');

    return [
      for (final r in rows)
        BudgetRow(
          id: r['id'] as int,
          typeId: r['type_id'] as int,
          period: r['period'] as String,
          currencyCode: r['currency_code'] as String,
          amountMinor: r['amount'] as int,
          effectiveFrom: DateTime.parse(r['effective_from'] as String),
        ),
    ];
  }
}
