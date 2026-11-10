//+------------------------------------------------------------------+
//|                                         GoldLondonV3.mq5         |
//|           Gold London Strategy - Optimized V3 (Trend-Aligned)    |
//+------------------------------------------------------------------+

#property version   "3.00"

#include <Trade\Trade.mqh>

//--- Inputs
input int      LondonOpenHour  = 10;     // London open hour (server time)
input int      SessionEndHour  = 16;     // Stop looking for trades after this hour
input double   LotSize         = 0.10;   // Lot size
input double   SLBufferPips    = 3.0;    // SL buffer below/above FVG (pips)
input double   MinRR           = 2.0;    // Minimum R:R to take trade
input int      MaxTradesPerDay = 1;      // Max trades per day
input int      FVG_Lookback    = 30;     // Bars to scan for FVG
input double   MinFVGPips      = 3.0;    // Min FVG width (pips)
input int      MagicNumber     = 271830; // Magic number

//--- State machine
enum ESTATE { ST_RANGE, ST_GRAB, ST_FVG, ST_RETEST, ST_INTRADE, ST_DONE };

//--- Globals
CTrade   trade;
ESTATE   gState;
datetime gDay;
double   gPipSize;
int      gEmaH1Handle, gEmaDailyHandle;

double   gRangeHigh, gRangeLow;
int      gBias;
double   gFVG_Top, gFVG_Bottom;
int      gTradesToday;

//+------------------------------------------------------------------+
int OnInit()
{
   trade.SetExpertMagicNumber(MagicNumber);
   trade.SetDeviationInPoints(30);
   gPipSize = (_Digits >= 2 && _Digits <= 5) ? _Point * 10 : _Point;
   gState = ST_RANGE;
   gDay = 0;
   gTradesToday = 0;
   gBias = 0;

   gEmaH1Handle    = iMA(_Symbol, PERIOD_H1, 50, 0, MODE_EMA, PRICE_CLOSE);
   gEmaDailyHandle = iMA(_Symbol, PERIOD_D1, 20, 0, MODE_EMA, PRICE_CLOSE);
   if(gEmaH1Handle == INVALID_HANDLE || gEmaDailyHandle == INVALID_HANDLE)
      return INIT_FAILED;

   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   if(gEmaH1Handle != INVALID_HANDLE)    IndicatorRelease(gEmaH1Handle);
   if(gEmaDailyHandle != INVALID_HANDLE) IndicatorRelease(gEmaDailyHandle);
}

//+------------------------------------------------------------------+
void OnTick()
{
   datetime today = iTime(_Symbol, PERIOD_D1, 0);
   if(today != gDay)
   {
      gDay = today;
      gState = ST_RANGE;
      gTradesToday = 0;
      gBias = 0;
      gRangeHigh = 0;
      gRangeLow = 0;
      gFVG_Top = 0;
      gFVG_Bottom = 0;
   }

   MqlDateTime dt;
   TimeCurrent(dt);

   switch(gState)
   {
      case ST_RANGE:   DoMarkRange(dt); break;
      case ST_GRAB:    if(dt.hour >= SessionEndHour) { gState = ST_DONE; break; } DoCheckGrab(); break;
      case ST_FVG:     if(dt.hour >= SessionEndHour) { gState = ST_DONE; break; } DoScanFVG(); break;
      case ST_RETEST:  if(dt.hour >= SessionEndHour) { gState = ST_DONE; break; } DoRetest(); break;
      case ST_INTRADE:
         if(!HasPos())
         {
            gTradesToday++;
            gState = (gTradesToday >= MaxTradesPerDay) ? ST_DONE : ST_GRAB;
         }
         break;
      case ST_DONE: break;
   }
}

//+------------------------------------------------------------------+
void DoMarkRange(MqlDateTime &dt)
{
   if(dt.hour < LondonOpenHour + 1) return;

   string dateStr = TimeToString(TimeCurrent(), TIME_DATE);
   datetime rangeBarTime = StringToTime(dateStr + " " +
      IntegerToString(LondonOpenHour, 2, '0') + ":00:00");

   MqlRates h1[];
   ArraySetAsSeries(h1, false);
   if(CopyRates(_Symbol, PERIOD_H1, rangeBarTime, rangeBarTime, h1) < 1) return;

   gRangeHigh = h1[0].high;
   gRangeLow  = h1[0].low;
   double rangeW = (gRangeHigh - gRangeLow) / gPipSize;

   // Skip abnormal ranges (too tight = noise, too wide = news candle)
   if(rangeW < 8 || rangeW > 60)
   {
      gState = ST_DONE;
      return;
   }

   gState = ST_GRAB;
}

//+------------------------------------------------------------------+
// Returns: 1=bullish, -1=bearish, 0=neutral
//+------------------------------------------------------------------+
int GetMacroBias()
{
   double emaH1[], emaD[];
   ArraySetAsSeries(emaH1, true);
   ArraySetAsSeries(emaD, true);
   if(CopyBuffer(gEmaH1Handle, 0, 0, 1, emaH1) != 1) return 0;
   if(CopyBuffer(gEmaDailyHandle, 0, 0, 1, emaD) != 1) return 0;

   double price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   int score = 0;
   if(price > emaH1[0]) score++; else score--;
   if(price > emaD[0])  score++; else score--;

   if(score >= 1) return 1;
   if(score <= -1) return -1;
   return 0;
}

//+------------------------------------------------------------------+
void DoCheckGrab()
{
   MqlRates bar[];
   ArraySetAsSeries(bar, false);
   if(CopyRates(_Symbol, PERIOD_M5, 1, 1, bar) != 1) return;

   double minGrab = 2.0 * gPipSize;
   int macro = GetMacroBias();

   // BULLISH grab: wick below range low, close back inside
   // Liquidity grab below = trapped sellers = bullish
   if(bar[0].low < gRangeLow - minGrab && bar[0].close > gRangeLow)
   {
      // BEST: bullish grab + bullish macro = strong confluence
      // OK:   bullish grab + neutral macro = take it
      // SKIP: bullish grab + bearish macro = counter-trend, skip
      if(macro == -1) return;

      gBias = 1;
      gState = ST_FVG;
      return;
   }

   // BEARISH grab: wick above range high, close back inside
   // Liquidity grab above = trapped buyers = bearish
   if(bar[0].high > gRangeHigh + minGrab && bar[0].close < gRangeHigh)
   {
      // BEST: bearish grab + bearish macro = strong confluence
      // OK:   bearish grab + neutral macro = take it
      // SKIP: bearish grab + bullish macro = counter-trend, skip
      if(macro == 1) return;

      gBias = -1;
      gState = ST_FVG;
      return;
   }
}

//+------------------------------------------------------------------+
void DoScanFVG()
{
   MqlRates bars[];
   ArraySetAsSeries(bars, false);
   int copied = CopyRates(_Symbol, PERIOD_M5, 1, FVG_Lookback, bars);
   if(copied < 3) return;

   for(int i = copied - 1; i >= 2; i--)
   {
      double fvgTop = 0, fvgBottom = 0;

      if(gBias == 1)
      {
         fvgBottom = bars[i-2].high;
         fvgTop    = bars[i].low;
      }
      else
      {
         fvgTop    = bars[i-2].low;
         fvgBottom = bars[i].high;
      }

      if(fvgTop <= fvgBottom) continue;

      double fvgW = (fvgTop - fvgBottom) / gPipSize;
      if(fvgW < MinFVGPips || fvgW > 25) continue;

      // FVG must be near the range
      if(fvgBottom < gRangeLow - 10 * gPipSize || fvgTop > gRangeHigh + 10 * gPipSize)
         continue;

      // R:R check
      double slDist = (fvgTop - fvgBottom) + SLBufferPips * gPipSize;
      double tpDist = (gBias == 1) ? (gRangeHigh - fvgTop) : (fvgBottom - gRangeLow);

      if(tpDist > 0 && tpDist / slDist >= MinRR)
      {
         gFVG_Top    = fvgTop;
         gFVG_Bottom = fvgBottom;
         gState = ST_RETEST;
         return;
      }
   }
}

//+------------------------------------------------------------------+
void DoRetest()
{
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);

   if(gBias == 1)
   {
      if(bid <= gFVG_Top && bid >= gFVG_Bottom)
      {
         double entry = ask;
         double sl = NormalizeDouble(gFVG_Bottom - SLBufferPips * gPipSize, _Digits);
         double tp = NormalizeDouble(gRangeHigh, _Digits);
         double slD = entry - sl;
         double tpD = tp - entry;

         if(slD > 0 && tpD / slD >= MinRR)
         {
            if(trade.Buy(LotSize, _Symbol, entry, sl, tp, "LND Buy"))
               gState = ST_INTRADE;
         }
         else gState = ST_FVG;
      }
      else if(bid > gFVG_Top + 10 * gPipSize) gState = ST_FVG;
      else if(bid < gFVG_Bottom - SLBufferPips * gPipSize) gState = ST_GRAB;
   }
   else if(gBias == -1)
   {
      if(ask >= gFVG_Bottom && ask <= gFVG_Top)
      {
         double entry = bid;
         double sl = NormalizeDouble(gFVG_Top + SLBufferPips * gPipSize, _Digits);
         double tp = NormalizeDouble(gRangeLow, _Digits);
         double slD = sl - entry;
         double tpD = entry - tp;

         if(slD > 0 && tpD / slD >= MinRR)
         {
            if(trade.Sell(LotSize, _Symbol, entry, sl, tp, "LND Sell"))
               gState = ST_INTRADE;
         }
         else gState = ST_FVG;
      }
      else if(ask < gFVG_Bottom - 10 * gPipSize) gState = ST_FVG;
      else if(ask > gFVG_Top + SLBufferPips * gPipSize) gState = ST_GRAB;
   }
}

//+------------------------------------------------------------------+
bool HasPos()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
      if(PositionGetSymbol(i) == _Symbol && PositionGetInteger(POSITION_MAGIC) == MagicNumber)
         return true;
   return false;
}
//+------------------------------------------------------------------+
