# Claude Code Task — MyFinance Phase 3: Transaction Provenance & Balance-Participation Model

> Paste this whole file into Claude Code as the task brief. This is a **money-critical schema migration** — the migration test is a hard gate, not optional. Do not start coding until you have proposed a plan (see "Before you code"). Reference: **ADR-0009** in `MyFinance_ADR.md`.

---

## Project context

MyFinance is an offline, Android-first Flutter finance tracker using **Drift** (SQLite). Money is integer VND. Phase 1 is complete: Riverpod DI, all screens on `ConsumerWidget`, 38 passing tests, a `CategorySuggester.fromRules()` test seam, and DB writes wrapped in transactions.

Balances are **derived, not stored** (ADR-0004): a wallet's balance is `initialBalance` plus a replay of its transactions. Today, `FinanceRepository.balanceOf` excludes transactions flagged `imported == true` via `if (t.imported) continue;`.

**The problem this task fixes (ADR-0009):** the single `imported` boolean conflates two orthogonal facts — *where a transaction came from* and *whether it moves the wallet balance*. The upcoming bank-notification feature will create transactions that are external in origin **but must move the balance**, which the current flag cannot express. This task splits the one flag into two fields. It does **not** build the bank feature — only prepares the data model it depends on.

Relevant files: `lib/data/database.dart` (Drift schema, `schemaVersion`, migrations), `lib/repositories/finance_repository.dart` (`balanceOf`, `_assertSufficient`, writes), `lib/services/csv_service.dart` (CSV import/export), `lib/models/domain.dart` (enums), the CSV import UI (in settings), and `test/`.

---

## Goal

Replace the `imported` boolean with two orthogonal fields — a `source` provenance enum and an `affectsBalance` boolean — migrate existing data with **exact balance preservation**, update `balanceOf` to use `affectsBalance`, and give CSV import a per-import choice of how it interacts with balance. When done, every pre-existing wallet shows an identical balance to before, and the model is ready for the bank feature to plug into.

---

## Scope — IN (do all of these)

### 1. Schema: two new fields on the transactions table
- Add **`source`** — a persisted enum with values `manual`, `csvImport`, `bankNotification` (declare all three now even though the bank feature isn't built; the value must exist so the model is complete). Provenance metadata only.
- Add **`affectsBalance`** — a boolean; the single input to the balance rule.
- **Enum persistence must be reorder-safe.** If you use Drift's `intEnum`, the enum's declaration order becomes the on-disk encoding, so reordering/removing a value silently corrupts data — if you go that route, document that `SourceType` is append-only. I'd recommend **`textEnum<SourceType>()`** instead (stores the value name, reorder-proof, self-documenting in the DB; the size cost is negligible). Propose which you'll use and why.

### 2. Migration with exact balance preservation
- Bump `schemaVersion` and add an `onUpgrade`/step that adds the two columns and **backfills** from the old flag:
  - `imported == true`  → `source = csvImport`, `affectsBalance = false`
  - `imported == false` → `source = manual`,    `affectsBalance = true`
- Decide and justify what happens to the old `imported` column. Physically dropping a column requires a recent SQLite (`DROP COLUMN` needs SQLite ≥ 3.35; `sqlite3_flutter_libs` bundles a newer build, so it's available) or a table-recreation migration. Prefer the **least destructive** path consistent with a clean schema — propose whether you drop it or retain it, and optionally keep a computed Dart getter `imported => source != SourceType.manual` to reduce call-site churn. Whatever you choose, the migration must not lose or alter any existing row's contribution to its wallet balance.

### 3. `balanceOf` uses `affectsBalance`
Replace `if (t.imported) continue;` with the `affectsBalance` check (sum amounts where `affectsBalance == true`). Behaviorally identical for all existing data after backfill — the migration test proves it.

### 4. CSV import: per-import balance choice
Per ADR-0009, the user chooses per import between two modes:
- **Context-only** — imported rows get `source = csvImport`, `affectsBalance = false`; the target wallet's `initialBalance` is untouched. (This reproduces today's behavior and should be the default.)
- **Reconstruct-balance** — imported rows get `source = csvImport`, `affectsBalance = true`; the import represents the wallet's transaction history.
- **Guard the double-count trap:** reconstruct mode into a wallet that already has `affectsBalance` transactions will double-count, because that wallet's `initialBalance` already reflects reality. Reconstruct mode must therefore either require a fresh/empty wallet or set the wallet's opening `initialBalance` as part of the import, and must **warn/block** when reconstructing into a non-empty wallet rather than silently producing a wrong balance.
- Update `csv_service.dart` and the CSV import UI to surface this choice.

### 5. Tests
- **Migration test (mandatory gate).** Use Drift's schema-test tooling rather than hand-rolling: `dart run drift_dev schema dump` to snapshot the pre-change schema, then `schema generate` to produce migration-test helpers, then a test that builds a database at the **old** version, seeds representative rows (mix of `imported` true/false across cash and bank wallets, including transfers), runs the migration, and **asserts every wallet's balance is unchanged** and the backfilled `source`/`affectsBalance` values are correct. If schema tooling setup is impractical, state why and use an equivalent explicit old-schema-seed-then-migrate test — but the balance-preservation assertion is non-negotiable.
- `balanceOf` tests updated for the `affectsBalance` filter (bank-source rows with `affectsBalance = true` count; context-only rows don't).
- CSV import mode tests: context-only leaves balance unchanged; reconstruct-balance produces the expected total; the non-empty-wallet reconstruct guard triggers.

---

## Scope — OUT (do NOT build this pass)

- **The bank-notification feature itself** — no `NotificationListenerService`, no parsers, no `Wallets.packageName`, no capture/pending model. This task only adds the `bankNotification` enum value so the model is complete. Everything else is Phase 5.
- **Moving balance/analytics into SQL aggregates** (ADR-0005) — that's Phase 4. Keep `balanceOf` and analytics as Dart-side logic here; only change the *filter*, not the *location*.
- Any native/Kotlin changes.
- Analytics behavior: analytics continues to count **all** real transactions regardless of `affectsBalance` (ADR-0009 — balance vs. analytics are independent). Do not add an `affectsBalance` filter to analytics.

---

## Constraints

- **Exact balance preservation** for all existing data — this is the whole point; the migration test proves it.
- **Least-destructive migration** consistent with a clean schema.
- Incremental, conventional commits (`feat:`, `refactor:`, `test:`, `chore:`).
- `flutter analyze` clean (the repo is currently clean — keep it that way); `flutter test` green; debug APK builds.
- Keep everything offline.

## Before you code
1. Read `database.dart` (current `schemaVersion` and migration setup), `finance_repository.dart` (`balanceOf`, writes), `csv_service.dart`, and the CSV import UI.
2. Propose: enum persistence choice (`textEnum` vs `intEnum`) with rationale; the migration mechanism and what happens to the `imported` column; the CSV import-mode UI change; and how you'll structure the migration test (schema tooling vs explicit seed).
3. Flag anything that complicates exact balance preservation (e.g. existing rows with unexpected `imported`/type combinations) and ask before working around it.
4. Wait for confirmation, then implement commit by commit.

## Definition of done
- Transactions table has `source` (reorder-safe enum incl. `bankNotification`) and `affectsBalance`; `imported` handled per your justified proposal.
- Migration backfills existing data and a test proves **every wallet balance is unchanged** post-migration.
- `balanceOf` filters on `affectsBalance`.
- CSV import offers context-only vs reconstruct-balance, with the non-empty-wallet reconstruct guard.
- Analytics still counts all transactions (unchanged).
- `flutter analyze` clean, `flutter test` green, debug APK builds.
- A short summary of what changed per file, the enum-persistence decision, and the `imported`-column decision.
