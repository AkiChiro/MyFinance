# Claude Code Task — MyFinance Phase 5b: Bank-Notification Parsers

> Paste this whole file into Claude Code as the task brief. This is a **pure-Dart, fixture-driven** slice — no native code, no UI, no DB changes. The fixtures below are real anonymized notification strings and are the spec; parsers must satisfy them exactly. Do not start coding until you have proposed a plan (see "Before you code"). References: **ADR-0007** (Strategy parsers keyed by package), **ADR-0016** (parser contract), **ADR-0013** (capture fields the output maps to).

---

## Project context

MyFinance is an offline, Android-first Flutter finance tracker (Drift, integer VND). Phases 1/3/4/5a are done. 5a added the `NotificationCaptures` table and the enums `CaptureDirection { income, expense }` and `ParseStatus { parsed, needsReview, unparsed }` in `lib/models/domain.dart`. `lib/format.dart` has a `parseAmount` helper.

This slice builds the **parsing layer**: an interface, a package-keyed registry, a shared VND-amount helper, and one parser per real bank, each backed by fixture tests from real notification strings. It is pure Dart — exercised entirely by unit tests calling parsers directly. Nothing native, no UI, no schema change.

**Key domain facts (from real samples):**
- **VND has no sub-unit.** Any `.` or `,` inside an amount is *always* a thousands separator, so both can be stripped to read the integer value (`20.000` → 20000, `20,000` → 20000, `6.000.000` → 6000000).
- Separator, amount location, and label wording **differ per bank** — that is why this is one parser per bank (Strategy), selected by **package name** (the notification header does not identify the bank; OCB and MB share the header "Thông báo biến động số dư").
- Direction comes from the `+`/`-` sign.
- Use the system capture time for the transaction timestamp — parsers do **not** need to parse the bank's embedded date.

---

## Scope — IN

### 1. Shared VND-amount helper
Extend `lib/format.dart` (or add alongside `parseAmount`) with a helper that takes an amount substring and returns an `int` VND by stripping **all** `.` and `,` and any currency tokens/whitespace, reading the remaining digits. Add unit tests: `20.000`, `20,000`, `6.000.000`, `335.532`, with and without `VND`/`đ`, leading `+`/`-`. Direction (sign) is extracted by the caller before/around this — decide the cleanest split and document it.

### 2. `ParsedNotification` value object (ADR-0016)
Immutable, in a new `lib/services/bank/` (or similar):
- `int amount` (VND), `CaptureDirection direction`, `int? endingBalance`, `String? accountHint`, and a confidence signal (e.g. `bool lowConfidence` or a small enum).
- The caller maps confidence → `ParseStatus`: a clean parse → `parsed`; an amount found but something ambiguous (e.g. amount present but no clear sign) → `needsReview`. A parser returning `null` → the caller records `unparsed`.

### 3. Parser interface + registry (ADR-0007/0016)
- Abstract `BankNotificationParser` with `ParsedNotification? parse(RawNotification raw)`, where `RawNotification` carries `{String packageName, String? title, String text}` (title matters — Techcombank's amount is in the title). Returns `null` when the notification is not a balance-change transaction (OTP, promo, login alert, etc.).
- A **registry** mapping package name → parser instance, with a lookup that returns the parser for a package or null. Adding a bank = implement + register + fixtures.
- **Package names:** define them as named constants **clearly marked `// TODO: verify against a real capture / Play Store id=`** — the authoritative values come from real `packageName`s once the native layer (5c) is live. Parser *tests call parsers directly*, so they do not depend on these being correct; only the production registry lookup does.

### 4. The three parsers, each satisfying its fixtures exactly

**OCB** — dot-separated; amount/sign on the `Số tiền:` line; balance on `Số dư:` (tolerate a stray trailing dot); account on `Tài khoản:` (fully masked here). Title: `Thông báo biến động số dư`.

Expense fixture — body:
```
06/07 15:27
Tài khoản: xxxxxxxxxxxxxxxx
Số tiền: -20.000 VND
Số dư: 335.532. VND
Nội dung: XXX transfer
```
→ `amount: 20000, direction: expense, endingBalance: 335532, parsed`.
Income fixture — same with `Số tiền: +20.000 VND` → `amount: 20000, direction: income, endingBalance: 335532, parsed`.

**MB** — pipe-delimited body; comma-separated; amount/sign in the `GD:` field (no space before `VND`); balance in `SD:`; account in `TK`. Title: `Thông báo biến động số dư`.

Expense fixture — body:
```
TK xxxxxxxx|GD: -20,000VND 07/07/26 15:25 |SD: 20,825VND|DEN: XXX - XXXXXXXXXXXX|ND: XXX chuyển tiền D2EA9G4U/886938
```
→ `amount: 20000, direction: expense, endingBalance: 20825, parsed`.
Income fixture — same with `GD: +20,000VND` → `amount: 20000, direction: income, endingBalance: 20825, parsed`.

**Techcombank** — comma-separated; **amount and sign are in the TITLE** (`± VND <amount>`, currency before number); balance in the body `Số dư: VND …`; account in `Tài khoản:`.

Income fixture — title `+ VND 20,000`, body:
```
Tài khoản: xxxxxxxxxxxxxxxx
Số dư: VND 20,013
XXX chuyen tien
```
→ `amount: 20000, direction: income, endingBalance: 20013, parsed`.
Expense fixture — **UNVERIFIED (no real sample yet)**: implement by symmetry assuming title `- VND 20,000`, mark the fixture and the code path with a clear `// UNVERIFIED: confirm with a real outgoing Techcombank notification` comment. If a Techcombank notification matches neither the `+` nor the `-` title pattern, return `null` / `needsReview` rather than guessing.

### 5. Negative fixtures (guard against false positives)
For each bank, add at least one **non-transaction** fixture (a plausible OTP / promo / login string lacking the amount structure — e.g. an OCB notification with no `Số tiền:` line) and assert `parse(...)` returns `null`. A parser must not, for example, pull a number out of an OTP message. (These are constructed; add real non-transaction samples later to harden them.)

### 6. Tests
All pure Dart, no Flutter binding. Every fixture above with its exact expected `ParsedNotification` (or null). Plus the VND-helper tests. Group per bank.

---

## Scope — OUT
- **No native / Kotlin** (5c) — parsers are invoked directly in tests; nothing wires them to a real listener yet.
- **No DB writes / no capture insertion** — this slice produces `ParsedNotification`s; storing them onto capture rows is the 5c wiring. Do not call `insertCapture` here.
- **No UI** (5d). **No `CategorySuggester` wiring** — bank captures leave `suggestedCategory` null.
- No date parsing — the bank's embedded date is ignored; the capture's system time is the source of truth (in 5c).
- No `schemaVersion` change, no new columns.

---

## Constraints
- Every fixture must pass exactly (amounts as integer VND; correct direction from sign; balances parsed with separators stripped).
- Parsers return `null` for anything that isn't a balance-change transaction — false positives are worse than misses here.
- Per-bank logic stays inside each parser; the only shared code is the VND helper.
- Incremental conventional commits (`feat:`, `test:`).
- `flutter analyze` clean; `flutter test` green; debug APK builds. Offline only.

## Before you code
1. Read `lib/format.dart` (`parseAmount`) and `domain.dart` (`CaptureDirection`, `ParseStatus`).
2. Propose: the VND-helper signature and how sign extraction is split from digit parsing; the `RawNotification` / `ParsedNotification` shapes; the registry structure; and the per-bank regex/field-extraction strategy for each of the three, referencing the fixtures.
3. Flag any ambiguity in the sample strings (e.g. the OCB trailing dot, MB's spacing around pipes) and how you'll make the extraction robust to it.
4. Wait for confirmation, then implement commit by commit (helper → interface/registry → OCB → MB → Techcombank → negatives).

## Definition of done
- Shared VND helper strips `.`/`,`/currency and returns integer VND, tested.
- `ParsedNotification`, `RawNotification`, `BankNotificationParser`, and a package-keyed registry exist; package-name constants are present and marked for verification.
- OCB, MB, Techcombank parsers each satisfy their income/expense fixtures; Techcombank expense is implemented-by-symmetry and marked unverified.
- Negative (non-transaction) fixtures return null for each bank.
- All tests green, pure Dart; `flutter analyze` clean; debug APK builds.
- A short summary per file, the VND-helper design, and any robustness decisions made for ambiguous sample formatting.
