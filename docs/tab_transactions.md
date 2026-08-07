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
| `_starredOnly` | `bool` | `false` | show only starred txns (`txn.starred == true`) |
| `_typeFilter` | `String?` | `null` | filter by `TxTypes.spending` / `.earning`; null = all |
| `_categoryFilter` | `String?` | `null` | filter to one category ID; null = all |
| `_sortDirection` | `String?` | `null` | `null` = newest-first, `'asc'` = amount low→high, `'desc'` = amount high→low |

`_categoryFilter` resets to null whenever `_typeFilter` changes.

### Riverpod providers (`lib/providers.dart`)

| Provider | Type | Default | Purpose |
|----------|------|---------|---------|
| `monthModeProvider` | `StateProvider<bool>` | `false` | whether month filter is active; written by TransactionsPage, read by both TransactionsPage and HomePage |
| `selectedMonthProvider` | `StateProvider<DateTime>` | current month | the month to display; written by HomePage AppBar buttons, read by TransactionsPage |

## Filter bar (`_buildFilterBar`)

Horizontal `SingleChildScrollView` containing a `Row` of chips:

| Chip | Type | Behaviour |
|------|------|-----------|
| Tất cả / Tháng | `ChoiceChip` | **Dual behaviour**: if chip is not selected (typeFilter≠null) → clears `_typeFilter` and `_categoryFilter`; if chip is already selected (typeFilter==null) → toggles `monthModeProvider`. Label shows "Tháng" when month mode is on, "Tất cả" otherwise. |
| Chi tiêu | `ChoiceChip` | sets `_typeFilter = TxTypes.spending`, clears `_categoryFilter` |
| Thu nhập | `ChoiceChip` | sets `_typeFilter = TxTypes.earning`, clears `_categoryFilter` |
| Có sao ⭐ | `FilterChip` | toggles `_starredOnly` |
| Danh mục | `FilterChip` | shown only when `_typeFilter != null`; taps to `_pickCategory()` |
| Số tiền | `FilterChip` | cycles `_sortDirection` through `null → 'asc' → 'desc' → null` |

The "Danh mục" chip label shows the current category name when `_categoryFilter != null`, otherwise "Danh mục".

The "Số tiền" chip label changes to "Số tiền ↑" (`asc`) or "Số tiền ↓" (`desc`) when active. Its `selected` state is `_sortDirection != null`.

### `_pickCategory(context, cats)`

`showDialog<List<String?>>` with a `SimpleDialog`. Returns a one-element list so that `null` return (dialog dismissed) is distinguishable from `[null]` (user picked "Tất cả") and `[id]` (user picked a category). Sets `_categoryFilter = picked[0]` on result.

## Filter and sort application

Applied in order just before building `ListView`:

```dart
final monthMode = ref.watch(monthModeProvider);
final selectedMonth = ref.watch(selectedMonthProvider);
if (monthMode)           txns = txns.where((t) =>
    t.timestamp.year == selectedMonth.year &&
    t.timestamp.month == selectedMonth.month).toList();
if (_starredOnly)        txns = txns.where((t) => t.starred).toList();
if (_typeFilter != null) txns = txns.where((t) => t.type == _typeFilter).toList();
if (_categoryFilter != null) txns = txns.where((t) => t.category == _categoryFilter).toList();
if (_sortDirection == 'asc')  txns = [...txns]..sort((a, b) => a.amount.compareTo(b.amount));
if (_sortDirection == 'desc') txns = [...txns]..sort((a, b) => b.amount.compareTo(a.amount));
```

`watchTxns()` always returns transactions newest-first. Sort-by-amount creates a fresh sorted copy without mutating the stream snapshot.

Month filtering is done in Dart for consistency with all other filters. With typical personal-finance data sizes this is fast enough.

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
