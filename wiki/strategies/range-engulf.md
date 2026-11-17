---
name: RangeEngulf (V2, V7, V8, V9)
files: [RangeEngulfingStrategy/RangeEngulfV2.mq5, RangeEngulfingStrategy/RangeEngulfV7.mq5, RangeEngulfingStrategy/RangeEngulfV8.mq5, RangeEngulfingStrategy/RangeEngulfV9.mq5, RangeEngulfingStrategy/README.txt]
market: XAUUSD
timeframe: M1
family: session-breakout
origin: own (IST-session idea)
verdict: promising but tiny sample (9–14 trades/year)
source_commit: 25e734f
last_reviewed: 2026-11-14
---
# RangeEngulf (Range + Engulfing)

Marks the gold range for 12:30–17:30 IST. Then, in a 4–15 minute window around 19:00 IST, it trades one engulfing candle **against** the side of the range
price is on: sell above the range, buy below it.

## Entry (as the code does it)
- Range: M1 high/low from 09:00 to 14:00 **server** (`RangeEngulfV2.mq5:13-16`, `:141-160`). The IST mapping in the README only holds on a UTC+2 server.
- Entry window: 15:30–15:34 server (V2, V7) or 15:30–15:45 (V8, V9) (`:20-23`). [inference] If the server is UTC+2/+3 on US DST (not checked), **15:30 server = 08:30 New York**, the US data-release minute,
  so in practice this fades or rides the news candle.
- Engulfing, body over body, on bar 1 vs bar 2, with a body of 3–30 "pips" ($0.30–$3) (`:188-202`). It requires the open to be strictly beyond the prior close,
  which on M1 often fails, so trades are rare.
- Direction comes from the current bid vs the range, not from the candle: above → sell only, below → buy only, inside → either (`:191-194`, `:204`, `:219`).

## Exit
SL = engulfing wick ± 1 pip; TP = 2 R (`:208-211`). No BE, no trailing, **no time exit**, so a trade can stay open overnight.

## Sizing & risk
V2: fixed 0.10 lot (`:26`). V7–V9: 1% risk from contract size (`RangeEngulfV7.mq5:118-145`; correct for XAUUSD on a USD account), raised to the minimum lot, capped at 5 lots.

## Versions
| Version | Change |
|---|---|
| V2 | baseline, fixed 0.10 lot |
| V7 | 1% risk sizing, deviation 30 → 50 points, new magic. The README calls this the "best version". |
| V8 | window extended to 15:45, up to 2 trades. **After a loss it opens an immediate opposite trade at market** (`RangeEngulfV8.mq5:107-110`, `:289-337`). It has no time check, so the reversal can fire hours later. |
| V9 | V8's 15:45 window **without** the reversal, 1 trade/day. Otherwise = V7. The Oct report tested this one. |

## Backtest evidence
- [from report] [`README.txt`](../../RangeEngulfingStrategy/README.txt), V7, 1 year XAUUSD M1: **+$916.05, win rate 66.7%, PF 4.03, max DD 2.81%,
  9 trades**.
- [from report] [`Backtest_Report_Oct2026.md`](../../Backtest_Report_Oct2026.md), V9, 1 year: **+$704, PF 2.03, win rate 50.0%, max DD 4.7%,
  14 trades**. Last month: 0 trades.
- The two sources disagree on which version is best. Neither tested V8. 9–14 trades can't separate luck from edge.

## Issues found in code
- [unverified] Entries never check for an open position. A daily reset (`RangeEngulfV2.mq5:70-78`) while yesterday's trade is still open allows two positions.
- The window is tied to server time with no DST handling. See [server time](../concepts/server-time.md).

## Verdict & next step
The cleanest code here and a sensible idea (the US-data candle), but with too few trades to judge. Run V9 over 2023–2026 (every tick). Also check whether the trigger is
really the 08:30 ET release by shifting the window ±1 hour.

## Related
[server time](../concepts/server-time.md) · [GoldenTime](golden-time.md) (another fixed-clock gold setup) ·
[NAS100_ORB](nas100-orb.md)
