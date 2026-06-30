## MyFinance

Offline, Vietnamese, VND-only personal finance tracker for Android.
Full implementation of all four scope phases (P1–P4).

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

> `make init` runs `flutter create --platforms=android .`, patches `minSdk` to 29,
> copies the `android_overlay/` directory into `android/` (widget XML, notification
> icon, custom `MainActivity.kt`, `WidgetProvider.kt`), patches `AndroidManifest.xml`
> to register the widget receiver and `POST_NOTIFICATIONS` permission, then runs
> `flutter pub get`.

### Codegen note (Drift)

The database uses Drift, which generates `lib/data/database.g.dart` from the
table definitions. `make apk` / `make run` run this for you via
`dart run build_runner build`. If you edit the tables, re-run `make gen`.

### What's implemented

**P1 — Core**
- **Ví** — add wallets with a starting balance; live balances; long-press to delete.
- **Thêm nhanh** — `Chi tiêu` / `Thu nhập` / `Chuyển khoản`. Description suggests a
  category (you confirm it). Time auto-filled, editable. Spending/transfer that
  would overdraw a wallet is blocked with **"Hãy kiểm tra lại số tiền thực tế"**.
- **Giao dịch** — list, tap to edit, swipe to delete. Imported rows tagged "đã nhập"
  are view-only.
- **Cài đặt** — CSV export (transactions + wallets) and merge-by-id import.
  Imported transactions are **archive-only**: excluded from balances and analytics.

**P2 — Analytics (Thống kê)**
- Month picker with previous/next navigation.
- Summary cards: total spending, total earning, net difference + % change vs last month.
- Dual pie charts: spending by category, earning by category (touch for details).
- Side-by-side bar chart: this month vs previous month for spending and earning.
- Year-to-date totals (spending, earning, net).

**P3 — Fast capture**
- Persistent low-priority notification with **Chi tiêu / Thu nhập / Chuyển khoản**
  action buttons — each opens Quick Add pre-selected to the right type.
- Home-screen widget (`android_overlay/`) with the same three buttons.
  Deep-links via `MYFINANCE_QUICK_ADD` intent → `MainActivity` → `HomeWidget`
  shared prefs → Flutter `HomeWidget.getWidgetData`.

**P4 — Polish**
- Keyword library editor in Cài đặt: view, add, delete rules; saved to
  `getApplicationDocumentsDirectory()/keywords.json` (persists across restarts,
  takes priority over the bundled `assets/keywords.json`).
- Yellow M3 theme throughout; wallet silhouette notification icon (`ic_notif.xml`).

### Layout

```
lib/
  main.dart                          app entry, theme, routes, notification init
  format.dart                        VND + date formatting
  models/domain.dart                 types, categories (VN labels)
  data/database.dart                 Drift tables: Wallets, Txns
  repositories/finance_repository.dart  balance math, overspend guard, CRUD,
                                        analytics (categoryTotals, monthTotal, yearTotal)
  services/category_suggester.dart   weighted-keyword suggestion + loadRaw/saveAndReload
  services/csv_service.dart          export / merge-import
  services/notification_service.dart persistent notification, navigatorKey
  ui/home_page.dart                  4-tab nav + FAB + home_widget listener
  ui/wallets_page.dart
  ui/transactions_page.dart
  ui/quick_add_page.dart             accepts initialType for deep-link pre-selection
  ui/analytics_page.dart             P2 charts
  ui/settings_page.dart              CSV + keyword editor (P4)
assets/keywords.json                 default keyword → category weights (editable in app)
android_overlay/                     merged into android/ by `make init`
  app/src/main/kotlin/…/MainActivity.kt   handles MYFINANCE_QUICK_ADD intent
  app/src/main/kotlin/…/WidgetProvider.kt home-screen widget
  app/src/main/res/layout/myfinance_widget.xml
  app/src/main/res/xml/myfinance_widget_info.xml
  app/src/main/res/drawable/ic_notif.xml  notification icon (white silhouette)
  app/src/main/res/drawable/widget_background.xml
```

### Design choices worth knowing

- **UUID primary keys** (not autoincrement) so CSV merge-by-id is safe across
  devices — two phones won't both mint `id = 1`.
- **Balance** = wallet's initial balance + net of **non-imported** transactions.
  Imported history never moves a balance (the scope's cross-device merge rule).
- **Analytics excludes imports and transfers** — only native spending/earning
  transactions appear in charts and month totals.
- **Keyword library** is loaded from the docs directory first (user-edited), falling
  back to the bundled asset. Edits apply immediately without restarting.
