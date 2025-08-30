import 'package:flutter/material.dart';
import '../repositories/currencies_repository.dart';

class CurrencyManagementPage extends StatefulWidget {
  final CurrenciesRepository repo;
  const CurrencyManagementPage({super.key, required this.repo});

  @override
  State<CurrencyManagementPage> createState() => _CurrencyManagementPageState();
}

class _CurrencyManagementPageState extends State<CurrencyManagementPage> {
  late List<CurrencyRow> _items;

  @override
  void initState() {
    super.initState();
    _items = widget.repo.listAll();
  }

  Future<void> _refresh() async {
    setState(() => _items = widget.repo.listAll());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Manage Currencies')),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          padding: const EdgeInsets.all(8),
          children: [
            for (final c in _items)
              Dismissible(
                key: ValueKey('cur_${c.code}'),
                direction: DismissDirection.endToStart,
                background: Container(
                  color: Colors.red,
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: const Icon(Icons.delete, color: Colors.white),
                ),
                confirmDismiss: (_) async {
                  final inUse = _countAccountsUsing(c.code) > 0;
                  if (inUse) {
                    if (!mounted) return false;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Cannot delete ${c.code}: currency in use',
                        ),
                      ),
                    );
                    return false;
                  }
                  final ok =
                      await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: Text('Delete ${c.code}?'),
                          content: const Text('This cannot be undone.'),
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
                  widget.repo.delete(c.code);
                  _refresh();
                },
                child: ListTile(
                  leading: const Icon(Icons.payments),
                  title: Text(c.code),
                  subtitle: Text(_desc(c)),
                  trailing: IconButton(
                    icon: const Icon(Icons.edit),
                    onPressed: () async {
                      final edited = await showDialog<CurrencyRow>(
                        context: context,
                        builder: (_) => _EditCurrencyDialog(initial: c),
                      );
                      if (edited != null) {
                        widget.repo.update(
                          code: edited.code,
                          symbol: edited.symbol,
                          symbolPosition: edited.symbolPosition,
                          decimalPlaces: edited.decimalPlaces,
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
          final created = await showDialog<CurrencyRow>(
            context: context,
            builder: (_) => const _NewCurrencyDialog(),
          );
          if (created != null) {
            widget.repo.create(
              code: created.code,
              symbol: created.symbol,
              symbolPosition: created.symbolPosition,
              decimalPlaces: created.decimalPlaces,
            );
            _refresh();
          }
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  String _desc(CurrencyRow c) {
    final sym = c.symbol ?? '(no symbol)';
    return '$sym • ${c.symbolPosition} • ${c.decimalPlaces} decimals';
  }

  int _countAccountsUsing(String code) {
    final result = widget.repo.db.select(
      'SELECT COUNT(*) AS c FROM accounts WHERE currency_code = ?',
      [code],
    );
    if (result.isEmpty) return 0;
    return (result.first['c'] as int?) ?? 0;
  }
}

class _NewCurrencyDialog extends StatefulWidget {
  const _NewCurrencyDialog();
  @override
  State<_NewCurrencyDialog> createState() => _NewCurrencyDialogState();
}

class _NewCurrencyDialogState extends State<_NewCurrencyDialog> {
  final _code = TextEditingController();
  final _symbol = TextEditingController();
  String _position = 'before';
  int _decimals = 2;

  @override
  void dispose() {
    _code.dispose();
    _symbol.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('New Currency'),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _code,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(
                labelText: 'Code (e.g., USD, BTC)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _symbol,
              decoration: const InputDecoration(
                labelText: 'Symbol (optional)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Symbol position',
                      border: OutlineInputBorder(),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _position,
                        isExpanded: true,
                        items: const [
                          DropdownMenuItem(
                            value: 'before',
                            child: Text('before'),
                          ),
                          DropdownMenuItem(
                            value: 'after',
                            child: Text('after'),
                          ),
                        ],
                        onChanged: (v) =>
                            setState(() => _position = v ?? 'before'),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Decimals',
                      border: OutlineInputBorder(),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<int>(
                        value: _decimals,
                        isExpanded: true,
                        items: const [0, 1, 2, 3, 4, 5, 6, 7, 8]
                            .map(
                              (d) =>
                                  DropdownMenuItem(value: d, child: Text('$d')),
                            )
                            .toList(),
                        onChanged: (v) => setState(() => _decimals = v ?? 2),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            final code = _code.text.trim().toUpperCase();
            if (code.isEmpty) return;
            Navigator.pop(
              context,
              CurrencyRow(
                code: code,
                symbol: _symbol.text.trim().isEmpty
                    ? null
                    : _symbol.text.trim(),
                symbolPosition: _position,
                decimalPlaces: _decimals,
              ),
            );
          },
          child: const Text('Create'),
        ),
      ],
    );
  }
}

class _EditCurrencyDialog extends StatefulWidget {
  final CurrencyRow initial;
  const _EditCurrencyDialog({required this.initial});

  @override
  State<_EditCurrencyDialog> createState() => _EditCurrencyDialogState();
}

class _EditCurrencyDialogState extends State<_EditCurrencyDialog> {
  late final TextEditingController _symbol;
  late String _position;
  late int _decimals;

  @override
  void initState() {
    super.initState();
    _symbol = TextEditingController(text: widget.initial.symbol ?? '');
    _position = widget.initial.symbolPosition;
    _decimals = widget.initial.decimalPlaces;
  }

  @override
  void dispose() {
    _symbol.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Edit ${widget.initial.code}'),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _symbol,
              decoration: const InputDecoration(
                labelText: 'Symbol (optional)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Symbol position',
                      border: OutlineInputBorder(),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _position,
                        isExpanded: true,
                        items: const [
                          DropdownMenuItem(
                            value: 'before',
                            child: Text('before'),
                          ),
                          DropdownMenuItem(
                            value: 'after',
                            child: Text('after'),
                          ),
                        ],
                        onChanged: (v) =>
                            setState(() => _position = v ?? 'before'),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Decimals',
                      border: OutlineInputBorder(),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<int>(
                        value: _decimals,
                        isExpanded: true,
                        items: const [0, 1, 2, 3, 4, 5, 6, 7, 8]
                            .map(
                              (d) =>
                                  DropdownMenuItem(value: d, child: Text('$d')),
                            )
                            .toList(),
                        onChanged: (v) => setState(() => _decimals = v ?? 2),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            Navigator.pop(
              context,
              CurrencyRow(
                code: widget.initial.code,
                symbol: _symbol.text.trim().isEmpty
                    ? null
                    : _symbol.text.trim(),
                symbolPosition: _position,
                decimalPlaces: _decimals,
              ),
            );
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}
