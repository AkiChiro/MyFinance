# Scope Document — MyFinance (Android)

**App name:** MyFinance
**Platform:** Android (personal use, single user)
**App language:** Vietnamese (UI)
**Author:** Huy
**Version:** 1.0 (scope locked)
**Last updated:** 29 Jun 2026

> Changes in 1.0: open items resolved — name = MyFinance · min Android 10 (API 29) · transfer is from/amount/to only (no description) · imported CSV history is archive-only (viewable, excluded from balance *and* analytics).
> Changes in 0.3: explicit per-type balance effects · overspend guard ("Hãy kiểm tra lại số tiền thực tế") · CSV merge confirmed, with imported history excluded from wallet balances.
> Changes in 0.2: currency system removed (VND only) · `Chuyển khoản` (transfer) type added · Vietnamese UI · CSV import/export added · advice/recommendations removed (numbers, % and bar charts only) · weekly comparison removed (monthly only) · widget elevated · phasing reordered to get a runnable app on-device fast.

---

## 1. Overview

A lightweight, fully offline, **Vietnamese-language** Android app for tracking personal spending and earning in **VND only**. You record each transaction with a few inputs (type, amount, description, wallet — or two wallets for a transfer); the app auto-timestamps it, totals everything, draws pie charts for category composition and bar charts for month-over-month comparison, and lets you export/import your data as CSV. The defining goal is *fast capture* plus *getting a usable build onto the phone quickly*.

---

## 2. Goals

1. **Friction-free capture** — log a transaction in seconds, ideally from the notification shade or a home-screen widget.
2. **Zero network dependency** — everything works offline; all data stays on the device.
3. **At-a-glance insight** — totals, two pie charts, and a clear "up or down vs last month?" answer via bar charts and percentages.
4. **Data safety** — CSV export/import so a year of history isn't trapped on one device.
5. **Ship fast** — a runnable, useful build on the phone as early as possible.

### Non-goals
- Multiple currencies / FX (VND only).
- Advice / recommendations (numbers, %, and charts only — no text suggestions).
- Cloud sync, multi-user, server backup (CSV export is the only backup).
- Bank/SMS import, receipt scanning, OCR.
- iOS or web.
- Budgets/limits, bill reminders, recurring entries *(possible later — §14)*.

---

## 3. Requirements summary

### Non-functional
| # | Requirement |
|---|---|
| NF1 | Runs on Android **10 (API 29)** and up — covers the older test phone; widget/notification features all supported |
| NF2 | Fully offline — no internet permission required |
| NF3 | Light & user-friendly — few screens, fast input |
| NF4 | **Vietnamese UI** throughout |
| NF5 | **VND only** — no currency selection anywhere |

### Functional
| # | Requirement |
|---|---|
| F1 | Fast input via **notification and home-screen widget** (§8) |
| F2 | Auto-capture timestamp from device clock; editable later |
| F3 | Totals + **pie charts** (category composition) + **bar charts** (month-over-month) |
| F4 | **CSV import/export** |
| F5 | No advice — display raw numbers and percentage differences only |

---

## 4. Core concept — the transaction

Three transaction **types**:

**`Chi tiêu` (Spending)** and **`Thu nhập` (Earning)** — 4 inputs + auto time:

| Input | Type | Detail |
|---|---|---|
| Type | Selection | `Chi tiêu` / `Thu nhập` / `Chuyển khoản` |
| Amount (`Số tiền`) | Integer | VND, whole numbers |
| Description (`Mô tả`) | Text | Drives the suggested category (§9) |
| Wallet (`Ví`) | Selection | One of your wallets/accounts |
| Time (`Thời gian`) *(auto)* | Datetime | From device clock; editable |

**`Chuyển khoản` (Transfer)** — moves money between your own wallets. **Not** counted as spending or earning. 3 inputs + auto time:

| Input | Detail |
|---|---|
| From wallet (`Từ ví`) | Source wallet |
| Amount (`Số tiền`) | VND |
| To wallet (`Đến ví`) | Destination wallet |
| Time *(auto)* | From device clock; editable |

A transfer decreases the source wallet and increases the destination by the same amount, and is **excluded from all spending/earning totals and pie charts**. Transfers carry no description and no category — from/amount/to only.

---

## 5. Data model

### 5.1 Transaction
| Field | Type | Notes |
|---|---|---|
| `id` | int/UUID | Primary key |
| `type` | enum | `spending` \| `earning` \| `transfer` |
| `amount` | integer | VND |
| `description` | text | Spending/earning only (feeds category suggestion); **null for transfer** |
| `wallet_id` | FK → Wallet | Spending/earning: the wallet. Transfer: the **from** wallet |
| `wallet_to_id` | FK → Wallet | **Transfer only**, else null |
| `category_id` | FK/enum | Spending/earning only (null for transfer); suggested + user-confirmable |
| `timestamp` | datetime | Auto from device; editable |
| `created_at` | datetime | System audit, non-editable |
| `imported` | bool | `true` if brought in via CSV merge. **Archive-only:** viewable in the transaction list but excluded from balance *and* analytics (§10, §11). Default `false` |

### 5.2 Wallet
| Field | Type | Notes |
|---|---|---|
| `id` | int/UUID | Primary key |
| `name` | text | e.g. "Tiền mặt", "Techcombank", "Momo" |
| `initial_balance` | integer | VND, set when the wallet is added |
| `type` | enum | `cash` \| `bank` (optional) |

> **Balance rule.** Each transaction adjusts the affected wallet(s):
> - `Chi tiêu` (spending): source wallet **− amount**
> - `Thu nhập` (earning): wallet **+ amount**
> - `Chuyển khoản` (transfer): from-wallet **− amount**, to-wallet **+ amount**
>
> Current balance = `initial_balance` + the net of all **non-imported** transactions for that wallet (imported history is excluded — see §11). `initial_balance` is the balance at the moment the wallet is created; it already reflects any earlier history, so don't backfill older transactions against it or it double-counts.
>
> **Overspend guard.** On save (add *or* edit), if a `Chi tiêu` or a `Chuyển khoản` would push the source wallet below 0, reject the transaction and show: **"Hãy kiểm tra lại số tiền thực tế"**. Earnings and transfers-*in* are never blocked.

### 5.3 Category
| Field | Type | Notes |
|---|---|---|
| `id` | enum | See §6 |
| `name_vi` | text | Vietnamese display name |
| `type` | enum | `spending` \| `earning` |
| `color` | color | Pie slice |

### 5.4 KeywordRule (editable library, §9)
| Field | Type | Notes |
|---|---|---|
| `keyword` | text | e.g. "đồ ăn" |
| `category_id` | FK | Target category |
| `weight` | integer | Higher = stronger suggestion |

Stored as an editable JSON file, editable in Settings.

---

## 6. Categories

### Spending (`Chi tiêu`)
| Category | VN | Covers |
|---|---|---|
| Necessities | **Thiết yếu** | Hóa đơn hằng tháng, xăng, di chuyển, học phí |
| Food | **Ăn uống** | Ăn ngoài |
| Hobbies | **Sở thích** | Setup (tai nghe, bàn phím, chuột…) |
| Others | **Khác** | Chi tiêu linh tinh |

### Earning (`Thu nhập`)
| Category | VN | Covers |
|---|---|---|
| Provided | **Chu cấp** | Tiền từ bố mẹ |
| Self-earned | **Tự kiếm** | Tiền mình kiếm được |
| Others | **Khác** | Nguồn khác |

> "Self-earned / Tự kiếm" is deliberately *not* called "Thu nhập" so the category doesn't collide with the spending/earning **type** of the same name.

---

## 7. App sections (screens)

### 7.1 Wallets (`Ví`)
- Add a wallet/account with a name and its balance at the time of adding (`initial_balance`).
- List of wallets, each showing its live balance.
- Edit / delete.

### 7.2 Finance cards (`Giao dịch`)
- Scrollable list of transactions, newest first.
- Each card shows type, amount, description, wallet(s), category, time.
- **Tap to edit any value** (including time and the suggested category). Delete supported.

### 7.3 Analytics (`Thống kê`)
- **Two pie charts**: spending by category, earning by category (transfers excluded).
- **Month view** — pick a month. Shows: total spending, total earning, net difference.
- **Month-over-month**: a **bar chart** comparing the selected month to the previous month, plus the **percentage difference** (spending, earning, net). No advice text — just the numbers and bars.
- **Year-to-date total** (spending, earning, net) for the calendar year.

### 7.4 Quick Add (`Thêm nhanh`)
- The shared entry form used in-app and from the notification/widget (§8).
- Type toggle `Chi tiêu / Thu nhập / Chuyển khoản`; the fields swap to from-wallet / amount / to-wallet when Transfer is selected.
- Pre-focused, smart defaults (last-used wallet), one action to save.

### 7.5 Settings (`Cài đặt`)
- **CSV import / export** (§11).
- **Keyword library** editor (§9).
- Theme/logo info (yellow, fixed).

---

## 8. Fast input — notification + widget

**Constraint (unchanged):** Android can't render a full multi-field form *inside* a notification — only text, buttons, and one inline reply field. So the realistic, robust fast-capture path is an entry point that opens a **pre-focused Quick Add form** in well under a second.

**Primary — home-screen widget (`better input`, as requested):**
- A widget with **`+ Chi tiêu`**, **`+ Thu nhập`**, **`+ Chuyển khoản`** buttons (and optionally quick amount presets). Each opens the Quick Add form on the right type, with smart defaults. This is the most reliable "fast and proper-fields" path.

**Secondary — persistent notification:**
- A low-priority ongoing notification with the same three action buttons, each opening the Quick Add form. Optional inline **direct reply** for a single-line entry (e.g. `50000 đồ ăn vcb`) parsed via the keyword library — kept as an optional power-user shortcut, not the main path.

**Tertiary — Quick Settings tile / app shortcuts** (long-press launcher icon) for the same thing.

All entries are editable later in §7.2.

---

## 9. Description → category (suggest, don't auto-file)

A lightweight offline weighted-keyword matcher — **only used to pre-select a suggested category in the form, which you confirm with a glance.** It never silently files a transaction, so a wrong guess can't quietly skew your pie charts. (Transfers have no category.)

**How:** scan the description; each matched keyword adds its weight to that category; highest total wins and is pre-selected; tie/no-match pre-selects `Khác`. User can change it before saving.

**Starter library:**
| Keyword | Category | Weight |
|---|---|---|
| đồ ăn / ăn / trà sữa / cà phê | Ăn uống | 10 / 6 / 6 / 6 |
| điện / nước / internet / xăng | Thiết yếu | 10 / 10 / 10 / 9 |
| grab / xe / vé | Thiết yếu | 7 |
| học phí / school | Thiết yếu | 8 |
| bàn phím / keycap / switch | Sở thích | 9 |
| tai nghe / chuột / mouse | Sở thích | 9 |
| bố mẹ / ba mẹ | Chu cấp | 10 |
| lương / freelance | Tự kiếm | 10 |

Editable in Settings (JSON), so the library grows without a rebuild.

---

## 10. Calculations

Monthly is the unit (weekly removed). All amounts VND.

| Output | Definition |
|---|---|
| Total spending | Σ spending in the selected month |
| Total earning | Σ earning in the selected month |
| Net | earning − spending |
| % difference vs previous month | per metric (spending, earning, net) |
| Bar chart | selected month vs previous month, side by side |
| Pie data | per-category sums (spending; earning) |
| Year total | Σ for the calendar year (spending, earning, net) |

Transfers are excluded from all of the above (they only move money between wallets), and so are **imported** transactions — those are archive-only and appear only in the transaction list (§11). No advice/recommendation text anywhere.

---

## 11. CSV import / export

Fully offline — reads/writes a file on device storage (or via the share sheet).

- **Export:** all transactions to a CSV. Suggested columns: `id, type, amount, description, wallet_from, wallet_to, category, timestamp`. Optionally a second CSV for wallets (`id, name, initial_balance, type`).
- **Import (merge by id):** rows whose `id` already exists are skipped (no duplicates); new rows are added. **Anything brought in via import is flagged `imported` on the receiving device and treated as archive-only** — viewable in the transaction list but excluded from wallet balances *and* from analytics (totals, pie, bar, year). The reason: the `initial_balance` you set on a new device already reflects all prior history, so re-applying merged transactions would double-count; and you asked for the old data purely to *view* the history, not to fold it back into the stats. Malformed rows are skipped/flagged.
  - *Scenario this protects:* log 3 months on the old phone → idle → log on a new phone → later merge the old export. The old 3 months are browsable in your history, but current balances and current stats are untouched.
- This doubles as your only backup, so make it easy to trigger and easy to find the file.

---

## 12. Vietnamese UI strings (reference)

| EN | VN |
|---|---|
| Spending / Earning / Transfer | Chi tiêu / Thu nhập / Chuyển khoản |
| Amount / Description / Time | Số tiền / Mô tả / Thời gian |
| Wallet / From wallet / To wallet | Ví / Từ ví / Đến ví |
| Wallets / Transactions / Analytics / Settings | Ví / Giao dịch / Thống kê / Cài đặt |
| Quick Add | Thêm nhanh |
| Total spending / Total earning / Net | Tổng chi / Tổng thu / Chênh lệch |
| This month / Last month / Year | Tháng này / Tháng trước / Năm |
| Import / Export | Nhập / Xuất |

---

## 13. Design & branding

- **Theme:** Yellow primary, white/neutral surfaces for readability; high contrast on amounts and chart slices.
- **Logo:** a **yellow wallet** with **white padding inside** the mark. Provide a simple white silhouette version for the notification icon (Android tints it).
- **Tone:** light, uncluttered, fast — big tappable controls on Quick Add.

---

## 14. Build phases (ordered to get it on your phone fast)

| Phase | Deliverable | Why here |
|---|---|---|
| **P1 — Runnable core** | SQLite data layer · Wallets (add/edit + balance) · Quick Add with all 3 types incl. transfer · Transactions list with edit/delete · Monthly totals (chi/thu/net) · **CSV export+import** · Vietnamese UI | A genuinely usable, data-safe app on the phone ASAP |
| **P2 — Insight** | Two pie charts · month-over-month **bar chart** + % difference · year total · keyword **suggestions** in the form | Adds the visual analytics |
| **P3 — Fast capture** | Home-screen **widget** · persistent notification (+ optional direct reply) · Quick Settings tile | The fast-input layer |
| **P4 — Polish** | Final yellow theme + logo · keyword library editor · edge cases | Finishing |

> Note: CSV is in P1 on purpose — it's cheap and it's your only backup, so it should exist before you accumulate real data.

---

## 15. Getting it on your phone (fast path, no Play Store)

Single-user, so you don't need the Play Store. With Flutter:
1. On the phone: enable **Developer options** → turn on **USB debugging**.
2. Dev loop: connect via USB and run `flutter run` for hot-reload while building.
3. Standalone install: `flutter build apk --release`, then install the generated APK directly on the phone.
4. Android 13+ will prompt once for **notification permission**; no internet permission is requested (reinforces fully-offline).

This is what "P1 runnable on device" means in practice — you can be hot-reloading on the actual phone from day one.

---

## 16. Technical notes (suggested)

- **Stack:** Flutter/Dart (fits your background) for UI + charts + DB. The **widget, notification actions, and QS tile in P3 need some native Android (Kotlin) glue** via platform channels (`home_widget` helps for the widget; `flutter_local_notifications` for notification actions). A fully native Kotlin app would do P3 most cleanly if you'd rather skip the glue.
- **Storage:** SQLite (Drift/sqflite) — fully offline.
- **Charts:** `fl_chart` (pie + bar) or similar offline lib.
- **CSV:** any local CSV lib + device file storage / share intent.

---

## 17. Resolved decisions

| # | Decision |
|---|---|
| 1 | Min Android version: **Android 10 (API 29)** |
| 2 | App name: **MyFinance** |
| 3 | Transfer fields: **from / amount / to only** (no description, no category) |
| 4 | Imported CSV history: **archive-only** — viewable in the transaction list, excluded from balance and analytics |

---

*End of scope document.*
