//+------------------------------------------------------------------+
//|                                              NOVA TITAN X.mq5    |
//|        Systematic BTCUSD Trading Framework - v1.0                |
//|        Capital Preservation | Regime Adaptive | Risk-Allocated   |
//+------------------------------------------------------------------+
//
//  ARCHITECTURE NOTE (read before editing):
//  This EA is a layered decision stack. Layers compute INFORMATION.
//  Only the Meta Router (Layer 14, added in Part 3) may authorize a
//  trade. No layer in this file places orders directly.
//
//  BUILD STATUS: Part 1 of 3
//    - Layer 1  Market Data Engine            [DONE - this file]
//    - Layer 9  Dynamic Capital Allocation     [DONE - this file]
//    - Layer 13 Capital Preservation Engine    [DONE - this file]
//    - Core dashboard shell (from legacy v5.0) [DONE - this file]
//  Remaining layers (2-8, 10-12, Meta Router) are added in Parts 2-3
//  of this same file via direct appends - this file will grow, it
//  will not be split across multiple .mq5 files, since MT5 EAs must
//  compile as a single source unit (or explicit #include set).
//
//+------------------------------------------------------------------+
#property copyright "NOVA TITAN X"
#property version   "1.00"
#property description "Systematic BTCUSD framework: regime-aware, risk-allocated, capital-preserving"
#property strict

#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>
#include <Trade\AccountInfo.mqh>
#include <Trade\OrderInfo.mqh>

//=======================================================================
//  DASHBOARD NAMESPACE / VISUAL CONSTANTS (carried forward from legacy
//  PHANTOM SCALPER v5.0 dashboard shell - colors/layout only, no logic)
//=======================================================================
#define D "NTX_"

#define C_BG0       C'4,6,18'
#define C_BG1       C'8,12,28'
#define C_BG2       C'12,18,42'
#define C_HDRBAR    C'10,16,38'
#define C_BORDER    C'22,44,90'
#define C_ACBORD    C'0,160,220'
#define C_GOLD      C'255,200,40'
#define C_CYAN      C'0,220,220'
#define C_PURPLE    C'180,100,255'
#define C_WHITE     C'220,225,240'
#define C_SUBTEXT   C'110,130,160'
#define C_GREEN     C'20,220,110'
#define C_RED       C'230,55,65'
#define C_ORANGE    C'255,145,0'
#define C_DKGREEN   C'14,80,45'
#define C_LBLUE     C'80,160,255'
#define C_DGRAY     C'40,52,72'
#define C_MGRAY     C'75,90,115'

//=======================================================================
//  ENUMS - SHARED ACROSS ALL LAYERS
//=======================================================================

// Market regime classification (Layer 2 will populate this; declared
// here because Layer 9/13 risk logic needs to reference regime state)
enum ENUM_MARKET_REGIME
{
   REGIME_UNKNOWN = 0,
   REGIME_TREND_EXPANSION,
   REGIME_TREND_EXHAUSTION,
   REGIME_RANGE,
   REGIME_TRANSITION,
   REGIME_SHOCK
};

// Volatility state (Layer 4 will populate; needed by Layer 9 sizing)
enum ENUM_VOL_STATE
{
   VOL_SUPPRESSED = 0,
   VOL_NORMAL,
   VOL_EXPANDING,
   VOL_EXTREME,
   VOL_CHAOTIC
};

// Strategy identifiers (Meta Router uses this in Part 3; declared here
// so Strategy Health tracking in Part 3 can reference a stable enum)
enum ENUM_STRATEGY_ID
{
   STRATEGY_NONE = 0,
   STRATEGY_TREND_CONTINUATION,
   STRATEGY_RANGE_REVERSION,
   STRATEGY_BREAKOUT,
   STRATEGY_LIQUIDITY_SWEEP,
   STRATEGY_MOMENTUM_EXPANSION
};

// System operating mode - drives the Self-Diagnostic / Safe Mode logic
enum ENUM_SYSTEM_MODE
{
   SYS_MODE_NORMAL = 0,
   SYS_MODE_SAFE,        // degraded - diagnostics failed, trading suspended
   SYS_MODE_LOCKED       // capital protection lock active - no new trades
};

//=======================================================================
//  INPUTS
//=======================================================================

input group "===== IDENTITY ====="
input ulong   InpMagicNumber        = 770001;
input string  InpBotName            = "NOVA TITAN X";

input group "===== CAPITAL ALLOCATION (Layer 9) ====="
input double  InpBaseRiskPct            = 0.25;  // Base risk % of equity at 0.25R tier
input double  InpMidRiskPct             = 0.50;  // Risk % of equity at 0.50R tier
input double  InpHighRiskPct            = 1.00;  // Risk % of equity at 1.0R tier
input double  InpMinProbToTrade         = 70.0;  // Below this probability score, DO_NOT_TRADE
input double  InpMidProbThreshold       = 80.0;
input double  InpHighProbThreshold      = 90.0;
input double  InpMaxRiskPctHardCap      = 2.00;  // Absolute ceiling regardless of any other factor
input bool    InpUseFixedLotInstead     = false; // Override: ignore risk%, use fixed lot below (for testing only)
input double  InpFixedLotIfOverride     = 0.01;

input group "===== EXECUTION TRANCHING (replaces legacy fixed bulk-N) ====="
input bool    InpUseTrancheExecution    = true;  // Split large positions into time-distributed entries
input int     InpMaxTranches            = 3;     // Max number of tranches for a single signal
input int     InpTrancheDelayMs         = 400;   // Delay between tranche legs (milliseconds)
input double  InpTrancheSizeThreshold   = 0.10;  // Lot size above which tranching activates (else single shot)

input group "===== CAPITAL PROTECTION (Layer 13 - highest priority) ====="
input double  InpDailyLossLockPct       = 3.0;   // % of day-start equity
input double  InpWeeklyLossLockPct      = 6.0;
input double  InpMonthlyLossLockPct     = 12.0;
input int     InpConsecutiveLossLock    = 4;      // consecutive losing trades -> lock
input double  InpEquityDrawdownLockPct  = 10.0;   // from peak equity
input double  InpMaxSpreadPoints        = 800;    // execution quality lock - spread too wide (BTC point=0.01 typical, adjust per broker)
input bool    InpEnableKillSwitch       = true;   // manual emergency stop via global variable
input string  InpKillSwitchGlobalVar    = "NTX_KILLSWITCH"; // set this GV to 1 in Terminal to force-lock

input group "===== TRADE FREQUENCY ====="
input int     InpMaxDailyTrades         = 10;
input int     InpCooldownSec            = 60;

input group "===== DASHBOARD ====="
input bool    InpShowDash               = true;
input int     InpDashX                  = 14;
input int     InpDashY                  = 14;

input group "===== DIAGNOSTICS ====="
input bool    InpVerboseLogging         = true;

//=======================================================================
//  GLOBAL OBJECTS
//=======================================================================
CTrade        g_trade;
CPositionInfo g_pos;
CAccountInfo  g_account;
COrderInfo    g_order;

const int     DW = 440;
const int     DH = 640;

//=======================================================================
//  LAYER 1 - MARKET DATA ENGINE
//  Centralized cache. No other layer may call CopyBuffer/iXxx directly
//  for these series - they read from this struct instead. This is what
//  the legacy EA got wrong (every function called CopyBuffer itself,
//  meaning indicator handles could be queried with inconsistent shifts
//  and the same bar re-read multiple times with different stale data
//  if a tick arrived mid-calculation).
//=======================================================================
struct MarketDataSnapshot
{
   // Price / OHLC (current + previous closed bar, M5 base timeframe)
   double bid;
   double ask;
   double spreadPoints;
   double open0, high0, low0, close0;      // current forming bar
   double open1, high1, low1, close1;      // last closed bar
   double open2, high2, low2, close2;      // bar before that

   // Indicators
   double atrM5;
   double atrM5_prev;
   double atrPercentile;                   // computed vs rolling history
   double adxM5;
   double rsiM5;
   double emaFastM5;
   double emaSlowM5;
   double emaM15;
   double emaH1;
   double bandsUpper, bandsMid, bandsLower;
   double macdMain, macdSignal;
   double volTickCurrent, volTickAvg;

   // Session / timing
   datetime barTime0;
   datetime serverTime;
   bool     isNewBar;

   // Validity flag - if false, downstream layers must treat this tick
   // as unusable and the Self-Diagnostic Engine should flip SAFE MODE
   bool     isValid;
};

MarketDataSnapshot g_md;          // the single shared snapshot
datetime           g_lastBarTime = 0;

// Indicator handles - owned exclusively by Layer 1
int g_h_emaFast   = INVALID_HANDLE;
int g_h_emaSlow   = INVALID_HANDLE;
int g_h_emaM15    = INVALID_HANDLE;
int g_h_emaH1     = INVALID_HANDLE;
int g_h_rsi       = INVALID_HANDLE;
int g_h_atr       = INVALID_HANDLE;
int g_h_adx       = INVALID_HANDLE;
int g_h_bands     = INVALID_HANDLE;
int g_h_macd      = INVALID_HANDLE;
int g_h_volTick   = INVALID_HANDLE;

// Rolling ATR history for percentile calc (Layer 4 will consume this,
// but the buffer is owned and maintained by Layer 1 since it is raw
// data, not derived intelligence)
#define ATR_HISTORY_LEN 200
double g_atrHistory[ATR_HISTORY_LEN];
int    g_atrHistoryCount = 0;

//=======================================================================
//  LAYER 13 STATE - CAPITAL PROTECTION ENGINE
//=======================================================================
struct CapitalProtectionState
{
   double   dayStartEquity;
   double   weekStartEquity;
   double   monthStartEquity;
   double   peakEquity;
   datetime currentDay;
   datetime currentWeekStart;
   datetime currentMonthStart;
   int      consecutiveLosses;

   bool     lockDaily;
   bool     lockWeekly;
   bool     lockMonthly;
   bool     lockConsecutive;
   bool     lockDrawdown;
   bool     lockStrategyFailure;   // wired in Part 3 (Strategy Health)
   bool     lockVolChaos;          // wired in Part 2 (Volatility Engine)
   bool     lockExecutionQuality;
   bool     lockKillSwitch;

   string   lastLockReason;
};
CapitalProtectionState g_cap;

ENUM_SYSTEM_MODE g_systemMode = SYS_MODE_NORMAL;

//=======================================================================
//  LAYER 9 STATE - DYNAMIC CAPITAL ALLOCATION ENGINE
//=======================================================================
struct RiskDecision
{
   double   probabilityScore;   // 0-100, supplied by fusion layer (Part 3). Until then, neutral 0.
   double   riskPct;            // resolved % of equity to risk
   double   lotSize;            // resolved lot size after SL distance + risk%
   bool     tradeAllowed;       // false => DO_NOT_TRADE
   string   reason;
};
RiskDecision g_riskDecision;

//=======================================================================
//  SESSION / BOOKKEEPING STATE (carried forward concept from legacy v5.0,
//  rebuilt to be regime/locks-aware rather than purely cosmetic)
//=======================================================================
datetime g_sessionDay        = 0;
int      g_sessTradesToday   = 0;
double   g_sessProfitToday   = 0.0;
int      g_sessWinsToday     = 0;
int      g_sessLossesToday   = 0;
datetime g_lastCloseTime     = 0;
bool     g_inCooldown        = false;
int      g_cooldownLeft      = 0;

string   g_statusText  = "INITIALIZING";
color    g_statusColor = C_ORANGE;
string   g_lastAction  = "Booting NOVA TITAN X...";

//=======================================================================
//  FORWARD DECLARATIONS - LAYER 1
//=======================================================================
bool     L1_InitIndicators();
void     L1_ReleaseIndicators();
bool     L1_UpdateSnapshot();
void     L1_UpdateAtrHistory(double atrValue);
double   L1_GetAtrPercentile(double currentAtr);

//=======================================================================
//  FORWARD DECLARATIONS - LAYER 9
//=======================================================================
void     L9_ResolveRisk(double probabilityScore, double slDistancePoints);
double   L9_CalcLotFromRisk(double riskPct, double slDistancePoints);

//=======================================================================
//  FORWARD DECLARATIONS - LAYER 13
//=======================================================================
void     L13_InitPeriodAnchors();
void     L13_UpdateRollover();
void     L13_EvaluateLocks();
bool     L13_AnyLockActive();
void     L13_RegisterTradeResult(double pnl);
void     L13_ResetConsecutiveLossCounter();

//=======================================================================
//  FORWARD DECLARATIONS - UTILITY / SELF-DIAGNOSTIC
//=======================================================================
bool     SelfDiagnostic_Run();
bool     IsMarketTradeable();
datetime DayStart(datetime ts);
datetime WeekStart(datetime ts);
datetime MonthStart(datetime ts);
double   NPrice(double p);
ENUM_ORDER_TYPE_FILLING GetFillMode();
void     LogVerbose(string msg);
void     BuildSessionStatsFromHistory();
void     NTX_Dispatch_OnTick();   // implemented in Part 3, below
void     L12_LoadHealth();        // implemented in Part 3, below

//=======================================================================
//  FORWARD DECLARATIONS - DASHBOARD (legacy v5.0 shell, rebuilt fields)
//=======================================================================
void InitDash();
void UpdateDash();
void DeleteDash();
void R(string nm, int x, int y, int w, int h, color bg, color brd=clrNONE, int bw=1);
void L(string nm, int x, int y, string txt, color clr, int fsz, string fnt="Arial Bold");
void U(string nm, string txt, color clr=C_WHITE);
void Bar(string nm, int x, int y, int w, int h, double pct, color fg, color bg_c);
void UpdBar(string nm, double pct, color fg);

//+------------------------------------------------------------------+
//| OnInit                                                            |
//+------------------------------------------------------------------+
int OnInit()
{
   if(StringFind(Symbol(), "BTC") < 0)
      Print("[NOVA TITAN X] Warning: chart symbol does not contain 'BTC'. This framework is tuned for BTCUSD microstructure; other symbols are not validated.");

   g_trade.SetExpertMagicNumber(InpMagicNumber);
   g_trade.SetDeviationInPoints(50);
   g_trade.SetTypeFilling(GetFillMode());
   g_trade.SetAsyncMode(false);

   if(!L1_InitIndicators())
   {
      Print("[NOVA TITAN X] FATAL: indicator initialization failed. EA will not run.");
      return INIT_FAILED;
   }

   ArrayInitialize(g_atrHistory, 0.0);
   g_atrHistoryCount = 0;

   L13_InitPeriodAnchors();
   g_sessionDay = DayStart(TimeCurrent());
   BuildSessionStatsFromHistory();
   L12_LoadHealth();

   ZeroMemory(g_riskDecision);
   g_riskDecision.reason = "Awaiting first probability score";

   if(InpShowDash) InitDash();

   EventSetTimer(1);

   g_systemMode = SYS_MODE_NORMAL;
   g_lastAction = "Initialized. Awaiting market data.";
   Print("[NOVA TITAN X] Initialized successfully. Magic=", InpMagicNumber, " Symbol=", Symbol());
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| OnDeinit                                                          |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   EventKillTimer();
   DeleteDash();
   L1_ReleaseIndicators();
}

//+------------------------------------------------------------------+
//| OnTimer - housekeeping that does not need to run every tick       |
//+------------------------------------------------------------------+
void OnTimer()
{
   if(g_lastCloseTime > 0)
   {
      int elapsed = (int)(TimeCurrent() - g_lastCloseTime);
      g_inCooldown   = (elapsed < InpCooldownSec);
      g_cooldownLeft = g_inCooldown ? (InpCooldownSec - elapsed) : 0;
   }
   else
   {
      g_inCooldown   = false;
      g_cooldownLeft = 0;
   }

   L13_UpdateRollover();
   L13_EvaluateLocks();

   if(InpShowDash) UpdateDash();
}

//+------------------------------------------------------------------+
//| OnTick - Part 1 scope: data + protection only. No trade decisions |
//| are made yet (Layers 2-12 and Meta Router land in Parts 2-3).     |
//| This function intentionally does NOT open trades in Part 1.       |
//+------------------------------------------------------------------+
void OnTick()
{
   // --- Daily rollover check (also handled in OnTimer, but OnTick is
   //     the authoritative path so a fast market doesn't miss it) ---
   datetime todayStart = DayStart(TimeCurrent());
   if(todayStart != g_sessionDay)
   {
      g_sessionDay = todayStart;
      g_sessTradesToday = 0;
      BuildSessionStatsFromHistory();
   }

   // --- Self diagnostic gate - if this fails, system enters SAFE MODE
   //     and nothing downstream is permitted to run this tick ---
   if(!SelfDiagnostic_Run())
   {
      g_systemMode = SYS_MODE_SAFE;
      g_statusText = "SAFE MODE";
      g_statusColor = C_RED;
      return;
   }

   // --- Layer 1: refresh the shared market data snapshot ---
   if(!L1_UpdateSnapshot())
   {
      g_statusText = "DATA INVALID";
      g_statusColor = C_RED;
      return;
   }

   // --- Layer 13: capital protection is evaluated before anything else
   //     is allowed to think about trading. This overrides all else. ---
   L13_EvaluateLocks();
   if(L13_AnyLockActive())
   {
      g_systemMode = SYS_MODE_LOCKED;
      g_statusText = "LOCKED: " + g_cap.lastLockReason;
      g_statusColor = C_RED;
      return;
   }
   g_systemMode = SYS_MODE_NORMAL;

   if(!IsMarketTradeable())
   {
      g_statusText = "MARKET CLOSED";
      g_statusColor = C_MGRAY;
      return;
   }

   if(g_inCooldown)
   {
      g_statusText = "COOLDOWN (" + IntegerToString(g_cooldownLeft) + "s)";
      g_statusColor = C_CYAN;
      return;
   }

   if(InpMaxDailyTrades > 0 && g_sessTradesToday >= InpMaxDailyTrades)
   {
      g_statusText = "DAILY TRADE CAP REACHED";
      g_statusColor = C_ORANGE;
      return;
   }

   // --- Dispatch to Layers 2-12 + Meta Router (defined later in this
   //     file, in Part 3). Forward-declared just above OnInit. ---
   NTX_Dispatch_OnTick();
}

//=======================================================================
//  LAYER 1 IMPLEMENTATION - MARKET DATA ENGINE
//=======================================================================
bool L1_InitIndicators()
{
   g_h_emaFast = iMA(Symbol(), PERIOD_M5, 9, 0, MODE_EMA, PRICE_CLOSE);
   g_h_emaSlow = iMA(Symbol(), PERIOD_M5, 21, 0, MODE_EMA, PRICE_CLOSE);
   g_h_emaM15  = iMA(Symbol(), PERIOD_M15, 21, 0, MODE_EMA, PRICE_CLOSE);
   g_h_emaH1   = iMA(Symbol(), PERIOD_H1, 21, 0, MODE_EMA, PRICE_CLOSE);
   g_h_rsi     = iRSI(Symbol(), PERIOD_M5, 14, PRICE_CLOSE);
   g_h_atr     = iATR(Symbol(), PERIOD_M5, 14);
   g_h_adx     = iADX(Symbol(), PERIOD_M5, 14);
   g_h_bands   = iBands(Symbol(), PERIOD_M5, 20, 0, 2.0, PRICE_CLOSE);
   g_h_macd    = iMACD(Symbol(), PERIOD_M5, 12, 26, 9, PRICE_CLOSE);
   g_h_volTick = iVolumes(Symbol(), PERIOD_M5, VOLUME_TICK);

   int handles[10] = {g_h_emaFast, g_h_emaSlow, g_h_emaM15, g_h_emaH1, g_h_rsi,
                       g_h_atr, g_h_adx, g_h_bands, g_h_macd, g_h_volTick};
   for(int i = 0; i < 10; i++)
   {
      if(handles[i] == INVALID_HANDLE)
      {
         Print("[L1] Failed to create indicator handle index ", i, " err=", GetLastError());
         return false;
      }
   }
   return true;
}

void L1_ReleaseIndicators()
{
   if(g_h_emaFast != INVALID_HANDLE) IndicatorRelease(g_h_emaFast);
   if(g_h_emaSlow != INVALID_HANDLE) IndicatorRelease(g_h_emaSlow);
   if(g_h_emaM15  != INVALID_HANDLE) IndicatorRelease(g_h_emaM15);
   if(g_h_emaH1   != INVALID_HANDLE) IndicatorRelease(g_h_emaH1);
   if(g_h_rsi     != INVALID_HANDLE) IndicatorRelease(g_h_rsi);
   if(g_h_atr     != INVALID_HANDLE) IndicatorRelease(g_h_atr);
   if(g_h_adx     != INVALID_HANDLE) IndicatorRelease(g_h_adx);
   if(g_h_bands   != INVALID_HANDLE) IndicatorRelease(g_h_bands);
   if(g_h_macd    != INVALID_HANDLE) IndicatorRelease(g_h_macd);
   if(g_h_volTick != INVALID_HANDLE) IndicatorRelease(g_h_volTick);
}

// Pulls every series ONCE per tick into the shared snapshot. All other
// layers read g_md fields only - they never call CopyBuffer themselves.
// This is the single biggest structural fix vs the legacy EA, where
// every scoring function independently called CopyBuffer and could
// read inconsistent bars relative to each other mid-tick.
bool L1_UpdateSnapshot()
{
   MarketDataSnapshot snap;
   ZeroMemory(snap);
   snap.isValid = true;

   MqlTick tick;
   if(!SymbolInfoTick(Symbol(), tick) || tick.bid <= 0 || tick.ask <= 0)
   {
      snap.isValid = false;
      g_md = snap;
      return false;
   }
   snap.bid = tick.bid;
   snap.ask = tick.ask;

   double point = SymbolInfoDouble(Symbol(), SYMBOL_POINT);
   snap.spreadPoints = (point > 0) ? (snap.ask - snap.bid) / point : 0.0;

   double o[3], h[3], l[3], c[3];
   if(CopyOpen(Symbol(), PERIOD_M5, 0, 3, o) < 3 ||
      CopyHigh(Symbol(), PERIOD_M5, 0, 3, h) < 3 ||
      CopyLow(Symbol(), PERIOD_M5, 0, 3, l) < 3 ||
      CopyClose(Symbol(), PERIOD_M5, 0, 3, c) < 3)
   {
      snap.isValid = false;
      g_md = snap;
      return false;
   }
   // CopyXxx with shift 0 returns most recent bars at the END of the
   // array (ascending time). Index [2] = current forming bar.
   snap.open0 = o[2]; snap.high0 = h[2]; snap.low0 = l[2]; snap.close0 = c[2];
   snap.open1 = o[1]; snap.high1 = h[1]; snap.low1 = l[1]; snap.close1 = c[1];
   snap.open2 = o[0]; snap.high2 = h[0]; snap.low2 = l[0]; snap.close2 = c[0];

   datetime bt[1];
   if(CopyTime(Symbol(), PERIOD_M5, 0, 1, bt) < 1) { snap.isValid = false; g_md = snap; return false; }
   snap.barTime0 = bt[0];
   snap.isNewBar = (snap.barTime0 != g_lastBarTime);
   if(snap.isNewBar) g_lastBarTime = snap.barTime0;

   double atrBuf[2];
   if(CopyBuffer(g_h_atr, 0, 0, 2, atrBuf) < 2) { snap.isValid = false; g_md = snap; return false; }
   snap.atrM5 = atrBuf[1];      // current
   snap.atrM5_prev = atrBuf[0]; // previous bar's ATR value

   double adxBuf[1];
   if(CopyBuffer(g_h_adx, MAIN_LINE, 0, 1, adxBuf) < 1) { snap.isValid = false; g_md = snap; return false; }
   snap.adxM5 = adxBuf[0];

   double rsiBuf[1];
   if(CopyBuffer(g_h_rsi, 0, 0, 1, rsiBuf) < 1) { snap.isValid = false; g_md = snap; return false; }
   snap.rsiM5 = rsiBuf[0];

   double emaFastBuf[1], emaSlowBuf[1], emaM15Buf[1], emaH1Buf[1];
   if(CopyBuffer(g_h_emaFast, 0, 0, 1, emaFastBuf) < 1) { snap.isValid = false; g_md = snap; return false; }
   if(CopyBuffer(g_h_emaSlow, 0, 0, 1, emaSlowBuf) < 1) { snap.isValid = false; g_md = snap; return false; }
   if(CopyBuffer(g_h_emaM15,  0, 0, 1, emaM15Buf)  < 1) { snap.isValid = false; g_md = snap; return false; }
   if(CopyBuffer(g_h_emaH1,   0, 0, 1, emaH1Buf)   < 1) { snap.isValid = false; g_md = snap; return false; }
   snap.emaFastM5 = emaFastBuf[0];
   snap.emaSlowM5 = emaSlowBuf[0];
   snap.emaM15    = emaM15Buf[0];
   snap.emaH1     = emaH1Buf[0];

   double bUpper[1], bMid[1], bLower[1];
   if(CopyBuffer(g_h_bands, UPPER_BAND, 0, 1, bUpper) < 1) { snap.isValid = false; g_md = snap; return false; }
   if(CopyBuffer(g_h_bands, BASE_LINE,  0, 1, bMid)   < 1) { snap.isValid = false; g_md = snap; return false; }
   if(CopyBuffer(g_h_bands, LOWER_BAND, 0, 1, bLower) < 1) { snap.isValid = false; g_md = snap; return false; }
   snap.bandsUpper = bUpper[0];
   snap.bandsMid   = bMid[0];
   snap.bandsLower = bLower[0];

   double macdMainBuf[1], macdSigBuf[1];
   if(CopyBuffer(g_h_macd, MAIN_LINE, 0, 1, macdMainBuf) < 1) { snap.isValid = false; g_md = snap; return false; }
   if(CopyBuffer(g_h_macd, SIGNAL_LINE, 0, 1, macdSigBuf) < 1) { snap.isValid = false; g_md = snap; return false; }
   snap.macdMain   = macdMainBuf[0];
   snap.macdSignal = macdSigBuf[0];

   double volBuf[3];
   if(CopyBuffer(g_h_volTick, 0, 0, 3, volBuf) < 3) { snap.isValid = false; g_md = snap; return false; }
   snap.volTickCurrent = volBuf[2];
   snap.volTickAvg     = (volBuf[0] + volBuf[1]) / 2.0;

   snap.serverTime = TimeCurrent();

   // Maintain ATR rolling history (owned by Layer 1; Layer 4 reads via
   // L1_GetAtrPercentile rather than touching the array directly)
   if(snap.isNewBar)
      L1_UpdateAtrHistory(snap.atrM5);
   snap.atrPercentile = L1_GetAtrPercentile(snap.atrM5);

   g_md = snap;
   return true;
}

void L1_UpdateAtrHistory(double atrValue)
{
   if(atrValue <= 0) return;
   if(g_atrHistoryCount < ATR_HISTORY_LEN)
   {
      g_atrHistory[g_atrHistoryCount] = atrValue;
      g_atrHistoryCount++;
   }
   else
   {
      for(int i = 0; i < ATR_HISTORY_LEN - 1; i++)
         g_atrHistory[i] = g_atrHistory[i+1];
      g_atrHistory[ATR_HISTORY_LEN - 1] = atrValue;
   }
}

double L1_GetAtrPercentile(double currentAtr)
{
   if(g_atrHistoryCount < 10 || currentAtr <= 0) return 50.0; // neutral until enough history
   int below = 0;
   for(int i = 0; i < g_atrHistoryCount; i++)
      if(g_atrHistory[i] <= currentAtr) below++;
   return (double)below / (double)g_atrHistoryCount * 100.0;
}

//=======================================================================
//  LAYER 9 IMPLEMENTATION - DYNAMIC CAPITAL ALLOCATION ENGINE
//  Replaces the legacy "loss-streak multiplier" (martingale) entirely.
//  Sizing now derives from (a) probability score tier and (b) a real
//  stop-distance-based lot calculation, never from consecutive losses.
//  Probability score itself is supplied by the Fusion Engine (Part 3);
//  until that exists, g_riskDecision.tradeAllowed will simply stay
//  false because no caller feeds a probability > 0 yet in Part 1.
//=======================================================================
void L9_ResolveRisk(double probabilityScore, double slDistancePoints)
{
   g_riskDecision.probabilityScore = probabilityScore;
   g_riskDecision.tradeAllowed = false;
   g_riskDecision.riskPct = 0.0;
   g_riskDecision.lotSize = 0.0;

   if(probabilityScore < InpMinProbToTrade)
   {
      g_riskDecision.reason = StringFormat("Probability %.1f below floor %.1f - DO_NOT_TRADE",
                                            probabilityScore, InpMinProbToTrade);
      return;
   }

   double riskPct;
   if(probabilityScore >= InpHighProbThreshold)
      riskPct = InpHighRiskPct;
   else if(probabilityScore >= InpMidProbThreshold)
      riskPct = InpMidRiskPct;
   else
      riskPct = InpBaseRiskPct;

   // Drawdown / volatility / strategy-health throttling multipliers are
   // applied here as they come online (drawdown throttle wired now,
   // since Layer 13 state already exists; vol + strategy health
   // throttles are wired in Parts 2-3 once those layers exist).
   double ddPct = 0.0;
   if(g_cap.peakEquity > 0)
      ddPct = (g_cap.peakEquity - AccountInfoDouble(ACCOUNT_EQUITY)) / g_cap.peakEquity * 100.0;

   if(ddPct > InpEquityDrawdownLockPct * 0.5 && ddPct < InpEquityDrawdownLockPct)
   {
      // Approaching the drawdown lock - throttle risk in half rather
      // than waiting for the hard lock to bite
      riskPct *= 0.5;
   }

   riskPct = MathMin(riskPct, InpMaxRiskPctHardCap);

   g_riskDecision.riskPct = riskPct;
   g_riskDecision.lotSize = L9_CalcLotFromRisk(riskPct, slDistancePoints);
   g_riskDecision.tradeAllowed = (g_riskDecision.lotSize > 0);
   g_riskDecision.reason = g_riskDecision.tradeAllowed
                            ? StringFormat("Prob %.1f -> risk %.2f%% -> lot %.2f", probabilityScore, riskPct, g_riskDecision.lotSize)
                            : "Resolved lot size invalid (check SL distance / symbol limits)";
}

double L9_CalcLotFromRisk(double riskPct, double slDistancePoints)
{
   if(InpUseFixedLotInstead)
      return InpFixedLotIfOverride;

   if(slDistancePoints <= 0) return 0.0;

   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   double riskAmount = equity * (riskPct / 100.0);

   double tickValue = SymbolInfoDouble(Symbol(), SYMBOL_TRADE_TICK_VALUE);
   double tickSize  = SymbolInfoDouble(Symbol(), SYMBOL_TRADE_TICK_SIZE);
   double point     = SymbolInfoDouble(Symbol(), SYMBOL_POINT);
   if(tickValue <= 0 || tickSize <= 0 || point <= 0) return 0.0;

   double valuePerPointPerLot = tickValue * (point / tickSize);
   double slValuePerLot = slDistancePoints * valuePerPointPerLot;
   if(slValuePerLot <= 0) return 0.0;

   double rawLot = riskAmount / slValuePerLot;

   double lotMin  = SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_MIN);
   double lotMax  = SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_MAX);
   double lotStep = SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_STEP);
   if(lotStep <= 0) lotStep = 0.01;

   double lot = MathFloor(rawLot / lotStep) * lotStep;
   lot = MathMax(lotMin, MathMin(lotMax, lot));

   // Sanity guard: never let a calculation error produce a lot size
   // that risks dramatically more than intended (protects against
   // tick value/contract size misreads on exotic BTC contract specs)
   double sanityCheckRisk = lot * slValuePerLot;
   if(sanityCheckRisk > equity * (InpMaxRiskPctHardCap / 100.0) * 1.05)
   {
      Print("[L9] Sanity check failed: calculated lot ", lot, " implies risk ", sanityCheckRisk,
            " exceeding hard cap. Rejecting trade sizing.");
      return 0.0;
   }

   return lot;
}

//=======================================================================
//  LAYER 13 IMPLEMENTATION - CAPITAL PRESERVATION ENGINE
//  Highest priority layer. Overrides everything. No trade can occur if
//  any lock here is active, regardless of what any other layer says.
//=======================================================================
void L13_InitPeriodAnchors()
{
   ZeroMemory(g_cap);
   double eq = AccountInfoDouble(ACCOUNT_EQUITY);
   g_cap.dayStartEquity   = eq;
   g_cap.weekStartEquity  = eq;
   g_cap.monthStartEquity = eq;
   g_cap.peakEquity       = eq;
   g_cap.currentDay         = DayStart(TimeCurrent());
   g_cap.currentWeekStart   = WeekStart(TimeCurrent());
   g_cap.currentMonthStart  = MonthStart(TimeCurrent());
   g_cap.consecutiveLosses  = 0;
   g_cap.lastLockReason     = "";
}

void L13_UpdateRollover()
{
   datetime d = DayStart(TimeCurrent());
   datetime w = WeekStart(TimeCurrent());
   datetime m = MonthStart(TimeCurrent());
   double eq = AccountInfoDouble(ACCOUNT_EQUITY);

   if(d != g_cap.currentDay)
   {
      g_cap.currentDay = d;
      g_cap.dayStartEquity = eq;
      g_cap.lockDaily = false;
      LogVerbose("Daily equity anchor reset to " + DoubleToString(eq, 2));
   }
   if(w != g_cap.currentWeekStart)
   {
      g_cap.currentWeekStart = w;
      g_cap.weekStartEquity = eq;
      g_cap.lockWeekly = false;
      LogVerbose("Weekly equity anchor reset to " + DoubleToString(eq, 2));
   }
   if(m != g_cap.currentMonthStart)
   {
      g_cap.currentMonthStart = m;
      g_cap.monthStartEquity = eq;
      g_cap.lockMonthly = false;
      LogVerbose("Monthly equity anchor reset to " + DoubleToString(eq, 2));
   }
   if(eq > g_cap.peakEquity)
      g_cap.peakEquity = eq;
}

void L13_EvaluateLocks()
{
   double eq = AccountInfoDouble(ACCOUNT_EQUITY);

   // --- Daily loss lock ---
   if(g_cap.dayStartEquity > 0)
   {
      double dayLossPct = (g_cap.dayStartEquity - eq) / g_cap.dayStartEquity * 100.0;
      g_cap.lockDaily = (dayLossPct >= InpDailyLossLockPct);
   }

   // --- Weekly loss lock ---
   if(g_cap.weekStartEquity > 0)
   {
      double weekLossPct = (g_cap.weekStartEquity - eq) / g_cap.weekStartEquity * 100.0;
      g_cap.lockWeekly = (weekLossPct >= InpWeeklyLossLockPct);
   }

   // --- Monthly loss lock ---
   if(g_cap.monthStartEquity > 0)
   {
      double monthLossPct = (g_cap.monthStartEquity - eq) / g_cap.monthStartEquity * 100.0;
      g_cap.lockMonthly = (monthLossPct >= InpMonthlyLossLockPct);
   }

   // --- Equity drawdown-from-peak lock ---
   if(g_cap.peakEquity > 0)
   {
      double ddPct = (g_cap.peakEquity - eq) / g_cap.peakEquity * 100.0;
      g_cap.lockDrawdown = (ddPct >= InpEquityDrawdownLockPct);
   }

   // --- Consecutive loss lock ---
   g_cap.lockConsecutive = (InpConsecutiveLossLock > 0 && g_cap.consecutiveLosses >= InpConsecutiveLossLock);

   // --- Execution quality lock (spread-based; full execution engine
   //     with slippage/tick-stability scoring lands in Part 3) ---
   double point = SymbolInfoDouble(Symbol(), SYMBOL_POINT);
   double spread = (point > 0) ? (SymbolInfoDouble(Symbol(), SYMBOL_ASK) - SymbolInfoDouble(Symbol(), SYMBOL_BID)) / point : 0;
   g_cap.lockExecutionQuality = (InpMaxSpreadPoints > 0 && spread > InpMaxSpreadPoints);

   // --- Manual kill switch via Global Variable ---
   if(InpEnableKillSwitch)
   {
      if(GlobalVariableCheck(InpKillSwitchGlobalVar))
      {
         double gv = GlobalVariableGet(InpKillSwitchGlobalVar);
         g_cap.lockKillSwitch = (gv >= 1.0);
      }
      else
      {
         g_cap.lockKillSwitch = false;
      }
   }
   else
   {
      g_cap.lockKillSwitch = false;
   }

   // Resolve human-readable reason for dashboard / logs
   if(g_cap.lockKillSwitch)         g_cap.lastLockReason = "KILL SWITCH";
   else if(g_cap.lockDaily)         g_cap.lastLockReason = "DAILY LOSS LIMIT";
   else if(g_cap.lockWeekly)        g_cap.lastLockReason = "WEEKLY LOSS LIMIT";
   else if(g_cap.lockMonthly)       g_cap.lastLockReason = "MONTHLY LOSS LIMIT";
   else if(g_cap.lockDrawdown)      g_cap.lastLockReason = "EQUITY DRAWDOWN";
   else if(g_cap.lockConsecutive)   g_cap.lastLockReason = "CONSECUTIVE LOSSES";
   else if(g_cap.lockStrategyFailure) g_cap.lastLockReason = "STRATEGY FAILURE";
   else if(g_cap.lockVolChaos)      g_cap.lastLockReason = "VOLATILITY CHAOS";
   else if(g_cap.lockExecutionQuality) g_cap.lastLockReason = "EXECUTION QUALITY (SPREAD)";
   else                              g_cap.lastLockReason = "";
}

bool L13_AnyLockActive()
{
   return g_cap.lockDaily || g_cap.lockWeekly || g_cap.lockMonthly ||
          g_cap.lockConsecutive || g_cap.lockDrawdown || g_cap.lockStrategyFailure ||
          g_cap.lockVolChaos || g_cap.lockExecutionQuality || g_cap.lockKillSwitch;
}

void L13_RegisterTradeResult(double pnl)
{
   if(pnl < 0)
      g_cap.consecutiveLosses++;
   else
      g_cap.consecutiveLosses = 0;
}

void L13_ResetConsecutiveLossCounter()
{
   g_cap.consecutiveLosses = 0;
}

//=======================================================================
//  SELF-DIAGNOSTIC ENGINE
//=======================================================================
bool SelfDiagnostic_Run()
{
   if(g_h_emaFast == INVALID_HANDLE || g_h_emaSlow == INVALID_HANDLE ||
      g_h_emaM15  == INVALID_HANDLE || g_h_emaH1   == INVALID_HANDLE ||
      g_h_rsi     == INVALID_HANDLE || g_h_atr     == INVALID_HANDLE ||
      g_h_adx     == INVALID_HANDLE || g_h_bands   == INVALID_HANDLE ||
      g_h_macd    == INVALID_HANDLE || g_h_volTick == INVALID_HANDLE)
   {
      Print("[DIAG] Indicator handle invalid.");
      return false;
   }

   if(!SymbolInfoInteger(Symbol(), SYMBOL_SELECT))
   {
      Print("[DIAG] Symbol not selected in Market Watch.");
      return false;
   }

   MqlTick t;
   if(!SymbolInfoTick(Symbol(), t))
   {
      Print("[DIAG] Tick feed unavailable.");
      return false;
   }

   long terminalMaxBars = TerminalInfoInteger(TERMINAL_MAXBARS);
   if(terminalMaxBars > 0 && Bars(Symbol(), PERIOD_M5) < 50)
   {
      Print("[DIAG] Insufficient bar history available (<50 bars on M5).");
      return false;
   }

   return true;
}

//=======================================================================
//  UTILITY FUNCTIONS
//=======================================================================
bool IsMarketTradeable()
{
   ENUM_SYMBOL_TRADE_MODE m = (ENUM_SYMBOL_TRADE_MODE)SymbolInfoInteger(Symbol(), SYMBOL_TRADE_MODE);
   return (m == SYMBOL_TRADE_MODE_FULL || m == SYMBOL_TRADE_MODE_LONGONLY || m == SYMBOL_TRADE_MODE_SHORTONLY);
}

datetime DayStart(datetime ts)
{
   MqlDateTime d;
   TimeToStruct(ts, d);
   return ts - (datetime)(d.hour * 3600 + d.min * 60 + d.sec);
}

datetime WeekStart(datetime ts)
{
   MqlDateTime d;
   TimeToStruct(ts, d);
   datetime today = DayStart(ts);
   int dow = d.day_of_week; // 0=Sunday
   return today - (datetime)(dow * 86400);
}

datetime MonthStart(datetime ts)
{
   MqlDateTime d;
   TimeToStruct(ts, d);
   d.day = 1; d.hour = 0; d.min = 0; d.sec = 0;
   return StructToTime(d);
}

double NPrice(double p)
{
   return NormalizeDouble(p, (int)SymbolInfoInteger(Symbol(), SYMBOL_DIGITS));
}

ENUM_ORDER_TYPE_FILLING GetFillMode()
{
   uint f = (uint)SymbolInfoInteger(Symbol(), SYMBOL_FILLING_MODE);
   if((f & SYMBOL_FILLING_FOK) != 0) return ORDER_FILLING_FOK;
   if((f & SYMBOL_FILLING_IOC) != 0) return ORDER_FILLING_IOC;
   return ORDER_FILLING_RETURN;
}

void LogVerbose(string msg)
{
   if(InpVerboseLogging) Print("[NTX] ", msg);
}

void BuildSessionStatsFromHistory()
{
   g_sessProfitToday = 0.0;
   g_sessWinsToday = 0;
   g_sessLossesToday = 0;
   g_sessTradesToday = 0;

   datetime ds = DayStart(TimeCurrent());
   if(!HistorySelect(ds, TimeCurrent())) return;

   int total = HistoryDealsTotal();
   for(int i = 0; i < total; i++)
   {
      ulong tk = HistoryDealGetTicket(i);
      if((ulong)HistoryDealGetInteger(tk, DEAL_MAGIC) != InpMagicNumber) continue;
      if(HistoryDealGetString(tk, DEAL_SYMBOL) != Symbol()) continue;

      if(HistoryDealGetInteger(tk, DEAL_ENTRY) == DEAL_ENTRY_IN)
         g_sessTradesToday++;

      if(HistoryDealGetInteger(tk, DEAL_ENTRY) == DEAL_ENTRY_OUT)
      {
         double pnl = HistoryDealGetDouble(tk, DEAL_PROFIT) +
                      HistoryDealGetDouble(tk, DEAL_SWAP) +
                      HistoryDealGetDouble(tk, DEAL_COMMISSION);
         g_sessProfitToday += pnl;
         if(pnl >= 0) g_sessWinsToday++; else g_sessLossesToday++;
      }
   }
}

//=======================================================================
//  DASHBOARD (visual shell carried forward from legacy v5.0; fields
//  rebuilt to reflect the new architecture - probability/risk/locks
//  instead of fake "AI confidence" and recovery-tier multiplier)
//=======================================================================
void R(string nm, int x, int y, int w, int h, color bg, color brd=clrNONE, int bw=1)
{
   string n = D + nm;
   if(ObjectFind(0, n) >= 0) ObjectDelete(0, n);
   ObjectCreate(0, n, OBJ_RECTANGLE_LABEL, 0, 0, 0);
   ObjectSetInteger(0, n, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, n, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, n, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, n, OBJPROP_XSIZE, w);
   ObjectSetInteger(0, n, OBJPROP_YSIZE, h);
   ObjectSetInteger(0, n, OBJPROP_BGCOLOR, bg);
   if(brd != clrNONE)
   {
      ObjectSetInteger(0, n, OBJPROP_BORDER_TYPE, BORDER_FLAT);
      ObjectSetInteger(0, n, OBJPROP_COLOR, brd);
      ObjectSetInteger(0, n, OBJPROP_WIDTH, bw);
   }
   else ObjectSetInteger(0, n, OBJPROP_BORDER_TYPE, BORDER_RAISED);
   ObjectSetInteger(0, n, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, n, OBJPROP_HIDDEN, true);
}

void L(string nm, int x, int y, string txt, color clr, int fsz, string fnt="Arial Bold")
{
   string n = D + nm;
   if(ObjectFind(0, n) >= 0) ObjectDelete(0, n);
   ObjectCreate(0, n, OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, n, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, n, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, n, OBJPROP_YDISTANCE, y);
   ObjectSetString(0, n, OBJPROP_TEXT, txt);
   ObjectSetInteger(0, n, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, n, OBJPROP_FONTSIZE, fsz);
   ObjectSetString(0, n, OBJPROP_FONT, fnt);
   ObjectSetInteger(0, n, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, n, OBJPROP_HIDDEN, true);
}

void U(string nm, string txt, color clr=C_WHITE)
{
   string n = D + nm;
   if(ObjectFind(0, n) >= 0)
   {
      ObjectSetString(0, n, OBJPROP_TEXT, txt);
      ObjectSetInteger(0, n, OBJPROP_COLOR, clr);
   }
}

void Bar(string nm, int x, int y, int w, int h, double pct, color fg, color bg_c)
{
   R(nm + "_bg", x, y, w, h, bg_c, C_BORDER, 1);
   int fw = (int)MathMax(2, MathRound(pct / 100.0 * (w - 2)));
   R(nm + "_fg", x+1, y+1, fw, h-2, fg, clrNONE);
}

void UpdBar(string nm, double pct, color fg)
{
   string n  = D + nm + "_fg";
   string nb = D + nm + "_bg";
   int w = 0;
   if(ObjectFind(0, nb) >= 0) w = (int)ObjectGetInteger(0, nb, OBJPROP_XSIZE);
   if(w <= 0) return;
   int fw = (int)MathMax(2, MathRound(pct / 100.0 * (w - 2)));
   if(ObjectFind(0, n) >= 0)
   {
      ObjectSetInteger(0, n, OBJPROP_XSIZE, fw);
      ObjectSetInteger(0, n, OBJPROP_BGCOLOR, fg);
   }
}

void InitDash()
{
   int X = InpDashX, Y = InpDashY;
   R("frame_outer", X,   Y,   DW,   DH,   C_BG0, C_ACBORD, 2);
   R("frame_inner", X+2, Y+2, DW-4, DH-4, C_BG0, C_BORDER, 1);

   R("hdr_bg",  X+2,  Y+2,  DW-4, 80, C_HDRBAR, C_BORDER, 1);
   R("hdr_acc", X+2,  Y+2,  DW-4,  3, C_ACBORD);
   L("h_name",  X+10, Y+10, InpBotName, C_GOLD, 12, "Arial Black");
   L("h_tag",   X+10, Y+30, "Regime-Adaptive Systematic Framework", C_CYAN, 7, "Arial");
   L("h_ver",   X+10, Y+44, "v1.0 (Part 1/3)  |  Magic: " + IntegerToString((long)InpMagicNumber) + "  |  " + Symbol(), C_LBLUE, 7, "Arial");
   R("live_bg", X+DW-80, Y+8, 64, 22, C_DKGREEN, C_GREEN, 1);
   L("live_lbl",X+DW-72, Y+12, "\u25CF LIVE", C_GREEN, 7, "Arial Bold");
   R("div_hdr", X+2, Y+82, DW-4, 2, C_ACBORD);

   L("lb_stat", X+14, Y+93, "STATUS", C_SUBTEXT, 8, "Arial");
   L("vl_stat", X+90, Y+93, "INITIALIZING", C_ORANGE, 9, "Arial Black");
   R("div_stat", X+2, Y+118, DW-4, 1, C_BORDER);

   // Section: Capital Protection (Layer 13)
   R("sec_cp",    X+2, Y+122, DW-4, 150, C_BG1, C_BORDER, 1);
   R("sec_cp_hd", X+2, Y+122, DW-4,  22, C_HDRBAR, C_BORDER, 1);
   L("sec_cp_lb", X+10, Y+126, "\u25B8  CAPITAL PROTECTION (L13)", C_GOLD, 8, "Arial Black");
   L("lb_dayeq",  X+14, Y+149, "Day-Start Equity", C_SUBTEXT, 8, "Arial");
   L("vl_dayeq",  X+220, Y+149, "$ 0.00", C_WHITE, 9, "Arial Bold");
   L("lb_dd",     X+14, Y+165, "Drawdown from Peak", C_SUBTEXT, 8, "Arial");
   L("vl_dd",     X+220, Y+165, "0.00 %", C_WHITE, 9, "Arial Bold");
   Bar("dd_bar",  X+300, Y+167, 110, 12, 0, C_RED, C_DGRAY);
   L("lb_consec", X+14, Y+181, "Consecutive Losses", C_SUBTEXT, 8, "Arial");
   L("vl_consec", X+220, Y+181, "0 / " + IntegerToString(InpConsecutiveLossLock), C_WHITE, 9, "Arial Bold");
   L("lb_lock",   X+14, Y+197, "Lock State", C_SUBTEXT, 8, "Arial");
   L("vl_lock",   X+220, Y+197, "CLEAR", C_GREEN, 9, "Arial Bold");
   L("lb_trades", X+14, Y+213, "Trades Today", C_SUBTEXT, 8, "Arial");
   L("vl_trades", X+220, Y+213, "0 / " + IntegerToString(InpMaxDailyTrades), C_WHITE, 9, "Arial Bold");
   L("lb_sp",     X+14, Y+229, "Session P&L", C_SUBTEXT, 8, "Arial");
   L("vl_sp",     X+220, Y+229, "$ 0.00", C_WHITE, 9, "Arial Bold");
   L("lb_spread", X+14, Y+245, "Spread (pts)", C_SUBTEXT, 8, "Arial");
   L("vl_spread", X+220, Y+245, "0", C_WHITE, 9, "Arial Bold");

   // Section: Risk Allocation (Layer 9)
   R("sec_ra",    X+2, Y+278, DW-4, 110, C_BG1, C_BORDER, 1);
   R("sec_ra_hd", X+2, Y+278, DW-4,  22, C_HDRBAR, C_BORDER, 1);
   L("sec_ra_lb", X+10, Y+282, "\u25B8  CAPITAL ALLOCATION (L9)", C_GOLD, 8, "Arial Black");
   L("lb_prob",   X+14, Y+305, "Probability Score", C_SUBTEXT, 8, "Arial");
   L("vl_prob",   X+220, Y+305, "-- %", C_CYAN, 9, "Arial Bold");
   Bar("prob_bar", X+300, Y+307, 110, 12, 0, C_CYAN, C_DGRAY);
   L("lb_riskpct", X+14, Y+321, "Resolved Risk %", C_SUBTEXT, 8, "Arial");
   L("vl_riskpct", X+220, Y+321, "0.00 %", C_WHITE, 9, "Arial Bold");
   L("lb_lot",    X+14, Y+337, "Resolved Lot", C_SUBTEXT, 8, "Arial");
   L("vl_lot",    X+220, Y+337, "0.00", C_WHITE, 9, "Arial Bold");
   L("lb_riskreason", X+14, Y+353, "Reason", C_SUBTEXT, 8, "Arial");
   L("vl_riskreason", X+90, Y+353, "Awaiting fusion engine", C_SUBTEXT, 7, "Arial");

   // Section: System / Build status
   R("sec_sys",    X+2, Y+398, DW-4, 64, C_BG2, C_BORDER, 1);
   L("sys1", X+14, Y+403, "Build status: Part 1/3 - Data Engine, Risk", C_LBLUE, 7, "Arial");
   L("sys2", X+14, Y+417, "Allocation, Capital Protection complete.", C_LBLUE, 7, "Arial");
   L("sys3", X+14, Y+431, "Regime/structure/vol/liquidity/fusion/router", C_LBLUE, 7, "Arial");
   L("sys4", X+14, Y+445, "land in Parts 2-3. No trades placed yet.", C_LBLUE, 7, "Arial");

   R("ftr", X+2, Y+DH-39, DW-4, 15, C_HDRBAR, C_BORDER, 1);
   L("ft_time", X+10, Y+DH-37, "Server: --:--", C_MGRAY, 7, "Arial");

   ChartRedraw(0);
}

void UpdateDash()
{
   if(!InpShowDash) return;

   U("vl_stat", g_statusText, g_statusColor);

   U("vl_dayeq", "$ " + DoubleToString(g_cap.dayStartEquity, 2), C_WHITE);

   double eq = AccountInfoDouble(ACCOUNT_EQUITY);
   double ddPct = (g_cap.peakEquity > 0) ? (g_cap.peakEquity - eq) / g_cap.peakEquity * 100.0 : 0.0;
   U("vl_dd", DoubleToString(ddPct, 2) + " %", (ddPct < InpEquityDrawdownLockPct * 0.5) ? C_GREEN : C_RED);
   UpdBar("dd_bar", MathMin(ddPct / MathMax(InpEquityDrawdownLockPct,0.01) * 100.0, 100.0),
          (ddPct < InpEquityDrawdownLockPct * 0.5) ? C_GREEN : C_RED);

   U("vl_consec", IntegerToString(g_cap.consecutiveLosses) + " / " + IntegerToString(InpConsecutiveLossLock),
     (g_cap.consecutiveLosses == 0) ? C_GREEN : C_ORANGE);

   bool anyLock = L13_AnyLockActive();
   U("vl_lock", anyLock ? ("LOCKED: " + g_cap.lastLockReason) : "CLEAR", anyLock ? C_RED : C_GREEN);

   U("vl_trades", IntegerToString(g_sessTradesToday) + " / " + IntegerToString(InpMaxDailyTrades), C_WHITE);
   U("vl_sp", "$ " + DoubleToString(g_sessProfitToday, 2), (g_sessProfitToday >= 0) ? C_GREEN : C_RED);
   U("vl_spread", DoubleToString(g_md.spreadPoints, 0), (g_md.spreadPoints <= InpMaxSpreadPoints) ? C_WHITE : C_RED);

   if(g_riskDecision.probabilityScore > 0)
   {
      U("vl_prob", DoubleToString(g_riskDecision.probabilityScore, 1) + " %", C_CYAN);
      UpdBar("prob_bar", g_riskDecision.probabilityScore, C_CYAN);
   }
   else
   {
      U("vl_prob", "-- %", C_SUBTEXT);
      UpdBar("prob_bar", 0, C_CYAN);
   }
   U("vl_riskpct", DoubleToString(g_riskDecision.riskPct, 2) + " %", C_WHITE);
   U("vl_lot", DoubleToString(g_riskDecision.lotSize, 2), C_WHITE);
   U("vl_riskreason", g_riskDecision.reason, C_SUBTEXT);

   U("ft_time", "Server: " + TimeToString(TimeCurrent(), TIME_SECONDS), C_DGRAY);

   ChartRedraw(0);
}

void DeleteDash()
{
   ObjectsDeleteAll(0, D);
   ChartRedraw(0);
}
//+------------------------------------------------------------------+
//|                    PART 2 / 3                                     |
//|  Layers 2-7: Market State, Structure, Volatility, Liquidity,      |
//|  Flow Pressure, Session Intelligence.                             |
//|  These layers compute INFORMATION only - none of them place       |
//|  trades. They populate the structs below, which Part 3's Fusion  |
//|  Engine and Meta Router will consume.                             |
//+------------------------------------------------------------------+

//=======================================================================
//  LAYER 2 - MARKET STATE INTELLIGENCE ENGINE
//  Produces a weighted probability DISTRIBUTION across regimes rather
//  than a forced single classification (per spec: "never force
//  classification"). Distribution sums to ~100.
//=======================================================================
struct MarketStateDistribution
{
   double pTrendExpansion;
   double pTrendExhaustion;
   double pRange;
   double pTransition;
   double pShock;
   ENUM_MARKET_REGIME dominant;   // highest-probability regime, for display/logging only
};
MarketStateDistribution g_state;

void L2_UpdateMarketState()
{
   MarketStateDistribution s;
   ZeroMemory(s);

   double adx = g_md.adxM5;
   double atrPctile = g_md.atrPercentile;
   double emaFast = g_md.emaFastM5;
   double emaSlow = g_md.emaSlowM5;
   double price = g_md.bid;

   double emaSeparationPct = (emaSlow != 0) ? MathAbs(emaFast - emaSlow) / emaSlow * 100.0 : 0.0;
   double trendStrengthRaw = MathMin(adx / 45.0, 1.0) * 0.6 + MathMin(emaSeparationPct / 0.5, 1.0) * 0.4;

   double shockRaw = 0.0;
   if(atrPctile > 95.0) shockRaw += 0.5;
   if(g_md.atrM5_prev > 0 && (g_md.atrM5 / g_md.atrM5_prev) > 1.8) shockRaw += 0.5;
   shockRaw = MathMin(shockRaw, 1.0);

   double rsi = g_md.rsiM5;
   bool overboughtFade = (rsi > 70 && price < g_md.high1);
   bool oversoldFade    = (rsi < 30 && price > g_md.low1);
   double exhaustionRaw = (trendStrengthRaw > 0.5 && (overboughtFade || oversoldFade)) ? 0.7 : 0.1;

   double bandWidthPct = (g_md.bandsMid != 0) ? (g_md.bandsUpper - g_md.bandsLower) / g_md.bandsMid * 100.0 : 0.0;
   double rangeRaw = (adx < 20 && bandWidthPct < 1.5) ? 0.8 : MathMax(0.0, (20 - adx) / 20.0 * 0.5);

   double sumKnown = trendStrengthRaw + shockRaw + exhaustionRaw + rangeRaw;
   double transitionRaw = MathMax(0.05, 1.0 - MathMin(sumKnown, 1.0));

   double total = trendStrengthRaw + exhaustionRaw + rangeRaw + transitionRaw + shockRaw;
   if(total <= 0) total = 1.0;

   s.pTrendExpansion  = trendStrengthRaw / total * 100.0;
   s.pTrendExhaustion = exhaustionRaw    / total * 100.0;
   s.pRange           = rangeRaw         / total * 100.0;
   s.pTransition      = transitionRaw    / total * 100.0;
   s.pShock           = shockRaw         / total * 100.0;

   double maxP = s.pTrendExpansion;
   s.dominant = REGIME_TREND_EXPANSION;
   if(s.pTrendExhaustion > maxP) { maxP = s.pTrendExhaustion; s.dominant = REGIME_TREND_EXHAUSTION; }
   if(s.pRange > maxP)           { maxP = s.pRange;           s.dominant = REGIME_RANGE; }
   if(s.pTransition > maxP)      { maxP = s.pTransition;      s.dominant = REGIME_TRANSITION; }
   if(s.pShock > maxP)           { maxP = s.pShock;           s.dominant = REGIME_SHOCK; }

   g_state = s;
}

//=======================================================================
//  LAYER 3 - STRUCTURE INTELLIGENCE ENGINE
//  Tracks HH/HL/LH/LL swing sequence and scores structure quality 0-100.
//=======================================================================
struct StructureState
{
   double structureStrength;   // 0-100
   double trendEfficiency;     // 0-100
   double impulseQuality;      // 0-100
   double pullbackQuality;     // 0-100
   int    swingDirection;      // 1 bullish, -1 bearish, 0 unclear
};
StructureState g_structure;

#define SWING_LOOKBACK 60

void L3_UpdateStructure()
{
   StructureState st;
   ZeroMemory(st);

   double highs[SWING_LOOKBACK], lows[SWING_LOOKBACK], closes[SWING_LOOKBACK];
   int got_h = CopyHigh(Symbol(), PERIOD_M5, 0, SWING_LOOKBACK, highs);
   int got_l = CopyLow(Symbol(), PERIOD_M5, 0, SWING_LOOKBACK, lows);
   int got_c = CopyClose(Symbol(), PERIOD_M5, 0, SWING_LOOKBACK, closes);

   if(got_h < SWING_LOOKBACK || got_l < SWING_LOOKBACK || got_c < SWING_LOOKBACK)
   {
      g_structure = st;
      return;
   }

   double recentSwingHighVals[10], recentSwingLowVals[10];
   int hCount = 0, lCount = 0;
   for(int i = 2; i < SWING_LOOKBACK - 2 && (hCount < 10 || lCount < 10); i++)
   {
      bool isHigh = (highs[i] > highs[i-1] && highs[i] > highs[i-2] &&
                     highs[i] > highs[i+1] && highs[i] > highs[i+2]);
      bool isLow  = (lows[i] < lows[i-1] && lows[i] < lows[i-2] &&
                     lows[i] < lows[i+1] && lows[i] < lows[i+2]);
      if(isHigh && hCount < 10) recentSwingHighVals[hCount++] = highs[i];
      if(isLow  && lCount < 10) recentSwingLowVals[lCount++]  = lows[i];
   }

   int hhCount = 0, hlCount = 0, lhCount = 0, llCount = 0;
   for(int i = 1; i < hCount; i++)
   {
      if(recentSwingHighVals[i] > recentSwingHighVals[i-1]) hhCount++; else lhCount++;
   }
   for(int i = 1; i < lCount; i++)
   {
      if(recentSwingLowVals[i] > recentSwingLowVals[i-1]) hlCount++; else llCount++;
   }

   int bullishVotes = hhCount + hlCount;
   int bearishVotes = lhCount + llCount;
   int totalVotes = bullishVotes + bearishVotes;

   if(totalVotes > 0)
   {
      st.structureStrength = MathAbs(bullishVotes - bearishVotes) / (double)totalVotes * 100.0;
      st.swingDirection = (bullishVotes > bearishVotes) ? 1 : ((bearishVotes > bullishVotes) ? -1 : 0);
   }

   double netDisplacement = MathAbs(closes[SWING_LOOKBACK-1] - closes[0]);
   double totalPath = 0.0;
   for(int i = 1; i < SWING_LOOKBACK; i++)
      totalPath += MathAbs(closes[i] - closes[i-1]);
   st.trendEfficiency = (totalPath > 0) ? MathMin(netDisplacement / totalPath, 1.0) * 100.0 : 0.0;

   if(g_md.atrM5 > 0)
   {
      double lastLegDisplacement = MathAbs(closes[SWING_LOOKBACK-1] - closes[SWING_LOOKBACK-5]);
      st.impulseQuality = MathMin(lastLegDisplacement / (g_md.atrM5 * 4.0), 1.0) * 100.0;
   }

   if(hCount >= 1 && lCount >= 1 && g_md.atrM5 > 0)
   {
      double priorLegRange = MathAbs(recentSwingHighVals[hCount-1] - recentSwingLowVals[lCount-1]);
      double currentRetrace = MathAbs(closes[SWING_LOOKBACK-1] - (st.swingDirection > 0 ? recentSwingHighVals[hCount-1] : recentSwingLowVals[lCount-1]));
      double retracePct = (priorLegRange > 0) ? currentRetrace / priorLegRange : 0.0;
      if(retracePct >= 0.30 && retracePct <= 0.61)
         st.pullbackQuality = 100.0 - MathAbs(retracePct - 0.45) * 200.0;
      else
         st.pullbackQuality = MathMax(0.0, 40.0 - MathAbs(retracePct - 0.45) * 60.0);
      st.pullbackQuality = MathMax(0.0, MathMin(100.0, st.pullbackQuality));
   }

   g_structure = st;
}

//=======================================================================
//  LAYER 4 - VOLATILITY INTELLIGENCE ENGINE
//=======================================================================
struct VolatilityState
{
   double compositeIndex;
   ENUM_VOL_STATE state;
   double spreadExpansionRatio;
   double barVelocity;
};
VolatilityState g_vol;

double   g_baselineSpreadPoints = 0.0;
int      g_spreadSampleCount = 0;

void L4_UpdateVolatility()
{
   VolatilityState v;
   ZeroMemory(v);

   if(g_baselineSpreadPoints <= 0)
   {
      g_baselineSpreadPoints = g_md.spreadPoints;
      g_spreadSampleCount = 1;
   }
   else if(g_md.spreadPoints > 0 && g_md.spreadPoints < g_baselineSpreadPoints * 5.0)
   {
      g_spreadSampleCount = MathMin(g_spreadSampleCount + 1, 2000);
      g_baselineSpreadPoints += (g_md.spreadPoints - g_baselineSpreadPoints) / g_spreadSampleCount;
   }
   v.spreadExpansionRatio = (g_baselineSpreadPoints > 0) ? g_md.spreadPoints / g_baselineSpreadPoints : 1.0;

   double barRange = g_md.high0 - g_md.low0;
   v.barVelocity = (g_md.atrM5 > 0) ? barRange / g_md.atrM5 : 0.0;

   double atrExpansion = (g_md.atrM5_prev > 0) ? (g_md.atrM5 - g_md.atrM5_prev) / g_md.atrM5_prev : 0.0;

   double avgRecentRange = ((g_md.high1 - g_md.low1) + (g_md.high2 - g_md.low2)) / 2.0;
   double rangeExpansionRatio = (avgRecentRange > 0) ? barRange / avgRecentRange : 1.0;

   double composite = 0.0;
   composite += MathMin(g_md.atrPercentile, 100.0) * 0.30;
   composite += MathMin(MathMax(atrExpansion, -1.0), 2.0) * 25.0 * 0.20;
   composite += MathMin(v.spreadExpansionRatio, 5.0) * 10.0 * 0.20;
   composite += MathMin(v.barVelocity, 3.0) * 20.0 * 0.15;
   composite += MathMin(rangeExpansionRatio, 3.0) * 20.0 * 0.15;
   composite = MathMax(0.0, MathMin(100.0, composite));
   v.compositeIndex = composite;

   if(composite < 15.0)      v.state = VOL_SUPPRESSED;
   else if(composite < 45.0) v.state = VOL_NORMAL;
   else if(composite < 70.0) v.state = VOL_EXPANDING;
   else if(composite < 90.0) v.state = VOL_EXTREME;
   else                       v.state = VOL_CHAOTIC;

   g_vol = v;
   g_cap.lockVolChaos = (v.state == VOL_CHAOTIC);
}

//=======================================================================
//  LAYER 5 - LIQUIDITY INTELLIGENCE ENGINE
//  Heuristic liquidity proxies only - NOT a claim of true order-book
//  visibility, which MT5 CFD feeds do not provide.
//=======================================================================
struct LiquidityState
{
   double dailyHigh, dailyLow;
   double weeklyHigh, weeklyLow;
   double sessionHigh, sessionLow;
   bool   nearEqualHighs;
   bool   nearEqualLows;
   bool   inCompressionZone;
   double liquidityRelevanceScore;
};
LiquidityState g_liquidity;

void L5_UpdateLiquidity()
{
   LiquidityState liq;
   ZeroMemory(liq);

   double dHigh[1], dLow[1];
   if(CopyHigh(Symbol(), PERIOD_D1, 0, 1, dHigh) > 0) liq.dailyHigh = dHigh[0];
   if(CopyLow(Symbol(), PERIOD_D1, 0, 1, dLow) > 0)  liq.dailyLow = dLow[0];

   double wHigh[1], wLow[1];
   if(CopyHigh(Symbol(), PERIOD_W1, 0, 1, wHigh) > 0) liq.weeklyHigh = wHigh[0];
   if(CopyLow(Symbol(), PERIOD_W1, 0, 1, wLow) > 0)  liq.weeklyLow = wLow[0];

   double sHighs[96], sLows[96];
   int gotH = CopyHigh(Symbol(), PERIOD_M5, 0, 96, sHighs);
   int gotL = CopyLow(Symbol(), PERIOD_M5, 0, 96, sLows);
   if(gotH > 0 && gotL > 0)
   {
      liq.sessionHigh = sHighs[ArrayMaximum(sHighs, 0, gotH)];
      liq.sessionLow  = sLows[ArrayMinimum(sLows, 0, gotL)];
   }

   if(g_md.atrM5 > 0 && gotH > 10)
   {
      double tol = g_md.atrM5 * 0.15;
      int matches = 0;
      for(int i = 0; i < gotH - 1; i++)
         for(int j = i+1; j < gotH; j++)
            if(MathAbs(sHighs[i] - sHighs[j]) < tol) matches++;
      liq.nearEqualHighs = (matches >= 2);

      matches = 0;
      for(int i = 0; i < gotL - 1; i++)
         for(int j = i+1; j < gotL; j++)
            if(MathAbs(sLows[i] - sLows[j]) < tol) matches++;
      liq.nearEqualLows = (matches >= 2);
   }

   if(liq.sessionHigh > liq.sessionLow)
   {
      double recentRange = g_md.high1 - g_md.low1;
      double sessionRange = liq.sessionHigh - liq.sessionLow;
      liq.inCompressionZone = (sessionRange > 0 && recentRange / sessionRange < 0.08);
   }

   double score = 0.0;
   double price = g_md.bid;
   if(g_md.atrM5 > 0)
   {
      double distToDailyHigh = MathAbs(price - liq.dailyHigh) / g_md.atrM5;
      double distToDailyLow  = MathAbs(price - liq.dailyLow)  / g_md.atrM5;
      if(distToDailyHigh < 1.0) score += (1.0 - distToDailyHigh) * 40.0;
      if(distToDailyLow  < 1.0) score += (1.0 - distToDailyLow)  * 40.0;
   }
   if(liq.nearEqualHighs || liq.nearEqualLows) score += 20.0;
   if(liq.inCompressionZone) score += 15.0;
   liq.liquidityRelevanceScore = MathMax(0.0, MathMin(100.0, score));

   g_liquidity = liq;
}

//=======================================================================
//  LAYER 6 - FLOW PRESSURE ENGINE
//  MT5 CFD feeds lack order-book/DOM data, so this builds PROXY models
//  from tick imbalance, directional persistence, and magnitude bias.
//=======================================================================
struct FlowPressureState
{
   double bullPressure;
   double bearPressure;
   double netPressure;
   double confidence;
};
FlowPressureState g_flow;

#define TICK_SAMPLE_SIZE 50
double   g_tickPriceSamples[TICK_SAMPLE_SIZE];
int      g_tickSampleCount = 0;
double   g_lastSampledBid = 0.0;

void L6_SampleTick()
{
   double bid = g_md.bid;
   if(g_lastSampledBid == 0.0) { g_lastSampledBid = bid; return; }
   if(bid == g_lastSampledBid) return;

   if(g_tickSampleCount < TICK_SAMPLE_SIZE)
   {
      g_tickPriceSamples[g_tickSampleCount] = bid - g_lastSampledBid;
      g_tickSampleCount++;
   }
   else
   {
      for(int i = 0; i < TICK_SAMPLE_SIZE - 1; i++)
         g_tickPriceSamples[i] = g_tickPriceSamples[i+1];
      g_tickPriceSamples[TICK_SAMPLE_SIZE - 1] = bid - g_lastSampledBid;
   }
   g_lastSampledBid = bid;
}

void L6_UpdateFlowPressure()
{
   FlowPressureState f;
   ZeroMemory(f);

   if(g_tickSampleCount < 10)
   {
      f.confidence = (double)g_tickSampleCount / 10.0 * 100.0;
      g_flow = f;
      return;
   }

   int upTicks = 0, downTicks = 0;
   double upSum = 0.0, downSum = 0.0;
   for(int i = 0; i < g_tickSampleCount; i++)
   {
      if(g_tickPriceSamples[i] > 0) { upTicks++; upSum += g_tickPriceSamples[i]; }
      else if(g_tickPriceSamples[i] < 0) { downTicks++; downSum += MathAbs(g_tickPriceSamples[i]); }
   }

   int totalDirectional = upTicks + downTicks;
   if(totalDirectional == 0) { g_flow = f; return; }

   double tickImbalance = (double)upTicks / totalDirectional;

   int currentRun = 0, maxRun = 0, runDir = 0;
   for(int i = 0; i < g_tickSampleCount; i++)
   {
      int dir = (g_tickPriceSamples[i] > 0) ? 1 : ((g_tickPriceSamples[i] < 0) ? -1 : 0);
      if(dir == 0) continue;
      if(dir == runDir) currentRun++;
      else { currentRun = 1; runDir = dir; }
      if(currentRun > maxRun) maxRun = currentRun;
   }
   double persistenceScore = MathMin((double)maxRun / 8.0, 1.0);

   double magnitudeBias = 0.0;
   if((upSum + downSum) > 0)
      magnitudeBias = (upSum - downSum) / (upSum + downSum);

   double netBias = (tickImbalance - 0.5) * 2.0 * 0.5 + magnitudeBias * 0.3 + (persistenceScore * runDir) * 0.2;
   netBias = MathMax(-1.0, MathMin(1.0, netBias));

   f.bullPressure = MathMax(0.0, netBias) * 100.0;
   f.bearPressure = MathMax(0.0, -netBias) * 100.0;
   f.netPressure = netBias * 100.0;
   f.confidence = MathMin((double)g_tickSampleCount / TICK_SAMPLE_SIZE * 100.0, 100.0);

   g_flow = f;
}

//=======================================================================
//  LAYER 7 - SESSION INTELLIGENCE ENGINE
//  Recognizes Asia/London/NY/Overlap sessions (server-time based).
//=======================================================================
enum ENUM_SESSION
{
   SESSION_ASIA = 0,
   SESSION_LONDON,
   SESSION_NEWYORK,
   SESSION_OVERLAP_LONDON_NY,
   SESSION_OFF_HOURS
};

struct SessionStats
{
   double sumVolatility;
   double sumRange;
   int    sampleCount;
   int    falseBreakouts;
   int    totalBreakouts;
};
SessionStats g_sessionStats[5];

ENUM_SESSION g_currentSession = SESSION_OFF_HOURS;

input group "===== SESSION HOURS (server time, 24h) ====="
input int InpAsiaStartHour    = 0;
input int InpAsiaEndHour      = 8;
input int InpLondonStartHour  = 7;
input int InpLondonEndHour    = 16;
input int InpNYStartHour      = 12;
input int InpNYEndHour        = 21;

ENUM_SESSION L7_ClassifySession(datetime t)
{
   MqlDateTime dt;
   TimeToStruct(t, dt);
   int hour = dt.hour;

   bool inLondon = (hour >= InpLondonStartHour && hour < InpLondonEndHour);
   bool inNY     = (hour >= InpNYStartHour && hour < InpNYEndHour);
   bool inAsia   = (hour >= InpAsiaStartHour && hour < InpAsiaEndHour);

   if(inLondon && inNY) return SESSION_OVERLAP_LONDON_NY;
   if(inLondon) return SESSION_LONDON;
   if(inNY) return SESSION_NEWYORK;
   if(inAsia) return SESSION_ASIA;
   return SESSION_OFF_HOURS;
}

void L7_UpdateSession()
{
   g_currentSession = L7_ClassifySession(TimeCurrent());
   if(!g_md.isNewBar) return;

   SessionStats s = g_sessionStats[g_currentSession];
   double barRange = g_md.high1 - g_md.low1;
   s.sumRange += barRange;
   s.sumVolatility += g_md.atrM5;
   s.sampleCount++;

   if(g_liquidity.dailyHigh > 0 && g_md.high1 > g_liquidity.dailyHigh && g_md.close1 < g_liquidity.dailyHigh)
   {
      s.totalBreakouts++; s.falseBreakouts++;
   }
   else if(g_liquidity.dailyLow > 0 && g_md.low1 < g_liquidity.dailyLow && g_md.close1 > g_liquidity.dailyLow)
   {
      s.totalBreakouts++; s.falseBreakouts++;
   }

   g_sessionStats[g_currentSession] = s;
}

double L7_GetSessionAvgVolatility(ENUM_SESSION sess)
{
   if(g_sessionStats[sess].sampleCount == 0) return 0.0;
   return g_sessionStats[sess].sumVolatility / g_sessionStats[sess].sampleCount;
}

double L7_GetSessionFalseBreakoutRate(ENUM_SESSION sess)
{
   if(g_sessionStats[sess].totalBreakouts == 0) return 0.0;
   return (double)g_sessionStats[sess].falseBreakouts / g_sessionStats[sess].totalBreakouts * 100.0;
}

//=======================================================================
//  PART 2 INTEGRATION HOOK - called from OnTick (wired in Part 3, since
//  Part 3 also rewrites OnTick's tail to add Fusion + Router execution)
//=======================================================================
void Part2_RunAnalysisLayers()
{
   L6_SampleTick();
   L2_UpdateMarketState();
   L3_UpdateStructure();
   L4_UpdateVolatility();
   L5_UpdateLiquidity();
   L6_UpdateFlowPressure();
   L7_UpdateSession();
}

//+------------------------------------------------------------------+
//|                    PART 3 / 3                                     |
//|  Layer 8 (Probability Fusion), Layer 10 (Execution Intelligence + |
//|  tranching, replacing legacy fixed bulk-N), Layer 11 (Trade        |
//|  Management - regime-aware exits, replacing legacy fixed TP),     |
//|  Layer 12 (Strategy Health), and the Meta Router - the ONLY        |
//|  component authorized to place trades. OnTick is rewired at the   |
//|  bottom of this section to call everything in sequence.           |
//+------------------------------------------------------------------+

//=======================================================================
//  STRATEGY MODULES - lightweight signal generators. Each module only
//  PROPOSES a direction + rough conviction; it does NOT decide whether
//  to trade. The Meta Router is the sole authority for that decision.
//=======================================================================
struct StrategyProposal
{
   ENUM_STRATEGY_ID id;
   int    direction;     // 1 = buy, -1 = sell, 0 = no proposal
   double rawConviction; // 0-100, this module's own confidence
   bool   eligible;      // false if current regime/health excludes this module
};

// --- Trend Continuation: trades WITH structure + trend regime ---
StrategyProposal Strategy_TrendContinuation()
{
   StrategyProposal p;
   ZeroMemory(p);
   p.id = STRATEGY_TREND_CONTINUATION;
   p.eligible = (g_state.pTrendExpansion > 40.0 && g_structure.swingDirection != 0);
   if(!p.eligible) return p;

   p.direction = g_structure.swingDirection;
   double convict = (g_state.pTrendExpansion * 0.5) + (g_structure.structureStrength * 0.3) + (g_structure.pullbackQuality * 0.2);
   p.rawConviction = MathMax(0.0, MathMin(100.0, convict));
   return p;
}

// --- Breakout: trades expansion out of compression, confirmed by flow ---
StrategyProposal Strategy_Breakout()
{
   StrategyProposal p;
   ZeroMemory(p);
   p.id = STRATEGY_BREAKOUT;
   p.eligible = (g_liquidity.inCompressionZone && g_vol.state == VOL_EXPANDING);
   if(!p.eligible) return p;

   p.direction = (g_flow.netPressure > 0) ? 1 : ((g_flow.netPressure < 0) ? -1 : 0);
   if(p.direction == 0) { p.eligible = false; return p; }

   double convict = (g_vol.compositeIndex * 0.4) + (MathAbs(g_flow.netPressure) * 0.4) + (g_liquidity.liquidityRelevanceScore * 0.2);
   p.rawConviction = MathMax(0.0, MathMin(100.0, convict));
   return p;
}

// --- Liquidity Sweep: trades reversal after a stop-hunt style wick
//     through an equal-high/low or daily extreme ---
StrategyProposal Strategy_LiquiditySweep()
{
   StrategyProposal p;
   ZeroMemory(p);
   p.id = STRATEGY_LIQUIDITY_SWEEP;

   double body   = MathAbs(g_md.open1 - g_md.close1);
   double wickUp = g_md.high1 - MathMax(g_md.open1, g_md.close1);
   double wickDn = MathMin(g_md.open1, g_md.close1) - g_md.low1;

   bool sweepHigh = (wickUp > body * 2.0) && (g_liquidity.nearEqualHighs || g_md.high1 >= g_liquidity.dailyHigh * 0.999);
   bool sweepLow  = (wickDn > body * 2.0) && (g_liquidity.nearEqualLows  || g_md.low1  <= g_liquidity.dailyLow * 1.001);

   p.eligible = (sweepHigh || sweepLow);
   if(!p.eligible) return p;

   p.direction = sweepHigh ? -1 : 1; // fade the sweep
   double convict = g_liquidity.liquidityRelevanceScore * 0.6 + (MathAbs(g_flow.netPressure) * 0.4);
   p.rawConviction = MathMax(0.0, MathMin(100.0, convict));
   return p;
}

// --- Range Reversion: trades back toward the mid-band in range regime ---
StrategyProposal Strategy_RangeReversion()
{
   StrategyProposal p;
   ZeroMemory(p);
   p.id = STRATEGY_RANGE_REVERSION;
   p.eligible = (g_state.pRange > 45.0 && g_vol.state != VOL_CHAOTIC && g_vol.state != VOL_EXTREME);
   if(!p.eligible) return p;

   double price = g_md.bid;
   if(price >= g_md.bandsUpper) p.direction = -1;
   else if(price <= g_md.bandsLower) p.direction = 1;
   else { p.eligible = false; return p; }

   double bandWidth = g_md.bandsUpper - g_md.bandsLower;
   double distFromMid = MathAbs(price - g_md.bandsMid);
   double convict = g_state.pRange * 0.5 + MathMin(distFromMid / MathMax(bandWidth/2.0, 0.0001), 1.0) * 50.0;
   p.rawConviction = MathMax(0.0, MathMin(100.0, convict));
   return p;
}

// --- Momentum Expansion: trades fresh impulsive moves, shock-aware ---
StrategyProposal Strategy_MomentumExpansion()
{
   StrategyProposal p;
   ZeroMemory(p);
   p.id = STRATEGY_MOMENTUM_EXPANSION;
   p.eligible = (g_structure.impulseQuality > 55.0 && g_vol.state == VOL_EXPANDING);
   if(!p.eligible) return p;

   p.direction = g_structure.swingDirection;
   if(p.direction == 0) { p.eligible = false; return p; }

   double convict = g_structure.impulseQuality * 0.5 + g_vol.compositeIndex * 0.3 + g_structure.trendEfficiency * 0.2;
   p.rawConviction = MathMax(0.0, MathMin(100.0, convict));
   return p;
}

//=======================================================================
//  LAYER 12 - STRATEGY HEALTH ENGINE
//  Tracks each module's performance separately and auto-throttles
//  underperforming modules. Persisted to disk so it survives restarts.
//=======================================================================
struct StrategyHealthRecord
{
   int    totalTrades;
   int    wins;
   int    losses;
   double grossProfit;
   double grossLoss;
   double sumR;            // sum of R-multiples for averaging
   double maxDrawdown;
   double peakEquitySinceStart;
   bool   throttled;
};
StrategyHealthRecord g_health[6]; // indexed by ENUM_STRATEGY_ID (0=NONE unused)

string L12_GetHealthFilePath() { return "NOVA_TITAN_X_health.bin"; }

void L12_SaveHealth()
{
   int fh = FileOpen(L12_GetHealthFilePath(), FILE_WRITE | FILE_BIN | FILE_COMMON);
   if(fh == INVALID_HANDLE) { Print("[L12] Could not open health file for write. err=", GetLastError()); return; }
   for(int i = 0; i < 6; i++)
      FileWriteStruct(fh, g_health[i]);
   FileClose(fh);
}

void L12_LoadHealth()
{
   if(!FileIsExist(L12_GetHealthFilePath(), FILE_COMMON)) return;
   int fh = FileOpen(L12_GetHealthFilePath(), FILE_READ | FILE_BIN | FILE_COMMON);
   if(fh == INVALID_HANDLE) return;
   for(int i = 0; i < 6 && !FileIsEnding(fh); i++)
      FileReadStruct(fh, g_health[i]);
   FileClose(fh);
}

double L12_GetProfitFactor(ENUM_STRATEGY_ID id)
{
   StrategyHealthRecord h = g_health[id];
   if(h.grossLoss <= 0) return (h.grossProfit > 0) ? 99.0 : 0.0;
   return h.grossProfit / h.grossLoss;
}

double L12_GetExpectancy(ENUM_STRATEGY_ID id)
{
   StrategyHealthRecord h = g_health[id];
   if(h.totalTrades == 0) return 0.0;
   return h.sumR / h.totalTrades;
}

double L12_GetWinRate(ENUM_STRATEGY_ID id)
{
   StrategyHealthRecord h = g_health[id];
   if(h.totalTrades == 0) return 0.0;
   return (double)h.wins / h.totalTrades * 100.0;
}

void L12_RegisterResult(ENUM_STRATEGY_ID id, double pnl, double rMultiple)
{
   StrategyHealthRecord h = g_health[id];
   h.totalTrades++;
   if(pnl >= 0) { h.wins++; h.grossProfit += pnl; }
   else         { h.losses++; h.grossLoss += MathAbs(pnl); }
   h.sumR += rMultiple;
   g_health[id] = h;

   // Auto-throttle: after a meaningful sample, if profit factor drops
   // below 1.0 and expectancy is negative, throttle the module (it is
   // excluded from the Router's eligible set until it recovers - see
   // MetaRouter_Evaluate). This persists until enough new trades shift
   // the stats back above threshold.
   if(h.totalTrades >= 10)
   {
      double pf = L12_GetProfitFactor(id);
      double exp = L12_GetExpectancy(id);
      g_health[id].throttled = (pf < 1.0 && exp < 0.0);
   }

   L12_SaveHealth();
}

//=======================================================================
//  LAYER 8 - PROBABILITY FUSION ENGINE
//  No strategy trades directly. All proposals pass through fusion,
//  which blends regime/structure/volatility/liquidity/pressure/session/
//  health/execution-quality evidence into one 0-100 trade probability
//  per proposal. Weights are configurable inputs.
//=======================================================================
input group "===== FUSION WEIGHTS (Layer 8, must look reasonable; rebalanced automatically if they don't sum to 1) ====="
input double InpWeight_StrategyConviction = 0.30;
input double InpWeight_Regime             = 0.15;
input double InpWeight_Structure          = 0.15;
input double InpWeight_Volatility         = 0.10;
input double InpWeight_Liquidity          = 0.10;
input double InpWeight_FlowPressure       = 0.10;
input double InpWeight_StrategyHealth     = 0.10;

struct FusionResult
{
   ENUM_STRATEGY_ID sourceStrategy;
   int    direction;
   double probability; // 0-100
   string breakdown;
};

FusionResult L8_Fuse(const StrategyProposal &p)
{
   FusionResult r;
   ZeroMemory(r);
   r.sourceStrategy = p.id;
   r.direction = p.direction;

   if(!p.eligible || p.direction == 0)
   {
      r.probability = 0.0;
      r.breakdown = "Not eligible";
      return r;
   }

   // Regime alignment score: how much does the dominant/relevant regime
   // probability support this proposal's implied regime requirement
   double regimeScore = 0.0;
   switch(p.id)
   {
      case STRATEGY_TREND_CONTINUATION:
      case STRATEGY_MOMENTUM_EXPANSION:
         regimeScore = g_state.pTrendExpansion;
         break;
      case STRATEGY_RANGE_REVERSION:
         regimeScore = g_state.pRange;
         break;
      case STRATEGY_BREAKOUT:
         regimeScore = 100.0 - g_state.pRange; // breakout wants NOT range
         break;
      case STRATEGY_LIQUIDITY_SWEEP:
         regimeScore = MathMax(g_state.pTrendExhaustion, g_state.pTransition);
         break;
      default:
         regimeScore = 50.0;
   }
   // Shock regime universally suppresses everything except explicit
   // shock-handling logic (none implemented yet -> always suppress)
   regimeScore *= (1.0 - g_state.pShock / 100.0);

   double structureScore = (p.direction == g_structure.swingDirection)
                            ? g_structure.structureStrength
                            : MathMax(0.0, 50.0 - g_structure.structureStrength * 0.5);

   double volScore;
   switch(g_vol.state)
   {
      case VOL_SUPPRESSED: volScore = 30.0; break;
      case VOL_NORMAL:     volScore = 80.0; break;
      case VOL_EXPANDING:  volScore = 90.0; break;
      case VOL_EXTREME:    volScore = 40.0; break;
      case VOL_CHAOTIC:    volScore = 0.0;  break;
      default:             volScore = 50.0;
   }

   double liqScore = g_liquidity.liquidityRelevanceScore;

   double flowScore;
   {
      double agree = (p.direction == 1) ? g_flow.bullPressure : g_flow.bearPressure;
      flowScore = agree * (g_flow.confidence / 100.0) + 50.0 * (1.0 - g_flow.confidence / 100.0);
   }

   double healthScore = 50.0;
   if(g_health[p.id].totalTrades >= 10)
   {
      healthScore = g_health[p.id].throttled ? 10.0 : MathMin(100.0, 50.0 + L12_GetExpectancy(p.id) * 10.0);
   }

   // Rebalance weights defensively in case inputs don't sum to 1.0
   double wSum = InpWeight_StrategyConviction + InpWeight_Regime + InpWeight_Structure +
                 InpWeight_Volatility + InpWeight_Liquidity + InpWeight_FlowPressure + InpWeight_StrategyHealth;
   if(wSum <= 0) wSum = 1.0;

   double fused = (p.rawConviction * InpWeight_StrategyConviction +
                   regimeScore      * InpWeight_Regime +
                   structureScore   * InpWeight_Structure +
                   volScore         * InpWeight_Volatility +
                   liqScore         * InpWeight_Liquidity +
                   flowScore        * InpWeight_FlowPressure +
                   healthScore      * InpWeight_StrategyHealth) / wSum;

   r.probability = MathMax(0.0, MathMin(100.0, fused));
   r.breakdown = StringFormat("conv=%.0f regime=%.0f struct=%.0f vol=%.0f liq=%.0f flow=%.0f health=%.0f",
                               p.rawConviction, regimeScore, structureScore, volScore, liqScore, flowScore, healthScore);
   return r;
}

//=======================================================================
//  LAYER 10 - EXECUTION INTELLIGENCE ENGINE
//  Institutional-style execution quality checks + tranche splitting.
//  This REPLACES the legacy EA's fixed "bulk-7" identical-size blind
//  order spam with: (a) a pre-trade execution quality gate, and (b) a
//  tranche count derived from total intended size, capped by
//  InpMaxTranches, with per-leg delay - never multiplied by a loss
//  streak.
//=======================================================================
struct ExecutionQuality
{
   double spreadScore;       // 0-100, 100 = excellent
   double slippageRiskScore; // 0-100, proxy from recent spread volatility
   double overallScore;      // 0-100
   bool   acceptable;
};

double g_recentSpreadSamples[20];
int    g_recentSpreadCount = 0;

void L10_SampleSpreadForSlippageProxy()
{
   if(g_recentSpreadCount < 20)
      g_recentSpreadSamples[g_recentSpreadCount++] = g_md.spreadPoints;
   else
   {
      for(int i = 0; i < 19; i++) g_recentSpreadSamples[i] = g_recentSpreadSamples[i+1];
      g_recentSpreadSamples[19] = g_md.spreadPoints;
   }
}

ExecutionQuality L10_AssessExecutionQuality()
{
   ExecutionQuality q;
   ZeroMemory(q);

   // Spread score: comfort-zone curve (this is the fix the legacy v2
   // BTC EA needed after its dead-zone bug - normal spreads should
   // score near 100, with decay only once spread genuinely widens
   // beyond a comfort multiple of the symbol's baseline).
   double ratio = (g_baselineSpreadPoints > 0) ? g_md.spreadPoints / g_baselineSpreadPoints : 1.0;
   if(ratio <= 1.3)
      q.spreadScore = 100.0;
   else if(ratio <= 3.0)
      q.spreadScore = 100.0 - (ratio - 1.3) / (3.0 - 1.3) * 60.0; // decays 100 -> 40
   else
      q.spreadScore = MathMax(0.0, 40.0 - (ratio - 3.0) * 10.0);

   // Slippage risk proxy: variance of recent spread samples - choppy
   // spread behavior implies choppy fill quality
   double mean = 0.0;
   for(int i = 0; i < g_recentSpreadCount; i++) mean += g_recentSpreadSamples[i];
   if(g_recentSpreadCount > 0) mean /= g_recentSpreadCount;
   double variance = 0.0;
   for(int i = 0; i < g_recentSpreadCount; i++) variance += MathPow(g_recentSpreadSamples[i] - mean, 2);
   if(g_recentSpreadCount > 0) variance /= g_recentSpreadCount;
   double stdDev = MathSqrt(variance);
   q.slippageRiskScore = MathMax(0.0, 100.0 - stdDev * 5.0);

   q.overallScore = q.spreadScore * 0.6 + q.slippageRiskScore * 0.4;
   q.acceptable = (q.overallScore >= 50.0) && !g_cap.lockExecutionQuality;
   return q;
}

// Determines tranche count for a given total lot size. Replaces the
// legacy fixed InpBulkTrades constant entirely - tranche count now
// scales with position size, not with consecutive losses.
int L10_ResolveTrancheCount(double totalLot)
{
   if(!InpUseTrancheExecution) return 1;
   if(totalLot < InpTrancheSizeThreshold) return 1;

   int tranches = (int)MathCeil(totalLot / InpTrancheSizeThreshold);
   return (int)MathMax(1, MathMin(InpMaxTranches, tranches));
}

// Executes the trade across N tranches with a millisecond delay between
// legs (TWAP-style distribution per spec Layer 10), splitting risk
// evenly. SL/TP are computed once and applied identically to each leg.
bool L10_ExecuteTrancheEntry(ENUM_ORDER_TYPE otype, double totalLot, double sl, double tp, string comment)
{
   int tranches = L10_ResolveTrancheCount(totalLot);
   double lotStep = SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_STEP);
   double lotMin  = SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_MIN);
   if(lotStep <= 0) lotStep = 0.01;

   double perLegLot = MathFloor((totalLot / tranches) / lotStep) * lotStep;
   if(perLegLot < lotMin) { perLegLot = lotMin; tranches = (int)MathMax(1, MathFloor(totalLot / perLegLot)); }
   if(perLegLot <= 0) return false;

   double allocatedSoFar = 0.0;
   bool anySuccess = false;

   for(int i = 0; i < tranches; i++)
   {
      double legLot = perLegLot;
      // Last leg absorbs any rounding remainder so total size matches intent
      if(i == tranches - 1)
      {
         double remainder = totalLot - allocatedSoFar;
         legLot = MathFloor(remainder / lotStep) * lotStep;
         if(legLot < lotMin) legLot = lotMin;
      }
      if(legLot <= 0) continue;

      double price = (otype == ORDER_TYPE_BUY) ? SymbolInfoDouble(Symbol(), SYMBOL_ASK) : SymbolInfoDouble(Symbol(), SYMBOL_BID);
      bool ok = (otype == ORDER_TYPE_BUY)
                ? g_trade.Buy(legLot, Symbol(), price, sl, tp, comment)
                : g_trade.Sell(legLot, Symbol(), price, sl, tp, comment);

      if(ok) { anySuccess = true; allocatedSoFar += legLot; }
      else   Print("[L10] Tranche leg ", i+1, "/", tranches, " failed. err=", GetLastError());

      if(i < tranches - 1 && InpTrancheDelayMs > 0)
         Sleep(InpTrancheDelayMs);
   }

   return anySuccess;
}

//=======================================================================
//  LAYER 11 - ADVANCED TRADE MANAGEMENT ENGINE
//  Manages open positions through regime-aware state transitions
//  instead of a static TP. Replaces the legacy fixed InpTakeProfitPct/
//  InpProfitTargetUSD single-shot exit entirely.
//=======================================================================
input group "===== TRADE MANAGEMENT (Layer 11) ====="
input double InpInitialSL_ATRMult        = 2.0;
input double InpTrailStart_ATRMult       = 1.5;   // start trailing once price moves this many ATR in favor
input double InpTrailStep_ATRMult        = 1.0;   // trail distance once active
input double InpPartialCloseAtR          = 1.0;   // close partial at this R multiple
input double InpPartialClosePct          = 50.0;  // % of position to close at that R
input int    InpTimeStopMinutes          = 240;   // close dead trades after this long with no progress
input double InpTimeStopMinProgressR     = 0.3;   // "progress" threshold below which time-stop triggers

struct ManagedPositionMeta
{
   ulong  ticket;
   double initialSLDistance; // in price terms, for R calculation
   double entryPrice;
   datetime openTime;
   bool   partialDone;
   double volumeAtOpen;       // lots, needed to convert $ pnl back to R correctly
   ENUM_STRATEGY_ID strategyId; // which strategy authorized this entry (for health attribution)
};
// Simple fixed-size table since BTCUSD single-symbol EA won't have many
// concurrent positions; linear scan is fine at this scale.
#define MAX_TRACKED_POSITIONS 50
ManagedPositionMeta g_trackedPositions[MAX_TRACKED_POSITIONS];
int g_trackedCount = 0;

int L11_FindTrackedIndex(ulong ticket)
{
   for(int i = 0; i < g_trackedCount; i++)
      if(g_trackedPositions[i].ticket == ticket) return i;
   return -1;
}

void L11_TrackNewPosition(ulong ticket, double slDistance, double entryPrice, double volume, ENUM_STRATEGY_ID sid)
{
   if(g_trackedCount >= MAX_TRACKED_POSITIONS) return;
   ManagedPositionMeta m;
   m.ticket = ticket;
   m.initialSLDistance = slDistance;
   m.entryPrice = entryPrice;
   m.openTime = TimeCurrent();
   m.partialDone = false;
   m.volumeAtOpen = volume;
   m.strategyId = sid;
   g_trackedPositions[g_trackedCount++] = m;
}

void L11_RemoveTrackedPosition(int idx)
{
   if(idx < 0 || idx >= g_trackedCount) return;
   for(int i = idx; i < g_trackedCount - 1; i++)
      g_trackedPositions[i] = g_trackedPositions[i+1];
   g_trackedCount--;
}

void L11_ManageOpenPositions()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(!g_pos.SelectByIndex(i)) continue;
      if(g_pos.Magic() != InpMagicNumber || g_pos.Symbol() != Symbol()) continue;

      ulong ticket = g_pos.Ticket();
      int idx = L11_FindTrackedIndex(ticket);
      if(idx < 0)
      {
         // Position exists but wasn't tracked (e.g. EA restarted) -
         // adopt it with a best-effort SL distance estimate
         double estSL = (g_pos.StopLoss() > 0) ? MathAbs(g_pos.PriceOpen() - g_pos.StopLoss()) : g_md.atrM5 * InpInitialSL_ATRMult;
         L11_TrackNewPosition(ticket, estSL, g_pos.PriceOpen(), g_pos.Volume(), STRATEGY_NONE);
         idx = L11_FindTrackedIndex(ticket);
      }
      if(idx < 0) continue;

      ManagedPositionMeta meta = g_trackedPositions[idx];
      bool isBuy = (g_pos.PositionType() == POSITION_TYPE_BUY);
      double currentPrice = isBuy ? g_md.bid : g_md.ask;
      double favorableMove = isBuy ? (currentPrice - meta.entryPrice) : (meta.entryPrice - currentPrice);
      double rMultiple = (meta.initialSLDistance > 0) ? favorableMove / meta.initialSLDistance : 0.0;

      // --- Volatility Extreme: reduce exposure immediately ---
      if(g_vol.state == VOL_EXTREME || g_vol.state == VOL_CHAOTIC)
      {
         if(!meta.partialDone)
         {
            double closeVolume = g_pos.Volume() * 0.5;
            if(g_trade.PositionClosePartial(ticket, closeVolume))
            {
               g_trackedPositions[idx].partialDone = true;
               LogVerbose(StringFormat("Position %I64u partially closed (50%%) due to %s volatility state.",
                          ticket, EnumToString(g_vol.state)));
            }
         }
      }

      // --- Partial close at target R (only once, if vol-driven partial hasn't already fired) ---
      if(!g_trackedPositions[idx].partialDone && rMultiple >= InpPartialCloseAtR)
      {
         double closeVolume = g_pos.Volume() * (InpPartialClosePct / 100.0);
         double lotStep = SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_STEP);
         closeVolume = MathFloor(closeVolume / lotStep) * lotStep;
         if(closeVolume > 0 && g_trade.PositionClosePartial(ticket, closeVolume))
         {
            g_trackedPositions[idx].partialDone = true;
            LogVerbose(StringFormat("Position %I64u partial close at R=%.2f", ticket, rMultiple));
         }
      }

      // --- Adaptive trailing: behavior depends on regime ---
      if(rMultiple >= InpTrailStart_ATRMult)
      {
         double trailDistance = g_md.atrM5 * InpTrailStep_ATRMult;
         // Trend Exhaustion -> tighten trailing per spec
         if(g_state.pTrendExhaustion > 50.0)
            trailDistance *= 0.5;
         // Trend Expansion -> let winners run, looser trail
         else if(g_state.pTrendExpansion > 60.0)
            trailDistance *= 1.5;

         double newSL = isBuy ? NPrice(currentPrice - trailDistance) : NPrice(currentPrice + trailDistance);
         double existingSL = g_pos.StopLoss();
         bool shouldUpdate = isBuy ? (newSL > existingSL) : (newSL < existingSL || existingSL == 0);
         if(shouldUpdate)
            g_trade.PositionModify(ticket, newSL, g_pos.TakeProfit());
      }

      // --- Time stop: close dead trades with no real progress ---
      int minutesOpen = (int)((TimeCurrent() - meta.openTime) / 60);
      if(minutesOpen >= InpTimeStopMinutes && rMultiple < InpTimeStopMinProgressR)
      {
         double pnl = g_pos.Profit() + g_pos.Swap() + g_pos.Commission();
         if(g_trade.PositionClose(ticket))
         {
            LogVerbose(StringFormat("Position %I64u closed by TIME STOP after %d min, R=%.2f", ticket, minutesOpen, rMultiple));
            L12_RegisterResult(meta.strategyId, pnl, rMultiple);
            L13_RegisterTradeResult(pnl);
            L11_RemoveTrackedPosition(idx);
            continue;
         }
      }
   }

   // Clean up tracked entries for positions that no longer exist (closed
   // by SL/TP hit rather than explicit management action above)
   for(int i = g_trackedCount - 1; i >= 0; i--)
   {
      if(!PositionSelectByTicket(g_trackedPositions[i].ticket))
      {
         // Position is gone - look up its closing deal to register health/cap stats
         ulong ticket = g_trackedPositions[i].ticket;
         if(HistorySelectByPosition(ticket))
         {
            int deals = HistoryDealsTotal();
            for(int d = 0; d < deals; d++)
            {
               ulong dt = HistoryDealGetTicket(d);
               if(HistoryDealGetInteger(dt, DEAL_ENTRY) == DEAL_ENTRY_OUT)
               {
                  double pnl = HistoryDealGetDouble(dt, DEAL_PROFIT) + HistoryDealGetDouble(dt, DEAL_SWAP) + HistoryDealGetDouble(dt, DEAL_COMMISSION);
                  double slDist = g_trackedPositions[i].initialSLDistance;
                  double vol = g_trackedPositions[i].volumeAtOpen;
                  double tickValue = SymbolInfoDouble(Symbol(), SYMBOL_TRADE_TICK_VALUE);
                  double tickSize  = SymbolInfoDouble(Symbol(), SYMBOL_TRADE_TICK_SIZE);
                  double rMult = 0.0;
                  if(slDist > 0 && vol > 0 && tickSize > 0)
                  {
                     double riskAmountForThisPosition = slDist * (tickValue / tickSize) * vol;
                     rMult = (riskAmountForThisPosition > 0) ? pnl / riskAmountForThisPosition : 0.0;
                  }
                  ENUM_STRATEGY_ID sid = g_trackedPositions[i].strategyId;
                  if(sid >= STRATEGY_NONE && sid <= STRATEGY_MOMENTUM_EXPANSION)
                     L12_RegisterResult(sid, pnl, rMult);
                  L13_RegisterTradeResult(pnl);
                  g_sessProfitToday += pnl;
                  if(pnl >= 0) g_sessWinsToday++; else g_sessLossesToday++;
               }
            }
         }
         L11_RemoveTrackedPosition(i);
      }
   }
}

//=======================================================================
//  META ROUTER
//  The ONLY component authorized to place trades. Evaluates all
//  strategy proposals through fusion, checks health/risk/execution
//  quality, and either ALLOWs or STANDS_ASIDE.
//=======================================================================
void MetaRouter_Evaluate()
{
   if(HasOpenPosition()) return; // one position at a time, framework default

   StrategyProposal proposals[5];
   proposals[0] = Strategy_TrendContinuation();
   proposals[1] = Strategy_Breakout();
   proposals[2] = Strategy_LiquiditySweep();
   proposals[3] = Strategy_RangeReversion();
   proposals[4] = Strategy_MomentumExpansion();

   FusionResult best;
   ZeroMemory(best);
   best.probability = -1.0;

   for(int i = 0; i < 5; i++)
   {
      if(!proposals[i].eligible) continue;
      if(g_health[proposals[i].id].throttled)
      {
         LogVerbose(StringFormat("Strategy %s throttled by health engine - skipped.", EnumToString(proposals[i].id)));
         continue;
      }
      FusionResult fr = L8_Fuse(proposals[i]);
      if(fr.probability > best.probability)
         best = fr;
   }

   if(best.probability < InpMinProbToTrade)
   {
      g_statusText = StringFormat("STAND_ASIDE (best=%.0f%%)", MathMax(best.probability,0.0));
      g_statusColor = C_GOLD;
      return;
   }

   ExecutionQuality eq = L10_AssessExecutionQuality();
   if(!eq.acceptable)
   {
      g_statusText = StringFormat("STAND_ASIDE (exec quality %.0f)", eq.overallScore);
      g_statusColor = C_ORANGE;
      LogVerbose("Router: signal present but execution quality unacceptable - standing aside.");
      return;
   }

   double slDistancePrice = g_md.atrM5 * InpInitialSL_ATRMult;
   if(slDistancePrice <= 0)
   {
      g_statusText = "STAND_ASIDE (invalid ATR)";
      g_statusColor = C_RED;
      return;
   }
   double point = SymbolInfoDouble(Symbol(), SYMBOL_POINT);
   double slDistancePoints = (point > 0) ? slDistancePrice / point : 0;

   L9_ResolveRisk(best.probability, slDistancePoints);
   if(!g_riskDecision.tradeAllowed)
   {
      g_statusText = "STAND_ASIDE (" + g_riskDecision.reason + ")";
      g_statusColor = C_ORANGE;
      return;
   }

   ENUM_ORDER_TYPE otype = (best.direction == 1) ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
   double entryPrice = (otype == ORDER_TYPE_BUY) ? g_md.ask : g_md.bid;
   double sl = (otype == ORDER_TYPE_BUY) ? NPrice(entryPrice - slDistancePrice) : NPrice(entryPrice + slDistancePrice);
   double tp = 0.0; // no static TP - Layer 11 manages exits dynamically

   // Nudge SL to respect the broker's minimum stop distance
   {
      int stopsLevel = (int)SymbolInfoInteger(Symbol(), SYMBOL_TRADE_STOPS_LEVEL);
      double minDist = stopsLevel * point;
      if(otype == ORDER_TYPE_BUY) { if((entryPrice - sl) < minDist) sl = NPrice(entryPrice - minDist); }
      else                         { if((sl - entryPrice) < minDist) sl = NPrice(entryPrice + minDist); }
   }

   // Strategy attribution for Layer 12 health tracking is done via the
   // ManagedPositionMeta table (strategyId field), populated right
   // below when each opened position is tracked - NOT via magic number
   // encoding, since CTrade uses one global expert magic and per-trade
   // comments aren't reliably parseable across all broker server setups.
   // The comment field below is purely for human-readable identification
   // in the MT5 terminal's trade history.
   string comment = InpBotName + "_" + EnumToString(best.sourceStrategy);

   bool opened = L10_ExecuteTrancheEntry(otype, g_riskDecision.lotSize, sl, tp, comment);
   if(opened)
   {
      // Track every newly opened position belonging to this magic that
      // isn't already tracked (covers all tranche legs at once)
      for(int i = 0; i < PositionsTotal(); i++)
      {
         if(!g_pos.SelectByIndex(i)) continue;
         if(g_pos.Magic() != InpMagicNumber || g_pos.Symbol() != Symbol()) continue;
         ulong tk = g_pos.Ticket();
         if(L11_FindTrackedIndex(tk) < 0)
            L11_TrackNewPosition(tk, slDistancePrice, g_pos.PriceOpen(), g_pos.Volume(), best.sourceStrategy);
      }
      g_sessTradesToday++;
      g_lastAction = StringFormat("ALLOW: %s prob=%.0f%% lot=%.2f", EnumToString(best.sourceStrategy), best.probability, g_riskDecision.lotSize);
      g_statusText = "IN TRADE";
      g_statusColor = C_GREEN;
      LogVerbose(g_lastAction + " | " + best.breakdown);
   }
   else
   {
      g_statusText = "EXECUTION FAILED";
      g_statusColor = C_RED;
      Print("[Router] Trade execution failed despite ALLOW decision. err=", GetLastError());
   }
}

bool HasOpenPosition()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
      if(g_pos.SelectByIndex(i) && g_pos.Magic() == InpMagicNumber && g_pos.Symbol() == Symbol())
         return true;
   return false;
}

//=======================================================================
//  OnTick DISPATCH - called from Part 1's OnTick (single OnTick exists
//  in this file, per MQL5's one-handler-per-symbol rule). This function
//  runs Layers 2-12 and the Meta Router, in order, every tick that
//  clears Part 1's gates (self-diagnostic, capital protection locks,
//  market-open check, cooldown, daily trade cap).
//=======================================================================
void NTX_Dispatch_OnTick()
{
   L10_SampleSpreadForSlippageProxy();
   Part2_RunAnalysisLayers();
   L11_ManageOpenPositions();
   MetaRouter_Evaluate();
}

//+------------------------------------------------------------------+
//|                    END OF PART 3 / 3 - BUILD COMPLETE              |
//+------------------------------------------------------------------+
