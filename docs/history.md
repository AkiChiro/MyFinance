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

Open tasks (from GitHub issues, to be implemented in future sessions):
- (User will provide issues)
