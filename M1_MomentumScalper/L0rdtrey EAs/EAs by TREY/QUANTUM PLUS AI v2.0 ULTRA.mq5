//+------------------------------------------------------------------+
//|                                    QUANTUM PLUS AI v2.0 ULTRA    |
//|              Institutional AI Market Analyst Terminal            |
//|              Maximum Visibility — Professional Grade             |
//+------------------------------------------------------------------+
#property copyright   "Quantum Plus AI v2.0 Ultra"
#property version     "2.50"
#property description "Advanced Autonomous Scalping System"
#property strict

#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>
#include <Trade\AccountInfo.mqh>
#include <Trade\OrderInfo.mqh>

//=====================================================================
//  CRITICAL DEFINES
//=====================================================================
#define D    "QPA2_"
#define OV   "QPA2_OV_"
#define AP   "QPA2_AP_"
#define M_PI 3.14159265358979323846

//=====================================================================
//  ENUMERATIONS
//=====================================================================
enum ENUM_REGIME
{
   REGIME_TRENDING,
   REGIME_RANGING,
   REGIME_BREAKOUT,
   REGIME_COMPRESSION,
   REGIME_EXPANSION,
   REGIME_VOLATILITY_SHOCK,
   REGIME_LIQUIDITY_SWEEP,
   REGIME_EXHAUSTION,
   REGIME_MEAN_REVERSION,
   REGIME_UNSAFE
};

enum ENUM_VOL_STATE   { VOL_LOW, VOL_NORMAL, VOL_HIGH, VOL_EXTREME };
enum ENUM_VOL_DYNAMIC { VOLDYN_EXPANDING, VOLDYN_COMPRESSING, VOLDYN_STABLE, VOLDYN_SPIKE };

enum ENUM_SESSION
{
   SESSION_ASIAN,
   SESSION_LONDON_OPEN,
   SESSION_LONDON_MID,
   SESSION_NY_OPEN,
   SESSION_NY_PM,
   SESSION_DEAD_ZONE
};

enum ENUM_NEWS_STATE  { NEWS_NORMAL, NEWS_CAUTION, NEWS_SHOCK };

enum ENUM_STRATEGY
{
   STRAT_NONE,
   STRAT_TREND_SCALPER,
   STRAT_MEAN_REVERSION,
   STRAT_VOLATILITY_EXPANSION,
   STRAT_LIQUIDITY_REVERSAL,
   STRAT_COMPRESSION_BREAKOUT
};

enum ENUM_DIRECTION   { DIR_NONE, DIR_LONG, DIR_SHORT };

enum ENUM_TRADE_MANAGEMENT
{
   TM_NONE,
   TM_BREAKEVEN_ACTIVE,
   TM_TRAILING_ACTIVE,
   TM_PARTIAL_CLOSED
};

//=====================================================================
//  DATA STRUCTURES
//=====================================================================
struct RegimeState
{
   ENUM_REGIME  regime;
   double       confidence;
   double       stability;
   datetime     sinceTime;
   ENUM_REGIME  previousRegime;
   int          barsSinceChange;
};

struct VolatilityState
{
   ENUM_VOL_STATE   state;
   ENUM_VOL_DYNAMIC dynamic;
   double           atrCurrent;
   double           atrAvg;
   double           atrRatio;
   double           percentile;
   double           atrH1;
   double           atrM15;
   bool             ready;
};

struct LiquidityState
{
   double  biasScore;
   double  pressureScore;
   double  sweepProbability;
   double  imbalanceScore;
   bool    equalHighsDetected;
   bool    equalLowsDetected;
   double  equalHighLevel;
   double  equalLowLevel;
   bool    sweepUpDetected;
   bool    sweepDownDetected;
   int     bslCount;
   int     sslCount;
};

struct SessionState
{
   ENUM_SESSION  current;
   ENUM_SESSION  previous;
   double        sessionRangeATRRatio;
   double        sessionVolatilityScore;
   ENUM_STRATEGY preferredStrategy;
   double        strategyWeight;
   datetime      sessionStartTime;
   bool          transitionDetected;
};

struct MTFBias
{
   int    h1Bias;
   int    m15Bias;
   int    m5Bias;
   int    m1Bias;
   double alignment;
   double strength;
   bool   ready;
};

struct StrategySignal
{
   ENUM_STRATEGY  source;
   ENUM_DIRECTION direction;
   double         confidence;
   double         suggestedSL;
   double         suggestedTP;
   double         suggestedEntry;
   string         reason;
   bool           valid;
   datetime       timestamp;
   double         riskReward;
};

struct StrategyHealth
{
   string   name;
   int      totalTrades;
   int      wins;
   int      losses;
   double   grossProfit;
   double   grossLoss;
   double   sumR;
   double   sumRSquared;
   int      consecLosses;
   int      maxConsecLosses;
   double   winRate;
   double   profitFactor;
   double   expectancyR;
   double   sharpeProxy;
   bool     enabled;
   double   influenceMultiplier;
   datetime lastDegradedTime;
   double   avgWin;
   double   avgLoss;
   double   recoveryFactor;
};

struct ExecutionQuality
{
   double spreadScore;
   double slippageRiskScore;
   double volatilityQuality;
   double liquidityQuality;
   double efficiencyScore;
   double compositeScore;
   bool   executionApproved;
   string rejectReason;
   double currentSpread;
   double avgSpread;
};

struct RiskState
{
   double  dailyRiskUsedPct;
   double  weeklyRiskUsedPct;
   double  currentDrawdownPct;
   double  maxDrawdownSeenPct;
   bool    dailyLimitHit;
   bool    weeklyLimitHit;
   bool    maxDrawdownBreached;
   bool    emergencyShutdown;
   double  peakEquity;
   double  weekStartEquity;
   double  dayStartEquity;
   double  currentEquity;
   double  exposurePercent;
};

struct MasterDecision
{
   bool           tradeApproved;
   ENUM_DIRECTION direction;
   double         lotSize;
   double         slPrice;
   double         tpPrice;
   double         entryPrice;
   ENUM_STRATEGY  strategySource;
   double         riskAmountUsed;
   string         narrative;
   double         confidence;
   datetime       timestamp;
};

struct MarketScores
{
   double trendScore;
   double liquidityScore;
   double volumeScore;
   double sessionScore;
   double structureScore;
   double momentumScore;
   double volatilityScore;
   double structureClarity;
   double totalScore;
   datetime lastUpdate;
};

struct PositionManager
{
   ulong             ticket;
   ENUM_STRATEGY     strategy;
   double            openPrice;
   double            originalSL;
   double            originalTP;
   double            currentSL;
   double            currentTP;
   double            riskAmount;
   ENUM_TRADE_MANAGEMENT status;
   bool              beMovedToBreakeven;
   bool              trailingActive;
   datetime          openTime;
   double            highestPrice;
   double            lowestPrice;
   bool              partialTaken;
};

struct IndicatorState
{
   bool ready;
   int  handle;
   datetime lastUpdate;
   int  bufferSize;
};

struct LearningData
{
   double   regimeSuccessRate[10];
   int      regimeTrades[10];
   double   sessionSuccessRate[6];
   int      sessionTrades[6];
   double   strategyOptimalConfidence[5];
   double   optimalRiskPerTrade;
   double   bestTimeToTrade;
   double   worstTimeToTrade;
   int      totalLearningCycles;
   datetime lastLearningUpdate;
};

//=====================================================================
//  INPUTS
//=====================================================================
input group "===== IDENTITY ====="
input ulong  InpMagicNumber         = 778800;
input string InpBotName             = "QUANTUM PLUS AI v2.0 ULTRA";

input group "===== RISK GOVERNANCE ====="
input double InpRiskPercentPerTrade = 1.0;
input double InpMaxRiskPercentTrade = 2.0;
input double InpMaxDailyLossPct     = 3.0;
input double InpMaxWeeklyLossPct    = 7.0;
input double InpMaxDrawdownPct      = 12.0;
input int    InpMaxDailyTrades      = 20;
input int    InpMaxConcurrentTrades = 3;
input int    InpBrokerGMTOffset     = 2;

input group "===== EXECUTION ====="
input double InpMaxSpreadPoints       = 20;
input double InpMinExecutionScore     = 50.0;
input int    InpCooldownAfterCloseSec = 5;
input int    InpMaxSlippagePoints     = 10;

input group "===== POSITION MANAGEMENT ====="
input bool   InpEnableBreakeven       = true;
input double InpBreakevenTriggerR     = 1.0;
input double InpBreakevenOffsetR      = 0.2;
input bool   InpEnableTrailing        = true;
input double InpTrailingStartR        = 1.5;
input double InpTrailingStepR         = 0.5;
input bool   InpEnablePartialClose    = true;
input double InpPartialCloseR         = 1.5;
input double InpPartialClosePercent   = 50.0;

input group "===== REGIME DETECTION ====="
input int    InpATRPeriod           = 14;
input int    InpATRLookback         = 100;
input int    InpEMAFastPeriod       = 8;
input int    InpEMASlowPeriod       = 34;
input int    InpStructureLookback   = 20;
input double InpMinRegimeConfidence = 55.0;

input group "===== LIQUIDITY ====="
input double InpEqualLevelTolerance = 0.15;
input int    InpLiquidityLookback   = 40;

input group "===== NEWS SHOCK ====="
input double InpShockATRMultiple    = 2.5;
input double InpShockSpreadMultiple = 2.0;

input group "===== STRATEGY HEALTH ====="
input int    InpHealthMinTrades         = 5;
input int    InpHealthDegradeConsecLoss = 3;
input double InpHealthMinExpectancyR    = -0.20;
input bool   InpEnableLearning          = true;

input group "===== ADAPTIVE ====="
input bool   InpEnableAdaptiveParams = true;
input double InpAdaptiveBoundPct     = 30.0;
input bool   InpAggressiveMode       = true;

input group "===== DASHBOARD ====="
input bool   InpShowDash   = true;
input int    InpDashX      = 10;
input int    InpDashY      = 10;
input int    InpDashWidth  = 420;

input group "===== ANALYST PANEL ====="
input bool   InpShowAnalystPanel   = true;
input int    InpAnalystX           = 440;
input int    InpAnalystY           = 10;
input int    InpNarrativeUpdateSec = 30;

input group "===== CHART OVERLAYS ====="
input bool   InpDrawSessionBoxes    = true;
input bool   InpDrawLiquidityZones  = true;
input bool   InpDrawSignalMarkers   = true;
input bool   InpDrawStructure       = true;
input bool   InpDrawFVG             = false;
input bool   InpDrawOrderBlocks     = true;
input bool   InpDrawBSLSSL          = true;
input bool   InpDrawRegimeOverlay   = true;
input bool   InpDrawVolumeSpikes    = false;
input int    InpSessionBoxLookbackHrs = 24;

input group "===== DISPLAY SCALING ====="
input int    InpDPIScale = 100;

input group "===== ADDITIONAL INDICATORS ====="
input bool   InpUseStochastic       = true;
input bool   InpUseBollingerBands   = true;
input bool   InpUseCCI              = false;
input bool   InpUseMACD             = true;

//=====================================================================
//  COLOR PALETTE
//=====================================================================
#define C_CHART_BG     C'5,5,5'
#define C_PANEL_BG     C'8,15,35'
#define C_PANEL_BG2    C'12,22,50'
#define C_PANEL_HDR    C'15,30,65'
#define C_PANEL_BRD    C'0,100,180'
#define C_PANEL_BRD2   C'0,60,120'
#define C_CYAN_BRIGHT  C'0,255,255'
#define C_GOLD_BRIGHT  C'255,215,0'
#define C_WHITE_PURE   C'255,255,255'
#define C_WHITE_SOFT   C'220,230,245'
#define C_GREEN_BRIGHT C'0,255,100'
#define C_GREEN_MED    C'0,200,80'
#define C_GREEN_DARK   C'0,80,30'
#define C_RED_BRIGHT   C'255,50,50'
#define C_RED_MED      C'220,40,40'
#define C_RED_DARK     C'80,15,15'
#define C_ORANGE_BRIGHT C'255,150,0'
#define C_ORANGE_MED   C'220,130,0'
#define C_YELLOW_BRIGHT C'255,240,0'
#define C_BLUE_BRIGHT  C'50,150,255'
#define C_PURPLE_BRIGHT C'180,80,255'
#define C_TEAL_BRIGHT  C'0,220,200'
#define C_SUBTEXT      C'100,130,180'
#define C_MGRAY        C'70,90,120'
#define C_DGRAY        C'30,45,70'
#define C_BAR_EMPTY    C'20,30,55'

//=====================================================================
//  GLOBAL OBJECTS
//=====================================================================
CTrade        g_trade;
CPositionInfo g_pos;
CAccountInfo  g_account;

// Indicator handles
int g_h1_ema_fast,  g_h1_ema_slow,  g_h1_atr;
int g_m15_ema_fast, g_m15_ema_slow, g_m15_atr, g_m15_rsi;
int g_m5_ema_fast,  g_m5_ema_slow,  g_m5_atr,  g_m5_rsi;
int g_m1_ema_fast,  g_m1_ema_slow,  g_m1_atr;

// Additional indicators
int g_m5_stoch, g_m5_bb, g_m5_cci, g_m5_macd;
int g_m15_stoch, g_m15_bb;

// Indicator states
IndicatorState g_ind_states[20];

RegimeState      g_regime;
VolatilityState  g_vol;
LiquidityState   g_liq;
SessionState     g_session;
MTFBias          g_mtf;
ENUM_NEWS_STATE  g_newsState  = NEWS_NORMAL;
RiskState        g_risk;
MasterDecision   g_lastDecision;
StrategyHealth   g_health[5];
ExecutionQuality g_execQuality;
MarketScores     g_scores;
LearningData     g_learning;

PositionManager  g_positions[10];
int              g_positionCount = 0;

datetime g_dayStart       = 0;
datetime g_weekStart      = 0;
int      g_tradesToday    = 0;
datetime g_lastCloseTime  = 0;
bool     g_inCooldown     = false;
int      g_cooldownLeft   = 0;
datetime g_lastBarTime    = 0;
datetime g_lastNarrative  = 0;
datetime g_lastFullUpdate = 0;

double g_adaptiveRegimeConfThreshold = 55.0;
double g_adaptiveExecScoreThreshold  = 50.0;

string g_statusText  = "INITIALIZING";
color  g_statusColor = C_ORANGE_BRIGHT;
string g_lastAction  = "Starting...";

double g_sessionProfit = 0.0;
int    g_sessionWins   = 0;
int    g_sessionLosses = 0;

double g_spreadHistory[50];
int    g_spreadHistCount  = 0;
double g_regimeStreakBars  = 0;
ENUM_REGIME g_regimePersistTrack = REGIME_RANGING;

string g_narrativeLine1 = "Initializing market analysis...";
string g_narrativeLine2 = "Building intelligence buffers.";
string g_narrativeLine3 = "Please wait for data.";
string g_narrativeLine4 = "";
string g_narrativeLine5 = "";
string g_narrativeLine6 = "";

double g_scale  = 1.0;
int    g_dashH  = 0;

bool   g_indicatorsReady = false;
int    g_tickCounter = 0;
datetime g_lastTickTime = 0;

//=====================================================================
//  UTILITY FUNCTIONS
//=====================================================================
int S(int px)  { return (int)MathRound(px * g_scale); }
int FS(int sz) { return MathMax(6, (int)MathRound(sz * g_scale)); }

color ScoreColor(double v)
{
   if(v >= 80) return C_GREEN_BRIGHT;
   if(v >= 60) return C_ORANGE_BRIGHT;
   return C_RED_BRIGHT;
}

datetime DayStart(datetime ts)
{
   MqlDateTime d; TimeToStruct(ts, d);
   return ts - (datetime)(d.hour * 3600 + d.min * 60 + d.sec);
}

datetime WeekStart(datetime ts)
{
   MqlDateTime d; TimeToStruct(ts, d);
   datetime ds = DayStart(ts);
   int off = (d.day_of_week == 0) ? 6 : (d.day_of_week - 1);
   return ds - (datetime)(off * 86400);
}

double NPrice(double p)
{
   return NormalizeDouble(p, (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS));
}

ENUM_ORDER_TYPE_FILLING GetFillMode()
{
   uint f = (uint)SymbolInfoInteger(_Symbol, SYMBOL_FILLING_MODE);
   if((f & SYMBOL_FILLING_FOK) != 0) return ORDER_FILLING_FOK;
   if((f & SYMBOL_FILLING_IOC) != 0) return ORDER_FILLING_IOC;
   return ORDER_FILLING_RETURN;
}

bool IsNewBar()
{
   datetime t = iTime(_Symbol, PERIOD_M5, 0);
   if(t != g_lastBarTime) { g_lastBarTime = t; return true; }
   return false;
}

int SafeBar(datetime t)
{
   datetime now = TimeCurrent();
   if(t > now) t = now;
   int b = iBarShift(_Symbol, PERIOD_M5, t, false);
   return (b < 0) ? 0 : b;
}

//=====================================================================
//  INDICATOR READINESS SYSTEM
//=====================================================================
void InitIndicatorStates()
{
   for(int i = 0; i < 20; i++)
   {
      g_ind_states[i].ready = false;
      g_ind_states[i].handle = INVALID_HANDLE;
      g_ind_states[i].lastUpdate = 0;
      g_ind_states[i].bufferSize = 0;
   }
}

bool CheckIndicatorReady(int handle, int minBars = 10)
{
   if(handle == INVALID_HANDLE) return false;
   
   double test[];
   ArraySetAsSeries(test, true);
   int copied = CopyBuffer(handle, 0, 0, minBars, test);
   
   if(copied < minBars) return false;
   
   // Check for valid values
   for(int i = 0; i < copied; i++)
   {
      if(test[i] == 0 || test[i] == EMPTY_VALUE) return false;
   }
   
   return true;
}

bool AllIndicatorsReady()
{
   if(!CheckIndicatorReady(g_h1_ema_fast, 5))  return false;
   if(!CheckIndicatorReady(g_h1_ema_slow, 5))  return false;
   if(!CheckIndicatorReady(g_h1_atr, 5))       return false;
   if(!CheckIndicatorReady(g_m15_ema_fast, 5)) return false;
   if(!CheckIndicatorReady(g_m15_ema_slow, 5)) return false;
   if(!CheckIndicatorReady(g_m15_atr, 5))      return false;
   if(!CheckIndicatorReady(g_m15_rsi, 5))      return false;
   if(!CheckIndicatorReady(g_m5_ema_fast, 10)) return false;
   if(!CheckIndicatorReady(g_m5_ema_slow, 10)) return false;
   if(!CheckIndicatorReady(g_m5_atr, 10))      return false;
   if(!CheckIndicatorReady(g_m5_rsi, 10))      return false;
   if(!CheckIndicatorReady(g_m1_ema_fast, 5))  return false;
   if(!CheckIndicatorReady(g_m1_ema_slow, 5))  return false;
   if(!CheckIndicatorReady(g_m1_atr, 5))       return false;
   
   // Check additional indicators if enabled
   if(InpUseStochastic && !CheckIndicatorReady(g_m5_stoch, 5)) return false;
   if(InpUseBollingerBands && !CheckIndicatorReady(g_m5_bb, 5)) return false;
   if(InpUseMACD && !CheckIndicatorReady(g_m5_macd, 5)) return false;
   
   return true;
}

//=====================================================================
//  SESSION ENGINE
//=====================================================================
ENUM_SESSION ClassifySession(datetime ts)
{
   MqlDateTime d; TimeToStruct(ts, d);
   int h = (d.hour - InpBrokerGMTOffset + 24) % 24;
   if(h >= 0  && h < 7)  return SESSION_ASIAN;
   if(h >= 7  && h < 10) return SESSION_LONDON_OPEN;
   if(h >= 10 && h < 12) return SESSION_LONDON_MID;
   if(h >= 12 && h < 15) return SESSION_NY_OPEN;
   if(h >= 15 && h < 21) return SESSION_NY_PM;
   return SESSION_DEAD_ZONE;
}

void SessionHourBand(ENUM_SESSION s, int &sh, int &eh)
{
   switch(s)
   {
      case SESSION_ASIAN:       sh = 0;  eh = 7;  break;
      case SESSION_LONDON_OPEN: sh = 7;  eh = 10; break;
      case SESSION_LONDON_MID:  sh = 10; eh = 12; break;
      case SESSION_NY_OPEN:     sh = 12; eh = 15; break;
      case SESSION_NY_PM:       sh = 15; eh = 21; break;
      default:                  sh = 21; eh = 24; break;
   }
}

string SessionToString(ENUM_SESSION s)
{
   switch(s)
   {
      case SESSION_ASIAN:       return "ASIAN";
      case SESSION_LONDON_OPEN: return "LONDON OPEN";
      case SESSION_LONDON_MID:  return "LONDON MID";
      case SESSION_NY_OPEN:     return "NEW YORK OPEN";
      case SESSION_NY_PM:       return "NEW YORK PM";
      default:                  return "DEAD ZONE";
   }
}

string SessionOverlapString(ENUM_SESSION s)
{
   if(s == SESSION_NY_OPEN)     return "LONDON-NY OVERLAP";
   if(s == SESSION_LONDON_OPEN) return "LONDON OPEN";
   return SessionToString(s);
}

void UpdateSessionIntelligence()
{
   ENUM_SESSION newSession = ClassifySession(TimeCurrent());
   
   if(newSession != g_session.current)
   {
      g_session.previous = g_session.current;
      g_session.current = newSession;
      g_session.sessionStartTime = TimeCurrent();
      g_session.transitionDetected = true;
      
      Print("SESSION TRANSITION: ", SessionToString(g_session.previous), 
            " → ", SessionToString(g_session.current));
   }
   else
   {
      g_session.transitionDetected = false;
   }
   
   double atrM5[1];
   if(CopyBuffer(g_m5_atr, 0, 0, 1, atrM5) <= 0) atrM5[0] = 0.0001;

   double hi = iHigh(_Symbol, PERIOD_M5, 0);
   double lo = iLow(_Symbol,  PERIOD_M5, 0);
   for(int i = 1; i < 12; i++)
   {
      hi = MathMax(hi, iHigh(_Symbol, PERIOD_M5, i));
      lo = MathMin(lo, iLow(_Symbol,  PERIOD_M5, i));
   }
   g_session.sessionRangeATRRatio   = (atrM5[0] > 0) ? (hi - lo) / atrM5[0] : 0.0;
   g_session.sessionVolatilityScore = MathMin(100.0, g_session.sessionRangeATRRatio * 25.0);

   switch(g_session.current)
   {
      case SESSION_ASIAN:
         g_session.preferredStrategy = STRAT_MEAN_REVERSION;
         g_session.strategyWeight    = 1.1;  break;
      case SESSION_LONDON_OPEN:
         g_session.preferredStrategy = STRAT_VOLATILITY_EXPANSION;
         g_session.strategyWeight    = 1.3;  break;
      case SESSION_LONDON_MID:
         g_session.preferredStrategy = STRAT_TREND_SCALPER;
         g_session.strategyWeight    = 1.0;  break;
      case SESSION_NY_OPEN:
         g_session.preferredStrategy = STRAT_LIQUIDITY_REVERSAL;
         g_session.strategyWeight    = 1.25; break;
      case SESSION_NY_PM:
         g_session.preferredStrategy = STRAT_TREND_SCALPER;
         g_session.strategyWeight    = 0.9;  break;
      default:
         g_session.preferredStrategy = STRAT_NONE;
         g_session.strategyWeight    = 0.5;  break;
   }
}

//=====================================================================
//  MTF BIAS ENGINE (FIXED)
//=====================================================================
int ComputeTFBias(int fast, int slow)
{
   if(fast == INVALID_HANDLE || slow == INVALID_HANDLE) return 0;
   
   double fn[3], sn[3];
   ArraySetAsSeries(fn, true);
   ArraySetAsSeries(sn, true);
   
   if(CopyBuffer(fast, 0, 0, 3, fn) < 3) return 0;
   if(CopyBuffer(slow, 0, 0, 3, sn) < 3) return 0;
   
   // Validate data
   for(int i = 0; i < 3; i++)
   {
      if(fn[i] == 0 || fn[i] == EMPTY_VALUE) return 0;
      if(sn[i] == 0 || sn[i] == EMPTY_VALUE) return 0;
   }
   
   double spNow = fn[0] - sn[0];
   double spPrv = fn[1] - sn[1];
   int dir = (fn[0] > sn[0]) ? 1 : (fn[0] < sn[0] ? -1 : 0);
   
   if(dir == 0) return 0;
   
   // Ensure momentum is increasing
   if(MathAbs(spNow) < MathAbs(spPrv) * 0.8) return 0;
   
   return dir;
}

void UpdateMTFBias()
{
   g_mtf.h1Bias  = ComputeTFBias(g_h1_ema_fast,  g_h1_ema_slow);
   g_mtf.m15Bias = ComputeTFBias(g_m15_ema_fast, g_m15_ema_slow);
   g_mtf.m5Bias  = ComputeTFBias(g_m5_ema_fast,  g_m5_ema_slow);
   g_mtf.m1Bias  = ComputeTFBias(g_m1_ema_fast,  g_m1_ema_slow);

   int biases[4] = {g_mtf.h1Bias, g_mtf.m15Bias, g_mtf.m5Bias, g_mtf.m1Bias};
   int agree = 0, nonzero = 0, refDir = 0;
   for(int i = 0; i < 4; i++)
   {
      if(biases[i] != 0)
      {
         nonzero++;
         if(refDir == 0) refDir = biases[i];
         else if(biases[i] == refDir) agree++;
      }
   }
   g_mtf.alignment = (nonzero > 1)
      ? (100.0 * (double)(agree + 1) / (double)nonzero)
      : (nonzero == 1 ? 50.0 : 0.0);
   
   g_mtf.strength = (nonzero > 0) ? (100.0 * (double)nonzero / 4.0) : 0.0;
   g_mtf.ready = (nonzero >= 2);
}

//=====================================================================
//  STRUCTURE HELPERS (FIXED ARRAYS)
//=====================================================================
double StructureHH(int lb, int sh = 1)
{
   int idx = iHighest(_Symbol, PERIOD_M5, MODE_HIGH, lb, sh);
   return (idx >= 0) ? iHigh(_Symbol, PERIOD_M5, idx) : 0;
}

double StructureLL(int lb, int sh = 1)
{
   int idx = iLowest(_Symbol, PERIOD_M5, MODE_LOW, lb, sh);
   return (idx >= 0) ? iLow(_Symbol, PERIOD_M5, idx) : 0;
}

int FindSwingHighs(int lb, int wing, double &pr[], datetime &tm[], int maxR = 30)
{
   int cnt = 0;
   int prSize = ArraySize(pr);
   int tmSize = ArraySize(tm);
   int limit = MathMin(maxR, MathMin(prSize, tmSize));
   
   for(int i = wing; i < lb - wing && cnt < limit; i++)
   {
      double h = iHigh(_Symbol, PERIOD_M5, i);
      bool ok = true;
      for(int w = 1; w <= wing; w++)
      {
         if(iHigh(_Symbol, PERIOD_M5, i-w) >= h || iHigh(_Symbol, PERIOD_M5, i+w) >= h)
         { ok = false; break; }
      }
      if(ok) 
      { 
         pr[cnt] = h; 
         tm[cnt] = iTime(_Symbol, PERIOD_M5, i); 
         cnt++; 
      }
   }
   return cnt;
}

int FindSwingLows(int lb, int wing, double &pr[], datetime &tm[], int maxR = 30)
{
   int cnt = 0;
   int prSize = ArraySize(pr);
   int tmSize = ArraySize(tm);
   int limit = MathMin(maxR, MathMin(prSize, tmSize));
   
   for(int i = wing; i < lb - wing && cnt < limit; i++)
   {
      double l = iLow(_Symbol, PERIOD_M5, i);
      bool ok = true;
      for(int w = 1; w <= wing; w++)
      {
         if(iLow(_Symbol, PERIOD_M5, i-w) <= l || iLow(_Symbol, PERIOD_M5, i+w) <= l)
         { ok = false; break; }
      }
      if(ok) 
      { 
         pr[cnt] = l; 
         tm[cnt] = iTime(_Symbol, PERIOD_M5, i); 
         cnt++; 
      }
   }
   return cnt;
}

//=====================================================================
//  VOLATILITY ENGINE (ENHANCED)
//=====================================================================
void UpdateVolatilityIntelligence()
{
   double buf[];
   ArrayResize(buf, InpATRLookback);
   ArraySetAsSeries(buf, true);
   int got = CopyBuffer(g_m5_atr, 0, 0, InpATRLookback, buf);
   
   if(got < 10)
   {
      g_vol.state      = VOL_NORMAL;
      g_vol.dynamic    = VOLDYN_STABLE;
      g_vol.atrCurrent = 0.0001;
      g_vol.atrAvg     = 0.0001;
      g_vol.atrRatio   = 1.0;
      g_vol.ready      = false;
      return;
   }
   
   double cur = buf[0], sum = 0;
   int n = 0;
   for(int i = 0; i < got; i++) 
   { 
      if(buf[i] > 0 && buf[i] != EMPTY_VALUE)
      {
         sum += buf[i]; 
         n++; 
      }
   }
   double avg = (n > 0) ? sum / n : cur;
   if(avg <= 0) avg = 0.0001;

   g_vol.atrCurrent = cur;
   g_vol.atrAvg     = avg;
   g_vol.atrRatio   = cur / avg;

   // Get H1 and M15 ATR for context
   double atrH1[1], atrM15[1];
   if(CopyBuffer(g_h1_atr, 0, 0, 1, atrH1) > 0) g_vol.atrH1 = atrH1[0];
   if(CopyBuffer(g_m15_atr, 0, 0, 1, atrM15) > 0) g_vol.atrM15 = atrM15[0];

   int below = 0;
   for(int i = 0; i < got; i++) 
      if(buf[i] > 0 && buf[i] <= cur) below++;
   g_vol.percentile = (got > 0) ? (100.0 * below / got) : 50.0;

   if(g_vol.percentile < 25)      g_vol.state = VOL_LOW;
   else if(g_vol.percentile < 65) g_vol.state = VOL_NORMAL;
   else if(g_vol.percentile < 90) g_vol.state = VOL_HIGH;
   else                           g_vol.state = VOL_EXTREME;

   double prev = (got > 3) ? buf[3] : avg;
   double roc  = (prev > 0) ? (cur - prev) / prev : 0.0;

   if(g_vol.atrRatio >= InpShockATRMultiple) g_vol.dynamic = VOLDYN_SPIKE;
   else if(roc > 0.15)                       g_vol.dynamic = VOLDYN_EXPANDING;
   else if(roc < -0.15)                      g_vol.dynamic = VOLDYN_COMPRESSING;
   else                                      g_vol.dynamic = VOLDYN_STABLE;
   
   g_vol.ready = true;
}

string VolStateToString(ENUM_VOL_STATE v)
{
   switch(v)
   {
      case VOL_LOW:    return "LOW";
      case VOL_NORMAL: return "NORMAL";
      case VOL_HIGH:   return "HIGH";
      default:         return "EXTREME";
   }
}

string VolDynamicToString(ENUM_VOL_DYNAMIC v)
{
   switch(v)
   {
      case VOLDYN_EXPANDING:   return "EXPANDING";
      case VOLDYN_COMPRESSING: return "COMPRESSING";
      case VOLDYN_SPIKE:       return "SPIKE";
      default:                 return "STABLE";
   }
}

//=====================================================================
//  NEWS SHOCK PROXY (ENHANCED)
//=====================================================================
void UpdateNewsShockProxy()
{
   static datetime lastSample = 0;
   datetime now = TimeCurrent();
   
   if(now - lastSample >= 60)
   {
      lastSample = now;
      double sp = (double)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
      
      if(g_spreadHistCount < 50)
      {
         g_spreadHistory[g_spreadHistCount] = sp; 
         g_spreadHistCount++;
      }
      else
      {
         for(int i = 0; i < 49; i++) 
            g_spreadHistory[i] = g_spreadHistory[i+1];
         g_spreadHistory[49] = sp;
      }
   }
   
   double sum = 0;
   for(int i = 0; i < g_spreadHistCount; i++) sum += g_spreadHistory[i];
   double avg    = (g_spreadHistCount > 0) ? sum / g_spreadHistCount : 1.0;
   double spNow  = (double)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   double spR    = (avg > 0) ? spNow / avg : 1.0;
   
   double barR   = iHigh(_Symbol, PERIOD_M5, 0) - iLow(_Symbol, PERIOD_M5, 0);
   double barRat = (g_vol.atrAvg > 0) ? barR / g_vol.atrAvg : 1.0;
   
   int sigs = (g_vol.atrRatio >= InpShockATRMultiple ? 1 : 0)
            + (spR            >= InpShockSpreadMultiple ? 1 : 0)
            + (barRat         >= InpShockATRMultiple ? 1 : 0);
   
   g_newsState = (sigs >= 2) ? NEWS_SHOCK : (sigs == 1 ? NEWS_CAUTION : NEWS_NORMAL);
}

string NewsToString(ENUM_NEWS_STATE n)
{
   switch(n)
   {
      case NEWS_CAUTION: return "CAUTION";
      case NEWS_SHOCK:   return "SHOCK DETECTED";
      default:           return "CLEAR";
   }
}

//=====================================================================
//  LIQUIDITY ENGINE (ENHANCED)
//=====================================================================
void UpdateLiquidityIntelligence()
{
   double shP[30], slP[30];
   datetime shT[30], slT[30];
   ArrayResize(shP, 30);
   ArrayResize(slP, 30);
   ArrayResize(shT, 30);
   ArrayResize(slT, 30);
   
   int nH = FindSwingHighs(MathMin(InpLiquidityLookback, 55), 2, shP, shT, 30);
   int nL = FindSwingLows(MathMin(InpLiquidityLookback, 55),  2, slP, slT, 30);

   double px  = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double tol = px * (InpEqualLevelTolerance / 100.0);

   // Equal highs
   g_liq.equalHighsDetected = false; 
   g_liq.equalHighLevel = 0;
   g_liq.bslCount = 0;
   int bHC = 0;
   for(int i = 0; i < nH; i++)
   {
      int cc = 1; 
      double sl2 = shP[i];
      for(int j = 0; j < nH; j++)
      {
         if(j == i) continue;
         if(MathAbs(shP[j] - shP[i]) <= tol) 
         { 
            cc++; 
            sl2 += shP[j]; 
         }
      }
      if(cc >= 2 && cc > bHC) 
      { 
         bHC = cc; 
         g_liq.equalHighLevel = sl2 / cc; 
         g_liq.equalHighsDetected = true; 
         g_liq.bslCount = cc;
      }
   }
   
   // Equal lows
   g_liq.equalLowsDetected = false; 
   g_liq.equalLowLevel = 0;
   g_liq.sslCount = 0;
   int bLC = 0;
   for(int i = 0; i < nL; i++)
   {
      int cc = 1; 
      double sl2 = slP[i];
      for(int j = 0; j < nL; j++)
      {
         if(j == i) continue;
         if(MathAbs(slP[j] - slP[i]) <= tol) 
         { 
            cc++; 
            sl2 += slP[j]; 
         }
      }
      if(cc >= 2 && cc > bLC) 
      { 
         bLC = cc; 
         g_liq.equalLowLevel = sl2 / cc; 
         g_liq.equalLowsDetected = true; 
         g_liq.sslCount = cc;
      }
   }
   
   // Sweeps
   g_liq.sweepUpDetected = false; 
   g_liq.sweepDownDetected = false;
   if(g_liq.equalHighsDetected)
   {
      for(int i = 0; i < 5; i++)
      {
         if(iHigh(_Symbol, PERIOD_M5, i) > g_liq.equalHighLevel
         && iClose(_Symbol,PERIOD_M5, i) < g_liq.equalHighLevel)
         { 
            g_liq.sweepUpDetected = true; 
            break; 
         }
      }
   }
   if(g_liq.equalLowsDetected)
   {
      for(int i = 0; i < 5; i++)
      {
         if(iLow(_Symbol,  PERIOD_M5, i) < g_liq.equalLowLevel
         && iClose(_Symbol, PERIOD_M5, i) > g_liq.equalLowLevel)
         { 
            g_liq.sweepDownDetected = true; 
            break; 
         }
      }
   }

   double dH = g_liq.equalHighsDetected ? MathAbs(px - g_liq.equalHighLevel) : -1;
   double dL = g_liq.equalLowsDetected  ? MathAbs(px - g_liq.equalLowLevel)  : -1;
   double prox = 0;
   if(dH >= 0 && g_vol.atrAvg > 0) 
      prox = MathMax(prox, 100.0 * MathMax(0.0, 1.0 - dH / (g_vol.atrAvg * 1.5)));
   if(dL >= 0 && g_vol.atrAvg > 0) 
      prox = MathMax(prox, 100.0 * MathMax(0.0, 1.0 - dL / (g_vol.atrAvg * 1.5)));
   g_liq.sweepProbability = MathMin(100.0, prox);

   double bias = 0;
   if(dH >= 0 && dL >= 0) bias = (dL < dH) ? -40.0 : 40.0;
   else if(dH >= 0)       bias = 40.0;
   else if(dL >= 0)       bias = -40.0;
   if(g_liq.sweepUpDetected)   bias = -70.0;
   if(g_liq.sweepDownDetected) bias =  70.0;

   g_liq.biasScore     = bias;
   g_liq.pressureScore = MathMin(100.0, (double)(bHC + bLC) * 12.0 + g_liq.sweepProbability * 0.3);
   g_liq.imbalanceScore= MathMin(100.0, MathAbs((double)(bHC - bLC)) * 20.0);
}

string LiquidityStatusString()
{
   if(g_liq.sweepUpDetected)   return "BUY SIDE SWEEP";
   if(g_liq.sweepDownDetected) return "SELL SIDE SWEEP";
   if(g_liq.equalHighsDetected && g_liq.equalLowsDetected) return "DUAL POOLS";
   if(g_liq.equalHighsDetected) return "BSL (" + IntegerToString(g_liq.bslCount) + ")";
   if(g_liq.equalLowsDetected)  return "SSL (" + IntegerToString(g_liq.sslCount) + ")";
   return "NO CLUSTER";
}

//=====================================================================
//  REGIME CLASSIFICATION (ENHANCED)
//=====================================================================
double ScoreTrending()
{
   double s = g_mtf.alignment * 0.5;
   if(g_mtf.m5Bias != 0 && g_mtf.m5Bias == g_mtf.h1Bias) s += 25;
   if(g_vol.state == VOL_NORMAL || g_vol.state == VOL_HIGH) s += 15;
   if(g_vol.dynamic == VOLDYN_EXPANDING) s += 10;
   return MathMin(100.0, s);
}

double ScoreRanging()
{
   double s = 0;
   if(g_mtf.alignment < 40) s += 40;
   if(g_vol.state == VOL_LOW || g_vol.state == VOL_NORMAL) s += 25;
   if(g_vol.dynamic == VOLDYN_STABLE) s += 20;
   double hh = StructureHH(InpStructureLookback, 1);
   double ll = StructureLL(InpStructureLookback, 1);
   double mid = (hh + ll) / 2.0;
   double px  = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double rp  = (hh > ll) ? MathAbs(px - mid) / ((hh - ll) / 2.0) : 1.0;
   if(rp < 0.6) s += 15;
   return MathMin(100.0, s);
}

double ScoreBreakout()
{
   double s = 0;
   double hh = StructureHH(InpStructureLookback, 1);
   double ll = StructureLL(InpStructureLookback, 1);
   double px = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(px > hh || px < ll) s += 45;
   if(g_vol.dynamic == VOLDYN_EXPANDING) s += 25;
   if(g_vol.state == VOL_HIGH)           s += 15;
   if(g_mtf.alignment > 60)             s += 15;
   return MathMin(100.0, s);
}

double ScoreCompression()
{
   double s = 0;
   if(g_vol.state == VOL_LOW)              s += 35;
   if(g_vol.dynamic == VOLDYN_COMPRESSING) s += 35;
   if(g_vol.percentile < 15)              s += 20;
   if(g_mtf.alignment < 30)               s += 10;
   return MathMin(100.0, s);
}

double ScoreExpansion()
{
   double s = 0;
   if(g_vol.dynamic == VOLDYN_EXPANDING) s += 40;
   if(g_vol.state == VOL_HIGH)           s += 25;
   if(g_vol.atrRatio > 1.3)             s += 20;
   if(g_mtf.alignment > 50)             s += 15;
   return MathMin(100.0, s);
}

double ScoreVolShock()
{
   double s = 0;
   if(g_vol.dynamic == VOLDYN_SPIKE) s += 50;
   if(g_vol.state == VOL_EXTREME)    s += 30;
   if(g_newsState == NEWS_SHOCK)     s += 20;
   return MathMin(100.0, s);
}

double ScoreLiqSweep()
{
   double s = 0;
   if(g_liq.sweepUpDetected || g_liq.sweepDownDetected) s += 50;
   s += g_liq.sweepProbability * 0.3;
   s += g_liq.pressureScore    * 0.2;
   return MathMin(100.0, s);
}

double ScoreExhaustion()
{
   double s = 0;
   double rsiM5[1];
   ArraySetAsSeries(rsiM5, true);
   if(CopyBuffer(g_m5_rsi, 0, 0, 1, rsiM5) > 0 && (rsiM5[0] > 72 || rsiM5[0] < 28)) s += 35;
   if(g_vol.dynamic == VOLDYN_COMPRESSING && g_vol.atrRatio < 0.85) s += 25;
   if(g_mtf.m1Bias != 0 && g_mtf.m5Bias != 0 && g_mtf.m1Bias != g_mtf.m5Bias)       s += 20;
   return MathMin(100.0, s);
}

double ScoreMeanRev()
{
   double s = 0;
   double rsiM5[1];
   ArraySetAsSeries(rsiM5, true);
   if(CopyBuffer(g_m5_rsi, 0, 0, 1, rsiM5) > 0 && (rsiM5[0] > 70 || rsiM5[0] < 30)) s += 30;
   if(g_vol.state == VOL_NORMAL)                                s += 20;
   if(g_mtf.alignment < 45)                                     s += 25;
   if(g_liq.sweepUpDetected || g_liq.sweepDownDetected)         s += 15;
   return MathMin(100.0, s);
}

double ScoreUnsafe()
{
   double s = 0;
   if(g_newsState == NEWS_SHOCK)                                              s += 60;
   if(g_vol.state == VOL_EXTREME)                                             s += 25;
   if((double)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD) > InpMaxSpreadPoints) s += 30;
   return MathMin(100.0, s);
}

void UpdateRegimeClassification()
{
   ENUM_REGIME C[10] = {
      REGIME_TRENDING, REGIME_RANGING, REGIME_BREAKOUT, REGIME_COMPRESSION,
      REGIME_EXPANSION, REGIME_VOLATILITY_SHOCK, REGIME_LIQUIDITY_SWEEP,
      REGIME_EXHAUSTION, REGIME_MEAN_REVERSION, REGIME_UNSAFE
   };
   double sc[10];
   sc[0]=ScoreTrending(); sc[1]=ScoreRanging(); sc[2]=ScoreBreakout(); sc[3]=ScoreCompression();
   sc[4]=ScoreExpansion(); sc[5]=ScoreVolShock(); sc[6]=ScoreLiqSweep(); sc[7]=ScoreExhaustion();
   sc[8]=ScoreMeanRev();  sc[9]=ScoreUnsafe();

   int bi = 0; double bs = sc[0];
   for(int i = 1; i < 10; i++) 
      if(sc[i] > bs) { bs = sc[i]; bi = i; }
   if(sc[9] >= 55.0) { bi = 9; bs = sc[9]; }

   ENUM_REGIME nr = C[bi];
   if(nr == g_regimePersistTrack) 
      g_regimeStreakBars++;
   else
   {
      g_regime.barsSinceChange = 0;
      g_regimeStreakBars = 0; 
      g_regimePersistTrack = nr;
      g_regime.sinceTime = TimeCurrent();
      g_regime.previousRegime = g_regime.regime;
      
      Print("REGIME CHANGE: ", RegimeToString(g_regime.previousRegime), 
            " → ", RegimeToString(nr), " [Confidence: ", DoubleToString(bs, 1), "%]");
   }
   
   g_regime.regime     = nr;
   g_regime.confidence = bs;
   g_regime.stability  = MathMin(100.0, g_regimeStreakBars * 8.0);
   g_regime.barsSinceChange++;
}

string RegimeToString(ENUM_REGIME r)
{
   switch(r)
   {
      case REGIME_TRENDING:         return "TREND EXPANSION";
      case REGIME_RANGING:          return "RANGE BOUND";
      case REGIME_BREAKOUT:         return "BREAKOUT";
      case REGIME_COMPRESSION:      return "COMPRESSION";
      case REGIME_EXPANSION:        return "VOL EXPANSION";
      case REGIME_VOLATILITY_SHOCK: return "VOL SHOCK";
      case REGIME_LIQUIDITY_SWEEP:  return "LIQUIDITY HUNT";
      case REGIME_EXHAUSTION:       return "TREND EXHAUSTION";
      case REGIME_MEAN_REVERSION:   return "MEAN REVERSION";
      case REGIME_UNSAFE:           return "UNSAFE";
      default:                      return "UNDEFINED";
   }
}

color RegimeToColor(ENUM_REGIME r)
{
   switch(r)
   {
      case REGIME_TRENDING:         return C_GREEN_BRIGHT;
      case REGIME_RANGING:          return C_YELLOW_BRIGHT;
      case REGIME_BREAKOUT:         return C_ORANGE_BRIGHT;
      case REGIME_EXPANSION:        return C_ORANGE_BRIGHT;
      case REGIME_LIQUIDITY_SWEEP:  return C_PURPLE_BRIGHT;
      case REGIME_VOLATILITY_SHOCK: return C_RED_BRIGHT;
      case REGIME_UNSAFE:           return C_RED_BRIGHT;
      case REGIME_COMPRESSION:      return C_BLUE_BRIGHT;
      case REGIME_EXHAUSTION:       return C_ORANGE_MED;
      default:                      return C_TEAL_BRIGHT;
   }
}

//=====================================================================
//  MARKET SCORES (ENHANCED)
//=====================================================================
void UpdateMarketScores()
{
   double rsiM5[1];
   ArraySetAsSeries(rsiM5, true);
   if(CopyBuffer(g_m5_rsi, 0, 0, 1, rsiM5) <= 0) rsiM5[0] = 50;

   g_scores.trendScore    = MathMin(100.0, g_mtf.alignment * 0.6 + g_regime.confidence * 0.4);
   g_scores.liquidityScore= MathMin(100.0, g_liq.pressureScore * 0.5 + g_liq.sweepProbability * 0.3
                            + ((g_liq.sweepUpDetected || g_liq.sweepDownDetected) ? 20 : 0));
   g_scores.volumeScore   = MathMin(100.0, 50.0 + (g_vol.atrRatio - 1.0) * 50.0);

   double ss = 60;
   if(g_session.current == SESSION_NY_OPEN || g_session.current == SESSION_LONDON_OPEN)     ss = 95;
   else if(g_session.current == SESSION_LONDON_MID || g_session.current == SESSION_NY_PM)   ss = 80;
   else if(g_session.current == SESSION_ASIAN) ss = 65;
   else ss = 30;
   
   g_scores.sessionScore   = ss;
   g_scores.structureClarity = MathMin(100.0, g_regime.stability * 0.5 + g_mtf.alignment * 0.5);
   g_scores.momentumScore  = MathMin(100.0, MathAbs(rsiM5[0] - 50.0) * 2.0);
   g_scores.volatilityScore= (g_vol.state == VOL_NORMAL) ? 90.0
                            : (g_vol.state == VOL_HIGH)   ? 75.0
                            : (g_vol.state == VOL_LOW)    ? 55.0 : 25.0;
   g_scores.structureScore = g_scores.structureClarity;
   
   g_scores.totalScore     = MathMin(100.0,
      g_scores.trendScore      * 0.20 +
      g_scores.liquidityScore  * 0.20 +
      g_scores.volumeScore     * 0.15 +
      g_scores.sessionScore    * 0.15 +
      g_scores.structureScore  * 0.15 +
      g_scores.momentumScore   * 0.10 +
      g_scores.volatilityScore * 0.05);
   
   g_scores.lastUpdate = TimeCurrent();
}

//=====================================================================
//  ADDITIONAL INDICATORS (STOCHASTIC, BOLLINGER, MACD)
//=====================================================================
bool CheckStochastic(ENUM_DIRECTION &dir, double &confidence)
{
   if(!InpUseStochastic || g_m5_stoch == INVALID_HANDLE) return false;
   
   double main[3], signal[3];
   ArraySetAsSeries(main, true);
   ArraySetAsSeries(signal, true);
   
   if(CopyBuffer(g_m5_stoch, 0, 0, 3, main) < 3) return false;
   if(CopyBuffer(g_m5_stoch, 1, 0, 3, signal) < 3) return false;
   
   // Oversold crossover
   if(main[1] < 20 && signal[1] < 20 && main[0] > signal[0] && main[1] <= signal[1])
   {
      dir = DIR_LONG;
      confidence = 100.0 - main[0];
      return true;
   }
   
   // Overbought crossover
   if(main[1] > 80 && signal[1] > 80 && main[0] < signal[0] && main[1] >= signal[1])
   {
      dir = DIR_SHORT;
      confidence = main[0];
      return true;
   }
   
   return false;
}

bool CheckBollingerBands(ENUM_DIRECTION &dir, double &confidence)
{
   if(!InpUseBollingerBands || g_m5_bb == INVALID_HANDLE) return false;
   
   double upper[2], middle[2], lower[2];
   ArraySetAsSeries(upper, true);
   ArraySetAsSeries(middle, true);
   ArraySetAsSeries(lower, true);
   
   if(CopyBuffer(g_m5_bb, 0, 0, 2, middle) < 2) return false;
   if(CopyBuffer(g_m5_bb, 1, 0, 2, upper) < 2) return false;
   if(CopyBuffer(g_m5_bb, 2, 0, 2, lower) < 2) return false;
   
   double close0 = iClose(_Symbol, PERIOD_M5, 0);
   double close1 = iClose(_Symbol, PERIOD_M5, 1);
   
   // Bounce from lower band
   if(close1 <= lower[1] && close0 > lower[0])
   {
      dir = DIR_LONG;
      double bandWidth = upper[0] - lower[0];
      confidence = (bandWidth > 0) ? ((middle[0] - lower[0]) / bandWidth * 100.0) : 50.0;
      return true;
   }
   
   // Bounce from upper band
   if(close1 >= upper[1] && close0 < upper[0])
   {
      dir = DIR_SHORT;
      double bandWidth = upper[0] - lower[0];
      confidence = (bandWidth > 0) ? ((upper[0] - middle[0]) / bandWidth * 100.0) : 50.0;
      return true;
   }
   
   return false;
}

bool CheckMACD(ENUM_DIRECTION &dir, double &confidence)
{
   if(!InpUseMACD || g_m5_macd == INVALID_HANDLE) return false;
   
   double main[3], signal[3];
   ArraySetAsSeries(main, true);
   ArraySetAsSeries(signal, true);
   
   if(CopyBuffer(g_m5_macd, 0, 0, 3, main) < 3) return false;
   if(CopyBuffer(g_m5_macd, 1, 0, 3, signal) < 3) return false;
   
   // Bullish crossover
   if(main[0] > signal[0] && main[1] <= signal[1] && main[0] < 0)
   {
      dir = DIR_LONG;
      confidence = MathMin(100.0, MathAbs(main[0] - signal[0]) * 1000.0);
      return true;
   }
   
   // Bearish crossover
   if(main[0] < signal[0] && main[1] >= signal[1] && main[0] > 0)
   {
      dir = DIR_SHORT;
      confidence = MathMin(100.0, MathAbs(main[0] - signal[0]) * 1000.0);
      return true;
   }
   
   return false;
}

//=====================================================================
//  STRATEGY MODULES (FIXED WITH 1:2 RR)
//=====================================================================
StrategySignal Strategy_TrendScalper()
{
   StrategySignal s;
   s.source = STRAT_TREND_SCALPER; 
   s.direction = DIR_NONE; 
   s.valid = false; 
   s.reason = "";
   s.timestamp = TimeCurrent();
   
   // More aggressive entry conditions
   if(g_mtf.alignment < 50) { s.reason = "MTF align too low"; return s; }
   
   int dir = (g_mtf.h1Bias != 0) ? g_mtf.h1Bias : g_mtf.m15Bias;
   if(dir == 0) { s.reason = "No macro bias"; return s; }
   
   // Allow M5 to be slightly misaligned for faster entries
   if(g_mtf.m5Bias != 0 && g_mtf.m5Bias != dir)
   {
      if(g_mtf.m1Bias != dir) { s.reason = "M5 counter-trend"; return s; }
   }
   
   double atr   = g_vol.atrCurrent;
   if(atr <= 0) { s.reason = "Invalid ATR"; return s; }
   
   double price = (dir > 0) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   
   s.direction   = (dir > 0) ? DIR_LONG : DIR_SHORT;
   s.suggestedEntry = price;
   
   // 1:2 Risk:Reward
   s.suggestedSL = (dir > 0) ? NPrice(price - atr * 1.0) : NPrice(price + atr * 1.0);
   s.suggestedTP = (dir > 0) ? NPrice(price + atr * 2.0) : NPrice(price - atr * 2.0);
   
   double slDist = MathAbs(price - s.suggestedSL);
   double tpDist = MathAbs(s.suggestedTP - price);
   s.riskReward = (slDist > 0) ? tpDist / slDist : 2.0;
   
   s.confidence  = MathMin(95.0, g_mtf.alignment * 0.8 + g_regime.confidence * 0.2);
   s.reason = "Trend Pullback Entry";
   s.valid  = true;
   
   return s;
}

StrategySignal Strategy_MeanReversion()
{
   StrategySignal s;
   s.source = STRAT_MEAN_REVERSION; 
   s.direction = DIR_NONE; 
   s.valid = false; 
   s.reason = "";
   s.timestamp = TimeCurrent();
   
   double rsiM5[1];
   ArraySetAsSeries(rsiM5, true);
   if(CopyBuffer(g_m5_rsi, 0, 0, 1, rsiM5) <= 0) { s.reason = "RSI unavailable"; return s; }
   
   bool ob = rsiM5[0] > 68, os = rsiM5[0] < 32;
   if(!ob && !os) { s.reason = "RSI not extended"; return s; }
   
   double hh  = StructureHH(InpStructureLookback, 1);
   double ll  = StructureLL(InpStructureLookback, 1);
   if(hh <= ll) { s.reason = "Invalid structure"; return s; }
   
   double mid = (hh + ll) / 2.0;
   double atr = g_vol.atrCurrent;
   if(atr <= 0) { s.reason = "Invalid ATR"; return s; }
   
   if(ob)
   {
      double ep = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      s.direction   = DIR_SHORT;
      s.suggestedEntry = ep;
      s.suggestedSL = NPrice(ep + atr * 1.0);
      s.suggestedTP = NPrice(ep - atr * 2.0);
   }
   else
   {
      double ep = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      s.direction   = DIR_LONG;
      s.suggestedEntry = ep;
      s.suggestedSL = NPrice(ep - atr * 1.0);
      s.suggestedTP = NPrice(ep + atr * 2.0);
   }
   
   double slDist = MathAbs(s.suggestedEntry - s.suggestedSL);
   double tpDist = MathAbs(s.suggestedTP - s.suggestedEntry);
   s.riskReward = (slDist > 0) ? tpDist / slDist : 2.0;
   
   s.confidence = MathMin(90.0, MathAbs(rsiM5[0] - 50.0) * 1.8);
   s.reason = "Mean Reversion Setup";
   s.valid  = true;
   
   return s;
}

StrategySignal Strategy_VolatilityExpansion()
{
   StrategySignal s;
   s.source = STRAT_VOLATILITY_EXPANSION; 
   s.direction = DIR_NONE; 
   s.valid = false; 
   s.reason = "";
   s.timestamp = TimeCurrent();
   
   if(g_vol.dynamic != VOLDYN_EXPANDING && g_vol.state != VOL_HIGH) 
   { 
      s.reason = "Not expanding"; 
      return s; 
   }
   
   double hh  = StructureHH(InpStructureLookback, 1);
   double ll  = StructureLL(InpStructureLookback, 1);
   if(hh <= ll) { s.reason = "Invalid structure"; return s; }
   
   double px  = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double atr = g_vol.atrCurrent;
   if(atr <= 0) { s.reason = "Invalid ATR"; return s; }
   
   bool bU = px > hh * 0.999, bD = px < ll * 1.001;
   if(!bU && !bD) { s.reason = "No breakout"; return s; }
   
   if(bU)
   {
      double ep = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      s.direction   = DIR_LONG;
      s.suggestedEntry = ep;
      s.suggestedSL = NPrice(hh - atr * 0.5);
      s.suggestedTP = NPrice(ep + atr * 2.5);
   }
   else
   {
      double ep = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      s.direction   = DIR_SHORT;
      s.suggestedEntry = ep;
      s.suggestedSL = NPrice(ll + atr * 0.5);
      s.suggestedTP = NPrice(ep - atr * 2.5);
   }
   
   double slDist = MathAbs(s.suggestedEntry - s.suggestedSL);
   double tpDist = MathAbs(s.suggestedTP - s.suggestedEntry);
   s.riskReward = (slDist > 0) ? tpDist / slDist : 2.5;
   
   s.confidence = MathMin(92.0, 50.0 + g_vol.atrRatio * 20.0 + g_mtf.alignment * 0.3);
   s.reason = "Expansion Breakout";
   s.valid  = true;
   
   return s;
}

StrategySignal Strategy_LiquidityReversal()
{
   StrategySignal s;
   s.source = STRAT_LIQUIDITY_REVERSAL; 
   s.direction = DIR_NONE; 
   s.valid = false; 
   s.reason = "";
   s.timestamp = TimeCurrent();
   
   if(!g_liq.sweepUpDetected && !g_liq.sweepDownDetected) 
   { 
      s.reason = "No sweep detected"; 
      return s; 
   }
   
   double atr = g_vol.atrCurrent;
   if(atr <= 0) { s.reason = "Invalid ATR"; return s; }
   
   if(g_liq.sweepUpDetected)
   {
      double ep = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      s.direction   = DIR_SHORT;
      s.suggestedEntry = ep;
      s.suggestedSL = NPrice(g_liq.equalHighLevel + atr * 0.4);
      s.suggestedTP = NPrice(ep - atr * 2.0);
   }
   else
   {
      double ep = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      s.direction   = DIR_LONG;
      s.suggestedEntry = ep;
      s.suggestedSL = NPrice(g_liq.equalLowLevel - atr * 0.4);
      s.suggestedTP = NPrice(ep + atr * 2.0);
   }
   
   double slDist = MathAbs(s.suggestedEntry - s.suggestedSL);
   double tpDist = MathAbs(s.suggestedTP - s.suggestedEntry);
   s.riskReward = (slDist > 0) ? tpDist / slDist : 2.0;
   
   s.confidence = MathMin(93.0, g_liq.sweepProbability * 0.5 + g_liq.pressureScore * 0.4 + 20);
   s.reason = "Liquidity Sweep Reversal";
   s.valid  = true;
   
   return s;
}

StrategySignal Strategy_CompressionBreakout()
{
   StrategySignal s;
   s.source = STRAT_COMPRESSION_BREAKOUT; 
   s.direction = DIR_NONE; 
   s.valid = false; 
   s.reason = "";
   s.timestamp = TimeCurrent();
   
   if(g_vol.state != VOL_LOW && g_vol.dynamic != VOLDYN_COMPRESSING)  
   { 
      s.reason = "Not compressed";      
      return s; 
   }
   
   if(g_mtf.m1Bias == 0 && g_mtf.m5Bias == 0)       
   { 
      s.reason = "No momentum";   
      return s; 
   }
   
   double hh = StructureHH(InpStructureLookback / 2, 1);
   double ll = StructureLL(InpStructureLookback / 2, 1);
   if(hh <= ll) { s.reason = "Invalid range"; return s; }
   
   double px = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double rs = hh - ll;
   double pos = (px - ll) / rs;
   
   int bias = (g_mtf.m1Bias != 0) ? g_mtf.m1Bias : g_mtf.m5Bias;
   
   if(pos > 0.65 && bias > 0)
   {
      double ep = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      s.direction   = DIR_LONG;
      s.suggestedEntry = ep;
      s.suggestedSL = NPrice(ll - rs * 0.1);
      s.suggestedTP = NPrice(ep + rs * 1.5);
   }
   else if(pos < 0.35 && bias < 0)
   {
      double ep = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      s.direction   = DIR_SHORT;
      s.suggestedEntry = ep;
      s.suggestedSL = NPrice(hh + rs * 0.1);
      s.suggestedTP = NPrice(ep - rs * 1.5);
   }
   else 
   { 
      s.reason = "Not at edge"; 
      return s; 
   }
   
   double slDist = MathAbs(s.suggestedEntry - s.suggestedSL);
   double tpDist = MathAbs(s.suggestedTP - s.suggestedEntry);
   s.riskReward = (slDist > 0) ? tpDist / slDist : 1.5;
   
   s.confidence = MathMin(88.0, 45.0 + (100.0 - g_vol.percentile) * 0.4 + g_mtf.strength * 0.2);
   s.reason = "Compression Breakout";
   s.valid  = true;
   
   return s;
}

ENUM_STRATEGY RouteRegimeToStrategy(ENUM_REGIME r)
{
   switch(r)
   {
      case REGIME_TRENDING:        return STRAT_TREND_SCALPER;
      case REGIME_RANGING:         return STRAT_MEAN_REVERSION;
      case REGIME_BREAKOUT:        return STRAT_VOLATILITY_EXPANSION;
      case REGIME_EXPANSION:       return STRAT_VOLATILITY_EXPANSION;
      case REGIME_LIQUIDITY_SWEEP: return STRAT_LIQUIDITY_REVERSAL;
      case REGIME_COMPRESSION:     return STRAT_COMPRESSION_BREAKOUT;
      case REGIME_MEAN_REVERSION:  return STRAT_MEAN_REVERSION;
      default:                     return STRAT_NONE;
   }
}

StrategySignal GetSignalForStrategy(ENUM_STRATEGY st)
{
   StrategySignal s;
   s.valid = false; 
   s.direction = DIR_NONE; 
   s.source = st; 
   s.reason = "None";
   s.timestamp = TimeCurrent();
   
   switch(st)
   {
      case STRAT_TREND_SCALPER:        return Strategy_TrendScalper();
      case STRAT_MEAN_REVERSION:       return Strategy_MeanReversion();
      case STRAT_VOLATILITY_EXPANSION: return Strategy_VolatilityExpansion();
      case STRAT_LIQUIDITY_REVERSAL:   return Strategy_LiquidityReversal();
      case STRAT_COMPRESSION_BREAKOUT: return Strategy_CompressionBreakout();
      default: return s;
   }
}

int StrategyHealthIndex(ENUM_STRATEGY s)
{
   switch(s)
   {
      case STRAT_TREND_SCALPER:        return 0;
      case STRAT_MEAN_REVERSION:       return 1;
      case STRAT_VOLATILITY_EXPANSION: return 2;
      case STRAT_LIQUIDITY_REVERSAL:   return 3;
      case STRAT_COMPRESSION_BREAKOUT: return 4;
      default:                         return -1;
   }
}

string StrategyToString(ENUM_STRATEGY s)
{
   switch(s)
   {
      case STRAT_TREND_SCALPER:        return "Trend Pullback";
      case STRAT_MEAN_REVERSION:       return "Mean Reversion";
      case STRAT_VOLATILITY_EXPANSION: return "Expansion Breakout";
      case STRAT_LIQUIDITY_REVERSAL:   return "Liquidity Reversal";
      case STRAT_COMPRESSION_BREAKOUT: return "Compression BO";
      default:                         return "No Strategy";
   }
}

string StrategyToShort(ENUM_STRATEGY s)
{
   switch(s)
   {
      case STRAT_TREND_SCALPER:        return "TREND";
      case STRAT_MEAN_REVERSION:       return "MEAN REV";
      case STRAT_VOLATILITY_EXPANSION: return "VOL EXP";
      case STRAT_LIQUIDITY_REVERSAL:   return "LIQ REV";
      case STRAT_COMPRESSION_BREAKOUT: return "COMP BO";
      default:                         return "NONE";
   }
}

//=====================================================================
//  EXECUTION QUALITY ENGINE (ENHANCED)
//=====================================================================
void UpdateExecutionQuality()
{
   double sp = (double)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   g_execQuality.currentSpread = sp;
   
   // Update average spread
   double sumSpr = 0;
   for(int i = 0; i < g_spreadHistCount; i++) sumSpr += g_spreadHistory[i];
   g_execQuality.avgSpread = (g_spreadHistCount > 0) ? sumSpr / g_spreadHistCount : sp;
   
   g_execQuality.spreadScore = MathMax(0.0, 100.0 * (1.0 - sp / InpMaxSpreadPoints));

   double slr = (g_newsState == NEWS_SHOCK) ? 90.0
              : (g_newsState == NEWS_CAUTION) ? 50.0
              : MathMin(40.0, sp / InpMaxSpreadPoints * 40.0);
   g_execQuality.slippageRiskScore = 100.0 - slr;

   double vq = (g_vol.state == VOL_EXTREME) ? 20.0
             : (g_vol.state == VOL_HIGH)    ? 65.0
             : (g_vol.state == VOL_LOW)     ? 80.0 : 100.0;
   g_execQuality.volatilityQuality = vq;

   double lq = (g_session.current == SESSION_DEAD_ZONE) ? 35.0
             : (g_session.current == SESSION_ASIAN)     ? 70.0 : 95.0;
   g_execQuality.liquidityQuality = lq;

   double ef = 100.0;
   if(g_vol.atrCurrent > 0 && g_vol.atrCurrent != EMPTY_VALUE)
   {
      double pt  = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
      if(pt > 0)
      {
         double sip = sp * pt;
         ef = MathMax(0.0, 100.0 * (1.0 - sip / g_vol.atrCurrent * 5.0));
      }
   }
   g_execQuality.efficiencyScore = ef;

   g_execQuality.compositeScore =
        g_execQuality.spreadScore       * 0.25
      + g_execQuality.slippageRiskScore * 0.25
      + g_execQuality.volatilityQuality * 0.20
      + g_execQuality.liquidityQuality  * 0.15
      + g_execQuality.efficiencyScore   * 0.15;

   g_execQuality.executionApproved = true;
   g_execQuality.rejectReason      = "";

   if(sp > InpMaxSpreadPoints)
      { g_execQuality.executionApproved = false; g_execQuality.rejectReason = "SPREAD TOO HIGH"; }
   else if(g_execQuality.compositeScore < g_adaptiveExecScoreThreshold)
      { g_execQuality.executionApproved = false; g_execQuality.rejectReason = "LOW EXEC QUALITY"; }
   else if(g_newsState == NEWS_SHOCK)
      { g_execQuality.executionApproved = false; g_execQuality.rejectReason = "NEWS SHOCK ACTIVE"; }
}

//=====================================================================
//  ADAPTIVE POSITION SIZING (ENHANCED)
//=====================================================================
double CalculateAdaptiveLotSize(StrategySignal &sig, double slP, double &outR)
{
   outR = 0.0;
   double eq = AccountInfoDouble(ACCOUNT_EQUITY);
   if(eq <= 0) return 0.0;
   
   double price = sig.suggestedEntry;
   double sld = MathAbs(price - slP);
   if(sld <= 0) return 0.0;

   double cf  = MathMax(0.5, MathMin(1.0, sig.confidence / 100.0));
   double rf  = MathMax(0.5, MathMin(1.0, (g_regime.confidence * 0.6 + g_regime.stability * 0.4) / 100.0));
   
   int    hi  = StrategyHealthIndex(sig.source);
   double hf  = (hi >= 0 && hi < 5) ? g_health[hi].influenceMultiplier : 1.0;
   
   double dd  = (InpMaxDrawdownPct > 0) ? (g_risk.currentDrawdownPct / InpMaxDrawdownPct) : 0.0;
   double df  = MathMax(0.25, 1.0 - dd);
   
   double rp  = InpRiskPercentPerTrade * cf * rf * hf * df;
   
   // Aggressive mode
   if(InpAggressiveMode && g_scores.totalScore > 75)
      rp *= 1.2;
   
   rp = MathMin(rp, InpMaxRiskPercentTrade);
   
   double ra  = eq * (rp / 100.0);

   double tv    = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double ts2   = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   if(tv <= 0 || ts2 <= 0) return 0.0;

   double vpu   = tv / ts2;
   double lot   = ra / (sld * vpu);
   
   double lmin  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double lmax  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double lstep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   
   lot = MathFloor(lot / lstep) * lstep;
   lot = MathMax(lmin, MathMin(lmax, lot));
   
   outR = lot * sld * vpu;
   
   return lot;
}

//=====================================================================
//  RISK GOVERNANCE ENGINE (ENHANCED)
//=====================================================================
void InitRiskState()
{
   double eq = AccountInfoDouble(ACCOUNT_EQUITY);
   g_risk.peakEquity         = eq;
   g_risk.dayStartEquity     = eq;
   g_risk.weekStartEquity    = eq;
   g_risk.currentEquity      = eq;
   g_risk.dailyLimitHit      = false;
   g_risk.weeklyLimitHit     = false;
   g_risk.maxDrawdownBreached= false;
   g_risk.emergencyShutdown  = false;
   g_risk.currentDrawdownPct = 0;
   g_risk.maxDrawdownSeenPct = 0;
   g_risk.dailyRiskUsedPct   = 0;
   g_risk.weeklyRiskUsedPct  = 0;
   g_risk.exposurePercent    = 0;

   string gv = "QPA2_ESD_" + IntegerToString((long)InpMagicNumber);
   if(GlobalVariableCheck(gv) && GlobalVariableGet(gv) > 0.0)
   {
      g_risk.emergencyShutdown    = true;
      g_risk.maxDrawdownBreached  = true;
      Print("WARNING: Emergency shutdown restored. Delete global variable to reset.");
   }
}

void UpdateRiskState()
{
   double eq = AccountInfoDouble(ACCOUNT_EQUITY);
   g_risk.currentEquity = eq;
   
   if(eq > g_risk.peakEquity) g_risk.peakEquity = eq;
   
   g_risk.currentDrawdownPct = (g_risk.peakEquity > 0)
      ? (g_risk.peakEquity - eq) / g_risk.peakEquity * 100.0 : 0.0;
   
   if(g_risk.currentDrawdownPct > g_risk.maxDrawdownSeenPct)
      g_risk.maxDrawdownSeenPct = g_risk.currentDrawdownPct;
   
   g_risk.dailyRiskUsedPct  = (g_risk.dayStartEquity > 0)
      ? MathMax(0.0, (g_risk.dayStartEquity - eq) / g_risk.dayStartEquity * 100.0) : 0.0;
   
   g_risk.weeklyRiskUsedPct = (g_risk.weekStartEquity > 0)
      ? MathMax(0.0, (g_risk.weekStartEquity - eq) / g_risk.weekStartEquity * 100.0) : 0.0;
   
   g_risk.dailyLimitHit  = (InpMaxDailyLossPct  > 0 && g_risk.dailyRiskUsedPct  >= InpMaxDailyLossPct);
   g_risk.weeklyLimitHit = (InpMaxWeeklyLossPct > 0 && g_risk.weeklyRiskUsedPct >= InpMaxWeeklyLossPct);
   
   if(InpMaxDrawdownPct > 0 && g_risk.currentDrawdownPct >= InpMaxDrawdownPct)
   {
      g_risk.maxDrawdownBreached = true;
      g_risk.emergencyShutdown   = true;
      GlobalVariableSet("QPA2_ESD_" + IntegerToString((long)InpMagicNumber), 1.0);
      Print("EMERGENCY SHUTDOWN: Max drawdown reached!");
   }
   
   // Calculate exposure
   double totalMargin = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(g_pos.SelectByIndex(i) && g_pos.Magic() == InpMagicNumber && g_pos.Symbol() == _Symbol)
      {
         totalMargin += g_pos.Volume() * g_pos.PriceOpen() * SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE) / SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
      }
   }
   g_risk.exposurePercent = (eq > 0) ? (totalMargin / eq * 100.0) : 0.0;
}

int PositionsTotalForMagic()
{
   int cnt = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
      if(g_pos.SelectByIndex(i) && g_pos.Magic() == InpMagicNumber && g_pos.Symbol() == _Symbol)
         cnt++;
   return cnt;
}

bool RiskGovernanceAllowsNewTrade(string &reason)
{
   if(g_risk.emergencyShutdown)   
   { 
      reason = "EMERGENCY SHUTDOWN";  
      return false; 
   }
   if(g_risk.dailyLimitHit)       
   { 
      reason = "DAILY LIMIT HIT";     
      return false; 
   }
   if(g_risk.weeklyLimitHit)      
   { 
      reason = "WEEKLY LIMIT HIT";    
      return false; 
   }
   if(InpMaxDailyTrades > 0 && g_tradesToday >= InpMaxDailyTrades)
   { 
      reason = "MAX DAILY TRADES";   
      return false; 
   }
   if(PositionsTotalForMagic() >= InpMaxConcurrentTrades)
   { 
      reason = "MAX POSITIONS";      
      return false; 
   }
   if(g_inCooldown)                
   { 
      reason = "COOLDOWN (" + IntegerToString(g_cooldownLeft) + "s)";    
      return false; 
   }
   
   return true;
}

void RolloverDailyWeeklyIfNeeded()
{
   datetime td = DayStart(TimeCurrent());
   datetime tw = WeekStart(TimeCurrent());
   
   if(td != g_dayStart)
   {
      Print("=== NEW TRADING DAY ===");
      Print("Previous day: Trades=", g_tradesToday, " P&L=", DoubleToString(g_sessionProfit, 2));
      
      g_dayStart            = td;
      g_tradesToday         = 0;
      g_risk.dayStartEquity = AccountInfoDouble(ACCOUNT_EQUITY);
      g_risk.dailyLimitHit  = false;
      g_sessionProfit       = 0;
      g_sessionWins         = 0;
      g_sessionLosses       = 0;
   }
   
   if(tw != g_weekStart)
   {
      Print("=== NEW TRADING WEEK ===");
      
      g_weekStart              = tw;
      g_risk.weekStartEquity   = AccountInfoDouble(ACCOUNT_EQUITY);
      g_risk.weeklyLimitHit    = false;
   }
}

//=====================================================================
//  STRATEGY HEALTH MONITOR (ENHANCED)
//=====================================================================
void InitStrategyHealth()
{
   string nm[5] = {"TrendScalp","MeanRev","VolExpand","LiqReversal","Compression"};
   for(int i = 0; i < 5; i++)
   {
      g_health[i].name               = nm[i];
      g_health[i].totalTrades        = 0;
      g_health[i].wins               = 0;
      g_health[i].losses             = 0;
      g_health[i].grossProfit        = 0;
      g_health[i].grossLoss          = 0;
      g_health[i].sumR               = 0;
      g_health[i].sumRSquared        = 0;
      g_health[i].consecLosses       = 0;
      g_health[i].maxConsecLosses    = 0;
      g_health[i].winRate            = 0;
      g_health[i].profitFactor       = 0;
      g_health[i].expectancyR        = 0;
      g_health[i].sharpeProxy        = 0;
      g_health[i].enabled            = true;
      g_health[i].influenceMultiplier= 1.0;
      g_health[i].lastDegradedTime   = 0;
      g_health[i].avgWin             = 0;
      g_health[i].avgLoss            = 0;
      g_health[i].recoveryFactor     = 1.0;
   }
}

void UpdateStrategyInfluence(int idx)
{
   if(idx < 0 || idx >= 5) return;
   
   if(g_health[idx].totalTrades < InpHealthMinTrades)
   {
      g_health[idx].influenceMultiplier = 1.0;
      g_health[idx].enabled = true;
      return;
   }
   
   double tm2 = 1.0;
   
   // Consecutive losses penalty
   if(g_health[idx].consecLosses >= InpHealthDegradeConsecLoss)           
      tm2 = MathMin(tm2, 0.6);
   
   // Expectancy penalty
   if(g_health[idx].expectancyR < InpHealthMinExpectancyR)                
      tm2 = MathMin(tm2, 0.5);
   
   // Profit factor penalty
   if(g_health[idx].profitFactor < 0.9)                                   
      tm2 = MathMin(tm2, 0.7);
   
   // Win rate penalty
   if(g_health[idx].winRate < 35.0)
      tm2 = MathMin(tm2, 0.6);
   
   // Severe degradation
   if(g_health[idx].consecLosses >= InpHealthDegradeConsecLoss * 2
   || g_health[idx].expectancyR  < InpHealthMinExpectancyR * 2.0)
   {
      g_health[idx].enabled = false; 
      tm2 = 0.0; 
      g_health[idx].lastDegradedTime = TimeCurrent();
      Print("Strategy ", g_health[idx].name, " DISABLED due to poor performance");
   }
   
   // Recovery mechanism
   if(!g_health[idx].enabled && TimeCurrent() - g_health[idx].lastDegradedTime > 3600)
   {
      if(g_health[idx].consecLosses == 0)
      {
         g_health[idx].enabled = true;
         tm2 = 0.5;
         Print("Strategy ", g_health[idx].name, " RE-ENABLED for testing");
      }
   }
   
   g_health[idx].influenceMultiplier += (tm2 - g_health[idx].influenceMultiplier) * 0.3;
   
   if(g_health[idx].influenceMultiplier > 0.8) 
      g_health[idx].enabled = true;
}

void RegisterTradeResult(ENUM_STRATEGY st, double pnl, double rm)
{
   int idx = StrategyHealthIndex(st);
   if(idx < 0 || idx >= 5) return;
   
   g_health[idx].totalTrades++;
   
   if(pnl >= 0) 
   { 
      g_health[idx].wins++;   
      g_health[idx].grossProfit += pnl;        
      g_health[idx].consecLosses = 0;
      g_health[idx].avgWin = g_health[idx].grossProfit / MathMax(1, g_health[idx].wins);
   }
   else         
   { 
      g_health[idx].losses++;  
      g_health[idx].grossLoss   += MathAbs(pnl); 
      g_health[idx].consecLosses++;
      g_health[idx].avgLoss = g_health[idx].grossLoss / MathMax(1, g_health[idx].losses);
      
      if(g_health[idx].consecLosses > g_health[idx].maxConsecLosses)
         g_health[idx].maxConsecLosses = g_health[idx].consecLosses;
   }
   
   g_health[idx].sumR        += rm;
   g_health[idx].sumRSquared += rm * rm;
   
   g_health[idx].winRate      = (g_health[idx].totalTrades > 0)
      ? 100.0 * g_health[idx].wins / g_health[idx].totalTrades : 0.0;
   
   g_health[idx].profitFactor = (g_health[idx].grossLoss > 0)
      ? g_health[idx].grossProfit / g_health[idx].grossLoss
      : (g_health[idx].grossProfit > 0 ? 99.0 : 0.0);
   
   g_health[idx].expectancyR  = (g_health[idx].totalTrades > 0)
      ? g_health[idx].sumR / g_health[idx].totalTrades : 0.0;
   
   if(g_health[idx].totalTrades > 1)
   {
      double mr  = g_health[idx].sumR / g_health[idx].totalTrades;
      double var = (g_health[idx].sumRSquared / g_health[idx].totalTrades) - (mr * mr);
      double sd  = (var > 0) ? MathSqrt(var) : 0.0;
      g_health[idx].sharpeProxy = (sd > 0) ? (mr / sd) : 0.0;
   }
   
   // Recovery factor
   g_health[idx].recoveryFactor = (g_health[idx].maxConsecLosses > 0)
      ? (double)g_health[idx].wins / (double)g_health[idx].maxConsecLosses
      : 1.0;
   
   UpdateStrategyInfluence(idx);
   
   Print("Strategy [", g_health[idx].name, "] Result: ", 
         (pnl >= 0 ? "WIN" : "LOSS"), " ", DoubleToString(pnl, 2),
         " | WR: ", DoubleToString(g_health[idx].winRate, 1), "%",
         " PF: ", DoubleToString(g_health[idx].profitFactor, 2),
         " Exp: ", DoubleToString(g_health[idx].expectancyR, 2), "R");
}

//=====================================================================
//  LEARNING SYSTEM
//=====================================================================
void InitLearning()
{
   for(int i = 0; i < 10; i++)
   {
      g_learning.regimeSuccessRate[i] = 0.5;
      g_learning.regimeTrades[i] = 0;
   }
   for(int i = 0; i < 6; i++)
   {
      g_learning.sessionSuccessRate[i] = 0.5;
      g_learning.sessionTrades[i] = 0;
   }
   for(int i = 0; i < 5; i++)
   {
      g_learning.strategyOptimalConfidence[i] = 60.0;
   }
   
   g_learning.optimalRiskPerTrade = InpRiskPercentPerTrade;
   g_learning.bestTimeToTrade = 12.0;
   g_learning.worstTimeToTrade = 21.0;
   g_learning.totalLearningCycles = 0;
   g_learning.lastLearningUpdate = 0;
}

void UpdateLearning()
{
   if(!InpEnableLearning) return;
   if(TimeCurrent() - g_learning.lastLearningUpdate < 3600) return;
   
   g_learning.lastLearningUpdate = TimeCurrent();
   g_learning.totalLearningCycles++;
   
   // Learn from strategy performance
   for(int i = 0; i < 5; i++)
   {
      if(g_health[i].totalTrades >= 10)
      {
         if(g_health[i].winRate > 55.0 && g_health[i].profitFactor > 1.5)
         {
            g_learning.strategyOptimalConfidence[i] = MathMax(50.0, g_learning.strategyOptimalConfidence[i] - 2.0);
         }
         else if(g_health[i].winRate < 40.0 || g_health[i].profitFactor < 0.9)
         {
            g_learning.strategyOptimalConfidence[i] = MathMin(80.0, g_learning.strategyOptimalConfidence[i] + 3.0);
         }
      }
   }
   
   // Adjust risk based on performance
   double totalPnL = 0;
   int totalTrades = 0;
   for(int i = 0; i < 5; i++)
   {
      totalPnL += g_health[i].grossProfit - g_health[i].grossLoss;
      totalTrades += g_health[i].totalTrades;
   }
   
   if(totalTrades >= 20)
   {
      if(totalPnL > 0 && g_risk.currentDrawdownPct < 5.0)
      {
         g_learning.optimalRiskPerTrade = MathMin(InpMaxRiskPercentTrade, 
                                                   g_learning.optimalRiskPerTrade * 1.05);
      }
      else if(totalPnL < 0 || g_risk.currentDrawdownPct > 8.0)
      {
         g_learning.optimalRiskPerTrade = MathMax(InpRiskPercentPerTrade * 0.5, 
                                                   g_learning.optimalRiskPerTrade * 0.95);
      }
   }
   
   Print("LEARNING UPDATE #", g_learning.totalLearningCycles, 
         " | Optimal Risk: ", DoubleToString(g_learning.optimalRiskPerTrade, 2), "%");
}

//=====================================================================
//  ADAPTIVE PARAMETERS (ENHANCED)
//=====================================================================
void InitAdaptiveParams()
{
   g_adaptiveRegimeConfThreshold = InpMinRegimeConfidence;
   g_adaptiveExecScoreThreshold  = InpMinExecutionScore;
}

void UpdateAdaptiveParams()
{
   if(!InpEnableAdaptiveParams) return;
   
   static datetime lb = 0;
   datetime cb = iTime(_Symbol, PERIOD_M5, 0);
   if(cb == lb) return;
   lb = cb;

   double rLo = InpMinRegimeConfidence * (1.0 - InpAdaptiveBoundPct / 100.0);
   double rHi = InpMinRegimeConfidence * (1.0 + InpAdaptiveBoundPct / 100.0);
   double eLo = InpMinExecutionScore   * (1.0 - InpAdaptiveBoundPct / 100.0);
   double eHi = InpMinExecutionScore   * (1.0 + InpAdaptiveBoundPct / 100.0);

   // Adjust based on market scores
   if(g_scores.totalScore > 80)
   {
      g_adaptiveRegimeConfThreshold = MathMax(rLo, g_adaptiveRegimeConfThreshold - 0.5);
      g_adaptiveExecScoreThreshold  = MathMax(eLo, g_adaptiveExecScoreThreshold - 0.3);
   }
   else if(g_scores.totalScore < 50)
   {
      g_adaptiveRegimeConfThreshold = MathMin(rHi, g_adaptiveRegimeConfThreshold + 0.5);
      g_adaptiveExecScoreThreshold  = MathMin(eHi, g_adaptiveExecScoreThreshold + 0.3);
   }
   
   // Adjust based on recent performance
   int recentWins = 0, recentTrades = 0;
   for(int i = 0; i < 5; i++)
   {
      if(g_health[i].totalTrades > 0)
      {
         recentWins += g_health[i].wins;
         recentTrades += g_health[i].totalTrades;
      }
   }
   
   if(recentTrades >= 10)
   {
      double recentWR = 100.0 * recentWins / recentTrades;
      if(recentWR > 60.0)
      {
         g_adaptiveRegimeConfThreshold = MathMax(rLo, g_adaptiveRegimeConfThreshold - 1.0);
      }
      else if(recentWR < 35.0)
      {
         g_adaptiveRegimeConfThreshold = MathMin(rHi, g_adaptiveRegimeConfThreshold + 1.5);
      }
   }
}

//=====================================================================
//  POSITION MANAGEMENT SYSTEM
//=====================================================================
void AddPosition(ulong ticket, ENUM_STRATEGY strat, double open, double sl, double tp, double risk)
{
   for(int i = 0; i < 10; i++)
   {
      if(g_positions[i].ticket == 0)
      {
         g_positions[i].ticket = ticket;
         g_positions[i].strategy = strat;
         g_positions[i].openPrice = open;
         g_positions[i].originalSL = sl;
         g_positions[i].originalTP = tp;
         g_positions[i].currentSL = sl;
         g_positions[i].currentTP = tp;
         g_positions[i].riskAmount = risk;
         g_positions[i].status = TM_NONE;
         g_positions[i].beMovedToBreakeven = false;
         g_positions[i].trailingActive = false;
         g_positions[i].openTime = TimeCurrent();
         g_positions[i].highestPrice = open;
         g_positions[i].lowestPrice = open;
         g_positions[i].partialTaken = false;
         g_positionCount++;
         break;
      }
   }
}

void RemovePosition(ulong ticket)
{
   for(int i = 0; i < 10; i++)
   {
      if(g_positions[i].ticket == ticket)
      {
         g_positions[i].ticket = 0;
         g_positionCount--;
         break;
      }
   }
}

PositionManager* GetPositionManager(ulong ticket)
{
   for(int i = 0; i < 10; i++)
      if(g_positions[i].ticket == ticket)
         return &g_positions[i];
   return NULL;
}

void ManageOpenPositions()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(!g_pos.SelectByIndex(i)) continue;
      if(g_pos.Magic() != InpMagicNumber) continue;
      if(g_pos.Symbol() != _Symbol) continue;
      
      ulong ticket = g_pos.Ticket();
      PositionManager* pm = GetPositionManager(ticket);
      if(pm == NULL) continue;
      
      double currentPrice = g_pos.PriceCurrent();
      bool isLong = (g_pos.PositionType() == POSITION_TYPE_BUY);
      
      // Update highest/lowest
      if(isLong)
      {
         if(currentPrice > pm.highestPrice) pm.highestPrice = currentPrice;
      }
      else
      {
         if(currentPrice < pm.lowestPrice) pm.lowestPrice = currentPrice;
      }
      
      double profitR = 0;
      if(isLong)
         profitR = (currentPrice - pm.openPrice) / MathAbs(pm.openPrice - pm.originalSL);
      else
         profitR = (pm.openPrice - currentPrice) / MathAbs(pm.originalSL - pm.openPrice);
      
      // Breakeven logic
      if(InpEnableBreakeven && !pm.beMovedToBreakeven && profitR >= InpBreakevenTriggerR)
      {
         double newSL = isLong 
            ? NPrice(pm.openPrice + MathAbs(pm.openPrice - pm.originalSL) * InpBreakevenOffsetR)
            : NPrice(pm.openPrice - MathAbs(pm.originalSL - pm.openPrice) * InpBreakevenOffsetR);
         
         if(g_trade.PositionModify(ticket, newSL, pm.currentTP))
         {
            pm.currentSL = newSL;
            pm.beMovedToBreakeven = true;
            pm.status = TM_BREAKEVEN_ACTIVE;
            Print("Breakeven activated for ticket ", ticket, " at ", DoubleToString(newSL, _Digits));
         }
      }
      
      // Trailing stop logic
      if(InpEnableTrailing && profitR >= InpTrailingStartR)
      {
         pm.trailingActive = true;
         pm.status = TM_TRAILING_ACTIVE;
         
         double trailDist = MathAbs(pm.openPrice - pm.originalSL) * InpTrailingStepR;
         double newSL = isLong
            ? NPrice(pm.highestPrice - trailDist)
            : NPrice(pm.lowestPrice + trailDist);
         
         bool shouldUpdate = false;
         if(isLong && newSL > pm.currentSL) shouldUpdate = true;
         if(!isLong && newSL < pm.currentSL) shouldUpdate = true;
         
         if(shouldUpdate)
         {
            if(g_trade.PositionModify(ticket, newSL, pm.currentTP))
            {
               pm.currentSL = newSL;
               Print("Trailing stop updated for ticket ", ticket, " to ", DoubleToString(newSL, _Digits));
            }
         }
      }
      
      // Partial close logic
      if(InpEnablePartialClose && !pm.partialTaken && profitR >= InpPartialCloseR)
      {
         double closeVol = g_pos.Volume() * (InpPartialClosePercent / 100.0);
         double volStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
         closeVol = MathFloor(closeVol / volStep) * volStep;
         
         if(closeVol >= SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN))
         {
            if(g_trade.PositionClosePartial(ticket, closeVol))
            {
               pm.partialTaken = true;
               pm.status = TM_PARTIAL_CLOSED;
               Print("Partial close: ", DoubleToString(InpPartialClosePercent, 0), 
                     "% of position ", ticket);
            }
         }
      }
   }
}

//=====================================================================
//  AI NARRATIVE ENGINE
//=====================================================================
void UpdateNarrative()
{
   if(TimeCurrent() - g_lastNarrative < InpNarrativeUpdateSec) return;
   g_lastNarrative = TimeCurrent();

   ENUM_STRATEGY routed = RouteRegimeToStrategy(g_regime.regime);
   bool bullish = (g_mtf.h1Bias > 0 || (g_mtf.h1Bias == 0 && g_mtf.m15Bias > 0));
   bool swept   = g_liq.sweepUpDetected || g_liq.sweepDownDetected;
   string bias  = bullish ? "BULLISH" : "BEARISH";

   g_narrativeLine1 = "Regime: " + RegimeToString(g_regime.regime) + 
                      " [" + DoubleToString(g_regime.confidence, 0) + "%]";

   if(swept)
      g_narrativeLine2 = (g_liq.sweepUpDetected ? "BSL" : "SSL") + " swept. Reversal expected.";
   else if(g_liq.equalHighsDetected || g_liq.equalLowsDetected)
      g_narrativeLine2 = LiquidityStatusString() + " detected.";
   else
      g_narrativeLine2 = "No active liquidity sweep.";

   g_narrativeLine3 = "Vol: " + VolStateToString(g_vol.state) + " / " + 
                      VolDynamicToString(g_vol.dynamic) + 
                      " [ATR Ratio: " + DoubleToString(g_vol.atrRatio, 2) + "]";

   g_narrativeLine4 = (routed != STRAT_NONE)
      ? "Active: " + StrategyToString(routed) + " [Ready]"
      : "Waiting for high-quality setup.";

   g_narrativeLine5 = "Market Score: " + DoubleToString(g_scores.totalScore, 0) + 
                      "/100 | Bias: " + bias + " [" + DoubleToString(g_mtf.alignment, 0) + "%]";
   
   g_narrativeLine6 = SessionOverlapString(g_session.current) + 
                      " | Spread: " + DoubleToString(g_execQuality.currentSpread, 1) +
                      " | Trades: " + IntegerToString(g_tradesToday);
}

//=====================================================================
//  MASTER DECISION ENGINE (ENHANCED)
//=====================================================================
MasterDecision BuildMasterDecision()
{
   MasterDecision d;
   d.tradeApproved = false; 
   d.direction = DIR_NONE; 
   d.lotSize = 0;
   d.slPrice = 0; 
   d.tpPrice = 0; 
   d.entryPrice = 0;
   d.strategySource = STRAT_NONE;
   d.riskAmountUsed = 0; 
   d.narrative = "";
   d.confidence = 0;
   d.timestamp = TimeCurrent();

   string rr = "";
   if(!RiskGovernanceAllowsNewTrade(rr))              
   { 
      d.narrative = rr;                           
      return d; 
   }
   
   if(g_regime.regime == REGIME_UNSAFE)               
   { 
      d.narrative = "REGIME UNSAFE";              
      return d; 
   }
   
   if(g_regime.confidence < g_adaptiveRegimeConfThreshold)
   { 
      d.narrative = "LOW REGIME CONF [" + DoubleToString(g_regime.confidence, 0) + "]";      
      return d; 
   }
   
   if(!g_execQuality.executionApproved)               
   { 
      d.narrative = g_execQuality.rejectReason;   
      return d; 
   }

   // Try all strategies, not just routed one
   StrategySignal signals[5];
   int validSignals = 0;
   
   for(int i = 1; i <= 5; i++)
   {
      ENUM_STRATEGY st = (ENUM_STRATEGY)i;
      int hi = StrategyHealthIndex(st);
      
      if(hi >= 0 && hi < 5 && !g_health[hi].enabled) continue;
      
      StrategySignal sig = GetSignalForStrategy(st);
      if(sig.valid)
      {
         signals[validSignals] = sig;
         validSignals++;
      }
   }
   
   if(validSignals == 0)
   {
      d.narrative = "NO VALID SIGNALS";
      return d;
   }
   
   // Select best signal
   StrategySignal bestSig = signals[0];
   for(int i = 1; i < validSignals; i++)
   {
      if(signals[i].confidence > bestSig.confidence)
         bestSig = signals[i];
   }
   
   // Session weight adjustment
   double sessionAdj = 1.0;
   if(g_session.preferredStrategy == bestSig.source)
      sessionAdj = g_session.strategyWeight;
   else
      sessionAdj = 0.9;
   
   double finalConf = bestSig.confidence * sessionAdj;
   
   // Use learning data
   if(InpEnableLearning)
   {
      int sidx = StrategyHealthIndex(bestSig.source);
      if(sidx >= 0 && sidx < 5)
      {
         if(finalConf < g_learning.strategyOptimalConfidence[sidx])
         {
            d.narrative = "BELOW LEARNED CONFIDENCE";
            return d;
         }
      }
   }
   
   if(finalConf < g_adaptiveRegimeConfThreshold)             
   { 
      d.narrative = "LOW FINAL CONFIDENCE";
      return d; 
   }

   double ra = 0.0;
   double lot = CalculateAdaptiveLotSize(bestSig, bestSig.suggestedSL, ra);
   if(lot <= 0)                                       
   { 
      d.narrative = "INVALID LOT SIZE";
      return d; 
   }

   d.tradeApproved  = true;
   d.direction      = bestSig.direction;
   d.lotSize        = lot;
   d.slPrice        = bestSig.suggestedSL;
   d.tpPrice        = bestSig.suggestedTP;
   d.entryPrice     = bestSig.suggestedEntry;
   d.strategySource = bestSig.source;
   d.riskAmountUsed = ra;
   d.narrative      = StrategyToString(bestSig.source);
   d.confidence     = finalConf;
   
   return d;
}

//=====================================================================
//  EXECUTION ENGINE (ENHANCED)
//=====================================================================
string EncodePositionTag(ENUM_STRATEGY st, double ra)
{
   return "QPA2|" + IntegerToString((int)st) + "|" + DoubleToString(ra, 2);
}

bool DecodePositionTag(string c, ENUM_STRATEGY &st, double &ra)
{
   string pts[];
   ArrayResize(pts, 10);
   int n = StringSplit(c, '|', pts);
   if(n < 3 || ArraySize(pts) < 3) return false;
   int sid = (int)StringToInteger(pts[1]);
   if(sid < 0 || sid > 5) return false;
   st = (ENUM_STRATEGY)sid;
   ra = StringToDouble(pts[2]);
   return (ra > 0);
}

bool ExecuteMasterDecision(MasterDecision &d)
{
   if(!d.tradeApproved || d.direction == DIR_NONE) return false;
   
   double price = d.entryPrice;
   if(price <= 0) 
   {
      price = (d.direction == DIR_LONG)
            ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
            : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   }
   
   if(price <= 0) return false;

   double minD = (double)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL)
               * SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   
   double sl = d.slPrice, tp = d.tpPrice;

   if(d.direction == DIR_LONG)
   {
      if(sl > 0 && (price - sl) < minD) sl = NPrice(price - minD * 2);
      if(tp > 0 && (tp - price) < minD) tp = NPrice(price + minD * 2);
   }
   else
   {
      if(sl > 0 && (sl - price) < minD) sl = NPrice(price + minD * 2);
      if(tp > 0 && (price - tp) < minD) tp = NPrice(price - minD * 2);
   }

   g_trade.SetExpertMagicNumber(InpMagicNumber);
   g_trade.SetDeviationInPoints((ulong)InpMaxSlippagePoints);
   g_trade.SetTypeFilling(GetFillMode());

   bool ok = (d.direction == DIR_LONG)
           ? g_trade.Buy(d.lotSize,  _Symbol, price, sl, tp, EncodePositionTag(d.strategySource, d.riskAmountUsed))
           : g_trade.Sell(d.lotSize, _Symbol, price, sl, tp, EncodePositionTag(d.strategySource, d.riskAmountUsed));

   if(ok) 
   { 
      g_tradesToday++; 
      g_lastAction = d.narrative;
      
      ulong ticket = g_trade.ResultOrder();
      if(ticket > 0)
      {
         AddPosition(ticket, d.strategySource, price, sl, tp, d.riskAmountUsed);
         Print("TRADE EXECUTED: ", (d.direction == DIR_LONG ? "BUY" : "SELL"),
               " ", DoubleToString(d.lotSize, 2), " lots",
               " | Strategy: ", StrategyToString(d.strategySource),
               " | Confidence: ", DoubleToString(d.confidence, 1), "%",
               " | Risk: $", DoubleToString(d.riskAmountUsed, 2));
      }
      
      DrawEntryMarker(d.direction, price, d.strategySource);
   }
   else
   {
      Print("TRADE FAILED: ", g_trade.ResultRetcodeDescription());
   }
   
   return ok;
}

double GetFloatingPL()
{
   double t = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
      if(g_pos.SelectByIndex(i) && g_pos.Magic() == InpMagicNumber && g_pos.Symbol() == _Symbol)
         t += g_pos.Profit() + g_pos.Swap() + g_pos.Commission();
   return t;
}

bool HasManagedPosition() 
{ 
   return PositionsTotalForMagic() > 0; 
}

void OnTradeTransactionHandler(const MqlTradeTransaction &trans,
                               const MqlTradeRequest     &request,
                               const MqlTradeResult      &result)
{
   if(trans.type != TRADE_TRANSACTION_DEAL_ADD) return;
   
   ulong dt = trans.deal;
   
   if(!HistoryDealSelect(dt)) return;
   if((ulong)HistoryDealGetInteger(dt, DEAL_MAGIC) != InpMagicNumber) return;
   if(HistoryDealGetString(dt, DEAL_SYMBOL)  != _Symbol)              return;
   if(HistoryDealGetInteger(dt, DEAL_ENTRY)  != DEAL_ENTRY_OUT)       return;

   double pnl = HistoryDealGetDouble(dt, DEAL_PROFIT)
              + HistoryDealGetDouble(dt, DEAL_SWAP)
              + HistoryDealGetDouble(dt, DEAL_COMMISSION);

   ENUM_STRATEGY st = STRAT_NONE; 
   double ra = 0;
   string comment = HistoryDealGetString(dt, DEAL_COMMENT);
   
   if(!DecodePositionTag(comment, st, ra)) 
   {
      Print("Could not decode position tag: ", comment);
      return;
   }

   RegisterTradeResult(st, pnl, (ra > 0) ? pnl / ra : 0.0);
   
   g_sessionProfit += pnl;
   if(pnl >= 0) g_sessionWins++; 
   else g_sessionLosses++;
   
   g_lastCloseTime = TimeCurrent();
   g_inCooldown    = true;
   g_cooldownLeft  = InpCooldownAfterCloseSec;
   
   ulong ticket = HistoryDealGetInteger(dt, DEAL_POSITION_ID);
   RemovePosition(ticket);
   
   DrawExitMarker(HistoryDealGetDouble(dt, DEAL_PRICE), pnl);
   
   Print("=== POSITION CLOSED ===");
   Print("Strategy: ", StrategyToString(st));
   Print("P&L: ", DoubleToString(pnl, 2), " USD");
   Print("R-Multiple: ", DoubleToString((ra > 0) ? pnl / ra : 0.0, 2), "R");
   Print("Session: Wins=", g_sessionWins, " Losses=", g_sessionLosses);
}

void RunMasterDecisionCycle()
{
   // Manage existing positions first
   ManageOpenPositions();
   
   if(HasManagedPosition()) 
   { 
      g_statusText = "IN TRADE";   
      g_statusColor = C_GREEN_BRIGHT;  
      return; 
   }
   
   if(g_inCooldown)         
   { 
      g_statusText = "COOLDOWN";   
      g_statusColor = C_CYAN_BRIGHT;   
      return; 
   }

   MasterDecision d = BuildMasterDecision();
   g_lastDecision   = d;

   if(d.tradeApproved)
   {
      g_statusText  = "EXECUTING"; 
      g_statusColor = C_BLUE_BRIGHT;
      
      bool ok = ExecuteMasterDecision(d);
      
      g_statusText  = ok ? "IN TRADE"   : "ORDER FAIL";
      g_statusColor = ok ? C_GREEN_BRIGHT : C_RED_BRIGHT;
   }
   else
   {
      g_statusText  = "SCANNING"; 
      g_statusColor = C_GOLD_BRIGHT;
      g_lastAction  = d.narrative;
   }
}

//=====================================================================
//  CHART THEME
//=====================================================================
void ApplyProfessionalTheme()
{
   long ch = ChartID();
   ChartSetInteger(ch, CHART_MODE,             CHART_CANDLES);
   ChartSetInteger(ch, CHART_COLOR_BACKGROUND, C'5,5,5');
   ChartSetInteger(ch, CHART_COLOR_FOREGROUND, C_WHITE_PURE);
   ChartSetInteger(ch, CHART_COLOR_GRID,       C'15,15,15');
   ChartSetInteger(ch, CHART_COLOR_CANDLE_BULL,C_GREEN_BRIGHT);
   ChartSetInteger(ch, CHART_COLOR_CANDLE_BEAR,C_RED_BRIGHT);
   ChartSetInteger(ch, CHART_COLOR_CHART_UP,   C_GREEN_BRIGHT);
   ChartSetInteger(ch, CHART_COLOR_CHART_DOWN, C_RED_BRIGHT);
   ChartSetInteger(ch, CHART_COLOR_CHART_LINE, C_WHITE_PURE);
   ChartSetInteger(ch, CHART_COLOR_VOLUME,     C_CYAN_BRIGHT);
   ChartSetInteger(ch, CHART_COLOR_BID,        C_GREEN_BRIGHT);
   ChartSetInteger(ch, CHART_COLOR_ASK,        C_RED_BRIGHT);
   ChartSetInteger(ch, CHART_COLOR_STOP_LEVEL, C_YELLOW_BRIGHT);
   ChartSetInteger(ch, CHART_SHOW_GRID,        false);
   ChartSetInteger(ch, CHART_SHOW_VOLUMES,     CHART_VOLUME_TICK);
   ChartSetInteger(ch, CHART_SHOW_OHLC,        true);
   ChartSetInteger(ch, CHART_SHOW_ASK_LINE,    true);
   ChartSetInteger(ch, CHART_SHOW_BID_LINE,    true);
   ChartSetInteger(ch, CHART_SHOW_TRADE_LEVELS,true);
   ChartSetInteger(ch, CHART_SHIFT,            true);
   ChartSetInteger(ch, CHART_AUTOSCROLL,       true);
   ChartRedraw(ch);
}

//=====================================================================
//  DASHBOARD RENDERING (CONTINUED IN NEXT MESSAGE DUE TO LENGTH)
//=====================================================================

// [Dashboard functions from original, enhanced with real-time updates...]
// Due to character limit, I'll provide the key enhanced sections:

void DRect(string nm, int x, int y, int w, int h, color bg, color brd = clrNONE, int bw = 1)
{
   string n = D + nm;
   if(ObjectFind(0, n) < 0) ObjectCreate(0, n, OBJ_RECTANGLE_LABEL, 0, 0, 0);
   ObjectSetInteger(0, n, OBJPROP_CORNER,    CORNER_LEFT_UPPER);
   ObjectSetInteger(0, n, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, n, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, n, OBJPROP_XSIZE,     w);
   ObjectSetInteger(0, n, OBJPROP_YSIZE,     h);
   ObjectSetInteger(0, n, OBJPROP_BGCOLOR,   bg);
   ObjectSetInteger(0, n, OBJPROP_SELECTABLE,false);
   ObjectSetInteger(0, n, OBJPROP_HIDDEN,    false);
   ObjectSetInteger(0, n, OBJPROP_ZORDER,    0);
   if(brd != clrNONE)
   {
      ObjectSetInteger(0, n, OBJPROP_BORDER_TYPE, BORDER_FLAT);
      ObjectSetInteger(0, n, OBJPROP_COLOR,       brd);
      ObjectSetInteger(0, n, OBJPROP_WIDTH,        bw);
   }
   else
   {
      ObjectSetInteger(0, n, OBJPROP_BORDER_TYPE, BORDER_RAISED);
      ObjectSetInteger(0, n, OBJPROP_COLOR,       bg);
   }
}

void DLabel(string nm, int x, int y, string txt, color clr, int fsz, string fnt = "Segoe UI Bold")
{
   string n = D + nm;
   if(ObjectFind(0, n) < 0) ObjectCreate(0, n, OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, n, OBJPROP_CORNER,    CORNER_LEFT_UPPER);
   ObjectSetInteger(0, n, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, n, OBJPROP_YDISTANCE, y);
   ObjectSetString (0, n, OBJPROP_TEXT,      txt);
   ObjectSetInteger(0, n, OBJPROP_COLOR,     clr);
   ObjectSetInteger(0, n, OBJPROP_FONTSIZE,  fsz);
   ObjectSetString (0, n, OBJPROP_FONT,      fnt);
   ObjectSetInteger(0, n, OBJPROP_SELECTABLE,false);
   ObjectSetInteger(0, n, OBJPROP_HIDDEN,    false);
   ObjectSetInteger(0, n, OBJPROP_ZORDER,    2);
}

void DUpdate(string nm, string txt, color clr = C_WHITE_PURE)
{
   string n = D + nm;
   if(ObjectFind(0, n) >= 0)
   {
      ObjectSetString (0, n, OBJPROP_TEXT,  txt);
      ObjectSetInteger(0, n, OBJPROP_COLOR, clr);
   }
}

void DUpdateBG(string nm, color bg)
{
   string n = D + nm;
   if(ObjectFind(0, n) >= 0) ObjectSetInteger(0, n, OBJPROP_BGCOLOR, bg);
}

void DScoreBar(string nm, int x, int y, int w, int h, double pct, color fg)
{
   DRect(nm + "_bg", x, y, w, h, C_BAR_EMPTY, C_PANEL_BRD2, 1);
   int fw = (int)MathMax(2, MathRound(MathMax(0.0, MathMin(100.0, pct)) / 100.0 * (w - 2)));
   DRect(nm + "_fg", x + 1, y + 1, fw, h - 2, fg, clrNONE);
}

void DScoreBarUpdate(string nm, double pct, color fg)
{
   string nb = D + nm + "_bg";
   string nf = D + nm + "_fg";
   if(ObjectFind(0, nb) < 0) return;
   int w  = (int)ObjectGetInteger(0, nb, OBJPROP_XSIZE);
   int fw = (int)MathMax(2, MathRound(MathMax(0.0, MathMin(100.0, pct)) / 100.0 * (w - 2)));
   if(ObjectFind(0, nf) >= 0)
   {
      ObjectSetInteger(0, nf, OBJPROP_XSIZE,   fw);
      ObjectSetInteger(0, nf, OBJPROP_BGCOLOR, fg);
   }
}

void DSep(string nm, int x, int y, int w)
{
   DRect(nm, x, y, w, 1, C_PANEL_BRD2, clrNONE);
}

void InitDash()
{
   if(!InpShowDash) return;

   int X  = S(InpDashX);
   int Y  = S(InpDashY);
   int W  = S(InpDashWidth);
   int y  = Y;
   int lp = S(10);
   int IW = W - S(4);

   DRect("fr_outer", X, Y, W, S(900), C_PANEL_BG, C_CYAN_BRIGHT, 2);
   y += S(2);

   DRect("hdr", X+S(2), y, IW, S(28), C_PANEL_HDR, C_CYAN_BRIGHT, 1);
   DLabel("hdr_title", X+lp, y+S(6), "QUANTUM PLUS AI v2.0 ULTRA  |  LIVE SCALPER", C_CYAN_BRIGHT, FS(9));
   y += S(30);

   // Status row
   DRect("status_bar", X+S(2), y, IW, S(22), C_PANEL_BG2, C_PANEL_BRD, 1);
   DLabel("lb_status", X+lp,       y+S(4), "STATUS",        C_SUBTEXT,    FS(7));
   DLabel("vl_status", X+S(70),    y+S(4), "INITIALIZING",  C_ORANGE_BRIGHT, FS(8));
   DLabel("lb_time",   X+W-S(140), y+S(4), "SERVER:",       C_SUBTEXT,    FS(7));
   DLabel("vl_time",   X+W-S(95),  y+S(4), "--:--:--",      C_WHITE_SOFT, FS(7));
   y += S(24);

   DSep("sep0", X+S(2), y, IW); y += S(3);

   // [Continue with all sections from original, adding dynamic fields...]
   
   ChartRedraw(0);
}

void UpdateDash()
{
   if(!InpShowDash) return;

   int digs = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   double sp  = (double)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   
   // Real-time status
   DUpdate("vl_status", g_statusText, g_statusColor);
   DUpdate("vl_time",   TimeToString(TimeCurrent(), TIME_SECONDS), C_WHITE_SOFT);

   // Regime
   DUpdate("vl_regime",    RegimeToString(g_regime.regime), RegimeToColor(g_regime.regime));
   DUpdate("vl_regconf",   DoubleToString(g_regime.confidence, 0) + "%", ScoreColor(g_regime.confidence));
   DUpdate("vl_regstab",   DoubleToString(g_regime.stability,  0) + "%", ScoreColor(g_regime.stability));
   DScoreBarUpdate("regime_bar", g_regime.confidence, RegimeToColor(g_regime.regime));

   // Session
   DUpdate("vl_sess",   SessionOverlapString(g_session.current), C_CYAN_BRIGHT);
   
   // Market scores (real-time)
   DUpdate("vl_trend",  DoubleToString(g_scores.trendScore, 0) + "/100", ScoreColor(g_scores.trendScore));
   
   // Spread check
   bool spOk = (sp <= InpMaxSpreadPoints);
   DUpdate("vl_spread", DoubleToString(sp, 0) + " pts", spOk ? C_GREEN_BRIGHT : C_RED_BRIGHT);
   
   // Active strategy
   ENUM_STRATEGY routed = RouteRegimeToStrategy(g_regime.regime);
   string stratStr = (routed == STRAT_NONE) ? "STAND ASIDE" : StrategyToString(routed);
   color  stratClr = (routed == STRAT_NONE) ? C_MGRAY : C_GREEN_BRIGHT;
   DUpdate("vl_active_strat", stratStr, stratClr);
   
   // Last action (real-time)
   DUpdate("vl_strat_reason", g_lastAction, C_WHITE_SOFT);
   
   // Total score
   color tqC = ScoreColor(g_scores.totalScore);
   DUpdate("vl_tq_total",  DoubleToString(g_scores.totalScore, 0) + " / 100", tqC);
   
   // Account
   double eq = AccountInfoDouble(ACCOUNT_EQUITY);
   DUpdate("vl_eq",  DoubleToString(eq,  2), C_GREEN_BRIGHT);
   
   ChartRedraw(0);
}

void DeleteDash()
{
   ObjectsDeleteAll(0, D);
   ChartRedraw(0);
}

// [Analyst Panel, Chart Overlays, and other visual functions follow same pattern...]

//=====================================================================
//  CHART OVERLAYS - ENTRY/EXIT MARKERS
//=====================================================================
void DrawEntryMarker(ENUM_DIRECTION dir, double price, ENUM_STRATEGY strat)
{
   if(!InpDrawSignalMarkers) return;
   
   datetime t   = TimeCurrent();
   string   nm  = OV + "ENTRY_" + IntegerToString((int)t);
   color    clr = (dir == DIR_LONG) ? C_GREEN_BRIGHT : C_RED_BRIGHT;
   int      arr = (dir == DIR_LONG) ? 233 : 234;

   if(ObjectCreate(0, nm, OBJ_ARROW, 0, t, price))
   {
      ObjectSetInteger(0, nm, OBJPROP_ARROWCODE,  arr);
      ObjectSetInteger(0, nm, OBJPROP_COLOR,      clr);
      ObjectSetInteger(0, nm, OBJPROP_WIDTH,      5);
      ObjectSetInteger(0, nm, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, nm, OBJPROP_HIDDEN,     false);
      ObjectSetInteger(0, nm, OBJPROP_BACK,       false);
      ObjectSetInteger(0, nm, OBJPROP_ANCHOR,     (dir == DIR_LONG) ? ANCHOR_TOP : ANCHOR_BOTTOM);
   }
   
   double off = MathMax(g_vol.atrAvg * 0.7, SymbolInfoDouble(_Symbol, SYMBOL_POINT) * 300);
   double lp2 = (dir == DIR_LONG) ? price - off : price + off;
   
   string nmL = OV + "ENTRY_L_" + IntegerToString((int)t);
   if(ObjectCreate(0, nmL, OBJ_TEXT, 0, t, lp2))
   {
      ObjectSetString(0, nmL, OBJPROP_TEXT, " " + StrategyToShort(strat) + " ");
      ObjectSetInteger(0, nmL, OBJPROP_COLOR, clr);
      ObjectSetInteger(0, nmL, OBJPROP_FONTSIZE, 12);
      ObjectSetString(0, nmL, OBJPROP_FONT, "Segoe UI Bold");
      ObjectSetInteger(0, nmL, OBJPROP_ANCHOR, (dir == DIR_LONG) ? ANCHOR_UPPER : ANCHOR_LOWER);
   }
}

void DrawExitMarker(double price, double pnl)
{
   if(!InpDrawSignalMarkers) return;
   
   datetime t   = TimeCurrent();
   string   nm  = OV + "EXIT_" + IntegerToString((int)t);
   color    clr = (pnl >= 0) ? C_CYAN_BRIGHT : C_ORANGE_BRIGHT;

   if(ObjectCreate(0, nm, OBJ_ARROW, 0, t, price))
   {
      ObjectSetInteger(0, nm, OBJPROP_ARROWCODE,  251);
      ObjectSetInteger(0, nm, OBJPROP_COLOR,      clr);
      ObjectSetInteger(0, nm, OBJPROP_WIDTH,      4);
      ObjectSetInteger(0, nm, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, nm, OBJPROP_HIDDEN,     false);
      ObjectSetInteger(0, nm, OBJPROP_BACK,       false);
   }
   
   double off = MathMax(g_vol.atrAvg * 0.5, SymbolInfoDouble(_Symbol, SYMBOL_POINT) * 200);
   
   string nmL = OV + "EXIT_L_" + IntegerToString((int)t);
   if(ObjectCreate(0, nmL, OBJ_TEXT, 0, t, price + off))
   {
      string txt = (pnl >= 0 ? "+" : "") + DoubleToString(pnl, 2);
      ObjectSetString(0, nmL, OBJPROP_TEXT, txt);
      ObjectSetInteger(0, nmL, OBJPROP_COLOR, clr);
      ObjectSetInteger(0, nmL, OBJPROP_FONTSIZE, 12);
      ObjectSetString(0, nmL, OBJPROP_FONT, "Segoe UI Bold");
      ObjectSetInteger(0, nmL, OBJPROP_ANCHOR, ANCHOR_LOWER);
   }
}

//=====================================================================
//  EA LIFECYCLE
//=====================================================================
int OnInit()
{
   Print("========================================");
   Print("QUANTUM PLUS AI v2.0 ULTRA - INITIALIZING");
   Print("========================================");
   
   g_scale = MathMax(0.5, MathMin(3.0, InpDPIScale / 100.0));

   ApplyProfessionalTheme();
   
   InitIndicatorStates();

   g_trade.SetExpertMagicNumber(InpMagicNumber);
   g_trade.SetDeviationInPoints((ulong)InpMaxSlippagePoints);
   g_trade.SetTypeFilling(GetFillMode());

   // Create indicators
   g_h1_ema_fast  = iMA(_Symbol, PERIOD_H1,  InpEMAFastPeriod, 0, MODE_EMA, PRICE_CLOSE);
   g_h1_ema_slow  = iMA(_Symbol, PERIOD_H1,  InpEMASlowPeriod, 0, MODE_EMA, PRICE_CLOSE);
   g_h1_atr       = iATR(_Symbol, PERIOD_H1, InpATRPeriod);
   
   g_m15_ema_fast = iMA(_Symbol, PERIOD_M15, InpEMAFastPeriod, 0, MODE_EMA, PRICE_CLOSE);
   g_m15_ema_slow = iMA(_Symbol, PERIOD_M15, InpEMASlowPeriod, 0, MODE_EMA, PRICE_CLOSE);
   g_m15_atr      = iATR(_Symbol, PERIOD_M15, InpATRPeriod);
   g_m15_rsi      = iRSI(_Symbol, PERIOD_M15, 14, PRICE_CLOSE);
   
   g_m5_ema_fast  = iMA(_Symbol, PERIOD_M5,  InpEMAFastPeriod, 0, MODE_EMA, PRICE_CLOSE);
   g_m5_ema_slow  = iMA(_Symbol, PERIOD_M5,  InpEMASlowPeriod, 0, MODE_EMA, PRICE_CLOSE);
   g_m5_atr       = iATR(_Symbol, PERIOD_M5, InpATRPeriod);
   g_m5_rsi       = iRSI(_Symbol, PERIOD_M5, 14, PRICE_CLOSE);
   
   g_m1_ema_fast  = iMA(_Symbol, PERIOD_M1,  InpEMAFastPeriod, 0, MODE_EMA, PRICE_CLOSE);
   g_m1_ema_slow  = iMA(_Symbol, PERIOD_M1,  InpEMASlowPeriod, 0, MODE_EMA, PRICE_CLOSE);
   g_m1_atr       = iATR(_Symbol, PERIOD_M1, InpATRPeriod);

   // Additional indicators
   if(InpUseStochastic)
      g_m5_stoch = iStochastic(_Symbol, PERIOD_M5, 5, 3, 3, MODE_SMA, STO_LOWHIGH);
   
   if(InpUseBollingerBands)
      g_m5_bb = iBands(_Symbol, PERIOD_M5, 20, 0, 2.0, PRICE_CLOSE);
   
   if(InpUseMACD)
      g_m5_macd = iMACD(_Symbol, PERIOD_M5, 12, 26, 9, PRICE_CLOSE);

   // Validate handles
   if(g_h1_ema_fast  == INVALID_HANDLE || g_h1_ema_slow  == INVALID_HANDLE || g_h1_atr  == INVALID_HANDLE ||
      g_m15_ema_fast == INVALID_HANDLE || g_m15_ema_slow == INVALID_HANDLE || g_m15_atr == INVALID_HANDLE ||
      g_m15_rsi      == INVALID_HANDLE || g_m5_ema_fast  == INVALID_HANDLE || g_m5_ema_slow == INVALID_HANDLE ||
      g_m5_atr       == INVALID_HANDLE || g_m5_rsi       == INVALID_HANDLE || g_m1_ema_fast == INVALID_HANDLE ||
      g_m1_ema_slow  == INVALID_HANDLE || g_m1_atr       == INVALID_HANDLE)
   {
      Print("ERROR: Core indicator creation failed!");
      return INIT_FAILED;
   }

   g_dayStart  = DayStart(TimeCurrent());
   g_weekStart = WeekStart(TimeCurrent());

   InitRiskState();
   InitStrategyHealth();
   InitAdaptiveParams();
   InitLearning();

   g_regime.regime         = REGIME_RANGING;
   g_regime.confidence     = 0;
   g_regime.stability      = 0;
   g_regime.sinceTime      = TimeCurrent();
   g_regime.previousRegime = REGIME_RANGING;
   g_regime.barsSinceChange= 0;

   if(InpShowDash)         InitDash();

   EventSetTimer(1);

   g_statusText  = "WARMING UP";
   g_statusColor = C_ORANGE_BRIGHT;
   g_lastAction  = "Building buffers...";

   Print("Indicators created. Waiting for data validation...");
   Print("Magic Number: ", InpMagicNumber);
   Print("Risk per trade: ", InpRiskPercentPerTrade, "%");
   Print("Max spread: ", InpMaxSpreadPoints, " points");
   Print("========================================");

   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
   EventKillTimer();
   DeleteDash();

   IndicatorRelease(g_h1_ema_fast);  IndicatorRelease(g_h1_ema_slow);  IndicatorRelease(g_h1_atr);
   IndicatorRelease(g_m15_ema_fast); IndicatorRelease(g_m15_ema_slow); IndicatorRelease(g_m15_atr);
   IndicatorRelease(g_m15_rsi);
   IndicatorRelease(g_m5_ema_fast);  IndicatorRelease(g_m5_ema_slow);  IndicatorRelease(g_m5_atr);
   IndicatorRelease(g_m5_rsi);
   IndicatorRelease(g_m1_ema_fast);  IndicatorRelease(g_m1_ema_slow);  IndicatorRelease(g_m1_atr);
   
   if(g_m5_stoch != INVALID_HANDLE) IndicatorRelease(g_m5_stoch);
   if(g_m5_bb != INVALID_HANDLE) IndicatorRelease(g_m5_bb);
   if(g_m5_macd != INVALID_HANDLE) IndicatorRelease(g_m5_macd);

   Print("=== QPA v2.0 ULTRA SESSION END ===");
   Print("Total trades: ", g_tradesToday);
   Print("Session P&L: ", DoubleToString(g_sessionProfit, 2));
}

void OnTimer()
{
   g_tickCounter++;
   
   // Update cooldown
   if(g_lastCloseTime > 0)
   {
      int el       = (int)(TimeCurrent() - g_lastCloseTime);
      g_inCooldown = (el < InpCooldownAfterCloseSec);
      g_cooldownLeft = g_inCooldown ? (InpCooldownAfterCloseSec - el) : 0;
   }
   
   if(InpShowDash) UpdateDash();
}

void OnTick()
{
   g_lastTickTime = TimeCurrent();
   
   // Cooldown check
   if(g_lastCloseTime > 0)
   {
      int el       = (int)(TimeCurrent() - g_lastCloseTime);
      g_inCooldown = (el < InpCooldownAfterCloseSec);
   }

   RolloverDailyWeeklyIfNeeded();

   // Check indicator readiness
   if(!g_indicatorsReady)
   {
      g_indicatorsReady = AllIndicatorsReady();
      if(!g_indicatorsReady)
      {
         g_statusText  = "LOADING INDICATORS";
         g_statusColor = C_ORANGE_BRIGHT;
         return;
      }
      else
      {
         Print("All indicators ready. Starting analysis...");
      }
   }

   UpdateRiskState();

   bool nb = IsNewBar();
   
   // Full update on new bar or every 60 seconds
   if(nb || TimeCurrent() - g_lastFullUpdate > 60)
   {
      UpdateMTFBias();
      UpdateVolatilityIntelligence();
      UpdateNewsShockProxy();
      UpdateLiquidityIntelligence();
      UpdateSessionIntelligence();
      UpdateRegimeClassification();
      UpdateMarketScores();
      UpdateNarrative();
      UpdateAdaptiveParams();
      UpdateLearning();
      g_lastFullUpdate = TimeCurrent();
   }

   UpdateExecutionQuality();
   RunMasterDecisionCycle();
}

void OnTradeTransaction(const MqlTradeTransaction &trans,
                        const MqlTradeRequest     &request,
                        const MqlTradeResult      &result)
{
   OnTradeTransactionHandler(trans, request, result);
}