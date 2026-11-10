//+------------------------------------------------------------------+
//|                                                 Gold_BB_RSI.mq5  |
//|  YouTube gold scalp: Bollinger Band (20,2) re-entry + RSI.       |
//|  Buy : prev bar closed below lower band with RSI < 30, signal    |
//|        bar closes back inside. SL below 3-bar low - 0.2 ATR,     |
//|        TP at the middle band. Sell is the mirror.                |
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
input double  InpMinSL_ATR        = 0.5;               // Min SL (x ATR14)
input double  InpMaxSL_ATR        = 3.0;               // Max SL (x ATR14)
input ulong   InpMagic            = 888201;            // Magic number

input group "=== Strategy ==="
input int     InpBB               = 20;                // BB period
input double  InpBBDev            = 2.0;               // BB deviation
input int     InpRSI              = 14;                // RSI period
input double  InpRSI_Low          = 30;                // Oversold
input double  InpRSI_High         = 70;                // Overbought
input int     InpSwingBars        = 3;                 // Bars for SL extreme
input double  InpSLBuf_ATR        = 0.2;               // SL buffer (x ATR)
input double  InpMinRR            = 0.7;               // Min reward:risk to target
input int     InpTPMode           = 0;                 // TP: 0=middle band, 1=fixed RR, 2=opposite band
input double  InpRR               = 1.5;               // RR for TP mode 1

input group "=== Filters ==="
input int     InpTrendMode        = 0;                 // HTF trend: 0=off, 1=trade with HTF trend only
input ENUM_TIMEFRAMES InpHTF      = PERIOD_H1;         // Higher TF
input int     InpHTF_EMA          = 50;                // Higher-TF EMA
input double  InpMaxADX           = 0;                 // Max ADX(14) on signal TF (0=off, ranging filter)
input double  InpMinSLPct         = 0.0;               // Min SL as % of price (widens stop, 0=off)
input int     InpMaxTradesDay     = 0;                 // Max trades per day (0=off)
input int     InpCooldownBars     = 0;                 // Bars to wait after a loss
input int     InpBuySell          = 0;                 // 0=both, 1=buy only, 2=sell only

input group "=== Exits ==="
input double  InpBE_R             = 0.0;               // Move SL to BE at X R (0=off)

CTrade   trade;
int      hBB, hRSI, hATR, hHTF, hADX;
double   g_initBalance;
datetime g_lastBar = 0;
int      g_day = -1, g_dayTrades = 0;
datetime g_lossTime = 0;
double   g_risk = 0;

//+------------------------------------------------------------------+
int OnInit()
{
   trade.SetExpertMagicNumber(InpMagic);
   trade.SetDeviationInPoints(30);
   g_initBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   hBB  = iBands(_Symbol, InpTF, InpBB, 0, InpBBDev, PRICE_CLOSE);
   hRSI = iRSI(_Symbol, InpTF, InpRSI, PRICE_CLOSE);
   hATR = iATR(_Symbol, InpTF, 14);
   hHTF = iMA(_Symbol, InpHTF, InpHTF_EMA, 0, MODE_EMA, PRICE_CLOSE);
   hADX = iADX(_Symbol, InpTF, 14);
   if(hHTF == INVALID_HANDLE || hADX == INVALID_HANDLE) return INIT_FAILED;
   if(hBB == INVALID_HANDLE || hRSI == INVALID_HANDLE || hATR == INVALID_HANDLE)
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

// tp: band target (modes 0/2); mode 1 recomputes from RR
void Open(bool buy, double sl, double tp)
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
   if(dist <= MathMax(stops, 5 * _Point)) return;
   double atr = Buf(hATR, 0, 1);
   if(dist < InpMinSL_ATR * atr || dist > InpMaxSL_ATR * atr) return;
   if(InpTPMode == 1) tp = buy ? entry + InpRR * dist : entry - InpRR * dist;
   if(buy ? tp <= entry : tp >= entry) return;
   if((buy ? tp - entry : entry - tp) < InpMinRR * dist) return;
   double lot = LotForRisk(buy ? ORDER_TYPE_BUY : ORDER_TYPE_SELL, entry, sl);
   if(lot <= 0) return;
   sl = NormalizeDouble(sl, _Digits);
   tp = NormalizeDouble(tp, _Digits);
   bool ok = buy ? trade.Buy(lot, _Symbol, entry, sl, tp, "BBRSI buy")
                 : trade.Sell(lot, _Symbol, entry, sl, tp, "BBRSI sell");
   if(ok) { g_dayTrades++; g_risk = dist; }
}

void ManagePosition()
{
   if(InpBE_R <= 0 || g_risk <= 0) return;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong t = PositionGetTicket(i);
      if(PositionGetString(POSITION_SYMBOL) != _Symbol || PositionGetInteger(POSITION_MAGIC) != (long)InpMagic)
         continue;
      bool   buy   = PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY;
      double entry = PositionGetDouble(POSITION_PRICE_OPEN);
      double sl    = PositionGetDouble(POSITION_SL);
      if(buy ? sl >= entry : sl <= entry) continue;
      double px = buy ? SymbolInfoDouble(_Symbol, SYMBOL_BID) : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if((buy ? px - entry : entry - px) >= InpBE_R * g_risk)
         trade.PositionModify(t, NormalizeDouble(entry + (buy ? 1 : -1) * 10 * _Point, _Digits), PositionGetDouble(POSITION_TP));
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
   if(InpMaxTradesDay > 0 && g_dayTrades >= InpMaxTradesDay) return;
   if(InpCooldownBars > 0 && g_lossTime > 0 && bt - g_lossTime < InpCooldownBars * PeriodSeconds(InpTF)) return;
   if(InpMaxADX > 0)
   {
      double adx = Buf(hADX, 0, 1);
      if(adx == EMPTY_VALUE || adx > InpMaxADX) return;
   }
   double htf = Buf(hHTF, 0, 1), htfC = iClose(_Symbol, InpHTF, 1);
   bool htfUp = InpTrendMode == 0 || (htf != EMPTY_VALUE && htfC > htf);
   bool htfDn = InpTrendMode == 0 || (htf != EMPTY_VALUE && htfC < htf);

   double up1 = Buf(hBB, 1, 1), lo1 = Buf(hBB, 2, 1), mid1 = Buf(hBB, 0, 1);
   double up2 = Buf(hBB, 1, 2), lo2 = Buf(hBB, 2, 2);
   double r2 = Buf(hRSI, 0, 2), atr = Buf(hATR, 0, 1);
   if(up1 == EMPTY_VALUE || up2 == EMPTY_VALUE || r2 == EMPTY_VALUE || atr == EMPTY_VALUE) return;
   double c1 = iClose(_Symbol, InpTF, 1), c2 = iClose(_Symbol, InpTF, 2);

   if(InpBuySell != 2 && htfUp && c2 < lo2 && r2 < InpRSI_Low && c1 > lo1)
   {
      double sl = iLow(_Symbol, InpTF, iLowest(_Symbol, InpTF, MODE_LOW, InpSwingBars, 1)) - InpSLBuf_ATR * atr;
      Open(true, sl, InpTPMode == 2 ? up1 : mid1);
   }
   else if(InpBuySell != 1 && htfDn && c2 > up2 && r2 > InpRSI_High && c1 < up1)
   {
      double sl = iHigh(_Symbol, InpTF, iHighest(_Symbol, InpTF, MODE_HIGH, InpSwingBars, 1)) + InpSLBuf_ATR * atr;
      Open(false, sl, InpTPMode == 2 ? lo1 : mid1);
   }
}
//+------------------------------------------------------------------+
