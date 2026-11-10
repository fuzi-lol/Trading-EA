//+------------------------------------------------------------------+
//|                                       CandleColor_ATR_EA.mq5      |
//|   Intra-bar candle color EA with FIXED-DOLLAR TP/SL              |
//|   (filename kept as-is for continuity; ATR is no longer used      |
//|   for risk sizing -- see notes below)                             |
//|                                                                    |
//|   LOGIC (confirmed with user):                                    |
//|   - Watches the M5 candle that is CURRENTLY FORMING (live, tick   |
//|     by tick), not the last closed candle.                        |
//|   - If current price > current candle's open  -> bias = BUY      |
//|   - If current price < current candle's open  -> bias = SELL     |
//|   - This is intentional: the user explicitly rejected reacting    |
//|     to the previous CLOSED candle's color, because that is a     |
//|     lagging signal (e.g. it can buy into the 3rd green candle of |
//|     a liquidity sweep right before it reverses). Reacting to the  |
//|     live, currently-forming candle is the closest thing to a     |
//|     true "candle color" reaction possible in MT5.                |
//|   - When the bias flips, a new position is opened in the new     |
//|     bias direction (if one isn't already open that way). By      |
//|     DEFAULT, the opposite-direction position is left alone to    |
//|     run to its own SL/TP rather than being force-closed on the   |
//|     flip. Set InpCloseOppositeOnFlip=true to restore flip-close   |
//|     behavior. Note: this means BUY and SELL can be open on the   |
//|     same symbol simultaneously (requires a hedging-enabled       |
//|     account, e.g. FBS Markets demo/live).                        |
//|   - Only one position per direction at a time (no stacking).     |
//|                                                                    |
//|   RISK MODEL -- FIXED DOLLAR TP/SL, NO ATR (changed per user      |
//|   request after live testing showed the problem with ATR-based    |
//|   sizing: on a 0.01 lot, ATR-derived TP distances were often too  |
//|   far away to realistically be hit before price reversed and hit |
//|   the SL instead -- trades floated near +$4 profit, the EA had no |
//|   mechanism to bank that, and they later closed at SL for a loss. |
//|   Fixed, reachable dollar targets solve this directly):           |
//|   - TP = InpFixedTPDollar (default $4.00) on every trade.          |
//|   - SL = InpFixedSLDollar (default $2.50 as of v2.1) on every     |
//|     trade -- a 1.6:1 reward:risk ratio. This was changed from an  |
//|     initial 1:1 ($4/$4) after live demo testing showed an actual  |
//|     win rate of ~43% (9 wins / 12 losses over 21 trades). At 1:1,  |
//|     breakeven requires >=50% win rate, so 1:1 was guaranteed to    |
//|     lose money long-run at that win rate. The mathematical         |
//|     breakeven R:R at a 43% win rate is (1-0.43)/0.43 ~= 1.33:1;    |
//|     1.6:1 was chosen to sit above that with a safety margin, so   |
//|     the EA can stay profitable even if win rate drifts down        |
//|     slightly. This is a MECHANICAL fix (changes how much is won   |
//|     vs lost per trade) -- it does NOT change which trades are      |
//|     taken or improve win rate itself. A separate, planned signal   |
//|     filter (e.g. higher-timeframe trend confirmation) is the next  |
//|     step for improving win rate, and should be tested separately  |
//|     from this R:R change so the two effects aren't conflated.      |
//|   - Both $ targets are converted into an actual price distance     |
//|     using the trade's real lot size (so the $ amount is exact,    |
//|     not approximate), via the same tick-value math for both.       |
//|   - ATR is NOT used anywhere in this calculation. No ATR handle    |
//|     is created at all -- this EA no longer depends on ATR.        |
//|   - InpLots defaults to 0.01 as requested; if InpUseRiskPercent    |
//|     is enabled instead, lot size is derived from InpRiskPercent    |
//|     of balance against the $ SL amount (so larger accounts risk   |
//|     more $ per trade automatically, while small accounts stay at  |
//|     minimum lot). Leave it OFF (default) to keep lot size fixed   |
//|     at exactly InpLots regardless of balance.                     |
//|                                                                    |
//|   SECOND, FULLY INDEPENDENT SIGNAL -- LIQUIDITY SWEEP REVERSAL:    |
//|   - Liquidity level = highest high / lowest low of the last        |
//|     InpSweepLookback (default 10) FULLY CLOSED candles.            |
//|   - Sweep "taken": at any point during the currently forming       |
//|     candle, its high goes above that level (upside sweep) or its  |
//|     low goes below it (downside sweep).                            |
//|   - Sweep "confirmed" (the actual entry trigger): after being      |
//|     taken, price comes back inside the range -- checked LIVE,      |
//|     tick by tick, using current price as a provisional "close".    |
//|     This is provisional: if price wicks back outside again before  |
//|     the bar closes, confirmation reverts to false until price      |
//|     comes back inside again.                                       |
//|   - Bullish sweep confirmed (low swept + reclaimed) -> BUY.         |
//|     Bearish sweep confirmed (high swept + reclaimed) -> SELL.      |
//|   - Runs completely independently of the intra-bar signal above:   |
//|     separate position tracking (by trade comment tag), separate    |
//|     one-buy/one-sell cap. This means up to 4 positions can be open |
//|     at once (intra-bar buy, intra-bar sell, sweep buy, sweep       |
//|     sell) if both systems fire in different directions.            |
//|   - Sweep trades use the EXACT SAME fixed-$ TP/SL engine as        |
//|     intra-bar trades -- only the entry trigger differs.            |
//|   - Set InpEnableSweepSignal=false to disable this signal entirely |
//|     and run intra-bar-only.                                        |
//|                                                                    |
//|   MULTI-TIMEFRAME TREND FILTER (gates BOTH signals identically):   |
//|   - Checks M15, H1, and H4. H4 is INFORMATIONAL ONLY (logged, does |
//|     not block trades) -- only M15 and H1 can block.                |
//|   - Per-timeframe trend = EMA(InpMTF_EMA_Period, default 50)        |
//|     direction AND 5-candle fractal swing structure must AGREE:     |
//|       Bullish = price above EMA AND last 2 confirmed swings show   |
//|                 higher-high + higher-low                            |
//|       Bearish = price below EMA AND lower-high + lower-low         |
//|       Neutral = anything else (MA/structure disagree, or not        |
//|                 enough confirmed swing data in the lookback yet)    |
//|   - Fractal swings use the standard non-repainting 5-candle         |
//|     definition (2 bars before + 2 bars after must already be       |
//|     closed), same as used in real SMC/ICT structure analysis.      |
//|   - GATING RULE: a BUY is blocked only if M15 OR H1 reads hard      |
//|     Bearish. A SELL is blocked only if M15 OR H1 reads hard         |
//|     Bullish. Neutral on either timeframe does NOT block -- this    |
//|     was a deliberate choice (vs. requiring full agreement) because  |
//|     requiring true bullish/bearish agreement on both M15 and H1     |
//|     simultaneously is rare and would starve the EA of trades.       |
//|     Only a direct, hard contradiction (e.g. buying into a clearly   |
//|     bearish H1) gets blocked.                                       |
//|   - This filter is a PURE GATE -- it only blocks/allows the entry   |
//|     signals already generated by the intra-bar and sweep systems;   |
//|     it does not generate signals of its own.                        |
//|   - Set InpEnableMTFFilter=false to disable and trade unfiltered.   |
//|                                                                    |
//|   QUICK-SCALP CLOSE (EA-managed, runs alongside broker TP/SL):     |
//|   - Added after live testing showed trades repeatedly reaching     |
//|     +$1 floating profit but failing to reach the $4 broker TP,     |
//|     then reversing all the way to the $2.50 SL for a loss. Rather  |
//|     than wait for the broker TP, the EA now actively monitors      |
//|     every open position every tick and force-closes it the instant  |
//|     floating profit reaches InpScalpProfitDollar (default $1).     |
//|   - The broker-side $4 TP / $2.50 SL stays attached to every order  |
//|     as a BACKSTOP ONLY -- it protects you if the EA disconnects,    |
//|     the terminal closes, or a tick is somehow missed. In normal     |
//|     operation the $1 scalp-close fires first and the broker TP is   |
//|     essentially never reached.                                      |
//|   - NOTE ON RISK:REWARD: scalping at $1 against a $2.50 SL is a     |
//|     0.4:1 reward:risk ratio (the inverse of the 1.6:1 the broker    |
//|     TP/SL was tuned for). This requires a notably higher win rate    |
//|     (~71%+) to break even, since losses are now 2.5x the size of    |
//|     wins. This tradeoff was discussed and accepted: the bet is that  |
//|     $1 targets get hit far more often than $4 ones, more than        |
//|     compensating for the worse per-trade ratio. Watch your actual    |
//|     win rate on demo to confirm this holds before going live.        |
//|   - After a scalp-close, if InpReopenAfterScalp=true (default), the  |
//|     EA immediately re-checks whether the ORIGINAL entry condition    |
//|     for that position (intra-bar bias still same direction, or       |
//|     sweep still confirmed) is STILL true right now. Only if it is    |
//|     does it open a new position in the same direction immediately   |
//|     -- otherwise it does nothing and lets the normal signal logic    |
//|     pick things up naturally on a later tick. This was a deliberate  |
//|     choice over blind re-entry, to avoid forcing trades against      |
//|     price action that has already turned.                            |
//|   - Applies identically to BOTH the intra-bar and sweep signals.     |
//|   - Set InpEnableQuickScalp=false to disable and rely purely on the  |
//|     broker-side $4/$2.50 TP/SL again, like before this feature.      |
//|                                                                    |
//|   DAILY PROFIT TARGET / CIRCUIT BREAKER:                           |
//|   - Tracks cumulative CLOSED (realized) profit for this EA's        |
//|     trades only (filtered by magic number) since the last           |
//|     broker-server-time midnight, by scanning the account's deal     |
//|     history -- this is accurate even across terminal restarts.       |
//|   - Once that total reaches InpDailyTargetDollar (default $20),     |
//|     the EA STOPS OPENING NEW TRADES for the rest of the day          |
//|     (intra-bar, sweep, AND scalp-reopen are all gated). Positions    |
//|     already open at that moment are explicitly LEFT ALONE to run     |
//|     to their own TP/SL/scalp-close -- the breaker only blocks new     |
//|     entries, confirmed as the safer choice over force-closing         |
//|     everything.                                                       |
//|   - Fires exactly once per day, the moment the target is crossed:    |
//|     an on-chart Alert() popup, a persistent Comment() on the chart,  |
//|     and an MT5 push notification via SendNotification() if           |
//|     InpSendPushNotification=true (requires a MetaQuotes ID            |
//|     configured in Tools->Options->Notifications; fails silently      |
//|     and harmlessly if not configured).                                |
//|   - Automatically resets to $0 and re-arms at the next broker-time    |
//|     midnight -- no manual intervention needed.                        |
//|   - Set InpEnableDailyTarget=false to disable entirely.               |
//+------------------------------------------------------------------+
#property copyright "Karisa"
#property version   "2.30"
#property strict

#include <Trade\Trade.mqh>

//--- Inputs
input group "=== Signal Settings ==="
input ENUM_TIMEFRAMES InpTimeframe        = PERIOD_M5;   // Timeframe whose forming candle is watched
input int             InpMagicNumber      = 990011;      // Magic number for this EA's trades

input group "=== Risk / Lot Settings ==="
input double          InpLots             = 0.01;        // Fixed lot size per trade
input bool            InpUseRiskPercent   = false;        // If true, size lots by % risk instead of fixed lot
input double          InpRiskPercent      = 1.0;          // Risk % of balance per trade (only if InpUseRiskPercent=true)

input group "=== Fixed Dollar TP / SL (1:1 by default, no ATR) ==="
input double          InpFixedTPDollar    = 4.0;          // Fixed TP target in account currency (e.g. $4)
input double          InpFixedSLDollar    = 2.5;          // Fixed SL loss amount in account currency (e.g. $2.50 -> 1.6:1 reward:risk vs $4 TP)

input group "=== Trade Management ==="
input bool            InpCloseOppositeOnFlip = false;      // Close opposite-direction position when bias flips (false = SL/TP manage all exits)
input int             InpMaxSpreadPoints  = 50;             // Skip new entries if spread exceeds this (points)
input int             InpSlippage         = 10;             // Allowed slippage in points

input group "=== Liquidity Sweep Settings ==="
input bool            InpEnableSweepSignal = true;          // Enable the independent liquidity sweep reversal signal
input int             InpSweepLookback     = 10;             // N closed candles used to define the swept high/low

input group "=== Multi-Timeframe Trend Filter ==="
input bool            InpEnableMTFFilter   = true;           // Enable M15+H1 trend agreement filter (H4 informational only)
input int             InpMTF_EMA_Period    = 50;             // EMA period used for trend direction on M15/H1/H4
input int             InpMTF_FractalLookback = 50;           // How many bars back to search for the last confirmed fractal swing pair

input group "=== Quick-Scalp Close (EA-managed, on top of broker TP/SL backstop) ==="
input bool            InpEnableQuickScalp  = true;           // Enable EA-side $ profit quick-close (independent of broker TP)
input double          InpScalpProfitDollar = 1.0;            // Close a position the instant its floating profit reaches this $ amount
input bool            InpReopenAfterScalp  = true;           // After a scalp-close, immediately re-check signal and re-enter same direction if still valid

input group "=== Daily Profit Target / Circuit Breaker ==="
input bool            InpEnableDailyTarget = true;           // Enable daily profit target circuit breaker
input double          InpDailyTargetDollar = 20.0;           // Once cumulative CLOSED profit since midnight reaches this, stop opening new trades
input bool            InpSendPushNotification = true;        // Send MT5 push notification when daily target is hit (needs MetaQuotes ID configured)

//--- Globals
CTrade        trade;
datetime      lastBarTime = 0;   // tracks the open time of the candle currently being watched (intra-bar signal)
int           lastBias    = 0;   // 0 = none, 1 = buy bias, -1 = sell bias (state of the CURRENT forming candle, intra-bar signal)

//--- Sweep signal globals (fully independent from the intra-bar signal above)
datetime      sweepBarTime    = 0;     // tracks the open time of the candle currently being watched (sweep signal)
double        sweepLevelHigh  = 0;     // the N-bar high being watched for an upside sweep this candle
double        sweepLevelLow   = 0;     // the N-bar low being watched for a downside sweep this candle
bool          sweepHighTaken  = false; // true once current candle's high has poked above sweepLevelHigh at some point this bar
bool          sweepLowTaken   = false; // true once current candle's low has poked below sweepLevelLow at some point this bar
int           lastSweepSignal = 0;     // 0 = none, 1 = bullish sweep confirmed, -1 = bearish sweep confirmed (provisional, re-evaluated every tick)

#define TAG_INTRABAR "CandleColor"
#define TAG_SWEEP    "LiquiditySweep"

//--- MTF trend filter globals
int emaHandleM15 = INVALID_HANDLE;
int emaHandleH1  = INVALID_HANDLE;
int emaHandleH4  = INVALID_HANDLE;

// Trend states: 1 = Bullish, -1 = Bearish, 0 = Neutral
enum TrendState { TREND_BEARISH = -1, TREND_NEUTRAL = 0, TREND_BULLISH = 1 };

//--- Daily profit target / circuit breaker globals
datetime      dailyResetDay   = 0;     // the broker-time DAY (date-truncated) the counter was last reset for
double        dailyClosedPL   = 0;     // cumulative CLOSED profit (this EA's trades only) since the last reset
bool          dailyTargetHit  = false; // true once InpDailyTargetDollar has been reached today; blocks new entries until reset
ulong         lastDealTicketSeen = 0;  // last history deal ticket already counted, to avoid double-counting on each scan

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   trade.SetExpertMagicNumber(InpMagicNumber);
   trade.SetDeviationInPoints(InpSlippage);
   trade.SetTypeFillingBySymbol(_Symbol);

   lastBarTime = 0;
   lastBias    = 0;

   sweepBarTime    = 0;
   sweepLevelHigh  = 0;
   sweepLevelLow   = 0;
   sweepHighTaken  = false;
   sweepLowTaken   = false;
   lastSweepSignal = 0;

   if(InpEnableMTFFilter)
   {
      emaHandleM15 = iMA(_Symbol, PERIOD_M15, InpMTF_EMA_Period, 0, MODE_EMA, PRICE_CLOSE);
      emaHandleH1  = iMA(_Symbol, PERIOD_H1,  InpMTF_EMA_Period, 0, MODE_EMA, PRICE_CLOSE);
      emaHandleH4  = iMA(_Symbol, PERIOD_H4,  InpMTF_EMA_Period, 0, MODE_EMA, PRICE_CLOSE);

      if(emaHandleM15 == INVALID_HANDLE || emaHandleH1 == INVALID_HANDLE || emaHandleH4 == INVALID_HANDLE)
      {
         Print("Failed to create one or more MTF EMA handles. Error: ", GetLastError());
         return INIT_FAILED;
      }
   }

   // --- Daily profit target / circuit breaker: initialize for "today" and
   //     back-scan today's already-closed deals so a restart mid-day doesn't
   //     lose track of profit already banked today.
   dailyResetDay  = 0;
   dailyClosedPL  = 0;
   dailyTargetHit = false;
   lastDealTicketSeen = 0;
   RefreshDailyPLIfNeeded(true); // force initial scan

   Print("CandleColor_ATR_EA initialized (v2.30, fixed-$ TP/SL 1.6:1 R:R, no ATR, MTF filter, quick-scalp, daily target). Watching ", EnumToString(InpTimeframe),
         " live candle color. TP=$", DoubleToString(InpFixedTPDollar,2),
         " SL=$", DoubleToString(InpFixedSLDollar,2),
         ". Liquidity sweep signal: ", InpEnableSweepSignal ? "ENABLED" : "disabled",
         " (lookback=", InpSweepLookback, ")",
         ". MTF trend filter: ", InpEnableMTFFilter ? "ENABLED" : "disabled",
         " (EMA", InpMTF_EMA_Period, " on M15/H1/H4, M15+H1 must not oppose, H4 informational)",
         ". Quick-scalp: ", InpEnableQuickScalp ? "ENABLED" : "disabled",
         " ($", DoubleToString(InpScalpProfitDollar,2), " instant close, reopen=", InpReopenAfterScalp?"yes":"no", ")",
         ". Daily target: ", InpEnableDailyTarget ? "ENABLED" : "disabled",
         " ($", DoubleToString(InpDailyTargetDollar,2), ", current banked today: $", DoubleToString(dailyClosedPL,2), ")");

   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   if(emaHandleM15 != INVALID_HANDLE) IndicatorRelease(emaHandleM15);
   if(emaHandleH1  != INVALID_HANDLE) IndicatorRelease(emaHandleH1);
   if(emaHandleH4  != INVALID_HANDLE) IndicatorRelease(emaHandleH4);
}

//+------------------------------------------------------------------+
//| Count open positions for this EA, by direction, FILTERED BY TAG  |
//| (tag = TAG_INTRABAR or TAG_SWEEP) so the two signal systems each  |
//| have their own independent one-buy/one-sell cap.                  |
//+------------------------------------------------------------------+
void CountPositions(string tag, bool &hasBuy, bool &hasSell)
{
   hasBuy  = false;
   hasSell = false;

   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      if(!PositionSelectByTicket(ticket)) continue;

      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if(PositionGetInteger(POSITION_MAGIC) != InpMagicNumber) continue;

      string posComment = PositionGetString(POSITION_COMMENT);
      if(StringFind(posComment, tag) < 0) continue; // not this signal system's position

      long type = PositionGetInteger(POSITION_TYPE);
      if(type == POSITION_TYPE_BUY)  hasBuy  = true;
      if(type == POSITION_TYPE_SELL) hasSell = true;
   }
}

//+------------------------------------------------------------------+
//| Close all positions for this EA, for a given tag, in a direction  |
//+------------------------------------------------------------------+
void CloseDirection(string tag, long positionType)
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      if(!PositionSelectByTicket(ticket)) continue;

      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if(PositionGetInteger(POSITION_MAGIC) != InpMagicNumber) continue;

      string posComment = PositionGetString(POSITION_COMMENT);
      if(StringFind(posComment, tag) < 0) continue;

      if(PositionGetInteger(POSITION_TYPE) != positionType) continue;

      trade.PositionClose(ticket, InpSlippage);
   }
}

//+------------------------------------------------------------------+
//| Shared helper: convert a $ amount into a price distance for a     |
//| given lot size. Used identically for both TP and SL now -- no     |
//| ATR involved anywhere in this calculation.                        |
//+------------------------------------------------------------------+
double DollarToPriceDistance(double dollarAmount, double lots)
{
   double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double tickSize  = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   double point     = SymbolInfoDouble(_Symbol, SYMBOL_POINT);

   if(tickValue <= 0 || tickSize <= 0 || point <= 0 || lots <= 0)
      return 0; // caller must handle this safety case

   double valuePerPoint = tickValue * (point / tickSize) * lots;
   if(valuePerPoint <= 0) return 0;

   double points = dollarAmount / valuePerPoint;
   return points * point;
}

//+------------------------------------------------------------------+
//| Calculate lot size, either fixed or risk-percent based.           |
//| Risk-percent mode sizes against the fixed $ SL amount (no ATR).   |
//+------------------------------------------------------------------+
double CalculateLotSize()
{
   if(!InpUseRiskPercent)
      return InpLots;

   double balance     = AccountInfoDouble(ACCOUNT_BALANCE);
   double riskAmount  = balance * (InpRiskPercent / 100.0);

   // How many lots would make InpFixedSLDollar-per-lot scale up to riskAmount?
   // i.e. lots = riskAmount / InpFixedSLDollar, since SL $ loss scales linearly with lots
   // at a FIXED $ SL per 1 lot reference. We treat InpFixedSLDollar as defined at 0.01 lot
   // (the EA's baseline), so scale accordingly.
   double baselineLots = 0.01;
   double slDollarAtBaseline = InpFixedSLDollar; // $ SL amount is defined at InpLots/baseline scale

   if(slDollarAtBaseline <= 0) return InpLots;

   double lots = (riskAmount / slDollarAtBaseline) * baselineLots;

   double minLot  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxLot  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);

   lots = MathFloor(lots / lotStep) * lotStep;
   lots = MathMax(minLot, MathMin(maxLot, lots));

   return lots;
}

//+------------------------------------------------------------------+
//| Open a buy position with fixed-$ TP/SL (no ATR)                   |
//+------------------------------------------------------------------+
void OpenBuy(string tag)
{
   double point  = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   int    digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   double ask    = SymbolInfoDouble(_Symbol, SYMBOL_ASK);

   double lots = CalculateLotSize();

   double tpDist = DollarToPriceDistance(InpFixedTPDollar, lots);
   double slDist = DollarToPriceDistance(InpFixedSLDollar, lots);

   if(tpDist <= 0 || slDist <= 0)
   {
      Print("Could not compute TP/SL distance (", tag, ") -- check symbol tick value/size. Skipping buy.");
      return;
   }

   double sl = NormalizeDouble(ask - slDist, digits);
   double tp = NormalizeDouble(ask + tpDist, digits);

   if(!trade.Buy(lots, _Symbol, ask, sl, tp, tag + " BUY"))
      Print("Buy order failed (", tag, "). Error: ", GetLastError(), " | ", trade.ResultRetcodeDescription());
   else
      Print(tag, " BUY opened. Lots=", lots, " SL=", sl, " ($", DoubleToString(InpFixedSLDollar,2),
            ") TP=", tp, " ($", DoubleToString(InpFixedTPDollar,2), ")");
}

//+------------------------------------------------------------------+
//| Open a sell position with fixed-$ TP/SL (no ATR)                  |
//+------------------------------------------------------------------+
void OpenSell(string tag)
{
   double point  = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   int    digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   double bid    = SymbolInfoDouble(_Symbol, SYMBOL_BID);

   double lots = CalculateLotSize();

   double tpDist = DollarToPriceDistance(InpFixedTPDollar, lots);
   double slDist = DollarToPriceDistance(InpFixedSLDollar, lots);

   if(tpDist <= 0 || slDist <= 0)
   {
      Print("Could not compute TP/SL distance (", tag, ") -- check symbol tick value/size. Skipping sell.");
      return;
   }

   double sl = NormalizeDouble(bid + slDist, digits);
   double tp = NormalizeDouble(bid - tpDist, digits);

   if(!trade.Sell(lots, _Symbol, bid, sl, tp, tag + " SELL"))
      Print("Sell order failed (", tag, "). Error: ", GetLastError(), " | ", trade.ResultRetcodeDescription());
   else
      Print(tag, " SELL opened. Lots=", lots, " SL=", sl, " ($", DoubleToString(InpFixedSLDollar,2),
            ") TP=", tp, " ($", DoubleToString(InpFixedTPDollar,2), ")");
}

//+------------------------------------------------------------------+
//| Check spread filter                                               |
//+------------------------------------------------------------------+
bool SpreadOK()
{
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);

   double spreadPoints = (ask - bid) / point;
   return (spreadPoints <= InpMaxSpreadPoints);
}

//+------------------------------------------------------------------+
//| MULTI-TIMEFRAME TREND FILTER                                      |
//|                                                                    |
//| Definition (confirmed with user):                                 |
//| - Checked on M15, H1, H4. H4 is informational only (logged, never |
//|   blocks a trade). M15 and H1 must not OPPOSE the trade direction |
//|   -- Neutral on either is fine; only a hard opposite-direction     |
//|   read on M15 or H1 blocks the trade.                              |
//| - Per-timeframe trend = EMA(InpMTF_EMA_Period) direction AND       |
//|   5-candle fractal swing structure must AGREE:                    |
//|     Bullish = price above EMA AND last 2 confirmed fractal swings  |
//|               show higher-high + higher-low                        |
//|     Bearish = price below EMA AND lower-high + lower-low           |
//|     Neutral = anything else (MA/structure disagree, or not enough  |
//|               confirmed swing data yet within InpMTF_FractalLookback|
//|               bars)                                                 |
//| - A "confirmed" fractal swing high/low uses the standard 5-candle  |
//|   definition: the middle candle's high (or low) is the highest     |
//|   (or lowest) of itself and the 2 candles on each side. This       |
//|   requires the 2 candles AFTER it to have already closed, so only  |
//|   bars from index 3 onward (relative to the current forming bar)   |
//|   can ever be confirmed swing points -- this is what makes it a    |
//|   real, non-repainting confirmation rather than a guess.            |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Find the two most recent CONFIRMED fractal swing highs and the    |
//| two most recent CONFIRMED fractal swing lows on the given          |
//| timeframe, searching back up to InpMTF_FractalLookback bars.       |
//| Returns true if both pairs were found (enough data + enough       |
//| swings exist); fills swingHigh1/2 and swingLow1/2 with the values, |
//| where index 1 is the MOST RECENT confirmed swing, index 2 is the   |
//| one before that (so a higher-high check is swingHigh1 > swingHigh2)|
//+------------------------------------------------------------------+
bool GetLastTwoFractalSwings(ENUM_TIMEFRAMES tf, double &swingHigh1, double &swingHigh2,
                              double &swingLow1, double &swingLow2)
{
   int barsNeeded = InpMTF_FractalLookback + 4; // +4 buffer for the 5-candle fractal window
   double highs[], lows[];
   ArraySetAsSeries(highs, true);
   ArraySetAsSeries(lows, true);

   if(CopyHigh(_Symbol, tf, 0, barsNeeded, highs) <= 0) return false;
   if(CopyLow(_Symbol, tf, 0, barsNeeded, lows)   <= 0) return false;

   int foundHighs = 0, foundLows = 0;
   swingHigh1 = 0; swingHigh2 = 0;
   swingLow1  = 0; swingLow2  = 0;

   // Start at index 3: a confirmed fractal at index i needs i-2 and i+2 to exist,
   // and i-1, i-2 must already be CLOSED bars (i.e. i >= 3, since index 0-2 are
   // still forming / too recent to confirm the 2 bars "after" the fractal).
   int maxIndex = ArraySize(highs) - 3;
   for(int i = 3; i <= maxIndex && (foundHighs < 2 || foundLows < 2); i++)
   {
      if(foundHighs < 2)
      {
         bool isFractalHigh = (highs[i] >= highs[i-1] && highs[i] >= highs[i-2] &&
                                highs[i] >= highs[i+1] && highs[i] >= highs[i+2]);
         if(isFractalHigh)
         {
            if(foundHighs == 0) swingHigh1 = highs[i];
            else                 swingHigh2 = highs[i];
            foundHighs++;
         }
      }
      if(foundLows < 2)
      {
         bool isFractalLow = (lows[i] <= lows[i-1] && lows[i] <= lows[i-2] &&
                               lows[i] <= lows[i+1] && lows[i] <= lows[i+2]);
         if(isFractalLow)
         {
            if(foundLows == 0) swingLow1 = lows[i];
            else                 swingLow2 = lows[i];
            foundLows++;
         }
      }
   }

   return (foundHighs == 2 && foundLows == 2);
}

//+------------------------------------------------------------------+
//| Evaluate trend state (Bullish/Bearish/Neutral) on a given          |
//| timeframe using its EMA handle + fractal structure agreement.     |
//+------------------------------------------------------------------+
TrendState GetTrendState(ENUM_TIMEFRAMES tf, int emaHandle)
{
   double emaBuf[];
   ArraySetAsSeries(emaBuf, true);
   if(CopyBuffer(emaHandle, 0, 0, 1, emaBuf) <= 0) return TREND_NEUTRAL;

   double ema = emaBuf[0];
   double price = SymbolInfoDouble(_Symbol, SYMBOL_BID);

   double sh1, sh2, sl1, sl2;
   if(!GetLastTwoFractalSwings(tf, sh1, sh2, sl1, sl2))
      return TREND_NEUTRAL; // not enough confirmed swing data yet

   bool maAboveEMA = (price > ema);
   bool maBelowEMA = (price < ema);

   bool structureBullish = (sh1 > sh2) && (sl1 > sl2); // higher high + higher low
   bool structureBearish = (sh1 < sh2) && (sl1 < sl2); // lower high + lower low

   if(maAboveEMA && structureBullish) return TREND_BULLISH;
   if(maBelowEMA && structureBearish) return TREND_BEARISH;

   return TREND_NEUTRAL; // MA and structure disagree, or structure is choppy/sideways
}

//+------------------------------------------------------------------+
//| Master MTF gate: does the proposed trade direction (1=buy,        |
//| -1=sell) get blocked by M15 or H1? H4 is computed for logging      |
//| only and never blocks. Returns true if the trade is ALLOWED.       |
//+------------------------------------------------------------------+
bool MTFAllowsTrade(int direction)
{
   if(!InpEnableMTFFilter) return true;

   TrendState m15 = GetTrendState(PERIOD_M15, emaHandleM15);
   TrendState h1  = GetTrendState(PERIOD_H1,  emaHandleH1);
   TrendState h4  = GetTrendState(PERIOD_H4,  emaHandleH4); // informational only

   bool blocked = false;
   if(direction == 1) // proposed BUY: blocked only if M15 or H1 is hard Bearish
      blocked = (m15 == TREND_BEARISH || h1 == TREND_BEARISH);
   else if(direction == -1) // proposed SELL: blocked only if M15 or H1 is hard Bullish
      blocked = (m15 == TREND_BULLISH || h1 == TREND_BULLISH);

   if(blocked)
      Print("MTF filter BLOCKED ", (direction==1?"BUY":"SELL"),
            " | M15=", EnumToString(m15), " H1=", EnumToString(h1), " H4(info)=", EnumToString(h4));

   return !blocked;
}

//+------------------------------------------------------------------+
//| DAILY PROFIT TARGET / CIRCUIT BREAKER                             |
//|                                                                    |
//| - Tracks cumulative CLOSED (realized) profit for THIS EA's trades  |
//|   (filtered by magic number) since the last broker-time midnight.  |
//| - Resets automatically when the broker-time date changes.          |
//| - Once dailyClosedPL >= InpDailyTargetDollar, dailyTargetHit=true, |
//|   which blocks new entries (checked in OnTick/CheckSweepSignal)    |
//|   but does NOT touch already-open positions.                       |
//| - Fires an on-chart Alert + optional push notification exactly      |
//|   once per day, the moment the target is crossed.                  |
//+------------------------------------------------------------------+
void RefreshDailyPLIfNeeded(bool forceFullScan = false)
{
   if(!InpEnableDailyTarget && !forceFullScan) return;

   // --- Determine "today" in broker/server time, truncated to the date ---
   datetime serverNow = TimeCurrent();
   MqlDateTime dt;
   TimeToStruct(serverNow, dt);
   dt.hour = 0; dt.min = 0; dt.sec = 0;
   datetime todayStart = StructToTime(dt);

   if(todayStart != dailyResetDay)
   {
      // New day (or first run): reset counters and rescan from today's start only.
      dailyResetDay  = todayStart;
      dailyClosedPL  = 0;
      dailyTargetHit = false;
      lastDealTicketSeen = 0;
      Print("Daily profit counter reset for new day: ", TimeToString(todayStart, TIME_DATE));
   }

   // --- Scan closed deals (history) since todayStart for this EA's magic number ---
   if(!HistorySelect(dailyResetDay, serverNow + 60)) return; // +60s buffer for clock skew

   int totalDeals = HistoryDealsTotal();
   double newlyFoundPL = 0;

   for(int i = 0; i < totalDeals; i++)
   {
      ulong dealTicket = HistoryDealGetTicket(i);
      if(dealTicket == 0) continue;
      if(dealTicket <= lastDealTicketSeen) continue; // already counted

      if(HistoryDealGetString(dealTicket, DEAL_SYMBOL) != _Symbol) continue;
      if(HistoryDealGetInteger(dealTicket, DEAL_MAGIC) != InpMagicNumber) continue;

      long dealEntry = HistoryDealGetInteger(dealTicket, DEAL_ENTRY);
      if(dealEntry != DEAL_ENTRY_OUT && dealEntry != DEAL_ENTRY_OUT_BY) continue; // only count closing deals

      double profit = HistoryDealGetDouble(dealTicket, DEAL_PROFIT)
                     + HistoryDealGetDouble(dealTicket, DEAL_SWAP)
                     + HistoryDealGetDouble(dealTicket, DEAL_COMMISSION);
      newlyFoundPL += profit;

      if(dealTicket > lastDealTicketSeen) lastDealTicketSeen = dealTicket;
   }

   if(newlyFoundPL != 0)
   {
      dailyClosedPL += newlyFoundPL;
      Print("Daily closed P/L updated: +", DoubleToString(newlyFoundPL,2),
            " -> running total today: $", DoubleToString(dailyClosedPL,2));
   }

   // --- Check target crossing (fires the alert exactly once per day) ---
   if(InpEnableDailyTarget && !dailyTargetHit && dailyClosedPL >= InpDailyTargetDollar)
   {
      dailyTargetHit = true;

      string msg = StringFormat("Daily TP hit! Trading stopped. Banked: $%.2f (target $%.2f)",
                                 dailyClosedPL, InpDailyTargetDollar);
      Alert(msg);
      Comment(msg); // also leave it visible on-chart persistently

      if(InpSendPushNotification)
         SendNotification(msg); // requires MetaQuotes ID set in Tools->Options->Notifications; fails silently if not configured

      Print(msg);
   }
}

//+------------------------------------------------------------------+
//| QUICK-SCALP CLOSE (EA-managed, runs every tick)                   |
//|                                                                    |
//| - Scans ALL open positions for this EA (both TAG_INTRABAR and      |
//|   TAG_SWEEP) and closes any whose floating profit has reached      |
//|   InpScalpProfitDollar, regardless of the broker-side TP/SL still  |
//|   attached (which remains as a backstop and is simply never        |
//|   reached in the normal case, since this closes first).            |
//| - After closing, if InpReopenAfterScalp=true, re-checks whether    |
//|   the ORIGINAL entry condition for that tag/direction still holds  |
//|   right now, and if so immediately opens a new position in the     |
//|   same direction. If the condition no longer holds, does nothing   |
//|   -- the normal signal logic (intra-bar bias flip / sweep) will    |
//|   pick it up naturally on a future tick if/when it re-confirms.    |
//| - Respects the daily target circuit breaker: will NOT reopen a     |
//|   new trade if dailyTargetHit is true (closing for profit is       |
//|   still allowed/expected either way, only new entries are gated).  |
//+------------------------------------------------------------------+
void CheckQuickScalpCloses()
{
   if(!InpEnableQuickScalp) return;

   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      if(!PositionSelectByTicket(ticket)) continue;

      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if(PositionGetInteger(POSITION_MAGIC) != InpMagicNumber) continue;

      double profit = PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);
      if(profit < InpScalpProfitDollar) continue; // not there yet

      string posComment = PositionGetString(POSITION_COMMENT);
      long   posType     = PositionGetInteger(POSITION_TYPE);
      string tag         = (StringFind(posComment, TAG_SWEEP) >= 0) ? TAG_SWEEP : TAG_INTRABAR;
      int    direction   = (posType == POSITION_TYPE_BUY) ? 1 : -1;

      if(!trade.PositionClose(ticket, InpSlippage))
      {
         Print("Quick-scalp close FAILED for ticket ", ticket, ". Error: ", GetLastError());
         continue;
      }

      Print("Quick-scalp closed ", tag, " ", (direction==1?"BUY":"SELL"),
            " ticket ", ticket, " at +$", DoubleToString(profit,2));

      // Refresh daily P/L immediately so the target check is current before any reopen.
      RefreshDailyPLIfNeeded();

      if(!InpReopenAfterScalp) continue;
      if(InpEnableDailyTarget && dailyTargetHit) continue; // circuit breaker: no new entries today

      // --- Re-check whether the ORIGINAL entry condition still holds right now ---
      bool conditionStillValid = false;

      if(tag == TAG_INTRABAR)
      {
         double currentOpen = iOpen(_Symbol, InpTimeframe, 0);
         double curPrice    = SymbolInfoDouble(_Symbol, SYMBOL_BID);
         if(currentOpen > 0)
         {
            if(direction == 1 && curPrice > currentOpen) conditionStillValid = true;
            if(direction == -1 && curPrice < currentOpen) conditionStillValid = true;
         }
      }
      else // TAG_SWEEP
      {
         // Sweep condition still valid = the level is still taken AND price still back inside,
         // i.e. lastSweepSignal still matches this direction (re-evaluated live each tick by
         // CheckSweepSignal, so we just check its current state here).
         if(direction == 1  && sweepLowTaken  && SymbolInfoDouble(_Symbol, SYMBOL_BID) > sweepLevelLow)  conditionStillValid = true;
         if(direction == -1 && sweepHighTaken && SymbolInfoDouble(_Symbol, SYMBOL_BID) < sweepLevelHigh) conditionStillValid = true;
      }

      if(!conditionStillValid)
      {
         Print(tag, " ", (direction==1?"BUY":"SELL"), " condition no longer valid after scalp-close, not reopening.");
         continue;
      }

      if(!SpreadOK())
      {
         Print("Spread too wide, skipping scalp reopen.");
         continue;
      }

      if(!MTFAllowsTrade(direction))
         continue; // MTFAllowsTrade already logs its own block reason

      // Re-check this tag's own one-buy/one-sell cap (should be free since we just closed it,
      // but re-verify in case of any race with the natural signal logic on the same tick).
      bool hasBuy, hasSell;
      CountPositions(tag, hasBuy, hasSell);
      if(direction == 1 && !hasBuy)
         OpenBuy(tag);
      else if(direction == -1 && !hasSell)
         OpenSell(tag);
   }
}

//+------------------------------------------------------------------+
//| Liquidity sweep detection (independent signal system).            |
//|                                                                    |
//| Definition (confirmed with user):                                 |
//| - Liquidity level = highest high / lowest low of the last         |
//|   InpSweepLookback FULLY CLOSED candles (bars 1..N, excludes the  |
//|   currently forming bar itself).                                  |
//| - A sweep is "taken" when, at ANY point during the current         |
//|   forming candle, price has wicked beyond that level (high above  |
//|   the N-bar high, or low below the N-bar low).                    |
//| - A sweep is "confirmed" (the reversal trigger) when price has    |
//|   come back inside the range after having been taken -- checked   |
//|   live every tick using current price as the provisional "close". |
//| - This is fully provisional/live: if price wicks back outside the  |
//|   level again, confirmation reverts to false until it comes back  |
//|   inside again. It only becomes permanent once the bar actually   |
//|   closes (handled naturally since a new bar resets the tracking). |
//| - Runs entirely independently of the intra-bar bias signal; both  |
//|   can fire and hold positions at the same time.                   |
//+------------------------------------------------------------------+
void CheckSweepSignal()
{
   if(!InpEnableSweepSignal) return;

   datetime currentBarTime = iTime(_Symbol, InpTimeframe, 0);
   if(currentBarTime == 0) return;

   // --- New candle started: recompute the N-bar liquidity level, reset tracking ---
   if(currentBarTime != sweepBarTime)
   {
      sweepBarTime = currentBarTime;

      double highs[], lows[];
      ArraySetAsSeries(highs, true);
      ArraySetAsSeries(lows, true);

      // bars 1..N = last N CLOSED candles, excluding the forming bar at index 0
      if(CopyHigh(_Symbol, InpTimeframe, 1, InpSweepLookback, highs) <= 0 ||
         CopyLow(_Symbol, InpTimeframe, 1, InpSweepLookback, lows)  <= 0)
      {
         sweepLevelHigh = 0;
         sweepLevelLow  = 0;
         return;
      }

      sweepLevelHigh = highs[ArrayMaximum(highs)];
      sweepLevelLow  = lows[ArrayMinimum(lows)];

      sweepHighTaken  = false;
      sweepLowTaken   = false;
      lastSweepSignal = 0;
   }

   if(sweepLevelHigh <= 0 || sweepLevelLow <= 0) return; // level not ready

   double curHigh = iHigh(_Symbol, InpTimeframe, 0);
   double curLow  = iLow(_Symbol, InpTimeframe, 0);
   double price   = SymbolInfoDouble(_Symbol, SYMBOL_BID); // provisional "close so far"

   // --- Track whether the level has been wicked through at any point this bar ---
   if(curHigh > sweepLevelHigh) sweepHighTaken = true;
   if(curLow  < sweepLevelLow)  sweepLowTaken  = true;

   // --- Confirm reversal: level was taken, AND price is now back inside ---
   bool bearishSweepConfirmed = sweepHighTaken && (price < sweepLevelHigh); // swept highs, now back below -> sell
   bool bullishSweepConfirmed = sweepLowTaken  && (price > sweepLevelLow);  // swept lows, now back above -> buy

   int newSweepSignal = 0;
   if(bullishSweepConfirmed && !bearishSweepConfirmed) newSweepSignal = 1;
   else if(bearishSweepConfirmed && !bullishSweepConfirmed) newSweepSignal = -1;
   // if both somehow true (level taken on both sides this bar), skip -- ambiguous, wait for next tick

   if(newSweepSignal == 0 || newSweepSignal == lastSweepSignal)
      return; // no new confirmed signal, or same as already acted on

   lastSweepSignal = newSweepSignal;

   if(!SpreadOK())
   {
      Print("Spread too wide, skipping sweep signal.");
      return;
   }

   bool hasBuy, hasSell;
   CountPositions(TAG_SWEEP, hasBuy, hasSell);

   bool dailyBlocked = (InpEnableDailyTarget && dailyTargetHit);

   if(newSweepSignal == 1 && !hasBuy && !dailyBlocked)
   {
      if(MTFAllowsTrade(1))
      {
         Print("Bullish liquidity sweep confirmed: low ", sweepLevelLow, " swept and reclaimed.");
         OpenBuy(TAG_SWEEP);
      }
   }
   else if(newSweepSignal == -1 && !hasSell && !dailyBlocked)
   {
      if(MTFAllowsTrade(-1))
      {
         Print("Bearish liquidity sweep confirmed: high ", sweepLevelHigh, " swept and reclaimed.");
         OpenSell(TAG_SWEEP);
      }
   }
}

//+------------------------------------------------------------------+
//| Expert tick function                                              |
//+------------------------------------------------------------------+
void OnTick()
{
   // === Daily profit target: refresh tracker every tick (cheap; only scans new deals) ===
   RefreshDailyPLIfNeeded();

   // === Quick-scalp close: check open positions for the $ profit target FIRST,
   //     before evaluating new signals, so a position that just hit +$1 gets
   //     closed (and possibly reopened) before anything else happens this tick ===
   CheckQuickScalpCloses();

   bool dailyBlocked = (InpEnableDailyTarget && dailyTargetHit);

   // === SIGNAL 1: Intra-bar candle-color bias (existing system) ===

   // --- Identify the candle currently forming on InpTimeframe ---
   datetime currentBarTime = iTime(_Symbol, InpTimeframe, 0);
   if(currentBarTime == 0) return; // data not ready yet

   double currentOpen = iOpen(_Symbol, InpTimeframe, 0);
   if(currentOpen <= 0) return;

   double price = SymbolInfoDouble(_Symbol, SYMBOL_BID); // reference price for bias check

   // --- Reset bias tracking when a brand-new candle starts ---
   if(currentBarTime != lastBarTime)
   {
      lastBarTime = currentBarTime;
      lastBias    = 0; // fresh candle, no bias decided yet
   }

   // --- Determine live bias: compare current price to THIS candle's open ---
   int newBias = 0;
   if(price > currentOpen)      newBias = 1;   // trading above own open -> "green" -> buy bias
   else if(price < currentOpen) newBias = -1;  // trading below own open -> "red"   -> sell bias

   // --- Only act when the bias actually changes (avoids re-firing every tick) ---
   if(newBias != 0 && newBias != lastBias)
   {
      lastBias = newBias;

      if(SpreadOK())
      {
         bool hasBuy, hasSell;
         CountPositions(TAG_INTRABAR, hasBuy, hasSell);

         if(newBias == 1) // bias flipped to BUY
         {
            if(InpCloseOppositeOnFlip && hasSell)
               CloseDirection(TAG_INTRABAR, POSITION_TYPE_SELL);

            CountPositions(TAG_INTRABAR, hasBuy, hasSell); // refresh after potential close
            if(!hasBuy && !dailyBlocked && MTFAllowsTrade(1))
               OpenBuy(TAG_INTRABAR);
         }
         else if(newBias == -1) // bias flipped to SELL
         {
            if(InpCloseOppositeOnFlip && hasBuy)
               CloseDirection(TAG_INTRABAR, POSITION_TYPE_BUY);

            CountPositions(TAG_INTRABAR, hasBuy, hasSell); // refresh after potential close
            if(!hasSell && !dailyBlocked && MTFAllowsTrade(-1))
               OpenSell(TAG_INTRABAR);
         }
      }
      else
      {
         Print("Spread too wide, skipping intra-bar signal.");
      }
   }

   // === SIGNAL 2: Liquidity sweep reversal (independent system) ===
   CheckSweepSignal();
}
//+------------------------------------------------------------------+
