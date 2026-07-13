# Giao dịch Tab — Developer Reference

File: `lib/ui/transactions_page.dart`

## Overview

The Giao dịch tab shows transactions with a multi-filter bar, a bank-capture banner, and a list. Each tile supports tap-to-edit (non-imported), long-press action sheet, and delete-via-action-sheet. Swipe-to-delete was removed — delete is now action-sheet only.

## Widget tree

```
TransactionsPage (ConsumerStatefulWidget)
  └─ _TransactionsPageState
     └─ StreamBuilder<List<AppCategory>>  (repo.watchAllCategories())
        └─ Column
           ├─ _buildFilterBar (SingleChildScrollView of chips)
           ├─ StreamBuilder<int>   (repo.pendingCaptureCount()) — captures banner
           └─ Expanded
              └─ StreamBuilder<List<Wallet>>       (repo.watchWallets())
                 └─ FutureBuilder<Map<String,int>> (repo.categoryThresholds('spending'))
                    └─ StreamBuilder<List<Txn>>    (repo.watchTxns())
                       └─ ListView.builder / empty state
                          └─ _TxnTile × N
```

`watchAllCategories()` is the **outermost** stream so the filter bar and the tile label map share the same snapshot without redundant subscriptions.

## State

| Field | Type | Default | Purpose |
|-------|------|---------|---------|
| `_starredOnly` | `bool` | `false` | show only manually or auto-starred txns |
| `_typeFilter` | `String?` | `null` | filter by `TxTypes.spending` / `.earning`; null = all |
| `_categoryFilter` | `String?` | `null` | filter to one category ID; null = all |
| `_sortByAmount` | `bool` | `false` | sort by amount descending instead of timestamp descending |

`_categoryFilter` resets to null whenever `_typeFilter` changes.

## Filter bar (`_buildFilterBar`)

Horizontal `SingleChildScrollView` containing a `Row` of chips:

| Chip | Type | Behaviour |
|------|------|-----------|
| Tất cả | `ChoiceChip` | clears `_typeFilter` and `_categoryFilter` |
| Chi tiêu | `ChoiceChip` | sets `_typeFilter = TxTypes.spending`, clears `_categoryFilter` |
| Thu nhập | `ChoiceChip` | sets `_typeFilter = TxTypes.earning`, clears `_categoryFilter` |
| Có sao ⭐ | `FilterChip` | toggles `_starredOnly` |
| Danh mục | `FilterChip` | shown only when `_typeFilter != null`; taps to `_pickCategory()` |
| Số tiền ↕ | `FilterChip` | toggles `_sortByAmount` |

The "Danh mục" chip label shows the current category name when `_categoryFilter != null`, otherwise "Danh mục".

### `_pickCategory(context, cats)`

`showDialog<List<String?>>` with a `SimpleDialog`. Returns a one-element list so that `null` return (dialog dismissed) is distinguishable from `[null]` (user picked "Tất cả") and `[id]` (user picked a category). Sets `_categoryFilter = picked[0]` on result.

## Filter and sort application

Applied after all streams resolve, just before building `ListView`:

```dart
if (_starredOnly)       txns = txns.where((t) => t.starred || isAutoStarred(...)).toList();
if (_typeFilter != null) txns = txns.where((t) => t.type == _typeFilter).toList();
if (_categoryFilter != null) txns = txns.where((t) => t.category == _categoryFilter).toList();
if (_sortByAmount)       txns = [...txns]..sort((a, b) => b.amount.compareTo(a.amount));
```

`watchTxns()` always returns transactions newest-first; sort-by-amount creates a fresh sorted copy without mutating the snapshot.

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
| `thresholds` | `Map<String,int>` | per-category auto-star limits |
| `catLabels` | `Map<String,String>` | `{categoryId → label}` from DB |

### Title logic

- Transfer: `"sourceWalletName → destWalletName"` (using `resolveWallet`)
- Non-transfer with description: the description string
- Non-transfer without description: the category label

`resolveWallet(id, snapshot)`: tries live name first; if the wallet was deleted (returns "(ví khác)"), falls back to the snapshot name stored in `walletFromName`/`walletToName`.

### Amount display

- Transfer: formatted absolute VND (no sign)
- Spending: `−amount` in error color
- Earning: `+amount` in green

### Star display

`showStar = txn.starred || autoStar`. If `txn.starred`, shows filled star icon; if only `autoStar`, shows outlined star. Both are amber.

`autoStar` is computed in `build()` and passed into `_showActionSheet(context, repo, showStar: showStar)` so the action sheet reflects the same combined state.

### No `Dismissible`

Swipe-to-delete was removed. Delete is now only accessible via the long-press action sheet. This prevents accidental deletion when the user is trying to scroll or swipe between tabs.

### `onTap`

Opens `QuickAddPage(editing: txn)`. Disabled for imported transactions (`onTap: txn.imported ? null : ...`).

### `_showActionSheet(context, repo, {required bool showStar})`

`showModalBottomSheet` with:
- **Sửa** (non-imported only) → pushes `QuickAddPage(editing: txn)`
- **Đánh dấu sao / Bỏ đánh dấu sao** (non-imported only):
  - Icon and label reflect `showStar` (= `txn.starred || autoStar`), not just `txn.starred`.
  - Toggle action: `repo.toggleStar(txn)` — only flips the manual `starred` flag, auto-star is computed separately.
- **Xoá** → AlertDialog → `repo.deleteTxn(txn.id)`

**Why `showStar` not `txn.starred`:** The action sheet previously showed "Đánh dấu sao" even when a transaction was already auto-starred, which was visually inconsistent. Passing `showStar` unifies the icon/label to match the tile display.

### `_catLabel(String? id) → String`

Resolves from `catLabels` map. Falls back to `Categories.label(id)` for archived categories still referenced by old transactions.

## `_Chip` widget

Tiny label chip for "đã nhập" badge on imported transactions. `surfaceContainerHighest` background, `labelSmall` text.

## Key repository calls

| Call | Effect |
|------|--------|
| `repo.pendingCaptureCount()` | stream of pending capture count |
| `repo.watchAllCategories()` | stream of all categories (including archived) |
| `repo.watchWallets()` | stream of wallets for name map |
| `repo.categoryThresholds('spending')` | future of `{categoryId → VND threshold}` |
| `repo.watchTxns()` | stream of all transactions newest-first |
| `repo.deleteTxn(id)` | deletes one transaction |
| `repo.toggleStar(txn)` | flips `txn.starred` |
