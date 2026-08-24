# MyFinance — Claude Project Context

## Project identity

Offline Vietnamese-language Android personal finance tracker (VND integers only). Single user (Huy). Flutter/Dart, SQLite via Drift ORM, no cloud dependency.

- **Working dir:** `e:\User\Personal\AI\MyFinance`
- **Active branch:** `V0.2-Improve`
- **Language:** UI strings in Vietnamese; all code and comments in English

---

## Architecture

```
UI            lib/ui/                ConsumerWidget / ConsumerStatefulWidget + StreamBuilder
Repository    lib/repositories/      FinanceRepository — all writes, overspend guard, dedup
Data          lib/data/database.dart Drift ORM, migrations, raw SQL queries
Services      lib/services/          AppSettings, CaptureService, CategorySuggester, CsvService, NotificationService
Native        android_overlay/       Kotlin: BankCaptureService, CaptureChannelApi (Pigeon), BootReceiver, WidgetProvider
```

**Hard rules:**
- No direct DB access from UI — always call through `FinanceRepository`
- No business logic in widgets
- Cross-widget state → Riverpod provider; widget-local state → `setState`

---

## Tech stack

| | |
|---|---|
| Flutter / Dart | Android target, min SDK 21 |
| Drift 2.29.0 | DateTime stored as **Unix seconds** (`millisecondsSinceEpoch ~/ 1000`) |
| Riverpod 3.x | `StateProvider`, `StreamProvider`; `ChangeNotifierProvider` from `flutter_riverpod/legacy.dart` |
| Pigeon v22 | Typed Dart↔Kotlin channel defined in `pigeons/capture_channel.dart` |
| fl_chart, home_widget, flutter_local_notifications, share_plus, uuid, intl | |

---

## Database schema (v9)

### `wallets`
| Column | Type | Notes |
|--------|------|-------|
| id | TEXT PK | UUID v4 |
| name | TEXT | |
| initial_balance | INT | VND |
| type | TEXT | `'cash'` / `'bank'` |
| package_name | TEXT? | linked bank app package |
| sort_order | INT | user drag order |
| balance_cutoff_at | INT? | Unix seconds; when set, only txns at/after this timestamp affect this wallet's balance |

### `txns`
id, type (`spending`/`earning`/`transfer`), amount (VND positive), description?, wallet_id, wallet_to_id?, category?, timestamp, created_at, imported, **starred**, wallet_from_name?, wallet_to_name?, source (`manual`/`csvImport`/`bankNotification`), **affects_balance**

### `notification_captures`
Deferred capture inbox — see `docs/architecture.md` for full schema.

### `app_categories`
id, label, kind (`spending`/`earning`), threshold (VND auto-star limit), is_default, archived, sort_order, **envelope_cutoff_at** (Unix seconds?; per-category envelope reset, mirrors wallets.balance_cutoff_at)

### `category_budget_history`
Append-only envelope-budgeting percent history: id, category_id, percent (0-100), effective_from (Unix seconds). New row per edit, never mutated — see Budget invariants below.

### Migration rules
- **Additive only** — `ALTER TABLE ADD COLUMN`, never DROP or RENAME
- Increment `schemaVersion`, add `if (from < N)` block in `onUpgrade`
- New columns need raw SQL until `make apk` regenerates `database.g.dart`

---

## Drift gotchas

- **`customStatement()` is invisible to Drift's change tracker.** After any raw SQL write, call `markTablesUpdated({tableRef})` inside the same transaction, or reactive streams (`customSelect().watch()`) will never re-emit.
- **New columns before codegen:** use `customSelect('SELECT col FROM ...')` + `row.readNullable<T>('col')` for reads; `customStatement('UPDATE ... SET col = ?')` for writes. Typed accessors (`WalletsCompanion(col: Value(...))`) only work after `make apk`.
- **Typed row construction from raw query:** `$WalletsTable.map(row.data)` builds a typed `Wallet` from `QueryRow.data` — works before and after regeneration.
- **`ChangeNotifierProvider`** must be imported from `flutter_riverpod/legacy.dart` (removed from top-level in Riverpod 3.x).

---

## Balance invariants

- Balance is **derived, never stored** — SQL UNION ALL pattern, `initial_balance + SUM(signed deltas)`.
- Only `affects_balance=1` rows count toward balance (CSV context-only imports have `affects_balance=0`).
- `balance_cutoff_at` per wallet: only txns with `timestamp >= cutoff` are included. Resetting wallet A's initial balance sets its own cutoff — does **not** affect wallet B's view of shared transfer rows.
- **Analytics ignores `affects_balance`** — all non-transfer txns appear in totals regardless of balance reset.

---

## Budget (envelope) invariants

- Envelope balance is **derived, never stored** — same philosophy as balance (ADR-0004), applied to `category_budget_history` + `txns`. `addSpending`/`addEarning`/`updateTxn`/`deleteTxn`/`confirmCapture` need zero envelope-specific code.
- `category_budget_history` is **append-only** — a % edit inserts a new row (`effectiveFrom = now`), never updates one. Reads take the row with the largest `effectiveFrom <= ` a given earning's own timestamp ("as-of" join), so a % change is **never retroactive**.
- Only `type='earning'`/`'spending'` rows with `affects_balance=1` participate. Unlike analytics, envelopes **do** filter on `affects_balance` (they track real money only).
- Overspending an envelope is informational only — never blocks a write (contrast with `OverspendException`/wallet balance).
- `FinanceRepository.setCategoryBudgetPercent` blocks only if the new sum across **active** spending categories would exceed 100% (`BudgetPercentExceededException`) — summing to less than 100% is allowed.
- `FinanceRepository.resetEnvelope(categoryId)` sets that category's own `envelope_cutoff_at` to now — mirrors `balance_cutoff_at`, but **per-category**: resetting one category's envelope never affects another's. No validation guard (unlike the 100% sum check above) — a cutoff write can't violate any other row's invariant.

---

## Riverpod providers (`lib/providers.dart`)

```
dbProvider                Provider<AppDatabase>
repositoryProvider        Provider<FinanceRepository>
suggesterProvider         Provider<CategorySuggester>
captureServiceProvider    Provider<CaptureService>
settingsProvider          ChangeNotifierProvider<AppSettings>   ← legacy.dart import required
monthModeProvider         StateProvider<bool>                   ← Giao dịch tab month filter toggle
selectedMonthProvider     StateProvider<DateTime>               ← month shown in month-filter mode
```

---

## Build commands

```
make init    # first-time: patches android/, runs codegen
make apk     # make gen + flutter build apk --release
make gen     # pigeon codegen + drift build_runner
```

Run `make apk` after **any** schema or Pigeon change before using typed accessors.

---

## Always-do rules

| Rule | Reason |
|------|--------|
| Update all relevant `docs/` files after every change | Explicitly requested — every session |
| `markTablesUpdated({table})` after every `customStatement` write | Raw SQL bypasses Drift's reactive stream |
| Migrations are additive only (`ALTER TABLE ADD COLUMN`) | Protects existing device data on upgrade |
| No comments unless the WHY is non-obvious | Identifiers explain what; comments explain why |
| No abstractions beyond what the task requires | Avoid premature complexity |
| No error handling for impossible scenarios | Trust Drift/framework; validate only at system boundaries |
| Balance is derived, never stored | ADR-0004 |
| Analytics does not filter on `affects_balance` | Balance reset should not suppress old totals in charts |

---

## Docs map — what to update per change type

| Change | Update |
|--------|--------|
| Schema column added/changed | `docs/architecture.md` — wallets/txns table |
| Provider added | `docs/architecture.md` — Riverpod providers table |
| Ví tab UI or wallet logic | `docs/tab_wallets.md` |
| Giao dịch tab | `docs/tab_transactions.md` |
| Thống kê tab | `docs/tab_analytics.md` |
| Cài đặt tab | `docs/tab_settings.md` |
| Analytics computation change | `docs/architecture.md` — Analytics computation section |
| Budget (envelope) UI or computation change | `docs/tab_analytics.md`, `docs/architecture.md` — Envelope budgeting section |
| Any session of work | `docs/history.md` — append new session section |
| Architectural decision | `docs/MyFinance_ADR.md` |

For workflow recipes (schema change checklist, new screen steps, debug balance, etc.) see `docs/claude/skill.md`.
