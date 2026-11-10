# SMC Confluence - Strategy Variation Results
## XAUUSD M5 | Oct 2025 - Oct 2026 | $10,000 deposit | Every Tick

### Full Comparison Table

| # | Description | Profit | DD% | WR% | PF | Sharpe | RecFact | Trades |
|---|------------|--------|-----|-----|-----|--------|---------|--------|
| Baseline | RR 2.5, ATR 1.5x | $2,026 | 14.4% | 54.6% | 1.53 | 13.3 | 1.37 | 119 |
| V1 | RR 2.0, ATR 1.0x | $1,420 | 10.4% | 55.7% | 1.40 | 12.6 | 1.34 | 122 |
| V2 | RR 2.0, ATR 1.5x | $1,827 | 10.7% | 55.4% | 1.46 | 13.2 | 1.68 | 121 |
| V3 | RR 3.0, ATR 1.5x | $1,165 | 16.9% | 55.1% | 1.31 | 6.6 | 0.67 | 118 |
| V4 | RR 2.5, ATR 2.0x | $2,106 | 15.6% | 55.1% | 1.53 | 11.6 | 1.32 | 118 |
| V5 | RR 2.0, 1 trade/day | $773 | 8.6% | 59.1% | 1.30 | 11.2 | 0.88 | 93 |
| V6 | RR 2.5, NY only | $1,932 | 12.7% | 55.5% | 1.58 | 15.3 | 1.53 | 101 |
| V7 | RR 2.0, tight SMC | $316 | 9.1% | 62.0% | 1.11 | 3.6 | 0.35 | 113 |
| V8 | Conservative all | -$431 | 11.7% | 56.3% | 0.77 | -5.0 | -0.37 | 64 |

### Top 3 Recommendations

1. **V2 (RR 2.0, ATR 1.5x)** - BEST BALANCED
   - Profit: $1,827 | DD: 10.7% | WR: 55.4% | PF: 1.46 | Recovery: 1.68
   - Best drawdown-to-profit ratio, most consistent

2. **V6 (RR 2.5, NY Only)** - BEST RISK-ADJUSTED
   - Profit: $1,932 | DD: 12.7% | WR: 55.5% | PF: 1.58 | Sharpe: 15.3
   - Highest PF and Sharpe, NY session is the edge

3. **V5 (RR 2.0, 1 trade/day)** - SAFEST
   - Profit: $773 | DD: 8.6% | WR: 59.1% | PF: 1.30
   - Lowest drawdown, highest win rate, fewer trades

### Key Findings

- RR 2.0 outperforms RR 2.5 and 3.0 for win rate and drawdown control
- ATR 1.5x is the optimal SL multiplier
- NY session (15:00-21:00) is where the real edge lies
- London session (11:00-13:00) adds marginal value with added risk
- 1 trade/day drastically reduces DD but limits upside
- Over-filtering SMC zones (V7/V8) kills profitability

### Parameter Details per Variation

#### Baseline (Current Default)
- RR=2.5, ATR_SL=1.5, MaxSL=1200, BE@1R, Trail@2R/100pts
- London 11-13, NY 15-21, Skip Tuesday, 2 trades/day, Cooldown 6 bars

#### V1: RR 2.0, ATR 1.0x
- Tighter SL (1.0x ATR), MaxSL=1000, earlier trail@1.5R

#### V2: RR 2.0, ATR 1.5x
- Same SL as baseline but lower RR target, trail@1.5R

#### V3: RR 3.0, ATR 1.5x
- Wider TP target, trail@2R

#### V4: RR 2.5, ATR 2.0x
- Wider SL (2.0x ATR), MaxSL=1500, trail@2R/150pts

#### V5: RR 2.0, 1 trade/day
- Max 1 trade/day, early BE@0.8R, lock 30pts, trail@1.5R/80pts, cooldown 8 bars

#### V6: RR 2.5, NY Only
- London disabled (LDN_Start=23), NY 15-21 only

#### V7: RR 2.0, Tight SMC
- RSI 48/52, OB/FVG max dist 1.5 ATR, OB displacement 2.0x, FVG min 40pts

#### V8: Conservative
- ATR 1.2x, MaxSL=800, BE@0.7R, trail@1.3R/80pts, NY 16-20 only, 1 trade/day, spread<40
