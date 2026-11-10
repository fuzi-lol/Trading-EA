//+------------------------------------------------------------------+
//|                                       GoldenTimeStrategy.mq5     |
//|                   Golden Time Strategy V5 - Fully Optimized      |
//+------------------------------------------------------------------+
#property copyright "GoldenTime"
#property version   "5.00"

#include <Trade\Trade.mqh>

//--- Inputs: Zone
input int      ZoneHour        = 13;     // Zone candle hour (server time)
input int      ZoneMinute      = 15;     // Zone candle minute
input int      ZoneDuration    = 3;      // Zone candle duration (minutes)

//--- Inputs: Trade (Fix #1: Better R:R — tighter SL, wider TP)
input double   LotSize         = 0.10;   // Lot size
input double   MaxSLPips       = 30.0;   // Max SL pips (tightened from 50)
input double   TP1Pips         = 50.0;   // First target pips (widened from 40)
input double   PartialPct      = 80.0;   // % qty to close at TP1
input double   TrailRR         = 3.0;    // R:R target for remaining qty
input int      MaxAttempts     = 1;      // Max attempts (Fix #4: reduced from 3)

//--- Inputs: Multi-TF Trend Filter (Fix #2: Stronger filter)
input bool     UseTrendFilter  = true;   // Enable multi-TF trend filter
input int      EMA_Fast        = 21;     // Fast EMA period (H1)
input int      EMA_Slow        = 50;     // Slow EMA period (H1)
input int      EMA_HTF         = 200;    // Higher TF EMA (H4)
input bool     UseDailyBias    = true;   // Use previous day close as bias

//--- Inputs: ATR Volatility Filter (Fix #3: Skip choppy days)
input bool     UseATRFilter    = true;   // Enable ATR filter
input int      ATR_Period      = 14;     // ATR period
input ENUM_TIMEFRAMES ATR_TF   = PERIOD_H1; // ATR timeframe
input double   ATR_MinPips     = 10.0;   // Min ATR to trade (skip low vol)
input double   ATR_MaxPips     = 80.0;   // Max ATR to trade (skip extreme vol)

//--- Inputs: Trailing
input bool     UseTrailingStop = true;   // Enable trailing stop
input double   TrailStepPips   = 10.0;   // Trailing step in pips

//--- Inputs: Session
input int      TradeEndHour    = 21;     // Stop new trades after this hour
input int      MagicNumber     = 184500; // Magic number

//--- Globals
CTrade   trade;
double   gZoneHigh, gZoneLow;
bool     gZoneReady;
int      gAttempts;
datetime gDay;
bool     gPartialDone;
double   gOrigRisk;
double   gEntryPrice;
datetime gLastEntryBar;
double   gPipSize;

int      gEmaFastHandle;
int      gEmaSlowHandle;
int      gEmaHTFHandle;
int      gATRHandle;

//+------------------------------------------------------------------+
int OnInit()
{
   trade.SetExpertMagicNumber(MagicNumber);
   trade.SetDeviationInPoints(30);

   // Pip size: XAUUSD _Digits=2, _Point=0.01 → pip=0.10
   if(_Digits >= 2 && _Digits <= 5)
      gPipSize = _Point * 10;
   else
      gPipSize = _Point;

   gZoneReady    = false;
   gAttempts     = 0;
   gDay          = 0;
   gPartialDone  = false;
   gOrigRisk     = 0;
   gEntryPrice   = 0;
   gLastEntryBar = 0;

   // Create indicator handles
   if(UseTrendFilter)
   {
      gEmaFastHandle = iMA(_Symbol, PERIOD_H1, EMA_Fast, 0, MODE_EMA, PRICE_CLOSE);
      gEmaSlowHandle = iMA(_Symbol, PERIOD_H1, EMA_Slow, 0, MODE_EMA, PRICE_CLOSE);
      gEmaHTFHandle  = iMA(_Symbol, PERIOD_H4, EMA_HTF, 0, MODE_EMA, PRICE_CLOSE);
      if(gEmaFastHandle == INVALID_HANDLE || gEmaSlowHandle == INVALID_HANDLE || gEmaHTFHandle == INVALID_HANDLE)
      {
         Print("Failed to create EMA handles");
         return INIT_FAILED;
      }
   }

   if(UseATRFilter)
   {
      gATRHandle = iATR(_Symbol, ATR_TF, ATR_Period);
      if(gATRHandle == INVALID_HANDLE)
      {
         Print("Failed to create ATR handle");
         return INIT_FAILED;
      }
   }

   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   if(UseTrendFilter)
   {
      if(gEmaFastHandle != INVALID_HANDLE) IndicatorRelease(gEmaFastHandle);
      if(gEmaSlowHandle != INVALID_HANDLE) IndicatorRelease(gEmaSlowHandle);
      if(gEmaHTFHandle  != INVALID_HANDLE) IndicatorRelease(gEmaHTFHandle);
   }
   if(UseATRFilter && gATRHandle != INVALID_HANDLE)
      IndicatorRelease(gATRHandle);
}

//+------------------------------------------------------------------+
void OnTick()
{
   // Daily reset
   datetime today = iTime(_Symbol, PERIOD_D1, 0);
   if(today != gDay)
   {
      gDay          = today;
      gZoneReady    = false;
      gAttempts     = 0;
      gPartialDone  = false;
      gZoneHigh     = 0;
      gZoneLow      = 0;
      gOrigRisk     = 0;
      gEntryPrice   = 0;
      gLastEntryBar = 0;
   }

   // Step 1: Mark zone once per day
   if(!gZoneReady)
      TryMarkZone();

   // Step 2: Manage existing position or look for entries
   if(gZoneReady)
   {
      if(HasPosition())
         ManagePosition();
      else if(gAttempts < MaxAttempts)
         CheckBreakout();
   }
}

//+------------------------------------------------------------------+
void TryMarkZone()
{
   MqlDateTime dt;
   TimeCurrent(dt);

   int endMin  = ZoneMinute + ZoneDuration;
   int endHour = ZoneHour + endMin / 60;
   endMin      = endMin % 60;

   if(dt.hour < endHour || (dt.hour == endHour && dt.min < endMin))
      return;

   string dateStr = TimeToString(TimeCurrent(), TIME_DATE);
   datetime zoneStart = StringToTime(dateStr + " " +
      IntegerToString(ZoneHour, 2, '0') + ":" +
      IntegerToString(ZoneMinute, 2, '0') + ":00");
   datetime zoneEnd = zoneStart + (ZoneDuration - 1) * 60;

   MqlRates rates[];
   ArraySetAsSeries(rates, false);
   int copied = CopyRates(_Symbol, PERIOD_M1, zoneStart, zoneEnd, rates);
   if(copied < 1)
      return;

   gZoneHigh = rates[0].high;
   gZoneLow  = rates[0].low;
   for(int i = 1; i < copied; i++)
   {
      if(rates[i].high > gZoneHigh) gZoneHigh = rates[i].high;
      if(rates[i].low  < gZoneLow)  gZoneLow  = rates[i].low;
   }

   gZoneReady = true;
}

//+------------------------------------------------------------------+
//| Multi-TF Trend Filter: returns 1=buy only, -1=sell only, 0=skip  |
//+------------------------------------------------------------------+
int GetTrendBias()
{
   if(!UseTrendFilter)
      return 99; // no filter, allow both

   double emaFast[], emaSlow[], emaHTF[];
   ArraySetAsSeries(emaFast, true);
   ArraySetAsSeries(emaSlow, true);
   ArraySetAsSeries(emaHTF, true);

   if(CopyBuffer(gEmaFastHandle, 0, 0, 1, emaFast) != 1) return 0;
   if(CopyBuffer(gEmaSlowHandle, 0, 0, 1, emaSlow) != 1) return 0;
   if(CopyBuffer(gEmaHTFHandle,  0, 0, 1, emaHTF)  != 1) return 0;

   double price = SymbolInfoDouble(_Symbol, SYMBOL_BID);

   // Condition 1: H1 fast EMA above slow EMA = bullish, below = bearish
   bool h1Bullish = emaFast[0] > emaSlow[0];

   // Condition 2: Price above H4 EMA 200 = bullish
   bool htfBullish = price > emaHTF[0];

   // Condition 3: Daily bias — price above previous day close
   bool dailyBullish = true;
   if(UseDailyBias)
   {
      double prevClose[];
      ArraySetAsSeries(prevClose, true);
      MqlRates dayBars[];
      ArraySetAsSeries(dayBars, true);
      if(CopyRates(_Symbol, PERIOD_D1, 1, 1, dayBars) == 1)
         dailyBullish = price > dayBars[0].close;
   }

   // Need at least 2 out of 3 signals aligned for a trade
   int bullScore = 0;
   if(h1Bullish)    bullScore++;
   if(htfBullish)   bullScore++;
   if(dailyBullish) bullScore++;

   if(bullScore >= 2) return  1;  // bullish — buy only
   if(bullScore <= 1) return -1;  // bearish — sell only

   return 0; // conflicting — skip
}

//+------------------------------------------------------------------+
//| ATR Volatility Filter: returns true if volatility is acceptable  |
//+------------------------------------------------------------------+
bool IsVolatilityOK()
{
   if(!UseATRFilter)
      return true;

   double atr[];
   ArraySetAsSeries(atr, true);
   if(CopyBuffer(gATRHandle, 0, 0, 1, atr) != 1)
      return true; // allow trade if we can't read ATR

   double atrPips = atr[0] / gPipSize;

   if(atrPips < ATR_MinPips)
   {
      // Too low volatility — choppy, will get stopped out
      return false;
   }
   if(atrPips > ATR_MaxPips)
   {
      // Extreme volatility — news events, too risky
      return false;
   }

   return true;
}

//+------------------------------------------------------------------+
bool HasPosition()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(PositionGetSymbol(i) == _Symbol &&
         PositionGetInteger(POSITION_MAGIC) == MagicNumber)
         return true;
   }
   return false;
}

//+------------------------------------------------------------------+
void CheckBreakout()
{
   MqlDateTime dt;
   TimeCurrent(dt);
   if(dt.hour >= TradeEndHour)
      return;

   // Get last closed bar
   MqlRates bar[];
   ArraySetAsSeries(bar, false);
   if(CopyRates(_Symbol, _Period, 1, 1, bar) != 1)
      return;

   if(bar[0].time == gLastEntryBar)
      return;

   // Check ATR filter
   if(!IsVolatilityOK())
      return;

   double close = bar[0].close;
   int trend = GetTrendBias();

   // Skip if no clear direction
   if(trend == 0)
      return;

   // Breakout above zone → BUY (only if trend bullish or unfiltered)
   if(close > gZoneHigh && (trend == 1 || trend == 99))
   {
      gLastEntryBar = bar[0].time;

      double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      double sl    = gZoneLow;
      double dist  = entry - sl;

      double maxSL = MaxSLPips * gPipSize;
      if(dist > maxSL)
      {
         sl   = entry - maxSL;
         dist = maxSL;
      }

      // Skip if zone is too tight (SL < 5 pips = noise)
      if(dist < 5 * gPipSize)
         return;

      double tp = entry + TP1Pips * gPipSize;
      sl = NormalizeDouble(sl, _Digits);
      tp = NormalizeDouble(tp, _Digits);

      if(trade.Buy(LotSize, _Symbol, entry, sl, tp, "GT Buy"))
      {
         gAttempts++;
         gOrigRisk    = dist;
         gEntryPrice  = trade.ResultPrice();
         gPartialDone = false;
      }
   }
   // Breakdown below zone → SELL (only if trend bearish or unfiltered)
   else if(close < gZoneLow && (trend == -1 || trend == 99))
   {
      gLastEntryBar = bar[0].time;

      double entry = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      double sl    = gZoneHigh;
      double dist  = sl - entry;

      double maxSL = MaxSLPips * gPipSize;
      if(dist > maxSL)
      {
         sl   = entry + maxSL;
         dist = maxSL;
      }

      if(dist < 5 * gPipSize)
         return;

      double tp = entry - TP1Pips * gPipSize;
      sl = NormalizeDouble(sl, _Digits);
      tp = NormalizeDouble(tp, _Digits);

      if(trade.Sell(LotSize, _Symbol, entry, sl, tp, "GT Sell"))
      {
         gAttempts++;
         gOrigRisk    = dist;
         gEntryPrice  = trade.ResultPrice();
         gPartialDone = false;
      }
   }
}

//+------------------------------------------------------------------+
void ManagePosition()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(PositionGetSymbol(i) != _Symbol ||
         PositionGetInteger(POSITION_MAGIC) != MagicNumber)
         continue;

      ulong  ticket = PositionGetInteger(POSITION_TICKET);
      double vol    = PositionGetDouble(POSITION_VOLUME);
      double open   = PositionGetDouble(POSITION_PRICE_OPEN);
      double sl     = PositionGetDouble(POSITION_SL);
      double tp     = PositionGetDouble(POSITION_TP);
      long   type   = PositionGetInteger(POSITION_TYPE);

      double price = (type == POSITION_TYPE_BUY)
                     ? SymbolInfoDouble(_Symbol, SYMBOL_BID)
                     : SymbolInfoDouble(_Symbol, SYMBOL_ASK);

      // --- Partial close at TP1 ---
      if(!gPartialDone)
      {
         bool hitTP1 = false;
         if(type == POSITION_TYPE_BUY  && price >= open + TP1Pips * gPipSize) hitTP1 = true;
         if(type == POSITION_TYPE_SELL && price <= open - TP1Pips * gPipSize) hitTP1 = true;

         if(hitTP1)
         {
            double closeVol = NormalizeDouble(vol * PartialPct / 100.0, 2);
            double minVol   = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
            double volStep  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);

            closeVol = MathFloor(closeVol / volStep) * volStep;
            if(closeVol < minVol) closeVol = minVol;

            if(closeVol >= vol)
            {
               trade.PositionClose(ticket);
            }
            else
            {
               trade.PositionClosePartial(ticket, closeVol);

               double beSL = NormalizeDouble(open, _Digits);
               double newTP = 0;
               if(type == POSITION_TYPE_BUY)
                  newTP = NormalizeDouble(open + TrailRR * gOrigRisk, _Digits);
               else
                  newTP = NormalizeDouble(open - TrailRR * gOrigRisk, _Digits);

               trade.PositionModify(ticket, beSL, newTP);
            }
            gPartialDone = true;
         }
      }
      // --- Dynamic trailing stop on remainder ---
      else if(UseTrailingStop)
      {
         double trailStep = TrailStepPips * gPipSize;

         if(type == POSITION_TYPE_BUY)
         {
            double profitDist = price - open;
            if(profitDist >= gOrigRisk)  // start trailing after 1R profit
            {
               double newSL = NormalizeDouble(price - trailStep, _Digits);
               if(newSL > sl + trailStep && newSL > open)
                  trade.PositionModify(ticket, newSL, tp);
            }
         }
         else if(type == POSITION_TYPE_SELL)
         {
            double profitDist = open - price;
            if(profitDist >= gOrigRisk)
            {
               double newSL = NormalizeDouble(price + trailStep, _Digits);
               if(newSL < sl - trailStep && newSL < open)
                  trade.PositionModify(ticket, newSL, tp);
            }
         }
      }
      break;
   }
}
//+------------------------------------------------------------------+
