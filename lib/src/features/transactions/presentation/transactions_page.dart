import 'package:flutter/material.dart';

import '../../../repositories/transactions_repository.dart';
import '../../../repositories/accounts_repository.dart';
import '../../../repositories/currencies_repository.dart';
import '../../../repositories/transaction_types_repository.dart';
import '../../../utils/currency_format.dart';
import '../../../utils/date_format.dart';
import '../../accounts/domain/account_icon_choices.dart';
import 'create_transaction_pages.dart';

class TransactionsPage extends StatefulWidget {
  final AccountsRepository accountsRepo;
  final TransactionsRepository txRepo;
  final CurrenciesRepository currenciesRepo;
  final TransactionTypesRepository typesRepo;
  const TransactionsPage({
    super.key,
    required this.accountsRepo,
    required this.txRepo,
    required this.currenciesRepo,
    required this.typesRepo,
  });

  @override
  State<TransactionsPage> createState() => _TransactionsPageState();
}

class _TransactionsPageState extends State<TransactionsPage> {
  late List<TransactionRow> _items;
  int? _selectedAccountId; // null = All

  @override
  void initState() {
    super.initState();
    _items = widget.txRepo.listRecent();
  }

  Future<void> _refresh() async {
    setState(() => _items = widget.txRepo.listRecent());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Transactions'),
        actions: [
          IconButton(
            tooltip: 'Manage types',
            icon: const Icon(Icons.category),
            onPressed: () async {
              await Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => _ManageTypesPage(typesRepo: widget.typesRepo),
                ),
              );
              _refresh();
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _accountFilterRow(),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final t = _filtered()[index];
                  return Dismissible(
                  key: ValueKey('tx_${t.id}'),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    color: Colors.red,
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: const Icon(Icons.delete, color: Colors.white),
                  ),
                  confirmDismiss: (_) async {
                    final ok = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('Delete transaction?'),
                            content: const Text('This cannot be undone.'),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                              TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
                            ],
                          ),
                        ) ??
                        false;
                    return ok;
                  },
                  onDismissed: (_) {
                    widget.txRepo.delete(t.id);
                    _refresh();
                  },
                  child: _TransactionTile(
                    tx: t,
                    accountsRepo: widget.accountsRepo,
                    currenciesRepo: widget.currenciesRepo,
                    typesRepo: widget.typesRepo,
                  ),
                  );
                },
                childCount: _filtered().length,
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 80)),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await showModalBottomSheet<void>(
            context: context,
            showDragHandle: true,
            builder: (ctx) => SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    leading: const Icon(Icons.arrow_downward),
                    title: const Text('Funds in'),
                    onTap: () async {
                      Navigator.pop(ctx);
                      final res = await Navigator.of(context).push<bool>(
                        MaterialPageRoute(
                          builder: (_) => NewInboundPage(
                            accountsRepo: widget.accountsRepo,
                            currenciesRepo: widget.currenciesRepo,
                            txRepo: widget.txRepo,
                            typesRepo: widget.typesRepo,
                            initialAccountId: _selectedAccountId,
                          ),
                        ),
                      );
                      if (res == true) _refresh();
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.arrow_upward),
                    title: const Text('Funds out'),
                    onTap: () async {
                      Navigator.pop(ctx);
                      final res = await Navigator.of(context).push<bool>(
                        MaterialPageRoute(
                          builder: (_) => NewOutboundPage(
                            accountsRepo: widget.accountsRepo,
                            currenciesRepo: widget.currenciesRepo,
                            txRepo: widget.txRepo,
                            typesRepo: widget.typesRepo,
                            initialAccountId: _selectedAccountId,
                          ),
                        ),
                      );
                      if (res == true) _refresh();
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.swap_horiz),
                    title: const Text('Move funds'),
                    onTap: () async {
                      Navigator.pop(ctx);
                      final res = await Navigator.of(context).push<bool>(
                        MaterialPageRoute(
                          builder: (_) => NewTransferPage(
                            accountsRepo: widget.accountsRepo,
                            currenciesRepo: widget.currenciesRepo,
                            txRepo: widget.txRepo,
                            typesRepo: widget.typesRepo,
                            initialAccountId: _selectedAccountId,
                          ),
                        ),
                      );
                      if (res == true) _refresh();
                    },
                  ),
                ],
              ),
            ),
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  List<TransactionRow> _filtered() {
    final sel = _selectedAccountId;
    if (sel == null) return _items;
    return _items.where((t) {
      switch (t.kind) {
        case 'inbound':
        case 'outbound':
          return t.accountId == sel;
        case 'internal':
          return t.fromAccountId == sel || t.toAccountId == sel;
        default:
          return true;
      }
    }).toList();
  }

  Widget _accountFilterRow() {
    final accounts = widget.accountsRepo.listAll();
    return Row(
      children: [
        Expanded(
          child: InputDecorator(
            decoration: const InputDecoration(labelText: 'Viewing account', border: OutlineInputBorder()),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<int?>(
                isExpanded: true,
                value: _selectedAccountId,
                items: [
                  const DropdownMenuItem<int?>(value: null, child: Text('All accounts')),
                  for (final a in accounts)
                    DropdownMenuItem<int?>(
                      value: a.id,
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 12,
                            backgroundColor: _parseColor(a.color),
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
                    ),
                ],
                onChanged: (v) => setState(() => _selectedAccountId = v),
              ),
            ),
          ),
        ),
        if (_selectedAccountId != null) ...[
          const SizedBox(width: 8),
          OutlinedButton(
            onPressed: () => setState(() => _selectedAccountId = null),
            child: const Text('Clear'),
          ),
        ],
      ],
    );
  }
}

class _TransactionTile extends StatelessWidget {
  const _TransactionTile({
    required this.tx,
    required this.accountsRepo,
    required this.currenciesRepo,
    required this.typesRepo,
  });

  final TransactionRow tx;
  final AccountsRepository accountsRepo;
  final CurrenciesRepository currenciesRepo;
  final TransactionTypesRepository typesRepo;

  @override
  Widget build(BuildContext context) {
    final type = tx.typeId == null ? null : typesRepo.getById(tx.typeId!);
    final subtitle = _buildSubtitle();
    final leading = _buildLeading(type);
    final trailing = _buildTrailing();
    return ListTile(
      leading: leading,
      title: Text(_title()),
      subtitle: Text(subtitle),
      trailing: trailing,
    );
  }

  String _title() {
    switch (tx.kind) {
      case 'inbound':
        return 'Inbound';
      case 'outbound':
        return 'Outbound';
      case 'internal':
        return 'Transfer';
      default:
        return tx.kind;
    }
  }

  Widget _buildLeading(TransactionTypeRow? type) {
    if (type == null) {
      return const CircleAvatar(child: Icon(Icons.swap_horiz));
    }
    final bg = _parseColor(type.color);
    if (type.iconKind == 'emoji') {
      return CircleAvatar(backgroundColor: bg, child: Text(type.iconValue));
    }
    final icon = kAccountIconChoices[type.iconValue] ?? Icons.category;
    return CircleAvatar(backgroundColor: bg, child: Icon(icon, color: Colors.white));
  }

  String _buildSubtitle() {
    final when = formatDateTimeShort(tx.occurredAt);
    final type = tx.typeId == null ? null : typesRepo.getById(tx.typeId!);
    switch (tx.kind) {
      case 'inbound':
      case 'outbound':
        final acctId = tx.accountId!;
        final acct = accountsRepo.listAll().firstWhere((a) => a.id == acctId);
        final bits = [acct.name, if (type != null) type.name, when];
        final head = tx.description == null || tx.description!.isEmpty ? null : tx.description;
        return head == null ? bits.join(' • ') : '$head\n${bits.join(' • ')}';
      case 'internal':
        final from = accountsRepo.listAll().firstWhere((a) => a.id == tx.fromAccountId);
        final to = accountsRepo.listAll().firstWhere((a) => a.id == tx.toAccountId);
        final path = '${from.name} → ${to.name}';
        final bits = [path, if (type != null) type.name, when];
        final head = tx.description == null || tx.description!.isEmpty ? null : tx.description;
        return head == null ? bits.join(' • ') : '$head\n${bits.join(' • ')}';
      default:
        return when;
    }
  }

  Widget _buildTrailing() {
    switch (tx.kind) {
      case 'inbound':
      case 'outbound':
        final acctId = tx.accountId!;
        final acct = accountsRepo.listAll().firstWhere((a) => a.id == acctId);
        final cur = currenciesRepo.getByCode(acct.currencyCode) ??
            CurrencyRow(code: acct.currencyCode, symbol: '', symbolPosition: 'before', decimalPlaces: 2);
        final s = formatMinorUnits(tx.amount ?? 0, cur);
        final prominent = TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: tx.kind == 'inbound' ? Colors.green.shade700 : Colors.red.shade700,
          fontFeatures: const [FontFeature.tabularFigures()],
        );
        return Text(s, style: prominent, textAlign: TextAlign.right);
      case 'internal':
        final from = accountsRepo.listAll().firstWhere((a) => a.id == tx.fromAccountId);
        final to = accountsRepo.listAll().firstWhere((a) => a.id == tx.toAccountId);
        final fromCur = currenciesRepo.getByCode(from.currencyCode) ??
            CurrencyRow(code: from.currencyCode, symbol: '', symbolPosition: 'before', decimalPlaces: 2);
        final toCur = currenciesRepo.getByCode(to.currencyCode) ??
            CurrencyRow(code: to.currencyCode, symbol: '', symbolPosition: 'before', decimalPlaces: 2);
        if (tx.amount != null) {
          // same currency: one prominent line
          final s = formatMinorUnits(tx.amount!, fromCur);
          return Text(
            s,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
            textAlign: TextAlign.right,
          );
        }
        // cross-currency: show out (red) and in (green)
        final outS = formatMinorUnits(tx.outAmount ?? 0, fromCur);
        final inS = formatMinorUnits(tx.inAmount ?? 0, toCur);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              outS,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Colors.red.shade700,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            Text(
              inS,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Colors.green.shade700,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        );
      default:
        return const SizedBox.shrink();
    }
  }
}

/* class _NewTransactionDialog extends StatefulWidget {
  const _NewTransactionDialog({
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
  State<_NewTransactionDialog> createState() => _NewTransactionDialogState();
}

class _NewTransactionDialogState extends State<_NewTransactionDialog> {
  String _kind = 'inbound';
  int? _accountId;
  int? _fromAccountId;
  int? _toAccountId;
  final _amount = TextEditingController();
  final _outAmount = TextEditingController();
  final _inAmount = TextEditingController();
  final _desc = TextEditingController();
  DateTime _occurredAt = DateTime.now();
  int? _typeId;

  @override
  void dispose() {
    _amount.dispose();
    _outAmount.dispose();
    _inAmount.dispose();
    _desc.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _accountId = widget.initialAccountId;
    _fromAccountId = widget.initialAccountId;
  }

  @override
  Widget build(BuildContext context) {
    final accounts = widget.accountsRepo.listAll();
    final types = widget.typesRepo.listAll();
    return AlertDialog(
      title: const Text('New Transaction'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _kindSelector(),
              const SizedBox(height: 12),
              if (_kind != 'internal')
                _accountDropdown(accounts, (v) => setState(() => _accountId = v)),
              if (_kind == 'internal') ...[
                _fromToDropdown(accounts),
              ],
              const SizedBox(height: 12),
              if (_kind == 'internal') _amountFieldsInternal(accounts) else _amountFieldSingle(accounts),
              const SizedBox(height: 12),
              _typeSelector(types),
              const SizedBox(height: 12),
              TextField(
                controller: _desc,
                decoration: const InputDecoration(labelText: 'Description (optional)', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              _dateField(context),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
        FilledButton(onPressed: _save, child: const Text('Create')),
      ],
    );
  }

  Widget _kindSelector() {
    return InputDecorator(
      decoration: const InputDecoration(labelText: 'Kind', border: OutlineInputBorder()),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _kind,
          items: const [
            DropdownMenuItem(value: 'inbound', child: Text('Inbound')),
            DropdownMenuItem(value: 'outbound', child: Text('Outbound')),
            DropdownMenuItem(value: 'internal', child: Text('Transfer')),
          ],
          onChanged: (v) => setState(() => _kind = v ?? 'inbound'),
        ),
      ),
    );
  }

  Widget _accountDropdown(List<AccountRow> accounts, ValueChanged<int?> onChanged) {
    return InputDecorator(
      decoration: const InputDecoration(labelText: 'Account', border: OutlineInputBorder()),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          value: _accountId,
          isExpanded: true,
          items: [
            for (final a in accounts)
              DropdownMenuItem(value: a.id, child: Text(a.name)),
          ],
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _fromToDropdown(List<AccountRow> accounts) {
    return Row(
      children: [
        Expanded(child: _labeledDropdown('From account', accounts, _fromAccountId, (v) => setState(() => _fromAccountId = v))),
        const SizedBox(width: 12),
        Expanded(child: _labeledDropdown('To account', accounts, _toAccountId, (v) => setState(() => _toAccountId = v))),
      ],
    );
  }

  Widget _labeledDropdown(String label, List<AccountRow> accounts, int? value, ValueChanged<int?> onChanged) {
    return InputDecorator(
      decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          value: value,
          isExpanded: true,
          items: [
            for (final a in accounts)
              DropdownMenuItem(value: a.id, child: Text(a.name)),
          ],
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _amountFieldSingle(List<AccountRow> accounts) {
    final acct = accounts.firstWhere((a) => a.id == _accountId, orElse: () => accounts.isNotEmpty ? accounts.first : (throw StateError('No accounts')));
    final cur = widget.currenciesRepo.getByCode(acct.currencyCode) ?? CurrencyRow(code: acct.currencyCode, symbol: '', symbolPosition: 'before', decimalPlaces: 2);
    return TextField(
      controller: _amount,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(labelText: 'Amount (${cur.code}, minor units)', border: const OutlineInputBorder()),
    );
  }

  Widget _amountFieldsInternal(List<AccountRow> accounts) {
    final from = accounts.firstWhere((a) => a.id == _fromAccountId, orElse: () => accounts.isNotEmpty ? accounts.first : (throw StateError('No accounts')));
    final to = accounts.firstWhere((a) => a.id == _toAccountId, orElse: () => accounts.isNotEmpty ? accounts.first : (throw StateError('No accounts')));
    final fromCur = widget.currenciesRepo.getByCode(from.currencyCode) ?? CurrencyRow(code: from.currencyCode, symbol: '', symbolPosition: 'before', decimalPlaces: 2);
    final toCur = widget.currenciesRepo.getByCode(to.currencyCode) ?? CurrencyRow(code: to.currencyCode, symbol: '', symbolPosition: 'before', decimalPlaces: 2);
    final same = from.currencyCode == to.currencyCode;
    if (same) {
      return TextField(
        controller: _amount,
        keyboardType: TextInputType.number,
        decoration: InputDecoration(labelText: 'Amount (${fromCur.code}, minor units)', border: const OutlineInputBorder()),
      );
    }
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _outAmount,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(labelText: 'Out (${fromCur.code}, minor units)', border: const OutlineInputBorder()),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: TextField(
            controller: _inAmount,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(labelText: 'In (${toCur.code}, minor units)', border: const OutlineInputBorder()),
          ),
        ),
      ],
    );
  }

  Widget _typeSelector(List<TransactionTypeRow> types) {
    return Row(
      children: [
        Expanded(
          child: InputDecorator(
            decoration: const InputDecoration(labelText: 'Type (optional)', border: OutlineInputBorder()),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<int>(
                value: _typeId,
                isExpanded: true,
                items: [
                  for (final t in types)
                    DropdownMenuItem(
                      value: t.id,
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 12,
                            backgroundColor: _parseColor(t.color),
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
                onChanged: (v) => setState(() => _typeId = v),
                hint: const Text('None'),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        if (_typeId != null)
          OutlinedButton(
            onPressed: () => setState(() => _typeId = null),
            child: const Text('Clear'),
          ),
      ],
    );
  }

  Widget _dateField(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text('When: ${_occurredAt.toLocal()}')),
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

  Future<void> _save() async {
    try {
      switch (_kind) {
        case 'inbound':
          if (_accountId == null) throw Exception('Select account');
          final amt = int.parse(_amount.text.trim());
          widget.txRepo.createInbound(accountId: _accountId!, amountMinor: amt, occurredAt: _occurredAt, typeId: _typeId, description: _desc.text.trim());
          break;
        case 'outbound':
          if (_accountId == null) throw Exception('Select account');
          final amt = int.parse(_amount.text.trim());
          widget.txRepo.createOutbound(accountId: _accountId!, amountMinor: amt, occurredAt: _occurredAt, typeId: _typeId, description: _desc.text.trim());
          break;
        case 'internal':
          if (_fromAccountId == null || _toAccountId == null) throw Exception('Select both accounts');
          final accounts = widget.accountsRepo.listAll();
          final from = accounts.firstWhere((a) => a.id == _fromAccountId);
          final to = accounts.firstWhere((a) => a.id == _toAccountId);
          if (from.currencyCode == to.currencyCode) {
            final amt = int.parse(_amount.text.trim());
            widget.txRepo.createInternalSameCurrency(fromAccountId: _fromAccountId!, toAccountId: _toAccountId!, amountMinor: amt, occurredAt: _occurredAt, typeId: _typeId, description: _desc.text.trim());
          } else {
            final outAmt = int.parse(_outAmount.text.trim());
            final inAmt = int.parse(_inAmount.text.trim());
            widget.txRepo.createInternalCrossCurrency(fromAccountId: _fromAccountId!, toAccountId: _toAccountId!, outAmountMinor: outAmt, inAmountMinor: inAmt, occurredAt: _occurredAt, typeId: _typeId, description: _desc.text.trim());
          }
          break;
        default:
          throw Exception('Unsupported kind');
      }
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
    }
  }
} */

class _ManageTypesPage extends StatefulWidget {
  final TransactionTypesRepository typesRepo;
  const _ManageTypesPage({required this.typesRepo});

  @override
  State<_ManageTypesPage> createState() => _ManageTypesPageState();
}

class _ManageTypesPageState extends State<_ManageTypesPage> {
  late List<TransactionTypeRow> _items;

  @override
  void initState() {
    super.initState();
    _items = widget.typesRepo.listAll();
  }

  Future<void> _refresh() async {
    setState(() => _items = widget.typesRepo.listAll());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Manage Types')),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          padding: const EdgeInsets.all(8),
          children: [
            for (final t in _items)
              Dismissible(
                key: ValueKey('tt_${t.id}'),
                direction: DismissDirection.endToStart,
                background: Container(
                  color: Colors.red,
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: const Icon(Icons.delete, color: Colors.white),
                ),
                confirmDismiss: (_) async {
                  final ok = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: Text('Delete ${t.name}?'),
                          content: const Text('This cannot be undone.'),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                            TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
                          ],
                        ),
                      ) ??
                      false;
                  return ok;
                },
                onDismissed: (_) {
                  widget.typesRepo.delete(t.id);
                  _refresh();
                },
                child: ListTile(
                  leading: _typeAvatar(t),
                  title: Text(t.name),
                  subtitle: Text('${t.appliesTo} • ${t.iconKind}:${t.iconValue} • ${t.color}'),
                  trailing: IconButton(
                    icon: const Icon(Icons.edit),
                    onPressed: () async {
                      final edited = await showDialog<_TypeFormValue>(
                        context: context,
                        builder: (_) => _EditTypeDialog(initial: t),
                      );
                      if (edited != null) {
                        widget.typesRepo.update(
                          id: t.id,
                          name: edited.name,
                          color: edited.color,
                          iconKind: edited.iconKind,
                          iconValue: edited.iconValue,
                          appliesTo: edited.appliesTo,
                        );
                        _refresh();
                      }
                    },
                  ),
                ),
              ),
            const SizedBox(height: 80),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final value = await showDialog<_TypeFormValue>(
            context: context,
            builder: (_) => const _NewTypeDialog(),
          );
          if (value != null) {
            widget.typesRepo.create(
              name: value.name,
              color: value.color,
              iconKind: value.iconKind,
              iconValue: value.iconValue,
              appliesTo: value.appliesTo,
            );
            _refresh();
          }
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _typeAvatar(TransactionTypeRow t) {
    final bg = _parseColor(t.color);
    if (t.iconKind == 'emoji') {
      return CircleAvatar(backgroundColor: bg, child: Text(t.iconValue));
    }
    final icon = kAccountIconChoices[t.iconValue] ?? Icons.category;
    return CircleAvatar(backgroundColor: bg, child: Icon(icon, color: Colors.white));
  }
}

class _NewTypeDialog extends StatefulWidget {
  const _NewTypeDialog();
  @override
  State<_NewTypeDialog> createState() => _NewTypeDialogState();
}

class _NewTypeDialogState extends State<_NewTypeDialog> {
  final _name = TextEditingController();
  final _color = TextEditingController(text: '#4CAF50');
  String _iconKind = 'material';
  final _iconValue = TextEditingController(text: 'category');
  String _appliesTo = 'any';

  @override
  void dispose() {
    _name.dispose();
    _color.dispose();
    _iconValue.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('New Type'),
      content: SizedBox(
        width: 380,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: _name, decoration: const InputDecoration(labelText: 'Name', border: OutlineInputBorder())),
            const SizedBox(height: 12),
            TextField(controller: _color, decoration: const InputDecoration(labelText: 'Color (#RRGGBB)', border: OutlineInputBorder())),
            const SizedBox(height: 12),
            _iconRow(),
            const SizedBox(height: 12),
            _appliesToRow(),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          onPressed: () {
            if (_name.text.trim().isEmpty) return;
            Navigator.pop(
              context,
              _TypeFormValue(
                name: _name.text.trim(),
                color: _color.text.trim(),
                iconKind: _iconKind,
                iconValue: _iconValue.text.trim(),
                appliesTo: _appliesTo,
              ),
            );
          },
          child: const Text('Create'),
        ),
      ],
    );
  }

  Widget _iconRow() {
    return Row(
      children: [
        Expanded(
          child: InputDecorator(
            decoration: const InputDecoration(labelText: 'Icon kind', border: OutlineInputBorder()),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _iconKind,
                isExpanded: true,
                items: const [
                  DropdownMenuItem(value: 'material', child: Text('material')),
                  DropdownMenuItem(value: 'emoji', child: Text('emoji')),
                ],
                onChanged: (v) => setState(() => _iconKind = v ?? 'material'),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: TextField(
            controller: _iconValue,
            decoration: InputDecoration(
              labelText: _iconKind == 'emoji' ? 'Emoji' : 'Material icon name',
              border: const OutlineInputBorder(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _appliesToRow() {
    return InputDecorator(
      decoration: const InputDecoration(labelText: 'Applies to', border: OutlineInputBorder()),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _appliesTo,
          isExpanded: true,
          items: const [
            DropdownMenuItem(value: 'any', child: Text('any')),
            DropdownMenuItem(value: 'inbound', child: Text('inbound')),
            DropdownMenuItem(value: 'outbound', child: Text('outbound')),
            DropdownMenuItem(value: 'internal', child: Text('internal')),
          ],
          onChanged: (v) => setState(() => _appliesTo = v ?? 'any'),
        ),
      ),
    );
  }
}

class _EditTypeDialog extends StatefulWidget {
  final TransactionTypeRow initial;
  const _EditTypeDialog({required this.initial});
  @override
  State<_EditTypeDialog> createState() => _EditTypeDialogState();
}

class _EditTypeDialogState extends State<_EditTypeDialog> {
  late final TextEditingController _name;
  late final TextEditingController _color;
  late final TextEditingController _iconValue;
  String _iconKind = 'material';
  String _appliesTo = 'any';

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.initial.name);
    _color = TextEditingController(text: widget.initial.color);
    _iconValue = TextEditingController(text: widget.initial.iconValue);
    _iconKind = widget.initial.iconKind;
    _appliesTo = widget.initial.appliesTo;
  }

  @override
  void dispose() {
    _name.dispose();
    _color.dispose();
    _iconValue.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Edit ${widget.initial.name}')
          ,
      content: SizedBox(
        width: 380,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: _name, decoration: const InputDecoration(labelText: 'Name', border: OutlineInputBorder())),
            const SizedBox(height: 12),
            TextField(controller: _color, decoration: const InputDecoration(labelText: 'Color (#RRGGBB)', border: OutlineInputBorder())),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: InputDecorator(
                    decoration: const InputDecoration(labelText: 'Icon kind', border: OutlineInputBorder()),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _iconKind,
                        isExpanded: true,
                        items: const [
                          DropdownMenuItem(value: 'material', child: Text('material')),
                          DropdownMenuItem(value: 'emoji', child: Text('emoji')),
                        ],
                        onChanged: (v) => setState(() => _iconKind = v ?? 'material'),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _iconValue,
                    decoration: InputDecoration(
                      labelText: _iconKind == 'emoji' ? 'Emoji' : 'Material icon name',
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            InputDecorator(
              decoration: const InputDecoration(labelText: 'Applies to', border: OutlineInputBorder()),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _appliesTo,
                  isExpanded: true,
                  items: const [
                    DropdownMenuItem(value: 'any', child: Text('any')),
                    DropdownMenuItem(value: 'inbound', child: Text('inbound')),
                    DropdownMenuItem(value: 'outbound', child: Text('outbound')),
                    DropdownMenuItem(value: 'internal', child: Text('internal')),
                  ],
                  onChanged: (v) => setState(() => _appliesTo = v ?? 'any'),
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          onPressed: () {
            Navigator.pop(
              context,
              _TypeFormValue(
                name: _name.text.trim(),
                color: _color.text.trim(),
                iconKind: _iconKind,
                iconValue: _iconValue.text.trim(),
                appliesTo: _appliesTo,
              ),
            );
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}

class _TypeFormValue {
  final String name;
  final String color;
  final String iconKind;
  final String iconValue;
  final String appliesTo;
  _TypeFormValue({required this.name, required this.color, required this.iconKind, required this.iconValue, required this.appliesTo});
}

Color _parseColor(String hex) {
  var h = hex.replaceAll('#', '').trim();
  if (h.length == 3) {
    h = h.split('').map((ch) => ch * 2).join();
  }
  final value = int.tryParse(h, radix: 16) ?? 0x000000;
  return Color(0xFF000000 | value);
}
