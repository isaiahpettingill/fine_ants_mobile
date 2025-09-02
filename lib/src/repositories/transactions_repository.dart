import 'package:sqlite3/sqlite3.dart' as sqlite;
import '../services/balance_cache.dart';

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
  final BalanceCache? balanceCache;
  TransactionsRepository(this.db, {this.balanceCache});

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

  /// Lists outbound transactions for a given category (type) and currency
  /// within the provided [start, endExclusive) date range. Results are
  /// ordered by occurred_at desc then id desc.
  List<TransactionRow> listOutboundByTypeCurrencyInRange({
    required int typeId,
    required String currencyCode,
    required DateTime start,
    required DateTime endExclusive,
  }) {
    final result = db.select(
      '''
      SELECT t.id, t.kind, t.account_id, t.from_account_id, t.to_account_id,
             t.amount, t.out_amount, t.in_amount, t.type_id, t.description, t.occurred_at
      FROM transactions t
      JOIN accounts a ON a.id = t.account_id
      WHERE t.kind = 'outbound'
        AND t.type_id = ?
        AND a.currency_code = ?
        AND datetime(t.occurred_at) >= datetime(?)
        AND datetime(t.occurred_at) < datetime(?)
      ORDER BY datetime(t.occurred_at) DESC, t.id DESC
      ''',
      [
        typeId,
        currencyCode,
        start.toIso8601String(),
        endExclusive.toIso8601String(),
      ],
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

  /// Lists all transactions that occurred within [start, endExclusive).
  /// Ordered by occurred_at desc then id desc.
  List<TransactionRow> listByOccurredAtRange({
    required DateTime start,
    required DateTime endExclusive,
  }) {
    final result = db.select(
      'SELECT id, kind, account_id, from_account_id, to_account_id, amount, out_amount, in_amount, type_id, description, occurred_at '
      'FROM transactions WHERE datetime(occurred_at) >= datetime(?) AND datetime(occurred_at) < datetime(?) '
      'ORDER BY datetime(occurred_at) DESC, id DESC;',
      [start.toIso8601String(), endExclusive.toIso8601String()],
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
      stmt.execute([
        accountId,
        amountMinor,
        occurredAt.toIso8601String(),
        typeId,
        description,
      ]);
      balanceCache?.applyDelta(accountId, amountMinor);
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
      stmt.execute([
        accountId,
        amountMinor,
        occurredAt.toIso8601String(),
        typeId,
        description,
      ]);
      balanceCache?.applyDelta(accountId, -amountMinor);
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
      stmt.execute([
        fromAccountId,
        toAccountId,
        amountMinor,
        occurredAt.toIso8601String(),
        typeId,
        description,
      ]);
      balanceCache?.applyDelta(fromAccountId, -amountMinor);
      balanceCache?.applyDelta(toAccountId, amountMinor);
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
      stmt.execute([
        fromAccountId,
        toAccountId,
        outAmountMinor,
        inAmountMinor,
        occurredAt.toIso8601String(),
        typeId,
        description,
      ]);
      balanceCache?.applyDelta(fromAccountId, -outAmountMinor);
      balanceCache?.applyDelta(toAccountId, inAmountMinor);
    } finally {
      stmt.dispose();
    }
    return db.lastInsertRowId;
  }

  /// Creates a rebalance transaction for a single account. The [deltaMinor]
  /// may be positive (to add funds) or negative (to remove funds).
  int createRebalance({
    required int accountId,
    required int deltaMinor,
    required DateTime occurredAt,
    String? description,
  }) {
    final stmt = db.prepare(
      "INSERT INTO transactions (kind, account_id, amount, occurred_at, type_id, description) VALUES ('rebalance', ?, ?, ?, NULL, ?)",
    );
    try {
      stmt.execute([
        accountId,
        deltaMinor,
        occurredAt.toIso8601String(),
        description,
      ]);
      balanceCache?.applyDelta(accountId, deltaMinor);
    } finally {
      stmt.dispose();
    }
    return db.lastInsertRowId;
  }

  /// Computes the current balance (in minor units) for an account by summing
  /// all related transactions. Rebalance deltas are applied as signed amounts.
  int getAccountBalanceMinor(int accountId) {
    // Inbound sum
    final inbound =
        db.select(
              "SELECT COALESCE(SUM(amount),0) AS s FROM transactions WHERE kind='inbound' AND account_id=?",
              [accountId],
            ).first['s']
            as int;

    // Outbound sum
    final outbound =
        db.select(
              "SELECT COALESCE(SUM(amount),0) AS s FROM transactions WHERE kind='outbound' AND account_id=?",
              [accountId],
            ).first['s']
            as int;

    // Internal same-currency (amount not null)
    final internalOut =
        db.select(
              "SELECT COALESCE(SUM(amount),0) AS s FROM transactions WHERE kind='internal' AND from_account_id=? AND amount IS NOT NULL",
              [accountId],
            ).first['s']
            as int;
    final internalIn =
        db.select(
              "SELECT COALESCE(SUM(amount),0) AS s FROM transactions WHERE kind='internal' AND to_account_id=? AND amount IS NOT NULL",
              [accountId],
            ).first['s']
            as int;

    // Internal cross-currency (out_amount / in_amount)
    final internalOutX =
        db.select(
              "SELECT COALESCE(SUM(out_amount),0) AS s FROM transactions WHERE kind='internal' AND from_account_id=? AND out_amount IS NOT NULL",
              [accountId],
            ).first['s']
            as int;
    final internalInX =
        db.select(
              "SELECT COALESCE(SUM(in_amount),0) AS s FROM transactions WHERE kind='internal' AND to_account_id=? AND in_amount IS NOT NULL",
              [accountId],
            ).first['s']
            as int;

    // Rebalance sum (signed)
    final rebalance =
        db.select(
              "SELECT COALESCE(SUM(amount),0) AS s FROM transactions WHERE kind='rebalance' AND account_id=?",
              [accountId],
            ).first['s']
            as int;

    return inbound -
        outbound -
        internalOut -
        internalOutX +
        internalIn +
        internalInX +
        rebalance;
  }

  void delete(int id) {
    db.execute('DELETE FROM transactions WHERE id = ?', [id]);
  }
}
