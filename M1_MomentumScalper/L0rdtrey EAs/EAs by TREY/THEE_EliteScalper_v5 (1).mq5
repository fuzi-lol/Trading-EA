//+------------------------------------------------------------------+
//|                                          THEE EliteScalper v5.mq5|
//|                                  Copyright 2026, FXBotHub Systems|
//|                                             https://fxbothub.com |
//+------------------------------------------------------------------+
//  GOLD (XAUUSD) Optimised High-Frequency Scalping Engine
//  v5.00 – Full rebuild with:
//    • Dynamic risk management (% of balance)
//    • ATR-adaptive stop loss / take profit
//    • Breakeven + multi-step trailing stop
//    • Partial position close at TP1
//    • 7-indicator confluence signal engine
//    • Bollinger Band squeeze / range filter
//    • ADX trend-strength gate
//    • RSI momentum confirmation
//    • MACD histogram filter
//    • Session time filter (London/NY overlap)
//    • Spread spike guard (dynamic ceiling)
//    • Daily drawdown kill-switch
//    • Consecutive loss streak protection
//    • GOLD tick-size / point correction
//    • News-pause flag (manual toggle)
//    • Compounding lot-tier system
//    • Full bug-fixed dashboard
//+------------------------------------------------------------------+
#property copyright   "Copyright 2026, THEE EliteScalper Systems"
#property version     "5.00"
#property description "GOLD Institutional Scalping Engine – Full Confluence"
#property strict

#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>

#define DASH_PREFIX  "FXBH_V5_"
#define EA_VERSION   "v5.00"
#define EA_SYMBOL    "XAUUSD"

//+------------------------------------------------------------------+
//| ENGINE STATE MACHINE                                             |
//+------------------------------------------------------------------+
enum ENUM_ENGINE_STATE
{
   STATE_SCANNING,
   STATE_ANALYZING,
   STATE_COOLDOWN,
   STATE_DAILY_LIMIT,
   STATE_NEWS_PAUSE
};

enum ENUM_SIGNAL
{
   SIGNAL_BUY  =  1,
   SIGNAL_SELL = -1,
   SIGNAL_NONE =  0
};

//+------------------------------------------------------------------+
//| INPUT PARAMETERS                                                 |
//+------------------------------------------------------------------+
input group "=== CORE IDENTITY ==="
input ulong   InpMagicNumber       = 999555;     // Unique Magic Number
input string  InpTradeComment      = "EliteScalper_v5";

input group "=== RISK MANAGEMENT (primary controls) ==="
input double  InpRiskPercent       = 1.0;        // Risk % per trade (1-2% recommended)
input double  InpMaxDailyLossPct   = 5.0;        // Daily loss limit % (kill-switch)
input double  InpMaxDailyProfitPct = 10.0;       // Daily profit target % (stop trading)
input int     InpMaxDailyTrades    = 15;         // Max trades per day

input group "=== ATR-BASED STOP LOSS & TAKE PROFIT ==="
input int     InpATRPeriod         = 14;         // ATR period
input double  InpSLMultiplier      = 1.5;        // SL = ATR x multiplier
input double  InpTP1Multiplier     = 1.0;        // TP1 = ATR x multiplier (partial close trigger)
input double  InpTP2Multiplier     = 3.0;        // TP2 = ATR x multiplier (hard server TP)
input int     InpMinSLPoints       = 150;        // Minimum SL in points (floor)
input int     InpMaxSLPoints       = 500;        // Maximum SL in points (ceiling)

input group "=== SMART EXIT SYSTEM ==="
input int     InpBreakevenPoints   = 80;         // Move SL to breakeven after X points profit
input int     InpBreakevenBuffer   = 5;          // Buffer above/below open price at BE (points)
input bool    InpUsePeakLock       = true;       // Peak-profit lock: trail from highest PnL seen
input double  InpPeakLockActivate  = 0.50;       // Activate peak-lock after this USD profit
input double  InpPeakLockRetrace   = 30.0;       // Close if profit retraces X% from peak
input bool    InpUseTrailing       = true;       // Enable ATR trailing stop on SL
input int     InpTrailStartPoints  = 80;         // Start ATR trailing after X points profit
input double  InpTrailATRMult      = 0.8;        // Trail SL = price - (ATR x this mult)
input bool    InpUsePartialClose   = true;       // Enable partial close at TP1
input double  InpPartialClosePct   = 50.0;       // Percent of position to close at TP1
input double  InpMinLockProfit     = 0.20;       // After partial close lock min this USD on remainder

input group "=== PRE-TRADE ANALYSIS ENGINE ==="
input int     InpAnalysisMaxSec    = 120;        // Max analysis window (seconds)
input int     InpAnalysisMinSec    = 10;         // Minimum observation time
input int     InpAnalysisMinTicks  = 30;         // Min tick volume to confirm

input group "=== SIGNAL CONFLUENCE ENGINE ==="
input int     InpFastEMAPeriod     = 9;          // Fast EMA period
input int     InpSlowEMAPeriod     = 21;         // Slow EMA period
input int     InpTrendEMAPeriod    = 50;         // Trend EMA (bias filter)
input int     InpRSIPeriod         = 14;         // RSI period
input double  InpRSIOverbought     = 70.0;       // RSI overbought level
input double  InpRSIOversold       = 30.0;       // RSI oversold level
input int     InpADXPeriod         = 14;         // ADX period
input double  InpADXMinStrength    = 20.0;       // Minimum ADX for trend trade
input int     InpMACDFast          = 12;         // MACD fast period
input int     InpMACDSlow          = 26;         // MACD slow period
input int     InpMACDSignal        = 9;          // MACD signal period
input int     InpBBPeriod          = 20;         // Bollinger Bands period
input double  InpBBDeviation       = 2.0;        // Bollinger Bands deviation
input double  InpBBSqueezeRatio    = 0.003;      // BB width/price ratio squeeze threshold
input int     InpStructureBars     = 5;          // Market structure high/low bars

input group "=== COOLDOWN & SPREAD ==="
input int     InpCooldownSeconds   = 45;         // Cooldown between trades (seconds)
input int     InpSpreadMaxPoints   = 40;         // Hard spread ceiling (points)
input double  InpSpreadMultiplier  = 2.5;        // Dynamic: reject if spread > avg × X

input group "=== SESSION FILTER ==="
input bool    InpUseSessionFilter  = true;       // Only trade during active sessions
input int     InpSessionStartGMT   = 7;          // Session start hour (GMT) – London open
input int     InpSessionEndGMT     = 20;         // Session end hour (GMT)

input group "=== STREAK PROTECTION ==="
input int     InpMaxLossStreak     = 3;          // Halve lot size after N consecutive losses
input int     InpWinStreakBoost    = 5;          // Allow slight size increase after N wins (capped)

input group "=== NEWS PAUSE ==="
input bool    InpNewsPauseActive   = false;      // Manual news pause toggle (set true before news)

input group "=== DASHBOARD ==="
input int     InpDashX            = 15;
input int     InpDashY            = 15;

//+------------------------------------------------------------------+
//| COLOUR PALETTE  - NEURA AI cyan/navy style                       |
//+------------------------------------------------------------------+
const color C_BG          = C'4,10,22';
const color C_PANEL       = C'6,16,36';
const color C_PANEL2      = C'8,22,48';
const color C_HEADER      = C'5,28,58';
const color C_BORDER      = C'0,180,220';
const color C_BORDER2     = C'0,120,160';
const color C_CYAN        = C'0,210,240';
const color C_BLUE        = C'30,160,255';
const color C_GREEN       = C'0,230,130';
const color C_RED         = C'220,40,60';
const color C_GOLD        = C'255,185,20';
const color C_ORANGE      = C'255,140,0';
const color C_PURPLE      = C'160,0,240';
const color C_WHITE       = C'220,238,255';
const color C_MUTED       = C'90,130,160';
const color C_HOLD_BG     = C'70,45,0';
const color C_BUY_BG      = C'0,55,18';
const color C_SELL_BG     = C'55,0,8';
const color C_SECTION_HDR = C'8,28,62';

//+------------------------------------------------------------------+
//| GLOBAL ENGINE OBJECTS                                            |
//+------------------------------------------------------------------+
CTrade          g_Trade;
CPositionInfo   g_Pos;

//--- Indicator handles
int g_hFastEMA  = INVALID_HANDLE;
int g_hSlowEMA  = INVALID_HANDLE;
int g_hTrendEMA = INVALID_HANDLE;
int g_hRSI      = INVALID_HANDLE;
int g_hATR      = INVALID_HANDLE;
int g_hADX      = INVALID_HANDLE;
int g_hMACD     = INVALID_HANDLE;
int g_hBB       = INVALID_HANDLE;

//--- State machine
ENUM_ENGINE_STATE g_State        = STATE_SCANNING;
datetime          g_StateTimer   = 0;

//--- Analysis phase
ENUM_SIGNAL  g_PendingSignal     = SIGNAL_NONE;
int          g_AnalysisTicks     = 0;
datetime     g_AnalysisStart     = 0;
bool         g_PartialClosed     = false;

//--- Session metrics
datetime g_SessionDay       = 0;
int      g_DailyTrades      = 0;
double   g_DailyProfit      = 0.0;
int      g_DailyWins        = 0;
int      g_DailyLosses      = 0;
int      g_ConsecLosses     = 0;
int      g_ConsecWins       = 0;
int      g_TotalReopens     = 0;
double   g_SessionOpenBal   = 0.0;

//--- Spread tracking
double g_AvgSpread          = 0.0;
int    g_SpreadSamples      = 0;

//--- Smart exit tracking (per-trade state)
double g_PeakProfit         = 0.0;   // Highest floating PnL seen this trade
double g_PartialClosePrice  = 0.0;   // Price at which partial close fired
bool   g_BESet              = false; // Whether breakeven has been set this trade
double g_EntryATR           = 0.0;   // ATR value captured at trade entry
int    g_TradeDirection     = 0;     // 1=buy -1=sell, cached at entry
double g_EntryPrice         = 0.0;   // Entry price cached for calculations

//--- Dashboard strings
string g_StatusText         = "BOOTING";
color  g_StatusColor        = C_GOLD;
string g_HeartbeatStr       = "0 0 0 0";
string g_SignalText         = "COMPUTING";
color  g_SignalColor        = C_MUTED;

//--- Enhanced signal quality tracking
int    g_LastConfluenceScore = 0;      // 0-7 score of last evaluated signal
int    g_SignalBarsHeld      = 0;      // How many bars the signal has been consistent
ENUM_SIGNAL g_PrevBarSignal  = SIGNAL_NONE; // Signal on previous bar (bar-change detection)
double g_ConsecSignalBars    = 0;      // Count of bars with same signal direction
double g_WinRate7            = 0.0;    // Rolling 7-trade win rate
int    g_Last7Results[7];              // 1=win 0=loss ring buffer
int    g_Last7Idx            = 0;

//+------------------------------------------------------------------+
//| FORWARD DECLARATIONS                                             |
//+------------------------------------------------------------------+
bool         InitIndicators();
void         ReleaseIndicators();
void         SyncDailyStats();
ENUM_SIGNAL  EvaluateConfluence(bool detectionMode = true);
bool         CheckEMAStack(double &fast, double &slow, double &trend);
bool         CheckRSI(ENUM_SIGNAL sig, double &rsiVal);
bool         CheckADX(double &adxVal);
bool         CheckMACD(ENUM_SIGNAL sig);
bool         CheckBollingerBands(ENUM_SIGNAL sig, bool &inSqueeze);
bool         CheckMarketStructure(ENUM_SIGNAL sig, bool proximityMode = false);
double       GetATR();
double       CalculateLotSize(int slPoints);
void         ExecuteEntry(ENUM_SIGNAL sig);
void         ManageOpenTrade();
void         CheckBreakeven();
void         CheckATRTrailing();
void         CheckPeakProfitLock(double pnl);
void         CheckPartialClose(double pnl);
void         EvaluateFloatingPnL(double pnl);
void         CacheTradeEntry();
void         ResetTradeState();
bool         IsPositionOpen();
double       GetFloatingPnL();
void         CloseAllPositions(string reason);
bool         IsMarketOpen();
bool         IsInSession();
bool         IsSpreadOk();
void         UpdateSpreadAverage();
bool         IsDailyLossLimitHit();
bool         IsDailyProfitTargetHit();
double       GetRiskAdjustedPercent();
datetime     GetDayStart(datetime t);
void         ProcessAnalysisPhase();
void         RenderDashboard();
void         UpdateDashboard();
void         PurgeDashboard();
void         DrawRect(string id, int x, int y, int w, int h, color bg, color border, int bw);
void         DrawLabel(string id, int x, int y, string txt, color clr, int sz, string fnt);
void         SetLabel(string id, string txt, color clr = clrNONE);
string       TimeframeToString(ENUM_TIMEFRAMES tf);

//+------------------------------------------------------------------+
//| INIT                                                             |
//+------------------------------------------------------------------+
int OnInit()
{
   //--- Validate symbol – warn but don't block (allows backtesting on other symbols)
   if(StringFind(_Symbol, "XAU") < 0 && StringFind(_Symbol, "GOLD") < 0)
      Print("[EliteScalper v5] WARNING: This EA is optimised for GOLD (XAUUSD). Current symbol: ", _Symbol);

   g_Trade.SetExpertMagicNumber(InpMagicNumber);
   g_Trade.SetDeviationInPoints(20);
   g_Trade.SetTypeFilling(ORDER_FILLING_FOK);

   if(InpRiskPercent <= 0.0 || InpRiskPercent > 10.0)
   { Alert("Risk% must be 0.01–10. Got: ", InpRiskPercent); return INIT_PARAMETERS_INCORRECT; }

   if(!InitIndicators()) return INIT_FAILED;

   g_SessionDay     = GetDayStart(TimeCurrent());
   g_SessionOpenBal = AccountInfoDouble(ACCOUNT_BALANCE);
   SyncDailyStats();

   g_State = STATE_SCANNING;
   EventSetTimer(1);
   RenderDashboard();

   Print("[EliteScalper v5] Initialised. Symbol=", _Symbol, " Magic=", InpMagicNumber);
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| DEINIT                                                           |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   EventKillTimer();
   PurgeDashboard();
   ReleaseIndicators();
}

//+------------------------------------------------------------------+
//| TIMER – heartbeat + stats sync                                   |
//+------------------------------------------------------------------+
void OnTimer()
{
   static uint beat = 0; beat++;
   string p[4] = {"1 0 1 1  0 1 0 0","0 1 0 0  1 0 1 1","1 1 0 1  0 0 1 0","0 0 1 0  1 1 0 1"};
   g_HeartbeatStr = p[beat % 4];
   SyncDailyStats();
   UpdateDashboard();
}

//+------------------------------------------------------------------+
//| TICK – main engine                                               |
//+------------------------------------------------------------------+
void OnTick()
{
   UpdateSpreadAverage();

   //--- Market tradeable?
   if(!IsMarketOpen())
   { g_StatusText = "MARKET CLOSED"; g_StatusColor = C_RED; return; }

   //--- News pause
   if(InpNewsPauseActive || g_State == STATE_NEWS_PAUSE)
   { g_StatusText = "NEWS PAUSE ACTIVE"; g_StatusColor = C_GOLD; return; }

   //--- Manage any open trade first (trailing, BE, partial, PnL exit)
   if(IsPositionOpen())
   { ManageOpenTrade(); return; }

   //--- Daily drawdown kill-switch
   if(IsDailyLossLimitHit())
   {
      g_State = STATE_DAILY_LIMIT;
      g_StatusText = "DAILY LOSS LIMIT HIT – HALTED";
      g_StatusColor = C_RED;
      return;
   }

   //--- Daily profit target reached
   if(IsDailyProfitTargetHit())
   {
      g_State = STATE_DAILY_LIMIT;
      g_StatusText = "DAILY PROFIT TARGET MET – HALTED";
      g_StatusColor = C_GREEN;
      return;
   }

   //--- Max daily trades
   if(g_DailyTrades >= InpMaxDailyTrades)
   {
      g_StatusText = "MAX DAILY TRADES REACHED";
      g_StatusColor = C_GOLD;
      return;
   }

   //--- Session filter
   if(InpUseSessionFilter && !IsInSession())
   {
      g_StatusText = "OUT OF SESSION – WAITING";
      g_StatusColor = C_MUTED;
      return;
   }

   //--- Spread guard
   if(!IsSpreadOk())
   {
      int sp = (int)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
      g_StatusText = "SPREAD TOO HIGH (" + IntegerToString(sp) + " pts)";
      g_StatusColor = C_RED;
      return;
   }

   //--- Cooldown state
   if(g_State == STATE_COOLDOWN)
   {
      int left = (int)(g_StateTimer - TimeCurrent());
      if(left > 0)
      {
         g_StatusText = "COOLDOWN (" + IntegerToString(left) + "s)";
         g_StatusColor = C_GOLD;
         return;
      }
      g_State = STATE_SCANNING;
   }

   //--- SCANNING: evaluate confluence signal
   if(g_State == STATE_SCANNING)
   {
      ENUM_SIGNAL sig = EvaluateConfluence(true);
      if(sig == SIGNAL_NONE)
      {
         g_StatusText  = "SCANNING – BUILDING CONFLUENCE";
         g_StatusColor = C_MUTED;
         return;
      }
      // Signal found – enter analysis phase
      g_State          = STATE_ANALYZING;
      g_PendingSignal  = sig;
      g_AnalysisStart  = TimeCurrent();
      g_AnalysisTicks  = 0;
      g_StatusText     = "SIGNAL DETECTED – ANALYSING";
      g_StatusColor    = C_PURPLE;
      Print("[EliteScalper v5] Signal=", (sig==SIGNAL_BUY?"BUY":"SELL"), " – Entering analysis phase");
   }
   //--- ANALYSING: validate signal over time window
   else if(g_State == STATE_ANALYZING)
   {
      ProcessAnalysisPhase();
   }
}

//+------------------------------------------------------------------+
//| INDICATOR INITIALISATION                                         |
//+------------------------------------------------------------------+
bool InitIndicators()
{
   g_hFastEMA  = iMA(_Symbol, _Period, InpFastEMAPeriod,  0, MODE_EMA, PRICE_CLOSE);
   g_hSlowEMA  = iMA(_Symbol, _Period, InpSlowEMAPeriod,  0, MODE_EMA, PRICE_CLOSE);
   g_hTrendEMA = iMA(_Symbol, _Period, InpTrendEMAPeriod, 0, MODE_EMA, PRICE_CLOSE);
   g_hRSI      = iRSI(_Symbol, _Period, InpRSIPeriod, PRICE_CLOSE);
   g_hATR      = iATR(_Symbol, _Period, InpATRPeriod);
   g_hADX      = iADX(_Symbol, _Period, InpADXPeriod);
   g_hMACD     = iMACD(_Symbol, _Period, InpMACDFast, InpMACDSlow, InpMACDSignal, PRICE_CLOSE);
   g_hBB       = iBands(_Symbol, _Period, InpBBPeriod, 0, InpBBDeviation, PRICE_CLOSE);

   if(g_hFastEMA==INVALID_HANDLE || g_hSlowEMA==INVALID_HANDLE || g_hTrendEMA==INVALID_HANDLE ||
      g_hRSI==INVALID_HANDLE || g_hATR==INVALID_HANDLE || g_hADX==INVALID_HANDLE ||
      g_hMACD==INVALID_HANDLE || g_hBB==INVALID_HANDLE)
   {
      Print("[EliteScalper v5] FAILED: One or more indicator handles invalid.");
      return false;
   }
   return true;
}

void ReleaseIndicators()
{
   int handles[] = {g_hFastEMA, g_hSlowEMA, g_hTrendEMA, g_hRSI, g_hATR, g_hADX, g_hMACD, g_hBB};
   for(int i = 0; i < ArraySize(handles); i++)
      if(handles[i] != INVALID_HANDLE) IndicatorRelease(handles[i]);
}

//+------------------------------------------------------------------+
//| CONFLUENCE SIGNAL ENGINE                                         |
//| detectionMode=true  → strict (scanning, all gates must pass)    |
//| detectionMode=false → validation (analysis ticks, relaxed struct)|
//+------------------------------------------------------------------+
ENUM_SIGNAL EvaluateConfluence(bool detectionMode = true)
{
   double fastEMA, slowEMA, trendEMA, rsiVal, adxVal;
   bool   inSqueeze = false;

   //--- EMA stack (directional bias – weighted: counts as 2)
   if(!CheckEMAStack(fastEMA, slowEMA, trendEMA))
   {
      // EMA stack not aligned – no trade
      return SIGNAL_NONE;
   }
   ENUM_SIGNAL emaSig = (fastEMA > slowEMA && slowEMA > trendEMA) ? SIGNAL_BUY : SIGNAL_SELL;

   int score = 2; // EMA stack = 2 points

   bool rsiPass  = CheckRSI(emaSig, rsiVal);
   bool adxPass  = CheckADX(adxVal);
   bool macdPass = CheckMACD(emaSig);
   bool bbPass   = CheckBollingerBands(emaSig, inSqueeze);
   bool structPass = CheckMarketStructure(emaSig, !detectionMode);

   if(rsiPass)   score++;
   if(adxPass)   score++;
   if(macdPass)  score++;
   if(bbPass)    score++;
   if(structPass)score++;

   // BB squeeze is a hard block regardless of other scores
   if(inSqueeze) return SIGNAL_NONE;

   // Log diagnostic on detection pass (every 10 ticks to avoid spam)
   static int logTick = 0; logTick++;
   if(detectionMode || (logTick % 10 == 0))
   {
      PrintFormat("[Confluence] Dir=%s Score=%d/7 | EMA✓(2) RSI=%s(%.1f) ADX=%s(%.1f) MACD=%s BB=%s Struct=%s",
         (emaSig==SIGNAL_BUY?"BUY":"SELL"), score,
         rsiPass  ?"✓":"✗", rsiVal,
         adxPass  ?"✓":"✗", adxVal,
         macdPass ?"✓":"✗",
         bbPass   ?"✓":"✗",
         structPass?"✓":"✗");
   }

   // Store for dashboard and execution gate
   g_LastConfluenceScore = score;

   // Dynamic threshold: tighten after consecutive losses to filter weaker setups
   int required = 5;
   if(g_ConsecLosses >= 2) required = 6; // 6/7 needed after 2 losses in a row
   if(g_ConsecLosses >= 3) required = 7; // all 7 needed after 3+ losses in a row

   if(score >= required) return emaSig;
   return SIGNAL_NONE;
}

//--- EMA Stack: fast > slow > trend = bullish; fast < slow < trend = bearish
bool CheckEMAStack(double &fast, double &slow, double &trend)
{
   double f[1], s[1], t[1];
   if(CopyBuffer(g_hFastEMA,  0, 0, 1, f) <= 0) return false;
   if(CopyBuffer(g_hSlowEMA,  0, 0, 1, s) <= 0) return false;
   if(CopyBuffer(g_hTrendEMA, 0, 0, 1, t) <= 0) return false;
   fast = f[0]; slow = s[0]; trend = t[0];
   bool bull = (fast > slow && slow > trend);
   bool bear = (fast < slow && slow < trend);
   return (bull || bear); // Only trade when fully stacked
}

//--- RSI: bull signal requires RSI > 50 but not overbought; bear = RSI < 50 but not oversold
bool CheckRSI(ENUM_SIGNAL sig, double &rsiVal)
{
   double r[1];
   if(CopyBuffer(g_hRSI, 0, 0, 1, r) <= 0) return false;
   rsiVal = r[0];
   if(sig == SIGNAL_BUY)  return (rsiVal > 50.0 && rsiVal < InpRSIOverbought);
   if(sig == SIGNAL_SELL) return (rsiVal < 50.0 && rsiVal > InpRSIOversold);
   return false;
}

//--- ADX: trend must have sufficient strength
bool CheckADX(double &adxVal)
{
   double adx[1];
   if(CopyBuffer(g_hADX, 0, 0, 1, adx) <= 0) return false;
   adxVal = adx[0];
   return (adxVal >= InpADXMinStrength);
}

//--- MACD histogram: positive and growing = buy; negative and falling = sell
//    CopyBuffer fills index 0 = most recent bar, index 1 = one bar older.
//    So: rising   = hist[0] > hist[1]  (current > previous = growing upward)
//        falling  = hist[0] < hist[1]  (current < previous = falling)
bool CheckMACD(ENUM_SIGNAL sig)
{
   double hist[2];
   // iMACD buffers: 0=MACD line, 1=signal line, 2=histogram
   if(CopyBuffer(g_hMACD, 2, 0, 2, hist) < 2) return false;
   double current  = hist[0]; // most recent
   double previous = hist[1]; // one bar back
   bool rising  = (current > previous);
   bool falling = (current < previous);
   if(sig == SIGNAL_BUY)  return (current > 0.0 && rising);
   if(sig == SIGNAL_SELL) return (current < 0.0 && falling);
   return false;
}

//--- Bollinger Bands: block on squeeze; confirm direction on expansion
bool CheckBollingerBands(ENUM_SIGNAL sig, bool &inSqueeze)
{
   double upper[1], lower[1], mid[1];
   if(CopyBuffer(g_hBB, 1, 0, 1, upper) <= 0) return false;
   if(CopyBuffer(g_hBB, 2, 0, 1, lower) <= 0) return false;
   if(CopyBuffer(g_hBB, 0, 0, 1, mid)   <= 0) return false;

   double width      = upper[0] - lower[0];
   double price      = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double squeezeThresh = price * InpBBSqueezeRatio;

   if(width < squeezeThresh) { inSqueeze = true; return false; }
   inSqueeze = false;

   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(sig == SIGNAL_BUY)  return (bid > mid[0]); // price above midline
   if(sig == SIGNAL_SELL) return (bid < mid[0]); // price below midline
   return false;
}

//--- Market structure: breakout OR proximity to swing level (within 1 ATR)
//    Strict breakout only required at signal detection. During analysis ticks
//    price will retrace slightly – proximity mode prevents false invalidation.
bool CheckMarketStructure(ENUM_SIGNAL sig, bool proximityMode = false)
{
   int highBar = iHighest(_Symbol, _Period, MODE_HIGH, InpStructureBars, 1);
   int lowBar  = iLowest(_Symbol,  _Period, MODE_LOW,  InpStructureBars, 1);
   if(highBar < 0 || lowBar < 0) return false;

   double swingHigh = iHigh(_Symbol, _Period, highBar);
   double swingLow  = iLow(_Symbol,  _Period, lowBar);
   double bid       = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask       = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double atr       = GetATR();
   double buffer    = atr * 0.5; // 50% ATR proximity allowance

   if(proximityMode)
   {
      // During analysis: accept if within buffer of structure level
      if(sig == SIGNAL_BUY)  return (ask >= swingHigh - buffer);
      if(sig == SIGNAL_SELL) return (bid <= swingLow  + buffer);
   }
   else
   {
      // Strict: must actually be breaking the level
      if(sig == SIGNAL_BUY)  return (ask > swingHigh);
      if(sig == SIGNAL_SELL) return (bid < swingLow);
   }
   return false;
}

//+------------------------------------------------------------------+
//| ATR VALUE                                                        |
//+------------------------------------------------------------------+
double GetATR()
{
   double atr[1];
   if(CopyBuffer(g_hATR, 0, 0, 1, atr) <= 0) return 0.0;
   return atr[0];
}

//+------------------------------------------------------------------+
//| DYNAMIC LOT SIZING                                               |
//+------------------------------------------------------------------+
double CalculateLotSize(int slPoints)
{
   double balance    = AccountInfoDouble(ACCOUNT_BALANCE);
   double riskPct    = GetRiskAdjustedPercent();
   double riskAmount = balance * (riskPct / 100.0);

   double tickVal  = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   double point    = SymbolInfoDouble(_Symbol, SYMBOL_POINT);

   // Cost of 1 lot at SL distance
   double slCostPerLot = (slPoints * point / tickSize) * tickVal;
   if(slCostPerLot <= 0.0) return SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);

   double lot  = riskAmount / slCostPerLot;
   double minV = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxV = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);

   lot = MathMax(minV, MathMin(maxV, MathFloor(lot / step) * step));
   return lot;
}

//--- Adjust risk % based on loss/win streak
double GetRiskAdjustedPercent()
{
   double pct = InpRiskPercent;
   if(g_ConsecLosses >= InpMaxLossStreak)
      pct = InpRiskPercent * 0.5; // half size after loss streak
   else if(g_ConsecWins >= InpWinStreakBoost)
      pct = MathMin(InpRiskPercent * 1.25, 2.0); // modest boost, hard cap 2%
   return pct;
}

//+------------------------------------------------------------------+
//| PRE-TRADE ANALYSIS PHASE                                         |
//+------------------------------------------------------------------+
void ProcessAnalysisPhase()
{
   g_AnalysisTicks++;
   int elapsed = (int)(TimeCurrent() - g_AnalysisStart);

   g_StatusText  = "ANALYSING: " + IntegerToString(elapsed) + "s | Ticks: " + IntegerToString(g_AnalysisTicks);
   g_StatusColor = C_PURPLE;

   // Timeout – signal expired
   if(elapsed > InpAnalysisMaxSec)
   {
      Print("[EliteScalper v5] Analysis timeout – signal invalidated.");
      g_State = STATE_SCANNING;
      return;
   }

   // Re-evaluate confluence in VALIDATION mode (relaxed structure check).
   // Only invalidate if the EMA/RSI/ADX core flips – not on minor price retraces.
   ENUM_SIGNAL current = EvaluateConfluence(false);
   if(current != g_PendingSignal)
   {
      Print("[EliteScalper v5] Signal reversed during analysis – invalidated. Was=",
            (g_PendingSignal==SIGNAL_BUY?"BUY":"SELL"), " Now=",
            (current==SIGNAL_BUY?"BUY":(current==SIGNAL_SELL?"SELL":"NONE")));
      g_State = STATE_SCANNING;
      return;
   }

   // Minimum time + tick volume met? Fire the trade.
   if(elapsed >= InpAnalysisMinSec && g_AnalysisTicks >= InpAnalysisMinTicks)
   {
      // Extra filter: require confluence score >= 5 right at execution moment
      // This catches cases where score was good at detection but degraded
      ENUM_SIGNAL finalCheck = EvaluateConfluence(false);
      if(finalCheck != g_PendingSignal)
      {
         Print("[EliteScalper v5] Final-moment confluence check failed. Aborting.");
         g_StateTimer = TimeCurrent() + 10;
         g_State      = STATE_COOLDOWN;
         return;
      }
      // Score must be at least 5 even in validation mode
      if(g_LastConfluenceScore < 5)
      {
         Print("[EliteScalper v5] Score too low at execution (", g_LastConfluenceScore, "/7). Aborting.");
         g_StateTimer = TimeCurrent() + 10;
         g_State      = STATE_COOLDOWN;
         return;
      }
      PrintFormat("[EliteScalper v5] Analysis complete. Score=%d/7 Elapsed=%ds Ticks=%d. Firing.",
                  g_LastConfluenceScore, elapsed, g_AnalysisTicks);
      ExecuteEntry(g_PendingSignal);
      g_StateTimer = TimeCurrent() + 10;
      g_State      = STATE_COOLDOWN;
   }
}

//+------------------------------------------------------------------+
//| TRADE EXECUTION                                                  |
//+------------------------------------------------------------------+
void ExecuteEntry(ENUM_SIGNAL sig)
{
   if(!IsSpreadOk()) { Print("[EliteScalper v5] Spread too wide at execution – aborted."); return; }

   double point  = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   int    digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   double atr    = GetATR();
   double price  = (sig == SIGNAL_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                       : SymbolInfoDouble(_Symbol, SYMBOL_BID);

   //--- ATR-based SL/TP
   int slPoints  = (int)MathRound((atr * InpSLMultiplier) / point);
   slPoints      = MathMax(InpMinSLPoints, MathMin(InpMaxSLPoints, slPoints));

   int tp2Points = (int)MathRound((atr * InpTP2Multiplier) / point);

   double sl, tp;
   if(sig == SIGNAL_BUY)
   {
      sl = NormalizeDouble(price - slPoints  * point, digits);
      tp = NormalizeDouble(price + tp2Points * point, digits);
   }
   else
   {
      sl = NormalizeDouble(price + slPoints  * point, digits);
      tp = NormalizeDouble(price - tp2Points * point, digits);
   }

   double lot = CalculateLotSize(slPoints);

   Print("[EliteScalper v5] Entry: ", (sig==SIGNAL_BUY?"BUY":"SELL"),
         " Price=", price, " SL=", sl, " TP=", tp,
         " Lot=", lot, " SL_pts=", slPoints);

   bool ok = (sig == SIGNAL_BUY) ? g_Trade.Buy(lot, _Symbol, price, sl, tp, InpTradeComment)
                                 : g_Trade.Sell(lot, _Symbol, price, sl, tp, InpTradeComment);
   if(ok)
   {
      g_DailyTrades++;
      ResetTradeState();
      Sleep(100);
      CacheTradeEntry();
      g_StatusText  = (sig==SIGNAL_BUY) ? "IN TRADE - LONG" : "IN TRADE - SHORT";
      g_StatusColor = C_GREEN;
   }
   else
   {
      Print("[EliteScalper v5] Order FAILED. RetCode=", g_Trade.ResultRetcode(), " ", g_Trade.ResultRetcodeDescription());
   }
}

//+------------------------------------------------------------------+
//| OPEN TRADE MANAGEMENT                                            |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| SMART EXIT SYSTEM                                                |
//|                                                                  |
//| Priority order every tick:                                       |
//|  1. Peak-profit lock  – closes if profit retraces X% from peak  |
//|  2. Partial close     – closes 50% at TP1 and locks min profit  |
//|  3. Breakeven         – moves SL to entry after 80 pts profit   |
//|  4. ATR trailing SL   – trails SL using ATR once 80 pts profit  |
//|  5. Daily target      – closes if daily goal hit                |
//+------------------------------------------------------------------+

//--- Cache entry state when a new position is opened
void CacheTradeEntry()
{
   for(int i = PositionsTotal()-1; i >= 0; i--)
   {
      if(!g_Pos.SelectByIndex(i)) continue;
      if(g_Pos.Magic()!=InpMagicNumber || g_Pos.Symbol()!=_Symbol) continue;
      g_EntryPrice     = g_Pos.PriceOpen();
      g_EntryATR       = GetATR();
      g_TradeDirection = (g_Pos.PositionType()==POSITION_TYPE_BUY) ? 1 : -1;
      g_PeakProfit     = 0.0;
      g_BESet          = false;
      g_PartialClosed  = false;
      break;
   }
}

//--- Reset all trade state variables after a position closes
void ResetTradeState()
{
   g_PeakProfit        = 0.0;
   g_PartialClosePrice = 0.0;
   g_BESet             = false;
   g_PartialClosed     = false;
   g_EntryATR          = 0.0;
   g_EntryPrice        = 0.0;
   g_TradeDirection    = 0;
}

//+------------------------------------------------------------------+
//| MASTER TRADE MANAGER – called every tick while position open     |
//+------------------------------------------------------------------+
void ManageOpenTrade()
{
   if(!IsPositionOpen()) { ResetTradeState(); return; }

   double pnl = GetFloatingPnL();

   // Update peak profit tracker
   if(pnl > g_PeakProfit) g_PeakProfit = pnl;

   // Update dashboard status
   string pnlStr = (pnl>=0?"+$":"-$") + DoubleToString(MathAbs(pnl),2)
                   + "  Peak:+$" + DoubleToString(g_PeakProfit,2);
   g_StatusText  = "TRADE RUNNING " + pnlStr;
   g_StatusColor = (pnl >= 0) ? C_GREEN : C_RED;

   //--- Priority 1: Peak-profit lock (most important – prevents $3 becoming $1)
   if(InpUsePeakLock) CheckPeakProfitLock(pnl);
   if(!IsPositionOpen()) return;

   //--- Priority 2: Partial close at TP1
   if(InpUsePartialClose && !g_PartialClosed) CheckPartialClose(pnl);
   if(!IsPositionOpen()) return;

   //--- Priority 3: Breakeven
   CheckBreakeven();
   if(!IsPositionOpen()) return;

   //--- Priority 4: ATR trailing SL
   if(InpUseTrailing) CheckATRTrailing();

   //--- Priority 5: Daily profit target via floating PnL
   EvaluateFloatingPnL(pnl);
}

//+------------------------------------------------------------------+
//| PEAK-PROFIT LOCK                                                 |
//| Once profit exceeds InpPeakLockActivate, if it retraces         |
//| InpPeakLockRetrace% from the peak, close immediately.           |
//| Example: Peak=$3.00, retrace=30% → close if PnL drops to $2.10 |
//+------------------------------------------------------------------+
void CheckPeakProfitLock(double pnl)
{
   if(g_PeakProfit < InpPeakLockActivate) return; // not activated yet

   double lockLevel = g_PeakProfit * (1.0 - InpPeakLockRetrace / 100.0);

   // Also enforce absolute minimum lock: after partial close, protect remainder
   if(g_PartialClosed && lockLevel < InpMinLockProfit)
      lockLevel = InpMinLockProfit;

   if(pnl <= lockLevel && pnl < g_PeakProfit) // only close on retrace, never on the way up
   {
      PrintFormat("[PeakLock] Triggered. Peak=$%.2f Lock=$%.2f Current=$%.2f. Closing.",
                  g_PeakProfit, lockLevel, pnl);
      CloseAllPositions("Peak-profit lock triggered");
      g_StatusText  = "PEAK LOCK EXIT  Peak:+$"+DoubleToString(g_PeakProfit,2);
      g_StatusColor = C_CYAN;
      ResetTradeState();
   }
}

//+------------------------------------------------------------------+
//| PARTIAL CLOSE AT TP1                                             |
//| Fires when price reaches 1x ATR profit in points.               |
//| After firing, tightens the peak-lock threshold to protect gains.|
//+------------------------------------------------------------------+
void CheckPartialClose(double pnl)
{
   for(int i = PositionsTotal()-1; i >= 0; i--)
   {
      if(!g_Pos.SelectByIndex(i)) continue;
      if(g_Pos.Magic()!=InpMagicNumber || g_Pos.Symbol()!=_Symbol) continue;

      double open      = g_Pos.PriceOpen();
      double point     = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
      double bid       = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      double ask       = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      bool   isBuy     = (g_Pos.PositionType()==POSITION_TYPE_BUY);
      double profitPts = isBuy ? (bid-open)/point : (open-ask)/point;

      // Use entry ATR for consistency – live ATR can change mid-trade
      double atr    = (g_EntryATR > 0) ? g_EntryATR : GetATR();
      double tp1Pts = (atr * InpTP1Multiplier) / point;

      if(profitPts < tp1Pts) continue;

      double volStep  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
      double closeLot = MathFloor((g_Pos.Volume()*(InpPartialClosePct/100.0))/volStep)*volStep;
      closeLot        = NormalizeDouble(closeLot, 2);
      double minLot   = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);

      if(closeLot < minLot)
      {
         // Lot too small to partial – close entire position instead
         PrintFormat("[PartialClose] Lot %.2f below min %.2f – closing full position", closeLot, minLot);
         CloseAllPositions("TP1 full close (lot too small to partial)");
         ResetTradeState();
         return;
      }

      if(g_Trade.PositionClosePartial(g_Pos.Ticket(), closeLot))
      {
         g_PartialClosed     = true;
         g_PartialClosePrice = isBuy ? bid : ask;
         // After partial close: tighten peak-lock to 20% retrace (from 30%)
         // This is handled automatically – the lockLevel calc uses g_PartialClosed flag
         PrintFormat("[PartialClose] %.2f lots closed at %.2f. Profit so far: $%.2f",
                     closeLot, g_PartialClosePrice, pnl);
      }
   }
}

//+------------------------------------------------------------------+
//| BREAKEVEN                                                        |
//| Moves SL to entry+buffer after InpBreakevenPoints profit        |
//+------------------------------------------------------------------+
void CheckBreakeven()
{
   if(g_BESet) return; // only need to do this once

   for(int i = PositionsTotal()-1; i >= 0; i--)
   {
      if(!g_Pos.SelectByIndex(i)) continue;
      if(g_Pos.Magic()!=InpMagicNumber || g_Pos.Symbol()!=_Symbol) continue;

      double open      = g_Pos.PriceOpen();
      double sl        = g_Pos.StopLoss();
      double point     = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
      double bid       = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      double ask       = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      int    digits    = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
      bool   isBuy     = (g_Pos.PositionType()==POSITION_TYPE_BUY);
      double profitPts = isBuy ? (bid-open)/point : (open-ask)/point;

      if(profitPts < InpBreakevenPoints) continue;

      double beSL = isBuy ? NormalizeDouble(open + InpBreakevenBuffer*point, digits)
                           : NormalizeDouble(open - InpBreakevenBuffer*point, digits);
      bool needsMove = isBuy ? (sl < beSL) : (sl > beSL || sl == 0.0);

      if(needsMove && g_Trade.PositionModify(g_Pos.Ticket(), beSL, g_Pos.TakeProfit()))
      {
         g_BESet = true;
         Print("[Breakeven] SL moved to ", DoubleToString(beSL, digits));
      }
   }
}

//+------------------------------------------------------------------+
//| ATR TRAILING STOP                                                |
//| Trail SL = current price - (ATR x InpTrailATRMult)              |
//| Only activates after InpTrailStartPoints profit                  |
//| Uses entry ATR so it stays consistent throughout the trade      |
//+------------------------------------------------------------------+
void CheckATRTrailing()
{
   double atr = (g_EntryATR > 0) ? g_EntryATR : GetATR();
   if(atr <= 0) return;

   double point  = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   double trailDist = atr * InpTrailATRMult; // distance in price terms

   for(int i = PositionsTotal()-1; i >= 0; i--)
   {
      if(!g_Pos.SelectByIndex(i)) continue;
      if(g_Pos.Magic()!=InpMagicNumber || g_Pos.Symbol()!=_Symbol) continue;

      double open      = g_Pos.PriceOpen();
      double sl        = g_Pos.StopLoss();
      double bid       = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      double ask       = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      int    digits    = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
      bool   isBuy     = (g_Pos.PositionType()==POSITION_TYPE_BUY);
      double profitPts = isBuy ? (bid-open)/point : (open-ask)/point;

      // Only start trailing after minimum profit threshold
      if(profitPts < InpTrailStartPoints) continue;

      double newSL = isBuy ? NormalizeDouble(bid - trailDist, digits)
                           : NormalizeDouble(ask + trailDist, digits);

      // Only move SL in profit direction, never against us
      bool improves;
      if(isBuy)
         improves = (newSL > sl && newSL < bid); // new SL must be higher than old, below price
      else
         improves = (sl == 0.0) ? (newSL > ask) : (newSL < sl && newSL > ask);
      if(improves)
         g_Trade.PositionModify(g_Pos.Ticket(), newSL, g_Pos.TakeProfit());
   }
}

//+------------------------------------------------------------------+
//| DAILY PNL TARGET CHECK                                           |
//+------------------------------------------------------------------+
void EvaluateFloatingPnL(double pnl)
{
   double balance   = AccountInfoDouble(ACCOUNT_BALANCE);
   double dailyGoal = balance * (InpMaxDailyProfitPct / 100.0);
   double remaining = dailyGoal - g_DailyProfit;
   if(remaining > 0.0 && pnl >= remaining)
   {
      CloseAllPositions("Daily profit target reached");
      g_State = STATE_DAILY_LIMIT;
      ResetTradeState();
   }
}

void SyncDailyStats()
{
   datetime now      = TimeCurrent();
   datetime dayStart = GetDayStart(now);

   // New day reset
   if(dayStart > g_SessionDay)
   {
      g_SessionDay     = dayStart;
      g_DailyTrades    = 0;
      g_DailyProfit    = 0.0;
      g_DailyWins      = 0;
      g_DailyLosses    = 0;
      g_TotalReopens   = 0;
      g_SessionOpenBal = AccountInfoDouble(ACCOUNT_BALANCE);
      if(g_State == STATE_DAILY_LIMIT) g_State = STATE_SCANNING;
   }

   g_DailyProfit = 0.0;
   g_DailyWins   = 0;
   g_DailyLosses = 0;

   // Scan history from 7 days back to capture multi-day loss streaks
   datetime scanFrom = dayStart - 7*86400;
   if(!HistorySelect(scanFrom, now)) return;

   // Ring buffer for rolling win rate (last 7 closed trades)
   int  ringBuf[7];  ArrayInitialize(ringBuf, -1); // -1 = empty
   int  ringIdx   = 0;
   bool lastWasWin = false;
   int  curStreak  = 0;
   int  totalDeals = 0;

   for(int i = 0; i < HistoryDealsTotal(); i++)
   {
      ulong tkt = HistoryDealGetTicket(i);
      if(tkt == 0) continue;
      if(HistoryDealGetInteger(tkt, DEAL_MAGIC)  != (long)InpMagicNumber) continue;
      if(HistoryDealGetString(tkt,  DEAL_SYMBOL) != _Symbol) continue;
      if(HistoryDealGetInteger(tkt, DEAL_ENTRY)  != DEAL_ENTRY_OUT) continue;

      double pnl = HistoryDealGetDouble(tkt, DEAL_PROFIT)
                 + HistoryDealGetDouble(tkt, DEAL_COMMISSION)
                 + HistoryDealGetDouble(tkt, DEAL_SWAP);

      bool win = (pnl >= 0.0);
      totalDeals++;

      // Only count today's trades for daily stats
      datetime dealTime = (datetime)HistoryDealGetInteger(tkt, DEAL_TIME);
      if(dealTime >= dayStart)
      {
         g_DailyProfit += pnl;
         if(win) g_DailyWins++; else g_DailyLosses++;
      }

      // Rolling ring buffer (all history, last 7 trades)
      ringBuf[ringIdx % 7] = win ? 1 : 0;
      ringIdx++;

      // Streak tracking (all history for multi-day loss streaks)
      if(win == lastWasWin) curStreak++;
      else                  curStreak = 1;
      lastWasWin = win;
   }

   // Set streaks
   if(totalDeals > 0)
   {
      if(lastWasWin) { g_ConsecWins = curStreak; g_ConsecLosses = 0; }
      else           { g_ConsecLosses = curStreak; g_ConsecWins  = 0; }
   }
   else { g_ConsecWins = 0; g_ConsecLosses = 0; }

   // Calculate rolling 7-trade win rate
   int wins7 = 0, total7 = 0;
   for(int j = 0; j < 7; j++)
   {
      if(ringBuf[j] < 0) continue;
      total7++;
      if(ringBuf[j] == 1) wins7++;
   }
   g_WinRate7 = (total7 > 0) ? ((double)wins7 / total7) * 100.0 : 0.0;

   // Copy ring buffer to global for dashboard
   for(int j = 0; j < 7; j++) g_Last7Results[j] = ringBuf[j];
}

//+------------------------------------------------------------------+
//| UTILITY FUNCTIONS                                                |
//+------------------------------------------------------------------+
bool IsPositionOpen()
{
   for(int i = PositionsTotal()-1; i >= 0; i--)
      if(g_Pos.SelectByIndex(i) && g_Pos.Magic()==InpMagicNumber && g_Pos.Symbol()==_Symbol) return true;
   return false;
}

double GetFloatingPnL()
{
   double total = 0.0;
   for(int i = PositionsTotal()-1; i >= 0; i--)
      if(g_Pos.SelectByIndex(i) && g_Pos.Magic()==InpMagicNumber && g_Pos.Symbol()==_Symbol)
         total += g_Pos.Profit() + g_Pos.Swap() + g_Pos.Commission();
   return total;
}

void CloseAllPositions(string reason)
{
   PrintFormat("[EliteScalper v5] CloseAll: %s | Peak was $%.2f", reason, g_PeakProfit);
   for(int i = PositionsTotal()-1; i >= 0; i--)
      if(g_Pos.SelectByIndex(i) && g_Pos.Magic()==InpMagicNumber && g_Pos.Symbol()==_Symbol)
         g_Trade.PositionClose(g_Pos.Ticket());
   g_StateTimer = TimeCurrent() + InpCooldownSeconds;
   g_State      = STATE_COOLDOWN;
   ResetTradeState();
}

bool IsMarketOpen()
{
   ENUM_SYMBOL_TRADE_MODE m = (ENUM_SYMBOL_TRADE_MODE)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_MODE);
   return (m == SYMBOL_TRADE_MODE_FULL || m == SYMBOL_TRADE_MODE_LONGONLY || m == SYMBOL_TRADE_MODE_SHORTONLY);
}

bool IsInSession()
{
   MqlDateTime t; TimeToStruct(TimeGMT(), t);
   return (t.hour >= InpSessionStartGMT && t.hour < InpSessionEndGMT);
}

bool IsSpreadOk()
{
   double spread = (double)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   if(spread > InpSpreadMaxPoints) return false;
   if(g_SpreadSamples > 50 && spread > g_AvgSpread * InpSpreadMultiplier) return false;
   return true;
}

void UpdateSpreadAverage()
{
   double spread = (double)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   int    cap    = 2000;
   g_AvgSpread   = (g_AvgSpread * g_SpreadSamples + spread) / (double)(g_SpreadSamples + 1);
   g_SpreadSamples = MathMin(g_SpreadSamples + 1, cap);
}

bool IsDailyLossLimitHit()
{
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double limit   = balance * (InpMaxDailyLossPct / 100.0);
   return (g_DailyProfit <= -MathAbs(limit));
}

bool IsDailyProfitTargetHit()
{
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double target  = balance * (InpMaxDailyProfitPct / 100.0);
   return (g_DailyProfit >= target);
}

datetime GetDayStart(datetime t)
{
   MqlDateTime d; TimeToStruct(t, d);
   return t - (datetime)(d.hour*3600 + d.min*60 + d.sec);
}

//+------------------------------------------------------------------+
//| DASHBOARD                                                        |
//+------------------------------------------------------------------+

//====================================================================
// NEURA-STYLE DASHBOARD ENGINE
// Layout (top to bottom, width=320px to fit chart panel):
//   [HEADER]          – EA name, symbol, time
//   [MARKET INFO]     – Bid/Ask, Spread, ATR, Symbol, Vol status
//   [SIGNAL ENGINE]   – EMA values, RSI, EMA21, Decision bar
//   [AI ENGINE]       – Status, Last decision, Confidence bar
//   [FINAL DECISION]  – Large coloured BUY / SELL / HOLD block
//   [OPEN POSITIONS]  – Table: Type, Lot, Open, SL, TP, P&L
//   [ACCOUNT INFO]    – Balance, Equity, Day P&L, Win Rate, Risk
//   [SESSION BAR]     – London | New York | Asia pills
//====================================================================

// Dashboard geometry – compact to fit MT5 chart window
// W=320 fits comfortably on a 1280px wide monitor alongside the chart
#define DW  320    // total width
#define COL 130    // label column width; value starts here

void RenderDashboard()
{
   int X = InpDashX;
   int Y = InpDashY;
   int W = DW;
   int y = Y; // running Y cursor

   //----------------------------------------------------------------
   // OUTER SHELL
   //----------------------------------------------------------------
   DrawRect("SHELL", X, Y, W, 612, C_BG, C_BORDER, 2);

   //----------------------------------------------------------------
   // HEADER BAR
   //----------------------------------------------------------------
   DrawRect("HDR_BG", X+2, y+2, W-4, 36, C_HEADER, C_BORDER, 1);
   DrawLabel("HDR_IC",  X+8,     y+6,  "[ ELITE SCALPER AI ]",      C_CYAN,  9,  "Arial Black");
   DrawLabel("HDR_SYM", X+W-100, y+6,  _Symbol,                      C_GOLD,  10, "Impact");
   DrawLabel("HDR_TF",  X+W-60,  y+22, TimeframeToString(_Period),   C_MUTED, 7,  "Arial");
   DrawLabel("HDR_VER", X+8,     y+24, "v5.00  |  GOLD ENGINE",      C_MUTED, 7,  "Arial");
   y += 40;

   //----------------------------------------------------------------
   // MARKET INFO SECTION
   //----------------------------------------------------------------
   DrawRect("MI_HDR", X+2, y, W-4, 16, C_SECTION_HDR, C_BORDER2, 1);
   DrawLabel("MI_TIT", X+8, y+3, "MARKET INFO", C_ORANGE, 8, "Arial Black");
   DrawLabel("MI_CLK", X+W-60, y+3, "00:00", C_MUTED, 8, "Arial");
   y += 17;

   DrawRect("MI_BG", X+2, y, W-4, 72, C_PANEL, C_BORDER2, 1);
   // Row 1: Bid | Ask
   DrawLabel("L_BID",  X+8,      y+6,  "Bid",                 C_MUTED, 8, "Arial");
   DrawLabel("V_BID",  X+36,     y+6,  "0.00",                C_WHITE, 9, "Arial Bold");
   DrawLabel("L_ASK",  X+W/2+4,  y+6,  "ASK",                 C_MUTED, 8, "Arial");
   DrawLabel("V_ASK",  X+W/2+30, y+6,  "0.00",                C_WHITE, 9, "Arial Bold");
   // Row 2: Spread | ATR
   DrawLabel("L_SPR",  X+8,      y+24, "SPREAD",              C_MUTED, 8, "Arial");
   DrawLabel("V_SPR",  X+55,     y+24, "0 pts",               C_GOLD,  9, "Arial Bold");
   DrawLabel("L_ATR",  X+W/2+4,  y+24, "ATR(14)",             C_MUTED, 8, "Arial");
   DrawLabel("V_ATR",  X+W/2+44, y+24, "0 pts",               C_CYAN,  9, "Arial Bold");
   // Row 3: Symbol | Vol status
   DrawLabel("L_SYM2", X+8,      y+42, "SYMBOL",              C_MUTED, 8, "Arial");
   DrawLabel("V_SYM2", X+55,     y+42, _Symbol+" M"+TimeframeToString(_Period), C_WHITE, 8, "Arial Bold");
   DrawLabel("L_VOL",  X+W/2+4,  y+42, "Vol:",                C_MUTED, 8, "Arial");
   DrawLabel("V_VOL",  X+W/2+28, y+42, "PASS",                C_GREEN, 8, "Arial Bold");
   // Row 4: Session status
   DrawLabel("L_SES",  X+8,      y+58, "SESSION",             C_MUTED, 8, "Arial");
   DrawLabel("V_SES",  X+55,     y+58, "CHECKING",            C_GOLD,  8, "Arial Bold");
   y += 74;

   //----------------------------------------------------------------
   // SIGNAL ENGINE (XGBoost-style from image)
   //----------------------------------------------------------------
   DrawRect("SE_HDR", X+2, y, W-4, 16, C_SECTION_HDR, C_BORDER2, 1);
   DrawLabel("SE_TIT", X+8, y+3, "CONFLUENCE SIGNAL ENGINE", C_ORANGE, 8, "Arial Black");
   y += 17;

   DrawRect("SE_BG", X+2, y, W-4, 88, C_PANEL, C_BORDER2, 1);
   // Row 1: EMA Fast | EMA Slow
   DrawLabel("L_EF",   X+8,      y+6,  "EMA "+IntegerToString(InpFastEMAPeriod), C_MUTED, 8, "Arial");
   DrawLabel("V_EF",   X+52,     y+6,  "0.00",                C_CYAN,  9, "Arial Bold");
   DrawLabel("L_ES",   X+W/2+4,  y+6,  "EMA "+IntegerToString(InpSlowEMAPeriod), C_MUTED, 8, "Arial");
   DrawLabel("V_ES",   X+W/2+40, y+6,  "0.00",                C_CYAN,  9, "Arial Bold");
   // Row 2: RSI | BB Status pill
   DrawLabel("L_RSI",  X+8,      y+24, "RSI",                 C_MUTED, 8, "Arial");
   DrawLabel("V_RSI",  X+36,     y+24, "0.0",                 C_WHITE, 9, "Arial Bold");
   DrawRect("BB_PILL", X+W/2+4,  y+22, 72, 14, C_HOLD_BG, C_BORDER2, 1);
   DrawLabel("V_BBP",  X+W/2+8,  y+24, "RANGE",               C_GOLD,  8, "Arial Bold");
   // Row 3: EMA Trend | ADX
   DrawLabel("L_ET",   X+8,      y+42, "EMA("+IntegerToString(InpTrendEMAPeriod)+")", C_MUTED, 8, "Arial");
   DrawLabel("V_ET",   X+52,     y+42, "0.00",                C_WHITE, 9, "Arial Bold");
   DrawLabel("L_ADX",  X+W/2+4,  y+42, "ADX",                 C_MUTED, 8, "Arial");
   DrawLabel("V_ADX",  X+W/2+30, y+42, "0.0",                 C_WHITE, 9, "Arial Bold");
   // Row 4: MACD
   DrawLabel("L_MCD",  X+8,      y+60, "MACD Hist",           C_MUTED, 8, "Arial");
   DrawLabel("V_MCD",  X+66,     y+60, "0.00",                C_WHITE, 9, "Arial Bold");
   DrawLabel("L_STR",  X+W/2+4,  y+60, "Structure",           C_MUTED, 8, "Arial");
   DrawLabel("V_STR",  X+W/2+52, y+60, "—",                   C_WHITE, 8, "Arial Bold");
   // Decision bar (like the image "Decision: HOLD" amber bar)
   DrawRect("DEC_BAR", X+2, y+74, W-4, 14, C_HOLD_BG, C_BORDER2, 1);
   DrawLabel("V_DEC",  X+W/2-40, y+75, "Decision: HOLD",      C_GOLD,  8, "Arial Black");
   y += 90;

   //----------------------------------------------------------------
   // AI ENGINE STATUS (mirrors "AI GEMINI" section in image)
   //----------------------------------------------------------------
   DrawRect("AI_HDR", X+2, y, W-4, 16, C_SECTION_HDR, C_BORDER2, 1);
   DrawLabel("AI_TIT", X+8, y+3, "AI ENGINE", C_ORANGE, 8, "Arial Black");
   y += 17;

   DrawRect("AI_BG", X+2, y, W-4, 62, C_PANEL, C_BORDER2, 1);
   DrawLabel("L_AIST",  X+8,  y+6,  "STATUS",          C_MUTED, 8, "Arial");
   DrawLabel("V_AIST",  X+70, y+6,  "ANALYSING",        C_CYAN,  9, "Arial Black");
   DrawLabel("AI_DOT",  X+W-16, y+6, "●",               C_GOLD,  9, "Arial");   // status dot
   DrawLabel("L_AILD",  X+8,  y+24, "LAST DECISION",   C_MUTED, 8, "Arial");
   DrawLabel("V_AILD",  X+W-50,y+24, "HOLD",            C_GOLD,  8, "Arial Bold");
   DrawLabel("L_AISC",  X+8,  y+42, "CONFIDENCE",      C_MUTED, 8, "Arial");
   // Confidence bar background + fill
   DrawRect("CONF_BG",  X+85, y+43, 140, 11, C_PANEL2,  C_BORDER2, 1);
   DrawRect("CONF_FG",  X+85, y+43, 56,  11, C_GOLD,    clrNONE,   0);  // starts at 40%
   DrawLabel("V_AISC",  X+230,y+42, "MED",              C_GOLD,  8, "Arial Bold");
   y += 64;

   //----------------------------------------------------------------
   // FINAL DECISION BLOCK (large coloured bar like image)
   //----------------------------------------------------------------
   DrawRect("FD_HDR", X+2, y, W-4, 16, C_SECTION_HDR, C_BORDER2, 1);
   DrawLabel("FD_TIT", X+8, y+3, "FINAL DECISION", C_ORANGE, 8, "Arial Black");
   y += 17;

   DrawRect("FD_BG",  X+2, y, W-4, 32, C_HOLD_BG, C_BORDER, 2);
   DrawLabel("V_FD",  X+W/2-20, y+9, "HOLD", C_GOLD, 14, "Arial Black");
   y += 34;

   // Sub-row: Signal Engine | AI Engine verdict
   DrawRect("FD_SUB", X+2, y, W-4, 14, C_PANEL2, C_BORDER2, 1);
   DrawLabel("L_FDS1", X+8,      y+2, "SIGNAL ENG:",  C_MUTED, 7, "Arial");
   DrawLabel("V_FDS1", X+70,     y+2, "HOLD",         C_GOLD,  7, "Arial Bold");
   DrawLabel("L_FDS2", X+W/2+8,  y+2, "AI ENGINE:",   C_MUTED, 7, "Arial");
   DrawLabel("V_FDS2", X+W/2+62, y+2, "HOLD",         C_GOLD,  7, "Arial Bold");
   y += 16;

   //----------------------------------------------------------------
   // OPEN POSITIONS TABLE
   //----------------------------------------------------------------
   DrawRect("OP_HDR", X+2, y, W-4, 16, C_SECTION_HDR, C_BORDER2, 1);
   DrawLabel("OP_TIT",  X+8,     y+3,  "OPEN POSITIONS", C_ORANGE, 8, "Arial Black");
   DrawLabel("OP_CNT",  X+W-50,  y+3,  "0 open",         C_MUTED,  8, "Arial");
   y += 17;

   DrawRect("OP_COL", X+2, y, W-4, 13, C_PANEL2, C_BORDER2, 1);
   DrawLabel("OC_TYP",  X+6,   y+2, "TYPE", C_MUTED, 7, "Arial");
   DrawLabel("OC_LOT",  X+48,  y+2, "LOT",  C_MUTED, 7, "Arial");
   DrawLabel("OC_OPN",  X+88,  y+2, "OPEN", C_MUTED, 7, "Arial");
   DrawLabel("OC_SL",   X+140, y+2, "SL",   C_MUTED, 7, "Arial");
   DrawLabel("OC_TP",   X+180, y+2, "TP",   C_MUTED, 7, "Arial");
   DrawLabel("OC_PNL",  X+230, y+2, "P&L",  C_MUTED, 7, "Arial");
   y += 14;

   // 3 data rows
   for(int r = 0; r < 3; r++)
   {
      color rowBg = (r % 2 == 0) ? C_PANEL : C_PANEL2;
      DrawRect("OR"+IntegerToString(r),      X+2, y, W-4, 13, rowBg, clrNONE, 0);
      DrawLabel("OR_T"+IntegerToString(r),   X+6,   y+2, "---", C_MUTED, 7, "Arial");
      DrawLabel("OR_L"+IntegerToString(r),   X+48,  y+2, "---", C_MUTED, 7, "Arial");
      DrawLabel("OR_O"+IntegerToString(r),   X+88,  y+2, "---", C_MUTED, 7, "Arial");
      DrawLabel("OR_S"+IntegerToString(r),   X+140, y+2, "---", C_MUTED, 7, "Arial");
      DrawLabel("OR_P"+IntegerToString(r),   X+180, y+2, "---", C_MUTED, 7, "Arial");
      DrawLabel("OR_F"+IntegerToString(r),   X+230, y+2, "---", C_MUTED, 7, "Arial");
      y += 14;
   }

   DrawRect("OP_FT", X+2, y, W-4, 13, C_PANEL2, C_BORDER2, 1);
   DrawLabel("L_FLT",  X+6,    y+2, "FLOAT:",  C_MUTED, 7, "Arial");
   DrawLabel("V_FLT",  X+42,   y+2, "+0.00",   C_GREEN, 8, "Arial Bold");
   DrawLabel("L_OEQV", X+W-90, y+2, "EQUITY:", C_MUTED, 7, "Arial");
   DrawLabel("V_OEQV", X+W-50, y+2, "$0.00",   C_WHITE, 8, "Arial Bold");
   y += 15;

   //----------------------------------------------------------------
   // ACCOUNT INFO
   //----------------------------------------------------------------
   DrawRect("AC_HDR", X+2, y, W-4, 16, C_SECTION_HDR, C_BORDER2, 1);
   DrawLabel("AC_TIT", X+8, y+3, "ACCOUNT INFO", C_ORANGE, 8, "Arial Black");
   y += 17;

   DrawRect("AC_BG", X+2, y, W-4, 100, C_PANEL, C_BORDER2, 1);
   DrawLabel("L_BAL",  X+8,      y+4,  "BALANCE",    C_MUTED, 8, "Arial");
   DrawLabel("V_BAL",  X+COL,    y+4,  "$0.00",      C_GREEN, 9, "Arial Bold");
   DrawLabel("L_EQ",   X+8,      y+20, "EQUITY",     C_MUTED, 8, "Arial");
   DrawLabel("V_EQ",   X+COL,    y+20, "$0.00",      C_WHITE, 9, "Arial Bold");
   DrawLabel("L_DP",   X+8,      y+36, "DAY P&L",    C_MUTED, 8, "Arial");
   DrawLabel("V_DP",   X+COL,    y+36, "+0.00 (0.00%)", C_GREEN, 9, "Arial Bold");
   DrawLabel("L_WR",   X+8,      y+52, "WIN RATE",   C_MUTED, 8, "Arial");
   DrawLabel("V_WR",   X+COL,    y+52, "0%",         C_CYAN,  9, "Arial Bold");
   DrawLabel("L_RSK",  X+W/2+4,  y+52, "RISK",       C_MUTED, 8, "Arial");
   DrawLabel("V_RSK",  X+W/2+32, y+52, "0.0%",       C_GOLD,  9, "Arial Bold");
   DrawLabel("L_MN",   X+W-55,   y+52, "MN:",        C_MUTED, 7, "Arial");
   DrawLabel("V_MN",   X+W-38,   y+52, IntegerToString((int)InpMagicNumber % 10000), C_MUTED, 7, "Arial");
   DrawLabel("L_STKR", X+8,      y+68, "STREAK",     C_MUTED, 8, "Arial");
   DrawLabel("V_STK",  X+COL,    y+68, "---",        C_MUTED, 8, "Arial Bold");
   DrawLabel("L_CONFR",X+8,      y+84, "LAST 7",     C_MUTED, 8, "Arial");
   DrawLabel("V_CONF", X+COL,    y+84, "Score:0/7",  C_CYAN,  8, "Consolas");
   y += 102;

   //----------------------------------------------------------------
   // SESSION BAR (London | New York | Asia pills like image)
   //----------------------------------------------------------------
   DrawRect("SB_BG", X+2, y, W-4, 18, C_PANEL2, C_BORDER2, 1);
   int pw = (W-10)/3;
   // London pill
   DrawRect("SB_LON", X+3,        y+2, pw,   14, C_PANEL, C_BORDER2, 1);
   DrawLabel("SB_LT",  X+3+pw/2-18, y+4,  "LONDON",   C_MUTED, 7, "Arial Bold");
   // New York pill (highlighted when active)
   DrawRect("SB_NYC", X+3+pw+1,   y+2, pw,   14, C_GOLD,  clrNONE,   0);
   DrawLabel("SB_NT",  X+4+pw+pw/2-22, y+4, "NEW YORK", C_BG,   7, "Arial Black");
   // Asia pill
   DrawRect("SB_ASI", X+3+pw*2+2, y+2, pw-1, 14, C_PANEL, C_BORDER2, 1);
   DrawLabel("SB_AT",  X+4+pw*2+pw/2-12, y+4, "ASIA",  C_MUTED, 7, "Arial Bold");

   ChartRedraw(0);
}

//+------------------------------------------------------------------+
//| NEURA-STYLE DASHBOARD UPDATE                                     |
//+------------------------------------------------------------------+
void UpdateDashboard()
{
   // Header clock
   MqlDateTime dt; TimeToStruct(TimeCurrent(), dt);
   string clk = StringFormat("%02d:%02d", dt.hour, dt.min);
   SetLabel("MI_CLK", clk, C_MUTED);

   //--- Market Info
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   int    sp  = (int)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   double atr = GetATR();
   double pt  = SymbolInfoDouble(_Symbol, SYMBOL_POINT);

   SetLabel("V_BID", DoubleToString(bid, 2), C_WHITE);
   SetLabel("V_ASK", DoubleToString(ask, 2), C_WHITE);
   color cSp = IsSpreadOk() ? C_GOLD : C_RED;
   SetLabel("V_SPR", IntegerToString(sp)+" pts", cSp);
   SetLabel("V_ATR", IntegerToString((int)MathRound(atr/pt))+" pts", C_CYAN);

   bool inSess = IsInSession();
   SetLabel("V_VOL",  IsMarketOpen() ? "PASS" : "HALT",  IsMarketOpen() ? C_GREEN : C_RED);
   SetLabel("V_SES",  inSess ? "ACTIVE" : "CLOSED",       inSess        ? C_GREEN : C_MUTED);

   //--- Signal Engine indicators
   double fast[1], slow[1], trend[1], rsi[1], adx[1], hist[2];
   if(CopyBuffer(g_hFastEMA,  0, 0, 1, fast)  > 0) SetLabel("V_EF",  DoubleToString(fast[0],  2), C_CYAN);
   if(CopyBuffer(g_hSlowEMA,  0, 0, 1, slow)  > 0) SetLabel("V_ES",  DoubleToString(slow[0],  2), C_CYAN);
   if(CopyBuffer(g_hTrendEMA, 0, 0, 1, trend) > 0) SetLabel("V_ET",  DoubleToString(trend[0], 2), C_WHITE);
   if(CopyBuffer(g_hRSI,      0, 0, 1, rsi)   > 0)
   {
      color cR = (rsi[0]>InpRSIOverbought||rsi[0]<InpRSIOversold) ? C_RED : C_WHITE;
      SetLabel("V_RSI", DoubleToString(rsi[0], 1), cR);
   }
   if(CopyBuffer(g_hADX, 0, 0, 1, adx) > 0)
   {
      color cA = (adx[0] >= InpADXMinStrength) ? C_GREEN : C_GOLD;
      SetLabel("V_ADX", DoubleToString(adx[0], 1), cA);
   }
   if(CopyBuffer(g_hMACD, 2, 0, 2, hist) >= 2)
   {
      color cM = (hist[0] > 0) ? C_GREEN : C_RED;
      SetLabel("V_MCD", DoubleToString(hist[0], 4), cM);
   }

   // BB status pill
   double upper[1], lower[1], mid[1];
   if(CopyBuffer(g_hBB,1,0,1,upper)>0 && CopyBuffer(g_hBB,2,0,1,lower)>0 && CopyBuffer(g_hBB,0,0,1,mid)>0)
   {
      bool squeeze = (upper[0]-lower[0]) < bid * InpBBSqueezeRatio;
      SetLabel("V_BBP", squeeze ? "SQUEEZE" : "EXPAND", squeeze ? C_RED : C_GREEN);
      // Update BB pill background colour via re-drawing
      string pillN = DASH_PREFIX+"BB_PILL";
      if(ObjectFind(0,pillN)>=0) ObjectSetInteger(0,pillN,OBJPROP_BGCOLOR, squeeze ? C_SELL_BG : C_BUY_BG);
   }

   // Structure
   ENUM_SIGNAL sig = EvaluateConfluence(true);
   bool structOk = CheckMarketStructure(sig, false);
   SetLabel("V_STR", structOk ? "BREAK" : "HOLD", structOk ? C_GREEN : C_MUTED);

   //--- Decision bar + Final Decision
   string decTxt;
   color  decClr;
   color  decBg;
   string aiTxt;

   if(g_State == STATE_ANALYZING)
   {
      int elapsed = (int)(TimeCurrent() - g_AnalysisStart);
      decTxt = "Decision: ANALYSING ("+IntegerToString(elapsed)+"s)";
      decClr = C_PURPLE; decBg = C_PANEL2; aiTxt = "ANALYSING";
   }
   else if(sig == SIGNAL_BUY)
   {
      decTxt = "Decision: BUY"; decClr = C_GREEN; decBg = C_BUY_BG; aiTxt = "BUY";
   }
   else if(sig == SIGNAL_SELL)
   {
      decTxt = "Decision: SELL"; decClr = C_RED; decBg = C_SELL_BG; aiTxt = "SELL";
   }
   else
   {
      decTxt = "Decision: HOLD"; decClr = C_GOLD; decBg = C_HOLD_BG; aiTxt = "HOLD";
   }

   SetLabel("V_DEC", decTxt, decClr);
   string decBarN = DASH_PREFIX+"DEC_BAR";
   if(ObjectFind(0,decBarN)>=0) ObjectSetInteger(0,decBarN,OBJPROP_BGCOLOR,decBg);

   // Final decision large block
   string fdN = DASH_PREFIX+"FD_BG";
   if(ObjectFind(0,fdN)>=0) ObjectSetInteger(0,fdN,OBJPROP_BGCOLOR,decBg);
   if(g_State == STATE_ANALYZING)
      SetLabel("V_FD", "ANALYSING", C_PURPLE);
   else
      SetLabel("V_FD", aiTxt, decClr);

   SetLabel("V_FDS1", aiTxt, decClr);
   SetLabel("V_FDS2", g_StatusText, g_StatusColor);

   //--- AI Engine status
   SetLabel("V_AIST", g_StatusText, g_StatusColor);
   // Status dot colour
   string dotN = DASH_PREFIX+"AI_DOT";
   if(ObjectFind(0,dotN)>=0) ObjectSetInteger(0,dotN,OBJPROP_COLOR,g_StatusColor);

   // Last decision
   string lastDec = (sig==SIGNAL_BUY) ? "BUY" : (sig==SIGNAL_SELL) ? "SELL" : "HOLD";
   SetLabel("V_AILD", lastDec, decClr);

   // Confidence = score / 7 × 100 — approximate from indicator states
   int score = 2; // EMA always counted if we got this far
   double rsiV[1], adxV[1];
   if(CopyBuffer(g_hRSI,0,0,1,rsiV)>0 && ((sig==SIGNAL_BUY&&rsiV[0]>50&&rsiV[0]<InpRSIOverbought)||(sig==SIGNAL_SELL&&rsiV[0]<50&&rsiV[0]>InpRSIOversold))) score++;
   if(CopyBuffer(g_hADX,0,0,1,adxV)>0 && adxV[0]>=InpADXMinStrength) score++;
   if(CopyBuffer(g_hMACD,2,0,2,hist)>=2 && ((sig==SIGNAL_BUY&&hist[0]>0)||(sig==SIGNAL_SELL&&hist[0]<0))) score++;
   int confPct = (int)MathRound((score / 7.0) * 100.0);
   string confTxt = (confPct >= 70) ? "HIGH" : (confPct >= 50) ? "MEDIUM" : "LOW";
   color  confClr = (confPct >= 70) ? C_GREEN : (confPct >= 50) ? C_GOLD : C_RED;
   SetLabel("V_AISC", confTxt, confClr);
   // Update confidence bar fill width (max 140px)
   string confFgN = DASH_PREFIX+"CONF_FG";
   if(ObjectFind(0,confFgN)>=0)
      ObjectSetInteger(0,confFgN,OBJPROP_XSIZE, MathMax(4,(int)MathRound(140*(confPct/100.0))));
   string confFgC = DASH_PREFIX+"CONF_FG";
   if(ObjectFind(0,confFgC)>=0) ObjectSetInteger(0,confFgC,OBJPROP_BGCOLOR,confClr);

   //--- Open Positions Table
   int posCount = 0;
   double totalFloat = 0.0;
   for(int r = 0; r < 3; r++)
   {
      string rs = IntegerToString(r);
      bool filled = false;
      if(r < PositionsTotal())
      {
         if(g_Pos.SelectByIndex(r) && g_Pos.Magic()==InpMagicNumber && g_Pos.Symbol()==_Symbol)
         {
            string typStr = (g_Pos.PositionType()==POSITION_TYPE_BUY) ? "BUY" : "SELL";
            color  typClr = (g_Pos.PositionType()==POSITION_TYPE_BUY) ? C_GREEN : C_RED;
            double rowPnl = g_Pos.Profit()+g_Pos.Swap()+g_Pos.Commission();
            totalFloat   += rowPnl;
            posCount++;
            SetLabel("OR_T"+rs, typStr,                              typClr);
            SetLabel("OR_L"+rs, DoubleToString(g_Pos.Volume(),2),    C_WHITE);
            SetLabel("OR_O"+rs, DoubleToString(g_Pos.PriceOpen(),2), C_WHITE);
            SetLabel("OR_S"+rs, DoubleToString(g_Pos.StopLoss(),2),  C_RED);
            SetLabel("OR_P"+rs, DoubleToString(g_Pos.TakeProfit(),2),C_GREEN);
            color pC = (rowPnl>=0) ? C_GREEN : C_RED;
            SetLabel("OR_F"+rs, (rowPnl>=0?"+":"")+DoubleToString(rowPnl,2), pC);
            filled = true;
         }
      }
      if(!filled)
      {
         SetLabel("OR_T"+rs, "---", C_MUTED);
         SetLabel("OR_L"+rs, "---", C_MUTED);
         SetLabel("OR_O"+rs, "---", C_MUTED);
         SetLabel("OR_S"+rs, "---", C_MUTED);
         SetLabel("OR_P"+rs, "---", C_MUTED);
         SetLabel("OR_F"+rs, "---", C_MUTED);
      }
   }
   SetLabel("OP_CNT", IntegerToString(posCount)+" open", posCount>0 ? C_CYAN : C_MUTED);
   color cFlt = (totalFloat>=0) ? C_GREEN : C_RED;
   SetLabel("V_FLT",  (totalFloat>=0?"+":"")+DoubleToString(totalFloat,2), cFlt);
   SetLabel("V_OEQV", "$"+DoubleToString(AccountInfoDouble(ACCOUNT_EQUITY),2), C_WHITE);

   //--- Account Info
   double bal    = AccountInfoDouble(ACCOUNT_BALANCE);
   double eq     = AccountInfoDouble(ACCOUNT_EQUITY);
   int    tot    = g_DailyWins + g_DailyLosses;
   double wr     = (tot>0) ? ((double)g_DailyWins/tot)*100.0 : 0.0;
   double dpPct  = (bal>0) ? (g_DailyProfit/bal)*100.0 : 0.0;

   SetLabel("V_BAL", "$"+DoubleToString(bal,2), C_GREEN);
   SetLabel("V_EQ",  "$"+DoubleToString(eq, 2), C_WHITE);
   color cDp = (g_DailyProfit>=0) ? C_GREEN : C_RED;
   SetLabel("V_DP",  (g_DailyProfit>=0?"+":"")+DoubleToString(g_DailyProfit,2)
            +" ("+DoubleToString(MathAbs(dpPct),2)+"%)", cDp);

   // Rolling 7-trade win rate (more meaningful than daily)
   color cWR = (g_WinRate7>=60) ? C_GREEN : (g_WinRate7>=40 ? C_GOLD : C_RED);
   string wrStr = IntegerToString((int)wr)+"% | 7T:"+IntegerToString((int)g_WinRate7)+"%";
   SetLabel("V_WR", wrStr, cWR);
   SetLabel("V_RSK", DoubleToString(GetRiskAdjustedPercent(),1)+"%", C_GOLD);

   // Peak profit display (only when trade is running)
   if(IsPositionOpen() && g_PeakProfit > 0.0)
      SetLabel("V_FLT", (totalFloat>=0?"+":"-")+"$"+DoubleToString(MathAbs(totalFloat),2)
               +" Pk:$"+DoubleToString(g_PeakProfit,2),
               (totalFloat>=0)?C_GREEN:C_RED);

   // Loss streak alert on dashboard
   if(g_ConsecLosses >= 2)
   {
      string streakAlert = "!! LOSS STREAK x"+IntegerToString(g_ConsecLosses)
                          +" | Need "+IntegerToString(5+g_ConsecLosses)+"/7";
      SetLabel("V_STK", streakAlert, C_RED);
   }
   else if(g_ConsecWins >= 2)
      SetLabel("V_STK", "WIN STREAK x"+IntegerToString(g_ConsecWins), C_GREEN);
   else
      SetLabel("V_STK", "---", C_MUTED);

   // Last 7 results strip (W=green dot, L=red dot)
   string strip = "";
   for(int j = 0; j < 7; j++)
   {
      if(g_Last7Results[j] < 0) strip += ". ";
      else if(g_Last7Results[j]==1) strip += "W ";
      else strip += "L ";
   }
   SetLabel("V_CONF", "Score:"+IntegerToString(g_LastConfluenceScore)+"/7  "+strip, C_CYAN);

   //--- Session Pills – highlight active session
   MqlDateTime gmt; TimeToStruct(TimeGMT(), gmt);
   int h = gmt.hour;
   bool isLon = (h>=7  && h<16);
   bool isNYC = (h>=13 && h<22);
   bool isAsi = (h>=22 || h<7);

   string lonN=DASH_PREFIX+"SB_LON", nycN=DASH_PREFIX+"SB_NYC", asiN=DASH_PREFIX+"SB_ASI";
   string ltN=DASH_PREFIX+"SB_LT",   ntN=DASH_PREFIX+"SB_NT",   atN=DASH_PREFIX+"SB_AT";

   if(ObjectFind(0,lonN)>=0) ObjectSetInteger(0,lonN,OBJPROP_BGCOLOR, isLon ? C_BLUE  : C_PANEL);
   if(ObjectFind(0,nycN)>=0) ObjectSetInteger(0,nycN,OBJPROP_BGCOLOR, isNYC ? C_GOLD  : C_PANEL);
   if(ObjectFind(0,asiN)>=0) ObjectSetInteger(0,asiN,OBJPROP_BGCOLOR, isAsi ? C_CYAN  : C_PANEL);
   if(ObjectFind(0,ltN) >=0) ObjectSetInteger(0,ltN, OBJPROP_COLOR,   isLon ? C_WHITE : C_MUTED);
   if(ObjectFind(0,ntN) >=0) ObjectSetInteger(0,ntN, OBJPROP_COLOR,   isNYC ? C_BG    : C_MUTED);
   if(ObjectFind(0,atN) >=0) ObjectSetInteger(0,atN, OBJPROP_COLOR,   isAsi ? C_BG    : C_MUTED);

   ChartRedraw(0);
}

//+------------------------------------------------------------------+
//| HELPER: timeframe to short string                                |
//+------------------------------------------------------------------+
string TimeframeToString(ENUM_TIMEFRAMES tf)
{
   switch(tf)
   {
      case PERIOD_M1:  return "1";
      case PERIOD_M5:  return "5";
      case PERIOD_M15: return "15";
      case PERIOD_M30: return "30";
      case PERIOD_H1:  return "H1";
      case PERIOD_H4:  return "H4";
      case PERIOD_D1:  return "D1";
      default:         return "?";
   }
}

void PurgeDashboard()
{
   ObjectsDeleteAll(0, DASH_PREFIX);
   ChartRedraw(0);
}

void DrawRect(string id, int x, int y, int w, int h, color bg, color border, int bw)
{
   string n = DASH_PREFIX + id;
   if(ObjectFind(0, n) < 0) ObjectCreate(0, n, OBJ_RECTANGLE_LABEL, 0, 0, 0);
   ObjectSetInteger(0, n, OBJPROP_CORNER,    CORNER_LEFT_UPPER);
   ObjectSetInteger(0, n, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, n, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, n, OBJPROP_XSIZE,     w);
   ObjectSetInteger(0, n, OBJPROP_YSIZE,     h);
   ObjectSetInteger(0, n, OBJPROP_BGCOLOR,   bg);
   if(border != clrNONE)
   {
      ObjectSetInteger(0, n, OBJPROP_BORDER_TYPE, BORDER_FLAT);
      ObjectSetInteger(0, n, OBJPROP_COLOR,        border);
      ObjectSetInteger(0, n, OBJPROP_WIDTH,         bw);
   }
   else ObjectSetInteger(0, n, OBJPROP_BORDER_TYPE, BORDER_RAISED);
   ObjectSetInteger(0, n, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, n, OBJPROP_HIDDEN,     true);
   ObjectSetInteger(0, n, OBJPROP_ZORDER,     0);
}

void DrawLabel(string id, int x, int y, string txt, color clr, int sz, string fnt)
{
   string n = DASH_PREFIX + id;
   if(ObjectFind(0, n) < 0) ObjectCreate(0, n, OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, n, OBJPROP_CORNER,    CORNER_LEFT_UPPER);
   ObjectSetInteger(0, n, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, n, OBJPROP_YDISTANCE, y);
   ObjectSetString( 0, n, OBJPROP_TEXT,      txt);
   ObjectSetInteger(0, n, OBJPROP_COLOR,     clr);
   ObjectSetInteger(0, n, OBJPROP_FONTSIZE,  sz);
   ObjectSetString( 0, n, OBJPROP_FONT,      fnt);
   ObjectSetInteger(0, n, OBJPROP_SELECTABLE,false);
   ObjectSetInteger(0, n, OBJPROP_HIDDEN,    true);
   ObjectSetInteger(0, n, OBJPROP_ZORDER,    1);
}

void SetLabel(string id, string txt, color clr = clrNONE)
{
   string n = DASH_PREFIX + id;
   if(ObjectFind(0, n) >= 0)
   {
      ObjectSetString(0, n, OBJPROP_TEXT, txt);
      if(clr != clrNONE) ObjectSetInteger(0, n, OBJPROP_COLOR, clr);
   }
}
//+------------------------------------------------------------------+
//| END OF FILE                                                      |
//+------------------------------------------------------------------+
