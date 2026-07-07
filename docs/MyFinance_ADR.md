# MyFinance — Architecture Decision Records

A running log of architectural decisions for the MyFinance remake. Each entry records the *context* and *reasoning*, not just the choice, so future-you (and any reviewer) can see why things are the way they are. Newest decisions can be appended at the bottom. Statuses: **Accepted** (decided), **Proposed** (leaning this way, not locked), **Superseded** (replaced by a later ADR).

Format per entry: Status · Context · Decision · Consequences.

---

## ADR-0001 — Android-first; drop iOS support

**Status:** Accepted

**Context:** The app's headline feature is reading incoming bank notifications (e.g. OCB, MB, Techcombank) and pre-filling a transaction. On Android this is possible via a `NotificationListenerService`. On iOS it is fundamentally impossible — Apple sandboxes notifications per-app, and there is no API for one app to read another app's notifications. The existing native code (`MainActivity.kt`, `WidgetProvider.kt`, `BootReceiver.kt`) is already Android-only Kotlin; there is no iOS implementation.

**Decision:** Target Android only. The bank-notification feature is the priority and it dictates the platform. Do not spend effort keeping an iOS path open.

**Consequences:** No App Store distribution; iPhone users cannot use the app. In exchange, design is simpler (no cross-platform compromises around a feature that can only exist on one platform), and the native layer has a single clear target.

---

## ADR-0002 — Keep Flutter; own the native layer in Kotlin via typed platform channels

**Status:** Accepted

**Context:** The painful, flaky parts of the app (persistent/lock-screen notification, home-screen widget, permissions, and the future notification-listener) are all native Android concerns currently routed through third-party Flutter plugins (`flutter_local_notifications`, `home_widget`). The code is full of OEM workarounds (e.g. re-posting the notification on tap to fight Vivo OriginOS dismissing it) and a fragile widget data-passing chain (WidgetProvider → SharedPreferences → Flutter). A full rewrite to native Kotlin was considered but would discard a ~90% working, already-layered Flutter app to re-tread solved ground.

**Decision:** Keep the Flutter app (UI, database, business logic stay in Dart). Rebuild only the genuinely-native slice — notification listener, App Widget, inline-input notification (`RemoteInput`), permission routing — as first-party Kotlin the project owns, bridged to Dart. Use **Pigeon** to generate type-safe channel bindings rather than hand-rolled `MethodChannel` string keys.

**Consequences:** A small amount of maintained Kotlin alongside Dart, and a platform-channel learning curve — far smaller than a full rewrite. Pigeon's compile-time-checked contract eliminates the silent-failure mode of the current string-keyed handoff. Strong portfolio narrative ("bridged Flutter to a native Kotlin notification-listener service").

---

## ADR-0003 — Dependency injection via Riverpod; remove global singletons

**Status:** Accepted

**Context:** `main.dart` declares `repository`, `suggester`, and `settings` as top-level global variables, imported across every screen via `import '../main.dart' show ...`. This is the single biggest maintainability smell: it makes the code untestable (no way to inject fakes — hence zero existing tests), couples every screen to `main.dart`, and is a hidden global at app scale (ironically, `format.dart` deliberately avoids hidden globals by taking parameters).

**Decision:** Introduce Riverpod. Expose the database, repository, suggester, and settings as providers; screens read them via `ref`. Remove the top-level globals.

**Consequences:** Unlocks unit testing and screen isolation. Small upfront refactor touching every screen, but behavior-preserving. Chosen over `get_it` because Riverpod also formalizes the currently ad-hoc `StreamBuilder` + `setState` view-state pattern.

---

## ADR-0004 — Balance is derived, not stored

**Status:** Accepted

**Context:** Wallet balance is computed as `initialBalance` plus a replay of all that wallet's transactions (`balanceOf`), rather than kept as a stored, mutated field. The alternative — a stored balance updated on each write — risks drifting out of sync with transaction history, which is unacceptable for a finance app.

**Decision:** Keep balance derived from transaction history (lightweight event-sourcing). Never store a mutable balance.

**Consequences:** Balance and history can never disagree. The naive derivation is O(transactions) and is currently recomputed in the UI — see ADR-0005 for the performance fix, which changes *where* it's computed, not this principle.

---

## ADR-0005 — Move aggregation and balance computation into SQL

**Status:** Accepted (implementation deferred to a later phase)

**Context:** `balanceOf` is called inside `wallets_page`'s `build`, looping all transactions per wallet (O(wallets × transactions) per rebuild). Analytics (`categoryTotals`, `monthTotal`, `yearTotal`) fetch *all* transactions via `nativeTxns()` and filter/sum in Dart. This works at small scale but degrades as transactions grow, and it puts aggregation logic in the wrong layer.

**Decision:** Push aggregation into Drift as typed queries (`SUM`, `GROUP BY`, `WHERE` on month) in the data layer. The UI requests computed results, not the raw transaction table. This preserves ADR-0004's derived-balance principle — only the computation location changes (Dart-in-widget → SQL).

**Consequences:** Better performance and correct layering. Deferred until after the DI/test foundation (ADR-0003) so tests can guard the behavior change.

---

## ADR-0006 — Bank-notification parsing: native captures raw, Dart parses, user confirms

**Status:** Accepted

**Context:** Reading bank notifications requires a native `NotificationListenerService`, which yields the posting app's package name and the notification text. Bank message formats vary per bank and change over time — this is the most volatile logic in the app. It runs when the Flutter engine may be dead.

**Decision:** The native service stays "dumb": it captures the raw `{packageName, text, timestamp}` and stores it (and may post a heads-up). All parsing — extracting amount and direction — happens in **Dart**, where it can be unit-tested against sample strings. Parsing never silently files a transaction; it *proposes* a pre-filled entry the user confirms. This mirrors the existing `CategorySuggester` philosophy (suggest, never file silently, so a wrong guess can't corrupt the charts).

**Consequences:** The changeable parsing logic lives where testing is easy. Robust against the engine being dead in the background. Confirm-don't-auto-insert is more trustworthy for a finance app and avoids fragile background writes. Requires a modest capture/queue mechanism on the native side.

---

## ADR-0007 — Per-bank parsers as a Strategy pattern, keyed by package name; wallet↔bank association

**Status:** Accepted

**Context:** Following ADR-0006, parsing must handle many bank formats and grow over time. A monolithic if/else over bank formats would rot.

**Decision:** One parser per bank implementing a common interface (Strategy pattern), selected from a registry keyed on the notifying app's package name. Add a `packageName` field to the `Wallets` table so a wallet is associated with a bank app; the incoming package both selects the parser and pre-selects the target wallet. Adding a bank = add one parser class + register it + add its test cases.

**Consequences:** Clean, testable extension point (consistent with Strategy usage elsewhere in the author's projects). Requires a schema migration to add `packageName` to `Wallets`. See ADR-0009 for the interaction with the `imported` flag.

---

## ADR-0008 — Permissions routed by class through a coordinator

**Status:** Accepted

**Context:** In-app permission toggles are inconsistent ("sometimes work, mostly don't") because Android permissions come in different *classes* that require different handling, but the current code treats them uniformly. `POST_NOTIFICATIONS` is a runtime dialog (works via `permission_handler`). Notification-listener access is a **special access** — there is no dialog; the user must be deep-linked to a specific Settings screen.

**Decision:** Introduce a `PermissionCoordinator` that knows each permission's class and routes it correctly (runtime dialog vs. special-access settings deep-link vs. other). No permission is requested with the wrong mechanism.

**Consequences:** Fixes the inconsistency at the root. Small abstraction that must be kept accurate as new permissions are added.

---

## ADR-0009 — `imported` transactions and their effect on balance (to be resolved)

**Status:** Proposed

**Context:** `balanceOf` currently skips transactions with `imported == true` (`if (t.imported) continue;`), so CSV-imported history is display-only and does not affect wallet balances. The bank-notification feature (ADR-0006/0007) will generate transactions that *originate from an external source* and, unlike CSV history, almost certainly **should** move the balance. The current binary `imported` flag conflates "external in origin" with "excluded from balance," which will break once bank auto-import lands.

**Decision (proposed):** Separate the two concerns. Bank-confirmed transactions affect balance like manual ones. Revisit whether CSV-imported history should remain balance-excluded or be reconciled. Likely replace the single `imported` boolean with an explicit source/`affectsBalance` distinction. **Resolve before building the bank feature.**

**Consequences:** Probable schema change and a migration. Until resolved, do not build balance-affecting logic on top of the current `imported` flag.

---

## ADR-0010 — Correctness fixes bundled into the foundation phase

**Status:** Accepted

**Context:** Review found three discrete issues safe to fix alongside the DI refactor: (a) multi-step writes (`addSpending`, `addTransfer`, `updateTxn`) do a balance check then a separate write, not wrapped in a DB transaction — a race window; (b) `home_page.dart` swallows all widget-handling errors in `try { } catch (_) {}`, hiding the very bugs that make the widget undebuggable; (c) category labels/thresholds exist in two places (static map in `domain.dart` and seeded DB rows), risking divergence.

**Decision:** Fix all three in Phase 1: wrap the writes in `db.transaction`, replace the empty catch with logging, and make the DB the single source of truth for live category data.

**Consequences:** Closes a finance-relevant race, surfaces widget failures, removes a divergence hazard — all behavior-preserving for the user.

---

## ADR-0011 — Git workflow (decision pending)

**Status:** Proposed

**Context:** The author uses full Git Flow (feature/hotfix/UAT branches) at work (FPT). Full Git Flow suits scheduled team releases; for a solo app it is arguably over-engineering, where GitHub Flow (protected `main`, short-lived feature branches, self-reviewed PRs) is the right-sized tool. However, deliberately practicing Git Flow here is a legitimate choice if the goal is drilling that muscle.

**Decision (proposed):** Default to **GitHub Flow** for this solo project unless the author decides the Git Flow practice value outweighs the overhead. Either way, adopt regardless: Architecture Decision Records (this document), conventional commits, a changelog, and a CI job running `flutter test` + `flutter analyze` on every PR once the test foundation (ADR-0003) exists.

**Consequences:** Lightweight process that fits solo development while still reading as professional. The ADR/commit/CI habits deliver most of the "legitimacy" signal independent of the branching model chosen.

---

## Implementation phasing (reference)

The decisions above are sequenced to keep the app running throughout — never a big-bang rewrite:

1. **Foundation** — Riverpod DI + remove globals + tests (ADR-0003), bundled correctness fixes (ADR-0010).
2. **Process** — branching model, ADRs, conventional commits, CI (ADR-0011).
3. **SQL** — move balance/analytics into Drift aggregates (ADR-0005).
4. **Native rebuild** — `PermissionCoordinator` (ADR-0008), notification listener + parser strategies + wallet-bank association (ADR-0006/0007), after resolving the `imported` question (ADR-0009).
5. **Widget + inline-input notification** — shares native infrastructure with phase 4.
6. **Polish** — English localization, CSV for wallets, currency-label consistency.
