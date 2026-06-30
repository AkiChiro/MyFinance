import 'package:flutter/material.dart';
import 'package:home_widget/home_widget.dart';

import 'analytics_page.dart';
import 'quick_add_page.dart';
import 'settings_page.dart';
import 'transactions_page.dart';
import 'wallets_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key, this.initialType});

  /// When set (e.g. from a widget/notification deep-link), the FAB opens
  /// Quick Add pre-selected to this transaction type.
  final String? initialType;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _index = 0;

  static const _titles = ['Ví', 'Giao dịch', 'Thống kê', 'Cài đặt'];
  static const _pages = [
    WalletsPage(),
    TransactionsPage(),
    AnalyticsPage(),
    SettingsPage(),
  ];

  @override
  void initState() {
    super.initState();
    // Handle cold-start from a widget button (initialType set by MainActivity).
    if (widget.initialType != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) =>
          _openQuickAdd(initialType: widget.initialType));
    }
    // Handle warm-start / resume from a widget button tap.
    try {
      HomeWidget.widgetClicked.listen(_onWidgetClicked);
      HomeWidget.getWidgetData<String>('pendingTxType').then((type) {
        if (type != null && type.isNotEmpty) {
          HomeWidget.saveWidgetData('pendingTxType', '');
          WidgetsBinding.instance.addPostFrameCallback(
              (_) => _openQuickAdd(initialType: type));
        }
      });
    } catch (_) {}
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
    return Scaffold(
      appBar: AppBar(title: Text(_titles[_index])),
      body: IndexedStack(index: _index, children: _pages),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openQuickAdd(),
        icon: const Icon(Icons.add),
        label: const Text('Thêm'),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.account_balance_wallet_outlined),
              selectedIcon: Icon(Icons.account_balance_wallet),
              label: 'Ví'),
          NavigationDestination(
              icon: Icon(Icons.receipt_long_outlined),
              selectedIcon: Icon(Icons.receipt_long),
              label: 'Giao dịch'),
          NavigationDestination(
              icon: Icon(Icons.bar_chart_outlined),
              selectedIcon: Icon(Icons.bar_chart),
              label: 'Thống kê'),
          NavigationDestination(
              icon: Icon(Icons.settings_outlined),
              selectedIcon: Icon(Icons.settings),
              label: 'Cài đặt'),
        ],
      ),
    );
  }
}
