# MyFinance — Project Overview

## What this app is

MyFinance is an offline Android personal-finance app built for Vietnamese users. Every amount is stored and computed as whole-number VND integers (no decimals). The UI is Vietnamese throughout. The app's distinguishing feature is **automatic bank-notification capture**: it reads incoming push notifications from supported Vietnamese bank apps (OCB, MB, Techcombank), extracts the transaction amount and direction using per-bank regex parsers, and surfaces a pre-filled entry the user can confirm or dismiss — rather than auto-importing, which would risk silent corruption of the ledger.

## Platform

Android only. The bank-notification feature requires `NotificationListenerService`, which does not exist on iOS (see ADR-0001). The app contains first-party Kotlin code for the native layer, bridged to Flutter via Pigeon-generated typed channels.

## Tech stack

| Layer | Tech | Version |
|-------|------|---------|
| UI + business logic | Flutter / Dart | 3.x |
| Reactive state | Riverpod | 3.x (providers in `legacy.dart`) |
| Database ORM | Drift | 2.29.0 |
| Platform channel | Pigeon | 22.7.4 |
| Kotlin (native) | Android Notification Listener, Widget, Boot Receiver | — |
| Persistence (settings) | shared_preferences | — |
| Charts | fl_chart | — |

## Repository layout

```
lib/
  main.dart                   — app bootstrap, lifecycle observer, drain wiring
  providers.dart              — Riverpod provider declarations
  format.dart                 — VND formatters, parseAmount helper
  models/domain.dart          — enums (TxTypes, SourceType, CaptureStatus, …) + category constants
  data/database.dart          — Drift schema (4 tables), migrations, SQL queries, AnalyticsBundle
  data/database.g.dart        — Drift generated code (do not edit)
  repositories/
    finance_repository.dart   — all write logic, dedup, confirmCapture, CSV delegation
  services/
    app_settings.dart         — SharedPreferences wrapper (ChangeNotifier)
    capture_service.dart      — drain logic: parse + file + clear
    category_suggester.dart   — heuristic category suggestion from description text
    notification_service.dart — flutter_local_notifications persistent quick-add notification
    permission_coordinator.dart — routes permission requests by class
    csv_service.dart          — CSV export/import
    bank/
      bank_notification_parser.dart — BankPackages constants, BankParserRegistry, strategy interface
      parsed_notification.dart      — RawNotification, ParsedNotification value types
      ocb_parser.dart               — OCB regex parser
      mb_parser.dart                — MB regex parser
      techcombank_parser.dart       — Techcombank regex parser
  ui/
    home_page.dart            — 4-tab scaffold, nav-bar badge, lifecycle home
    wallets_page.dart         — Ví tab: wallet list, add/edit/link dialogs
    transactions_page.dart    — Giao dịch tab: transaction list, filter, captures banner
    analytics_page.dart       — Thống kê tab: monthly summary + pie charts
    settings_page.dart        — Cài đặt tab: settings, CSV, developer section
    quick_add_page.dart       — Add/edit transaction form (shared between manual and editing flow)
    categories_page.dart      — Category management screen
    theme_customization_page.dart — Theme + background image customizer
    captures_page.dart        — Bank notification inbox (Phase 5d)
    capture_confirm_page.dart — Review and confirm/dismiss a single capture (Phase 5d)
  pigeon/
    capture_channel.g.dart    — Pigeon generated Dart stubs

android/app/src/main/kotlin/com/huy/myfinance/
  MainActivity.kt             — Flutter engine host
  BankCaptureService.kt       — NotificationListenerService (captures → SharedPreferences buffer)
  CaptureChannelApi.kt        — Pigeon Kotlin implementation
  NotificationService.kt      — Persistent quick-add notification (Kotlin side)
  BootReceiver.kt             — Reposts notification after device reboot
  WidgetProvider.kt           — App widget

docs/                         — all developer documentation (you are here)
test/                         — unit tests (Drift in-memory DB, no widget tests yet)
android_overlay/              — source-controlled Kotlin files patched in by patch_android.py
Makefile                      — build shortcuts
```

## Building

```bash
make init   # one-time: pub get + patch_android.py + pigeon + build_runner
make apk    # release APK → build/app/outputs/flutter-apk/app-release.apk
make test   # flutter test
make lint   # flutter analyze
```

`patch_android.py` copies files from `android_overlay/` into `android/` (idempotent). It must be run once (`make init`) before building, and again if overlay files change.

## Features by phase

| Phase | Feature |
|-------|---------|
| 1 | Riverpod DI, remove globals, SQLite via Drift, basic wallet/transaction CRUD, tests |
| 2 | Categories (CRUD, thresholds), starred transactions, CSV export/import |
| 3 | `source` / `affectsBalance` columns (separate CSV history from live balance), schema migration |
| 4 | SQL-computed balance and analytics (replace Dart fold with `SUM`/`GROUP BY` queries) |
| 5a | `NotificationCaptures` table + `Wallets.packageName`, schema v5, dedup key |
| 5b | Per-bank parsers (OCB, MB, Techcombank), `BankParserRegistry`, `ParseStatus` |
| 5c | Native `BankCaptureService` (Kotlin), Pigeon channel, `CaptureService.drain()` |
| 5d | Captures inbox (`CapturesPage`), confirm screen (`CaptureConfirmPage`), nav-bar badge |

## Key design rules

- **Amounts are whole-number VND integers.** Never use `double` for money.
- **Enums stored as `textEnum` are append-only.** Never reorder, rename, or remove a value from `SourceType`, `CaptureDirection`, `ParseStatus`, or `CaptureStatus` — old rows in production databases would become unreadable.
- **Balance is derived, never stored.** `initialBalance + Σ(transaction deltas)` computed in SQL. The SQL UNION ALL pattern handles transfers correctly (subtract from source, add to destination) — see `_kAllBalancesSql` in `database.dart`.
- **Confirm, don't auto-import.** Bank notifications produce proposals that require user confirmation. A parser bug cannot silently corrupt the ledger.
- **Dedup on insert.** `insertCapture` checks for an identical `dedupKey` within a 2-minute window before inserting, making drain re-runs after a crash safe.
- **File-then-clear ordering.** `CaptureService.drain()` writes all captures to Drift before calling `clearCaptures()` on the native buffer. A crash mid-drain causes a re-drain, not data loss.
