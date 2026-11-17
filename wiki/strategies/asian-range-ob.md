---
name: AsianRangeOB
files: [AsianRangeOB/AsianRangeOB.mq5]
market: XAUUSD (range filters of 200–2000 points suggest gold)
timeframe: chart timeframe (PERIOD_CURRENT), tested on M5
family: session-breakout
origin: own
verdict: marginal
source_commit: 25e734f
last_reviewed: 2026-11-14
---
# AsianRangeOB

Marks a one-hour early-Asian range. It waits for a candle to break out of it, finds the order block that caused the break, and enters
when price pulls back into that block.

## Entry (as the code does it)
- Range window: 4:30–5:30 IST, coded as 02:00–03:00 **server time on a UTC+3 broker** (`AsianRangeOB.mq5:15-17`). On a UTC+2
  winter server it's an hour off. See [server time](../concepts/server-time.md).
- The range high/low is built from **live bid ticks** (`:175-177`), so starting or restarting the EA mid-window gives a partial range.
- Breakout: closed bar 1 must *open inside* the range and close ≥30 points outside it (`:221`, `:243`). A slow drift out of the range is never caught.
- OB: the last opposite-colour candle before the breakout, using its body (`:280-296`). There's no displacement check, despite the comment.
- Entry: the pullback bar touches the OB and closes beyond it, **or simply when the ask is inside the OB** (`:354`).
- Thursdays and Fridays are skipped. One trade per day.

## Exit
SL = OB edge ± 30 points; TP = 2 R. At 1 R: BE +10 points and TP extended to 4 R (`:455-463`). Trailing by 80 points from 2 R (`:468-472`).

## Sizing & risk
Fixed 0.10 lot. No min/max SL check (only `slDist <= 0`, `:362`).

## Backtest evidence
[`Backtest_Report_Oct2026.md`](../../Backtest_Report_Oct2026.md) [from report]: 1 year **+$144, PF 1.06, max DD 11.8%, 48 trades**;
last month +$181, PF 1.40, 8 trades. Too few trades to conclude anything.

## Issues found in code
- **[verified] The retest checks the wrong bar.** `CopyRates(_Symbol, PERIOD_CURRENT, 1, 2, rates)` (`:343`) without `ArraySetAsSeries`
  returns the oldest bar first, so `rates[0]` is **bar 2**, not the "last closed bar" the comment says (`:350`). The rejection test is one bar late.
- [unverified] The failed-breakout check (`:379-382`) and the day reset (`:104-109`) can set state to DONE while a position is
  open. The open trade then loses its BE and trailing management.
- [unverified] The BE flag is set without checking the modify (`:463`).

## Verdict & next step
Barely positive and under-sampled. Fix the bar index (use `rates[1]` or set the array as series), remove the `priceInOB` shortcut,
derive the range from M1 bars instead of ticks, then retest over 2–3 years.

## Related
[server time](../concepts/server-time.md) · [SMC terms as coded](../concepts/smc-terms-as-coded.md) ·
[SMC_Confluence](smc-confluence.md) (same coding style) · [GoldLondon](gold-london.md) (another session-range idea)
