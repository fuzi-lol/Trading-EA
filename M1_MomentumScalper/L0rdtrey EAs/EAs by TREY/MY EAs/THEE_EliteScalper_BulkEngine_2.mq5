//+------------------------------------------------------------------+
//|              THEE EliteScalper — BULK ENGINE v6.0                |
//|                    Copyright 2026, FXBotHub Systems              |
//|                         https://fxbothub.com                     |
//+------------------------------------------------------------------+
//  BULK ENGINE v6.0 — MARKET ANALYSIS EDITION
//  Signal Engine  : 5-Layer Confluence (EMA Trend + RSI + ATR + 
//                   Candle Structure + Higher-TF Bias)
//  Execution      : 10 trades, 1 every 10 seconds, same direction
//  Auto-Close     : Each trade closes at $0.50 profit individually
//  Guard Rails    : Round Abort if signal flips mid-round
//                   Daily drawdown limit kills all trades
//                   Per-round max loss bail-out
//  Cooldown       : 60s anti-manipulation pause between rounds
//+------------------------------------------------------------------+
#property copyright   "Copyright 2026, FXBotHub Systems"
#property version     "6.00"
#property description "THEE EliteScalper — Bulk Engine v6.0 | 5-Layer Signal"
#property strict

#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>

#define DASH_PREFIX "FXBH_BLK6_"

//+------------------------------------------------------------------+
//| STATE MACHINE                                                    |
//+------------------------------------------------------------------+
enum ENUM_BULK_STATE
{
   BULK_STATE_SCANNING,
   BULK_STATE_ANALYZING,
   BULK_STATE_FIRING,
   BULK_STATE_MONITORING,
   BULK_STATE_COOLDOWN,
   BULK_STATE_HALTED
};

//+------------------------------------------------------------------+
//| INPUTS                                                           |
//+------------------------------------------------------------------+
input group "=== BULK ENGINE CORE ==="
input ulong   InpMagicNumber        = 999666;
input double  InpLotSize            = 0.01;
input int     InpMaxDailyRounds     = 10;
input int     InpBulkTradeCount     = 10;
input int     InpFireIntervalSec    = 10;

input group "=== PROFIT & LOSS GATES ==="
input double  InpProfitPerTrade     = 0.50;   // Auto-close per trade ($)
input double  InpMaxRoundLoss       = 3.00;   // Abort round if round PnL < -$3.00
input double  InpMaxDailyLoss       = 10.00;  // Halt EA if daily loss > $10.00

input group "=== COOLDOWN ==="
input int     InpCooldownSeconds    = 60;

input group "=== SIGNAL ENGINE — EMA TREND ==="
input int     InpFastEMA            = 9;
input int     InpSlowEMA            = 21;
input int     InpTrendEMA           = 50;     // Higher bias EMA

input group "=== SIGNAL ENGINE — RSI FILTER ==="
input int     InpRSIPeriod          = 14;
input double  InpRSIOverbought      = 65.0;   // Block BUY above this
input double  InpRSIOversold        = 35.0;   // Block SELL below this

input group "=== SIGNAL ENGINE — ATR VOLATILITY ==="
input int     InpATRPeriod          = 14;
input double  InpATRMinMultiple     = 0.5;    // Min ATR required (avoids dead markets)
input double  InpATRMaxMultiple     = 3.0;    // Max ATR allowed (avoids news spikes)

input group "=== SIGNAL ENGINE — CANDLE STRUCTURE ==="
input int     InpCandleLookback     = 3;      // Bars to confirm swing structure

input group "=== SIGNAL ENGINE — HIGHER TF BIAS ==="
input ENUM_TIMEFRAMES InpHTFPeriod  = PERIOD_H1; // Higher TF for trend bias

input group "=== EXECUTION GUARDRAILS ==="
input int     InpStopLossPoints     = 300;
input int     InpTakeProfitPoints   = 600;
input int     InpMaxSpreadPoints    = 25;
input int     InpAnalysisMinTicks   = 30;
input int     InpAnalysisMinSeconds = 8;
input int     InpAnalysisMaxSeconds = 120;

input group "=== DASHBOARD ==="
input int     InpDashX              = 15;
input int     InpDashY              = 15;

//+------------------------------------------------------------------+
//| COLOR PALETTE                                                    |
//+------------------------------------------------------------------+
const color C_BG         = C'4,6,10';
const color C_PANEL      = C'10,16,26';
const color C_HEADER     = C'14,32,66';
const color C_GLOW       = C'0,90,180';
const color C_BLUE       = C'0,140,255';
const color C_GREEN      = C'0,225,120';
const color C_RED        = C'235,45,65';
const color C_GOLD       = C'255,185,25';
const color C_PURPLE     = C'180,0,255';
const color C_ORANGE     = C'255,110,0';
const color C_WHITE      = C'235,242,255';
const color C_MUTED      = C'130,145,170';
const color C_TEAL       = C'0,200,180';

//+------------------------------------------------------------------+
//| SIGNAL STRUCT — holds all layer scores                           |
//+------------------------------------------------------------------+
struct SignalResult
{
   bool        valid;          // true = tradeable signal found
   ENUM_ORDER_TYPE direction;
   int         score;          // 0–5 confluence score
   bool        emaAligned;     // Layer 1: EMA stack
   bool        htfAligned;     // Layer 2: Higher TF bias
   bool        rsiClean;       // Layer 3: RSI not extreme
   bool        atrValid;       // Layer 4: ATR in range
   bool        candleConfirm;  // Layer 5: Candle structure
   double      rsiValue;
   double      atrValue;
   double      atrAvg;
   string      rejReason;
};

//+------------------------------------------------------------------+
//| GLOBALS                                                          |
//+------------------------------------------------------------------+
CTrade          g_Trade;
CPositionInfo   g_PosInfo;

// Indicator handles
int  g_hFastEMA   = INVALID_HANDLE;
int  g_hSlowEMA   = INVALID_HANDLE;
int  g_hTrendEMA  = INVALID_HANDLE;
int  g_hHTFEMA    = INVALID_HANDLE;   // H1 slow EMA for HTF bias
int  g_hRSI       = INVALID_HANDLE;
int  g_hATR       = INVALID_HANDLE;

// State
ENUM_BULK_STATE g_State       = BULK_STATE_SCANNING;
datetime        g_StateTimer  = 0;

// Analysis
ENUM_ORDER_TYPE g_PendingDir  = ORDER_TYPE_BUY;
int             g_AnaTickCnt  = 0;
datetime        g_AnaStart    = 0;

// Round tracking
ENUM_ORDER_TYPE g_RoundDir    = ORDER_TYPE_BUY;
int             g_TradesFired = 0;
datetime        g_NextFire    = 0;
ulong           g_Tickets[10];
bool            g_Closed[10];
int             g_TickReg     = 0;

// Session stats
int    g_DayRounds  = 0;
int    g_DayTrades  = 0;
double g_DayProfit  = 0.0;
int    g_DayWins    = 0;
int    g_DayLosses  = 0;
datetime g_DayStart = 0;

// Dashboard state
string g_Heartbeat  = "0 0 0 0";
string g_StatusTxt  = "BOOTING";
color  g_StatusClr  = C_GOLD;
string g_SigScoreTxt = "---";
string g_SigLayerTxt = "LAYER STATUS PENDING";
color  g_SigScoreClr = C_MUTED;

//+------------------------------------------------------------------+
//| FORWARD DECLARATIONS                                             |
//+------------------------------------------------------------------+
SignalResult    AnalyseMarket();
bool            ValidateSignalStability(ENUM_ORDER_TYPE dir);
void            LaunchBulkRound(ENUM_ORDER_TYPE dir);
void            FireNextTrade();
void            MonitorTrades();
void            AbortRound(string reason);
bool            AllClosed();
int             OpenCount();
void            ExecTrade(ENUM_ORDER_TYPE dir);
void            RegisterTkt(ulong tkt);
double          RoundPnL();
bool            MarketOpen();
void            SyncStats();
datetime        Midnight(datetime t);
double          FloatPnL();
void            BuildDash();
void            UpdateDash();
void            PurgeDash();
void            MkBox(string n, int x, int y, int w, int h, color bg, color bdr, int bw);
void            MkLbl(string n, int x, int y, string t, color c, int fs, string f);
void            SetLbl(string n, string t, color c = clrNONE);

//+------------------------------------------------------------------+
//| OnInit                                                           |
//+------------------------------------------------------------------+
int OnInit()
{
   g_Trade.SetExpertMagicNumber(InpMagicNumber);
   g_Trade.SetDeviationInPoints(20);

   g_hFastEMA  = iMA(_Symbol, _Period,    InpFastEMA,  0, MODE_EMA, PRICE_CLOSE);
   g_hSlowEMA  = iMA(_Symbol, _Period,    InpSlowEMA,  0, MODE_EMA, PRICE_CLOSE);
   g_hTrendEMA = iMA(_Symbol, _Period,    InpTrendEMA, 0, MODE_EMA, PRICE_CLOSE);
   g_hHTFEMA   = iMA(_Symbol, InpHTFPeriod, InpSlowEMA, 0, MODE_EMA, PRICE_CLOSE);
   g_hRSI      = iRSI(_Symbol, _Period,   InpRSIPeriod, PRICE_CLOSE);
   g_hATR      = iATR(_Symbol, _Period,   InpATRPeriod);

   if(g_hFastEMA==INVALID_HANDLE || g_hSlowEMA==INVALID_HANDLE ||
      g_hTrendEMA==INVALID_HANDLE || g_hHTFEMA==INVALID_HANDLE ||
      g_hRSI==INVALID_HANDLE || g_hATR==INVALID_HANDLE)
   {
      Alert("THEE BulkEngine v6: Indicator init failed");
      return INIT_FAILED;
   }

   g_DayStart = Midnight(TimeCurrent());
   SyncStats();
   ArrayInitialize(g_Tickets, 0);
   ArrayInitialize(g_Closed, true);

   BuildDash();
   EventSetTimer(1);
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| OnDeinit                                                         |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   EventKillTimer();
   PurgeDash();
   IndicatorRelease(g_hFastEMA);  IndicatorRelease(g_hSlowEMA);
   IndicatorRelease(g_hTrendEMA); IndicatorRelease(g_hHTFEMA);
   IndicatorRelease(g_hRSI);      IndicatorRelease(g_hATR);
}

//+------------------------------------------------------------------+
//| OnTimer                                                          |
//+------------------------------------------------------------------+
void OnTimer()
{
   uint c = GetTickCount() % 4;
   g_Heartbeat = (c==0)?"1 0 1 1  0 1 0 0":(c==1)?"0 1 0 0  1 0 1 1":(c==2)?"1 1 0 1  0 0 1 0":"0 0 1 0  1 1 0 1";
   SyncStats();
   UpdateDash();
}

//+------------------------------------------------------------------+
//| OnTick — Main Engine Loop                                        |
//+------------------------------------------------------------------+
void OnTick()
{
   //--- HALTED
   if(g_State == BULK_STATE_HALTED)
   {
      g_StatusTxt = "EA HALTED — DAILY LOSS LIMIT HIT";
      g_StatusClr = C_RED;
      return;
   }

   //--- Market check
   if(!MarketOpen()) { g_StatusTxt = "MARKET CLOSED"; g_StatusClr = C_RED; return; }

   //--- Daily drawdown hard stop
   SyncStats();
   if(g_DayProfit <= -(InpMaxDailyLoss))
   {
      AbortRound("Daily loss limit breached — EA halting");
      g_State     = BULK_STATE_HALTED;
      g_StatusTxt = "HALTED: DAILY LOSS LIMIT $" + DoubleToString(InpMaxDailyLoss, 2);
      g_StatusClr = C_RED;
      return;
   }

   //--- COOLDOWN
   if(g_State == BULK_STATE_COOLDOWN)
   {
      int left = (int)(g_StateTimer - TimeCurrent());
      if(left > 0)
      {
         g_StatusTxt = "COOLDOWN — NEXT ROUND IN " + IntegerToString(left) + "s";
         g_StatusClr = C_GOLD;
         return;
      }
      g_State     = BULK_STATE_SCANNING;
      g_StatusTxt = "COOLDOWN COMPLETE — SCANNING";
      g_StatusClr = C_BLUE;
   }

   //--- Daily round limit
   if(g_DayRounds >= InpMaxDailyRounds)
   {
      g_StatusTxt = "DAILY ROUND LIMIT REACHED (" + IntegerToString(InpMaxDailyRounds) + ")";
      g_StatusClr = C_GOLD;
      return;
   }

   //--- ACTIVE ROUND (FIRING + MONITORING unified)
   if(g_State == BULK_STATE_FIRING || g_State == BULK_STATE_MONITORING)
   {
      //-- Per-round loss bail-out
      double rpnl = RoundPnL();
      if(rpnl <= -(InpMaxRoundLoss))
      {
         AbortRound("Round loss limit $" + DoubleToString(InpMaxRoundLoss,2) + " breached. PnL: $" + DoubleToString(rpnl,2));
         return;
      }

      //-- Monitor each trade for $0.50 profit auto-close
      MonitorTrades();

      //-- Keep firing until all InpBulkTradeCount trades sent
      if(g_TradesFired < InpBulkTradeCount)
      {
         //-- Mid-round signal reversal check: abort if market flips
         if(g_TradesFired >= 2 && !ValidateSignalStability(g_RoundDir))
         {
            AbortRound("Signal reversed mid-round at trade " + IntegerToString(g_TradesFired));
            return;
         }

         if(TimeCurrent() >= g_NextFire)
            FireNextTrade();

         int left = (int)(g_NextFire - TimeCurrent());
         g_StatusTxt = "FIRING " + IntegerToString(g_TradesFired) + "/" + IntegerToString(InpBulkTradeCount)
                     + " | NEXT " + IntegerToString(MathMax(0,left)) + "s | OPEN:" + IntegerToString(OpenCount());
         g_StatusClr = C_ORANGE;
         g_State     = BULK_STATE_FIRING;
      }
      else
      {
         g_State     = BULK_STATE_MONITORING;
         g_StatusTxt = "WAITING $" + DoubleToString(InpProfitPerTrade,2) + "/ea | OPEN:" + IntegerToString(OpenCount())
                     + " | RoundPnL: $" + DoubleToString(RoundPnL(),2);
         g_StatusClr = C_BLUE;
      }

      //-- Round complete check
      if(AllClosed())
      {
         g_DayRounds++;
         g_State      = BULK_STATE_COOLDOWN;
         g_StateTimer = TimeCurrent() + InpCooldownSeconds;
         g_StatusTxt  = "ROUND " + IntegerToString(g_DayRounds) + " COMPLETE — COOLING " + IntegerToString(InpCooldownSeconds) + "s";
         g_StatusClr  = C_GREEN;
         Print("[BulkEngine v6] Round ", g_DayRounds, " complete. Cooldown ", InpCooldownSeconds, "s.");
      }
      return;
   }

   //--- Spread gate
   int spread = (int)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   if(spread > InpMaxSpreadPoints)
   {
      g_StatusTxt = "SPREAD TOO WIDE: " + IntegerToString(spread) + " pts (limit " + IntegerToString(InpMaxSpreadPoints) + ")";
      g_StatusClr = C_RED;
      return;
   }

   //--- SCANNING
   if(g_State == BULK_STATE_SCANNING)
   {
      SignalResult sig = AnalyseMarket();
      UpdateSignalDisplay(sig);

      if(!sig.valid)
      {
         g_StatusTxt = "SCANNING — " + sig.rejReason;
         g_StatusClr = C_MUTED;
         return;
      }

      g_State         = BULK_STATE_ANALYZING;
      g_PendingDir    = sig.direction;
      g_AnaStart      = TimeCurrent();
      g_AnaTickCnt    = 0;
      g_StatusTxt     = "SIGNAL CONFIRMED [" + IntegerToString(sig.score) + "/5] — ANALYZING...";
      g_StatusClr     = C_PURPLE;
      Print("[BulkEngine v6] Signal: ", EnumToString(sig.direction), " Score:", sig.score, "/5");
   }

   //--- ANALYZING
   else if(g_State == BULK_STATE_ANALYZING)
   {
      g_AnaTickCnt++;
      int elapsed = (int)(TimeCurrent() - g_AnaStart);

      g_StatusTxt = "ANALYZING: " + IntegerToString(elapsed) + "s | TICKS:" + IntegerToString(g_AnaTickCnt);
      g_StatusClr = C_PURPLE;

      if(elapsed > InpAnalysisMaxSeconds)
      {
         g_State     = BULK_STATE_SCANNING;
         g_StatusTxt = "ANALYSIS TIMEOUT — RESCANNING";
         Print("[BulkEngine v6] Analysis timeout. Rescanning.");
         return;
      }

      // Re-evaluate signal — must stay valid and same direction
      SignalResult sig = AnalyseMarket();
      UpdateSignalDisplay(sig);

      if(!sig.valid || sig.direction != g_PendingDir)
      {
         g_State     = BULK_STATE_SCANNING;
         g_StatusTxt = "SETUP INVALIDATED — RESCANNING";
         Print("[BulkEngine v6] Setup invalidated during analysis.");
         return;
      }

      if(elapsed >= InpAnalysisMinSeconds && g_AnaTickCnt >= InpAnalysisMinTicks)
      {
         LaunchBulkRound(g_PendingDir);
      }
   }
}

//+------------------------------------------------------------------+
//| 5-LAYER MARKET ANALYSIS ENGINE                                   |
//+------------------------------------------------------------------+
SignalResult AnalyseMarket()
{
   SignalResult r;
   r.valid = false; r.score = 0; r.rejReason = "";

   double fast[2], slow[2], trend[2], htf[2], rsi[1], atr[14];

   if(CopyBuffer(g_hFastEMA,  0, 0, 2, fast)  <= 0 ||
      CopyBuffer(g_hSlowEMA,  0, 0, 2, slow)  <= 0 ||
      CopyBuffer(g_hTrendEMA, 0, 0, 2, trend) <= 0 ||
      CopyBuffer(g_hHTFEMA,   0, 0, 2, htf)   <= 0 ||
      CopyBuffer(g_hRSI,      0, 0, 1, rsi)   <= 0 ||
      CopyBuffer(g_hATR,      0, 0, 14, atr)  <= 0)
   {
      r.rejReason = "INDICATOR DATA UNAVAILABLE";
      return r;
   }

   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);

   //--- LAYER 1: EMA STACK (Fast > Slow > Trend = Bull | Fast < Slow < Trend = Bear)
   bool emaBull = (fast[0] > slow[0] && slow[0] > trend[0]);
   bool emaBear = (fast[0] < slow[0] && slow[0] < trend[0]);
   r.emaAligned = (emaBull || emaBear);
   if(r.emaAligned) r.score++;

   //--- LAYER 2: HIGHER TIMEFRAME BIAS (H1 EMA direction)
   bool htfBull = (bid > htf[0]);
   bool htfBear = (bid < htf[0]);
   // HTF must align with EMA direction
   bool htfMatchBull = (emaBull && htfBull);
   bool htfMatchBear = (emaBear && htfBear);
   r.htfAligned = (htfMatchBull || htfMatchBear);
   if(r.htfAligned) r.score++;

   //--- LAYER 3: RSI FILTER (avoid extreme zones)
   r.rsiValue = rsi[0];
   bool rsiOkBull = (emaBull && rsi[0] > 40.0 && rsi[0] < InpRSIOverbought);
   bool rsiOkBear = (emaBear && rsi[0] < 60.0 && rsi[0] > InpRSIOversold);
   r.rsiClean = (rsiOkBull || rsiOkBear);
   if(r.rsiClean) r.score++;

   //--- LAYER 4: ATR VOLATILITY GATE (not dead, not spiking)
   double atrNow = atr[0];
   double atrAvg = 0.0;
   for(int i = 1; i < 14; i++) atrAvg += atr[i];
   atrAvg /= 13.0;
   r.atrValue = atrNow;
   r.atrAvg   = atrAvg;
   bool atrOk = (atrNow >= atrAvg * InpATRMinMultiple && atrNow <= atrAvg * InpATRMaxMultiple);
   r.atrValid = atrOk;
   if(r.atrValid) r.score++;

   //--- LAYER 5: CANDLE STRUCTURE (swing high/low confirmation)
   // Bull: last N closes trending up (higher closes)
   // Bear: last N closes trending down (lower closes)
   double closes[];
   ArraySetAsSeries(closes, true);
   if(CopyClose(_Symbol, _Period, 0, InpCandleLookback + 1, closes) > 0)
   {
      bool candleBull = true, candleBear = true;
      for(int i = 0; i < InpCandleLookback - 1; i++)
      {
         if(closes[i] <= closes[i+1]) candleBull = false;
         if(closes[i] >= closes[i+1]) candleBear = false;
      }
      bool candleOk = (emaBull && candleBull) || (emaBear && candleBear);
      r.candleConfirm = candleOk;
      if(r.candleConfirm) r.score++;
   }

   //--- DIRECTION
   if(emaBull) r.direction = ORDER_TYPE_BUY;
   else        r.direction = ORDER_TYPE_SELL;

   //--- MINIMUM 4/5 LAYERS REQUIRED
   if(r.score < 4)
   {
      r.rejReason = "SCORE " + IntegerToString(r.score) + "/5 — NEED 4+";
      return r;
   }

   //--- Must have EMA + HTF (non-negotiable core layers)
   if(!r.emaAligned)  { r.rejReason = "EMA STACK NOT ALIGNED";  return r; }
   if(!r.htfAligned)  { r.rejReason = "HTF BIAS CONFLICT";       return r; }
   if(!r.rsiClean)    { r.rejReason = "RSI ZONE BLOCKED";         return r; }
   if(!r.atrValid)    { r.rejReason = "ATR OUT OF RANGE";         return r; }

   r.valid = true;
   return r;
}

//+------------------------------------------------------------------+
//| Mid-round stability check — fast read only                       |
//+------------------------------------------------------------------+
bool ValidateSignalStability(ENUM_ORDER_TYPE dir)
{
   double fast[1], slow[1], trend[1];
   if(CopyBuffer(g_hFastEMA,  0, 0, 1, fast)  <= 0) return true; // can't check, allow
   if(CopyBuffer(g_hSlowEMA,  0, 0, 1, slow)  <= 0) return true;
   if(CopyBuffer(g_hTrendEMA, 0, 0, 1, trend) <= 0) return true;

   bool bull = (fast[0] > slow[0] && slow[0] > trend[0]);
   bool bear = (fast[0] < slow[0] && slow[0] < trend[0]);

   if(dir == ORDER_TYPE_BUY  && !bull) return false;
   if(dir == ORDER_TYPE_SELL && !bear) return false;
   return true;
}

//+------------------------------------------------------------------+
//| Launch a new bulk round                                          |
//+------------------------------------------------------------------+
void LaunchBulkRound(ENUM_ORDER_TYPE dir)
{
   g_RoundDir    = dir;
   g_TradesFired = 0;
   g_TickReg     = 0;
   ArrayInitialize(g_Tickets, 0);
   ArrayInitialize(g_Closed, true); // slots start as "closed" — flip on register
   g_State       = BULK_STATE_FIRING;
   g_NextFire    = TimeCurrent();   // fire first one immediately
   FireNextTrade();
   Print("[BulkEngine v6] Round launched. Dir:", EnumToString(dir));
}

//+------------------------------------------------------------------+
//| Fire one trade in the round                                      |
//+------------------------------------------------------------------+
void FireNextTrade()
{
   if(g_TradesFired >= InpBulkTradeCount) return;

   int spread = (int)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   if(spread > InpMaxSpreadPoints)
   {
      Print("[BulkEngine v6] Fire skipped — spread ", spread, " > limit ", InpMaxSpreadPoints);
      g_NextFire = TimeCurrent() + InpFireIntervalSec;
      return;
   }

   ExecTrade(g_RoundDir);
   g_TradesFired++;
   g_NextFire = TimeCurrent() + InpFireIntervalSec;
   Print("[BulkEngine v6] Fired ", g_TradesFired, "/", InpBulkTradeCount, " Dir:", EnumToString(g_RoundDir));
}

//+------------------------------------------------------------------+
//| Execute a single market order                                    |
//+------------------------------------------------------------------+
void ExecTrade(ENUM_ORDER_TYPE dir)
{
   double price = (dir==ORDER_TYPE_BUY) ? SymbolInfoDouble(_Symbol,SYMBOL_ASK) : SymbolInfoDouble(_Symbol,SYMBOL_BID);
   double pt    = SymbolInfoDouble(_Symbol,SYMBOL_POINT);
   int    digs  = (int)SymbolInfoInteger(_Symbol,SYMBOL_DIGITS);
   double minV  = SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN);
   double maxV  = SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MAX);
   double step  = SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_STEP);
   double lot   = MathMax(minV, MathMin(maxV, MathRound(InpLotSize/step)*step));

   double sl = 0, tp = 0;
   if(InpStopLossPoints>0)
      sl = NormalizeDouble((dir==ORDER_TYPE_BUY)?price-InpStopLossPoints*pt:price+InpStopLossPoints*pt, digs);
   if(InpTakeProfitPoints>0)
      tp = NormalizeDouble((dir==ORDER_TYPE_BUY)?price+InpTakeProfitPoints*pt:price-InpTakeProfitPoints*pt, digs);

   bool ok = (dir==ORDER_TYPE_BUY)
             ? g_Trade.Buy(lot,_Symbol,price,sl,tp,"BulkEng_v6")
             : g_Trade.Sell(lot,_Symbol,price,sl,tp,"BulkEng_v6");

   if(ok)
   {
      RegisterTkt(g_Trade.ResultOrder());
      g_DayTrades++;
   }
   else
      Print("[BulkEngine v6] Order failed: ", g_Trade.ResultRetcode(), " — ", g_Trade.ResultRetcodeDescription());
}

//+------------------------------------------------------------------+
//| Register ticket                                                  |
//+------------------------------------------------------------------+
void RegisterTkt(ulong tkt)
{
   if(g_TickReg < 10) { g_Tickets[g_TickReg] = tkt; g_Closed[g_TickReg] = false; g_TickReg++; }
}

//+------------------------------------------------------------------+
//| Monitor open trades — auto-close at $0.50 profit each           |
//+------------------------------------------------------------------+
void MonitorTrades()
{
   for(int i = 0; i < g_TickReg; i++)
   {
      if(g_Closed[i] || g_Tickets[i]==0) continue;
      if(!PositionSelectByTicket(g_Tickets[i])) { g_Closed[i]=true; continue; }

      double pnl = PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);
      if(pnl >= InpProfitPerTrade)
      {
         if(g_Trade.PositionClose(g_Tickets[i]))
         {
            g_Closed[i] = true;
            Print("[BulkEngine v6] Trade ", g_Tickets[i], " closed at $", DoubleToString(pnl,2));
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Abort round — close all open trades immediately                  |
//+------------------------------------------------------------------+
void AbortRound(string reason)
{
   Print("[BulkEngine v6] ABORTING ROUND — ", reason);
   for(int i = 0; i < g_TickReg; i++)
   {
      if(g_Closed[i] || g_Tickets[i]==0) continue;
      if(PositionSelectByTicket(g_Tickets[i]))
      {
         if(g_Trade.PositionClose(g_Tickets[i]))
            g_Closed[i] = true;
      }
   }
   g_State      = BULK_STATE_COOLDOWN;
   g_StateTimer = TimeCurrent() + InpCooldownSeconds;
   g_StatusTxt  = "ROUND ABORTED: " + reason;
   g_StatusClr  = C_RED;
}

//+------------------------------------------------------------------+
//| All trades in this round closed?                                 |
//+------------------------------------------------------------------+
bool AllClosed()
{
   if(g_TradesFired < InpBulkTradeCount) return false;
   return (OpenCount() == 0);
}

//+------------------------------------------------------------------+
//| Count open positions for this EA                                 |
//+------------------------------------------------------------------+
int OpenCount()
{
   int n = 0;
   for(int i = PositionsTotal()-1; i >= 0; i--)
      if(g_PosInfo.SelectByIndex(i) && g_PosInfo.Magic()==InpMagicNumber && g_PosInfo.Symbol()==_Symbol)
         n++;
   return n;
}

//+------------------------------------------------------------------+
//| Round floating PnL                                               |
//+------------------------------------------------------------------+
double RoundPnL()
{
   double t = 0;
   for(int i = PositionsTotal()-1; i >= 0; i--)
      if(g_PosInfo.SelectByIndex(i) && g_PosInfo.Magic()==InpMagicNumber && g_PosInfo.Symbol()==_Symbol)
         t += g_PosInfo.Profit() + g_PosInfo.Swap() + g_PosInfo.Commission();
   return t;
}

double FloatPnL() { return RoundPnL(); }

//+------------------------------------------------------------------+
bool MarketOpen()
{
   ENUM_SYMBOL_TRADE_MODE m = (ENUM_SYMBOL_TRADE_MODE)SymbolInfoInteger(_Symbol,SYMBOL_TRADE_MODE);
   return (m==SYMBOL_TRADE_MODE_FULL||m==SYMBOL_TRADE_MODE_LONGONLY||m==SYMBOL_TRADE_MODE_SHORTONLY);
}

//+------------------------------------------------------------------+
void SyncStats()
{
   datetime now = TimeCurrent(), mid = Midnight(now);
   if(mid > g_DayStart) { g_DayRounds=0;g_DayTrades=0;g_DayProfit=0;g_DayWins=0;g_DayLosses=0;g_DayStart=mid; }
   g_DayProfit=0; g_DayWins=0; g_DayLosses=0;
   if(HistorySelect(g_DayStart,now))
      for(int i=0;i<HistoryDealsTotal();i++)
      {
         ulong t=HistoryDealGetTicket(i);
         if(t>0 && HistoryDealGetInteger(t,DEAL_MAGIC)==InpMagicNumber && HistoryDealGetString(t,DEAL_SYMBOL)==_Symbol
            && HistoryDealGetInteger(t,DEAL_ENTRY)==DEAL_ENTRY_OUT)
         {
            double p=HistoryDealGetDouble(t,DEAL_PROFIT)+HistoryDealGetDouble(t,DEAL_COMMISSION)+HistoryDealGetDouble(t,DEAL_SWAP);
            g_DayProfit+=p;
            if(p>=0)g_DayWins++;else g_DayLosses++;
         }
      }
}

datetime Midnight(datetime t) { MqlDateTime d; TimeToStruct(t,d); return t-(datetime)(d.hour*3600+d.min*60+d.sec); }

//+------------------------------------------------------------------+
//| Update signal layer display string                               |
//+------------------------------------------------------------------+
void UpdateSignalDisplay(SignalResult &sig)
{
   g_SigScoreTxt = IntegerToString(sig.score) + " / 5";
   g_SigScoreClr = (sig.score>=4) ? C_GREEN : (sig.score>=2) ? C_GOLD : C_RED;

   g_SigLayerTxt = "EMA:" + (sig.emaAligned?"✓":"✗")
                 + "  HTF:" + (sig.htfAligned?"✓":"✗")
                 + "  RSI:" + (sig.rsiClean?"✓":"✗") + "(" + DoubleToString(sig.rsiValue,1) + ")"
                 + "  ATR:" + (sig.atrValid?"✓":"✗")
                 + "  CDL:" + (sig.candleConfirm?"✓":"✗");
}

//====================================================================
//  DASHBOARD — v6.0
//====================================================================
void BuildDash()
{
   int x=InpDashX, y=InpDashY, W=480, H=680;

   MkBox("Bg",  x,   y,   W,   H,   C_BG,     C_GLOW, 2);
   MkBox("Hdr", x+2, y+2, W-4, 80,  C_HEADER, C_GLOW, 1);

   MkLbl("T1",  x+16, y+10, "THEE ELITE SCALPER",               C_WHITE, 18, "Algerian");
   MkLbl("T2",  x+16, y+38, "BULK EXECUTION ENGINE v6.0",        C_BLUE,   9, "Arial Black");
   MkLbl("T3",  x+16, y+56, "5-Layer Signal | $0.50 Auto-Close | Abort Guard | 60s Cooldown", C_MUTED, 8, "Arial Italic");
   MkLbl("Sym", x+W-115, y+14, _Symbol,                          C_GOLD,  14, "Impact");

   // Heartbeat
   MkBox("PBg", x+2, y+85, W-4, 26, C_PANEL, clrNONE, 0);
   MkLbl("PLbl",x+16, y+91, "[ ENGINE RUNTIME MATRIX ]:",        C_MUTED,  8, "Consolas Black");
   MkLbl("PVal",x+215,y+91, "0 0 0 0",                           C_BLUE,   9, "Consolas");

   // PANEL 1 — Financials
   int p1=y+116;
   MkBox("P1", x+2, p1, W-4, 148, C_PANEL, C_GLOW, 1);
   MkLbl("P1H",x+16, p1+10, "LIVE FINANCIAL DYNAMICS",           C_WHITE, 10, "Arial Black");
   MkLbl("LA", x+22, p1+36, "Account Balance:",                  C_MUTED,  9, "Arial");
   MkLbl("VA", x+230,p1+36, "$ 0.00",                            C_WHITE, 10, "Arial Bold");
   MkLbl("LE", x+22, p1+58, "Net Equity:",                       C_MUTED,  9, "Arial");
   MkLbl("VE", x+230,p1+58, "$ 0.00",                            C_WHITE, 10, "Arial Bold");
   MkLbl("LD", x+22, p1+80, "Daily Net Yield:",                  C_MUTED,  9, "Arial");
   MkLbl("VD", x+230,p1+80, "$ 0.00",                            C_GREEN, 10, "Arial Black");
   MkLbl("LF", x+22, p1+102,"Floating P&L:",                     C_MUTED,  9, "Arial");
   MkLbl("VF", x+230,p1+102,"$ 0.00",                            C_GREEN, 10, "Arial Black");
   MkLbl("LDL",x+22, p1+124,"Daily Loss Limit:",                 C_MUTED,  8, "Arial");
   MkLbl("VDL",x+230,p1+124,"$"+DoubleToString(InpMaxDailyLoss,2)+" guard active", C_TEAL, 8, "Arial Bold");

   // PANEL 2 — Signal Analysis
   int p2=y+272;
   MkBox("P2",  x+2, p2, W-4, 148, C_PANEL, C_GLOW, 1);
   MkLbl("P2H", x+16, p2+10, "5-LAYER SIGNAL ENGINE",            C_WHITE, 10, "Arial Black");
   MkLbl("LSc", x+22, p2+36, "Confluence Score:",                C_MUTED,  9, "Arial");
   MkLbl("VSc", x+230,p2+36, "--- / 5",                          C_GOLD,  10, "Arial Black");
   MkLbl("LLy", x+22, p2+58, "Layer Status:",                    C_MUTED,  8, "Arial");
   MkLbl("VLy", x+22, p2+74, "EMA:? HTF:? RSI:? ATR:? CDL:?",   C_MUTED,  8, "Consolas");
   MkLbl("LSp", x+22, p2+100,"Spread:",                          C_MUTED,  9, "Arial");
   MkLbl("VSp", x+100,p2+100,"0 pts",                            C_WHITE,  9, "Arial Bold");
   MkLbl("LMs", x+180,p2+100,"Market:",                          C_MUTED,  9, "Arial");
   MkLbl("VMs", x+248,p2+100,"ACTIVE",                           C_GREEN,  9, "Arial Bold");
   MkLbl("LRD", x+22, p2+122,"Round Direction:",                 C_MUTED,  9, "Arial");
   MkLbl("VRD", x+230,p2+122,"SCANNING...",                      C_WHITE,  9, "Arial Bold");

   // PANEL 3 — Bulk Pipeline
   int p3=y+428;
   MkBox("P3",  x+2, p3, W-4, 210, C_PANEL, C_GLOW, 1);
   MkLbl("P3H", x+16, p3+10, "BULK EXECUTION PIPELINE",         C_WHITE, 10, "Arial Black");
   MkLbl("LSt", x+22, p3+36, "Engine Status:",                  C_MUTED,  9, "Arial");
   MkLbl("VSt", x+155,p3+36, "INITIALIZING",                    C_BLUE,   9, "Arial Black");
   MkLbl("LRn", x+22, p3+60, "Rounds Today:",                   C_MUTED,  9, "Arial");
   MkLbl("VRn", x+230,p3+60, "0 / 10",                          C_WHITE,  9, "Arial Bold");
   MkLbl("LFr", x+22, p3+82, "Trades Fired:",                   C_MUTED,  9, "Arial");
   MkLbl("VFr", x+230,p3+82, "0 / 10",                          C_ORANGE, 9, "Arial Bold");
   MkLbl("LOp", x+22, p3+104,"Open Trades:",                    C_MUTED,  9, "Arial");
   MkLbl("VOp", x+230,p3+104,"0",                               C_WHITE,  9, "Arial Bold");
   MkLbl("LTg", x+22, p3+126,"Close Target/Trade:",             C_MUTED,  9, "Arial");
   MkLbl("VTg", x+230,p3+126,"$"+DoubleToString(InpProfitPerTrade,2), C_GREEN, 9, "Arial Bold");
   MkLbl("LRl", x+22, p3+148,"Round Loss Limit:",               C_MUTED,  9, "Arial");
   MkLbl("VRl", x+230,p3+148,"$"+DoubleToString(InpMaxRoundLoss,2)+" abort", C_TEAL, 9, "Arial Bold");
   MkLbl("LWR", x+22, p3+170,"Win Rate:",                       C_MUTED,  9, "Arial");
   MkLbl("VWR", x+230,p3+170,"0.0 %",                           C_WHITE,  9, "Arial Bold");
   MkLbl("LTt", x+22, p3+192,"Trades Today:",                   C_MUTED,  9, "Arial");
   MkLbl("VTt", x+230,p3+192,"0",                               C_WHITE,  9, "Arial Bold");

   // Footer
   MkLbl("Ft1",x+10,  y+650,"5-Layer Analysis | Abort Guard | Anti-Manipulation Cooldown", C_MUTED, 7, "Arial");
   MkLbl("Ft2",x+330, y+650,"BULK ENGINE v6.00",                C_MUTED, 7, "Arial Black");

   ChartRedraw(0);
}

void UpdateDash()
{
   SetLbl("PVal", g_Heartbeat, C_BLUE);

   SetLbl("VA", "$ " + DoubleToString(AccountInfoDouble(ACCOUNT_BALANCE),2));
   SetLbl("VE", "$ " + DoubleToString(AccountInfoDouble(ACCOUNT_EQUITY),2));

   color cd = (g_DayProfit>=0)?C_GREEN:C_RED;
   SetLbl("VD", (g_DayProfit>=0?"+$":"-$") + DoubleToString(MathAbs(g_DayProfit),2), cd);

   double fp = FloatPnL();
   color cf = (fp>=0)?C_GREEN:C_RED;
   SetLbl("VF", (fp>=0?"+$":"-$") + DoubleToString(MathAbs(fp),2), cf);

   SetLbl("VSc", g_SigScoreTxt, g_SigScoreClr);
   SetLbl("VLy", g_SigLayerTxt, C_TEAL);

   SetLbl("VSp", IntegerToString((int)SymbolInfoInteger(_Symbol,SYMBOL_SPREAD))+" pts");
   SetLbl("VMs", MarketOpen()?"ACTIVE":"CLOSED", MarketOpen()?C_GREEN:C_RED);

   string dirStr="SCANNING..."; color dirClr=C_MUTED;
   if(g_State==BULK_STATE_FIRING||g_State==BULK_STATE_MONITORING)
   {
      dirStr=(g_RoundDir==ORDER_TYPE_BUY)?"LOCKED BUY  ▲":"LOCKED SELL ▼";
      dirClr=(g_RoundDir==ORDER_TYPE_BUY)?C_GREEN:C_RED;
   }
   SetLbl("VRD", dirStr, dirClr);

   SetLbl("VSt", g_StatusTxt, g_StatusClr);
   SetLbl("VRn", IntegerToString(g_DayRounds)+" / "+IntegerToString(InpMaxDailyRounds));
   SetLbl("VFr", IntegerToString(g_TradesFired)+" / "+IntegerToString(InpBulkTradeCount),
          (g_TradesFired>=InpBulkTradeCount)?C_GREEN:C_ORANGE);
   SetLbl("VOp", IntegerToString(OpenCount()));

   int tot=g_DayWins+g_DayLosses;
   SetLbl("VWR", (tot>0?DoubleToString((double)g_DayWins/tot*100,1):"0.0")+" %");
   SetLbl("VTt", IntegerToString(g_DayTrades));

   ChartRedraw(0);
}

void PurgeDash() { ObjectsDeleteAll(0, DASH_PREFIX); ChartRedraw(0); }

void MkBox(string nm,int x,int y,int w,int h,color bg,color bdr,int bw)
{
   string n=DASH_PREFIX+nm;
   ObjectCreate(0,n,OBJ_RECTANGLE_LABEL,0,0,0);
   ObjectSetInteger(0,n,OBJPROP_CORNER,CORNER_LEFT_UPPER);
   ObjectSetInteger(0,n,OBJPROP_XDISTANCE,x); ObjectSetInteger(0,n,OBJPROP_YDISTANCE,y);
   ObjectSetInteger(0,n,OBJPROP_XSIZE,w);     ObjectSetInteger(0,n,OBJPROP_YSIZE,h);
   ObjectSetInteger(0,n,OBJPROP_BGCOLOR,bg);
   if(bdr!=clrNONE){ObjectSetInteger(0,n,OBJPROP_BORDER_TYPE,BORDER_FLAT);ObjectSetInteger(0,n,OBJPROP_COLOR,bdr);ObjectSetInteger(0,n,OBJPROP_WIDTH,bw);}
   else ObjectSetInteger(0,n,OBJPROP_BORDER_TYPE,BORDER_RAISED);
   ObjectSetInteger(0,n,OBJPROP_SELECTABLE,false);
   ObjectSetInteger(0,n,OBJPROP_HIDDEN,true);
   ObjectSetInteger(0,n,OBJPROP_ZORDER,0);
}

void MkLbl(string nm,int x,int y,string t,color c,int fs,string f)
{
   string n=DASH_PREFIX+nm;
   ObjectCreate(0,n,OBJ_LABEL,0,0,0);
   ObjectSetInteger(0,n,OBJPROP_CORNER,CORNER_LEFT_UPPER);
   ObjectSetInteger(0,n,OBJPROP_XDISTANCE,x); ObjectSetInteger(0,n,OBJPROP_YDISTANCE,y);
   ObjectSetString(0,n,OBJPROP_TEXT,t);        ObjectSetInteger(0,n,OBJPROP_COLOR,c);
   ObjectSetInteger(0,n,OBJPROP_FONTSIZE,fs);  ObjectSetString(0,n,OBJPROP_FONT,f);
   ObjectSetInteger(0,n,OBJPROP_SELECTABLE,false);
   ObjectSetInteger(0,n,OBJPROP_HIDDEN,true);
   ObjectSetInteger(0,n,OBJPROP_ZORDER,1);
}

void SetLbl(string nm,string t,color c=clrNONE)
{
   string n=DASH_PREFIX+nm;
   if(ObjectFind(0,n)>=0)
   {
      ObjectSetString(0,n,OBJPROP_TEXT,t);
      if(c!=clrNONE)ObjectSetInteger(0,n,OBJPROP_COLOR,c);
   }
}
//+------------------------------------------------------------------+
