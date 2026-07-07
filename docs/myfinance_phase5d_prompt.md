# Claude Code Task — MyFinance Phase 5d: In-App Capture Review & Confirm UX

> Paste this whole file into Claude Code as the task brief. This is the **final slice** of the bank feature: the in-app inbox, the review/confirm screen, and the wallet↔bank-app link. It is **UI + Dart**, tested against *seeded* captures — no native code, and (per ADR-0017) **no notification quick-actions**. Do not start coding until you have proposed a plan (see "Before you code"). References: **ADR-0014** (wallet matching, overridable at confirm), **ADR-0017** (deferred model → in-app review, not notification-confirm), **ADR-0013** (`parseStatus` visibility), **ADR-0009** (`source`/`affectsBalance`).

---

## Project context

MyFinance is an offline, Android-first Flutter finance tracker (Drift, integer VND, **Vietnamese UI**). Phases 1–5c are done:
- **5a**: `NotificationCaptures` table + `Wallets.packageName`; repo methods `watchPendingCaptures()`, `pendingCaptureCount()`, `insertCapture(...)`, **`confirmCapture(captureId, {walletId, amount, direction, category, starred})`** (atomic; writes a `bankNotification`/`affectsBalance=true` transaction; overspend-bypassed), **`dismissCapture(captureId)`**.
- **5b**: parsers producing `{amount, direction, endingBalance?, accountHint?}`; `BankPackages` constants (OCB/MB/Techcombank — real values pending the device pass).
- **5c**: native listener buffers raw notifications; Dart drains, parses, and files captures. A parsed capture has `parseStatus = parsed`; a low-confidence one `needsReview`; a money-shaped notification the parser couldn't read is filed `unparsed` (per ADR-0013 — these must be *visible*, not silently dropped).

This slice is the human-facing end: review the pending captures and turn them into transactions (or dismiss them), and let a wallet be linked to a bank app so captures pre-fill the right wallet.

The app is **Vietnamese** (e.g. Settings shows "Nhà phát triển", "Cấp quyền", "Gói đã thấy"). Match the existing screens' language, theme, and widget style. Screens are Riverpod `ConsumerWidget`s.

---

## Goal

A captures **inbox** the user reaches from the app, showing pending captures with a count badge; a **review/confirm screen** that pre-fills the proposed transaction and lets the user edit and confirm (or dismiss); and a **"linked bank app" field** on wallet create/edit that sets `Wallets.packageName`. All unit-tested against seeded captures.

---

## Scope — IN

### 1. Captures inbox
- A screen listing `watchPendingCaptures()` (newest first), reached from a clear entry point with a **count badge** driven by `pendingCaptureCount()` (propose placement — e.g. a banner/card on the Wallets or Home screen, or an app-bar action; match the app's navigation).
- Each row summarizes the capture: the linked bank/wallet (resolve via `packageName` → wallet name, else the bank label), amount, direction (thu/chi — income/expense), and `endingBalance` if present.
- **Render the three `parseStatus` states distinctly:**
  - `parsed` → a normal proposal ready to confirm.
  - `needsReview` → a proposal flagged for a closer look (low confidence).
  - `unparsed` → "couldn't read automatically" — tapping goes to manual entry (see §2), *not* a pre-filled proposal. This is the visible-parser-gap path; never hide these.
- Empty state ("no captures to review") in Vietnamese.

### 2. Review / confirm screen
- Opened by tapping a capture. Pre-fills from the capture: **amount**, **direction**, **wallet** (from `suggestedWalletId`), and shows `endingBalance`/`capturedAt`/raw text for reference.
- All fields **editable at confirm** (ADR-0014): wallet (override via a wallet picker — the suggested one is a default, not a lock), amount, direction (thu/chi), category (manual selection — see note), starred.
- **`unparsed` captures**: show the raw `title`/`text` prominently so the user can read the notification, and require manual amount + direction entry before confirming. This is graceful degradation for a parser gap — the transaction is still capturable by hand.
- **Confirm** → `confirmCapture(captureId, walletId:…, amount:…, direction:…, category:…, starred:…)` (this already writes the `bankNotification` transaction atomically and marks the capture confirmed). **Dismiss** → `dismissCapture(captureId)`.
- After confirm/dismiss, return to the inbox; the row disappears (it's no longer pending) and the badge decrements — both reactive via the existing streams.

### 3. Wallet ↔ bank-app link (ADR-0014)
- On wallet **create/edit**, add a "Ngân hàng liên kết" (linked bank) field: a picker offering **None + the supported banks** (labeled OCB / MB / Techcombank, mapping to the `BankPackages` constants). Selecting one sets `Wallets.packageName` to that constant; "None" clears it.
- **Enforce the uniqueness** from ADR-0014 (the `packageName` unique index): if the chosen bank is already linked to another wallet, don't just let the insert throw — check first and show a clear Vietnamese message (offer to move the link to this wallet, or block — propose the cleaner UX). The unique index is the backstop; the UI must not hit it.
- A curated bank list (not an installed-apps enumeration) is intended here — three supported banks is a dropdown, no `PackageManager` query needed.

### 4. Category on bank confirms (note, not a feature to build)
Bank notifications carry no merchant text (descriptions are person-to-person transfers), so **category is a manual pick**, defaulting to none/`others`. Do **not** wire `CategorySuggester` here — there's nothing useful for it to read. (It can be revisited later if bank descriptions ever prove useful.)

### 5. Tests (against seeded captures — no native)
Seed `NotificationCaptures` rows directly in an in-memory DB and drive the logic:
- Confirming a `parsed` capture calls `confirmCapture` and produces exactly one transaction with `source == bankNotification`, `affectsBalance == true`, correct type (income→earning, expense→spending), wallet, amount; the capture becomes `confirmed`.
- **Wallet override**: confirming with a wallet different from `suggestedWalletId` writes the transaction to the chosen wallet.
- **Dismiss** creates no transaction and marks the capture `dismissed`.
- **`unparsed` flow**: a manually-entered amount/direction on an `unparsed` capture confirms correctly.
- **Uniqueness guard**: linking a bank already linked to another wallet is caught by the UI (doesn't throw the index error).
- Inbox count/list react to insert/confirm/dismiss.

---

## Scope — OUT
- **No notification quick-actions / confirm-from-notification** — deferred (ADR-0015/0017). Review is in-app only.
- **No installed-apps enumeration / `PackageManager` channel** — use the curated `BankPackages` bank list.
- **No native/Kotlin, no parser changes, no capture-table or schema changes** — all of that exists.
- No `CategorySuggester` wiring; no Instant-mode; no English localization (Phase 7).

---

## Constraints
- **Vietnamese UI**, matching existing screens' theme and widget style; Riverpod `ConsumerWidget`s.
- Reuse `confirmCapture` / `dismissCapture` — do not duplicate transaction-writing logic in the UI.
- Reactive throughout (inbox, badge) via the existing streams.
- Incremental conventional commits (`feat:`, `test:`).
- `flutter analyze` clean; `flutter test` green (seeded-capture tests); debug APK builds.

## Before you code
1. Read the 5a repo methods (`watchPendingCaptures`, `pendingCaptureCount`, `confirmCapture`, `dismissCapture`), the `NotificationCaptures`/`Wallets` schema, an existing screen (e.g. `quick_add_page.dart`) for the transaction-entry widget patterns to match, and the wallet create/edit flow.
2. Propose: the inbox entry point + badge placement; the review-screen layout and how it differs for `unparsed` vs `parsed`; the linked-bank picker and the uniqueness UX (move vs block); and the seeded-capture test structure.
3. Flag any mismatch between the capture fields and what the confirm/transaction path needs, and ask before working around it.
4. Wait for confirmation, then implement commit by commit.

## Definition of done
- A captures inbox reachable from the app with a reactive count badge, rendering `parsed` / `needsReview` / `unparsed` distinctly.
- A review/confirm screen that pre-fills, allows editing (incl. wallet override), confirms via `confirmCapture`, and dismisses via `dismissCapture`; `unparsed` captures show raw text and support manual entry.
- A "linked bank" picker on wallet create/edit setting `Wallets.packageName`, with the uniqueness guard handled in the UI.
- Seeded-capture tests green (confirm, override, dismiss, unparsed, uniqueness, reactivity); `flutter analyze` clean; debug APK builds.
- A short summary per file, plus a consolidated **on-device test checklist for all of Phase 5** (grant access → discover packages → fix `BankPackages` → link a wallet → trigger a real transaction → confirm it lands in the inbox → confirm it becomes a transaction), since the device pass now covers 5c + 5d together.
