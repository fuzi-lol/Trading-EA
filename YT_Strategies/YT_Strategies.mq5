//+------------------------------------------------------------------+
//|                                              YT_Strategies.mq5   |
//|  Popular YouTube forex strategies in one EA (pick via input)     |
//|   1 = MACD + 200 EMA (Trading Rush)                              |
//|   2 = Triple EMA (8/14/50) + Stoch RSI + ATR                     |
//|   3 = London Breakout of the Asian range                        |
//|   4 = Supertrend + 200 EMA                                       |
//|  Risk: fixed % of initial balance per trade, TP = RR x SL        |
//+------------------------------------------------------------------+
#property copyright "Trading EAs"
#property version   "1.00"
#property strict

#include <Trade/Trade.mqh>

enum ENUM_YT_STRAT
{
   STRAT_MACD_EMA200   = 1, // MACD + 200 EMA
   STRAT_TRIPLE_EMA    = 2, // Triple EMA + Stoch RSI + ATR
   STRAT_LONDON_BREAK  = 3, // London Breakout (Asian range)
   STRAT_SUPERTREND    = 4  // Supertrend + 200 EMA
};

input group "=== General ==="
input ENUM_YT_STRAT InpStrategy   = STRAT_MACD_EMA200; // Strategy
input ENUM_TIMEFRAMES InpTF       = PERIOD_H1;         // Signal timeframe
input double  InpRiskPct          = 1.0;               // Risk % per trade
input bool    InpStaticRisk       = true;              // Risk % of INITIAL balance (no compounding)
input double  InpRR               = 2.0;               // Reward:Risk
input int     InpMaxSpreadPts     = 30;                // Max spread (points)
input ulong   InpMagic            = 777001;            // Magic number

input group "=== 1: MACD + 200 EMA ==="
input int     InpEMA_Trend        = 200;               // Trend EMA
input int     InpSwingBars        = 10;                // Swing lookback for SL
input double  InpMinSL_ATR        = 0.5;               // Min SL (x ATR)
input double  InpMaxSL_ATR        = 3.0;               // Max SL (x ATR)

input group "=== 2: Triple EMA + StochRSI ==="
input int     InpEMA1             = 8;                 // Fast EMA
input int     InpEMA2             = 14;                // Mid EMA
input int     InpEMA3             = 50;                // Slow EMA
input double  InpATR_SL           = 1.5;               // SL (x ATR)

input group "=== 3: London Breakout ==="
input int     InpServerOffsetUK   = 2;                 // Server hour minus UK hour
input int     InpAsiaStartUK      = 0;                 // Asian range start (UK hour)
input int     InpLondonOpenUK     = 8;                 // London open / range end (UK hour)
input int     InpEntryEndUK       = 11;                // Last entry hour (UK)
input int     InpCloseUK          = 17;                // Flatten hour (UK)
input double  InpMinRangePips     = 15;                // Min Asian range (pips)
input double  InpMaxRangePips     = 60;                // Max Asian range (pips)

input group "=== 4: Supertrend ==="
input int     InpST_ATR           = 10;                // Supertrend ATR period
input double  InpST_Mult          = 3.0;               // Supertrend multiplier

CTrade   trade;
int      hEMA200, hMACD, hATR, hE1, hE2, hE3, hRSI;
double   g_initBalance;
datetime g_lastBar = 0;
double   g_pip;
// London breakout state
int      g_lbDay = -1;
bool     g_lbTraded = false;

//+------------------------------------------------------------------+
int OnInit()
{
   trade.SetExpertMagicNumber(InpMagic);
   trade.SetDeviationInPoints(20);
   g_initBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   g_pip = (digits == 3 || digits == 5) ? _Point * 10 : _Point;

   hEMA200 = iMA(_Symbol, InpTF, InpEMA_Trend, 0, MODE_EMA, PRICE_CLOSE);
   hMACD   = iMACD(_Symbol, InpTF, 12, 26, 9, PRICE_CLOSE);
   hATR    = iATR(_Symbol, InpTF, 14);
   hE1     = iMA(_Symbol, InpTF, InpEMA1, 0, MODE_EMA, PRICE_CLOSE);
   hE2     = iMA(_Symbol, InpTF, InpEMA2, 0, MODE_EMA, PRICE_CLOSE);
   hE3     = iMA(_Symbol, InpTF, InpEMA3, 0, MODE_EMA, PRICE_CLOSE);
   hRSI    = iRSI(_Symbol, InpTF, 14, PRICE_CLOSE);
   if(hEMA200 == INVALID_HANDLE || hMACD == INVALID_HANDLE || hATR == INVALID_HANDLE ||
      hE1 == INVALID_HANDLE || hE2 == INVALID_HANDLE || hE3 == INVALID_HANDLE || hRSI == INVALID_HANDLE)
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
   if(lot < minL) return 0;   // skip rather than over-risk
   return MathMin(lot, maxL);
}

void Open(bool buy, double sl, string tag)
{
   MqlTick tk;
   if(!SymbolInfoTick(_Symbol, tk)) return;
   if((tk.ask - tk.bid) / _Point > InpMaxSpreadPts) return;
   double entry = buy ? tk.ask : tk.bid;
   double dist  = buy ? entry - sl : sl - entry;
   double stops = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL) * _Point;
   if(dist <= MathMax(stops, 5 * _Point)) return;
   double tp  = buy ? entry + dist * InpRR : entry - dist * InpRR;
   double lot = LotForRisk(buy ? ORDER_TYPE_BUY : ORDER_TYPE_SELL, entry, sl);
   if(lot <= 0) return;
   sl = NormalizeDouble(sl, _Digits);
   tp = NormalizeDouble(tp, _Digits);
   if(buy) trade.Buy(lot, _Symbol, entry, sl, tp, tag);
   else    trade.Sell(lot, _Symbol, entry, sl, tp, tag);
}

//+------------------------------------------------------------------+
//| 1: MACD + 200 EMA - MACD crosses signal below/above zero,        |
//|    with trend; SL beyond recent swing                            |
//+------------------------------------------------------------------+
void StratMACD()
{
   double ema  = Buf(hEMA200, 0, 1);
   double m1   = Buf(hMACD, 0, 1), s1 = Buf(hMACD, 1, 1);
   double m2   = Buf(hMACD, 0, 2), s2 = Buf(hMACD, 1, 2);
   double atr  = Buf(hATR, 0, 1);
   double c    = iClose(_Symbol, InpTF, 1);
   if(ema == EMPTY_VALUE || m2 == EMPTY_VALUE || atr == EMPTY_VALUE) return;

   bool buy  = c > ema && m2 <= s2 && m1 > s1 && m1 < 0;
   bool sell = c < ema && m2 >= s2 && m1 < s1 && m1 > 0;
   if(!buy && !sell) return;

   double sl;
   if(buy)
   {
      sl = iLow(_Symbol, InpTF, iLowest(_Symbol, InpTF, MODE_LOW, InpSwingBars, 1));
      double d = c - sl;
      if(d < InpMinSL_ATR * atr) sl = c - InpMinSL_ATR * atr;
      if(d > InpMaxSL_ATR * atr) return;
   }
   else
   {
      sl = iHigh(_Symbol, InpTF, iHighest(_Symbol, InpTF, MODE_HIGH, InpSwingBars, 1));
      double d = sl - c;
      if(d < InpMinSL_ATR * atr) sl = c + InpMinSL_ATR * atr;
      if(d > InpMaxSL_ATR * atr) return;
   }
   Open(buy, sl, "MACD200");
}

//+------------------------------------------------------------------+
//| Stochastic RSI (14,14,3,3) K and D at given shift                |
//+------------------------------------------------------------------+
bool StochRSI(int shift, double &k, double &d)
{
   const int len = 14, sk = 3, sd = 3;
   int need = len + sk + sd;
   double rsi[];
   ArraySetAsSeries(rsi, true);
   if(CopyBuffer(hRSI, 0, shift, need, rsi) != need) return false;
   double raw[];                       // raw stoch values, index 0 = newest
   int nRaw = sk + sd - 1;
   ArrayResize(raw, nRaw);
   for(int i = 0; i < nRaw; i++)
   {
      double hi = rsi[i], lo = rsi[i];
      for(int j = i; j < i + len; j++) { hi = MathMax(hi, rsi[j]); lo = MathMin(lo, rsi[j]); }
      raw[i] = (hi - lo) > 0 ? 100.0 * (rsi[i] - lo) / (hi - lo) : 50.0;
   }
   double kArr[3];
   for(int i = 0; i < sd; i++)
   {
      double s = 0;
      for(int j = i; j < i + sk; j++) s += raw[j];
      kArr[i] = s / sk;
   }
   k = kArr[0];
   d = (kArr[0] + kArr[1] + kArr[2]) / sd;
   return true;
}

//+------------------------------------------------------------------+
//| 2: Triple EMA stacked + StochRSI K/D cross, ATR stop             |
//+------------------------------------------------------------------+
void StratTripleEMA()
{
   double e1 = Buf(hE1, 0, 1), e2 = Buf(hE2, 0, 1), e3 = Buf(hE3, 0, 1);
   double atr = Buf(hATR, 0, 1);
   double c = iClose(_Symbol, InpTF, 1);
   double k1, d1, k2, d2;
   if(e3 == EMPTY_VALUE || atr == EMPTY_VALUE) return;
   if(!StochRSI(1, k1, d1) || !StochRSI(2, k2, d2)) return;

   bool buy  = e1 > e2 && e2 > e3 && c > e1 && k2 <= d2 && k1 > d1 && k2 < 50;
   bool sell = e1 < e2 && e2 < e3 && c < e1 && k2 >= d2 && k1 < d1 && k2 > 50;
   if(buy)  Open(true,  c - InpATR_SL * atr, "TEMA_SRSI");
   if(sell) Open(false, c + InpATR_SL * atr, "TEMA_SRSI");
}

//+------------------------------------------------------------------+
//| 3: London Breakout - first M15 close outside the Asian range,   |
//|    SL at range midpoint, flatten at end of London/NY overlap     |
//+------------------------------------------------------------------+
void StratLondon()
{
   MqlDateTime t;
   TimeToStruct(TimeCurrent(), t);
   int ukHour = (t.hour - InpServerOffsetUK + 24) % 24;

   if(t.day_of_year != g_lbDay) { g_lbDay = t.day_of_year; g_lbTraded = false; }
   if(ukHour >= InpCloseUK) { CloseAll(); return; }
   if(g_lbTraded || ukHour < InpLondonOpenUK || ukHour > InpEntryEndUK) return;
   if(HasPosition()) return;

   // Asian range from M15 bars between AsiaStart and LondonOpen (UK) today
   datetime dayStart = TimeCurrent() - (t.hour * 3600 + t.min * 60 + t.sec);
   datetime rStart = dayStart + (InpAsiaStartUK + InpServerOffsetUK) * 3600;
   datetime rEnd   = dayStart + (InpLondonOpenUK + InpServerOffsetUK) * 3600 - 1;
   MqlRates r[];
   int n = CopyRates(_Symbol, PERIOD_M15, rStart, rEnd, r);
   if(n < 8) return;
   double hi = r[0].high, lo = r[0].low;
   for(int i = 1; i < n; i++) { hi = MathMax(hi, r[i].high); lo = MathMin(lo, r[i].low); }
   double rangePips = (hi - lo) / g_pip;
   if(rangePips < InpMinRangePips || rangePips > InpMaxRangePips) { g_lbTraded = true; return; }

   double c = iClose(_Symbol, PERIOD_M15, 1);
   double mid = (hi + lo) / 2.0;
   if(c > hi)      { Open(true,  mid, "LDN_BO"); g_lbTraded = true; }
   else if(c < lo) { Open(false, mid, "LDN_BO"); g_lbTraded = true; }
}

//+------------------------------------------------------------------+
//| Supertrend direction (+1/-1) and line at shift 1 and 2           |
//+------------------------------------------------------------------+
bool Supertrend(int &dir1, int &dir2, double &line1)
{
   const int N = 300;
   MqlRates r[];
   ArraySetAsSeries(r, false);
   if(CopyRates(_Symbol, InpTF, 1, N, r) != N) return false;   // r[N-1] = last closed bar
   double upper = 0, lower = 0, a = 0;   // a = Wilder ATR(InpST_ATR)
   int dir = 1, prevDir = 1;
   for(int i = 1; i < N; i++)
   {
      double tr = MathMax(r[i].high - r[i].low, MathMax(MathAbs(r[i].high - r[i-1].close), MathAbs(r[i].low - r[i-1].close)));
      a = (i == 1) ? tr : (a * (InpST_ATR - 1) + tr) / InpST_ATR;
      double hl2 = (r[i].high + r[i].low) / 2.0;
      double bu = hl2 + InpST_Mult * a, bl = hl2 - InpST_Mult * a;
      double nu = (i == 1 || bu < upper || r[i-1].close > upper) ? bu : upper;
      double nl = (i == 1 || bl > lower || r[i-1].close < lower) ? bl : lower;
      prevDir = dir;
      if(dir == 1 && r[i].close < nl) dir = -1;
      else if(dir == -1 && r[i].close > nu) dir = 1;
      upper = nu; lower = nl;
   }
   dir1 = dir; dir2 = prevDir;
   line1 = dir == 1 ? lower : upper;
   return true;
}

//+------------------------------------------------------------------+
//| 4: Supertrend flip in direction of 200 EMA, SL at ST line        |
//+------------------------------------------------------------------+
void StratSupertrend()
{
   int d1, d2; double line;
   if(!Supertrend(d1, d2, line)) return;
   double ema = Buf(hEMA200, 0, 1), atr = Buf(hATR, 0, 1);
   double c = iClose(_Symbol, InpTF, 1);
   if(ema == EMPTY_VALUE || atr == EMPTY_VALUE) return;
   if(d1 == d2) return;
   double dist = MathAbs(c - line);
   if(dist > InpMaxSL_ATR * atr) return;
   if(d1 == 1 && c > ema)  Open(true,  MathMin(line, c - InpMinSL_ATR * atr), "ST200");
   if(d1 == -1 && c < ema) Open(false, MathMax(line, c + InpMinSL_ATR * atr), "ST200");
}

//+------------------------------------------------------------------+
void OnTick()
{
   if(InpStrategy == STRAT_LONDON_BREAK)
   {
      datetime b = iTime(_Symbol, PERIOD_M15, 0);
      MqlDateTime t; TimeToStruct(TimeCurrent(), t);
      int ukHour = (t.hour - InpServerOffsetUK + 24) % 24;
      if(ukHour >= InpCloseUK && HasPosition()) CloseAll();
      if(b == g_lastBar) return;
      g_lastBar = b;
      StratLondon();
      return;
   }

   datetime bar = iTime(_Symbol, InpTF, 0);
   if(bar == g_lastBar) return;
   g_lastBar = bar;
   if(HasPosition()) return;

   switch(InpStrategy)
   {
      case STRAT_MACD_EMA200:  StratMACD();       break;
      case STRAT_TRIPLE_EMA:   StratTripleEMA();  break;
      case STRAT_SUPERTREND:   StratSupertrend(); break;
      default: break;
   }
}
//+------------------------------------------------------------------+
