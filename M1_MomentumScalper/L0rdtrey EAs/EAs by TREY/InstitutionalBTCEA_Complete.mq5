//+------------------------------------------------------------------+
//| InstitutionalBTCEA_Complete.mq5                                 |
//| Institutional-Grade Adaptive Market Structure EA                |
//| Optimized for BTCUSD - Complete Single File Version             |
//+------------------------------------------------------------------+
#property copyright "Institutional Trading Systems"
#property link      "https://www.mql5.com"
#property version   "1.00"
#property strict
#property description "Advanced Smart Money Concept EA with Multi-Strategy Adaptive Engine"
#property description "Fully autonomous institutional-grade trading system for BTCUSD"

#include <Trade\Trade.mqh>

//+------------------------------------------------------------------+
//| ENUMERATIONS                                                     |
//+------------------------------------------------------------------+
enum ENUM_MARKET_REGIME
{
   REGIME_STRONG_BULL_TREND,      // Strong bullish trend
   REGIME_STRONG_BEAR_TREND,      // Strong bearish trend
   REGIME_WEAK_BULL_TREND,        // Weak bullish trend
   REGIME_WEAK_BEAR_TREND,        // Weak bearish trend
   REGIME_ACCUMULATION,           // Accumulation phase
   REGIME_DISTRIBUTION,           // Distribution phase
   REGIME_RANGE_BOUND,            // Range-bound market
   REGIME_HIGH_VOLATILITY,        // High volatility expansion
   REGIME_LOW_VOLATILITY,         // Low volatility compression
   REGIME_LIQUIDITY_HUNT,         // Liquidity hunting
   REGIME_SESSION_TRANSITION,     // Session transition
   REGIME_TREND_EXHAUSTION,       // Trend exhaustion
   REGIME_REVERSAL_SETUP,         // Potential reversal
   REGIME_NEWS_INSTABILITY,       // News-driven instability
   REGIME_UNDEFINED               // Cannot determine
};

enum ENUM_STRATEGY_TYPE
{
   STRATEGY_NONE,                 // No strategy active
   STRATEGY_TREND_CONTINUATION,   // Trend continuation
   STRATEGY_LIQUIDITY_REVERSAL,   // Liquidity sweep reversal
   STRATEGY_RANGE_MEAN_REVERSION, // Range mean reversion
   STRATEGY_VOLATILITY_BREAKOUT,  // Volatility breakout
   STRATEGY_MOMENTUM_SCALP,       // Momentum scalping
   STRATEGY_PULLBACK_ENTRY,       // Pullback/retracement entry
   STRATEGY_SESSION_EXPANSION,    // Session expansion
   STRATEGY_OB_REENTRY            // Order block re-entry
};

enum ENUM_TRADE_DIRECTION
{
   DIRECTION_NONE,                // No direction
   DIRECTION_LONG,                // Long/Buy
   DIRECTION_SHORT                // Short/Sell
};

enum ENUM_TRADING_SESSION
{
   SESSION_NONE,                  // No specific session
   SESSION_ASIAN,                 // Asian session
   SESSION_LONDON,                // London session
   SESSION_NEWYORK,               // New York session
   SESSION_OVERLAP_LONDON_NY      // London-NY overlap
};

enum ENUM_VOLATILITY_STATE
{
   VOLATILITY_VERY_LOW,           // Very low volatility
   VOLATILITY_LOW,                // Low volatility
   VOLATILITY_NORMAL,             // Normal volatility
   VOLATILITY_HIGH,               // High volatility
   VOLATILITY_EXTREME             // Extreme volatility
};

enum ENUM_STRUCTURE_BIAS
{
   BIAS_STRONGLY_BULLISH,         // Strongly bullish structure
   BIAS_BULLISH,                  // Bullish structure
   BIAS_NEUTRAL,                  // Neutral/undefined
   BIAS_BEARISH,                  // Bearish structure
   BIAS_STRONGLY_BEARISH          // Strongly bearish structure
};

enum ENUM_OB_TYPE
{
   OB_NONE,                       // No order block
   OB_BULLISH,                    // Bullish order block
   OB_BEARISH,                    // Bearish order block
   OB_BREAKER_BULL,               // Bullish breaker
   OB_BREAKER_BEAR,               // Bearish breaker
   OB_MITIGATION                  // Mitigation block
};

enum ENUM_FVG_TYPE
{
   FVG_NONE,                      // No FVG
   FVG_BULLISH,                   // Bullish FVG
   FVG_BEARISH,                   // Bearish FVG
   FVG_INVERSE_BULL,              // Inverse bullish FVG
   FVG_INVERSE_BEAR               // Inverse bearish FVG
};

enum ENUM_TRAILING_TYPE
{
   TRAILING_FIXED,                // Fixed pip trailing
   TRAILING_ATR,                  // ATR-based trailing
   TRAILING_STRUCTURE,            // Structure-based trailing
   TRAILING_DYNAMIC               // Dynamic adaptive trailing
};

enum ENUM_LIQUIDITY_TYPE
{
   LIQ_NONE,                      // No liquidity level
   LIQ_EQUAL_HIGHS,               // Equal highs
   LIQ_EQUAL_LOWS,                // Equal lows
   LIQ_SESSION_HIGH,              // Session high
   LIQ_SESSION_LOW,               // Session low
   LIQ_PREVIOUS_DAY_HIGH,         // Previous day high
   LIQ_PREVIOUS_DAY_LOW,          // Previous day low
   LIQ_WEEKLY_HIGH,               // Weekly high
   LIQ_WEEKLY_LOW,                // Weekly low
   LIQ_ROUND_NUMBER               // Round number
};

enum ENUM_SWEEP_DIRECTION
{
   SWEEP_NONE,                    // No sweep
   SWEEP_BUYSIDE,                 // Buy-side liquidity sweep
   SWEEP_SELLSIDE,                // Sell-side liquidity sweep
   SWEEP_BOTH                     // Both sides swept
};

//+------------------------------------------------------------------+
//| STRUCTURES                                                       |
//+------------------------------------------------------------------+
struct SOrderBlock
{
   ENUM_OB_TYPE      type;
   datetime          time;
   double            top;
   double            bottom;
   double            quality;
   int               touches;
   bool              isFresh;
   double            displacement;
   bool              hasSweep;
   ENUM_TIMEFRAMES   timeframe;
   
   SOrderBlock() : type(OB_NONE), time(0), top(0), bottom(0), quality(0), 
                   touches(0), isFresh(true), displacement(0), hasSweep(false),
                   timeframe(PERIOD_CURRENT) {}
};

struct SFairValueGap
{
   ENUM_FVG_TYPE     type;
   datetime          time;
   double            top;
   double            bottom;
   double            midpoint;
   bool              filled;
   double            fillPercent;
   ENUM_TIMEFRAMES   timeframe;
   
   SFairValueGap() : type(FVG_NONE), time(0), top(0), bottom(0), midpoint(0),
                     filled(false), fillPercent(0), timeframe(PERIOD_CURRENT) {}
};

struct SLiquidityLevel
{
   ENUM_LIQUIDITY_TYPE type;
   double            price;
   datetime          time;
   bool              swept;
   int               strength;
   int               touches;
   
   SLiquidityLevel() : type(LIQ_NONE), price(0), time(0), swept(false),
                       strength(0), touches(0) {}
};

struct SStructurePoint
{
   bool              isHigh;
   datetime          time;
   double            price;
   bool              isBroken;
   bool              isProtected;
   
   SStructurePoint() : isHigh(false), time(0), price(0), isBroken(false),
                       isProtected(false) {}
};

struct SMarketNarrative
{
   ENUM_MARKET_REGIME   regime;
   double               trendStrength;
   ENUM_VOLATILITY_STATE volatilityState;
   bool                 hasActiveBOS;
   bool                 hasCHoCH;
   SOrderBlock          latestOrderBlock;
   SFairValueGap        latestFVG;
   ENUM_STRUCTURE_BIAS  structureBias;
   SLiquidityLevel      buysideLiquidity;
   SLiquidityLevel      sellsideLiquidity;
   bool                 hasRecentSweep;
   ENUM_SWEEP_DIRECTION sweepDirection;
   ENUM_TRADE_DIRECTION htfBias;
   double               mtfAlignment;
   ENUM_STRUCTURE_BIAS  htfTrend;
   ENUM_TRADING_SESSION currentSession;
   bool                 isKillZone;
   double               currentPrice;
   double               atr;
   bool                 isInPremium;
   bool                 isInDiscount;
   double               equilibriumPrice;
   
   SMarketNarrative() : regime(REGIME_UNDEFINED), trendStrength(0), 
                        volatilityState(VOLATILITY_NORMAL), hasActiveBOS(false),
                        hasCHoCH(false), structureBias(BIAS_NEUTRAL),
                        hasRecentSweep(false), sweepDirection(SWEEP_NONE),
                        htfBias(DIRECTION_NONE), mtfAlignment(0),
                        htfTrend(BIAS_NEUTRAL), currentSession(SESSION_NONE),
                        isKillZone(false), currentPrice(0), atr(0),
                        isInPremium(false), isInDiscount(false), equilibriumPrice(0) {}
};

struct STradeSignal
{
   ENUM_STRATEGY_TYPE   strategy;
   ENUM_TRADE_DIRECTION direction;
   double               confidence;
   double               entryPrice;
   double               stopLoss;
   double               takeProfit1;
   double               takeProfit2;
   double               takeProfit3;
   double               riskRewardRatio;
   string               reason;
   
   STradeSignal() : strategy(STRATEGY_NONE), direction(DIRECTION_NONE),
                    confidence(0), entryPrice(0), stopLoss(0), takeProfit1(0),
                    takeProfit2(0), takeProfit3(0), riskRewardRatio(0), reason("") {}
};

struct STradeRequest
{
   ENUM_STRATEGY_TYPE   strategy;
   ENUM_TRADE_DIRECTION direction;
   double               confidence;
   double               entryPrice;
   double               stopLoss;
   double               takeProfit1;
   double               takeProfit2;
   double               takeProfit3;
   double               riskRewardRatio;
   double               lotSize;
   
   STradeRequest() : strategy(STRATEGY_NONE), direction(DIRECTION_NONE),
                     confidence(0), entryPrice(0), stopLoss(0), takeProfit1(0),
                     takeProfit2(0), takeProfit3(0), riskRewardRatio(0), lotSize(0) {}
};

struct SPerformanceMetrics
{
   int      totalTrades;
   int      winningTrades;
   int      losingTrades;
   double   winRate;
   double   grossProfit;
   double   grossLoss;
   double   netProfit;
   double   profitFactor;
   double   expectancy;
   double   maxDrawdown;
   int      consecutiveWins;
   int      consecutiveLosses;
   int      maxConsecutiveLosses;
   double   dailyProfit;
   int      dailyTrades;
   
   SPerformanceMetrics() : totalTrades(0), winningTrades(0), losingTrades(0),
                           winRate(0), grossProfit(0), grossLoss(0), netProfit(0),
                           profitFactor(0), expectancy(0), maxDrawdown(0), 
                           consecutiveWins(0), consecutiveLosses(0), 
                           maxConsecutiveLosses(0), dailyProfit(0), dailyTrades(0) {}
};

struct SDecisionWeights
{
   int marketRegime;
   int htfBias;
   int liquidity;
   int structure;
   int orderBlock;
   int fvg;
   int momentum;
   int session;
   int volatility;
   
   SDecisionWeights() : marketRegime(20), htfBias(15), liquidity(15),
                        structure(15), orderBlock(10), fvg(5), momentum(10),
                        session(5), volatility(5) {}
};

//+------------------------------------------------------------------+
//| INPUT PARAMETERS                                                 |
//+------------------------------------------------------------------+
input group "═══════════ CORE SETTINGS ═══════════"
input int      InpMagicNumber        = 100001;     // Magic Number
input double   InpRiskPercent        = 1.0;        // Risk Per Trade (%)
input double   InpMaxLotSize         = 10.0;       // Maximum Lot Size
input double   InpMinRR              = 2.0;        // Minimum Risk:Reward Ratio

input group "═══════════ MARKET REGIME ═══════════"
input bool     InpEnableRegimeFilter = true;       // Enable Regime Detection
input int      InpRegimePeriod       = 100;        // Regime Analysis Period
input double   InpTrendThreshold     = 0.6;        // Trend Strength Threshold (0-1)
input int      InpVolatilityPeriod   = 20;         // Volatility Period (ATR)

input group "═══════════ SMART MONEY CONCEPTS ═══════════"
input bool     InpRequireBOS         = true;       // Require Break of Structure
input bool     InpRequireOB          = true;       // Require Order Block
input bool     InpRequireFVG         = false;      // Require Fair Value Gap
input double   InpOBMinQuality       = 60.0;       // Minimum Order Block Quality (0-100)
input int      InpSwingStrength      = 5;          // Swing Detection Strength
input int      InpStructurePeriod    = 50;         // Market Structure Period

input group "═══════════ LIQUIDITY TARGETING ═══════════"
input bool     InpRequireLiqSweep    = true;       // Require Liquidity Sweep
input int      InpEqualLevelPips     = 20;         // Equal High/Low Tolerance (pips)
input bool     InpTrackSessionLiq    = true;       // Track Session Liquidity

input group "═══════════ MULTI-TIMEFRAME ═══════════"
input bool     InpUseMTF             = true;       // Use Multi-Timeframe Analysis
input ENUM_TIMEFRAMES InpHTF1        = PERIOD_D1;  // Higher Timeframe 1
input ENUM_TIMEFRAMES InpHTF2        = PERIOD_H4;  // Higher Timeframe 2
input ENUM_TIMEFRAMES InpHTF3        = PERIOD_H1;  // Higher Timeframe 3
input double   InpMTFAlignmentReq    = 70.0;       // MTF Alignment Required (%)

input group "═══════════ DECISION ENGINE ═══════════"
input double   InpMinConfidence      = 70.0;       // Minimum Trade Confidence (%)
input int      InpWeightRegime       = 20;         // Weight: Market Regime
input int      InpWeightHTF          = 15;         // Weight: HTF Bias
input int      InpWeightLiquidity    = 15;         // Weight: Liquidity
input int      InpWeightStructure    = 15;         // Weight: Market Structure
input int      InpWeightOB           = 10;         // Weight: Order Block
input int      InpWeightFVG          = 5;          // Weight: FVG
input int      InpWeightMomentum     = 10;         // Weight: Momentum
input int      InpWeightSession      = 5;          // Weight: Session
input int      InpWeightVolatility   = 5;          // Weight: Volatility

input group "═══════════ STRATEGY SELECTION ═══════════"
input bool     InpEnableTrendCont    = true;       // Enable: Trend Continuation
input bool     InpEnableLiqReversal  = true;       // Enable: Liquidity Reversal
input bool     InpEnableRangeMean    = true;       // Enable: Range Mean Reversion
input bool     InpEnableVolBreakout  = true;       // Enable: Volatility Breakout
input bool     InpEnablePullback     = true;       // Enable: Pullback Entry
input bool     InpEnableOBReentry    = true;       // Enable: Order Block Re-entry

input group "═══════════ TRADE MANAGEMENT ═══════════"
input bool     InpUsePartialTP       = true;       // Use Partial Take Profit
input double   InpPartial1Percent    = 30.0;       // First Partial (%)
input double   InpPartial1RR         = 1.5;        // First Partial RR
input double   InpPartial2Percent    = 30.0;       // Second Partial (%)
input double   InpPartial2RR         = 2.5;        // Second Partial RR
input bool     InpUseBreakeven       = true;       // Move to Breakeven
input double   InpBreakevenRR        = 1.0;        // Breakeven RR Trigger
input bool     InpUseTrailing        = true;       // Use Trailing Stop
input ENUM_TRAILING_TYPE InpTrailingType = TRAILING_ATR; // Trailing Type
input double   InpTrailingStart      = 2.0;        // Trailing Start (RR)
input double   InpTrailingDistance   = 1.5;        // Trailing Distance (ATR multiplier)

input group "═══════════ RISK MANAGEMENT ═══════════"
input double   InpMaxDailyLoss       = 3.0;        // Max Daily Loss (%)
input double   InpMaxDailyProfit     = 10.0;       // Max Daily Profit Target (%)
input int      InpMaxConsecLosses    = 3;          // Max Consecutive Losses
input int      InpMaxDailyTrades     = 10;         // Max Daily Trades
input double   InpMaxSpreadPips      = 50.0;       // Max Spread (pips)
input int      InpMinTimeBetween     = 30;         // Min Minutes Between Trades

input group "═══════════ SESSION FILTERS ═══════════"
input bool     InpTradeAsian         = true;       // Trade Asian Session
input bool     InpTradeLondon        = true;       // Trade London Session
input bool     InpTradeNY            = true;       // Trade New York Session
input bool     InpAvoidWeekend       = true;       // Avoid Weekend Trading

input group "═══════════ DASHBOARD ═══════════"
input bool     InpShowDashboard      = true;       // Show Dashboard
input ENUM_BASE_CORNER InpDashCorner = CORNER_LEFT_UPPER; // Dashboard Corner
input int      InpDashFontSize       = 9;          // Dashboard Font Size
input color    InpDashColorBull      = clrLime;    // Bullish Color
input color    InpDashColorBear      = clrRed;     // Bearish Color
input color    InpDashColorNeutral   = clrGray;    // Neutral Color

//+------------------------------------------------------------------+
//| GLOBAL VARIABLES                                                 |
//+------------------------------------------------------------------+
// Indicator handles
int g_atrHandle = INVALID_HANDLE;
int g_adxHandle = INVALID_HANDLE;
int g_emaFast = INVALID_HANDLE;
int g_emaSlow = INVALID_HANDLE;
int g_ema20_HTF1 = INVALID_HANDLE;
int g_ema50_HTF1 = INVALID_HANDLE;
int g_ema20_HTF2 = INVALID_HANDLE;
int g_ema50_HTF2 = INVALID_HANDLE;
int g_ema20_HTF3 = INVALID_HANDLE;
int g_ema50_HTF3 = INVALID_HANDLE;

// Market state
ENUM_MARKET_REGIME g_currentRegime = REGIME_UNDEFINED;
ENUM_VOLATILITY_STATE g_volatilityState = VOLATILITY_NORMAL;
double g_trendStrength = 0;
double g_atr = 0;

// Smart Money Concepts
SStructurePoint g_swingHighs[];
SStructurePoint g_swingLows[];
bool g_hasActiveBOS = false;
bool g_hasCHoCH = false;
ENUM_STRUCTURE_BIAS g_structureBias = BIAS_NEUTRAL;
SOrderBlock g_orderBlocks[];
SOrderBlock g_latestOB;
SFairValueGap g_fvgs[];
SFairValueGap g_latestFVG;
double g_equilibrium = 0;

// Liquidity
SLiquidityLevel g_liquidityLevels[];
SLiquidityLevel g_buysideLiq;
SLiquidityLevel g_sellsideLiq;
bool g_recentSweep = false;
ENUM_SWEEP_DIRECTION g_lastSweepDir = SWEEP_NONE;
datetime g_lastSweepTime = 0;

// Multi-timeframe
ENUM_TRADE_DIRECTION g_htfBias = DIRECTION_NONE;
double g_mtfAlignment = 0;
ENUM_STRUCTURE_BIAS g_htfTrend = BIAS_NEUTRAL;

// Decision engine
SDecisionWeights g_weights;

// Trade management
CTrade g_trade;
SPerformanceMetrics g_metrics;
datetime g_lastTradeTime = 0;
datetime g_lastBarTime = 0;

// Strategy flags
bool g_enabledStrategies[8];

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   Print("═══════════════════════════════════════════════════════");
   Print("  INSTITUTIONAL BTCUSD EA - Initialization Started");
   Print("═══════════════════════════════════════════════════════");
   
   // Validate symbol
   if(_Symbol != "BTCUSD" && StringFind(_Symbol, "BTC") == -1)
   {
      Alert("WARNING: This EA is optimized for BTCUSD. Current symbol: ", _Symbol);
   }
   
   // Apply institutional chart theme
   ChartSetInteger(0, CHART_COLOR_BACKGROUND, clrBlack);
   ChartSetInteger(0, CHART_COLOR_FOREGROUND, clrWhite);
   ChartSetInteger(0, CHART_COLOR_GRID, C'30,30,30');
   ChartSetInteger(0, CHART_COLOR_CHART_UP, clrLime);
   ChartSetInteger(0, CHART_COLOR_CHART_DOWN, clrRed);
   ChartSetInteger(0, CHART_COLOR_CANDLE_BULL, clrLime);
   ChartSetInteger(0, CHART_COLOR_CANDLE_BEAR, clrRed);
   ChartSetInteger(0, CHART_SHOW_GRID, true);
   
   // Initialize indicators
   g_atrHandle = iATR(_Symbol, PERIOD_CURRENT, InpVolatilityPeriod);
   g_adxHandle = iADX(_Symbol, PERIOD_CURRENT, 14);
   g_emaFast = iMA(_Symbol, PERIOD_CURRENT, 20, 0, MODE_EMA, PRICE_CLOSE);
   g_emaSlow = iMA(_Symbol, PERIOD_CURRENT, 50, 0, MODE_EMA, PRICE_CLOSE);
   
   if(g_atrHandle == INVALID_HANDLE || g_adxHandle == INVALID_HANDLE ||
      g_emaFast == INVALID_HANDLE || g_emaSlow == INVALID_HANDLE)
   {
      Print("ERROR: Failed to create core indicators");
      return INIT_FAILED;
   }
   
   // Initialize MTF indicators
   if(InpUseMTF)
   {
      g_ema20_HTF1 = iMA(_Symbol, InpHTF1, 20, 0, MODE_EMA, PRICE_CLOSE);
      g_ema50_HTF1 = iMA(_Symbol, InpHTF1, 50, 0, MODE_EMA, PRICE_CLOSE);
      g_ema20_HTF2 = iMA(_Symbol, InpHTF2, 20, 0, MODE_EMA, PRICE_CLOSE);
      g_ema50_HTF2 = iMA(_Symbol, InpHTF2, 50, 0, MODE_EMA, PRICE_CLOSE);
      g_ema20_HTF3 = iMA(_Symbol, InpHTF3, 20, 0, MODE_EMA, PRICE_CLOSE);
      g_ema50_HTF3 = iMA(_Symbol, InpHTF3, 50, 0, MODE_EMA, PRICE_CLOSE);
      
      if(g_ema20_HTF1 == INVALID_HANDLE || g_ema50_HTF1 == INVALID_HANDLE ||
         g_ema20_HTF2 == INVALID_HANDLE || g_ema50_HTF2 == INVALID_HANDLE ||
         g_ema20_HTF3 == INVALID_HANDLE || g_ema50_HTF3 == INVALID_HANDLE)
      {
         Print("ERROR: Failed to create MTF indicators");
         return INIT_FAILED;
      }
   }
   
   // Initialize arrays
   ArrayResize(g_swingHighs, 0);
   ArrayResize(g_swingLows, 0);
   ArrayResize(g_orderBlocks, 0);
   ArrayResize(g_fvgs, 0);
   ArrayResize(g_liquidityLevels, 0);
   
   // Configure trade object
   g_trade.SetExpertMagicNumber(InpMagicNumber);
   g_trade.SetDeviationInPoints(50);
   g_trade.SetTypeFilling(ORDER_FILLING_FOK);
   
   // Set decision weights
   g_weights.marketRegime = InpWeightRegime;
   g_weights.htfBias = InpWeightHTF;
   g_weights.liquidity = InpWeightLiquidity;
   g_weights.structure = InpWeightStructure;
   g_weights.orderBlock = InpWeightOB;
   g_weights.fvg = InpWeightFVG;
   g_weights.momentum = InpWeightMomentum;
   g_weights.session = InpWeightSession;
   g_weights.volatility = InpWeightVolatility;
   
   // Validate weights
   int totalWeight = InpWeightRegime + InpWeightHTF + InpWeightLiquidity + InpWeightStructure +
                     InpWeightOB + InpWeightFVG + InpWeightMomentum + InpWeightSession + InpWeightVolatility;
   if(totalWeight != 100)
   {
      Print("ERROR: Decision weights must sum to 100. Current: ", totalWeight);
      return INIT_FAILED;
   }
   
   // Enable strategies
   ArrayInitialize(g_enabledStrategies, false);
   g_enabledStrategies[STRATEGY_TREND_CONTINUATION] = InpEnableTrendCont;
   g_enabledStrategies[STRATEGY_LIQUIDITY_REVERSAL] = InpEnableLiqReversal;
   g_enabledStrategies[STRATEGY_RANGE_MEAN_REVERSION] = InpEnableRangeMean;
   g_enabledStrategies[STRATEGY_VOLATILITY_BREAKOUT] = InpEnableVolBreakout;
   g_enabledStrategies[STRATEGY_PULLBACK_ENTRY] = InpEnablePullback;
   g_enabledStrategies[STRATEGY_OB_REENTRY] = InpEnableOBReentry;
   
   // Set timer
   EventSetTimer(1);
   
   Print("═══════════════════════════════════════════════════════");
   Print("  INSTITUTIONAL BTCUSD EA - Initialization Complete");
   Print("  Magic Number: ", InpMagicNumber);
   Print("  Risk Per Trade: ", InpRiskPercent, "%");
   Print("  Minimum Confidence: ", InpMinConfidence, "%");
   Print("  Minimum R:R: ", InpMinRR);
   Print("═══════════════════════════════════════════════════════");
   
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   Print("═══════════════════════════════════════════════════════");
   Print("  INSTITUTIONAL BTCUSD EA - Shutdown");
   Print("  Reason: ", GetDeinitReasonText(reason));
   Print("═══════════════════════════════════════════════════════");
   
   // Release indicators
   if(g_atrHandle != INVALID_HANDLE) IndicatorRelease(g_atrHandle);
   if(g_adxHandle != INVALID_HANDLE) IndicatorRelease(g_adxHandle);
   if(g_emaFast != INVALID_HANDLE) IndicatorRelease(g_emaFast);
   if(g_emaSlow != INVALID_HANDLE) IndicatorRelease(g_emaSlow);
   if(g_ema20_HTF1 != INVALID_HANDLE) IndicatorRelease(g_ema20_HTF1);
   if(g_ema50_HTF1 != INVALID_HANDLE) IndicatorRelease(g_ema50_HTF1);
   if(g_ema20_HTF2 != INVALID_HANDLE) IndicatorRelease(g_ema20_HTF2);
   if(g_ema50_HTF2 != INVALID_HANDLE) IndicatorRelease(g_ema50_HTF2);
   if(g_ema20_HTF3 != INVALID_HANDLE) IndicatorRelease(g_ema20_HTF3);
   if(g_ema50_HTF3 != INVALID_HANDLE) IndicatorRelease(g_ema50_HTF3);
   
   EventKillTimer();
   Comment("");
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   // Monitor existing positions
   MonitorPositions();
   
   // Update dashboard
   if(InpShowDashboard)
      UpdateDashboard();
   
   // Check for new bar
   if(!IsNewBar()) return;
   
   // Update all analytical engines
   UpdateMarketRegime();
   UpdateSmartMoneyConcepts();
   UpdateLiquidity();
   UpdateMultiTimeframe();
   
   // Check risk limits
   if(!CheckRiskLimits()) return;
   
   // Evaluate trading opportunity
   EvaluateTradingOpportunity();
}

//+------------------------------------------------------------------+
//| Timer function                                                   |
//+------------------------------------------------------------------+
void OnTimer()
{
   if(InpShowDashboard)
      UpdateDashboard();
}

//+------------------------------------------------------------------+
//| Check for new bar                                                |
//+------------------------------------------------------------------+
bool IsNewBar()
{
   datetime currentBarTime = iTime(_Symbol, PERIOD_CURRENT, 0);
   if(currentBarTime != g_lastBarTime)
   {
      g_lastBarTime = currentBarTime;
      return true;
   }
   return false;
}

//+------------------------------------------------------------------+
//| Update Market Regime                                             |
//+------------------------------------------------------------------+
void UpdateMarketRegime()
{
   // Get ATR
   double atrBuffer[];
   ArraySetAsSeries(atrBuffer, true);
   if(CopyBuffer(g_atrHandle, 0, 0, 1, atrBuffer) > 0)
      g_atr = atrBuffer[0];
   
   // Calculate trend strength
   double adx = GetIndicatorValue(g_adxHandle, 0, 0);
   g_trendStrength = MathMin(adx / 100.0, 1.0);
   
   // Determine volatility state
   double atrValues[];
   ArraySetAsSeries(atrValues, true);
   if(CopyBuffer(g_atrHandle, 0, 0, InpRegimePeriod, atrValues) > 0)
   {
      double avgATR = 0;
      for(int i = 0; i < InpRegimePeriod; i++)
         avgATR += atrValues[i];
      avgATR /= InpRegimePeriod;
      
      if(avgATR > 0)
      {
         double ratio = g_atr / avgATR;
         if(ratio > 2.0) g_volatilityState = VOLATILITY_EXTREME;
         else if(ratio > 1.5) g_volatilityState = VOLATILITY_HIGH;
         else if(ratio > 0.5) g_volatilityState = VOLATILITY_NORMAL;
         else if(ratio > 0.3) g_volatilityState = VOLATILITY_LOW;
         else g_volatilityState = VOLATILITY_VERY_LOW;
      }
   }
   
   // Detect regime
   double emaFastVal = GetIndicatorValue(g_emaFast, 0, 0);
   double emaSlowVal = GetIndicatorValue(g_emaSlow, 0, 0);
   double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   
   bool bullishTrend = (emaFastVal > emaSlowVal);
   bool bearishTrend = (emaFastVal < emaSlowVal);
   bool priceAboveEMAs = (currentPrice > emaFastVal && currentPrice > emaSlowVal);
   bool priceBelowEMAs = (currentPrice < emaFastVal && currentPrice < emaSlowVal);
   
   ENUM_MARKET_REGIME newRegime = REGIME_UNDEFINED;
   
   if(adx > 25 && g_trendStrength > InpTrendThreshold)
   {
      if(bullishTrend && priceAboveEMAs)
         newRegime = REGIME_STRONG_BULL_TREND;
      else if(bearishTrend && priceBelowEMAs)
         newRegime = REGIME_STRONG_BEAR_TREND;
   }
   else if(adx > 20 && adx <= 25)
   {
      if(bullishTrend) newRegime = REGIME_WEAK_BULL_TREND;
      else if(bearishTrend) newRegime = REGIME_WEAK_BEAR_TREND;
   }
   else if(adx < 20)
   {
      newRegime = REGIME_RANGE_BOUND;
   }
   
   if(g_volatilityState == VOLATILITY_EXTREME)
      newRegime = REGIME_HIGH_VOLATILITY;
   else if(g_volatilityState == VOLATILITY_VERY_LOW)
      newRegime = REGIME_LOW_VOLATILITY;
   
   if(newRegime != g_currentRegime)
   {
      Print("REGIME CHANGE: ", EnumToString(g_currentRegime), " -> ", EnumToString(newRegime));
      g_currentRegime = newRegime;
   }
}

//+------------------------------------------------------------------+
//| Update Smart Money Concepts                                      |
//+------------------------------------------------------------------+
void UpdateSmartMoneyConcepts()
{
   // Detect swing points
   for(int i = InpSwingStrength; i < InpStructurePeriod; i++)
   {
      if(IsSwingHigh(i, InpSwingStrength))
      {
         datetime time = iTime(_Symbol, PERIOD_CURRENT, i);
         double price = iHigh(_Symbol, PERIOD_CURRENT, i);
         AddSwingHigh(time, price);
      }
      
      if(IsSwingLow(i, InpSwingStrength))
      {
         datetime time = iTime(_Symbol, PERIOD_CURRENT, i);
         double price = iLow(_Symbol, PERIOD_CURRENT, i);
         AddSwingLow(time, price);
      }
   }
   
   // Detect market structure
   double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   g_hasActiveBOS = false;
   g_hasCHoCH = false;
   
   if(ArraySize(g_swingHighs) > 0)
   {
      SStructurePoint lastHigh = g_swingHighs[ArraySize(g_swingHighs) - 1];
      if(!lastHigh.isBroken && currentPrice > lastHigh.price)
      {
         g_hasActiveBOS = true;
         if(g_structureBias == BIAS_BEARISH || g_structureBias == BIAS_STRONGLY_BEARISH)
         {
            g_hasCHoCH = true;
            g_structureBias = BIAS_BULLISH;
         }
         else
         {
            g_structureBias = BIAS_STRONGLY_BULLISH;
         }
      }
   }
   
   if(ArraySize(g_swingLows) > 0)
   {
      SStructurePoint lastLow = g_swingLows[ArraySize(g_swingLows) - 1];
      if(!lastLow.isBroken && currentPrice < lastLow.price)
      {
         g_hasActiveBOS = true;
         if(g_structureBias == BIAS_BULLISH || g_structureBias == BIAS_STRONGLY_BULLISH)
         {
            g_hasCHoCH = true;
            g_structureBias = BIAS_BEARISH;
         }
         else
         {
            g_structureBias = BIAS_STRONGLY_BEARISH;
         }
      }
   }
   
   // Detect order blocks
   DetectOrderBlocks();
   
   // Detect FVGs
   DetectFairValueGaps();
   
   // Update premium/discount zones
   UpdatePremiumDiscount();
}

//+------------------------------------------------------------------+
//| Update Liquidity                                                 |
//+------------------------------------------------------------------+
void UpdateLiquidity()
{
   DetectLiquidityLevels();
   CheckLiquiditySweeps();
   UpdateNearestLiquidity();
}

//+------------------------------------------------------------------+
//| Update Multi-Timeframe Analysis                                  |
//+------------------------------------------------------------------+
void UpdateMultiTimeframe()
{
   if(!InpUseMTF) return;
   
   ENUM_TRADE_DIRECTION htf1Bias = AnalyzeTimeframe(InpHTF1, g_ema20_HTF1, g_ema50_HTF1);
   ENUM_TRADE_DIRECTION htf2Bias = AnalyzeTimeframe(InpHTF2, g_ema20_HTF2, g_ema50_HTF2);
   ENUM_TRADE_DIRECTION htf3Bias = AnalyzeTimeframe(InpHTF3, g_ema20_HTF3, g_ema50_HTF3);
   
   int bullishCount = 0;
   int bearishCount = 0;
   
   if(htf1Bias == DIRECTION_LONG) bullishCount++;
   if(htf1Bias == DIRECTION_SHORT) bearishCount++;
   if(htf2Bias == DIRECTION_LONG) bullishCount++;
   if(htf2Bias == DIRECTION_SHORT) bearishCount++;
   if(htf3Bias == DIRECTION_LONG) bullishCount++;
   if(htf3Bias == DIRECTION_SHORT) bearishCount++;
   
   if(bullishCount > bearishCount)
   {
      g_htfBias = DIRECTION_LONG;
      g_mtfAlignment = (bullishCount * 100.0) / 3;
      g_htfTrend = (bullishCount == 3) ? BIAS_STRONGLY_BULLISH : BIAS_BULLISH;
   }
   else if(bearishCount > bullishCount)
   {
      g_htfBias = DIRECTION_SHORT;
      g_mtfAlignment = (bearishCount * 100.0) / 3;
      g_htfTrend = (bearishCount == 3) ? BIAS_STRONGLY_BEARISH : BIAS_BEARISH;
   }
   else
   {
      g_htfBias = DIRECTION_NONE;
      g_mtfAlignment = 0;
      g_htfTrend = BIAS_NEUTRAL;
   }
}

//+------------------------------------------------------------------+
//| Evaluate Trading Opportunity                                     |
//+------------------------------------------------------------------+
void EvaluateTradingOpportunity()
{
   // Get active strategy for current regime
   ENUM_STRATEGY_TYPE activeStrategy = GetActiveStrategy(g_currentRegime);
   if(activeStrategy == STRATEGY_NONE)
   {
      return;
   }
   
   // Build market narrative
   SMarketNarrative narrative;
   BuildMarketNarrative(narrative);
   
   // Evaluate signal
   STradeSignal signal = EvaluateSignal(narrative, activeStrategy);
   
   if(signal.confidence < InpMinConfidence)
   {
      return;
   }
   
   if(signal.riskRewardRatio < InpMinRR)
   {
      Print("Signal rejected: R:R ", DoubleToString(signal.riskRewardRatio, 2), " < ", InpMinRR);
      return;
   }
   
   // Execute trade
   ExecuteTrade(signal, narrative);
}

//+------------------------------------------------------------------+
//| Build Market Narrative                                           |
//+------------------------------------------------------------------+
void BuildMarketNarrative(SMarketNarrative &narrative)
{
   narrative.regime = g_currentRegime;
   narrative.trendStrength = g_trendStrength;
   narrative.volatilityState = g_volatilityState;
   narrative.hasActiveBOS = g_hasActiveBOS;
   narrative.hasCHoCH = g_hasCHoCH;
   narrative.latestOrderBlock = g_latestOB;
   narrative.latestFVG = g_latestFVG;
   narrative.structureBias = g_structureBias;
   narrative.buysideLiquidity = g_buysideLiq;
   narrative.sellsideLiquidity = g_sellsideLiq;
   narrative.hasRecentSweep = g_recentSweep;
   narrative.sweepDirection = g_lastSweepDir;
   narrative.htfBias = g_htfBias;
   narrative.mtfAlignment = g_mtfAlignment;
   narrative.htfTrend = g_htfTrend;
   narrative.currentSession = GetCurrentSession();
   narrative.isKillZone = IsKillZone();
   narrative.currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   narrative.atr = g_atr;
   narrative.isInPremium = (narrative.currentPrice > g_equilibrium);
   narrative.isInDiscount = (narrative.currentPrice < g_equilibrium);
   narrative.equilibriumPrice = g_equilibrium;
}

//+------------------------------------------------------------------+
//| Evaluate Trade Signal                                            |
//+------------------------------------------------------------------+
STradeSignal EvaluateSignal(const SMarketNarrative &narrative, ENUM_STRATEGY_TYPE strategy)
{
   STradeSignal signal;
   signal.strategy = strategy;
   
   // Determine direction
   signal.direction = DetermineDirection(narrative, strategy);
   if(signal.direction == DIRECTION_NONE)
   {
      signal.confidence = 0;
      return signal;
   }
   
   // Calculate weighted confidence
   double totalScore = 0;
   
   totalScore += ScoreMarketRegime(narrative, strategy) * (g_weights.marketRegime / 100.0);
   totalScore += ScoreHTFBias(narrative, signal.direction) * (g_weights.htfBias / 100.0);
   totalScore += ScoreLiquidity(narrative, signal.direction) * (g_weights.liquidity / 100.0);
   totalScore += ScoreStructure(narrative, signal.direction) * (g_weights.structure / 100.0);
   totalScore += ScoreOrderBlock(narrative, signal.direction) * (g_weights.orderBlock / 100.0);
   totalScore += ScoreFVG(narrative, signal.direction) * (g_weights.fvg / 100.0);
   totalScore += ScoreMomentum(narrative, signal.direction) * (g_weights.momentum / 100.0);
   totalScore += ScoreSession(narrative) * (g_weights.session / 100.0);
   totalScore += ScoreVolatility(narrative, strategy) * (g_weights.volatility / 100.0);
   
   signal.confidence = totalScore;
   
   // Calculate entry and targets
   CalculateEntryAndTargets(signal, narrative);
   
   // Build reason
   signal.reason = "Regime: " + EnumToString(narrative.regime) + " | HTF: " + EnumToString(narrative.htfBias);
   
   return signal;
}

//+------------------------------------------------------------------+
//| Execute Trade                                                    |
//+------------------------------------------------------------------+
void ExecuteTrade(const STradeSignal &signal, const SMarketNarrative &narrative)
{
   double lotSize = CalculateLotSize(signal.stopLoss, signal.entryPrice);
   if(lotSize == 0) return;
   
   ENUM_ORDER_TYPE orderType = (signal.direction == DIRECTION_LONG) ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
   
   bool success = g_trade.PositionOpen(_Symbol, orderType, lotSize,
                                       signal.entryPrice, signal.stopLoss,
                                       signal.takeProfit1, EnumToString(signal.strategy));
   
   if(success)
   {
      Print("═══════════════════════════════════════════════════════");
      Print("  TRADE EXECUTED");
      Print("  Strategy: ", EnumToString(signal.strategy));
      Print("  Direction: ", EnumToString(signal.direction));
      Print("  Confidence: ", DoubleToString(signal.confidence, 1), "%");
      Print("  Entry: ", DoubleToString(signal.entryPrice, _Digits));
      Print("  SL: ", DoubleToString(signal.stopLoss, _Digits));
      Print("  TP: ", DoubleToString(signal.takeProfit1, _Digits));
      Print("  Lot: ", DoubleToString(lotSize, 2));
      Print("  R:R: ", DoubleToString(signal.riskRewardRatio, 2));
      Print("═══════════════════════════════════════════════════════");
      
      g_lastTradeTime = TimeCurrent();
      g_metrics.dailyTrades++;
      g_metrics.totalTrades++;
   }
   else
   {
      Print("TRADE EXECUTION FAILED: ", g_trade.ResultRetcodeDescription());
   }
}

//+------------------------------------------------------------------+
//| Monitor Positions                                                |
//+------------------------------------------------------------------+
void MonitorPositions()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(PositionSelectByTicket(PositionGetTicket(i)))
      {
         if(PositionGetInteger(POSITION_MAGIC) != InpMagicNumber) continue;
         if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
         
         ulong ticket = PositionGetInteger(POSITION_TICKET);
         double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
         double currentSL = PositionGetDouble(POSITION_SL);
         double currentTP = PositionGetDouble(POSITION_TP);
         ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
         
         double currentPrice = (posType == POSITION_TYPE_BUY) ? 
                               SymbolInfoDouble(_Symbol, SYMBOL_BID) : 
                               SymbolInfoDouble(_Symbol, SYMBOL_ASK);
         
         double riskDistance = MathAbs(openPrice - currentSL);
         double currentProfit = MathAbs(currentPrice - openPrice);
         double currentRR = (riskDistance > 0) ? (currentProfit / riskDistance) : 0;
         
         // Breakeven logic
         if(InpUseBreakeven && currentRR >= InpBreakevenRR)
         {
            if((posType == POSITION_TYPE_BUY && currentSL < openPrice) ||
               (posType == POSITION_TYPE_SELL && currentSL > openPrice))
            {
               g_trade.PositionModify(ticket, openPrice, currentTP);
               Print("Position ", ticket, " moved to breakeven");
            }
         }
         
         // Trailing stop logic
         if(InpUseTrailing && currentRR >= InpTrailingStart)
         {
            double trailDistance = g_atr * InpTrailingDistance;
            double newSL = 0;
            
            if(posType == POSITION_TYPE_BUY)
            {
               newSL = currentPrice - trailDistance;
               if(newSL > currentSL)
               {
                  g_trade.PositionModify(ticket, newSL, currentTP);
                  Print("BUY position ", ticket, " trailing SL updated to ", newSL);
               }
            }
            else
            {
               newSL = currentPrice + trailDistance;
               if(newSL < currentSL || currentSL == 0)
               {
                  g_trade.PositionModify(ticket, newSL, currentTP);
                  Print("SELL position ", ticket, " trailing SL updated to ", newSL);
               }
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Check Risk Limits                                                |
//+------------------------------------------------------------------+
bool CheckRiskLimits()
{
   // Check daily trade limit
   if(g_metrics.dailyTrades >= InpMaxDailyTrades)
   {
      return false;
   }
   
   // Check consecutive losses
   if(g_metrics.consecutiveLosses >= InpMaxConsecLosses)
   {
      return false;
   }
   
   // Check time between trades
   if(TimeCurrent() - g_lastTradeTime < InpMinTimeBetween * 60)
   {
      return false;
   }
   
   // Check spread
   long spreadPoints = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   double spreadPips = spreadPoints * SymbolInfoDouble(_Symbol, SYMBOL_POINT) / GetPipSize();
   if(spreadPips > InpMaxSpreadPips)
   {
      return false;
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| Update Dashboard                                                 |
//+------------------------------------------------------------------+
void UpdateDashboard()
{
   string dashboard = "\n";
   dashboard += "╔════════════════════════════════════════╗\n";
   dashboard += "║  INSTITUTIONAL BTCUSD EA - LIVE       ║\n";
   dashboard += "╚════════════════════════════════════════╝\n\n";
   
   dashboard += "MARKET REGIME\n";
   dashboard += "Current: " + EnumToString(g_currentRegime) + "\n";
   dashboard += "Trend Strength: " + DoubleToString(g_trendStrength * 100, 1) + "%\n";
   dashboard += "Volatility: " + EnumToString(g_volatilityState) + "\n";
   dashboard += "ATR: " + DoubleToString(g_atr, 2) + "\n\n";
   
   dashboard += "MARKET STRUCTURE\n";
   dashboard += "BOS: " + (g_hasActiveBOS ? "✓ Active" : "✗ None") + "\n";
   dashboard += "CHoCH: " + (g_hasCHoCH ? "✓ Detected" : "✗ None") + "\n";
   dashboard += "Bias: " + EnumToString(g_structureBias) + "\n";
   dashboard += "OB Quality: " + DoubleToString(g_latestOB.quality, 0) + "%\n\n";
   
   dashboard += "LIQUIDITY\n";
   dashboard += "Recent Sweep: " + (g_recentSweep ? EnumToString(g_lastSweepDir) : "None") + "\n";
   dashboard += "Buy-side: " + DoubleToString(g_buysideLiq.price, 2) + "\n";
   dashboard += "Sell-side: " + DoubleToString(g_sellsideLiq.price, 2) + "\n\n";
   
   dashboard += "MULTI-TIMEFRAME\n";
   dashboard += "HTF Bias: " + EnumToString(g_htfBias) + "\n";
   dashboard += "Alignment: " + DoubleToString(g_mtfAlignment, 0) + "%\n\n";
   
   dashboard += "PERFORMANCE\n";
   dashboard += "Total Trades: " + IntegerToString(g_metrics.totalTrades) + "\n";
   dashboard += "Daily Trades: " + IntegerToString(g_metrics.dailyTrades) + "\n";
   dashboard += "Win Rate: " + DoubleToString(g_metrics.winRate, 1) + "%\n";
   dashboard += "Profit Factor: " + DoubleToString(g_metrics.profitFactor, 2) + "\n";
   dashboard += "Active Positions: " + IntegerToString(PositionsTotal()) + "\n\n";
   
   dashboard += "SESSION\n";
   dashboard += "Current: " + EnumToString(GetCurrentSession()) + "\n";
   dashboard += "Kill Zone: " + (IsKillZone() ? "✓ YES" : "✗ NO") + "\n";
   
   Comment(dashboard);
}

//+------------------------------------------------------------------+
//| HELPER FUNCTIONS                                                 |
//+------------------------------------------------------------------+
double GetIndicatorValue(int handle, int buffer, int index)
{
   double value[];
   ArraySetAsSeries(value, true);
   if(CopyBuffer(handle, buffer, 0, index + 1, value) > 0)
      return value[index];
   return 0;
}

double GetPipSize()
{
   int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   if(digits == 3 || digits == 5)
      return SymbolInfoDouble(_Symbol, SYMBOL_POINT) * 10;
   return SymbolInfoDouble(_Symbol, SYMBOL_POINT);
}

bool IsSwingHigh(int index, int strength)
{
   double centerHigh = iHigh(_Symbol, PERIOD_CURRENT, index);
   for(int i = 1; i <= strength; i++)
   {
      if(iHigh(_Symbol, PERIOD_CURRENT, index - i) >= centerHigh) return false;
      if(iHigh(_Symbol, PERIOD_CURRENT, index + i) >= centerHigh) return false;
   }
   return true;
}

bool IsSwingLow(int index, int strength)
{
   double centerLow = iLow(_Symbol, PERIOD_CURRENT, index);
   for(int i = 1; i <= strength; i++)
   {
      if(iLow(_Symbol, PERIOD_CURRENT, index - i) <= centerLow) return false;
      if(iLow(_Symbol, PERIOD_CURRENT, index + i) <= centerLow) return false;
   }
   return true;
}

void AddSwingHigh(datetime time, double price)
{
   for(int i = 0; i < ArraySize(g_swingHighs); i++)
      if(g_swingHighs[i].time == time) return;
   
   int size = ArraySize(g_swingHighs);
   ArrayResize(g_swingHighs, size + 1);
   g_swingHighs[size].isHigh = true;
   g_swingHighs[size].time = time;
   g_swingHighs[size].price = price;
   g_swingHighs[size].isBroken = false;
}

void AddSwingLow(datetime time, double price)
{
   for(int i = 0; i < ArraySize(g_swingLows); i++)
      if(g_swingLows[i].time == time) return;
   
   int size = ArraySize(g_swingLows);
   ArrayResize(g_swingLows, size + 1);
   g_swingLows[size].isHigh = false;
   g_swingLows[size].time = time;
   g_swingLows[size].price = price;
   g_swingLows[size].isBroken = false;
}

void DetectOrderBlocks()
{
   for(int i = 5; i < 50; i++)
   {
      double open = iOpen(_Symbol, PERIOD_CURRENT, i);
      double close = iClose(_Symbol, PERIOD_CURRENT, i);
      double high = iHigh(_Symbol, PERIOD_CURRENT, i);
      double low = iLow(_Symbol, PERIOD_CURRENT, i);
      
      double displacementUp = 0;
      double displacementDown = 0;
      
      for(int j = 1; j <= 3; j++)
      {
         if(i - j < 0) break;
         double moveUp = iHigh(_Symbol, PERIOD_CURRENT, i - j) - low;
         double moveDown = high - iLow(_Symbol, PERIOD_CURRENT, i - j);
         displacementUp = MathMax(displacementUp, moveUp);
         displacementDown = MathMax(displacementDown, moveDown);
      }
      
      if(g_atr == 0) continue;
      
      if(close < open && displacementUp > g_atr * 2)
      {
         SOrderBlock ob;
         ob.type = OB_BULLISH;
         ob.time = iTime(_Symbol, PERIOD_CURRENT, i);
         ob.top = open;
         ob.bottom = close;
         ob.displacement = displacementUp / g_atr;
         ob.quality = MathMin(ob.displacement * 15 + 40, 100);
         
         if(ob.quality > g_latestOB.quality)
            g_latestOB = ob;
      }
      
      if(close > open && displacementDown > g_atr * 2)
      {
         SOrderBlock ob;
         ob.type = OB_BEARISH;
         ob.time = iTime(_Symbol, PERIOD_CURRENT, i);
         ob.top = close;
         ob.bottom = open;
         ob.displacement = displacementDown / g_atr;
         ob.quality = MathMin(ob.displacement * 15 + 40, 100);
         
         if(ob.quality > g_latestOB.quality)
            g_latestOB = ob;
      }
   }
}

void DetectFairValueGaps()
{
   for(int i = 2; i < 50; i++)
   {
      double high0 = iHigh(_Symbol, PERIOD_CURRENT, i - 2);
      double low0 = iLow(_Symbol, PERIOD_CURRENT, i - 2);
      double high2 = iHigh(_Symbol, PERIOD_CURRENT, i);
      double low2 = iLow(_Symbol, PERIOD_CURRENT, i);
      
      if(low0 > high2)
      {
         SFairValueGap fvg;
         fvg.type = FVG_BULLISH;
         fvg.time = iTime(_Symbol, PERIOD_CURRENT, i - 1);
         fvg.top = low0;
         fvg.bottom = high2;
         fvg.midpoint = (fvg.top + fvg.bottom) / 2;
         
         if(fvg.time > g_latestFVG.time)
            g_latestFVG = fvg;
      }
      
      if(high0 < low2)
      {
         SFairValueGap fvg;
         fvg.type = FVG_BEARISH;
         fvg.time = iTime(_Symbol, PERIOD_CURRENT, i - 1);
         fvg.top = low2;
         fvg.bottom = high0;
         fvg.midpoint = (fvg.top + fvg.bottom) / 2;
         
         if(fvg.time > g_latestFVG.time)
            g_latestFVG = fvg;
      }
   }
}

void UpdatePremiumDiscount()
{
   if(ArraySize(g_swingHighs) > 0 && ArraySize(g_swingLows) > 0)
   {
      double recentHigh = g_swingHighs[ArraySize(g_swingHighs) - 1].price;
      double recentLow = g_swingLows[ArraySize(g_swingLows) - 1].price;
      g_equilibrium = (recentHigh + recentLow) / 2;
   }
}

void DetectLiquidityLevels()
{
   // Session liquidity
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   datetime todayStart = StringToTime(IntegerToString(dt.year) + "." + 
                                      IntegerToString(dt.mon) + "." + 
                                      IntegerToString(dt.day));
   
   double sessionHigh = iHigh(_Symbol, PERIOD_D1, 0);
   double sessionLow = iLow(_Symbol, PERIOD_D1, 0);
   
   AddLiquidityLevel(LIQ_SESSION_HIGH, sessionHigh, todayStart, 7);
   AddLiquidityLevel(LIQ_SESSION_LOW, sessionLow, todayStart, 7);
   
   // Previous day
   double prevDayHigh = iHigh(_Symbol, PERIOD_D1, 1);
   double prevDayLow = iLow(_Symbol, PERIOD_D1, 1);
   
   AddLiquidityLevel(LIQ_PREVIOUS_DAY_HIGH, prevDayHigh, iTime(_Symbol, PERIOD_D1, 1), 8);
   AddLiquidityLevel(LIQ_PREVIOUS_DAY_LOW, prevDayLow, iTime(_Symbol, PERIOD_D1, 1), 8);
}

void AddLiquidityLevel(ENUM_LIQUIDITY_TYPE type, double price, datetime time, int strength)
{
   int size = ArraySize(g_liquidityLevels);
   ArrayResize(g_liquidityLevels, size + 1);
   g_liquidityLevels[size].type = type;
   g_liquidityLevels[size].price = price;
   g_liquidityLevels[size].time = time;
   g_liquidityLevels[size].strength = strength;
   g_liquidityLevels[size].swept = false;
}

void CheckLiquiditySweeps()
{
   double currentHigh = iHigh(_Symbol, PERIOD_CURRENT, 0);
   double currentLow = iLow(_Symbol, PERIOD_CURRENT, 0);
   double currentClose = iClose(_Symbol, PERIOD_CURRENT, 0);
   
   if(TimeCurrent() - g_lastSweepTime > PeriodSeconds(PERIOD_H1))
   {
      g_recentSweep = false;
      g_lastSweepDir = SWEEP_NONE;
   }
   
   for(int i = 0; i < ArraySize(g_liquidityLevels); i++)
   {
      if(currentHigh > g_liquidityLevels[i].price && currentClose < g_liquidityLevels[i].price)
      {
         g_recentSweep = true;
         g_lastSweepDir = SWEEP_BUYSIDE;
         g_lastSweepTime = TimeCurrent();
         Print("✓ BUY-SIDE LIQUIDITY SWEEP at ", g_liquidityLevels[i].price);
         return;
      }
      
      if(currentLow < g_liquidityLevels[i].price && currentClose > g_liquidityLevels[i].price)
      {
         g_recentSweep = true;
         g_lastSweepDir = SWEEP_SELLSIDE;
         g_lastSweepTime = TimeCurrent();
         Print("✓ SELL-SIDE LIQUIDITY SWEEP at ", g_liquidityLevels[i].price);
         return;
      }
   }
}

void UpdateNearestLiquidity()
{
   double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double nearestBuyside = DBL_MAX;
   double nearestSellside = 0;
   
   for(int i = 0; i < ArraySize(g_liquidityLevels); i++)
   {
      if(g_liquidityLevels[i].swept) continue;
      
      if(g_liquidityLevels[i].price > currentPrice && g_liquidityLevels[i].price < nearestBuyside)
      {
         nearestBuyside = g_liquidityLevels[i].price;
         g_buysideLiq = g_liquidityLevels[i];
      }
      
      if(g_liquidityLevels[i].price < currentPrice && g_liquidityLevels[i].price > nearestSellside)
      {
         nearestSellside = g_liquidityLevels[i].price;
         g_sellsideLiq = g_liquidityLevels[i];
      }
   }
}

ENUM_TRADE_DIRECTION AnalyzeTimeframe(ENUM_TIMEFRAMES tf, int ema20Handle, int ema50Handle)
{
   double ema20 = GetIndicatorValue(ema20Handle, 0, 0);
   double ema50 = GetIndicatorValue(ema50Handle, 0, 0);
   double currentPrice = iClose(_Symbol, tf, 0);
   
   if(ema20 > ema50 && currentPrice > ema20)
      return DIRECTION_LONG;
   if(ema20 < ema50 && currentPrice < ema20)
      return DIRECTION_SHORT;
   
   return DIRECTION_NONE;
}

ENUM_STRATEGY_TYPE GetActiveStrategy(ENUM_MARKET_REGIME regime)
{
   switch(regime)
   {
      case REGIME_STRONG_BULL_TREND:
      case REGIME_STRONG_BEAR_TREND:
         if(g_enabledStrategies[STRATEGY_TREND_CONTINUATION])
            return STRATEGY_TREND_CONTINUATION;
         break;
         
      case REGIME_LIQUIDITY_HUNT:
      case REGIME_TREND_EXHAUSTION:
         if(g_enabledStrategies[STRATEGY_LIQUIDITY_REVERSAL])
            return STRATEGY_LIQUIDITY_REVERSAL;
         break;
         
      case REGIME_RANGE_BOUND:
      case REGIME_ACCUMULATION:
      case REGIME_DISTRIBUTION:
         if(g_enabledStrategies[STRATEGY_RANGE_MEAN_REVERSION])
            return STRATEGY_RANGE_MEAN_REVERSION;
         break;
         
      case REGIME_LOW_VOLATILITY:
         if(g_enabledStrategies[STRATEGY_VOLATILITY_BREAKOUT])
            return STRATEGY_VOLATILITY_BREAKOUT;
         break;
   }
   
   return STRATEGY_NONE;
}

ENUM_TRADE_DIRECTION DetermineDirection(const SMarketNarrative &narrative, ENUM_STRATEGY_TYPE strategy)
{
   if(narrative.htfBias == DIRECTION_LONG && 
      (narrative.structureBias == BIAS_BULLISH || narrative.structureBias == BIAS_STRONGLY_BULLISH))
      return DIRECTION_LONG;
   
   if(narrative.htfBias == DIRECTION_SHORT && 
      (narrative.structureBias == BIAS_BEARISH || narrative.structureBias == BIAS_STRONGLY_BEARISH))
      return DIRECTION_SHORT;
   
   if(strategy == STRATEGY_LIQUIDITY_REVERSAL && narrative.hasCHoCH)
   {
      if(narrative.sweepDirection == SWEEP_SELLSIDE)
         return DIRECTION_LONG;
      if(narrative.sweepDirection == SWEEP_BUYSIDE)
         return DIRECTION_SHORT;
   }
   
   return DIRECTION_NONE;
}

double ScoreMarketRegime(const SMarketNarrative &narrative, ENUM_STRATEGY_TYPE strategy)
{
   switch(strategy)
   {
      case STRATEGY_TREND_CONTINUATION:
         if(narrative.regime == REGIME_STRONG_BULL_TREND || narrative.regime == REGIME_STRONG_BEAR_TREND)
            return 100;
         if(narrative.regime == REGIME_WEAK_BULL_TREND || narrative.regime == REGIME_WEAK_BEAR_TREND)
            return 70;
         return 20;
         
      case STRATEGY_LIQUIDITY_REVERSAL:
         if(narrative.regime == REGIME_LIQUIDITY_HUNT)
            return 100;
         return 50;
         
      case STRATEGY_RANGE_MEAN_REVERSION:
         if(narrative.regime == REGIME_RANGE_BOUND)
            return 100;
         return 30;
         
      default:
         return 50;
   }
}

double ScoreHTFBias(const SMarketNarrative &narrative, ENUM_TRADE_DIRECTION direction)
{
   if(direction == DIRECTION_LONG && narrative.htfBias == DIRECTION_LONG)
      return narrative.mtfAlignment;
   if(direction == DIRECTION_SHORT && narrative.htfBias == DIRECTION_SHORT)
      return narrative.mtfAlignment;
   return 30;
}

double ScoreLiquidity(const SMarketNarrative &narrative, ENUM_TRADE_DIRECTION direction)
{
   double score = 50;
   if(narrative.hasRecentSweep)
   {
      if(direction == DIRECTION_LONG && narrative.sweepDirection == SWEEP_SELLSIDE)
         score += 40;
      if(direction == DIRECTION_SHORT && narrative.sweepDirection == SWEEP_BUYSIDE)
         score += 40;
   }
   return MathMin(score, 100);
}

double ScoreStructure(const SMarketNarrative &narrative, ENUM_TRADE_DIRECTION direction)
{
   double score = 50;
   if(narrative.hasActiveBOS) score += 25;
   if(narrative.hasCHoCH) score += 20;
   return MathMin(score, 100);
}

double ScoreOrderBlock(const SMarketNarrative &narrative, ENUM_TRADE_DIRECTION direction)
{
   if(narrative.latestOrderBlock.type == OB_NONE) return 30;
   if(direction == DIRECTION_LONG && narrative.latestOrderBlock.type == OB_BULLISH)
      return narrative.latestOrderBlock.quality;
   if(direction == DIRECTION_SHORT && narrative.latestOrderBlock.type == OB_BEARISH)
      return narrative.latestOrderBlock.quality;
   return 20;
}

double ScoreFVG(const SMarketNarrative &narrative, ENUM_TRADE_DIRECTION direction)
{
   if(narrative.latestFVG.type == FVG_NONE) return 50;
   if(direction == DIRECTION_LONG && narrative.latestFVG.type == FVG_BULLISH && !narrative.latestFVG.filled)
      return 85;
   if(direction == DIRECTION_SHORT && narrative.latestFVG.type == FVG_BEARISH && !narrative.latestFVG.filled)
      return 85;
   return 40;
}

double ScoreMomentum(const SMarketNarrative &narrative, ENUM_TRADE_DIRECTION direction)
{
   if(direction == DIRECTION_LONG && narrative.structureBias == BIAS_STRONGLY_BULLISH)
      return narrative.trendStrength * 100;
   if(direction == DIRECTION_SHORT && narrative.structureBias == BIAS_STRONGLY_BEARISH)
      return narrative.trendStrength * 100;
   return 50;
}

double ScoreSession(const SMarketNarrative &narrative)
{
   if(narrative.isKillZone) return 100;
   if(narrative.currentSession == SESSION_LONDON || narrative.currentSession == SESSION_NEWYORK)
      return 80;
   return 60;
}

double ScoreVolatility(const SMarketNarrative &narrative, ENUM_STRATEGY_TYPE strategy)
{
   if(strategy == STRATEGY_VOLATILITY_BREAKOUT)
   {
      if(narrative.volatilityState == VOLATILITY_LOW || narrative.volatilityState == VOLATILITY_VERY_LOW)
         return 100;
   }
   if(narrative.volatilityState == VOLATILITY_NORMAL)
      return 80;
   if(narrative.volatilityState == VOLATILITY_EXTREME)
      return 30;
   return 60;
}

void CalculateEntryAndTargets(STradeSignal &signal, const SMarketNarrative &narrative)
{
   signal.entryPrice = narrative.currentPrice;
   
   if(signal.direction == DIRECTION_LONG)
   {
      if(narrative.latestOrderBlock.type == OB_BULLISH)
         signal.stopLoss = narrative.latestOrderBlock.bottom - (narrative.atr * 0.5);
      else
         signal.stopLoss = narrative.currentPrice - (narrative.atr * 1.5);
   }
   else
   {
      if(narrative.latestOrderBlock.type == OB_BEARISH)
         signal.stopLoss = narrative.latestOrderBlock.top + (narrative.atr * 0.5);
      else
         signal.stopLoss = narrative.currentPrice + (narrative.atr * 1.5);
   }
   
   double riskDistance = MathAbs(signal.entryPrice - signal.stopLoss);
   
   signal.takeProfit1 = signal.entryPrice + (riskDistance * 1.5 * (signal.direction == DIRECTION_LONG ? 1 : -1));
   signal.takeProfit2 = signal.entryPrice + (riskDistance * 2.5 * (signal.direction == DIRECTION_LONG ? 1 : -1));
   signal.takeProfit3 = signal.entryPrice + (riskDistance * 4.0 * (signal.direction == DIRECTION_LONG ? 1 : -1));
   
   signal.riskRewardRatio = MathAbs(signal.takeProfit1 - signal.entryPrice) / riskDistance;
}

double CalculateLotSize(double stopLoss, double entryPrice)
{
   double accountBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   double riskAmount = accountBalance * (InpRiskPercent / 100.0);
   
   double slDistance = MathAbs(entryPrice - stopLoss);
   if(slDistance == 0) return 0;
   
   double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   
   if(tickValue == 0 || tickSize == 0) return 0;
   
   double lotSize = riskAmount / (slDistance / tickSize * tickValue);
   
   double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   
   lotSize = MathFloor(lotSize / lotStep) * lotStep;
   lotSize = MathMax(minLot, MathMin(maxLot, lotSize));
   lotSize = MathMin(lotSize, InpMaxLotSize);
   
   return lotSize;
}

ENUM_TRADING_SESSION GetCurrentSession()
{
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   int hour = dt.hour;
   
   if(hour >= 0 && hour < 9) return SESSION_ASIAN;
   if(hour >= 8 && hour < 17) return SESSION_LONDON;
   if(hour >= 13 && hour < 22) return SESSION_NEWYORK;
   
   return SESSION_NONE;
}

bool IsKillZone()
{
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   int hour = dt.hour;
   
   if(hour >= 7 && hour < 9) return true;
   if(hour >= 13 && hour < 15) return true;
   
   return false;
}

string GetDeinitReasonText(int reason)
{
   switch(reason)
   {
      case REASON_PROGRAM:     return "Program terminated";
      case REASON_REMOVE:      return "EA removed from chart";
      case REASON_RECOMPILE:   return "EA recompiled";
      case REASON_CHARTCHANGE: return "Chart changed";
      case REASON_CHARTCLOSE:  return "Chart closed";
      case REASON_PARAMETERS:  return "Parameters changed";
      case REASON_ACCOUNT:     return "Account changed";
      default:                 return "Unknown reason";
   }
}
//+------------------------------------------------------------------+