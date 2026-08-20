# MyFinance — Workflow Skills

Quick-reference recipes for common project tasks. Read this file when starting a task that matches one of the skills below.

Project context lives in `CLAUDE.md` at the project root (auto-loaded by Claude Code).

---

## Skill: session-start

Orient quickly at the start of any session.

1. `git log --oneline -5` — see what was last committed
2. `git status` — check for uncommitted work from the previous session
3. Read the last section of `docs/history.md` — recap what was done and what was left pending
4. Read the tab-specific doc for the area you're about to work on (`docs/tab_wallets.md`, `docs/tab_transactions.md`, etc.)
5. If the task involves the DB schema, check the current `schemaVersion` in `lib/data/database.dart`

---

## Skill: schema-change

Adding a new column to an existing table.

1. Add the column field to the Drift table class in `lib/data/database.dart` (e.g. `IntColumn get myCol => integer().nullable()();`)
2. Increment `schemaVersion`
3. Add a migration block in `onUpgrade`:
   ```dart
   if (from < N) {
     await customStatement('ALTER TABLE my_table ADD COLUMN my_col INTEGER NULL');
   }
   ```
4. **Before `make apk` (pre-regeneration):**
   - Reads: `customSelect('SELECT my_col FROM my_table WHERE id=?', ...)` + `row.readNullable<int>('my_col')`
   - Writes: `customStatement('UPDATE my_table SET my_col = ? WHERE id = ?', [value, id])`
   - Any write via `customStatement` inside a transaction → add `markTablesUpdated({myTable})` after it
5. Update any existing SQL query strings that join or reference this table
6. Run `make apk` → `database.g.dart` is regenerated; typed accessors (`MyTableCompanion(myCol: Value(...))`) now work
7. Update `docs/architecture.md` — add the column to the relevant table section
8. Update `docs/history.md` — note the schema version bump and what changed

---

## Skill: new-screen

Adding a new full-page screen.

1. Create `lib/ui/new_page.dart`:
   - Use `ConsumerStatefulWidget` if local state is needed, `ConsumerWidget` if not
   - Read DB data via `ref.read(repositoryProvider)` (or `ref.watch` for reactive streams) — never call `ref.read(dbProvider)` directly
2. Push from the parent widget:
   ```dart
   Navigator.of(context).push(MaterialPageRoute(builder: (_) => const NewPage()));
   ```
3. If adding a **tab**:
   - Add the page to `_pages` list in `HomePage` (`lib/ui/home_page.dart`)
   - Add a `NavigationDestination` to the `NavigationBar`
   - Update `_titles` list
4. Update the relevant tab doc in `docs/`

---

## Skill: add-transaction-flow

Adding a new transaction type or modifying the add/edit flow.

1. New type string → add to `TxTypes` in `lib/models/domain.dart`
2. Repository write method in `lib/repositories/finance_repository.dart`:
   - Wrap in `db.transaction()`
   - Call `_assertSufficient` if money leaves a wallet
   - Pass `affects_balance: true` on insert
   - Call `_shouldAutoStar` if the type supports auto-starring
3. `QuickAddPage` (`lib/ui/quick_add_page.dart`): add branch in `_save()` for the new type
4. `_TxnTile` in `lib/ui/transactions_page.dart`: update title logic and amount display for the new type
5. Balance SQL in `lib/data/database.dart`: add UNION ALL arm if the new type affects wallet balances
6. Update docs

---

## Skill: document-changes

Which docs to update after any feature or fix session.

Update in this order:

1. **`docs/history.md`** — always, for any session work:
   - Append a new `## Session N` section
   - Include: what changed, why, files changed table, bugs fixed (if any)

2. **Tab-specific doc** — for any UI or behaviour change:
   - `docs/tab_wallets.md` — Ví tab, wallet edit, balance reset
   - `docs/tab_transactions.md` — Giao dịch tab, filters, month mode, star
   - `docs/tab_analytics.md` — Thống kê tab
   - `docs/tab_settings.md` — Cài đặt tab

3. **`docs/architecture.md`** — for any of:
   - Schema change (update the table columns section)
   - New Riverpod provider (update the providers table)
   - Analytics computation change (update Analytics computation section)
   - Layer/service architecture change

4. **`docs/MyFinance_ADR.md`** — when an architectural decision was explicitly made (new ADR number, problem → decision → consequences format)

Do **not** update docs for work that isn't complete yet. If a session ends mid-task, note the pending state in `docs/history.md`.

---

## Skill: debug-balance

When a wallet shows an unexpected balance.

1. Check `balance_cutoff_at` for that wallet — if set, only txns with `timestamp >= cutoff` count. A balance reset sets this to unix-now.
2. Check `affects_balance` on suspicious txns:
   - CSV context-only imports have `affects_balance=0`
   - Manually created txns have `affects_balance=1`
3. Verify `markTablesUpdated({wallets})` or `markTablesUpdated({txns})` is called after any `customStatement` that writes to those tables — otherwise the reactive stream never re-emits.
4. Call `db.sqlBalance(walletId)` directly in a debug session and compare to what `watchWalletBalances()` returns — if they match, the display is correct and the mental model is wrong; if they differ, a stream notification is missing.
5. Check the balance SQL constants (`_kAllBalancesSql`, `_kSingleBalanceSql`) in `lib/data/database.dart` — confirm the UNION ALL arms cover all txn types and the cutoff JOIN is present.

---

## Skill: debug-stream-not-updating

When a reactive stream (wallet list, balance map, txn list) doesn't update after a write.

Almost always caused by using `customStatement` without `markTablesUpdated`.

1. Find the write path (repository method → database method)
2. Check if it uses `customStatement` or `customInsert`/`customUpdate` instead of typed Drift methods
3. If yes: add `markTablesUpdated({affectedTable})` inside the same `db.transaction()` call after the statements
4. If using typed Drift methods (`db.into(db.table).insert(...)`, `db.update(db.table).write(...)`): these auto-notify — look elsewhere

---

## Skill: bank-capture-pipeline

When adding a new bank parser or debugging a capture that isn't showing up.

Pipeline flow:
```
Bank notification → BankCaptureService.kt (buffers to SharedPreferences)
    → CaptureService.drain() on app resume
    → BankParserRegistry.forPackage(pkg)?.parse(raw)
    → FinanceRepository.insertCapture() (dedup by dedupKey, 2-min window)
    → watchPendingCaptures() stream → CapturesPage
```

1. **New bank:** add package constant to `BankPackages` in `lib/services/bank/bank_notification_parser.dart`, create parser file in `lib/services/bank/`, register in `BankParserRegistry`
2. **Verify package name:** Settings → Nhà phát triển → "Gói ứng dụng đã thấy" shows every package seen by the listener
3. **Capture not appearing:** check `ParseStatus` — `unparsed` means the parser returned null but text was money-shaped; `needsReview` is low-confidence; both appear in the inbox
4. **Dedup false positive:** `dedupKey = packageName + '\x1e' + normalizedText`; 2-minute window. If two real transactions look identical, the second is silently dropped — this is by design (ADR-0017)
