import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:home_widget/home_widget.dart';

import '../l10n/generated/app_localizations.dart';
import '../providers.dart';
import 'analytics_page.dart';
import 'quick_add_page.dart';
import 'settings_page.dart';
import 'transactions_page.dart';
import 'wallets_page.dart';
import 'widgets/app_icon.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key, this.initialType});

  /// When set (e.g. from a widget/notification deep-link), the FAB opens
  /// Quick Add pre-selected to this transaction type.
  final String? initialType;

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  int _index = 0;

  static const _pages = [
    WalletsPage(),
    TransactionsPage(),
    AnalyticsPage(),
    SettingsPage(),
  ];

  @override
  void initState() {
    super.initState();
    if (widget.initialType != null) {
      WidgetsBinding.instance.addPostFrameCallback(
          (_) => _openQuickAdd(initialType: widget.initialType));
    }
    try {
      HomeWidget.widgetClicked.listen(_onWidgetClicked);
      HomeWidget.getWidgetData<String>('pendingTxType').then((type) {
        if (type != null && type.isNotEmpty) {
          HomeWidget.saveWidgetData('pendingTxType', '');
          WidgetsBinding.instance.addPostFrameCallback(
              (_) => _openQuickAdd(initialType: type));
        }
      });
    } catch (e, st) {
      debugPrint('HomeWidget error: $e\n$st');
    }
  }

  void _onWidgetClicked(Uri? uri) {
    if (uri == null) return;
    final type = uri.queryParameters['txType'];
    _openQuickAdd(initialType: type);
  }

  void _openQuickAdd({String? initialType}) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => QuickAddPage(initialType: initialType),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.read(repositoryProvider);
    final monthMode = ref.watch(monthModeProvider);
    final selectedMonth = ref.watch(selectedMonthProvider);
    final l10n = AppLocalizations.of(context)!;
    final titles = [
      l10n.navWallets,
      l10n.navTransactions,
      l10n.navAnalytics,
      l10n.navSettings,
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(titles[_index]),
        actions: _index == 1 && monthMode
            ? [
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  onPressed: () =>
                      ref.read(selectedMonthProvider.notifier).state =
                          DateTime(selectedMonth.year, selectedMonth.month - 1),
                ),
                Center(
                  child: Text(
                    l10n.monthYearLabel(selectedMonth.month, selectedMonth.year),
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  onPressed: () =>
                      ref.read(selectedMonthProvider.notifier).state =
                          DateTime(selectedMonth.year, selectedMonth.month + 1),
                ),
              ]
            : const [],
      ),
      body: GestureDetector(
        onHorizontalDragEnd: (details) {
          final v = details.primaryVelocity ?? 0;
          if (v < -300 && _index < _pages.length - 1) {
            setState(() => _index++);
          } else if (v > 300 && _index > 0) {
            setState(() => _index--);
          }
        },
        behavior: HitTestBehavior.opaque,
        child: IndexedStack(index: _index, children: _pages),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openQuickAdd(),
        icon: const AppIcon('fab_add', fallback: Icons.add),
        label: Text(l10n.commonAdd),
      ),
      bottomNavigationBar: StreamBuilder<int>(
        stream: repo.pendingCaptureCount(),
        builder: (context, snap) {
          final captureCount = snap.data ?? 0;
          return NavigationBar(
            selectedIndex: _index,
            onDestinationSelected: (i) => setState(() => _index = i),
            destinations: [
              NavigationDestination(
                  icon: const AppIcon('nav_wallets',
                      fallback: Icons.account_balance_wallet_outlined),
                  selectedIcon: const AppIcon('nav_wallets',
                      fallback: Icons.account_balance_wallet),
                  label: l10n.navWallets),
              NavigationDestination(
                icon: captureCount > 0
                    ? Badge(
                        label: Text('$captureCount'),
                        child: const AppIcon('nav_transactions',
                            fallback: Icons.receipt_long_outlined))
                    : const AppIcon('nav_transactions',
                        fallback: Icons.receipt_long_outlined),
                selectedIcon: captureCount > 0
                    ? Badge(
                        label: Text('$captureCount'),
                        child: const AppIcon('nav_transactions',
                            fallback: Icons.receipt_long))
                    : const AppIcon('nav_transactions',
                        fallback: Icons.receipt_long),
                label: l10n.navTransactions,
              ),
              NavigationDestination(
                  icon: const AppIcon('nav_analytics',
                      fallback: Icons.bar_chart_outlined),
                  selectedIcon: const AppIcon('nav_analytics',
                      fallback: Icons.bar_chart),
                  label: l10n.navAnalytics),
              NavigationDestination(
                  icon: const AppIcon('nav_settings',
                      fallback: Icons.settings_outlined),
                  selectedIcon: const AppIcon('nav_settings',
                      fallback: Icons.settings),
                  label: l10n.navSettings),
            ],
          );
        },
      ),
    );
  }
}
