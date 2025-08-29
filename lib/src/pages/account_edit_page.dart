import 'package:flutter/material.dart';
import '../features/accounts/domain/account_icon_choices.dart';
import '../features/accounts/domain/account_icon_groups.dart';
import '../features/accounts/presentation/widgets/account_icon_selector.dart';
import '../features/accounts/presentation/widgets/account_color_selector.dart';

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
    }
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
    return '#${r.toRadixString(16).padLeft(2, '0')}${g.toRadixString(16).padLeft(2, '0')}${b.toRadixString(16).padLeft(2, '0')}'.toUpperCase();
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
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Name required')));
      return;
    }
    setState(() => _saving = true);
    try {
      final colorHex = _toHex(_color);
      final accountType = _accountType.text.trim();
      if (widget.initial == null) {
        widget.repo.create(name: name, icon: _icon, color: colorHex, accountType: accountType);
      } else {
        widget.repo.update(id: widget.initial!.id, name: name, icon: _icon, color: colorHex, accountType: accountType);
      }
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to save: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // Color picking handled by AccountColorSelector.

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(widget.initial == null ? 'New Account' : 'Edit Account')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'Name', border: OutlineInputBorder()),
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
                    onChanged: (c) => setState(() => _color = c.withValues(alpha: 1.0)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text('Icon', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            // Fill remaining vertical space for the icon selector.
            Expanded(
              child: AccountIconSelector(
                icons: kAccountIconChoices,
                groups: kAccountIconGroups,
                selectedKey: _icon,
                onChanged: (key) => setState(() => _icon = key),
                maxItemExtent: 88,
              ),
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _saving ? null : _save,
                child: Text(widget.initial == null ? 'Create' : 'Save'),
              ),
            )
          ],
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
      fieldViewBuilder: (context, textEditingController, focusNode, onFieldSubmitted) {
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
