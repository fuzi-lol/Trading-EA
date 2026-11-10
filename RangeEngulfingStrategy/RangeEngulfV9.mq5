//+------------------------------------------------------------------+
//|                                        RangeEngulfV9.mq5         |
//|  V8 without reversal: 7:00-7:15 PM IST, 1% risk, max 1 trade    |
//+------------------------------------------------------------------+
#property copyright "RangeEngulfing"
#property version   "9.00"

#include <Trade\Trade.mqh>

input int      RangeStartHour  = 9;
input int      RangeStartMin   = 0;
input int      RangeEndHour    = 14;
input int      RangeEndMin     = 0;
input int      EntryStartHour  = 15;
input int      EntryStartMin   = 30;
input int      EntryEndHour    = 15;
input int      EntryEndMin     = 45;

input double   RiskPercent     = 1.0;
input double   RR_Ratio        = 2.0;
input double   SLBufferPips    = 1.0;
input int      MaxTradesPerDay = 1;
input double   MinEngulfPips   = 3.0;
input double   MaxEngulfPips   = 30.0;
input int      MagicNumber     = 314171;

enum ESTATE { ST_WAIT_RANGE, ST_MARKING, ST_WAIT_WINDOW, ST_SCANNING, ST_IN_TRADE, ST_DONE };

CTrade   trade;
ESTATE   gState;
datetime gDay;
double   gPipSize;
double   gRangeHigh, gRangeLow;
int      gTradesToday;

int OnInit()
{
   trade.SetExpertMagicNumber(MagicNumber);
   trade.SetDeviationInPoints(50);
   gPipSize = (_Digits >= 2 && _Digits <= 5) ? _Point * 10 : _Point;
   gState = ST_WAIT_RANGE;
   gDay = 0;
   gTradesToday = 0;
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason) {}

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

   switch(gState)
   {
      case ST_WAIT_RANGE:
         if(nowMins >= RangeStartHour * 60 + RangeStartMin) gState = ST_MARKING;
         break;
      case ST_MARKING:
         if(nowMins >= RangeEndHour * 60 + RangeEndMin) { MarkRange(); gState = ST_WAIT_WINDOW; }
         break;
      case ST_WAIT_WINDOW:
         if(nowMins >= EntryStartHour * 60 + EntryStartMin) gState = ST_SCANNING;
         if(nowMins > EntryEndHour * 60 + EntryEndMin) gState = ST_DONE;
         break;
      case ST_SCANNING:
         if(nowMins > EntryEndHour * 60 + EntryEndMin) { gState = ST_DONE; break; }
         CheckEngulfing();
         break;
      case ST_IN_TRADE:
         if(!HasPos())
         {
            gTradesToday++;
            gState = (gTradesToday >= MaxTradesPerDay) ? ST_DONE : ST_SCANNING;
         }
         break;
      case ST_DONE: break;
   }
}

void MarkRange()
{
   string dateStr = TimeToString(TimeCurrent(), TIME_DATE);
   datetime rs = StringToTime(dateStr + " " +
      IntegerToString(RangeStartHour, 2, '0') + ":" + IntegerToString(RangeStartMin, 2, '0') + ":00");
   datetime re = StringToTime(dateStr + " " +
      IntegerToString(RangeEndHour, 2, '0') + ":" + IntegerToString(RangeEndMin, 2, '0') + ":00");

   MqlRates bars[];
   ArraySetAsSeries(bars, false);
   int n = CopyRates(_Symbol, PERIOD_M1, rs, re, bars);
   if(n < 1) return;

   gRangeHigh = bars[0].high;
   gRangeLow  = bars[0].low;
   for(int i = 1; i < n; i++)
   {
      if(bars[i].high > gRangeHigh) gRangeHigh = bars[i].high;
      if(bars[i].low  < gRangeLow)  gRangeLow  = bars[i].low;
   }
}

double CalcLots(double slDistPrice)
{
   if(slDistPrice <= 0) return 0.01;
   double balance    = AccountInfoDouble(ACCOUNT_BALANCE);
   double riskMoney  = balance * RiskPercent / 100.0;
   double contractSz = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_CONTRACT_SIZE);
   if(contractSz <= 0) contractSz = 100;

   double lots = riskMoney / (slDistPrice * contractSz);
   double minLot  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   double maxLot  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   if(minLot <= 0) minLot = 0.01;
   if(lotStep <= 0) lotStep = 0.01;

   lots = MathFloor(lots / lotStep) * lotStep;
   if(lots < minLot) lots = minLot;
   if(lots > maxLot) lots = maxLot;
   if(lots > 5.0) lots = 5.0;
   return lots;
}

void CheckEngulfing()
{
   if(gRangeHigh == 0) return;

   MqlRates bars[];
   ArraySetAsSeries(bars, true);
   if(CopyRates(_Symbol, PERIOD_M1, 1, 2, bars) != 2) return;

   static datetime lastBar = 0;
   if(bars[0].time == lastBar) return;

   double pO = bars[1].open, pC = bars[1].close;
   double cO = bars[0].open, cC = bars[0].close;

   bool prevBear = pC < pO;
   bool prevBull = pC > pO;
   bool currBull = cC > cO;
   bool currBear = cC < cO;

   double bodyPips = MathAbs(cC - cO) / gPipSize;
   if(bodyPips < MinEngulfPips || bodyPips > MaxEngulfPips) return;

   double price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   int zone = 0;
   if(price > gRangeHigh) zone = 1;
   else if(price < gRangeLow) zone = -1;

   bool bullEngulf = currBull && prevBear && cC > pO && cO < pC;
   bool bearEngulf = currBear && prevBull && cC < pO && cO > pC;
   double buffer = SLBufferPips * gPipSize;

   if(bullEngulf && zone <= 0)
   {
      lastBar = bars[0].time;
      double entry  = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      double sl     = NormalizeDouble(bars[0].low - buffer, _Digits);
      double slDist = entry - sl;
      if(slDist <= 0) return;
      double tp   = NormalizeDouble(entry + RR_Ratio * slDist, _Digits);
      double lots = CalcLots(slDist);
      if(trade.Buy(lots, _Symbol, entry, sl, tp, "RE9 Buy"))
         gState = ST_IN_TRADE;
   }
   else if(bearEngulf && zone >= 0)
   {
      lastBar = bars[0].time;
      double entry  = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      double sl     = NormalizeDouble(bars[0].high + buffer, _Digits);
      double slDist = sl - entry;
      if(slDist <= 0) return;
      double tp   = NormalizeDouble(entry - RR_Ratio * slDist, _Digits);
      double lots = CalcLots(slDist);
      if(trade.Sell(lots, _Symbol, entry, sl, tp, "RE9 Sell"))
         gState = ST_IN_TRADE;
   }
}

bool HasPos()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
      if(PositionGetSymbol(i) == _Symbol && PositionGetInteger(POSITION_MAGIC) == MagicNumber)
         return true;
   return false;
}
