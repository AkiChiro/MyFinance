import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'data/database.dart';
import 'repositories/finance_repository.dart';
import 'services/category_suggester.dart';
import 'services/notification_service.dart';
import 'ui/home_page.dart';
import 'ui/quick_add_page.dart';

// Simple global access — fine for a single-user app.
late final FinanceRepository repository;
late final CategorySuggester suggester;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final db = AppDatabase();
  repository = FinanceRepository(db);
  suggester = CategorySuggester();
  await suggester.load();
  try {
    await NotificationService.instance.init();
  } catch (_) {
    // Notifications are not critical — the app works without them.
  }
  runApp(const MyFinanceApp());
}

class MyFinanceApp extends StatelessWidget {
  const MyFinanceApp({super.key});

  @override
  Widget build(BuildContext context) {
    const seed = Color(0xFFFFC107); // amber / yellow
    final scheme = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: Brightness.light,
    );

    return MaterialApp(
      title: 'MyFinance',
      debugShowCheckedModeBanner: false,
      navigatorKey: navigatorKey,
      locale: const Locale('vi'),
      supportedLocales: const [Locale('vi'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: scheme,
        scaffoldBackgroundColor: const Color(0xFFFFFDF5),
        appBarTheme: const AppBarTheme(centerTitle: false),
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(),
          isDense: true,
        ),
      ),
      home: const HomePage(),
      // Named route used by notification actions and widget deep-links.
      onGenerateRoute: (settings) {
        if (settings.name == '/quick-add') {
          final type = settings.arguments as String?;
          return MaterialPageRoute(
            builder: (_) => QuickAddPage(initialType: type),
          );
        }
        if (settings.name == '/') {
          return MaterialPageRoute(builder: (_) => const HomePage());
        }
        return null;
      },
    );
  }
}

// Convenience — used by home_widget callbacks to jump to the right type.
void openQuickAdd(String txType) {
  navigatorKey.currentState?.pushNamed(
    '/quick-add',
    arguments: txType,
  );
}
