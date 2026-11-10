//+------------------------------------------------------------------+
//|                                            NOVA TITAN X.mq5       |
//|                         Third-Generation Institutional BTCUSD EA  |
//+------------------------------------------------------------------+
//
// =====================================================================
// DESIGN ORIGIN / AUDIT NOTES
// =====================================================================
// This EA was designed after auditing two prior systems:
//
//  PRIOR SYSTEM 1 - "Bulk Matrix" style engine (fixed-lot, bulk-entry,
//  single static signal, fixed-point SL/TP). Strength: high market
//  participation, simple state machine, never sits idle. Weakness: no
//  real risk sizing, ten correlated trades fired off one unconfirmed
//  signal, fixed-point exits meaningless across volatility regimes,
//  no drawdown protection.
//
//  PRIOR SYSTEM 2 - "Confluence/Regime" style engine (R-multiple risk
//  sizing, ATR-percentile volatility regime, single 9-point confluence
//  gate applied uniformly to every market condition). Strength:
//  genuinely correct risk-based position sizing and R-multiple exit
//  stack. Weakness: ONE checklist gating every entry regardless of
//  regime, so it structurally cannot trade well in conditions the
//  checklist wasn't built for (e.g. ranges, sweeps) - quiet for long
//  stretches, then identical logic re-asked on a timer rather than a
//  materially different confirmation.
//
//  CORE DESIGN RESPONSE - a REGIME ROUTER. The market is classified
//  into one of six mutually exclusive regimes every closed bar. Only
//  the ONE strategy module that is logically coherent with that regime
//  is allowed to generate a signal that tick. A trend-following module
//  and a mean-reversion module never vote on the same decision, because
//  their underlying assumptions about price behaviour directly
//  contradict each other - blending them produces an EA that performs
//  worse than either approach alone. Risk sizing, exits, and dashboard
//  density are inherited from the better-architected prior system and
//  generalised across all regimes; participation rate is inherited from
//  the simpler system's instinct to stay engaged, but every entry is now
//  individually risk-sized and individually confirmed - never bulk-fired
//  off one unconfirmed signal.
//
// =====================================================================
#property copyright   "Copyright 2026, NOVA TITAN Systems"
#property version     "1.00"
#property description "Third-Gen BTCUSD Regime-Routed Multi-Strategy Engine"
#property description "Adaptive risk sizing scales correctly from micro to institutional account size"
#property strict

#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>

#define DASH_PREFIX "NTX_"
#define EA_VERSION  "v1.00"
#define NUM_REGIMES 6

//+------------------------------------------------------------------+
//| ENUMS                                                             |
//+------------------------------------------------------------------+
enum ENUM_ENGINE_STATE
{
   ENGINE_SCANNING,
   ENGINE_CONFIRMING,     // short re-validation window before commit
   ENGINE_COOLDOWN,
   ENGINE_HALTED_DAILY,   // daily loss/profit limit hit
   ENGINE_HALTED_DD,      // equity drawdown limit hit
   ENGINE_RECOVERY        // reduced-risk mode after drawdown, rebuilding equity
};

enum ENUM_SIGNAL
{
   SIG_BUY  =  1,
   SIG_SELL = -1,
   SIG_NONE =  0
};

enum ENUM_REGIME
{
   REGIME_SHOCK,        // priority 1 - abnormal displacement/volume
   REGIME_BREAKOUT,     // priority 2 - squeeze release / structure break
   REGIME_TRENDING,     // priority 3 - persistent directional move
   REGIME_COMPRESSION,  // priority 4 - tight range, low ADX, pre-breakout
   REGIME_SWEEP,        // priority 5 - liquidity sweep + rejection wick
   REGIME_RANGING       // priority 6 - fallback / mean-reversion
};

enum ENUM_STRAT_MODULE
{
   STRAT_NONE,
   STRAT_TREND_CONT,     // A - Trend Continuation        (owns TRENDING)
   STRAT_BREAKOUT_MOM,   // B - Breakout Momentum         (owns BREAKOUT)
   STRAT_PULLBACK_MR,    // C - Pullback / Mean-Reversion (owns RANGING)
   STRAT_VOL_EXPANSION,  // D - Volatility Expansion       (owns SHOCK)
   STRAT_SWEEP_REV,      // E - Liquidity Sweep Reversal   (owns SWEEP)
   STRAT_COMPRESSION_BO  // H - Compression Breakout       (owns COMPRESSION)
};

//+------------------------------------------------------------------+
//| INPUT PARAMETERS                                                  |
//+------------------------------------------------------------------+
input group "=== CORE IDENTITY ==="
input ulong   InpMagicNumber        = 552901;      // Unique magic number
input string  InpTradeComment       = "NovaTitanX";

input group "=== ADAPTIVE RISK ENGINE (scales with account size automatically) ==="
input double  InpBaseRiskPercent    = 1.0;         // Base risk % of balance per trade
input double  InpMinRiskPercent     = 0.25;        // Floor risk % (deep drawdown / recovery mode)
input double  InpMaxRiskPercent     = 2.0;         // Ceiling risk % (win streak boost cap)
input double  InpMaxDailyLossPct    = 5.0;         // Daily loss kill-switch, % of balance
input double  InpMaxDailyProfitPct  = 8.0;         // Daily profit ceiling, % of balance
input double  InpMaxWeeklyLossPct   = 10.0;        // Weekly loss kill-switch, % of balance
input double  InpMaxDrawdownPct     = 15.0;        // All-time equity DD from peak -> halt
input double  InpRecoveryDDPct      = 8.0;         // DD level that triggers recovery mode (reduced size)
input int     InpMaxDailyTrades     = 20;          // Max trades per day
input int     InpMaxLossStreak      = 3;           // Loss streak that triggers size reduction
input int     InpWinStreakBoost     = 5;           // Win streak that allows modest size boost

input group "=== SMALL-ACCOUNT AFFORDABILITY GUARD ==="
input bool    InpSkipIfUnaffordable = true;        // Skip trade if min broker lot exceeds target risk
input double  InpMaxAffordRiskMult  = 2.5;         // Allow up to this x target risk if min-lot forces it

input group "=== ATR / VOLATILITY ==="
input int     InpATRPeriod          = 14;
input int     InpVolLookback        = 150;         // Bars for ATR percentile baseline
input double  InpVolExtremePctile   = 95.0;
input double  InpVolHighPercentile  = 80.0;
input double  InpVolLowPercentile   = 20.0;

input group "=== REGIME CLASSIFIER ==="
input int     InpRegimeADXPeriod    = 14;
input double  InpRegimeADXTrend     = 22.0;        // ADX above this = trending candidate
input double  InpRegimeADXLow       = 15.0;        // ADX below this = compression/ranging candidate
input int     InpBBPeriod           = 20;
input double  InpBBDeviation        = 2.0;
input double  InpBBSqueezePctile    = 20.0;        // BB-width percentile below this = squeeze
input double  InpBBExpansionPctile  = 75.0;        // BB-width percentile above this = expansion/breakout
input int     InpStructureBars      = 8;           // Swing high/low lookback for structure & sweep
input int     InpDisplacementLookback = 50;        // Bars for return z-score baseline
input double  InpShockZScoreThresh  = 2.5;         // Abs return z-score above this = shock candidate
input double  InpShockVolZThresh    = 2.0;         // Volume z-score above this = shock candidate

input group "=== SIGNAL ENGINE COMMON ==="
input int     InpFastEMAPeriod      = 8;
input int     InpSlowEMAPeriod      = 21;
input int     InpTrendEMAPeriod     = 55;
input int     InpRSIPeriod          = 14;
input double  InpRSIOverbought      = 72.0;
input double  InpRSIOversold        = 28.0;
input bool    InpUseHTFFilter       = true;
input ENUM_TIMEFRAMES InpHTFPeriod  = PERIOD_M15;
input int     InpHTFEMAPeriod       = 50;
input int     InpVolumeAvgPeriod    = 20;

input group "=== CONFIDENCE THRESHOLDS (0-100 scale, per module) ==="
input double  InpBaseConfidenceReq  = 62.0;        // Base required confidence to fire
input double  InpMaxConfidenceReq   = 85.0;        // Ceiling after repeated losses in a regime

input group "=== STOP LOSS / TAKE PROFIT (ATR + % bounded) ==="
input double  InpSLMultiplier       = 1.3;
input double  InpMinSLPercent       = 0.18;        // Floor SL distance as % of price
input double  InpMaxSLPercent       = 1.60;        // Ceiling SL distance as % of price
input double  InpTP2Multiplier      = 3.2;         // Hard server-side TP ceiling (ATR x mult)

input group "=== EXIT ENGINE (all R-multiple based) ==="
input double  InpBreakevenR         = 0.5;
input double  InpBEBufferPercent    = 0.02;
input bool    InpUsePeakLock        = true;
input double  InpPeakLockActivateR  = 0.8;
input double  InpPeakLockRetrace    = 25.0;
input double  InpMinRewardRiskR     = 1.0;
input bool    InpUseTrailing        = true;
input double  InpTrailStartR        = 0.6;
input double  InpTrailATRMult       = 0.7;
input bool    InpUsePartialClose    = true;
input double  InpPartialClosePct    = 50.0;
input double  InpTP1R               = 1.0;
input double  InpMinLockProfitR     = 0.5;
input int     InpMaxBarsToTarget    = 24;          // Time-based deterioration window (bars)
input double  InpDeteriorationR     = 0.3;         // Must reach this R within window or tighten exit

input group "=== SPREAD / EXECUTION PROTECTION ==="
input double  InpMaxSpreadPercent   = 0.06;
input double  InpSpreadAvgMultiple  = 2.5;
input int     InpSlippagePoints     = 50;

input group "=== SESSION / LIQUIDITY AWARENESS ==="
input bool    InpAvoidWeekendOpen   = true;
input int     InpWeekendPauseMin    = 30;

input group "=== DASHBOARD ==="
input int     InpDashX              = 15;
input int     InpDashY              = 15;

//+------------------------------------------------------------------+
//| COLOR PALETTE - institutional dark theme                         |
//+------------------------------------------------------------------+
const color C_BG          = C'5,7,12';
const color C_PANEL       = C'9,12,20';
const color C_PANEL2      = C'12,16,28';
const color C_HEADER      = C'11,16,32';
const color C_BORDER      = C'60,75,130';
const color C_BORDER2     = C'40,50,90';
const color C_CYAN        = C'0,215,210';
const color C_VIOLET      = C'150,110,255';
const color C_BLUE        = C'45,150,255';
const color C_GREEN       = C'0,220,140';
const color C_RED         = C'235,60,80';
const color C_GOLD        = C'255,190,30';
const color C_ORANGE      = C'255,140,30';
const color C_WHITE       = C'225,235,255';
const color C_MUTED       = C'100,115,150';
const color C_SECTION_HDR = C'14,20,44';
const color C_HOLD_BG     = C'45,38,0';
const color C_BUY_BG      = C'0,45,26';
const color C_SELL_BG     = C'50,6,12';

//+------------------------------------------------------------------+
//| GLOBAL TRADE OBJECTS                                              |
//+------------------------------------------------------------------+
CTrade        g_Trade;
CPositionInfo g_Pos;

//+------------------------------------------------------------------+
//| INDICATOR HANDLES                                                  |
//+------------------------------------------------------------------+
int g_hFastEMA  = INVALID_HANDLE;
int g_hSlowEMA  = INVALID_HANDLE;
int g_hTrendEMA = INVALID_HANDLE;
int g_hRSI      = INVALID_HANDLE;
int g_hATR      = INVALID_HANDLE;
int g_hADX      = INVALID_HANDLE;
int g_hBB       = INVALID_HANDLE;
int g_hHTFEMA   = INVALID_HANDLE;

//+------------------------------------------------------------------+
//| ENGINE STATE                                                       |
//+------------------------------------------------------------------+
ENUM_ENGINE_STATE g_State       = ENGINE_SCANNING;
datetime          g_StateTimer  = 0;

ENUM_SIGNAL       g_PendingSignal = SIG_NONE;
ENUM_STRAT_MODULE g_PendingModule = STRAT_NONE;
ENUM_REGIME       g_PendingRegime = REGIME_RANGING;
double            g_PendingConfidence = 0.0;
datetime          g_ConfirmStart  = 0;
int               g_ConfirmTicks  = 0;

//+------------------------------------------------------------------+
//| REGIME / DISPLACEMENT TRACKING                                    |
//+------------------------------------------------------------------+
ENUM_REGIME g_CurrentRegime   = REGIME_RANGING;
double      g_ATRHistory[];
double      g_BBWidthHistory[];
double      g_ReturnHistory[];     // for displacement z-score
double      g_VolumeHistoryArr[];  // for volume z-score
double      g_VolPercentile     = 50.0;
double      g_BBWidthPercentile = 50.0;
double      g_DisplacementZ     = 0.0;
double      g_VolumeZ           = 0.0;
bool        g_ShockActive       = false;
datetime    g_LastClassifyBar   = 0;

//+------------------------------------------------------------------+
//| TRADE LIFECYCLE CACHE (current open position)                     |
//+------------------------------------------------------------------+
double   g_PeakProfit       = 0.0;
double   g_PartialClosePrice= 0.0;
bool     g_BESet            = false;
bool     g_PartialClosed    = false;
double   g_EntryATR         = 0.0;
double   g_EntryPrice       = 0.0;
double   g_EntrySLPrice     = 0.0;
double   g_EntryRiskUSD     = 0.0;
int      g_TradeDirection   = 0;
datetime g_EntryBarTime     = 0;
int      g_EntryBarsElapsed = 0;
ENUM_STRAT_MODULE g_OpenModule = STRAT_NONE;
ENUM_REGIME       g_OpenRegime = REGIME_RANGING;
bool     g_DeteriorationTightened = false;

//+------------------------------------------------------------------+
//| DAILY / WEEKLY / EQUITY METRICS                                   |
//+------------------------------------------------------------------+
datetime g_SessionDay      = 0;
datetime g_WeekStart       = 0;
int      g_DailyTrades     = 0;
double   g_DailyProfit     = 0.0;
int      g_DailyWins       = 0;
int      g_DailyLosses     = 0;
double   g_WeeklyProfit    = 0.0;
int      g_ConsecLosses    = 0;
int      g_ConsecWins      = 0;
double   g_SessionOpenBal  = 0.0;
double   g_EquityPeak      = 0.0;

//+------------------------------------------------------------------+
//| PER-REGIME PERFORMANCE STRUCT (self-optimising stat tracking)     |
//+------------------------------------------------------------------+
struct RegimeStats
{
   int    trades;
   int    wins;
   int    losses;
   double grossProfit;
   double grossLoss;
   double sumR;             // sum of R-multiples achieved, for expectancy
   int    last10[10];       // ring buffer of win(1)/loss(0)
   int    ring10Idx;
   double dynamicThreshold; // adaptive confidence requirement for this regime
};
RegimeStats g_RegimeStats[NUM_REGIMES];

//+------------------------------------------------------------------+
//| SPREAD / VOLUME ROLLING AVERAGES                                  |
//+------------------------------------------------------------------+
double g_AvgSpread     = 0.0;
int    g_SpreadSamples = 0;
double g_AvgVolume     = 0.0;
int    g_VolumeSamples = 0;

//+------------------------------------------------------------------+
//| DASHBOARD STRINGS                                                  |
//+------------------------------------------------------------------+
string g_StatusText  = "BOOTING";
color  g_StatusColor = C_GOLD;

//+------------------------------------------------------------------+
//| FORWARD DECLARATIONS                                              |
//+------------------------------------------------------------------+
bool   InitIndicators();
void   ReleaseIndicators();
void   InitRegimeStats();
void   SyncDailyWeeklyStats();
datetime GetDayStart(datetime t);
datetime GetWeekStart(datetime t);

double GetATR();
void   UpdateVolatilityAndDisplacement();
ENUM_REGIME ClassifyRegime();
bool   DetectShock();
bool   DetectBreakoutCandidate();
bool   DetectTrendCandidate();
bool   DetectCompressionCandidate();
bool   DetectSweepCandidate();

struct ModuleResult { ENUM_SIGNAL sig; double confidence; };

ModuleResult Strategy_TrendContinuation();
ModuleResult Strategy_BreakoutMomentum();
ModuleResult Strategy_PullbackMeanReversion();
ModuleResult Strategy_VolatilityExpansion();
ModuleResult Strategy_LiquiditySweepReversal();
ModuleResult Strategy_CompressionBreakout();

bool   CheckHTFTrend(ENUM_SIGNAL sig);
bool   CheckVolumeSurge(double minMult);
void   UpdateVolumeAverage();
double GetRequiredConfidence(ENUM_REGIME regime);

double GetRiskAdjustedPercent(ENUM_REGIME regime);
double CalculateLotSize(double slDistancePrice, ENUM_REGIME regime);
bool   IsAffordable(double slDistancePrice, double lot);

void   ExecuteEntry(ENUM_SIGNAL sig, ENUM_STRAT_MODULE module, ENUM_REGIME regime, double confidence);
void   CacheTradeEntry(ENUM_STRAT_MODULE module, ENUM_REGIME regime);
void   ResetTradeState();
bool   IsPositionOpen();
double GetFloatingPnL();
void   CloseAllPositions(string reason);
void   ManageOpenTrade();
void   CheckBreakeven();
void   CheckATRTrailing();
void   CheckPeakProfitLock(double pnl);
void   CheckPartialClose(double pnl);
void   CheckTimeDeterioration();
void   EvaluateFloatingPnL(double pnl);
void   RecordClosedTradeFromHistory();

bool   IsMarketOpen();
bool   IsSpreadOk();
void   UpdateSpreadAverage();
bool   IsDailyLossLimitHit();
bool   IsDailyProfitTargetHit();
bool   IsWeeklyLossLimitHit();
bool   IsDrawdownLimitHit();
bool   IsRecoveryModeActive();
bool   IsWeekendPauseActive();

string RegimeToString(ENUM_REGIME r);
string ModuleToString(ENUM_STRAT_MODULE m);
string TimeframeToString(ENUM_TIMEFRAMES tf);

void   RenderDashboard();
void   UpdateDashboard();
void   PurgeDashboard();
void   DrawRect(string id, int x, int y, int w, int h, color bg, color border, int bw);
void   DrawLabel(string id, int x, int y, string txt, color clr, int sz, string fnt);
void   SetLabel(string id, string txt, color clr = clrNONE);

//+------------------------------------------------------------------+
//| INIT                                                               |
//+------------------------------------------------------------------+
int OnInit()
{
   if(StringFind(_Symbol, "BTC") < 0)
      Print("[NovaTitanX] NOTE: this EA is tuned for BTCUSD. Current symbol: ", _Symbol,
            " - regime thresholds and % based filters should still function but were not tuned for this instrument.");

   g_Trade.SetExpertMagicNumber(InpMagicNumber);
   g_Trade.SetDeviationInPoints(InpSlippagePoints);
   g_Trade.SetTypeFilling(ORDER_FILLING_FOK);

   if(InpBaseRiskPercent <= 0.0 || InpBaseRiskPercent > 10.0)
   { Alert("InpBaseRiskPercent must be 0.01-10. Got: ", InpBaseRiskPercent); return INIT_PARAMETERS_INCORRECT; }
   if(InpMinRiskPercent > InpBaseRiskPercent || InpMaxRiskPercent < InpBaseRiskPercent)
   { Alert("Risk floor/ceiling must straddle base risk %."); return INIT_PARAMETERS_INCORRECT; }
   if(InpVolLookback < 15)
   { Alert("InpVolLookback must be at least 15 for a meaningful percentile baseline. Got: ", InpVolLookback); return INIT_PARAMETERS_INCORRECT; }
   if(InpDisplacementLookback < 15)
   { Alert("InpDisplacementLookback must be at least 15 for a meaningful z-score baseline. Got: ", InpDisplacementLookback); return INIT_PARAMETERS_INCORRECT; }
   if(InpStructureBars < 3)
   { Alert("InpStructureBars must be at least 3 for a meaningful swing high/low. Got: ", InpStructureBars); return INIT_PARAMETERS_INCORRECT; }
   if(InpBBSqueezePctile <= 0.0)
   { Alert("InpBBSqueezePctile must be greater than 0 (used as a divisor in compression scoring). Got: ", InpBBSqueezePctile); return INIT_PARAMETERS_INCORRECT; }
   if(InpRegimeADXTrend <= 0.0)
   { Alert("InpRegimeADXTrend must be greater than 0 (used as a divisor in mean-reversion scoring). Got: ", InpRegimeADXTrend); return INIT_PARAMETERS_INCORRECT; }
   if(InpShockZScoreThresh <= 0.0)
   { Alert("InpShockZScoreThresh must be greater than 0 (used as a divisor in shock-expansion scoring). Got: ", InpShockZScoreThresh); return INIT_PARAMETERS_INCORRECT; }
   if(InpShockVolZThresh <= 0.0)
   { Alert("InpShockVolZThresh must be greater than 0 (used as a divisor in shock-expansion scoring). Got: ", InpShockVolZThresh); return INIT_PARAMETERS_INCORRECT; }

   if(!InitIndicators()) return INIT_FAILED;

   ArrayResize(g_ATRHistory, InpVolLookback);     ArrayInitialize(g_ATRHistory, 0.0);
   ArrayResize(g_BBWidthHistory, InpVolLookback);  ArrayInitialize(g_BBWidthHistory, 0.0);
   ArrayResize(g_ReturnHistory, InpDisplacementLookback); ArrayInitialize(g_ReturnHistory, 0.0);
   ArrayResize(g_VolumeHistoryArr, InpDisplacementLookback); ArrayInitialize(g_VolumeHistoryArr, 0.0);

   InitRegimeStats();

   datetime now = TimeCurrent();
   g_SessionDay     = GetDayStart(now);
   g_WeekStart      = GetWeekStart(now);
   g_SessionOpenBal = AccountInfoDouble(ACCOUNT_BALANCE);
   g_EquityPeak     = AccountInfoDouble(ACCOUNT_EQUITY);
   SyncDailyWeeklyStats();

   g_State = ENGINE_SCANNING;
   EventSetTimer(1);
   RenderDashboard();

   Print("[NovaTitanX] Initialised. Symbol=", _Symbol, " Magic=", InpMagicNumber,
         " TF=", EnumToString(_Period), " Balance=", DoubleToString(g_SessionOpenBal,2));
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
//| TIMER - stats sync + regime/vol refresh + dashboard               |
//+------------------------------------------------------------------+
void OnTimer()
{
   SyncDailyWeeklyStats();
   UpdateVolatilityAndDisplacement();
   UpdateVolumeAverage();

   double eq = AccountInfoDouble(ACCOUNT_EQUITY);
   if(eq > g_EquityPeak) g_EquityPeak = eq;

   g_CurrentRegime = ClassifyRegime();

   UpdateDashboard();
}

//+------------------------------------------------------------------+
//| TICK - main engine                                                 |
//+------------------------------------------------------------------+
void OnTick()
{
   UpdateSpreadAverage();

   if(!IsMarketOpen())
   { g_StatusText = "MARKET CLOSED / TRADE DISABLED"; g_StatusColor = C_RED; return; }

   //--- Manage any open position first - exit logic always runs regardless of state
   if(IsPositionOpen())
   { ManageOpenTrade(); return; }

   //--- Equity drawdown circuit breaker (all-time peak, broadest safety net)
   if(IsDrawdownLimitHit())
   {
      g_State = ENGINE_HALTED_DD;
      g_StatusText  = "MAX DRAWDOWN HIT - HALTED";
      g_StatusColor = C_RED;
      return;
   }

   //--- Daily / weekly kill switches
   if(IsDailyLossLimitHit())
   { g_State = ENGINE_HALTED_DAILY; g_StatusText = "DAILY LOSS LIMIT - HALTED"; g_StatusColor = C_RED; return; }
   if(IsWeeklyLossLimitHit())
   { g_State = ENGINE_HALTED_DAILY; g_StatusText = "WEEKLY LOSS LIMIT - HALTED"; g_StatusColor = C_RED; return; }
   if(IsDailyProfitTargetHit())
   { g_State = ENGINE_HALTED_DAILY; g_StatusText = "DAILY TARGET MET - HALTED"; g_StatusColor = C_GREEN; return; }

   //--- Max daily trades
   if(g_DailyTrades >= InpMaxDailyTrades)
   { g_StatusText = "MAX DAILY TRADES REACHED"; g_StatusColor = C_GOLD; return; }

   //--- Weekend / thin liquidity pause
   if(InpAvoidWeekendOpen && IsWeekendPauseActive())
   { g_StatusText = "WEEKEND OPEN PAUSE"; g_StatusColor = C_MUTED; return; }

   //--- Spread guard
   if(!IsSpreadOk())
   {
      double sp = SymbolInfoDouble(_Symbol, SYMBOL_ASK) - SymbolInfoDouble(_Symbol, SYMBOL_BID);
      g_StatusText  = "SPREAD TOO WIDE ($" + DoubleToString(sp,2) + ")";
      g_StatusColor = C_RED;
      return;
   }

   //--- If halted-daily state but the day rolled over, SyncDailyWeeklyStats already
   //    reset it to SCANNING. If halted-DD, only a fresh equity-peak rebuild via
   //    recovery mode can clear it - handled inside SyncDailyWeeklyStats/manual restart.
   if(g_State == ENGINE_HALTED_DAILY || g_State == ENGINE_HALTED_DD)
   {
      g_StatusText  = (g_State==ENGINE_HALTED_DD) ? "HALTED: DRAWDOWN LIMIT" : "HALTED: DAILY/WEEKLY LIMIT";
      g_StatusColor = C_RED;
      return;
   }

   //--- Cooldown
   if(g_State == ENGINE_COOLDOWN)
   {
      int left = (int)(g_StateTimer - TimeCurrent());
      if(left > 0)
      { g_StatusText = "COOLDOWN (" + IntegerToString(left) + "s)"; g_StatusColor = C_GOLD; return; }
      g_State = ENGINE_SCANNING;
   }

   //--- Refresh regime on every tick read (cheap - classification itself is bar-gated internally)
   g_CurrentRegime = ClassifyRegime();

   //--- SCANNING: route to the single strategy module that owns this regime
   if(g_State == ENGINE_SCANNING)
   {
      ModuleResult res;
      res.sig = SIG_NONE; res.confidence = 0.0;
      ENUM_STRAT_MODULE mod = STRAT_NONE;

      switch(g_CurrentRegime)
      {
         case REGIME_SHOCK:        res = Strategy_VolatilityExpansion;     mod = STRAT_VOL_EXPANSION;   break;
         case REGIME_BREAKOUT:     res = Strategy_BreakoutMomentum;        mod = STRAT_BREAKOUT_MOM;    break;
         case REGIME_TRENDING:     res = Strategy_TrendContinuation;       mod = STRAT_TREND_CONT;      break;
         case REGIME_COMPRESSION:  res = Strategy_CompressionBreakout;     mod = STRAT_COMPRESSION_BO;  break;
         case REGIME_SWEEP:        res = Strategy_LiquiditySweepReversal;  mod = STRAT_SWEEP_REV;       break;
         case REGIME_RANGING:
         default:                  res = Strategy_PullbackMeanReversion;   mod = STRAT_PULLBACK_MR;     break;
      }

      double required = GetRequiredConfidence(g_CurrentRegime);

      if(res.sig == SIG_NONE || res.confidence < required)
      {
         g_StatusText  = RegimeToString(g_CurrentRegime) + " | " + ModuleToString(mod) +
                          " scanning (" + DoubleToString(res.confidence,0) + "/" + DoubleToString(required,0) + ")";
         g_StatusColor = C_MUTED;
         return;
      }

      g_State            = ENGINE_CONFIRMING;
      g_PendingSignal     = res.sig;
      g_PendingModule     = mod;
      g_PendingRegime      = g_CurrentRegime;
      g_PendingConfidence  = res.confidence;
      g_ConfirmStart       = TimeCurrent();
      g_ConfirmTicks       = 0;
      g_StatusText  = "SIGNAL: " + ModuleToString(mod) + " " + (res.sig==SIG_BUY?"BUY":"SELL") +
                       " conf=" + DoubleToString(res.confidence,0);
      g_StatusColor = C_VIOLET;
      PrintFormat("[NovaTitanX] Signal: regime=%s module=%s sig=%s confidence=%.1f required=%.1f",
                  RegimeToString(g_CurrentRegime), ModuleToString(mod),
                  (res.sig==SIG_BUY?"BUY":"SELL"), res.confidence, required);
   }
   else if(g_State == ENGINE_CONFIRMING)
   {
      g_ConfirmTicks++;
      int elapsed = (int)(TimeCurrent() - g_ConfirmStart);

      //--- Short re-validation: regime must not have flipped, and the same module
      //    re-evaluated must still agree in direction with at least 90% of its
      //    original confidence - a genuinely different check than "ask again",
      //    because regime drift during the window invalidates the setup outright.
      if(elapsed > 12)
      {
         ENUM_REGIME nowRegime = ClassifyRegime();
         if(nowRegime != g_PendingRegime)
         {
            Print("[NovaTitanX] Confirmation aborted - regime shifted during confirmation window.");
            g_State = ENGINE_SCANNING;
            return;
         }

         ModuleResult recheck;
         switch(g_PendingModule)
         {
            case STRAT_TREND_CONT:      recheck = Strategy_TrendContinuation;      break;
            case STRAT_BREAKOUT_MOM:    recheck = Strategy_BreakoutMomentum;       break;
            case STRAT_PULLBACK_MR:     recheck = Strategy_PullbackMeanReversion;  break;
            case STRAT_VOL_EXPANSION:   recheck = Strategy_VolatilityExpansion;    break;
            case STRAT_SWEEP_REV:       recheck = Strategy_LiquiditySweepReversal; break;
            case STRAT_COMPRESSION_BO:  recheck = Strategy_CompressionBreakout;    break;
            default: recheck.sig = SIG_NONE; recheck.confidence = 0.0; break;
         }

         if(recheck.sig != g_PendingSignal || recheck.confidence < g_PendingConfidence * 0.9)
         {
            Print("[NovaTitanX] Confirmation failed re-check - aborting entry.");
            g_StateTimer = TimeCurrent() + 8;
            g_State      = ENGINE_COOLDOWN;
            return;
         }

         ExecuteEntry(g_PendingSignal, g_PendingModule, g_PendingRegime, recheck.confidence);
         g_StateTimer = TimeCurrent() + 5;
         g_State      = ENGINE_COOLDOWN;
      }
      else
      {
         g_StatusText  = "CONFIRMING " + ModuleToString(g_PendingModule) + " (" + IntegerToString(elapsed) + "s)";
         g_StatusColor = C_VIOLET;
      }
   }
}

//+------------------------------------------------------------------+
//| INDICATOR INIT / RELEASE                                          |
//+------------------------------------------------------------------+
bool InitIndicators()
{
   g_hFastEMA  = iMA(_Symbol, _Period, InpFastEMAPeriod,  0, MODE_EMA, PRICE_CLOSE);
   g_hSlowEMA  = iMA(_Symbol, _Period, InpSlowEMAPeriod,  0, MODE_EMA, PRICE_CLOSE);
   g_hTrendEMA = iMA(_Symbol, _Period, InpTrendEMAPeriod, 0, MODE_EMA, PRICE_CLOSE);
   g_hRSI      = iRSI(_Symbol, _Period, InpRSIPeriod, PRICE_CLOSE);
   g_hATR      = iATR(_Symbol, _Period, InpATRPeriod);
   g_hADX      = iADX(_Symbol, _Period, InpRegimeADXPeriod);
   g_hBB       = iBands(_Symbol, _Period, InpBBPeriod, 0, InpBBDeviation, PRICE_CLOSE);
   g_hHTFEMA   = iMA(_Symbol, InpHTFPeriod, InpHTFEMAPeriod, 0, MODE_EMA, PRICE_CLOSE);

   if(g_hFastEMA==INVALID_HANDLE || g_hSlowEMA==INVALID_HANDLE || g_hTrendEMA==INVALID_HANDLE ||
      g_hRSI==INVALID_HANDLE     || g_hATR==INVALID_HANDLE     || g_hADX==INVALID_HANDLE ||
      g_hBB==INVALID_HANDLE      || g_hHTFEMA==INVALID_HANDLE)
   {
      Print("[NovaTitanX] FAILED: one or more indicator handles invalid.");
      return false;
   }
   return true;
}

void ReleaseIndicators()
{
   int handles[] = {g_hFastEMA, g_hSlowEMA, g_hTrendEMA, g_hRSI, g_hATR, g_hADX, g_hBB, g_hHTFEMA};
   for(int i = 0; i < ArraySize(handles); i++)
      if(handles[i] != INVALID_HANDLE) IndicatorRelease(handles[i]);
}

void InitRegimeStats()
{
   for(int r = 0; r < NUM_REGIMES; r++)
   {
      g_RegimeStats[r].trades = 0;
      g_RegimeStats[r].wins = 0;
      g_RegimeStats[r].losses = 0;
      g_RegimeStats[r].grossProfit = 0.0;
      g_RegimeStats[r].grossLoss = 0.0;
      g_RegimeStats[r].sumR = 0.0;
      g_RegimeStats[r].ring10Idx = 0;
      for(int j = 0; j < 10; j++) g_RegimeStats[r].last10[j] = -1;
      g_RegimeStats[r].dynamicThreshold = InpBaseConfidenceReq;
   }
}

//+------------------------------------------------------------------+
//| DAILY / WEEKLY STATS SYNC                                         |
//+------------------------------------------------------------------+
void SyncDailyWeeklyStats()
{
   datetime now      = TimeCurrent();
   datetime dayStart = GetDayStart(now);
   datetime wkStart  = GetWeekStart(now);

   if(dayStart > g_SessionDay)
   {
      g_SessionDay     = dayStart;
      g_DailyTrades    = 0;
      g_DailyProfit    = 0.0;
      g_DailyWins      = 0;
      g_DailyLosses    = 0;
      g_SessionOpenBal = AccountInfoDouble(ACCOUNT_BALANCE);
      if(g_State == ENGINE_HALTED_DAILY) g_State = ENGINE_SCANNING;
   }
   if(wkStart > g_WeekStart)
   {
      g_WeekStart    = wkStart;
      g_WeeklyProfit = 0.0;
   }

   g_DailyProfit = 0.0; g_DailyWins = 0; g_DailyLosses = 0; g_WeeklyProfit = 0.0;

   datetime scanFrom = wkStart - 7*86400; // extra week back, safety margin
   if(!HistorySelect(scanFrom, now)) return;

   bool lastWasWin = false;
   int  curStreak   = 0;
   int  totalDeals  = 0;

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

      datetime dealTime = (datetime)HistoryDealGetInteger(tkt, DEAL_TIME);
      if(dealTime >= dayStart) { g_DailyProfit += pnl; if(win) g_DailyWins++; else g_DailyLosses++; }
      if(dealTime >= wkStart)  g_WeeklyProfit += pnl;

      if(win == lastWasWin) curStreak++; else curStreak = 1;
      lastWasWin = win;
   }

   if(totalDeals > 0)
   {
      if(lastWasWin) { g_ConsecWins = curStreak; g_ConsecLosses = 0; }
      else           { g_ConsecLosses = curStreak; g_ConsecWins  = 0; }
   }
   else { g_ConsecWins = 0; g_ConsecLosses = 0; }
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
   int dow = d.day_of_week; // 0=Sunday
   return dayStart - (datetime)(dow * 86400);
}

//+------------------------------------------------------------------+
//| ATR                                                                |
//+------------------------------------------------------------------+
double GetATR()
{
   double atr[1];
   if(CopyBuffer(g_hATR, 0, 0, 1, atr) <= 0) return 0.0;
   return atr[0];
}

//+------------------------------------------------------------------+
//| VOLATILITY + DISPLACEMENT ROLLING UPDATE                          |
//| New-bar gated (same correct technique validated in prior system): |
//| sampling every second instead of once per closed bar would flood |
//| the rolling buffers with near-duplicate values of 1-2 bars and    |
//| corrupt every percentile/z-score calculation that depends on it. |
//+------------------------------------------------------------------+
void UpdateVolatilityAndDisplacement()
{
   static datetime lastBarTime = 0;
   datetime curBarTime = (datetime)SeriesInfoInteger(_Symbol, _Period, SERIES_LASTBAR_DATE);
   if(curBarTime == lastBarTime) return;
   lastBarTime = curBarTime;

   //--- ATR percentile ---
   double curATR = GetATR();
   if(curATR > 0.0)
   {
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
      g_VolPercentile = (validCount >= 10) ? ((double)belowCount/validCount)*100.0 : 50.0;
   }

   //--- BB width percentile ---
   double upper[1], lower[1];
   if(CopyBuffer(g_hBB, 1, 0, 1, upper) > 0 && CopyBuffer(g_hBB, 2, 0, 1, lower) > 0)
   {
      double width = upper[0] - lower[0];
      int n = ArraySize(g_BBWidthHistory);
      for(int i = n-1; i > 0; i--) g_BBWidthHistory[i] = g_BBWidthHistory[i-1];
      g_BBWidthHistory[0] = width;

      int validCount = 0, belowCount = 0;
      for(int i = 1; i < n; i++)
      {
         if(g_BBWidthHistory[i] <= 0.0) continue;
         validCount++;
         if(g_BBWidthHistory[i] <= width) belowCount++;
      }
      g_BBWidthPercentile = (validCount >= 10) ? ((double)belowCount/validCount)*100.0 : 50.0;
   }

   //--- Displacement (bar-to-bar return) z-score ---
   double closeNow  = iClose(_Symbol, _Period, 1);
   double closePrev = iClose(_Symbol, _Period, 2);
   if(closePrev > 0.0)
   {
      double ret = (closeNow - closePrev) / closePrev;
      int n = ArraySize(g_ReturnHistory);
      for(int i = n-1; i > 0; i--) g_ReturnHistory[i] = g_ReturnHistory[i-1];
      g_ReturnHistory[0] = ret;

      double mean = 0.0; int cnt = 0;
      for(int i = 0; i < n; i++) { mean += g_ReturnHistory[i]; cnt++; }
      if(cnt > 0) mean /= cnt;

      double variance = 0.0;
      for(int i = 0; i < n; i++) variance += MathPow(g_ReturnHistory[i]-mean, 2);
      if(cnt > 1) variance /= (cnt-1);
      double stdev = MathSqrt(variance);

      g_DisplacementZ = (stdev > 0.0) ? (ret - mean) / stdev : 0.0;
   }

   //--- Volume z-score ---
   long vol[1];
   if(CopyTickVolume(_Symbol, _Period, 1, 1, vol) > 0)
   {
      double v = (double)vol[0];
      int n = ArraySize(g_VolumeHistoryArr);
      for(int i = n-1; i > 0; i--) g_VolumeHistoryArr[i] = g_VolumeHistoryArr[i-1];
      g_VolumeHistoryArr[0] = v;

      double mean = 0.0; int cnt = 0;
      for(int i = 0; i < n; i++) { mean += g_VolumeHistoryArr[i]; cnt++; }
      if(cnt > 0) mean /= cnt;

      double variance = 0.0;
      for(int i = 0; i < n; i++) variance += MathPow(g_VolumeHistoryArr[i]-mean, 2);
      if(cnt > 1) variance /= (cnt-1);
      double stdev = MathSqrt(variance);

      g_VolumeZ = (stdev > 0.0) ? (v - mean) / stdev : 0.0;
   }
}

//+------------------------------------------------------------------+
//| SHOCK / DISPLACEMENT DETECTOR                                     |
//| Internal statistical anomaly detector ONLY. This does not read   |
//| any news feed, calendar, or external API, and it does not claim  |
//| to know WHY price is moving abnormally - only THAT it is, based  |
//| on return and volume z-scores plus ATR percentile. Treat its     |
//| output as "the market is currently behaving abnormally" rather   |
//| than "a news event has occurred."                                |
//+------------------------------------------------------------------+
bool DetectShock()
{
   bool atrExtreme = (g_VolPercentile >= InpVolExtremePctile);
   bool retShock    = (MathAbs(g_DisplacementZ) >= InpShockZScoreThresh);
   bool volShock    = (g_VolumeZ >= InpShockVolZThresh);

   // Require displacement AND (extreme ATR OR volume confirmation) - a single
   // noisy return spike without volume/ATR backing is not treated as shock.
   return (retShock && (atrExtreme || volShock));
}

bool DetectBreakoutCandidate()
{
   // Expansion in BB width while ADX is rising from a low base, OR a clean
   // structure break beyond the recent swing extreme.
   double adx[1];
   if(CopyBuffer(g_hADX, 0, 0, 1, adx) <= 0) return false;

   bool expanding = (g_BBWidthPercentile >= InpBBExpansionPctile);

   int highBar = iHighest(_Symbol, _Period, MODE_HIGH, InpStructureBars, 1);
   int lowBar  = iLowest(_Symbol,  _Period, MODE_LOW,  InpStructureBars, 1);
   if(highBar < 0 || lowBar < 0) return false;
   double swingHigh = iHigh(_Symbol, _Period, highBar);
   double swingLow  = iLow(_Symbol,  _Period, lowBar);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   bool structureBreak = (ask > swingHigh) || (bid < swingLow);

   return (expanding && structureBreak);
}

bool DetectTrendCandidate()
{
   double adx[1];
   if(CopyBuffer(g_hADX, 0, 0, 1, adx) <= 0) return false;
   if(adx[0] < InpRegimeADXTrend) return false;

   double fast[1], slow[1], trend[1];
   if(CopyBuffer(g_hFastEMA, 0, 0, 1, fast)  <= 0) return false;
   if(CopyBuffer(g_hSlowEMA, 0, 0, 1, slow)  <= 0) return false;
   if(CopyBuffer(g_hTrendEMA,0, 0, 1, trend) <= 0) return false;

   bool bullStack = (fast[0] > slow[0] && slow[0] > trend[0]);
   bool bearStack = (fast[0] < slow[0] && slow[0] < trend[0]);
   return (bullStack || bearStack);
}

bool DetectCompressionCandidate()
{
   double adx[1];
   if(CopyBuffer(g_hADX, 0, 0, 1, adx) <= 0) return false;
   bool lowADX   = (adx[0] <= InpRegimeADXLow);
   bool tightBB  = (g_BBWidthPercentile <= InpBBSqueezePctile);
   return (lowADX && tightBB);
}

bool DetectSweepCandidate()
{
   // Liquidity sweep: price pokes beyond the recent swing extreme intrabar
   // then the most recent CLOSED candle rejects back inside it with a
   // pronounced wick - classic stop-hunt-then-reverse signature.
   int highBar = iHighest(_Symbol, _Period, MODE_HIGH, InpStructureBars, 2);
   int lowBar  = iLowest(_Symbol,  _Period, MODE_LOW,  InpStructureBars, 2);
   if(highBar < 0 || lowBar < 0) return false;

   double priorSwingHigh = iHigh(_Symbol, _Period, highBar);
   double priorSwingLow  = iLow(_Symbol,  _Period, lowBar);

   double openP  = iOpen(_Symbol, _Period, 1);
   double closeP = iClose(_Symbol, _Period, 1);
   double highP  = iHigh(_Symbol, _Period, 1);
   double lowP   = iLow(_Symbol, _Period, 1);
   double range  = highP - lowP;
   if(range <= 0.0) return false;

   bool sweptHigh = (highP > priorSwingHigh) && (closeP < priorSwingHigh);
   bool sweptLow  = (lowP  < priorSwingLow)  && (closeP > priorSwingLow);

   double upperWick = highP - MathMax(openP, closeP);
   double lowerWick = MathMin(openP, closeP) - lowP;

   bool rejectHigh = sweptHigh && (upperWick > range * 0.35);
   bool rejectLow  = sweptLow  && (lowerWick > range * 0.35);

   return (rejectHigh || rejectLow);
}

//+------------------------------------------------------------------+
//| REGIME CLASSIFIER - priority-ordered, mutually exclusive          |
//| Only ONE regime is active at a time, which gates exactly ONE     |
//| strategy module. Priority order matters: shock overrides every-  |
//| thing because trading a trend/range strategy through a violent   |
//| displacement event is precisely the failure mode this design     |
//| exists to prevent.                                                |
//+------------------------------------------------------------------+
ENUM_REGIME ClassifyRegime()
{
   if(DetectShock())               return REGIME_SHOCK;
   if(DetectBreakoutCandidate())   return REGIME_BREAKOUT;
   if(DetectTrendCandidate())      return REGIME_TRENDING;
   if(DetectCompressionCandidate())return REGIME_COMPRESSION;
   if(DetectSweepCandidate())      return REGIME_SWEEP;
   return REGIME_RANGING;
}

//+------------------------------------------------------------------+
//| SHARED SIGNAL HELPERS (used by multiple modules, regime-neutral) |
//+------------------------------------------------------------------+
bool CheckHTFTrend(ENUM_SIGNAL sig)
{
   double htf[1];
   if(CopyBuffer(g_hHTFEMA, 0, 0, 1, htf) <= 0) return false;
   double price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(sig == SIG_BUY)  return (price > htf[0]);
   if(sig == SIG_SELL) return (price < htf[0]);
   return false;
}

void UpdateVolumeAverage()
{
   static datetime lastVolBarTime = 0;
   datetime curBarTime = (datetime)SeriesInfoInteger(_Symbol, _Period, SERIES_LASTBAR_DATE);
   if(curBarTime == lastVolBarTime) return;
   lastVolBarTime = curBarTime;

   long vol[1];
   if(CopyTickVolume(_Symbol, _Period, 1, 1, vol) <= 0) return;

   int cap = InpVolumeAvgPeriod * 20;
   g_AvgVolume = (g_AvgVolume * g_VolumeSamples + (double)vol[0]) / (double)(g_VolumeSamples + 1);
   g_VolumeSamples = MathMin(g_VolumeSamples + 1, cap);
}

bool CheckVolumeSurge(double minMult)
{
   if(g_AvgVolume <= 0.0) return true; // insufficient data, don't block
   long vol[1];
   if(CopyTickVolume(_Symbol, _Period, 0, 1, vol) <= 0) return true;
   return ((double)vol[0] >= g_AvgVolume * minMult);
}

//+------------------------------------------------------------------+
//| ADAPTIVE REQUIRED CONFIDENCE PER REGIME                           |
//| Base requirement adjusted by that regime's OWN recent performance |
//| (self-optimising - a regime that's been losing for this account  |
//| on this market gets a higher bar; one performing well gets to    |
//| ease slightly toward base, never below it).                      |
//+------------------------------------------------------------------+
double GetRequiredConfidence(ENUM_REGIME regime)
{
   double req = g_RegimeStats[regime].dynamicThreshold;
   // Global loss-streak also nudges every regime's bar up slightly - the
   // account-wide circuit breaker layer, distinct from per-regime learning.
   if(g_ConsecLosses >= InpMaxLossStreak) req += 5.0;
   return MathMin(InpMaxConfidenceReq, MathMax(InpBaseConfidenceReq, req));
}

//+------------------------------------------------------------------+
//| STRATEGY A - TREND CONTINUATION  (owns REGIME_TRENDING)          |
//| Assumption: directional persistence continues after a shallow    |
//| pullback to the fast EMA. Contradicts mean-reversion logic by    |
//| design - this module never runs outside REGIME_TRENDING.         |
//| Weights: Structure 25 / Trend 25 / Momentum 20 / Volume 15 / HTF 15|
//+------------------------------------------------------------------+
ModuleResult Strategy_TrendContinuationsignal()
{
   ModuleResult r; r.sig = SIG_NONE; r.confidence = 0.0;

   double fast[1], slow[1], trend[1], rsi[1], adx[1];
   if(CopyBuffer(g_hFastEMA, 0,0,1,fast)<=0)  return r;
   if(CopyBuffer(g_hSlowEMA, 0,0,1,slow)<=0)  return r;
   if(CopyBuffer(g_hTrendEMA,0,0,1,trend)<=0) return r;
   if(CopyBuffer(g_hRSI,     0,0,1,rsi)<=0)   return r;
   if(CopyBuffer(g_hADX,     0,0,1,adx)<=0)   return r;

   bool bullStack = (fast[0] > slow[0] && slow[0] > trend[0]);
   bool bearStack = (fast[0] < slow[0] && slow[0] < trend[0]);
   if(!bullStack && !bearStack) return r;

   ENUM_SIGNAL sig = bullStack ? SIG_BUY : SIG_SELL;
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);

   double score = 0.0;

   // Trend alignment (25) - already required true to reach here, scale by ADX strength
   score += 25.0 * MathMin(1.0, adx[0] / (InpRegimeADXTrend * 1.5));

   // Structure (25) - pullback proximity to fast EMA without breaking slow EMA
   double pullbackDist = MathAbs(bid - fast[0]) / MathMax(1e-8, MathAbs(fast[0]-slow[0]));
   bool shallowPullback = (sig==SIG_BUY) ? (bid >= slow[0]) : (bid <= slow[0]);
   if(shallowPullback) score += 25.0 * MathMax(0.0, 1.0 - MathMin(1.0, pullbackDist));

   // Momentum (20) - RSI on the correct side of 50 but not exhausted
   bool rsiOk = (sig==SIG_BUY) ? (rsi[0] > 48.0 && rsi[0] < InpRSIOverbought)
                                 : (rsi[0] < 52.0 && rsi[0] > InpRSIOversold);
   if(rsiOk) score += 20.0;

   // Volume (15)
   if(CheckVolumeSurge(1.05)) score += 15.0;

   // HTF alignment (15)
   if(!InpUseHTFFilter || CheckHTFTrend(sig)) score += 15.0;

   r.sig = sig;
   r.confidence = score;
   return r;
}

//+------------------------------------------------------------------+
//| STRATEGY B - BREAKOUT MOMENTUM  (owns REGIME_BREAKOUT)            |
//| Assumption: structure break + expanding volatility continues in  |
//| breakout direction. Requires volume confirmation - the prior     |
//| system's biggest miss was treating a thin breakout the same as a |
//| volume-backed one.                                                |
//| Weights: Structure 30 / Volume 25 / Volatility 20 / Momentum 15 / |
//| Session 10                                                        |
//+------------------------------------------------------------------+
ModuleResult BreakoutMomentum_Strategy()
{
   ModuleResult r; r.sig = SIG_NONE; r.confidence = 0.0;

   int highBar = iHighest(_Symbol, _Period, MODE_HIGH, InpStructureBars, 1);
   int lowBar  = iLowest(_Symbol,  _Period, MODE_LOW,  InpStructureBars, 1);
   if(highBar < 0 || lowBar < 0) return r;

   double swingHigh = iHigh(_Symbol, _Period, highBar);
   double swingLow  = iLow(_Symbol,  _Period, lowBar);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);

   bool breakUp   = (ask > swingHigh);
   bool breakDown = (bid < swingLow);
   if(!breakUp && !breakDown) return r;

   ENUM_SIGNAL sig = breakUp ? SIG_BUY : SIG_SELL;
   double score = 0.0;

   // Structure (30) - magnitude of break relative to ATR
   double atr = GetATR();
   double breakDist = breakUp ? (ask - swingHigh) : (swingLow - bid);
   if(atr > 0.0) score += 30.0 * MathMin(1.0, breakDist / (atr*0.5));

   // Volume (25) - hard requirement region; weighted, not pass/fail, but
   // heavily penalised if absent since an unconfirmed breakout is the
   // classic false-breakout trap.
   if(CheckVolumeSurge(1.3)) score += 25.0;
   else score += 5.0;

   // Volatility expansion confirmation (20)
   score += 20.0 * MathMin(1.0, g_BBWidthPercentile / 100.0);

   // Momentum (15) - RSI direction agrees, not yet extreme
   double rsi[1];
   if(CopyBuffer(g_hRSI, 0, 0, 1, rsi) > 0)
   {
      bool rsiOk = (sig==SIG_BUY) ? (rsi[0] > 55.0 && rsi[0] < 85.0)
                                    : (rsi[0] < 45.0 && rsi[0] > 15.0);
      if(rsiOk) score += 15.0;
   }

   // Session/HTF alignment (10)
   if(!InpUseHTFFilter || CheckHTFTrend(sig)) score += 10.0;

   r.sig = sig;
   r.confidence = score;
   return r;
}

//+------------------------------------------------------------------+
//| STRATEGY C - PULLBACK / MEAN-REVERSION  (owns REGIME_RANGING)    |
//| Assumption: price fades back toward the mean in a low-ADX range. |
//| Directly contradicts trend-continuation logic by design - this   |
//| module never runs while REGIME_TRENDING or REGIME_BREAKOUT.      |
//| Weights: Structure(band position) 30 / Momentum(RSI extreme) 25 /|
//| Volatility(range-bound) 20 / Volume(low/normal) 15 / Session 10   |
//+------------------------------------------------------------------+
ModuleResult PullbackMeanReversion_Strategy()
{
   ModuleResult r; r.sig = SIG_NONE; r.confidence = 0.0;

   double upper[1], lower[1], mid[1], rsi[1], adx[1];
   if(CopyBuffer(g_hBB, 1,0,1,upper)<=0) return r;
   if(CopyBuffer(g_hBB, 2,0,1,lower)<=0) return r;
   if(CopyBuffer(g_hBB, 0,0,1,mid)  <=0) return r;
   if(CopyBuffer(g_hRSI,0,0,1,rsi)  <=0) return r;
   if(CopyBuffer(g_hADX,0,0,1,adx)  <=0) return r;

   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);

   bool nearUpper = (bid >= upper[0]*0.998);
   bool nearLower = (ask <= lower[0]*1.002);
   if(!nearUpper && !nearLower) return r;

   // Fade toward the mean: at upper band -> SELL, at lower band -> BUY
   ENUM_SIGNAL sig = nearUpper ? SIG_SELL : SIG_BUY;
   double score = 0.0;

   // Structure - position within the band (30)
   double bandWidth = MathMax(1e-8, upper[0]-lower[0]);
   double posInBand = nearUpper ? (bid-mid[0])/bandWidth : (mid[0]-ask)/bandWidth;
   score += 30.0 * MathMax(0.0, MathMin(1.0, posInBand*2.0));

   // Momentum - RSI extreme in the corresponding direction (25)
   bool rsiExtreme = (sig==SIG_SELL) ? (rsi[0] >= InpRSIOverbought)
                                       : (rsi[0] <= InpRSIOversold);
   if(rsiExtreme) score += 25.0;
   else score += 25.0 * MathMax(0.0, 1.0 - MathAbs(rsi[0]-50.0)/30.0);

   // Volatility - genuinely range-bound, not secretly trending (20)
   score += 20.0 * MathMax(0.0, 1.0 - (adx[0]/InpRegimeADXTrend));

   // Volume - mean reversion works best WITHOUT a volume surge (surge would
   // suggest a genuine breakout attempt, not a fade) (15)
   if(!CheckVolumeSurge(1.3)) score += 15.0;

   // Session - avoid fading during weekend thin liquidity gaps (10)
   if(!InpAvoidWeekendOpen || !IsWeekendPauseActive()) score += 10.0;

   r.sig = sig;
   r.confidence = score;
   return r;
}

//+------------------------------------------------------------------+
//| STRATEGY D - VOLATILITY EXPANSION  (owns REGIME_SHOCK)            |
//| Assumption: a statistically abnormal displacement event tends to |
//| continue briefly in its initial direction before mean-reverting. |
//| Trades WITH the shock direction, reduced size (handled in risk    |
//| engine), fast partial-take (handled in exit engine).              |
//| Weights: Displacement 30 / Volume 25 / Volatility 20 / Momentum 15|
//| / Structure 10                                                    |
//+------------------------------------------------------------------+
ModuleResult VolatilityExpansion_Strategy()
{
   ModuleResult r; r.sig = SIG_NONE; r.confidence = 0.0;

   // No internal latch here by design - g_CurrentRegime is recomputed fresh
   // every tick by ClassifyRegime(), and the OnTick() router only calls this
   // module when that fresh classification is REGIME_SHOCK. A persistent
   // "shock active" flag inside the module itself would go stale the moment
   // the underlying displacement/volume conditions normalise, since nothing
   // resets it until a trade opens and closes - re-deriving it fresh here
   // instead keeps this module honest tick to tick.
   if(!DetectShock()) return r;
   g_ShockActive = true; // dashboard display flag only, not used for gating logic

   ENUM_SIGNAL sig = (g_DisplacementZ > 0) ? SIG_BUY : SIG_SELL;
   double score = 0.0;

   // Displacement magnitude (30)
   score += 30.0 * MathMin(1.0, MathAbs(g_DisplacementZ) / (InpShockZScoreThresh*2.0));

   // Volume confirmation (25)
   score += 25.0 * MathMin(1.0, MathMax(0.0, g_VolumeZ) / (InpShockVolZThresh*2.0));

   // Volatility / ATR percentile (20)
   score += 20.0 * MathMin(1.0, g_VolPercentile/100.0);

   // Momentum continuation - RSI not already maxed against the shock dir (15)
   double rsi[1];
   if(CopyBuffer(g_hRSI, 0, 0, 1, rsi) > 0)
   {
      bool notExhausted = (sig==SIG_BUY) ? (rsi[0] < 88.0) : (rsi[0] > 12.0);
      if(notExhausted) score += 15.0;
   }

   // Structure - not trading directly into an opposing untested swing level (10)
   int highBar = iHighest(_Symbol, _Period, MODE_HIGH, InpStructureBars, 1);
   int lowBar  = iLowest(_Symbol,  _Period, MODE_LOW,  InpStructureBars, 1);
   if(highBar >= 0 && lowBar >= 0)
   {
      double swingHigh = iHigh(_Symbol, _Period, highBar);
      double swingLow  = iLow(_Symbol,  _Period, lowBar);
      double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      bool clearRoom = (sig==SIG_BUY) ? (bid < swingHigh*1.02) || (bid>swingHigh)
                                        : (bid > swingLow*0.98)  || (bid<swingLow);
      if(clearRoom) score += 10.0;
   }

   r.sig = sig;
   r.confidence = score;
   return r;
}

//+------------------------------------------------------------------+
//| STRATEGY E - LIQUIDITY SWEEP REVERSAL  (owns REGIME_SWEEP)        |
//| Assumption: a stop-hunt beyond a swing extreme that immediately   |
//| rejects back inside range is a reversal signal, trading AGAINST   |
//| the sweep direction. Mean-reversion flavoured but distinct from   |
//| Strategy C - this fires on a single sharp rejection wick rather   |
//| than generic band-extreme positioning.                            |
//| Weights: Wick rejection 30 / Structure context 25 / Momentum 20 / |
//| Volume 15 / Volatility 10                                         |
//+------------------------------------------------------------------+
ModuleResult LiquiditySweepReversal_Strategy()
{
   ModuleResult r; r.sig = SIG_NONE; r.confidence = 0.0;

   int highBar = iHighest(_Symbol, _Period, MODE_HIGH, InpStructureBars, 2);
   int lowBar  = iLowest(_Symbol,  _Period, MODE_LOW,  InpStructureBars, 2);
   if(highBar < 0 || lowBar < 0) return r;

   double priorSwingHigh = iHigh(_Symbol, _Period, highBar);
   double priorSwingLow  = iLow(_Symbol,  _Period, lowBar);

   double openP  = iOpen(_Symbol, _Period, 1);
   double closeP = iClose(_Symbol, _Period, 1);
   double highP  = iHigh(_Symbol, _Period, 1);
   double lowP   = iLow(_Symbol, _Period, 1);
   double range  = highP - lowP;
   if(range <= 0.0) return r;

   bool sweptHigh = (highP > priorSwingHigh) && (closeP < priorSwingHigh);
   bool sweptLow  = (lowP  < priorSwingLow)  && (closeP > priorSwingLow);

   double upperWick = highP - MathMax(openP, closeP);
   double lowerWick = MathMin(openP, closeP) - lowP;

   bool rejectHigh = sweptHigh && (upperWick > range*0.35);
   bool rejectLow  = sweptLow  && (lowerWick > range*0.35);
   if(!rejectHigh && !rejectLow) return r;

   // Trade AGAINST the sweep: swept high & rejected -> SELL; swept low & rejected -> BUY
   ENUM_SIGNAL sig = rejectHigh ? SIG_SELL : SIG_BUY;
   double score = 0.0;

   // Wick rejection strength (30)
   double wickRatio = rejectHigh ? (upperWick/range) : (lowerWick/range);
   score += 30.0 * MathMin(1.0, wickRatio / 0.6);

   // Structure context - how far beyond the swing extreme it poked (25)
   double sweepDist = rejectHigh ? (highP-priorSwingHigh) : (priorSwingLow-lowP);
   double atr = GetATR();
   if(atr > 0.0) score += 25.0 * MathMin(1.0, sweepDist/(atr*0.4));

   // Momentum - RSI was extreme into the sweep (20)
   double rsi[1];
   if(CopyBuffer(g_hRSI, 0, 0, 1, rsi) > 0)
   {
      bool rsiExtreme = rejectHigh ? (rsi[0] > 65.0) : (rsi[0] < 35.0);
      if(rsiExtreme) score += 20.0;
   }

   // Volume - sweeps with a volume spike (stop cascade) are more reliable (15)
   if(CheckVolumeSurge(1.2)) score += 15.0;

   // Volatility - avoid trading sweep reversals inside a SHOCK-level move (10)
   if(g_VolPercentile < InpVolExtremePctile) score += 10.0;

   r.sig = sig;
   r.confidence = score;
   return r;
}

//+------------------------------------------------------------------+
//| STRATEGY H - COMPRESSION BREAKOUT  (owns REGIME_COMPRESSION)      |
//| Assumption: a tight squeeze (low ADX + low BB width) is about to  |
//| release; takes a SMALL anticipatory position toward the side the  |
//| price is currently pressing against the band, with tighter        |
//| invalidation (handled by SL sizing in the risk engine via the     |
//| regime parameter). Distinct from Strategy B - this fires BEFORE   |
//| the structural break confirms, on band-edge pressure only.        |
//| Weights: Squeeze depth 30 / Band-edge pressure 25 / Momentum 20 / |
//| Volume building 15 / Volatility floor 10                          |
//+------------------------------------------------------------------+
ModuleResult CompressionBreakout_Strategy()
{
   ModuleResult r; r.sig = SIG_NONE; r.confidence = 0.0;

   double upper[1], lower[1], mid[1], rsi[1];
   if(CopyBuffer(g_hBB,1,0,1,upper)<=0) return r;
   if(CopyBuffer(g_hBB,2,0,1,lower)<=0) return r;
   if(CopyBuffer(g_hBB,0,0,1,mid)  <=0) return r;
   if(CopyBuffer(g_hRSI,0,0,1,rsi) <=0) return r;

   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);

   double bandWidth = MathMax(1e-8, upper[0]-lower[0]);
   double pressureUpper = (bid - mid[0]) / bandWidth; // 0..0.5+ toward upper
   double pressureLower = (mid[0] - ask) / bandWidth;

   bool pressingUpper = (pressureUpper > 0.30);
   bool pressingLower = (pressureLower > 0.30);
   if(!pressingUpper && !pressingLower) return r;

   ENUM_SIGNAL sig = pressingUpper ? SIG_BUY : SIG_SELL;
   double score = 0.0;

   // Squeeze depth - tighter squeeze = higher conviction the release is near (30)
   score += 30.0 * MathMax(0.0, 1.0 - (g_BBWidthPercentile/InpBBSqueezePctile));

   // Band-edge pressure magnitude (25)
   double pressure = pressingUpper ? pressureUpper : pressureLower;
   score += 25.0 * MathMin(1.0, pressure / 0.6);

   // Momentum building in the press direction (20)
   bool rsiOk = (sig==SIG_BUY) ? (rsi[0] > 50.0) : (rsi[0] < 50.0);
   if(rsiOk) score += 20.0;

   // Volume building ahead of release (15)
   if(CheckVolumeSurge(1.1)) score += 15.0;

   // Volatility floor - confirm we are not already breaking out (would be
   // Strategy B's job, not this one) (10)
   if(g_BBWidthPercentile <= InpBBExpansionPctile) score += 10.0;

   r.sig = sig;
   r.confidence = score;
   return r;
}

//+------------------------------------------------------------------+
//| ADAPTIVE RISK ENGINE                                              |
//| Lot size is ALWAYS derived from (balance x risk%) / (actual SL    |
//| distance in dollars for 1.0 lot). This formula is scale-invariant |
//| by construction - it produces correctly small lots on a $50      |
//| account and correctly larger lots on a $50,000 account without   |
//| any account-size branching, because both numerator and the       |
//| resulting lot size move proportionally with balance.              |
//+------------------------------------------------------------------+
double GetRiskAdjustedPercent(ENUM_REGIME regime)
{
   double pct = InpBaseRiskPercent;

   // Loss-streak / win-streak adjustment (global, account behaviour)
   if(g_ConsecLosses >= InpMaxLossStreak)
      pct = InpBaseRiskPercent * 0.5;
   else if(g_ConsecWins >= InpWinStreakBoost)
      pct = MathMin(InpBaseRiskPercent * 1.25, InpMaxRiskPercent);

   // Equity-curve drawdown scaling - deeper drawdown from all-time peak
   // shrinks every subsequent trade, compounding with streak sizing above
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   if(g_EquityPeak > 0.0)
   {
      double ddPct = ((g_EquityPeak - equity) / g_EquityPeak) * 100.0;
      if(ddPct >= InpRecoveryDDPct) pct *= 0.5;       // recovery mode - half size
      else if(ddPct > InpRecoveryDDPct*0.5) pct *= 0.75;
   }

   // Regime-specific de-risking: SHOCK and COMPRESSION trades are inherently
   // lower-confidence bets on continuation/anticipation - cut size further
   // regardless of global streak state.
   if(regime == REGIME_SHOCK)       pct *= 0.6;
   if(regime == REGIME_COMPRESSION) pct *= 0.7;

   return MathMax(InpMinRiskPercent, MathMin(InpMaxRiskPercent, pct));
}

//--- Returns true if the broker's minimum lot, at this SL distance, does not
//    risk more than InpMaxAffordRiskMult x the account's target risk amount.
//    This is the explicit small-account guard: on a genuinely tiny account
//    where even the minimum lot would blow past the intended risk, the EA
//    skips the trade rather than silently over-risking the account.
bool IsAffordable(double slDistancePrice, double lot)
{
   if(!InpSkipIfUnaffordable) return true;

   double balance   = AccountInfoDouble(ACCOUNT_BALANCE);
   double tickVal   = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double tickSize  = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   if(tickSize <= 0.0 || balance <= 0.0) return true; // can't evaluate, don't block

   double minLotRiskUSD = (slDistancePrice / tickSize) * tickVal * lot;
   double targetRiskUSD = balance * (InpBaseRiskPercent / 100.0);

   return (minLotRiskUSD <= targetRiskUSD * InpMaxAffordRiskMult);
}

double CalculateLotSize(double slDistancePrice, ENUM_REGIME regime)
{
   double balance    = AccountInfoDouble(ACCOUNT_BALANCE);
   double riskPct     = GetRiskAdjustedPercent(regime);
   double riskAmount  = balance * (riskPct / 100.0);

   double tickVal  = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   double minV     = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxV     = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double step      = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);

   if(tickSize <= 0.0 || slDistancePrice <= 0.0) return minV;

   double slCostPerLot = (slDistancePrice / tickSize) * tickVal;
   if(slCostPerLot <= 0.0) return minV;

   double lot = riskAmount / slCostPerLot;
   lot = MathMax(minV, MathMin(maxV, MathFloor(lot/step)*step));

   // If the floor/min-lot clamp pushed the lot above what the risk%
   // actually justifies, IsAffordable() (checked by the caller before
   // ExecuteEntry commits) will catch and skip on genuinely tiny accounts.
   return lot;
}

//+------------------------------------------------------------------+
//| TRADE EXECUTION                                                    |
//+------------------------------------------------------------------+
void ExecuteEntry(ENUM_SIGNAL sig, ENUM_STRAT_MODULE module, ENUM_REGIME regime, double confidence)
{
   if(!IsSpreadOk()) { Print("[NovaTitanX] Spread too wide at execution - aborted."); return; }

   int    digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   double atr    = GetATR();
   if(atr <= 0.0) { Print("[NovaTitanX] ATR unavailable at execution - aborted."); return; }

   double price = (sig == SIG_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                     : SymbolInfoDouble(_Symbol, SYMBOL_BID);

   // SL distance: ATR-based, bounded by % of price floor/ceiling - robust
   // across BTC price levels and regimes. Compression regime gets a tighter
   // multiplier (smaller anticipatory bets need tighter invalidation).
   double slMult = InpSLMultiplier;
   if(regime == REGIME_COMPRESSION) slMult *= 0.75;
   if(regime == REGIME_SHOCK)        slMult *= 1.15; // shock moves need a bit more room

   double slDistATR = atr * slMult;
   double minSLDist  = price * (InpMinSLPercent/100.0);
   double maxSLDist  = price * (InpMaxSLPercent/100.0);
   double slDistance = MathMax(minSLDist, MathMin(maxSLDist, slDistATR));

   double tp2Distance = atr * InpTP2Multiplier;

   double sl, tp;
   if(sig == SIG_BUY)
   {
      sl = NormalizeDouble(price - slDistance,  digits);
      tp = NormalizeDouble(price + tp2Distance, digits);
   }
   else
   {
      sl = NormalizeDouble(price + slDistance,  digits);
      tp = NormalizeDouble(price - tp2Distance, digits);
   }

   double lot = CalculateLotSize(slDistance, regime);

   if(!IsAffordable(slDistance, lot))
   {
      Print("[NovaTitanX] Trade skipped - minimum broker lot would exceed affordable risk on this account size.");
      g_StateTimer = TimeCurrent() + 15;
      g_State      = ENGINE_COOLDOWN;
      return;
   }

   PrintFormat("[NovaTitanX] ENTRY %s | Module=%s Regime=%s Conf=%.1f Lot=%.2f Price=%.2f SL=%.2f TP=%.2f SLdist=$%.2f ATR=%.2f",
               (sig==SIG_BUY?"BUY":"SELL"), ModuleToString(module), RegimeToString(regime), confidence,
               lot, price, sl, tp, slDistance, atr);

   bool ok = (sig == SIG_BUY) ? g_Trade.Buy(lot, _Symbol, price, sl, tp, InpTradeComment)
                                : g_Trade.Sell(lot, _Symbol, price, sl, tp, InpTradeComment);
   if(ok)
   {
      g_DailyTrades++;
      ResetTradeState();
      Sleep(100);
      CacheTradeEntry(module, regime);
      g_StatusText  = (sig==SIG_BUY) ? "IN TRADE - LONG" : "IN TRADE - SHORT";
      g_StatusColor = C_GREEN;
   }
   else
   {
      Print("[NovaTitanX] Order FAILED. RetCode=", g_Trade.ResultRetcode(), " ", g_Trade.ResultRetcodeDescription());
   }
}

//+------------------------------------------------------------------+
//| TRADE LIFECYCLE CACHE                                             |
//+------------------------------------------------------------------+
void CacheTradeEntry(ENUM_STRAT_MODULE module, ENUM_REGIME regime)
{
   for(int i = PositionsTotal()-1; i >= 0; i--)
   {
      if(!g_Pos.SelectByIndex(i)) continue;
      if(g_Pos.Magic()!=InpMagicNumber || g_Pos.Symbol()!=_Symbol) continue;

      g_EntryPrice     = g_Pos.PriceOpen();
      g_EntrySLPrice   = g_Pos.StopLoss();
      g_EntryATR       = GetATR();
      g_TradeDirection = (g_Pos.PositionType()==POSITION_TYPE_BUY) ? 1 : -1;
      g_PeakProfit     = 0.0;
      g_BESet          = false;
      g_PartialClosed  = false;
      g_OpenModule     = module;
      g_OpenRegime     = regime;
      g_EntryBarTime   = (datetime)SeriesInfoInteger(_Symbol, _Period, SERIES_LASTBAR_DATE);
      g_EntryBarsElapsed = 0;
      g_DeteriorationTightened = false;

      double slDistPrice = MathAbs(g_EntryPrice - g_EntrySLPrice);
      double tickVal  = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
      double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
      if(tickSize > 0.0)
         g_EntryRiskUSD = (slDistPrice / tickSize) * tickVal * g_Pos.Volume();
      else
         g_EntryRiskUSD = 0.01;
      if(g_EntryRiskUSD <= 0.0) g_EntryRiskUSD = 0.01;

      PrintFormat("[CacheEntry] Module=%s Regime=%s Entry=%.2f SL=%.2f SLdist=$%.2f Risk(1R)=$%.2f",
                  ModuleToString(module), RegimeToString(regime), g_EntryPrice, g_EntrySLPrice, slDistPrice, g_EntryRiskUSD);
      break;
   }
}

void ResetTradeState()
{
   g_PeakProfit        = 0.0;
   g_PartialClosePrice = 0.0;
   g_BESet              = false;
   g_PartialClosed      = false;
   g_EntryATR          = 0.0;
   g_EntryPrice        = 0.0;
   g_EntrySLPrice      = 0.0;
   g_EntryRiskUSD      = 0.0;
   g_TradeDirection    = 0;
   g_EntryBarTime      = 0;
   g_EntryBarsElapsed  = 0;
   g_OpenModule        = STRAT_NONE;
   g_DeteriorationTightened = false;
   g_ShockActive       = false;
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

//--- This is the single reliable recording point for every EXPLICIT close
//    path (peak-lock, partial-close fallback, daily-target). It records from
//    realized deal history BEFORE resetting trade state, since ResetTradeState()
//    clears the cached regime/risk context that the recorder needs. SL/TP hits
//    that the EA did not explicitly request go through the equivalent check in
//    ManageOpenTrade()'s top-of-function IsPositionOpen() branch instead, which
//    follows the same record-before-reset order for that path.
void CloseAllPositions(string reason)
{
   PrintFormat("[NovaTitanX] CloseAll: %s | Peak was $%.2f", reason, g_PeakProfit);
   for(int i = PositionsTotal()-1; i >= 0; i--)
      if(g_Pos.SelectByIndex(i) && g_Pos.Magic()==InpMagicNumber && g_Pos.Symbol()==_Symbol)
         g_Trade.PositionClose(g_Pos.Ticket());
   RecordClosedTradeFromHistory();
   g_EntryRiskUSD = 0.0; // guards against double-recording on next tick's ManageOpenTrade() check
   g_StateTimer = TimeCurrent() + 20;
   g_State      = ENGINE_COOLDOWN;
   ResetTradeState();
}

//+------------------------------------------------------------------+
//| MASTER TRADE MANAGER                                              |
//+------------------------------------------------------------------+
void ManageOpenTrade()
{
   if(!IsPositionOpen())
   {
      // Position closed since last tick (SL hit, TP hit, manual close, or one
      // of our own explicit closes already handled below) - record it exactly
      // once here rather than depending on every exit path remembering to call
      // RecordClosedTrade() itself, which is fragile and was previously
      // double-counting on some paths and missing broker-side SL/TP hits entirely.
      RecordClosedTradeFromHistory();
      ResetTradeState();
      return;
   }

   double pnl = GetFloatingPnL();
   if(pnl > g_PeakProfit) g_PeakProfit = pnl;

   datetime curBarTime = (datetime)SeriesInfoInteger(_Symbol, _Period, SERIES_LASTBAR_DATE);
   if(curBarTime != g_EntryBarTime)
   {
      // count distinct closed bars since entry (approx via period seconds)
      int periodSec = PeriodSeconds(_Period);
      if(periodSec > 0) g_EntryBarsElapsed = (int)((curBarTime - g_EntryBarTime) / periodSec);
   }

   string rStr = (g_EntryRiskUSD > 0) ? " ("+DoubleToString(pnl/g_EntryRiskUSD,2)+"R)" : "";
   g_StatusText  = "TRADE [" + ModuleToString(g_OpenModule) + "] " + (pnl>=0?"+$":"-$") +
                    DoubleToString(MathAbs(pnl),2) + rStr + " Pk:+$" + DoubleToString(g_PeakProfit,2);
   g_StatusColor = (pnl >= 0) ? C_GREEN : C_RED;

   if(InpUsePeakLock) CheckPeakProfitLock(pnl);
   if(!IsPositionOpen()) return;

   if(InpUsePartialClose && !g_PartialClosed) CheckPartialClose(pnl);
   if(!IsPositionOpen()) return;

   CheckBreakeven();
   if(!IsPositionOpen()) return;

   if(InpUseTrailing) CheckATRTrailing();
   if(!IsPositionOpen()) return;

   CheckTimeDeterioration();
   if(!IsPositionOpen()) return;

   EvaluateFloatingPnL(pnl);
}

//+------------------------------------------------------------------+
//| PEAK-PROFIT LOCK (R-multiple based)                               |
//+------------------------------------------------------------------+
void CheckPeakProfitLock(double pnl)
{
   double oneR = g_EntryRiskUSD;
   if(oneR <= 0.0) return;

   double activateLevel = oneR * InpPeakLockActivateR;
   if(g_PeakProfit < activateLevel) return;

   double retraceLevel = g_PeakProfit * (1.0 - InpPeakLockRetrace/100.0);
   double minRFloor      = oneR * InpMinRewardRiskR;
   double lockLevel       = MathMax(retraceLevel, minRFloor);
   if(g_PartialClosed) lockLevel = MathMax(lockLevel, oneR * InpMinLockProfitR);

   if(pnl <= lockLevel && pnl < g_PeakProfit)
   {
      PrintFormat("[PeakLock] Triggered. 1R=$%.2f Peak=$%.2f(%.2fR) Lock=$%.2f(%.2fR) Current=$%.2f",
                  oneR, g_PeakProfit, g_PeakProfit/oneR, lockLevel, lockLevel/oneR, pnl);
      CloseAllPositions("Peak-profit lock triggered");
   }
}

//+------------------------------------------------------------------+
//| PARTIAL CLOSE AT TP1                                              |
//+------------------------------------------------------------------+
void CheckPartialClose(double pnl)
{
   double oneR = g_EntryRiskUSD;
   if(oneR <= 0.0) return;

   // Shock-regime trades take partials faster - fast moves often snap back
   double tp1R = (g_OpenRegime == REGIME_SHOCK) ? InpTP1R * 0.6 : InpTP1R;
   double tp1Level = oneR * tp1R;
   if(pnl < tp1Level) return;

   for(int i = PositionsTotal()-1; i >= 0; i--)
   {
      if(!g_Pos.SelectByIndex(i)) continue;
      if(g_Pos.Magic()!=InpMagicNumber || g_Pos.Symbol()!=_Symbol) continue;

      double volStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
      double minLot  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
      double closeLot = MathFloor((g_Pos.Volume()*(InpPartialClosePct/100.0))/volStep)*volStep;
      closeLot = NormalizeDouble(closeLot, 2);

      if(closeLot < minLot)
      {
         PrintFormat("[PartialClose] Lot %.2f below min %.2f - closing full position", closeLot, minLot);
         CloseAllPositions("TP1 full close (lot too small to partial)");
         return;
      }

      if(g_Trade.PositionClosePartial(g_Pos.Ticket(), closeLot))
      {
         g_PartialClosed = true;
         PrintFormat("[PartialClose] %.2f lots closed. 1R=$%.2f Profit=$%.2f (%.2fR)", closeLot, oneR, pnl, pnl/oneR);
      }
   }
}

//+------------------------------------------------------------------+
//| BREAKEVEN                                                          |
//+------------------------------------------------------------------+
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

      double open   = g_Pos.PriceOpen();
      double sl     = g_Pos.StopLoss();
      int    digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
      bool   isBuy  = (g_Pos.PositionType()==POSITION_TYPE_BUY);
      double buffer = open * (InpBEBufferPercent/100.0);

      double beSL = isBuy ? NormalizeDouble(open+buffer, digits) : NormalizeDouble(open-buffer, digits);
      bool needsMove = isBuy ? (sl < beSL) : (sl > beSL || sl == 0.0);

      if(needsMove && g_Trade.PositionModify(g_Pos.Ticket(), beSL, g_Pos.TakeProfit()))
      {
         g_BESet = true;
         PrintFormat("[Breakeven] SL moved to %.2f at profit $%.2f (%.2fR)", beSL, pnl, pnl/oneR);
      }
   }
}

//+------------------------------------------------------------------+
//| ATR TRAILING STOP                                                  |
//+------------------------------------------------------------------+
void CheckATRTrailing()
{
   double oneR = g_EntryRiskUSD;
   if(oneR <= 0.0) return;

   double pnl = GetFloatingPnL();
   double trailStartR = g_DeteriorationTightened ? InpTrailStartR * 0.5 : InpTrailStartR;
   if(pnl < oneR * trailStartR) return;

   double atr = (g_EntryATR > 0) ? g_EntryATR : GetATR();
   if(atr <= 0) return;

   double trailMult = InpTrailATRMult;
   if(g_OpenRegime == REGIME_SHOCK) trailMult *= 0.7;          // tighter trail in fast moves
   if(g_DeteriorationTightened)      trailMult *= 0.6;          // tighter if trade is stalling

   double trailDist = atr * trailMult;

   for(int i = PositionsTotal()-1; i >= 0; i--)
   {
      if(!g_Pos.SelectByIndex(i)) continue;
      if(g_Pos.Magic()!=InpMagicNumber || g_Pos.Symbol()!=_Symbol) continue;

      double open   = g_Pos.PriceOpen();
      double sl     = g_Pos.StopLoss();
      double bid    = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      double ask    = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      int    digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
      bool   isBuy  = (g_Pos.PositionType()==POSITION_TYPE_BUY);

      double newSL = isBuy ? NormalizeDouble(bid-trailDist, digits) : NormalizeDouble(ask+trailDist, digits);

      if(g_BESet)
      {
         double buffer  = open * (InpBEBufferPercent/100.0);
         double beFloor = isBuy ? NormalizeDouble(open+buffer, digits) : NormalizeDouble(open-buffer, digits);
         if(isBuy) newSL = MathMax(newSL, beFloor); else newSL = MathMin(newSL, beFloor);
      }

      bool improves = isBuy ? (newSL > sl && newSL < bid)
                              : ((sl==0.0) ? (newSL > ask) : (newSL < sl && newSL > ask));

      if(improves) g_Trade.PositionModify(g_Pos.Ticket(), newSL, g_Pos.TakeProfit());
   }
}

//+------------------------------------------------------------------+
//| TIME-BASED DETERIORATION EXIT                                     |
//| If a trade has not reached InpDeteriorationR within InpMaxBars-   |
//| ToTarget bars, it is treated as stalling - tightens the trail and |
//| breakeven trigger (handled by the flag above) rather than forcing |
//| an immediate close, since a hard time-stop on a still-valid setup |
//| would discard genuine slow-developing trends.                     |
//+------------------------------------------------------------------+
void CheckTimeDeterioration()
{
   if(g_DeteriorationTightened) return;
   if(g_EntryBarsElapsed < InpMaxBarsToTarget) return;

   double oneR = g_EntryRiskUSD;
   if(oneR <= 0.0) return;
   double pnl = GetFloatingPnL();

   if(pnl < oneR * InpDeteriorationR)
   {
      g_DeteriorationTightened = true;
      Print("[NovaTitanX] Time-deterioration: trade has not progressed within window - tightening exits.");
   }
}

//+------------------------------------------------------------------+
//| DAILY PROFIT TARGET VIA FLOATING PNL                              |
//+------------------------------------------------------------------+
void EvaluateFloatingPnL(double pnl)
{
   double balance   = AccountInfoDouble(ACCOUNT_BALANCE);
   double dailyGoal = balance * (InpMaxDailyProfitPct/100.0);
   double remaining = dailyGoal - g_DailyProfit;
   if(remaining > 0.0 && pnl >= remaining)
   {
      CloseAllPositions("Daily profit target reached");
      g_State = ENGINE_HALTED_DAILY; // override the COOLDOWN state CloseAllPositions just set
   }
}

//+------------------------------------------------------------------+
//| PER-REGIME PERFORMANCE RECORDING (self-optimising threshold)      |
//| Called from ManageOpenTrade() the tick AFTER our tracked position  |
//| is detected as closed - covers SL hits, TP hits, manual closes,   |
//| and our own explicit CloseAllPositions() calls uniformly, since   |
//| all of them are read back from realized deal history rather than  |
//| relying on every single exit code path remembering to self-report.|
//| Sums every closing deal since entry (captures partial closes too).|
//+------------------------------------------------------------------+
void RecordClosedTradeFromHistory()
{
   if(g_EntryRiskUSD <= 0.0 || g_EntryBarTime == 0) return; // nothing was cached, nothing to record

   datetime scanFrom = g_EntryBarTime - PeriodSeconds(_Period); // small safety margin before entry
   if(!HistorySelect(scanFrom, TimeCurrent())) return;

   double realizedPnl = 0.0;
   bool   foundAny    = false;

   for(int i = 0; i < HistoryDealsTotal(); i++)
   {
      ulong tkt = HistoryDealGetTicket(i);
      if(tkt == 0) continue;
      if(HistoryDealGetInteger(tkt, DEAL_MAGIC)  != (long)InpMagicNumber) continue;
      if(HistoryDealGetString(tkt,  DEAL_SYMBOL) != _Symbol) continue;
      if(HistoryDealGetInteger(tkt, DEAL_ENTRY)  != DEAL_ENTRY_OUT) continue;

      datetime dealTime = (datetime)HistoryDealGetInteger(tkt, DEAL_TIME);
      if(dealTime < g_EntryBarTime) continue; // belongs to a previous trade cycle

      realizedPnl += HistoryDealGetDouble(tkt, DEAL_PROFIT)
                   + HistoryDealGetDouble(tkt, DEAL_COMMISSION)
                   + HistoryDealGetDouble(tkt, DEAL_SWAP);
      foundAny = true;
   }

   if(!foundAny) return; // nothing closed yet under this entry timestamp - don't record a phantom trade

   double rMultiple = realizedPnl / g_EntryRiskUSD;
   ENUM_REGIME regime = g_OpenRegime;

   g_RegimeStats[regime].trades++;
   g_RegimeStats[regime].sumR += rMultiple;
   if(realizedPnl >= 0.0) { g_RegimeStats[regime].wins++;   g_RegimeStats[regime].grossProfit += realizedPnl; }
   else                    { g_RegimeStats[regime].losses++; g_RegimeStats[regime].grossLoss   += MathAbs(realizedPnl); }

   int idx = g_RegimeStats[regime].ring10Idx % 10;
   g_RegimeStats[regime].last10[idx] = (realizedPnl >= 0.0) ? 1 : 0;
   g_RegimeStats[regime].ring10Idx++;

   int wins10 = 0, total10 = 0;
   for(int j = 0; j < 10; j++)
   {
      if(g_RegimeStats[regime].last10[j] < 0) continue;
      total10++;
      if(g_RegimeStats[regime].last10[j] == 1) wins10++;
   }
   double winRate10 = (total10 > 0) ? ((double)wins10/total10)*100.0 : 50.0;

   double cur = g_RegimeStats[regime].dynamicThreshold;
   if(total10 >= 4)
   {
      if(winRate10 < 40.0)       cur = MathMin(InpMaxConfidenceReq, cur + 4.0);
      else if(winRate10 < 50.0)  cur = MathMin(InpMaxConfidenceReq, cur + 2.0);
      else if(winRate10 >= 65.0) cur = MathMax(InpBaseConfidenceReq, cur - 2.0);
   }
   g_RegimeStats[regime].dynamicThreshold = cur;

   PrintFormat("[RegimeStats] %s closed trade recorded. PnL=$%.2f (%.2fR) Regime trades=%d winRate10=%.0f%% newThreshold=%.1f",
               RegimeToString(regime), realizedPnl, rMultiple, g_RegimeStats[regime].trades, winRate10, cur);
}

//+------------------------------------------------------------------+
//| MARKET / SPREAD / LIMIT UTILITY FUNCTIONS                         |
//+------------------------------------------------------------------+
bool IsMarketOpen()
{
   ENUM_SYMBOL_TRADE_MODE m = (ENUM_SYMBOL_TRADE_MODE)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_MODE);
   return (m == SYMBOL_TRADE_MODE_FULL || m == SYMBOL_TRADE_MODE_LONGONLY || m == SYMBOL_TRADE_MODE_SHORTONLY);
}

//--- Percentage-based spread filter: correct across BTC price levels, where
//    a fixed-point ceiling has no consistent meaning ($20 spread is tight at
//    $100k BTC, enormous at $10k BTC).
bool IsSpreadOk()
{
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(bid <= 0.0) return false;
   double spread = ask - bid;
   double spreadPct = (spread/bid) * 100.0;

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
   g_AvgSpread = (g_AvgSpread * g_SpreadSamples + spread) / (double)(g_SpreadSamples+1);
   g_SpreadSamples = MathMin(g_SpreadSamples+1, cap);
}

bool IsDailyLossLimitHit()
{
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double limit   = balance * (InpMaxDailyLossPct/100.0);
   return (g_DailyProfit <= -MathAbs(limit));
}

bool IsWeeklyLossLimitHit()
{
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double limit   = balance * (InpMaxWeeklyLossPct/100.0);
   return (g_WeeklyProfit <= -MathAbs(limit));
}

bool IsDailyProfitTargetHit()
{
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double target  = balance * (InpMaxDailyProfitPct/100.0);
   return (g_DailyProfit >= target);
}

bool IsDrawdownLimitHit()
{
   if(g_EquityPeak <= 0.0) return false;
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   double ddPct  = ((g_EquityPeak - equity) / g_EquityPeak) * 100.0;
   return (ddPct >= InpMaxDrawdownPct);
}

bool IsRecoveryModeActive()
{
   if(g_EquityPeak <= 0.0) return false;
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   double ddPct  = ((g_EquityPeak - equity) / g_EquityPeak) * 100.0;
   return (ddPct >= InpRecoveryDDPct && ddPct < InpMaxDrawdownPct);
}

bool IsWeekendPauseActive()
{
   MqlDateTime dt; TimeToStruct(TimeGMT(), dt);
   if(dt.day_of_week == 1 && dt.hour == 0 && dt.min < InpWeekendPauseMin)
      return true;
   return false;
}

//+------------------------------------------------------------------+
//| STRING CONVERSION HELPERS                                         |
//+------------------------------------------------------------------+
string RegimeToString(ENUM_REGIME r)
{
   switch(r)
   {
      case REGIME_SHOCK:       return "SHOCK";
      case REGIME_BREAKOUT:    return "BREAKOUT";
      case REGIME_TRENDING:    return "TRENDING";
      case REGIME_COMPRESSION: return "COMPRESSION";
      case REGIME_SWEEP:       return "SWEEP";
      case REGIME_RANGING:     return "RANGING";
      default:                 return "?";
   }
}

string ModuleToString(ENUM_STRAT_MODULE m)
{
   switch(m)
   {
      case STRAT_TREND_CONT:     return "TrendCont(A)";
      case STRAT_BREAKOUT_MOM:   return "BreakoutMom(B)";
      case STRAT_PULLBACK_MR:    return "PullbackMR(C)";
      case STRAT_VOL_EXPANSION:  return "VolExpansion(D)";
      case STRAT_SWEEP_REV:      return "SweepReversal(E)";
      case STRAT_COMPRESSION_BO: return "CompressionBO(H)";
      default:                   return "None";
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
      default:         return EnumToString(tf);
   }
}

//====================================================================
// NOVA TITAN X DASHBOARD ENGINE
//
// Layout (top to bottom, width=350px):
//   [HEADER]              - name, symbol, timeframe, version
//   [REGIME PANEL]         - current regime + classifier sub-readings
//   [ACTIVE STRATEGY]      - module owning current regime, confidence bar
//   [RISK / ACCOUNT]       - balance, equity, risk%, drawdown, state
//   [OPEN POSITION]        - R-multiple, peak, SL/TP
//   [PERFORMANCE TABLE]    - per-regime trades/winrate/expectancy
//   [ENGINE STATUS]        - state machine + daily counters
//====================================================================
#define DW 350

void RenderDashboard()
{
   int X = InpDashX, Y = InpDashY, W = DW;
   int y = Y;

   DrawRect("SHELL", X, Y, W, 560, C_BG, C_BORDER, 2);

   //--- HEADER ---
   DrawRect("HDR_BG", X+2, y+2, W-4, 28, C_HEADER, C_BORDER, 1);
   DrawLabel("HDR_NM",  X+6,    y+4,  "NOVA TITAN X", C_CYAN, 10, "Arial Black");
   DrawLabel("HDR_SYM", X+W-100,y+4,  _Symbol,        C_GOLD, 10, "Impact");
   DrawLabel("HDR_TF",  X+W-40, y+16, TimeframeToString(_Period), C_MUTED, 7, "Arial");
   DrawLabel("HDR_VER", X+6,    y+16, EA_VERSION+" REGIME-ROUTED MULTI-STRATEGY", C_MUTED, 7, "Arial");
   y += 31;

   //--- REGIME PANEL (13 hdr + 56 body) ---
   DrawRect("RG_HDR", X+2, y, W-4, 13, C_SECTION_HDR, C_BORDER2, 1);
   DrawLabel("RG_TIT", X+6, y+2, "MARKET REGIME CLASSIFIER", C_ORANGE, 7, "Arial Black");
   y += 14;
   DrawRect("RG_BG", X+2, y, W-4, 56, C_PANEL, C_BORDER2, 1);
   DrawLabel("L_REG", X+6, y+3, "REGIME", C_MUTED, 7, "Arial");
   DrawRect("REG_PILL", X+62, y+2, 110, 12, C_PANEL2, C_BORDER2, 1);
   DrawLabel("V_REG", X+66, y+3, "RANGING", C_BLUE, 8, "Arial Black");
   DrawLabel("L_ADX", X+W-90, y+3, "ADX", C_MUTED, 7, "Arial");
   DrawLabel("V_ADX", X+W-65, y+3, "0.0", C_WHITE, 7, "Arial Bold");
   DrawLabel("L_VPC", X+6, y+16, "ATR Pctl", C_MUTED, 7, "Arial");
   DrawLabel("V_VPC", X+58, y+16, "50%", C_WHITE, 7, "Arial Bold");
   DrawLabel("L_BBP", X+W/2, y+16, "BB Pctl", C_MUTED, 7, "Arial");
   DrawLabel("V_BBP", X+W/2+48, y+16, "50%", C_WHITE, 7, "Arial Bold");
   DrawLabel("L_DSZ", X+6, y+29, "Disp Z", C_MUTED, 7, "Arial");
   DrawLabel("V_DSZ", X+58, y+29, "0.00", C_WHITE, 7, "Arial Bold");
   DrawLabel("L_VOZ", X+W/2, y+29, "Vol Z", C_MUTED, 7, "Arial");
   DrawLabel("V_VOZ", X+W/2+48, y+29, "0.00", C_WHITE, 7, "Arial Bold");
   DrawLabel("L_SHK", X+6, y+42, "Shock", C_MUTED, 7, "Arial");
   DrawLabel("V_SHK", X+58, y+42, "NO", C_GREEN, 7, "Arial Bold");
   DrawLabel("L_BID", X+W/2, y+42, "BID/ASK", C_MUTED, 7, "Arial");
   DrawLabel("V_BID", X+W/2+48, y+42, "0.00/0.00", C_WHITE, 7, "Arial Bold");
   y += 58;

   //--- ACTIVE STRATEGY (13 hdr + 44 body) ---
   DrawRect("ST_HDR", X+2, y, W-4, 13, C_SECTION_HDR, C_BORDER2, 1);
   DrawLabel("ST_TIT", X+6, y+2, "ACTIVE STRATEGY MODULE", C_ORANGE, 7, "Arial Black");
   y += 14;
   DrawRect("ST_BG", X+2, y, W-4, 44, C_PANEL, C_BORDER2, 1);
   DrawLabel("L_MOD", X+6, y+3, "MODULE", C_MUTED, 7, "Arial");
   DrawLabel("V_MOD", X+58, y+3, "---", C_CYAN, 8, "Arial Bold");
   DrawLabel("L_SIG", X+W-90, y+3, "SIGNAL", C_MUTED, 7, "Arial");
   DrawLabel("V_SIG", X+W-46, y+3, "HOLD", C_GOLD, 8, "Arial Black");
   DrawLabel("L_CNF", X+6, y+18, "CONFIDENCE", C_MUTED, 7, "Arial");
   DrawRect("CONF_BG", X+76, y+19, 200, 10, C_PANEL2, C_BORDER2, 1);
   DrawRect("CONF_FG", X+76, y+19, 4, 10, C_GOLD, clrNONE, 0);
   DrawLabel("V_CNF", X+282, y+18, "0/100", C_WHITE, 7, "Arial Bold");
   DrawLabel("L_REQ", X+6, y+31, "Required", C_MUTED, 7, "Arial");
   DrawLabel("V_REQ", X+58, y+31, "62", C_WHITE, 7, "Arial Bold");
   DrawLabel("L_CONFM", X+W/2, y+31, "Engine", C_MUTED, 7, "Arial");
   DrawLabel("V_CONFM", X+W/2+44, y+31, "SCANNING", C_GOLD, 7, "Arial Bold");
   y += 46;

   //--- RISK / ACCOUNT (13 hdr + 56 body) ---
   DrawRect("AC_HDR", X+2, y, W-4, 13, C_SECTION_HDR, C_BORDER2, 1);
   DrawLabel("AC_TIT", X+6, y+2, "RISK & ACCOUNT", C_ORANGE, 7, "Arial Black");
   y += 14;
   DrawRect("AC_BG", X+2, y, W-4, 56, C_PANEL, C_BORDER2, 1);
   DrawLabel("L_BAL", X+6, y+3, "BAL", C_MUTED, 7, "Arial");
   DrawLabel("V_BAL", X+30, y+3, "$0.00", C_GREEN, 8, "Arial Bold");
   DrawLabel("L_EQ", X+W/2, y+3, "EQ", C_MUTED, 7, "Arial");
   DrawLabel("V_EQ", X+W/2+20, y+3, "$0.00", C_WHITE, 8, "Arial Bold");
   DrawLabel("L_RSK", X+6, y+16, "RISK%", C_MUTED, 7, "Arial");
   DrawLabel("V_RSK", X+40, y+16, "0.00%", C_GOLD, 7, "Arial Bold");
   DrawLabel("L_DD", X+W/2, y+16, "DRAWDOWN", C_MUTED, 7, "Arial");
   DrawLabel("V_DD", X+W/2+62, y+16, "0.00%", C_WHITE, 7, "Arial Bold");
   DrawLabel("L_DP", X+6, y+29, "DAY P&L", C_MUTED, 7, "Arial");
   DrawLabel("V_DP", X+48, y+29, "+0.00 (0.00%)", C_GREEN, 7, "Arial Bold");
   DrawLabel("L_RM", X+6, y+42, "RISK STATE", C_MUTED, 7, "Arial");
   DrawLabel("V_RM", X+62, y+42, "NORMAL", C_GREEN, 7, "Arial Bold");
   DrawLabel("L_STK", X+W/2, y+42, "STREAK", C_MUTED, 7, "Arial");
   DrawLabel("V_STK", X+W/2+44, y+42, "---", C_MUTED, 7, "Arial Bold");
   y += 58;

   //--- OPEN POSITION (13 hdr + 42 body) ---
   DrawRect("OP_HDR", X+2, y, W-4, 13, C_SECTION_HDR, C_BORDER2, 1);
   DrawLabel("OP_TIT", X+6, y+2, "OPEN POSITION", C_ORANGE, 7, "Arial Black");
   DrawLabel("OP_CNT", X+W-44, y+2, "0 open", C_MUTED, 7, "Arial");
   y += 14;
   DrawRect("OP_BG", X+2, y, W-4, 42, C_PANEL, C_BORDER2, 1);
   DrawLabel("L_OTYP", X+6, y+3, "TYPE", C_MUTED, 7, "Arial");
   DrawLabel("V_OTYP", X+32, y+3, "---", C_MUTED, 8, "Arial Bold");
   DrawLabel("L_OMOD", X+W/2-20, y+3, "MOD", C_MUTED, 7, "Arial");
   DrawLabel("V_OMOD", X+W/2+6, y+3, "---", C_MUTED, 7, "Arial Bold");
   DrawLabel("L_OOPN", X+6, y+16, "OPEN", C_MUTED, 7, "Arial");
   DrawLabel("V_OOPN", X+34, y+16, "---", C_WHITE, 7, "Arial Bold");
   DrawLabel("L_OSLT", X+W/2-20, y+16, "SL/TP", C_MUTED, 7, "Arial");
   DrawLabel("V_OSLT", X+W/2+6, y+16, "--- / ---", C_WHITE, 7, "Arial Bold");
   DrawLabel("L_OPNL", X+6, y+29, "P&L", C_MUTED, 7, "Arial");
   DrawLabel("V_OPNL", X+30, y+29, "+$0.00 (0.0R)", C_GREEN, 7, "Arial Bold");
   DrawLabel("L_OPK", X+W/2+40, y+29, "PK", C_MUTED, 7, "Arial");
   DrawLabel("V_OPK", X+W/2+58, y+29, "+$0.00", C_CYAN, 7, "Arial Bold");
   y += 44;

   //--- PERFORMANCE TABLE (13 hdr + 80 body, one row per regime) ---
   DrawRect("PF_HDR", X+2, y, W-4, 13, C_SECTION_HDR, C_BORDER2, 1);
   DrawLabel("PF_TIT", X+6, y+2, "PER-REGIME PERFORMANCE", C_ORANGE, 7, "Arial Black");
   y += 14;
   DrawRect("PF_BG", X+2, y, W-4, 80, C_PANEL, C_BORDER2, 1);
   DrawLabel("PF_C1", X+6,   y+2, "Regime",   C_MUTED, 7, "Arial Black");
   DrawLabel("PF_C2", X+118, y+2, "Trades",   C_MUTED, 7, "Arial Black");
   DrawLabel("PF_C3", X+170, y+2, "Win%",     C_MUTED, 7, "Arial Black");
   DrawLabel("PF_C4", X+215, y+2, "ExpR",     C_MUTED, 7, "Arial Black");
   DrawLabel("PF_C5", X+260, y+2, "PF",       C_MUTED, 7, "Arial Black");
   DrawLabel("PF_C6", X+300, y+2, "Thresh",   C_MUTED, 7, "Arial Black");
   string regNames[6] = {"SHOCK","BREAKOUT","TRENDING","COMPRESS","SWEEP","RANGING"};
   for(int r = 0; r < 6; r++)
   {
      int ry = y + 13 + r*11;
      DrawLabel("PF_R"+IntegerToString(r)+"_N", X+6,   ry, regNames[r], C_WHITE, 7, "Arial");
      DrawLabel("PF_R"+IntegerToString(r)+"_T", X+118, ry, "0",         C_WHITE, 7, "Arial");
      DrawLabel("PF_R"+IntegerToString(r)+"_W", X+170, ry, "0%",        C_WHITE, 7, "Arial");
      DrawLabel("PF_R"+IntegerToString(r)+"_E", X+215, ry, "0.00",      C_WHITE, 7, "Arial");
      DrawLabel("PF_R"+IntegerToString(r)+"_P", X+260, ry, "0.00",      C_WHITE, 7, "Arial");
      DrawLabel("PF_R"+IntegerToString(r)+"_H", X+300, ry, "62",        C_WHITE, 7, "Arial");
   }
   y += 82;

   //--- ENGINE STATUS (13 hdr + 42 body) ---
   DrawRect("EN_HDR", X+2, y, W-4, 13, C_SECTION_HDR, C_BORDER2, 1);
   DrawLabel("EN_TIT", X+6, y+2, "ENGINE STATUS", C_ORANGE, 7, "Arial Black");
   y += 14;
   DrawRect("EN_BG", X+2, y, W-4, 42, C_PANEL, C_BORDER2, 1);
   DrawLabel("L_STA", X+6, y+3, "STATE", C_MUTED, 7, "Arial");
   DrawLabel("V_STA", X+44, y+3, "BOOTING", C_GOLD, 7, "Arial Black");
   DrawLabel("L_TRD", X+6, y+18, "Daily Trades", C_MUTED, 7, "Arial");
   DrawLabel("V_TRD", X+78, y+18, "0 / 20", C_WHITE, 7, "Arial Bold");
   DrawLabel("L_WK",  X+W/2, y+18, "Weekly P&L", C_MUTED, 7, "Arial");
   DrawLabel("V_WK",  X+W/2+62, y+18, "+0.00", C_GREEN, 7, "Arial Bold");
   DrawLabel("F1", X+6, y+31, "Self-optimising regime-routed engine.", C_MUTED, 6, "Arial");
   y += 44;

   ChartRedraw(0);
}

void UpdateDashboard()
{
   //--- Regime panel ---
   SetLabel("V_REG", RegimeToString(g_CurrentRegime),
            (g_CurrentRegime==REGIME_SHOCK) ? C_RED :
            (g_CurrentRegime==REGIME_BREAKOUT) ? C_ORANGE :
            (g_CurrentRegime==REGIME_TRENDING) ? C_GREEN :
            (g_CurrentRegime==REGIME_COMPRESSION) ? C_GOLD :
            (g_CurrentRegime==REGIME_SWEEP) ? C_VIOLET : C_BLUE);
   string pillN = DASH_PREFIX+"REG_PILL";
   if(ObjectFind(0,pillN)>=0)
      ObjectSetInteger(0,pillN,OBJPROP_BGCOLOR,
         (g_CurrentRegime==REGIME_SHOCK)?C_SELL_BG:(g_CurrentRegime==REGIME_TRENDING)?C_BUY_BG:C_PANEL2);

   double adx[1];
   if(CopyBuffer(g_hADX,0,0,1,adx)>0) SetLabel("V_ADX", DoubleToString(adx[0],1), C_WHITE);
   SetLabel("V_VPC", DoubleToString(g_VolPercentile,0)+"%", C_WHITE);
   SetLabel("V_BBP", DoubleToString(g_BBWidthPercentile,0)+"%", C_WHITE);
   SetLabel("V_DSZ", DoubleToString(g_DisplacementZ,2), (MathAbs(g_DisplacementZ)>=InpShockZScoreThresh)?C_RED:C_WHITE);
   SetLabel("V_VOZ", DoubleToString(g_VolumeZ,2), (g_VolumeZ>=InpShockVolZThresh)?C_RED:C_WHITE);
   bool shockNow = (g_CurrentRegime==REGIME_SHOCK);
   SetLabel("V_SHK", shockNow?"YES":"NO", shockNow?C_RED:C_GREEN);
   double bid = SymbolInfoDouble(_Symbol,SYMBOL_BID), ask = SymbolInfoDouble(_Symbol,SYMBOL_ASK);
   SetLabel("V_BID", DoubleToString(bid,2)+"/"+DoubleToString(ask,2), C_WHITE);

   //--- Active strategy ---
   ENUM_STRAT_MODULE curMod = STRAT_NONE;
   switch(g_CurrentRegime)
   {
      case REGIME_SHOCK:        curMod = STRAT_VOL_EXPANSION;   break;
      case REGIME_BREAKOUT:     curMod = STRAT_BREAKOUT_MOM;    break;
      case REGIME_TRENDING:     curMod = STRAT_TREND_CONT;      break;
      case REGIME_COMPRESSION:  curMod = STRAT_COMPRESSION_BO;  break;
      case REGIME_SWEEP:        curMod = STRAT_SWEEP_REV;       break;
      default:                  curMod = STRAT_PULLBACK_MR;     break;
   }
   SetLabel("V_MOD", ModuleToString(curMod), C_CYAN);

   double reqConf = GetRequiredConfidence(g_CurrentRegime);
   SetLabel("V_REQ", DoubleToString(reqConf,0), C_WHITE);

   double curConf = 0.0; ENUM_SIGNAL curSig = SIG_NONE;
   if(!IsPositionOpen() && (g_State==ENGINE_SCANNING))
   {
      ModuleResult res;
      switch(g_CurrentRegime)
      {
         case REGIME_SHOCK:        res = Strategy_VolatilityExpansion;    break;
         case REGIME_BREAKOUT:     res = Strategy_BreakoutMomentum;       break;
         case REGIME_TRENDING:     res = Strategy_TrendContinuation;      break;
         case REGIME_COMPRESSION:  res = Strategy_CompressionBreakout;    break;
         case REGIME_SWEEP:        res = Strategy_LiquiditySweepReversal; break;
         default:                  res = Strategy_PullbackMeanReversion;  break;
      }
      curConf = res.confidence; curSig = res.sig;
   }
   else if(g_State == ENGINE_CONFIRMING)
   {
      curConf = g_PendingConfidence; curSig = g_PendingSignal;
   }

   color sigClr = (curSig==SIG_BUY)?C_GREEN:(curSig==SIG_SELL)?C_RED:C_GOLD;
   SetLabel("V_SIG", (curSig==SIG_BUY)?"BUY":(curSig==SIG_SELL)?"SELL":"HOLD", sigClr);
   SetLabel("V_CNF", DoubleToString(curConf,0)+"/100", C_WHITE);
   string confFgN = DASH_PREFIX+"CONF_FG";
   if(ObjectFind(0,confFgN)>=0)
   {
      ObjectSetInteger(0,confFgN,OBJPROP_XSIZE, MathMax(4,(int)MathRound(200*(curConf/100.0))));
      color cfClr = (curConf>=reqConf) ? C_GREEN : (curConf>=reqConf*0.8) ? C_GOLD : C_RED;
      ObjectSetInteger(0,confFgN,OBJPROP_BGCOLOR, cfClr);
   }
   string engTxt = (g_State==ENGINE_SCANNING)?"SCANNING":(g_State==ENGINE_CONFIRMING)?"CONFIRMING":
                   (g_State==ENGINE_COOLDOWN)?"COOLDOWN":(g_State==ENGINE_HALTED_DAILY)?"HALTED-DAILY":
                   (g_State==ENGINE_HALTED_DD)?"HALTED-DD":"RECOVERY";
   SetLabel("V_CONFM", engTxt, (g_State==ENGINE_HALTED_DAILY||g_State==ENGINE_HALTED_DD)?C_RED:C_GOLD);

   //--- Risk / account ---
   double bal = AccountInfoDouble(ACCOUNT_BALANCE);
   double eq  = AccountInfoDouble(ACCOUNT_EQUITY);
   SetLabel("V_BAL", "$"+DoubleToString(bal,2), C_GREEN);
   SetLabel("V_EQ",  "$"+DoubleToString(eq,2),  C_WHITE);
   SetLabel("V_RSK", DoubleToString(GetRiskAdjustedPercent(g_CurrentRegime),2)+"%", C_GOLD);

   double ddPct = (g_EquityPeak>0.0) ? ((g_EquityPeak-eq)/g_EquityPeak)*100.0 : 0.0;
   color cDD = (ddPct > InpMaxDrawdownPct*0.66) ? C_RED : (ddPct > InpMaxDrawdownPct*0.33) ? C_GOLD : C_WHITE;
   SetLabel("V_DD", DoubleToString(ddPct,2)+"%", cDD);

   double dpPct = (bal>0)?(g_DailyProfit/bal)*100.0:0.0;
   color cDp = (g_DailyProfit>=0)?C_GREEN:C_RED;
   SetLabel("V_DP", (g_DailyProfit>=0?"+":"")+DoubleToString(g_DailyProfit,2)+" ("+DoubleToString(MathAbs(dpPct),2)+"%)", cDp);

   string rmTxt = IsDrawdownLimitHit() ? "HALTED" : IsRecoveryModeActive() ? "RECOVERY" :
                  (g_ConsecLosses>=InpMaxLossStreak) ? "REDUCED" : "NORMAL";
   color rmClr = IsDrawdownLimitHit() ? C_RED : IsRecoveryModeActive() ? C_GOLD :
                 (g_ConsecLosses>=InpMaxLossStreak) ? C_ORANGE : C_GREEN;
   SetLabel("V_RM", rmTxt, rmClr);

   if(g_ConsecLosses >= 2) SetLabel("V_STK", "LOSS x"+IntegerToString(g_ConsecLosses), C_RED);
   else if(g_ConsecWins >= 2) SetLabel("V_STK", "WIN x"+IntegerToString(g_ConsecWins), C_GREEN);
   else SetLabel("V_STK", "---", C_MUTED);

   //--- Open position ---
   bool hasPos = false;
   for(int i = 0; i < PositionsTotal(); i++)
   {
      if(g_Pos.SelectByIndex(i) && g_Pos.Magic()==InpMagicNumber && g_Pos.Symbol()==_Symbol)
      {
         hasPos = true;
         string typStr = (g_Pos.PositionType()==POSITION_TYPE_BUY)?"BUY":"SELL";
         color  typClr = (g_Pos.PositionType()==POSITION_TYPE_BUY)?C_GREEN:C_RED;
         double rowPnl = g_Pos.Profit()+g_Pos.Swap()+g_Pos.Commission();

         SetLabel("V_OTYP", typStr, typClr);
         SetLabel("V_OMOD", ModuleToString(g_OpenModule), C_CYAN);
         SetLabel("V_OOPN", DoubleToString(g_Pos.PriceOpen(),2), C_WHITE);
         SetLabel("V_OSLT", DoubleToString(g_Pos.StopLoss(),2)+" / "+DoubleToString(g_Pos.TakeProfit(),2), C_WHITE);

         string rTxt   = (g_EntryRiskUSD>0)?" ("+DoubleToString(rowPnl/g_EntryRiskUSD,2)+"R)":"";
         string pkRTxt = (g_EntryRiskUSD>0)?" ("+DoubleToString(g_PeakProfit/g_EntryRiskUSD,2)+"R)":"";
         color  pnlClr = (rowPnl>=0)?C_GREEN:C_RED;
         SetLabel("V_OPNL", (rowPnl>=0?"+$":"-$")+DoubleToString(MathAbs(rowPnl),2)+rTxt, pnlClr);
         SetLabel("V_OPK", "+$"+DoubleToString(g_PeakProfit,2)+pkRTxt, C_CYAN);
         break;
      }
   }
   if(!hasPos)
   {
      SetLabel("V_OTYP","---",C_MUTED); SetLabel("V_OMOD","---",C_MUTED);
      SetLabel("V_OOPN","---",C_MUTED); SetLabel("V_OSLT","--- / ---",C_MUTED);
      SetLabel("V_OPNL","+$0.00 (0.0R)",C_MUTED); SetLabel("V_OPK","+$0.00",C_MUTED);
   }
   SetLabel("OP_CNT", (hasPos?"1 open":"0 open"), hasPos?C_CYAN:C_MUTED);

   //--- Per-regime performance table ---
   for(int r = 0; r < 6; r++)
   {
      string idx = IntegerToString(r);
      int trades = g_RegimeStats[r].trades;
      double winRate = (trades>0) ? ((double)g_RegimeStats[r].wins/trades)*100.0 : 0.0;
      double expR    = (trades>0) ? g_RegimeStats[r].sumR/trades : 0.0;
      double pf      = (g_RegimeStats[r].grossLoss>0.0) ? g_RegimeStats[r].grossProfit/g_RegimeStats[r].grossLoss : 0.0;

      SetLabel("PF_R"+idx+"_T", IntegerToString(trades), C_WHITE);
      SetLabel("PF_R"+idx+"_W", DoubleToString(winRate,0)+"%", (winRate>=50)?C_GREEN:(trades>0?C_RED:C_MUTED));
      SetLabel("PF_R"+idx+"_E", DoubleToString(expR,2), (expR>=0)?C_GREEN:C_RED);
      SetLabel("PF_R"+idx+"_P", (trades>0)?DoubleToString(pf,2):"---", C_WHITE);
      SetLabel("PF_R"+idx+"_H", DoubleToString(g_RegimeStats[r].dynamicThreshold,0), C_GOLD);
   }

   //--- Engine status ---
   string stTxt = (g_State==ENGINE_SCANNING)?"SCANNING":(g_State==ENGINE_CONFIRMING)?"CONFIRMING":
                  (g_State==ENGINE_COOLDOWN)?"COOLDOWN":(g_State==ENGINE_HALTED_DAILY)?"HALTED-DAILY":
                  (g_State==ENGINE_HALTED_DD)?"HALTED-DRAWDOWN":"RECOVERY";
   color stClr = (g_State==ENGINE_HALTED_DAILY||g_State==ENGINE_HALTED_DD)?C_RED:
                 (g_State==ENGINE_COOLDOWN)?C_GOLD:(g_State==ENGINE_CONFIRMING)?C_VIOLET:C_GREEN;
   SetLabel("V_STA", g_StatusText, g_StatusColor != clrNONE ? g_StatusColor : stClr);
   SetLabel("V_TRD", IntegerToString(g_DailyTrades)+" / "+IntegerToString(InpMaxDailyTrades), C_WHITE);
   color wkClr = (g_WeeklyProfit>=0)?C_GREEN:C_RED;
   SetLabel("V_WK", (g_WeeklyProfit>=0?"+":"")+DoubleToString(g_WeeklyProfit,2), wkClr);

   ChartRedraw(0);
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
//+------------------------------------------------------------------+
//| END OF FILE                                                       |
//+------------------------------------------------------------------+
