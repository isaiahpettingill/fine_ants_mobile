import 'package:sqlite3/sqlite3.dart' as sqlite;

import '../../stats/domain/time_series.dart';
import '../../stats/domain/simple_stats.dart';
import '../../stats/domain/account_totals.dart';

class StatsService {
  final sqlite.Database db;
  StatsService(this.db);

  /// Returns a balance time series for a single account.
  /// Computes the end-of-period balance within [start, endExclusive).
  List<TimeSeriesPoint> accountBalanceSeries({
    required int accountId,
    required DateTime start,
    required DateTime endExclusive,
    SeriesPeriod period = SeriesPeriod.month,
  }) {
    final deltas = _accountDeltas(
      accountId: accountId,
      start: null,
      endExclusive: null,
    );
    return _balanceSeriesFromDeltas(
      deltas: deltas,
      start: start,
      endExclusive: endExclusive,
      period: period,
    );
  }

  /// Returns a combined balance time series summing balances across accounts.
  List<TimeSeriesPoint> combinedBalanceSeries({
    required List<int> accountIds,
    required DateTime start,
    required DateTime endExclusive,
    SeriesPeriod period = SeriesPeriod.month,
  }) {
    final deltas = <_Delta>[];
    for (final id in accountIds) {
      deltas.addAll(
        _accountDeltas(accountId: id, start: null, endExclusive: null),
      );
    }
    deltas.sort((a, b) => a.when.compareTo(b.when));
    return _balanceSeriesFromDeltas(
      deltas: deltas,
      start: start,
      endExclusive: endExclusive,
      period: period,
    );
  }

  /// For a given (typeId, currencyCode, period), computes pairs of
  /// (periodStart, spentMinor, budgetMinor) across the range.
  List<BudgetAdherencePoint> budgetAdherenceSeries({
    required int typeId,
    required String currencyCode,
    required String period, // 'week' | 'month' | 'year'
    required DateTime start,
    required DateTime endExclusive,
  }) {
    final points = <BudgetAdherencePoint>[];
    DateTime cursor = _floorForBudget(period, start);
    while (cursor.isBefore(endExclusive)) {
      final next = _nextForBudget(period, cursor);
      final spent = _spentForKeyInRange(
        typeId: typeId,
        currencyCode: currencyCode,
        start: cursor,
        endExclusive: next,
      );
      final budget = _budgetForKeyOnDate(
        typeId: typeId,
        currencyCode: currencyCode,
        period: period,
        onDate: cursor,
      );
      final budgetMinor = budget?.amount ?? 0;
      points.add(
        BudgetAdherencePoint(
          x: cursor,
          spentMinor: spent,
          budgetMinor: budgetMinor,
        ),
      );
      cursor = next;
    }
    return points;
  }

  // --- Internal helpers ---

  List<TimeSeriesPoint> _balanceSeriesFromDeltas({
    required List<_Delta> deltas,
    required DateTime start,
    required DateTime endExclusive,
    required SeriesPeriod period,
  }) {
    deltas.sort((a, b) => a.when.compareTo(b.when));

    int running = 0;
    var idx = 0;

    // Apply all deltas before start to seed the running balance.
    while (idx < deltas.length && !deltas[idx].when.isAfter(start)) {
      running += deltas[idx].amountMinor;
      idx++;
    }

    final out = <TimeSeriesPoint>[];
    DateTime cursor = period.floor(start);
    while (cursor.isBefore(endExclusive)) {
      final next = period.next(cursor);
      // Apply deltas within this period [cursor, next)
      while (idx < deltas.length && deltas[idx].when.isBefore(next)) {
        running += deltas[idx].amountMinor;
        idx++;
      }
      out.add(TimeSeriesPoint(x: cursor, yMinor: running));
      cursor = next;
    }
    return out;
  }

  List<_Delta> _accountDeltas({
    required int accountId,
    DateTime? start,
    DateTime? endExclusive,
  }) {
    final params = <Object?>[];
    final clauses = <String>[];
    if (start != null) {
      clauses.add("datetime(occurred_at) >= datetime(?)");
      params.add(start.toIso8601String());
    }
    if (endExclusive != null) {
      clauses.add("datetime(occurred_at) < datetime(?)");
      params.add(endExclusive.toIso8601String());
    }
    final range = clauses.isEmpty ? '' : 'AND ${clauses.join(' AND ')}';

    final rows = db.select(
      '''
      SELECT occurred_at, kind, account_id, from_account_id, to_account_id, amount, out_amount, in_amount
      FROM transactions
      WHERE (
        (kind IN ('inbound','outbound','rebalance') AND account_id = ?)
        OR (kind = 'internal' AND (from_account_id = ? OR to_account_id = ?))
      )
      $range
      ORDER BY datetime(occurred_at) ASC, id ASC
    ''',
      [accountId, accountId, accountId, ...params],
    );

    final deltas = <_Delta>[];
    for (final r in rows) {
      final kind = r['kind'] as String;
      final when = DateTime.parse(r['occurred_at'] as String);
      int delta = 0;
      if (kind == 'inbound') {
        delta = (r['amount'] as int?) ?? 0;
      } else if (kind == 'outbound') {
        delta = -((r['amount'] as int?) ?? 0);
      } else if (kind == 'rebalance') {
        delta = (r['amount'] as int?) ?? 0;
      } else if (kind == 'internal') {
        final fromId = r['from_account_id'] as int?;
        final toId = r['to_account_id'] as int?;
        final sameCurAmount = r['amount'] as int?;
        if (fromId == accountId) {
          delta = -((sameCurAmount ?? (r['out_amount'] as int?)) ?? 0);
        } else if (toId == accountId) {
          delta = (sameCurAmount ?? (r['in_amount'] as int?)) ?? 0;
        }
      }
      if (delta != 0) deltas.add(_Delta(when: when, amountMinor: delta));
    }
    return deltas;
  }

  DateTime _floorForBudget(String period, DateTime dt) {
    switch (period) {
      case 'week':
        final weekday = dt.weekday; // Monday=1 .. Sunday=7
        final start = dt.subtract(Duration(days: weekday - 1));
        return DateTime(start.year, start.month, start.day);
      case 'year':
        return DateTime(dt.year);
      case 'month':
      default:
        return DateTime(dt.year, dt.month, 1);
    }
  }

  DateTime _nextForBudget(String period, DateTime dt) {
    switch (period) {
      case 'week':
        return dt.add(const Duration(days: 7));
      case 'year':
        return DateTime(dt.year + 1);
      case 'month':
      default:
        return DateTime(dt.year, dt.month + 1, 1);
    }
  }

  int _spentForKeyInRange({
    required int typeId,
    required String currencyCode,
    required DateTime start,
    required DateTime endExclusive,
  }) {
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

  /// Earnings vs Spending ratio series per period for a currency across all accounts.
  List<EarningSpendingPoint> earningSpendingRatioSeries({
    required String currencyCode,
    required DateTime start,
    required DateTime endExclusive,
    SeriesPeriod period = SeriesPeriod.month,
  }) {
    final points = <EarningSpendingPoint>[];
    DateTime cursor = period.floor(start);
    while (cursor.isBefore(endExclusive)) {
      final next = period.next(cursor);
      final earned = _sumForKindCurrencyInRange(
        kind: 'inbound',
        currencyCode: currencyCode,
        start: cursor,
        endExclusive: next,
      );
      final spent = _sumForKindCurrencyInRange(
        kind: 'outbound',
        currencyCode: currencyCode,
        start: cursor,
        endExclusive: next,
      );
      points.add(
        EarningSpendingPoint(x: cursor, earnedMinor: earned, spentMinor: spent),
      );
      cursor = next;
    }
    return points;
  }

  /// Computes simple aggregate stats for a given [currencyCode] at [asOf].
  /// - Spent this month/year across all accounts in currency.
  /// - % budgets met: share of budget keys whose current-period spend <= budget.
  /// - $ saved: sum of (budget - spend) for those met.
  /// - E/S ratio for current month.
  SimpleStats computeSimpleStats({
    required String currencyCode,
    DateTime? asOf,
  }) {
    final now = asOf ?? DateTime.now();
    final monthStart = DateTime(now.year, now.month);
    final nextMonth = DateTime(now.year, now.month + 1);
    final yearStart = DateTime(now.year);

    final spentMonth = _sumForKindCurrencyInRange(
      kind: 'outbound',
      currencyCode: currencyCode,
      start: monthStart,
      endExclusive: nextMonth,
    );
    final earnedMonth = _sumForKindCurrencyInRange(
      kind: 'inbound',
      currencyCode: currencyCode,
      start: monthStart,
      endExclusive: nextMonth,
    );
    final spentYear = _sumForKindCurrencyInRange(
      kind: 'outbound',
      currencyCode: currencyCode,
      start: yearStart,
      endExclusive: DateTime(now.year + 1),
    );

    // Budgets: evaluate latest version per (type_id, period) for this currency.
    final latestBudgetRows = db.select(
      '''
      SELECT b.type_id, b.period, b.currency_code, b.amount
      FROM budgets b
      JOIN (
        SELECT type_id, period, currency_code, MAX(datetime(effective_from)) AS eff
        FROM budgets
        WHERE currency_code = ?
        GROUP BY type_id, period, currency_code
      ) j
      ON b.type_id = j.type_id AND b.period = j.period AND b.currency_code = j.currency_code
         AND datetime(b.effective_from) = j.eff
      WHERE b.currency_code = ?
    ''',
      [currencyCode, currencyCode],
    );

    int totalBudgets = 0;
    int metBudgets = 0;
    int savedMinor = 0;
    for (final r in latestBudgetRows) {
      totalBudgets += 1;
      final typeId = r['type_id'] as int;
      final period = r['period'] as String;
      final amountMinor = r['amount'] as int;
      final periodStart = _floorForBudget(period, now);
      final periodEnd = _nextForBudget(period, periodStart);
      final spent = _spentForKeyInRange(
        typeId: typeId,
        currencyCode: currencyCode,
        start: periodStart,
        endExclusive: periodEnd,
      );
      if (spent <= amountMinor) {
        metBudgets += 1;
        savedMinor += (amountMinor - spent);
      }
    }

    final percentMet = totalBudgets == 0
        ? 0.0
        : (metBudgets * 100.0) / totalBudgets;

    final ratio = spentMonth == 0 ? null : earnedMonth / spentMonth;

    return SimpleStats(
      currencyCode: currencyCode,
      spentThisMonthMinor: spentMonth,
      earnedThisMonthMinor: earnedMonth,
      spentThisYearMinor: spentYear,
      budgetsMetPercent: percentMet,
      savedMinor: savedMinor,
      earningSpendingRatio: ratio,
    );
  }

  /// Returns earned and spent totals per account for a given currency.
  /// Only considers inbound/outbound transactions (excludes internal/rebalance).
  List<AccountTotals> perAccountTotalsByCurrency({
    required String currencyCode,
  }) {
    final rows = db.select(
      '''
      SELECT a.id AS account_id, a.name AS account_name,
             COALESCE(SUM(CASE WHEN t.kind = 'inbound' THEN t.amount END), 0) AS earned,
             COALESCE(SUM(CASE WHEN t.kind = 'outbound' THEN t.amount END), 0) AS spent
      FROM accounts a
      LEFT JOIN transactions t ON t.account_id = a.id AND t.kind IN ('inbound','outbound')
      WHERE a.currency_code = ?
      GROUP BY a.id, a.name
      ORDER BY a.id DESC
      ''',
      [currencyCode],
    );
    return [
      for (final r in rows)
        AccountTotals(
          accountId: r['account_id'] as int,
          accountName: r['account_name'] as String,
          earnedMinor: (r['earned'] as int?) ?? 0,
          spentMinor: (r['spent'] as int?) ?? 0,
        ),
    ];
  }

  int _sumForKindCurrencyInRange({
    required String kind,
    required String currencyCode,
    required DateTime start,
    required DateTime endExclusive,
  }) {
    final rows = db.select(
      '''
      SELECT COALESCE(SUM(t.amount), 0) AS s
      FROM transactions t
      JOIN accounts a ON a.id = t.account_id
      WHERE t.kind = ?
        AND a.currency_code = ?
        AND datetime(t.occurred_at) >= datetime(?)
        AND datetime(t.occurred_at) < datetime(?)
      ''',
      [
        kind,
        currencyCode,
        start.toIso8601String(),
        endExclusive.toIso8601String(),
      ],
    );
    return (rows.first['s'] as int?) ?? 0;
  }

  _BudgetVersion? _budgetForKeyOnDate({
    required int typeId,
    required String currencyCode,
    required String period,
    required DateTime onDate,
  }) {
    final rows = db.select(
      '''
      SELECT id, amount
      FROM budgets
      WHERE type_id = ? AND period = ? AND currency_code = ?
        AND datetime(effective_from) <= datetime(?)
      ORDER BY datetime(effective_from) DESC, id DESC LIMIT 1
      ''',
      [typeId, period, currencyCode, onDate.toIso8601String()],
    );
    if (rows.isEmpty) return null;
    return _BudgetVersion(
      id: rows.first['id'] as int,
      amount: rows.first['amount'] as int,
    );
  }
}

class _Delta {
  final DateTime when;
  final int amountMinor;
  _Delta({required this.when, required this.amountMinor});
}

class _BudgetVersion {
  final int id;
  final int amount;
  _BudgetVersion({required this.id, required this.amount});
}

// no-op
