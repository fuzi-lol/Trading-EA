//+------------------------------------------------------------------+
//|                                             Gold_RSI_EMA200.mq5  |
//|  YouTube gold scalp: RSI(14) crosses into 30/70 while price is   |
//|  on the trend side of the 200 EMA. ATR stop, fixed 1:2 RR.        |
//|  Buy : RSI crosses below 30 and close > EMA200                    |
//|  Sell: RSI crosses above 70 and close < EMA200                    |
//+------------------------------------------------------------------+
#property copyright "Trading EAs"
#property version   "1.00"
#property strict

#include <Trade/Trade.mqh>

input group "=== General ==="
input ENUM_TIMEFRAMES InpTF       = PERIOD_M5;         // Signal timeframe
input double  InpRiskPct          = 1.0;               // Risk % per trade
input bool    InpStaticRisk       = true;              // Risk % of INITIAL balance (no compounding)
input int     InpMaxSpreadPts     = 60;                // Max spread (points)
input int     InpStartHour        = 9;                 // Session start (server hour)
input int     InpEndHour          = 21;                // Session end (server hour)
input ulong   InpMagic            = 888101;            // Magic number

input group "=== Strategy ==="
input int     InpEMA              = 200;               // Trend EMA
input int     InpRSI              = 14;                // RSI period
input double  InpRSI_Low          = 30;                // Oversold
input double  InpRSI_High         = 70;                // Overbought
input double  InpSL_ATR           = 1.0;               // SL (x ATR14)
input double  InpRR               = 2.0;               // Reward:Risk
input int     InpEntryMode        = 0;                 // 0=RSI crosses into zone, 1=RSI crosses back out

input group "=== Filters ==="
input bool    InpUseHTF           = false;             // Require higher-TF trend agreement
input ENUM_TIMEFRAMES InpHTF      = PERIOD_H1;         // Higher TF
input int     InpHTF_EMA          = 50;                // Higher-TF EMA
input double  InpMinSLPct         = 0.0;               // Min SL as % of price (widens stop, 0=off)
input double  InpMaxSLPct         = 0.0;               // Max SL as % of price (skip, 0=off)
input int     InpMaxTradesDay     = 0;                 // Max trades per day (0=off)
input int     InpCooldownBars     = 0;                 // Bars to wait after a loss
input bool    InpSkipMon          = false;             // Skip Monday
input bool    InpSkipFri          = false;             // Skip Friday
input int     InpBuySell          = 0;                 // 0=both, 1=buy only, 2=sell only

input group "=== Exits ==="
input double  InpBE_R             = 0.0;               // Move SL to BE at X R (0=off)
input double  InpTrail_ATR        = 0.0;               // Trail at X ATR once BE hit (0=off)

CTrade   trade;
int      hEMA, hRSI, hATR, hHTF;
double   g_initBalance;
datetime g_lastBar = 0;
int      g_day = -1, g_dayTrades = 0;
datetime g_lossTime = 0;

//+------------------------------------------------------------------+
int OnInit()
{
   trade.SetExpertMagicNumber(InpMagic);
   trade.SetDeviationInPoints(30);
   g_initBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   hEMA = iMA(_Symbol, InpTF, InpEMA, 0, MODE_EMA, PRICE_CLOSE);
   hRSI = iRSI(_Symbol, InpTF, InpRSI, PRICE_CLOSE);
   hATR = iATR(_Symbol, InpTF, 14);
   hHTF = iMA(_Symbol, InpHTF, InpHTF_EMA, 0, MODE_EMA, PRICE_CLOSE);
   if(hHTF == INVALID_HANDLE) return INIT_FAILED;
   if(hEMA == INVALID_HANDLE || hRSI == INVALID_HANDLE || hATR == INVALID_HANDLE)
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

// Lot size so that hitting SL loses InpRiskPct of the base balance, capped by free margin
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
   double marginPerLot = 0;
   if(OrderCalcMargin(type, _Symbol, 1.0, entry, marginPerLot) && marginPerLot > 0)
      lot = MathMin(lot, MathFloor(AccountInfoDouble(ACCOUNT_MARGIN_FREE) * 0.9 / marginPerLot / step) * step);
   if(lot < minL) return 0;
   return MathMin(lot, maxL);
}

void Open(bool buy, double sl)
{
   MqlTick tk;
   if(!SymbolInfoTick(_Symbol, tk)) return;
   if((tk.ask - tk.bid) / _Point > InpMaxSpreadPts) return;
   double entry = buy ? tk.ask : tk.bid;
   double dist  = buy ? entry - sl : sl - entry;
   double stops = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL) * _Point;
   if(InpMinSLPct > 0 && dist < entry * InpMinSLPct / 100.0)
   {
      dist = entry * InpMinSLPct / 100.0;
      sl = buy ? entry - dist : entry + dist;
   }
   if(InpMaxSLPct > 0 && dist > entry * InpMaxSLPct / 100.0) return;
   if(dist <= MathMax(stops, 5 * _Point)) return;
   double tp  = buy ? entry + dist * InpRR : entry - dist * InpRR;
   double lot = LotForRisk(buy ? ORDER_TYPE_BUY : ORDER_TYPE_SELL, entry, sl);
   if(lot <= 0) return;
   sl = NormalizeDouble(sl, _Digits);
   tp = NormalizeDouble(tp, _Digits);
   bool ok = buy ? trade.Buy(lot, _Symbol, entry, sl, tp, "RSI200 buy")
                 : trade.Sell(lot, _Symbol, entry, sl, tp, "RSI200 sell");
   if(ok) g_dayTrades++;
}

// Breakeven at InpBE_R, then ATR trail
void ManagePosition()
{
   if(InpBE_R <= 0) return;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong t = PositionGetTicket(i);
      if(PositionGetString(POSITION_SYMBOL) != _Symbol || PositionGetInteger(POSITION_MAGIC) != (long)InpMagic)
         continue;
      bool   buy   = PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY;
      double entry = PositionGetDouble(POSITION_PRICE_OPEN);
      double sl    = PositionGetDouble(POSITION_SL);
      double tp    = PositionGetDouble(POSITION_TP);
      double px    = buy ? SymbolInfoDouble(_Symbol, SYMBOL_BID) : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      bool   atBE  = buy ? sl >= entry : sl <= entry;
      if(!atBE)
      {
         // initial risk = distance to TP / RR
         double risk = MathAbs(tp - entry) / InpRR;
         if((buy ? px - entry : entry - px) >= InpBE_R * risk)
            trade.PositionModify(t, NormalizeDouble(entry + (buy ? 1 : -1) * 10 * _Point, _Digits), tp);
      }
      else if(InpTrail_ATR > 0)
      {
         double atr = Buf(hATR, 0, 1);
         double nsl = NormalizeDouble(buy ? px - InpTrail_ATR * atr : px + InpTrail_ATR * atr, _Digits);
         if(buy ? nsl > sl + _Point : nsl < sl - _Point)
            trade.PositionModify(t, nsl, tp);
      }
   }
}

void OnTradeTransaction(const MqlTradeTransaction &tx, const MqlTradeRequest &rq, const MqlTradeResult &rs)
{
   if(tx.type != TRADE_TRANSACTION_DEAL_ADD || !HistoryDealSelect(tx.deal)) return;
   if(HistoryDealGetInteger(tx.deal, DEAL_MAGIC) != (long)InpMagic) return;
   if(HistoryDealGetInteger(tx.deal, DEAL_ENTRY) != DEAL_ENTRY_OUT) return;
   if(HistoryDealGetDouble(tx.deal, DEAL_PROFIT) < 0) g_lossTime = (datetime)HistoryDealGetInteger(tx.deal, DEAL_TIME);
}

//+------------------------------------------------------------------+
void OnTick()
{
   ManagePosition();
   datetime bt = iTime(_Symbol, InpTF, 0);
   if(bt == g_lastBar) return;
   g_lastBar = bt;
   if(HasPosition()) return;

   MqlDateTime dt;
   TimeToStruct(bt, dt);
   if(dt.day_of_year != g_day) { g_day = dt.day_of_year; g_dayTrades = 0; }
   bool inSess = InpStartHour <= InpEndHour ? (dt.hour >= InpStartHour && dt.hour < InpEndHour)
                                           : (dt.hour >= InpStartHour || dt.hour < InpEndHour);
   if(!inSess) return;
   if((InpSkipMon && dt.day_of_week == 1) || (InpSkipFri && dt.day_of_week == 5)) return;
   if(InpMaxTradesDay > 0 && g_dayTrades >= InpMaxTradesDay) return;
   if(InpCooldownBars > 0 && g_lossTime > 0 && bt - g_lossTime < InpCooldownBars * PeriodSeconds(InpTF)) return;

   double r1 = Buf(hRSI, 0, 1), r2 = Buf(hRSI, 0, 2);
   double ema = Buf(hEMA, 0, 1), atr = Buf(hATR, 0, 1);
   if(r1 == EMPTY_VALUE || r2 == EMPTY_VALUE || ema == EMPTY_VALUE || atr == EMPTY_VALUE) return;
   double c = iClose(_Symbol, InpTF, 1);
   double htf = Buf(hHTF, 0, 1), htfC = iClose(_Symbol, InpHTF, 1);
   bool htfUp = !InpUseHTF || (htf != EMPTY_VALUE && htfC > htf);
   bool htfDn = !InpUseHTF || (htf != EMPTY_VALUE && htfC < htf);

   bool buySig  = InpEntryMode == 0 ? (r2 >= InpRSI_Low && r1 < InpRSI_Low)   : (r2 < InpRSI_Low && r1 >= InpRSI_Low);
   bool sellSig = InpEntryMode == 0 ? (r2 <= InpRSI_High && r1 > InpRSI_High) : (r2 > InpRSI_High && r1 <= InpRSI_High);

   if(InpBuySell != 2 && buySig && c > ema && htfUp)
      Open(true, c - InpSL_ATR * atr);
   else if(InpBuySell != 1 && sellSig && c < ema && htfDn)
      Open(false, c + InpSL_ATR * atr);
}
//+------------------------------------------------------------------+
