//+------------------------------------------------------------------+
//|                                          SMC_LumenTrades.mq5     |
//|                    XAU/USD SMC Strategy - Lumen Trades V3        |
//|  H1 ChoCH -> H1 OB -> M5 confirmation at OB -> TP at DOL       |
//+------------------------------------------------------------------+
#property copyright "SMC Lumen Trades Strategy"
#property version   "3.00"
#property strict

#include <Trade\Trade.mqh>

//--- Inputs
input group "=== Structure Detection ==="
input int     H1_SwingBars     = 5;         // H1 swing bars each side
input int     M5_ConfirmBars   = 3;         // M5 bars to wait at OB for reversal candle

input group "=== Risk Management ==="
input double  RiskPercent      = 1.0;       // Risk % per trade
input double  RiskReward       = 3.0;       // Risk:Reward ratio
input int     MaxSLPoints      = 600;       // Max SL in points
input int     MinSLPoints      = 80;        // Min SL in points
input bool    UseBreakeven     = true;      // Move SL to BE at 1R profit

input group "=== Filters ==="
input int     MaxTradesPerDay  = 2;         // Max trades per day
input int     StartHour        = 7;         // Trading start hour
input int     EndHour          = 20;        // Trading end hour
input int     SetupTimeoutH    = 24;        // Cancel setup after N hours

input group "=== General ==="
input int     MagicNumber      = 556600;    // Magic number

CTrade trade;

//--- H1 swing storage
double   g_sh[30];       // swing highs
double   g_sl_arr[30];   // swing lows (renamed to avoid SL confusion)
int      g_shCount = 0;
int      g_slCount = 0;

//--- Setup state
bool     g_hasSetup      = false;
int      g_setupDir      = 0;     // 1=bullish, -1=bearish
double   g_obHigh        = 0;
double   g_obLow         = 0;
double   g_obMid         = 0;
double   g_dolTarget     = 0;
datetime g_setupTime     = 0;
bool     g_enteredOB     = false;  // price has touched OB
int      g_obBarsInside  = 0;     // how many M5 bars inside OB

//--- Trade state
bool     g_inTrade       = false;
double   g_tradeEntry    = 0;
double   g_tradeSL       = 0;
bool     g_movedToBE     = false;

//--- Daily
datetime g_lastDay       = 0;
int      g_dailyTrades   = 0;

//--- Bar tracking
datetime g_lastH1Bar     = 0;
datetime g_lastM5Bar     = 0;

//+------------------------------------------------------------------+
int OnInit()
{
   trade.SetExpertMagicNumber(MagicNumber);
   trade.SetTypeFillingBySymbol(_Symbol);
   g_shCount = 0;
   g_slCount = 0;
   PreloadSwings();
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
void PreloadSwings()
{
   for(int i = 150; i >= H1_SwingBars + 1; i--)
   {
      if(IsSwingHigh(PERIOD_H1, i, H1_SwingBars) && g_shCount < 30)
      {
         g_sh[g_shCount++] = iHigh(_Symbol, PERIOD_H1, i);
      }
      if(IsSwingLow(PERIOD_H1, i, H1_SwingBars) && g_slCount < 30)
      {
         g_sl_arr[g_slCount++] = iLow(_Symbol, PERIOD_H1, i);
      }
   }
   Print("Init: ", g_shCount, " H1 swing highs, ", g_slCount, " H1 swing lows");
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
   }

   //--- Manage open position
   if(g_inTrade)
   {
      if(!HasPosition())
      {
         g_inTrade = false;
         g_hasSetup = false; // look for new setup after trade closes
         g_movedToBE = false;
      }
      else if(UseBreakeven)
      {
         ManageBreakeven();
      }
      return;
   }

   if(g_dailyTrades >= MaxTradesPerDay) return;
   if(dt.hour < StartHour || dt.hour >= EndHour) return;

   //--- New H1 bar: update swings and detect ChoCH
   datetime curH1 = iTime(_Symbol, PERIOD_H1, 0);
   if(curH1 != g_lastH1Bar)
   {
      g_lastH1Bar = curH1;
      UpdateH1Swings();

      if(!g_hasSetup)
         DetectChoCH();
   }

   //--- New M5 bar: check OB interaction
   datetime curM5 = iTime(_Symbol, PERIOD_M5, 0);
   if(curM5 != g_lastM5Bar)
   {
      g_lastM5Bar = curM5;

      if(g_hasSetup)
         CheckOBEntry();
   }
}

//+------------------------------------------------------------------+
void UpdateH1Swings()
{
   int idx = H1_SwingBars + 1;

   if(IsSwingHigh(PERIOD_H1, idx, H1_SwingBars))
   {
      double h = iHigh(_Symbol, PERIOD_H1, idx);
      AddSwing(g_sh, g_shCount, h, 30);
   }
   if(IsSwingLow(PERIOD_H1, idx, H1_SwingBars))
   {
      double l = iLow(_Symbol, PERIOD_H1, idx);
      AddSwing(g_sl_arr, g_slCount, l, 30);
   }
}

//+------------------------------------------------------------------+
void DetectChoCH()
{
   if(g_shCount < 2 || g_slCount < 2) return;

   double close1 = iClose(_Symbol, PERIOD_H1, 1);
   double lastSH = g_sh[g_shCount - 1];
   double prevSH = g_sh[g_shCount - 2];
   double lastSL = g_sl_arr[g_slCount - 1];
   double prevSL = g_sl_arr[g_slCount - 2];

   // Bullish ChoCH: was bearish (lower lows), H1 closes above last swing high
   if(lastSL < prevSL && close1 > lastSH)
   {
      SetupBullish(lastSH, prevSH, lastSL);
   }
   // Bearish ChoCH: was bullish (higher highs), H1 closes below last swing low
   else if(lastSH > prevSH && close1 < lastSL)
   {
      SetupBearish(lastSL, prevSL, lastSH);
   }
}

//+------------------------------------------------------------------+
void SetupBullish(double chochLevel, double prevSH, double lastSL)
{
   // Find OB: last bearish H1 candle before the bullish impulse
   for(int i = 1; i <= 30; i++)
   {
      double o = iOpen(_Symbol, PERIOD_H1, i);
      double c = iClose(_Symbol, PERIOD_H1, i);
      if(c < o) // bearish candle
      {
         g_obHigh = iHigh(_Symbol, PERIOD_H1, i);
         g_obLow  = iLow(_Symbol, PERIOD_H1, i);
         g_obMid  = (g_obHigh + g_obLow) / 2.0;
         break;
      }
   }
   if(g_obHigh == 0) return;

   g_setupDir    = 1;
   g_dolTarget   = prevSH;
   g_hasSetup    = true;
   g_setupTime   = TimeCurrent();
   g_enteredOB   = false;
   g_obBarsInside = 0;

   Print("BULLISH setup: OB=[", g_obLow, "-", g_obHigh, "] DOL=", g_dolTarget);
}

//+------------------------------------------------------------------+
void SetupBearish(double chochLevel, double prevSL, double lastSH)
{
   for(int i = 1; i <= 30; i++)
   {
      double o = iOpen(_Symbol, PERIOD_H1, i);
      double c = iClose(_Symbol, PERIOD_H1, i);
      if(c > o) // bullish candle
      {
         g_obHigh = iHigh(_Symbol, PERIOD_H1, i);
         g_obLow  = iLow(_Symbol, PERIOD_H1, i);
         g_obMid  = (g_obHigh + g_obLow) / 2.0;
         break;
      }
   }
   if(g_obHigh == 0) return;

   g_setupDir    = -1;
   g_dolTarget   = prevSL;
   g_hasSetup    = true;
   g_setupTime   = TimeCurrent();
   g_enteredOB   = false;
   g_obBarsInside = 0;

   Print("BEARISH setup: OB=[", g_obLow, "-", g_obHigh, "] DOL=", g_dolTarget);
}

//+------------------------------------------------------------------+
void CheckOBEntry()
{
   // Timeout check
   if(TimeCurrent() - g_setupTime > SetupTimeoutH * 3600)
   {
      g_hasSetup = false;
      Print("Setup timed out.");
      return;
   }

   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);

   // Check for invalidation
   if(g_setupDir == 1 && bid < g_obLow - MaxSLPoints * _Point)
   {
      g_hasSetup = false;
      Print("Price broke far below OB. Bullish setup invalid.");
      return;
   }
   if(g_setupDir == -1 && bid > g_obHigh + MaxSLPoints * _Point)
   {
      g_hasSetup = false;
      Print("Price broke far above OB. Bearish setup invalid.");
      return;
   }

   // Check last closed M5 candle
   double m5Open  = iOpen(_Symbol, PERIOD_M5, 1);
   double m5Close = iClose(_Symbol, PERIOD_M5, 1);
   double m5High  = iHigh(_Symbol, PERIOD_M5, 1);
   double m5Low   = iLow(_Symbol, PERIOD_M5, 1);

   if(g_setupDir == 1) // Bullish: wait for price to dip INTO OB then show rejection
   {
      // Price must touch OB zone
      if(m5Low <= g_obHigh)
      {
         if(!g_enteredOB)
         {
            g_enteredOB = true;
            g_obBarsInside = 0;
            Print("Price touched bullish OB.");
         }
         g_obBarsInside++;

         // Look for bullish rejection: close above OB mid, bullish candle, wick rejection
         bool bullishCandle = m5Close > m5Open;
         bool closeAboveMid = m5Close > g_obMid;
         double lowerWick = MathMin(m5Open, m5Close) - m5Low;
         double body = MathAbs(m5Close - m5Open);
         bool hasRejection = lowerWick > body * 0.5;

         if(bullishCandle && closeAboveMid && (hasRejection || g_obBarsInside >= M5_ConfirmBars))
         {
            ExecuteBuy();
         }
      }
   }
   else // Bearish: wait for price to rally INTO OB then show rejection
   {
      if(m5High >= g_obLow)
      {
         if(!g_enteredOB)
         {
            g_enteredOB = true;
            g_obBarsInside = 0;
            Print("Price touched bearish OB.");
         }
         g_obBarsInside++;

         bool bearishCandle = m5Close < m5Open;
         bool closeBelowMid = m5Close < g_obMid;
         double upperWick = m5High - MathMax(m5Open, m5Close);
         double body = MathAbs(m5Close - m5Open);
         bool hasRejection = upperWick > body * 0.5;

         if(bearishCandle && closeBelowMid && (hasRejection || g_obBarsInside >= M5_ConfirmBars))
         {
            ExecuteSell();
         }
      }
   }
}

//+------------------------------------------------------------------+
void ExecuteBuy()
{
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double sl  = g_obLow - 20 * _Point;  // SL just below OB
   double slDist = ask - sl;

   if(slDist > MaxSLPoints * _Point) { sl = ask - MaxSLPoints * _Point; slDist = MaxSLPoints * _Point; }
   if(slDist < MinSLPoints * _Point) return;

   // TP: RR-based or DOL (whichever is further for proper reward)
   double tpRR = ask + RiskReward * slDist;
   double tp = tpRR;
   if(g_dolTarget > ask)
      tp = MathMax(tpRR, g_dolTarget);

   double lot = CalcLotSize(slDist);
   if(lot <= 0) return;

   if(trade.Buy(lot, _Symbol, ask, sl, tp, "SMC Buy"))
   {
      g_inTrade    = true;
      g_tradeEntry = ask;
      g_tradeSL    = sl;
      g_movedToBE  = false;
      g_dailyTrades++;
      g_hasSetup   = false;
      Print("BUY! Lot=", lot, " Entry=", ask, " SL=", sl, " TP=", tp,
            " RR=", NormalizeDouble((tp-ask)/slDist, 1));
   }
}

//+------------------------------------------------------------------+
void ExecuteSell()
{
   double bid2 = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double sl   = g_obHigh + 20 * _Point;
   double slDist = sl - bid2;

   if(slDist > MaxSLPoints * _Point) { sl = bid2 + MaxSLPoints * _Point; slDist = MaxSLPoints * _Point; }
   if(slDist < MinSLPoints * _Point) return;

   double tpRR = bid2 - RiskReward * slDist;
   double tp = tpRR;
   if(g_dolTarget < bid2)
      tp = MathMin(tpRR, g_dolTarget);

   double lot = CalcLotSize(slDist);
   if(lot <= 0) return;

   if(trade.Sell(lot, _Symbol, bid2, sl, tp, "SMC Sell"))
   {
      g_inTrade    = true;
      g_tradeEntry = bid2;
      g_tradeSL    = sl;
      g_movedToBE  = false;
      g_dailyTrades++;
      g_hasSetup   = false;
      Print("SELL! Lot=", lot, " Entry=", bid2, " SL=", sl, " TP=", tp,
            " RR=", NormalizeDouble((bid2-tp)/slDist, 1));
   }
}

//+------------------------------------------------------------------+
void ManageBreakeven()
{
   if(g_movedToBE) return;

   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(PositionGetSymbol(i) != _Symbol) continue;
      if(PositionGetInteger(POSITION_MAGIC) != MagicNumber) continue;

      double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
      long posType = PositionGetInteger(POSITION_TYPE);
      double slDist = MathAbs(openPrice - g_tradeSL);
      ulong ticket = PositionGetInteger(POSITION_TICKET);

      if(posType == POSITION_TYPE_BUY)
      {
         double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
         if(bid >= openPrice + slDist) // 1R profit
         {
            trade.PositionModify(ticket, openPrice + 10 * _Point, PositionGetDouble(POSITION_TP));
            g_movedToBE = true;
            Print("Moved SL to breakeven (BUY)");
         }
      }
      else
      {
         double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
         if(ask <= openPrice - slDist)
         {
            trade.PositionModify(ticket, openPrice - 10 * _Point, PositionGetDouble(POSITION_TP));
            g_movedToBE = true;
            Print("Moved SL to breakeven (SELL)");
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Helpers                                                          |
//+------------------------------------------------------------------+
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

void AddSwing(double &arr[], int &count, double val, int maxSize)
{
   if(count < maxSize)
   {
      arr[count++] = val;
   }
   else
   {
      for(int i = 0; i < maxSize - 1; i++) arr[i] = arr[i+1];
      arr[maxSize - 1] = val;
   }
}
//+------------------------------------------------------------------+
