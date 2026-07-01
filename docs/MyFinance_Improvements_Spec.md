# MyFinance — Improvements Spec (hand-off to Claude Code)

> **How to use this doc:** Each feature is self-contained with *Goal → Design →
> Files/Schema → Acceptance*. Build in the order in §13 unless told otherwise.
> Code references point at the original P1 scaffold (lib/…); the app has moved
> since (2 Claude Code sessions). Treat paths as indicative — match them to the
> **current** code, don't assume the scaffold is untouched.

---

## 0. Confirmed decisions (no open questions — build as written)

1. **"Mô tả" = user-editable categories.** The user manages their own categories
   (add a label, give it an auto-star threshold). Today's fixed set
   (Thiết yếu / Ăn uống / Sở thích / Khác, etc.) becomes the seeded default that
   they can extend. Auto-star thresholds are keyed to these categories; "đồ ăn"
   in the request = the **Ăn uống (food)** category. Implement §7 in full
   (Categories table). There is no "description-only" fallback to consider.

2. **Currency = display label only.** Changing it just swaps the symbol shown
   next to amounts (e.g. `đ`). **No conversion, no decimals, no FX, no DB type
   change** — amounts remain whole-number integers exactly as stored. The current
   UI shows `đ`, so that's the default. §9 is a one-string cosmetic setting.

---

## 1. Settings & persistence backbone *(build this first — §5–§9 depend on it)*

**Goal.** One reactive, persisted settings object the whole app reads from.

**Design.**
- Add `shared_preferences` (scalars + small JSON blobs) for settings; keep
  **Drift** for transactional data only.
- `lib/services/app_settings.dart` → `class AppSettings extends ChangeNotifier`.
  Loads once at startup, exposes typed getters, persists on every setter, calls
  `notifyListeners()`.
- Mirror the existing global pattern (`repository`, `suggester` in `main.dart`):
  add a global `late AppSettings settings;`, init in `main()` **before**
  `runApp`.
- Wrap `MaterialApp` in a `ListenableBuilder(listenable: settings, …)` so
  **theme, locale, currency, and background changes rebuild live** without a
  restart.
- Image-type settings (custom icons, backgrounds) are stored as **file paths**
  into the app documents dir, not as prefs blobs. Copy picked files into
  `…/app_documents/customization/` and persist the path.

**Settings keys (initial set).**
```
ui.locale            = "vi" | "en"                  (default "vi")
currency.symbol      = "đ"                           (default; display label only)
currency.suffix      = true                          (symbol after amount)
autostar.enabled     = true        (per-category thresholds live on the
                                    Categories table — see §7, not here)
theme.mode           = "system" | "light" | "dark"   (default "system")
theme.seedColor      = 0xFFFFC107                     (ARGB int, amber)
theme.background     = {"type":"color","value":"0xFFFFFDF5"}  (or image path)
icons.<slotId>       = "<file path>" | null           (per slot, see §9)
```

**Acceptance.** Changing any setting persists across app restarts and updates the
UI immediately (no manual restart).

---

## 2. Database migration v1 → v2 *(needed by §3, §4, §5)*

Bump `schemaVersion` in `AppDatabase` to **2** and add a migration. **Must not
wipe existing on-device data.**

**Txns — add columns:**
- `starred` BOOL, default `false` — *manual* star (user bookmark). Auto-star is
  **computed at read time, never stored** (see §5).
- `walletFromName` TEXT nullable — display snapshot for imported rows.
- `walletToName` TEXT nullable — display snapshot for imported rows.

Also add the **Categories table** in this same migration — see §7 for its
schema and seeding.

```dart
@override
int get schemaVersion => 2;

@override
MigrationStrategy get migration => MigrationStrategy(
  onCreate: (m) => m.createAll(),
  onUpgrade: (m, from, to) async {
    if (from < 2) {
      await m.addColumn(txns, txns.starred);
      await m.addColumn(txns, txns.walletFromName);
      await m.addColumn(txns, txns.walletToName);
    }
  },
);
```

**Acceptance.** Upgrading an existing install keeps all wallets/transactions and
their balances; new columns default cleanly.

---

## 3. Notifications + home-screen widget (FIX) — *highest priority*

**Symptom reported:** no permission prompt; even after enabling notifications
manually in Android settings, **no notification or widget appears for input
outside the app.**

**Root causes to check (most likely first).**
1. **No runtime permission request.** Android 13+ (API 33) requires asking for
   `POST_NOTIFICATIONS` at runtime — a manifest entry alone does nothing, and a
   notification will silently fail to show. Add the request on first launch +
   re-trigger from a Settings toggle. (`permission_handler` or
   `flutter_local_notifications`’ Android `requestNotificationsPermission()`.)
2. **Nothing actually posts an ongoing notification.** A "quick-add"
   notification must be *posted* (and re-posted) — typically an **ongoing /
   foreground** notification so it survives outside the app. Confirm there's a
   code path that posts it on app start and after boot, not just a definition.
3. **Home-screen widget needs native Android code.** Flutter cannot render a
   home-screen widget; it requires a native `AppWidgetProvider` (Kotlin) +
   `RemoteViews`, bridged via the **`home_widget`** package. If the widget was
   attempted in pure Dart, that's why it never appears. The widget itself can't
   host a multi-field form — its buttons must **deep-link into the app's Quick
   Add**, pre-focused (this matches the original scope note).
4. **Manifest registration / boot.** The `AppWidgetProvider` receiver must be
   declared in `AndroidManifest.xml`; for the notification to come back after a
   reboot, add a `BOOT_COMPLETED` receiver (`RECEIVE_BOOT_COMPLETED`).
5. **OEM battery optimization** (common on phones sold in VN: Xiaomi/Oppo/Vivo/
   Samsung) kills background posters. Document that the user may need to allow
   "autostart" / disable battery optimization for the app.

**Design.**
- Packages: `flutter_local_notifications` (ongoing notification + action
  buttons + Android `RemoteInput` direct-reply), `home_widget` (widget bridge),
  `permission_handler` (runtime perms).
- **Deep-link scheme** for all entry points → Quick Add with a preset type:
  `myfinance://add?type=spending|earning|transfer`. Handle it in `main()` /
  route layer and push `QuickAddPage` with the type pre-selected.
- **Notification:** one ongoing notification, title "MyFinance", with action
  buttons **Chi tiêu / Thu nhập** (and optionally a direct-reply field that
  accepts a bare amount → opens Quick Add prefilled). Tapping an action fires the
  deep link.
- **Widget (native):** a small 2–3 button widget (Chi tiêu / Thu nhập / +) whose
  buttons launch the deep link. Provide a default 2×1 and 4×1 layout.
- **Settings:** a "Thông báo nhập nhanh" toggle (requests permission + posts/
  cancels the notification) and a short help line about battery optimization.

**Acceptance.**
- First launch prompts for notification permission (API 33+).
- With it enabled, the ongoing notification is visible from the lock/home screen;
  its buttons open Quick Add with the right type pre-selected.
- A home-screen widget can be added; its buttons open Quick Add.
- Both survive a device reboot.
- If permission is denied, Settings explains how to enable it and the toggle
  reflects real state.

> Note: I don't have your current Claude Code implementation of this, so the
> above is requirements + root-cause checklist, not a line-edit. Start by
> verifying which of causes 1–5 is actually hitting.

---

## 4. Long-press action sheet on a transaction (Giao dịch)

**Goal.** Holding a transaction card opens a modal with actions (incl. a delete
**confirmation**). Also the natural home for the manual-star toggle (§5).

**Design.**
- In `transactions_page.dart`, add `onLongPress` to the tile → `showModalBottom
  Sheet` with: **Sửa** (push `QuickAddPage(editing: txn)`), **Đánh dấu sao /
  Bỏ đánh dấu** (toggle `starred`, §5), **Xoá** (→ confirm `AlertDialog` →
  `repository.deleteTxn`).
- Keep swipe-to-delete as the fast path, but the long-press **Xoá** must still
  show the confirm dialog (the user explicitly wants a confirm-on-hold).
- Imported (archive-only) rows: show **Xoá** only — no Sửa/sao (consistent with
  current view-only rule).

**Acceptance.** Long-press shows the sheet; delete asks for confirmation before
removing; edit/star route correctly; imported rows offer delete only.

---

## 5. Starred — manual + automatic

**Goal.** (a) Manually star/bookmark any transaction; (b) auto-star spending that
exceeds a per-category threshold; (c) filter the list to starred.

**Design — manual is stored, auto is computed; the UI shows a star if either is
true.** These are barely different in cost: manual star is the one stored boolean
from §2, and auto-star is *just an extra predicate function* — no new storage, no
write path, no migration beyond the manual flag. Keeping them separate (rather
than trying to make one field mean both) is what keeps it simple: auto-star
recomputes itself whenever amounts/categories/thresholds change, so there's
nothing to keep in sync.
- **Manual** = stored `Txns.starred` (§2). Toggled from the long-press sheet
  (§4). `repository.setStarred(id, bool)` / `toggleStar(id)`.
- **Auto** = *computed at read time, never stored.* For a row:
  `autoStar = type=='spending' && !imported && walletToId==null &&
   settings.autostarEnabled && amount > threshold(category)`.
  (`walletToId==null` enforces "spending and single", i.e. not a transfer.)
  The per-category threshold comes from that category's `threshold` field on the
  **Categories table** (§7) — a threshold of `0` means "never auto-star this
  category".
- **Tile rendering:** show a star when `starred || autoStar`. Optional polish:
  filled amber star for manual, outline amber for auto, so the user can tell
  which is which (tooltip "Vượt ngưỡng Ăn uống").
- **Filter:** add a filter control at the top of Giao dịch — `Tất cả` / `Có sao`
  (segmented or chips). "Có sao" shows rows where `starred || autoStar`.

```dart
// `thresholds` is a Map<categoryId, int> built once from the Categories table
// (the UI already loads categories to render the list).
bool isAutoStarred(Txn t, Map<String, int> thresholds, {required bool enabled}) {
  if (!enabled) return false;
  if (t.type != 'spending' || t.imported || t.walletToId != null) return false;
  final limit = thresholds[t.category] ?? 0;
  return limit > 0 && t.amount > limit;
}
```

**Settings UI.** A "Tự động đánh dấu sao" section: a master toggle + one editable
amount per category (label uses the category's Vietnamese name). The list is
driven by the Categories table (§7), so any category the user adds automatically
gets its own threshold field.

**Acceptance.** Manual star persists and is togglable; spending over its
category threshold shows a star without any write; turning the master toggle off
removes all auto-stars; the "Có sao" filter shows the union; editing a row's
amount/category updates its auto-star state on next render.

---

## 6. CSV import — three changes

Current `csv_service.dart` exports **two** files (txns + wallets) and
`importMerge` adds rows flagged `imported=true` (archive-only). Changes:

### 6a. Bump the CSV format so names survive a merge
Add `wallet_name` and `wallet_to_name` columns to the **transactions** CSV on
export. On import, write them into the new `walletFromName` / `walletToName`
columns (§2). **Name resolution order in the list:** live wallet by id → stored
snapshot name → `"(ví khác)"`. This makes merged rows show the real From/To
instead of "ví khác", with no need to import the other device's wallets into
your balance. Keep reading old CSVs that lack these columns (names just fall
back).

### 6b. Add "Replace entirely" import (new-device restore)
A second import mode that **wipes current data and restores the CSV as native
data** (so balances reconstruct exactly):
- Requires **both** CSVs (wallets + transactions) — wallets restore
  `initialBalance`; without them balances can't be rebuilt.
- **Destructive** → a clear confirm dialog ("Thao tác này sẽ xoá toàn bộ dữ liệu
  hiện tại và thay bằng dữ liệu trong file. Không thể hoàn tác.").
- Insert rows **preserving the `imported` flag from the CSV verbatim** (archive
  rows stay archive, native rows stay native) so the restored state matches the
  source device exactly. (Contrast with merge, which forces `imported=true`.)
- Implement `repository.csv.importReplace(walletsPath, txnsPath)`:
  transaction → `db.transaction(() async { delete all txns; delete all wallets;
  insert wallets; insert txns; })`.

### 6c. Clear copy on when to use which (Settings)
Two distinct buttons with explicit Vietnamese descriptions:
- **Nhập & gộp (giữ dữ liệu hiện tại)** — "Thêm lịch sử từ máy cũ vào máy đang
  dùng. Giao dịch nhập vào chỉ để xem lại — **không** tính vào số dư hay thống
  kê. Dùng khi bạn muốn ghép lịch sử mà không đụng tới số liệu hiện tại."
- **Khôi phục & thay thế (máy mới)** — "Xoá sạch dữ liệu hiện tại và khôi phục
  toàn bộ từ file sao lưu. Dùng khi cài lại app hoặc chuyển sang máy mới. **Cần
  cả 2 file** (ví + giao dịch)."

**Acceptance.** Merged rows display real From/To names; replace wipes + restores
with balances matching the source device; both modes have unambiguous,
non-interchangeable descriptions; replace requires explicit confirmation.

---

## 7. User-editable categories ("Mô tả")

**Goal.** Let the user add / rename / archive their own categories, each with an
auto-star threshold. The current fixed set becomes the seeded default.

**Design.**
- New Drift table `Categories` (id TEXT PK = uuid, label TEXT, kind TEXT
  `spending|earning`, threshold INT default 0, isDefault BOOL, archived BOOL
  default false, sortOrder INT). Seed it on first run from the current fixed set
  with these default auto-star thresholds (VND): **Thiết yếu 500.000 · Ăn uống
  100.000 · Sở thích 1.000.000 · Khác 200.000**; earning categories (Chu cấp /
  Tự kiếm / Khác) seed with threshold `0` (earning isn't auto-starred). Add the
  table in the §2 migration.
- Replace the hardcoded `Categories.forType()` in `models/domain.dart` with reads
  from this table. The Quick Add category dropdown, the keyword suggester's
  allowed set, and the §5 threshold list all read from it.
- **Referential safety:** a transaction stores `category` = category **id**.
  Don't hard-delete a category that's in use — **soft-delete** via the `archived`
  flag (hidden from pickers, but old rows still resolve their label). Seeded
  defaults can be edited/archived but the seed should always be re-creatable.
- Settings → "Quản lý danh mục": list, add (label + kind + threshold), edit,
  archive.

**Acceptance.** User can add a category; it appears in Quick Add, the suggester's
allowed set, and the §5 auto-star thresholds; archiving a used category keeps
old transactions' labels intact; balances/exports are unaffected.

---

## 8. English UI support (UI strings only)

**Goal.** Toggle the whole app chrome between Vietnamese and English. User data
(typed descriptions, category labels they created) is **not** translated.

**Design.**
- Use Flutter's built-in `gen-l10n`: add `l10n.yaml`, `lib/l10n/app_vi.arb`
  (template) and `app_en.arb`. Generate `AppLocalizations`.
- `MaterialApp`: add `AppLocalizations.delegate`, `supportedLocales: [vi, en]`,
  and drive `locale:` from `settings.locale` (§1).
- Replace every hardcoded literal (e.g. "Thêm nhanh", "Chi tiêu", "Hãy kiểm tra
  lại số tiền thực tế", nav labels, dialog text) with `AppLocalizations.of(ctx)!
  .<key>`. **Extract all of them** — the scaffold has literals across
  `home_page`, `wallets_page`, `transactions_page`, `quick_add_page`,
  `settings_page`, and the `OverspendException` message.
- Settings → "Ngôn ngữ / Language": `Tiếng Việt` / `English`, persisted, applies
  live.

**Starter key map (extend to cover everything):**

| key | vi | en |
|---|---|---|
| nav_wallets | Ví | Wallets |
| nav_transactions | Giao dịch | Transactions |
| nav_settings | Cài đặt | Settings |
| action_add | Thêm | Add |
| quick_add_title | Thêm nhanh | Quick add |
| type_spending | Chi tiêu | Expense |
| type_earning | Thu nhập | Income |
| type_transfer | Chuyển khoản | Transfer |
| field_amount | Số tiền | Amount |
| field_description | Mô tả | Description |
| field_category | Danh mục | Category |
| overspend_error | Hãy kiểm tra lại số tiền thực tế | Check the actual balance |
| confirm_delete | Xoá giao dịch? | Delete transaction? |
| total_balance | Tổng số dư | Total balance |

**Acceptance.** Switching language re-renders all app chrome immediately; no
hardcoded Vietnamese remains in widgets; user-entered text is untouched.

---

## 9. Currency symbol (display label only)

**Goal.** Default `đ`; user can change the displayed symbol (e.g. to `$`) in
Settings. Pure relabel — no conversion, no decimals, amounts stay integers.

**Design.**
- Centralize in `format.dart`. Replace the fixed `formatVnd` with
  `formatMoney(int amount)` that reads `settings.currencySymbol` and
  `currency.suffix`:
  - suffix=true → `"100.000 đ"`; suffix=false → `"$ 100.000"`.
  - Grouping is unchanged (locale-driven `NumberFormat`); the integer value is
    never scaled or converted.
- Update every call site (`formatVnd` → `formatMoney`).
- Settings → "Đơn vị tiền tệ": a symbol text field + a prefix/suffix switch. The
  field is short (1–3 chars) and free-text, so the user can type whatever label
  they want.

**Acceptance.** Changing the symbol updates every amount in the app live; the
underlying number is never altered; default is `đ` as a suffix.

---

## 10. Custom theme / icons / backgrounds ("ricing")

**Goal.** Let the user restyle: component colors, the in-app icons, and view
backgrounds, with a sane default icon resolution so making icon packs is easy.

### 10a. Colors
- `theme.mode` (system/light/dark) + `theme.seedColor` (ARGB int). Build the
  scheme with `ColorScheme.fromSeed(seedColor: settings.seedColor, brightness:
  …)`, wired through the §1 `ListenableBuilder`. Default seed `0xFFFFC107`.
- Settings → a color picker (e.g. `flex_color_picker`) for the seed + a
  light/dark/system selector. (Optional later: override individual roles —
  primary/surface/onSurface — but seed-based is enough to start.)

### 10b. Custom icons (overridable slots)
- Define named icon **slots**; each can be a built-in Material icon (default) or
  a user image. Slots: `nav_wallets`, `nav_transactions`, `nav_settings`,
  `fab_add`, `type_spending`, `type_earning`, `type_transfer`, `wallet_cash`,
  `wallet_bank`, `star`.
- A central `AppIcon(slotId, size)` widget: if `settings.icons[slotId]` is a
  file path → `Image.file(...)`; else fall back to the built-in `IconData`.
- **Recommended icon resolution (document this in-app):** square PNG with
  transparency, **144×144 px** (crisp up to xxhdpi for a ~48dp slot); **96×96
  minimum**. Render slots at a fixed logical size (24–28dp nav, 24dp tiles) so
  user art lands predictably.
- Settings → "Biểu tượng": list slots, pick an image per slot (file picker →
  copy into `…/customization/icons/<slot>.png`), reset-to-default per slot and
  "reset all".

### 10c. View backgrounds
- `theme.background` = `{type: color|image, value}`; optionally per-view later,
  global to start.
- Wrap each page body in a `ThemedBackground` widget: color → plain fill; image →
  `DecorationImage(fit: cover)` with an adjustable **scrim** (semi-opaque
  overlay) so foreground text/cards stay readable. Expose a scrim-opacity slider.
- Settings → "Hình nền": pick color or image (copied into
  `…/customization/backgrounds/`), scrim slider, reset.

**Acceptance.** Seed color + light/dark apply live; any icon slot can be replaced
by a user PNG and reverts cleanly; a background color/image applies across views
with a readability scrim; the recommended icon size is shown in the UI; "reset
all" restores stock look.

---

## 11. Cross-cutting acceptance / regression guards

Whatever you build, these existing invariants **must still hold**:
- Balance = wallet `initialBalance` + net of **non-imported** transactions;
  imported rows never move a balance.
- Overspend guard rejects spending/transfer that would overdraw the source wallet
  (message respects the current locale + the §9 currency symbol).
- Transfers carry no category and are excluded from spending totals/auto-star.
- UUID primary keys preserved (don't reintroduce autoincrement — breaks CSV
  merge-by-id).
- Migration v1→v2 preserves all existing on-device data.

---

## 12. New dependencies (expected)

```
shared_preferences          # settings persistence (§1)
flutter_local_notifications # ongoing notification + actions (§3)
home_widget                 # native home-screen widget bridge (§3)
permission_handler          # runtime POST_NOTIFICATIONS (§3)
flex_color_picker           # color picker (§10a)  [or any picker]
# file_picker / path_provider already present
```

---

## 13. Suggested build order

1. **§1 Settings backbone** + **§2 DB migration** (everything leans on these; the
   migration also creates + seeds the §7 Categories table).
2. **§7 Categories** — wire `forType()` to the table + the "Quản lý danh mục" UI.
   Do this early because §5's thresholds and the Quick Add dropdown read from it.
3. **§3 Notifications/widget** (highest user priority; isolated, native-heavy).
4. **§4 Long-press sheet** + **§5 Starred** (manual + auto; share the sheet).
5. **§6 CSV import** (name snapshots, replace mode, copy).
6. **§8 Language** then **§9 Currency** (both flow through the §1 builder).
7. **§10 Theme/icons/backgrounds** (largest; do after the above are stable).

Steps 1–2 are one unit; after that each block can be its own Claude Code
session / PR.
