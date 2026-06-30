## MyFinance (P1)

Offline, Vietnamese, VND-only personal finance tracker for Android. This is the
**P1 scaffold** from the scope doc: data layer, wallets, quick add (with
transfers + overspend guard), transaction list/edit, and CSV import/export.

### Why there's no prebuilt APK in here

An APK has to be *compiled* with the Flutter + Android SDK, and those toolchains
weren't available where this project was generated. So instead you get the full
source plus a Makefile — `make apk` builds the installable APK on your machine in
one command. Same end result, and you can rebuild any time you change something.

### Build it (one time)

```
make init      # creates the android/ folder and sets minSdk = 29
make apk       # runs Drift codegen, then builds the release APK
```

APK lands at: `build/app/outputs/flutter-apk/app-release.apk`

Install on the phone (USB debugging on):

```
make install   # build + push to the connected device
# or just:  make run   for hot-reload development
```

> `make init` runs `flutter create --platforms=android .` to materialize the
> Android project (your `pubspec.yaml` is backed up and restored around it), then
> patches `minSdk` to 29 and the app label to "MyFinance".

### Codegen note (Drift)

The database uses Drift, which generates `lib/data/database.g.dart` from the
table definitions. `make apk` / `make run` run this for you via
`dart run build_runner build`. If you edit the tables, re-run `make gen`.

### What's in P1

- **Ví** — add wallets with a starting balance; live balances; long-press to delete.
- **Thêm nhanh** — `Chi tiêu` / `Thu nhập` / `Chuyển khoản`. Description suggests a
  category (you confirm it). Time auto-filled, editable. Spending/transfer that
  would overdraw a wallet is blocked with **"Hãy kiểm tra lại số tiền thực tế"**.
- **Giao dịch** — list, tap to edit, swipe to delete. Imported rows are tagged
  "đã nhập" and are view-only.
- **Cài đặt** — CSV export (transactions + wallets) and merge-by-id import.
  Imported transactions are **archive-only**: excluded from balances and (future)
  analytics.

### Not in P1 (next phases)

- Pie charts + month-over-month bar chart + year total (P2)
- Home-screen widget / notification quick-add (P3)
- Keyword-library editor, final logo (P4)

### Layout

```
lib/
  main.dart                      app entry, theme (yellow), vi locale
  format.dart                    VND + date formatting
  models/domain.dart             types, categories (VN labels)
  data/database.dart             Drift tables: Wallets, Txns
  repositories/finance_repository.dart   balance math, overspend guard, CRUD
  services/category_suggester.dart       weighted-keyword category suggestion
  services/csv_service.dart      export / merge-import
  ui/home_page.dart              bottom nav + FAB
  ui/wallets_page.dart
  ui/transactions_page.dart
  ui/quick_add_page.dart
  ui/settings_page.dart
assets/keywords.json             editable keyword -> category weights
```

### Design choices worth knowing

- **UUID primary keys** (not autoincrement) so CSV merge-by-id is safe across
  devices — two phones won't both mint `id = 1`.
- **Balance** = wallet's initial balance + net of **non-imported** transactions.
  Imported history never moves a balance (the scope's cross-device merge rule).
