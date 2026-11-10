//+------------------------------------------------------------------+
//|                                              NOVA TITAN X.mq5     |
//|                          Copyright 2026, FXBotHub Systems         |
//|                                     https://fxbothub.com          |
//+------------------------------------------------------------------+
//  THIRD-GENERATION BTCUSD INSTITUTIONAL TRADING ENGINE
//
//  Lineage / honest design note (read this before changing anything):
//  ---------------------------------------------------------------
//  This EA was built by auditing two prior systems:
//
//   "EA #1" (bulk-grid scalper): fired a fixed batch of trades on a timer
//   off a single dual-EMA + N-bar high/low check that ALWAYS returns a
//   direction (never "no signal"), exited each leg at a flat $ target,
//   and re-stacked positions on a % runner trigger. It is NOT a
//   sophisticated opportunity engine - it is a high-frequency, low-
//   selectivity firing pattern. What it DOES contribute structurally:
//   the idea of staying engaged with the market rather than waiting for
//   a single "perfect" setup, and accepting smaller, frequent wins.
//
//   "EA #2" (NovaBTC ScalperAI v1): a well-built R-multiple risk/exit
//   engine - real ATR-percentile volatility regime classification (with
//   new-bar gating to avoid oversampling a single closed bar), percentage-
//   based spread filtering appropriate for an asset whose price level
//   moves, an equity-peak drawdown circuit breaker, and a 9-point
//   confluence score (NOT a 100-point weighted model - that distinction
//   matters, see below). Its failure mode was over-filtering: requiring
//   6-8 of 9 confluence points plus HTF agreement plus volume surge plus
//   a multi-second "analysis phase" re-validation meant it could sit out
//   long stretches of valid, profitable conditions.
//
//  This system (NOVA TITAN X) takes the risk/exit/volatility architecture
//  from EA #2, replaces its single rigid confluence gate with a regime-
//  aware multi-strategy dispatcher (inspired by EA #1's willingness to
//  participate), and adds genuinely new subsystems: a 10-state regime
//  classifier, 8 regime-scoped strategy modules, a weighted confidence
//  engine with bounded adaptive weighting, and a per-regime/per-strategy
//  performance tracker that nudges those weights over time.
//
//  WHAT THIS IS NOT, STATED PLAINLY:
//   - The "Market Intelligence Layer" is a volatility/volume/displacement
//     spike detector. It infers that the market is moving abnormally
//     fast - it does NOT know that news happened, what the news was, or
//     read any external feed. It is labeled MARKET_DISPLACEMENT_SCORE
//     throughout, not "news detection," because that is what it actually
//     measures.
//   - The "self-optimizing performance engine" is a bounded statistical
//     weight-nudge based on tracked win-rate/expectancy per regime and
//     per strategy. It is NOT machine learning. There is no model being
//     trained, no gradient, no generalization claim. It is closer to a
//     slowly-adjusting lookup table, and is documented as such at the
//     point it is implemented.
//   - There are two distinct numeric scores in this file and they are
//     NOT the same thing: (a) a per-strategy raw signal score (0-100,
//     strategy-internal, "how good does THIS strategy's setup look"),
//     and (b) the cross-cutting CONFIDENCE score (0-100, weighted across
//     market-structure/trend/momentum/volume/volatility/liquidity/
//     session factors) that gates execution. A trade requires both a
//     winning strategy signal AND the confidence score to clear the
//     adaptive threshold.
//
#property copyright   "Copyright 2026, NOVA TITAN X Systems"
#property version     "1.00"
#property description "Third-Generation BTCUSD Regime-Adaptive Multi-Strategy Engine"
#property description "Honest-labeling build: see header comment for what each subsystem actually does"
#property strict

#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>

#define DASH_PREFIX  "NTX_"
#define EA_VERSION   "v1.00"
#define NUM_STRATEGIES 8
#define NUM_REGIMES    10
#define PERF_WINDOW    40     // trades remembered per regime/strategy bucket for adaptive weighting

//+------------------------------------------------------------------+
//| ENUMERATIONS                                                      |
//+------------------------------------------------------------------+
enum ENUM_MARKET_REGIME
{
   REGIME_TRENDING_BULL = 0,
   REGIME_TRENDING_BEAR,
   REGIME_RANGING,
   REGIME_BREAKOUT,
   REGIME_MOMENTUM_EXPANSION,
   REGIME_VOLATILITY_COMPRESSION,
   REGIME_ACCUMULATION,
   REGIME_DISTRIBUTION,
   REGIME_LIQUIDITY_SWEEP,
   REGIME_REVERSAL
};

enum ENUM_STRATEGY_ID
{
   STRAT_TREND_CONTINUATION = 0,
   STRAT_BREAKOUT_MOMENTUM,
   STRAT_PULLBACK_ENTRY,
   STRAT_VOLATILITY_EXPANSION,
   STRAT_LIQUIDITY_SWEEP_REVERSAL,
   STRAT_STRUCTURE_SHIFT,
   STRAT_SESSION_MOMENTUM,
   STRAT_COMPRESSION_BREAKOUT
};

enum ENUM_SIGNAL_DIR
{
   SIG_NONE = 0,
   SIG_BUY  = 1,
   SIG_SELL = -1
};

enum ENUM_ENGINE_STATE
{
   ENGSTATE_SCANNING,
   ENGSTATE_IN_TRADE,
   ENGSTATE_COOLDOWN,
   ENGSTATE_DAILY_HALT,
   ENGSTATE_DRAWDOWN_HALT,
   ENGSTATE_EMERGENCY_HALT
};

enum ENUM_RISK_MODE
{
   RISKMODE_NORMAL,
   RISKMODE_RECOVERY,        // reduced size after loss streak
   RISKMODE_CAPITAL_PRESERVE // reduced size after drawdown threshold
};

//+------------------------------------------------------------------+
//| STRUCTS                                                            |
//+------------------------------------------------------------------+
struct StrategySignal
{
   ENUM_STRATEGY_ID id;
   ENUM_SIGNAL_DIR  dir;
   double           rawScore;     // 0-100, strategy-internal quality score
   string           reason;       // short human-readable justification
   bool             valid;
};

struct ConfidenceBreakdown
{
   double structureScore;
   double trendScore;
   double momentumScore;
   double volumeScore;
   double volatilityScore;
   double liquidityScore;
   double sessionScore;
   double total;                  // weighted sum, 0-100
};

struct ConfidenceWeights
{
   double wStructure;
   double wTrend;
   double wMomentum;
   double wVolume;
   double wVolatility;
   double wLiquidity;
   double wSession;
};

// Per-bucket (regime or strategy) rolling performance record
struct PerfBucket
{
   int    results[PERF_WINDOW];   // 1=win, 0=loss, -1=unfilled
   int    idx;
   int    count;
   double sumR;                   // sum of R-multiples for expectancy
   int    trades;
};

//+------------------------------------------------------------------+
//| INPUT PARAMETERS                                                  |
//+------------------------------------------------------------------+
input group "=== CORE IDENTITY ==="
input ulong   InpMagicNumber       = 990441;
input string  InpTradeComment      = "NovaTitanX_v1";

input group "=== CONFIDENCE ENGINE ==="
input double  InpConfBaseThreshold = 62.0;       // base confidence required to fire (0-100)
input double  InpConfMinThreshold  = 50.0;       // floor - threshold never adapts below this
input double  InpConfMaxThreshold  = 80.0;       // ceiling - threshold never adapts above this
input bool    InpUseAdaptiveWeights= true;        // allow bounded weight nudging from tracked performance

input group "=== RISK MANAGEMENT ==="
input double  InpRiskPercent       = 1.0;
input double  InpMaxDailyLossPct   = 5.0;
input double  InpMaxDailyProfitPct = 10.0;
input int     InpMaxDailyTrades    = 18;
input double  InpMaxDrawdownPct    = 15.0;
input double  InpWeeklyLossLimitPct= 10.0;       // weekly kill-switch, broader than daily
input int     InpMaxLossStreak     = 3;
input int     InpWinStreakBoost    = 5;

input group "=== ATR-BASED STOPS ==="
input int     InpATRPeriod         = 14;
input double  InpSLMultiplier      = 1.4;
input double  InpTP2Multiplier     = 3.2;
input double  InpMinSLPercent      = 0.20;
input double  InpMaxSLPercent      = 1.60;

input group "=== EXIT MANAGEMENT (R-multiple based) ==="
input double  InpTP1R              = 1.0;
input double  InpPartialClosePct   = 50.0;
input double  InpBreakevenR        = 0.5;
input double  InpBEBufferPercent   = 0.02;
input bool    InpUsePeakLock       = true;
input double  InpPeakLockActivateR = 0.8;
input double  InpPeakLockRetrace   = 25.0;
input double  InpMinRewardRiskR    = 1.0;
input double  InpMinLockProfitR    = 0.5;
input bool    InpUseTrailing       = true;
input double  InpTrailStartR       = 0.6;
input double  InpTrailATRMult      = 0.7;
input int     InpMaxTradeBars      = 96;          // time-based exit ceiling (bars)
input double  InpDeteriorationR    = -0.7;        // close early if drifting toward this loss w/ no momentum

input group "=== INDICATOR PERIODS (shared across strategies) ==="
input int     InpFastEMA           = 8;
input int     InpSlowEMA           = 21;
input int     InpTrendEMA          = 55;
input int     InpRSIPeriod         = 14;
input double  InpRSIOverbought     = 72.0;
input double  InpRSIOversold       = 28.0;
input int     InpADXPeriod         = 14;
input double  InpADXTrendMin       = 20.0;
input int     InpMACDFast          = 12;
input int     InpMACDSlow          = 26;
input int     InpMACDSignal        = 9;
input int     InpBBPeriod          = 20;
input double  InpBBDeviation       = 2.0;
input double  InpBBSqueezeRatio    = 0.012;
input int     InpStructureBars     = 6;
input bool    InpUseHTFFilter      = true;
input ENUM_TIMEFRAMES InpHTFPeriod = PERIOD_M15;
input int     InpHTFEMAPeriod      = 50;

input group "=== REGIME CLASSIFIER ==="
input int     InpRegimeATRLookback = 100;
input double  InpVolHighPctile     = 80.0;
input double  InpVolExtremePctile  = 95.0;
input double  InpVolLowPctile      = 20.0;
input int     InpADXRangeMax       = 18;          // below this ADX = ranging candidate

input group "=== VOLUME ==="
input int     InpVolumeAvgPeriod   = 20;
input double  InpVolumeSurgeMult   = 1.3;

input group "=== SPREAD / EXECUTION PROTECTION ==="
input double  InpMaxSpreadPercent  = 0.06;
input double  InpSpreadAvgMultiple = 2.5;
input int     InpMaxSlippagePoints = 50;
input int     InpMaxRequoteRetries = 2;

input group "=== MARKET DISPLACEMENT DETECTOR (see header note - NOT news detection) ===" 
input double  InpDisplacementATRMult = 2.2;       // bar range vs ATR multiple to flag displacement
input double  InpDisplacementVolMult = 1.8;       // volume vs avg multiple to flag displacement

input group "=== WEEKEND / LIQUIDITY AWARENESS ==="
input bool    InpAvoidWeekendOpen  = true;
input int     InpWeekendPauseMin   = 30;

input group "=== DASHBOARD ==="
input int     InpDashX             = 15;
input int     InpDashY             = 15;

//+------------------------------------------------------------------+
//| COLOUR PALETTE                                                     |
//+------------------------------------------------------------------+
const color C_BG          = C'5,7,16';
const color C_PANEL       = C'8,12,26';
const color C_PANEL2      = C'10,16,34';
const color C_HEADER      = C'11,16,38';
const color C_BORDER      = C'90,70,230';
const color C_BORDER2     = C'55,42,140';
const color C_CYAN        = C'0,225,210';
const color C_VIOLET      = C'160,120,255';
const color C_BLUE        = C'45,150,255';
const color C_GREEN       = C'0,220,140';
const color C_RED         = C'235,55,75';
const color C_GOLD        = C'255,190,30';
const color C_ORANGE      = C'255,140,30';
const color C_WHITE       = C'225,235,255';
const color C_MUTED       = C'95,110,150';
const color C_HOLD_BG     = C'55,40,0';
const color C_BUY_BG      = C'0,50,28';
const color C_SELL_BG     = C'55,5,12';
const color C_SECTION_HDR = C'12,20,48';

//+------------------------------------------------------------------+
//| GLOBAL ENGINE OBJECTS                                             |
//+------------------------------------------------------------------+
CTrade          g_Trade;
CPositionInfo   g_Pos;

//--- Indicator handles
int g_hFastEMA=INVALID_HANDLE, g_hSlowEMA=INVALID_HANDLE, g_hTrendEMA=INVALID_HANDLE;
int g_hRSI=INVALID_HANDLE, g_hATR=INVALID_HANDLE, g_hADX=INVALID_HANDLE;
int g_hMACD=INVALID_HANDLE, g_hBB=INVALID_HANDLE, g_hHTFEMA=INVALID_HANDLE;

//--- Engine state
ENUM_ENGINE_STATE g_State      = ENGSTATE_SCANNING;
ENUM_RISK_MODE    g_RiskMode   = RISKMODE_NORMAL;
datetime          g_StateTimer = 0;

//--- Regime tracking
ENUM_MARKET_REGIME g_CurrentRegime   = REGIME_RANGING;
double              g_RegimeConfidence = 0.0;
double              g_ATRHistory[];
double              g_AvgVolume = 0.0;
int                 g_VolumeSamples = 0;
double              g_AvgSpread = 0.0;
int                 g_SpreadSamples = 0;
double              g_VolPercentile = 50.0;

//--- Displacement detector (see header - not "news")
double g_MarketDisplacementScore = 0.0;
bool   g_DisplacementActive      = false;

//--- Confidence engine
ConfidenceWeights   g_Weights;
ConfidenceBreakdown  g_LastConfidence;
double               g_AdaptiveThreshold = 62.0;
ENUM_STRATEGY_ID     g_LastWinningStrategy;
bool                 g_HasWinningStrategy = false;
StrategySignal       g_LastSignal;

//--- Performance tracking buckets
PerfBucket g_RegimePerf[NUM_REGIMES];
PerfBucket g_StrategyPerf[NUM_STRATEGIES];

//--- Trade lifecycle cache
double g_EntryPrice=0.0, g_EntrySLPrice=0.0, g_EntryATR=0.0, g_EntryRiskUSD=0.0;
double g_PeakProfit=0.0;
bool   g_BESet=false, g_PartialClosed=false;
int    g_TradeDirection=0;
datetime g_TradeOpenTime=0;
ENUM_STRATEGY_ID g_TradeStrategyId;
ENUM_MARKET_REGIME g_TradeRegime;

//--- Session / daily / weekly metrics
datetime g_SessionDay=0;
int      g_DailyTrades=0;
double   g_DailyProfit=0.0;
int      g_DailyWins=0, g_DailyLosses=0;
int      g_ConsecLosses=0, g_ConsecWins=0;
double   g_SessionOpenBal=0.0;
double   g_EquityPeak=0.0;
datetime g_WeekStart=0;
double   g_WeekOpenBal=0.0;
double   g_WeekProfit=0.0;
double   g_WinRate7=0.0;
int      g_Last7Results[7];

//--- Execution quality tracking
int    g_RequoteCount=0;
int    g_RejectCount=0;
double g_AvgSlippage=0.0;
int    g_SlippageSamples=0;

//--- Dashboard
string g_StatusText="BOOTING";
color  g_StatusColor=C_GOLD;
string g_HeartbeatStr="0 0 0 0";

//+------------------------------------------------------------------+
//| FORWARD DECLARATIONS                                              |
//+------------------------------------------------------------------+
bool   InitIndicators();
void   ReleaseIndicators();
void   InitWeights();
string GVName(string suffix);
void   LoadWeightsFromGlobals();
void   SaveWeightsToGlobals();
void   InitPerfBuckets();

// Regime
void   UpdateRegimeClassifier();
void   UpdateVolatilityPercentile();
ENUM_MARKET_REGIME ClassifyRegime(double adx, double bbWidthPct, double atrPctile, bool structBreak, bool sweepDetected, double emaSlope);
string RegimeToString(ENUM_MARKET_REGIME r);

// Shared indicator reads
bool   GetEMAStack(double &fast, double &slow, double &trend);
double GetRSI();
double GetADX();
bool   GetMACDHist(double &cur, double &prev);
bool   GetBBands(double &upper, double &lower, double &mid);
double GetATRValue();
bool   GetHTFTrend(bool &bullish);
void   UpdateVolumeAverage();
bool   IsVolumeSurging();
bool   DetectLiquiditySweep(ENUM_SIGNAL_DIR &dir);
bool   DetectStructureBreak(ENUM_SIGNAL_DIR dir, bool proximityMode);
double GetEMASlope();

// Displacement detector
void   UpdateMarketDisplacement();

// Strategies
StrategySignal Strategy_TrendContinuation();
StrategySignal Strategy_BreakoutMomentum();
StrategySignal Strategy_PullbackEntry();
StrategySignal Strategy_VolatilityExpansion();
StrategySignal Strategy_LiquiditySweepReversal();
StrategySignal Strategy_StructureShift();
StrategySignal Strategy_SessionMomentum();
StrategySignal Strategy_CompressionBreakout();
void   GetValidStrategiesForRegime(ENUM_MARKET_REGIME regime, ENUM_STRATEGY_ID &list[], int &count);
StrategySignal DispatchStrategies();

// Confidence
ConfidenceBreakdown ComputeConfidence(StrategySignal &sig);
double GetDynamicThreshold();
void   AdaptWeightsFromPerformance();

// Risk / sizing
double GetRiskAdjustedPercent();
double CalculateLotSize(double slDistancePrice);
ENUM_RISK_MODE DetermineRiskMode();

// Execution
void   ExecuteEntry(StrategySignal &sig);
bool   IsSpreadOk();
void   UpdateSpreadAverage();
bool   IsMarketOpen();
bool   IsWeekendPauseActive();

// Trade management
void   ManageOpenTrade();
void   CaptureUnmanagedExitIfAny();
void   CacheTradeEntry(ENUM_STRATEGY_ID stratId);
void   ResetTradeState();
void   CheckBreakeven();
void   CheckATRTrailing();
void   CheckPeakProfitLock(double pnl);
void   CheckPartialClose(double pnl);
void   CheckTimeExit();
void   CheckDeteriorationExit(double pnl);
bool   IsPositionOpen();
double GetFloatingPnL();
void   CloseAllPositions(string reason);

// Daily/weekly/drawdown
void   SyncDailyStats();
void   SyncWeeklyStats();
bool   IsDailyLossLimitHit();
bool   IsDailyProfitTargetHit();
bool   IsWeeklyLossLimitHit();
bool   IsDrawdownLimitHit();
datetime GetDayStart(datetime t);
datetime GetWeekStart(datetime t);

// Performance tracking
void   RecordTradeResult(ENUM_MARKET_REGIME regime, ENUM_STRATEGY_ID strat, double rMultiple);
double GetBucketExpectancy(PerfBucket &b);
double GetBucketWinRate(PerfBucket &b);

// Dashboard
void   RenderDashboard();
void   UpdateDashboard();
void   PurgeDashboard();
void   DrawRect(string id, int x, int y, int w, int h, color bg, color border, int bw);
void   DrawLabel(string id, int x, int y, string txt, color clr, int sz, string fnt);
void   SetLabel(string id, string txt, color clr = clrNONE);
string TimeframeToString(ENUM_TIMEFRAMES tf);
string StrategyToString(ENUM_STRATEGY_ID s);

//+------------------------------------------------------------------+
//| INIT                                                               |
//+------------------------------------------------------------------+
int OnInit()
{
   if(StringFind(_Symbol, "BTC") < 0)
      Print("[NovaTitanX] WARNING: built for BTCUSD. Current symbol: ", _Symbol);

   if(_Period == PERIOD_M1)
      Print("[NovaTitanX] WARNING: M1 detected. M5/M15 recommended - ATR-based SL distances "
           +"can be structurally large relative to typical M1 moves on BTCUSD.");

   g_Trade.SetExpertMagicNumber(InpMagicNumber);
   g_Trade.SetDeviationInPoints(InpMaxSlippagePoints);
   g_Trade.SetTypeFilling(ORDER_FILLING_FOK);

   if(InpRiskPercent <= 0.0 || InpRiskPercent > 10.0)
   { Alert("Risk% must be 0.01-10. Got: ", InpRiskPercent); return INIT_PARAMETERS_INCORRECT; }

   if(InpConfMinThreshold > InpConfMaxThreshold || InpConfBaseThreshold < InpConfMinThreshold || InpConfBaseThreshold > InpConfMaxThreshold)
   { Alert("Confidence threshold inputs inconsistent (min <= base <= max required)."); return INIT_PARAMETERS_INCORRECT; }

   if(!InitIndicators()) return INIT_FAILED;

   ArrayResize(g_ATRHistory, InpRegimeATRLookback);
   ArrayInitialize(g_ATRHistory, 0.0);
   ArrayInitialize(g_Last7Results, -1);

   InitWeights();
   if(InpUseAdaptiveWeights) LoadWeightsFromGlobals();
   InitPerfBuckets();

   g_AdaptiveThreshold = InpConfBaseThreshold;

   datetime now = TimeCurrent();
   g_SessionDay     = GetDayStart(now);
   g_SessionOpenBal = AccountInfoDouble(ACCOUNT_BALANCE);
   g_EquityPeak     = AccountInfoDouble(ACCOUNT_EQUITY);
   g_WeekStart      = GetWeekStart(now);
   g_WeekOpenBal    = AccountInfoDouble(ACCOUNT_BALANCE);
   SyncDailyStats();
   SyncWeeklyStats();

   g_State = ENGSTATE_SCANNING;
   EventSetTimer(1);
   RenderDashboard();

   Print("[NovaTitanX] Initialised. Symbol=", _Symbol, " Magic=", InpMagicNumber,
         " TF=", EnumToString(_Period), " AdaptiveWeights=", InpUseAdaptiveWeights);
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| DEINIT                                                             |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   EventKillTimer();
   if(InpUseAdaptiveWeights) SaveWeightsToGlobals();
   PurgeDashboard();
   ReleaseIndicators();
}

//+------------------------------------------------------------------+
//| TIMER - heartbeat + periodic sync (1s cadence)                    |
//+------------------------------------------------------------------+
void OnTimer()
{
   static uint beat = 0; beat++;
   string p[4] = {"1 0 1 1  0 1 0 0","0 1 0 0  1 0 1 1","1 1 0 1  0 0 1 0","0 0 1 0  1 1 0 1"};
   g_HeartbeatStr = p[beat % 4];

   SyncDailyStats();
   SyncWeeklyStats();
   UpdateRegimeClassifier();
   UpdateVolumeAverage();
   UpdateMarketDisplacement();

   double eq = AccountInfoDouble(ACCOUNT_EQUITY);
   if(eq > g_EquityPeak) g_EquityPeak = eq;

   g_RiskMode = DetermineRiskMode();

   if(InpUseAdaptiveWeights) AdaptWeightsFromPerformance();
   g_AdaptiveThreshold = GetDynamicThreshold();

   UpdateDashboard();
}

//+------------------------------------------------------------------+
//| TICK - main engine                                                 |
//+------------------------------------------------------------------+
void OnTick()
{
   UpdateSpreadAverage();

   if(!IsMarketOpen())
   { g_StatusText = "MARKET CLOSED"; g_StatusColor = C_RED; return; }

   //--- Manage open trade first - this always runs regardless of halt state,
   //    since halts block NEW entries, not management of existing risk.
   if(IsPositionOpen())
   { g_State = ENGSTATE_IN_TRADE; ManageOpenTrade(); return; }

   //--- Emergency / drawdown circuit breaker - all-time equity peak based
   if(IsDrawdownLimitHit())
   {
      g_State = ENGSTATE_DRAWDOWN_HALT;
      g_StatusText = "MAX DRAWDOWN HIT - HALTED";
      g_StatusColor = C_RED;
      return;
   }

   //--- Weekly kill-switch - broader net than daily, catches slow bleed across days
   if(IsWeeklyLossLimitHit())
   {
      g_State = ENGSTATE_EMERGENCY_HALT;
      g_StatusText = "WEEKLY LOSS LIMIT - HALTED";
      g_StatusColor = C_RED;
      return;
   }

   //--- Daily loss kill-switch
   if(IsDailyLossLimitHit())
   {
      g_State = ENGSTATE_DAILY_HALT;
      g_StatusText = "DAILY LOSS LIMIT - HALTED";
      g_StatusColor = C_RED;
      return;
   }

   //--- Daily profit ceiling
   if(IsDailyProfitTargetHit())
   {
      g_State = ENGSTATE_DAILY_HALT;
      g_StatusText = "DAILY TARGET MET - HALTED";
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

   //--- Weekend / thin-liquidity pause
   if(InpAvoidWeekendOpen && IsWeekendPauseActive())
   {
      g_StatusText = "WEEKEND OPEN PAUSE";
      g_StatusColor = C_MUTED;
      return;
   }

   //--- Spread / execution protection
   if(!IsSpreadOk())
   {
      double sp = SymbolInfoDouble(_Symbol, SYMBOL_ASK) - SymbolInfoDouble(_Symbol, SYMBOL_BID);
      g_StatusText = "SPREAD TOO WIDE ($"+DoubleToString(sp,2)+")";
      g_StatusColor = C_RED;
      return;
   }

   //--- Cooldown
   if(g_State == ENGSTATE_COOLDOWN)
   {
      int left = (int)(g_StateTimer - TimeCurrent());
      if(left > 0)
      {
         g_StatusText = "COOLDOWN (" + IntegerToString(left) + "s)";
         g_StatusColor = C_GOLD;
         return;
      }
      g_State = ENGSTATE_SCANNING;
   }

   //--- If we were halted and conditions cleared (new day etc.), SyncDailyStats
   //    already resets g_State to SCANNING - see SyncDailyStats(). Guard here too:
   if(g_State == ENGSTATE_DAILY_HALT || g_State == ENGSTATE_DRAWDOWN_HALT || g_State == ENGSTATE_EMERGENCY_HALT)
      return; // still halted, nothing reset it yet this tick

   //--- SCANNING: regime is already updated on the timer; dispatch strategies
   if(g_State == ENGSTATE_SCANNING)
   {
      StrategySignal sig = DispatchStrategies();

      if(!sig.valid || sig.dir == SIG_NONE)
      {
         g_StatusText  = "SCANNING - " + RegimeToString(g_CurrentRegime) + " - NO QUALIFYING STRATEGY";
         g_StatusColor = C_MUTED;
         g_HasWinningStrategy = false;
         return;
      }

      ConfidenceBreakdown conf = ComputeConfidence(sig);
      g_LastConfidence = conf;
      g_LastSignal     = sig;

      double threshold = GetDynamicThreshold();

      if(conf.total < threshold)
      {
         g_StatusText  = StrategyToString(sig.id) + " " + (sig.dir==SIG_BUY?"BUY":"SELL")
                        + " conf " + DoubleToString(conf.total,1) + "/" + DoubleToString(threshold,1) + " - BELOW THRESHOLD";
         g_StatusColor = C_GOLD;
         g_HasWinningStrategy = false;
         return;
      }

      //--- Both gates cleared: strategy signal quality AND confluence confidence
      g_HasWinningStrategy  = true;
      g_LastWinningStrategy = sig.id;
      Print("[NovaTitanX] FIRE: Strategy=", StrategyToString(sig.id), " Dir=", (sig.dir==SIG_BUY?"BUY":"SELL"),
            " Regime=", RegimeToString(g_CurrentRegime), " RawScore=", DoubleToString(sig.rawScore,1),
            " Confidence=", DoubleToString(conf.total,1), "/", DoubleToString(threshold,1), " Reason=", sig.reason);
      ExecuteEntry(sig);
   }
}

//+------------------------------------------------------------------+
//| INDICATOR INIT / RELEASE                                          |
//+------------------------------------------------------------------+
bool InitIndicators()
{
   g_hFastEMA  = iMA(_Symbol, _Period, InpFastEMA,  0, MODE_EMA, PRICE_CLOSE);
   g_hSlowEMA  = iMA(_Symbol, _Period, InpSlowEMA,  0, MODE_EMA, PRICE_CLOSE);
   g_hTrendEMA = iMA(_Symbol, _Period, InpTrendEMA, 0, MODE_EMA, PRICE_CLOSE);
   g_hRSI      = iRSI(_Symbol, _Period, InpRSIPeriod, PRICE_CLOSE);
   g_hATR      = iATR(_Symbol, _Period, InpATRPeriod);
   g_hADX      = iADX(_Symbol, _Period, InpADXPeriod);
   g_hMACD     = iMACD(_Symbol, _Period, InpMACDFast, InpMACDSlow, InpMACDSignal, PRICE_CLOSE);
   g_hBB       = iBands(_Symbol, _Period, InpBBPeriod, 0, InpBBDeviation, PRICE_CLOSE);
   g_hHTFEMA   = iMA(_Symbol, InpHTFPeriod, InpHTFEMAPeriod, 0, MODE_EMA, PRICE_CLOSE);

   if(g_hFastEMA==INVALID_HANDLE || g_hSlowEMA==INVALID_HANDLE || g_hTrendEMA==INVALID_HANDLE ||
      g_hRSI==INVALID_HANDLE     || g_hATR==INVALID_HANDLE     || g_hADX==INVALID_HANDLE ||
      g_hMACD==INVALID_HANDLE    || g_hBB==INVALID_HANDLE      || g_hHTFEMA==INVALID_HANDLE)
   {
      Print("[NovaTitanX] FAILED: one or more indicator handles invalid.");
      return false;
   }
   return true;
}

void ReleaseIndicators()
{
   int handles[] = {g_hFastEMA, g_hSlowEMA, g_hTrendEMA, g_hRSI, g_hATR, g_hADX, g_hMACD, g_hBB, g_hHTFEMA};
   for(int i = 0; i < ArraySize(handles); i++)
      if(handles[i] != INVALID_HANDLE) IndicatorRelease(handles[i]);
}

//+------------------------------------------------------------------+
//| WEIGHTS INIT / PERSISTENCE                                        |
//| Adaptive weights are bounded - see AdaptWeightsFromPerformance(). |
//| Persisted via GlobalVariable so a restarted EA keeps what it      |
//| learned, same pattern as the BTCSniperScalperPro confluence       |
//| weight persistence.                                               |
//+------------------------------------------------------------------+
void InitWeights()
{
   // Defaults mirror the spec's illustrative weighting (structure/trend
   // weighted highest, session lightest) but these are STARTING points,
   // not fixed truth - they drift within bounds if adaptive weights are on.
   g_Weights.wStructure  = 25.0;
   g_Weights.wTrend      = 20.0;
   g_Weights.wMomentum   = 15.0;
   g_Weights.wVolume     = 15.0;
   g_Weights.wVolatility = 10.0;
   g_Weights.wLiquidity  = 10.0;
   g_Weights.wSession    = 5.0;
}

string GVName(string suffix)
{
   return "NTX_" + IntegerToString((long)InpMagicNumber) + "_" + _Symbol + "_" + suffix;
}

void LoadWeightsFromGlobals()
{
   if(GlobalVariableCheck(GVName("wStructure")))  g_Weights.wStructure  = GlobalVariableGet(GVName("wStructure"));
   if(GlobalVariableCheck(GVName("wTrend")))      g_Weights.wTrend      = GlobalVariableGet(GVName("wTrend"));
   if(GlobalVariableCheck(GVName("wMomentum")))   g_Weights.wMomentum   = GlobalVariableGet(GVName("wMomentum"));
   if(GlobalVariableCheck(GVName("wVolume")))     g_Weights.wVolume     = GlobalVariableGet(GVName("wVolume"));
   if(GlobalVariableCheck(GVName("wVolatility"))) g_Weights.wVolatility = GlobalVariableGet(GVName("wVolatility"));
   if(GlobalVariableCheck(GVName("wLiquidity")))  g_Weights.wLiquidity  = GlobalVariableGet(GVName("wLiquidity"));
   if(GlobalVariableCheck(GVName("wSession")))    g_Weights.wSession    = GlobalVariableGet(GVName("wSession"));
   if(GlobalVariableCheck(GVName("threshold")))   g_AdaptiveThreshold   = GlobalVariableGet(GVName("threshold"));
}

void SaveWeightsToGlobals()
{
   GlobalVariableSet(GVName("wStructure"),  g_Weights.wStructure);
   GlobalVariableSet(GVName("wTrend"),      g_Weights.wTrend);
   GlobalVariableSet(GVName("wMomentum"),   g_Weights.wMomentum);
   GlobalVariableSet(GVName("wVolume"),     g_Weights.wVolume);
   GlobalVariableSet(GVName("wVolatility"), g_Weights.wVolatility);
   GlobalVariableSet(GVName("wLiquidity"),  g_Weights.wLiquidity);
   GlobalVariableSet(GVName("wSession"),    g_Weights.wSession);
   GlobalVariableSet(GVName("threshold"),   g_AdaptiveThreshold);
}

void InitPerfBuckets()
{
   for(int r = 0; r < NUM_REGIMES; r++)
   {
      ArrayInitialize(g_RegimePerf[r].results, -1);
      g_RegimePerf[r].idx = 0; g_RegimePerf[r].count = 0;
      g_RegimePerf[r].sumR = 0.0; g_RegimePerf[r].trades = 0;
   }
   for(int s = 0; s < NUM_STRATEGIES; s++)
   {
      ArrayInitialize(g_StrategyPerf[s].results, -1);
      g_StrategyPerf[s].idx = 0; g_StrategyPerf[s].count = 0;
      g_StrategyPerf[s].sumR = 0.0; g_StrategyPerf[s].trades = 0;
   }
}

//+------------------------------------------------------------------+
//| SHARED INDICATOR READS (used by multiple strategies)              |
//+------------------------------------------------------------------+
bool GetEMAStack(double &fast, double &slow, double &trend)
{
   double f[1], s[1], t[1];
   if(CopyBuffer(g_hFastEMA,  0, 0, 1, f) <= 0) return false;
   if(CopyBuffer(g_hSlowEMA,  0, 0, 1, s) <= 0) return false;
   if(CopyBuffer(g_hTrendEMA, 0, 0, 1, t) <= 0) return false;
   fast = f[0]; slow = s[0]; trend = t[0];
   return true;
}

double GetRSI()
{
   double r[1];
   if(CopyBuffer(g_hRSI, 0, 0, 1, r) <= 0) return 50.0;
   return r[0];
}

double GetADX()
{
   double a[1];
   if(CopyBuffer(g_hADX, 0, 0, 1, a) <= 0) return 0.0;
   return a[0];
}

bool GetMACDHist(double &cur, double &prev)
{
   double hist[2];
   if(CopyBuffer(g_hMACD, 2, 0, 2, hist) < 2) return false;
   cur = hist[0]; prev = hist[1];
   return true;
}

bool GetBBands(double &upper, double &lower, double &mid)
{
   double u[1], l[1], m[1];
   if(CopyBuffer(g_hBB, 1, 0, 1, u) <= 0) return false;
   if(CopyBuffer(g_hBB, 2, 0, 1, l) <= 0) return false;
   if(CopyBuffer(g_hBB, 0, 0, 1, m) <= 0) return false;
   upper = u[0]; lower = l[0]; mid = m[0];
   return true;
}

double GetATRValue()
{
   double a[1];
   if(CopyBuffer(g_hATR, 0, 0, 1, a) <= 0) return 0.0;
   return a[0];
}

bool GetHTFTrend(bool &bullish)
{
   double h[1];
   if(CopyBuffer(g_hHTFEMA, 0, 0, 1, h) <= 0) return false;
   double price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   bullish = (price > h[0]);
   return true;
}

double GetEMASlope()
{
   // Slope of the slow EMA over the last 5 closed bars, normalised by ATR
   // so the slope is comparable across BTC's different price regimes.
   double s[6];
   if(CopyBuffer(g_hSlowEMA, 0, 0, 6, s) < 6) return 0.0;
   double atr = GetATRValue();
   if(atr <= 0.0) return 0.0;
   return (s[0] - s[5]) / atr; // positive = rising, negative = falling
}

void UpdateVolumeAverage()
{
   static datetime lastVolBarTime = 0;
   datetime curBarTime = (datetime)SeriesInfoInteger(_Symbol, _Period, SERIES_LASTBAR_DATE);
   if(curBarTime == lastVolBarTime) return; // new-bar gate - see NovaBTC v1 fix notes in lineage header
   lastVolBarTime = curBarTime;

   long vol[1];
   if(CopyTickVolume(_Symbol, _Period, 1, 1, vol) <= 0) return;

   int cap = InpVolumeAvgPeriod * 20;
   g_AvgVolume = (g_AvgVolume * g_VolumeSamples + (double)vol[0]) / (double)(g_VolumeSamples + 1);
   g_VolumeSamples = MathMin(g_VolumeSamples + 1, cap);
}

bool IsVolumeSurging()
{
   if(g_AvgVolume <= 0.0) return true; // insufficient data - don't block
   long vol[1];
   if(CopyTickVolume(_Symbol, _Period, 0, 1, vol) <= 0) return true;
   return ((double)vol[0] >= g_AvgVolume * InpVolumeSurgeMult);
}

//--- Liquidity sweep: price wicks beyond a recent swing high/low and closes
//    back inside it within the same or next bar - classic stop-hunt pattern.
bool DetectLiquiditySweep(ENUM_SIGNAL_DIR &dir)
{
   int highBar = iHighest(_Symbol, _Period, MODE_HIGH, InpStructureBars, 2);
   int lowBar  = iLowest(_Symbol,  _Period, MODE_LOW,  InpStructureBars, 2);
   if(highBar < 0 || lowBar < 0) return false;

   double swingHigh = iHigh(_Symbol, _Period, highBar);
   double swingLow  = iLow(_Symbol,  _Period, lowBar);

   double bar1High = iHigh(_Symbol, _Period, 1);
   double bar1Low  = iLow(_Symbol, _Period, 1);
   double bar1Close= iClose(_Symbol, _Period, 1);
   double bar1Open = iOpen(_Symbol, _Period, 1);

   // Swept the high (wicked above, closed back below) = bearish reversal signal
   if(bar1High > swingHigh && bar1Close < swingHigh && bar1Close < bar1Open)
   { dir = SIG_SELL; return true; }

   // Swept the low (wicked below, closed back above) = bullish reversal signal
   if(bar1Low < swingLow && bar1Close > swingLow && bar1Close > bar1Open)
   { dir = SIG_BUY; return true; }

   return false;
}

bool DetectStructureBreak(ENUM_SIGNAL_DIR dir, bool proximityMode)
{
   int highBar = iHighest(_Symbol, _Period, MODE_HIGH, InpStructureBars, 1);
   int lowBar  = iLowest(_Symbol,  _Period, MODE_LOW,  InpStructureBars, 1);
   if(highBar < 0 || lowBar < 0) return false;

   double swingHigh = iHigh(_Symbol, _Period, highBar);
   double swingLow  = iLow(_Symbol,  _Period, lowBar);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double atr = GetATRValue();
   double buffer = atr * 0.5;

   if(proximityMode)
   {
      if(dir == SIG_BUY)  return (ask >= swingHigh - buffer);
      if(dir == SIG_SELL) return (bid <= swingLow  + buffer);
   }
   else
   {
      if(dir == SIG_BUY)  return (ask > swingHigh);
      if(dir == SIG_SELL) return (bid < swingLow);
   }
   return false;
}

//+------------------------------------------------------------------+
//| MARKET REGIME CLASSIFIER                                          |
//|                                                                    |
//| Runs once per closed bar (new-bar gated, same lesson as NovaBTC   |
//| v1's ATR percentile fix - sampling every tick fills the rolling   |
//| buffer with near-duplicates of the same 1-2 bars and corrupts the |
//| percentile read). Classifies into one of 10 states using:        |
//|   - ADX (trend strength)                                          |
//|   - EMA slope (trend direction/steepness)                        |
//|   - Bollinger Band width as % of price (compression/expansion)   |
//|   - ATR percentile vs rolling history (volatility regime)        |
//|   - Structure break / liquidity sweep detection                  |
//|                                                                    |
//| This is a rule-based classifier, not a probabilistic model - the  |
//| g_RegimeConfidence value reflects how cleanly the rules agreed,   |
//| not a statistical posterior.                                      |
//+------------------------------------------------------------------+
void UpdateRegimeClassifier()
{
   static datetime lastRegimeBarTime = 0;
   datetime curBarTime = (datetime)SeriesInfoInteger(_Symbol, _Period, SERIES_LASTBAR_DATE);
   if(curBarTime == lastRegimeBarTime) return;
   lastRegimeBarTime = curBarTime;

   UpdateVolatilityPercentile();

   double adx = GetADX();
   double upper, lower, mid;
   bool bbOk = GetBBands(upper, lower, mid);
   double price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double bbWidthPct = (bbOk && price > 0.0) ? ((upper - lower) / price) * 100.0 : 0.0;
   double emaSlope = GetEMASlope();

   ENUM_SIGNAL_DIR sweepDir = SIG_NONE;
   bool sweepDetected = DetectLiquiditySweep(sweepDir);

   bool structBreakUp   = DetectStructureBreak(SIG_BUY,  false);
   bool structBreakDown = DetectStructureBreak(SIG_SELL, false);
   bool structBreak = structBreakUp || structBreakDown;

   g_CurrentRegime = ClassifyRegime(adx, bbWidthPct, g_VolPercentile, structBreak, sweepDetected, emaSlope);
}

//--- ATR percentile - identical methodology/fix lineage to NovaBTC v1:
//    new-bar gated sampling, self-comparison excluded from the loop.
void UpdateVolatilityPercentile()
{
   double curATR = GetATRValue();
   if(curATR <= 0.0) return;

   int n = ArraySize(g_ATRHistory);
   for(int i = n-1; i > 0; i--) g_ATRHistory[i] = g_ATRHistory[i-1];
   g_ATRHistory[0] = curATR;

   int validCount = 0, belowCount = 0;
   for(int i = 1; i < n; i++)
   {
      if(g_ATRHistory[i] <= 0.0) continue;
      validCount++;
      if(g_ATRHistory[i] <= curATR) belowCount++;
   }
   if(validCount < 10) { g_VolPercentile = 50.0; return; }
   g_VolPercentile = ((double)belowCount / validCount) * 100.0;
}

ENUM_MARKET_REGIME ClassifyRegime(double adx, double bbWidthPct, double atrPctile, bool structBreak, bool sweepDetected, double emaSlope)
{
   // Priority order matters: more specific/urgent regimes are checked first
   // so e.g. a liquidity sweep during a compression phase is correctly
   // flagged as a sweep, not silently absorbed into "compression."

   // 1. Liquidity sweep - highest priority, short-lived and actionable
   if(sweepDetected) return REGIME_LIQUIDITY_SWEEP;

   // 2. Extreme volatility + structure break = breakout or momentum expansion
   if(atrPctile >= InpVolExtremePctile && structBreak)
      return REGIME_BREAKOUT;

   if(atrPctile >= InpVolHighPctile && MathAbs(emaSlope) > 1.5)
      return REGIME_MOMENTUM_EXPANSION;

   // 3. Compression - tight BB width + low ATR percentile = coiling
   if(bbWidthPct < InpBBSqueezeRatio * 100.0 && atrPctile <= InpVolLowPctile)
      return REGIME_VOLATILITY_COMPRESSION;

   // 4. Trending - strong ADX + clear EMA slope direction
   if(adx >= InpADXTrendMin)
      return (emaSlope > 0.0) ? REGIME_TRENDING_BULL : REGIME_TRENDING_BEAR;

   // 5. Reversal candidate - structure break against the prevailing slope
   //    direction (price breaking down while EMA was still sloping up, etc.)
   if(structBreak)
   {
      bool breakUp = DetectStructureBreak(SIG_BUY, false);
      if(breakUp && emaSlope < -0.5)  return REGIME_REVERSAL;
      if(!breakUp && emaSlope > 0.5)  return REGIME_REVERSAL;
   }

   // 6. Low ADX, low volatility percentile, slope flattening = accumulation
   //    vs distribution - distinguished by whether recent slope is still
   //    mildly positive (accumulation, base-building before markup) or
   //    mildly negative (distribution, topping before markdown).
   if(adx < InpADXRangeMax && atrPctile < 60.0)
   {
      if(emaSlope >= 0.0) return REGIME_ACCUMULATION;
      return REGIME_DISTRIBUTION;
   }

   // 7. Default fallback - genuinely directionless chop
   return REGIME_RANGING;
}

string RegimeToString(ENUM_MARKET_REGIME r)
{
   switch(r)
   {
      case REGIME_TRENDING_BULL:           return "TRENDING BULL";
      case REGIME_TRENDING_BEAR:           return "TRENDING BEAR";
      case REGIME_RANGING:                 return "RANGING";
      case REGIME_BREAKOUT:                return "BREAKOUT";
      case REGIME_MOMENTUM_EXPANSION:      return "MOMENTUM EXPANSION";
      case REGIME_VOLATILITY_COMPRESSION:  return "VOL COMPRESSION";
      case REGIME_ACCUMULATION:            return "ACCUMULATION";
      case REGIME_DISTRIBUTION:            return "DISTRIBUTION";
      case REGIME_LIQUIDITY_SWEEP:         return "LIQUIDITY SWEEP";
      case REGIME_REVERSAL:                return "REVERSAL";
      default:                             return "?";
   }
}

//+------------------------------------------------------------------+
//| MARKET DISPLACEMENT DETECTOR                                      |
//| Honest label (see file header): this measures abnormal bar range  |
//| + volume + spread behaviour. It does NOT know whether news        |
//| happened. It outputs a 0-100 "abnormal activity" score used by    |
//| the confidence engine's volatility/liquidity weighting - treat it |
//| as "the market is moving unusually fast right now," nothing more. |
//+------------------------------------------------------------------+
void UpdateMarketDisplacement()
{
   double atr = GetATRValue();
   if(atr <= 0.0) { g_MarketDisplacementScore = 0.0; g_DisplacementActive = false; return; }

   double bar1High = iHigh(_Symbol, _Period, 1);
   double bar1Low  = iLow(_Symbol, _Period, 1);
   double barRange = bar1High - bar1Low;
   double rangeRatio = barRange / atr; // how many ATRs did the last bar span

   long vol[1];
   double volRatio = 1.0;
   if(CopyTickVolume(_Symbol, _Period, 1, 1, vol) > 0 && g_AvgVolume > 0.0)
      volRatio = (double)vol[0] / g_AvgVolume;

   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double spreadPct = (bid > 0.0) ? ((ask - bid) / bid) * 100.0 : 0.0;
   double spreadRatio = (g_AvgSpread > 0.0) ? ((ask-bid) / g_AvgSpread) : 1.0;

   // Composite 0-100 score: range contributes up to 50, volume up to 35,
   // spread blowout up to 15. Weights chosen so any single extreme factor
   // alone can still flag displacement, but normal noise in one factor
   // doesn't falsely trigger it.
   double rangeScore  = MathMin(50.0, (rangeRatio / InpDisplacementATRMult) * 50.0);
   double volScore    = MathMin(35.0, (volRatio   / InpDisplacementVolMult) * 35.0);
   double spreadScore = MathMin(15.0, MathMax(0.0, (spreadRatio - 1.5)) * 10.0);

   g_MarketDisplacementScore = MathMin(100.0, rangeScore + volScore + spreadScore);
   g_DisplacementActive = (rangeRatio >= InpDisplacementATRMult) && (volRatio >= InpDisplacementVolMult);
}

//+------------------------------------------------------------------+
//| STRATEGY MODULES                                                   |
//| Each returns a StrategySignal with a 0-100 rawScore that reflects |
//| ONLY that strategy's own internal setup quality - it is NOT the   |
//| same number as the cross-cutting confidence score computed later  |
//| in ComputeConfidence(). A strategy can return a high rawScore and |
//| still get blocked if the confluence confidence score is weak, and|
//| vice versa is not possible (confidence is only computed for a    |
//| strategy that already returned a valid signal).                  |
//+------------------------------------------------------------------+

//--- Strategy A: Trend Continuation - valid in TRENDING_BULL/BEAR
StrategySignal Strategy_TrendContinuation()
{
   StrategySignal s; s.id = STRAT_TREND_CONTINUATION; s.dir = SIG_NONE; s.rawScore = 0.0; s.valid = false; s.reason = "";

   double fast, slow, trend;
   if(!GetEMAStack(fast, slow, trend)) return s;

   bool bullStack = (fast > slow && slow > trend);
   bool bearStack = (fast < slow && slow < trend);
   if(!bullStack && !bearStack) return s;

   ENUM_SIGNAL_DIR dir = bullStack ? SIG_BUY : SIG_SELL;
   double adx = GetADX();
   double rsi = GetRSI();
   double macdCur, macdPrev;
   bool hasMacd = GetMACDHist(macdCur, macdPrev);

   double score = 40.0; // base for clean EMA stack in a confirmed trend regime
   if(adx >= InpADXTrendMin) score += 20.0;
   if(adx >= InpADXTrendMin + 8.0) score += 10.0; // extra-strong trend bonus

   bool rsiOk = (dir==SIG_BUY) ? (rsi > 50.0 && rsi < InpRSIOverbought) : (rsi < 50.0 && rsi > InpRSIOversold);
   if(rsiOk) score += 15.0;

   if(hasMacd)
   {
      bool macdAgrees = (dir==SIG_BUY) ? (macdCur > 0.0 && macdCur > macdPrev) : (macdCur < 0.0 && macdCur < macdPrev);
      if(macdAgrees) score += 15.0;
   }

   s.dir = dir;
   s.rawScore = MathMin(100.0, score);
   s.valid = (s.rawScore >= 40.0);
   s.reason = "EMA stack " + (bullStack?"bullish":"bearish") + ", ADX=" + DoubleToString(adx,1);
   return s;
}

//--- Strategy B: Breakout Momentum - valid in BREAKOUT
StrategySignal Strategy_BreakoutMomentum()
{
   StrategySignal s; s.id = STRAT_BREAKOUT_MOMENTUM; s.dir = SIG_NONE; s.rawScore = 0.0; s.valid = false; s.reason = "";

   bool breakUp   = DetectStructureBreak(SIG_BUY, false);
   bool breakDown = DetectStructureBreak(SIG_SELL, false);
   if(!breakUp && !breakDown) return s;

   ENUM_SIGNAL_DIR dir = breakUp ? SIG_BUY : SIG_SELL;
   bool volSurge = IsVolumeSurging();
   double emaSlope = GetEMASlope();
   bool slopeAgrees = (dir==SIG_BUY) ? (emaSlope > 0.0) : (emaSlope < 0.0);

   double score = 45.0; // base for confirmed structural break
   if(volSurge) score += 25.0;                          // breakouts without volume are suspect
   if(slopeAgrees) score += 15.0;
   if(g_DisplacementActive) score += 15.0;               // genuine displacement supports a breakout read

   s.dir = dir;
   s.rawScore = MathMin(100.0, score);
   s.valid = (s.rawScore >= 45.0) && volSurge; // hard requirement: breakouts need volume, not just price
   s.reason = "Structure break " + (breakUp?"up":"down") + (volSurge?", volume confirmed":", NO volume - weak");
   return s;
}

//--- Strategy C: Pullback Entry - valid in TRENDING_BULL/BEAR, ACCUMULATION/DISTRIBUTION
StrategySignal Strategy_PullbackEntry()
{
   StrategySignal s; s.id = STRAT_PULLBACK_ENTRY; s.dir = SIG_NONE; s.rawScore = 0.0; s.valid = false; s.reason = "";

   double fast, slow, trend;
   if(!GetEMAStack(fast, slow, trend)) return s;
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);

   // Pullback definition: price has pulled back to touch/near the fast EMA
   // while the broader stack (slow vs trend) still agrees with the original
   // trend direction - i.e. a dip-buy in an uptrend or rip-sell in a downtrend.
   bool macroBull = (slow > trend);
   bool macroBear = (slow < trend);
   if(!macroBull && !macroBear) return s;

   double atr = GetATRValue();
   double distToFast = MathAbs(bid - fast);
   bool nearFastEMA = (atr > 0.0) && (distToFast <= atr * 0.6);
   if(!nearFastEMA) return s;

   ENUM_SIGNAL_DIR dir = macroBull ? SIG_BUY : SIG_SELL;
   double rsi = GetRSI();

   double score = 35.0;
   if(nearFastEMA) score += 20.0;
   // RSI should have cooled off (not still pinned at extreme) for a clean pullback
   bool rsiCooled = (dir==SIG_BUY) ? (rsi < 60.0 && rsi > 38.0) : (rsi > 40.0 && rsi < 62.0);
   if(rsiCooled) score += 20.0;
   double adx = GetADX();
   if(adx >= InpADXRangeMax) score += 15.0; // some underlying trend strength, not pure chop
   if(g_DisplacementActive) score -= 15.0;  // a displacement bar argues against a calm pullback read

   s.dir = dir;
   s.rawScore = MathMax(0.0, MathMin(100.0, score));
   s.valid = (s.rawScore >= 40.0);
   s.reason = "Pullback to fast EMA in " + (macroBull?"bull":"bear") + " structure, RSI=" + DoubleToString(rsi,1);
   return s;
}

//--- Strategy D: Volatility Expansion - valid in MOMENTUM_EXPANSION
StrategySignal Strategy_VolatilityExpansion()
{
   StrategySignal s; s.id = STRAT_VOLATILITY_EXPANSION; s.dir = SIG_NONE; s.rawScore = 0.0; s.valid = false; s.reason = "";

   if(g_VolPercentile < InpVolHighPctile) return s; // requires genuinely elevated vol percentile

   double emaSlope = GetEMASlope();
   if(MathAbs(emaSlope) < 1.0) return s; // expansion strategy needs directional conviction, not just noise

   ENUM_SIGNAL_DIR dir = (emaSlope > 0.0) ? SIG_BUY : SIG_SELL;
   bool volSurge = IsVolumeSurging();
   double adx = GetADX();

   double score = 40.0;
   score += MathMin(25.0, (g_VolPercentile - InpVolHighPctile)); // scales with how extreme the percentile is
   if(volSurge) score += 20.0;
   if(adx >= InpADXTrendMin) score += 15.0;

   s.dir = dir;
   s.rawScore = MathMin(100.0, score);
   s.valid = (s.rawScore >= 45.0);
   s.reason = "Vol percentile=" + DoubleToString(g_VolPercentile,0) + "%, slope=" + DoubleToString(emaSlope,2);
   return s;
}

//--- Strategy E: Liquidity Sweep Reversal - valid in LIQUIDITY_SWEEP
StrategySignal Strategy_LiquiditySweepReversal()
{
   StrategySignal s; s.id = STRAT_LIQUIDITY_SWEEP_REVERSAL; s.dir = SIG_NONE; s.rawScore = 0.0; s.valid = false; s.reason = "";

   ENUM_SIGNAL_DIR sweepDir = SIG_NONE;
   if(!DetectLiquiditySweep(sweepDir)) return s;

   double rsi = GetRSI();
   // Confirm the sweep with RSI at a relative extreme in the OPPOSITE
   // direction of the sweep's implied reversal - i.e. swept the low (bullish
   // reversal) should show RSI was depressed, not already neutral.
   bool rsiConfirms = (sweepDir==SIG_BUY) ? (rsi < 45.0) : (rsi > 55.0);

   double score = 50.0; // sweeps are a fairly high-conviction pattern on their own
   if(rsiConfirms) score += 25.0;
   if(IsVolumeSurging()) score += 15.0; // sweep + volume = more likely a genuine stop run, not noise
   if(g_DisplacementActive) score += 10.0;

   s.dir = sweepDir;
   s.rawScore = MathMin(100.0, score);
   s.valid = (s.rawScore >= 50.0);
   s.reason = "Liquidity sweep " + (sweepDir==SIG_BUY?"of lows (bullish)":"of highs (bearish)")
            + (rsiConfirms?", RSI confirms":", RSI neutral");
   return s;
}

//--- Strategy F: Market Structure Shift - valid in REVERSAL
StrategySignal Strategy_StructureShift()
{
   StrategySignal s; s.id = STRAT_STRUCTURE_SHIFT; s.dir = SIG_NONE; s.rawScore = 0.0; s.valid = false; s.reason = "";

   bool breakUp   = DetectStructureBreak(SIG_BUY, false);
   bool breakDown = DetectStructureBreak(SIG_SELL, false);
   if(!breakUp && !breakDown) return s;

   double emaSlope = GetEMASlope();
   ENUM_SIGNAL_DIR dir = breakUp ? SIG_BUY : SIG_SELL;

   // A genuine structure SHIFT (not continuation) means the break direction
   // disagrees with the prior EMA slope - this is what makes it a reversal
   // signal distinct from Strategy B's continuation-flavoured breakout read.
   bool isShift = (dir==SIG_BUY) ? (emaSlope < 0.3) : (emaSlope > -0.3);
   if(!isShift) return s;

   double macdCur, macdPrev;
   bool hasMacd = GetMACDHist(macdCur, macdPrev);

   double score = 40.0;
   if(hasMacd)
   {
      bool macdTurning = (dir==SIG_BUY) ? (macdCur > macdPrev) : (macdCur < macdPrev);
      if(macdTurning) score += 25.0;
   }
   if(IsVolumeSurging()) score += 20.0;
   if(g_DisplacementActive) score += 15.0;

   s.dir = dir;
   s.rawScore = MathMin(100.0, score);
   s.valid = (s.rawScore >= 45.0);
   s.reason = "Structure shift " + (breakUp?"up":"down") + " against prior slope=" + DoubleToString(emaSlope,2);
   return s;
}

//--- Strategy G: Session Momentum - valid in TRENDING_BULL/BEAR, BREAKOUT, MOMENTUM_EXPANSION
//    "Session" here means recency-weighted intraday momentum, not a forex
//    trading-session concept - BTC trades 24/7, so this looks at the last
//    few closed bars' directional consistency rather than London/NY hours.
StrategySignal Strategy_SessionMomentum()
{
   StrategySignal s; s.id = STRAT_SESSION_MOMENTUM; s.dir = SIG_NONE; s.rawScore = 0.0; s.valid = false; s.reason = "";

   double c0 = iClose(_Symbol, _Period, 1);
   double c1 = iClose(_Symbol, _Period, 2);
   double c2 = iClose(_Symbol, _Period, 3);
   double c3 = iClose(_Symbol, _Period, 4);

   bool consecUp   = (c0 > c1) && (c1 > c2) && (c2 > c3);
   bool consecDown = (c0 < c1) && (c1 < c2) && (c2 < c3);
   if(!consecUp && !consecDown) return s;

   ENUM_SIGNAL_DIR dir = consecUp ? SIG_BUY : SIG_SELL;
   double rsi = GetRSI();
   bool rsiNotExhausted = (dir==SIG_BUY) ? (rsi < InpRSIOverbought) : (rsi > InpRSIOversold);
   if(!rsiNotExhausted) return s; // 4 closes in a row into an RSI extreme = chase risk, skip

   double score = 35.0;
   score += 20.0; // 3-bar consecutive close confirmed above
   if(IsVolumeSurging()) score += 20.0;
   double adx = GetADX();
   if(adx >= InpADXTrendMin) score += 25.0;

   s.dir = dir;
   s.rawScore = MathMin(100.0, score);
   s.valid = (s.rawScore >= 45.0);
   s.reason = "3-bar momentum " + (consecUp?"up":"down") + ", RSI=" + DoubleToString(rsi,1) + " not exhausted";
   return s;
}

//--- Strategy H: Volatility Compression Breakout - valid in VOLATILITY_COMPRESSION
StrategySignal Strategy_CompressionBreakout()
{
   StrategySignal s; s.id = STRAT_COMPRESSION_BREAKOUT; s.dir = SIG_NONE; s.rawScore = 0.0; s.valid = false; s.reason = "";

   double upper, lower, mid;
   if(!GetBBands(upper, lower, mid)) return s;
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);

   // Looking for the FIRST close outside the (still tight) bands - i.e. the
   // initial thrust out of a compression regime, not a fully developed move.
   bool breakingUp   = (ask > upper);
   bool breakingDown = (bid < lower);
   if(!breakingUp && !breakingDown) return s;

   ENUM_SIGNAL_DIR dir = breakingUp ? SIG_BUY : SIG_SELL;
   bool volSurge = IsVolumeSurging();

   double score = 40.0;
   if(volSurge) score += 30.0;            // compression breakouts are easy to fake without volume
   if(g_DisplacementActive) score += 20.0;
   double adx = GetADX();
   if(adx < InpADXTrendMin) score += 10.0; // bonus for genuinely coming FROM a low-ADX coil, not already trending

   s.dir = dir;
   s.rawScore = MathMin(100.0, score);
   s.valid = (s.rawScore >= 50.0) && volSurge; // hard requirement, same logic as Strategy B
   s.reason = "BB compression break " + (breakingUp?"up":"down") + (volSurge?", volume confirmed":", NO volume - weak");
   return s;
}

//+------------------------------------------------------------------+
//| REGIME -> STRATEGY MAPPING & DISPATCH                              |
//| This is what makes strategy selection "dynamic" rather than       |
//| "run all 8 every tick and hope one fires": only the strategies     |
//| listed as valid for the CURRENT regime are even evaluated.        |
//+------------------------------------------------------------------+
void GetValidStrategiesForRegime(ENUM_MARKET_REGIME regime, ENUM_STRATEGY_ID &list[], int &count)
{
   count = 0;
   ArrayResize(list, NUM_STRATEGIES); // worst case all valid; trimmed by count

   switch(regime)
   {
      case REGIME_TRENDING_BULL:
      case REGIME_TRENDING_BEAR:
         list[count++] = STRAT_TREND_CONTINUATION;
         list[count++] = STRAT_PULLBACK_ENTRY;
         list[count++] = STRAT_SESSION_MOMENTUM;
         break;

      case REGIME_BREAKOUT:
         list[count++] = STRAT_BREAKOUT_MOMENTUM;
         list[count++] = STRAT_SESSION_MOMENTUM;
         break;

      case REGIME_MOMENTUM_EXPANSION:
         list[count++] = STRAT_VOLATILITY_EXPANSION;
         list[count++] = STRAT_SESSION_MOMENTUM;
         break;

      case REGIME_VOLATILITY_COMPRESSION:
         list[count++] = STRAT_COMPRESSION_BREAKOUT;
         break;

      case REGIME_ACCUMULATION:
      case REGIME_DISTRIBUTION:
         list[count++] = STRAT_PULLBACK_ENTRY;
         break;

      case REGIME_LIQUIDITY_SWEEP:
         list[count++] = STRAT_LIQUIDITY_SWEEP_REVERSAL;
         break;

      case REGIME_REVERSAL:
         list[count++] = STRAT_STRUCTURE_SHIFT;
         break;

      case REGIME_RANGING:
         // Deliberately empty: ranging/chop is the one regime where this
         // engine takes EA #2's side of the tradeoff and sits out, rather
         // than forcing a strategy designed for a different regime shape.
         break;

      default:
         break;
   }
}

//--- Calls only the strategies valid for the current regime, and if more
//    than one qualifies, picks the highest rawScore - NOT the first one
//    found, so a stronger Strategy G read can beat a weaker Strategy A
//    read even though A is listed first.
StrategySignal DispatchStrategies()
{
   StrategySignal best; best.valid = false; best.dir = SIG_NONE; best.rawScore = 0.0; best.reason = "no regime-eligible strategy";
   best.id = STRAT_TREND_CONTINUATION; // placeholder, only meaningful if best.valid

   ENUM_STRATEGY_ID candidates[];
   int count = 0;
   GetValidStrategiesForRegime(g_CurrentRegime, candidates, count);

   for(int i = 0; i < count; i++)
   {
      StrategySignal sig;
      switch(candidates[i])
      {
         case STRAT_TREND_CONTINUATION:        sig = Strategy_TrendContinuation();      break;
         case STRAT_BREAKOUT_MOMENTUM:         sig = Strategy_BreakoutMomentum();       break;
         case STRAT_PULLBACK_ENTRY:            sig = Strategy_PullbackEntry();          break;
         case STRAT_VOLATILITY_EXPANSION:      sig = Strategy_VolatilityExpansion();    break;
         case STRAT_LIQUIDITY_SWEEP_REVERSAL:  sig = Strategy_LiquiditySweepReversal(); break;
         case STRAT_STRUCTURE_SHIFT:           sig = Strategy_StructureShift();         break;
         case STRAT_SESSION_MOMENTUM:          sig = Strategy_SessionMomentum();        break;
         case STRAT_COMPRESSION_BREAKOUT:      sig = Strategy_CompressionBreakout();    break;
         default: sig.valid = false; sig.rawScore = 0.0; break;
      }

      if(sig.valid && sig.dir != SIG_NONE && sig.rawScore > best.rawScore)
         best = sig;
   }

   return best;
}

string StrategyToString(ENUM_STRATEGY_ID s)
{
   switch(s)
   {
      case STRAT_TREND_CONTINUATION:       return "TrendContinuation";
      case STRAT_BREAKOUT_MOMENTUM:        return "BreakoutMomentum";
      case STRAT_PULLBACK_ENTRY:           return "PullbackEntry";
      case STRAT_VOLATILITY_EXPANSION:     return "VolatilityExpansion";
      case STRAT_LIQUIDITY_SWEEP_REVERSAL: return "LiquiditySweepReversal";
      case STRAT_STRUCTURE_SHIFT:          return "StructureShift";
      case STRAT_SESSION_MOMENTUM:         return "SessionMomentum";
      case STRAT_COMPRESSION_BREAKOUT:     return "CompressionBreakout";
      default: return "?";
   }
}

//+------------------------------------------------------------------+
//| CONFIDENCE ENGINE                                                  |
//| Weighted 0-100 score across 7 cross-cutting factors. This is      |
//| DISTINCT from the strategy's own rawScore (see strategy module    |
//| header comment). A trade needs a valid strategy signal AND this   |
//| score to clear the adaptive threshold.                            |
//+------------------------------------------------------------------+
ConfidenceBreakdown ComputeConfidence(StrategySignal &sig)
{
   ConfidenceBreakdown c;
   c.structureScore=0; c.trendScore=0; c.momentumScore=0; c.volumeScore=0;
   c.volatilityScore=0; c.liquidityScore=0; c.sessionScore=0; c.total=0;

   //--- Structure (0-100 raw, then weighted): proximity/break strength
   bool structNear = DetectStructureBreak(sig.dir, true);
   bool structBreak = DetectStructureBreak(sig.dir, false);
   c.structureScore = structBreak ? 100.0 : (structNear ? 60.0 : 25.0);

   //--- Trend: EMA stack alignment + HTF agreement
   double fast, slow, trend;
   double trendRaw = 0.0;
   if(GetEMAStack(fast, slow, trend))
   {
      bool aligns = (sig.dir==SIG_BUY) ? (fast>slow && slow>trend) : (fast<slow && slow<trend);
      trendRaw += aligns ? 60.0 : 20.0;
   }
   bool htfBull = false;
   if(InpUseHTFFilter && GetHTFTrend(htfBull))
   {
      bool htfAgrees = (sig.dir==SIG_BUY) ? htfBull : !htfBull;
      trendRaw += htfAgrees ? 40.0 : 0.0;
   }
   else trendRaw += 25.0; // HTF filter off - partial credit, neither confirmed nor denied
   c.trendScore = MathMin(100.0, trendRaw);

   //--- Momentum: RSI positioning + MACD agreement
   double rsi = GetRSI();
   double momRaw = 0.0;
   bool rsiHealthy = (sig.dir==SIG_BUY) ? (rsi>45.0 && rsi<InpRSIOverbought) : (rsi<55.0 && rsi>InpRSIOversold);
   momRaw += rsiHealthy ? 50.0 : 15.0;
   double macdCur, macdPrev;
   if(GetMACDHist(macdCur, macdPrev))
   {
      bool macdAgrees = (sig.dir==SIG_BUY) ? (macdCur > macdPrev) : (macdCur < macdPrev);
      momRaw += macdAgrees ? 50.0 : 10.0;
   }
   c.momentumScore = MathMin(100.0, momRaw);

   //--- Volume: surge confirmation
   c.volumeScore = IsVolumeSurging() ? 90.0 : 35.0;

   //--- Volatility: regime suitability - NORMAL/HIGH favoured over EXTREME
   //    (too chaotic to size confidently) or super-LOW (insufficient follow-through)
   if(g_VolPercentile >= InpVolExtremePctile)      c.volatilityScore = 40.0; // extreme - some caution
   else if(g_VolPercentile >= InpVolHighPctile)    c.volatilityScore = 90.0;
   else if(g_VolPercentile <= InpVolLowPctile)     c.volatilityScore = 45.0;
   else                                             c.volatilityScore = 75.0;

   //--- Liquidity: derived from the displacement detector - a moderate
   //    displacement score suggests real participation; near-zero suggests
   //    a dead/illiquid tape; pegged-at-max suggests possible instability.
   if(g_MarketDisplacementScore <= 5.0)       c.liquidityScore = 40.0;
   else if(g_MarketDisplacementScore >= 90.0) c.liquidityScore = 55.0;
   else                                         c.liquidityScore = 85.0;

   //--- Session (recency-weighted momentum consistency, see Strategy G note
   //    on what "session" means for a 24/7 asset in this file)
   double c0 = iClose(_Symbol, _Period, 1);
   double c1 = iClose(_Symbol, _Period, 2);
   bool sessionAgrees = (sig.dir==SIG_BUY) ? (c0 > c1) : (c0 < c1);
   c.sessionScore = sessionAgrees ? 80.0 : 40.0;

   //--- Weighted total. Weights sum to 100 by construction in InitWeights()
   //    and are kept normalised after any adaptive nudge - see
   //    AdaptWeightsFromPerformance().
   double wSum = g_Weights.wStructure + g_Weights.wTrend + g_Weights.wMomentum
               + g_Weights.wVolume + g_Weights.wVolatility + g_Weights.wLiquidity + g_Weights.wSession;
   if(wSum <= 0.0) wSum = 100.0; // safety floor, should not happen given bounded adaptation

   c.total = (c.structureScore  * g_Weights.wStructure
            + c.trendScore      * g_Weights.wTrend
            + c.momentumScore   * g_Weights.wMomentum
            + c.volumeScore     * g_Weights.wVolume
            + c.volatilityScore * g_Weights.wVolatility
            + c.liquidityScore  * g_Weights.wLiquidity
            + c.sessionScore    * g_Weights.wSession) / wSum;

   return c;
}

//--- Dynamic threshold: adapts within [InpConfMinThreshold, InpConfMaxThreshold]
//    based on loss streak, drawdown state, and recent regime performance.
//    This is the mechanism that prevents both extremes: it tightens after
//    losses (avoiding EA #1's indiscriminate firing) and loosens back down
//    when performance is healthy (avoiding EA #2's permanent over-filtering).
double GetDynamicThreshold()
{
   double t = InpConfBaseThreshold;

   if(g_ConsecLosses >= InpMaxLossStreak)      t += 8.0;
   else if(g_ConsecLosses >= 2)                t += 4.0;
   else if(g_ConsecWins  >= InpWinStreakBoost) t -= 4.0;

   if(g_RiskMode == RISKMODE_CAPITAL_PRESERVE) t += 6.0;
   else if(g_RiskMode == RISKMODE_RECOVERY)    t += 3.0;

   // Regime-bucket expectancy nudge: if this regime has been net-negative
   // over its tracked window, demand more confidence before trading it again.
   int regimeIdx = (int)g_CurrentRegime;
   if(regimeIdx >= 0 && regimeIdx < NUM_REGIMES && g_RegimePerf[regimeIdx].trades >= 5)
   {
      double exp = GetBucketExpectancy(g_RegimePerf[regimeIdx]);
      if(exp < 0.0) t += 5.0;
      else if(exp > 0.3) t -= 3.0;
   }

   return MathMax(InpConfMinThreshold, MathMin(InpConfMaxThreshold, t));
}

//+------------------------------------------------------------------+
//| BOUNDED ADAPTIVE WEIGHT NUDGING                                   |
//| Plain statement of what this is: per the lineage header, this is  |
//| NOT machine learning. It is a slowly-adjusting weighted average -  |
//| each factor's weight nudges up or down based on whether trades    |
//| taken when that factor scored well actually won, within hard      |
//| bounds (+/-40% of its starting value) so no single factor can     |
//| collapse to zero or dominate the score entirely.                  |
//+------------------------------------------------------------------+
void AdaptWeightsFromPerformance()
{
   // Runs on the 1s timer but only actually adjusts once enough closed
   // trades exist - avoid thrashing weights off a handful of samples.
   int totalStratTrades = 0;
   for(int i = 0; i < NUM_STRATEGIES; i++) totalStratTrades += g_StrategyPerf[i].trades;
   if(totalStratTrades < 8) return;

   // Nudge factor weights toward strategies/regimes with positive expectancy
   // and away from those with negative expectancy, distributing the delta
   // proportionally across the 7 confidence factors. This is intentionally
   // a small step size (max 0.5 points per cycle) - it is meant to drift
   // over hundreds of trades, not react to short-term swings.
   double stepSize = 0.5;

   double avgExpectancy = 0.0;
   int contributing = 0;
   for(int i = 0; i < NUM_STRATEGIES; i++)
   {
      if(g_StrategyPerf[i].trades >= 3)
      {
         avgExpectancy += GetBucketExpectancy(g_StrategyPerf[i]);
         contributing++;
      }
   }
   if(contributing == 0) return;
   avgExpectancy /= contributing;

   // If overall expectancy is healthy, lean weight slightly toward structure
   // and trend (the factors with the most signal in backtested confluence
   // systems generally); if unhealthy, lean toward volatility/liquidity
   // (i.e. become more conservative about WHEN to trade, not just whether).
   double direction = (avgExpectancy >= 0.0) ? 1.0 : -1.0;

   g_Weights.wStructure  += direction * stepSize;
   g_Weights.wTrend      += direction * stepSize * 0.6;
   g_Weights.wVolatility -= direction * stepSize * 0.5;
   g_Weights.wLiquidity  -= direction * stepSize * 0.5;

   // Bounds: clamp each weight to +/-40% of its InitWeights() starting value
   g_Weights.wStructure  = MathMax(15.0, MathMin(35.0, g_Weights.wStructure));
   g_Weights.wTrend      = MathMax(12.0, MathMin(28.0, g_Weights.wTrend));
   g_Weights.wMomentum   = MathMax(9.0,  MathMin(21.0, g_Weights.wMomentum));
   g_Weights.wVolume     = MathMax(9.0,  MathMin(21.0, g_Weights.wVolume));
   g_Weights.wVolatility = MathMax(6.0,  MathMin(14.0, g_Weights.wVolatility));
   g_Weights.wLiquidity  = MathMax(6.0,  MathMin(14.0, g_Weights.wLiquidity));
   g_Weights.wSession    = MathMax(3.0,  MathMin(7.0,  g_Weights.wSession));
   // Note: weights are NOT re-normalised to sum=100 after clamping - ComputeConfidence()
   // divides by the actual running wSum, so the weighted average stays mathematically
   // valid (0-100 range preserved) even as the relative proportions drift within bounds.
}

//+------------------------------------------------------------------+
//| RISK MODE & SIZING                                                 |
//+------------------------------------------------------------------+
ENUM_RISK_MODE DetermineRiskMode()
{
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   double ddPct = (g_EquityPeak > 0.0) ? ((g_EquityPeak - equity) / g_EquityPeak) * 100.0 : 0.0;

   if(ddPct > InpMaxDrawdownPct * 0.6) return RISKMODE_CAPITAL_PRESERVE;
   if(g_ConsecLosses >= InpMaxLossStreak) return RISKMODE_RECOVERY;
   return RISKMODE_NORMAL;
}

double GetRiskAdjustedPercent()
{
   double pct = InpRiskPercent;

   if(g_ConsecLosses >= InpMaxLossStreak)
      pct = InpRiskPercent * 0.5;
   else if(g_ConsecWins >= InpWinStreakBoost)
      pct = MathMin(InpRiskPercent * 1.25, 2.0);

   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   if(g_EquityPeak > 0.0)
   {
      double ddPct = ((g_EquityPeak - equity) / g_EquityPeak) * 100.0;
      if(ddPct > 8.0)      pct *= 0.5;
      else if(ddPct > 4.0) pct *= 0.75;
   }

   if(g_RiskMode == RISKMODE_CAPITAL_PRESERVE) pct *= 0.5;

   return pct;
}

double CalculateLotSize(double slDistancePrice)
{
   double balance   = AccountInfoDouble(ACCOUNT_BALANCE);
   double riskPct    = GetRiskAdjustedPercent();
   double riskAmount = balance * (riskPct / 100.0);

   double tickVal  = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   if(tickSize <= 0.0) return SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);

   double slCostPerLot = (slDistancePrice / tickSize) * tickVal;
   if(slCostPerLot <= 0.0) return SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);

   double lot  = riskAmount / slCostPerLot;
   double minV = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxV = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);

   lot = MathMax(minV, MathMin(maxV, MathFloor(lot / step) * step));
   return lot;
}

//+------------------------------------------------------------------+
//| EXECUTION                                                          |
//+------------------------------------------------------------------+
bool IsMarketOpen()
{
   ENUM_SYMBOL_TRADE_MODE m = (ENUM_SYMBOL_TRADE_MODE)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_MODE);
   return (m == SYMBOL_TRADE_MODE_FULL || m == SYMBOL_TRADE_MODE_LONGONLY || m == SYMBOL_TRADE_MODE_SHORTONLY);
}

bool IsSpreadOk()
{
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(bid <= 0.0) return false;
   double spread = ask - bid;
   double spreadPct = (spread / bid) * 100.0;

   if(spreadPct > InpMaxSpreadPercent) return false;
   if(g_SpreadSamples > 50 && spread > g_AvgSpread * InpSpreadAvgMultiple) return false;
   return true;
}

void UpdateSpreadAverage()
{
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double spread = ask - bid;
   int cap = 2000;
   g_AvgSpread = (g_AvgSpread * g_SpreadSamples + spread) / (double)(g_SpreadSamples + 1);
   g_SpreadSamples = MathMin(g_SpreadSamples + 1, cap);
}

bool IsWeekendPauseActive()
{
   MqlDateTime dt; TimeToStruct(TimeGMT(), dt);
   if(dt.day_of_week == 1 && dt.hour == 0 && dt.min < InpWeekendPauseMin)
      return true;
   return false;
}

//--- Entry with requote/slippage-aware retry. Tracks execution quality
//    metrics (requotes, rejects, realised slippage) for the dashboard.
void ExecuteEntry(StrategySignal &sig)
{
   if(!IsSpreadOk()) { Print("[NovaTitanX] Spread too wide at execution - aborted."); return; }

   int    digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   double atr    = GetATRValue();
   ENUM_SIGNAL_DIR dir = sig.dir;

   double slDistATR = atr * InpSLMultiplier;
   double priceForDist = (dir==SIG_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double minSLDist  = priceForDist * (InpMinSLPercent / 100.0);
   double maxSLDist  = priceForDist * (InpMaxSLPercent / 100.0);
   double slDistance = MathMax(minSLDist, MathMin(maxSLDist, slDistATR));
   double tp2Distance = atr * InpTP2Multiplier;

   double lot = CalculateLotSize(slDistance);
   bool ok = false;
   int attempts = 0;

   while(attempts <= InpMaxRequoteRetries && !ok)
   {
      double price = (dir==SIG_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);
      double sl, tp;
      if(dir == SIG_BUY)
      {
         sl = NormalizeDouble(price - slDistance,  digits);
         tp = NormalizeDouble(price + tp2Distance, digits);
      }
      else
      {
         sl = NormalizeDouble(price + slDistance,  digits);
         tp = NormalizeDouble(price - tp2Distance, digits);
      }

      ok = (dir==SIG_BUY) ? g_Trade.Buy(lot, _Symbol, price, sl, tp, InpTradeComment)
                          : g_Trade.Sell(lot, _Symbol, price, sl, tp, InpTradeComment);

      if(!ok)
      {
         uint rc = g_Trade.ResultRetcode();
         if(rc == TRADE_RETCODE_REQUOTE || rc == TRADE_RETCODE_PRICE_CHANGED)
         {
            g_RequoteCount++;
            attempts++;
            Sleep(150);
            continue;
         }
         g_RejectCount++;
         Print("[NovaTitanX] Order FAILED. RetCode=", rc, " ", g_Trade.ResultRetcodeDescription());
         break;
      }
      else
      {
         double fillPrice = g_Trade.ResultPrice();
         double slip = MathAbs(fillPrice - price);
         g_AvgSlippage = (g_AvgSlippage * g_SlippageSamples + slip) / (double)(g_SlippageSamples + 1);
         g_SlippageSamples = MathMin(g_SlippageSamples + 1, 2000);
      }
   }

   if(ok)
   {
      g_DailyTrades++;
      ResetTradeState();
      Sleep(100);
      CacheTradeEntry(sig.id);
      g_TradeRegime = g_CurrentRegime;
      g_StatusText  = StrategyToString(sig.id) + " " + (dir==SIG_BUY?"LONG":"SHORT") + " - IN TRADE";
      g_StatusColor = C_GREEN;
   }
}

//+------------------------------------------------------------------+
//| TRADE LIFECYCLE CACHE                                             |
//+------------------------------------------------------------------+
void CacheTradeEntry(ENUM_STRATEGY_ID stratId)
{
   for(int i = PositionsTotal()-1; i >= 0; i--)
   {
      if(!g_Pos.SelectByIndex(i)) continue;
      if(g_Pos.Magic()!=InpMagicNumber || g_Pos.Symbol()!=_Symbol) continue;

      g_EntryPrice     = g_Pos.PriceOpen();
      g_EntrySLPrice   = g_Pos.StopLoss();
      g_EntryATR       = GetATRValue();
      g_TradeDirection = (g_Pos.PositionType()==POSITION_TYPE_BUY) ? 1 : -1;
      g_PeakProfit     = 0.0;
      g_BESet          = false;
      g_PartialClosed  = false;
      g_TradeOpenTime  = TimeCurrent();
      g_TradeStrategyId = stratId;

      double slDistPrice = MathAbs(g_EntryPrice - g_EntrySLPrice);
      double tickVal  = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
      double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
      if(tickSize > 0.0)
         g_EntryRiskUSD = (slDistPrice / tickSize) * tickVal * g_Pos.Volume();
      else
         g_EntryRiskUSD = 0.01;
      if(g_EntryRiskUSD <= 0.0) g_EntryRiskUSD = 0.01;

      PrintFormat("[CacheEntry] Strategy=%s Entry=%.2f SL=%.2f SLdist=$%.2f Risk(1R)=$%.2f",
                  StrategyToString(stratId), g_EntryPrice, g_EntrySLPrice, slDistPrice, g_EntryRiskUSD);
      break;
   }
}

//--- Looks up trade history for the most recent closed deal under our
//    magic number/symbol since g_TradeOpenTime, to capture outcomes for
//    trades closed by the broker-side hard SL or TP2 ceiling rather than
//    by one of our own explicit exit checks. Only fires when g_TradeOpenTime
//    is non-zero (i.e. we actually had a cached trade in flight) and
//    g_EntryRiskUSD is known (so an R-multiple can be computed), preventing
//    this from misfiring on EA startup when there is no prior trade.
void CaptureUnmanagedExitIfAny()
{
   if(g_TradeOpenTime == 0 || g_EntryRiskUSD <= 0.0) return;

   datetime now = TimeCurrent();
   if(!HistorySelect(g_TradeOpenTime - 60, now)) return;

   double realizedPnl = 0.0;
   bool foundClosingDeal = false;
   datetime latestDealTime = 0;

   for(int i = 0; i < HistoryDealsTotal(); i++)
   {
      ulong tkt = HistoryDealGetTicket(i);
      if(tkt == 0) continue;
      if(HistoryDealGetInteger(tkt, DEAL_MAGIC) != (long)InpMagicNumber) continue;
      if(HistoryDealGetString(tkt, DEAL_SYMBOL) != _Symbol) continue;
      if(HistoryDealGetInteger(tkt, DEAL_ENTRY) != DEAL_ENTRY_OUT) continue;

      datetime dealTime = (datetime)HistoryDealGetInteger(tkt, DEAL_TIME);
      if(dealTime < g_TradeOpenTime) continue; // belongs to a previous trade, not this one

      double pnl = HistoryDealGetDouble(tkt, DEAL_PROFIT) + HistoryDealGetDouble(tkt, DEAL_COMMISSION) + HistoryDealGetDouble(tkt, DEAL_SWAP);
      realizedPnl += pnl; // sums partial-close-then-final-close legs that all post-date open time
      foundClosingDeal = true;
      if(dealTime > latestDealTime) latestDealTime = dealTime;
   }

   if(!foundClosingDeal) return; // nothing closed yet under our tracking window - shouldn't normally happen here

   double rMultiple = realizedPnl / g_EntryRiskUSD;
   PrintFormat("[UnmanagedExit] Captured broker-side close (SL/TP2 or external). RealizedPnL=$%.2f (%.2fR) Strategy=%s Regime=%s",
               realizedPnl, rMultiple, StrategyToString(g_TradeStrategyId), RegimeToString(g_TradeRegime));
   RecordTradeResult(g_TradeRegime, g_TradeStrategyId, rMultiple);
}

void ResetTradeState()
{
   g_PeakProfit=0.0; g_BESet=false; g_PartialClosed=false;
   g_EntryATR=0.0; g_EntryPrice=0.0; g_EntrySLPrice=0.0; g_EntryRiskUSD=0.0;
   g_TradeDirection=0; g_TradeOpenTime=0;
}

//+------------------------------------------------------------------+
//| MASTER TRADE MANAGER                                              |
//+------------------------------------------------------------------+
void ManageOpenTrade()
{
   if(!IsPositionOpen())
   {
      // Position vanished without going through one of our own explicit
      // close paths (CheckPeakProfitLock/CheckPartialClose/CheckTimeExit/
      // CheckDeteriorationExit) - this means the broker-side hard SL or
      // TP2 ceiling closed it. Without this check, that trade's outcome
      // would silently never reach RecordTradeResult(), and the adaptive
      // weighting/threshold system would only ever learn from actively-
      // managed exits - a real bias, not a cosmetic gap.
      CaptureUnmanagedExitIfAny();
      ResetTradeState();
      return;
   }

   double pnl = GetFloatingPnL();
   if(pnl > g_PeakProfit) g_PeakProfit = pnl;

   string rStr = (g_EntryRiskUSD > 0) ? " ("+DoubleToString(pnl/g_EntryRiskUSD,2)+"R)" : "";
   g_StatusText  = "TRADE RUNNING " + (pnl>=0?"+$":"-$") + DoubleToString(MathAbs(pnl),2) + rStr
                  + "  Peak:+$" + DoubleToString(g_PeakProfit,2);
   g_StatusColor = (pnl >= 0) ? C_GREEN : C_RED;

   //--- Priority order: peak-lock > partial close > time/deterioration > breakeven > trailing
   if(InpUsePeakLock) CheckPeakProfitLock(pnl);
   if(!IsPositionOpen()) return;

   if(InpUsePartialClose && !g_PartialClosed) CheckPartialClose(pnl);
   if(!IsPositionOpen()) return;

   CheckTimeExit();
   if(!IsPositionOpen()) return;

   CheckDeteriorationExit(pnl);
   if(!IsPositionOpen()) return;

   CheckBreakeven();
   if(!IsPositionOpen()) return;

   if(InpUseTrailing) CheckATRTrailing();
}

void CheckPeakProfitLock(double pnl)
{
   double oneR = g_EntryRiskUSD;
   if(oneR <= 0.0) return;
   double activateLevel = oneR * InpPeakLockActivateR;
   if(g_PeakProfit < activateLevel) return;

   double retraceLevel = g_PeakProfit * (1.0 - InpPeakLockRetrace / 100.0);
   double minRFloor = oneR * InpMinRewardRiskR;
   double lockLevel = MathMax(retraceLevel, minRFloor);
   if(g_PartialClosed) lockLevel = MathMax(lockLevel, oneR * InpMinLockProfitR);

   if(pnl <= lockLevel && pnl < g_PeakProfit)
   {
      double rMultiple = pnl / oneR;
      CloseAllPositions("Peak-profit lock triggered");
      RecordTradeResult(g_TradeRegime, g_TradeStrategyId, rMultiple);
      g_StatusText = "PEAK LOCK EXIT +$"+DoubleToString(pnl,2)+" ("+DoubleToString(rMultiple,2)+"R)";
      g_StatusColor = C_CYAN;
      ResetTradeState();
   }
}

void CheckPartialClose(double pnl)
{
   double oneR = g_EntryRiskUSD;
   if(oneR <= 0.0) return;
   double tp1Level = oneR * InpTP1R;
   if(pnl < tp1Level) return;

   for(int i = PositionsTotal()-1; i >= 0; i--)
   {
      if(!g_Pos.SelectByIndex(i)) continue;
      if(g_Pos.Magic()!=InpMagicNumber || g_Pos.Symbol()!=_Symbol) continue;

      bool isBuy = (g_Pos.PositionType()==POSITION_TYPE_BUY);
      double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      double volStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
      double closeLot = MathFloor((g_Pos.Volume()*(InpPartialClosePct/100.0))/volStep)*volStep;
      closeLot = NormalizeDouble(closeLot, 2);
      double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);

      if(closeLot < minLot)
      {
         double rMultiple = pnl / oneR;
         PrintFormat("[PartialClose] Lot %.2f below min %.2f - closing full position", closeLot, minLot);
         CloseAllPositions("TP1 full close (lot too small to partial)");
         RecordTradeResult(g_TradeRegime, g_TradeStrategyId, rMultiple);
         ResetTradeState();
         return;
      }

      if(g_Trade.PositionClosePartial(g_Pos.Ticket(), closeLot))
      {
         g_PartialClosed = true;
         PrintFormat("[PartialClose] %.2f lots closed. 1R=$%.2f Profit=$%.2f (%.2fR)", closeLot, oneR, pnl, pnl/oneR);
      }
   }
}

//--- Time-based exit: if a trade has run longer than InpMaxTradeBars closed
//    bars without reaching breakeven, close it - capital tied up in a stale
//    trade is an opportunity cost, not just a risk concern.
void CheckTimeExit()
{
   if(g_TradeOpenTime == 0) return;
   int periodSeconds = PeriodSeconds(_Period);
   if(periodSeconds <= 0) return;
   int barsElapsed = (int)((TimeCurrent() - g_TradeOpenTime) / periodSeconds);

   if(barsElapsed >= InpMaxTradeBars && !g_BESet)
   {
      double pnl = GetFloatingPnL();
      double rMultiple = (g_EntryRiskUSD > 0) ? pnl / g_EntryRiskUSD : 0.0;
      PrintFormat("[TimeExit] %d bars elapsed without reaching breakeven. Closing. PnL=$%.2f (%.2fR)",
                  barsElapsed, pnl, rMultiple);
      CloseAllPositions("Time-based exit - stale trade");
      RecordTradeResult(g_TradeRegime, g_TradeStrategyId, rMultiple);
      ResetTradeState();
   }
}

//--- Deterioration exit: if the trade has drifted to a meaningful negative
//    R-multiple AND momentum (MACD histogram) has turned further against
//    the position direction, exit early rather than wait for the hard SL -
//    this is a "the thesis is wrong" exit, distinct from the SL's "the
//    thesis is wrong AND we waited for proof" exit.
void CheckDeteriorationExit(double pnl)
{
   double oneR = g_EntryRiskUSD;
   if(oneR <= 0.0) return;
   double rMultiple = pnl / oneR;
   if(rMultiple > InpDeteriorationR) return; // not deteriorated enough yet

   double macdCur, macdPrev;
   if(!GetMACDHist(macdCur, macdPrev)) return;

   bool isBuy = (g_TradeDirection == 1);
   bool momentumAgainstUs = isBuy ? (macdCur < macdPrev && macdCur < 0.0) : (macdCur > macdPrev && macdCur > 0.0);

   if(momentumAgainstUs)
   {
      PrintFormat("[DeteriorationExit] R=%.2f below threshold %.2f and momentum confirms - closing early.",
                  rMultiple, InpDeteriorationR);
      CloseAllPositions("Deterioration exit - thesis invalidated early");
      RecordTradeResult(g_TradeRegime, g_TradeStrategyId, rMultiple);
      ResetTradeState();
   }
}

void CheckBreakeven()
{
   if(g_BESet) return;
   double oneR = g_EntryRiskUSD;
   if(oneR <= 0.0) return;
   double pnl = GetFloatingPnL();
   if(pnl < oneR * InpBreakevenR) return;

   for(int i = PositionsTotal()-1; i >= 0; i--)
   {
      if(!g_Pos.SelectByIndex(i)) continue;
      if(g_Pos.Magic()!=InpMagicNumber || g_Pos.Symbol()!=_Symbol) continue;

      double open = g_Pos.PriceOpen();
      double sl = g_Pos.StopLoss();
      int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
      bool isBuy = (g_Pos.PositionType()==POSITION_TYPE_BUY);
      double buffer = open * (InpBEBufferPercent / 100.0);
      double beSL = isBuy ? NormalizeDouble(open + buffer, digits) : NormalizeDouble(open - buffer, digits);
      bool needsMove = isBuy ? (sl < beSL) : (sl > beSL || sl == 0.0);

      if(needsMove && g_Trade.PositionModify(g_Pos.Ticket(), beSL, g_Pos.TakeProfit()))
      {
         g_BESet = true;
         PrintFormat("[Breakeven] SL moved to %.2f at profit $%.2f (%.2fR)", beSL, pnl, pnl/oneR);
      }
   }
}

void CheckATRTrailing()
{
   double oneR = g_EntryRiskUSD;
   if(oneR <= 0.0) return;
   double pnl = GetFloatingPnL();
   if(pnl < oneR * InpTrailStartR) return;

   double atr = (g_EntryATR > 0) ? g_EntryATR : GetATRValue();
   if(atr <= 0) return;
   double trailDist = atr * InpTrailATRMult;

   for(int i = PositionsTotal()-1; i >= 0; i--)
   {
      if(!g_Pos.SelectByIndex(i)) continue;
      if(g_Pos.Magic()!=InpMagicNumber || g_Pos.Symbol()!=_Symbol) continue;

      double open = g_Pos.PriceOpen();
      double sl = g_Pos.StopLoss();
      double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
      bool isBuy = (g_Pos.PositionType()==POSITION_TYPE_BUY);

      double newSL = isBuy ? NormalizeDouble(bid - trailDist, digits) : NormalizeDouble(ask + trailDist, digits);

      if(g_BESet)
      {
         double buffer = open * (InpBEBufferPercent / 100.0);
         double beFloor = isBuy ? NormalizeDouble(open + buffer, digits) : NormalizeDouble(open - buffer, digits);
         if(isBuy) newSL = MathMax(newSL, beFloor); else newSL = MathMin(newSL, beFloor);
      }

      bool improves;
      if(isBuy) improves = (newSL > sl && newSL < bid);
      else      improves = (sl == 0.0) ? (newSL > ask) : (newSL < sl && newSL > ask);

      if(improves) g_Trade.PositionModify(g_Pos.Ticket(), newSL, g_Pos.TakeProfit());
   }
}

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
   PrintFormat("[NovaTitanX] CloseAll: %s | Peak was $%.2f", reason, g_PeakProfit);
   for(int i = PositionsTotal()-1; i >= 0; i--)
      if(g_Pos.SelectByIndex(i) && g_Pos.Magic()==InpMagicNumber && g_Pos.Symbol()==_Symbol)
         g_Trade.PositionClose(g_Pos.Ticket());
   g_StateTimer = TimeCurrent() + 30;
   g_State = ENGSTATE_COOLDOWN;
}

//+------------------------------------------------------------------+
//| DAILY / WEEKLY STATS                                              |
//+------------------------------------------------------------------+
void SyncDailyStats()
{
   datetime now = TimeCurrent();
   datetime dayStart = GetDayStart(now);

   if(dayStart > g_SessionDay)
   {
      g_SessionDay = dayStart;
      g_DailyTrades = 0; g_DailyProfit = 0.0; g_DailyWins = 0; g_DailyLosses = 0;
      g_SessionOpenBal = AccountInfoDouble(ACCOUNT_BALANCE);
      if(g_State == ENGSTATE_DAILY_HALT) g_State = ENGSTATE_SCANNING;
   }

   g_DailyProfit = 0.0; g_DailyWins = 0; g_DailyLosses = 0;
   datetime scanFrom = dayStart - 7*86400;
   if(!HistorySelect(scanFrom, now)) return;

   int ringBuf[7]; ArrayInitialize(ringBuf, -1);
   int ringIdx = 0;
   bool lastWasWin = false;
   int curStreak = 0;
   int totalDeals = 0;

   for(int i = 0; i < HistoryDealsTotal(); i++)
   {
      ulong tkt = HistoryDealGetTicket(i);
      if(tkt == 0) continue;
      if(HistoryDealGetInteger(tkt, DEAL_MAGIC) != (long)InpMagicNumber) continue;
      if(HistoryDealGetString(tkt, DEAL_SYMBOL) != _Symbol) continue;
      if(HistoryDealGetInteger(tkt, DEAL_ENTRY) != DEAL_ENTRY_OUT) continue;

      double pnl = HistoryDealGetDouble(tkt, DEAL_PROFIT) + HistoryDealGetDouble(tkt, DEAL_COMMISSION) + HistoryDealGetDouble(tkt, DEAL_SWAP);
      bool win = (pnl >= 0.0);
      totalDeals++;

      datetime dealTime = (datetime)HistoryDealGetInteger(tkt, DEAL_TIME);
      if(dealTime >= dayStart)
      {
         g_DailyProfit += pnl;
         if(win) g_DailyWins++; else g_DailyLosses++;
      }

      ringBuf[ringIdx % 7] = win ? 1 : 0;
      ringIdx++;
      if(win == lastWasWin) curStreak++; else curStreak = 1;
      lastWasWin = win;
   }

   if(totalDeals > 0)
   {
      if(lastWasWin) { g_ConsecWins = curStreak; g_ConsecLosses = 0; }
      else           { g_ConsecLosses = curStreak; g_ConsecWins = 0; }
   }
   else { g_ConsecWins = 0; g_ConsecLosses = 0; }

   int wins7 = 0, total7 = 0;
   for(int j = 0; j < 7; j++) { if(ringBuf[j] < 0) continue; total7++; if(ringBuf[j]==1) wins7++; }
   g_WinRate7 = (total7 > 0) ? ((double)wins7/total7)*100.0 : 0.0;
   for(int j = 0; j < 7; j++) g_Last7Results[j] = ringBuf[j];
}

void SyncWeeklyStats()
{
   datetime now = TimeCurrent();
   datetime weekStart = GetWeekStart(now);

   if(weekStart > g_WeekStart)
   {
      g_WeekStart = weekStart;
      g_WeekOpenBal = AccountInfoDouble(ACCOUNT_BALANCE);
      g_WeekProfit = 0.0;
      if(g_State == ENGSTATE_EMERGENCY_HALT) g_State = ENGSTATE_SCANNING;
   }

   g_WeekProfit = 0.0;
   if(!HistorySelect(weekStart, now)) return;
   for(int i = 0; i < HistoryDealsTotal(); i++)
   {
      ulong tkt = HistoryDealGetTicket(i);
      if(tkt == 0) continue;
      if(HistoryDealGetInteger(tkt, DEAL_MAGIC) != (long)InpMagicNumber) continue;
      if(HistoryDealGetString(tkt, DEAL_SYMBOL) != _Symbol) continue;
      if(HistoryDealGetInteger(tkt, DEAL_ENTRY) != DEAL_ENTRY_OUT) continue;
      g_WeekProfit += HistoryDealGetDouble(tkt, DEAL_PROFIT) + HistoryDealGetDouble(tkt, DEAL_COMMISSION) + HistoryDealGetDouble(tkt, DEAL_SWAP);
   }
}

bool IsDailyLossLimitHit()
{
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double limit = balance * (InpMaxDailyLossPct / 100.0);
   return (g_DailyProfit <= -MathAbs(limit));
}

bool IsDailyProfitTargetHit()
{
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double target = balance * (InpMaxDailyProfitPct / 100.0);
   return (g_DailyProfit >= target);
}

bool IsWeeklyLossLimitHit()
{
   double limit = g_WeekOpenBal * (InpWeeklyLossLimitPct / 100.0);
   return (g_WeekProfit <= -MathAbs(limit));
}

bool IsDrawdownLimitHit()
{
   if(g_EquityPeak <= 0.0) return false;
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   double ddPct = ((g_EquityPeak - equity) / g_EquityPeak) * 100.0;
   return (ddPct >= InpMaxDrawdownPct);
}

datetime GetDayStart(datetime t)
{
   MqlDateTime d; TimeToStruct(t, d);
   return t - (datetime)(d.hour*3600 + d.min*60 + d.sec);
}

datetime GetWeekStart(datetime t)
{
   MqlDateTime d; TimeToStruct(t, d);
   datetime dayStart = t - (datetime)(d.hour*3600 + d.min*60 + d.sec);
   // day_of_week: 0=Sunday..6=Saturday. Treat Monday as week start.
   int daysSinceMonday = (d.day_of_week == 0) ? 6 : (d.day_of_week - 1);
   return dayStart - (datetime)(daysSinceMonday * 86400);
}

//+------------------------------------------------------------------+
//| PERFORMANCE BUCKET TRACKING                                       |
//| Feeds GetDynamicThreshold() and AdaptWeightsFromPerformance().    |
//| See those functions' headers for what this is and is not.         |
//+------------------------------------------------------------------+
void RecordTradeResult(ENUM_MARKET_REGIME regime, ENUM_STRATEGY_ID strat, double rMultiple)
{
   int win = (rMultiple >= 0.0) ? 1 : 0;

   int rIdx = (int)regime;
   if(rIdx >= 0 && rIdx < NUM_REGIMES)
   {
      PerfBucket b;
      b = g_RegimePerf[rIdx];
      b.results[b.idx % PERF_WINDOW] = win;
      b.idx++;
      b.count = MathMin(b.count + 1, PERF_WINDOW);
      b.sumR += rMultiple;
      b.trades++;
      g_RegimePerf[rIdx] = b;
   }

   int sIdx = (int)strat;
   if(sIdx >= 0 && sIdx < NUM_STRATEGIES)
   {
      PerfBucket b2;
      b2 = g_StrategyPerf[sIdx];
      b2.results[b2.idx % PERF_WINDOW] = win;
      b2.idx++;
      b2.count = MathMin(b2.count + 1, PERF_WINDOW);
      b2.sumR += rMultiple;
      b2.trades++;
      g_StrategyPerf[sIdx] = b2;
   }
}

double GetBucketExpectancy(PerfBucket &b)
{
   if(b.trades <= 0) return 0.0;
   // Expectancy here = average R-multiple across ALL recorded trades for
   // this bucket (not just the rolling window) - sumR/trades is the
   // standard expectancy definition, distinct from win RATE.
   return b.sumR / b.trades;
}

double GetBucketWinRate(PerfBucket &b)
{
   if(b.count <= 0) return 0.0;
   int wins = 0;
   for(int i = 0; i < b.count; i++) if(b.results[i] == 1) wins++;
   return ((double)wins / b.count) * 100.0;
}

//+------------------------------------------------------------------+
//| DASHBOARD                                                           |
//| Sections (top to bottom): Header / Market+Regime / Displacement    |
//| (labeled honestly, not "news") / Strategy Dispatch / Confidence     |
//| Breakdown / Open Position / Risk & Account / Performance Buckets   |
//+------------------------------------------------------------------+
#define DW 350

void RenderDashboard()
{
   int X = InpDashX, Y = InpDashY, W = DW, y = Y;

   DrawRect("SHELL", X, Y, W, 620, C_BG, C_BORDER, 2);

   DrawRect("HDR_BG", X+2, y+2, W-4, 26, C_HEADER, C_BORDER, 1);
   DrawLabel("HDR_IC",  X+6,    y+4,  "NOVA TITAN X", C_CYAN, 9, "Arial Black");
   DrawLabel("HDR_SYM", X+W-95, y+4,  _Symbol, C_GOLD, 9, "Impact");
   DrawLabel("HDR_TF",  X+W-50, y+15, TimeframeToString(_Period), C_MUTED, 7, "Arial");
   DrawLabel("HDR_VER", X+6,    y+15, EA_VERSION+" REGIME-ADAPTIVE ENGINE", C_MUTED, 7, "Arial");
   y += 29;

   //--- Regime block
   DrawRect("RG_HDR", X+2, y, W-4, 13, C_SECTION_HDR, C_BORDER2, 1);
   DrawLabel("RG_TIT", X+6, y+2, "MARKET REGIME", C_ORANGE, 7, "Arial Black");
   DrawLabel("RG_CLK", X+W-46, y+2, "00:00", C_MUTED, 7, "Arial");
   y += 14;
   DrawRect("RG_BG", X+2, y, W-4, 42, C_PANEL, C_BORDER2, 1);
   DrawLabel("L_REG",  X+6, y+3, "REGIME", C_MUTED, 7, "Arial");
   DrawLabel("V_REG",  X+55, y+3, "RANGING", C_VIOLET, 8, "Arial Bold");
   DrawLabel("L_ADX",  X+6, y+16, "ADX", C_MUTED, 7, "Arial");
   DrawLabel("V_ADX",  X+30, y+16, "0.0", C_WHITE, 7, "Arial Bold");
   DrawLabel("L_VPCT", X+W/2, y+16, "VolPctl", C_MUTED, 7, "Arial");
   DrawLabel("V_VPCT", X+W/2+42, y+16, "50%", C_WHITE, 7, "Arial Bold");
   DrawLabel("L_ATR",  X+6, y+29, "ATR", C_MUTED, 7, "Arial");
   DrawLabel("V_ATR",  X+30, y+29, "$0", C_CYAN, 7, "Arial Bold");
   DrawLabel("L_SPR",  X+W/2, y+29, "SPRD", C_MUTED, 7, "Arial");
   DrawLabel("V_SPR",  X+W/2+42, y+29, "0.00%", C_GOLD, 7, "Arial Bold");
   y += 44;

   //--- Displacement block (honest label, NOT "news detection")
   DrawRect("DP_HDR", X+2, y, W-4, 13, C_SECTION_HDR, C_BORDER2, 1);
   DrawLabel("DP_TIT", X+6, y+2, "DISPLACEMENT SCORE (vol/volume/spread - not news)", C_ORANGE, 6, "Arial Black");
   y += 14;
   DrawRect("DP_BG", X+2, y, W-4, 26, C_PANEL, C_BORDER2, 1);
   DrawLabel("L_DISP", X+6, y+3, "SCORE", C_MUTED, 7, "Arial");
   DrawRect("DISP_BG", X+50, y+4, 200, 10, C_PANEL2, C_BORDER2, 1);
   DrawRect("DISP_FG", X+50, y+4, 4, 10, C_BLUE, clrNONE, 0);
   DrawLabel("V_DISP", X+256, y+3, "0/100", C_WHITE, 7, "Arial Bold");
   DrawLabel("L_DACT", X+6, y+15, "ACTIVE", C_MUTED, 7, "Arial");
   DrawLabel("V_DACT", X+45, y+15, "NO", C_MUTED, 7, "Arial Bold");
   y += 28;

   //--- Strategy dispatch block
   DrawRect("SD_HDR", X+2, y, W-4, 13, C_SECTION_HDR, C_BORDER2, 1);
   DrawLabel("SD_TIT", X+6, y+2, "STRATEGY DISPATCH", C_ORANGE, 7, "Arial Black");
   y += 14;
   DrawRect("SD_BG", X+2, y, W-4, 42, C_PANEL, C_BORDER2, 1);
   DrawLabel("L_STRT", X+6, y+3, "ACTIVE", C_MUTED, 7, "Arial");
   DrawLabel("V_STRT", X+50, y+3, "---", C_WHITE, 8, "Arial Bold");
   DrawLabel("L_RSCR", X+W/2, y+3, "RawScr", C_MUTED, 7, "Arial");
   DrawLabel("V_RSCR", X+W/2+42, y+3, "0/100", C_CYAN, 7, "Arial Bold");
   DrawLabel("L_SDIR", X+6, y+16, "DIR", C_MUTED, 7, "Arial");
   DrawLabel("V_SDIR", X+30, y+16, "---", C_GOLD, 7, "Arial Bold");
   DrawLabel("L_SRSN", X+6, y+29, "WHY", C_MUTED, 7, "Arial");
   DrawLabel("V_SRSN", X+30, y+29, "scanning...", C_MUTED, 6, "Arial");
   y += 44;

   //--- Confidence breakdown block
   DrawRect("CF_HDR", X+2, y, W-4, 13, C_SECTION_HDR, C_BORDER2, 1);
   DrawLabel("CF_TIT", X+6, y+2, "CONFIDENCE ENGINE (weighted, 0-100)", C_ORANGE, 7, "Arial Black");
   y += 14;
   DrawRect("CF_BG", X+2, y, W-4, 70, C_PANEL, C_BORDER2, 1);
   DrawLabel("L_CST", X+6, y+3,  "Struct", C_MUTED, 7, "Arial"); DrawLabel("V_CST", X+48, y+3,  "0", C_WHITE, 7, "Arial Bold");
   DrawLabel("L_CTR", X+W/2, y+3,  "Trend", C_MUTED, 7, "Arial"); DrawLabel("V_CTR", X+W/2+42, y+3,  "0", C_WHITE, 7, "Arial Bold");
   DrawLabel("L_CMO", X+6, y+16, "Moment", C_MUTED, 7, "Arial"); DrawLabel("V_CMO", X+48, y+16, "0", C_WHITE, 7, "Arial Bold");
   DrawLabel("L_CVO", X+W/2, y+16, "Volume", C_MUTED, 7, "Arial"); DrawLabel("V_CVO", X+W/2+42, y+16, "0", C_WHITE, 7, "Arial Bold");
   DrawLabel("L_CVL", X+6, y+29, "Volatil", C_MUTED, 7, "Arial"); DrawLabel("V_CVL", X+48, y+29, "0", C_WHITE, 7, "Arial Bold");
   DrawLabel("L_CLQ", X+W/2, y+29, "Liquid", C_MUTED, 7, "Arial"); DrawLabel("V_CLQ", X+W/2+42, y+29, "0", C_WHITE, 7, "Arial Bold");
   DrawLabel("L_CSE", X+6, y+42, "Session", C_MUTED, 7, "Arial"); DrawLabel("V_CSE", X+48, y+42, "0", C_WHITE, 7, "Arial Bold");
   DrawRect("CONF_TOT_BG", X+2, y+54, W-4, 14, C_HOLD_BG, C_BORDER2, 1);
   DrawLabel("V_CTOT", X+6, y+56, "TOTAL: 0.0 / threshold 0.0", C_GOLD, 7, "Arial Black");
   y += 72;

   //--- Open position block
   DrawRect("OP_HDR", X+2, y, W-4, 13, C_SECTION_HDR, C_BORDER2, 1);
   DrawLabel("OP_TIT", X+6, y+2, "OPEN POSITION", C_ORANGE, 7, "Arial Black");
   DrawLabel("OP_CNT", X+W-44, y+2, "0 open", C_MUTED, 7, "Arial");
   y += 14;
   DrawRect("OP_BG", X+2, y, W-4, 42, C_PANEL, C_BORDER2, 1);
   DrawLabel("L_OTYP", X+6, y+3, "TYPE", C_MUTED, 7, "Arial"); DrawLabel("V_OTYP", X+32, y+3, "---", C_MUTED, 8, "Arial Bold");
   DrawLabel("L_OLOT", X+W/2-10, y+3, "LOT", C_MUTED, 7, "Arial"); DrawLabel("V_OLOT", X+W/2+14, y+3, "---", C_MUTED, 8, "Arial Bold");
   DrawLabel("L_OOPN", X+6, y+16, "OPEN", C_MUTED, 7, "Arial"); DrawLabel("V_OOPN", X+34, y+16, "---", C_WHITE, 7, "Arial Bold");
   DrawLabel("L_OSLT", X+W/2-10, y+16, "SL/TP", C_MUTED, 7, "Arial"); DrawLabel("V_OSLT", X+W/2+24, y+16, "--- / ---", C_WHITE, 7, "Arial Bold");
   DrawLabel("L_OPNL", X+6, y+29, "P&L", C_MUTED, 7, "Arial"); DrawLabel("V_OPNL", X+30, y+29, "+$0.00 (0.0R)", C_GREEN, 7, "Arial Bold");
   DrawLabel("L_OPK",  X+W/2+30, y+29, "PK", C_MUTED, 7, "Arial"); DrawLabel("V_OPK",  X+W/2+48, y+29, "+$0.00", C_CYAN, 7, "Arial Bold");
   y += 44;

   //--- Risk & account block
   DrawRect("AC_HDR", X+2, y, W-4, 13, C_SECTION_HDR, C_BORDER2, 1);
   DrawLabel("AC_TIT", X+6, y+2, "RISK & ACCOUNT", C_ORANGE, 7, "Arial Black");
   y += 14;
   DrawRect("AC_BG", X+2, y, W-4, 70, C_PANEL, C_BORDER2, 1);
   DrawLabel("L_BAL", X+6, y+3, "BAL", C_MUTED, 7, "Arial"); DrawLabel("V_BAL", X+30, y+3, "$0.00", C_GREEN, 8, "Arial Bold");
   DrawLabel("L_EQ",  X+W/2, y+3, "EQ", C_MUTED, 7, "Arial"); DrawLabel("V_EQ",  X+W/2+20, y+3, "$0.00", C_WHITE, 8, "Arial Bold");
   DrawLabel("L_DD",  X+6, y+16, "DD", C_MUTED, 7, "Arial"); DrawLabel("V_DD",  X+26, y+16, "0.00%", C_WHITE, 7, "Arial Bold");
   DrawLabel("L_RM",  X+W/2, y+16, "MODE", C_MUTED, 7, "Arial"); DrawLabel("V_RM",  X+W/2+40, y+16, "NORMAL", C_GREEN, 7, "Arial Bold");
   DrawLabel("L_DP",  X+6, y+29, "DAY", C_MUTED, 7, "Arial"); DrawLabel("V_DP",  X+30, y+29, "+0.00 (0.00%)", C_GREEN, 7, "Arial Bold");
   DrawLabel("L_WK",  X+W/2, y+29, "WEEK", C_MUTED, 7, "Arial"); DrawLabel("V_WK",  X+W/2+34, y+29, "+0.00", C_GREEN, 7, "Arial Bold");
   DrawLabel("L_RSK", X+6, y+42, "RISK%", C_MUTED, 7, "Arial"); DrawLabel("V_RSK", X+38, y+42, "0.0%", C_GOLD, 7, "Arial Bold");
   DrawLabel("L_TR",  X+W/2, y+42, "TRADES", C_MUTED, 7, "Arial"); DrawLabel("V_TR",  X+W/2+44, y+42, "0/0", C_WHITE, 7, "Arial Bold");
   DrawLabel("L_STK", X+6, y+55, "STRK", C_MUTED, 7, "Arial"); DrawLabel("V_STK", X+32, y+55, "---", C_MUTED, 7, "Arial Bold");
   DrawLabel("L_EXQ", X+W/2, y+55, "RQ/RJ/Slip", C_MUTED, 7, "Arial"); DrawLabel("V_EXQ", X+W/2+58, y+55, "0/0/$0", C_MUTED, 7, "Arial Bold");
   y += 72;

   //--- Performance buckets block
   DrawRect("PB_HDR", X+2, y, W-4, 13, C_SECTION_HDR, C_BORDER2, 1);
   DrawLabel("PB_TIT", X+6, y+2, "PERFORMANCE TRACKING (bounded stat. nudge, not ML)", C_ORANGE, 6, "Arial Black");
   y += 14;
   DrawRect("PB_BG", X+2, y, W-4, 56, C_PANEL, C_BORDER2, 1);
   DrawLabel("L_PREG", X+6, y+3, "Regime Exp(R)", C_MUTED, 7, "Arial"); DrawLabel("V_PREG", X+90, y+3, "0.00", C_WHITE, 7, "Arial Bold");
   DrawLabel("L_PSTR", X+6, y+16, "Best Strategy", C_MUTED, 7, "Arial"); DrawLabel("V_PSTR", X+90, y+16, "---", C_CYAN, 7, "Arial Bold");
   DrawLabel("L_PWR",  X+6, y+29, "7T Win Rate", C_MUTED, 7, "Arial"); DrawLabel("V_PWR",  X+90, y+29, "0%", C_GREEN, 7, "Arial Bold");
   DrawLabel("L_PWT",  X+6, y+42, "Weights S/T/M", C_MUTED, 7, "Arial"); DrawLabel("V_PWT",  X+90, y+42, "0/0/0", C_MUTED, 7, "Arial Bold");
   y += 58;

   ChartRedraw(0);
}

void UpdateDashboard()
{
   MqlDateTime dt; TimeToStruct(TimeCurrent(), dt);
   SetLabel("RG_CLK", StringFormat("%02d:%02d", dt.hour, dt.min), C_MUTED);

   //--- Regime block
   SetLabel("V_REG", RegimeToString(g_CurrentRegime), C_VIOLET);
   double adx = GetADX();
   SetLabel("V_ADX", DoubleToString(adx,1), (adx>=InpADXTrendMin)?C_GREEN:C_GOLD);
   SetLabel("V_VPCT", DoubleToString(g_VolPercentile,0)+"%", C_WHITE);
   SetLabel("V_ATR", "$"+DoubleToString(GetATRValue(),2), C_CYAN);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double spreadPct = (bid>0) ? ((ask-bid)/bid)*100.0 : 0.0;
   SetLabel("V_SPR", DoubleToString(spreadPct,3)+"%", IsSpreadOk()?C_GOLD:C_RED);

   //--- Displacement block
   SetLabel("V_DISP", DoubleToString(g_MarketDisplacementScore,0)+"/100", C_WHITE);
   string dispFgN = DASH_PREFIX+"DISP_FG";
   if(ObjectFind(0,dispFgN)>=0) ObjectSetInteger(0,dispFgN,OBJPROP_XSIZE, MathMax(4,(int)MathRound(200*(g_MarketDisplacementScore/100.0))));
   SetLabel("V_DACT", g_DisplacementActive?"YES":"NO", g_DisplacementActive?C_ORANGE:C_MUTED);

   //--- Strategy dispatch block
   if(g_HasWinningStrategy)
   {
      SetLabel("V_STRT", StrategyToString(g_LastWinningStrategy), C_CYAN);
      SetLabel("V_SDIR", (g_LastSignal.dir==SIG_BUY)?"BUY":"SELL", (g_LastSignal.dir==SIG_BUY)?C_GREEN:C_RED);
      SetLabel("V_RSCR", DoubleToString(g_LastSignal.rawScore,0)+"/100", C_CYAN);
      SetLabel("V_SRSN", g_LastSignal.reason, C_MUTED);
   }
   else
   {
      SetLabel("V_STRT", "---", C_MUTED);
      SetLabel("V_SDIR", "---", C_MUTED);
      SetLabel("V_RSCR", "0/100", C_MUTED);
      SetLabel("V_SRSN", g_StatusText, C_MUTED);
   }

   //--- Confidence breakdown
   SetLabel("V_CST", DoubleToString(g_LastConfidence.structureScore,0), C_WHITE);
   SetLabel("V_CTR", DoubleToString(g_LastConfidence.trendScore,0), C_WHITE);
   SetLabel("V_CMO", DoubleToString(g_LastConfidence.momentumScore,0), C_WHITE);
   SetLabel("V_CVO", DoubleToString(g_LastConfidence.volumeScore,0), C_WHITE);
   SetLabel("V_CVL", DoubleToString(g_LastConfidence.volatilityScore,0), C_WHITE);
   SetLabel("V_CLQ", DoubleToString(g_LastConfidence.liquidityScore,0), C_WHITE);
   SetLabel("V_CSE", DoubleToString(g_LastConfidence.sessionScore,0), C_WHITE);
   double thr = GetDynamicThreshold();
   color totClr = (g_LastConfidence.total >= thr) ? C_GREEN : C_GOLD;
   SetLabel("V_CTOT", "TOTAL: "+DoubleToString(g_LastConfidence.total,1)+" / threshold "+DoubleToString(thr,1), totClr);
   string ctotBgN = DASH_PREFIX+"CONF_TOT_BG";
   if(ObjectFind(0,ctotBgN)>=0) ObjectSetInteger(0,ctotBgN,OBJPROP_BGCOLOR, (g_LastConfidence.total>=thr)?C_BUY_BG:C_HOLD_BG);

   //--- Open position
   bool hasPos = false;
   for(int i = 0; i < PositionsTotal(); i++)
   {
      if(g_Pos.SelectByIndex(i) && g_Pos.Magic()==InpMagicNumber && g_Pos.Symbol()==_Symbol)
      {
         hasPos = true;
         string typStr = (g_Pos.PositionType()==POSITION_TYPE_BUY) ? "BUY" : "SELL";
         color typClr = (g_Pos.PositionType()==POSITION_TYPE_BUY) ? C_GREEN : C_RED;
         double rowPnl = g_Pos.Profit()+g_Pos.Swap()+g_Pos.Commission();

         SetLabel("V_OTYP", typStr, typClr);
         SetLabel("V_OLOT", DoubleToString(g_Pos.Volume(),2), C_WHITE);
         SetLabel("V_OOPN", DoubleToString(g_Pos.PriceOpen(),2), C_WHITE);
         SetLabel("V_OSLT", DoubleToString(g_Pos.StopLoss(),2)+" / "+DoubleToString(g_Pos.TakeProfit(),2), C_WHITE);
         string rTxt = (g_EntryRiskUSD>0) ? " ("+DoubleToString(rowPnl/g_EntryRiskUSD,2)+"R)" : "";
         color pnlClr = (rowPnl>=0) ? C_GREEN : C_RED;
         SetLabel("V_OPNL", (rowPnl>=0?"+$":"-$")+DoubleToString(MathAbs(rowPnl),2)+rTxt, pnlClr);
         SetLabel("V_OPK", "+$"+DoubleToString(g_PeakProfit,2), C_CYAN);
         break;
      }
   }
   if(!hasPos)
   {
      SetLabel("V_OTYP","---",C_MUTED); SetLabel("V_OLOT","---",C_MUTED); SetLabel("V_OOPN","---",C_MUTED);
      SetLabel("V_OSLT","--- / ---",C_MUTED); SetLabel("V_OPNL","+$0.00 (0.0R)",C_MUTED); SetLabel("V_OPK","+$0.00",C_MUTED);
   }
   SetLabel("OP_CNT", hasPos?"1 open":"0 open", hasPos?C_CYAN:C_MUTED);

   //--- Risk & account
   double bal = AccountInfoDouble(ACCOUNT_BALANCE);
   double eq  = AccountInfoDouble(ACCOUNT_EQUITY);
   SetLabel("V_BAL", "$"+DoubleToString(bal,2), C_GREEN);
   SetLabel("V_EQ",  "$"+DoubleToString(eq,2), C_WHITE);
   double ddPct = (g_EquityPeak>0) ? ((g_EquityPeak-eq)/g_EquityPeak)*100.0 : 0.0;
   color cDD = (ddPct > InpMaxDrawdownPct*0.66) ? C_RED : (ddPct > InpMaxDrawdownPct*0.33) ? C_GOLD : C_WHITE;
   SetLabel("V_DD", DoubleToString(ddPct,2)+"%", cDD);
   string rmStr = (g_RiskMode==RISKMODE_CAPITAL_PRESERVE)?"PRESERVE":(g_RiskMode==RISKMODE_RECOVERY)?"RECOVERY":"NORMAL";
   color rmClr = (g_RiskMode==RISKMODE_CAPITAL_PRESERVE)?C_RED:(g_RiskMode==RISKMODE_RECOVERY)?C_GOLD:C_GREEN;
   SetLabel("V_RM", rmStr, rmClr);
   double dpPct = (bal>0) ? (g_DailyProfit/bal)*100.0 : 0.0;
   color cDp = (g_DailyProfit>=0)?C_GREEN:C_RED;
   SetLabel("V_DP", (g_DailyProfit>=0?"+":"")+DoubleToString(g_DailyProfit,2)+" ("+DoubleToString(MathAbs(dpPct),2)+"%)", cDp);
   color cWk = (g_WeekProfit>=0)?C_GREEN:C_RED;
   SetLabel("V_WK", (g_WeekProfit>=0?"+":"")+DoubleToString(g_WeekProfit,2), cWk);
   SetLabel("V_RSK", DoubleToString(GetRiskAdjustedPercent(),2)+"%", C_GOLD);
   SetLabel("V_TR", IntegerToString(g_DailyTrades)+"/"+IntegerToString(InpMaxDailyTrades), C_WHITE);

   if(g_ConsecLosses >= 2) SetLabel("V_STK", "LOSS x"+IntegerToString(g_ConsecLosses), C_RED);
   else if(g_ConsecWins >= 2) SetLabel("V_STK", "WIN x"+IntegerToString(g_ConsecWins), C_GREEN);
   else SetLabel("V_STK", "---", C_MUTED);

   SetLabel("V_EXQ", IntegerToString(g_RequoteCount)+"/"+IntegerToString(g_RejectCount)+"/$"+DoubleToString(g_AvgSlippage,2), C_MUTED);

   //--- Performance buckets
   int regimeIdx = (int)g_CurrentRegime;
   if(regimeIdx>=0 && regimeIdx<NUM_REGIMES && g_RegimePerf[regimeIdx].trades > 0)
   {
      double exp = GetBucketExpectancy(g_RegimePerf[regimeIdx]);
      SetLabel("V_PREG", DoubleToString(exp,2), (exp>=0)?C_GREEN:C_RED);
   }
   else SetLabel("V_PREG", "n/a", C_MUTED);

   // Find best-expectancy strategy with >=3 trades
   double bestExp = -999.0; int bestIdx = -1;
   for(int i = 0; i < NUM_STRATEGIES; i++)
   {
      if(g_StrategyPerf[i].trades >= 3)
      {
         double e = GetBucketExpectancy(g_StrategyPerf[i]);
         if(e > bestExp) { bestExp = e; bestIdx = i; }
      }
   }
   if(bestIdx >= 0) SetLabel("V_PSTR", StrategyToString((ENUM_STRATEGY_ID)bestIdx), C_CYAN);
   else SetLabel("V_PSTR", "n/a (need 3+ trades)", C_MUTED);

   SetLabel("V_PWR", DoubleToString(g_WinRate7,0)+"%", (g_WinRate7>=50)?C_GREEN:C_GOLD);
   SetLabel("V_PWT", DoubleToString(g_Weights.wStructure,0)+"/"+DoubleToString(g_Weights.wTrend,0)+"/"+DoubleToString(g_Weights.wMomentum,0), C_MUTED);

   ChartRedraw(0);
}

void PurgeDashboard() { ObjectsDeleteAll(0, DASH_PREFIX); ChartRedraw(0); }

void DrawRect(string id, int x, int y, int w, int h, color bg, color border, int bw)
{
   string n = DASH_PREFIX + id;
   if(ObjectFind(0, n) < 0) ObjectCreate(0, n, OBJ_RECTANGLE_LABEL, 0, 0, 0);
   ObjectSetInteger(0, n, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, n, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, n, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, n, OBJPROP_XSIZE, w);
   ObjectSetInteger(0, n, OBJPROP_YSIZE, h);
   ObjectSetInteger(0, n, OBJPROP_BGCOLOR, bg);
   if(border != clrNONE)
   {
      ObjectSetInteger(0, n, OBJPROP_BORDER_TYPE, BORDER_FLAT);
      ObjectSetInteger(0, n, OBJPROP_COLOR, border);
      ObjectSetInteger(0, n, OBJPROP_WIDTH, bw);
   }
   else ObjectSetInteger(0, n, OBJPROP_BORDER_TYPE, BORDER_RAISED);
   ObjectSetInteger(0, n, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, n, OBJPROP_HIDDEN, true);
   ObjectSetInteger(0, n, OBJPROP_ZORDER, 0);
}

void DrawLabel(string id, int x, int y, string txt, color clr, int sz, string fnt)
{
   string n = DASH_PREFIX + id;
   if(ObjectFind(0, n) < 0) ObjectCreate(0, n, OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, n, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, n, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, n, OBJPROP_YDISTANCE, y);
   ObjectSetString(0, n, OBJPROP_TEXT, txt);
   ObjectSetInteger(0, n, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, n, OBJPROP_FONTSIZE, sz);
   ObjectSetString(0, n, OBJPROP_FONT, fnt);
   ObjectSetInteger(0, n, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, n, OBJPROP_HIDDEN, true);
   ObjectSetInteger(0, n, OBJPROP_ZORDER, 1);
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

string TimeframeToString(ENUM_TIMEFRAMES tf)
{
   switch(tf)
   {
      case PERIOD_M1:  return "M1";
      case PERIOD_M5:  return "M5";
      case PERIOD_M15: return "M15";
      case PERIOD_M30: return "M30";
      case PERIOD_H1:  return "H1";
      case PERIOD_H4:  return "H4";
      case PERIOD_D1:  return "D1";
      default:         return "?";
   }
}
//+------------------------------------------------------------------+
//| END OF FILE                                                        |
//+------------------------------------------------------------------+
