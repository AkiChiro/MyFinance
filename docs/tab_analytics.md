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

## Envelope budgeting section (`_EnvelopeSection`)

A plain `Card`/`ListTile`-style list — one row per active spending category, `spendColor` dot + label + `formatVnd(balance)` (red when negative) — subscribed to `repo.watchEnvelopeBalances()`. Deliberately minimal (no progress bars): this session builds the data layer + a functional display; visual treatment is expected to be refined separately (this project splits core/business-logic work from UI/UX polish across two chats).

Unlike every other section on this page, envelope balances are **cumulative since forever**, not scoped to `_month` — so `_EnvelopeSection` keeps its own `StreamBuilder` rather than being folded into `_Stats`/`AnalyticsBundle`. It reuses the `catLabels` map `_AnalyticsPageState.build()` already computes once (a third consumer, alongside the two `_PieSection`s). Tapping a row calls the page's existing `_drillDown(type: TxTypes.spending, category: categoryId)` — same navigation the stat cards/pie already use, not a second mechanism.

Budget percents themselves are configured in `CategoriesPage` (Cài đặt → Quản lý danh mục), not here — see `docs/tab_settings.md`. Full computation details (the as-of join against `category_budget_history`, the non-retroactive-percentage design, why it filters `affects_balance` unlike the rest of this page) are in `docs/architecture.md`'s "Envelope budgeting" section.

## Key repository calls

- `repo.watchAnalyticsBundle(month)` — the month-scoped data dependency for everything except the envelope section.
- `repo.watchEnvelopeBalances()` — cumulative-since-forever `{categoryId → balance}` for `_EnvelopeSection`.
