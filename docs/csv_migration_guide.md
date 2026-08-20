# MyFinance — converting an old CSV export to the new unified format

This is a one-time data-migration recipe. It has no relation to any other context —
follow it using only the two old CSV files the user provides alongside this document.

## Background

Old MyFinance versions exported **two separate CSV files**:

- `myfinance_wallets_*.csv` — one header row, then one row per wallet
- `myfinance_txns_*.csv` — one header row, then one row per transaction

The new version reads a **single** CSV file. Instead of a header row per file, every
row's **first column is a record-type tag** (`WALLET` or `TXN`), so both tables live
in one file that a single CSV parser pass can split apart again. Your job is to
convert the two old files into one new file in this format.

## Step 0 — parse correctly, don't string-split

Parse both old files with a real CSV parser (respecting quoted fields), not by
splitting on `,` naively. A transaction description or wallet name can legitimately
contain a comma, in which case the original export already wrapped that field in
double quotes (standard CSV escaping) — a dumb split would break on it. Re-emit the
new file the same way (a proper CSV writer), not by concatenating raw strings.

## Step 1 — old column layouts (for reference)

**`myfinance_wallets_*.csv`** header (4 columns):
```
id,name,initial_balance,type
```

**`myfinance_txns_*.csv`** header (14 columns):
```
id,type,amount,description,wallet_id,wallet_to_id,wallet_from_name,wallet_to_name,category,timestamp,imported,starred,source,affects_balance
```

## Step 2 — new unified layout

Every row starts with a tag. The importer (`CsvService.importAll` in the current
app) only reads `WALLET` and `TXN` rows — `META`/`CATEGORY`/`SETTING`/`KEYWORD` rows
are accepted but ignored, so you don't need to produce them. Skip them entirely
unless you want the file to look complete for a human reader.

**`WALLET` row** (8 columns after the tag):
```
WALLET,id,name,initial_balance,type,package_name,sort_order,balance_cutoff_at
```
The old wallet export never had `package_name` (bank-app link), `sort_order` (drag
order), or `balance_cutoff_at` (balance-reset cutoff timestamp) — there is no data to
carry over for these three. Leave them **empty** (`sort_order` can be `0`). The user
will need to re-link any bank app and re-order wallets by hand after import; that's
expected, not a bug in this conversion.

**`TXN` row** (14 columns after the tag) — note this is the *same column order* as
the old txns.csv header, so conversion is mechanical:
```
TXN,id,type,amount,description,wallet_id,wallet_to_id,wallet_from_name,wallet_to_name,category,timestamp,imported,starred,source,affects_balance
```

## Step 3 — the mechanical transform

For every data row (skip each file's header row):

- **Wallets file**: prepend the literal cell `WALLET`, then keep the row's 4 values
  as-is, then append 3 empty-ish cells: `` (package_name), `0` (sort_order), ``
  (balance_cutoff_at).

  Example — old row:
  ```
  a1b2c3,Vietcombank,500000,bank
  ```
  becomes:
  ```
  WALLET,a1b2c3,Vietcombank,500000,bank,,0,
  ```

- **Transactions file**: prepend the literal cell `TXN`, then keep all 14 values
  exactly as they are — no reordering, no reformatting.

  Example — old row:
  ```
  t9f8e7,spending,45000,Cà phê,a1b2c3,,,,food,2025-11-02T08:15:00.000,0,0,manual,1
  ```
  becomes:
  ```
  TXN,t9f8e7,spending,45000,Cà phê,a1b2c3,,,,food,2025-11-02T08:15:00.000,0,0,manual,1
  ```

## Step 4 — combine and hand back

Concatenate: all converted `WALLET` rows, then all converted `TXN` rows, into one
`.csv` file (any row order actually works — the importer sorts by tag internally,
this is just for readability). Give that single file back to the user to import via
Cài đặt → "Nhập CSV" in the new app.

## Known, expected limitations of this conversion (tell the user, don't try to fix)

- **Bank-app links, wallet drag-order, and balance-reset cutoffs** are not
  recoverable from the old export — re-set these manually per wallet after import.
- **Custom (non-default) categories** are not carried over — the old export format
  never captured category definitions, only category *id strings* on each
  transaction. If the user created custom categories in the old app, those
  transactions will reference an id that doesn't exist in the freshly-installed app;
  they'll need to recreate the categories and may need to re-assign those specific
  transactions.
- **App settings** (locale, theme, currency symbol, autostar toggle, custom icons)
  and the **keyword-suggestion library** are not in the old export at all — nothing
  to convert here; these just need to be reconfigured by hand in the new app.
- If the user has **more than one** old export snapshot (e.g. several backups taken
  over time) and wants to merge them, keep only the most recent row per `id` before
  converting — don't include the same id twice, since which one "wins" on import
  would otherwise depend on row order.
