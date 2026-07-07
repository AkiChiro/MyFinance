# Claude Code Task — MyFinance Phase 5c: Native Capture Layer (Deferred model)

> Paste this whole file into Claude Code as the task brief. This is the **native-heavy** slice — Kotlin `NotificationListenerService`, a Pigeon channel, permission routing, and the Dart drain orchestration. Per **ADR-0017**, it uses the **Deferred** model: native *buffers* raw notifications; Dart *parses and files* them on app open. Do not start coding until you have proposed a plan (see "Before you code"). References: **ADR-0017** (deferred capture), **ADR-0013** (capture table & scope), **ADR-0008** (permission coordinator), **ADR-0002** (Pigeon channels).

---

## Project context

MyFinance is an offline, Android-first Flutter finance tracker (Drift, integer VND). Phases 1/3/4/5a/5b are done:
- **5a** added the `NotificationCaptures` table + `Wallets.packageName`, and repository methods `insertCapture(...)` (dedups; resolves `suggestedWalletId` from `packageName`) and `watchPendingCaptures()`.
- **5b** added pure-Dart parsers: `BankNotificationParser`, `BankParserRegistry.forPackage(pkg)`, `RawNotification {packageName, title?, text}`, `ParsedNotification {amount, direction, endingBalance?, accountHint?, lowConfidence}`, and `BankPackages` constants (currently **placeholder** package names marked TODO).

The existing app already uses Kotlin (`MainActivity.kt`, a persistent-notification setup) and has a package name like `com.huy.myfinance` (confirm the actual `applicationId` in `android/app/build.gradle`).

This slice connects real notifications to that pipeline, **deferred**: the native listener buffers raw notification text as it arrives (even when the app is closed); when the app opens, Dart drains the buffer, parses each item with 5b, and files real transactions' proposals into `NotificationCaptures`.

---

## Goal

A working end-to-end deferred capture path: grant notification-listener access via a proper settings deep-link; the native service buffers raw notifications from watched packages; on app open Dart drains, parses, and files captures (discarding non-transactions); and a small discovery surface reveals real package names so the `BankPackages` placeholders can be corrected.

---

## Scope — IN

### 1. Pigeon channel (typed, per ADR-0002)
Define a Pigeon schema and generate bindings. Host API (Dart → native):
- `setWatchedPackages(List<String> packages)` — Dart tells native which packages to buffer content for.
- `List<RawCaptureMessage> drainCaptures()` — returns buffered captures **without clearing** (each with a native-side `id`).
- `clearCaptures(List<String> ids)` — clears the acked captures after Dart has filed them.
- `List<String> seenPackages()` — returns the set of package names seen (names only, no content) for discovery.
- `bool isListenerEnabled()` / `void openListenerSettings()` — for permission routing.

`RawCaptureMessage` carries `{id, packageName, title?, text, postTimeMillis}`. No `FlutterApi` (push-to-Dart) is needed — Dart pulls. Do not hand-roll `MethodChannel` string keys; use Pigeon so the contract is compile-checked.

### 2. Native `NotificationListenerService` (Kotlin)
- A `NotificationListenerService` subclass registered in the manifest with `BIND_NOTIFICATION_LISTENER_SERVICE`.
- In `onNotificationPosted`: extract `packageName`, `title` (`EXTRA_TITLE`), and `text` (prefer `EXTRA_BIG_TEXT`, fall back to `EXTRA_TEXT`) and `postTime`.
- **Discovery:** always record the `packageName` (name only, no content) into a "seen packages" set.
- **Content buffering:** only if `packageName` is in the watched-packages set, append `{id, packageName, title, text, postTime}` to a **native buffer** (SharedPreferences JSON, or a small Room table — propose which). Generate a stable `id` (e.g. UUID). Appends must be concurrency-safe (the callback can fire rapidly).
- Native performs **no parsing and no Drift access** — it only buffers raw strings (ADR-0017).
- The watched-packages set is persisted natively (written by `setWatchedPackages`) so the service can filter even when the Flutter engine isn't running.

### 3. `PermissionCoordinator` (ADR-0008)
- Introduce a small coordinator that knows notification-listener access is a **special access**, not a runtime dialog: `isListenerEnabled()` checks whether this app's service is in the enabled-listeners list; requesting it **deep-links** to `Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS` via `openListenerSettings()`. Do not attempt a runtime permission dialog for it.
- This is the first concrete client of the coordinator; structure it so other permission classes can be added later, but only implement the listener-access class now.

### 4. Dart drain orchestration
- A service/provider (Riverpod) that, on **app start and on resume**: computes the watched-package set = `BankPackages` values ∪ `{wallet.packageName for wallets where packageName != null}`, calls `setWatchedPackages(...)`, then `drainCaptures()`.
- For each drained item: build a `RawNotification`, select `BankParserRegistry.forPackage(packageName)`, and `parse(...)`.
  - If it returns a `ParsedNotification` → `insertCapture(...)` with the parsed fields and `parseStatus` from `lowConfidence` (`false → parsed`, `true → needsReview`). `insertCapture` handles dedup.
  - If it returns `null` (OTP/promo/non-transaction, or no parser for the package) → **discard** (do not insert) — keeps the inbox clean.
- After all items are filed, call `clearCaptures(theirIds)` to ack. Order matters: file first, then clear, so a crash mid-drain re-drains rather than loses data.

### 5. Discovery surface (resolve the placeholder package names)
- A minimal debug/settings view (or even a log + a temporary list in settings) that shows `seenPackages()` so you can identify which package each bank app uses and correct the `BankPackages` constants. Names only — no notification content. This is how the 5b placeholders get their real values.

### 6. Tests
- **Dart orchestration is unit-testable** with a fake Pigeon Host API: given canned `RawCaptureMessage`s, assert the correct `insertCapture` calls (parsed → filed with right fields/status; null/unknown-package → discarded), the watched-package set is computed correctly from `BankPackages` ∪ linked wallets, and `clearCaptures` is called only after filing. Use the generated Pigeon mock/abstract Host API.
- The Kotlin `NotificationListenerService` cannot be exercised by `flutter test` — see the on-device note below.

---

## Scope — OUT
- **No inbox / review UI, no wallet↔bank-app picker, no notification quick-actions** — that's **5d**. (This slice files captures; reviewing/confirming them in-app is 5d. Until 5d, verify via `watchPendingCaptures()` in a test or a temporary debug list.)
- **No background isolate, no Instant-mode / confirm-from-notification** — explicitly deferred (ADR-0017/0015).
- **No Drift access from native.** Native only buffers.
- **No changes to parsers (5b), the capture table (5a), or balance/analytics (4).**
- No `schemaVersion` change (the table already exists).

---

## Constraints
- Native buffers raw only; Dart owns parsing and all Drift writes (ADR-0017).
- File-then-clear ordering so a mid-drain crash re-drains rather than drops captures.
- Pigeon for the channel — no ad-hoc `MethodChannel` string keys.
- Listener access via settings deep-link, never a runtime dialog (ADR-0008).
- Incremental conventional commits (`feat:`, `test:`, `chore:` for Pigeon generation).
- `flutter analyze` clean; `flutter test` green (Dart orchestration tests); debug APK builds.

## On-device verification (read this — it's a real shift)
Every slice so far was fully provable by `flutter test`. **5c is the first that isn't:** a `NotificationListenerService`, the special-access grant flow, OEM/lock-screen behavior, and real bank notifications can only be verified on a physical Android device. The Dart orchestration is unit-tested here, but the native half needs manual on-device checks. Expect to: grant listener access via the deep-link, confirm `seenPackages()` shows your bank apps (and correct the `BankPackages` constants from it), then trigger a real transaction and confirm a capture appears via `watchPendingCaptures()`. Plan for a device test pass, not just green unit tests.

## Before you code
1. Read `MainActivity.kt` and the manifest (existing Kotlin/notification setup, `applicationId`), the 5b registry/`BankPackages`, and the 5a `insertCapture`/`watchPendingCaptures`.
2. Propose: the native buffer store (SharedPreferences JSON vs Room) and its concurrency handling; the Pigeon schema; how `setWatchedPackages` is persisted for the always-on service; the drain-orchestration lifecycle (start + resume) and how it hooks into the Riverpod graph; and how you'll fake the Host API for the orchestration tests.
3. Flag any OEM/background-execution caveats you know of (this app has hit Vivo/OEM notification quirks before) and how the deferred model sidesteps them.
4. Wait for confirmation, then implement commit by commit (Pigeon schema → native listener + buffer → permission coordinator → Dart drain orchestration → discovery surface → tests).

## Definition of done
- Pigeon channel generated: `setWatchedPackages`, `drainCaptures`, `clearCaptures`, `seenPackages`, `isListenerEnabled`, `openListenerSettings`.
- Native `NotificationListenerService` buffers raw notifications from watched packages (no parsing, no Drift), records seen package names, and persists the watch set.
- `PermissionCoordinator` routes listener access via the settings deep-link.
- Dart drains on start/resume: parse → file (`insertCapture`) → clear, discarding non-transactions and unknown packages.
- A discovery surface lists seen package names.
- Dart orchestration unit-tested against a fake Host API; `flutter analyze` clean; debug APK builds.
- A short summary per file, the buffer-store choice, and a brief on-device test checklist for you to run.
