import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart'; // ChangeNotifierProvider (Riverpod 3.x legacy)

import 'data/database.dart';
import 'repositories/finance_repository.dart';
import 'services/app_settings.dart';
import 'services/capture_service.dart';
import 'services/category_suggester.dart';

final dbProvider = Provider<AppDatabase>((_) => throw UnimplementedError());
final repositoryProvider = Provider<FinanceRepository>((_) => throw UnimplementedError());
final suggesterProvider = Provider<CategorySuggester>((_) => throw UnimplementedError());
final captureServiceProvider = Provider<CaptureService>((_) => throw UnimplementedError());

// ChangeNotifierProvider preserves the notifyListeners() → rebuild contract
// without requiring a migration of AppSettings to the modern Notifier API.
// Import from legacy.dart required in Riverpod 3.x.
final settingsProvider = ChangeNotifierProvider<AppSettings>((_) => throw UnimplementedError());

// Month navigation state — shared between TransactionsPage (writer) and HomePage (reader).
final monthModeProvider = StateProvider<bool>((ref) => false);
final selectedMonthProvider = StateProvider<DateTime>((ref) {
  final now = DateTime.now();
  return DateTime(now.year, now.month);
});

// Bottom-nav tab index — owned here instead of as HomePage local State so
// drill-down navigation (e.g. AnalyticsPage → Giao dịch) doesn't need a
// shared ancestor. Same reasoning as monthModeProvider/selectedMonthProvider.
final homeTabIndexProvider = StateProvider<int>((ref) => 0);

// Giao dịch (Transactions) filter state — shared between TransactionsPage
// (primary owner) and drill-down writers (AnalyticsPage), same pattern as
// monthModeProvider/selectedMonthProvider above.
final txnTypeFilterProvider = StateProvider<String?>((ref) => null);
final txnCategoryFilterProvider = StateProvider<String?>((ref) => null);
final txnStarredOnlyProvider = StateProvider<bool>((ref) => false);
