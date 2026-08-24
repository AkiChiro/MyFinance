# Thống kê Tab — Developer Reference

File: `lib/ui/analytics_page.dart`

## Overview

The Thống kê tab shows monthly spending/earning summaries and pie charts broken down by category. The user can navigate backwards and forwards through months. All data comes from a single SQL analytics bundle that is recomputed whenever the `txns` table changes.

## Widget structure

```
AnalyticsPage (ConsumerStatefulWidget)
  └─ _AnalyticsPageState
     └─ StreamBuilder<AnalyticsBundle>   (_bundleStream)
        ├─ loading: CircularProgressIndicator
        └─ data: ListView
           ├─ Month navigation row (← Month Year →)
           ├─ Summary card (spending / earning / net for curr month)
           ├─ Comparison row (vs. last month)
           ├─ Year-to-date row
           ├─ Spending pie chart + legend
           ├─ Earning pie chart + legend
           └─ Envelope budgeting section (_EnvelopeSection)
```

## State

- `_month: DateTime` — the currently selected month (day is always 1; only year/month matter)
- `_bundleStream: Stream<AnalyticsBundle>` — recreated whenever `_month` changes

`_month` is initialized to `DateTime.now()` in `initState`. When the user taps ← or →, `_month` is updated with `setState` and `_bundleStream` is replaced.

## `_bundleStream` lifecycle

```dart
void initState() {
  super.initState();
  _month = DateTime(DateTime.now().year, DateTime.now().month);
  _bundleStream = ref.read(repositoryProvider).watchAnalyticsBundle(_month);
}
```

When `_month` changes:
```dart
setState(() {
  _month = newMonth;
  _bundleStream = repo.watchAnalyticsBundle(_month);
});
```

Replacing the stream is safe because `StreamBuilder` cancels the old subscription and subscribes to the new one. The `AnalyticsBundle` for the new month is emitted immediately (the method uses `async*` with an initial `yield`).

## `_Stats` data class

`_Stats.fromBundle(AnalyticsBundle)` wraps the bundle into a convenience object with computed `net`, `prevNet`, `yearNet` getters. Used purely within `analytics_page.dart`; not exported.

## Category colors

Moved to the shared `lib/ui/category_colors.dart` (warm-redesign change, so `transactions_page.dart`'s `_TxnTile` can use the same palette for its icon color). Two `const` maps keyed by category ID:
- `spendColors`: `necessities=orange, food=amber, hobbies=purple, others=grey`
- `earnColors`: `provided=green, self_earned=blue, others_earn=grey`

`spendColor(cat)` / `earnColor(cat)`: resolve color, fall back to grey for unknown IDs (user-created categories).

## Pie charts

Built with `fl_chart`'s `PieChart`. Each sector corresponds to one category entry in `stats.spendByCat` or `stats.earnByCat`. The legend is a `Column` of color-dot + label + amount rows on the right side of the chart.

Sections with zero total are not rendered (excluded from the map by the SQL `GROUP BY` result).

### Legend rows

Each row in the right-side legend shows:
- A 10×10 colored circle (matching the pie sector)
- The category label (expanded, ellipsized)
- The VND amount (`formatVnd(e.value)`) — **not** a percentage

Row padding: `EdgeInsets.symmetric(vertical: 6)` — increased from 3 to 6 for readability.

Pie sector labels (inside the chart itself) still show `'${pct.toStringAsFixed(1)}%'` so the proportions are visible at a glance in the chart.

## Month navigation

Two `IconButton`s ("←" and "→") change `_month` by calling `DateTime(year, month ± 1)`. Flutter normalizes month values (e.g., `DateTime(2026, 0)` → December 2025), so navigation across year boundaries is handled automatically.

## `watchAnalyticsBundle` (in `database.dart`)

```dart
Stream<AnalyticsBundle> watchAnalyticsBundle(DateTime month) async* {
  yield await _buildAnalyticsBundle(month);        // immediate first value
  await for (final _ in tableUpdates(onTable: txns)) {
    yield await _buildAnalyticsBundle(month);      // re-emit on every txns change
  }
}
```

`_buildAnalyticsBundle` runs two SQL queries:
1. **Totals**: one row with 6 conditional `SUM`s using Unix-second boundaries
2. **Category breakdowns**: two `GROUP BY category` queries

All SQL filters: `WHERE type != 'transfer'` (no `affects_balance` gate — see `docs/architecture.md`'s "Analytics computation" section; a balance reset must not remove old spending/earning from these totals). Transfers are deliberately excluded from the spending/earning totals because they don't represent new income or expense — they move money between wallets.

## Drill-down navigation

Tapping the Tổng chi/Tổng thu stat cards, a pie slice, or a legend row switches to Giao dịch pre-filtered to match — see `docs/architecture.md`'s "Analytics drill-down" section for the full design (`_drillDown()`, the providers it writes, the `FlTapUpEvent` pie-touch handling, and the "Khác" category-coalescing fix this relies on). Only the two stat cards and the two pie sections are interactive this way — `_YearCard` and the "Chênh lệch tháng này" comparison row stay non-interactive, intentionally. `_EnvelopeSection` rows are also interactive, reusing the same `_drillDown` callback (see below).

## Envelope budgeting section (`_EnvelopeSection` / `_EnvelopeRow`)

One card, one row per **budgeted** spending category — active, not archived, and with a currently-configured percent > 0 (a 0%/unset category is hidden entirely; there's no budget for it to be "over"). Each row is a `spendColor` dot + label + `{percent}%` badge + a small edit icon, a thin `LinearProgressIndicator` (spent ⁄ allocated, clamped to `[0,1]`), and a caption line — `formatVnd`-formatted "Còn lại: X ₫" when under budget, "Vượt: X ₫" in the error color when over. Rows come from crossing two streams: `repo.watchCategoryBudgetPercents()` (percent badge + the hide-if-zero filter, the same stream `CategoriesPage` uses for its own subtitle) and `repo.watchEnvelopeBalances()` (the allocated/spent numbers driving the bar).

The trailing edit icon (`Icons.edit_outlined`, `_EnvelopeRow.onEdit`) opens `_showEnvelopeEditDialog` — a percent `TextField` in an `AlertDialog`/`StatefulBuilder`, identical validation shape to `CategoriesPage`'s own edit dialog (catches `BudgetPercentExceededException` and shows it as inline `errorText` without closing the dialog). It's a separate Material tap target nested inside the row's own `InkWell`, so it doesn't trigger drill-down when pressed. That same dialog has a "Đặt lại ngân sách…" text button (`analyticsEnvelopeResetTrigger`) that closes it and opens a second confirmation dialog (`_confirmResetEnvelope`, styled like `theme_customization_page.dart`'s `_resetAll` — plain, non-error `AlertDialog`); confirming calls `repo.resetEnvelope(categoryId)`. Reset and percent-edit are independent mutations by design — confirming one never touches the other.

`watchEnvelopeBalances()` returns `Map<String, EnvelopeStatus>` (`lib/data/database.dart`) — `EnvelopeStatus{allocated, spent}` plus a `balance` getter (`allocated - spent`), replacing the old pre-subtracted `Map<String, int>`. A freshly-budgeted category with no income recorded since (`allocated == 0 && spent == 0`) is rendered as "Chưa có thu nhập để phân bổ" with an empty bar rather than a divide-by-zero or a misleading 100%-over.

Unlike every other section on this page, envelope balances are **cumulative since forever**, not scoped to `_month` — so `_EnvelopeSection` keeps its own `StreamBuilder`s rather than being folded into `_Stats`/`AnalyticsBundle`. It takes the full `List<AppCategory>` `_AnalyticsPageState.build()` already fetches via `watchAllCategories()` (ordered by `sort_order`, same ordering as everywhere else in the app) rather than the flattened `catLabels` map the two `_PieSection`s use — it needs `label`/`kind`/`archived` directly. Tapping a row calls the page's existing `_drillDown(type: TxTypes.spending, category: categoryId)` — same navigation the stat cards/pie already use, not a second mechanism.

Budget percents can also be configured in `CategoriesPage` (Cài đặt → Quản lý danh mục) via the same repository call — see `docs/tab_settings.md`. Full computation details (the as-of join against `category_budget_history`, the non-retroactive-percentage design, why it filters `affects_balance` unlike the rest of this page, and the per-category `envelope_cutoff_at` reset mechanism) are in `docs/architecture.md`'s "Envelope budgeting" section.

## Key repository calls

- `repo.watchAnalyticsBundle(month)` — the month-scoped data dependency for everything except the envelope section.
- `repo.watchEnvelopeBalances()` — cumulative-since-forever `{categoryId → EnvelopeStatus(allocated, spent)}` for `_EnvelopeSection`.
- `repo.watchCategoryBudgetPercents()` — `{categoryId → percent}`, drives the envelope section's percent badge and its hide-if-0% filter.
- `repo.setCategoryBudgetPercent(categoryId, percent)` — called from the row's edit dialog (also called from `CategoriesPage`).
- `repo.resetEnvelope(categoryId)` — called after confirming the row edit dialog's reset action; sets that category's `envelope_cutoff_at` to now.
