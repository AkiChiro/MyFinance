# Claude Code Task — MyFinance Phase 4: Move Balance & Analytics into SQL Aggregates

> Paste this whole file into Claude Code as the task brief. The core requirement is **exact numerical equivalence** with the current behavior — the equivalence tests are a hard gate. Do not start coding until you have proposed a plan (see "Before you code"). Reference: **ADR-0004** (balance is derived), **ADR-0005** (this task), **ADR-0009** (`affectsBalance` predicate).

---

## Project context

MyFinance is an offline, Android-first Flutter finance tracker using **Drift** (SQLite). Money is integer VND. Phases 1 and 3 are complete: Riverpod DI, the `imported` flag split into `source` + `affectsBalance`, and balance/analytics already filter on `affectsBalance == true` (44 tests green).

Balances are **derived, not stored** (ADR-0004): a wallet's balance is `initialBalance` plus the signed contribution of its `affectsBalance` transactions. Today that derivation, and the analytics aggregations, happen **in Dart by fetching rows and folding** — which doesn't scale and puts computation in the wrong layer. This phase moves them into SQL. It changes *where* the numbers are computed, **not** what they are.

Current shape (in `lib/repositories/finance_repository.dart` and `lib/data/database.dart`):
- `int balanceOf(Wallet w, List<Txn> txns)` — pure Dart. Starts at `w.initialBalance`; skips `!t.affectsBalance`; then by type: **earning** `walletId == w.id → += amount`; **spending** `walletId == w.id → -= amount`; **transfer** `walletId == w.id → -= amount` and `walletToId == w.id → += amount`.
- `_balance(walletId, {excludeId})` — fetches `nativeTxns()` (which filters `affectsBalance.equals(true)`) and calls `balanceOf`, optionally excluding one transaction id. Used by the overspend checks in `addSpending` / `addTransfer` / `updateTxn`.
- `categoryTotals(txType, month)`, `monthTotal(txType, month)`, `yearTotal(txType, year)` — fetch `nativeTxns()` and fold in Dart, filtering by `type` and by `timestamp` year/month (in **local** time), grouping by category.
- `wallets_page.dart` streams `watchTxns()` (all rows) and calls `balanceOf` **per wallet** on every rebuild → O(wallets × transactions). `analytics_page.dart` streams `watchTxns()` and folds with its own `if (!t.affectsBalance) continue;`.

---

## Goal

Compute wallet balances and analytics totals with SQL `SUM`/`GROUP BY` aggregates (reactive `.watch()` queries for the UI, one-shot for imperative checks), filtered on `affectsBalance == true`, producing **byte-for-byte the same numbers** the current Dart code produces. Retire the per-wallet Dart fold from `wallets_page` and the Dart analytics folding, backed by equivalence tests that prove the SQL matches the old Dart logic.

---

## Scope — IN (do all of these)

### 1. SQL balance queries
- A query returning **each wallet's derived balance** = `initialBalance` + signed sum of its `affectsBalance` transactions, plus a single-wallet variant and a variant that can **exclude one transaction id** (for the overspend check's `excludeId`).
- Provide a **reactive `.watch()`** version for the UI (wallet list / total balance) and a one-shot version for the overspend checks.
- The two structural gotchas to handle carefully:
  - **Transfers have a dual role** — the same row subtracts from `walletId` and adds to `walletToId`. A plain `GROUP BY walletId` misses the incoming side. Decompose into signed contributions (e.g. a `UNION ALL` of earning `+amount`/spending `-amount`/transfer-out `-amount` keyed on `walletId` and transfer-in `+amount` keyed on `walletToId`, then group+sum), or an equivalent conditional aggregation. Propose your approach.
  - **`excludeId`** — the overspend path checks the balance as if a given transaction weren't there; the SQL must support omitting one id.
- Total-balance-across-wallets should come from the same aggregate (or be summed from the per-wallet result — cheap and fine).

### 2. SQL analytics queries
- `categoryTotals` → `SELECT category, SUM(amount) ... WHERE type = ? AND affectsBalance = true AND <period> GROUP BY category`. `monthTotal` / `yearTotal` → `SUM` over the period.
- **Preserve the exact date semantics.** The current Dart filters by `timestamp.year` / `.month` in **local time**. Do not reintroduce this as `strftime` on a stored UTC value — that can shift rows across month boundaries. Compute the period boundaries in Dart (local start-of-month/next-month, or start/end-of-year) and filter with a half-open range `timestamp >= start AND timestamp < end`. Confirm how the `timestamp` column is stored and match the semantics precisely.
- Provide `.watch()` variants so charts stay reactive.

### 3. Wire the UI and checks to the SQL paths
- `wallets_page.dart`: replace the `watchTxns()` + per-wallet `balanceOf` fold with the reactive balance query (e.g. `watchWalletBalances()`), surfaced through a Riverpod provider.
- `analytics_page.dart`: replace the Dart folding (including its `if (!t.affectsBalance) continue;`) with the SQL-backed totals.
- Overspend checks (`addSpending` / `addTransfer` / `updateTxn`): use the one-shot SQL balance (with `excludeId`) instead of `nativeTxns()` + `balanceOf`.
- **Leave transaction *listing* alone.** `watchTxns()` legitimately returns all rows for the transaction list — only the balance/analytics *folding* moves to SQL, not row listing.

### 4. Indexes
Add the indexes the aggregates need — at minimum on `walletId`, `walletToId`, `timestamp`, and `type` (and `affectsBalance` where it helps). Bump `schemaVersion` with a migration that creates them. Indexes only — no data changes.

### 5. Keep `balanceOf` as the equivalence oracle
Do **not** delete the Dart `balanceOf` — retain it (as `@visibleForTesting` if it's no longer called in app code) so the equivalence tests can compare SQL output against the original Dart logic over the same data.

### 6. Equivalence tests (hard gate)
Using an in-memory Drift DB (`NativeDatabase.memory()`):
- **Balance equivalence:** over representative *and* randomized transaction sets (multiple wallets; earning/spending/transfer; a `walletToId` transfer chain; a mix of `affectsBalance` true/false; the `excludeId` case; empty wallets), assert the SQL balance equals the Dart `balanceOf` for every wallet. Random-data equivalence is the strongest signal here — seed a few hundred random rows and assert equality.
- **Analytics equivalence:** assert SQL `categoryTotals` / `monthTotal` / `yearTotal` equal the old Dart results, including **month/year boundary rows** (a transaction at 23:59 on the last day of a month, one at 00:00 on the first) to prove the local-time range filter matches the old `.year`/`.month` behavior.

---

## Scope — OUT (do NOT do this pass)

- **The bank feature** (Phase 5) — no capture table, parsers, `packageName`, or native changes.
- **No change to `affectsBalance` semantics** — Phase 3 locked them; this task only relocates computation.
- **No change to transaction listing** — `watchTxns()` stays as the list source.
- No model/schema changes beyond the indexes in item 4.
- Do not restyle screens; the numbers and their meaning must be identical.

---

## Constraints

- **Exact numerical equivalence** with current behavior for every wallet balance and every analytics total — the equivalence tests prove it. This is the whole point.
- **Date semantics preserved** (local-time month/year boundaries).
- Incremental, conventional commits (`perf:`, `refactor:`, `test:`, `feat:` for the queries, `chore:` for indexes).
- `flutter analyze` clean (repo is currently clean — keep it that way); `flutter test` green; debug APK builds.
- Offline only.

## Before you code
1. Read the balance and analytics methods in `finance_repository.dart`, `nativeTxns()`/`watchTxns()` in `database.dart`, and the balance/analytics reads in `wallets_page.dart` and `analytics_page.dart`.
2. Confirm how the `timestamp` column is stored (unix int vs ISO text) so the range filter matches local-time semantics exactly.
3. Propose: the balance-aggregation approach (how you handle the transfer dual-role and `excludeId`); the analytics period-range approach; the reactive-vs-one-shot split; the indexes; and how you'll structure the equivalence tests (including random-data generation).
4. Flag anything that could make SQL diverge from the Dart result (e.g. NULL categories, `coalesce` on empty sums, integer overflow expectations) and ask before working around it.
5. Wait for confirmation, then implement commit by commit.

## Definition of done
- Wallet balances and total balance come from a reactive SQL aggregate; `wallets_page` no longer folds all transactions per wallet.
- `categoryTotals` / `monthTotal` / `yearTotal` are SQL `GROUP BY`/`SUM` with the local-time range filter; `analytics_page` no longer folds in Dart.
- Overspend checks use the one-shot SQL balance with `excludeId`.
- Indexes added via a `schemaVersion` migration.
- Dart `balanceOf` retained as the test oracle.
- Equivalence tests green: SQL == Dart `balanceOf` over representative and random data; SQL analytics == old Dart analytics including boundary rows.
- `flutter analyze` clean, `flutter test` green, debug APK builds.
- A short summary per file, the balance-aggregation approach you chose, and the timestamp-storage/date-range decision.
