//+------------------------------------------------------------------+
//|                                    ExMachina_SafeScalping_CB.mq5 |
//|                     ExMachina Safe Scalping v1.0 — Code Base      |
//|                         ExMachina Trading Systems                 |
//|                https://www.mql5.com/en/users/WilliamMukam         |
//+------------------------------------------------------------------+
//|  6-Condition Breakout Scalping System                             |
//|                                                                   |
//|  Every entry requires ALL conditions to align simultaneously:     |
//|    1. EMA trend direction (fast > slow or fast < slow)            |
//|    2. Trend strength — EMAs separated by minimum ATR distance     |
//|    3. Price position — close above/below both EMAs                |
//|    4. Breakout detection — N-bar high/low with ATR buffer         |
//|    5. RSI filter — healthy zone, no extremes                      |
//|    6. Momentum confirmation — close vs previous close             |
//|                                                                   |
//|  Risk: Fixed SL/TP, one trade at a time, auto breakeven,         |
//|        drawdown pause, session/spread/news filters.               |
//|  No martingale. No grid. No hedging. No recovery logic.           |
//+------------------------------------------------------------------+
#property copyright   "ExMachina Trading Systems"
#property link        "https://www.mql5.com/en/users/WilliamMukam"
#property version     "1.00"
#property description "6-Condition Breakout Scalping — Conservative & Transparent"
#property description "Full source code. No dashboard (see Market version for GUI)."
#property strict

#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>
#include <Trade\SymbolInfo.mqh>
#include <Trade\AccountInfo.mqh>

//+------------------------------------------------------------------+
//| CONSTANTS                                                        |
//+------------------------------------------------------------------+
#define EXM_MAX_RETRIES    3
#define EXM_RETRY_DELAY_MS 300

//+------------------------------------------------------------------+
//| ENUMERATIONS                                                     |
//+------------------------------------------------------------------+
enum ENUM_LOT_MODE
  {
   LOT_FIXED     = 0,   // Fixed Lot Size
   LOT_RISK_PCT  = 1    // Percent of Balance
  };

enum ENUM_TREND_STR
  {
   TREND_WEAK     = 0,  // Allow Weak Trends
   TREND_MODERATE = 1,  // Moderate Trends Only
   TREND_STRONG   = 2   // Strong Trends Only
  };

//+------------------------------------------------------------------+
//| INPUT PARAMETERS                                                 |
//+------------------------------------------------------------------+
input string           _s0_ = "=== GENERAL ===";               // ────────────────────
input int              InpMagicNumber      = 202503;            // Magic Number
input string           InpTradeComment     = "EXMv1";           // Trade Comment
input int              InpMaxSlippage      = 10;                // Max Slippage (points)

input string           _s1_ = "=== RISK ===";                  // ────────────────────
input ENUM_LOT_MODE    InpLotMode          = LOT_FIXED;         // Lot Sizing Mode
input double           InpFixedLots        = 0.01;              // Fixed Lot Size
input double           InpRiskPercent      = 1.0;               // Risk % per Trade
input double           InpMaxDrawdownPct   = 10.0;              // Max Drawdown % (pause)

input string           _s2_ = "=== SL / TP ===";               // ────────────────────
input int              InpStopLoss         = 225;               // Stop Loss (points)
input int              InpTakeProfit       = 250;               // Take Profit (points)
input bool             InpUseBreakeven     = true;              // Use Breakeven
input int              InpBreakevenStart   = 100;               // BE Trigger (points)
input int              InpBreakevenOffset  = 10;                // BE Offset (points)

input string           _s3_ = "=== EMA TREND ===";             // ────────────────────
input int              InpEmaFast          = 150;               // Fast EMA Period
input int              InpEmaSlow          = 510;               // Slow EMA Period
input ENUM_TREND_STR   InpTrendStrength    = TREND_MODERATE;    // Trend Strength Filter

input string           _s4_ = "=== RSI ===";                   // ────────────────────
input int              InpRsiPeriod        = 10;                // RSI Period
input double           InpRsiBuyMin        = 40.0;              // RSI Buy Min
input double           InpRsiBuyMax        = 65.0;              // RSI Buy Max
input double           InpRsiSellMin       = 35.0;              // RSI Sell Min
input double           InpRsiSellMax       = 60.0;              // RSI Sell Max

input string           _s5_ = "=== BREAKOUT ===";              // ────────────────────
input int              InpBreakoutLookback = 20;                // Lookback Bars
input double           InpBreakoutBuffer   = 0.5;               // Buffer (x ATR)
input int              InpAtrPeriod        = 125;               // ATR Period

input string           _s6_ = "=== SESSION ===";               // ────────────────────
input bool             InpUseSessionFilter = true;              // Enable Session Filter
input int              InpSessionStartHour = 8;                 // Start Hour
input int              InpSessionEndHour   = 20;                // End Hour
input bool             InpAvoidFriday      = true;              // Avoid Friday Afternoon
input int              InpFridayCutoffHour = 16;                // Friday Cutoff Hour

input string           _s7_ = "=== SPREAD ===";                // ────────────────────
input bool             InpUseSpreadFilter  = true;              // Enable Spread Filter
input int              InpMaxSpread        = 30;                // Max Spread (points)

input string           _s8_ = "=== NEWS ===";                  // ────────────────────
input bool             InpUseNewsFilter    = true;              // Enable News Filter
input string           InpNewsTime1        = "";                // News Time 1 (HH:MM)
input string           InpNewsTime2        = "";                // News Time 2
input string           InpNewsTime3        = "";                // News Time 3
input int              InpNewsMinsBefore   = 30;                // Minutes Before News
input int              InpNewsMinsAfter    = 15;                // Minutes After News

//+------------------------------------------------------------------+
//| GLOBALS                                                          |
//+------------------------------------------------------------------+
CTrade         g_trade;
CPositionInfo  g_pos;
CSymbolInfo    g_sym;
CAccountInfo   g_acc;

// Indicator handles
int            g_hEmaFast, g_hEmaSlow, g_hRsi, g_hAtr;

// Buffers
double         g_bufEmaFast[], g_bufEmaSlow[], g_bufRsi[], g_bufAtr[];

// State
datetime       g_lastBar      = 0;
double         g_peakBalance  = 0;
double         g_dayBalance   = 0;
datetime       g_dayStart     = 0;
bool           g_ddPaused     = false;

//+------------------------------------------------------------------+
//| INIT                                                             |
//+------------------------------------------------------------------+
int OnInit()
  {
   // Validate
   if(InpStopLoss <= 0 || InpTakeProfit <= 0)
     { Print("ERROR: SL and TP must be > 0"); return INIT_PARAMETERS_INCORRECT; }
   if(InpEmaFast >= InpEmaSlow)
     { Print("ERROR: Fast EMA must be < Slow EMA"); return INIT_PARAMETERS_INCORRECT; }

   // Trade setup
   g_trade.SetExpertMagicNumber(InpMagicNumber);
   g_trade.SetDeviationInPoints(InpMaxSlippage);
   g_trade.SetMarginMode();

   // Filling mode
   long fill = SymbolInfoInteger(_Symbol, SYMBOL_FILLING_MODE);
   if((fill & SYMBOL_FILLING_IOC) != 0)     g_trade.SetTypeFilling(ORDER_FILLING_IOC);
   else if((fill & SYMBOL_FILLING_FOK) != 0) g_trade.SetTypeFilling(ORDER_FILLING_FOK);
   else                                       g_trade.SetTypeFilling(ORDER_FILLING_RETURN);

   g_sym.Name(_Symbol);

   // Create indicators
   ENUM_TIMEFRAMES tf = (ENUM_TIMEFRAMES)Period();
   g_hEmaFast = iMA(_Symbol, tf, InpEmaFast, 0, MODE_EMA, PRICE_CLOSE);
   g_hEmaSlow = iMA(_Symbol, tf, InpEmaSlow, 0, MODE_EMA, PRICE_CLOSE);
   g_hRsi     = iRSI(_Symbol, tf, InpRsiPeriod, PRICE_CLOSE);
   g_hAtr     = iATR(_Symbol, tf, InpAtrPeriod);

   if(g_hEmaFast == INVALID_HANDLE || g_hEmaSlow == INVALID_HANDLE ||
      g_hRsi == INVALID_HANDLE || g_hAtr == INVALID_HANDLE)
     { Print("ERROR: Indicator creation failed"); return INIT_FAILED; }

   ArraySetAsSeries(g_bufEmaFast, true);
   ArraySetAsSeries(g_bufEmaSlow, true);
   ArraySetAsSeries(g_bufRsi, true);
   ArraySetAsSeries(g_bufAtr, true);

   // State
   g_peakBalance = g_acc.Balance();
   g_dayBalance  = g_peakBalance;
   g_dayStart    = GetDayStart();
   g_ddPaused    = false;

   Print("ExMachina Safe Scalping v1.0 initialized | ",
         _Symbol, " ", EnumToString(tf),
         " | EMA ", InpEmaFast, "/", InpEmaSlow,
         " | RSI ", InpRsiPeriod,
         " | ATR ", InpAtrPeriod);
   return INIT_SUCCEEDED;
  }

//+------------------------------------------------------------------+
//| DEINIT                                                           |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   if(g_hEmaFast != INVALID_HANDLE) IndicatorRelease(g_hEmaFast);
   if(g_hEmaSlow != INVALID_HANDLE) IndicatorRelease(g_hEmaSlow);
   if(g_hRsi     != INVALID_HANDLE) IndicatorRelease(g_hRsi);
   if(g_hAtr     != INVALID_HANDLE) IndicatorRelease(g_hAtr);
  }

//+------------------------------------------------------------------+
//| TICK                                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
   g_sym.RefreshRates();

   // Track peak balance and day reset
   double bal = g_acc.Balance();
   if(bal > g_peakBalance) g_peakBalance = bal;
   datetime today = GetDayStart();
   if(today != g_dayStart) { g_dayStart = today; g_dayBalance = bal; }

   // Breakeven management
   if(InpUseBreakeven)
      ManageBreakeven(InpBreakevenStart, InpBreakevenOffset);

   // New bar check
   datetime barTime = iTime(_Symbol, PERIOD_CURRENT, 0);
   if(barTime == g_lastBar) return;
   g_lastBar = barTime;

   // --- Drawdown check ---
   double dd = GetDrawdownPct();
   if(dd >= InpMaxDrawdownPct)
     {
      if(!g_ddPaused) { Print("DRAWDOWN PAUSE: DD=", DoubleToString(dd, 2), "%"); g_ddPaused = true; }
      return;
     }
   g_ddPaused = false;

   // --- Already in position? ---
   if(HasPosition()) return;

   // --- Filters ---
   if(InpUseSessionFilter && !PassSession()) return;
   if(InpUseSpreadFilter  && (int)g_sym.Spread() > InpMaxSpread) return;
   if(InpUseNewsFilter    && !PassNews()) return;

   // --- Update indicators ---
   int need = MathMax(InpBreakoutLookback + 5, InpEmaSlow + 5);
   need = MathMax(need, 10);
   if(CopyBuffer(g_hEmaFast, 0, 0, need, g_bufEmaFast) < need) return;
   if(CopyBuffer(g_hEmaSlow, 0, 0, need, g_bufEmaSlow) < need) return;
   if(CopyBuffer(g_hRsi, 0, 0, 5, g_bufRsi) < 5) return;
   if(CopyBuffer(g_hAtr, 0, 0, 5, g_bufAtr) < 5) return;

   double emaF = g_bufEmaFast[1];
   double emaS = g_bufEmaSlow[1];
   double rsi  = g_bufRsi[1];
   double atr  = g_bufAtr[1];
   double c1   = iClose(_Symbol, PERIOD_CURRENT, 1);
   double c2   = iClose(_Symbol, PERIOD_CURRENT, 2);

   if(atr <= 0) return;

   // --- SIGNAL GENERATION (6 conditions) ---
   int signal = GetSignal(emaF, emaS, rsi, atr, c1, c2);
   if(signal == 0) return;

   // --- EXECUTE ---
   double lot = CalcLot(InpStopLoss);
   if(lot <= 0) return;  // Insufficient margin

   // Margin check
   double marginNeeded = 0;
   if(!OrderCalcMargin(signal == 1 ? ORDER_TYPE_BUY : ORDER_TYPE_SELL,
                       _Symbol, lot, signal == 1 ? g_sym.Ask() : g_sym.Bid(), marginNeeded))
      marginNeeded = 0;
   if(marginNeeded > 0 && marginNeeded >= g_acc.FreeMargin() * 0.9)
      return;

   if(signal == 1)
      OpenBuy(lot, InpStopLoss, InpTakeProfit);
   else if(signal == -1)
      OpenSell(lot, InpStopLoss, InpTakeProfit);
  }

//+------------------------------------------------------------------+
//| SIGNAL: 6-condition check. Returns +1 BUY, -1 SELL, 0 NONE      |
//+------------------------------------------------------------------+
int GetSignal(double emaF, double emaS, double rsi, double atr,
              double c1, double c2)
  {
   // 1. TREND DIRECTION
   bool bullTrend = (emaF > emaS);
   bool bearTrend = (emaF < emaS);

   // 2. TREND STRENGTH (EMA separation vs ATR)
   double sep = MathAbs(emaF - emaS);
   double minSep = 0;
   switch(InpTrendStrength)
     {
      case TREND_WEAK:     minSep = atr * 0.1; break;
      case TREND_MODERATE: minSep = atr * 0.3; break;
      case TREND_STRONG:   minSep = atr * 0.6; break;
     }
   if(sep < minSep) return 0;

   // 3. PRICE POSITION (above/below both EMAs)
   bool aboveBoth = (c1 > emaF && c1 > emaS);
   bool belowBoth = (c1 < emaF && c1 < emaS);

   // 4. BREAKOUT DETECTION
   double hh = 0, ll = DBL_MAX;
   for(int i = 2; i <= InpBreakoutLookback + 1; i++)
     {
      double h = iHigh(_Symbol, PERIOD_CURRENT, i);
      double l = iLow(_Symbol, PERIOD_CURRENT, i);
      if(h > hh) hh = h;
      if(l < ll) ll = l;
     }
   double buf = atr * InpBreakoutBuffer;
   bool bullBreak = (c1 > hh - buf) && (c2 <= hh);
   bool bearBreak = (c1 < ll + buf) && (c2 >= ll);

   // 5. RSI FILTER
   bool rsiBuy  = (rsi >= InpRsiBuyMin  && rsi <= InpRsiBuyMax);
   bool rsiSell = (rsi >= InpRsiSellMin && rsi <= InpRsiSellMax);

   // 6. MOMENTUM
   bool bullMom = (c1 > c2);
   bool bearMom = (c1 < c2);

   // COMBINE
   if(bullTrend && aboveBoth && bullBreak && rsiBuy && bullMom)
      return 1;
   if(bearTrend && belowBoth && bearBreak && rsiSell && bearMom)
      return -1;

   return 0;
  }

//+------------------------------------------------------------------+
//| ORDER EXECUTION                                                  |
//+------------------------------------------------------------------+
bool OpenBuy(double lot, int slPts, int tpPts)
  {
   double ask = g_sym.Ask();
   double pt  = g_sym.Point();
   int    dig = g_sym.Digits();
   double sl  = NormalizeDouble(ask - slPts * pt, dig);
   double tp  = NormalizeDouble(ask + tpPts * pt, dig);

   for(int i = 0; i < EXM_MAX_RETRIES; i++)
     {
      if(g_trade.Buy(lot, _Symbol, ask, sl, tp, InpTradeComment))
        {
         Print("BUY ", DoubleToString(lot, 2), " @ ", DoubleToString(ask, dig),
               " SL=", DoubleToString(sl, dig), " TP=", DoubleToString(tp, dig));
         return true;
        }
      uint rc = g_trade.ResultRetcode();
      if(!IsRecoverable(rc)) break;
      Sleep(EXM_RETRY_DELAY_MS);
      g_sym.RefreshRates(); ask = g_sym.Ask();
      sl = NormalizeDouble(ask - slPts * pt, dig);
      tp = NormalizeDouble(ask + tpPts * pt, dig);
     }
   Print("BUY FAILED: ", g_trade.ResultComment());
   return false;
  }

bool OpenSell(double lot, int slPts, int tpPts)
  {
   double bid = g_sym.Bid();
   double pt  = g_sym.Point();
   int    dig = g_sym.Digits();
   double sl  = NormalizeDouble(bid + slPts * pt, dig);
   double tp  = NormalizeDouble(bid - tpPts * pt, dig);

   for(int i = 0; i < EXM_MAX_RETRIES; i++)
     {
      if(g_trade.Sell(lot, _Symbol, bid, sl, tp, InpTradeComment))
        {
         Print("SELL ", DoubleToString(lot, 2), " @ ", DoubleToString(bid, dig),
               " SL=", DoubleToString(sl, dig), " TP=", DoubleToString(tp, dig));
         return true;
        }
      uint rc = g_trade.ResultRetcode();
      if(!IsRecoverable(rc)) break;
      Sleep(EXM_RETRY_DELAY_MS);
      g_sym.RefreshRates(); bid = g_sym.Bid();
      sl = NormalizeDouble(bid + slPts * pt, dig);
      tp = NormalizeDouble(bid - tpPts * pt, dig);
     }
   Print("SELL FAILED: ", g_trade.ResultComment());
   return false;
  }

//+------------------------------------------------------------------+
//| BREAKEVEN                                                        |
//+------------------------------------------------------------------+
void ManageBreakeven(int trigPts, int offPts)
  {
   double pt = g_sym.Point();
   int dig   = g_sym.Digits();

   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      if(!g_pos.SelectByIndex(i)) continue;
      if(g_pos.Symbol() != _Symbol || g_pos.Magic() != InpMagicNumber) continue;

      double op = g_pos.PriceOpen();
      double sl = g_pos.StopLoss();

      if(g_pos.PositionType() == POSITION_TYPE_BUY)
        {
         double be = NormalizeDouble(op + offPts * pt, dig);
         if(g_sym.Bid() >= op + trigPts * pt && sl < be)
            g_trade.PositionModify(g_pos.Ticket(), be, g_pos.TakeProfit());
        }
      else if(g_pos.PositionType() == POSITION_TYPE_SELL)
        {
         double be = NormalizeDouble(op - offPts * pt, dig);
         if(g_sym.Ask() <= op - trigPts * pt && (sl > be || sl == 0))
            g_trade.PositionModify(g_pos.Ticket(), be, g_pos.TakeProfit());
        }
     }
  }

//+------------------------------------------------------------------+
//| LOT CALCULATION                                                  |
//+------------------------------------------------------------------+
double CalcLot(int slPts)
  {
   double lots = InpFixedLots;

   if(InpLotMode == LOT_RISK_PCT && InpRiskPercent > 0 && slPts > 0)
     {
      double risk = g_acc.Balance() * MathMin(InpRiskPercent, 5.0) / 100.0;
      double tv = g_sym.TickValue();
      double ts = g_sym.TickSize();
      if(tv > 0 && ts > 0)
        {
         double slMoney = slPts * g_sym.Point() / ts * tv;
         if(slMoney > 0) lots = NormalizeDouble(risk / slMoney, 2);
        }
     }

   double lotMin  = g_sym.LotsMin();
   double lotMax  = g_sym.LotsMax();
   double lotStep = g_sym.LotsStep();
   if(lots < lotMin) lots = lotMin;
   if(lots > lotMax) lots = lotMax;
   if(lotStep > 0)   lots = MathFloor(lots / lotStep) * lotStep;

   // Margin safety: reduce lot until it fits free margin (90%)
   double freeMargin = g_acc.FreeMargin();
   while(lots >= lotMin)
     {
      double marginNeeded = 0;
      if(OrderCalcMargin(ORDER_TYPE_BUY, _Symbol, lots, g_sym.Ask(), marginNeeded))
        {
         if(marginNeeded < freeMargin * 0.9)
            break;
        }
      lots -= lotStep > 0 ? lotStep : 0.01;
     }
   if(lots < lotMin) lots = 0;  // Signal: cannot trade

   return NormalizeDouble(lots, 2);
  }

//+------------------------------------------------------------------+
//| POSITION CHECK                                                   |
//+------------------------------------------------------------------+
bool HasPosition()
  {
   for(int i = PositionsTotal() - 1; i >= 0; i--)
      if(g_pos.SelectByIndex(i))
         if(g_pos.Symbol() == _Symbol && g_pos.Magic() == InpMagicNumber)
            return true;
   return false;
  }

//+------------------------------------------------------------------+
//| DRAWDOWN                                                         |
//+------------------------------------------------------------------+
double GetDrawdownPct()
  {
   if(g_peakBalance <= 0) return 0;
   double dd = (g_peakBalance - g_acc.Equity()) / g_peakBalance * 100.0;
   return MathMax(dd, 0);
  }

//+------------------------------------------------------------------+
//| SESSION FILTER                                                   |
//+------------------------------------------------------------------+
bool PassSession()
  {
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   if(dt.day_of_week == 0 || dt.day_of_week == 6) return false;
   if(InpAvoidFriday && dt.day_of_week == 5 && dt.hour >= InpFridayCutoffHour) return false;
   int cur = dt.hour * 60 + dt.min;
   int st  = InpSessionStartHour * 60;
   int en  = InpSessionEndHour * 60;
   if(st < en) { if(cur < st || cur >= en) return false; }
   else        { if(cur < st && cur >= en) return false; }
   return true;
  }

//+------------------------------------------------------------------+
//| NEWS FILTER                                                      |
//+------------------------------------------------------------------+
bool PassNews()
  {
   datetime now = TimeCurrent();
   if(IsNearNews(InpNewsTime1, now)) return false;
   if(IsNearNews(InpNewsTime2, now)) return false;
   if(IsNearNews(InpNewsTime3, now)) return false;
   return true;
  }

bool IsNearNews(string timeStr, datetime now)
  {
   if(timeStr == "" || StringLen(timeStr) < 4) return false;
   int cp = StringFind(timeStr, ":");
   if(cp < 0) return false;
   int nh = (int)StringToInteger(StringSubstr(timeStr, 0, cp));
   int nm = (int)StringToInteger(StringSubstr(timeStr, cp + 1));
   MqlDateTime dtN;
   TimeToStruct(now, dtN);
   dtN.hour = nh; dtN.min = nm; dtN.sec = 0;
   datetime nt = StructToTime(dtN);
   return (now >= nt - InpNewsMinsBefore * 60 && now <= nt + InpNewsMinsAfter * 60);
  }

//+------------------------------------------------------------------+
//| RECOVERABLE ERROR CHECK                                          |
//+------------------------------------------------------------------+
bool IsRecoverable(uint rc)
  {
   return (rc == TRADE_RETCODE_REQUOTE      ||
           rc == TRADE_RETCODE_CONNECTION    ||
           rc == TRADE_RETCODE_TIMEOUT       ||
           rc == TRADE_RETCODE_PRICE_CHANGED ||
           rc == TRADE_RETCODE_PRICE_OFF     ||
           rc == TRADE_RETCODE_TOO_MANY_REQUESTS);
  }

//+------------------------------------------------------------------+
//| DAY START                                                        |
//+------------------------------------------------------------------+
datetime GetDayStart()
  {
   MqlDateTime dt;
   TimeCurrent(dt);
   dt.hour = 0; dt.min = 0; dt.sec = 0;
   return StructToTime(dt);
  }

//+------------------------------------------------------------------+
//| CUSTOM TESTER CRITERION                                          |
//+------------------------------------------------------------------+
double OnTester()
  {
   double profit = TesterStatistics(STAT_PROFIT);
   double trades = TesterStatistics(STAT_TRADES);
   double maxDD  = TesterStatistics(STAT_EQUITY_DDREL_PERCENT);
   double pf     = TesterStatistics(STAT_PROFIT_FACTOR);
   double sharpe = TesterStatistics(STAT_SHARPE_RATIO);
   double recov  = TesterStatistics(STAT_RECOVERY_FACTOR);
   double wr     = trades > 0 ? TesterStatistics(STAT_PROFIT_TRADES) / trades * 100 : 0;

   if(trades < 30 || profit <= 0 || maxDD > InpMaxDrawdownPct || wr < 40 || pf < 1.2)
      return 0;

   double fitness = (maxDD > 0.1) ? profit / maxDD : profit * 10;
   if(wr > 50)     fitness *= (1.0 + (wr - 50) / 100.0);
   if(pf > 1.5)    fitness *= (1.0 + (pf - 1.5) / 10.0);
   if(sharpe > 0)   fitness *= (1.0 + sharpe / 10.0);
   if(recov > 1)    fitness *= (1.0 + MathMin(recov, 5.0) / 10.0);

   return fitness;
  }
//+------------------------------------------------------------------+
