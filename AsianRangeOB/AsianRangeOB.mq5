//+------------------------------------------------------------------+
//|                                          AsianRangeOB.mq5        |
//|   Asian Range Breakout + Order Block Retest Strategy              |
//|   Mark 4:30-5:30 IST range, breakout, OB retest entry            |
//|   1:2 RR initial, trail to BE at 1:1, extend to 1:4              |
//+------------------------------------------------------------------+

#property version   "1.00"
#property strict

#include <Trade\Trade.mqh>

//=== INPUTS =========================================================
//--- Range Window (Server Time)
//--- IST = Server Time + offset. Adjust these to match your broker.
//--- Default: 4:30-5:30 IST on a UTC+3 broker = 02:00-03:00 server
input int      RangeStartHour   = 2;        // Range start hour (server time)
input int      RangeStartMin    = 0;        // Range start minute
input int      RangeEndHour     = 3;        // Range end hour (server time)
input int      RangeEndMin      = 0;        // Range end minute

//--- Trading Window
input int      TradeStartHour   = 4;        // Start looking for breakouts (skip fakeouts at hr 3)
input int      TradeEndHour     = 12;       // Stop trading after this hour
input int      MaxTradesPerDay  = 1;        // Max trades per day (1 breakout)
input bool     SkipThursday     = true;     // Skip Thursdays (historically bad)
input bool     SkipFriday       = true;     // Skip Fridays (historically bad)

//--- Risk Management
input double   RR_Initial       = 2.0;      // Initial Risk:Reward for TP
input double   BE_Trigger_RR    = 1.0;      // Move SL to BE at this R multiple
input double   BE_Lock_Points   = 10;       // Points of profit to lock at BE
input double   RR_Extended      = 4.0;      // Extended TP target after BE hit
input double   Trail_Step_Pts   = 80;       // Trailing step after BE (points)

//--- Order Block
input int      OB_Lookback      = 10;       // Bars before breakout to scan for OB
input double   SL_Buffer_Pts    = 30;       // Extra SL buffer beyond OB (points)
input double   MinBreakPts      = 30;       // Min breakout beyond range (points)

//--- Trade Settings
input double   LotSize          = 0.10;     // Lot size
input int      MagicNumber      = 889001;   // Magic number
input int      MaxSpreadPts     = 50;       // Max spread in points
input double   MinRangePts      = 200;      // Min range size in points (filter tiny ranges)
input double   MaxRangePts      = 2000;     // Max range size in points (filter huge ranges)

//=== ENUMS ==========================================================
enum EState
{
   ST_MARKING_RANGE,     // Building the range (during range window)
   ST_WAITING_BREAKOUT,  // Range set, waiting for breakout
   ST_WAITING_RETEST,    // Breakout happened, waiting for OB retest
   ST_IN_TRADE,          // Position open
   ST_DONE_TODAY         // Done for the day
};

//=== GLOBALS ========================================================
CTrade   trade;
EState   gState;
datetime gDay;
int      gTradesToday;

// Range
double   gRangeHigh;
double   gRangeLow;
bool     gRangeSet;

// Breakout
int      gBreakDir;          // +1 = bullish breakout, -1 = bearish
datetime gBreakTime;

// Order Block
double   gOB_High;
double   gOB_Low;
bool     gOB_Found;

// Trade management
double   gEntrySLDist;       // SL distance for RR calculations
bool     gBE_Hit;            // Whether breakeven was triggered

//+------------------------------------------------------------------+
int OnInit()
{
   trade.SetExpertMagicNumber(MagicNumber);
   trade.SetDeviationInPoints(30);

   gState = ST_MARKING_RANGE;
   gDay = 0;
   gTradesToday = 0;
   ResetDaily();

   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
void OnDeinit(const int reason) {}

//+------------------------------------------------------------------+
void OnTick()
{
   //--- New day reset
   datetime today = iTime(_Symbol, PERIOD_D1, 0);
   if(today != gDay)
   {
      gDay = today;
      gTradesToday = 0;
      gState = ST_MARKING_RANGE;
      ResetDaily();
   }

   MqlDateTime dt;
   TimeCurrent(dt);
   int curMin = dt.hour * 60 + dt.min;
   int rangeStartMin = RangeStartHour * 60 + RangeStartMin;
   int rangeEndMin   = RangeEndHour * 60 + RangeEndMin;
   int tradeEndMin   = TradeEndHour * 60;

   //--- State machine
   switch(gState)
   {
      case ST_MARKING_RANGE:
         HandleRangeMarking(curMin, rangeStartMin, rangeEndMin);
         break;

      case ST_WAITING_BREAKOUT:
         if(curMin >= tradeEndMin) { gState = ST_DONE_TODAY; break; }
         if(curMin < TradeStartHour * 60) break;  // Wait for trade start hour
         if(SkipThursday && dt.day_of_week == 4) { gState = ST_DONE_TODAY; break; }
         if(SkipFriday && dt.day_of_week == 5) { gState = ST_DONE_TODAY; break; }
         HandleBreakoutDetection();
         break;

      case ST_WAITING_RETEST:
         if(curMin >= tradeEndMin) { gState = ST_DONE_TODAY; break; }
         HandleRetestEntry();
         break;

      case ST_IN_TRADE:
         ManagePosition();
         break;

      case ST_DONE_TODAY:
         break;
   }
}

//+------------------------------------------------------------------+
void ResetDaily()
{
   gRangeHigh = 0;
   gRangeLow  = DBL_MAX;
   gRangeSet  = false;
   gBreakDir  = 0;
   gBreakTime = 0;
   gOB_High   = 0;
   gOB_Low    = 0;
   gOB_Found  = false;
   gEntrySLDist = 0;
   gBE_Hit    = false;
}

//+------------------------------------------------------------------+
//| PHASE 1: Mark the range high/low during the window               |
//+------------------------------------------------------------------+
void HandleRangeMarking(int curMin, int rangeStartMin, int rangeEndMin)
{
   // Before range window - wait
   if(curMin < rangeStartMin)
      return;

   // During range window - update high/low on each tick
   if(curMin < rangeEndMin)
   {
      double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      if(bid > gRangeHigh) gRangeHigh = bid;
      if(bid < gRangeLow)  gRangeLow  = bid;
      return;
   }

   // Range window ended - finalize
   if(curMin >= rangeEndMin)
   {
      double rangeSize = (gRangeHigh - gRangeLow) / _Point;

      if(gRangeHigh <= gRangeLow || rangeSize < MinRangePts || rangeSize > MaxRangePts)
      {
         Print("Range invalid or filtered: High=", gRangeHigh, " Low=", gRangeLow,
               " Size=", DoubleToString(rangeSize, 0), " pts");
         gState = ST_DONE_TODAY;
         return;
      }

      gRangeSet = true;
      gState = ST_WAITING_BREAKOUT;

      Print("Range Set: High=", gRangeHigh, " Low=", gRangeLow,
            " Size=", DoubleToString(rangeSize, 0), " pts");

      // Draw range lines for visual reference
      DrawRange();
   }
}

//+------------------------------------------------------------------+
//| PHASE 2: Wait for candle close breakout of range                  |
//+------------------------------------------------------------------+
void HandleBreakoutDetection()
{
   if(!IsNewBar()) return;

   // Check last closed bar (bar 1)
   MqlRates rates[];
   int copied = CopyRates(_Symbol, PERIOD_CURRENT, 1, 1, rates);
   if(copied < 1) return;

   // Bullish breakout: candle CLOSES above range high with minimum strength
   double breakAbove = (rates[0].close - gRangeHigh) / _Point;
   double breakBelow = (gRangeLow - rates[0].close) / _Point;

   if(rates[0].close > gRangeHigh && rates[0].open < gRangeHigh && breakAbove >= MinBreakPts)
   {
      gBreakDir = 1;
      gBreakTime = rates[0].time;
      Print("BULLISH Breakout at ", rates[0].close, " above range high ", gRangeHigh);

      // Find the order block (last bearish candle before the breakout move)
      if(FindOrderBlock(true))
      {
         gState = ST_WAITING_RETEST;
         Print("OB Found: High=", gOB_High, " Low=", gOB_Low);
         DrawOB();
      }
      else
      {
         Print("No valid OB found after bullish breakout");
         gState = ST_DONE_TODAY;
      }
      return;
   }

   // Bearish breakout: candle CLOSES below range low with minimum strength
   if(rates[0].close < gRangeLow && rates[0].open > gRangeLow && breakBelow >= MinBreakPts)
   {
      gBreakDir = -1;
      gBreakTime = rates[0].time;
      Print("BEARISH Breakout at ", rates[0].close, " below range low ", gRangeLow);

      if(FindOrderBlock(false))
      {
         gState = ST_WAITING_RETEST;
         Print("OB Found: High=", gOB_High, " Low=", gOB_Low);
         DrawOB();
      }
      else
      {
         Print("No valid OB found after bearish breakout");
         gState = ST_DONE_TODAY;
      }
      return;
   }
}

//+------------------------------------------------------------------+
//| Find Order Block: the candle where the big move started           |
//| Bullish: last bearish candle before strong bullish displacement   |
//| Bearish: last bullish candle before strong bearish displacement   |
//+------------------------------------------------------------------+
bool FindOrderBlock(bool bullish)
{
   MqlRates rates[];
   int copied = CopyRates(_Symbol, PERIOD_CURRENT, 1, OB_Lookback + 2, rates);
   if(copied < 3) return false;
   // rates[0] = oldest, rates[copied-1] = most recent (breakout bar)

   if(bullish)
   {
      // Scan backward from breakout bar to find the last bearish candle
      // before the bullish expansion began
      for(int i = copied - 2; i >= 0; i--)
      {
         bool isBearish = rates[i].close < rates[i].open;
         if(isBearish)
         {
            // Verify the next candle(s) moved up strongly (displacement)
            if(i + 1 < copied)
            {
               bool nextBullish = rates[i+1].close > rates[i+1].open;
               if(nextBullish)
               {
                  // This bearish candle is our OB (demand zone)
                  gOB_High  = rates[i].open;    // Body high of bearish candle
                  gOB_Low   = rates[i].close;   // Body low of bearish candle
                  gOB_Found = true;
                  return true;
               }
            }
         }
      }
   }
   else // bearish breakout
   {
      for(int i = copied - 2; i >= 0; i--)
      {
         bool isBullish = rates[i].close > rates[i].open;
         if(isBullish)
         {
            if(i + 1 < copied)
            {
               bool nextBearish = rates[i+1].close < rates[i+1].open;
               if(nextBearish)
               {
                  // This bullish candle is our OB (supply zone)
                  gOB_High  = rates[i].close;   // Body high of bullish candle
                  gOB_Low   = rates[i].open;    // Body low of bullish candle
                  gOB_Found = true;
                  return true;
               }
            }
         }
      }
   }

   return false;
}

//+------------------------------------------------------------------+
//| PHASE 3: Wait for price to retest the Order Block, then enter     |
//+------------------------------------------------------------------+
void HandleRetestEntry()
{
   if(!IsNewBar()) return;
   if(!gOB_Found) { gState = ST_DONE_TODAY; return; }
   if(gTradesToday >= MaxTradesPerDay) { gState = ST_DONE_TODAY; return; }
   if((int)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD) > MaxSpreadPts) return;
   if(HasOpenPosition()) return;

   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);

   // Check last closed bar for retest
   MqlRates rates[];
   int copied = CopyRates(_Symbol, PERIOD_CURRENT, 1, 2, rates);
   if(copied < 2) return;

   if(gBreakDir == 1)  // Bullish breakout - wait for pullback into OB
   {
      // Price pulled back and touched the OB zone, then bounced
      // Bar touched OB zone (low went into OB) and closed above OB
      bool touchedOB = rates[0].low <= gOB_High && rates[0].low >= gOB_Low - SL_Buffer_Pts * _Point;
      bool closedAbove = rates[0].close > gOB_High;

      // Also accept: price is currently in the OB zone
      bool priceInOB = ask >= gOB_Low && ask <= gOB_High;

      if((touchedOB && closedAbove) || priceInOB)
      {
         double entry = ask;
         double sl = NormalizeDouble(gOB_Low - SL_Buffer_Pts * _Point, _Digits);
         double slDist = entry - sl;

         if(slDist <= 0) return;

         double tp = NormalizeDouble(entry + slDist * RR_Initial, _Digits);

         Print("BUY @ OB Retest: Entry=", entry, " SL=", sl, " TP=", tp,
               " OB=[", gOB_Low, "-", gOB_High, "]");

         if(trade.Buy(LotSize, _Symbol, entry, sl, tp, "RangeOB_Buy"))
         {
            gTradesToday++;
            gEntrySLDist = slDist;
            gBE_Hit = false;
            gState = ST_IN_TRADE;
         }
      }

      // If price broke back below range low, breakout failed
      if(bid < gRangeLow)
      {
         Print("Breakout failed - price back below range");
         gState = ST_DONE_TODAY;
      }
   }
   else if(gBreakDir == -1)  // Bearish breakout - wait for pullback up into OB
   {
      bool touchedOB = rates[0].high >= gOB_Low && rates[0].high <= gOB_High + SL_Buffer_Pts * _Point;
      bool closedBelow = rates[0].close < gOB_Low;

      bool priceInOB = bid >= gOB_Low && bid <= gOB_High;

      if((touchedOB && closedBelow) || priceInOB)
      {
         double entry = bid;
         double sl = NormalizeDouble(gOB_High + SL_Buffer_Pts * _Point, _Digits);
         double slDist = sl - entry;

         if(slDist <= 0) return;

         double tp = NormalizeDouble(entry - slDist * RR_Initial, _Digits);

         Print("SELL @ OB Retest: Entry=", entry, " SL=", sl, " TP=", tp,
               " OB=[", gOB_Low, "-", gOB_High, "]");

         if(trade.Sell(LotSize, _Symbol, entry, sl, tp, "RangeOB_Sell"))
         {
            gTradesToday++;
            gEntrySLDist = slDist;
            gBE_Hit = false;
            gState = ST_IN_TRADE;
         }
      }

      // If price broke back above range high, breakout failed
      if(ask > gRangeHigh)
      {
         Print("Breakout failed - price back above range");
         gState = ST_DONE_TODAY;
      }
   }
}

//+------------------------------------------------------------------+
//| PHASE 4: Manage open position - BE at 1:1, extend TP to 1:4     |
//+------------------------------------------------------------------+
void ManagePosition()
{
   if(!HasOpenPosition())
   {
      gState = ST_DONE_TODAY;
      return;
   }

   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      if(PositionGetInteger(POSITION_MAGIC) != MagicNumber) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;

      double posOpen = PositionGetDouble(POSITION_PRICE_OPEN);
      double posSL   = PositionGetDouble(POSITION_SL);
      double posTP   = PositionGetDouble(POSITION_TP);
      long   posType = PositionGetInteger(POSITION_TYPE);

      double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);

      if(posType == POSITION_TYPE_BUY)
      {
         double profit = bid - posOpen;
         double profitRR = (gEntrySLDist > 0) ? profit / gEntrySLDist : 0;

         // Step 1: At 1:1, move SL to breakeven and extend TP to 1:4
         if(!gBE_Hit && profitRR >= BE_Trigger_RR)
         {
            double newSL = NormalizeDouble(posOpen + BE_Lock_Points * _Point, _Digits);
            double newTP = NormalizeDouble(posOpen + gEntrySLDist * RR_Extended, _Digits);

            if(newSL > posSL)
            {
               trade.PositionModify(ticket, newSL, newTP);
               gBE_Hit = true;
               Print("BE Hit! SL moved to ", newSL, " TP extended to ", newTP, " (1:", RR_Extended, ")");
            }
         }
         // Step 2: After BE, trail the stop
         else if(gBE_Hit && profitRR >= 2.0)
         {
            double trailSL = NormalizeDouble(bid - Trail_Step_Pts * _Point, _Digits);
            if(trailSL > posSL && trailSL > posOpen)
               trade.PositionModify(ticket, trailSL, posTP);
         }
      }
      else // SELL
      {
         double profit = posOpen - ask;
         double profitRR = (gEntrySLDist > 0) ? profit / gEntrySLDist : 0;

         if(!gBE_Hit && profitRR >= BE_Trigger_RR)
         {
            double newSL = NormalizeDouble(posOpen - BE_Lock_Points * _Point, _Digits);
            double newTP = NormalizeDouble(posOpen - gEntrySLDist * RR_Extended, _Digits);

            if(newSL < posSL)
            {
               trade.PositionModify(ticket, newSL, newTP);
               gBE_Hit = true;
               Print("BE Hit! SL moved to ", newSL, " TP extended to ", newTP, " (1:", RR_Extended, ")");
            }
         }
         else if(gBE_Hit && profitRR >= 2.0)
         {
            double trailSL = NormalizeDouble(ask + Trail_Step_Pts * _Point, _Digits);
            if(trailSL < posSL && trailSL < posOpen)
               trade.PositionModify(ticket, trailSL, posTP);
         }
      }
   }
}

//+------------------------------------------------------------------+
bool IsNewBar()
{
   static datetime lastBar = 0;
   datetime curBar = iTime(_Symbol, PERIOD_CURRENT, 0);
   if(curBar == lastBar) return false;
   lastBar = curBar;
   return true;
}

//+------------------------------------------------------------------+
bool HasOpenPosition()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      if(PositionGetInteger(POSITION_MAGIC) == MagicNumber &&
         PositionGetString(POSITION_SYMBOL) == _Symbol)
         return true;
   }
   return false;
}

//+------------------------------------------------------------------+
//| Draw range and OB lines on chart for visual reference              |
//+------------------------------------------------------------------+
void DrawRange()
{
   string prefix = "AROB_";
   datetime t1 = TimeCurrent() - 3600;
   datetime t2 = TimeCurrent() + 86400;

   ObjectCreate(0, prefix + "RangeHigh", OBJ_HLINE, 0, 0, gRangeHigh);
   ObjectSetInteger(0, prefix + "RangeHigh", OBJPROP_COLOR, clrDodgerBlue);
   ObjectSetInteger(0, prefix + "RangeHigh", OBJPROP_STYLE, STYLE_DASH);
   ObjectSetInteger(0, prefix + "RangeHigh", OBJPROP_WIDTH, 1);

   ObjectCreate(0, prefix + "RangeLow", OBJ_HLINE, 0, 0, gRangeLow);
   ObjectSetInteger(0, prefix + "RangeLow", OBJPROP_COLOR, clrDodgerBlue);
   ObjectSetInteger(0, prefix + "RangeLow", OBJPROP_STYLE, STYLE_DASH);
   ObjectSetInteger(0, prefix + "RangeLow", OBJPROP_WIDTH, 1);
}

void DrawOB()
{
   string prefix = "AROB_";

   ObjectCreate(0, prefix + "OB_High", OBJ_HLINE, 0, 0, gOB_High);
   ObjectSetInteger(0, prefix + "OB_High", OBJPROP_COLOR, clrOrange);
   ObjectSetInteger(0, prefix + "OB_High", OBJPROP_STYLE, STYLE_DOT);

   ObjectCreate(0, prefix + "OB_Low", OBJ_HLINE, 0, 0, gOB_Low);
   ObjectSetInteger(0, prefix + "OB_Low", OBJPROP_COLOR, clrOrange);
   ObjectSetInteger(0, prefix + "OB_Low", OBJPROP_STYLE, STYLE_DOT);
}
//+------------------------------------------------------------------+
