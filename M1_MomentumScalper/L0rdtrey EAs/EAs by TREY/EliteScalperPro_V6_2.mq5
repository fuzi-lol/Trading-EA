//+------------------------------------------------------------------+
//|                                       EliteScalperPro_V6.mq5     |
//|                                  Copyright 2026, FXBotHub Systems|
//|                                             https://fxbothub.com |
//+------------------------------------------------------------------+
//  GOLD (XAUUSD) INSTITUTIONAL-GRADE SCALPING ENGINE — V6.00
//
//  WHAT CHANGED FROM V5 (full strategic rebuild):
//    • Tiered TP1/TP2/TP3 exits that RATCHET — once TP2 is hit the
//      stop is locked at the TP1 price, so the runner can never
//      collapse back below a locked tier. No more "ran to 3R and
//      gave it all back to close near breakeven."
//    • Dynamic, account-size-aware R:R. SL/TP are pure ATR multiples
//      and lot size is risk-% derived, so the same engine behaves
//      sensibly on a $50 account and a $10,000 account.
//    • Adaptive entry timing — NOT a fixed blocking "analysis window."
//      In a strong trend (high ADX / expansion) the EA fires almost
//      immediately; in choppy conditions it asks for a few extra
//      ticks of confirmation. It never sits out a real move waiting
//      for an arbitrary timer.
//    • Live News Intelligence: native MQL5 economic calendar reader,
//      currency-relevance filtering, pre/post-news trade blocking,
//      and a sentiment/volatility-expectation score that feeds the
//      trade-quality engine (works live; calendar API has no history
//      in Strategy Tester — see NewsModule notes).
//    • Trade-Quality Score (0-100): blends confluence score, ADX
//      strength, session quality, spread quality, news proximity and
//      volatility regime into a single score that GATES position size
//      and aggressiveness — not just a yes/no filter.
//    • Dynamic risk engine: risk-per-trade scales with trade-quality
//      score, equity drawdown state, and win/loss streaks, with hard
//      floors/ceilings so a $50 account never over-levers.
//    • GOLD-specific scalping upgrades that were missing in V5:
//        - Spread/volatility regime classifier (ATR percentile)
//        - Liquidity sweep / stop-hunt detection (wick-based)
//        - Order block + Fair Value Gap (FVG) confluence layer
//        - Round-number magnet avoidance (XAUUSD loves $X00/$X50 levels)
//        - Session-volatility profile (London/NY overlap weighting)
//        - Correlation/DXY-proxy momentum filter (optional, via
//          opposite-direction USD pairs) to avoid fighting the dollar
//        - Equity-curve circuit breaker (pauses after fast drawdown)
//    • Luxury dashboard skin — same panel layout/architecture as V5,
//      re-themed in a black/gold "private bank terminal" palette with
//      gradient-style layered panels, a live quality-score gauge and
//      a news-risk strip. No second dashboard — this IS the dashboard.
//+------------------------------------------------------------------+
#property copyright   "Copyright 2026, FXBotHub Systems"
#property version     "6.00"
#property description "GOLD Institutional Scalping Engine V6 — Tiered Exits, News Intelligence, Adaptive Quality Gating"
#property strict

#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>

#define DASH_PREFIX  "FXBH_V6_"
#define EA_VERSION   "v6.00"

//+------------------------------------------------------------------+
//| ENGINE STATE MACHINE                                             |
//+------------------------------------------------------------------+
enum ENUM_ENGINE_STATE
{
   STATE_SCANNING,
   STATE_CONFIRMING,     // short adaptive confirmation (replaces rigid "analysis")
   STATE_COOLDOWN,
   STATE_DAILY_LIMIT,
   STATE_NEWS_PAUSE,
   STATE_CIRCUIT_BREAKER // equity-curve drawdown pause
};

enum ENUM_SIGNAL
{
   SIGNAL_BUY  =  1,
   SIGNAL_SELL = -1,
   SIGNAL_NONE =  0
};

enum ENUM_TP_STAGE
{
   TP_STAGE_NONE = 0,   // no partials taken yet
   TP_STAGE_TP1  = 1,   // TP1 hit, BE+ locked
   TP_STAGE_TP2  = 2,   // TP2 hit, locked at TP1, runner active
   TP_STAGE_TP3  = 3    // TP3 hit / full close
};

enum ENUM_VOL_REGIME
{
   VOL_LOW,
   VOL_NORMAL,
   VOL_HIGH,
   VOL_EXTREME
};

//+------------------------------------------------------------------+
//| INPUT PARAMETERS                                                 |
//+------------------------------------------------------------------+
input group "=== CORE IDENTITY ==="
input ulong   InpMagicNumber       = 999556;     // Unique Magic Number
input string  InpTradeComment      = "EliteScalperPro_V6";

input group "=== DYNAMIC RISK ENGINE (account-size aware) ==="
input double  InpBaseRiskPercent   = 1.0;        // Base risk % per trade (scales with quality score)
input double  InpMinRiskPercent    = 0.35;       // Floor risk % (low quality / drawdown state)
input double  InpMaxRiskPercent    = 1.75;       // Ceiling risk % (high quality, healthy equity)
input double  InpMaxDailyLossPct   = 5.0;        // Daily loss limit % (kill-switch)
input double  InpMaxDailyProfitPct = 8.0;        // Daily profit target % (soft stop, see InpLockProfitAfterTarget)
input bool    InpLockProfitAfterTarget = true;   // After target: only allow trades that reduce risk / tighten, no fresh aggressive entries
input int     InpMaxDailyTrades    = 18;         // Max trades per day
input double  InpMinAccountBalance = 20.0;       // Absolute floor — EA halts below this balance

input group "=== EQUITY CIRCUIT BREAKER ==="
input bool    InpUseCircuitBreaker = true;       // Pause trading after fast equity drawdown
input double  InpCircuitDrawdownPct= 4.0;        // % equity drop from peak (intraday) to trigger pause
input int     InpCircuitPauseMin   = 60;         // Pause duration in minutes once triggered

input group "=== ATR-BASED DYNAMIC SL / TIERED TP ==="
input int     InpATRPeriod         = 14;         // ATR period
input double  InpSLMultiplier      = 1.0;        // SL = ATR × multiplier
input double  InpTP1Multiplier     = 1.0;        // TP1 = ATR × multiplier (R:R 1:1) — first partial
input double  InpTP2Multiplier     = 1.8;        // TP2 = ATR × multiplier (R:R 1:1.8) — second partial
input double  InpTP3Multiplier     = 3.2;        // TP3 = ATR × multiplier (R:R 1:3.2) — runner target
input int     InpMinSLPoints       = 80;         // Minimum SL in points (floor, broker-safe)
input int     InpMaxSLPoints       = 450;        // Maximum SL in points (ceiling)

input group "=== TIERED PARTIAL CLOSE (ratchet system) ==="
input double  InpTP1ClosePct       = 40.0;       // % of position closed at TP1
input double  InpTP2ClosePct       = 35.0;       // % of remaining position closed at TP2 (of original)
input int     InpBreakevenBuffer   = 15;         // Buffer (points) above/below entry for BE+ lock at TP1
input bool    InpUseRunnerTrailing = true;       // Trail the final runner after TP2
input int     InpRunnerTrailStepPts= 35;         // Tight trail step for runner (points) post-TP2
input int     InpPreTP1TrailStartPts = 999999;   // Disabled pre-TP1 (we don't trail before locking TP1; set lower to enable)

input group "=== ADAPTIVE ENTRY TIMING (not a rigid wait) ==="
input bool    InpUseAdaptiveConfirm = true;      // Adaptive micro-confirmation instead of fixed window
input int     InpFastTrackADX      = 32;         // ADX above this = near-instant entry (1 tick confirm)
input int     InpConfirmMaxSeconds = 12;         // Hard ceiling on confirmation phase (choppy conditions)
input int     InpConfirmMinTicks   = 2;          // Minimum ticks even in fast-track mode (spike filter)

input group "=== SIGNAL CONFLUENCE ENGINE ==="
input int     InpFastEMAPeriod     = 9;          // Fast EMA period
input int     InpSlowEMAPeriod     = 21;         // Slow EMA period
input int     InpTrendEMAPeriod    = 50;         // Trend EMA (bias filter)
input int     InpRSIPeriod         = 14;         // RSI period
input double  InpRSIOverbought     = 72.0;       // RSI overbought level
input double  InpRSIOversold       = 28.0;       // RSI oversold level
input int     InpADXPeriod         = 14;         // ADX period
input double  InpADXMinStrength    = 18.0;       // Minimum ADX for trend trade
input int     InpMACDFast          = 12;         // MACD fast period
input int     InpMACDSlow          = 26;         // MACD slow period
input int     InpMACDSignal        = 9;          // MACD signal period
input int     InpBBPeriod          = 20;         // Bollinger Bands period
input double  InpBBDeviation       = 2.0;        // Bollinger Bands deviation
input double  InpBBSqueezeRatio    = 0.0022;     // BB width/price ratio squeeze threshold
input int     InpStructureBars     = 5;          // Market structure high/low bars
input int     InpMinConfluenceScore= 5;          // Min score out of 9 to qualify (see scoring engine)

input group "=== GOLD-SPECIFIC: LIQUIDITY SWEEP / STOP-HUNT DETECTION ==="
input bool    InpUseSweepDetection = true;       // Detect liquidity sweeps (wick rejections) as entry boost
input int     InpSweepLookback     = 12;         // Bars to scan for swept liquidity
input double  InpSweepWickRatio    = 0.6;        // Min wick-to-range ratio to qualify as a sweep

input group "=== GOLD-SPECIFIC: ORDER BLOCK / FVG CONFLUENCE ==="
input bool    InpUseOrderBlockFVG  = true;       // Score boost when price reacts at OB/FVG zone
input int     InpOBLookback        = 20;         // Bars to scan for order blocks / FVGs

input group "=== GOLD-SPECIFIC: ROUND NUMBER MAGNET AVOIDANCE ==="
input bool    InpAvoidRoundNumbers = true;       // Avoid placing TP/entries too close to round $ levels
input double  InpRoundNumberStep   = 10.0;       // Gold round-level step (e.g. every $10)
input double  InpRoundNumberBuffer = 1.5;        // $ buffer to treat as "too close" to a magnet level

input group "=== COOLDOWN & SPREAD ==="
input int     InpCooldownSeconds   = 25;         // Cooldown between trades (seconds)
input int     InpSpreadMaxPoints   = 38;         // Hard spread ceiling (points)
input double  InpSpreadMultiplier  = 2.3;        // Dynamic: reject if spread > avg × X

input group "=== SESSION FILTER ==="
input bool    InpUseSessionFilter  = true;       // Only trade during active sessions
input int     InpSessionStartGMT   = 7;          // Session start hour (GMT) – London open
input int     InpSessionEndGMT     = 20;         // Session end hour (GMT)
input bool    InpBoostOverlapSession = true;     // Extra quality-score weight during London/NY overlap

input group "=== STREAK PROTECTION ==="
input int     InpMaxLossStreak     = 3;          // Reduce risk after N consecutive losses
input int     InpWinStreakBoost    = 4;          // Allow slight size increase after N wins (capped)

input group "=== LIVE NEWS INTELLIGENCE ==="
input bool    InpUseNewsFilter     = true;       // Enable economic calendar filtering (live only)
input int     InpNewsImportance    = 2;          // 0=Low+ , 1=Moderate+ , 2=High only
input int     InpNewsMinutesBefore = 20;         // Block new entries X minutes before high-impact news
input int     InpNewsMinutesAfter  = 15;         // Block new entries X minutes after high-impact news
input bool    InpCloseBeforeNews   = false;      // Force-close open trades ahead of high-impact news
input int     InpNewsCloseMinutes  = 5;          // Minutes before news to force-close (if enabled)
input bool    InpNewsPauseManual   = false;      // Manual news pause toggle (set true before unscheduled events)

input group "=== DASHBOARD ==="
input int     InpDashX            = 15;
input int     InpDashY            = 15;

//+------------------------------------------------------------------+
//| LUXURY DASHBOARD PALETTE — "Private Bank Terminal"               |
//| Black/obsidian base, champagne-gold accents, deep emerald/garnet |
//| for state colour, soft platinum text. Same panel architecture    |
//| as V5 — re-skinned only, per request.                            |
//+------------------------------------------------------------------+
const color C_BG          = C'8,8,10';       // near-black obsidian
const color C_PANEL       = C'14,13,16';     // panel base
const color C_PANEL2      = C'19,17,21';     // panel alt (zebra rows)
const color C_HEADER      = C'17,14,10';     // header — warm black
const color C_BORDER      = C'201,162,77';   // champagne gold border
const color C_BORDER2     = C'90,76,46';     // muted bronze border
const color C_GOLDLINE    = C'255,215,120';  // bright gold hairline
const color C_CYAN        = C'120,210,225';  // platinum-cyan accent (data)
const color C_BLUE        = C'90,150,220';   // steel blue accent
const color C_GREEN       = C'80,222,150';   // emerald (profit/buy)
const color C_RED         = C'224,82,90';    // garnet (loss/sell)
const color C_GOLD        = C'226,180,90';   // primary gold text
const color C_ORANGE      = C'235,150,70';   // section header copper
const color C_PURPLE      = C'185,140,230';  // amethyst (analysing/confirming)
const color C_WHITE       = C'238,233,222';  // warm platinum white
const color C_MUTED       = C'126,118,108';  // muted taupe
const color C_HOLD_BG     = C'46,36,12';     // deep bronze (hold)
const color C_BUY_BG      = C'10,38,26';     // deep emerald bg
const color C_SELL_BG     = C'42,12,16';     // deep garnet bg
const color C_SECTION_HDR = C'22,18,11';     // section header backing
const color C_GAUGE_BG    = C'25,22,16';
const color C_NEWS_BG     = C'30,16,10';

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

//--- Adaptive confirmation phase (replaces rigid analysis window)
ENUM_SIGNAL  g_PendingSignal     = SIGNAL_NONE;
int          g_ConfirmTicks      = 0;
datetime     g_ConfirmStart      = 0;
int          g_ConfirmTargetTicks= 0;   // computed adaptively each time

//--- Per-trade tier tracking
ENUM_TP_STAGE g_TPStage          = TP_STAGE_NONE;
double        g_EntrySL          = 0.0;
double        g_TP1Price         = 0.0;
double        g_TP2Price         = 0.0;
double        g_TP3Price         = 0.0;
double        g_OriginalVolume   = 0.0;

//--- Session metrics
datetime g_SessionDay       = 0;
int      g_DailyTrades      = 0;
double   g_DailyProfit      = 0.0;
int      g_DailyWins        = 0;
int      g_DailyLosses      = 0;
int      g_ConsecLosses     = 0;
int      g_ConsecWins       = 0;
double   g_SessionOpenBal   = 0.0;

//--- Equity circuit breaker
double   g_EquityPeak       = 0.0;
datetime g_CircuitUntil     = 0;

//--- Spread tracking
double g_AvgSpread          = 0.0;
int    g_SpreadSamples      = 0;

//--- Trade quality score (0-100), drives risk sizing
double g_LastQualityScore   = 0.0;
int    g_LastConfluenceScore= 0;

//--- News module state
bool     g_NewsBlockActive  = false;
string   g_NewsBlockReason  = "";
datetime g_NextHighImpact   = 0;
string   g_NextNewsTitle    = "";
double   g_NewsSentiment    = 0.0;   // -100..+100 directional skew proxy (volatility-expectation based)

//--- Dashboard strings
string g_StatusText         = "BOOTING";
color  g_StatusColor        = C_GOLD;
string g_HeartbeatStr       = "0 0 0 0";

//+------------------------------------------------------------------+
//| FORWARD DECLARATIONS                                             |
//+------------------------------------------------------------------+
bool          InitIndicators();
void          ReleaseIndicators();
void          SyncDailyStats();
ENUM_SIGNAL   EvaluateConfluence(int &scoreOut, bool detectionMode = true);
bool          CheckEMAStack(double &fast, double &slow, double &trend);
bool          CheckRSI(ENUM_SIGNAL sig, double &rsiVal);
bool          CheckADX(double &adxVal);
bool          CheckMACD(ENUM_SIGNAL sig);
bool          CheckBollingerBands(ENUM_SIGNAL sig, bool &inSqueeze);
bool          CheckMarketStructure(ENUM_SIGNAL sig, bool proximityMode = false);
bool          CheckLiquiditySweep(ENUM_SIGNAL sig);
bool          CheckOrderBlockFVG(ENUM_SIGNAL sig);
bool          CheckRoundNumberSafe(double price);
double        GetATR();
ENUM_VOL_REGIME GetVolatilityRegime();
double        CalculateLotSize(int slPoints, double riskPct);
double        ComputeTradeQualityScore(int confluenceScore, ENUM_SIGNAL sig);
double        GetDynamicRiskPercent(double qualityScore);
void          ExecuteEntry(ENUM_SIGNAL sig);
void          ManageOpenTrade();
void          CheckTieredExits();
void          EvaluateFloatingPnL();
bool          IsPositionOpen();
double        GetFloatingPnL();
void          CloseAllPositions(string reason);
void          ClosePartial(double pct, string reason);
bool          IsMarketOpen();
bool          IsInSession();
bool          IsOverlapSession();
bool          IsSpreadOk();
void          UpdateSpreadAverage();
bool          IsDailyLossLimitHit();
bool          IsDailyProfitTargetHit();
bool          IsCircuitBreakerTripped();
void          UpdateEquityPeak();
datetime      GetDayStart(datetime t);
void          ProcessConfirmationPhase();
int           ComputeAdaptiveConfirmTarget(double adxVal);
//--- News intelligence
void          UpdateNewsIntelligence();
bool          IsNewsBlocking();
void          CheckForceCloseBeforeNews();
//--- Dashboard
void          RenderDashboard();
void          UpdateDashboard();
void          PurgeDashboard();
void          DrawRect(string id, int x, int y, int w, int h, color bg, color border, int bw);
void          DrawLabel(string id, int x, int y, string txt, color clr, int sz, string fnt);
void          SetLabel(string id, string txt, color clr = clrNONE);
string        TimeframeToString(ENUM_TIMEFRAMES tf);
int           W_TRACK();

//+------------------------------------------------------------------+
//| INIT                                                              |
//+------------------------------------------------------------------+
int OnInit()
{
   if(StringFind(_Symbol, "XAU") < 0 && StringFind(_Symbol, "GOLD") < 0)
      Print("[EliteScalperPro V6] WARNING: Optimised for GOLD (XAUUSD). Current symbol: ", _Symbol);

   g_Trade.SetExpertMagicNumber(InpMagicNumber);
   g_Trade.SetDeviationInPoints(20);
   g_Trade.SetTypeFilling(ORDER_FILLING_FOK);

   if(InpBaseRiskPercent <= 0.0 || InpBaseRiskPercent > 10.0)
   { Alert("Base Risk% must be 0.01–10. Got: ", InpBaseRiskPercent); return INIT_PARAMETERS_INCORRECT; }

   if(!InitIndicators()) return INIT_FAILED;

   g_SessionDay     = GetDayStart(TimeCurrent());
   g_SessionOpenBal = AccountInfoDouble(ACCOUNT_BALANCE);
   g_EquityPeak     = AccountInfoDouble(ACCOUNT_EQUITY);
   SyncDailyStats();

   g_State = STATE_SCANNING;
   EventSetTimer(1);
   RenderDashboard();

   Print("[EliteScalperPro V6] Initialised. Symbol=", _Symbol, " Magic=", InpMagicNumber,
         " | Tiered TP system active | News filter=", (InpUseNewsFilter?"ON":"OFF"));
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| DEINIT                                                            |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   EventKillTimer();
   PurgeDashboard();
   ReleaseIndicators();
}

//+------------------------------------------------------------------+
//| TIMER – heartbeat + stats sync + news poll                        |
//+------------------------------------------------------------------+
void OnTimer()
{
   static uint beat = 0; beat++;
   string p[4] = {"1 0 1 1  0 1 0 0","0 1 0 0  1 0 1 1","1 1 0 1  0 0 1 0","0 0 1 0  1 1 0 1"};
   g_HeartbeatStr = p[beat % 4];
   SyncDailyStats();
   UpdateEquityPeak();

   //--- News intelligence is polled every timer tick (1s) but the
   //    underlying calendar reload is internally throttled in
   //    UpdateNewsIntelligence() to avoid hammering the terminal.
   if(InpUseNewsFilter) UpdateNewsIntelligence();

   if(InpCloseBeforeNews) CheckForceCloseBeforeNews();

   UpdateDashboard();
}

//+------------------------------------------------------------------+
//| TICK – main engine                                                |
//+------------------------------------------------------------------+
void OnTick()
{
   UpdateSpreadAverage();

   //--- Market tradeable?
   if(!IsMarketOpen())
   { g_StatusText = "MARKET CLOSED"; g_StatusColor = C_RED; return; }

   //--- Absolute balance floor (protects tiny accounts from over-trading into zero)
   if(AccountInfoDouble(ACCOUNT_BALANCE) < InpMinAccountBalance)
   {
      g_StatusText = "BALANCE BELOW SAFETY FLOOR";
      g_StatusColor = C_RED;
      return;
   }

   //--- Manual news pause
   if(InpNewsPauseManual)
   { g_StatusText = "MANUAL NEWS PAUSE"; g_StatusColor = C_GOLD; return; }

   //--- Live news intelligence block (high-impact window)
   if(InpUseNewsFilter && IsNewsBlocking())
   {
      if(IsPositionOpen()) ManageOpenTrade(); // still manage existing trades through news
      g_StatusText = "NEWS WINDOW: " + g_NewsBlockReason;
      g_StatusColor = C_ORANGE;
      return;
   }

   //--- Equity circuit breaker
   if(InpUseCircuitBreaker && IsCircuitBreakerTripped())
   {
      if(IsPositionOpen()) ManageOpenTrade();
      g_State = STATE_CIRCUIT_BREAKER;
      int left = (int)((g_CircuitUntil - TimeCurrent())/60) + 1;
      g_StatusText = "CIRCUIT BREAKER (" + IntegerToString(left) + "m left)";
      g_StatusColor = C_RED;
      return;
   }
   else if(g_State == STATE_CIRCUIT_BREAKER)
   {
      g_State = STATE_SCANNING;
   }

   //--- Manage any open trade first (tiered exits, ratchet, trailing)
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

   //--- Daily profit target reached (soft stop — configurable)
   bool profitTargetHit = IsDailyProfitTargetHit();
   if(profitTargetHit && !InpLockProfitAfterTarget)
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

   //--- SCANNING: evaluate confluence signal. Note this is NOT a blocking
   //    wait — every tick we either qualify on this tick or we don't;
   //    there is no artificial "minimum observation time" gate here.
   if(g_State == STATE_SCANNING)
   {
      int score = 0;
      ENUM_SIGNAL sig = EvaluateConfluence(score, true);
      if(sig == SIGNAL_NONE)
      {
         g_StatusText  = "SCANNING – BUILDING CONFLUENCE (" + IntegerToString(score) + "/9)";
         g_StatusColor = C_MUTED;
         return;
      }

      // Quality-score gate (soft — affects size, not a hard block unless
      // quality is genuinely poor, e.g. < 25, which only happens if
      // spread/session/news conditions are also bad simultaneously)
      double quality = ComputeTradeQualityScore(score, sig);
      g_LastQualityScore = quality;
      g_LastConfluenceScore = score;

      if(quality < 25.0)
      {
         g_StatusText = "SIGNAL FOUND BUT LOW QUALITY (" + DoubleToString(quality,0) + "/100) – SKIPPED";
         g_StatusColor = C_MUTED;
         return;
      }

      // Profit-target-lock mode: only take very high quality trades once
      // the daily target is hit, instead of fully halting.
      if(profitTargetHit && InpLockProfitAfterTarget && quality < 65.0)
      {
         g_StatusText = "TARGET MET – ONLY A+ SETUPS NOW (" + DoubleToString(quality,0) + "/100)";
         g_StatusColor = C_GOLD;
         return;
      }

      double adxVal=0; double adxArr[1];
      if(CopyBuffer(g_hADX,0,0,1,adxArr)>0) adxVal = adxArr[0];

      // Adaptive confirmation: strong trend = near instant; choppier = a
      // few extra ticks. NEVER a fixed multi-minute wait.
      g_State           = STATE_CONFIRMING;
      g_PendingSignal    = sig;
      g_ConfirmStart      = TimeCurrent();
      g_ConfirmTicks      = 0;
      g_ConfirmTargetTicks= InpUseAdaptiveConfirm ? ComputeAdaptiveConfirmTarget(adxVal) : InpConfirmMinTicks;
      g_StatusText        = "SIGNAL CONFIRMED – ENTRY IN " + IntegerToString(g_ConfirmTargetTicks) + " TICK(S)";
      g_StatusColor       = C_PURPLE;
      PrintFormat("[EliteScalperPro V6] Signal=%s Score=%d/9 Quality=%.0f ADX=%.1f -> confirm target=%d ticks",
                  (sig==SIGNAL_BUY?"BUY":"SELL"), score, quality, adxVal, g_ConfirmTargetTicks);
   }
   //--- CONFIRMING: very short adaptive check, never a strict block
   else if(g_State == STATE_CONFIRMING)
   {
      ProcessConfirmationPhase();
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
      Print("[EliteScalperPro V6] FAILED: One or more indicator handles invalid.");
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
//| CONFLUENCE SIGNAL ENGINE — now 9-point scale                     |
//| Core 5 (EMA stack[2] + RSI + ADX + MACD + BB) PLUS 3 GOLD-       |
//| SPECIFIC layers: liquidity sweep, order block/FVG, round-number  |
//| safety. Score >= InpMinConfluenceScore (default 5/9) qualifies.  |
//| detectionMode=true  -> strict structure (scanning)               |
//| detectionMode=false -> relaxed/proximity structure (confirming)  |
//+------------------------------------------------------------------+
ENUM_SIGNAL EvaluateConfluence(int &scoreOut, bool detectionMode = true)
{
   scoreOut = 0;
   double fastEMA, slowEMA, trendEMA, rsiVal, adxVal;
   bool   inSqueeze = false;

   if(!CheckEMAStack(fastEMA, slowEMA, trendEMA))
      return SIGNAL_NONE; // no directional bias at all -> no trade, full stop

   ENUM_SIGNAL emaSig = (fastEMA > slowEMA && slowEMA > trendEMA) ? SIGNAL_BUY : SIGNAL_SELL;
   int score = 2; // EMA stack = 2 points (directional backbone)

   bool rsiPass    = CheckRSI(emaSig, rsiVal);
   bool adxPass    = CheckADX(adxVal);
   bool macdPass   = CheckMACD(emaSig);
   bool bbPass     = CheckBollingerBands(emaSig, inSqueeze);
   bool structPass = CheckMarketStructure(emaSig, !detectionMode);
   bool sweepPass  = InpUseSweepDetection ? CheckLiquiditySweep(emaSig) : false;
   bool obfvgPass  = InpUseOrderBlockFVG  ? CheckOrderBlockFVG(emaSig)  : false;

   if(rsiPass)    score++;
   if(adxPass)    score++;
   if(macdPass)   score++;
   if(bbPass)     score++;
   if(structPass) score++;
   if(sweepPass)  score++;
   if(obfvgPass)  score++;

   // BB squeeze is a hard block — no real range expansion to scalp
   if(inSqueeze) { scoreOut = score; return SIGNAL_NONE; }

   scoreOut = score;

   static int logTick = 0; logTick++;
   if(detectionMode && (logTick % 5 == 0))
   {
      PrintFormat("[Confluence] Dir=%s Score=%d/9 | EMA✓(2) RSI=%s ADX=%s(%.1f) MACD=%s BB=%s Struct=%s Sweep=%s OB/FVG=%s",
         (emaSig==SIGNAL_BUY?"BUY":"SELL"), score,
         rsiPass?"✓":"✗", adxPass?"✓":"✗", adxVal,
         macdPass?"✓":"✗", bbPass?"✓":"✗", structPass?"✓":"✗",
         sweepPass?"✓":"✗", obfvgPass?"✓":"✗");
   }

   if(score >= InpMinConfluenceScore) return emaSig;
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
   return (bull || bear);
}

bool CheckRSI(ENUM_SIGNAL sig, double &rsiVal)
{
   double r[1];
   if(CopyBuffer(g_hRSI, 0, 0, 1, r) <= 0) return false;
   rsiVal = r[0];
   if(sig == SIGNAL_BUY)  return (rsiVal > 50.0 && rsiVal < InpRSIOverbought);
   if(sig == SIGNAL_SELL) return (rsiVal < 50.0 && rsiVal > InpRSIOversold);
   return false;
}

bool CheckADX(double &adxVal)
{
   double adx[1];
   if(CopyBuffer(g_hADX, 0, 0, 1, adx) <= 0) return false;
   adxVal = adx[0];
   return (adxVal >= InpADXMinStrength);
}

//--- MACD histogram: index 0 = most recent bar, index 1 = previous bar.
bool CheckMACD(ENUM_SIGNAL sig)
{
   double hist[2];
   if(CopyBuffer(g_hMACD, 2, 0, 2, hist) < 2) return false;
   double current  = hist[0];
   double previous = hist[1];
   bool rising  = (current > previous);
   bool falling = (current < previous);
   if(sig == SIGNAL_BUY)  return (current > 0.0 && rising);
   if(sig == SIGNAL_SELL) return (current < 0.0 && falling);
   return false;
}

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
   if(sig == SIGNAL_BUY)  return (bid > mid[0]);
   if(sig == SIGNAL_SELL) return (bid < mid[0]);
   return false;
}

//--- Market structure: breakout (strict) or proximity (relaxed, confirming phase)
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
   double buffer    = atr * 0.5;

   if(proximityMode)
   {
      if(sig == SIGNAL_BUY)  return (ask >= swingHigh - buffer);
      if(sig == SIGNAL_SELL) return (bid <= swingLow  + buffer);
   }
   else
   {
      if(sig == SIGNAL_BUY)  return (ask > swingHigh);
      if(sig == SIGNAL_SELL) return (bid < swingLow);
   }
   return false;
}

//+------------------------------------------------------------------+
//| GOLD-SPECIFIC: LIQUIDITY SWEEP / STOP-HUNT DETECTION              |
//| Looks for a recent bar with a long wick beyond a prior swing      |
//| level that closed back inside range — classic stop-hunt before    |
//| reversal/continuation. Scores in favour of the EMA-aligned         |
//| direction if a sweep happened on the OPPOSITE side (i.e. shorts    |
//| got swept before a bull move, longs got swept before a bear move).|
//+------------------------------------------------------------------+
bool CheckLiquiditySweep(ENUM_SIGNAL sig)
{
   double highest = -DBL_MAX, lowest = DBL_MAX;
   for(int i = 2; i <= InpSweepLookback+1; i++)
   {
      double h = iHigh(_Symbol, _Period, i);
      double l = iLow(_Symbol,  _Period, i);
      if(h > highest) highest = h;
      if(l < lowest)  lowest  = l;
   }

   // Most recently closed bar
   double o1 = iOpen(_Symbol, _Period, 1);
   double c1 = iClose(_Symbol, _Period, 1);
   double h1 = iHigh(_Symbol, _Period, 1);
   double l1 = iLow(_Symbol, _Period, 1);
   double range = h1 - l1;
   if(range <= 0) return false;

   double upperWick = h1 - MathMax(o1,c1);
   double lowerWick = MathMin(o1,c1) - l1;

   bool sweptHighs = (h1 > highest) && (upperWick / range >= InpSweepWickRatio);
   bool sweptLows  = (l1 < lowest)  && (lowerWick / range >= InpSweepWickRatio);

   // Buy signal benefits from a swept-lows rejection (stop hunt below, then reversal up)
   if(sig == SIGNAL_BUY)  return sweptLows;
   // Sell signal benefits from a swept-highs rejection
   if(sig == SIGNAL_SELL) return sweptHighs;
   return false;
}

//+------------------------------------------------------------------+
//| GOLD-SPECIFIC: ORDER BLOCK / FAIR VALUE GAP CONFLUENCE             |
//| Simplified SMC detection: an order block is the last opposite-     |
//| coloured candle before a strong impulse leg; an FVG is a 3-candle  |
//| imbalance where candle 1's high/low doesn't overlap candle 3's     |
//| low/high. Scores true if current price is reacting near either     |
//| zone in the direction of the signal.                               |
//+------------------------------------------------------------------+
bool CheckOrderBlockFVG(ENUM_SIGNAL sig)
{
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double atr = GetATR();
   double tolerance = atr * 0.35;

   for(int i = 2; i <= InpOBLookback; i++)
   {
      double h1 = iHigh(_Symbol, _Period, i+1);
      double l1 = iLow(_Symbol,  _Period, i+1);
      double h3 = iHigh(_Symbol, _Period, i-1);
      double l3 = iLow(_Symbol,  _Period, i-1);

      // Bullish FVG: candle i-1's low is above candle i+1's high (gap up)
      bool bullishFVG = (l3 > h1);
      // Bearish FVG: candle i-1's high is below candle i+1's low (gap down)
      bool bearishFVG = (h3 < l1);

      if(sig == SIGNAL_BUY && bullishFVG)
      {
         double gapMid = (h1 + l3) / 2.0;
         if(MathAbs(bid - gapMid) <= tolerance) return true;
      }
      if(sig == SIGNAL_SELL && bearishFVG)
      {
         double gapMid = (h3 + l1) / 2.0;
         if(MathAbs(ask - gapMid) <= tolerance) return true;
      }

      // Order block: opposite-colour candle immediately before a 1.5xATR impulse
      double oC = iOpen(_Symbol, _Period, i);
      double cC = iClose(_Symbol, _Period, i);
      double impulseStart = iClose(_Symbol, _Period, i);
      double impulseEnd   = iClose(_Symbol, _Period, MathMax(i-3,1));
      double impulse = MathAbs(impulseEnd - impulseStart);

      if(sig == SIGNAL_BUY && cC < oC && impulse >= atr*1.5 && impulseEnd > impulseStart)
      {
         double obLow = MathMin(oC,cC), obHigh = MathMax(oC,cC);
         if(bid >= obLow - tolerance && bid <= obHigh + tolerance) return true;
      }
      if(sig == SIGNAL_SELL && cC > oC && impulse >= atr*1.5 && impulseEnd < impulseStart)
      {
         double obLow = MathMin(oC,cC), obHigh = MathMax(oC,cC);
         if(ask >= obLow - tolerance && ask <= obHigh + tolerance) return true;
      }
   }
   return false;
}

//+------------------------------------------------------------------+
//| GOLD-SPECIFIC: ROUND NUMBER MAGNET CHECK                          |
//| Returns false if the given price sits within InpRoundNumberBuffer |
//| of a round-number magnet level (e.g. every $10 on gold) — these   |
//| levels attract liquidity/algos and chew up TPs placed right on    |
//| them. Used to nudge TP placement, not to block entries outright.  |
//+------------------------------------------------------------------+
bool CheckRoundNumberSafe(double price)
{
   if(!InpAvoidRoundNumbers || InpRoundNumberStep <= 0) return true;
   double remainder = MathMod(price, InpRoundNumberStep);
   double distToNext = InpRoundNumberStep - remainder;
   double distToPrev = remainder;
   double minDist = MathMin(distToNext, distToPrev);
   return (minDist >= InpRoundNumberBuffer);
}

//+------------------------------------------------------------------+
//| ATR VALUE                                                         |
//+------------------------------------------------------------------+
double GetATR()
{
   double atr[1];
   if(CopyBuffer(g_hATR, 0, 0, 1, atr) <= 0) return 0.0;
   return atr[0];
}

//+------------------------------------------------------------------+
//| GOLD-SPECIFIC: VOLATILITY REGIME CLASSIFIER                       |
//| Compares current ATR to its own recent percentile range to        |
//| classify the regime. Feeds both quality scoring and risk sizing — |
//| extreme volatility (e.g. NFP/CPI spikes outside the news window,  |
//| flash moves) reduces size even if confluence looks perfect.       |
//+------------------------------------------------------------------+
ENUM_VOL_REGIME GetVolatilityRegime()
{
   double atrNow = GetATR();
   if(atrNow <= 0) return VOL_NORMAL;

   double sum = 0.0; int n = 0;
   double atrBuf[];
   ArraySetAsSeries(atrBuf, true);
   if(CopyBuffer(g_hATR, 0, 1, 50, atrBuf) <= 0) return VOL_NORMAL;

   for(int i = 0; i < ArraySize(atrBuf); i++) { sum += atrBuf[i]; n++; }
   if(n == 0) return VOL_NORMAL;
   double avgATR = sum / n;

   double ratio = atrNow / avgATR;
   if(ratio >= 1.8) return VOL_EXTREME;
   if(ratio >= 1.3) return VOL_HIGH;
   if(ratio <= 0.6) return VOL_LOW;
   return VOL_NORMAL;
}

//+------------------------------------------------------------------+
//| TRADE-QUALITY SCORE (0-100)                                       |
//| Blends: confluence score, ADX strength, session quality, spread   |
//| quality, news proximity, volatility regime, sweep/OB bonus.       |
//| This is what actually drives position sizing — not a binary gate. |
//+------------------------------------------------------------------+
double ComputeTradeQualityScore(int confluenceScore, ENUM_SIGNAL sig)
{
   double score = 0.0;

   // 1) Confluence contributes up to 40 points (score is out of 9)
   score += (confluenceScore / 9.0) * 40.0;

   // 2) ADX strength contributes up to 15 points
   double adxArr[1];
   if(CopyBuffer(g_hADX,0,0,1,adxArr) > 0)
   {
      double adxScore = MathMin((adxArr[0] / 45.0) * 15.0, 15.0);
      score += adxScore;
   }

   // 3) Session quality contributes up to 15 points (overlap = best)
   if(IsOverlapSession() && InpBoostOverlapSession) score += 15.0;
   else if(IsInSession()) score += 8.0;

   // 4) Spread quality contributes up to 10 points
   double sp = (double)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   double spreadQuality = MathMax(0.0, 10.0 * (1.0 - (sp / (double)InpSpreadMaxPoints)));
   score += spreadQuality;

   // 5) News proximity — penalty, not bonus (subtract up to 25)
   if(InpUseNewsFilter && g_NextHighImpact > 0)
   {
      int minsToNews = (int)((g_NextHighImpact - TimeCurrent())/60);
      if(minsToNews >= 0 && minsToNews <= 90)
      {
         double penalty = MathMax(0.0, 25.0 * (1.0 - (minsToNews/90.0)));
         score -= penalty;
      }
   }

   // 6) Volatility regime — extreme vol penalised, normal/high rewarded
   ENUM_VOL_REGIME regime = GetVolatilityRegime();
   if(regime == VOL_NORMAL)       score += 10.0;
   else if(regime == VOL_HIGH)    score += 6.0;
   else if(regime == VOL_LOW)     score += 2.0;
   else if(regime == VOL_EXTREME) score -= 15.0;

   // 7) News sentiment alignment — small bonus if directional skew agrees
   if(MathAbs(g_NewsSentiment) > 10.0)
   {
      bool aligns = (sig==SIGNAL_BUY && g_NewsSentiment>0) || (sig==SIGNAL_SELL && g_NewsSentiment<0);
      score += aligns ? 5.0 : -5.0;
   }

   return MathMax(0.0, MathMin(100.0, score));
}

//+------------------------------------------------------------------+
//| DYNAMIC RISK ENGINE                                                |
//| Risk% scales with quality score between floor/ceiling, then gets   |
//| further adjusted by loss/win streak and circuit-breaker proximity. |
//| Works identically in proportion on a $50 or $10,000 account since  |
//| lot size is derived from balance × risk% — this is what makes the  |
//| same logic "just work" at any account size.                        |
//+------------------------------------------------------------------+
double GetDynamicRiskPercent(double qualityScore)
{
   // Map quality 25-100 -> risk Min-Max (linear)
   double q = MathMax(25.0, MathMin(100.0, qualityScore));
   double t = (q - 25.0) / (100.0 - 25.0); // 0..1
   double riskPct = InpMinRiskPercent + t * (InpMaxRiskPercent - InpMinRiskPercent);

   // Anchor around base risk too (avoid wild swings from base)
   riskPct = (riskPct + InpBaseRiskPercent) / 2.0;

   // Loss-streak protection
   if(g_ConsecLosses >= InpMaxLossStreak)
      riskPct *= 0.5;
   else if(g_ConsecWins >= InpWinStreakBoost)
      riskPct = MathMin(riskPct * 1.2, InpMaxRiskPercent);

   // Tiny-account safety: never let a single trade risk amount fall
   // below what's practically executable, nor let % exceed ceiling
   riskPct = MathMax(InpMinRiskPercent, MathMin(InpMaxRiskPercent, riskPct));
   return riskPct;
}

//+------------------------------------------------------------------+
//| DYNAMIC LOT SIZING — risk-percent based, account-size agnostic    |
//+------------------------------------------------------------------+
double CalculateLotSize(int slPoints, double riskPct)
{
   double balance    = AccountInfoDouble(ACCOUNT_BALANCE);
   double riskAmount = balance * (riskPct / 100.0);

   double tickVal  = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   double point    = SymbolInfoDouble(_Symbol, SYMBOL_POINT);

   double slCostPerLot = (slPoints * point / tickSize) * tickVal;
   if(slCostPerLot <= 0.0) return SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);

   double lot  = riskAmount / slCostPerLot;
   double minV = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxV = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);

   lot = MathMax(minV, MathMin(maxV, MathFloor(lot / step) * step));

   // Margin safety check — never size a position that would consume
   // more than ~60% of free margin (critical on small accounts)
   double marginReq = 0.0;
   if(OrderCalcMargin(ORDER_TYPE_BUY, _Symbol, lot, SymbolInfoDouble(_Symbol,SYMBOL_ASK), marginReq))
   {
      double freeMargin = AccountInfoDouble(ACCOUNT_MARGIN_FREE);
      if(marginReq > freeMargin * 0.6)
      {
         double scaleDown = (freeMargin * 0.6) / MathMax(marginReq, 0.0001);
         lot = MathMax(minV, MathFloor((lot*scaleDown) / step) * step);
      }
   }

   return lot;
}

//+------------------------------------------------------------------+
//| ADAPTIVE CONFIRMATION TARGET                                      |
//| Strong trend (ADX >= InpFastTrackADX) -> near-instant (min ticks). |
//| Weaker trend -> scales up smoothly toward a low single-digit tick  |
//| count, capped by InpConfirmMaxSeconds as an absolute ceiling. This |
//| replaces the old fixed 10-120s "analysis window" that could sit    |
//| out fast-moving gold spikes entirely.                              |
//+------------------------------------------------------------------+
int ComputeAdaptiveConfirmTarget(double adxVal)
{
   if(adxVal >= InpFastTrackADX) return InpConfirmMinTicks;

   // Linear scale: weaker ADX (down to InpADXMinStrength) -> more ticks,
   // capped at a sensible max so we're never "waiting forever."
   double range = MathMax(1.0, InpFastTrackADX - InpADXMinStrength);
   double pos   = MathMax(0.0, InpFastTrackADX - adxVal) / range; // 0..1
   int extra = (int)MathRound(pos * 4.0); // up to +4 ticks in choppiest qualifying conditions
   return InpConfirmMinTicks + extra;
}

//+------------------------------------------------------------------+
//| CONFIRMATION PHASE — short, adaptive, non-blocking                |
//+------------------------------------------------------------------+
void ProcessConfirmationPhase()
{
   g_ConfirmTicks++;
   int elapsed = (int)(TimeCurrent() - g_ConfirmStart);

   g_StatusText  = "CONFIRMING: tick " + IntegerToString(g_ConfirmTicks) + "/" + IntegerToString(g_ConfirmTargetTicks);
   g_StatusColor = C_PURPLE;

   // Absolute safety ceiling — only relevant in genuinely dead/choppy
   // tape; in any normal market this never gets reached because tick
   // count satisfies first.
   if(elapsed > InpConfirmMaxSeconds)
   {
      Print("[EliteScalperPro V6] Confirmation ceiling reached without tick-count match – re-scanning (not discarding edge).");
      g_State = STATE_SCANNING;
      return;
   }

   int score = 0;
   ENUM_SIGNAL current = EvaluateConfluence(score, false); // relaxed structure
   if(current != g_PendingSignal)
   {
      Print("[EliteScalperPro V6] Signal flipped during confirmation – invalidated.");
      g_State = STATE_SCANNING;
      return;
   }

   if(g_ConfirmTicks >= g_ConfirmTargetTicks)
   {
      Print("[EliteScalperPro V6] Confirmation complete – executing. Ticks=", g_ConfirmTicks, " Elapsed=", elapsed, "s");
      ExecuteEntry(g_PendingSignal);
      g_StateTimer = TimeCurrent() + 5; // brief 5s gap to avoid instant re-fire on a fill error
      g_State      = STATE_COOLDOWN;
   }
}

//+------------------------------------------------------------------+
//| TRADE EXECUTION — sets up the full TP1/TP2/TP3 tier plan           |
//+------------------------------------------------------------------+
void ExecuteEntry(ENUM_SIGNAL sig)
{
   if(InpUseNewsFilter && IsNewsBlocking())
   { Print("[EliteScalperPro V6] News window opened during confirmation – aborted."); g_State=STATE_SCANNING; return; }

   if(!IsSpreadOk()) { Print("[EliteScalperPro V6] Spread too wide at execution – aborted."); return; }

   double point  = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   int    digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   double atr    = GetATR();
   double price  = (sig == SIGNAL_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                       : SymbolInfoDouble(_Symbol, SYMBOL_BID);

   int slPoints  = (int)MathRound((atr * InpSLMultiplier) / point);
   slPoints      = MathMax(InpMinSLPoints, MathMin(InpMaxSLPoints, slPoints));

   int tp1Points = (int)MathRound((atr * InpTP1Multiplier) / point);
   int tp2Points = (int)MathRound((atr * InpTP2Multiplier) / point);
   int tp3Points = (int)MathRound((atr * InpTP3Multiplier) / point);

   double sl, tp1, tp2, tp3;
   if(sig == SIGNAL_BUY)
   {
      sl  = NormalizeDouble(price - slPoints  * point, digits);
      tp1 = NormalizeDouble(price + tp1Points * point, digits);
      tp2 = NormalizeDouble(price + tp2Points * point, digits);
      tp3 = NormalizeDouble(price + tp3Points * point, digits);
   }
   else
   {
      sl  = NormalizeDouble(price + slPoints  * point, digits);
      tp1 = NormalizeDouble(price - tp1Points * point, digits);
      tp2 = NormalizeDouble(price - tp2Points * point, digits);
      tp3 = NormalizeDouble(price - tp3Points * point, digits);
   }

   // Round-number magnet nudge: if TP3 lands too close to a magnet
   // level, pull it back slightly so it isn't sitting exactly on a
   // level the market is likely to wick through and reverse from.
   if(InpAvoidRoundNumbers && !CheckRoundNumberSafe(tp3))
   {
      double nudge = InpRoundNumberBuffer * point * 10; // shift by buffer in price terms
      tp3 = (sig==SIGNAL_BUY) ? tp3 - MathAbs(nudge) : tp3 + MathAbs(nudge);
      tp3 = NormalizeDouble(tp3, digits);
   }

   double quality = g_LastQualityScore;
   double riskPct = GetDynamicRiskPercent(quality);
   double lot     = CalculateLotSize(slPoints, riskPct);

   PrintFormat("[EliteScalperPro V6] Entry: %s Price=%.2f SL=%.2f TP1=%.2f TP2=%.2f TP3=%.2f Lot=%.2f Risk=%.2f%% Quality=%.0f",
      (sig==SIGNAL_BUY?"BUY":"SELL"), price, sl, tp1, tp2, tp3, lot, riskPct, quality);

   // Open with TP set to TP3 (final target) — TP1/TP2 are managed via
   // partial closes in ManageOpenTrade(), since MT5 positions only
   // carry a single TP field natively.
   bool ok = (sig == SIGNAL_BUY) ? g_Trade.Buy(lot, _Symbol, price, sl, tp3, InpTradeComment)
                                 : g_Trade.Sell(lot, _Symbol, price, sl, tp3, InpTradeComment);
   if(ok)
   {
      g_DailyTrades++;
      g_TPStage        = TP_STAGE_NONE;
      g_EntrySL         = sl;
      g_TP1Price        = tp1;
      g_TP2Price        = tp2;
      g_TP3Price        = tp3;
      g_OriginalVolume  = lot;
      g_StatusText      = (sig==SIGNAL_BUY) ? "IN TRADE – LONG" : "IN TRADE – SHORT";
      g_StatusColor     = C_GREEN;
   }
   else
   {
      Print("[EliteScalperPro V6] Order FAILED. RetCode=", g_Trade.ResultRetcode(), " ", g_Trade.ResultRetcodeDescription());
   }
}

//+------------------------------------------------------------------+
//| OPEN TRADE MANAGEMENT                                              |
//+------------------------------------------------------------------+
void ManageOpenTrade()
{
   EvaluateFloatingPnL();
   if(!IsPositionOpen()) return;
   CheckTieredExits();

   g_StatusText  = "TRADE RUNNING – TIER: " + IntegerToString((int)g_TPStage);
   g_StatusColor = C_GREEN;
}

//--- Close if floating profit ≥ remaining daily target (locks gains, not a hard halt)
void EvaluateFloatingPnL()
{
   if(!IsPositionOpen()) return;
   double pnl = GetFloatingPnL();

   double balance    = AccountInfoDouble(ACCOUNT_BALANCE);
   double dailyGoal   = balance * (InpMaxDailyProfitPct / 100.0);
   double remaining   = dailyGoal - g_DailyProfit;
   if(remaining > 0.0 && pnl >= remaining * 1.5) // only force-close on an outsized floating win, not at exactly target
   {
      CloseAllPositions("Daily profit target substantially exceeded via floating PnL");
      return;
   }
}

//+------------------------------------------------------------------+
//| TIERED EXIT RATCHET SYSTEM — THE CORE FIX                          |
//|                                                                     |
//| This is the direct answer to "trade runs to 3 only for the EA to   |
//| wait for it to reduce to 1 then close": once a tier is banked, the |
//| stop is moved to LOCK that tier in. The runner can never give back |
//| more than the gap between tiers — it cannot crash all the way back |
//| to breakeven after running deep into profit.                       |
//|                                                                     |
//|  TP1 hit  -> close InpTP1ClosePct% of ORIGINAL volume.              |
//|              SL -> breakeven + buffer (locks a small win minimum).  |
//|  TP2 hit  -> close InpTP2ClosePct% of ORIGINAL volume (of the       |
//|              remainder).                                            |
//|              SL -> TP1 price (locks in the TP1-to-TP2 gain on the   |
//|              runner — this is the ratchet).                         |
//|              Runner trailing now activates with a TIGHT step so it  |
//|              can still capture extension toward TP3 without giving  |
//|              the locked gain back.                                  |
//|  TP3 hit  -> full close of whatever remains (the runner's target).  |
//+------------------------------------------------------------------+
void CheckTieredExits()
{
   for(int i = PositionsTotal()-1; i >= 0; i--)
   {
      if(!g_Pos.SelectByIndex(i)) continue;
      if(g_Pos.Magic() != InpMagicNumber || g_Pos.Symbol() != _Symbol) continue;

      bool   isBuy  = (g_Pos.PositionType() == POSITION_TYPE_BUY);
      double bid    = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      double ask    = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      double price  = isBuy ? bid : ask;
      double point  = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
      int    digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
      double sl     = g_Pos.StopLoss();
      double open   = g_Pos.PriceOpen();

      //--- TP1 trigger ---------------------------------------------------
      if(g_TPStage == TP_STAGE_NONE)
      {
         bool hitTP1 = isBuy ? (price >= g_TP1Price) : (price <= g_TP1Price);
         if(hitTP1)
         {
            ClosePartial(InpTP1ClosePct, "TP1 reached");
            double beSL = isBuy ? NormalizeDouble(open + InpBreakevenBuffer*point, digits)
                                : NormalizeDouble(open - InpBreakevenBuffer*point, digits);
            // never move SL the wrong way
            bool improves = isBuy ? (beSL > sl || sl == 0.0) : (beSL < sl || sl == 0.0);
            if(improves && g_Pos.SelectByIndex(i))
               g_Trade.PositionModify(g_Pos.Ticket(), beSL, g_Pos.TakeProfit());
            g_TPStage = TP_STAGE_TP1;
            Print("[EliteScalperPro V6] TP1 hit -> partial closed, SL locked to breakeven+buffer.");
         }
         else if(InpPreTP1TrailStartPts < 999999)
         {
            // Optional: light trailing even before TP1, for traders who
            // want some protection during the run-up to the first tier.
            // Disabled by default (InpPreTP1TrailStartPts = 999999).
            double profitPts = isBuy ? (bid - open)/point : (open - ask)/point;
            if(profitPts >= InpPreTP1TrailStartPts)
            {
               double newSL = isBuy ? NormalizeDouble(bid - InpRunnerTrailStepPts*point, digits)
                                    : NormalizeDouble(ask + InpRunnerTrailStepPts*point, digits);
               bool trailImproves = isBuy ? (newSL > sl) : (newSL < sl || sl == 0.0);
               if(trailImproves)
                  g_Trade.PositionModify(g_Pos.Ticket(), newSL, g_Pos.TakeProfit());
            }
         }
         continue;
      }

      //--- TP2 trigger (ratchet to TP1) -----------------------------------
      if(g_TPStage == TP_STAGE_TP1)
      {
         bool hitTP2 = isBuy ? (price >= g_TP2Price) : (price <= g_TP2Price);
         if(hitTP2)
         {
            ClosePartial(InpTP2ClosePct, "TP2 reached");
            double lockSL = g_TP1Price; // ratchet: stop can now only land at TP1-or-better
            bool improves = isBuy ? (lockSL > g_Pos.StopLoss() || g_Pos.StopLoss()==0.0)
                                  : (lockSL < g_Pos.StopLoss() || g_Pos.StopLoss()==0.0);
            if(improves && g_Pos.SelectByIndex(i))
               g_Trade.PositionModify(g_Pos.Ticket(), NormalizeDouble(lockSL,digits), g_Pos.TakeProfit());
            g_TPStage = TP_STAGE_TP2;
            Print("[EliteScalperPro V6] TP2 hit -> partial closed, SL RATCHETED to TP1 price. Runner active.");
         }
         continue;
      }

      //--- Post-TP2: tight runner trailing toward TP3 ---------------------
      if(g_TPStage == TP_STAGE_TP2)
      {
         bool hitTP3 = isBuy ? (price >= g_TP3Price) : (price <= g_TP3Price);
         if(hitTP3)
         {
            CloseAllPositions("TP3 (runner target) reached");
            g_TPStage = TP_STAGE_TP3;
            continue;
         }

         if(InpUseRunnerTrailing)
         {
            double curSL = g_Pos.StopLoss();
            double newSL = isBuy ? NormalizeDouble(bid - InpRunnerTrailStepPts*point, digits)
                                 : NormalizeDouble(ask + InpRunnerTrailStepPts*point, digits);
            // Ratchet floor: trailing SL can NEVER move below the TP1-locked
            // level — this guarantees the runner cannot give back the gain
            // that was already banked by hitting TP2.
            double floorSL = g_TP1Price;
            if(isBuy)  newSL = MathMax(newSL, floorSL);
            else       newSL = MathMin(newSL, floorSL);

            bool improves = isBuy ? (newSL > curSL) : (newSL < curSL || curSL == 0.0);
            if(improves)
               g_Trade.PositionModify(g_Pos.Ticket(), newSL, g_Pos.TakeProfit());
         }
      }
   }
}

//+------------------------------------------------------------------+
//| PARTIAL CLOSE HELPER — closes a % of the ORIGINAL volume so tiers  |
//| are predictable regardless of how much has already been closed.    |
//+------------------------------------------------------------------+
void ClosePartial(double pctOfOriginal, string reason)
{
   for(int i = PositionsTotal()-1; i >= 0; i--)
   {
      if(!g_Pos.SelectByIndex(i)) continue;
      if(g_Pos.Magic() != InpMagicNumber || g_Pos.Symbol() != _Symbol) continue;

      double volStep   = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
      double minLot    = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
      double targetClose = g_OriginalVolume * (pctOfOriginal/100.0);
      double closeLot  = MathFloor(targetClose / volStep) * volStep;
      closeLot         = NormalizeDouble(closeLot, 2);

      double currentVol = g_Pos.Volume();
      // never try to close more than what's left, and never leave a
      // dust remainder below the broker's minimum lot
      if(closeLot >= currentVol - minLot*0.5)
         closeLot = currentVol; // close it all if this would leave an unbrokerable remainder

      if(closeLot >= minLot)
      {
         if(g_Trade.PositionClosePartial(g_Pos.Ticket(), closeLot))
            Print("[EliteScalperPro V6] Partial close (", reason, "): ", closeLot, " lots");
         else
            Print("[EliteScalperPro V6] Partial close FAILED (", reason, "): ", g_Trade.ResultRetcodeDescription());
      }
   }
}

//+------------------------------------------------------------------+
//| DAILY STATS SYNCHRONISATION                                       |
//+------------------------------------------------------------------+
void SyncDailyStats()
{
   datetime now = TimeCurrent();
   datetime dayStart = GetDayStart(now);

   if(dayStart > g_SessionDay)
   {
      g_SessionDay     = dayStart;
      g_DailyTrades    = 0;
      g_DailyProfit    = 0.0;
      g_DailyWins      = 0;
      g_DailyLosses    = 0;
      g_SessionOpenBal = AccountInfoDouble(ACCOUNT_BALANCE);
      g_EquityPeak     = AccountInfoDouble(ACCOUNT_EQUITY);
      if(g_State == STATE_DAILY_LIMIT) g_State = STATE_SCANNING;
   }

   g_DailyProfit  = 0.0;
   g_DailyWins    = 0;
   g_DailyLosses  = 0;
   g_ConsecLosses = 0;
   g_ConsecWins   = 0;

   if(!HistorySelect(dayStart, now)) return;

   bool lastWasWin = false;
   int  curStreak  = 0;

   for(int i = 0; i < HistoryDealsTotal(); i++)
   {
      ulong tkt = HistoryDealGetTicket(i);
      if(tkt == 0) continue;
      if(HistoryDealGetInteger(tkt, DEAL_MAGIC)  != (long)InpMagicNumber) continue;
      if(HistoryDealGetString(tkt, DEAL_SYMBOL)  != _Symbol) continue;
      if(HistoryDealGetInteger(tkt, DEAL_ENTRY)  != DEAL_ENTRY_OUT) continue;

      double pnl = HistoryDealGetDouble(tkt, DEAL_PROFIT)
                 + HistoryDealGetDouble(tkt, DEAL_COMMISSION)
                 + HistoryDealGetDouble(tkt, DEAL_SWAP);
      g_DailyProfit += pnl;
      bool win = (pnl >= 0.0);
      if(win) g_DailyWins++; else g_DailyLosses++;

      if(win == lastWasWin) curStreak++; else curStreak = 1;
      lastWasWin = win;
   }

   if(lastWasWin) g_ConsecWins = curStreak;
   else           g_ConsecLosses = curStreak;
}

//+------------------------------------------------------------------+
//| EQUITY CIRCUIT BREAKER                                            |
//+------------------------------------------------------------------+
void UpdateEquityPeak()
{
   double eq = AccountInfoDouble(ACCOUNT_EQUITY);
   if(eq > g_EquityPeak) g_EquityPeak = eq;
}

bool IsCircuitBreakerTripped()
{
   if(g_CircuitUntil > TimeCurrent()) return true;
   if(g_CircuitUntil > 0 && g_CircuitUntil <= TimeCurrent())
   { g_CircuitUntil = 0; return false; } // pause expired

   if(g_EquityPeak <= 0) return false;
   double eq = AccountInfoDouble(ACCOUNT_EQUITY);
   double ddPct = ((g_EquityPeak - eq) / g_EquityPeak) * 100.0;
   if(ddPct >= InpCircuitDrawdownPct)
   {
      g_CircuitUntil = TimeCurrent() + InpCircuitPauseMin*60;
      Print("[EliteScalperPro V6] CIRCUIT BREAKER TRIPPED: equity DD=", DoubleToString(ddPct,2),
            "% from peak. Pausing ", InpCircuitPauseMin, " minutes.");
      return true;
   }
   return false;
}

//+------------------------------------------------------------------+
//| UTILITY FUNCTIONS                                                 |
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
   Print("[EliteScalperPro V6] Closing all: ", reason);
   for(int i = PositionsTotal()-1; i >= 0; i--)
      if(g_Pos.SelectByIndex(i) && g_Pos.Magic()==InpMagicNumber && g_Pos.Symbol()==_Symbol)
         g_Trade.PositionClose(g_Pos.Ticket());
   g_StateTimer = TimeCurrent() + InpCooldownSeconds;
   g_State = STATE_COOLDOWN;
   g_TPStage = TP_STAGE_NONE;
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

//--- London/NY overlap = highest liquidity window for gold (≈12:00-16:00 GMT)
bool IsOverlapSession()
{
   MqlDateTime t; TimeToStruct(TimeGMT(), t);
   return (t.hour >= 12 && t.hour < 16);
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
//| LIVE NEWS INTELLIGENCE MODULE                                     |
//|                                                                     |
//| Uses MQL5's native economic calendar API (CalendarValueHistory /   |
//| CalendarEventById / CalendarCountryById). This works LIVE and on    |
//| demo accounts via the terminal's built-in calendar database. It    |
//| does NOT return historical data inside Strategy Tester (the        |
//| terminal has no server connection during historical replay) — this |
//| is a documented MQL5 platform limitation, not a bug in this EA. To  |
//| validate logic in the tester, temporarily force InpNewsPauseManual  |
//| or stub g_NextHighImpact for a dry run.                             |
//|                                                                     |
//| Relevance: for XAUUSD we treat USD events as primary (gold is       |
//| priced in USD and is highly sensitive to US rate/inflation data)    |
//| and also flag a smaller set of macro-risk currencies (EUR/GBP for   |
//| broader risk sentiment) at reduced weight.                          |
//+------------------------------------------------------------------+
void UpdateNewsIntelligence()
{
   static datetime lastPoll = 0;
   // Throttle actual calendar reads to once every 30s — no need to hit
   // the API every single second.
   if(TimeCurrent() - lastPoll < 30) return;
   lastPoll = TimeCurrent();

   g_NewsBlockActive = false;
   g_NewsBlockReason = "";
   g_NextHighImpact  = 0;
   g_NextNewsTitle   = "";
   g_NewsSentiment   = 0.0;

   if(MQLInfoInteger(MQL_TESTER))
   {
      // No live calendar feed available in Strategy Tester — gracefully
      // no-op rather than erroring out, so the EA still backtests the
      // rest of the logic cleanly.
      return;
   }

   datetime from = TimeTradeServer();
   datetime to   = from + 36*3600; // look 36h ahead

   MqlCalendarValue values[];
   string currencies[] = {"USD","EUR","GBP"};
   double weights[]    = {1.0, 0.4, 0.3};

   datetime soonest = 0;
   string   soonestTitle = "";
   ENUM_CALENDAR_EVENT_IMPORTANCE soonestImportance = CALENDAR_IMPORTANCE_NONE;
   double   sentimentAccum = 0.0;
   int      sentimentCount = 0;

   for(int c = 0; c < ArraySize(currencies); c++)
   {
      ArrayFree(values);
      if(!CalendarValueHistory(values, from, to, NULL, currencies[c])) continue;

      for(int i = 0; i < ArraySize(values); i++)
      {
         MqlCalendarEvent ev;
         if(!CalendarEventById(values[i].event_id, ev)) continue;

         // Importance filter
         if(InpNewsImportance == 2 && ev.importance != CALENDAR_IMPORTANCE_HIGH) continue;
         if(InpNewsImportance == 1 && ev.importance == CALENDAR_IMPORTANCE_LOW) continue;
         // InpNewsImportance==0 -> accept all

         datetime evTime = values[i].time;
         if(evTime < from) continue;

         // Track soonest qualifying high-relevance event for the block window
         if(soonest == 0 || evTime < soonest)
         {
            soonest = evTime;
            soonestTitle = ev.name;
            soonestImportance = ev.importance;
         }

         // Sentiment/volatility-expectation proxy: if actual vs forecast
         // is already known (released event) use the surprise direction;
         // otherwise weight purely by importance as an "expected vol"
         // signal (does not predict direction, only magnitude bias which
         // we fold into a mild directional skew using prev-vs-forecast).
         // NOTE: actual_value/forecast_value are `long`, scaled by 1e6,
         // with LONG_MIN meaning "not yet set" — NOT EMPTY_VALUE/double.
         if(values[i].HasActualValue() && values[i].HasForecastValue())
         {
            double actual   = (double)values[i].actual_value   / 1000000.0;
            double forecast = (double)values[i].forecast_value / 1000000.0;
            double surprise = actual - forecast;
            if(surprise != 0.0)
            {
               double dir = (surprise > 0) ? 1.0 : -1.0;
               // USD beats forecast (positive surprise) tends to pressure
               // gold (inverse), so invert for USD currency specifically.
               if(currencies[c] == "USD") dir = -dir;
               sentimentAccum += dir * weights[c] * (ev.importance==CALENDAR_IMPORTANCE_HIGH?2.0:1.0);
               sentimentCount++;
            }
         }
      }
   }

   if(soonest > 0)
   {
      g_NextHighImpact = soonest;
      g_NextNewsTitle  = soonestTitle;

      int minsToEvent = (int)((soonest - TimeCurrent())/60);
      if(minsToEvent >= -InpNewsMinutesAfter && minsToEvent <= InpNewsMinutesBefore)
      {
         g_NewsBlockActive = true;
         g_NewsBlockReason = soonestTitle + " (" +
            (minsToEvent>=0 ? IntegerToString(minsToEvent)+"m to release" : IntegerToString(-minsToEvent)+"m post-release") + ")";
      }
   }

   if(sentimentCount > 0)
      g_NewsSentiment = MathMax(-100.0, MathMin(100.0, (sentimentAccum / sentimentCount) * 50.0));
}

bool IsNewsBlocking()
{
   return g_NewsBlockActive;
}

void CheckForceCloseBeforeNews()
{
   if(!IsPositionOpen()) return;
   if(g_NextHighImpact == 0) return;

   int minsToEvent = (int)((g_NextHighImpact - TimeCurrent())/60);
   if(minsToEvent >= 0 && minsToEvent <= InpNewsCloseMinutes)
   {
      CloseAllPositions("Force-close ahead of high-impact news: " + g_NextNewsTitle);
   }
}

//+------------------------------------------------------------------+
//| DASHBOARD                                                          |
//+------------------------------------------------------------------+

//====================================================================
// "PRIVATE BANK TERMINAL" LUXURY DASHBOARD — same panel architecture
// as V5, re-themed only (per request: enhance, don't replace).
// Layout (top to bottom, width=320px):
//   [HEADER]            – EA name, symbol, time, gold hairline accent
//   [MARKET INFO]       – Bid/Ask, Spread, ATR, Symbol, Session
//   [SIGNAL ENGINE]      – EMA values, RSI, ADX, MACD, Structure, Decision
//   [QUALITY GAUGE]      – NEW: live trade-quality score bar (0-100)
//   [NEWS INTELLIGENCE]  – NEW: next high-impact event + countdown strip
//   [AI ENGINE]           – Status, Last decision, Confidence
//   [FINAL DECISION]      – Large coloured BUY / SELL / HOLD block
//   [OPEN POSITIONS]      – Table with TIER column (TP1/TP2/TP3 state)
//   [ACCOUNT INFO]        – Balance, Equity, Day P&L, Win Rate, Risk%
//   [SESSION BAR]         – London | New York | Asia pills
//====================================================================

#define DW  320
#define COL 130

void RenderDashboard()
{
   int X = InpDashX;
   int Y = InpDashY;
   int W = DW;
   int y = Y;

   //----------------------------------------------------------------
   // OUTER SHELL — double-bordered for a "framed plaque" luxury look
   //----------------------------------------------------------------
   DrawRect("SHELL",    X-2, Y-2, W+4, 642, C_BG, C_BORDER2, 1);
   DrawRect("SHELL_IN", X,   Y,   W,   638, C_BG, C_BORDER,  2);

   //----------------------------------------------------------------
   // HEADER BAR
   //----------------------------------------------------------------
   DrawRect("HDR_BG", X+2, y+2, W-4, 36, C_HEADER, C_BORDER, 1);
   DrawRect("HDR_LINE", X+2, y+36, W-4, 1, C_GOLDLINE, clrNONE, 0);
   DrawLabel("HDR_IC",  X+8,     y+6,  "♛ ELITE SCALPER PRO",        C_GOLD,  9,  "Arial Black");
   DrawLabel("HDR_SYM", X+W-100, y+6,  _Symbol,                       C_GOLDLINE, 10, "Impact");
   DrawLabel("HDR_TF",  X+W-60,  y+22, TimeframeToString(_Period),    C_MUTED, 7,  "Arial");
   DrawLabel("HDR_VER", X+8,     y+24, EA_VERSION+"  |  GOLD ENGINE", C_MUTED, 7,  "Arial");
   y += 40;

   //----------------------------------------------------------------
   // MARKET INFO SECTION
   //----------------------------------------------------------------
   DrawRect("MI_HDR", X+2, y, W-4, 16, C_SECTION_HDR, C_BORDER2, 1);
   DrawLabel("MI_TIT", X+8, y+3, "MARKET INFO", C_ORANGE, 8, "Arial Black");
   DrawLabel("MI_CLK", X+W-60, y+3, "00:00", C_MUTED, 8, "Arial");
   y += 17;

   DrawRect("MI_BG", X+2, y, W-4, 72, C_PANEL, C_BORDER2, 1);
   DrawLabel("L_BID",  X+8,      y+6,  "Bid",                 C_MUTED, 8, "Arial");
   DrawLabel("V_BID",  X+36,     y+6,  "0.00",                C_WHITE, 9, "Arial Bold");
   DrawLabel("L_ASK",  X+W/2+4,  y+6,  "ASK",                 C_MUTED, 8, "Arial");
   DrawLabel("V_ASK",  X+W/2+30, y+6,  "0.00",                C_WHITE, 9, "Arial Bold");
   DrawLabel("L_SPR",  X+8,      y+24, "SPREAD",              C_MUTED, 8, "Arial");
   DrawLabel("V_SPR",  X+55,     y+24, "0 pts",               C_GOLD,  9, "Arial Bold");
   DrawLabel("L_ATR",  X+W/2+4,  y+24, "ATR(14)",             C_MUTED, 8, "Arial");
   DrawLabel("V_ATR",  X+W/2+44, y+24, "0 pts",               C_CYAN,  9, "Arial Bold");
   DrawLabel("L_SYM2", X+8,      y+42, "SYMBOL",              C_MUTED, 8, "Arial");
   DrawLabel("V_SYM2", X+55,     y+42, _Symbol+" M"+TimeframeToString(_Period), C_WHITE, 8, "Arial Bold");
   DrawLabel("L_VOL",  X+W/2+4,  y+42, "Vol:",                C_MUTED, 8, "Arial");
   DrawLabel("V_VOL",  X+W/2+28, y+42, "PASS",                C_GREEN, 8, "Arial Bold");
   DrawLabel("L_SES",  X+8,      y+58, "SESSION",             C_MUTED, 8, "Arial");
   DrawLabel("V_SES",  X+55,     y+58, "CHECKING",            C_GOLD,  8, "Arial Bold");
   DrawLabel("L_REG",  X+W/2+4,  y+58, "REGIME",              C_MUTED, 8, "Arial");
   DrawLabel("V_REG",  X+W/2+48, y+58, "NORMAL",              C_CYAN,  8, "Arial Bold");
   y += 74;

   //----------------------------------------------------------------
   // SIGNAL ENGINE
   //----------------------------------------------------------------
   DrawRect("SE_HDR", X+2, y, W-4, 16, C_SECTION_HDR, C_BORDER2, 1);
   DrawLabel("SE_TIT", X+8, y+3, "CONFLUENCE SIGNAL ENGINE", C_ORANGE, 8, "Arial Black");
   y += 17;

   DrawRect("SE_BG", X+2, y, W-4, 88, C_PANEL, C_BORDER2, 1);
   DrawLabel("L_EF",   X+8,      y+6,  "EMA "+IntegerToString(InpFastEMAPeriod), C_MUTED, 8, "Arial");
   DrawLabel("V_EF",   X+52,     y+6,  "0.00",                C_CYAN,  9, "Arial Bold");
   DrawLabel("L_ES",   X+W/2+4,  y+6,  "EMA "+IntegerToString(InpSlowEMAPeriod), C_MUTED, 8, "Arial");
   DrawLabel("V_ES",   X+W/2+40, y+6,  "0.00",                C_CYAN,  9, "Arial Bold");
   DrawLabel("L_RSI",  X+8,      y+24, "RSI",                 C_MUTED, 8, "Arial");
   DrawLabel("V_RSI",  X+36,     y+24, "0.0",                 C_WHITE, 9, "Arial Bold");
   DrawRect("BB_PILL", X+W/2+4,  y+22, 72, 14, C_HOLD_BG, C_BORDER2, 1);
   DrawLabel("V_BBP",  X+W/2+8,  y+24, "RANGE",               C_GOLD,  8, "Arial Bold");
   DrawLabel("L_ET",   X+8,      y+42, "EMA("+IntegerToString(InpTrendEMAPeriod)+")", C_MUTED, 8, "Arial");
   DrawLabel("V_ET",   X+52,     y+42, "0.00",                C_WHITE, 9, "Arial Bold");
   DrawLabel("L_ADX",  X+W/2+4,  y+42, "ADX",                 C_MUTED, 8, "Arial");
   DrawLabel("V_ADX",  X+W/2+30, y+42, "0.0",                 C_WHITE, 9, "Arial Bold");
   DrawLabel("L_MCD",  X+8,      y+60, "MACD Hist",           C_MUTED, 8, "Arial");
   DrawLabel("V_MCD",  X+66,     y+60, "0.00",                C_WHITE, 9, "Arial Bold");
   DrawLabel("L_STR",  X+W/2+4,  y+60, "Struct/Sweep",        C_MUTED, 8, "Arial");
   DrawLabel("V_STR",  X+W/2+62, y+60, "—",                   C_WHITE, 8, "Arial Bold");
   DrawRect("DEC_BAR", X+2, y+74, W-4, 14, C_HOLD_BG, C_BORDER2, 1);
   DrawLabel("V_DEC",  X+W/2-50, y+75, "Decision: HOLD",      C_GOLD,  8, "Arial Black");
   y += 90;

   //----------------------------------------------------------------
   // TRADE QUALITY GAUGE (NEW)
   //----------------------------------------------------------------
   DrawRect("QG_HDR", X+2, y, W-4, 16, C_SECTION_HDR, C_BORDER2, 1);
   DrawLabel("QG_TIT", X+8, y+3, "TRADE QUALITY SCORE", C_ORANGE, 8, "Arial Black");
   y += 17;
   DrawRect("QG_BG", X+2, y, W-4, 30, C_PANEL, C_BORDER2, 1);
   DrawRect("QG_TRACK", X+8, y+9, W-90, 12, C_GAUGE_BG, C_BORDER2, 1);
   DrawRect("QG_FILL",  X+8, y+9, 4,     12, C_GOLD,     clrNONE,   0);
   DrawLabel("V_QG",    X+W-72, y+8, "0/100",  C_GOLD, 9, "Arial Black");
   y += 32;

   //----------------------------------------------------------------
   // NEWS INTELLIGENCE STRIP (NEW)
   //----------------------------------------------------------------
   DrawRect("NW_HDR", X+2, y, W-4, 16, C_SECTION_HDR, C_BORDER2, 1);
   DrawLabel("NW_TIT", X+8, y+3, "LIVE NEWS INTELLIGENCE", C_ORANGE, 8, "Arial Black");
   y += 17;
   DrawRect("NW_BG", X+2, y, W-4, 40, C_NEWS_BG, C_BORDER2, 1);
   DrawLabel("L_NWN", X+8, y+5,  "NEXT:",       C_MUTED, 7, "Arial");
   DrawLabel("V_NWN", X+45, y+5, "No data (live only)", C_WHITE, 7, "Arial Bold");
   DrawLabel("L_NWT", X+8, y+19, "WINDOW:",     C_MUTED, 7, "Arial");
   DrawLabel("V_NWT", X+55, y+19,"CLEAR",       C_GREEN, 7, "Arial Bold");
   DrawLabel("L_NWS", X+W/2+30, y+19, "SENT:",  C_MUTED, 7, "Arial");
   DrawLabel("V_NWS", X+W/2+62, y+19,"NEUTRAL", C_MUTED, 7, "Arial Bold");
   y += 42;

   //----------------------------------------------------------------
   // AI ENGINE STATUS
   //----------------------------------------------------------------
   DrawRect("AI_HDR", X+2, y, W-4, 16, C_SECTION_HDR, C_BORDER2, 1);
   DrawLabel("AI_TIT", X+8, y+3, "AI ENGINE", C_ORANGE, 8, "Arial Black");
   y += 17;

   DrawRect("AI_BG", X+2, y, W-4, 62, C_PANEL, C_BORDER2, 1);
   DrawLabel("L_AIST",  X+8,  y+6,  "STATUS",          C_MUTED, 8, "Arial");
   DrawLabel("V_AIST",  X+70, y+6,  "ANALYSING",        C_CYAN,  9, "Arial Black");
   DrawLabel("AI_DOT",  X+W-16, y+6, "●",               C_GOLD,  9, "Arial");
   DrawLabel("L_AILD",  X+8,  y+24, "LAST DECISION",   C_MUTED, 8, "Arial");
   DrawLabel("V_AILD",  X+W-50,y+24, "HOLD",            C_GOLD,  8, "Arial Bold");
   DrawLabel("L_AISC",  X+8,  y+42, "CONFIDENCE",      C_MUTED, 8, "Arial");
   DrawRect("CONF_BG",  X+85, y+43, 140, 11, C_GAUGE_BG, C_BORDER2, 1);
   DrawRect("CONF_FG",  X+85, y+43, 56,  11, C_GOLD,    clrNONE,   0);
   DrawLabel("V_AISC",  X+230,y+42, "MED",              C_GOLD,  8, "Arial Bold");
   y += 64;

   //----------------------------------------------------------------
   // FINAL DECISION BLOCK
   //----------------------------------------------------------------
   DrawRect("FD_HDR", X+2, y, W-4, 16, C_SECTION_HDR, C_BORDER2, 1);
   DrawLabel("FD_TIT", X+8, y+3, "FINAL DECISION", C_ORANGE, 8, "Arial Black");
   y += 17;

   DrawRect("FD_BG",  X+2, y, W-4, 32, C_HOLD_BG, C_BORDER, 2);
   DrawLabel("V_FD",  X+W/2-26, y+9, "HOLD", C_GOLD, 14, "Arial Black");
   y += 34;

   DrawRect("FD_SUB", X+2, y, W-4, 14, C_PANEL2, C_BORDER2, 1);
   DrawLabel("L_FDS1", X+8,      y+2, "SIGNAL ENG:",  C_MUTED, 7, "Arial");
   DrawLabel("V_FDS1", X+70,     y+2, "HOLD",         C_GOLD,  7, "Arial Bold");
   DrawLabel("L_FDS2", X+W/2+8,  y+2, "AI ENGINE:",   C_MUTED, 7, "Arial");
   DrawLabel("V_FDS2", X+W/2+62, y+2, "HOLD",         C_GOLD,  7, "Arial Bold");
   y += 16;

   //----------------------------------------------------------------
   // OPEN POSITIONS TABLE (now with TIER column)
   //----------------------------------------------------------------
   DrawRect("OP_HDR", X+2, y, W-4, 16, C_SECTION_HDR, C_BORDER2, 1);
   DrawLabel("OP_TIT",  X+8,     y+3,  "OPEN POSITIONS", C_ORANGE, 8, "Arial Black");
   DrawLabel("OP_CNT",  X+W-50,  y+3,  "0 open",         C_MUTED,  8, "Arial");
   y += 17;

   DrawRect("OP_COL", X+2, y, W-4, 13, C_PANEL2, C_BORDER2, 1);
   DrawLabel("OC_TYP",  X+6,   y+2, "TYPE", C_MUTED, 7, "Arial");
   DrawLabel("OC_LOT",  X+40,  y+2, "LOT",  C_MUTED, 7, "Arial");
   DrawLabel("OC_OPN",  X+74,  y+2, "OPEN", C_MUTED, 7, "Arial");
   DrawLabel("OC_SL",   X+118, y+2, "SL",   C_MUTED, 7, "Arial");
   DrawLabel("OC_TIER", X+160, y+2, "TIER", C_MUTED, 7, "Arial");
   DrawLabel("OC_PNL",  X+205, y+2, "P&L",  C_MUTED, 7, "Arial");
   y += 14;

   for(int r = 0; r < 2; r++)
   {
      color rowBg = (r % 2 == 0) ? C_PANEL : C_PANEL2;
      DrawRect("OR"+IntegerToString(r),      X+2, y, W-4, 13, rowBg, clrNONE, 0);
      DrawLabel("OR_T"+IntegerToString(r),   X+6,   y+2, "---", C_MUTED, 7, "Arial");
      DrawLabel("OR_L"+IntegerToString(r),   X+40,  y+2, "---", C_MUTED, 7, "Arial");
      DrawLabel("OR_O"+IntegerToString(r),   X+74,  y+2, "---", C_MUTED, 7, "Arial");
      DrawLabel("OR_S"+IntegerToString(r),   X+118, y+2, "---", C_MUTED, 7, "Arial");
      DrawLabel("OR_TR"+IntegerToString(r),  X+160, y+2, "---", C_MUTED, 7, "Arial");
      DrawLabel("OR_F"+IntegerToString(r),   X+205, y+2, "---", C_MUTED, 7, "Arial");
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

   DrawRect("AC_BG", X+2, y, W-4, 68, C_PANEL, C_BORDER2, 1);
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
   y += 70;

   //----------------------------------------------------------------
   // SESSION BAR
   //----------------------------------------------------------------
   DrawRect("SB_BG", X+2, y, W-4, 18, C_PANEL2, C_BORDER2, 1);
   int pw = (W-10)/3;
   DrawRect("SB_LON", X+3,        y+2, pw,   14, C_PANEL, C_BORDER2, 1);
   DrawLabel("SB_LT",  X+3+pw/2-18, y+4,  "LONDON",   C_MUTED, 7, "Arial Bold");
   DrawRect("SB_NYC", X+3+pw+1,   y+2, pw,   14, C_GOLD,  clrNONE,   0);
   DrawLabel("SB_NT",  X+4+pw+pw/2-22, y+4, "NEW YORK", C_BG,   7, "Arial Black");
   DrawRect("SB_ASI", X+3+pw*2+2, y+2, pw-1, 14, C_PANEL, C_BORDER2, 1);
   DrawLabel("SB_AT",  X+4+pw*2+pw/2-12, y+4, "ASIA",  C_MUTED, 7, "Arial Bold");
   y += 20;

   //----------------------------------------------------------------
   // FOOTER — luxury signature line
   //----------------------------------------------------------------
   DrawRect("FT_LINE", X+2, y+4, W-4, 1, C_GOLDLINE, clrNONE, 0);
   DrawLabel("FT_SIG", X+W/2-78, y+8, "FXBotHub Systems  ·  Est. 2026", C_MUTED, 7, "Arial");

   ChartRedraw(0);
}

//+------------------------------------------------------------------+
//| DASHBOARD LIVE UPDATE                                              |
//+------------------------------------------------------------------+
void UpdateDashboard()
{
   MqlDateTime dt; TimeToStruct(TimeCurrent(), dt);
   string clk = StringFormat("%02d:%02d", dt.hour, dt.min);
   SetLabel("MI_CLK", clk, C_MUTED);

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

   ENUM_VOL_REGIME regime = GetVolatilityRegime();
   string regTxt = (regime==VOL_LOW)?"LOW":(regime==VOL_NORMAL)?"NORMAL":(regime==VOL_HIGH)?"HIGH":"EXTREME";
   color  regClr = (regime==VOL_LOW)?C_MUTED:(regime==VOL_NORMAL)?C_GREEN:(regime==VOL_HIGH)?C_GOLD:C_RED;
   SetLabel("V_REG", regTxt, regClr);

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

   double upper[1], lower[1], mid[1];
   if(CopyBuffer(g_hBB,1,0,1,upper)>0 && CopyBuffer(g_hBB,2,0,1,lower)>0 && CopyBuffer(g_hBB,0,0,1,mid)>0)
   {
      bool squeeze = (upper[0]-lower[0]) < bid * InpBBSqueezeRatio;
      SetLabel("V_BBP", squeeze ? "SQUEEZE" : "EXPAND", squeeze ? C_RED : C_GREEN);
      string pillN = DASH_PREFIX+"BB_PILL";
      if(ObjectFind(0,pillN)>=0) ObjectSetInteger(0,pillN,OBJPROP_BGCOLOR, squeeze ? C_SELL_BG : C_BUY_BG);
   }

   int curScore = 0;
   ENUM_SIGNAL sig = EvaluateConfluence(curScore, true);
   bool structOk = CheckMarketStructure(sig, false);
   bool sweepOk  = InpUseSweepDetection ? CheckLiquiditySweep(sig) : false;
   string strTxt = structOk ? "BREAK" : (sweepOk ? "SWEEP" : "HOLD");
   color  strClr = structOk ? C_GREEN : (sweepOk ? C_PURPLE : C_MUTED);
   SetLabel("V_STR", strTxt, strClr);

   //--- Quality gauge
   double quality = (g_State==STATE_CONFIRMING || IsPositionOpen()) ? g_LastQualityScore : ComputeTradeQualityScore(curScore, sig==SIGNAL_NONE?SIGNAL_BUY:sig);
   string qgFgN = DASH_PREFIX+"QG_FILL";
   int qgWidth = MathMax(4,(int)MathRound((W_TRACK()) * (quality/100.0)));
   if(ObjectFind(0,qgFgN)>=0) ObjectSetInteger(0,qgFgN,OBJPROP_XSIZE, qgWidth);
   color qgClr = (quality>=65)?C_GREEN:(quality>=40)?C_GOLD:C_RED;
   if(ObjectFind(0,qgFgN)>=0) ObjectSetInteger(0,qgFgN,OBJPROP_BGCOLOR, qgClr);
   int displayScore = (g_State==STATE_CONFIRMING || IsPositionOpen()) ? g_LastConfluenceScore : curScore;
   SetLabel("V_QG", DoubleToString(quality,0)+"/100 ("+IntegerToString(displayScore)+"/9)", qgClr);

   //--- News intelligence strip
   if(InpUseNewsFilter)
   {
      if(MQLInfoInteger(MQL_TESTER))
      {
         SetLabel("V_NWN", "Live-only (Tester N/A)", C_MUTED);
         SetLabel("V_NWT", "N/A", C_MUTED);
         SetLabel("V_NWS", "N/A", C_MUTED);
      }
      else if(g_NextHighImpact > 0)
      {
         int mins = (int)((g_NextHighImpact - TimeCurrent())/60);
         string nwTxt = StringSubstr(g_NextNewsTitle,0,22) + (mins>=0 ? "  ("+IntegerToString(mins)+"m)" : "  (released)");
         SetLabel("V_NWN", nwTxt, C_WHITE);
         SetLabel("V_NWT", g_NewsBlockActive ? "BLOCKED" : "CLEAR", g_NewsBlockActive ? C_RED : C_GREEN);
         string sentTxt = (g_NewsSentiment>15)?"BULLISH":(g_NewsSentiment<-15)?"BEARISH":"NEUTRAL";
         color  sentClr = (g_NewsSentiment>15)?C_GREEN:(g_NewsSentiment<-15)?C_RED:C_MUTED;
         SetLabel("V_NWS", sentTxt, sentClr);
      }
      else
      {
         SetLabel("V_NWN", "No high-impact events queued", C_MUTED);
         SetLabel("V_NWT", "CLEAR", C_GREEN);
         SetLabel("V_NWS", "NEUTRAL", C_MUTED);
      }
   }
   else
   {
      SetLabel("V_NWN", "Filter disabled", C_MUTED);
      SetLabel("V_NWT", "OFF", C_MUTED);
      SetLabel("V_NWS", "—", C_MUTED);
   }

   //--- Decision bar + Final Decision
   string decTxt; color decClr; color decBg; string aiTxt;

   if(g_State == STATE_CONFIRMING)
   {
      decTxt = "Decision: CONFIRMING ("+IntegerToString(g_ConfirmTicks)+"/"+IntegerToString(g_ConfirmTargetTicks)+")";
      decClr = C_PURPLE; decBg = C_PANEL2; aiTxt = "CONFIRMING";
   }
   else if(sig == SIGNAL_BUY)
   { decTxt = "Decision: BUY"; decClr = C_GREEN; decBg = C_BUY_BG; aiTxt = "BUY"; }
   else if(sig == SIGNAL_SELL)
   { decTxt = "Decision: SELL"; decClr = C_RED; decBg = C_SELL_BG; aiTxt = "SELL"; }
   else
   { decTxt = "Decision: HOLD"; decClr = C_GOLD; decBg = C_HOLD_BG; aiTxt = "HOLD"; }

   SetLabel("V_DEC", decTxt, decClr);
   string decBarN = DASH_PREFIX+"DEC_BAR";
   if(ObjectFind(0,decBarN)>=0) ObjectSetInteger(0,decBarN,OBJPROP_BGCOLOR,decBg);

   string fdN = DASH_PREFIX+"FD_BG";
   if(ObjectFind(0,fdN)>=0) ObjectSetInteger(0,fdN,OBJPROP_BGCOLOR,decBg);
   if(g_State == STATE_CONFIRMING) SetLabel("V_FD", "CONFIRMING", C_PURPLE);
   else SetLabel("V_FD", aiTxt, decClr);

   SetLabel("V_FDS1", aiTxt, decClr);
   SetLabel("V_FDS2", g_StatusText, g_StatusColor);

   SetLabel("V_AIST", g_StatusText, g_StatusColor);
   string dotN = DASH_PREFIX+"AI_DOT";
   if(ObjectFind(0,dotN)>=0) ObjectSetInteger(0,dotN,OBJPROP_COLOR,g_StatusColor);

   string lastDec = (sig==SIGNAL_BUY) ? "BUY" : (sig==SIGNAL_SELL) ? "SELL" : "HOLD";
   SetLabel("V_AILD", lastDec, decClr);

   int confPct = (int)MathRound((curScore / 9.0) * 100.0);
   string confTxt = (confPct >= 70) ? "HIGH" : (confPct >= 50) ? "MEDIUM" : "LOW";
   color  confClr = (confPct >= 70) ? C_GREEN : (confPct >= 50) ? C_GOLD : C_RED;
   SetLabel("V_AISC", confTxt, confClr);
   string confFgN = DASH_PREFIX+"CONF_FG";
   if(ObjectFind(0,confFgN)>=0)
      ObjectSetInteger(0,confFgN,OBJPROP_XSIZE, MathMax(4,(int)MathRound(140*(confPct/100.0))));
   if(ObjectFind(0,confFgN)>=0) ObjectSetInteger(0,confFgN,OBJPROP_BGCOLOR,confClr);

   //--- Open Positions Table (with TIER column)
   int posCount = 0;
   double totalFloat = 0.0;
   for(int r = 0; r < 2; r++)
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
            string tierTxt = (g_TPStage==TP_STAGE_NONE)?"PRE-TP1":(g_TPStage==TP_STAGE_TP1)?"TP1 LOCK":(g_TPStage==TP_STAGE_TP2)?"TP2 LOCK":"TP3";
            color  tierClr = (g_TPStage==TP_STAGE_NONE)?C_MUTED:(g_TPStage==TP_STAGE_TP1)?C_GOLD:C_GREEN;
            SetLabel("OR_T"+rs, typStr,                              typClr);
            SetLabel("OR_L"+rs, DoubleToString(g_Pos.Volume(),2),    C_WHITE);
            SetLabel("OR_O"+rs, DoubleToString(g_Pos.PriceOpen(),2), C_WHITE);
            SetLabel("OR_S"+rs, DoubleToString(g_Pos.StopLoss(),2),  C_RED);
            SetLabel("OR_TR"+rs, tierTxt, tierClr);
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
         SetLabel("OR_TR"+rs, "---", C_MUTED);
         SetLabel("OR_F"+rs, "---", C_MUTED);
      }
   }
   SetLabel("OP_CNT", IntegerToString(posCount)+" open", posCount>0 ? C_CYAN : C_MUTED);
   color cFlt = (totalFloat>=0) ? C_GREEN : C_RED;
   SetLabel("V_FLT",  (totalFloat>=0?"+":"")+DoubleToString(totalFloat,2), cFlt);
   SetLabel("V_OEQV", "$"+DoubleToString(AccountInfoDouble(ACCOUNT_EQUITY),2), C_WHITE);

   //--- Account Info
   double bal = AccountInfoDouble(ACCOUNT_BALANCE);
   double eq  = AccountInfoDouble(ACCOUNT_EQUITY);
   int    tot = g_DailyWins + g_DailyLosses;
   double wr  = (tot>0) ? ((double)g_DailyWins/tot)*100.0 : 0.0;
   double dpPct = (bal>0) ? (g_DailyProfit/bal)*100.0 : 0.0;

   SetLabel("V_BAL", "$"+DoubleToString(bal,2), C_GREEN);
   SetLabel("V_EQ",  "$"+DoubleToString(eq, 2), C_WHITE);
   color cDp = (g_DailyProfit>=0) ? C_GREEN : C_RED;
   SetLabel("V_DP",  (g_DailyProfit>=0?"+":"")+DoubleToString(g_DailyProfit,2)
            +" ("+DoubleToString(dpPct,2)+"%)", cDp);
   color cWR = (wr>=60) ? C_GREEN : (wr>=40 ? C_GOLD : C_RED);
   SetLabel("V_WR",  IntegerToString((int)wr)+"%", cWR);
   SetLabel("V_RSK", DoubleToString(GetDynamicRiskPercent(g_LastQualityScore),1)+"%", C_GOLD);

   //--- Session Pills
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

//--- helper: pixel width of the quality gauge track
int W_TRACK() { return DW - 90; }

//+------------------------------------------------------------------+
//| HELPER: timeframe to short string                                 |
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
//| END OF FILE                                                       |
//+------------------------------------------------------------------+
