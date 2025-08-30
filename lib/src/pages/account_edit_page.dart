import 'package:flutter/material.dart';
import '../features/accounts/domain/account_icon_choices.dart';
import '../features/accounts/domain/account_icon_groups.dart';
import '../features/accounts/presentation/widgets/account_icon_selector.dart';
import '../features/accounts/presentation/widgets/account_color_selector.dart';
import '../repositories/currencies_repository.dart';

import '../repositories/accounts_repository.dart';

class AccountEditPage extends StatefulWidget {
  final AccountsRepository repo;
  final AccountRow? initial;
  const AccountEditPage({super.key, required this.repo, this.initial});

  @override
  State<AccountEditPage> createState() => _AccountEditPageState();
}

class _AccountEditPageState extends State<AccountEditPage> {
  final _name = TextEditingController();
  final _accountType = TextEditingController();
  String _icon = 'savings';
  Color _color = const Color(0xFF1565C0);
  bool _saving = false;
  String _currencyCode = 'USD';
  List<CurrencyRow> _currencies = const [];
  bool _loadingCurrencies = true;

  // Available icon choices are defined in the domain layer.

  @override
  void initState() {
    super.initState();
    final i = widget.initial;
    if (i != null) {
      _name.text = i.name;
      _icon = i.icon;
      _color = _parseHex(i.color);
      _accountType.text = i.accountType;
      _currencyCode = i.currencyCode;
    }
    // Load currencies from DB
    final curRepo = CurrenciesRepository(widget.repo.db);
    _currencies = curRepo.listAll();
    if (_currencies.isEmpty) {
      // If somehow empty (before migrations), default to USD option only
      _currencies = [
        CurrencyRow(
          code: 'USD',
          symbol: '\$',
          symbolPosition: 'before',
          decimalPlaces: 2,
        ),
      ];
    }
    // Prefill currency for new accounts from last used in this register
    if (i == null) {
      try {
        final existing = AccountsRepository(widget.repo.db).listAll();
        if (existing.isNotEmpty) {
          _currencyCode = existing.first.currencyCode;
        }
      } catch (_) {
        // ignore
      }
    }
    if (!mounted) return;
    setState(() => _loadingCurrencies = false);
  }

  @override
  void dispose() {
    _name.dispose();
    _accountType.dispose();
    super.dispose();
  }

  static String _toHex(Color c) {
    final argb = c.toARGB32();
    final r = (argb >> 16) & 0xff;
    final g = (argb >> 8) & 0xff;
    final b = argb & 0xff;
    return '#${r.toRadixString(16).padLeft(2, '0')}${g.toRadixString(16).padLeft(2, '0')}${b.toRadixString(16).padLeft(2, '0')}'
        .toUpperCase();
  }

  static Color _parseHex(String hex) {
    var h = hex.replaceAll('#', '').trim();
    if (h.length == 3) {
      h = h.split('').map((ch) => ch * 2).join();
    }
    final value = int.parse(h, radix: 16);
    return Color(0xFF000000 | value);
  }

  Future<void> _save() async {
    if (_saving) return;
    final name = _name.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Name required')));
      return;
    }
    setState(() => _saving = true);
    try {
      final colorHex = _toHex(_color);
      final currencyCode = _currencyCode;
      final accountType = _accountType.text.trim();
      if (widget.initial == null) {
        widget.repo.create(
          name: name,
          icon: _icon,
          color: colorHex,
          accountType: accountType,
          currencyCode: currencyCode,
        );
      } else {
        widget.repo.update(
          id: widget.initial!.id,
          name: name,
          icon: _icon,
          color: colorHex,
          accountType: accountType,
          currencyCode: currencyCode,
        );
      }
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to save: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // Color picking handled by AccountColorSelector.

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.initial == null ? 'New Account' : 'Edit Account'),
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final iconHeight = (constraints.maxHeight * 0.36).clamp(
              200.0,
              420.0,
            );
            final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
            return SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(16, 16, 16, bottomInset + 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: _name,
                    decoration: const InputDecoration(
                      labelText: 'Name',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _AccountTypeField(controller: _accountType),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Text('Color', style: theme.textTheme.titleMedium),
                      const SizedBox(width: 12),
                      Expanded(
                        child: AccountColorSelector(
                          color: _color,
                          onChanged: (c) =>
                              setState(() => _color = c.withValues(alpha: 1.0)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text('Icon', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: iconHeight,
                    child: AccountIconSelector(
                      icons: kAccountIconChoices,
                      groups: kAccountIconGroups,
                      selectedKey: _icon,
                      onChanged: (key) => setState(() => _icon = key),
                      maxItemExtent: 88,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _CurrencySelector(
                    currencies: _currencies,
                    loading: _loadingCurrencies,
                    value: _currencyCode,
                    onChanged: (v) => setState(() => _currencyCode = v),
                    onCreate: (newCurrency) {
                      final repo = CurrenciesRepository(widget.repo.db);
                      repo.create(
                        code: newCurrency.code,
                        symbol: newCurrency.symbol,
                        symbolPosition: newCurrency.symbolPosition,
                        decimalPlaces: newCurrency.decimalPlaces,
                      );
                      final list = repo.listAll();
                      setState(() {
                        _currencies = list;
                        _currencyCode = newCurrency.code;
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _saving ? null : _save,
                      child: Text(widget.initial == null ? 'Create' : 'Save'),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _AccountTypeField extends StatefulWidget {
  final TextEditingController controller;
  const _AccountTypeField({required this.controller});

  @override
  State<_AccountTypeField> createState() => _AccountTypeFieldState();
}

class _AccountTypeFieldState extends State<_AccountTypeField> {
  static const List<String> _suggestions = <String>[
    'savings',
    'checking',
    'investment',
    'IRA',
    'HSA',
    'debit',
    'crypto',
  ];

  @override
  Widget build(BuildContext context) {
    return Autocomplete<String>(
      optionsBuilder: (TextEditingValue value) {
        final query = value.text.toLowerCase().trim();
        if (query.isEmpty) return _suggestions;
        return _suggestions.where((s) => s.toLowerCase().contains(query));
      },
      onSelected: (s) => widget.controller.text = s,
      fieldViewBuilder:
          (context, textEditingController, focusNode, onFieldSubmitted) {
            // Keep the external controller in sync for initial and manual changes.
            textEditingController.text = widget.controller.text;
            textEditingController.addListener(() {
              if (widget.controller.text != textEditingController.text) {
                widget.controller.text = textEditingController.text;
              }
            });
            return TextField(
              controller: textEditingController,
              focusNode: focusNode,
              decoration: const InputDecoration(
                labelText: 'Account Type',
                hintText: 'e.g., savings, checking, crypto…',
                border: OutlineInputBorder(),
              ),
              onSubmitted: (_) => onFieldSubmitted(),
            );
          },
    );
  }
}

class _CurrencySelector extends StatelessWidget {
  const _CurrencySelector({
    required this.currencies,
    required this.loading,
    required this.value,
    required this.onChanged,
    required this.onCreate,
  });

  final List<CurrencyRow> currencies;
  final bool loading;
  final String value;
  final ValueChanged<String> onChanged;
  final ValueChanged<CurrencyRow> onCreate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: InputDecorator(
            decoration: const InputDecoration(
              labelText: 'Currency',
              border: OutlineInputBorder(),
            ),
            child: loading
                ? const SizedBox(height: 24, child: LinearProgressIndicator())
                : DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      isExpanded: true,
                      value: value,
                      onChanged: (v) => v == null ? null : onChanged(v),
                      items: [
                        for (final c in currencies)
                          DropdownMenuItem(
                            value: c.code,
                            child: Text(_format(c, theme)),
                          ),
                      ],
                    ),
                  ),
          ),
        ),
        const SizedBox(width: 12),
        OutlinedButton.icon(
          icon: const Icon(Icons.add),
          label: const Text('New'),
          onPressed: () async {
            final created = await showDialog<CurrencyRow>(
              context: context,
              builder: (ctx) => const _NewCurrencyDialog(),
            );
            if (created != null) {
              onCreate(created);
            }
          },
        ),
      ],
    );
  }

  String _format(CurrencyRow c, ThemeData theme) {
    final sym = c.symbol ?? '';
    final pos = c.symbolPosition;
    final dec = c.decimalPlaces;
    if (sym.isEmpty) return '${c.code} (no symbol, $dec)';
    return '${c.code} ($sym $pos, $dec)';
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
