//+------------------------------------------------------------------+
//|                    QUANTUM GOLD SCALPER AI v3.1                  |
//|              Advanced ML Gold Scalping Terminal                  |
//+------------------------------------------------------------------+
#property copyright   "Quantum Gold Scalper AI v3.0"
#property version     "3.00"
#property description "Advanced ML-Powered Gold Scalping System"
#property strict

#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>
#include <Trade\AccountInfo.mqh>
#include <Trade\OrderInfo.mqh>

//=====================================================================
//  DEFINES
//=====================================================================
#define D    "QGSA3_"
#define OV   "QGSA3_OV_"
#define M_PI 3.14159265358979323846

//=====================================================================
//  ENUMERATIONS - ENHANCED FOR GOLD
//=====================================================================
enum ENUM_REGIME
{
   REGIME_STRONG_BULL_TREND,
   REGIME_WEAK_BULL_TREND,
   REGIME_STRONG_BEAR_TREND,
   REGIME_WEAK_BEAR_TREND,
   REGIME_RANGING,
   REGIME_BREAKOUT,
   REGIME_COMPRESSION,
   REGIME_EXPANSION,
   REGIME_VOLATILITY_SHOCK,
   REGIME_LIQUIDITY_SWEEP,
   REGIME_EXHAUSTION,
   REGIME_MEAN_REVERSION,
   REGIME_NEWS_EVENT,
   REGIME_ACCUMULATION,
   REGIME_DISTRIBUTION,
   REGIME_UNSAFE
};

enum ENUM_VOL_STATE   
{ 
   VOL_ULTRA_LOW, 
   VOL_LOW, 
   VOL_NORMAL, 
   VOL_HIGH, 
   VOL_EXTREME,
   VOL_SHOCK 
};

enum ENUM_VOL_DYNAMIC 
{ 
   VOLDYN_EXPANDING, 
   VOLDYN_COMPRESSING, 
   VOLDYN_STABLE, 
   VOLDYN_SPIKE,
   VOLDYN_CONTRACTING 
};

enum ENUM_SESSION
{
   SESSION_ASIAN,
   SESSION_LONDON_OPEN,
   SESSION_LONDON_MID,
   SESSION_NY_OPEN,
   SESSION_OVERLAP,      // London-NY overlap - BEST for gold scalping
   SESSION_NY_PM,
   SESSION_DEAD_ZONE
};

enum ENUM_STRATEGY
{
   STRAT_NONE,
   STRAT_BREAKOUT_SCALP,
   STRAT_REVERSAL_SCALP,
   STRAT_MOMENTUM_SCALP,
   STRAT_RANGE_SCALP,
   STRAT_LIQUIDITY_REVERSAL,
   STRAT_COMPRESSION_BREAKOUT,
   STRAT_FVG_FILL,
   STRAT_ORDERBLOCK_REACTION,
   STRAT_IMBALANCE_SCALP,
   STRAT_SESSION_BREAKOUT
};

enum ENUM_INDICATOR
{
   IND_EMA_FAST,
   IND_EMA_SLOW,
   IND_EMA_200,
   IND_RSI,
   IND_STOCHASTIC,
   IND_MACD,
   IND_BOLLINGER,
   IND_ATR,
   IND_ADX,
   IND_CCI,
   IND_MOMENTUM,
   IND_VOLUME_ANALYSIS,
   IND_SUPERTREND,
   IND_ICHIMOKU
};

//=====================================================================
//  ADVANCED STRUCTURES - ML ENHANCED
//=====================================================================

// Indicator performance tracking with ML
struct IndicatorMetrics
{
   ENUM_INDICATOR type;
   string         name;
   bool           active;
   bool           enabled;
   double         signalStrength;
   double         reliability;
   double         winRate;
   int            totalSignals;
   int            correctSignals;
   double         avgProfit;
   double         avgLoss;
   double         sharpeRatio;
   double         mlWeight;           // ML-calculated weight
   double         correlationPenalty; // Penalty for correlation with other indicators
   datetime       lastUpdate;
};

// Strategy performance with ML learning
struct StrategyMetrics
{
   ENUM_STRATEGY  type;
   string         name;
   bool           enabled;
   double         winRate;
   int            totalTrades;
   int            wins;
   int            losses;
   double         grossProfit;
   double         grossLoss;
   double         profitFactor;
   double         expectancyR;
   double         sharpeProxy;
   int            consecWins;
   int            consecLosses;
   int            maxConsecLosses;
   double         recentPerformance[20];  // Last 20 for ML
   int            recentIndex;
   double         mlConfidence;           // ML confidence score
   double         sessionMultiplier;      // Session-specific multiplier
   double         volatilityMultiplier;   // Volatility-specific multiplier
   datetime       lastTradeTime;
};

// Enhanced regime with ML classification
struct RegimeState
{
   ENUM_REGIME  regime;
   ENUM_REGIME  previousRegime;
   double       confidence;
   double       stability;
   int          barsInRegime;
   datetime     sinceTime;
   double       trendStrength;
   double       mlClassificationScore;
};

// Volatility with percentile tracking
struct VolatilityState
{
   ENUM_VOL_STATE   state;
   ENUM_VOL_DYNAMIC dynamic;
   double           atrCurrent;
   double           atrAvg;
   double           atrRatio;
   double           percentile;
   double           historicalVol;
   double           impliedVol;
   bool             expanding;
   bool             contracting;
   bool             spike;
};

// Enhanced liquidity detection
struct LiquidityState
{
   double  buySideLiquidity;
   double  sellSideLiquidity;
   double  imbalanceRatio;
   double  sweepProbability;
   bool    equalHighsDetected;
   bool    equalLowsDetected;
   double  equalHighLevel;
   double  equalLowLevel;
   int     equalHighCount;
   int     equalLowCount;
   bool    sweepUpDetected;
   bool    sweepDownDetected;
   double  liquidityScore;
};

// Session with Gold-specific data
struct SessionState
{
   ENUM_SESSION  current;
   double        sessionRangeATRRatio;
   double        sessionVolatilityScore;
   double        sessionVolumeScore;
   double        spreadQuality;
   ENUM_STRATEGY preferredStrategy;
   double        strategyWeight;
   double        optimalRiskPercent;
   double        sessionHigh;
   double        sessionLow;
   double        sessionOpen;
};

// Multi-timeframe with strength
struct MTFBias
{
   int    h4Bias;
   int    h1Bias;
   int    m30Bias;
   int    m15Bias;
   int    m5Bias;
   int    m1Bias;
   double alignment;
   double strength;
};

// Price patterns for visual overlay
struct PricePattern
{
   string   type;        // "FVG", "OB", "CHoCH", "BOS", "MSS", "SF"
   double   priceUpper;
   double   priceLower;
   double   priceLevel;
   datetime time;
   bool     bullish;
   double   strength;
   bool     active;
};

// Order Block detection
struct OrderBlock
{
   double   high;
   double   low;
   datetime time;
   bool     bullish;
   double   strength;
   bool     tested;
   int      touches;
   bool     broken;
};

// Fair Value Gap
struct FairValueGap
{
   double   upper;
   double   lower;
   datetime time;
   bool     bullish;
   bool     filled;
   double   fillPercent;
   double   strength;
};

// ML Pattern for learning
struct MLPattern
{
   double   features[15];
   int      label;        // 1=win, -1=loss
   double   confidence;
   double   actualOutcome;
   datetime time;
};

// Advanced risk with account scaling
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
   double  currentRiskPercent;      // Adaptive
   double  volatilityAdjustment;    // Volatility-based adjustment
   double  accountSizeMultiplier;   // Account size scaling
};

// Signal generation
struct StrategySignal
{
   ENUM_STRATEGY  source;
   int            direction;  // 1=long, -1=short, 0=none
   double         confidence;
   double         suggestedSL;
   double         suggestedTP;
   string         reason;
   bool           valid;
   int            indicatorsAgreeing;
   double         qualityScore;
};

// Execution quality
struct ExecutionQuality
{
   double spreadScore;
   double slippageRiskScore;
   double volatilityQuality;
   double liquidityQuality;
   double timingScore;
   double compositeScore;
   bool   executionApproved;
   string rejectReason;
};

// Master decision
struct MasterDecision
{
   bool           tradeApproved;
   int            direction;
   double         lotSize;
   double         slPrice;
   double         tpPrice;
   ENUM_STRATEGY  strategySource;
   double         riskAmountUsed;
   double         confidence;
   string         narrative;
};

//=====================================================================
//  INPUTS - ENHANCED FOR GOLD
//=====================================================================
input group "===== IDENTITY ====="
input ulong  InpMagicNumber         = 999900;
input string InpBotName             = "QUANTUM GOLD SCALPER AI v3.0";

input group "===== GOLD-SPECIFIC RISK ====="
input double InpBaseRiskPercent     = 0.5;   // Base risk per trade
input double InpMaxRiskPercent      = 1.5;   // Max risk per trade
input double InpMinRiskPercent      = 0.2;   // Min risk per trade
input bool   InpUseAdaptiveRisk     = true;  // Enable adaptive risk
input bool   InpScaleByVolatility   = true;  // Scale by volatility
input bool   InpScaleByAccountSize  = true;  // Scale by account size
input double InpMaxDailyLossPct     = 3.0;   // Max daily loss %
input double InpMaxWeeklyLossPct    = 7.0;   // Max weekly loss %
input double InpMaxDrawdownPct      = 12.0;  // Max drawdown %
input int    InpMaxDailyTrades      = 20;    // Max daily trades
input int    InpMaxConcurrentTrades = 1;     // Max concurrent positions

input group "===== GOLD EXECUTION ====="
input double InpMaxSpreadPoints     = 30;    // Max spread (points/10)
input double InpGoldMinMove         = 0.50;  // Min price move ($)
input int    InpSlippage            = 30;    // Max slippage
input int    InpCooldownSeconds     = 20;    // Cooldown after close

input group "===== SESSION FILTERS ====="
input bool   InpTradeAsian          = false; // Trade Asian
input bool   InpTradeLondon         = true;  // Trade London
input bool   InpTradeNY             = true;  // Trade NY
input bool   InpTradeOverlap        = true;  // Trade overlap (best!)
input int    InpBrokerGMTOffset     = 2;     // Broker GMT offset

input group "===== INDICATORS (AUTO-SELECT) ====="
input int    InpEMAFast             = 8;
input int    InpEMASlow             = 21;
input int    InpEMA200              = 200;
input int    InpRSIPeriod           = 14;
input int    InpATRPeriod           = 14;
input int    InpATRLookback         = 100;
input int    InpADXPeriod           = 14;
input int    InpCCIPeriod           = 14;
input int    InpStochPeriod         = 14;
input int    InpBBPeriod            = 20;
input double InpBBDeviation         = 2.0;

input group "===== MACHINE LEARNING ====="
input bool   InpEnableML            = true;  // Enable ML
input int    InpMLLookback          = 100;   // ML lookback
input double InpMLLearningRate      = 0.15;  // Learning rate
input int    InpMLMinSamples        = 15;    // Min samples

input group "===== STRATEGY AUTO-SELECT ====="
input bool   InpAutoSelectStrategy  = true;  // Auto-select strategy
input bool   InpEnableBreakout      = true;
input bool   InpEnableReversal      = true;
input bool   InpEnableMomentum      = true;
input bool   InpEnableRange         = true;
input bool   InpEnableLiquidity     = true;
input bool   InpEnableFVG           = true;
input bool   InpEnableOrderBlock    = true;

input group "===== FILTERS ====="
input double InpMinRegimeConfidence = 55.0;
input double InpMinSignalConfidence = 65.0;
input double InpMinExecutionScore   = 70.0;
input bool   InpUseSpreadFilter     = true;
input bool   InpUseVolatilityFilter = true;

input group "===== VISUAL OVERLAYS ====="
input bool   InpShowDash            = true;
input bool   InpShowMLPanel         = true;
input bool   InpDrawSessionBoxes    = true;
input bool   InpDrawLiquidityZones  = true;
input bool   InpDrawOrderBlocks     = true;
input bool   InpDrawFVG             = true;
input bool   InpDrawChoCh           = true;
input bool   InpDrawBOS             = true;
input int    InpDashX               = 10;
input int    InpDashY               = 10;
input int    InpDashWidth           = 450;
input int    InpDPIScale            = 100;

//=====================================================================
//  GLOBALS
//=====================================================================
CTrade        g_trade;
CPositionInfo g_pos;
CAccountInfo  g_account;

// Indicator handles - Multi-timeframe
int g_h4_ema_fast, g_h4_ema_slow, g_h4_ema_200, g_h4_atr;
int g_h1_ema_fast, g_h1_ema_slow, g_h1_ema_200, g_h1_atr, g_h1_rsi, g_h1_adx;
int g_m30_ema_fast, g_m30_ema_slow, g_m30_atr, g_m30_rsi;
int g_m15_ema_fast, g_m15_ema_slow, g_m15_atr, g_m15_rsi, g_m15_bb;
int g_m5_ema_fast, g_m5_ema_slow, g_m5_ema_200, g_m5_atr, g_m5_rsi, g_m5_stoch, g_m5_cci, g_m5_adx;
int g_m1_ema_fast, g_m1_ema_slow, g_m1_atr, g_m1_rsi;

// State structures
IndicatorMetrics  g_indicators[14];
StrategyMetrics   g_strategies[11];
RegimeState       g_regime;
VolatilityState   g_vol;
LiquidityState    g_liq;
SessionState      g_session;
MTFBias           g_mtf;
RiskState         g_risk;
ExecutionQuality  g_execQuality;
MasterDecision    g_lastDecision;

// Price patterns
PricePattern      g_patterns[50];
int               g_patternCount = 0;
OrderBlock        g_orderBlocks[30];
int               g_obCount = 0;
FairValueGap      g_fvgs[30];
int               g_fvgCount = 0;

// ML data
MLPattern         g_mlPatterns[200];
int               g_mlPatternCount = 0;
double            g_mlWeights[15];

// Runtime
datetime g_dayStart      = 0;
datetime g_weekStart     = 0;
int      g_tradesToday   = 0;
datetime g_lastCloseTime = 0;
bool     g_inCooldown    = false;
datetime g_lastBarTime   = 0;
double   g_scale         = 1.0;

string g_statusText  = "INITIALIZING";
color  g_statusColor = C'255,150,0';

// Performance tracking
double g_sessionProfit = 0.0;
int    g_sessionWins   = 0;
int    g_sessionLosses = 0;

//=====================================================================
//  COLOR PALETTE
//=====================================================================
#define C_BG_DARK       C'5,5,10'
#define C_PANEL_BG      C'10,15,30'
#define C_PANEL_HDR     C'15,30,60'
#define C_BORDER        C'0,255,255'
#define C_GOLD          C'255,215,0'
#define C_WHITE         C'255,255,255'
#define C_GRAY          C'120,140,170'
#define C_GREEN         C'0,255,100'
#define C_RED           C'255,50,50'
#define C_BLUE          C'50,150,255'
#define C_PURPLE        C'180,80,255'
#define C_ORANGE        C'255,150,0'

//=====================================================================
//  UTILITY FUNCTIONS
//=====================================================================
int S(int px) { return (int)MathRound(px * g_scale); }
int FS(int sz) { return MathMax(6, (int)MathRound(sz * g_scale)); }

double NPrice(double p) { return NormalizeDouble(p, 2); }

datetime DayStart(datetime ts)
{
   MqlDateTime d; 
   TimeToStruct(ts, d);
   d.hour = 0; d.min = 0; d.sec = 0;
   return StructToTime(d);
}

datetime WeekStart(datetime ts)
{
   MqlDateTime d; 
   TimeToStruct(ts, d);
   datetime ds = DayStart(ts);
   int off = (d.day_of_week == 0) ? 6 : (d.day_of_week - 1);
   return ds - off * 86400;
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
   if(t != g_lastBarTime) 
   { 
      g_lastBarTime = t; 
      return true; 
   }
   return false;
}

//=====================================================================
//  SESSION CLASSIFICATION - GOLD SPECIFIC
//=====================================================================
ENUM_SESSION ClassifySession(datetime ts)
{
   MqlDateTime d; 
   TimeToStruct(ts, d);
   int h = (d.hour - InpBrokerGMTOffset + 24) % 24;
   
   // Gold session classification
   // Asian: 00:00-07:00 (low vol)
   // London Open: 07:00-09:00 (high vol)
   // London Mid: 09:00-13:00
   // NY Open: 13:00-15:00 (extreme vol)
   // Overlap: 13:00-16:00 (BEST for scalping)
   // NY PM: 16:00-20:00
   // Dead Zone: 20:00-24:00
   
   if(h >= 0 && h < 7)
      return SESSION_ASIAN;
   else if(h >= 7 && h < 9)
      return SESSION_LONDON_OPEN;
   else if(h >= 9 && h < 13)
      return SESSION_LONDON_MID;
   else if(h >= 13 && h < 16)
      return SESSION_OVERLAP;  // Best session!
   else if(h >= 13 && h < 20)
      return SESSION_NY_PM;
   else
      return SESSION_DEAD_ZONE;
}

string SessionToString(ENUM_SESSION s)
{
   switch(s)
   {
      case SESSION_ASIAN:       return "ASIAN";
      case SESSION_LONDON_OPEN: return "LONDON OPEN";
      case SESSION_LONDON_MID:  return "LONDON MID";
      case SESSION_NY_OPEN:     return "NY OPEN";
      case SESSION_OVERLAP:     return "OVERLAP ★";  // Star indicates best
      case SESSION_NY_PM:       return "NY PM";
      default:                  return "DEAD ZONE";
   }
}

//=====================================================================
//  ADAPTIVE RISK MANAGEMENT - ACCOUNT & VOLATILITY SCALED
//=====================================================================
double CalculateAdaptiveRisk()
{
   double baseRisk = InpBaseRiskPercent;
   
   if(!InpUseAdaptiveRisk)
      return baseRisk;
   
   double risk = baseRisk;
   
   // 1. Volatility scaling
   if(InpScaleByVolatility && g_vol.atrAvg > 0)
   {
      double volRatio = g_vol.atrCurrent / g_vol.atrAvg;
      
      if(volRatio > 1.5)  // High volatility - reduce risk
         risk *= 0.7;
      else if(volRatio > 1.2)
         risk *= 0.85;
      else if(volRatio < 0.7)  // Low volatility - can increase
         risk *= 1.15;
      else if(volRatio < 0.5)
         risk *= 0.8;  // Too low - also reduce
   }
   
   // 2. Account size scaling
   if(InpScaleByAccountSize)
   {
      double equity = AccountInfoDouble(ACCOUNT_EQUITY);
      
      if(equity < 1000)
         risk *= 0.5;  // Small account - very conservative
      else if(equity < 5000)
         risk *= 0.75;
      else if(equity < 10000)
         risk *= 0.9;
      else if(equity >= 50000)
         risk *= 1.2;  // Larger account - can take slightly more
   }
   
   // 3. Drawdown scaling
   if(g_risk.currentDrawdownPct > 5.0)
      risk *= 0.6;
   else if(g_risk.currentDrawdownPct > 3.0)
      risk *= 0.8;
   
   // 4. Session scaling
   switch(g_session.current)
   {
      case SESSION_OVERLAP:
         risk *= 1.2;  // Best session - can increase
         break;
      case SESSION_LONDON_OPEN:
      case SESSION_NY_OPEN:
         risk *= 0.9;  // High vol - slightly reduce
         break;
      case SESSION_ASIAN:
         risk *= 0.7;  // Low vol - reduce
         break;
      case SESSION_DEAD_ZONE:
         risk *= 0.5;  // Poor session
         break;
   }
   
   // 5. Win/loss streak scaling
   int recentWins = 0, recentLosses = 0;
   for(int i = 0; i < 5; i++)
   {
      // Check recent strategy performance
      for(int s = 0; s < 11; s++)
      {
         if(g_strategies[s].recentIndex > i)
         {
            if(g_strategies[s].recentPerformance[g_strategies[s].recentIndex - i - 1] > 0)
               recentWins++;
            else
               recentLosses++;
         }
      }
   }
   
   if(recentLosses >= 3)
      risk *= 0.7;  // Recent losses - reduce
   else if(recentWins >= 3)
      risk *= 1.1;  // Recent wins - can increase slightly
   
   // Clamp to min/max
   risk = MathMax(InpMinRiskPercent, MathMin(InpMaxRiskPercent, risk));
   
   return risk;
}

double CalculateLotSize(double slDistance, double riskPercent)
{
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   double riskAmount = equity * riskPercent / 100.0;
   
   // Gold-specific calculation
   // 1 lot = $100,000
   // 1 point move = $1 (for 0.01 lot)
   // SL distance is in price ($)
   
   double lotSize = riskAmount / slDistance / 100.0;
   
   // Normalize to broker requirements
   double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   
   lotSize = MathFloor(lotSize / lotStep) * lotStep;
   lotSize = MathMax(minLot, MathMin(maxLot, lotSize));
   
   return lotSize;
}

//=====================================================================
//  INDICATOR AUTO-SELECTION - ML BASED
//=====================================================================
void InitializeIndicators()
{
   // Initialize all indicators
   string names[] = {
      "EMA Fast", "EMA Slow", "EMA 200", "RSI", "Stochastic", 
      "MACD", "Bollinger", "ATR", "ADX", "CCI", 
      "Momentum", "Volume", "SuperTrend", "Ichimoku"
   };
   
   for(int i = 0; i < 14; i++)
   {
      g_indicators[i].type = (ENUM_INDICATOR)i;
      g_indicators[i].name = names[i];
      g_indicators[i].enabled = true;
      g_indicators[i].active = false;
      g_indicators[i].reliability = 50.0;
      g_indicators[i].mlWeight = 1.0;
      g_indicators[i].correlationPenalty = 0.0;
   }
}

void AutoSelectIndicators()
{
   if(!InpEnableML)
      return;
   
   // Auto-select best indicators based on:
   // 1. Current market regime
   // 2. Session
   // 3. Volatility
   // 4. Recent performance
   // 5. Correlation (avoid redundant signals)
   
   // Reset active status
   for(int i = 0; i < 14; i++)
      g_indicators[i].active = false;
   
   // Always active core indicators
   g_indicators[IND_EMA_FAST].active = true;
   g_indicators[IND_EMA_SLOW].active = true;
   g_indicators[IND_ATR].active = true;
   
   // Select based on regime
   switch(g_regime.regime)
   {
      case REGIME_STRONG_BULL_TREND:
      case REGIME_STRONG_BEAR_TREND:
         g_indicators[IND_ADX].active = true;
         g_indicators[IND_EMA_200].active = true;
         g_indicators[IND_MOMENTUM].active = true;
         break;
         
      case REGIME_RANGING:
         g_indicators[IND_RSI].active = true;
         g_indicators[IND_STOCHASTIC].active = true;
         g_indicators[IND_BOLLINGER].active = true;
         break;
         
      case REGIME_BREAKOUT:
         g_indicators[IND_BOLLINGER].active = true;
         g_indicators[IND_VOLUME_ANALYSIS].active = true;
         g_indicators[IND_ADX].active = true;
         break;
         
      case REGIME_MEAN_REVERSION:
         g_indicators[IND_RSI].active = true;
         g_indicators[IND_CCI].active = true;
         g_indicators[IND_BOLLINGER].active = true;
         break;
         
      case REGIME_LIQUIDITY_SWEEP:
         g_indicators[IND_VOLUME_ANALYSIS].active = true;
         g_indicators[IND_RSI].active = true;
         break;
   }
   
   // Select based on volatility
   if(g_vol.state == VOL_HIGH || g_vol.state == VOL_EXTREME)
   {
      g_indicators[IND_ATR].active = true;
      g_indicators[IND_BOLLINGER].active = true;
   }
   
   // Session-specific
   if(g_session.current == SESSION_OVERLAP || g_session.current == SESSION_NY_OPEN)
   {
      g_indicators[IND_VOLUME_ANALYSIS].active = true;
      g_indicators[IND_ADX].active = true;
   }
   
   // ML-based selection: Use indicators with highest reliability
   int activeCount = 0;
   for(int i = 0; i < 14; i++)
      if(g_indicators[i].active)
         activeCount++;
   
   // If too many active, prune lowest performers
   while(activeCount > 8)
   {
      double minReliability = 100.0;
      int minIndex = -1;
      
      for(int i = 0; i < 14; i++)
      {
         if(g_indicators[i].active && g_indicators[i].reliability < minReliability)
         {
            // Don't remove core indicators
            if(i != IND_EMA_FAST && i != IND_EMA_SLOW && i != IND_ATR)
            {
               minReliability = g_indicators[i].reliability;
               minIndex = i;
            }
         }
      }
      
      if(minIndex >= 0)
      {
         g_indicators[minIndex].active = false;
         activeCount--;
      }
      else
         break;
   }
}

void UpdateIndicatorPerformance(ENUM_INDICATOR ind, bool correct, double profit)
{
   int idx = (int)ind;
   if(idx < 0 || idx >= 14)
      return;
   
   g_indicators[idx].totalSignals++;
   if(correct)
      g_indicators[idx].correctSignals++;
   
   if(profit > 0)
      g_indicators[idx].avgProfit = (g_indicators[idx].avgProfit * (g_indicators[idx].totalSignals - 1) + profit) / g_indicators[idx].totalSignals;
   else
      g_indicators[idx].avgLoss = (g_indicators[idx].avgLoss * (g_indicators[idx].totalSignals - 1) + MathAbs(profit)) / g_indicators[idx].totalSignals;
   
   // Update win rate
   g_indicators[idx].winRate = (g_indicators[idx].totalSignals > 0) ? 
      100.0 * g_indicators[idx].correctSignals / g_indicators[idx].totalSignals : 0;
   
   // Update reliability
   g_indicators[idx].reliability = g_indicators[idx].winRate;
   
   // Update ML weight
   if(InpEnableML && g_indicators[idx].totalSignals >= InpMLMinSamples)
   {
      double performance = g_indicators[idx].winRate / 100.0;
      g_indicators[idx].mlWeight += InpMLLearningRate * (performance - 0.5);
      g_indicators[idx].mlWeight = MathMax(0.1, MathMin(2.0, g_indicators[idx].mlWeight));
   }
}

//=====================================================================
//  STRATEGY AUTO-SELECTION
//=====================================================================
void InitializeStrategies()
{
   string names[] = {
      "None", "Breakout Scalp", "Reversal Scalp", "Momentum Scalp",
      "Range Scalp", "Liquidity Reversal", "Compression Breakout",
      "FVG Fill", "OrderBlock Reaction", "Imbalance Scalp", "Session Breakout"
   };
   
   for(int i = 0; i < 11; i++)
   {
      g_strategies[i].type = (ENUM_STRATEGY)i;
      g_strategies[i].name = names[i];
      g_strategies[i].enabled = true;
      g_strategies[i].mlConfidence = 50.0;
      g_strategies[i].sessionMultiplier = 1.0;
      g_strategies[i].volatilityMultiplier = 1.0;
      g_strategies[i].recentIndex = 0;
   }
}

ENUM_STRATEGY AutoSelectBestStrategy()
{
   if(!InpAutoSelectStrategy)
      return g_session.preferredStrategy;
   
   double bestScore = -999999;
   ENUM_STRATEGY bestStrategy = STRAT_NONE;
   
   for(int i = 1; i < 11; i++)  // Skip STRAT_NONE
   {
      if(!g_strategies[i].enabled)
         continue;
      
      // Calculate composite score
      double score = 0;
      
      // 1. Historical performance (40%)
      score += g_strategies[i].expectancyR * 40.0;
      
      // 2. Recent performance (30%)
      double recentPerf = 0;
      int recentCount = MathMin(5, g_strategies[i].recentIndex);
      if(recentCount > 0)
      {
         for(int j = 0; j < recentCount; j++)
            recentPerf += g_strategies[i].recentPerformance[g_strategies[i].recentIndex - j - 1];
         recentPerf /= recentCount;
      }
      score += recentPerf * 30.0;
      
      // 3. ML confidence (20%)
      score += g_strategies[i].mlConfidence * 0.2;
      
      // 4. Session suitability (10%)
      score += g_strategies[i].sessionMultiplier * 10.0;
      
      // Adjust for current conditions
      switch((ENUM_STRATEGY)i)
      {
         case STRAT_BREAKOUT_SCALP:
            if(g_session.current == SESSION_LONDON_OPEN || g_session.current == SESSION_NY_OPEN)
               score *= 1.3;
            if(g_vol.state == VOL_HIGH || g_vol.expanding)
               score *= 1.2;
            break;
            
         case STRAT_REVERSAL_SCALP:
            if(g_liq.sweepUpDetected || g_liq.sweepDownDetected)
               score *= 1.4;
            if(g_regime.regime == REGIME_EXHAUSTION)
               score *= 1.3;
            break;
            
         case STRAT_RANGE_SCALP:
            if(g_regime.regime == REGIME_RANGING)
               score *= 1.5;
            if(g_vol.state == VOL_LOW || g_vol.state == VOL_ULTRA_LOW)
               score *= 1.2;
            break;
            
         case STRAT_MOMENTUM_SCALP:
            if(g_regime.regime == REGIME_STRONG_BULL_TREND || g_regime.regime == REGIME_STRONG_BEAR_TREND)
               score *= 1.4;
            if(g_mtf.alignment > 70)
               score *= 1.3;
            break;
            
         case STRAT_LIQUIDITY_REVERSAL:
            if(g_session.current == SESSION_OVERLAP)
               score *= 1.5;
            if(g_liq.sweepUpDetected || g_liq.sweepDownDetected)
               score *= 1.6;
            break;
      }
      
      if(score > bestScore)
      {
         bestScore = score;
         bestStrategy = (ENUM_STRATEGY)i;
      }
   }
   
   return bestStrategy;
}

void UpdateStrategyPerformance(ENUM_STRATEGY strat, double profit, double risk)
{
   int idx = (int)strat;
   if(idx < 0 || idx >= 11)
      return;
   
   g_strategies[idx].totalTrades++;
   
   double rMultiple = (risk > 0) ? profit / risk : 0;
   
   if(profit >= 0)
   {
      g_strategies[idx].wins++;
      g_strategies[idx].grossProfit += profit;
      g_strategies[idx].consecWins++;
      g_strategies[idx].consecLosses = 0;
   }
   else
   {
      g_strategies[idx].losses++;
      g_strategies[idx].grossLoss += MathAbs(profit);
      g_strategies[idx].consecLosses++;
      g_strategies[idx].consecWins = 0;
      
      if(g_strategies[idx].consecLosses > g_strategies[idx].maxConsecLosses)
         g_strategies[idx].maxConsecLosses = g_strategies[idx].consecLosses;
   }
   
   // Store in recent performance array
   if(g_strategies[idx].recentIndex < 20)
   {
      g_strategies[idx].recentPerformance[g_strategies[idx].recentIndex] = rMultiple;
      g_strategies[idx].recentIndex++;
   }
   else
   {
      // Shift array and add new
      for(int i = 0; i < 19; i++)
         g_strategies[idx].recentPerformance[i] = g_strategies[idx].recentPerformance[i + 1];
      g_strategies[idx].recentPerformance[19] = rMultiple;
   }
   
   // Update metrics
   g_strategies[idx].winRate = (g_strategies[idx].totalTrades > 0) ?
      100.0 * g_strategies[idx].wins / g_strategies[idx].totalTrades : 0;
   
   g_strategies[idx].profitFactor = (g_strategies[idx].grossLoss > 0) ?
      g_strategies[idx].grossProfit / g_strategies[idx].grossLoss : 0;
   
   double totalPnL = g_strategies[idx].grossProfit - g_strategies[idx].grossLoss;
   g_strategies[idx].expectancyR = (g_strategies[idx].totalTrades > 0) ?
      totalPnL / g_strategies[idx].totalTrades : 0;
   
   // ML confidence update
   if(InpEnableML && g_strategies[idx].totalTrades >= InpMLMinSamples)
   {
      double performance = (rMultiple > 0) ? 1.0 : 0.0;
      g_strategies[idx].mlConfidence += InpMLLearningRate * (performance * 100.0 - g_strategies[idx].mlConfidence);
   }
   
   // Disable strategy if performing poorly
   if(g_strategies[idx].totalTrades >= 20)
   {
      if(g_strategies[idx].winRate < 40.0 || g_strategies[idx].expectancyR < -0.5)
         g_strategies[idx].enabled = false;
      else if(g_strategies[idx].winRate > 50.0 && g_strategies[idx].expectancyR > 0)
         g_strategies[idx].enabled = true;
   }
}


//=====================================================================
//  ADVANCED VOLATILITY ANALYSIS
//=====================================================================
void UpdateVolatilityAnalysis()
{
   double atrBuffer[100];
   if(CopyBuffer(g_m5_atr, 0, 0, InpATRLookback, atrBuffer) < InpATRLookback)
      return;
      
   g_vol.atrCurrent = atrBuffer[0];
   
   // Calculate average ATR
   double sum = 0;
   for(int i = 0; i < InpATRLookback; i++)
      sum += atrBuffer[i];
   g_vol.atrAvg = sum / InpATRLookback;
   
   // ATR ratio
   g_vol.atrRatio = (g_vol.atrAvg > 0) ? g_vol.atrCurrent / g_vol.atrAvg : 1.0;
   
   // Calculate percentile
   int below = 0;
   for(int i = 0; i < InpATRLookback; i++)
      if(atrBuffer[i] <= g_vol.atrCurrent)
         below++;
   g_vol.percentile = 100.0 * below / InpATRLookback;
   
   // Classify state
   if(g_vol.percentile < 20)
      g_vol.state = VOL_ULTRA_LOW;
   else if(g_vol.percentile < 40)
      g_vol.state = VOL_LOW;
   else if(g_vol.percentile < 60)
      g_vol.state = VOL_NORMAL;
   else if(g_vol.percentile < 80)
      g_vol.state = VOL_HIGH;
   else if(g_vol.percentile < 95)
      g_vol.state = VOL_EXTREME;
   else
      g_vol.state = VOL_SHOCK;
   
   // Expansion/contraction detection
   double recent = 0, older = 0;
   for(int i = 0; i < 5; i++) recent += atrBuffer[i];
   for(int i = 5; i < 15; i++) older += atrBuffer[i];
   recent /= 5.0;
   older /= 10.0;
   
   double changeRate = (older > 0) ? (recent - older) / older : 0;
   
   g_vol.expanding = (changeRate > 0.15);
   g_vol.contracting = (changeRate < -0.15);
   g_vol.spike = (g_vol.atrRatio > 2.0);
   
   // Dynamic classification
   if(g_vol.spike)
      g_vol.dynamic = VOLDYN_SPIKE;
   else if(g_vol.expanding)
      g_vol.dynamic = VOLDYN_EXPANDING;
   else if(g_vol.contracting)
      g_vol.dynamic = VOLDYN_COMPRESSING;
   else
      g_vol.dynamic = VOLDYN_STABLE;
   
   // Historical volatility (std dev)
   double returns[50];
   for(int i = 0; i < 50; i++)
   {
      double close0 = iClose(_Symbol, PERIOD_M5, i);
      double close1 = iClose(_Symbol, PERIOD_M5, i + 1);
      returns[i] = (close1 > 0) ? (close0 - close1) / close1 : 0;
   }
   
   double mean = 0;
   for(int i = 0; i < 50; i++)
      mean += returns[i];
   mean /= 50.0;
   
   double variance = 0;
   for(int i = 0; i < 50; i++)
      variance += MathPow(returns[i] - mean, 2);
   variance /= 50.0;
   
   g_vol.historicalVol = MathSqrt(variance) * 100.0;
}

//=====================================================================
//  ADVANCED LIQUIDITY DETECTION
//=====================================================================
void UpdateLiquidityAnalysis()
{
   double swingHighs[50], swingLows[50];
   datetime highTimes[50], lowTimes[50];
   int highCount = 0, lowCount = 0;
   
   // Find swing points
   for(int i = 3; i < 60; i++)
   {
      double high = iHigh(_Symbol, PERIOD_M5, i);
      double low = iLow(_Symbol, PERIOD_M5, i);
      
      // Swing high
      bool isHigh = true;
      for(int j = 1; j <= 3; j++)
      {
         if(iHigh(_Symbol, PERIOD_M5, i-j) >= high || 
            iHigh(_Symbol, PERIOD_M5, i+j) >= high)
         {
            isHigh = false;
            break;
         }
      }
      
      if(isHigh && highCount < 50)
      {
         swingHighs[highCount] = high;
         highTimes[highCount] = iTime(_Symbol, PERIOD_M5, i);
         highCount++;
      }
      
      // Swing low
      bool isLow = true;
      for(int j = 1; j <= 3; j++)
      {
         if(iLow(_Symbol, PERIOD_M5, i-j) <= low || 
            iLow(_Symbol, PERIOD_M5, i+j) <= low)
         {
            isLow = false;
            break;
         }
      }
      
      if(isLow && lowCount < 50)
      {
         swingLows[lowCount] = low;
         lowTimes[lowCount] = iTime(_Symbol, PERIOD_M5, i);
         lowCount++;
      }
   }
   
   // Detect equal highs/lows (liquidity pools)
   double tolerance = g_vol.atrCurrent * 0.15;
   
   g_liq.equalHighsDetected = false;
   g_liq.equalLowsDetected = false;
   g_liq.equalHighCount = 0;
   g_liq.equalLowCount = 0;
   
   // Equal highs
   for(int i = 0; i < highCount; i++)
   {
      int matches = 1;
      double sumLevel = swingHighs[i];
      
      for(int j = i+1; j < highCount; j++)
      {
         if(MathAbs(swingHighs[i] - swingHighs[j]) <= tolerance)
         {
            matches++;
            sumLevel += swingHighs[j];
         }
      }
      
      if(matches >= 2 && matches > g_liq.equalHighCount)
      {
         g_liq.equalHighsDetected = true;
         g_liq.equalHighLevel = sumLevel / matches;
         g_liq.equalHighCount = matches;
      }
   }
   
   // Equal lows
   for(int i = 0; i < lowCount; i++)
   {
      int matches = 1;
      double sumLevel = swingLows[i];
      
      for(int j = i+1; j < lowCount; j++)
      {
         if(MathAbs(swingLows[i] - swingLows[j]) <= tolerance)
         {
            matches++;
            sumLevel += swingLows[j];
         }
      }
      
      if(matches >= 2 && matches > g_liq.equalLowCount)
      {
         g_liq.equalLowsDetected = true;
         g_liq.equalLowLevel = sumLevel / matches;
         g_liq.equalLowCount = matches;
      }
   }
   
   // Detect sweeps
   g_liq.sweepUpDetected = false;
   g_liq.sweepDownDetected = false;
   
   if(g_liq.equalHighsDetected)
   {
      for(int i = 0; i < 5; i++)
      {
         double high = iHigh(_Symbol, PERIOD_M5, i);
         double close = iClose(_Symbol, PERIOD_M5, i);
         
         if(high > g_liq.equalHighLevel && close < g_liq.equalHighLevel)
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
         double low = iLow(_Symbol, PERIOD_M5, i);
         double close = iClose(_Symbol, PERIOD_M5, i);
         
         if(low < g_liq.equalLowLevel && close > g_liq.equalLowLevel)
         {
            g_liq.sweepDownDetected = true;
            break;
         }
      }
   }
   
   // Calculate liquidity scores
   g_liq.buySideLiquidity = g_liq.equalHighCount * 100.0 / MathMax(1, highCount);
   g_liq.sellSideLiquidity = g_liq.equalLowCount * 100.0 / MathMax(1, lowCount);
   
   double totalLiq = g_liq.buySideLiquidity + g_liq.sellSideLiquidity;
   g_liq.imbalanceRatio = (totalLiq > 0) ? 
      MathAbs(g_liq.buySideLiquidity - g_liq.sellSideLiquidity) / totalLiq : 0;
   
   g_liq.liquidityScore = MathMin(100.0, totalLiq * 0.5 + g_liq.imbalanceRatio * 30.0);
}

//=====================================================================
//  MULTI-TIMEFRAME BIAS
//=====================================================================
int CalculateTFBias(int fastHandle, int slowHandle)
{
   double fast[2], slow[2];
   if(CopyBuffer(fastHandle, 0, 0, 2, fast) < 2 || 
      CopyBuffer(slowHandle, 0, 0, 2, slow) < 2)
      return 0;
      
   if(fast[0] > slow[0] && fast[1] > slow[1])
      return 1;
   else if(fast[0] < slow[0] && fast[1] < slow[1])
      return -1;
   else
      return 0;
}

void UpdateMTFBias()
{
   g_mtf.h4Bias  = CalculateTFBias(g_h4_ema_fast, g_h4_ema_slow);
   g_mtf.h1Bias  = CalculateTFBias(g_h1_ema_fast, g_h1_ema_slow);
   g_mtf.m30Bias = CalculateTFBias(g_m30_ema_fast, g_m30_ema_slow);
   g_mtf.m15Bias = CalculateTFBias(g_m15_ema_fast, g_m15_ema_slow);
   g_mtf.m5Bias  = CalculateTFBias(g_m5_ema_fast, g_m5_ema_slow);
   g_mtf.m1Bias  = CalculateTFBias(g_m1_ema_fast, g_m1_ema_slow);
   
   // Calculate alignment
   int biases[] = {g_mtf.h4Bias, g_mtf.h1Bias, g_mtf.m30Bias, g_mtf.m15Bias, g_mtf.m5Bias, g_mtf.m1Bias};
   int bullish = 0, bearish = 0;
   
   for(int i = 0; i < 6; i++)
   {
      if(biases[i] > 0) bullish++;
      else if(biases[i] < 0) bearish++;
   }
   
   int aligned = MathMax(bullish, bearish);
   g_mtf.alignment = 100.0 * aligned / 6.0;
   
   // Weighted strength
   double weights[] = {3.0, 2.5, 2.0, 1.5, 1.0, 0.5};
   double totalWeight = 0, weightedSum = 0;
   
   for(int i = 0; i < 6; i++)
   {
      totalWeight += weights[i];
      weightedSum += biases[i] * weights[i];
   }
   
   g_mtf.strength = (totalWeight > 0) ? MathAbs(weightedSum / totalWeight) * 100.0 : 0;
}

//=====================================================================
//  ORDER BLOCK DETECTION
//=====================================================================
void DetectOrderBlocks()
{
   g_obCount = 0;
   
   // Look for strong directional candles followed by reversal
   for(int i = 5; i < 50; i++)
   {
      double open = iOpen(_Symbol, PERIOD_M5, i);
      double close = iClose(_Symbol, PERIOD_M5, i);
      double high = iHigh(_Symbol, PERIOD_M5, i);
      double low = iLow(_Symbol, PERIOD_M5, i);
      double body = MathAbs(close - open);
      
      // Must be strong candle
      if(body < g_vol.atrAvg * 0.5)
         continue;
      
      bool isBullish = (close > open);
      
      // Check if followed by reversal in next 3 bars
      bool hasReversal = false;
      for(int j = i-1; j >= i-3 && j >= 0; j--)
      {
         double nextClose = iClose(_Symbol, PERIOD_M5, j);
         double nextOpen = iOpen(_Symbol, PERIOD_M5, j);
         
         if(isBullish && nextClose < nextOpen)
            hasReversal = true;
         else if(!isBullish && nextClose > nextOpen)
            hasReversal = true;
      }
      
      if(hasReversal && g_obCount < 30)
      {
         g_orderBlocks[g_obCount].high = high;
         g_orderBlocks[g_obCount].low = low;
         g_orderBlocks[g_obCount].time = iTime(_Symbol, PERIOD_M5, i);
         g_orderBlocks[g_obCount].bullish = isBullish;
         g_orderBlocks[g_obCount].strength = body / g_vol.atrAvg * 100.0;
         g_orderBlocks[g_obCount].tested = false;
         g_orderBlocks[g_obCount].broken = false;
         g_orderBlocks[g_obCount].touches = 0;
         
         // Check if price has tested this OB
         double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
         if(currentPrice >= low && currentPrice <= high)
         {
            g_orderBlocks[g_obCount].tested = true;
            g_orderBlocks[g_obCount].touches++;
         }
         
         g_obCount++;
      }
   }
}

//=====================================================================
//  FAIR VALUE GAP (FVG) DETECTION
//=====================================================================
void DetectFairValueGaps()
{
   g_fvgCount = 0;
   
   for(int i = 2; i < 50; i++)
   {
      double high1 = iHigh(_Symbol, PERIOD_M5, i+1);
      double low1 = iLow(_Symbol, PERIOD_M5, i+1);
      double high3 = iHigh(_Symbol, PERIOD_M5, i-1);
      double low3 = iLow(_Symbol, PERIOD_M5, i-1);
      
      // Bullish FVG: gap between candle[i+1] high and candle[i-1] low
      if(low3 > high1 && (low3 - high1) > g_vol.atrAvg * 0.3)
      {
         if(g_fvgCount < 30)
         {
            g_fvgs[g_fvgCount].upper = low3;
            g_fvgs[g_fvgCount].lower = high1;
            g_fvgs[g_fvgCount].time = iTime(_Symbol, PERIOD_M5, i);
            g_fvgs[g_fvgCount].bullish = true;
            g_fvgs[g_fvgCount].filled = false;
            g_fvgs[g_fvgCount].fillPercent = 0;
            g_fvgs[g_fvgCount].strength = (low3 - high1) / g_vol.atrAvg * 100.0;
            
            // Check if filled
            double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
            if(currentPrice <= g_fvgs[g_fvgCount].upper && currentPrice >= g_fvgs[g_fvgCount].lower)
            {
               double gapSize = g_fvgs[g_fvgCount].upper - g_fvgs[g_fvgCount].lower;
               double filled = g_fvgs[g_fvgCount].upper - currentPrice;
               g_fvgs[g_fvgCount].fillPercent = (gapSize > 0) ? filled / gapSize * 100.0 : 0;
               
               if(g_fvgs[g_fvgCount].fillPercent > 80)
                  g_fvgs[g_fvgCount].filled = true;
            }
            
            g_fvgCount++;
         }
      }
      
      // Bearish FVG: gap between candle[i+1] low and candle[i-1] high
      if(high3 < low1 && (low1 - high3) > g_vol.atrAvg * 0.3)
      {
         if(g_fvgCount < 30)
         {
            g_fvgs[g_fvgCount].upper = low1;
            g_fvgs[g_fvgCount].lower = high3;
            g_fvgs[g_fvgCount].time = iTime(_Symbol, PERIOD_M5, i);
            g_fvgs[g_fvgCount].bullish = false;
            g_fvgs[g_fvgCount].filled = false;
            g_fvgs[g_fvgCount].fillPercent = 0;
            g_fvgs[g_fvgCount].strength = (low1 - high3) / g_vol.atrAvg * 100.0;
            
            // Check if filled
            double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
            if(currentPrice <= g_fvgs[g_fvgCount].upper && currentPrice >= g_fvgs[g_fvgCount].lower)
            {
               double gapSize = g_fvgs[g_fvgCount].upper - g_fvgs[g_fvgCount].lower;
               double filled = currentPrice - g_fvgs[g_fvgCount].lower;
               g_fvgs[g_fvgCount].fillPercent = (gapSize > 0) ? filled / gapSize * 100.0 : 0;
               
               if(g_fvgs[g_fvgCount].fillPercent > 80)
                  g_fvgs[g_fvgCount].filled = true;
            }
            
            g_fvgCount++;
         }
      }
   }
}

//=====================================================================
//  CHoCH (Change of Character) & BOS (Break of Structure) DETECTION
//=====================================================================
void DetectStructureBreaks()
{
   g_patternCount = 0;
   
   // Find recent swing highs and lows
   double swingHigh = 0, swingLow = 999999;
   int highBar = -1, lowBar = -1;
   
   for(int i = 3; i < 20; i++)
   {
      double high = iHigh(_Symbol, PERIOD_M5, i);
      double low = iLow(_Symbol, PERIOD_M5, i);
      
      // Check if swing high
      bool isSwingHigh = true;
      for(int j = 1; j <= 3; j++)
      {
         if(iHigh(_Symbol, PERIOD_M5, i-j) >= high || 
            iHigh(_Symbol, PERIOD_M5, i+j) >= high)
         {
            isSwingHigh = false;
            break;
         }
      }
      
      if(isSwingHigh && high > swingHigh)
      {
         swingHigh = high;
         highBar = i;
      }
      
      // Check if swing low
      bool isSwingLow = true;
      for(int j = 1; j <= 3; j++)
      {
         if(iLow(_Symbol, PERIOD_M5, i-j) <= low || 
            iLow(_Symbol, PERIOD_M5, i+j) <= low)
         {
            isSwingLow = false;
            break;
         }
      }
      
      if(isSwingLow && low < swingLow)
      {
         swingLow = low;
         lowBar = i;
      }
   }
   
   double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   
   // BOS - Break of Structure (strong trend continuation)
   if(swingHigh > 0 && currentPrice > swingHigh && g_patternCount < 50)
   {
      g_patterns[g_patternCount].type = "BOS";
      g_patterns[g_patternCount].priceLevel = swingHigh;
      g_patterns[g_patternCount].time = iTime(_Symbol, PERIOD_M5, highBar);
      g_patterns[g_patternCount].bullish = true;
      g_patterns[g_patternCount].strength = (currentPrice - swingHigh) / g_vol.atrAvg * 100.0;
      g_patterns[g_patternCount].active = true;
      g_patternCount++;
   }
   
   if(swingLow < 999999 && currentPrice < swingLow && g_patternCount < 50)
   {
      g_patterns[g_patternCount].type = "BOS";
      g_patterns[g_patternCount].priceLevel = swingLow;
      g_patterns[g_patternCount].time = iTime(_Symbol, PERIOD_M5, lowBar);
      g_patterns[g_patternCount].bullish = false;
      g_patterns[g_patternCount].strength = (swingLow - currentPrice) / g_vol.atrAvg * 100.0;
      g_patterns[g_patternCount].active = true;
      g_patternCount++;
   }
   
   // CHoCH - Change of Character (trend reversal signal)
   // Detected when price breaks counter-trend structure
   if(g_mtf.m5Bias == 1 && swingLow < 999999)  // Was bullish
   {
      // Check if broke below recent swing low
      for(int i = 0; i < 5; i++)
      {
         if(iLow(_Symbol, PERIOD_M5, i) < swingLow && g_patternCount < 50)
         {
            g_patterns[g_patternCount].type = "CHoCH";
            g_patterns[g_patternCount].priceLevel = swingLow;
            g_patterns[g_patternCount].time = iTime(_Symbol, PERIOD_M5, i);
            g_patterns[g_patternCount].bullish = false;
            g_patterns[g_patternCount].strength = 75.0;
            g_patterns[g_patternCount].active = true;
            g_patternCount++;
            break;
         }
      }
   }
   
   if(g_mtf.m5Bias == -1 && swingHigh > 0)  // Was bearish
   {
      // Check if broke above recent swing high
      for(int i = 0; i < 5; i++)
      {
         if(iHigh(_Symbol, PERIOD_M5, i) > swingHigh && g_patternCount < 50)
         {
            g_patterns[g_patternCount].type = "CHoCH";
            g_patterns[g_patternCount].priceLevel = swingHigh;
            g_patterns[g_patternCount].time = iTime(_Symbol, PERIOD_M5, i);
            g_patterns[g_patternCount].bullish = true;
            g_patterns[g_patternCount].strength = 75.0;
            g_patterns[g_patternCount].active = true;
            g_patternCount++;
            break;
         }
      }
   }
   
   // MSS - Market Structure Shift (similar to CHoCH but stronger)
   // Add MSS detection based on higher timeframe structure
}

//=====================================================================
//  REGIME CLASSIFICATION WITH ML
//=====================================================================
void UpdateRegimeClassification()
{
   double scores[16];
   
   // Score each regime
   scores[0] = ScoreStrongBullTrend();
   scores[1] = ScoreWeakBullTrend();
   scores[2] = ScoreStrongBearTrend();
   scores[3] = ScoreWeakBearTrend();
   scores[4] = ScoreRanging();
   scores[5] = ScoreBreakout();
   scores[6] = ScoreCompression();
   scores[7] = ScoreExpansion();
   scores[8] = ScoreVolShock();
   scores[9] = ScoreLiquiditySweep();
   scores[10] = ScoreExhaustion();
   scores[11] = ScoreMeanReversion();
   scores[12] = ScoreNewsEvent();
   scores[13] = ScoreAccumulation();
   scores[14] = ScoreDistribution();
   scores[15] = ScoreUnsafe();
   
   // Find highest score
   int bestIdx = 0;
   double bestScore = scores[0];
   
   for(int i = 1; i < 16; i++)
   {
      if(scores[i] > bestScore)
      {
         bestScore = scores[i];
         bestIdx = i;
      }
   }
   
   ENUM_REGIME newRegime = (ENUM_REGIME)bestIdx;
   
   // Update regime state
   if(newRegime != g_regime.regime)
   {
      g_regime.previousRegime = g_regime.regime;
      g_regime.regime = newRegime;
      g_regime.barsInRegime = 0;
      g_regime.sinceTime = TimeCurrent();
   }
   else
   {
      g_regime.barsInRegime++;
   }
   
   g_regime.confidence = bestScore;
   g_regime.stability = MathMin(100.0, g_regime.barsInRegime * 5.0);
   
   // Calculate trend strength
   g_regime.trendStrength = g_mtf.strength;
}

// Individual regime scoring functions
double ScoreStrongBullTrend()
{
   double score = 0;
   if(g_mtf.h4Bias > 0) score += 30;
   if(g_mtf.h1Bias > 0) score += 25;
   if(g_mtf.m15Bias > 0) score += 20;
   if(g_mtf.alignment > 70) score += 25;
   return MathMin(100.0, score);
}

double ScoreWeakBullTrend()
{
   double score = 0;
   if(g_mtf.h1Bias > 0) score += 20;
   if(g_mtf.m15Bias > 0) score += 20;
   if(g_mtf.alignment > 50 && g_mtf.alignment < 70) score += 30;
   if(g_vol.state == VOL_NORMAL) score += 15;
   return MathMin(100.0, score);
}

double ScoreStrongBearTrend()
{
   double score = 0;
   if(g_mtf.h4Bias < 0) score += 30;
   if(g_mtf.h1Bias < 0) score += 25;
   if(g_mtf.m15Bias < 0) score += 20;
   if(g_mtf.alignment > 70) score += 25;
   return MathMin(100.0, score);
}

double ScoreWeakBearTrend()
{
   double score = 0;
   if(g_mtf.h1Bias < 0) score += 20;
   if(g_mtf.m15Bias < 0) score += 20;
   if(g_mtf.alignment > 50 && g_mtf.alignment < 70) score += 30;
   if(g_vol.state == VOL_NORMAL) score += 15;
   return MathMin(100.0, score);
}

double ScoreRanging()
{
   double score = 0;
   if(g_mtf.alignment < 40) score += 40;
   if(g_vol.state == VOL_LOW || g_vol.state == VOL_ULTRA_LOW) score += 30;
   if(g_vol.dynamic == VOLDYN_STABLE) score += 20;
   return MathMin(100.0, score);
}

double ScoreBreakout()
{
   double score = 0;
   if(g_vol.expanding) score += 35;
   if(g_vol.state == VOL_HIGH) score += 25;
   
   // Check if price broke recent high/low
   double recentHigh = iHigh(_Symbol, PERIOD_M5, iHighest(_Symbol, PERIOD_M5, MODE_HIGH, 20, 1));
   double recentLow = iLow(_Symbol, PERIOD_M5, iLowest(_Symbol, PERIOD_M5, MODE_LOW, 20, 1));
   double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   
   if(currentPrice > recentHigh || currentPrice < recentLow)
      score += 40;
   
   return MathMin(100.0, score);
}

double ScoreCompression()
{
   double score = 0;
   if(g_vol.state == VOL_ULTRA_LOW || g_vol.state == VOL_LOW) score += 40;
   if(g_vol.contracting) score += 30;
   if(g_mtf.alignment < 30) score += 20;
   return MathMin(100.0, score);
}

double ScoreExpansion()
{
   double score = 0;
   if(g_vol.expanding) score += 40;
   if(g_vol.state == VOL_HIGH || g_vol.state == VOL_EXTREME) score += 30;
   if(g_mtf.alignment > 60) score += 20;
   return MathMin(100.0, score);
}

double ScoreVolShock()
{
   double score = 0;
   if(g_vol.spike) score += 50;
   if(g_vol.state == VOL_SHOCK) score += 50;
   return MathMin(100.0, score);
}

double ScoreLiquiditySweep()
{
   double score = 0;
   if(g_liq.sweepUpDetected || g_liq.sweepDownDetected) score += 60;
   score += g_liq.liquidityScore * 0.3;
   return MathMin(100.0, score);
}

double ScoreExhaustion()
{
   double score = 0;
   double rsi[1];
   if(CopyBuffer(g_m5_rsi, 0, 0, 1, rsi) > 0)
   {
      if(rsi[0] > 75 || rsi[0] < 25) score += 40;
   }
   
   if(g_vol.contracting && g_vol.atrRatio < 0.8) score += 30;
   if(g_mtf.m1Bias != g_mtf.m5Bias && g_mtf.m1Bias != 0) score += 20;
   
   return MathMin(100.0, score);
}

double ScoreMeanReversion()
{
   double score = 0;
   double rsi[1];
   if(CopyBuffer(g_m5_rsi, 0, 0, 1, rsi) > 0)
   {
      if(rsi[0] > 70 || rsi[0] < 30) score += 35;
   }
   
   if(g_vol.state == VOL_NORMAL) score += 25;
   if(g_liq.sweepUpDetected || g_liq.sweepDownDetected) score += 20;
   
   return MathMin(100.0, score);
}

double ScoreNewsEvent()
{
   double score = 0;
   if(g_vol.spike) score += 40;
   
   // Check for unusual spread
   double spread = (double)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   if(spread > InpMaxSpreadPoints * 1.5) score += 30;
   
   return MathMin(100.0, score);
}

double ScoreAccumulation()
{
   double score = 0;
   if(g_vol.state == VOL_LOW || g_vol.state == VOL_ULTRA_LOW) score += 30;
   if(g_mtf.alignment < 40) score += 25;
   
   // Check for tight range
   double range = iHigh(_Symbol, PERIOD_M5, iHighest(_Symbol, PERIOD_M5, MODE_HIGH, 20, 0)) -
                  iLow(_Symbol, PERIOD_M5, iLowest(_Symbol, PERIOD_M5, MODE_LOW, 20, 0));
   if(range < g_vol.atrAvg * 2.0) score += 25;
   
   return MathMin(100.0, score);
}

double ScoreDistribution()
{
   double score = 0;
   if(g_vol.state == VOL_NORMAL || g_vol.state == VOL_HIGH) score += 25;
   
   // Check for wide range with no follow-through
   double range = iHigh(_Symbol, PERIOD_M5, iHighest(_Symbol, PERIOD_M5, MODE_HIGH, 10, 0)) -
                  iLow(_Symbol, PERIOD_M5, iLowest(_Symbol, PERIOD_M5, MODE_LOW, 10, 0));
   if(range > g_vol.atrAvg * 3.0 && g_mtf.m5Bias == 0) score += 35;
   
   return MathMin(100.0, score);
}

double ScoreUnsafe()
{
   double score = 0;
   
   if(g_vol.state == VOL_SHOCK) score += 40;
   
   double spread = (double)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   if(spread > InpMaxSpreadPoints) score += 30;
   
   if(g_session.current == SESSION_DEAD_ZONE) score += 20;
   
   return MathMin(100.0, score);
}

//=====================================================================
//  STRATEGY SIGNAL GENERATION - ALL 10 STRATEGIES
//=====================================================================

StrategySignal Strategy_BreakoutScalp()
{
   StrategySignal sig;
   sig.source = STRAT_BREAKOUT_SCALP;
   sig.valid = false;
   sig.direction = 0;
   sig.reason = "";
   
   if(!InpEnableBreakout || !g_strategies[STRAT_BREAKOUT_SCALP].enabled)
   {
      sig.reason = "Strategy disabled";
      return sig;
   }
   
   // Best during London/NY open with expanding volatility
   if(g_session.current != SESSION_LONDON_OPEN && 
      g_session.current != SESSION_NY_OPEN && 
      g_session.current != SESSION_OVERLAP)
   {
      sig.reason = "Wrong session for breakout";
      return sig;
   }
   
   if(!g_vol.expanding && g_vol.state < VOL_NORMAL)
   {
      sig.reason = "Volatility not expanding";
      return sig;
   }
   
   // Find recent range
   double rangeHigh = iHigh(_Symbol, PERIOD_M5, iHighest(_Symbol, PERIOD_M5, MODE_HIGH, 20, 1));
   double rangeLow = iLow(_Symbol, PERIOD_M5, iLowest(_Symbol, PERIOD_M5, MODE_LOW, 20, 1));
   double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   
   // Breakout long
   if(currentPrice > rangeHigh && g_mtf.m5Bias >= 0)
   {
      sig.direction = 1;
      sig.valid = true;
      sig.confidence = 75.0;
      sig.suggestedSL = NPrice(rangeLow - g_vol.atrAvg * 0.2);
      sig.suggestedTP = NPrice(currentPrice + g_vol.atrAvg * 2.0);
      sig.reason = "Bullish breakout detected";
      sig.indicatorsAgreeing = 3;
      sig.qualityScore = 80.0;
   }
   // Breakout short
   else if(currentPrice < rangeLow && g_mtf.m5Bias <= 0)
   {
      sig.direction = -1;
      sig.valid = true;
      sig.confidence = 75.0;
      sig.suggestedSL = NPrice(rangeHigh + g_vol.atrAvg * 0.2);
      sig.suggestedTP = NPrice(currentPrice - g_vol.atrAvg * 2.0);
      sig.reason = "Bearish breakout detected";
      sig.indicatorsAgreeing = 3;
      sig.qualityScore = 80.0;
   }
   
   return sig;
}

StrategySignal Strategy_ReversalScalp()
{
   StrategySignal sig;
   sig.source = STRAT_REVERSAL_SCALP;
   sig.valid = false;
   sig.direction = 0;
   
   if(!InpEnableReversal || !g_strategies[STRAT_REVERSAL_SCALP].enabled)
      return sig;
   
   // Best after liquidity sweep
   if(!g_liq.sweepUpDetected && !g_liq.sweepDownDetected)
   {
      sig.reason = "No sweep detected";
      return sig;
   }
   
   double rsi[1];
   if(CopyBuffer(g_m5_rsi, 0, 0, 1, rsi) < 1)
      return sig;
   
   // Bullish reversal after sweep down
   if(g_liq.sweepDownDetected && rsi[0] < 30)
   {
      sig.direction = 1;
      sig.valid = true;
      sig.confidence = 85.0;
      double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      sig.suggestedSL = NPrice(g_liq.equalLowLevel - g_vol.atrAvg * 0.3);
      sig.suggestedTP = NPrice(entry + g_vol.atrAvg * 2.5);
      sig.reason = "Liquidity sweep reversal - LONG";
      sig.indicatorsAgreeing = 4;
      sig.qualityScore = 90.0;
   }
   // Bearish reversal after sweep up
   else if(g_liq.sweepUpDetected && rsi[0] > 70)
   {
      sig.direction = -1;
      sig.valid = true;
      sig.confidence = 85.0;
      double entry = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      sig.suggestedSL = NPrice(g_liq.equalHighLevel + g_vol.atrAvg * 0.3);
      sig.suggestedTP = NPrice(entry - g_vol.atrAvg * 2.5);
      sig.reason = "Liquidity sweep reversal - SHORT";
      sig.indicatorsAgreeing = 4;
      sig.qualityScore = 90.0;
   }
   
   return sig;
}

StrategySignal Strategy_MomentumScalp()
{
   StrategySignal sig;
   sig.source = STRAT_MOMENTUM_SCALP;
   sig.valid = false;
   sig.direction = 0;
   
   if(!InpEnableMomentum || !g_strategies[STRAT_MOMENTUM_SCALP].enabled)
      return sig;
   
   // Need strong MTF alignment
   if(g_mtf.alignment < 65)
   {
      sig.reason = "Insufficient MTF alignment";
      return sig;
   }
   
   // Need trending regime
   if(g_regime.regime != REGIME_STRONG_BULL_TREND && 
      g_regime.regime != REGIME_STRONG_BEAR_TREND &&
      g_regime.regime != REGIME_WEAK_BULL_TREND &&
      g_regime.regime != REGIME_WEAK_BEAR_TREND)
   {
      sig.reason = "Not in trending regime";
      return sig;
   }
   
   int trendDir = (g_mtf.h1Bias > 0) ? 1 : -1;
   
   // Wait for pullback on M5
   if(g_mtf.m5Bias == trendDir)
   {
      sig.reason = "Waiting for pullback";
      return sig;
   }
   
   double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   
   // Long momentum
   if(trendDir > 0)
   {
      sig.direction = 1;
      sig.valid = true;
      sig.confidence = 80.0;
      sig.suggestedSL = NPrice(currentPrice - g_vol.atrAvg * 1.2);
      sig.suggestedTP = NPrice(currentPrice + g_vol.atrAvg * 2.5);
      sig.reason = "Momentum scalp on pullback - LONG";
      sig.indicatorsAgreeing = 5;
      sig.qualityScore = 85.0;
   }
   // Short momentum
   else
   {
      sig.direction = -1;
      sig.valid = true;
      sig.confidence = 80.0;
      sig.suggestedSL = NPrice(currentPrice + g_vol.atrAvg * 1.2);
      sig.suggestedTP = NPrice(currentPrice - g_vol.atrAvg * 2.5);
      sig.reason = "Momentum scalp on pullback - SHORT";
      sig.indicatorsAgreeing = 5;
      sig.qualityScore = 85.0;
   }
   
   return sig;
}

StrategySignal Strategy_RangeScalp()
{
   StrategySignal sig;
   sig.source = STRAT_RANGE_SCALP;
   sig.valid = false;
   sig.direction = 0;
   
   if(!InpEnableRange || !g_strategies[STRAT_RANGE_SCALP].enabled)
      return sig;
   
   if(g_regime.regime != REGIME_RANGING)
   {
      sig.reason = "Not in ranging regime";
      return sig;
   }
   
   // Find range
   double rangeHigh = iHigh(_Symbol, PERIOD_M5, iHighest(_Symbol, PERIOD_M5, MODE_HIGH, 30, 1));
   double rangeLow = iLow(_Symbol, PERIOD_M5, iLowest(_Symbol, PERIOD_M5, MODE_LOW, 30, 1));
   double rangeMid = (rangeHigh + rangeLow) / 2.0;
   double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   
   double rsi[1];
   if(CopyBuffer(g_m5_rsi, 0, 0, 1, rsi) < 1)
      return sig;
   
   // Buy at support
   if(currentPrice <= rangeLow + (rangeHigh - rangeLow) * 0.2 && rsi[0] < 40)
   {
      sig.direction = 1;
      sig.valid = true;
      sig.confidence = 70.0;
      sig.suggestedSL = NPrice(rangeLow - g_vol.atrAvg * 0.5);
      sig.suggestedTP = NPrice(rangeMid);
      sig.reason = "Range support bounce";
      sig.indicatorsAgreeing = 3;
      sig.qualityScore = 75.0;
   }
   // Sell at resistance
   else if(currentPrice >= rangeHigh - (rangeHigh - rangeLow) * 0.2 && rsi[0] > 60)
   {
      sig.direction = -1;
      sig.valid = true;
      sig.confidence = 70.0;
      sig.suggestedSL = NPrice(rangeHigh + g_vol.atrAvg * 0.5);
      sig.suggestedTP = NPrice(rangeMid);
      sig.reason = "Range resistance rejection";
      sig.indicatorsAgreeing = 3;
      sig.qualityScore = 75.0;
   }
   
   return sig;
}

StrategySignal Strategy_FVGFill()
{
   StrategySignal sig;
   sig.source = STRAT_FVG_FILL;
   sig.valid = false;
   sig.direction = 0;
   
   if(!InpEnableFVG || !g_strategies[STRAT_FVG_FILL].enabled)
      return sig;
   
   if(g_fvgCount == 0)
   {
      sig.reason = "No FVG detected";
      return sig;
   }
   
   double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   
   // Find nearest unfilled FVG
   for(int i = 0; i < g_fvgCount; i++)
   {
      if(g_fvgs[i].filled)
         continue;
      
      // Price entering bullish FVG
      if(g_fvgs[i].bullish && 
         currentPrice <= g_fvgs[i].upper && 
         currentPrice >= g_fvgs[i].lower)
      {
         sig.direction = 1;
         sig.valid = true;
         sig.confidence = 75.0;
         sig.suggestedSL = NPrice(g_fvgs[i].lower - g_vol.atrAvg * 0.3);
         sig.suggestedTP = NPrice(currentPrice + g_vol.atrAvg * 2.0);
         sig.reason = "Bullish FVG fill opportunity";
         sig.indicatorsAgreeing = 3;
         sig.qualityScore = 80.0;
         break;
      }
      // Price entering bearish FVG
      else if(!g_fvgs[i].bullish && 
              currentPrice <= g_fvgs[i].upper && 
              currentPrice >= g_fvgs[i].lower)
      {
         sig.direction = -1;
         sig.valid = true;
         sig.confidence = 75.0;
         sig.suggestedSL = NPrice(g_fvgs[i].upper + g_vol.atrAvg * 0.3);
         sig.suggestedTP = NPrice(currentPrice - g_vol.atrAvg * 2.0);
         sig.reason = "Bearish FVG fill opportunity";
         sig.indicatorsAgreeing = 3;
         sig.qualityScore = 80.0;
         break;
      }
   }
   
   return sig;
}

StrategySignal Strategy_OrderBlockReaction()
{
   StrategySignal sig;
   sig.source = STRAT_ORDERBLOCK_REACTION;
   sig.valid = false;
   sig.direction = 0;
   
   if(!InpEnableOrderBlock || !g_strategies[STRAT_ORDERBLOCK_REACTION].enabled)
      return sig;
   
   if(g_obCount == 0)
   {
      sig.reason = "No order blocks detected";
      return sig;
   }
   
   double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   
   // Find order blocks being tested
   for(int i = 0; i < g_obCount; i++)
   {
      if(g_orderBlocks[i].broken)
         continue;
      
      bool priceInOB = (currentPrice >= g_orderBlocks[i].low && 
                        currentPrice <= g_orderBlocks[i].high);
      
      if(!priceInOB)
         continue;
      
      // Bullish OB reaction
      if(g_orderBlocks[i].bullish && g_mtf.m5Bias >= 0)
      {
         sig.direction = 1;
         sig.valid = true;
         sig.confidence = 80.0;
         sig.suggestedSL = NPrice(g_orderBlocks[i].low - g_vol.atrAvg * 0.3);
         sig.suggestedTP = NPrice(currentPrice + g_vol.atrAvg * 2.5);
         sig.reason = "Bullish order block reaction";
         sig.indicatorsAgreeing = 4;
         sig.qualityScore = 85.0;
         break;
      }
      // Bearish OB reaction
      else if(!g_orderBlocks[i].bullish && g_mtf.m5Bias <= 0)
      {
         sig.direction = -1;
         sig.valid = true;
         sig.confidence = 80.0;
         sig.suggestedSL = NPrice(g_orderBlocks[i].high + g_vol.atrAvg * 0.3);
         sig.suggestedTP = NPrice(currentPrice - g_vol.atrAvg * 2.5);
         sig.reason = "Bearish order block reaction";
         sig.indicatorsAgreeing = 4;
         sig.qualityScore = 85.0;
         break;
      }
   }
   
   return sig;
}

//=====================================================================
//  MASTER SIGNAL GENERATION - AUTO-SELECT BEST STRATEGY
//=====================================================================
StrategySignal GenerateMasterSignal()
{
   StrategySignal bestSignal;
   bestSignal.valid = false;
   bestSignal.confidence = 0;
   
   // Get best strategy for current conditions
   ENUM_STRATEGY bestStrategy = AutoSelectBestStrategy();
   
   // Generate signal from best strategy
   StrategySignal sig;
   
   switch(bestStrategy)
   {
      case STRAT_BREAKOUT_SCALP:
         sig = Strategy_BreakoutScalp();
         break;
      case STRAT_REVERSAL_SCALP:
         sig = Strategy_ReversalScalp();
         break;
      case STRAT_MOMENTUM_SCALP:
         sig = Strategy_MomentumScalp();
         break;
      case STRAT_RANGE_SCALP:
         sig = Strategy_RangeScalp();
         break;
      case STRAT_FVG_FILL:
         sig = Strategy_FVGFill();
         break;
      case STRAT_ORDERBLOCK_REACTION:
         sig = Strategy_OrderBlockReaction();
         break;
      default:
         return bestSignal;
   }
   
   // If primary strategy doesn't give signal, try others
   if(!sig.valid)
   {
      StrategySignal signals[6];
      signals[0] = Strategy_BreakoutScalp();
      signals[1] = Strategy_ReversalScalp();
      signals[2] = Strategy_MomentumScalp();
      signals[3] = Strategy_RangeScalp();
      signals[4] = Strategy_FVGFill();
      signals[5] = Strategy_OrderBlockReaction();
      
      double bestConf = 0;
      for(int i = 0; i < 6; i++)
      {
         if(signals[i].valid && signals[i].confidence > bestConf)
         {
            sig = signals[i];
            bestConf = signals[i].confidence;
         }
      }
   }
   
   return sig;
}

//=====================================================================
//  EXECUTION QUALITY ASSESSMENT
//=====================================================================
void UpdateExecutionQuality()
{
   double spread = (double)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   
   // Spread score
   g_execQuality.spreadScore = MathMax(0.0, 100.0 * (1.0 - spread / InpMaxSpreadPoints));
   
   // Slippage risk
   if(g_vol.state == VOL_SHOCK || g_vol.spike)
      g_execQuality.slippageRisk = 20.0;
   else if(g_vol.state == VOL_EXTREME)
      g_execQuality.slippageRisk = 40.0;
   else if(g_vol.state == VOL_HIGH)
      g_execQuality.slippageRisk = 70.0;
   else
      g_execQuality.slippageRisk = 90.0;
   
   // Volatility quality
   if(g_vol.state == VOL_NORMAL || g_vol.state == VOL_HIGH)
      g_execQuality.volatilityQuality = 100.0;
   else if(g_vol.state == VOL_LOW)
      g_execQuality.volatilityQuality = 70.0;
   else if(g_vol.state == VOL_ULTRA_LOW)
      g_execQuality.volatilityQuality = 50.0;
   else
      g_execQuality.volatilityQuality = 30.0;
   
   // Liquidity quality (session-based)
   switch(g_session.current)
   {
      case SESSION_OVERLAP:
         g_execQuality.liquidityQuality = 100.0;
         break;
      case SESSION_LONDON_OPEN:
      case SESSION_NY_OPEN:
         g_execQuality.liquidityQuality = 90.0;
         break;
      case SESSION_LONDON_MID:
      case SESSION_NY_PM:
         g_execQuality.liquidityQuality = 80.0;
         break;
      case SESSION_ASIAN:
         g_execQuality.liquidityQuality = 60.0;
         break;
      default:
         g_execQuality.liquidityQuality = 30.0;
   }
   
   // Timing score
   g_execQuality.timingScore = 100.0;
   if(g_inCooldown)
      g_execQuality.timingScore = 0;
   
   // Composite score
   g_execQuality.compositeScore = 
      g_execQuality.spreadScore * 0.30 +
      g_execQuality.slippageRisk * 0.25 +
      g_execQuality.volatilityQuality * 0.20 +
      g_execQuality.liquidityQuality * 0.15 +
      g_execQuality.timingScore * 0.10;
   
   // Approval logic
   g_execQuality.executionApproved = true;
   g_execQuality.rejectReason = "";
   
   if(spread > InpMaxSpreadPoints && InpUseSpreadFilter)
   {
      g_execQuality.executionApproved = false;
      g_execQuality.rejectReason = "SPREAD TOO HIGH";
   }
   else if(g_execQuality.compositeScore < InpMinExecutionScore)
   {
      g_execQuality.executionApproved = false;
      g_execQuality.rejectReason = "LOW EXECUTION QUALITY";
   }
   else if(g_vol.state == VOL_SHOCK && InpUseVolatilityFilter)
   {
      g_execQuality.executionApproved = false;
      g_execQuality.rejectReason = "VOLATILITY SHOCK";
   }
}

//=====================================================================
//  RISK MANAGEMENT
//=====================================================================
void InitRiskState()
{
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   g_risk.peakEquity = equity;
   g_risk.dayStartEquity = equity;
   g_risk.weekStartEquity = equity;
   g_risk.dailyLimitHit = false;
   g_risk.weeklyLimitHit = false;
   g_risk.emergencyShutdown = false;
}

void UpdateRiskState()
{
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   
   if(equity > g_risk.peakEquity)
      g_risk.peakEquity = equity;
   
   g_risk.currentDrawdownPct = (g_risk.peakEquity > 0) ? 
      (g_risk.peakEquity - equity) / g_risk.peakEquity * 100.0 : 0;
   
   if(g_risk.currentDrawdownPct > g_risk.maxDrawdownSeenPct)
      g_risk.maxDrawdownSeenPct = g_risk.currentDrawdownPct;
   
   g_risk.dailyRiskUsedPct = (g_risk.dayStartEquity > 0) ?
      MathMax(0.0, (g_risk.dayStartEquity - equity) / g_risk.dayStartEquity * 100.0) : 0;
   
   g_risk.weeklyRiskUsedPct = (g_risk.weekStartEquity > 0) ?
      MathMax(0.0, (g_risk.weekStartEquity - equity) / g_risk.weekStartEquity * 100.0) : 0;
   
   g_risk.dailyLimitHit = (g_risk.dailyRiskUsedPct >= InpMaxDailyLossPct);
   g_risk.weeklyLimitHit = (g_risk.weeklyRiskUsedPct >= InpMaxWeeklyLossPct);
   
   if(g_risk.currentDrawdownPct >= InpMaxDrawdownPct)
   {
      g_risk.emergencyShutdown = true;
      Alert("EMERGENCY SHUTDOWN: Max drawdown reached!");
   }
   
   // Calculate adaptive risk
   g_risk.currentRiskPercent = CalculateAdaptiveRisk();
}

void RolloverDailyWeekly()
{
   datetime today = DayStart(TimeCurrent());
   datetime thisWeek = WeekStart(TimeCurrent());
   
   if(today != g_dayStart)
   {
      g_dayStart = today;
      g_tradesToday = 0;
      g_risk.dayStartEquity = AccountInfoDouble(ACCOUNT_EQUITY);
      g_risk.dailyLimitHit = false;
      g_sessionProfit = 0;
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

bool RiskAllowsNewTrade(string &reason)
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
   
   if(g_tradesToday >= InpMaxDailyTrades)
   {
      reason = "MAX DAILY TRADES";
      return false;
   }
   
   int positions = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(g_pos.SelectByIndex(i) && 
         g_pos.Magic() == InpMagicNumber && 
         g_pos.Symbol() == _Symbol)
         positions++;
   }
   
   if(positions >= InpMaxConcurrentTrades)
   {
      reason = "MAX CONCURRENT TRADES";
      return false;
   }
   
   if(g_inCooldown)
   {
      reason = "COOLDOWN ACTIVE";
      return false;
   }
   
   return true;
}


//=====================================================================
//  TRADE EXECUTION
//=====================================================================
string EncodePositionComment(ENUM_STRATEGY strat, double risk)
{
   return "QGS3|" + IntegerToString((int)strat) + "|" + DoubleToString(risk, 2);
}

bool DecodePositionComment(string comment, ENUM_STRATEGY &strat, double &risk)
{
   string parts[];
   int count = StringSplit(comment, '|', parts);
   
   if(count < 3)
      return false;
   
   strat = (ENUM_STRATEGY)StringToInteger(parts[1]);
   risk = StringToDouble(parts[2]);
   
   return (risk > 0);
}

bool ExecuteTrade(StrategySignal &signal)
{
   if(!signal.valid)
      return false;
   
   double riskPercent = g_risk.currentRiskPercent;
   double entryPrice = (signal.direction > 0) ? 
      SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   
   double slDistance = MathAbs(entryPrice - signal.suggestedSL);
   double lotSize = CalculateLotSize(slDistance, riskPercent);
   
   if(lotSize <= 0)
      return false;
   
   // Validate SL/TP distances
   double minStops = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL) * 
                     SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   
   if(signal.direction > 0)
   {
      if(entryPrice - signal.suggestedSL < minStops)
         signal.suggestedSL = NPrice(entryPrice - minStops - 0.10);
      if(signal.suggestedTP - entryPrice < minStops)
         signal.suggestedTP = NPrice(entryPrice + minStops + 0.10);
   }
   else
   {
      if(signal.suggestedSL - entryPrice < minStops)
         signal.suggestedSL = NPrice(entryPrice + minStops + 0.10);
      if(entryPrice - signal.suggestedTP < minStops)
         signal.suggestedTP = NPrice(entryPrice - minStops - 0.10);
   }
   
   g_trade.SetExpertMagicNumber(InpMagicNumber);
   g_trade.SetDeviationInPoints(InpSlippage);
   g_trade.SetTypeFilling(GetFillMode());
   
   double riskAmount = AccountInfoDouble(ACCOUNT_EQUITY) * riskPercent / 100.0;
   string comment = EncodePositionComment(signal.source, riskAmount);
   
   bool result = false;
   
   if(signal.direction > 0)
   {
      result = g_trade.Buy(lotSize, _Symbol, entryPrice, 
                          signal.suggestedSL, signal.suggestedTP, comment);
   }
   else
   {
      result = g_trade.Sell(lotSize, _Symbol, entryPrice, 
                           signal.suggestedSL, signal.suggestedTP, comment);
   }
   
   if(result)
   {
      g_tradesToday++;
      g_lastAction = signal.reason;
      g_statusText = "TRADE EXECUTED";
      g_statusColor = C_GREEN;
      
      // Draw entry marker
      if(InpDrawSignalMarkers)
         DrawEntryMarker(signal);
      
      Print("✓ TRADE EXECUTED: ", signal.reason, " | Lot: ", lotSize, 
            " | SL: ", signal.suggestedSL, " | TP: ", signal.suggestedTP);
   }
   
   return result;
}

void DrawEntryMarker(StrategySignal &signal)
{
   datetime time = TimeCurrent();
   double price = (signal.direction > 0) ? 
      SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   
   string name = OV + "ENTRY_" + IntegerToString((long)time);
   
   if(ObjectCreate(0, name, OBJ_ARROW, 0, time, price))
   {
      ObjectSetInteger(0, name, OBJPROP_ARROWCODE, (signal.direction > 0) ? 233 : 234);
      ObjectSetInteger(0, name, OBJPROP_COLOR, (signal.direction > 0) ? C_GREEN : C_RED);
      ObjectSetInteger(0, name, OBJPROP_WIDTH, 4);
      ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, name, OBJPROP_BACK, false);
   }
   
   // Add label
   string labelName = name + "_LBL";
   if(ObjectCreate(0, labelName, OBJ_TEXT, 0, time, price))
   {
      string stratName = "";
      switch(signal.source)
      {
         case STRAT_BREAKOUT_SCALP: stratName = "BREAKOUT"; break;
         case STRAT_REVERSAL_SCALP: stratName = "REVERSAL"; break;
         case STRAT_MOMENTUM_SCALP: stratName = "MOMENTUM"; break;
         case STRAT_RANGE_SCALP: stratName = "RANGE"; break;
         case STRAT_FVG_FILL: stratName = "FVG"; break;
         case STRAT_ORDERBLOCK_REACTION: stratName = "OB"; break;
         default: stratName = "SCALP";
      }
      
      ObjectSetString(0, labelName, OBJPROP_TEXT, " " + stratName + " ");
      ObjectSetInteger(0, labelName, OBJPROP_COLOR, (signal.direction > 0) ? C_GREEN : C_RED);
      ObjectSetInteger(0, labelName, OBJPROP_FONTSIZE, 10);
      ObjectSetString(0, labelName, OBJPROP_FONT, "Arial Bold");
      ObjectSetInteger(0, labelName, OBJPROP_ANCHOR, ANCHOR_CENTER);
      ObjectSetInteger(0, labelName, OBJPROP_SELECTABLE, false);
   }
}

void DrawExitMarker(double price, double pnl)
{
   datetime time = TimeCurrent();
   string name = OV + "EXIT_" + IntegerToString((long)time);
   
   if(ObjectCreate(0, name, OBJ_ARROW, 0, time, price))
   {
      ObjectSetInteger(0, name, OBJPROP_ARROWCODE, 251);
      ObjectSetInteger(0, name, OBJPROP_COLOR, (pnl >= 0) ? C_CYAN_BRIGHT : C_PURPLE_BRIGHT);
      ObjectSetInteger(0, name, OBJPROP_WIDTH, 3);
      ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   }
   
   // Add PnL label
   string labelName = name + "_PNL";
   if(ObjectCreate(0, labelName, OBJ_TEXT, 0, time, price))
   {
      ObjectSetString(0, labelName, OBJPROP_TEXT, " " + 
                     (pnl >= 0 ? "+" : "") + DoubleToString(pnl, 2) + " ");
      ObjectSetInteger(0, labelName, OBJPROP_COLOR, (pnl >= 0) ? C_CYAN_BRIGHT : C_PURPLE_BRIGHT);
      ObjectSetInteger(0, labelName, OBJPROP_FONTSIZE, 10);
      ObjectSetString(0, labelName, OBJPROP_FONT, "Arial Bold");
      ObjectSetInteger(0, labelName, OBJPROP_ANCHOR, ANCHOR_CENTER);
      ObjectSetInteger(0, labelName, OBJPROP_SELECTABLE, false);
   }
}

//=====================================================================
//  TRADE TRANSACTION HANDLER
//=====================================================================
void OnTradeTransactionHandler(const MqlTradeTransaction &trans,
                               const MqlTradeRequest &request,
                               const MqlTradeResult &result)
{
   if(trans.type != TRADE_TRANSACTION_DEAL_ADD)
      return;
   
   ulong dealTicket = trans.deal;
   
   if(!HistoryDealSelect(dealTicket))
      return;
   
   if(HistoryDealGetInteger(dealTicket, DEAL_MAGIC) != InpMagicNumber)
      return;
   
   if(HistoryDealGetString(dealTicket, DEAL_SYMBOL) != _Symbol)
      return;
   
   if(HistoryDealGetInteger(dealTicket, DEAL_ENTRY) != DEAL_ENTRY_OUT)
      return;
   
   // Trade closed
   double pnl = HistoryDealGetDouble(dealTicket, DEAL_PROFIT) +
                HistoryDealGetDouble(dealTicket, DEAL_SWAP) +
                HistoryDealGetDouble(dealTicket, DEAL_COMMISSION);
   
   string comment = HistoryDealGetString(dealTicket, DEAL_COMMENT);
   ENUM_STRATEGY strat;
   double risk;
   
   if(DecodePositionComment(comment, strat, risk))
   {
      UpdateStrategyPerformance(strat, pnl, risk);
      
      // Update indicator performance
      // (simplified - you'd track which indicators contributed)
      for(int i = 0; i < 14; i++)
      {
         if(g_indicators[i].active)
            UpdateIndicatorPerformance((ENUM_INDICATOR)i, (pnl > 0), pnl);
      }
   }
   
   // Update session stats
   g_sessionProfit += pnl;
   if(pnl >= 0)
      g_sessionWins++;
   else
      g_sessionLosses++;
   
   // Start cooldown
   g_lastCloseTime = TimeCurrent();
   g_inCooldown = true;
   
   // Draw exit marker
   double exitPrice = HistoryDealGetDouble(dealTicket, DEAL_PRICE);
   DrawExitMarker(exitPrice, pnl);
   
   Print("✓ TRADE CLOSED: PnL = ", pnl, " | Strategy: ", EnumToString(strat));
}

//=====================================================================
//  VISUAL OVERLAYS - FVG
//=====================================================================
void DrawFVGs()
{
   if(!InpDrawFVG)
      return;
   
   // Delete old FVG objects
   for(int i = ObjectsTotal(0, 0, OBJ_RECTANGLE) - 1; i >= 0; i--)
   {
      string name = ObjectName(0, i, 0, OBJ_RECTANGLE);
      if(StringFind(name, OV + "FVG_") >= 0)
         ObjectDelete(0, name);
   }
   
   datetime now = TimeCurrent();
   
   for(int i = 0; i < g_fvgCount; i++)
   {
      if(g_fvgs[i].filled)
         continue;
      
      string name = OV + "FVG_" + IntegerToString(i);
      
      if(ObjectCreate(0, name, OBJ_RECTANGLE, 0, g_fvgs[i].time, g_fvgs[i].upper, now, g_fvgs[i].lower))
      {
         color fvgColor = g_fvgs[i].bullish ? C'0,60,20' : C'60,0,20';
         ObjectSetInteger(0, name, OBJPROP_COLOR, fvgColor);
         ObjectSetInteger(0, name, OBJPROP_FILL, true);
         ObjectSetInteger(0, name, OBJPROP_BACK, true);
         ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
         ObjectSetInteger(0, name, OBJPROP_WIDTH, 1);
      }
      
      // Add label
      string labelName = name + "_LBL";
      if(ObjectCreate(0, labelName, OBJ_TEXT, 0, g_fvgs[i].time, g_fvgs[i].upper))
      {
         ObjectSetString(0, labelName, OBJPROP_TEXT, " FVG ");
         ObjectSetInteger(0, labelName, OBJPROP_COLOR, g_fvgs[i].bullish ? C_GREEN : C_RED);
         ObjectSetInteger(0, labelName, OBJPROP_FONTSIZE, 10);
         ObjectSetString(0, labelName, OBJPROP_FONT, "Arial Bold");
         ObjectSetInteger(0, labelName, OBJPROP_ANCHOR, ANCHOR_LEFT_LOWER);
         ObjectSetInteger(0, labelName, OBJPROP_SELECTABLE, false);
      }
   }
}

//=====================================================================
//  VISUAL OVERLAYS - ORDER BLOCKS
//=====================================================================
void DrawOrderBlocks()
{
   if(!InpDrawOrderBlocks)
      return;
   
   // Delete old OB objects
   for(int i = ObjectsTotal(0, 0, OBJ_RECTANGLE) - 1; i >= 0; i--)
   {
      string name = ObjectName(0, i, 0, OBJ_RECTANGLE);
      if(StringFind(name, OV + "OB_") >= 0)
         ObjectDelete(0, name);
   }
   
   datetime now = TimeCurrent();
   
   for(int i = 0; i < g_obCount; i++)
   {
      if(g_orderBlocks[i].broken)
         continue;
      
      string name = OV + "OB_" + IntegerToString(i);
      
      if(ObjectCreate(0, name, OBJ_RECTANGLE, 0, g_orderBlocks[i].time, 
                     g_orderBlocks[i].high, now, g_orderBlocks[i].low))
      {
         color obColor = g_orderBlocks[i].bullish ? C'0,40,10' : C'40,0,10';
         color borderColor = g_orderBlocks[i].bullish ? C_GREEN : C_RED;
         
         ObjectSetInteger(0, name, OBJPROP_COLOR, borderColor);
         ObjectSetInteger(0, name, OBJPROP_BGCOLOR, obColor);
         ObjectSetInteger(0, name, OBJPROP_FILL, true);
         ObjectSetInteger(0, name, OBJPROP_BACK, true);
         ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
         ObjectSetInteger(0, name, OBJPROP_WIDTH, 2);
         ObjectSetInteger(0, name, OBJPROP_STYLE, STYLE_SOLID);
      }
      
      // Add label
      string labelName = name + "_LBL";
      if(ObjectCreate(0, labelName, OBJ_TEXT, 0, g_orderBlocks[i].time, g_orderBlocks[i].high))
      {
         ObjectSetString(0, labelName, OBJPROP_TEXT, g_orderBlocks[i].bullish ? " OB+ " : " OB- ");
         ObjectSetInteger(0, labelName, OBJPROP_COLOR, C_GOLD);
         ObjectSetInteger(0, labelName, OBJPROP_FONTSIZE, 11);
         ObjectSetString(0, labelName, OBJPROP_FONT, "Arial Bold");
         ObjectSetInteger(0, labelName, OBJPROP_ANCHOR, ANCHOR_LEFT_LOWER);
         ObjectSetInteger(0, labelName, OBJPROP_SELECTABLE, false);
      }
   }
}

//=====================================================================
//  VISUAL OVERLAYS - CHoCH & BOS
//=====================================================================
void DrawStructureBreaks()
{
   if(!InpDrawChoCh && !InpDrawBOS)
      return;
   
   for(int i = 0; i < g_patternCount; i++)
   {
      if(!g_patterns[i].active)
         continue;
      
      string name = OV + g_patterns[i].type + "_" + IntegerToString((long)g_patterns[i].time);
      
      // Draw horizontal line
      datetime now = TimeCurrent();
      if(ObjectCreate(0, name, OBJ_TREND, 0, g_patterns[i].time, g_patterns[i].priceLevel, now, g_patterns[i].priceLevel))
      {
         color lineColor;
         if(g_patterns[i].type == "BOS")
            lineColor = g_patterns[i].bullish ? C_GREEN : C_RED;
         else  // CHoCH
            lineColor = C_PURPLE;
         
         ObjectSetInteger(0, name, OBJPROP_COLOR, lineColor);
         ObjectSetInteger(0, name, OBJPROP_WIDTH, 2);
         ObjectSetInteger(0, name, OBJPROP_STYLE, STYLE_DASH);
         ObjectSetInteger(0, name, OBJPROP_RAY_RIGHT, false);
         ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
         ObjectSetInteger(0, name, OBJPROP_BACK, false);
      }
      
      // Add label
      string labelName = name + "_LBL";
      if(ObjectCreate(0, labelName, OBJ_TEXT, 0, now, g_patterns[i].priceLevel))
      {
         string text = " " + g_patterns[i].type + " ";
         ObjectSetString(0, labelName, OBJPROP_TEXT, text);
         
         color labelColor;
         if(g_patterns[i].type == "BOS")
            labelColor = g_patterns[i].bullish ? C_GREEN : C_RED;
         else
            labelColor = C_PURPLE;
         
         ObjectSetInteger(0, labelName, OBJPROP_COLOR, labelColor);
         ObjectSetInteger(0, labelName, OBJPROP_FONTSIZE, 12);
         ObjectSetString(0, labelName, OBJPROP_FONT, "Arial Bold");
         ObjectSetInteger(0, labelName, OBJPROP_ANCHOR, ANCHOR_RIGHT);
         ObjectSetInteger(0, labelName, OBJPROP_SELECTABLE, false);
      }
   }
}

//=====================================================================
//  VISUAL OVERLAYS - LIQUIDITY ZONES
//=====================================================================
void DrawLiquidityZones()
{
   if(!InpDrawLiquidityZones)
      return;
   
   datetime now = TimeCurrent();
   datetime past = now - 3600 * 24;  // 24 hours back
   
   // BSL (Buy Side Liquidity) - equal highs
   if(g_liq.equalHighsDetected)
   {
      string name = OV + "BSL";
      
      // Delete old
      ObjectDelete(0, name);
      ObjectDelete(0, name + "_LBL");
      
      if(ObjectCreate(0, name, OBJ_TREND, 0, past, g_liq.equalHighLevel, now, g_liq.equalHighLevel))
      {
         color lineColor = g_liq.sweepUpDetected ? C_RED : C_ORANGE;
         ObjectSetInteger(0, name, OBJPROP_COLOR, lineColor);
         ObjectSetInteger(0, name, OBJPROP_WIDTH, 3);
         ObjectSetInteger(0, name, OBJPROP_STYLE, STYLE_DASH);
         ObjectSetInteger(0, name, OBJPROP_RAY_RIGHT, false);
         ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
      }
      
      // Label
      string labelName = name + "_LBL";
      if(ObjectCreate(0, labelName, OBJ_TEXT, 0, now, g_liq.equalHighLevel))
      {
         string text = g_liq.sweepUpDetected ? " BSL ✓ SWEPT " : " BSL (" + IntegerToString(g_liq.equalHighCount) + ") ";
         ObjectSetString(0, labelName, OBJPROP_TEXT, text);
         ObjectSetInteger(0, labelName, OBJPROP_COLOR, g_liq.sweepUpDetected ? C_RED : C_ORANGE);
         ObjectSetInteger(0, labelName, OBJPROP_FONTSIZE, 11);
         ObjectSetString(0, labelName, OBJPROP_FONT, "Arial Bold");
         ObjectSetInteger(0, labelName, OBJPROP_ANCHOR, ANCHOR_RIGHT);
         ObjectSetInteger(0, labelName, OBJPROP_SELECTABLE, false);
      }
   }
   
   // SSL (Sell Side Liquidity) - equal lows
   if(g_liq.equalLowsDetected)
   {
      string name = OV + "SSL";
      
      // Delete old
      ObjectDelete(0, name);
      ObjectDelete(0, name + "_LBL");
      
      if(ObjectCreate(0, name, OBJ_TREND, 0, past, g_liq.equalLowLevel, now, g_liq.equalLowLevel))
      {
         color lineColor = g_liq.sweepDownDetected ? C_GREEN : C_ORANGE;
         ObjectSetInteger(0, name, OBJPROP_COLOR, lineColor);
         ObjectSetInteger(0, name, OBJPROP_WIDTH, 3);
         ObjectSetInteger(0, name, OBJPROP_STYLE, STYLE_DASH);
         ObjectSetInteger(0, name, OBJPROP_RAY_RIGHT, false);
         ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
      }
      
      // Label
      string labelName = name + "_LBL";
      if(ObjectCreate(0, labelName, OBJ_TEXT, 0, now, g_liq.equalLowLevel))
      {
         string text = g_liq.sweepDownDetected ? " SSL ✓ SWEPT " : " SSL (" + IntegerToString(g_liq.equalLowCount) + ") ";
         ObjectSetString(0, labelName, OBJPROP_TEXT, text);
         ObjectSetInteger(0, labelName, OBJPROP_COLOR, g_liq.sweepDownDetected ? C_GREEN : C_ORANGE);
         ObjectSetInteger(0, labelName, OBJPROP_FONTSIZE, 11);
         ObjectSetString(0, labelName, OBJPROP_FONT, "Arial Bold");
         ObjectSetInteger(0, labelName, OBJPROP_ANCHOR, ANCHOR_RIGHT);
         ObjectSetInteger(0, labelName, OBJPROP_SELECTABLE, false);
      }
   }
}

//=====================================================================
//  VISUAL OVERLAYS - SESSION BOXES
//=====================================================================
void DrawSessionBoxes()
{
   if(!InpDrawSessionBoxes)
      return;
   
   datetime now = TimeCurrent();
   datetime today = DayStart(now);
   
   ENUM_SESSION sessions[] = {SESSION_ASIAN, SESSION_LONDON_OPEN, SESSION_LONDON_MID, SESSION_OVERLAP, SESSION_NY_PM};
   color sessionColors[] = {C'20,20,40', C'20,30,50', C'20,30,50', C'50,40,0', C'50,30,0'};
   color borderColors[] = {C_PURPLE, C_BLUE, C_BLUE, C_GOLD, C_ORANGE};
   string sessionNames[] = {"ASIAN", "LONDON OPEN", "LONDON MID", "OVERLAP ★", "NY PM"};
   
   for(int s = 0; s < 5; s++)
   {
      // Calculate session times (simplified)
      int startHour = 0, endHour = 0;
      
      switch(sessions[s])
      {
         case SESSION_ASIAN:       startHour = 0;  endHour = 7;  break;
         case SESSION_LONDON_OPEN: startHour = 7;  endHour = 9;  break;
         case SESSION_LONDON_MID:  startHour = 9;  endHour = 13; break;
         case SESSION_OVERLAP:     startHour = 13; endHour = 16; break;
         case SESSION_NY_PM:       startHour = 16; endHour = 20; break;
      }
      
      datetime sessionStart = today + startHour * 3600;
      datetime sessionEnd = today + endHour * 3600;
      
      if(sessionEnd < now - 86400)  // Skip old sessions
         continue;
      
      if(sessionEnd > now)
         sessionEnd = now;
      
      // Get session high/low
      int startBar = iBarShift(_Symbol, PERIOD_M5, sessionStart, false);
      int endBar = iBarShift(_Symbol, PERIOD_M5, sessionEnd, false);
      
      if(startBar < 0 || endBar < 0)
         continue;
      
      double sessionHigh = 0, sessionLow = 999999;
      for(int i = endBar; i <= startBar; i++)
      {
         double high = iHigh(_Symbol, PERIOD_M5, i);
         double low = iLow(_Symbol, PERIOD_M5, i);
         if(high > sessionHigh) sessionHigh = high;
         if(low < sessionLow) sessionLow = low;
      }
      
      if(sessionHigh == 0 || sessionLow == 999999)
         continue;
      
      string name = OV + "SESSION_" + sessionNames[s] + "_" + IntegerToString((long)sessionStart);
      
      // Delete old
      ObjectDelete(0, name);
      ObjectDelete(0, name + "_LBL");
      
      // Draw box
      if(ObjectCreate(0, name, OBJ_RECTANGLE, 0, sessionStart, sessionHigh * 1.0002, sessionEnd, sessionLow * 0.9998))
      {
         ObjectSetInteger(0, name, OBJPROP_COLOR, borderColors[s]);
         ObjectSetInteger(0, name, OBJPROP_BGCOLOR, sessionColors[s]);
         ObjectSetInteger(0, name, OBJPROP_FILL, true);
         ObjectSetInteger(0, name, OBJPROP_BACK, true);
         ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
         ObjectSetInteger(0, name, OBJPROP_WIDTH, 2);
      }
      
      // Label
      string labelName = name + "_LBL";
      if(ObjectCreate(0, labelName, OBJ_TEXT, 0, sessionStart, sessionHigh * 1.0002))
      {
         ObjectSetString(0, labelName, OBJPROP_TEXT, " " + sessionNames[s] + " ");
         ObjectSetInteger(0, labelName, OBJPROP_COLOR, borderColors[s]);
         ObjectSetInteger(0, labelName, OBJPROP_FONTSIZE, 11);
         ObjectSetString(0, labelName, OBJPROP_FONT, "Arial Bold");
         ObjectSetInteger(0, labelName, OBJPROP_ANCHOR, ANCHOR_LEFT_LOWER);
         ObjectSetInteger(0, labelName, OBJPROP_SELECTABLE, false);
      }
   }
}

//=====================================================================
//  UPDATE ALL VISUAL OVERLAYS
//=====================================================================
void UpdateVisualOverlays()
{
   if(!InpShowChartOverlays)
      return;
   
   DrawFVGs();
   DrawOrderBlocks();
   DrawStructureBreaks();
   DrawLiquidityZones();
   DrawSessionBoxes();
}

//=====================================================================
//  DASHBOARD RENDERING
//=====================================================================
void DelObj(string nm) { ObjectDelete(0, D + nm); }

void DRect(string nm, int x, int y, int w, int h, color bg, color brd = clrNONE, int bw = 1)
{
   string n = D + nm;
   if(ObjectFind(0, n) < 0) ObjectCreate(0, n, OBJ_RECTANGLE_LABEL, 0, 0, 0);
   ObjectSetInteger(0, n, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, n, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, n, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, n, OBJPROP_XSIZE, w);
   ObjectSetInteger(0, n, OBJPROP_YSIZE, h);
   ObjectSetInteger(0, n, OBJPROP_BGCOLOR, bg);
   ObjectSetInteger(0, n, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, n, OBJPROP_HIDDEN, false);
   
   if(brd != clrNONE)
   {
      ObjectSetInteger(0, n, OBJPROP_BORDER_TYPE, BORDER_FLAT);
      ObjectSetInteger(0, n, OBJPROP_COLOR, brd);
      ObjectSetInteger(0, n, OBJPROP_WIDTH, bw);
   }
}

void DLabel(string nm, int x, int y, string txt, color clr, int fsz, string fnt = "Arial Bold")
{
   string n = D + nm;
   if(ObjectFind(0, n) < 0) ObjectCreate(0, n, OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, n, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, n, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, n, OBJPROP_YDISTANCE, y);
   ObjectSetString(0, n, OBJPROP_TEXT, txt);
   ObjectSetInteger(0, n, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, n, OBJPROP_FONTSIZE, fsz);
   ObjectSetString(0, n, OBJPROP_FONT, fnt);
   ObjectSetInteger(0, n, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, n, OBJPROP_HIDDEN, false);
}

void DUpdate(string nm, string txt, color clr = C_WHITE)
{
   string n = D + nm;
   if(ObjectFind(0, n) >= 0)
   {
      ObjectSetString(0, n, OBJPROP_TEXT, txt);
      ObjectSetInteger(0, n, OBJPROP_COLOR, clr);
   }
}

void InitDashboard()
{
   if(!InpShowDash)
      return;
   
   int X = S(InpDashX);
   int Y = S(InpDashY);
   int W = S(InpDashWidth);
   int lp = S(10);
   int y = Y;
   
   // Outer frame
   DRect("frame", X, Y, W, S(600), C_PANEL_BG, C_BORDER, 2);
   y += S(2);
   
   // Header
   DRect("hdr", X+S(2), y, W-S(4), S(28), C_PANEL_HDR, C_GOLD, 1);
   DLabel("hdr_title", X+lp, y+S(6), "QUANTUM GOLD SCALPER AI v3.0  |  ML-POWERED", C_GOLD, FS(10));
   y += S(30);
   
   // Status bar
   DRect("status_bar", X+S(2), y, W-S(4), S(20), C_PANEL_BG, C_BORDER, 1);
   DLabel("lb_status", X+lp, y+S(4), "STATUS:", C_GRAY, FS(7));
   DLabel("vl_status", X+S(70), y+S(4), "INITIALIZING", C_ORANGE, FS(8));
   DLabel("lb_time", X+W-S(120), y+S(4), "TIME:", C_GRAY, FS(7));
   DLabel("vl_time", X+W-S(75), y+S(4), "--:--:--", C_WHITE, FS(7));
   y += S(22);
   
   // Regime section
   DRect("regime_hdr", X+S(2), y, W-S(4), S(18), C_PANEL_HDR, C_BORDER, 1);
   DLabel("hdr_regime", X+lp, y+S(3), "■ MARKET REGIME", C_BORDER, FS(8));
   y += S(20);
   
   DRect("regime_body", X+S(2), y, W-S(4), S(50), C_PANEL_BG, C_BORDER, 1);
   DLabel("lb_regime", X+lp, y+S(4), "REGIME:", C_GRAY, FS(7));
   DLabel("vl_regime", X+S(80), y+S(4), "---", C_GREEN, FS(9));
   DLabel("lb_conf", X+lp, y+S(20), "CONFIDENCE:", C_GRAY, FS(7));
   DLabel("vl_conf", X+S(100), y+S(20), "0%", C_WHITE, FS(8));
   DLabel("lb_mtf", X+lp, y+S(36), "MTF ALIGN:", C_GRAY, FS(7));
   DLabel("vl_mtf", X+S(90), y+S(36), "0%", C_WHITE, FS(8));
   y += S(54);
   
   // Session section
   DRect("session_hdr", X+S(2), y, W-S(4), S(18), C_PANEL_HDR, C_BORDER, 1);
   DLabel("hdr_session", X+lp, y+S(3), "■ SESSION & VOLATILITY", C_BORDER, FS(8));
   y += S(20);
   
   DRect("session_body", X+S(2), y, W-S(4), S(50), C_PANEL_BG, C_BORDER, 1);
   DLabel("lb_session", X+lp, y+S(4), "SESSION:", C_GRAY, FS(7));
   DLabel("vl_session", X+S(80), y+S(4), "---", C_GOLD, FS(9));
   DLabel("lb_vol", X+lp, y+S(20), "VOLATILITY:", C_GRAY, FS(7));
   DLabel("vl_vol", X+S(90), y+S(20), "---", C_WHITE, FS(8));
   DLabel("lb_spread", X+lp, y+S(36), "SPREAD:", C_GRAY, FS(7));
   DLabel("vl_spread", X+S(70), y+S(36), "0", C_GREEN, FS(8));
   y += S(54);
   
   // Liquidity section
   DRect("liq_hdr", X+S(2), y, W-S(4), S(18), C_PANEL_HDR, C_BORDER, 1);
   DLabel("hdr_liq", X+lp, y+S(3), "■ LIQUIDITY INTELLIGENCE", C_BORDER, FS(8));
   y += S(20);
   
   DRect("liq_body", X+S(2), y, W-S(4), S(50), C_PANEL_BG, C_BORDER, 1);
   DLabel("lb_liq_state", X+lp, y+S(4), "STATE:", C_GRAY, FS(7));
   DLabel("vl_liq_state", X+S(60), y+S(4), "---", C_PURPLE, FS(8));
   DLabel("lb_bsl", X+lp, y+S(20), "BSL:", C_GRAY, FS(7));
   DLabel("vl_bsl", X+S(50), y+S(20), "---", C_ORANGE, FS(7));
   DLabel("lb_ssl", X+S(200), y+S(20), "SSL:", C_GRAY, FS(7));
   DLabel("vl_ssl", X+S(240), y+S(20), "---", C_ORANGE, FS(7));
   DLabel("vl_liq_detail", X+lp, y+S(36), "No sweeps detected", C_GRAY, FS(7));
   y += S(54);
   
   // Strategy section
   DRect("strat_hdr", X+S(2), y, W-S(4), S(18), C_PANEL_HDR, C_BORDER, 1);
   DLabel("hdr_strat", X+lp, y+S(3), "■ ACTIVE STRATEGY", C_BORDER, FS(8));
   y += S(20);
   
   DRect("strat_body", X+S(2), y, W-S(4), S(60), C_PANEL_BG, C_BORDER, 1);
   DRect("strat_name_bg", X+S(4), y+S(4), W-S(8), S(20), C_PANEL_HDR, C_GREEN, 2);
   DLabel("vl_strat_name", X+lp, y+S(8), "AUTO-SELECTING...", C_GREEN, FS(10));
   DLabel("lb_signal", X+lp, y+S(30), "SIGNAL:", C_GRAY, FS(7));
   DLabel("vl_signal", X+S(70), y+S(30), "---", C_WHITE, FS(8));
   DLabel("lb_quality", X+lp, y+S(46), "QUALITY:", C_GRAY, FS(7));
   DLabel("vl_quality", X+S(80), y+S(46), "0/100", C_WHITE, FS(8));
   y += S(64);
   
   // Active indicators
   DRect("ind_hdr", X+S(2), y, W-S(4), S(18), C_PANEL_HDR, C_BORDER, 1);
   DLabel("hdr_ind", X+lp, y+S(3), "■ ACTIVE INDICATORS (AUTO)", C_BORDER, FS(8));
   y += S(20);
   
   DRect("ind_body", X+S(2), y, W-S(4), S(40), C_PANEL_BG, C_BORDER, 1);
   for(int i = 0; i < 6; i++)
   {
      int ix = lp + (i % 3) * S(130);
      int iy = y + S(4) + (i / 3) * S(18);
      DRect("ind_" + IntegerToString(i), X+ix, iy, S(40), S(14), C_PANEL_HDR, C_GRAY, 1);
      DLabel("ind_lbl_" + IntegerToString(i), X+ix+S(4), iy+S(3), "---", C_GRAY, FS(7));
   }
   y += S(44);
   
   // Risk & Account
   DRect("risk_hdr", X+S(2), y, W-S(4), S(18), C_PANEL_HDR, C_BORDER, 1);
   DLabel("hdr_risk", X+lp, y+S(3), "■ RISK & ACCOUNT", C_BORDER, FS(8));
   y += S(20);
   
   DRect("risk_body", X+S(2), y, W-S(4), S(60), C_PANEL_BG, C_BORDER, 1);
   DLabel("lb_equity", X+lp, y+S(4), "EQUITY:", C_GRAY, FS(7));
   DLabel("vl_equity", X+S(70), y+S(4), "0.00", C_GREEN, FS(9));
   DLabel("lb_risk_pct", X+lp, y+S(20), "RISK/TRADE:", C_GRAY, FS(7));
   DLabel("vl_risk_pct", X+S(100), y+S(20), "0.0%", C_WHITE, FS(8));
   DLabel("lb_dd", X+lp, y+S(36), "DRAWDOWN:", C_GRAY, FS(7));
   DLabel("vl_dd", X+S(100), y+S(36), "0.0%", C_WHITE, FS(8));
   DLabel("lb_trades", X+S(250), y+S(4), "TRADES:", C_GRAY, FS(7));
   DLabel("vl_trades", X+S(320), y+S(4), "0/15", C_WHITE, FS(8));
   DLabel("lb_wr", X+S(250), y+S(20), "WIN RATE:", C_GRAY, FS(7));
   DLabel("vl_wr", X+S(330), y+S(20), "0%", C_WHITE, FS(8));
   DLabel("lb_pnl", X+S(250), y+S(36), "DAY P&L:", C_GRAY, FS(7));
   DLabel("vl_pnl", X+S(330), y+S(36), "+0.00", C_GREEN, FS(8));
   y += S(64);
   
   // Decision
   DRect("dec_hdr", X+S(2), y, W-S(4), S(18), C_PANEL_HDR, C_BORDER, 1);
   DLabel("hdr_dec", X+lp, y+S(3), "■ MASTER DECISION", C_BORDER, FS(8));
   y += S(20);
   
   DRect("dec_body", X+S(2), y, W-S(4), S(40), C_PANEL_BG, C_BORDER, 2);
   DLabel("vl_decision", X+W/2-S(30), y+S(12), "ANALYZING", C_GOLD, FS(14));
   y += S(44);
   
   // Footer
   DRect("footer", X+S(2), y, W-S(4), S(14), C_PANEL_HDR, C_BORDER, 1);
   DLabel("ft_left", X+lp, y+S(3), "MN: " + IntegerToString((long)InpMagicNumber), C_GRAY, FS(6));
   DLabel("ft_right", X+W-S(100), y+S(3), "QGS AI v3.0", C_GRAY, FS(6));
   
   ChartRedraw(0);
}

void UpdateDashboard()
{
   if(!InpShowDash)
      return;
   
   // Status
   DUpdate("vl_status", g_statusText, g_statusColor);
   DUpdate("vl_time", TimeToString(TimeCurrent(), TIME_SECONDS), C_WHITE);
   
   // Regime
   string regimeName = EnumToString(g_regime.regime);
   StringReplace(regimeName, "REGIME_", "");
   DUpdate("vl_regime", regimeName, RegimeToColor(g_regime.regime));
   DUpdate("vl_conf", DoubleToString(g_regime.confidence, 0) + "%", ScoreColor(g_regime.confidence));
   DUpdate("vl_mtf", DoubleToString(g_mtf.alignment, 0) + "%", ScoreColor(g_mtf.alignment));
   
   // Session
   DUpdate("vl_session", SessionToString(g_session.current), C_GOLD);
   DUpdate("vl_vol", VolatilityStateToString(g_vol.state), VolStateColor(g_vol.state));
   
   double spread = (double)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   bool spreadOk = (spread <= InpMaxSpreadPoints);
   DUpdate("vl_spread", DoubleToString(spread / 10.0, 1), spreadOk ? C_GREEN : C_RED);
   
   // Liquidity
   string liqState = "BALANCED";
   if(g_liq.sweepUpDetected) liqState = "SWEEP UP";
   else if(g_liq.sweepDownDetected) liqState = "SWEEP DOWN";
   else if(g_liq.buySideLiquidity > g_liq.sellSideLiquidity * 1.5) liqState = "BSL HEAVY";
   else if(g_liq.sellSideLiquidity > g_liq.buySideLiquidity * 1.5) liqState = "SSL HEAVY";
   DUpdate("vl_liq_state", liqState, C_PURPLE);
   
   DUpdate("vl_bsl", g_liq.equalHighsDetected ? DoubleToString(g_liq.equalHighLevel, 2) : "---", 
           g_liq.sweepUpDetected ? C_RED : C_ORANGE);
   DUpdate("vl_ssl", g_liq.equalLowsDetected ? DoubleToString(g_liq.equalLowLevel, 2) : "---",
           g_liq.sweepDownDetected ? C_GREEN : C_ORANGE);
   
   string liqDetail = "";
   if(g_liq.sweepUpDetected) liqDetail = "✓ Buy-side sweep confirmed";
   else if(g_liq.sweepDownDetected) liqDetail = "✓ Sell-side sweep confirmed";
   else liqDetail = "Monitoring for sweeps...";
   DUpdate("vl_liq_detail", liqDetail, C_GRAY);
   
   // Strategy
   ENUM_STRATEGY bestStrat = AutoSelectBestStrategy();
   string stratName = EnumToString(bestStrat);
   StringReplace(stratName, "STRAT_", "");
   DUpdate("vl_strat_name", stratName, C_GREEN);
   
   DUpdate("vl_signal", g_lastAction, C_WHITE);
   DUpdate("vl_quality", DoubleToString(g_execQuality.compositeScore, 0) + "/100", 
           ScoreColor(g_execQuality.compositeScore));
   
   // Active indicators
   string indNames[] = {"EMA", "RSI", "ATR", "ADX", "BB", "VOL"};
   for(int i = 0; i < 6 && i < 14; i++)
   {
      if(g_indicators[i].active)
      {
         DUpdate("ind_lbl_" + IntegerToString(i), indNames[i], C_GREEN);
         ObjectSetInteger(0, D + "ind_" + IntegerToString(i), OBJPROP_BGCOLOR, C'0,40,10');
      }
      else
      {
         DUpdate("ind_lbl_" + IntegerToString(i), indNames[i], C_GRAY);
         ObjectSetInteger(0, D + "ind_" + IntegerToString(i), OBJPROP_BGCOLOR, C_PANEL_HDR);
      }
   }
   
   // Risk & Account
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   DUpdate("vl_equity", DoubleToString(equity, 2), C_GREEN);
   DUpdate("vl_risk_pct", DoubleToString(g_risk.currentRiskPercent, 2) + "%", C_WHITE);
   DUpdate("vl_dd", DoubleToString(g_risk.currentDrawdownPct, 1) + "%",
           (g_risk.currentDrawdownPct < 5) ? C_GREEN : (g_risk.currentDrawdownPct < 8 ? C_ORANGE : C_RED));
   
   DUpdate("vl_trades", IntegerToString(g_tradesToday) + "/" + IntegerToString(InpMaxDailyTrades), C_WHITE);
   
   int totalTrades = g_sessionWins + g_sessionLosses;
   double winRate = (totalTrades > 0) ? 100.0 * g_sessionWins / totalTrades : 0;
   DUpdate("vl_wr", DoubleToString(winRate, 0) + "%", ScoreColor(winRate));
   
   DUpdate("vl_pnl", (g_sessionProfit >= 0 ? "+" : "") + DoubleToString(g_sessionProfit, 2),
           (g_sessionProfit >= 0) ? C_GREEN : C_RED);
   
   // Decision
   string decisionText = "HOLD";
   color decisionColor = C_GOLD;
   
   if(g_lastDecision.tradeApproved)
   {
      decisionText = (g_lastDecision.direction > 0) ? "◆ BUY" : "◆ SELL";
      decisionColor = (g_lastDecision.direction > 0) ? C_GREEN : C_RED;
   }
   else if(g_risk.emergencyShutdown)
   {
      decisionText = "SHUTDOWN";
      decisionColor = C_RED;
   }
   
   DUpdate("vl_decision", decisionText, decisionColor);
   
   ChartRedraw(0);
}

color RegimeToColor(ENUM_REGIME r)
{
   if(r == REGIME_STRONG_BULL_TREND || r == REGIME_WEAK_BULL_TREND)
      return C_GREEN;
   else if(r == REGIME_STRONG_BEAR_TREND || r == REGIME_WEAK_BEAR_TREND)
      return C_RED;
   else if(r == REGIME_LIQUIDITY_SWEEP)
      return C_PURPLE;
   else if(r == REGIME_UNSAFE)
      return C_RED;
   else
      return C_GOLD;
}

color VolStateColor(ENUM_VOL_STATE v)
{
   switch(v)
   {
      case VOL_ULTRA_LOW: return C_BLUE;
      case VOL_LOW: return C_GREEN;
      case VOL_NORMAL: return C_WHITE;
      case VOL_HIGH: return C_ORANGE;
      case VOL_EXTREME: return C_RED;
      case VOL_SHOCK: return C_RED;
      default: return C_WHITE;
   }
}

color ScoreColor(double score)
{
   if(score >= 75) return C_GREEN;
   if(score >= 50) return C_GOLD;
   if(score >= 30) return C_ORANGE;
   return C_RED;
}

string VolatilityStateToString(ENUM_VOL_STATE v)
{
   switch(v)
   {
      case VOL_ULTRA_LOW: return "ULTRA LOW";
      case VOL_LOW: return "LOW";
      case VOL_NORMAL: return "NORMAL";
      case VOL_HIGH: return "HIGH";
      case VOL_EXTREME: return "EXTREME";
      case VOL_SHOCK: return "SHOCK";
      default: return "UNKNOWN";
   }
}

void DeleteDashboard()
{
   ObjectsDeleteAll(0, D);
   ChartRedraw(0);
}

void DeleteVisuals()
{
   ObjectsDeleteAll(0, OV);
   ChartRedraw(0);
}

//=====================================================================
//  CHART THEME
//=====================================================================
void ApplyGoldTheme()
{
   long ch = ChartID();
   ChartSetInteger(ch, CHART_MODE, CHART_CANDLES);
   ChartSetInteger(ch, CHART_COLOR_BACKGROUND, C_BG_DARK);
   ChartSetInteger(ch, CHART_COLOR_FOREGROUND, C_WHITE);
   ChartSetInteger(ch, CHART_COLOR_GRID, C_BG_DARK);
   ChartSetInteger(ch, CHART_COLOR_CANDLE_BULL, C_GREEN);
   ChartSetInteger(ch, CHART_COLOR_CANDLE_BEAR, C_RED);
   ChartSetInteger(ch, CHART_COLOR_CHART_UP, C_GREEN);
   ChartSetInteger(ch, CHART_COLOR_CHART_DOWN, C_RED);
   ChartSetInteger(ch, CHART_COLOR_VOLUME, C_GOLD);
   ChartSetInteger(ch, CHART_SHOW_GRID, false);
   ChartSetInteger(ch, CHART_SHOW_VOLUMES, true);
   ChartRedraw(ch);
}

//=====================================================================
//  EA LIFECYCLE - OnInit
//=====================================================================
int OnInit()
{
   g_scale = InpDPIScale / 100.0;
   if(g_scale < 0.5) g_scale = 0.5;
   if(g_scale > 3.0) g_scale = 3.0;
   
   ApplyGoldTheme();
   
   // Initialize indicator handles
   g_h4_ema_fast = iMA(_Symbol, PERIOD_H4, InpEMAFast, 0, MODE_EMA, PRICE_CLOSE);
   g_h4_ema_slow = iMA(_Symbol, PERIOD_H4, InpEMASlow, 0, MODE_EMA, PRICE_CLOSE);
   g_h4_ema_200 = iMA(_Symbol, PERIOD_H4, InpEMA200, 0, MODE_EMA, PRICE_CLOSE);
   g_h4_atr = iATR(_Symbol, PERIOD_H4, InpATRPeriod);
   
   g_h1_ema_fast = iMA(_Symbol, PERIOD_H1, InpEMAFast, 0, MODE_EMA, PRICE_CLOSE);
   g_h1_ema_slow = iMA(_Symbol, PERIOD_H1, InpEMASlow, 0, MODE_EMA, PRICE_CLOSE);
   g_h1_ema_200 = iMA(_Symbol, PERIOD_H1, InpEMA200, 0, MODE_EMA, PRICE_CLOSE);
   g_h1_atr = iATR(_Symbol, PERIOD_H1, InpATRPeriod);
   g_h1_rsi = iRSI(_Symbol, PERIOD_H1, InpRSIPeriod, PRICE_CLOSE);
   g_h1_adx = iADX(_Symbol, PERIOD_H1, InpADXPeriod);
   
   g_m30_ema_fast = iMA(_Symbol, PERIOD_M30, InpEMAFast, 0, MODE_EMA, PRICE_CLOSE);
   g_m30_ema_slow = iMA(_Symbol, PERIOD_M30, InpEMASlow, 0, MODE_EMA, PRICE_CLOSE);
   g_m30_atr = iATR(_Symbol, PERIOD_M30, InpATRPeriod);
   g_m30_rsi = iRSI(_Symbol, PERIOD_M30, InpRSIPeriod, PRICE_CLOSE);
   
   g_m15_ema_fast = iMA(_Symbol, PERIOD_M15, InpEMAFast, 0, MODE_EMA, PRICE_CLOSE);
   g_m15_ema_slow = iMA(_Symbol, PERIOD_M15, InpEMASlow, 0, MODE_EMA, PRICE_CLOSE);
   g_m15_atr = iATR(_Symbol, PERIOD_M15, InpATRPeriod);
   g_m15_rsi = iRSI(_Symbol, PERIOD_M15, InpRSIPeriod, PRICE_CLOSE);
   g_m15_bb = iBands(_Symbol, PERIOD_M15, InpBBPeriod, 0, InpBBDeviation, PRICE_CLOSE);
   
   g_m5_ema_fast = iMA(_Symbol, PERIOD_M5, InpEMAFast, 0, MODE_EMA, PRICE_CLOSE);
   g_m5_ema_slow = iMA(_Symbol, PERIOD_M5, InpEMASlow, 0, MODE_EMA, PRICE_CLOSE);
   g_m5_ema_200 = iMA(_Symbol, PERIOD_M5, InpEMA200, 0, MODE_EMA, PRICE_CLOSE);
   g_m5_atr = iATR(_Symbol, PERIOD_M5, InpATRPeriod);
   g_m5_rsi = iRSI(_Symbol, PERIOD_M5, InpRSIPeriod, PRICE_CLOSE);
   g_m5_stoch = iStochastic(_Symbol, PERIOD_M5, InpStochPeriod, 3, 3, MODE_SMA, STO_LOWHIGH);
   g_m5_cci = iCCI(_Symbol, PERIOD_M5, InpCCIPeriod, PRICE_TYPICAL);
   g_m5_adx = iADX(_Symbol, PERIOD_M5, InpADXPeriod);
   
   g_m1_ema_fast = iMA(_Symbol, PERIOD_M1, InpEMAFast, 0, MODE_EMA, PRICE_CLOSE);
   g_m1_ema_slow = iMA(_Symbol, PERIOD_M1, InpEMASlow, 0, MODE_EMA, PRICE_CLOSE);
   g_m1_atr = iATR(_Symbol, PERIOD_M1, InpATRPeriod);
   g_m1_rsi = iRSI(_Symbol, PERIOD_M1, InpRSIPeriod, PRICE_CLOSE);
   
   // Validate handles
   if(g_h4_ema_fast == INVALID_HANDLE || g_h1_ema_fast == INVALID_HANDLE || 
      g_m5_ema_fast == INVALID_HANDLE || g_m5_atr == INVALID_HANDLE)
   {
      Print("ERROR: Failed to create indicator handles");
      return INIT_FAILED;
   }
   
   // Initialize systems
   g_dayStart = DayStart(TimeCurrent());
   g_weekStart = WeekStart(TimeCurrent());
   
   InitRiskState();
   InitializeIndicators();
   InitializeStrategies();
   
   g_trade.SetExpertMagicNumber(InpMagicNumber);
   g_trade.SetDeviationInPoints(InpSlippage);
   g_trade.SetTypeFilling(GetFillMode());
   
   if(InpShowDash)
      InitDashboard();
   
   EventSetTimer(1);
   
   g_statusText = "WARMING UP";
   g_statusColor = C_ORANGE;
   
   Print("========================================");
   Print("  QUANTUM GOLD SCALPER AI v3.0");
   Print("  Advanced ML-Powered Gold Scalping");
   Print("  Symbol: ", _Symbol);
   Print("  Magic: ", InpMagicNumber);
   Print("  Base Risk: ", InpBaseRiskPercent, "%");
   Print("========================================");
   
   return INIT_SUCCEEDED;
}

//=====================================================================
//  EA LIFECYCLE - OnDeinit
//=====================================================================
void OnDeinit(const int reason)
{
   EventKillTimer();
   
   DeleteDashboard();
   DeleteVisuals();
   
   // Release indicators
   IndicatorRelease(g_h4_ema_fast);
   IndicatorRelease(g_h4_ema_slow);
   IndicatorRelease(g_h4_ema_200);
   IndicatorRelease(g_h4_atr);
   IndicatorRelease(g_h1_ema_fast);
   IndicatorRelease(g_h1_ema_slow);
   IndicatorRelease(g_h1_ema_200);
   IndicatorRelease(g_h1_atr);
   IndicatorRelease(g_h1_rsi);
   IndicatorRelease(g_h1_adx);
   IndicatorRelease(g_m30_ema_fast);
   IndicatorRelease(g_m30_ema_slow);
   IndicatorRelease(g_m30_atr);
   IndicatorRelease(g_m30_rsi);
   IndicatorRelease(g_m15_ema_fast);
   IndicatorRelease(g_m15_ema_slow);
   IndicatorRelease(g_m15_atr);
   IndicatorRelease(g_m15_rsi);
   IndicatorRelease(g_m15_bb);
   IndicatorRelease(g_m5_ema_fast);
   IndicatorRelease(g_m5_ema_slow);
   IndicatorRelease(g_m5_ema_200);
   IndicatorRelease(g_m5_atr);
   IndicatorRelease(g_m5_rsi);
   IndicatorRelease(g_m5_stoch);
   IndicatorRelease(g_m5_cci);
   IndicatorRelease(g_m5_adx);
   IndicatorRelease(g_m1_ema_fast);
   IndicatorRelease(g_m1_ema_slow);
   IndicatorRelease(g_m1_atr);
   IndicatorRelease(g_m1_rsi);
   
   Print("========================================");
   Print("  QUANTUM GOLD SCALPER AI v3.0");
   Print("  SESSION ENDED");
   Print("  Total Trades: ", g_tradesToday);
   Print("  Session P&L: ", g_sessionProfit);
   Print("  Win Rate: ", (g_sessionWins + g_sessionLosses > 0) ? 
         DoubleToString(100.0 * g_sessionWins / (g_sessionWins + g_sessionLosses), 1) : "0", "%");
   Print("========================================");
}

//=====================================================================
//  EA LIFECYCLE - OnTimer
//=====================================================================
void OnTimer()
{
   if(g_inCooldown)
   {
      if(TimeCurrent() - g_lastCloseTime >= InpCooldownSeconds)
         g_inCooldown = false;
   }
   
   if(InpShowDash)
      UpdateDashboard();
}

//=====================================================================
//  EA LIFECYCLE - OnTick
//=====================================================================
void OnTick()
{
   // Cooldown check
   if(g_inCooldown)
   {
      if(TimeCurrent() - g_lastCloseTime >= InpCooldownSeconds)
         g_inCooldown = false;
   }
   
   // Daily/weekly rollover
   RolloverDailyWeekly();
   
   // Buffer check
   if(Bars(_Symbol, PERIOD_M5) < 200)
   {
      g_statusText = "BUFFERING";
      g_statusColor = C_ORANGE;
      return;
   }
   
   // Update risk state
   UpdateRiskState();
   
   // Check if in position
   bool inPosition = false;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(g_pos.SelectByIndex(i) && 
         g_pos.Magic() == InpMagicNumber && 
         g_pos.Symbol() == _Symbol)
      {
         inPosition = true;
         break;
      }
   }
   
   if(inPosition)
   {
      g_statusText = "IN TRADE";
      g_statusColor = C_GREEN;
      return;
   }
   
   // New bar check
   if(!IsNewBar())
      return;
   
   // Update all market analysis
   UpdateSessionData();
   UpdateVolatilityAnalysis();
   UpdateLiquidityAnalysis();
   UpdateMTFBias();
   UpdateRegimeClassification();
   
   // Detect patterns
   DetectOrderBlocks();
   DetectFairValueGaps();
   DetectStructureBreaks();
   
   // Auto-select indicators
   AutoSelectIndicators();
   
   // Update execution quality
   UpdateExecutionQuality();
   
   // Update visuals
   UpdateVisualOverlays();
   
   // Check if can trade
   string rejectReason = "";
   if(!RiskAllowsNewTrade(rejectReason))
   {
      g_statusText = "BLOCKED";
      g_statusColor = C_RED;
      g_lastAction = rejectReason;
      return;
   }
   
   if(!g_execQuality.executionApproved)
   {
      g_statusText = "ANALYZING";
      g_statusColor = C_GOLD;
      g_lastAction = g_execQuality.rejectReason;
      return;
   }
   
   // Generate master signal
   StrategySignal signal = GenerateMasterSignal();
   
   if(!signal.valid)
   {
      g_statusText = "ANALYZING";
      g_statusColor = C_GOLD;
      g_lastDecision.tradeApproved = false;
      return;
   }
   
   // Check signal confidence
   if(signal.confidence < InpMinSignalConfidence)
   {
      g_statusText = "ANALYZING";
      g_statusColor = C_GOLD;
      g_lastAction = "Signal confidence low: " + DoubleToString(signal.confidence, 0) + "%";
      g_lastDecision.tradeApproved = false;
      return;
   }
   
   // Build decision
   g_lastDecision.tradeApproved = true;
   g_lastDecision.direction = signal.direction;
   g_lastDecision.slPrice = signal.suggestedSL;
   g_lastDecision.tpPrice = signal.suggestedTP;
   g_lastDecision.strategySource = signal.source;
   g_lastDecision.confidence = signal.confidence;
   g_lastDecision.narrative = signal.reason;
   
   // Execute trade
   g_statusText = "EXECUTING";
   g_statusColor = C_BLUE;
   
   bool executed = ExecuteTrade(signal);
   
   if(executed)
   {
      g_statusText = "TRADE OPENED";
      g_statusColor = C_GREEN;
   }
   else
   {
      g_statusText = "EXECUTION FAILED";
      g_statusColor = C_RED;
   }
}

//=====================================================================
//  EA LIFECYCLE - OnTradeTransaction
//=====================================================================
void OnTradeTransaction(const MqlTradeTransaction &trans,
                       const MqlTradeRequest &request,
                       const MqlTradeResult &result)
{
   OnTradeTransactionHandler(trans, request, result);
}

//=====================================================================
//  END OF QUANTUM GOLD SCALPER AI v3.0
//=====================================================================