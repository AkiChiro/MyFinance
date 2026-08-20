# Bank Captures — Developer Reference

Files: `lib/ui/captures_page.dart`, `lib/ui/capture_confirm_page.dart`

## Overview

Two screens handle the bank-notification review UX (Phase 5d):

1. **`CapturesPage`** ("Thông báo ngân hàng") — inbox listing all pending captures
2. **`CaptureConfirmPage`** ("Xác nhận giao dịch" / "Nhập thủ công") — review + edit + confirm/dismiss one capture

Entry points:
- Banner tap in `TransactionsPage`
- Nav-bar badge on the Giao dịch tab (via the banner on the transactions page — there is no direct badge tap-through)

## `CapturesPage`

### Widget structure

```
CapturesPage (ConsumerWidget)
  └─ Scaffold (title: "Thông báo ngân hàng")
     └─ StreamBuilder<List<Wallet>>            (repo.watchWallets())
        └─ StreamBuilder<List<NotificationCapture>>  (repo.watchPendingCaptures())
           ├─ Center "Không có thông báo nào cần xem."  (if empty)
           └─ ListView.builder
              └─ _CaptureTile × N
```

### Why nested StreamBuilders

`_CaptureTile` needs both a wallet name (to show "OCB Wallet" instead of just "OCB") and the bank label (to show "OCB" when no wallet is linked). The wallet stream is the outer layer so its snapshot is available when building each tile.

`walletMap` = `{walletId → walletName}` built from the wallet list, passed into each tile.

### `_CaptureTile`

**`_bankLabels` map:**
```dart
static const _bankLabels = <String, String>{
  BankPackages.ocb: 'OCB',
  BankPackages.mb: 'MB',
  BankPackages.techcombank: 'Techcombank',
};
```
Keys are `BankPackages.*` constants (not hardcoded strings), so they track constant updates automatically.

**Wallet name resolution:**
```dart
final walletName = capture.suggestedWalletId != null
    ? (walletMap[capture.suggestedWalletId!] ?? _bankLabels[capture.packageName] ?? capture.packageName)
    : (_bankLabels[capture.packageName] ?? capture.packageName);
```
Priority: live wallet name → bank label → raw package name.

**Three tile styles based on `capture.parseStatus`:**

| `parseStatus` | Icon | Color | Chip |
|---------------|------|-------|------|
| `parsed` | `notifications_outlined` | primary | none |
| `needsReview` | `help_outline` | orange | "Cần xem lại" |
| `unparsed` | `warning_amber_outlined` | error | "Chưa đọc được" |

Amount display:
- `parsed`/`needsReview`: `±formatVnd(amount)`
- `unparsed`: `"—"` (amount is null)

Direction sign: `income → "+"`, `expense → "−"`. Amount text is colored green for income, error-color for expense.

`onTap` → `Navigator.push(MaterialPageRoute(_ => CaptureConfirmPage(capture: capture)))`.

---

## `CaptureConfirmPage`

### State

| Field | Type | Initialized from |
|-------|------|-----------------|
| `_amount` | `TextEditingController` | `capture.amount.toString()` (if not unparsed and not null) |
| `_direction` | `CaptureDirection` | `capture.direction` (if not unparsed); else `CaptureDirection.expense` |
| `_walletId` | `String?` | `capture.suggestedWalletId` |
| `_category` | `String?` | `null` (user always picks) |
| `_starred` | `bool` | `false` |
| `_timestamp` | `DateTime` | `capture.capturedAt` |
| `_saving` | `bool` | `false` (loading guard) |

### Title

- `_isUnparsed` → "Nhập thủ công"
- else → "Xác nhận giao dịch"

### App bar actions

`TextButton("Bỏ qua")` in the actions list → calls `_dismiss()`. Disabled while `_saving`.

### Widget structure (body)

```
StreamBuilder<List<Wallet>>
  └─ StreamBuilder<List<AppCategory>>   (key: ValueKey(_direction))
     └─ ListView
        ├─ [if unparsed] raw text Card (errorContainer color)
        ├─ SegmentedButton (Chi tiêu / Thu nhập)
        ├─ TextField (Số tiền, digits only)
        ├─ DropdownButtonFormField<String>    (Ví *, required)
        ├─ DropdownButtonFormField<String?>   (Danh mục, optional — includes "— Bỏ qua —")
        ├─ Card → ListTile (Thời gian giao dịch, tap to pick date/time)
        ├─ SwitchListTile (Đánh dấu sao)
        ├─ [if not unparsed] raw text Card (reference, at bottom)
        └─ FilledButton.icon "Xác nhận giao dịch"
```

### `StreamBuilder(key: ValueKey(_direction))` on categories

The `key` forces Flutter to destroy and recreate the inner `StreamBuilder` when `_direction` changes. This causes `watchActiveCategories` to be called with the new type, and the `DropdownButtonFormField` for categories to rebuild with `initialValue: null`. Without the key, Flutter would reuse the existing widget and the category dropdown would show a stale list.

### `_onDirectionChanged(CaptureDirection dir)`

```dart
setState(() {
  _direction = dir;
  _category = null;   // reset category when direction changes
});
```

Also triggers the `ValueKey` rebuild of the category stream.

### `_txType` getter

```dart
String get _txType =>
    _direction == CaptureDirection.income ? TxTypes.earning : TxTypes.spending;
```

Used as the `kind` argument for `watchActiveCategories`.

### Wallet dropdown

```dart
DropdownButtonFormField<String>(
  initialValue: wallets.any((w) => w.id == _walletId) ? _walletId : null,
  ...
)
```

The guard `wallets.any((w) => w.id == _walletId)` prevents `initialValue` from being set to a stale ID that no longer exists in the loaded wallet list. Without this, `DropdownButtonFormField` would throw an assertion error if the initial value is not among the items.

### Category dropdown

Has a null option "— Bỏ qua —" at the top. `_category = null` means no category is selected; the transaction will be saved without a category.

### `_pickDate()`

```dart
final d = await showDatePicker(...);
final t = await showTimePicker(...);
setState(() => _timestamp = DateTime(d.year, d.month, d.day, t?.hour, t?.minute));
```

Shows date picker then time picker sequentially. If only date is picked (user dismisses time picker), the original time components are preserved.

### `_confirm(List<Wallet> wallets)`

```dart
1. amount = parseAmount(_amount.text)
   if amount <= 0 → _snack('Vui lòng nhập số tiền hợp lệ.')  → return
2. if _walletId == null → _snack('Vui lòng chọn ví.')  → return
3. _saving = true
4. await repo.confirmCapture(
     _capture.id,
     walletId: _walletId!,
     amount: amount,
     direction: _direction,
     category: _category,
     starred: _starred,
     timestamp: _timestamp,
   )
5. Navigator.pop(context)   → returns to inbox
```

`timestamp: _timestamp` is always explicitly passed (initialized to `capturedAt`, possibly edited by `_pickDate`). This means the transaction always lands on the notification's arrival time unless the user changes it.

### `_dismiss()`

```dart
1. showDialog "Bỏ qua thông báo này?" with "Huỷ" and "Bỏ qua" buttons
2. on confirm: repo.dismissCapture(_capture.id)
3. Navigator.pop(context)
```

No transaction is created. The capture's `status` is set to `dismissed` in DB. It will no longer appear in `watchPendingCaptures()`.

### `_fallbackCats(String type)` (top-level function)

Returns a hardcoded `List<AppCategory>` from `Categories.forType(type)` and `Categories.label(id)`. Used when `catSnap.data` is null or empty (i.e., DB hasn't loaded yet). Prevents a blank category dropdown on first render.

---

## Entry point — nav-bar badge (in `home_page.dart`)

```dart
StreamBuilder<int>(
  stream: repo.pendingCaptureCount(),
  builder: (context, snap) {
    final captureCount = snap.data ?? 0;
    return NavigationBar(
      destinations: [
        ...,
        NavigationDestination(
          icon: captureCount > 0
              ? Badge(label: Text('$captureCount'), child: Icon(Icons.receipt_long_outlined))
              : Icon(Icons.receipt_long_outlined),
          ...
        ),
      ],
    );
  },
)
```

The badge count matches `pendingCaptureCount()`, which is `watchPendingCaptures().map((list) => list.length)`. The same stream drives the banner in `TransactionsPage`, so badge and banner are always in sync.

---

## Key repository calls

| Call | Effect |
|------|--------|
| `repo.watchWallets()` | stream of wallets for name map |
| `repo.watchPendingCaptures()` | stream of `pending` captures, newest-first |
| `repo.pendingCaptureCount()` | stream of pending count (used by badge and banner) |
| `repo.watchActiveCategories(kind)` | stream of non-archived categories for the category dropdown |
| `repo.confirmCapture(id, walletId, amount, direction, ...)` | creates transaction + marks capture confirmed (atomic) |
| `repo.dismissCapture(id)` | marks capture dismissed, no transaction |
