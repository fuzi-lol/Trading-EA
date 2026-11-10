//+------------------------------------------------------------------+
//|                                    LiquiditySweepScalper.mq5     |
//|           M1 Liquidity Sweep + S/R + Pattern Scalper             |
//+------------------------------------------------------------------+
//| LOGIC:                                                           |
//| 1. Build S/R from M15 swing highs/lows                          |
//| 2. Detect liquidity sweep: M1 wick pierces S/R then closes back |
//| 3. Confirm with pattern: engulfing, pin bar, or inside bar break|
//| 4. Enter on next candle, SL beyond sweep wick, TP at next S/R   |
//+------------------------------------------------------------------+
#property copyright "Liquidity Sweep Scalper"
#property version   "1.00"
#property strict

#include <Trade\Trade.mqh>

//--- Inputs
input group "=== S/R Detection ==="
input int     SR_SwingBars     = 5;         // M15 swing lookback (bars each side)
input int     SR_MaxLevels     = 10;        // Max S/R levels to track
input int     SR_MergePoints   = 200;       // Merge S/R within this distance (points)
input int     SR_MinAge        = 3;         // Min bars old for S/R to be valid

input group "=== Liquidity Sweep ==="
input int     SweepMinPts      = 20;        // Min sweep beyond S/R (points)
input int     SweepMaxPts      = 300;       // Max sweep beyond S/R (points)
input int     MaxDistToSR      = 50;        // Max candle open distance from S/R (points)

input group "=== Risk Management ==="
input bool    UseFixedLot      = false;     // Use fixed lot size (ignore risk %)
input double  FixedLot         = 0.10;      // Fixed lot size
input double  RiskPercent      = 1.0;       // Risk % per trade (if not fixed lot)
input int     MaxSLPoints      = 400;       // Max SL in points
input int     MinSLPoints      = 50;        // Min SL in points
input double  MinRR            = 1.5;       // Minimum R:R to take trade
input bool    UseTrailing      = true;      // Use trailing stop after 1R
input int     TrailPoints      = 150;       // Trailing stop distance (points)

input group "=== Session Filter ==="
input int     LondonStart      = 8;         // London session start (server)
input int     LondonEnd        = 12;        // London session end
input int     NYStart          = 14;        // NY session start (server)
input int     NYEnd            = 20;        // NY session end

input group "=== Prop Firm Safety ==="
input double  DailyLossLimit   = 3.0;       // Daily loss limit % (stop trading)
input double  MaxDrawdownPct   = 10.0;      // Max account DD % (stop all)
input double  ProfitTargetPct  = 0.0;       // Profit target % (0=disabled)
input bool    UseEquityGuard   = false;     // Enable prop firm protection

input group "=== General ==="
input int     MaxTradesPerDay  = 5;         // Max trades per day
input int     CooldownBars     = 3;         // Bars to wait after a trade
input int     MagicNumber      = 777100;    // Magic number

CTrade trade;

//--- S/R levels
struct SRLevel
{
   double price;
   int    touches;
   bool   isSupport;     // true=support, false=resistance
   datetime lastTouch;
};

SRLevel g_levels[];
int     g_levelCount = 0;

//--- Trade state
datetime g_lastTradeBar = 0;
int      g_barsSinceTrade = 999;
datetime g_lastDay = 0;
int      g_dailyTrades = 0;
bool     g_inTrade = false;
double   g_tradeEntry = 0;
double   g_tradeSL = 0;
bool     g_trailingActive = false;

//--- Prop firm state
double   g_initialBalance  = 0;
double   g_dayStartBalance = 0;
bool     g_dailyStopped    = false;
bool     g_ddStopped       = false;
bool     g_targetReached   = false;

//--- Bar tracking
datetime g_lastM15Bar = 0;
datetime g_lastM1Bar = 0;

//--- Sweep detection
bool     g_sweepDetected = false;
int      g_sweepDir = 0;       // 1=sweep below support (buy), -1=sweep above resistance (sell)
double   g_sweepSR = 0;        // the S/R level that was swept
double   g_sweepWick = 0;      // extreme of the sweep wick
datetime g_sweepTime = 0;

//+------------------------------------------------------------------+
int OnInit()
{
   trade.SetExpertMagicNumber(MagicNumber);
   trade.SetTypeFillingBySymbol(_Symbol);
   ArrayResize(g_levels, 0);
   g_levelCount = 0;
   g_initialBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   g_dayStartBalance = g_initialBalance;
   BuildSRLevels();
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
void OnTick()
{
   MqlDateTime dt;
   TimeCurrent(dt);
   datetime today = TimeCurrent() - dt.hour*3600 - dt.min*60 - dt.sec;

   if(today != g_lastDay)
   {
      g_lastDay = today;
      g_dailyTrades = 0;
      g_dailyStopped = false;
      g_dayStartBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   }

   //--- Prop firm safety checks
   if(UseEquityGuard)
   {
      double equity = AccountInfoDouble(ACCOUNT_EQUITY);
      double dailyPL = equity - g_dayStartBalance;
      if(-dailyPL / g_dayStartBalance * 100.0 >= DailyLossLimit)
      {
         if(!g_dailyStopped) { g_dailyStopped = true; Print("DAILY LOSS LIMIT. Stopped."); }
         return;
      }
      if((g_initialBalance - equity) / g_initialBalance * 100.0 >= MaxDrawdownPct)
      {
         if(!g_ddStopped) { g_ddStopped = true; Print("MAX DD REACHED. ALL STOPPED."); }
         return;
      }
      if(ProfitTargetPct > 0 && (AccountInfoDouble(ACCOUNT_BALANCE) - g_initialBalance) / g_initialBalance * 100.0 >= ProfitTargetPct)
      {
         if(!g_targetReached) { g_targetReached = true; Print("PROFIT TARGET REACHED!"); }
         return;
      }
   }
   if(g_dailyStopped || g_ddStopped || g_targetReached) return;

   //--- Manage open position
   if(g_inTrade)
   {
      if(!HasPosition())
      {
         g_inTrade = false;
         g_trailingActive = false;
         g_barsSinceTrade = 0;
      }
      else if(UseTrailing)
      {
         ManageTrailing();
      }
      return;
   }

   //--- Update M15 S/R
   datetime curM15 = iTime(_Symbol, PERIOD_M15, 0);
   if(curM15 != g_lastM15Bar)
   {
      g_lastM15Bar = curM15;
      BuildSRLevels();
   }

   //--- Process M1 bars
   datetime curM1 = iTime(_Symbol, PERIOD_M1, 0);
   if(curM1 != g_lastM1Bar)
   {
      g_lastM1Bar = curM1;
      g_barsSinceTrade++;

      if(g_dailyTrades >= MaxTradesPerDay) return;
      if(!InSession(dt.hour)) return;
      if(g_barsSinceTrade < CooldownBars) return;

      //--- Step 1: Detect sweep on last closed M1 candle
      DetectSweep();

      //--- Step 2: If sweep was detected previously, look for confirmation pattern
      if(g_sweepDetected)
         CheckConfirmation();
   }
}

//+------------------------------------------------------------------+
//| Build S/R levels from M15 swing highs/lows                      |
//+------------------------------------------------------------------+
void BuildSRLevels()
{
   ArrayResize(g_levels, 0);
   g_levelCount = 0;

   double tempLevels[];
   bool   tempIsSupport[];
   int    tempCount = 0;

   // Scan M15 for swing points
   int barsToScan = 200;
   for(int i = SR_MinAge + SR_SwingBars; i <= barsToScan; i++)
   {
      if(IsSwingHigh(PERIOD_M15, i, SR_SwingBars))
      {
         double h = iHigh(_Symbol, PERIOD_M15, i);
         ArrayResize(tempLevels, tempCount + 1);
         ArrayResize(tempIsSupport, tempCount + 1);
         tempLevels[tempCount] = h;
         tempIsSupport[tempCount] = false;  // resistance
         tempCount++;
      }
      if(IsSwingLow(PERIOD_M15, i, SR_SwingBars))
      {
         double l = iLow(_Symbol, PERIOD_M15, i);
         ArrayResize(tempLevels, tempCount + 1);
         ArrayResize(tempIsSupport, tempCount + 1);
         tempLevels[tempCount] = l;
         tempIsSupport[tempCount] = true;   // support
         tempCount++;
      }
   }

   // Merge nearby levels and count touches
   double mergeDist = SR_MergePoints * _Point;
   bool used[];
   ArrayResize(used, tempCount);
   ArrayInitialize(used, false);

   for(int i = 0; i < tempCount && g_levelCount < SR_MaxLevels; i++)
   {
      if(used[i]) continue;

      double sum = tempLevels[i];
      int count = 1;
      bool isSup = tempIsSupport[i];

      for(int j = i + 1; j < tempCount; j++)
      {
         if(used[j]) continue;
         if(MathAbs(tempLevels[j] - tempLevels[i]) <= mergeDist)
         {
            sum += tempLevels[j];
            count++;
            used[j] = true;
            // If any touch is support and any is resistance, it's a flip level (stronger)
         }
      }
      used[i] = true;

      ArrayResize(g_levels, g_levelCount + 1);
      g_levels[g_levelCount].price = NormalizeDouble(sum / count, _Digits);
      g_levels[g_levelCount].touches = count;
      g_levels[g_levelCount].isSupport = isSup;
      g_levels[g_levelCount].lastTouch = TimeCurrent();
      g_levelCount++;
   }

   // Sort by proximity to current price
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   for(int i = 0; i < g_levelCount - 1; i++)
   {
      for(int j = i + 1; j < g_levelCount; j++)
      {
         if(MathAbs(g_levels[j].price - bid) < MathAbs(g_levels[i].price - bid))
         {
            SRLevel temp = g_levels[i];
            g_levels[i] = g_levels[j];
            g_levels[j] = temp;
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Detect liquidity sweep on M1                                     |
//+------------------------------------------------------------------+
void DetectSweep()
{
   double open1  = iOpen(_Symbol, PERIOD_M1, 1);
   double close1 = iClose(_Symbol, PERIOD_M1, 1);
   double high1  = iHigh(_Symbol, PERIOD_M1, 1);
   double low1   = iLow(_Symbol, PERIOD_M1, 1);

   if(open1 <= 0) return;

   double body_top = MathMax(open1, close1);
   double body_bot = MathMin(open1, close1);

   for(int i = 0; i < g_levelCount; i++)
   {
      double sr = g_levels[i].price;

      // SWEEP BELOW SUPPORT: wick goes below, body closes above
      // Candle must open near S/R, wick pierces below, closes back above
      if(g_levels[i].isSupport || g_levels[i].touches >= 2)
      {
         double distOpen = MathAbs(open1 - sr) / _Point;
         double sweepDist = (sr - low1) / _Point;

         if(low1 < sr                                    // wick pierced below
            && body_bot >= sr - MaxDistToSR * _Point      // body stayed near/above SR
            && sweepDist >= SweepMinPts                   // meaningful sweep
            && sweepDist <= SweepMaxPts                   // not a breakdown
            && close1 > sr)                               // closed back above
         {
            g_sweepDetected = true;
            g_sweepDir = 1;  // buy setup
            g_sweepSR = sr;
            g_sweepWick = low1;
            g_sweepTime = iTime(_Symbol, PERIOD_M1, 1);
            Print("SWEEP BELOW support ", sr, " | Wick=", low1,
                  " | Sweep=", sweepDist, "pts | Touches=", g_levels[i].touches);
            return;
         }
      }

      // SWEEP ABOVE RESISTANCE: wick goes above, body closes below
      if(!g_levels[i].isSupport || g_levels[i].touches >= 2)
      {
         double sweepDist = (high1 - sr) / _Point;

         if(high1 > sr                                    // wick pierced above
            && body_top <= sr + MaxDistToSR * _Point      // body stayed near/below SR
            && sweepDist >= SweepMinPts
            && sweepDist <= SweepMaxPts
            && close1 < sr)                               // closed back below
         {
            g_sweepDetected = true;
            g_sweepDir = -1;  // sell setup
            g_sweepSR = sr;
            g_sweepWick = high1;
            g_sweepTime = iTime(_Symbol, PERIOD_M1, 1);
            Print("SWEEP ABOVE resistance ", sr, " | Wick=", high1,
                  " | Sweep=", sweepDist, "pts | Touches=", g_levels[i].touches);
            return;
         }
      }
   }

   // Expire old sweep if no confirmation within 3 bars
   if(g_sweepDetected)
   {
      datetime curBar = iTime(_Symbol, PERIOD_M1, 0);
      if((curBar - g_sweepTime) > 3 * 60)
      {
         g_sweepDetected = false;
         g_sweepDir = 0;
      }
   }
}

//+------------------------------------------------------------------+
//| Check for confirmation pattern after sweep                       |
//+------------------------------------------------------------------+
void CheckConfirmation()
{
   if(!g_sweepDetected) return;

   double open1  = iOpen(_Symbol, PERIOD_M1, 1);
   double close1 = iClose(_Symbol, PERIOD_M1, 1);
   double high1  = iHigh(_Symbol, PERIOD_M1, 1);
   double low1   = iLow(_Symbol, PERIOD_M1, 1);
   double open2  = iOpen(_Symbol, PERIOD_M1, 2);
   double close2 = iClose(_Symbol, PERIOD_M1, 2);
   double high2  = iHigh(_Symbol, PERIOD_M1, 2);
   double low2   = iLow(_Symbol, PERIOD_M1, 2);

   double body1 = MathAbs(close1 - open1);
   double range1 = high1 - low1;
   if(range1 <= 0) return;

   bool confirmed = false;

   if(g_sweepDir == 1) // BUY confirmation
   {
      // Pattern 1: Bullish engulfing
      bool engulfing = (close1 > open1) && (close1 > high2) && (open1 < low2);

      // Pattern 2: Pin bar (long lower wick, small body, close near high)
      double lowerWick = MathMin(open1, close1) - low1;
      bool pinBar = (close1 > open1) && (lowerWick > body1 * 1.5) && (close1 > (high1 + low1) / 2);

      // Pattern 3: Strong bullish candle closing above S/R
      bool strongBull = (close1 > open1) && (body1 > range1 * 0.6) && (close1 > g_sweepSR);

      confirmed = engulfing || pinBar || strongBull;

      if(confirmed)
      {
         Print("BUY confirmed: ", engulfing ? "Engulfing" : (pinBar ? "PinBar" : "StrongBull"));
         ExecuteBuy();
      }
   }
   else if(g_sweepDir == -1) // SELL confirmation
   {
      // Pattern 1: Bearish engulfing
      bool engulfing = (close1 < open1) && (close1 < low2) && (open1 > high2);

      // Pattern 2: Pin bar (long upper wick)
      double upperWick = high1 - MathMax(open1, close1);
      bool pinBar = (close1 < open1) && (upperWick > body1 * 1.5) && (close1 < (high1 + low1) / 2);

      // Pattern 3: Strong bearish candle closing below S/R
      bool strongBear = (close1 < open1) && (body1 > range1 * 0.6) && (close1 < g_sweepSR);

      confirmed = engulfing || pinBar || strongBear;

      if(confirmed)
      {
         Print("SELL confirmed: ", engulfing ? "Engulfing" : (pinBar ? "PinBar" : "StrongBear"));
         ExecuteSell();
      }
   }
}

//+------------------------------------------------------------------+
void ExecuteBuy()
{
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);

   // SL below the sweep wick
   double sl = g_sweepWick - 20 * _Point;
   double slDist = ask - sl;

   if(slDist > MaxSLPoints * _Point) { sl = ask - MaxSLPoints * _Point; slDist = MaxSLPoints * _Point; }
   if(slDist < MinSLPoints * _Point) return;

   // TP: next resistance level above, or RR-based
   double tp = ask + MinRR * slDist;  // minimum RR

   // Find nearest resistance above for TP
   for(int i = 0; i < g_levelCount; i++)
   {
      if(g_levels[i].price > ask + slDist)  // at least 1R away
      {
         double srTP = g_levels[i].price - 20 * _Point;  // slightly before S/R
         if(srTP > tp) tp = srTP;  // use S/R if it gives better RR
         break;
      }
   }

   double actualRR = (tp - ask) / slDist;
   if(actualRR < MinRR) return;

   double lot = CalcLotSize(slDist);
   if(lot <= 0) return;

   if(trade.Buy(lot, _Symbol, ask, sl, tp, "LSS Buy"))
   {
      g_inTrade = true;
      g_tradeEntry = ask;
      g_tradeSL = sl;
      g_trailingActive = false;
      g_dailyTrades++;
      g_sweepDetected = false;
      g_barsSinceTrade = 0;
      Print("BUY! Lot=", lot, " Entry=", ask, " SL=", sl, " TP=", tp,
            " RR=", NormalizeDouble(actualRR, 1));
   }
}

//+------------------------------------------------------------------+
void ExecuteSell()
{
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);

   double sl = g_sweepWick + 20 * _Point;
   double slDist = sl - bid;

   if(slDist > MaxSLPoints * _Point) { sl = bid + MaxSLPoints * _Point; slDist = MaxSLPoints * _Point; }
   if(slDist < MinSLPoints * _Point) return;

   double tp = bid - MinRR * slDist;

   // Find nearest support below for TP
   for(int i = 0; i < g_levelCount; i++)
   {
      if(g_levels[i].price < bid - slDist)
      {
         double srTP = g_levels[i].price + 20 * _Point;
         if(srTP < tp) tp = srTP;
         break;
      }
   }

   double actualRR = (bid - tp) / slDist;
   if(actualRR < MinRR) return;

   double lot = CalcLotSize(slDist);
   if(lot <= 0) return;

   if(trade.Sell(lot, _Symbol, bid, sl, tp, "LSS Sell"))
   {
      g_inTrade = true;
      g_tradeEntry = bid;
      g_tradeSL = sl;
      g_trailingActive = false;
      g_dailyTrades++;
      g_sweepDetected = false;
      g_barsSinceTrade = 0;
      Print("SELL! Lot=", lot, " Entry=", bid, " SL=", sl, " TP=", tp,
            " RR=", NormalizeDouble(actualRR, 1));
   }
}

//+------------------------------------------------------------------+
void ManageTrailing()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(PositionGetSymbol(i) != _Symbol) continue;
      if(PositionGetInteger(POSITION_MAGIC) != MagicNumber) continue;

      ulong  ticket = PositionGetInteger(POSITION_TICKET);
      double openP  = PositionGetDouble(POSITION_PRICE_OPEN);
      long   pType  = PositionGetInteger(POSITION_TYPE);
      double curSL  = PositionGetDouble(POSITION_SL);
      double curTP  = PositionGetDouble(POSITION_TP);
      double slDist = MathAbs(openP - g_tradeSL);

      double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      double trail = TrailPoints * _Point;

      if(pType == POSITION_TYPE_BUY)
      {
         // Activate trailing after 1R profit
         if(bid >= openP + slDist && !g_trailingActive)
         {
            g_trailingActive = true;
            double newSL = bid - trail;
            if(newSL > curSL)
               trade.PositionModify(ticket, newSL, curTP);
         }
         else if(g_trailingActive)
         {
            double newSL = bid - trail;
            if(newSL > curSL)
               trade.PositionModify(ticket, newSL, curTP);
         }
      }
      else
      {
         if(ask <= openP - slDist && !g_trailingActive)
         {
            g_trailingActive = true;
            double newSL = ask + trail;
            if(newSL < curSL)
               trade.PositionModify(ticket, newSL, curTP);
         }
         else if(g_trailingActive)
         {
            double newSL = ask + trail;
            if(newSL < curSL)
               trade.PositionModify(ticket, newSL, curTP);
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Utility functions                                                |
//+------------------------------------------------------------------+
bool InSession(int hour)
{
   return (hour >= LondonStart && hour < LondonEnd) ||
          (hour >= NYStart && hour < NYEnd);
}

bool IsSwingHigh(ENUM_TIMEFRAMES tf, int bar, int lookback)
{
   double high = iHigh(_Symbol, tf, bar);
   if(high <= 0) return false;
   for(int i = 1; i <= lookback; i++)
   {
      if(iHigh(_Symbol, tf, bar - i) >= high) return false;
      if(iHigh(_Symbol, tf, bar + i) >= high) return false;
   }
   return true;
}

bool IsSwingLow(ENUM_TIMEFRAMES tf, int bar, int lookback)
{
   double low = iLow(_Symbol, tf, bar);
   if(low <= 0) return false;
   for(int i = 1; i <= lookback; i++)
   {
      if(iLow(_Symbol, tf, bar - i) <= low) return false;
      if(iLow(_Symbol, tf, bar + i) <= low) return false;
   }
   return true;
}

double CalcLotSize(double slDistance)
{
   if(slDistance <= 0) return 0;

   double lot;

   if(UseFixedLot)
   {
      lot = FixedLot;
   }
   else
   {
      double balance  = AccountInfoDouble(ACCOUNT_BALANCE);
      double riskAmt  = balance * RiskPercent / 100.0;
      double tickVal  = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
      double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
      if(tickVal > 0 && tickSize > 0)
         lot = riskAmt / ((slDistance / tickSize) * tickVal);
      else
         lot = FixedLot;  // fallback when tick info unavailable
      if(lot <= 0) lot = FixedLot;
   }

   double minLot  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxLot  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   lot = MathFloor(lot / lotStep) * lotStep;
   lot = NormalizeDouble(lot, 2);
   if(lot < minLot) lot = minLot;
   if(lot > maxLot) lot = maxLot;
   return lot;
}

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
