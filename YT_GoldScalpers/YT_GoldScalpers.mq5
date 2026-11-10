//+------------------------------------------------------------------+
//|                                             YT_GoldScalpers.mq5  |
//|  Popular YouTube gold (XAUUSD) scalping strategies in one EA     |
//|   1 = RSI 30/70 extreme + 200 EMA trend filter (1:2 RR)          |
//|   2 = Bollinger Band (20,2) re-entry + RSI, TP at middle band     |
//|   3 = VWAP + 20/50 EMA pullback, partial at 1R + BE, TP 2R        |
//|   4 = Williams Fractal + EMA 20/50/100 (Trade Pro), TP 1.5R       |
//|   5 = New York open 15-min range breakout, TP 2R                  |
//|  Risk: fixed % of initial balance per trade                      |
//+------------------------------------------------------------------+
#property copyright "Trading EAs"
#property version   "1.00"
#property strict

#include <Trade/Trade.mqh>

enum ENUM_GS_STRAT
{
   GS_RSI_EMA200   = 1, // RSI extreme + 200 EMA
   GS_BB_RSI       = 2, // Bollinger + RSI reversion
   GS_VWAP_EMA     = 3, // VWAP + EMA pullback
   GS_FRACTAL_EMA  = 4, // Fractal + EMA 20/50/100
   GS_NY_ORB       = 5  // NY open 15-min breakout
};

input group "=== General ==="
input ENUM_GS_STRAT InpStrategy   = GS_RSI_EMA200;     // Strategy
input ENUM_TIMEFRAMES InpTF       = PERIOD_M5;         // Signal timeframe
input double  InpRiskPct          = 1.0;               // Risk % per trade
input bool    InpStaticRisk       = true;              // Risk % of INITIAL balance (no compounding)
input int     InpMaxSpreadPts     = 60;                // Max spread (points)
input int     InpStartHour        = 9;                 // Session start (server hour, S1-S4)
input int     InpEndHour          = 21;                // Session end (server hour, S1-S4)
input double  InpMinSL_ATR        = 0.5;               // Min SL (x ATR)
input double  InpMaxSL_ATR        = 3.0;               // Max SL (x ATR)
input ulong   InpMagic            = 888001;            // Magic number

input group "=== 1: RSI + 200 EMA ==="
input int     InpRSI              = 14;                // RSI period
input double  InpRSI_Low          = 30;                // Oversold
input double  InpRSI_High         = 70;                // Overbought
input double  InpS1_SL_ATR        = 1.0;               // SL (x ATR)
input double  InpS1_RR            = 2.0;               // Reward:Risk

input group "=== 2: Bollinger + RSI ==="
input int     InpBB               = 20;                // BB period
input double  InpBBDev            = 2.0;               // BB deviation
input double  InpS2_MinRR         = 0.7;               // Min reward:risk to middle band

input group "=== 3: VWAP + EMA pullback ==="
input double  InpS3_SL_ATR        = 1.5;               // SL (x ATR)
input double  InpS3_RR            = 2.0;               // Final TP (R)

input group "=== 4: Fractal + EMA 20/50/100 ==="
input double  InpS4_RR            = 1.5;               // Reward:Risk

input group "=== 5: NY open range breakout ==="
input int     InpNYOpenHour       = 16;                // NY open (server hour, server = UK+2)
input int     InpNYOpenMin        = 30;                // NY open minute
input int     InpRangeMins        = 15;                // Opening range length (min)
input int     InpLastEntryHour    = 19;                // Last entry (server hour)
input int     InpFlatHour         = 22;                // Flatten (server hour)
input int     InpMinRangePts      = 200;               // Min range (points)
input int     InpMaxRangePts      = 3000;              // Max range (points)
input double  InpS5_RR            = 2.0;               // Reward:Risk

CTrade   trade;
int      hEMA200, hEMA20, hEMA50, hEMA100, hRSI, hBB, hATR;
double   g_initBalance;
datetime g_lastBar = 0;
int      g_orbDay = -1;
bool     g_orbTraded = false;

//+------------------------------------------------------------------+
int OnInit()
{
   trade.SetExpertMagicNumber(InpMagic);
   trade.SetDeviationInPoints(30);
   g_initBalance = AccountInfoDouble(ACCOUNT_BALANCE);

   hEMA200 = iMA(_Symbol, InpTF, 200, 0, MODE_EMA, PRICE_CLOSE);
   hEMA20  = iMA(_Symbol, InpTF, 20, 0, MODE_EMA, PRICE_CLOSE);
   hEMA50  = iMA(_Symbol, InpTF, 50, 0, MODE_EMA, PRICE_CLOSE);
   hEMA100 = iMA(_Symbol, InpTF, 100, 0, MODE_EMA, PRICE_CLOSE);
   hRSI    = iRSI(_Symbol, InpTF, InpRSI, PRICE_CLOSE);
   hBB     = iBands(_Symbol, InpTF, InpBB, 0, InpBBDev, PRICE_CLOSE);
   hATR    = iATR(_Symbol, InpTF, 14);
   if(hEMA200 == INVALID_HANDLE || hEMA20 == INVALID_HANDLE || hEMA50 == INVALID_HANDLE ||
      hEMA100 == INVALID_HANDLE || hRSI == INVALID_HANDLE || hBB == INVALID_HANDLE || hATR == INVALID_HANDLE)
      return INIT_FAILED;
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
double Buf(int h, int buf, int shift)
{
   double v[1];
   if(CopyBuffer(h, buf, shift, 1, v) != 1) return EMPTY_VALUE;
   return v[0];
}

bool HasPosition()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong t = PositionGetTicket(i);
      if(PositionGetString(POSITION_SYMBOL) == _Symbol && PositionGetInteger(POSITION_MAGIC) == (long)InpMagic)
         return true;
   }
   return false;
}

void CloseAll()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong t = PositionGetTicket(i);
      if(PositionGetString(POSITION_SYMBOL) == _Symbol && PositionGetInteger(POSITION_MAGIC) == (long)InpMagic)
         trade.PositionClose(t);
   }
}

// Lot size so that hitting SL loses exactly InpRiskPct of the base balance
double LotForRisk(ENUM_ORDER_TYPE type, double entry, double sl)
{
   double base = InpStaticRisk ? g_initBalance : AccountInfoDouble(ACCOUNT_BALANCE);
   double riskMoney = base * InpRiskPct / 100.0;
   double lossPerLot = 0;
   if(!OrderCalcProfit(type, _Symbol, 1.0, entry, sl, lossPerLot) || lossPerLot >= 0)
      return 0;
   lossPerLot = -lossPerLot;
   double step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   double minL = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxL = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double lot = MathFloor(riskMoney / lossPerLot / step) * step;
   // tight scalping stops can need more margin than the account has: cap to 90% of free margin
   double marginPerLot = 0;
   if(OrderCalcMargin(type, _Symbol, 1.0, entry, marginPerLot) && marginPerLot > 0)
      lot = MathMin(lot, MathFloor(AccountInfoDouble(ACCOUNT_MARGIN_FREE) * 0.9 / marginPerLot / step) * step);
   if(lot < minL) return 0;   // skip rather than over-risk
   return MathMin(lot, maxL);
}

// tp > 0 = absolute TP price; tp <= 0 = use rr x SL distance
void Open(bool buy, double sl, double tp, double rr, string tag, bool checkATR = true)
{
   MqlTick tk;
   if(!SymbolInfoTick(_Symbol, tk)) return;
   if((tk.ask - tk.bid) / _Point > InpMaxSpreadPts) return;
   double entry = buy ? tk.ask : tk.bid;
   double dist  = buy ? entry - sl : sl - entry;
   double stops = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL) * _Point;
   if(dist <= MathMax(stops, 5 * _Point)) return;
   if(checkATR)
   {
      double atr = Buf(hATR, 0, 1);
      if(dist < InpMinSL_ATR * atr || dist > InpMaxSL_ATR * atr) return;
   }
   if(tp <= 0) tp = buy ? entry + dist * rr : entry - dist * rr;
   if(buy ? tp <= entry : tp >= entry) return;
   double lot = LotForRisk(buy ? ORDER_TYPE_BUY : ORDER_TYPE_SELL, entry, sl);
   if(lot <= 0) return;
   sl = NormalizeDouble(sl, _Digits);
   tp = NormalizeDouble(tp, _Digits);
   if(buy) trade.Buy(lot, _Symbol, entry, sl, tp, tag);
   else    trade.Sell(lot, _Symbol, entry, sl, tp, tag);
}

// S3: close half at 1R and move SL to entry (stateless: runs while SL is still on the loss side)
void ManagePartial()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong t = PositionGetTicket(i);
      if(PositionGetString(POSITION_SYMBOL) != _Symbol || PositionGetInteger(POSITION_MAGIC) != (long)InpMagic)
         continue;
      bool   buy   = PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY;
      double entry = PositionGetDouble(POSITION_PRICE_OPEN);
      double sl    = PositionGetDouble(POSITION_SL);
      double tp    = PositionGetDouble(POSITION_TP);
      double vol   = PositionGetDouble(POSITION_VOLUME);
      double risk  = buy ? entry - sl : sl - entry;
      if(risk <= 0) continue;
      double px = buy ? SymbolInfoDouble(_Symbol, SYMBOL_BID) : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if((buy ? px - entry : entry - px) < risk) continue;
      double step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
      double half = MathFloor(vol / 2.0 / step) * step;
      if(half >= SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN))
         trade.PositionClosePartial(t, half);
      trade.PositionModify(t, NormalizeDouble(entry, _Digits), tp);
   }
}

bool InSession()
{
   MqlDateTime dt;
   TimeToStruct(iTime(_Symbol, InpTF, 0), dt);
   return dt.hour >= InpStartHour && dt.hour < InpEndHour;
}

//+------------------------------------------------------------------+
//| 1: RSI crosses into 30/70 while price is on the trend side of    |
//|    the 200 EMA; fixed ATR stop, 1:2 RR                           |
//+------------------------------------------------------------------+
void SignalRSI()
{
   double r1 = Buf(hRSI, 0, 1), r2 = Buf(hRSI, 0, 2);
   double ema = Buf(hEMA200, 0, 1), atr = Buf(hATR, 0, 1);
   double c = iClose(_Symbol, InpTF, 1);
   if(r1 == EMPTY_VALUE || ema == EMPTY_VALUE || atr == EMPTY_VALUE) return;
   if(r2 >= InpRSI_Low && r1 < InpRSI_Low && c > ema)
      Open(true, c - InpS1_SL_ATR * atr, 0, InpS1_RR, "S1 RSI buy");
   else if(r2 <= InpRSI_High && r1 > InpRSI_High && c < ema)
      Open(false, c + InpS1_SL_ATR * atr, 0, InpS1_RR, "S1 RSI sell");
}

//+------------------------------------------------------------------+
//| 2: previous bar closed outside the band with RSI extreme, signal |
//|    bar closes back inside; SL beyond the 3-bar extreme, TP mid    |
//+------------------------------------------------------------------+
void SignalBB()
{
   double up1 = Buf(hBB, 1, 1), lo1 = Buf(hBB, 2, 1), mid1 = Buf(hBB, 0, 1);
   double up2 = Buf(hBB, 1, 2), lo2 = Buf(hBB, 2, 2);
   double r2 = Buf(hRSI, 0, 2), atr = Buf(hATR, 0, 1);
   if(up1 == EMPTY_VALUE || r2 == EMPTY_VALUE || atr == EMPTY_VALUE) return;
   double c1 = iClose(_Symbol, InpTF, 1), c2 = iClose(_Symbol, InpTF, 2);

   if(c2 < lo2 && r2 < InpRSI_Low && c1 > lo1)
   {
      double sl = iLow(_Symbol, InpTF, iLowest(_Symbol, InpTF, MODE_LOW, 3, 1)) - 0.2 * atr;
      if((mid1 - c1) >= InpS2_MinRR * (c1 - sl))
         Open(true, sl, mid1, 0, "S2 BB buy");
   }
   else if(c2 > up2 && r2 > InpRSI_High && c1 < up1)
   {
      double sl = iHigh(_Symbol, InpTF, iHighest(_Symbol, InpTF, MODE_HIGH, 3, 1)) + 0.2 * atr;
      if((c1 - mid1) >= InpS2_MinRR * (sl - c1))
         Open(false, sl, mid1, 0, "S2 BB sell");
   }
}

//+------------------------------------------------------------------+
//| 3: intraday VWAP + 20/50 EMA bias; buy a bullish rejection of    |
//|    the 20 EMA. ATR stop, half off at 1R + BE, rest at 2R          |
//+------------------------------------------------------------------+
double SessionVWAP()
{
   datetime dayStart = iTime(_Symbol, PERIOD_D1, 0);
   int n = iBarShift(_Symbol, InpTF, dayStart, false);
   if(n < 1) return EMPTY_VALUE;
   MqlRates r[];
   int got = CopyRates(_Symbol, InpTF, 1, n, r);
   if(got <= 0) return EMPTY_VALUE;
   double pv = 0, v = 0;
   for(int i = 0; i < got; i++)
   {
      double tp = (r[i].high + r[i].low + r[i].close) / 3.0;
      pv += tp * (double)r[i].tick_volume;
      v  += (double)r[i].tick_volume;
   }
   return v > 0 ? pv / v : EMPTY_VALUE;
}

void SignalVWAP()
{
   double vwap = SessionVWAP();
   double e20 = Buf(hEMA20, 0, 1), e50 = Buf(hEMA50, 0, 1), atr = Buf(hATR, 0, 1);
   if(vwap == EMPTY_VALUE || e20 == EMPTY_VALUE || atr == EMPTY_VALUE) return;
   double o = iOpen(_Symbol, InpTF, 1), h = iHigh(_Symbol, InpTF, 1);
   double l = iLow(_Symbol, InpTF, 1),  c = iClose(_Symbol, InpTF, 1);

   if(c > vwap && e20 > e50 && l <= e20 && c > e20 && c > o)
      Open(true, c - InpS3_SL_ATR * atr, 0, InpS3_RR, "S3 VWAP buy");
   else if(c < vwap && e20 < e50 && h >= e20 && c < e20 && c < o)
      Open(false, c + InpS3_SL_ATR * atr, 0, InpS3_RR, "S3 VWAP sell");
}

//+------------------------------------------------------------------+
//| 4: EMAs 20>50>100 stacked; a down-fractal (bar 3) prints in the  |
//|    pullback zone below EMA20 but above EMA100. SL below EMA50 or |
//|    EMA100 depending on how deep the pullback went; TP 1.5R        |
//+------------------------------------------------------------------+
void SignalFractal()
{
   double e20 = Buf(hEMA20, 0, 3), e50 = Buf(hEMA50, 0, 3), e100 = Buf(hEMA100, 0, 3);
   double e50n = Buf(hEMA50, 0, 1), e100n = Buf(hEMA100, 0, 1), e20n = Buf(hEMA20, 0, 1);
   if(e20 == EMPTY_VALUE || e100n == EMPTY_VALUE) return;
   double c = iClose(_Symbol, InpTF, 1);
   double l[5], h[5];
   for(int i = 0; i < 5; i++) { l[i] = iLow(_Symbol, InpTF, i + 1); h[i] = iHigh(_Symbol, InpTF, i + 1); }
   // fractal at shift 3 = index 2
   bool downFr = l[2] < l[0] && l[2] < l[1] && l[2] < l[3] && l[2] < l[4];
   bool upFr   = h[2] > h[0] && h[2] > h[1] && h[2] > h[3] && h[2] > h[4];

   if(downFr && e20 > e50 && e50 > e100 && e20n > e50n && e50n > e100n &&
      l[2] < e20 && l[2] > e100 && c > e50n)
   {
      double sl = (l[2] < e50) ? e100n : e50n;
      Open(true, sl, 0, InpS4_RR, "S4 Fractal buy");
   }
   else if(upFr && e20 < e50 && e50 < e100 && e20n < e50n && e50n < e100n &&
           h[2] > e20 && h[2] < e100 && c < e50n)
   {
      double sl = (h[2] > e50) ? e100n : e50n;
      Open(false, sl, 0, InpS4_RR, "S4 Fractal sell");
   }
}

//+------------------------------------------------------------------+
//| 5: first 15 minutes after NY open define a range; first M5 close |
//|    beyond it enters, SL at the other side, TP 2R, flat at close  |
//+------------------------------------------------------------------+
void SignalORB()
{
   datetime t0 = iTime(_Symbol, InpTF, 0);
   MqlDateTime dt;
   TimeToStruct(t0, dt);
   if(dt.day_of_year != g_orbDay) { g_orbDay = dt.day_of_year; g_orbTraded = false; }

   if(dt.hour >= InpFlatHour) { CloseAll(); return; }
   if(g_orbTraded || HasPosition()) return;
   if(dt.hour > InpLastEntryHour) return;

   datetime dayStart = t0 - (dt.hour * 3600 + dt.min * 60 + dt.sec);
   datetime rStart = dayStart + InpNYOpenHour * 3600 + InpNYOpenMin * 60;
   datetime rEnd   = rStart + InpRangeMins * 60;
   if(t0 < rEnd + PeriodSeconds(InpTF)) return;   // need at least one closed bar after the range

   int iS = iBarShift(_Symbol, PERIOD_M1, rStart, true);
   int iE = iBarShift(_Symbol, PERIOD_M1, rEnd - 60, true);
   if(iS < 0 || iE < 0) return;
   double hi = iHigh(_Symbol, PERIOD_M1, iHighest(_Symbol, PERIOD_M1, MODE_HIGH, iS - iE + 1, iE));
   double lo = iLow(_Symbol, PERIOD_M1, iLowest(_Symbol, PERIOD_M1, MODE_LOW, iS - iE + 1, iE));
   double rangePts = (hi - lo) / _Point;
   if(rangePts < InpMinRangePts || rangePts > InpMaxRangePts) { g_orbTraded = true; return; }

   double c = iClose(_Symbol, InpTF, 1);
   if(c > hi)      { Open(true, lo, 0, InpS5_RR, "S5 ORB buy", false);  g_orbTraded = true; }
   else if(c < lo) { Open(false, hi, 0, InpS5_RR, "S5 ORB sell", false); g_orbTraded = true; }
}

//+------------------------------------------------------------------+
void OnTick()
{
   if(InpStrategy == GS_VWAP_EMA) ManagePartial();

   datetime bt = iTime(_Symbol, InpTF, 0);
   if(bt == g_lastBar) return;
   g_lastBar = bt;

   if(InpStrategy == GS_NY_ORB) { SignalORB(); return; }
   if(HasPosition() || !InSession()) return;

   switch(InpStrategy)
   {
      case GS_RSI_EMA200:  SignalRSI();     break;
      case GS_BB_RSI:      SignalBB();      break;
      case GS_VWAP_EMA:    SignalVWAP();    break;
      case GS_FRACTAL_EMA: SignalFractal(); break;
      default: break;
   }
}
//+------------------------------------------------------------------+
