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
