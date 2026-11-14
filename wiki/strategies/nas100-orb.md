---
name: NAS100_ORB
files: [NAS100_ORB/NAS100_ORB.mq5, NAS100_ORB/NAS100_ORB_V1.set]
market: NAS100 (Nasdaq 100 CFD)
timeframe: M1 range, tick-level breakout
family: session-breakout
origin: own
verdict: broken (bar counter counts ticks; partial close opens a hedge)
source_commit: 25e734f
last_reviewed: 2026-11-14
---
# NAS100_ORB (opening-range breakout)

Marks the first minutes of the US cash session on NAS100 and trades the breakout, with ATR, H1 EMA50 and VWAP filters.

## Entry (as the code does it)
- The opening range starts at 16:30 server by default (`NAS100_ORB.mq5:16-18`), which is 09:30 New York on a UTC+2/+3 server. **`NAS100_ORB_V1.set` uses 15:30**
  (08:30 New York), which is before the cash open [inference].
- The range comes from tick mid-prices plus M1 highs/lows (`:203-227`) and must be 200–2000 points (`:237`). What that means depends on the broker's digits.
- Entry: bid beyond the range ± 30 points (`:283-284`). Filters: an ATR ratio of the current H1 bar vs the prior 20 H1 bars (not 20 days as commented, `:368-376`), the H1 EMA50
  (`:403`), and a VWAP from server midnight using tick volume, not from the session open (`:602-623`).

## Exit
SL = range × 1, clamped to 150–1500 points; TP 2 R; BE at 1 R; trail from 1.5 R; 50% partial at 1 R (`:441-571`). The .set has `CloseEOD=false`.

## Sizing & risk
1% via tick value, falling back to a fixed lot when tick value is 0 (`:475-476`). [unverified] The lot is sized (`:309`) **before** the SL is widened to the range edge
− 50 points (`:322-323`), so real risk is above 1%.

## Backtest evidence
**No backtest on record.**

## Issues found in code
- **[verified] `gBarsAfterOR++` runs on every tick** (`:177`, no new-bar gate in `OnTick`), so `MaxBarsAfterOR = 48` means 48 *ticks*. In an every-tick
  test the breakout window closes within seconds.
- [unverified] **The partial close sends an opposite market order** (`:536-538`). On a hedging account ([inference] FundingPips accounts are usually hedging; not checked) that **opens a new, unprotected
  position** instead of closing half.
- [unverified] The deadline and "range not ready" returns (`:157`, `:165-169`) run before trade management (`:172`), so nothing is managed after 21:00. The
  daily reset sets `gEntrySL_Dist = 0` (`:707`), so overnight positions are skipped.

## Verdict & next step
Not testable as written. Fix the bar counter (count M1 bars), use `PositionClosePartial`, move management above the early returns, and use 16:30 in the
.set. Then backtest.

## Related
[server time](../concepts/server-time.md) · [common code traps](../concepts/common-code-traps.md) ·
[YT_GoldScalpers S5 NY ORB](yt-gold-scalpers.md) (the same idea on gold, PF 0.99)
