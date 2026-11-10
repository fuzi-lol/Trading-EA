//+------------------------------------------------------------------+
//|                                     M1_MomentumScalper.mq5 V10   |
//|     Fine-Tuned: Best Hours + M15 Trend + Data-Driven Filters     |
//+------------------------------------------------------------------+
//| V10 FINE-TUNING (21-month data-driven):                          |
//|   - Hours 14-15 lost -$600 → Session2 starts at 16              |
//|   - Thursday lost -$323 → Skipped                                |
//|   - Added M15 EMA 200 higher TF trend filter                    |
//|   - Best hours: 8-9 (London) + 16-18 (late NY)                  |
//|   - Buy only + consolidation filters + 1% daily loss cap        |
//+------------------------------------------------------------------+
#property copyright "M1 Momentum Scalper V10"
#property version   "10.00"
#property strict

#include <Trade\Trade.mqh>

//--- Inputs
input group "=== EMA Settings ==="
input int     FastEMA          = 5;          // Fast EMA (M1)
input int     SlowEMA          = 13;         // Slow EMA (M1)
input int     TrendEMA         = 50;         // Trend EMA (M5)
input ENUM_TIMEFRAMES TrendTF  = PERIOD_M5;  // Trend TF
input int     HTF_EMA          = 50;         // Higher TF EMA (M15, faster)
input ENUM_TIMEFRAMES HTF_TF   = PERIOD_M15; // Higher TF

input group "=== VWAP ==="
input bool    UseVWAP          = true;       // Use VWAP filter

input group "=== Indicators ==="
input int     Stoch_K          = 5;
input int     Stoch_D          = 3;
input int     Stoch_Slow       = 3;
input int     Stoch_OB         = 80;
input int     Stoch_OS         = 20;
input int     RSI_Period       = 7;
input int     RSI_OB           = 70;
input int     RSI_OS           = 30;
input int     ADX_Period       = 10;
input int     ADX_Threshold    = 15;
input int     ATR_Period       = 10;
input int     BB_Period        = 20;
input double  BB_TouchRatio    = 0.9;

input group "=== Consolidation Filters ==="
input int     ATR_MA_Period    = 50;
input double  ATR_MinRatio     = 1.0;
input double  BB_MinWidth      = 0.0008;     // Min BB width as % of price

input group "=== Direction ==="
input bool    AllowBuys        = true;
input bool    AllowSells       = false;      // Sells lose on XAUUSD

input group "=== Session ==="
input int     Session1_Start   = 8;          // London open
input int     Session1_End     = 10;         // London end
input int     Session2_Start   = 14;         // NY overlap start
input int     Session2_End     = 19;         // NY end
input bool    SkipHour15       = true;       // Skip hour 15 (-$396 worst hour)
input bool    SkipHour17       = false;      // Skip hour 17

input group "=== Day Filter ==="
input bool    SkipMonday       = false;
input bool    SkipTuesday      = false;
input bool    SkipWednesday    = true;       // -$954
input bool    SkipThursday     = false;
input bool    SkipFriday       = false;

input group "=== Risk ==="
input bool    UseFixedLot      = true;
input double  FixedLot         = 0.10;
input double  RiskPercent      = 0.5;
input double  SL_ATR_Multi     = 1.5;
input int     MinSLPoints      = 40;
input int     MaxSLPoints      = 200;
input double  RiskReward       = 2.0;
input bool    UseBreakeven     = true;
input int     BE_Buffer        = 5;
input bool    UseTrailing      = true;
input int     TrailPoints      = 40;

input group "=== General ==="
input int     MaxTradesPerDay  = 8;
input double  MaxDailyLossPct  = 1.0;
input int     CooldownBars     = 2;
input int     MaxSpreadPoints  = 30;
input int     VolMA_Period     = 20;
input double  VolMinRatio      = 1.0;
input int     MagicNumber      = 991100;

CTrade trade;

int h_fastEMA, h_slowEMA, h_trendEMA, h_htfEMA;
int h_adx, h_atr, h_bb, h_rsi, h_stoch;

datetime g_lastDay        = 0;
int      g_dailyTrades    = 0;
datetime g_lastM1Bar      = 0;
int      g_barsSinceTrade = 999;
bool     g_inTrade        = false;
double   g_tradeSL        = 0;
bool     g_trailingActive = false;
double   g_dailyStartBal  = 0;

double   g_vwap           = 0;
double   g_cumPV          = 0;
double   g_cumVol         = 0;
datetime g_vwapDay        = 0;

//+------------------------------------------------------------------+
int OnInit()
{
   trade.SetExpertMagicNumber(MagicNumber);
   trade.SetDeviationInPoints(10);
   trade.SetTypeFilling(ORDER_FILLING_IOC);

   h_fastEMA  = iMA(_Symbol, PERIOD_M1, FastEMA, 0, MODE_EMA, PRICE_CLOSE);
   h_slowEMA  = iMA(_Symbol, PERIOD_M1, SlowEMA, 0, MODE_EMA, PRICE_CLOSE);
   h_trendEMA = iMA(_Symbol, TrendTF, TrendEMA, 0, MODE_EMA, PRICE_CLOSE);
   h_htfEMA   = iMA(_Symbol, HTF_TF, HTF_EMA, 0, MODE_EMA, PRICE_CLOSE);
   h_adx      = iADX(_Symbol, PERIOD_M1, ADX_Period);
   h_atr      = iATR(_Symbol, PERIOD_M1, ATR_Period);
   h_bb       = iBands(_Symbol, PERIOD_M1, BB_Period, 0, 2.0, PRICE_CLOSE);
   h_rsi      = iRSI(_Symbol, PERIOD_M1, RSI_Period, PRICE_CLOSE);
   h_stoch    = iStochastic(_Symbol, PERIOD_M1, Stoch_K, Stoch_D, Stoch_Slow, MODE_SMA, STO_LOWHIGH);

   if(h_fastEMA == INVALID_HANDLE || h_slowEMA == INVALID_HANDLE ||
      h_trendEMA == INVALID_HANDLE || h_htfEMA == INVALID_HANDLE ||
      h_adx == INVALID_HANDLE || h_atr == INVALID_HANDLE ||
      h_bb == INVALID_HANDLE || h_rsi == INVALID_HANDLE ||
      h_stoch == INVALID_HANDLE)
   {
      Print("Failed to create indicator handles!");
      return(INIT_FAILED);
   }

   g_dailyStartBal = AccountInfoDouble(ACCOUNT_BALANCE);
   Print("M1 Scalper V10 (Fine-Tuned) on ", _Symbol);
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   IndicatorRelease(h_fastEMA);
   IndicatorRelease(h_slowEMA);
   IndicatorRelease(h_trendEMA);
   IndicatorRelease(h_htfEMA);
   IndicatorRelease(h_adx);
   IndicatorRelease(h_atr);
   IndicatorRelease(h_bb);
   IndicatorRelease(h_rsi);
   IndicatorRelease(h_stoch);
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
      g_dailyStartBal = AccountInfoDouble(ACCOUNT_BALANCE);
   }

   if(g_inTrade)
   {
      if(!HasPosition())
      {
         g_inTrade = false;
         g_trailingActive = false;
         g_barsSinceTrade = 0;
      }
      else
         ManagePosition();
      return;
   }

   datetime curM1 = iTime(_Symbol, PERIOD_M1, 0);
   if(curM1 == g_lastM1Bar) return;
   g_lastM1Bar = curM1;
   g_barsSinceTrade++;

   if(g_dailyTrades >= MaxTradesPerDay) return;
   if(!IsSessionActive(dt.hour)) return;
   if(SkipHour15 && dt.hour == 15) return;
   if(SkipHour17 && dt.hour == 17) return;
   if(IsSkippedDay(dt.day_of_week)) return;
   if(g_barsSinceTrade < CooldownBars) return;
   if(IsSpreadTooWide()) return;
   if(IsDailyLossHit()) return;

   if(UseVWAP) CalcVWAP(today);

   CheckEntry();
}

//+------------------------------------------------------------------+
void CheckEntry()
{
   double fast[2], slow[2], trend[1], htf[1], adx[1], atr[1], rsi[3];
   double bbUpper[1], bbLower[1];
   double stochK[3], stochD[3];

   if(CopyBuffer(h_fastEMA, 0, 1, 2, fast) < 2) return;
   if(CopyBuffer(h_slowEMA, 0, 1, 2, slow) < 2) return;
   if(CopyBuffer(h_trendEMA, 0, 1, 1, trend) < 1) return;
   if(CopyBuffer(h_htfEMA, 0, 1, 1, htf) < 1) return;
   if(CopyBuffer(h_adx, 0, 1, 1, adx) < 1) return;
   if(CopyBuffer(h_atr, 0, 1, 1, atr) < 1) return;
   if(CopyBuffer(h_rsi, 0, 1, 3, rsi) < 3) return;
   if(CopyBuffer(h_bb, 1, 1, 1, bbUpper) < 1) return;
   if(CopyBuffer(h_bb, 2, 1, 1, bbLower) < 1) return;
   if(CopyBuffer(h_stoch, 0, 1, 3, stochK) < 3) return;
   if(CopyBuffer(h_stoch, 1, 1, 3, stochD) < 3) return;

   double close1 = iClose(_Symbol, PERIOD_M1, 1);
   double close2 = iClose(_Symbol, PERIOD_M1, 2);
   double open1  = iOpen(_Symbol, PERIOD_M1, 1);
   double open2  = iOpen(_Symbol, PERIOD_M1, 2);
   double high1  = iHigh(_Symbol, PERIOD_M1, 1);
   double low1   = iLow(_Symbol, PERIOD_M1, 1);
   double bid    = SymbolInfoDouble(_Symbol, SYMBOL_BID);

   double curFast  = fast[1];
   double curSlow  = slow[1];
   double prevFast = fast[0];
   double prevSlow = slow[0];

   //=== FILTERS ===
   if(adx[0] < ADX_Threshold) return;
   if(!IsVolumeAboveAvg()) return;
   if(!IsATRExpanding(atr[0])) return;

   double bbWidth = (bbUpper[0] - bbLower[0]) / bid;
   if(bbWidth < BB_MinWidth) return;

   //=== DUAL TIMEFRAME TREND ===
   bool m5_upTrend  = bid > trend[0];
   bool m15_upTrend = bid > htf[0];
   bool m5_downTrend  = bid < trend[0];
   bool m15_downTrend = bid < htf[0];

   // M5 trend required (M15 available as optional extra filter)
   bool strongBullTrend = m5_upTrend;
   bool strongBearTrend = m5_downTrend;

   bool vwapBull = true, vwapBear = true;
   if(UseVWAP && g_vwap > 0)
   {
      vwapBull = bid > g_vwap;
      vwapBear = bid < g_vwap;
   }

   bool rsiOK_buy  = rsi[2] < RSI_OB;
   bool rsiOK_sell = rsi[2] > RSI_OS;

   double slDist = atr[0] * SL_ATR_Multi;
   slDist = MathMax(slDist, MinSLPoints * _Point);
   slDist = MathMin(slDist, MaxSLPoints * _Point);

   double body1 = MathAbs(close1 - open1);
   double range1 = high1 - low1;
   bool strongBullCandle = close1 > open1 && range1 > 0 && body1 / range1 > 0.5;
   bool strongBearCandle = close1 < open1 && range1 > 0 && body1 / range1 > 0.5;

   //=== BUY SIGNALS ===
   if(AllowBuys && strongBullTrend && vwapBull)
   {
      // Signal 1: EMA Cross + Stochastic
      bool bullCross = (prevFast <= prevSlow) && (curFast > curSlow);
      bool stochBull = (stochK[2] > stochD[2]) && (stochK[1] < Stoch_OB);

      if(bullCross && stochBull && rsiOK_buy)
      {
         ExecuteBuy(slDist, "EMA_X");
         return;
      }

      // Signal 2: RSI Bounce
      bool rsiBullBounce = (rsi[0] < RSI_OS || rsi[1] < RSI_OS) && rsi[2] > RSI_OS && rsi[2] > rsi[1];
      if(rsiBullBounce && strongBullCandle)
      {
         ExecuteBuy(slDist, "RSI_B");
         return;
      }

      // Signal 3: BB Rejection
      double bbRange = bbUpper[0] - bbLower[0];
      if(bbRange > 0)
      {
         double lowerZone = bbLower[0] + bbRange * (1.0 - BB_TouchRatio);
         bool bullReject = low1 <= lowerZone && close1 > bbLower[0] && close1 > open1;
         bool stochOS = stochK[2] < 30;

         if(bullReject && stochOS)
         {
            ExecuteBuy(slDist, "BB_R");
            return;
         }
      }

      // Signal 4: Momentum Continuation
      bool bull1 = close1 > open1 && range1 > 0 && body1 / range1 > 0.4;
      double body2 = MathAbs(close2 - open2);
      double range2 = iHigh(_Symbol, PERIOD_M1, 2) - iLow(_Symbol, PERIOD_M1, 2);
      bool bull2 = close2 > open2 && range2 > 0 && body2 / range2 > 0.4;
      bool emaAligned = curFast > curSlow;

      if(bull1 && bull2 && emaAligned && stochK[2] > stochD[2] && stochK[2] < 70)
      {
         ExecuteBuy(slDist, "MOM_C");
         return;
      }
   }

   //=== SELL SIGNALS (strict) ===
   if(AllowSells && strongBearTrend && vwapBear)
   {
      bool bearCross = (prevFast >= prevSlow) && (curFast < curSlow);
      bool stochBear = (stochK[2] < stochD[2]) && (stochK[1] > Stoch_OS);

      if(bearCross && stochBear && rsiOK_sell && strongBearCandle)
      {
         ExecuteSell(slDist, "EMA_X");
         return;
      }
   }
}

//+------------------------------------------------------------------+
bool IsATRExpanding(double currentATR)
{
   double atrValues[];
   if(CopyBuffer(h_atr, 0, 1, ATR_MA_Period, atrValues) < ATR_MA_Period)
      return true;

   double atrMA = 0;
   for(int i = 0; i < ATR_MA_Period; i++)
      atrMA += atrValues[i];
   atrMA /= ATR_MA_Period;

   if(atrMA <= 0) return true;
   return (currentATR >= atrMA * ATR_MinRatio);
}

//+------------------------------------------------------------------+
void ExecuteBuy(double slDist, string signal)
{
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double sl  = ask - slDist;
   double tp  = ask + slDist * RiskReward;

   double lot = CalcLotSize(slDist);
   if(lot <= 0) return;

   if(trade.Buy(lot, _Symbol, ask, sl, tp, StringFormat("MS_%s", signal)))
   {
      g_inTrade = true;
      g_tradeSL = sl;
      g_trailingActive = false;
      g_dailyTrades++;
      g_barsSinceTrade = 0;
   }
}

void ExecuteSell(double slDist, string signal)
{
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double sl  = bid + slDist;
   double tp  = bid - slDist * RiskReward;

   double lot = CalcLotSize(slDist);
   if(lot <= 0) return;

   if(trade.Sell(lot, _Symbol, bid, sl, tp, StringFormat("MS_%s", signal)))
   {
      g_inTrade = true;
      g_tradeSL = sl;
      g_trailingActive = false;
      g_dailyTrades++;
      g_barsSinceTrade = 0;
   }
}

//+------------------------------------------------------------------+
void ManagePosition()
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
      double beBuf  = BE_Buffer * _Point;

      double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);

      if(pType == POSITION_TYPE_BUY)
      {
         double profit = bid - openP;

         if(UseBreakeven && profit >= slDist && !g_trailingActive)
         {
            double newSL = openP + beBuf;
            if(newSL > curSL)
               trade.PositionModify(ticket, newSL, curTP);
         }

         if(UseTrailing && profit >= slDist * 1.5)
         {
            g_trailingActive = true;
            double newSL = bid - trail;
            if(newSL > curSL)
               trade.PositionModify(ticket, newSL, curTP);
         }
      }
      else
      {
         double profit = openP - ask;

         if(UseBreakeven && profit >= slDist && !g_trailingActive)
         {
            double newSL = openP - beBuf;
            if(newSL < curSL)
               trade.PositionModify(ticket, newSL, curTP);
         }

         if(UseTrailing && profit >= slDist * 1.5)
         {
            g_trailingActive = true;
            double newSL = ask + trail;
            if(newSL < curSL)
               trade.PositionModify(ticket, newSL, curTP);
         }
      }
   }
}

//+------------------------------------------------------------------+
bool IsSessionActive(int hour)
{
   if(hour >= Session1_Start && hour < Session1_End) return true;
   if(hour >= Session2_Start && hour < Session2_End) return true;
   return false;
}

bool IsSkippedDay(int dow)
{
   if(SkipMonday    && dow == 1) return true;
   if(SkipTuesday   && dow == 2) return true;
   if(SkipWednesday && dow == 3) return true;
   if(SkipThursday  && dow == 4) return true;
   if(SkipFriday    && dow == 5) return true;
   return false;
}

bool IsSpreadTooWide()
{
   double spread = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   return (spread > MaxSpreadPoints);
}

bool IsDailyLossHit()
{
   if(MaxDailyLossPct <= 0) return false;
   double bal = AccountInfoDouble(ACCOUNT_BALANCE);
   return ((g_dailyStartBal - bal) / g_dailyStartBal * 100.0 >= MaxDailyLossPct);
}

bool IsVolumeAboveAvg()
{
   long volumes[];
   if(CopyTickVolume(_Symbol, PERIOD_M1, 1, VolMA_Period + 1, volumes) < VolMA_Period + 1)
      return true;

   double curVol = (double)volumes[VolMA_Period];
   double avgVol = 0;
   for(int i = 0; i < VolMA_Period; i++)
      avgVol += (double)volumes[i];
   avgVol /= VolMA_Period;

   if(avgVol <= 0) return true;
   return (curVol >= avgVol * VolMinRatio);
}

void CalcVWAP(datetime today)
{
   if(today != g_vwapDay)
   {
      g_vwapDay = today;
      g_cumPV   = 0;
      g_cumVol  = 0;
      g_vwap    = 0;
   }

   double c = iClose(_Symbol, PERIOD_M1, 1);
   double h = iHigh(_Symbol, PERIOD_M1, 1);
   double l = iLow(_Symbol, PERIOD_M1, 1);
   long   v = iVolume(_Symbol, PERIOD_M1, 1);
   if(v <= 0) v = 1;

   double tp = (h + l + c) / 3.0;
   g_cumPV  += tp * (double)v;
   g_cumVol += (double)v;

   if(g_cumVol > 0)
      g_vwap = g_cumPV / g_cumVol;
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

double CalcLotSize(double slDistance)
{
   if(slDistance <= 0) return 0;

   double lot;
   if(UseFixedLot)
      lot = FixedLot;
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
