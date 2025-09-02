import 'package:flutter/material.dart';

import '../../../repositories/budgets_repository.dart';
import '../../../repositories/transactions_repository.dart';
import '../../../repositories/accounts_repository.dart';
import '../../../repositories/currencies_repository.dart';
import '../../../repositories/transaction_types_repository.dart';
import '../../../utils/currency_format.dart';
import '../../../utils/period_ranges.dart';
import '../../../utils/date_format.dart';
import 'edit_budget_page.dart';

class BudgetDetailPage extends StatefulWidget {
  const BudgetDetailPage({
    super.key,
    required this.budget,
    required this.budgetsRepo,
    required this.typesRepo,
    required this.currenciesRepo,
    required this.accountsRepo,
    required this.txRepo,
  });

  final BudgetRow budget;
  final BudgetsRepository budgetsRepo;
  final TransactionTypesRepository typesRepo;
  final CurrenciesRepository currenciesRepo;
  final AccountsRepository accountsRepo;
  final TransactionsRepository txRepo;

  @override
  State<BudgetDetailPage> createState() => _BudgetDetailPageState();
}

class _BudgetDetailPageState extends State<BudgetDetailPage> {
  late BudgetRow _budget;
  late PeriodRange _range;
  late List<TransactionRow> _items;
  DateTime _anchor = DateTime.now();

  @override
  void initState() {
    super.initState();
    _budget = widget.budget;
    _load();
  }

  void _load() {
    // Pick budget version effective for the current anchor date
    final b =
        widget.budgetsRepo.getForDate(
          typeId: _budget.typeId,
          period: _budget.period,
          currencyCode: _budget.currencyCode,
          onDate: _anchor,
        ) ??
        _budget;
    _budget = b;
    _range = currentPeriodRange(_budget.period, now: _anchor);
    _items = widget.txRepo.listOutboundByTypeCurrencyInRange(
      typeId: _budget.typeId,
      currencyCode: _budget.currencyCode,
      start: _range.start,
      endExclusive: _range.endExclusive,
    );
  }

  @override
  Widget build(BuildContext context) {
    final type = widget.typesRepo.getById(_budget.typeId);
    final cur =
        widget.currenciesRepo.getByCode(_budget.currencyCode) ??
        CurrencyRow(
          code: _budget.currencyCode,
          symbol: '',
          symbolPosition: 'before',
          decimalPlaces: 2,
        );
    final spentMinor = widget.budgetsRepo.getSpentForBudgetInRange(
      _budget,
      _range.start,
      _range.endExclusive,
    );
    final spentStr = formatMinorUnits(spentMinor, cur);
    final budgetStr = formatMinorUnits(_budget.amountMinor, cur);
    final pct = _budget.amountMinor == 0
        ? 0.0
        : (spentMinor / _budget.amountMinor).clamp(0.0, 1.0);

    return Scaffold(
      appBar: AppBar(
        title: Text(type?.name ?? 'Budget'),
        actions: [
          IconButton(
            tooltip: 'Edit budget',
            icon: const Icon(Icons.edit),
            onPressed: () async {
              final changed = await Navigator.of(context).push<bool>(
                MaterialPageRoute(
                  builder: (_) => EditBudgetPage(
                    initial: _budget,
                    typesRepo: widget.typesRepo,
                    currenciesRepo: widget.currenciesRepo,
                    budgetsRepo: widget.budgetsRepo,
                    effectiveFromOverride: _range.start,
                  ),
                ),
              );
              if (changed == true) {
                // Reload updated budget row and refresh list
                setState(() {
                  _load();
                });
              }
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => setState(() => _load()),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 12, 8, 4),
              child: _periodPagerRow(context),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _periodHeaderText(
                      _budget.period,
                      _anchor,
                      _budget.currencyCode,
                    ),
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                  const SizedBox(height: 6),
                  Text('$spentStr of $budgetStr'),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: pct.toDouble(),
                      minHeight: 8,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView.builder(
                itemCount: _items.length,
                itemBuilder: (context, index) {
                  final t = _items[index];
                  return _BudgetTransactionTile(
                    tx: t,
                    accountsRepo: widget.accountsRepo,
                    currency: cur,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  DateTime _prevAnchor(String period, DateTime anchor) {
    switch (period) {
      case 'week':
        return anchor.subtract(const Duration(days: 7));
      case 'year':
        return DateTime(
          anchor.year - 1,
          anchor.month,
          anchor.day,
          anchor.hour,
          anchor.minute,
          anchor.second,
          anchor.millisecond,
          anchor.microsecond,
        );
      case 'month':
      default:
        final y = anchor.year;
        final m = anchor.month - 1;
        final newY = m >= 1 ? y : y - 1;
        final newM = m >= 1 ? m : 12;
        return DateTime(newY, newM, anchor.day);
    }
  }

  DateTime _nextAnchor(String period, DateTime anchor) {
    switch (period) {
      case 'week':
        return anchor.add(const Duration(days: 7));
      case 'year':
        return DateTime(
          anchor.year + 1,
          anchor.month,
          anchor.day,
          anchor.hour,
          anchor.minute,
          anchor.second,
          anchor.millisecond,
          anchor.microsecond,
        );
      case 'month':
      default:
        final y = anchor.year;
        final m = anchor.month + 1;
        final newY = m <= 12 ? y : y + 1;
        final newM = m <= 12 ? m : 1;
        return DateTime(newY, newM, anchor.day);
    }
  }

  String _periodHeaderText(
    String period,
    DateTime anchor,
    String currencyCode,
  ) {
    String when;
    switch (period) {
      case 'week':
        final r = currentPeriodRange('week', now: anchor);
        when =
            '${formatDateTimeShort(r.start)} – ${formatDateTimeShort(r.endExclusive.subtract(const Duration(seconds: 1)))}';
        break;
      case 'year':
        when = '${anchor.year}';
        break;
      case 'month':
      default:
        when =
            '${anchor.year.toString().padLeft(4, '0')}-${anchor.month.toString().padLeft(2, '0')}';
        break;
    }
    return '${period.toUpperCase()} • $currencyCode • $when';
  }

  Widget _periodPagerRow(BuildContext context) {
    final theme = Theme.of(context);
    final label = _periodLabel(_budget.period, _anchor);
    return Row(
      children: [
        IconButton(
          tooltip: 'Previous',
          onPressed: () => setState(() {
            _anchor = _prevAnchor(_budget.period, _anchor);
            _load();
          }),
          icon: const Icon(Icons.chevron_left),
        ),
        Expanded(
          child: Center(
            child: Text(
              label,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
        IconButton(
          tooltip: 'Next',
          onPressed: () => setState(() {
            _anchor = _nextAnchor(_budget.period, _anchor);
            _load();
          }),
          icon: const Icon(Icons.chevron_right),
        ),
      ],
    );
  }

  String _periodLabel(String period, DateTime anchor) {
    switch (period) {
      case 'week':
        final r = currentPeriodRange('week', now: anchor);
        return '${_formatDate(r.start)} – ${_formatDate(r.endExclusive.subtract(const Duration(days: 1)))}';
      case 'year':
        return anchor.year.toString();
      case 'month':
      default:
        const months = [
          'January',
          'February',
          'March',
          'April',
          'May',
          'June',
          'July',
          'August',
          'September',
          'October',
          'November',
          'December',
        ];
        return '${months[anchor.month - 1]} ${anchor.year}';
    }
  }

  String _formatDate(DateTime d) {
    return '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }
}

class _BudgetTransactionTile extends StatelessWidget {
  const _BudgetTransactionTile({
    required this.tx,
    required this.accountsRepo,
    required this.currency,
  });

  final TransactionRow tx;
  final AccountsRepository accountsRepo;
  final CurrencyRow currency;

  @override
  Widget build(BuildContext context) {
    final acct = tx.accountId == null
        ? null
        : accountsRepo.listAll().firstWhere((a) => a.id == tx.accountId);
    final when = formatDateTimeShort(tx.occurredAt);
    final desc = tx.description;
    final subtitleBits = [if (acct != null) acct.name, when];
    final amt = tx.amount ?? 0;
    final amtStr = formatMinorUnits(amt.abs(), currency);
    final amtColor = Colors.red.shade700;
    return ListTile(
      leading: const CircleAvatar(child: Icon(Icons.arrow_upward)),
      title: Text(desc == null || desc.isEmpty ? 'Outbound' : desc),
      subtitle: Text(subtitleBits.join(' • ')),
      trailing: Text(
        amtStr,
        style: TextStyle(
          color: amtColor,
          fontWeight: FontWeight.w600,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}
