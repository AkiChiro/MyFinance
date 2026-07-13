# MyFinance — Full Flow Explanations

## App startup

```
main()
  1. WidgetsFlutterBinding.ensureInitialized()
  2. AppDatabase()            — opens SQLite (Documents/myfinance.sqlite)
  3. FinanceRepository(db)   — sets up CSV service
  4. CategorySuggester().load()
  5. AppSettings.load()      — reads SharedPreferences
  6. NotificationService.instance.init(enabled: settings.notifEnabled)
     — creates notification channel, shows persistent notification if enabled
  7. CaptureService(repo, LiveCaptureChannelApi())
  8. WidgetsBinding.instance.addObserver(_AppLifecycleObserver)
     — will call drain() on every AppLifecycleState.resumed
  9. addPostFrameCallback(() => captureService.drain())
     — first drain after first frame (Pigeon bindings registered by then)
 10. runApp(ProviderScope(...overrides..., child: MyFinanceApp()))
```

`MyFinanceApp` is a `ConsumerWidget` that builds the `MaterialApp`. It watches `settingsProvider` so theme, locale, and background image rebuild automatically when settings change.

## Bank notification capture drain

Triggered on first frame after launch and on every `AppLifecycleState.resumed`.

```
CaptureService.drain()
  1. repo.allWallets()
     → build walletPkgs = {w.packageName for all wallets with non-null packageName}
  2. watched = BankPackages.all ∪ walletPkgs   (deduplicated set)
  3. _api.setWatchedPackages(watched)
     → Pigeon → Kotlin: saves filter list to SharedPreferences so
       BankCaptureService only buffers notifications from these packages
  4. messages = _api.drainCaptures()
     → Pigeon → Kotlin: reads all CapturedMessage objects from the buffer,
       marks them "claimed" (they still exist until clearCaptures is called)
  5. if messages.isEmpty → return
  6. for each message:
     a. BankParserRegistry.forPackage(message.packageName)
        → returns the BankNotificationParser for that package, or null
     b. if parser found: parsed = parser.parse(RawNotification)
        → returns ParsedNotification(amount, direction, lowConfidence)
          or null if the text doesn't match
     c. if parsed != null:
          → insertCapture(parseStatus: lowConfidence ? needsReview : parsed)
        elif message text matches _rAmountShape regex (money-shaped text):
          → insertCapture(parseStatus: unparsed)
          [ADR-0013: probable parser gap — file it so no bank transaction is lost]
        else:
          → discard silently (OTP, login alert, promo)
          [message.id still added to allIds so buffer is cleared]
     d. collect message.id into allIds
  7. _api.clearCaptures(allIds)
     → Pigeon → Kotlin: removes these IDs from SharedPreferences buffer
```

**Crash safety:** steps 6 and 7 are intentionally ordered "file first, clear after". If the app crashes between step 6 and 7, the next drain re-processes the same messages. `insertCapture` uses a 2-minute dedup window on the `dedupKey` to make re-draining idempotent.

## Insert capture (dedup + wallet resolution)

```
FinanceRepository.insertCapture(packageName, rawTitle, rawText, capturedAt, amount, direction, parseStatus)
  1. key = dedupKey(packageName, rawText)
     = "packageName\x1enormalized(rawText)"
     [normalize: trim + collapse whitespace + lowercase]
  2. windowStart = capturedAt − 2 minutes
  3. DB query: SELECT * FROM notification_captures
       WHERE dedup_key = key AND captured_at >= windowStart
     if row found → return null (duplicate, skip)
  4. wallet = walletByPackageName(packageName)
     → SELECT * FROM wallets WHERE package_name = packageName
  5. INSERT notification_captures (
       id=UUID, packageName, rawTitle, rawText, capturedAt,
       amount, direction, parseStatus,
       suggestedWalletId = wallet?.id,   ← pre-filled wallet suggestion
       dedupKey = key
     )
  6. return the inserted row
```

## Manual transaction creation

### Spending
```
QuickAddPage → repo.addSpending(amount, walletId, category, description, timestamp)
  1. db.transaction(() {
       _assertSufficient(walletId, amount)
         → sqlBalance(walletId) → raises OverspendException if amount > balance
       INSERT txns (type=spending, source=manual, affectsBalance=true, ...)
     })
```

### Earning
```
repo.addEarning(amount, walletId, category, description, timestamp)
  INSERT txns (type=earning, source=manual, affectsBalance=true, ...)
  [no overspend check needed]
```

### Transfer
```
repo.addTransfer(amount, fromWalletId, toWalletId, timestamp)
  1. db.transaction(() {
       _assertSufficient(fromWalletId, amount)
       INSERT txns (type=transfer, walletId=fromWalletId, walletToId=toWalletId,
                    source=manual, affectsBalance=true, ...)
     })
```

## Confirm a capture

```
CaptureConfirmPage._confirm()
  → repo.confirmCapture(captureId, walletId, amount, direction, category, starred, timestamp)

FinanceRepository.confirmCapture()
  db.transaction(() {
    1. txnTimestamp = timestamp   [caller-supplied, e.g. user-edited date]
                   ?? capturedAt  [from the notification_captures row — when the bank event happened]
                   ?? DateTime.now()
    2. txnId = UUID
    3. type = direction == income ? TxTypes.earning : TxTypes.spending
    4. INSERT txns (
         type, amount, walletId, category, timestamp=txnTimestamp, createdAt=now,
         source=bankNotification, affectsBalance=true, starred
       )
    5. UPDATE notification_captures SET
         status=confirmed, resulting_txn_id=txnId
       WHERE id = captureId
  })
```

**Overspend bypass:** `confirmCapture` intentionally skips `_assertSufficient`. A bank notification records money that already moved; a negative resulting balance is an accurate reflection of the account state.

## Dismiss a capture

```
CaptureConfirmPage._dismiss()
  → shows AlertDialog "Bỏ qua thông báo này?"
  → on confirm: repo.dismissCapture(captureId)

FinanceRepository.dismissCapture()
  UPDATE notification_captures SET status=dismissed WHERE id=captureId
  [no transaction row created]
```

## Balance computation

Computed on every query — never stored:

```
SQL (simplified):
  SELECT w.initial_balance + COALESCE(SUM(delta), 0) AS balance
  FROM wallets w
  LEFT JOIN (
    SELECT wallet_id   AS wid,  amount AS delta FROM txns WHERE type='earning'  AND affects_balance=1
    UNION ALL
    SELECT wallet_id   AS wid, -amount AS delta FROM txns WHERE type='spending' AND affects_balance=1
    UNION ALL
    SELECT wallet_id   AS wid, -amount AS delta FROM txns WHERE type='transfer' AND affects_balance=1
    UNION ALL
    SELECT wallet_to_id AS wid, amount AS delta FROM txns WHERE type='transfer' AND affects_balance=1
  ) grouped ON grouped.wid = w.id
  WHERE w.id = ?
```

The UNION ALL handles the dual-sided nature of transfers: one row decrements the source wallet, the second increments the destination wallet.

## Analytics computation

```
AppDatabase.watchAnalyticsBundle(month)
  yields whenever txns table changes:
    _buildAnalyticsBundle(month)
      1. Compute UTC-second boundaries for: curr month, prev month, year
      2. Single SQL query → 6 totals (curr/prev/year × spending/earning)
         WHERE affects_balance=1 AND type!='transfer'
      3. Two GROUP BY queries → {category → total} for curr month
      4. Return AnalyticsBundle
```

`AnalyticsPage` wraps this in a `StreamBuilder` and rebuilds on each emission.

## Auto-star logic

```
isAutoStarred(txn, thresholds, enabled) → bool
  ─ returns false if: disabled, not a spending, imported, or a transfer
  ─ threshold = thresholds[txn.category] ?? 0
  ─ returns true if: threshold > 0 AND txn.amount > threshold
```

`isAutoStarred` is a pure function in `finance_repository.dart`. The thresholds map is loaded from the DB (per-category VND limit). A transaction is visually starred if `txn.starred || isAutoStarred(txn, thresholds, enabled: settings.autostarEnabled)`.

## Wallet bank-link uniqueness

Each bank package can be linked to **at most one wallet** (partial unique index). When the user tries to link a bank to a second wallet:

```
If old wallet exists with that package name:
  1. Show conflict dialog "Ngân hàng đã được liên kết — Chuyển?"
  2. On confirm:
     repo.reassignWalletBankLink(packageName, newWalletId)
       db.transaction() {
         UPDATE wallets SET package_name=NULL WHERE package_name=pkg
         UPDATE wallets SET package_name=pkg WHERE id=newWalletId
       }
```

For the add-wallet flow with a conflict, the wallet is created first (without the pkg) to get its ID, then `reassignWalletBankLink` is called:

```
newId = await repo.addWallet(name, balance, type, packageName: null)
await repo.reassignWalletBankLink(pkg, newId)
```

This ensures the transaction never writes a `packageName` that violates the unique index.

## Category suggestion

```
QuickAddPage description field onChange:
  suggester.suggest(description)
    → tries each heuristic pattern against the description
    → returns a category ID string, or null
  if result != null: auto-select that category in the dropdown
```

The suggester is a stateless heuristic (no ML). Patterns are keyword lists matched case-insensitively.

## CSV export

```
repo.csv.export()
  → generates two XFile objects:
    1. transactions.csv  — all txns ordered by timestamp
    2. wallets.csv       — all wallets
  → SharePlus shares both files (system share sheet)
```

## CSV import

```
_importMerge() in SettingsPage
  1. User picks CsvImportMode (contextOnly or reconstructBalance)
  2. User picks a .csv file via FilePicker
  3. repo.csv.importMerge(file, mode)
     → parses CSV, resolves wallet by name or snapshot
     → inserts txns with:
         imported=true
         source=csvImport
         affectsBalance = (mode == reconstructBalance)
```
