//+------------------------------------------------------------------+
//|                                   BTC QUANTUM SCALPER v1.0        |
//|        BTCUSD-Optimized Adaptive Multi-Regime Scalping System    |
//|        Compact Dashboard Edition - Auto Black Theme on Load      |
//+------------------------------------------------------------------+
#property copyright   "BTC Quantum Scalper v1.0 - BTCUSD Edition"
#property version     "1.00"
#property description "BTCUSD-optimized multi-regime adaptive scalping EA with compact dashboard"
#property strict

#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>
#include <Trade\AccountInfo.mqh>
#include <Trade\OrderInfo.mqh>

#define D "BQS_"      
#define OV "BQS_OV_"   // Dashboard / overlay object name prefixes
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
//  TRADE QUALITY SCORE STRUCTURE
//=====================================================================
struct TradeQualityScore
{
   double trendScore;
   double liquidityScore;
   double structureScore;
   double volatilityScore;
   double sessionScore;
   double executionScore;
   
   double totalScore;
   
   bool   approved;
   string rejectReason;
};

//=====================================================================
//  INSTITUTIONAL ANALYSIS STRUCTURES
//=====================================================================

struct OrderBlock
{
   datetime    time;
   double      high;
   double      low;
   bool        isBullish;
   bool        mitigated;
   int         strength;      // 1-5 rating
   double      volume;
};

struct FairValueGap
{
   datetime    startTime;
   datetime    endTime;
   double      topPrice;
   double      bottomPrice;
   bool        isBullish;
   bool        filled;
};

struct MarketStructure
{
   datetime    time;
   double      price;
   bool        isHigh;        // true = swing high, false = swing low
   bool        isBOS;         // Break of Structure
   bool        isCHoCH;       // Change of Character
   int         strength;
};

struct POI
{
   datetime    time;
   double      price;
   string      type;          // "DEMAND", "SUPPLY", "LIQUIDITY", "IMBALANCE"
   color       markerColor;
   bool        active;
};

struct KillZone
{
   datetime    startTime;
   datetime    endTime;
   string      name;
   color       zoneColor;
   int         importance;    // 1-10
};

struct VolumeNode
{
   double      price;
   double      volume;
   color       nodeColor;
};

//=====================================================================
//  GLOBAL ANALYSIS ARRAYS
//=====================================================================
OrderBlock      g_orderBlocks[];
FairValueGap    g_fvgArray[];
MarketStructure g_structure[];
POI             g_poiArray[];
KillZone        g_killZones[];
VolumeNode      g_volumeProfile[];

int             g_obCount = 0;
int             g_fvgCount = 0;
int             g_structCount = 0;
int             g_poiCount = 0;
datetime        g_lastStructureUpdate = 0;

//=====================================================================
//  INPUT PARAMETERS
//=====================================================================

input group "╔══════  IDENTITY  ══════╗"
input ulong    InpMagicNumber          = 881100;
input string   InpBotName              = "BTC QUANTUM SCALPER";

input group "╔══════  RISK GOVERNANCE (BTCUSD TUNED)  ══════╗"
input double   InpRiskPercentPerTrade  = 0.3;     // BTC volatility punishes oversized risk fast - keep base risk lean
input double   InpMaxRiskPercentTrade  = 0.75;    
input double   InpMaxDailyLossPct      = 4.0;     // BTC swings wider than FX pairs - slightly larger daily buffer
input double   InpMaxWeeklyLossPct     = 10.0;    
input double   InpMaxDrawdownPct       = 15.0;    
input int      InpMaxDailyTrades       = 20;      // Scalper profile - more trade attempts per day
input int      InpMaxConcurrentTrades  = 1;       

input group "╔══════  EXECUTION QUALITY (BTCUSD TUNED)  ══════╗"
input double   InpMaxSpreadPoints      = 6000;    // BTCUSD spreads run into hundreds/thousands of points depending on broker digits - adjust to your broker
input double   InpMinExecutionScore    = 55.0;    
input int      InpCooldownAfterCloseSec= 15;      // Shorter cooldown - scalper wants to re-engage quickly

input group "╔══════  REGIME DETECTION (BTCUSD TUNED)  ══════╗"
input int      InpATRPeriod            = 14;
input int      InpATRLookback          = 100;     
input int      InpEMAFastPeriod        = 5;       // Faster EMAs for scalping reaction speed
input int      InpEMASlowPeriod        = 21;
input int      InpStructureLookback    = 20;      
input double   InpMinRegimeConfidence  = 55.0;    

input group "╔══════  LIQUIDITY ENGINE (BTCUSD TUNED)  ══════╗"
input double   InpEqualLevelTolerance  = 0.10;    // Tighter % tolerance since BTC price levels are large numbers
input int      InpLiquidityLookback    = 40;

input group "╔══════  NEWS / VOLATILITY SHOCK PROXY (BTCUSD TUNED)  ══════╗"
input double   InpShockATRMultiple     = 3.0;     // BTC baseline volatility already runs hot - raise shock threshold
input double   InpShockSpreadMultiple  = 2.5;     

input group "╔══════  STRATEGY HEALTH  ══════╗"
input int      InpHealthMinTrades      = 10;        
input int      InpHealthDegradeConsecLoss = 4;     
input double   InpHealthMinExpectancyR = -0.10;    

input group "╔══════  ADAPTIVE PARAMETERS  ══════╗"
input bool     InpEnableAdaptiveParams = true;
input double   InpAdaptiveBoundPct     = 20.0;     

input group "╔══════  SESSION CONFIGURATION  ══════╗"
input int      InpBrokerGMTOffset      = 2;        // BTC trades 24/7 - offset still shifts session volume windows

input group "╔══════  DASHBOARD  ══════╗"
input bool     InpShowDash             = true;
input int      InpDashX                = 10;
input int      InpDashY                = 10;

input group "╔══════  CHART THEME  ══════╗"
input bool     InpEnableBlackTheme     = true;     // Auto-apply a black chart theme on load for maximum overlay visibility
input bool     InpHideGrid             = true;     // Hide gridlines to reduce visual clutter over the analysis overlays

input group "╔══════  VISUAL INTELLIGENCE OVERLAYS  ══════╗"
input bool     InpDrawVolumeProfile    = true;
input bool     InpDrawSessionBoxes     = true;
input bool     InpDrawLiquidityZones   = true;
input bool     InpDrawSignalMarkers    = true;
input int      InpSessionBoxLookbackHrs= 24;        
input color    InpAsianBoxColor        = C'30,50,70';
input color    InpLondonBoxColor       = C'50,40,80';
input color    InpNYBoxColor           = C'70,45,30';

input group "╔══════  INSTITUTIONAL VISUAL ANALYSIS  ══════╗"
input bool     InpDrawMarketStructure  = true;     // Draw Market Structure Lines
input bool     InpDrawOrderBlocks      = true;     // Draw Order Block Levels
input bool     InpDrawFVG              = true;     // Draw Fair Value Gap Levels
input bool     InpDrawPremiumDiscount  = true;     // Draw Premium/Discount Lines
input bool     InpDrawEquilibrium      = true;     // Draw Equilibrium Line
input bool     InpDrawKillZones        = false;    // Draw Kill Zone Backgrounds
input bool     InpDrawSessionHL        = true;     // Draw Session High/Low
input bool     InpDrawPOI              = true;     // Draw Points of Interest
input int      InpStructureBars        = 50;       // Structure Lookback Bars
input int      InpMaxOrderBlocks       = 3;        // Max Order Blocks to Show
input int      InpMaxFVGs              = 5;        // Max FVGs to Show
input bool     InpShowOnlyActive       = true;     // Show Only Active Levels
input ENUM_LINE_STYLE InpLineStyle     = STYLE_SOLID;  // Line Style
input int      InpLineWidth            = 1;        // Line Width
input int      InpLabelFontSize        = 8;        // Label Font Size



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
TradeQualityScore g_tradeQuality;

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
const int   DH = 680;  // Reduced from 850

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
         g_session.strategyWeight    = 1.15;  // BTC: Tokyo/Seoul/Singapore hours drive real crypto volume
         break;
      case SESSION_LONDON_OPEN:
         g_session.preferredStrategy = STRAT_VOLATILITY_EXPANSION;
         g_session.strategyWeight    = 1.3;   
         break;
      case SESSION_LONDON_MID:
         g_session.preferredStrategy = STRAT_TREND_SCALPER;
         g_session.strategyWeight    = 1.05;
         break;
      case SESSION_NY_OPEN:
         g_session.preferredStrategy = STRAT_LIQUIDITY_REVERSAL;
         g_session.strategyWeight    = 1.35;  // BTC: US session typically sees the highest crypto volume/volatility
         break;
      case SESSION_NY_PM:
         g_session.preferredStrategy = STRAT_TREND_SCALPER;
         g_session.strategyWeight    = 1.0;   // BTC never truly closes - keep this window near neutral, not discounted
         break;
      default: 
         g_session.preferredStrategy = STRAT_NONE;
         g_session.strategyWeight    = 0.7;   // BTC "dead zone" hours still see meaningful volume, unlike FX
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
//  MARKET STRUCTURE INTELLIGENCE (SMC/ICT)
//=====================================================================

bool IsSwingHigh(int index, int leftBars, int rightBars)
{
   double centerHigh = iHigh(_Symbol, PERIOD_M5, index);
   
   for(int i = 1; i <= leftBars; i++)
      if(iHigh(_Symbol, PERIOD_M5, index - i) >= centerHigh) return false;
   
   for(int i = 1; i <= rightBars; i++)
      if(iHigh(_Symbol, PERIOD_M5, index + i) >= centerHigh) return false;
   
   return true;
}

bool IsSwingLow(int index, int leftBars, int rightBars)
{
   double centerLow = iLow(_Symbol, PERIOD_M5, index);
   
   for(int i = 1; i <= leftBars; i++)
      if(iLow(_Symbol, PERIOD_M5, index - i) <= centerLow) return false;
   
   for(int i = 1; i <= rightBars; i++)
      if(iLow(_Symbol, PERIOD_M5, index + i) <= centerLow) return false;
   
   return true;
}

void DetectMarketStructure()
{
   if(!InpDrawMarketStructure) return;
   
   ArrayResize(g_structure, 0);
   g_structCount = 0;
   
   int lookback = MathMin(InpStructureBars, Bars(_Symbol, PERIOD_M5) - 10);
   
   // Find swing points
   for(int i = 5; i < lookback; i++)
   {
      bool isHigh = IsSwingHigh(i, 3, 3);
      bool isLow = IsSwingLow(i, 3, 3);
      
      if(isHigh || isLow)
      {
         ArrayResize(g_structure, g_structCount + 1);
         g_structure[g_structCount].time = iTime(_Symbol, PERIOD_M5, i);
         g_structure[g_structCount].price = isHigh ? iHigh(_Symbol, PERIOD_M5, i) : iLow(_Symbol, PERIOD_M5, i);
         g_structure[g_structCount].isHigh = isHigh;
         g_structure[g_structCount].isBOS = false;
         g_structure[g_structCount].isCHoCH = false;
         
         // Calculate strength based on how pronounced the swing is
         double range = iHigh(_Symbol, PERIOD_M5, i) - iLow(_Symbol, PERIOD_M5, i);
         double atrRef = g_vol.atrCurrent > 0 ? g_vol.atrCurrent : 0.0001;
         g_structure[g_structCount].strength = (int)MathMin(5, MathMax(1, range / atrRef * 3));
         
         g_structCount++;
      }
   }
   
   // Detect BOS and CHoCH
   if(g_structCount >= 3)
   {
      bool uptrend = false;
      
      for(int i = g_structCount - 1; i >= 2; i--)
      {
         if(g_structure[i].isHigh)
         {
            // Check if this high broke previous high (BOS) or failed (CHoCH)
            for(int j = i - 1; j >= 0; j--)
            {
               if(g_structure[j].isHigh)
               {
                  if(g_structure[i].price > g_structure[j].price)
                  {
                     g_structure[i].isBOS = uptrend;    // BOS if we were in uptrend
                     g_structure[i].isCHoCH = !uptrend; // CHoCH if we were in downtrend
                     uptrend = true;
                  }
                  break;
               }
            }
         }
         else // is low
         {
            for(int j = i - 1; j >= 0; j--)
            {
               if(!g_structure[j].isHigh)
               {
                  if(g_structure[i].price < g_structure[j].price)
                  {
                     g_structure[i].isBOS = !uptrend;   // BOS if we were in downtrend
                     g_structure[i].isCHoCH = uptrend;  // CHoCH if we were in uptrend
                     uptrend = false;
                  }
                  break;
               }
            }
         }
      }
   }
}

//=====================================================================
//  ORDER BLOCK DETECTION (INSTITUTIONAL FOOTPRINTS)
//=====================================================================

void DetectOrderBlocks()
{
   if(!InpDrawOrderBlocks) return;
   
   ArrayResize(g_orderBlocks, 0);
   g_obCount = 0;
   
   int lookback = MathMin(InpStructureBars, Bars(_Symbol, PERIOD_M5) - 5);
   
   for(int i = 3; i < lookback; i++)
   {
      double open1  = iOpen(_Symbol, PERIOD_M5, i);
      double close1 = iClose(_Symbol, PERIOD_M5, i);
      double high1  = iHigh(_Symbol, PERIOD_M5, i);
      double low1   = iLow(_Symbol, PERIOD_M5, i);
      
      double open2  = iOpen(_Symbol, PERIOD_M5, i-1);
      double close2 = iClose(_Symbol, PERIOD_M5, i-1);
      double high2  = iHigh(_Symbol, PERIOD_M5, i-1);
      double low2   = iLow(_Symbol, PERIOD_M5, i-1);
      
      double open3  = iOpen(_Symbol, PERIOD_M5, i-2);
      double close3 = iClose(_Symbol, PERIOD_M5, i-2);
      
      // Bullish Order Block: Down candle followed by strong up move
      bool bullishOB = (close1 < open1) && (close2 > open2) && (close3 > close2);
      
      // Bearish Order Block: Up candle followed by strong down move
      bool bearishOB = (close1 > open1) && (close2 < open2) && (close3 < close2);
      
      if(bullishOB || bearishOB)
      {
         double price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
         bool mitigated = false;
         
         if(bullishOB)
            mitigated = (iLow(_Symbol, PERIOD_M5, 0) < low1);
         else
            mitigated = (iHigh(_Symbol, PERIOD_M5, 0) > high1);
         
         if(!mitigated || i < 10)  // Keep recent OBs even if mitigated
         {
            ArrayResize(g_orderBlocks, g_obCount + 1);
            g_orderBlocks[g_obCount].time = iTime(_Symbol, PERIOD_M5, i);
            g_orderBlocks[g_obCount].high = high1;
            g_orderBlocks[g_obCount].low = low1;
            g_orderBlocks[g_obCount].isBullish = bullishOB;
            g_orderBlocks[g_obCount].mitigated = mitigated;
            
            // Strength based on follow-through
            double moveSize = bullishOB ? (close3 - low1) : (high1 - close3);
            double atrRef = g_vol.atrCurrent > 0 ? g_vol.atrCurrent : 0.0001;
            g_orderBlocks[g_obCount].strength = (int)MathMin(5, MathMax(1, moveSize / atrRef * 2));
            
            g_obCount++;
         }
      }
   }
}

//=====================================================================
//  FAIR VALUE GAP DETECTION (IMBALANCE)
//=====================================================================

void DetectFairValueGaps()
{
   if(!InpDrawFVG) return;
   
   ArrayResize(g_fvgArray, 0);
   g_fvgCount = 0;
   
   int lookback = MathMin(InpStructureBars, Bars(_Symbol, PERIOD_M5) - 3);
   
   for(int i = 2; i < lookback; i++)
   {
      double high0 = iHigh(_Symbol, PERIOD_M5, i-2);
      double low0  = iLow(_Symbol, PERIOD_M5, i-2);
      
      double high1 = iHigh(_Symbol, PERIOD_M5, i-1);
      double low1  = iLow(_Symbol, PERIOD_M5, i-1);
      
      double high2 = iHigh(_Symbol, PERIOD_M5, i);
      double low2  = iLow(_Symbol, PERIOD_M5, i);
      
      // Bullish FVG: Gap between candle[i] low and candle[i-2] high
      bool bullishFVG = (low0 > high2);
      double bullGapTop = low0;
      double bullGapBottom = high2;
      
      // Bearish FVG: Gap between candle[i] high and candle[i-2] low
      bool bearishFVG = (high0 < low2);
      double bearGapTop = low2;
      double bearGapBottom = high0;
      
      if(bullishFVG || bearishFVG)
      {
         double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
         bool filled = false;
         
         if(bullishFVG)
            filled = (currentPrice < bullGapBottom);
         else
            filled = (currentPrice > bearGapTop);
         
         if(!filled || i < 20)  // Keep recent FVGs
         {
            ArrayResize(g_fvgArray, g_fvgCount + 1);
            g_fvgArray[g_fvgCount].startTime = iTime(_Symbol, PERIOD_M5, i);
            g_fvgArray[g_fvgCount].endTime = TimeCurrent() + 3600 * 24;  // Extend 24h
            g_fvgArray[g_fvgCount].topPrice = bullishFVG ? bullGapTop : bearGapTop;
            g_fvgArray[g_fvgCount].bottomPrice = bullishFVG ? bullGapBottom : bearGapBottom;
            g_fvgArray[g_fvgCount].isBullish = bullishFVG;
            g_fvgArray[g_fvgCount].filled = filled;
            
            g_fvgCount++;
         }
      }
   }
}

//=====================================================================
//  PREMIUM / DISCOUNT ZONE CALCULATION
//=====================================================================

//=====================================================================
//  CLEAN PREMIUM/DISCOUNT ZONES (SIMPLE LINES)
//=====================================================================

void CalculatePremiumDiscount()
{
   if(!InpDrawPremiumDiscount) return;
   
   int lookback = MathMin(100, Bars(_Symbol, PERIOD_M5) - 1);
   
   double rangeHigh = iHigh(_Symbol, PERIOD_M5, iHighest(_Symbol, PERIOD_M5, MODE_HIGH, lookback, 0));
   double rangeLow  = iLow(_Symbol, PERIOD_M5, iLowest(_Symbol, PERIOD_M5, MODE_LOW, lookback, 0));
   
   double range = rangeHigh - rangeLow;
   if(range <= 0) return;
   
   double equilibrium = rangeLow + (range * 0.5);
   double premiumStart = rangeLow + (range * 0.618);  // 61.8%
   double discountEnd  = rangeLow + (range * 0.382);  // 38.2%
   double premium75 = rangeLow + (range * 0.75);      // 75%
   double discount25 = rangeLow + (range * 0.25);     // 25%
   
   datetime now = TimeCurrent();
   datetime past = now - 3600 * InpSessionBoxLookbackHrs;
   
   // Draw range high/low
   DrawHorizontalLine("RANGE_HIGH", past, now, rangeHigh, C'150,150,150', "High", 1, STYLE_SOLID, true);
   DrawHorizontalLine("RANGE_LOW", past, now, rangeLow, C'150,150,150', "Low", 1, STYLE_SOLID, true);
   
   // Draw equilibrium (most important)
   if(InpDrawEquilibrium)
   {
      DrawHorizontalLine("EQUILIBRIUM", past, now, equilibrium, C_GOLD, "EQ (50%)", 2, STYLE_SOLID, true);
   }
   
   // Draw premium levels
   DrawHorizontalLine("PREMIUM_618", past, now, premiumStart, C'200,100,100', "Premium (61.8%)", 1, STYLE_DOT, true);
   DrawHorizontalLine("PREMIUM_75", past, now, premium75, C'180,80,80', "75%", 1, STYLE_DOT, true);
   
   // Draw discount levels
   DrawHorizontalLine("DISCOUNT_382", past, now, discountEnd, C'100,200,100', "Discount (38.2%)", 1, STYLE_DOT, true);
   DrawHorizontalLine("DISCOUNT_25", past, now, discount25, C'80,180,80', "25%", 1, STYLE_DOT, true);
}

//=====================================================================
//  SESSION HIGH/LOW (CLEAN PROFESSIONAL LEVELS)
//=====================================================================

void DrawSessionHighLow()
{
   if(!InpDrawSessionHL) return;
   
   datetime now = TimeCurrent();
   MqlDateTime dt;
   TimeToStruct(now, dt);
   
   // Get session times
   datetime today = now - (dt.hour * 3600 + dt.min * 60 + dt.sec);
   
   // Find session high/low for different sessions
   struct SessionHL
   {
      string name;
      int startHour;
      int endHour;
      color lineColor;
   };
   
   SessionHL sessions[3];
   sessions[0].name = "London";
   sessions[0].startHour = (7 + InpBrokerGMTOffset) % 24;
   sessions[0].endHour = (12 + InpBrokerGMTOffset) % 24;
   sessions[0].lineColor = C'150,150,255';
   
   sessions[1].name = "NY";
   sessions[1].startHour = (12 + InpBrokerGMTOffset) % 24;
   sessions[1].endHour = (17 + InpBrokerGMTOffset) % 24;
   sessions[1].lineColor = C'255,150,150';
   
   sessions[2].name = "Asia";
   sessions[2].startHour = (0 + InpBrokerGMTOffset) % 24;
   sessions[2].endHour = (7 + InpBrokerGMTOffset) % 24;
   sessions[2].lineColor = C'255,255,150';
   
   for(int s = 0; s < 3; s++)
   {
      datetime sessionStart = today + sessions[s].startHour * 3600;
      datetime sessionEnd = today + sessions[s].endHour * 3600;
      
      if(sessionEnd < sessionStart) sessionEnd += 86400;
      if(sessionStart > now) continue;
      
      int startBar = iBarShift(_Symbol, PERIOD_M5, sessionStart, false);
      int endBar = iBarShift(_Symbol, PERIOD_M5, MathMin(sessionEnd, now), false);
      
      if(startBar < 0 || endBar < 0) continue;
      
      double sessionHigh = -DBL_MAX;
      double sessionLow = DBL_MAX;
      
      for(int i = endBar; i <= startBar; i++)
      {
         double h = iHigh(_Symbol, PERIOD_M5, i);
         double l = iLow(_Symbol, PERIOD_M5, i);
         if(h > sessionHigh) sessionHigh = h;
         if(l < sessionLow) sessionLow = l;
      }
      
      if(sessionHigh > -DBL_MAX && sessionLow < DBL_MAX)
      {
         DrawHorizontalLine(sessions[s].name + "_HIGH", 
                           sessionStart, now,
                           sessionHigh, 
                           sessions[s].lineColor, 
                           sessions[s].name + " H", 
                           1, STYLE_DASH, false);
         
         DrawHorizontalLine(sessions[s].name + "_LOW", 
                           sessionStart, now,
                           sessionLow, 
                           sessions[s].lineColor, 
                           sessions[s].name + " L", 
                           1, STYLE_DASH, false);
      }
   }
}

//=====================================================================
//  ICT KILL ZONES (HIGH PROBABILITY TIMES)
//=====================================================================
//=====================================================================
//  SIMPLIFIED KILL ZONES (VERTICAL LINES ONLY)
//=====================================================================

void DrawKillZones()
{
   if(!InpDrawKillZones) return;
   
   datetime now = TimeCurrent();
   MqlDateTime dt;
   TimeToStruct(now, dt);
   
   datetime today = now - (dt.hour * 3600 + dt.min * 60 + dt.sec);
   
   // Just mark the start of kill zones with vertical lines
   struct KZMarker
   {
      string name;
      int hour;
      color lineColor;
   };
   
   KZMarker markers[3];
   markers[0].name = "London KZ";
   markers[0].hour = (7 + InpBrokerGMTOffset) % 24;
   markers[0].lineColor = C'100,100,200';
   
   markers[1].name = "NY KZ";
   markers[1].hour = (12 + InpBrokerGMTOffset) % 24;
   markers[1].lineColor = C'200,100,100';
   
   markers[2].name = "Asia KZ";
   markers[2].hour = (1 + InpBrokerGMTOffset) % 24;
   markers[2].lineColor = C'200,200,100';
   
   for(int i = 0; i < 3; i++)
   {
      datetime kzTime = today + markers[i].hour * 3600;
      if(kzTime > now - 86400 && kzTime < now)
      {
         string vlineName = OV + "KZ_" + markers[i].name;
         ObjectDelete(0, vlineName);
         
         if(ObjectCreate(0, vlineName, OBJ_VLINE, 0, kzTime, 0))
         {
            ObjectSetInteger(0, vlineName, OBJPROP_COLOR, markers[i].lineColor);
            ObjectSetInteger(0, vlineName, OBJPROP_STYLE, STYLE_DOT);
            ObjectSetInteger(0, vlineName, OBJPROP_WIDTH, 1);
            ObjectSetInteger(0, vlineName, OBJPROP_BACK, true);
            ObjectSetInteger(0, vlineName, OBJPROP_SELECTABLE, false);
            ObjectSetInteger(0, vlineName, OBJPROP_HIDDEN, true);
         }
         
         // Add small label
         DrawPriceLabel("KZ_LBL_" + IntegerToString(i), kzTime, SymbolInfoDouble(_Symbol, SYMBOL_BID), 
                       markers[i].name, markers[i].lineColor, 7);
      }
   }
}

//=====================================================================
//  VOLUME PROFILE SIMULATION (PRICE ACCEPTANCE ZONES)
//=====================================================================

void DrawVolumeProfile()
{
   if(!InpDrawVolumeProfile) return;
   
   int lookback = MathMin(100, Bars(_Symbol, PERIOD_M5) - 1);
   
   double rangeHigh = iHigh(_Symbol, PERIOD_M5, iHighest(_Symbol, PERIOD_M5, MODE_HIGH, lookback, 0));
   double rangeLow  = iLow(_Symbol, PERIOD_M5, iLowest(_Symbol, PERIOD_M5, MODE_LOW, lookback, 0));
   
   int bins = 20;
   double binSize = (rangeHigh - rangeLow) / bins;
   if(binSize <= 0) return;
   
   ArrayResize(g_volumeProfile, bins);
   for(int i = 0; i < bins; i++)
   {
      g_volumeProfile[i].price = rangeLow + (i * binSize) + (binSize / 2);
      g_volumeProfile[i].volume = 0;
   }
   
   // Accumulate volume per price level
   for(int bar = 0; bar < lookback; bar++)
   {
      double high = iHigh(_Symbol, PERIOD_M5, bar);
      double low = iLow(_Symbol, PERIOD_M5, bar);
      long tickVol = iVolume(_Symbol, PERIOD_M5, bar);
      
      for(int i = 0; i < bins; i++)
      {
         double binLow = rangeLow + (i * binSize);
         double binHigh = binLow + binSize;
         
         if((low <= binHigh) && (high >= binLow))
         {
            g_volumeProfile[i].volume += tickVol;
         }
      }
   }
   
   // Find max volume for scaling
   double maxVol = 0;
   for(int i = 0; i < bins; i++)
      if(g_volumeProfile[i].volume > maxVol) maxVol = g_volumeProfile[i].volume;
   
   if(maxVol <= 0) return;
   
   datetime now = TimeCurrent();
   datetime baseTime = now - 3600;
   
   // Draw volume bars
   for(int i = 0; i < bins; i++)
   {
      double volPct = g_volumeProfile[i].volume / maxVol;
      int barWidth = (int)(volPct * 1800);  // Max 30 min width
      
      if(barWidth < 60) continue;
      
      datetime endTime = now + barWidth;
      double binLow = rangeLow + (i * binSize);
      double binHigh = binLow + binSize;
      
      color volColor = (volPct > 0.7) ? C'60,60,100' : C'40,40,60';
      g_volumeProfile[i].nodeColor = volColor;
      
      string volName = OV + "VOL_" + IntegerToString(i);
      ObjectDelete(0, volName);
      if(ObjectCreate(0, volName, OBJ_RECTANGLE, 0, now, binHigh, endTime, binLow))
      {
         ObjectSetInteger(0, volName, OBJPROP_COLOR, volColor);
         ObjectSetInteger(0, volName, OBJPROP_FILL, true);
         ObjectSetInteger(0, volName, OBJPROP_BACK, true);
         ObjectSetInteger(0, volName, OBJPROP_SELECTABLE, false);
         ObjectSetInteger(0, volName, OBJPROP_HIDDEN, true);
      }
   }
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
//  TRADE QUALITY SCORING ENGINE (TQSE)
//=====================================================================

double CalculateTrendQuality()
{
   double score = 0;
   
   // MTF alignment is primary trend quality indicator
   score += g_mtf.alignment * 0.70;
   
   // H1 and M15 alignment bonus
   if(g_mtf.h1Bias == g_mtf.m15Bias && g_mtf.h1Bias != 0)
      score += 15;
   
   // M15 and M5 alignment bonus
   if(g_mtf.m15Bias == g_mtf.m5Bias && g_mtf.m15Bias != 0)
      score += 15;
   
   // Perfect alignment across all timeframes
   if(g_mtf.h1Bias == g_mtf.m15Bias && 
      g_mtf.m15Bias == g_mtf.m5Bias && 
      g_mtf.m5Bias == g_mtf.m1Bias && 
      g_mtf.h1Bias != 0)
      score += 10;
   
   return MathMin(100.0, score);
}

double CalculateLiquidityQuality()
{
   double score = 0;
   
   // Sweep probability (high when near liquidity pools)
   score += g_liq.sweepProbability * 0.50;
   
   // Pressure score (strength of liquidity accumulation)
   score += g_liq.pressureScore * 0.30;
   
   // Imbalance score (asymmetric liquidity = opportunity)
   score += g_liq.imbalanceScore * 0.20;
   
   // Bonus for confirmed sweeps (smart money confirmation)
   if(g_liq.sweepUpDetected || g_liq.sweepDownDetected)
      score += 20;
   
   return MathMin(100.0, score);
}

double CalculateStructureQuality()
{
   if(g_structCount < 2) return 0;
   
   double score = 0;
   int recentBOS = 0;
   int recentCHoCH = 0;
   int totalRecent = 0;
   
   // Analyze last 10 structure points (most recent = most relevant)
   int startIdx = MathMax(0, g_structCount - 10);
   
   for(int i = startIdx; i < g_structCount; i++)
   {
      totalRecent++;
      
      // BOS = strong directional move (high quality)
      if(g_structure[i].isBOS)
      {
         recentBOS++;
         // Weight recent BOS more heavily
         double recencyWeight = 1.0 + (0.2 * (i - startIdx));
         score += 8 * recencyWeight;
      }
      
      // CHoCH = potential reversal (medium quality)
      if(g_structure[i].isCHoCH)
      {
         recentCHoCH++;
         score += 5;
      }
      
      // Structure strength bonus
      score += g_structure[i].strength * 2;
   }
   
   // Bonus for clear structure (at least 3 defined swings)
   if(totalRecent >= 3)
      score += 15;
   
   // Bonus for recent BOS (strong trend)
   if(recentBOS >= 2)
      score += 20;
   
   // Regime stability bonus
   score += g_regime.stability * 0.15;
   
   return MathMin(100.0, score);
}

double CalculateVolatilityQuality()
{
   double score = 0;
   
   // NORMAL volatility = ideal trading conditions
   if(g_vol.state == VOL_NORMAL)
      score = 100;
   
   // HIGH volatility = good for breakouts, acceptable
   else if(g_vol.state == VOL_HIGH)
      score = 75;
   
   // LOW volatility = acceptable for mean reversion
   else if(g_vol.state == VOL_LOW)
      score = 60;
   
   // EXTREME volatility = dangerous, low quality
   else if(g_vol.state == VOL_EXTREME)
      score = 25;
   
   // Penalize volatile shocks
   if(g_vol.dynamic == VOLDYN_SPIKE)
      score *= 0.5;
   
   // Bonus for expanding volatility in trending markets
   if(g_vol.dynamic == VOLDYN_EXPANDING && g_regime.regime == REGIME_TRENDING)
      score += 15;
   
   // Penalize if ATR ratio is too extreme
   if(g_vol.atrRatio > 2.5)
      score *= 0.7;
   
   return MathMin(100.0, score);
}

double CalculateSessionQuality()
{
   double score = 0;
   
   // Session priority scoring
   switch(g_session.current)
   {
      case SESSION_LONDON_OPEN:
         score = 100;  // Highest liquidity and volatility
         break;
         
      case SESSION_NY_OPEN:
         score = 95;   // Major market open, high quality
         break;
         
      case SESSION_LONDON_MID:
         score = 80;   // Good liquidity, stable
         break;
         
      case SESSION_NY_PM:
         score = 70;   // Decent continuation trades
         break;
         
      case SESSION_ASIAN:
         score = 40;   // Low volatility, range-bound
         break;
         
      case SESSION_DEAD_ZONE:
         score = 20;   // Avoid trading
         break;
         
      default:
         score = 50;
         break;
   }
   
   // Boost if current session matches preferred strategy
   if(g_session.preferredStrategy != STRAT_NONE)
      score *= g_session.strategyWeight;
   
   // Session volatility bonus (active session = better quality)
   score += g_session.sessionVolatilityScore * 0.15;
   
   return MathMin(100.0, score);
}

double CalculateExecutionQuality()
{
   // Direct pass-through of existing execution quality composite
   return g_execQuality.compositeScore;
}

//=====================================================================
//  MASTER TRADE QUALITY CALCULATOR
//=====================================================================

void UpdateTradeQualityScore()
{
   // Calculate individual quality components
   g_tradeQuality.trendScore      = CalculateTrendQuality();
   g_tradeQuality.liquidityScore  = CalculateLiquidityQuality();
   g_tradeQuality.structureScore  = CalculateStructureQuality();
   g_tradeQuality.volatilityScore = CalculateVolatilityQuality();
   g_tradeQuality.sessionScore    = CalculateSessionQuality();
   g_tradeQuality.executionScore  = CalculateExecutionQuality();
   
   // Weighted composite score (institutional weighting)
   g_tradeQuality.totalScore = 
        (g_tradeQuality.trendScore      * 0.25)   // 25% - Trend is king
      + (g_tradeQuality.liquidityScore  * 0.20)   // 20% - Smart money footprints
      + (g_tradeQuality.structureScore  * 0.20)   // 20% - Market structure
      + (g_tradeQuality.volatilityScore * 0.10)   // 10% - Volatility regime
      + (g_tradeQuality.sessionScore    * 0.10)   // 10% - Time-based edge
      + (g_tradeQuality.executionScore  * 0.15);  // 15% - Execution conditions
   
   // Approval logic with tiered thresholds
   g_tradeQuality.approved = false;
   g_tradeQuality.rejectReason = "";
   
   if(g_tradeQuality.totalScore < 50)
   {
      g_tradeQuality.approved = false;
      g_tradeQuality.rejectReason = "Quality too low (<50)";
   }
   else if(g_tradeQuality.totalScore < 65)
   {
      // Medium quality - require at least 2 strong components
      int strongComponents = 0;
      if(g_tradeQuality.trendScore >= 75) strongComponents++;
      if(g_tradeQuality.liquidityScore >= 75) strongComponents++;
      if(g_tradeQuality.structureScore >= 75) strongComponents++;
      
      if(strongComponents >= 2)
         g_tradeQuality.approved = true;
      else
      {
         g_tradeQuality.approved = false;
         g_tradeQuality.rejectReason = "Quality medium, need 2 strong components";
      }
   }
   else if(g_tradeQuality.totalScore < 75)
   {
      // Good quality - approved
      g_tradeQuality.approved = true;
   }
   else
   {
      // High quality (>= 75) - approved
      g_tradeQuality.approved = true;
   }
   
   // Emergency overrides
   if(g_newsState == NEWS_SHOCK)
   {
      g_tradeQuality.approved = false;
      g_tradeQuality.rejectReason = "News shock override";
   }
   
   if(g_regime.regime == REGIME_UNSAFE)
   {
      g_tradeQuality.approved = false;
      g_tradeQuality.rejectReason = "Unsafe regime override";
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
   s.suggestedSL = (dir > 0) ? NPrice(price - atr * 2.0) : NPrice(price + atr * 2.0);
   s.suggestedTP = (dir > 0) ? NPrice(price + atr * 4.0) : NPrice(price - atr * 4.0);
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
      s.suggestedSL = NPrice(entryPrice + atr * 1.8);
      s.suggestedTP = NPrice(MathMax(mid, entryPrice - atr * 2.5));
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

   double riskPct = InpRiskPercentPerTrade * confidenceFactor * regimeFactor * healthFactor * drawdownFactor;
   riskPct = MathMin(riskPct, InpMaxRiskPercentTrade); 

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

   outRiskAmountUsed = lot * slDistance * valuePerPriceUnit;

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
   if(PositionsTotalForMagic() >= InpMaxConcurrentTrades)
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
   DrawTradeReasoning(decision, TimeCurrent());  // ✅ NEW: Show why we entered
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

   Print("[BQS] Trade closed: ", StrategyToString(strat), " | P&L=", DoubleToString(pnl,2), " | R=", DoubleToString(rMultiple,2));
}

//=====================================================================
//  ACTIVE TRADE MANAGEMENT ENGINE
//=====================================================================
void ManageOpenPositions()
{
   for(int i = PositionsTotal()-1; i >= 0; i--)
   {
      if(!g_pos.SelectByIndex(i)) continue;
      if(g_pos.Magic() != InpMagicNumber || g_pos.Symbol() != _Symbol) continue;

      ulong ticket = g_pos.Ticket();
      double openPrice = g_pos.PriceOpen();
      double currentSL = g_pos.StopLoss();
      double currentTP = g_pos.TakeProfit();
      bool isLong = (g_pos.PositionType() == POSITION_TYPE_BUY);
      
      double currentPrice = isLong ? SymbolInfoDouble(_Symbol, SYMBOL_BID) : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      double profit = g_pos.Profit() + g_pos.Swap();
      
      // Calculate profit in ATR units
      double atr = g_vol.atrCurrent;
      if(atr <= 0) atr = 0.0001;
      
      double profitDistance = isLong ? (currentPrice - openPrice) : (openPrice - currentPrice);
      double profitInATR = profitDistance / atr;
      
      double newSL = currentSL;
      bool needUpdate = false;

      // === BREAK-EVEN LOGIC ===
      // Move SL to break-even + small profit when trade is 0.8 ATR in profit
      if(profitInATR >= 0.8)
      {
         double breakEvenPrice = openPrice + (isLong ? atr * 0.2 : -atr * 0.2);
         
         if(isLong)
         {
            if(currentSL < breakEvenPrice)
            {
               newSL = NPrice(breakEvenPrice);
               needUpdate = true;
               Print("[BQS] Moving to break-even+: ", ticket);
            }
         }
         else
         {
            if(currentSL > breakEvenPrice || currentSL == 0)
            {
               newSL = NPrice(breakEvenPrice);
               needUpdate = true;
               Print("[BQS] Moving to break-even+: ", ticket);
            }
         }
      }

      // === TRAILING STOP LOGIC ===
      // Start trailing when 1.2 ATR in profit
      if(profitInATR >= 1.2)
      {
         double trailDistance = atr * 1.0;  // Trail 1 ATR behind
         double trailSL = isLong ? (currentPrice - trailDistance) : (currentPrice + trailDistance);
         
         if(isLong)
         {
            if(trailSL > currentSL)
            {
               newSL = NPrice(trailSL);
               needUpdate = true;
               Print("[BQS] Trailing stop: ", ticket, " New SL: ", newSL);
            }
         }
         else
         {
            if(trailSL < currentSL || currentSL == 0)
            {
               newSL = NPrice(trailSL);
               needUpdate = true;
               Print("[BQS] Trailing stop: ", ticket, " New SL: ", newSL);
            }
         }
      }

      // === PARTIAL CLOSE LOGIC ===
      // Close 50% at 1.5 ATR profit to lock in gains
      if(profitInATR >= 1.5)
      {
         string comment = g_pos.Comment();
         if(StringFind(comment, "|PARTIAL") < 0)  // Not already partially closed
         {
            double currentLot = g_pos.Volume();
            double lotMin = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
            double closeLot = MathFloor(currentLot * 0.5 / lotMin) * lotMin;
            
            if(closeLot >= lotMin)
            {
               if(g_trade.PositionClosePartial(ticket, closeLot))
               {
                  Print("[BQS] Partial close 50% at +", DoubleToString(profitInATR, 1), " ATR");
                  
                  // Mark position as partially closed
                  g_trade.PositionModify(ticket, currentSL, currentTP);
               }
            }
         }
      }

      // === APPLY SL MODIFICATION ===
      if(needUpdate && newSL > 0)
      {
         if(!g_trade.PositionModify(ticket, newSL, currentTP))
         {
            Print("[BQS] Failed to modify SL: ", GetLastError());
         }
      }
   }
}

//=====================================================================
//  PERFORMANCE ANALYTICS ENGINE  
//=====================================================================
double TradeQualityScoreV2()
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
   ManageOpenPositions();  // ✅ NOW WE MANAGE THE TRADE!
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

   // ============ TRADE QUALITY FILTER ============
   UpdateTradeQualityScore();
   
   if(!g_tradeQuality.approved && decision.tradeApproved)
   {
      g_statusText = "QUALITY BLOCK";
      g_statusColor = C_ORANGE;
      g_lastAction = "Rejected: " + g_tradeQuality.rejectReason + 
                     " (Score: " + DoubleToString(g_tradeQuality.totalScore, 1) + "%)";
      return;
   }
   // ============================================

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

   string objName = OV + name;
   ObjectDelete(0, objName);
   
   if(ObjectCreate(0, objName, OBJ_RECTANGLE, 0, startTime, hi, endTime, lo))
   {
      ObjectSetInteger(0, objName, OBJPROP_COLOR, boxColor);
      ObjectSetInteger(0, objName, OBJPROP_FILL, true);
      ObjectSetInteger(0, objName, OBJPROP_BACK, true);
      ObjectSetInteger(0, objName, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, objName, OBJPROP_HIDDEN, true);
      ObjectSetInteger(0, objName, OBJPROP_WIDTH, 1);
   }

   string lblName = OV + name + "_lbl";
   ObjectDelete(0, lblName);
   
   if(ObjectCreate(0, lblName, OBJ_TEXT, 0, startTime, hi))
   {
      ObjectSetString(0, lblName, OBJPROP_TEXT, name);
      ObjectSetInteger(0, lblName, OBJPROP_COLOR, boxColor);
      ObjectSetInteger(0, lblName, OBJPROP_FONTSIZE, 6);
      ObjectSetInteger(0, lblName, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, lblName, OBJPROP_HIDDEN, true);
   }
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

void UpdateSessionBoxes()
{
   if(!InpDrawSessionBoxes) return;
   
   // Just draw vertical lines at session starts instead of boxes
   datetime now = TimeCurrent();
   MqlDateTime dt;
   TimeToStruct(now, dt);
   datetime today = now - (dt.hour * 3600 + dt.min * 60 + dt.sec);
   
   struct SessionMarker
   {
      string name;
      int hour;
      color lineColor;
   };
   
   SessionMarker sessions[3];
   sessions[0].name = "London Open";
   sessions[0].hour = (7 + InpBrokerGMTOffset) % 24;
   sessions[0].lineColor = C'100,100,150';
   
   sessions[1].name = "NY Open";
   sessions[1].hour = (12 + InpBrokerGMTOffset) % 24;
   sessions[1].lineColor = C'150,100,100';
   
   sessions[2].name = "Asia Open";
   sessions[2].hour = (0 + InpBrokerGMTOffset) % 24;
   sessions[2].lineColor = C'150,150,100';
   
   for(int i = 0; i < 3; i++)
   {
      datetime sessionTime = today + sessions[i].hour * 3600;
      
      if(sessionTime > now - 86400 && sessionTime < now)
      {
         string vlineName = OV + "SESSION_" + sessions[i].name;
         ObjectDelete(0, vlineName);
         
         if(ObjectCreate(0, vlineName, OBJ_VLINE, 0, sessionTime, 0))
         {
            ObjectSetInteger(0, vlineName, OBJPROP_COLOR, sessions[i].lineColor);
            ObjectSetInteger(0, vlineName, OBJPROP_STYLE, STYLE_DASHDOT);
            ObjectSetInteger(0, vlineName, OBJPROP_WIDTH, 1);
            ObjectSetInteger(0, vlineName, OBJPROP_BACK, true);
            ObjectSetInteger(0, vlineName, OBJPROP_SELECTABLE, false);
            ObjectSetInteger(0, vlineName, OBJPROP_HIDDEN, true);
         }
      }
   }
}
void UpdateLiquidityZones()
{
   if(!InpDrawLiquidityZones) return;

   datetime now = TimeCurrent();
   datetime past = now - InpSessionBoxLookbackHrs * 3600;

   // Equal Highs - draw as single line with label
   if(g_liq.equalHighsDetected)
   {
      color lineColor = g_liq.sweepUpDetected ? C'255,100,100' : C'200,200,100';
      string label = g_liq.sweepUpDetected ? "EQH SWEPT ⚡" : "EQH (Liquidity)";
      
      DrawHorizontalLine("LIQ_EQH", past, now, g_liq.equalHighLevel, 
                        lineColor, label, 2, STYLE_SOLID, true);
   }
   else
   {
      ObjectDelete(0, OV + "LIQ_EQH");
      ObjectDelete(0, OV + "LIQ_EQH_LBL");
   }

   // Equal Lows - draw as single line with label
   if(g_liq.equalLowsDetected)
   {
      color lineColor = g_liq.sweepDownDetected ? C'100,255,100' : C'200,200,100';
      string label = g_liq.sweepDownDetected ? "EQL SWEPT ⚡" : "EQL (Liquidity)";
      
      DrawHorizontalLine("LIQ_EQL", past, now, g_liq.equalLowLevel, 
                        lineColor, label, 2, STYLE_SOLID, true);
   }
   else
   {
      ObjectDelete(0, OV + "LIQ_EQL");
      ObjectDelete(0, OV + "LIQ_EQL_LBL");
   }
}
void DrawEntryMarker(ENUM_DIRECTION dir, double price, ENUM_STRATEGY strat)
{
   if(!InpDrawSignalMarkers) return;

   datetime t = TimeCurrent();
   string name = OV + "ENTRY_" + IntegerToString((int)t) + "_" + IntegerToString(MathRand());

   int arrowCode = (dir == DIR_LONG) ? 233 : 234; 
   color arrowColor = (dir == DIR_LONG) ? C_GREEN : C_RED;

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

   color markColor = (pnl >= 0) ? C_CYAN : C_PURPLE;

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
   UpdateInstitutionalVisuals();  // ✅ NEW: Add institutional analysis
}

void DeleteVisualOverlays()
{
   ObjectsDeleteAll(0, OV);
}

//=====================================================================
//  LIVE TRADE REASONING OVERLAY
//=====================================================================
//=====================================================================
//  CLEAN TRADE REASONING (MINIMAL TEXT BOX)
//=====================================================================

void DrawTradeReasoning(MasterDecision &decision, datetime entryTime)
{
   if(!decision.tradeApproved) return;
   
   double entryPrice = decision.direction == DIR_LONG ? 
                       SymbolInfoDouble(_Symbol, SYMBOL_ASK) : 
                       SymbolInfoDouble(_Symbol, SYMBOL_BID);
   
   // Just draw a small info label, no box
   string reasoning = "";
   reasoning += (decision.direction == DIR_LONG ? "↑ " : "↓ ");
   reasoning += StrategyToString(decision.strategySource);
   reasoning += " | " + RegimeToString(g_regime.regime);
   reasoning += " | C:" + DoubleToString(g_regime.confidence, 0) + "%";
   reasoning += " | R:$" + DoubleToString(decision.riskAmountUsed, 2);
   
   string txtName = OV + "REASON_" + IntegerToString((int)entryTime);
   ObjectDelete(0, txtName);
   
   double labelPrice = entryPrice + (decision.direction == DIR_LONG ? g_vol.atrCurrent * 0.5 : -g_vol.atrCurrent * 0.5);
   
   if(ObjectCreate(0, txtName, OBJ_TEXT, 0, entryTime, labelPrice))
   {
      color txtColor = decision.direction == DIR_LONG ? C_GREEN : C_RED;
      ObjectSetString(0, txtName, OBJPROP_TEXT, reasoning);
      ObjectSetInteger(0, txtName, OBJPROP_COLOR, txtColor);
      ObjectSetInteger(0, txtName, OBJPROP_FONTSIZE, 8);
      ObjectSetString(0, txtName, OBJPROP_FONT, "Arial");
      ObjectSetInteger(0, txtName, OBJPROP_ANCHOR, ANCHOR_LEFT);
      ObjectSetInteger(0, txtName, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, txtName, OBJPROP_HIDDEN, true);
   }
}


//=====================================================================
//  DRAW MARKET STRUCTURE ON CHART
//=====================================================================
//=====================================================================
//  CLEAN LINE DRAWING HELPERS
//=====================================================================

void DrawHorizontalLine(string name, datetime time1, datetime time2, double price, 
                        color lineColor, string label, int width = 1, 
                        ENUM_LINE_STYLE style = STYLE_SOLID, bool ray = false)
{
   string lineName = OV + name;
   ObjectDelete(0, lineName);
   
   if(ObjectCreate(0, lineName, OBJ_TREND, 0, time1, price, time2, price))
   {
      ObjectSetInteger(0, lineName, OBJPROP_COLOR, lineColor);
      ObjectSetInteger(0, lineName, OBJPROP_STYLE, style);
      ObjectSetInteger(0, lineName, OBJPROP_WIDTH, width);
      ObjectSetInteger(0, lineName, OBJPROP_BACK, true);
      ObjectSetInteger(0, lineName, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, lineName, OBJPROP_HIDDEN, true);
      ObjectSetInteger(0, lineName, OBJPROP_RAY_RIGHT, ray);
   }
   
   // Add label at the end
   if(label != "")
   {
      string lblName = lineName + "_LBL";
      ObjectDelete(0, lblName);
      
      if(ObjectCreate(0, lblName, OBJ_TEXT, 0, time2, price))
      {
         ObjectSetString(0, lblName, OBJPROP_TEXT, " " + label);
         ObjectSetInteger(0, lblName, OBJPROP_COLOR, lineColor);
         ObjectSetInteger(0, lblName, OBJPROP_FONTSIZE, InpLabelFontSize);
         ObjectSetString(0, lblName, OBJPROP_FONT, "Arial");
         ObjectSetInteger(0, lblName, OBJPROP_ANCHOR, ANCHOR_LEFT);
         ObjectSetInteger(0, lblName, OBJPROP_SELECTABLE, false);
         ObjectSetInteger(0, lblName, OBJPROP_HIDDEN, true);
      }
   }
}

void DrawTrendLine(string name, datetime time1, double price1, datetime time2, double price2,
                   color lineColor, string label, int width = 1, ENUM_LINE_STYLE style = STYLE_SOLID)
{
   string lineName = OV + name;
   ObjectDelete(0, lineName);
   
   if(ObjectCreate(0, lineName, OBJ_TREND, 0, time1, price1, time2, price2))
   {
      ObjectSetInteger(0, lineName, OBJPROP_COLOR, lineColor);
      ObjectSetInteger(0, lineName, OBJPROP_STYLE, style);
      ObjectSetInteger(0, lineName, OBJPROP_WIDTH, width);
      ObjectSetInteger(0, lineName, OBJPROP_BACK, true);
      ObjectSetInteger(0, lineName, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, lineName, OBJPROP_HIDDEN, true);
      ObjectSetInteger(0, lineName, OBJPROP_RAY_RIGHT, false);
   }
   
   if(label != "")
   {
      string lblName = lineName + "_LBL";
      ObjectDelete(0, lblName);
      
      if(ObjectCreate(0, lblName, OBJ_TEXT, 0, time2, price2))
      {
         ObjectSetString(0, lblName, OBJPROP_TEXT, " " + label);
         ObjectSetInteger(0, lblName, OBJPROP_COLOR, lineColor);
         ObjectSetInteger(0, lblName, OBJPROP_FONTSIZE, InpLabelFontSize - 1);
         ObjectSetString(0, lblName, OBJPROP_FONT, "Arial");
         ObjectSetInteger(0, lblName, OBJPROP_SELECTABLE, false);
         ObjectSetInteger(0, lblName, OBJPROP_HIDDEN, true);
      }
   }
}

void DrawPriceLabel(string name, datetime time, double price, string text, color textColor, int size = 8)
{
   string lblName = OV + name;
   ObjectDelete(0, lblName);
   
   if(ObjectCreate(0, lblName, OBJ_TEXT, 0, time, price))
   {
      ObjectSetString(0, lblName, OBJPROP_TEXT, text);
      ObjectSetInteger(0, lblName, OBJPROP_COLOR, textColor);
      ObjectSetInteger(0, lblName, OBJPROP_FONTSIZE, size);
      ObjectSetString(0, lblName, OBJPROP_FONT, "Arial Bold");
      ObjectSetInteger(0, lblName, OBJPROP_ANCHOR, ANCHOR_LEFT);
      ObjectSetInteger(0, lblName, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, lblName, OBJPROP_HIDDEN, true);
   }
}

//=====================================================================
//  CLEAN MARKET STRUCTURE DRAWING
//=====================================================================

void DrawMarketStructure()
{
   if(!InpDrawMarketStructure || g_structCount < 2) return;
   
   datetime now = TimeCurrent();
   
   // Only draw recent structure (last 10 swings)
   int startIdx = MathMax(0, g_structCount - 10);
   
   for(int i = startIdx; i < g_structCount - 1; i++)
   {
      string lineName = "STRUCT_" + IntegerToString(i);
      
      // Simpler color scheme
      color lineColor = C'120,120,120';  // Gray for regular structure
      int lineWidth = 1;
      ENUM_LINE_STYLE style = STYLE_SOLID;
      string label = "";
      
      // Highlight important structures
      if(g_structure[i].isBOS)
      {
         lineColor = C_GOLD;
         lineWidth = 2;
         label = "BOS";
      }
      else if(g_structure[i].isCHoCH)
      {
         lineColor = C_ORANGE;
         lineWidth = 2;
         label = "CHoCH";
      }
      
      DrawTrendLine(lineName, 
                    g_structure[i].time, g_structure[i].price,
                    g_structure[i+1].time, g_structure[i+1].price,
                    lineColor, label, lineWidth, style);
   }
   
   // Draw swing high/low markers as small dots
   for(int i = startIdx; i < g_structCount; i++)
   {
      if(g_structure[i].isBOS || g_structure[i].isCHoCH)
      {
         string markerName = "STRUCT_DOT_" + IntegerToString(i);
         ObjectDelete(0, OV + markerName);
         
         if(ObjectCreate(0, OV + markerName, OBJ_ARROW, 0, g_structure[i].time, g_structure[i].price))
         {
            int arrowCode = g_structure[i].isHigh ? 159 : 159;  // Small circle
            color dotColor = g_structure[i].isBOS ? C_GOLD : C_ORANGE;
            
            ObjectSetInteger(0, OV + markerName, OBJPROP_ARROWCODE, arrowCode);
            ObjectSetInteger(0, OV + markerName, OBJPROP_COLOR, dotColor);
            ObjectSetInteger(0, OV + markerName, OBJPROP_WIDTH, 3);
            ObjectSetInteger(0, OV + markerName, OBJPROP_SELECTABLE, false);
            ObjectSetInteger(0, OV + markerName, OBJPROP_HIDDEN, true);
         }
      }
   }
}
//=====================================================================
//  DRAW ORDER BLOCKS ON CHART
//=====================================================================

//=====================================================================
//  CLEAN ORDER BLOCK DRAWING (ONLY KEY LEVELS)
//=====================================================================
//=====================================================================
//  CLEAN ORDER BLOCK DRAWING (ONLY KEY LEVELS)
//=====================================================================

void DrawOrderBlocks()
{
   if(!InpDrawOrderBlocks || g_obCount <= 0) return;
   
   datetime now = TimeCurrent();
   datetime past = now - 3600 * 12;  // 12 hours back
   
   int drawn = 0;
   
   // Draw only most recent and unmitigated order blocks
   for(int i = g_obCount - 1; i >= 0 && drawn < InpMaxOrderBlocks; i--)
   {
      // Skip mitigated if showing only active
      if(InpShowOnlyActive && g_orderBlocks[i].mitigated) continue;
      
      double price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      double distanceATR = MathAbs(price - (g_orderBlocks[i].high + g_orderBlocks[i].low) / 2) / g_vol.atrCurrent;
      
      // Skip if too far away (more than 5 ATR)
      if(distanceATR > 5.0) continue;
      
      color lineColor = g_orderBlocks[i].isBullish ? C'60,180,100' : C'220,80,80';
      if(g_orderBlocks[i].mitigated) lineColor = C'80,80,80';  // Dim if mitigated
      
      string typeLabel = g_orderBlocks[i].isBullish ? "OB↑" : "OB↓";
      if(g_orderBlocks[i].mitigated) typeLabel += " (M)";
      
      // Draw top line
      DrawHorizontalLine("OB_HIGH_" + IntegerToString(i),
                        g_orderBlocks[i].time, now,
                        g_orderBlocks[i].high,
                        lineColor, typeLabel, InpLineWidth, STYLE_DOT, false);
      
      // Draw bottom line
      DrawHorizontalLine("OB_LOW_" + IntegerToString(i),
                        g_orderBlocks[i].time, now,
                        g_orderBlocks[i].low,
                        lineColor, "", InpLineWidth, STYLE_DOT, false);
      
      drawn++;
   }
}
//=====================================================================
//  DRAW FAIR VALUE GAPS
//=====================================================================

//=====================================================================
//  CLEAN FAIR VALUE GAP DRAWING
//=====================================================================

void DrawFairValueGaps()
{
   if(!InpDrawFVG || g_fvgCount <= 0) return;
   
   datetime now = TimeCurrent();
   int drawn = 0;
   
   for(int i = g_fvgCount - 1; i >= 0 && drawn < InpMaxFVGs; i--)
   {
      if(InpShowOnlyActive && g_fvgArray[i].filled) continue;
      
      double price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      double distanceATR = MathAbs(price - (g_fvgArray[i].topPrice + g_fvgArray[i].bottomPrice) / 2) / g_vol.atrCurrent;
      
      if(distanceATR > 4.0) continue;
      
      color lineColor = g_fvgArray[i].isBullish ? C'100,200,150' : C'200,100,120';
      if(g_fvgArray[i].filled) lineColor = C'90,90,90';
      
      string label = g_fvgArray[i].isBullish ? "FVG↑" : "FVG↓";
      if(g_fvgArray[i].filled) label += " (F)";
      
      // Draw top boundary
      DrawHorizontalLine("FVG_TOP_" + IntegerToString(i),
                        g_fvgArray[i].startTime, now,
                        g_fvgArray[i].topPrice,
                        lineColor, label, InpLineWidth, STYLE_DASHDOTDOT, false);
      
      // Draw bottom boundary
      DrawHorizontalLine("FVG_BOT_" + IntegerToString(i),
                        g_fvgArray[i].startTime, now,
                        g_fvgArray[i].bottomPrice,
                        lineColor, "", InpLineWidth, STYLE_DASHDOTDOT, false);
      
      drawn++;
   }
}
//=====================================================================
//  MASTER VISUAL UPDATE FUNCTION
//=====================================================================
//=====================================================================
//  MASTER CLEAN VISUAL UPDATE
//=====================================================================

void UpdateInstitutionalVisuals()
{
   datetime now = TimeCurrent();
   
   // Update every 5 minutes
   if(now - g_lastStructureUpdate < 300 && !IsNewBar()) return;
   
   g_lastStructureUpdate = now;
   
   // Detect patterns
   DetectMarketStructure();
   DetectOrderBlocks();
   DetectFairValueGaps();
   
   // Draw clean visuals
   DrawMarketStructure();
   DrawOrderBlocks();
   DrawFairValueGaps();
   CalculatePremiumDiscount();
   DrawSessionHighLow();
   DrawKillZones();
   
   ChartRedraw(0);
}
//=====================================================================
//  CHART THEME - AUTO BLACK THEME FOR MAXIMUM OVERLAY VISIBILITY
//=====================================================================
void ApplyBlackChartTheme()
{
   if(!InpEnableBlackTheme) return;

   long chartId = ChartID();

   ChartSetInteger(chartId, CHART_COLOR_BACKGROUND, clrBlack);
   ChartSetInteger(chartId, CHART_COLOR_FOREGROUND, C'220,220,220');
   ChartSetInteger(chartId, CHART_COLOR_GRID,        C'20,20,20');
   ChartSetInteger(chartId, CHART_COLOR_CHART_UP,    C'24,222,118');
   ChartSetInteger(chartId, CHART_COLOR_CHART_DOWN,  C'234,62,72');
   ChartSetInteger(chartId, CHART_COLOR_CHART_LINE,  C'0,224,224');
   ChartSetInteger(chartId, CHART_COLOR_CANDLE_BULL, C'24,222,118');
   ChartSetInteger(chartId, CHART_COLOR_CANDLE_BEAR, C'234,62,72');
   ChartSetInteger(chartId, CHART_COLOR_VOLUME,      C'78,92,118');
   ChartSetInteger(chartId, CHART_COLOR_BID,         C'0,170,225');
   ChartSetInteger(chartId, CHART_COLOR_ASK,         C'255,150,10');
   ChartSetInteger(chartId, CHART_COLOR_LAST,        C'255,202,60');
   ChartSetInteger(chartId, CHART_COLOR_STOP_LEVEL,  C'182,108,255');

   ChartSetInteger(chartId, CHART_SHOW_GRID, InpHideGrid ? false : true);
   ChartSetInteger(chartId, CHART_MODE,      CHART_CANDLES);

   ChartRedraw(chartId);

   Print("[BQS] Black chart theme applied for maximum overlay visibility.");
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
   L("ring_title", X+8, Y+6, "BTC SCALP AI", C_CYAN, 7, "Arial Black");

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

   
   // ========== TRADE QUALITY DISPLAY ==========
   int yQual = ySig + 81;
   R("quality_hd", X+2, yQual, DW-4, 16, C'40,80,120', C_BORDER, 1);
   L("quality_lb", X+8, yQual+2, "TRADE QUALITY", C_WHITE, 6, "Arial Black");
   
   R("quality_body", X+2, yQual+16, DW-4, 32, C_BG2, C_BORDER, 1);
   
   // Individual scores row
   L("vl_trend_quality", X+8, yQual+20, "T:0", C_WHITE, 6, "Arial");
   L("vl_liq_quality", X+70, yQual+20, "L:0", C_WHITE, 6, "Arial");
   L("vl_struct_quality", X+130, yQual+20, "S:0", C_WHITE, 6, "Arial");
   
   // Total score and status
   L("lb_total_q", X+8, yQual+33, "Total:", C_SUBTEXT, 6, "Arial");
   L("vl_total_quality", X+50, yQual+33, "Q:0%", C_WHITE, 7, "Arial Bold");
   L("vl_quality_status", X+200, yQual+33, "✓ PASS", C_GREEN, 7, "Arial Bold");

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
   L("lb_obcount", X+8, yACC+56, "OBs:", C_SUBTEXT, 6, "Arial");
   L("vl_obcount", X+50, yACC+56, IntegerToString(g_obCount), C_CYAN, 6, "Arial");
   L("lb_fvgcount", X+120, yACC+56, "FVGs:", C_SUBTEXT, 6, "Arial");
   L("vl_fvgcount", X+160, yACC+56, IntegerToString(g_fvgCount), C_PURPLE, 6, "Arial");
   L("lb_structcount", X+220, yACC+56, "Struct:", C_SUBTEXT, 6, "Arial");
   L("vl_structcount", X+270, yACC+56, IntegerToString(g_structCount), C_ORANGE, 6, "Arial");

   L("lb_daypl", X+8, yACC+33, "Day P&L", C_SUBTEXT, 6, "Arial");
   L("vl_daypl", X+60, yACC+33, "0.00", C_GREEN, 7, "Arial");

   L("lb_wr",   X+8, yACC+46, "WR", C_SUBTEXT, 6, "Arial");
   L("vl_wr",   X+40, yACC+46, "0%", C_WHITE, 6, "Arial");
   L("lb_risk", X+180,yACC+46, "Risk", C_SUBTEXT, 6, "Arial");
   L("vl_risk", X+220,yACC+46, "0%", C_WHITE, 6, "Arial");

   // Session Tabs (compact)
   int yTabs = yACC + 70;
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
   L("ft_engine", X+DW-100, Y+DH-12, "BTC-QS v1.0", C_MGRAY, 6, "Arial");

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

      
   // ========== TRADE QUALITY PANEL ==========
   // Display individual scores with color coding
   color trendColor = (g_tradeQuality.trendScore >= 75) ? C_GREEN : 
                      (g_tradeQuality.trendScore >= 50) ? C_GOLD : C_RED;
   U("vl_trend_quality", "T:" + DoubleToString(g_tradeQuality.trendScore, 0), trendColor);
   
   color liqColor = (g_tradeQuality.liquidityScore >= 75) ? C_GREEN : 
                    (g_tradeQuality.liquidityScore >= 50) ? C_GOLD : C_RED;
   U("vl_liq_quality", "L:" + DoubleToString(g_tradeQuality.liquidityScore, 0), liqColor);
   
   color structColor = (g_tradeQuality.structureScore >= 75) ? C_GREEN : 
                       (g_tradeQuality.structureScore >= 50) ? C_GOLD : C_RED;
   U("vl_struct_quality", "S:" + DoubleToString(g_tradeQuality.structureScore, 0), structColor);
   
   // Total Quality Score
   color totalColor = (g_tradeQuality.totalScore >= 85) ? C_GREEN : 
                      (g_tradeQuality.totalScore >= 75) ? C_GOLD : 
                      (g_tradeQuality.totalScore >= 65) ? C_ORANGE : C_RED;
   U("vl_total_quality", "Q:" + DoubleToString(g_tradeQuality.totalScore, 0) + "%", totalColor);
   
   // Approval status
   string approvalText = g_tradeQuality.approved ? "✓ PASS" : "✗ BLOCK";
   color approvalColor = g_tradeQuality.approved ? C_GREEN : C_RED;
   U("vl_quality_status", approvalText, approvalColor);

   bool tradeNow = g_lastDecision.tradeApproved;
   string decisionWord = tradeNow ? (g_lastDecision.direction == DIR_LONG ? "BUY" : "SELL") : "HOLD";
   color decisionColor = tradeNow ? (g_lastDecision.direction == DIR_LONG ? C_GREEN : C_RED) : C_ORANGE;
   U("vl_decision1", "Decision: " + decisionWord, decisionColor);

   U("vl_aistat", g_statusText, g_statusColor);

   double confPct = g_tradeQuality.totalScore;
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
   U("vl_obcount", IntegerToString(g_obCount), C_CYAN);
   U("vl_fvgcount", IntegerToString(g_fvgCount), C_PURPLE);
   U("vl_structcount", IntegerToString(g_structCount), C_ORANGE);
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

   // Apply the black chart theme immediately on load for best overlay visibility
   ApplyBlackChartTheme();

   if(StringFind(_Symbol, "BTC") < 0 && StringFind(_Symbol, "XBT") < 0)
      Print("[BQS] WARNING: This EA is tuned for BTCUSD. Current chart symbol is ", _Symbol,
            " - inputs (spread, ATR, tolerance, risk) may not be optimal.");

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

     
   // Initialize Trade Quality Score
   g_tradeQuality.trendScore = 0;
   g_tradeQuality.liquidityScore = 0;
   g_tradeQuality.structureScore = 0;
   g_tradeQuality.volatilityScore = 0;
   g_tradeQuality.sessionScore = 0;
   g_tradeQuality.executionScore = 0;
   g_tradeQuality.totalScore = 0;
   g_tradeQuality.approved = false;
   g_tradeQuality.rejectReason = "Not yet calculated"; 

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

   Print("=== BTC QUANTUM SCALPER v1.0 ===");
   Print("Symbol: ", _Symbol, " | Magic: ", InpMagicNumber, " | Risk: ", InpRiskPercentPerTrade, "% | GMT:", InpBrokerGMTOffset);
   Print("Dashboard: ", InpShowDash ? "ENABLED" : "DISABLED", " | Size: ", DW, "x", DH, " | Black Theme: ", InpEnableBlackTheme ? "ON" : "OFF");
   Print("=== ACCOUNT INFO ===");
   Print("Balance: $", AccountInfoDouble(ACCOUNT_BALANCE));
   Print("Equity: $", AccountInfoDouble(ACCOUNT_EQUITY));
   Print("Risk per trade: ", InpRiskPercentPerTrade, "%");
   Print("Risk amount: $", AccountInfoDouble(ACCOUNT_EQUITY) * InpRiskPercentPerTrade / 100.0);
   
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
   Print("=== BTC QUANTUM SCALPER SESSION SUMMARY ===");
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
 
   
   // Update TQSE on new bar for efficiency
   if(isNewBar)
   {
      UpdateTradeQualityScore();
   } 
   
   if(HasManagedPosition())
{
   ManageOpenPositions();  // ✅ NOW WE MANAGE THE TRADE!
   g_statusText = "IN TRADE";
   g_statusColor = C_GREEN;
   return;
}

   if(isNewBar || TimeCurrent() - g_lastFullUpdate > 60)
   {
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
