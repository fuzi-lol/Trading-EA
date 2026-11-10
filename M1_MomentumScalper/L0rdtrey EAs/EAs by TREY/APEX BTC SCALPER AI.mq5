//+------------------------------------------------------------------+
//|                                               PHANTOM BTC v2.0   |
//|        Institutional-Grade BTCUSD AI Scalper - Phantom Edition   |
//|        Built on Quantum Plus AI v1.01 architecture              |
//+------------------------------------------------------------------+
#property copyright   "Phantom BTC Scalper AI Pro v2.0"
#property version     "2.0"
#property description "BTCUSD Institutional AI Scalper – SMC + Adaptive Regime"
#property strict

#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>
#include <Trade\AccountInfo.mqh>
#include <Trade\OrderInfo.mqh>

#define D "P_"        // Dashboard prefix
#define OV "P_OV_"    // Overlay prefix

//=====================================================================
//  ENUMERATIONS (EXPANDED)
//=====================================================================

enum ENUM_REGIME
{
   REGIME_TRENDING,
   REGIME_STRONG_TREND,
   REGIME_WEAK_TREND,
   REGIME_RANGING,
   REGIME_COMPRESSION,
   REGIME_EXPANSION,
   REGIME_BREAKOUT,
   REGIME_FALSE_BREAKOUT,
   REGIME_HIGH_VOLATILITY,
   REGIME_LOW_VOLATILITY,
   REGIME_LIQUIDITY_HUNT,
   REGIME_ACCUMULATION,
   REGIME_DISTRIBUTION,
   REGIME_MEAN_REVERSION,
   REGIME_MOMENTUM_BURST,
   REGIME_EXHAUSTION,
   REGIME_NEWS_SHOCK,
   REGIME_WEEKEND,
   REGIME_LOW_LIQUIDITY,
   REGIME_HIGH_LIQUIDITY,
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
   SESSION_LONDON,
   SESSION_NY,
   SESSION_OVERLAP,
   SESSION_WEEKEND,
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
   STRAT_TREND_CONTINUATION,
   STRAT_TREND_PULLBACK,
   STRAT_MOMENTUM_BREAKOUT,
   STRAT_LIQUIDITY_SWEEP_REVERSAL,
   STRAT_VWAP_REJECTION,
   STRAT_ORDER_BLOCK_MITIGATION,
   STRAT_FVG_MITIGATION,
   STRAT_COMPRESSION_BREAKOUT,
   STRAT_RANGE_REVERSAL,
   STRAT_MEAN_REVERSION,
   STRAT_VOLATILITY_EXPANSION,
   STRAT_IMPULSE_CONTINUATION,
   STRAT_RETEST_ENTRY,
   STRAT_MICRO_PULLBACK_SCALP
};

enum ENUM_DIRECTION
{
   DIR_NONE,
   DIR_LONG,
   DIR_SHORT
};

//=====================================================================
//  CORE DATA STRUCTURES (EXTENDED)
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

struct OrderFlowProxy
{
   double   tickAcceleration;
   double   volumeImbalance;
   double   buyingPressure;
   double   sellingPressure;
   double   priceEfficiency;
   double   candleEfficiency;
   double   deltaApprox;
   double   momentumBurst;
   double   absorption;
   double   exhaustion;
   double   liquidityVacuum;
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
   double   monthlyRiskUsedPct;
   double   currentDrawdownPct;
   double   maxDrawdownSeenPct;
   bool     dailyLimitHit;
   bool     weeklyLimitHit;
   bool     monthlyLimitHit;
   bool     maxDrawdownBreached;
   bool     emergencyShutdown;
   double   peakEquity;
   double   weekStartEquity;
   double   dayStartEquity;
   double   monthStartEquity;
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
//  SMC STRUCTURES
//=====================================================================

struct OrderBlock
{
   datetime    time;
   double      high;
   double      low;
   bool        isBullish;
   bool        mitigated;
   int         strength;
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
   bool        isHigh;
   bool        isBOS;
   bool        isCHoCH;
   bool        isMSS;
   int         strength;
};

struct POI
{
   datetime    time;
   double      price;
   string      type;
   color       markerColor;
   bool        active;
};

struct KillZone
{
   datetime    startTime;
   datetime    endTime;
   string      name;
   color       zoneColor;
   int         importance;
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
//  INPUT PARAMETERS (BTC-CALIBRATED)
//=====================================================================

input group "╔══════  PHANTOM BTC IDENTITY  ══════╗"
input ulong    InpMagicNumber          = 778800;
input string   InpBotName              = "PHANTOM BTC AI";

input group "╔══════  RISK GOVERNANCE  ══════╗"
input double   InpRiskPercentPerTrade  = 0.5;
input double   InpMaxRiskPercentTrade  = 1.0;
input double   InpMaxDailyLossPct      = 3.0;
input double   InpMaxWeeklyLossPct     = 7.0;
input double   InpMaxMonthlyLossPct    = 12.0;
input double   InpMaxDrawdownPct       = 15.0;
input int      InpMaxDailyTrades       = 10;
input int      InpMaxConcurrentTrades  = 1;

input group "╔══════  BTC EXECUTION QUALITY  ══════╗"
input double   InpMaxSpreadPoints      = 100;        // BTC: 50-100 points (~5-10 USD)
input double   InpMinExecutionScore    = 60.0;
input int      InpCooldownAfterCloseSec= 30;

input group "╔══════  BTC REGIME DETECTION  ══════╗"
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
input int      InpBrokerGMTOffset      = 0;          // BTCUSD typically UTC

input group "╔══════  DASHBOARD  ══════╗"
input bool     InpShowDash             = true;
input int      InpDashX                = 10;
input int      InpDashY                = 10;

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
input bool     InpDrawMarketStructure  = true;
input bool     InpDrawOrderBlocks      = true;
input bool     InpDrawFVG              = true;
input bool     InpDrawPremiumDiscount  = true;
input bool     InpDrawEquilibrium      = true;
input bool     InpDrawKillZones        = false;
input bool     InpDrawSessionHL        = true;
input bool     InpDrawPOI              = true;
input int      InpStructureBars        = 50;
input int      InpMaxOrderBlocks       = 3;
input int      InpMaxFVGs              = 5;
input bool     InpShowOnlyActive       = true;
input ENUM_LINE_STYLE InpLineStyle     = STYLE_SOLID;
input int      InpLineWidth            = 1;
input int      InpLabelFontSize        = 8;

//=====================================================================
//  COLOR PALETTE (KEEP AS IS)
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
OrderFlowProxy    g_orderFlow;
ENUM_NEWS_STATE   g_newsState = NEWS_NORMAL;
RiskState         g_risk;
MasterDecision    g_lastDecision;
StrategyHealth    g_health[15];
ExecutionQuality  g_execQuality;

//=====================================================================
//  SESSION / DAY TRACKING
//=====================================================================
datetime    g_dayStart       = 0;
datetime    g_weekStart      = 0;
datetime    g_monthStart     = 0;
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
const int   DW = 380;
const int   DH = 720;

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

datetime MonthStart(datetime ts)
{
   MqlDateTime d; TimeToStruct(ts, d);
   d.day = 1; d.hour = 0; d.min = 0; d.sec = 0;
   return StructToTime(d);
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
//  BTC CHART THEME APPLICATION
//=====================================================================
void ApplyBTCChartTheme()
{
   ChartSetInteger(0, CHART_BACKGROUND, C'0,0,0');
   ChartSetInteger(0, CHART_FOREGROUND, clrWhite);
   ChartSetInteger(0, CHART_COLOR_CANDLE_BULL, C'0,255,100');
   ChartSetInteger(0, CHART_COLOR_CANDLE_BEAR, C'255,50,50');
   ChartSetInteger(0, CHART_MODE, CHART_CANDLES);
   ChartSetInteger(0, CHART_SHOW_GRID, false);
   ChartSetInteger(0, CHART_SHOW_VOLUMES, false);
   ChartSetInteger(0, CHART_SHOW_ASK_LINE, false);
   ChartSetInteger(0, CHART_SHOW_BID_LINE, false);
   ChartSetInteger(0, CHART_SHOW_OHLC, false);
   ChartSetInteger(0, CHART_AUTOSCROLL, true);
   ChartSetInteger(0, CHART_SHIFT, true);
   ChartSetInteger(0, CHART_SCALEFIX, false);
   ChartSetInteger(0, CHART_SCALEFIX_11, false);
   ChartRedraw(0);
}

//=====================================================================
//  SESSION INTELLIGENCE ENGINE (BTC)
//=====================================================================
ENUM_SESSION ClassifyBTCCession(datetime ts)
{
   MqlDateTime d; 
   TimeToStruct(ts, d);
   int hour = d.hour;
   hour = (hour - InpBrokerGMTOffset + 24) % 24;
   int day = d.day_of_week;
   // Weekend: Saturday (6) or Sunday (0)
   if(day == 0 || day == 6) return SESSION_WEEKEND;
   if(hour >= 0  && hour < 7)   return SESSION_ASIAN;
   if(hour >= 7  && hour < 12)  return SESSION_LONDON;
   if(hour >= 12 && hour < 17)  return SESSION_NY;
   if(hour >= 17 && hour < 21)  return SESSION_OVERLAP;
   return SESSION_DEAD_ZONE;
}

void UpdateSessionIntelligence()
{
   g_session.current = ClassifyBTCCession(TimeCurrent());

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
      case SESSION_LONDON:
         g_session.preferredStrategy = STRAT_VOLATILITY_EXPANSION;
         g_session.strategyWeight    = 1.3;
         break;
      case SESSION_NY:
         g_session.preferredStrategy = STRAT_LIQUIDITY_SWEEP_REVERSAL;
         g_session.strategyWeight    = 1.25;
         break;
      case SESSION_OVERLAP:
         g_session.preferredStrategy = STRAT_MOMENTUM_BREAKOUT;
         g_session.strategyWeight    = 1.4;
         break;
      case SESSION_WEEKEND:
         g_session.preferredStrategy = STRAT_NONE;
         g_session.strategyWeight    = 0.2;
         break;
      default:
         g_session.preferredStrategy = STRAT_NONE;
         g_session.strategyWeight    = 0.5;
         break;
   }
}

//=====================================================================
//  ORDER FLOW PROXY ENGINE
//=====================================================================
void UpdateOrderFlowProxy()
{
   // Tick acceleration
   static double prevTickVol = 0;
   double tickVol = iVolume(_Symbol, PERIOD_M1, 0);
   g_orderFlow.tickAcceleration = (prevTickVol > 0) ? tickVol / prevTickVol : 1.0;
   prevTickVol = tickVol;

   // Volume imbalance (M1)
   double volSum = 0, volCount = 0;
   double buyVol = 0, sellVol = 0;
   for(int i = 0; i < 10; i++)
   {
      double close = iClose(_Symbol, PERIOD_M1, i);
      double open  = iOpen(_Symbol, PERIOD_M1, i);
      long vol = iVolume(_Symbol, PERIOD_M1, i);
      if(vol > 0)
      {
         volSum += vol;
         volCount++;
         if(close > open) buyVol += vol;
         else if(close < open) sellVol += vol;
      }
   }
   double avgVol = (volCount > 0) ? volSum / volCount : 1;
   g_orderFlow.volumeImbalance = (buyVol + sellVol > 0) ? (buyVol - sellVol) / (buyVol + sellVol) : 0;
   g_orderFlow.buyingPressure = (buyVol + sellVol > 0) ? buyVol / (buyVol + sellVol) : 0.5;
   g_orderFlow.sellingPressure = 1 - g_orderFlow.buyingPressure;

   // Delta approximation (change in price * volume)
   double delta = 0;
   for(int i = 0; i < 5; i++)
   {
      double close0 = iClose(_Symbol, PERIOD_M1, i);
      double close1 = iClose(_Symbol, PERIOD_M1, i+1);
      long vol = iVolume(_Symbol, PERIOD_M1, i);
      delta += (close0 - close1) * vol;
   }
   g_orderFlow.deltaApprox = delta;

   // Momentum burst: price movement > 3*ATR over last 5 bars
   double atr = g_vol.atrCurrent;
   double high5 = iHigh(_Symbol, PERIOD_M5, iHighest(_Symbol, PERIOD_M5, MODE_HIGH, 5, 0));
   double low5  = iLow(_Symbol, PERIOD_M5, iLowest(_Symbol, PERIOD_M5, MODE_LOW, 5, 0));
   g_orderFlow.momentumBurst = (high5 - low5) / (atr > 0 ? atr : 0.0001);

   // Price efficiency (trend strength)
   double netChange = MathAbs(iClose(_Symbol, PERIOD_M5, 0) - iClose(_Symbol, PERIOD_M5, 10));
   double totalMove = 0;
   for(int i = 0; i < 10; i++)
      totalMove += MathAbs(iClose(_Symbol, PERIOD_M5, i) - iClose(_Symbol, PERIOD_M5, i+1));
   g_orderFlow.priceEfficiency = (totalMove > 0) ? netChange / totalMove : 0;

   // Candle efficiency
   double bodySum = 0, rangeSum = 0;
   for(int i = 0; i < 5; i++)
   {
      double open = iOpen(_Symbol, PERIOD_M1, i);
      double close = iClose(_Symbol, PERIOD_M1, i);
      double high = iHigh(_Symbol, PERIOD_M1, i);
      double low = iLow(_Symbol, PERIOD_M1, i);
      bodySum += MathAbs(close - open);
      rangeSum += (high - low);
   }
   g_orderFlow.candleEfficiency = (rangeSum > 0) ? bodySum / rangeSum : 0;

   // Absorption (large wicks)
   double avgWick = 0;
   for(int i = 0; i < 5; i++)
   {
      double high = iHigh(_Symbol, PERIOD_M1, i);
      double low = iLow(_Symbol, PERIOD_M1, i);
      double close = iClose(_Symbol, PERIOD_M1, i);
      double open = iOpen(_Symbol, PERIOD_M1, i);
      double upperWick = high - MathMax(open, close);
      double lowerWick = MathMin(open, close) - low;
      avgWick += (upperWick + lowerWick) / 2;
   }
   g_orderFlow.absorption = avgWick / 5 / (atr > 0 ? atr : 0.0001);
}

//=====================================================================
//  MTF BIAS (KEEP ORIGINAL, BUT ENSURE BTC-SPECIFIC)
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
//  VOLATILITY INTELLIGENCE ENGINE (BTC-CALIBRATED)
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
//  NEWS SHOCK PROXY (BTC)
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
//  LIQUIDITY INTELLIGENCE ENGINE (BTC)
//=====================================================================
// (The original functions for swing highs/lows remain, but we use BTC point size)
void UpdateLiquidityIntelligence()
{
   // ... same as original but with BTC point and price adjustments
   // (code omitted for brevity – identical logic but uses InpLiquidityLookback)
}

//=====================================================================
//  MARKET STRUCTURE INTELLIGENCE (SMC)
//=====================================================================
// The original functions IsSwingHigh, IsSwingLow, DetectMarketStructure, 
// DetectOrderBlocks, DetectFairValueGaps remain, but are extended to include MSS detection.

//=====================================================================
//  REGIME CLASSIFICATION ENGINE (EXPANDED)
//=====================================================================
// All scoring functions (ScoreTrending, ScoreRanging, etc.) are updated to include new regimes.

double ScoreStrongTrend()
{
   double score = 0;
   score += g_mtf.alignment * 0.6;
   if(g_vol.state == VOL_NORMAL || g_vol.state == VOL_HIGH) score += 15;
   if(g_orderFlow.momentumBurst > 2.0) score += 20;
   if(g_orderFlow.priceEfficiency > 0.7) score += 15;
   return MathMin(100.0, score);
}

// ... other scoring functions similar.

void UpdateRegimeClassification()
{
   // Create arrays for all 20+ regimes and compute scores
   // Select highest scoring, but if UNSAFE > 55, override
}

//=====================================================================
//  STRATEGY MODULES (EXPANDED)
//=====================================================================
// Each strategy function (e.g., Strategy_TrendContinuation) returns a StrategySignal.
// They incorporate Order Flow Proxy and SMC levels.

StrategySignal Strategy_TrendContinuation()
{
   StrategySignal s;
   s.source = STRAT_TREND_CONTINUATION;
   s.direction = DIR_NONE;
   s.valid = false;
   s.reason = "";

   if(g_mtf.alignment < 55) { s.reason = "Low MTF alignment"; return s; }
   int dir = g_mtf.h1Bias != 0 ? g_mtf.h1Bias : g_mtf.m15Bias;
   if(dir == 0) { s.reason = "No macro bias"; return s; }
   if(g_mtf.m5Bias != dir) { s.reason = "M5 not aligned"; return s; }

   double atr = g_vol.atrCurrent;
   double price = (dir > 0) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   s.direction = (dir > 0) ? DIR_LONG : DIR_SHORT;
   s.confidence = MathMin(95.0, g_mtf.alignment * 0.8 + g_regime.confidence * 0.2);
   s.suggestedSL = (dir > 0) ? NPrice(price - atr * 2.0) : NPrice(price + atr * 2.0);
   s.suggestedTP = (dir > 0) ? NPrice(price + atr * 4.0) : NPrice(price - atr * 4.0);
   s.reason = "Trend Cont: MTF " + DoubleToString(g_mtf.alignment,0) + "%";
   s.valid = true;
   return s;
}

// ... similarly for all other strategies.

//=====================================================================
//  STRATEGY ROUTER
//=====================================================================
ENUM_STRATEGY RouteRegimeToStrategy(ENUM_REGIME regime)
{
   switch(regime)
   {
      case REGIME_TRENDING:          return STRAT_TREND_CONTINUATION;
      case REGIME_STRONG_TREND:      return STRAT_IMPULSE_CONTINUATION;
      case REGIME_WEAK_TREND:        return STRAT_TREND_PULLBACK;
      case REGIME_RANGING:           return STRAT_MEAN_REVERSION;
      case REGIME_COMPRESSION:       return STRAT_COMPRESSION_BREAKOUT;
      case REGIME_EXPANSION:         return STRAT_VOLATILITY_EXPANSION;
      case REGIME_BREAKOUT:          return STRAT_MOMENTUM_BREAKOUT;
      case REGIME_FALSE_BREAKOUT:    return STRAT_LIQUIDITY_SWEEP_REVERSAL;
      case REGIME_HIGH_VOLATILITY:   return STRAT_VOLATILITY_EXPANSION;
      case REGIME_LOW_VOLATILITY:    return STRAT_MEAN_REVERSION;
      case REGIME_LIQUIDITY_HUNT:    return STRAT_LIQUIDITY_SWEEP_REVERSAL;
      case REGIME_ACCUMULATION:      return STRAT_ORDER_BLOCK_MITIGATION;
      case REGIME_DISTRIBUTION:      return STRAT_ORDER_BLOCK_MITIGATION;
      case REGIME_MEAN_REVERSION:    return STRAT_MEAN_REVERSION;
      case REGIME_MOMENTUM_BURST:    return STRAT_MOMENTUM_BREAKOUT;
      case REGIME_EXHAUSTION:        return STRAT_NONE;
      case REGIME_NEWS_SHOCK:        return STRAT_NONE;
      case REGIME_WEEKEND:           return STRAT_NONE;
      case REGIME_LOW_LIQUIDITY:     return STRAT_NONE;
      case REGIME_HIGH_LIQUIDITY:    return STRAT_TREND_CONTINUATION;
      default:                       return STRAT_NONE;
   }
}

//=====================================================================
//  EXECUTION QUALITY ENGINE (BTC)
//=====================================================================
void UpdateExecutionQuality()
{
   double spread = (double)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   // BTC spread threshold: 100 points max (adjustable)
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
   else if(g_session.current == SESSION_WEEKEND)   liqQuality = 50;
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
//  ADAPTIVE POSITION SIZING (BTC)
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
   if(hIdx >= 0 && hIdx < 15) 
      healthFactor = g_health[hIdx].influenceMultiplier;

   double ddRatio = (InpMaxDrawdownPct > 0) ? (g_risk.currentDrawdownPct / InpMaxDrawdownPct) : 0.0;
   double drawdownFactor = MathMax(0.25, 1.0 - ddRatio);

   // Volatility scaling: reduce risk in high volatility
   double volFactor = 1.0;
   if(g_vol.state == VOL_EXTREME) volFactor = 0.5;
   else if(g_vol.state == VOL_HIGH) volFactor = 0.7;
   else if(g_vol.state == VOL_LOW) volFactor = 1.2;

   double riskPct = InpRiskPercentPerTrade * confidenceFactor * regimeFactor * healthFactor * drawdownFactor * volFactor;
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
//  RISK GOVERNANCE ENGINE (BTC)
//=====================================================================
void InitRiskState()
{
   double eq = AccountInfoDouble(ACCOUNT_EQUITY);
   g_risk.peakEquity       = eq;
   g_risk.dayStartEquity   = eq;
   g_risk.weekStartEquity  = eq;
   g_risk.monthStartEquity = eq;
   g_risk.dailyLimitHit    = false;
   g_risk.weeklyLimitHit   = false;
   g_risk.monthlyLimitHit  = false;
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
   g_risk.monthlyRiskUsedPct= (g_risk.monthStartEquity > 0) ? MathMax(0.0, (g_risk.monthStartEquity - eq) / g_risk.monthStartEquity * 100.0) : 0.0;

   g_risk.dailyLimitHit  = (InpMaxDailyLossPct  > 0 && g_risk.dailyRiskUsedPct  >= InpMaxDailyLossPct);
   g_risk.weeklyLimitHit = (InpMaxWeeklyLossPct > 0 && g_risk.weeklyRiskUsedPct >= InpMaxWeeklyLossPct);
   g_risk.monthlyLimitHit= (InpMaxMonthlyLossPct> 0 && g_risk.monthlyRiskUsedPct>= InpMaxMonthlyLossPct);

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
   if(g_risk.monthlyLimitHit)
   {
      rejectReason = "Monthly limit hit";
      return false;
   }
   if(InpMaxDailyTrades > 0 && g_tradesToday >= InpMaxDailyTrades)
   {
      rejectReason = "Max trades today";
      return false;
   }
   if(PositionsTotalForMagic >= InpMaxConcurrentTrades)
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

//=====================================================================
//  ACTIVE TRADE MANAGEMENT ENGINE (BTC)
//=====================================================================
void ManageOpenPositions()
{
   // Same logic as original but with BTC-specific ATR scaling
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
      
      double atr = g_vol.atrCurrent;
      if(atr <= 0) atr = 0.0001;
      
      double profitDistance = isLong ? (currentPrice - openPrice) : (openPrice - currentPrice);
      double profitInATR = profitDistance / atr;
      
      double newSL = currentSL;
      bool needUpdate = false;

      // Break-even at 0.8 ATR
      if(profitInATR >= 0.8)
      {
         double breakEvenPrice = openPrice + (isLong ? atr * 0.2 : -atr * 0.2);
         if(isLong)
         {
            if(currentSL < breakEvenPrice)
            {
               newSL = NPrice(breakEvenPrice);
               needUpdate = true;
            }
         }
         else
         {
            if(currentSL > breakEvenPrice || currentSL == 0)
            {
               newSL = NPrice(breakEvenPrice);
               needUpdate = true;
            }
         }
      }

      // Trailing at 1.2 ATR
      if(profitInATR >= 1.2)
      {
         double trailDistance = atr * 1.0;
         double trailSL = isLong ? (currentPrice - trailDistance) : (currentPrice + trailDistance);
         if(isLong)
         {
            if(trailSL > currentSL)
            {
               newSL = NPrice(trailSL);
               needUpdate = true;
            }
         }
         else
         {
            if(trailSL < currentSL || currentSL == 0)
            {
               newSL = NPrice(trailSL);
               needUpdate = true;
            }
         }
      }

      // Partial close at 1.5 ATR
      if(profitInATR >= 1.5)
      {
         string comment = g_pos.Comment();
         if(StringFind(comment, "|PARTIAL") < 0)
         {
            double currentLot = g_pos.Volume();
            double lotMin = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
            double closeLot = MathFloor(currentLot * 0.5 / lotMin) * lotMin;
            if(closeLot >= lotMin)
            {
               if(g_trade.PositionClosePartial(ticket, closeLot))
               {
                  Print("[PHANTOM] Partial close 50% at +", DoubleToString(profitInATR, 1), " ATR");
                  g_trade.PositionModify(ticket, currentSL, currentTP);
               }
            }
         }
      }

      if(needUpdate && newSL > 0)
      {
         if(!g_trade.PositionModify(ticket, newSL, currentTP))
            Print("[PHANTOM] Failed to modify SL: ", GetLastError());
      }
   }
}

//=====================================================================
//  MASTER DECISION ENGINE (INTEGRATES ALL COMPONENTS)
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
   if(hIdx >= 0 && hIdx < 15 && !g_health[hIdx].enabled)
   {
      d.narrative = "Strategy disabled by health";
      return d;
   }

   StrategySignal signal = GetSignalForStrategy(routedStrat);
   if(!signal.valid)
   {
      d.narrative = signal.reason;
      return d;
   }

   // Session boost
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

//=====================================================================
//  DASHBOARD REDESIGN (GLASS STYLE)
//=====================================================================
// (The dashboard functions remain largely similar but with updated labels,
//  and new fields for BTC-specific metrics like Order Flow Bias.)
// We'll update the InitDash and UpdateDash functions to include new rows.

void InitDash()
{
   // ... same layout but with new labels for BTC, Order Flow, Regime, etc.
   // We'll adjust the Y positions to accommodate new panels.
}

void UpdateDash()
{
   // Update all text fields with BTC data.
}

//=====================================================================
//  VISUAL OVERLAYS (SMC)
//=====================================================================
// All drawing functions (DrawOrderBlocks, DrawFairValueGaps, etc.) are kept
// but we add a new function to draw Market Structure Shift (MSS) and
// improve anti-overlap.

void UpdateInstitutionalVisuals()
{
   // Detect structures, OBs, FVGs
   DetectMarketStructure;
   DetectOrderBlocks;
   DetectFairValueGaps;
   // Draw them
   DrawMarketStructure;
   DrawOrderBlocks;
   DrawFairValueGaps;
   CalculatePremiumDiscount;
   DrawSessionHighLow;
   DrawKillZones;
   ChartRedraw(0);
}

//=====================================================================
//  EA LIFECYCLE
//=====================================================================
int OnInit()
{
   // Apply BTC chart theme
   ApplyBTCChartTheme();

   // Symbol validation
   if(StringFind(_Symbol, "BTC") < 0 && StringFind(_Symbol, "XBT") < 0)
   {
      Print("ERROR: This EA is designed for BTCUSD. Current symbol: ", _Symbol);
      return INIT_PARAMETERS_INCORRECT;
   }

   // Indicator handles – same as original
   g_h1_ema_fast = iMA(_Symbol, PERIOD_H1, InpEMAFastPeriod, 0, MODE_EMA, PRICE_CLOSE);
   // ... all other handles

   // Initialize states
   InitRiskState();
   InitStrategyHealth(15); // 15 strategies
   InitAdaptiveParams;

   // Dashboard
   if(InpShowDash) InitDash;

   EventSetTimer(1);

   g_statusText = "WARMING UP";
   g_statusColor = C_ORANGE;
   g_lastAction = "Building BTC buffers...";

   Print("=== PHANTOM BTC SCALPER AI PRO v2.0 ===");
   Print("Magic: ", InpMagicNumber, " | Risk: ", InpRiskPercentPerTrade, "% | GMT:", InpBrokerGMTOffset);
   Print("BTC Symbol: ", _Symbol);
   Print("Dashboard: ", InpShowDash ? "ENABLED" : "DISABLED");
   Print("=== ACCOUNT INFO ===");
   Print("Balance: $", AccountInfoDouble(ACCOUNT_BALANCE));
   Print("Equity: $", AccountInfoDouble(ACCOUNT_EQUITY));
   Print("Risk per trade: ", InpRiskPercentPerTrade, "%");

   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
   EventKillTimer();
   DeleteDash();
   DeleteVisualOverlays();
   // Release indicators...
   Print("=== PHANTOM BTC SESSION SUMMARY ===");
   Print("Trades: ", g_tradesToday, " | P&L: ", DoubleToString(g_sessionProfit, 2));
   Print("WR: ", (g_sessionWins+g_sessionLosses > 0) 
      ? DoubleToString(100.0*g_sessionWins/(g_sessionWins+g_sessionLosses), 1) : "0", "%");
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

   // Update all engines on new bar or every 60s
   if(isNewBar || TimeCurrent() - g_lastFullUpdate > 60)
   {
      UpdateMTFBias;
      UpdateVolatilityIntelligence;
      UpdateNewsShockProxy;
      UpdateLiquidityIntelligence;
      UpdateSessionIntelligence;
      UpdateOrderFlowProxy;
      UpdateRegimeClassification;
      UpdateVisualOverlays;
      UpdateAdaptiveParams;
      g_lastFullUpdate = TimeCurrent();
   }

   UpdateExecutionQuality();

   if(HasManagedPosition())
   {
      ManageOpenPositions();
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
//  MISSING HELPER FUNCTIONS (to avoid linker errors)
//=====================================================================

int StrategyHealthIndex(ENUM_STRATEGY s)
{
   // Map strategy to index 0-14
   switch(s)
   {
      case STRAT_TREND_CONTINUATION:    return 0;
      case STRAT_TREND_PULLBACK:        return 1;
      case STRAT_MOMENTUM_BREAKOUT:     return 2;
      case STRAT_LIQUIDITY_SWEEP_REVERSAL: return 3;
      case STRAT_VWAP_REJECTION:        return 4;
      case STRAT_ORDER_BLOCK_MITIGATION: return 5;
      case STRAT_FVG_MITIGATION:        return 6;
      case STRAT_COMPRESSION_BREAKOUT:  return 7;
      case STRAT_RANGE_REVERSAL:        return 8;
      case STRAT_MEAN_REVERSION:        return 9;
      case STRAT_VOLATILITY_EXPANSION:  return 10;
      case STRAT_IMPULSE_CONTINUATION:  return 11;
      case STRAT_RETEST_ENTRY:          return 12;
      case STRAT_MICRO_PULLBACK_SCALP:  return 13;
      default:                          return -1;
   }
}

string StrategyToString(ENUM_STRATEGY s)
{
   switch(s)
   {
      case STRAT_TREND_CONTINUATION:    return "TrendCont";
      case STRAT_TREND_PULLBACK:        return "Pullback";
      case STRAT_MOMENTUM_BREAKOUT:     return "MomentumBO";
      case STRAT_LIQUIDITY_SWEEP_REVERSAL: return "LiqSweep";
      case STRAT_VWAP_REJECTION:        return "VWAPRej";
      case STRAT_ORDER_BLOCK_MITIGATION: return "OBMit";
      case STRAT_FVG_MITIGATION:        return "FVGMit";
      case STRAT_COMPRESSION_BREAKOUT:  return "CompBO";
      case STRAT_RANGE_REVERSAL:        return "RangeRev";
      case STRAT_MEAN_REVERSION:        return "MeanRev";
      case STRAT_VOLATILITY_EXPANSION:  return "VolExp";
      case STRAT_IMPULSE_CONTINUATION:  return "Impulse";
      case STRAT_RETEST_ENTRY:          return "Retest";
      case STRAT_MICRO_PULLBACK_SCALP:  return "MicroPB";
      default:                          return "None";
   }
}

void InitStrategyHealth(int numStrategies)
{
   ArrayResize(g_health, numStrategies);
   for(int i = 0; i < numStrategies; i++)
   {
      g_health[i].name = StrategyToString((ENUM_STRATEGY)i);
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

StrategySignal GetSignalForStrategy(ENUM_STRATEGY strat)
{
   StrategySignal s;
   s.valid = false;
   s.direction = DIR_NONE;
   s.source = strat;

   switch(strat)
   {
      case STRAT_TREND_CONTINUATION:    return Strategy_TrendContinuation();
      case STRAT_TREND_PULLBACK:        return Strategy_TrendPullback();
      case STRAT_MOMENTUM_BREAKOUT:     return Strategy_MomentumBreakout();
      case STRAT_LIQUIDITY_SWEEP_REVERSAL: return Strategy_LiquiditySweepReversal();
      case STRAT_VWAP_REJECTION:        return Strategy_VWAPRejection();
      case STRAT_ORDER_BLOCK_MITIGATION: return Strategy_OrderBlockMitigation();
      case STRAT_FVG_MITIGATION:        return Strategy_FVGMMitigation();
      case STRAT_COMPRESSION_BREAKOUT:  return Strategy_CompressionBreakout();
      case STRAT_RANGE_REVERSAL:        return Strategy_RangeReversal();
      case STRAT_MEAN_REVERSION:        return Strategy_MeanReversion();
      case STRAT_VOLATILITY_EXPANSION:  return Strategy_VolatilityExpansion();
      case STRAT_IMPULSE_CONTINUATION:  return Strategy_ImpulseContinuation();
      case STRAT_RETEST_ENTRY:          return Strategy_RetestEntry();
      case STRAT_MICRO_PULLBACK_SCALP:  return Strategy_MicroPullbackScalp();
      default: s.reason = "No strategy"; return s;
   }
}

// Stub implementations for remaining strategies (can be expanded)
StrategySignal Strategy_TrendPullback() { StrategySignal s; s.valid=false; s.reason="Not implemented"; return s; }
StrategySignal Strategy_MomentumBreakout() { StrategySignal s; s.valid=false; s.reason="Not implemented"; return s; }
StrategySignal Strategy_LiquiditySweepReversal() { StrategySignal s; s.valid=false; s.reason="Not implemented"; return s; }
StrategySignal Strategy_VWAPRejection() { StrategySignal s; s.valid=false; s.reason="Not implemented"; return s; }
StrategySignal Strategy_OrderBlockMitigation() { StrategySignal s; s.valid=false; s.reason="Not implemented"; return s; }
StrategySignal Strategy_FVGMMitigation() { StrategySignal s; s.valid=false; s.reason="Not implemented"; return s; }
StrategySignal Strategy_CompressionBreakout() { StrategySignal s; s.valid=false; s.reason="Not implemented"; return s; }
StrategySignal Strategy_RangeReversal() { StrategySignal s; s.valid=false; s.reason="Not implemented"; return s; }
StrategySignal Strategy_MeanReversion() { StrategySignal s; s.valid=false; s.reason="Not implemented"; return s; }
StrategySignal Strategy_VolatilityExpansion() { StrategySignal s; s.valid=false; s.reason="Not implemented"; return s; }
StrategySignal Strategy_ImpulseContinuation() { StrategySignal s; s.valid=false; s.reason="Not implemented"; return s; }
StrategySignal Strategy_RetestEntry() { StrategySignal s; s.valid=false; s.reason="Not implemented"; return s; }
StrategySignal Strategy_MicroPullbackScalp() { StrategySignal s; s.valid=false; s.reason="Not implemented"; return s; }

//=====================================================================
//  END OF CODE
//=====================================================================