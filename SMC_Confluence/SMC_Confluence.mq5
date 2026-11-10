//+------------------------------------------------------------------+
//|                                      SMC_Confluence V3.mq5       |
//|   Smart Money Confluence: EMA Cross + RSI + ATR SL + FVG + OB    |
//|   Multi-TF trend filter + Breakeven trailing + ICT killzones     |
//+------------------------------------------------------------------+

#property version   "3.00"
#property strict

#include <Trade\Trade.mqh>

//=== INPUTS =========================================================
//--- EMA Crossover (Signal TF)
input int      FastEMA_Period    = 9;        // Fast EMA period
input int      SlowEMA_Period    = 21;       // Slow EMA period

//--- Higher TF Trend Filter
input int      TrendEMA_Period   = 50;       // H1 EMA for trend direction
input int      TrendEMA_Period2  = 200;      // H1 EMA 200 for major trend

//--- RSI Filter
input int      RSI_Period        = 14;       // RSI period
input int      RSI_BuyLevel     = 45;       // RSI above this for buys
input int      RSI_SellLevel    = 55;       // RSI below this for sells
input int      RSI_OB           = 80;       // RSI overbought (skip buys)
input int      RSI_OS           = 20;       // RSI oversold (skip sells)

//--- ATR Stop Loss
input int      ATR_Period        = 14;       // ATR period
input double   ATR_SL_Multi     = 1.5;      // ATR multiplier for SL
input double   RiskReward       = 2.5;      // Risk:Reward ratio (min 1:2)
input double   MinSL_Points     = 200;      // Min SL distance in points
input double   MaxSL_Points     = 1200;     // Max SL distance in points

//--- Breakeven & Trailing
input double   BE_Trigger_RR    = 1.0;      // Move SL to BE at this R multiple
input double   BE_Lock_Points   = 20;       // Points of profit to lock at BE
input double   Trail_Trigger_RR = 2.0;      // Start trailing at this R multiple
input double   Trail_Step_Pts   = 100;      // Trailing step in points

//--- SMC: Fair Value Gap
input int      FVG_Lookback     = 25;       // Bars to scan for FVG
input double   FVG_MinWidth_Pts = 30;       // Min FVG width in points
input double   FVG_MaxDist_ATR  = 2.0;      // Max distance from price to FVG in ATR units

//--- SMC: Order Block
input int      OB_Lookback      = 30;       // Bars to scan for Order Blocks
input double   OB_Disp_Multi    = 1.5;      // Displacement multiplier (bull/bear body ratio)
input double   OB_MaxDist_ATR   = 2.0;      // Max distance from price to OB in ATR units

//--- Session Filter (Server Time hours)
input int      LDN_Start        = 11;       // London killzone start (skip bad early hrs)
input int      LDN_End          = 13;       // London killzone end
input int      NY_Start         = 15;       // NY killzone start
input int      NY_End           = 21;       // NY killzone end
input bool     SkipTuesday      = true;     // Skip trading on Tuesdays

//--- Trade Management
input double   LotSize          = 0.10;     // Lot size
input int      MaxTradesPerDay  = 2;        // Max trades per day
input int      MagicNumber      = 888003;   // Magic number
input int      MaxSpreadPts     = 50;       // Max spread in points
input int      CooldownBars     = 6;        // Bars to wait after a losing trade

//=== GLOBALS ========================================================
CTrade   trade;
int      hFastEMA, hSlowEMA, hRSI, hATR;
int      hTrendEMA50, hTrendEMA200;
int      hRSI_H1;
datetime gDay;
int      gTradesToday;
datetime gLastLossTime;
double   gLastEntrySL;     // Store SL distance for BE/trail calc

//=== STRUCTURES =====================================================
struct FVGZone
{
   double top;
   double bottom;
   bool   bullish;
   int    barIndex;
};

struct OrderBlock
{
   double high;
   double low;
   bool   bullish;
   int    barIndex;
};

//+------------------------------------------------------------------+
int OnInit()
{
   trade.SetExpertMagicNumber(MagicNumber);
   trade.SetDeviationInPoints(30);

   // Signal timeframe indicators (M15)
   hFastEMA = iMA(_Symbol, PERIOD_M15, FastEMA_Period, 0, MODE_EMA, PRICE_CLOSE);
   hSlowEMA = iMA(_Symbol, PERIOD_M15, SlowEMA_Period, 0, MODE_EMA, PRICE_CLOSE);
   hRSI     = iRSI(_Symbol, PERIOD_M15, RSI_Period, PRICE_CLOSE);
   hATR     = iATR(_Symbol, PERIOD_M15, ATR_Period);

   // Higher TF trend filter (H1)
   hTrendEMA50  = iMA(_Symbol, PERIOD_H1, TrendEMA_Period, 0, MODE_EMA, PRICE_CLOSE);
   hTrendEMA200 = iMA(_Symbol, PERIOD_H1, TrendEMA_Period2, 0, MODE_EMA, PRICE_CLOSE);
   hRSI_H1      = iRSI(_Symbol, PERIOD_H1, RSI_Period, PRICE_CLOSE);

   if(hFastEMA == INVALID_HANDLE || hSlowEMA == INVALID_HANDLE ||
      hRSI == INVALID_HANDLE || hATR == INVALID_HANDLE ||
      hTrendEMA50 == INVALID_HANDLE || hTrendEMA200 == INVALID_HANDLE ||
      hRSI_H1 == INVALID_HANDLE)
   {
      Print("Failed to create indicator handles");
      return INIT_FAILED;
   }

   gDay = 0;
   gTradesToday = 0;
   gLastLossTime = 0;
   gLastEntrySL = 0;

   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   if(hFastEMA != INVALID_HANDLE)      IndicatorRelease(hFastEMA);
   if(hSlowEMA != INVALID_HANDLE)      IndicatorRelease(hSlowEMA);
   if(hRSI != INVALID_HANDLE)          IndicatorRelease(hRSI);
   if(hATR != INVALID_HANDLE)          IndicatorRelease(hATR);
   if(hTrendEMA50 != INVALID_HANDLE)   IndicatorRelease(hTrendEMA50);
   if(hTrendEMA200 != INVALID_HANDLE)  IndicatorRelease(hTrendEMA200);
   if(hRSI_H1 != INVALID_HANDLE)      IndicatorRelease(hRSI_H1);
}

//+------------------------------------------------------------------+
void OnTick()
{
   //--- New day reset
   datetime today = iTime(_Symbol, PERIOD_D1, 0);
   if(today != gDay)
   {
      gDay = today;
      gTradesToday = 0;
   }

   //--- Manage existing positions (breakeven + trailing)
   ManagePositions();

   //--- Guards for new entries
   if(gTradesToday >= MaxTradesPerDay) return;
   if(!IsNewBar()) return;
   if(!InKillzone()) return;
   if((int)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD) > MaxSpreadPts) return;
   if(HasOpenPosition()) return;

   //--- Cooldown after loss
   if(gLastLossTime > 0)
   {
      datetime barTime = iTime(_Symbol, PERIOD_CURRENT, 0);
      if(barTime < gLastLossTime + CooldownBars * PeriodSeconds(PERIOD_CURRENT))
         return;
   }

   //--- Get M15 indicator values (bar 1 = last closed)
   double fastEMA[3], slowEMA[3], rsi[2], atr[2];
   if(CopyBuffer(hFastEMA, 0, 1, 3, fastEMA) < 3) return;
   if(CopyBuffer(hSlowEMA, 0, 1, 3, slowEMA) < 3) return;
   if(CopyBuffer(hRSI, 0, 1, 2, rsi) < 2) return;
   if(CopyBuffer(hATR, 0, 1, 2, atr) < 2) return;

   // CopyBuffer returns oldest first: [0]=oldest, [2]=newest for 3 elements
   double curFast  = fastEMA[2];
   double prevFast = fastEMA[1];
   double curSlow  = slowEMA[2];
   double prevSlow = slowEMA[1];
   double curRSI   = rsi[1];      // newest of 2
   double curATR   = atr[1];

   //--- Get H1 trend filter
   double trendEma50[2], trendEma200[2], rsiH1[2];
   if(CopyBuffer(hTrendEMA50, 0, 1, 2, trendEma50) < 2) return;
   if(CopyBuffer(hTrendEMA200, 0, 1, 2, trendEma200) < 2) return;
   if(CopyBuffer(hRSI_H1, 0, 1, 2, rsiH1) < 2) return;

   double h1Ema50  = trendEma50[1];
   double h1Ema200 = trendEma200[1];
   double h1RSI    = rsiH1[1];
   double curPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);

   //--- H1 Trend determination
   bool h1Bullish = (curPrice > h1Ema50) && (h1Ema50 > h1Ema200);
   bool h1Bearish = (curPrice < h1Ema50) && (h1Ema50 < h1Ema200);

   // Relaxed: at least price above/below EMA50
   bool h1BullishRelaxed = (curPrice > h1Ema50);
   bool h1BearishRelaxed = (curPrice < h1Ema50);

   //--- Detect EMA crossover on M15
   bool bullishCross = (prevFast <= prevSlow) && (curFast > curSlow);
   bool bearishCross = (prevFast >= prevSlow) && (curFast < curSlow);

   if(!bullishCross && !bearishCross) return;

   //--- Trend alignment filter
   if(bullishCross && !h1BullishRelaxed) return;
   if(bearishCross && !h1BearishRelaxed) return;

   //--- RSI filter (M15 + H1 alignment)
   if(bullishCross)
   {
      if(curRSI < RSI_BuyLevel || curRSI > RSI_OB) return;
      if(h1RSI < 40) return;  // H1 RSI should support bullish bias
   }
   if(bearishCross)
   {
      if(curRSI > RSI_SellLevel || curRSI < RSI_OS) return;
      if(h1RSI > 60) return;  // H1 RSI should support bearish bias
   }

   //--- SMC Confluence: Check for supporting FVG on M5 chart
   bool hasFVG = false;
   FVGZone fvg;
   ZeroMemory(fvg);
   if(bullishCross)
      hasFVG = FindBullishFVG(fvg, curATR);
   else
      hasFVG = FindBearishFVG(fvg, curATR);

   //--- SMC Confluence: Check for supporting Order Block
   bool hasOB = false;
   OrderBlock ob;
   ZeroMemory(ob);
   if(bullishCross)
      hasOB = FindBullishOB(ob, curATR);
   else
      hasOB = FindBearishOB(ob, curATR);

   //--- Need at least one SMC confluence (FVG or OB)
   if(!hasFVG && !hasOB) return;

   //--- Check Break of Structure (BOS) confirmation on M5
   if(!CheckBOS(bullishCross)) return;

   //--- Calculate SL/TP using ATR
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double slDistance = curATR * ATR_SL_Multi;

   // Enforce min/max SL
   if(slDistance < MinSL_Points * _Point)
      slDistance = MinSL_Points * _Point;
   if(slDistance > MaxSL_Points * _Point)
      slDistance = MaxSL_Points * _Point;

   double tpDistance = slDistance * RiskReward;

   if(bullishCross)
   {
      double entry = ask;
      double sl = entry - slDistance;
      double tp = entry + tpDistance;

      // Tighten SL to OB/FVG zone if closer and reasonable
      if(hasOB && ob.low < entry && (entry - ob.low) < slDistance &&
         (entry - ob.low) >= MinSL_Points * _Point)
         sl = NormalizeDouble(ob.low - 10 * _Point, _Digits);

      if(hasFVG && fvg.bottom < entry && (entry - fvg.bottom) < slDistance &&
         (entry - fvg.bottom) >= MinSL_Points * _Point)
      {
         double fvgSL = NormalizeDouble(fvg.bottom - 10 * _Point, _Digits);
         if(fvgSL > sl) sl = fvgSL;  // Use tighter of the two
      }

      // Recalculate TP for minimum RR
      double actualSL = entry - sl;
      tp = NormalizeDouble(entry + (actualSL * RiskReward), _Digits);
      sl = NormalizeDouble(sl, _Digits);

      // Bonus: extra confluence score for logging
      int confluence = (hasFVG ? 1 : 0) + (hasOB ? 1 : 0) + (h1Bullish ? 1 : 0);

      Print("BUY: Entry=", entry, " SL=", sl, " TP=", tp,
            " ATR=", DoubleToString(curATR, 2),
            " RSI_M15=", DoubleToString(curRSI, 1),
            " RSI_H1=", DoubleToString(h1RSI, 1),
            " FVG=", hasFVG, " OB=", hasOB,
            " Confluence=", confluence);

      if(trade.Buy(LotSize, _Symbol, entry, sl, tp, "SMC_Buy"))
      {
         gTradesToday++;
         gLastEntrySL = actualSL;
      }
   }
   else
   {
      double entry = bid;
      double sl = entry + slDistance;
      double tp = entry - tpDistance;

      if(hasOB && ob.high > entry && (ob.high - entry) < slDistance &&
         (ob.high - entry) >= MinSL_Points * _Point)
         sl = NormalizeDouble(ob.high + 10 * _Point, _Digits);

      if(hasFVG && fvg.top > entry && (fvg.top - entry) < slDistance &&
         (fvg.top - entry) >= MinSL_Points * _Point)
      {
         double fvgSL = NormalizeDouble(fvg.top + 10 * _Point, _Digits);
         if(fvgSL < sl) sl = fvgSL;
      }

      double actualSL = sl - entry;
      tp = NormalizeDouble(entry - (actualSL * RiskReward), _Digits);
      sl = NormalizeDouble(sl, _Digits);

      int confluence = (hasFVG ? 1 : 0) + (hasOB ? 1 : 0) + (h1Bearish ? 1 : 0);

      Print("SELL: Entry=", entry, " SL=", sl, " TP=", tp,
            " ATR=", DoubleToString(curATR, 2),
            " RSI_M15=", DoubleToString(curRSI, 1),
            " RSI_H1=", DoubleToString(h1RSI, 1),
            " FVG=", hasFVG, " OB=", hasOB,
            " Confluence=", confluence);

      if(trade.Sell(LotSize, _Symbol, entry, sl, tp, "SMC_Sell"))
      {
         gTradesToday++;
         gLastEntrySL = actualSL;
      }
   }
}

//+------------------------------------------------------------------+
//| Manage open positions: Breakeven + Trailing Stop                  |
//+------------------------------------------------------------------+
void ManagePositions()
{
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

      double slDist = 0;
      if(posType == POSITION_TYPE_BUY)
         slDist = posOpen - posSL;
      else
         slDist = posSL - posOpen;

      if(slDist <= 0) continue;

      double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);

      if(posType == POSITION_TYPE_BUY)
      {
         double profit = bid - posOpen;
         double profitRR = profit / slDist;

         // Breakeven: move SL to entry + small lock
         if(profitRR >= BE_Trigger_RR && posSL < posOpen)
         {
            double newSL = NormalizeDouble(posOpen + BE_Lock_Points * _Point, _Digits);
            if(newSL > posSL)
               trade.PositionModify(ticket, newSL, posTP);
         }
         // Trailing: move SL up as price advances
         else if(profitRR >= Trail_Trigger_RR)
         {
            double trailSL = NormalizeDouble(bid - Trail_Step_Pts * _Point, _Digits);
            if(trailSL > posSL && trailSL > posOpen)
               trade.PositionModify(ticket, trailSL, posTP);
         }
      }
      else // SELL
      {
         double profit = posOpen - ask;
         double profitRR = profit / slDist;

         if(profitRR >= BE_Trigger_RR && posSL > posOpen)
         {
            double newSL = NormalizeDouble(posOpen - BE_Lock_Points * _Point, _Digits);
            if(newSL < posSL)
               trade.PositionModify(ticket, newSL, posTP);
         }
         else if(profitRR >= Trail_Trigger_RR)
         {
            double trailSL = NormalizeDouble(ask + Trail_Step_Pts * _Point, _Digits);
            if(trailSL < posSL && trailSL < posOpen)
               trade.PositionModify(ticket, trailSL, posTP);
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Track closed trades for cooldown logic                            |
//+------------------------------------------------------------------+
void OnTradeTransaction(const MqlTradeTransaction &trans,
                        const MqlTradeRequest &request,
                        const MqlTradeResult &result)
{
   if(trans.type == TRADE_TRANSACTION_DEAL_ADD)
   {
      if(trans.deal_type == DEAL_TYPE_BUY || trans.deal_type == DEAL_TYPE_SELL)
      {
         // Check if this is a closing deal (position exit)
         if(HistoryDealSelect(trans.deal))
         {
            long entry = (long)HistoryDealGetInteger(trans.deal, DEAL_ENTRY);
            if(entry == DEAL_ENTRY_OUT || entry == DEAL_ENTRY_OUT_BY)
            {
               double profit = HistoryDealGetDouble(trans.deal, DEAL_PROFIT);
               if(profit < 0)
                  gLastLossTime = TimeCurrent();
            }
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
bool InKillzone()
{
   MqlDateTime dt;
   TimeCurrent(dt);
   int hour = dt.hour;

   // Skip Tuesday if enabled (historically unprofitable)
   if(SkipTuesday && dt.day_of_week == 2) return false;

   if(hour >= LDN_Start && hour < LDN_End) return true;
   if(hour >= NY_Start  && hour < NY_End)  return true;
   return false;
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
//| Bullish FVG: low[newest] > high[oldest] in 3-candle pattern      |
//| Uses ATR-based max distance for proximity check                   |
//+------------------------------------------------------------------+
bool FindBullishFVG(FVGZone &zone, double atrValue)
{
   MqlRates rates[];
   int copied = CopyRates(_Symbol, PERIOD_CURRENT, 1, FVG_Lookback + 2, rates);
   if(copied < 3) return false;

   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double maxDist = atrValue * FVG_MaxDist_ATR;

   for(int i = copied - 1; i >= 2; i--)
   {
      double gapTop    = rates[i].low;
      double gapBottom = rates[i-2].high;

      if(gapTop > gapBottom)
      {
         double width = gapTop - gapBottom;
         if(width < FVG_MinWidth_Pts * _Point) continue;

         // Check if FVG is unfilled (price hasn't traded through it completely)
         // Simple check: is current price at or near the FVG?
         double midFVG = (gapTop + gapBottom) / 2.0;
         if(MathAbs(ask - midFVG) > maxDist) continue;

         if(ask >= gapBottom)
         {
            zone.top      = gapTop;
            zone.bottom   = gapBottom;
            zone.bullish  = true;
            zone.barIndex = copied - 1 - i;
            return true;
         }
      }
   }
   return false;
}

//+------------------------------------------------------------------+
bool FindBearishFVG(FVGZone &zone, double atrValue)
{
   MqlRates rates[];
   int copied = CopyRates(_Symbol, PERIOD_CURRENT, 1, FVG_Lookback + 2, rates);
   if(copied < 3) return false;

   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double maxDist = atrValue * FVG_MaxDist_ATR;

   for(int i = copied - 1; i >= 2; i--)
   {
      double gapBottom = rates[i].high;
      double gapTop    = rates[i-2].low;

      if(gapTop > gapBottom)
      {
         double width = gapTop - gapBottom;
         if(width < FVG_MinWidth_Pts * _Point) continue;

         double midFVG = (gapTop + gapBottom) / 2.0;
         if(MathAbs(bid - midFVG) > maxDist) continue;

         if(bid <= gapTop)
         {
            zone.top      = gapTop;
            zone.bottom   = gapBottom;
            zone.bullish  = false;
            zone.barIndex = copied - 1 - i;
            return true;
         }
      }
   }
   return false;
}

//+------------------------------------------------------------------+
bool FindBullishOB(OrderBlock &block, double atrValue)
{
   MqlRates rates[];
   int copied = CopyRates(_Symbol, PERIOD_CURRENT, 1, OB_Lookback, rates);
   if(copied < 5) return false;

   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double maxDist = atrValue * OB_MaxDist_ATR;

   for(int i = copied - 2; i >= 1; i--)
   {
      bool isBearish = rates[i].close < rates[i].open;
      if(!isBearish) continue;

      bool nextBullish = rates[i+1].close > rates[i+1].open;
      if(!nextBullish) continue;

      double bearBody = rates[i].open - rates[i].close;
      double bullBody = rates[i+1].close - rates[i+1].open;

      if(bullBody < bearBody * OB_Disp_Multi) continue;

      // Use candle body for tighter OB zone (not wicks)
      double obHigh = rates[i].open;   // body high of bearish candle
      double obLow  = rates[i].close;  // body low of bearish candle

      double midOB = (obHigh + obLow) / 2.0;
      if(MathAbs(ask - midOB) > maxDist) continue;

      if(ask >= obLow && ask <= obHigh + maxDist)
      {
         block.high    = obHigh;
         block.low     = obLow;
         block.bullish = true;
         block.barIndex = copied - 1 - i;
         return true;
      }
   }
   return false;
}

//+------------------------------------------------------------------+
bool FindBearishOB(OrderBlock &block, double atrValue)
{
   MqlRates rates[];
   int copied = CopyRates(_Symbol, PERIOD_CURRENT, 1, OB_Lookback, rates);
   if(copied < 5) return false;

   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double maxDist = atrValue * OB_MaxDist_ATR;

   for(int i = copied - 2; i >= 1; i--)
   {
      bool isBullish = rates[i].close > rates[i].open;
      if(!isBullish) continue;

      bool nextBearish = rates[i+1].close < rates[i+1].open;
      if(!nextBearish) continue;

      double bullBody = rates[i].close - rates[i].open;
      double bearBody = rates[i+1].open - rates[i+1].close;

      if(bearBody < bullBody * OB_Disp_Multi) continue;

      double obHigh = rates[i].close;  // body high of bullish candle
      double obLow  = rates[i].open;   // body low of bullish candle

      double midOB = (obHigh + obLow) / 2.0;
      if(MathAbs(bid - midOB) > maxDist) continue;

      if(bid <= obHigh && bid >= obLow - maxDist)
      {
         block.high    = obHigh;
         block.low     = obLow;
         block.bullish = false;
         block.barIndex = copied - 1 - i;
         return true;
      }
   }
   return false;
}

//+------------------------------------------------------------------+
//| Break of Structure (BOS) on M5 chart                              |
//| Uses 5-bar swing point detection                                  |
//+------------------------------------------------------------------+
bool CheckBOS(bool bullish)
{
   MqlRates rates[];
   int copied = CopyRates(_Symbol, PERIOD_CURRENT, 1, 40, rates);
   if(copied < 12) return false;

   if(bullish)
   {
      for(int i = copied - 3; i >= 2; i--)
      {
         if(rates[i].high > rates[i-1].high && rates[i].high > rates[i+1].high &&
            rates[i].high > rates[i-2].high && rates[i].high > rates[i+2].high)
         {
            if(rates[copied-1].close > rates[i].high)
               return true;
            return false;
         }
      }
   }
   else
   {
      for(int i = copied - 3; i >= 2; i--)
      {
         if(rates[i].low < rates[i-1].low && rates[i].low < rates[i+1].low &&
            rates[i].low < rates[i-2].low && rates[i].low < rates[i+2].low)
         {
            if(rates[copied-1].close < rates[i].low)
               return true;
            return false;
         }
      }
   }

   return false;
}
//+------------------------------------------------------------------+
