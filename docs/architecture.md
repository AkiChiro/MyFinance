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
| `monthModeProvider` | `StateProvider<bool>` | whether the Giao dịch tab is in month-filter mode |
| `selectedMonthProvider` | `StateProvider<DateTime>` | the month currently shown in month-filter mode |
| `homeTabIndexProvider` | `StateProvider<int>` | bottom-nav tab index — lifted out of `HomePage` local `State` so other screens can switch tabs (e.g. Analytics drill-down) |
| `txnTypeFilterProvider` | `StateProvider<String?>` | Giao dịch's active type filter (`TxTypes.spending`/`.earning`/`null`) |
| `txnCategoryFilterProvider` | `StateProvider<String?>` | Giao dịch's active category filter |
| `txnStarredOnlyProvider` | `StateProvider<bool>` | Giao dịch's "Có sao" filter |

`settingsProvider` uses `ChangeNotifierProvider` from `flutter_riverpod/legacy.dart` (Riverpod 3.x removed the top-level export; must import `legacy.dart` explicitly).

`homeTabIndexProvider`/`txnTypeFilterProvider`/`txnCategoryFilterProvider`/`txnStarredOnlyProvider` follow the exact `monthModeProvider`/`selectedMonthProvider` pattern: cross-widget UI state lives in a `StateProvider` rather than a screen's local `State`, whenever more than one screen needs to read or write it. `TransactionsPage` is still each filter's primary owner (`_sortDirection` alone stays local `State` — it reorders, never hides rows, so no other screen needs to touch it); `AnalyticsPage` writes all four as part of drill-down navigation — see "Analytics drill-down" below.

## Database schema (schema version 9)

### Table: `wallets`

| Column | Type | Notes |
|--------|------|-------|
| `id` | TEXT PK | UUID v4 |
| `name` | TEXT | display name |
| `initial_balance` | INT | VND, whole number |
| `type` | TEXT | `'cash'` or `'bank'` |
| `package_name` | TEXT? | Android package name of linked bank app (ADR-0014) |
| `sort_order` | INT | user-defined display order; default 0 |
| `balance_cutoff_at` | INT? | Unix seconds; when set, only transactions at or after this timestamp affect the balance for this wallet |

Partial unique index on `package_name WHERE package_name IS NOT NULL` — allows multiple wallets with `NULL` but enforces uniqueness among non-null values.

`sort_order` added in schema v6 (Issue #4). The v6 migration seeds initial values alphabetically using a subquery. New wallets are appended at the bottom via `sort_order = (SELECT COUNT(*) FROM wallets)` in raw SQL (bypasses the Drift ORM before build_runner regenerates the column accessor). `watchWallets()` orders by `sort_order ASC, name ASC`.

`balance_cutoff_at` added in schema v7. Used by the balance-reset feature — see Balance computation below.

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
| `starred` | BOOL | user-starred or auto-starred (written at creation/edit, not computed at render) |
| `wallet_from_name` | TEXT? | snapshot of source wallet name at import time |
| `wallet_to_name` | TEXT? | snapshot of destination wallet name at import time |
| `source` | TEXT | `textEnum<SourceType>`: `manual` / `csvImport` / `bankNotification` |
| `affects_balance` | BOOL | false for CSV context-only imports; does NOT gate analytics (analytics counts all non-transfer txns) |

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
| `envelope_cutoff_at` | INT? | Unix seconds; when set, only transactions at or after this timestamp count toward this category's envelope allocated/spent totals |

### Table: `category_budget_history`

| Column | Type | Notes |
|--------|------|-------|
| `id` | TEXT PK | UUID v4 |
| `category_id` | TEXT | spending category id (no FK — matches `txns.category`'s plain-string-id convention) |
| `percent` | INT | 0-100, whole percent of every earning allocated to this category |
| `effective_from` | INT | Unix seconds |

Append-only (schema v8) — a percent edit always **inserts** a new row, never updates one. Never physically pruned. See "Envelope budgeting" below for how this is read.

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

Only `affects_balance=1` rows are included. This means CSV context-only imports are excluded from the running balance. Transactions linked to wallets with a `balance_cutoff_at` are also excluded per-wallet (see below).

**Wallet balance reset** (Option C — per-wallet timestamp cutoff): when a user changes `initialBalance` in `WalletEditPage`, `updateWallet(resetTransactions: true)` is called. Inside a single DB transaction it updates the wallet's `initialBalance` and sets `balance_cutoff_at = unix_now` on that wallet row. The balance SQL then applies `AND timestamp >= COALESCE(balance_cutoff_at, 0)` per-wallet via a JOIN, so only transactions after the cutoff accumulate on top of `initialBalance`. Critically, resetting wallet A does **not** affect wallet B's view of shared transfer rows — each wallet applies its own cutoff independently.

`wallets_page.dart` gets the reactive balance map from `repo.watchWalletBalances()`, which maps `walletId → computed balance`.

## Analytics computation

`AppDatabase.watchAnalyticsBundle(DateTime month)` emits an `AnalyticsBundle` whenever the `txns` table changes. The bundle is built by two SQL queries:

1. **Totals query**: one row with 6 conditional sums (current month spending/earning, previous month spending/earning, year-to-date spending/earning). Filter: `WHERE type!='transfer'` — all non-transfer transactions regardless of `affects_balance`.
2. **Category breakdown**: two `GROUP BY category` queries (spending and earning) for the current month. Same filter — no `affects_balance` gate.

Analytics intentionally counts **all visible transactions** (no `affects_balance` filter), so a balance reset does not remove old spending/earning from analytics totals. Only `type='transfer'` rows are excluded since transfers are zero-sum across wallets.

Timestamps are compared as Unix seconds in SQL to match Drift 2.x's storage format.

## Envelope budgeting

The user assigns each active spending category a % of every earning (e.g. Thiết yếu 50%, Ăn uống 15%, Sở thích 20%, Khác 15%); the category's envelope balance is that accumulated share minus whatever's been spent in that category. Like balance (ADR-0004) and analytics, this is **computed entirely on read** — nothing is written to `txns`/`wallets`/`app_categories`, and `addSpending`/`addEarning`/`updateTxn`/`deleteTxn`/`confirmCapture` have zero envelope-specific code.

**Non-retroactive percentages**: `category_budget_history` is append-only — editing a category's % inserts a new row (`effective_from = now`) rather than mutating one. `AppDatabase._buildEnvelopeBalances()` reads it via an "as-of" join: for each earning, the applicable percent is the history row with the largest `effective_from <= ` that earning's own `timestamp`. This makes a percent change apply only to income recorded after the change — mirrors `wallets.balance_cutoff_at`'s point-in-time cutover, just as a full history instead of one mutable column. An earning older than any configured percent for a category contributes exactly $0 (no applicable row) — no backfill migration needed when a percent is first set.

```sql
-- earned share per active spending category (as-of join against history),
-- filtered by this category's own envelope_cutoff_at
SELECT c.id, SUM(e.amount * <percent in effect at e.timestamp> / 100)
FROM app_categories c ... JOIN txns e ON e.type='earning' AND e.affects_balance=1
  AND e.timestamp >= COALESCE(c.envelope_cutoff_at, 0)
WHERE c.kind='spending' AND c.archived=0

-- spent per category, all-time (not month-scoped), same cutoff filter —
-- joined on the coalesced category value so null-category spending still
-- resolves to the 'others' row's own cutoff
SELECT COALESCE(t.category,'others'), SUM(t.amount)
FROM txns t JOIN app_categories c ON c.id = COALESCE(t.category,'others')
WHERE t.type='spending' AND t.affects_balance=1
  AND t.timestamp >= COALESCE(c.envelope_cutoff_at, 0)
GROUP BY 1
```

`envelope = earned − spent`, glued in Dart per category into `EnvelopeStatus{allocated, spent}` (a `balance` getter computes `allocated - spent`) — `AppDatabase.watchEnvelopeBalances()` returns `Stream<Map<String, EnvelopeStatus>>`, exposed via `FinanceRepository`; keeping both numbers rather than only their difference is what lets the Analytics tab's `_EnvelopeSection` render a spent-vs-allocated progress bar (see `docs/tab_analytics.md`). Unlike analytics, envelopes **filter on `affects_balance`** — they track real money only, not CSV context-only rows. Transfers never participate (never `type='spending'`/`'earning'`). Archived categories are excluded from the read (`archived=0`) — no special-casing needed in the write paths; if later unarchived, its envelope recomputes across its whole history as if always active, consistent with how `archived` behaves everywhere else in this codebase (a hide flag, not a timeline toggle). `watchEnvelopeBalances()` listens for changes on `txns`, `category_budget_history`, **and** `app_categories` (editing a % or archiving a category must both trigger a re-emit — `watchAnalyticsBundle` only listens to `txns`, which would silently miss those two).

**Overspending an envelope is informational only** — a spending transaction that pushes a category negative still saves normally; this is independent of the hard wallet-balance guard (`OverspendException`/`_assertSufficient`).

**Setting a percent** (`FinanceRepository.setCategoryBudgetPercent`): mirrors `OverspendException`'s zero-payload-exception shape. Throws `BudgetPercentExceededException` if the new percent, summed with every other *active* spending category's current percent (the target category's own prior value is excluded from the sum, not double-counted), would exceed 100%. Summing to less than 100% is allowed — the shortfall is just untracked in any envelope. Editing the percent is exposed both from Cài đặt → Quản lý danh mục and directly on the Thống kê tab (see `docs/tab_analytics.md`), both calling the same repository method.

**Resetting an envelope** (`FinanceRepository.resetEnvelope`, schema v9): mirrors `wallets.balance_cutoff_at`, applied **per-category** via a new `app_categories.envelope_cutoff_at` column rather than a single global flag — resetting one category never affects another's numbers, exactly like each wallet's cutoff is independent of every other wallet's. The call sets that category's cutoff to `unix_now` inside a transaction; since it's a bare `customStatement` with no accompanying typed write in the same transaction (unlike `updateWallet`, whose cutoff write piggybacks on a preceding typed `WalletsCompanion` write), it calls `markTablesUpdated({appCategories})` explicitly so `watchEnvelopeBalances()` re-emits. Both `_buildEnvelopeBalances()` subqueries above filter on this cutoff; only the spent-side query needed a new join to reach it (the earned-side subquery already has the category row in scope). No validation guard exists for reset — unlike the 100%-sum check on setting a percent, a cutoff write can't violate any other row's invariant.

Fresh installs (`onCreate` only, never the upgrade path) seed necessities/food/hobbies/others at 50/15/20/15 (`effective_from: 0`) — the feature's own worked example. An install upgrading from an earlier schema version gains **no** seeded percentages: there is no percent that was ever "in effect" for pre-existing data, so every category reads as unbudgeted until the user explicitly configures one.

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
NotificationService.showCaptureNotification(capture, walletName)  [drain(), per new row]
  ─ system notification: "Có giao dịch +/-X vào [wallet]" (or a generic
    manual-review message for unparsed captures)
  ─ actions: "Thêm" (showsUserInterface: true) / "Bỏ qua" (showsUserInterface: false)
        │
        ├─ tap body or "Thêm" → app opens (or resumes) → onOpenCapture(captureId)
        │                        → CaptureConfirmPage(capture)
        │
        └─ "Bỏ qua" → _onResponseBackground isolate → dismissCapture(captureId)
                        directly against a throwaway AppDatabase connection,
                        without ever bringing the app UI forward
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

### Capture alert notification (ADR — background-isolate dismiss)

`CaptureService.drain()` pops a one-shot Android notification for every newly inserted capture (a `CaptureNotifier` callback, `NotificationService.instance.showCaptureNotification` by default — injectable so tests don't touch the `flutter_local_notifications` platform channel). It uses its own channel (`myfinance_capture_alert_v1`, distinct from the quiet persistent quick-add channel) with two actions:

- **Thêm** (`showsUserInterface: true`) — routed through the existing foreground `NotificationResponse` callback (same mechanism the persistent notification already uses across cold starts). `main.dart` wires `NotificationService.instance.onOpenCapture` to fetch the capture (`FinanceRepository.captureById`) and push `CaptureConfirmPage`.
- **Bỏ qua** (`showsUserInterface: false`) — never opens the app. flutter_local_notifications runs this in its own **separate Flutter engine** (see the plugin's README — Android auto-registers plugins for it, unlike iOS), so `_onResponseBackground` in `notification_service.dart` can safely instantiate a throwaway `AppDatabase()` (the database already uses `NativeDatabase.createInBackground`, so this is just another connection to the same sqlite file) and write the dismissal directly.

Because that write happens through a *different* `AppDatabase`/`QueryExecutor` instance than the live app's, Drift's reactive `watch()` streams don't see it automatically — Drift only pushes updates within the same connection, not by watching the file. Fix: `_AppLifecycleObserver.didChangeAppLifecycleState` (`main.dart`) calls `db.markTablesUpdated({db.notificationCaptures})` on every `resumed`, in addition to the existing `captureService.drain()` call, forcing any live watchers (badge, banner, `CapturesPage`) to re-query.

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

Settings keys: `ui.locale`, `currency.symbol`, `autostar.enabled`, `theme.mode`, `theme.seedColor`, `ui.scaffoldBgColor`, `ui.fontColor`, `ui.bgImagePath`, `notif.enabled`, `ui.icon.<slotId>` (one key per customizable icon slot — see below).

### Icon customization (`AppIcon`)

`lib/ui/widgets/app_icon.dart` defines `AppIcon(slotId, {required fallback, size, color})` — a `ConsumerWidget` that reads `settings.iconPath(slotId)` and renders `Image.file(...)` if a custom image is set, else the built-in `Icon(fallback)`. `color` only tints the fallback branch (a user-picked image is assumed full-color, so it's never recolored). `lib/ui/widgets/icon_slots.dart` defines the 11 customizable slot ids (`kIconSlots`), their grouping for the settings UI (`kIconSlotGroups`: nav / fab / type / star / wallet), and localized display-name/fallback-icon lookups.

Unlike `bgImagePath` (which stores whatever raw path `FilePicker` returns), icon images are **copied** into `(app documents)/customization/icons/<slotId>.<ext>` before the path is persisted — more robust against picker-granted paths becoming invalid across app restarts. `ThemeCustomizationPage`'s "Biểu tượng" section is the only place that writes `AppSettings.setIconPath`; `_resetAll()` clears every slot alongside the color/background settings.

Two slots (`wallet_cash`/`wallet_bank`) are net-new UI elements — before this, wallet type was shown as text only (`WalletKinds.label()`). `wallets_page.dart`'s wallet-card leading widget is now a `Row` of the drag handle + a `CircleAvatar(AppIcon(...))`.

### `CategorySuggester`

Heuristic pattern-matching against transaction description text. Used in `QuickAddPage` to auto-select a category when the user types a description. Falls back to empty (no suggestion) if no pattern matches.

### `NotificationService`

Flutter-side wrapper for `flutter_local_notifications`. Creates and manages a persistent quick-add notification in the status bar, with action buttons for spending/earning/transfer that deep-link into `QuickAddPage` via `openQuickAdd(txType)`. Locale-aware: `init()`/`showPersistentNotification()` take a `locale` parameter and resolve strings via the generated `lookupAppLocalizations(Locale)` (no `BuildContext` available in this singleton service). The service remembers the last-known locale internally so `_onResponse`'s re-post (needed on OEMs that dismiss `ongoing:true` notifications on tap) doesn't need settings access.

### `CsvService`

Single-file CSV export/import (`lib/services/csv_service.dart`). There is no per-section header row — every row's **first cell is a record-type discriminator** (`META`/`WALLET`/`TXN`/`CATEGORY`/`SETTING`/`KEYWORD`/`BUDGET`), so heterogeneous "tables" round-trip through one `CsvToListConverter`/`ListToCsvConverter` pass:

```
META,schema_version,exported_at
WALLET,id,name,initial_balance,type,package_name,sort_order,balance_cutoff_at
TXN,id,type,amount,description,wallet_id,wallet_to_id,wallet_from_name,wallet_to_name,category,timestamp,imported,starred,source,affects_balance
CATEGORY,id,label,kind,threshold,is_default,archived,sort_order
SETTING,key,value
KEYWORD,keyword,category,weight
BUDGET,id,category_id,percent,effective_from
```

**`exportAll({settingsEntries, keywordRules})`** — one `XFile`. Wallets/transactions/categories/the full `category_budget_history` timeline (`AppDatabase.allCategoryBudgetHistory()`) come from `AppDatabase`; `settingsEntries` (`AppSettings.exportEntries(kIconSlots)`) and `keywordRules` (`CategorySuggester.loadRaw()`) are passed in by the caller (`SettingsPage`) so `CsvService` itself only depends on `AppDatabase`. SETTING/KEYWORD rows exist for backup/documentation only — they are not re-imported (see below).

**`importAll(path)`** — reads **wallets, transactions, categories, and budget history**; META/SETTING/KEYWORD rows are parsed and ignored. Merge semantics (chosen because balance no longer depends on wallet emptiness — see `balance_cutoff_at` below):
- **Wallets/categories**: insert-if-absent. A row whose `id` already exists in the database is skipped entirely — existing live state (a wallet's `balance_cutoff_at`/`sort_order`/`package_name`, a category's `archived`/`threshold`/`sort_order`) always wins over an older export.
- **Transactions**: upsert by `id` (`insertOnConflictUpdate`), applying every column exactly as stored in the file — `source`/`affects_balance`/`starred`/`imported` all round-trip faithfully. Re-importing the same file (or an overlapping backup) is idempotent.
- **Budget history**: insert-if-absent by `id`, same as wallets/categories. Since `category_budget_history` is append-only (never updated), this makes re-importing the same file a no-op instead of duplicating history rows. A `BUDGET` row's `category_id` has no DB-level FK constraint (same as `txns.category`) — if it references a category id that isn't present (e.g. a hand-edited file, or a file whose CATEGORY rows were stripped), the row still imports but stays inert until a matching category exists.
- Returns an `ImportSummary` (`walletsAdded`, `walletsSkipped`, `txnsAdded`, `txnsUpdated`, `categoriesAdded`, `categoriesSkipped`, `budgetEntriesAdded`, `budgetEntriesSkipped`) for the settings-page result snackbar.

This replaced an earlier two-file (wallets.csv + txns.csv), two-mode (`contextOnly`/`reconstructBalance`) design. That design's `NonEmptyWalletReconstructError` guard existed to stop a "restore balance" import from double-counting into a wallet that already had transactions — a concern schema v7's `balance_cutoff_at` (per-wallet cutoff timestamp) made moot, since a wallet's balance is self-contained regardless of transaction provenance. Both are gone; there is no import mode to choose anymore.

### `PermissionCoordinator`

Routes permission requests by class:
- `POST_NOTIFICATIONS` → runtime dialog via `permission_handler`
- Notification-listener access → deep-links to system Settings screen (no dialog — special access class)

## Localization (l10n)

Flutter's `gen-l10n` toolchain generates `AppLocalizations` from `lib/l10n/app_vi.arb` (template — Vietnamese is the app's actual default locale, not the gen-l10n convention of `en`) and `lib/l10n/app_en.arb` (translation). Config is `l10n.yaml` at the repo root; generated output lands in `lib/l10n/generated/` (`synthetic-package: false`, so it's a real, committed, importable directory like `database.g.dart` — not Flutter's default invisible synthetic package). `pubspec.yaml` has `generate: true`; `make gen` runs `flutter gen-l10n` before Pigeon/Drift codegen.

- **Settings → Ngôn ngữ**: a `SegmentedButton` writing `settings.locale` (`'vi'`/`'en'`, `AppSettings`); `MyFinanceApp` already watched `settingsProvider` so the whole app rebuilds live. `AppLocalizations.localizationsDelegates`/`.supportedLocales` (generated static lists, already bundling the standard Flutter delegates) are passed straight into `MaterialApp`.
- **Call sites** use `AppLocalizations.of(context)!.someKey`. `lib/models/domain.dart`'s `TxTypes.label()`/`Categories.label()`/`WalletKinds.label()` take a resolved `AppLocalizations` (not a `BuildContext`, keeping the file widget-free) instead of the old static Vietnamese-only `labels` maps.
- **No-`BuildContext` surfaces** (`NotificationService`, a singleton) use the generated top-level `lookupAppLocalizations(Locale)` function instead.
- **`OverspendException`** was simplified to a zero-payload exception (single throw site, single catch site) — the UI catch site resolves `l10n.overspendError` itself rather than the exception carrying pre-formatted text across the repository/UI boundary.
- **Explicitly not localized**: strings baked into native Android code (`BootReceiver.kt`'s post-reboot notification, the home-screen widget's XML labels) — Flutter's l10n system can't reach them; they stay Vietnamese pending a separate Android string-resources pass. `AppCategories` DB rows (user-editable data, seeded once in Vietnamese, never auto-translated). `format.dart`'s number grouping and date order (VND/Vietnamese-style regardless of UI language — this is a VND-only, Vietnam-focused app).

## Theming ("warm & friendly" pass)

`MyFinanceApp` (`lib/main.dart`) builds `lightScheme`/`darkScheme` via `ColorScheme.fromSeed(seedColor: settings.themeSeedColor)` once, then reuses them for both `ColorScheme` and a shared `cardTheme(scheme)` helper — every `Card` in the app gets `elevation: 0`, `color: scheme.surfaceContainerHigh` (a tonal "filled" look instead of a drop shadow), and a 16px rounded `RoundedRectangleBorder`. `chipTheme` pushes `ChoiceChip`/`FilterChip` (the Giao dịch filter bar) toward a `StadiumBorder` pill shape.

**Typography**: `Nunito` (variable font, `assets/fonts/Nunito-VariableFont_wght.ttf`, registered in `pubspec.yaml`'s `fonts:`) is applied unconditionally via `textTheme: base.apply(fontFamily: 'Nunito', ...)` — fetched once from Google Fonts' GitHub repo at implementation time (a dev-time download, not a runtime app dependency; the app itself makes no network calls). Verified to include the `vietnamese` glyph subset, since this is a Vietnamese-primary app. A single variable-font file covers every `FontWeight` used in the app rather than bundling separate static weight cuts.

**Category colors**: `lib/ui/category_colors.dart` holds `spendColors`/`earnColors` (7 default category ids → color) and `spendColor()`/`earnColor()` lookup functions, promoted out of `analytics_page.dart` (which still uses them for the pie charts) so `transactions_page.dart` can share the same palette. `_TxnTile`'s `CircleAvatar` icon is colored per-category for spending/earning (transfer keeps `scheme.primary`); the amount text stays the semantic red/green/blue by transaction type, so spend-vs-earn is still a 1-glance scan even with richer per-row category info. User-created categories (UUID ids) fall back to grey.

**Icon customization** interacts with theming too — see the dedicated section above.

## Ví tab dashboard

`WalletsPage` splits into `_WalletsList` (the populated state) and `_Empty` (fade/scale-in via `TweenAnimationBuilder`), swapped with an `AnimatedSwitcher`. `_WalletsList` renders, top to bottom:
1. `HeroBalanceCard` (`lib/ui/widgets/hero_balance_card.dart`) — replaces the old plain "Tổng số dư" `Card` in place. A primary→tertiary gradient container (both colors derived from the seed, so it always harmonizes) with a `TweenAnimationBuilder<double>` count-up animation on the total.
2. `RecentActivityPreview` (`lib/ui/widgets/recent_activity_preview.dart`) — a new `ConsumerWidget` that subscribes to `repo.watchTxns()` (the same stream `TransactionsPage` uses) and takes the first 5 client-side rather than adding a dedicated bounded query. `_netChangeOf(recentTxns)` sums signed amounts across the slice (transfers contribute 0 since they net to zero across the user's own wallets). A caption reads "Qua N giao dịch gần nhất · ±X ₫" (`walletsRecentActivitySubtitle` + the formatted net change, colored green/red/primary by sign). **A sparkline chart originally sat below this caption** (an `fl_chart` `LineChart` with a dashed zero-reference line, colored by net-change sign) but was removed after on-device feedback that it didn't carry enough information to earn its space — the caption alone (which the chart was originally added to give the chart context for) turned out to be the actually-useful part, so it stayed. Below the caption: up to 5 compact `_RecentTile` rows (not a reuse of `_TxnTile` — keeps `transactions_page.dart` untouched and avoids dragging its action-sheet/edit-navigation semantics into a preview). The whole card hides (`SizedBox.shrink()`) when there are no transactions yet.
3. The existing `ReorderableListView` of wallet cards — unchanged in position and behavior.

No "see all" link from the preview to the Giao dịch tab yet — `homeTabIndexProvider` (added for the Analytics drill-down below) makes this straightforward now, but it hasn't been requested.

## Analytics drill-down

`AnalyticsPage`'s `_drillDown({required type, category})` (in `_AnalyticsPageState`) writes `txnTypeFilterProvider`, `txnCategoryFilterProvider`, resets `txnStarredOnlyProvider` to `false`, sets `monthModeProvider = true` and `selectedMonthProvider = _month` (scoping Giao dịch to the *same* month being viewed in Thống kê — required, since `_StatCard`/`_PieSection` figures are month-scoped, not all-time), then sets `homeTabIndexProvider = 1`. Wired from two places:
- `_StatCard` (Tổng chi/Tổng thu) — a new `onTap: VoidCallback?`, wrapped via `InkWell` inside the existing `Card` (radius matches `main.dart`'s global `CardThemeData`), calling `_drillDown(type: ...)` with no category.
- `_PieSection` — a new `onSliceTap: void Function(String categoryId)?`, called from both the pie chart's `touchCallback` (a `FlTapUpEvent` branch reading `PieTouchResponse.touchedSection.touchedSectionIndex`, additive to the existing highlight-on-touch logic — `isInterestedForInteractions` is `false` for taps specifically on mobile, so this branch can't reuse that guard) and each legend row (wrapped in `InkWell`). Both index into the same `entries` list that drives the pie sections, so `entries[i].key` is the tapped category id either way.

`transactions_page.dart`'s category filter coalesces a null `category` into its type's synthetic bucket (`t.category ?? (earning ? 'others_earn' : 'others')`) before comparing — mirrors the analytics SQL's own `COALESCE(category, 'others'|'others_earn')` exactly, so a drill-down into (or a manual filter by) "Khác" includes uncategorized transactions the same way the analytics total already did. `'others'`/`'others_earn'` are simultaneously the real seeded ids of the default "Khác" categories and the analytics bucket for `category IS NULL` rows (reachable via `CaptureConfirmPage`'s "— Bỏ qua —" option).

## Navigation

`HomePage` is the root scaffold. It uses a `NavigationBar` with 4 destinations. The Giao dịch tab icon shows a `Badge` when `pendingCaptureCount > 0`. The active tab index lives in `homeTabIndexProvider` (not local `State`), so other screens can switch tabs — see "Analytics drill-down" above.

Tab switching: `GestureDetector` wraps the `IndexedStack` body with `onHorizontalDragEnd`, writing `homeTabIndexProvider`. Swipe left (velocity < −300) advances one tab; swipe right (velocity > 300) goes back one tab. `HitTestBehavior.opaque` ensures the gesture captures swipes over any child widget that doesn't handle them itself.

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
