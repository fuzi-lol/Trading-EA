//+------------------------------------------------------------------+
//|                                          QUANTUM PLUS AI v1.0     |
//|        Institutional-Grade Adaptive Multi-Regime Trading System  |
//|        Architecture: Regime-Routed Strategy Selection            |
//|        Built for XAUUSD | M1/M5/M15/H1 Hierarchical Decisioning  |
//+------------------------------------------------------------------+
#property copyright   "Quantum Plus AI v1.0"
#property version     "1.00"
#property description "Institutional multi-regime adaptive EA"
#property strict

#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>
#include <Trade\AccountInfo.mqh>
#include <Trade\OrderInfo.mqh>

#define D    "QPA_DASH_"
#define OV   "QPA_OV_"
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

enum ENUM_VOL_STATE
{
   VOL_LOW,
   VOL_NORMAL,
   VOL_HIGH,
   VOL_EXTREME
};

enum ENUM_VOL_DYNAMIC
{
   VOLDYN_EXPANDING,
   VOLDYN_COMPRESSING,
   VOLDYN_STABLE,
   VOLDYN_SPIKE
};

enum ENUM_SESSION
{
   SESSION_ASIAN,
   SESSION_LONDON_OPEN,
   SESSION_LONDON_MID,
   SESSION_NY_OPEN,
   SESSION_NY_PM,
   SESSION_DEAD_ZONE
};

enum ENUM_NEWS_STATE
{
   NEWS_NORMAL,
   NEWS_CAUTION,
   NEWS_SHOCK
};

enum ENUM_STRATEGY
{
   STRAT_NONE,
   STRAT_TREND_SCALPER,
   STRAT_MEAN_REVERSION,
   STRAT_VOLATILITY_EXPANSION,
   STRAT_LIQUIDITY_REVERSAL,
   STRAT_COMPRESSION_BREAKOUT
};

enum ENUM_DIRECTION
{
   DIR_NONE,
   DIR_LONG,
   DIR_SHORT
};

//=====================================================================
//  CORE DATA STRUCTURES
//=====================================================================
struct RegimeState
{
   ENUM_REGIME    regime;
   double         confidence;
   double         stability;
   datetime       sinceTime;
   ENUM_REGIME    previousRegime;
};

struct VolatilityState
{
   ENUM_VOL_STATE   state;
   ENUM_VOL_DYNAMIC dynamic;
   double           atrCurrent;
   double           atrAvg;
   double           atrRatio;
   double           percentile;
};

struct LiquidityState
{
   double   biasScore;
   double   pressureScore;
   double   sweepProbability;
   double   imbalanceScore;
   bool     equalHighsDetected;
   bool     equalLowsDetected;
   double   equalHighLevel;
   double   equalLowLevel;
   bool     sweepUpDetected;
   bool     sweepDownDetected;
};

struct SessionState
{
   ENUM_SESSION   current;
   double         sessionRangeATRRatio;
   double         sessionVolatilityScore;
   ENUM_STRATEGY  preferredStrategy;
   double         strategyWeight;
};

struct MTFBias
{
   int      h1Bias;
   int      m15Bias;
   int      m5Bias;
   int      m1Bias;
   double   alignment;
};

struct StrategySignal
{
   ENUM_STRATEGY   source;
   ENUM_DIRECTION  direction;
   double          confidence;
   double          suggestedSL;
   double          suggestedTP;
   string          reason;
   bool            valid;
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
   double   peakEquityContribution;
   double   currentDrawdownContribution;
   double   winRate;
   double   profitFactor;
   double   expectancyR;
   double   sharpeProxy;
   bool     enabled;
   double   influenceMultiplier;
   datetime lastDegradedTime;
};

struct ExecutionQuality
{
   double   spreadScore;
   double   slippageRiskScore;
   double   volatilityQuality;
   double   liquidityQuality;
   double   efficiencyScore;
   double   compositeScore;
   bool     executionApproved;
   string   rejectReason;
};

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

struct MasterDecision
{
   bool             tradeApproved;
   ENUM_DIRECTION   direction;
   double           lotSize;
   double           slPrice;
   double           tpPrice;
   ENUM_STRATEGY    strategySource;
   double           riskAmountUsed;
   string           narrative;
};

//=====================================================================
//  INPUT PARAMETERS
//=====================================================================
input group "=====  IDENTITY  ====="
input ulong    InpMagicNumber          = 778800;
input string   InpBotName              = "QUANTUM PLUS AI";

input group "=====  RISK GOVERNANCE  ====="
input double   InpRiskPercentPerTrade  = 0.5;
input double   InpMaxRiskPercentTrade  = 1.0;
input double   InpMaxDailyLossPct      = 3.0;
input double   InpMaxWeeklyLossPct     = 7.0;
input double   InpMaxDrawdownPct       = 12.0;
input int      InpMaxDailyTrades       = 8;
input int      InpMaxConcurrentTrades  = 1;
input int      InpServerTimezoneOffsetHrs = 0;

input group "=====  EXECUTION QUALITY  ====="
input double   InpMaxSpreadPoints      = 350;
input double   InpMinExecutionScore    = 60.0;
input int      InpCooldownAfterCloseSec= 30;

input group "=====  REGIME DETECTION  ====="
input int      InpATRPeriod            = 14;
input int      InpATRLookback          = 100;
input int      InpEMAFastPeriod        = 8;
input int      InpEMASlowPeriod        = 34;
input int      InpStructureLookback    = 20;
input double   InpMinRegimeConfidence  = 55.0;

input group "=====  LIQUIDITY ENGINE  ====="
input double   InpEqualLevelTolerance  = 0.15;
input int      InpLiquidityLookback    = 40;

input group "=====  NEWS SHOCK PROXY  ====="
input double   InpShockATRMultiple     = 2.5;
input double   InpShockSpreadMultiple  = 2.0;

input group "=====  STRATEGY HEALTH  ====="
input int      InpHealthMinTrades            = 8;
input int      InpHealthDegradeConsecLoss    = 4;
input double   InpHealthMinExpectancyR       = -0.10;

input group "=====  ADAPTIVE PARAMETERS  ====="
input bool     InpEnableAdaptiveParams = true;
input double   InpAdaptiveBoundPct     = 20.0;

input group "=====  DASHBOARD  ====="
input bool     InpShowDash             = true;
input int      InpDashX                = 8;
input int      InpDashY                = 8;

input group "=====  CHART THEME ENGINE  ====="
input bool     InpApplyChartTheme      = true;
input bool     InpSaveChartTemplate    = true;
input bool     InpLoadChartTemplate    = true;
input string   InpTemplateName         = "QuantumPlusAI_Theme";

input group "=====  VISUAL INTELLIGENCE OVERLAYS  ====="
input bool     InpDrawSessionBoxes     = true;
input bool     InpDrawLiquidityZones   = true;
input bool     InpDrawSignalMarkers    = true;
input int      InpSessionBoxLookbackHrs= 26;
input color    InpAsianBoxColor        = C'20,40,60';
input color    InpLondonBoxColor       = C'40,25,70';
input color    InpNYBoxColor           = C'60,35,20';

//=====================================================================
//  COLOR PALETTE
//=====================================================================
#define C_BG0     C'5,7,16'
#define C_BG1     C'9,13,26'
#define C_BG2     C'13,19,38'
#define C_HDRBAR  C'11,17,34'
#define C_BORDER  C'24,46,88'
#define C_ACBORD  C'0,170,225'
#define C_GOLD    C'255,202,60'
#define C_CYAN    C'0,224,224'
#define C_PURPLE  C'182,108,255'
#define C_WHITE   C'222,228,242'
#define C_SUBTEXT C'112,132,162'
#define C_GREEN   C'24,222,118'
#define C_RED     C'234,62,72'
#define C_ORANGE  C'255,150,10'
#define C_DKGREEN C'15,82,48'
#define C_DKRED   C'82,22,28'
#define C_LBLUE   C'85,165,255'
#define C_DGRAY   C'42,54,74'
#define C_MGRAY   C'78,92,118'

//=====================================================================
//  DASHBOARD LAYOUT CONSTANTS  (compact)
//=====================================================================
// Total width and row height tuned so the panel fits a 1920x1080
// screen at the default MT5 chart scaling without scrolling.
// Rows are 16px high; sections are separated by 2px dividers.
const int DW  = 320;   // panel width  (was 460)
const int RH  = 16;    // standard row height
const int SH  = 18;    // section header height
const int PAD = 6;     // left text padding
const int COL2 = 168;  // second-column x offset (relative to panel left)

//=====================================================================
//  GLOBAL OBJECTS
//=====================================================================
CTrade        g_trade;
CPositionInfo g_pos;
CAccountInfo  g_account;

//=====================================================================
//  INDICATOR HANDLES
//=====================================================================
int g_h1_ema_fast,  g_h1_ema_slow,  g_h1_atr;
int g_m15_ema_fast, g_m15_ema_slow, g_m15_atr, g_m15_rsi;
int g_m5_ema_fast,  g_m5_ema_slow,  g_m5_atr,  g_m5_rsi;
int g_m1_ema_fast,  g_m1_ema_slow,  g_m1_atr;

//=====================================================================
//  STATE CONTAINERS
//=====================================================================
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

//=====================================================================
//  SESSION / DAY TRACKING
//=====================================================================
datetime g_dayStart      = 0;
datetime g_weekStart     = 0;
int      g_tradesToday   = 0;
datetime g_lastCloseTime = 0;
bool     g_inCooldown    = false;
int      g_cooldownLeft  = 0;

double g_adaptiveRegimeConfThreshold;
double g_adaptiveExecScoreThreshold;

string g_statusText  = "INITIALIZING";
color  g_statusColor = C_ORANGE;
string g_lastAction  = "Starting up...";

double g_sessionProfit  = 0.0;
int    g_sessionWins    = 0;
int    g_sessionLosses  = 0;

double g_spreadHistory[20];
int    g_spreadHistCount = 0;

double      g_regimeStreakBars    = 0;
ENUM_REGIME g_regimePersistTrack = REGIME_RANGING;
int         g_regimeCandidateBars = 0;
ENUM_REGIME g_regimeCandidate    = REGIME_RANGING;

int g_prevPositionCount = 0;

//=====================================================================
//  TIME & SESSION HELPERS
//=====================================================================
datetime DayStart(datetime ts)
{
   ts += InpServerTimezoneOffsetHrs * 3600;
   MqlDateTime d; TimeToStruct(ts, d);
   return ts - (datetime)(d.hour * 3600 + d.min * 60 + d.sec);
}

datetime WeekStart(datetime ts)
{
   MqlDateTime d; TimeToStruct(ts, d);
   datetime ds = DayStart(ts);
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
//  SESSION INTELLIGENCE ENGINE
//=====================================================================
ENUM_SESSION ClassifySession(datetime ts)
{
   MqlDateTime d; TimeToStruct(ts, d);
   int hour = d.hour;
   if(hour >= 0  && hour < 7)  return SESSION_ASIAN;
   if(hour >= 7  && hour < 10) return SESSION_LONDON_OPEN;
   if(hour >= 10 && hour < 12) return SESSION_LONDON_MID;
   if(hour >= 12 && hour < 15) return SESSION_NY_OPEN;
   if(hour >= 15 && hour < 21) return SESSION_NY_PM;
   return SESSION_DEAD_ZONE;
}

void SessionHourBand(ENUM_SESSION s, int &startHour, int &endHour)
{
   switch(s)
   {
      case SESSION_ASIAN:       startHour = 0;  endHour = 7;  break;
      case SESSION_LONDON_OPEN: startHour = 7;  endHour = 10; break;
      case SESSION_LONDON_MID:  startHour = 10; endHour = 12; break;
      case SESSION_NY_OPEN:     startHour = 12; endHour = 15; break;
      case SESSION_NY_PM:       startHour = 15; endHour = 21; break;
      default:                  startHour = 21; endHour = 24; break;
   }
}

void UpdateSessionIntelligence()
{
   g_session.current = ClassifySession(TimeCurrent());

   double atrM5[1];
   if(CopyBuffer(g_m5_atr, 0, 0, 1, atrM5) <= 0) atrM5[0] = 0;

   double sHigh = iHigh(_Symbol, PERIOD_M5, 0);
   double sLow  = iLow(_Symbol, PERIOD_M5, 0);
   for(int i = 1; i < 12; i++)
   {
      double h = iHigh(_Symbol, PERIOD_M5, i);
      double l = iLow(_Symbol, PERIOD_M5, i);
      if(h > sHigh) sHigh = h;
      if(l < sLow)  sLow  = l;
   }
   double range = sHigh - sLow;
   g_session.sessionRangeATRRatio   = (atrM5[0] > 0) ? (range / atrM5[0]) : 0.0;
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
//  MTF BIAS ENGINE
//=====================================================================
int ComputeTFBias(int emaFastHandle, int emaSlowHandle, ENUM_TIMEFRAMES tf)
{
   double fastNow[2], slowNow[2];
   if(CopyBuffer(emaFastHandle, 0, 0, 2, fastNow) < 2) return 0;
   if(CopyBuffer(emaSlowHandle, 0, 0, 2, slowNow) < 2) return 0;
   double spreadNow  = fastNow[0] - slowNow[0];
   double spreadPrev = fastNow[1] - slowNow[1];
   int dirStack = (fastNow[0] > slowNow[0]) ? 1 : (fastNow[0] < slowNow[0] ? -1 : 0);
   bool widening = MathAbs(spreadNow) > MathAbs(spreadPrev);
   if(dirStack == 0) return 0;
   if(!widening && MathAbs(spreadNow) < MathAbs(spreadPrev) * 0.5) return 0;
   return dirStack;
}

void UpdateMTFBias()
{
   g_mtf.h1Bias  = ComputeTFBias(g_h1_ema_fast,  g_h1_ema_slow,  PERIOD_H1);
   g_mtf.m15Bias = ComputeTFBias(g_m15_ema_fast, g_m15_ema_slow, PERIOD_M15);
   g_mtf.m5Bias  = ComputeTFBias(g_m5_ema_fast,  g_m5_ema_slow,  PERIOD_M5);
   g_mtf.m1Bias  = ComputeTFBias(g_m1_ema_fast,  g_m1_ema_slow,  PERIOD_M1);

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
   g_mtf.alignment = (nonzero > 1) ? (100.0 * (double)(agree + 1) / (double)nonzero)
                   : (nonzero == 1 ? 50.0 : 0.0);
}

//=====================================================================
//  STRUCTURE HELPERS
//=====================================================================
double StructureHighestHigh(int lookback, int shift = 1)
{
   int idx = iHighest(_Symbol, PERIOD_M5, MODE_HIGH, lookback, shift);
   if(idx < 0) return 0;
   return iHigh(_Symbol, PERIOD_M5, idx);
}

double StructureLowestLow(int lookback, int shift = 1)
{
   int idx = iLowest(_Symbol, PERIOD_M5, MODE_LOW, lookback, shift);
   if(idx < 0) return 0;
   return iLow(_Symbol, PERIOD_M5, idx);
}

int FindSwingHighs(int lookback, int wing, double &outPrices[], datetime &outTimes[], int maxResults = 30)
{
   int count = 0;
   for(int i = wing; i < lookback - wing && count < maxResults; i++)
   {
      double h = iHigh(_Symbol, PERIOD_M5, i);
      bool isSwing = true;
      for(int w = 1; w <= wing; w++)
         if(iHigh(_Symbol, PERIOD_M5, i-w) >= h || iHigh(_Symbol, PERIOD_M5, i+w) >= h)
         { isSwing = false; break; }
      if(isSwing && count < ArraySize(outPrices))
      { outPrices[count] = h; outTimes[count] = iTime(_Symbol, PERIOD_M5, i); count++; }
   }
   return count;
}

int FindSwingLows(int lookback, int wing, double &outPrices[], datetime &outTimes[], int maxResults = 30)
{
   int count = 0;
   for(int i = wing; i < lookback - wing && count < maxResults; i++)
   {
      double l = iLow(_Symbol, PERIOD_M5, i);
      bool isSwing = true;
      for(int w = 1; w <= wing; w++)
         if(iLow(_Symbol, PERIOD_M5, i-w) <= l || iLow(_Symbol, PERIOD_M5, i+w) <= l)
         { isSwing = false; break; }
      if(isSwing && count < ArraySize(outPrices))
      { outPrices[count] = l; outTimes[count] = iTime(_Symbol, PERIOD_M5, i); count++; }
   }
   return count;
}

//=====================================================================
//  VOLATILITY ENGINE
//=====================================================================
void UpdateVolatilityIntelligence()
{
   double atrBuf[];
   ArrayResize(atrBuf, InpATRLookback);
   ArraySetAsSeries(atrBuf, true);
   int got = CopyBuffer(g_m5_atr, 0, 0, InpATRLookback, atrBuf);
   if(got < InpATRLookback / 2 || got <= 0) { g_vol.state = VOL_NORMAL; g_vol.dynamic = VOLDYN_STABLE; return; }

   double current = atrBuf[0], sum = 0; int n = 0;
   for(int i = 0; i < got; i++) { sum += atrBuf[i]; n++; }
   double avg = (n > 0) ? sum / n : current;

   g_vol.atrCurrent = current;
   g_vol.atrAvg     = avg;
   g_vol.atrRatio   = (avg > 0) ? current / avg : 1.0;

   int below = 0;
   for(int i = 0; i < got; i++) if(atrBuf[i] <= current) below++;
   g_vol.percentile = (got > 0) ? (100.0 * below / got) : 50.0;

   if(g_vol.percentile < 25)      g_vol.state = VOL_LOW;
   else if(g_vol.percentile < 65) g_vol.state = VOL_NORMAL;
   else if(g_vol.percentile < 90) g_vol.state = VOL_HIGH;
   else                           g_vol.state = VOL_EXTREME;

   double atrPrev3 = (got > 3) ? atrBuf[3] : avg;
   double roc = (atrPrev3 > 0) ? (current - atrPrev3) / atrPrev3 : 0.0;

   if(g_vol.atrRatio >= InpShockATRMultiple) g_vol.dynamic = VOLDYN_SPIKE;
   else if(roc > 0.15)                       g_vol.dynamic = VOLDYN_EXPANDING;
   else if(roc < -0.15)                      g_vol.dynamic = VOLDYN_COMPRESSING;
   else                                      g_vol.dynamic = VOLDYN_STABLE;
}

//=====================================================================
//  NEWS SHOCK PROXY
//=====================================================================
void UpdateNewsShockProxy()
{
   static datetime s_lastSample = 0;
   datetime now = TimeCurrent();
   if(now - s_lastSample >= 60)
   {
      s_lastSample = now;
      double spd = (double)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
      if(g_spreadHistCount < 20) { g_spreadHistory[g_spreadHistCount] = spd; g_spreadHistCount++; }
      else { for(int i=0;i<19;i++) g_spreadHistory[i]=g_spreadHistory[i+1]; g_spreadHistory[19]=spd; }
   }
   double sum = 0;
   for(int i = 0; i < g_spreadHistCount; i++) sum += g_spreadHistory[i];
   double avg = (g_spreadHistCount > 0) ? sum / g_spreadHistCount : (double)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   double spdNow = (double)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   double spdRatio = (avg > 0) ? spdNow / avg : 1.0;
   double barRange = iHigh(_Symbol,PERIOD_M5,0) - iLow(_Symbol,PERIOD_M5,0);
   double barRatio = (g_vol.atrAvg > 0) ? barRange / g_vol.atrAvg : 1.0;
   int shock = (g_vol.atrRatio >= InpShockATRMultiple ? 1 : 0)
             + (spdRatio       >= InpShockSpreadMultiple ? 1 : 0)
             + (barRatio       >= InpShockATRMultiple ? 1 : 0);
   g_newsState = (shock >= 2) ? NEWS_SHOCK : (shock == 1) ? NEWS_CAUTION : NEWS_NORMAL;
}

//=====================================================================
//  LIQUIDITY ENGINE
//=====================================================================
void UpdateLiquidityIntelligence()
{
   double shP[30], slP[30]; datetime shT[30], slT[30];
   int nH = FindSwingHighs(InpLiquidityLookback, 2, shP, shT);
   int nL = FindSwingLows(InpLiquidityLookback, 2, slP, slT);
   double price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double tol   = price * (InpEqualLevelTolerance / 100.0);

   g_liq.equalHighsDetected = false; g_liq.equalHighLevel = 0;
   int bestH = 0;
   for(int i = 0; i < nH; i++)
   {
      int cnt = 1; double sum = shP[i];
      for(int j = 0; j < nH; j++) if(j!=i && MathAbs(shP[j]-shP[i])<=tol) { cnt++; sum+=shP[j]; }
      if(cnt >= 2 && cnt > bestH) { bestH = cnt; g_liq.equalHighLevel = sum/cnt; g_liq.equalHighsDetected = true; }
   }
   g_liq.equalLowsDetected = false; g_liq.equalLowLevel = 0;
   int bestL = 0;
   for(int i = 0; i < nL; i++)
   {
      int cnt = 1; double sum = slP[i];
      for(int j = 0; j < nL; j++) if(j!=i && MathAbs(slP[j]-slP[i])<=tol) { cnt++; sum+=slP[j]; }
      if(cnt >= 2 && cnt > bestL) { bestL = cnt; g_liq.equalLowLevel = sum/cnt; g_liq.equalLowsDetected = true; }
   }

   g_liq.sweepUpDetected = false; g_liq.sweepDownDetected = false;
   if(g_liq.equalHighsDetected)
      for(int i=0;i<3;i++) if(iHigh(_Symbol,PERIOD_M5,i)>g_liq.equalHighLevel && iClose(_Symbol,PERIOD_M5,i)<g_liq.equalHighLevel) { g_liq.sweepUpDetected=true; break; }
   if(g_liq.equalLowsDetected)
      for(int i=0;i<3;i++) if(iLow(_Symbol,PERIOD_M5,i)<g_liq.equalLowLevel && iClose(_Symbol,PERIOD_M5,i)>g_liq.equalLowLevel) { g_liq.sweepDownDetected=true; break; }

   double dH = g_liq.equalHighsDetected ? MathAbs(price-g_liq.equalHighLevel) : -1;
   double dL = g_liq.equalLowsDetected  ? MathAbs(price-g_liq.equalLowLevel)  : -1;
   double prox = 0;
   if(dH>=0 && g_vol.atrAvg>0) prox = MathMax(prox, 100.0*MathMax(0.0,1.0-dH/(g_vol.atrAvg*1.5)));
   if(dL>=0 && g_vol.atrAvg>0) prox = MathMax(prox, 100.0*MathMax(0.0,1.0-dL/(g_vol.atrAvg*1.5)));
   g_liq.sweepProbability = MathMin(100.0, prox);

   double bias = 0;
   if(dH>=0 && dL>=0) bias = (dL<dH) ? -40.0 : 40.0;
   else if(dH>=0) bias=40.0; else if(dL>=0) bias=-40.0;
   if(g_liq.sweepUpDetected)   bias = -70.0;
   if(g_liq.sweepDownDetected) bias =  70.0;
   g_liq.biasScore      = bias;
   g_liq.pressureScore  = MathMin(100.0,(bestH+bestL)*12.0+g_liq.sweepProbability*0.3);
   g_liq.imbalanceScore = MathMin(100.0, MathAbs((double)bestH-(double)bestL)*20.0);
}

//=====================================================================
//  REGIME CLASSIFICATION ENGINE
//=====================================================================
double ScoreTrending()
{
   double s = g_mtf.alignment*0.5;
   if(g_mtf.m5Bias!=0 && g_mtf.m5Bias==g_mtf.h1Bias) s+=20;
   if(g_vol.state==VOL_NORMAL||g_vol.state==VOL_HIGH) s+=15;
   if(g_vol.dynamic==VOLDYN_EXPANDING) s+=10;
   return MathMin(100.0,s);
}
double ScoreRanging()
{
   double s=0;
   if(g_mtf.alignment<40) s+=40;
   if(g_vol.state==VOL_LOW||g_vol.state==VOL_NORMAL) s+=25;
   if(g_vol.dynamic==VOLDYN_STABLE) s+=20;
   double hh=StructureHighestHigh(InpStructureLookback,1),ll=StructureLowestLow(InpStructureLookback,1);
   double mid=(hh+ll)/2.0, px=SymbolInfoDouble(_Symbol,SYMBOL_BID);
   double rp=(hh>ll)?MathAbs(px-mid)/((hh-ll)/2.0):1.0;
   if(rp<0.6) s+=15;
   return MathMin(100.0,s);
}
double ScoreBreakout()
{
   double s=0;
   double hh=StructureHighestHigh(InpStructureLookback,1),ll=StructureLowestLow(InpStructureLookback,1);
   double px=SymbolInfoDouble(_Symbol,SYMBOL_BID);
   if(px>hh||px<ll) s+=45;
   if(g_vol.dynamic==VOLDYN_EXPANDING) s+=25;
   if(g_vol.state==VOL_HIGH) s+=15;
   if(g_mtf.alignment>60) s+=15;
   return MathMin(100.0,s);
}
double ScoreCompression()
{
   double s=0;
   if(g_vol.state==VOL_LOW) s+=35;
   if(g_vol.dynamic==VOLDYN_COMPRESSING) s+=35;
   if(g_vol.percentile<15) s+=20;
   if(g_mtf.alignment<30) s+=10;
   return MathMin(100.0,s);
}
double ScoreExpansion()
{
   double s=0;
   if(g_vol.dynamic==VOLDYN_EXPANDING) s+=40;
   if(g_vol.state==VOL_HIGH) s+=25;
   if(g_vol.atrRatio>1.3) s+=20;
   if(g_mtf.alignment>50) s+=15;
   return MathMin(100.0,s);
}
double ScoreVolatilityShock()
{
   double s=0;
   if(g_vol.dynamic==VOLDYN_SPIKE) s+=50;
   if(g_vol.state==VOL_EXTREME) s+=30;
   if(g_newsState==NEWS_SHOCK) s+=20;
   return MathMin(100.0,s);
}
double ScoreLiquiditySweep()
{
   double s=0;
   if(g_liq.sweepUpDetected||g_liq.sweepDownDetected) s+=50;
   s+=g_liq.sweepProbability*0.3+g_liq.pressureScore*0.2;
   return MathMin(100.0,s);
}
double ScoreExhaustion()
{
   double s=0,rsi[1];
   if(CopyBuffer(g_m5_rsi,0,0,1,rsi)>0 && (rsi[0]>72||rsi[0]<28)) s+=35;
   if(g_vol.dynamic==VOLDYN_COMPRESSING&&g_vol.atrRatio<0.85) s+=25;
   if(g_mtf.m1Bias!=0&&g_mtf.m5Bias!=0&&g_mtf.m1Bias!=g_mtf.m5Bias) s+=20;
   return MathMin(100.0,s);
}
double ScoreMeanReversion()
{
   double s=0,rsi[1];
   if(CopyBuffer(g_m5_rsi,0,0,1,rsi)>0 && (rsi[0]>70||rsi[0]<30)) s+=30;
   if(g_vol.state==VOL_NORMAL) s+=20;
   if(g_mtf.alignment<45) s+=25;
   if(g_liq.sweepUpDetected||g_liq.sweepDownDetected) s+=15;
   return MathMin(100.0,s);
}
double ScoreUnsafe()
{
   double s=0;
   if(g_newsState==NEWS_SHOCK) s+=60;
   if(g_vol.state==VOL_EXTREME) s+=25;
   if((double)SymbolInfoInteger(_Symbol,SYMBOL_SPREAD)>InpMaxSpreadPoints) s+=30;
   return MathMin(100.0,s);
}

void UpdateRegimeClassification()
{
   ENUM_REGIME cand[10]={REGIME_TRENDING,REGIME_RANGING,REGIME_BREAKOUT,REGIME_COMPRESSION,
      REGIME_EXPANSION,REGIME_VOLATILITY_SHOCK,REGIME_LIQUIDITY_SWEEP,
      REGIME_EXHAUSTION,REGIME_MEAN_REVERSION,REGIME_UNSAFE};
   double sc[10];
   sc[0]=ScoreTrending(); sc[1]=ScoreRanging(); sc[2]=ScoreBreakout(); sc[3]=ScoreCompression();
   sc[4]=ScoreExpansion(); sc[5]=ScoreVolatilityShock(); sc[6]=ScoreLiquiditySweep();
   sc[7]=ScoreExhaustion(); sc[8]=ScoreMeanReversion(); sc[9]=ScoreUnsafe();

   int bestIdx=0; double bestSc=sc[0];
   for(int i=1;i<10;i++) if(sc[i]>bestSc){bestSc=sc[i];bestIdx=i;}
   if(sc[9]>=55.0){bestIdx=9;bestSc=sc[9];}

   ENUM_REGIME newR = cand[bestIdx];
   if(newR==g_regimeCandidate) g_regimeCandidateBars++;
   else { g_regimeCandidate=newR; g_regimeCandidateBars=1; }

   if(g_regimeCandidateBars>=3 && newR!=g_regimePersistTrack)
   {
      g_regimeStreakBars=0; g_regimePersistTrack=newR;
      g_regime.sinceTime=TimeCurrent(); g_regime.previousRegime=g_regime.regime;
      g_regime.regime=newR;
   }
   else if(newR==g_regimePersistTrack) { g_regimeStreakBars++; g_regime.regime=newR; }

   g_regime.confidence = bestSc;
   g_regime.stability  = MathMin(100.0, g_regimeStreakBars * 8.0);
}

string RegimeToString(ENUM_REGIME r)
{
   switch(r)
   {
      case REGIME_TRENDING:         return "TRENDING";
      case REGIME_RANGING:          return "RANGING";
      case REGIME_BREAKOUT:         return "BREAKOUT";
      case REGIME_COMPRESSION:      return "COMPRESS";
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
//  STRATEGY MODULES
//=====================================================================
StrategySignal Strategy_TrendScalper()
{
   StrategySignal s; s.source=STRAT_TREND_SCALPER; s.direction=DIR_NONE; s.valid=false; s.reason="";
   if(g_mtf.alignment<55){s.reason="Low MTF align";return s;}
   int dir=(g_mtf.h1Bias!=0)?g_mtf.h1Bias:g_mtf.m15Bias;
   if(dir==0){s.reason="No macro bias";return s;}
   if(g_mtf.m5Bias!=dir){s.reason="M5 not aligned";return s;}
   double atr=g_vol.atrCurrent;
   double price=(dir>0)?SymbolInfoDouble(_Symbol,SYMBOL_ASK):SymbolInfoDouble(_Symbol,SYMBOL_BID);
   s.direction=(dir>0)?DIR_LONG:DIR_SHORT;
   s.confidence=MathMin(95.0,g_mtf.alignment*0.9+g_regime.confidence*0.1);
   s.suggestedSL=(dir>0)?NPrice(price-atr*1.5):NPrice(price+atr*1.5);
   s.suggestedTP=(dir>0)?NPrice(price+atr*2.5):NPrice(price-atr*2.5);
   s.reason="Trend MTF "+DoubleToString(g_mtf.alignment,0)+"%";
   s.valid=true; return s;
}

StrategySignal Strategy_MeanReversion()
{
   StrategySignal s; s.source=STRAT_MEAN_REVERSION; s.direction=DIR_NONE; s.valid=false; s.reason="";
   double rsi[1];
   if(CopyBuffer(g_m5_rsi,0,0,1,rsi)<=0){s.reason="RSI unavailable";return s;}
   if(rsi[0]<=70&&rsi[0]>=30){s.reason="RSI not extended";return s;}
   double hh=StructureHighestHigh(InpStructureLookback,1),ll=StructureLowestLow(InpStructureLookback,1);
   double mid=(hh+ll)/2.0, atr=g_vol.atrCurrent;
   if(rsi[0]>70)
   {
      double ep=SymbolInfoDouble(_Symbol,SYMBOL_BID);
      s.direction=DIR_SHORT;
      s.suggestedSL=NPrice(ep+atr*1.2); s.suggestedTP=NPrice(MathMax(mid,ep-atr*1.8));
   }
   else
   {
      double ep=SymbolInfoDouble(_Symbol,SYMBOL_ASK);
      s.direction=DIR_LONG;
      s.suggestedSL=NPrice(ep-atr*1.2); s.suggestedTP=NPrice(MathMin(mid,ep+atr*1.8));
   }
   s.confidence=MathMin(90.0,MathAbs(rsi[0]-50.0)*1.6);
   s.reason="MeanRev RSI "+DoubleToString(rsi[0],1); s.valid=true; return s;
}

StrategySignal Strategy_VolatilityExpansion()
{
   StrategySignal s; s.source=STRAT_VOLATILITY_EXPANSION; s.direction=DIR_NONE; s.valid=false; s.reason="";
   if(g_vol.dynamic!=VOLDYN_EXPANDING){s.reason="Not expanding";return s;}
   double hh=StructureHighestHigh(InpStructureLookback,1),ll=StructureLowestLow(InpStructureLookback,1);
   double px=SymbolInfoDouble(_Symbol,SYMBOL_BID), atr=g_vol.atrCurrent;
   if(px>hh){double ep=SymbolInfoDouble(_Symbol,SYMBOL_ASK);s.direction=DIR_LONG;s.suggestedSL=NPrice(hh-atr*0.4);s.suggestedTP=NPrice(ep+atr*3.0);}
   else if(px<ll){double ep=SymbolInfoDouble(_Symbol,SYMBOL_BID);s.direction=DIR_SHORT;s.suggestedSL=NPrice(ll+atr*0.4);s.suggestedTP=NPrice(ep-atr*3.0);}
   else{s.reason="No structural break";return s;}
   s.confidence=MathMin(92.0,50.0+g_vol.atrRatio*20.0);
   s.reason="VolExp ATR×"+DoubleToString(g_vol.atrRatio,2); s.valid=true; return s;
}

StrategySignal Strategy_LiquidityReversal()
{
   StrategySignal s; s.source=STRAT_LIQUIDITY_REVERSAL; s.direction=DIR_NONE; s.valid=false; s.reason="";
   if(!g_liq.sweepUpDetected&&!g_liq.sweepDownDetected){s.reason="No sweep";return s;}
   double atr=g_vol.atrCurrent;
   if(g_liq.sweepUpDetected){double ep=SymbolInfoDouble(_Symbol,SYMBOL_BID);s.direction=DIR_SHORT;s.suggestedSL=NPrice(g_liq.equalHighLevel+atr*0.3);s.suggestedTP=NPrice(ep-atr*2.2);}
   else{double ep=SymbolInfoDouble(_Symbol,SYMBOL_ASK);s.direction=DIR_LONG;s.suggestedSL=NPrice(g_liq.equalLowLevel-atr*0.3);s.suggestedTP=NPrice(ep+atr*2.2);}
   s.confidence=MathMin(93.0,g_liq.sweepProbability*0.5+g_liq.pressureScore*0.4);
   s.reason="LiqRev P="+DoubleToString(g_liq.pressureScore,0); s.valid=true; return s;
}

StrategySignal Strategy_CompressionBreakout()
{
   StrategySignal s; s.source=STRAT_COMPRESSION_BREAKOUT; s.direction=DIR_NONE; s.valid=false; s.reason="";
   if(g_vol.state!=VOL_LOW){s.reason="Not low vol";return s;}
   if(g_mtf.m1Bias==0){s.reason="No micro momentum";return s;}
   double hh=StructureHighestHigh(InpStructureLookback/2,1),ll=StructureLowestLow(InpStructureLookback/2,1);
   double px=SymbolInfoDouble(_Symbol,SYMBOL_BID), rng=hh-ll;
   if(rng<=0){s.reason="Invalid range";return s;}
   double pos=(px-ll)/rng;
   if(pos>0.7&&g_mtf.m1Bias>0){double ep=SymbolInfoDouble(_Symbol,SYMBOL_ASK);s.direction=DIR_LONG;s.suggestedSL=NPrice(ll);s.suggestedTP=NPrice(ep+rng*1.5);}
   else if(pos<0.3&&g_mtf.m1Bias<0){double ep=SymbolInfoDouble(_Symbol,SYMBOL_BID);s.direction=DIR_SHORT;s.suggestedSL=NPrice(hh);s.suggestedTP=NPrice(ep-rng*1.5);}
   else{s.reason="Not at edge";return s;}
   s.confidence=MathMin(88.0,45.0+(100.0-g_vol.percentile)*0.4);
   s.reason="CompBO pos="+DoubleToString(pos,2); s.valid=true; return s;
}

//=====================================================================
//  STRATEGY ROUTER
//=====================================================================
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

StrategySignal GetSignalForStrategy(ENUM_STRATEGY strat)
{
   StrategySignal s; s.valid=false; s.direction=DIR_NONE; s.source=strat; s.reason="No strategy routed";
   switch(strat)
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
      default: return -1;
   }
}

string StrategyToString(ENUM_STRATEGY s)
{
   switch(s)
   {
      case STRAT_TREND_SCALPER:        return "TrendScalp";
      case STRAT_MEAN_REVERSION:       return "MeanRev";
      case STRAT_VOLATILITY_EXPANSION: return "VolExp";
      case STRAT_LIQUIDITY_REVERSAL:   return "LiqRev";
      case STRAT_COMPRESSION_BREAKOUT: return "CompBO";
      default:                         return "None";
   }
}

//=====================================================================
//  EXECUTION QUALITY ENGINE
//=====================================================================
void UpdateExecutionQuality()
{
   double spread=(double)SymbolInfoInteger(_Symbol,SYMBOL_SPREAD);
   g_execQuality.spreadScore=MathMax(0.0,100.0*(1.0-spread/InpMaxSpreadPoints));
   double slipRisk=0;
   if(g_newsState==NEWS_SHOCK) slipRisk=90;
   else if(g_newsState==NEWS_CAUTION) slipRisk=50;
   else slipRisk=MathMin(40.0,spread/InpMaxSpreadPoints*40.0);
   g_execQuality.slippageRiskScore=100.0-slipRisk;
   double vq=100;
   if(g_vol.state==VOL_EXTREME) vq=20; else if(g_vol.state==VOL_HIGH) vq=65; else if(g_vol.state==VOL_LOW) vq=80;
   g_execQuality.volatilityQuality=vq;
   double lq=100;
   if(g_session.current==SESSION_DEAD_ZONE) lq=35; else if(g_session.current==SESSION_ASIAN) lq=70;
   g_execQuality.liquidityQuality=lq;
   double ef=100;
   if(g_vol.atrCurrent>0){ double pt=SymbolInfoDouble(_Symbol,SYMBOL_POINT); ef=MathMax(0.0,100.0*(1.0-(spread*pt/g_vol.atrCurrent)*5.0)); }
   g_execQuality.efficiencyScore=ef;
   g_execQuality.compositeScore=g_execQuality.spreadScore*0.25+g_execQuality.slippageRiskScore*0.25+
                                  g_execQuality.volatilityQuality*0.20+g_execQuality.liquidityQuality*0.15+
                                  g_execQuality.efficiencyScore*0.15;
   g_execQuality.executionApproved=true; g_execQuality.rejectReason="";
   if(spread>InpMaxSpreadPoints){g_execQuality.executionApproved=false;g_execQuality.rejectReason="Spread too wide";}
   else if(g_execQuality.compositeScore<g_adaptiveExecScoreThreshold){g_execQuality.executionApproved=false;g_execQuality.rejectReason="Low exec score";}
   else if(g_newsState==NEWS_SHOCK){g_execQuality.executionApproved=false;g_execQuality.rejectReason="News shock";}
}

//=====================================================================
//  ADAPTIVE POSITION SIZING
//=====================================================================
double CalculateAdaptiveLotSize(StrategySignal &signal, double slPrice, double &outRisk)
{
   outRisk=0.0;
   double equity=AccountInfoDouble(ACCOUNT_EQUITY);
   if(equity<=0) return 0.0;
   double price=(signal.direction==DIR_LONG)?SymbolInfoDouble(_Symbol,SYMBOL_ASK):SymbolInfoDouble(_Symbol,SYMBOL_BID);
   double slDist=MathAbs(price-slPrice);
   if(slDist<=0) return 0.0;
   double cf=MathMax(0.5,MathMin(1.0,signal.confidence/100.0));
   double rf=MathMax(0.5,MathMin(1.0,(g_regime.confidence*0.6+g_regime.stability*0.4)/100.0));
   int hIdx=StrategyHealthIndex(signal.source);
   double hf=(hIdx>=0)?g_health[hIdx].influenceMultiplier:1.0;
   double ddr=(InpMaxDrawdownPct>0)?(g_risk.currentDrawdownPct/InpMaxDrawdownPct):0.0;
   double df=MathMax(0.25,1.0-ddr);
   double rPct=MathMin(InpRiskPercentPerTrade*cf*rf*hf*df,InpMaxRiskPercentTrade);
   double rAmt=equity*(rPct/100.0);
   double tv=SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_VALUE);
   double ts=SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE);
   if(tv<=0||ts<=0) return 0.0;
   double vpu=tv/ts;
   double lot=MathFloor((rAmt/(slDist*vpu))/SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_STEP))*SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_STEP);
   lot=MathMax(SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN),MathMin(SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MAX),lot));
   outRisk=lot*slDist*vpu;
   return lot;
}

//=====================================================================
//  RISK GOVERNANCE ENGINE
//=====================================================================
void InitRiskState()
{
   double eq=AccountInfoDouble(ACCOUNT_EQUITY);
   g_risk.peakEquity=eq; g_risk.dayStartEquity=eq; g_risk.weekStartEquity=eq;
   g_risk.dailyLimitHit=false; g_risk.weeklyLimitHit=false;
   g_risk.maxDrawdownBreached=false; g_risk.emergencyShutdown=false;
   g_risk.maxDrawdownSeenPct=0;
   string gv="QPA_ESD_"+IntegerToString((long)InpMagicNumber);
   if(GlobalVariableCheck(gv)&&GlobalVariableGet(gv)>0.0)
   { g_risk.emergencyShutdown=true; g_risk.maxDrawdownBreached=true; Print("WARNING: Emergency shutdown restored."); }
}

void UpdateRiskState()
{
   double eq=AccountInfoDouble(ACCOUNT_EQUITY);
   if(eq>g_risk.peakEquity) g_risk.peakEquity=eq;
   g_risk.currentDrawdownPct=(g_risk.peakEquity>0)?(g_risk.peakEquity-eq)/g_risk.peakEquity*100.0:0.0;
   if(g_risk.currentDrawdownPct>g_risk.maxDrawdownSeenPct) g_risk.maxDrawdownSeenPct=g_risk.currentDrawdownPct;
   g_risk.dailyRiskUsedPct=(g_risk.dayStartEquity>0)?MathMax(0.0,(g_risk.dayStartEquity-eq)/g_risk.dayStartEquity*100.0):0.0;
   g_risk.weeklyRiskUsedPct=(g_risk.weekStartEquity>0)?MathMax(0.0,(g_risk.weekStartEquity-eq)/g_risk.weekStartEquity*100.0):0.0;
   g_risk.dailyLimitHit=(InpMaxDailyLossPct>0&&g_risk.dailyRiskUsedPct>=InpMaxDailyLossPct);
   g_risk.weeklyLimitHit=(InpMaxWeeklyLossPct>0&&g_risk.weeklyRiskUsedPct>=InpMaxWeeklyLossPct);
   if(InpMaxDrawdownPct>0&&g_risk.currentDrawdownPct>=InpMaxDrawdownPct)
   { g_risk.maxDrawdownBreached=true; g_risk.emergencyShutdown=true; GlobalVariableSet("QPA_ESD_"+IntegerToString((long)InpMagicNumber),1.0); }
}

bool RiskGovernanceAllowsNewTrade(string &reason)
{
   if(g_risk.emergencyShutdown){reason="Emergency shutdown";return false;}
   if(g_risk.dailyLimitHit){reason="Daily limit hit";return false;}
   if(g_risk.weeklyLimitHit){reason="Weekly limit hit";return false;}
   if(InpMaxDailyTrades>0&&g_tradesToday>=InpMaxDailyTrades){reason="Daily trade limit";return false;}
   if(PositionsTotalForMagic()>=InpMaxConcurrentTrades){reason="Max concurrent";return false;}
   if(g_inCooldown){reason="Cooldown active";return false;}
   return true;
}

int PositionsTotalForMagic()
{
   int c=0;
   for(int i=PositionsTotal()-1;i>=0;i--)
      if(g_pos.SelectByIndex(i)&&g_pos.Magic()==InpMagicNumber&&g_pos.Symbol()==_Symbol) c++;
   return c;
}

void RolloverDailyWeeklyIfNeeded()
{
   datetime today=DayStart(TimeCurrent()), thisWeek=WeekStart(TimeCurrent());
   if(today!=g_dayStart)
   { g_dayStart=today; g_tradesToday=0; g_risk.dayStartEquity=AccountInfoDouble(ACCOUNT_EQUITY);
     g_risk.dailyLimitHit=false; g_sessionProfit=0.0; g_sessionWins=0; g_sessionLosses=0; }
   if(thisWeek!=g_weekStart)
   { g_weekStart=thisWeek; g_risk.weekStartEquity=AccountInfoDouble(ACCOUNT_EQUITY); g_risk.weeklyLimitHit=false; }
}

//=====================================================================
//  STRATEGY HEALTH MONITOR
//=====================================================================
void InitStrategyHealth()
{
   string names[5]={"TrendScalp","MeanRev","VolExp","LiqRev","CompBO"};
   for(int i=0;i<5;i++)
   {
      g_health[i].name=names[i]; g_health[i].totalTrades=0; g_health[i].wins=0; g_health[i].losses=0;
      g_health[i].grossProfit=0; g_health[i].grossLoss=0; g_health[i].sumR=0; g_health[i].sumRSquared=0;
      g_health[i].consecLosses=0; g_health[i].maxConsecLosses=0; g_health[i].winRate=0;
      g_health[i].profitFactor=0; g_health[i].expectancyR=0; g_health[i].sharpeProxy=0;
      g_health[i].enabled=true; g_health[i].influenceMultiplier=1.0; g_health[i].lastDegradedTime=0;
   }
}

void UpdateStrategyInfluence(int idx)
{
   if(idx<0||idx>4) return;
   if(g_health[idx].totalTrades<InpHealthMinTrades){g_health[idx].influenceMultiplier=1.0;return;}
   double t=1.0;
   if(g_health[idx].consecLosses>=InpHealthDegradeConsecLoss) t=MathMin(t,0.5);
   if(g_health[idx].expectancyR<InpHealthMinExpectancyR) t=MathMin(t,0.4);
   if(g_health[idx].profitFactor<0.8) t=MathMin(t,0.6);
   if(g_health[idx].consecLosses>=InpHealthDegradeConsecLoss*2||g_health[idx].expectancyR<InpHealthMinExpectancyR*2.5)
   { g_health[idx].enabled=false; t=0.0; g_health[idx].lastDegradedTime=TimeCurrent(); }
   g_health[idx].influenceMultiplier+=( t-g_health[idx].influenceMultiplier)*0.5;
   if(g_health[idx].influenceMultiplier>0.7) g_health[idx].enabled=true;
}

void RegisterTradeResult(ENUM_STRATEGY strat, double pnl, double rMult)
{
   int idx=StrategyHealthIndex(strat); if(idx<0) return;
   g_health[idx].totalTrades++;
   if(pnl>=0){g_health[idx].wins++;g_health[idx].grossProfit+=pnl;g_health[idx].consecLosses=0;}
   else{g_health[idx].losses++;g_health[idx].grossLoss+=MathAbs(pnl);g_health[idx].consecLosses++;
        if(g_health[idx].consecLosses>g_health[idx].maxConsecLosses) g_health[idx].maxConsecLosses=g_health[idx].consecLosses;}
   g_health[idx].sumR+=rMult; g_health[idx].sumRSquared+=rMult*rMult;
   g_health[idx].winRate=(g_health[idx].totalTrades>0)?(100.0*g_health[idx].wins/g_health[idx].totalTrades):0.0;
   g_health[idx].profitFactor=(g_health[idx].grossLoss>0)?(g_health[idx].grossProfit/g_health[idx].grossLoss):(g_health[idx].grossProfit>0?99.0:0.0);
   g_health[idx].expectancyR=(g_health[idx].totalTrades>0)?(g_health[idx].sumR/g_health[idx].totalTrades):0.0;
   if(g_health[idx].totalTrades>1)
   { double mR=g_health[idx].sumR/g_health[idx].totalTrades; double var=g_health[idx].sumRSquared/g_health[idx].totalTrades-mR*mR;
     double sd=(var>0)?MathSqrt(var):0.0; g_health[idx].sharpeProxy=(sd>0)?(mR/sd):0.0; }
   UpdateStrategyInfluence(idx);
}

//=====================================================================
//  ADAPTIVE PARAMETER ENGINE
//=====================================================================
void InitAdaptiveParams()
{ g_adaptiveRegimeConfThreshold=InpMinRegimeConfidence; g_adaptiveExecScoreThreshold=InpMinExecutionScore; }

void UpdateAdaptiveParams()
{
   if(!InpEnableAdaptiveParams) return;
   static datetime s_lb=0; datetime cb=iTime(_Symbol,PERIOD_M5,0);
   if(cb==s_lb) return; s_lb=cb;
   double rLo=InpMinRegimeConfidence*(1.0-InpAdaptiveBoundPct/100.0),rHi=InpMinRegimeConfidence*(1.0+InpAdaptiveBoundPct/100.0);
   double eLo=InpMinExecutionScore*(1.0-InpAdaptiveBoundPct/100.0),eHi=InpMinExecutionScore*(1.0+InpAdaptiveBoundPct/100.0);
   double rn=(g_regime.confidence>g_adaptiveRegimeConfThreshold+15.0)?0.15:(g_regime.confidence<g_adaptiveRegimeConfThreshold-15.0?-0.15:0.0);
   g_adaptiveRegimeConfThreshold=MathMax(rLo,MathMin(rHi,g_adaptiveRegimeConfThreshold+rn));
   double en=(g_execQuality.compositeScore>g_adaptiveExecScoreThreshold+15.0)?0.1:(g_execQuality.compositeScore<g_adaptiveExecScoreThreshold-15.0?-0.1:0.0);
   g_adaptiveExecScoreThreshold=MathMax(eLo,MathMin(eHi,g_adaptiveExecScoreThreshold+en));
}

//=====================================================================
//  TRADE EXECUTION ENGINE
//=====================================================================
string EncodePositionTag(ENUM_STRATEGY strat, double risk)
{ return "QPA|"+IntegerToString((int)strat)+"|"+DoubleToString(risk,2); }

bool DecodePositionTag(string comment, ENUM_STRATEGY &strat, double &risk)
{
   string parts[]; int n=StringSplit(comment,'|',parts);
   if(n<3||StringLen(parts[1])==0) return false;
   int sid=(int)StringToInteger(parts[1]);
   if(sid<0||sid>5) return false;
   strat=(ENUM_STRATEGY)sid; risk=StringToDouble(parts[2]);
   return (risk>0);
}

bool ExecuteMasterDecision(MasterDecision &d)
{
   if(!d.tradeApproved||d.direction==DIR_NONE) return false;
   double price=(d.direction==DIR_LONG)?SymbolInfoDouble(_Symbol,SYMBOL_ASK):SymbolInfoDouble(_Symbol,SYMBOL_BID);
   if(price<=0) return false;
   double minDist=(int)SymbolInfoInteger(_Symbol,SYMBOL_TRADE_STOPS_LEVEL)*SymbolInfoDouble(_Symbol,SYMBOL_POINT);
   double sl=d.slPrice, tp=d.tpPrice;
   if(d.direction==DIR_LONG)
   { if(sl>0&&(price-sl)<minDist) sl=NPrice(price-minDist); if(tp>0&&(tp-price)<minDist) tp=NPrice(price+minDist); }
   else
   { if(sl>0&&(sl-price)<minDist) sl=NPrice(price+minDist); if(tp>0&&(price-tp)<minDist) tp=NPrice(price-minDist); }
   g_trade.SetExpertMagicNumber(InpMagicNumber);
   g_trade.SetDeviationInPoints(30);
   g_trade.SetTypeFilling(GetFillMode());
   string tag=EncodePositionTag(d.strategySource,d.riskAmountUsed);
   bool ok=(d.direction==DIR_LONG)?g_trade.Buy(d.lotSize,_Symbol,price,sl,tp,tag):g_trade.Sell(d.lotSize,_Symbol,price,sl,tp,tag);
   if(ok){g_tradesToday++;g_lastAction=d.narrative;DrawEntryMarker(d.direction,price,d.strategySource);}
   return ok;
}

double GetFloatingPL()
{
   double t=0;
   for(int i=PositionsTotal()-1;i>=0;i--)
      if(g_pos.SelectByIndex(i)&&g_pos.Magic()==InpMagicNumber&&g_pos.Symbol()==_Symbol)
         t+=g_pos.Profit()+g_pos.Swap()+g_pos.Commission();
   return t;
}

bool HasManagedPosition(){ return PositionsTotalForMagic()>0; }

//=====================================================================
//  TRADE TRANSACTION HANDLER
//=====================================================================
void OnTradeTransactionHandler(const MqlTradeTransaction &trans,const MqlTradeRequest &req,const MqlTradeResult &res)
{
   if(trans.type!=TRADE_TRANSACTION_DEAL_ADD) return;
   ulong deal=trans.deal;
   HistorySelect(TimeCurrent()-86400,TimeCurrent());
   if(!HistoryDealSelect(deal)) return;
   if((ulong)HistoryDealGetInteger(deal,DEAL_MAGIC)!=InpMagicNumber) return;
   if(HistoryDealGetString(deal,DEAL_SYMBOL)!=_Symbol) return;
   if(HistoryDealGetInteger(deal,DEAL_ENTRY)!=DEAL_ENTRY_OUT) return;
   double pnl=HistoryDealGetDouble(deal,DEAL_PROFIT)+HistoryDealGetDouble(deal,DEAL_SWAP)+HistoryDealGetDouble(deal,DEAL_COMMISSION);
   ENUM_STRATEGY strat=STRAT_NONE; double risk=0;
   if(!DecodePositionTag(HistoryDealGetString(deal,DEAL_COMMENT),strat,risk)) return;
   double rMult=(risk>0)?(pnl/risk):0.0;
   RegisterTradeResult(strat,pnl,rMult);
   g_sessionProfit+=pnl; if(pnl>=0) g_sessionWins++; else g_sessionLosses++;
   g_lastCloseTime=TimeCurrent(); g_inCooldown=true; g_cooldownLeft=InpCooldownAfterCloseSec;
   DrawExitMarker(HistoryDealGetDouble(deal,DEAL_PRICE),pnl);
   Print(StringFormat("[QPA] Strat=%s PnL=%.2f R=%.2f Regime=%s",StrategyToString(strat),pnl,rMult,RegimeToString(g_regime.regime)));
}

double TradeQualityScore(){ return MathMin(100.0,g_execQuality.compositeScore*0.5+g_regime.confidence*0.5); }

//=====================================================================
//  MASTER DECISION ENGINE
//=====================================================================
MasterDecision BuildMasterDecision()
{
   MasterDecision d; d.tradeApproved=false; d.direction=DIR_NONE; d.lotSize=0;
   d.slPrice=0; d.tpPrice=0; d.strategySource=STRAT_NONE; d.riskAmountUsed=0; d.narrative="";
   string r="";
   if(!RiskGovernanceAllowsNewTrade(r)){d.narrative="RiskGate:"+r;return d;}
   if(g_regime.regime==REGIME_UNSAFE){d.narrative="Regime UNSAFE";return d;}
   if(g_regime.confidence<g_adaptiveRegimeConfThreshold){d.narrative="Low regime conf";return d;}
   if(!g_execQuality.executionApproved){d.narrative="ExecGate:"+g_execQuality.rejectReason;return d;}
   ENUM_STRATEGY rs=RouteRegimeToStrategy(g_regime.regime);
   if(rs==STRAT_NONE){d.narrative="No strategy routed";return d;}
   int hIdx=StrategyHealthIndex(rs);
   if(hIdx>=0&&!g_health[hIdx].enabled){d.narrative=StrategyToString(rs)+" disabled";return d;}
   StrategySignal sig=GetSignalForStrategy(rs);
   if(!sig.valid){d.narrative="No signal:"+sig.reason;return d;}
   double sa=(g_session.preferredStrategy==rs)?MathMin(100.0,sig.confidence*g_session.strategyWeight):sig.confidence*0.85;
   if(sa<g_adaptiveRegimeConfThreshold){d.narrative="Session conf too low";return d;}
   sig.confidence=sa;
   double riskUsed=0.0;
   double lot=CalculateAdaptiveLotSize(sig,sig.suggestedSL,riskUsed);
   if(lot<=0){d.narrative="Lot=0";return d;}
   d.tradeApproved=true; d.direction=sig.direction; d.lotSize=lot;
   d.slPrice=sig.suggestedSL; d.tpPrice=sig.suggestedTP;
   d.strategySource=rs; d.riskAmountUsed=riskUsed;
   d.narrative=StrategyToString(rs)+"|"+sig.reason+"|Lot="+DoubleToString(lot,2);
   return d;
}

void RunMasterDecisionCycle()
{
   if(HasManagedPosition()){g_statusText="IN TRADE";g_statusColor=C_GREEN;return;}
   if(g_inCooldown){g_statusText="COOLDOWN";g_statusColor=C_CYAN;return;}
   MasterDecision d=BuildMasterDecision(); g_lastDecision=d;
   if(d.tradeApproved)
   {
      g_statusText="EXECUTING";g_statusColor=C_LBLUE;
      bool ok=ExecuteMasterDecision(d);
      g_statusText=ok?"IN TRADE":"EXEC FAIL"; g_statusColor=ok?C_GREEN:C_RED;
   }
   else{g_statusText="ANALYZING";g_statusColor=C_GOLD;g_lastAction=d.narrative;}
}

//=====================================================================
//  EA LIFECYCLE
//=====================================================================
int OnInit()
{
   if(StringFind(_Symbol,"XAU")<0) Print("Note: EA tuned for XAUUSD; current symbol: ",_Symbol);
   InitializeChartTheme();
   g_trade.SetExpertMagicNumber(InpMagicNumber);
   g_trade.SetDeviationInPoints(30);
   g_trade.SetTypeFilling(GetFillMode());

   g_h1_ema_fast=iMA(_Symbol,PERIOD_H1,InpEMAFastPeriod,0,MODE_EMA,PRICE_CLOSE);
   g_h1_ema_slow=iMA(_Symbol,PERIOD_H1,InpEMASlowPeriod,0,MODE_EMA,PRICE_CLOSE);
   g_h1_atr=iATR(_Symbol,PERIOD_H1,InpATRPeriod);
   g_m15_ema_fast=iMA(_Symbol,PERIOD_M15,InpEMAFastPeriod,0,MODE_EMA,PRICE_CLOSE);
   g_m15_ema_slow=iMA(_Symbol,PERIOD_M15,InpEMASlowPeriod,0,MODE_EMA,PRICE_CLOSE);
   g_m15_atr=iATR(_Symbol,PERIOD_M15,InpATRPeriod);
   g_m15_rsi=iRSI(_Symbol,PERIOD_M15,14,PRICE_CLOSE);
   g_m5_ema_fast=iMA(_Symbol,PERIOD_M5,InpEMAFastPeriod,0,MODE_EMA,PRICE_CLOSE);
   g_m5_ema_slow=iMA(_Symbol,PERIOD_M5,InpEMASlowPeriod,0,MODE_EMA,PRICE_CLOSE);
   g_m5_atr=iATR(_Symbol,PERIOD_M5,InpATRPeriod);
   g_m5_rsi=iRSI(_Symbol,PERIOD_M5,14,PRICE_CLOSE);
   g_m1_ema_fast=iMA(_Symbol,PERIOD_M1,InpEMAFastPeriod,0,MODE_EMA,PRICE_CLOSE);
   g_m1_ema_slow=iMA(_Symbol,PERIOD_M1,InpEMASlowPeriod,0,MODE_EMA,PRICE_CLOSE);
   g_m1_atr=iATR(_Symbol,PERIOD_M1,InpATRPeriod);

   if(g_h1_ema_fast==INVALID_HANDLE||g_h1_ema_slow==INVALID_HANDLE||g_h1_atr==INVALID_HANDLE||
      g_m15_ema_fast==INVALID_HANDLE||g_m15_ema_slow==INVALID_HANDLE||g_m15_atr==INVALID_HANDLE||g_m15_rsi==INVALID_HANDLE||
      g_m5_ema_fast==INVALID_HANDLE||g_m5_ema_slow==INVALID_HANDLE||g_m5_atr==INVALID_HANDLE||g_m5_rsi==INVALID_HANDLE||
      g_m1_ema_fast==INVALID_HANDLE||g_m1_ema_slow==INVALID_HANDLE||g_m1_atr==INVALID_HANDLE)
   { Print("ERROR: Indicator handle creation failed."); return INIT_FAILED; }

   g_dayStart=DayStart(TimeCurrent()); g_weekStart=WeekStart(TimeCurrent());
   InitRiskState(); InitStrategyHealth(); InitAdaptiveParams();
   g_regime.regime=REGIME_RANGING; g_regime.confidence=0; g_regime.stability=0;
   g_regime.sinceTime=TimeCurrent(); g_regime.previousRegime=REGIME_RANGING;
   g_prevPositionCount=PositionsTotalForMagic();
   if(InpShowDash) InitDash();
   EventSetTimer(1);
   g_statusText="WARMING UP"; g_statusColor=C_ORANGE;
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
   EventKillTimer(); DeleteDash(); DeleteVisualOverlays();
   IndicatorRelease(g_h1_ema_fast);  IndicatorRelease(g_h1_ema_slow);  IndicatorRelease(g_h1_atr);
   IndicatorRelease(g_m15_ema_fast); IndicatorRelease(g_m15_ema_slow); IndicatorRelease(g_m15_atr); IndicatorRelease(g_m15_rsi);
   IndicatorRelease(g_m5_ema_fast);  IndicatorRelease(g_m5_ema_slow);  IndicatorRelease(g_m5_atr);  IndicatorRelease(g_m5_rsi);
   IndicatorRelease(g_m1_ema_fast);  IndicatorRelease(g_m1_ema_slow);  IndicatorRelease(g_m1_atr);
}

void OnTimer()
{
   if(g_lastCloseTime>0){int e=(int)(TimeCurrent()-g_lastCloseTime);g_inCooldown=(e<InpCooldownAfterCloseSec);g_cooldownLeft=g_inCooldown?(InpCooldownAfterCloseSec-e):0;}
   if(InpShowDash) UpdateDash();
}

void OnTick()
{
   RolloverDailyWeeklyIfNeeded();
   int cc=PositionsTotalForMagic();
   if(cc<g_prevPositionCount&&g_prevPositionCount>0)
   { if(g_lastCloseTime==0||(int)(TimeCurrent()-g_lastCloseTime)>InpCooldownAfterCloseSec){g_lastCloseTime=TimeCurrent();g_inCooldown=true;g_cooldownLeft=InpCooldownAfterCloseSec;} }
   g_prevPositionCount=cc;
   if(Bars(_Symbol,PERIOD_H1)<InpEMASlowPeriod+5||Bars(_Symbol,PERIOD_M15)<InpEMASlowPeriod+5||
      Bars(_Symbol,PERIOD_M5)<InpATRLookback+5||Bars(_Symbol,PERIOD_M1)<InpEMASlowPeriod+5)
   { g_statusText="BUFFERING";g_statusColor=C_ORANGE;return; }
   UpdateMTFBias(); UpdateVolatilityIntelligence(); UpdateNewsShockProxy();
   UpdateLiquidityIntelligence(); UpdateSessionIntelligence(); UpdateRegimeClassification();
   UpdateVisualOverlays(); UpdateExecutionQuality(); UpdateRiskState(); UpdateAdaptiveParams();
   if(HasManagedPosition()){g_statusText="IN TRADE";g_statusColor=C_GREEN;return;}
   RunMasterDecisionCycle();
}

void OnTradeTransaction(const MqlTradeTransaction &trans,const MqlTradeRequest &req,const MqlTradeResult &res)
{ OnTradeTransactionHandler(trans,req,res); }

//=====================================================================
//  CHART THEME ENGINE
//=====================================================================
void ApplyProfessionalTheme()
{
   long c=ChartID();
   ChartSetInteger(c,CHART_MODE,CHART_CANDLES);
   ChartSetInteger(c,CHART_COLOR_BACKGROUND,clrBlack);
   ChartSetInteger(c,CHART_COLOR_FOREGROUND,clrWhite);
   ChartSetInteger(c,CHART_COLOR_GRID,clrBlack);
   ChartSetInteger(c,CHART_COLOR_CANDLE_BULL,C'24,222,118');
   ChartSetInteger(c,CHART_COLOR_CANDLE_BEAR,C'234,62,72');
   ChartSetInteger(c,CHART_COLOR_CHART_UP,C'24,222,118');
   ChartSetInteger(c,CHART_COLOR_CHART_DOWN,C'234,62,72');
   ChartSetInteger(c,CHART_COLOR_CHART_LINE,clrWhite);
   ChartSetInteger(c,CHART_COLOR_VOLUME,clrAqua);
   ChartSetInteger(c,CHART_COLOR_BID,C'24,222,118');
   ChartSetInteger(c,CHART_COLOR_ASK,C'234,62,72');
   ChartSetInteger(c,CHART_COLOR_STOP_LEVEL,clrYellow);
   ChartSetInteger(c,CHART_SHOW_GRID,false);
   ChartSetInteger(c,CHART_SHOW_VOLUMES,true);
   ChartSetInteger(c,CHART_SHOW_OHLC,true);
   ChartSetInteger(c,CHART_SHOW_ASK_LINE,false);
   ChartSetInteger(c,CHART_SHOW_BID_LINE,false);
   ChartSetInteger(c,CHART_SHOW_TRADE_LEVELS,true);
   ChartSetInteger(c,CHART_SHIFT,true);
   ChartSetInteger(c,CHART_AUTOSCROLL,true);
   ChartRedraw(c);
}

void InitializeChartTheme()
{
   if(!InpApplyChartTheme) return;
   if(InpLoadChartTemplate) ChartApplyTemplate(ChartID(),InpTemplateName+".tpl");
   ApplyProfessionalTheme();
   if(InpSaveChartTemplate) ChartSaveTemplate(ChartID(),InpTemplateName+".tpl");
}

//=====================================================================
//  COMPACT DASHBOARD SYSTEM
//  Layout: 320px wide, fixed-height rows of 16px.
//  All rectangles created BEFORE labels to guarantee labels render on top.
//  OBJPROP_HIDDEN = false on every object.
//  Two-pass approach: pass 1 = all rects, pass 2 = all labels.
//=====================================================================

// --- Helpers --------------------------------------------------------
void DR(string nm,int x,int y,int w,int h,color bg,color brd=clrNONE,int bw=1)
{
   string n=D+nm;
   if(ObjectFind(0,n)<0) ObjectCreate(0,n,OBJ_RECTANGLE_LABEL,0,0,0);
   ObjectSetInteger(0,n,OBJPROP_CORNER,CORNER_LEFT_UPPER);
   ObjectSetInteger(0,n,OBJPROP_XDISTANCE,x);
   ObjectSetInteger(0,n,OBJPROP_YDISTANCE,y);
   ObjectSetInteger(0,n,OBJPROP_XSIZE,w);
   ObjectSetInteger(0,n,OBJPROP_YSIZE,h);
   ObjectSetInteger(0,n,OBJPROP_BGCOLOR,bg);
   ObjectSetInteger(0,n,OBJPROP_SELECTABLE,false);
   ObjectSetInteger(0,n,OBJPROP_HIDDEN,false);
   ObjectSetInteger(0,n,OBJPROP_ZORDER,0);
   if(brd!=clrNONE){ObjectSetInteger(0,n,OBJPROP_BORDER_TYPE,BORDER_FLAT);ObjectSetInteger(0,n,OBJPROP_COLOR,brd);ObjectSetInteger(0,n,OBJPROP_WIDTH,bw);}
   else{ObjectSetInteger(0,n,OBJPROP_BORDER_TYPE,BORDER_RAISED);ObjectSetInteger(0,n,OBJPROP_COLOR,bg);}
}

void DL(string nm,int x,int y,string txt,color clr,int fsz=7,string fnt="Arial Bold")
{
   string n=D+nm;
   if(ObjectFind(0,n)<0) ObjectCreate(0,n,OBJ_LABEL,0,0,0);
   ObjectSetInteger(0,n,OBJPROP_CORNER,CORNER_LEFT_UPPER);
   ObjectSetInteger(0,n,OBJPROP_XDISTANCE,x);
   ObjectSetInteger(0,n,OBJPROP_YDISTANCE,y);
   ObjectSetString(0,n,OBJPROP_TEXT,txt);
   ObjectSetInteger(0,n,OBJPROP_COLOR,clr);
   ObjectSetInteger(0,n,OBJPROP_FONTSIZE,fsz);
   ObjectSetString(0,n,OBJPROP_FONT,fnt);
   ObjectSetInteger(0,n,OBJPROP_SELECTABLE,false);
   ObjectSetInteger(0,n,OBJPROP_HIDDEN,false);
   ObjectSetInteger(0,n,OBJPROP_ZORDER,1);
}

void DU(string nm,string txt,color clr=C_WHITE)
{
   string n=D+nm;
   if(ObjectFind(0,n)>=0){ObjectSetString(0,n,OBJPROP_TEXT,txt);ObjectSetInteger(0,n,OBJPROP_COLOR,clr);}
}

// Update rectangle background color
void DRC(string nm,color bg)
{ string n=D+nm; if(ObjectFind(0,n)>=0) ObjectSetInteger(0,n,OBJPROP_BGCOLOR,bg); }

// Thin horizontal divider
void DIV(string nm,int x,int y,int w)
{ DR(nm,x,y,w,1,C_BORDER,clrNONE); }

// Section header bar (returns bottom y of header)
int HDR(string nm,int x,int y,int w,string title,color titleClr,color bgClr)
{
   DR(nm+"_hbg",x,y,w,SH,bgClr,C_BORDER,1);
   DL(nm+"_htxt",x+PAD,y+3,title,titleClr,7,"Arial Black");
   return y+SH;
}

// Two-column data row (key left, value right) — returns bottom y
int ROW(string keyNm,string valNm,int x,int y,int w,string key,string val,color valClr)
{
   DL(keyNm,x+PAD,y+2,key,C_SUBTEXT,7,"Arial");
   DL(valNm,x+COL2,y+2,val,valClr,7);
   return y+RH;
}

// Full-width centered label row
int FROW(string nm,int x,int y,int w,string txt,color clr,int fsz=8)
{
   DL(nm,x+PAD,y+2,txt,clr,fsz,"Arial Bold");
   return y+RH;
}

// Thin progress bar (drawn as two rects, already in rect-pass if called from InitDash)
void PBAR(string nm,int x,int y,int w,int h,double pct,color fg,color bg_c)
{
   DR(nm+"_bg",x,y,w,h,bg_c,C_BORDER,1);
   int fw=(int)MathMax(2,MathRound(MathMax(0.0,MathMin(100.0,pct))/100.0*(w-2)));
   DR(nm+"_fg",x+1,y+1,fw,h-2,fg,clrNONE);
}
void PBAR_UPD(string nm,double pct,color fg)
{
   string nb=D+nm+"_bg",nf=D+nm+"_fg";
   if(ObjectFind(0,nb)<0) return;
   int w=(int)ObjectGetInteger(0,nb,OBJPROP_XSIZE);
   int fw=(int)MathMax(2,MathRound(MathMax(0.0,MathMin(100.0,pct))/100.0*(w-2)));
   if(ObjectFind(0,nf)>=0){ObjectSetInteger(0,nf,OBJPROP_XSIZE,fw);ObjectSetInteger(0,nf,OBJPROP_BGCOLOR,fg);}
}

//--------------------------------------------------------------------
//  InitDash  — compact 320-wide panel
//  Sections (top-to-bottom):
//   [TITLE BAR]           18px
//   [DECISION BANNER]     28px  — BIG status
//   [MARKET]              5 rows
//   [REGIME]              3 rows
//   [STRATEGY]            2 rows
//   [RISK]                3 rows
//   [ACCOUNT]             3 rows
//   [SESSION TABS]        16px
//   [FOOTER]              14px
//  Total ≈ 390px height — fits 1080p with space to spare
//--------------------------------------------------------------------
void InitDash()
{
   if(!InpShowDash) return;
   int X=InpDashX, Y=InpDashY, W=DW;

   // ── PASS 1 : all rectangles ──────────────────────────────────────
   // Outer shell
   DR("shell",X,Y,W,392,C_BG0,C_ACBORD,2);
   DR("inner",X+2,Y+2,W-4,388,C_BG0,C_BORDER,1);

   // Title bar
   DR("titlebar",X+2,Y+2,W-4,18,C_HDRBAR,C_ACBORD,1);

   // Decision banner
   DR("banner_bg",X+2,Y+22,W-4,28,C_DGRAY,C_GOLD,2);

   // Market section bg
   DR("mkt_bg",X+2,Y+52,W-4,5*RH+4,C_BG2,C_BORDER,1);

   // Regime section bg
   DR("reg_bg",X+2,Y+52+5*RH+6,W-4,SH+3*RH+2,C_BG2,C_BORDER,1);

   // Strategy section bg
   int yStr=Y+52+5*RH+6+SH+3*RH+4;
   DR("str_bg",X+2,yStr,W-4,SH+2*RH+2,C_BG2,C_BORDER,1);

   // Risk section bg
   int yRisk=yStr+SH+2*RH+4;
   DR("risk_bg",X+2,yRisk,W-4,SH+3*RH+2,C_BG2,C_BORDER,1);

   // Confidence progress bar (inside risk section)
   PBAR("conf",X+3,yRisk+SH+2*RH+1,W-6,8,0,C_GOLD,C_DGRAY);

   // Account section bg
   int yAcc=yRisk+SH+3*RH+10;
   DR("acc_bg",X+2,yAcc,W-4,SH+3*RH+2,C_BG2,C_DKGREEN,1);

   // Session tabs
   int yTabs=yAcc+SH+3*RH+4;
   int tw=(W-4)/3;
   DR("tab_asia",   X+2,       yTabs,tw,  RH,C_DGRAY,C_BORDER,1);
   DR("tab_london", X+2+tw,    yTabs,tw,  RH,C_DGRAY,C_BORDER,1);
   DR("tab_ny",     X+2+tw*2,  yTabs,W-4-tw*2,RH,C_DGRAY,C_BORDER,1);

   // Footer
   DR("footer",X+2,yTabs+RH+1,W-4,14,C_HDRBAR,C_BORDER,1);

   // ── PASS 2 : all labels ──────────────────────────────────────────
   // Title
   DL("title_l", X+PAD, Y+4,   InpBotName+" v1.0", C_CYAN, 8,"Arial Black");
   DL("title_r", X+W-68,Y+5,   "QPA ENGINE",        C_SUBTEXT,6,"Arial");

   // Decision banner labels
   DL("ban_dec",  X+PAD,      Y+28, "ANALYZING",    C_ORANGE, 11,"Arial Black");
   DL("ban_strat",X+W-100,    Y+25, "Strategy:",    C_SUBTEXT,6,"Arial");
   DL("ban_sval", X+W-100,    Y+34, "None",         C_WHITE,  7);

   // Market section header
   int yM = Y+52;
   DR("mkt_hbg",X+2,yM,W-4,SH,C_HDRBAR,C_BORDER,1);
   DL("mkt_htxt",X+PAD,yM+3,"MARKET",C_GOLD,7,"Arial Black");
   DL("mkt_htime",X+W-72,yM+3,"--:--:--",C_SUBTEXT,6,"Arial");
   yM+=SH;
   // rows
   ROW("lb_bid","vl_bid",     X,yM,W,"Bid",   "0.00",     C_WHITE);  yM+=RH;
   ROW("lb_ask","vl_ask",     X,yM,W,"Ask",   "0.00",     C_WHITE);  yM+=RH;
   ROW("lb_spd","vl_spd",     X,yM,W,"Spread","0 pts",    C_GREEN);  yM+=RH;
   ROW("lb_atr","vl_atr",     X,yM,W,"ATR",   "0",        C_WHITE);  yM+=RH;
   ROW("lb_vol","vl_vol",     X,yM,W,"Vol",   "NORMAL",   C_GREEN);  yM+=RH;

   // Regime section header
   int yR=Y+52+5*RH+6;
   DR("reg_hbg",X+2,yR,W-4,SH,C_HDRBAR,C_BORDER,1);
   DL("reg_htxt",X+PAD,yR+3,"REGIME & MTF",C_GOLD,7,"Arial Black");
   yR+=SH;
   ROW("lb_rg","vl_rg",       X,yR,W,"Regime","RANGING",  C_CYAN);   yR+=RH;
   ROW("lb_rc","vl_rc",       X,yR,W,"Conf",  "0%",       C_WHITE);  yR+=RH;
   ROW("lb_mtf","vl_mtf",     X,yR,W,"MTF",   "0%",       C_WHITE);  yR+=RH;

   // Strategy section
   HDR("str",X+2,yStr,W-4,"STRATEGY & EXECUTION",C_GOLD,C_HDRBAR);
   int yS=yStr+SH;
   ROW("lb_st","vl_st",       X,yS,W,"Active","None",      C_ORANGE); yS+=RH;
   ROW("lb_eq","vl_eq",       X,yS,W,"Exec Q","0.0",       C_WHITE);  yS+=RH;

   // Risk section
   HDR("rsk",X+2,yRisk,W-4,"RISK GOVERNANCE",C_GOLD,C_HDRBAR);
   int yK=yRisk+SH;
   ROW("lb_dd","vl_dd",       X,yK,W,"Drawdn","0.00%",    C_WHITE);  yK+=RH;
   ROW("lb_dl","vl_dl",       X,yK,W,"Day L", "0.00%",    C_WHITE);  yK+=RH;
   // conf bar sits here (already drawn as rect in pass 1)
   DL("conf_lbl",X+PAD,yK+1,"Conf",C_SUBTEXT,6,"Arial");
   DL("conf_pct",X+50,yK+1,"0%",C_GOLD,6);

   // Account section
   HDR("acc",X+2,yAcc,W-4,"ACCOUNT",C_WHITE,C_DKGREEN);
   int yA=yAcc+SH;
   ROW("lb_bal","vl_bal",     X,yA,W,"Balance","0.00",     C_GREEN);  yA+=RH;
   ROW("lb_flt","vl_flt",     X,yA,W,"Float",  "+0.00",    C_GREEN);  yA+=RH;
  

   // Session tab labels
   int yT=yTabs;
   DL("tab_asia_l",   X+2+tw/2-12,    yT+3,"ASIA",    C_SUBTEXT,6,"Arial Bold");
   DL("tab_london_l", X+2+tw+tw/2-22, yT+3,"LONDON",  C_SUBTEXT,6,"Arial Bold");
   DL("tab_ny_l",     X+2+tw*2+tw/2-22,yT+3,"NEW YORK",C_SUBTEXT,6,"Arial Bold");

   // Footer
   DL("ft",X+PAD,yTabs+RH+2,"",C_MGRAY,6,"Arial");

   ChartRedraw(0);
}

//--------------------------------------------------------------------
string VolStr(ENUM_VOL_STATE v)
{ switch(v){case VOL_LOW:return "LOW";case VOL_NORMAL:return "NORMAL";case VOL_HIGH:return "HIGH";default:return "EXTREME";} }
string NewsStr(ENUM_NEWS_STATE n)
{ switch(n){case NEWS_NORMAL:return "NORMAL";case NEWS_CAUTION:return "CAUTION";default:return "SHOCK!";} }
string SessStr(ENUM_SESSION s)
{ switch(s){case SESSION_ASIAN:return "ASIAN";case SESSION_LONDON_OPEN:return "LON-OPEN";case SESSION_LONDON_MID:return "LON-MID";case SESSION_NY_OPEN:return "NY-OPEN";case SESSION_NY_PM:return "NY-PM";default:return "DEAD";} }

//--------------------------------------------------------------------
void UpdateDash()
{
   if(!InpShowDash) return;
   int digs=(int)SymbolInfoInteger(_Symbol,SYMBOL_DIGITS);
   int X=InpDashX, W=DW;

   // Title time
   DU("mkt_htime",TimeToString(TimeCurrent(),TIME_SECONDS),C_SUBTEXT);

   // Decision banner
   bool hasPos=HasManagedPosition();
   bool tradeOn=g_lastDecision.tradeApproved;
   string decTxt; color decClr; color banBg;
   if(g_risk.emergencyShutdown){decTxt="SHUTDOWN";decClr=C_RED;banBg=C_DKRED;}
   else if(hasPos){decTxt=(g_lastDecision.direction==DIR_LONG)?"◆ LONG OPEN":"◆ SHORT OPEN";decClr=C_GREEN;banBg=C_DKGREEN;}
   else if(g_inCooldown){decTxt="COOLDOWN "+IntegerToString(g_cooldownLeft)+"s";decClr=C_CYAN;banBg=C_DGRAY;}
   else if(tradeOn){decTxt=(g_lastDecision.direction==DIR_LONG)?"▲ BUY":"▼ SELL";decClr=(g_lastDecision.direction==DIR_LONG)?C_GREEN:C_RED;banBg=(g_lastDecision.direction==DIR_LONG)?C_DKGREEN:C_DKRED;}
   else{decTxt=g_statusText;decClr=g_statusColor;banBg=C_DGRAY;}
   DU("ban_dec",decTxt,decClr); DRC("banner_bg",banBg);
   ENUM_STRATEGY routed=RouteRegimeToStrategy(g_regime.regime);
   DU("ban_sval",StrategyToString(routed),(routed==STRAT_NONE)?C_MGRAY:C_WHITE);

   // Market
   double bid=SymbolInfoDouble(_Symbol,SYMBOL_BID);
   double ask=SymbolInfoDouble(_Symbol,SYMBOL_ASK);
   double spd=(double)SymbolInfoInteger(_Symbol,SYMBOL_SPREAD);
   bool spdOk=(spd<=InpMaxSpreadPoints);
   DU("vl_bid",DoubleToString(bid,digs),C_WHITE);
   DU("vl_ask",DoubleToString(ask,digs),C_WHITE);
   DU("vl_spd",DoubleToString(spd,0)+" pts"+(spdOk?" OK":" !"),spdOk?C_GREEN:C_RED);
   DU("vl_atr",DoubleToString(g_vol.atrCurrent/SymbolInfoDouble(_Symbol,SYMBOL_POINT),1)+" pts",C_WHITE);
   string volTxt=VolStr(g_vol.state)+" / "+NewsStr(g_newsState)+" / "+SessStr(g_session.current);
   color volClr=(g_vol.state==VOL_EXTREME||g_newsState==NEWS_SHOCK)?C_RED:(g_newsState==NEWS_CAUTION||g_vol.state==VOL_HIGH)?C_ORANGE:C_GREEN;
   DU("vl_vol",volTxt,volClr);

   // Regime
   color regClr=(g_regime.regime==REGIME_UNSAFE)?C_RED:(g_regime.confidence>=70)?C_CYAN:C_ORANGE;
   DU("vl_rg",RegimeToString(g_regime.regime),regClr);
   DU("vl_rc",DoubleToString(g_regime.confidence,0)+"% stab "+DoubleToString(g_regime.stability,0)+"%",(g_regime.confidence>=60)?C_GREEN:C_ORANGE);
   string mtfTxt="H1:"+IntegerToString(g_mtf.h1Bias)+" M15:"+IntegerToString(g_mtf.m15Bias)+" M5:"+IntegerToString(g_mtf.m5Bias)+" aln "+DoubleToString(g_mtf.alignment,0)+"%";
   DU("vl_mtf",mtfTxt,(g_mtf.alignment>=65)?C_GREEN:(g_mtf.alignment>=40)?C_ORANGE:C_RED);

   // Strategy
   int hIdx=StrategyHealthIndex(routed);
   bool hOk=(hIdx<0)?true:g_health[hIdx].enabled;
   string strTxt=(routed==STRAT_NONE)?"None":StrategyToString(routed);
   if(!hOk) strTxt+=" [OFF]";
   DU("vl_st",strTxt,(routed==STRAT_NONE)?C_MGRAY:(hOk?C_WHITE:C_RED));
   DU("vl_eq",DoubleToString(g_execQuality.compositeScore,1)+(g_execQuality.executionApproved?" PASS":" BLOCK"),(g_execQuality.executionApproved)?C_GREEN:C_RED);

   // Risk / confidence bar
   color ddClr=(g_risk.currentDrawdownPct<4)?C_GREEN:(g_risk.currentDrawdownPct<8)?C_ORANGE:C_RED;
   DU("vl_dd",DoubleToString(g_risk.currentDrawdownPct,2)+"% (max "+DoubleToString(InpMaxDrawdownPct,0)+"%)",ddClr);
   string dlTxt=DoubleToString(g_risk.dailyRiskUsedPct,2)+"% / "+DoubleToString(InpMaxDailyLossPct,0)+"% | trades "+IntegerToString(g_tradesToday)+"/"+IntegerToString(InpMaxDailyTrades);
   DU("vl_dl",dlTxt,(g_risk.dailyLimitHit)?C_RED:C_WHITE);
   double conf=TradeQualityScore();
   color cClr=(conf>=75)?C_GREEN:(conf>=45)?C_GOLD:C_RED;
   DU("conf_pct",DoubleToString(conf,0)+"%",cClr);
   PBAR_UPD("conf",conf,cClr);

   // Account
   double bal=AccountInfoDouble(ACCOUNT_BALANCE);
   double eq=AccountInfoDouble(ACCOUNT_EQUITY);
   double flt=GetFloatingPL();
   double dayPL=eq-g_risk.dayStartEquity;
   double dayPct=(g_risk.dayStartEquity>0)?dayPL/g_risk.dayStartEquity*100.0:0.0;
   DU("vl_bal",DoubleToString(bal,2)+" / eq "+DoubleToString(eq,2),C_GREEN);
   DU("vl_flt",(flt>=0?"+":"")+DoubleToString(flt,2)+" float",(flt>=0)?C_GREEN:C_RED);
   DU("vl_dpl",(dayPL>=0?"+":"")+DoubleToString(dayPL,2)+" ("+DoubleToString(dayPct,2)+"%)",(dayPL>=0)?C_GREEN:C_RED);

   // Session tabs
   color cAs=(g_session.current==SESSION_ASIAN)?C_ORANGE:C_DGRAY;
   color cLn=(g_session.current==SESSION_LONDON_OPEN||g_session.current==SESSION_LONDON_MID)?C_ORANGE:C_DGRAY;
   color cNY=(g_session.current==SESSION_NY_OPEN||g_session.current==SESSION_NY_PM)?C_ORANGE:C_DGRAY;
   DRC("tab_asia",cAs);   DU("tab_asia_l","ASIA",  (cAs==C_ORANGE)?C_BG0:C_SUBTEXT);
   DRC("tab_london",cLn); DU("tab_london_l","LONDON",(cLn==C_ORANGE)?C_BG0:C_SUBTEXT);
   DRC("tab_ny",cNY);     DU("tab_ny_l","NEW YORK",(cNY==C_ORANGE)?C_BG0:C_SUBTEXT);

   // Footer
   DU("ft","Srv:"+TimeToString(TimeCurrent(),TIME_SECONDS)+" | MN:"+IntegerToString((long)InpMagicNumber)+" | "+InpBotName,C_MGRAY);

   ChartRedraw(0);
}

void DeleteDash(){ ObjectsDeleteAll(0,D); ChartRedraw(0); }

//=====================================================================
//  VISUAL INTELLIGENCE OVERLAYS
//=====================================================================
int SafeBar(datetime t)
{
   if(t>TimeCurrent()) t=TimeCurrent();
   int b=iBarShift(_Symbol,PERIOD_M5,t,false);
   return (b<0)?0:b;
}

void DrawSessionBox(string id,datetime t0,datetime t1,color col,string lbl)
{
   datetime now=TimeCurrent();
   datetime e=MathMin(t1,now);
   if(e<=t0) return;
   int b0=SafeBar(t0), b1=SafeBar(e);
   if(b0<b1){int tmp=b0;b0=b1;b1=tmp;}
   double hi=-1e300,lo=1e300;
   for(int i=b1;i<=b0&&i>=0;i++)
   {
      double h=iHigh(_Symbol,PERIOD_M5,i), l=iLow(_Symbol,PERIOD_M5,i);
      if(h!=0&&h>hi) hi=h; if(l!=0&&l<lo) lo=l;
   }
   if(hi<=-1e300||lo>=1e300||hi<=lo) return;
   double buf=(hi-lo)*0.01; hi+=buf; lo-=buf;

   string nm=OV+"SB_"+id;
   if(ObjectFind(0,nm)>=0) ObjectDelete(0,nm);
   if(ObjectCreate(0,nm,OBJ_RECTANGLE,0,t0,hi,e,lo))
   {
      ObjectSetInteger(0,nm,OBJPROP_COLOR,col);
      ObjectSetInteger(0,nm,OBJPROP_FILL,true);
      ObjectSetInteger(0,nm,OBJPROP_BACK,true);
      ObjectSetInteger(0,nm,OBJPROP_SELECTABLE,false);
      ObjectSetInteger(0,nm,OBJPROP_HIDDEN,false);
   }
   string nt=OV+"SBT_"+id;
   if(ObjectFind(0,nt)>=0) ObjectDelete(0,nt);
   if(ObjectCreate(0,nt,OBJ_TREND,0,t0,hi,e,hi))
   {
      ObjectSetInteger(0,nt,OBJPROP_COLOR,col);ObjectSetInteger(0,nt,OBJPROP_WIDTH,2);
      ObjectSetInteger(0,nt,OBJPROP_RAY_RIGHT,false);ObjectSetInteger(0,nt,OBJPROP_SELECTABLE,false);
      ObjectSetInteger(0,nt,OBJPROP_HIDDEN,false);ObjectSetInteger(0,nt,OBJPROP_BACK,false);
   }
   string nb=OV+"SBB_"+id;
   if(ObjectFind(0,nb)>=0) ObjectDelete(0,nb);
   if(ObjectCreate(0,nb,OBJ_TREND,0,t0,lo,e,lo))
   {
      ObjectSetInteger(0,nb,OBJPROP_COLOR,col);ObjectSetInteger(0,nb,OBJPROP_WIDTH,2);
      ObjectSetInteger(0,nb,OBJPROP_RAY_RIGHT,false);ObjectSetInteger(0,nb,OBJPROP_SELECTABLE,false);
      ObjectSetInteger(0,nb,OBJPROP_HIDDEN,false);ObjectSetInteger(0,nb,OBJPROP_BACK,false);
   }
   string nl=OV+"SBL_"+id;
   if(ObjectFind(0,nl)>=0) ObjectDelete(0,nl);
   if(ObjectCreate(0,nl,OBJ_TEXT,0,t0,hi))
   {
      ObjectSetString(0,nl,OBJPROP_TEXT,lbl);ObjectSetInteger(0,nl,OBJPROP_COLOR,col);
      ObjectSetInteger(0,nl,OBJPROP_FONTSIZE,8);ObjectSetString(0,nl,OBJPROP_FONT,"Arial Bold");
      ObjectSetInteger(0,nl,OBJPROP_SELECTABLE,false);ObjectSetInteger(0,nl,OBJPROP_HIDDEN,false);
      ObjectSetInteger(0,nl,OBJPROP_BACK,false);ObjectSetInteger(0,nl,OBJPROP_ANCHOR,ANCHOR_LEFT_LOWER);
   }
}

void UpdateSessionBoxes()
{
   if(!InpDrawSessionBoxes) return;
   datetime now=TimeCurrent(),today=DayStart(now),yest=today-86400;
   datetime lb=now-(datetime)(InpSessionBoxLookbackHrs*3600);
   ENUM_SESSION ss[5]={SESSION_ASIAN,SESSION_LONDON_OPEN,SESSION_LONDON_MID,SESSION_NY_OPEN,SESSION_NY_PM};
   color sc[5]={InpAsianBoxColor,InpLondonBoxColor,InpLondonBoxColor,InpNYBoxColor,InpNYBoxColor};
   string sl[5]={"ASIAN","LON-O","LON-M","NY-O","NY-P"};
   for(int d=0;d<2;d++)
   {
      datetime db=(d==0)?today:yest;
      for(int i=0;i<5;i++)
      {
         int sh,eh; SessionHourBand(ss[i],sh,eh);
         datetime st=db+sh*3600, et=db+eh*3600;
         if(et<lb||st>now) continue;
         DrawSessionBox(sl[i]+"_"+IntegerToString((int)db),st,et,sc[i],sl[i]);
      }
   }
}

void UpdateLiquidityZones()
{
   if(!InpDrawLiquidityZones) return;
   datetime now=TimeCurrent(), past=now-(datetime)(InpSessionBoxLookbackHrs*3600);
   double pt=SymbolInfoDouble(_Symbol,SYMBOL_POINT);

   // Equal Highs
   string nh=OV+"EQH", nht=OV+"EQHT", nhl=OV+"EQHL";
   if(g_liq.equalHighsDetected)
   {
      double zw=MathMax(pt*80,g_vol.atrAvg*0.06);
      color zc=g_liq.sweepUpDetected?C_RED:C_ORANGE;
      if(ObjectFind(0,nh)>=0) ObjectDelete(0,nh);
      if(ObjectCreate(0,nh,OBJ_RECTANGLE,0,past,g_liq.equalHighLevel+zw,now,g_liq.equalHighLevel-zw))
      {ObjectSetInteger(0,nh,OBJPROP_COLOR,zc);ObjectSetInteger(0,nh,OBJPROP_FILL,true);ObjectSetInteger(0,nh,OBJPROP_BACK,true);ObjectSetInteger(0,nh,OBJPROP_SELECTABLE,false);ObjectSetInteger(0,nh,OBJPROP_HIDDEN,false);}
      if(ObjectFind(0,nht)>=0) ObjectDelete(0,nht);
      if(ObjectCreate(0,nht,OBJ_TREND,0,past,g_liq.equalHighLevel,now,g_liq.equalHighLevel))
      {ObjectSetInteger(0,nht,OBJPROP_COLOR,zc);ObjectSetInteger(0,nht,OBJPROP_WIDTH,2);ObjectSetInteger(0,nht,OBJPROP_STYLE,STYLE_DASH);ObjectSetInteger(0,nht,OBJPROP_RAY_RIGHT,false);ObjectSetInteger(0,nht,OBJPROP_SELECTABLE,false);ObjectSetInteger(0,nht,OBJPROP_HIDDEN,false);ObjectSetInteger(0,nht,OBJPROP_BACK,false);}
      if(ObjectFind(0,nhl)>=0) ObjectDelete(0,nhl);
      if(ObjectCreate(0,nhl,OBJ_TEXT,0,now,g_liq.equalHighLevel+zw))
      {ObjectSetString(0,nhl,OBJPROP_TEXT,g_liq.sweepUpDetected?"EQH SWEPT":"EQH LIQ");ObjectSetInteger(0,nhl,OBJPROP_COLOR,zc);ObjectSetInteger(0,nhl,OBJPROP_FONTSIZE,8);ObjectSetString(0,nhl,OBJPROP_FONT,"Arial Bold");ObjectSetInteger(0,nhl,OBJPROP_SELECTABLE,false);ObjectSetInteger(0,nhl,OBJPROP_HIDDEN,false);ObjectSetInteger(0,nhl,OBJPROP_BACK,false);ObjectSetInteger(0,nhl,OBJPROP_ANCHOR,ANCHOR_RIGHT_LOWER);}
   }
   else
   { if(ObjectFind(0,nh)>=0)ObjectDelete(0,nh); if(ObjectFind(0,nht)>=0)ObjectDelete(0,nht); if(ObjectFind(0,nhl)>=0)ObjectDelete(0,nhl); }

   // Equal Lows
   string nl=OV+"EQL", nlt=OV+"EQLT", nll=OV+"EQLL";
   if(g_liq.equalLowsDetected)
   {
      double zw=MathMax(pt*80,g_vol.atrAvg*0.06);
      color zc=g_liq.sweepDownDetected?C_GREEN:C_LBLUE;
      if(ObjectFind(0,nl)>=0) ObjectDelete(0,nl);
      if(ObjectCreate(0,nl,OBJ_RECTANGLE,0,past,g_liq.equalLowLevel+zw,now,g_liq.equalLowLevel-zw))
      {ObjectSetInteger(0,nl,OBJPROP_COLOR,zc);ObjectSetInteger(0,nl,OBJPROP_FILL,true);ObjectSetInteger(0,nl,OBJPROP_BACK,true);ObjectSetInteger(0,nl,OBJPROP_SELECTABLE,false);ObjectSetInteger(0,nl,OBJPROP_HIDDEN,false);}
      if(ObjectFind(0,nlt)>=0) ObjectDelete(0,nlt);
      if(ObjectCreate(0,nlt,OBJ_TREND,0,past,g_liq.equalLowLevel,now,g_liq.equalLowLevel))
      {ObjectSetInteger(0,nlt,OBJPROP_COLOR,zc);ObjectSetInteger(0,nlt,OBJPROP_WIDTH,2);ObjectSetInteger(0,nlt,OBJPROP_STYLE,STYLE_DASH);ObjectSetInteger(0,nlt,OBJPROP_RAY_RIGHT,false);ObjectSetInteger(0,nlt,OBJPROP_SELECTABLE,false);ObjectSetInteger(0,nlt,OBJPROP_HIDDEN,false);ObjectSetInteger(0,nlt,OBJPROP_BACK,false);}
      if(ObjectFind(0,nll)>=0) ObjectDelete(0,nll);
      if(ObjectCreate(0,nll,OBJ_TEXT,0,now,g_liq.equalLowLevel-zw))
      {ObjectSetString(0,nll,OBJPROP_TEXT,g_liq.sweepDownDetected?"EQL SWEPT":"EQL LIQ");ObjectSetInteger(0,nll,OBJPROP_COLOR,zc);ObjectSetInteger(0,nll,OBJPROP_FONTSIZE,8);ObjectSetString(0,nll,OBJPROP_FONT,"Arial Bold");ObjectSetInteger(0,nll,OBJPROP_SELECTABLE,false);ObjectSetInteger(0,nll,OBJPROP_HIDDEN,false);ObjectSetInteger(0,nll,OBJPROP_BACK,false);ObjectSetInteger(0,nll,OBJPROP_ANCHOR,ANCHOR_RIGHT_UPPER);}
   }
   else
   { if(ObjectFind(0,nl)>=0)ObjectDelete(0,nl); if(ObjectFind(0,nlt)>=0)ObjectDelete(0,nlt); if(ObjectFind(0,nll)>=0)ObjectDelete(0,nll); }
}

void DrawEntryMarker(ENUM_DIRECTION dir,double price,ENUM_STRATEGY strat)
{
   if(!InpDrawSignalMarkers) return;
   datetime t=TimeCurrent();
   string nm=OV+"EN_"+(string)(int)t;
   color ac=(dir==DIR_LONG)?C_GREEN:C_RED;
   int code=(dir==DIR_LONG)?233:234;
   if(ObjectFind(0,nm)>=0) ObjectDelete(0,nm);
   if(ObjectCreate(0,nm,OBJ_ARROW,0,t,price))
   {ObjectSetInteger(0,nm,OBJPROP_ARROWCODE,code);ObjectSetInteger(0,nm,OBJPROP_COLOR,ac);ObjectSetInteger(0,nm,OBJPROP_WIDTH,3);ObjectSetInteger(0,nm,OBJPROP_SELECTABLE,false);ObjectSetInteger(0,nm,OBJPROP_HIDDEN,false);ObjectSetInteger(0,nm,OBJPROP_BACK,false);ObjectSetInteger(0,nm,OBJPROP_ANCHOR,(dir==DIR_LONG)?ANCHOR_TOP:ANCHOR_BOTTOM);}
   double off=MathMax(g_vol.atrAvg*0.5,SymbolInfoDouble(_Symbol,SYMBOL_POINT)*200);
   string nl=nm+"L";
   if(ObjectFind(0,nl)>=0) ObjectDelete(0,nl);
   if(ObjectCreate(0,nl,OBJ_TEXT,0,t,(dir==DIR_LONG)?price-off:price+off))
   {ObjectSetString(0,nl,OBJPROP_TEXT,StrategyToString(strat));ObjectSetInteger(0,nl,OBJPROP_COLOR,ac);ObjectSetInteger(0,nl,OBJPROP_FONTSIZE,8);ObjectSetString(0,nl,OBJPROP_FONT,"Arial Bold");ObjectSetInteger(0,nl,OBJPROP_SELECTABLE,false);ObjectSetInteger(0,nl,OBJPROP_HIDDEN,false);ObjectSetInteger(0,nl,OBJPROP_BACK,false);ObjectSetInteger(0,nl,OBJPROP_ANCHOR,ANCHOR_CENTER);}
}

void DrawExitMarker(double price,double pnl)
{
   if(!InpDrawSignalMarkers) return;
   datetime t=TimeCurrent();
   string nm=OV+"EX_"+(string)(int)t;
   color c=(pnl>=0)?C_CYAN:C_PURPLE;
   if(ObjectFind(0,nm)>=0) ObjectDelete(0,nm);
   if(ObjectCreate(0,nm,OBJ_ARROW,0,t,price))
   {ObjectSetInteger(0,nm,OBJPROP_ARROWCODE,251);ObjectSetInteger(0,nm,OBJPROP_COLOR,c);ObjectSetInteger(0,nm,OBJPROP_WIDTH,2);ObjectSetInteger(0,nm,OBJPROP_SELECTABLE,false);ObjectSetInteger(0,nm,OBJPROP_HIDDEN,false);ObjectSetInteger(0,nm,OBJPROP_BACK,false);}
   double off=MathMax(g_vol.atrAvg*0.4,SymbolInfoDouble(_Symbol,SYMBOL_POINT)*150);
   string nl=nm+"L";
   if(ObjectFind(0,nl)>=0) ObjectDelete(0,nl);
   if(ObjectCreate(0,nl,OBJ_TEXT,0,t,price+off))
   {ObjectSetString(0,nl,OBJPROP_TEXT,(pnl>=0?"+":"")+DoubleToString(pnl,2));ObjectSetInteger(0,nl,OBJPROP_COLOR,c);ObjectSetInteger(0,nl,OBJPROP_FONTSIZE,8);ObjectSetString(0,nl,OBJPROP_FONT,"Arial Bold");ObjectSetInteger(0,nl,OBJPROP_SELECTABLE,false);ObjectSetInteger(0,nl,OBJPROP_HIDDEN,false);ObjectSetInteger(0,nl,OBJPROP_BACK,false);ObjectSetInteger(0,nl,OBJPROP_ANCHOR,ANCHOR_CENTER);}
}

void UpdateVisualOverlays(){ UpdateSessionBoxes(); UpdateLiquidityZones(); }
void DeleteVisualOverlays(){ ObjectsDeleteAll(0,OV); ChartRedraw(0); }