import 'package:flutter/material.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

import '../../stats/data/stats_service.dart';
import '../../../repositories/accounts_repository.dart';
import '../../../repositories/currencies_repository.dart';
import '../../../utils/currency_format.dart';
import '../../stats/domain/simple_stats.dart';
import '../../stats/domain/account_totals.dart';

class StatsPage extends StatefulWidget {
  final sqlite.Database db;
  final AccountsRepository accountsRepo;
  final CurrenciesRepository currenciesRepo;

  const StatsPage({
    super.key,
    required this.db,
    required this.accountsRepo,
    required this.currenciesRepo,
  });

  @override
  State<StatsPage> createState() => _StatsPageState();
}

class _StatsPageState extends State<StatsPage> {
  late final StatsService _stats;
  String? _selectedCurrency;

  @override
  void initState() {
    super.initState();
    _stats = StatsService(widget.db);
    final accounts = widget.accountsRepo.listAll();
    _selectedCurrency = accounts.isNotEmpty
        ? accounts.first.currencyCode
        : null;
  }

  @override
  Widget build(BuildContext context) {
    final accounts = widget.accountsRepo.listAll();
    if (accounts.isEmpty) return const Center(child: Text('No accounts'));
    final currencies = {for (final a in accounts) a.currencyCode}.toList()
      ..sort();
    final curCode = _selectedCurrency ?? currencies.first;

    final curRow =
        widget.currenciesRepo.getByCode(curCode) ??
        CurrencyRow(
          code: curCode,
          symbol: '',
          symbolPosition: 'before',
          decimalPlaces: 2,
        );

    final SimpleStats data = _stats.computeSimpleStats(currencyCode: curCode);
    final List<AccountTotals> perAccount = _stats.perAccountTotalsByCurrency(
      currencyCode: curCode,
    );

    String fmtMinor(int m) => formatMinorUnits(m.abs(), curRow);

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DropdownButton<String>(
            value: curCode,
            onChanged: (v) => setState(() => _selectedCurrency = v),
            items: [
              for (final c in currencies)
                DropdownMenuItem(value: c, child: Text(c)),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ListView(
              children: [
                _StatTile(
                  title: 'Expense this month',
                  value: fmtMinor(data.spentThisMonthMinor),
                ),
                _StatTile(
                  title: 'Income this month',
                  value: fmtMinor(data.earnedThisMonthMinor),
                ),
                _StatTile(
                  title: 'Expense this year',
                  value: fmtMinor(data.spentThisYearMinor),
                ),
                _StatTile(
                  title: '% of budgets met',
                  value:
                      '${data.budgetsMetPercent.toStringAsFixed(0)}%,'
                      ' saved ${fmtMinor(data.savedMinor)}',
                ),
                _StatTile(
                  title: 'Income:Expense ratio (month)',
                  value: data.earningSpendingRatio == null
                      ? '∞ (no spend)'
                      : data.earningSpendingRatio!.toStringAsFixed(2),
                ),
                const SizedBox(height: 8),
                const _SectionHeader(title: 'By account (income vs expense)'),
                ...[
                  for (final t in perAccount)
                    _AccountTotalsTile(
                      name: t.accountName,
                      income: fmtMinor(t.earnedMinor),
                      expense: fmtMinor(t.spentMinor),
                    ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final String title;
  final String value;
  const _StatTile({required this.title, required this.value});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        title: Text(title),
        trailing: Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
      child: Text(title, style: Theme.of(context).textTheme.titleMedium),
    );
  }
}

class _AccountTotalsTile extends StatelessWidget {
  final String name;
  final String income;
  final String expense;

  const _AccountTotalsTile({
    required this.name,
    required this.income,
    required this.expense,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        title: Text(name),
        trailing: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [Text('Income: $income'), Text('Expense: $expense')],
        ),
      ),
    );
  }
}
