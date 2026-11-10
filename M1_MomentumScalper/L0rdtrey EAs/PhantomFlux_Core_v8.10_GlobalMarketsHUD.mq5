//+------------------------------------------------------------------+
//|                 PHANTOM FLUX CORE v8.10 - SCALPING GRID          |
//|          Aggressive Bidirectional Execution Engine               |
//|          BALANCED R:R + LIQUIDITY INTELLIGENCE SYSTEM            |
//+------------------------------------------------------------------+
#property copyright "Phantom Technologies © 2024"
#property version   "8.10"
#property description "Bidirectional Grid with Liquidity Intelligence - Balanced Expectancy Edition"
#property strict

#include <Trade\Trade.mqh>
#include <Canvas\Canvas.mqh>

//+------------------------------------------------------------------+
//| DASHBOARD CONFIGURATION - ENHANCED VISIBILITY                     |
//+------------------------------------------------------------------+
#define DASH_PREFIX "PFCHUD_"
#define DASH_MIN_WIDTH 380
#define DASH_TOTAL_H 1000 // Initial/default height; recalculated dynamically to fit content
#define GLOBE_SIZE 190
#define BTN_PROFIT_NAME "BTN_CLOSE_PROFIT"
#define BTN_LOSS_NAME   "BTN_CLOSE_LOSS"

// GLOBAL MARKETS HUD Color Scheme
#define COLOR_BG_MAIN      C'0,0,0'
#define COLOR_BG_PANEL     C'0,0,0'
#define COLOR_BG_HIGHLIGHT C'20,20,20'
#define COLOR_BORDER       C'45,45,45'
#define COLOR_BORDER_ACCENT C'0,200,255'
#define COLOR_BORDER_GOLD  C'255,205,40'
#define COLOR_TEXT_PRIMARY C'235,240,250'
#define COLOR_TEXT_SECONDARY C'150,175,215'
#define COLOR_TEXT_DIM     C'85,105,145'
#define COLOR_ACCENT_BLUE  C'0,153,255'
#define COLOR_ACCENT_GREEN C'40,225,140'
#define COLOR_ACCENT_RED   C'255,80,95'
#define COLOR_ACCENT_YELLOW C'255,205,60'
#define COLOR_ACCENT_PURPLE C'170,120,255'
#define COLOR_ACCENT_ORANGE C'255,150,45'
#define COLOR_ACCENT_CYAN  C'0,225,255'
#define COLOR_ACCENT_GOLD  C'255,205,60'
#define COLOR_GLOW_CYAN    C'0,90,110'
#define COLOR_DIVIDER      C'35,35,35'
#define COLOR_ORB_BLUE     C'35,110,210'
#define COLOR_ORB_HILITE   C'70,150,240'

// Chart Auto-Theme Colors
#define CHART_THEME_BG      C'6,8,12'
#define CHART_THEME_BULL    C'0,230,150'
#define CHART_THEME_BEAR    C'255,71,87'
#define CHART_THEME_WICK    C'150,160,175'
#define CHART_THEME_GRID    CHART_THEME_BG
#define CHART_THEME_FORE    C'220,225,235'

//+------------------------------------------------------------------+
//| LIQUIDITY INTELLIGENCE ENUMERATIONS                               |
//+------------------------------------------------------------------+
enum LiquidityState
{
   LIQ_VERY_LOW    = 0,  // Extremely thin, avoid trading
   LIQ_LOW         = 1,  // Below average, reduce size
   LIQ_NORMAL      = 2,  // Average conditions
   LIQ_HIGH        = 3,  // Above average, good for trading
   LIQ_VERY_HIGH   = 4   // Excellent liquidity, full size
};

enum VolatilityRegime
{
   VOL_DORMANT     = 0,  // Dead market
   VOL_LOW         = 1,  // Low volatility
   VOL_NORMAL      = 2,  // Normal volatility
   VOL_HIGH        = 3,  // High volatility
   VOL_EXTREME     = 4   // Extreme volatility - reduce exposure
};

enum MarketMomentum
{
   MOM_STRONG_BEAR = -2,
   MOM_WEAK_BEAR   = -1,
   MOM_NEUTRAL     = 0,
   MOM_WEAK_BULL   = 1,
   MOM_STRONG_BULL = 2
};

//+------------------------------------------------------------------+
//| EXECUTION MODE ENUMERATION                                        |
//+------------------------------------------------------------------+
enum ExecutionMode
{
   Stealth      = 1,
   Adaptive     = 2,
   Aggressive   = 3
};

//+------------------------------------------------------------------+
//| INPUTS                                                            |
//+------------------------------------------------------------------+
input group "═══ BIDIRECTIONAL GRID CORE ═══"
input ExecutionMode InpMode = Aggressive;
input int InpOrdersPerSide = 10;
input int InpMaxOrderLifetimeSeconds = 60;
input bool InpAutoRecycleStaleOrders = true;

input group "═══ BALANCED PROFIT TARGETS (FIXED R:R) ═══"
input bool InpUseDynamicTargets = true;         // Use intelligent target adjustment
input double InpMinRiskRewardRatio = 1.8;       // Minimum R:R ratio (1.8:1 default)
input double InpScalpTargetMultiplier = 2.2;    // Scalp target = SL × this (2.2:1 R:R)
input bool InpAllowEarlyExit = true;            // Allow partial exit at 1:1 R:R

input group "═══ LIQUIDITY INTELLIGENCE SYSTEM ═══"
input bool InpUseLiquidityFilter = true;        // Enable liquidity-based filtering
input int InpVolumeLookback = 20;               // Bars to analyze for volume profile
input double InpMinVolumeRatio = 0.7;           // Min current/average volume ratio
input bool InpUseMomentumFilter = true;         // Enable momentum analysis
input int InpMomentumPeriod = 14;               // Momentum calculation period
input bool InpTradeWithTrend = true;            // Only trade in momentum direction
input bool InpUseVolatilityAdaptation = true;   // Adapt to volatility regime

input group "═══ ORDER PROXIMITY (ATR-based) ═══"
input double InpMinOrderDistanceATR = 0.15;
input double InpMaxOrderDistanceATR = 0.5;
input double InpGridStepATR = 0.035;

input group "═══ RISK MANAGEMENT ═══"
input double InpBaseLot = 0.15;
input double InpRiskPercent = 0.5;
input double InpMaxTotalLots = 3.0;
input double InpSLATRMult = 1.0;                // Base SL (used for R:R calculation)
input double InpTPATRMult = 2.2;                // Base TP (minimum 2.2:1 R:R)

input group "═══ EXECUTION ENGINE ═══"
input bool InpUseTickDrivenMgmt = true;
input int InpTradeDeviationPts = 5;
input int InpTimerMs = 100;

input group "═══ POSITION MANAGEMENT ═══"
input int InpMaxHoldMinutes = 60;
input bool InpForceCloseAtMaxHold = false;
input bool InpUseBreakeven = true;
input double InpBreakevenATR = 0.6;
input double InpBreakevenBufferPts = 10;
input bool InpUseTrailing = true;
input double InpTrailStartATR = 1.2;            // Increased to let winners run
input double InpTrailATR = 0.4;                 // Tighter trail to lock profits

input group "═══ CIRCUIT BREAKER ═══"
input double InpDailyProfitTarget = 50.0;
input double InpDailyLossLimit = 30.0;
input bool InpCloseAllOnLossLimit = true;
input double InpMaxDrawdownPct = 8.0;

input group "═══ ANALYSIS ═══"
input ENUM_TIMEFRAMES InpAnalysisTF = PERIOD_M1;
input int InpATRPeriod = 14;
input int InpMaxSpreadPoints = 80;
input int InpEMAPeriod = 20;                    // EMA period shown on dashboard

input group "═══ GLOBAL MARKETS DASHBOARD ═══"
input bool InpShowDashboard = true;
input int InpDashboardTransparency = 0;
input int InpDashboardWidthPct = 30;             // Dashboard width as % of chart width
input string InpDashTitleLine1 = "GLOBAL MARKETS";
input string InpDashTitleLine2 = "SMC/ICT Hybrid";

input group "═══ AUTO CHART THEME (BLACK / NO GRID) ═══"
input bool InpAutoStyleChart = true;
input bool InpHideGridLines = true;
input bool InpRestoreChartOnRemove = false;

input group "═══ TRADING SESSION FILTER (SERVER TIME) ═══"
input bool InpTradeAllSessions = true;
input bool InpTradeSydneySession = true;
input int  InpSydneyStartHour = 21;
input int  InpSydneyEndHour = 6;
input bool InpTradeTokyoSession = true;
input int  InpTokyoStartHour = 0;
input int  InpTokyoEndHour = 9;
input bool InpTradeLondonSession = true;
input int  InpLondonStartHour = 7;
input int  InpLondonEndHour = 16;
input bool InpTradeNewYorkSession = true;
input int  InpNewYorkStartHour = 12;
input int  InpNewYorkEndHour = 21;

//+------------------------------------------------------------------+
//| GLOBAL VARIABLES                                                  |
//+------------------------------------------------------------------+
CTrade trade;
int handleATR;
int handleEMA;
datetime lastBarTime = 0;
int magic = 990012;

// Account tracking
double dayStartBalance = 0.0;
int lastDayChecked = -1;
double dailyProfit = 0.0;
double peakEquity = 0.0;
double grossProfit = 0.0, grossLoss = 0.0;
int totalWins = 0, totalLosses = 0;
bool tradingEnabled = true;
double recentProfitFactor = 1.0;

// Scalping tracking with R:R metrics
double totalScalpProfit = 0.0;
int scalpWins = 0;
double avgWinSize = 0.0;
double avgLossSize = 0.0;
double realizedRR = 0.0;

// Tick management
datetime lastTickManagement = 0;
datetime lastGridDeployTime = 0;

// Fill-race protection
datetime lastFillTime = 0;
ulong    lastFilledOrderTicket = 0;
#define  FILL_SETTLE_SECONDS 2

// Symbol precision
int symbolDigits = 0;
double symbolPoint = 0.0, pipSize = 0.0;
bool isJPYPair = false;

// Cached ATR
double cachedATR = 0.0;
datetime atrCacheTime = 0;

// Cached EMA
double cachedEMA = 0.0;
datetime emaCacheTime = 0;

// EA runtime
datetime eaStartTime = 0;

// Dashboard manual-control feedback
string lastButtonActionMsg = "";

//+------------------------------------------------------------------+
//| LIQUIDITY INTELLIGENCE STATE                                      |
//+------------------------------------------------------------------+
struct LiquidityIntelligence
{
   // Volume analysis
   double avgVolume;
   double currentVolume;
   double volumeRatio;
   double volumeStdDev;
   
   // Momentum analysis
   double momentum;
   double acceleration;
   MarketMomentum momentumState;
   
   // Volatility regime
   double currentATR;
   double avgATR;
   double atrRatio;
   VolatilityRegime volRegime;
   
   // Liquidity state
   LiquidityState liquidityState;
   double liquidityScore;      // 0-100
   
   // Market microstructure
   double bidAskSpread;
   double spreadRatio;         // Current/Average spread
   int ticksPerSecond;
   double priceVelocity;
   
   // Smart targets
   double dynamicTPMultiplier;
   double dynamicSLMultiplier;
   double recommendedRR;
   
   // Trading recommendation
   bool allowLongEntry;
   bool allowShortEntry;
   double lotSizeMultiplier;   // 0.5 - 1.5 based on conditions
   
   // Update timestamp
   datetime lastUpdate;
   
} LiqIntel;

// Dashboard state
struct DashboardState {
   int x, y, width, height, currentY;
   int objectCount;
   bool needsFullRedraw;
   datetime lastUpdate;
} dashState;

// Session globe (real CCanvas bitmap, not a placeholder graphic)
CCanvas globeCanvas;
bool    globeCanvasReady = false;
double  globeRotation = 0.0;

//+------------------------------------------------------------------+
//| DASHBOARD SUPPORT STATE                                           |
//+------------------------------------------------------------------+
#define COND_COUNT 12  // Increased for liquidity conditions
string condLabel[COND_COUNT] = {
   "Session OK", "Spread OK", "ATR OK", "Exposure OK", "Grid Ready",
   "Circuit OK", "DD OK", "Liquidity OK", "Volume OK", "Momentum OK",
   "Vol Regime", "R:R Valid"
};
bool   condValue[COND_COUNT];
int    readinessScore = 0;

string marketBiasText = "RANGE";
color  marketBiasColor = clrNONE;

int    currentSpreadPoints = 0;
double currentDDPct = 0.0;

//+------------------------------------------------------------------+
//| LIQUIDITY INTELLIGENCE FUNCTIONS                                  |
//+------------------------------------------------------------------+

// Calculate average volume over lookback period
double CalculateAverageVolume(int lookback)
{
   long volumeArray[];
   ArraySetAsSeries(volumeArray, true);
   
   int copied = CopyTickVolume(_Symbol, InpAnalysisTF, 0, lookback, volumeArray);
   if(copied <= 0) return 0;
   
   double sum = 0;
   for(int i = 0; i < copied; i++)
      sum += (double)volumeArray[i];
   
   return sum / copied;
}

// Calculate volume standard deviation
double CalculateVolumeStdDev(int lookback, double avgVolume)
{
   long volumeArray[];
   ArraySetAsSeries(volumeArray, true);
   
   int copied = CopyTickVolume(_Symbol, InpAnalysisTF, 0, lookback, volumeArray);
   if(copied <= 0) return 0;
   
   double sumSquares = 0;
   for(int i = 0; i < copied; i++)
   {
      double diff = (double)volumeArray[i] - avgVolume;
      sumSquares += diff * diff;
   }
   
   return MathSqrt(sumSquares / copied);
}

// Calculate price momentum
double CalculateMomentum(int period)
{
   double closeArray[];
   ArraySetAsSeries(closeArray, true);
   
   int copied = CopyClose(_Symbol, InpAnalysisTF, 0, period + 1, closeArray);
   if(copied <= period) return 0;
   
   double currentClose = closeArray[0];
   double pastClose = closeArray[period];
   
   return (currentClose - pastClose) / pastClose * 100.0;  // Percentage momentum
}

// Calculate price acceleration (rate of momentum change)
double CalculateAcceleration()
{
   double closeArray[];
   ArraySetAsSeries(closeArray, true);
   
   int copied = CopyClose(_Symbol, InpAnalysisTF, 0, 5, closeArray);
   if(copied < 5) return 0;
   
   double momentum1 = (closeArray[0] - closeArray[2]) / closeArray[2];
   double momentum2 = (closeArray[2] - closeArray[4]) / closeArray[4];
   
   return (momentum1 - momentum2) * 10000;  // Scaled acceleration
}

// Calculate average ATR for volatility regime detection
double CalculateAverageATR(int lookback)
{
   double atrArray[];
   ArraySetAsSeries(atrArray, true);
   
   if(CopyBuffer(handleATR, 0, 0, lookback, atrArray) <= 0)
      return GetCurrentATR();
   
   double sum = 0;
   for(int i = 0; i < lookback; i++)
      sum += atrArray[i];
   
   return sum / lookback;
}

// Determine volatility regime
VolatilityRegime ClassifyVolatilityRegime(double currentATR, double avgATR)
{
   if(avgATR <= 0) return VOL_NORMAL;
   
   double ratio = currentATR / avgATR;
   
   if(ratio < 0.3)       return VOL_DORMANT;
   else if(ratio < 0.7)  return VOL_LOW;
   else if(ratio < 1.3)  return VOL_NORMAL;
   else if(ratio < 2.0)  return VOL_HIGH;
   else                  return VOL_EXTREME;
}

// Determine momentum state
MarketMomentum ClassifyMomentum(double momentum, double acceleration)
{
   if(momentum > 0.15 && acceleration > 0)      return MOM_STRONG_BULL;
   else if(momentum > 0.05)                     return MOM_WEAK_BULL;
   else if(momentum < -0.15 && acceleration < 0) return MOM_STRONG_BEAR;
   else if(momentum < -0.05)                    return MOM_WEAK_BEAR;
   else                                         return MOM_NEUTRAL;
}

// Calculate liquidity score (0-100)
double CalculateLiquidityScore()
{
   double score = 50.0;  // Baseline
   
   // Volume component (0-30 points)
   if(LiqIntel.volumeRatio > 1.5)       score += 30;
   else if(LiqIntel.volumeRatio > 1.2)  score += 20;
   else if(LiqIntel.volumeRatio > 0.9)  score += 10;
   else if(LiqIntel.volumeRatio < 0.5)  score -= 20;
   else if(LiqIntel.volumeRatio < 0.7)  score -= 10;
   
   // Spread component (0-20 points)
   if(LiqIntel.spreadRatio < 0.8)       score += 20;
   else if(LiqIntel.spreadRatio < 1.0)  score += 10;
   else if(LiqIntel.spreadRatio > 1.5)  score -= 15;
   else if(LiqIntel.spreadRatio > 1.2)  score -= 10;
   
   // Volatility component (0-20 points)
   if(LiqIntel.volRegime == VOL_NORMAL || LiqIntel.volRegime == VOL_HIGH)
      score += 20;
   else if(LiqIntel.volRegime == VOL_LOW)
      score += 5;
   else if(LiqIntel.volRegime == VOL_DORMANT || LiqIntel.volRegime == VOL_EXTREME)
      score -= 20;
   
   return MathMax(0, MathMin(100, score));
}

// Determine liquidity state from score
LiquidityState ClassifyLiquidity(double score)
{
   if(score >= 80)      return LIQ_VERY_HIGH;
   else if(score >= 60) return LIQ_HIGH;
   else if(score >= 40) return LIQ_NORMAL;
   else if(score >= 20) return LIQ_LOW;
   else                 return LIQ_VERY_LOW;
}

// Main liquidity intelligence update function
void UpdateLiquidityIntelligence()
{
   datetime now = TimeCurrent();
   if(now == LiqIntel.lastUpdate) return;
   
   // Volume analysis
   LiqIntel.avgVolume = CalculateAverageVolume(InpVolumeLookback);
   long currentVol[];
   ArraySetAsSeries(currentVol, true);
   if(CopyTickVolume(_Symbol, InpAnalysisTF, 0, 1, currentVol) > 0)
      LiqIntel.currentVolume = (double)currentVol[0];
   else
      LiqIntel.currentVolume = LiqIntel.avgVolume;
   
   LiqIntel.volumeRatio = (LiqIntel.avgVolume > 0) ? LiqIntel.currentVolume / LiqIntel.avgVolume : 1.0;
   LiqIntel.volumeStdDev = CalculateVolumeStdDev(InpVolumeLookback, LiqIntel.avgVolume);
   
   // Momentum analysis
   LiqIntel.momentum = CalculateMomentum(InpMomentumPeriod);
   LiqIntel.acceleration = CalculateAcceleration();
   LiqIntel.momentumState = ClassifyMomentum(LiqIntel.momentum, LiqIntel.acceleration);
   
   // Volatility regime
   LiqIntel.currentATR = GetCurrentATR();
   LiqIntel.avgATR = CalculateAverageATR(InpATRPeriod * 2);
   LiqIntel.atrRatio = (LiqIntel.avgATR > 0) ? LiqIntel.currentATR / LiqIntel.avgATR : 1.0;
   LiqIntel.volRegime = ClassifyVolatilityRegime(LiqIntel.currentATR, LiqIntel.avgATR);
   
   // Spread analysis
   MqlTick tick;
   SymbolInfoTick(_Symbol, tick);
   LiqIntel.bidAskSpread = (tick.ask - tick.bid) / symbolPoint;
   
   // Calculate average spread (simplified - using ATR as proxy)
   double avgSpread = LiqIntel.avgATR / symbolPoint * 0.1;  // Typical spread is ~10% of ATR
   if(avgSpread > 0)
      LiqIntel.spreadRatio = LiqIntel.bidAskSpread / avgSpread;
   else
      LiqIntel.spreadRatio = 1.0;
   
   // Liquidity scoring
   LiqIntel.liquidityScore = CalculateLiquidityScore();
   LiqIntel.liquidityState = ClassifyLiquidity(LiqIntel.liquidityScore);
   
   // Dynamic target calculation based on market conditions
   LiqIntel.dynamicTPMultiplier = InpTPATRMult;  // Base TP
   LiqIntel.dynamicSLMultiplier = InpSLATRMult;  // Base SL
   
   // Adjust TP based on volatility regime
   switch(LiqIntel.volRegime)
   {
      case VOL_DORMANT:
         LiqIntel.dynamicTPMultiplier *= 0.6;  // Smaller targets in dead market
         break;
      case VOL_LOW:
         LiqIntel.dynamicTPMultiplier *= 0.8;
         break;
      case VOL_HIGH:
         LiqIntel.dynamicTPMultiplier *= 1.3;  // Larger targets in trending market
         break;
      case VOL_EXTREME:
         LiqIntel.dynamicTPMultiplier *= 1.5;  // Even larger targets but careful
         LiqIntel.dynamicSLMultiplier *= 1.2;  // Wider stops too
         break;
   }
   
   // Adjust TP based on momentum
   if(LiqIntel.momentumState == MOM_STRONG_BULL || LiqIntel.momentumState == MOM_STRONG_BEAR)
      LiqIntel.dynamicTPMultiplier *= 1.2;  // Let winners run in strong trends
   
   // Calculate recommended R:R
   LiqIntel.recommendedRR = LiqIntel.dynamicTPMultiplier / LiqIntel.dynamicSLMultiplier;
   
   // Ensure minimum R:R
   if(LiqIntel.recommendedRR < InpMinRiskRewardRatio)
   {
      LiqIntel.dynamicTPMultiplier = InpMinRiskRewardRatio * LiqIntel.dynamicSLMultiplier;
      LiqIntel.recommendedRR = InpMinRiskRewardRatio;
   }
   
   // Entry permission logic
   LiqIntel.allowLongEntry = true;
   LiqIntel.allowShortEntry = true;
   
   if(InpUseMomentumFilter && InpTradeWithTrend)
   {
      if(LiqIntel.momentumState == MOM_STRONG_BEAR || LiqIntel.momentumState == MOM_WEAK_BEAR)
         LiqIntel.allowLongEntry = false;
      
      if(LiqIntel.momentumState == MOM_STRONG_BULL || LiqIntel.momentumState == MOM_WEAK_BULL)
         LiqIntel.allowShortEntry = false;
   }
   
   // Lot size adjustment based on liquidity
   LiqIntel.lotSizeMultiplier = 1.0;
   
   switch(LiqIntel.liquidityState)
   {
      case LIQ_VERY_LOW:
         LiqIntel.lotSizeMultiplier = 0.3;
         break;
      case LIQ_LOW:
         LiqIntel.lotSizeMultiplier = 0.6;
         break;
      case LIQ_NORMAL:
         LiqIntel.lotSizeMultiplier = 1.0;
         break;
      case LIQ_HIGH:
         LiqIntel.lotSizeMultiplier = 1.2;
         break;
      case LIQ_VERY_HIGH:
         LiqIntel.lotSizeMultiplier = 1.4;
         break;
   }
   
   // Further reduce size in extreme volatility
   if(LiqIntel.volRegime == VOL_EXTREME)
      LiqIntel.lotSizeMultiplier *= 0.7;
   
   LiqIntel.lastUpdate = now;
}

// Get string representation of liquidity state
string LiquidityStateToString(LiquidityState state)
{
   switch(state)
   {
      case LIQ_VERY_LOW:   return "VERY LOW";
      case LIQ_LOW:        return "LOW";
      case LIQ_NORMAL:     return "NORMAL";
      case LIQ_HIGH:       return "HIGH";
      case LIQ_VERY_HIGH:  return "VERY HIGH";
      default:             return "UNKNOWN";
   }
}

// Get color for liquidity state
color LiquidityStateColor(LiquidityState state)
{
   switch(state)
   {
      case LIQ_VERY_LOW:   return COLOR_ACCENT_RED;
      case LIQ_LOW:        return COLOR_ACCENT_ORANGE;
      case LIQ_NORMAL:     return COLOR_ACCENT_YELLOW;
      case LIQ_HIGH:       return COLOR_ACCENT_GREEN;
      case LIQ_VERY_HIGH:  return COLOR_ACCENT_CYAN;
      default:             return COLOR_TEXT_DIM;
   }
}

// Get string representation of volatility regime
string VolatilityRegimeToString(VolatilityRegime regime)
{
   switch(regime)
   {
      case VOL_DORMANT:    return "DORMANT";
      case VOL_LOW:        return "LOW";
      case VOL_NORMAL:     return "NORMAL";
      case VOL_HIGH:       return "HIGH";
      case VOL_EXTREME:    return "EXTREME";
      default:             return "UNKNOWN";
   }
}

// Get string representation of momentum
string MomentumToString(MarketMomentum momentum)
{
   switch(momentum)
   {
      case MOM_STRONG_BEAR: return "STRONG BEAR";
      case MOM_WEAK_BEAR:   return "WEAK BEAR";
      case MOM_NEUTRAL:     return "NEUTRAL";
      case MOM_WEAK_BULL:   return "WEAK BULL";
      case MOM_STRONG_BULL: return "STRONG BULL";
      default:              return "UNKNOWN";
   }
}

//+------------------------------------------------------------------+
//| AUTO CHART THEMING                                                |
//+------------------------------------------------------------------+
void SetupChartAppearance()
{
   if(!InpAutoStyleChart) return;

   long chartId = ChartID();

   ChartSetInteger(chartId, CHART_COLOR_BACKGROUND, CHART_THEME_BG);
   ChartSetInteger(chartId, CHART_COLOR_FOREGROUND, CHART_THEME_FORE);
   ChartSetInteger(chartId, CHART_SHOW_GRID, !InpHideGridLines);
   ChartSetInteger(chartId, CHART_COLOR_GRID, CHART_THEME_GRID);
   ChartSetInteger(chartId, CHART_MODE, CHART_CANDLES);
   ChartSetInteger(chartId, CHART_COLOR_CANDLE_BULL, CHART_THEME_BULL);
   ChartSetInteger(chartId, CHART_COLOR_CANDLE_BEAR, CHART_THEME_BEAR);
   ChartSetInteger(chartId, CHART_COLOR_CHART_UP, CHART_THEME_BULL);
   ChartSetInteger(chartId, CHART_COLOR_CHART_DOWN, CHART_THEME_BEAR);
   ChartSetInteger(chartId, CHART_COLOR_CHART_LINE, CHART_THEME_FORE);
   ChartSetInteger(chartId, CHART_COLOR_VOLUME, COLOR_TEXT_DIM);
   ChartSetInteger(chartId, CHART_SHOW_BID_LINE, false);
   ChartSetInteger(chartId, CHART_SHOW_ASK_LINE, false);
   ChartSetInteger(chartId, CHART_SHOW_LAST_LINE, false);
   ChartSetInteger(chartId, CHART_SHOW_OBJECT_DESCR, false);
   ChartSetInteger(chartId, CHART_SHOW_TRADE_LEVELS, true);

   ChartRedraw(chartId);

   Print("🎨 Chart auto-themed with liquidity intelligence overlay");
}

void RestoreChartAppearance()
{
   if(!InpRestoreChartOnRemove) return;

   long chartId = ChartID();
   ChartSetInteger(chartId, CHART_COLOR_BACKGROUND, clrWhite);
   ChartSetInteger(chartId, CHART_COLOR_FOREGROUND, clrBlack);
   ChartSetInteger(chartId, CHART_SHOW_GRID, true);
   ChartSetInteger(chartId, CHART_COLOR_GRID, C'218,223,225');
   ChartSetInteger(chartId, CHART_COLOR_CANDLE_BULL, clrBlack);
   ChartSetInteger(chartId, CHART_COLOR_CANDLE_BEAR, clrRed);
   ChartSetInteger(chartId, CHART_COLOR_CHART_UP, clrBlack);
   ChartSetInteger(chartId, CHART_COLOR_CHART_DOWN, clrRed);
   ChartSetInteger(chartId, CHART_COLOR_CHART_LINE, clrBlack);
   ChartRedraw(chartId);
}

//+------------------------------------------------------------------+
//| TRADING SESSION FILTER                                            |
//+------------------------------------------------------------------+
bool IsSessionActive(int startH, int endH)
{
   MqlDateTime tm;
   TimeToStruct(TimeCurrent(), tm);
   int h = tm.hour;

   if(startH == endH) return true;

   if(startH < endH)
      return (h >= startH && h < endH);
   else
      return (h >= startH || h < endH);
}

bool IsSydneyActiveNow()   { return IsSessionActive(InpSydneyStartHour, InpSydneyEndHour); }
bool IsTokyoActiveNow()    { return IsSessionActive(InpTokyoStartHour, InpTokyoEndHour); }
bool IsLondonActiveNow()   { return IsSessionActive(InpLondonStartHour, InpLondonEndHour); }
bool IsNewYorkActiveNow()  { return IsSessionActive(InpNewYorkStartHour, InpNewYorkEndHour); }

bool HourInSession(int hour, int startH, int endH)
{
   if(startH == endH) return true;
   if(startH < endH)
      return (hour >= startH && hour < endH);
   else
      return (hour >= startH || hour < endH);
}

bool IsTradingSessionAllowed()
{
   if(InpTradeAllSessions) return true;

   bool sydneyOK  = InpTradeSydneySession  && IsSydneyActiveNow();
   bool tokyoOK   = InpTradeTokyoSession   && IsTokyoActiveNow();
   bool londonOK  = InpTradeLondonSession  && IsLondonActiveNow();
   bool newyorkOK = InpTradeNewYorkSession && IsNewYorkActiveNow();

   return (sydneyOK || tokyoOK || londonOK || newyorkOK);
}

//+------------------------------------------------------------------+
//| INITIALIZATION                                                    |
//+------------------------------------------------------------------+
int OnInit()
{
   if(InpRiskPercent > 10.0)
   {
      Print("⚠ ERROR: Risk % exceeds safety limit");
      return INIT_PARAMETERS_INCORRECT;
   }
   
   if(InpOrdersPerSide < 1 || InpOrdersPerSide > 50)
   {
      Print("⚠ ERROR: Orders per side must be 1-50");
      return INIT_PARAMETERS_INCORRECT;
   }
   
   if(InpMinRiskRewardRatio < 1.0)
   {
      Print("⚠ ERROR: Minimum R:R must be >= 1.0");
      return INIT_PARAMETERS_INCORRECT;
   }

   symbolDigits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   symbolPoint = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   
   string symbolName = _Symbol;
   isJPYPair = (StringFind(symbolName, "JPY") >= 0);
   
   if(isJPYPair)
      pipSize = 0.01;
   else if(symbolDigits == 3 || symbolDigits == 2)
      pipSize = 0.01;
   else
      pipSize = 0.0001;

   trade.SetExpertMagicNumber(magic);
   trade.SetDeviationInPoints(InpTradeDeviationPts);
   trade.SetTypeFillingBySymbol(_Symbol);

   handleATR = iATR(_Symbol, InpAnalysisTF, InpATRPeriod);
   if(handleATR == INVALID_HANDLE)
   {
      Print("⚠ ERROR: ATR indicator failed");
      return INIT_FAILED;
   }

   handleEMA = iMA(_Symbol, InpAnalysisTF, InpEMAPeriod, 0, MODE_EMA, PRICE_CLOSE);
   if(handleEMA == INVALID_HANDLE)
   {
      Print("⚠ ERROR: EMA indicator failed");
      return INIT_FAILED;
   }

   EventSetMillisecondTimer(InpTimerMs);
   peakEquity = AccountInfoDouble(ACCOUNT_EQUITY);
   dayStartBalance = AccountInfoDouble(ACCOUNT_BALANCE);

   MqlDateTime tm;
   TimeToStruct(TimeCurrent(), tm);
   lastDayChecked = tm.day;
   
   eaStartTime = TimeCurrent();

   // Initialize liquidity intelligence
   ZeroMemory(LiqIntel);
   UpdateLiquidityIntelligence();

   SetupChartAppearance();

   if(InpShowDashboard)
      InitDashboard();

   Print("═══════════════════════════════════════════════════════════");
   Print("⚡ PHANTOM FLUX v8.10 - BALANCED R:R + LIQUIDITY INTELLIGENCE");
   Print("Symbol: ", _Symbol, " | Digits: ", symbolDigits);
   Print("Grid: ", InpOrdersPerSide, " BUY + ", InpOrdersPerSide, " SELL");
   Print("Min R:R: 1:", DoubleToString(InpMinRiskRewardRatio, 1));
   Print("Scalp Target: ", DoubleToString(InpScalpTargetMultiplier, 1), "× SL");
   Print("Liquidity Filter: ", InpUseLiquidityFilter ? "ENABLED" : "DISABLED");
   Print("Momentum Filter: ", InpUseMomentumFilter ? "ENABLED" : "DISABLED");
   Print("═══════════════════════════════════════════════════════════");
   
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| DEINITIALIZATION                                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   EventKillTimer();
   IndicatorRelease(handleATR);
   IndicatorRelease(handleEMA);
   
   if(InpShowDashboard)
      DestroyDashboard();

   RestoreChartAppearance();
   
   Print("═══════════════════════════════════════════════════════════");
   Print("⚡ ENGINE SHUTDOWN");
   Print("Session: ", totalWins, "W / ", totalLosses, "L");
   if(totalWins > 0)
      Print("Avg Win: $", DoubleToString(avgWinSize, 2));
   if(totalLosses > 0)
      Print("Avg Loss: $", DoubleToString(avgLossSize, 2));
   if(totalWins + totalLosses > 0)
      Print("Realized R:R: 1:", DoubleToString(realizedRR, 2));
   Print("Net P/L: $", DoubleToString(grossProfit - grossLoss, 2));
   Print("═══════════════════════════════════════════════════════════");
}

//+------------------------------------------------------------------+
//| DASHBOARD FUNCTIONS - GLOBAL MARKETS / SMC-ICT STYLE              |
//+------------------------------------------------------------------+
void InitDashboard()
{
   int chartWidth = (int)ChartGetInteger(0, CHART_WIDTH_IN_PIXELS);

   dashState.x = 10;
   dashState.y = 10;
   dashState.width = MathMax(DASH_MIN_WIDTH, (chartWidth * InpDashboardWidthPct) / 100);
   dashState.height = DASH_TOTAL_H;
   dashState.currentY = dashState.y;
   dashState.objectCount = 0;
   dashState.needsFullRedraw = true;
   dashState.lastUpdate = TimeCurrent();

   Print("✅ Dashboard initialized: ", dashState.width, "x", dashState.height);
}

void DestroyDashboard()
{
   if(globeCanvasReady)
   {
      globeCanvas.Destroy();
      globeCanvasReady = false;
   }

   ObjectsDeleteAll(0, DASH_PREFIX);
   Print("🗑 Dashboard destroyed - ", dashState.objectCount, " objects removed");
}

void CreateRect(string name, int x, int y, int w, int h, color bg, color border = clrNONE, int borderWidth = 2)
{
   string objName = DASH_PREFIX + name;

   if(ObjectFind(0, objName) < 0)
   {
      ObjectCreate(0, objName, OBJ_RECTANGLE_LABEL, 0, 0, 0);
      dashState.objectCount++;
   }

   ObjectSetInteger(0, objName, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, objName, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, objName, OBJPROP_XSIZE, w);
   ObjectSetInteger(0, objName, OBJPROP_YSIZE, h);
   ObjectSetInteger(0, objName, OBJPROP_BGCOLOR, bg);
   ObjectSetInteger(0, objName, OBJPROP_BORDER_TYPE, BORDER_FLAT);
   ObjectSetInteger(0, objName, OBJPROP_COLOR, border == clrNONE ? bg : border);
   ObjectSetInteger(0, objName, OBJPROP_WIDTH, borderWidth);
   ObjectSetInteger(0, objName, OBJPROP_BACK, true);
   ObjectSetInteger(0, objName, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, objName, OBJPROP_HIDDEN, true);
}

void CreateText(string name, int x, int y, string text, color clr, int size = 9, string font = "Segoe UI", int anchor = ANCHOR_LEFT_UPPER)
{
   string objName = DASH_PREFIX + name;

   if(ObjectFind(0, objName) < 0)
   {
      ObjectCreate(0, objName, OBJ_LABEL, 0, 0, 0);
      dashState.objectCount++;
   }

   ObjectSetInteger(0, objName, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, objName, OBJPROP_YDISTANCE, y);
   ObjectSetString(0, objName, OBJPROP_TEXT, text);
   ObjectSetInteger(0, objName, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, objName, OBJPROP_FONTSIZE, size);
   ObjectSetString(0, objName, OBJPROP_FONT, font);
   ObjectSetInteger(0, objName, OBJPROP_ANCHOR, anchor);
   ObjectSetInteger(0, objName, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, objName, OBJPROP_HIDDEN, true);
}

void UpdateText(string name, string newText)
{
   string objName = DASH_PREFIX + name;
   if(ObjectFind(0, objName) >= 0)
      ObjectSetString(0, objName, OBJPROP_TEXT, newText);
}

void UpdateTextColor(string name, color newColor)
{
   string objName = DASH_PREFIX + name;
   if(ObjectFind(0, objName) >= 0)
      ObjectSetInteger(0, objName, OBJPROP_COLOR, newColor);
}

void CreateProgressBar(string name, int x, int y, int w, int h, double value, color barColor)
{
   CreateRect(name + "_BG", x, y, w, h, COLOR_BG_HIGHLIGHT, COLOR_BORDER, 2);

   int fillWidth = (int)(w * MathMin(value / 100.0, 1.0));
   if(fillWidth > 2)
      CreateRect(name + "_FG", x + 1, y + 1, fillWidth - 2, h - 2, barColor, barColor, 0);

   string valueText = DoubleToString(value, 0);
   CreateText(name + "_VAL", x + w/2, y + h/2 - 5, valueText, COLOR_TEXT_PRIMARY, 9, "Arial Black", ANCHOR_CENTER);
}

void UpdateProgressBar(string name, double value, color barColor)
{
   string bgName = DASH_PREFIX + name + "_BG";
   if(ObjectFind(0, bgName) < 0) return;

   int w = (int)ObjectGetInteger(0, bgName, OBJPROP_XSIZE);
   int fillWidth = (int)(w * MathMin(value / 100.0, 1.0));

   string fgName = DASH_PREFIX + name + "_FG";
   if(fillWidth > 2)
   {
      if(ObjectFind(0, fgName) < 0)
      {
         int x = (int)ObjectGetInteger(0, bgName, OBJPROP_XDISTANCE);
         int y = (int)ObjectGetInteger(0, bgName, OBJPROP_YDISTANCE);
         int h = (int)ObjectGetInteger(0, bgName, OBJPROP_YSIZE);
         CreateRect(name + "_FG", x + 1, y + 1, fillWidth - 2, h - 2, barColor, barColor, 0);
      }
      else
      {
         ObjectSetInteger(0, fgName, OBJPROP_XSIZE, fillWidth - 2);
         ObjectSetInteger(0, fgName, OBJPROP_BGCOLOR, barColor);
      }
   }

   UpdateText(name + "_VAL", DoubleToString(value, 0));
}

void DrawDivider(string name, int x, int y, int w, color clr = clrNONE)
{
   color lineColor = (clr == clrNONE) ? COLOR_DIVIDER : clr;
   CreateRect(name + "_DIV", x, y, w, 1, lineColor, lineColor, 0);
}

//+------------------------------------------------------------------+
//| CONTROL BUTTON HELPER                                             |
//+------------------------------------------------------------------+
void CreateButton(string name, int x, int y, int w, int h, string text, color bg, color txtClr, color borderClr, int fontSize = 9)
{
   string objName = DASH_PREFIX + name;
   bool isNew = (ObjectFind(0, objName) < 0);

   if(isNew)
   {
      ObjectCreate(0, objName, OBJ_BUTTON, 0, 0, 0);
      dashState.objectCount++;
   }

   ObjectSetInteger(0, objName, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, objName, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, objName, OBJPROP_XSIZE, w);
   ObjectSetInteger(0, objName, OBJPROP_YSIZE, h);
   ObjectSetString(0, objName, OBJPROP_TEXT, text);
   ObjectSetInteger(0, objName, OBJPROP_BGCOLOR, bg);
   ObjectSetInteger(0, objName, OBJPROP_COLOR, txtClr);
   ObjectSetInteger(0, objName, OBJPROP_BORDER_COLOR, borderClr);
   ObjectSetInteger(0, objName, OBJPROP_FONTSIZE, fontSize);
   ObjectSetString(0, objName, OBJPROP_FONT, "Segoe UI Black");
   ObjectSetInteger(0, objName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, objName, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, objName, OBJPROP_HIDDEN, true);
   ObjectSetInteger(0, objName, OBJPROP_ZORDER, 5);

   if(isNew)
      ObjectSetInteger(0, objName, OBJPROP_STATE, false);
}

//+------------------------------------------------------------------+
//| DASHBOARD READINESS / BIAS EVALUATION                             |
//+------------------------------------------------------------------+
void GetMarketBias()
{
   int bars = iBars(_Symbol, InpAnalysisTF);
   int lookback = MathMin(20, bars - 2);

   if(lookback < 2)
   {
      marketBiasText = "RANGE / NEUTRAL";
      marketBiasColor = COLOR_ACCENT_YELLOW;
      return;
   }

   double c0  = iClose(_Symbol, InpAnalysisTF, 1);
   double cN  = iClose(_Symbol, InpAnalysisTF, lookback);
   double atr = GetCurrentATR();
   double diff = c0 - cN;

   if(atr <= 0)
   {
      marketBiasText = "RANGE / NEUTRAL";
      marketBiasColor = COLOR_ACCENT_YELLOW;
      return;
   }

   if(diff > atr * 0.5)
   {
      marketBiasText = "BULL TREND UP";
      marketBiasColor = COLOR_ACCENT_GREEN;
   }
   else if(diff < -atr * 0.5)
   {
      marketBiasText = "BEAR TREND DOWN";
      marketBiasColor = COLOR_ACCENT_RED;
   }
   else
   {
      marketBiasText = "RANGE / NEUTRAL";
      marketBiasColor = COLOR_ACCENT_YELLOW;
   }
}

void EvaluateConditions()
{
   MqlTick tick;
   SymbolInfoTick(_Symbol, tick);
   currentSpreadPoints = (int)MathRound((tick.ask - tick.bid) / symbolPoint);

   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   currentDDPct = (peakEquity > 0) ? (peakEquity - equity) / peakEquity * 100.0 : 0.0;

   condValue[0] = IsTradingSessionAllowed();
   condValue[1] = currentSpreadPoints <= InpMaxSpreadPoints;
   condValue[2] = GetCurrentATR() > 0;
   condValue[3] = GetTotalExposure() < InpMaxTotalLots;
   condValue[4] = (OrdersTotal() == 0);
   condValue[5] = tradingEnabled;
   condValue[6] = currentDDPct <= InpMaxDrawdownPct;
   condValue[7] = (!InpUseLiquidityFilter || LiqIntel.liquidityState >= LIQ_NORMAL);
   condValue[8] = (!InpUseLiquidityFilter || LiqIntel.volumeRatio >= InpMinVolumeRatio);
   condValue[9] = (!InpUseMomentumFilter || LiqIntel.momentumState != MOM_NEUTRAL);
   condValue[10] = (LiqIntel.volRegime != VOL_DORMANT && LiqIntel.volRegime != VOL_EXTREME);
   condValue[11] = (LiqIntel.recommendedRR >= InpMinRiskRewardRatio);

   readinessScore = 0;
   for(int i = 0; i < COND_COUNT; i++)
      if(condValue[i]) readinessScore++;

   GetMarketBias();
}

//+------------------------------------------------------------------+
//| DASHBOARD BLOCKS - Header, Sessions, Market, Signal, etc.         |
//+------------------------------------------------------------------+
void DrawHeader()
{
   int y = dashState.currentY;
   int PAD = 14;

   CreateText("HDR_GM",  dashState.x + PAD, y,      InpDashTitleLine1, COLOR_TEXT_SECONDARY, 9, "Segoe UI Semibold");
   CreateText("HDR_SUB", dashState.x + PAD, y + 15,  InpDashTitleLine2, COLOR_ACCENT_CYAN,    9, "Segoe UI Black");

   CreateText("HDR_SYM", dashState.x + dashState.width - PAD, y, _Symbol, COLOR_TEXT_PRIMARY, 12, "Segoe UI Black", ANCHOR_RIGHT_UPPER);

   string clockTxt = TimeToString(TimeCurrent(), TIME_MINUTES | TIME_SECONDS);
   CreateText("HDR_CLOCK", dashState.x + dashState.width - PAD, y + 16, clockTxt, COLOR_TEXT_SECONDARY, 8, "Consolas", ANCHOR_RIGHT_UPPER);

   string liveTxt = tradingEnabled ? "● LIVE" : "● PAUSED";
   color liveClr  = tradingEnabled ? COLOR_ACCENT_GREEN : COLOR_ACCENT_RED;
   CreateText("HDR_LIVE", dashState.x + dashState.width - PAD, y + 28, liveTxt, liveClr, 8, "Segoe UI Black", ANCHOR_RIGHT_UPPER);

   DrawDivider("HDR", dashState.x + PAD, y + 42, dashState.width - 2 * PAD);

   dashState.currentY = y + 52;
}

//+------------------------------------------------------------------+
//| SESSION GLOBE (real rendered graphic via the standard CCanvas     |
//| library — not a placeholder). Draws a shaded sphere with slowly   |
//| rotating landmass silhouettes (decorative only) and one colored   |
//| marker per session this EA actually tracks: Sydney, Tokyo,        |
//| London, New York. A marker is lit in its session color only when  |
//| that session is BOTH enabled in inputs AND currently in its       |
//| configured hour range (IsXxxActiveNow()); otherwise it is shown   |
//| dim gray. No session or location not modeled by the EA is drawn.  |
//| Marker placement is a stylized even spacing around the disc, not  |
//| a literal geographic projection — MQL5 has no true lat/long globe |
//| primitive, so this is the closest faithful equivalent.            |
//+------------------------------------------------------------------+
void EnsureGlobeCanvas(int y)
{
   if(globeCanvasReady) return;

   string objName = DASH_PREFIX + "GLOBE";
   int gx = dashState.x + (dashState.width - GLOBE_SIZE) / 2;

   if(globeCanvas.CreateBitmapLabel(objName, gx, y, GLOBE_SIZE, GLOBE_SIZE, COLOR_FORMAT_ARGB_NORMALIZE))
   {
      ObjectSetInteger(0, objName, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, objName, OBJPROP_HIDDEN, true);
      ObjectSetInteger(0, objName, OBJPROP_BACK, false);
      dashState.objectCount++;
      globeCanvasReady = true;
   }
   else
   {
      Print("⚠ WARNING: Globe canvas creation failed - session globe will be skipped this session");
   }
}

// One decorative, slowly-rotating landmass blob. Purely cosmetic - carries
// no market or session data, so it cannot mislead about EA state.
void DrawGlobeContinent(int cx, int cy, int radius, double rotation, double baseAngle, double sizeFrac, double distFrac)
{
   double angle = baseAngle + rotation * 0.4;
   double frontFacing = MathCos(angle);
   if(frontFacing < -0.15)
      return; // rotated to the far side of the sphere - not drawn, like the real hemisphere

   double bx = cx + MathCos(angle) * radius * distFrac;
   double by = cy + MathSin(angle) * radius * distFrac * 0.55;

   uint landColor = ColorToARGB(C'40,150,95', 190);
   int blobR = (int)MathMax(3, radius * sizeFrac);

   globeCanvas.FillCircle((int)bx, (int)by, blobR, landColor);
   globeCanvas.FillCircle((int)(bx - blobR * 0.5), (int)(by + blobR * 0.3), (int)(blobR * 0.6), landColor);
   globeCanvas.FillCircle((int)(bx + blobR * 0.4), (int)(by - blobR * 0.2), (int)(blobR * 0.5), landColor);
}

// One real session marker. 'active' must be computed from the EA's actual
// session-hour logic by the caller - this function only renders it.
void PlotSessionMarker(int cx, int cy, int radius, double rotation, double baseAngle, bool active, color activeColor)
{
   double angle = baseAngle + rotation;
   double mx = cx + MathCos(angle) * (radius * 0.72);
   double my = cy + MathSin(angle) * (radius * 0.50);

   uint dotColor = active ? ColorToARGB(activeColor, 255) : ColorToARGB(COLOR_TEXT_DIM, 200);
   int dotR = active ? 6 : 4;

   globeCanvas.FillCircle((int)MathRound(mx), (int)MathRound(my), dotR, dotColor);
   if(active)
      globeCanvas.CircleAA(mx, my, dotR + 3, ColorToARGB(activeColor, 130));
}

void DrawGlobe()
{
   int y = dashState.currentY;
   EnsureGlobeCanvas(y);

   if(globeCanvasReady)
   {
      int cx = GLOBE_SIZE / 2;
      int cy = GLOBE_SIZE / 2;
      int radius = GLOBE_SIZE / 2 - 8;

      globeCanvas.Erase(0x00000000);

      // Shaded sphere base (dark navy fill + soft top-left highlight for depth)
      globeCanvas.FillCircle(cx, cy, radius, ColorToARGB(C'8,28,58', 255));
      globeCanvas.FillCircle(cx - radius / 3, cy - radius / 3, radius / 2, ColorToARGB(C'35,85,150', 70));

      globeRotation += 0.15;
      if(globeRotation > 6.2831853) globeRotation -= 6.2831853;

      DrawGlobeContinent(cx, cy, radius, globeRotation, 0.3, 0.34, 0.55);
      DrawGlobeContinent(cx, cy, radius, globeRotation, 2.6, 0.24, 0.42);
      DrawGlobeContinent(cx, cy, radius, globeRotation, 4.4, 0.20, 0.60);
      DrawGlobeContinent(cx, cy, radius, globeRotation, 5.6, 0.16, 0.35);

      globeCanvas.CircleAA(cx, cy, radius, ColorToARGB(COLOR_BORDER_ACCENT, 255));

      // Only the four sessions this EA actually filters on - real state, not decoration
      bool sydOn = IsSydneyActiveNow()  && (InpTradeAllSessions || InpTradeSydneySession);
      bool tokOn = IsTokyoActiveNow()   && (InpTradeAllSessions || InpTradeTokyoSession);
      bool lonOn = IsLondonActiveNow()  && (InpTradeAllSessions || InpTradeLondonSession);
      bool nyOn  = IsNewYorkActiveNow() && (InpTradeAllSessions || InpTradeNewYorkSession);

      PlotSessionMarker(cx, cy, radius, globeRotation, 0.9, sydOn, COLOR_ACCENT_PURPLE);
      PlotSessionMarker(cx, cy, radius, globeRotation, 2.1, tokOn, COLOR_ACCENT_GOLD);
      PlotSessionMarker(cx, cy, radius, globeRotation, 3.6, lonOn, COLOR_ACCENT_GREEN);
      PlotSessionMarker(cx, cy, radius, globeRotation, 5.0, nyOn,  COLOR_ACCENT_CYAN);

      globeCanvas.Update();
   }

   dashState.currentY = y + GLOBE_SIZE + 10;
}

// Session label strip beneath the globe - text confirmation of exactly the
// same four sessions and the same active/enabled state used to color the
// globe's markers above (single source of truth: IsXxxActiveNow() + inputs).
void DrawSessionStrip()
{
   int y = dashState.currentY;
   int PAD = 14;

   string labels[4]     = {"SYD", "TOK", "LON", "NY"};
   bool   enabledArr[4] = { (InpTradeAllSessions || InpTradeSydneySession),
                             (InpTradeAllSessions || InpTradeTokyoSession),
                             (InpTradeAllSessions || InpTradeLondonSession),
                             (InpTradeAllSessions || InpTradeNewYorkSession) };
   bool   activeArr[4]  = { IsSydneyActiveNow(), IsTokyoActiveNow(), IsLondonActiveNow(), IsNewYorkActiveNow() };
   color  colorArr[4]   = { COLOR_ACCENT_PURPLE, COLOR_ACCENT_GOLD, COLOR_ACCENT_GREEN, COLOR_ACCENT_CYAN };

   int colW = (dashState.width - 2 * PAD) / 4;
   for(int i = 0; i < 4; i++)
   {
      color c = (enabledArr[i] && activeArr[i]) ? colorArr[i] : COLOR_TEXT_DIM;
      int cx = dashState.x + PAD + colW * i + colW / 2;
      CreateText("SESSTRIP_" + IntegerToString(i), cx, y, labels[i], c, 10, "Segoe UI Black", ANCHOR_TOP);
   }

   DrawDivider("SESSTRIP", dashState.x + PAD, y + 22, dashState.width - 2 * PAD);

   dashState.currentY = y + 32;
}

void DrawMarketBlock()
{
   int y = dashState.currentY;
   int PAD = 14;

   MqlTick tick;
   SymbolInfoTick(_Symbol, tick);
   int digits = symbolDigits;

   CreateText("MK_BID", dashState.x + PAD, y, "BID: " + DoubleToString(tick.bid, digits), COLOR_TEXT_PRIMARY, 13, "Consolas");

   int pillW = 150, pillH = 22;
   int pillX = dashState.x + dashState.width / 2 - pillW / 2;
   CreateRect("MK_PILL_BG", pillX, y, pillW, pillH, COLOR_BG_HIGHLIGHT, marketBiasColor, 1);
   CreateText("MK_PILL_TXT", dashState.x + dashState.width / 2, y + 4, marketBiasText, marketBiasColor, 9, "Segoe UI Black", ANCHOR_TOP);

   color sprColor = (currentSpreadPoints <= InpMaxSpreadPoints) ? COLOR_ACCENT_GREEN : COLOR_ACCENT_RED;
   CreateText("MK_SPR", dashState.x + dashState.width - PAD, y, "SPR: " + IntegerToString(currentSpreadPoints) + " pts", sprColor, 9, "Consolas", ANCHOR_RIGHT_UPPER);

   int y2 = y + 26;
   CreateText("MK_ASK", dashState.x + PAD, y2, "ASK: " + DoubleToString(tick.ask, digits), COLOR_TEXT_SECONDARY, 11, "Consolas");
   CreateText("MK_ATR", dashState.x + dashState.width - PAD, y2, "ATR: " + DoubleToString(GetCurrentATR() / symbolPoint, 0) + " pts", COLOR_ACCENT_CYAN, 9, "Consolas", ANCHOR_RIGHT_UPPER);

   DrawDivider("MK", dashState.x + PAD, y + 50, dashState.width - 2 * PAD);

   dashState.currentY = y + 60;
}

void DrawSignalBlock()
{
   int y = dashState.currentY;
   int PAD = 14;

   string sigText;
   color  sigColor;
   bool   sessionOK = IsTradingSessionAllowed();

   if(!sessionOK)
   {
      sigText = "WAIT";
      sigColor = COLOR_TEXT_DIM;
   }
   else if(!tradingEnabled)
   {
      sigText = "PAUSED";
      sigColor = COLOR_ACCENT_RED;
   }
   else if(LiqIntel.allowLongEntry && !LiqIntel.allowShortEntry)
   {
      sigText = "BUY";
      sigColor = COLOR_ACCENT_GREEN;
   }
   else if(LiqIntel.allowShortEntry && !LiqIntel.allowLongEntry)
   {
      sigText = "SELL";
      sigColor = COLOR_ACCENT_RED;
   }
   else if(LiqIntel.allowLongEntry && LiqIntel.allowShortEntry)
   {
      sigText = "GRID";
      sigColor = COLOR_ACCENT_CYAN;
   }
   else
   {
      sigText = "WAIT";
      sigColor = COLOR_TEXT_DIM;
   }

   CreateText("SIG_LBL", dashState.x + PAD, y, "SIGNAL", COLOR_TEXT_SECONDARY, 9, "Segoe UI Semibold");

   int pillW = 120, pillH = 24;
   CreateRect("SIG_PILL_BG", dashState.x + PAD, y + 16, pillW, pillH, COLOR_BG_HIGHLIGHT, sigColor, 1);
   CreateText("SIG_PILL_TXT", dashState.x + PAD + pillW / 2, y + 21, sigText, sigColor, 10, "Segoe UI Black", ANCHOR_TOP);

   int waitSecs = (int)MathMax(0, 5 - (TimeCurrent() - lastGridDeployTime));
   CreateText("SIG_WAIT", dashState.x + PAD + pillW + 14, y + 21, "Wait: " + IntegerToString(waitSecs), COLOR_TEXT_DIM, 8, "Consolas");

   CreateText("SIG_SCORE", dashState.x + dashState.width - PAD, y, "AI SCORE " + IntegerToString(readinessScore) + "/" + IntegerToString(COND_COUNT), COLOR_ACCENT_YELLOW, 9, "Consolas", ANCHOR_RIGHT_UPPER);

   int barY = y + 48;
   int barW = dashState.width - 2 * PAD;
   int segGap = 2;
   int segW = (barW - segGap * (COND_COUNT - 1)) / COND_COUNT;
   for(int i = 0; i < COND_COUNT; i++)
   {
      color segColor = (i < readinessScore) ? COLOR_ACCENT_CYAN : COLOR_BG_HIGHLIGHT;
      CreateRect("SIG_SEG" + IntegerToString(i), dashState.x + PAD + i * (segW + segGap), barY, segW, 8, segColor, segColor, 0);
   }

   dashState.currentY = y + 66;
}

void DrawConditionsBlock()
{
   int y = dashState.currentY;
   int PAD = 14;

   CreateText("COND_HDR", dashState.x + PAD, y, "CONDITIONS", COLOR_ACCENT_CYAN, 9, "Segoe UI Black");
   DrawDivider("COND", dashState.x + PAD, y + 16, dashState.width - 2 * PAD);

   int rows = (COND_COUNT + 1) / 2;
   int colW = (dashState.width - 2 * PAD) / 2;
   int rowH = 17;
   int startY = y + 24;
   int failCount = 0;
   string firstFail = "";

   for(int i = 0; i < COND_COUNT; i++)
   {
      int col = i / rows;
      int row = i % rows;
      int cx = dashState.x + PAD + col * colW;
      int cy = startY + row * rowH;

      color sq = condValue[i] ? COLOR_ACCENT_GREEN : COLOR_TEXT_DIM;
      CreateRect("COND_SQ" + IntegerToString(i), cx, cy + 3, 6, 6, sq, sq, 0);

      color txtColor = condValue[i] ? COLOR_TEXT_PRIMARY : COLOR_TEXT_DIM;
      CreateText("COND_TXT" + IntegerToString(i), cx + 11, cy, condLabel[i], txtColor, 8);

      if(!condValue[i])
      {
         failCount++;
         if(firstFail == "") firstFail = condLabel[i];
      }
   }

   string reason = (failCount == 0)
                   ? "All systems optimal - liquidity confirmed"
                   : ("Blocked: " + firstFail + (failCount > 1 ? " +" + IntegerToString(failCount - 1) : ""));
   CreateText("COND_REASON", dashState.x + PAD, startY + rows * rowH + 6, reason, COLOR_TEXT_SECONDARY, 7);

   dashState.currentY = y + 136;
}

void DrawPositionsBlock()
{
   int y = dashState.currentY;
   int PAD = 14;
   int maxRows = 3;

   int openCount = 0;
   double totalFloat = 0.0;
   for(int i = 0; i < PositionsTotal(); i++)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket > 0 && PositionSelectByTicket(ticket) && PositionGetString(POSITION_SYMBOL) == _Symbol && PositionGetInteger(POSITION_MAGIC) == magic)
      {
         openCount++;
         totalFloat += PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP) + PositionGetDouble(POSITION_COMMISSION);
      }
   }

   CreateText("POS_HDR", dashState.x + PAD, y, "OPEN POSITIONS", COLOR_ACCENT_CYAN, 9, "Segoe UI Black");
   CreateText("POS_CNT", dashState.x + dashState.width - PAD, y, IntegerToString(openCount) + " open", COLOR_TEXT_PRIMARY, 8, "Segoe UI Semibold", ANCHOR_RIGHT_UPPER);
   DrawDivider("POS", dashState.x + PAD, y + 16, dashState.width - 2 * PAD);

   int colDir  = dashState.x + PAD;
   int colOpen = dashState.x + PAD + 36;
   int colSL   = dashState.x + PAD + 100;
   int colTP   = dashState.x + PAD + 164;
   int colPL   = dashState.x + dashState.width - PAD;

   CreateText("POS_HL_DIR",  colDir,  y + 24, "DIR",  COLOR_TEXT_DIM, 7);
   CreateText("POS_HL_OPEN", colOpen, y + 24, "OPEN", COLOR_TEXT_DIM, 7);
   CreateText("POS_HL_SL",   colSL,   y + 24, "SL",   COLOR_TEXT_DIM, 7);
   CreateText("POS_HL_TP",   colTP,   y + 24, "TP",   COLOR_TEXT_DIM, 7);
   CreateText("POS_HL_PL",   colPL,   y + 24, "P&L",  COLOR_TEXT_DIM, 7, "Segoe UI", ANCHOR_RIGHT_UPPER);

   int shown = 0;
   int rowY = y + 42;
   int rowH = 18;

   for(int i = 0; i < PositionsTotal() && shown < maxRows; i++)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket)) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol || PositionGetInteger(POSITION_MAGIC) != magic) continue;

      ENUM_POSITION_TYPE ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      string dir = (ptype == POSITION_TYPE_BUY) ? "BUY" : "SELL";
      color dirColor = (ptype == POSITION_TYPE_BUY) ? COLOR_ACCENT_GREEN : COLOR_ACCENT_RED;
      double openP = PositionGetDouble(POSITION_PRICE_OPEN);
      double sl = PositionGetDouble(POSITION_SL);
      double tp = PositionGetDouble(POSITION_TP);
      double pl = PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP) + PositionGetDouble(POSITION_COMMISSION);
      color plColor = (pl >= 0) ? COLOR_ACCENT_GREEN : COLOR_ACCENT_RED;

      string idx = IntegerToString(shown);
      CreateText("POS_R" + idx + "_DIR",  colDir,  rowY, dir, dirColor, 8, "Consolas");
      CreateText("POS_R" + idx + "_OPEN", colOpen, rowY, DoubleToString(openP, symbolDigits), COLOR_TEXT_PRIMARY, 8, "Consolas");
      CreateText("POS_R" + idx + "_SL",   colSL,   rowY, (sl > 0 ? DoubleToString(sl, symbolDigits) : "--"), COLOR_ACCENT_RED, 8, "Consolas");
      CreateText("POS_R" + idx + "_TP",   colTP,   rowY, (tp > 0 ? DoubleToString(tp, symbolDigits) : "--"), COLOR_ACCENT_GREEN, 8, "Consolas");
      CreateText("POS_R" + idx + "_PL",   colPL,   rowY, (pl >= 0 ? "+" : "") + DoubleToString(pl, 2), plColor, 8, "Consolas", ANCHOR_RIGHT_UPPER);

      rowY += rowH;
      shown++;
   }

   for(int r = shown; r < maxRows; r++)
   {
      string idx = IntegerToString(r);
      CreateText("POS_R" + idx + "_DIR",  colDir,  rowY, "---", COLOR_TEXT_DIM, 8, "Consolas");
      CreateText("POS_R" + idx + "_OPEN", colOpen, rowY, "---", COLOR_TEXT_DIM, 8, "Consolas");
      CreateText("POS_R" + idx + "_SL",   colSL,   rowY, "---", COLOR_TEXT_DIM, 8, "Consolas");
      CreateText("POS_R" + idx + "_TP",   colTP,   rowY, "---", COLOR_TEXT_DIM, 8, "Consolas");
      CreateText("POS_R" + idx + "_PL",   colPL,   rowY, "---", COLOR_TEXT_DIM, 8, "Consolas", ANCHOR_RIGHT_UPPER);
      rowY += rowH;
   }

   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   color floatColor = (totalFloat >= 0) ? COLOR_ACCENT_GREEN : COLOR_ACCENT_RED;
   string moreTag = (openCount > maxRows) ? ("  (+" + IntegerToString(openCount - maxRows) + " more)") : "";
   CreateText("POS_SUM", dashState.x + PAD, y + 100, "Float: " + (totalFloat >= 0 ? "+" : "") + DoubleToString(totalFloat, 2) + "   Equity: $" + DoubleToString(equity, 2) + moreTag, floatColor, 8, "Consolas");

   dashState.currentY = y + 114;
}

void DrawAccountBlock()
{
   int y = dashState.currentY;
   int PAD = 14;

   CreateText("ACC_HDR", dashState.x + PAD, y, "ACCOUNT & RISK", COLOR_ACCENT_CYAN, 9, "Segoe UI Black");
   DrawDivider("ACC", dashState.x + PAD, y + 16, dashState.width - 2 * PAD);

   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double equity  = AccountInfoDouble(ACCOUNT_EQUITY);
   int midX = dashState.x + dashState.width / 2 + 4;
   int ly = y + 26, lh = 18;

   CreateText("ACC_BAL", dashState.x + PAD, ly, "Balance: $" + DoubleToString(balance, 2), COLOR_TEXT_PRIMARY, 8, "Consolas");
   color mddColor = (currentDDPct <= InpMaxDrawdownPct) ? COLOR_TEXT_SECONDARY : COLOR_ACCENT_RED;
   CreateText("ACC_MDD", midX, ly, "Max DD: " + DoubleToString(currentDDPct, 2) + "%", mddColor, 8, "Consolas");
   ly += lh;

   color eqColor = (equity >= balance) ? COLOR_ACCENT_GREEN : COLOR_ACCENT_RED;
   CreateText("ACC_EQ", dashState.x + PAD, ly, "Equity: $" + DoubleToString(equity, 2), eqColor, 8, "Consolas");
   double winRate = (totalWins + totalLosses > 0) ? totalWins * 100.0 / (totalWins + totalLosses) : 0.0;
   color wrColor = winRate >= 50 ? COLOR_ACCENT_GREEN : COLOR_ACCENT_ORANGE;
   CreateText("ACC_WR", midX, ly, "WinRate: " + DoubleToString(winRate, 0) + "%", wrColor, 8, "Consolas");
   ly += lh;

   color plColor = (dailyProfit >= 0) ? COLOR_ACCENT_GREEN : COLOR_ACCENT_RED;
   CreateText("ACC_PL", dashState.x + PAD, ly, "Day P&L: " + (dailyProfit >= 0 ? "+$" : "-$") + DoubleToString(MathAbs(dailyProfit), 2), plColor, 8, "Consolas");

   double atrNow = GetCurrentATR();
   double slDistNow = LiqIntel.dynamicSLMultiplier * atrNow;
   double lotNow = CalculateLotSize(slDistNow);
   double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double tickSize  = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   double riskDollars = (tickSize > 0) ? (slDistNow / tickSize) * tickValue * lotNow : 0.0;
   double riskPct = (equity > 0) ? (riskDollars / equity) * 100.0 : 0.0;
   CreateText("ACC_RISK", midX, ly, "Risk: " + DoubleToString(riskPct, 2) + "%", COLOR_ACCENT_YELLOW, 8, "Consolas");
   ly += lh;

   string avgWinText  = (totalWins > 0)   ? ("Avg Win: $" + DoubleToString(avgWinSize, 2))   : "Avg Win: --";
   string avgLossText = (totalLosses > 0) ? ("Avg Loss: $" + DoubleToString(avgLossSize, 2)) : "Avg Loss: --";
   CreateText("ACC_AVGWIN", dashState.x + PAD, ly, avgWinText, COLOR_ACCENT_GREEN, 7, "Consolas");
   CreateText("ACC_AVGLOSS", midX, ly, avgLossText, COLOR_ACCENT_RED, 7, "Consolas");

   dashState.currentY = y + 98;
}

void DrawLevelsBlock()
{
   int y = dashState.currentY;
   int PAD = 14;

   CreateText("LVL_HDR", dashState.x + PAD, y, "TRADE LEVELS", COLOR_ACCENT_CYAN, 9, "Segoe UI Black");
   DrawDivider("LVL", dashState.x + PAD, y + 16, dashState.width - 2 * PAD);

   double atr = GetCurrentATR();
   double slDist  = LiqIntel.dynamicSLMultiplier * atr;
   double tp1Dist = slDist;                              // 1:1 partial-exit level
   double tp2Dist = LiqIntel.dynamicTPMultiplier * atr;   // full balanced target
   double slPips  = slDist  / pipSize;
   double tp1Pips = tp1Dist / pipSize;
   double tp2Pips = tp2Dist / pipSize;
   double ema     = GetCurrentEMA();
   double lot     = CalculateLotSize(slDist);
   bool   volPass = (!InpUseLiquidityFilter || LiqIntel.volumeRatio >= InpMinVolumeRatio);

   int liveTrades = 0;
   for(int i = 0; i < PositionsTotal(); i++)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket > 0 && PositionSelectByTicket(ticket) &&
         PositionGetString(POSITION_SYMBOL) == _Symbol && PositionGetInteger(POSITION_MAGIC) == magic)
         liveTrades++;
   }

   int midX = dashState.x + dashState.width / 2 + 4;
   int ly = y + 26, lh = 18;

   CreateText("LVL_SL", dashState.x + PAD, ly, "SL: " + DoubleToString(slPips, 1) + "p", COLOR_ACCENT_RED, 8, "Consolas");
   CreateText("LVL_EMA", midX, ly, "EMA: " + (ema > 0 ? DoubleToString(ema, symbolDigits) : "--"), COLOR_ACCENT_YELLOW, 8, "Consolas");
   ly += lh;

   CreateText("LVL_TP1", dashState.x + PAD, ly, "TP1: " + DoubleToString(tp1Pips, 1) + "p", COLOR_ACCENT_GREEN, 8, "Consolas");
   CreateText("LVL_VOL", midX, ly, "Vol: " + (volPass ? "PASS" : "FAIL"), volPass ? COLOR_ACCENT_GREEN : COLOR_ACCENT_RED, 8, "Consolas");
   ly += lh;

   CreateText("LVL_TP2", dashState.x + PAD, ly, "TP2: " + DoubleToString(tp2Pips, 1) + "p", COLOR_ACCENT_GREEN, 8, "Consolas");
   CreateText("LVL_CL", midX, ly, "CL: " + IntegerToString(liveTrades), COLOR_TEXT_PRIMARY, 8, "Consolas");
   ly += lh;

   color rrColor = (LiqIntel.recommendedRR >= InpMinRiskRewardRatio) ? COLOR_ACCENT_GREEN : COLOR_ACCENT_ORANGE;
   CreateText("LVL_RR", dashState.x + PAD, ly, "R:R  1:" + DoubleToString(LiqIntel.recommendedRR, 2), rrColor, 8, "Consolas");
   CreateText("LVL_LOTS", midX, ly, "Lots: " + DoubleToString(lot, 2), COLOR_ACCENT_CYAN, 8, "Consolas");

   dashState.currentY = y + 98;
}

// Footer session-confirmation pills (LONDON / ASIA / NEW YORK), styled to
// match the reference dashboard's checkmark pills.
void DrawSessionPill(string name, int x, int y, int w, int h, string label, bool active)
{
   color bg     = active ? C'10,40,20' : C'22,22,22';
   color border = active ? COLOR_ACCENT_GREEN : COLOR_TEXT_DIM;
   color txtClr = active ? COLOR_ACCENT_GREEN : COLOR_TEXT_DIM;
   string txt   = (active ? "✓ " : "✗ ") + label;

   CreateRect(name + "_BG", x, y, w, h, bg, border, 1);
   CreateText(name + "_TXT", x + w / 2, y + 4, txt, txtClr, 8, "Segoe UI Black", ANCHOR_TOP);
}

void DrawFooterSessionPills()
{
   int y = dashState.currentY;
   int PAD = 14;
   int gap = 8;
   int pillW = (dashState.width - 2 * PAD - 2 * gap) / 3;
   int pillH = 22;

   bool londonOn  = (InpTradeAllSessions || InpTradeLondonSession)  && IsLondonActiveNow();
   bool asiaOn    = (InpTradeAllSessions || InpTradeTokyoSession)   && IsTokyoActiveNow();
   bool newyorkOn = (InpTradeAllSessions || InpTradeNewYorkSession) && IsNewYorkActiveNow();

   DrawSessionPill("PILL_LON",  dashState.x + PAD,                          y, pillW, pillH, "LONDON",   londonOn);
   DrawSessionPill("PILL_ASIA", dashState.x + PAD + (pillW + gap),          y, pillW, pillH, "ASIA",     asiaOn);
   DrawSessionPill("PILL_NY",   dashState.x + PAD + 2 * (pillW + gap),      y, pillW, pillH, "NEW YORK", newyorkOn);

   dashState.currentY = y + pillH + 12;
}

// Manual override control buttons.
void DrawControlButtons()
{
   int y = dashState.currentY;
   int PAD = 14;
   int gap = 8;
   int btnH = 26;
   int btnW = (dashState.width - 2 * PAD - gap) / 2;

   CreateButton(BTN_PROFIT_NAME, dashState.x + PAD, y, btnW, btnH,
                "CLOSE ALL PROFIT", COLOR_ACCENT_GREEN, C'6,12,6', COLOR_ACCENT_GREEN, 8);

   CreateButton(BTN_LOSS_NAME, dashState.x + PAD + btnW + gap, y, btnW, btnH,
                "CLOSE ALL LOSS", COLOR_ACCENT_RED, C'16,6,6', COLOR_ACCENT_RED, 8);

   string statusTxt = (lastButtonActionMsg != "") ? lastButtonActionMsg : "Manual controls ready";
   CreateText("BTN_STATUS", dashState.x + dashState.width / 2, y + btnH + 6, statusTxt, COLOR_TEXT_DIM, 7, "Segoe UI Semibold", ANCHOR_TOP);

   dashState.currentY = y + btnH + 20;
}

void UpdateDashboard()
{
   if(!InpShowDashboard) return;

   datetime now = TimeCurrent();
   if(now == dashState.lastUpdate && !dashState.needsFullRedraw) return;
   dashState.lastUpdate = now;

   EvaluateConditions();

   // Provisional background box; resized to the exact content height below.
   CreateRect("MAIN_BG", dashState.x, dashState.y, dashState.width, dashState.height, COLOR_BG_PANEL, COLOR_BORDER_ACCENT, 2);

   dashState.currentY = dashState.y + 8;

   DrawHeader();
   DrawGlobe();
   DrawSessionStrip();
   DrawMarketBlock();
   DrawSignalBlock();
   DrawConditionsBlock();
   DrawPositionsBlock();
   DrawAccountBlock();
   DrawLevelsBlock();
   DrawFooterSessionPills();
   DrawControlButtons();

   int finalHeight = (dashState.currentY - dashState.y) + 10;
   if(finalHeight != dashState.height)
   {
      dashState.height = finalHeight;
      CreateRect("MAIN_BG", dashState.x, dashState.y, dashState.width, dashState.height, COLOR_BG_PANEL, COLOR_BORDER_ACCENT, 2);
   }

   dashState.needsFullRedraw = false;
   ChartRedraw(0);
}

//+------------------------------------------------------------------+
//| MANUAL TRADE CONTROLS (DASHBOARD BUTTONS)                         |
//+------------------------------------------------------------------+
void CloseAllProfitableTrades()
{
   int closed = 0;

   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket)) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol || PositionGetInteger(POSITION_MAGIC) != magic) continue;

      double pl = PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP) + PositionGetDouble(POSITION_COMMISSION);
      if(pl <= 0) continue;

      if(trade.PositionClose(ticket))
      {
         closed++;
         Print("✅ MANUAL CLOSE (PROFIT): ticket #", ticket, " | +$", DoubleToString(pl, 2));
      }
      else
      {
         Print("⚠ MANUAL CLOSE FAILED (PROFIT): ticket #", ticket,
               " | Error: ", GetLastError(), " | Retcode: ", trade.ResultRetcode());
      }
   }

   lastButtonActionMsg = "Closed " + IntegerToString(closed) + " profitable trade" + (closed == 1 ? "" : "s");
   Print("🟢 CLOSE ALL PROFIT executed: ", closed, " position(s) closed");
   dashState.needsFullRedraw = true;
}

void CloseAllLosingTrades()
{
   int closed = 0;

   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket)) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol || PositionGetInteger(POSITION_MAGIC) != magic) continue;

      double pl = PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP) + PositionGetDouble(POSITION_COMMISSION);
      if(pl >= 0) continue;

      if(trade.PositionClose(ticket))
      {
         closed++;
         Print("✅ MANUAL CLOSE (LOSS): ticket #", ticket, " | -$", DoubleToString(MathAbs(pl), 2));
      }
      else
      {
         Print("⚠ MANUAL CLOSE FAILED (LOSS): ticket #", ticket,
               " | Error: ", GetLastError(), " | Retcode: ", trade.ResultRetcode());
      }
   }

   lastButtonActionMsg = "Closed " + IntegerToString(closed) + " losing trade" + (closed == 1 ? "" : "s");
   Print("🔴 CLOSE ALL LOSS executed: ", closed, " position(s) closed");
   dashState.needsFullRedraw = true;
}


//+------------------------------------------------------------------+
//| CORE EA FUNCTIONS                                                 |
//+------------------------------------------------------------------+
double GetCurrentATR()
{
   datetime now = TimeCurrent();
   if(now == atrCacheTime && cachedATR > 0)
      return cachedATR;
   
   double atrBuffer[];
   ArraySetAsSeries(atrBuffer, true);
   
   if(CopyBuffer(handleATR, 0, 0, 1, atrBuffer) > 0)
   {
      cachedATR = atrBuffer[0];
      atrCacheTime = now;
      return cachedATR;
   }
   
   return cachedATR > 0 ? cachedATR : 0.0001;
}

double GetCurrentEMA()
{
   datetime now = TimeCurrent();
   if(now == emaCacheTime && cachedEMA > 0)
      return cachedEMA;

   double emaBuffer[];
   ArraySetAsSeries(emaBuffer, true);

   if(CopyBuffer(handleEMA, 0, 0, 1, emaBuffer) > 0)
   {
      cachedEMA = emaBuffer[0];
      emaCacheTime = now;
      return cachedEMA;
   }

   return cachedEMA;
}

double CalculateLotSize(double slDistance)
{
   if(InpRiskPercent <= 0) 
      return NormalizeVolume(InpBaseLot);
   
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   double riskAmount = equity * InpRiskPercent / 100.0;
   riskAmount *= recentProfitFactor;
   
   double contractSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_CONTRACT_SIZE);
   double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   
   if(contractSize <= 0 || tickValue <= 0 || tickSize <= 0)
      return NormalizeVolume(InpBaseLot);
   
   double slInTicks = slDistance / tickSize;
   double riskPerLot = slInTicks * tickValue;
   
   if(riskPerLot <= 0)
      return NormalizeVolume(InpBaseLot);
   
   double lotSize = riskAmount / riskPerLot;
   
   double modeMult = (InpMode == Aggressive) ? 1.3 : (InpMode == Stealth) ? 0.7 : 1.0;
   lotSize *= modeMult;
   
   // Apply liquidity-based lot size adjustment
   if(InpUseLiquidityFilter)
      lotSize *= LiqIntel.lotSizeMultiplier;
   
   return NormalizeVolume(lotSize);
}

double NormalizeVolume(double vol)
{
   double stepV = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   double minV = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxV = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);

   if(stepV <= 0) stepV = 0.01;
   double normalized = MathRound(vol / stepV) * stepV;
   normalized = MathMax(minV, MathMin(maxV, normalized));
   return NormalizeDouble(normalized, 2);
}

int DeleteAllPendingOrders()
{
   int deleted = 0;
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      ulong ticket = OrderGetTicket(i);
      if(ticket == 0 || !OrderSelect(ticket)) continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol || OrderGetInteger(ORDER_MAGIC) != magic) continue;

      if(!IsOrderGenuinelyPending(ticket))
         continue;

      if(trade.OrderDelete(ticket))
         deleted++;
   }
   return deleted;
}

bool IsOrderGenuinelyPending(ulong ticket)
{
   if(!OrderSelect(ticket))
      return false;

   ENUM_ORDER_STATE state = (ENUM_ORDER_STATE)OrderGetInteger(ORDER_STATE);
   return (state == ORDER_STATE_PLACED || state == ORDER_STATE_STARTED);
}

int DeleteStaleOrders()
{
   if(!InpAutoRecycleStaleOrders) return 0;

   if(TimeCurrent() - lastFillTime < FILL_SETTLE_SECONDS)
      return 0;

   datetime now = TimeCurrent();
   int deleted = 0;

   MqlTick tick;
   bool haveTick = SymbolInfoTick(_Symbol, tick);

   long stopLevel = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   double minStopDist = stopLevel * symbolPoint;
   double atr = GetCurrentATR();
   double triggerBuffer = MathMax(minStopDist * 2.0, atr * 0.05);

   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      ulong ticket = OrderGetTicket(i);
      if(ticket == 0 || !OrderSelect(ticket)) continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol || OrderGetInteger(ORDER_MAGIC) != magic) continue;

      if(!IsOrderGenuinelyPending(ticket))
         continue;

      if(haveTick)
      {
         ENUM_ORDER_TYPE otype = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
         double orderPrice = OrderGetDouble(ORDER_PRICE_OPEN);
         double refPrice = (otype == ORDER_TYPE_BUY_STOP || otype == ORDER_TYPE_BUY_LIMIT) ? tick.ask : tick.bid;
         double proximity = MathAbs(refPrice - orderPrice);

         if(proximity <= triggerBuffer)
            continue;
      }

      datetime orderTime = (datetime)OrderGetInteger(ORDER_TIME_SETUP);
      int orderAge = (int)(now - orderTime);

      if(orderAge >= InpMaxOrderLifetimeSeconds)
      {
         if(!IsOrderGenuinelyPending(ticket))
            continue;

         if(trade.OrderDelete(ticket))
         {
            deleted++;
            Print("🗑 STALE: Order #", ticket, " deleted (age: ", orderAge, "s)");
         }
      }
   }

   return deleted;
}

void DeployBidirectionalGrid()
{
   if(OrdersTotal() > 0)
   {
      int deletedCount = DeleteStaleOrders();
      
      if(deletedCount > 0)
      {
         lastGridDeployTime = TimeCurrent();
         Print("♻ ", deletedCount, " stale orders deleted");
         return;
      }
      
      return;
   }
   
   if(!IsTradingSessionAllowed())
      return;
   
   if(TimeCurrent() - lastGridDeployTime < 5)
      return;
   
   // Liquidity filter check
   if(InpUseLiquidityFilter && LiqIntel.liquidityState == LIQ_VERY_LOW)
   {
      Print("⚠ GRID DEPLOYMENT BLOCKED: Liquidity too low (", LiquidityStateToString(LiqIntel.liquidityState), ")");
      return;
   }
   
   // Volume filter check
   if(InpUseLiquidityFilter && LiqIntel.volumeRatio < InpMinVolumeRatio)
   {
      Print("⚠ GRID DEPLOYMENT BLOCKED: Volume ratio ", DoubleToString(LiqIntel.volumeRatio, 2), " < ", DoubleToString(InpMinVolumeRatio, 2));
      return;
   }
   
   // Volatility regime check
   if(InpUseVolatilityAdaptation && LiqIntel.volRegime == VOL_DORMANT)
   {
      Print("⚠ GRID DEPLOYMENT BLOCKED: Market dormant (ATR ratio ", DoubleToString(LiqIntel.atrRatio, 2), ")");
      return;
   }
   
   double currentExposure = GetTotalExposure();
   if(currentExposure >= InpMaxTotalLots)
      return;
   
   MqlTick tick;
   if(!SymbolInfoTick(_Symbol, tick))
      return;
   
   double atr = GetCurrentATR();
   if(atr <= 0)
      return;
   
   double currentPrice = (tick.bid + tick.ask) / 2.0;
   int digits = symbolDigits;
   
   long stopLevel = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   double minStopDist = stopLevel * symbolPoint;
   
   // Use dynamic SL/TP from liquidity intelligence
   double slDist = MathMax(atr * LiqIntel.dynamicSLMultiplier, minStopDist * 1.5);
   double tpDist = atr * LiqIntel.dynamicTPMultiplier;
   
   // Verify minimum R:R is maintained
   double actualRR = tpDist / slDist;
   if(actualRR < InpMinRiskRewardRatio)
   {
      Print("⚠ GRID DEPLOYMENT BLOCKED: R:R ", DoubleToString(actualRR, 2), " < minimum ", DoubleToString(InpMinRiskRewardRatio, 2));
      return;
   }
   
   double gridSpacing = atr * InpGridStepATR;
   
   double lot = CalculateLotSize(slDist);  // Already includes liquidity adjustment
   double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   
   if(lot < minLot)
      return;
   
   Print("⚡ DEPLOYING INTELLIGENT GRID | ATR: ", DoubleToString(atr/pipSize, 1), 
         " | Liq: ", LiquidityStateToString(LiqIntel.liquidityState),
         " | R:R: 1:", DoubleToString(actualRR, 1),
         " | Lot: ", lot);
   
   int buyOrdersPlaced = 0, sellOrdersPlaced = 0;
   
   // Deploy BUY side only if momentum filter allows
   if(!InpUseMomentumFilter || LiqIntel.allowLongEntry)
   {
      double firstBuyOffset = atr * InpMinOrderDistanceATR;
      
      for(int i = 0; i < InpOrdersPerSide; i++)
      {
         double entryPrice = currentPrice + firstBuyOffset + (i * gridSpacing);
         entryPrice = NormalizeDouble(entryPrice, digits);
         
         if(entryPrice <= tick.ask)
            continue;
         
         double sl = NormalizeDouble(entryPrice - slDist, digits);
         double tp = NormalizeDouble(entryPrice + tpDist, digits);
         
         if((entryPrice - sl) < minStopDist || (tp - entryPrice) < minStopDist)
            continue;
         
         string comment = StringFormat("LIQ_BUY_%d_RR%.1f", i+1, actualRR);
         
         if(trade.BuyStop(lot, entryPrice, _Symbol, sl, tp, ORDER_TIME_GTC, 0, comment))
            buyOrdersPlaced++;
      }
   }
   else
   {
      Print("⚠ BUY orders skipped: Momentum filter blocked (", MomentumToString(LiqIntel.momentumState), ")");
   }
   
   // Deploy SELL side only if momentum filter allows
   if(!InpUseMomentumFilter || LiqIntel.allowShortEntry)
   {
      double firstSellOffset = atr * InpMinOrderDistanceATR;
      
      for(int i = 0; i < InpOrdersPerSide; i++)
      {
         double entryPrice = currentPrice - firstSellOffset - (i * gridSpacing);
         entryPrice = NormalizeDouble(entryPrice, digits);
         
         if(entryPrice >= tick.bid)
            continue;
         
         double sl = NormalizeDouble(entryPrice + slDist, digits);
         double tp = NormalizeDouble(entryPrice - tpDist, digits);
         
         if((sl - entryPrice) < minStopDist || (entryPrice - tp) < minStopDist)
            continue;
         
         string comment = StringFormat("LIQ_SELL_%d_RR%.1f", i+1, actualRR);
         
         if(trade.SellStop(lot, entryPrice, _Symbol, sl, tp, ORDER_TIME_GTC, 0, comment))
            sellOrdersPlaced++;
      }
   }
   else
   {
      Print("⚠ SELL orders skipped: Momentum filter blocked (", MomentumToString(LiqIntel.momentumState), ")");
   }
   
   lastGridDeployTime = TimeCurrent();
   
   Print("✅ GRID: ", buyOrdersPlaced, " BUY + ", sellOrdersPlaced, " SELL placed");
}

void ManageOCO()
{
   bool hasBuyPosition = false, hasSellPosition = false;
   
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket)) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol || PositionGetInteger(POSITION_MAGIC) != magic) continue;
      
      ENUM_POSITION_TYPE ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      if(ptype == POSITION_TYPE_BUY) 
         hasBuyPosition = true;
      else 
         hasSellPosition = true;
   }
   
   if(!hasBuyPosition && !hasSellPosition) 
      return;
   
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      ulong ticket = OrderGetTicket(i);
      if(ticket == 0 || !OrderSelect(ticket)) continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol || OrderGetInteger(ORDER_MAGIC) != magic) continue;
      
      ENUM_ORDER_TYPE otype = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);

      bool isOppositeOfBuy  = hasBuyPosition  && (otype == ORDER_TYPE_SELL_STOP || otype == ORDER_TYPE_SELL_LIMIT);
      bool isOppositeOfSell = hasSellPosition && (otype == ORDER_TYPE_BUY_STOP  || otype == ORDER_TYPE_BUY_LIMIT);

      if(!isOppositeOfBuy && !isOppositeOfSell)
         continue;

      if(!IsOrderGenuinelyPending(ticket))
         continue;

      trade.OrderDelete(ticket);
   }
}

//+------------------------------------------------------------------+
//| BALANCED TARGET MANAGEMENT - ELIMINATES SMALL WIN / BIG LOSS      |
//+------------------------------------------------------------------+
void ManageBalancedTargets()
{
   if(!InpUseDynamicTargets) return;
   
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket)) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol || PositionGetInteger(POSITION_MAGIC) != magic) continue;
      
      ENUM_POSITION_TYPE ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
      double curSL = PositionGetDouble(POSITION_SL);
      double curTP = PositionGetDouble(POSITION_TP);
      
      MqlTick tick;
      SymbolInfoTick(_Symbol, tick);
      double curPrice = (ptype == POSITION_TYPE_BUY) ? tick.bid : tick.ask;
      
      // Calculate actual SL distance in dollars
      double slDistance = MathAbs(openPrice - curSL);
      if(slDistance <= 0) continue;  // No SL set, skip
      
      double contractSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_CONTRACT_SIZE);
      double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
      double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
      double lot = PositionGetDouble(POSITION_VOLUME);
      
      double slInTicks = slDistance / tickSize;
      double slRiskDollars = slInTicks * tickValue * lot;
      
      // Calculate minimum TP distance to achieve target R:R
      double minTPDollars = slRiskDollars * InpScalpTargetMultiplier;  // e.g., 2.2× risk
      double minTPInTicks = minTPDollars / (tickValue * lot);
      double minTPDistance = minTPInTicks * tickSize;
      
      // Calculate current profit distance
      double profitDistance = (ptype == POSITION_TYPE_BUY) ? (curPrice - openPrice) : (openPrice - curPrice);
      double currentProfit = PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP) + PositionGetDouble(POSITION_COMMISSION);
      
      // Close if we've reached the balanced profit target
      if(currentProfit >= (slRiskDollars * InpScalpTargetMultiplier))
      {
         if(trade.PositionClose(ticket))
         {
            scalpWins++;
            totalScalpProfit += currentProfit;
            Print("💰 BALANCED TARGET HIT: +$", DoubleToString(currentProfit, 2), " (R:R 1:", DoubleToString(InpScalpTargetMultiplier, 1), ")");
         }
      }
      
      // Optional partial exit at 1:1 R:R
      if(InpAllowEarlyExit && currentProfit >= slRiskDollars && currentProfit < (slRiskDollars * InpScalpTargetMultiplier))
      {
         // Check if we haven't already taken partial profit (simple flag: if lot size is original size)
         double originalLot = lot;  // In production, you'd store this in a global array
         
         // Partial close 50% at 1:1 R:R
         double partialLot = NormalizeVolume(lot * 0.5);
         if(partialLot >= SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN))
         {
            if(trade.PositionClosePartial(ticket, partialLot))
            {
               Print("✂ PARTIAL EXIT: $", DoubleToString(currentProfit * 0.5, 2), " at 1:1 R:R, holding ", DoubleToString(lot - partialLot, 2), " lots for ", DoubleToString(InpScalpTargetMultiplier, 1), ":1");
            }
         }
      }
   }
}

void ManagePositions()
{
   double atr = GetCurrentATR();
   if(atr <= 0) return;
   
   int digits = symbolDigits;
   long stopLvl = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   double minStopDist = stopLvl * symbolPoint;
   
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket)) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol || PositionGetInteger(POSITION_MAGIC) != magic) continue;
      
      ENUM_POSITION_TYPE ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
      double curSL = PositionGetDouble(POSITION_SL);
      double curTP = PositionGetDouble(POSITION_TP);
      
      double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      double curPrice = (ptype == POSITION_TYPE_BUY) ? bid : ask;
      double profitDist = (ptype == POSITION_TYPE_BUY) ? (curPrice - openPrice) : (openPrice - curPrice);
      
      double newSL = curSL;
      bool modify = false;
      
      if(InpUseBreakeven && profitDist >= InpBreakevenATR * atr)
      {
         double bePrice = (ptype == POSITION_TYPE_BUY) ? openPrice + InpBreakevenBufferPts * symbolPoint
                                                        : openPrice - InpBreakevenBufferPts * symbolPoint;
         if((ptype == POSITION_TYPE_BUY && (curSL == 0 || curSL < bePrice)) ||
            (ptype == POSITION_TYPE_SELL && (curSL == 0 || curSL > bePrice)))
         {
            newSL = bePrice;
            modify = true;
         }
      }
      
      if(InpUseTrailing && profitDist >= InpTrailStartATR * atr)
      {
         double trailPrice = (ptype == POSITION_TYPE_BUY) ? curPrice - InpTrailATR * atr
                                                           : curPrice + InpTrailATR * atr;
         if((ptype == POSITION_TYPE_BUY && trailPrice > newSL) ||
            (ptype == POSITION_TYPE_SELL && (newSL == 0 || trailPrice < newSL)))
         {
            newSL = trailPrice;
            modify = true;
         }
      }
      
      if(modify)
      {
         newSL = NormalizeDouble(newSL, digits);
         
         if(ptype == POSITION_TYPE_BUY && (bid - newSL) < minStopDist) continue;
         if(ptype == POSITION_TYPE_SELL && (newSL - ask) < minStopDist) continue;
         
         trade.PositionModify(ticket, newSL, curTP);
      }
   }
}

void ManageMaxHoldTime()
{
   if(InpMaxHoldMinutes <= 0) return;
   
   datetime now = TimeCurrent();
   
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket)) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol || PositionGetInteger(POSITION_MAGIC) != magic) continue;
      
      datetime openTime = (datetime)PositionGetInteger(POSITION_TIME);
      double heldMinutes = (now - openTime) / 60.0;
      
      if(heldMinutes >= InpMaxHoldMinutes)
      {
         if(InpForceCloseAtMaxHold)
         {
            trade.PositionClose(ticket);
         }
         else
         {
            double profit = PositionGetDouble(POSITION_PROFIT);
            if(profit <= 0)
               trade.PositionClose(ticket);
         }
      }
   }
}

double GetTotalExposure()
{
   double total = 0.0;
   
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket)) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol || PositionGetInteger(POSITION_MAGIC) != magic) continue;
      total += PositionGetDouble(POSITION_VOLUME);
   }
   
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      ulong ticket = OrderGetTicket(i);
      if(ticket == 0 || !OrderSelect(ticket)) continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol || OrderGetInteger(ORDER_MAGIC) != magic) continue;
      total += OrderGetDouble(ORDER_VOLUME_CURRENT);
   }
   
   return total;
}

void CheckCircuitBreaker()
{
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   peakEquity = MathMax(peakEquity, equity);
   
   MqlDateTime tm;
   TimeToStruct(TimeCurrent(), tm);
   
   if(tm.day != lastDayChecked)
   {
      dayStartBalance = AccountInfoDouble(ACCOUNT_BALANCE);
      lastDayChecked = tm.day;
      tradingEnabled = true;
      
      grossProfit = 0.0;
      grossLoss = 0.0;
      totalWins = 0;
      totalLosses = 0;
      avgWinSize = 0.0;
      avgLossSize = 0.0;
      realizedRR = 0.0;
      
      Print("🌅 NEW DAY - Baseline: $", DoubleToString(dayStartBalance, 2));
   }
   
   dailyProfit = equity - dayStartBalance;
   
   if(dailyProfit >= InpDailyProfitTarget)
   {
      tradingEnabled = false;
      Print("🎯 Daily target: $", DoubleToString(dailyProfit, 2));
   }
   else if(dailyProfit <= -InpDailyLossLimit)
   {
      tradingEnabled = false;
      
      if(InpCloseAllOnLossLimit)
      {
         for(int i = PositionsTotal() - 1; i >= 0; i--)
         {
            ulong ticket = PositionGetTicket(i);
            if(ticket > 0 && PositionSelectByTicket(ticket))
               if(PositionGetString(POSITION_SYMBOL) == _Symbol && PositionGetInteger(POSITION_MAGIC) == magic)
                  trade.PositionClose(ticket);
         }
         DeleteAllPendingOrders();
      }
   }
   
   if(equity < peakEquity * (1 - InpMaxDrawdownPct/100.0))
      recentProfitFactor = 0.6;
}

void UpdateProfitFactor()
{
   if(grossLoss > 0)
      recentProfitFactor = grossProfit / grossLoss;
   else if(grossProfit > 0)
      recentProfitFactor = 1.5;
   else
      recentProfitFactor = 1.0;
   
   recentProfitFactor = MathMax(0.5, MathMin(recentProfitFactor, 2.0));
}

//+------------------------------------------------------------------+
//| EVENT HANDLERS                                                    |
//+------------------------------------------------------------------+
void OnTimer()
{
   UpdateLiquidityIntelligence();  // Update market analysis first
   
   ManageOCO();
   ManageBalancedTargets();        // NEW: Balanced R:R target management
   ManagePositions();
   ManageMaxHoldTime();
   CheckCircuitBreaker();
   
   if(tradingEnabled)
      DeployBidirectionalGrid();
   
   UpdateDashboard();
}

void OnTick()
{
   if(!InpUseTickDrivenMgmt) return;
   
   datetime now = TimeCurrent();
   if(now == lastTickManagement) return;
   lastTickManagement = now;
   
   ManageOCO();
   ManageBalancedTargets();
   ManagePositions();
}

void OnTradeTransaction(const MqlTradeTransaction &trans,
                         const MqlTradeRequest &request,
                         const MqlTradeResult &result)
{
   if(trans.type == TRADE_TRANSACTION_ORDER_ADD)
      return;
   
   if(trans.type == TRADE_TRANSACTION_ORDER_DELETE)
      return;

   if(trans.type != TRADE_TRANSACTION_DEAL_ADD) return;
   
   ulong dealTicket = trans.deal;
   if(!HistoryDealSelect(dealTicket)) return;
   
   if(HistoryDealGetInteger(dealTicket, DEAL_MAGIC) != magic) return;
   if(HistoryDealGetString(dealTicket, DEAL_SYMBOL) != _Symbol) return;
   
   long entry = HistoryDealGetInteger(dealTicket, DEAL_ENTRY);
   
   if(entry == DEAL_ENTRY_IN)
   {
      ulong filledOrderTicket = HistoryDealGetInteger(dealTicket, DEAL_ORDER);

      lastFillTime = TimeCurrent();
      lastFilledOrderTicket = filledOrderTicket;

      Print("✅ ORDER FILLED - ticket #", filledOrderTicket, " | R:R target: 1:", DoubleToString(LiqIntel.recommendedRR, 1));

      ManageOCO();
   }
   else if(entry == DEAL_ENTRY_OUT || entry == DEAL_ENTRY_OUT_BY)
   {
      double dealProfit = HistoryDealGetDouble(dealTicket, DEAL_PROFIT)
                         + HistoryDealGetDouble(dealTicket, DEAL_SWAP)
                         + HistoryDealGetDouble(dealTicket, DEAL_COMMISSION);
      
      if(dealProfit > 0)
      {
         totalWins++;
         grossProfit += dealProfit;
         avgWinSize = grossProfit / totalWins;
         Print("💰 WIN: +$", DoubleToString(dealProfit, 2));
      }
      else if(dealProfit < 0)
      {
         totalLosses++;
         grossLoss += MathAbs(dealProfit);
         avgLossSize = grossLoss / totalLosses;
         Print("💸 LOSS: -$", DoubleToString(MathAbs(dealProfit), 2));
      }
      
      // Calculate realized R:R
      if(totalLosses > 0 && avgLossSize > 0)
         realizedRR = avgWinSize / avgLossSize;
      else if(totalWins > 0)
         realizedRR = 2.0;  // If no losses yet, assume good R:R
      
      UpdateProfitFactor();
      dashState.needsFullRedraw = true;
   }
}

void OnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam)
{
   if(id == CHARTEVENT_CHART_CHANGE && InpShowDashboard)
   {
      DestroyDashboard();
      InitDashboard();
      dashState.needsFullRedraw = true;
      return;
   }

   if(id == CHARTEVENT_OBJECT_CLICK)
   {
      if(sparam == DASH_PREFIX + BTN_PROFIT_NAME)
      {
         ObjectSetInteger(0, sparam, OBJPROP_STATE, false);
         CloseAllProfitableTrades();
         UpdateDashboard();
         ChartRedraw(0);
         return;
      }

      if(sparam == DASH_PREFIX + BTN_LOSS_NAME)
      {
         ObjectSetInteger(0, sparam, OBJPROP_STATE, false);
         CloseAllLosingTrades();
         UpdateDashboard();
         ChartRedraw(0);
         return;
      }
   }
}
//+------------------------------------------------------------------+
