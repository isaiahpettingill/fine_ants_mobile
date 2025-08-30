import 'package:sqlite3/sqlite3.dart' as sqlite;

class BalanceCache {
  final sqlite.Database db;
  final Duration ttl;

  BalanceCache(this.db, {this.ttl = const Duration(minutes: 30)});

  final Map<int, _Entry> _cache = {};

  int getBalanceMinor(int accountId) {
    final now = DateTime.now();
    final e = _cache[accountId];
    if (e != null && now.difference(e.updatedAt) < ttl) {
      return e.amountMinor;
    }
    final fresh = _computeFromDb(accountId);
    _cache[accountId] = _Entry(fresh, now);
    return fresh;
  }

  void applyDelta(int accountId, int deltaMinor) {
    final now = DateTime.now();
    final e = _cache[accountId];
    if (e == null || now.difference(e.updatedAt) >= ttl) {
      final base = _computeFromDb(accountId);
      _cache[accountId] = _Entry(base + deltaMinor, now);
    } else {
      _cache[accountId] = _Entry(e.amountMinor + deltaMinor, now);
    }
  }

  void reloadAll() {
    final result = db.select('SELECT id FROM accounts');
    final now = DateTime.now();
    for (final row in result) {
      final id = row['id'] as int;
      _cache[id] = _Entry(_computeFromDb(id), now);
    }
  }

  void invalidateAll() => _cache.clear();

  int _computeFromDb(int accountId) {
    int sum(String sql, List<Object?> args) =>
        db.select(sql, args).first['s'] as int;

    final inbound = sum(
      "SELECT COALESCE(SUM(amount),0) AS s FROM transactions WHERE kind='inbound' AND account_id=?",
      [accountId],
    );
    final outbound = sum(
      "SELECT COALESCE(SUM(amount),0) AS s FROM transactions WHERE kind='outbound' AND account_id=?",
      [accountId],
    );
    final internalOut = sum(
      "SELECT COALESCE(SUM(amount),0) AS s FROM transactions WHERE kind='internal' AND from_account_id=? AND amount IS NOT NULL",
      [accountId],
    );
    final internalIn = sum(
      "SELECT COALESCE(SUM(amount),0) AS s FROM transactions WHERE kind='internal' AND to_account_id=? AND amount IS NOT NULL",
      [accountId],
    );
    final internalOutX = sum(
      "SELECT COALESCE(SUM(out_amount),0) AS s FROM transactions WHERE kind='internal' AND from_account_id=? AND out_amount IS NOT NULL",
      [accountId],
    );
    final internalInX = sum(
      "SELECT COALESCE(SUM(in_amount),0) AS s FROM transactions WHERE kind='internal' AND to_account_id=? AND in_amount IS NOT NULL",
      [accountId],
    );
    final rebalance = sum(
      "SELECT COALESCE(SUM(amount),0) AS s FROM transactions WHERE kind='rebalance' AND account_id=?",
      [accountId],
    );

    return inbound -
        outbound -
        internalOut -
        internalOutX +
        internalIn +
        internalInX +
        rebalance;
  }
}

class _Entry {
  final int amountMinor;
  final DateTime updatedAt;
  _Entry(this.amountMinor, this.updatedAt);
}
