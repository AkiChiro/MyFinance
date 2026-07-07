# Claude Code Task — MyFinance Phase 1: Foundation Refactor

> Paste this whole file into Claude Code as the task brief. **Read the "Scope" section carefully — the OUT-OF-SCOPE list is as important as the in-scope list.** Do not start coding until you have proposed a plan (see "Before you code").

---

## Project context

MyFinance is a personal, **offline, Android-first** finance tracker built in **Flutter** with a **Drift** (SQLite) database. Money is stored as **integer VND** (whole numbers, no floating point). It has four screens — Wallets (Ví), Transactions (Giao dịch), Analytics (Thống kê), Settings (Cài đặt) — plus a Quick Add form, all in Vietnamese. The app already works and is roughly feature-complete.

The current architecture is already layered: UI → `FinanceRepository` → `AppDatabase`. That layering is good and should be preserved. This task hardens the foundation so the app becomes testable and maintainable — it is **not** a rewrite and must **not** change what the app does from a user's point of view.

Relevant existing files:
- `lib/main.dart` — app entry, `MaterialApp`, and (the problem) three top-level global variables.
- `lib/repositories/finance_repository.dart` — all business logic, balance calc, transaction writes.
- `lib/data/database.dart` — Drift schema, migrations, category seeding.
- `lib/models/domain.dart` — enums + a static `Categories` label map (duplicates the seeded DB rows).
- `lib/services/` — `app_settings.dart` (ChangeNotifier over SharedPreferences), `category_suggester.dart`, `notification_service.dart`, `csv_service.dart`.
- `lib/ui/*.dart` — the screens, each currently reaching into `main.dart` for globals.
- `lib/format.dart` — pure money/date formatting functions.

---

## Goal of this task

Make the codebase **testable and decoupled** by replacing global-variable wiring with proper dependency injection, fix a small set of concrete correctness bugs found in review, and stand up a real test suite. When done, the app builds, `flutter analyze` is clean, tests pass, and a user notices **no behavioral difference**.

---

## Scope — IN (do all of these)

### 1. Dependency injection with Riverpod — remove the global singletons
`lib/main.dart` currently declares `late final FinanceRepository repository;`, `late final CategorySuggester suggester;`, and `late final AppSettings settings;` as top-level globals, and every screen imports them via `import '../main.dart' show repository`. This is the primary thing to fix.
- Add **`flutter_riverpod` 3.x** (current line is 3.3.x) and wrap the app in a `ProviderScope`. Do **not** pin to 2.x.
- Expose `AppDatabase`, `FinanceRepository`, `CategorySuggester`, and `AppSettings` as providers. `AppSettings` and the async `.load()`/`suggester.load()` initialization currently happening in `main()` must be handled through the provider graph (an initialization provider or `FutureProvider` is fine — propose your approach).
- **Riverpod 3.x note (this will bite you otherwise):** in Riverpod 3.x, `ChangeNotifierProvider` is legacy and was moved out of the main library. To keep `AppSettings` as a `ChangeNotifier` and expose it via `ChangeNotifierProvider` (which preserves the `notifyListeners()` → rebuild contract with a minimal diff), you **must** add `import 'package:flutter_riverpod/legacy.dart';` where that provider is declared. Plain `Provider<T>` and the `overrideWithValue` injection pattern are unaffected — they are first-class in 3.x.
- **Keep `AppSettings` as a `ChangeNotifier` this pass.** Do not migrate it to the modern `Notifier`/`AsyncNotifier` API now — that would rewrite every `settings.x = y` call site and is out of scope (it is a later Phase 6 cleanup, recorded in ADR-0012). The legacy `ChangeNotifierProvider` bridge is the deliberate, behavior-preserving choice for Phase 1.
- Convert screens to `ConsumerWidget` / `ConsumerStatefulWidget` and read dependencies via `ref` instead of the `main.dart` globals.
- Remove the top-level globals and the `show repository, settings, suggester` imports entirely.
- Keep `AppSettings` reactive: the theme/locale/currency must still rebuild the UI on change (today via `ListenableBuilder`). Preserve that behavior through the provider.

### 2. Fix silent error swallowing in `lib/ui/home_page.dart`
The widget-deep-link handling in `initState` is wrapped in `try { ... } catch (_) {}`, which eats all errors with no logging. This is almost certainly why the home-screen widget fails silently and can't be debugged. Replace the empty catch with real logging (`debugPrint` at minimum, or a small logging helper) so failures surface. Do **not** otherwise change the widget-handling logic in this pass — the native rewrite is a later phase.

### 3. One source of truth for categories
`lib/models/domain.dart` has a static `Categories.labels` / `defaultThresholds` map that duplicates the rows seeded into the `AppCategories` table in `database.dart`. This is a divergence hazard. Make the **database the single source of truth** for live category data. The static definitions may remain **only** as the seed source (referenced by `_seedCategories`) or as a minimal enum-key fallback for the null-DB edge case — but no screen should read labels/thresholds from the static map when live DB data is available. Audit every call site of `Categories.labels` / `Categories.label(...)` / `Categories.defaultThresholds` and route them through DB-backed data. List what you changed.

**Critical distinction — rendering vs. selection (do not conflate these):**
- **Selection** (category picker dropdowns in Quick Add, keyword editor, etc.) uses **active** categories only — the existing `watchActiveCategories(kind)` / `activeCategories(kind)`, which filter out archived rows. Correct as-is.
- **Rendering** a category label on a historical transaction or in the analytics pie must draw from **all** categories, **including archived ones**. Soft-delete (archiving) is a real scenario: a *user-created* category (a uuid id) that gets archived is in neither the active-category stream nor the static `Categories.labels` map, so `catLabels[id] ?? Categories.label(id)` would render the raw uuid. To prevent that, add a **`watchAllCategories()`** stream (and/or `allCategories()` future) to `database.dart` that has **no `archived` filter**, and build the label map for rendering from that. Keep the active-only queries for pickers. The current call sites to fix are `Categories.label(txn.category)` in `transactions_page.dart` (lines ~146, ~150) and `Categories.label(e.key)` in `analytics_page.dart` (line ~596).

### 4. Atomicity for multi-step writes
In `finance_repository.dart`, `addSpending`, `addTransfer`, and `updateTxn` perform an overspend check (`_assertSufficient`, which reads the DB) followed by a separate write. Wrap each of these operations in `db.transaction(() async { ... })` so the check-and-write is atomic. Behavior for the user is unchanged; this just closes a race window that matters for a finance app.

### 5. Test suite
Standing up tests is the payoff of the DI work — prioritize it, don't skip it. Add unit tests under `test/`:
- `balanceOf` in `FinanceRepository` — cash/bank, spending/earning/transfer, the `imported` exclusion, multi-wallet transfers.
- `isAutoStarred` — enabled/disabled, threshold boundaries, type/imported/transfer exclusions.
- `format.dart` — `formatMoney`, `formatSigned`, `parseAmount` (including grouping-character stripping).
- `CategorySuggester.suggest` — weighted scoring, type filtering, fallback when no rule matches.
- The overspend path — `addSpending`/`addTransfer` throw `OverspendException` past available balance (use an in-memory Drift DB — `NativeDatabase.memory()`).
Add `flutter_test` targets and make sure `flutter test` runs green.

**Required refactor to make `CategorySuggester` testable:** as written, `CategorySuggester` has **no seam to inject rules** — `_rules`, `_Rule`, and `_parseRaw` are all private, and the only public entry points are `load()` (reads a bundled asset / documents-dir file) and `saveAndReload()` (writes to the documents dir). Both require Flutter binding and platform-channel mocking, so `suggest()` cannot be a pure unit test without a seam. Add a `@visibleForTesting` factory or named constructor that accepts a rule list (or raw JSON) and populates `_rules` **without any file I/O** — e.g. extract the pure "parse + assign" step out of `saveAndReload` into a shared private method that both `saveAndReload` and the test seam call. The `suggest` test then constructs a suggester with known rules directly. This is exactly the kind of make-it-testable change this phase exists for; do it rather than working around it with binding mocks.

---

## Scope — OUT (do NOT touch this pass; each is a later, separate task)

- **The native / Kotlin layer** — `notification_service.dart`, the `home_widget` wiring, `MainActivity.kt`, `WidgetProvider.kt`, `BootReceiver.kt`, permissions. This gets rebuilt properly in a dedicated phase. Leave it exactly as-is aside from the logging fix in item 2.
- **Moving balance/analytics into SQL aggregate queries.** `balanceOf`, `categoryTotals`, `monthTotal`, `yearTotal` stay as Dart-side logic for now — do not rewrite them into `GROUP BY`/`SUM` queries this pass. (They are already testable as-is, which is what this phase needs.) The SQL migration is Phase 3.
- **The bank-notification auto-input feature** and any wallet↔bank-app association / schema changes for it. Later phase.
- **New features** — English UI localization, CSV export for wallets, the currency-label consistency cleanup. Later phase.
- Do not restyle or redesign any screen. Visual output must be unchanged.

---

## Constraints

- **Behavior parity:** the app must build and behave identically from the user's perspective. This is a refactor.
- **Minimal diff for logic:** do not rewrite working business logic just to move it. Move it into DI, don't reimplement it.
- **Incremental, conventional commits:** small, reviewable commits using conventional-commit style (`refactor:`, `fix:`, `test:`, `chore:`). Not one giant commit.
- **Clean gates:** `flutter analyze` reports no new issues; `flutter test` passes; `flutter build apk --debug` succeeds.
- Keep everything offline. No new network dependencies.

---

## Before you code

1. Read the files listed above and confirm your understanding of the current wiring.
2. Propose a short plan: which provider approach you'll use, the order of commits, and any place where DI forces a non-obvious change (e.g. how you'll handle the async settings/suggester load, and how `navigatorKey` in `notification_service.dart` interacts with the refactor).
3. Flag anything in the current code that would make behavior parity hard, and ask before working around it.
4. Wait for confirmation, then implement commit by commit.

## Definition of done

- `flutter_riverpod` 3.x is used; no top-level global variables remain in `main.dart`; no screen imports dependencies from `main.dart`. `AppSettings` is exposed via `ChangeNotifierProvider` with the `legacy.dart` import and is otherwise unchanged.
- The empty `catch (_) {}` in `home_page.dart` is gone; failures are logged.
- Category labels/thresholds have a single source of truth (the DB for live data), and **label rendering resolves archived categories** (no raw uuids shown for archived custom categories) via a no-archived-filter query, while pickers still use active-only.
- `CategorySuggester` has a `@visibleForTesting` seam to inject rules without file I/O.
- `addSpending`, `addTransfer`, `updateTxn` are wrapped in DB transactions.
- `test/` contains the tests listed above (including `CategorySuggester.suggest` via the new seam) and `flutter test` is green.
- `flutter analyze` clean; debug APK builds.
- A short summary of what changed, per file, and the list of category call-sites you rerouted.
