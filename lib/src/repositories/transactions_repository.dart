import 'package:sqlite3/sqlite3.dart' as sqlite;

class TransactionRow {
  final int id;
  final String kind; // inbound|outbound|internal
  final int? accountId;
  final int? fromAccountId;
  final int? toAccountId;
  final int? amount; // minor units
  final int? outAmount; // minor units
  final int? inAmount; // minor units
  final int? typeId;
  final String? description;
  final DateTime occurredAt;

  TransactionRow({
    required this.id,
    required this.kind,
    required this.accountId,
    required this.fromAccountId,
    required this.toAccountId,
    required this.amount,
    required this.outAmount,
    required this.inAmount,
    required this.typeId,
    required this.description,
    required this.occurredAt,
  });
}

class TransactionsRepository {
  final sqlite.Database db;
  TransactionsRepository(this.db);

  List<TransactionRow> listRecent({int limit = 100}) {
    final result = db.select(
      'SELECT id, kind, account_id, from_account_id, to_account_id, amount, out_amount, in_amount, type_id, description, occurred_at '
      'FROM transactions ORDER BY datetime(occurred_at) DESC, id DESC LIMIT ?;',
      [limit],
    );
    return [
      for (final row in result)
        TransactionRow(
          id: row['id'] as int,
          kind: row['kind'] as String,
          accountId: row['account_id'] as int?,
          fromAccountId: row['from_account_id'] as int?,
          toAccountId: row['to_account_id'] as int?,
          amount: row['amount'] as int?,
          outAmount: row['out_amount'] as int?,
          inAmount: row['in_amount'] as int?,
          typeId: row['type_id'] as int?,
          description: row['description'] as String?,
          occurredAt: DateTime.parse(row['occurred_at'] as String),
        ),
    ];
  }

  int createInbound({
    required int accountId,
    required int amountMinor,
    required DateTime occurredAt,
    int? typeId,
    String? description,
  }) {
    final stmt = db.prepare(
      'INSERT INTO transactions (kind, account_id, amount, occurred_at, type_id, description) VALUES (\'inbound\', ?, ?, ?, ?, ?)',
    );
    try {
      stmt.execute([accountId, amountMinor, occurredAt.toIso8601String(), typeId, description]);
    } finally {
      stmt.dispose();
    }
    return db.lastInsertRowId;
  }

  int createOutbound({
    required int accountId,
    required int amountMinor,
    required DateTime occurredAt,
    int? typeId,
    String? description,
  }) {
    final stmt = db.prepare(
      'INSERT INTO transactions (kind, account_id, amount, occurred_at, type_id, description) VALUES (\'outbound\', ?, ?, ?, ?, ?)',
    );
    try {
      stmt.execute([accountId, amountMinor, occurredAt.toIso8601String(), typeId, description]);
    } finally {
      stmt.dispose();
    }
    return db.lastInsertRowId;
  }

  int createInternalSameCurrency({
    required int fromAccountId,
    required int toAccountId,
    required int amountMinor,
    required DateTime occurredAt,
    int? typeId,
    String? description,
  }) {
    final stmt = db.prepare(
      'INSERT INTO transactions (kind, from_account_id, to_account_id, amount, occurred_at, type_id, description) VALUES (\'internal\', ?, ?, ?, ?, ?, ?)',
    );
    try {
      stmt.execute([fromAccountId, toAccountId, amountMinor, occurredAt.toIso8601String(), typeId, description]);
    } finally {
      stmt.dispose();
    }
    return db.lastInsertRowId;
  }

  int createInternalCrossCurrency({
    required int fromAccountId,
    required int toAccountId,
    required int outAmountMinor,
    required int inAmountMinor,
    required DateTime occurredAt,
    int? typeId,
    String? description,
  }) {
    final stmt = db.prepare(
      'INSERT INTO transactions (kind, from_account_id, to_account_id, out_amount, in_amount, occurred_at, type_id, description) VALUES (\'internal\', ?, ?, ?, ?, ?, ?, ?)',
    );
    try {
      stmt.execute([fromAccountId, toAccountId, outAmountMinor, inAmountMinor, occurredAt.toIso8601String(), typeId, description]);
    } finally {
      stmt.dispose();
    }
    return db.lastInsertRowId;
  }

  void delete(int id) {
    db.execute('DELETE FROM transactions WHERE id = ?', [id]);
  }
}

