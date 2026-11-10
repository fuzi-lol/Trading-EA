//+------------------------------------------------------------------+
//|                           QUANTUM GOLD SCALPER PRO v3.0          |
//|                  Autonomous AI Gold Scalping System              |
//|                     Advanced Machine Learning Engine             |
//+------------------------------------------------------------------+
#property copyright   "Quantum Gold Scalper Pro v3.0"
#property version     "3.00"
#property description "Autonomous AI Gold Scalping with ML Optimization"
#property strict

#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>
#include <Trade\AccountInfo.mqh>

//=====================================================================
//  ENUMERATIONS
//=====================================================================
enum ENUM_MARKET_CONDITION
{
   COND_TRENDING_STRONG,
   COND_TRENDING_WEAK,
   COND_RANGING_TIGHT,
   COND_RANGING_WIDE,
   COND_BREAKOUT_BULL,
   COND_BREAKOUT_BEAR,
   COND_REVERSAL_ZONE,
   COND_CONSOLIDATION,
   COND_HIGH_VOLATILITY,
   COND_LOW_VOLATILITY,
   COND_NEWS_EVENT,
   COND_ILLIQUID
};

enum ENUM_SESSION_TYPE
{
   SESSION_ASIAN,
   SESSION_LONDON_OPEN,
   SESSION_LONDON_CLOSE,
   SESSION_NY_OPEN,
   SESSION_NY_CLOSE,
   SESSION_OVERLAP,
   SESSION_DEAD
};

enum ENUM_VOLATILITY_STATE
{
   VOL_EXTREMELY_LOW,
   VOL_LOW,
   VOL_NORMAL,
   VOL_HIGH,
   VOL_EXTREMELY_HIGH,
   VOL_SPIKE
};

enum ENUM_LIQUIDITY_STATE
{
   LIQ_VERY_THIN,
   LIQ_THIN,
   LIQ_NORMAL,
   LIQ_DEEP,
   LIQ_VERY_DEEP
};

//=====================================================================
//  INDICATOR LIBRARY ENUMS
//=====================================================================
enum ENUM_INDICATOR_TYPE
{
   IND_EMA_CROSS,
   IND_MACD,
   IND_RSI,
   IND_STOCHASTIC,
   IND_BOLLINGER,
   IND_ATR,
   IND_ADX,
   IND_CCI,
   IND_WILLIAMS,
   IND_MOMENTUM,
   IND_VWAP,
   IND_ICHIMOKU,
   IND_PARABOLIC_SAR,
   IND_FRACTAL,
   IND_ALLIGATOR
};

enum ENUM_STRATEGY_TYPE
{
   STRAT_MOMENTUM_SCALP,
   STRAT_MEAN_REVERSION,
   STRAT_BREAKOUT_SCALP,
   STRAT_RANGE_BOUNCE,
   STRAT_TREND_FOLLOW,
   STRAT_LONDON_BREAKOUT,
   STRAT_NY_REVERSAL,
   STRAT_ASIAN_RANGE,
   STRAT_LIQUIDITY_GRAB,
   STRAT_VOLATILITY_EXPANSION
};

//=====================================================================
//  CONFIGURATION INPUTS
//=====================================================================
input group "===== CORE SETTINGS ====="
input ulong  InpMagicNumber         = 100001;
input string InpTradeComment        = "QGS_PRO_v3";

input group "===== RISK MANAGEMENT ====="
input double InpBaseRiskPercent     = 0.5;      // Base risk per trade (%)
input double InpMaxRiskPercent      = 2.0;      // Maximum risk per trade (%)
input double InpMaxDailyLoss        = 5.0;      // Max daily loss (%)
input double InpMaxDrawdown         = 15.0;     // Max drawdown (%)
input int    InpMaxDailyTrades      = 20;       // Max trades per day
input int    InpMaxConcurrent       = 3;        // Max concurrent positions

input group "===== ML SETTINGS ====="
input bool   InpEnableML            = true;     // Enable machine learning
input int    InpMLLearningPeriod    = 100;      // ML learning period (trades)
input double InpMLMinConfidence     = 65.0;     // ML minimum confidence (%)
input int    InpMLRetrainingPeriod  = 50;       // Retrain every N trades

input group "===== ADAPTIVE SYSTEMS ====="
input bool   InpAutoIndicatorSelect = true;     // Auto-select indicators
input bool   InpAutoStrategySelect  = true;     // Auto-select strategies
input int    InpAdaptivePeriod      = 50;       // Adaptive learning period (bars)
input double InpAdaptiveThreshold   = 70.0;     // Adaptation threshold (%)

input group "===== EXECUTION ====="
input double InpMaxSpreadPips       = 2.5;      // Max spread (pips)
input int    InpSlippagePips        = 3;        // Max slippage (pips)
input int    InpMinTPPips           = 5;        // Min take profit (pips)
input int    InpMinSLPips           = 8;        // Min stop loss (pips)

input group "===== FILTERS ====="
input bool   InpUseNewsFilter       = true;     // Use news filter
input int    InpNewsAvoidMinutes    = 30;       // Avoid news +/- minutes
input bool   InpUseSpreadFilter     = true;     // Use spread filter
input bool   InpUseTimeFilter       = true;     // Use time filter
input string InpTradingStartTime    = "01:00";  // Trading start time
input string InpTradingEndTime      = "22:00";  // Trading end time

input group "===== TRAILING & BE ====="
input bool   InpUseTrailingStop     = true;     // Use trailing stop
input double InpTrailingStart       = 10;       // Trailing start (pips)
input double InpTrailingStep        = 5;        // Trailing step (pips)
input double InpBreakEvenPips       = 8;        // Break even at (pips)
input double InpBreakEvenPlus       = 2;        // BE + (pips)

input group "===== DISPLAY ====="
input bool   InpShowPanel           = true;     // Show dashboard
input int    InpDashX               = 20;       // Dashboard X
input int    InpDashY               = 20;       // Dashboard Y

//=====================================================================
//  INDICATOR STORAGE STRUCTURE
//=====================================================================
struct IndicatorProfile
{
   ENUM_INDICATOR_TYPE type;
   int                 handle;
   bool                active;
   double              performance;        // Win rate
   int                 tradesCount;
   int                 wins;
   int                 losses;
   double              avgProfit;
   double              avgLoss;
   double              sharpe;
   datetime            lastUsed;
   
   // Market condition compatibility
   bool                goodForTrending;
   bool                goodForRanging;
   bool                goodForHighVol;
   bool                goodForLowVol;
   bool                goodForAsian;
   bool                goodForLondon;
   bool                goodForNY;
};

//=====================================================================
//  STRATEGY STORAGE STRUCTURE
//=====================================================================
struct StrategyProfile
{
   ENUM_STRATEGY_TYPE  type;
   bool                active;
   double              performance;
   int                 tradesCount;
   int                 wins;
   int                 losses;
   double              totalProfit;
   double              totalLoss;
   double              sharpe;
   double              expectancy;
   int                 consecutiveLosses;
   int                 maxConsecutiveLosses;
   datetime            lastUsed;
   bool                enabled;
   
   // Optimal conditions
   ENUM_MARKET_CONDITION bestCondition;
   ENUM_SESSION_TYPE     bestSession;
   ENUM_VOLATILITY_STATE bestVolatility;
   ENUM_LIQUIDITY_STATE  bestLiquidity;
   
   // Performance by condition
   double              perfInTrend;
   double              perfInRange;
   double              perfInBreakout;
   double              perfHighVol;
   double              perfLowVol;
};

//=====================================================================
//  MACHINE LEARNING STRUCTURE
//=====================================================================
struct MLFeatures
{
   double atr;
   double spread;
   double hourOfDay;
   double dayOfWeek;
   double volatilityRatio;
   double trendStrength;
   double momentumScore;
   double volumeRatio;
   double pricePosition;    // Position in range
   double timeInSession;
};

struct MLTradeRecord
{
   datetime          timestamp;
   MLFeatures        features;
   ENUM_STRATEGY_TYPE strategy;
   int               indicatorSet[5];   // Up to 5 indicators used
   double            entryPrice;
   double            exitPrice;
   double            profit;
   bool              wasWinner;
   ENUM_MARKET_CONDITION condition;
   ENUM_SESSION_TYPE     session;
};

struct MLModel
{
   MLTradeRecord     history[200];      // Last 200 trades
   int               historyCount;
   double            weights[15];       // Feature weights
   double            bias;
   double            accuracy;
   datetime          lastTraining;
   int               trainingCount;
};

//=====================================================================
//  MARKET STATE STRUCTURE
//=====================================================================
struct MarketState
{
   ENUM_MARKET_CONDITION condition;
   ENUM_SESSION_TYPE     session;
   ENUM_VOLATILITY_STATE volatility;
   ENUM_LIQUIDITY_STATE  liquidity;
   
   double                atr;
   double                atrNormalized;
   double                spreadCurrent;
   double                spreadAvg;
   double                trendStrength;
   double                momentum;
   double                volumeRatio;
   double                priceRangePosition;
   
   bool                  isTrending;
   bool                  isRanging;
   bool                  isBreakout;
   bool                  isReversal;
   
   datetime              lastUpdate;
};

//=====================================================================
//  RISK STATE STRUCTURE
//=====================================================================
struct RiskState
{
   double currentRiskPercent;
   double dailyProfitLoss;
   double currentDrawdown;
   double peakEquity;
   double dayStartEquity;
   int    dailyTradesCount;
   bool   dailyLimitHit;
   bool   drawdownLimitHit;
   bool   emergencyStop;
   datetime lastResetTime;
};

//=====================================================================
//  POSITION MANAGEMENT STRUCTURE
//=====================================================================
struct ManagedPosition
{
   ulong             ticket;
   ENUM_STRATEGY_TYPE strategy;
   datetime          openTime;
   double            openPrice;
   double            stopLoss;
   double            takeProfit;
   double            trailingActivated;
   bool              breakEvenSet;
   double            initialRisk;
   int               indicatorsUsed[5];
   MLFeatures        entryFeatures;
};

//=====================================================================
//  GLOBAL VARIABLES
//=====================================================================
CTrade           g_trade;
CPositionInfo    g_position;
CAccountInfo     g_account;

// Indicator library (15 indicators max)
IndicatorProfile g_indicators[15];
int              g_indicatorCount = 0;

// Strategy library (10 strategies max)
StrategyProfile  g_strategies[10];
int              g_strategyCount = 10;

// ML Engine
MLModel          g_mlModel;
bool             g_mlReady = false;

// Market State
MarketState      g_market;

// Risk Management
RiskState        g_risk;

// Position Management
ManagedPosition  g_positions[10];
int              g_positionCount = 0;

// Performance Tracking
double           g_totalProfit = 0;
int              g_totalTrades = 0;
int              g_totalWins = 0;
int              g_totalLosses = 0;

// Timing
datetime         g_lastBarTime = 0;
datetime         g_lastMLUpdate = 0;
datetime         g_lastAdaptation = 0;

// Constants
double           g_pointValue;
double           g_pipValue;
int              g_digits;

//=====================================================================
//  INITIALIZATION
//=====================================================================
int OnInit()
{
   // Initialize constants
   g_digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   g_pointValue = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   g_pipValue = (g_digits == 5 || g_digits == 3) ? g_pointValue * 10 : g_pointValue;
   
   // Initialize trade object
   g_trade.SetExpertMagicNumber(InpMagicNumber);
   g_trade.SetDeviationInPoints((int)(InpSlippagePips * 10));
   g_trade.SetTypeFilling(ORDER_FILLING_FOK);
   g_trade.SetAsyncMode(false);
   
   // Initialize indicator library
   InitializeIndicatorLibrary();
   
   // Initialize strategy library
   InitializeStrategyLibrary();
   
   // Initialize ML model
   InitializeMLModel();
   
   // Initialize risk state
   InitializeRiskState();
   
   // Load historical data for ML training
   if(InpEnableML)
   {
      LoadHistoricalTrades();
      TrainMLModel();
   }
   
   // Initial market analysis
   UpdateMarketState();
   
   // Auto-select best indicators and strategies
   if(InpAutoIndicatorSelect) AutoSelectIndicators();
   if(InpAutoStrategySelect) AutoSelectStrategies();
   
   // Create dashboard
   if(InpShowPanel) CreateDashboard();
   
   Print("=== QUANTUM GOLD SCALPER PRO v3.0 INITIALIZED ===");
   Print("ML Engine: ", InpEnableML ? "ACTIVE" : "INACTIVE");
   Print("Auto-Selection: Indicators=", InpAutoIndicatorSelect, " Strategies=", InpAutoStrategySelect);
   
   EventSetTimer(1);
   
   return INIT_SUCCEEDED;
}

//=====================================================================
//  DEINITIALIZATION
//=====================================================================
void OnDeinit(const int reason)
{
   EventKillTimer();
   
   // Save ML model and performance data
   SaveMLModel();
   SavePerformanceData();
   
   // Release indicator handles
   for(int i = 0; i < g_indicatorCount; i++)
   {
      if(g_indicators[i].handle != INVALID_HANDLE)
         IndicatorRelease(g_indicators[i].handle);
   }
   
   // Delete dashboard
   if(InpShowPanel) DeleteDashboard();
   
   Print("=== QUANTUM GOLD SCALPER PRO v3.0 SHUTDOWN ===");
   Print("Total Trades: ", g_totalTrades);
   Print("Win Rate: ", g_totalTrades > 0 ? DoubleToString((double)g_totalWins / g_totalTrades * 100, 2) : "0", "%");
   Print("Total Profit: ", DoubleToString(g_totalProfit, 2));
}

//=====================================================================
//  INDICATOR LIBRARY INITIALIZATION
//=====================================================================
void InitializeIndicatorLibrary()
{
   g_indicatorCount = 0;
   
   // EMA Cross
   AddIndicator(IND_EMA_CROSS, iMA(_Symbol, PERIOD_M1, 8, 0, MODE_EMA, PRICE_CLOSE),
                true, true, true, false, false, true, true);
   
   // MACD
   AddIndicator(IND_MACD, iMACD(_Symbol, PERIOD_M1, 12, 26, 9, PRICE_CLOSE),
                true, true, true, true, false, true, true);
   
   // RSI
   AddIndicator(IND_RSI, iRSI(_Symbol, PERIOD_M1, 14, PRICE_CLOSE),
                true, true, true, true, true, true, true);
   
   // Stochastic
   AddIndicator(IND_STOCHASTIC, iStochastic(_Symbol, PERIOD_M1, 5, 3, 3, MODE_SMA, STO_LOWHIGH),
                true, true, true, true, true, true, true);
   
   // Bollinger Bands
   AddIndicator(IND_BOLLINGER, iBands(_Symbol, PERIOD_M1, 20, 0, 2, PRICE_CLOSE),
                false, true, true, true, true, true, false);
   
   // ATR
   AddIndicator(IND_ATR, iATR(_Symbol, PERIOD_M1, 14),
                true, true, true, true, true, true, true);
   
   // ADX
   AddIndicator(IND_ADX, iADX(_Symbol, PERIOD_M1, 14),
                true, false, true, true, false, true, true);
   
   // CCI
   AddIndicator(IND_CCI, iCCI(_Symbol, PERIOD_M1, 14, PRICE_TYPICAL),
                true, true, true, true, true, true, true);
   
   // Williams %R
   AddIndicator(IND_WILLIAMS, iWPR(_Symbol, PERIOD_M1, 14),
                true, true, true, true, true, true, true);
   
   // Momentum
   AddIndicator(IND_MOMENTUM, iMomentum(_Symbol, PERIOD_M1, 14, PRICE_CLOSE),
                true, true, true, true, false, true, true);
   
   // Ichimoku
   AddIndicator(IND_ICHIMOKU, iIchimoku(_Symbol, PERIOD_M5, 9, 26, 52),
                true, false, true, false, false, true, true);
   
   // Parabolic SAR
   AddIndicator(IND_PARABOLIC_SAR, iSAR(_Symbol, PERIOD_M1, 0.02, 0.2),
                true, false, true, true, true, true, true);
   
   // Fractals
   AddIndicator(IND_FRACTAL, iFractals(_Symbol, PERIOD_M5),
                true, true, false, false, true, true, false);
   
   // Alligator
   AddIndicator(IND_ALLIGATOR, iAlligator(_Symbol, PERIOD_M5, 13, 8, 8, 5, 5, 3, MODE_SMMA, PRICE_MEDIAN),
                true, false, true, true, false, true, true);
   
   Print("Indicator Library Initialized: ", g_indicatorCount, " indicators loaded");
}

void AddIndicator(ENUM_INDICATOR_TYPE type, int handle, 
                  bool trend, bool range, bool highVol, bool lowVol,
                  bool asian, bool london, bool ny)
{
   if(g_indicatorCount >= 15) return;
   if(handle == INVALID_HANDLE)
   {
      Print("Warning: Failed to create indicator handle for type ", type);
      return;
   }
   
   g_indicators[g_indicatorCount].type = type;
   g_indicators[g_indicatorCount].handle = handle;
   g_indicators[g_indicatorCount].active = true;
   g_indicators[g_indicatorCount].performance = 50.0;
   g_indicators[g_indicatorCount].tradesCount = 0;
   g_indicators[g_indicatorCount].wins = 0;
   g_indicators[g_indicatorCount].losses = 0;
   g_indicators[g_indicatorCount].goodForTrending = trend;
   g_indicators[g_indicatorCount].goodForRanging = range;
   g_indicators[g_indicatorCount].goodForHighVol = highVol;
   g_indicators[g_indicatorCount].goodForLowVol = lowVol;
   g_indicators[g_indicatorCount].goodForAsian = asian;
   g_indicators[g_indicatorCount].goodForLondon = london;
   g_indicators[g_indicatorCount].goodForNY = ny;
   
   g_indicatorCount++;
}

//=====================================================================
//  STRATEGY LIBRARY INITIALIZATION
//=====================================================================
void InitializeStrategyLibrary()
{
   for(int i = 0; i < 10; i++)
   {
      g_strategies[i].type = (ENUM_STRATEGY_TYPE)i;
      g_strategies[i].active = true;
      g_strategies[i].performance = 50.0;
      g_strategies[i].tradesCount = 0;
      g_strategies[i].wins = 0;
      g_strategies[i].losses = 0;
      g_strategies[i].totalProfit = 0;
      g_strategies[i].totalLoss = 0;
      g_strategies[i].consecutiveLosses = 0;
      g_strategies[i].maxConsecutiveLosses = 0;
      g_strategies[i].enabled = true;
      g_strategies[i].perfInTrend = 50.0;
      g_strategies[i].perfInRange = 50.0;
      g_strategies[i].perfInBreakout = 50.0;
      g_strategies[i].perfHighVol = 50.0;
      g_strategies[i].perfLowVol = 50.0;
   }
   
   // Set optimal conditions for each strategy
   g_strategies[0].bestCondition = COND_TRENDING_STRONG;
   g_strategies[0].bestSession = SESSION_LONDON_OPEN;
   g_strategies[0].bestVolatility = VOL_HIGH;
   
   g_strategies[1].bestCondition = COND_RANGING_TIGHT;
   g_strategies[1].bestSession = SESSION_ASIAN;
   g_strategies[1].bestVolatility = VOL_LOW;
   
   g_strategies[2].bestCondition = COND_BREAKOUT_BULL;
   g_strategies[2].bestSession = SESSION_NY_OPEN;
   g_strategies[2].bestVolatility = VOL_HIGH;
   
   g_strategies[3].bestCondition = COND_RANGING_WIDE;
   g_strategies[3].bestSession = SESSION_ASIAN;
   g_strategies[3].bestVolatility = VOL_NORMAL;
   
   g_strategies[4].bestCondition = COND_TRENDING_WEAK;
   g_strategies[4].bestSession = SESSION_OVERLAP;
   g_strategies[4].bestVolatility = VOL_NORMAL;
   
   g_strategies[5].bestCondition = COND_BREAKOUT_BULL;
   g_strategies[5].bestSession = SESSION_LONDON_OPEN;
   g_strategies[5].bestVolatility = VOL_HIGH;
   
   g_strategies[6].bestCondition = COND_REVERSAL_ZONE;
   g_strategies[6].bestSession = SESSION_NY_CLOSE;
   g_strategies[6].bestVolatility = VOL_HIGH;
   
   g_strategies[7].bestCondition = COND_RANGING_TIGHT;
   g_strategies[7].bestSession = SESSION_ASIAN;
   g_strategies[7].bestVolatility = VOL_LOW;
   
   g_strategies[8].bestCondition = COND_BREAKOUT_BEAR;
   g_strategies[8].bestSession = SESSION_LONDON_OPEN;
   g_strategies[8].bestVolatility = VOL_HIGH;
   
   g_strategies[9].bestCondition = COND_HIGH_VOLATILITY;
   g_strategies[9].bestSession = SESSION_NY_OPEN;
   g_strategies[9].bestVolatility = VOL_EXTREMELY_HIGH;
   
   Print("Strategy Library Initialized: 10 strategies configured");
}

//=====================================================================
//  ML MODEL INITIALIZATION
//=====================================================================
void InitializeMLModel()
{
   ArrayInitialize(g_mlModel.weights, 0.1);
   g_mlModel.bias = 0.0;
   g_mlModel.historyCount = 0;
   g_mlModel.accuracy = 0.0;
   g_mlModel.lastTraining = 0;
   g_mlModel.trainingCount = 0;
   
   Print("ML Model Initialized");
}

//=====================================================================
//  RISK STATE INITIALIZATION
//=====================================================================
void InitializeRiskState()
{
   g_risk.currentRiskPercent = InpBaseRiskPercent;
   g_risk.dailyProfitLoss = 0;
   g_risk.currentDrawdown = 0;
   g_risk.peakEquity = AccountInfoDouble(ACCOUNT_EQUITY);
   g_risk.dayStartEquity = g_risk.peakEquity;
   g_risk.dailyTradesCount = 0;
   g_risk.dailyLimitHit = false;
   g_risk.drawdownLimitHit = false;
   g_risk.emergencyStop = false;
   g_risk.lastResetTime = TimeCurrent();
}

//=====================================================================
//  MARKET STATE UPDATE
//=====================================================================
void UpdateMarketState()
{
   // Get ATR
   double atr[];
   ArraySetAsSeries(atr, true);
   if(CopyBuffer(g_indicators[5].handle, 0, 0, 50, atr) < 50) return;
   
   g_market.atr = atr[0];
   
   // Calculate normalized ATR
   double atrSum = 0;
   for(int i = 0; i < 50; i++) atrSum += atr[i];
   double atrAvg = atrSum / 50;
   g_market.atrNormalized = (atrAvg > 0) ? (g_market.atr / atrAvg) : 1.0;
   
   // Spread analysis
   g_market.spreadCurrent = (double)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD) * g_pointValue / g_pipValue;
   
   // Determine session
   g_market.session = GetCurrentSession();
   
   // Determine volatility state
   if(g_market.atrNormalized > 2.5)
      g_market.volatility = VOL_SPIKE;
   else if(g_market.atrNormalized > 1.8)
      g_market.volatility = VOL_EXTREMELY_HIGH;
   else if(g_market.atrNormalized > 1.3)
      g_market.volatility = VOL_HIGH;
   else if(g_market.atrNormalized > 0.7)
      g_market.volatility = VOL_NORMAL;
   else if(g_market.atrNormalized > 0.4)
      g_market.volatility = VOL_LOW;
   else
      g_market.volatility = VOL_EXTREMELY_LOW;
   
   // Calculate trend strength
   double ema8[], ema21[];
   ArraySetAsSeries(ema8, true);
   ArraySetAsSeries(ema21, true);
   
   int ema8_handle = iMA(_Symbol, PERIOD_M1, 8, 0, MODE_EMA, PRICE_CLOSE);
   int ema21_handle = iMA(_Symbol, PERIOD_M1, 21, 0, MODE_EMA, PRICE_CLOSE);
   
   if(CopyBuffer(ema8_handle, 0, 0, 20, ema8) >= 20 &&
      CopyBuffer(ema21_handle, 0, 0, 20, ema21) >= 20)
   {
      double separation = MathAbs(ema8[0] - ema21[0]) / g_market.atr;
      g_market.trendStrength = MathMin(100, separation * 50);
      
      // Determine trending state
      g_market.isTrending = (g_market.trendStrength > 30);
      g_market.isRanging = (g_market.trendStrength < 20);
   }
   
   IndicatorRelease(ema8_handle);
   IndicatorRelease(ema21_handle);
   
   // Determine market condition
   DetermineMarketCondition();
   
   // Determine liquidity state
   DetermineLiquidityState();
   
   g_market.lastUpdate = TimeCurrent();
}

ENUM_SESSION_TYPE GetCurrentSession()
{
   MqlDateTime dt;
   TimeCurrent(dt);
   int hour = dt.hour;
   
   // Adjust for broker GMT offset (assuming GMT+2)
   hour = (hour - 2 + 24) % 24;
   
   if(hour >= 0 && hour < 7)
      return SESSION_ASIAN;
   else if(hour >= 7 && hour < 9)
      return SESSION_LONDON_OPEN;
   else if(hour >= 9 && hour < 12)
   {
      if(hour >= 12 && hour < 16)
         return SESSION_OVERLAP; // London-NY overlap
      return SESSION_LONDON_CLOSE;
   }
   else if(hour >= 13 && hour < 15)
      return SESSION_NY_OPEN;
   else if(hour >= 15 && hour < 21)
      return SESSION_NY_CLOSE;
   else
      return SESSION_DEAD;
}

void DetermineMarketCondition()
{
   // Multi-factor analysis
   bool highVol = (g_market.volatility >= VOL_HIGH);
   bool lowVol = (g_market.volatility <= VOL_LOW);
   bool trending = g_market.isTrending;
   bool ranging = g_market.isRanging;
   
   // Get price action
   double high = iHigh(_Symbol, PERIOD_M1, 0);
   double low = iLow(_Symbol, PERIOD_M1, 0);
   double close = iClose(_Symbol, PERIOD_M1, 0);
   double prevClose = iClose(_Symbol, PERIOD_M1, 1);
   
   // Calculate price range position
   double range = high - low;
   if(range > 0)
      g_market.priceRangePosition = (close - low) / range * 100;
   else
      g_market.priceRangePosition = 50;
   
   // Breakout detection
   double high20 = iHigh(_Symbol, PERIOD_M1, iHighest(_Symbol, PERIOD_M1, MODE_HIGH, 20, 1));
   double low20 = iLow(_Symbol, PERIOD_M1, iLowest(_Symbol, PERIOD_M1, MODE_LOW, 20, 1));
   
   bool breakoutUp = (close > high20);
   bool breakoutDown = (close < low20);
   
   // Determine condition
   if(breakoutUp && highVol)
      g_market.condition = COND_BREAKOUT_BULL;
   else if(breakoutDown && highVol)
      g_market.condition = COND_BREAKOUT_BEAR;
   else if(trending && g_market.trendStrength > 60)
      g_market.condition = COND_TRENDING_STRONG;
   else if(trending && g_market.trendStrength > 30)
      g_market.condition = COND_TRENDING_WEAK;
   else if(ranging && lowVol)
      g_market.condition = COND_RANGING_TIGHT;
   else if(ranging)
      g_market.condition = COND_RANGING_WIDE;
   else if(g_market.volatility == VOL_SPIKE)
      g_market.condition = COND_HIGH_VOLATILITY;
   else if(g_market.volatility == VOL_EXTREMELY_LOW)
      g_market.condition = COND_LOW_VOLATILITY;
   else
      g_market.condition = COND_CONSOLIDATION;
}

void DetermineLiquidityState()
{
   // Based on spread and volatility
   double spreadRatio = g_market.spreadCurrent / (g_market.atr / g_pipValue);
   
   if(spreadRatio < 0.05)
      g_market.liquidity = LIQ_VERY_DEEP;
   else if(spreadRatio < 0.1)
      g_market.liquidity = LIQ_DEEP;
   else if(spreadRatio < 0.2)
      g_market.liquidity = LIQ_NORMAL;
   else if(spreadRatio < 0.4)
      g_market.liquidity = LIQ_THIN;
   else
      g_market.liquidity = LIQ_VERY_THIN;
}

//=====================================================================
//  AUTO-SELECT INDICATORS
//=====================================================================
void AutoSelectIndicators()
{
   // Deactivate all first
   for(int i = 0; i < g_indicatorCount; i++)
      g_indicators[i].active = false;
   
   // Select top performers for current conditions
   double scores[15];
   
   for(int i = 0; i < g_indicatorCount; i++)
   {
      scores[i] = CalculateIndicatorScore(i);
   }
   
   // Get top 5 indicators
   int selected = 0;
   while(selected < 5 && selected < g_indicatorCount)
   {
      int bestIdx = -1;
      double bestScore = -1;
      
      for(int i = 0; i < g_indicatorCount; i++)
      {
         if(!g_indicators[i].active && scores[i] > bestScore)
         {
            bestScore = scores[i];
            bestIdx = i;
         }
      }
      
      if(bestIdx >= 0)
      {
         g_indicators[bestIdx].active = true;
         selected++;
      }
      else
         break;
   }
   
   Print("Auto-selected ", selected, " indicators for current market conditions");
}

double CalculateIndicatorScore(int idx)
{
   double score = g_indicators[idx].performance;
   
   // Boost score based on compatibility with current conditions
   if(g_market.isTrending && g_indicators[idx].goodForTrending)
      score *= 1.3;
   if(g_market.isRanging && g_indicators[idx].goodForRanging)
      score *= 1.3;
   if(g_market.volatility >= VOL_HIGH && g_indicators[idx].goodForHighVol)
      score *= 1.2;
   if(g_market.volatility <= VOL_LOW && g_indicators[idx].goodForLowVol)
      score *= 1.2;
   
   // Session compatibility
   if(g_market.session == SESSION_ASIAN && g_indicators[idx].goodForAsian)
      score *= 1.2;
   if((g_market.session == SESSION_LONDON_OPEN || g_market.session == SESSION_LONDON_CLOSE) && 
      g_indicators[idx].goodForLondon)
      score *= 1.2;
   if((g_market.session == SESSION_NY_OPEN || g_market.session == SESSION_NY_CLOSE) && 
      g_indicators[idx].goodForNY)
      score *= 1.2;
   
   // Recent performance weight
   if(g_indicators[idx].tradesCount > 0)
   {
      datetime hourAgo = TimeCurrent() - 3600;
      if(g_indicators[idx].lastUsed > hourAgo)
         score *= 1.1; // Recently successful
   }
   
   return score;
}

//=====================================================================
//  AUTO-SELECT STRATEGIES
//=====================================================================
void AutoSelectStrategies()
{
   // Disable poorly performing strategies
   for(int i = 0; i < g_strategyCount; i++)
   {
      // Disable if consecutive losses exceed threshold
      if(g_strategies[i].consecutiveLosses >= 5)
      {
         g_strategies[i].enabled = false;
         Print("Strategy ", i, " disabled due to consecutive losses");
         continue;
      }
      
      // Disable if performance below 40%
      if(g_strategies[i].tradesCount >= 20 && g_strategies[i].performance < 40)
      {
         g_strategies[i].enabled = false;
         Print("Strategy ", i, " disabled due to poor performance");
         continue;
      }
      
      // Re-enable if performance improves
      if(!g_strategies[i].enabled && g_strategies[i].performance > 55)
      {
         g_strategies[i].enabled = true;
         g_strategies[i].consecutiveLosses = 0;
         Print("Strategy ", i, " re-enabled");
      }
   }
}

//=====================================================================
//  SIGNAL GENERATION
//=====================================================================
int GenerateSignal()
{
   // Check filters first
   if(!PassFilters()) return 0;
   
   // Get best strategy for current conditions
   int strategyIdx = GetBestStrategy();
   if(strategyIdx < 0) return 0;
   
   // Generate signal based on strategy
   int signal = 0;
   
   switch(g_strategies[strategyIdx].type)
   {
      case STRAT_MOMENTUM_SCALP:
         signal = Signal_MomentumScalp();
         break;
      case STRAT_MEAN_REVERSION:
         signal = Signal_MeanReversion();
         break;
      case STRAT_BREAKOUT_SCALP:
         signal = Signal_BreakoutScalp();
         break;
      case STRAT_RANGE_BOUNCE:
         signal = Signal_RangeBounce();
         break;
      case STRAT_TREND_FOLLOW:
         signal = Signal_TrendFollow();
         break;
      case STRAT_LONDON_BREAKOUT:
         signal = Signal_LondonBreakout();
         break;
      case STRAT_NY_REVERSAL:
         signal = Signal_NYReversal();
         break;
      case STRAT_ASIAN_RANGE:
         signal = Signal_AsianRange();
         break;
      case STRAT_LIQUIDITY_GRAB:
         signal = Signal_LiquidityGrab();
         break;
      case STRAT_VOLATILITY_EXPANSION:
         signal = Signal_VolatilityExpansion();
         break;
   }
   
   // ML confidence check
   if(InpEnableML && g_mlReady)
   {
      double confidence = GetMLConfidence(signal, strategyIdx);
      if(confidence < InpMLMinConfidence)
      {
         Print("ML rejected signal - confidence: ", DoubleToString(confidence, 2), "%");
         return 0;
      }
   }
   
   return signal;
}

bool PassFilters()
{
   // Spread filter
   if(InpUseSpreadFilter && g_market.spreadCurrent > InpMaxSpreadPips)
   {
      Print("Spread filter: ", DoubleToString(g_market.spreadCurrent, 2), " pips > ", InpMaxSpreadPips);
      return false;
   }
   
   // Time filter
   if(InpUseTimeFilter)
   {
      MqlDateTime dt;
      TimeCurrent(dt);
      int currentMinutes = dt.hour * 60 + dt.min;
      
      string parts[];
      int startHour = 0, startMin = 0, endHour = 23, endMin = 59;
      
      if(StringSplit(InpTradingStartTime, ':', parts) == 2)
      {
         startHour = (int)StringToInteger(parts[0]);
         startMin = (int)StringToInteger(parts[1]);
      }
      
      if(StringSplit(InpTradingEndTime, ':', parts) == 2)
      {
         endHour = (int)StringToInteger(parts[0]);
         endMin = (int)StringToInteger(parts[1]);
      }
      
      int startMinutes = startHour * 60 + startMin;
      int endMinutes = endHour * 60 + endMin;
      
      if(currentMinutes < startMinutes || currentMinutes > endMinutes)
         return false;
   }
   
   // News filter (simplified - checks for high volatility spike)
   if(InpUseNewsFilter && g_market.volatility == VOL_SPIKE)
   {
      Print("News filter: Volatility spike detected");
      return false;
   }
   
   // Risk limits
   if(g_risk.dailyLimitHit || g_risk.drawdownLimitHit || g_risk.emergencyStop)
      return false;
   
   if(g_risk.dailyTradesCount >= InpMaxDailyTrades)
      return false;
   
   if(g_positionCount >= InpMaxConcurrent)
      return false;
   
   return true;
}

int GetBestStrategy()
{
   int bestIdx = -1;
   double bestScore = 0;
   
   for(int i = 0; i < g_strategyCount; i++)
   {
      if(!g_strategies[i].enabled) continue;
      
      double score = g_strategies[i].performance;
      
      // Boost based on condition match
      if(g_strategies[i].bestCondition == g_market.condition)
         score *= 1.5;
      if(g_strategies[i].bestSession == g_market.session)
         score *= 1.3;
      if(g_strategies[i].bestVolatility == g_market.volatility)
         score *= 1.2;
      
      // Performance in current condition type
      if(g_market.isTrending)
         score *= (g_strategies[i].perfInTrend / 50.0);
      else if(g_market.isRanging)
         score *= (g_strategies[i].perfInRange / 50.0);
      
      if(score > bestScore)
      {
         bestScore = score;
         bestIdx = i;
      }
   }
   
   return bestIdx;
}

//=====================================================================
//  STRATEGY SIGNAL FUNCTIONS
//=====================================================================
int Signal_MomentumScalp()
{
   // Uses RSI, MACD, and Momentum
   double rsi[], macd[], signal_line[], momentum[];
   ArraySetAsSeries(rsi, true);
   ArraySetAsSeries(macd, true);
   ArraySetAsSeries(signal_line, true);
   ArraySetAsSeries(momentum, true);
   
   int rsi_idx = GetIndicatorIndex(IND_RSI);
   int macd_idx = GetIndicatorIndex(IND_MACD);
   int mom_idx = GetIndicatorIndex(IND_MOMENTUM);
   
   if(rsi_idx < 0 || macd_idx < 0 || mom_idx < 0) return 0;
   
   if(CopyBuffer(g_indicators[rsi_idx].handle, 0, 0, 3, rsi) < 3) return 0;
   if(CopyBuffer(g_indicators[macd_idx].handle, 0, 0, 3, macd) < 3) return 0;
   if(CopyBuffer(g_indicators[macd_idx].handle, 1, 0, 3, signal_line) < 3) return 0;
   if(CopyBuffer(g_indicators[mom_idx].handle, 0, 0, 3, momentum) < 3) return 0;
   
   // Buy signal
   if(rsi[0] > 50 && rsi[0] < 70 &&
      macd[0] > signal_line[0] && macd[1] <= signal_line[1] &&
      momentum[0] > momentum[1])
      return 1;
   
   // Sell signal
   if(rsi[0] < 50 && rsi[0] > 30 &&
      macd[0] < signal_line[0] && macd[1] >= signal_line[1] &&
      momentum[0] < momentum[1])
      return -1;
   
   return 0;
}

int Signal_MeanReversion()
{
   // Uses Bollinger Bands and RSI
   double upper[], middle[], lower[], rsi[];
   ArraySetAsSeries(upper, true);
   ArraySetAsSeries(middle, true);
   ArraySetAsSeries(lower, true);
   ArraySetAsSeries(rsi, true);
   
   int bb_idx = GetIndicatorIndex(IND_BOLLINGER);
   int rsi_idx = GetIndicatorIndex(IND_RSI);
   
   if(bb_idx < 0 || rsi_idx < 0) return 0;
   
   if(CopyBuffer(g_indicators[bb_idx].handle, 1, 0, 3, upper) < 3) return 0;
   if(CopyBuffer(g_indicators[bb_idx].handle, 0, 0, 3, middle) < 3) return 0;
   if(CopyBuffer(g_indicators[bb_idx].handle, 2, 0, 3, lower) < 3) return 0;
   if(CopyBuffer(g_indicators[rsi_idx].handle, 0, 0, 3, rsi) < 3) return 0;
   
   double close = iClose(_Symbol, PERIOD_M1, 0);
   
   // Buy at lower band
   if(close <= lower[0] && rsi[0] < 30)
      return 1;
   
   // Sell at upper band
   if(close >= upper[0] && rsi[0] > 70)
      return -1;
   
   return 0;
}

int Signal_BreakoutScalp()
{
   // Detects breakout with volume confirmation (ATR proxy)
   double high20 = iHigh(_Symbol, PERIOD_M1, iHighest(_Symbol, PERIOD_M1, MODE_HIGH, 20, 1));
   double low20 = iLow(_Symbol, PERIOD_M1, iLowest(_Symbol, PERIOD_M1, MODE_LOW, 20, 1));
   double close = iClose(_Symbol, PERIOD_M1, 0);
   
   // Must have high volatility
   if(g_market.volatility < VOL_HIGH) return 0;
   
   if(close > high20)
      return 1;
   if(close < low20)
      return -1;
   
   return 0;
}

int Signal_RangeBounce()
{
   // Trade bounces in ranging market
   if(!g_market.isRanging) return 0;
   
   double high20 = iHigh(_Symbol, PERIOD_M1, iHighest(_Symbol, PERIOD_M1, MODE_HIGH, 20, 1));
   double low20 = iLow(_Symbol, PERIOD_M1, iLowest(_Symbol, PERIOD_M1, MODE_LOW, 20, 1));
   double close = iClose(_Symbol, PERIOD_M1, 0);
   
   double range = high20 - low20;
   if(range == 0) return 0;
   
   double position = (close - low20) / range;
   
   // Buy near support
   if(position < 0.2)
      return 1;
   
   // Sell near resistance
   if(position > 0.8)
      return -1;
   
   return 0;
}

int Signal_TrendFollow()
{
   // Uses EMA and ADX
   double ema8[], ema21[], adx[];
   ArraySetAsSeries(ema8, true);
   ArraySetAsSeries(ema21, true);
   ArraySetAsSeries(adx, true);
   
   int ema_idx = GetIndicatorIndex(IND_EMA_CROSS);
   int adx_idx = GetIndicatorIndex(IND_ADX);
   
   if(ema_idx < 0 || adx_idx < 0) return 0;
   
   int ema8_h = iMA(_Symbol, PERIOD_M1, 8, 0, MODE_EMA, PRICE_CLOSE);
   int ema21_h = iMA(_Symbol, PERIOD_M1, 21, 0, MODE_EMA, PRICE_CLOSE);
   
   if(CopyBuffer(ema8_h, 0, 0, 3, ema8) < 3) return 0;
   if(CopyBuffer(ema21_h, 0, 0, 3, ema21) < 3) return 0;
   if(CopyBuffer(g_indicators[adx_idx].handle, 0, 0, 3, adx) < 3) return 0;
   
   IndicatorRelease(ema8_h);
   IndicatorRelease(ema21_h);
   
   // Strong trend required
   if(adx[0] < 25) return 0;
   
   double close = iClose(_Symbol, PERIOD_M1, 0);
   
   // Buy in uptrend
   if(ema8[0] > ema21[0] && close > ema8[0])
      return 1;
   
   // Sell in downtrend
   if(ema8[0] < ema21[0] && close < ema8[0])
      return -1;
   
   return 0;
}

int Signal_LondonBreakout()
{
   if(g_market.session != SESSION_LONDON_OPEN) return 0;
   return Signal_BreakoutScalp();
}

int Signal_NYReversal()
{
   if(g_market.session != SESSION_NY_CLOSE) return 0;
   return Signal_MeanReversion();
}

int Signal_AsianRange()
{
   if(g_market.session != SESSION_ASIAN) return 0;
   return Signal_RangeBounce();
}

int Signal_LiquidityGrab()
{
   // Looks for stop hunts - price spikes that reverse quickly
   double high = iHigh(_Symbol, PERIOD_M1, 0);
   double low = iLow(_Symbol, PERIOD_M1, 0);
   double close = iClose(_Symbol, PERIOD_M1, 0);
   double open = iOpen(_Symbol, PERIOD_M1, 0);
   
   double bodySize = MathAbs(close - open);
   double upperWick = high - MathMax(close, open);
   double lowerWick = MathMin(close, open) - low;
   
   // Long upper wick suggests liquidity grab above
   if(upperWick > bodySize * 2 && close < open)
      return -1;
   
   // Long lower wick suggests liquidity grab below
   if(lowerWick > bodySize * 2 && close > open)
      return 1;
   
   return 0;
}

int Signal_VolatilityExpansion()
{
   if(g_market.volatility < VOL_HIGH) return 0;
   
   // Trade in direction of momentum during volatility expansion
   double close = iClose(_Symbol, PERIOD_M1, 0);
   double prevClose = iClose(_Symbol, PERIOD_M1, 1);
   
   if(close > prevClose)
      return 1;
   else if(close < prevClose)
      return -1;
   
   return 0;
}

int GetIndicatorIndex(ENUM_INDICATOR_TYPE type)
{
   for(int i = 0; i < g_indicatorCount; i++)
   {
      if(g_indicators[i].type == type && g_indicators[i].active)
         return i;
   }
   return -1;
}

//=====================================================================
//  ML CONFIDENCE CALCULATION
//=====================================================================
double GetMLConfidence(int signal, int strategyIdx)
{
   if(!g_mlReady || g_mlModel.historyCount < 20) return 100.0;
   
   // Extract current features
   MLFeatures currentFeatures;
   ExtractCurrentFeatures(currentFeatures);
   
   // Calculate prediction using trained model
   double prediction = g_mlModel.bias;
   
   prediction += currentFeatures.atr * g_mlModel.weights[0];
   prediction += currentFeatures.spread * g_mlModel.weights[1];
   prediction += currentFeatures.hourOfDay * g_mlModel.weights[2];
   prediction += currentFeatures.dayOfWeek * g_mlModel.weights[3];
   prediction += currentFeatures.volatilityRatio * g_mlModel.weights[4];
   prediction += currentFeatures.trendStrength * g_mlModel.weights[5];
   prediction += currentFeatures.momentumScore * g_mlModel.weights[6];
   prediction += currentFeatures.volumeRatio * g_mlModel.weights[7];
   prediction += currentFeatures.pricePosition * g_mlModel.weights[8];
   prediction += currentFeatures.timeInSession * g_mlModel.weights[9];
   
   // Sigmoid activation
   double probability = 1.0 / (1.0 + MathExp(-prediction));
   
   // Convert to confidence percentage
   double confidence = probability * 100;
   
   // Adjust based on recent strategy performance
   if(g_strategies[strategyIdx].tradesCount > 0)
   {
      confidence *= (g_strategies[strategyIdx].performance / 100.0);
   }
   
   return confidence;
}

void ExtractCurrentFeatures(MLFeatures &features)
{
   features.atr = g_market.atr / g_pipValue;
   features.spread = g_market.spreadCurrent;
   
   MqlDateTime dt;
   TimeCurrent(dt);
   features.hourOfDay = dt.hour / 24.0;
   features.dayOfWeek = dt.day_of_week / 7.0;
   
   features.volatilityRatio = g_market.atrNormalized;
   features.trendStrength = g_market.trendStrength / 100.0;
   features.momentumScore = g_market.momentum / 100.0;
   features.volumeRatio = g_market.volumeRatio;
   features.pricePosition = g_market.priceRangePosition / 100.0;
   
   // Calculate time in current session (0-1)
   int sessionStart = 0, sessionEnd = 24;
   switch(g_market.session)
   {
      case SESSION_ASIAN: sessionStart = 0; sessionEnd = 7; break;
      case SESSION_LONDON_OPEN: sessionStart = 7; sessionEnd = 9; break;
      case SESSION_OVERLAP: sessionStart = 12; sessionEnd = 16; break;
      case SESSION_NY_OPEN: sessionStart = 13; sessionEnd = 15; break;
   }
   
   if(sessionEnd > sessionStart)
      features.timeInSession = (double)(dt.hour - sessionStart) / (sessionEnd - sessionStart);
   else
      features.timeInSession = 0.5;
}

//=====================================================================
//  POSITION MANAGEMENT
//=====================================================================
void ManageOpenPositions()
{
   for(int i = g_positionCount - 1; i >= 0; i--)
   {
      if(!PositionSelectByTicket(g_positions[i].ticket))
      {
         // Position closed - remove from array
         RemoveManagedPosition(i);
         continue;
      }
      
      double currentPrice = PositionGetDouble(POSITION_PRICE_CURRENT);
      double openPrice = g_positions[i].openPrice;
      double sl = g_positions[i].stopLoss;
      double tp = g_positions[i].takeProfit;
      
      bool isBuy = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY);
      
      double profitPips = isBuy ? 
         (currentPrice - openPrice) / g_pipValue : 
         (openPrice - currentPrice) / g_pipValue;
      
      // Break-even logic
      if(InpUseTrailingStop && !g_positions[i].breakEvenSet && profitPips >= InpBreakEvenPips)
      {
         double newSL = isBuy ? 
            openPrice + InpBreakEvenPlus * g_pipValue :
            openPrice - InpBreakEvenPlus * g_pipValue;
         
         if(g_trade.PositionModify(g_positions[i].ticket, newSL, tp))
         {
            g_positions[i].breakEvenSet = true;
            g_positions[i].stopLoss = newSL;
            Print("Break-even set for ticket ", g_positions[i].ticket);
         }
      }
      
      // Trailing stop logic
      if(InpUseTrailingStop && profitPips >= InpTrailingStart)
      {
         if(g_positions[i].trailingActivated == 0)
            g_positions[i].trailingActivated = profitPips;
         
         double trailDistance = profitPips - g_positions[i].trailingActivated;
         
         if(trailDistance >= InpTrailingStep)
         {
            double newSL = isBuy ?
               currentPrice - InpTrailingStep * g_pipValue :
               currentPrice + InpTrailingStep * g_pipValue;
            
            // Only move SL in favorable direction
            bool shouldUpdate = isBuy ? (newSL > sl) : (newSL < sl);
            
            if(shouldUpdate && g_trade.PositionModify(g_positions[i].ticket, newSL, tp))
            {
               g_positions[i].stopLoss = newSL;
               g_positions[i].trailingActivated = profitPips;
               Print("Trailing stop updated for ticket ", g_positions[i].ticket, " to ", newSL);
            }
         }
      }
   }
}

void RemoveManagedPosition(int index)
{
   if(index < 0 || index >= g_positionCount) return;
   
   // Shift remaining positions
   for(int i = index; i < g_positionCount - 1; i++)
   {
      g_positions[i] = g_positions[i + 1];
   }
   
   g_positionCount--;
}

//=====================================================================
//  TRADE EXECUTION
//=====================================================================
bool ExecuteTrade(int signal, int strategyIdx)
{
   if(signal == 0) return false;
   
   // Calculate lot size
   double lotSize = CalculateLotSize(strategyIdx);
   if(lotSize <= 0) return false;
   
   // Calculate SL and TP
   double sl = 0, tp = 0;
   CalculateSLTP(signal, sl, tp);
   
   // Validate SL/TP
   if(!ValidateSLTP(signal, sl, tp)) return false;
   
   // Execute trade
   bool success = false;
   ulong ticket = 0;
   
   if(signal > 0) // Buy
   {
      double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      success = g_trade.Buy(lotSize, _Symbol, ask, sl, tp, InpTradeComment);
      ticket = g_trade.ResultOrder();
   }
   else // Sell
   {
      double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      success = g_trade.Sell(lotSize, _Symbol, bid, sl, tp, InpTradeComment);
      ticket = g_trade.ResultOrder();
   }
   
   if(success && ticket > 0)
   {
      // Add to managed positions
      AddManagedPosition(ticket, strategyIdx, sl, tp);
      
      // Update counters
      g_risk.dailyTradesCount++;
      g_totalTrades++;
      
      Print("Trade executed: ", signal > 0 ? "BUY" : "SELL", 
            " Lot: ", lotSize, " SL: ", sl, " TP: ", tp);
      
      return true;
   }
   else
   {
      Print("Trade execution failed: ", g_trade.ResultRetcodeDescription());
      return false;
   }
}

double CalculateLotSize(int strategyIdx)
{
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   
   // Adjust risk based on conditions
   double riskPercent = g_risk.currentRiskPercent;
   
   // Reduce risk in high volatility
   if(g_market.volatility >= VOL_EXTREMELY_HIGH)
      riskPercent *= 0.5;
   else if(g_market.volatility >= VOL_HIGH)
      riskPercent *= 0.7;
   
   // Reduce risk after losses
   if(g_strategies[strategyIdx].consecutiveLosses > 0)
      riskPercent *= MathPow(0.8, g_strategies[strategyIdx].consecutiveLosses);
   
   // Increase risk after wins (up to max)
   if(g_strategies[strategyIdx].consecutiveLosses == 0 && g_strategies[strategyIdx].wins > g_strategies[strategyIdx].losses)
      riskPercent = MathMin(InpMaxRiskPercent, riskPercent * 1.2);
   
   double riskAmount = equity * riskPercent / 100.0;
   
   // Calculate based on SL distance
   double slPips = MathMax(InpMinSLPips, g_market.atr / g_pipValue * 1.5);
   
   double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   
   if(tickValue <= 0 || tickSize <= 0) return 0;
   
   double lotSize = riskAmount / (slPips * 10 * tickValue / tickSize);
   
   // Round to lot step
   double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   lotSize = MathFloor(lotSize / lotStep) * lotStep;
   
   // Apply min/max limits
   double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   
   lotSize = MathMax(minLot, MathMin(maxLot, lotSize));
   
   return lotSize;
}

void CalculateSLTP(int signal, double &sl, double &tp)
{
   double atr = g_market.atr;
   double price = (signal > 0) ? 
      SymbolInfoDouble(_Symbol, SYMBOL_ASK) : 
      SymbolInfoDouble(_Symbol, SYMBOL_BID);
   
   // Dynamic SL based on ATR
   double slPips = MathMax(InpMinSLPips, atr / g_pipValue * 1.5);
   double tpPips = MathMax(InpMinTPPips, slPips * 1.5); // 1.5:1 R:R minimum
   
   if(signal > 0) // Buy
   {
      sl = price - slPips * g_pipValue;
      tp = price + tpPips * g_pipValue;
   }
   else // Sell
   {
      sl = price + slPips * g_pipValue;
      tp = price - tpPips * g_pipValue;
   }
   
   // Normalize
   sl = NormalizeDouble(sl, g_digits);
   tp = NormalizeDouble(tp, g_digits);
}

bool ValidateSLTP(int signal, double sl, double tp)
{
   double price = (signal > 0) ? 
      SymbolInfoDouble(_Symbol, SYMBOL_ASK) : 
      SymbolInfoDouble(_Symbol, SYMBOL_BID);
   
   double minDistance = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL) * g_pointValue;
   
   if(signal > 0) // Buy
   {
      if(price - sl < minDistance) return false;
      if(tp - price < minDistance) return false;
   }
   else // Sell
   {
      if(sl - price < minDistance) return false;
      if(price - tp < minDistance) return false;
   }
   
   return true;
}

void AddManagedPosition(ulong ticket, int strategyIdx, double sl, double tp)
{
   if(g_positionCount >= 10) return;
   
   g_positions[g_positionCount].ticket = ticket;
   g_positions[g_positionCount].strategy = g_strategies[strategyIdx].type;
   g_positions[g_positionCount].openTime = TimeCurrent();
   g_positions[g_positionCount].openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
   g_positions[g_positionCount].stopLoss = sl;
   g_positions[g_positionCount].takeProfit = tp;
   g_positions[g_positionCount].trailingActivated = 0;
   g_positions[g_positionCount].breakEvenSet = false;
   
   // Store indicators used
   int indCount = 0;
   for(int i = 0; i < g_indicatorCount && indCount < 5; i++)
   {
      if(g_indicators[i].active)
      {
         g_positions[g_positionCount].indicatorsUsed[indCount] = i;
         indCount++;
      }
   }
   
   // Store entry features for ML
   ExtractCurrentFeatures(g_positions[g_positionCount].entryFeatures);
   
   g_positionCount++;
}

//=====================================================================
//  TRADE HISTORY ANALYSIS
//=====================================================================
void OnTradeTransaction(const MqlTradeTransaction &trans,
                        const MqlTradeRequest &request,
                        const MqlTradeResult &result)
{
   if(trans.type == TRADE_TRANSACTION_DEAL_ADD)
   {
      ulong dealTicket = trans.deal;
      
      if(HistoryDealSelect(dealTicket))
      {
         long dealMagic = HistoryDealGetInteger(dealTicket, DEAL_MAGIC);
         if(dealMagic != InpMagicNumber) return;
         
         long dealEntry = HistoryDealGetInteger(dealTicket, DEAL_ENTRY);
         if(dealEntry == DEAL_ENTRY_OUT) // Position closed
         {
            double profit = HistoryDealGetDouble(dealTicket, DEAL_PROFIT);
            double swap = HistoryDealGetDouble(dealTicket, DEAL_SWAP);
            double commission = HistoryDealGetDouble(dealTicket, DEAL_COMMISSION);
            
            double totalProfit = profit + swap + commission;
            
            // Find the managed position
            for(int i = 0; i < g_positionCount; i++)
            {
               if(g_positions[i].ticket == trans.position)
               {
                  ProcessClosedTrade(i, totalProfit);
                  RemoveManagedPosition(i);
                  break;
               }
            }
         }
      }
   }
}

void ProcessClosedTrade(int posIdx, double profit)
{
   bool isWin = (profit > 0);
   
   // Update global stats
   g_totalProfit += profit;
   if(isWin)
      g_totalWins++;
   else
      g_totalLosses++;
   
   g_risk.dailyProfitLoss += profit;
   
   // Update strategy stats
   int stratIdx = GetStrategyIndex(g_positions[posIdx].strategy);
   if(stratIdx >= 0)
   {
      g_strategies[stratIdx].tradesCount++;
      
      if(isWin)
      {
         g_strategies[stratIdx].wins++;
         g_strategies[stratIdx].totalProfit += profit;
         g_strategies[stratIdx].consecutiveLosses = 0;
      }
      else
      {
         g_strategies[stratIdx].losses++;
         g_strategies[stratIdx].totalLoss += MathAbs(profit);
         g_strategies[stratIdx].consecutiveLosses++;
         
         if(g_strategies[stratIdx].consecutiveLosses > g_strategies[stratIdx].maxConsecutiveLosses)
            g_strategies[stratIdx].maxConsecutiveLosses = g_strategies[stratIdx].consecutiveLosses;
      }
      
      // Update performance
      if(g_strategies[stratIdx].tradesCount > 0)
      {
         g_strategies[stratIdx].performance = 
            (double)g_strategies[stratIdx].wins / g_strategies[stratIdx].tradesCount * 100.0;
      }
      
      // Update expectancy
      double avgWin = (g_strategies[stratIdx].wins > 0) ? 
         g_strategies[stratIdx].totalProfit / g_strategies[stratIdx].wins : 0;
      double avgLoss = (g_strategies[stratIdx].losses > 0) ? 
         g_strategies[stratIdx].totalLoss / g_strategies[stratIdx].losses : 0;
      
      double winRate = g_strategies[stratIdx].performance / 100.0;
      g_strategies[stratIdx].expectancy = (winRate * avgWin) - ((1 - winRate) * avgLoss);
   }
   
   // Update indicator stats
   for(int i = 0; i < 5; i++)
   {
      int indIdx = g_positions[posIdx].indicatorsUsed[i];
      if(indIdx >= 0 && indIdx < g_indicatorCount)
      {
         g_indicators[indIdx].tradesCount++;
         
         if(isWin)
         {
            g_indicators[indIdx].wins++;
            g_indicators[indIdx].avgProfit = 
               (g_indicators[indIdx].avgProfit * (g_indicators[indIdx].wins - 1) + profit) / 
               g_indicators[indIdx].wins;
         }
         else
         {
            g_indicators[indIdx].losses++;
            g_indicators[indIdx].avgLoss = 
               (g_indicators[indIdx].avgLoss * (g_indicators[indIdx].losses - 1) + MathAbs(profit)) / 
               g_indicators[indIdx].losses;
         }
         
         if(g_indicators[indIdx].tradesCount > 0)
         {
            g_indicators[indIdx].performance = 
               (double)g_indicators[indIdx].wins / g_indicators[indIdx].tradesCount * 100.0;
         }
         
         g_indicators[indIdx].lastUsed = TimeCurrent();
      }
   }
   
   // Add to ML history
   if(InpEnableML)
   {
      AddMLTradeRecord(posIdx, profit, isWin);
   }
   
   Print("Trade closed - Profit: ", DoubleToString(profit, 2), 
         " Strategy: ", stratIdx, " Win: ", isWin ? "YES" : "NO");
}

int GetStrategyIndex(ENUM_STRATEGY_TYPE type)
{
   for(int i = 0; i < g_strategyCount; i++)
   {
      if(g_strategies[i].type == type)
         return i;
   }
   return -1;
}

void AddMLTradeRecord(int posIdx, double profit, bool isWin)
{
   if(g_mlModel.historyCount >= 200)
   {
      // Shift array to make room
      for(int i = 0; i < 199; i++)
      {
         g_mlModel.history[i] = g_mlModel.history[i + 1];
      }
      g_mlModel.historyCount = 199;
   }
   
   int idx = g_mlModel.historyCount;
   
   g_mlModel.history[idx].timestamp = g_positions[posIdx].openTime;
   g_mlModel.history[idx].features = g_positions[posIdx].entryFeatures;
   g_mlModel.history[idx].strategy = g_positions[posIdx].strategy;
   g_mlModel.history[idx].profit = profit;
   g_mlModel.history[idx].wasWinner = isWin;
   g_mlModel.history[idx].condition = g_market.condition;
   g_mlModel.history[idx].session = g_market.session;
   
   // Copy indicators used
   for(int i = 0; i < 5; i++)
   {
      g_mlModel.history[idx].indicatorSet[i] = g_positions[posIdx].indicatorsUsed[i];
   }
   
   g_mlModel.historyCount++;
   
   // Trigger retraining if needed
   if(g_mlModel.historyCount % InpMLRetrainingPeriod == 0)
   {
      TrainMLModel();
   }
}

//=====================================================================
//  ML TRAINING
//=====================================================================
void TrainMLModel()
{
   if(g_mlModel.historyCount < InpMLLearningPeriod) 
   {
      Print("Insufficient data for ML training: ", g_mlModel.historyCount, " / ", InpMLLearningPeriod);
      return;
   }
   
   Print("Training ML model with ", g_mlModel.historyCount, " samples...");
   
   // Simple gradient descent
   double learningRate = 0.01;
   int epochs = 100;
   
   for(int epoch = 0; epoch < epochs; epoch++)
   {
      double totalError = 0;
      
      for(int i = 0; i < g_mlModel.historyCount; i++)
      {
         // Forward pass
         double prediction = g_mlModel.bias;
         MLFeatures f = g_mlModel.history[i].features;
         
         prediction += f.atr * g_mlModel.weights[0];
         prediction += f.spread * g_mlModel.weights[1];
         prediction += f.hourOfDay * g_mlModel.weights[2];
         prediction += f.dayOfWeek * g_mlModel.weights[3];
         prediction += f.volatilityRatio * g_mlModel.weights[4];
         prediction += f.trendStrength * g_mlModel.weights[5];
         prediction += f.momentumScore * g_mlModel.weights[6];
         prediction += f.volumeRatio * g_mlModel.weights[7];
         prediction += f.pricePosition * g_mlModel.weights[8];
         prediction += f.timeInSession * g_mlModel.weights[9];
         
         // Sigmoid
         prediction = 1.0 / (1.0 + MathExp(-prediction));
         
         // Calculate error
         double target = g_mlModel.history[i].wasWinner ? 1.0 : 0.0;
         double error = target - prediction;
         totalError += error * error;
         
         // Backward pass (gradient descent)
         double gradient = error * prediction * (1.0 - prediction);
         
         g_mlModel.weights[0] += learningRate * gradient * f.atr;
         g_mlModel.weights[1] += learningRate * gradient * f.spread;
         g_mlModel.weights[2] += learningRate * gradient * f.hourOfDay;
         g_mlModel.weights[3] += learningRate * gradient * f.dayOfWeek;
         g_mlModel.weights[4] += learningRate * gradient * f.volatilityRatio;
         g_mlModel.weights[5] += learningRate * gradient * f.trendStrength;
         g_mlModel.weights[6] += learningRate * gradient * f.momentumScore;
         g_mlModel.weights[7] += learningRate * gradient * f.volumeRatio;
         g_mlModel.weights[8] += learningRate * gradient * f.pricePosition;
         g_mlModel.weights[9] += learningRate * gradient * f.timeInSession;
         
         g_mlModel.bias += learningRate * gradient;
      }
   }
   
   // Calculate accuracy
   int correct = 0;
   for(int i = 0; i < g_mlModel.historyCount; i++)
   {
      double prediction = g_mlModel.bias;
      MLFeatures f = g_mlModel.history[i].features;
      
      prediction += f.atr * g_mlModel.weights[0];
      prediction += f.spread * g_mlModel.weights[1];
      prediction += f.hourOfDay * g_mlModel.weights[2];
      prediction += f.dayOfWeek * g_mlModel.weights[3];
      prediction += f.volatilityRatio * g_mlModel.weights[4];
      prediction += f.trendStrength * g_mlModel.weights[5];
      prediction += f.momentumScore * g_mlModel.weights[6];
      prediction += f.volumeRatio * g_mlModel.weights[7];
      prediction += f.pricePosition * g_mlModel.weights[8];
      prediction += f.timeInSession * g_mlModel.weights[9];
      
      prediction = 1.0 / (1.0 + MathExp(-prediction));
      
      bool predictedWin = (prediction > 0.5);
      if(predictedWin == g_mlModel.history[i].wasWinner)
         correct++;
   }
   
   g_mlModel.accuracy = (double)correct / g_mlModel.historyCount * 100.0;
   g_mlModel.lastTraining = TimeCurrent();
   g_mlModel.trainingCount++;
   g_mlReady = true;
   
   Print("ML training complete - Accuracy: ", DoubleToString(g_mlModel.accuracy, 2), "%");
}

void LoadHistoricalTrades()
{
   // In real implementation, load from files
   // For now, we'll start fresh
   Print("ML will learn from live trades");
}

void SaveMLModel()
{
   // Save to file for persistence
   string filename = "QGS_ML_Model_" + IntegerToString(InpMagicNumber) + ".dat";
   int handle = FileOpen(filename, FILE_WRITE | FILE_BIN);
   
   if(handle != INVALID_HANDLE)
   {
      FileWriteInteger(handle, g_mlModel.historyCount);
      FileWriteDouble(handle, g_mlModel.bias);
      FileWriteDouble(handle, g_mlModel.accuracy);
      
      for(int i = 0; i < 15; i++)
         FileWriteDouble(handle, g_mlModel.weights[i]);
      
      FileClose(handle);
      Print("ML model saved to ", filename);
   }
}

void SavePerformanceData()
{
   string filename = "QGS_Performance_" + IntegerToString(InpMagicNumber) + ".csv";
   int handle = FileOpen(filename, FILE_WRITE | FILE_CSV);
   
   if(handle != INVALID_HANDLE)
   {
      FileWrite(handle, "Strategy,Trades,Wins,Losses,WinRate,Profit,Loss,Expectancy");
      
      for(int i = 0; i < g_strategyCount; i++)
      {
         FileWrite(handle, i, 
                   g_strategies[i].tradesCount,
                   g_strategies[i].wins,
                   g_strategies[i].losses,
                   DoubleToString(g_strategies[i].performance, 2),
                   DoubleToString(g_strategies[i].totalProfit, 2),
                   DoubleToString(g_strategies[i].totalLoss, 2),
                   DoubleToString(g_strategies[i].expectancy, 2));
      }
      
      FileClose(handle);
      Print("Performance data saved to ", filename);
   }
}

//=====================================================================
//  RISK MANAGEMENT
//=====================================================================
void UpdateRiskState()
{
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   
   // Update peak equity
   if(equity > g_risk.peakEquity)
      g_risk.peakEquity = equity;
   
   // Calculate drawdown
   if(g_risk.peakEquity > 0)
      g_risk.currentDrawdown = (g_risk.peakEquity - equity) / g_risk.peakEquity * 100.0;
   
   // Check limits
   if(MathAbs(g_risk.dailyProfitLoss) >= g_risk.dayStartEquity * InpMaxDailyLoss / 100.0)
   {
      g_risk.dailyLimitHit = true;
      Print("DAILY LOSS LIMIT HIT - Trading stopped for today");
   }
   
   if(g_risk.currentDrawdown >= InpMaxDrawdown)
   {
      g_risk.drawdownLimitHit = true;
      g_risk.emergencyStop = true;
      Print("MAX DRAWDOWN EXCEEDED - Emergency stop activated");
      
      // Close all positions
      CloseAllPositions();
   }
   
   // Reset daily stats
   MqlDateTime dt;
   TimeCurrent(dt);
   datetime currentDay = dt.day;
   MqlDateTime lastDt;
   TimeToStruct(g_risk.lastResetTime, lastDt);
   
   if(currentDay != lastDt.day)
   {
      g_risk.dailyProfitLoss = 0;
      g_risk.dailyTradesCount = 0;
      g_risk.dailyLimitHit = false;
      g_risk.dayStartEquity = equity;
      g_risk.lastResetTime = TimeCurrent();
      Print("Daily stats reset");
   }
}

void CloseAllPositions()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(g_position.SelectByIndex(i))
      {
         if(g_position.Magic() == InpMagicNumber && g_position.Symbol() == _Symbol)
         {
            g_trade.PositionClose(g_position.Ticket());
         }
      }
   }
   
   g_positionCount = 0;
}

//=====================================================================
//  DASHBOARD
//=====================================================================
void CreateDashboard()
{
   int x = InpDashX;
   int y = InpDashY;
   
   CreateLabel("QGS_Title", x, y, "QUANTUM GOLD SCALPER PRO v3.0", clrGold, 12);
   CreateLabel("QGS_Status", x, y + 25, "Status: ACTIVE", clrLimeGreen, 10);
   CreateLabel("QGS_Equity", x, y + 50, "Equity: $0.00", clrWhite, 9);
   CreateLabel("QGS_Profit", x, y + 70, "Day P/L: $0.00", clrWhite, 9);
   CreateLabel("QGS_Trades", x, y + 90, "Trades: 0", clrWhite, 9);
   CreateLabel("QGS_WinRate", x, y + 110, "Win Rate: 0%", clrWhite, 9);
   CreateLabel("QGS_DD", x, y + 130, "DD: 0%", clrWhite, 9);
   CreateLabel("QGS_ML", x, y + 150, "ML: LEARNING", clrYellow, 9);
   CreateLabel("QGS_Session", x, y + 170, "Session: --", clrWhite, 9);
   CreateLabel("QGS_Volatility", x, y + 190, "Volatility: --", clrWhite, 9);
}

void UpdateDashboard()
{
   if(!InpShowPanel) return;
   
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   
   UpdateLabel("QGS_Equity", "Equity: $" + DoubleToString(equity, 2), clrWhite);
   
   color plColor = (g_risk.dailyProfitLoss >= 0) ? clrLimeGreen : clrRed;
   UpdateLabel("QGS_Profit", "Day P/L: $" + DoubleToString(g_risk.dailyProfitLoss, 2), plColor);
   
   UpdateLabel("QGS_Trades", "Trades: " + IntegerToString(g_totalTrades), clrWhite);
   
   double winRate = (g_totalTrades > 0) ? (double)g_totalWins / g_totalTrades * 100.0 : 0;
   color wrColor = (winRate >= 50) ? clrLimeGreen : clrOrange;
   UpdateLabel("QGS_WinRate", "Win Rate: " + DoubleToString(winRate, 1) + "%", wrColor);
   
   color ddColor = (g_risk.currentDrawdown < 5) ? clrLimeGreen : 
                   (g_risk.currentDrawdown < 10) ? clrOrange : clrRed;
   UpdateLabel("QGS_DD", "DD: " + DoubleToString(g_risk.currentDrawdown, 2) + "%", ddColor);
   
   string mlStatus = g_mlReady ? "ACTIVE (" + DoubleToString(g_mlModel.accuracy, 1) + "%)" : "LEARNING";
   color mlColor = g_mlReady ? clrLimeGreen : clrYellow;
   UpdateLabel("QGS_ML", "ML: " + mlStatus, mlColor);
   
   string sessionStr = EnumToString(g_market.session);
   UpdateLabel("QGS_Session", "Session: " + sessionStr, clrCyan);
   
   string volStr = EnumToString(g_market.volatility);
   color volColor = (g_market.volatility == VOL_SPIKE) ? clrRed :
                    (g_market.volatility >= VOL_HIGH) ? clrOrange : clrLimeGreen;
   UpdateLabel("QGS_Volatility", "Vol: " + volStr, volColor);
}

void CreateLabel(string name, int x, int y, string text, color clr, int fontSize)
{
   ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetString(0, name, OBJPROP_TEXT, text);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, fontSize);
   ObjectSetString(0, name, OBJPROP_FONT, "Arial Bold");
}

void UpdateLabel(string name, string text, color clr)
{
   ObjectSetString(0, name, OBJPROP_TEXT, text);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
}

void DeleteDashboard()
{
   ObjectDelete(0, "QGS_Title");
   ObjectDelete(0, "QGS_Status");
   ObjectDelete(0, "QGS_Equity");
   ObjectDelete(0, "QGS_Profit");
   ObjectDelete(0, "QGS_Trades");
   ObjectDelete(0, "QGS_WinRate");
   ObjectDelete(0, "QGS_DD");
   ObjectDelete(0, "QGS_ML");
   ObjectDelete(0, "QGS_Session");
   ObjectDelete(0, "QGS_Volatility");
}

//=====================================================================
//  MAIN EVENT HANDLERS
//=====================================================================
void OnTick()
{
   // Check for new bar
   datetime currentBar = iTime(_Symbol, PERIOD_M1, 0);
   bool isNewBar = (currentBar != g_lastBarTime);
   if(isNewBar) g_lastBarTime = currentBar;
   
   // Update market state
   UpdateMarketState();
   
   // Update risk state
   UpdateRiskState();
   
   // Manage open positions (every tick for precise trailing)
   ManageOpenPositions();
   
   // Only check for new trades on new bar
   if(isNewBar)
   {
      // Adapt systems periodically
      if(InpAutoIndicatorSelect && g_totalTrades % InpAdaptivePeriod == 0 && g_totalTrades > 0)
      {
         AutoSelectIndicators();
      }
      
      if(InpAutoStrategySelect && g_totalTrades % InpAdaptivePeriod == 0 && g_totalTrades > 0)
      {
         AutoSelectStrategies();
      }
      
      // Generate signal
      int signal = GenerateSignal();
      
      // Execute trade if signal valid
      if(signal != 0)
      {
         int strategyIdx = GetBestStrategy();
         if(strategyIdx >= 0)
         {
            ExecuteTrade(signal, strategyIdx);
         }
      }
   }
}

void OnTimer()
{
   UpdateDashboard();
}