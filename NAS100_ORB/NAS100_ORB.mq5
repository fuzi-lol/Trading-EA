//+------------------------------------------------------------------+
//|                                           NAS100_ORB.mq5         |
//|   Opening Range Breakout Strategy for NAS100 (US Tech 100)       |
//|   Trades breakout of first 15-30 min of US cash session          |
//|   with VWAP bias, EMA trend filter, and ATR volatility gate      |
//+------------------------------------------------------------------+

#property version   "1.00"
#property strict

#include <Trade\Trade.mqh>

//=== INPUTS =========================================================

//--- Opening Range Settings
input int      OR_StartHour     = 16;       // OR start hour (server time, 16=9:30 ET typical)
input int      OR_StartMinute   = 30;       // OR start minute
input int      OR_DurationMin   = 15;       // OR duration in minutes (15 or 30)
input double   OR_MinRange_Pts  = 200;      // Min range size in points (skip tiny ranges)
input double   OR_MaxRange_Pts  = 2000;     // Max range size in points (skip news spikes)

//--- Breakout Entry
input double   BreakoutBuffer_Pts = 30;     // Points above/below range for entry trigger
input bool     WaitForClose     = false;     // Wait for candle close above/below range
input int      MaxBarsAfterOR   = 48;       // Cancel if no breakout within N bars (e.g. 48 x 5min = 4hrs)

//--- Trend Filters
input int      EMA_Period       = 50;       // H1 EMA period for trend filter
input bool     UseEMAFilter     = true;     // Enable EMA trend filter
input bool     UseVWAP          = true;     // Use VWAP as bias filter
input int      VWAP_Period      = 1;        // VWAP lookback (1 = daily)

//--- ATR Volatility Gate
input int      ATR_Period       = 14;       // ATR period (H1)
input double   ATR_MinMulti     = 0.5;      // Min ATR vs 20-day avg (skip dead days)
input double   ATR_MaxMulti     = 3.0;      // Max ATR vs 20-day avg (skip news bombs)

//--- Stop Loss & Take Profit
input double   SL_Mode          = 0;        // 0=Range-based, 1=ATR-based
input double   SL_RangeMulti    = 1.0;      // SL = range height * this multiplier
input double   ATR_SL_Multi     = 1.5;      // ATR multiplier for SL (if ATR mode)
input double   MinSL_Points     = 150;      // Min SL distance in points
input double   MaxSL_Points     = 1500;     // Max SL distance in points
input double   RiskReward       = 2.0;      // Risk:Reward ratio for TP

//--- Breakeven & Trailing
input double   BE_Trigger_RR    = 1.0;      // Move SL to BE at this R multiple
input double   BE_Lock_Points   = 30;       // Points of profit to lock at BE
input double   Trail_Trigger_RR = 1.5;      // Start trailing at this R multiple
input double   Trail_Step_Pts   = 150;      // Trailing step in points

//--- Partial Close
input bool     UsePartialClose  = true;     // Enable partial close at 1R
input double   PartialPct       = 50.0;     // Percentage to close at partial TP
input double   PartialTP_RR     = 1.0;      // R multiple for partial close

//--- Risk Management
input double   RiskPercent      = 1.0;      // Risk % of balance per trade (0 = fixed lot)
input double   FixedLot         = 0.10;     // Fixed lot size (used if RiskPercent=0)
input int      MaxTradesPerDay  = 1;        // Max trades per day
input int      MaxSpreadPts     = 80;       // Max spread in points
input int      MagicNumber      = 770100;   // Magic number

//--- Session Control
input int      DeadlineHour     = 21;       // Stop trading after this server hour
input bool     CloseEOD         = false;    // Close all positions at end of day
input int      EOD_Hour         = 22;       // EOD close hour (server time)
input bool     SkipMonday       = false;    // Skip Monday (often choppy opens)
input bool     SkipFriday       = false;    // Skip Friday (early close risk)

//=== GLOBALS ========================================================
CTrade   trade;
int      hATR_H1;
int      hEMA_H1;

// Opening Range state
bool     gOR_Defined;            // OR is captured for today
double   gOR_High;               // OR high price
double   gOR_Low;                // OR low price
double   gOR_Mid;                // OR midpoint
datetime gOR_StartTime;          // OR start timestamp
datetime gOR_EndTime;            // OR end timestamp
int      gBarsAfterOR;           // Bars elapsed since OR ended

// Trade state
datetime gDay;                   // Current day
int      gTradesToday;           // Trades taken today
bool     gBreakoutTriggered;     // Already triggered a breakout today
bool     gPartialDone;           // Partial close done for current trade
double   gEntrySL_Dist;          // SL distance at entry (for BE/trail calc)
int      gEntryDirection;        // 1=long, -1=short, 0=none

// VWAP calculation
double   gVWAP;                  // Current session VWAP
double   gCumVolPrice;           // Cumulative volume * price
double   gCumVolume;             // Cumulative volume
datetime gVWAP_Day;              // Day for VWAP reset

//=== INIT / DEINIT ==================================================
int OnInit()
{
   trade.SetExpertMagicNumber(MagicNumber);

   // H1 ATR
   hATR_H1 = iATR(_Symbol, PERIOD_H1, ATR_Period);
   if(hATR_H1 == INVALID_HANDLE)
   {
      Print("Failed to create ATR indicator");
      return INIT_FAILED;
   }

   // H1 EMA
   hEMA_H1 = iMA(_Symbol, PERIOD_H1, EMA_Period, 0, MODE_EMA, PRICE_CLOSE);
   if(hEMA_H1 == INVALID_HANDLE)
   {
      Print("Failed to create EMA indicator");
      return INIT_FAILED;
   }

   ResetDailyState();
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
   if(hATR_H1 != INVALID_HANDLE) IndicatorRelease(hATR_H1);
   if(hEMA_H1 != INVALID_HANDLE) IndicatorRelease(hEMA_H1);
}

//=== MAIN TICK ======================================================
void OnTick()
{
   // --- Day change detection
   datetime today = iTime(_Symbol, PERIOD_D1, 0);
   if(today != gDay)
   {
      gDay = today;
      ResetDailyState();
   }

   // --- Day filter
   MqlDateTime dt;
   TimeCurrent(dt);

   if(SkipMonday && dt.day_of_week == 1) return;
   if(SkipFriday && dt.day_of_week == 5) return;
   if(dt.day_of_week == 0 || dt.day_of_week == 6) return; // weekend

   // --- EOD close
   if(CloseEOD && dt.hour >= EOD_Hour)
   {
      CloseAllPositions();
      return;
   }

   // --- Past deadline, no new trades
   if(dt.hour >= DeadlineHour)
      return;

   // --- Update VWAP
   if(UseVWAP)
      CalcVWAP();

   // --- Phase 1: Capture the Opening Range
   if(!gOR_Defined)
   {
      CaptureOpeningRange(dt);
      return;  // Don't trade while OR is forming
   }

   // --- Phase 2: Manage existing positions
   ManageOpenTrades();

   // --- Phase 3: Look for breakout entry
   if(!gBreakoutTriggered && gTradesToday < MaxTradesPerDay)
   {
      gBarsAfterOR++;
      if(gBarsAfterOR <= MaxBarsAfterOR)
         CheckBreakout(dt);
   }
}

//=== OPENING RANGE CAPTURE ==========================================
void CaptureOpeningRange(MqlDateTime &dt)
{
   // Check if we're in the OR window
   int currentMinutes = dt.hour * 60 + dt.min;
   int orStartMinutes = OR_StartHour * 60 + OR_StartMinute;
   int orEndMinutes   = orStartMinutes + OR_DurationMin;

   if(currentMinutes < orStartMinutes)
      return;  // Before OR starts

   // Set OR start time on first entry
   if(gOR_StartTime == 0)
   {
      gOR_StartTime = TimeCurrent() - (currentMinutes - orStartMinutes) * 60;
      gOR_High = 0;
      gOR_Low  = DBL_MAX;
   }

   // During OR: track high and low
   if(currentMinutes < orEndMinutes)
   {
      double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      double mid = (bid + ask) / 2.0;

      if(mid > gOR_High) gOR_High = mid;
      if(mid < gOR_Low)  gOR_Low  = mid;

      // Also scan bar data for the OR period to ensure we capture wicks
      int bars = Bars(_Symbol, PERIOD_M1, gOR_StartTime, TimeCurrent());
      if(bars > 0)
      {
         double highs[], lows[];
         if(CopyHigh(_Symbol, PERIOD_M1, gOR_StartTime, TimeCurrent(), highs) > 0)
         {
            for(int i = 0; i < ArraySize(highs); i++)
               if(highs[i] > gOR_High) gOR_High = highs[i];
         }
         if(CopyLow(_Symbol, PERIOD_M1, gOR_StartTime, TimeCurrent(), lows) > 0)
         {
            for(int i = 0; i < ArraySize(lows); i++)
               if(lows[i] < gOR_Low) gOR_Low = lows[i];
         }
      }
      return;
   }

   // OR period is over - finalize the range
   gOR_EndTime = gOR_StartTime + OR_DurationMin * 60;
   gOR_Mid = (gOR_High + gOR_Low) / 2.0;
   double rangePoints = (gOR_High - gOR_Low) / _Point;

   // Validate range size
   if(rangePoints < OR_MinRange_Pts || rangePoints > OR_MaxRange_Pts)
   {
      Print("OR range ", DoubleToString(rangePoints, 0), " pts - outside bounds, skipping day");
      gOR_Defined = true;
      gBreakoutTriggered = true;  // Skip trading today
      return;
   }

   gOR_Defined = true;
   gBarsAfterOR = 0;

   // Draw OR zone on chart
   DrawORZone();

   Print("OR Defined: High=", DoubleToString(gOR_High, _Digits),
         " Low=", DoubleToString(gOR_Low, _Digits),
         " Range=", DoubleToString(rangePoints, 0), " pts");
}

//=== BREAKOUT CHECK =================================================
void CheckBreakout(MqlDateTime &dt)
{
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double spread = (ask - bid) / _Point;

   // Spread check
   if(spread > MaxSpreadPts)
      return;

   double bufferPrice = BreakoutBuffer_Pts * _Point;
   double breakHigh = gOR_High + bufferPrice;
   double breakLow  = gOR_Low  - bufferPrice;

   int direction = 0;

   // Check for breakout
   if(WaitForClose)
   {
      // Use previous bar close
      double close1 = iClose(_Symbol, PERIOD_CURRENT, 1);
      if(close1 > breakHigh) direction = 1;
      else if(close1 < breakLow) direction = -1;
   }
   else
   {
      if(bid > breakHigh) direction = 1;
      else if(bid < breakLow) direction = -1;
   }

   if(direction == 0)
      return;

   // --- Apply filters ---

   // ATR volatility gate
   if(!CheckATRGate())
      return;

   // EMA trend filter
   if(UseEMAFilter && !CheckEMAFilter(direction))
      return;

   // VWAP bias filter
   if(UseVWAP && !CheckVWAPFilter(direction, bid))
      return;

   // --- Calculate SL/TP ---
   double slDist = CalcSLDistance();
   if(slDist == 0) return;

   double tpDist = slDist * RiskReward;
   double lotSize = CalcLotSize(slDist);
   if(lotSize <= 0) return;

   // --- Execute trade ---
   double sl, tp, entry;

   if(direction == 1) // BUY
   {
      entry = ask;
      sl = entry - slDist;
      tp = entry + tpDist;

      // Ensure SL is below OR low for safety
      double orLowSL = gOR_Low - 50 * _Point;
      if(sl > orLowSL) sl = orLowSL;

      if(trade.Buy(lotSize, _Symbol, entry, sl, tp, "ORB_Long"))
      {
         gBreakoutTriggered = true;
         gTradesToday++;
         gPartialDone = false;
         gEntrySL_Dist = entry - sl;
         gEntryDirection = 1;
         Print("ORB BUY: Entry=", DoubleToString(entry, _Digits),
               " SL=", DoubleToString(sl, _Digits),
               " TP=", DoubleToString(tp, _Digits),
               " Lots=", DoubleToString(lotSize, 2));
      }
   }
   else // SELL
   {
      entry = bid;
      sl = entry + slDist;
      tp = entry - tpDist;

      // Ensure SL is above OR high for safety
      double orHighSL = gOR_High + 50 * _Point;
      if(sl < orHighSL) sl = orHighSL;

      if(trade.Sell(lotSize, _Symbol, entry, sl, tp, "ORB_Short"))
      {
         gBreakoutTriggered = true;
         gTradesToday++;
         gPartialDone = false;
         gEntrySL_Dist = sl - entry;
         gEntryDirection = -1;
         Print("ORB SELL: Entry=", DoubleToString(entry, _Digits),
               " SL=", DoubleToString(sl, _Digits),
               " TP=", DoubleToString(tp, _Digits),
               " Lots=", DoubleToString(lotSize, 2));
      }
   }
}

//=== FILTERS ========================================================

bool CheckATRGate()
{
   double atr[];
   if(CopyBuffer(hATR_H1, 0, 0, 21, atr) < 21) return true; // fail open

   double currentATR = atr[20];

   // Average ATR over last 20 bars (excluding current)
   double avgATR = 0;
   for(int i = 0; i < 20; i++)
      avgATR += atr[i];
   avgATR /= 20.0;

   if(avgATR == 0) return true;

   double ratio = currentATR / avgATR;

   if(ratio < ATR_MinMulti)
   {
      Print("ATR gate: too quiet (", DoubleToString(ratio, 2), "x avg)");
      return false;
   }
   if(ratio > ATR_MaxMulti)
   {
      Print("ATR gate: too volatile (", DoubleToString(ratio, 2), "x avg)");
      return false;
   }
   return true;
}

bool CheckEMAFilter(int direction)
{
   double ema[];
   if(CopyBuffer(hEMA_H1, 0, 0, 2, ema) < 2) return true;

   double price = SymbolInfoDouble(_Symbol, SYMBOL_BID);

   // Price should be on the same side as the breakout direction
   if(direction == 1 && price < ema[1])
   {
      Print("EMA filter: price below H1 EMA, skipping long");
      return false;
   }
   if(direction == -1 && price > ema[1])
   {
      Print("EMA filter: price above H1 EMA, skipping short");
      return false;
   }
   return true;
}

bool CheckVWAPFilter(int direction, double price)
{
   if(gVWAP == 0) return true;

   if(direction == 1 && price < gVWAP)
   {
      Print("VWAP filter: price below VWAP, skipping long");
      return false;
   }
   if(direction == -1 && price > gVWAP)
   {
      Print("VWAP filter: price above VWAP, skipping short");
      return false;
   }
   return true;
}

//=== SL CALCULATION =================================================
double CalcSLDistance()
{
   double slDist;

   if(SL_Mode == 0)
   {
      // Range-based SL
      double rangeHeight = gOR_High - gOR_Low;
      slDist = rangeHeight * SL_RangeMulti;
   }
   else
   {
      // ATR-based SL
      double atr[];
      if(CopyBuffer(hATR_H1, 0, 0, 2, atr) < 2) return 0;
      slDist = atr[1] * ATR_SL_Multi;
   }

   // Clamp SL
   double minSL = MinSL_Points * _Point;
   double maxSL = MaxSL_Points * _Point;

   if(slDist < minSL) slDist = minSL;
   if(slDist > maxSL) slDist = maxSL;

   return NormalizeDouble(slDist, _Digits);
}

//=== LOT SIZE CALCULATION ===========================================
double CalcLotSize(double slDist)
{
   if(RiskPercent <= 0)
      return FixedLot;

   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double riskMoney = balance * RiskPercent / 100.0;

   // Get tick value for position sizing
   double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double tickSize  = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);

   if(tickValue == 0 || tickSize == 0 || slDist == 0)
      return FixedLot;

   double slTicks = slDist / tickSize;
   double lotSize = riskMoney / (slTicks * tickValue);

   // Normalize to lot step
   double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   double minLot  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxLot  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);

   lotSize = MathFloor(lotSize / lotStep) * lotStep;
   lotSize = MathMax(lotSize, minLot);
   lotSize = MathMin(lotSize, maxLot);

   return NormalizeDouble(lotSize, 2);
}

//=== TRADE MANAGEMENT ===============================================
void ManageOpenTrades()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      if(PositionGetInteger(POSITION_MAGIC) != MagicNumber) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;

      double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
      double currentSL = PositionGetDouble(POSITION_SL);
      double currentTP = PositionGetDouble(POSITION_TP);
      double profit    = PositionGetDouble(POSITION_PROFIT);
      long   type      = PositionGetInteger(POSITION_TYPE);
      double volume    = PositionGetDouble(POSITION_VOLUME);

      double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);

      if(gEntrySL_Dist <= 0) continue;

      // --- Partial close at 1R ---
      if(UsePartialClose && !gPartialDone)
      {
         double partialTarget = gEntrySL_Dist * PartialTP_RR;
         bool hitPartial = false;

         if(type == POSITION_TYPE_BUY && (bid - openPrice) >= partialTarget)
            hitPartial = true;
         if(type == POSITION_TYPE_SELL && (openPrice - ask) >= partialTarget)
            hitPartial = true;

         if(hitPartial)
         {
            double closeLots = NormalizeDouble(volume * PartialPct / 100.0, 2);
            double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
            closeLots = MathFloor(closeLots / lotStep) * lotStep;
            double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);

            if(closeLots >= minLot)
            {
               if(type == POSITION_TYPE_BUY)
                  trade.Sell(closeLots, _Symbol, bid, 0, 0, "ORB_Partial");
               else
                  trade.Buy(closeLots, _Symbol, ask, 0, 0, "ORB_Partial");

               gPartialDone = true;
               Print("Partial close: ", DoubleToString(closeLots, 2), " lots at 1R");
            }
         }
      }

      // --- Breakeven ---
      double beTarget = gEntrySL_Dist * BE_Trigger_RR;
      double beLock   = BE_Lock_Points * _Point;

      if(type == POSITION_TYPE_BUY)
      {
         double priceDist = bid - openPrice;

         // Breakeven
         if(priceDist >= beTarget && currentSL < openPrice + beLock)
         {
            double newSL = openPrice + beLock;
            newSL = NormalizeDouble(newSL, _Digits);
            if(newSL > currentSL)
               trade.PositionModify(ticket, newSL, currentTP);
         }

         // Trailing
         double trailTarget = gEntrySL_Dist * Trail_Trigger_RR;
         if(priceDist >= trailTarget)
         {
            double trailSL = bid - Trail_Step_Pts * _Point;
            trailSL = NormalizeDouble(trailSL, _Digits);
            if(trailSL > currentSL)
               trade.PositionModify(ticket, trailSL, currentTP);
         }
      }
      else if(type == POSITION_TYPE_SELL)
      {
         double priceDist = openPrice - ask;

         // Breakeven
         if(priceDist >= beTarget && (currentSL > openPrice - beLock || currentSL == 0))
         {
            double newSL = openPrice - beLock;
            newSL = NormalizeDouble(newSL, _Digits);
            if(currentSL == 0 || newSL < currentSL)
               trade.PositionModify(ticket, newSL, currentTP);
         }

         // Trailing
         double trailTarget = gEntrySL_Dist * Trail_Trigger_RR;
         if(priceDist >= trailTarget)
         {
            double trailSL = ask + Trail_Step_Pts * _Point;
            trailSL = NormalizeDouble(trailSL, _Digits);
            if(currentSL == 0 || trailSL < currentSL)
               trade.PositionModify(ticket, trailSL, currentTP);
         }
      }
   }
}

//=== VWAP CALCULATION ===============================================
void CalcVWAP()
{
   datetime today = iTime(_Symbol, PERIOD_D1, 0);

   // Reset on new day
   if(today != gVWAP_Day)
   {
      gVWAP_Day = today;
      gCumVolPrice = 0;
      gCumVolume = 0;
      gVWAP = 0;
   }

   // Use M5 bars for VWAP calculation
   int todayBars = Bars(_Symbol, PERIOD_M5, today, TimeCurrent());
   if(todayBars <= 0) return;

   // Recalculate from scratch each time (simple approach)
   double closes[], highs[], lows[];
   long volumes[];
   int copied = CopyClose(_Symbol, PERIOD_M5, today, TimeCurrent(), closes);
   CopyHigh(_Symbol, PERIOD_M5, today, TimeCurrent(), highs);
   CopyLow(_Symbol, PERIOD_M5, today, TimeCurrent(), lows);
   CopyTickVolume(_Symbol, PERIOD_M5, today, TimeCurrent(), volumes);

   if(copied <= 0) return;

   gCumVolPrice = 0;
   gCumVolume = 0;

   for(int i = 0; i < copied; i++)
   {
      double typical = (highs[i] + lows[i] + closes[i]) / 3.0;
      gCumVolPrice += typical * volumes[i];
      gCumVolume   += volumes[i];
   }

   if(gCumVolume > 0)
      gVWAP = gCumVolPrice / gCumVolume;
}

//=== CLOSE ALL POSITIONS ============================================
void CloseAllPositions()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      if(PositionGetInteger(POSITION_MAGIC) != MagicNumber) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;

      trade.PositionClose(ticket);
   }
}

//=== DRAW OR ZONE ===================================================
void DrawORZone()
{
   string nameRect = "ORB_Zone_" + TimeToString(gOR_StartTime, TIME_DATE);
   string nameHigh = "ORB_High_" + TimeToString(gOR_StartTime, TIME_DATE);
   string nameLow  = "ORB_Low_"  + TimeToString(gOR_StartTime, TIME_DATE);
   string nameMid  = "ORB_Mid_"  + TimeToString(gOR_StartTime, TIME_DATE);

   datetime endDraw = gOR_StartTime + 12 * 3600; // extend 12 hours

   // Rectangle zone
   ObjectCreate(0, nameRect, OBJ_RECTANGLE, 0, gOR_StartTime, gOR_High, endDraw, gOR_Low);
   ObjectSetInteger(0, nameRect, OBJPROP_COLOR, clrDodgerBlue);
   ObjectSetInteger(0, nameRect, OBJPROP_FILL, true);
   ObjectSetInteger(0, nameRect, OBJPROP_BACK, true);
   ObjectSetInteger(0, nameRect, OBJPROP_WIDTH, 1);

   // High line
   ObjectCreate(0, nameHigh, OBJ_TREND, 0, gOR_StartTime, gOR_High, endDraw, gOR_High);
   ObjectSetInteger(0, nameHigh, OBJPROP_COLOR, clrLime);
   ObjectSetInteger(0, nameHigh, OBJPROP_STYLE, STYLE_DASH);
   ObjectSetInteger(0, nameHigh, OBJPROP_WIDTH, 2);
   ObjectSetInteger(0, nameHigh, OBJPROP_RAY_RIGHT, false);

   // Low line
   ObjectCreate(0, nameLow, OBJ_TREND, 0, gOR_StartTime, gOR_Low, endDraw, gOR_Low);
   ObjectSetInteger(0, nameLow, OBJPROP_COLOR, clrRed);
   ObjectSetInteger(0, nameLow, OBJPROP_STYLE, STYLE_DASH);
   ObjectSetInteger(0, nameLow, OBJPROP_WIDTH, 2);
   ObjectSetInteger(0, nameLow, OBJPROP_RAY_RIGHT, false);

   // Mid line
   ObjectCreate(0, nameMid, OBJ_TREND, 0, gOR_StartTime, gOR_Mid, endDraw, gOR_Mid);
   ObjectSetInteger(0, nameMid, OBJPROP_COLOR, clrGold);
   ObjectSetInteger(0, nameMid, OBJPROP_STYLE, STYLE_DOT);
   ObjectSetInteger(0, nameMid, OBJPROP_WIDTH, 1);
   ObjectSetInteger(0, nameMid, OBJPROP_RAY_RIGHT, false);
}

//=== DAILY RESET ====================================================
void ResetDailyState()
{
   gOR_Defined = false;
   gOR_High = 0;
   gOR_Low = DBL_MAX;
   gOR_Mid = 0;
   gOR_StartTime = 0;
   gOR_EndTime = 0;
   gBarsAfterOR = 0;
   gTradesToday = 0;
   gBreakoutTriggered = false;
   gPartialDone = false;
   gEntrySL_Dist = 0;
   gEntryDirection = 0;
}

//+------------------------------------------------------------------+
