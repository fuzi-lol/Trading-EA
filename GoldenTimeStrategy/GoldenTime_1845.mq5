//+------------------------------------------------------------------+
//|                                          GoldenTime_1845.mq5     |
//|                          Golden Time Strategy 18:45 / 6:45 PM    |
//+------------------------------------------------------------------+
#property copyright "Golden Time Strategy"
#property version   "3.00"
#property strict

#include <Trade\Trade.mqh>

//--- Strategy Inputs
input group "=== Zone Settings ==="
input int     ZoneHour         = 18;        // Zone candle hour (server time)
input int     ZoneMinute       = 45;        // Zone candle minute
input int     ZoneBars         = 3;         // Number of M1 bars for zone
input int     MinZoneWidth     = 50;        // Minimum zone width (points) - skip if too narrow
input int     ZoneBufferPts    = 20;        // Buffer above/below zone for entry (points)

input group "=== Risk Management ==="
input double  RiskPercent      = 1.0;       // Risk % per trade
input int     MaxSLPoints      = 500;       // Max SL in points (50 pips)
input int     TP1Points        = 500;       // TP1 in points (50 pips)
input double  TP1ClosePct      = 80.0;      // % to close at TP1
input double  TrailRR          = 2.0;       // Remaining position R:R target
input int     MaxAttempts      = 3;         // Max re-entry attempts after SL

input group "=== General ==="
input int     MagicNumber      = 184500;    // Magic number
input int     EndTradingHour   = 23;        // Stop trading after this hour

CTrade trade;

//--- Daily state
datetime g_today          = 0;
double   g_zoneHigh       = 0;
double   g_zoneLow        = 0;
bool     g_zoneReady      = false;
int      g_attempts       = 0;
bool     g_tp1Hit         = false;
double   g_slPrice        = 0;
datetime g_lastBarTime    = 0;
bool     g_waitForReset   = false;
int      g_lockedDir      = 0;   // 0=none, 1=buy locked, -1=sell locked
bool     g_hadPosition    = false;
bool     g_doneForDay     = false;

//+------------------------------------------------------------------+
int OnInit()
{
   trade.SetExpertMagicNumber(MagicNumber);
   trade.SetTypeFillingBySymbol(_Symbol);
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
void OnTick()
{
   MqlDateTime dt;
   TimeCurrent(dt);
   datetime today = TimeCurrent() - dt.hour*3600 - dt.min*60 - dt.sec;

   //--- Reset state on new day
   if(today != g_today)
   {
      g_today         = today;
      g_zoneReady     = false;
      g_zoneHigh      = 0;
      g_zoneLow       = 0;
      g_attempts      = 0;
      g_tp1Hit        = false;
      g_slPrice       = 0;
      g_waitForReset  = false;
      g_lockedDir     = 0;
      g_hadPosition   = false;
      g_doneForDay    = false;
   }

   if(g_doneForDay) return;

   //--- Build zone after 3-min candle completes
   if(!g_zoneReady)
   {
      if((dt.hour == ZoneHour && dt.min >= ZoneMinute + ZoneBars) || dt.hour > ZoneHour)
         BuildZone();
   }

   if(!g_zoneReady) return;
   if(dt.hour >= EndTradingHour)
   {
      // Close any remaining position at end of day
      if(HasPosition()) CloseAll();
      g_doneForDay = true;
      return;
   }

   //--- Detect position closed (SL hit)
   bool hasPos = HasPosition();
   if(g_hadPosition && !hasPos)
   {
      g_hadPosition = false;
      g_tp1Hit      = false;

      if(g_attempts >= MaxAttempts)
      {
         g_doneForDay = true;
         Print("Max attempts reached (", MaxAttempts, "). Done for today.");
         return;
      }

      g_waitForReset = true;
      Print("Position closed. Attempt ", g_attempts, "/", MaxAttempts,
            ". Waiting for price to return to zone.");
   }
   if(hasPos)
      g_hadPosition = true;

   //--- Manage open positions
   if(hasPos)
   {
      ManagePositions();
      return;
   }

   //--- Once per M1 bar
   datetime curBarTime = iTime(_Symbol, PERIOD_M1, 0);
   if(curBarTime == g_lastBarTime) return;
   g_lastBarTime = curBarTime;

   //--- Wait for reset: price must close back inside zone
   if(g_waitForReset)
   {
      double close1 = iClose(_Symbol, PERIOD_M1, 1);
      if(close1 >= g_zoneLow && close1 <= g_zoneHigh)
      {
         g_waitForReset = false;
         Print("Reset complete. Price back in zone. Ready for breakout.");
      }
      return;
   }

   //--- Check breakout
   if(g_attempts < MaxAttempts)
      CheckBreakout();
}

//+------------------------------------------------------------------+
void BuildZone()
{
   g_zoneHigh = -DBL_MAX;
   g_zoneLow  = DBL_MAX;

   for(int i = 0; i < ZoneBars; i++)
   {
      datetime barTime = g_today + ZoneHour * 3600 + (ZoneMinute + i) * 60;
      int shift = iBarShift(_Symbol, PERIOD_M1, barTime);
      if(shift < 0) return;

      double h = iHigh(_Symbol, PERIOD_M1, shift);
      double l = iLow(_Symbol, PERIOD_M1, shift);
      if(h <= 0 || l <= 0) return;

      if(h > g_zoneHigh) g_zoneHigh = h;
      if(l < g_zoneLow)  g_zoneLow  = l;
   }

   double zoneWidth = (g_zoneHigh - g_zoneLow) / _Point;

   if(g_zoneHigh <= g_zoneLow || zoneWidth < MinZoneWidth)
   {
      Print("Zone too narrow (", zoneWidth, " pts). Skipping today.");
      g_doneForDay = true;
      return;
   }

   g_zoneReady = true;
   Print("Zone: High=", g_zoneHigh, " Low=", g_zoneLow, " Width=", zoneWidth, " pts");
}

//+------------------------------------------------------------------+
void CheckBreakout()
{
   double close1 = iClose(_Symbol, PERIOD_M1, 1);
   double open1  = iOpen(_Symbol, PERIOD_M1, 1);
   double high1  = iHigh(_Symbol, PERIOD_M1, 1);
   double low1   = iLow(_Symbol, PERIOD_M1, 1);

   if(close1 <= 0 || open1 <= 0) return;

   double buffer  = ZoneBufferPts * _Point;
   double bodyPct = 0;
   double range1  = high1 - low1;
   if(range1 > 0) bodyPct = MathAbs(close1 - open1) / range1;

   //--- BUY breakout: close above zone+buffer, with decent body
   if(close1 > g_zoneHigh + buffer && open1 <= g_zoneHigh + buffer && bodyPct > 0.3)
   {
      if(g_lockedDir == 0 || g_lockedDir == 1)  // no lock or buy locked
      {
         g_lockedDir = 1;
         OpenBuy();
         return;
      }
   }

   //--- SELL breakdown: close below zone-buffer, with decent body
   if(close1 < g_zoneLow - buffer && open1 >= g_zoneLow - buffer && bodyPct > 0.3)
   {
      if(g_lockedDir == 0 || g_lockedDir == -1)  // no lock or sell locked
      {
         g_lockedDir = -1;
         OpenSell();
         return;
      }
   }
}

//+------------------------------------------------------------------+
void OpenBuy()
{
   double ask    = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double sl     = g_zoneLow;
   double slDist = ask - sl;

   double maxSL = MaxSLPoints * _Point;
   if(slDist > maxSL)
   {
      sl = ask - maxSL;
      slDist = maxSL;
   }
   if(slDist <= 0) return;

   double tp1 = ask + TP1Points * _Point;
   double lot = CalcLotSize(slDist);
   if(lot <= 0) return;

   if(trade.Buy(lot, _Symbol, ask, sl, tp1, "GT Buy #" + IntegerToString(g_attempts+1)))
   {
      g_attempts++;
      g_slPrice     = sl;
      g_tp1Hit      = false;
      g_hadPosition = true;
      Print("BUY #", g_attempts, " Lot=", lot, " Entry=", ask, " SL=", sl, " TP=", tp1);
   }
}

//+------------------------------------------------------------------+
void OpenSell()
{
   double bid    = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double sl     = g_zoneHigh;
   double slDist = sl - bid;

   double maxSL = MaxSLPoints * _Point;
   if(slDist > maxSL)
   {
      sl = bid + maxSL;
      slDist = maxSL;
   }
   if(slDist <= 0) return;

   double tp1 = bid - TP1Points * _Point;
   double lot = CalcLotSize(slDist);
   if(lot <= 0) return;

   if(trade.Sell(lot, _Symbol, bid, sl, tp1, "GT Sell #" + IntegerToString(g_attempts+1)))
   {
      g_attempts++;
      g_slPrice     = sl;
      g_tp1Hit      = false;
      g_hadPosition = true;
      Print("SELL #", g_attempts, " Lot=", lot, " Entry=", bid, " SL=", sl, " TP=", tp1);
   }
}

//+------------------------------------------------------------------+
double CalcLotSize(double slDistance)
{
   if(slDistance <= 0) return 0;

   double balance  = AccountInfoDouble(ACCOUNT_BALANCE);
   double riskAmt  = balance * RiskPercent / 100.0;
   double tickVal  = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);

   if(tickVal <= 0 || tickSize <= 0) return 0;

   double lot = riskAmt / ((slDistance / tickSize) * tickVal);

   double minLot  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxLot  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);

   lot = MathFloor(lot / lotStep) * lotStep;
   lot = NormalizeDouble(lot, 2);

   if(lot < minLot) lot = minLot;
   if(lot > maxLot) lot = maxLot;

   return lot;
}

//+------------------------------------------------------------------+
void ManagePositions()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(PositionGetSymbol(i) != _Symbol) continue;
      if(PositionGetInteger(POSITION_MAGIC) != MagicNumber) continue;

      ulong  ticket    = PositionGetInteger(POSITION_TICKET);
      double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
      double volume    = PositionGetDouble(POSITION_VOLUME);
      long   posType   = PositionGetInteger(POSITION_TYPE);
      double curSL     = PositionGetDouble(POSITION_SL);
      double curTP     = PositionGetDouble(POSITION_TP);

      double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);

      //--- TP1 partial close (80%)
      if(!g_tp1Hit)
      {
         bool tp1Reached = false;
         if(posType == POSITION_TYPE_BUY  && bid >= openPrice + TP1Points * _Point)
            tp1Reached = true;
         if(posType == POSITION_TYPE_SELL && ask <= openPrice - TP1Points * _Point)
            tp1Reached = true;

         if(tp1Reached)
         {
            double closeLot = volume * TP1ClosePct / 100.0;
            double lotStep  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
            double minLot   = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
            closeLot = MathFloor(closeLot / lotStep) * lotStep;
            closeLot = NormalizeDouble(closeLot, 2);

            double remainLot = NormalizeDouble(volume - closeLot, 2);

            if(closeLot >= minLot && remainLot >= minLot)
            {
               trade.PositionClosePartial(ticket, closeLot);
               g_tp1Hit = true;

               // Move SL to breakeven + 1 point, TP to TrailRR
               double slDist = MathAbs(openPrice - g_slPrice);
               if(posType == POSITION_TYPE_BUY)
               {
                  double newTP = openPrice + TrailRR * slDist;
                  trade.PositionModify(ticket, openPrice + _Point, newTP);
               }
               else
               {
                  double newTP = openPrice - TrailRR * slDist;
                  trade.PositionModify(ticket, openPrice - _Point, newTP);
               }
               Print("TP1 hit! Closed ", DoubleToString(closeLot,2),
                     " lots. Trailing rest to ", TrailRR, "R");
            }
            else
            {
               // Can't split, close entire position
               trade.PositionClose(ticket);
               g_tp1Hit = true;
               g_doneForDay = true;
               Print("TP1 hit! Closed full position (can't split).");
            }
         }
      }
      else
      {
         //--- After TP1: trail SL to lock profits
         double trailDist = TP1Points * _Point * 0.5;
         if(posType == POSITION_TYPE_BUY)
         {
            double newSL = bid - trailDist;
            if(newSL > curSL && newSL > openPrice)
               trade.PositionModify(ticket, newSL, curTP);
         }
         else
         {
            double newSL = ask + trailDist;
            if((newSL < curSL || curSL == 0) && newSL < openPrice)
               trade.PositionModify(ticket, newSL, curTP);
         }
      }
   }
}

//+------------------------------------------------------------------+
bool HasPosition()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(PositionGetSymbol(i) != _Symbol) continue;
      if(PositionGetInteger(POSITION_MAGIC) != MagicNumber) continue;
      return true;
   }
   return false;
}

//+------------------------------------------------------------------+
void CloseAll()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(PositionGetSymbol(i) != _Symbol) continue;
      if(PositionGetInteger(POSITION_MAGIC) != MagicNumber) continue;
      trade.PositionClose(PositionGetInteger(POSITION_TICKET));
   }
}
//+------------------------------------------------------------------+
