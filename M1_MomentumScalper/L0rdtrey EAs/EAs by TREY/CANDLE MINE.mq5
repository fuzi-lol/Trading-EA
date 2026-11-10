//+--------------------------------------------------------------------+
//|                                              CANDLE MINE.mq5       |
//|   Intra-bar candle color EA with FIXED-DOLLAR TP/SL                |
//|                                                                    |                 
//|   LOGIC :                                                          |
//|   - Watches the M5 candle that is CURRENTLY FORMING (live, tick    |
//|     by tick), not the last closed candle.                          |
//|   - If current price > current candle's open  -> bias = BUY        |
//|   - If current price < current candle's open  -> bias = SELL       |
//|   - This is intentional: the user explicitly rejected reacting     |
//|     to the previous CLOSED candle's color, because that is a       |
//|     lagging signal (e.g. it can buy into the 3rd green candle of   |
//|     a liquidity sweep right before it reverses). Reacting to the   |
//|     live, currently-forming candle is the closest thing to a       |
//|     true "candle color" reaction possible in MT5.                  |
//|   - When the bias flips, a new position is opened in the new       |
//|     bias direction (if one isn't already open that way). By        |
//|     DEFAULT, the opposite-direction position is left alone to      |
//|     run to its own SL/TP rather than being force-closed on the     |
//|     flip. Set InpCloseOppositeOnFlip=true to restore flip-close    |
//|     behavior. Note: this means BUY and SELL can be open on the     |
//|     same symbol simultaneously (requires a hedging-enabled         |
//|     account, e.g. FBS Markets demo/live).                          |
//|   - Only one position per direction at a time (no stacking).       |
//|                                                                    |
//|   RISK MODEL -- FIXED DOLLAR TP/SL, NO ATR (changed per user       |
//|   request after live testing showed the problem with ATR-based     |
//|   sizing: on a 0.01 lot, ATR-derived TP distances were often too   |
//|   far away to realistically be hit before price reversed and hit   |
//|   the SL instead -- trades floated near +$4 profit, the EA had no  |
//|   mechanism to bank that, and they later closed at SL for a loss.  |
//|   Fixed, reachable dollar targets solve this directly):            |
//|   - TP = InpFixedTPDollar (default $4.00) on every trade.          |
//|   - SL = InpFixedSLDollar (default $4.00) on every trade --        |
//|     same $ amount as TP, i.e. a clean 1:1 risk:reward, confirmed   |
//|     with user as the intended ratio.                               |
//|   - Both $ targets are converted into an actual price distance     |
//|     using the trade's real lot size (so the $ amount is exact,     |
//|     not approximate), via the same tick-value math for both.       |
//|   - ATR is NOT used anywhere in this calculation. No ATR handle    |
//|     is created at all -- this EA no longer depends on ATR.         |
//|   - InpLots defaults to 0.01 as requested; if InpUseRiskPercent    |
//|     is enabled instead, lot size is derived from InpRiskPercent    |
//|     of balance against the $ SL amount (so larger accounts risk    |
//|     more $ per trade automatically, while small accounts stay at   |
//|     minimum lot). Leave it OFF (default) to keep lot size fixed    |
//|     at exactly InpLots regardless of balance.                      |
//|                                                                    |
//|   SECOND, FULLY INDEPENDENT SIGNAL -- LIQUIDITY SWEEP REVERSAL:    |
//|   - Liquidity level = highest high / lowest low of the last        |
//|     InpSweepLookback (default 10) FULLY CLOSED candles.            |
//|   - Sweep "taken": at any point during the currently forming       |
//|     candle, its high goes above that level (upside sweep) or its   |
//|     low goes below it (downside sweep).                            |
//|   - Sweep "confirmed" (the actual entry trigger): after being      |
//|     taken, price comes back inside the range -- checked LIVE,      |
//|     tick by tick, using current price as a provisional "close".    |
//|     This is provisional: if price wicks back outside again before  |
//|     the bar closes, confirmation reverts to false until price      |
//|     comes back inside again.                                       |
//|   - Bullish sweep confirmed (low swept + reclaimed) -> BUY.        |
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
//+--------------------------------------------------------------------+
#property copyright "Karisa"
#property version   "2.00"
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
input double          InpFixedSLDollar    = 4.0;          // Fixed SL loss amount in account currency (e.g. $4 = same as TP, 1:1 R:R)

input group "=== Trade Management ==="
input bool            InpCloseOppositeOnFlip = false;      // Close opposite-direction position when bias flips (false = SL/TP manage all exits)
input int             InpMaxSpreadPoints  = 50;             // Skip new entries if spread exceeds this (points)
input int             InpSlippage         = 10;             // Allowed slippage in points

input group "=== Liquidity Sweep Settings ==="
input bool            InpEnableSweepSignal = true;          // Enable the independent liquidity sweep reversal signal
input int             InpSweepLookback     = 10;             // N closed candles used to define the swept high/low

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

   Print("CandleColor_ATR_EA initialized (v2.00, fixed-$ TP/SL, no ATR). Watching ", EnumToString(InpTimeframe),
         " live candle color. TP=$", DoubleToString(InpFixedTPDollar,2),
         " SL=$", DoubleToString(InpFixedSLDollar,2),
         ". Liquidity sweep signal: ", InpEnableSweepSignal ? "ENABLED" : "disabled",
         " (lookback=", InpSweepLookback, ")");

   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   // No ATR handle to release anymore.
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

   if(newSweepSignal == 1 && !hasBuy)
   {
      Print("Bullish liquidity sweep confirmed: low ", sweepLevelLow, " swept and reclaimed.");
      OpenBuy(TAG_SWEEP);
   }
   else if(newSweepSignal == -1 && !hasSell)
   {
      Print("Bearish liquidity sweep confirmed: high ", sweepLevelHigh, " swept and reclaimed.");
      OpenSell(TAG_SWEEP);
   }
}

//+------------------------------------------------------------------+
//| Expert tick function                                              |
//+------------------------------------------------------------------+
void OnTick()
{
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
            if(!hasBuy)
               OpenBuy(TAG_INTRABAR);
         }
         else if(newBias == -1) // bias flipped to SELL
         {
            if(InpCloseOppositeOnFlip && hasBuy)
               CloseDirection(TAG_INTRABAR, POSITION_TYPE_BUY);

            CountPositions(TAG_INTRABAR, hasBuy, hasSell); // refresh after potential close
            if(!hasSell)
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