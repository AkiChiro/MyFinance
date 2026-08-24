# MyFinance — Development History

This document is for future Claude Code sessions. It summarizes every phase of work, the decisions made, bugs fixed, and the current state of the codebase as of the end of the Phase 5d session.

---

## Starting point

The app was an existing Flutter project with global top-level variables in `main.dart` (no DI), no tests, ad-hoc `setState`/`StreamBuilder` state management, and a fragile widget/notification pipeline built on third-party plugins. The core data model was a SQLite database with `Wallets` and `Txns` tables managed by Drift.

The key goal from the outset was to rebuild this into a professional-grade app with:
- Testable DI (Riverpod)
- SQL-computed balance and analytics
- A native Android notification listener to capture bank transactions
- A confirm-before-filing UX so parser bugs cannot corrupt the ledger

---

## Phase 1 — Foundation

**Work done:**
- Introduced Riverpod (providers in `lib/providers.dart`, all overridden in `main()`)
- Removed global top-level variables from `main.dart`
- Wrapped multi-step writes (`addSpending`, `addTransfer`, `updateTxn`) in `db.transaction()` to close a race window
- Replaced empty `catch (_) {}` in the home widget handler with `debugPrint` logging
- Added `lib/models/domain.dart` (`TxTypes`, `Categories`, `WalletKinds`)
- Made DB the single source of truth for category labels/thresholds (removed duplicate static map)
- Wrote the first test suite

**Key files changed:** `lib/main.dart`, `lib/providers.dart`, `lib/models/domain.dart`, `lib/repositories/finance_repository.dart`

---

## Phase 2 — Categories, starred transactions, CSV

**Work done:**
- Added `AppCategories` table (schema v2 migration: add `starred`, `walletFromName`, `walletToName` columns to txns, create `app_categories`)
- Default categories seeded on first run: Thiết yếu, Ăn uống, Sở thích, Khác (spending); Chu cấp, Tự kiếm, Khác (earning)
- Category CRUD: add, archive (soft-delete), threshold editing
- Auto-star: `isAutoStarred(txn, thresholds, enabled)` pure function — spending above a per-category VND threshold shows a star
- Manual star: `toggleStar(txn)`, `setStarred(id, starred:)`
- CSV export (two files: transactions + wallets via share_plus)
- CSV import with two modes: contextOnly (no balance effect) and reconstructBalance

---

## Phase 3 — `source` / `affectsBalance` split

**Work done:**
- Added `source` (`textEnum<SourceType>`) and `affectsBalance` columns to `txns` (schema v3 migration)
- `SourceType`: `manual`, `csvImport`, `bankNotification`
- Migration backfill: `imported=true` → `source=csvImport, affects_balance=0`
- `addSpending`/`addEarning`/`addTransfer` now set `source=manual, affectsBalance=true`
- CSV import sets `source=csvImport`, `affectsBalance=(mode==reconstructBalance)`
- Balance SQL updated to use `WHERE affects_balance=1`

**Key decision (ADR-0009 resolution):** The old single `imported` boolean conflated "came from CSV" with "excluded from balance". Separating into `source` + `affectsBalance` allows bank-notification transactions to be bank-sourced but still affect balance.

---

## Phase 4 — SQL balance and analytics

**Work done:**
- Replaced Dart-side `balanceOf` loop with SQL UNION ALL queries in `AppDatabase`
- `watchWalletBalances()`: reactive stream of `{walletId → balance}` using `_kAllBalancesSql`
- `sqlBalance(walletId, {excludeId})`: one-shot single-wallet balance used for overspend checks; `excludeId` excludes the transaction being edited
- `watchAnalyticsBundle(month)`: reactive stream of `AnalyticsBundle` built from two SQL queries
- Schema v4 migration: added 4 partial indexes (`WHERE affects_balance=1`) on `wallet_id`, `wallet_to_id`, `timestamp`, `(type, timestamp)` to keep SQL aggregates fast as transaction count grows

---

## Phase 5a — Schema + wallet↔bank association

**Work done:**
- Added `packageName` column to `Wallets` (schema v5 migration)
- Added `NotificationCaptures` table (see Architecture doc for full schema)
- Partial unique index on `wallets(package_name) WHERE package_name IS NOT NULL` — allows multiple `NULL` wallets but enforces uniqueness among non-null values
- Added to `FinanceRepository`:
  - `insertCapture(...)` — dedup + wallet resolution + insert
  - `updateWalletPackageName(id, pkg)`
  - `walletByPackageName(pkg)`
  - `pendingCaptureCount()` — stream of pending count for badge/banner
  - `watchPendingCaptures()` — stream of pending captures for inbox
- Added `dismissCapture(id)` and `confirmCapture(...)` stubs (implemented fully in Phase 5c/5d)

**Key files:** `lib/data/database.dart`, `lib/repositories/finance_repository.dart`, `lib/models/domain.dart`

---

## Phase 5b — Bank notification parsers

**Work done:**
- `lib/services/bank/bank_notification_parser.dart`:
  - `BankPackages` constants: `ocb`, `mb`, `techcombank` (verified on-device in Phase 5 testing — see below)
  - `BankParserRegistry`: map of `packageName → BankNotificationParser`
  - `BankNotificationParser` abstract interface with `parse(RawNotification)` method
- `lib/services/bank/parsed_notification.dart`: `RawNotification`, `ParsedNotification` value types
- Per-bank parser files: `ocb_parser.dart`, `mb_parser.dart`, `techcombank_parser.dart`
- `ParseStatus` enum: `parsed` (clean), `needsReview` (low-confidence), `unparsed` (parser returned null but text is money-shaped)

**Verified package names (from on-device testing):**
- OCB: `vn.com.ocb.awe` (initial guess `com.ocb.app` was wrong)
- MB: `com.mbmobile` (correct from the start)
- Techcombank: `vn.com.techcombank.bb.app` (initial guess `com.techcombank.mb` was wrong)

---

## Phase 5c — Native notification listener

**Work done (Kotlin):**
- `BankCaptureService.kt`: `NotificationListenerService` that buffers captured notifications to SharedPreferences as JSON
- `CaptureChannelApi.kt`: Pigeon `@HostApi` implementation
- Pigeon channel methods: `setWatchedPackages`, `drainCaptures`, `clearCaptures`, `seenPackages`
- `android_overlay/` directory for source-controlled Kotlin files; `patch_android.py` copies them into `android/` during `make init`

**Work done (Dart):**
- `lib/services/capture_service.dart`: `CaptureService.drain()` — the Dart side of the pipeline (parse + file + clear)
- `lib/services/capture_channel.dart`: `LiveCaptureChannelApi` (real Pigeon calls) and the abstract `CaptureChannelApi` interface
- `lib/services/permission_coordinator.dart`: routes notification-listener permission to system settings deep-link
- Settings page "Nhà phát triển" section: "Cấp quyền nghe thông báo" button, "Gói ứng dụng đã thấy" debug dialog

---

## Phase 5d — In-app review UX

**Work done:**

### New files
- `lib/ui/captures_page.dart` — `CapturesPage` (inbox)
  - Nested StreamBuilders: outer = `watchWallets()`, inner = `watchPendingCaptures()`
  - `_CaptureTile` with 3 visual states (parsed / needsReview / unparsed)
  - `_bankLabels` map — **initially used hardcoded string literals** (bug), **fixed** to use `BankPackages.*` constants
- `lib/ui/capture_confirm_page.dart` — `CaptureConfirmPage`
  - `ConsumerStatefulWidget`, `initState` pre-fills from capture fields
  - Direction segmented button, amount text field, wallet dropdown (required), category dropdown (optional), date/time picker, starred switch
  - Unparsed: raw text shown at top in error-colour card; blank amount
  - Parsed/needsReview: raw text at bottom as reference card
  - `_confirm()`: validates, calls `repo.confirmCapture(timestamp: _timestamp)`
  - `_dismiss()`: AlertDialog → `repo.dismissCapture()`
- `test/capture_confirm_test.dart` — 15 unit tests (Drift in-memory DB)

### Updated files
- `lib/ui/transactions_page.dart` — added captures banner between filter bar and list
- `lib/ui/wallets_page.dart` — added bank-link picker to add/edit dialogs; long-press action sheet with "Sửa liên kết ngân hàng"
- `lib/ui/home_page.dart` — changed to `ConsumerStatefulWidget`, added nav-bar badge on Giao dịch tab
- `lib/repositories/finance_repository.dart`:
  - `addWallet` now returns `Future<String>` (wallet ID) instead of `Future<void>`
  - `reassignWalletBankLink(pkg, newWalletId)` — atomic `db.transaction` that clears pkg from old wallet and sets it on new wallet
  - `confirmCapture` — full implementation with `capturedAt` timestamp resolution inside the transaction

### Bug fixed in this session
The `_bankLabels` map in `captures_page.dart` was initially written with hardcoded string literals (`'com.ocb.app'`, `'com.techcombank.mb'`). After the user updated `BankPackages` constants to the real device values (`'vn.com.ocb.awe'`, `'vn.com.techcombank.bb.app'`), the inbox showed raw package names instead of "OCB" / "Techcombank". Fixed by changing the map keys to `BankPackages.ocb` / `BankPackages.mb` / `BankPackages.techcombank`.

---

## ADRs beyond the ADR.md file

The following ADRs were decided during implementation but were not written into the formal ADR file (`docs/MyFinance_ADR.md`):

**ADR-0013 — Money-shaped null-parse → file as `unparsed`, not discard**
If a bank notification arrives, the parser returns null (text doesn't match any pattern), but the text contains a money-shaped string (digits adjacent to VND/đ/₫), file it as `ParseStatus.unparsed`. This prevents silent loss of bank transactions when the parser has a gap. The user will see it in the inbox with a red ⚠ tile and can enter the amount manually.

**ADR-0014 — Wallet↔bank association via `Wallets.packageName`**
A wallet can be associated with a bank app's package name. When a notification arrives from that package, the capture's `suggestedWalletId` is pre-filled with that wallet's ID. The partial unique index enforces at most one wallet per bank.

**ADR-0017 — Deferred capture model (file-then-clear)**
`CaptureService.drain()` inserts all captures into Drift before calling `clearCaptures()` on the native buffer. Crash between these two steps causes a re-drain on next launch; `insertCapture`'s 2-minute dedup window makes re-draining idempotent.

**ADR-0018 — "Bỏ qua" capture-alert action dismisses via a background-isolate `AppDatabase`, not by opening the app**
The alternative (briefly open the app, run the dismiss, show nothing) is simpler and was offered to the user as the recommended default, but the user explicitly chose the silent background path. flutter_local_notifications runs a `showsUserInterface: false` action's callback in its own separate Flutter engine, which Android already plugin-registers, so a throwaway `AppDatabase()` opened there works — the existing `NativeDatabase.createInBackground` means this is just another connection to the same sqlite file. The tradeoff: writes made this way are invisible to the live app's Drift reactive streams until something calls `markTablesUpdated` on the live connection, which is why `_AppLifecycleObserver` now does that on every resume regardless of whether `drain()` found anything.

**ADR-0019 — Single CSV file, record-type-discriminator rows, instead of per-entity files/headers**
Once export needed to cover wallets + transactions + categories + settings + keyword rules (all different column shapes) in one file, a per-section-header format (like a multi-sheet spreadsheet) would need custom line-splitting to parse. Prefixing every row with a type tag (`WALLET,...` / `TXN,...` / ...) instead lets the whole file go through one `CsvToListConverter`/`ListToCsvConverter` pass — rows are just grouped by `row[0]` after parsing. Chosen over keeping multiple files (harder to share as one backup) or switching export to JSON (user asked for CSV specifically).

**ADR-0020 — Envelope budgeting: recompute-on-read from an append-only percent-history table, not a stored/mutated ledger**
The alternative (a snapshot table writing an allocation row per earning, reversed on edit/delete) would need all five transaction-mutation call sites touched (`addSpending`/`addEarning`/`updateTxn`/`deleteTxn`/`confirmCapture`, plus a new `db.transaction()` wrapper on `addEarning`, which doesn't have one today) and directly fights ADR-0004's "never store a mutable balance — risks drifting out of sync" reasoning, just applied to a category-tagged sub-balance of income instead of a wallet balance. Recompute-on-read gets three product requirements essentially for free: a percent change is just a new `category_budget_history` row, read via an "as-of" join against each earning's own timestamp, so it's never retroactive; there's no write path to hang an overspend guard on, so overspending an envelope can only ever be informational; and an earning older than any configured percent naturally contributes $0, so no backfill migration is needed when a percent is first set post-upgrade.

---

## Device testing results (Phase 5, V0.2-Improve branch)

Tested on Vivo X200 Pro (OriginOS / Android 15).

- All 4 tabs load correctly.
- Notification-listener permission requires first removing OEM background restrictions in App Manager, then enabling via the in-app button.
- BankPackages constants updated after on-device discovery: OCB → `vn.com.ocb.awe`, Techcombank → `vn.com.techcombank.bb.app`.
- Bank transactions (OCB, MB, Techcombank) captured and parsed correctly as `parsed` tiles.
- Wallet bank-link add/edit/uniqueness/reassign all work correctly.
- Capture drain on resume works; intermittent behavior noted (possibly OEM background kill — not a code bug).
- Confirm flow: timestamp correctly uses `capturedAt`, not review time. ✅
- Dismiss flow works correctly.
- Section 8 (unparsed capture confirm) deferred — not yet tested on device.

---

## Build notes

`make apk` runs: `gen` (build_runner) → `flutter build apk --release`.

The `.dart_tool/build/entrypoint/build.dart` file is generated by `build_runner`. If this file was generated by a newer version than the one in `pubspec.yaml`, `make apk` will fail with exit 78. The fix is to delete `.dart_tool/build/` and re-run `make init`. This happened during the Phase 5d session and was resolved by the user directly in the Makefile.

---

## Current branch state (as of end of Phase 5d)

Branch: `V0.2-Improve`

All Phase 5d work is committed. The `_bankLabels` bug fix was committed in this final session. The branch is ready to merge to `main` pending the unparsed-capture test (Section 8 of the checklist).

---

## Session 6 — Issues #4, #5, #6 (UI improvements)

Branch: `V0.2-Improve` (continued)

**Work done:**

### Schema v6 — Wallet sort order (Issue #4)

- Added `sort_order INTEGER NOT NULL DEFAULT 0` to `Wallets` table in `database.dart`.
- Schema v6 migration in `onUpgrade`:
  - `ALTER TABLE wallets ADD COLUMN sort_order INTEGER NOT NULL DEFAULT 0` (raw SQL — avoids Drift column accessor before build_runner regenerates)
  - Seed: `UPDATE wallets SET sort_order = (SELECT COUNT(*) FROM wallets w2 WHERE w2.name < wallets.name)` — preserves old alphabetical order as starting drag positions.
- `watchWallets()`: uses `customSelect('SELECT * FROM wallets ORDER BY sort_order, name', readsFrom: {wallets}).watch().map((rows) => rows.map((r) => wallets.map(r.data)).toList())`. Raw SQL for ORDER BY; `$WalletsTable.map(r.data)` for typed `Wallet` construction (works before and after build_runner regeneration).
- `updateWalletsOrder(List<String> orderedIds)`: uses `customStatement('UPDATE wallets SET sort_order = ? WHERE id = ?', [i, id])` in a transaction.

**Pre-regeneration compile strategy:** Drift column accessors (`wallets.sortOrder`, `WalletsCompanion(sortOrder:)`) don't exist until build_runner regenerates `database.g.dart`. Raw SQL is used throughout the v6 additions to avoid this dependency. After `make apk` (which runs `make gen`), typed accessors could replace the raw SQL but aren't required to.

### Issue #4 — Ví tab: tap-to-edit + drag-to-reorder

**`lib/ui/wallet_edit_page.dart`** (new file):
- Full `ConsumerStatefulWidget` page with fields: name, initial balance, type (SegmentedButton), bank link (dropdown from `kBankPickerOptions`).
- Delete button in AppBar (error colour). Confirm dialog before deleting.
- On save: checks bank-link uniqueness if link changed; handles conflict via reassign dialog (same flow as add dialog).
- Uses `repo.updateWallet(id, name, initialBalance, type, packageName)` for all field updates.

**`lib/ui/wallets_page.dart`** (updated):
- `ListView` → `ReorderableListView.builder` with `buildDefaultDragHandles: false`.
- `ReorderableDragStartListener` on leading `Icon(Icons.drag_handle)` — only the handle starts a drag.
- `onTap` → push `WalletEditPage`.
- `onReorder` → `repo.updateWalletsOrder(reorderedIds)`.
- Removed `_walletActionSheet`, `_editBankLinkDialog`, `_confirmDelete` — all replaced by `WalletEditPage`.
- Private `_kBankOptions`/`_bankLabel` removed — replaced by `kBankPickerOptions`/`bankLabel` from `bank_notification_parser.dart`.

**`lib/repositories/finance_repository.dart`** (updated):
- `addWallet`: raw SQL insert with `sort_order = (SELECT COUNT(*) FROM wallets)`.
- `updateWallet(id, name, initialBalance, type, packageName)`: new method using `WalletsCompanion` (only updates non-order fields).
- `updateWalletsOrder(List<String> ids)`: delegation to `db.updateWalletsOrder`.

### Issue #5 — Giao dịch tab: filters + star toggle in QuickAdd

**`lib/ui/transactions_page.dart`** (updated):
- Removed `Dismissible` wrapper — delete is now action-sheet only (prevents accidental delete on swipe).
- Moved `StreamBuilder<List<AppCategory>>` to outermost position (outside `Column`) so category data is available to both the filter bar and the tile label map.
- Added state: `_typeFilter`, `_categoryFilter`, `_sortByAmount`.
- Added `_buildFilterBar`: `SingleChildScrollView` with `Row` of chips (Tất cả / Chi tiêu / Thu nhập / Có sao / Danh mục (conditional) / Số tiền sort).
- `_pickCategory`: `showDialog<List<String?>>` with `SimpleDialog`; wrapper list distinguishes dismissed (null) from "all" ([null]) from specific category ([id]).
- Filters applied client-side after `watchTxns()` emits.
- `_showActionSheet` now takes `showStar: bool` parameter (= `txn.starred || autoStar`) so icon and label reflect the combined star state, not just the manual flag.

**`lib/ui/quick_add_page.dart`** (updated):
- Added `bool _starred = false` state, initialised from `e.starred` when editing.
- `SwitchListTile` with star icon after the date card (hidden for transfers).
- `addSpending` and `addEarning` calls pass `starred: _starred`.
- `copyWith` on edit passes `starred: _starred`.
- `addSpending`/`addEarning` in repository now accept `starred: bool = false`.

### Issue #6 — Thống kê tab: VND amounts + spacing

**`lib/ui/analytics_page.dart`** (updated):
- Right-side legend in `_PieSection` now shows `formatVnd(e.value)` instead of `'${pct.toStringAsFixed(1)}%'`.
- Legend row padding increased from `vertical: 3` to `vertical: 6`.
- Pie sector labels inside the chart still show percentages.

### Swipe between tabs

**`lib/ui/home_page.dart`** (updated):
- `IndexedStack` wrapped in `GestureDetector` with `onHorizontalDragEnd`.
- `v < -300 → _index++` (swipe left = next tab); `v > 300 → _index--` (swipe right = previous tab).
- `HitTestBehavior.opaque` captures swipes over any non-interactive child.

### Key files changed in this session

| File | Change |
|------|--------|
| `lib/data/database.dart` | Schema v6: sort_order, migration, watchWallets, updateWalletsOrder |
| `lib/repositories/finance_repository.dart` | addWallet (sort order), updateWallet, updateWalletsOrder, starred on addSpending/addEarning |
| `lib/ui/wallet_edit_page.dart` | **new** — full wallet edit screen |
| `lib/ui/wallets_page.dart` | ReorderableListView, tap-to-edit, remove action sheet |
| `lib/ui/quick_add_page.dart` | starred toggle SwitchListTile |
| `lib/ui/transactions_page.dart` | remove Dismissible, add filters, fix star in action sheet |
| `lib/ui/analytics_page.dart` | VND in legend, more row spacing |
| `lib/ui/home_page.dart` | swipe gesture for tab switching |

**Build note:** `make apk` must be run to regenerate `database.g.dart` with `sortOrder` before the typed Drift accessors are usable. Until then, raw SQL bridges the gap.

---

## Session 7 — Real-world usage improvements (Branch: V0.2-Improve)

After 3+ weeks of daily use, several improvements were identified and implemented.

### 1. Ví tab — Wallet balance reset on `initialBalance` change (Option C — per-wallet cutoff)

**Problem:** Changing `initialBalance` in `WalletEditPage` would immediately shift the displayed balance, but all old transactions still accumulated on top of the new initial value, giving a confusing result. A naive fix using `affects_balance=0` would contaminate transfer counterparties — resetting wallet A would remove the transfer from wallet B's balance too.

**Solution (schema v7):** Added `balance_cutoff_at INTEGER?` column to the `wallets` table. When the user saves a new `initialBalance`, the repository sets `balance_cutoff_at = unix_now` on that wallet only. Balance SQL applies `AND timestamp >= COALESCE(balance_cutoff_at, 0)` per-wallet via a JOIN, so each wallet has its own view of history. Resetting wallet A does not affect wallet B's balance.

**Files changed:**
- `lib/data/database.dart`: schema v7 migration (`ALTER TABLE wallets ADD COLUMN balance_cutoff_at INTEGER NULL`); `Wallets` table class gained `balanceCutoffAt` column; `_kAllBalancesSql` updated to JOIN wallets and apply per-wallet cutoff; `_kSingleBalanceSql` updated (9 params); `_kSingleBalanceExcludeSql` updated (13 params); `sqlBalance()` fetches cutoff via `customSelect` before running balance SQL; added `txnById(String id)` helper.
- `lib/repositories/finance_repository.dart`: `updateWallet` — on `resetTransactions: true`, now runs `UPDATE wallets SET balance_cutoff_at = ? WHERE id = ?` instead of the old `UPDATE txns SET affects_balance = 0`.
- `lib/ui/wallet_edit_page.dart`: computes `balanceChanged = newBalance != widget.wallet.initialBalance`; passes `resetTransactions: balanceChanged` to both `updateWallet` call sites. Helper text warns user.

### 2. Giao dịch tab — Month mode + pagination (AppBar nav)

**Problem:** The transaction list had no way to view just one month's worth of data.

**Solution:** Month state is stored in two Riverpod `StateProvider`s (`monthModeProvider`, `selectedMonthProvider`) so `TransactionsPage` can toggle mode and `HomePage` can show navigation in the AppBar without an extra row in the content area.

- The first chip in the filter bar ("Tất cả"/"Tháng") has dual behaviour: if not selected → clears `_typeFilter`; if already selected → toggles `monthModeProvider`. Label changes to "Tháng" when month mode is active.
- `HomePage.build()` reads both providers. When `_index == 1 && monthMode`, three actions appear in the AppBar: `←` | `Tháng X/YYYY` | `→`. The arrows write to `selectedMonthProvider` (Flutter's `DateTime` normalises year boundaries automatically).
- Month filtering reads `selectedMonthProvider` client-side before other filters.

The old `_buildMonthHeader()` Switch row was removed entirely.

**Files changed:**
- `lib/providers.dart`: added `monthModeProvider` and `selectedMonthProvider`.
- `lib/ui/home_page.dart`: AppBar reads providers; shows month nav actions when on Giao dịch tab in month mode.
- `lib/ui/transactions_page.dart`: removed `_monthMode`, `_selectedMonth`, `initState`, `_buildMonthHeader()`; first chip writes to `monthModeProvider`; filter block reads from providers.

### 3. Giao dịch tab — Bidirectional amount sort

**Problem:** The "Số tiền" filter chip could only sort highest→lowest.

**Solution:** Replaced `bool _sortByAmount` with `String? _sortDirection` (`null` / `'asc'` / `'desc'`). Tapping the chip cycles through all three states. The chip label updates to "Số tiền ↑" (asc) or "Số tiền ↓" (desc) when active.

**Files changed:**
- `lib/ui/transactions_page.dart`: `_sortByAmount` → `_sortDirection`; chip label and sort logic updated.

### 4. Star unification

**Problem:** Two overlapping star concepts: an `isAutoStarred()` pure function checked at render time (showed outlined star) and a manual `starred` DB flag (showed filled star). UX confusion — filter and tile icon disagreed in auto-star cases.

**Solution:** Merged into a single unified `starred` column. Auto-star is **written once at creation or on amount change**, not computed at render time.

- **At creation** (`addSpending` / `addEarning`): if `autostarEnabled` (from Settings) and `amount > threshold[category]`, insert writes `starred = true`. User's manual toggle is OR'd with the auto-star check.
- **On edit** (`updateTxn`): if amount changed, threshold is re-checked; if exceeded, `starred = true` is forced. Amount unchanged → keeps whatever user set.
- **Manual unstar**: user can always long-press → "Bỏ đánh dấu sao". No auto-clear.
- **Render**: `_TxnTile` shows `Icons.star` (filled) when `txn.starred == true`; no outlined variant.
- `isAutoStarred()` is retained in `finance_repository.dart` but no longer called in the UI.

**Files changed:**
- `lib/data/database.dart`: added `txnById()`.
- `lib/repositories/finance_repository.dart`: added `_shouldAutoStar()` private helper; `addSpending`, `addEarning`, `updateTxn` accept `autostarEnabled`.
- `lib/ui/quick_add_page.dart`: reads `settings.autostarEnabled` in `_save()`, passes to repo methods.
- `lib/ui/transactions_page.dart`: removed `FutureBuilder<Map<String,int>>` for thresholds; `_starredOnly` filter uses `t.starred` only.

### 5. Bug fix — Drag reorder reverts

**Problem:** After dragging a wallet card to a new position, the UI reverted to the original order. `customStatement('UPDATE wallets SET sort_order...')` is opaque to Drift's change tracker, so `watchWallets()` (backed by `customSelect().watch()`) never re-emitted.

**Fix:** `updateWalletsOrder` now calls `markTablesUpdated({wallets})` inside the transaction after all `customStatement` updates. Same fix applied to `addWallet` (which also used `customStatement` for INSERT). This forces Drift's stream to re-emit with the new sort order.

### 6. Thống kê — Remove `affects_balance` from analytics

**Problem:** After a balance reset, old transactions had `affects_balance=0` (under the old approach), which silently excluded them from analytics totals too — not the intended behaviour.

**Solution:** Removed `affects_balance=1 AND` from all three analytics SQL queries in `_buildAnalyticsBundle`. Analytics now counts all non-transfer transactions regardless of `affects_balance`. A balance reset no longer removes old spending/earning from totals.

**Files changed:**
- `lib/data/database.dart`: `_buildAnalyticsBundle` — three `WHERE` clauses updated.

### Key files changed in this session

| File | Change |
|------|--------|
| `lib/data/database.dart` | Schema v7: `balance_cutoff_at` column + migration; updated balance SQL constants; remove `affects_balance` from analytics; `txnById()` helper; `markTablesUpdated` in `updateWalletsOrder` + `addWallet` |
| `lib/repositories/finance_repository.dart` | `updateWallet`: `balance_cutoff_at` instead of `affects_balance=0`; `_shouldAutoStar`; auto-star on `addSpending`/`addEarning`/`updateTxn` |
| `lib/ui/wallet_edit_page.dart` | Balance reset detection, `resetTransactions` flag, helperText |
| `lib/ui/quick_add_page.dart` | Pass `autostarEnabled` to repo methods |
| `lib/providers.dart` | Added `monthModeProvider`, `selectedMonthProvider` |
| `lib/ui/home_page.dart` | AppBar month nav actions (reads providers) |
| `lib/ui/transactions_page.dart` | Remove Switch row; first chip toggles month mode via provider; bidirectional sort; unified star; removed thresholds FutureBuilder |

---

## Session 8 — Localization, icon customization, warm redesign (Branch: V0.2-Improve)

Three bundled features, planned together and landed as one session: (1) real vi/en localization — `settings.locale` existed but did nothing before this; (2) a custom icon-slot system (spec'd in `docs/MyFinance_Improvements_Spec.md` §10b, never built); (3) a "warm & friendly" visual redesign pass. Native Android strings (`BootReceiver.kt`, the home-screen widget XML) were explicitly deferred — out of Flutter's l10n reach, left Vietnamese for now.

### 1. Real localization (vi/en)

**Problem:** `MyFinanceApp` passed `locale: Locale(settings.locale)` into `MaterialApp` but only wired the 3 standard Flutter delegates — no `AppLocalizations` existed, so every string in the app was a hardcoded Vietnamese literal regardless of the setting.

**Solution:** Wired Flutter's `gen-l10n` toolchain end to end.
- New `l10n.yaml` (`template-arb-file: app_vi.arb` — vi is the app's actual default, not the gen-l10n convention of en; `synthetic-package: false` so generated output is a real, committed, importable directory at `lib/l10n/generated/`, matching how `database.g.dart` is already treated).
- New `lib/l10n/app_vi.arb` / `app_en.arb` — ~150 keys covering every screen, `finance_repository.dart`'s `OverspendException`, and `notification_service.dart`'s persistent-notification text. `common*`-prefixed keys dedupe strings byte-identical across ≥2 files (Huỷ/Lưu/Xoá/Sửa/Đóng/Thêm, the 3×-duplicated "Có lỗi xảy ra: $e"). Parameterized strings (month/year, CSV merge counts, bank-conflict wallet names, the pending-capture count) use ICU placeholders; the capture-count banner uses a full `plural` block.
- `lib/models/domain.dart`: `TxTypes.labels`/`Categories.labels`/`WalletKinds.labels` (static Vietnamese-only maps) replaced with `label(AppLocalizations l10n, ...)` functions — takes a resolved `AppLocalizations`, not a `BuildContext`, so the file stays free of Flutter widget imports. `Categories.forType()`/`fallbackFor()` (id lists, not display text) untouched. `AppCategories` DB rows are user-editable data seeded once in Vietnamese — never auto-translated, regardless of locale at seed time.
- `finance_repository.dart`'s `OverspendException` simplified to a zero-payload exception (confirmed single throw site, single catch site) — the UI catch site in `quick_add_page.dart` resolves `l10n.overspendError` itself instead of the exception carrying pre-formatted text across the repository/UI boundary.
- `notification_service.dart` has no `BuildContext` (singleton, sometimes called before any widget tree exists) — uses generated `lookupAppLocalizations(Locale)` instead, remembering the last-known locale internally so `_onResponse`'s re-post (needed on OEMs that dismiss `ongoing:true` notifications on tap) doesn't need settings access.
- Every hardcoded literal across all 11 `lib/ui/*.dart` files replaced with `AppLocalizations.of(context)!.<key>`.
- New Settings section "Ngôn ngữ" (`SegmentedButton`, Tiếng Việt/English — hardcoded endonyms, never translated) writing `settings.locale`; also refreshes the persistent notification's text immediately if one is showing.
- `main.dart` simplified to use the generated `AppLocalizations.localizationsDelegates`/`.supportedLocales` static lists instead of a manually maintained delegate array.

**Explicitly out of scope:** native Android strings (`BootReceiver.kt`, widget XML — deferred, needs Android string resources), bank proper nouns (OCB/MB/Techcombank), CSV column headers, `format.dart`'s number grouping/date order (stays Vietnamese-style regardless of UI language — this is a VND-only, Vietnam-focused app).

### 2. Icon customization system

**Problem:** The only real personalization lever was the theme seed color; a historical spec (§10b) for user-replaceable icons was never implemented.

**Solution:**
- `AppSettings` gained `iconPath(slotId)`/`setIconPath(slotId, path)` — dot-keyed `ui.icon.<slotId>` prefs, following the file's existing one-getter-setter-pair-per-setting idiom.
- New `lib/ui/widgets/app_icon.dart`: `AppIcon(slotId, {required fallback, size, color})`, a `ConsumerWidget` rendering `Image.file` if a custom path is set, else the built-in `Icon(fallback)`. `color` only tints the fallback branch (a picked image is assumed full-color already).
- New `lib/ui/widgets/icon_slots.dart`: `kIconSlots` (11 ids), `kIconSlotGroups` (nav/fab/type/star/wallet, for the settings UI), localized display names and fallback-icon lookups.
- Unlike the existing `bgImagePath` setting (stores whatever raw path `FilePicker` returns), icon images are **copied** into `(app documents)/customization/icons/<slotId>.<ext>` before the path is persisted — more robust against picker-granted paths going stale across restarts. `bgImagePath` itself was left untouched (out of scope for this pass).
- Two slots (`wallet_cash`/`wallet_bank`) are net-new: wallet type used to be text-only. `wallets_page.dart`'s wallet-card leading widget is now a `Row` of the drag handle + `CircleAvatar(AppIcon(...))`.
- `analytics_page.dart`'s `_StatCard.icon` field changed from `IconData` to `Widget` so it can host an `AppIcon`; callers now also pass `color:` explicitly since the card no longer applies it itself.
- `ThemeCustomizationPage` gained a "Biểu tượng" section: 5 grouped sub-`Card`s, each row = thumbnail + name + conditional reset button + chevron → file picker → copy → `setIconPath`. `_resetAll()` now also clears every icon slot.

### 3. "Warm & friendly" visual redesign

**Component styling:** `main.dart` builds `lightScheme`/`darkScheme` once and reuses them for a shared `cardTheme()` helper — every `Card` gets `elevation: 0`, `color: scheme.surfaceContainerHigh` (tonal fill instead of a drop shadow), 16px rounded corners; `chipTheme` pushes filter-bar chips toward a `StadiumBorder` pill shape.

**Category colors in the transaction list:** `_spendColors`/`_earnColors`/`_spendColor()`/`_earnColor()` promoted from `analytics_page.dart` into new `lib/ui/category_colors.dart` (public names: `spendColors`/`earnColors`/`spendColor()`/`earnColor()`). `_TxnTile`'s `CircleAvatar` icon now colors by category for spending/earning; the amount text keeps the semantic red/green/blue by type — confirmed with the user via a side-by-side preview that this hybrid (icon=category, amount=type) was preferred over both "flat type-color only" and "full category-color" alternatives.

**Typography:** Nunito (variable font, verified to include the `vietnamese` glyph subset) fetched once from Google Fonts' GitHub repo into `assets/fonts/` (a dev-time download; the app itself makes no runtime network calls) and registered in `pubspec.yaml`. `main.dart`'s `withFontColor()` helper (previously returned `null`/untouched-default-font whenever no custom font *color* was set) was replaced with `withFont()`, which applies `fontFamily: 'Nunito'` unconditionally — the old early-return would have silently kept the system font whenever the user hadn't picked a custom color.

**Empty states & motion:** `transactions_page.dart`'s 3 text-only empty variants brought to icon+text parity with `wallets_page.dart`'s `_Empty`. Both tabs now cross-fade between list and empty states via `AnimatedSwitcher` (200ms, distinct `ValueKey`s per branch). `wallets_page.dart`'s `_Empty` also gets a fade/scale-in (`TweenAnimationBuilder`) and friendlier copy. `HomePage`'s `IndexedStack` tab switching was deliberately **not** touched — animating it would break the state/scroll preservation `IndexedStack` exists for.

**Ví tab dashboard:** `WalletsPage` split into `_WalletsList`/`_Empty`, swapped via `AnimatedSwitcher`. New `lib/ui/widgets/hero_balance_card.dart` (`HeroBalanceCard`) replaces the old plain "Tổng số dư" card in place — a primary→tertiary gradient (both derived from the seed color) with a count-up animation. New `lib/ui/widgets/recent_activity_preview.dart` (`RecentActivityPreview`) sits between the hero card and the existing (untouched) wallet list: a trend sparkline (`fl_chart`, cumulative signed-amount running total over the last 5 transactions, oldest→newest; transfers contribute 0 since they net to zero across the user's own wallets) plus up to 5 compact rows. Sources from the same `repo.watchTxns()` stream `TransactionsPage` already uses, sliced client-side with `.take(5)` rather than adding a new bounded repo query. No "see all" link to the Giao dịch tab in this pass (would need a new cross-tab provider).

### Verification

`flutter analyze` and `flutter test` both run clean relative to baseline — the only remaining issues are 2 pre-existing `info`-level lints in `quick_add_page.dart` (unrelated control flow, not introduced this session) and 3 pre-existing test failures traced to the **uncommitted** Session 7 `sortOrder`/`affects_balance` work already in the tree before this session started (`test/balance_test.dart` and `test/auto_star_test.dart` fail to load — missing `sortOrder` argument; `test/sql_analytics_test.dart` has one stale assertion against the old `affects_balance`-gated analytics behavior Session 7 intentionally removed) — confirmed via `git diff` that none of those files were touched this session.

### Key files changed in this session

| File | Change |
|------|--------|
| `l10n.yaml`, `lib/l10n/app_vi.arb`, `lib/l10n/app_en.arb` | **new** — l10n config + ~150-key template/translation |
| `lib/models/domain.dart` | `TxTypes`/`Categories`/`WalletKinds` `.label()` now take `AppLocalizations` |
| `lib/repositories/finance_repository.dart` | `OverspendException` simplified to zero-payload |
| `lib/services/notification_service.dart` | Locale-aware via `lookupAppLocalizations`; remembers last-known locale |
| `lib/services/app_settings.dart` | `iconPath()`/`setIconPath()` |
| `lib/ui/widgets/app_icon.dart`, `lib/ui/widgets/icon_slots.dart` | **new** — icon-slot widget + registry |
| `lib/ui/widgets/hero_balance_card.dart`, `lib/ui/widgets/recent_activity_preview.dart` | **new** — Ví tab dashboard |
| `lib/ui/category_colors.dart` | **new** — promoted from `analytics_page.dart`, now shared with `transactions_page.dart` |
| `lib/main.dart` | l10n delegate wiring; `cardTheme`/`chipTheme`; Nunito `textTheme` wiring; locale passed to `NotificationService.init` |
| `assets/fonts/Nunito-VariableFont_wght.ttf`, `OFL.txt`; `pubspec.yaml` | **new** — bundled font asset + `fonts:` registration |
| All 11 `lib/ui/*.dart` screens | Literal string extraction; icon-slot call-site swaps where applicable |
| `lib/ui/wallets_page.dart` | Split into `_WalletsList`/`_Empty` + `AnimatedSwitcher`; hero card + recent-activity preview wired in; new wallet-type icons |
| `lib/ui/transactions_page.dart` | `_TxnTile` category-color icon (amount stays semantic); `_TxnsEmpty` + `AnimatedSwitcher` |
| `lib/ui/theme_customization_page.dart` | New "Biểu tượng" section; `_resetAll()` clears icon slots too |

---

## Session 9 — Bank capture system notification + unified CSV export/import (Branch: V0.2-Improve)

Two independent business-logic changes, planned together.

### 1. Bank capture system notification

**Problem:** a captured bank notification only ever showed up inside the app (badge, banner, `CapturesPage` inbox). The user has to have the app open to notice a new bank transaction needs confirming.

**Solution:** `CaptureService.drain()` now pops a real Android notification for every newly inserted capture, via a new `NotificationService.showCaptureNotification(capture, {walletName})` on a dedicated channel (`myfinance_capture_alert_v1`, distinct from the quiet persistent quick-add channel). Body text is "Có giao dịch {+/-amount} vào {wallet}" (via `formatSigned` from `lib/format.dart`), or a generic manual-review message for `ParseStatus.unparsed` captures with no amount. Two actions:

- **Thêm** (`showsUserInterface: true`): routed through the existing foreground `NotificationResponse` callback — the same mechanism the persistent quick-add notification already uses reliably across cold starts. `main.dart` wires `NotificationService.instance.onOpenCapture = (id) async { ... }` to fetch the capture via a new `FinanceRepository.captureById(id)` and push `CaptureConfirmPage`.
- **Bỏ qua** (`showsUserInterface: false`, per explicit user choice over a simpler "briefly opens the app" alternative): never opens the app UI. flutter_local_notifications runs this callback in its own **separate Flutter engine** (already plugin-registered on Android, per the plugin's README), so `_onResponseBackground` in `notification_service.dart` instantiates a throwaway `AppDatabase()` — safe, since the database already opens via `NativeDatabase.createInBackground`, so this is just another connection to the same sqlite file — and writes the dismissal directly, without ever bringing the app forward.

**Cross-isolate staleness fix:** since the dismiss write happens through a different `AppDatabase`/`QueryExecutor` instance than the live app's, Drift's reactive `watch()` streams don't see it automatically. `_AppLifecycleObserver.didChangeAppLifecycleState` (`main.dart`) now calls `db.markTablesUpdated({db.notificationCaptures})` on every `resumed`, alongside the existing `captureService.drain()` call, so the badge/banner/`CapturesPage` refresh correctly after a background dismiss.

**Testability:** `CaptureService`'s constructor gained an optional `notify: CaptureNotifier?` parameter (defaults to `NotificationService.instance.showCaptureNotification`). Without this, `drain()`'s new notification call would hit the `flutter_local_notifications` platform channel, which throws "Binding has not yet been initialized" in the existing pure-Dart `capture_drain_test.dart` suite (no `TestWidgetsFlutterBinding`). Tests now inject a no-op fake.

**Files changed:** `lib/services/notification_service.dart` (new channel, actions, `showCaptureNotification`, `_onResponseBackground`, `onOpenCapture` callback), `lib/services/capture_service.dart` (`CaptureNotifier` typedef + DI, `_notifyIfNew` helper), `lib/repositories/finance_repository.dart` (`captureById`), `lib/main.dart` (`onOpenCapture` wiring, `_AppLifecycleObserver` gained a `db` reference for the resume nudge), `lib/l10n/app_vi.arb`/`app_en.arb` (6 new `notifCapture*` keys), `test/capture_drain_test.dart` (inject fake `notify`).

### 2. Unified CSV export/import

**Problem:** export produced two separate files (wallets.csv, txns.csv); import offered two flows — `importMerge` with a `contextOnly`/`reconstructBalance` mode picker, and a destructive two-file `importReplace`. The `reconstructBalance` mode's `NonEmptyWalletReconstructError` guard (import into a non-empty wallet was rejected) existed to prevent double-counting balance — a concern schema v7's `balance_cutoff_at` (Session 7) already made moot, since each wallet's balance is self-contained regardless of transaction provenance. The wallet export also silently dropped `package_name`/`sort_order`/`balance_cutoff_at`, so `importReplace` restores lost bank-links/order/cutoffs — a latent bug.

**Solution:** `CsvService` now has exactly two methods, `exportAll()` and `importAll()`, writing/reading **one** CSV file. Since heterogeneous "tables" don't share a column schema, every row's first cell is a record-type discriminator instead of a per-section header:

```
META,schema_version,exported_at
WALLET,id,name,initial_balance,type,package_name,sort_order,balance_cutoff_at
TXN,id,type,amount,description,wallet_id,wallet_to_id,wallet_from_name,wallet_to_name,category,timestamp,imported,starred,source,affects_balance
CATEGORY,id,label,kind,threshold,is_default,archived,sort_order
SETTING,key,value
KEYWORD,keyword,category,weight
```

`exportAll({settingsEntries, keywordRules})` writes all six row types — wallets/transactions/categories come from `AppDatabase`; `settingsEntries` (new `AppSettings.exportEntries(kIconSlots)`) and `keywordRules` (`CategorySuggester.loadRaw()`) are passed in by `SettingsPage` so `CsvService` stays dependency-free of the settings/suggester service classes.

`importAll(path)` reads **wallets + transactions only** — CATEGORY/SETTING/KEYWORD/META rows are export-only (backup/documentation), parsed and ignored on import, per explicit user scoping. There is no mode picker — merge semantics (confirmed with the user):
- **Wallets**: insert-if-absent. A row whose `id` already exists in the database is skipped — the existing wallet always wins, so live `balance_cutoff_at`/`sort_order`/`package_name` are never clobbered by an older export.
- **Transactions**: upsert by `id` (`insertOnConflictUpdate`), applying every column exactly as stored in the file (no forced mode — `affects_balance`/`source`/`starred` all round-trip faithfully). Re-importing the same file is idempotent.

Returns `ImportSummary(walletsAdded, walletsSkipped, txnsAdded, txnsUpdated)` for the settings-page result snackbar.

**Removed:** `CsvImportMode` enum (`lib/models/domain.dart`), `NonEmptyWalletReconstructError`, the old `export()`/`importMerge()`/`importReplace()`, the "Merge"/"Replace" tiles and mode-picker dialog in `SettingsPage` (replaced by one "Nhập CSV" tile with a lightweight non-destructive confirm dialog).

**Files changed:** `lib/services/csv_service.dart` (rewritten), `lib/services/app_settings.dart` (`exportEntries`), `lib/models/domain.dart` (removed `CsvImportMode`), `lib/ui/settings_page.dart` (`_export`/`_import`, single-tile UI), `lib/l10n/app_vi.arb`/`app_en.arb` (CSV section keys consolidated), `test/csv_import_test.dart` (rewritten against `importAll`: fresh import, idempotent re-import, existing-wallet-preserved, existing-txn-updated, export-only-rows-ignored).

### Verification

`flutter analyze`: 0 new issues (2 pre-existing `use_build_context_synchronously` infos in `quick_add_page.dart`, unrelated). `flutter test`: all tests pass except 3 pre-existing failures already present before this session and unrelated to it — `test/balance_test.dart` and `test/auto_star_test.dart` fail to *load* (missing `sortOrder` argument, from the still-uncommitted Session 7 work) and one stale `test/sql_analytics_test.dart` assertion against the pre-Session-7 `affects_balance`-gated analytics behavior. Confirmed via `git diff`/`flutter analyze` output that none of these three are touched or newly caused by this session — see Session 8's "Verification" section for the same three, first observed there.

On-device testing (notification popup, cold-start "Thêm"/"Bỏ qua", CSV round-trip on a real device) was **not** performed as part of this session — flagged for the user to verify per the project's usual on-device test checklist.

### On-device follow-up — CSV file picker couldn't select files from Google Drive

**Problem:** on first real-device test, tapping a `.csv` file listed under a Google Drive location in the system file picker did nothing — the file appeared greyed out/unselectable. This was **not new** in this session; the picker call (`FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['csv'])`) was carried over unchanged from the old `_importMerge`/`_importReplace` flows. `FileType.custom` + `allowedExtensions` asks Android's Storage Access Framework document picker to filter by MIME type; cloud-provider-listed files (Google Drive here) frequently don't report the exact MIME type the filter expects, so SAF disables them even though the extension is correct — a well-known `file_picker`/Android limitation, not an app logic bug.

**Fix:** `lib/ui/settings_page.dart`'s `_import()` now calls `FilePicker.platform.pickFiles(type: FileType.any)` (no MIME filter, so every file stays selectable regardless of provider-reported MIME type) and validates the `.csv` extension in code afterward, showing `l10n.settingsCsvWrongFileType` if it doesn't match.

---

## Session 10 — Sparkline removal, Analytics drill-down, combined filter chip (Branch: V0.2-Improve)

On-device feedback after Session 8's redesign: the Ví tab's new Recent Activity sparkline didn't carry enough information to earn its space, the Thống kê tab's totals/categories were dead ends, and Giao dịch's Chi tiêu/Thu nhập/Danh mục three-chip filter setup cost an extra tap for the common "filter to one category" flow.

### 1. Sparkline removed from Recent Activity

`lib/ui/widgets/recent_activity_preview.dart`: deleted `_TrendSparkline` and the `_Trend`/`_trendOf` machinery that fed its `FlSpot` series (collapsed to a single `_netChangeOf(recentTxns) → int` the caption still needs); removed the now-fully-dead `fl_chart` import from this file (still used elsewhere, e.g. `analytics_page.dart`). The net-change caption line above where the chart used to sit ("Qua N giao dịch gần nhất · ±X ₫") was **kept** — it turned out to be the actually-useful part; the chart was only ever added to give that caption context.

### 2. Analytics → Transactions drill-down

**Problem:** `AnalyticsPage`'s totals and pie slices were read-only — no way to jump to the underlying transactions.

**Architectural prerequisite:** `AnalyticsPage` needed to switch `HomePage`'s active tab and preset `TransactionsPage`'s filters, but neither was reachable (tab index was `HomePage`-local `State`; filters were `TransactionsPage`-local `State`). Extended the existing `monthModeProvider`/`selectedMonthProvider` pattern (cross-widget UI state → `StateProvider`, not local `State`) with four more providers in `lib/providers.dart`: `homeTabIndexProvider` (replaces `HomePage`'s local `_index` entirely), `txnTypeFilterProvider`, `txnCategoryFilterProvider`, `txnStarredOnlyProvider` (the last one added so a drill-down can reset a stale "Có sao" filter left over from a prior manual Giao dịch session — otherwise the landed list could be a strict subset of what actually summed to the tapped figure). `_sortDirection` stayed `TransactionsPage`-local — it reorders, never hides rows.

**`_AnalyticsPageState._drillDown({required type, category})`**: writes `txnTypeFilterProvider`, `txnCategoryFilterProvider`, resets `txnStarredOnlyProvider` to `false`, sets `monthModeProvider = true` and `selectedMonthProvider = _month` (required, not optional — `_StatCard`/`_PieSection` figures are scoped to the month being viewed, not all-time), then `homeTabIndexProvider = 1`. Wired from:
- `_StatCard` (Tổng chi/Tổng thu) — new `onTap: VoidCallback?`, `Card(child: InkWell(borderRadius: BorderRadius.circular(16), onTap: onTap, child: ...))` (radius matches `main.dart`'s global `CardThemeData`).
- `_PieSection` — new `onSliceTap: void Function(String categoryId)?`, wired into both the pie chart (`pieTouchData.touchCallback` gained an `if (event is FlTapUpEvent)` branch, additive to the existing highlight-on-touch logic — `isInterestedForInteractions` is `false` for taps specifically on mobile, confirmed via the installed fl_chart 0.69.2 source, so the new branch can't reuse that guard) and each legend row (wrapped in `InkWell`). Both index into the same `entries` list that drives the pie sections, so `entries[i].key` is the category id either way.

**Category-coalescing fix** (`transactions_page.dart`'s filter chain): `'others'`/`'others_earn'` are simultaneously the real seeded ids of the default "Khác" categories *and* the analytics SQL's `COALESCE(category, 'others'|'others_earn')` bucket for `category IS NULL` rows (reachable via `CaptureConfirmPage`'s "— Bỏ qua —" option). The old exact-match filter (`t.category == categoryFilter`) didn't do this coalescing, so drilling into (or even just manually filtering by) "Khác" would have silently omitted uncategorized transactions the analytics total already counted. Fixed by comparing `(t.category ?? (t.type == TxTypes.earning ? 'others_earn' : 'others')) == categoryFilter` instead — mirrors the SQL exactly.

**Scope boundary:** only the two stat cards and the two pie sections drill down. `_YearCard` and the "Chênh lệch tháng này" comparison card stay non-interactive — not requested.

### 3. Combined type+category filter chip

**Problem:** filtering to one category took two taps — select Chi tiêu/Thu nhập, then a separate Danh mục chip that only appeared once a type was active.

**Solution:** `transactions_page.dart`'s `_buildFilterBar` replaces the "Chi tiêu"/"Thu nhập" `ChoiceChip`s and the conditional "Danh mục" `FilterChip` (three elements) with a `typeCategoryChip()` helper local to `_buildFilterBar` (closes over `context`/`catLabels`/`l10n`/`ref` for free) that builds one combo-chip per type:
- Inactive: plain type label, `showCheckmark: false`.
- First tap (inactive → active): sets the type filter, clears that type's category, reveals a trailing `Icons.arrow_drop_down`.
- Second tap (already active): opens `_pickCategory()` instead of toggling — `categoriesForType` is computed per chip from that chip's own fixed type, not the shared filter state, since the picker can only ever open for the type that's already active.
- After picking, the label swaps from the type name to the category's label (arrow stays); picking "Tất cả" reverts to the plain type label.

Chip row order shifted as a forced consequence (Danh mục no longer exists as a separate element): Tất cả/Tháng → Chi tiêu-combo → Thu nhập-combo → Có sao → Sort.

`_starredOnly`/`_typeFilter`/`_categoryFilter` (previously local `State`, now the providers from §2) are read via `ref.watch` and written via `ref.read(...notifier).state =` at every mutation site — the two combo-chips, the Có sao chip, and `_pickCategory`'s result handling.

### Verification

`flutter analyze`: 0 new issues, same 2 pre-existing `use_build_context_synchronously` infos in `quick_add_page.dart` and the same pre-existing `sortOrder`-related test-loading errors already tracked in Sessions 8/9 (confirmed unrelated via `git diff` — none of `test/balance_test.dart`/`test/auto_star_test.dart` touched). `flutter test`: same pre-existing 3 failures, no new ones. Full debug APK build succeeded.

On-device re-verification of the specific interactions this session touched (drill-down from both stat cards and both pie sections including a "Khác" slice, the combo-chip's two-tap flow, tab-switch/swipe still working after the `_index` lift) was **not** performed as part of writing this entry — flagged for the user, per the project's usual on-device test checklist.

### Key files changed in this session

| File | Change |
|------|--------|
| `lib/providers.dart` | 4 new `StateProvider`s: `homeTabIndexProvider`, `txnTypeFilterProvider`, `txnCategoryFilterProvider`, `txnStarredOnlyProvider` |
| `lib/ui/home_page.dart` | `_index` local `State` → `homeTabIndexProvider` |
| `lib/ui/transactions_page.dart` | Filter state → providers; `_buildFilterBar` combo-chip rebuild; category-coalescing predicate fix |
| `lib/ui/analytics_page.dart` | `_drillDown()`; `_StatCard`/`_SummaryCards` gained `onTap`/`onTotalTap`; `_PieSection` gained `onSliceTap` (pie touch + legend rows) |
| `lib/ui/widgets/recent_activity_preview.dart` | Sparkline removed; `_Trend`/`_trendOf` simplified to `_netChangeOf` |

---

## Session 11 — Envelope budgeting (Branch: V0.2-Improve)

User request: assign each spending category a % of every income; the category's "envelope" balance is that accumulated share minus what's been spent in it, so the Thống kê tab can show whether there's still budget left per category. Three product decisions were confirmed with the user up front (see ADR-0020 above for the architecture they drove): percentage changes are **not retroactive**; overspending an envelope is **informational only**, never blocking; budget percentages must sum to **≤100%**, not exactly 100%.

### Schema v8 — `category_budget_history`

New append-only table: `id, category_id, percent (0-100), effective_from (Unix seconds)`. A percent edit always inserts a new row, never updates one. Migration (`if (from < 8)`) is raw `CREATE TABLE`/`CREATE INDEX` — following the v6/v7 precedent, since `database.g.dart` doesn't have the generated accessor yet at migration-authoring time. Deliberately seeds **nothing** on the upgrade path (no percent was ever "in effect" for pre-existing installs); `onCreate` only (fresh installs) seeds necessities/food/hobbies/others at 50/15/20/15 via a new `_seedBudgetPercents()`, matching the feature's own worked example.

### `AppDatabase` (`lib/data/database.dart`)

- `categoryBudgetPercents()`/`watchCategoryBudgetPercents()` — folds the history table to `{categoryId → current effective percent}` in Dart (latest `effectiveFrom` wins; the table only grows on user edits, realistically tens of rows, so a Dart fold beats an awkward SQL self-join tie-break).
- `allCategoryBudgetHistory()` — every row, unfolded, for CSV export completeness.
- `watchEnvelopeBalances()`/`_buildEnvelopeBalances()` — two `customSelect` queries glued in Dart (mirrors `_buildAnalyticsBundle`'s own multi-query shape): an "as-of" correlated subquery finds, per earning, the most recent `category_budget_history` row at-or-before that earning's own `timestamp`; a second query sums spending per category (`COALESCE(category,'others')`, matching analytics' fallback). Both filter `type`+`affects_balance=1` — unlike analytics, envelopes track real money only. Listens for changes on `txns`, `category_budget_history`, **and** `app_categories` (`TableUpdateQuery.allOf([...])` — its doc-comment says "matches any query in the list," i.e. OR semantics despite the name) — `watchAnalyticsBundle` only listens to `txns`, which would silently miss a percent edit or an archive toggle.

### `FinanceRepository`

- `BudgetPercentExceededException` — zero-payload, mirrors `OverspendException` exactly (same "repository is the one choke point" reasoning as the "no direct DB access from UI" rule).
- `setCategoryBudgetPercent(categoryId, percent)` — sums `percent` against every *other* active spending category's current percent (the target's own prior value is excluded, not double-counted); throws if the sum exceeds 100. Always inserts a new history row on success (even if the value is unchanged — still correct, since "no-op" isn't meaningfully different from "re-affirm the same allocation from now on").
- `addCategory` changed from `Future<void>` → `Future<String>` (returns the new id) — mirrors the earlier `addWallet` precedent — so the add-category dialog can immediately call `setCategoryBudgetPercent` on a category that didn't exist a moment before.

### UI (minimal — per this chat's business-logic scope; visual polish left to the other chat)

- `lib/ui/categories_page.dart`: a % `TextField`, conditional on `kind == TxTypes.spending`, sibling to the existing threshold field in both add/edit dialogs (same conditional-field pattern). Both dialogs wrapped in `StatefulBuilder` so a caught `BudgetPercentExceededException` can show an inline `errorText` without losing the user's typed values or closing the dialog. The category list wraps its existing `StreamBuilder<List<AppCategory>>` with an outer `StreamBuilder<Map<String,int>>` (`watchCategoryBudgetPercents()`) to show/prefill current percents.
- `lib/ui/analytics_page.dart`: new `_EnvelopeSection` (plain list, `spendColor` dot + label + `formatVnd(balance)`, red when negative) added after the spend-by-category `_PieSection`. Not month-scoped like the rest of the page, so it keeps its own `StreamBuilder` rather than folding into `_Stats`. Reuses the `catLabels` map already computed once in `_AnalyticsPageState.build()`, and reuses the *existing* `_drillDown(type, category)` (Session 10) for row taps rather than inventing a second navigation path — this session was re-checked against Session 10's concurrent changes before writing any analytics_page.dart code, specifically so the two didn't collide.

### CSV (`lib/services/csv_service.dart`)

New `BUDGET,id,category_id,percent,effective_from` record type — export-only (like `CATEGORY`/`SETTING`/`KEYWORD`), sourced from `allCategoryBudgetHistory()`. `importAll()` needed no change — unrecognized record types were already silently skipped.

### Testing

`test/envelope_budget_test.dart` (new, 18 tests): SQL-vs-Dart-oracle-style correctness tests (the worked example; percent-change-mid-timeline proving non-retroactivity; envelope-goes-negative-without-blocking; null-category/`affects_balance=0`/transfer exclusions; pre-configuration earnings contribute $0; archived-category exclusion; <100% leftover; `updateTxn`/`deleteTxn` on an earning correctly changes the next read with zero code touching either method) plus a 3-part invariant-guard suite for `setCategoryBudgetPercent` (boundary-pass/exceed/atomicity, self-exclusion, archived-exclusion).

**Reactivity-test gotcha worth remembering**: the first attempt at the three "stream re-emits on X" tests used `StreamIterator`, and all three timed out even with a settle delay — not a bug in `watchEnvelopeBalances()`, but `StreamIterator` pausing its underlying subscription between `moveNext()` calls, which for an `async*` generator also suspends the generator body — it never reached its inner `await for (tableUpdates(...))` before the test's mutation fired, so the notification was missed permanently. Fixed by switching the test to a plain `.listen()` collecting events into a list. A live `StreamBuilder` in the running app never pauses like this, so production code was never at risk — this was purely a test-consumption-pattern bug.

`test/migration_test.dart`: extended the existing v2→v3 test with one more assertion (`category_budget_history` is empty after the cascade-upgrade — proves no retroactive seeding) rather than hand-writing a new v7-schema replica, since `onUpgrade` runs every `if (from < N)` block in sequence regardless of starting version, so reopening the v2 seed with the current `AppDatabase` already exercises v8 too. Added one small standalone test confirming fresh installs seed 50/15/20/15.

### Verification

`flutter analyze`: 0 new issues (same 2 pre-existing `quick_add_page.dart` infos). `flutter test`: same 3 pre-existing failures already tracked since Session 8/9 (`test/balance_test.dart`/`test/auto_star_test.dart` load errors, one stale `sql_analytics_test.dart` assertion) — confirmed identical failure signatures, nothing new. All 20 new tests pass.

On-device testing (setting percentages that sum near 100%, confirming a real earning splits correctly, confirming a percent change doesn't reshape past income, confirming an over-budget spend still saves) was **not** performed as part of this session — flagged for the user per the project's usual on-device test checklist.

### Key files changed in this session

| File | Change |
|------|--------|
| `lib/data/database.dart` | `CategoryBudgetHistory` table; schema v8 migration; `_seedBudgetPercents()`; `categoryBudgetPercents`/`watchCategoryBudgetPercents`/`allCategoryBudgetHistory`/`watchEnvelopeBalances`/`_buildEnvelopeBalances` |
| `lib/repositories/finance_repository.dart` | `BudgetPercentExceededException`; `setCategoryBudgetPercent`; `addCategory` now returns the new id; two stream pass-throughs |
| `lib/ui/categories_page.dart` | % field in add/edit dialogs (`StatefulBuilder` for inline errors); nested `StreamBuilder` for current percents |
| `lib/ui/analytics_page.dart` | New `_EnvelopeSection`, wired to the existing `_drillDown` |
| `lib/services/csv_service.dart` | `BUDGET` export-only row type |
| `lib/l10n/app_vi.arb`, `app_en.arb` | 4 new keys: category %-field label/subtitle, `budgetPercentExceededError`, `analyticsEnvelopeSectionTitle` |
| `test/envelope_budget_test.dart` (new), `test/migration_test.dart` | see Testing above |

---

## Session 12 — Envelope budgeting visual polish (Branch: FE-dev)

Follow-up to Session 11, which deliberately shipped a minimal, no-progress-bar display and flagged visual treatment as separate work. This session is that deferred polish, Analytics tab only — `categories_page.dart`'s %-entry dialog stays untouched (confirmed with the user).

### Design

Confirmed with the user up front: each budgeted category gets a two-line row — label + `{percent}%` badge, then a thin progress bar (spent vs. allocated), then a "Còn lại: X ₫" / "Vượt: X ₫" caption. Categories with no percent currently configured (0%/unset) are **hidden** — showing them would misleadingly frame unbudgeted spending as "overspent."

### Data layer (`lib/data/database.dart`)

`_buildEnvelopeBalances()` computed `allocated` and `spent` internally but only ever returned their pre-subtracted difference (`Map<String, int>`) — a progress bar needs both numbers, not just the difference. No SQL or computation logic changed (same two queries, same as-of join, same `affects_balance` filtering) — just stopped collapsing the result before returning it. Added `EnvelopeStatus{allocated, spent}` (with a `balance` getter, `allocated - spent`, for callers that only want the old number) next to `AnalyticsBundle`; `watchEnvelopeBalances()`/`_buildEnvelopeBalances()` now return `Map<String, EnvelopeStatus>`. `FinanceRepository.watchEnvelopeBalances()` is a pass-through, updated to match.

### UI (`lib/ui/analytics_page.dart`)

`_EnvelopeSection` now takes the full `List<AppCategory>` (`_AnalyticsPageState.build()` already fetches this via `watchAllCategories()`, ordered by `sort_order`) instead of the flattened `catLabels` map, and nests a `StreamBuilder<Map<String,int>>` on `watchCategoryBudgetPercents()` (percent badge + hide-if-0% filter — the same stream `CategoriesPage` already uses for its own subtitle) around the existing `watchEnvelopeBalances()` stream. New `_EnvelopeRow` renders the two-line design: `LinearProgressIndicator` (`spendColor` when under/on budget, `colorScheme.error` when over) inside a `ClipRRect` for rounded ends, plus the caption. Explicit three-way caption/ratio logic handles the case a plain `spent/allocated` division can't: `allocated == 0 && spent == 0` (freshly budgeted, no income recorded since) → empty bar, "Chưa có thu nhập để phân bổ"; `spent > allocated` (including `allocated == 0 && spent > 0`) → full red bar, "Vượt: {spent-allocated}"; otherwise → partial bar, "Còn lại: {balance}".

### l10n

3 new keys: `analyticsEnvelopeRemaining`/`analyticsEnvelopeOverBy` (both take an `{amount}` placeholder, matching `analyticsCategoryTotal`'s existing `{total}` pattern) and `analyticsEnvelopeNotFundedYet`. The `{percent}%` badge itself needed no new key — matches the existing pie-chart sector label precedent (`'${pct.toStringAsFixed(1)}%'`, plain Dart interpolation, no ARB entry).

### Testing

`test/envelope_budget_test.dart` needed updating for the `Map<String, int>` → `Map<String, EnvelopeStatus>` signature change: every `balances['x']`-against-a-number assertion became `balances['x']?.balance`, the `collectTwo` reactivity helper's generic type changed, and a `values.fold` picked up `.balance` on its accumulator. All 18 pre-existing tests pass unchanged in behavior. `flutter analyze`: 0 new issues (same pre-existing `quick_add_page.dart` infos + `balance_test.dart` `sortOrder` errors). `flutter test`: same 3 pre-existing failures as every prior session (`balance_test.dart`/`auto_star_test.dart` load errors, one stale `sql_analytics_test.dart` assertion) — confirmed identical before/after with `git stash`.

On-device testing (confirming the bar renders correctly for under/over/not-yet-funded states, tap-to-drill-down, and the section hiding itself when nothing's budgeted) was **not** performed as part of this session — flagged for the user per the project's usual on-device test checklist.

### Key files changed in this session

| File | Change |
|------|--------|
| `lib/data/database.dart` | `EnvelopeStatus` class; `watchEnvelopeBalances`/`_buildEnvelopeBalances` return `Map<String, EnvelopeStatus>` instead of `Map<String, int>` |
| `lib/repositories/finance_repository.dart` | `watchEnvelopeBalances()` return-type pass-through updated |
| `lib/ui/analytics_page.dart` | `_EnvelopeSection` rewritten to take `List<AppCategory>` + cross percents/balances; new `_EnvelopeRow` (percent badge, progress bar, remaining/over caption) |
| `lib/l10n/app_vi.arb`, `app_en.arb` | 3 new keys: `analyticsEnvelopeRemaining`, `analyticsEnvelopeOverBy`, `analyticsEnvelopeNotFundedYet` |
| `test/envelope_budget_test.dart` | Updated all `Map<String, int>`-shaped assertions/helpers for `EnvelopeStatus` |
| `docs/tab_analytics.md`, `docs/architecture.md` | Envelope budgeting section updated for the new UI and `EnvelopeStatus` return shape |

## Session 13 — Envelope budgeting: inline % editing + per-category reset (Branch: FE-dev)

Two functional additions on top of Session 11/12's read-only envelope display, both requested directly against the Analytics tab: (1) edit a category's budget % without leaving Thống kê, and (2) a per-category "reset" that zeroes an envelope's cumulative allocated/spent so only transactions from that point forward count — for when a one-off anomalous transaction skews a category's bar indefinitely. Planned in `plan` mode; the user picked **per-category** reset over a single "reset all" button, explicitly to keep categories independent of each other (mirroring how each wallet already resets independently).

### Design

Percent editing needed zero data-layer change — `setCategoryBudgetPercent`'s append-only "as-of" history already behaves exactly as requested (old transactions keep the old %, new ones use the new %); this was purely a matter of exposing the existing call on a new UI surface. Reset is new: it mirrors `wallets.balance_cutoff_at` (Session pre-11), but as a **per-category** nullable cutoff column on `app_categories` rather than a single global flag, so resetting one category never touches another's numbers.

### Schema (`lib/data/database.dart`, v8 → v9)

Added `app_categories.envelope_cutoff_at` (nullable Unix seconds, mirrors `wallets.balance_cutoff_at`). Migration `if (from < 9)`: additive `ALTER TABLE app_categories ADD COLUMN envelope_cutoff_at INTEGER NULL`, no backfill — NULL is the correct "no cutoff" default for every existing row.

### Data layer (`lib/data/database.dart`)

Both `_buildEnvelopeBalances()` subqueries now filter by each category's own cutoff. The earned-share subquery already has the category row (`c`) in scope, so it only needed `AND e.timestamp >= COALESCE(c.envelope_cutoff_at, 0)` added to its inner `WHERE`. The spent-side query previously had no join at all (a flat `GROUP BY category`); it now joins `app_categories` on `c.id = COALESCE(t.category, 'others')` — the coalesced value, not the raw nullable column, so null-category spending still correctly resolves to the `'others'` row's own cutoff instead of being dropped by the join. `readsFrom` for the spent query changed from `{txns}` to `{txns, appCategories}`.

### Repository (`lib/repositories/finance_repository.dart`)

New `resetEnvelope(String categoryId, {DateTime? at})`: sets that category's `envelope_cutoff_at` to now inside a transaction, then explicitly calls `markTablesUpdated({appCategories})`. That explicit call matters here specifically — `updateWallet`'s analogous cutoff write gets away without one only because it piggybacks on a preceding *typed* `WalletsCompanion` write in the same transaction; `resetEnvelope` has no such accompanying typed write, so without the explicit call `watchEnvelopeBalances()` would silently stop re-emitting after a reset. The optional `{DateTime? at}` is a testing seam (every real call site omits it) — added because it's the only way to assert exact cutoff-boundary behavior deterministically, mirroring the `DateTime? timestamp` parameter already on `addSpending`/`addEarning`/`addTransfer`. No new validation guard: unlike the 100%-sum check on `setCategoryBudgetPercent`, a cutoff write can't violate any other row's invariant.

### UI (`lib/ui/analytics_page.dart`)

`_EnvelopeRow` gained a small trailing `IconButton(Icons.edit_outlined)` next to the existing `{percent}%` badge — a nested Material tappable inside the row's outer `InkWell`, so it claims its own tap before drill-down navigation fires. It opens `_showEnvelopeEditDialog`, reusing `categories_page.dart`'s validation shape exactly (`AlertDialog` + `StatefulBuilder`, a percent `TextField`, catches `BudgetPercentExceededException` into inline `errorText`). That dialog's `actionsAlignment: spaceBetween` puts a "Đặt lại ngân sách…" text button on the left (visually separated from Cancel/Save on the right); tapping it closes the edit dialog and opens `_confirmResetEnvelope`, a second, purpose-built confirmation styled like `theme_customization_page.dart`'s `_resetAll` (plain, non-error `AlertDialog` — this isn't as destructive as a delete). Confirming calls `repo.resetEnvelope(categoryId)`. The two actions are deliberately independent — tapping Reset discards any unsaved percent keystrokes, since Save and Reset are unrelated mutations. No success snackbar (matches `_resetAll`/`_confirmArchive` precedent) — the row's own `StreamBuilder`s re-render reactively once the reset lands.

### l10n

5 new keys, inserted after `analyticsEnvelopeNotFundedYet`: `analyticsEnvelopeEditTitle` (placeholder `label`), `analyticsEnvelopeResetTrigger`, `analyticsEnvelopeResetConfirmTitle` (placeholder `label`), `analyticsEnvelopeResetConfirmBody`, `analyticsEnvelopeResetAction`. The trigger and action labels are deliberately separate keys (not one key reused for both, unlike `_resetAll`'s single `themeResetAction`) — the trigger sits directly next to a Save button inside a form dialog, where a bare "Reset" would be ambiguous between resetting the typed field or the envelope.

### Testing

`test/envelope_budget_test.dart`: new `group('resetEnvelope', ...)` (7 tests) — zeroes both allocated and spent with nothing following; earning/spending before the cutoff excluded while after it still counts (separate tests, since the earned and spent sides needed separate query changes); resetting one category leaves others untouched; a txn timestamped exactly at the cutoff still counts (`>=`, not `>`); an archive/unarchive round-trip doesn't clear the cutoff; and a `collectTwo`-based reactivity test extending the existing `group('reactivity', ...)`, added specifically to catch a missing `markTablesUpdated` call. `test/migration_test.dart`: extended the existing v2→v9 cascade test with a Phase 6 asserting a pre-existing category's `envelope_cutoff_at` reads back `NULL` post-migration (seeded a category row via raw SQL in Phase 1, since this test's upgrade path — starting from v2 already past the `if (from < 2)` seeding block — never runs `_seedCategories()`).

`flutter analyze`: 0 new issues (same pre-existing `quick_add_page.dart` infos + `balance_test.dart` `sortOrder` errors as every prior session). `flutter test`: 169 tests, same 3 pre-existing failures as every prior session (`balance_test.dart`/`auto_star_test.dart` load errors, one stale `sql_analytics_test.dart` assertion) — all new tests (resetEnvelope group + migration Phase 6) pass.

On-device testing (confirming the edit icon/dialog and reset flow render and behave correctly — tap targets not colliding with drill-down, the confirm dialog, the bar dropping to "Chưa có thu nhập để phân bổ" immediately after a reset) was **not** performed as part of this session — flagged for the user per the project's usual on-device test checklist.

### Key files changed in this session

| File | Change |
|------|--------|
| `lib/data/database.dart` | `app_categories.envelope_cutoff_at` column + v9 migration; `_buildEnvelopeBalances()` both subqueries filter by per-category cutoff (spent-side query gained a join) |
| `lib/repositories/finance_repository.dart` | New `resetEnvelope(categoryId, {at})` |
| `lib/ui/analytics_page.dart` | `_EnvelopeRow` gained an edit icon + `onEdit`; new `_showEnvelopeEditDialog`/`_confirmResetEnvelope` dialogs |
| `lib/l10n/app_vi.arb`, `app_en.arb` | 5 new keys: `analyticsEnvelopeEditTitle`, `analyticsEnvelopeResetTrigger`, `analyticsEnvelopeResetConfirmTitle`, `analyticsEnvelopeResetConfirmBody`, `analyticsEnvelopeResetAction` |
| `test/envelope_budget_test.dart` | New `group('resetEnvelope', ...)` (7 tests) + 1 reactivity test |
| `test/migration_test.dart` | New Phase 6 asserting the v9 column migrates in as `NULL` |
| `docs/tab_analytics.md`, `docs/architecture.md`, `CLAUDE.md` | Schema version, `app_categories` table, and Envelope budgeting sections updated for the new column/reset mechanism and the second %-edit entry point |

---

## Session 14 — CSV backup/restore: import support for categories + budget history (Branch: FE-dev)

**Problem:** Session 9's unified CSV export already wrote `CATEGORY` and `BUDGET` (`category_budget_history`) rows, but `importAll` only ever consumed `WALLET`/`TXN` rows — both were parsed and silently discarded on import, documented as "export-only." The user asked for the envelope-budgeting feature to round-trip through CSV backup/restore. Investigation surfaced a dependency: `BUDGET` rows key off `category_id`, and default categories use fixed string ids (`'food'`, `'necessities'`, etc., stable across installs) but user-created custom categories get a `uuid.v4()` id — those would never match after a fresh install, leaving restored budget history orphaned unless `CATEGORY` rows were imported too. Confirmed with the user: import both.

**Solution (`lib/services/csv_service.dart`):** Two new branches in `importAll`'s row loop, both following the existing `WALLET` insert-if-absent pattern (skip a row whose `id` already exists, so live device state always wins over an older export):
- `CATEGORY` → `db.into(db.appCategories).insert(AppCategoriesCompanion.insert(...))`, field-for-field the same shape as `_seedDefaultCategories`.
- `BUDGET` → `db.into(db.categoryBudgetHistory).insert(CategoryBudgetHistoryCompanion.insert(...))`, same shape as `_seedBudgetPercents`. Insert-if-absent-by-id is a natural fit here since the table is append-only — re-importing the same file just skips every row it already wrote, rather than duplicating history. No FK constraint enforces `category_id`, so a `BUDGET` row importing before/without a matching category degrades the same way an orphan `txns.category` already does — silently inert until a matching id shows up. This is a non-issue on a normal round-trip since export always writes `CATEGORY` rows before `BUDGET` rows and both are consumed in one sequential pass.

`ImportSummary` gained `categoriesAdded`/`categoriesSkipped`/`budgetEntriesAdded`/`budgetEntriesSkipped`, threaded through to the settings-page result snackbar (`l10n.csvImportResult`, extended with 3 new placeholders in both `.arb` files, regenerated via `flutter gen-l10n`). SETTING/KEYWORD/META rows remain export-only/ignored — unchanged.

### Testing

`test/csv_import_test.dart`: the old "CATEGORY/SETTING/KEYWORD/META rows are ignored" test was split — CATEGORY is no longer in that ignored set, so it got its own coverage instead. Added: fresh import of `CATEGORY`+`BUDGET` rows populates `app_categories`/`category_budget_history` and the percent is readable via `db.categoryBudgetPercents()`; re-import is idempotent (skip counts, no duplicate rows — asserted via before/after counts rather than an assumed-empty table, since `AppDatabase.forTesting` seeds the default categories/budget rows on creation); an existing category with a matching id is preserved, not overwritten.

`flutter analyze`: clean on the changed files. `flutter test test/csv_import_test.dart`: 8/8 pass. Full suite: same 3 pre-existing failures as every prior session since Session 8 (`balance_test.dart`/`auto_star_test.dart` load errors from the still-uncommitted Session 7 `sortOrder` work, one stale `sql_analytics_test.dart` assertion) — confirmed unrelated via `git status`, none of those three files are touched by this session's diff.

### Key files changed in this session

| File | Change |
|------|--------|
| `lib/services/csv_service.dart` | `importAll` gained `CATEGORY`/`BUDGET` branches (insert-if-absent); `ImportSummary` gained 4 fields |
| `lib/ui/settings_page.dart` | `_import()`'s snackbar call passes the 3 new `csvImportResult` placeholders |
| `lib/l10n/app_vi.arb`, `app_en.arb` | `csvImportResult` extended with `categoriesAdded`/`categoriesSkipped`/`budgetEntriesAdded` |
| `test/csv_import_test.dart` | Split the stale ignored-rows test; added category/budget import + idempotency + preservation cases |
| `docs/architecture.md`, `docs/tab_settings.md` | `CsvService`/CSV import sections updated — CATEGORY/BUDGET are now imported, not export-only |
