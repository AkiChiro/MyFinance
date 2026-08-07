import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'data/database.dart';
import 'l10n/generated/app_localizations.dart';
import 'providers.dart';
import 'repositories/finance_repository.dart';
import 'services/app_settings.dart';
import 'services/capture_channel.dart';
import 'services/capture_service.dart';
import 'services/category_suggester.dart';
import 'services/notification_service.dart';
import 'ui/home_page.dart';
import 'ui/quick_add_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final db = AppDatabase();
  final repository = FinanceRepository(db);
  final suggester = CategorySuggester();
  final settings = await AppSettings.load();
  await suggester.load();
  await NotificationService.instance
      .init(enabled: settings.notifEnabled, locale: settings.locale);
  final captureService =
      CaptureService(repo: repository, api: LiveCaptureChannelApi());
  WidgetsBinding.instance.addObserver(_AppLifecycleObserver(captureService));
  // Initial drain after the first frame, when Pigeon channel bindings are
  // registered in configureFlutterEngine.
  WidgetsBinding.instance
      .addPostFrameCallback((_) => captureService.drain());
  runApp(
    ProviderScope(
      overrides: [
        dbProvider.overrideWithValue(db),
        repositoryProvider.overrideWithValue(repository),
        suggesterProvider.overrideWithValue(suggester),
        settingsProvider.overrideWith((_) => settings),
        captureServiceProvider.overrideWithValue(captureService),
      ],
      child: const MyFinanceApp(),
    ),
  );
}

class _AppLifecycleObserver extends WidgetsBindingObserver {
  _AppLifecycleObserver(this._captureService);

  final CaptureService _captureService;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.detached) {
      NotificationService.instance.cancelPersistentNotification();
    }
    // Drain the native notification buffer every time the app comes to
    // foreground so captures are filed promptly on resume.
    if (state == AppLifecycleState.resumed) {
      _captureService.drain();
    }
  }
}

class MyFinanceApp extends ConsumerWidget {
  const MyFinanceApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
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

    // fontFamily applies unconditionally (Nunito, bundled asset); only the
    // body/display color override stays conditional on a custom font color.
    TextTheme withFont(TextTheme base) => base.apply(
          fontFamily: 'Nunito',
          bodyColor: customFont,
          displayColor: customFont,
        );

    final lightScheme = ColorScheme.fromSeed(seedColor: seed);
    final darkScheme =
        ColorScheme.fromSeed(seedColor: seed, brightness: Brightness.dark);

    CardThemeData cardTheme(ColorScheme scheme) => CardThemeData(
          elevation: 0,
          color: scheme.surfaceContainerHigh,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        );
    const chipTheme = ChipThemeData(shape: StadiumBorder());

    return MaterialApp(
      title: 'MyFinance',
      debugShowCheckedModeBanner: false,
      navigatorKey: navigatorKey,
      locale: Locale(settings.locale),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      themeMode: settings.flutterThemeMode,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: lightScheme,
        scaffoldBackgroundColor: lightBg,
        textTheme: withFont(ThemeData().textTheme),
        appBarTheme: const AppBarTheme(centerTitle: false),
        cardTheme: cardTheme(lightScheme),
        chipTheme: chipTheme,
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(),
          isDense: true,
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: darkScheme,
        scaffoldBackgroundColor: darkBg,
        textTheme: withFont(ThemeData(brightness: Brightness.dark).textTheme),
        appBarTheme: const AppBarTheme(centerTitle: false),
        cardTheme: cardTheme(darkScheme),
        chipTheme: chipTheme,
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
  }
}

void openQuickAdd(String txType) {
  navigatorKey.currentState?.pushNamed('/quick-add', arguments: txType);
}
