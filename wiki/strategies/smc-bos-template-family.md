---
name: SMC BOS template family (4 EAs)
files: [SMC_2xBOS_BreakerBlock/SMC_2xBOS_BreakerBlock.mq5, SMC_2xBOS_BB_Scalp/SMC_2xBOS_BB_Scalp.mq5, SMC_3xBOS_Reversal/SMC_3xBOS_Reversal.mq5, SMC_LiqSweep_OB_IFVG/SMC_LiqSweep_OB_IFVG.mq5]
market: not stated (gold-sized point defaults)
timeframe: HTF/LTF pairs — H1/M5, M5/M1, M15/M5
family: smc
origin: own
verdict: untested (no backtest on record; logic is loosely tied to the names)
source_commit: 25e734f
last_reviewed: 2026-11-14
---
# SMC BOS template family

Four EAs built from **one copy-pasted template** (all have the same "Trading EAs" header). Each one looks for a higher-timeframe structure
pattern, then a lower-timeframe confirmation. Every one of them **enters at market** and uses the SMC zone **only to place the stop**.
None waits for a retest of the zone.

| EA | HTF / LTF | Idea | Direction |
|---|---|---|---|
| `SMC_2xBOS_BreakerBlock` | H1 / M5 (`:14-15`) | 2 breaks of structure, then demand zone + LTF "MSS" + breaker | with trend |
| `SMC_2xBOS_BB_Scalp` | M5 / M1 (`:14-15`) | same as BreakerBlock with tighter numbers, BE, spread filter | with trend |
| `SMC_3xBOS_Reversal` | H1 / M5 (`:14-15`) | 3 breaks in one direction = exhaustion → trade the **opposite** way (`:101`) | counter-trend |
| `SMC_LiqSweep_OB_IFVG` | M15 / M5 (`:14-15`) | liquidity sweep of a swing low, then BOS, OB and inverse FVG | reversal after sweep |

## Entry (as the code does it)
- **Shared gate:** logic runs only when a new LTF bar opens. Stop management sits behind the same gate, so it also runs only once per LTF bar.
- **2xBOS:** among the 3 newest HTF swing highs, any 2 have a later close above them. The breaks don't need to be consecutive, and higher highs aren't required
  (`SMC_2xBOS_BreakerBlock.mq5:158-163`; Scalp `:163-167`).
- **Zone:** the newest bearish candle followed by a bigger bullish one (1.5× in BreakerBlock `:196`, 1.2× in Scalp). It isn't tied to the BOS.
- **"MSS":** *any* LTF swing high within 30 bars (25 in Scalp) that bar 1 or 2 closed above (BreakerBlock `:241-249`).
- **Breaker:** swing low → swing high → lower low → close above the high (`:284-313`). It only feeds the stop.
- **3xBOS_Reversal:** 3 HTF swings each broken, consecutively (`:150-157`). Then an "any recent" ChoCH (`:187-195`), an HTF FVG within 15 bars and
  within 100 points of price (`:112`, `:226-237`), and an LTF inverse FVG (`:271-282`).
- **LiqSweep_OB_IFVG:** a wick below one of the 3 newest swing lows with a close back above, within bars 1–14 (`:194-195`). Then a close above a
  swing high formed after the sweep (`:199-200`; the code contradicts its own comment). Then the newest bearish/bullish candle pair in bars 2–9 as the OB, not linked to the sweep
  (`:259-268`), and an inverse FVG (`:330`).
- Hours 8–20 server time.

## Exit
SL = the zone or breaker extreme ± a buffer (30 points BreakerBlock, 20 Scalp, 50 3xBOS and LiqSweep), and the trade is skipped outside a min/max SL range.
TP = `MinRR` × SL (2 R or 2.5 R). Trailing starts at 1 R. Scalp also moves to BE +10 points (`:421-425`).

## Sizing & risk
Fixed 0.10 lot by default. In % mode, a tick value of 0 silently falls back to `FixedLot` (BreakerBlock `:412-413`, LiqSweep `:429-432`).
Only LiqSweep caps the maximum lot (`:441`).

## Backtest evidence
**No backtest on record** for any of the four.

## Issues found in code (shared unless noted)
- [unverified] **Swings use the unfinished bar:** `CopyRates(..., 0, ...)` with series indexing, and the loop reaches the forming bar 0
  (BreakerBlock `:131/:140`, Scalp `:143/:151`, 3xBOS `:129/:138`, LiqSweep `:154/:230`). Swing points can appear and then disappear in live trading,
  which a backtest won't fully show.
- [unverified] Order filling is hard-coded with `trade.SetTypeFilling(ORDER_FILLING_IOC)` (BreakerBlock `:75`, 3xBOS `:70`, LiqSweep `:89`). Brokers that only accept FOK will reject every order.
- [unverified] The cooldown counter is reset at *entry* (`:400`, 3xBOS `:337`), so there's effectively no cooldown after an exit.
- [unverified] Scalp only: `BreakerBlock bb;` is never initialised (`:131`), but `bb.high == 0` / `bb.low == 0` are tested (`:291`, `:321`).
- SL, TP and trail prices are not normalized. Unused state variables in LiqSweep.

## Verdict & next step
The names promise sequenced SMC setups, but the code checks independent "any recent X" conditions and enters at market. Before
backtesting: use only closed bars for swings, enter on the zone retest, and make the filling mode match the broker.

## Related
[SMC terms as coded](../concepts/smc-terms-as-coded.md) · [position sizing](../concepts/position-sizing.md) ·
[SMC_Confluence](smc-confluence.md)
