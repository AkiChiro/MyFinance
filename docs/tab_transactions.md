# Giao dịch Tab — Developer Reference

File: `lib/ui/transactions_page.dart`

## Overview

The Giao dịch tab shows transactions with a month-mode toggle, a multi-filter bar, a bank-capture banner, and a list. Each tile supports tap-to-edit (non-imported), long-press action sheet, and delete-via-action-sheet. Swipe-to-delete was removed — delete is now action-sheet only.

## Widget tree

```
TransactionsPage (ConsumerStatefulWidget)
  └─ _TransactionsPageState
     └─ StreamBuilder<List<AppCategory>>  (repo.watchAllCategories())
        └─ Column
           ├─ _buildFilterBar (SingleChildScrollView of chips)
           ├─ StreamBuilder<int>   (repo.pendingCaptureCount()) — captures banner
           └─ Expanded
              └─ StreamBuilder<List<Wallet>>  (repo.watchWallets())
                 └─ StreamBuilder<List<Txn>>  (repo.watchTxns())
                    └─ AnimatedSwitcher (200ms cross-fade, keyed 'empty'/'list')
                       ├─ _TxnsEmpty (icon + message — parity with Ví tab's _Empty)
                       └─ ListView.builder
                          └─ _TxnTile × N
```

`watchAllCategories()` is the **outermost** stream so the filter bar and the tile label map share the same snapshot without redundant subscriptions.

The old `FutureBuilder<Map<String,int>>` for `categoryThresholds` was removed — auto-star is now written to the DB at creation/edit time, so there is no need to evaluate thresholds at render time.

Month navigation (`← Tháng X/YYYY →`) lives in **`HomePage`'s AppBar**, not in this page. `TransactionsPage` writes to `monthModeProvider` and reads from `selectedMonthProvider`; `HomePage` reads both to show or hide the AppBar actions.

## State

### Local (`_TransactionsPageState`)

| Field | Type | Default | Purpose |
|-------|------|---------|---------|
| `_sortDirection` | `String?` | `null` | `null` = newest-first, `'asc'` = amount low→high, `'desc'` = amount high→low |

The only remaining local filter field — it reorders but never hides rows, so no other screen needs to read or write it.

### Riverpod providers (`lib/providers.dart`)

| Provider | Type | Default | Purpose |
|----------|------|---------|---------|
| `monthModeProvider` | `StateProvider<bool>` | `false` | whether month filter is active; written by TransactionsPage and AnalyticsPage (drill-down), read by TransactionsPage and HomePage |
| `selectedMonthProvider` | `StateProvider<DateTime>` | current month | the month to display; written by HomePage AppBar buttons and AnalyticsPage (drill-down), read by TransactionsPage |
| `txnTypeFilterProvider` | `StateProvider<String?>` | `null` | filter by `TxTypes.spending` / `.earning`; null = all |
| `txnCategoryFilterProvider` | `StateProvider<String?>` | `null` | filter to one category ID; null = all |
| `txnStarredOnlyProvider` | `StateProvider<bool>` | `false` | show only starred txns (`txn.starred == true`) |

`_starredOnly`/`_typeFilter`/`_categoryFilter` used to be local `State` here; they were lifted to providers so `AnalyticsPage` can drive them directly for drill-down navigation (see `docs/architecture.md`'s "Analytics drill-down" section) — same reasoning as `monthModeProvider`/`selectedMonthProvider`. `txnCategoryFilterProvider` is cleared to `null` whenever `txnTypeFilterProvider` changes (same reset-on-type-change behavior as before, now expressed at each write site instead of via one `setState`).

## Filter bar (`_buildFilterBar`)

Horizontal `SingleChildScrollView` containing a `Row` of chips:

| Chip | Type | Behaviour |
|------|------|-----------|
| Tất cả / Tháng | `ChoiceChip` | **Dual behaviour**: if not selected (typeFilter≠null) → clears `txnTypeFilterProvider`/`txnCategoryFilterProvider`; if already selected (typeFilter==null) → toggles `monthModeProvider`. Label shows "Tháng" when month mode is on, "Tất cả" otherwise. |
| Chi tiêu / Thu nhập | combined type+category `ChoiceChip` (built by the `typeCategoryChip` helper local to `_buildFilterBar`) — see below | |
| Có sao ⭐ | `FilterChip` | toggles `txnStarredOnlyProvider` |
| Số tiền | `FilterChip` | cycles `_sortDirection` through `null → 'asc' → 'desc' → null` |

The "Số tiền" chip label changes to "Số tiền ↑" (`asc`) or "Số tiền ↓" (`desc`) when active. Its `selected` state is `_sortDirection != null`.

### Combined type+category chip (`typeCategoryChip`)

Replaces what used to be three separate elements (Chi tiêu `ChoiceChip`, Thu nhập `ChoiceChip`, and a conditional standalone Danh mục `FilterChip` that only appeared once a type was active) with one `ChoiceChip` per type that does double duty:

- **Inactive** (`txnTypeFilterProvider != type`): label is just the type name ("Chi tiêu"/"Thu nhập"), no arrow, `showCheckmark: false`.
- **First tap** (was inactive): activates — sets `txnTypeFilterProvider = type`, clears `txnCategoryFilterProvider` — and the label gains a trailing `Icons.arrow_drop_down`.
- **Second tap** (already active): opens `_pickCategory(context, categoriesForType)` instead of toggling — `categoriesForType` is computed per chip from that chip's own fixed `type` (not the currently-selected filter), since the picker can only ever open for the type that's already active.
- After picking, the label switches from the type name to the picked category's label (arrow stays); picking "Tất cả" in the picker clears `txnCategoryFilterProvider` back to the plain type label.

Switching to the other type chip deactivates this one and discards its category (same reset-on-type-change as the old separate chips).

### `_pickCategory(context, cats)`

`showDialog<List<String?>>` with a `SimpleDialog`. Returns a one-element list so that `null` return (dialog dismissed) is distinguishable from `[null]` (user picked "Tất cả") and `[id]` (user picked a category). Writes `txnCategoryFilterProvider.notifier).state = picked[0]` on result — unchanged apart from writing a provider instead of calling `setState`.

## Filter and sort application

Applied in order just before building `ListView`:

```dart
final monthMode = ref.watch(monthModeProvider);
final selectedMonth = ref.watch(selectedMonthProvider);
final starredOnly = ref.watch(txnStarredOnlyProvider);
final typeFilter = ref.watch(txnTypeFilterProvider);
final categoryFilter = ref.watch(txnCategoryFilterProvider);
if (monthMode)        txns = txns.where((t) =>
    t.timestamp.year == selectedMonth.year &&
    t.timestamp.month == selectedMonth.month).toList();
if (starredOnly)       txns = txns.where((t) => t.starred).toList();
if (typeFilter != null) txns = txns.where((t) => t.type == typeFilter).toList();
if (categoryFilter != null) {
  txns = txns.where((t) {
    final effectiveCat = t.category ?? (t.type == TxTypes.earning ? 'others_earn' : 'others');
    return effectiveCat == categoryFilter;
  }).toList();
}
if (_sortDirection == 'asc')  txns = [...txns]..sort((a, b) => a.amount.compareTo(b.amount));
if (_sortDirection == 'desc') txns = [...txns]..sort((a, b) => b.amount.compareTo(a.amount));
```

`watchTxns()` always returns transactions newest-first. Sort-by-amount creates a fresh sorted copy without mutating the stream snapshot.

Month filtering is done in Dart for consistency with all other filters. With typical personal-finance data sizes this is fast enough.

**Category-coalescing fix**: the category match treats a null `category` as belonging to its type's synthetic "Khác" bucket (`'others'`/`'others_earn'`) rather than requiring an exact string match. This mirrors `_buildAnalyticsBundle`'s own `COALESCE(category, 'others'|'others_earn')` exactly — without it, filtering (or drilling down from Thống kê) by "Khác" would silently omit transactions left uncategorized via `CaptureConfirmPage`'s "— Bỏ qua —" option, even though the analytics total for that slice already included them.

## Captures banner

```dart
StreamBuilder<int>(
  stream: repo.pendingCaptureCount(),
  builder: (context, snap) {
    if (count == 0) return const SizedBox.shrink();
    return Card(color: scheme.primaryContainer, child: ListTile(...));
  },
)
```

Reactive — disappears automatically when `pendingCaptureCount` drops to 0.

## `_TxnTile` (ConsumerWidget)

### Data received

| Parameter | Type | Purpose |
|-----------|------|---------|
| `txn` | `Txn` | the transaction |
| `walletName` | `String Function(String id)` | live name resolver |
| `catLabels` | `Map<String,String>` | `{categoryId → label}` from DB |

The `thresholds` parameter was removed — star state is now stored in `txn.starred` directly.

### Title logic

- Transfer: `"sourceWalletName → destWalletName"` (using `resolveWallet`)
- Non-transfer with description: the description string
- Non-transfer without description: the category label

`resolveWallet(id, snapshot)`: tries live name first; if the wallet was deleted (returns `l10n.txnsOtherWallet`), falls back to the snapshot name stored in `walletFromName`/`walletToName`.

### Amount display

- Transfer: formatted absolute VND (no sign), amount text in `scheme.primary`
- Spending: `−amount` in error color
- Earning: `+amount` in green

### Icon color vs. amount color

The leading `CircleAvatar`/icon and the trailing amount text are colored **independently** (warm-redesign change): the icon uses `spendColor(txn.category)`/`earnColor(txn.category)` from `lib/ui/category_colors.dart` (the same 7-color palette as the Thống kê pie charts — transfer keeps `scheme.primary`), while the amount text keeps the semantic red/green/blue by type. This means a food-spending row's icon is amber-ish and a necessities-spending row's icon is orange-ish, but both amounts stay error-red — spend-vs-earn is still a 1-glance scan via the number, category is a secondary glance cue via the icon. User-created categories (UUID ids) fall back to grey.

### Star display

A filled `Icons.star` in amber is shown when `txn.starred == true`. There is no longer an outlined star for "auto-star" — auto-star is now written to the `starred` column at transaction creation or when amount changes (see star unification below).

### No `Dismissible`

Swipe-to-delete was removed. Delete is now only accessible via the long-press action sheet. This prevents accidental deletion when the user is trying to scroll or swipe between tabs.

### `onTap`

Opens `QuickAddPage(editing: txn)`. Disabled for imported transactions (`onTap: txn.imported ? null : ...`).

### `_showActionSheet(context, repo)`

`showModalBottomSheet` with:
- **Sửa** (non-imported only) → pushes `QuickAddPage(editing: txn)`
- **Đánh dấu sao / Bỏ đánh dấu sao** (non-imported only): icon and label reflect `txn.starred`. Toggle action: `repo.toggleStar(txn)`.
- **Xoá** → AlertDialog → `repo.deleteTxn(txn.id)`

### `_catLabel(String? id) → String`

Resolves from `catLabels` map. Falls back to `Categories.label(id)` for archived categories still referenced by old transactions.

## Star unification

The old dual-star model (outlined auto-star computed at render time, filled manual star stored in DB) was replaced with a single unified `starred` flag stored in the DB.

**At creation** (`addSpending` / `addEarning`): the repository checks if `amount > threshold[category]` (only if `autostarEnabled = true` from settings). If exceeded, `starred = true` is written on insert, regardless of the user's manual toggle. User can still manually star via the `SwitchListTile` in `QuickAddPage` — the effective value is `starred_from_ui || auto_star`.

**On edit** (`updateTxn`): if the transaction amount changed, the threshold is re-checked. If exceeded, `starred = true` is forced on the updated row. If the amount did not change, `starred` keeps whatever value the user set in the UI.

**Manual unstar**: the user can always long-press → "Bỏ đánh dấu sao" to clear `starred` after auto-starring. There is no auto-clear — the threshold only fires at creation or when amount changes.

`autostarEnabled` is read from `AppSettings` in `QuickAddPage._save()` and passed to the repository methods. The Settings toggle "Bật tự động đánh dấu sao" controls whether this threshold check fires.

The `isAutoStarred()` pure function in `finance_repository.dart` is retained but no longer called in the UI render path.

## `_Chip` widget

Tiny label chip for "đã nhập" badge on imported transactions. `surfaceContainerHighest` background, `labelSmall` text.

## Key repository calls

| Call | Effect |
|------|--------|
| `repo.pendingCaptureCount()` | stream of pending capture count |
| `repo.watchAllCategories()` | stream of all categories (including archived) |
| `repo.watchWallets()` | stream of wallets for name map |
| `repo.watchTxns()` | stream of all transactions newest-first |
| `repo.deleteTxn(id)` | deletes one transaction |
| `repo.toggleStar(txn)` | flips `txn.starred` |
