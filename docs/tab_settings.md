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
        ├─ "Ngôn ngữ" section
        │   └─ SegmentedButton<String> (Tiếng Việt / English → settings.locale)
        ├─ "Đơn vị tiền tệ" section
        │   └─ "Ký hiệu tiền tệ" tile → symbol edit dialog
        ├─ "Tự động đánh dấu sao" section
        │   └─ SwitchListTile (autostar toggle)
        ├─ "Danh mục" section
        │   └─ "Quản lý danh mục" tile → CategoriesPage
        ├─ "Giao diện" section
        │   ├─ "Chế độ màu" SegmentedButton (system/light/dark)
        │   └─ "Tuỳ chỉnh nâng cao" tile → ThemeCustomizationPage
        ├─ "Sao lưu dữ liệu (CSV)" section
        │   ├─ "Xuất CSV" tile
        │   └─ "Nhập CSV" tile
        ├─ "Danh mục gợi ý" section
        │   └─ "Thư viện từ khoá" tile → KeywordEditorPage
        ├─ "Thông tin" section (about card)
        └─ "Nhà phát triển" section
            ├─ "Cấp quyền nghe thông báo" tile
            └─ "Gói ứng dụng đã thấy" tile
```

## Icon customization ("Biểu tượng" section, `ThemeCustomizationPage`)

Below "Ảnh nền", grouped into 5 sub-`Card`s (Điều hướng / Nút thêm nhanh / Loại giao dịch / Đánh dấu sao / Loại ví — `kIconSlotGroups` in `lib/ui/widgets/icon_slots.dart`). Each row: `AppIcon` thumbnail, slot display name, a reset `IconButton` (shown only when a custom image is set) + chevron. Tapping a row opens the file picker (`FilePicker.platform.pickFiles(type: FileType.image)`), copies the result into `.../customization/icons/<slotId>.<ext>`, and calls `settings.setIconPath(slotId, path)`. In-app guidance text above the groups recommends square PNGs, 128×128 minimum / 256×256 recommended. The page's "Đặt lại" action (app bar + confirm dialog) now also clears every icon slot, not just colors/background.

See `docs/architecture.md`'s "Icon customization (`AppIcon`)" section for the full design (11 slots, storage, fallback resolution).

## Language toggle

`SegmentedButton<String>` with two segments (`'vi'` → "Tiếng Việt", `'en'` → "English" — language endonyms, hardcoded rather than translated, so a Vietnamese speaker always sees "Tiếng Việt" regardless of the active locale). `onSelectionChanged` writes `settings.locale`, which `MyFinanceApp` already watches (`locale: Locale(settings.locale)`), so every screen using `AppLocalizations.of(context)!` rebuilds immediately. If the persistent notification is currently enabled, the handler also calls `NotificationService.instance.showPersistentNotification(locale: s.first)` so the tray notification's text updates without waiting for the next toggle/resume. See `docs/architecture.md`'s "Localization (l10n)" section for the full l10n design.

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
final file = await repo.csv.exportAll(
  settingsEntries: settings.exportEntries(kIconSlots),
  keywordRules: await suggester.loadRaw(),
);
await SharePlus.instance.share(ShareParams(files: [file], subject: 'MyFinance — sao lưu CSV'));
```

`CsvService.exportAll()` writes a **single** CSV file covering wallets, transactions, categories, app settings, and the keyword library — see `docs/architecture.md`'s "CSV export/import" section for the row format. `SharePlus` opens the system share sheet. `_busy` guards against concurrent taps.

## CSV import (`_import`)

```dart
1. showDialog → confirm (non-destructive wording — nothing is deleted)
2. FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['csv'])
3. repo.csv.importAll(file.path)
```

A single import path, no mode picker. `importAll` reads **wallets + transactions only** from the file (categories/settings/keywords are export-only, not restored). Wallets are insert-if-absent — a row whose id already exists in the database is skipped, so the device's live `balance_cutoff_at`/`sort_order`/`package_name` are never clobbered by an older export. Transactions are upserted by id, so re-importing the same file (or importing overlapping backups) is safe and idempotent. The result snackbar reports wallets-added/skipped and transactions-added/updated counts separately.

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
| `repo.csv.exportAll(settingsEntries:, keywordRules:)` | `CsvService.exportAll()` |
| `repo.csv.importAll(path)` | `CsvService.importAll()` |
| `captureService.permissions.requestNotificationListenerPermission()` | `PermissionCoordinator` |
| `captureService.seenPackages()` | Pigeon → Kotlin |
| `settings.notifEnabled = v` | `AppSettings.notifEnabled` setter |
