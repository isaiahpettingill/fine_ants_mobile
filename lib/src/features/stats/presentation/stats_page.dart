import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

import '../../stats/data/stats_service.dart';
import '../../stats/domain/time_series.dart';
import '../../../repositories/accounts_repository.dart';
import '../../../repositories/currencies_repository.dart';
import '../../../repositories/budgets_repository.dart';
import '../../../utils/currency_format.dart';

class StatsPage extends StatefulWidget {
  final sqlite.Database db;
  final AccountsRepository accountsRepo;
  final CurrenciesRepository currenciesRepo;
  final BudgetsRepository budgetsRepo;

  const StatsPage({
    super.key,
    required this.db,
    required this.accountsRepo,
    required this.currenciesRepo,
    required this.budgetsRepo,
  });

  @override
  State<StatsPage> createState() => _StatsPageState();
}

class _StatsPageState extends State<StatsPage>
    with SingleTickerProviderStateMixin {
  late final StatsService _stats;
  int? _selectedAccountId;
  String? _selectedCurrency;
  _BudgetKey? _selectedBudgetKey;

  @override
  void initState() {
    super.initState();
    _stats = StatsService(widget.db);
    final accounts = widget.accountsRepo.listAll();
    _selectedAccountId = accounts.isNotEmpty ? accounts.first.id : null;
    _selectedCurrency = accounts.isNotEmpty
        ? accounts.first.currencyCode
        : null;

    final latestBudgets = widget.budgetsRepo.listLatestPerKey();
    if (latestBudgets.isNotEmpty) {
      final b = latestBudgets.first;
      _selectedBudgetKey = _BudgetKey(
        typeId: b.typeId,
        period: b.period,
        currencyCode: b.currencyCode,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Column(
        children: [
          const TabBar(
            tabs: [
              Tab(text: 'Account'),
              Tab(text: 'All Accounts'),
              Tab(text: 'Budget'),
              Tab(text: 'E/S Ratio'),
            ],
          ),
          const Divider(height: 1),
          Expanded(
            child: TabBarView(
              children: [
                _AccountChartTab(
                  stats: _stats,
                  accountsRepo: widget.accountsRepo,
                  currenciesRepo: widget.currenciesRepo,
                  selectedAccountId: _selectedAccountId,
                  onSelectAccount: (v) =>
                      setState(() => _selectedAccountId = v),
                ),
                _AllAccountsChartTab(
                  stats: _stats,
                  accountsRepo: widget.accountsRepo,
                  currenciesRepo: widget.currenciesRepo,
                  selectedCurrency: _selectedCurrency,
                  onSelectCurrency: (v) =>
                      setState(() => _selectedCurrency = v),
                ),
                _BudgetChartTab(
                  stats: _stats,
                  budgetsRepo: widget.budgetsRepo,
                  currenciesRepo: widget.currenciesRepo,
                  selected: _selectedBudgetKey,
                  onSelect: (v) => setState(() => _selectedBudgetKey = v),
                ),
                _EarningSpendingRatioTab(
                  stats: _stats,
                  accountsRepo: widget.accountsRepo,
                  selectedCurrency: _selectedCurrency,
                  onSelectCurrency: (v) =>
                      setState(() => _selectedCurrency = v),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AccountChartTab extends StatelessWidget {
  final StatsService stats;
  final AccountsRepository accountsRepo;
  final CurrenciesRepository currenciesRepo;
  final int? selectedAccountId;
  final ValueChanged<int?> onSelectAccount;

  const _AccountChartTab({
    required this.stats,
    required this.accountsRepo,
    required this.currenciesRepo,
    required this.selectedAccountId,
    required this.onSelectAccount,
  });

  @override
  Widget build(BuildContext context) {
    final accounts = accountsRepo.listAll();
    if (accounts.isEmpty) {
      return const Center(child: Text('No accounts'));
    }
    final sel = selectedAccountId ?? accounts.first.id;
    final account = accounts.firstWhere(
      (a) => a.id == sel,
      orElse: () => accounts.first,
    );
    final curRow = currenciesRepo.getByCode(account.currencyCode);

    final now = DateTime.now();
    final start = DateTime(now.year, now.month - 11, 1);
    final series = stats.accountBalanceSeries(
      accountId: account.id,
      start: start,
      endExclusive: DateTime(now.year, now.month + 1, 1),
      period: SeriesPeriod.month,
    );

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DropdownButton<int>(
            value: sel,
            onChanged: onSelectAccount,
            items: [
              for (final a in accounts)
                DropdownMenuItem(value: a.id, child: Text(a.name)),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: _BalanceLineChart(
              points: series,
              currency: curRow?.code ?? account.currencyCode,
              currenciesRepo: currenciesRepo,
            ),
          ),
        ],
      ),
    );
  }
}

class _AllAccountsChartTab extends StatelessWidget {
  final StatsService stats;
  final AccountsRepository accountsRepo;
  final CurrenciesRepository currenciesRepo;
  final String? selectedCurrency;
  final ValueChanged<String?> onSelectCurrency;

  const _AllAccountsChartTab({
    required this.stats,
    required this.accountsRepo,
    required this.currenciesRepo,
    required this.selectedCurrency,
    required this.onSelectCurrency,
  });

  @override
  Widget build(BuildContext context) {
    final accounts = accountsRepo.listAll();
    if (accounts.isEmpty) return const Center(child: Text('No accounts'));
    final currencies = {for (final a in accounts) a.currencyCode}.toList()
      ..sort();
    final cur = selectedCurrency ?? currencies.first;
    final chosenAccounts = accounts
        .where((a) => a.currencyCode == cur)
        .map((a) => a.id)
        .toList();
    if (chosenAccounts.isEmpty) {
      return const Center(child: Text('No accounts for currency'));
    }

    final now = DateTime.now();
    final start = DateTime(now.year, now.month - 11, 1);
    final series = stats.combinedBalanceSeries(
      accountIds: chosenAccounts,
      start: start,
      endExclusive: DateTime(now.year, now.month + 1, 1),
      period: SeriesPeriod.month,
    );

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DropdownButton<String>(
            value: cur,
            onChanged: onSelectCurrency,
            items: [
              for (final c in currencies)
                DropdownMenuItem(value: c, child: Text(c)),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: _BalanceLineChart(
              points: series,
              currency: cur,
              currenciesRepo: currenciesRepo,
            ),
          ),
        ],
      ),
    );
  }
}

class _BudgetChartTab extends StatelessWidget {
  final StatsService stats;
  final BudgetsRepository budgetsRepo;
  final CurrenciesRepository currenciesRepo;
  final _BudgetKey? selected;
  final ValueChanged<_BudgetKey?> onSelect;

  const _BudgetChartTab({
    required this.stats,
    required this.budgetsRepo,
    required this.currenciesRepo,
    required this.selected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final latest = budgetsRepo.listLatestPerKey();
    if (latest.isEmpty) return const Center(child: Text('No budgets'));
    final keys = [
      for (final b in latest)
        _BudgetKey(
          typeId: b.typeId,
          period: b.period,
          currencyCode: b.currencyCode,
        ),
    ];
    final sel = selected ?? keys.first;

    final now = DateTime.now();
    final start = sel.period == 'year'
        ? DateTime(now.year - 4)
        : DateTime(now.year, now.month - 11, 1);
    final end = sel.period == 'year'
        ? DateTime(now.year + 1)
        : DateTime(now.year, now.month + 1, 1);

    final points = stats.budgetAdherenceSeries(
      typeId: sel.typeId,
      currencyCode: sel.currencyCode,
      period: sel.period,
      start: start,
      endExclusive: end,
    );

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DropdownButton<_BudgetKey>(
            value: sel,
            onChanged: onSelect,
            items: [
              for (final k in keys)
                DropdownMenuItem(
                  value: k,
                  child: Text(
                    '${k.currencyCode} • ${k.period} • type:${k.typeId}',
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: _BudgetBarChart(
              points: points,
              currency: sel.currencyCode,
              currenciesRepo: currenciesRepo,
            ),
          ),
        ],
      ),
    );
  }
}

class _BalanceLineChart extends StatelessWidget {
  final List<TimeSeriesPoint> points;
  final String currency;
  final CurrenciesRepository currenciesRepo;

  const _BalanceLineChart({
    required this.points,
    required this.currency,
    required this.currenciesRepo,
  });

  @override
  Widget build(BuildContext context) {
    final cur = currenciesRepo.getByCode(currency);
    final spots = <FlSpot>[];
    for (var i = 0; i < points.length; i++) {
      spots.add(FlSpot(i.toDouble(), points[i].yMinor.toDouble()));
    }
    final double? maxY = spots.isEmpty
        ? null
        : spots.map((e) => e.y).reduce((a, b) => a > b ? a : b);
    final double? minY = spots.isEmpty
        ? null
        : spots.map((e) => e.y).reduce((a, b) => a < b ? a : b);

    String formatMinor(num v) => formatMinorUnits(
      v.abs().toInt(),
      cur ??
          CurrencyRow(
            code: currency,
            symbol: '',
            symbolPosition: 'before',
            decimalPlaces: 2,
          ),
    );

    return LineChart(
      LineChartData(
        minY: minY,
        maxY: maxY,
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipItems: (touchedSpots) => [
              for (final s in touchedSpots)
                LineTooltipItem(
                  formatMinor(s.y),
                  const TextStyle(fontWeight: FontWeight.bold),
                ),
            ],
          ),
        ),
        gridData: const FlGridData(show: true),
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 22,
              interval: math.max(1, (points.length / 6).floorToDouble()),
              getTitlesWidget: (value, meta) {
                final idx = value.toInt();
                if (idx < 0 || idx >= points.length) {
                  return const SizedBox.shrink();
                }
                final d = points[idx].x;
                return Text(
                  '${d.month}/${d.year % 100}',
                  style: const TextStyle(fontSize: 10),
                );
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 56,
              getTitlesWidget: (value, meta) {
                return Text(
                  formatMinor(value),
                  style: const TextStyle(fontSize: 10),
                );
              },
            ),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            isCurved: true,
            color: Theme.of(context).colorScheme.primary,
            barWidth: 3,
            spots: spots,
            dotData: const FlDotData(show: false),
          ),
        ],
      ),
    );
  }
}

class _BudgetBarChart extends StatelessWidget {
  final List<BudgetAdherencePoint> points;
  final String currency;
  final CurrenciesRepository currenciesRepo;

  const _BudgetBarChart({
    required this.points,
    required this.currency,
    required this.currenciesRepo,
  });

  @override
  Widget build(BuildContext context) {
    final cur = currenciesRepo.getByCode(currency);
    String fmt(int v) => formatMinorUnits(
      v.abs(),
      cur ??
          CurrencyRow(
            code: currency,
            symbol: '',
            symbolPosition: 'before',
            decimalPlaces: 2,
          ),
    );

    final groups = <BarChartGroupData>[];
    for (var i = 0; i < points.length; i++) {
      final p = points[i];
      groups.add(
        BarChartGroupData(
          x: i,
          barsSpace: 6,
          barRods: [
            BarChartRodData(
              toY: p.spentMinor.toDouble(),
              color: Colors.red.shade400,
              width: 10,
            ),
            BarChartRodData(
              toY: p.budgetMinor.toDouble(),
              color: Colors.green.shade500,
              width: 10,
            ),
          ],
        ),
      );
    }

    return BarChart(
      BarChartData(
        barTouchData: BarTouchData(
          enabled: true,
          touchTooltipData: BarTouchTooltipData(
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              final p = points[group.x.toInt()];
              return BarTooltipItem(
                '${p.x.month}/${p.x.year % 100}\n${rodIndex == 0 ? 'Spent' : 'Budget'}: ${fmt(rod.toY.toInt())}',
                const TextStyle(fontWeight: FontWeight.bold),
              );
            },
          ),
        ),
        gridData: const FlGridData(show: true),
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 22,
              interval: math.max(1, (points.length / 6).floorToDouble()),
              getTitlesWidget: (value, meta) {
                final idx = value.toInt();
                if (idx < 0 || idx >= points.length) {
                  return const SizedBox.shrink();
                }
                final d = points[idx].x;
                return Text(
                  '${d.month}/${d.year % 100}',
                  style: const TextStyle(fontSize: 10),
                );
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 56,
              getTitlesWidget: (value, meta) {
                return Text(
                  fmt(value.toInt()),
                  style: const TextStyle(fontSize: 10),
                );
              },
            ),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
        ),
        barGroups: groups,
      ),
    );
  }
}

class _BudgetKey {
  final int typeId;
  final String period;
  final String currencyCode;
  const _BudgetKey({
    required this.typeId,
    required this.period,
    required this.currencyCode,
  });

  @override
  bool operator ==(Object other) =>
      other is _BudgetKey &&
      other.typeId == typeId &&
      other.period == period &&
      other.currencyCode == currencyCode;

  @override
  int get hashCode => Object.hash(typeId, period, currencyCode);
}

class _EarningSpendingRatioTab extends StatelessWidget {
  final StatsService stats;
  final AccountsRepository accountsRepo;
  final String? selectedCurrency;
  final ValueChanged<String?> onSelectCurrency;

  const _EarningSpendingRatioTab({
    required this.stats,
    required this.accountsRepo,
    required this.selectedCurrency,
    required this.onSelectCurrency,
  });

  @override
  Widget build(BuildContext context) {
    final accounts = accountsRepo.listAll();
    if (accounts.isEmpty) {
      return const Center(child: Text('No accounts'));
    }
    final currencies = {for (final a in accounts) a.currencyCode}.toList()
      ..sort();
    final cur = selectedCurrency ?? currencies.first;

    final now = DateTime.now();
    final start = DateTime(now.year, now.month - 11, 1);
    final series = stats.earningSpendingRatioSeries(
      currencyCode: cur,
      start: start,
      endExclusive: DateTime(now.year, now.month + 1, 1),
      period: SeriesPeriod.month,
    );

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DropdownButton<String>(
            value: cur,
            onChanged: onSelectCurrency,
            items: [
              for (final c in currencies)
                DropdownMenuItem(value: c, child: Text(c)),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(child: _RatioLineChart(points: series)),
        ],
      ),
    );
  }
}

class _RatioLineChart extends StatelessWidget {
  final List<EarningSpendingPoint> points;
  const _RatioLineChart({required this.points});

  @override
  Widget build(BuildContext context) {
    final spots = <FlSpot>[];
    for (var i = 0; i < points.length; i++) {
      final r = points[i].ratio ?? 0.0;
      spots.add(FlSpot(i.toDouble(), r));
    }
    final double? maxY = spots.isEmpty
        ? null
        : spots.map((e) => e.y).reduce((a, b) => a > b ? a : b);
    const double minY = 0.0; // ratio can't be negative
    final double? showMax = maxY == null
        ? null
        : (maxY < 2.0
              ? 2.0
              : maxY > 10.0
              ? 10.0
              : maxY);

    return LineChart(
      LineChartData(
        minY: minY,
        maxY: showMax,
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipItems: (touchedSpots) => [
              for (final s in touchedSpots)
                LineTooltipItem(
                  points[s.spotIndex].ratio == null
                      ? '∞ (no spend)'
                      : points[s.spotIndex].ratio!.toStringAsFixed(2),
                  const TextStyle(fontWeight: FontWeight.bold),
                ),
            ],
          ),
        ),
        gridData: const FlGridData(show: true),
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 22,
              interval: math.max(1, (points.length / 6).floorToDouble()),
              getTitlesWidget: (value, meta) {
                final idx = value.toInt();
                if (idx < 0 || idx >= points.length) {
                  return const SizedBox.shrink();
                }
                final d = points[idx].x;
                return Text(
                  '${d.month}/${d.year % 100}',
                  style: const TextStyle(fontSize: 10),
                );
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 44,
              getTitlesWidget: (value, meta) => Text(
                value.toStringAsFixed(1),
                style: const TextStyle(fontSize: 10),
              ),
            ),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            isCurved: true,
            color: Theme.of(context).colorScheme.primary,
            barWidth: 3,
            spots: spots,
            dotData: const FlDotData(show: false),
          ),
        ],
        extraLinesData: ExtraLinesData(
          horizontalLines: [
            HorizontalLine(
              y: 1.0,
              color: Colors.grey.shade500,
              dashArray: const [6, 6],
            ),
          ],
        ),
      ),
    );
  }
}
