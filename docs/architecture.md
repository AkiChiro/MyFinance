# MyFinance — Architecture & System Design

## Layered architecture

```
┌─────────────────────────────────────────────────────────────────┐
│  UI layer (lib/ui/)                                             │
│  ConsumerWidget / ConsumerStatefulWidget + StreamBuilder        │
│  No direct DB access — everything via FinanceRepository         │
├─────────────────────────────────────────────────────────────────┤
│  Repository layer (lib/repositories/finance_repository.dart)    │
│  All write logic, dedup, overspend check, CSV delegation        │
│  Delegates read queries/streams back to AppDatabase              │
├─────────────────────────────────────────────────────────────────┤
│  Data layer (lib/data/database.dart)                            │
│  Drift ORM: table definitions, SQL queries, migrations          │
│  SQLite file: Documents/myfinance.sqlite                        │
├─────────────────────────────────────────────────────────────────┤
│  Services (lib/services/)                                       │
│  AppSettings, CaptureService, CategorySuggester,               │
│  NotificationService, PermissionCoordinator, CsvService         │
├─────────────────────────────────────────────────────────────────┤
│  Native Android (Kotlin)                                        │
│  BankCaptureService (NotificationListenerService)               │
│  CaptureChannelApi (Pigeon bridge)                              │
│  BootReceiver, WidgetProvider, NotificationService.kt           │
└─────────────────────────────────────────────────────────────────┘
```

## Riverpod providers

All providers are declared in `lib/providers.dart` and overridden in `main()` with real instances. Tests can override them with in-memory fakes.

| Provider | Type | Value |
|----------|------|-------|
| `dbProvider` | `Provider<AppDatabase>` | singleton Drift database |
| `repositoryProvider` | `Provider<FinanceRepository>` | singleton repository |
| `suggesterProvider` | `Provider<CategorySuggester>` | singleton ML-free heuristic suggester |
| `captureServiceProvider` | `Provider<CaptureService>` | singleton drain service |
| `settingsProvider` | `ChangeNotifierProvider<AppSettings>` | SharedPreferences wrapper (rebuilds UI on change) |

`settingsProvider` uses `ChangeNotifierProvider` from `flutter_riverpod/legacy.dart` (Riverpod 3.x removed the top-level export; must import `legacy.dart` explicitly).

## Database schema (schema version 6)

### Table: `wallets`

| Column | Type | Notes |
|--------|------|-------|
| `id` | TEXT PK | UUID v4 |
| `name` | TEXT | display name |
| `initial_balance` | INT | VND, whole number |
| `type` | TEXT | `'cash'` or `'bank'` |
| `package_name` | TEXT? | Android package name of linked bank app (ADR-0014) |
| `sort_order` | INT | user-defined display order; default 0 |

Partial unique index on `package_name WHERE package_name IS NOT NULL` — allows multiple wallets with `NULL` but enforces uniqueness among non-null values.

`sort_order` added in schema v6 (Issue #4). The v6 migration seeds initial values alphabetically using a subquery. New wallets are appended at the bottom via `sort_order = (SELECT COUNT(*) FROM wallets)` in raw SQL (bypasses the Drift ORM before build_runner regenerates the column accessor). `watchWallets()` orders by `sort_order ASC, name ASC`.

### Table: `txns`

| Column | Type | Notes |
|--------|------|-------|
| `id` | TEXT PK | UUID v4 |
| `type` | TEXT | `'spending'` / `'earning'` / `'transfer'` |
| `amount` | INT | VND, always positive |
| `description` | TEXT? | user note |
| `wallet_id` | TEXT | source wallet (or sole wallet for non-transfer) |
| `wallet_to_id` | TEXT? | destination wallet (transfer only) |
| `category` | TEXT? | category ID or null (null for transfers) |
| `timestamp` | INT | Unix seconds (Drift 2.x DateTimeColumn) |
| `created_at` | INT | Unix seconds |
| `imported` | BOOL | true = came from CSV import |
| `starred` | BOOL | user-starred or auto-starred |
| `wallet_from_name` | TEXT? | snapshot of source wallet name at import time |
| `wallet_to_name` | TEXT? | snapshot of destination wallet name at import time |
| `source` | TEXT | `textEnum<SourceType>`: `manual` / `csvImport` / `bankNotification` |
| `affects_balance` | BOOL | false for CSV context-only imports |

Partial indexes on `wallet_id`, `wallet_to_id`, `timestamp`, `(type, timestamp)` — all `WHERE affects_balance=1`.

### Table: `notification_captures`

| Column | Type | Notes |
|--------|------|-------|
| `id` | TEXT PK | UUID v4 |
| `package_name` | TEXT | Android package of bank app |
| `raw_title` | TEXT? | notification title (nullable — some banks omit it) |
| `raw_text` | TEXT | notification body text |
| `captured_at` | INT | Unix seconds — when the bank event happened |
| `amount` | INT? | parsed amount, null for unparsed |
| `direction` | TEXT? | `textEnum<CaptureDirection>`: `income` / `expense` |
| `parse_status` | TEXT | `textEnum<ParseStatus>`: `parsed` / `needsReview` / `unparsed` |
| `suggested_wallet_id` | TEXT? | resolved from wallet↔package link on insert |
| `suggested_category` | TEXT? | reserved for future use |
| `status` | TEXT | `textEnum<CaptureStatus>`: `pending` / `confirmed` / `dismissed` |
| `resulting_txn_id` | TEXT? | populated after confirmation |
| `dedup_key` | TEXT | `packageName \x1e normalizedText` for 2-minute dedup |

### Table: `app_categories`

| Column | Type | Notes |
|--------|------|-------|
| `id` | TEXT PK | stable string key (`'necessities'`, `'food'`, … or UUID for user-created) |
| `label` | TEXT | Vietnamese display name |
| `kind` | TEXT | `'spending'` or `'earning'` |
| `threshold` | INT | VND limit for auto-star (0 = disabled) |
| `is_default` | BOOL | seeded on first run |
| `archived` | BOOL | soft-delete (never physically remove — historical transactions reference category IDs) |
| `sort_order` | INT | display order |

## Append-only enums

These enums are serialized to the DB as their `.name` string. **Never** rename, reorder, or remove values — existing DB rows would become unparseable.

```dart
enum SourceType      { manual, csvImport, bankNotification }
enum CaptureDirection { income, expense }
enum ParseStatus     { parsed, needsReview, unparsed }
enum CaptureStatus   { pending, confirmed, dismissed }
```

## Balance computation

Balance is **derived, never stored** (ADR-0004). The SQL UNION ALL pattern decomposes every transaction into signed `(walletId, delta)` pairs, then sums by wallet:

```sql
-- earning  → +amount to wallet_id
-- spending → −amount to wallet_id
-- transfer → −amount to wallet_id, +amount to wallet_to_id
```

Only `affects_balance=1` rows are included. This means CSV context-only imports and any future non-balance-affecting entries are excluded from the running balance.

`wallets_page.dart` gets the reactive balance map from `repo.watchWalletBalances()`, which maps `walletId → computed balance`.

## Analytics computation

`AppDatabase.watchAnalyticsBundle(DateTime month)` emits an `AnalyticsBundle` whenever the `txns` table changes. The bundle is built by two SQL queries:

1. **Totals query**: one row with 6 conditional sums (current month spending/earning, previous month spending/earning, year-to-date spending/earning). All filters use `affects_balance=1 AND type!='transfer'`.
2. **Category breakdown**: two `GROUP BY category` queries (spending and earning) for the current month.

Timestamps are compared as Unix seconds in SQL to match Drift 2.x's storage format.

## Bank capture pipeline

```
Bank app posts notification
        │
        ▼
BankCaptureService.kt (NotificationListenerService)
  ─ checks if packageName ∈ watchedPackages
  ─ buffers {id, packageName, title, text, postTimeMillis}
    to SharedPreferences as JSON
        │
  (app opens or resumes)
        │
        ▼
CaptureService.drain()  [Dart, called from _AppLifecycleObserver]
  1. Compute watched = BankPackages.all ∪ wallet.packageNames
  2. setWatchedPackages(watched)   → syncs filter to native side
  3. drainCaptures()               → reads + removes from SharedPreferences buffer
  4. For each message:
     a. BankParserRegistry.forPackage(pkg)?.parse(raw)
     b. parsed → insertCapture(parseStatus: parsed|needsReview)
     c. null + money-shaped text → insertCapture(parseStatus: unparsed)
     d. null + no money shape → discard (OTP, promo)
  5. clearCaptures(allIds)         → confirms buffer cleared
        │
        ▼
FinanceRepository.insertCapture()
  ─ 2-minute dedup check on dedupKey
  ─ resolves suggestedWalletId from wallet↔package link
  ─ writes NotificationCaptures row
        │
        ▼
CapturesPage / badge / banner  [reactive via watchPendingCaptures()]
        │
  (user taps capture)
        │
        ▼
CaptureConfirmPage
  ─ user edits direction, amount, wallet, category, date
  ─ _confirm() → repo.confirmCapture()
        │
        ▼
FinanceRepository.confirmCapture()
  ─ db.transaction:
    1. resolve txnTimestamp = caller-supplied ?? capturedAt ?? now
    2. INSERT txns (source=bankNotification, affectsBalance=true)
    3. UPDATE notification_captures SET status=confirmed, resulting_txn_id=...
```

## Pigeon channel (`CaptureChannelApi`)

Pigeon generates type-safe Dart stubs from the `@HostApi` definition in `lib/pigeon/capture_channel.g.dart`. The Kotlin implementation is in `android/…/CaptureChannelApi.kt`.

Methods:
- `setWatchedPackages(List<String>)` — syncs the filter set to the native service
- `drainCaptures()` → `List<CapturedMessage>` — atomically reads + clears the SharedPreferences buffer
- `clearCaptures(List<String>)` — removes specific IDs from the buffer (used after file-then-clear cycle)
- `seenPackages()` → `List<String>` — returns every package whose notification has ever been seen (used by the developer dialog)

## Services

### `AppSettings`

`ChangeNotifier` wrapping SharedPreferences. Reads and writes happen immediately; `notifyListeners()` is called on every setter, triggering a rebuild in any widget that `ref.watch(settingsProvider)`.

Settings keys: `ui.locale`, `currency.symbol`, `autostar.enabled`, `theme.mode`, `theme.seedColor`, `ui.scaffoldBgColor`, `ui.fontColor`, `ui.bgImagePath`, `notif.enabled`.

### `CategorySuggester`

Heuristic pattern-matching against transaction description text. Used in `QuickAddPage` to auto-select a category when the user types a description. Falls back to empty (no suggestion) if no pattern matches.

### `NotificationService`

Flutter-side wrapper for `flutter_local_notifications`. Creates and manages a persistent "Nhấn để ghi giao dịch nhanh" notification in the status bar. The notification has "Chi tiêu" and "Thu nhập" action buttons that deep-link into `QuickAddPage` via `openQuickAdd(txType)`.

### `CsvService`

- Export: produces two CSV files (transactions + wallets) and shares them via `share_plus`.
- Import: parses a CSV, resolves wallets by name (with snapshot name fallback), inserts transactions with `source=csvImport` and respects the user-chosen `CsvImportMode` for `affectsBalance`.

### `PermissionCoordinator`

Routes permission requests by class:
- `POST_NOTIFICATIONS` → runtime dialog via `permission_handler`
- Notification-listener access → deep-links to system Settings screen (no dialog — special access class)

## Navigation

`HomePage` is the root scaffold. It uses a `NavigationBar` with 4 destinations. The Giao dịch tab icon shows a `Badge` when `pendingCaptureCount > 0`.

Tab switching: `GestureDetector` wraps the `IndexedStack` body with `onHorizontalDragEnd`. Swipe left (velocity < −300) advances one tab; swipe right (velocity > 300) goes back one tab. `HitTestBehavior.opaque` ensures the gesture captures swipes over any child widget that doesn't handle them itself.

Sub-screens are pushed with `Navigator.of(context).push(MaterialPageRoute(...))`. There is no named-route graph beyond `/` and `/quick-add`.

`navigatorKey` in `main.dart` is a global `GlobalKey<NavigatorState>` used by `openQuickAdd()` to push `QuickAddPage` from outside the widget tree (notification action button tap).

### Sub-screens

| Screen | Entry | File |
|--------|-------|------|
| `QuickAddPage` | FAB, tile tap, notification, action "Sửa" | `lib/ui/quick_add_page.dart` |
| `WalletEditPage` | wallet tile tap | `lib/ui/wallet_edit_page.dart` |
| `CapturesPage` | captures banner tap | `lib/ui/captures_page.dart` |
| `CaptureConfirmPage` | capture tile tap | `lib/ui/capture_confirm_page.dart` |
| `CategoriesPage` | Settings → Quản lý danh mục | `lib/ui/categories_page.dart` |
| `ThemeCustomizationPage` | Settings → Tuỳ chỉnh giao diện | `lib/ui/theme_customization_page.dart` |
