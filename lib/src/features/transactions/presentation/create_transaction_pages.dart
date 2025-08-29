import 'package:flutter/material.dart';

import '../../../repositories/accounts_repository.dart';
import '../../../repositories/currencies_repository.dart';
import '../../../repositories/transactions_repository.dart';
import '../../../repositories/transaction_types_repository.dart';
import '../../../utils/currency_format.dart';
import '../../accounts/domain/account_icon_choices.dart';
import '../../accounts/presentation/widgets/account_color_selector.dart';
import '../../accounts/presentation/widgets/account_icon_selector.dart';
import '../../../utils/color_parse.dart';
import '../../../utils/date_format.dart';

// Shared type picker used by all pages. Type selection is REQUIRED.
class _TypePicker extends StatefulWidget {
  const _TypePicker({
    required this.typesRepo,
    required this.appliesTo,
    required this.onChanged,
  });

  final TransactionTypesRepository typesRepo;
  final String appliesTo; // inbound | outbound | internal
  final ValueChanged<int> onChanged; // required selection

  @override
  State<_TypePicker> createState() => _TypePickerState();
}

class _TypePickerState extends State<_TypePicker> {
  int? _typeId;

  @override
  void initState() {
    super.initState();
    _typeId = null;
  }

  @override
  Widget build(BuildContext context) {
    final list = widget.typesRepo
        .listAll()
        .where((t) => t.appliesTo == widget.appliesTo)
        .toList();

    return Row(
      children: [
        Expanded(
          child: InputDecorator(
            decoration: const InputDecoration(labelText: 'Type', border: OutlineInputBorder()),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<int>(
                value: _typeId,
                isExpanded: true,
                hint: const Text('Select a type'),
                items: [
                  for (final t in list)
                    DropdownMenuItem(
                      value: t.id,
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 12,
                            backgroundColor: parseHexColor(t.color),
                            child: t.iconKind == 'emoji'
                                ? Text(t.iconValue)
                                : Icon(
                                    kAccountIconChoices[t.iconValue] ?? Icons.category,
                                    color: Colors.white,
                                    size: 16,
                                  ),
                          ),
                          const SizedBox(width: 8),
                          Text(t.name),
                        ],
                      ),
                    ),
                ],
                onChanged: (v) {
                  if (v == null) return;
                  setState(() => _typeId = v);
                  widget.onChanged(v);
                },
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        OutlinedButton.icon(
          icon: const Icon(Icons.add),
          label: const Text('New type'),
          onPressed: () async {
            final createdId = await Navigator.of(context).push<int>(
              MaterialPageRoute(
                builder: (_) => TypeCreatorPage(
                  typesRepo: widget.typesRepo,
                  appliesTo: widget.appliesTo,
                ),
              ),
            );
            if (createdId != null) {
              setState(() => _typeId = createdId);
              widget.onChanged(createdId);
            }
          },
        ),
      ],
    );
  }
}

class NewInboundPage extends StatefulWidget {
  const NewInboundPage({
    super.key,
    required this.accountsRepo,
    required this.currenciesRepo,
    required this.txRepo,
    required this.typesRepo,
    this.initialAccountId,
  });

  final AccountsRepository accountsRepo;
  final CurrenciesRepository currenciesRepo;
  final TransactionsRepository txRepo;
  final TransactionTypesRepository typesRepo;
  final int? initialAccountId;

  @override
  State<NewInboundPage> createState() => _NewInboundPageState();
}

class _NewInboundPageState extends State<NewInboundPage> {
  int? _accountId;
  final _amount = TextEditingController(); // major units
  final _desc = TextEditingController();
  int? _typeId; // required
  DateTime _occurredAt = DateTime.now();

  @override
  void initState() {
    super.initState();
    _accountId = widget.initialAccountId;
  }

  @override
  void dispose() {
    _amount.dispose();
    _desc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accounts = widget.accountsRepo.listAll();
    return Scaffold(
      appBar: AppBar(title: const Text('Funds in')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _accountSelector(accounts),
              const SizedBox(height: 12),
              _amountField(accounts),
              const SizedBox(height: 12),
              _TypePicker(
                typesRepo: widget.typesRepo,
                appliesTo: 'inbound',
                onChanged: (id) => _typeId = id,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _desc,
                decoration: const InputDecoration(labelText: 'Description (optional)', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              _whenRow(context),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(onPressed: _save, child: const Text('Add funds')),
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _accountSelector(List<AccountRow> accounts) {
    return InputDecorator(
      decoration: const InputDecoration(labelText: 'Account', border: OutlineInputBorder()),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          value: _accountId,
          isExpanded: true,
          items: [
            for (final a in accounts)
              DropdownMenuItem(
                value: a.id,
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 12,
                      backgroundColor: parseHexColor(a.color),
                      child: Icon(
                        kAccountIconChoices[a.icon] ?? Icons.account_balance,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(a.name),
                  ],
                ),
              )
          ],
          onChanged: (v) => setState(() => _accountId = v),
        ),
      ),
    );
  }

  Widget _amountField(List<AccountRow> accounts) {
    final acct = accounts.firstWhere((a) => a.id == _accountId, orElse: () => accounts.isNotEmpty ? accounts.first : (throw StateError('No accounts')));
    final cur = widget.currenciesRepo.getByCode(acct.currencyCode) ??
        CurrencyRow(code: acct.currencyCode, symbol: '', symbolPosition: 'before', decimalPlaces: 2);
    final sym = cur.symbol ?? cur.code;
    return TextField(
      controller: _amount,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(labelText: 'Amount ($sym)', hintText: 'e.g., 12.34', border: const OutlineInputBorder()),
    );
  }

  Widget _whenRow(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text('When: ${formatDateTimeShort(_occurredAt)}')),
        TextButton(
          onPressed: () async {
            final d = await showDatePicker(
              context: context,
              initialDate: _occurredAt,
              firstDate: DateTime(2000),
              lastDate: DateTime(2100),
            );
            if (d == null) return;
            if (!context.mounted) return;
            final t = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(_occurredAt));
            if (!context.mounted) return;
            setState(() => _occurredAt = DateTime(d.year, d.month, d.day, t?.hour ?? 0, t?.minute ?? 0));
          },
          child: const Text('Pick date/time'),
        ),
      ],
    );
  }

  void _save() {
    try {
      if (_accountId == null) throw Exception('Select account');
      if (_typeId == null) throw Exception('Select a type');
      final accounts = widget.accountsRepo.listAll();
      final acct = accounts.firstWhere((a) => a.id == _accountId);
      final cur = widget.currenciesRepo.getByCode(acct.currencyCode) ??
          CurrencyRow(code: acct.currencyCode, symbol: '', symbolPosition: 'before', decimalPlaces: 2);
      final amtMinor = parseMajorToMinor(_amount.text.trim(), cur);
      widget.txRepo.createInbound(
        accountId: _accountId!,
        amountMinor: amtMinor,
        occurredAt: _occurredAt,
        typeId: _typeId,
        description: _desc.text.trim(),
      );
      Navigator.pop(context, true);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
    }
  }
}

class NewOutboundPage extends StatefulWidget {
  const NewOutboundPage({
    super.key,
    required this.accountsRepo,
    required this.currenciesRepo,
    required this.txRepo,
    required this.typesRepo,
    this.initialAccountId,
  });

  final AccountsRepository accountsRepo;
  final CurrenciesRepository currenciesRepo;
  final TransactionsRepository txRepo;
  final TransactionTypesRepository typesRepo;
  final int? initialAccountId;

  @override
  State<NewOutboundPage> createState() => _NewOutboundPageState();
}

class _NewOutboundPageState extends State<NewOutboundPage> {
  int? _accountId;
  final _amount = TextEditingController(); // major
  final _desc = TextEditingController();
  int? _typeId;
  DateTime _occurredAt = DateTime.now();

  @override
  void initState() {
    super.initState();
    _accountId = widget.initialAccountId;
  }

  @override
  void dispose() {
    _amount.dispose();
    _desc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accounts = widget.accountsRepo.listAll();
    return Scaffold(
      appBar: AppBar(title: const Text('Funds out')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _accountSelector(accounts),
              const SizedBox(height: 12),
              _amountField(accounts),
              const SizedBox(height: 12),
              _TypePicker(
                typesRepo: widget.typesRepo,
                appliesTo: 'outbound',
                onChanged: (id) => _typeId = id,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _desc,
                decoration: const InputDecoration(labelText: 'Description (optional)', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              _whenRow(context),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(onPressed: _save, child: const Text('Record expense')),
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _accountSelector(List<AccountRow> accounts) {
    return InputDecorator(
      decoration: const InputDecoration(labelText: 'Account', border: OutlineInputBorder()),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          value: _accountId,
          isExpanded: true,
          items: [for (final a in accounts) DropdownMenuItem(value: a.id, child: Text(a.name))],
          onChanged: (v) => setState(() => _accountId = v),
        ),
      ),
    );
  }

  Widget _amountField(List<AccountRow> accounts) {
    final acct = accounts.firstWhere((a) => a.id == _accountId, orElse: () => accounts.isNotEmpty ? accounts.first : (throw StateError('No accounts')));
    final cur = widget.currenciesRepo.getByCode(acct.currencyCode) ??
        CurrencyRow(code: acct.currencyCode, symbol: '', symbolPosition: 'before', decimalPlaces: 2);
    final sym = cur.symbol ?? cur.code;
    return TextField(
      controller: _amount,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(labelText: 'Amount ($sym)', hintText: 'e.g., 12.34', border: const OutlineInputBorder()),
    );
  }

  Widget _whenRow(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text('When: ${formatDateTimeShort(_occurredAt)}')),
        TextButton(
          onPressed: () async {
            final d = await showDatePicker(
              context: context,
              initialDate: _occurredAt,
              firstDate: DateTime(2000),
              lastDate: DateTime(2100),
            );
            if (d == null) return;
            if (!context.mounted) return;
            final t = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(_occurredAt));
            if (!context.mounted) return;
            setState(() => _occurredAt = DateTime(d.year, d.month, d.day, t?.hour ?? 0, t?.minute ?? 0));
          },
          child: const Text('Pick date/time'),
        ),
      ],
    );
  }

  void _save() {
    try {
      if (_accountId == null) throw Exception('Select account');
      if (_typeId == null) throw Exception('Select a type');
      final accounts = widget.accountsRepo.listAll();
      final acct = accounts.firstWhere((a) => a.id == _accountId);
      final cur = widget.currenciesRepo.getByCode(acct.currencyCode) ??
          CurrencyRow(code: acct.currencyCode, symbol: '', symbolPosition: 'before', decimalPlaces: 2);
      final amtMinor = parseMajorToMinor(_amount.text.trim(), cur);
      widget.txRepo.createOutbound(
        accountId: _accountId!,
        amountMinor: amtMinor,
        occurredAt: _occurredAt,
        typeId: _typeId,
        description: _desc.text.trim(),
      );
      Navigator.pop(context, true);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
    }
  }
}

class NewTransferPage extends StatefulWidget {
  const NewTransferPage({
    super.key,
    required this.accountsRepo,
    required this.currenciesRepo,
    required this.txRepo,
    required this.typesRepo,
    this.initialAccountId,
  });

  final AccountsRepository accountsRepo;
  final CurrenciesRepository currenciesRepo;
  final TransactionsRepository txRepo;
  final TransactionTypesRepository typesRepo;
  final int? initialAccountId;

  @override
  State<NewTransferPage> createState() => _NewTransferPageState();
}

class _NewTransferPageState extends State<NewTransferPage> {
  int? _fromAccountId;
  int? _toAccountId;
  final _amount = TextEditingController(); // major, same currency
  final _outAmount = TextEditingController(); // major, from currency
  final _inAmount = TextEditingController(); // major, to currency
  final _desc = TextEditingController();
  DateTime _occurredAt = DateTime.now();

  @override
  void initState() {
    super.initState();
    _fromAccountId = widget.initialAccountId;
  }

  @override
  void dispose() {
    _amount.dispose();
    _outAmount.dispose();
    _inAmount.dispose();
    _desc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accounts = widget.accountsRepo.listAll();
    return Scaffold(
      appBar: AppBar(title: const Text('Move funds')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: _accountDropdown('From account', accounts, _fromAccountId, (v) => setState(() => _fromAccountId = v))),
                  const SizedBox(width: 12),
                  Expanded(child: _accountDropdown('To account', accounts, _toAccountId, (v) => setState(() => _toAccountId = v))),
                ],
              ),
              const SizedBox(height: 12),
              _amountFields(accounts),
              const SizedBox(height: 12),
              TextField(
                controller: _desc,
                decoration: const InputDecoration(labelText: 'Description (optional)', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              _whenRow(context),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(onPressed: _save, child: const Text('Move')),
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _accountDropdown(String label, List<AccountRow> accounts, int? value, ValueChanged<int?> onChanged) {
    return InputDecorator(
      decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          value: value,
          isExpanded: true,
          items: [
            for (final a in accounts)
              DropdownMenuItem(
                value: a.id,
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 12,
                      backgroundColor: parseHexColor(a.color),
                      child: Icon(
                        kAccountIconChoices[a.icon] ?? Icons.account_balance,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(a.name),
                  ],
                ),
              )
          ],
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _amountFields(List<AccountRow> accounts) {
    final from = accounts.firstWhere((a) => a.id == _fromAccountId, orElse: () => accounts.isNotEmpty ? accounts.first : (throw StateError('No accounts')));
    final to = accounts.firstWhere((a) => a.id == _toAccountId, orElse: () => accounts.isNotEmpty ? accounts.first : (throw StateError('No accounts')));
    final fromCur = widget.currenciesRepo.getByCode(from.currencyCode) ?? CurrencyRow(code: from.currencyCode, symbol: '', symbolPosition: 'before', decimalPlaces: 2);
    final toCur = widget.currenciesRepo.getByCode(to.currencyCode) ?? CurrencyRow(code: to.currencyCode, symbol: '', symbolPosition: 'before', decimalPlaces: 2);
    final same = from.currencyCode == to.currencyCode;
    if (same) {
      final sym = fromCur.symbol ?? fromCur.code;
      return TextField(
        controller: _amount,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(labelText: 'Amount ($sym)', hintText: 'e.g., 12.34', border: const OutlineInputBorder()),
      );
    }
    final symOut = fromCur.symbol ?? fromCur.code;
    final symIn = toCur.symbol ?? toCur.code;
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _outAmount,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(labelText: 'Out ($symOut)', hintText: 'e.g., 12.34', border: const OutlineInputBorder()),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: TextField(
            controller: _inAmount,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(labelText: 'In ($symIn)', hintText: 'e.g., 12.34', border: const OutlineInputBorder()),
          ),
        ),
      ],
    );
  }

  Widget _whenRow(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text('When: ${formatDateTimeShort(_occurredAt)}')),
        TextButton(
          onPressed: () async {
            final d = await showDatePicker(
              context: context,
              initialDate: _occurredAt,
              firstDate: DateTime(2000),
              lastDate: DateTime(2100),
            );
            if (d == null) return;
            if (!context.mounted) return;
            final t = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(_occurredAt));
            if (!context.mounted) return;
            setState(() => _occurredAt = DateTime(d.year, d.month, d.day, t?.hour ?? 0, t?.minute ?? 0));
          },
          child: const Text('Pick date/time'),
        ),
      ],
    );
  }

  void _save() {
    try {
      if (_fromAccountId == null || _toAccountId == null) throw Exception('Select both accounts');
      if (_fromAccountId == _toAccountId) throw Exception('Accounts must differ');
      final accounts = widget.accountsRepo.listAll();
      final from = accounts.firstWhere((a) => a.id == _fromAccountId);
      final to = accounts.firstWhere((a) => a.id == _toAccountId);
      final fromCur = widget.currenciesRepo.getByCode(from.currencyCode) ?? CurrencyRow(code: from.currencyCode, symbol: '', symbolPosition: 'before', decimalPlaces: 2);
      final toCur = widget.currenciesRepo.getByCode(to.currencyCode) ?? CurrencyRow(code: to.currencyCode, symbol: '', symbolPosition: 'before', decimalPlaces: 2);
      if (from.currencyCode == to.currencyCode) {
        final amt = parseMajorToMinor(_amount.text.trim(), fromCur);
        widget.txRepo.createInternalSameCurrency(
          fromAccountId: _fromAccountId!,
          toAccountId: _toAccountId!,
          amountMinor: amt,
          occurredAt: _occurredAt,
          typeId: null,
          description: _desc.text.trim(),
        );
      } else {
        final outAmt = parseMajorToMinor(_outAmount.text.trim(), fromCur);
        final inAmt = parseMajorToMinor(_inAmount.text.trim(), toCur);
        widget.txRepo.createInternalCrossCurrency(
          fromAccountId: _fromAccountId!,
          toAccountId: _toAccountId!,
          outAmountMinor: outAmt,
          inAmountMinor: inAmt,
          occurredAt: _occurredAt,
          typeId: null,
          description: _desc.text.trim(),
        );
      }
      Navigator.pop(context, true);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
    }
  }
}

class TypeCreatorPage extends StatefulWidget {
  const TypeCreatorPage({super.key, required this.typesRepo, required this.appliesTo});

  final TransactionTypesRepository typesRepo;
  final String appliesTo; // inbound|outbound|internal

  @override
  State<TypeCreatorPage> createState() => _TypeCreatorPageState();
}

class _TypeCreatorPageState extends State<TypeCreatorPage> {
  final _name = TextEditingController();
  Color _color = const Color(0xFF4CAF50);
  String _mode = 'material'; // or 'emoji'
  String _materialIcon = 'category';
  final _emoji = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    _emoji.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('New Type')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _name,
                decoration: const InputDecoration(labelText: 'Name', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 16),
              Text('Color', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              AccountColorSelector(
                color: _color,
                onChanged: (c) => setState(() => _color = c.withValues(alpha: 1.0)),
              ),
              const SizedBox(height: 16),
              InputDecorator(
                decoration: const InputDecoration(labelText: 'Icon mode', border: OutlineInputBorder()),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _mode,
                    isExpanded: true,
                    items: const [
                      DropdownMenuItem(value: 'material', child: Text('Material icon')),
                      DropdownMenuItem(value: 'emoji', child: Text('Emoji')),
                    ],
                    onChanged: (v) => setState(() => _mode = v ?? 'material'),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              if (_mode == 'material')
                SizedBox(
                  height: 300,
                  child: AccountIconSelector(
                    icons: kAccountIconChoices,
                    selectedKey: _materialIcon,
                    onChanged: (v) => setState(() => _materialIcon = v),
                    maxItemExtent: 88,
                  ),
                )
              else
                TextField(
                  controller: _emoji,
                  decoration: const InputDecoration(labelText: 'Emoji', hintText: 'e.g., 🍕', border: OutlineInputBorder()),
                ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _save,
                  child: const Text('Create type'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _save() {
    try {
      final name = _name.text.trim();
      if (name.isEmpty) throw Exception('Name required');
      final colorHex = _toHex(_color);
      int id;
      if (_mode == 'emoji') {
        final emoji = _emoji.text.trim();
        if (emoji.isEmpty) throw Exception('Emoji required');
        id = widget.typesRepo.create(name: name, color: colorHex, iconKind: 'emoji', iconValue: emoji, appliesTo: widget.appliesTo);
      } else {
        id = widget.typesRepo.create(name: name, color: colorHex, iconKind: 'material', iconValue: _materialIcon, appliesTo: widget.appliesTo);
      }
      Navigator.pop(context, id);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
    }
  }

  String _toHex(Color c) {
    final argb = c.toARGB32();
    final r = (argb >> 16) & 0xff;
    final g = (argb >> 8) & 0xff;
    final b = argb & 0xff;
    return '#${r.toRadixString(16).padLeft(2, '0')}${g.toRadixString(16).padLeft(2, '0')}${b.toRadixString(16).padLeft(2, '0')}'.toUpperCase();
  }
}
