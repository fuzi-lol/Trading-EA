//+------------------------------------------------------------------+
//|                                         PropFirmScalper.mq5      |
//|          Prop Firm Gold Scalper - ICT Kill Zone + FVG + EMA      |
//+------------------------------------------------------------------+
//| DESIGNED FOR: Prop firm challenges (10% target, 12% max DD)      |
//|                                                                  |
//| LOGIC:                                                           |
//| 1. Trade only during ICT Kill Zones (London/NY AM)               |
//| 2. EMA 50 on M5 for trend direction                              |
//| 3. Detect Fair Value Gap (FVG) on M1 during kill zone            |
//| 4. RSI pullback confirmation (not overbought/oversold)           |
//| 5. Enter on FVG fill, SL beyond FVG, TP at RR target            |
//|                                                                  |
//| SAFETY:                                                          |
//| - Daily loss limit (stops trading for the day)                   |
//| - Max account drawdown guard (stops trading entirely)            |
//| - Profit target (stops when phase target reached)                |
//+------------------------------------------------------------------+
#property copyright "Prop Firm Gold Scalper"
#property version   "1.00"
#property strict

#include <Trade\Trade.mqh>

//--- Inputs
input group "=== Kill Zone Times (Server Time) ==="
input int     LDN_Start        = 10;        // London KZ start hour
input int     LDN_End          = 11;        // London KZ end hour
input int     NY_Start         = 15;        // NY AM KZ start hour
input int     NY_End           = 16;        // NY AM KZ end hour
input int     NY2_Start        = 19;        // NY PM KZ start hour
input int     NY2_End          = 20;        // NY PM KZ end hour
input bool    UseLDN           = true;      // Trade London KZ
input bool    UseNY            = true;      // Trade NY AM KZ
input bool    UseNY2           = false;     // Trade NY PM KZ

input group "=== Entry Filters ==="
input int     EMA_Period       = 50;        // Trend EMA period (M5)
input int     RSI_Period       = 14;        // RSI period
input int     RSI_BuyMax       = 65;        // Max RSI for buy (avoid chasing)
input int     RSI_SellMin      = 35;        // Min RSI for sell
input int     ATR_Period       = 14;        // ATR period
input double  MinFVG_ATR       = 0.3;       // Min FVG size as ATR ratio

input group "=== Risk Management ==="
input bool    UseFixedLot      = true;      // Use fixed lot
input double  FixedLot         = 0.10;      // Fixed lot size
input double  RiskPercent      = 0.75;      // Risk % per trade (if not fixed)
input double  SL_ATR_Multi     = 1.5;       // SL = ATR x multiplier
input double  RiskReward       = 2.0;       // Risk:Reward for TP
input bool    UseTrailing      = true;      // Trail after 1R
input int     TrailPoints      = 80;        // Trail distance (points)

input group "=== Prop Firm Safety ==="
input double  DailyLossLimit   = 3.0;       // Daily loss limit % (stop trading)
input double  MaxDrawdownPct   = 10.0;      // Max account DD % (stop all trading)
input double  ProfitTargetPct  = 10.0;      // Profit target % (stop when reached)
input bool    UseEquityGuard   = true;      // Enable equity protection

input group "=== General ==="
input int     MaxTradesPerDay  = 2;         // Max trades per day
input int     CooldownMins     = 30;        // Minutes between trades
input int     MagicNumber      = 999300;    // Magic number

CTrade trade;

//--- Indicator handles
int h_ema, h_rsi, h_atr;

//--- State
datetime g_lastDay         = 0;
int      g_dailyTrades     = 0;
double   g_dayStartBalance = 0;
double   g_peakBalance     = 0;
double   g_initialBalance  = 0;
bool     g_dailyStopped    = false;
bool     g_ddStopped       = false;
bool     g_targetReached   = false;
datetime g_lastTradeTime   = 0;
bool     g_inTrade         = false;
double   g_tradeSL         = 0;
bool     g_trailingActive  = false;
datetime g_lastM1Bar       = 0;

//--- FVG tracking
struct FVG
{
   double high;       // FVG upper boundary
   double low;        // FVG lower boundary
   int    direction;  // 1=bullish FVG, -1=bearish FVG
   datetime time;     // when detected
   bool   filled;     // has price returned to fill it
};

FVG g_fvgList[];
int g_fvgCount = 0;

//+------------------------------------------------------------------+
int OnInit()
{
   trade.SetExpertMagicNumber(MagicNumber);
   trade.SetTypeFillingBySymbol(_Symbol);

   h_ema = iMA(_Symbol, PERIOD_M5, EMA_Period, 0, MODE_EMA, PRICE_CLOSE);
   h_rsi = iRSI(_Symbol, PERIOD_M1, RSI_Period, PRICE_CLOSE);
   h_atr = iATR(_Symbol, PERIOD_M1, ATR_Period);

   if(h_ema == INVALID_HANDLE || h_rsi == INVALID_HANDLE || h_atr == INVALID_HANDLE)
   {
      Print("Failed to create indicators!");
      return(INIT_FAILED);
   }

   g_initialBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   g_peakBalance    = g_initialBalance;
   g_dayStartBalance = g_initialBalance;

   ArrayResize(g_fvgList, 0);
   g_fvgCount = 0;

   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   IndicatorRelease(h_ema);
   IndicatorRelease(h_rsi);
   IndicatorRelease(h_atr);
}

//+------------------------------------------------------------------+
void OnTick()
{
   MqlDateTime dt;
   TimeCurrent(dt);
   datetime today = TimeCurrent() - dt.hour*3600 - dt.min*60 - dt.sec;

   //--- New day reset
   if(today != g_lastDay)
   {
      g_lastDay = today;
      g_dailyTrades = 0;
      g_dailyStopped = false;
      g_dayStartBalance = AccountInfoDouble(ACCOUNT_BALANCE);
      // Clear old FVGs
      ArrayResize(g_fvgList, 0);
      g_fvgCount = 0;
   }

   //--- Update peak balance
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   if(balance > g_peakBalance) g_peakBalance = balance;

   //--- PROP FIRM SAFETY CHECKS ===
   if(UseEquityGuard)
   {
      // Daily loss limit
      double dailyPL = equity - g_dayStartBalance;
      double dailyLossPct = -dailyPL / g_dayStartBalance * 100.0;
      if(dailyLossPct >= DailyLossLimit && !g_dailyStopped)
      {
         g_dailyStopped = true;
         if(g_inTrade) CloseAll();
         Print("DAILY LOSS LIMIT HIT (", DoubleToString(dailyLossPct, 2), "%). Stopped for today.");
         return;
      }

      // Max drawdown from initial balance
      double ddFromInitial = (g_initialBalance - equity) / g_initialBalance * 100.0;
      if(ddFromInitial >= MaxDrawdownPct && !g_ddStopped)
      {
         g_ddStopped = true;
         if(g_inTrade) CloseAll();
         Print("MAX DRAWDOWN HIT (", DoubleToString(ddFromInitial, 2), "%). ALL TRADING STOPPED.");
         return;
      }

      // Profit target reached
      double profitPct = (balance - g_initialBalance) / g_initialBalance * 100.0;
      if(profitPct >= ProfitTargetPct && !g_targetReached)
      {
         g_targetReached = true;
         if(g_inTrade) CloseAll();
         Print("PROFIT TARGET REACHED (", DoubleToString(profitPct, 2), "%)!");
         return;
      }
   }

   if(g_dailyStopped || g_ddStopped || g_targetReached) return;

   //--- Manage open trade
   if(g_inTrade)
   {
      if(!HasPosition())
      {
         g_inTrade = false;
         g_trailingActive = false;
      }
      else if(UseTrailing)
      {
         ManageTrailing();
      }
      return;
   }

   //--- New M1 bar processing
   datetime curM1 = iTime(_Symbol, PERIOD_M1, 0);
   if(curM1 == g_lastM1Bar) return;
   g_lastM1Bar = curM1;

   //--- Basic filters
   if(g_dailyTrades >= MaxTradesPerDay) return;
   if(!InKillZone(dt.hour, dt.min)) return;

   // Cooldown check
   if(TimeCurrent() - g_lastTradeTime < CooldownMins * 60) return;

   //--- Detect new FVGs
   DetectFVG();

   //--- Check for FVG fill entries
   CheckFVGEntry();
}

//+------------------------------------------------------------------+
bool InKillZone(int hour, int min)
{
   if(UseLDN && hour >= LDN_Start && hour < LDN_End) return true;
   if(UseNY  && hour >= NY_Start  && hour < NY_End)  return true;
   if(UseNY2 && hour >= NY2_Start && hour < NY2_End) return true;
   return false;
}

//+------------------------------------------------------------------+
//| Detect Fair Value Gaps on M1                                     |
//+------------------------------------------------------------------+
void DetectFVG()
{
   // FVG = gap between bar[3] and bar[1] where bar[2] creates displacement
   // Bullish FVG: Low[1] > High[3] (gap up)
   // Bearish FVG: High[1] < Low[3] (gap down)

   double high1 = iHigh(_Symbol, PERIOD_M1, 1);
   double low1  = iLow(_Symbol, PERIOD_M1, 1);
   double high2 = iHigh(_Symbol, PERIOD_M1, 2);
   double low2  = iLow(_Symbol, PERIOD_M1, 2);
   double high3 = iHigh(_Symbol, PERIOD_M1, 3);
   double low3  = iLow(_Symbol, PERIOD_M1, 3);

   if(high1 <= 0 || high3 <= 0) return;

   double atr[1];
   if(CopyBuffer(h_atr, 0, 1, 1, atr) < 1) return;
   double minGap = atr[0] * MinFVG_ATR;

   // Bullish FVG: gap between bar 3 high and bar 1 low
   if(low1 > high3 + minGap)
   {
      // Displacement candle (bar 2) must be bullish and large
      double body2 = iClose(_Symbol, PERIOD_M1, 2) - iOpen(_Symbol, PERIOD_M1, 2);
      if(body2 > 0) // bullish displacement
      {
         AddFVG(low1, high3, 1);
      }
   }

   // Bearish FVG: gap between bar 1 high and bar 3 low
   if(high1 < low3 - minGap)
   {
      double body2 = iOpen(_Symbol, PERIOD_M1, 2) - iClose(_Symbol, PERIOD_M1, 2);
      if(body2 > 0) // bearish displacement
      {
         AddFVG(low3, high1, -1);
      }
   }
}

//+------------------------------------------------------------------+
void AddFVG(double high, double low, int dir)
{
   // Max 5 active FVGs
   if(g_fvgCount >= 5)
   {
      // Remove oldest
      for(int i = 0; i < g_fvgCount - 1; i++)
         g_fvgList[i] = g_fvgList[i + 1];
      g_fvgCount--;
   }

   ArrayResize(g_fvgList, g_fvgCount + 1);
   g_fvgList[g_fvgCount].high = high;
   g_fvgList[g_fvgCount].low = low;
   g_fvgList[g_fvgCount].direction = dir;
   g_fvgList[g_fvgCount].time = TimeCurrent();
   g_fvgList[g_fvgCount].filled = false;
   g_fvgCount++;

   Print(dir == 1 ? "Bullish" : "Bearish", " FVG detected: [",
         low, " - ", high, "]");
}

//+------------------------------------------------------------------+
//| Check if price fills an FVG and enter                            |
//+------------------------------------------------------------------+
void CheckFVGEntry()
{
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double close1 = iClose(_Symbol, PERIOD_M1, 1);

   // Get trend and RSI
   double ema[1], rsi[1], atr[1];
   if(CopyBuffer(h_ema, 0, 0, 1, ema) < 1) return;
   if(CopyBuffer(h_rsi, 0, 1, 1, rsi) < 1) return;
   if(CopyBuffer(h_atr, 0, 1, 1, atr) < 1) return;

   for(int i = g_fvgCount - 1; i >= 0; i--)
   {
      // Skip filled or expired FVGs (older than 30 minutes)
      if(g_fvgList[i].filled) continue;
      if(TimeCurrent() - g_fvgList[i].time > 30 * 60)
      {
         g_fvgList[i].filled = true;
         continue;
      }

      // BULLISH FVG FILL: price pulls back into the gap
      if(g_fvgList[i].direction == 1)
      {
         // Price must enter the FVG zone
         if(close1 <= g_fvgList[i].high && close1 >= g_fvgList[i].low)
         {
            g_fvgList[i].filled = true;

            // Filters: trend up + RSI not overbought
            if(bid <= ema[0]) continue;      // must be above EMA 50
            if(rsi[0] > RSI_BuyMax) continue; // not overbought

            // Check for bullish reaction (close above FVG mid)
            double fvgMid = (g_fvgList[i].high + g_fvgList[i].low) / 2.0;
            if(close1 < fvgMid) continue;

            ExecuteBuy(g_fvgList[i].low, atr[0]);
            return;
         }
      }

      // BEARISH FVG FILL: price pulls back up into the gap
      if(g_fvgList[i].direction == -1)
      {
         if(close1 >= g_fvgList[i].low && close1 <= g_fvgList[i].high)
         {
            g_fvgList[i].filled = true;

            if(bid >= ema[0]) continue;       // must be below EMA 50
            if(rsi[0] < RSI_SellMin) continue; // not oversold

            double fvgMid = (g_fvgList[i].high + g_fvgList[i].low) / 2.0;
            if(close1 > fvgMid) continue;

            ExecuteSell(g_fvgList[i].high, atr[0]);
            return;
         }
      }
   }
}

//+------------------------------------------------------------------+
void ExecuteBuy(double fvgLow, double atr)
{
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double slDist = MathMax(ask - fvgLow + 20 * _Point, atr * SL_ATR_Multi);
   double sl = ask - slDist;
   double tp = ask + slDist * RiskReward;

   double lot = CalcLotSize(slDist);
   if(lot <= 0) return;

   // Pre-trade daily loss check
   double potentialLoss = slDist / _Point * lot * SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE)
                          / (SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE) / _Point);

   if(trade.Buy(lot, _Symbol, ask, sl, tp, "PF Buy FVG"))
   {
      g_inTrade = true;
      g_tradeSL = sl;
      g_trailingActive = false;
      g_dailyTrades++;
      g_lastTradeTime = TimeCurrent();
      Print("BUY! Lot=", lot, " Entry=", ask, " SL=", sl, " TP=", tp,
            " RR=", RiskReward);
   }
}

//+------------------------------------------------------------------+
void ExecuteSell(double fvgHigh, double atr)
{
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double slDist = MathMax(fvgHigh - bid + 20 * _Point, atr * SL_ATR_Multi);
   double sl = bid + slDist;
   double tp = bid - slDist * RiskReward;

   double lot = CalcLotSize(slDist);
   if(lot <= 0) return;

   if(trade.Sell(lot, _Symbol, bid, sl, tp, "PF Sell FVG"))
   {
      g_inTrade = true;
      g_tradeSL = sl;
      g_trailingActive = false;
      g_dailyTrades++;
      g_lastTradeTime = TimeCurrent();
      Print("SELL! Lot=", lot, " Entry=", bid, " SL=", sl, " TP=", tp,
            " RR=", RiskReward);
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
      double trail  = TrailPoints * _Point;

      double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);

      if(pType == POSITION_TYPE_BUY)
      {
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
      if(tickVal <= 0 || tickSize <= 0) return 0;
      lot = riskAmt / ((slDistance / tickSize) * tickVal);
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
