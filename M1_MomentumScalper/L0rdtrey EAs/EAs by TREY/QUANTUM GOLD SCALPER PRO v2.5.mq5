//+------------------------------------------------------------------+
//|                                    QUANTUM PLUS AI v2.0 GOLD     |
//|        Elite Gold Scalping System with ML & Smart Money Concepts |
//|        Advanced Institutional-Grade Adaptive Trading System      |
//+------------------------------------------------------------------+
#property copyright   "Quantum Plus AI v2.0 - Elite Gold Scalper"
#property version     "2.00"
#property description "Advanced ML-powered Gold scalping with Smart Money Concepts"
#property strict

#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>
#include <Trade\AccountInfo.mqh>
#include <Trade\OrderInfo.mqh>

#define D "QPA2_"   

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
   REGIME_CONSOLIDATION,
   REGIME_SMART_MONEY_ACCUMULATION,
   REGIME_SMART_MONEY_DISTRIBUTION,
   REGIME_UNSAFE
};

enum ENUM_VOL_STATE
{
   VOL_EXTREME_LOW,
   VOL_LOW,
   VOL_NORMAL,
   VOL_HIGH,
   VOL_EXTREME,
   VOL_SPIKE
};

enum ENUM_SESSION
{
   SESSION_ASIAN,
   SESSION_LONDON_OPEN,
   SESSION_LONDON_MID,
   SESSION_NY_OPEN,
   SESSION_NY_OVERLAP,
   SESSION_NY_PM,
   SESSION_DEAD_ZONE
};

enum ENUM_MARKET_PHASE
{
   PHASE_ACCUMULATION,
   PHASE_MARKUP,
   PHASE_DISTRIBUTION,
   PHASE_MARKDOWN,
   PHASE_REACCUMULATION,
   PHASE_REDISTRIBUTION
};

enum ENUM_GOLD_STRATEGY
{
   STRAT_NONE,
   STRAT_FVG_SCALP,              // Fair Value Gap scalping
   STRAT_ORDER_BLOCK_REVERSAL,   // Order block reversals
   STRAT_LIQUIDITY_GRAB,         // Liquidity sweep trades
   STRAT_BREAKOUT_RETEST,        // Break & retest
   STRAT_ASIAN_RANGE_BREAKOUT,   // Asian range breakout
   STRAT_LONDON_KILLZONE,        // London open volatility
   STRAT_NY_REVERSAL,            // NY session reversal
   STRAT_PREMIUM_DISCOUNT,       // Premium/Discount zones
   STRAT_IMBALANCE_FILL,         // Imbalance/inefficiency fill
   STRAT_TREND_CONTINUATION,     // Trend following
   STRAT_SCALP_MOMENTUM,         // Pure momentum scalp
   STRAT_CORRELATION_DIVERGENCE  // DXY/USD correlation
};

enum ENUM_DIRECTION
{
   DIR_NONE,
   DIR_LONG,
   DIR_SHORT
};

enum ENUM_ORDER_BLOCK_TYPE
{
   OB_BULLISH,
   OB_BEARISH,
   OB_NONE
};

//=====================================================================
//  ADVANCED STRUCTURES
//=====================================================================

struct FairValueGap
{
   datetime   time;
   double     top;
   double     bottom;
   double     middle;
   bool       bullish;
   bool       filled;
   double     fillPercent;
   int        strength;        // 1-10 rating
};

struct OrderBlock
{
   datetime   time;
   double     high;
   double     low;
   double     entry;
   ENUM_ORDER_BLOCK_TYPE type;
   bool       tested;
   int        strength;
   bool       valid;
};

struct ChangeOfCharacter
{
   datetime   time;
   double     price;
   bool       bullish;
   int        strength;
   bool       confirmed;
};

struct LiquidityZone
{
   double     price;
   int        touches;
   datetime   lastTouch;
   bool       swept;
   int        strength;
   bool       isHigh;
};

struct PremiumDiscount
{
   double     equilibrium;
   double     premiumZone;
   double     discountZone;
   double     extremePremium;
   double     extremeDiscount;
   bool       inPremium;
   bool       inDiscount;
   double     currentLevel;    // 0-100 scale
};

struct MarketStructure
{
   double     lastHH;
   double     lastHL;
   double     lastLH;
   double     lastLL;
   datetime   lastHHTime;
   datetime   lastHLTime;
   datetime   lastLHTime;
   datetime   lastLLTime;
   bool       uptrendActive;
   bool       downtrendActive;
   int        structureStrength;
};

struct CorrelationData
{
   double     dxyCorrelation;      // Dollar index proxy
   double     usdStrength;
   double     goldUSDScore;
   bool       divergenceDetected;
   int        divergenceStrength;
};

struct MLPattern
{
   string     patternName;
   double     features[20];        // Pattern features
   int        featureCount;
   double     successRate;
   int        occurrences;
   int        wins;
   int        losses;
   double     avgWin;
   double     avgLoss;
   double     confidence;
   bool       active;
};

struct IndicatorSet
{
   string     name;
   int        handles[5];          // Multiple indicator handles
   int        count;
   double     weight;              // Current weight/importance
   double     performance;         // Recent performance score
   bool       active;
   ENUM_SESSION preferredSession;
   ENUM_VOL_STATE preferredVolatility;
};

struct StrategyPerformance
{
   ENUM_GOLD_STRATEGY strategy;
   string     name;
   int        totalTrades;
   int        wins;
   int        losses;
   double     grossProfit;
   double     grossLoss;
   double     profitFactor;
   double     winRate;
   double     avgWin;
   double     avgLoss;
   double     expectancy;
   double     sharpe;
   double     maxDD;
   int        consecWins;
   int        consecLosses;
   int        maxConsecWins;
   int        maxConsecLosses;
   double     currentWeight;       // ML-adjusted weight
   bool       enabled;
   ENUM_SESSION bestSession;
   ENUM_VOL_STATE bestVolatility;
   datetime   lastTrade;
};

struct DynamicRiskParams
{
   double     baseLotSize;
   double     currentMultiplier;
   double     volatilityAdjustment;
   double     accountSizeAdjustment;
   double     winStreakBonus;
   double     lossStreakPenalty;
   double     sessionAdjustment;
   double     confidenceMultiplier;
   double     finalLotSize;
   double     dynamicSL_ATR;
   double     dynamicTP_ATR;
   double     riskPercent;
};

struct SignalQuality
{
   double     indicatorAlignment;
   double     marketStructureScore;
   double     volumeConfirmation;
   double     sessionScore;
   double     volatilityScore;
   double     momentumScore;
   double     smartMoneyScore;
   double     mlConfidence;
   double     compositeScore;
   int        signalStrength;      // 1-10
};

struct GoldSignal
{
   ENUM_GOLD_STRATEGY strategy;
   ENUM_DIRECTION direction;
   double     entryPrice;
   double     slPrice;
   double     tp1Price;
   double     tp2Price;
   double     tp3Price;
   SignalQuality quality;
   string     narrative;
   bool       valid;
   datetime   timestamp;
};

//=====================================================================
//  INPUT PARAMETERS
//=====================================================================

input group "╔══════  IDENTITY  ══════╗"
input ulong    InpMagicNumber          = 888800;
input string   InpBotName              = "QPA GOLD 2.0";
input string   InpSymbolOverride       = "XAUUSD";  // Leave empty for current symbol

input group "╔══════  DYNAMIC RISK MANAGEMENT  ══════╗"
input double   InpBaseRiskPercent      = 0.5;      // Base risk per trade
input double   InpMaxRiskPercent       = 2.0;      // Maximum risk per trade
input double   InpMinRiskPercent       = 0.1;      // Minimum risk per trade
input bool     InpEnableVolatilityRisk = true;     // Adjust risk by volatility
input bool     InpEnableAccountScaling = true;     // Scale with account size
input double   InpSmallAccountThreshold= 1000;     // Small account threshold
input double   InpLargeAccountThreshold= 10000;    // Large account threshold
input int      InpMaxDailyTrades       = 15;       // Max trades per day
input int      InpMaxConcurrentTrades  = 3;        // Max concurrent positions
input double   InpMaxDailyLossPct      = 4.0;      // Max daily loss %
input double   InpMaxWeeklyLossPct     = 10.0;     // Max weekly loss %
input double   InpMaxDrawdownPct       = 15.0;     // Max drawdown %

input group "╔══════  SMART MONEY CONCEPTS  ══════╗"
input bool     InpEnableFVG            = true;     // Enable Fair Value Gaps
input bool     InpEnableOrderBlocks    = true;     // Enable Order Blocks
input bool     InpEnableCHoCH          = true;     // Enable Change of Character
input bool     InpEnableBOS            = true;     // Enable Break of Structure
input bool     InpEnablePremiumDiscount= true;     // Enable Premium/Discount zones
input int      InpFVG_MinPoints        = 100;      // Min FVG size in points
input int      InpOB_LookbackBars      = 50;       // Order block lookback
input double   InpOB_MinStrength       = 5.0;      // Min order block strength

input group "╔══════  MACHINE LEARNING  ══════╗"
input bool     InpEnableML             = true;     // Enable ML features
input int      InpML_LearningPeriod    = 100;      // Learning period (trades)
input double   InpML_MinConfidence     = 60.0;     // Min ML confidence %
input bool     InpML_AdaptiveWeights   = true;     // Adaptive strategy weights
input int      InpML_PatternMemory     = 500;      // Pattern memory size

input group "╔══════  INDICATOR SYSTEM  ══════╗"
input bool     InpAutoSelectIndicators = true;     // Auto-select best indicators
input bool     InpUseEMA               = true;     // Use EMA
input bool     InpUseRSI               = true;     // Use RSI
input bool     InpUseStochastic        = true;     // Use Stochastic
input bool     InpUseMACD              = true;     // Use MACD
input bool     InpUseBollinger         = true;     // Use Bollinger Bands
input bool     InpUseATR               = true;     // Use ATR
input bool     InpUseVolume            = true;     // Use Volume analysis
input bool     InpUseADX               = true;     // Use ADX
input bool     InpUseCCI               = true;     // Use CCI
input bool     InpUseIchimoku          = false;    // Use Ichimoku
input int      InpEMA_Fast             = 8;
input int      InpEMA_Medium           = 21;
input int      InpEMA_Slow             = 50;
input int      InpEMA_SuperSlow        = 200;

input group "╔══════  GOLD-SPECIFIC SETTINGS  ══════╗"
input bool     InpEnableCorrelation    = true;     // Monitor USD correlation
input bool     InpEnableNewsFilter     = true;     // News filter
input int      InpGoldVolatilityPeriod = 14;       // Gold volatility period
input double   InpGoldSpreadMax        = 30.0;     // Max spread in points
input int      InpScalpTimeframe       = 5;        // Primary scalp TF (minutes)

input group "╔══════  SESSION OPTIMIZATION  ══════╗"
input bool     InpTradeAsian           = true;
input bool     InpTradeLondon          = true;
input bool     InpTradeNY              = true;
input bool     InpTradeOverlap         = true;     // London-NY overlap
input int      InpBrokerGMTOffset      = 2;

input group "╔══════  VISUAL INTELLIGENCE  ══════╗"
input bool     InpShowDashboard        = true;
input int      InpDashX                = 10;
input int      InpDashY                = 10;
input bool     InpDrawFVG              = true;     // Draw Fair Value Gaps
input bool     InpDrawOrderBlocks      = true;     // Draw Order Blocks
input bool     InpDrawCHoCH            = true;     // Draw Change of Character
input bool     InpDrawBOS              = true;     // Draw Break of Structure
input bool     InpDrawPremiumDiscount  = true;     // Draw Premium/Discount
input bool     InpDrawLiquidity        = true;     // Draw Liquidity zones
input bool     InpDrawMarketStructure  = true;     // Draw Market Structure
input bool     InpDrawSignals          = true;     // Draw entry/exit signals

//=====================================================================
//  GLOBAL COLOR PALETTE
//=====================================================================
#define C_BG0       C'5,7,16'
#define C_BG1       C'9,13,26'
#define C_BG2       C'13,19,38'
#define C_BG3       C'18,25,48'
#define C_HDRBAR    C'11,17,34'
#define C_BORDER    C'24,46,88'
#define C_ACBORD    C'0,170,225'
#define C_GOLD      C'255,202,60'
#define C_DARKGOLD  C'184,134,11'
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
#define C_FVG_BULL  C'0,255,100,40'
#define C_FVG_BEAR  C'255,0,100,40'
#define C_OB_BULL   C'0,150,255,60'
#define C_OB_BEAR   C'255,50,0,60'
#define C_PREMIUM   C'255,0,0,30'
#define C_DISCOUNT  C'0,255,0,30'

//=====================================================================
//  GLOBAL OBJECTS & HANDLES
//=====================================================================
CTrade        g_trade;
CPositionInfo g_pos;
CAccountInfo  g_account;

// Multi-timeframe indicator handles
int g_h4_ema_fast, g_h4_ema_medium, g_h4_ema_slow, g_h4_atr;
int g_h1_ema_fast, g_h1_ema_medium, g_h1_ema_slow, g_h1_atr, g_h1_rsi, g_h1_macd;
int g_m15_ema_fast, g_m15_ema_medium, g_m15_ema_slow, g_m15_atr, g_m15_rsi, g_m15_stoch, g_m15_macd;
int g_m5_ema_fast, g_m5_ema_medium, g_m5_ema_slow, g_m5_atr, g_m5_rsi, g_m5_stoch, g_m5_bb, g_m5_adx, g_m5_cci;
int g_m1_ema_fast, g_m1_ema_medium, g_m1_atr, g_m1_rsi;

// Smart Money arrays
FairValueGap g_fvgArray[50];
int g_fvgCount = 0;

OrderBlock g_orderBlocks[30];
int g_obCount = 0;

ChangeOfCharacter g_chochArray[20];
int g_chochCount = 0;

LiquidityZone g_liquidityZones[40];
int g_liqZoneCount = 0;

// ML Pattern database
MLPattern g_mlPatterns[100];
int g_mlPatternCount = 0;

// Strategy performance tracking
StrategyPerformance g_strategies[13];

// Indicator sets
IndicatorSet g_indicatorSets[5];
int g_activeIndicatorSet = 0;

//=====================================================================
//  STATE VARIABLES
//=====================================================================
ENUM_REGIME g_currentRegime = REGIME_RANGING;
ENUM_SESSION g_currentSession = SESSION_DEAD_ZONE;
ENUM_VOL_STATE g_currentVolState = VOL_NORMAL;
ENUM_MARKET_PHASE g_marketPhase = PHASE_ACCUMULATION;

MarketStructure g_structure;
PremiumDiscount g_premiumDiscount;
CorrelationData g_correlation;
DynamicRiskParams g_dynamicRisk;

double g_peakEquity = 0;
double g_dayStartEquity = 0;
double g_weekStartEquity = 0;
datetime g_dayStart = 0;
datetime g_weekStart = 0;
int g_tradesToday = 0;
datetime g_lastTradeTime = 0;
datetime g_lastBarTime = 0;

string g_statusText = "INITIALIZING";
color g_statusColor = C_ORANGE;
string g_lastAction = "System starting...";

// Performance tracking
double g_sessionProfit = 0;
int g_sessionWins = 0;
int g_sessionLosses = 0;
double g_totalProfit = 0;
double g_totalLoss = 0;

// Dashboard dimensions
const int DW = 380;
const int DH = 720;

//=====================================================================
//  UTILITY FUNCTIONS
//=====================================================================

double NPrice(double p)
{
   return NormalizeDouble(p, (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS));
}

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

ENUM_ORDER_TYPE_FILLING GetFillMode()
{
   uint f = (uint)SymbolInfoInteger(_Symbol, SYMBOL_FILLING_MODE);
   if((f & SYMBOL_FILLING_FOK) != 0) return ORDER_FILLING_FOK;
   if((f & SYMBOL_FILLING_IOC) != 0) return ORDER_FILLING_IOC;
   return ORDER_FILLING_RETURN;
}

bool IsNewBar(ENUM_TIMEFRAMES tf = PERIOD_CURRENT)
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

int PositionsTotalForMagic()
{
   int count = 0;
   for(int i = PositionsTotal()-1; i >= 0; i--)
   {
      if(g_pos.SelectByIndex(i) && g_pos.Magic() == InpMagicNumber && g_pos.Symbol() == _Symbol)
         count++;
   }
   return count;
}

//=====================================================================
//  SESSION DETECTION
//=====================================================================

ENUM_SESSION ClassifySession(datetime ts)
{
   MqlDateTime d; 
   TimeToStruct(ts, d);
   int hour = d.hour;
   
   hour = (hour - InpBrokerGMTOffset + 24) % 24;

   // Asian: 00:00-07:00 GMT
   if(hour >= 0 && hour < 7) return SESSION_ASIAN;
   
   // London Open: 07:00-10:00 GMT
   if(hour >= 7 && hour < 10) return SESSION_LONDON_OPEN;
   
   // London Mid: 10:00-12:00 GMT
   if(hour >= 10 && hour < 12) return SESSION_LONDON_MID;
   
   // NY Open / Overlap: 12:00-16:00 GMT
   if(hour >= 12 && hour < 16) return SESSION_NY_OVERLAP;
   
   // NY PM: 16:00-21:00 GMT
   if(hour >= 16 && hour < 21) return SESSION_NY_PM;
   
   return SESSION_DEAD_ZONE;
}

bool IsSessionAllowed(ENUM_SESSION session)
{
   switch(session)
   {
      case SESSION_ASIAN: return InpTradeAsian;
      case SESSION_LONDON_OPEN:
      case SESSION_LONDON_MID: return InpTradeLondon;
      case SESSION_NY_OVERLAP: return InpTradeOverlap;
      case SESSION_NY_PM: return InpTradeNY;
      default: return false;
   }
}

//=====================================================================
//  SMART MONEY CONCEPTS - FAIR VALUE GAPS
//=====================================================================

void DetectFairValueGaps()
{
   if(!InpEnableFVG) return;
   
   g_fvgCount = 0;
   
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   int minGapPoints = InpFVG_MinPoints;
   
   for(int i = 2; i < 100 && g_fvgCount < 50; i++)
   {
      double high1 = iHigh(_Symbol, PERIOD_M5, i);
      double low1  = iLow(_Symbol, PERIOD_M5, i);
      double high2 = iHigh(_Symbol, PERIOD_M5, i-1);
      double low2  = iLow(_Symbol, PERIOD_M5, i-1);
      double high3 = iHigh(_Symbol, PERIOD_M5, i+1);
      double low3  = iLow(_Symbol, PERIOD_M5, i+1);
      
      // Bullish FVG: low3 > high1
      if(low3 > high1 + minGapPoints * point)
      {
         FairValueGap fvg;
         fvg.time    = iTime(_Symbol, PERIOD_M5, i);
         fvg.top     = low3;
         fvg.bottom  = high1;
         fvg.middle  = (fvg.top + fvg.bottom) / 2.0;
         fvg.bullish = true;
         fvg.filled  = false;
         fvg.fillPercent = 0;
         
         double size = fvg.top - fvg.bottom;
         fvg.strength = (int)MathMin(10, MathMax(1, size / (point * 100)));
         
         g_fvgArray[g_fvgCount++] = fvg;
      }
      
      // Bearish FVG: high3 < low1
      if(high3 < low1 - minGapPoints * point)
      {
         FairValueGap fvg;
         fvg.time    = iTime(_Symbol, PERIOD_M5, i);
         fvg.bottom  = high3;
         fvg.top     = low1;
         fvg.middle  = (fvg.top + fvg.bottom) / 2.0;
         fvg.bullish = false;
         fvg.filled  = false;
         fvg.fillPercent = 0;
         
         double size = fvg.top - fvg.bottom;
         fvg.strength = (int)MathMin(10, MathMax(1, size / (point * 100)));
         
         g_fvgArray[g_fvgCount++] = fvg;
      }
   }
   
   // Check fill status
   double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   
   for(int i = 0; i < g_fvgCount; i++)
   {
      if(g_fvgArray[i].bullish)
      {
         if(currentPrice >= g_fvgArray[i].bottom && currentPrice <= g_fvgArray[i].top)
         {
            g_fvgArray[i].fillPercent = (currentPrice - g_fvgArray[i].bottom) / (g_fvgArray[i].top - g_fvgArray[i].bottom) * 100.0;
            if(g_fvgArray[i].fillPercent >= 50) g_fvgArray[i].filled = true;
         }
      }
      else
      {
         if(currentPrice >= g_fvgArray[i].bottom && currentPrice <= g_fvgArray[i].top)
         {
            g_fvgArray[i].fillPercent = (g_fvgArray[i].top - currentPrice) / (g_fvgArray[i].top - g_fvgArray[i].bottom) * 100.0;
            if(g_fvgArray[i].fillPercent >= 50) g_fvgArray[i].filled = true;
         }
      }
   }
}

//=====================================================================
//  SMART MONEY CONCEPTS - ORDER BLOCKS
//=====================================================================

void DetectOrderBlocks()
{
   if(!InpEnableOrderBlocks) return;
   
   g_obCount = 0;
   
   for(int i = 5; i < InpOB_LookbackBars && g_obCount < 30; i++)
   {
      double o = iOpen(_Symbol, PERIOD_M5, i);
      double h = iHigh(_Symbol, PERIOD_M5, i);
      double l = iLow(_Symbol, PERIOD_M5, i);
      double c = iClose(_Symbol, PERIOD_M5, i);
      
      // Check for strong move after this candle
      double nextHigh = iHigh(_Symbol, PERIOD_M5, i-1);
      double nextLow  = iLow(_Symbol, PERIOD_M5, i-1);
      double next2High = iHigh(_Symbol, PERIOD_M5, i-2);
      double next2Low  = iLow(_Symbol, PERIOD_M5, i-2);
      
      double candleSize = h - l;
      double avgMove = (MathAbs(nextHigh - h) + MathAbs(next2High - nextHigh)) / 2.0;
      
      // Bullish Order Block: Down candle followed by strong up move
      if(c < o && next2High > h && avgMove > candleSize * 1.5)
      {
         OrderBlock ob;
         ob.time = iTime(_Symbol, PERIOD_M5, i);
         ob.high = h;
         ob.low  = l;
         ob.entry = (h + l) / 2.0;
         ob.type = OB_BULLISH;
         ob.tested = false;
         ob.strength = (int)MathMin(10, avgMove / candleSize);
         ob.valid = ob.strength >= (int)InpOB_MinStrength;
         
         if(ob.valid) g_orderBlocks[g_obCount++] = ob;
      }
      
      // Bearish Order Block: Up candle followed by strong down move
      if(c > o && next2Low < l && avgMove > candleSize * 1.5)
      {
         OrderBlock ob;
         ob.time = iTime(_Symbol, PERIOD_M5, i);
         ob.high = h;
         ob.low  = l;
         ob.entry = (h + l) / 2.0;
         ob.type = OB_BEARISH;
         ob.tested = false;
         ob.strength = (int)MathMin(10, avgMove / candleSize);
         ob.valid = ob.strength >= (int)InpOB_MinStrength;
         
         if(ob.valid) g_orderBlocks[g_obCount++] = ob;
      }
   }
   
   // Check if order blocks have been tested
   double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   
   for(int i = 0; i < g_obCount; i++)
   {
      if(g_orderBlocks[i].type == OB_BULLISH && currentPrice >= g_orderBlocks[i].low && currentPrice <= g_orderBlocks[i].high)
         g_orderBlocks[i].tested = true;
         
      if(g_orderBlocks[i].type == OB_BEARISH && currentPrice >= g_orderBlocks[i].low && currentPrice <= g_orderBlocks[i].high)
         g_orderBlocks[i].tested = true;
   }
}

//=====================================================================
//  SMART MONEY CONCEPTS - CHANGE OF CHARACTER (CHoCH)
//=====================================================================

void DetectChangeOfCharacter()
{
   if(!InpEnableCHoCH) return;
   
   g_chochCount = 0;
   
   // Find recent swing highs and lows
   double swingHighs[10];
   double swingLows[10];
   int shCount = 0, slCount = 0;
   
   for(int i = 2; i < 50 && shCount < 10; i++)
   {
      double h = iHigh(_Symbol, PERIOD_M5, i);
      double h1 = iHigh(_Symbol, PERIOD_M5, i-1);
      double h2 = iHigh(_Symbol, PERIOD_M5, i+1);
      
      if(h > h1 && h > h2)
         swingHighs[shCount++] = h;
   }
   
   for(int i = 2; i < 50 && slCount < 10; i++)
   {
      double l = iLow(_Symbol, PERIOD_M5, i);
      double l1 = iLow(_Symbol, PERIOD_M5, i-1);
      double l2 = iLow(_Symbol, PERIOD_M5, i+1);
      
      if(l < l1 && l < l2)
         swingLows[slCount++] = l;
   }
   
   // Detect CHoCH
   if(shCount >= 2 && slCount >= 2)
   {
      // Bullish CHoCH: Break of recent lower high
      if(swingHighs[0] > swingHighs[1])
      {
         ChangeOfCharacter choch;
         choch.time = iTime(_Symbol, PERIOD_M5, 0);
         choch.price = swingHighs[1];
         choch.bullish = true;
         choch.strength = 7;
         choch.confirmed = true;
         g_chochArray[g_chochCount++] = choch;
      }
      
      // Bearish CHoCH: Break of recent higher low
      if(swingLows[0] < swingLows[1])
      {
         ChangeOfCharacter choch;
         choch.time = iTime(_Symbol, PERIOD_M5, 0);
         choch.price = swingLows[1];
         choch.bullish = false;
         choch.strength = 7;
         choch.confirmed = true;
         g_chochArray[g_chochCount++] = choch;
      }
   }
}

//=====================================================================
//  SMART MONEY CONCEPTS - PREMIUM/DISCOUNT ZONES
//=====================================================================

void CalculatePremiumDiscount()
{
   if(!InpEnablePremiumDiscount) return;
   
   // Find recent high and low (swing high/low)
   double high = iHigh(_Symbol, PERIOD_M5, iHighest(_Symbol, PERIOD_M5, MODE_HIGH, 50, 0));
   double low  = iLow(_Symbol, PERIOD_M5, iLowest(_Symbol, PERIOD_M5, MODE_LOW, 50, 0));
   
   g_premiumDiscount.equilibrium = (high + low) / 2.0;
   
   double range = high - low;
   
   // Premium zones: 50%-100% of range
   g_premiumDiscount.premiumZone = g_premiumDiscount.equilibrium + range * 0.25;
   g_premiumDiscount.extremePremium = high;
   
   // Discount zones: 0%-50% of range
   g_premiumDiscount.discountZone = g_premiumDiscount.equilibrium - range * 0.25;
   g_premiumDiscount.extremeDiscount = low;
   
   double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   
   g_premiumDiscount.inPremium = currentPrice > g_premiumDiscount.equilibrium;
   g_premiumDiscount.inDiscount = currentPrice < g_premiumDiscount.equilibrium;
   
   // Calculate 0-100 scale position
   if(range > 0)
      g_premiumDiscount.currentLevel = (currentPrice - low) / range * 100.0;
   else
      g_premiumDiscount.currentLevel = 50.0;
}

//=====================================================================
//  MARKET STRUCTURE ANALYSIS
//=====================================================================

void UpdateMarketStructure()
{
   // Simplified market structure tracking
   double highs[20], lows[20];
   
   for(int i = 0; i < 20; i++)
   {
      highs[i] = iHigh(_Symbol, PERIOD_M15, i);
      lows[i]  = iLow(_Symbol, PERIOD_M15, i);
   }
   
   // Find highest high and lowest low
   int hhIdx = ArrayMaximum(highs, 0, 20);
   int llIdx = ArrayMinimum(lows, 0, 20);
   
   g_structure.lastHH = highs[hhIdx];
   g_structure.lastLL = lows[llIdx];
   g_structure.lastHHTime = iTime(_Symbol, PERIOD_M15, hhIdx);
   g_structure.lastLLTime = iTime(_Symbol, PERIOD_M15, llIdx);
   
   // Determine trend
   g_structure.uptrendActive = (hhIdx < llIdx); // HH came after LL
   g_structure.downtrendActive = (llIdx < hhIdx); // LL came after HH
   
   double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   
   // Structure strength based on proximity to extremes
   if(g_structure.uptrendActive)
      g_structure.structureStrength = (int)(100 * (currentPrice - g_structure.lastLL) / (g_structure.lastHH - g_structure.lastLL));
   else if(g_structure.downtrendActive)
      g_structure.structureStrength = (int)(100 * (g_structure.lastHH - currentPrice) / (g_structure.lastHH - g_structure.lastLL));
   else
      g_structure.structureStrength = 50;
}

//=====================================================================
//  LIQUIDITY ZONE DETECTION
//=====================================================================

void DetectLiquidityZones()
{
   if(!InpDrawLiquidity) return;
   
   g_liqZoneCount = 0;
   
   double tolerance = SymbolInfoDouble(_Symbol, SYMBOL_POINT) * 50; // 50 points tolerance
   
   // Find swing highs
   for(int i = 3; i < 50 && g_liqZoneCount < 40; i++)
   {
      double h = iHigh(_Symbol, PERIOD_M5, i);
      bool isSwingHigh = true;
      
      for(int j = 1; j <= 3; j++)
      {
         if(iHigh(_Symbol, PERIOD_M5, i-j) >= h || iHigh(_Symbol, PERIOD_M5, i+j) >= h)
         {
            isSwingHigh = false;
            break;
         }
      }
      
      if(isSwingHigh)
      {
         // Check if similar level exists
         bool foundSimilar = false;
         int similarIdx = -1;
         
         for(int k = 0; k < g_liqZoneCount; k++)
         {
            if(g_liquidityZones[k].isHigh && MathAbs(g_liquidityZones[k].price - h) <= tolerance)
            {
               foundSimilar = true;
               similarIdx = k;
               break;
            }
         }
         
         if(foundSimilar && similarIdx >= 0)
         {
            g_liquidityZones[similarIdx].touches++;
            g_liquidityZones[similarIdx].strength++;
         }
         else
         {
            LiquidityZone lz;
            lz.price = h;
            lz.touches = 1;
            lz.lastTouch = iTime(_Symbol, PERIOD_M5, i);
            lz.swept = false;
            lz.strength = 1;
            lz.isHigh = true;
            g_liquidityZones[g_liqZoneCount++] = lz;
         }
      }
   }
   
   // Find swing lows
   for(int i = 3; i < 50 && g_liqZoneCount < 40; i++)
   {
      double l = iLow(_Symbol, PERIOD_M5, i);
      bool isSwingLow = true;
      
      for(int j = 1; j <= 3; j++)
      {
         if(iLow(_Symbol, PERIOD_M5, i-j) <= l || iLow(_Symbol, PERIOD_M5, i+j) <= l)
         {
            isSwingLow = false;
            break;
         }
      }
      
      if(isSwingLow)
      {
         bool foundSimilar = false;
         int similarIdx = -1;
         
         for(int k = 0; k < g_liqZoneCount; k++)
         {
            if(!g_liquidityZones[k].isHigh && MathAbs(g_liquidityZones[k].price - l) <= tolerance)
            {
               foundSimilar = true;
               similarIdx = k;
               break;
            }
         }
         
         if(foundSimilar && similarIdx >= 0)
         {
            g_liquidityZones[similarIdx].touches++;
            g_liquidityZones[similarIdx].strength++;
         }
         else
         {
            LiquidityZone lz;
            lz.price = l;
            lz.touches = 1;
            lz.lastTouch = iTime(_Symbol, PERIOD_M5, i);
            lz.swept = false;
            lz.strength = 1;
            lz.isHigh = false;
            g_liquidityZones[g_liqZoneCount++] = lz;
         }
      }
   }
}

//=====================================================================
//  CORRELATION ANALYSIS (Gold vs USD)
//=====================================================================

void UpdateCorrelationAnalysis()
{
   if(!InpEnableCorrelation) return;
   
   // Simplified correlation proxy using price momentum
   double goldChanges[20], usdProxyChanges[20];
   
   for(int i = 0; i < 20; i++)
   {
      double goldClose = iClose(_Symbol, PERIOD_H1, i);
      double goldPrev = iClose(_Symbol, PERIOD_H1, i+1);
      goldChanges[i] = goldClose - goldPrev;
      
      // USD proxy: inverse of gold movement (simplified)
      usdProxyChanges[i] = -goldChanges[i];
   }
   
   // Calculate correlation coefficient
   double sumGold = 0, sumUSD = 0;
   for(int i = 0; i < 20; i++)
   {
      sumGold += goldChanges[i];
      sumUSD += usdProxyChanges[i];
   }
   
   double meanGold = sumGold / 20.0;
   double meanUSD = sumUSD / 20.0;
   
   double numerator = 0, denomGold = 0, denomUSD = 0;
   
   for(int i = 0; i < 20; i++)
   {
      double diffGold = goldChanges[i] - meanGold;
      double diffUSD = usdProxyChanges[i] - meanUSD;
      
      numerator += diffGold * diffUSD;
      denomGold += diffGold * diffGold;
      denomUSD += diffUSD * diffUSD;
   }
   
   if(denomGold > 0 && denomUSD > 0)
      g_correlation.dxyCorrelation = numerator / MathSqrt(denomGold * denomUSD);
   else
      g_correlation.dxyCorrelation = 0;
      
   g_correlation.usdStrength = (g_correlation.dxyCorrelation < -0.5) ? 80 : 50;
   g_correlation.goldUSDScore = MathAbs(g_correlation.dxyCorrelation) * 100.0;
   
   // Detect divergence
   g_correlation.divergenceDetected = (MathAbs(g_correlation.dxyCorrelation) < 0.3);
   g_correlation.divergenceStrength = g_correlation.divergenceDetected ? 7 : 0;
}

//=====================================================================
//  VOLATILITY ANALYSIS
//=====================================================================

ENUM_VOL_STATE AnalyzeVolatility()
{
   double atr[1];
   double atrArray[50];
   
   if(CopyBuffer(g_m5_atr, 0, 0, 1, atr) <= 0) return VOL_NORMAL;
   if(CopyBuffer(g_m5_atr, 0, 0, 50, atrArray) < 50) return VOL_NORMAL;
   
   double currentATR = atr[0];
   
   // Calculate ATR statistics
   double sum = 0;
   for(int i = 0; i < 50; i++) sum += atrArray[i];
   double avgATR = sum / 50.0;
   
   // Calculate percentile
   int below = 0;
   for(int i = 0; i < 50; i++)
      if(atrArray[i] <= currentATR) below++;
   
   double percentile = (below / 50.0) * 100.0;
   
   // Classify volatility
   if(percentile < 10) return VOL_EXTREME_LOW;
   if(percentile < 30) return VOL_LOW;
   if(percentile < 70) return VOL_NORMAL;
   if(percentile < 90) return VOL_HIGH;
   if(percentile < 95) return VOL_EXTREME;
   return VOL_SPIKE;
}

//=====================================================================
//  REGIME CLASSIFICATION
//=====================================================================

void ClassifyMarketRegime()
{
   // Multi-factor regime classification
   ENUM_VOL_STATE volState = g_currentVolState;
   
   double emaFast[1], emaSlow[1], rsi[1], adx[1];
   
   if(CopyBuffer(g_m5_ema_fast, 0, 0, 1, emaFast) <= 0) return;
   if(CopyBuffer(g_m5_ema_slow, 0, 0, 1, emaSlow) <= 0) return;
   if(CopyBuffer(g_m5_rsi, 0, 0, 1, rsi) <= 0) return;
   if(CopyBuffer(g_m5_adx, 0, 0, 1, adx) <= 0) adx[0] = 20;
   
   double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   
   // Determine regime
   if(volState == VOL_SPIKE || volState == VOL_EXTREME)
   {
      g_currentRegime = REGIME_VOLATILITY_SHOCK;
   }
   else if(adx[0] > 30 && MathAbs(emaFast[0] - emaSlow[0]) > currentPrice * 0.001)
   {
      g_currentRegime = REGIME_TRENDING;
   }
   else if(adx[0] < 20 && volState == VOL_LOW)
   {
      g_currentRegime = REGIME_RANGING;
   }
   else if(volState == VOL_EXTREME_LOW)
   {
      g_currentRegime = REGIME_COMPRESSION;
   }
   else if(volState == VOL_HIGH)
   {
      g_currentRegime = REGIME_EXPANSION;
   }
   else if((rsi[0] > 75 || rsi[0] < 25) && adx[0] < 25)
   {
      g_currentRegime = REGIME_MEAN_REVERSION;
   }
   else if(g_chochCount > 0)
   {
      g_currentRegime = REGIME_LIQUIDITY_SWEEP;
   }
   else
   {
      g_currentRegime = REGIME_CONSOLIDATION;
   }
}

//=====================================================================
//  DYNAMIC RISK CALCULATION
//=====================================================================

void CalculateDynamicRisk()
{
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   
   // Base lot calculation
   double baseRisk = InpBaseRiskPercent;
   
   // Account size adjustment
   if(InpEnableAccountScaling)
   {
      if(equity < InpSmallAccountThreshold)
         g_dynamicRisk.accountSizeAdjustment = 0.7; // Conservative for small accounts
      else if(equity > InpLargeAccountThreshold)
         g_dynamicRisk.accountSizeAdjustment = 1.3; // More aggressive for large accounts
      else
         g_dynamicRisk.accountSizeAdjustment = 1.0;
   }
   else
   {
      g_dynamicRisk.accountSizeAdjustment = 1.0;
   }
   
   // Volatility adjustment
   if(InpEnableVolatilityRisk)
   {
      switch(g_currentVolState)
      {
         case VOL_EXTREME_LOW: g_dynamicRisk.volatilityAdjustment = 1.2; break;
         case VOL_LOW:         g_dynamicRisk.volatilityAdjustment = 1.1; break;
         case VOL_NORMAL:      g_dynamicRisk.volatilityAdjustment = 1.0; break;
         case VOL_HIGH:        g_dynamicRisk.volatilityAdjustment = 0.8; break;
         case VOL_EXTREME:     g_dynamicRisk.volatilityAdjustment = 0.6; break;
         case VOL_SPIKE:       g_dynamicRisk.volatilityAdjustment = 0.3; break;
      }
   }
   else
   {
      g_dynamicRisk.volatilityAdjustment = 1.0;
   }
   
   // Win/loss streak adjustment
   if(g_sessionWins >= 3)
      g_dynamicRisk.winStreakBonus = 1.1;
   else
      g_dynamicRisk.winStreakBonus = 1.0;
      
   if(g_sessionLosses >= 2)
      g_dynamicRisk.lossStreakPenalty = 0.7;
   else if(g_sessionLosses >= 3)
      g_dynamicRisk.lossStreakPenalty = 0.5;
   else
      g_dynamicRisk.lossStreakPenalty = 1.0;
   
   // Session adjustment
   switch(g_currentSession)
   {
      case SESSION_LONDON_OPEN:
      case SESSION_NY_OVERLAP:
         g_dynamicRisk.sessionAdjustment = 1.2; break; // Best sessions
      case SESSION_ASIAN:
         g_dynamicRisk.sessionAdjustment = 0.8; break; // Lower liquidity
      default:
         g_dynamicRisk.sessionAdjustment = 1.0;
   }
   
   // Calculate final multiplier
   g_dynamicRisk.currentMultiplier = 
      g_dynamicRisk.accountSizeAdjustment *
      g_dynamicRisk.volatilityAdjustment *
      g_dynamicRisk.winStreakBonus *
      g_dynamicRisk.lossStreakPenalty *
      g_dynamicRisk.sessionAdjustment;
   
   // Calculate final risk percent
   g_dynamicRisk.riskPercent = baseRisk * g_dynamicRisk.currentMultiplier;
   g_dynamicRisk.riskPercent = MathMax(InpMinRiskPercent, MathMin(InpMaxRiskPercent, g_dynamicRisk.riskPercent));
   
   // Dynamic SL/TP in ATR multiples
   double atr[1];
   if(CopyBuffer(g_m5_atr, 0, 0, 1, atr) > 0)
   {
      switch(g_currentVolState)
      {
         case VOL_EXTREME_LOW: 
            g_dynamicRisk.dynamicSL_ATR = 1.2;
            g_dynamicRisk.dynamicTP_ATR = 2.0;
            break;
         case VOL_LOW:
            g_dynamicRisk.dynamicSL_ATR = 1.5;
            g_dynamicRisk.dynamicTP_ATR = 2.5;
            break;
         case VOL_NORMAL:
            g_dynamicRisk.dynamicSL_ATR = 2.0;
            g_dynamicRisk.dynamicTP_ATR = 3.0;
            break;
         case VOL_HIGH:
            g_dynamicRisk.dynamicSL_ATR = 2.5;
            g_dynamicRisk.dynamicTP_ATR = 4.0;
            break;
         default:
            g_dynamicRisk.dynamicSL_ATR = 3.0;
            g_dynamicRisk.dynamicTP_ATR = 5.0;
      }
   }
}

double CalculateLotSize(double slDistance)
{
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   double riskAmount = equity * (g_dynamicRisk.riskPercent / 100.0);
   
   double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   
   if(tickValue <= 0 || tickSize <= 0 || slDistance <= 0) return 0;
   
   double lot = riskAmount / (slDistance * (tickValue / tickSize));
   
   double lotMin = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double lotMax = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   
   lot = MathFloor(lot / lotStep) * lotStep;
   lot = MathMax(lotMin, MathMin(lotMax, lot));
   
   g_dynamicRisk.finalLotSize = lot;
   
   return lot;
}

//=====================================================================
//  STRATEGY INITIALIZATION
//=====================================================================

void InitializeStrategies()
{
   string names[] = {
      "NONE", "FVG Scalp", "Order Block", "Liquidity Grab", "Breakout Retest",
      "Asian Breakout", "London Killzone", "NY Reversal", "Premium/Discount",
      "Imbalance Fill", "Trend Continuation", "Momentum Scalp", "Correlation Div"
   };
   
   for(int i = 0; i < 13; i++)
   {
      g_strategies[i].strategy = (ENUM_GOLD_STRATEGY)i;
      g_strategies[i].name = names[i];
      g_strategies[i].totalTrades = 0;
      g_strategies[i].wins = 0;
      g_strategies[i].losses = 0;
      g_strategies[i].grossProfit = 0;
      g_strategies[i].grossLoss = 0;
      g_strategies[i].profitFactor = 0;
      g_strategies[i].winRate = 0;
      g_strategies[i].avgWin = 0;
      g_strategies[i].avgLoss = 0;
      g_strategies[i].expectancy = 0;
      g_strategies[i].sharpe = 0;
      g_strategies[i].maxDD = 0;
      g_strategies[i].consecWins = 0;
      g_strategies[i].consecLosses = 0;
      g_strategies[i].maxConsecWins = 0;
      g_strategies[i].maxConsecLosses = 0;
      g_strategies[i].currentWeight = 1.0;
      g_strategies[i].enabled = true;
      g_strategies[i].bestSession = SESSION_LONDON_OPEN;
      g_strategies[i].bestVolatility = VOL_NORMAL;
      g_strategies[i].lastTrade = 0;
   }
}

void UpdateStrategyWeights()
{
   if(!InpEnableML || !InpML_AdaptiveWeights) return;
   
   for(int i = 1; i < 13; i++)
   {
      if(g_strategies[i].totalTrades < 5)
      {
         g_strategies[i].currentWeight = 1.0;
         continue;
      }
      
      // Calculate performance score
      double score = 0;
      
      // Win rate component (30%)
      score += (g_strategies[i].winRate / 100.0) * 0.3;
      
      // Profit factor component (30%)
      if(g_strategies[i].profitFactor > 0)
         score += MathMin(1.0, g_strategies[i].profitFactor / 2.0) * 0.3;
      
      // Expectancy component (25%)
      if(g_strategies[i].expectancy > 0)
         score += MathMin(1.0, g_strategies[i].expectancy / 2.0) * 0.25;
      
      // Consistency component (15%)
      double consistency = 1.0 - (g_strategies[i].maxConsecLosses / 10.0);
      score += MathMax(0, consistency) * 0.15;
      
      // Convert score to weight (0.5 to 1.5 range)
      g_strategies[i].currentWeight = 0.5 + score;
      
      // Disable if performing poorly
      if(g_strategies[i].totalTrades >= 10)
      {
         if(g_strategies[i].winRate < 35 || g_strategies[i].profitFactor < 0.8)
            g_strategies[i].enabled = false;
         else
            g_strategies[i].enabled = true;
      }
   }
}

void RegisterStrategyResult(ENUM_GOLD_STRATEGY strat, double profit)
{
   int idx = (int)strat;
   if(idx < 0 || idx >= 13) return;
   
   g_strategies[idx].totalTrades++;
   
   if(profit >= 0)
   {
      g_strategies[idx].wins++;
      g_strategies[idx].grossProfit += profit;
      g_strategies[idx].consecWins++;
      g_strategies[idx].consecLosses = 0;
      
      if(g_strategies[idx].consecWins > g_strategies[idx].maxConsecWins)
         g_strategies[idx].maxConsecWins = g_strategies[idx].consecWins;
      
      g_strategies[idx].avgWin = g_strategies[idx].grossProfit / g_strategies[idx].wins;
   }
   else
   {
      g_strategies[idx].losses++;
      g_strategies[idx].grossLoss += MathAbs(profit);
      g_strategies[idx].consecLosses++;
      g_strategies[idx].consecWins = 0;
      
      if(g_strategies[idx].consecLosses > g_strategies[idx].maxConsecLosses)
         g_strategies[idx].maxConsecLosses = g_strategies[idx].consecLosses;
      
      g_strategies[idx].avgLoss = g_strategies[idx].grossLoss / g_strategies[idx].losses;
   }
   
   // Update statistics
   g_strategies[idx].winRate = (100.0 * g_strategies[idx].wins) / g_strategies[idx].totalTrades;
   
   if(g_strategies[idx].grossLoss > 0)
      g_strategies[idx].profitFactor = g_strategies[idx].grossProfit / g_strategies[idx].grossLoss;
   else
      g_strategies[idx].profitFactor = (g_strategies[idx].grossProfit > 0) ? 99 : 0;
   
   if(g_strategies[idx].totalTrades > 0)
   {
      double avgWin = (g_strategies[idx].wins > 0) ? g_strategies[idx].avgWin : 0;
      double avgLoss = (g_strategies[idx].losses > 0) ? g_strategies[idx].avgLoss : 0;
      double winProb = g_strategies[idx].winRate / 100.0;
      
      g_strategies[idx].expectancy = (winProb * avgWin) - ((1 - winProb) * avgLoss);
   }
   
   g_strategies[idx].lastTrade = TimeCurrent();
}

//=====================================================================
//  GOLD SCALPING STRATEGIES
//=====================================================================

// Strategy 1: FVG Scalping
GoldSignal Strategy_FVG_Scalp()
{
   GoldSignal signal;
   signal.valid = false;
   signal.strategy = STRAT_FVG_SCALP;
   
   if(g_fvgCount == 0) 
   {
      signal.narrative = "No FVG detected";
      return signal;
   }
   
   double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double atr[1];
   if(CopyBuffer(g_m5_atr, 0, 0, 1, atr) <= 0) return signal;
   
   // Look for price approaching unfilled FVG
   for(int i = 0; i < g_fvgCount; i++)
   {
      if(g_fvgArray[i].filled) continue;
      if(g_fvgArray[i].strength < 5) continue;
      
      double distanceToFVG = MathAbs(currentPrice - g_fvgArray[i].middle);
      
      if(distanceToFVG < atr[0] * 0.5) // Close to FVG
      {
         if(g_fvgArray[i].bullish && currentPrice <= g_fvgArray[i].top && currentPrice >= g_fvgArray[i].bottom)
         {
            signal.direction = DIR_LONG;
            signal.entryPrice = currentPrice;
            signal.slPrice = NPrice(g_fvgArray[i].bottom - atr[0] * 0.3);
            signal.tp1Price = NPrice(currentPrice + atr[0] * 1.5);
            signal.tp2Price = NPrice(currentPrice + atr[0] * 2.5);
            signal.tp3Price = NPrice(currentPrice + atr[0] * 3.5);
            signal.quality.smartMoneyScore = g_fvgArray[i].strength * 10;
            signal.narrative = "Bullish FVG entry";
            signal.valid = true;
            return signal;
         }
         else if(!g_fvgArray[i].bullish && currentPrice <= g_fvgArray[i].top && currentPrice >= g_fvgArray[i].bottom)
         {
            signal.direction = DIR_SHORT;
            signal.entryPrice = currentPrice;
            signal.slPrice = NPrice(g_fvgArray[i].top + atr[0] * 0.3);
            signal.tp1Price = NPrice(currentPrice - atr[0] * 1.5);
            signal.tp2Price = NPrice(currentPrice - atr[0] * 2.5);
            signal.tp3Price = NPrice(currentPrice - atr[0] * 3.5);
            signal.quality.smartMoneyScore = g_fvgArray[i].strength * 10;
            signal.narrative = "Bearish FVG entry";
            signal.valid = true;
            return signal;
         }
      }
   }
   
   signal.narrative = "No FVG setup";
   return signal;
}

// Strategy 2: Order Block Reversal
GoldSignal Strategy_OrderBlock_Reversal()
{
   GoldSignal signal;
   signal.valid = false;
   signal.strategy = STRAT_ORDER_BLOCK_REVERSAL;
   
   if(g_obCount == 0) 
   {
      signal.narrative = "No order blocks";
      return signal;
   }
   
   double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double atr[1];
   if(CopyBuffer(g_m5_atr, 0, 0, 1, atr) <= 0) return signal;
   
   // Find nearest untested order block
   for(int i = 0; i < g_obCount; i++)
   {
      if(g_orderBlocks[i].tested) continue;
      if(!g_orderBlocks[i].valid) continue;
      
      if(g_orderBlocks[i].type == OB_BULLISH && currentPrice >= g_orderBlocks[i].low && currentPrice <= g_orderBlocks[i].high)
      {
         signal.direction = DIR_LONG;
         signal.entryPrice = currentPrice;
         signal.slPrice = NPrice(g_orderBlocks[i].low - atr[0] * 0.5);
         signal.tp1Price = NPrice(currentPrice + atr[0] * 2.0);
         signal.tp2Price = NPrice(currentPrice + atr[0] * 3.0);
         signal.tp3Price = NPrice(currentPrice + atr[0] * 4.0);
         signal.quality.smartMoneyScore = g_orderBlocks[i].strength * 10;
         signal.narrative = "Bullish OB reaction";
         signal.valid = true;
         return signal;
      }
      else if(g_orderBlocks[i].type == OB_BEARISH && currentPrice >= g_orderBlocks[i].low && currentPrice <= g_orderBlocks[i].high)
      {
         signal.direction = DIR_SHORT;
         signal.entryPrice = currentPrice;
         signal.slPrice = NPrice(g_orderBlocks[i].high + atr[0] * 0.5);
         signal.tp1Price = NPrice(currentPrice - atr[0] * 2.0);
         signal.tp2Price = NPrice(currentPrice - atr[0] * 3.0);
         signal.tp3Price = NPrice(currentPrice - atr[0] * 4.0);
         signal.quality.smartMoneyScore = g_orderBlocks[i].strength * 10;
         signal.narrative = "Bearish OB reaction";
         signal.valid = true;
         return signal;
      }
   }
   
   signal.narrative = "No OB setup";
   return signal;
}

// Strategy 3: Premium/Discount Zone Trading
GoldSignal Strategy_PremiumDiscount()
{
   GoldSignal signal;
   signal.valid = false;
   signal.strategy = STRAT_PREMIUM_DISCOUNT;
   
   double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double atr[1];
   double rsi[1];
   
   if(CopyBuffer(g_m5_atr, 0, 0, 1, atr) <= 0) return signal;
   if(CopyBuffer(g_m5_rsi, 0, 0, 1, rsi) <= 0) return signal;
   
   // Sell from premium, buy from discount
   if(g_premiumDiscount.currentLevel >= 70 && rsi[0] > 60) // In premium + overbought
   {
      signal.direction = DIR_SHORT;
      signal.entryPrice = currentPrice;
      signal.slPrice = NPrice(currentPrice + atr[0] * g_dynamicRisk.dynamicSL_ATR);
      signal.tp1Price = NPrice(g_premiumDiscount.equilibrium);
      signal.tp2Price = NPrice(g_premiumDiscount.discountZone);
      signal.tp3Price = NPrice(g_premiumDiscount.extremeDiscount);
      signal.quality.smartMoneyScore = 75;
      signal.narrative = "Premium zone short";
      signal.valid = true;
      return signal;
   }
   else if(g_premiumDiscount.currentLevel <= 30 && rsi[0] < 40) // In discount + oversold
   {
      signal.direction = DIR_LONG;
      signal.entryPrice = currentPrice;
      signal.slPrice = NPrice(currentPrice - atr[0] * g_dynamicRisk.dynamicSL_ATR);
      signal.tp1Price = NPrice(g_premiumDiscount.equilibrium);
      signal.tp2Price = NPrice(g_premiumDiscount.premiumZone);
      signal.tp3Price = NPrice(g_premiumDiscount.extremePremium);
      signal.quality.smartMoneyScore = 75;
      signal.narrative = "Discount zone long";
      signal.valid = true;
      return signal;
   }
   
   signal.narrative = "Not in extreme zone";
   return signal;
}

// Strategy 4: Liquidity Grab
GoldSignal Strategy_LiquidityGrab()
{
   GoldSignal signal;
   signal.valid = false;
   signal.strategy = STRAT_LIQUIDITY_GRAB;
   
   if(g_liqZoneCount == 0)
   {
      signal.narrative = "No liquidity zones";
      return signal;
   }
   
   double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double atr[1];
   if(CopyBuffer(g_m5_atr, 0, 0, 1, atr) <= 0) return signal;
   
   // Check for sweep + rejection
   double currentHigh = iHigh(_Symbol, PERIOD_M5, 0);
   double currentLow = iLow(_Symbol, PERIOD_M5, 0);
   double prevClose = iClose(_Symbol, PERIOD_M5, 1);
   
   for(int i = 0; i < g_liqZoneCount; i++)
   {
      if(g_liquidityZones[i].touches < 2) continue;
      
      // Bullish: sweep below liquidity, close above
      if(!g_liquidityZones[i].isHigh && currentLow < g_liquidityZones[i].price && currentPrice > g_liquidityZones[i].price)
      {
         signal.direction = DIR_LONG;
         signal.entryPrice = currentPrice;
         signal.slPrice = NPrice(currentLow - atr[0] * 0.3);
         signal.tp1Price = NPrice(currentPrice + atr[0] * 2.5);
         signal.tp2Price = NPrice(currentPrice + atr[0] * 3.5);
         signal.tp3Price = NPrice(currentPrice + atr[0] * 5.0);
         signal.quality.smartMoneyScore = g_liquidityZones[i].strength * 15;
         signal.narrative = "Liquidity sweep long";
         signal.valid = true;
         return signal;
      }
      
      // Bearish: sweep above liquidity, close below
      if(g_liquidityZones[i].isHigh && currentHigh > g_liquidityZones[i].price && currentPrice < g_liquidityZones[i].price)
      {
         signal.direction = DIR_SHORT;
         signal.entryPrice = currentPrice;
         signal.slPrice = NPrice(currentHigh + atr[0] * 0.3);
         signal.tp1Price = NPrice(currentPrice - atr[0] * 2.5);
         signal.tp2Price = NPrice(currentPrice - atr[0] * 3.5);
         signal.tp3Price = NPrice(currentPrice - atr[0] * 5.0);
         signal.quality.smartMoneyScore = g_liquidityZones[i].strength * 15;
         signal.narrative = "Liquidity sweep short";
         signal.valid = true;
         return signal;
      }
   }
   
   signal.narrative = "No sweep detected";
   return signal;
}

// Strategy 5: London Killzone
GoldSignal Strategy_LondonKillzone()
{
   GoldSignal signal;
   signal.valid = false;
   signal.strategy = STRAT_LONDON_KILLZONE;
   
   if(g_currentSession != SESSION_LONDON_OPEN)
   {
      signal.narrative = "Not London session";
      return signal;
   }
   
   double atr[1], rsi[1], macdMain[1], macdSignal[1];
   
   if(CopyBuffer(g_m5_atr, 0, 0, 1, atr) <= 0) return signal;
   if(CopyBuffer(g_m5_rsi, 0, 0, 1, rsi) <= 0) return signal;
   if(CopyBuffer(g_m5_ema_fast, 0, 0, 1, macdMain) <= 0) return signal;
   
   double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   
   // Strong momentum trades during London open
   if(rsi[0] > 55 && g_structure.uptrendActive)
   {
      signal.direction = DIR_LONG;
      signal.entryPrice = currentPrice;
      signal.slPrice = NPrice(currentPrice - atr[0] * 2.0);
      signal.tp1Price = NPrice(currentPrice + atr[0] * 3.0);
      signal.tp2Price = NPrice(currentPrice + atr[0] * 5.0);
      signal.tp3Price = NPrice(currentPrice + atr[0] * 7.0);
      signal.quality.sessionScore = 90;
      signal.narrative = "London killzone long";
      signal.valid = true;
      return signal;
   }
   else if(rsi[0] < 45 && g_structure.downtrendActive)
   {
      signal.direction = DIR_SHORT;
      signal.entryPrice = currentPrice;
      signal.slPrice = NPrice(currentPrice + atr[0] * 2.0);
      signal.tp1Price = NPrice(currentPrice - atr[0] * 3.0);
      signal.tp2Price = NPrice(currentPrice - atr[0] * 5.0);
      signal.tp3Price = NPrice(currentPrice - atr[0] * 7.0);
      signal.quality.sessionScore = 90;
      signal.narrative = "London killzone short";
      signal.valid = true;
      return signal;
   }
   
   signal.narrative = "No London setup";
   return signal;
}

//=====================================================================
//  SIGNAL QUALITY ASSESSMENT
//=====================================================================

void AssessSignalQuality(GoldSignal &signal)
{
   // Indicator alignment
   double emaFast[1], emaMed[1], emaSlow[1], rsi[1], adx[1];
   
   if(CopyBuffer(g_m5_ema_fast, 0, 0, 1, emaFast) > 0 &&
      CopyBuffer(g_m5_ema_medium, 0, 0, 1, emaMed) > 0 &&
      CopyBuffer(g_m5_ema_slow, 0, 0, 1, emaSlow) > 0)
   {
      bool aligned = (signal.direction == DIR_LONG && emaFast[0] > emaMed[0] && emaMed[0] > emaSlow[0]) ||
                     (signal.direction == DIR_SHORT && emaFast[0] < emaMed[0] && emaMed[0] < emaSlow[0]);
      
      signal.quality.indicatorAlignment = aligned ? 100 : 50;
   }
   
   // Market structure score
   signal.quality.marketStructureScore = g_structure.structureStrength;
   
   // Volume confirmation (simplified - using bar size as proxy)
   double currentRange = iHigh(_Symbol, PERIOD_M5, 0) - iLow(_Symbol, PERIOD_M5, 0);
   double avgRange = 0;
   for(int i = 1; i <= 10; i++)
      avgRange += iHigh(_Symbol, PERIOD_M5, i) - iLow(_Symbol, PERIOD_M5, i);
   avgRange /= 10.0;
   
   signal.quality.volumeConfirmation = (avgRange > 0) ? MathMin(100, (currentRange / avgRange) * 100) : 50;
   
   // Session score
   switch(g_currentSession)
   {
      case SESSION_LONDON_OPEN:
      case SESSION_NY_OVERLAP:
         signal.quality.sessionScore = 100;
         break;
      case SESSION_NY_PM:
         signal.quality.sessionScore = 75;
         break;
      case SESSION_ASIAN:
         signal.quality.sessionScore = 60;
         break;
      default:
         signal.quality.sessionScore = 30;
   }
   
   // Volatility score
   switch(g_currentVolState)
   {
      case VOL_NORMAL:
      case VOL_HIGH:
         signal.quality.volatilityScore = 100;
         break;
      case VOL_LOW:
         signal.quality.volatilityScore = 70;
         break;
      case VOL_EXTREME:
         signal.quality.volatilityScore = 50;
         break;
      default:
         signal.quality.volatilityScore = 30;
   }
   
   // Momentum score
   if(CopyBuffer(g_m5_rsi, 0, 0, 1, rsi) > 0)
   {
      if(signal.direction == DIR_LONG)
         signal.quality.momentumScore = MathMax(0, rsi[0] - 30) * 1.43; // Scale 30-100 to 0-100
      else
         signal.quality.momentumScore = MathMax(0, 70 - rsi[0]) * 1.43; // Scale 0-70 to 0-100
   }
   
   // ML confidence (simplified - based on strategy performance)
   int stratIdx = (int)signal.strategy;
   if(stratIdx >= 0 && stratIdx < 13 && g_strategies[stratIdx].totalTrades >= 10)
   {
      signal.quality.mlConfidence = g_strategies[stratIdx].winRate * g_strategies[stratIdx].currentWeight;
   }
   else
   {
      signal.quality.mlConfidence = 70; // Default for new strategies
   }
   
   // Composite score
   signal.quality.compositeScore = 
      signal.quality.indicatorAlignment * 0.15 +
      signal.quality.marketStructureScore * 0.15 +
      signal.quality.volumeConfirmation * 0.10 +
      signal.quality.sessionScore * 0.15 +
      signal.quality.volatilityScore * 0.10 +
      signal.quality.momentumScore * 0.10 +
      signal.quality.smartMoneyScore * 0.15 +
      signal.quality.mlConfidence * 0.10;
   
   signal.quality.signalStrength = (int)MathMin(10, signal.quality.compositeScore / 10.0);
}

//=====================================================================
//  MASTER SIGNAL GENERATOR
//=====================================================================

GoldSignal GenerateBestSignal()
{
   GoldSignal signals[13];
   int signalCount = 0;
   
   // Generate signals from all enabled strategies
   if(g_strategies[1].enabled) signals[signalCount++] = Strategy_FVG_Scalp();
   if(g_strategies[2].enabled) signals[signalCount++] = Strategy_OrderBlock_Reversal();
   if(g_strategies[3].enabled) signals[signalCount++] = Strategy_LiquidityGrab();
   if(g_strategies[8].enabled) signals[signalCount++] = Strategy_PremiumDiscount();
   if(g_strategies[6].enabled && g_currentSession == SESSION_LONDON_OPEN) 
      signals[signalCount++] = Strategy_LondonKillzone();
   
   // Assess quality for each signal
   for(int i = 0; i < signalCount; i++)
   {
      if(signals[i].valid)
         AssessSignalQuality(signals[i]);
   }
   
   // Find best signal
   int bestIdx = -1;
   double bestScore = 0;
   
   for(int i = 0; i < signalCount; i++)
   {
      if(!signals[i].valid) continue;
      
      // Apply strategy weight
      int stratIdx = (int)signals[i].strategy;
      double weightedScore = signals[i].quality.compositeScore * g_strategies[stratIdx].currentWeight;
      
      if(weightedScore > bestScore)
      {
         bestScore = weightedScore;
         bestIdx = i;
      }
   }
   
   if(bestIdx >= 0)
   {
      signals[bestIdx].timestamp = TimeCurrent();
      return signals[bestIdx];
   }
   
   // Return invalid signal
   GoldSignal emptySignal;
   emptySignal.valid = false;
   emptySignal.narrative = "No valid signals";
   return emptySignal;
}

//=====================================================================
//  RISK CHECKS
//=====================================================================

bool RiskChecksPass(string &reason)
{
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   
   // Daily loss limit
   double dayPL = equity - g_dayStartEquity;
   if(dayPL < 0 && MathAbs(dayPL) >= g_dayStartEquity * (InpMaxDailyLossPct / 100.0))
   {
      reason = "Daily loss limit hit";
      return false;
   }
   
   // Weekly loss limit
   double weekPL = equity - g_weekStartEquity;
   if(weekPL < 0 && MathAbs(weekPL) >= g_weekStartEquity * (InpMaxWeeklyLossPct / 100.0))
   {
      reason = "Weekly loss limit hit";
      return false;
   }
   
   // Drawdown limit
   double currentDD = (g_peakEquity - equity) / g_peakEquity * 100.0;
   if(currentDD >= InpMaxDrawdownPct)
   {
      reason = "Max drawdown exceeded";
      return false;
   }
   
   // Daily trade limit
   if(g_tradesToday >= InpMaxDailyTrades)
   {
      reason = "Daily trade limit reached";
      return false;
   }
   
   // Concurrent trades
   if(PositionsTotalForMagic() >= InpMaxConcurrentTrades)
   {
      reason = "Max concurrent positions";
      return false;
   }
   
   // Spread check
   double spread = (double)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   if(spread > InpGoldSpreadMax)
   {
      reason = "Spread too high";
      return false;
   }
   
   // Session check
   if(!IsSessionAllowed(g_currentSession))
   {
      reason = "Session not allowed";
      return false;
   }
   
   return true;
}

//=====================================================================
//  TRADE EXECUTION
//=====================================================================

bool ExecuteSignal(GoldSignal &signal)
{
   if(!signal.valid) return false;
   
   double atr[1];
   if(CopyBuffer(g_m5_atr, 0, 0, 1, atr) <= 0) return false;
   
   double slDistance = MathAbs(signal.entryPrice - signal.slPrice);
   double lotSize = CalculateLotSize(slDistance);
   
   if(lotSize <= 0)
   {
      Print("Invalid lot size calculated");
      return false;
   }
   
   g_trade.SetExpertMagicNumber(InpMagicNumber);
   g_trade.SetDeviationInPoints(30);
   g_trade.SetTypeFilling(GetFillMode());
   
   string comment = InpBotName + "|" + IntegerToString((int)signal.strategy);
   
   bool result = false;
   
   if(signal.direction == DIR_LONG)
   {
      result = g_trade.Buy(lotSize, _Symbol, signal.entryPrice, signal.slPrice, signal.tp1Price, comment);
   }
   else if(signal.direction == DIR_SHORT)
   {
      result = g_trade.Sell(lotSize, _Symbol, signal.entryPrice, signal.slPrice, signal.tp1Price, comment);
   }
   
   if(result)
   {
      g_tradesToday++;
      g_lastTradeTime = TimeCurrent();
      g_statusText = "IN TRADE";
      g_statusColor = C_GREEN;
      g_lastAction = signal.narrative;
      
      Print("✓ Trade executed: ", signal.narrative, " | Lot: ", lotSize, " | SL: ", signal.slPrice, " | TP: ", signal.tp1Price);
   }
   else
   {
      Print("✗ Trade execution failed: ", g_trade.ResultRetcode());
   }
   
   return result;
}

//=====================================================================
//  VISUAL OVERLAYS
//=====================================================================

void DrawFVGZones()
{
   if(!InpDrawFVG) return;
   
   datetime now = TimeCurrent();
   datetime past = now - 4 * 3600; // 4 hours lookback
   
   for(int i = 0; i < g_fvgCount; i++)
   {
      string name = "FVG_" + IntegerToString(i);
      
      ObjectDelete(0, name);
      
      if(g_fvgArray[i].filled) continue;
      
      if(ObjectCreate(0, name, OBJ_RECTANGLE, 0, past, g_fvgArray[i].top, now, g_fvgArray[i].bottom))
      {
         color fvgColor = g_fvgArray[i].bullish ? C_FVG_BULL : C_FVG_BEAR;
         ObjectSetInteger(0, name, OBJPROP_COLOR, fvgColor);
         ObjectSetInteger(0, name, OBJPROP_FILL, true);
         ObjectSetInteger(0, name, OBJPROP_BACK, true);
         ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
         ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
      }
   }
}

void DrawOrderBlockZones()
{
   if(!InpDrawOrderBlocks) return;
   
   datetime now = TimeCurrent();
   datetime past = now - 6 * 3600;
   
   for(int i = 0; i < g_obCount; i++)
   {
      if(!g_orderBlocks[i].valid) continue;
      
      string name = "OB_" + IntegerToString(i);
      ObjectDelete(0, name);
      
      if(ObjectCreate(0, name, OBJ_RECTANGLE, 0, g_orderBlocks[i].time, g_orderBlocks[i].high, now, g_orderBlocks[i].low))
      {
         color obColor = (g_orderBlocks[i].type == OB_BULLISH) ? C_OB_BULL : C_OB_BEAR;
         ObjectSetInteger(0, name, OBJPROP_COLOR, obColor);
         ObjectSetInteger(0, name, OBJPROP_FILL, true);
         ObjectSetInteger(0, name, OBJPROP_BACK, true);
         ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
         ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
         ObjectSetInteger(0, name, OBJPROP_WIDTH, g_orderBlocks[i].tested ? 1 : 2);
      }
   }
}

void DrawPremiumDiscountZones()
{
   if(!InpDrawPremiumDiscount) return;
   
   datetime now = TimeCurrent();
   datetime past = now - 8 * 3600;
   
   // Equilibrium line
   string eqName = "PD_EQ";
   ObjectDelete(0, eqName);
   if(ObjectCreate(0, eqName, OBJ_TREND, 0, past, g_premiumDiscount.equilibrium, now, g_premiumDiscount.equilibrium))
   {
      ObjectSetInteger(0, eqName, OBJPROP_COLOR, C_GOLD);
      ObjectSetInteger(0, eqName, OBJPROP_STYLE, STYLE_DOT);
      ObjectSetInteger(0, eqName, OBJPROP_WIDTH, 2);
      ObjectSetInteger(0, eqName, OBJPROP_BACK, false);
      ObjectSetInteger(0, eqName, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, eqName, OBJPROP_RAY_RIGHT, true);
   }
   
   // Premium zone
   string premName = "PD_PREM";
   ObjectDelete(0, premName);
   if(ObjectCreate(0, premName, OBJ_RECTANGLE, 0, past, g_premiumDiscount.extremePremium, now, g_premiumDiscount.premiumZone))
   {
      ObjectSetInteger(0, premName, OBJPROP_COLOR, C_PREMIUM);
      ObjectSetInteger(0, premName, OBJPROP_FILL, true);
      ObjectSetInteger(0, premName, OBJPROP_BACK, true);
      ObjectSetInteger(0, premName, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, premName, OBJPROP_HIDDEN, true);
   }
   
   // Discount zone
   string discName = "PD_DISC";
   ObjectDelete(0, discName);
   if(ObjectCreate(0, discName, OBJ_RECTANGLE, 0, past, g_premiumDiscount.discountZone, now, g_premiumDiscount.extremeDiscount))
   {
      ObjectSetInteger(0, discName, OBJPROP_COLOR, C_DISCOUNT);
      ObjectSetInteger(0, discName, OBJPROP_FILL, true);
      ObjectSetInteger(0, discName, OBJPROP_BACK, true);
      ObjectSetInteger(0, discName, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, discName, OBJPROP_HIDDEN, true);
   }
}

void DrawCHoCHMarkers()
{
   if(!InpDrawCHoCH) return;
   
   for(int i = 0; i < g_chochCount; i++)
   {
      string name = "CHOCH_" + IntegerToString(i);
      ObjectDelete(0, name);
      
      if(ObjectCreate(0, name, OBJ_ARROW, 0, g_chochArray[i].time, g_chochArray[i].price))
      {
         ObjectSetInteger(0, name, OBJPROP_ARROWCODE, g_chochArray[i].bullish ? 233 : 234);
         ObjectSetInteger(0, name, OBJPROP_COLOR, g_chochArray[i].bullish ? C_GREEN : C_RED);
         ObjectSetInteger(0, name, OBJPROP_WIDTH, 3);
         ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
      }
   }
}

void UpdateVisualOverlays()
{
   DrawFVGZones();
   DrawOrderBlockZones();
   DrawPremiumDiscountZones();
   DrawCHoCHMarkers();
}

void DeleteAllOverlays()
{
   ObjectsDeleteAll(0, "FVG_");
   ObjectsDeleteAll(0, "OB_");
   ObjectsDeleteAll(0, "PD_");
   ObjectsDeleteAll(0, "CHOCH_");
   ObjectsDeleteAll(0, D);
}

//=====================================================================
//  DASHBOARD (Simplified for space)
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

void L(string nm, int x, int y, string txt, color clr, int fsz, string fnt="Arial")
{
   string n = D + nm;
   ObjectDelete(0, n);
   
   if(ObjectCreate(0, n, OBJ_LABEL, 0, 0, 0))
   {
      ObjectSetInteger(0, n, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(0, n, OBJPROP_XDISTANCE, x);
      ObjectSetInteger(0, n, OBJPROP_YDISTANCE, y);
      ObjectSetString(0, n, OBJPROP_TEXT, txt);
      ObjectSetInteger(0, n, OBJPROP_COLOR, clr);
      ObjectSetInteger(0, n, OBJPROP_FONTSIZE, fsz);
      ObjectSetString(0, n, OBJPROP_FONT, fnt);
      ObjectSetInteger(0, n, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, n, OBJPROP_HIDDEN, true);
   }
}

void U(string nm, string txt, color clr=C_WHITE)
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
   if(!InpShowDashboard) return;
   if(MQLInfoInteger(MQL_TESTER) && !MQLInfoInteger(MQL_VISUAL_MODE)) return;
   
   int X = InpDashX, Y = InpDashY;
   
   // Main frame
   R("frame", X, Y, DW, DH, C_BG0, C_ACBORD, 2);
   
   // Header
   R("hdr", X+2, Y+2, DW-4, 40, C_HDRBAR, C_GOLD, 1);
   L("title", X+10, Y+8, "⚡ QUANTUM PLUS AI 2.0", C_GOLD, 10, "Arial Black");
   L("subtitle", X+10, Y+24, "Elite Gold Scalper", C_CYAN, 7, "Arial");
   
   // Status
   R("status_bg", X+2, Y+44, DW-4, 30, C_BG2, C_BORDER, 1);
   L("status_lbl", X+10, Y+50, "STATUS:", C_SUBTEXT, 7);
   L("status_val", X+70, Y+50, "ANALYZING", C_ORANGE, 8, "Arial Black");
   L("action", X+10, Y+62, "Initializing...", C_SUBTEXT, 6);
   
   // Market Info
   R("mkt_hdr", X+2, Y+76, DW-4, 18, C_HDRBAR, C_BORDER, 1);
   L("mkt_title", X+8, Y+79, "MARKET", C_GOLD, 7, "Arial Black");
   
   R("mkt_body", X+2, Y+94, DW-4, 60, C_BG2, C_BORDER, 1);
   L("price_lbl", X+8, Y+98, "Price:", C_SUBTEXT, 6);
   L("price_val", X+50, Y+98, "0.00", C_WHITE, 8);
   L("spread_lbl", X+200, Y+98, "Spread:", C_SUBTEXT, 6);
   L("spread_val", X+250, Y+98, "0", C_GREEN, 7);
   
   L("session_lbl", X+8, Y+112, "Session:", C_SUBTEXT, 6);
   L("session_val", X+65, Y+112, "LONDON", C_CYAN, 7);
   L("vol_lbl", X+200, Y+112, "Vol:", C_SUBTEXT, 6);
   L("vol_val", X+235, Y+112, "NORMAL", C_GREEN, 7);
   
   L("regime_lbl", X+8, Y+126, "Regime:", C_SUBTEXT, 6);
   L("regime_val", X+60, Y+126, "RANGING", C_ORANGE, 7);
   L("phase_lbl", X+200, Y+126, "Phase:", C_SUBTEXT, 6);
   L("phase_val", X+245, Y+126, "ACCUMULATION", C_PURPLE, 6);
   
   // Smart Money
   R("sm_hdr", X+2, Y+156, DW-4, 18, C_HDRBAR, C_BORDER, 1);
   L("sm_title", X+8, Y+159, "SMART MONEY", C_GOLD, 7, "Arial Black");
   
   R("sm_body", X+2, Y+174, DW-4, 75, C_BG2, C_BORDER, 1);
   L("fvg_lbl", X+8, Y+178, "FVG:", C_SUBTEXT, 6);
   L("fvg_val", X+50, Y+178, "0", C_WHITE, 7);
   L("ob_lbl", X+200, Y+178, "OB:", C_SUBTEXT, 6);
   L("ob_val", X+235, Y+178, "0", C_WHITE, 7);
   
   L("liq_lbl", X+8, Y+192, "Liquidity:", C_SUBTEXT, 6);
   L("liq_val", X+70, Y+192, "0 zones", C_WHITE, 7);
   L("choch_lbl", X+200, Y+192, "CHoCH:", C_SUBTEXT, 6);
   L("choch_val", X+255, Y+192, "0", C_WHITE, 7);
   
   L("pd_lbl", X+8, Y+206, "P/D Level:", C_SUBTEXT, 6);
   L("pd_val", X+70, Y+206, "50%", C_ORANGE, 7);
   L("struct_lbl", X+200, Y+206, "Structure:", C_SUBTEXT, 6);
   L("struct_val", X+265, Y+206, "50", C_WHITE, 7);
   
   L("corr_lbl", X+8, Y+220, "USD Corr:", C_SUBTEXT, 6);
   L("corr_val", X+70, Y+220, "0.0", C_WHITE, 7);
   L("diverg_lbl", X+200, Y+220, "Divergence:", C_SUBTEXT, 6);
   L("diverg_val", X+280, Y+220, "NO", C_SUBTEXT, 6);
   
   // Position Info
   R("pos_hdr", X+2, Y+251, DW-4, 18, C_HDRBAR, C_BORDER, 1);
   L("pos_title", X+8, Y+254, "POSITIONS", C_GOLD, 7, "Arial Black");
   L("pos_count", X+DW-50, Y+254, "0", C_ORANGE, 7);
   
   R("pos_body", X+2, Y+269, DW-4, 50, C_BG2, C_BORDER, 1);
   L("pos_info", X+10, Y+275, "No open positions", C_SUBTEXT, 7);
   L("float_lbl", X+8, Y+295, "Float P/L:", C_SUBTEXT, 6);
   L("float_val", X+70, Y+295, "$0.00", C_GREEN, 8);
   
   // Account Stats
   R("acc_hdr", X+2, Y+321, DW-4, 18, C_HDRBAR, C_BORDER, 1);
   L("acc_title", X+8, Y+324, "ACCOUNT", C_GOLD, 7, "Arial Black");
   
   R("acc_body", X+2, Y+339, DW-4, 85, C_BG2, C_BORDER, 1);
   L("bal_lbl", X+8, Y+343, "Balance:", C_SUBTEXT, 6);
   L("bal_val", X+70, Y+343, "$0", C_GREEN, 8);
   L("eq_lbl", X+200, Y+343, "Equity:", C_SUBTEXT, 6);
   L("eq_val", X+255, Y+343, "$0", C_GREEN, 8);
   
   L("daypl_lbl", X+8, Y+358, "Day P/L:", C_SUBTEXT, 6);
   L("daypl_val", X+70, Y+358, "$0", C_GREEN, 8);
   L("trades_lbl", X+200, Y+358, "Trades:", C_SUBTEXT, 6);
   L("trades_val", X+255, Y+358, "0", C_WHITE, 7);
   
   L("wr_lbl", X+8, Y+373, "Win Rate:", C_SUBTEXT, 6);
   L("wr_val", X+70, Y+373, "0%", C_WHITE, 7);
   L("risk_lbl", X+200, Y+373, "Risk:", C_SUBTEXT, 6);
   L("risk_val", X+255, Y+373, "0.5%", C_CYAN, 7);
   
   L("dd_lbl", X+8, Y+388, "Drawdown:", C_SUBTEXT, 6);
   L("dd_val", X+70, Y+388, "0%", C_GREEN, 7);
   L("peak_lbl", X+200, Y+388, "Peak:", C_SUBTEXT, 6);
   L("peak_val", X+255, Y+388, "$0", C_WHITE, 7);
   
   // Strategy Performance
   R("strat_hdr", X+2, Y+426, DW-4, 18, C_HDRBAR, C_BORDER, 1);
   L("strat_title", X+8, Y+429, "TOP STRATEGIES", C_GOLD, 7, "Arial Black");
   
   R("strat_body", X+2, Y+444, DW-4, 100, C_BG2, C_BORDER, 1);
   L("s1_name", X+8, Y+448, "1. FVG Scalp", C_SUBTEXT, 6);
   L("s1_stats", X+150, Y+448, "0 | 0% | 0.0", C_WHITE, 6);
   
   L("s2_name", X+8, Y+463, "2. Order Block", C_SUBTEXT, 6);
   L("s2_stats", X+150, Y+463, "0 | 0% | 0.0", C_WHITE, 6);
   
   L("s3_name", X+8, Y+478, "3. Liquidity Grab", C_SUBTEXT, 6);
   L("s3_stats", X+150, Y+478, "0 | 0% | 0.0", C_WHITE, 6);
   
   L("s4_name", X+8, Y+493, "4. Premium/Discount", C_SUBTEXT, 6);
   L("s4_stats", X+150, Y+493, "0 | 0% | 0.0", C_WHITE, 6);
   
   L("s5_name", X+8, Y+508, "5. London Killzone", C_SUBTEXT, 6);
   L("s5_stats", X+150, Y+508, "0 | 0% | 0.0", C_WHITE, 6);
   
   L("strat_note", X+8, Y+525, "Trades | WR% | PF", C_SUBTEXT, 5);
   
   // ML Status
   R("ml_hdr", X+2, Y+546, DW-4, 18, C_HDRBAR, C_BORDER, 1);
   L("ml_title", X+8, Y+549, "MACHINE LEARNING", C_GOLD, 7, "Arial Black");
   
   R("ml_body", X+2, Y+564, DW-4, 45, C_BG2, C_BORDER, 1);
   L("ml_status", X+8, Y+568, "Status:", C_SUBTEXT, 6);
   L("ml_status_val", X+60, Y+568, "LEARNING", C_CYAN, 7);
   L("ml_patterns", X+200, Y+568, "Patterns:", C_SUBTEXT, 6);
   L("ml_patterns_val", X+265, Y+568, "0", C_WHITE, 7);
   
   L("ml_conf", X+8, Y+583, "Confidence:", C_SUBTEXT, 6);
   L("ml_conf_val", X+80, Y+583, "0%", C_WHITE, 7);
   L("ml_adapt", X+200, Y+583, "Adaptive:", C_SUBTEXT, 6);
   L("ml_adapt_val", X+265, Y+583, "ON", C_GREEN, 7);
   
   // Risk Metrics
   R("risk_hdr", X+2, Y+611, DW-4, 18, C_HDRBAR, C_BORDER, 1);
   L("risk_title", X+8, Y+614, "RISK MANAGEMENT", C_GOLD, 7, "Arial Black");
   
   R("risk_body", X+2, Y+629, DW-4, 60, C_BG2, C_BORDER, 1);
   L("lot_lbl", X+8, Y+633, "Lot Size:", C_SUBTEXT, 6);
   L("lot_val", X+70, Y+633, "0.01", C_CYAN, 8);
   L("mult_lbl", X+200, Y+633, "Multiplier:", C_SUBTEXT, 6);
   L("mult_val", X+275, Y+633, "1.0x", C_WHITE, 7);
   
   L("sl_lbl", X+8, Y+648, "SL (ATR):", C_SUBTEXT, 6);
   L("sl_val", X+70, Y+648, "2.0", C_WHITE, 7);
   L("tp_lbl", X+200, Y+648, "TP (ATR):", C_SUBTEXT, 6);
   L("tp_val", X+275, Y+648, "3.0", C_WHITE, 7);
   
   L("vol_adj_lbl", X+8, Y+663, "Vol Adj:", C_SUBTEXT, 6);
   L("vol_adj_val", X+70, Y+663, "1.0x", C_WHITE, 6);
   L("acc_adj_lbl", X+130, Y+663, "Acc Adj:", C_SUBTEXT, 6);
   L("acc_adj_val", X+185, Y+663, "1.0x", C_WHITE, 6);
   L("sess_adj_lbl", X+240, Y+663, "Sess:", C_SUBTEXT, 6);
   L("sess_adj_val", X+280, Y+663, "1.0x", C_WHITE, 6);
   
   // Footer
   R("footer", X+2, Y+DH-18, DW-4, 16, C_HDRBAR, C_BORDER, 1);
   L("time", X+8, Y+DH-14, TimeToString(TimeCurrent(), TIME_MINUTES), C_MGRAY, 6);
   L("version", X+DW-80, Y+DH-14, "QPA 2.0", C_MGRAY, 6);
   
   ChartRedraw(0);
}

void UpdateDashboard()
{
   if(!InpShowDashboard) return;
   if(MQLInfoInteger(MQL_TESTER) && !MQLInfoInteger(MQL_VISUAL_MODE)) return;
   
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double spread = (double)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   
   U("status_val", g_statusText, g_statusColor);
   U("action", g_lastAction, C_SUBTEXT);
   
   U("price_val", DoubleToString(bid, (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS)), C_WHITE);
   U("spread_val", DoubleToString(spread, 0), (spread <= InpGoldSpreadMax) ? C_GREEN : C_RED);
   
   // Session
   string sessionNames[] = {"ASIAN", "LONDON-O", "LONDON", "NY-OVERLAP", "NY-PM", "DEAD"};
   U("session_val", sessionNames[g_currentSession], C_CYAN);
   
   // Volatility
   string volNames[] = {"XLOW", "LOW", "NORMAL", "HIGH", "EXTREME", "SPIKE"};
   color volColors[] = {C_CYAN, C_GREEN, C_WHITE, C_ORANGE, C_RED, C_PURPLE};
   U("vol_val", volNames[g_currentVolState], volColors[g_currentVolState]);
   
   // Regime
   string regimeNames[] = {"TREND", "RANGE", "BREAKOUT", "COMPRESS", "EXPAND", "SHOCK", "SWEEP", "EXHAUST", "REVERT", "CONSOL", "SM-ACCUM", "SM-DIST", "UNSAFE"};
   U("regime_val", regimeNames[g_currentRegime], C_ORANGE);
   
   // Smart Money
   U("fvg_val", IntegerToString(g_fvgCount), C_WHITE);
   U("ob_val", IntegerToString(g_obCount), C_WHITE);
   U("liq_val", IntegerToString(g_liqZoneCount) + " zones", C_WHITE);
   U("choch_val", IntegerToString(g_chochCount), C_WHITE);
   U("pd_val", DoubleToString(g_premiumDiscount.currentLevel, 0) + "%", 
      g_premiumDiscount.inPremium ? C_RED : (g_premiumDiscount.inDiscount ? C_GREEN : C_ORANGE));
   U("struct_val", IntegerToString(g_structure.structureStrength), C_WHITE);
   U("corr_val", DoubleToString(g_correlation.dxyCorrelation, 2), C_WHITE);
   U("diverg_val", g_correlation.divergenceDetected ? "YES" : "NO", 
      g_correlation.divergenceDetected ? C_ORANGE : C_SUBTEXT);
   
   // Positions
   int posCount = PositionsTotalForMagic();
   U("pos_count", IntegerToString(posCount), posCount > 0 ? C_GREEN : C_ORANGE);
   
   if(posCount > 0)
   {
      double floatPL = 0;
      for(int i = PositionsTotal()-1; i >= 0; i--)
      {
         if(g_pos.SelectByIndex(i) && g_pos.Magic() == InpMagicNumber && g_pos.Symbol() == _Symbol)
         {
            floatPL += g_pos.Profit() + g_pos.Swap() + g_pos.Commission();
            string posType = (g_pos.PositionType() == POSITION_TYPE_BUY) ? "LONG" : "SHORT";
            U("pos_info", posType + " " + DoubleToString(g_pos.Volume(), 2) + " | " + 
              DoubleToString(g_pos.Profit(), 2), C_WHITE);
            break;
         }
      }
      U("float_val", (floatPL >= 0 ? "$+" : "$") + DoubleToString(floatPL, 2), 
         floatPL >= 0 ? C_GREEN : C_RED);
   }
   else
   {
      U("pos_info", "No open positions", C_SUBTEXT);
      U("float_val", "$0.00", C_SUBTEXT);
   }
   
   // Account
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   double dayPL = equity - g_dayStartEquity;
   
   U("bal_val", "$" + DoubleToString(balance, 0), C_GREEN);
   U("eq_val", "$" + DoubleToString(equity, 0), C_GREEN);
   U("daypl_val", (dayPL >= 0 ? "$+" : "$") + DoubleToString(dayPL, 2), dayPL >= 0 ? C_GREEN : C_RED);
   U("trades_val", IntegerToString(g_tradesToday), C_WHITE);
   
   int totalTrades = g_sessionWins + g_sessionLosses;
   double winRate = (totalTrades > 0) ? (100.0 * g_sessionWins / totalTrades) : 0;
   U("wr_val", DoubleToString(winRate, 0) + "%", winRate >= 50 ? C_GREEN : C_ORANGE);
   U("risk_val", DoubleToString(g_dynamicRisk.riskPercent, 2) + "%", C_CYAN);
   
   double currentDD = (g_peakEquity > 0) ? ((g_peakEquity - equity) / g_peakEquity * 100.0) : 0;
   U("dd_val", DoubleToString(currentDD, 1) + "%", currentDD < 5 ? C_GREEN : (currentDD < 10 ? C_ORANGE : C_RED));
   U("peak_val", "$" + DoubleToString(g_peakEquity, 0), C_WHITE);
   
   // Strategies
   string stratStats[5];
   for(int i = 0; i < 5; i++)
   {
      int idx = i + 1; // Skip STRAT_NONE
      stratStats[i] = IntegerToString(g_strategies[idx].totalTrades) + " | " +
                      DoubleToString(g_strategies[idx].winRate, 0) + "% | " +
                      DoubleToString(g_strategies[idx].profitFactor, 1);
   }
   U("s1_stats", stratStats[0], C_WHITE);
   U("s2_stats", stratStats[1], C_WHITE);
   U("s3_stats", stratStats[2], C_WHITE);
   U("s4_stats", stratStats[3], C_WHITE);
   U("s5_stats", stratStats[4], C_WHITE);
   
   // ML
   U("ml_status_val", InpEnableML ? "ACTIVE" : "OFF", InpEnableML ? C_CYAN : C_SUBTEXT);
   U("ml_patterns_val", IntegerToString(g_mlPatternCount), C_WHITE);
   U("ml_conf_val", "0%", C_WHITE); // Placeholder
   U("ml_adapt_val", InpML_AdaptiveWeights ? "ON" : "OFF", InpML_AdaptiveWeights ? C_GREEN : C_SUBTEXT);
   
   // Risk
   U("lot_val", DoubleToString(g_dynamicRisk.finalLotSize, 2), C_CYAN);
   U("mult_val", DoubleToString(g_dynamicRisk.currentMultiplier, 2) + "x", C_WHITE);
   U("sl_val", DoubleToString(g_dynamicRisk.dynamicSL_ATR, 1), C_WHITE);
   U("tp_val", DoubleToString(g_dynamicRisk.dynamicTP_ATR, 1), C_WHITE);
   U("vol_adj_val", DoubleToString(g_dynamicRisk.volatilityAdjustment, 2) + "x", C_WHITE);
   U("acc_adj_val", DoubleToString(g_dynamicRisk.accountSizeAdjustment, 2) + "x", C_WHITE);
   U("sess_adj_val", DoubleToString(g_dynamicRisk.sessionAdjustment, 2) + "x", C_WHITE);
   
   U("time", TimeToString(TimeCurrent(), TIME_MINUTES), C_MGRAY);
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
   
   double pnl = HistoryDealGetDouble(dealTicket, DEAL_PROFIT) +
                HistoryDealGetDouble(dealTicket, DEAL_SWAP) +
                HistoryDealGetDouble(dealTicket, DEAL_COMMISSION);
   
   string comment = HistoryDealGetString(dealTicket, DEAL_COMMENT);
   
   // Extract strategy from comment
   string parts[];
   if(StringSplit(comment, '|', parts) >= 2)
   {
      ENUM_GOLD_STRATEGY strat = (ENUM_GOLD_STRATEGY)StringToInteger(parts[1]);
      RegisterStrategyResult(strat, pnl);
   }
   
   // Update session stats
   g_sessionProfit += pnl;
   if(pnl >= 0) g_sessionWins++;
   else g_sessionLosses++;
   
   // Update total profit/loss
   if(pnl >= 0) g_totalProfit += pnl;
   else g_totalLoss += MathAbs(pnl);
   
   Print("✓ Trade closed | P/L: ", DoubleToString(pnl, 2), " | Session: ", g_sessionWins, "W / ", g_sessionLosses, "L");
}

//=====================================================================
//  MAIN TRADING LOGIC
//=====================================================================

void ExecuteTradingLogic()
{
   // Check if we already have positions
   if(PositionsTotalForMagic() > 0)
   {
      g_statusText = "IN TRADE";
      g_statusColor = C_GREEN;
      return;
   }
   
   // Risk checks
   string riskReason;
   if(!RiskChecksPass(riskReason))
   {
      g_statusText = "BLOCKED";
      g_statusColor = C_RED;
      g_lastAction = riskReason;
      return;
   }
   
   // Generate signal
   GoldSignal signal = GenerateBestSignal();
   
   if(!signal.valid)
   {
      g_statusText = "SCANNING";
      g_statusColor = C_CYAN;
      g_lastAction = signal.narrative;
      return;
   }
   
   // Check signal quality threshold
   if(signal.quality.compositeScore < InpML_MinConfidence)
   {
      g_statusText = "LOW QUALITY";
      g_statusColor = C_ORANGE;
      g_lastAction = "Signal quality: " + DoubleToString(signal.quality.compositeScore, 0) + "%";
      return;
   }
   
   // Execute trade
   g_statusText = "EXECUTING";
   g_statusColor = C_LBLUE;
   
   bool success = ExecuteSignal(signal);
   
   if(!success)
   {
      g_statusText = "FAILED";
      g_statusColor = C_RED;
      g_lastAction = "Execution failed";
   }
}

//=====================================================================
//  PERIODIC UPDATES
//=====================================================================

void PerformFullAnalysis()
{
   // Update session
   g_currentSession = ClassifySession(TimeCurrent());
   
   // Analyze volatility
   g_currentVolState = AnalyzeVolatility();
   
   // Smart Money Concepts
   DetectFairValueGaps();
   DetectOrderBlocks();
   DetectChangeOfCharacter();
   DetectLiquidityZones();
   CalculatePremiumDiscount();
   
   // Market structure
   UpdateMarketStructure();
   
   // Correlation
   UpdateCorrelationAnalysis();
   
   // Regime
   ClassifyMarketRegime();
   
   // Risk calculations
   CalculateDynamicRisk();
   
   // ML updates
   UpdateStrategyWeights();
   
   // Visual overlays
   UpdateVisualOverlays();
}

//=====================================================================
//  EA LIFECYCLE
//=====================================================================

int OnInit()
{
   Print("═══════════════════════════════════════");
   Print("  QUANTUM PLUS AI v2.0 - GOLD SCALPER  ");
   Print("═══════════════════════════════════════");
   
   // Set symbol
  // Set symbol
string symbol = (InpSymbolOverride == "") ? _Symbol : InpSymbolOverride;
   
   // Initialize indicators (M5 timeframe as primary)
   g_m5_ema_fast = iMA(_Symbol, PERIOD_M5, InpEMA_Fast, 0, MODE_EMA, PRICE_CLOSE);
   g_m5_ema_medium = iMA(_Symbol, PERIOD_M5, InpEMA_Medium, 0, MODE_EMA, PRICE_CLOSE);
   g_m5_ema_slow = iMA(_Symbol, PERIOD_M5, InpEMA_Slow, 0, MODE_EMA, PRICE_CLOSE);
   g_m5_atr = iATR(_Symbol, PERIOD_M5, InpGoldVolatilityPeriod);
   g_m5_rsi = iRSI(_Symbol, PERIOD_M5, 14, PRICE_CLOSE);
   g_m5_bb = iBands(_Symbol, PERIOD_M5, 20, 0, 2.0, PRICE_CLOSE);
   g_m5_adx = iADX(_Symbol, PERIOD_M5, 14);
   g_m5_cci = iCCI(_Symbol, PERIOD_M5, 14, PRICE_TYPICAL);
   g_m5_stoch = iStochastic(_Symbol, PERIOD_M5, 5, 3, 3, MODE_SMA, STO_LOWHIGH);
   
   // H1 indicators
   g_h1_ema_fast = iMA(_Symbol, PERIOD_H1, InpEMA_Fast, 0, MODE_EMA, PRICE_CLOSE);
   g_h1_ema_medium = iMA(_Symbol, PERIOD_H1, InpEMA_Medium, 0, MODE_EMA, PRICE_CLOSE);
   g_h1_ema_slow = iMA(_Symbol, PERIOD_H1, InpEMA_Slow, 0, MODE_EMA, PRICE_CLOSE);
   g_h1_atr = iATR(_Symbol, PERIOD_H1, InpGoldVolatilityPeriod);
   g_h1_rsi = iRSI(_Symbol, PERIOD_H1, 14, PRICE_CLOSE);
   
   // M15 indicators
   g_m15_ema_fast = iMA(_Symbol, PERIOD_M15, InpEMA_Fast, 0, MODE_EMA, PRICE_CLOSE);
   g_m15_ema_medium = iMA(_Symbol, PERIOD_M15, InpEMA_Medium, 0, MODE_EMA, PRICE_CLOSE);
   g_m15_ema_slow = iMA(_Symbol, PERIOD_M15, InpEMA_Slow, 0, MODE_EMA, PRICE_CLOSE);
   g_m15_atr = iATR(_Symbol, PERIOD_M15, InpGoldVolatilityPeriod);
   g_m15_rsi = iRSI(_Symbol, PERIOD_M15, 14, PRICE_CLOSE);
   
   // M1 indicators
   g_m1_ema_fast = iMA(_Symbol, PERIOD_M1, InpEMA_Fast, 0, MODE_EMA, PRICE_CLOSE);
   g_m1_ema_medium = iMA(_Symbol, PERIOD_M1, InpEMA_Medium, 0, MODE_EMA, PRICE_CLOSE);
   g_m1_atr = iATR(_Symbol, PERIOD_M1, InpGoldVolatilityPeriod);
   g_m1_rsi = iRSI(_Symbol, PERIOD_M1, 14, PRICE_CLOSE);
   
   // Validate handles
   if(g_m5_ema_fast == INVALID_HANDLE || g_m5_atr == INVALID_HANDLE || g_m5_rsi == INVALID_HANDLE)
   {
      Print("ERROR: Failed to create indicator handles");
      return INIT_FAILED;
   }
   
   // Initialize states
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   g_peakEquity = equity;
   g_dayStartEquity = equity;
   g_weekStartEquity = equity;
   g_dayStart = DayStart(TimeCurrent());
   g_weekStart = WeekStart(TimeCurrent());
   
   // Initialize strategies
   InitializeStrategies();
   
   // Initialize dashboard
   if(InpShowDashboard)
   {
      InitDashboard();
   }
   
   // Set timer (every second)
   EventSetTimer(1);
   
   g_statusText = "READY";
   g_statusColor = C_GREEN;
   g_lastAction = "System initialized successfully";
   
   Print("✓ Initialization complete");
   Print("  Symbol: ", _Symbol);
   Print("  Base Risk: ", InpBaseRiskPercent, "%");
   Print("  Max Daily Trades: ", InpMaxDailyTrades);
   Print("  ML Enabled: ", InpEnableML ? "Yes" : "No");
   
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
   Print("═══════════════════════════════════════");
   Print("  SESSION SUMMARY  ");
   Print("═══════════════════════════════════════");
   Print("  Trades: ", g_tradesToday);
   Print("  Wins: ", g_sessionWins, " | Losses: ", g_sessionLosses);
   Print("  Session P/L: $", DoubleToString(g_sessionProfit, 2));
   Print("  Total Profit: $", DoubleToString(g_totalProfit, 2));
   Print("  Total Loss: $", DoubleToString(g_totalLoss, 2));
   
   Print("\n  TOP STRATEGIES:");
   for(int i = 1; i < 6; i++)
   {
      if(g_strategies[i].totalTrades > 0)
      {
         Print("  ", g_strategies[i].name, ": ", g_strategies[i].totalTrades, " trades | ",
               DoubleToString(g_strategies[i].winRate, 0), "% WR | ",
               DoubleToString(g_strategies[i].profitFactor, 2), " PF");
      }
   }
   
   Print("═══════════════════════════════════════");
   
   EventKillTimer();
   DeleteAllOverlays();
   
   // Release indicators
   IndicatorRelease(g_m5_ema_fast); IndicatorRelease(g_m5_ema_medium); IndicatorRelease(g_m5_ema_slow);
   IndicatorRelease(g_m5_atr); IndicatorRelease(g_m5_rsi); IndicatorRelease(g_m5_bb);
   IndicatorRelease(g_m5_adx); IndicatorRelease(g_m5_cci); IndicatorRelease(g_m5_stoch);
   IndicatorRelease(g_h1_ema_fast); IndicatorRelease(g_h1_ema_medium); IndicatorRelease(g_h1_ema_slow);
   IndicatorRelease(g_h1_atr); IndicatorRelease(g_h1_rsi);
   IndicatorRelease(g_m15_ema_fast); IndicatorRelease(g_m15_ema_medium); IndicatorRelease(g_m15_ema_slow);
   IndicatorRelease(g_m15_atr); IndicatorRelease(g_m15_rsi);
   IndicatorRelease(g_m1_ema_fast); IndicatorRelease(g_m1_ema_medium);
   IndicatorRelease(g_m1_atr); IndicatorRelease(g_m1_rsi);
}

void OnTimer()
{
   // Update dashboard every second
   if(InpShowDashboard)
   {
      UpdateDashboard();
   }
   
   // Update equity peak
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   if(equity > g_peakEquity)
      g_peakEquity = equity;
}

void OnTick()
{
   // Day/week rollover
   datetime now = TimeCurrent();
   datetime today = DayStart(now);
   datetime thisWeek = WeekStart(now);
   
   if(today != g_dayStart)
   {
      g_dayStart = today;
      g_tradesToday = 0;
      g_dayStartEquity = AccountInfoDouble(ACCOUNT_EQUITY);
      g_sessionProfit = 0;
      g_sessionWins = 0;
      g_sessionLosses = 0;
   }
   
   if(thisWeek != g_weekStart)
   {
      g_weekStart = thisWeek;
      g_weekStartEquity = AccountInfoDouble(ACCOUNT_EQUITY);
   }
   
   // Full analysis every new M5 bar
   if(IsNewBar(PERIOD_M5))
   {
      PerformFullAnalysis();
   }
   
   // Trading logic
   ExecuteTradingLogic();
}

void OnTradeTransaction(const MqlTradeTransaction &trans,
                         const MqlTradeRequest &request,
                         const MqlTradeResult &result)
{
   OnTradeTransactionHandler(trans, request, result);
}
//+------------------------------------------------------------------+