# Claude Code Task — MyFinance Phase 5a: Bank-Capture Data Model

> Paste this whole file into Claude Code as the task brief. This is the **pure-Dart + Drift backbone** of the bank feature — no native code, no parsers, no UI. Those are later slices (5b/5c/5d). Do not start coding until you have proposed a plan (see "Before you code"). References: **ADR-0013** (capture pipeline & table), **ADR-0014** (wallet matching), **ADR-0009** (`source`/`affectsBalance`).

---

## Project context

MyFinance is an offline, Android-first Flutter finance tracker using **Drift** (SQLite). Money is integer VND. Phases 1, 3, and 4 are complete: Riverpod DI; the transaction model carries a `source` enum (`manual` / `csvImport` / `bankNotification`) and an `affectsBalance` bool (ADR-0009); balances and analytics are SQL aggregates (`schemaVersion` is currently **4**). All green, analyze-clean.

The upcoming bank feature reads bank notifications and proposes transactions the user confirms. This slice builds only the **data model and repository backbone** every later slice writes into — the persistent capture table and the wallet↔bank association — so it's fully testable with zero native or parsing code.

Relevant files: `lib/data/database.dart` (schema, migrations, `schemaVersion`), `lib/repositories/finance_repository.dart` (transaction writes, `source`/`affectsBalance` handling), `lib/models/domain.dart` (enums; note the append-only `textEnum` convention established for `SourceType`), and `test/`.

---

## Goal

Add a persistent `NotificationCaptures` table and a `Wallets.packageName` association, plus the repository methods to insert captures (with de-duplication and default-wallet resolution), stream pending captures, confirm a capture into a real transaction, and dismiss one. Migration 4→5, non-destructive. Fully unit-tested against an in-memory DB.

---

## Scope — IN (do all of these)

### 1. Enums (append-only `textEnum`, per the `SourceType` convention)
Add to `domain.dart`, each with the mandatory append-only comment (stored by name; never reorder, remove, or rename):
- `CaptureDirection { income, expense }` — note: **income/expense only**, no transfer (ADR-0016). On confirm, `income → earning`, `expense → spending`.
- `ParseStatus { parsed, needsReview, unparsed }` — set by later slices; 5a just stores it.
- `CaptureStatus { pending, confirmed, dismissed }`.

### 2. `NotificationCaptures` table (ADR-0013)
Columns:
- `id` (UUID text, like other tables), `packageName` (text), `rawTitle` (text, nullable), `rawText` (text), `capturedAt` (datetime).
- Parsed fields (nullable, populated by later slices): `amount` (int, VND), `direction` (`CaptureDirection` textEnum), `parseStatus` (`ParseStatus` textEnum, default `unparsed`).
- Suggestions (nullable): `suggestedWalletId` (text), `suggestedCategory` (text).
- Lifecycle: `status` (`CaptureStatus` textEnum, default `pending`), `resultingTxnId` (text, nullable).
- `dedupHash` (text) — see item 4.

### 3. `Wallets.packageName` association (ADR-0014)
- Add nullable `packageName` (text) to `Wallets`.
- Add a **unique index** on `packageName` (SQLite allows multiple NULLs, so many wallets may have none, but at most one wallet is the default for a given package).
- No UI for setting it in this slice (that's 5d) — just the column, the index, and repository support.

### 4. Repository methods (pure Dart + Drift)
- **`insertCapture({packageName, rawTitle, rawText, capturedAt, ...optional parsed fields})`** — before inserting: compute `dedupHash` over `packageName` + normalized `rawText` (trim + collapse internal whitespace + lowercase — propose the exact normalization), and **skip/no-op if an equivalent capture exists within a short time window** (propose the window, e.g. a few minutes). On insert, **resolve `suggestedWalletId`** by looking up the wallet whose `packageName` matches (ADR-0014); leave null if none. Return the created capture (or an indication it was a dedup skip).
- **`watchPendingCaptures()`** — reactive stream of `status == pending`, newest first. Also a `pendingCaptureCount()` stream/int for a future badge.
- **`confirmCapture(captureId, {required walletId, required amount, required direction, category, starred})`** — atomically (`db.transaction`): create a transaction with **`source = bankNotification`, `affectsBalance = true`** (ADR-0009), `type` from direction (`income→earning`, `expense→spending`), the given wallet/amount/category/starred; then mark the capture `confirmed` and set `resultingTxnId`. The passed-in values override the stored proposal (the user may have edited them at confirm).
  - **Bank confirms bypass the overspend guard.** A bank notification records money that already moved; blocking the record because the *tracked* balance looks insufficient would be wrong and would drop real transactions. So `confirmCapture` must **not** throw `OverspendException` — it inserts regardless, letting the derived balance follow reality (even negative). This differs from manual `addSpending`/`addTransfer`, which keep their guard. (Flagging this as a deliberate semantic choice — see the note to the user.)
- **`dismissCapture(captureId)`** — mark `status = dismissed`; no transaction created.

### 5. Migration 4→5
Bump `schemaVersion` to 5. Non-destructive `onUpgrade` step: create the `NotificationCaptures` table, add `Wallets.packageName`, create the unique index. No existing data changes.

### 6. Tests (in-memory Drift DB)
- `insertCapture`: stores the row; resolves `suggestedWalletId` from a matching wallet `packageName`; leaves it null when no match.
- **Dedup:** a second equivalent capture within the window is skipped; the same text after the window, or different text, is not.
- **`confirmCapture`:** creates exactly one transaction with `source == bankNotification`, `affectsBalance == true`, correct `type` (income→earning, expense→spending), wallet, amount, category, starred; marks the capture `confirmed` with `resultingTxnId`; is atomic. Confirm an `expense` that exceeds tracked balance and assert it **succeeds** (no `OverspendException`) and the balance goes negative.
- `dismissCapture`: marks dismissed, creates no transaction.
- `watchPendingCaptures` / count: reflect inserts, confirms, dismissals.
- A migration test (4→5) that seeds a v4 DB, migrates, and asserts existing wallet balances are unchanged and the new table/column/index exist.

---

## Scope — OUT (do NOT do this pass)

- **No native / Kotlin** — no `NotificationListenerService`, no permissions, no Pigeon. That's 5c. This slice is exercised by calling repository methods directly in tests.
- **No parsers** — no `BankNotificationParser`, no registry, no per-bank logic, no `ParsedNotification` value object. That's 5b. 5a only stores parsed *fields* that later slices populate.
- **No UI** — no captures inbox, no review screen, no `packageName` picker, no notification actions. That's 5d.
- **No `CategorySuggester` wiring** — `suggestedCategory` is a stored column here; populating it is deferred.
- Do not change existing transaction writes, balance/analytics SQL, or `affectsBalance` semantics.

---

## Constraints
- Non-destructive migration; existing balances unchanged (a migration test proves it).
- `textEnum` for all new enums, append-only, matching the `SourceType` convention.
- `confirmCapture` is atomic and reuses the `source`/`affectsBalance` model rather than duplicating write logic.
- Incremental conventional commits (`feat:`, `test:`, `chore:`).
- `flutter analyze` clean; `flutter test` green; debug APK builds. Offline only.

## Before you code
1. Read `database.dart` (schema + current migration setup at v4), `finance_repository.dart` (how transactions are written with `source`/`affectsBalance`, and how the overspend guard is structured so you can bypass it cleanly for `confirmCapture`), and `domain.dart` (the `SourceType` textEnum pattern).
2. Propose: the `dedupHash` normalization and time window; the exact shape of `confirmCapture` (how it reuses vs. bypasses the existing write path and its overspend guard); and the migration step.
3. Flag anything that complicates a clean overspend-bypass for bank confirms, or the unique-index-with-nullable-packageName behavior, and ask before working around it.
4. Wait for confirmation, then implement commit by commit.

## Definition of done
- `NotificationCaptures` table and `Wallets.packageName` (+ unique index) exist; `schemaVersion == 5` with a non-destructive migration.
- Repository supports insert (with dedup + default-wallet resolution), watch-pending (+ count), confirm (atomic, `bankNotification`/`affectsBalance`, overspend-bypassed), and dismiss.
- Tests green, including the overspend-bypass case and the 4→5 migration balance-preservation check.
- `flutter analyze` clean, `flutter test` green, debug APK builds.
- A short summary per file, plus the dedup normalization/window and the `confirmCapture` overspend-bypass approach you used.
