//+------------------------------------------------------------------+
//|                                    QUANTUM PLUS AI v1.03         |
//|              Institutional AI Market Analyst Edition             |
//|        Enhanced Visibility | Professional Interface | DPI Aware  |
//+------------------------------------------------------------------+
#property copyright   "Quantum Plus AI v1.03 - Institutional Edition"
#property version     "1.03"
#property description "AI-Driven Market Intelligence Terminal"
#property strict

#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>
#include <Trade\AccountInfo.mqh>
#include <Trade\OrderInfo.mqh>

#define D "QPA_"   
#define OV "QPA_OV_"

//=====================================================================
//  INSTITUTIONAL COLOR PALETTE - HIGH CONTRAST
//=====================================================================
#define C_CHART_BG      C'5,5,5'        
#define C_PANEL_BG      C'8,15,35'      
#define C_PANEL_DARK    C'5,10,25'      
#define C_HEADER        C'0,255,255'    
#define C_VALUE         C'255,255,255'  
#define C_POSITIVE      C'0,255,100'    
#define C_WARNING       C'255,180,0'    
#define C_NEGATIVE      C'255,50,50'    
#define C_NEUTRAL       C'120,120,140'  
#define C_ACCENT        C'0,200,255'    
#define C_BORDER        C'30,60,100'    

#define C_BULLISH       C'0,255,100'
#define C_BEARISH       C'255,50,50'
#define C_BSL           C'100,150,255'  
#define C_SSL           C'255,100,150'  
#define C_OB_BULL       C'0,200,80'     
#define C_OB_BEAR       C'200,0,80'     
#define C_FVG           C'255,200,0'    

#define C_ASIA          C'138,43,226'   
#define C_LONDON        C'30,144,255'   
#define C_NY            C'255,140,0'    
#define C_OVERLAP       C'255,215,0'    

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

enum ENUM_STRUCTURE
{
   STRUCT_NONE,
   STRUCT_BOS_BULL,     
   STRUCT_BOS_BEAR,     
   STRUCT_CHOCH_BULL,   
   STRUCT_CHOCH_BEAR,   
   STRUCT_MSS_BULL,     
   STRUCT_MSS_BEAR      
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
   double   bslLevel;           
   double   sslLevel;           
   bool     bslActive;
   bool     sslActive;
};

struct SessionState
{
   ENUM_SESSION   current;
   double         sessionRangeATRRatio;
   double         sessionVolatilityScore;
   ENUM_STRATEGY  preferredStrategy;
   double         strategyWeight;
   bool           isOverlap;    
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
   double   winRate;
   double   profitFactor;
   double   expectancyR;
   double   sharpeProxy;
   bool     enabled;
   double   influenceMultiplier;
   datetime lastDegradedTime;
   double   score;              
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

struct MarketStructure
{
   ENUM_STRUCTURE   type;
   double           price;
   datetime         time;
   bool             active;
};

struct VolumeAnalysis
{
   double   currentVolume;
   double   avgVolume;
   double   volumeRatio;        
   bool     institutionalActivity;
   bool     volumeSpike;
};

struct TradeQualityMetrics
{
   double   trendScore;
   double   liquidityScore;
   double   volumeScore;
   double   sessionScore;
   double   structureScore;
   double   totalScore;
};

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

input group "╔══════  AI ANALYST DISPLAY  ══════╗"
input bool     InpShowIntelligencePanel = true;    
input bool     InpShowCommentary        = true;    
input bool     InpShowQualityCard       = true;    
input bool     InpShowHeatmap           = true;    
input int      InpDashX                 = 10;
input int      InpDashY                 = 10;

input group "╔══════  VISUAL INTELLIGENCE OVERLAYS  ══════╗"
input bool     InpDrawSessionBoxes      = true;
input bool     InpDrawLiquidityZones    = true;
input bool     InpDrawLiquidityPools    = true;    
input bool     InpDrawStructureLabels   = true;    
input bool     InpDrawSignalMarkers     = true;
input bool     InpDrawVolumeSpikes      = true;
input int      InpOverlayLookbackHrs    = 24;

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
RegimeState         g_regime;
VolatilityState     g_vol;
LiquidityState      g_liq;
SessionState        g_session;
MTFBias             g_mtf;
ENUM_NEWS_STATE     g_newsState = NEWS_NORMAL;
RiskState           g_risk;
MasterDecision      g_lastDecision;
VolumeAnalysis      g_volume;
TradeQualityMetrics g_quality;

StrategyHealth      g_health[5];   
ExecutionQuality    g_execQuality;

MarketStructure     g_lastStructure;
string              g_aiCommentary = "";

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
datetime    g_lastCommentaryUpdate = 0;

//=====================================================================
//  ADAPTIVE PARAMETER STATE 
//=====================================================================
double      g_adaptiveRegimeConfThreshold;  
double      g_adaptiveExecScoreThreshold;   

//=====================================================================
//  DASHBOARD / STATUS
//=====================================================================
string      g_statusText  = "INITIALIZING";
color       g_statusColor = C_WARNING;
string      g_lastAction  = "Starting AI Market Analyst...";

//=====================================================================
//  PERFORMANCE ANALYTICS 
//=====================================================================
double      g_sessionProfit   = 0.0;
int         g_sessionWins     = 0;
int         g_sessionLosses   = 0;

//=====================================================================
//  DPI SCALING FACTOR
//=====================================================================
double      g_dpiScale = 1.0;

//=====================================================================
//  DASHBOARD DIMENSIONS
//=====================================================================
const int   PANEL_WIDTH = 420;
const int   INTEL_PANEL_HEIGHT = 280;
const int   COMMENTARY_PANEL_HEIGHT = 200;
const int   QUALITY_CARD_HEIGHT = 180;
const int   HEATMAP_HEIGHT = 160;

//=====================================================================
//  FONT SETTINGS
//=====================================================================
const string FONT_HEADER = "Segoe UI Bold";
const string FONT_VALUE  = "Segoe UI Bold";
const string FONT_LABEL  = "Segoe UI";
const int    FONT_SIZE_HEADER = 12;
const int    FONT_SIZE_VALUE  = 10;
const int    FONT_SIZE_DECISION = 18;
const int    FONT_SIZE_CHART_LABEL = 14;

//=====================================================================
//  REGIME TRACKING
//=====================================================================
double g_regimeStreakBars = 0;
ENUM_REGIME g_regimePersistTrack = REGIME_RANGING;

//=====================================================================
//  NEWS PROXY TRACKING
//=====================================================================
double g_spreadHistory[20];
int    g_spreadHistCount = 0;

//=====================================================================
//  HELPER FUNCTIONS
//=====================================================================

datetime DayStart(datetime ts)
{
   MqlDateTime d; 
   TimeToStruct(ts, d);
   return ts - (datetime)(d.hour*3600 + d.min*60 + d.sec);
}

datetime WeekStart(datetime ts)
{
   MqlDateTime d; 
   TimeToStruct(ts, d);
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

void DetectDPIScale()
{
   int chartWidth = (int)ChartGetInteger(0, CHART_WIDTH_IN_PIXELS);
   
   if(chartWidth > 3000)      g_dpiScale = 2.0;   
   else if(chartWidth > 2000) g_dpiScale = 1.5;   
   else if(chartWidth > 1500) g_dpiScale = 1.25;  
   else                       g_dpiScale = 1.0;   
}

int ScaleFont(int baseSize)
{
   return (int)MathRound((double)baseSize * g_dpiScale);
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

void UpdateSessionIntelligence()
{
   g_session.current = ClassifySession(TimeCurrent());
   
   g_session.isOverlap = (g_session.current == SESSION_LONDON_MID || 
                          g_session.current == SESSION_NY_OPEN);

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

   int biases[4];
   biases[0] = g_mtf.h1Bias;
   biases[1] = g_mtf.m15Bias;
   biases[2] = g_mtf.m5Bias;
   biases[3] = g_mtf.m1Bias;
   
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
//  STRUCTURE HELPERS
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
//  MARKET STRUCTURE DETECTION
//=====================================================================

void DetectMarketStructure()
{
   double swingHighs[10];
   datetime swingHighTimes[10];
   double swingLows[10];
   datetime swingLowTimes[10];
   
   int nHighs = FindSwingHighs(20, 2, swingHighs, swingHighTimes);
   int nLows  = FindSwingLows(20, 2, swingLows, swingLowTimes);
   
   if(nHighs < 2 || nLows < 2) return;
   
   double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   
   if(currentPrice > swingHighs[0] && g_mtf.m5Bias > 0)
   {
      g_lastStructure.type = STRUCT_BOS_BULL;
      g_lastStructure.price = swingHighs[0];
      g_lastStructure.time = TimeCurrent();
      g_lastStructure.active = true;
   }
   else if(currentPrice < swingLows[0] && g_mtf.m5Bias < 0)
   {
      g_lastStructure.type = STRUCT_BOS_BEAR;
      g_lastStructure.price = swingLows[0];
      g_lastStructure.time = TimeCurrent();
      g_lastStructure.active = true;
   }
   else if(currentPrice > swingHighs[0] && g_mtf.m5Bias < 0)
   {
      g_lastStructure.type = STRUCT_CHOCH_BULL;
      g_lastStructure.price = swingHighs[0];
      g_lastStructure.time = TimeCurrent();
      g_lastStructure.active = true;
   }
   else if(currentPrice < swingLows[0] && g_mtf.m5Bias > 0)
   {
      g_lastStructure.type = STRUCT_CHOCH_BEAR;
      g_lastStructure.price = swingLows[0];
      g_lastStructure.time = TimeCurrent();
      g_lastStructure.active = true;
   }
}

string StructureToString(ENUM_STRUCTURE s)
{
   switch(s)
   {
      case STRUCT_BOS_BULL:   return "BOS ↑";
      case STRUCT_BOS_BEAR:   return "BOS ↓";
      case STRUCT_CHOCH_BULL: return "CHOCH ↑";
      case STRUCT_CHOCH_BEAR: return "CHOCH ↓";
      case STRUCT_MSS_BULL:   return "MSS ↑";
      case STRUCT_MSS_BEAR:   return "MSS ↓";
      default:                return "";
   }
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

//=====================================================================
//  VOLUME ENGINE
//=====================================================================

void UpdateVolumeAnalysis()
{
   long volumeBuf[];
   ArrayResize(volumeBuf, 20);
   ArraySetAsSeries(volumeBuf, true);
   
   int got = CopyTickVolume(_Symbol, PERIOD_M5, 0, 20, volumeBuf);
   if(got < 10)
   {
      g_volume.currentVolume = 0;
      g_volume.avgVolume = 0;
      g_volume.volumeRatio = 1.0;
      g_volume.institutionalActivity = false;
      g_volume.volumeSpike = false;
      return;
   }
   
   g_volume.currentVolume = (double)volumeBuf[0];
   
   double sum = 0;
   for(int i = 1; i < got; i++) sum += volumeBuf[i];
   g_volume.avgVolume = sum / (got - 1);
   
   if(g_volume.avgVolume > 0)
      g_volume.volumeRatio = g_volume.currentVolume / g_volume.avgVolume;
   else
      g_volume.volumeRatio = 1.0;
   
   g_volume.institutionalActivity = (g_volume.volumeRatio > 1.5);
   g_volume.volumeSpike = (g_volume.volumeRatio > 2.0);
}

//=====================================================================
//  NEWS SHOCK PROXY
//=====================================================================

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
//  LIQUIDITY ENGINE
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

   g_liq.bslActive = false;
   if(nHighs > 0)
   {
      g_liq.bslLevel = swingHighPrices[0];
      g_liq.bslActive = (g_liq.bslLevel > price);
   }
   
   g_liq.sslActive = false;
   if(nLows > 0)
   {
      g_liq.sslLevel = swingLowPrices[0];
      g_liq.sslActive = (g_liq.sslLevel < price);
   }

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
//  REGIME CLASSIFICATION
//=====================================================================

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
   ENUM_REGIME candidates[10];
   candidates[0] = REGIME_TRENDING;
   candidates[1] = REGIME_RANGING;
   candidates[2] = REGIME_BREAKOUT;
   candidates[3] = REGIME_COMPRESSION;
   candidates[4] = REGIME_EXPANSION;
   candidates[5] = REGIME_VOLATILITY_SHOCK;
   candidates[6] = REGIME_LIQUIDITY_SWEEP;
   candidates[7] = REGIME_EXHAUSTION;
   candidates[8] = REGIME_MEAN_REVERSION;
   candidates[9] = REGIME_UNSAFE;
   
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
      case REGIME_TRENDING:         return "TREND CONTINUATION";
      case REGIME_RANGING:          return "RANGE MARKET";
      case REGIME_BREAKOUT:         return "BREAKOUT";
      case REGIME_COMPRESSION:      return "COMPRESSION";
      case REGIME_EXPANSION:        return "TREND EXPANSION";
      case REGIME_VOLATILITY_SHOCK: return "VOLATILITY SHOCK";
      case REGIME_LIQUIDITY_SWEEP:  return "LIQUIDITY HUNT";
      case REGIME_EXHAUSTION:       return "EXHAUSTION";
      case REGIME_MEAN_REVERSION:   return "MEAN REVERSION";
      case REGIME_UNSAFE:           return "UNSAFE CONDITIONS";
      default:                      return "UNKNOWN";
   }
}

//=====================================================================
//  TRADE QUALITY SCORING
//=====================================================================

void CalculateTradeQuality()
{
   g_quality.trendScore = g_mtf.alignment;
   
   double liqScore = 0;
   if(g_liq.bslActive || g_liq.sslActive) liqScore += 30;
   if(g_liq.sweepUpDetected || g_liq.sweepDownDetected) liqScore += 40;
   liqScore += g_liq.pressureScore * 0.3;
   g_quality.liquidityScore = MathMin(100.0, liqScore);
   
   g_quality.volumeScore = MathMin(100.0, g_volume.volumeRatio * 50.0);
   if(g_volume.institutionalActivity) g_quality.volumeScore += 20;
   g_quality.volumeScore = MathMin(100.0, g_quality.volumeScore);
   
   double sessScore = 50;
   if(g_session.isOverlap) sessScore = 95;
   else if(g_session.current == SESSION_LONDON_OPEN || g_session.current == SESSION_NY_OPEN) sessScore = 85;
   else if(g_session.current == SESSION_DEAD_ZONE) sessScore = 20;
   g_quality.sessionScore = sessScore;
   
   double structScore = 50;
   if(g_lastStructure.active)
   {
      if(g_lastStructure.type == STRUCT_BOS_BULL || g_lastStructure.type == STRUCT_BOS_BEAR)
         structScore = 90;
      else if(g_lastStructure.type == STRUCT_CHOCH_BULL || g_lastStructure.type == STRUCT_CHOCH_BEAR)
         structScore = 75;
   }
   g_quality.structureScore = structScore;
   
   g_quality.totalScore = (g_quality.trendScore * 0.25 +
                           g_quality.liquidityScore * 0.25 +
                           g_quality.volumeScore * 0.20 +
                           g_quality.sessionScore * 0.15 +
                           g_quality.structureScore * 0.15);
}

//=====================================================================
//  AI COMMENTARY ENGINE
//=====================================================================

void GenerateAICommentary()
{
   string commentary = "";
   
   commentary += "Market is in " + RegimeToString(g_regime.regime) + " phase.\n\n";
   
   if(g_lastStructure.active)
   {
      commentary += "Price recently printed a " + StructureToString(g_lastStructure.type) + ".\n\n";
   }
   
   if(g_liq.sweepUpDetected)
      commentary += "Buy Side Liquidity sweep detected.\n\n";
   else if(g_liq.sweepDownDetected)
      commentary += "Sell Side Liquidity sweep detected.\n\n";
   else if(g_liq.bslActive && g_liq.sslActive)
      commentary += "Both BSL and SSL pools present.\n\n";
   
   if(g_volume.institutionalActivity)
      commentary += "Institutional volume detected.\n\n";
   else if(g_volume.volumeRatio > 1.2)
      commentary += "Volume above average.\n\n";
   else if(g_volume.volumeRatio < 0.8)
      commentary += "Volume below average.\n\n";
   
   if(g_session.isOverlap)
      commentary += "London-NY overlap active - High opportunity window.\n\n";
   
   ENUM_STRATEGY routedStrat = RouteRegimeToStrategy(g_regime.regime);
   if(routedStrat != STRAT_NONE)
   {
      commentary += "Active strategy: " + StrategyToString(routedStrat) + ".\n\n";
   }
   
   commentary += "Trade quality score: " + DoubleToString(g_quality.totalScore, 0) + "/100.\n\n";
   
   string bias = "NEUTRAL";
   if(g_mtf.m5Bias > 0 && g_mtf.h1Bias > 0) bias = "BULLISH";
   else if(g_mtf.m5Bias < 0 && g_mtf.h1Bias < 0) bias = "BEARISH";
   
   commentary += "Bias: " + bias + ".";
   
   g_aiCommentary = commentary;
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
      case STRAT_TREND_SCALPER:        return "Trend Pullback Scalper";
      case STRAT_MEAN_REVERSION:       return "Mean Reversion";
      case STRAT_VOLATILITY_EXPANSION: return "Volatility Expansion";
      case STRAT_LIQUIDITY_REVERSAL:   return "Liquidity Sweep Reversal";
      case STRAT_COMPRESSION_BREAKOUT: return "Compression Breakout";
      default:                         return "None";
   }
}

//=====================================================================
//  RISK GOVERNANCE
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
//  STRATEGY HEALTH
//=====================================================================

void InitStrategyHealth()
{
   string names[5];
   names[0] = "Trend Scalper";
   names[1] = "Mean Reversion";
   names[2] = "Vol Expansion";
   names[3] = "Liq Reversal";
   names[4] = "Compression";
   
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
      g_health[i].score = 100;
   }
}

//=====================================================================
//  ADAPTIVE PARAMS
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

   double nudge = 0.0;
   if(g_regime.confidence > g_adaptiveRegimeConfThreshold + 15.0) nudge = 0.15;
   else if(g_regime.confidence < g_adaptiveRegimeConfThreshold - 15.0) nudge = -0.15;

   g_adaptiveRegimeConfThreshold = MathMax(regimeBoundLow, MathMin(regimeBoundHigh, g_adaptiveRegimeConfThreshold + nudge));
}

//=====================================================================
//  EXECUTION QUALITY
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
//  MASTER DECISION
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
   d.narrative = "HOLD - No valid signal";

   return d;
}

void RunMasterDecisionCycle()
{
   g_lastDecision = BuildMasterDecision();
}

//=====================================================================
//  DASHBOARD GRAPHICS
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
         
      ObjectSetInteger(0, n, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, n, OBJPROP_HIDDEN, true);
   }
}

void L(string nm, int x, int y, string txt, color clr, int fsz, string fnt="FONT_VALUE")
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
      ObjectSetInteger(0, n, OBJPROP_FONTSIZE, ScaleFont(fsz));
      ObjectSetString (0, n, OBJPROP_FONT, fnt);
      ObjectSetInteger(0, n, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, n, OBJPROP_HIDDEN, true);
   }
}

void U(string nm, string txt, color clr=C_VALUE)
{
   string n = D + nm;
   if(ObjectFind(0, n) >= 0)
   {
      ObjectSetString(0, n, OBJPROP_TEXT, txt);
      ObjectSetInteger(0, n, OBJPROP_COLOR, clr);
   }
}

void HeatBar(string nm, int x, int y, int w, int h, double pct, string label)
{
   R(nm + "_bg", x, y, w + 100, h, C_PANEL_DARK, C_BORDER, 1);
   
   int barWidth = (int)((pct / 100.0) * w);
   color barColor = (pct >= 90) ? C_POSITIVE : (pct >= 70) ? C_WARNING : C_NEGATIVE;
   
   R(nm + "_bar", x + 2, y + 2, barWidth, h - 4, barColor, clrNONE);
   L(nm + "_lbl", x + 5, y + (h/2) - 5, label, C_VALUE, 9, FONT_VALUE);
   L(nm + "_val", x + w + 10, y + (h/2) - 5, DoubleToString(pct, 0), C_VALUE, 9, FONT_VALUE);
}

void InitIntelligencePanel()
{
   int X = InpDashX;
   int Y = InpDashY;
   
   R("intel_frame", X, Y, PANEL_WIDTH, INTEL_PANEL_HEIGHT, C_PANEL_BG, C_BORDER, 2);
   L("intel_header", X + 10, Y + 8, "MARKET INTELLIGENCE ENGINE", C_HEADER, FONT_SIZE_HEADER, FONT_HEADER);
   
   int yRow = Y + 35;
   L("lbl_regime", X + 10, yRow, "REGIME:", C_HEADER, FONT_SIZE_VALUE);
   L("val_regime", X + 120, yRow, "Initializing...", C_VALUE, FONT_SIZE_VALUE);
   
   yRow += 25;
   L("lbl_confidence", X + 10, yRow, "CONFIDENCE:", C_HEADER, FONT_SIZE_VALUE);
   L("val_confidence", X + 120, yRow, "0%", C_POSITIVE, FONT_SIZE_VALUE);
   
   yRow += 25;
   L("lbl_session", X + 10, yRow, "SESSION:", C_HEADER, FONT_SIZE_VALUE);
   L("val_session", X + 120, yRow, "--", C_VALUE, FONT_SIZE_VALUE);
   
   yRow += 25;
   L("lbl_strategy", X + 10, yRow, "ACTIVE STRATEGY:", C_HEADER, FONT_SIZE_VALUE);
   L("val_strategy", X + 180, yRow, "None", C_VALUE, FONT_SIZE_VALUE);
   
   yRow += 25;
   L("lbl_tradequality", X + 10, yRow, "TRADE QUALITY:", C_HEADER, FONT_SIZE_VALUE);
   L("val_tradequality", X + 180, yRow, "0/100", C_WARNING, FONT_SIZE_VALUE);
   
   yRow += 30;
   R("decision_panel", X + 10, yRow, PANEL_WIDTH - 20, 50, C_PANEL_DARK, C_ACCENT, 2);
   L("lbl_decision_hdr", X + 20, yRow + 5, "DECISION:", C_HEADER, 10);
   L("val_decision", X + 120, yRow + 12, "HOLD", C_WARNING, FONT_SIZE_DECISION, FONT_HEADER);
}

void InitCommentaryPanel()
{
   int X = InpDashX;
   int Y = InpDashY + INTEL_PANEL_HEIGHT + 10;
   
   R("comment_frame", X, Y, PANEL_WIDTH, COMMENTARY_PANEL_HEIGHT, C_PANEL_BG, C_BORDER, 2);
   L("comment_header", X + 10, Y + 8, "AI MARKET COMMENTARY", C_HEADER, FONT_SIZE_HEADER, FONT_HEADER);
   
   L("comment_line1", X + 10, Y + 35, "", C_VALUE, 9);
   L("comment_line2", X + 10, Y + 52, "", C_VALUE, 9);
   L("comment_line3", X + 10, Y + 69, "", C_VALUE, 9);
   L("comment_line4", X + 10, Y + 86, "", C_VALUE, 9);
   L("comment_line5", X + 10, Y + 103, "", C_VALUE, 9);
   L("comment_line6", X + 10, Y + 120, "", C_VALUE, 9);
   L("comment_line7", X + 10, Y + 137, "", C_VALUE, 9);
   L("comment_line8", X + 10, Y + 154, "", C_VALUE, 9);
   L("comment_line9", X + 10, Y + 171, "", C_VALUE, 9);
}

void InitQualityCard()
{
   int X = InpDashX;
   int Y = InpDashY + INTEL_PANEL_HEIGHT + COMMENTARY_PANEL_HEIGHT + 20;
   
   R("quality_frame", X, Y, PANEL_WIDTH, QUALITY_CARD_HEIGHT, C_PANEL_BG, C_BORDER, 2);
   L("quality_header", X + 10, Y + 8, "TRADE QUALITY METRICS", C_HEADER, FONT_SIZE_HEADER, FONT_HEADER);
   
   int yRow = Y + 35;
   L("quality_trend_lbl", X + 10, yRow, "Trend Strength", C_HEADER, 9);
   L("quality_trend_val", X + 350, yRow, "0", C_VALUE, 9);
   
   yRow += 20;
   L("quality_liq_lbl", X + 10, yRow, "Liquidity Quality", C_HEADER, 9);
   L("quality_liq_val", X + 350, yRow, "0", C_VALUE, 9);
   
   yRow += 20;
   L("quality_vol_lbl", X + 10, yRow, "Volume", C_HEADER, 9);
   L("quality_vol_val", X + 350, yRow, "0", C_VALUE, 9);
   
   yRow += 20;
   L("quality_sess_lbl", X + 10, yRow, "Session", C_HEADER, 9);
   L("quality_sess_val", X + 350, yRow, "0", C_VALUE, 9);
   
   yRow += 20;
   L("quality_struct_lbl", X + 10, yRow, "Structure", C_HEADER, 9);
   L("quality_struct_val", X + 350, yRow, "0", C_VALUE, 9);
   
   yRow += 30;
   R("quality_total_bg", X + 10, yRow, PANEL_WIDTH - 20, 30, C_PANEL_DARK, C_ACCENT, 2);
   L("quality_total_lbl", X + 20, yRow + 8, "TOTAL SCORE:", C_HEADER, 11, FONT_HEADER);
   L("quality_total_val", X + 250, yRow + 8, "0 / 100", C_POSITIVE, 11, FONT_HEADER);
}

void InitHeatmap()
{
   int X = InpDashX;
   int Y = InpDashY + INTEL_PANEL_HEIGHT + COMMENTARY_PANEL_HEIGHT + QUALITY_CARD_HEIGHT + 30;
   
   R("heatmap_frame", X, Y, PANEL_WIDTH, HEATMAP_HEIGHT, C_PANEL_BG, C_BORDER, 2);
   L("heatmap_header", X + 10, Y + 8, "MARKET CONDITIONS HEATMAP", C_HEADER, FONT_SIZE_HEADER, FONT_HEADER);
   
   int yRow = Y + 35;
   HeatBar("heat_trend", X + 10, yRow, 250, 18, 0, "Trend Strength");
   
   yRow += 23;
   HeatBar("heat_liq", X + 10, yRow, 250, 18, 0, "Liquidity Quality");
   
   yRow += 23;
   HeatBar("heat_momentum", X + 10, yRow, 250, 18, 0, "Momentum");
   
   yRow += 23;
   HeatBar("heat_vol", X + 10, yRow, 250, 18, 0, "Volatility");
   
   yRow += 23;
   HeatBar("heat_struct", X + 10, yRow, 250, 18, 0, "Structure Clarity");
}

void UpdateIntelligencePanel()
{
   U("val_regime", RegimeToString(g_regime.regime), C_ACCENT);
   U("val_confidence", DoubleToString(g_regime.confidence, 0) + "%", 
     (g_regime.confidence >= 75) ? C_POSITIVE : (g_regime.confidence >= 55) ? C_WARNING : C_NEGATIVE);
   
   string sessionText = SessionToString(g_session.current);
   if(g_session.isOverlap) sessionText += " [OVERLAP]";
   U("val_session", sessionText, g_session.isOverlap ? C_WARNING : C_VALUE);
   
   ENUM_STRATEGY routed = RouteRegimeToStrategy(g_regime.regime);
   U("val_strategy", StrategyToString(routed), (routed != STRAT_NONE) ? C_ACCENT : C_NEUTRAL);
   
   color qualityColor = (g_quality.totalScore >= 80) ? C_POSITIVE : (g_quality.totalScore >= 60) ? C_WARNING : C_NEGATIVE;
   U("val_tradequality", DoubleToString(g_quality.totalScore, 0) + "/100", qualityColor);
   
   bool tradeNow = g_lastDecision.tradeApproved;
   string decisionWord = tradeNow ? (g_lastDecision.direction == DIR_LONG ? "BUY" : "SELL") : "HOLD";
   color decisionColor = tradeNow ? (g_lastDecision.direction == DIR_LONG ? C_POSITIVE : C_NEGATIVE) : C_WARNING;
   U("val_decision", decisionWord, decisionColor);
   
   color decBg = tradeNow ? ((g_lastDecision.direction == DIR_LONG) ? C'0,50,20' : C'50,0,20') : C_PANEL_DARK;
   ObjectSetInteger(0, D+"decision_panel", OBJPROP_BGCOLOR, decBg);
}

void UpdateCommentaryPanel()
{
   string lines[];
   int lineCount = StringSplit(g_aiCommentary, '\n', lines);
   
   for(int i = 0; i < 9; i++)
   {
      string text = (i < lineCount) ? lines[i] : "";
      U("comment_line" + IntegerToString(i + 1), text, C_VALUE);
   }
}

void UpdateQualityCard()
{
   U("quality_trend_val", DoubleToString(g_quality.trendScore, 0), C_VALUE);
   U("quality_liq_val", DoubleToString(g_quality.liquidityScore, 0), C_VALUE);
   U("quality_vol_val", DoubleToString(g_quality.volumeScore, 0), C_VALUE);
   U("quality_sess_val", DoubleToString(g_quality.sessionScore, 0), C_VALUE);
   U("quality_struct_val", DoubleToString(g_quality.structureScore, 0), C_VALUE);
   
   color totalColor = (g_quality.totalScore >= 80) ? C_POSITIVE : (g_quality.totalScore >= 60) ? C_WARNING : C_NEGATIVE;
   U("quality_total_val", DoubleToString(g_quality.totalScore, 0) + " / 100", totalColor);
}

void UpdateHeatmap()
{
   double trendPct = g_quality.trendScore;
   int trendWidth = (int)((trendPct / 100.0) * 250);
   color trendColor = (trendPct >= 90) ? C_POSITIVE : (trendPct >= 70) ? C_WARNING : C_NEGATIVE;
   ObjectSetInteger(0, D+"heat_trend_bar", OBJPROP_XSIZE, trendWidth);
   ObjectSetInteger(0, D+"heat_trend_bar", OBJPROP_BGCOLOR, trendColor);
   U("heat_trend_val", DoubleToString(trendPct, 0), C_VALUE);
   
   double liqPct = g_quality.liquidityScore;
   int liqWidth = (int)((liqPct / 100.0) * 250);
   color liqColor = (liqPct >= 90) ? C_POSITIVE : (liqPct >= 70) ? C_WARNING : C_NEGATIVE;
   ObjectSetInteger(0, D+"heat_liq_bar", OBJPROP_XSIZE, liqWidth);
   ObjectSetInteger(0, D+"heat_liq_bar", OBJPROP_BGCOLOR, liqColor);
   U("heat_liq_val", DoubleToString(liqPct, 0), C_VALUE);
   
   double momPct = g_mtf.alignment;
   int momWidth = (int)((momPct / 100.0) * 250);
   color momColor = (momPct >= 90) ? C_POSITIVE : (momPct >= 70) ? C_WARNING : C_NEGATIVE;
   ObjectSetInteger(0, D+"heat_momentum_bar", OBJPROP_XSIZE, momWidth);
   ObjectSetInteger(0, D+"heat_momentum_bar", OBJPROP_BGCOLOR, momColor);
   U("heat_momentum_val", DoubleToString(momPct, 0), C_VALUE);
   
   double volPct = g_vol.percentile;
   int volWidth = (int)((volPct / 100.0) * 250);
   color volColor = (volPct >= 90) ? C_POSITIVE : (volPct >= 70) ? C_WARNING : C_NEGATIVE;
   ObjectSetInteger(0, D+"heat_vol_bar", OBJPROP_XSIZE, volWidth);
   ObjectSetInteger(0, D+"heat_vol_bar", OBJPROP_BGCOLOR, volColor);
   U("heat_vol_val", DoubleToString(volPct, 0), C_VALUE);
   
   double structPct = g_quality.structureScore;
   int structWidth = (int)((structPct / 100.0) * 250);
   color structColor = (structPct >= 90) ? C_POSITIVE : (structPct >= 70) ? C_WARNING : C_NEGATIVE;
   ObjectSetInteger(0, D+"heat_struct_bar", OBJPROP_XSIZE, structWidth);
   ObjectSetInteger(0, D+"heat_struct_bar", OBJPROP_BGCOLOR, structColor);
   U("heat_struct_val", DoubleToString(structPct, 0), C_VALUE);
}

void InitAIAnalystDashboard()
{
   if(MQLInfoInteger(MQL_TESTER) && !MQLInfoInteger(MQL_VISUAL_MODE)) 
   {
      Print("AI Analyst Dashboard disabled in non-visual tester");
      return;
   }

   DetectDPIScale();
   
   if(InpShowIntelligencePanel) InitIntelligencePanel();
   if(InpShowCommentary) InitCommentaryPanel();
   if(InpShowQualityCard) InitQualityCard();
   if(InpShowHeatmap) InitHeatmap();
   
   ChartRedraw(0);
   Print("AI Analyst Dashboard initialized | DPI Scale: ", g_dpiScale);
}

void UpdateAIAnalystDashboard()
{
   if(MQLInfoInteger(MQL_TESTER) && !MQLInfoInteger(MQL_VISUAL_MODE)) return;
   
   if(InpShowIntelligencePanel) UpdateIntelligencePanel();
   if(InpShowCommentary) UpdateCommentaryPanel();
   if(InpShowQualityCard) UpdateQualityCard();
   if(InpShowHeatmap) UpdateHeatmap();
}

void DeleteAIAnalystDashboard()
{
   ObjectsDeleteAll(0, D);
   ChartRedraw(0);
}

//=====================================================================
//  VISUAL OVERLAYS
//=====================================================================

void DrawLabelWithBackground(string name, datetime time, double price, string text, color bgColor, color textColor)
{
   string objName = OV + name;
   ObjectDelete(0, objName);
   
   if(ObjectCreate(0, objName, OBJ_TEXT, 0, time, price))
   {
      ObjectSetString(0, objName, OBJPROP_TEXT, " " + text + " ");
      ObjectSetInteger(0, objName, OBJPROP_COLOR, textColor);
      ObjectSetInteger(0, objName, OBJPROP_FONTSIZE, ScaleFont(FONT_SIZE_CHART_LABEL));
      ObjectSetString(0, objName, OBJPROP_FONT, FONT_HEADER);
      ObjectSetInteger(0, objName, OBJPROP_BACK, false);
      ObjectSetInteger(0, objName, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, objName, OBJPROP_HIDDEN, true);
   }
}

void DrawLiquidityPools()
{
   if(!InpDrawLiquidityPools) return;
   
   datetime now = TimeCurrent();
   datetime past = now - (datetime)(InpOverlayLookbackHrs * 3600);
   
   if(g_liq.bslActive)
   {
      string bslName = OV + "BSL_LINE";
      ObjectDelete(0, bslName);
      
      if(ObjectCreate(0, bslName, OBJ_TREND, 0, past, g_liq.bslLevel, now, g_liq.bslLevel))
      {
         ObjectSetInteger(0, bslName, OBJPROP_COLOR, C_BSL);
         ObjectSetInteger(0, bslName, OBJPROP_STYLE, STYLE_DASH);
         ObjectSetInteger(0, bslName, OBJPROP_WIDTH, 2);
         ObjectSetInteger(0, bslName, OBJPROP_BACK, true);
         ObjectSetInteger(0, bslName, OBJPROP_SELECTABLE, false);
         ObjectSetInteger(0, bslName, OBJPROP_HIDDEN, true);
         ObjectSetInteger(0, bslName, OBJPROP_RAY_RIGHT, true);
      }
      
      DrawLabelWithBackground("BSL_LABEL", now, g_liq.bslLevel, "BSL", C_BSL, C_VALUE);
   }
   
   if(g_liq.sslActive)
   {
      string sslName = OV + "SSL_LINE";
      ObjectDelete(0, sslName);
      
      if(ObjectCreate(0, sslName, OBJ_TREND, 0, past, g_liq.sslLevel, now, g_liq.sslLevel))
      {
         ObjectSetInteger(0, sslName, OBJPROP_COLOR, C_SSL);
         ObjectSetInteger(0, sslName, OBJPROP_STYLE, STYLE_DASH);
         ObjectSetInteger(0, sslName, OBJPROP_WIDTH, 2);
         ObjectSetInteger(0, sslName, OBJPROP_BACK, true);
         ObjectSetInteger(0, sslName, OBJPROP_SELECTABLE, false);
         ObjectSetInteger(0, sslName, OBJPROP_HIDDEN, true);
         ObjectSetInteger(0, sslName, OBJPROP_RAY_RIGHT, true);
      }
      
      DrawLabelWithBackground("SSL_LABEL", now, g_liq.sslLevel, "SSL", C_SSL, C_VALUE);
   }
}

void DrawStructureLabels()
{
   if(!InpDrawStructureLabels) return;
   if(!g_lastStructure.active) return;
   
   int barsSince = iBarShift(_Symbol, PERIOD_M5, g_lastStructure.time, false);
   if(barsSince > 20) 
   {
      g_lastStructure.active = false;
      return;
   }
   
   color structColor = (g_lastStructure.type == STRUCT_BOS_BULL || g_lastStructure.type == STRUCT_CHOCH_BULL) ? C_BULLISH : C_BEARISH;
   
   DrawLabelWithBackground("STRUCTURE", g_lastStructure.time, g_lastStructure.price, 
                          StructureToString(g_lastStructure.type), structColor, C_VALUE);
}

void UpdateVisualOverlays()
{
   DrawLiquidityPools();
   DrawStructureLabels();
}

void DeleteVisualOverlays()
{
   ObjectsDeleteAll(0, OV);
}

//=====================================================================
//  EA LIFECYCLE
//=====================================================================

int OnInit()
{
   ChartSetInteger(0, CHART_COLOR_BACKGROUND, C_CHART_BG);
   ChartSetInteger(0, CHART_COLOR_FOREGROUND, C_VALUE);
   ChartSetInteger(0, CHART_COLOR_GRID, C'10,10,10');
   ChartSetInteger(0, CHART_SHOW_GRID, false);
   
   if(InpLiquidityLookback > 60)
   {
      Print("ERROR: InpLiquidityLookback max 60");
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

   if(g_h1_ema_fast == INVALID_HANDLE || g_m5_atr == INVALID_HANDLE)
   {
      Print("ERROR: Indicator initialization failed");
      return INIT_FAILED;
   }

   g_dayStart  = DayStart(TimeCurrent());
   g_weekStart = WeekStart(TimeCurrent());

   InitRiskState();
   InitStrategyHealth();
   InitAdaptiveParams();
   
   g_lastStructure.active = false;

   InitAIAnalystDashboard();
   
   EventSetTimer(1);

   Print("═══════════════════════════════════════════════════");
   Print("  QUANTUM PLUS AI v1.03 - INSTITUTIONAL EDITION");
   Print("  AI Market Analyst | Enhanced Visibility");
   Print("═══════════════════════════════════════════════════");

   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
   Print("═══ AI ANALYST SESSION SUMMARY ═══");
   
   EventKillTimer();
   DeleteAIAnalystDashboard();
   DeleteVisualOverlays();

   IndicatorRelease(g_h1_ema_fast); IndicatorRelease(g_h1_ema_slow); IndicatorRelease(g_h1_atr);
   IndicatorRelease(g_m15_ema_fast); IndicatorRelease(g_m15_ema_slow); IndicatorRelease(g_m15_atr); IndicatorRelease(g_m15_rsi);
   IndicatorRelease(g_m5_ema_fast); IndicatorRelease(g_m5_ema_slow); IndicatorRelease(g_m5_atr); IndicatorRelease(g_m5_rsi);
   IndicatorRelease(g_m1_ema_fast); IndicatorRelease(g_m1_ema_slow); IndicatorRelease(g_m1_atr);
}

void OnTimer()
{
   UpdateAIAnalystDashboard();
}

void OnTick()
{
   RolloverDailyWeeklyIfNeeded();

   if(Bars(_Symbol, PERIOD_M5) < InpATRLookback + 5)
   {
      g_statusText = "BUFFERING";
      g_statusColor = C_WARNING;
      return;
   }

   bool isNewBar = IsNewBar();
   
   UpdateRiskState();
   
   if(isNewBar || TimeCurrent() - g_lastFullUpdate > 60)
   {
      UpdateMTFBias();
      UpdateVolatilityIntelligence();
      UpdateNewsShockProxy();
      UpdateVolumeAnalysis();
      UpdateLiquidityIntelligence();
      UpdateSessionIntelligence();
      UpdateRegimeClassification();
      DetectMarketStructure();
      CalculateTradeQuality();
      UpdateVisualOverlays();
      UpdateAdaptiveParams();
      
      g_lastFullUpdate = TimeCurrent();
   }
   
   if(TimeCurrent() - g_lastCommentaryUpdate > 30)
   {
      GenerateAICommentary();
      g_lastCommentaryUpdate = TimeCurrent();
   }
   
   UpdateExecutionQuality();
   RunMasterDecisionCycle();
}

void OnTradeTransaction(const MqlTradeTransaction &trans,
                         const MqlTradeRequest &request,
                         const MqlTradeResult &result)
{
   // Transaction handler placeholder
}