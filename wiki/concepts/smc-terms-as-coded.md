# SMC terms, as this repo's code defines them

"Smart Money Concepts" words mean different things in different EAs. This page records what the **code** checks, so pages and conversations don't
assume the textbook meaning.

| Term | Textbook meaning | What the code here does |
|---|---|---|
| **Swing high/low** | a confirmed pivot | Strict N-bars-each-side fractal. N = 2 ([SMC_Confluence](../strategies/smc-confluence.md) BOS), 5 ([SMC_LumenTrades](../strategies/smc-lumentrades.md), [RSI_Divergence](../strategies/rsi-divergence.md), [LiquiditySweep](../strategies/liquidity-sweep-scalper.md)). The [SMC BOS family](../strategies/smc-bos-template-family.md) and [DoubleTrap](../strategies/double-trap.md) can read the **forming bar 0**, so their swings can repaint. |
| **BOS** (break of structure) | a close beyond the last swing in the trend direction | Confluence: the last closed bar beyond the newest 2-bar fractal. BOS family: "any 2 (or 3) of the newest swings have a later close beyond them", with no check for consecutive higher highs. |
| **ChoCH / MSS** | the first break against the prior trend | LumenTrades: lower low + close above the last swing high (it doesn't check the break is new). BOS family: *any* LTF swing within 25–30 bars closed past by bar 1 or 2. |
| **Order block (OB)** | the last opposite candle before a displacement move | Usually "a bearish candle followed by a bullish candle with a body ≥ 1.2–1.5× bigger" (Confluence, BOS family, AsianRangeOB), using the body. LumenTrades uses the full H1 wick range. It's rarely tied to the BOS or sweep it supposedly caused. |
| **FVG** (fair value gap) | a 3-candle imbalance, still unfilled | `low[i] > high[i-2]` (bullish). **No "still unfilled" check** in Confluence; [GoldLondon](../strategies/gold-london.md) doesn't require the FVG to form after the grab. |
| **IFVG** (inverse FVG) | a gap that price closed through, then used as the opposite zone | BOS family / 3xBOS / LiqSweep: an opposite gap that a later bar closed through, plus a momentum check. Entry is at market, with no retest. |
| **Liquidity sweep / grab** | a run past a swing level that reverses | A wick past a level with a close back inside, on one bar ([LiquiditySweep](../strategies/liquidity-sweep-scalper.md), [GoldLondon](../strategies/gold-london.md), LiqSweep_OB_IFVG, [DoubleTrap](../strategies/double-trap.md) "trap"). |
| **Breaker block** | a failed OB that flips role | BOS family: swing low → swing high → lower low → close above the high. **It only sets the SL**; it's never the entry zone. |
| **Kill zone** | London / NY high-activity windows | Fixed server hours. See [server time](server-time.md). |

**Common pattern:** most SMC EAs here **enter at market** once all the "any recent X" checks are true, then use the zone only for the stop. Real SMC entries wait
for a retest of the zone. That's the biggest gap between the names and the code.
