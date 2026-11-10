//+------------------------------------------------------------------+
//|                                    DoubleTrapStrategy.mq5        |
//|   Double Top/Bottom Trap Strategy for XAUUSD                     |
//|   Trades false breakouts of double tops/bottoms at 15m S/R zones |
//+------------------------------------------------------------------+

#property version   "1.00"
#property strict

#include <Trade\Trade.mqh>

//=== INPUTS =========================================================
//--- S/R Zone Detection (M15)
input int      SR_Lookback       = 120;      // Bars to scan for S/R zones
input int      SR_MinTouches     = 3;        // Min touches to confirm zone
input double   SR_ZoneWidth_Pts  = 300;      // Zone width in points (each side of pivot)
input int      SR_MaxZones       = 6;        // Max zones to track

//--- Double Top/Bottom Detection
input int      Pattern_Lookback  = 40;       // Bars to scan for pattern peaks/troughs
input double   Peak_Tolerance_Pts= 200;      // Max pts difference between two peaks/troughs
input int      Min_Bars_Between  = 5;        // Min bars between peak1 and peak2
input int      Max_Bars_Between  = 30;       // Max bars between peak1 and peak2
input int      Neckline_Depth    = 2;        // Bars around pivot for swing detection

//--- Trap (False Breakout) Detection
input double   Trap_MinPenetration_Pts = 30; // Min points price must exceed the pattern
input double   Trap_MaxPenetration_Pts = 500;// Max points (too far = real breakout)
input int      Trap_Confirm_Bars = 2;        // Bars to confirm trap (close back inside)

//--- Session Filter (Server Time)
input int      LDN_Start         = 10;       // London session start hour
input int      LDN_End           = 13;       // London session end hour
input int      NY_Start          = 15;       // NY session start hour
input int      NY_End            = 21;       // NY session end hour
input bool     SkipTuesday       = true;     // Skip Tuesdays

//--- Trade Management
input double   LotSize           = 0.10;     // Lot size
input double   RiskReward        = 2.5;      // Risk:Reward ratio
input double   MinSL_Points      = 150;      // Min SL distance in points
input double   MaxSL_Points      = 800;      // Max SL distance in points
input double   BE_Trigger_RR     = 1.0;      // Move SL to BE at this R multiple
input double   BE_Lock_Points    = 20;       // Points of profit to lock at BE
input double   Trail_Trigger_RR  = 2.0;      // Start trailing at this R multiple
input double   Trail_Step_Pts    = 80;       // Trailing step in points
input int      MaxTradesPerDay   = 3;        // Max trades per day
input int      MagicNumber       = 889001;   // Magic number
input int      MaxSpreadPts      = 50;       // Max spread in points
input int      CooldownBars      = 4;        // Bars to wait after losing trade

//--- ATR for dynamic SL
input int      ATR_Period        = 14;       // ATR period
input double   ATR_SL_Multi     = 1.5;      // ATR multiplier for SL

//=== STRUCTURES =====================================================
struct SRZone
{
   double   level;        // Center price level
   double   upper;        // Zone upper boundary
   double   lower;        // Zone lower boundary
   int      touches;      // Number of touches
   bool     isResistance; // true = resistance, false = support
   datetime lastTouch;    // Last time price touched zone
};

struct PatternInfo
{
   bool     valid;
   bool     isDoubleTop;  // true = double top, false = double bottom
   double   peak1;        // First peak/trough price
   double   peak2;        // Second peak/trough price
   int      peak1Bar;     // Bar index of first peak/trough
   int      peak2Bar;     // Bar index of second peak/trough
   double   neckline;     // Neckline level
   double   patternLevel; // The extreme level (avg of peaks)
};

struct TrapSignal
{
   bool     triggered;
   int      direction;    // 1 = buy (DB trap), -1 = sell (DT trap)
   double   entryPrice;
   double   sl;
   double   tp;
   double   patternLevel;
   double   neckline;
};

//=== GLOBALS ========================================================
CTrade   trade;
int      hATR;
SRZone   gZones[];
datetime gDay;
int      gTradesToday;
datetime gLastLossTime;
double   gLastEntrySL;

//+------------------------------------------------------------------+
int OnInit()
{
   trade.SetExpertMagicNumber(MagicNumber);
   trade.SetDeviationInPoints(30);

   hATR = iATR(_Symbol, PERIOD_M15, ATR_Period);
   if(hATR == INVALID_HANDLE)
   {
      Print("Failed to create ATR handle");
      return INIT_FAILED;
   }

   ArrayResize(gZones, 0);
   gDay = 0;
   gTradesToday = 0;
   gLastLossTime = 0;
   gLastEntrySL = 0;

   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   if(hATR != INVALID_HANDLE) IndicatorRelease(hATR);
}

//+------------------------------------------------------------------+
void OnTick()
{
   // New day reset
   datetime today = iTime(_Symbol, PERIOD_D1, 0);
   if(today != gDay)
   {
      gDay = today;
      gTradesToday = 0;
   }

   // Manage existing positions
   ManagePositions();

   // Guards
   if(gTradesToday >= MaxTradesPerDay) return;
   if(!IsNewBar()) return;
   if(!InKillzone()) return;
   if((int)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD) > MaxSpreadPts) return;
   if(HasOpenPosition()) return;

   // Cooldown after loss
   if(gLastLossTime > 0)
   {
      datetime barTime = iTime(_Symbol, PERIOD_CURRENT, 0);
      if(barTime < gLastLossTime + CooldownBars * PeriodSeconds(PERIOD_CURRENT))
         return;
   }

   // Get ATR
   double atr[1];
   if(CopyBuffer(hATR, 0, 1, 1, atr) < 1) return;
   double curATR = atr[0];
   if(curATR < _Point) return;

   // Step 1: Detect M15 S/R zones
   DetectSRZones();

   // Step 2: Detect double top/bottom patterns near zones
   PatternInfo pattern;
   pattern.valid = false;
   DetectDoublePattern(pattern);

   if(!pattern.valid) return;

   // Step 3: Check if pattern is near a strong S/R zone
   if(!PatternNearZone(pattern)) return;

   // Step 4: Check for trap (false breakout + rejection)
   TrapSignal trap;
   trap.triggered = false;
   DetectTrap(pattern, curATR, trap);

   if(!trap.triggered) return;

   // Step 5: Validate SL distance
   double slDist = MathAbs(trap.entryPrice - trap.sl) / _Point;
   if(slDist < MinSL_Points || slDist > MaxSL_Points) return;

   // Step 6: Execute trade
   ExecuteTrade(trap, slDist);
}

//+------------------------------------------------------------------+
//| Detect Support/Resistance Zones on M15                           |
//+------------------------------------------------------------------+
void DetectSRZones()
{
   ArrayResize(gZones, 0);

   double highs[], lows[], closes[];
   ArraySetAsSeries(highs, true);
   ArraySetAsSeries(lows, true);
   ArraySetAsSeries(closes, true);

   if(CopyHigh(_Symbol, PERIOD_M15, 0, SR_Lookback, highs) < SR_Lookback) return;
   if(CopyLow(_Symbol, PERIOD_M15, 0, SR_Lookback, lows) < SR_Lookback) return;
   if(CopyClose(_Symbol, PERIOD_M15, 0, SR_Lookback, closes) < SR_Lookback) return;

   double zoneWidth = SR_ZoneWidth_Pts * _Point;

   // Find swing highs and lows as candidate levels
   double candidates[];
   bool   candIsHigh[];
   int    candCount = 0;

   for(int i = 3; i < SR_Lookback - 3; i++)
   {
      // Swing high
      if(highs[i] > highs[i-1] && highs[i] > highs[i-2] &&
         highs[i] > highs[i+1] && highs[i] > highs[i+2])
      {
         ArrayResize(candidates, candCount + 1);
         ArrayResize(candIsHigh, candCount + 1);
         candidates[candCount] = highs[i];
         candIsHigh[candCount] = true;
         candCount++;
      }
      // Swing low
      if(lows[i] < lows[i-1] && lows[i] < lows[i-2] &&
         lows[i] < lows[i+1] && lows[i] < lows[i+2])
      {
         ArrayResize(candidates, candCount + 1);
         ArrayResize(candIsHigh, candCount + 1);
         candidates[candCount] = lows[i];
         candIsHigh[candCount] = false;
         candCount++;
      }
   }

   // Cluster nearby levels and count touches
   bool used[];
   ArrayResize(used, candCount);
   ArrayInitialize(used, false);

   for(int i = 0; i < candCount; i++)
   {
      if(used[i]) continue;

      double level = candidates[i];
      int touches = 1;
      double sumLevel = level;
      used[i] = true;

      for(int j = i + 1; j < candCount; j++)
      {
         if(used[j]) continue;
         if(MathAbs(candidates[j] - level) <= zoneWidth)
         {
            sumLevel += candidates[j];
            touches++;
            used[j] = true;
         }
      }

      if(touches >= SR_MinTouches)
      {
         double avgLevel = sumLevel / touches;
         double curPrice = closes[0];

         int size = ArraySize(gZones);
         if(size >= SR_MaxZones) break;

         ArrayResize(gZones, size + 1);
         gZones[size].level = avgLevel;
         gZones[size].upper = avgLevel + zoneWidth;
         gZones[size].lower = avgLevel - zoneWidth;
         gZones[size].touches = touches;
         gZones[size].isResistance = (curPrice < avgLevel);
         gZones[size].lastTouch = iTime(_Symbol, PERIOD_M15, 0);
      }
   }
}

//+------------------------------------------------------------------+
//| Detect Double Top or Double Bottom Pattern                       |
//+------------------------------------------------------------------+
void DetectDoublePattern(PatternInfo &pattern)
{
   double highs[], lows[];
   ArraySetAsSeries(highs, true);
   ArraySetAsSeries(lows, true);

   if(CopyHigh(_Symbol, PERIOD_M15, 0, Pattern_Lookback, highs) < Pattern_Lookback) return;
   if(CopyLow(_Symbol, PERIOD_M15, 0, Pattern_Lookback, lows) < Pattern_Lookback) return;

   double tolerance = Peak_Tolerance_Pts * _Point;
   int depth = Neckline_Depth;

   // --- Check for Double Top ---
   // Find swing highs
   double swingHighs[];
   int    swingHighBars[];
   int    shCount = 0;

   for(int i = depth; i < Pattern_Lookback - depth; i++)
   {
      bool isSwingHigh = true;
      for(int d = 1; d <= depth; d++)
      {
         if(highs[i] <= highs[i-d] || highs[i] <= highs[i+d])
         {
            isSwingHigh = false;
            break;
         }
      }
      if(isSwingHigh)
      {
         ArrayResize(swingHighs, shCount + 1);
         ArrayResize(swingHighBars, shCount + 1);
         swingHighs[shCount] = highs[i];
         swingHighBars[shCount] = i;
         shCount++;
      }
   }

   // Look for two swing highs at similar level
   for(int i = 0; i < shCount; i++)
   {
      for(int j = i + 1; j < shCount; j++)
      {
         int barDiff = MathAbs(swingHighBars[j] - swingHighBars[i]);
         if(barDiff < Min_Bars_Between || barDiff > Max_Bars_Between) continue;
         if(MathAbs(swingHighs[i] - swingHighs[j]) > tolerance) continue;

         // Found double top - find neckline (lowest low between peaks)
         double neckline = DBL_MAX;
         int startBar = swingHighBars[i];
         int endBar = swingHighBars[j];
         if(startBar > endBar) { int tmp = startBar; startBar = endBar; endBar = tmp; }

         for(int k = startBar; k <= endBar; k++)
            if(lows[k] < neckline) neckline = lows[k];

         // Most recent peak should be peak2 (closer to bar 0)
         pattern.valid = true;
         pattern.isDoubleTop = true;
         pattern.peak1 = swingHighs[j]; // older (further from 0)
         pattern.peak2 = swingHighs[i]; // newer (closer to 0)
         pattern.peak1Bar = swingHighBars[j];
         pattern.peak2Bar = swingHighBars[i];
         pattern.neckline = neckline;
         pattern.patternLevel = (pattern.peak1 + pattern.peak2) / 2.0;
         return; // Take first valid pattern found
      }
   }

   // --- Check for Double Bottom ---
   double swingLows[];
   int    swingLowBars[];
   int    slCount = 0;

   for(int i = depth; i < Pattern_Lookback - depth; i++)
   {
      bool isSwingLow = true;
      for(int d = 1; d <= depth; d++)
      {
         if(lows[i] >= lows[i-d] || lows[i] >= lows[i+d])
         {
            isSwingLow = false;
            break;
         }
      }
      if(isSwingLow)
      {
         ArrayResize(swingLows, slCount + 1);
         ArrayResize(swingLowBars, slCount + 1);
         swingLows[slCount] = lows[i];
         swingLowBars[slCount] = i;
         slCount++;
      }
   }

   for(int i = 0; i < slCount; i++)
   {
      for(int j = i + 1; j < slCount; j++)
      {
         int barDiff = MathAbs(swingLowBars[j] - swingLowBars[i]);
         if(barDiff < Min_Bars_Between || barDiff > Max_Bars_Between) continue;
         if(MathAbs(swingLows[i] - swingLows[j]) > tolerance) continue;

         // Found double bottom - find neckline (highest high between troughs)
         double neckline = 0;
         int startBar = swingLowBars[i];
         int endBar = swingLowBars[j];
         if(startBar > endBar) { int tmp = startBar; startBar = endBar; endBar = tmp; }

         for(int k = startBar; k <= endBar; k++)
            if(highs[k] > neckline) neckline = highs[k];

         pattern.valid = true;
         pattern.isDoubleTop = false;
         pattern.peak1 = swingLows[j];
         pattern.peak2 = swingLows[i];
         pattern.peak1Bar = swingLowBars[j];
         pattern.peak2Bar = swingLowBars[i];
         pattern.neckline = neckline;
         pattern.patternLevel = (pattern.peak1 + pattern.peak2) / 2.0;
         return;
      }
   }
}

//+------------------------------------------------------------------+
//| Check if pattern is near a strong S/R zone                       |
//+------------------------------------------------------------------+
bool PatternNearZone(const PatternInfo &pattern)
{
   double zoneProximity = SR_ZoneWidth_Pts * 2.0 * _Point; // Allow 2x zone width proximity

   for(int i = 0; i < ArraySize(gZones); i++)
   {
      double dist = MathAbs(pattern.patternLevel - gZones[i].level);
      if(dist <= zoneProximity)
      {
         // Double top should be near resistance
         if(pattern.isDoubleTop && gZones[i].isResistance)
            return true;
         // Double bottom should be near support
         if(!pattern.isDoubleTop && !gZones[i].isResistance)
            return true;
      }
   }
   return false;
}

//+------------------------------------------------------------------+
//| Detect Trap (False Breakout + Rejection)                         |
//+------------------------------------------------------------------+
void DetectTrap(const PatternInfo &pattern, double curATR, TrapSignal &trap)
{
   double highs[], lows[], closes[], opens[];
   ArraySetAsSeries(highs, true);
   ArraySetAsSeries(lows, true);
   ArraySetAsSeries(closes, true);
   ArraySetAsSeries(opens, true);

   int barsNeeded = Trap_Confirm_Bars + 3;
   if(CopyHigh(_Symbol, PERIOD_M15, 0, barsNeeded, highs) < barsNeeded) return;
   if(CopyLow(_Symbol, PERIOD_M15, 0, barsNeeded, lows) < barsNeeded) return;
   if(CopyClose(_Symbol, PERIOD_M15, 0, barsNeeded, closes) < barsNeeded) return;
   if(CopyOpen(_Symbol, PERIOD_M15, 0, barsNeeded, opens) < barsNeeded) return;

   double minPen = Trap_MinPenetration_Pts * _Point;
   double maxPen = Trap_MaxPenetration_Pts * _Point;

   if(pattern.isDoubleTop)
   {
      // DOUBLE TOP TRAP → SELL signal
      // Look for: price spiked above pattern level (trap), then closed back below
      double patLevel = pattern.patternLevel;

      // Check recent bars for a false breakout above
      for(int i = 1; i <= Trap_Confirm_Bars; i++)
      {
         double penetration = highs[i] - patLevel;

         // Wick went above the pattern level (stop hunt)
         if(penetration >= minPen && penetration <= maxPen)
         {
            // But candle closed BACK BELOW the pattern level (trap confirmed)
            if(closes[i] < patLevel)
            {
               // Additional: bearish rejection candle (upper wick > body)
               double body = MathAbs(closes[i] - opens[i]);
               double upperWick = highs[i] - MathMax(opens[i], closes[i]);

               if(upperWick > body * 0.5) // Upper wick at least 50% of body
               {
                  // Check bar 1 (most recent closed bar) confirms direction
                  if(closes[1] < opens[1] || closes[1] < patLevel)
                  {
                     double sl = highs[i] + ATR_SL_Multi * curATR * 0.3; // Above trap wick
                     double slDist = sl - closes[1];
                     double tp = closes[1] - slDist * RiskReward;

                     // Alternative TP: neckline if closer for partial
                     if(pattern.neckline > tp)
                        tp = MathMin(pattern.neckline, closes[1] - slDist * RiskReward);

                     trap.triggered = true;
                     trap.direction = -1;
                     trap.entryPrice = closes[1];
                     trap.sl = sl;
                     trap.tp = tp;
                     trap.patternLevel = patLevel;
                     trap.neckline = pattern.neckline;
                     return;
                  }
               }
            }
         }
      }
   }
   else
   {
      // DOUBLE BOTTOM TRAP → BUY signal
      double patLevel = pattern.patternLevel;

      for(int i = 1; i <= Trap_Confirm_Bars; i++)
      {
         double penetration = patLevel - lows[i];

         // Wick went below the pattern level (stop hunt)
         if(penetration >= minPen && penetration <= maxPen)
         {
            // Candle closed BACK ABOVE the pattern level (trap confirmed)
            if(closes[i] > patLevel)
            {
               // Bullish rejection candle (lower wick > body)
               double body = MathAbs(closes[i] - opens[i]);
               double lowerWick = MathMin(opens[i], closes[i]) - lows[i];

               if(lowerWick > body * 0.5)
               {
                  if(closes[1] > opens[1] || closes[1] > patLevel)
                  {
                     double sl = lows[i] - ATR_SL_Multi * curATR * 0.3;
                     double slDist = closes[1] - sl;
                     double tp = closes[1] + slDist * RiskReward;

                     if(pattern.neckline < tp)
                        tp = MathMax(pattern.neckline, closes[1] + slDist * RiskReward);

                     trap.triggered = true;
                     trap.direction = 1;
                     trap.entryPrice = closes[1];
                     trap.sl = sl;
                     trap.tp = tp;
                     trap.patternLevel = patLevel;
                     trap.neckline = pattern.neckline;
                     return;
                  }
               }
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Execute Trade                                                    |
//+------------------------------------------------------------------+
void ExecuteTrade(const TrapSignal &trap, double slDist)
{
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);

   if(trap.direction == 1) // BUY
   {
      double sl = NormalizeDouble(trap.sl, _Digits);
      double tp = NormalizeDouble(trap.tp, _Digits);

      if(trade.Buy(LotSize, _Symbol, ask, sl, tp, "DT_Trap_BUY"))
      {
         gTradesToday++;
         gLastEntrySL = MathAbs(ask - sl);
         Print("DOUBLE BOTTOM TRAP BUY @ ", ask, " SL=", sl, " TP=", tp);
      }
   }
   else // SELL
   {
      double sl = NormalizeDouble(trap.sl, _Digits);
      double tp = NormalizeDouble(trap.tp, _Digits);

      if(trade.Sell(LotSize, _Symbol, bid, sl, tp, "DT_Trap_SELL"))
      {
         gTradesToday++;
         gLastEntrySL = MathAbs(bid - sl);
         Print("DOUBLE TOP TRAP SELL @ ", bid, " SL=", sl, " TP=", tp);
      }
   }
}

//+------------------------------------------------------------------+
//| Manage open positions: Breakeven + Trailing                      |
//+------------------------------------------------------------------+
void ManagePositions()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket)) continue;
      if(PositionGetInteger(POSITION_MAGIC) != MagicNumber) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;

      double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
      double curSL     = PositionGetDouble(POSITION_SL);
      double curTP     = PositionGetDouble(POSITION_TP);
      long   type      = PositionGetInteger(POSITION_TYPE);

      if(gLastEntrySL <= 0) continue;
      double riskDist = gLastEntrySL;

      if(type == POSITION_TYPE_BUY)
      {
         double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
         double profit = bid - openPrice;
         double rMultiple = profit / riskDist;

         // Breakeven
         if(rMultiple >= BE_Trigger_RR && curSL < openPrice + BE_Lock_Points * _Point)
         {
            double newSL = openPrice + BE_Lock_Points * _Point;
            trade.PositionModify(ticket, NormalizeDouble(newSL, _Digits), curTP);
         }
         // Trailing
         else if(rMultiple >= Trail_Trigger_RR)
         {
            double trailSL = bid - Trail_Step_Pts * _Point;
            if(trailSL > curSL + _Point)
               trade.PositionModify(ticket, NormalizeDouble(trailSL, _Digits), curTP);
         }
      }
      else // SELL
      {
         double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
         double profit = openPrice - ask;
         double rMultiple = profit / riskDist;

         // Breakeven
         if(rMultiple >= BE_Trigger_RR && (curSL > openPrice - BE_Lock_Points * _Point || curSL == 0))
         {
            double newSL = openPrice - BE_Lock_Points * _Point;
            trade.PositionModify(ticket, NormalizeDouble(newSL, _Digits), curTP);
         }
         // Trailing
         else if(rMultiple >= Trail_Trigger_RR)
         {
            double trailSL = ask + Trail_Step_Pts * _Point;
            if(trailSL < curSL - _Point || curSL == 0)
               trade.PositionModify(ticket, NormalizeDouble(trailSL, _Digits), curTP);
         }
      }
   }

   // Track last loss for cooldown
   CheckLastTradeLoss();
}

//+------------------------------------------------------------------+
//| Check if last closed trade was a loss                            |
//+------------------------------------------------------------------+
void CheckLastTradeLoss()
{
   if(!HistorySelect(iTime(_Symbol, PERIOD_D1, 0), TimeCurrent())) return;

   int total = HistoryDealsTotal();
   if(total == 0) return;

   ulong lastDeal = HistoryDealGetTicket(total - 1);
   if(lastDeal == 0) return;

   if(HistoryDealGetInteger(lastDeal, DEAL_MAGIC) != MagicNumber) return;
   if(HistoryDealGetInteger(lastDeal, DEAL_ENTRY) != DEAL_ENTRY_OUT) return;

   double profit = HistoryDealGetDouble(lastDeal, DEAL_PROFIT);
   if(profit < 0)
      gLastLossTime = (datetime)HistoryDealGetInteger(lastDeal, DEAL_TIME);
}

//+------------------------------------------------------------------+
//| Check if in trading session                                      |
//+------------------------------------------------------------------+
bool InKillzone()
{
   MqlDateTime dt;
   TimeCurrent(dt);

   if(SkipTuesday && dt.day_of_week == 2) return false;

   int hour = dt.hour;
   if(hour >= LDN_Start && hour <= LDN_End) return true;
   if(hour >= NY_Start  && hour <= NY_End)  return true;

   return false;
}

//+------------------------------------------------------------------+
//| New bar detection                                                |
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
//| Check for open position                                          |
//+------------------------------------------------------------------+
bool HasOpenPosition()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket)) continue;
      if(PositionGetInteger(POSITION_MAGIC) == MagicNumber &&
         PositionGetString(POSITION_SYMBOL) == _Symbol)
         return true;
   }
   return false;
}
//+------------------------------------------------------------------+
