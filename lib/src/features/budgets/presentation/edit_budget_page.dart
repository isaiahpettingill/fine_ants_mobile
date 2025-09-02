import 'package:flutter/material.dart';

import '../../../repositories/budgets_repository.dart';
import '../../../repositories/transaction_types_repository.dart';
import '../../../repositories/currencies_repository.dart';
import '../../../utils/currency_format.dart';
import '../../../utils/date_format.dart';

class EditBudgetPage extends StatefulWidget {
  final BudgetRow? initial;
  final TransactionTypesRepository typesRepo;
  final CurrenciesRepository currenciesRepo;
  final BudgetsRepository budgetsRepo;
  final DateTime? effectiveFromOverride;
  const EditBudgetPage({
    super.key,
    this.initial,
    required this.typesRepo,
    required this.currenciesRepo,
    required this.budgetsRepo,
    this.effectiveFromOverride,
  });

  @override
  State<EditBudgetPage> createState() => _EditBudgetPageState();
}

class _EditBudgetPageState extends State<EditBudgetPage> {
  int? _typeId;
  String _period = 'month';
  String? _currencyCode;
  final _amount = TextEditingController();
  DateTime _effectiveFrom = DateTime.now();

  @override
  void initState() {
    super.initState();
    final init = widget.initial;
    if (init != null) {
      _typeId = init.typeId;
      _period = init.period;
      _currencyCode = init.currencyCode;
    }
    if (widget.effectiveFromOverride != null) {
      _effectiveFrom = widget.effectiveFromOverride!;
    }
  }

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final types = widget.typesRepo
        .listAll()
        .where((t) => t.appliesTo == 'outbound' || t.appliesTo == 'any')
        .toList();
    final currencies = widget.currenciesRepo.listAll();
    final cur = _currencyCode != null
        ? widget.currenciesRepo.getByCode(_currencyCode!)
        : (currencies.isNotEmpty ? currencies.first : null);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.initial == null ? 'New Budget' : 'Edit Budget'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            InputDecorator(
              decoration: const InputDecoration(
                labelText: 'Category',
                border: OutlineInputBorder(),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<int>(
                  value: _typeId,
                  isExpanded: true,
                  hint: const Text('Select category'),
                  items: [
                    for (final t in types)
                      DropdownMenuItem(value: t.id, child: Text(t.name)),
                  ],
                  onChanged: (v) => setState(() => _typeId = v),
                ),
              ),
            ),
            const SizedBox(height: 12),
            InputDecorator(
              decoration: const InputDecoration(
                labelText: 'Period',
                border: OutlineInputBorder(),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _period,
                  isExpanded: true,
                  items: const [
                    DropdownMenuItem(value: 'week', child: Text('Weekly')),
                    DropdownMenuItem(value: 'month', child: Text('Monthly')),
                    DropdownMenuItem(value: 'year', child: Text('Yearly')),
                  ],
                  onChanged: (v) => setState(() => _period = v ?? 'month'),
                ),
              ),
            ),
            const SizedBox(height: 12),
            InputDecorator(
              decoration: const InputDecoration(
                labelText: 'Currency',
                border: OutlineInputBorder(),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _currencyCode,
                  isExpanded: true,
                  hint: const Text('Select currency'),
                  items: [
                    for (final c in currencies)
                      DropdownMenuItem(value: c.code, child: Text(c.code)),
                  ],
                  onChanged: (v) => setState(() => _currencyCode = v),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Effective from: ${formatDateTimeShort(_effectiveFrom)}',
                  ),
                ),
                TextButton(
                  onPressed: () async {
                    final d = await showDatePicker(
                      context: context,
                      initialDate: _effectiveFrom,
                      firstDate: DateTime(2000),
                      lastDate: DateTime(2100),
                    );
                    if (d == null) return;
                    if (!context.mounted) return;
                    final t = await showTimePicker(
                      context: context,
                      initialTime: TimeOfDay.fromDateTime(_effectiveFrom),
                    );
                    if (!context.mounted) return;
                    setState(() {
                      _effectiveFrom = DateTime(
                        d.year,
                        d.month,
                        d.day,
                        t?.hour ?? 0,
                        t?.minute ?? 0,
                      );
                    });
                  },
                  child: const Text('Pick effective date/time'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _amount,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
                signed: false,
              ),
              decoration: const InputDecoration(
                labelText: 'Budget amount',
                hintText: 'e.g., 100.00',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton(
                onPressed: () => _save(cur),
                child: Text(widget.initial == null ? 'Create' : 'Save'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _save(CurrencyRow? cur) {
    if (_typeId == null || _currencyCode == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select category and currency')),
      );
      return;
    }
    final currency = cur ?? widget.currenciesRepo.getByCode(_currencyCode!);
    if (currency == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Invalid currency')));
      return;
    }
    int amountMinor;
    try {
      amountMinor = parseMajorToMinor(_amount.text.trim(), currency);
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Amount error: $e')));
      return;
    }
    // Always create a new version to preserve history.
    widget.budgetsRepo.create(
      typeId: _typeId!,
      period: _period,
      currencyCode: _currencyCode!,
      amountMinor: amountMinor,
      effectiveFrom: _effectiveFrom,
    );
    Navigator.of(context).pop(true);
  }
}
