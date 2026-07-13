# Giao dịch Tab — Developer Reference

File: `lib/ui/transactions_page.dart`

## Overview

The Giao dịch tab shows all transactions (newest first), with a filter for starred transactions and a banner linking to the bank-capture inbox when pending captures exist. Each transaction tile supports tap-to-edit (non-imported), long-press action sheet, and swipe-to-delete.

## Widget tree

```
TransactionsPage (ConsumerStatefulWidget)
  └─ _TransactionsPageState
     └─ Column
        ├─ Filter bar (Tất cả / Có sao ChoiceChips)
        ├─ StreamBuilder<int>     (repo.pendingCaptureCount()) — captures banner
        └─ Expanded
           └─ StreamBuilder<List<AppCategory>>   (repo.watchAllCategories())
              └─ StreamBuilder<List<Wallet>>       (repo.watchWallets())
                 └─ FutureBuilder<Map<String,int>> (repo.categoryThresholds('spending'))
                    └─ StreamBuilder<List<Txn>>    (repo.watchTxns())
                       └─ ListView.builder / empty state
                          └─ _TxnTile × N
```

## State

`_starredOnly: bool` — toggled by the filter chips; causes a `setState` rebuild.

## Filter bar

Two `ChoiceChip`s:
- "Tất cả" — selected when `!_starredOnly`
- "Có sao" (with star icon) — selected when `_starredOnly`

Both call `setState(() => _starredOnly = ...)`.

## Captures banner

```dart
StreamBuilder<int>(
  stream: repo.pendingCaptureCount(),
  builder: (context, snap) {
    final count = snap.data ?? 0;
    if (count == 0) return const SizedBox.shrink();
    return Card(
      color: scheme.primaryContainer,
      child: ListTile(
        leading: Badge(label: Text('$count'), child: Icon(Icons.notifications_outlined)),
        title: Text('$count thông báo ngân hàng chờ xác nhận'),
        trailing: Icon(Icons.chevron_right),
        onTap: () => Navigator.push(_, MaterialPageRoute(_ => const CapturesPage())),
      ),
    );
  },
)
```

Reactive — disappears automatically when `pendingCaptureCount` drops to 0 after all captures are confirmed or dismissed.

## Transaction list

Four nested `StreamBuilder`/`FutureBuilder`s (category labels, wallet name map, category thresholds, transaction list) build a snapshot each, then pass them down to each tile. This nesting is verbose but keeps data fresh reactively.

When `_starredOnly` is true, the transactions list is filtered to those where `txn.starred || isAutoStarred(txn, thresholds, enabled: settings.autostarEnabled)`.

## `_TxnTile` (ConsumerWidget)

### Data it receives

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

`resolveWallet(id, snapshot)`: tries live name first; if the wallet was deleted (returns "(ví khác)"), falls back to the snapshot name stored in `walletFromName`/`walletToName` at import time.

### Subtitle

`"TxType · Category · WalletName · DateTime"` joined with ` · `. Transfers omit category and wallet fields (both sides are already in the title).

### Amount display

- Transfer: formatted absolute VND (no sign)
- Spending: `−amount` in error color
- Earning: `+amount` in green

Respects `settings.currencySymbol` and `settings.currencySuffix`.

### Star display

`showStar = txn.starred || autoStar`. If `txn.starred`, shows filled star icon; if only `autoStar`, shows outlined star. Both are amber.

### `Dismissible`

Direction: `endToStart` (swipe left). Shows a red delete background. On dismiss:
1. `showDialog` "Xoá giao dịch?" — must confirm before the row is removed.
2. On confirm: `repo.deleteTxn(txn.id)`.

`confirmDismiss` returns `false` if the user cancels, which aborts the dismiss animation and restores the tile.

### `onTap`

Opens `QuickAddPage(editing: txn)` — the shared add/edit form in edit mode. Disabled for imported transactions (`onTap: txn.imported ? null : ...`).

### `_showActionSheet(context, repo)`

`showModalBottomSheet` with:
- **Sửa** (non-imported only) → pushes `QuickAddPage(editing: txn)`
- **Đánh dấu sao / Bỏ đánh dấu sao** (non-imported only) → `repo.toggleStar(txn)`
- **Xoá** → AlertDialog → `repo.deleteTxn(txn.id)`

"Sửa" and star are hidden for imported transactions.

### `_catLabel(String? id) → String`

Resolves `id` from the `catLabels` map received from the parent. Falls back to `Categories.label(id)` from the static fallback map if the DB category isn't in the snapshot (e.g., archived but still referenced by old transactions).

## `_Chip` widget

Tiny label chip used to show "đã nhập" on imported transactions. Styled with `surfaceContainerHighest` background and `labelSmall` text.

## Key repository calls

| Call | Effect |
|------|--------|
| `repo.pendingCaptureCount()` | stream of pending capture count |
| `repo.watchAllCategories()` | stream of all categories (including archived) for label lookup |
| `repo.watchWallets()` | stream of wallets for name map |
| `repo.categoryThresholds('spending')` | future of `{categoryId → VND threshold}` |
| `repo.watchTxns()` | stream of all transactions newest-first |
| `repo.deleteTxn(id)` | deletes one transaction |
| `repo.toggleStar(txn)` | flips `txn.starred` |
