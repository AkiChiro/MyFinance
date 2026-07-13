# Ví Tab — Developer Reference

Files: `lib/ui/wallets_page.dart`, `lib/ui/wallet_edit_page.dart`

## Overview

The Ví tab shows all wallets in user-defined order with their derived balances. Wallets can be dragged to reorder, tapped to edit, and created via the "Thêm ví" button. The total balance across all wallets is shown at the top.

## Widget tree

```
WalletsPage (ConsumerWidget)
  └─ StreamBuilder<List<Wallet>>       (repo.watchWallets())
     └─ StreamBuilder<Map<String,int>>  (repo.watchWalletBalances())
        ├─ _Empty                      (if no wallets)
        └─ ListView
           ├─ Card (total balance row)
           ├─ ReorderableListView.builder (wallet cards × N)
           │   └─ Card > ListTile
           │       ├─ leading: ReorderableDragStartListener (drag handle icon)
           │       ├─ title: wallet name
           │       ├─ subtitle: type · bank label (if linked)
           │       ├─ trailing: formatted VND balance
           │       └─ onTap → push WalletEditPage
           └─ OutlinedButton "Thêm ví"
```

## Data sources

- `repo.watchWallets()` — stream of all wallets ordered by `sort_order, name`
- `repo.watchWalletBalances()` — stream of `{walletId → int}` balance map; recomputed in SQL on every txns-table change

## Wallet ordering

Wallets have a `sort_order INTEGER` column (schema v6). The `watchWallets()` query orders by `sort_order ASC, name ASC`. The `ReorderableListView.onReorder` callback calls `repo.updateWalletsOrder(orderedIds)` which updates all rows via `customStatement` in a single transaction.

New wallets are appended at the bottom: `sort_order = (SELECT COUNT(*) FROM wallets)` at insert time (raw SQL in `addWallet`).

Initial `sort_order` for existing wallets is seeded by the v6 migration to match the previous alphabetical order, so drag state is preserved across upgrades.

## `ReorderableListView` setup

```dart
ReorderableListView.builder(
  shrinkWrap: true,
  physics: const NeverScrollableScrollPhysics(),
  buildDefaultDragHandles: false,          // we supply our own handle
  itemBuilder: (context, i) => Card(
    key: ValueKey(w.id),                   // required for ReorderableListView
    child: ListTile(
      leading: ReorderableDragStartListener(
        index: i,
        child: const Icon(Icons.drag_handle),
      ),
      ...
      onTap: () => Navigator.push(..., WalletEditPage(wallet: w)),
    ),
  ),
  onReorder: (oldIndex, newIndex) {
    if (newIndex > oldIndex) newIndex--;   // Flutter reorder index adjustment
    final reordered = [...wallets];
    reordered.insert(newIndex, reordered.removeAt(oldIndex));
    repo.updateWalletsOrder(reordered.map((w) => w.id).toList());
  },
)
```

`buildDefaultDragHandles: false` is required to use `ReorderableDragStartListener` on a specific widget (the handle icon) instead of making the entire tile draggable.

The `if (newIndex > oldIndex) newIndex--` adjustment is standard Flutter — when moving an item downward, the destination index arrives 1 too large because the removed item shifts remaining indices.

## Bank label helper

`bankLabel(String? pkg)` from `bank_notification_parser.dart` (shared constant `kBankPickerOptions`) resolves package name to human label ("OCB", "MB", "Techcombank"), or returns null if `pkg` is null.

Previously `wallets_page.dart` had its own private `_kBankOptions`/`_bankLabel`. These were removed in favour of the shared constant from `bank_notification_parser.dart` so all UI pickers stay in sync automatically when `BankPackages` constants change.

## `_addWalletDialog(context, repository)` (top-level function)

`showDialog` with a `StatefulBuilder`. Exposed as `showAddWalletDialog(context, repo)`.

Fields:
- Name text field (required)
- Balance number field (`parseAmount(text)`)
- `SegmentedButton<String>` for type: Tiền mặt / Ngân hàng
- `DropdownButtonFormField<String?>` for bank link (from `kBankPickerOptions`)

On "Lưu":
1. If `name.isEmpty` → return.
2. If `pkg != null`: uniqueness check → `repo.walletByPackageName(pkg)`.
   - If existing found: conflict dialog "Chuyển sang ví mới?".
     - "Chuyển": create wallet without pkg, then `repo.reassignWalletBankLink(pkg, newId)`.
     - "Huỷ" → return.
   - No conflict → `repo.addWallet(name, balance, type, packageName: pkg)`.

## `_Empty` widget

Shown when `wallets.isEmpty`. Center column with wallet icon and a "Thêm ví" FilledButton.

---

## `WalletEditPage`

File: `lib/ui/wallet_edit_page.dart`

Full-page edit screen pushed by tapping any wallet tile.

### Widget tree

```
WalletEditPage (ConsumerStatefulWidget)
  └─ _WalletEditPageState
     └─ Scaffold
        ├─ AppBar (title: "Sửa ví", actions: [delete IconButton])
        └─ ListView
           ├─ TextField (Tên ví)
           ├─ TextField (Số dư ban đầu, digits only)
           ├─ SegmentedButton (Tiền mặt / Ngân hàng)
           ├─ DropdownButtonFormField (Ngân hàng liên kết)
           └─ FilledButton.icon "Lưu thay đổi"
```

### State

| Field | Type | Initialized from |
|-------|------|-----------------|
| `_name` | `TextEditingController` | `wallet.name` |
| `_balance` | `TextEditingController` | `wallet.initialBalance.toString()` |
| `_type` | `String` | `wallet.type` |
| `_pkg` | `String?` | `wallet.packageName` |
| `_saving` | `bool` | `false` (loading guard) |

### `_save(context, repo)`

1. Validate `_name.text.trim()` — snack and return if empty.
2. If `_pkg != null && _pkg != wallet.packageName` (bank link changed):
   - Uniqueness check: `repo.walletByPackageName(newPkg)`.
   - If conflict (other wallet holds this pkg): show conflict dialog.
     - On confirm: `repo.updateWallet(id, ..., packageName: const Value(null))` then `repo.reassignWalletBankLink(newPkg, wallet.id)`.
     - On cancel: reset `_saving`, return.
3. Otherwise: `repo.updateWallet(id, name, balance, type, packageName: Value(_pkg))`.
4. `Navigator.pop(context)`.

**Why clear pkg before reassign:** `updateWallet` with `packageName: const Value(null)` removes our wallet's current link before `reassignWalletBankLink` moves the target link. This keeps all operations within the unique index constraint.

### Delete button

`IconButton` in the app bar with error-colour `Icons.delete_outline`. Calls `_confirmDelete(context, repo)`.

`_confirmDelete`: AlertDialog "Xoá ví `name`?" with an error-coloured FilledButton. On confirm: `repo.deleteWallet(wallet.id)` then `Navigator.pop(context)`.

Transactions linked to the deleted wallet are retained (the wallet reference becomes stale).

### `initialBalance` note

Changing `initialBalance` directly shifts all derived balances. There is no archiving or transaction split on wallet parameter changes — this is a conscious simplicity tradeoff (the user requested archiving as optional; it was not implemented).

---

## Key repository calls

| Call | Effect |
|------|--------|
| `repo.watchWallets()` | stream of wallets ordered by sort_order, name |
| `repo.watchWalletBalances()` | stream of balance map |
| `repo.addWallet(name, initialBalance, type, packageName?)` | creates wallet, appends at sort order bottom, returns new UUID |
| `repo.updateWallet(id, name, initialBalance, type, packageName)` | updates all non-order fields |
| `repo.updateWalletsOrder(List<String> ids)` | persists drag-reorder by writing sort_order for each wallet |
| `repo.updateWalletPackageName(id, pkg?)` | sets or clears package link (used only from add dialog no-conflict path) |
| `repo.walletByPackageName(pkg)` | uniqueness pre-check |
| `repo.reassignWalletBankLink(pkg, newWalletId)` | atomic: clear pkg from old wallet, set on new wallet |
| `repo.deleteWallet(id)` | deletes wallet row |
