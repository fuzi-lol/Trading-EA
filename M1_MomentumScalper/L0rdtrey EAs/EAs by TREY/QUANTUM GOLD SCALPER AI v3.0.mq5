//+------------------------------------------------------------------+
//|                                QUANTUM GOLD SCALPER AI v3.0      |
//|              Advanced ML-Powered Gold Scalping Terminal          |
//|              20+ Years Professional Gold Trading Intelligence    |
//+------------------------------------------------------------------+
#property copyright   "Quantum Gold Scalper AI v3.0"
#property version     "3.00"
#property description "Advanced ML Gold Scalping with Adaptive Intelligence"
#property strict

#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>
#include <Trade\AccountInfo.mqh>
#include <Trade\OrderInfo.mqh>
#include <Arrays\ArrayDouble.mqh>
#include <Arrays\ArrayInt.mqh>

//=====================================================================
//  CRITICAL DEFINES
//=====================================================================
#define EA_PREFIX    "QGS3_"
#define OV_PREFIX    "QGS3_OV_"
#define M_PI         3.14159265358979323846
#define GOLD_POINT   0.01

//=====================================================================
//  ENUMERATIONS
//=====================================================================
enum ENUM_GOLD_SESSION
{
   GOLD_ASIAN,           // Asian Session (Low volatility)
   GOLD_LONDON_OPEN,     // London Open (High volatility)
   GOLD_LONDON_MID,      // London Mid (Trending)
   GOLD_NY_OPEN,         // NY Open (Extreme volatility)
   GOLD_NY_LONDON_OVERLAP, // Overlap (Best for scalping)
   GOLD_NY_MID,          // NY Mid Session
   GOLD_DEAD_ZONE        // Low liquidity zone
};

enum ENUM_MARKET_REGIME
{
   REGIME_STRONG_TREND,      // Strong directional move
   REGIME_WEAK_TREND,        // Weak trend
   REGIME_RANGING,           // Consolidation
   REGIME_BREAKOUT,          // Breakout in progress
   REGIME_REVERSAL,          // Reversal pattern
   REGIME_VOLATILE_CHOP,     // High vol, no direction
   REGIME_NEWS_SPIKE,        // News event
   REGIME_LIQUIDITY_GRAB,    // Stop hunt
   REGIME_ACCUMULATION,      // Smart money accumulation
   REGIME_DISTRIBUTION,      // Smart money distribution
   REGIME_UNSAFE             // Do not trade
};

enum ENUM_VOL_STATE
{
   VOL_ULTRA_LOW,    // < 20th percentile
   VOL_LOW,          // 20-40th percentile
   VOL_NORMAL,       // 40-60th percentile
   VOL_HIGH,         // 60-80th percentile
   VOL_EXTREME,      // 80-95th percentile
   VOL_SHOCK         // > 95th percentile
};

enum ENUM_LIQUIDITY_STATE
{
   LIQ_BALANCED,
   LIQ_BUY_SIDE_HEAVY,
   LIQ_SELL_SIDE_HEAVY,
   LIQ_SWEEP_UP_DETECTED,
   LIQ_SWEEP_DOWN_DETECTED,
   LIQ_DUAL_SWEEP
};

enum ENUM_INDICATOR_TYPE
{
   IND_EMA_FAST,
   IND_EMA_SLOW,
   IND_EMA_200,
   IND_RSI,
   IND_STOCH,
   IND_MACD,
   IND_BOLLINGER,
   IND_ATR,
   IND_ADX,
   IND_CCI,
   IND_MOMENTUM,
   IND_VOLUME_PROFILE,
   IND_ORDER_FLOW,
   IND_SMART_MONEY
};

enum ENUM_STRATEGY_TYPE
{
   STRAT_NONE,
   STRAT_BREAKOUT_SCALP,       // Breakout scalping
   STRAT_REVERSAL_SCALP,       // Reversal at extremes
   STRAT_MOMENTUM_SCALP,       // Momentum continuation
   STRAT_RANGE_SCALP,          // Range bound scalping
   STRAT_NEWS_SCALP,           // News event scalping
   STRAT_SESSION_OPEN,         // Session open breakout
   STRAT_LIQUIDITY_HUNT,       // Liquidity grab reversal
   STRAT_ORDERBLOCK_SCALP,     // Order block reaction
   STRAT_FVG_SCALP,            // Fair value gap fill
   STRAT_IMBALANCE_SCALP       // Imbalance scalping
};

enum ENUM_SIGNAL_QUALITY
{
   QUALITY_INVALID,
   QUALITY_POOR,
   QUALITY_FAIR,
   QUALITY_GOOD,
   QUALITY_EXCELLENT,
   QUALITY_PERFECT
};

enum ENUM_TRADE_DIRECTION
{
   DIR_NONE,
   DIR_LONG,
   DIR_SHORT
};

//=====================================================================
//  ADVANCED DATA STRUCTURES
//=====================================================================

// Indicator performance tracking
struct IndicatorMetrics
{
   ENUM_INDICATOR_TYPE type;
   bool                active;
   bool                enabled;
   double              signalStrength;
   double              reliability;       // 0-100%
   double              winRate;
   int                 totalSignals;
   int                 correctSignals;
   double              avgProfit;
   double              avgLoss;
   double              sharpeRatio;
   datetime            lastSignalTime;
   double              correlationScore;  // With other indicators
   double              adaptiveWeight;    // ML-adjusted weight
};

// Strategy performance and ML learning
struct StrategyMetrics
{
   ENUM_STRATEGY_TYPE  type;
   bool                enabled;
   double              winRate;
   int                 totalTrades;
   int                 wins;
   int                 losses;
   double              grossProfit;
   double              grossLoss;
   double              profitFactor;
   double              expectancy;
   double              sharpeRatio;
   double              maxConsecWins;
   double              maxConsecLosses;
   int                 consecWins;
   int                 consecLosses;
   double              avgWin;
   double              avgLoss;
   double              bestTrade;
   double              worstTrade;
   double              recoveryFactor;
   double              adaptiveConfidence; // ML confidence
   datetime            lastTradeTime;
   double              recentPerformance[20]; // Last 20 trades for ML
   int                 recentCount;
};

// Market regime classification
struct RegimeData
{
   ENUM_MARKET_REGIME  regime;
   double              confidence;
   double              stability;
   int                 barsInRegime;
   datetime            regimeStartTime;
   ENUM_MARKET_REGIME  previousRegime;
   double              trendStrength;
   double              volatilityLevel;
   double              liquidityScore;
};

// Volatility intelligence
struct VolatilityData
{
   ENUM_VOL_STATE  state;
   double          atrCurrent;
   double          atrAverage;
   double          atrRatio;
   double          percentile;
   double          rangeExpansion;
   double          historicalVol;
   double          impliedVol;        // Proxy via price action
   bool            expanding;
   bool            contracting;
   bool            spike;
};

// Liquidity analysis
struct LiquidityData
{
   ENUM_LIQUIDITY_STATE state;
   double               buySideLiquidity;
   double               sellSideLiquidity;
   double               imbalanceRatio;
   bool                 equalHighsDetected;
   bool                 equalLowsDetected;
   double               equalHighLevel;
   double               equalLowLevel;
   int                  equalHighCount;
   int                  equalLowCount;
   bool                 sweepUpConfirmed;
   bool                 sweepDownConfirmed;
   double               liquidityScore;
};

// Session-specific data
struct SessionData
{
   ENUM_GOLD_SESSION    current;
   double               volatilityFactor;
   double               volumeFactor;
   double               spreadFactor;
   double               optimalRiskPercent;
   ENUM_STRATEGY_TYPE   preferredStrategy;
   double               sessionHigh;
   double               sessionLow;
   double               sessionOpen;
   double               avgSessionRange;
};

// Multi-timeframe bias
struct MTFData
{
   int     h4Bias;
   int     h1Bias;
   int     m30Bias;
   int     m15Bias;
   int     m5Bias;
   int     m1Bias;
   double  alignment;
   double  strength;
};

// Price action patterns
struct PricePattern
{
   string   type;           // "FVG", "OB", "CHoCH", "BOS", "MSS"
   double   priceLevel;
   double   upperLevel;
   double   lowerLevel;
   datetime time;
   bool     bullish;
   double   strength;
   bool     tested;
   bool     broken;
};

// Order block detection
struct OrderBlock
{
   double   high;
   double   low;
   double   open;
   double   close;
   datetime time;
   bool     bullish;
   double   strength;
   bool     valid;
   bool     tested;
   int      touches;
};

// Fair Value Gap
struct FairValueGap
{
   double   upperLevel;
   double   lowerLevel;
   datetime time;
   bool     bullish;
   bool     filled;
   double   fillPercent;
   double   strength;
};

// ML Pattern recognition
struct MLPattern
{
   double   features[20];     // Feature vector
   int      label;            // 1=bullish, -1=bearish, 0=neutral
   double   confidence;
   double   outcome;          // Actual result for learning
   datetime time;
};

// Risk management state
struct RiskState
{
   double  accountEquity;
   double  accountBalance;
   double  dayStartEquity;
   double  weekStartEquity;
   double  peakEquity;
   double  currentDrawdown;
   double  maxDrawdown;
   double  dailyPnL;
   double  weeklyPnL;
   double  dailyRiskUsed;
   double  weeklyRiskUsed;
   int     dailyTrades;
   int     weeklyTrades;
   bool    dailyLimitHit;
   bool    weeklyLimitHit;
   bool    emergencyStop;
   double  currentRiskPercent;    // Adaptive
   double  currentLotSize;        // Adaptive
   double  volatilityAdjustment;
   double  accountSizeMultiplier;
};

// Trade signal
struct TradeSignal
{
   ENUM_TRADE_DIRECTION direction;
   ENUM_STRATEGY_TYPE   strategy;
   ENUM_SIGNAL_QUALITY  quality;
   double               confidence;
   double               entryPrice;
   double               stopLoss;
   double               takeProfit;
   double               riskReward;
   double               lotSize;
   string               reason;
   bool                 valid;
   datetime             signalTime;
   double               expectedProfit;
   int                  indicatorsAgreeing;
};

// Execution quality
struct ExecutionQuality
{
   double  spreadScore;
   double  slippageRisk;
   double  liquidityScore;
   double  volatilityScore;
   double  timingScore;
   double  compositeScore;
   bool    approved;
   string  rejectReason;
};

//=====================================================================
//  INPUT PARAMETERS
//=====================================================================
input group "========== EA IDENTITY =========="
input ulong  InpMagicNumber          = 888800;
input string InpEAName               = "QUANTUM GOLD SCALPER AI v3.0";

input group "========== RISK MANAGEMENT =========="
input double InpBaseRiskPercent      = 0.5;     // Base risk per trade (%)
input double InpMaxRiskPercent       = 2.0;     // Maximum risk per trade (%)
input double InpMinRiskPercent       = 0.2;     // Minimum risk per trade (%)
input double InpMaxDailyLoss         = 3.0;     // Max daily loss (%)
input double InpMaxWeeklyLoss        = 7.0;     // Max weekly loss (%)
input double InpMaxDrawdown          = 12.0;    // Max drawdown (%)
input int    InpMaxDailyTrades       = 15;      // Max trades per day
input int    InpMaxConcurrentTrades  = 1;       // Max concurrent positions
input bool   InpUseAdaptiveRisk      = true;    // Enable adaptive risk
input bool   InpUseVolatilityScaling = true;    // Scale risk by volatility
input bool   InpUseAccountScaling    = true;    // Scale risk by account size

input group "========== GOLD-SPECIFIC SETTINGS =========="
input double InpGoldMaxSpreadPoints  = 30;      // Max spread (points)
input double InpGoldMinMove          = 0.50;    // Min price move ($)
input double InpGoldSessionMultiplier= 1.5;     // Session volatility multiplier
input bool   InpTradeAsianSession    = false;   // Trade Asian session
input bool   InpTradeLondonSession   = true;    // Trade London session
input bool   InpTradeNYSession       = true;    // Trade NY session
input bool   InpTradeOverlapSession  = true;    // Trade overlap (best)

input group "========== INDICATOR SETTINGS =========="
input int    InpEMAFast              = 8;       // Fast EMA period
input int    InpEMASlow              = 21;      // Slow EMA period
input int    InpEMA200               = 200;     // Long-term EMA
input int    InpRSIPeriod            = 14;      // RSI period
input int    InpATRPeriod            = 14;      // ATR period
input int    InpATRLookback          = 100;     // ATR history lookback
input int    InpBollingerPeriod      = 20;      // Bollinger period
input double InpBollingerDev         = 2.0;     // Bollinger deviation
input int    InpADXPeriod            = 14;      // ADX period
input int    InpCCIPeriod            = 14;      // CCI period
input int    InpStochPeriod          = 14;      // Stochastic period
input int    InpMACDFast             = 12;      // MACD fast
input int    InpMACDSlow             = 26;      // MACD slow
input int    InpMACDSignal           = 9;       // MACD signal

input group "========== MACHINE LEARNING =========="
input bool   InpEnableML             = true;    // Enable ML adaptation
input int    InpMLLookback           = 100;     // ML training lookback
input double InpMLLearningRate       = 0.1;     // Learning rate
input int    InpMLMinSamples         = 20;      // Min samples for ML
input bool   InpMLAutoOptimize       = true;    // Auto-optimize parameters

input group "========== STRATEGY SELECTION =========="
input bool   InpAutoSelectStrategy   = true;    // Auto-select best strategy
input bool   InpEnableBreakout       = true;    // Enable breakout scalping
input bool   InpEnableReversal       = true;    // Enable reversal scalping
input bool   InpEnableMomentum       = true;    // Enable momentum scalping
input bool   InpEnableRange          = true;    // Enable range scalping
input bool   InpEnableLiquidity      = true;    // Enable liquidity hunting
input bool   InpEnableOrderBlock     = true;    // Enable order block scalping
input bool   InpEnableFVG            = true;    // Enable FVG scalping
input bool   InpEnableImbalance      = true;    // Enable imbalance scalping

input group "========== FILTERS =========="
input double InpMinTrendStrength     = 30.0;    // Min trend strength
input double InpMinSignalConfidence  = 65.0;    // Min signal confidence
input double InpMinExecutionScore    = 70.0;    // Min execution quality
input bool   InpUseSpreadFilter      = true;    // Use spread filter
input bool   InpUseVolatilityFilter  = true;    // Use volatility filter
input bool   InpUseTimeFilter        = true;    // Use time filter
input bool   InpUseTrendFilter       = true;    // Use trend filter

input group "========== VISUAL INTELLIGENCE =========="
input bool   InpShowDashboard        = true;    // Show main dashboard
input bool   InpShowMLPanel          = true;    // Show ML analysis panel
input bool   InpShowChart Overlays   = true;    // Show chart overlays
input bool   InpDrawSessionBoxes     = true;    // Draw session boxes
input bool   InpDrawOrderBlocks      = true;    // Draw order blocks
input bool   InpDrawFVG              = true;    // Draw fair value gaps
input bool   InpDrawChoCh            = true;    // Draw CHoCH
input bool   InpDrawBOS              = true;    // Draw BOS/MSS
input bool   InpDrawLiquidity        = true;    // Draw liquidity levels
input bool   InpDrawSupport Resistance=true;    // Draw S/R levels
input int    InpDashX                = 10;      // Dashboard X position
input int    InpDashY                = 10;      // Dashboard Y position
input int    InpDPIScale             = 100;     // DPI scaling (%)

input group "========== ADVANCED SETTINGS =========="
input int    InpSlippage             = 30;      // Max slippage (points)
input int    InpCooldownSeconds      = 30;      // Cooldown after trade close
input int    InpMagicOffset          = 0;       // Magic number offset
input bool   InpEnableLogging        = true;    // Enable detailed logging
input int    InpServerGMTOffset      = 2;       // Broker GMT offset

//=====================================================================
//  GLOBAL VARIABLES
//=====================================================================

// Core trading objects
CTrade         g_trade;
CPositionInfo  g_position;
CAccountInfo   g_account;
COrderInfo     g_order;

// Indicator handles - Multi-timeframe
int g_h4_ema_fast, g_h4_ema_slow, g_h4_ema_200, g_h4_atr, g_h4_adx;
int g_h1_ema_fast, g_h1_ema_slow, g_h1_ema_200, g_h1_atr, g_h1_rsi, g_h1_adx;
int g_m30_ema_fast, g_m30_ema_slow, g_m30_atr, g_m30_rsi;
int g_m15_ema_fast, g_m15_ema_slow, g_m15_atr, g_m15_rsi, g_m15_macd, g_m15_bb;
int g_m5_ema_fast, g_m5_ema_slow, g_m5_ema_200, g_m5_atr, g_m5_rsi, g_m5_stoch, g_m5_cci;
int g_m1_ema_fast, g_m1_ema_slow, g_m1_atr, g_m1_rsi;

// State structures
IndicatorMetrics  g_indicators[14];
StrategyMetrics   g_strategies[10];
RegimeData        g_regime;
VolatilityData    g_volatility;
LiquidityData     g_liquidity;
SessionData       g_session;
MTFData           g_mtf;
RiskState         g_risk;
ExecutionQuality  g_execQuality;
TradeSignal       g_currentSignal;

// Price patterns storage
PricePattern      g_patterns[50];
int               g_patternCount = 0;
OrderBlock        g_orderBlocks[30];
int               g_obCount = 0;
FairValueGap      g_fvgs[30];
int               g_fvgCount = 0;

// ML data
MLPattern         g_mlPatterns[200];
int               g_mlPatternCount = 0;
double            g_mlWeights[20];
bool              g_mlTrained = false;

// Runtime variables
datetime g_lastBarTime = 0;
datetime g_lastTradeTime = 0;
datetime g_dayStart = 0;
datetime g_weekStart = 0;
int      g_dailyTrades = 0;
int      g_weeklyTrades = 0;
bool     g_inCooldown = false;
datetime g_cooldownEnd = 0;
double   g_scale = 1.0;

// Status
string g_statusText = "INITIALIZING";
color  g_statusColor = clrOrange;
string g_lastAction = "Starting up...";

//=====================================================================
//  COLOR PALETTE - Maximum Contrast for Gold Trading
//=====================================================================
#define C_BG_DARK       C'5,5,10'
#define C_PANEL_BG      C'10,15,25'
#define C_PANEL_HDR     C'15,25,45'
#define C_BORDER_CYAN   C'0,255,255'
#define C_BORDER_GOLD   C'255,215,0'
#define C_TEXT_WHITE    C'255,255,255'
#define C_TEXT_GRAY     C'150,160,180'
#define C_GOLD_BRIGHT   C'255,215,0'
#define C_GREEN_BRIGHT  C'0,255,100'
#define C_RED_BRIGHT    C'255,50,50'
#define C_BLUE_BRIGHT   C'50,150,255'
#define C_PURPLE_BRIGHT C'180,80,255'
#define C_ORANGE_BRIGHT C'255,150,0'
#define C_CYAN_BRIGHT   C'0,255,255'

//=====================================================================
//  UTILITY FUNCTIONS
//=====================================================================

// DPI-aware scaling
int S(int pixels) { return (int)MathRound(pixels * g_scale); }
int FS(int fontSize) { return MathMax(6, (int)MathRound(fontSize * g_scale)); }

// Price normalization for Gold
double NormPrice(double price)
{
   return NormalizeDouble(price, 2);
}

// Get fill mode
ENUM_ORDER_TYPE_FILLING GetFillMode()
{
   uint fillMode = (uint)SymbolInfoInteger(_Symbol, SYMBOL_FILLING_MODE);
   if((fillMode & SYMBOL_FILLING_FOK) != 0) return ORDER_FILLING_FOK;
   if((fillMode & SYMBOL_FILLING_IOC) != 0) return ORDER_FILLING_IOC;
   return ORDER_FILLING_RETURN;
}

// New bar detection
bool IsNewBar(ENUM_TIMEFRAMES tf = PERIOD_M5)
{
   static datetime lastBarTime = 0;
   datetime currentBarTime = iTime(_Symbol, tf, 0);
   if(currentBarTime != lastBarTime)
   {
      lastBarTime = currentBarTime;
      return true;
   }
   return false;
}

// Day start
datetime DayStart(datetime time)
{
   MqlDateTime dt;
   TimeToStruct(time, dt);
   dt.hour = 0; dt.min = 0; dt.sec = 0;
   return StructToTime(dt);
}

// Week start
datetime WeekStart(datetime time)
{
   MqlDateTime dt;
   TimeToStruct(time, dt);
   int daysBack = (dt.day_of_week == 0) ? 6 : dt.day_of_week - 1;
   return DayStart(time) - daysBack * 86400;
}

//=====================================================================
//  SESSION CLASSIFICATION - Gold-Specific
//=====================================================================

ENUM_GOLD_SESSION ClassifyGoldSession(datetime time)
{
   MqlDateTime dt;
   TimeToStruct(time, dt);
   
   // Adjust for broker GMT offset
   int hour = (dt.hour - InpServerGMTOffset + 24) % 24;
   
   // Gold session times (GMT)
   // Asian: 00:00-07:00
   // London Open: 07:00-09:00 (High volatility)
   // London Mid: 09:00-13:00
   // NY Open: 13:00-15:00 (Extreme volatility)
   // London-NY Overlap: 13:00-16:00 (Best for scalping)
   // NY Mid: 15:00-20:00
   // Dead Zone: 20:00-24:00
   
   if(hour >= 0 && hour < 7)
      return GOLD_ASIAN;
   else if(hour >= 7 && hour < 9)
      return GOLD_LONDON_OPEN;
   else if(hour >= 9 && hour < 13)
      return GOLD_LONDON_MID;
   else if(hour >= 13 && hour < 15)
      return GOLD_NY_OPEN;
   else if(hour >= 13 && hour < 16)
      return GOLD_NY_LONDON_OVERLAP;
   else if(hour >= 15 && hour < 20)
      return GOLD_NY_MID;
   else
      return GOLD_DEAD_ZONE;
}

string SessionToString(ENUM_GOLD_SESSION session)
{
   switch(session)
   {
      case GOLD_ASIAN:            return "ASIAN";
      case GOLD_LONDON_OPEN:      return "LONDON OPEN";
      case GOLD_LONDON_MID:       return "LONDON MID";
      case GOLD_NY_OPEN:          return "NY OPEN";
      case GOLD_NY_LONDON_OVERLAP:return "LONDON-NY OVERLAP";
      case GOLD_NY_MID:           return "NY MID";
      default:                    return "DEAD ZONE";
   }
}

// Update session data
void UpdateSessionData()
{
   g_session.current = ClassifyGoldSession(TimeCurrent());
   
   // Calculate session-specific factors
   switch(g_session.current)
   {
      case GOLD_ASIAN:
         g_session.volatilityFactor = 0.6;
         g_session.volumeFactor = 0.4;
         g_session.spreadFactor = 1.2;
         g_session.optimalRiskPercent = InpBaseRiskPercent * 0.7;
         g_session.preferredStrategy = STRAT_RANGE_SCALP;
         break;
         
      case GOLD_LONDON_OPEN:
         g_session.volatilityFactor = 1.8;
         g_session.volumeFactor = 1.6;
         g_session.spreadFactor = 0.9;
         g_session.optimalRiskPercent = InpBaseRiskPercent * 1.2;
         g_session.preferredStrategy = STRAT_BREAKOUT_SCALP;
         break;
         
      case GOLD_LONDON_MID:
         g_session.volatilityFactor = 1.3;
         g_session.volumeFactor = 1.2;
         g_session.spreadFactor = 0.8;
         g_session.optimalRiskPercent = InpBaseRiskPercent;
         g_session.preferredStrategy = STRAT_MOMENTUM_SCALP;
         break;
         
      case GOLD_NY_OPEN:
         g_session.volatilityFactor = 2.2;
         g_session.volumeFactor = 2.0;
         g_session.spreadFactor = 1.1;
         g_session.optimalRiskPercent = InpBaseRiskPercent * 0.8;
         g_session.preferredStrategy = STRAT_BREAKOUT_SCALP;
         break;
         
      case GOLD_NY_LONDON_OVERLAP:
         g_session.volatilityFactor = 2.0;
         g_session.volumeFactor = 1.9;
         g_session.spreadFactor = 0.7;
         g_session.optimalRiskPercent = InpBaseRiskPercent * 1.3;
         g_session.preferredStrategy = STRAT_LIQUIDITY_HUNT;
         break;
         
      case GOLD_NY_MID:
         g_session.volatilityFactor = 1.4;
         g_session.volumeFactor = 1.3;
         g_session.spreadFactor = 0.9;
         g_session.optimalRiskPercent = InpBaseRiskPercent;
         g_session.preferredStrategy = STRAT_MOMENTUM_SCALP;
         break;
         
      default: // DEAD_ZONE
         g_session.volatilityFactor = 0.5;
         g_session.volumeFactor = 0.3;
         g_session.spreadFactor = 1.5;
         g_session.optimalRiskPercent = InpBaseRiskPercent * 0.5;
         g_session.preferredStrategy = STRAT_NONE;
         break;
   }
   
   // Calculate session range
   double sessionH = 0, sessionL = 999999, sessionO = 0;
   int sessionBars = 0;
   
   // Look back through current session
   for(int i = 0; i < 100; i++)
   {
      datetime barTime = iTime(_Symbol, PERIOD_M5, i);
      if(ClassifyGoldSession(barTime) != g_session.current)
         break;
         
      double high = iHigh(_Symbol, PERIOD_M5, i);
      double low = iLow(_Symbol, PERIOD_M5, i);
      
      if(high > sessionH) sessionH = high;
      if(low < sessionL) sessionL = low;
      if(sessionO == 0) sessionO = iOpen(_Symbol, PERIOD_M5, i);
      sessionBars++;
   }
   
   g_session.sessionHigh = sessionH;
   g_session.sessionLow = sessionL;
   g_session.sessionOpen = sessionO;
   
   // Calculate average session range
   double totalRange = 0;
   int samples = 0;
   for(int day = 1; day <= 20; day++)
   {
      double dayH = 0, dayL = 999999;
      for(int i = day * 288; i < (day + 1) * 288; i++)
      {
         double high = iHigh(_Symbol, PERIOD_M5, i);
         double low = iLow(_Symbol, PERIOD_M5, i);
         if(high > dayH) dayH = high;
         if(low < dayL) dayL = low;
      }
      if(dayH > 0 && dayL < 999999)
      {
         totalRange += (dayH - dayL);
         samples++;
      }
   }
   g_session.avgSessionRange = (samples > 0) ? totalRange / samples : 50.0;
}

//=====================================================================
//  VOLATILITY ANALYSIS - Advanced Gold-Specific
//=====================================================================

void UpdateVolatilityAnalysis()
{
   double atrBuffer[100];
   if(CopyBuffer(g_m5_atr, 0, 0, InpATRLookback, atrBuffer) < InpATRLookback)
      return;
      
   // Current ATR
   g_volatility.atrCurrent = atrBuffer[0];
   
   // Average ATR
   double sum = 0;
   for(int i = 0; i < InpATRLookback; i++)
      sum += atrBuffer[i];
   g_volatility.atrAverage = sum / InpATRLookback;
   
   // ATR ratio
   g_volatility.atrRatio = (g_volatility.atrAverage > 0) ? 
                          g_volatility.atrCurrent / g_volatility.atrAverage : 1.0;
   
   // Calculate percentile
   int below = 0;
   for(int i = 0; i < InpATRLookback; i++)
      if(atrBuffer[i] <= g_volatility.atrCurrent)
         below++;
   g_volatility.percentile = 100.0 * below / InpATRLookback;
   
   // Classify volatility state
   if(g_volatility.percentile < 20)
      g_volatility.state = VOL_ULTRA_LOW;
   else if(g_volatility.percentile < 40)
      g_volatility.state = VOL_LOW;
   else if(g_volatility.percentile < 60)
      g_volatility.state = VOL_NORMAL;
   else if(g_volatility.percentile < 80)
      g_volatility.state = VOL_HIGH;
   else if(g_volatility.percentile < 95)
      g_volatility.state = VOL_EXTREME;
   else
      g_volatility.state = VOL_SHOCK;
   
   // Range expansion/contraction
   double recentRange = iHigh(_Symbol, PERIOD_M5, 0) - iLow(_Symbol, PERIOD_M5, 0);
   double avgRecentRange = 0;
   for(int i = 1; i <= 10; i++)
      avgRecentRange += iHigh(_Symbol, PERIOD_M5, i) - iLow(_Symbol, PERIOD_M5, i);
   avgRecentRange /= 10.0;
   
   g_volatility.rangeExpansion = (avgRecentRange > 0) ? recentRange / avgRecentRange : 1.0;
   
   // Expansion/contraction flags
   g_volatility.expanding = (g_volatility.atrRatio > 1.2);
   g_volatility.contracting = (g_volatility.atrRatio < 0.8);
   g_volatility.spike = (g_volatility.atrRatio > 2.0);
   
   // Historical volatility (std dev of returns)
   double returns[50];
   for(int i = 0; i < 50; i++)
   {
      double close0 = iClose(_Symbol, PERIOD_M5, i);
      double close1 = iClose(_Symbol, PERIOD_M5, i + 1);
      returns[i] = (close1 > 0) ? (close0 - close1) / close1 : 0;
   }
   
   double meanReturn = 0;
   for(int i = 0; i < 50; i++)
      meanReturn += returns[i];
   meanReturn /= 50.0;
   
   double variance = 0;
   for(int i = 0; i < 50; i++)
      variance += MathPow(returns[i] - meanReturn, 2);
   variance /= 50.0;
   
   g_volatility.historicalVol = MathSqrt(variance) * 100.0;
   
   // Implied volatility proxy (Gold-specific)
   // Based on option-like behavior in price action
   double highLowRange = 0;
   for(int i = 0; i < 20; i++)
      highLowRange += iHigh(_Symbol, PERIOD_M5, i) - iLow(_Symbol, PERIOD_M5, i);
   g_volatility.impliedVol = highLowRange / 20.0;
}

string VolatilityStateToString(ENUM_VOL_STATE state)
{
   switch(state)
   {
      case VOL_ULTRA_LOW: return "ULTRA LOW";
      case VOL_LOW:       return "LOW";
      case VOL_NORMAL:    return "NORMAL";
      case VOL_HIGH:      return "HIGH";
      case VOL_EXTREME:   return "EXTREME";
      case VOL_SHOCK:     return "SHOCK";
      default:            return "UNKNOWN";
   }
}

//=====================================================================
//  LIQUIDITY ANALYSIS - Institutional Level
//=====================================================================

void UpdateLiquidityAnalysis()
{
   double swingHighs[50], swingLows[50];
   datetime swingHighTimes[50], swingLowTimes[50];
   int highCount = 0, lowCount = 0;
   
   // Find swing highs and lows
   for(int i = 3; i < 50; i++)
   {
      double high = iHigh(_Symbol, PERIOD_M5, i);
      double low = iLow(_Symbol, PERIOD_M5, i);
      
      // Swing high detection
      bool isSwingHigh = true;
      for(int j = 1; j <= 3; j++)
      {
         if(iHigh(_Symbol, PERIOD_M5, i - j) >= high || 
            iHigh(_Symbol, PERIOD_M5, i + j) >= high)
         {
            isSwingHigh = false;
            break;
         }
      }
      
      if(isSwingHigh && highCount < 50)
      {
         swingHighs[highCount] = high;
         swingHighTimes[highCount] = iTime(_Symbol, PERIOD_M5, i);
         highCount++;
      }
      
      // Swing low detection
      bool isSwingLow = true;
      for(int j = 1; j <= 3; j++)
      {
         if(iLow(_Symbol, PERIOD_M5, i - j) <= low || 
            iLow(_Symbol, PERIOD_M5, i + j) <= low)
         {
            isSwingLow = false;
            break;
         }
      }
      
      if(isSwingLow && lowCount < 50)
      {
         swingLows[lowCount] = low;
         swingLowTimes[lowCount] = iTime(_Symbol, PERIOD_M5, i);
         lowCount++;
      }
   }
   
   // Detect equal highs/lows (liquidity pools)
   double tolerance = g_volatility.atrCurrent * 0.15;
   
   g_liquidity.equalHighsDetected = false;
   g_liquidity.equalLowsDetected = false;
   g_liquidity.equalHighCount = 0;
   g_liquidity.equalLowCount = 0;
   
   // Equal highs
   for(int i = 0; i < highCount; i++)
   {
      int matches = 1;
      double sumLevels = swingHighs[i];
      
      for(int j = i + 1; j < highCount; j++)
      {
         if(MathAbs(swingHighs[i] - swingHighs[j]) <= tolerance)
         {
            matches++;
            sumLevels += swingHighs[j];
         }
      }
      
      if(matches >= 2 && matches > g_liquidity.equalHighCount)
      {
         g_liquidity.equalHighsDetected = true;
         g_liquidity.equalHighLevel = sumLevels / matches;
         g_liquidity.equalHighCount = matches;
      }
   }
   
   // Equal lows
   for(int i = 0; i < lowCount; i++)
   {
      int matches = 1;
      double sumLevels = swingLows[i];
      
      for(int j = i + 1; j < lowCount; j++)
      {
         if(MathAbs(swingLows[i] - swingLows[j]) <= tolerance)
         {
            matches++;
            sumLevels += swingLows[j];
         }
      }
      
      if(matches >= 2 && matches > g_liquidity.equalLowCount)
      {
         g_liquidity.equalLowsDetected = true;
         g_liquidity.equalLowLevel = sumLevels / matches;
         g_liquidity.equalLowCount = matches;
      }
   }
   
   // Detect liquidity sweeps
   double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   g_liquidity.sweepUpConfirmed = false;
   g_liquidity.sweepDownConfirmed = false;
   
   // Check last 5 bars for sweep
   if(g_liquidity.equalHighsDetected)
   {
      for(int i = 0; i < 5; i++)
      {
         double high = iHigh(_Symbol, PERIOD_M5, i);
         double close = iClose(_Symbol, PERIOD_M5, i);
         
         if(high > g_liquidity.equalHighLevel && close < g_liquidity.equalHighLevel)
         {
            g_liquidity.sweepUpConfirmed = true;
            break;
         }
      }
   }
   
   if(g_liquidity.equalLowsDetected)
   {
      for(int i = 0; i < 5; i++)
      {
         double low = iLow(_Symbol, PERIOD_M5, i);
         double close = iClose(_Symbol, PERIOD_M5, i);
         
         if(low < g_liquidity.equalLowLevel && close > g_liquidity.equalLowLevel)
         {
            g_liquidity.sweepDownConfirmed = true;
            break;
         }
      }
   }
   
   // Calculate buy/sell side liquidity
   g_liquidity.buySideLiquidity = g_liquidity.equalHighCount * 100.0 / MathMax(1, highCount);
   g_liquidity.sellSideLiquidity = g_liquidity.equalLowCount * 100.0 / MathMax(1, lowCount);
   
   // Imbalance ratio
   double totalLiq = g_liquidity.buySideLiquidity + g_liquidity.sellSideLiquidity;
   g_liquidity.imbalanceRatio = (totalLiq > 0) ? 
      MathAbs(g_liquidity.buySideLiquidity - g_liquidity.sellSideLiquidity) / totalLiq : 0;
   
   // Liquidity state classification
   if(g_liquidity.sweepUpConfirmed && g_liquidity.sweepDownConfirmed)
      g_liquidity.state = LIQ_DUAL_SWEEP;
   else if(g_liquidity.sweepUpConfirmed)
      g_liquidity.state = LIQ_SWEEP_UP_DETECTED;
   else if(g_liquidity.sweepDownConfirmed)
      g_liquidity.state = LIQ_SWEEP_DOWN_DETECTED;
   else if(g_liquidity.buySideLiquidity > g_liquidity.sellSideLiquidity * 1.5)
      g_liquidity.state = LIQ_BUY_SIDE_HEAVY;
   else if(g_liquidity.sellSideLiquidity > g_liquidity.buySideLiquidity * 1.5)
      g_liquidity.state = LIQ_SELL_SIDE_HEAVY;
   else
      g_liquidity.state = LIQ_BALANCED;
   
   // Overall liquidity score
   g_liquidity.liquidityScore = MathMin(100.0, 
      (g_liquidity.buySideLiquidity + g_liquidity.sellSideLiquidity) * 0.5 +
      g_liquidity.imbalanceRatio * 30.0);
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
      return 1;  // Bullish
   else if(fast[0] < slow[0] && fast[1] < slow[1])
      return -1; // Bearish
   else
      return 0;  // Neutral
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
   int bullish = 0, bearish = 0, neutral = 0;
   
   for(int i = 0; i < 6; i++)
   {
      if(biases[i] > 0) bullish++;
      else if(biases[i] < 0) bearish++;
      else neutral++;
   }
   
   int aligned = MathMax(bullish, bearish);
   g_mtf.alignment = 100.0 * aligned / 6.0;
   
   // Calculate strength
   double weights[] = {3.0, 2.5, 2.0, 1.5, 1.0, 0.5};  // Higher TF = more weight
   double totalWeight = 0, weightedSum = 0;
   
   for(int i = 0; i < 6; i++)
   {
      totalWeight += weights[i];
      weightedSum += biases[i] * weights[i];
   }
   
   g_mtf.strength = (totalWeight > 0) ? MathAbs(weightedSum / totalWeight) * 100.0 : 0;
}

//=====================================================================
//  CONTINUES IN NEXT PART DUE TO LENGTH...
//=====================================================================