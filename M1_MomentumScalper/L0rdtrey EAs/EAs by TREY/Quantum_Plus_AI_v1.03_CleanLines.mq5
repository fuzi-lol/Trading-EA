//+------------------------------------------------------------------+
//|                                          QUANTUM PLUS AI v1.01    |
//|        Institutional-Grade Adaptive Multi-Regime Trading System  |
//|        Compact Dashboard Edition - Optimized for Screen Fit      |
//+------------------------------------------------------------------+
#property copyright   "Quantum Plus AI v1.01 - Compact Edition"
#property version     "1.01"
#property description "Institutional multi-regime adaptive EA with compact dashboard"
#property strict

#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>
#include <Trade\AccountInfo.mqh>
#include <Trade\OrderInfo.mqh>

#define D "QPA_"   

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
//  ACCOUNT TIER ADAPTIVE ENGINE
//  The EA classifies the account by equity size and applies a
//  completely different risk / ATR-stop profile per tier so that a
//  $20 account, a $100 account, a $1000 account and a $10000+ account
//  are each traded with parameters appropriate to their size.
//=====================================================================
enum ENUM_ACC_TIER
{
   ACC_TIER_MICRO,         // <= 50
   ACC_TIER_SMALL,         // <= 200
   ACC_TIER_MEDIUM,        // <= 2000
   ACC_TIER_LARGE,         // <= 10000
   ACC_TIER_INSTITUTIONAL  // > 10000
};

struct AccountTierConfig
{
   string   name;
   double   riskMultiplier;      // multiplies InpRiskPercentPerTrade
   double   maxRiskCapPct;       // hard ceiling for this tier regardless of input
   double   slATRMultiplier;     // ATR multiple used for SL distance
   double   tpATRMultiplier;     // ATR multiple used for TP distance (R:R baseline)
   double   minLotRiskTolerance; // how far above target risk% we tolerate when broker forces min lot
   int      maxConcurrentTrades; // tier-specific concurrency cap
};

AccountTierConfig  g_tierCfg;
ENUM_ACC_TIER      g_accTier = ACC_TIER_SMALL;
double             g_lastTierEquity = 0.0;

string AccTierToString(ENUM_ACC_TIER t)
{
   switch(t)
   {
      case ACC_TIER_MICRO:         return "MICRO";
      case ACC_TIER_SMALL:         return "SMALL";
      case ACC_TIER_MEDIUM:        return "MEDIUM";
      case ACC_TIER_LARGE:         return "LARGE";
      case ACC_TIER_INSTITUTIONAL: return "INSTITUTIONAL";
      default:                     return "UNKNOWN";
   }
}

// Re-evaluates which tier the account belongs to and loads that
// tier's risk / ATR-stop profile. Designed so behaviour scales
// smoothly: small accounts get tighter stops (to keep $ loss small
// against likely broker-minimum lot constraints) and proportionally
// wider take-profits (to compensate with bigger R multiples), while
// larger accounts get wider ATR stops (less noise-stopped) and can
// run more concurrent trades with a lower risk-multiplier per trade.
void UpdateAccountTier()
{
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   if(equity <= 0) equity = AccountInfoDouble(ACCOUNT_BALANCE);
   g_lastTierEquity = equity;

   if(equity <= 50.0)        g_accTier = ACC_TIER_MICRO;
   else if(equity <= 200.0)  g_accTier = ACC_TIER_SMALL;
   else if(equity <= 2000.0) g_accTier = ACC_TIER_MEDIUM;
   else if(equity <= 10000.0)g_accTier = ACC_TIER_LARGE;
   else                      g_accTier = ACC_TIER_INSTITUTIONAL;

   switch(g_accTier)
   {
      case ACC_TIER_MICRO:
         // $0-50: capital is dominated by broker min-lot/min-spread cost.
         // Use tight ATR stops to cap $ risk, bigger R:R to offset the
         // higher relative risk forced by minimum lot sizes, and allow
         // only a single trade at a time.
         g_tierCfg.name                 = "MICRO";
         g_tierCfg.riskMultiplier        = 1.5;
         g_tierCfg.maxRiskCapPct         = 2.5;
         g_tierCfg.slATRMultiplier       = 1.0;
         g_tierCfg.tpATRMultiplier       = 2.0;
         g_tierCfg.minLotRiskTolerance   = 3.0;
         g_tierCfg.maxConcurrentTrades   = 1;
         break;
      case ACC_TIER_SMALL:
         // $50-200: still lot-size constrained but less severely.
         g_tierCfg.name                 = "SMALL";
         g_tierCfg.riskMultiplier        = 1.25;
         g_tierCfg.maxRiskCapPct         = 2.0;
         g_tierCfg.slATRMultiplier       = 1.2;
         g_tierCfg.tpATRMultiplier       = 2.2;
         g_tierCfg.minLotRiskTolerance   = 2.0;
         g_tierCfg.maxConcurrentTrades   = 1;
         break;
      case ACC_TIER_MEDIUM:
         // $200-2000: standard retail sizing, balanced ATR stops.
         g_tierCfg.name                 = "MEDIUM";
         g_tierCfg.riskMultiplier        = 1.0;
         g_tierCfg.maxRiskCapPct         = 1.25;
         g_tierCfg.slATRMultiplier       = 1.4;
         g_tierCfg.tpATRMultiplier       = 2.4;
         g_tierCfg.minLotRiskTolerance   = 1.5;
         g_tierCfg.maxConcurrentTrades   = 2;
         break;
      case ACC_TIER_LARGE:
         // $2000-10000: can absorb wider ATR stops, lower risk% per trade,
         // more concurrent diversification across signals.
         g_tierCfg.name                 = "LARGE";
         g_tierCfg.riskMultiplier        = 0.8;
         g_tierCfg.maxRiskCapPct         = 1.0;
         g_tierCfg.slATRMultiplier       = 1.6;
         g_tierCfg.tpATRMultiplier       = 2.6;
         g_tierCfg.minLotRiskTolerance   = 1.2;
         g_tierCfg.maxConcurrentTrades   = 3;
         break;
      default: // INSTITUTIONAL
         // >$10000: capital preservation prioritised, widest ATR stops
         // to ride out noise, smallest risk multiplier per trade.
         g_tierCfg.name                 = "INSTITUTIONAL";
         g_tierCfg.riskMultiplier        = 0.6;
         g_tierCfg.maxRiskCapPct         = 0.75;
         g_tierCfg.slATRMultiplier       = 1.9;
         g_tierCfg.tpATRMultiplier       = 3.2;
         g_tierCfg.minLotRiskTolerance   = 1.1;
         g_tierCfg.maxConcurrentTrades   = 5;
         break;
   }
}

// Rescales a strategy's suggested SL/TP so that absolute distance is
// driven by current ATR * tier multiplier, while preserving the
// strategy's original reward:risk ratio (so a Trend strategy still
// targets a bigger multiple than a Mean-Reversion strategy, just
// scaled to the account's tier).
void ApplyTierAdaptiveStops(StrategySignal &s)
{
   if(s.direction == DIR_NONE) return;

   double price = (s.direction == DIR_LONG) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double oldSLdist = MathAbs(price - s.suggestedSL);
   double oldTPdist = MathAbs(s.suggestedTP - price);
   double rr = (oldSLdist > 0) ? (oldTPdist / oldSLdist) : 1.6;
   rr = MathMax(1.2, MathMin(3.5, rr));

   double atr = (g_vol.atrCurrent > 0) ? g_vol.atrCurrent : g_vol.atrAvg;
   if(atr <= 0) return;

   double newSLdist = atr * g_tierCfg.slATRMultiplier;
   double newTPdist = atr * g_tierCfg.tpATRMultiplier * (rr / 1.6); // scale TP with strategy's own ambition

   if(s.direction == DIR_LONG)
   {
      s.suggestedSL = NPrice(price - newSLdist);
      s.suggestedTP = NPrice(price + newTPdist);
   }
   else
   {
      s.suggestedSL = NPrice(price + newSLdist);
      s.suggestedTP = NPrice(price - newTPdist);
   }
}

//=====================================================================
//  INPUT PARAMETERS
//=====================================================================

input group "╔══════  IDENTITY  ══════╗"
input ulong    InpMagicNumber          = 778800;
input string   InpBotName              = "QUANTUM PLUS AI";

input group "╔══════  RISK GOVERNANCE  ══════╗"
input double   InpRiskPercentPerTrade  = 0.5;     
input double   InpMaxRiskPercentTrade  = 1.0;     
input double   InpMaxDailyLossPct      = 3.0;     
input double   InpMaxWeeklyLossPct     = 7.0;     
input double   InpMaxDrawdownPct       = 12.0;    
input int      InpMaxDailyTrades       = 8;
input int      InpMaxConcurrentTrades  = 1;       

input group "╔══════  EXECUTION QUALITY  ══════╗"
input double   InpMaxSpreadPoints      = 350;     
input double   InpMinExecutionScore    = 60.0;    
input int      InpCooldownAfterCloseSec= 30;

input group "╔══════  REGIME DETECTION  ══════╗"
input int      InpATRPeriod            = 14;
input int      InpATRLookback          = 100;     
input int      InpEMAFastPeriod        = 8;
input int      InpEMASlowPeriod        = 34;
input int      InpStructureLookback    = 20;      
input double   InpMinRegimeConfidence  = 55.0;    

input group "╔══════  LIQUIDITY ENGINE  ══════╗"
input double   InpEqualLevelTolerance  = 0.15;    
input int      InpLiquidityLookback    = 40;

input group "╔══════  NEWS SHOCK PROXY  ══════╗"
input double   InpShockATRMultiple     = 2.5;     
input double   InpShockSpreadMultiple  = 2.0;     

input group "╔══════  STRATEGY HEALTH  ══════╗"
input int      InpHealthMinTrades      = 8;        
input int      InpHealthDegradeConsecLoss = 4;     
input double   InpHealthMinExpectancyR = -0.10;    

input group "╔══════  ADAPTIVE PARAMETERS  ══════╗"
input bool     InpEnableAdaptiveParams = true;
input double   InpAdaptiveBoundPct     = 20.0;     

input group "╔══════  SESSION CONFIGURATION  ══════╗"
input int      InpBrokerGMTOffset      = 2;        

input group "╔══════  DASHBOARD  ══════╗"
input bool     InpShowDash             = true;
input int      InpDashX                = 10;
input int      InpDashY                = 10;

input group "╔══════  VISUAL INTELLIGENCE OVERLAYS  ══════╗"
input bool     InpDrawSessionBoxes     = true;     // session H/L reference lines
input bool     InpDrawLiquidityZones   = true;     // EQH/EQL liquidity lines
input bool     InpDrawSignalMarkers    = true;
input int      InpSessionBoxLookbackHrs= 24;        // kept for compatibility, unused by line-based overlay

//=====================================================================
//  COLOR PALETTE
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
//  INDICATOR HANDLES
//=====================================================================
int  g_h1_ema_fast, g_h1_ema_slow, g_h1_atr;
int  g_m15_ema_fast, g_m15_ema_slow, g_m15_atr, g_m15_rsi;
int  g_m5_ema_fast, g_m5_ema_slow, g_m5_atr, g_m5_rsi;
int  g_m1_ema_fast, g_m1_ema_slow, g_m1_atr;

//=====================================================================
//  STATE CONTAINERS 
//=====================================================================
RegimeState       g_regime;
VolatilityState   g_vol;
LiquidityState    g_liq;
SessionState      g_session;
MTFBias           g_mtf;
ENUM_NEWS_STATE   g_newsState = NEWS_NORMAL;
RiskState         g_risk;
MasterDecision    g_lastDecision;

StrategyHealth    g_health[5];   

ExecutionQuality  g_execQuality;

//=====================================================================
//  SESSION / DAY TRACKING
//=====================================================================
datetime    g_dayStart       = 0;
datetime    g_weekStart      = 0;
int         g_tradesToday    = 0;
datetime    g_lastCloseTime  = 0;
bool        g_inCooldown     = false;
int         g_cooldownLeft   = 0;
datetime    g_lastFullUpdate = 0;
datetime    g_lastBarTime    = 0;

//=====================================================================
//  ADAPTIVE PARAMETER STATE 
//=====================================================================
double      g_adaptiveRegimeConfThreshold;  
double      g_adaptiveExecScoreThreshold;   

//=====================================================================
//  DASHBOARD / STATUS
//=====================================================================
string      g_statusText  = "INITIALIZING";
color       g_statusColor = C_ORANGE;
string      g_lastAction  = "Starting up...";

//=====================================================================
//  PERFORMANCE ANALYTICS 
//=====================================================================
double      g_sessionProfit   = 0.0;
int         g_sessionWins     = 0;
int         g_sessionLosses   = 0;
double      g_equityPeak      = 0.0;

//=====================================================================
//  COMPACT DASHBOARD CONSTANTS
//=====================================================================
const int   DW = 360;  // Reduced from 460
const int   DH = 740;  // increased to fit Risk Profile / Tier panel

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

bool IsNewBar()
{
   datetime currentBarTime = iTime(_Symbol, PERIOD_M5, 0);
   if(currentBarTime != g_lastBarTime)
   {
      g_lastBarTime = currentBarTime;
      return true;
   }
   return false;
}

//=====================================================================
//  SESSION INTELLIGENCE ENGINE  
//=====================================================================
ENUM_SESSION ClassifySession(datetime ts)
{
   MqlDateTime d; 
   TimeToStruct(ts, d);
   int hour = d.hour;
   
   hour = (hour - InpBrokerGMTOffset + 24) % 24;

   if(hour >= 0  && hour < 7)   return SESSION_ASIAN;
   if(hour >= 7  && hour < 10)  return SESSION_LONDON_OPEN;
   if(hour >= 10 && hour < 12)  return SESSION_LONDON_MID;
   if(hour >= 12 && hour < 15)  return SESSION_NY_OPEN;
   if(hour >= 15 && hour < 21)  return SESSION_NY_PM;
   return SESSION_DEAD_ZONE; 
}

void UpdateSessionIntelligence()
{
   g_session.current = ClassifySession(TimeCurrent());

   double atrM5[1];
   if(CopyBuffer(g_m5_atr, 0, 0, 1, atrM5) <= 0) atrM5[0] = 0.0001;

   double sessionHigh = iHigh(_Symbol, PERIOD_M5, 0);
   double sessionLow   = iLow(_Symbol, PERIOD_M5, 0);
   int barsBack = 12; 
   
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

   switch(g_session.current)
   {
      case SESSION_ASIAN:
         g_session.preferredStrategy = STRAT_MEAN_REVERSION;
         g_session.strategyWeight    = 1.1;   
         break;
      case SESSION_LONDON_OPEN:
         g_session.preferredStrategy = STRAT_VOLATILITY_EXPANSION;
         g_session.strategyWeight    = 1.3;   
         break;
      case SESSION_LONDON_MID:
         g_session.preferredStrategy = STRAT_TREND_SCALPER;
         g_session.strategyWeight    = 1.0;
         break;
      case SESSION_NY_OPEN:
         g_session.preferredStrategy = STRAT_LIQUIDITY_REVERSAL;
         g_session.strategyWeight    = 1.25;  
         break;
      case SESSION_NY_PM:
         g_session.preferredStrategy = STRAT_TREND_SCALPER;
         g_session.strategyWeight    = 0.9;
         break;
      default: 
         g_session.preferredStrategy = STRAT_NONE;
         g_session.strategyWeight    = 0.5;   
         break;
   }
}

//=====================================================================
//  MARKET INTELLIGENCE ENGINE  
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
   
   g_mtf.alignment = (nonzero > 1) ? (100.0 * (double)(agree + 1) / (double)nonzero) : (nonzero == 1 ? 50.0 : 0.0);
}

//=====================================================================
//  SWING / STRUCTURE HELPERS  
//=====================================================================
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

int FindSwingHighs(int lookback, int wing, double &outPrices[], datetime &outTimes[])
{
   int count = 0;
   int maxCount = ArraySize(outPrices);
   
   for(int i = wing; i < lookback - wing && count < maxCount; i++)
   {
      double h = iHigh(_Symbol, PERIOD_M5, i);
      bool isSwing = true;
      
      for(int w = 1; w <= wing; w++)
      {
         if(iHigh(_Symbol, PERIOD_M5, i-w) >= h || iHigh(_Symbol, PERIOD_M5, i+w) >= h)
         { 
            isSwing = false; 
            break; 
         }
      }
      
      if(isSwing)
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
   int maxCount = ArraySize(outPrices);
   
   for(int i = wing; i < lookback - wing && count < maxCount; i++)
   {
      double l = iLow(_Symbol, PERIOD_M5, i);
      bool isSwing = true;
      
      for(int w = 1; w <= wing; w++)
      {
         if(iLow(_Symbol, PERIOD_M5, i-w) <= l || iLow(_Symbol, PERIOD_M5, i+w) <= l)
         { 
            isSwing = false; 
            break; 
         }
      }
      
      if(isSwing)
      {
         outPrices[count] = l;
         outTimes[count]  = iTime(_Symbol, PERIOD_M5, i);
         count++;
      }
   }
   return count;
}

//=====================================================================
//  VOLATILITY INTELLIGENCE ENGINE  
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
      g_vol.atrCurrent = 0.0001;
      g_vol.atrAvg = 0.0001;
      g_vol.atrRatio = 1.0;
      return;
   }

   double current = atrBuf[0];
   double sum = 0;
   int n = 0;
   for(int i = 0; i < got; i++) { sum += atrBuf[i]; n++; }
   double avg = (n > 0) ? sum / n : current;
   if(avg <= 0) avg = 0.0001;

   g_vol.atrCurrent = current;
   g_vol.atrAvg     = avg;
   g_vol.atrRatio   = (avg > 0) ? current / avg : 1.0;

   int below = 0;
   for(int i = 0; i < got; i++) if(atrBuf[i] <= current) below++;
   g_vol.percentile = (got > 0) ? (100.0 * below / got) : 50.0;

   if(g_vol.percentile < 25)       g_vol.state = VOL_LOW;
   else if(g_vol.percentile < 65)  g_vol.state = VOL_NORMAL;
   else if(g_vol.percentile < 90)  g_vol.state = VOL_HIGH;
   else                            g_vol.state = VOL_EXTREME;

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
//  NEWS SHOCK PROXY SYSTEM  
//=====================================================================
double g_spreadHistory[20];
int    g_spreadHistCount = 0;

void UpdateNewsShockProxy()
{
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
   if(spreadAvg <= 0) spreadAvg = 1;
   
   double spreadRatio = (spreadAvg > 0) ? spreadNow / spreadAvg : 1.0;

   double barRange = iHigh(_Symbol, PERIOD_M5, 0) - iLow(_Symbol, PERIOD_M5, 0);
   double atrRatioForBar = (g_vol.atrAvg > 0) ? barRange / g_vol.atrAvg : 1.0;

   bool atrShock    = g_vol.atrRatio    >= InpShockATRMultiple;
   bool spreadShock = spreadRatio       >= InpShockSpreadMultiple;
   bool barShock    = atrRatioForBar    >= InpShockATRMultiple;

   int shockSignals = (atrShock ? 1 : 0) + (spreadShock ? 1 : 0) + (barShock ? 1 : 0);

   if(shockSignals >= 2)
      g_newsState = NEWS_SHOCK;
   else if(shockSignals == 1)
      g_newsState = NEWS_CAUTION;
   else
      g_newsState = NEWS_NORMAL;
}

//=====================================================================
//  LIQUIDITY INTELLIGENCE ENGINE  
//=====================================================================
void UpdateLiquidityIntelligence()
{
   double swingHighPrices[30];
   datetime swingHighTimes[30];
   double swingLowPrices[30];
   datetime swingLowTimes[30];

   int nHighs = FindSwingHighs(MathMin(InpLiquidityLookback, 60), 2, swingHighPrices, swingHighTimes);
   int nLows  = FindSwingLows(MathMin(InpLiquidityLookback, 60), 2, swingLowPrices, swingLowTimes);

   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   double price  = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double tolAbs = price * (InpEqualLevelTolerance / 100.0);

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

   double distToHigh = g_liq.equalHighsDetected ? MathAbs(price - g_liq.equalHighLevel) : -1;
   double distToLow  = g_liq.equalLowsDetected  ? MathAbs(price - g_liq.equalLowLevel)  : -1;

   double proximityScore = 0;
   if(distToHigh >= 0 && g_vol.atrAvg > 0)
      proximityScore = MathMax(proximityScore, 100.0 * MathMax(0.0, 1.0 - distToHigh / (g_vol.atrAvg * 1.5)));
   if(distToLow >= 0 && g_vol.atrAvg > 0)
      proximityScore = MathMax(proximityScore, 100.0 * MathMax(0.0, 1.0 - distToLow / (g_vol.atrAvg * 1.5)));

   g_liq.sweepProbability = MathMin(100.0, proximityScore);

   double bias = 0;
   if(distToHigh >= 0 && distToLow >= 0)
      bias = (distToLow < distToHigh) ? -40.0 : 40.0; 
   else if(distToHigh >= 0) bias = 40.0;
   else if(distToLow >= 0)  bias = -40.0;

   if(g_liq.sweepUpDetected)   bias = -70.0; 
   if(g_liq.sweepDownDetected) bias = 70.0;  

   g_liq.biasScore = bias;

   g_liq.pressureScore = MathMin(100.0, (bestHighClusterCount + bestLowClusterCount) * 12.0 + (g_liq.sweepProbability * 0.3));

   double poolAsym = MathAbs((double)bestHighClusterCount - (double)bestLowClusterCount);
   g_liq.imbalanceScore = MathMin(100.0, poolAsym * 20.0);
}

//=====================================================================
//  REGIME CLASSIFICATION ENGINE  
//=====================================================================
double g_regimeStreakBars = 0;
ENUM_REGIME g_regimePersistTrack = REGIME_RANGING;

double ScoreTrending()
{
   double score = 0;
   score += g_mtf.alignment * 0.5;
   if(g_mtf.m5Bias != 0 && g_mtf.m5Bias == g_mtf.h1Bias) score += 20;
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
   double rsiM5[1];
   if(CopyBuffer(g_m5_rsi, 0, 0, 1, rsiM5) > 0)
   {
      if(rsiM5[0] > 72 || rsiM5[0] < 28) score += 35;
   }
   if(g_vol.dynamic == VOLDYN_COMPRESSING && g_vol.atrRatio < 0.85) score += 25;
   if(g_mtf.m1Bias != 0 && g_mtf.m5Bias != 0 && g_mtf.m1Bias != g_mtf.m5Bias) score += 20; 
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

   int bestIdx = 0;
   double bestScore = scores[0];
   for(int i = 1; i < 10; i++)
   {
      if(scores[i] > bestScore) { bestScore = scores[i]; bestIdx = i; }
   }
   if(scores[9] >= 55.0) { bestIdx = 9; bestScore = scores[9]; }

   ENUM_REGIME newRegime = candidates[bestIdx];

   if(newRegime == g_regimePersistTrack) 
      g_regimeStreakBars++;
   else
   {
      g_regimeStreakBars = 0;
      g_regimePersistTrack = newRegime;
      g_regime.sinceTime = TimeCurrent();
      g_regime.previousRegime = g_regime.regime;
   }

   g_regime.regime      = newRegime;
   g_regime.confidence  = bestScore;
   g_regime.stability   = MathMin(100.0, g_regimeStreakBars * 8.0);
}

string RegimeToString(ENUM_REGIME r)
{
   switch(r)
   {
      case REGIME_TRENDING:         return "TREND";
      case REGIME_RANGING:          return "RANGE";
      case REGIME_BREAKOUT:         return "BREAKOUT";
      case REGIME_COMPRESSION:      return "COMPRESS";
      case REGIME_EXPANSION:        return "EXPAND";
      case REGIME_VOLATILITY_SHOCK: return "SHOCK";
      case REGIME_LIQUIDITY_SWEEP:  return "SWEEP";
      case REGIME_EXHAUSTION:       return "EXHAUST";
      case REGIME_MEAN_REVERSION:   return "REVERT";
      case REGIME_UNSAFE:           return "UNSAFE";
      default:                      return "UNKNOWN";
   }
}

//=====================================================================
//  STRATEGY MODULES  
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
   s.reason      = "Trend continuation: MTF " + DoubleToString(g_mtf.alignment,0) + "%";
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
   bool oversold   = rsiM5[0] < 30;
   if(!overbought && !oversold) { s.reason = "RSI not extended"; return s; }

   double hh = StructureHighestHigh(InpStructureLookback);
   double ll = StructureLowestLow(InpStructureLookback);
   double mid = (hh + ll) / 2.0;
   double atr = g_vol.atrCurrent;

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
   s.reason     = "Mean rev: RSI " + DoubleToString(rsiM5[0],1);
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

   if(g_vol.dynamic != VOLDYN_EXPANDING) { s.reason = "Not expanding"; return s; }

   double hh = StructureHighestHigh(InpStructureLookback, 1);
   double ll = StructureLowestLow(InpStructureLookback, 1);
   double price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double atr = g_vol.atrCurrent;

   bool brokeUp   = price > hh;
   bool brokeDown = price < ll;
   if(!brokeUp && !brokeDown) { s.reason = "No break yet"; return s; }

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
   s.reason     = "Vol expansion ATR " + DoubleToString(g_vol.atrRatio,2);
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

   if(!g_liq.sweepUpDetected && !g_liq.sweepDownDetected) { s.reason = "No sweep"; return s; }

   double atr = g_vol.atrCurrent;

   if(g_liq.sweepUpDetected)
   {
      double entryPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      s.direction   = DIR_SHORT;
      s.suggestedSL = NPrice(g_liq.equalHighLevel + atr * 0.3);
      s.suggestedTP = NPrice(entryPrice - atr * 2.2);
   }
   else 
   {
      double entryPrice = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      s.direction   = DIR_LONG;
      s.suggestedSL = NPrice(g_liq.equalLowLevel - atr * 0.3);
      s.suggestedTP = NPrice(entryPrice + atr * 2.2);
   }
   
   s.confidence = MathMin(93.0, g_liq.sweepProbability * 0.5 + g_liq.pressureScore * 0.4);
   s.reason     = "Liq sweep reversal";
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

   if(g_vol.state != VOL_LOW) { s.reason = "Not low vol"; return s; }
   if(g_mtf.m1Bias == 0) { s.reason = "No micro momentum"; return s; }

   double hh = StructureHighestHigh(InpStructureLookback / 2);
   double ll = StructureLowestLow(InpStructureLookback / 2);
   double price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double rangeSize = hh - ll;
   if(rangeSize <= 0) { s.reason = "Invalid range"; return s; }

   double posInRange = (price - ll) / rangeSize;

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
   else { s.reason = "Not at edge"; return s; }

   s.confidence = MathMin(88.0, 45.0 + (100.0 - g_vol.percentile) * 0.4);
   s.reason     = "Compression break";
   s.valid      = true;
   return s;
}

//=====================================================================
//  STRATEGY ROUTER  
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
      case REGIME_EXHAUSTION:       return STRAT_NONE; 
      case REGIME_VOLATILITY_SHOCK: return STRAT_NONE; 
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
      default: s.reason = "No strategy"; return s;
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
      case STRAT_VOLATILITY_EXPANSION: return "VolExpand";
      case STRAT_LIQUIDITY_REVERSAL:   return "LiqReversal";
      case STRAT_COMPRESSION_BREAKOUT: return "Compression";
      default:                         return "None";
   }
}

//=====================================================================
//  EXECUTION QUALITY ENGINE  
//=====================================================================
void UpdateExecutionQuality()
{
   double spread = (double)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);

   g_execQuality.spreadScore = MathMax(0.0, 100.0 * (1.0 - spread / InpMaxSpreadPoints));

   double slippageRisk = 0;
   if(g_newsState == NEWS_SHOCK)        slippageRisk = 90;
   else if(g_newsState == NEWS_CAUTION) slippageRisk = 50;
   else slippageRisk = MathMin(40.0, spread / InpMaxSpreadPoints * 40.0);
   g_execQuality.slippageRiskScore = 100.0 - slippageRisk;

   double volQuality = 100;
   if(g_vol.state == VOL_EXTREME)      volQuality = 20;
   else if(g_vol.state == VOL_HIGH)    volQuality = 65;
   else if(g_vol.state == VOL_LOW)     volQuality = 80; 
   else volQuality = 100;
   g_execQuality.volatilityQuality = volQuality;

   double liqQuality = 100;
   if(g_session.current == SESSION_DEAD_ZONE)      liqQuality = 35;
   else if(g_session.current == SESSION_ASIAN)     liqQuality = 70;
   else liqQuality = 95;
   g_execQuality.liquidityQuality = liqQuality;

   double efficiency = 100;
   if(g_vol.atrCurrent > 0)
   {
      double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
      double spreadInPrice = spread * point;
      double costRatio = spreadInPrice / g_vol.atrCurrent;
      efficiency = MathMax(0.0, 100.0 * (1.0 - costRatio * 5.0));
   }
   g_execQuality.efficiencyScore = efficiency;

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
      g_execQuality.rejectReason = "Spread too high";
   }
   else if(g_execQuality.compositeScore < g_adaptiveExecScoreThreshold)
   {
      g_execQuality.executionApproved = false;
      g_execQuality.rejectReason = "Low quality score";
   }
   else if(g_newsState == NEWS_SHOCK)
   {
      g_execQuality.executionApproved = false;
      g_execQuality.rejectReason = "News shock active";
   }
}

//=====================================================================
//  ADAPTIVE POSITION SIZING  
//=====================================================================
double CalculateAdaptiveLotSize(StrategySignal &signal, double slPrice, double &outRiskAmountUsed)
{
   outRiskAmountUsed = 0.0;
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   if(equity <= 0) return 0.0;

   double price = (signal.direction == DIR_LONG) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double slDistance = MathAbs(price - slPrice);
   if(slDistance <= 0) return 0.0;

   double confidenceFactor = MathMax(0.5, MathMin(1.0, signal.confidence / 100.0));

   double regimeFactor = MathMax(0.5, MathMin(1.0, (g_regime.confidence * 0.6 + g_regime.stability * 0.4) / 100.0));

   int hIdx = StrategyHealthIndex(signal.source);
   double healthFactor = 1.0;
   if(hIdx >= 0 && hIdx < 5) 
      healthFactor = g_health[hIdx].influenceMultiplier;

   double ddRatio = (InpMaxDrawdownPct > 0) ? (g_risk.currentDrawdownPct / InpMaxDrawdownPct) : 0.0;
   double drawdownFactor = MathMax(0.25, 1.0 - ddRatio); 

   // --- Account-tier adaptive risk% --------------------------------
   // The same InpRiskPercentPerTrade input produces a different
   // effective risk% depending on account size: tiny accounts get a
   // boosted multiplier (so they aren't permanently stuck on the
   // broker-minimum lot at near-zero risk), large accounts get a
   // reduced multiplier (capital preservation, smoother equity curve).
   double riskPct = InpRiskPercentPerTrade * g_tierCfg.riskMultiplier
                     * confidenceFactor * regimeFactor * healthFactor * drawdownFactor;

   double effectiveCap = MathMin(InpMaxRiskPercentTrade, g_tierCfg.maxRiskCapPct);
   riskPct = MathMin(riskPct, effectiveCap);

   double riskAmount = equity * (riskPct / 100.0);

   double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double tickSize  = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   if(tickValue <= 0 || tickSize <= 0) return 0.0;

   double valuePerPriceUnit = tickValue / tickSize;
   double lot = riskAmount / (slDistance * valuePerPriceUnit);

   double lotMin  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double lotMax  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);

   lot = MathFloor(lot / lotStep) * lotStep; 
   lot = MathMax(lotMin, MathMin(lotMax, lot));

   // --- Minimum-lot risk guard -------------------------------------
   // On very small accounts the broker's minimum tradable lot can
   // force a risk% far above what was intended. Each tier defines how
   // much overshoot it will tolerate (minLotRiskTolerance, expressed
   // as a multiple of the tier's risk cap). If even the minimum lot
   // would blow past that tolerance, the EA skips the trade instead
   // of taking on disproportionate risk.
   double actualRiskAmount = lot * slDistance * valuePerPriceUnit;
   double actualRiskPct = (equity > 0) ? (actualRiskAmount / equity * 100.0) : 0.0;

   if(lot <= lotMin && actualRiskPct > effectiveCap * g_tierCfg.minLotRiskTolerance)
      return 0.0;

   outRiskAmountUsed = actualRiskAmount;

   return lot;
}

//=====================================================================
//  RISK GOVERNANCE ENGINE  
//=====================================================================
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
   g_risk.currentDrawdownPct = 0.0;
   g_risk.maxDrawdownSeenPct = 0.0;
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
      g_risk.emergencyShutdown   = true; 
   }
}

bool RiskGovernanceAllowsNewTrade(string &rejectReason)
{
   if(g_risk.emergencyShutdown)
   {
      rejectReason = "Emergency shutdown";
      return false;
   }
   if(g_risk.dailyLimitHit)
   {
      rejectReason = "Daily limit hit";
      return false;
   }
   if(g_risk.weeklyLimitHit)
   {
      rejectReason = "Weekly limit hit";
      return false;
   }
   if(InpMaxDailyTrades > 0 && g_tradesToday >= InpMaxDailyTrades)
   {
      rejectReason = "Max trades today";
      return false;
   }
   if(PositionsTotalForMagic() >= MathMin(InpMaxConcurrentTrades, g_tierCfg.maxConcurrentTrades))
   {
      rejectReason = "Max positions";
      return false;
   }
   if(g_inCooldown)
   {
      rejectReason = "Cooldown active";
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
   }
   
   if(thisWeek != g_weekStart)
   {
      g_weekStart = thisWeek;
      g_risk.weekStartEquity = AccountInfoDouble(ACCOUNT_EQUITY);
      g_risk.weeklyLimitHit = false;
   }
}

//=====================================================================
//  STRATEGY HEALTH MONITOR  
//=====================================================================
void InitStrategyHealth()
{
   string names[5] = {"TrendScalp", "MeanRev", "VolExpand", "LiqReversal", "Compression"};
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

void RegisterTradeResult(ENUM_STRATEGY strat, double pnl, double rMultiple)
{
   int idx = StrategyHealthIndex(strat);
   if(idx < 0 || idx >= 5) return;

   StrategyHealth h = g_health[idx];
   h.totalTrades++;
   
   if(pnl >= 0) 
   { 
      h.wins++; 
      h.grossProfit += pnl; 
      h.consecLosses = 0; 
   }
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

void UpdateStrategyInfluence(int idx)
{
   if(idx < 0 || idx >= 5) return;
   StrategyHealth h = g_health[idx];

   if(h.totalTrades < InpHealthMinTrades)
   {
      g_health[idx].influenceMultiplier = 1.0; 
      return;
   }

   double targetMultiplier = 1.0;

   if(h.consecLosses >= InpHealthDegradeConsecLoss)
      targetMultiplier = MathMin(targetMultiplier, 0.5);

   if(h.expectancyR < InpHealthMinExpectancyR)
      targetMultiplier = MathMin(targetMultiplier, 0.4);

   if(h.profitFactor < 0.8 && h.totalTrades >= InpHealthMinTrades)
      targetMultiplier = MathMin(targetMultiplier, 0.6);

   if(h.consecLosses >= InpHealthDegradeConsecLoss * 2 || h.expectancyR < (InpHealthMinExpectancyR * 2.5))
   {
      g_health[idx].enabled = false;
      targetMultiplier = 0.0;
      g_health[idx].lastDegradedTime = TimeCurrent();
   }

   double current = g_health[idx].influenceMultiplier;
   g_health[idx].influenceMultiplier = current + (targetMultiplier - current) * 0.5;

   if(g_health[idx].influenceMultiplier > 0.7) g_health[idx].enabled = true;
}

//=====================================================================
//  ADAPTIVE PARAMETER ENGINE  
//=====================================================================
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
//  TRADE EXECUTION ENGINE  
//=====================================================================
string EncodePositionTag(ENUM_STRATEGY strat, double riskAmount)
{
   return InpBotName + "|" + IntegerToString((int)strat) + "|" + DoubleToString(riskAmount, 2);
}

bool DecodePositionTag(string comment, ENUM_STRATEGY &strat, double &riskAmount)
{
   string parts[];
   int n = StringSplit(comment, '|', parts);
   if(n < 3) return false;
   if(ArraySize(parts) < 3) return false;  
   
   strat = (ENUM_STRATEGY)StringToInteger(parts[1]);
   riskAmount = StringToDouble(parts[2]);
   return true;
}

bool ExecuteMasterDecision(MasterDecision &decision)
{
   if(!decision.tradeApproved || decision.direction == DIR_NONE) return false;

   double price = (decision.direction == DIR_LONG) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(price <= 0) return false;

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
      DrawEntryMarker(decision.direction, price, decision.strategySource);
   }
   
   return ok;
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
//  TRADE TRANSACTION HANDLER
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
   if(HistoryDealGetInteger(dealTicket, DEAL_ENTRY) != DEAL_ENTRY_OUT) return; 

   double pnl = HistoryDealGetDouble(dealTicket, DEAL_PROFIT)
              + HistoryDealGetDouble(dealTicket, DEAL_SWAP)
              + HistoryDealGetDouble(dealTicket, DEAL_COMMISSION);

   string comment = HistoryDealGetString(dealTicket, DEAL_COMMENT);

   ENUM_STRATEGY strat = STRAT_NONE;
   double riskAmount = 0;
   if(!DecodePositionTag(comment, strat, riskAmount))
   {
      return;
   }

   double rMultiple = (riskAmount > 0) ? (pnl / riskAmount) : 0.0;
   RegisterTradeResult(strat, pnl, rMultiple);

   g_sessionProfit += pnl;
   if(pnl >= 0) g_sessionWins++; else g_sessionLosses++;

   g_lastCloseTime = TimeCurrent();
   g_inCooldown    = true;
   g_cooldownLeft  = InpCooldownAfterCloseSec;

   double exitPrice = HistoryDealGetDouble(dealTicket, DEAL_PRICE);
   DrawExitMarker(exitPrice, pnl);

   Print("[QPA] Trade closed: ", StrategyToString(strat), " | P&L=", DoubleToString(pnl,2), " | R=", DoubleToString(rMultiple,2));
}

//=====================================================================
//  PERFORMANCE ANALYTICS ENGINE  
//=====================================================================
double TradeQualityScore()
{
   return MathMin(100.0, g_execQuality.compositeScore * 0.5 + g_regime.confidence * 0.5);
}

//=====================================================================
//  MASTER DECISION ENGINE  
//=====================================================================
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

   string rejectReason = "";
   if(!RiskGovernanceAllowsNewTrade(rejectReason))
   {
      d.narrative = rejectReason;
      return d;
   }

   if(g_regime.regime == REGIME_UNSAFE)
   {
      d.narrative = "Regime UNSAFE";
      return d;
   }
   
   if(g_regime.confidence < g_adaptiveRegimeConfThreshold)
   {
      d.narrative = "Low regime confidence";
      return d;
   }

   if(!g_execQuality.executionApproved)
   {
      d.narrative = g_execQuality.rejectReason;
      return d;
   }

   ENUM_STRATEGY routedStrat = RouteRegimeToStrategy(g_regime.regime);
   if(routedStrat == STRAT_NONE)
   {
      d.narrative = "No strategy for regime";
      return d;
   }

   int hIdx = StrategyHealthIndex(routedStrat);
   if(hIdx >= 0 && hIdx < 5 && !g_health[hIdx].enabled)
   {
      d.narrative = "Strategy disabled";
      return d;
   }

   StrategySignal signal = GetSignalForStrategy(routedStrat);
   if(!signal.valid)
   {
      d.narrative = signal.reason;
      return d;
   }

   double sessionAdjustedConfidence = signal.confidence;
   if(g_session.preferredStrategy == routedStrat)
      sessionAdjustedConfidence = MathMin(100.0, signal.confidence * g_session.strategyWeight);
   else
      sessionAdjustedConfidence = signal.confidence * 0.85; 

   if(sessionAdjustedConfidence < g_adaptiveRegimeConfThreshold)
   {
      d.narrative = "Session-adj confidence low";
      return d;
   }
   signal.confidence = sessionAdjustedConfidence;

   // Rescale SL/TP to the account-tier ATR profile (different stop/target
   // distances for a $20 account vs a $100 / $1000 / $10000+ account).
   ApplyTierAdaptiveStops(signal);

   double riskAmountUsed = 0.0;
   double lot = CalculateAdaptiveLotSize(signal, signal.suggestedSL, riskAmountUsed);
   if(lot <= 0)
   {
      d.narrative = "Invalid lot size";
      return d;
   }

   d.tradeApproved   = true;
   d.direction       = signal.direction;
   d.lotSize         = lot;
   d.slPrice         = signal.suggestedSL;
   d.tpPrice         = signal.suggestedTP;
   d.strategySource  = routedStrat;
   d.riskAmountUsed  = riskAmountUsed;
   d.narrative       = StrategyToString(routedStrat) + " | " + signal.reason;

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
//  VISUAL INTELLIGENCE OVERLAYS
//=====================================================================
#define OV "QPA_OV_"   

//=====================================================================
//  CLEAN INSTITUTIONAL LINE PALETTE
//  A deliberately small, restrained set of colors used ONLY for
//  on-chart analyst lines, so the price action stays readable instead
//  of being buried under filled, multi-colored boxes/zones.
//=====================================================================
#define C_LVL_SESSION    C'120,140,168'   // muted slate - prior session H/L
#define C_LVL_DAY        C'150,160,185'   // slightly brighter slate - daily H/L
#define C_LVL_LIQUIDITY  C'255,178,40'    // single amber - untouched liquidity pool
#define C_LVL_SWEPT      C'234,70,80'     // single red - liquidity already swept
#define C_LVL_ENTRY      C'235,240,250'   // near-white - entry
#define C_LVL_SL         C'234,62,72'     // red - stop loss
#define C_LVL_TP         C'24,222,118'    // green - take profit

void DrawSessionBox(string name, datetime startTime, datetime endTime, color boxColor)
{
   if(endTime <= startTime) return;

   double hi = -DBL_MAX, lo = DBL_MAX;
   int startBar = iBarShift(_Symbol, PERIOD_M5, startTime, false);
   int endBar   = iBarShift(_Symbol, PERIOD_M5, endTime, false);
   
   if(startBar < 0 || endBar < 0) return;
   if(endBar > startBar) { int tmp = startBar; startBar = endBar; endBar = tmp; } 

   for(int i = endBar; i <= startBar; i++)
   {
      double h = iHigh(_Symbol, PERIOD_M5, i);
      double l = iLow(_Symbol, PERIOD_M5, i);
      if(h > hi) hi = h;
      if(l < lo) lo = l;
   }
   
   if(hi <= -DBL_MAX || lo >= DBL_MAX) return;

   // Thin labeled lines instead of a filled box - keeps candles visible.
   DrawHLine(OV + name + "_H", hi, boxColor, name + " H " + DoubleToString(hi, (int)SymbolInfoInteger(_Symbol,SYMBOL_DIGITS)));
   DrawHLine(OV + name + "_L", lo, boxColor, name + " L " + DoubleToString(lo, (int)SymbolInfoInteger(_Symbol,SYMBOL_DIGITS)));
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

// Draws only TWO reference levels: the high/low of the CURRENTLY ACTIVE
// session, plus the high/low of the prior completed session for
// context. This is the minimum an institutional trader actually marks
// up live - everything else (5 sessions x 2 days of filled boxes) was
// just noise sitting on top of price.
void UpdateSessionBoxes()
{
   if(!InpDrawSessionBoxes) return;

   datetime now = TimeCurrent();
   datetime today = DayStart(now);

   ENUM_SESSION sessions[5] = {SESSION_ASIAN, SESSION_LONDON_OPEN, SESSION_LONDON_MID, SESSION_NY_OPEN, SESSION_NY_PM};
   string sessionLabels[5]  = {"ASIA", "LDN-O", "LDN-M", "NY-O", "NY-PM"};

   int curIdx = -1;
   for(int i = 0; i < 5; i++) if(sessions[i] == g_session.current) { curIdx = i; break; }
   if(curIdx < 0)
   {
      ObjectDelete(0, OV + "SESS_CUR_H");    ObjectDelete(0, OV + "SESS_CUR_H_lbl");
      ObjectDelete(0, OV + "SESS_CUR_L");    ObjectDelete(0, OV + "SESS_CUR_L_lbl");
      ObjectDelete(0, OV + "SESS_PREV_H");   ObjectDelete(0, OV + "SESS_PREV_H_lbl");
      ObjectDelete(0, OV + "SESS_PREV_L");   ObjectDelete(0, OV + "SESS_PREV_L_lbl");
      return;
   }
   int prevIdx = (curIdx + 4) % 5; // previous session, wrapping to yesterday's NY-PM if needed

   int sh, eh;
   SessionHourBand(sessions[curIdx], sh, eh);
   sh = (sh + InpBrokerGMTOffset) % 24;
   eh = (eh + InpBrokerGMTOffset) % 24;
   datetime curStart = today + sh * 3600;
   DrawSessionBox("SESS_CUR", curStart, now, C_LVL_SESSION);

   datetime prevDayBase = (prevIdx > curIdx) ? (today - 86400) : today;
   SessionHourBand(sessions[prevIdx], sh, eh);
   sh = (sh + InpBrokerGMTOffset) % 24;
   eh = (eh + InpBrokerGMTOffset) % 24;
   datetime prevStart = prevDayBase + sh * 3600;
   datetime prevEnd   = prevDayBase + eh * 3600;
   DrawSessionBox("SESS_PREV", prevStart, MathMin(prevEnd, now), C_LVL_SESSION);
}

// Equal-highs / equal-lows liquidity pools as single clean dashed
// lines (amber = untouched pool, red = already swept) instead of
// translucent filled rectangles smeared across the chart.
void UpdateLiquidityZones()
{
   if(!InpDrawLiquidityZones) return;

   string nameHigh = OV + "LIQ_EQH";
   string nameLow  = OV + "LIQ_EQL";
   int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);

   if(g_liq.equalHighsDetected)
   {
      color c = g_liq.sweepUpDetected ? C_LVL_SWEPT : C_LVL_LIQUIDITY;
      string tag = g_liq.sweepUpDetected ? "EQH SWEPT" : "EQH";
      DrawHLine(nameHigh, g_liq.equalHighLevel, c, tag + " " + DoubleToString(g_liq.equalHighLevel, digits));
   }
   else
   {
      ObjectDelete(0, nameHigh); ObjectDelete(0, nameHigh+"_lbl");
   }

   if(g_liq.equalLowsDetected)
   {
      color c = g_liq.sweepDownDetected ? C_LVL_SWEPT : C_LVL_LIQUIDITY;
      string tag = g_liq.sweepDownDetected ? "EQL SWEPT" : "EQL";
      DrawHLine(nameLow, g_liq.equalLowLevel, c, tag + " " + DoubleToString(g_liq.equalLowLevel, digits));
   }
   else
   {
      ObjectDelete(0, nameLow); ObjectDelete(0, nameLow+"_lbl");
   }
}

void DrawEntryMarker(ENUM_DIRECTION dir, double price, ENUM_STRATEGY strat)
{
   if(!InpDrawSignalMarkers) return;

   datetime t = TimeCurrent();
   string name = OV + "ENTRY_" + IntegerToString((int)t) + "_" + IntegerToString(MathRand());

   int arrowCode = (dir == DIR_LONG) ? 233 : 234; 
   color arrowColor = (dir == DIR_LONG) ? C_LVL_TP : C_LVL_SL;

   if(ObjectCreate(0, name, OBJ_ARROW, 0, t, price))
   {
      ObjectSetInteger(0, name, OBJPROP_ARROWCODE, arrowCode);
      ObjectSetInteger(0, name, OBJPROP_COLOR, arrowColor);
      ObjectSetInteger(0, name, OBJPROP_WIDTH, 2);
      ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
      ObjectSetInteger(0, name, OBJPROP_ANCHOR, (dir == DIR_LONG) ? ANCHOR_TOP : ANCHOR_BOTTOM);
   }

   string lblName = name + "_lbl";
   double offset = g_vol.atrAvg * 0.5;
   double lblPrice = (dir == DIR_LONG) ? price - offset : price + offset;
   
   if(ObjectCreate(0, lblName, OBJ_TEXT, 0, t, lblPrice))
   {
      ObjectSetString(0, lblName, OBJPROP_TEXT, StrategyToString(strat));
      ObjectSetInteger(0, lblName, OBJPROP_COLOR, arrowColor);
      ObjectSetInteger(0, lblName, OBJPROP_FONTSIZE, 6);
      ObjectSetInteger(0, lblName, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, lblName, OBJPROP_HIDDEN, true);
   }
}

void DrawExitMarker(double price, double pnl)
{
   if(!InpDrawSignalMarkers) return;

   datetime t = TimeCurrent();
   string name = OV + "EXIT_" + IntegerToString((int)t) + "_" + IntegerToString(MathRand());

   // Same two-color win/loss convention as everywhere else on the
   // chart (green = good, red = bad) instead of a third cyan/purple pair.
   color markColor = (pnl >= 0) ? C_LVL_TP : C_LVL_SL;

   if(ObjectCreate(0, name, OBJ_ARROW, 0, t, price))
   {
      ObjectSetInteger(0, name, OBJPROP_ARROWCODE, 251); 
      ObjectSetInteger(0, name, OBJPROP_COLOR, markColor);
      ObjectSetInteger(0, name, OBJPROP_WIDTH, 2);
      ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
   }

   string lblName = name + "_lbl";
   if(ObjectCreate(0, lblName, OBJ_TEXT, 0, t, price))
   {
      ObjectSetString(0, lblName, OBJPROP_TEXT, (pnl >= 0 ? "+" : "") + DoubleToString(pnl,2));
      ObjectSetInteger(0, lblName, OBJPROP_COLOR, markColor);
      ObjectSetInteger(0, lblName, OBJPROP_FONTSIZE, 6);
      ObjectSetInteger(0, lblName, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, lblName, OBJPROP_HIDDEN, true);
   }
}

void UpdateVisualOverlays()
{
   UpdateSessionBoxes();
   UpdateLiquidityZones();
   DrawActiveRiskLevels();
   DrawMTFBiasPanel();
}

// Draws live SL / Entry / TP horizontal price lines plus an R-multiple
// label for the currently managed position(s) - the kind of "risk
// skeleton" an institutional discretionary trader keeps on their chart.
void DrawActiveRiskLevels()
{
   string slName    = OV + "RISK_SL";
   string tpName    = OV + "RISK_TP";
   string entryName = OV + "RISK_ENTRY";

   if(!HasManagedPosition())
   {
      ObjectDelete(0, slName);    ObjectDelete(0, slName+"_lbl");
      ObjectDelete(0, tpName);    ObjectDelete(0, tpName+"_lbl");
      ObjectDelete(0, entryName); ObjectDelete(0, entryName+"_lbl");
      return;
   }

   for(int i = PositionsTotal()-1; i >= 0; i--)
   {
      if(!(g_pos.SelectByIndex(i) && g_pos.Magic() == InpMagicNumber && g_pos.Symbol() == _Symbol)) continue;

      double entry = g_pos.PriceOpen();
      double sl    = g_pos.StopLoss();
      double tp    = g_pos.TakeProfit();
      double cur   = g_pos.PriceCurrent();

      DrawHLine(entryName, entry, C_LVL_ENTRY, "ENTRY " + DoubleToString(entry, (int)SymbolInfoInteger(_Symbol,SYMBOL_DIGITS)));
      if(sl > 0)
      {
         double rDist = MathAbs(entry - sl);
         double curR  = (rDist > 0) ? (cur - entry) / rDist * ((g_pos.PositionType()==POSITION_TYPE_BUY)?1:-1) : 0.0;
         DrawHLine(slName, sl, C_LVL_SL, "SL " + DoubleToString(sl,(int)SymbolInfoInteger(_Symbol,SYMBOL_DIGITS)) + "  (" + DoubleToString(curR,2) + "R)");
      }
      if(tp > 0)
         DrawHLine(tpName, tp, C_LVL_TP, "TP " + DoubleToString(tp,(int)SymbolInfoInteger(_Symbol,SYMBOL_DIGITS)));

      break; // one managed position expected per InpMaxConcurrentTrades==1 tiers; draws first found otherwise
   }
}

void DrawHLine(string name, double price, color clr, string label)
{
   ObjectDelete(0, name);
   if(ObjectCreate(0, name, OBJ_HLINE, 0, 0, price))
   {
      ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
      ObjectSetInteger(0, name, OBJPROP_STYLE, STYLE_DASH);
      ObjectSetInteger(0, name, OBJPROP_WIDTH, 1);
      ObjectSetInteger(0, name, OBJPROP_BACK, true);
      ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
   }

   string lblName = name + "_lbl";
   ObjectDelete(0, lblName);
   if(ObjectCreate(0, lblName, OBJ_TEXT, 0, TimeCurrent() + PeriodSeconds(PERIOD_M5)*3, price))
   {
      ObjectSetString(0, lblName, OBJPROP_TEXT, label);
      ObjectSetInteger(0, lblName, OBJPROP_COLOR, clr);
      ObjectSetInteger(0, lblName, OBJPROP_FONTSIZE, 7);
      ObjectSetInteger(0, lblName, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, lblName, OBJPROP_HIDDEN, true);
   }
}

// Compact on-chart "analyst readout" near the current price: regime,
// confidence, MTF bias stack (H1/M15/M5/M1) and account tier - the
// kind of annotation an experienced discretionary/institutional
// trader would scribble on their own chart.
void DrawMTFBiasPanel()
{
   string name = OV + "ANALYST_PANEL";
   ObjectDelete(0, name);

   string arrowH1  = (g_mtf.h1Bias  > 0) ? "H1▲"  : (g_mtf.h1Bias  < 0 ? "H1▼"  : "H1•");
   string arrowM15 = (g_mtf.m15Bias > 0) ? "M15▲" : (g_mtf.m15Bias < 0 ? "M15▼" : "M15•");
   string arrowM5  = (g_mtf.m5Bias  > 0) ? "M5▲"  : (g_mtf.m5Bias  < 0 ? "M5▼"  : "M5•");
   string arrowM1  = (g_mtf.m1Bias  > 0) ? "M1▲"  : (g_mtf.m1Bias  < 0 ? "M1▼"  : "M1•");

   string text = StringFormat("%s | %s conf %.0f%% | %s %s %s %s | ATR x%.2f | %s acct",
                  _Symbol, RegimeToString(g_regime.regime), g_regime.confidence,
                  arrowH1, arrowM15, arrowM5, arrowM1, g_tierCfg.slATRMultiplier, g_tierCfg.name);

   double price = SymbolInfoDouble(_Symbol, SYMBOL_BID) + g_vol.atrAvg * 1.2;
   if(ObjectCreate(0, name, OBJ_TEXT, 0, TimeCurrent(), price))
   {
      ObjectSetString(0, name, OBJPROP_TEXT, text);
      ObjectSetInteger(0, name, OBJPROP_COLOR, C_GOLD);
      ObjectSetInteger(0, name, OBJPROP_FONTSIZE, 8);
      ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
      ObjectSetInteger(0, name, OBJPROP_ANCHOR, ANCHOR_LEFT_LOWER);
   }
}

void DeleteVisualOverlays()
{
   ObjectsDeleteAll(0, OV);
}

//=====================================================================
//  COMPACT INSTITUTIONAL DASHBOARD  
//=====================================================================
void R(string nm, int x, int y, int w, int h, color bg, color brd=clrNONE, int bw=1)
{
   string n = D + nm;
   ObjectDelete(0, n);
   
   if(ObjectCreate(0, n, OBJ_RECTANGLE_LABEL, 0, 0, 0))
   {
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
      else 
         ObjectSetInteger(0, n, OBJPROP_BORDER_TYPE, BORDER_RAISED);
         
      ObjectSetInteger(0, n, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, n, OBJPROP_HIDDEN, true);
   }
}

void L(string nm, int x, int y, string txt, color clr, int fsz, string fnt="Arial")
{
   string n = D + nm;
   ObjectDelete(0, n);
   
   if(ObjectCreate(0, n, OBJ_LABEL, 0, 0, 0))
   {
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

void InitDash()
{
   if(MQLInfoInteger(MQL_TESTER) && !MQLInfoInteger(MQL_VISUAL_MODE)) 
   {
      Print("Dashboard disabled in non-visual tester");
      return;
   }

   int X = InpDashX, Y = InpDashY;

   // Outer frame
   R("frame_outer", X, Y, DW, DH, C_BG0, C_ACBORD, 2);
   R("frame_inner", X+2, Y+2, DW-4, DH-4, C_BG0, C_BORDER, 1);

   // Compact AI Engine visual (reduced from 220 to 140)
   int ringPanelH = 140;
   R("ring_panel", X+2, Y+2, DW-4, ringPanelH, C_HDRBAR, C_ACBORD, 1);
   L("ring_title", X+8, Y+6, "AI ENGINE", C_CYAN, 7, "Arial Black");

   int cx = X + DW/2;
   int cy = Y + 16 + (ringPanelH-22)/2;
   
   // Smaller rings
   for(int i = 0; i < 10; i++)
   {
      double angle = (2.0 * M_PI * i) / 10;
      int nx = cx + (int)(50 * MathCos(angle));
      int ny = cy + (int)(50 * MathSin(angle));
      R("ring_out_" + IntegerToString(i), nx-2, ny-2, 4, 4, C_LBLUE, clrNONE);
   }
   
   for(int i = 0; i < 8; i++)
   {
      double angle = (2.0 * M_PI * i) / 8;
      int nx = cx + (int)(35 * MathCos(angle));
      int ny = cy + (int)(35 * MathSin(angle));
      R("ring_mid_" + IntegerToString(i), nx-2, ny-2, 4, 4, C_GOLD, clrNONE);
   }
   
   R("ring_core", cx-10, cy-10, 20, 20, C_BG0, C_CYAN, 2);
   L("ring_core_lbl", cx-6, cy-4, "AI", C_WHITE, 7, "Arial Black");

   R("ring_div", X+2, Y+ringPanelH, DW-4, 2, C_ACBORD);

   // Market Info (compact)
   int yMI = Y + ringPanelH + 2;
   R("mi_hd", X+2, yMI, DW-4, 16, C_HDRBAR, C_BORDER, 1);
   L("mi_lb", X+8, yMI+2, "MARKET", C_GOLD, 6, "Arial Black");
   L("mi_time", X+DW-50, yMI+2, "--:--", C_SUBTEXT, 6, "Arial");

   R("mi_body", X+2, yMI+16, DW-4, 50, C_BG2, C_BORDER, 1);
   L("lb_bid", X+8, yMI+21, "Bid", C_SUBTEXT, 6, "Arial");
   L("vl_bid", X+40, yMI+21, "0.00", C_WHITE, 7, "Arial");
   L("lb_ask", X+180,yMI+21, "Ask", C_SUBTEXT, 6, "Arial");
   L("vl_ask", X+212,yMI+21, "0.00", C_WHITE, 7, "Arial");

   L("lb_spread", X+8, yMI+34, "Spread", C_SUBTEXT, 6, "Arial");
   L("vl_spread", X+50, yMI+34, "0", C_GREEN, 7, "Arial");
   L("lb_atr",    X+180,yMI+34, "ATR", C_SUBTEXT, 6, "Arial");
   L("vl_atr",    X+212,yMI+34, "0", C_WHITE, 7, "Arial");

   L("vl_sym", X+8, yMI+47, _Symbol, C_WHITE, 7, "Arial");
   L("vl_volgate", X+180,yMI+47, "VOL:--", C_GREEN, 6, "Arial");

   // Regime Signal (compact)
   int ySig = yMI + 68;
   R("sig_hd", X+2, ySig, DW-4, 16, C_ORANGE, C_BORDER, 1);
   L("sig_lb", X+8, ySig+2, "REGIME", C_BG0, 6, "Arial Black");

   R("sig_body", X+2, ySig+16, DW-4, 45, C_BG2, C_BORDER, 1);
   L("lb_ema", X+8, ySig+20, "EMA", C_SUBTEXT, 6, "Arial");
   L("vl_ema10", X+40, ySig+20, "0", C_WHITE, 7, "Arial");
   L("vl_ema30", X+140, ySig+20, "0", C_WHITE, 7, "Arial");

   L("lb_rsi",  X+8, ySig+33, "RSI", C_SUBTEXT, 6, "Arial");
   L("vl_rsi",  X+40, ySig+33, "50", C_WHITE, 7, "Arial");
   R("regime_tag", X+140, ySig+31, 80, 14, C_DGRAY, C_BORDER, 1);
   L("vl_regimetag", X+148, ySig+33, "RANGE", C_WHITE, 6, "Arial");

   R("decision_strip", X+2, ySig+63, DW-4, 16, C_DGRAY, C_BORDER, 1);
   L("vl_decision1", X+8, ySig+65, "Decision: HOLD", C_ORANGE, 6, "Arial Black");

   // Execution Intelligence (compact)
   int yAI = ySig + 81;
   R("ai_hd", X+2, yAI, DW-4, 16, C_HDRBAR, C_BORDER, 1);
   L("ai_lb", X+8, yAI+2, "EXECUTION", C_GOLD, 6, "Arial Black");

   R("ai_body", X+2, yAI+16, DW-4, 38, C_BG2, C_BORDER, 1);
   L("lb_aistat", X+8, yAI+20, "Status", C_SUBTEXT, 6, "Arial");
   L("vl_aistat", X+50, yAI+20, "ANALYZING", C_ORANGE, 7, "Arial");

   L("lb_conf", X+8, yAI+33, "Quality", C_SUBTEXT, 6, "Arial");
   L("vl_conf", X+50, yAI+33, "MED", C_GOLD, 6, "Arial");
   Bar("conf_bar", X+140, yAI+35, 100, 8, 0, C_GOLD, C_DGRAY);

   // Final Decision Banner (compact)
   int yFD = yAI + 56;
   R("fd_hd", X+2, yFD, DW-4, 14, C_ORANGE, C_BORDER, 1);
   L("fd_lb", X+8, yFD+2, "DECISION", C_BG0, 6, "Arial Black");
   R("fd_body", X+2, yFD+14, DW-4, 28, C_DKGREEN, C_GOLD, 2);
   L("fd_text", X+DW/2-20, yFD+22, "HOLD", C_WHITE, 10, "Arial Black");

   R("fd_split1", X+2, yFD+44, (DW-4)/2, 14, C_BG2, C_BORDER, 1);
   L("fd_split1_lb", X+8, yFD+46, "Route:", C_SUBTEXT, 6, "Arial");
   L("vl_router", X+50, yFD+46, "HOLD", C_ORANGE, 6, "Arial");
   R("fd_split2", X+DW/2+1, yFD+44, (DW-4)/2-2, 14, C_BG2, C_BORDER, 1);
   L("fd_split2_lb", X+DW/2+8, yFD+46, "Health:", C_SUBTEXT, 6, "Arial");
   L("vl_healthgate", X+DW/2+50, yFD+46, "OK", C_GREEN, 6, "Arial");

   // Open Positions (compact)
   int yOP = yFD + 60;
   R("op_hd", X+2, yOP, DW-4, 16, C_HDRBAR, C_BORDER, 1);
   L("op_lb", X+8, yOP+2, "POSITIONS", C_GOLD, 6, "Arial Black");
   L("vl_opcount", X+DW-60, yOP+2, "0 open", C_ORANGE, 6, "Arial");

   R("op_body", X+2, yOP+16, DW-4, 46, C_BG2, C_BORDER, 1);
   L("op_col_type", X+8,  yOP+20, "TYPE", C_SUBTEXT, 6, "Arial");
   L("op_col_lot",  X+50,  yOP+20, "LOT",  C_SUBTEXT, 6, "Arial");
   L("op_col_pl",   X+250, yOP+20, "P&L",  C_SUBTEXT, 6, "Arial");
   L("op_row0", X+8, yOP+30, "--", C_WHITE, 6, "Arial");

   L("lb_float", X+8, yOP+60, "Float:", C_SUBTEXT, 6, "Arial");
   L("vl_float", X+45, yOP+60, "0.00", C_GREEN, 7, "Arial");
   L("lb_equity2", X+180,yOP+60, "Equity:", C_SUBTEXT, 6, "Arial");
   L("vl_equity2", X+230,yOP+60, "0.00", C_WHITE, 7, "Arial");

   // Account Info (compact)
   int yACC = yOP + 78;
   R("acc_hd", X+2, yACC, DW-4, 16, C_DKGREEN, C_GREEN, 1);
   L("acc_lb", X+8, yACC+2, "ACCOUNT", C_WHITE, 6, "Arial Black");

   R("acc_body", X+2, yACC+16, DW-4, 44, C_BG2, C_BORDER, 1);
   L("lb_bal", X+8, yACC+20, "Balance", C_SUBTEXT, 6, "Arial");
   L("vl_bal", X+60, yACC+20, "0.00", C_GREEN, 7, "Arial");
   L("lb_eq",  X+180,yACC+20, "Equity", C_SUBTEXT, 6, "Arial");
   L("vl_eq",  X+230,yACC+20, "0.00", C_GREEN, 7, "Arial");

   L("lb_daypl", X+8, yACC+33, "Day P&L", C_SUBTEXT, 6, "Arial");
   L("vl_daypl", X+60, yACC+33, "0.00", C_GREEN, 7, "Arial");

   L("lb_wr",   X+8, yACC+46, "WR", C_SUBTEXT, 6, "Arial");
   L("vl_wr",   X+40, yACC+46, "0%", C_WHITE, 6, "Arial");
   L("lb_risk", X+180,yACC+46, "Risk", C_SUBTEXT, 6, "Arial");
   L("vl_risk", X+220,yACC+46, "0%", C_WHITE, 6, "Arial");

   // Risk Profile / Account Tier (compact)
   int yTier = yACC + 62;
   R("tier_hd", X+2, yTier, DW-4, 16, C_PURPLE, C_BORDER, 1);
   L("tier_lb", X+8, yTier+2, "RISK PROFILE", C_BG0, 6, "Arial Black");

   R("tier_body", X+2, yTier+16, DW-4, 32, C_BG2, C_BORDER, 1);
   L("lb_tier", X+8, yTier+20, "Tier", C_SUBTEXT, 6, "Arial");
   L("vl_tier", X+40, yTier+20, "SMALL", C_GOLD, 7, "Arial Black");
   L("lb_slmult", X+150, yTier+20, "SL/TP", C_SUBTEXT, 6, "Arial");
   L("vl_slmult", X+185, yTier+20, "1.0x/2.0x ATR", C_WHITE, 6, "Arial");
   L("lb_tierrisk", X+8, yTier+33, "Risk%", C_SUBTEXT, 6, "Arial");
   L("vl_tierrisk", X+45, yTier+33, "0.5%", C_WHITE, 6, "Arial");
   L("lb_tiermax", X+150, yTier+33, "MaxPos", C_SUBTEXT, 6, "Arial");
   L("vl_tiermax", X+195, yTier+33, "1", C_WHITE, 6, "Arial");

   // Session Tabs (compact)
   int yTabs = yTier + 50;
   int tabW = (DW-4)/3;
   R("tab_london", X+2,         yTabs, tabW, 14, C_DGRAY, C_BORDER, 1);
   R("tab_ny",      X+2+tabW,    yTabs, tabW, 14, C_DGRAY, C_BORDER, 1);
   R("tab_asia",    X+2+tabW*2,  yTabs, DW-4-tabW*2, 14, C_DGRAY, C_BORDER, 1);
   L("tab_london_lbl", X+2+tabW/2-18, yTabs+2, "LONDON", C_SUBTEXT, 6, "Arial");
   L("tab_ny_lbl",      X+2+tabW+tabW/2-15, yTabs+2, "NY", C_SUBTEXT, 6, "Arial");
   L("tab_asia_lbl",    X+2+tabW*2+tabW/2-15, yTabs+2, "ASIA", C_SUBTEXT, 6, "Arial");

   // Footer (compact)
   R("ftr", X+2, Y+DH-14, DW-4, 12, C_HDRBAR, C_BORDER, 1);
   L("ft_time", X+8, Y+DH-12, "Server: --:--", C_MGRAY, 6, "Arial");
   L("ft_engine", X+DW-100, Y+DH-12, "QPA v1.01", C_MGRAY, 6, "Arial");

   ChartRedraw(0);
   Print("Compact Dashboard initialized at X=", X, " Y=", Y, " Size=", DW, "x", DH);
}

void UpdateDash()
{
   if(!InpShowDash) return;
   if(MQLInfoInteger(MQL_TESTER) && !MQLInfoInteger(MQL_VISUAL_MODE)) return;

   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double spread = (double)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);

   U("vl_bid", DoubleToString(bid, (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS)), C_WHITE);
   U("vl_ask", DoubleToString(ask, (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS)), C_WHITE);
   U("vl_spread", DoubleToString(spread,0), (spread <= InpMaxSpreadPoints) ? C_GREEN : C_RED);
   U("vl_atr", DoubleToString(g_vol.atrCurrent / SymbolInfoDouble(_Symbol, SYMBOL_POINT), 0), C_WHITE);
   U("vl_volgate", (spread <= InpMaxSpreadPoints) ? "PASS" : "BLOCK", (spread <= InpMaxSpreadPoints) ? C_GREEN : C_RED);
   U("mi_time", TimeToString(TimeCurrent(), TIME_MINUTES), C_SUBTEXT);

   double emaFastM5[1], emaSlowM5[1], rsiM5[1];
   if(CopyBuffer(g_m5_ema_fast, 0, 0, 1, emaFastM5) <= 0) emaFastM5[0] = 0;
   if(CopyBuffer(g_m5_ema_slow, 0, 0, 1, emaSlowM5) <= 0) emaSlowM5[0] = 0;
   if(CopyBuffer(g_m5_rsi, 0, 0, 1, rsiM5) <= 0) rsiM5[0] = 50;

   U("vl_ema10", DoubleToString(emaFastM5[0], 0), C_WHITE);
   U("vl_ema30", DoubleToString(emaSlowM5[0], 0), C_WHITE);
   U("vl_rsi", DoubleToString(rsiM5[0],0), (rsiM5[0]>70 || rsiM5[0]<30) ? C_ORANGE : C_WHITE);
   U("vl_regimetag", RegimeToString(g_regime.regime), (g_regime.regime == REGIME_UNSAFE) ? C_RED : C_CYAN);

   bool tradeNow = g_lastDecision.tradeApproved;
   string decisionWord = tradeNow ? (g_lastDecision.direction == DIR_LONG ? "BUY" : "SELL") : "HOLD";
   color decisionColor = tradeNow ? (g_lastDecision.direction == DIR_LONG ? C_GREEN : C_RED) : C_ORANGE;
   U("vl_decision1", "Decision: " + decisionWord, decisionColor);

   U("vl_aistat", g_statusText, g_statusColor);

   double confPct = TradeQualityScore();
   string confLabel = (confPct >= 75) ? "HIGH" : (confPct >= 45 ? "MED" : "LOW");
   U("vl_conf", confLabel, (confPct>=75)?C_GREEN:(confPct>=45?C_GOLD:C_RED));
   UpdBar("conf_bar", confPct, (confPct>=75)?C_GREEN:(confPct>=45?C_GOLD:C_RED));

   U("fd_text", decisionWord, decisionColor);
   color fdBg = tradeNow ? ((g_lastDecision.direction==DIR_LONG) ? C_DKGREEN : C_DKRED) : C_DGRAY;
   ObjectSetInteger(0, D+"fd_body", OBJPROP_BGCOLOR, fdBg);

   ENUM_STRATEGY routed = RouteRegimeToStrategy(g_regime.regime);
   U("vl_router", (routed == STRAT_NONE) ? "HOLD" : StrategyToString(routed), (routed==STRAT_NONE)?C_MGRAY:C_WHITE);
   
   int hIdx = StrategyHealthIndex(routed);
   bool healthOk = (hIdx < 0 || hIdx >= 5) ? true : g_health[hIdx].enabled;
   U("vl_healthgate", healthOk ? "OK" : "BLOCK", healthOk ? C_GREEN : C_RED);

   int openCount = PositionsTotalForMagic();
   U("vl_opcount", IntegerToString(openCount) + " open", (openCount>0)?C_GREEN:C_ORANGE);

   string rowText = "--";
   if(openCount > 0)
   {
      for(int i = PositionsTotal()-1; i >= 0; i--)
      {
         if(g_pos.SelectByIndex(i) && g_pos.Magic() == InpMagicNumber && g_pos.Symbol() == _Symbol)
         {
            string typeStr = (g_pos.PositionType() == POSITION_TYPE_BUY) ? "BUY" : "SELL";
            rowText = typeStr + " " + DoubleToString(g_pos.Volume(),2) + " | " + DoubleToString(g_pos.Profit(),2);
            break;
         }
      }
   }
   U("op_row0", rowText, (openCount>0) ? C_WHITE : C_SUBTEXT);

   double floatPL = GetFloatingPL();
   U("vl_float", (floatPL>=0?"+":"") + DoubleToString(floatPL,2), (floatPL>=0)?C_GREEN:C_RED);
   
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   U("vl_equity2", DoubleToString(equity,2), C_WHITE);

   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   U("vl_bal", DoubleToString(balance,2), C_GREEN);
   U("vl_eq", DoubleToString(equity,2), C_GREEN);

   double dayPL = equity - g_risk.dayStartEquity;
   U("vl_daypl", (dayPL>=0?"+":"") + DoubleToString(dayPL,2), (dayPL>=0)?C_GREEN:C_RED);

   int totalTrades = g_sessionWins + g_sessionLosses;
   double winRate = (totalTrades>0) ? (100.0*g_sessionWins/totalTrades) : 0.0;
   U("vl_wr", DoubleToString(winRate,0) + "%", (winRate>=50)?C_GREEN:C_ORANGE);
   U("vl_risk", DoubleToString(InpRiskPercentPerTrade,1) + "%", C_WHITE);

   color londonOn = (g_session.current==SESSION_LONDON_OPEN || g_session.current==SESSION_LONDON_MID) ? C_ORANGE : C_DGRAY;
   color nyOn     = (g_session.current==SESSION_NY_OPEN || g_session.current==SESSION_NY_PM) ? C_ORANGE : C_DGRAY;
   color asiaOn   = (g_session.current==SESSION_ASIAN) ? C_ORANGE : C_DGRAY;
   
   ObjectSetInteger(0, D+"tab_london", OBJPROP_BGCOLOR, londonOn);
   ObjectSetInteger(0, D+"tab_ny",     OBJPROP_BGCOLOR, nyOn);
   ObjectSetInteger(0, D+"tab_asia",   OBJPROP_BGCOLOR, asiaOn);
   
   U("tab_london_lbl", "LONDON", (londonOn==C_ORANGE)?C_BG0:C_SUBTEXT);
   U("tab_ny_lbl",      "NY",(nyOn==C_ORANGE)?C_BG0:C_SUBTEXT);
   U("tab_asia_lbl",    "ASIA",(asiaOn==C_ORANGE)?C_BG0:C_SUBTEXT);

   U("ft_time", TimeToString(TimeCurrent(), TIME_MINUTES), C_DGRAY);

   // Risk profile / account tier readout
   U("vl_tier", g_tierCfg.name, C_GOLD);
   U("vl_slmult", DoubleToString(g_tierCfg.slATRMultiplier,1) + "x/" + DoubleToString(g_tierCfg.tpATRMultiplier,1) + "x ATR", C_WHITE);
   double effCap = MathMin(InpMaxRiskPercentTrade, g_tierCfg.maxRiskCapPct);
   U("vl_tierrisk", DoubleToString(InpRiskPercentPerTrade * g_tierCfg.riskMultiplier,2) + "% (cap " + DoubleToString(effCap,2) + "%)", C_WHITE);
   U("vl_tiermax", IntegerToString((int)MathMin(InpMaxConcurrentTrades, g_tierCfg.maxConcurrentTrades)), C_WHITE);
}

void DeleteDash()
{
   ObjectsDeleteAll(0, D);
   ChartRedraw(0);
}

//=====================================================================
//  EA LIFECYCLE
//=====================================================================
int OnInit()
{
   if(InpLiquidityLookback > 60)
   {
      Print("ERROR: InpLiquidityLookback max 60. Current: ", InpLiquidityLookback);
      return INIT_PARAMETERS_INCORRECT;
   }

   g_trade.SetExpertMagicNumber(InpMagicNumber);
   g_trade.SetDeviationInPoints(30);
   g_trade.SetTypeFilling(GetFillMode());

   g_h1_ema_fast = iMA(_Symbol, PERIOD_H1, InpEMAFastPeriod, 0, MODE_EMA, PRICE_CLOSE);
   g_h1_ema_slow = iMA(_Symbol, PERIOD_H1, InpEMASlowPeriod, 0, MODE_EMA, PRICE_CLOSE);
   g_h1_atr      = iATR(_Symbol, PERIOD_H1, InpATRPeriod);

   g_m15_ema_fast = iMA(_Symbol, PERIOD_M15, InpEMAFastPeriod, 0, MODE_EMA, PRICE_CLOSE);
   g_m15_ema_slow = iMA(_Symbol, PERIOD_M15, InpEMASlowPeriod, 0, MODE_EMA, PRICE_CLOSE);
   g_m15_atr      = iATR(_Symbol, PERIOD_M15, InpATRPeriod);
   g_m15_rsi      = iRSI(_Symbol, PERIOD_M15, 14, PRICE_CLOSE);

   g_m5_ema_fast = iMA(_Symbol, PERIOD_M5, InpEMAFastPeriod, 0, MODE_EMA, PRICE_CLOSE);
   g_m5_ema_slow = iMA(_Symbol, PERIOD_M5, InpEMASlowPeriod, 0, MODE_EMA, PRICE_CLOSE);
   g_m5_atr      = iATR(_Symbol, PERIOD_M5, InpATRPeriod);
   g_m5_rsi      = iRSI(_Symbol, PERIOD_M5, 14, PRICE_CLOSE);

   g_m1_ema_fast = iMA(_Symbol, PERIOD_M1, InpEMAFastPeriod, 0, MODE_EMA, PRICE_CLOSE);
   g_m1_ema_slow = iMA(_Symbol, PERIOD_M1, InpEMASlowPeriod, 0, MODE_EMA, PRICE_CLOSE);
   g_m1_atr      = iATR(_Symbol, PERIOD_M1, InpATRPeriod);

   if(g_h1_ema_fast == INVALID_HANDLE || g_h1_ema_slow == INVALID_HANDLE || g_h1_atr == INVALID_HANDLE ||
      g_m15_ema_fast == INVALID_HANDLE || g_m15_ema_slow == INVALID_HANDLE || g_m15_atr == INVALID_HANDLE || g_m15_rsi == INVALID_HANDLE ||
      g_m5_ema_fast == INVALID_HANDLE || g_m5_ema_slow == INVALID_HANDLE || g_m5_atr == INVALID_HANDLE || g_m5_rsi == INVALID_HANDLE ||
      g_m1_ema_fast == INVALID_HANDLE || g_m1_ema_slow == INVALID_HANDLE || g_m1_atr == INVALID_HANDLE)
   {
      Print("ERROR: Indicator handle creation failed");
      return INIT_FAILED;
   }

   g_dayStart  = DayStart(TimeCurrent());
   g_weekStart = WeekStart(TimeCurrent());

   InitRiskState();
   InitStrategyHealth();
   InitAdaptiveParams();
   UpdateAccountTier();

   g_regime.regime = REGIME_RANGING;
   g_regime.confidence = 0;
   g_regime.stability = 0;
   g_regime.sinceTime = TimeCurrent();
   g_regime.previousRegime = REGIME_RANGING;

   if(InpShowDash) InitDash();
   
   EventSetTimer(1);

   g_statusText = "WARMING UP";
   g_statusColor = C_ORANGE;
   g_lastAction = "Building buffers...";

   Print("=== QUANTUM PLUS AI v1.01 COMPACT ===");
   Print("Magic: ", InpMagicNumber, " | Risk: ", InpRiskPercentPerTrade, "% | GMT:", InpBrokerGMTOffset);
   Print("Dashboard: ", InpShowDash ? "ENABLED" : "DISABLED", " | Size: ", DW, "x", DH);

   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
   Print("=== QPA SESSION SUMMARY ===");
   Print("Trades: ", g_tradesToday, " | P&L: ", DoubleToString(g_sessionProfit, 2));
   Print("WR: ", (g_sessionWins+g_sessionLosses > 0) 
      ? DoubleToString(100.0*g_sessionWins/(g_sessionWins+g_sessionLosses), 1) : "0", "%");
   
   for(int i = 0; i < 5; i++)
   {
      Print(g_health[i].name, ": ", g_health[i].totalTrades, " trades | WR=", 
            DoubleToString(g_health[i].winRate, 1), "% | Exp=", DoubleToString(g_health[i].expectancyR, 2), "R");
   }

   EventKillTimer();
   DeleteDash();
   DeleteVisualOverlays();

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
   if(g_lastCloseTime > 0)
   {
      int elapsed = (int)(TimeCurrent() - g_lastCloseTime);
      g_inCooldown = (elapsed < InpCooldownAfterCloseSec);
   }

   RolloverDailyWeeklyIfNeeded();

   if(Bars(_Symbol, PERIOD_H1) < InpEMASlowPeriod + 5 ||
      Bars(_Symbol, PERIOD_M15) < InpEMASlowPeriod + 5 ||
      Bars(_Symbol, PERIOD_M5) < InpATRLookback + 5 ||
      Bars(_Symbol, PERIOD_M1) < InpEMASlowPeriod + 5)
   {
      g_statusText = "BUFFERING";
      g_statusColor = C_ORANGE;
      return;
   }

   bool isNewBar = IsNewBar();
   
   UpdateRiskState();
   
   if(HasManagedPosition())
   {
      g_statusText = "IN TRADE";
      g_statusColor = C_GREEN;
      DrawActiveRiskLevels();
      return;
   }

   if(isNewBar || TimeCurrent() - g_lastFullUpdate > 60)
   {
      UpdateAccountTier();
      UpdateMTFBias();
      UpdateVolatilityIntelligence();
      UpdateNewsShockProxy();
      UpdateLiquidityIntelligence();
      UpdateSessionIntelligence();
      UpdateRegimeClassification();
      UpdateVisualOverlays();
      UpdateAdaptiveParams();
      g_lastFullUpdate = TimeCurrent();
   }

   UpdateExecutionQuality();
   RunMasterDecisionCycle();
}

void OnTradeTransaction(const MqlTradeTransaction &trans,
                         const MqlTradeRequest &request,
                         const MqlTradeResult &result)
{
   OnTradeTransactionHandler(trans, request, result);
}
