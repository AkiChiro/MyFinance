import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'data/database.dart';
import 'repositories/finance_repository.dart';
import 'services/app_settings.dart';
import 'services/category_suggester.dart';
import 'services/notification_service.dart';
import 'ui/home_page.dart';
import 'ui/quick_add_page.dart';

late final FinanceRepository repository;
late final CategorySuggester suggester;
late final AppSettings settings;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final db = AppDatabase();
  repository = FinanceRepository(db);
  suggester = CategorySuggester();
  settings = await AppSettings.load();
  await suggester.load();
  await NotificationService.instance.init(enabled: settings.notifEnabled);
  WidgetsBinding.instance.addObserver(_AppLifecycleObserver());
  runApp(const MyFinanceApp());
}

/// Cancels the persistent notification when the app is fully detached (force-
/// closed from recents). Has no effect when the app is merely backgrounded.
class _AppLifecycleObserver extends WidgetsBindingObserver {
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.detached) {
      NotificationService.instance.cancelPersistentNotification();
    }
  }
}

class MyFinanceApp extends StatelessWidget {
  const MyFinanceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: settings,
      builder: (context, _) {
        final seed = Color(settings.themeSeedColor);
        final customBg = settings.scaffoldBgColor;
        final customFont = settings.fontColor;
        final imgPath = settings.bgImagePath;
        final hasBgImage = imgPath != null && imgPath.isNotEmpty;

        // When a background image is set, scaffolds become transparent so the
        // image painted by the MaterialApp builder shows through.
        final lightBg =
            hasBgImage ? Colors.transparent : (customBg ?? const Color(0xFFFFFDF5));
        final darkBg = hasBgImage ? Colors.transparent : customBg;

        TextTheme? withFontColor(TextTheme base) => customFont == null
            ? null
            : base.apply(bodyColor: customFont, displayColor: customFont);

        return MaterialApp(
          title: 'MyFinance',
          debugShowCheckedModeBanner: false,
          navigatorKey: navigatorKey,
          locale: Locale(settings.locale),
          supportedLocales: const [Locale('vi'), Locale('en')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          themeMode: settings.flutterThemeMode,
          theme: ThemeData(
            useMaterial3: true,
            colorScheme: ColorScheme.fromSeed(seedColor: seed),
            scaffoldBackgroundColor: lightBg,
            textTheme: withFontColor(ThemeData().textTheme),
            appBarTheme: const AppBarTheme(centerTitle: false),
            inputDecorationTheme: const InputDecorationTheme(
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
          darkTheme: ThemeData(
            useMaterial3: true,
            colorScheme:
                ColorScheme.fromSeed(seedColor: seed, brightness: Brightness.dark),
            scaffoldBackgroundColor: darkBg,
            textTheme: withFontColor(
                ThemeData(brightness: Brightness.dark).textTheme),
            appBarTheme: const AppBarTheme(centerTitle: false),
            inputDecorationTheme: const InputDecorationTheme(
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
          // Paint background image behind all routes when one is set.
          builder: hasBgImage
              ? (_, child) => Stack(
                    children: [
                      Positioned.fill(
                        child: Image.file(
                          File(imgPath),
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                              const SizedBox.shrink(),
                        ),
                      ),
                      child!,
                    ],
                  )
              : null,
          home: const HomePage(),
          onGenerateRoute: (s) {
            if (s.name == '/quick-add') {
              final type = s.arguments as String?;
              return MaterialPageRoute(
                  builder: (_) => QuickAddPage(initialType: type));
            }
            if (s.name == '/') {
              return MaterialPageRoute(builder: (_) => const HomePage());
            }
            return null;
          },
        );
      },
    );
  }
}

void openQuickAdd(String txType) {
  navigatorKey.currentState?.pushNamed('/quick-add', arguments: txType);
}
