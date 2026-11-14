# Common MQL5 code traps in this repo

Mistakes that repeat across several EAs. Check new or edited code against this list.

| Trap | What goes wrong | Where seen |
|---|---|---|
| **Array indexing without `ArraySetAsSeries`** | `CopyRates` / `CopyBuffer` return the **oldest first**, so `[0]` isn't the newest bar | [AsianRangeOB](../strategies/asian-range-ob.md) retest (`:343`, [verified]), [GoldAggressiveCompounder](../strategies/gold-aggressive-compounder.md) EMA cross (`:185`, [verified]) |
| **Reading the forming bar 0** for swings or filters | Signals can appear and disappear within the bar, so live trading differs from the backtest | [SMC BOS family](../strategies/smc-bos-template-family.md), [DoubleTrap](../strategies/double-trap.md), PropFirmScalper EMA, RSI_Divergence SL helper |
| **BE branch blocks the trail** (`if BE … else if trail`, then `slDist ≤ 0 → continue` after BE) | Trailing never runs | [SMC_Confluence](../strategies/smc-confluence.md) [verified], [MultiTF_Scalper](../strategies/multitf-scalper.md) [verified] |
| **R measured from the current SL** | After BE, "1 R" shrinks to a few points and later rules fire at once | [GoldAggressiveCompounder](../strategies/gold-aggressive-compounder.md), [GoldEliteScalper](../strategies/gold-elite-scalper.md) after restart |
| **Broker TP = partial-close price** | The broker TP closes everything before the partial logic runs | [GoldenTime](../strategies/golden-time.md) [verified] |
| **Early `return` before trade management** | Open positions lose trailing, EOD close or guards | [MultiSession](../strategies/multi-session-major-pairs.md) [verified], [NAS100_ORB](../strategies/nas100-orb.md), GoldEliteScalper, LiquiditySweepScalper |
| **Counters on ticks instead of bars** | "48 bars" = 48 ticks | [NAS100_ORB](../strategies/nas100-orb.md) [verified] |
| **Partial close by opposite order** | On a hedging account this opens a new position | [NAS100_ORB](../strategies/nas100-orb.md) |
| **State only in globals** (`g_inTrade`, BE flags, day/peak balance) | A terminal restart forgets open trades and guards | LiquiditySweep, PropFirm, EMA_VWAP, M1_Momentum, SMC_LumenTrades, GoldEliteScalper |
| **"VWAP" updated only when filters pass** | Not a real session VWAP | [EMA_VWAP](../strategies/ema-vwap-scalper.md), [M1_Momentum](../strategies/m1-momentum-scalper.md); GoldElite/EMA_VWAP/M1 share a copied VWAP block that starts at EA launch |
| **Account-wide history for cooldowns** | Another EA's deal resets or blocks this EA's cooldown | [SMC_Confluence](../strategies/smc-confluence.md) `OnTradeTransaction`, [DoubleTrap](../strategies/double-trap.md) |
| **Shared magic numbers** | Two EAs manage each other's trades | GoldenTime V5 + 1845 (184500); RSI_Divergence V1 + V2 (20261025) |
| **Hard-coded `ORDER_FILLING_IOC`** | FOK-only brokers reject every order | SMC BOS family, GoldAggressiveCompounder, M1_Momentum |
| **Raw `_Point` distances** | All point inputs assume 2-digit gold (0.01); on a 3-digit symbol every SL, buffer and spread cap is 10× smaller | almost every EA |
| **Price filters sized for old gold prices** | Fixed $ ranges reject most days at $3–4k gold | [GoldLondon](../strategies/gold-london.md), [GoldenTime V5](../strategies/golden-time.md) |
| **Order results unchecked** | Only the `bool` from `trade.Buy/Sell` is checked, never `ResultRetcode()`; `PositionModify` results are ignored; nobody checks `SYMBOL_TRADE_STOPS_LEVEL` | all EAs |
| **Header comment ≠ code** | The docs describe a different strategy | [M1_Momentum](../strategies/m1-momentum-scalper.md), [GoldEliteScalper](../strategies/gold-elite-scalper.md) ("6 of 6"), [MultiTF](../strategies/multitf-scalper.md) (3 TPs) |

What's generally fine: indicator handles are created once in `OnInit`, and position loops filter by magic number and symbol.
