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
