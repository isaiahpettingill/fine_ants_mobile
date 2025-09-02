import 'package:flutter/material.dart';

import '../../../repositories/budgets_repository.dart';
import '../../../repositories/transaction_types_repository.dart';
import '../../../repositories/currencies_repository.dart';
import '../../../repositories/accounts_repository.dart';
import '../../../repositories/transactions_repository.dart';
import 'edit_budget_page.dart';
import 'budget_detail_page.dart';
import '../../../utils/currency_format.dart';
import '../../../utils/period_ranges.dart';
// Removed pinned header; sort is controlled via parent AppBar.

class BudgetsPage extends StatefulWidget {
  final BudgetsRepository budgetsRepo;
  final TransactionTypesRepository typesRepo;
  final CurrenciesRepository currenciesRepo;
  final AccountsRepository accountsRepo;
  final TransactionsRepository txRepo;
  final ValueNotifier<BudgetSort>? sortNotifier;
  const BudgetsPage({
    super.key,
    required this.budgetsRepo,
    required this.typesRepo,
    required this.currenciesRepo,
    required this.accountsRepo,
    required this.txRepo,
    this.sortNotifier,
  });

  @override
  State<BudgetsPage> createState() => _BudgetsPageState();
}

enum BudgetSort { name, size, percent }

class _BudgetsPageState extends State<BudgetsPage>
    with SingleTickerProviderStateMixin {
  BudgetSort _sort = BudgetSort.name;
  // No longer filtering by period; list all latest budgets

  @override
  void initState() {
    super.initState();
    _sort = widget.sortNotifier?.value ?? BudgetSort.name;
    widget.sortNotifier?.addListener(_onSortChanged);
  }

  void _onSortChanged() {
    final v = widget.sortNotifier?.value;
    if (v != null && v != _sort) setState(() => _sort = v);
  }

  @override
  void dispose() {
    widget.sortNotifier?.removeListener(_onSortChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final budgets = widget.budgetsRepo.listLatestPerKey();
    final types = {for (final t in widget.typesRepo.listAll()) t.id: t};
    final entries = <_BudgetEntry>[];
    for (final b in budgets) {
      final range = currentPeriodRange(b.period);
      final spent = widget.budgetsRepo.getSpentForKeyInRange(
        b.typeId,
        b.currencyCode,
        range.start,
        range.endExclusive,
      );
      entries.add(
        _BudgetEntry(
          budget: b,
          typeName: types[b.typeId]?.name ?? 'Unknown',
          typeColor: (types[b.typeId]?.color ?? '#607D8B'),
          spentMinor: spent,
        ),
      );
    }

    entries.sort((a, b) {
      switch (_sort) {
        case BudgetSort.name:
          return a.typeName.toLowerCase().compareTo(b.typeName.toLowerCase());
        case BudgetSort.size:
          return b.budget.amountMinor.compareTo(a.budget.amountMinor);
        case BudgetSort.percent:
          final ap = a.percentSpent;
          final bp = b.percentSpent;
          return bp.compareTo(ap);
      }
    });

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async => setState(() {}),
        child: ListView.builder(
          padding: const EdgeInsets.only(top: 8),
          itemCount: entries.length,
          itemBuilder: (context, index) {
            final e = entries[index];
            final cur =
                widget.currenciesRepo.getByCode(e.budget.currencyCode) ??
                CurrencyRow(
                  code: e.budget.currencyCode,
                  symbol: '',
                  symbolPosition: 'before',
                  decimalPlaces: 2,
                );
            final budgetStr = formatMinorUnits(e.budget.amountMinor, cur);
            final spentStr = formatMinorUnits(e.spentMinor, cur);
            final pct = e.percentSpent;
            final over = e.spentMinor > e.budget.amountMinor;
            final progress = e.budget.amountMinor == 0
                ? 0.0
                : (e.spentMinor / e.budget.amountMinor).clamp(0.0, 1.0);
            final color = over
                ? Colors.red
                : (pct >= 0.75
                      ? Colors.orange
                      : Theme.of(context).colorScheme.primary);

            return Dismissible(
              key: ValueKey(
                'budget_${e.budget.id}_${e.budget.period}_${e.budget.currencyCode}',
              ),
              direction: DismissDirection.endToStart,
              background: Container(
                color: Colors.red,
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: const Icon(Icons.delete, color: Colors.white),
              ),
              confirmDismiss: (_) async {
                final ok =
                    await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Delete budget?'),
                        content: Text(
                          'Delete budget for ${e.typeName} (${e.budget.period}) in ${e.budget.currencyCode}?',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: const Text('Cancel'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            child: const Text('Delete'),
                          ),
                        ],
                      ),
                    ) ??
                    false;
                return ok;
              },
              onDismissed: (_) {
                widget.budgetsRepo.delete(e.budget.id);
                setState(() {});
              },
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: _parseColor(e.typeColor),
                  child: const Icon(Icons.category, color: Colors.white),
                ),
                title: Text(e.typeName),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${e.budget.period.toUpperCase()} • $spentStr of $budgetStr',
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 8,
                        color: color,
                        backgroundColor: Theme.of(
                          context,
                        ).colorScheme.surfaceContainerHighest,
                      ),
                    ),
                  ],
                ),
                trailing: over
                    ? const Icon(Icons.warning_amber, color: Colors.red)
                    : Text('${(pct * 100).toStringAsFixed(0)}%'),
                onTap: () async {
                  final changed = await Navigator.of(context).push<bool>(
                    MaterialPageRoute(
                      builder: (_) => BudgetDetailPage(
                        budget: e.budget,
                        budgetsRepo: widget.budgetsRepo,
                        typesRepo: widget.typesRepo,
                        currenciesRepo: widget.currenciesRepo,
                        accountsRepo: widget.accountsRepo,
                        txRepo: widget.txRepo,
                      ),
                    ),
                  );
                  if (changed == true) setState(() {});
                },
              ),
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'budgets-fab',
        onPressed: () async {
          final created = await Navigator.of(context).push<bool>(
            MaterialPageRoute(
              builder: (_) => EditBudgetPage(
                typesRepo: widget.typesRepo,
                currenciesRepo: widget.currenciesRepo,
                budgetsRepo: widget.budgetsRepo,
              ),
            ),
          );
          if (created == true) setState(() {});
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _BudgetEntry {
  final BudgetRow budget;
  final String typeName;
  final String typeColor;
  final int spentMinor;
  _BudgetEntry({
    required this.budget,
    required this.typeName,
    required this.typeColor,
    required this.spentMinor,
  });

  double get percentSpent => budget.amountMinor == 0
      ? 0.0
      : (spentMinor / budget.amountMinor).toDouble();
}

Color _parseColor(String hex) {
  var h = hex.replaceAll('#', '').trim();
  if (h.length == 3) {
    h = h.split('').map((ch) => ch * 2).join();
  }
  final value = int.tryParse(h, radix: 16) ?? 0x000000;
  return Color(0xFF000000 | value);
}
