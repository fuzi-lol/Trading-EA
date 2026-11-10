//+------------------------------------------------------------------+
//| GoldAggressiveCompounder.mq5                                     |
//| Aggressive Gold Compounder - Target 30%+ per month               |
//| WARNING: HIGH RISK - Designed for maximum returns, not safety     |
//+------------------------------------------------------------------+
//| APPROACH:                                                         |
//|   - 3% risk/trade with equity compounding                        |
//|   - Up to 5 concurrent positions (different signal types)         |
//|   - Pyramid into winners at 1R                                   |
//|   - Multi-signal: EMA cross, RSI bounce, BB reject, momentum     |
//|   - Both long & short (gold trends both ways)                    |
//|   - Wide session coverage: London 7-12, NY 13-21                 |
//|   - M5 chart with M15 trend filter                               |
//+------------------------------------------------------------------+
#property copyright "Gold Aggressive Compounder"
#property version   "1.00"
#property strict

#include <Trade\Trade.mqh>

//--- Inputs
input group "=== Core Risk (AGGRESSIVE) ==="
input double  RiskPercent      = 3.0;          // Risk % per trade (3% = aggressive)
input int     MaxPositions     = 5;            // Max concurrent positions
input bool    AllowPyramid     = true;         // Add to winners at 1R
input int     MaxPyramidAdds   = 2;            // Max pyramid adds per position chain

input group "=== EMA Settings ==="
input int     FastEMA          = 9;            // Fast EMA (M5)
input int     SlowEMA          = 21;           // Slow EMA (M5)
input int     TrendEMA_Period  = 50;           // Trend EMA (M15)
input ENUM_TIMEFRAMES TrendTF  = PERIOD_M15;   // Trend TF
input int     HTF_EMA_Period   = 200;          // HTF EMA (H1)
input ENUM_TIMEFRAMES HTF_TF   = PERIOD_H1;    // HTF TF

input group "=== Indicators ==="
input int     RSI_Period       = 14;
input int     RSI_OB           = 70;
input int     RSI_OS           = 30;
input int     ATR_Period       = 14;
input double  SL_ATR_Multi     = 1.5;          // SL = ATR * this
input int     MinSLPoints      = 100;          // Min SL (points)
input int     MaxSLPoints      = 800;          // Max SL (points)
input int     Stoch_K          = 14;
input int     Stoch_D          = 3;
input int     Stoch_Slow       = 3;
input int     BB_Period        = 20;
input double  BB_Dev           = 2.0;
input int     ADX_Period       = 14;
input int     ADX_Threshold    = 20;           // Min ADX for trending

input group "=== Risk:Reward ==="
input double  RR_Ratio         = 2.0;          // Base TP = SL * this
input bool    UseBreakeven     = true;         // Move to BE at 1R
input int     BE_Buffer        = 10;           // BE buffer points
input bool    UseTrailing      = true;         // Trail after 1.5R
input int     TrailPoints      = 100;          // Trail distance (points)

input group "=== Session ==="
input int     London_Start     = 7;
input int     London_End       = 12;
input int     NY_Start         = 13;
input int     NY_End           = 21;
input bool    SkipTuesday      = true;         // Historically worst day for gold

input group "=== General ==="
input int     MaxTradesPerDay  = 15;           // High frequency
input int     CooldownBars     = 2;            // Short cooldown
input int     MaxSpreadPoints  = 40;
input int     BaseMagic        = 880000;       // Base magic (each signal type adds offset)

//--- Signal type offsets for magic numbers
#define SIG_EMA_CROSS    0
#define SIG_RSI_BOUNCE   1
#define SIG_BB_REJECT    2
#define SIG_MOMENTUM     3
#define SIG_PYRAMID      4
#define NUM_SIGNAL_TYPES 5

CTrade trade;

//--- Indicator handles
int h_fastEMA, h_slowEMA, h_trendEMA, h_htfEMA;
int h_rsi, h_atr, h_stoch, h_bb, h_adx;

//--- State
datetime g_lastBar       = 0;
int      g_dailyTrades   = 0;
datetime g_lastDay       = 0;
int      g_barsSinceTrade = 999;

//--- Track pyramid state per position
struct PyramidInfo {
   ulong  baseTicket;
   int    addCount;
   double entryPrice;
   double slDistance;
   int    direction;  // 1=buy, -1=sell
};
PyramidInfo g_pyramids[];

//+------------------------------------------------------------------+
int OnInit()
{
   trade.SetExpertMagicNumber(BaseMagic);
   trade.SetDeviationInPoints(15);
   trade.SetTypeFilling(ORDER_FILLING_IOC);

   h_fastEMA  = iMA(_Symbol, PERIOD_M5, FastEMA, 0, MODE_EMA, PRICE_CLOSE);
   h_slowEMA  = iMA(_Symbol, PERIOD_M5, SlowEMA, 0, MODE_EMA, PRICE_CLOSE);
   h_trendEMA = iMA(_Symbol, TrendTF, TrendEMA_Period, 0, MODE_EMA, PRICE_CLOSE);
   h_htfEMA   = iMA(_Symbol, HTF_TF, HTF_EMA_Period, 0, MODE_EMA, PRICE_CLOSE);
   h_rsi      = iRSI(_Symbol, PERIOD_M5, RSI_Period, PRICE_CLOSE);
   h_atr      = iATR(_Symbol, PERIOD_M5, ATR_Period);
   h_stoch    = iStochastic(_Symbol, PERIOD_M5, Stoch_K, Stoch_D, Stoch_Slow, MODE_SMA, STO_LOWHIGH);
   h_bb       = iBands(_Symbol, PERIOD_M5, BB_Period, 0, BB_Dev, PRICE_CLOSE);
   h_adx      = iADX(_Symbol, PERIOD_M5, ADX_Period);

   if(h_fastEMA == INVALID_HANDLE || h_slowEMA == INVALID_HANDLE ||
      h_trendEMA == INVALID_HANDLE || h_htfEMA == INVALID_HANDLE ||
      h_rsi == INVALID_HANDLE || h_atr == INVALID_HANDLE ||
      h_stoch == INVALID_HANDLE || h_bb == INVALID_HANDLE ||
      h_adx == INVALID_HANDLE)
   {
      Print("ERROR: Failed to create indicator handles!");
      return INIT_FAILED;
   }

   ArrayResize(g_pyramids, 0);
   Print("=== Gold Aggressive Compounder LOADED ===");
   Print("Risk: ", RiskPercent, "% | MaxPos: ", MaxPositions, " | Pyramid: ", AllowPyramid);
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   IndicatorRelease(h_fastEMA);
   IndicatorRelease(h_slowEMA);
   IndicatorRelease(h_trendEMA);
   IndicatorRelease(h_htfEMA);
   IndicatorRelease(h_rsi);
   IndicatorRelease(h_atr);
   IndicatorRelease(h_stoch);
   IndicatorRelease(h_bb);
   IndicatorRelease(h_adx);
}

//+------------------------------------------------------------------+
void OnTick()
{
   MqlDateTime dt;
   TimeCurrent(dt);
   datetime today = TimeCurrent() - dt.hour * 3600 - dt.min * 60 - dt.sec;

   if(today != g_lastDay)
   {
      g_lastDay = today;
      g_dailyTrades = 0;
   }

   // Manage ALL open positions (breakeven, trailing, pyramid)
   ManageAllPositions();

   // New bar check on M5
   datetime curBar = iTime(_Symbol, PERIOD_M5, 0);
   if(curBar == g_lastBar) return;
   g_lastBar = curBar;
   g_barsSinceTrade++;

   // Clean closed pyramid entries
   CleanPyramids();

   // Filters
   if(g_dailyTrades >= MaxTradesPerDay) return;
   if(!IsSessionActive(dt.hour)) return;
   if(SkipTuesday && dt.day_of_week == 2) return;
   if(g_barsSinceTrade < CooldownBars) return;
   if(IsSpreadTooWide()) return;

   int openCount = CountMyPositions();
   if(openCount >= MaxPositions) return;

   // Get indicator data
   double fast[3], slow[3], trend[1], htf[1], rsi[3], atr[1];
   double stochK[3], stochD[3], bbUpper[1], bbLower[1], bbMid[1], adx[1];

   if(CopyBuffer(h_fastEMA, 0, 1, 3, fast) < 3) return;
   if(CopyBuffer(h_slowEMA, 0, 1, 3, slow) < 3) return;
   if(CopyBuffer(h_trendEMA, 0, 1, 1, trend) < 1) return;
   if(CopyBuffer(h_htfEMA, 0, 1, 1, htf) < 1) return;
   if(CopyBuffer(h_rsi, 0, 1, 3, rsi) < 3) return;
   if(CopyBuffer(h_atr, 0, 1, 1, atr) < 1) return;
   if(CopyBuffer(h_stoch, 0, 1, 3, stochK) < 3) return;
   if(CopyBuffer(h_stoch, 1, 1, 3, stochD) < 3) return;
   if(CopyBuffer(h_bb, 1, 1, 1, bbUpper) < 1) return;
   if(CopyBuffer(h_bb, 2, 1, 1, bbLower) < 1) return;
   if(CopyBuffer(h_bb, 0, 1, 1, bbMid) < 1) return;
   if(CopyBuffer(h_adx, 0, 1, 1, adx) < 1) return;

   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);

   // Candle data
   double close1 = iClose(_Symbol, PERIOD_M5, 1);
   double open1  = iOpen(_Symbol, PERIOD_M5, 1);
   double high1  = iHigh(_Symbol, PERIOD_M5, 1);
   double low1   = iLow(_Symbol, PERIOD_M5, 1);
   double close2 = iClose(_Symbol, PERIOD_M5, 2);
   double open2  = iOpen(_Symbol, PERIOD_M5, 2);

   // SL distance
   double slDist = atr[0] * SL_ATR_Multi;
   slDist = MathMax(slDist, MinSLPoints * _Point);
   slDist = MathMin(slDist, MaxSLPoints * _Point);

   // Trend direction
   bool m15_bull = bid > trend[0];
   bool m15_bear = bid < trend[0];
   bool h1_bull  = bid > htf[0];
   bool h1_bear  = bid < htf[0];

   bool trendBull = m15_bull;  // M15 EMA 50 is primary trend
   bool trendBear = m15_bear;

   // ADX trending
   bool trending = adx[0] >= ADX_Threshold;

   // === SIGNAL 1: EMA CROSSOVER (bread and butter) ===
   if(!HasSignalPosition(SIG_EMA_CROSS) && trending)
   {
      bool bullCross = (fast[0] <= slow[0]) && (fast[1] > slow[1]);
      bool bearCross = (fast[0] >= slow[0]) && (fast[1] < slow[1]);

      if(bullCross && trendBull && rsi[2] < RSI_OB)
         OpenTrade(1, slDist, SIG_EMA_CROSS, "EMA_X_BUY");
      else if(bearCross && trendBear && rsi[2] > RSI_OS)
         OpenTrade(-1, slDist, SIG_EMA_CROSS, "EMA_X_SELL");
   }

   // === SIGNAL 2: RSI BOUNCE ===
   if(!HasSignalPosition(SIG_RSI_BOUNCE))
   {
      bool rsiBullBounce = (rsi[0] < RSI_OS || rsi[1] < RSI_OS) && rsi[2] > RSI_OS && rsi[2] > rsi[1];
      bool rsiBearBounce = (rsi[0] > RSI_OB || rsi[1] > RSI_OB) && rsi[2] < RSI_OB && rsi[2] < rsi[1];
      bool bullCandle = close1 > open1 && (close1 - open1) > (high1 - low1) * 0.5;
      bool bearCandle = close1 < open1 && (open1 - close1) > (high1 - low1) * 0.5;

      if(rsiBullBounce && trendBull && bullCandle)
         OpenTrade(1, slDist, SIG_RSI_BOUNCE, "RSI_B_BUY");
      else if(rsiBearBounce && trendBear && bearCandle)
         OpenTrade(-1, slDist, SIG_RSI_BOUNCE, "RSI_B_SELL");
   }

   // === SIGNAL 3: BOLLINGER BAND REJECTION ===
   if(!HasSignalPosition(SIG_BB_REJECT))
   {
      double bbRange = bbUpper[0] - bbLower[0];
      if(bbRange > 0)
      {
         bool bbBullReject = low1 <= bbLower[0] && close1 > bbLower[0] && close1 > open1;
         bool bbBearReject = high1 >= bbUpper[0] && close1 < bbUpper[0] && close1 < open1;

         // Counter-trend BB needs strong confirmation
         bool stochOversold = stochK[2] < 25 && stochK[2] > stochD[2];
         bool stochOverbought = stochK[2] > 75 && stochK[2] < stochD[2];

         if(bbBullReject && stochOversold && m15_bull)
            OpenTrade(1, slDist, SIG_BB_REJECT, "BB_R_BUY");
         else if(bbBearReject && stochOverbought && m15_bear)
            OpenTrade(-1, slDist, SIG_BB_REJECT, "BB_R_SELL");
      }
   }

   // === SIGNAL 4: MOMENTUM CONTINUATION (2 strong candles + aligned EMAs) ===
   if(!HasSignalPosition(SIG_MOMENTUM) && trending)
   {
      double body1 = MathAbs(close1 - open1);
      double body2 = MathAbs(close2 - open2);
      double range1 = high1 - low1;
      double range2 = iHigh(_Symbol, PERIOD_M5, 2) - iLow(_Symbol, PERIOD_M5, 2);
      bool strongBull1 = close1 > open1 && range1 > 0 && body1 / range1 > 0.6;
      bool strongBull2 = close2 > open2 && range2 > 0 && body2 / range2 > 0.4;
      bool strongBear1 = close1 < open1 && range1 > 0 && body1 / range1 > 0.6;
      bool strongBear2 = close2 < open2 && range2 > 0 && body2 / range2 > 0.4;

      bool emaAlignedBull = fast[1] > slow[1] && fast[2] > fast[1];
      bool emaAlignedBear = fast[1] < slow[1] && fast[2] < fast[1];

      if(strongBull1 && strongBull2 && emaAlignedBull && trendBull && stochK[2] < 80)
         OpenTrade(1, slDist, SIG_MOMENTUM, "MOM_BUY");
      else if(strongBear1 && strongBear2 && emaAlignedBear && trendBear && stochK[2] > 20)
         OpenTrade(-1, slDist, SIG_MOMENTUM, "MOM_SELL");
   }
}

//+------------------------------------------------------------------+
void OpenTrade(int direction, double slDist, int signalType, string comment)
{
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double lot = CalcLotSize(slDist);
   if(lot <= 0) return;

   int magic = BaseMagic + signalType;
   trade.SetExpertMagicNumber(magic);

   bool result = false;
   double sl, tp;

   if(direction == 1)
   {
      sl = ask - slDist;
      tp = ask + slDist * RR_Ratio;
      result = trade.Buy(lot, _Symbol, ask, sl, tp, comment);
   }
   else
   {
      sl = bid + slDist;
      tp = bid - slDist * RR_Ratio;
      result = trade.Sell(lot, _Symbol, bid, sl, tp, comment);
   }

   if(result)
   {
      g_dailyTrades++;
      g_barsSinceTrade = 0;

      // Track for pyramiding
      if(AllowPyramid)
      {
         int sz = ArraySize(g_pyramids);
         ArrayResize(g_pyramids, sz + 1);
         g_pyramids[sz].baseTicket = trade.ResultDeal();
         g_pyramids[sz].addCount = 0;
         g_pyramids[sz].entryPrice = (direction == 1) ? ask : bid;
         g_pyramids[sz].slDistance = slDist;
         g_pyramids[sz].direction = direction;
      }

      Print("TRADE: ", comment, " | Lot: ", lot, " | SL: ", slDist / _Point, " pts | RR: ", RR_Ratio);
   }
}

//+------------------------------------------------------------------+
void ManageAllPositions()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket)) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;

      long magic = PositionGetInteger(POSITION_MAGIC);
      if(magic < BaseMagic || magic > BaseMagic + NUM_SIGNAL_TYPES) continue;

      double openP = PositionGetDouble(POSITION_PRICE_OPEN);
      double curSL = PositionGetDouble(POSITION_SL);
      double curTP = PositionGetDouble(POSITION_TP);
      long   pType = PositionGetInteger(POSITION_TYPE);
      double slDist = MathAbs(openP - curSL);
      if(slDist <= 0) continue;

      double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);

      trade.SetExpertMagicNumber((int)magic);

      if(pType == POSITION_TYPE_BUY)
      {
         double profit = bid - openP;

         // Breakeven at 1R
         if(UseBreakeven && profit >= slDist && curSL < openP)
         {
            double newSL = openP + BE_Buffer * _Point;
            trade.PositionModify(ticket, newSL, curTP);
         }

         // Trailing after 1.5R
         if(UseTrailing && profit >= slDist * 1.5)
         {
            double newSL = bid - TrailPoints * _Point;
            if(newSL > curSL)
               trade.PositionModify(ticket, newSL, curTP);
         }

         // Pyramid at 1R
         if(AllowPyramid && profit >= slDist && profit < slDist * 1.5)
            TryPyramid(ticket, 1, slDist);
      }
      else
      {
         double profit = openP - ask;

         if(UseBreakeven && profit >= slDist && curSL > openP)
         {
            double newSL = openP - BE_Buffer * _Point;
            trade.PositionModify(ticket, newSL, curTP);
         }

         if(UseTrailing && profit >= slDist * 1.5)
         {
            double newSL = ask + TrailPoints * _Point;
            if(newSL < curSL)
               trade.PositionModify(ticket, newSL, curTP);
         }

         if(AllowPyramid && profit >= slDist && profit < slDist * 1.5)
            TryPyramid(ticket, -1, slDist);
      }
   }
}

//+------------------------------------------------------------------+
void TryPyramid(ulong ticket, int direction, double slDist)
{
   if(CountMyPositions() >= MaxPositions) return;
   if(g_dailyTrades >= MaxTradesPerDay) return;

   // Find this position in pyramid tracker
   for(int i = 0; i < ArraySize(g_pyramids); i++)
   {
      if(g_pyramids[i].baseTicket == ticket)
      {
         if(g_pyramids[i].addCount >= MaxPyramidAdds) return;

         double lot = CalcLotSize(slDist);
         if(lot <= 0) return;

         // Reduce pyramid lot by 50%
         lot = NormalizeLot(lot * 0.5);
         if(lot <= 0) return;

         trade.SetExpertMagicNumber(BaseMagic + SIG_PYRAMID);
         bool result = false;
         double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
         double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);

         if(direction == 1)
         {
            double sl = ask - slDist;
            double tp = ask + slDist * RR_Ratio;
            result = trade.Buy(lot, _Symbol, ask, sl, tp, "PYRAMID_BUY");
         }
         else
         {
            double sl = bid + slDist;
            double tp = bid - slDist * RR_Ratio;
            result = trade.Sell(lot, _Symbol, bid, sl, tp, "PYRAMID_SELL");
         }

         if(result)
         {
            g_pyramids[i].addCount++;
            g_dailyTrades++;
            Print("PYRAMID ADD #", g_pyramids[i].addCount, " on ticket ", ticket);
         }
         return;
      }
   }
}

//+------------------------------------------------------------------+
double CalcLotSize(double slDistance)
{
   if(slDistance <= 0) return 0;

   double equity  = AccountInfoDouble(ACCOUNT_EQUITY);  // Compound off equity
   double riskAmt = equity * RiskPercent / 100.0;
   double tickVal = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double tickSz  = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);

   double lot;
   if(tickVal <= 0 || tickSz <= 0)
   {
      // Fallback for FundingPips TICK_VALUE bug: assume XAUUSD $1/point for 0.01 lot
      double pointValue = 0.01;  // $0.01 per point per 0.01 lot (standard gold)
      lot = riskAmt / (slDistance / _Point * pointValue);
      lot *= 0.01;
   }
   else
      lot = riskAmt / ((slDistance / tickSz) * tickVal);

   return NormalizeLot(lot);
}

//+------------------------------------------------------------------+
double NormalizeLot(double lot)
{
   double minLot  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxLot  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);

   if(lotStep <= 0) lotStep = 0.01;
   lot = MathFloor(lot / lotStep) * lotStep;
   lot = NormalizeDouble(lot, 2);
   if(lot < minLot) lot = minLot;
   if(lot > maxLot) lot = maxLot;
   return lot;
}

//+------------------------------------------------------------------+
bool IsSessionActive(int hour)
{
   if(hour >= London_Start && hour < London_End) return true;
   if(hour >= NY_Start && hour < NY_End) return true;
   return false;
}

//+------------------------------------------------------------------+
bool IsSpreadTooWide()
{
   long spread = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   return (spread > MaxSpreadPoints);
}

//+------------------------------------------------------------------+
int CountMyPositions()
{
   int count = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket)) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      long magic = PositionGetInteger(POSITION_MAGIC);
      if(magic >= BaseMagic && magic <= BaseMagic + NUM_SIGNAL_TYPES)
         count++;
   }
   return count;
}

//+------------------------------------------------------------------+
bool HasSignalPosition(int signalType)
{
   int targetMagic = BaseMagic + signalType;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket)) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if(PositionGetInteger(POSITION_MAGIC) == targetMagic) return true;
   }
   return false;
}

//+------------------------------------------------------------------+
void CleanPyramids()
{
   for(int i = ArraySize(g_pyramids) - 1; i >= 0; i--)
   {
      bool found = false;
      for(int j = PositionsTotal() - 1; j >= 0; j--)
      {
         ulong ticket = PositionGetTicket(j);
         if(!PositionSelectByTicket(ticket)) continue;
         if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
         long magic = PositionGetInteger(POSITION_MAGIC);
         if(magic >= BaseMagic && magic <= BaseMagic + NUM_SIGNAL_TYPES)
         {
            // Check if this position's open price matches pyramid entry
            double op = PositionGetDouble(POSITION_PRICE_OPEN);
            if(MathAbs(op - g_pyramids[i].entryPrice) < 1.0)
            {
               found = true;
               break;
            }
         }
      }
      if(!found)
      {
         // Remove from array
         int last = ArraySize(g_pyramids) - 1;
         if(i < last) g_pyramids[i] = g_pyramids[last];
         ArrayResize(g_pyramids, last);
      }
   }
}
//+------------------------------------------------------------------+
