import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Reactive, persisted settings. Wrap MaterialApp in a ListenableBuilder so
/// theme, currency, and locale rebuild automatically on change.
class AppSettings extends ChangeNotifier {
  AppSettings._(this._prefs);

  final SharedPreferences _prefs;

  static Future<AppSettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    return AppSettings._(prefs);
  }

  // ── locale ──────────────────────────────────────────────────────────────────
  String get locale => _prefs.getString('ui.locale') ?? 'vi';
  set locale(String v) {
    _prefs.setString('ui.locale', v);
    notifyListeners();
  }

  // ── currency ─────────────────────────────────────────────────────────────────
  String get currencySymbol => _prefs.getString('currency.symbol') ?? '₫';
  set currencySymbol(String v) {
    _prefs.setString('currency.symbol', v);
    notifyListeners();
  }

  // currencySuffix is always true — symbol always follows the amount.
  bool get currencySuffix => true;

  // ── auto-star ────────────────────────────────────────────────────────────────
  bool get autostarEnabled => _prefs.getBool('autostar.enabled') ?? true;
  set autostarEnabled(bool v) {
    _prefs.setBool('autostar.enabled', v);
    notifyListeners();
  }

  // ── theme ─────────────────────────────────────────────────────────────────────
  /// "system" | "light" | "dark"
  String get themeMode => _prefs.getString('theme.mode') ?? 'system';
  set themeMode(String v) {
    _prefs.setString('theme.mode', v);
    notifyListeners();
  }

  /// Seed color as an ARGB int. Default amber (0xFFFFC107).
  int get themeSeedColor => _prefs.getInt('theme.seedColor') ?? 0xFFFFC107;
  set themeSeedColor(int v) {
    _prefs.setInt('theme.seedColor', v);
    notifyListeners();
  }

  // ── custom scaffold background color (null = theme default) ─────────────────
  Color? get scaffoldBgColor {
    final v = _prefs.getInt('ui.scaffoldBgColor');
    return v == null ? null : Color(v);
  }

  set scaffoldBgColor(Color? v) {
    if (v == null) {
      _prefs.remove('ui.scaffoldBgColor');
    } else {
      // ignore: deprecated_member_use
      _prefs.setInt('ui.scaffoldBgColor', v.value);
    }
    notifyListeners();
  }

  // ── custom font color (null = theme default) ─────────────────────────────────
  Color? get fontColor {
    final v = _prefs.getInt('ui.fontColor');
    return v == null ? null : Color(v);
  }

  set fontColor(Color? v) {
    if (v == null) {
      _prefs.remove('ui.fontColor');
    } else {
      // ignore: deprecated_member_use
      _prefs.setInt('ui.fontColor', v.value);
    }
    notifyListeners();
  }

  // ── background image path (null = none) ──────────────────────────────────────
  String? get bgImagePath => _prefs.getString('ui.bgImagePath');
  set bgImagePath(String? v) {
    if (v == null) {
      _prefs.remove('ui.bgImagePath');
    } else {
      _prefs.setString('ui.bgImagePath', v);
    }
    notifyListeners();
  }

  // ── notification toggle ────────────────────────────────────────────────────
  bool get notifEnabled => _prefs.getBool('notif.enabled') ?? true;
  set notifEnabled(bool v) {
    _prefs.setBool('notif.enabled', v);
    notifyListeners();
  }

  // ── helpers ───────────────────────────────────────────────────────────────────
  ThemeMode get flutterThemeMode => switch (themeMode) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      };
}
