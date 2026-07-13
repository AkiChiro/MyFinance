# Ví Tab — Developer Reference

File: `lib/ui/wallets_page.dart`

## Overview

The Ví tab shows all wallets, their current balances (derived from transaction history), and the total balance across all wallets. It provides wallet creation, bank-link configuration, and deletion.

## Widget tree

```
WalletsPage (ConsumerWidget)
  └─ StreamBuilder<List<Wallet>>      (repo.watchWallets())
     └─ StreamBuilder<Map<String,int>> (repo.watchWalletBalances())
        ├─ _Empty                     (if no wallets)
        └─ ListView
           ├─ Card (total balance row)
           ├─ Card (per-wallet ListTile) × N
           └─ OutlinedButton "Thêm ví"
```

## Data sources

- `repo.watchWallets()` — stream of all wallets ordered by name
- `repo.watchWalletBalances()` — stream of `{walletId → int}` balance map; recomputed in SQL on every txns-table change

Both are nested `StreamBuilder`s. The outer wallet list provides the wallet order; the inner balance map provides the derived balance for each wallet tile.

## `_bankLabel(String? pkg) → String?`

Top-level helper. Scans `_kBankOptions` for a matching `pkg`, returns the human label ("OCB", "MB", "Techcombank") or falls back to the raw package name string. Returns null if `pkg` is null (no link).

`_kBankOptions` uses `BankPackages.*` constants directly, so updating a constant automatically updates the label resolver without any additional changes.

## Wallet tile (inline in `build`)

Each wallet is a `Card > ListTile`:
- Leading: `CircleAvatar` with bank or cash icon based on `w.type`
- Title: wallet name
- Subtitle: `WalletKinds.label(w.type)` + optional bank label joined with ` · `
- Trailing: formatted VND balance (`balances[w.id] ?? 0`)
- `onLongPress`: opens `_walletActionSheet`

## `_walletActionSheet(context, wallet, repo)`

`showModalBottomSheet` with two `ListTile` options:
1. **"Sửa liên kết ngân hàng"** → `_editBankLinkDialog`
2. **"Xoá ví"** → `_confirmDelete`

## `_editBankLinkDialog(context, wallet, repo)`

`showDialog` with a `StatefulBuilder` (so the dropdown can rebuild within the dialog).

Fields:
- `DropdownButtonFormField<String?>` — bank picker, `initialValue: w.packageName`
- Options: `null = "— Không liên kết —"`, then one per `_kBankOptions` entry

On "Lưu":
1. If `selectedPkg == w.packageName` → no-op, close.
2. If `selectedPkg != null`: uniqueness check — `repo.walletByPackageName(newPkg)`.
   - If existing wallet found **and** `existing.id != w.id` (self-exclusion guard): show conflict dialog.
     - "Chuyển" → `repo.reassignWalletBankLink(newPkg, w.id)` → closes.
     - "Huỷ" → stay open.
   - No conflict → `repo.updateWalletPackageName(w.id, newPkg)` → closes.
3. If `selectedPkg == null` → `repo.updateWalletPackageName(w.id, null)` → clears the link.

**Self-exclusion guard:** `existing != null && existing.id != w.id` — when the wallet being edited already owns the selected package, `walletByPackageName` returns itself. Without this guard, it would falsely show the conflict dialog.

## `_confirmDelete(context, wallet, repo)`

`showDialog` with "Xoá ví / Huỷ". On confirm: `repo.deleteWallet(w.id)`. Transactions linked to the deleted wallet are retained in the DB (the wallet reference becomes stale — `resolveWallet` in `transactions_page.dart` falls back to the snapshot name stored at import time or "(ví khác)").

## `_addWalletDialog(context, repository)` (top-level function)

`showDialog` with a `StatefulBuilder`. Exposed as `showAddWalletDialog(context, repo)` for call sites outside the widget class.

Fields:
- Name text field (required — save is no-op if empty after trim)
- Balance number field (`parseAmount(text)`)
- `SegmentedButton<String>` for type: Tiền mặt / Ngân hàng
- `DropdownButtonFormField<String?>` for bank link (same `_kBankOptions` list)

On "Lưu":
1. If `name.isEmpty` → return.
2. If `pkg != null`: uniqueness check → `repo.walletByPackageName(pkg)`.
   - If existing found: conflict dialog "Chuyển sang ví mới?".
     - "Chuyển":
       ```
       newId = await repo.addWallet(name, balance, type, packageName: null)
       await repo.reassignWalletBankLink(pkg, newId)
       ```
       This creates the wallet without the package first (to get its ID), then atomically moves the link.
     - "Huỷ" → return without creating.
   - No conflict → `repo.addWallet(name, balance, type, packageName: pkg)`.
3. If `pkg == null` → `repo.addWallet(name, balance, type)`.

## `_Empty` widget

Shown when `wallets.isEmpty`. Center column with a wallet icon, "Chưa có ví nào." text, and a "Thêm ví" FilledButton.

## Key repository calls

| Call | Effect |
|------|--------|
| `repo.watchWallets()` | stream of wallets |
| `repo.watchWalletBalances()` | stream of balance map |
| `repo.addWallet(name, initialBalance, type, packageName?)` | creates wallet, returns new UUID |
| `repo.updateWalletPackageName(id, pkg?)` | sets or clears package link for one wallet |
| `repo.walletByPackageName(pkg)` | uniqueness pre-check |
| `repo.reassignWalletBankLink(pkg, newWalletId)` | atomic: clear pkg from old wallet, set on new wallet |
| `repo.deleteWallet(id)` | deletes wallet row |
