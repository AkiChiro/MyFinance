# Cài đặt Tab — Developer Reference

File: `lib/ui/settings_page.dart`  
Settings model: `lib/services/app_settings.dart`

## Overview

The Cài đặt tab exposes: persistent notification toggle, CSV export/import, category management, theme customization, and a developer section for the bank-notification capture system.

## Widget structure

```
SettingsPage (ConsumerStatefulWidget)
  └─ _SettingsPageState
     └─ ListView
        ├─ "Thông báo" section
        │   └─ SwitchListTile (persistent notification enable/disable)
        ├─ "Dữ liệu" section
        │   ├─ "Xuất CSV" tile
        │   └─ "Nhập / Hợp nhất CSV" tile
        ├─ "Danh mục" section
        │   └─ "Quản lý danh mục" tile → CategoriesPage
        ├─ "Giao diện" section
        │   └─ "Tuỳ chỉnh giao diện" tile → ThemeCustomizationPage
        ├─ "Tự động gắn sao" section
        │   └─ SwitchListTile (autostar toggle)
        └─ "Nhà phát triển" section
            ├─ "Cấp quyền nghe thông báo" tile
            └─ "Gói ứng dụng đã thấy" tile
```

## `AppSettings` service

`AppSettings` is a `ChangeNotifier` backed by `SharedPreferences`. Each setting is a getter/setter pair that reads/writes a typed pref key and calls `notifyListeners()`.

Settings exposed:

| Setting | Pref key | Type | Default |
|---------|----------|------|---------|
| `locale` | `ui.locale` | String | `'vi'` |
| `currencySymbol` | `currency.symbol` | String | `'₫'` |
| `currencySuffix` | — | bool | always `true` |
| `autostarEnabled` | `autostar.enabled` | bool | `true` |
| `themeMode` | `theme.mode` | String | `'system'` |
| `themeSeedColor` | `theme.seedColor` | int (ARGB) | amber `0xFFFFC107` |
| `scaffoldBgColor` | `ui.scaffoldBgColor` | int? | null |
| `fontColor` | `ui.fontColor` | int? | null |
| `bgImagePath` | `ui.bgImagePath` | String? | null |
| `notifEnabled` | `notif.enabled` | bool | `true` |

`flutterThemeMode` is a computed getter: `'light' → ThemeMode.light`, `'dark' → ThemeMode.dark`, else `ThemeMode.system`.

`MyFinanceApp` wraps the `MaterialApp` in a `ConsumerWidget` that `ref.watch(settingsProvider)`, so any `notifyListeners()` call rebuilds the theme and locale throughout the app.

## Persistent notification toggle

```dart
SwitchListTile(
  value: settings.notifEnabled,
  onChanged: (v) async {
    settings.notifEnabled = v;
    if (v) {
      await NotificationService.instance.showPersistentNotification();
    } else {
      await NotificationService.instance.cancelPersistentNotification();
    }
  },
)
```

The toggle both saves the pref and immediately shows/hides the notification.

## CSV export (`_export`)

```dart
final files = await repo.csv.export();
await SharePlus.instance.share(ShareParams(files: files, subject: 'MyFinance — sao lưu CSV'));
```

`CsvService.export()` returns two `XFile`s (transactions.csv, wallets.csv). `SharePlus` opens the system share sheet. `_busy` guards against concurrent taps.

## CSV import (`_importMerge`)

```dart
1. showDialog → user picks CsvImportMode (contextOnly or reconstructBalance)
2. FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['csv'])
3. repo.csv.importMerge(file.path, mode)
```

**contextOnly**: `affectsBalance = false` — imported rows are display-only history, don't move wallet balances.  
**reconstructBalance**: `affectsBalance = true` — use for empty wallets being bootstrapped from a CSV backup; the import moves the balance.

## Category management

Navigates to `CategoriesPage` (separate file). Category changes are immediately reflected everywhere via `watchActiveCategories` streams.

## Theme customization

Navigates to `ThemeCustomizationPage`. Allows changing seed color, dark/light/system mode, custom scaffold background color, custom font color, and a background image. All changes write to `AppSettings` which triggers a global rebuild.

## Auto-star toggle

```dart
SwitchListTile(
  value: settings.autostarEnabled,
  onChanged: (v) => settings.autostarEnabled = v,
)
```

When disabled, `isAutoStarred` always returns false. Manually starred transactions remain starred regardless.

## Developer section

### "Cấp quyền nghe thông báo"

```dart
onTap: () async {
  final coordinator = ref.read(captureServiceProvider).permissions;
  await coordinator.requestNotificationListenerPermission();
}
```

`PermissionCoordinator.requestNotificationListenerPermission()` opens the system notification-listener settings screen (not a permission dialog — this is a special-access permission class that Android only grants via its own settings UI).

**On Vivo/OriginOS:** The user must first open App Manager → MyFinance → Battery → remove background restriction. Without this, the system settings toggle is present but the service is silently killed.

### "Gói ứng dụng đã thấy"

```dart
onTap: () async {
  final pkgs = await ref.read(captureServiceProvider).seenPackages();
  showDialog(... Text(pkgs.join('\n')) ...)
}
```

Calls `CaptureService.seenPackages()` → Pigeon → Kotlin → reads the `seenPackages` set from SharedPreferences. Useful for discovering the exact package names of bank apps on a specific device (confirmed OCB and Techcombank package names this way during Phase 5 testing).

## Key repository / service calls

| Call | Source |
|------|--------|
| `repo.csv.export()` | `CsvService.export()` |
| `repo.csv.importMerge(path, mode)` | `CsvService.importMerge()` |
| `captureService.permissions.requestNotificationListenerPermission()` | `PermissionCoordinator` |
| `captureService.seenPackages()` | Pigeon → Kotlin |
| `settings.notifEnabled = v` | `AppSettings.notifEnabled` setter |
