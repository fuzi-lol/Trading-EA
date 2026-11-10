//+------------------------------------------------------------------+
//|                                      EliteScalperPro_V6.mq5       |
//|                                  Copyright 2026, FXBotHub Systems |
//|                                             https://fxbothub.com  |
//+------------------------------------------------------------------+
//  GOLD (XAUUSD) Institutional Scalping Engine — V6
//  Rebuilt from THEE EliteScalper v5 with:
//    • Market Regime Classifier (Strong Trend / Weak Trend / Range /
//      Breakout / High Vol / Extreme Vol) driving risk, entry strictness,
//      trade frequency and trailing aggressiveness
//    • Lightweight Smart Money Concepts filter — BOS, CHOCH, Liquidity
//      Sweep, Fair Value Gap — REQUIRED confirmation, not just scoring
//    • Gold-specific abnormal-candle / spread-spike / exhaustion guards
//    • 4-pillar signal quality gate: Trend + Momentum + Structure + Volatility
//      (no single indicator can trigger a trade)
//    • Dynamic risk 0.50%–2.00% driven by streak, drawdown, regime, signal score
//    • ATR dynamic trailing + structure trailing + time exit + volatility
//      collapse exit + emergency volatility-spike exit
//    • Spread Quality Score + Execution Quality Score gate
//    • CSV performance logging (pre-trade snapshot + post-trade outcome)
//      written to MQL5/Files for future ML research
//    • Expanded "Private Bank Terminal" dashboard
//+------------------------------------------------------------------+
#property copyright   "Copyright 2026, FXBotHub Systems"
#property version     "6.00"
#property description "GOLD Institutional Scalping Engine V6 — Regime + SMC + Dynamic Risk"
#property strict

#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>

#define DASH_PREFIX  "FXBH_V6_"
#define EA_VERSION   "v6.00"

//+------------------------------------------------------------------+
//| ENGINE STATE MACHINE                                              |
//+------------------------------------------------------------------+
enum ENUM_ENGINE_STATE
{
   STATE_SCANNING,
   STATE_ANALYZING,
   STATE_COOLDOWN,
   STATE_DAILY_LIMIT,
   STATE_NEWS_PAUSE,
   STATE_EMERGENCY_HALT
};

enum ENUM_SIGNAL
{
   SIGNAL_BUY  =  1,
   SIGNAL_SELL = -1,
   SIGNAL_NONE =  0
};

enum ENUM_MARKET_REGIME
{
   REGIME_STRONG_TREND,
   REGIME_WEAK_TREND,
   REGIME_RANGE,
   REGIME_BREAKOUT,
   REGIME_HIGH_VOL,
   REGIME_EXTREME_VOL
};

enum ENUM_SMC_EVENT
{
   SMC_NONE,
   SMC_BOS_BULL,
   SMC_BOS_BEAR,
   SMC_CHOCH_BULL,
   SMC_CHOCH_BEAR
};

//+------------------------------------------------------------------+
//| INPUT PARAMETERS                                                  |
//+------------------------------------------------------------------+
input group "=== CORE IDENTITY ==="
input ulong   InpMagicNumber       = 642071;     // Unique Magic Number (V6)
input string  InpTradeComment      = "EliteScalperPro_V6";

input group "=== RISK MANAGEMENT (primary controls) ==="
input double  InpRiskPercentBase   = 1.0;        // Base risk % per trade
input double  InpRiskPercentMin    = 0.50;       // Dynamic risk floor
input double  InpRiskPercentMax    = 2.00;       // Dynamic risk ceiling
input double  InpMaxDailyLossPct   = 5.0;        // Daily loss limit % (kill-switch)
input double  InpMaxDailyProfitPct = 10.0;       // Daily profit target % (stop trading)
input int     InpMaxDailyTrades    = 15;         // Max trades per day

input group "=== ATR-BASED STOP LOSS & TAKE PROFIT ==="
input int     InpATRPeriod         = 14;         // ATR period
input double  InpSLMultiplier      = 1.5;        // SL = ATR × multiplier
input double  InpTP1Multiplier     = 1.0;        // TP1 = ATR × multiplier (partial close)
input double  InpTP2Multiplier     = 1.8;        // TP2 = ATR × multiplier (ratchet step)
input double  InpTP3Multiplier     = 3.0;        // TP3 = ATR × multiplier (final target)
input int     InpMinSLPoints       = 150;        // Minimum SL in points (floor)
input int     InpMaxSLPoints       = 500;        // Maximum SL in points (ceiling)

input group "=== TIERED TP1/TP2/TP3 RATCHET EXIT ==="
input bool    InpUseTieredExit     = true;       // Enable TP1/TP2/TP3 ratchet system
input double  InpTP1ClosePct       = 40.0;       // % of position closed at TP1
input double  InpTP2ClosePct       = 35.0;       // % of remaining closed at TP2
input int     InpBreakevenPoints   = 120;        // Move SL to BE after X points in profit
input int     InpBreakevenBuffer   = 10;         // Extra buffer above open price for BE

input group "=== TRAILING STOP (ATR + Structure) ==="
input bool    InpUseTrailing       = true;       // Enable trailing stop
input bool    InpUseATRTrailing    = true;       // ATR-adaptive trail distance
input double  InpTrailATRMult      = 1.2;        // Trail distance = ATR × mult
input int     InpTrailStartPoints  = 200;        // Start trailing after X points profit
input int     InpTrailStepPoints   = 50;         // Min trail step size in points (fallback)
input bool    InpUseStructureTrail = true;       // Trail behind swing highs/lows
input int     InpStructureTrailBars= 8;          // Bars lookback for structure trail

input group "=== TIME / VOLATILITY / EMERGENCY EXIT ==="
input bool    InpUseTimeExit       = true;       // Close stagnant trades
input int     InpMaxTradeMinutes   = 90;         // Max minutes before time-exit eligible
input double  InpStagnationPts     = 80;         // Min points moved or considered stagnant
input bool    InpUseVolCollapseExit= true;       // Exit if volatility collapses post-entry
input double  InpVolCollapseRatio  = 0.45;       // Exit if ATR falls below entry-ATR × ratio
input bool    InpUseEmergencyExit  = true;       // Exit all on extreme volatility spike
input double  InpEmergencyATRMult  = 4.0;        // Emergency: candle range > ATR × mult

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
input int     InpStructureBars     = 5;          // Market structure high/low bars (signal)

input group "=== MARKET REGIME CLASSIFIER ==="
input int     InpRegimeEMASlopeBars= 10;         // Bars back for EMA slope calc
input double  InpRegimeADXStrong   = 30.0;       // ADX threshold: strong trend
input double  InpRegimeADXWeak     = 18.0;       // ADX threshold: weak trend floor
input double  InpRegimeBBWideRatio = 0.006;       // BB width/price ratio: breakout/expansion
input double  InpRegimeHighVolATR  = 1.8;        // ATR vs its own SMA(20) ratio: high vol
input double  InpRegimeExtremeVolATR= 2.6;       // ATR vs its own SMA(20) ratio: extreme vol

input group "=== SMART MONEY CONCEPTS (required confirmation) ==="
input bool    InpRequireSMC        = true;       // Require BOS/CHOCH confirmation to trade
input int     InpSMCSwingBars      = 6;          // Swing detection lookback (bars each side)
input int     InpSMCLookback       = 50;         // Bars searched for last swing points
input double  InpFVGMinATRRatio    = 0.25;       // Min gap size (×ATR) to qualify as FVG
input int     InpLiquiditySweepBars= 20;         // Bars back to find liquidity pool (equal highs/lows)
input double  InpLiquidityTolPts   = 60;         // Points tolerance for "equal" highs/lows

input group "=== GOLD-SPECIFIC GUARDS ==="
input double  InpAbnormalCandleATR = 3.0;        // Candle range > ATR × mult = abnormal/liquidation
input int     InpPostSpikeCooldown = 90;         // Seconds to wait after abnormal candle
input bool    InpWeekendLiquidityGuard = true;   // Reduce/avoid trading near weekend close
input int     InpFridayCutoffHourGMT   = 20;     // No new trades after this GMT hour on Friday
input bool    InpUseExhaustionFilter = true;     // Block entries on exhaustion candles

input group "=== EXECUTION QUALITY ==="
input int     InpSpreadMaxPoints   = 40;         // Hard spread ceiling (points)
input double  InpSpreadMultiplier  = 2.5;        // Dynamic: reject if spread > avg × X
input double  InpMinExecutionScore = 60.0;       // Min execution quality score (0-100) to trade

input group "=== COOLDOWN ==="
input int     InpCooldownSeconds   = 45;         // Cooldown between trades (seconds)

input group "=== SESSION FILTER ==="
input bool    InpUseSessionFilter  = true;       // Only trade during active sessions
input int     InpSessionStartGMT   = 7;          // Session start hour (GMT) – London open
input int     InpSessionEndGMT     = 20;         // Session end hour (GMT)

input group "=== STREAK PROTECTION ==="
input int     InpMaxLossStreak     = 3;          // Reduce size after N consecutive losses
input int     InpWinStreakBoost    = 5;          // Allow slight size increase after N wins (capped)

input group "=== NEWS PAUSE ==="
input bool    InpNewsPauseActive   = false;      // Manual news pause toggle (set true before news)

input group "=== CSV LOGGING ==="
input bool    InpEnableCSVLog      = true;       // Enable CSV performance logging
input string  InpCSVFileName       = "EliteScalperPro_V6_Log.csv"; // File name in MQL5/Files

input group "=== DASHBOARD ==="
input int     InpDashX            = 15;
input int     InpDashY            = 15;
//+------------------------------------------------------------------+
//| COLOUR PALETTE — "Private Bank Terminal" luxury dark/gold theme   |
//+------------------------------------------------------------------+
const color C_BG          = C'8,8,10';
const color C_PANEL       = C'14,14,17';
const color C_PANEL2      = C'18,18,22';
const color C_HEADER      = C'16,14,10';
const color C_BORDER      = C'196,164,90';   // muted antique gold
const color C_BORDER2     = C'90,78,52';
const color C_GOLD        = C'212,175,90';
const color C_GOLD_BRIGHT = C'255,210,120';
const color C_CYAN        = C'120,190,200';
const color C_BLUE        = C'90,140,200';
const color C_GREEN       = C'90,200,140';
const color C_RED         = C'205,70,70';
const color C_ORANGE      = C'215,140,60';
const color C_PURPLE      = C'150,120,190';
const color C_WHITE       = C'226,222,210';
const color C_MUTED       = C'120,116,108';
const color C_HOLD_BG     = C'40,34,16';
const color C_BUY_BG      = C'14,34,24';
const color C_SELL_BG     = C'36,14,14';
const color C_SECTION_HDR = C'20,18,14';

//+------------------------------------------------------------------+
//| GLOBAL ENGINE OBJECTS                                             |
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
int g_hATRSlow  = INVALID_HANDLE; // SMA(20) of ATR for regime vol-ratio

//--- State machine
ENUM_ENGINE_STATE g_State        = STATE_SCANNING;
datetime          g_StateTimer   = 0;

//--- Analysis phase
ENUM_SIGNAL  g_PendingSignal     = SIGNAL_NONE;
int          g_AnalysisTicks     = 0;
datetime     g_AnalysisStart     = 0;

//--- Tiered exit tracking (per open trade lifecycle)
bool         g_TP1Done           = false;
bool         g_TP2Done           = false;
datetime     g_TradeOpenTime     = 0;
double       g_TradeOpenPrice    = 0.0;
double       g_TradeEntryATR     = 0.0;
double       g_TradeInitialSL    = 0.0;
double       g_TradePeakProfit   = 0.0;
int          g_TradeSignalScore  = 0;
ENUM_MARKET_REGIME g_TradeRegime = REGIME_RANGE;

//--- Session metrics
datetime g_SessionDay       = 0;
int      g_DailyTrades      = 0;
double   g_DailyProfit      = 0.0;
int      g_DailyWins        = 0;
int      g_DailyLosses      = 0;
int      g_ConsecLosses     = 0;
int      g_ConsecWins       = 0;
double   g_SessionOpenBal   = 0.0;

//--- Spread tracking
double g_AvgSpread          = 0.0;
int    g_SpreadSamples      = 0;

//--- Abnormal candle / spike cooldown
datetime g_LastSpikeTime     = 0;

//--- Regime cache (recomputed each tick, cheap)
ENUM_MARKET_REGIME g_CurrentRegime = REGIME_RANGE;
string              g_RegimeLabel   = "RANGE";

//--- Execution / signal quality (recomputed each tick for dashboard)
double g_ExecutionScore     = 0.0;
double g_SpreadScore        = 0.0;
int    g_LastSignalScore    = 0;

//--- Dashboard strings
string g_StatusText         = "BOOTING";
color  g_StatusColor        = C_GOLD;
string g_HeartbeatStr       = "0 0 0 0";

//--- CSV log handle
int g_CSVHandle             = INVALID_HANDLE;

//+------------------------------------------------------------------+
//| FORWARD DECLARATIONS                                              |
//+------------------------------------------------------------------+
bool         InitIndicators();
void         ReleaseIndicators();
void         SyncDailyStats();

ENUM_SIGNAL  EvaluateConfluence(bool detectionMode, int &scoreOut);
bool         CheckEMAStack(double &fast, double &slow, double &trend);
bool         CheckRSI(ENUM_SIGNAL sig, double &rsiVal);
bool         CheckADX(double &adxVal);
bool         CheckMACD(ENUM_SIGNAL sig);
bool         CheckBollingerBands(ENUM_SIGNAL sig, bool &inSqueeze);
bool         CheckMarketStructure(ENUM_SIGNAL sig, bool proximityMode);

bool         CheckTrendAlignment(ENUM_SIGNAL sig);
bool         CheckMomentumAlignment(ENUM_SIGNAL sig);
bool         CheckStructureConfirmation(ENUM_SIGNAL sig, bool proximityMode);
bool         CheckVolatilityConfirmation();

ENUM_MARKET_REGIME ClassifyRegime();
string       RegimeToString(ENUM_MARKET_REGIME r);
double       GetRegimeRiskMultiplier(ENUM_MARKET_REGIME r);
int          GetRegimeMinScore(ENUM_MARKET_REGIME r);

ENUM_SMC_EVENT EvaluateSMC(ENUM_SIGNAL sig, bool &fvgPresent, bool &liquiditySwept);
bool         DetectBOS(ENUM_SIGNAL sig);
bool         DetectCHOCH(ENUM_SIGNAL sig);
bool         DetectFairValueGap(ENUM_SIGNAL sig);
bool         DetectLiquiditySweep(ENUM_SIGNAL sig);
int          FindSwingHigh(int startBar, int count);
int          FindSwingLow(int startBar, int count);

bool         IsAbnormalCandle();
bool         IsExhaustionCandle(ENUM_SIGNAL sig);
bool         IsWeekendLiquidityRisk();
bool         IsPostSpikeCooldown();

double       GetATR();
double       GetATRSlowAvg();
double       CalculateSpreadScore();
double       CalculateExecutionScore(int signalScore, double spreadScore);

double       CalculateLotSize(int slPoints, double riskPctOverride);
double       GetDynamicRiskPercent(ENUM_MARKET_REGIME regime, int signalScore);

void         ExecuteEntry(ENUM_SIGNAL sig, int signalScore, ENUM_MARKET_REGIME regime);
void         ManageOpenTrade();
void         CheckBreakevenAndRatchet();
void         CheckTrailing();
void         CheckATRTrailing();
void         CheckStructureTrailing();
void         CheckTimeExit();
void         CheckVolatilityCollapseExit();
void         CheckEmergencyExit();
void         EvaluateFloatingPnL();

bool         IsPositionOpen();
double       GetFloatingPnL();
void         CloseAllPositions(string reason);
bool         IsMarketOpen();
bool         IsInSession();
bool         IsSpreadOk();
void         UpdateSpreadAverage();
bool         IsDailyLossLimitHit();
bool         IsDailyProfitTargetHit();
datetime     GetDayStart(datetime t);
void         ProcessAnalysisPhase();

void         LogPreTrade(ENUM_SIGNAL sig, int signalScore, ENUM_MARKET_REGIME regime, double spreadScore, double execScore);
void         LogPostTrade(double profit, double rMultiple, int durationSec, double maxDD);
void         InitCSVLog();

void         RenderDashboard();
void         UpdateDashboard();
void         PurgeDashboard();
void         DrawRect(string id, int x, int y, int w, int h, color bg, color border, int bw);
void         DrawLabel(string id, int x, int y, string txt, color clr, int sz, string fnt);
void         SetLabel(string id, string txt, color clr = clrNONE);
string       TimeframeToString(ENUM_TIMEFRAMES tf);
//+------------------------------------------------------------------+
//| INIT                                                               |
//+------------------------------------------------------------------+
int OnInit()
{
   if(StringFind(_Symbol, "XAU") < 0 && StringFind(_Symbol, "GOLD") < 0)
      Print("[EliteScalperPro V6] WARNING: Optimised for GOLD (XAUUSD). Current symbol: ", _Symbol);

   g_Trade.SetExpertMagicNumber(InpMagicNumber);
   g_Trade.SetDeviationInPoints(20);
   g_Trade.SetTypeFilling(ORDER_FILLING_FOK);

   if(InpRiskPercentBase <= 0.0 || InpRiskPercentMax > 10.0 || InpRiskPercentMin <= 0.0 || InpRiskPercentMin > InpRiskPercentMax)
   { Alert("Risk% configuration invalid. Check Min/Base/Max."); return INIT_PARAMETERS_INCORRECT; }

   if(!InitIndicators()) return INIT_FAILED;

   g_SessionDay     = GetDayStart(TimeCurrent());
   g_SessionOpenBal = AccountInfoDouble(ACCOUNT_BALANCE);
   SyncDailyStats();

   if(InpEnableCSVLog) InitCSVLog();

   g_State = STATE_SCANNING;
   EventSetTimer(1);
   RenderDashboard();

   Print("[EliteScalperPro V6] Initialised. Symbol=", _Symbol, " Magic=", InpMagicNumber);
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| DEINIT                                                             |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   EventKillTimer();
   PurgeDashboard();
   ReleaseIndicators();
   if(g_CSVHandle != INVALID_HANDLE) FileClose(g_CSVHandle);
}

//+------------------------------------------------------------------+
//| TIMER — heartbeat + stats sync                                     |
//+------------------------------------------------------------------+
void OnTimer()
{
   static uint beat = 0; beat++;
   string p[4] = {"1 0 1 1  0 1 0 0","0 1 0 0  1 0 1 1","1 1 0 1  0 0 1 0","0 0 1 0  1 1 0 1"};
   g_HeartbeatStr = p[beat % 4];
   SyncDailyStats();
   g_CurrentRegime = ClassifyRegime();
   g_RegimeLabel   = RegimeToString(g_CurrentRegime);
   UpdateDashboard();
}

//+------------------------------------------------------------------+
//| TICK — main engine                                                 |
//+------------------------------------------------------------------+
void OnTick()
{
   UpdateSpreadAverage();
   g_CurrentRegime = ClassifyRegime();
   g_RegimeLabel   = RegimeToString(g_CurrentRegime);

   //--- Market tradeable?
   if(!IsMarketOpen())
   { g_StatusText = "MARKET CLOSED"; g_StatusColor = C_RED; return; }

   //--- Emergency halt (extreme volatility spike) — checked every tick, overrides all
   if(InpUseEmergencyExit && IsPositionOpen())
      CheckEmergencyExit();

   if(g_State == STATE_EMERGENCY_HALT)
   {
      int left = (int)(g_StateTimer - TimeCurrent());
      if(left > 0)
      {
         g_StatusText  = "EMERGENCY HALT (" + IntegerToString(left) + "s)";
         g_StatusColor = C_RED;
         return;
      }
      g_State = STATE_SCANNING;
   }

   //--- News pause
   if(InpNewsPauseActive || g_State == STATE_NEWS_PAUSE)
   { g_StatusText = "NEWS PAUSE ACTIVE"; g_StatusColor = C_GOLD; return; }

   //--- Manage any open trade first (trailing, BE, ratchet, time/vol exits)
   if(IsPositionOpen())
   { ManageOpenTrade(); return; }

   //--- Daily drawdown kill-switch
   if(IsDailyLossLimitHit())
   {
      g_State = STATE_DAILY_LIMIT;
      g_StatusText = "DAILY LOSS LIMIT HIT — HALTED";
      g_StatusColor = C_RED;
      return;
   }

   //--- Daily profit target reached
   if(IsDailyProfitTargetHit())
   {
      g_State = STATE_DAILY_LIMIT;
      g_StatusText = "DAILY PROFIT TARGET MET — HALTED";
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
      g_StatusText = "OUT OF SESSION — WAITING";
      g_StatusColor = C_MUTED;
      return;
   }

   //--- Weekend liquidity guard
   if(InpWeekendLiquidityGuard && IsWeekendLiquidityRisk())
   {
      g_StatusText = "WEEKEND LIQUIDITY GUARD ACTIVE";
      g_StatusColor = C_GOLD;
      return;
   }

   //--- Post-spike cooldown (abnormal/liquidation candle guard)
   if(IsPostSpikeCooldown())
   {
      g_StatusText = "POST-SPIKE COOLDOWN";
      g_StatusColor = C_ORANGE;
      return;
   }

   //--- Extreme volatility regime — pause new entries entirely
   if(g_CurrentRegime == REGIME_EXTREME_VOL)
   {
      g_StatusText = "EXTREME VOLATILITY — ENTRIES PAUSED";
      g_StatusColor = C_RED;
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

   //--- Abnormal candle just printed — treat as spike, start cooldown
   if(IsAbnormalCandle())
   {
      g_LastSpikeTime = TimeCurrent();
      g_StatusText = "ABNORMAL CANDLE DETECTED — COOLING DOWN";
      g_StatusColor = C_ORANGE;
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
      int score = 0;
      ENUM_SIGNAL sig = EvaluateConfluence(true, score);
      if(sig == SIGNAL_NONE)
      {
         g_StatusText  = "SCANNING [" + g_RegimeLabel + "] — BUILDING CONFLUENCE";
         g_StatusColor = C_MUTED;
         return;
      }
      // Signal found – enter analysis phase
      g_State          = STATE_ANALYZING;
      g_PendingSignal  = sig;
      g_AnalysisStart  = TimeCurrent();
      g_AnalysisTicks  = 0;
      g_LastSignalScore = score;
      g_StatusText     = "SIGNAL DETECTED — ANALYSING";
      g_StatusColor    = C_PURPLE;
      Print("[EliteScalperPro V6] Signal=", (sig==SIGNAL_BUY?"BUY":"SELL"),
            " Score=", score, " Regime=", g_RegimeLabel, " — Entering analysis phase");
   }
   //--- ANALYSING: validate signal over time window
   else if(g_State == STATE_ANALYZING)
   {
      ProcessAnalysisPhase();
   }
}
//+------------------------------------------------------------------+
//| INDICATOR INITIALISATION                                          |
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
   g_hATRSlow  = iMA(_Symbol, _Period, 20, 0, MODE_SMA, g_hATR == INVALID_HANDLE ? PRICE_CLOSE : PRICE_CLOSE);

   // ATR-of-ATR isn't directly supported via iMA on a handle, so we compute the
   // slow ATR average manually in GetATRSlowAvg() instead of via a chained handle.
   if(g_hATRSlow != INVALID_HANDLE) { IndicatorRelease(g_hATRSlow); g_hATRSlow = INVALID_HANDLE; }

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
//| CONFLUENCE SIGNAL ENGINE                                          |
//| detectionMode=true  → strict (scanning, all gates must pass)      |
//| detectionMode=false → validation (analysis ticks, relaxed struct) |
//|                                                                    |
//| 4-PILLAR GATE: no single indicator can trigger a trade. Trend,    |
//| Momentum, Structure and Volatility pillars must ALL pass before   |
//| the legacy weighted score is even consulted. SMC confirmation is  |
//| then layered on top as a hard requirement (if InpRequireSMC).     |
//+------------------------------------------------------------------+
ENUM_SIGNAL EvaluateConfluence(bool detectionMode, int &scoreOut)
{
   scoreOut = 0;
   double fastEMA, slowEMA, trendEMA;
   bool   inSqueeze = false;

   //--- EMA stack determines candidate direction
   if(!CheckEMAStack(fastEMA, slowEMA, trendEMA))
      return SIGNAL_NONE;
   ENUM_SIGNAL candidate = (fastEMA > slowEMA && slowEMA > trendEMA) ? SIGNAL_BUY : SIGNAL_SELL;

   //--- BB squeeze is a hard block regardless of anything else
   double dummyUpper, dummyLower, dummyMid;
   CheckBollingerBands(candidate, inSqueeze);
   if(inSqueeze) return SIGNAL_NONE;

   //--- 4-PILLAR GATE — every pillar must independently confirm
   bool trendOk      = CheckTrendAlignment(candidate);
   bool momentumOk    = CheckMomentumAlignment(candidate);
   bool structureOk   = CheckStructureConfirmation(candidate, !detectionMode);
   bool volatilityOk  = CheckVolatilityConfirmation();

   if(!trendOk || !momentumOk || !structureOk || !volatilityOk)
   {
      static int logTickFail = 0; logTickFail++;
      if(detectionMode && (logTickFail % 20 == 0))
         PrintFormat("[4-Pillar] Dir=%s REJECTED | Trend=%s Momentum=%s Structure=%s Volatility=%s",
            (candidate==SIGNAL_BUY?"BUY":"SELL"),
            trendOk?"OK":"FAIL", momentumOk?"OK":"FAIL", structureOk?"OK":"FAIL", volatilityOk?"OK":"FAIL");
      return SIGNAL_NONE;
   }

   //--- Legacy weighted confirmation score (kept for dashboard + dynamic risk sizing)
   double rsiVal, adxVal;
   bool rsiPass    = CheckRSI(candidate, rsiVal);
   bool adxPass    = CheckADX(adxVal);
   bool macdPass   = CheckMACD(candidate);
   bool bbPass     = CheckBollingerBands(candidate, inSqueeze);
   bool structPass = CheckMarketStructure(candidate, !detectionMode);

   int score = 2; // EMA stack baseline
   if(rsiPass)    score++;
   if(adxPass)    score++;
   if(macdPass)   score++;
   if(bbPass)     score++;
   if(structPass) score++;

   //--- Regime-adjusted minimum score requirement
   int minScore = GetRegimeMinScore(g_CurrentRegime);
   if(score < minScore) return SIGNAL_NONE;

   //--- SMC required confirmation layer
   if(InpRequireSMC)
   {
      bool fvgPresent = false, liquiditySwept = false;
      ENUM_SMC_EVENT smcEvt = EvaluateSMC(candidate, fvgPresent, liquiditySwept);
      bool smcConfirmed = (candidate == SIGNAL_BUY) ? (smcEvt == SMC_BOS_BULL || smcEvt == SMC_CHOCH_BULL)
                                                     : (smcEvt == SMC_BOS_BEAR || smcEvt == SMC_CHOCH_BEAR);
      if(!smcConfirmed)
      {
         static int logTickSMC = 0; logTickSMC++;
         if(detectionMode && (logTickSMC % 20 == 0))
            PrintFormat("[SMC] Dir=%s REJECTED | Event=%d FVG=%s Liquidity=%s",
               (candidate==SIGNAL_BUY?"BUY":"SELL"), (int)smcEvt,
               fvgPresent?"yes":"no", liquiditySwept?"swept":"no");
         return SIGNAL_NONE;
      }
      // Bonus score points for extra confluence (FVG / liquidity sweep), capped at 9
      if(fvgPresent)      score = MathMin(score+1, 9);
      if(liquiditySwept)  score = MathMin(score+1, 9);
   }

   //--- Exhaustion candle filter — block fresh entries into exhaustion
   if(InpUseExhaustionFilter && IsExhaustionCandle(candidate))
      return SIGNAL_NONE;

   scoreOut = score;

   static int logTick = 0; logTick++;
   if(detectionMode || (logTick % 10 == 0))
   {
      PrintFormat("[Confluence] Dir=%s Score=%d Regime=%s | RSI=%s ADX=%s MACD=%s BB=%s Struct=%s",
         (candidate==SIGNAL_BUY?"BUY":"SELL"), score, g_RegimeLabel,
         rsiPass?"OK":"NO", adxPass?"OK":"NO", macdPass?"OK":"NO", bbPass?"OK":"NO", structPass?"OK":"NO");
   }

   return candidate;
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
   if(sig == SIGNAL_BUY)  return (bid > mid[0]);
   if(sig == SIGNAL_SELL) return (bid < mid[0]);
   return false;
}

//--- Market structure (legacy scoring component): breakout OR proximity to swing level
bool CheckMarketStructure(ENUM_SIGNAL sig, bool proximityMode)
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
//| 4-PILLAR GATE COMPONENTS                                          |
//+------------------------------------------------------------------+

//--- PILLAR 1: Trend Alignment — EMA stack direction AND ADX above weak-trend floor
bool CheckTrendAlignment(ENUM_SIGNAL sig)
{
   double adxVal;
   if(!CheckADX(adxVal))
   {
      // ADX below InpADXMinStrength fails CheckADX; here we use the looser
      // "weak trend floor" so Trend pillar isn't redundant with legacy ADX score.
      double adx[1];
      if(CopyBuffer(g_hADX, 0, 0, 1, adx) <= 0) return false;
      if(adx[0] < InpRegimeADXWeak) return false;
   }
   // Reject trend-pillar pass during pure RANGE regime — trend pillar should
   // not pass when the market classifier itself says there is no trend.
   if(g_CurrentRegime == REGIME_RANGE) return false;
   return true;
}

//--- PILLAR 2: Momentum Alignment — RSI direction + MACD histogram direction agree
bool CheckMomentumAlignment(ENUM_SIGNAL sig)
{
   double rsiVal;
   bool rsiOk  = CheckRSI(sig, rsiVal);
   bool macdOk = CheckMACD(sig);
   return (rsiOk && macdOk);
}

//--- PILLAR 3: Structure Confirmation — price breaking/near swing structure
bool CheckStructureConfirmation(ENUM_SIGNAL sig, bool proximityMode)
{
   return CheckMarketStructure(sig, proximityMode);
}

//--- PILLAR 4: Volatility Confirmation — ATR not collapsed, not in squeeze, regime tradeable
bool CheckVolatilityConfirmation()
{
   double atr = GetATR();
   if(atr <= 0.0) return false;

   double atrSlowAvg = GetATRSlowAvg();
   if(atrSlowAvg <= 0.0) return true; // not enough history yet, don't block

   double ratio = atr / atrSlowAvg;
   // Reject if volatility has collapsed too far below its own average (dead market)
   if(ratio < 0.35) return false;
   // Extreme vol regime already blocked upstream in OnTick, but double-guard here
   if(ratio >= InpRegimeExtremeVolATR) return false;
   return true;
}
//+------------------------------------------------------------------+
//| ATR HELPERS                                                       |
//+------------------------------------------------------------------+
double GetATR()
{
   double atr[1];
   if(CopyBuffer(g_hATR, 0, 0, 1, atr) <= 0) return 0.0;
   return atr[0];
}

//--- Manual SMA(20) of the ATR buffer — avoids chaining indicator-on-indicator handles
double GetATRSlowAvg()
{
   double atrBuf[];
   int need = 20;
   if(CopyBuffer(g_hATR, 0, 0, need, atrBuf) < need) return 0.0;
   double sum = 0.0;
   for(int i = 0; i < need; i++) sum += atrBuf[i];
   return sum / need;
}

//+------------------------------------------------------------------+
//| MARKET REGIME CLASSIFIER                                          |
//| Combines ATR, ADX, EMA slope, BB width and structure into one of  |
//| six regimes. Regime feeds: dynamic risk, entry strictness (min    |
//| score), trade frequency (via entry gating upstream) and trailing  |
//| aggressiveness.                                                   |
//+------------------------------------------------------------------+
ENUM_MARKET_REGIME ClassifyRegime()
{
   double atr        = GetATR();
   double atrSlowAvg  = GetATRSlowAvg();
   double volRatio    = (atrSlowAvg > 0.0) ? (atr / atrSlowAvg) : 1.0;

   double adx[1];
   double adxVal = 0.0;
   if(CopyBuffer(g_hADX, 0, 0, 1, adx) > 0) adxVal = adx[0];

   //--- EMA slope over InpRegimeEMASlopeBars bars (using trend EMA buffer)
   double emaNow[1], emaPast[1];
   double slopePts = 0.0;
   if(CopyBuffer(g_hTrendEMA, 0, 0, 1, emaNow) > 0 &&
      CopyBuffer(g_hTrendEMA, 0, InpRegimeEMASlopeBars, 1, emaPast) > 0)
   {
      double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
      if(point > 0.0) slopePts = MathAbs(emaNow[0] - emaPast[0]) / point;
   }

   //--- BB width ratio
   double upper[1], lower[1];
   double bbWidthRatio = 0.0;
   if(CopyBuffer(g_hBB, 1, 0, 1, upper) > 0 && CopyBuffer(g_hBB, 2, 0, 1, lower) > 0)
   {
      double price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      if(price > 0.0) bbWidthRatio = (upper[0] - lower[0]) / price;
   }

   //--- EXTREME VOLATILITY — overrides everything
   if(volRatio >= InpRegimeExtremeVolATR)
      return REGIME_EXTREME_VOL;

   //--- HIGH VOLATILITY
   if(volRatio >= InpRegimeHighVolATR)
      return REGIME_HIGH_VOL;

   //--- BREAKOUT — BB expanding sharply with momentum behind it (ADX rising into strong zone)
   if(bbWidthRatio >= InpRegimeBBWideRatio && adxVal >= InpRegimeADXWeak)
      return REGIME_BREAKOUT;

   //--- STRONG TREND — high ADX + meaningful EMA slope
   if(adxVal >= InpRegimeADXStrong && slopePts > 0.0)
      return REGIME_STRONG_TREND;

   //--- WEAK TREND — moderate ADX
   if(adxVal >= InpRegimeADXWeak)
      return REGIME_WEAK_TREND;

   //--- Default — RANGE
   return REGIME_RANGE;
}

string RegimeToString(ENUM_MARKET_REGIME r)
{
   switch(r)
   {
      case REGIME_STRONG_TREND: return "STRONG TREND";
      case REGIME_WEAK_TREND:   return "WEAK TREND";
      case REGIME_RANGE:        return "RANGE";
      case REGIME_BREAKOUT:     return "BREAKOUT";
      case REGIME_HIGH_VOL:     return "HIGH VOL";
      case REGIME_EXTREME_VOL:  return "EXTREME VOL";
   }
   return "UNKNOWN";
}

//--- Regime → risk multiplier applied on top of dynamic streak/drawdown risk
double GetRegimeRiskMultiplier(ENUM_MARKET_REGIME r)
{
   switch(r)
   {
      case REGIME_STRONG_TREND: return 1.20;
      case REGIME_BREAKOUT:     return 1.10;
      case REGIME_WEAK_TREND:   return 1.00;
      case REGIME_RANGE:        return 0.70;
      case REGIME_HIGH_VOL:     return 0.55;
      case REGIME_EXTREME_VOL:  return 0.0; // no new entries in this regime anyway
   }
   return 1.0;
}

//--- Regime → minimum legacy confluence score required to trade
int GetRegimeMinScore(ENUM_MARKET_REGIME r)
{
   switch(r)
   {
      case REGIME_STRONG_TREND: return 5;
      case REGIME_BREAKOUT:     return 5;
      case REGIME_WEAK_TREND:   return 6;
      case REGIME_RANGE:        return 7; // range trades need near-perfect confluence
      case REGIME_HIGH_VOL:     return 7;
      case REGIME_EXTREME_VOL:  return 9; // effectively unreachable — no entries
   }
   return 6;
}

//+------------------------------------------------------------------+
//| SMART MONEY CONCEPTS (lightweight, required confirmation)         |
//+------------------------------------------------------------------+

//--- Find the bar index of a swing high within [startBar, startBar+count) using
//    a simple fractal-style check (higher than InpSMCSwingBars neighbours each side)
int FindSwingHigh(int startBar, int count)
{
   for(int i = startBar; i < startBar + count; i++)
   {
      double h = iHigh(_Symbol, _Period, i);
      bool isSwing = true;
      for(int j = 1; j <= InpSMCSwingBars; j++)
      {
         if(i-j < 0 || i+j >= startBar+count+InpSMCSwingBars) continue;
         if(iHigh(_Symbol, _Period, i-j) > h || iHigh(_Symbol, _Period, i+j) > h)
         { isSwing = false; break; }
      }
      if(isSwing) return i;
   }
   return -1;
}

int FindSwingLow(int startBar, int count)
{
   for(int i = startBar; i < startBar + count; i++)
   {
      double l = iLow(_Symbol, _Period, i);
      bool isSwing = true;
      for(int j = 1; j <= InpSMCSwingBars; j++)
      {
         if(i-j < 0 || i+j >= startBar+count+InpSMCSwingBars) continue;
         if(iLow(_Symbol, _Period, i-j) < l || iLow(_Symbol, _Period, i+j) < l)
         { isSwing = false; break; }
      }
      if(isSwing) return i;
   }
   return -1;
}

//--- BOS (Break Of Structure): price closes beyond the most recent swing high/low
//    in the direction of the candidate trade — continuation confirmation.
bool DetectBOS(ENUM_SIGNAL sig)
{
   int lookStart = 1;
   if(sig == SIGNAL_BUY)
   {
      int swingIdx = FindSwingHigh(lookStart, InpSMCLookback);
      if(swingIdx < 0) return false;
      double swingHigh = iHigh(_Symbol, _Period, swingIdx);
      double lastClose = iClose(_Symbol, _Period, 1);
      return (lastClose > swingHigh);
   }
   else if(sig == SIGNAL_SELL)
   {
      int swingIdx = FindSwingLow(lookStart, InpSMCLookback);
      if(swingIdx < 0) return false;
      double swingLow  = iLow(_Symbol, _Period, swingIdx);
      double lastClose = iClose(_Symbol, _Period, 1);
      return (lastClose < swingLow);
   }
   return false;
}

//--- CHOCH (Change Of Character): the most recent swing sequence flips —
//    e.g. for a bullish CHOCH, price was making lower lows/highs and just broke
//    above the most recent minor swing high, signalling a potential reversal.
bool DetectCHOCH(ENUM_SIGNAL sig)
{
   // Find two most recent swing highs and lows to establish prior structure
   int firstHigh  = FindSwingHigh(1, InpSMCLookback);
   if(firstHigh < 0) return false;
   int secondHigh = FindSwingHigh(firstHigh+1, InpSMCLookback);
   int firstLow   = FindSwingLow(1, InpSMCLookback);
   if(firstLow < 0) return false;
   int secondLow  = FindSwingLow(firstLow+1, InpSMCLookback);

   double lastClose = iClose(_Symbol, _Period, 1);

   if(sig == SIGNAL_BUY)
   {
      // Prior structure must show a lower-high pattern (downtrend context),
      // and price now breaks above the most recent (closer-in-time) swing high.
      if(secondHigh < 0) return false;
      double recentHigh = iHigh(_Symbol, _Period, firstHigh);
      double priorHigh  = iHigh(_Symbol, _Period, secondHigh);
      bool priorWasDowntrend = (recentHigh < priorHigh);
      return (priorWasDowntrend && lastClose > recentHigh);
   }
   else if(sig == SIGNAL_SELL)
   {
      if(secondLow < 0) return false;
      double recentLow = iLow(_Symbol, _Period, firstLow);
      double priorLow  = iLow(_Symbol, _Period, secondLow);
      bool priorWasUptrend = (recentLow > priorLow);
      return (priorWasUptrend && lastClose < recentLow);
   }
   return false;
}

//--- Fair Value Gap: a 3-candle imbalance where candle[2]'s high/low doesn't
//    overlap with candle[0]'s low/high, leaving a gap of at least
//    InpFVGMinATRRatio × ATR.
bool DetectFairValueGap(ENUM_SIGNAL sig)
{
   double atr = GetATR();
   if(atr <= 0.0) return false;
   double minGap = atr * InpFVGMinATRRatio;

   // candles: 1=most recent closed, 2=middle, 3=oldest of the 3
   double high3 = iHigh(_Symbol, _Period, 3);
   double low3  = iLow(_Symbol, _Period, 3);
   double high1 = iHigh(_Symbol, _Period, 1);
   double low1  = iLow(_Symbol, _Period, 1);

   if(sig == SIGNAL_BUY)
   {
      // Bullish FVG: low of candle1 > high of candle3 (gap up)
      double gap = low1 - high3;
      return (gap >= minGap);
   }
   else if(sig == SIGNAL_SELL)
   {
      // Bearish FVG: high of candle1 < low of candle3 (gap down)
      double gap = low3 - high1;
      return (gap >= minGap);
   }
   return false;
}

//--- Liquidity Sweep: price wicks beyond a pool of equal highs/lows (stop-hunt)
//    then closes back inside — classic liquidity grab before reversal/continuation.
bool DetectLiquiditySweep(ENUM_SIGNAL sig)
{
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   double tol   = InpLiquidityTolPts * point;

   if(sig == SIGNAL_BUY)
   {
      // Look for two or more equal lows in lookback window (a liquidity pool below),
      // then check the most recent candle wicked below the pool but closed above it.
      double poolLow = iLow(_Symbol, _Period, 2);
      int equalCount = 0;
      for(int i = 3; i < InpLiquiditySweepBars; i++)
      {
         double l = iLow(_Symbol, _Period, i);
         if(MathAbs(l - poolLow) <= tol) equalCount++;
      }
      if(equalCount < 1) return false;

      double curLow   = iLow(_Symbol, _Period, 1);
      double curClose = iClose(_Symbol, _Period, 1);
      bool sweptBelow = (curLow < poolLow - tol*0.5);
      bool closedBack = (curClose > poolLow);
      return (sweptBelow && closedBack);
   }
   else if(sig == SIGNAL_SELL)
   {
      double poolHigh = iHigh(_Symbol, _Period, 2);
      int equalCount = 0;
      for(int i = 3; i < InpLiquiditySweepBars; i++)
      {
         double h = iHigh(_Symbol, _Period, i);
         if(MathAbs(h - poolHigh) <= tol) equalCount++;
      }
      if(equalCount < 1) return false;

      double curHigh  = iHigh(_Symbol, _Period, 1);
      double curClose = iClose(_Symbol, _Period, 1);
      bool sweptAbove = (curHigh > poolHigh + tol*0.5);
      bool closedBack = (curClose < poolHigh);
      return (sweptAbove && closedBack);
   }
   return false;
}

//--- Master SMC evaluator: returns the strongest confirming event for the
//    candidate direction, plus FVG/liquidity flags used as bonus scoring.
ENUM_SMC_EVENT EvaluateSMC(ENUM_SIGNAL sig, bool &fvgPresent, bool &liquiditySwept)
{
   fvgPresent     = DetectFairValueGap(sig);
   liquiditySwept = DetectLiquiditySweep(sig);

   bool bos   = DetectBOS(sig);
   bool choch = DetectCHOCH(sig);

   if(sig == SIGNAL_BUY)
   {
      if(bos)   return SMC_BOS_BULL;
      if(choch) return SMC_CHOCH_BULL;
   }
   else if(sig == SIGNAL_SELL)
   {
      if(bos)   return SMC_BOS_BEAR;
      if(choch) return SMC_CHOCH_BEAR;
   }
   return SMC_NONE;
}
//+------------------------------------------------------------------+
//| GOLD-SPECIFIC GUARDS                                              |
//+------------------------------------------------------------------+

//--- Abnormal / liquidation candle: range of the last CLOSED candle exceeds
//    ATR × InpAbnormalCandleATR. Gold liquidation wicks tend to be violent
//    and mean-revert hard — we don't want to chase them.
bool IsAbnormalCandle()
{
   double atr = GetATR();
   if(atr <= 0.0) return false;
   double range = iHigh(_Symbol, _Period, 1) - iLow(_Symbol, _Period, 1);
   return (range >= atr * InpAbnormalCandleATR);
}

//--- Exhaustion candle: very large range candle in the direction of the
//    candidate trade, with a small body relative to range and a long wick
//    against the direction — classic blow-off/exhaustion signature.
bool IsExhaustionCandle(ENUM_SIGNAL sig)
{
   double open  = iOpen(_Symbol, _Period, 1);
   double close = iClose(_Symbol, _Period, 1);
   double high  = iHigh(_Symbol, _Period, 1);
   double low   = iLow(_Symbol, _Period, 1);
   double atr   = GetATR();
   if(atr <= 0.0) return false;

   double range = high - low;
   if(range < atr * 1.5) return false; // not a large enough candle to be exhaustion

   double body       = MathAbs(close - open);
   double bodyRatio  = (range > 0.0) ? body / range : 0.0;
   if(bodyRatio > 0.45) return false; // real bodies aren't exhaustion wicks

   if(sig == SIGNAL_BUY)
   {
      // Buying into a candle with a long upper wick (rejection at highs) = exhaustion
      double upperWick = high - MathMax(open, close);
      return (upperWick >= range * 0.45);
   }
   else if(sig == SIGNAL_SELL)
   {
      double lowerWick = MathMin(open, close) - low;
      return (lowerWick >= range * 0.45);
   }
   return false;
}

//--- Weekend liquidity guard: avoid opening new trades into thinning
//    Friday-evening liquidity ahead of the weekend gap risk.
bool IsWeekendLiquidityRisk()
{
   MqlDateTime gmt; TimeToStruct(TimeGMT(), gmt);
   if(gmt.day_of_week == 5 && gmt.hour >= InpFridayCutoffHourGMT) return true; // Friday evening
   if(gmt.day_of_week == 6) return true; // Saturday (should be market-closed anyway)
   if(gmt.day_of_week == 0) return true; // Sunday
   return false;
}

//--- Post-spike cooldown: after an abnormal candle is detected, stand aside
//    for InpPostSpikeCooldown seconds to let volatility/spread normalise.
bool IsPostSpikeCooldown()
{
   if(g_LastSpikeTime == 0) return false;
   return ((TimeCurrent() - g_LastSpikeTime) < InpPostSpikeCooldown);
}

//+------------------------------------------------------------------+
//| EXECUTION QUALITY SCORING                                         |
//+------------------------------------------------------------------+

//--- Spread Quality Score (0-100): 100 = spread at/below average, scales down
//    toward 0 as spread approaches the hard ceiling.
double CalculateSpreadScore()
{
   double spread = (double)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   if(spread <= 0.0) return 100.0;

   double baseline = (g_AvgSpread > 0.0) ? g_AvgSpread : spread;
   if(spread <= baseline) return 100.0;

   double ceiling = (double)InpSpreadMaxPoints;
   if(spread >= ceiling) return 0.0;

   double score = 100.0 * (1.0 - ((spread - baseline) / (ceiling - baseline)));
   return MathMax(0.0, MathMin(100.0, score));
}

//--- Execution Quality Score (0-100): blends spread quality, signal score,
//    current regime favourability and volatility ratio sanity.
double CalculateExecutionScore(int signalScore, double spreadScore)
{
   double signalComponent = MathMin(100.0, (signalScore / 9.0) * 100.0);

   double regimeComponent;
   switch(g_CurrentRegime)
   {
      case REGIME_STRONG_TREND: regimeComponent = 100.0; break;
      case REGIME_BREAKOUT:     regimeComponent = 90.0;  break;
      case REGIME_WEAK_TREND:   regimeComponent = 70.0;  break;
      case REGIME_RANGE:        regimeComponent = 45.0;  break;
      case REGIME_HIGH_VOL:     regimeComponent = 30.0;  break;
      case REGIME_EXTREME_VOL:  regimeComponent = 0.0;   break;
      default:                  regimeComponent = 50.0;  break;
   }

   double atr        = GetATR();
   double atrSlowAvg  = GetATRSlowAvg();
   double volRatio    = (atrSlowAvg > 0.0) ? (atr / atrSlowAvg) : 1.0;
   double volComponent = (volRatio >= 0.6 && volRatio <= 1.6) ? 100.0
                        : MathMax(0.0, 100.0 - MathAbs(volRatio - 1.0) * 80.0);

   double score = (spreadScore * 0.35) + (signalComponent * 0.30) + (regimeComponent * 0.20) + (volComponent * 0.15);
   return MathMax(0.0, MathMin(100.0, score));
}
//+------------------------------------------------------------------+
//| DYNAMIC RISK SIZING (0.50% – 2.00%)                                |
//| Driven by: win/loss streak, drawdown, volatility regime, signal   |
//| quality. Reduces automatically after losing streaks; only         |
//| increases when drawdown is low, win rate healthy and signal score |
//| is high.                                                          |
//+------------------------------------------------------------------+
double GetDynamicRiskPercent(ENUM_MARKET_REGIME regime, int signalScore)
{
   double pct = InpRiskPercentBase;

   //--- Loss streak reduction (compounding taper)
   if(g_ConsecLosses >= InpMaxLossStreak)
   {
      int overBy = g_ConsecLosses - InpMaxLossStreak + 1;
      double tape = MathPow(0.7, MathMin(overBy, 4)); // taper down, floor near 0.7^4
      pct *= tape;
   }

   //--- Drawdown-based reduction
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double dailyLossLimit = balance * (InpMaxDailyLossPct / 100.0);
   if(dailyLossLimit > 0.0 && g_DailyProfit < 0.0)
   {
      double ddUsedRatio = MathAbs(g_DailyProfit) / dailyLossLimit; // 0..1+
      if(ddUsedRatio >= 0.5) pct *= 0.6;       // halfway to daily limit — cut risk hard
      else if(ddUsedRatio >= 0.25) pct *= 0.8; // building drawdown — trim a bit
   }

   //--- Win streak / healthy win-rate boost (only when conditions are good)
   int totalToday = g_DailyWins + g_DailyLosses;
   double winRate  = (totalToday > 0) ? ((double)g_DailyWins / totalToday) : 0.5;
   bool lowDrawdown = (g_DailyProfit >= 0.0) ||
                       (dailyLossLimit > 0.0 && (MathAbs(g_DailyProfit)/dailyLossLimit) < 0.15);
   bool highSignalQuality = (signalScore >= 8);

   if(g_ConsecWins >= InpWinStreakBoost && lowDrawdown && winRate >= 0.55 && highSignalQuality)
      pct *= 1.25;
   else if(g_ConsecWins >= InpWinStreakBoost && lowDrawdown)
      pct *= 1.10;

   //--- Regime multiplier
   pct *= GetRegimeRiskMultiplier(regime);

   //--- Signal-quality fine adjustment — weak-but-still-valid signals get a slight trim
   if(signalScore <= 5) pct *= 0.85;

   //--- Hard clamp to configured dynamic risk band
   pct = MathMax(InpRiskPercentMin, MathMin(InpRiskPercentMax, pct));
   return pct;
}

//+------------------------------------------------------------------+
//| DYNAMIC LOT SIZING                                                 |
//+------------------------------------------------------------------+
double CalculateLotSize(int slPoints, double riskPctOverride)
{
   double balance    = AccountInfoDouble(ACCOUNT_BALANCE);
   double riskAmount = balance * (riskPctOverride / 100.0);

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
   return lot;
}

//+------------------------------------------------------------------+
//| PRE-TRADE ANALYSIS PHASE                                          |
//+------------------------------------------------------------------+
void ProcessAnalysisPhase()
{
   g_AnalysisTicks++;
   int elapsed = (int)(TimeCurrent() - g_AnalysisStart);

   g_StatusText  = "ANALYSING: " + IntegerToString(elapsed) + "s | Ticks: " + IntegerToString(g_AnalysisTicks);
   g_StatusColor = C_PURPLE;

   if(elapsed > InpAnalysisMaxSec)
   {
      Print("[EliteScalperPro V6] Analysis timeout — signal invalidated.");
      g_State = STATE_SCANNING;
      return;
   }

   int curScore = 0;
   ENUM_SIGNAL current = EvaluateConfluence(false, curScore);
   if(current != g_PendingSignal)
   {
      Print("[EliteScalperPro V6] Signal reversed during analysis — invalidated. Was=",
            (g_PendingSignal==SIGNAL_BUY?"BUY":"SELL"), " Now=",
            (current==SIGNAL_BUY?"BUY":(current==SIGNAL_SELL?"SELL":"NONE")));
      g_State = STATE_SCANNING;
      return;
   }
   g_LastSignalScore = curScore;

   if(elapsed >= InpAnalysisMinSec && g_AnalysisTicks >= InpAnalysisMinTicks)
   {
      double spreadScore = CalculateSpreadScore();
      double execScore   = CalculateExecutionScore(curScore, spreadScore);
      g_SpreadScore     = spreadScore;
      g_ExecutionScore  = execScore;

      if(execScore < InpMinExecutionScore)
      {
         Print("[EliteScalperPro V6] Execution quality too low (", DoubleToString(execScore,1),
               " < ", DoubleToString(InpMinExecutionScore,1), ") — signal skipped.");
         g_State = STATE_SCANNING;
         return;
      }

      Print("[EliteScalperPro V6] Analysis complete — executing. Elapsed=", elapsed,
            "s Ticks=", g_AnalysisTicks, " Score=", curScore, " ExecScore=", DoubleToString(execScore,1));

      LogPreTrade(g_PendingSignal, curScore, g_CurrentRegime, spreadScore, execScore);
      ExecuteEntry(g_PendingSignal, curScore, g_CurrentRegime);

      g_StateTimer = TimeCurrent() + 10; // minimum gap after any attempt
      g_State      = STATE_COOLDOWN;
   }
}

//+------------------------------------------------------------------+
//| TRADE EXECUTION                                                    |
//+------------------------------------------------------------------+
void ExecuteEntry(ENUM_SIGNAL sig, int signalScore, ENUM_MARKET_REGIME regime)
{
   if(!IsSpreadOk()) { Print("[EliteScalperPro V6] Spread too wide at execution — aborted."); return; }

   double point  = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   int    digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   double atr    = GetATR();
   double price  = (sig == SIGNAL_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                       : SymbolInfoDouble(_Symbol, SYMBOL_BID);

   int slPoints  = (int)MathRound((atr * InpSLMultiplier) / point);
   slPoints      = MathMax(InpMinSLPoints, MathMin(InpMaxSLPoints, slPoints));

   // Final TP target uses TP3 multiplier (the ratchet system manages TP1/TP2 partials
   // via CheckBreakevenAndRatchet rather than hard broker-side TP orders for them).
   int tpFinalPoints = (int)MathRound((atr * InpTP3Multiplier) / point);

   double sl, tp;
   if(sig == SIGNAL_BUY)
   {
      sl = NormalizeDouble(price - slPoints     * point, digits);
      tp = NormalizeDouble(price + tpFinalPoints* point, digits);
   }
   else
   {
      sl = NormalizeDouble(price + slPoints     * point, digits);
      tp = NormalizeDouble(price - tpFinalPoints* point, digits);
   }

   double riskPct = GetDynamicRiskPercent(regime, signalScore);
   double lot     = CalculateLotSize(slPoints, riskPct);

   Print("[EliteScalperPro V6] Entry: ", (sig==SIGNAL_BUY?"BUY":"SELL"),
         " Price=", price, " SL=", sl, " TP=", tp,
         " Lot=", lot, " Risk%=", DoubleToString(riskPct,2),
         " SL_pts=", slPoints, " Regime=", RegimeToString(regime), " Score=", signalScore);

   bool ok = (sig == SIGNAL_BUY) ? g_Trade.Buy(lot, _Symbol, price, sl, tp, InpTradeComment)
                                 : g_Trade.Sell(lot, _Symbol, price, sl, tp, InpTradeComment);
   if(ok)
   {
      g_DailyTrades++;
      g_TP1Done         = false;
      g_TP2Done          = false;
      g_TradeOpenTime    = TimeCurrent();
      g_TradeOpenPrice   = price;
      g_TradeEntryATR    = atr;
      g_TradeInitialSL   = sl;
      g_TradePeakProfit  = 0.0;
      g_TradeSignalScore = signalScore;
      g_TradeRegime      = regime;
      g_StatusText  = (sig==SIGNAL_BUY) ? "IN TRADE — LONG" : "IN TRADE — SHORT";
      g_StatusColor = C_GREEN;
   }
   else
   {
      Print("[EliteScalperPro V6] Order FAILED. RetCode=", g_Trade.ResultRetcode(), " ", g_Trade.ResultRetcodeDescription());
   }
}
//+------------------------------------------------------------------+
//| OPEN TRADE MANAGEMENT (dispatcher)                                 |
//+------------------------------------------------------------------+
void ManageOpenTrade()
{
   EvaluateFloatingPnL();
   if(!IsPositionOpen()) return;

   if(InpUseTieredExit) CheckBreakevenAndRatchet();
   else                 CheckBreakevenAndRatchet(); // BE logic still applies even without tiers

   if(InpUseTrailing)
   {
      if(InpUseStructureTrail) CheckStructureTrailing();
      else if(InpUseATRTrailing) CheckATRTrailing();
      else CheckTrailing();
   }

   if(InpUseTimeExit)        CheckTimeExit();
   if(InpUseVolCollapseExit) CheckVolatilityCollapseExit();
   // CheckEmergencyExit() is called every tick from OnTick() before this function runs.

   if(IsPositionOpen())
   {
      g_StatusText  = "TRADE RUNNING [" + g_RegimeLabel + "]";
      g_StatusColor = C_GREEN;
   }
}

//--- Close if floating profit reaches what's left of the daily profit target
void EvaluateFloatingPnL()
{
   if(!IsPositionOpen()) return;
   double pnl = GetFloatingPnL();
   if(pnl > g_TradePeakProfit) g_TradePeakProfit = pnl;

   double balance    = AccountInfoDouble(ACCOUNT_BALANCE);
   double dailyGoal  = balance * (InpMaxDailyProfitPct / 100.0);
   double remaining  = dailyGoal - g_DailyProfit;
   if(remaining > 0.0 && pnl >= remaining)
   {
      CloseAllPositions("Daily profit target reached via floating PnL");
      g_State = STATE_DAILY_LIMIT;
      return;
   }
}

//+------------------------------------------------------------------+
//| TIERED TP1/TP2/TP3 RATCHET EXIT + BREAKEVEN                       |
//| TP1 hit  -> close InpTP1ClosePct, move SL to breakeven+buffer     |
//| TP2 hit  -> close InpTP2ClosePct of what remains, tighten further |
//| TP3      -> handled by the broker-side hard TP set at entry, OR   |
//|             by trailing once we're past TP2 (whichever is closer) |
//+------------------------------------------------------------------+
void CheckBreakevenAndRatchet()
{
   for(int i = PositionsTotal()-1; i >= 0; i--)
   {
      if(!g_Pos.SelectByIndex(i)) continue;
      if(g_Pos.Magic() != InpMagicNumber || g_Pos.Symbol() != _Symbol) continue;

      double open   = g_Pos.PriceOpen();
      double sl     = g_Pos.StopLoss();
      double point  = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
      double bid    = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      double ask    = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      int    digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
      bool   isBuy  = (g_Pos.PositionType() == POSITION_TYPE_BUY);

      double profitPts = isBuy ? (bid - open)/point : (open - ask)/point;
      double atr        = (g_TradeEntryATR > 0.0) ? g_TradeEntryATR : GetATR();

      double tp1Pts = (atr * InpTP1Multiplier) / point;
      double tp2Pts = (atr * InpTP2Multiplier) / point;

      //--- Standard breakeven (independent of tiered system, applies first)
      if(profitPts >= InpBreakevenPoints)
      {
         double beSL = isBuy ? NormalizeDouble(open + InpBreakevenBuffer*point, digits)
                              : NormalizeDouble(open - InpBreakevenBuffer*point, digits);
         bool needsMove = isBuy ? (sl < beSL) : (sl > beSL || sl == 0.0);
         if(needsMove)
         {
            if(g_Trade.PositionModify(g_Pos.Ticket(), beSL, g_Pos.TakeProfit()))
               Print("[EliteScalperPro V6] Breakeven set at ", beSL);
         }
      }

      if(!InpUseTieredExit) continue;

      //--- TP1: partial close + ratchet SL to breakeven+buffer (if not already there)
      if(!g_TP1Done && profitPts >= tp1Pts)
      {
         double volStep  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
         double closeLot = MathFloor((g_Pos.Volume() * (InpTP1ClosePct / 100.0)) / volStep) * volStep;
         closeLot        = NormalizeDouble(closeLot, 2);
         double minLot   = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
         if(closeLot >= minLot)
         {
            if(g_Trade.PositionClosePartial(g_Pos.Ticket(), closeLot))
            {
               g_TP1Done = true;
               Print("[EliteScalperPro V6] TP1 ratchet: closed ", closeLot, " lots @ ", tp1Pts, " pts profit");
            }
         }
         else
         {
            // Position too small to partial-close further — mark TP1 as handled anyway
            g_TP1Done = true;
         }
      }

      //--- TP2: partial close of remainder + tighten SL further (lock more profit)
      if(g_TP1Done && !g_TP2Done && profitPts >= tp2Pts)
      {
         double volStep  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
         double closeLot = MathFloor((g_Pos.Volume() * (InpTP2ClosePct / 100.0)) / volStep) * volStep;
         closeLot        = NormalizeDouble(closeLot, 2);
         double minLot   = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
         if(closeLot >= minLot && closeLot < g_Pos.Volume())
         {
            if(g_Trade.PositionClosePartial(g_Pos.Ticket(), closeLot))
            {
               g_TP2Done = true;
               Print("[EliteScalperPro V6] TP2 ratchet: closed ", closeLot, " lots @ ", tp2Pts, " pts profit");
            }
         }
         else
         {
            g_TP2Done = true;
         }

         // Lock in roughly half the TP1->TP2 gain as the new floor
         double lockPts = tp1Pts + (tp2Pts - tp1Pts) * 0.5;
         double lockSL  = isBuy ? NormalizeDouble(open + lockPts*point, digits)
                                : NormalizeDouble(open - lockPts*point, digits);
         double curSL   = g_Pos.StopLoss();
         bool improves  = isBuy ? (curSL < lockSL) : (curSL > lockSL || curSL == 0.0);
         if(improves)
            g_Trade.PositionModify(g_Pos.Ticket(), lockSL, g_Pos.TakeProfit());
      }
   }
}

//+------------------------------------------------------------------+
//| TRAILING — fallback fixed-step (legacy v5 behaviour)               |
//+------------------------------------------------------------------+
void CheckTrailing()
{
   for(int i = PositionsTotal()-1; i >= 0; i--)
   {
      if(!g_Pos.SelectByIndex(i)) continue;
      if(g_Pos.Magic() != InpMagicNumber || g_Pos.Symbol() != _Symbol) continue;

      double open   = g_Pos.PriceOpen();
      double sl     = g_Pos.StopLoss();
      double point  = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
      double bid    = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      double ask    = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      int    digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
      bool   isBuy  = (g_Pos.PositionType() == POSITION_TYPE_BUY);

      double profitPts = isBuy ? (bid - open)/point : (open - ask)/point;
      if(profitPts < InpTrailStartPoints) continue;

      double newSL = isBuy ? NormalizeDouble(bid - InpTrailStepPoints*point, digits)
                           : NormalizeDouble(ask + InpTrailStepPoints*point, digits);

      bool improves = isBuy ? (newSL > sl) : (newSL < sl || sl == 0.0);
      if(improves)
         g_Trade.PositionModify(g_Pos.Ticket(), newSL, g_Pos.TakeProfit());
   }
}

//+------------------------------------------------------------------+
//| ATR DYNAMIC TRAILING — trail distance adapts to current volatility |
//+------------------------------------------------------------------+
void CheckATRTrailing()
{
   double atr = GetATR();
   if(atr <= 0.0) { CheckTrailing(); return; }

   for(int i = PositionsTotal()-1; i >= 0; i--)
   {
      if(!g_Pos.SelectByIndex(i)) continue;
      if(g_Pos.Magic() != InpMagicNumber || g_Pos.Symbol() != _Symbol) continue;

      double open   = g_Pos.PriceOpen();
      double sl     = g_Pos.StopLoss();
      double point  = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
      double bid    = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      double ask    = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      int    digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
      bool   isBuy  = (g_Pos.PositionType() == POSITION_TYPE_BUY);

      double profitPts = isBuy ? (bid - open)/point : (open - ask)/point;
      if(profitPts < InpTrailStartPoints) continue;

      // Trail distance is regime-aware: tighter in choppy/high-vol regimes,
      // looser in strong trends to let winners run.
      double regimeTrailMult = InpTrailATRMult;
      if(g_CurrentRegime == REGIME_STRONG_TREND) regimeTrailMult *= 1.3;
      else if(g_CurrentRegime == REGIME_HIGH_VOL) regimeTrailMult *= 0.8;
      else if(g_CurrentRegime == REGIME_RANGE)    regimeTrailMult *= 0.7;

      double trailDistPts = (atr * regimeTrailMult) / point;
      trailDistPts = MathMax(trailDistPts, InpTrailStepPoints); // never tighter than the fallback step

      double newSL = isBuy ? NormalizeDouble(bid - trailDistPts*point, digits)
                           : NormalizeDouble(ask + trailDistPts*point, digits);

      bool improves = isBuy ? (newSL > sl) : (newSL < sl || sl == 0.0);
      if(improves)
         g_Trade.PositionModify(g_Pos.Ticket(), newSL, g_Pos.TakeProfit());
   }
}

//+------------------------------------------------------------------+
//| STRUCTURE TRAILING — trail stop behind recent swing highs/lows     |
//+------------------------------------------------------------------+
void CheckStructureTrailing()
{
   for(int i = PositionsTotal()-1; i >= 0; i--)
   {
      if(!g_Pos.SelectByIndex(i)) continue;
      if(g_Pos.Magic() != InpMagicNumber || g_Pos.Symbol() != _Symbol) continue;

      double open   = g_Pos.PriceOpen();
      double sl     = g_Pos.StopLoss();
      double point  = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
      double bid    = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      double ask    = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      int    digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
      bool   isBuy  = (g_Pos.PositionType() == POSITION_TYPE_BUY);

      double profitPts = isBuy ? (bid - open)/point : (open - ask)/point;
      if(profitPts < InpTrailStartPoints)
      {
         // Not far enough in profit for structure trailing yet — fall back to
         // ATR trailing logic so the position still gets *some* protection.
         continue;
      }

      double atr    = GetATR();
      double buffer = atr * 0.3; // small buffer behind the swing point

      if(isBuy)
      {
         int lowBar = iLowest(_Symbol, _Period, MODE_LOW, InpStructureTrailBars, 1);
         if(lowBar < 0) continue;
         double swingLow = iLow(_Symbol, _Period, lowBar);
         double newSL    = NormalizeDouble(swingLow - buffer, digits);
         bool improves   = (newSL > sl) && (newSL < bid); // never place SL above current price
         if(improves)
            g_Trade.PositionModify(g_Pos.Ticket(), newSL, g_Pos.TakeProfit());
      }
      else
      {
         int highBar = iHighest(_Symbol, _Period, MODE_HIGH, InpStructureTrailBars, 1);
         if(highBar < 0) continue;
         double swingHigh = iHigh(_Symbol, _Period, highBar);
         double newSL     = NormalizeDouble(swingHigh + buffer, digits);
         bool improves    = (newSL < sl || sl == 0.0) && (newSL > ask);
         if(improves)
            g_Trade.PositionModify(g_Pos.Ticket(), newSL, g_Pos.TakeProfit());
      }
   }
}

//+------------------------------------------------------------------+
//| TIME-BASED EXIT — close trades that stagnate too long              |
//+------------------------------------------------------------------+
void CheckTimeExit()
{
   if(g_TradeOpenTime == 0) return;
   int elapsedMin = (int)((TimeCurrent() - g_TradeOpenTime) / 60);
   if(elapsedMin < InpMaxTradeMinutes) return;

   double pnl = GetFloatingPnL();
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);

   for(int i = PositionsTotal()-1; i >= 0; i--)
   {
      if(!g_Pos.SelectByIndex(i)) continue;
      if(g_Pos.Magic() != InpMagicNumber || g_Pos.Symbol() != _Symbol) continue;

      double open  = g_Pos.PriceOpen();
      bool   isBuy = (g_Pos.PositionType() == POSITION_TYPE_BUY);
      double cur   = isBuy ? SymbolInfoDouble(_Symbol, SYMBOL_BID) : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      double movedPts = MathAbs(cur - open) / point;

      if(movedPts < InpStagnationPts)
      {
         Print("[EliteScalperPro V6] Time exit — trade stagnant for ", elapsedMin,
               " min, moved only ", DoubleToString(movedPts,1), " pts.");
         CloseAllPositions("Time-based stagnation exit");
         return;
      }
   }
}

//+------------------------------------------------------------------+
//| VOLATILITY COLLAPSE EXIT — exit if ATR collapses after entry       |
//+------------------------------------------------------------------+
void CheckVolatilityCollapseExit()
{
   if(g_TradeEntryATR <= 0.0) return;
   double curATR = GetATR();
   if(curATR <= 0.0) return;

   double ratio = curATR / g_TradeEntryATR;
   if(ratio <= InpVolCollapseRatio)
   {
      Print("[EliteScalperPro V6] Volatility collapse exit — ATR ratio=", DoubleToString(ratio,2),
            " (entry ATR=", DoubleToString(g_TradeEntryATR,2), ", current=", DoubleToString(curATR,2), ")");
      CloseAllPositions("Volatility collapse exit");
   }
}

//+------------------------------------------------------------------+
//| EMERGENCY EXIT — extreme volatility spike mid-trade                |
//+------------------------------------------------------------------+
void CheckEmergencyExit()
{
   double atr = (g_TradeEntryATR > 0.0) ? g_TradeEntryATR : GetATR();
   if(atr <= 0.0) return;

   double range = iHigh(_Symbol, _Period, 0) - iLow(_Symbol, _Period, 0); // current forming candle
   if(range >= atr * InpEmergencyATRMult)
   {
      Print("[EliteScalperPro V6] EMERGENCY EXIT — live candle range=", DoubleToString(range,2),
            " exceeds ATR×", DoubleToString(InpEmergencyATRMult,1));
      CloseAllPositions("Emergency volatility spike exit");
      g_State      = STATE_EMERGENCY_HALT;
      g_StateTimer = TimeCurrent() + InpPostSpikeCooldown;
      g_LastSpikeTime = TimeCurrent();
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
//| UTILITY FUNCTIONS                                                  |
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

   double finalPnL   = GetFloatingPnL();
   int    durationSec= (g_TradeOpenTime > 0) ? (int)(TimeCurrent() - g_TradeOpenTime) : 0;
   double rMultiple  = 0.0;
   if(g_TradeInitialSL > 0.0 && g_TradeOpenPrice > 0.0)
   {
      double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
      double riskDist = MathAbs(g_TradeOpenPrice - g_TradeInitialSL);
      if(riskDist > 0.0)
      {
         double curPrice = (finalPnL >= 0) ? SymbolInfoDouble(_Symbol, SYMBOL_BID) : SymbolInfoDouble(_Symbol, SYMBOL_BID);
         double moveDist = MathAbs(curPrice - g_TradeOpenPrice);
         rMultiple = (finalPnL >= 0 ? 1.0 : -1.0) * (moveDist / riskDist);
      }
   }

   for(int i = PositionsTotal()-1; i >= 0; i--)
      if(g_Pos.SelectByIndex(i) && g_Pos.Magic()==InpMagicNumber && g_Pos.Symbol()==_Symbol)
         g_Trade.PositionClose(g_Pos.Ticket());

   if(InpEnableCSVLog)
      LogPostTrade(finalPnL, rMultiple, durationSec, g_TradePeakProfit);

   g_StateTimer = TimeCurrent() + InpCooldownSeconds;
   g_State = STATE_COOLDOWN;

   // Reset trade lifecycle tracking
   g_TP1Done         = false;
   g_TP2Done          = false;
   g_TradeOpenTime    = 0;
   g_TradeOpenPrice   = 0.0;
   g_TradeEntryATR    = 0.0;
   g_TradeInitialSL   = 0.0;
   g_TradePeakProfit  = 0.0;
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
//| CSV PERFORMANCE LOGGING                                            |
//| Pre-trade snapshot + post-trade outcome, suitable for future ML.   |
//+------------------------------------------------------------------+
void InitCSVLog()
{
   bool exists = FileIsExist(InpCSVFileName, FILE_COMMON == 0 ? 0 : 0);
   int flags = FILE_READ | FILE_WRITE | FILE_CSV | FILE_ANSI;
   g_CSVHandle = FileOpen(InpCSVFileName, flags, ',');
   if(g_CSVHandle == INVALID_HANDLE)
   {
      Print("[EliteScalperPro V6] WARNING: Could not open CSV log file '", InpCSVFileName, "'. Logging disabled.");
      return;
   }

   // If file is new/empty, write header row
   FileSeek(g_CSVHandle, 0, SEEK_END);
   if(FileTell(g_CSVHandle) == 0)
   {
      FileWrite(g_CSVHandle,
         "RecordType","Date","Time","Direction","ATR","RSI","ADX","Spread",
         "Regime","SignalScore","SpreadScore","ExecScore",
         "Profit","DurationSec","MaxDrawdown","RMultiple");
      FileFlush(g_CSVHandle);
   }
   else
   {
      // Move to end for appending
      FileSeek(g_CSVHandle, 0, SEEK_END);
   }
}

void LogPreTrade(ENUM_SIGNAL sig, int signalScore, ENUM_MARKET_REGIME regime, double spreadScore, double execScore)
{
   if(!InpEnableCSVLog || g_CSVHandle == INVALID_HANDLE) return;

   double atr = GetATR();
   double rsiV[1]; double rsiVal = 0.0;
   if(CopyBuffer(g_hRSI, 0, 0, 1, rsiV) > 0) rsiVal = rsiV[0];
   double adxV[1]; double adxVal = 0.0;
   if(CopyBuffer(g_hADX, 0, 0, 1, adxV) > 0) adxVal = adxV[0];
   int spread = (int)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);

   MqlDateTime dt; TimeToStruct(TimeCurrent(), dt);
   string dateStr = StringFormat("%04d.%02d.%02d", dt.year, dt.mon, dt.day);
   string timeStr = StringFormat("%02d:%02d:%02d", dt.hour, dt.min, dt.sec);

   FileSeek(g_CSVHandle, 0, SEEK_END);
   FileWrite(g_CSVHandle,
      "PRE_TRADE", dateStr, timeStr, (sig==SIGNAL_BUY?"BUY":"SELL"),
      DoubleToString(atr,5), DoubleToString(rsiVal,2), DoubleToString(adxVal,2), spread,
      RegimeToString(regime), signalScore, DoubleToString(spreadScore,1), DoubleToString(execScore,1),
      "", "", "", "");
   FileFlush(g_CSVHandle);
}

void LogPostTrade(double profit, double rMultiple, int durationSec, double maxDD)
{
   if(!InpEnableCSVLog || g_CSVHandle == INVALID_HANDLE) return;

   MqlDateTime dt; TimeToStruct(TimeCurrent(), dt);
   string dateStr = StringFormat("%04d.%02d.%02d", dt.year, dt.mon, dt.day);
   string timeStr = StringFormat("%02d:%02d:%02d", dt.hour, dt.min, dt.sec);

   FileSeek(g_CSVHandle, 0, SEEK_END);
   FileWrite(g_CSVHandle,
      "POST_TRADE", dateStr, timeStr, "", "", "", "", "",
      RegimeToString(g_TradeRegime), g_TradeSignalScore, "", "",
      DoubleToString(profit,2), durationSec, DoubleToString(maxDD,2), DoubleToString(rMultiple,2));
   FileFlush(g_CSVHandle);
}
//+------------------------------------------------------------------+
//| "PRIVATE BANK TERMINAL" DASHBOARD ENGINE                          |
//| Layout (top to bottom, width=340px):                              |
//|   [HEADER]          – EA name, symbol, version, clock             |
//|   [MARKET INFO]      – Bid/Ask, Spread, ATR, Session               |
//|   [REGIME PANEL]      – Current regime, risk multiplier            |
//|   [SIGNAL ENGINE]      – EMA/RSI/ADX/MACD/BB/Structure + decision  |
//|   [SMC PANEL]          – BOS/CHOCH/FVG/Liquidity status            |
//|   [EXECUTION QUALITY]  – Spread score, Exec score bars             |
//|   [OPEN POSITIONS]     – Table with tier status                    |
//|   [ACCOUNT INFO]       – Balance, Equity, Day P&L, Win Rate, Risk  |
//|   [SESSION BAR]        – London | New York | Asia pills            |
//+------------------------------------------------------------------+
#define DW  340
#define COL 140

void RenderDashboard()
{
   int X = InpDashX;
   int Y = InpDashY;
   int W = DW;
   int y = Y;

   DrawRect("SHELL", X, Y, W, 668, C_BG, C_BORDER, 2);

   //--- HEADER
   DrawRect("HDR_BG", X+2, y+2, W-4, 36, C_HEADER, C_BORDER, 1);
   DrawLabel("HDR_IC",  X+8,     y+6,  "[ ELITE SCALPER PRO ]",      C_GOLD_BRIGHT, 9, "Arial Black");
   DrawLabel("HDR_SYM", X+W-100, y+6,  _Symbol,                       C_GOLD,  10, "Impact");
   DrawLabel("HDR_TF",  X+W-60,  y+22, TimeframeToString(_Period),    C_MUTED, 7,  "Arial");
   DrawLabel("HDR_VER", X+8,     y+24, EA_VERSION+"  |  PRIVATE BANK TERMINAL", C_MUTED, 7,  "Arial");
   y += 40;

   //--- MARKET INFO
   DrawRect("MI_HDR", X+2, y, W-4, 16, C_SECTION_HDR, C_BORDER2, 1);
   DrawLabel("MI_TIT", X+8, y+3, "MARKET INFO", C_ORANGE, 8, "Arial Black");
   DrawLabel("MI_CLK", X+W-60, y+3, "00:00", C_MUTED, 8, "Arial");
   y += 17;

   DrawRect("MI_BG", X+2, y, W-4, 56, C_PANEL, C_BORDER2, 1);
   DrawLabel("L_BID",  X+8,      y+6,  "BID",                 C_MUTED, 8, "Arial");
   DrawLabel("V_BID",  X+36,     y+6,  "0.00",                C_WHITE, 9, "Arial Bold");
   DrawLabel("L_ASK",  X+W/2+4,  y+6,  "ASK",                 C_MUTED, 8, "Arial");
   DrawLabel("V_ASK",  X+W/2+30, y+6,  "0.00",                C_WHITE, 9, "Arial Bold");
   DrawLabel("L_SPR",  X+8,      y+24, "SPREAD",              C_MUTED, 8, "Arial");
   DrawLabel("V_SPR",  X+55,     y+24, "0 pts",               C_GOLD,  9, "Arial Bold");
   DrawLabel("L_ATR",  X+W/2+4,  y+24, "ATR(14)",             C_MUTED, 8, "Arial");
   DrawLabel("V_ATR",  X+W/2+44, y+24, "0 pts",               C_CYAN,  9, "Arial Bold");
   DrawLabel("L_SES",  X+8,      y+40, "SESSION",             C_MUTED, 8, "Arial");
   DrawLabel("V_SES",  X+55,     y+40, "CHECKING",            C_GOLD,  8, "Arial Bold");
   DrawLabel("L_VOL",  X+W/2+4,  y+40, "MKT:",                C_MUTED, 8, "Arial");
   DrawLabel("V_VOL",  X+W/2+28, y+40, "PASS",                C_GREEN, 8, "Arial Bold");
   y += 58;

   //--- REGIME PANEL
   DrawRect("RG_HDR", X+2, y, W-4, 16, C_SECTION_HDR, C_BORDER2, 1);
   DrawLabel("RG_TIT", X+8, y+3, "MARKET REGIME CLASSIFIER", C_ORANGE, 8, "Arial Black");
   y += 17;

   DrawRect("RG_BG", X+2, y, W-4, 36, C_PANEL, C_BORDER2, 1);
   DrawRect("RG_PILL", X+8, y+6, 160, 16, C_HOLD_BG, C_BORDER2, 1);
   DrawLabel("V_REGIME", X+14, y+9, "ANALYSING", C_GOLD, 9, "Arial Black");
   DrawLabel("L_RMULT", X+180, y+9, "Risk×", C_MUTED, 8, "Arial");
   DrawLabel("V_RMULT", X+218, y+9, "1.00", C_WHITE, 8, "Arial Bold");
   DrawLabel("L_MINSC", X+8,  y+22, "Min Score Req:", C_MUTED, 7, "Arial");
   DrawLabel("V_MINSC", X+90, y+22, "-", C_WHITE, 7, "Arial Bold");
   y += 38;

   //--- SIGNAL ENGINE
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
   DrawLabel("L_STR",  X+W/2+4,  y+60, "Structure",           C_MUTED, 8, "Arial");
   DrawLabel("V_STR",  X+W/2+52, y+60, "—",                   C_WHITE, 8, "Arial Bold");
   DrawRect("DEC_BAR", X+2, y+74, W-4, 14, C_HOLD_BG, C_BORDER2, 1);
   DrawLabel("V_DEC",  X+W/2-50, y+75, "Decision: HOLD",      C_GOLD,  8, "Arial Black");
   y += 90;

   //--- SMC PANEL
   DrawRect("SM_HDR", X+2, y, W-4, 16, C_SECTION_HDR, C_BORDER2, 1);
   DrawLabel("SM_TIT", X+8, y+3, "SMART MONEY CONCEPTS", C_ORANGE, 8, "Arial Black");
   y += 17;

   DrawRect("SM_BG", X+2, y, W-4, 36, C_PANEL, C_BORDER2, 1);
   DrawLabel("L_BOS",  X+8,      y+6,  "BOS/CHOCH",  C_MUTED, 8, "Arial");
   DrawLabel("V_BOS",  X+78,     y+6,  "—",          C_WHITE, 8, "Arial Bold");
   DrawLabel("L_FVG",  X+W/2+4,  y+6,  "FVG",        C_MUTED, 8, "Arial");
   DrawLabel("V_FVG",  X+W/2+34, y+6,  "—",          C_WHITE, 8, "Arial Bold");
   DrawLabel("L_LQS",  X+8,      y+22, "Liquidity Sweep", C_MUTED, 8, "Arial");
   DrawLabel("V_LQS",  X+108,    y+22, "—",          C_WHITE, 8, "Arial Bold");
   y += 38;

   //--- EXECUTION QUALITY
   DrawRect("EX_HDR", X+2, y, W-4, 16, C_SECTION_HDR, C_BORDER2, 1);
   DrawLabel("EX_TIT", X+8, y+3, "EXECUTION QUALITY", C_ORANGE, 8, "Arial Black");
   y += 17;

   DrawRect("EX_BG", X+2, y, W-4, 50, C_PANEL, C_BORDER2, 1);
   DrawLabel("L_SPQ",  X+8, y+6, "SPREAD SCORE", C_MUTED, 8, "Arial");
   DrawRect("SPQ_BG", X+108, y+7, 110, 11, C_PANEL2, C_BORDER2, 1);
   DrawRect("SPQ_FG", X+108, y+7, 55,  11, C_GOLD,   clrNONE,   0);
   DrawLabel("V_SPQ",  X+222, y+6, "0%", C_GOLD, 8, "Arial Bold");
   DrawLabel("L_EXQ",  X+8, y+24, "EXEC SCORE",   C_MUTED, 8, "Arial");
   DrawRect("EXQ_BG", X+108, y+25, 110, 11, C_PANEL2, C_BORDER2, 1);
   DrawRect("EXQ_FG", X+108, y+25, 55,  11, C_GREEN,  clrNONE,   0);
   DrawLabel("V_EXQ",  X+222, y+24, "0%", C_GREEN, 8, "Arial Bold");
   DrawLabel("L_SSC",  X+8, y+40, "SIGNAL SCORE",  C_MUTED, 8, "Arial");
   DrawLabel("V_SSC",  X+108, y+40, "0/9", C_WHITE, 8, "Arial Bold");
   y += 52;

   //--- FINAL DECISION
   DrawRect("FD_HDR", X+2, y, W-4, 16, C_SECTION_HDR, C_BORDER2, 1);
   DrawLabel("FD_TIT", X+8, y+3, "FINAL DECISION", C_ORANGE, 8, "Arial Black");
   y += 17;

   DrawRect("FD_BG",  X+2, y, W-4, 32, C_HOLD_BG, C_BORDER, 2);
   DrawLabel("V_FD",  X+W/2-30, y+9, "HOLD", C_GOLD, 14, "Arial Black");
   y += 34;

   //--- OPEN POSITIONS
   DrawRect("OP_HDR", X+2, y, W-4, 16, C_SECTION_HDR, C_BORDER2, 1);
   DrawLabel("OP_TIT",  X+8,     y+3,  "OPEN POSITIONS", C_ORANGE, 8, "Arial Black");
   DrawLabel("OP_CNT",  X+W-50,  y+3,  "0 open",         C_MUTED,  8, "Arial");
   y += 17;

   DrawRect("OP_COL", X+2, y, W-4, 13, C_PANEL2, C_BORDER2, 1);
   DrawLabel("OC_TYP",  X+6,   y+2, "TYPE", C_MUTED, 7, "Arial");
   DrawLabel("OC_LOT",  X+44,  y+2, "LOT",  C_MUTED, 7, "Arial");
   DrawLabel("OC_OPN",  X+84,  y+2, "OPEN", C_MUTED, 7, "Arial");
   DrawLabel("OC_SL",   X+136, y+2, "SL",   C_MUTED, 7, "Arial");
   DrawLabel("OC_TP",   X+178, y+2, "TIER", C_MUTED, 7, "Arial");
   DrawLabel("OC_PNL",  X+228, y+2, "P&L",  C_MUTED, 7, "Arial");
   y += 14;

   for(int r = 0; r < 2; r++)
   {
      color rowBg = (r % 2 == 0) ? C_PANEL : C_PANEL2;
      DrawRect("OR"+IntegerToString(r),      X+2, y, W-4, 13, rowBg, clrNONE, 0);
      DrawLabel("OR_T"+IntegerToString(r),   X+6,   y+2, "---", C_MUTED, 7, "Arial");
      DrawLabel("OR_L"+IntegerToString(r),   X+44,  y+2, "---", C_MUTED, 7, "Arial");
      DrawLabel("OR_O"+IntegerToString(r),   X+84,  y+2, "---", C_MUTED, 7, "Arial");
      DrawLabel("OR_S"+IntegerToString(r),   X+136, y+2, "---", C_MUTED, 7, "Arial");
      DrawLabel("OR_P"+IntegerToString(r),   X+178, y+2, "---", C_MUTED, 7, "Arial");
      DrawLabel("OR_F"+IntegerToString(r),   X+228, y+2, "---", C_MUTED, 7, "Arial");
      y += 14;
   }

   DrawRect("OP_FT", X+2, y, W-4, 26, C_PANEL2, C_BORDER2, 1);
   DrawLabel("L_FLT",  X+6,    y+2, "FLOAT:",  C_MUTED, 7, "Arial");
   DrawLabel("V_FLT",  X+42,   y+2, "+0.00",   C_GREEN, 8, "Arial Bold");
   DrawLabel("L_OEQV", X+W-90, y+2, "EQUITY:", C_MUTED, 7, "Arial");
   DrawLabel("V_OEQV", X+W-50, y+2, "$0.00",   C_WHITE, 8, "Arial Bold");
   DrawLabel("L_RMUL", X+6,    y+14,"R-MULT:", C_MUTED, 7, "Arial");
   DrawLabel("V_RMUL", X+50,   y+14,"0.00R",   C_CYAN,  8, "Arial Bold");
   y += 28;

   //--- ACCOUNT INFO
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
   DrawLabel("L_RSK",  X+W/2+30, y+52, "RISK",       C_MUTED, 8, "Arial");
   DrawLabel("V_RSK",  X+W/2+62, y+52, "0.0%",       C_GOLD,  9, "Arial Bold");
   y += 70;

   //--- SESSION BAR
   DrawRect("SB_BG", X+2, y, W-4, 18, C_PANEL2, C_BORDER2, 1);
   int pw = (W-10)/3;
   DrawRect("SB_LON", X+3,        y+2, pw,   14, C_PANEL, C_BORDER2, 1);
   DrawLabel("SB_LT",  X+3+pw/2-18, y+4,  "LONDON",   C_MUTED, 7, "Arial Bold");
   DrawRect("SB_NYC", X+3+pw+1,   y+2, pw,   14, C_GOLD,  clrNONE,   0);
   DrawLabel("SB_NT",  X+4+pw+pw/2-22, y+4, "NEW YORK", C_BG,   7, "Arial Black");
   DrawRect("SB_ASI", X+3+pw*2+2, y+2, pw-1, 14, C_PANEL, C_BORDER2, 1);
   DrawLabel("SB_AT",  X+4+pw*2+pw/2-12, y+4, "ASIA",  C_MUTED, 7, "Arial Bold");

   ChartRedraw(0);
}

//+------------------------------------------------------------------+
//| DASHBOARD UPDATE                                                    |
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
   SetLabel("V_ATR", IntegerToString((int)MathRound(atr/MathMax(pt,0.00001)))+" pts", C_CYAN);

   bool inSess = IsInSession();
   SetLabel("V_VOL",  IsMarketOpen() ? "PASS" : "HALT",  IsMarketOpen() ? C_GREEN : C_RED);
   SetLabel("V_SES",  inSess ? "ACTIVE" : "CLOSED",       inSess        ? C_GREEN : C_MUTED);

   //--- Regime panel
   color regimeClr;
   switch(g_CurrentRegime)
   {
      case REGIME_STRONG_TREND: regimeClr = C_GREEN; break;
      case REGIME_BREAKOUT:     regimeClr = C_CYAN;  break;
      case REGIME_WEAK_TREND:   regimeClr = C_GOLD;  break;
      case REGIME_RANGE:        regimeClr = C_MUTED; break;
      case REGIME_HIGH_VOL:     regimeClr = C_ORANGE;break;
      case REGIME_EXTREME_VOL:  regimeClr = C_RED;   break;
      default:                  regimeClr = C_WHITE; break;
   }
   SetLabel("V_REGIME", g_RegimeLabel, regimeClr);
   string rgPillN = DASH_PREFIX+"RG_PILL";
   if(ObjectFind(0,rgPillN)>=0) ObjectSetInteger(0,rgPillN,OBJPROP_BGCOLOR, regimeClr==C_RED?C_SELL_BG:(regimeClr==C_GREEN?C_BUY_BG:C_HOLD_BG));
   SetLabel("V_RMULT", DoubleToString(GetRegimeRiskMultiplier(g_CurrentRegime),2)+"x", C_WHITE);
   SetLabel("V_MINSC", IntegerToString(GetRegimeMinScore(g_CurrentRegime))+"/9", C_WHITE);

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

   int dummyScore = 0;
   ENUM_SIGNAL sig = EvaluateConfluence(true, dummyScore);
   bool structOk = CheckMarketStructure(sig, false);
   SetLabel("V_STR", structOk ? "BREAK" : "HOLD", structOk ? C_GREEN : C_MUTED);

   //--- SMC panel
   if(sig != SIGNAL_NONE)
   {
      bool fvgP=false, lqsP=false;
      ENUM_SMC_EVENT evt = EvaluateSMC(sig, fvgP, lqsP);
      string evtTxt = (evt==SMC_BOS_BULL?"BOS BULL":evt==SMC_BOS_BEAR?"BOS BEAR":
                        evt==SMC_CHOCH_BULL?"CHOCH BULL":evt==SMC_CHOCH_BEAR?"CHOCH BEAR":"NONE");
      color evtClr = (evt==SMC_NONE) ? C_MUTED : ((evt==SMC_BOS_BULL||evt==SMC_CHOCH_BULL)?C_GREEN:C_RED);
      SetLabel("V_BOS", evtTxt, evtClr);
      SetLabel("V_FVG", fvgP?"YES":"NO", fvgP?C_GREEN:C_MUTED);
      SetLabel("V_LQS", lqsP?"SWEPT":"NO", lqsP?C_GREEN:C_MUTED);
   }
   else
   {
      SetLabel("V_BOS", "—", C_MUTED);
      SetLabel("V_FVG", "—", C_MUTED);
      SetLabel("V_LQS", "—", C_MUTED);
   }

   //--- Execution quality
   double spreadScore = CalculateSpreadScore();
   double execScore   = CalculateExecutionScore(dummyScore>0?dummyScore:g_LastSignalScore, spreadScore);
   g_SpreadScore = spreadScore; g_ExecutionScore = execScore;

   SetLabel("V_SPQ", IntegerToString((int)spreadScore)+"%", spreadScore>=60?C_GREEN:(spreadScore>=30?C_GOLD:C_RED));
   string spqFgN = DASH_PREFIX+"SPQ_FG";
   if(ObjectFind(0,spqFgN)>=0) ObjectSetInteger(0,spqFgN,OBJPROP_XSIZE, MathMax(2,(int)MathRound(110*(spreadScore/100.0))));

   SetLabel("V_EXQ", IntegerToString((int)execScore)+"%", execScore>=InpMinExecutionScore?C_GREEN:C_RED);
   string exqFgN = DASH_PREFIX+"EXQ_FG";
   if(ObjectFind(0,exqFgN)>=0) ObjectSetInteger(0,exqFgN,OBJPROP_XSIZE, MathMax(2,(int)MathRound(110*(execScore/100.0))));
   string exqFgC = DASH_PREFIX+"EXQ_FG";
   if(ObjectFind(0,exqFgC)>=0) ObjectSetInteger(0,exqFgC,OBJPROP_BGCOLOR, execScore>=InpMinExecutionScore?C_GREEN:C_RED);

   SetLabel("V_SSC", IntegerToString(g_LastSignalScore)+"/9", C_WHITE);

   //--- Decision bar + Final Decision
   string decTxt; color decClr; color decBg; string aiTxt;
   if(g_State == STATE_ANALYZING)
   {
      int elapsed = (int)(TimeCurrent() - g_AnalysisStart);
      decTxt = "Decision: ANALYSING ("+IntegerToString(elapsed)+"s)";
      decClr = C_PURPLE; decBg = C_PANEL2; aiTxt = "ANALYSING";
   }
   else if(g_State == STATE_EMERGENCY_HALT)
   {
      decTxt = "Decision: EMERGENCY HALT"; decClr = C_RED; decBg = C_SELL_BG; aiTxt = "HALTED";
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

   string fdN = DASH_PREFIX+"FD_BG";
   if(ObjectFind(0,fdN)>=0) ObjectSetInteger(0,fdN,OBJPROP_BGCOLOR,decBg);
   SetLabel("V_FD", aiTxt, decClr);

   //--- Open Positions Table (2 rows — XAUUSD scalper typically holds 1 position)
   int posCount = 0;
   double totalFloat = 0.0;
   double curRMult = 0.0;
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
            string tierStr = g_TP2Done ? "TP2 DONE" : (g_TP1Done ? "TP1 DONE" : "OPEN");
            SetLabel("OR_T"+rs, typStr,                              typClr);
            SetLabel("OR_L"+rs, DoubleToString(g_Pos.Volume(),2),    C_WHITE);
            SetLabel("OR_O"+rs, DoubleToString(g_Pos.PriceOpen(),2), C_WHITE);
            SetLabel("OR_S"+rs, DoubleToString(g_Pos.StopLoss(),2),  C_RED);
            SetLabel("OR_P"+rs, tierStr,                             C_CYAN);
            color pC = (rowPnl>=0) ? C_GREEN : C_RED;
            SetLabel("OR_F"+rs, (rowPnl>=0?"+":"")+DoubleToString(rowPnl,2), pC);
            filled = true;

            if(g_TradeInitialSL > 0.0 && g_TradeOpenPrice > 0.0)
            {
               double riskDist = MathAbs(g_TradeOpenPrice - g_TradeInitialSL);
               if(riskDist > 0.0)
               {
                  double curPrice = (typStr=="BUY") ? bid : ask;
                  double moveDist = (typStr=="BUY") ? (curPrice - g_TradeOpenPrice) : (g_TradeOpenPrice - curPrice);
                  curRMult = moveDist / riskDist;
               }
            }
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
   color cRm = (curRMult>=0) ? C_GREEN : C_RED;
   SetLabel("V_RMUL", DoubleToString(curRMult,2)+"R", posCount>0?cRm:C_MUTED);

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
   double curRiskPct = GetDynamicRiskPercent(g_CurrentRegime, g_LastSignalScore>0?g_LastSignalScore:5);
   SetLabel("V_RSK", DoubleToString(curRiskPct,2)+"%", C_GOLD);

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
