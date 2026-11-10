//+------------------------------------------------------------------+
//|                                      GoldLondonStrategy.mq5      |
//|           Gold London Strategy [1:5 RR] - Lumen Trades V2       |
//+------------------------------------------------------------------+

#property version   "2.00"

#include <Trade\Trade.mqh>

//--- Inputs: Session
input int      LondonOpenHour  = 10;     // London open hour (server time)
input int      SessionEndHour  = 16;     // Stop looking for trades after this hour

//--- Inputs: Trade
input double   LotSize         = 0.10;   // Lot size
input double   SLBufferPips    = 3.0;    // SL buffer below/above FVG (pips)
input double   MinRR           = 2.0;    // Minimum R:R to take trade
input int      MaxTradesPerDay = 1;      // Max trades per day

//--- Inputs: Direction Filter (0=Both, 1=Buy only, 2=Sell only)
input int      DirectionMode   = 0;      // Direction: 0=Both 1=BuyOnly 2=SellOnly

//--- Inputs: FVG
input int      FVG_Lookback    = 30;     // Bars to scan for FVG
input double   MinFVGPips      = 3.0;    // Minimum FVG width (pips)
input double   MaxFVGPips      = 30.0;   // Maximum FVG width (skip huge gaps)

//--- Inputs: Range Filter
input double   MinRangePips    = 10.0;   // Skip days with tiny range
input double   MaxRangePips    = 80.0;   // Skip days with huge range

//--- Inputs: Trend Filter
input bool     UseTrendFilter  = true;   // Use EMA trend filter
input int      EMA_Period      = 50;     // EMA period (H1)
input int      EMA_Daily       = 20;     // Daily EMA for macro bias

//--- Inputs: Liquidity Grab
input double   MinGrabPips     = 2.0;    // Min wick beyond range to count as grab

input int      MagicNumber     = 271828; // Magic number

//--- State machine
enum ESTATE
{
   STATE_WAIT_RANGE,
   STATE_WAIT_GRAB,
   STATE_WAIT_FVG,
   STATE_WAIT_RETEST,
   STATE_IN_TRADE,
   STATE_DONE
};

//--- Globals
CTrade   trade;
ESTATE   gState;
datetime gDay;
double   gPipSize;
int      gEmaHandle;
int      gEmaDailyHandle;

double   gRangeHigh, gRangeLow;
datetime gRangeTime;
int      gBias;
double   gFVG_Top, gFVG_Bottom;
datetime gFVG_Time;
int      gTradesToday;
double   gEntryPrice, gSL, gTP;

//+------------------------------------------------------------------+
int OnInit()
{
   trade.SetExpertMagicNumber(MagicNumber);
   trade.SetDeviationInPoints(30);

   if(_Digits >= 2 && _Digits <= 5)
      gPipSize = _Point * 10;
   else
      gPipSize = _Point;

   gState       = STATE_WAIT_RANGE;
   gDay         = 0;
   gTradesToday = 0;
   gBias        = 0;

   if(UseTrendFilter)
   {
      gEmaHandle = iMA(_Symbol, PERIOD_H1, EMA_Period, 0, MODE_EMA, PRICE_CLOSE);
      gEmaDailyHandle = iMA(_Symbol, PERIOD_D1, EMA_Daily, 0, MODE_EMA, PRICE_CLOSE);
      if(gEmaHandle == INVALID_HANDLE || gEmaDailyHandle == INVALID_HANDLE)
         return INIT_FAILED;
   }

   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   if(UseTrendFilter)
   {
      if(gEmaHandle != INVALID_HANDLE) IndicatorRelease(gEmaHandle);
      if(gEmaDailyHandle != INVALID_HANDLE) IndicatorRelease(gEmaDailyHandle);
   }
}

//+------------------------------------------------------------------+
void OnTick()
{
   datetime today = iTime(_Symbol, PERIOD_D1, 0);
   if(today != gDay)
   {
      gDay         = today;
      gState       = STATE_WAIT_RANGE;
      gTradesToday = 0;
      gBias        = 0;
      gRangeHigh   = 0;
      gRangeLow    = 0;
      gFVG_Top     = 0;
      gFVG_Bottom  = 0;
   }

   MqlDateTime dt;
   TimeCurrent(dt);

   switch(gState)
   {
      case STATE_WAIT_RANGE:   CheckOpeningRange(dt); break;
      case STATE_WAIT_GRAB:    if(dt.hour >= SessionEndHour) { gState = STATE_DONE; break; } CheckLiquidityGrab(); break;
      case STATE_WAIT_FVG:     if(dt.hour >= SessionEndHour) { gState = STATE_DONE; break; } ScanForFVG(); break;
      case STATE_WAIT_RETEST:  if(dt.hour >= SessionEndHour) { gState = STATE_DONE; break; } CheckFVGRetest(); break;
      case STATE_IN_TRADE:
         if(!HasPosition())
         {
            gTradesToday++;
            if(gTradesToday >= MaxTradesPerDay)
               gState = STATE_DONE;
            else
            {
               gBias = 0;
               gState = STATE_WAIT_GRAB;
            }
         }
         break;
      case STATE_DONE: break;
   }
}

//+------------------------------------------------------------------+
void CheckOpeningRange(MqlDateTime &dt)
{
   int rangeCloseHour = LondonOpenHour + 1;
   if(dt.hour < rangeCloseHour)
      return;

   string dateStr = TimeToString(TimeCurrent(), TIME_DATE);
   datetime rangeBarTime = StringToTime(dateStr + " " +
      IntegerToString(LondonOpenHour, 2, '0') + ":00:00");

   MqlRates h1[];
   ArraySetAsSeries(h1, false);
   int copied = CopyRates(_Symbol, PERIOD_H1, rangeBarTime, rangeBarTime, h1);
   if(copied < 1)
      return;

   gRangeHigh = h1[0].high;
   gRangeLow  = h1[0].low;
   gRangeTime = h1[0].time;

   double rangeWidth = (gRangeHigh - gRangeLow) / gPipSize;

   // Range filter: skip abnormal ranges
   if(rangeWidth < MinRangePips || rangeWidth > MaxRangePips)
   {
      gState = STATE_DONE;
      return;
   }

   gState = STATE_WAIT_GRAB;
}

//+------------------------------------------------------------------+
int GetMacroBias()
{
   if(!UseTrendFilter)
      return 0;

   double ema[], emaD[];
   ArraySetAsSeries(ema, true);
   ArraySetAsSeries(emaD, true);
   if(CopyBuffer(gEmaHandle, 0, 0, 1, ema) != 1) return 0;
   if(CopyBuffer(gEmaDailyHandle, 0, 0, 1, emaD) != 1) return 0;

   double price = SymbolInfoDouble(_Symbol, SYMBOL_BID);

   // Both H1 EMA and Daily EMA must agree
   bool bullish = (price > ema[0] && price > emaD[0]);
   bool bearish = (price < ema[0] && price < emaD[0]);

   if(bullish) return 1;
   if(bearish) return -1;
   return 0;
}

//+------------------------------------------------------------------+
void CheckLiquidityGrab()
{
   MqlRates bar[];
   ArraySetAsSeries(bar, false);
   if(CopyRates(_Symbol, PERIOD_M5, 1, 1, bar) != 1)
      return;

   double minGrab = MinGrabPips * gPipSize;
   int macro = GetMacroBias();

   // Bullish grab: wick below range, close back inside
   if(bar[0].low < gRangeLow - minGrab && bar[0].close > gRangeLow)
   {
      // Direction filter
      if(DirectionMode == 2) return; // sell-only mode, skip buys

      // Trend filter: skip bullish if macro bearish
      if(UseTrendFilter && macro == -1) return;

      gBias = 1;
      gState = STATE_WAIT_FVG;
      return;
   }

   // Bearish grab: wick above range, close back inside
   if(bar[0].high > gRangeHigh + minGrab && bar[0].close < gRangeHigh)
   {
      if(DirectionMode == 1) return; // buy-only mode, skip sells

      if(UseTrendFilter && macro == 1) return;

      gBias = -1;
      gState = STATE_WAIT_FVG;
      return;
   }
}

//+------------------------------------------------------------------+
void ScanForFVG()
{
   MqlRates bars[];
   ArraySetAsSeries(bars, false);
   int copied = CopyRates(_Symbol, PERIOD_M5, 1, FVG_Lookback, bars);
   if(copied < 3)
      return;

   for(int i = copied - 1; i >= 2; i--)
   {
      if(gBias == 1) // Bullish FVG
      {
         double fvgBottom = bars[i-2].high;
         double fvgTop    = bars[i].low;

         if(fvgTop > fvgBottom)
         {
            double fvgWidth = (fvgTop - fvgBottom) / gPipSize;
            if(fvgWidth >= MinFVGPips && fvgWidth <= MaxFVGPips)
            {
               if(fvgBottom >= gRangeLow - 10 * gPipSize && fvgTop <= gRangeHigh + 10 * gPipSize)
               {
                  gFVG_Top    = fvgTop;
                  gFVG_Bottom = fvgBottom;
                  gFVG_Time   = bars[i].time;

                  double slDist = (fvgTop - fvgBottom) + SLBufferPips * gPipSize;
                  double tpDist = gRangeHigh - fvgTop;

                  if(tpDist > 0 && tpDist / slDist >= MinRR)
                  {
                     gState = STATE_WAIT_RETEST;
                     return;
                  }
               }
            }
         }
      }
      else if(gBias == -1) // Bearish FVG
      {
         double fvgTop    = bars[i-2].low;
         double fvgBottom = bars[i].high;

         if(fvgTop > fvgBottom)
         {
            double fvgWidth = (fvgTop - fvgBottom) / gPipSize;
            if(fvgWidth >= MinFVGPips && fvgWidth <= MaxFVGPips)
            {
               if(fvgBottom >= gRangeLow - 10 * gPipSize && fvgTop <= gRangeHigh + 10 * gPipSize)
               {
                  gFVG_Top    = fvgTop;
                  gFVG_Bottom = fvgBottom;
                  gFVG_Time   = bars[i].time;

                  double slDist = (fvgTop - fvgBottom) + SLBufferPips * gPipSize;
                  double tpDist = fvgBottom - gRangeLow;

                  if(tpDist > 0 && tpDist / slDist >= MinRR)
                  {
                     gState = STATE_WAIT_RETEST;
                     return;
                  }
               }
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
void CheckFVGRetest()
{
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);

   if(gBias == 1)
   {
      if(bid <= gFVG_Top && bid >= gFVG_Bottom)
      {
         double entry = ask;
         double sl    = NormalizeDouble(gFVG_Bottom - SLBufferPips * gPipSize, _Digits);
         double tp    = NormalizeDouble(gRangeHigh, _Digits);

         double slDist = entry - sl;
         double tpDist = tp - entry;

         if(slDist > 0 && tpDist / slDist >= MinRR)
         {
            if(trade.Buy(LotSize, _Symbol, entry, sl, tp, "LND Buy FVG"))
            {
               gEntryPrice = trade.ResultPrice();
               gSL = sl; gTP = tp;
               gState = STATE_IN_TRADE;
            }
         }
         else
            gState = STATE_WAIT_FVG;
      }
      else if(bid > gFVG_Top + 10 * gPipSize)
         gState = STATE_WAIT_FVG;
      else if(bid < gFVG_Bottom - SLBufferPips * gPipSize)
         gState = STATE_WAIT_GRAB;
   }
   else if(gBias == -1)
   {
      if(ask >= gFVG_Bottom && ask <= gFVG_Top)
      {
         double entry = bid;
         double sl    = NormalizeDouble(gFVG_Top + SLBufferPips * gPipSize, _Digits);
         double tp    = NormalizeDouble(gRangeLow, _Digits);

         double slDist = sl - entry;
         double tpDist = entry - tp;

         if(slDist > 0 && tpDist / slDist >= MinRR)
         {
            if(trade.Sell(LotSize, _Symbol, entry, sl, tp, "LND Sell FVG"))
            {
               gEntryPrice = trade.ResultPrice();
               gSL = sl; gTP = tp;
               gState = STATE_IN_TRADE;
            }
         }
         else
            gState = STATE_WAIT_FVG;
      }
      else if(ask < gFVG_Bottom - 10 * gPipSize)
         gState = STATE_WAIT_FVG;
      else if(ask > gFVG_Top + SLBufferPips * gPipSize)
         gState = STATE_WAIT_GRAB;
   }
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
