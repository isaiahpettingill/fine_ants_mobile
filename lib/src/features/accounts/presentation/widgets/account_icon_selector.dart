import 'package:flutter/material.dart';
import '../../domain/account_icon_groups.dart';

/// A responsive, scrollable grid of selectable icons.
///
/// - Adapts the number of columns to available width using max item extent.
/// - Uses smaller containers for better information density.
/// - Provides a visible scrollbar for easier selection in long lists.
class AccountIconSelector extends StatelessWidget {
  const AccountIconSelector({
    super.key,
    required this.icons,
    required this.selectedKey,
    required this.onChanged,
    this.maxItemExtent = 88,
    this.groups,
  });

  /// Map of icon key to icon data.
  final Map<String, IconData> icons;

  /// Currently selected icon key.
  final String selectedKey;

  /// Callback when a new icon is selected.
  final ValueChanged<String> onChanged;

  /// Maximum pixel width of a grid tile before adding another column.
  final double maxItemExtent;

  /// Optional groups for building category tabs.
  final List<AccountIconGroup>? groups;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final groups = this.groups;
    if (groups == null || groups.isEmpty) {
      return _Grid(
        entries: icons.entries.toList(growable: false),
        selectedKey: selectedKey,
        onChanged: onChanged,
        maxItemExtent: maxItemExtent,
      );
    }

    return DefaultTabController(
      length: groups.length,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Material(
            color: theme.colorScheme.surface,
            child: TabBar(
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              labelColor: theme.colorScheme.primary,
              tabs: [for (final g in groups) Tab(text: g.name)],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: TabBarView(
              children: [
                for (final g in groups)
                  _Grid(
                    entries: g.icons.entries.toList(growable: false),
                    selectedKey: selectedKey,
                    onChanged: onChanged,
                    maxItemExtent: maxItemExtent,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Grid extends StatefulWidget {
  const _Grid({
    required this.entries,
    required this.selectedKey,
    required this.onChanged,
    required this.maxItemExtent,
  });

  final List<MapEntry<String, IconData>> entries;
  final String selectedKey;
  final ValueChanged<String> onChanged;
  final double maxItemExtent;

  @override
  State<_Grid> createState() => _GridState();
}

class _GridState extends State<_Grid> {
  late final ScrollController _controller;

  @override
  void initState() {
    super.initState();
    _controller = ScrollController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final entries = widget.entries;
    final selectedKey = widget.selectedKey;
    return Scrollbar(
      controller: _controller,
      thumbVisibility: true,
      child: GridView.builder(
        controller: _controller,
        padding: EdgeInsets.zero,
        gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: widget.maxItemExtent,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: 1,
        ),
        itemCount: entries.length,
        itemBuilder: (context, index) {
          final entry = entries[index];
          final isSelected = selectedKey == entry.key;
          final color = isSelected ? theme.colorScheme.primary : null;

          return Semantics(
            selected: isSelected,
            button: true,
            label: entry.key,
            child: Tooltip(
              message: entry.key,
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () => widget.onChanged(entry.key),
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: isSelected ? theme.colorScheme.primary : Colors.grey.shade300,
                    ),
                    borderRadius: BorderRadius.circular(8),
                    color: isSelected
                        ? theme.colorScheme.primary.withValues(alpha: 0.06)
                        : theme.colorScheme.surface,
                  ),
                  alignment: Alignment.center,
                  child: Icon(entry.value, color: color, size: 22),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
