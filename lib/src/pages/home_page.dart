import 'package:flutter/material.dart';

import '../models/account.dart';
import '../db/app_db.dart';
import '../db/migrations.dart';
import '../features/accounts/domain/account_icon_choices.dart';
import '../repositories/accounts_repository.dart';
import 'account_edit_page.dart';
import 'account_setup_page.dart';
import '../services/account_store.dart';
import '../services/sync_service.dart';
import '../repositories/currencies_repository.dart';
import '../repositories/transactions_repository.dart';
import '../repositories/transaction_types_repository.dart';
import '../features/transactions/presentation/transactions_page.dart';
import '../features/stats/presentation/stats_page.dart';
import '../features/budgets/presentation/budgets_page.dart';
import '../repositories/budgets_repository.dart';
import 'currency_management_page.dart';
import '../services/balance_cache.dart';
import '../utils/currency_format.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

class HomePage extends StatefulWidget {
  final Account account;
  const HomePage({super.key, required this.account});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final bool _showSyncButton = false;
  String _status = 'Opening database...';
  AppDb? _appDb;
  AccountsRepository? _repo;
  List<AccountRow> _accounts = const [];
  int _tabIndex = 0;
  BalanceCache? _balanceCache;
  final ValueNotifier<BudgetSort> _budgetSort = ValueNotifier<BudgetSort>(
    BudgetSort.name,
  );

  @override
  void initState() {
    super.initState();
    // Remember this register as the last opened
    AccountStore.instance.setLastOpened(widget.account.id);
    _openAndMigrate();
  }

  Future<void> _openAndMigrate() async {
    try {
      final db = AppDb(widget.account.dbPath);
      await db.open();
      final runner = MigrationRunner(db.db);
      await runner.applyAll([
        CreateAccountsMigration(),
        AddAccountTypeToAccountsMigration(),
        CreateCurrenciesMigration(),
        SeedCurrenciesMigration(),
        AddCurrencyToAccountsMigration(),
        CreateTransactionTypesMigration(),
        CreateTransactionsMigration(),
        SeedDefaultTransactionTypesMigration(),
        AddRebalanceKindMigration(),
        CreateBudgetsMigration(),
        AddBudgetVersionsMigration(),
        BackfillAccountCurrencyMigration(),
      ]);
      final repo = AccountsRepository(db.db);
      final rows = repo.listAll();
      final bal = BalanceCache(db.db);
      setState(() {
        _appDb = db;
        _repo = repo;
        _balanceCache = bal;
        _accounts = rows;
        _status = 'Database ready';
      });
    } catch (e) {
      setState(() => _status = 'Error: $e');
    }
  }

  Future<void> _refresh() async {
    final repo = _repo;
    if (repo == null) return;
    _balanceCache?.reloadAll();
    setState(() => _accounts = repo.listAll());
  }

  @override
  void dispose() {
    _appDb?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final large = width >= 900;
    final destinations = const [
      NavigationDestination(
        icon: Icon(Icons.account_balance_wallet),
        label: 'Accounts',
      ),
      NavigationDestination(icon: Icon(Icons.list_alt), label: 'Transactions'),
      NavigationDestination(
        icon: Icon(Icons.account_balance),
        label: 'Budgets',
      ),
      NavigationDestination(icon: Icon(Icons.insights), label: 'Stats'),
    ];

    final content = _repo == null
        ? Center(child: Text(_status))
        : IndexedStack(
            index: _tabIndex,
            children: [
              _buildAccountsTab(),
              _buildTransactionsTab(),
              _buildBudgetsTab(),
              _buildStatsTab(),
            ],
          );

    return Scaffold(
      appBar: AppBar(
        title: Text(_currentPageTitle),
        actions: [
          if (_showSyncButton)
            IconButton(
              tooltip: 'Sync all registers',
              icon: const Icon(Icons.sync),
              onPressed: () async {
                final before = ScaffoldMessenger.of(context);
                before.showSnackBar(
                  const SnackBar(content: Text('Syncing registers…')),
                );
                final count = await SyncService.syncAll();
                before.showSnackBar(
                  SnackBar(content: Text('Synced $count register(s)')),
                );
              },
            ),
          if (_tabIndex == 2)
            PopupMenuButton<BudgetSort>(
              initialValue: _budgetSort.value,
              onSelected: (v) => _budgetSort.value = v,
              itemBuilder: (ctx) => const [
                PopupMenuItem(
                  value: BudgetSort.name,
                  child: Text('Sort by name'),
                ),
                PopupMenuItem(
                  value: BudgetSort.size,
                  child: Text('Sort by size'),
                ),
                PopupMenuItem(
                  value: BudgetSort.percent,
                  child: Text('Sort by % spent'),
                ),
              ],
              icon: const Icon(Icons.sort),
              tooltip: 'Sort',
            ),
        ],
      ),
      drawer: _buildDrawer(context),
      body: large
          ? Row(
              children: [
                NavigationRail(
                  selectedIndex: _tabIndex,
                  onDestinationSelected: (i) => setState(() => _tabIndex = i),
                  labelType: NavigationRailLabelType.all,
                  destinations: const [
                    NavigationRailDestination(
                      icon: Icon(Icons.account_balance_wallet),
                      label: Text('Accounts'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.list_alt),
                      label: Text('Transactions'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.account_balance),
                      label: Text('Budgets'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.insights),
                      label: Text('Stats'),
                    ),
                  ],
                ),
                const VerticalDivider(width: 1),
                Expanded(child: content),
              ],
            )
          : content,
      bottomNavigationBar: large
          ? null
          : NavigationBar(
              selectedIndex: _tabIndex,
              onDestinationSelected: (i) => setState(() => _tabIndex = i),
              destinations: destinations,
            ),
      floatingActionButton: _repo == null || _tabIndex != 0
          ? null
          : FloatingActionButton(
              heroTag: 'accounts-fab',
              onPressed: () async {
                final created = await Navigator.of(context).push<bool>(
                  MaterialPageRoute(
                    builder: (_) => AccountEditPage(repo: _repo!),
                  ),
                );
                if (created == true) {
                  _refresh();
                }
              },
              child: const Icon(Icons.add),
            ),
    );
  }
}

Widget _buildAccountsTabFallback(String message) =>
    Center(child: Text(message));

extension on _HomePageState {
  String get _currentPageTitle {
    switch (_tabIndex) {
      case 0:
        return 'Accounts';
      case 1:
        return 'Transactions';
      case 2:
        return 'Budgets';
      case 3:
      default:
        return 'Stats';
    }
  }

  Widget _buildTransactionsTab() {
    final db = _appDb?.db;
    if (db == null) return _buildAccountsTabFallback(_status);
    final accountsRepo = AccountsRepository(db);
    final txRepo = TransactionsRepository(db, balanceCache: _balanceCache);
    final curRepo = CurrenciesRepository(db);
    final typesRepo = TransactionTypesRepository(db);
    return TransactionsPage(
      accountsRepo: accountsRepo,
      txRepo: txRepo,
      currenciesRepo: curRepo,
      typesRepo: typesRepo,
      balanceCache: _balanceCache,
    );
  }

  Widget _buildAccountsTab() {
    final repo = _repo;
    if (repo == null) return _buildAccountsTabFallback(_status);
    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        padding: const EdgeInsets.all(8),
        children: [
          const ListTile(title: Text('Register Info')),
          ListTile(
            title: const Text('Register path'),
            subtitle: SelectableText(widget.account.dbPath),
          ),
          if (widget.account.mirrorUri != null)
            ListTile(
              title: const Text('Mirror URI'),
              subtitle: SelectableText(widget.account.mirrorUri!),
            ),
          const Divider(),
          const ListTile(title: Text('Accounts')),
          for (final a in _accounts)
            Dismissible(
              key: ValueKey('acct_${a.id}'),
              background: Container(
                color: Colors.red,
                alignment: Alignment.centerLeft,
                padding: const EdgeInsets.only(left: 16),
                child: const Icon(Icons.delete, color: Colors.white),
              ),
              secondaryBackground: Container(
                color: Colors.red,
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(right: 16),
                child: const Icon(Icons.delete, color: Colors.white),
              ),
              confirmDismiss: (_) async {
                final ok =
                    await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Delete account?'),
                        content: Text('Delete "${a.name}"?'),
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
                _repo!.delete(a.id);
                _refresh();
              },
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: _parseColor(a.color),
                  child: Icon(
                    kAccountIconChoices[a.icon] ?? Icons.account_balance_wallet,
                    color: Colors.white,
                  ),
                ),
                title: Text(a.name),
                subtitle: Text(
                  [
                    if (a.accountType.isNotEmpty) a.accountType,
                    a.currencyCode,
                    a.icon,
                    a.color,
                  ].join(' • '),
                ),
                trailing: _AccountBalancePill(
                  account: a,
                  db: _appDb!.db,
                  balanceCache: _balanceCache!,
                ),
                onTap: () async {
                  final changed = await Navigator.of(context).push<bool>(
                    MaterialPageRoute(
                      builder: (_) => AccountEditPage(repo: _repo!, initial: a),
                    ),
                  );
                  if (changed == true) {
                    _refresh();
                  }
                },
              ),
            ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _buildBudgetsTab() {
    final db = _appDb?.db;
    if (db == null) return _buildAccountsTabFallback(_status);
    return BudgetsPage(
      budgetsRepo: BudgetsRepository(db),
      typesRepo: TransactionTypesRepository(db),
      currenciesRepo: CurrenciesRepository(db),
      accountsRepo: AccountsRepository(db),
      txRepo: TransactionsRepository(db),
      sortNotifier: _budgetSort,
    );
  }

  Widget _buildStatsTab() {
    final db = _appDb?.db;
    if (db == null) return _buildAccountsTabFallback(_status);
    final accountsRepo = AccountsRepository(db);
    final currenciesRepo = CurrenciesRepository(db);
    return StatsPage(
      db: db,
      accountsRepo: accountsRepo,
      currenciesRepo: currenciesRepo,
    );
  }
}

class _AccountBalancePill extends StatelessWidget {
  const _AccountBalancePill({
    required this.account,
    required this.db,
    required this.balanceCache,
  });

  final AccountRow account;
  final sqlite.Database db;
  final BalanceCache balanceCache;

  @override
  Widget build(BuildContext context) {
    final curRepo = CurrenciesRepository(db);
    final cur =
        curRepo.getByCode(account.currencyCode) ??
        CurrencyRow(
          code: account.currencyCode,
          symbol: '',
          symbolPosition: 'before',
          decimalPlaces: 2,
        );
    final minor = balanceCache.getBalanceMinor(account.id);
    final s = formatMinorUnits(minor.abs(), cur);
    final color = minor >= 0 ? Colors.green.shade700 : Colors.red.shade700;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        s,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w600,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}

Color _parseColor(String hex) {
  var h = hex.replaceAll('#', '').trim();
  if (h.length == 3) {
    h = h.split('').map((ch) => ch * 2).join();
  }
  final value = int.tryParse(h, radix: 16) ?? 0x000000;
  return Color(0xFF000000 | value);
}

extension _DrawerExt on _HomePageState {
  Drawer _buildDrawer(BuildContext context) {
    return Drawer(
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Registers',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            Expanded(
              child: ListView(
                children: [
                  for (final reg in AccountStore.instance.accounts)
                    ListTile(
                      leading: const Icon(Icons.folder),
                      title: Text(reg.name),
                      subtitle: Text(
                        reg.dbPath,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      onTap: () {
                        // Persist the last opened register before switching
                        AccountStore.instance.setLastOpened(reg.id);
                        Navigator.of(context).pushReplacement(
                          MaterialPageRoute(
                            builder: (_) => HomePage(account: reg),
                          ),
                        );
                      },
                    ),
                  const Divider(),
                  ListTile(
                    leading: const Icon(Icons.sync),
                    title: const Text('Sync all registers'),
                    onTap: () async {
                      final before = ScaffoldMessenger.of(context);
                      before.showSnackBar(
                        const SnackBar(content: Text('Syncing registers.')),
                      );
                      final count = await SyncService.syncAll();
                      before.showSnackBar(
                        SnackBar(content: Text('Synced $count register(s)')),
                      );
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.payments),
                    title: const Text('Manage currencies'),
                    onTap: () {
                      final db = _appDb?.db;
                      if (db == null) return;
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => CurrencyManagementPage(
                            repo: CurrenciesRepository(db),
                          ),
                        ),
                      );
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.category),
                    title: const Text('Manage transaction types'),
                    onTap: () async {
                      final db = _appDb?.db;
                      if (db == null) return;
                      await Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => ManageTransactionTypesPage(
                            typesRepo: TransactionTypesRepository(db),
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.add_box),
              title: const Text('Create/Load Register'),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const AccountSetupPage()),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
