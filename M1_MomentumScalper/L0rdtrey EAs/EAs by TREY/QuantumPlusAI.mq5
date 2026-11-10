//+------------------------------------------------------------------+
//|                                          QUANTUM PLUS AI v1.0     |
//|        Institutional-Grade Adaptive Multi-Regime Trading System  |
//|        Architecture: Regime-Routed Strategy Selection            |
//|        Built for XAUUSD | M1/M5/M15/H1 Hierarchical Decisioning  |
//+------------------------------------------------------------------+
#property copyright   "Quantum Plus AI v1.0"
#property version     "1.00"
#property description "Institutional multi-regime adaptive EA. Regime-routed strategy"
#property description "selection, liquidity/volatility/session intelligence, dynamic"
#property description "risk governance, strategy health monitoring, no martingale."
#property strict

#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>
#include <Trade\AccountInfo.mqh>
#include <Trade\OrderInfo.mqh>

#define D "QPA_"   // Dashboard object namespace

//=====================================================================
//  ENUMERATIONS
//=====================================================================

// --- Market Regime States (Phase 2)
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

// --- Volatility States (Phase 6)
enum ENUM_VOL_STATE
{
   VOL_LOW,
   VOL_NORMAL,
   VOL_HIGH,
   VOL_EXTREME
};

// --- Volatility Dynamics
enum ENUM_VOL_DYNAMIC
{
   VOLDYN_EXPANDING,
   VOLDYN_COMPRESSING,
   VOLDYN_STABLE,
   VOLDYN_SPIKE
};

// --- Session States (Phase 5)
enum ENUM_SESSION
{
   SESSION_ASIAN,
   SESSION_LONDON_OPEN,
   SESSION_LONDON_MID,
   SESSION_NY_OPEN,
   SESSION_NY_PM,
   SESSION_DEAD_ZONE
};

// --- News Shock Proxy States (Phase 12)
enum ENUM_NEWS_STATE
{
   NEWS_NORMAL,
   NEWS_CAUTION,
   NEWS_SHOCK
};

// --- Strategy Identifiers (Phase 3 Router)
enum ENUM_STRATEGY
{
   STRAT_NONE,
   STRAT_TREND_SCALPER,
   STRAT_MEAN_REVERSION,
   STRAT_VOLATILITY_EXPANSION,
   STRAT_LIQUIDITY_REVERSAL,
   STRAT_COMPRESSION_BREAKOUT
};

// --- Trade Direction (internal, avoids ORDER_TYPE ambiguity)
enum ENUM_DIRECTION
{
   DIR_NONE,
   DIR_LONG,
   DIR_SHORT
};

//=====================================================================
//  CORE DATA STRUCTURES
//=====================================================================

// --- Regime Classification Output
struct RegimeState
{
   ENUM_REGIME    regime;
   double         confidence;      // 0-100
   double         stability;       // 0-100, how long regime has persisted
   datetime       sinceTime;
   ENUM_REGIME    previousRegime;
};

// --- Volatility Snapshot
struct VolatilityState
{
   ENUM_VOL_STATE   state;
   ENUM_VOL_DYNAMIC dynamic;
   double           atrCurrent;
   double           atrAvg;
   double           atrRatio;        // current / average
   double           percentile;      // 0-100 rank vs lookback
};

// --- Liquidity Snapshot (Phase 4)
struct LiquidityState
{
   double   biasScore;        // -100 (sell side) .. +100 (buy side)
   double   pressureScore;    // 0-100 intensity
   double   sweepProbability; // 0-100
   double   imbalanceScore;   // 0-100
   bool     equalHighsDetected;
   bool     equalLowsDetected;
   double   equalHighLevel;
   double   equalLowLevel;
   bool     sweepUpDetected;
   bool     sweepDownDetected;
};

// --- Session Snapshot (Phase 5)
struct SessionState
{
   ENUM_SESSION   current;
   double         sessionRangeATRRatio;
   double         sessionVolatilityScore;
   ENUM_STRATEGY  preferredStrategy;
   double         strategyWeight;   // multiplier 0.0-1.5 applied to confidence
};

// --- Multi-timeframe bias container (Phase 13)
struct MTFBias
{
   int      h1Bias;     // -1,0,1
   int      m15Bias;
   int      m5Bias;
   int      m1Bias;
   double   alignment;  // 0-100 how aligned across TFs
};

// --- Signal package produced by a strategy module
struct StrategySignal
{
   ENUM_STRATEGY   source;
   ENUM_DIRECTION  direction;
   double          confidence;    // 0-100
   double          suggestedSL;   // price
   double          suggestedTP;   // price
   string          reason;
   bool            valid;
};

// --- Per-strategy health tracking (Phase 10)
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
   double   peakEquityContribution;
   double   currentDrawdownContribution;
   double   winRate;
   double   profitFactor;
   double   expectancyR;
   double   sharpeProxy;
   bool     enabled;
   double   influenceMultiplier;  // 0.0 - 1.0, reduced on degradation
   datetime lastDegradedTime;
};

// --- Execution quality assessment (Phase 8)
struct ExecutionQuality
{
   double   spreadScore;        // 0-100
   double   slippageRiskScore;  // 0-100
   double   volatilityQuality;  // 0-100
   double   liquidityQuality;   // 0-100
   double   efficiencyScore;    // 0-100
   double   compositeScore;     // 0-100
   bool     executionApproved;
   string   rejectReason;
};

// --- Risk governance state (Phase 7)
struct RiskState
{
   double   dailyRiskUsedPct;
   double   weeklyRiskUsedPct;
   double   currentDrawdownPct;
   double   maxDrawdownSeenPct;
   bool     dailyLimitHit;
   bool     weeklyLimitHit;
   bool     maxDrawdownBreached;
   bool     emergencyShutdown;
   double   peakEquity;
   double   weekStartEquity;
   double   dayStartEquity;
};

// --- Master decision package
struct MasterDecision
{
   bool             tradeApproved;
   ENUM_DIRECTION   direction;
   double           lotSize;
   double           slPrice;
   double           tpPrice;
   ENUM_STRATEGY    strategySource;
   double           riskAmountUsed;   // actual $ risked at the lot size chosen — used for R-multiple attribution on close
   string           narrative;
};
//=====================================================================
//  INPUT PARAMETERS
//=====================================================================

input group "╔══════  IDENTITY  ══════╗"
input ulong    InpMagicNumber          = 778800;
input string   InpBotName              = "QUANTUM PLUS AI";

input group "╔══════  RISK GOVERNANCE  ══════╗"
input double   InpRiskPercentPerTrade  = 0.5;     // % equity risked per trade (base, before adaptive scaling)
input double   InpMaxRiskPercentTrade  = 1.0;     // hard ceiling on per-trade risk %, even at max confidence
input double   InpMaxDailyLossPct      = 3.0;     // daily loss circuit breaker
input double   InpMaxWeeklyLossPct     = 7.0;     // weekly loss circuit breaker
input double   InpMaxDrawdownPct       = 12.0;    // emergency shutdown threshold from peak equity
input int      InpMaxDailyTrades       = 8;
input int      InpMaxConcurrentTrades  = 1;       // mutual exclusion enforced regardless

input group "╔══════  EXECUTION QUALITY  ══════╗"
input double   InpMaxSpreadPoints      = 350;     // reject if spread exceeds this (points)
input double   InpMinExecutionScore    = 60.0;    // 0-100, composite gate
input int      InpCooldownAfterCloseSec= 30;

input group "╔══════  REGIME DETECTION  ══════╗"
input int      InpATRPeriod            = 14;
input int      InpATRLookback          = 100;     // for percentile ranking
input int      InpEMAFastPeriod        = 8;
input int      InpEMASlowPeriod        = 34;
input int      InpStructureLookback    = 20;      // bars for swing high/low structure
input double   InpMinRegimeConfidence  = 55.0;    // below this, regime = UNSAFE handling applies

input group "╔══════  LIQUIDITY ENGINE  ══════╗"
input double   InpEqualLevelTolerance  = 0.15;    // % price tolerance for equal high/low clustering
input int      InpLiquidityLookback    = 40;

input group "╔══════  NEWS SHOCK PROXY  ══════╗"
input double   InpShockATRMultiple     = 2.5;     // current ATR vs avg ATR multiple to flag shock
input double   InpShockSpreadMultiple  = 2.0;     // spread vs rolling avg multiple to flag shock

input group "╔══════  STRATEGY HEALTH  ══════╗"
input int      InpHealthMinTrades      = 8;        // min trades before health scoring kicks in
input int      InpHealthDegradeConsecLoss = 4;     // consecutive losses to trigger influence reduction
input double   InpHealthMinExpectancyR = -0.10;    // below this expectancy, strategy gets throttled

input group "╔══════  ADAPTIVE PARAMETERS  ══════╗"
input bool     InpEnableAdaptiveParams = true;
input double   InpAdaptiveBoundPct     = 20.0;     // max % drift allowed from base thresholds

input group "╔══════  DASHBOARD  ══════╗"
input bool     InpShowDash             = true;
input int      InpDashX                = 14;
input int      InpDashY                = 14;
//=====================================================================
//  COLOR PALETTE (Institutional Theme)
//=====================================================================
#define C_BG0       C'5,7,16'
#define C_BG1       C'9,13,26'
#define C_BG2       C'13,19,38'
#define C_HDRBAR    C'11,17,34'
#define C_BORDER    C'24,46,88'
#define C_ACBORD    C'0,170,225'
#define C_GOLD      C'255,202,60'
#define C_CYAN      C'0,224,224'
#define C_PURPLE    C'182,108,255'
#define C_WHITE     C'222,228,242'
#define C_SUBTEXT   C'112,132,162'
#define C_GREEN     C'24,222,118'
#define C_RED       C'234,62,72'
#define C_ORANGE    C'255,150,10'
#define C_DKGREEN   C'15,82,48'
#define C_DKRED     C'82,22,28'
#define C_LBLUE     C'85,165,255'
#define C_DGRAY     C'42,54,74'
#define C_MGRAY     C'78,92,118'

//=====================================================================
//  GLOBAL OBJECTS
//=====================================================================
CTrade        g_trade;
CPositionInfo g_pos;
CAccountInfo  g_account;

//=====================================================================
//  INDICATOR HANDLES (Multi-timeframe)
//=====================================================================
int  g_h1_ema_fast, g_h1_ema_slow, g_h1_atr;
int  g_m15_ema_fast, g_m15_ema_slow, g_m15_atr, g_m15_rsi;
int  g_m5_ema_fast, g_m5_ema_slow, g_m5_atr, g_m5_rsi;
int  g_m1_ema_fast, g_m1_ema_slow, g_m1_atr;

//=====================================================================
//  STATE CONTAINERS (global singletons, updated each tick)
//=====================================================================
RegimeState       g_regime;
VolatilityState    g_vol;
LiquidityState     g_liq;
SessionState       g_session;
MTFBias            g_mtf;
ENUM_NEWS_STATE    g_newsState = NEWS_NORMAL;
RiskState          g_risk;
MasterDecision     g_lastDecision;

StrategyHealth     g_health[5];   // indexed by ENUM_STRATEGY - 1 (NONE excluded)

ExecutionQuality   g_execQuality;

//=====================================================================
//  SESSION / DAY TRACKING
//=====================================================================
datetime    g_dayStart       = 0;
datetime    g_weekStart      = 0;
int         g_tradesToday    = 0;
datetime    g_lastCloseTime  = 0;
bool        g_inCooldown     = false;
int         g_cooldownLeft   = 0;

//=====================================================================
//  ADAPTIVE PARAMETER STATE (Phase 11) — bounded drift only
//=====================================================================
double      g_adaptiveRegimeConfThreshold;  // drifts around InpMinRegimeConfidence
double      g_adaptiveExecScoreThreshold;   // drifts around InpMinExecutionScore

//=====================================================================
//  DASHBOARD / STATUS
//=====================================================================
string      g_statusText  = "INITIALIZING";
color       g_statusColor = C_ORANGE;
string      g_lastAction  = "Starting up...";

//=====================================================================
//  PERFORMANCE ANALYTICS (Phase 15)
//=====================================================================
double      g_sessionProfit   = 0.0;
int         g_sessionWins     = 0;
int         g_sessionLosses   = 0;
double      g_equityPeak      = 0.0;

//=====================================================================
//  CONSTANTS
//=====================================================================
const int   DW = 460;
const int   DH = 700;
//=====================================================================
//  TIME & SESSION HELPERS
//=====================================================================
datetime DayStart(datetime ts)
{
   MqlDateTime d; TimeToStruct(ts, d);
   return ts - (datetime)(d.hour*3600 + d.min*60 + d.sec);
}

datetime WeekStart(datetime ts)
{
   MqlDateTime d; TimeToStruct(ts, d);
   datetime ds = DayStart(ts);
   // day_of_week: 0=Sunday .. 6=Saturday. Treat Monday as week start.
   int offset = (d.day_of_week == 0) ? 6 : (d.day_of_week - 1);
   return ds - (datetime)(offset * 86400);
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

//=====================================================================
//  SESSION INTELLIGENCE ENGINE  (Phase 5)
//=====================================================================
// Server-time based session windows. These are broad, intentionally
// conservative bands; brokers vary in GMT offset so we classify by
// behavior overlap rather than exact exchange hours.
ENUM_SESSION ClassifySession(datetime ts)
{
   MqlDateTime d; TimeToStruct(ts, d);
   int hour = d.hour;

   if(hour >= 0  && hour < 7)   return SESSION_ASIAN;
   if(hour >= 7  && hour < 10)  return SESSION_LONDON_OPEN;
   if(hour >= 10 && hour < 12)  return SESSION_LONDON_MID;
   if(hour >= 12 && hour < 15)  return SESSION_NY_OPEN;
   if(hour >= 15 && hour < 21)  return SESSION_NY_PM;
   return SESSION_DEAD_ZONE; // 21:00-24:00 thin liquidity wind-down
}

void UpdateSessionIntelligence()
{
   g_session.current = ClassifySession(TimeCurrent());

   // Session range vs ATR — measures how much "room" this session typically has used so far
   double atrM5[1];
   if(CopyBuffer(g_m5_atr, 0, 0, 1, atrM5) <= 0) atrM5[0] = 0;

   double sessionHigh = iHigh(_Symbol, PERIOD_M5, 0);
   double sessionLow   = iLow(_Symbol, PERIOD_M5, 0);
   int barsBack = 12; // ~1hr on M5, rough proxy for session activity snapshot
   for(int i = 1; i < barsBack; i++)
   {
      double h = iHigh(_Symbol, PERIOD_M5, i);
      double l = iLow(_Symbol, PERIOD_M5, i);
      if(h > sessionHigh) sessionHigh = h;
      if(l < sessionLow)  sessionLow  = l;
   }
   double range = sessionHigh - sessionLow;
   g_session.sessionRangeATRRatio = (atrM5[0] > 0) ? (range / atrM5[0]) : 0.0;
   g_session.sessionVolatilityScore = MathMin(100.0, g_session.sessionRangeATRRatio * 25.0);

   // Session-specific strategy preference + weight multiplier (Phase 5 requirement)
   switch(g_session.current)
   {
      case SESSION_ASIAN:
         g_session.preferredStrategy = STRAT_MEAN_REVERSION;
         g_session.strategyWeight    = 1.1;   // ranges dominate low-liquidity Asian hours
         break;
      case SESSION_LONDON_OPEN:
         g_session.preferredStrategy = STRAT_VOLATILITY_EXPANSION;
         g_session.strategyWeight    = 1.3;   // London open often drives breakout/expansion
         break;
      case SESSION_LONDON_MID:
         g_session.preferredStrategy = STRAT_TREND_SCALPER;
         g_session.strategyWeight    = 1.0;
         break;
      case SESSION_NY_OPEN:
         g_session.preferredStrategy = STRAT_LIQUIDITY_REVERSAL;
         g_session.strategyWeight    = 1.25;  // NY open frequently sweeps London liquidity
         break;
      case SESSION_NY_PM:
         g_session.preferredStrategy = STRAT_TREND_SCALPER;
         g_session.strategyWeight    = 0.9;
         break;
      default: // DEAD_ZONE
         g_session.preferredStrategy = STRAT_NONE;
         g_session.strategyWeight    = 0.5;   // heavily discourage trading thin hours
         break;
   }
}

//=====================================================================
//  MARKET INTELLIGENCE ENGINE  (Phase 1 / Phase 13 MTF)
//=====================================================================
// Computes raw directional bias per timeframe using EMA relationship +
// slope. This feeds both regime classification and the strategy router.

int ComputeTFBias(int emaFastHandle, int emaSlowHandle, ENUM_TIMEFRAMES tf)
{
   double fastNow[2], slowNow[2];
   if(CopyBuffer(emaFastHandle, 0, 0, 2, fastNow) < 2) return 0;
   if(CopyBuffer(emaSlowHandle, 0, 0, 2, slowNow) < 2) return 0;

   double spreadNow  = fastNow[0] - slowNow[0];
   double spreadPrev = fastNow[1] - slowNow[1];

   // Direction from EMA stack
   int dirStack = (fastNow[0] > slowNow[0]) ? 1 : (fastNow[0] < slowNow[0] ? -1 : 0);

   // Slope confirms or weakens the read — if spread is shrinking against the
   // stack direction, treat as weak/neutral rather than flipping outright.
   bool widening = MathAbs(spreadNow) > MathAbs(spreadPrev);

   if(dirStack == 0) return 0;
   if(!widening && MathAbs(spreadNow) < MathAbs(spreadPrev) * 0.5) return 0; // momentum fading hard

   return dirStack;
}

void UpdateMTFBias()
{
   g_mtf.h1Bias  = ComputeTFBias(g_h1_ema_fast,  g_h1_ema_slow,  PERIOD_H1);
   g_mtf.m15Bias = ComputeTFBias(g_m15_ema_fast, g_m15_ema_slow, PERIOD_M15);
   g_mtf.m5Bias  = ComputeTFBias(g_m5_ema_fast,  g_m5_ema_slow,  PERIOD_M5);
   g_mtf.m1Bias  = ComputeTFBias(g_m1_ema_fast,  g_m1_ema_slow,  PERIOD_M1);

   int biases[4] = {g_mtf.h1Bias, g_mtf.m15Bias, g_mtf.m5Bias, g_mtf.m1Bias};
   int agree = 0, nonzero = 0;
   int refDir = 0;
   for(int i = 0; i < 4; i++)
   {
      if(biases[i] != 0)
      {
         nonzero++;
         if(refDir == 0) refDir = biases[i];
         else if(biases[i] == refDir) agree++;
      }
   }
   // Alignment: % of non-zero timeframes agreeing with the first non-zero ref direction
   g_mtf.alignment = (nonzero > 1) ? (100.0 * (double)(agree + 1) / (double)nonzero) : (nonzero == 1 ? 50.0 : 0.0);
}

//=====================================================================
//  SWING / STRUCTURE HELPERS  (used by regime + liquidity engines)
//=====================================================================
// Finds the highest high and lowest low over a lookback window on the
// working timeframe (M5), returning index-aligned values for structure
// and liquidity analysis.
double StructureHighestHigh(int lookback, int shift=0)
{
   int idx = iHighest(_Symbol, PERIOD_M5, MODE_HIGH, lookback, shift);
   if(idx < 0) return 0;
   return iHigh(_Symbol, PERIOD_M5, idx);
}

double StructureLowestLow(int lookback, int shift=0)
{
   int idx = iLowest(_Symbol, PERIOD_M5, MODE_LOW, lookback, shift);
   if(idx < 0) return 0;
   return iLow(_Symbol, PERIOD_M5, idx);
}

// Simple swing point detector: a bar is a swing high if it's higher than
// 'wing' bars on each side; swing low analogous. Returns count of swings
// found in lookback and fills price arrays (caller pre-sizes to lookback).
int FindSwingHighs(int lookback, int wing, double &outPrices[], datetime &outTimes[])
{
   int count = 0;
   for(int i = wing; i < lookback - wing; i++)
   {
      double h = iHigh(_Symbol, PERIOD_M5, i);
      bool isSwing = true;
      for(int w = 1; w <= wing; w++)
      {
         if(iHigh(_Symbol, PERIOD_M5, i-w) >= h || iHigh(_Symbol, PERIOD_M5, i+w) >= h)
         { isSwing = false; break; }
      }
      if(isSwing && count < ArraySize(outPrices))
      {
         outPrices[count] = h;
         outTimes[count]  = iTime(_Symbol, PERIOD_M5, i);
         count++;
      }
   }
   return count;
}

int FindSwingLows(int lookback, int wing, double &outPrices[], datetime &outTimes[])
{
   int count = 0;
   for(int i = wing; i < lookback - wing; i++)
   {
      double l = iLow(_Symbol, PERIOD_M5, i);
      bool isSwing = true;
      for(int w = 1; w <= wing; w++)
      {
         if(iLow(_Symbol, PERIOD_M5, i-w) <= l || iLow(_Symbol, PERIOD_M5, i+w) <= l)
         { isSwing = false; break; }
      }
      if(isSwing && count < ArraySize(outPrices))
      {
         outPrices[count] = l;
         outTimes[count]  = iTime(_Symbol, PERIOD_M5, i);
         count++;
      }
   }
   return count;
}
//=====================================================================
//  VOLATILITY INTELLIGENCE ENGINE  (Phase 6)
//=====================================================================
void UpdateVolatilityIntelligence()
{
   double atrBuf[];
   ArrayResize(atrBuf, InpATRLookback);
   ArraySetAsSeries(atrBuf, true);

   int got = CopyBuffer(g_m5_atr, 0, 0, InpATRLookback, atrBuf);
   if(got < InpATRLookback / 2 || got <= 0)
   {
      g_vol.state   = VOL_NORMAL;
      g_vol.dynamic = VOLDYN_STABLE;
      return;
   }

   double current = atrBuf[0];
   double sum = 0;
   int n = 0;
   for(int i = 0; i < got; i++) { sum += atrBuf[i]; n++; }
   double avg = (n > 0) ? sum / n : current;

   g_vol.atrCurrent = current;
   g_vol.atrAvg     = avg;
   g_vol.atrRatio   = (avg > 0) ? current / avg : 1.0;

   // Percentile rank of current ATR within lookback
   int below = 0;
   for(int i = 0; i < got; i++) if(atrBuf[i] <= current) below++;
   g_vol.percentile = (got > 0) ? (100.0 * below / got) : 50.0;

   // Classify absolute volatility state by percentile
   if(g_vol.percentile < 25)       g_vol.state = VOL_LOW;
   else if(g_vol.percentile < 65)  g_vol.state = VOL_NORMAL;
   else if(g_vol.percentile < 90)  g_vol.state = VOL_HIGH;
   else                            g_vol.state = VOL_EXTREME;

   // Classify dynamic (rate of change of ATR over last few bars)
   double atrPrev3 = (got > 3) ? atrBuf[3] : avg;
   double roc = (atrPrev3 > 0) ? (current - atrPrev3) / atrPrev3 : 0.0;

   if(g_vol.atrRatio >= InpShockATRMultiple)
      g_vol.dynamic = VOLDYN_SPIKE;
   else if(roc > 0.15)
      g_vol.dynamic = VOLDYN_EXPANDING;
   else if(roc < -0.15)
      g_vol.dynamic = VOLDYN_COMPRESSING;
   else
      g_vol.dynamic = VOLDYN_STABLE;
}

//=====================================================================
//  NEWS SHOCK PROXY SYSTEM  (Phase 12) — no calendar/API dependency
//=====================================================================
// Infers abnormal-event conditions purely from market behavior: ATR
// dislocation, spread explosion relative to its own rolling average,
// and single-bar range displacement vs recent norm.
double g_spreadHistory[20];
int    g_spreadHistCount = 0;

void UpdateNewsShockProxy()
{
   // Roll spread history (points)
   double spreadNow = (double)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   if(g_spreadHistCount < 20)
   {
      g_spreadHistory[g_spreadHistCount] = spreadNow;
      g_spreadHistCount++;
   }
   else
   {
      for(int i = 0; i < 19; i++) g_spreadHistory[i] = g_spreadHistory[i+1];
      g_spreadHistory[19] = spreadNow;
   }

   double spreadSum = 0;
   for(int i = 0; i < g_spreadHistCount; i++) spreadSum += g_spreadHistory[i];
   double spreadAvg = (g_spreadHistCount > 0) ? spreadSum / g_spreadHistCount : spreadNow;
   double spreadRatio = (spreadAvg > 0) ? spreadNow / spreadAvg : 1.0;

   // Single-bar displacement: current M5 bar range vs ATR
   double barRange = iHigh(_Symbol, PERIOD_M5, 0) - iLow(_Symbol, PERIOD_M5, 0);
   double atrRatioForBar = (g_vol.atrAvg > 0) ? barRange / g_vol.atrAvg : 1.0;

   bool atrShock    = g_vol.atrRatio    >= InpShockATRMultiple;
   bool spreadShock = spreadRatio       >= InpShockSpreadMultiple;
   bool barShock     = atrRatioForBar   >= InpShockATRMultiple;

   int shockSignals = (atrShock ? 1 : 0) + (spreadShock ? 1 : 0) + (barShock ? 1 : 0);

   if(shockSignals >= 2)
      g_newsState = NEWS_SHOCK;
   else if(shockSignals == 1)
      g_newsState = NEWS_CAUTION;
   else
      g_newsState = NEWS_NORMAL;
}
//=====================================================================
//  LIQUIDITY INTELLIGENCE ENGINE  (Phase 4)
//=====================================================================
// Detects equal highs/lows (stop cluster proxies), evaluates sweep
// candidates (wick beyond a cluster level followed by rejection back
// inside range), and produces bias/pressure/imbalance scores.

void UpdateLiquidityIntelligence()
{
   double swingHighPrices[30];
   datetime swingHighTimes[30];
   double swingLowPrices[30];
   datetime swingLowTimes[30];

   int nHighs = FindSwingHighs(InpLiquidityLookback, 2, swingHighPrices, swingHighTimes);
   int nLows  = FindSwingLows(InpLiquidityLookback, 2, swingLowPrices, swingLowTimes);

   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   double price  = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double tolAbs = price * (InpEqualLevelTolerance / 100.0);

   // --- Equal highs detection: cluster swing highs within tolerance
   g_liq.equalHighsDetected = false;
   g_liq.equalHighLevel     = 0;
   int bestHighClusterCount = 0;
   for(int i = 0; i < nHighs; i++)
   {
      int clusterCount = 1;
      double sumLevel = swingHighPrices[i];
      for(int j = 0; j < nHighs; j++)
      {
         if(j == i) continue;
         if(MathAbs(swingHighPrices[j] - swingHighPrices[i]) <= tolAbs)
         {
            clusterCount++;
            sumLevel += swingHighPrices[j];
         }
      }
      if(clusterCount >= 2 && clusterCount > bestHighClusterCount)
      {
         bestHighClusterCount = clusterCount;
         g_liq.equalHighLevel = sumLevel / clusterCount;
         g_liq.equalHighsDetected = true;
      }
   }

   // --- Equal lows detection (mirror logic)
   g_liq.equalLowsDetected = false;
   g_liq.equalLowLevel     = 0;
   int bestLowClusterCount = 0;
   for(int i = 0; i < nLows; i++)
   {
      int clusterCount = 1;
      double sumLevel = swingLowPrices[i];
      for(int j = 0; j < nLows; j++)
      {
         if(j == i) continue;
         if(MathAbs(swingLowPrices[j] - swingLowPrices[i]) <= tolAbs)
         {
            clusterCount++;
            sumLevel += swingLowPrices[j];
         }
      }
      if(clusterCount >= 2 && clusterCount > bestLowClusterCount)
      {
         bestLowClusterCount = clusterCount;
         g_liq.equalLowLevel = sumLevel / clusterCount;
         g_liq.equalLowsDetected = true;
      }
   }

   // --- Sweep detection: last 3 bars wick through a cluster level then close back inside
   g_liq.sweepUpDetected   = false;
   g_liq.sweepDownDetected = false;

   if(g_liq.equalHighsDetected)
   {
      for(int i = 0; i < 3; i++)
      {
         double hi = iHigh(_Symbol, PERIOD_M5, i);
         double cl = iClose(_Symbol, PERIOD_M5, i);
         if(hi > g_liq.equalHighLevel && cl < g_liq.equalHighLevel)
         {
            g_liq.sweepUpDetected = true;
            break;
         }
      }
   }
   if(g_liq.equalLowsDetected)
   {
      for(int i = 0; i < 3; i++)
      {
         double lo = iLow(_Symbol, PERIOD_M5, i);
         double cl = iClose(_Symbol, PERIOD_M5, i);
         if(lo < g_liq.equalLowLevel && cl > g_liq.equalLowLevel)
         {
            g_liq.sweepDownDetected = true;
            break;
         }
      }
   }

   // --- Sweep probability: proximity of current price to nearest cluster,
   // scaled by how "stacked" (equal) the cluster is.
   double distToHigh = g_liq.equalHighsDetected ? MathAbs(price - g_liq.equalHighLevel) : -1;
   double distToLow   = g_liq.equalLowsDetected  ? MathAbs(price - g_liq.equalLowLevel)  : -1;

   double proximityScore = 0;
   if(distToHigh >= 0 && g_vol.atrAvg > 0)
      proximityScore = MathMax(proximityScore, 100.0 * MathMax(0.0, 1.0 - distToHigh / (g_vol.atrAvg * 1.5)));
   if(distToLow >= 0 && g_vol.atrAvg > 0)
      proximityScore = MathMax(proximityScore, 100.0 * MathMax(0.0, 1.0 - distToLow / (g_vol.atrAvg * 1.5)));

   g_liq.sweepProbability = MathMin(100.0, proximityScore);

   // --- Bias score: negative (sell-side liquidity below price, i.e. downside sweep risk)
   // positive (buy-side liquidity above price). Closer cluster = stronger pull.
   double bias = 0;
   if(distToHigh >= 0 && distToLow >= 0)
      bias = (distToLow < distToHigh) ? -40.0 : 40.0; // nearer cluster exerts pull toward it (then reversal)
   else if(distToHigh >= 0) bias = 40.0;
   else if(distToLow >= 0)  bias = -40.0;

   if(g_liq.sweepUpDetected)   bias = -70.0; // swept highs -> bias reversal short
   if(g_liq.sweepDownDetected) bias = 70.0;  // swept lows -> bias reversal long

   g_liq.biasScore = bias;

   // --- Pressure score: combination of cluster density and sweep recency
   g_liq.pressureScore = MathMin(100.0, (bestHighClusterCount + bestLowClusterCount) * 12.0 + (g_liq.sweepProbability * 0.3));

   // --- Imbalance score: asymmetry between buy-side and sell-side liquidity pools
   double poolAsym = MathAbs((double)bestHighClusterCount - (double)bestLowClusterCount);
   g_liq.imbalanceScore = MathMin(100.0, poolAsym * 20.0);
}
//=====================================================================
//  REGIME CLASSIFICATION ENGINE  (Phase 2)
//=====================================================================
// Scores each candidate regime using a weighted-evidence model built
// from ATR dynamics, EMA slope/stack, structure (higher highs/lows vs
// compression), momentum acceleration, and liquidity sweep signals.
// The highest-scoring regime wins, gated by a minimum confidence floor.

double g_regimeStreakBars = 0;
ENUM_REGIME g_regimePersistTrack = REGIME_RANGING;

double ScoreTrending()
{
   double score = 0;
   // Strong MTF alignment is the primary trending signal
   score += g_mtf.alignment * 0.5;
   // EMA stack confirms
   if(g_mtf.m5Bias != 0 && g_mtf.m5Bias == g_mtf.h1Bias) score += 20;
   // Healthy (not extreme) volatility supports sustained trend
   if(g_vol.state == VOL_NORMAL || g_vol.state == VOL_HIGH) score += 15;
   if(g_vol.dynamic == VOLDYN_EXPANDING) score += 10;
   return MathMin(100.0, score);
}

double ScoreRanging()
{
   double score = 0;
   if(g_mtf.alignment < 40) score += 40;
   if(g_vol.state == VOL_LOW || g_vol.state == VOL_NORMAL) score += 25;
   if(g_vol.dynamic == VOLDYN_STABLE) score += 20;
   // Price oscillating between recent structure bounds without progress
   double hh = StructureHighestHigh(InpStructureLookback);
   double ll = StructureLowestLow(InpStructureLookback);
   double mid = (hh + ll) / 2.0;
   double price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double rangePos = (hh > ll) ? MathAbs(price - mid) / ((hh - ll) / 2.0) : 1.0;
   if(rangePos < 0.6) score += 15;
   return MathMin(100.0, score);
}

double ScoreBreakout()
{
   double score = 0;
   double hh = StructureHighestHigh(InpStructureLookback, 1);
   double ll = StructureLowestLow(InpStructureLookback, 1);
   double price = SymbolInfoDouble(_Symbol, SYMBOL_BID);

   bool brokeUp   = price > hh;
   bool brokeDown = price < ll;

   if(brokeUp || brokeDown) score += 45;
   if(g_vol.dynamic == VOLDYN_EXPANDING) score += 25;
   if(g_vol.state == VOL_HIGH) score += 15;
   if(g_mtf.alignment > 60) score += 15;
   return MathMin(100.0, score);
}

double ScoreCompression()
{
   double score = 0;
   if(g_vol.state == VOL_LOW) score += 35;
   if(g_vol.dynamic == VOLDYN_COMPRESSING) score += 35;
   if(g_vol.percentile < 15) score += 20;
   if(g_mtf.alignment < 30) score += 10;
   return MathMin(100.0, score);
}

double ScoreExpansion()
{
   double score = 0;
   if(g_vol.dynamic == VOLDYN_EXPANDING) score += 40;
   if(g_vol.state == VOL_HIGH) score += 25;
   if(g_vol.atrRatio > 1.3) score += 20;
   if(g_mtf.alignment > 50) score += 15;
   return MathMin(100.0, score);
}

double ScoreVolatilityShock()
{
   double score = 0;
   if(g_vol.dynamic == VOLDYN_SPIKE) score += 50;
   if(g_vol.state == VOL_EXTREME) score += 30;
   if(g_newsState == NEWS_SHOCK) score += 20;
   return MathMin(100.0, score);
}

double ScoreLiquiditySweep()
{
   double score = 0;
   if(g_liq.sweepUpDetected || g_liq.sweepDownDetected) score += 50;
   score += g_liq.sweepProbability * 0.3;
   score += g_liq.pressureScore * 0.2;
   return MathMin(100.0, score);
}

double ScoreExhaustion()
{
   double score = 0;
   // Momentum deceleration after extension: alignment was high, ATR ratio falling, RSI extreme
   double rsiM5[1];
   if(CopyBuffer(g_m5_rsi, 0, 0, 1, rsiM5) > 0)
   {
      if(rsiM5[0] > 72 || rsiM5[0] < 28) score += 35;
   }
   if(g_vol.dynamic == VOLDYN_COMPRESSING && g_vol.atrRatio < 0.85) score += 25;
   if(g_mtf.m1Bias != 0 && g_mtf.m5Bias != 0 && g_mtf.m1Bias != g_mtf.m5Bias) score += 20; // lower-TF stalling vs higher-TF push
   return MathMin(100.0, score);
}

double ScoreMeanReversion()
{
   double score = 0;
   double rsiM5[1];
   if(CopyBuffer(g_m5_rsi, 0, 0, 1, rsiM5) > 0)
   {
      if(rsiM5[0] > 70 || rsiM5[0] < 30) score += 30;
   }
   if(g_vol.state == VOL_NORMAL) score += 20;
   if(g_mtf.alignment < 45) score += 25;
   if(g_liq.sweepUpDetected || g_liq.sweepDownDetected) score += 15;
   return MathMin(100.0, score);
}

double ScoreUnsafe()
{
   double score = 0;
   if(g_newsState == NEWS_SHOCK) score += 60;
   if(g_vol.state == VOL_EXTREME) score += 25;
   double spread = (double)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   if(spread > InpMaxSpreadPoints) score += 30;
   return MathMin(100.0, score);
}

void UpdateRegimeClassification()
{
   ENUM_REGIME candidates[10] = {
      REGIME_TRENDING, REGIME_RANGING, REGIME_BREAKOUT, REGIME_COMPRESSION,
      REGIME_EXPANSION, REGIME_VOLATILITY_SHOCK, REGIME_LIQUIDITY_SWEEP,
      REGIME_EXHAUSTION, REGIME_MEAN_REVERSION, REGIME_UNSAFE
   };
   double scores[10];
   scores[0] = ScoreTrending();
   scores[1] = ScoreRanging();
   scores[2] = ScoreBreakout();
   scores[3] = ScoreCompression();
   scores[4] = ScoreExpansion();
   scores[5] = ScoreVolatilityShock();
   scores[6] = ScoreLiquiditySweep();
   scores[7] = ScoreExhaustion();
   scores[8] = ScoreMeanReversion();
   scores[9] = ScoreUnsafe();

   // UNSAFE overrides everything if its score crosses a hard floor —
   // safety must not be out-voted by an enthusiastic trend score.
   int bestIdx = 0;
   double bestScore = scores[0];
   for(int i = 1; i < 10; i++)
   {
      if(scores[i] > bestScore) { bestScore = scores[i]; bestIdx = i; }
   }
   if(scores[9] >= 55.0) { bestIdx = 9; bestScore = scores[9]; }

   ENUM_REGIME newRegime = candidates[bestIdx];

   // Stability tracking: how many consecutive bars this regime has held
   if(newRegime == g_regimePersistTrack) g_regimeStreakBars++;
   else
   {
      g_regimeStreakBars = 0;
      g_regimePersistTrack = newRegime;
      g_regime.sinceTime = TimeCurrent();
      g_regime.previousRegime = g_regime.regime;
   }

   g_regime.regime     = newRegime;
   g_regime.confidence  = bestScore;
   g_regime.stability   = MathMin(100.0, g_regimeStreakBars * 8.0);

   // Adaptive floor (Phase 11) — if confidence persistently sits high above
   // threshold, no change needed; engine only nudges threshold within bounds
   // elsewhere (see Adaptive Parameter Engine). Below-floor confidence here
   // simply forces an UNSAFE handling decision downstream in the router.
}

string RegimeToString(ENUM_REGIME r)
{
   switch(r)
   {
      case REGIME_TRENDING:         return "TRENDING";
      case REGIME_RANGING:          return "RANGING";
      case REGIME_BREAKOUT:         return "BREAKOUT";
      case REGIME_COMPRESSION:      return "COMPRESSION";
      case REGIME_EXPANSION:        return "EXPANSION";
      case REGIME_VOLATILITY_SHOCK: return "VOL SHOCK";
      case REGIME_LIQUIDITY_SWEEP:  return "LIQ SWEEP";
      case REGIME_EXHAUSTION:       return "EXHAUSTION";
      case REGIME_MEAN_REVERSION:   return "MEAN REV";
      case REGIME_UNSAFE:           return "UNSAFE";
      default:                      return "UNKNOWN";
   }
}
//=====================================================================
//  STRATEGY MODULES  (Phase 3) — each returns a StrategySignal.
//  Only the router-selected strategy's signal is ever acted upon;
//  modules never execute trades directly. Mutual exclusion is
//  enforced entirely at the router level, not inside modules.
//=====================================================================

StrategySignal Strategy_TrendScalper()
{
   StrategySignal s;
   s.source = STRAT_TREND_SCALPER;
   s.direction = DIR_NONE;
   s.valid = false;
   s.reason = "";

   if(g_mtf.alignment < 55) { s.reason = "Insufficient MTF alignment"; return s; }

   int dir = (g_mtf.h1Bias != 0) ? g_mtf.h1Bias : g_mtf.m15Bias;
   if(dir == 0) { s.reason = "No macro bias"; return s; }
   if(g_mtf.m5Bias != dir) { s.reason = "M5 setup not aligned with macro"; return s; }

   double atr = g_vol.atrCurrent;
   double price = (dir > 0) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);

   s.direction   = (dir > 0) ? DIR_LONG : DIR_SHORT;
   s.confidence  = MathMin(95.0, g_mtf.alignment * 0.9 + g_regime.confidence * 0.1);
   s.suggestedSL = (dir > 0) ? NPrice(price - atr * 1.5) : NPrice(price + atr * 1.5);
   s.suggestedTP = (dir > 0) ? NPrice(price + atr * 2.5) : NPrice(price - atr * 2.5);
   s.reason      = "Trend continuation: MTF aligned " + DoubleToString(g_mtf.alignment,0) + "%";
   s.valid       = true;
   return s;
}

StrategySignal Strategy_MeanReversion()
{
   StrategySignal s;
   s.source = STRAT_MEAN_REVERSION;
   s.direction = DIR_NONE;
   s.valid = false;
   s.reason = "";

   double rsiM5[1];
   if(CopyBuffer(g_m5_rsi, 0, 0, 1, rsiM5) <= 0) { s.reason = "RSI unavailable"; return s; }

   bool overbought = rsiM5[0] > 70;
   bool oversold    = rsiM5[0] < 30;
   if(!overbought && !oversold) { s.reason = "RSI not extended"; return s; }

   double hh = StructureHighestHigh(InpStructureLookback);
   double ll = StructureLowestLow(InpStructureLookback);
   double mid = (hh + ll) / 2.0;
   double atr = g_vol.atrCurrent;
   double price = SymbolInfoDouble(_Symbol, SYMBOL_BID);

   if(overbought)
   {
      s.direction   = DIR_SHORT;
      double entryPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      s.suggestedSL = NPrice(entryPrice + atr * 1.2);
      s.suggestedTP = NPrice(MathMax(mid, entryPrice - atr * 1.8));
   }
   else
   {
      s.direction   = DIR_LONG;
      double entryPrice = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      s.suggestedSL = NPrice(entryPrice - atr * 1.2);
      s.suggestedTP = NPrice(MathMin(mid, entryPrice + atr * 1.8));
   }
   s.confidence = MathMin(90.0, MathAbs(rsiM5[0] - 50.0) * 1.6);
   s.reason     = "Mean reversion: RSI " + DoubleToString(rsiM5[0],1) + " extended in range";
   s.valid      = true;
   return s;
}

StrategySignal Strategy_VolatilityExpansion()
{
   StrategySignal s;
   s.source = STRAT_VOLATILITY_EXPANSION;
   s.direction = DIR_NONE;
   s.valid = false;
   s.reason = "";

   if(g_vol.dynamic != VOLDYN_EXPANDING) { s.reason = "Not in expansion phase"; return s; }

   double hh = StructureHighestHigh(InpStructureLookback, 1);
   double ll = StructureLowestLow(InpStructureLookback, 1);
   double price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double atr = g_vol.atrCurrent;

   bool brokeUp   = price > hh;
   bool brokeDown = price < ll;
   if(!brokeUp && !brokeDown) { s.reason = "No structural break yet"; return s; }

   if(brokeUp)
   {
      double entryPrice = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      s.direction   = DIR_LONG;
      s.suggestedSL = NPrice(hh - atr * 0.4);
      s.suggestedTP = NPrice(entryPrice + atr * 3.0);
   }
   else
   {
      double entryPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      s.direction   = DIR_SHORT;
      s.suggestedSL = NPrice(ll + atr * 0.4);
      s.suggestedTP = NPrice(entryPrice - atr * 3.0);
   }
   s.confidence = MathMin(92.0, 50.0 + g_vol.atrRatio * 20.0);
   s.reason     = "Volatility expansion breakout, ATR ratio " + DoubleToString(g_vol.atrRatio,2);
   s.valid      = true;
   return s;
}

StrategySignal Strategy_LiquidityReversal()
{
   StrategySignal s;
   s.source = STRAT_LIQUIDITY_REVERSAL;
   s.direction = DIR_NONE;
   s.valid = false;
   s.reason = "";

   if(!g_liq.sweepUpDetected && !g_liq.sweepDownDetected) { s.reason = "No sweep detected"; return s; }

   double atr = g_vol.atrCurrent;

   if(g_liq.sweepUpDetected)
   {
      double entryPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      s.direction   = DIR_SHORT;
      s.suggestedSL = NPrice(g_liq.equalHighLevel + atr * 0.3);
      s.suggestedTP = NPrice(entryPrice - atr * 2.2);
   }
   else // sweepDownDetected
   {
      double entryPrice = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      s.direction   = DIR_LONG;
      s.suggestedSL = NPrice(g_liq.equalLowLevel - atr * 0.3);
      s.suggestedTP = NPrice(entryPrice + atr * 2.2);
   }
   s.confidence = MathMin(93.0, g_liq.sweepProbability * 0.5 + g_liq.pressureScore * 0.4);
   s.reason     = "Liquidity sweep reversal, pressure " + DoubleToString(g_liq.pressureScore,0);
   s.valid      = true;
   return s;
}

StrategySignal Strategy_CompressionBreakout()
{
   StrategySignal s;
   s.source = STRAT_COMPRESSION_BREAKOUT;
   s.direction = DIR_NONE;
   s.valid = false;
   s.reason = "";

   // Looks for the *edge* of compression: still low vol but momentum
   // ticking up, anticipating imminent expansion rather than chasing one.
   if(g_vol.state != VOL_LOW) { s.reason = "Not in low-vol compression"; return s; }
   if(g_mtf.m1Bias == 0) { s.reason = "No micro momentum yet"; return s; }

   double hh = StructureHighestHigh(InpStructureLookback / 2);
   double ll = StructureLowestLow(InpStructureLookback / 2);
   double price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double rangeSize = hh - ll;
   if(rangeSize <= 0) { s.reason = "Invalid compression range"; return s; }

   double posInRange = (price - ll) / rangeSize;
   double atr = g_vol.atrCurrent;

   // Near top of compression range + bullish micro momentum -> anticipate upside break
   if(posInRange > 0.7 && g_mtf.m1Bias > 0)
   {
      double entryPrice = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      s.direction   = DIR_LONG;
      s.suggestedSL = NPrice(ll);
      s.suggestedTP = NPrice(entryPrice + rangeSize * 1.5);
   }
   else if(posInRange < 0.3 && g_mtf.m1Bias < 0)
   {
      double entryPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      s.direction   = DIR_SHORT;
      s.suggestedSL = NPrice(hh);
      s.suggestedTP = NPrice(entryPrice - rangeSize * 1.5);
   }
   else { s.reason = "Price not at compression edge with confirming momentum"; return s; }

   s.confidence = MathMin(88.0, 45.0 + (100.0 - g_vol.percentile) * 0.4);
   s.reason     = "Compression edge break, range pos " + DoubleToString(posInRange,2);
   s.valid      = true;
   return s;
}

//=====================================================================
//  STRATEGY ROUTER  (Phase 3) — strict mutual exclusion
//=====================================================================
ENUM_STRATEGY RouteRegimeToStrategy(ENUM_REGIME regime)
{
   switch(regime)
   {
      case REGIME_TRENDING:         return STRAT_TREND_SCALPER;
      case REGIME_RANGING:          return STRAT_MEAN_REVERSION;
      case REGIME_BREAKOUT:         return STRAT_VOLATILITY_EXPANSION;
      case REGIME_EXPANSION:        return STRAT_VOLATILITY_EXPANSION;
      case REGIME_LIQUIDITY_SWEEP:  return STRAT_LIQUIDITY_REVERSAL;
      case REGIME_COMPRESSION:      return STRAT_COMPRESSION_BREAKOUT;
      case REGIME_MEAN_REVERSION:   return STRAT_MEAN_REVERSION;
      case REGIME_EXHAUSTION:       return STRAT_NONE; // no edge defined — stand aside
      case REGIME_VOLATILITY_SHOCK: return STRAT_NONE; // safety stand-aside
      case REGIME_UNSAFE:           return STRAT_NONE;
      default:                      return STRAT_NONE;
   }
}

StrategySignal GetSignalForStrategy(ENUM_STRATEGY strat)
{
   StrategySignal s;
   s.valid = false;
   s.direction = DIR_NONE;
   s.source = strat;

   switch(strat)
   {
      case STRAT_TREND_SCALPER:          return Strategy_TrendScalper();
      case STRAT_MEAN_REVERSION:         return Strategy_MeanReversion();
      case STRAT_VOLATILITY_EXPANSION:   return Strategy_VolatilityExpansion();
      case STRAT_LIQUIDITY_REVERSAL:     return Strategy_LiquidityReversal();
      case STRAT_COMPRESSION_BREAKOUT:   return Strategy_CompressionBreakout();
      default: s.reason = "No strategy routed"; return s;
   }
}

int StrategyHealthIndex(ENUM_STRATEGY s)
{
   // Maps strategy enum to g_health[] array index (STRAT_NONE excluded)
   switch(s)
   {
      case STRAT_TREND_SCALPER:        return 0;
      case STRAT_MEAN_REVERSION:       return 1;
      case STRAT_VOLATILITY_EXPANSION: return 2;
      case STRAT_LIQUIDITY_REVERSAL:   return 3;
      case STRAT_COMPRESSION_BREAKOUT: return 4;
      default: return -1;
   }
}

string StrategyToString(ENUM_STRATEGY s)
{
   switch(s)
   {
      case STRAT_TREND_SCALPER:        return "Trend Scalper";
      case STRAT_MEAN_REVERSION:       return "Mean Reversion";
      case STRAT_VOLATILITY_EXPANSION: return "Volatility Expansion";
      case STRAT_LIQUIDITY_REVERSAL:   return "Liquidity Reversal";
      case STRAT_COMPRESSION_BREAKOUT: return "Compression Breakout";
      default:                         return "None";
   }
}
//=====================================================================
//  EXECUTION QUALITY ENGINE  (Phase 8)
//=====================================================================
void UpdateExecutionQuality()
{
   double spread = (double)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);

   // Spread score: 100 at zero spread, decays to 0 at InpMaxSpreadPoints
   g_execQuality.spreadScore = MathMax(0.0, 100.0 * (1.0 - spread / InpMaxSpreadPoints));

   // Slippage risk: derived from spread volatility + news state, not just raw spread
   double slippageRisk = 0;
   if(g_newsState == NEWS_SHOCK)   slippageRisk = 90;
   else if(g_newsState == NEWS_CAUTION) slippageRisk = 50;
   else slippageRisk = MathMin(40.0, spread / InpMaxSpreadPoints * 40.0);
   g_execQuality.slippageRiskScore = 100.0 - slippageRisk;

   // Volatility quality: extreme or shock volatility degrades execution reliability
   double volQuality = 100;
   if(g_vol.state == VOL_EXTREME) volQuality = 20;
   else if(g_vol.state == VOL_HIGH) volQuality = 65;
   else if(g_vol.state == VOL_LOW) volQuality = 80; // too quiet can mean unreliable fills too, mild penalty
   else volQuality = 100;
   g_execQuality.volatilityQuality = volQuality;

   // Liquidity quality: thin sessions / dead zones reduce fill reliability
   double liqQuality = 100;
   if(g_session.current == SESSION_DEAD_ZONE) liqQuality = 35;
   else if(g_session.current == SESSION_ASIAN) liqQuality = 70;
   else liqQuality = 95;
   g_execQuality.liquidityQuality = liqQuality;

   // Market efficiency: penalize when spread is wide relative to current ATR
   // (i.e., cost of entry is large relative to expected move)
   double efficiency = 100;
   if(g_vol.atrCurrent > 0)
   {
      double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
      double spreadInPrice = spread * point;
      double costRatio = spreadInPrice / g_vol.atrCurrent;
      efficiency = MathMax(0.0, 100.0 * (1.0 - costRatio * 5.0));
   }
   g_execQuality.efficiencyScore = efficiency;

   // Composite — weighted blend
   g_execQuality.compositeScore =
        g_execQuality.spreadScore        * 0.25
      + g_execQuality.slippageRiskScore  * 0.25
      + g_execQuality.volatilityQuality  * 0.20
      + g_execQuality.liquidityQuality   * 0.15
      + g_execQuality.efficiencyScore    * 0.15;

   g_execQuality.executionApproved = true;
   g_execQuality.rejectReason = "";

   if(spread > InpMaxSpreadPoints)
   {
      g_execQuality.executionApproved = false;
      g_execQuality.rejectReason = "Spread " + DoubleToString(spread,0) + " exceeds max " + DoubleToString(InpMaxSpreadPoints,0);
   }
   else if(g_execQuality.compositeScore < g_adaptiveExecScoreThreshold)
   {
      g_execQuality.executionApproved = false;
      g_execQuality.rejectReason = "Composite score " + DoubleToString(g_execQuality.compositeScore,1) + " below threshold";
   }
   else if(g_newsState == NEWS_SHOCK)
   {
      g_execQuality.executionApproved = false;
      g_execQuality.rejectReason = "News shock proxy active";
   }
}

//=====================================================================
//  ADAPTIVE POSITION SIZING  (Phase 9)
//=====================================================================
// Scales lot size from: base risk % -> equity, modulated by signal
// confidence, regime quality, current drawdown, and strategy health.
// This REPLACES any martingale/recovery-multiplier logic entirely.
// Losses never increase size; only confidence and health can.

double CalculateAdaptiveLotSize(StrategySignal &signal, double slPrice, double &outRiskAmountUsed)
{
   outRiskAmountUsed = 0.0;
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   if(equity <= 0) return 0.0;

   double price = (signal.direction == DIR_LONG) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double slDistance = MathAbs(price - slPrice);
   if(slDistance <= 0) return 0.0;

   // --- Base risk % scaled by confidence (0.5x to 1.0x of base risk range)
   double confidenceFactor = MathMax(0.5, MathMin(1.0, signal.confidence / 100.0));

   // --- Regime quality factor: higher regime confidence/stability -> fuller size
   double regimeFactor = MathMax(0.5, MathMin(1.0, (g_regime.confidence * 0.6 + g_regime.stability * 0.4) / 100.0));

   // --- Strategy health factor: degraded strategies get throttled, never boosted past 1.0
   int hIdx = StrategyHealthIndex(signal.source);
   double healthFactor = (hIdx >= 0) ? g_health[hIdx].influenceMultiplier : 1.0;

   // --- Drawdown factor: as drawdown grows toward the emergency threshold,
   // shrink size smoothly rather than abruptly cutting off at the wall.
   double ddRatio = (InpMaxDrawdownPct > 0) ? (g_risk.currentDrawdownPct / InpMaxDrawdownPct) : 0.0;
   double drawdownFactor = MathMax(0.25, 1.0 - ddRatio); // never fully zero here; hard stop handled by risk engine separately

   double riskPct = InpRiskPercentPerTrade * confidenceFactor * regimeFactor * healthFactor * drawdownFactor;
   riskPct = MathMin(riskPct, InpMaxRiskPercentTrade); // absolute ceiling, no exceptions

   double riskAmount = equity * (riskPct / 100.0);

   double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double tickSize  = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   if(tickValue <= 0 || tickSize <= 0) return 0.0;

   double valuePerPriceUnit = tickValue / tickSize;
   double lot = riskAmount / (slDistance * valuePerPriceUnit);

   double lotMin  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double lotMax  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);

   lot = MathFloor(lot / lotStep) * lotStep; // round down — never round up into more risk
   lot = MathMax(lotMin, MathMin(lotMax, lot));

   // Recompute the ACTUAL risk amount implied by the final, broker-rounded
   // lot size — this is what gets tagged onto the position for accurate
   // R-multiple attribution when the trade closes (not the pre-rounding target).
   outRiskAmountUsed = lot * slDistance * valuePerPriceUnit;

   return lot;
}
//=====================================================================
//  RISK GOVERNANCE ENGINE  (Phase 7)
//=====================================================================
// Hard, non-negotiable limits. No martingale, no grid, no loss-chasing
// recovery multipliers anywhere in this EA. Position sizing only ever
// scales DOWN in response to losses/drawdown (see Adaptive Position
// Sizing) and scales up only with genuine confidence/health signals,
// always bounded by InpMaxRiskPercentTrade regardless of streak.

void InitRiskState()
{
   double eq = AccountInfoDouble(ACCOUNT_EQUITY);
   g_risk.peakEquity       = eq;
   g_risk.dayStartEquity   = eq;
   g_risk.weekStartEquity  = eq;
   g_risk.dailyLimitHit    = false;
   g_risk.weeklyLimitHit   = false;
   g_risk.maxDrawdownBreached = false;
   g_risk.emergencyShutdown  = false;
}

void UpdateRiskState()
{
   double eq = AccountInfoDouble(ACCOUNT_EQUITY);

   if(eq > g_risk.peakEquity) g_risk.peakEquity = eq;
   g_risk.currentDrawdownPct = (g_risk.peakEquity > 0) ? (g_risk.peakEquity - eq) / g_risk.peakEquity * 100.0 : 0.0;
   if(g_risk.currentDrawdownPct > g_risk.maxDrawdownSeenPct) g_risk.maxDrawdownSeenPct = g_risk.currentDrawdownPct;

   g_risk.dailyRiskUsedPct  = (g_risk.dayStartEquity > 0) ? MathMax(0.0, (g_risk.dayStartEquity - eq) / g_risk.dayStartEquity * 100.0) : 0.0;
   g_risk.weeklyRiskUsedPct = (g_risk.weekStartEquity > 0) ? MathMax(0.0, (g_risk.weekStartEquity - eq) / g_risk.weekStartEquity * 100.0) : 0.0;

   g_risk.dailyLimitHit  = (InpMaxDailyLossPct  > 0 && g_risk.dailyRiskUsedPct  >= InpMaxDailyLossPct);
   g_risk.weeklyLimitHit = (InpMaxWeeklyLossPct > 0 && g_risk.weeklyRiskUsedPct >= InpMaxWeeklyLossPct);

   if(InpMaxDrawdownPct > 0 && g_risk.currentDrawdownPct >= InpMaxDrawdownPct)
   {
      g_risk.maxDrawdownBreached = true;
      g_risk.emergencyShutdown   = true; // sticky for the session once breached
   }
}

// Returns true if a NEW trade may be opened right now, false otherwise.
// This is the single gate every new entry must pass — independent of
// signal quality, confidence, or strategy health.
bool RiskGovernanceAllowsNewTrade(string &rejectReason)
{
   if(g_risk.emergencyShutdown)
   {
      rejectReason = "Emergency shutdown active (max drawdown breached this session)";
      return false;
   }
   if(g_risk.dailyLimitHit)
   {
      rejectReason = "Daily loss limit reached";
      return false;
   }
   if(g_risk.weeklyLimitHit)
   {
      rejectReason = "Weekly loss limit reached";
      return false;
   }
   if(InpMaxDailyTrades > 0 && g_tradesToday >= InpMaxDailyTrades)
   {
      rejectReason = "Daily trade count limit reached";
      return false;
   }
   if(PositionsTotalForMagic() >= InpMaxConcurrentTrades)
   {
      rejectReason = "Max concurrent trades reached (mutual exclusion)";
      return false;
   }
   if(g_inCooldown)
   {
      rejectReason = "In post-trade cooldown";
      return false;
   }
   return true;
}

int PositionsTotalForMagic()
{
   int count = 0;
   for(int i = PositionsTotal()-1; i >= 0; i--)
   {
      if(g_pos.SelectByIndex(i) && g_pos.Magic() == InpMagicNumber && g_pos.Symbol() == _Symbol) count++;
   }
   return count;
}

void RolloverDailyWeeklyIfNeeded()
{
   datetime today = DayStart(TimeCurrent());
   datetime thisWeek = WeekStart(TimeCurrent());

   if(today != g_dayStart)
   {
      g_dayStart = today;
      g_tradesToday = 0;
      g_risk.dayStartEquity = AccountInfoDouble(ACCOUNT_EQUITY);
      g_risk.dailyLimitHit = false;
      g_sessionProfit = 0.0;
      g_sessionWins = 0;
      g_sessionLosses = 0;
      // Note: emergency shutdown is intentionally NOT auto-cleared on day
      // rollover — a max-drawdown breach requires manual review/restart,
      // not a silent same-week reset.
   }
   if(thisWeek != g_weekStart)
   {
      g_weekStart = thisWeek;
      g_risk.weekStartEquity = AccountInfoDouble(ACCOUNT_EQUITY);
      g_risk.weeklyLimitHit = false;
   }
}
//=====================================================================
//  STRATEGY HEALTH MONITOR  (Phase 10)
//=====================================================================
void InitStrategyHealth()
{
   string names[5] = {"Trend Scalper", "Mean Reversion", "Volatility Expansion", "Liquidity Reversal", "Compression Breakout"};
   for(int i = 0; i < 5; i++)
   {
      g_health[i].name = names[i];
      g_health[i].totalTrades = 0;
      g_health[i].wins = 0;
      g_health[i].losses = 0;
      g_health[i].grossProfit = 0;
      g_health[i].grossLoss = 0;
      g_health[i].sumR = 0;
      g_health[i].sumRSquared = 0;
      g_health[i].consecLosses = 0;
      g_health[i].maxConsecLosses = 0;
      g_health[i].winRate = 0;
      g_health[i].profitFactor = 0;
      g_health[i].expectancyR = 0;
      g_health[i].sharpeProxy = 0;
      g_health[i].enabled = true;
      g_health[i].influenceMultiplier = 1.0;
      g_health[i].lastDegradedTime = 0;
   }
}

// Call this when a trade attributed to a strategy closes. pnl in account
// currency, rMultiple = realized P&L / initial risk amount for that trade.
void RegisterTradeResult(ENUM_STRATEGY strat, double pnl, double rMultiple)
{
   int idx = StrategyHealthIndex(strat);
   if(idx < 0) return;

   StrategyHealth h = g_health[idx];
   h.totalTrades++;
   if(pnl >= 0) { h.wins++; h.grossProfit += pnl; h.consecLosses = 0; }
   else
   {
      h.losses++;
      h.grossLoss += MathAbs(pnl);
      h.consecLosses++;
      if(h.consecLosses > h.maxConsecLosses) h.maxConsecLosses = h.consecLosses;
   }

   h.sumR        += rMultiple;
   h.sumRSquared += rMultiple * rMultiple;

   h.winRate      = (h.totalTrades > 0) ? (100.0 * h.wins / h.totalTrades) : 0.0;
   h.profitFactor = (h.grossLoss > 0) ? (h.grossProfit / h.grossLoss) : (h.grossProfit > 0 ? 99.0 : 0.0);
   h.expectancyR  = (h.totalTrades > 0) ? (h.sumR / h.totalTrades) : 0.0;

   // Sharpe proxy: mean R / stdev R (population), guarded against div by zero
   if(h.totalTrades > 1)
   {
      double meanR = h.sumR / h.totalTrades;
      double variance = (h.sumRSquared / h.totalTrades) - (meanR * meanR);
      double stdev = (variance > 0) ? MathSqrt(variance) : 0.0;
      h.sharpeProxy = (stdev > 0) ? (meanR / stdev) : 0.0;
   }

   g_health[idx] = h;
   UpdateStrategyInfluence(idx);
}

// Degrades influence multiplier when a strategy shows sustained poor
// performance. Never re-enables itself above 1.0 — recovery back to
// full influence requires sustained subsequent positive expectancy,
// rebuilt gradually, not snapped back.
void UpdateStrategyInfluence(int idx)
{
   if(idx < 0 || idx > 4) return;
   StrategyHealth h = g_health[idx];

   if(h.totalTrades < InpHealthMinTrades)
   {
      g_health[idx].influenceMultiplier = 1.0; // not enough data yet, trade at full size
      return;
   }

   double targetMultiplier = 1.0;

   if(h.consecLosses >= InpHealthDegradeConsecLoss)
      targetMultiplier = MathMin(targetMultiplier, 0.5);

   if(h.expectancyR < InpHealthMinExpectancyR)
      targetMultiplier = MathMin(targetMultiplier, 0.4);

   if(h.profitFactor < 0.8 && h.totalTrades >= InpHealthMinTrades)
      targetMultiplier = MathMin(targetMultiplier, 0.6);

   // Full disable if things are clearly broken
   if(h.consecLosses >= InpHealthDegradeConsecLoss * 2 || h.expectancyR < (InpHealthMinExpectancyR * 2.5))
   {
      g_health[idx].enabled = false;
      targetMultiplier = 0.0;
      g_health[idx].lastDegradedTime = TimeCurrent();
   }

   // Smooth move toward target rather than snapping, to avoid oscillation
   double current = g_health[idx].influenceMultiplier;
   g_health[idx].influenceMultiplier = current + (targetMultiplier - current) * 0.5;

   // Re-enable path: only after multiplier has organically recovered
   // above 0.7 through sustained better trades (handled by the smoothing
   // above + fresh trades pulling expectancy back up).
   if(g_health[idx].influenceMultiplier > 0.7) g_health[idx].enabled = true;
}

//=====================================================================
//  ADAPTIVE PARAMETER ENGINE  (Phase 11) — bounded drift only
//=====================================================================
// Both adaptive thresholds drift within +/- InpAdaptiveBoundPct of their
// base input value, nudged slowly by recent regime/execution outcomes.
// This is NOT machine learning or curve-fitting — it's a narrow governor
// to keep thresholds sane across slowly shifting market conditions
// without ever leaving the bounds the operator configured.

void InitAdaptiveParams()
{
   g_adaptiveRegimeConfThreshold = InpMinRegimeConfidence;
   g_adaptiveExecScoreThreshold  = InpMinExecutionScore;
}

void UpdateAdaptiveParams()
{
   if(!InpEnableAdaptiveParams) return;

   double regimeBoundLow  = InpMinRegimeConfidence * (1.0 - InpAdaptiveBoundPct/100.0);
   double regimeBoundHigh = InpMinRegimeConfidence * (1.0 + InpAdaptiveBoundPct/100.0);
   double execBoundLow    = InpMinExecutionScore   * (1.0 - InpAdaptiveBoundPct/100.0);
   double execBoundHigh   = InpMinExecutionScore   * (1.0 + InpAdaptiveBoundPct/100.0);

   // If recent regime confidence readings are consistently high, we can
   // afford to nudge the floor up slightly (be more selective). If the
   // engine has trouble ever crossing the floor (regime rarely confident),
   // nudge it down slightly so the system isn't perpetually idle.
   double nudge = 0.0;
   if(g_regime.confidence > g_adaptiveRegimeConfThreshold + 15.0) nudge = 0.15;
   else if(g_regime.confidence < g_adaptiveRegimeConfThreshold - 15.0) nudge = -0.15;

   g_adaptiveRegimeConfThreshold = MathMax(regimeBoundLow, MathMin(regimeBoundHigh, g_adaptiveRegimeConfThreshold + nudge));

   double execNudge = 0.0;
   if(g_execQuality.compositeScore > g_adaptiveExecScoreThreshold + 15.0) execNudge = 0.1;
   else if(g_execQuality.compositeScore < g_adaptiveExecScoreThreshold - 15.0) execNudge = -0.1;

   g_adaptiveExecScoreThreshold = MathMax(execBoundLow, MathMin(execBoundHigh, g_adaptiveExecScoreThreshold + execNudge));
}
//=====================================================================
//  TRADE EXECUTION ENGINE  (Phase 1) + POSITION ATTRIBUTION
//=====================================================================
// We persist which strategy + initial risk amount opened the currently
// active position via a comment-embedded tag, since MQL5 has no native
// custom metadata field on positions. Format: "QPA|<StratID>|<RiskAmt>"

string EncodePositionTag(ENUM_STRATEGY strat, double riskAmount)
{
   return InpBotName + "|" + IntegerToString((int)strat) + "|" + DoubleToString(riskAmount, 2);
}

bool DecodePositionTag(string comment, ENUM_STRATEGY &strat, double &riskAmount)
{
   string parts[];
   int n = StringSplit(comment, '|', parts);
   if(n < 3) return false;
   strat = (ENUM_STRATEGY)StringToInteger(parts[1]);
   riskAmount = StringToDouble(parts[2]);
   return true;
}

bool ExecuteMasterDecision(MasterDecision &decision)
{
   if(!decision.tradeApproved || decision.direction == DIR_NONE) return false;

   double price = (decision.direction == DIR_LONG) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(price <= 0) return false;

   // Adjust for broker min stop distance
   int stopsLevel = (int)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   double minDist = stopsLevel * point;

   double sl = decision.slPrice;
   double tp = decision.tpPrice;

   if(decision.direction == DIR_LONG)
   {
      if(sl > 0 && (price - sl) < minDist) sl = NPrice(price - minDist);
      if(tp > 0 && (tp - price) < minDist) tp = NPrice(price + minDist);
   }
   else
   {
      if(sl > 0 && (sl - price) < minDist) sl = NPrice(price + minDist);
      if(tp > 0 && (price - tp) < minDist) tp = NPrice(price - minDist);
   }

   string tag = EncodePositionTag(decision.strategySource, decision.riskAmountUsed);

   g_trade.SetExpertMagicNumber(InpMagicNumber);
   g_trade.SetDeviationInPoints(30);
   g_trade.SetTypeFilling(GetFillMode());

   bool ok = (decision.direction == DIR_LONG)
      ? g_trade.Buy(decision.lotSize, _Symbol, price, sl, tp, tag)
      : g_trade.Sell(decision.lotSize, _Symbol, price, sl, tp, tag);

   if(ok)
   {
      g_tradesToday++;
      g_lastAction = decision.narrative;
   }
   return ok;
}

void CloseAllManagedPositions()
{
   for(int i = PositionsTotal()-1; i >= 0; i--)
   {
      if(!g_pos.SelectByIndex(i)) continue;
      if(g_pos.Magic() != InpMagicNumber || g_pos.Symbol() != _Symbol) continue;
      g_trade.PositionClose(g_pos.Ticket());
   }
}

double GetFloatingPL()
{
   double t = 0;
   for(int i = PositionsTotal()-1; i >= 0; i--)
   {
      if(g_pos.SelectByIndex(i) && g_pos.Magic() == InpMagicNumber && g_pos.Symbol() == _Symbol)
         t += g_pos.Profit() + g_pos.Swap() + g_pos.Commission();
   }
   return t;
}

bool HasManagedPosition()
{
   return PositionsTotalForMagic() > 0;
}

//=====================================================================
//  TRADE TRANSACTION HANDLER — attributes closed deals back to the
//  strategy that opened them, feeding the Strategy Health Monitor.
//=====================================================================
void OnTradeTransactionHandler(const MqlTradeTransaction &trans,
                                const MqlTradeRequest &request,
                                const MqlTradeResult &result)
{
   if(trans.type != TRADE_TRANSACTION_DEAL_ADD) return;

   ulong dealTicket = trans.deal;
   if(!HistoryDealSelect(dealTicket)) return;

   if((ulong)HistoryDealGetInteger(dealTicket, DEAL_MAGIC) != InpMagicNumber) return;
   if(HistoryDealGetString(dealTicket, DEAL_SYMBOL) != _Symbol) return;
   if(HistoryDealGetInteger(dealTicket, DEAL_ENTRY) != DEAL_ENTRY_OUT) return; // only closing deals

   double pnl = HistoryDealGetDouble(dealTicket, DEAL_PROFIT)
              + HistoryDealGetDouble(dealTicket, DEAL_SWAP)
              + HistoryDealGetDouble(dealTicket, DEAL_COMMISSION);

   string comment = HistoryDealGetString(dealTicket, DEAL_COMMENT);

   ENUM_STRATEGY strat = STRAT_NONE;
   double riskAmount = 0;
   if(!DecodePositionTag(comment, strat, riskAmount))
   {
      // Position comment may have been altered by broker; fall back gracefully
      return;
   }

   double rMultiple = (riskAmount > 0) ? (pnl / riskAmount) : 0.0;
   RegisterTradeResult(strat, pnl, rMultiple);

   g_sessionProfit += pnl;
   if(pnl >= 0) g_sessionWins++; else g_sessionLosses++;

   g_lastCloseTime = TimeCurrent();
   g_inCooldown    = true;
   g_cooldownLeft  = InpCooldownAfterCloseSec;

   LogTradeResult(strat, pnl, rMultiple);
}

//=====================================================================
//  PERFORMANCE ANALYTICS ENGINE  (Phase 15)
//=====================================================================
void LogTradeResult(ENUM_STRATEGY strat, double pnl, double rMultiple)
{
   string line = StringFormat("[QPA] %s | Strategy=%s | PnL=%.2f | R=%.2f | Regime=%s | Session=%d",
                  TimeToString(TimeCurrent(), TIME_DATE|TIME_SECONDS),
                  StrategyToString(strat), pnl, rMultiple,
                  RegimeToString(g_regime.regime), (int)g_session.current);
   Print(line);
}

double TradeQualityScore()
{
   // Composite score blending execution quality at entry conditions now
   // (proxy) with regime confidence — used for dashboard/logging context,
   // not for gating (gating is handled explicitly by the engines above).
   return MathMin(100.0, g_execQuality.compositeScore * 0.5 + g_regime.confidence * 0.5);
}
//=====================================================================
//  MASTER DECISION ENGINE  (Phase 1 capstone)
//=====================================================================
// Single point of truth that consumes every engine's output and either
// approves or rejects a new trade. Order of operations matters: safety
// gates (risk governance, execution quality) run BEFORE strategy
// signal generation is even allowed to result in an order.

MasterDecision BuildMasterDecision()
{
   MasterDecision d;
   d.tradeApproved = false;
   d.direction = DIR_NONE;
   d.lotSize = 0;
   d.slPrice = 0;
   d.tpPrice = 0;
   d.strategySource = STRAT_NONE;
   d.riskAmountUsed = 0;
   d.narrative = "";

   // --- Gate 1: Risk governance (hard limits, emergency shutdown, cooldown)
   string rejectReason = "";
   if(!RiskGovernanceAllowsNewTrade(rejectReason))
   {
      d.narrative = "Blocked by Risk Governance: " + rejectReason;
      return d;
   }

   // --- Gate 2: Regime must be classified with sufficient confidence
   if(g_regime.regime == REGIME_UNSAFE)
   {
      d.narrative = "Regime UNSAFE — standing aside";
      return d;
   }
   if(g_regime.confidence < g_adaptiveRegimeConfThreshold)
   {
      d.narrative = "Regime confidence " + DoubleToString(g_regime.confidence,1) + " below adaptive floor " + DoubleToString(g_adaptiveRegimeConfThreshold,1);
      return d;
   }

   // --- Gate 3: Execution quality
   if(!g_execQuality.executionApproved)
   {
      d.narrative = "Blocked by Execution Quality: " + g_execQuality.rejectReason;
      return d;
   }

   // --- Route to strategy (mutual exclusion enforced here — only one
   // strategy is ever consulted for an actionable signal per tick)
   ENUM_STRATEGY routedStrat = RouteRegimeToStrategy(g_regime.regime);
   if(routedStrat == STRAT_NONE)
   {
      d.narrative = "Regime " + RegimeToString(g_regime.regime) + " has no routed strategy — standing aside";
      return d;
   }

   // --- Strategy health gate: disabled strategies cannot trade regardless of signal
   int hIdx = StrategyHealthIndex(routedStrat);
   if(hIdx >= 0 && !g_health[hIdx].enabled)
   {
      d.narrative = "Strategy " + StrategyToString(routedStrat) + " disabled by Health Monitor";
      return d;
   }

   StrategySignal signal = GetSignalForStrategy(routedStrat);
   if(!signal.valid)
   {
      d.narrative = "No valid signal from " + StrategyToString(routedStrat) + ": " + signal.reason;
      return d;
   }

   // --- Session weighting applied to signal confidence (Phase 5 integration)
   double sessionAdjustedConfidence = signal.confidence;
   if(g_session.preferredStrategy == routedStrat)
      sessionAdjustedConfidence = MathMin(100.0, signal.confidence * g_session.strategyWeight);
   else
      sessionAdjustedConfidence = signal.confidence * 0.85; // mild discount when off-session-preference

   if(sessionAdjustedConfidence < g_adaptiveRegimeConfThreshold)
   {
      d.narrative = "Session-adjusted confidence too low for " + StrategyToString(routedStrat);
      return d;
   }
   signal.confidence = sessionAdjustedConfidence;

   // --- Adaptive position sizing (no martingale — confidence/health/drawdown based)
   double riskAmountUsed = 0.0;
   double lot = CalculateAdaptiveLotSize(signal, signal.suggestedSL, riskAmountUsed);
   if(lot <= 0)
   {
      d.narrative = "Calculated lot size invalid (zero or below broker minimum)";
      return d;
   }

   d.tradeApproved   = true;
   d.direction       = signal.direction;
   d.lotSize         = lot;
   d.slPrice         = signal.suggestedSL;
   d.tpPrice         = signal.suggestedTP;
   d.strategySource  = routedStrat;
   d.riskAmountUsed  = riskAmountUsed;
   d.narrative       = StrategyToString(routedStrat) + " | " + signal.reason + " | Lot=" + DoubleToString(lot,2);

   return d;
}

void RunMasterDecisionCycle()
{
   if(HasManagedPosition())
   {
      g_statusText = "IN TRADE";
      g_statusColor = C_GREEN;
      return;
   }

   if(g_inCooldown)
   {
      g_statusText = "COOLDOWN";
      g_statusColor = C_CYAN;
      return;
   }

   MasterDecision decision = BuildMasterDecision();
   g_lastDecision = decision;

   if(decision.tradeApproved)
   {
      g_statusText = "EXECUTING";
      g_statusColor = C_LBLUE;
      bool ok = ExecuteMasterDecision(decision);
      if(ok)
      {
         g_statusText = "IN TRADE";
         g_statusColor = C_GREEN;
      }
      else
      {
         g_statusText = "ORDER FAIL";
         g_statusColor = C_RED;
      }
   }
   else
   {
      g_statusText = "ANALYZING";
      g_statusColor = C_GOLD;
      g_lastAction = decision.narrative;
   }
}

//=====================================================================
//  EA LIFECYCLE
//=====================================================================
int OnInit()
{
   if(_Symbol != "XAUUSD" && StringFind(_Symbol, "XAU") < 0)
      Print("Note: Quantum Plus AI is tuned for Gold (XAUUSD) microstructure; other symbols may need parameter review.");

   g_trade.SetExpertMagicNumber(InpMagicNumber);
   g_trade.SetDeviationInPoints(30);
   g_trade.SetTypeFilling(GetFillMode());

   // --- Indicator handles: H1
   g_h1_ema_fast = iMA(_Symbol, PERIOD_H1, InpEMAFastPeriod, 0, MODE_EMA, PRICE_CLOSE);
   g_h1_ema_slow = iMA(_Symbol, PERIOD_H1, InpEMASlowPeriod, 0, MODE_EMA, PRICE_CLOSE);
   g_h1_atr      = iATR(_Symbol, PERIOD_H1, InpATRPeriod);

   // --- M15
   g_m15_ema_fast = iMA(_Symbol, PERIOD_M15, InpEMAFastPeriod, 0, MODE_EMA, PRICE_CLOSE);
   g_m15_ema_slow = iMA(_Symbol, PERIOD_M15, InpEMASlowPeriod, 0, MODE_EMA, PRICE_CLOSE);
   g_m15_atr      = iATR(_Symbol, PERIOD_M15, InpATRPeriod);
   g_m15_rsi      = iRSI(_Symbol, PERIOD_M15, 14, PRICE_CLOSE);

   // --- M5 (primary working timeframe)
   g_m5_ema_fast = iMA(_Symbol, PERIOD_M5, InpEMAFastPeriod, 0, MODE_EMA, PRICE_CLOSE);
   g_m5_ema_slow = iMA(_Symbol, PERIOD_M5, InpEMASlowPeriod, 0, MODE_EMA, PRICE_CLOSE);
   g_m5_atr      = iATR(_Symbol, PERIOD_M5, InpATRPeriod);
   g_m5_rsi      = iRSI(_Symbol, PERIOD_M5, 14, PRICE_CLOSE);

   // --- M1
   g_m1_ema_fast = iMA(_Symbol, PERIOD_M1, InpEMAFastPeriod, 0, MODE_EMA, PRICE_CLOSE);
   g_m1_ema_slow = iMA(_Symbol, PERIOD_M1, InpEMASlowPeriod, 0, MODE_EMA, PRICE_CLOSE);
   g_m1_atr      = iATR(_Symbol, PERIOD_M1, InpATRPeriod);

   if(g_h1_ema_fast == INVALID_HANDLE || g_h1_ema_slow == INVALID_HANDLE || g_h1_atr == INVALID_HANDLE ||
      g_m15_ema_fast == INVALID_HANDLE || g_m15_ema_slow == INVALID_HANDLE || g_m15_atr == INVALID_HANDLE || g_m15_rsi == INVALID_HANDLE ||
      g_m5_ema_fast == INVALID_HANDLE || g_m5_ema_slow == INVALID_HANDLE || g_m5_atr == INVALID_HANDLE || g_m5_rsi == INVALID_HANDLE ||
      g_m1_ema_fast == INVALID_HANDLE || g_m1_ema_slow == INVALID_HANDLE || g_m1_atr == INVALID_HANDLE)
   {
      Print("ERROR: Failed to create one or more indicator handles.");
      return INIT_FAILED;
   }

   g_dayStart  = DayStart(TimeCurrent());
   g_weekStart = WeekStart(TimeCurrent());

   InitRiskState();
   InitStrategyHealth();
   InitAdaptiveParams();

   g_regime.regime = REGIME_RANGING;
   g_regime.confidence = 0;
   g_regime.stability = 0;
   g_regime.sinceTime = TimeCurrent();
   g_regime.previousRegime = REGIME_RANGING;

   if(InpShowDash) InitDash();
   EventSetTimer(1);

   g_statusText = "WARMING UP";
   g_statusColor = C_ORANGE;
   g_lastAction = "Building multi-timeframe buffers...";

   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
   EventKillTimer();
   DeleteDash();

   IndicatorRelease(g_h1_ema_fast);  IndicatorRelease(g_h1_ema_slow);  IndicatorRelease(g_h1_atr);
   IndicatorRelease(g_m15_ema_fast); IndicatorRelease(g_m15_ema_slow); IndicatorRelease(g_m15_atr); IndicatorRelease(g_m15_rsi);
   IndicatorRelease(g_m5_ema_fast);  IndicatorRelease(g_m5_ema_slow);  IndicatorRelease(g_m5_atr);  IndicatorRelease(g_m5_rsi);
   IndicatorRelease(g_m1_ema_fast);  IndicatorRelease(g_m1_ema_slow);  IndicatorRelease(g_m1_atr);
}

void OnTimer()
{
   if(g_lastCloseTime > 0)
   {
      int elapsed = (int)(TimeCurrent() - g_lastCloseTime);
      g_inCooldown   = (elapsed < InpCooldownAfterCloseSec);
      g_cooldownLeft = g_inCooldown ? (InpCooldownAfterCloseSec - elapsed) : 0;
   }

   if(InpShowDash) UpdateDash();
}

void OnTick()
{
   RolloverDailyWeeklyIfNeeded();

   // Require minimum bars across all timeframes before doing anything
   if(Bars(_Symbol, PERIOD_H1) < InpEMASlowPeriod + 5 ||
      Bars(_Symbol, PERIOD_M15) < InpEMASlowPeriod + 5 ||
      Bars(_Symbol, PERIOD_M5) < InpATRLookback + 5 ||
      Bars(_Symbol, PERIOD_M1) < InpEMASlowPeriod + 5)
   {
      g_statusText = "BUFFERING";
      g_statusColor = C_ORANGE;
      return;
   }

   // --- Update all intelligence engines, in dependency order
   UpdateMTFBias();
   UpdateVolatilityIntelligence();   // must run before liquidity (uses atrAvg) and news proxy
   UpdateNewsShockProxy();
   UpdateLiquidityIntelligence();
   UpdateSessionIntelligence();
   UpdateRegimeClassification();     // depends on vol, mtf, liquidity, news
   UpdateExecutionQuality();         // depends on vol, session, news
   UpdateRiskState();
   UpdateAdaptiveParams();

   // --- Manage any open position first (no new entries while one is open;
   // mutual exclusion + InpMaxConcurrentTrades enforce this structurally)
   if(HasManagedPosition())
   {
      g_statusText = "IN TRADE";
      g_statusColor = C_GREEN;
      return;
   }

   RunMasterDecisionCycle();
}

void OnTradeTransaction(const MqlTradeTransaction &trans,
                         const MqlTradeRequest &request,
                         const MqlTradeResult &result)
{
   OnTradeTransactionHandler(trans, request, result);
}
//=====================================================================
//  INSTITUTIONAL DASHBOARD  (Phase 14)
//=====================================================================
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
   ObjectSetString (0, n, OBJPROP_TEXT, txt);
   ObjectSetInteger(0, n, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, n, OBJPROP_FONTSIZE, fsz);
   ObjectSetString (0, n, OBJPROP_FONT, fnt);
   ObjectSetInteger(0, n, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, n, OBJPROP_HIDDEN, true);
}

void U(string nm, string txt, color clr=C'222,228,242')
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
   int fw = (int)MathMax(2, MathRound(MathMax(0.0, MathMin(100.0, pct)) / 100.0 * (w - 2)));
   if(ObjectFind(0, n) >= 0)
   {
      ObjectSetInteger(0, n, OBJPROP_XSIZE, fw);
      ObjectSetInteger(0, n, OBJPROP_BGCOLOR, fg);
   }
}

string SessionToString(ENUM_SESSION s)
{
   switch(s)
   {
      case SESSION_ASIAN:       return "ASIAN";
      case SESSION_LONDON_OPEN: return "LONDON OPEN";
      case SESSION_LONDON_MID:  return "LONDON MID";
      case SESSION_NY_OPEN:     return "NY OPEN";
      case SESSION_NY_PM:       return "NY PM";
      default:                  return "DEAD ZONE";
   }
}

string VolStateToString(ENUM_VOL_STATE v)
{
   switch(v)
   {
      case VOL_LOW:     return "LOW";
      case VOL_NORMAL:  return "NORMAL";
      case VOL_HIGH:    return "HIGH";
      default:          return "EXTREME";
   }
}

string NewsStateToString(ENUM_NEWS_STATE n)
{
   switch(n)
   {
      case NEWS_NORMAL:  return "NORMAL";
      case NEWS_CAUTION: return "CAUTION";
      default:           return "SHOCK";
   }
}

void InitDash()
{
   int X = InpDashX, Y = InpDashY;

   R("frame_outer", X,   Y,   DW,   DH,   C_BG0, C_ACBORD, 2);
   R("frame_inner", X+2, Y+2, DW-4, DH-4, C_BG0, C_BORDER, 1);

   // Header
   R("hdr_bg",  X+2,  Y+2,  DW-4, 78, C_HDRBAR, C_BORDER, 1);
   R("hdr_acc", X+2,  Y+2,  DW-4,  3, C_ACBORD);
   L("h_name",  X+10, Y+10, InpBotName, C_GOLD, 13, "Arial Black");
   L("h_tag",   X+10, Y+31, "Institutional Multi-Regime Adaptive Engine", C_CYAN, 7, "Arial");
   L("h_ver",   X+10, Y+45, "v1.0  |  Magic: " + IntegerToString((long)InpMagicNumber) + "  |  " + _Symbol, C_LBLUE, 7, "Arial");
   R("live_bg", X+DW-80, Y+8, 64, 22, C_DKGREEN, C_GREEN, 1);
   L("live_lbl",X+DW-72, Y+12, "● LIVE", C_GREEN, 7, "Arial Bold");
   R("div_hdr", X+2, Y+80, DW-4, 2, C_ACBORD);

   // Status row
   R("stat_bg", X+2, Y+84, DW-4, 28, C_BG2, C_BORDER, 1);
   L("lb_stat", X+14, Y+91, "STATUS", C_SUBTEXT, 8, "Arial");
   L("vl_stat", X+95, Y+91, "WARMING UP", C_ORANGE, 9, "Arial Black");
   L("lb_act",  X+250,Y+91, "Action:", C_SUBTEXT, 7, "Arial");
   R("div_stat",X+2, Y+114, DW-4, 1, C_BORDER);
   L("vl_act",  X+14, Y+118, "--", C_SUBTEXT, 7, "Arial");

   // Section A: Regime & Market State
   int yA = Y + 134;
   R("sec_a",    X+2, yA, DW-4, 140, C_BG1, C_BORDER, 1);
   R("sec_a_hd", X+2, yA, DW-4, 22, C_HDRBAR, C_BORDER, 1);
   L("sec_a_lb", X+10, yA+4, "▸  MARKET REGIME & STATE", C_GOLD, 8, "Arial Black");

   L("lb_reg",  X+14, yA+30, "Regime", C_SUBTEXT, 8, "Arial");
   L("vl_reg",  X+200,yA+30, "RANGING", C_CYAN, 9, "Arial Bold");
   L("lb_regc", X+14, yA+46, "Confidence / Stability", C_SUBTEXT, 8, "Arial");
   L("vl_regc", X+200,yA+46, "0% / 0%", C_WHITE, 9, "Arial Bold");

   L("lb_vol",  X+14, yA+62, "Volatility State", C_SUBTEXT, 8, "Arial");
   L("vl_vol",  X+200,yA+62, "NORMAL", C_WHITE, 9, "Arial Bold");
   L("lb_liq",  X+14, yA+78, "Liquidity Bias / Pressure", C_SUBTEXT, 8, "Arial");
   L("vl_liq",  X+200,yA+78, "0 / 0", C_WHITE, 9, "Arial Bold");

   L("lb_sess", X+14, yA+94, "Session", C_SUBTEXT, 8, "Arial");
   L("vl_sess", X+200,yA+94, "ASIAN", C_WHITE, 9, "Arial Bold");
   L("lb_news", X+14, yA+110, "News Shock Proxy", C_SUBTEXT, 8, "Arial");
   L("vl_news", X+200,yA+110, "NORMAL", C_GREEN, 9, "Arial Bold");

   // Section B: Strategy & Signal
   int yB = yA + 150;
   R("sec_b",    X+2, yB, DW-4, 90, C_BG1, C_BORDER, 1);
   R("sec_b_hd", X+2, yB, DW-4, 22, C_HDRBAR, C_BORDER, 1);
   L("sec_b_lb", X+10, yB+4, "▸  STRATEGY ROUTER", C_GOLD, 8, "Arial Black");

   L("lb_strat", X+14, yB+30, "Routed Strategy", C_SUBTEXT, 8, "Arial");
   L("vl_strat", X+200,yB+30, "NONE", C_WHITE, 9, "Arial Bold");
   L("lb_sigq",  X+14, yB+46, "Signal Quality", C_SUBTEXT, 8, "Arial");
   L("vl_sigq",  X+200,yB+46, "0 %", C_CYAN, 9, "Arial Bold");
   Bar("sigq_bar", X+280, yB+48, 130, 12, 0, C_CYAN, C_DGRAY);
   L("lb_exec",  X+14, yB+62, "Execution Quality", C_SUBTEXT, 8, "Arial");
   L("vl_exec",  X+200,yB+62, "0 %", C_PURPLE, 9, "Arial Bold");
   Bar("exec_bar", X+280, yB+64, 130, 12, 0, C_PURPLE, C_DGRAY);

   // Section C: Risk State
   int yC = yB + 100;
   R("sec_c",    X+2, yC, DW-4, 116, C_BG1, C_BORDER, 1);
   R("sec_c_hd", X+2, yC, DW-4, 22, C_HDRBAR, C_BORDER, 1);
   L("sec_c_lb", X+10, yC+4, "▸  RISK GOVERNANCE", C_GOLD, 8, "Arial Black");

   L("lb_dd",  X+14, yC+30, "Drawdown (Current / Max)", C_SUBTEXT, 8, "Arial");
   L("vl_dd",  X+200,yC+30, "0.00% / 0.00%", C_WHITE, 9, "Arial Bold");
   Bar("dd_bar", X+280, yC+18, 130, 12, 0, C_RED, C_DGRAY);

   L("lb_drisk", X+14, yC+46, "Daily / Weekly Risk Used", C_SUBTEXT, 8, "Arial");
   L("vl_drisk", X+200,yC+46, "0.00% / 0.00%", C_WHITE, 9, "Arial Bold");

   L("lb_tt",   X+14, yC+62, "Trades Today", C_SUBTEXT, 8, "Arial");
   L("vl_tt",   X+200,yC+62, "0 / " + IntegerToString(InpMaxDailyTrades), C_WHITE, 9, "Arial Bold");

   L("lb_shutdown", X+14, yC+78, "Emergency Status", C_SUBTEXT, 8, "Arial");
   L("vl_shutdown", X+200,yC+78, "NORMAL", C_GREEN, 9, "Arial Bold");

   L("lb_floatpl", X+14, yC+94, "Floating P&L", C_SUBTEXT, 8, "Arial");
   L("vl_floatpl", X+200,yC+94, "$ 0.00", C_WHITE, 9, "Arial Bold");

   // Section D: Strategy Health (compact table)
   int yD = yC + 126;
   R("sec_d",    X+2, yD, DW-4, 96, C_BG1, C_BORDER, 1);
   R("sec_d_hd", X+2, yD, DW-4, 22, C_HDRBAR, C_BORDER, 1);
   L("sec_d_lb", X+10, yD+4, "▸  STRATEGY HEALTH", C_GOLD, 8, "Arial Black");

   string shortNames[5] = {"Trend", "MeanRev", "VolExp", "LiqRev", "Compr"};
   for(int i = 0; i < 5; i++)
   {
      int rowY = yD + 28 + i*13;
      L("hl_name_"+IntegerToString(i), X+14, rowY, shortNames[i], C_SUBTEXT, 7, "Arial");
      L("hl_stat_"+IntegerToString(i), X+90, rowY, "WR -- | PF -- | E[R] -- | ON", C_WHITE, 7, "Arial");
   }

   // Section E: Performance summary
   int yE = yD + 106;
   R("sec_e", X+2, yE, DW-4, 56, C_BG2, C_BORDER, 1);
   L("cfg1", X+14, yE+5, "Session Profit: $0.00  |  Wins: 0  Losses: 0", C_LBLUE, 7, "Arial");
   L("cfg2", X+14, yE+19, "Base Risk: " + DoubleToString(InpRiskPercentPerTrade,2) + "%  |  Max Risk: " + DoubleToString(InpMaxRiskPercentTrade,2) + "%  |  Max DD: " + DoubleToString(InpMaxDrawdownPct,1) + "%", C_LBLUE, 7, "Arial");
   L("cfg3", X+14, yE+33, "Adaptive Regime Floor: --  |  Adaptive Exec Floor: --", C_LBLUE, 7, "Arial");

   R("ftr", X+2, Y+DH-19, DW-4, 15, C_HDRBAR, C_BORDER, 1);
   L("ft_time", X+10, Y+DH-17, "Server: --:--", C_MGRAY, 7, "Arial");

   ChartRedraw(0);
}

void UpdateDash()
{
   if(!InpShowDash) return;

   U("vl_stat", g_statusText, g_statusColor);
   U("vl_act",  g_lastAction, C_SUBTEXT);

   U("vl_reg", RegimeToString(g_regime.regime), (g_regime.regime == REGIME_UNSAFE) ? C_RED : C_CYAN);
   U("vl_regc", DoubleToString(g_regime.confidence,0) + "% / " + DoubleToString(g_regime.stability,0) + "%", C_WHITE);

   color volColor = C_GREEN;
   if(g_vol.state == VOL_HIGH) volColor = C_ORANGE;
   if(g_vol.state == VOL_EXTREME) volColor = C_RED;
   U("vl_vol", VolStateToString(g_vol.state), volColor);

   U("vl_liq", DoubleToString(g_liq.biasScore,0) + " / " + DoubleToString(g_liq.pressureScore,0), C_WHITE);
   U("vl_sess", SessionToString(g_session.current), C_WHITE);

   color newsColor = C_GREEN;
   if(g_newsState == NEWS_CAUTION) newsColor = C_ORANGE;
   if(g_newsState == NEWS_SHOCK)   newsColor = C_RED;
   U("vl_news", NewsStateToString(g_newsState), newsColor);

   ENUM_STRATEGY routed = RouteRegimeToStrategy(g_regime.regime);
   U("vl_strat", StrategyToString(routed), (routed == STRAT_NONE) ? C_MGRAY : C_WHITE);

   double sigQ = (g_lastDecision.tradeApproved) ? 100.0 : 0.0; // simplistic visual proxy; narrative carries detail
   U("vl_sigq", DoubleToString(TradeQualityScore(),0) + " %", C_CYAN);
   UpdBar("sigq_bar", TradeQualityScore(), C_CYAN);

   U("vl_exec", DoubleToString(g_execQuality.compositeScore,0) + " %", g_execQuality.executionApproved ? C_GREEN : C_RED);
   UpdBar("exec_bar", g_execQuality.compositeScore, g_execQuality.executionApproved ? C_PURPLE : C_RED);

   U("vl_dd", DoubleToString(g_risk.currentDrawdownPct,2) + "% / " + DoubleToString(g_risk.maxDrawdownSeenPct,2) + "%", (g_risk.currentDrawdownPct < InpMaxDrawdownPct*0.5) ? C_GREEN : C_RED);
   UpdBar("dd_bar", MathMin(100.0, (g_risk.currentDrawdownPct / MathMax(0.01,InpMaxDrawdownPct)) * 100.0), C_RED);

   U("vl_drisk", DoubleToString(g_risk.dailyRiskUsedPct,2) + "% / " + DoubleToString(g_risk.weeklyRiskUsedPct,2) + "%", C_WHITE);
   U("vl_tt", IntegerToString(g_tradesToday) + " / " + IntegerToString(InpMaxDailyTrades), C_WHITE);

   U("vl_shutdown", g_risk.emergencyShutdown ? "SHUTDOWN" : (g_risk.dailyLimitHit || g_risk.weeklyLimitHit ? "LIMIT HIT" : "NORMAL"),
                     g_risk.emergencyShutdown ? C_RED : (g_risk.dailyLimitHit || g_risk.weeklyLimitHit ? C_ORANGE : C_GREEN));

   double floatPL = GetFloatingPL();
   U("vl_floatpl", "$ " + DoubleToString(floatPL,2), (floatPL >= 0) ? C_GREEN : C_RED);

   for(int i = 0; i < 5; i++)
   {
      StrategyHealth h = g_health[i];
      string line = "WR " + DoubleToString(h.winRate,0) + "% | PF " + DoubleToString(h.profitFactor,2) +
                    " | E[R] " + DoubleToString(h.expectancyR,2) + " | " + (h.enabled ? "ON" : "OFF");
      color rowColor = h.enabled ? C_WHITE : C_RED;
      if(h.enabled && h.influenceMultiplier < 0.8) rowColor = C_ORANGE;
      U("hl_stat_"+IntegerToString(i), line, rowColor);
   }

   U("cfg1", "Session Profit: $" + DoubleToString(g_sessionProfit,2) + "  |  Wins: " + IntegerToString(g_sessionWins) + "  Losses: " + IntegerToString(g_sessionLosses),
      (g_sessionProfit >= 0) ? C_LBLUE : C_RED);
   U("cfg3", "Adaptive Regime Floor: " + DoubleToString(g_adaptiveRegimeConfThreshold,1) + "  |  Adaptive Exec Floor: " + DoubleToString(g_adaptiveExecScoreThreshold,1), C_LBLUE);

   U("ft_time", "Server: " + TimeToString(TimeCurrent(), TIME_SECONDS) + "  |  Local: " + TimeToString(TimeLocal(), TIME_MINUTES), C_DGRAY);

   ChartRedraw(0);
}

void DeleteDash()
{
   ObjectsDeleteAll(0, D);
   ChartRedraw(0);
}
