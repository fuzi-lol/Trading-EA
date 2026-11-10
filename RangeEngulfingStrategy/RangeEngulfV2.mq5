//+------------------------------------------------------------------+
//|                                        RangeEngulfV2.mq5         |
//|  Range: 12:30-5:30 PM IST, Entry only 7:00-7:04 PM IST          |
//|  Engulfing candle entry with 1:2 RR                              |
//+------------------------------------------------------------------+
#property copyright "RangeEngulfing"
#property version   "2.00"

#include <Trade\Trade.mqh>

//--- Inputs: Range Window (server time UTC+2)
// IST 12:30 PM = UTC+2 09:00, IST 5:30 PM = UTC+2 14:00
input int      RangeStartHour  = 9;      // Range start hour (server)
input int      RangeStartMin   = 0;      // Range start minute
input int      RangeEndHour    = 14;     // Range end hour (server)
input int      RangeEndMin     = 0;      // Range end minute

//--- Inputs: Entry Window (server time UTC+2)
// IST 7:00 PM = UTC+2 15:30, IST 7:04 PM = UTC+2 15:34
input int      EntryStartHour  = 15;     // Entry window start hour
input int      EntryStartMin   = 30;     // Entry window start minute
input int      EntryEndHour    = 15;     // Entry window end hour
input int      EntryEndMin     = 34;     // Entry window end minute

//--- Inputs: Trade
input double   LotSize         = 0.10;   // Lot size
input double   RR_Ratio        = 2.0;    // Risk:Reward ratio (1:X)
input double   SLBufferPips    = 1.0;    // SL buffer beyond engulfing H/L
input int      MaxTradesPerDay = 1;      // Max trades per day

//--- Inputs: Engulfing Filter
input double   MinEngulfPips   = 3.0;    // Min engulfing body size (pips)
input double   MaxEngulfPips   = 30.0;   // Max engulfing body (skip news)

input int      MagicNumber     = 314160; // Magic number

//--- State
enum ESTATE { ST_WAIT_RANGE, ST_MARKING, ST_WAIT_WINDOW, ST_SCANNING, ST_IN_TRADE, ST_DONE };

//--- Globals
CTrade   trade;
ESTATE   gState;
datetime gDay;
double   gPipSize;

double   gRangeHigh, gRangeLow;
int      gTradesToday;

//+------------------------------------------------------------------+
int OnInit()
{
   trade.SetExpertMagicNumber(MagicNumber);
   trade.SetDeviationInPoints(30);
   gPipSize = (_Digits >= 2 && _Digits <= 5) ? _Point * 10 : _Point;
   gState = ST_WAIT_RANGE;
   gDay = 0;
   gTradesToday = 0;
   gRangeHigh = 0;
   gRangeLow = 0;

   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
void OnDeinit(const int reason) {}

//+------------------------------------------------------------------+
void OnTick()
{
   datetime today = iTime(_Symbol, PERIOD_D1, 0);
   if(today != gDay)
   {
      gDay = today;
      gState = ST_WAIT_RANGE;
      gTradesToday = 0;
      gRangeHigh = 0;
      gRangeLow = 0;
   }

   MqlDateTime dt;
   TimeCurrent(dt);
   int nowMins = dt.hour * 60 + dt.min;

   int rangeStartMins = RangeStartHour * 60 + RangeStartMin;
   int rangeEndMins   = RangeEndHour * 60 + RangeEndMin;
   int entryStartMins = EntryStartHour * 60 + EntryStartMin;
   int entryEndMins   = EntryEndHour * 60 + EntryEndMin;

   switch(gState)
   {
      case ST_WAIT_RANGE:
         if(nowMins >= rangeStartMins)
            gState = ST_MARKING;
         break;

      case ST_MARKING:
         if(nowMins >= rangeEndMins)
         {
            MarkRange(dt);
            gState = ST_WAIT_WINDOW;
         }
         break;

      case ST_WAIT_WINDOW:
         if(nowMins >= entryStartMins)
            gState = ST_SCANNING;
         if(nowMins > entryEndMins)
            gState = ST_DONE;
         break;

      case ST_SCANNING:
         if(nowMins > entryEndMins)
         {
            gState = ST_DONE;
            break;
         }
         CheckEngulfing();
         break;

      case ST_IN_TRADE:
         if(!HasPosition())
         {
            gTradesToday++;
            if(gTradesToday >= MaxTradesPerDay)
               gState = ST_DONE;
            else if(nowMins <= entryEndMins)
               gState = ST_SCANNING;
            else
               gState = ST_DONE;
         }
         break;

      case ST_DONE:
         break;
   }
}

//+------------------------------------------------------------------+
void MarkRange(MqlDateTime &dt)
{
   string dateStr = TimeToString(TimeCurrent(), TIME_DATE);
   datetime rangeStart = StringToTime(dateStr + " " +
      IntegerToString(RangeStartHour, 2, '0') + ":" +
      IntegerToString(RangeStartMin, 2, '0') + ":00");
   datetime rangeEnd = StringToTime(dateStr + " " +
      IntegerToString(RangeEndHour, 2, '0') + ":" +
      IntegerToString(RangeEndMin, 2, '0') + ":00");

   MqlRates bars[];
   ArraySetAsSeries(bars, false);
   int copied = CopyRates(_Symbol, PERIOD_M1, rangeStart, rangeEnd, bars);
   if(copied < 1) return;

   gRangeHigh = bars[0].high;
   gRangeLow  = bars[0].low;
   for(int i = 1; i < copied; i++)
   {
      if(bars[i].high > gRangeHigh) gRangeHigh = bars[i].high;
      if(bars[i].low  < gRangeLow)  gRangeLow  = bars[i].low;
   }

   Print("Range: High=", gRangeHigh, " Low=", gRangeLow,
         " Width=", DoubleToString((gRangeHigh - gRangeLow) / gPipSize, 1), " pips");
}

//+------------------------------------------------------------------+
void CheckEngulfing()
{
   if(gRangeHigh == 0) return;

   MqlRates bars[];
   ArraySetAsSeries(bars, true);
   if(CopyRates(_Symbol, PERIOD_M1, 1, 2, bars) != 2) return;

   static datetime lastBar = 0;
   if(bars[0].time == lastBar) return;

   double prevOpen  = bars[1].open;
   double prevClose = bars[1].close;
   double currOpen  = bars[0].open;
   double currClose = bars[0].close;

   bool prevBear = prevClose < prevOpen;
   bool prevBull = prevClose > prevOpen;
   bool currBull = currClose > currOpen;
   bool currBear = currClose < currOpen;

   double bodyPips = MathAbs(currClose - currOpen) / gPipSize;
   if(bodyPips < MinEngulfPips || bodyPips > MaxEngulfPips) return;

   double price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   int zone = 0;
   if(price > gRangeHigh) zone = 1;
   else if(price < gRangeLow) zone = -1;

   // Bullish engulfing
   bool bullEngulf = currBull && prevBear &&
                     currClose > prevOpen && currOpen < prevClose;

   // Bearish engulfing
   bool bearEngulf = currBear && prevBull &&
                     currClose < prevOpen && currOpen > prevClose;

   if(bullEngulf && zone <= 0)
   {
      lastBar = bars[0].time;
      double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      double sl = NormalizeDouble(bars[0].low - SLBufferPips * gPipSize, _Digits);
      double slDist = entry - sl;
      if(slDist <= 0) return;
      double tp = NormalizeDouble(entry + RR_Ratio * slDist, _Digits);

      if(trade.Buy(LotSize, _Symbol, entry, sl, tp, "RE Buy"))
      {
         gState = ST_IN_TRADE;
         Print("BUY: entry=", entry, " sl=", sl, " tp=", tp);
      }
   }
   else if(bearEngulf && zone >= 0)
   {
      lastBar = bars[0].time;
      double entry = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      double sl = NormalizeDouble(bars[0].high + SLBufferPips * gPipSize, _Digits);
      double slDist = sl - entry;
      if(slDist <= 0) return;
      double tp = NormalizeDouble(entry - RR_Ratio * slDist, _Digits);

      if(trade.Sell(LotSize, _Symbol, entry, sl, tp, "RE Sell"))
      {
         gState = ST_IN_TRADE;
         Print("SELL: entry=", entry, " sl=", sl, " tp=", tp);
      }
   }
}

//+------------------------------------------------------------------+
bool HasPosition()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
      if(PositionGetSymbol(i) == _Symbol && PositionGetInteger(POSITION_MAGIC) == MagicNumber)
         return true;
   return false;
}
//+------------------------------------------------------------------+
