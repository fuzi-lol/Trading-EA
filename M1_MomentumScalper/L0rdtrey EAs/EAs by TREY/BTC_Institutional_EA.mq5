//+------------------------------------------------------------------+
//|                                   BTC INSTITUTIONAL EA v1.0       |
//|   Adaptive Multi-Regime, Multi-Timeframe Smart Money Framework   |
//|   Built for BTCUSD - Expectancy & Robustness over Trade Count    |
//+------------------------------------------------------------------+
#property copyright   "BTC Institutional EA v1.0"
#property version     "1.00"
#property description "Institutional-grade adaptive multi-strategy EA for BTCUSD. Trades only on coherent, weighted, multi-timeframe institutional confluence."
#property strict

#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>
#include <Trade\AccountInfo.mqh>
#include <Trade\OrderInfo.mqh>

#define D  "BIE_"      // Dashboard object prefix
#define OV "BIE_OV_"   // Chart overlay object prefix

//=====================================================================
//  ENUMERATIONS
//=====================================================================

enum ENUM_MKT_REGIME
{
   REGIME_STRONG_BULL,
   REGIME_STRONG_BEAR,
   REGIME_WEAK_TREND,
   REGIME_ACCUMULATION,
   REGIME_DISTRIBUTION,
   REGIME_RANGE,
   REGIME_VOL_EXPANSION,
   REGIME_VOL_COMPRESSION,
   REGIME_LIQUIDITY_HUNT,
   REGIME_SESSION_TRANSITION,
   REGIME_TREND_EXHAUSTION,
   REGIME_POTENTIAL_REVERSAL,
   REGIME_NEWS_INSTABILITY
};

enum ENUM_STRATEGY_TYPE
{
   STRAT_NONE,
   STRAT_TREND_CONTINUATION,
   STRAT_LIQUIDITY_SWEEP_REVERSAL,
   STRAT_RANGE_MEAN_REVERSION,
   STRAT_VOLATILITY_BREAKOUT,
   STRAT_MOMENTUM_SCALP,
   STRAT_PULLBACK_CONTINUATION,
   STRAT_SESSION_EXPANSION,
   STRAT_OB_REENTRY
};

enum ENUM_TRADE_DIR
{
   DIR_NONE,
   DIR_LONG,
   DIR_SHORT
};

enum ENUM_ENTRY_STYLE
{
   ENTRY_CONSERVATIVE,
   ENTRY_STANDARD,
   ENTRY_AGGRESSIVE
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

enum ENUM_SESSION_ID
{
   SESSION_ASIAN,
   SESSION_LONDON_OPEN,
   SESSION_LONDON_MID,
   SESSION_NY_OPEN,
   SESSION_NY_PM,
   SESSION_DEAD_ZONE
};

enum ENUM_TF_SLOT
{
   TF_MN1, TF_W1, TF_D1, TF_H4, TF_H1, TF_M15, TF_M5, TF_COUNT
};

//=====================================================================
//  CORE STRUCTS
//=====================================================================

struct RegimeState
{
   ENUM_MKT_REGIME regime;
   double          confidence;     // 0-100
   double          stability;      // how long the regime has persisted, 0-100
   datetime        sinceTime;
   ENUM_MKT_REGIME previousRegime;
};

struct TFBias
{
   int    direction;     // -1, 0, +1
   double strength;      // 0-100, how convicted this TF's bias is
};

struct MTFNarrative
{
   TFBias monthly;
   TFBias weekly;
   TFBias daily;
   TFBias h4;
   TFBias h1;
   TFBias m15;
   double alignment;        // 0-100 composite agreement score across all TFs
   int    dominantDirection; // -1,0,+1 - the higher-timeframe-weighted consensus direction
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

struct StructureEvent
{
   datetime time;
   double   price;
   bool     isHigh;
   bool     isBOS;
   bool     isCHoCH;
   bool     isMSS;
   int      strength;      // 1-5
   bool     isMajor;
   bool     isInternal;
   bool     isProtected;
   bool     swept;
};

struct OrderBlockEx
{
   datetime time;
   double   high;
   double   low;
   bool     isBullish;
   bool     mitigated;      // fully mitigated (invalidated)
   bool     partiallyMitigated;
   int      touches;
   double   qualityScore;   // 0-100 composite
   bool     isBreaker;       // this OB failed and flipped polarity
   bool     isFresh;
};

struct FVGEx
{
   datetime startTime;
   datetime endTime;
   double   topPrice;
   double   bottomPrice;
   bool     isBullish;
   bool     filled;
   bool     isInverse;       // filled through -> now acts as opposite-polarity zone
   bool     isBalancedRange; // overlaps with an opposite-polarity FVG
};

struct LiquidityPool
{
   double   price;
   string   label;
   int      priority;        // 1 = highest (external) ... 8 = lowest
   bool     buySide;
   bool     swept;
   datetime time;
};

struct PremiumDiscountZone
{
   double rangeHigh;
   double rangeLow;
   double equilibrium;
   double premiumStart;    // 61.8%
   double discountEnd;     // 38.2%
   double oteLongStart;    // 61.8% retracement of up-leg (for longs on pullback)
   double oteLongEnd;      // 79%
   double oteShortStart;   // 61.8% retracement of down-leg (for shorts on pullback)
   double oteShortEnd;     // 79%
};

struct StrategySignal
{
   ENUM_STRATEGY_TYPE source;
   ENUM_TRADE_DIR     direction;
   double             rawConfidence;   // 0-100, strategy's own conviction
   double             suggestedSL;
   double             suggestedTP;
   string             reason;
   bool               valid;
};

struct DecisionWeights
{
   double regime;
   double htfBias;
   double liquidity;
   double structure;
   double orderBlock;
   double fvg;
   double momentum;
   double session;
   double volatility;
   double riskReward;
};

struct TradeConfidence
{
   double regimeScore;
   double htfBiasScore;
   double liquidityScore;
   double structureScore;
   double orderBlockScore;
   double fvgScore;
   double momentumScore;
   double sessionScore;
   double volatilityScore;
   double riskRewardScore;
   double totalScore;       // 0-100 weighted composite
   bool   approved;
   string rejectReason;
};

struct RiskState
{
   double   dailyRiskUsedPct;
   double   weeklyRiskUsedPct;
   double   currentDrawdownPct;
   double   maxDrawdownSeenPct;
   bool     dailyLossLimitHit;
   bool     weeklyLossLimitHit;
   bool     dailyProfitLockHit;
   bool     maxDrawdownBreached;
   bool     emergencyShutdown;
   double   peakEquity;
   double   weekStartEquity;
   double   dayStartEquity;
   int      consecutiveLosses;
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
   int      consecLosses;
   double   winRate;
   double   profitFactor;
   double   expectancyR;
   bool     enabled;
   double   influenceMultiplier;
};

struct MasterDecision
{
   bool               tradeApproved;
   ENUM_TRADE_DIR     direction;
   double             lotSize;
   double             slPrice;
   double             tpPrice;
   ENUM_STRATEGY_TYPE strategySource;
   ENUM_ENTRY_STYLE   entryStyle;
   double             riskAmountUsed;
   double             confidence;
   string             narrative;
};

//=====================================================================
//  INPUT PARAMETERS
//=====================================================================

input group "======  IDENTITY  ======"
input ulong    InpMagicNumber          = 990100;
input string   InpBotName              = "BTC INSTITUTIONAL EA";

input group "======  RISK GOVERNANCE  ======"
input double   InpRiskPercentPerTrade  = 0.5;      // Base risk per trade (% of equity)
input double   InpMaxRiskPercentTrade  = 1.0;      // Absolute ceiling per trade
input double   InpMaxDailyLossPct      = 4.0;
input double   InpMaxWeeklyLossPct     = 10.0;
input double   InpMaxDrawdownPct       = 15.0;
input double   InpDailyProfitLockPct   = 6.0;       // Stop opening new trades once daily profit exceeds this (protect gains)
input int      InpMaxDailyTrades       = 12;        // Moderate cap - quality over quantity, but not starved
input int      InpMaxConcurrentTrades  = 1;
input int      InpMaxConsecutiveLosses = 4;         // Pause strategy after this many losses in a row
input int      InpCooldownAfterCloseSec= 45;

input group "======  EXECUTION QUALITY  ======"
input double   InpMaxSpreadPoints      = 5000;      // BTCUSD spreads run large - tune to your broker
input int      InpMaxSlippagePoints    = 50;

input group "======  WEIGHTED DECISION ENGINE  ======"
input double   InpWeightRegime         = 20.0;
input double   InpWeightHTFBias        = 15.0;
input double   InpWeightLiquidity      = 15.0;
input double   InpWeightStructure      = 15.0;
input double   InpWeightOrderBlock     = 10.0;
input double   InpWeightFVG            = 5.0;
input double   InpWeightMomentum       = 10.0;
input double   InpWeightSession        = 5.0;
input double   InpWeightVolatility     = 5.0;
input double   InpWeightRiskReward     = 10.0;      // Weights should sum to ~100 (auto-normalized if not)
input double   InpMinConfidenceScore   = 58.0;      // Trade only if composite confidence exceeds this - the core "how strict" dial
input double   InpMinRiskReward        = 1.3;       // Minimum acceptable reward:risk ratio

input group "======  MARKET REGIME ENGINE  ======"
input int      InpATRPeriod            = 14;
input int      InpATRLookback          = 100;
input int      InpEMAFastPeriod        = 8;
input int      InpEMASlowPeriod        = 34;
input double   InpMinRegimeConfidence  = 40.0;      // Loosened from the old rigid version, still meaningful
input double   InpUnsafeOverrideScore  = 75.0;      // Only truly extreme conditions force a full stand-down

input group "======  MULTI-TIMEFRAME NARRATIVE  ======"
input bool     InpRequireHTFAlignment  = true;      // Lower TF signals must not contradict higher TF narrative
input double   InpMinHTFAlignment      = 35.0;      // Minimum MTF alignment score to allow a trade

input group "======  MARKET STRUCTURE / SMC  ======"
input int      InpStructureBars        = 60;        // Base structure lookback (session-anchored window may extend this)
input int      InpSwingLeftRight       = 3;          // Bars each side required to confirm a swing point

input group "======  LIQUIDITY ENGINE  ======"
input double   InpEqualLevelTolerance  = 0.10;      // % tolerance for equal highs/lows clustering
input int      InpLiquidityLookback    = 40;
input double   InpRoundNumberStep      = 500.0;

input group "======  ORDER BLOCK / FVG ENGINE  ======"
input int      InpMaxOrderBlocks       = 4;
input int      InpMaxFVGs              = 6;
input double   InpMinOBQualityScore    = 45.0;      // Ignore weak institutional zones below this score

input group "======  ADAPTIVE ENTRY / SL / TP  ======"
input double   InpSLAtrMultiplier      = 1.8;
input double   InpMaxSLAtrMultiplier   = 3.0;       // Hard ceiling regardless of structure distance
input double   InpTrailStartAtr        = 1.0;       // Start trailing once profit exceeds this many ATR
input double   InpBreakEvenAtr         = 0.6;
input double   InpPartialCloseAtr      = 1.4;
input double   InpPartialClosePct      = 40.0;       // % of position closed at the partial-profit trigger
input int      InpMaxHoldingBars       = 96;         // Time-based exit (M5 bars, ~8h) - avoid stale trades

input group "======  STRATEGY HEALTH  ======"
input int      InpHealthMinTrades      = 8;
input int      InpHealthDegradeConsecLoss = 5;
input double   InpHealthMinExpectancyR = -0.15;

input group "======  SESSION CONFIGURATION  ======"
input int      InpBrokerGMTOffset      = 2;

input group "======  BTCUSD OPTIMIZATION  ======"
input bool     InpWeekendCaution       = true;       // Thin weekend liquidity - raise the quality bar slightly on Sat/Sun
input double   InpWeekendConfPenalty   = 8.0;        // Confidence points subtracted during weekend hours

input group "======  DASHBOARD  ======"
input bool     InpShowDash             = true;
input int      InpDashX                = 10;
input int      InpDashY                = 10;

input group "======  CHART THEME  ======"
input bool     InpEnableBlackTheme     = true;
input bool     InpHideGrid             = true;

input group "======  CHART OVERLAYS  ======"
input bool     InpDrawStructure        = true;
input bool     InpDrawOrderBlocks      = true;
input bool     InpDrawFVG              = true;
input bool     InpDrawLiquidity        = true;
input bool     InpDrawPremiumDiscount  = true;
input bool     InpShowMinorStructure   = false;
input int      InpMaxLiquidityLines    = 6;
input int      InpLabelFontSize        = 8;

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
#define C_MAGENTA   C'255,80,220'

//=====================================================================
//  GLOBAL OBJECTS
//=====================================================================
CTrade        g_trade;
CPositionInfo g_pos;
CAccountInfo  g_account;

//=====================================================================
//  INDICATOR HANDLES (per timeframe slot)
//=====================================================================
int g_emaFast[TF_COUNT];
int g_emaSlow[TF_COUNT];
int g_atrHandle[TF_COUNT];
int g_rsiHandle;     // M5 RSI
int g_adxHandle;     // M5 ADX
int g_macdHandle;    // M5 MACD

ENUM_TIMEFRAMES g_tfMap[TF_COUNT] = { PERIOD_MN1, PERIOD_W1, PERIOD_D1, PERIOD_H4, PERIOD_H1, PERIOD_M15, PERIOD_M5 };

//=====================================================================
//  STATE CONTAINERS
//=====================================================================
RegimeState          g_regime;
MTFNarrative          g_mtf;
VolatilityState       g_vol;
RiskState             g_risk;
MasterDecision        g_lastDecision;
TradeConfidence       g_confidence;
PremiumDiscountZone   g_pdZone;
StrategyHealth        g_health[8];
ENUM_SESSION_ID       g_session = SESSION_DEAD_ZONE;

// News/shock proxy: 0=normal, 1=caution, 2=shock
int   g_newsShockLevel = 0;

//=====================================================================
//  ANALYSIS ARRAYS
//=====================================================================
StructureEvent  g_structure[];
int             g_structCount = 0;
OrderBlockEx    g_orderBlocks[];
int             g_obCount = 0;
FVGEx           g_fvgArray[];
int             g_fvgCount = 0;
LiquidityPool   g_liquidityPools[];
int             g_liqPoolCount = 0;

//=====================================================================
//  SESSION / DAY / TIME TRACKING
//=====================================================================
datetime g_dayStart        = 0;
datetime g_weekStart       = 0;
int      g_tradesToday     = 0;
datetime g_lastCloseTime   = 0;
bool     g_inCooldown      = false;
datetime g_lastFullUpdate  = 0;
datetime g_lastBarTime     = 0;
datetime g_currentSessionStartTime = 0;
int      g_sessionAnchorBars = 100;
int      g_analysisLookback  = 60;
double   g_sessionHigh = 0, g_sessionLow = 0;
datetime g_sessionHighTime = 0, g_sessionLowTime = 0;
datetime g_eqHighTime = 0, g_eqLowTime = 0;
double   g_buySideLiqCount = 0, g_sellSideLiqCount = 0;
int      g_barsInCurrentTrade = 0;
int      g_sessionTransitionBars = 0;   // flags the first few bars after a session change
bool     g_partialTaken = false;

//=====================================================================
//  DASHBOARD / STATUS
//=====================================================================
string  g_statusText  = "INITIALIZING";
color   g_statusColor = C_ORANGE;
string  g_lastAction  = "Starting up...";
const int DW = 460;
const int DH = 400;

//=====================================================================
//  PERFORMANCE ANALYTICS
//=====================================================================
double g_sessionProfit = 0.0;
int    g_sessionWins   = 0;
int    g_sessionLosses = 0;

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

bool IsWeekend(datetime ts)
{
   MqlDateTime d; TimeToStruct(ts, d);
   return (d.day_of_week == 0 || d.day_of_week == 6);
}

ENUM_SESSION_ID ClassifySession(datetime ts)
{
   MqlDateTime d;
   TimeToStruct(ts, d);
   int hour = (d.hour - InpBrokerGMTOffset + 24) % 24;

   if(hour >= 0  && hour < 7)   return SESSION_ASIAN;
   if(hour >= 7  && hour < 10)  return SESSION_LONDON_OPEN;
   if(hour >= 10 && hour < 12)  return SESSION_LONDON_MID;
   if(hour >= 12 && hour < 15)  return SESSION_NY_OPEN;
   if(hour >= 15 && hour < 21)  return SESSION_NY_PM;
   return SESSION_DEAD_ZONE;
}

//=====================================================================
//  SESSION-ANCHORED ANALYSIS WINDOW
//  Every structural/liquidity module anchors to the real session start
//  (or the previous session, if we're within 30 minutes of a boundary)
//  rather than an arbitrary fixed bar count - this is what keeps the
//  institutional analysis grounded in real market context.
//=====================================================================
datetime ComputeSessionStartTime(datetime ts)
{
   MqlDateTime d;
   TimeToStruct(ts, d);
   int hourUTC = (d.hour - InpBrokerGMTOffset + 24) % 24;

   int sessionStartHourUTC;
   if(hourUTC >= 0  && hourUTC < 7)  sessionStartHourUTC = 0;
   else if(hourUTC >= 7  && hourUTC < 10) sessionStartHourUTC = 7;
   else if(hourUTC >= 10 && hourUTC < 12) sessionStartHourUTC = 10;
   else if(hourUTC >= 12 && hourUTC < 15) sessionStartHourUTC = 12;
   else if(hourUTC >= 15 && hourUTC < 21) sessionStartHourUTC = 15;
   else sessionStartHourUTC = 21;

   int brokerStartHour = (sessionStartHourUTC + InpBrokerGMTOffset + 24) % 24;

   datetime today = DayStart(ts);
   datetime sessionStart = today + brokerStartHour * 3600;
   if(sessionStart > ts) sessionStart -= 86400;

   int minutesIntoSession = (int)((ts - sessionStart) / 60);
   if(minutesIntoSession < 30)
      sessionStart -= 6 * 3600;

   return sessionStart;
}

void UpdateSessionAnchorWindow()
{
   datetime now = TimeCurrent();
   g_currentSessionStartTime = ComputeSessionStartTime(now);

   int barShift = iBarShift(_Symbol, PERIOD_M5, g_currentSessionStartTime, false);
   if(barShift <= 0) barShift = 100;

   g_sessionAnchorBars = (int)MathMin(400, MathMax(40, barShift));
   g_analysisLookback  = (int)MathMax(InpStructureBars, g_sessionAnchorBars);
}

void UpdateSessionIntelligence()
{
   ENUM_SESSION_ID newSession = ClassifySession(TimeCurrent());
   if(newSession != g_session)
   {
      g_sessionTransitionBars = 3;
      g_session = newSession;
   }
   else if(g_sessionTransitionBars > 0)
   {
      g_sessionTransitionBars--;
   }

   UpdateSessionAnchorWindow();

   double sessionHigh = iHigh(_Symbol, PERIOD_M5, 0);
   double sessionLow  = iLow(_Symbol, PERIOD_M5, 0);
   datetime sessionHighTime = iTime(_Symbol, PERIOD_M5, 0);
   datetime sessionLowTime  = iTime(_Symbol, PERIOD_M5, 0);

   for(int i = 1; i < g_sessionAnchorBars; i++)
   {
      double h = iHigh(_Symbol, PERIOD_M5, i);
      double l = iLow(_Symbol, PERIOD_M5, i);
      if(h > sessionHigh) { sessionHigh = h; sessionHighTime = iTime(_Symbol, PERIOD_M5, i); }
      if(l < sessionLow)  { sessionLow  = l; sessionLowTime  = iTime(_Symbol, PERIOD_M5, i); }
   }

   g_sessionHigh = sessionHigh;
   g_sessionLow  = sessionLow;
   g_sessionHighTime = sessionHighTime;
   g_sessionLowTime  = sessionLowTime;
}

string SessionToString(ENUM_SESSION_ID s)
{
   switch(s)
   {
      case SESSION_ASIAN:       return "ASIAN";
      case SESSION_LONDON_OPEN: return "LONDON OPEN";
      case SESSION_LONDON_MID:  return "LONDON MID";
      case SESSION_NY_OPEN:     return "NY OPEN";
      case SESSION_NY_PM:       return "NY PM";
      default:                  return "DEAD ZONE";
   }
}

//=====================================================================
//  MULTI-TIMEFRAME NARRATIVE ENGINE
//  Builds a top-down bias hierarchy: Monthly -> Weekly -> Daily -> H4
//  -> H1 -> M15. Each TF's bias is derived from EMA fast/slow separation
//  and its trajectory (widening = conviction, narrowing = weakening).
//  Higher timeframes are weighted more heavily in the composite.
//=====================================================================
TFBias ComputeTFBias(ENUM_TF_SLOT slot)
{
   TFBias b;
   b.direction = 0;
   b.strength  = 0;

   double fastNow[2], slowNow[2];
   if(CopyBuffer(g_emaFast[slot], 0, 0, 2, fastNow) < 2) return b;
   if(CopyBuffer(g_emaSlow[slot], 0, 0, 2, slowNow) < 2) return b;

   double spreadNow  = fastNow[0] - slowNow[0];
   double spreadPrev = fastNow[1] - slowNow[1];
   bool   widening    = MathAbs(spreadNow) > MathAbs(spreadPrev);

   b.direction = (fastNow[0] > slowNow[0]) ? 1 : (fastNow[0] < slowNow[0] ? -1 : 0);

   // Strength: base on separation relative to price, boosted if widening
   double refPrice = fastNow[0] != 0 ? fastNow[0] : 1.0;
   double sepPct = MathAbs(spreadNow) / refPrice * 100.0;
   b.strength = MathMin(100.0, sepPct * 800.0 + (widening ? 15.0 : 0.0));

   if(!widening && MathAbs(spreadNow) < MathAbs(spreadPrev) * 0.5)
      b.direction = 0;   // momentum has effectively died - treat as neutral

   return b;
}

void UpdateMTFNarrative()
{
   g_mtf.monthly = ComputeTFBias(TF_MN1);
   g_mtf.weekly  = ComputeTFBias(TF_W1);
   g_mtf.daily   = ComputeTFBias(TF_D1);
   g_mtf.h4      = ComputeTFBias(TF_H4);
   g_mtf.h1      = ComputeTFBias(TF_H1);
   g_mtf.m15     = ComputeTFBias(TF_M15);

   // Weighted composite: higher timeframes carry more institutional weight
   double weights[6]    = {0.30, 0.22, 0.18, 0.14, 0.10, 0.06};   // monthly..m15
   int    directions[6] = { g_mtf.monthly.direction, g_mtf.weekly.direction, g_mtf.daily.direction,
                             g_mtf.h4.direction, g_mtf.h1.direction, g_mtf.m15.direction };
   double strengths[6]  = { g_mtf.monthly.strength, g_mtf.weekly.strength, g_mtf.daily.strength,
                             g_mtf.h4.strength, g_mtf.h1.strength, g_mtf.m15.strength };

   double weightedSum = 0;
   double weightedAbs = 0;
   for(int i = 0; i < 6; i++)
   {
      weightedSum += directions[i] * weights[i] * (strengths[i] / 100.0);
      weightedAbs += weights[i] * (strengths[i] / 100.0);
   }

   g_mtf.dominantDirection = (weightedSum > 0.05) ? 1 : (weightedSum < -0.05 ? -1 : 0);

   // Alignment: what fraction of the (weighted) conviction agrees with the dominant direction
   double agreeWeight = 0, totalWeight = 0;
   for(int i = 0; i < 6; i++)
   {
      if(directions[i] == 0) continue;
      double w = weights[i] * (strengths[i] / 100.0);
      totalWeight += w;
      if(directions[i] == g_mtf.dominantDirection) agreeWeight += w;
   }
   g_mtf.alignment = (totalWeight > 0) ? MathMin(100.0, 100.0 * agreeWeight / totalWeight) : 0.0;
}

//=====================================================================
//  VOLATILITY INTELLIGENCE ENGINE
//=====================================================================
void UpdateVolatilityIntelligence()
{
   double atrBuf[];
   ArrayResize(atrBuf, InpATRLookback);
   ArraySetAsSeries(atrBuf, true);

   int got = CopyBuffer(g_atrHandle[TF_M5], 0, 0, InpATRLookback, atrBuf);
   if(got < InpATRLookback / 2 || got <= 0)
   {
      g_vol.state = VOL_NORMAL; g_vol.dynamic = VOLDYN_STABLE;
      g_vol.atrCurrent = 0.0001; g_vol.atrAvg = 0.0001; g_vol.atrRatio = 1.0;
      return;
   }

   double current = atrBuf[0];
   double sum = 0;
   for(int i = 0; i < got; i++) sum += atrBuf[i];
   double avg = (got > 0) ? sum / got : current;
   if(avg <= 0) avg = 0.0001;

   g_vol.atrCurrent = current;
   g_vol.atrAvg     = avg;
   g_vol.atrRatio   = current / avg;

   int below = 0;
   for(int i = 0; i < got; i++) if(atrBuf[i] <= current) below++;
   g_vol.percentile = 100.0 * below / got;

   if(g_vol.percentile < 25)      g_vol.state = VOL_LOW;
   else if(g_vol.percentile < 65) g_vol.state = VOL_NORMAL;
   else if(g_vol.percentile < 90) g_vol.state = VOL_HIGH;
   else                            g_vol.state = VOL_EXTREME;

   double atrPrev3 = (got > 3) ? atrBuf[3] : avg;
   double roc = (atrPrev3 > 0) ? (current - atrPrev3) / atrPrev3 : 0.0;

   if(g_vol.atrRatio >= 3.2)      g_vol.dynamic = VOLDYN_SPIKE;
   else if(roc > 0.15)             g_vol.dynamic = VOLDYN_EXPANDING;
   else if(roc < -0.15)            g_vol.dynamic = VOLDYN_COMPRESSING;
   else                             g_vol.dynamic = VOLDYN_STABLE;
}

//=====================================================================
//  NEWS / VOLATILITY SHOCK PROXY
//=====================================================================
double g_spreadHistory[20];
int    g_spreadHistCount = 0;

void UpdateNewsShockProxy()
{
   double spreadNow = (double)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);

   if(g_spreadHistCount < 20) { g_spreadHistory[g_spreadHistCount] = spreadNow; g_spreadHistCount++; }
   else { for(int i=0;i<19;i++) g_spreadHistory[i]=g_spreadHistory[i+1]; g_spreadHistory[19]=spreadNow; }

   double spreadSum = 0;
   for(int i = 0; i < g_spreadHistCount; i++) spreadSum += g_spreadHistory[i];
   double spreadAvg = (g_spreadHistCount > 0) ? spreadSum / g_spreadHistCount : spreadNow;
   if(spreadAvg <= 0) spreadAvg = 1;
   double spreadRatio = spreadNow / spreadAvg;

   double barRange = iHigh(_Symbol, PERIOD_M5, 0) - iLow(_Symbol, PERIOD_M5, 0);
   double atrRatioForBar = (g_vol.atrAvg > 0) ? barRange / g_vol.atrAvg : 1.0;

   bool atrShock    = g_vol.atrRatio >= 3.2;
   bool spreadShock = spreadRatio    >= 3.0;
   bool barShock    = atrRatioForBar >= 3.2;

   int shockSignals = (atrShock?1:0) + (spreadShock?1:0) + (barShock?1:0);
   g_newsShockLevel = (shockSignals >= 2) ? 2 : (shockSignals == 1 ? 1 : 0);
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

//=====================================================================
//  MARKET REGIME DETECTION ENGINE (13-state classifier)
//  This is the highest-priority module: every downstream engine reads
//  from g_regime. Each candidate regime gets a 0-100 score from the
//  current MTF/volatility/structure context; the highest scorer wins,
//  with an override for genuinely unsafe conditions only.
//=====================================================================
double g_regimeStreakBars = 0;
ENUM_MKT_REGIME g_regimePersistTrack = REGIME_RANGE;

double RS_StrongBull()
{
   double s = 0;
   if(g_mtf.dominantDirection > 0) s += g_mtf.alignment * 0.5;
   if(g_mtf.h1.direction > 0 && g_mtf.h4.direction > 0) s += 25;
   if(g_vol.state == VOL_NORMAL || g_vol.state == VOL_HIGH) s += 15;
   if(g_vol.dynamic == VOLDYN_EXPANDING) s += 10;
   return MathMin(100.0, s);
}
double RS_StrongBear()
{
   double s = 0;
   if(g_mtf.dominantDirection < 0) s += g_mtf.alignment * 0.5;
   if(g_mtf.h1.direction < 0 && g_mtf.h4.direction < 0) s += 25;
   if(g_vol.state == VOL_NORMAL || g_vol.state == VOL_HIGH) s += 15;
   if(g_vol.dynamic == VOLDYN_EXPANDING) s += 10;
   return MathMin(100.0, s);
}
double RS_WeakTrend()
{
   double s = 0;
   if(g_mtf.dominantDirection != 0 && g_mtf.alignment < 55) s += 45;
   if(g_vol.state == VOL_LOW || g_vol.state == VOL_NORMAL) s += 20;
   return MathMin(100.0, s);
}
double RS_Accumulation()
{
   double s = 0;
   double hh = StructureHighestHigh(InpStructureBars);
   double ll = StructureLowestLow(InpStructureBars);
   double price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double range = hh - ll;
   if(range <= 0) return 0;
   double posInRange = (price - ll) / range;
   if(posInRange < 0.3 && g_mtf.h1.direction <= 0 && (g_vol.dynamic == VOLDYN_COMPRESSING || g_vol.dynamic == VOLDYN_STABLE))
      s += 55;
   if(g_mtf.daily.direction < 0) s += 15;  // prior downtrend context makes accumulation more credible
   return MathMin(100.0, s);
}
double RS_Distribution()
{
   double s = 0;
   double hh = StructureHighestHigh(InpStructureBars);
   double ll = StructureLowestLow(InpStructureBars);
   double price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double range = hh - ll;
   if(range <= 0) return 0;
   double posInRange = (price - ll) / range;
   if(posInRange > 0.7 && g_mtf.h1.direction >= 0 && (g_vol.dynamic == VOLDYN_COMPRESSING || g_vol.dynamic == VOLDYN_STABLE))
      s += 55;
   if(g_mtf.daily.direction > 0) s += 15;
   return MathMin(100.0, s);
}
double RS_Range()
{
   double s = 0;
   if(g_mtf.alignment < 40) s += 40;
   if(g_vol.state == VOL_LOW || g_vol.state == VOL_NORMAL) s += 25;
   if(g_vol.dynamic == VOLDYN_STABLE) s += 20;
   return MathMin(100.0, s);
}
double RS_VolExpansion()
{
   double s = 0;
   if(g_vol.dynamic == VOLDYN_EXPANDING) s += 45;
   if(g_vol.state == VOL_HIGH) s += 25;
   if(g_vol.atrRatio > 1.3) s += 20;
   return MathMin(100.0, s);
}
double RS_VolCompression()
{
   double s = 0;
   if(g_vol.state == VOL_LOW) s += 40;
   if(g_vol.dynamic == VOLDYN_COMPRESSING) s += 35;
   if(g_vol.percentile < 15) s += 20;
   return MathMin(100.0, s);
}
double RS_LiquidityHunt()
{
   // High score when price is near a strong unswept liquidity pool (populated after liquidity engine runs)
   double s = 0;
   if(g_liqPoolCount > 0)
   {
      double price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      double atrRef = g_vol.atrCurrent > 0 ? g_vol.atrCurrent : 0.0001;
      for(int i = 0; i < g_liqPoolCount; i++)
      {
         if(g_liquidityPools[i].swept) continue;
         if(g_liquidityPools[i].priority > 4) continue;
         double distATR = MathAbs(price - g_liquidityPools[i].price) / atrRef;
         if(distATR < 1.0) s = MathMax(s, 70.0 - distATR*20.0);
      }
   }
   return MathMin(100.0, s);
}
double RS_TrendExhaustion(double rsiVal)
{
   double s = 0;
   if(rsiVal > 72 || rsiVal < 28) s += 35;
   if(g_vol.dynamic == VOLDYN_COMPRESSING && g_vol.atrRatio < 0.85) s += 25;
   if(g_mtf.h1.direction != 0 && g_mtf.m15.direction != 0 && g_mtf.h1.direction != g_mtf.m15.direction) s += 20;
   return MathMin(100.0, s);
}
double RS_PotentialReversal(double rsiVal)
{
   double s = 0;
   if(rsiVal > 68 || rsiVal < 32) s += 25;
   if(g_mtf.alignment < 40) s += 25;
   for(int i = 0; i < g_structCount; i++)
      if(g_structure[i].isCHoCH && i >= g_structCount-3) s += 25;
   return MathMin(100.0, s);
}
double RS_NewsInstability()
{
   double s = 0;
   if(g_newsShockLevel == 2) s += 60;
   else if(g_newsShockLevel == 1) s += 25;
   if(g_vol.state == VOL_EXTREME) s += 25;
   double spread = (double)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   if(spread > InpMaxSpreadPoints) s += 25;
   return MathMin(100.0, s);
}

void UpdateRegimeClassification()
{
   double rsiM5[1];
   if(CopyBuffer(g_rsiHandle, 0, 0, 1, rsiM5) <= 0) rsiM5[0] = 50;

   ENUM_MKT_REGIME candidates[13] = {
      REGIME_STRONG_BULL, REGIME_STRONG_BEAR, REGIME_WEAK_TREND, REGIME_ACCUMULATION,
      REGIME_DISTRIBUTION, REGIME_RANGE, REGIME_VOL_EXPANSION, REGIME_VOL_COMPRESSION,
      REGIME_LIQUIDITY_HUNT, REGIME_SESSION_TRANSITION, REGIME_TREND_EXHAUSTION,
      REGIME_POTENTIAL_REVERSAL, REGIME_NEWS_INSTABILITY
   };

   double scores[13];
   scores[0]  = RS_StrongBull();
   scores[1]  = RS_StrongBear();
   scores[2]  = RS_WeakTrend();
   scores[3]  = RS_Accumulation();
   scores[4]  = RS_Distribution();
   scores[5]  = RS_Range();
   scores[6]  = RS_VolExpansion();
   scores[7]  = RS_VolCompression();
   scores[8]  = RS_LiquidityHunt();
   scores[9]  = (g_sessionTransitionBars > 0) ? 65.0 : 0.0;
   scores[10] = RS_TrendExhaustion(rsiM5[0]);
   scores[11] = RS_PotentialReversal(rsiM5[0]);
   scores[12] = RS_NewsInstability();

   int bestIdx = 0;
   double bestScore = scores[0];
   for(int i = 1; i < 13; i++)
      if(scores[i] > bestScore) { bestScore = scores[i]; bestIdx = i; }

   // Only genuinely extreme conditions force a full stand-down
   if(scores[12] >= InpUnsafeOverrideScore) { bestIdx = 12; bestScore = scores[12]; }

   ENUM_MKT_REGIME newRegime = candidates[bestIdx];

   if(newRegime == g_regimePersistTrack) g_regimeStreakBars++;
   else
   {
      g_regimeStreakBars = 0;
      g_regimePersistTrack = newRegime;
      g_regime.sinceTime = TimeCurrent();
      g_regime.previousRegime = g_regime.regime;
   }

   g_regime.regime     = newRegime;
   g_regime.confidence = bestScore;
   g_regime.stability  = MathMin(100.0, g_regimeStreakBars * 8.0);
}

string RegimeToString(ENUM_MKT_REGIME r)
{
   switch(r)
   {
      case REGIME_STRONG_BULL:        return "STRONG BULL";
      case REGIME_STRONG_BEAR:        return "STRONG BEAR";
      case REGIME_WEAK_TREND:         return "WEAK TREND";
      case REGIME_ACCUMULATION:       return "ACCUMULATION";
      case REGIME_DISTRIBUTION:       return "DISTRIBUTION";
      case REGIME_RANGE:              return "RANGE";
      case REGIME_VOL_EXPANSION:      return "VOL EXPANSION";
      case REGIME_VOL_COMPRESSION:    return "VOL COMPRESSION";
      case REGIME_LIQUIDITY_HUNT:     return "LIQUIDITY HUNT";
      case REGIME_SESSION_TRANSITION: return "SESSION TRANSITION";
      case REGIME_TREND_EXHAUSTION:   return "TREND EXHAUSTION";
      case REGIME_POTENTIAL_REVERSAL: return "POTENTIAL REVERSAL";
      case REGIME_NEWS_INSTABILITY:   return "NEWS INSTABILITY";
      default:                         return "UNKNOWN";
   }
}

//=====================================================================
//  MARKET STRUCTURE / SMC ENGINE
//  Detects swing points, classifies them as Major/Minor and
//  Internal/External, tracks Protected Highs/Lows (unswept major
//  swings), and detects BOS / CHoCH / MSS (a CHoCH confirmed by a
//  follow-through break in the new direction).
//=====================================================================
bool IsSwingHigh(int index, int lr)
{
   double c = iHigh(_Symbol, PERIOD_M5, index);
   for(int i = 1; i <= lr; i++)
      if(iHigh(_Symbol, PERIOD_M5, index-i) >= c || iHigh(_Symbol, PERIOD_M5, index+i) >= c) return false;
   return true;
}
bool IsSwingLow(int index, int lr)
{
   double c = iLow(_Symbol, PERIOD_M5, index);
   for(int i = 1; i <= lr; i++)
      if(iLow(_Symbol, PERIOD_M5, index-i) <= c || iLow(_Symbol, PERIOD_M5, index+i) <= c) return false;
   return true;
}

void DetectMarketStructure()
{
   ArrayResize(g_structure, 0);
   g_structCount = 0;

   int lookback = MathMin(g_analysisLookback, (int)Bars(_Symbol, PERIOD_M5) - 10);
   int lr = InpSwingLeftRight;

   for(int i = lr+2; i < lookback; i++)
   {
      bool isHigh = IsSwingHigh(i, lr);
      bool isLow  = IsSwingLow(i, lr);
      if(!isHigh && !isLow) continue;

      ArrayResize(g_structure, g_structCount+1);
      g_structure[g_structCount].time  = iTime(_Symbol, PERIOD_M5, i);
      g_structure[g_structCount].price = isHigh ? iHigh(_Symbol, PERIOD_M5, i) : iLow(_Symbol, PERIOD_M5, i);
      g_structure[g_structCount].isHigh = isHigh;
      g_structure[g_structCount].isBOS = false;
      g_structure[g_structCount].isCHoCH = false;
      g_structure[g_structCount].isMSS = false;
      g_structure[g_structCount].isInternal = true;
      g_structure[g_structCount].isProtected = false;
      g_structure[g_structCount].swept = false;

      double range = iHigh(_Symbol, PERIOD_M5, i) - iLow(_Symbol, PERIOD_M5, i);
      double atrRef = g_vol.atrCurrent > 0 ? g_vol.atrCurrent : 0.0001;
      g_structure[g_structCount].strength = (int)MathMin(5, MathMax(1, range/atrRef*3));
      g_structure[g_structCount].isMajor = (g_structure[g_structCount].strength >= 4);

      g_structCount++;
   }

   // BOS / CHoCH detection
   if(g_structCount >= 3)
   {
      bool uptrend = false;
      for(int i = g_structCount-1; i >= 2; i--)
      {
         if(g_structure[i].isHigh)
         {
            for(int j = i-1; j >= 0; j--)
            {
               if(g_structure[j].isHigh)
               {
                  if(g_structure[i].price > g_structure[j].price)
                  {
                     g_structure[i].isBOS   = uptrend;
                     g_structure[i].isCHoCH = !uptrend;
                     uptrend = true;
                  }
                  break;
               }
            }
         }
         else
         {
            for(int j = i-1; j >= 0; j--)
            {
               if(!g_structure[j].isHigh)
               {
                  if(g_structure[i].price < g_structure[j].price)
                  {
                     g_structure[i].isBOS   = !uptrend;
                     g_structure[i].isCHoCH = uptrend;
                     uptrend = false;
                  }
                  break;
               }
            }
         }
      }
   }

   // Market Structure Shift: CHoCH confirmed by a same-direction BOS shortly after
   for(int i = 0; i < g_structCount; i++)
   {
      if(!g_structure[i].isCHoCH) continue;
      for(int k = i+1; k < MathMin(g_structCount, i+4); k++)
         if(g_structure[k].isBOS && g_structure[k].isHigh == g_structure[i].isHigh) { g_structure[i].isMSS = true; break; }
   }

   // Internal vs External
   double extHigh = -DBL_MAX, extLow = DBL_MAX;
   for(int i = 0; i < g_structCount; i++)
   {
      if(g_structure[i].isHigh && g_structure[i].price > extHigh) extHigh = g_structure[i].price;
      if(!g_structure[i].isHigh && g_structure[i].price < extLow) extLow = g_structure[i].price;
   }
   double extTol = (g_vol.atrCurrent > 0 ? g_vol.atrCurrent : 0.0001) * 0.25;
   for(int i = 0; i < g_structCount; i++)
   {
      if(g_structure[i].isHigh) g_structure[i].isInternal = (MathAbs(g_structure[i].price-extHigh) > extTol);
      else                       g_structure[i].isInternal = (MathAbs(g_structure[i].price-extLow)  > extTol);
   }

   // Protected vs Swept
   for(int i = 0; i < g_structCount; i++)
   {
      bool sweptFlag = false;
      int barShift = iBarShift(_Symbol, PERIOD_M5, g_structure[i].time, false);
      if(barShift > 0)
      {
         for(int b = barShift-1; b >= 0; b--)
         {
            if(g_structure[i].isHigh) { if(iHigh(_Symbol, PERIOD_M5, b) > g_structure[i].price) { sweptFlag = true; break; } }
            else                       { if(iLow(_Symbol, PERIOD_M5, b)  < g_structure[i].price) { sweptFlag = true; break; } }
         }
      }
      g_structure[i].swept = sweptFlag;
      g_structure[i].isProtected = (!sweptFlag && g_structure[i].isMajor);
   }
}

//=====================================================================
//  LIQUIDITY INTELLIGENCE ENGINE
//  Ranks every liquidity reference the framework tracks (external,
//  session, internal, equal highs/lows, previous day/week, round
//  numbers) by institutional priority and tags buy/sell-side.
//=====================================================================
struct EqualLevelState
{
   bool   highsDetected;
   bool   lowsDetected;
   double highLevel;
   double lowLevel;
   bool   sweepUp;
   bool   sweepDown;
   double sweepProbability;
   double pressureScore;
};
EqualLevelState g_eq;

void UpdateLiquidityStructure()
{
   double swingHighPrices[30]; datetime swingHighTimes[30];
   double swingLowPrices[30];  datetime swingLowTimes[30];
   int nHighs = 0, nLows = 0;

   int lb = MathMin(InpLiquidityLookback, 60);
   for(int i = 2; i < lb && nHighs < 30; i++)
      if(IsSwingHigh(i,2)) { swingHighPrices[nHighs]=iHigh(_Symbol,PERIOD_M5,i); swingHighTimes[nHighs]=iTime(_Symbol,PERIOD_M5,i); nHighs++; }
   for(int i = 2; i < lb && nLows < 30; i++)
      if(IsSwingLow(i,2)) { swingLowPrices[nLows]=iLow(_Symbol,PERIOD_M5,i); swingLowTimes[nLows]=iTime(_Symbol,PERIOD_M5,i); nLows++; }

   double price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double tolAbs = price * (InpEqualLevelTolerance/100.0);

   g_eq.highsDetected = false; g_eq.highLevel = 0;
   int bestHighCluster = 0;
   for(int i = 0; i < nHighs; i++)
   {
      int cnt=1; double sum=swingHighPrices[i];
      for(int j=0;j<nHighs;j++) if(j!=i && MathAbs(swingHighPrices[j]-swingHighPrices[i])<=tolAbs) { cnt++; sum+=swingHighPrices[j]; }
      if(cnt>=2 && cnt>bestHighCluster) { bestHighCluster=cnt; g_eq.highLevel=sum/cnt; g_eq.highsDetected=true; g_eqHighTime=swingHighTimes[i]; }
   }
   g_eq.lowsDetected = false; g_eq.lowLevel = 0;
   int bestLowCluster = 0;
   for(int i = 0; i < nLows; i++)
   {
      int cnt=1; double sum=swingLowPrices[i];
      for(int j=0;j<nLows;j++) if(j!=i && MathAbs(swingLowPrices[j]-swingLowPrices[i])<=tolAbs) { cnt++; sum+=swingLowPrices[j]; }
      if(cnt>=2 && cnt>bestLowCluster) { bestLowCluster=cnt; g_eq.lowLevel=sum/cnt; g_eq.lowsDetected=true; g_eqLowTime=swingLowTimes[i]; }
   }

   g_eq.sweepUp = false; g_eq.sweepDown = false;
   if(g_eq.highsDetected)
      for(int i=0;i<3;i++) if(iHigh(_Symbol,PERIOD_M5,i)>g_eq.highLevel && iClose(_Symbol,PERIOD_M5,i)<g_eq.highLevel) { g_eq.sweepUp=true; break; }
   if(g_eq.lowsDetected)
      for(int i=0;i<3;i++) if(iLow(_Symbol,PERIOD_M5,i)<g_eq.lowLevel && iClose(_Symbol,PERIOD_M5,i)>g_eq.lowLevel) { g_eq.sweepDown=true; break; }

   double distHigh = g_eq.highsDetected ? MathAbs(price-g_eq.highLevel) : -1;
   double distLow  = g_eq.lowsDetected  ? MathAbs(price-g_eq.lowLevel)  : -1;
   double prox = 0;
   if(distHigh>=0 && g_vol.atrAvg>0) prox = MathMax(prox, 100.0*MathMax(0.0,1.0-distHigh/(g_vol.atrAvg*1.5)));
   if(distLow>=0  && g_vol.atrAvg>0) prox = MathMax(prox, 100.0*MathMax(0.0,1.0-distLow/(g_vol.atrAvg*1.5)));
   g_eq.sweepProbability = MathMin(100.0, prox);
   g_eq.pressureScore = MathMin(100.0, (bestHighCluster+bestLowCluster)*12.0 + g_eq.sweepProbability*0.3);
}

void AddLiquidityPool(double price, string label, int priority, datetime t)
{
   if(price <= 0) return;
   double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);

   ArrayResize(g_liquidityPools, g_liqPoolCount+1);
   g_liquidityPools[g_liqPoolCount].price = price;
   g_liquidityPools[g_liqPoolCount].label = label;
   g_liquidityPools[g_liqPoolCount].priority = priority;
   g_liquidityPools[g_liqPoolCount].buySide = (price > currentPrice);
   g_liquidityPools[g_liqPoolCount].time = t;

   bool sweptFlag = false;
   int lookbackBars = MathMax(300, g_sessionAnchorBars*3);
   for(int b = 0; b < lookbackBars; b++)
   {
      if(g_liquidityPools[g_liqPoolCount].buySide) { if(iHigh(_Symbol,PERIOD_M5,b) > price) { sweptFlag = true; break; } }
      else                                          { if(iLow(_Symbol,PERIOD_M5,b)  < price) { sweptFlag = true; break; } }
   }
   g_liquidityPools[g_liqPoolCount].swept = sweptFlag;
   g_liqPoolCount++;
}

void BuildLiquidityPoolRanking()
{
   ArrayResize(g_liquidityPools, 0);
   g_liqPoolCount = 0;

   double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   datetime now = TimeCurrent();

   int extLookback = MathMin((int)MathMax(200, g_sessionAnchorBars*2), (int)Bars(_Symbol,PERIOD_M5)-1);
   int extHighIdx = iHighest(_Symbol,PERIOD_M5,MODE_HIGH,extLookback,0);
   int extLowIdx  = iLowest(_Symbol,PERIOD_M5,MODE_LOW,extLookback,0);
   AddLiquidityPool(iHigh(_Symbol,PERIOD_M5,extHighIdx), "EXTERNAL HIGH", 1, iTime(_Symbol,PERIOD_M5,extHighIdx));
   AddLiquidityPool(iLow(_Symbol,PERIOD_M5,extLowIdx),   "EXTERNAL LOW",  1, iTime(_Symbol,PERIOD_M5,extLowIdx));

   AddLiquidityPool(g_sessionHigh, "SESSION HIGH", 2, g_sessionHighTime);
   AddLiquidityPool(g_sessionLow,  "SESSION LOW",  2, g_sessionLowTime);

   int intLookback = (int)MathMax(InpStructureBars/2, g_sessionAnchorBars/2);
   int intHighIdx = iHighest(_Symbol,PERIOD_M5,MODE_HIGH,intLookback,0);
   int intLowIdx  = iLowest(_Symbol,PERIOD_M5,MODE_LOW,intLookback,0);
   AddLiquidityPool(iHigh(_Symbol,PERIOD_M5,intHighIdx), "INTERNAL HIGH", 3, iTime(_Symbol,PERIOD_M5,intHighIdx));
   AddLiquidityPool(iLow(_Symbol,PERIOD_M5,intLowIdx),   "INTERNAL LOW",  3, iTime(_Symbol,PERIOD_M5,intLowIdx));

   if(g_eq.highsDetected) AddLiquidityPool(g_eq.highLevel, "EQUAL HIGHS", 4, g_eqHighTime>0?g_eqHighTime:now);
   if(g_eq.lowsDetected)  AddLiquidityPool(g_eq.lowLevel,  "EQUAL LOWS",  4, g_eqLowTime>0?g_eqLowTime:now);

   AddLiquidityPool(iHigh(_Symbol,PERIOD_D1,1), "PREV DAY HIGH", 5, iTime(_Symbol,PERIOD_D1,1));
   AddLiquidityPool(iLow(_Symbol,PERIOD_D1,1),  "PREV DAY LOW",  5, iTime(_Symbol,PERIOD_D1,1));

   if(InpRoundNumberStep > 0)
   {
      double roundBelow = MathFloor(currentPrice/InpRoundNumberStep)*InpRoundNumberStep;
      datetime rTime = g_currentSessionStartTime>0 ? g_currentSessionStartTime : now;
      AddLiquidityPool(roundBelow+InpRoundNumberStep, "ROUND NUMBER", 6, rTime);
      AddLiquidityPool(roundBelow, "ROUND NUMBER", 6, rTime);
   }

   AddLiquidityPool(iHigh(_Symbol,PERIOD_D1,0), "DAILY HIGH", 7, iTime(_Symbol,PERIOD_D1,0));
   AddLiquidityPool(iLow(_Symbol,PERIOD_D1,0),  "DAILY LOW",  7, iTime(_Symbol,PERIOD_D1,0));

   AddLiquidityPool(iHigh(_Symbol,PERIOD_W1,1), "WEEKLY HIGH", 8, iTime(_Symbol,PERIOD_W1,1));
   AddLiquidityPool(iLow(_Symbol,PERIOD_W1,1),  "WEEKLY LOW",  8, iTime(_Symbol,PERIOD_W1,1));

   for(int i=0;i<g_liqPoolCount-1;i++)
      for(int j=0;j<g_liqPoolCount-1-i;j++)
         if(g_liquidityPools[j].priority > g_liquidityPools[j+1].priority)
         { LiquidityPool tmp=g_liquidityPools[j]; g_liquidityPools[j]=g_liquidityPools[j+1]; g_liquidityPools[j+1]=tmp; }

   g_buySideLiqCount = 0; g_sellSideLiqCount = 0;
   for(int i=0;i<g_liqPoolCount;i++)
   {
      if(g_liquidityPools[i].swept) continue;
      if(g_liquidityPools[i].buySide) g_buySideLiqCount++; else g_sellSideLiqCount++;
   }
}

// Nearest unswept liquidity pool in the given direction (1=above/buy-side, -1=below/sell-side)
bool GetNearestLiquidityTarget(int direction, double &outPrice, string &outLabel)
{
   double price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double bestDist = DBL_MAX;
   bool found = false;
   for(int i = 0; i < g_liqPoolCount; i++)
   {
      if(g_liquidityPools[i].swept) continue;
      bool isAbove = g_liquidityPools[i].price > price;
      if(direction > 0 && !isAbove) continue;
      if(direction < 0 && isAbove) continue;
      double dist = MathAbs(g_liquidityPools[i].price - price);
      if(dist < bestDist) { bestDist = dist; outPrice = g_liquidityPools[i].price; outLabel = g_liquidityPools[i].label; found = true; }
   }
   return found;
}

//=====================================================================
//  ORDER BLOCK INTELLIGENCE (scored, not just detected)
//  Quality score blends: freshness, displacement strength, momentum
//  follow-through, HTF alignment, and distance from equilibrium.
//  Breaker Blocks = an Order Block that failed and structure shifted
//  through it (institutional zone flips polarity).
//=====================================================================
void DetectOrderBlocks()
{
   ArrayResize(g_orderBlocks, 0);
   g_obCount = 0;

   int lookback = MathMin(g_analysisLookback, (int)Bars(_Symbol,PERIOD_M5)-5);
   double atrRef = g_vol.atrCurrent > 0 ? g_vol.atrCurrent : 0.0001;

   for(int i = 3; i < lookback; i++)
   {
      double open1=iOpen(_Symbol,PERIOD_M5,i), close1=iClose(_Symbol,PERIOD_M5,i);
      double high1=iHigh(_Symbol,PERIOD_M5,i), low1=iLow(_Symbol,PERIOD_M5,i);
      double open2=iOpen(_Symbol,PERIOD_M5,i-1), close2=iClose(_Symbol,PERIOD_M5,i-1);
      double close3=iClose(_Symbol,PERIOD_M5,i-2);

      bool bullishOB = (close1<open1) && (close2>open2) && (close3>close2);
      bool bearishOB = (close1>open1) && (close2<open2) && (close3<close2);
      if(!bullishOB && !bearishOB) continue;

      bool mitigated = bullishOB ? (iLow(_Symbol,PERIOD_M5,0)<low1) : (iHigh(_Symbol,PERIOD_M5,0)>high1);
      if(mitigated && i >= 15) continue;   // drop stale mitigated blocks, keep recent ones for breaker context

      ArrayResize(g_orderBlocks, g_obCount+1);
      g_orderBlocks[g_obCount].time = iTime(_Symbol,PERIOD_M5,i);
      g_orderBlocks[g_obCount].high = high1;
      g_orderBlocks[g_obCount].low  = low1;
      g_orderBlocks[g_obCount].isBullish = bullishOB;
      g_orderBlocks[g_obCount].mitigated = mitigated;
      g_orderBlocks[g_obCount].partiallyMitigated = false;
      g_orderBlocks[g_obCount].isBreaker = false;
      g_orderBlocks[g_obCount].isFresh = (i < 15);

      // touches: how many times price has revisited this block since formation
      int touches = 0;
      int barShift = iBarShift(_Symbol,PERIOD_M5,g_orderBlocks[g_obCount].time,false);
      for(int b = MathMax(0,barShift-1); b >= 0; b--)
      {
         double bh = iHigh(_Symbol,PERIOD_M5,b), bl = iLow(_Symbol,PERIOD_M5,b);
         if(bh >= low1 && bl <= high1) touches++;
      }
      g_orderBlocks[g_obCount].touches = touches;
      if(touches >= 1 && !mitigated) g_orderBlocks[g_obCount].partiallyMitigated = true;

      // Breaker: mitigated block whose zone price has since closed clean through with a structure break
      if(mitigated)
      {
         for(int k = 0; k < g_structCount; k++)
            if(g_structure[k].isBOS && g_structure[k].time > g_orderBlocks[g_obCount].time)
               { g_orderBlocks[g_obCount].isBreaker = true; break; }
      }

      // Quality score (0-100)
      double moveSize = bullishOB ? (close3-low1) : (high1-close3);
      double displacement = MathMin(100.0, MathMax(0.0, moveSize/atrRef*35.0));
      double freshness = g_orderBlocks[g_obCount].isFresh ? 25.0 : 10.0;
      double touchPenalty = MathMax(0.0, 20.0 - touches*7.0);
      double htfAlign = 0;
      if(bullishOB && g_mtf.h1.direction > 0) htfAlign = 15.0;
      if(bearishOB && g_mtf.h1.direction < 0) htfAlign = 15.0;
      double distFromEq = 0;
      if(g_pdZone.equilibrium > 0)
      {
         double distPct = MathAbs(((high1+low1)/2.0) - g_pdZone.equilibrium) / MathMax(0.0001, g_pdZone.rangeHigh-g_pdZone.rangeLow);
         distFromEq = MathMin(20.0, distPct*40.0);
      }
      double mitigatedPenalty = mitigated ? 25.0 : 0.0;

      double score = displacement*0.35 + freshness + touchPenalty*0.5 + htfAlign + distFromEq - mitigatedPenalty;
      g_orderBlocks[g_obCount].qualityScore = MathMax(0.0, MathMin(100.0, score));

      g_obCount++;
      if(g_obCount >= InpMaxOrderBlocks*3) break;   // cap raw detections before quality filtering downstream
   }
}

// Best-quality unmitigated order block in the given direction, above the minimum quality bar
bool GetBestOrderBlock(bool wantBullish, OrderBlockEx &outOB)
{
   double bestScore = -1;
   bool found = false;
   for(int i = 0; i < g_obCount; i++)
   {
      if(g_orderBlocks[i].isBullish != wantBullish) continue;
      if(g_orderBlocks[i].mitigated) continue;
      if(g_orderBlocks[i].qualityScore < InpMinOBQualityScore) continue;
      if(g_orderBlocks[i].qualityScore > bestScore) { bestScore = g_orderBlocks[i].qualityScore; outOB = g_orderBlocks[i]; found = true; }
   }
   return found;
}

//=====================================================================
//  FAIR VALUE GAP ENGINE (bullish/bearish + inverse + balanced range)
//=====================================================================
void DetectFairValueGaps()
{
   ArrayResize(g_fvgArray, 0);
   g_fvgCount = 0;

   int lookback = MathMin(g_analysisLookback, (int)Bars(_Symbol,PERIOD_M5)-3);

   for(int i = 2; i < lookback; i++)
   {
      double high0=iHigh(_Symbol,PERIOD_M5,i-2), low0=iLow(_Symbol,PERIOD_M5,i-2);
      double high2=iHigh(_Symbol,PERIOD_M5,i),   low2=iLow(_Symbol,PERIOD_M5,i);

      bool bullishFVG = (low0 > high2);
      bool bearishFVG = (high0 < low2);
      if(!bullishFVG && !bearishFVG) continue;

      double topPrice    = bullishFVG ? low0  : low2;
      double bottomPrice = bullishFVG ? high2 : high0;

      double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      bool filled = bullishFVG ? (currentPrice < bottomPrice) : (currentPrice > topPrice);
      if(filled && i >= 25) continue;   // drop stale filled gaps

      ArrayResize(g_fvgArray, g_fvgCount+1);
      g_fvgArray[g_fvgCount].startTime = iTime(_Symbol,PERIOD_M5,i);
      g_fvgArray[g_fvgCount].endTime   = TimeCurrent() + 3600*24;
      g_fvgArray[g_fvgCount].topPrice = topPrice;
      g_fvgArray[g_fvgCount].bottomPrice = bottomPrice;
      g_fvgArray[g_fvgCount].isBullish = bullishFVG;
      g_fvgArray[g_fvgCount].filled = filled;
      g_fvgArray[g_fvgCount].isInverse = filled;   // once filled through, it flips to acting as opposite-polarity resistance/support
      g_fvgArray[g_fvgCount].isBalancedRange = false;

      g_fvgCount++;
      if(g_fvgCount >= InpMaxFVGs*3) break;
   }

   // Balanced Price Range: overlap between a bullish and a bearish FVG
   for(int i = 0; i < g_fvgCount; i++)
   {
      for(int j = 0; j < g_fvgCount; j++)
      {
         if(i == j || g_fvgArray[i].isBullish == g_fvgArray[j].isBullish) continue;
         bool overlap = g_fvgArray[i].bottomPrice < g_fvgArray[j].topPrice && g_fvgArray[i].topPrice > g_fvgArray[j].bottomPrice;
         if(overlap) { g_fvgArray[i].isBalancedRange = true; g_fvgArray[j].isBalancedRange = true; }
      }
   }
}

//=====================================================================
//  PREMIUM / DISCOUNT / OTE ENGINE
//=====================================================================
void UpdatePremiumDiscountZone()
{
   int lookback = MathMin(g_analysisLookback, (int)Bars(_Symbol,PERIOD_M5)-1);
   double rangeHigh = iHigh(_Symbol,PERIOD_M5,iHighest(_Symbol,PERIOD_M5,MODE_HIGH,lookback,0));
   double rangeLow  = iLow(_Symbol,PERIOD_M5,iLowest(_Symbol,PERIOD_M5,MODE_LOW,lookback,0));
   double range = rangeHigh - rangeLow;
   if(range <= 0) return;

   g_pdZone.rangeHigh = rangeHigh;
   g_pdZone.rangeLow  = rangeLow;
   g_pdZone.equilibrium  = rangeLow + range*0.5;
   g_pdZone.premiumStart = rangeLow + range*0.618;
   g_pdZone.discountEnd  = rangeLow + range*0.382;

   // OTE for longs: the 61.8%-79% retracement of the most recent up-leg (from range low to range high)
   g_pdZone.oteLongStart = rangeHigh - range*0.79;
   g_pdZone.oteLongEnd   = rangeHigh - range*0.618;

   // OTE for shorts: the 61.8%-79% retracement of the most recent down-leg (from range high to range low)
   g_pdZone.oteShortStart = rangeLow + range*0.618;
   g_pdZone.oteShortEnd   = rangeLow + range*0.79;
}

bool IsInDiscount(double price) { return price < g_pdZone.equilibrium; }
bool IsInPremium(double price)  { return price > g_pdZone.equilibrium; }
bool IsInOTELong(double price)  { return price >= g_pdZone.oteLongStart  && price <= g_pdZone.oteLongEnd; }
bool IsInOTEShort(double price) { return price >= g_pdZone.oteShortStart && price <= g_pdZone.oteShortEnd; }

//=====================================================================
//  ADAPTIVE INDICATOR INTELLIGENCE
//  Indicators are supporting evidence, not decision-makers. This module
//  computes a regime-aware momentum score and a session-anchored VWAP,
//  activating the indicators most relevant to the current regime.
//=====================================================================
double g_momentumScore = 50;
double g_sessionVWAP = 0;

void UpdateSessionVWAP()
{
   double sumPV = 0, sumV = 0;
   for(int i = 0; i < g_sessionAnchorBars; i++)
   {
      double typical = (iHigh(_Symbol,PERIOD_M5,i) + iLow(_Symbol,PERIOD_M5,i) + iClose(_Symbol,PERIOD_M5,i)) / 3.0;
      long vol = iVolume(_Symbol,PERIOD_M5,i);
      sumPV += typical * (double)vol;
      sumV  += (double)vol;
   }
   g_sessionVWAP = (sumV > 0) ? sumPV/sumV : SymbolInfoDouble(_Symbol, SYMBOL_BID);
}

void UpdateMomentumScore()
{
   double adxBuf[1], macdMain[1], macdSignal[1], rsiBuf[1];
   if(CopyBuffer(g_adxHandle, 0, 0, 1, adxBuf) <= 0) adxBuf[0] = 20;
   if(CopyBuffer(g_macdHandle, 0, 0, 1, macdMain) <= 0) macdMain[0] = 0;
   if(CopyBuffer(g_macdHandle, 1, 0, 1, macdSignal) <= 0) macdSignal[0] = 0;
   if(CopyBuffer(g_rsiHandle, 0, 0, 1, rsiBuf) <= 0) rsiBuf[0] = 50;

   double score = 50;
   // ADX: trend strength contribution
   score += MathMin(25.0, MathMax(0.0, (adxBuf[0]-20.0) * 1.2));
   // MACD histogram direction/momentum
   double hist = macdMain[0] - macdSignal[0];
   score += MathMax(-15.0, MathMin(15.0, hist * 100000.0));   // scaled for BTC price magnitude
   // RSI distance from neutral (momentum extension, either direction)
   score += MathMin(10.0, MathAbs(rsiBuf[0]-50.0) * 0.3);

   g_momentumScore = MathMax(0.0, MathMin(100.0, score));
}

//=====================================================================
//  WEIGHTED DECISION ENGINE
//  Every module contributes a 0-100 sub-score; the composite confidence
//  is a configurable weighted blend. This replaces long mandatory
//  condition chains with a single, tunable "how strict" dial.
//=====================================================================
double NormalizedWeight(double w, double sumWeights) { return (sumWeights > 0) ? (w / sumWeights) * 100.0 : 0.0; }

double ScoreRegimeComponent()
{
   // Favor regimes that are actionable (trend/expansion/liquidity hunt/reversal) over "stand aside" regimes
   switch(g_regime.regime)
   {
      case REGIME_STRONG_BULL: case REGIME_STRONG_BEAR:
         return MathMin(100.0, g_regime.confidence * 1.05);
      case REGIME_WEAK_TREND: case REGIME_VOL_EXPANSION: case REGIME_LIQUIDITY_HUNT:
      case REGIME_POTENTIAL_REVERSAL: case REGIME_ACCUMULATION: case REGIME_DISTRIBUTION:
         return g_regime.confidence;
      case REGIME_RANGE: case REGIME_VOL_COMPRESSION:
         return g_regime.confidence * 0.85;
      case REGIME_TREND_EXHAUSTION: case REGIME_SESSION_TRANSITION:
         return g_regime.confidence * 0.7;
      case REGIME_NEWS_INSTABILITY:
         return 0;   // never contributes positively - true stand-down regime
      default: return g_regime.confidence * 0.6;
   }
}

double ScoreHTFBiasComponent(ENUM_TRADE_DIR dir)
{
   if(dir == DIR_NONE) return 0;
   int wantDir = (dir == DIR_LONG) ? 1 : -1;
   if(g_mtf.dominantDirection == wantDir) return g_mtf.alignment;
   if(g_mtf.dominantDirection == 0) return g_mtf.alignment * 0.5;   // neutral HTF - partial credit
   return MathMax(0.0, g_mtf.alignment * 0.2);                       // fighting the HTF narrative - heavily penalized
}

double ScoreLiquidityComponent(ENUM_TRADE_DIR dir)
{
   double outPrice; string outLabel;
   int wantDir = (dir == DIR_LONG) ? 1 : -1;
   if(!GetNearestLiquidityTarget(wantDir, outPrice, outLabel)) return 30.0;
   double dist = MathAbs(outPrice - SymbolInfoDouble(_Symbol, SYMBOL_BID));
   double atrRef = g_vol.atrCurrent > 0 ? g_vol.atrCurrent : 0.0001;
   double distATR = dist / atrRef;
   // Closer, meaningful liquidity target = higher score (there's somewhere for price to be drawn to)
   return MathMax(10.0, MathMin(100.0, 100.0 - distATR*12.0));
}

double ScoreStructureComponent(ENUM_TRADE_DIR dir)
{
   if(g_structCount < 2) return 20.0;
   double score = 0;
   int recentBOS = 0, recentMSS = 0, total = 0;
   int startIdx = MathMax(0, g_structCount-10);
   for(int i = startIdx; i < g_structCount; i++)
   {
      total++;
      bool matchesDir = (dir==DIR_LONG && !g_structure[i].isHigh) || (dir==DIR_SHORT && g_structure[i].isHigh);
      if(g_structure[i].isMSS && matchesDir) { recentMSS++; score += 25; }
      else if(g_structure[i].isBOS && matchesDir) { recentBOS++; score += 15; }
      if(g_structure[i].isProtected) score += 3;
   }
   score += g_regime.stability * 0.15;
   return MathMax(0.0, MathMin(100.0, score));
}

double ScoreOrderBlockComponent(ENUM_TRADE_DIR dir)
{
   OrderBlockEx ob;
   bool found = GetBestOrderBlock(dir==DIR_LONG, ob);
   if(!found) return 25.0;
   return ob.qualityScore;
}

double ScoreFVGComponent(ENUM_TRADE_DIR dir)
{
   double price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double best = 20.0;
   for(int i = 0; i < g_fvgCount; i++)
   {
      if(g_fvgArray[i].filled && !g_fvgArray[i].isInverse) continue;
      bool wantBull = (dir == DIR_LONG);
      if(g_fvgArray[i].isBullish != wantBull) continue;
      double mid = (g_fvgArray[i].topPrice + g_fvgArray[i].bottomPrice)/2.0;
      double atrRef = g_vol.atrCurrent > 0 ? g_vol.atrCurrent : 0.0001;
      double distATR = MathAbs(price-mid)/atrRef;
      double s = MathMax(0.0, 80.0 - distATR*15.0) + (g_fvgArray[i].isBalancedRange ? 15.0 : 0.0);
      if(s > best) best = s;
   }
   return MathMin(100.0, best);
}

double ScoreMomentumComponent(ENUM_TRADE_DIR dir)
{
   // Momentum score is direction-agnostic in magnitude; direction alignment matters
   double rsiBuf[1];
   if(CopyBuffer(g_rsiHandle, 0, 0, 1, rsiBuf) <= 0) rsiBuf[0] = 50;
   bool alignedUp   = (dir==DIR_LONG  && rsiBuf[0] > 50);
   bool alignedDown = (dir==DIR_SHORT && rsiBuf[0] < 50);
   double base = g_momentumScore;
   return (alignedUp || alignedDown) ? base : base * 0.6;
}

double ScoreSessionComponent()
{
   switch(g_session)
   {
      case SESSION_LONDON_OPEN: return 95;
      case SESSION_NY_OPEN:     return 95;
      case SESSION_LONDON_MID:  return 80;
      case SESSION_NY_PM:       return 75;
      case SESSION_ASIAN:       return 65;   // BTC's Asian session carries real volume, unlike FX
      default:                   return 45;   // dead zone - BTC still trades, just thinner
   }
}

double ScoreVolatilityComponent()
{
   double score;
   switch(g_vol.state)
   {
      case VOL_NORMAL:  score = 100; break;
      case VOL_HIGH:     score = 75; break;
      case VOL_LOW:      score = 60; break;
      default:            score = 25; break;   // extreme
   }
   if(g_vol.dynamic == VOLDYN_SPIKE) score *= 0.5;
   if(g_vol.atrRatio > 2.5) score *= 0.7;
   return score;
}

double ScoreRiskRewardComponent(double slPrice, double tpPrice, double entryPrice, ENUM_TRADE_DIR dir)
{
   double risk = MathAbs(entryPrice - slPrice);
   double reward = MathAbs(tpPrice - entryPrice);
   if(risk <= 0) return 0;
   double rr = reward / risk;
   if(rr < InpMinRiskReward) return MathMax(0.0, rr/InpMinRiskReward * 40.0);
   return MathMin(100.0, 40.0 + (rr - InpMinRiskReward) * 25.0);
}

// Master confidence builder - called once a strategy has produced a candidate signal
void BuildTradeConfidence(StrategySignal &sig)
{
   double sumW = InpWeightRegime+InpWeightHTFBias+InpWeightLiquidity+InpWeightStructure+InpWeightOrderBlock
               + InpWeightFVG+InpWeightMomentum+InpWeightSession+InpWeightVolatility+InpWeightRiskReward;

   g_confidence.regimeScore      = ScoreRegimeComponent();
   g_confidence.htfBiasScore     = ScoreHTFBiasComponent(sig.direction);
   g_confidence.liquidityScore   = ScoreLiquidityComponent(sig.direction);
   g_confidence.structureScore   = ScoreStructureComponent(sig.direction);
   g_confidence.orderBlockScore  = ScoreOrderBlockComponent(sig.direction);
   g_confidence.fvgScore         = ScoreFVGComponent(sig.direction);
   g_confidence.momentumScore    = ScoreMomentumComponent(sig.direction);
   g_confidence.sessionScore     = ScoreSessionComponent();
   g_confidence.volatilityScore  = ScoreVolatilityComponent();
   g_confidence.riskRewardScore  = ScoreRiskRewardComponent(sig.suggestedSL, sig.suggestedTP,
                                       SymbolInfoDouble(_Symbol, sig.direction==DIR_LONG?SYMBOL_ASK:SYMBOL_BID), sig.direction);

   double total =
        g_confidence.regimeScore     * NormalizedWeight(InpWeightRegime, sumW)/100.0
      + g_confidence.htfBiasScore    * NormalizedWeight(InpWeightHTFBias, sumW)/100.0
      + g_confidence.liquidityScore  * NormalizedWeight(InpWeightLiquidity, sumW)/100.0
      + g_confidence.structureScore  * NormalizedWeight(InpWeightStructure, sumW)/100.0
      + g_confidence.orderBlockScore * NormalizedWeight(InpWeightOrderBlock, sumW)/100.0
      + g_confidence.fvgScore        * NormalizedWeight(InpWeightFVG, sumW)/100.0
      + g_confidence.momentumScore   * NormalizedWeight(InpWeightMomentum, sumW)/100.0
      + g_confidence.sessionScore    * NormalizedWeight(InpWeightSession, sumW)/100.0
      + g_confidence.volatilityScore * NormalizedWeight(InpWeightVolatility, sumW)/100.0
      + g_confidence.riskRewardScore * NormalizedWeight(InpWeightRiskReward, sumW)/100.0;

   // Weekend caution: BTC liquidity thins on weekends - nudge the bar up slightly rather than blocking outright
   if(InpWeekendCaution && IsWeekend(TimeCurrent()))
      total -= InpWeekendConfPenalty;

   g_confidence.totalScore = MathMax(0.0, MathMin(100.0, total));

   g_confidence.approved = true;
   g_confidence.rejectReason = "";

   if(g_confidence.totalScore < InpMinConfidenceScore)
   {
      g_confidence.approved = false;
      g_confidence.rejectReason = "Confidence " + DoubleToString(g_confidence.totalScore,0) + "% below threshold";
   }
   if(g_confidence.riskRewardScore < 20)
   {
      g_confidence.approved = false;
      g_confidence.rejectReason = "Risk:Reward below minimum";
   }
   if(InpRequireHTFAlignment && g_mtf.alignment < InpMinHTFAlignment)
   {
      g_confidence.approved = false;
      g_confidence.rejectReason = "Insufficient HTF alignment";
   }
   if(g_regime.regime == REGIME_NEWS_INSTABILITY)
   {
      g_confidence.approved = false;
      g_confidence.rejectReason = "News/volatility instability override";
   }
}

//=====================================================================
//  STRATEGY MODULES
//  Each module only produces a signal when its own conditions are met.
//  The regime router decides which module(s) are even allowed to run.
//=====================================================================
StrategySignal Strategy_TrendContinuation()
{
   StrategySignal s; s.source=STRAT_TREND_CONTINUATION; s.direction=DIR_NONE; s.valid=false; s.reason="";
   if(g_mtf.dominantDirection == 0 || g_mtf.alignment < 35) { s.reason="No clear HTF trend"; return s; }

   int dir = g_mtf.dominantDirection;
   if(g_mtf.m15.direction != 0 && g_mtf.m15.direction != dir) { s.reason="M15 not aligned"; return s; }

   double atr = g_vol.atrCurrent;
   double price = (dir>0) ? SymbolInfoDouble(_Symbol,SYMBOL_ASK) : SymbolInfoDouble(_Symbol,SYMBOL_BID);
   s.direction = (dir>0) ? DIR_LONG : DIR_SHORT;
   s.suggestedSL = (dir>0) ? NPrice(price-atr*InpSLAtrMultiplier) : NPrice(price+atr*InpSLAtrMultiplier);
   s.suggestedTP = (dir>0) ? NPrice(price+atr*InpSLAtrMultiplier*2.2) : NPrice(price-atr*InpSLAtrMultiplier*2.2);
   s.rawConfidence = g_mtf.alignment;
   s.reason = "Trend continuation, HTF alignment " + DoubleToString(g_mtf.alignment,0) + "%";
   s.valid = true;
   return s;
}

StrategySignal Strategy_LiquiditySweepReversal()
{
   StrategySignal s; s.source=STRAT_LIQUIDITY_SWEEP_REVERSAL; s.direction=DIR_NONE; s.valid=false; s.reason="";
   if(!g_eq.sweepUp && !g_eq.sweepDown) { s.reason="No liquidity sweep detected"; return s; }

   double atr = g_vol.atrCurrent;
   if(g_eq.sweepUp)
   {
      double entry = SymbolInfoDouble(_Symbol,SYMBOL_BID);
      s.direction = DIR_SHORT;
      s.suggestedSL = NPrice(g_eq.highLevel + atr*0.4);
      s.suggestedTP = NPrice(entry - atr*2.2);
   }
   else
   {
      double entry = SymbolInfoDouble(_Symbol,SYMBOL_ASK);
      s.direction = DIR_LONG;
      s.suggestedSL = NPrice(g_eq.lowLevel - atr*0.4);
      s.suggestedTP = NPrice(entry + atr*2.2);
   }
   s.rawConfidence = MathMin(95.0, g_eq.sweepProbability*0.5 + g_eq.pressureScore*0.4);
   s.reason = "Liquidity sweep reversal";
   s.valid = true;
   return s;
}

StrategySignal Strategy_RangeMeanReversion()
{
   StrategySignal s; s.source=STRAT_RANGE_MEAN_REVERSION; s.direction=DIR_NONE; s.valid=false; s.reason="";
   double rsiBuf[1];
   if(CopyBuffer(g_rsiHandle,0,0,1,rsiBuf)<=0) { s.reason="RSI unavailable"; return s; }

   bool overbought = rsiBuf[0] > 65;
   bool oversold   = rsiBuf[0] < 35;
   if(!overbought && !oversold) { s.reason="RSI not extended"; return s; }

   double atr = g_vol.atrCurrent;
   if(overbought)
   {
      double entry = SymbolInfoDouble(_Symbol,SYMBOL_BID);
      s.direction = DIR_SHORT;
      s.suggestedSL = NPrice(entry + atr*1.6);
      s.suggestedTP = NPrice(MathMax(g_pdZone.equilibrium, entry - atr*2.2));
   }
   else
   {
      double entry = SymbolInfoDouble(_Symbol,SYMBOL_ASK);
      s.direction = DIR_LONG;
      s.suggestedSL = NPrice(entry - atr*1.6);
      s.suggestedTP = NPrice(MathMin(g_pdZone.equilibrium, entry + atr*2.2));
   }
   s.rawConfidence = MathMin(90.0, MathAbs(rsiBuf[0]-50.0)*1.6);
   s.reason = "Range mean reversion, RSI " + DoubleToString(rsiBuf[0],1);
   s.valid = true;
   return s;
}

StrategySignal Strategy_VolatilityBreakout()
{
   StrategySignal s; s.source=STRAT_VOLATILITY_BREAKOUT; s.direction=DIR_NONE; s.valid=false; s.reason="";
   if(g_vol.dynamic != VOLDYN_EXPANDING) { s.reason="Not expanding"; return s; }

   double hh = StructureHighestHigh(InpStructureBars,1);
   double ll = StructureLowestLow(InpStructureBars,1);
   double price = SymbolInfoDouble(_Symbol,SYMBOL_BID);
   double atr = g_vol.atrCurrent;

   bool brokeUp = price > hh, brokeDown = price < ll;
   if(!brokeUp && !brokeDown) { s.reason="No confirmed break"; return s; }

   if(brokeUp)
   {
      double entry = SymbolInfoDouble(_Symbol,SYMBOL_ASK);
      s.direction = DIR_LONG;
      s.suggestedSL = NPrice(hh - atr*0.4);
      s.suggestedTP = NPrice(entry + atr*3.0);
   }
   else
   {
      double entry = SymbolInfoDouble(_Symbol,SYMBOL_BID);
      s.direction = DIR_SHORT;
      s.suggestedSL = NPrice(ll + atr*0.4);
      s.suggestedTP = NPrice(entry - atr*3.0);
   }
   s.rawConfidence = MathMin(92.0, 50.0 + g_vol.atrRatio*18.0);
   s.reason = "Volatility breakout, ATR ratio " + DoubleToString(g_vol.atrRatio,2);
   s.valid = true;
   return s;
}

StrategySignal Strategy_MomentumScalp()
{
   StrategySignal s; s.source=STRAT_MOMENTUM_SCALP; s.direction=DIR_NONE; s.valid=false; s.reason="";
   if(g_momentumScore < 62) { s.reason="Momentum insufficient"; return s; }

   double rsiBuf[1];
   if(CopyBuffer(g_rsiHandle,0,0,1,rsiBuf)<=0) { s.reason="RSI unavailable"; return s; }
   int dir = (rsiBuf[0] > 52) ? 1 : (rsiBuf[0] < 48 ? -1 : 0);
   if(dir == 0 || g_mtf.m15.direction == 0 || g_mtf.m15.direction != dir) { s.reason="No aligned micro-momentum"; return s; }

   double atr = g_vol.atrCurrent;
   double price = (dir>0) ? SymbolInfoDouble(_Symbol,SYMBOL_ASK) : SymbolInfoDouble(_Symbol,SYMBOL_BID);
   s.direction = (dir>0) ? DIR_LONG : DIR_SHORT;
   s.suggestedSL = (dir>0) ? NPrice(price-atr*1.2) : NPrice(price+atr*1.2);
   s.suggestedTP = (dir>0) ? NPrice(price+atr*2.0) : NPrice(price-atr*2.0);
   s.rawConfidence = g_momentumScore;
   s.reason = "Momentum scalp, score " + DoubleToString(g_momentumScore,0);
   s.valid = true;
   return s;
}

StrategySignal Strategy_PullbackContinuation()
{
   StrategySignal s; s.source=STRAT_PULLBACK_CONTINUATION; s.direction=DIR_NONE; s.valid=false; s.reason="";
   if(g_mtf.dominantDirection == 0) { s.reason="No HTF trend to pull back into"; return s; }

   double price = SymbolInfoDouble(_Symbol,SYMBOL_BID);
   bool inOTE = (g_mtf.dominantDirection>0) ? IsInOTELong(price) : IsInOTEShort(price);
   if(!inOTE) { s.reason="Not in OTE zone"; return s; }

   double atr = g_vol.atrCurrent;
   int dir = g_mtf.dominantDirection;
   double entry = (dir>0) ? SymbolInfoDouble(_Symbol,SYMBOL_ASK) : SymbolInfoDouble(_Symbol,SYMBOL_BID);
   s.direction = (dir>0) ? DIR_LONG : DIR_SHORT;
   s.suggestedSL = (dir>0) ? NPrice(g_pdZone.oteLongStart - atr*0.3) : NPrice(g_pdZone.oteShortEnd + atr*0.3);
   s.suggestedTP = (dir>0) ? NPrice(g_pdZone.rangeHigh) : NPrice(g_pdZone.rangeLow);
   s.rawConfidence = MathMin(90.0, g_mtf.alignment*0.9);
   s.reason = "Pullback continuation in OTE zone";
   s.valid = true;
   return s;
}

StrategySignal Strategy_SessionExpansion()
{
   StrategySignal s; s.source=STRAT_SESSION_EXPANSION; s.direction=DIR_NONE; s.valid=false; s.reason="";
   if(g_sessionTransitionBars <= 0) { s.reason="Not in a session transition window"; return s; }
   if(g_mtf.m15.direction == 0) { s.reason="No directional bias yet"; return s; }

   double atr = g_vol.atrCurrent;
   int dir = g_mtf.m15.direction;
   double price = (dir>0) ? SymbolInfoDouble(_Symbol,SYMBOL_ASK) : SymbolInfoDouble(_Symbol,SYMBOL_BID);
   s.direction = (dir>0) ? DIR_LONG : DIR_SHORT;
   s.suggestedSL = (dir>0) ? NPrice(g_sessionLow) : NPrice(g_sessionHigh);
   s.suggestedTP = (dir>0) ? NPrice(price+atr*2.5) : NPrice(price-atr*2.5);
   s.rawConfidence = 65.0;
   s.reason = "Session expansion at " + SessionToString(g_session);
   s.valid = true;
   return s;
}

StrategySignal Strategy_OBReentry()
{
   StrategySignal s; s.source=STRAT_OB_REENTRY; s.direction=DIR_NONE; s.valid=false; s.reason="";

   bool wantBull = (g_mtf.dominantDirection >= 0);
   OrderBlockEx ob;
   if(!GetBestOrderBlock(wantBull, ob)) { s.reason="No quality order block nearby"; return s; }

   double price = SymbolInfoDouble(_Symbol,SYMBOL_BID);
   bool priceInZone = (price <= ob.high && price >= ob.low);
   if(!priceInZone) { s.reason="Price not currently retesting the block"; return s; }

   double atr = g_vol.atrCurrent;
   if(wantBull)
   {
      double entry = SymbolInfoDouble(_Symbol,SYMBOL_ASK);
      s.direction = DIR_LONG;
      s.suggestedSL = NPrice(ob.low - atr*0.3);
      s.suggestedTP = NPrice(entry + atr*2.4);
   }
   else
   {
      double entry = SymbolInfoDouble(_Symbol,SYMBOL_BID);
      s.direction = DIR_SHORT;
      s.suggestedSL = NPrice(ob.high + atr*0.3);
      s.suggestedTP = NPrice(entry - atr*2.4);
   }
   s.rawConfidence = ob.qualityScore;
   s.reason = "Order block re-entry, quality " + DoubleToString(ob.qualityScore,0);
   s.valid = true;
   return s;
}

//=====================================================================
//  REGIME -> STRATEGY ROUTER
//  Maps the current regime to the strategy module(s) statistically
//  best suited to it. Returns the primary candidate; a small number of
//  regimes offer a secondary candidate when both are coherent.
//=====================================================================
ENUM_STRATEGY_TYPE RouteRegimeToStrategy(ENUM_MKT_REGIME regime)
{
   switch(regime)
   {
      case REGIME_STRONG_BULL:
      case REGIME_STRONG_BEAR:         return STRAT_TREND_CONTINUATION;
      case REGIME_WEAK_TREND:          return STRAT_PULLBACK_CONTINUATION;
      case REGIME_ACCUMULATION:
      case REGIME_DISTRIBUTION:        return STRAT_OB_REENTRY;
      case REGIME_RANGE:               return STRAT_RANGE_MEAN_REVERSION;
      case REGIME_VOL_EXPANSION:       return STRAT_VOLATILITY_BREAKOUT;
      case REGIME_VOL_COMPRESSION:     return STRAT_NONE;   // genuinely wait for expansion - no edge here
      case REGIME_LIQUIDITY_HUNT:      return STRAT_LIQUIDITY_SWEEP_REVERSAL;
      case REGIME_SESSION_TRANSITION:  return STRAT_SESSION_EXPANSION;
      case REGIME_TREND_EXHAUSTION:    return STRAT_LIQUIDITY_SWEEP_REVERSAL;
      case REGIME_POTENTIAL_REVERSAL:  return STRAT_LIQUIDITY_SWEEP_REVERSAL;
      case REGIME_NEWS_INSTABILITY:    return STRAT_NONE;   // the one true circuit breaker
      default:                          return STRAT_NONE;
   }
}

StrategySignal GetSignalForStrategy(ENUM_STRATEGY_TYPE strat)
{
   StrategySignal s; s.valid=false; s.direction=DIR_NONE; s.source=strat; s.reason="No strategy";
   switch(strat)
   {
      case STRAT_TREND_CONTINUATION:         return Strategy_TrendContinuation();
      case STRAT_LIQUIDITY_SWEEP_REVERSAL:   return Strategy_LiquiditySweepReversal();
      case STRAT_RANGE_MEAN_REVERSION:       return Strategy_RangeMeanReversion();
      case STRAT_VOLATILITY_BREAKOUT:        return Strategy_VolatilityBreakout();
      case STRAT_MOMENTUM_SCALP:             return Strategy_MomentumScalp();
      case STRAT_PULLBACK_CONTINUATION:      return Strategy_PullbackContinuation();
      case STRAT_SESSION_EXPANSION:          return Strategy_SessionExpansion();
      case STRAT_OB_REENTRY:                 return Strategy_OBReentry();
      default: return s;
   }
}

int StrategyHealthIndex(ENUM_STRATEGY_TYPE s)
{
   switch(s)
   {
      case STRAT_TREND_CONTINUATION:       return 0;
      case STRAT_LIQUIDITY_SWEEP_REVERSAL: return 1;
      case STRAT_RANGE_MEAN_REVERSION:     return 2;
      case STRAT_VOLATILITY_BREAKOUT:      return 3;
      case STRAT_MOMENTUM_SCALP:           return 4;
      case STRAT_PULLBACK_CONTINUATION:    return 5;
      case STRAT_SESSION_EXPANSION:        return 6;
      case STRAT_OB_REENTRY:               return 7;
      default: return -1;
   }
}

string StrategyToString(ENUM_STRATEGY_TYPE s)
{
   switch(s)
   {
      case STRAT_TREND_CONTINUATION:       return "TrendCont";
      case STRAT_LIQUIDITY_SWEEP_REVERSAL: return "LiqSweepRev";
      case STRAT_RANGE_MEAN_REVERSION:     return "RangeMeanRev";
      case STRAT_VOLATILITY_BREAKOUT:      return "VolBreakout";
      case STRAT_MOMENTUM_SCALP:           return "MomentumScalp";
      case STRAT_PULLBACK_CONTINUATION:    return "PullbackCont";
      case STRAT_SESSION_EXPANSION:        return "SessionExpand";
      case STRAT_OB_REENTRY:               return "OBReentry";
      default:                              return "None";
   }
}

//=====================================================================
//  ADAPTIVE ENTRY STYLE SELECTION
//=====================================================================
ENUM_ENTRY_STYLE SelectEntryStyle(double confidence)
{
   if(confidence >= 80 && g_vol.state != VOL_EXTREME) return ENTRY_AGGRESSIVE;
   if(confidence >= 65) return ENTRY_STANDARD;
   return ENTRY_CONSERVATIVE;
}

//=====================================================================
//  ADAPTIVE STOP LOSS ENGINE
//  Evaluates several logical SL candidates (ATR, nearest protected
//  swing, order block edge) and picks the safest one that still
//  respects a hard maximum distance ceiling.
//=====================================================================
double RefineStopLoss(ENUM_TRADE_DIR dir, double atrSL, double entryPrice)
{
   double atr = g_vol.atrCurrent;
   double maxDist = atr * InpMaxSLAtrMultiplier;
   double candidates[4];
   int nCand = 0;
   candidates[nCand++] = atrSL;

   // Nearest protected swing in the stop-loss direction
   for(int i = g_structCount-1; i >= 0; i--)
   {
      if(!g_structure[i].isProtected) continue;
      if(dir == DIR_LONG && !g_structure[i].isHigh && g_structure[i].price < entryPrice)
      { candidates[nCand++] = NPrice(g_structure[i].price - atr*0.2); break; }
      if(dir == DIR_SHORT && g_structure[i].isHigh && g_structure[i].price > entryPrice)
      { candidates[nCand++] = NPrice(g_structure[i].price + atr*0.2); break; }
      if(nCand >= 4) break;
   }

   // Nearest relevant order block edge
   OrderBlockEx ob;
   if(GetBestOrderBlock(dir==DIR_LONG, ob) && nCand < 4)
   {
      candidates[nCand++] = (dir==DIR_LONG) ? NPrice(ob.low - atr*0.2) : NPrice(ob.high + atr*0.2);
   }

   // Pick the candidate closest to price but still beyond the ATR floor, capped by the max distance ceiling
   double best = atrSL;
   double bestDist = MathAbs(entryPrice - atrSL);
   for(int i = 0; i < nCand; i++)
   {
      double dist = MathAbs(entryPrice - candidates[i]);
      if(dist < atr*0.5) continue;         // too tight, likely to get noise-stopped
      if(dist > maxDist) continue;          // respects the hard ceiling
      if(dist < bestDist) { bestDist = dist; best = candidates[i]; }
   }
   return best;
}

//=====================================================================
//  DYNAMIC TAKE PROFIT ENGINE
//  Targets the nearest meaningful liquidity pool / institutional zone
//  in the trade's direction, falling back to an ATR projection when
//  the minimum risk:reward isn't otherwise satisfied.
//=====================================================================
double RefineTakeProfit(ENUM_TRADE_DIR dir, double atrTP, double entryPrice, double slPrice)
{
   double outPrice; string outLabel;
   int wantDir = (dir == DIR_LONG) ? 1 : -1;
   double risk = MathAbs(entryPrice - slPrice);
   if(risk <= 0) return atrTP;

   if(GetNearestLiquidityTarget(wantDir, outPrice, outLabel))
   {
      double reward = MathAbs(outPrice - entryPrice);
      double rr = reward / risk;
      if(rr >= InpMinRiskReward)
         return NPrice(outPrice);
   }
   return atrTP;   // fall back to the strategy's own ATR-based projection
}

//=====================================================================
//  ADAPTIVE POSITION SIZING
//=====================================================================
double CalculateAdaptiveLotSize(StrategySignal &signal, double slPrice, double &outRiskAmountUsed)
{
   outRiskAmountUsed = 0.0;
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   if(equity <= 0) return 0.0;

   double price = (signal.direction==DIR_LONG) ? SymbolInfoDouble(_Symbol,SYMBOL_ASK) : SymbolInfoDouble(_Symbol,SYMBOL_BID);
   double slDistance = MathAbs(price - slPrice);
   if(slDistance <= 0) return 0.0;

   double confFactor = MathMax(0.5, MathMin(1.0, g_confidence.totalScore/100.0));
   double regimeFactor = MathMax(0.5, MathMin(1.0, (g_regime.confidence*0.6 + g_regime.stability*0.4)/100.0));

   int hIdx = StrategyHealthIndex(signal.source);
   double healthFactor = 1.0;
   if(hIdx>=0 && hIdx<8) healthFactor = g_health[hIdx].influenceMultiplier;

   double ddRatio = (InpMaxDrawdownPct>0) ? (g_risk.currentDrawdownPct/InpMaxDrawdownPct) : 0.0;
   double drawdownFactor = MathMax(0.25, 1.0-ddRatio);

   double riskPct = InpRiskPercentPerTrade * confFactor * regimeFactor * healthFactor * drawdownFactor;
   riskPct = MathMin(riskPct, InpMaxRiskPercentTrade);

   double riskAmount = equity * (riskPct/100.0);

   double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double tickSize  = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   if(tickValue<=0 || tickSize<=0) return 0.0;

   double valuePerPriceUnit = tickValue/tickSize;
   double lot = riskAmount / (slDistance*valuePerPriceUnit);

   double lotMin = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double lotMax = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);

   lot = MathFloor(lot/lotStep)*lotStep;
   lot = MathMax(lotMin, MathMin(lotMax, lot));

   outRiskAmountUsed = lot*slDistance*valuePerPriceUnit;
   return lot;
}

//=====================================================================
//  RISK GOVERNANCE ENGINE
//=====================================================================
void InitRiskState()
{
   double eq = AccountInfoDouble(ACCOUNT_EQUITY);
   g_risk.peakEquity = eq;
   g_risk.dayStartEquity = eq;
   g_risk.weekStartEquity = eq;
   g_risk.dailyLossLimitHit = false;
   g_risk.weeklyLossLimitHit = false;
   g_risk.dailyProfitLockHit = false;
   g_risk.maxDrawdownBreached = false;
   g_risk.emergencyShutdown = false;
   g_risk.currentDrawdownPct = 0.0;
   g_risk.maxDrawdownSeenPct = 0.0;
   g_risk.consecutiveLosses = 0;
}

void UpdateRiskState()
{
   double eq = AccountInfoDouble(ACCOUNT_EQUITY);
   if(eq > g_risk.peakEquity) g_risk.peakEquity = eq;
   g_risk.currentDrawdownPct = (g_risk.peakEquity>0) ? (g_risk.peakEquity-eq)/g_risk.peakEquity*100.0 : 0.0;
   if(g_risk.currentDrawdownPct > g_risk.maxDrawdownSeenPct) g_risk.maxDrawdownSeenPct = g_risk.currentDrawdownPct;

   double dailyPL = eq - g_risk.dayStartEquity;
   double dailyRiskUsedPct = (g_risk.dayStartEquity>0) ? MathMax(0.0, -dailyPL/g_risk.dayStartEquity*100.0) : 0.0;
   double dailyProfitPct   = (g_risk.dayStartEquity>0) ? MathMax(0.0,  dailyPL/g_risk.dayStartEquity*100.0) : 0.0;
   double weeklyRiskUsedPct = (g_risk.weekStartEquity>0) ? MathMax(0.0, (g_risk.weekStartEquity-eq)/g_risk.weekStartEquity*100.0) : 0.0;

   g_risk.dailyRiskUsedPct = dailyRiskUsedPct;
   g_risk.weeklyRiskUsedPct = weeklyRiskUsedPct;
   g_risk.dailyLossLimitHit = (InpMaxDailyLossPct>0 && dailyRiskUsedPct >= InpMaxDailyLossPct);
   g_risk.weeklyLossLimitHit = (InpMaxWeeklyLossPct>0 && weeklyRiskUsedPct >= InpMaxWeeklyLossPct);
   g_risk.dailyProfitLockHit = (InpDailyProfitLockPct>0 && dailyProfitPct >= InpDailyProfitLockPct);

   if(InpMaxDrawdownPct>0 && g_risk.currentDrawdownPct >= InpMaxDrawdownPct)
   {
      g_risk.maxDrawdownBreached = true;
      g_risk.emergencyShutdown = true;
   }
}

bool RiskGovernanceAllowsNewTrade(string &rejectReason)
{
   if(g_risk.emergencyShutdown)   { rejectReason = "Emergency shutdown (max drawdown)"; return false; }
   if(g_risk.dailyLossLimitHit)   { rejectReason = "Daily loss limit hit"; return false; }
   if(g_risk.weeklyLossLimitHit)  { rejectReason = "Weekly loss limit hit"; return false; }
   if(g_risk.dailyProfitLockHit)  { rejectReason = "Daily profit lock engaged - protecting today's gains"; return false; }
   if(InpMaxDailyTrades>0 && g_tradesToday>=InpMaxDailyTrades) { rejectReason = "Max daily trades reached"; return false; }
   if(PositionsTotalForMagic()>=InpMaxConcurrentTrades) { rejectReason = "Max concurrent positions"; return false; }
   if(g_inCooldown) { rejectReason = "Cooldown active"; return false; }
   if(g_risk.consecutiveLosses >= InpMaxConsecutiveLosses) { rejectReason = "Max consecutive losses - pausing"; return false; }
   return true;
}

int PositionsTotalForMagic()
{
   int count = 0;
   for(int i = PositionsTotal()-1; i>=0; i--)
      if(g_pos.SelectByIndex(i) && g_pos.Magic()==InpMagicNumber && g_pos.Symbol()==_Symbol) count++;
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
      g_risk.dailyLossLimitHit = false;
      g_risk.dailyProfitLockHit = false;
      g_sessionProfit = 0.0; g_sessionWins = 0; g_sessionLosses = 0;
   }
   if(thisWeek != g_weekStart)
   {
      g_weekStart = thisWeek;
      g_risk.weekStartEquity = AccountInfoDouble(ACCOUNT_EQUITY);
      g_risk.weeklyLossLimitHit = false;
   }
}

//=====================================================================
//  STRATEGY HEALTH MONITOR
//=====================================================================
void InitStrategyHealth()
{
   string names[8] = {"TrendCont","LiqSweepRev","RangeMeanRev","VolBreakout","MomentumScalp","PullbackCont","SessionExpand","OBReentry"};
   for(int i=0;i<8;i++)
   {
      g_health[i].name = names[i];
      g_health[i].totalTrades=0; g_health[i].wins=0; g_health[i].losses=0;
      g_health[i].grossProfit=0; g_health[i].grossLoss=0; g_health[i].sumR=0;
      g_health[i].consecLosses=0; g_health[i].winRate=0; g_health[i].profitFactor=0;
      g_health[i].expectancyR=0; g_health[i].enabled=true; g_health[i].influenceMultiplier=1.0;
   }
}

void RegisterTradeResult(ENUM_STRATEGY_TYPE strat, double pnl, double rMultiple)
{
   int idx = StrategyHealthIndex(strat);
   if(idx<0 || idx>=8) return;

   StrategyHealth h = g_health[idx];
   h.totalTrades++;
   if(pnl>=0) { h.wins++; h.grossProfit+=pnl; h.consecLosses=0; g_risk.consecutiveLosses=0; }
   else       { h.losses++; h.grossLoss+=MathAbs(pnl); h.consecLosses++; g_risk.consecutiveLosses++; }

   h.sumR += rMultiple;
   h.winRate = (h.totalTrades>0) ? 100.0*h.wins/h.totalTrades : 0.0;
   h.profitFactor = (h.grossLoss>0) ? h.grossProfit/h.grossLoss : (h.grossProfit>0?99.0:0.0);
   h.expectancyR = (h.totalTrades>0) ? h.sumR/h.totalTrades : 0.0;

   g_health[idx] = h;
   UpdateStrategyInfluence(idx);
}

void UpdateStrategyInfluence(int idx)
{
   if(idx<0 || idx>=8) return;
   StrategyHealth h = g_health[idx];
   if(h.totalTrades < InpHealthMinTrades) { g_health[idx].influenceMultiplier = 1.0; return; }

   double target = 1.0;
   if(h.consecLosses >= InpHealthDegradeConsecLoss) target = MathMin(target, 0.5);
   if(h.expectancyR < InpHealthMinExpectancyR) target = MathMin(target, 0.4);
   if(h.profitFactor < 0.8 && h.totalTrades>=InpHealthMinTrades) target = MathMin(target, 0.6);

   if(h.consecLosses >= InpHealthDegradeConsecLoss*2 || h.expectancyR < InpHealthMinExpectancyR*2.5)
   { g_health[idx].enabled=false; target=0.0; }

   double cur = g_health[idx].influenceMultiplier;
   g_health[idx].influenceMultiplier = cur + (target-cur)*0.5;
   if(g_health[idx].influenceMultiplier > 0.7) g_health[idx].enabled = true;
}

//=====================================================================
//  MASTER DECISION ENGINE
//  Implements the full execution sequence from the spec:
//  regime -> narrative -> liquidity target -> sweep/trigger -> BOS/CHoCH
//  confirmation -> institutional zone -> momentum -> volatility ->
//  spread -> risk:reward -> execute.
//=====================================================================
string EncodePositionTag(ENUM_STRATEGY_TYPE strat, double riskAmount)
{
   return InpBotName + "|" + IntegerToString((int)strat) + "|" + DoubleToString(riskAmount,2);
}
bool DecodePositionTag(string comment, ENUM_STRATEGY_TYPE &strat, double &riskAmount)
{
   string parts[];
   int n = StringSplit(comment,'|',parts);
   if(n<3 || ArraySize(parts)<3) return false;
   strat = (ENUM_STRATEGY_TYPE)StringToInteger(parts[1]);
   riskAmount = StringToDouble(parts[2]);
   return true;
}

MasterDecision BuildMasterDecision()
{
   MasterDecision d;
   d.tradeApproved=false; d.direction=DIR_NONE; d.lotSize=0; d.slPrice=0; d.tpPrice=0;
   d.strategySource=STRAT_NONE; d.entryStyle=ENTRY_STANDARD; d.riskAmountUsed=0; d.confidence=0; d.narrative="";

   // Stage 1-2: regime + narrative already computed upstream each cycle
   string rejectReason = "";
   if(!RiskGovernanceAllowsNewTrade(rejectReason)) { d.narrative = rejectReason; return d; }

   if(g_regime.regime == REGIME_NEWS_INSTABILITY) { d.narrative = "News/volatility instability"; return d; }
   if(g_regime.confidence < InpMinRegimeConfidence) { d.narrative = "Low regime confidence"; return d; }

   double spread = (double)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   if(spread > InpMaxSpreadPoints) { d.narrative = "Spread too wide"; return d; }

   // Stage 3-6: route to strategy, which internally validates liquidity/structure/zone context
   ENUM_STRATEGY_TYPE routedStrat = RouteRegimeToStrategy(g_regime.regime);
   if(routedStrat == STRAT_NONE) { d.narrative = "No strategy suited to current regime"; return d; }

   int hIdx = StrategyHealthIndex(routedStrat);
   if(hIdx>=0 && hIdx<8 && !g_health[hIdx].enabled) { d.narrative = "Strategy paused (health monitor)"; return d; }

   StrategySignal signal = GetSignalForStrategy(routedStrat);
   if(!signal.valid) { d.narrative = signal.reason; return d; }

   // Stage 7-8: refine SL/TP using structure & liquidity, momentum/volatility feed into confidence
   double entryPrice = (signal.direction==DIR_LONG) ? SymbolInfoDouble(_Symbol,SYMBOL_ASK) : SymbolInfoDouble(_Symbol,SYMBOL_BID);
   signal.suggestedSL = RefineStopLoss(signal.direction, signal.suggestedSL, entryPrice);
   signal.suggestedTP = RefineTakeProfit(signal.direction, signal.suggestedTP, entryPrice, signal.suggestedSL);

   // Stage 9-10: weighted confidence + risk:reward validation
   BuildTradeConfidence(signal);
   if(!g_confidence.approved) { d.narrative = g_confidence.rejectReason; return d; }

   double riskAmountUsed = 0.0;
   double lot = CalculateAdaptiveLotSize(signal, signal.suggestedSL, riskAmountUsed);
   if(lot <= 0) { d.narrative = "Invalid lot size"; return d; }

   // Stage 11: execute
   d.tradeApproved = true;
   d.direction = signal.direction;
   d.lotSize = lot;
   d.slPrice = signal.suggestedSL;
   d.tpPrice = signal.suggestedTP;
   d.strategySource = routedStrat;
   d.entryStyle = SelectEntryStyle(g_confidence.totalScore);
   d.riskAmountUsed = riskAmountUsed;
   d.confidence = g_confidence.totalScore;
   d.narrative = StrategyToString(routedStrat) + " | " + signal.reason + " | Conf " + DoubleToString(g_confidence.totalScore,0) + "%";
   return d;
}

bool ExecuteMasterDecision(MasterDecision &decision)
{
   if(!decision.tradeApproved || decision.direction==DIR_NONE) return false;

   double price = (decision.direction==DIR_LONG) ? SymbolInfoDouble(_Symbol,SYMBOL_ASK) : SymbolInfoDouble(_Symbol,SYMBOL_BID);
   if(price<=0) return false;

   int stopsLevel = (int)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   double minDist = stopsLevel*point;

   double sl = decision.slPrice, tp = decision.tpPrice;
   if(decision.direction==DIR_LONG)
   {
      if(sl>0 && (price-sl)<minDist) sl = NPrice(price-minDist);
      if(tp>0 && (tp-price)<minDist) tp = NPrice(price+minDist);
   }
   else
   {
      if(sl>0 && (sl-price)<minDist) sl = NPrice(price+minDist);
      if(tp>0 && (price-tp)<minDist) tp = NPrice(price-minDist);
   }

   string tag = EncodePositionTag(decision.strategySource, decision.riskAmountUsed);
   g_trade.SetExpertMagicNumber(InpMagicNumber);
   g_trade.SetDeviationInPoints(InpMaxSlippagePoints);
   g_trade.SetTypeFilling(GetFillMode());

   bool ok = (decision.direction==DIR_LONG)
      ? g_trade.Buy(decision.lotSize,_Symbol,price,sl,tp,tag)
      : g_trade.Sell(decision.lotSize,_Symbol,price,sl,tp,tag);

   if(ok)
   {
      g_tradesToday++;
      g_lastAction = decision.narrative;
      g_barsInCurrentTrade = 0;
      g_partialTaken = false;
      DrawEntryMarker(decision.direction, price, decision.strategySource);
   }
   return ok;
}

double GetFloatingPL()
{
   double t=0;
   for(int i=PositionsTotal()-1;i>=0;i--)
      if(g_pos.SelectByIndex(i) && g_pos.Magic()==InpMagicNumber && g_pos.Symbol()==_Symbol)
         t += g_pos.Profit()+g_pos.Swap()+g_pos.Commission();
   return t;
}
bool HasManagedPosition() { return PositionsTotalForMagic() > 0; }

//=====================================================================
//  ADVANCED TRADE MANAGEMENT
//  Break-even, partial exits, structure/ATR trailing, time-based exit,
//  and emergency exit on abnormal market behaviour.
//=====================================================================
void ManageOpenPositions()
{
   for(int i=PositionsTotal()-1;i>=0;i--)
   {
      if(!g_pos.SelectByIndex(i)) continue;
      if(g_pos.Magic()!=InpMagicNumber || g_pos.Symbol()!=_Symbol) continue;

      ulong ticket = g_pos.Ticket();
      double openPrice = g_pos.PriceOpen();
      double currentSL = g_pos.StopLoss();
      double currentTP = g_pos.TakeProfit();
      bool isLong = (g_pos.PositionType()==POSITION_TYPE_BUY);
      double currentPrice = isLong ? SymbolInfoDouble(_Symbol,SYMBOL_BID) : SymbolInfoDouble(_Symbol,SYMBOL_ASK);

      double atr = g_vol.atrCurrent>0 ? g_vol.atrCurrent : 0.0001;
      double profitDist = isLong ? (currentPrice-openPrice) : (openPrice-currentPrice);
      double profitInATR = profitDist/atr;

      double newSL = currentSL;
      bool needUpdate = false;

      // Emergency exit: abnormal adverse move far beyond normal ATR (news spike against us)
      double lossDist = isLong ? (openPrice-currentPrice) : (currentPrice-openPrice);
      if(lossDist > atr*InpMaxSLAtrMultiplier*1.5 && g_newsShockLevel==2)
      {
         g_trade.PositionClose(ticket);
         Print("[BIE] Emergency exit - abnormal move during news/volatility instability: ", ticket);
         continue;
      }

      // Break-even
      if(profitInATR >= InpBreakEvenAtr)
      {
         double bePrice = openPrice + (isLong ? atr*0.15 : -atr*0.15);
         if(isLong  && currentSL < bePrice) { newSL = NPrice(bePrice); needUpdate = true; }
         if(!isLong && (currentSL > bePrice || currentSL==0)) { newSL = NPrice(bePrice); needUpdate = true; }
      }

      // Structure/ATR trailing
      if(profitInATR >= InpTrailStartAtr)
      {
         double trailDist = atr*1.0;
         double trailSL = isLong ? (currentPrice-trailDist) : (currentPrice+trailDist);
         if(isLong  && trailSL>currentSL) { newSL = NPrice(trailSL); needUpdate = true; }
         if(!isLong && (trailSL<currentSL || currentSL==0)) { newSL = NPrice(trailSL); needUpdate = true; }
      }

      // Partial close at defined ATR profit
      if(profitInATR >= InpPartialCloseAtr && !g_partialTaken)
      {
         double lotMin = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
         double closeLot = MathFloor(g_pos.Volume()*(InpPartialClosePct/100.0)/lotMin)*lotMin;
         if(closeLot >= lotMin)
         {
            if(g_trade.PositionClosePartial(ticket, closeLot))
            {
               g_partialTaken = true;
               Print("[BIE] Partial close ", InpPartialClosePct, "% at +", DoubleToString(profitInATR,1), " ATR");
            }
         }
      }

      // Time-based exit
      g_barsInCurrentTrade++;
      if(InpMaxHoldingBars>0 && g_barsInCurrentTrade > InpMaxHoldingBars)
      {
         g_trade.PositionClose(ticket);
         Print("[BIE] Time-based exit - max holding bars exceeded: ", ticket);
         continue;
      }

      if(needUpdate && newSL>0)
      {
         if(!g_trade.PositionModify(ticket,newSL,currentTP))
            Print("[BIE] Failed to modify SL: ", GetLastError());
      }
   }
}

//=====================================================================
//  TRADE TRANSACTION HANDLER
//=====================================================================
void OnTradeTransactionHandler(const MqlTradeTransaction &trans, const MqlTradeRequest &request, const MqlTradeResult &result)
{
   if(trans.type != TRADE_TRANSACTION_DEAL_ADD) return;
   ulong dealTicket = trans.deal;
   if(!HistoryDealSelect(dealTicket)) return;
   if((ulong)HistoryDealGetInteger(dealTicket, DEAL_MAGIC) != InpMagicNumber) return;
   if(HistoryDealGetString(dealTicket, DEAL_SYMBOL) != _Symbol) return;
   if(HistoryDealGetInteger(dealTicket, DEAL_ENTRY) != DEAL_ENTRY_OUT) return;

   double pnl = HistoryDealGetDouble(dealTicket, DEAL_PROFIT) + HistoryDealGetDouble(dealTicket, DEAL_SWAP) + HistoryDealGetDouble(dealTicket, DEAL_COMMISSION);
   string comment = HistoryDealGetString(dealTicket, DEAL_COMMENT);

   ENUM_STRATEGY_TYPE strat = STRAT_NONE;
   double riskAmount = 0;
   if(!DecodePositionTag(comment, strat, riskAmount)) return;

   double rMultiple = (riskAmount>0) ? pnl/riskAmount : 0.0;
   RegisterTradeResult(strat, pnl, rMultiple);

   g_sessionProfit += pnl;
   if(pnl>=0) g_sessionWins++; else g_sessionLosses++;

   g_lastCloseTime = TimeCurrent();
   g_inCooldown = true;

   double exitPrice = HistoryDealGetDouble(dealTicket, DEAL_PRICE);
   DrawExitMarker(exitPrice, pnl);

   Print("[BIE] Trade closed: ", StrategyToString(strat), " | P&L=", DoubleToString(pnl,2), " | R=", DoubleToString(rMultiple,2));
}

void RunMasterDecisionCycle()
{
   if(HasManagedPosition())
   {
      ManageOpenPositions();
      g_statusText = "IN TRADE";
      g_statusColor = C_GREEN;
      return;
   }
   if(g_inCooldown) { g_statusText = "COOLDOWN"; g_statusColor = C_CYAN; return; }

   MasterDecision decision = BuildMasterDecision();
   g_lastDecision = decision;

   if(decision.tradeApproved)
   {
      g_statusText = "EXECUTING"; g_statusColor = C_LBLUE;
      bool ok = ExecuteMasterDecision(decision);
      if(ok) { g_statusText = "IN TRADE"; g_statusColor = C_GREEN; }
      else    { g_statusText = "ORDER FAIL"; g_statusColor = C_RED; }
   }
   else
   {
      g_statusText = "ANALYZING"; g_statusColor = C_GOLD;
      g_lastAction = decision.narrative;
   }
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
   ChartSetInteger(chartId, CHART_COLOR_CHART_UP,    C_GREEN);
   ChartSetInteger(chartId, CHART_COLOR_CHART_DOWN,  C_RED);
   ChartSetInteger(chartId, CHART_COLOR_CHART_LINE,  C_CYAN);
   ChartSetInteger(chartId, CHART_COLOR_CANDLE_BULL, C_GREEN);
   ChartSetInteger(chartId, CHART_COLOR_CANDLE_BEAR, C_RED);
   ChartSetInteger(chartId, CHART_COLOR_VOLUME,      C_MGRAY);
   ChartSetInteger(chartId, CHART_COLOR_BID,         C_ACBORD);
   ChartSetInteger(chartId, CHART_COLOR_ASK,         C_ORANGE);
   ChartSetInteger(chartId, CHART_COLOR_LAST,        C_GOLD);
   ChartSetInteger(chartId, CHART_COLOR_STOP_LEVEL,  C_PURPLE);
   ChartSetInteger(chartId, CHART_SHOW_GRID, InpHideGrid ? false : true);
   ChartSetInteger(chartId, CHART_MODE, CHART_CANDLES);
   ChartRedraw(chartId);
   Print("[BIE] Black chart theme applied.");
}

//=====================================================================
//  DRAWING HELPERS
//  Labels anchor at the point of detection (not "now") with a small
//  vertical offset above the line, so they spread across the timeline
//  instead of stacking unreadably at the right edge.
//=====================================================================
void DrawHorizontalLine(string name, datetime time1, datetime time2, double price, color lineColor, string label,
                         int width=1, ENUM_LINE_STYLE style=STYLE_SOLID, bool ray=false,
                         bool labelAtDetectionPoint=true, double labelOffsetATR=0.18)
{
   string lineName = OV+name;
   ObjectDelete(0,lineName);
   if(ObjectCreate(0,lineName,OBJ_TREND,0,time1,price,time2,price))
   {
      ObjectSetInteger(0,lineName,OBJPROP_COLOR,lineColor);
      ObjectSetInteger(0,lineName,OBJPROP_STYLE,style);
      ObjectSetInteger(0,lineName,OBJPROP_WIDTH,width);
      ObjectSetInteger(0,lineName,OBJPROP_BACK,true);
      ObjectSetInteger(0,lineName,OBJPROP_SELECTABLE,false);
      ObjectSetInteger(0,lineName,OBJPROP_HIDDEN,true);
      ObjectSetInteger(0,lineName,OBJPROP_RAY_RIGHT,ray);
   }
   if(label != "")
   {
      string lblName = lineName+"_LBL";
      ObjectDelete(0,lblName);
      datetime labelTime = labelAtDetectionPoint ? time1 : time2;
      double atrRef = g_vol.atrCurrent>0 ? g_vol.atrCurrent : 0.0001;
      double labelPrice = price + atrRef*labelOffsetATR;
      if(ObjectCreate(0,lblName,OBJ_TEXT,0,labelTime,labelPrice))
      {
         ObjectSetString(0,lblName,OBJPROP_TEXT," "+label);
         ObjectSetInteger(0,lblName,OBJPROP_COLOR,lineColor);
         ObjectSetInteger(0,lblName,OBJPROP_FONTSIZE,InpLabelFontSize);
         ObjectSetString(0,lblName,OBJPROP_FONT,"Arial");
         ObjectSetInteger(0,lblName,OBJPROP_ANCHOR,ANCHOR_LEFT);
         ObjectSetInteger(0,lblName,OBJPROP_SELECTABLE,false);
         ObjectSetInteger(0,lblName,OBJPROP_HIDDEN,true);
      }
   }
}

void DrawTrendLine(string name, datetime t1, double p1, datetime t2, double p2, color lineColor, string label, int width=1, ENUM_LINE_STYLE style=STYLE_SOLID)
{
   string lineName = OV+name;
   ObjectDelete(0,lineName);
   if(ObjectCreate(0,lineName,OBJ_TREND,0,t1,p1,t2,p2))
   {
      ObjectSetInteger(0,lineName,OBJPROP_COLOR,lineColor);
      ObjectSetInteger(0,lineName,OBJPROP_STYLE,style);
      ObjectSetInteger(0,lineName,OBJPROP_WIDTH,width);
      ObjectSetInteger(0,lineName,OBJPROP_BACK,true);
      ObjectSetInteger(0,lineName,OBJPROP_SELECTABLE,false);
      ObjectSetInteger(0,lineName,OBJPROP_HIDDEN,true);
      ObjectSetInteger(0,lineName,OBJPROP_RAY_RIGHT,false);
   }
   if(label != "")
   {
      string lblName = lineName+"_LBL";
      ObjectDelete(0,lblName);
      if(ObjectCreate(0,lblName,OBJ_TEXT,0,t2,p2))
      {
         ObjectSetString(0,lblName,OBJPROP_TEXT," "+label);
         ObjectSetInteger(0,lblName,OBJPROP_COLOR,lineColor);
         ObjectSetInteger(0,lblName,OBJPROP_FONTSIZE,InpLabelFontSize-1);
         ObjectSetString(0,lblName,OBJPROP_FONT,"Arial");
         ObjectSetInteger(0,lblName,OBJPROP_SELECTABLE,false);
         ObjectSetInteger(0,lblName,OBJPROP_HIDDEN,true);
      }
   }
}

void DrawEntryMarker(ENUM_TRADE_DIR dir, double price, ENUM_STRATEGY_TYPE strat)
{
   datetime t = TimeCurrent();
   string name = OV+"ENTRY_"+IntegerToString((int)t)+"_"+IntegerToString(MathRand());
   int arrowCode = (dir==DIR_LONG) ? 233 : 234;
   color arrowColor = (dir==DIR_LONG) ? C_GREEN : C_RED;
   if(ObjectCreate(0,name,OBJ_ARROW,0,t,price))
   {
      ObjectSetInteger(0,name,OBJPROP_ARROWCODE,arrowCode);
      ObjectSetInteger(0,name,OBJPROP_COLOR,arrowColor);
      ObjectSetInteger(0,name,OBJPROP_WIDTH,2);
      ObjectSetInteger(0,name,OBJPROP_SELECTABLE,false);
      ObjectSetInteger(0,name,OBJPROP_HIDDEN,true);
      ObjectSetInteger(0,name,OBJPROP_ANCHOR,(dir==DIR_LONG)?ANCHOR_TOP:ANCHOR_BOTTOM);
   }
   string lbl = name+"_lbl";
   double offset = g_vol.atrAvg*0.5;
   double lblPrice = (dir==DIR_LONG) ? price-offset : price+offset;
   if(ObjectCreate(0,lbl,OBJ_TEXT,0,t,lblPrice))
   {
      ObjectSetString(0,lbl,OBJPROP_TEXT,StrategyToString(strat));
      ObjectSetInteger(0,lbl,OBJPROP_COLOR,arrowColor);
      ObjectSetInteger(0,lbl,OBJPROP_FONTSIZE,7);
      ObjectSetInteger(0,lbl,OBJPROP_SELECTABLE,false);
      ObjectSetInteger(0,lbl,OBJPROP_HIDDEN,true);
   }
}

void DrawExitMarker(double price, double pnl)
{
   datetime t = TimeCurrent();
   string name = OV+"EXIT_"+IntegerToString((int)t)+"_"+IntegerToString(MathRand());
   color markColor = (pnl>=0) ? C_CYAN : C_PURPLE;
   if(ObjectCreate(0,name,OBJ_ARROW,0,t,price))
   {
      ObjectSetInteger(0,name,OBJPROP_ARROWCODE,251);
      ObjectSetInteger(0,name,OBJPROP_COLOR,markColor);
      ObjectSetInteger(0,name,OBJPROP_WIDTH,2);
      ObjectSetInteger(0,name,OBJPROP_SELECTABLE,false);
      ObjectSetInteger(0,name,OBJPROP_HIDDEN,true);
   }
   string lbl = name+"_lbl";
   if(ObjectCreate(0,lbl,OBJ_TEXT,0,t,price))
   {
      ObjectSetString(0,lbl,OBJPROP_TEXT,(pnl>=0?"+":"")+DoubleToString(pnl,2));
      ObjectSetInteger(0,lbl,OBJPROP_COLOR,markColor);
      ObjectSetInteger(0,lbl,OBJPROP_FONTSIZE,7);
      ObjectSetInteger(0,lbl,OBJPROP_SELECTABLE,false);
      ObjectSetInteger(0,lbl,OBJPROP_HIDDEN,true);
   }
}

//=====================================================================
//  STRUCTURE / OB / FVG / LIQUIDITY / PREMIUM-DISCOUNT OVERLAYS
//=====================================================================
void DrawStructureOverlay()
{
   if(!InpDrawStructure || g_structCount<2) return;
   int startIdx = MathMax(0, g_structCount-10);
   for(int i=startIdx;i<g_structCount-1;i++)
   {
      if(!g_structure[i].isMajor && !InpShowMinorStructure) continue;
      string lineName = "STRUCT_"+IntegerToString(i);
      color lineColor = g_structure[i].isMajor ? C'150,150,150' : C'70,70,70';
      int lineWidth = 1; ENUM_LINE_STYLE style = g_structure[i].isMajor ? STYLE_SOLID : STYLE_DOT;
      string label = "";
      if(g_structure[i].isMSS) { lineColor=C_MAGENTA; lineWidth=3; label="MSS"; }
      else if(g_structure[i].isBOS) { lineColor=C_GOLD; lineWidth=2; label="BOS"; }
      else if(g_structure[i].isCHoCH) { lineColor=C_ORANGE; lineWidth=2; label="CHoCH"; }
      DrawTrendLine(lineName, g_structure[i].time, g_structure[i].price, g_structure[i+1].time, g_structure[i+1].price, lineColor, label, lineWidth, style);
   }
   // Protected level markers
   int drawn = 0;
   for(int i=g_structCount-1; i>=startIdx && drawn<4; i--)
   {
      if(!g_structure[i].isProtected) continue;
      double price = SymbolInfoDouble(_Symbol,SYMBOL_BID);
      double distATR = (g_vol.atrCurrent>0) ? MathAbs(price-g_structure[i].price)/g_vol.atrCurrent : 999;
      if(distATR>6.0) continue;
      color lvlColor = g_structure[i].isHigh ? C_PURPLE : C'108,255,220';
      string lbl = g_structure[i].isHigh ? "Protected High" : "Protected Low";
      DrawHorizontalLine("PROT_"+IntegerToString(i), g_structure[i].time, TimeCurrent(), g_structure[i].price, lvlColor, lbl, 1, STYLE_DASH, false);
      drawn++;
   }
}

void DrawOrderBlockOverlay()
{
   if(!InpDrawOrderBlocks || g_obCount<=0) return;
   datetime now = TimeCurrent();
   int drawn = 0;
   for(int i=g_obCount-1;i>=0 && drawn<InpMaxOrderBlocks;i--)
   {
      if(g_orderBlocks[i].mitigated && !g_orderBlocks[i].isBreaker) continue;
      if(g_orderBlocks[i].qualityScore < InpMinOBQualityScore) continue;
      double price = SymbolInfoDouble(_Symbol,SYMBOL_BID);
      double distATR = MathAbs(price-(g_orderBlocks[i].high+g_orderBlocks[i].low)/2)/MathMax(0.0001,g_vol.atrCurrent);
      if(distATR>5.0) continue;

      color lineColor = g_orderBlocks[i].isBullish ? C'60,180,100' : C'220,80,80';
      string typeLabel = (g_orderBlocks[i].isBullish?"OB-Bull":"OB-Bear") + " Q"+DoubleToString(g_orderBlocks[i].qualityScore,0);
      if(g_orderBlocks[i].isBreaker) { lineColor = C_MAGENTA; typeLabel = "BREAKER " + typeLabel; }

      DrawHorizontalLine("OB_HIGH_"+IntegerToString(i), g_orderBlocks[i].time, now, g_orderBlocks[i].high, lineColor, typeLabel, 1, STYLE_DOT, false);
      DrawHorizontalLine("OB_LOW_"+IntegerToString(i), g_orderBlocks[i].time, now, g_orderBlocks[i].low, lineColor, "", 1, STYLE_DOT, false);
      drawn++;
   }
}

void DrawFVGOverlay()
{
   if(!InpDrawFVG || g_fvgCount<=0) return;
   datetime now = TimeCurrent();
   int drawn = 0;
   for(int i=g_fvgCount-1;i>=0 && drawn<InpMaxFVGs;i--)
   {
      double price = SymbolInfoDouble(_Symbol,SYMBOL_BID);
      double distATR = MathAbs(price-(g_fvgArray[i].topPrice+g_fvgArray[i].bottomPrice)/2)/MathMax(0.0001,g_vol.atrCurrent);
      if(distATR>4.0) continue;

      color lineColor = g_fvgArray[i].isBullish ? C'100,200,150' : C'200,100,120';
      string label = g_fvgArray[i].isBullish ? "FVG-Bull" : "FVG-Bear";
      if(g_fvgArray[i].isInverse) { lineColor = C_PURPLE; label = "iFVG"; }
      if(g_fvgArray[i].isBalancedRange) label += " BPR";

      DrawHorizontalLine("FVG_TOP_"+IntegerToString(i), g_fvgArray[i].startTime, now, g_fvgArray[i].topPrice, lineColor, label, 1, STYLE_DASHDOTDOT, false);
      DrawHorizontalLine("FVG_BOT_"+IntegerToString(i), g_fvgArray[i].startTime, now, g_fvgArray[i].bottomPrice, lineColor, "", 1, STYLE_DASHDOTDOT, false);
      drawn++;
   }
}

void DrawLiquidityOverlay()
{
   ObjectsDeleteAll(0, OV+"LP_");
   if(!InpDrawLiquidity || g_liqPoolCount<=0) return;
   datetime now = TimeCurrent();
   double price = SymbolInfoDouble(_Symbol,SYMBOL_BID);
   double atrRef = g_vol.atrCurrent>0?g_vol.atrCurrent:0.0001;
   int drawn = 0;
   for(int i=0;i<g_liqPoolCount && drawn<InpMaxLiquidityLines;i++)
   {
      if(g_liquidityPools[i].swept) continue;
      double distATR = MathAbs(price-g_liquidityPools[i].price)/atrRef;
      if(distATR>8.0) continue;

      color lvlColor; int lvlWidth; ENUM_LINE_STYLE lvlStyle;
      if(g_liquidityPools[i].priority<=1) { lvlColor=C_GOLD; lvlWidth=2; lvlStyle=STYLE_SOLID; }
      else if(g_liquidityPools[i].priority==2) { lvlColor=C'0,190,255'; lvlWidth=1; lvlStyle=STYLE_DASH; }
      else if(g_liquidityPools[i].priority==3) { lvlColor=C'150,150,150'; lvlWidth=1; lvlStyle=STYLE_DOT; }
      else if(g_liquidityPools[i].priority==4) { lvlColor=C'255,150,150'; lvlWidth=1; lvlStyle=STYLE_SOLID; }
      else { lvlColor=C'120,120,170'; lvlWidth=1; lvlStyle=STYLE_DASHDOT; }

      datetime lineStart = g_liquidityPools[i].time>0 ? g_liquidityPools[i].time : now;
      if(lineStart>=now) lineStart = now-300;
      string side = g_liquidityPools[i].buySide ? " (BSL)" : " (SSL)";
      DrawHorizontalLine("LP_"+IntegerToString(i), lineStart, now, g_liquidityPools[i].price, lvlColor, g_liquidityPools[i].label+side, lvlWidth, lvlStyle, true);
      drawn++;
   }
}

void DrawPremiumDiscountOverlay()
{
   if(!InpDrawPremiumDiscount || g_pdZone.rangeHigh<=g_pdZone.rangeLow) return;
   datetime now = TimeCurrent();
   datetime past = g_currentSessionStartTime>0 ? g_currentSessionStartTime : (now-3600*24);
   DrawHorizontalLine("RANGE_HIGH", past, now, g_pdZone.rangeHigh, C'150,150,150', "Range High", 1, STYLE_SOLID, true);
   DrawHorizontalLine("RANGE_LOW", past, now, g_pdZone.rangeLow, C'150,150,150', "Range Low", 1, STYLE_SOLID, true);
   DrawHorizontalLine("EQUILIBRIUM", past, now, g_pdZone.equilibrium, C_GOLD, "EQ 50%", 2, STYLE_SOLID, true);
   DrawHorizontalLine("PREMIUM_618", past, now, g_pdZone.premiumStart, C'200,100,100', "Premium 61.8%", 1, STYLE_DOT, true);
   DrawHorizontalLine("DISCOUNT_382", past, now, g_pdZone.discountEnd, C'100,200,100', "Discount 38.2%", 1, STYLE_DOT, true);
}

void UpdateAllOverlays()
{
   DrawStructureOverlay();
   DrawOrderBlockOverlay();
   DrawFVGOverlay();
   DrawLiquidityOverlay();
   DrawPremiumDiscountOverlay();
   ChartRedraw(0);
}

//=====================================================================
//  DASHBOARD PRIMITIVES
//=====================================================================
void R(string nm, int x, int y, int w, int h, color bg, color brd=clrNONE, int bw=1)
{
   string n = D+nm; ObjectDelete(0,n);
   if(ObjectCreate(0,n,OBJ_RECTANGLE_LABEL,0,0,0))
   {
      ObjectSetInteger(0,n,OBJPROP_CORNER,CORNER_LEFT_UPPER);
      ObjectSetInteger(0,n,OBJPROP_XDISTANCE,x);
      ObjectSetInteger(0,n,OBJPROP_YDISTANCE,y);
      ObjectSetInteger(0,n,OBJPROP_XSIZE,w);
      ObjectSetInteger(0,n,OBJPROP_YSIZE,h);
      ObjectSetInteger(0,n,OBJPROP_BGCOLOR,bg);
      if(brd!=clrNONE) { ObjectSetInteger(0,n,OBJPROP_BORDER_TYPE,BORDER_FLAT); ObjectSetInteger(0,n,OBJPROP_COLOR,brd); ObjectSetInteger(0,n,OBJPROP_WIDTH,bw); }
      else ObjectSetInteger(0,n,OBJPROP_BORDER_TYPE,BORDER_RAISED);
      ObjectSetInteger(0,n,OBJPROP_SELECTABLE,false);
      ObjectSetInteger(0,n,OBJPROP_HIDDEN,true);
   }
}
void L(string nm, int x, int y, string txt, color clr, int fsz, string fnt="Arial")
{
   string n = D+nm; ObjectDelete(0,n);
   if(ObjectCreate(0,n,OBJ_LABEL,0,0,0))
   {
      ObjectSetInteger(0,n,OBJPROP_CORNER,CORNER_LEFT_UPPER);
      ObjectSetInteger(0,n,OBJPROP_XDISTANCE,x);
      ObjectSetInteger(0,n,OBJPROP_YDISTANCE,y);
      ObjectSetString(0,n,OBJPROP_TEXT,txt);
      ObjectSetInteger(0,n,OBJPROP_COLOR,clr);
      ObjectSetInteger(0,n,OBJPROP_FONTSIZE,fsz);
      ObjectSetString(0,n,OBJPROP_FONT,fnt);
      ObjectSetInteger(0,n,OBJPROP_SELECTABLE,false);
      ObjectSetInteger(0,n,OBJPROP_HIDDEN,true);
   }
}
void U(string nm, string txt, color clr=C'222,228,242')
{
   string n = D+nm;
   if(ObjectFind(0,n)>=0) { ObjectSetString(0,n,OBJPROP_TEXT,txt); ObjectSetInteger(0,n,OBJPROP_COLOR,clr); }
}

//=====================================================================
//  DASHBOARD - INIT (two-column institutional layout)
//=====================================================================
void InitDash()
{
   if(MQLInfoInteger(MQL_TESTER) && !MQLInfoInteger(MQL_VISUAL_MODE)) { Print("Dashboard disabled in non-visual tester"); return; }

   int X = InpDashX, Y = InpDashY;
   int CW = 222;
   int XL = X+4;
   int XR = X+232;

   R("frame_outer", X, Y, DW, DH, C_BG0, C_ACBORD, 2);
   R("frame_inner", X+2, Y+2, DW-4, DH-4, C_BG0, C_BORDER, 1);

   R("title_hd", X+2, Y+2, DW-4, 22, C_HDRBAR, C_ACBORD, 1);
   L("title_lbl", X+10, Y+6, "BTC INSTITUTIONAL EA", C_CYAN, 9, "Arial Black");
   L("title_time", X+DW-72, Y+7, "--:--", C_SUBTEXT, 7, "Arial");

   int yColTop = Y+28;
   R("col_divider", X+228, yColTop, 2, 320, C_BORDER);

   //--- LEFT: MARKET
   int yMkt = yColTop;
   R("mkt_hd", XL, yMkt, CW, 16, C_ORANGE, C_BORDER, 1);
   L("mkt_lbl", XL+6, yMkt+3, "MARKET", C_BG0, 7, "Arial Black");
   R("mkt_body", XL, yMkt+16, CW, 53, C_BG2, C_BORDER, 1);
   L("lb_bid", XL+6, yMkt+22, "Bid", C_SUBTEXT, 6, "Arial");
   L("vl_bid", XL+30, yMkt+22, "0.00", C_WHITE, 7, "Arial");
   L("lb_ask", XL+120, yMkt+22, "Ask", C_SUBTEXT, 6, "Arial");
   L("vl_ask", XL+144, yMkt+22, "0.00", C_WHITE, 7, "Arial");
   L("lb_spread", XL+6, yMkt+37, "Spread", C_SUBTEXT, 6, "Arial");
   L("vl_spread", XL+48, yMkt+37, "0", C_GREEN, 7, "Arial");
   L("lb_atr", XL+120, yMkt+37, "ATR", C_SUBTEXT, 6, "Arial");
   L("vl_atr", XL+144, yMkt+37, "0", C_WHITE, 7, "Arial");
   L("vl_sym", XL+6, yMkt+52, _Symbol, C_WHITE, 7, "Arial");
   L("vl_volgate", XL+120, yMkt+52, "PASS", C_GREEN, 6, "Arial");

   //--- LEFT: REGIME & HTF BIAS
   int yReg = yColTop+75;
   R("reg_hd", XL, yReg, CW, 16, C_ORANGE, C_BORDER, 1);
   L("reg_lbl", XL+6, yReg+3, "REGIME & BIAS", C_BG0, 7, "Arial Black");
   R("reg_body", XL, yReg+16, CW, 60, C_BG2, C_BORDER, 1);
   L("vl_conf", XL+6, yReg+22, "Conf: 0%", C_CYAN, 7, "Arial Black");
   L("vl_trendstrength", XL+110, yReg+22, "TS: 0", C_SUBTEXT, 6, "Arial");
   L("vl_regimetag", XL+6, yReg+37, "RANGE", C_ORANGE, 11, "Arial Black");
   L("vl_htfbias", XL+6, yReg+59, "HTF: NEUTRAL  Align:0%", C_SUBTEXT, 6, "Arial");

   //--- LEFT: STRUCTURE
   int yStruct = yColTop+157;
   R("struct_hd", XL, yStruct, CW, 16, C_HDRBAR, C_BORDER, 1);
   L("struct_lbl", XL+6, yStruct+3, "STRUCTURE", C_GOLD, 7, "Arial Black");
   R("struct_body", XL, yStruct+16, CW, 38, C_BG2, C_BORDER, 1);
   L("struct_row1", XL+6, yStruct+22, "Major:0 Minor:0 BOS:0", C_WHITE, 6, "Arial");
   L("struct_row2", XL+6, yStruct+37, "CHoCH:0 MSS:0 Prot:0", C_WHITE, 6, "Arial");

   //--- LEFT: VOLATILITY & MOMENTUM
   int yVolMom = yColTop+217;
   R("volmom_hd", XL, yVolMom, CW, 16, C'40,80,120', C_BORDER, 1);
   L("volmom_lbl", XL+6, yVolMom+3, "VOLATILITY / MOMENTUM", C_WHITE, 7, "Arial Black");
   R("volmom_body", XL, yVolMom+16, CW, 38, C_BG2, C_BORDER, 1);
   L("vl_volstate", XL+6, yVolMom+22, "NORMAL / STABLE", C_WHITE, 6, "Arial");
   L("vl_momrisk", XL+6, yVolMom+37, "Mom:50  Risk:0.5%", C_WHITE, 6, "Arial");

   //--- RIGHT: DECISION
   int yDec = yColTop;
   R("dec_hd", XR, yDec, CW, 16, C_ORANGE, C_BORDER, 1);
   L("dec_lbl", XR+6, yDec+3, "DECISION", C_BG0, 7, "Arial Black");
   R("dec_body", XR, yDec+16, CW, 26, C_DKGREEN, C_GOLD, 2);
   L("fd_text", XR+CW/2-22, yDec+22, "HOLD", C_WHITE, 12, "Arial Black");
   L("vl_router", XR+6, yDec+46, "Strategy: None", C_ORANGE, 6, "Arial");
   L("vl_healthgate", XR+6, yDec+61, "Health: OK", C_GREEN, 6, "Arial");
   L("vl_aistat", XR+110, yDec+61, "IDLE", C_ORANGE, 6, "Arial");

   //--- RIGHT: LIQUIDITY & OB
   int yLiq = yColTop+86;
   R("liq_hd", XR, yLiq, CW, 16, C'40,80,120', C_BORDER, 1);
   L("liq_lbl", XR+6, yLiq+3, "LIQUIDITY & OB QUALITY", C_WHITE, 7, "Arial Black");
   R("liq_body", XR, yLiq+16, CW, 83, C_BG2, C_BORDER, 1);
   L("vl_nextliq", XR+6, yLiq+22, "Next: --", C_GOLD, 6, "Arial");
   L("vl_obquality", XR+6, yLiq+37, "OB Quality: --", C_WHITE, 6, "Arial");
   for(int i=0;i<3;i++)
      L("liq_row"+IntegerToString(i), XR+6, yLiq+52+i*15, "--", C_SUBTEXT, 6, "Arial");

   //--- RIGHT: POSITIONS
   int yPos = yColTop+191;
   R("pos_hd", XR, yPos, CW, 16, C_HDRBAR, C_BORDER, 1);
   L("pos_lbl", XR+6, yPos+3, "POSITIONS", C_GOLD, 7, "Arial Black");
   L("vl_opcount", XR+CW-58, yPos+3, "0 open", C_ORANGE, 6, "Arial");
   R("pos_body", XR, yPos+16, CW, 38, C_BG2, C_BORDER, 1);
   L("op_row0", XR+6, yPos+22, "--", C_WHITE, 6, "Arial");
   L("vl_float", XR+6, yPos+37, "Float: 0.00", C_GREEN, 6, "Arial");

   //--- RIGHT: ACCOUNT
   int yAcc = yColTop+251;
   R("acc_hd", XR, yAcc, CW, 16, C_DKGREEN, C_GREEN, 1);
   L("acc_lb", XR+6, yAcc+3, "ACCOUNT", C_WHITE, 7, "Arial Black");
   R("acc_body", XR, yAcc+16, CW, 53, C_BG2, C_BORDER, 1);
   L("vl_bal", XR+6, yAcc+22, "Bal: 0.00", C_GREEN, 6, "Arial");
   L("vl_eq", XR+110, yAcc+22, "Eq: 0.00", C_GREEN, 6, "Arial");
   L("vl_daypl", XR+6, yAcc+37, "Day: 0.00", C_GREEN, 6, "Arial");
   L("vl_wr", XR+110, yAcc+37, "WR: 0%", C_WHITE, 6, "Arial");
   L("vl_dd", XR+6, yAcc+52, "DD: 0%", C_WHITE, 6, "Arial");
   L("vl_consec", XR+110, yAcc+52, "Losses: 0", C_SUBTEXT, 6, "Arial");

   //--- FULL WIDTH: SESSION TABS
   int yTabs = yColTop+326;
   int tabW = (DW-8)/3;
   R("tab_london", X+4, yTabs, tabW, 15, C_DGRAY, C_BORDER, 1);
   R("tab_ny",      X+4+tabW, yTabs, tabW, 15, C_DGRAY, C_BORDER, 1);
   R("tab_asia",    X+4+tabW*2, yTabs, DW-8-tabW*2, 15, C_DGRAY, C_BORDER, 1);
   L("tab_london_lbl", X+4+tabW/2-22, yTabs+3, "LONDON", C_SUBTEXT, 6, "Arial");
   L("tab_ny_lbl",      X+4+tabW+tabW/2-8, yTabs+3, "NY", C_SUBTEXT, 6, "Arial");
   L("tab_asia_lbl",    X+4+tabW*2+tabW/2-14, yTabs+3, "ASIA", C_SUBTEXT, 6, "Arial");

   //--- FOOTER
   R("ftr", X+2, Y+DH-14, DW-4, 12, C_HDRBAR, C_BORDER, 1);
   L("ft_time", X+8, Y+DH-12, "Server: --:--", C_MGRAY, 6, "Arial");
   L("ft_engine", X+DW-90, Y+DH-12, "BIE v1.0", C_MGRAY, 6, "Arial");

   ChartRedraw(0);
   Print("[BIE] Dashboard initialized at X=",X," Y=",Y," Size=",DW,"x",DH);
}

//=====================================================================
//  DASHBOARD - UPDATE
//=====================================================================
string DirToString(int d) { return d>0 ? "BULL" : (d<0 ? "BEAR" : "NEUTRAL"); }

void UpdateDash()
{
   if(!InpShowDash) return;
   if(MQLInfoInteger(MQL_TESTER) && !MQLInfoInteger(MQL_VISUAL_MODE)) return;

   double bid = SymbolInfoDouble(_Symbol,SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol,SYMBOL_ASK);
   double spread = (double)SymbolInfoInteger(_Symbol,SYMBOL_SPREAD);

   U("title_time", TimeToString(TimeCurrent(),TIME_MINUTES), C_SUBTEXT);
   U("vl_bid", DoubleToString(bid,(int)SymbolInfoInteger(_Symbol,SYMBOL_DIGITS)), C_WHITE);
   U("vl_ask", DoubleToString(ask,(int)SymbolInfoInteger(_Symbol,SYMBOL_DIGITS)), C_WHITE);
   U("vl_spread", DoubleToString(spread,0), (spread<=InpMaxSpreadPoints)?C_GREEN:C_RED);
   U("vl_atr", DoubleToString(g_vol.atrCurrent/SymbolInfoDouble(_Symbol,SYMBOL_POINT),0), C_WHITE);
   U("vl_volgate", (spread<=InpMaxSpreadPoints)?"PASS":"BLOCK", (spread<=InpMaxSpreadPoints)?C_GREEN:C_RED);

   // Regime & bias
   U("vl_conf", "Conf: "+DoubleToString(g_confidence.totalScore,0)+"%",
     g_confidence.totalScore>=InpMinConfidenceScore ? C_GREEN : C_ORANGE);
   double trendStrength = MathMax(g_mtf.h1.strength, g_mtf.h4.strength);
   U("vl_trendstrength", "TS: "+DoubleToString(trendStrength,0), C_SUBTEXT);
   color regimeColor = C_ORANGE;
   if(g_regime.regime==REGIME_STRONG_BULL || g_regime.regime==REGIME_ACCUMULATION) regimeColor=C_GREEN;
   else if(g_regime.regime==REGIME_STRONG_BEAR || g_regime.regime==REGIME_DISTRIBUTION) regimeColor=C_RED;
   else if(g_regime.regime==REGIME_NEWS_INSTABILITY) regimeColor=C_RED;
   else if(g_regime.regime==REGIME_LIQUIDITY_HUNT || g_regime.regime==REGIME_POTENTIAL_REVERSAL) regimeColor=C_PURPLE;
   else if(g_regime.regime==REGIME_VOL_EXPANSION) regimeColor=C_GOLD;
   else if(g_regime.regime==REGIME_VOL_COMPRESSION) regimeColor=C_CYAN;
   U("vl_regimetag", RegimeToString(g_regime.regime), regimeColor);
   U("vl_htfbias", "HTF: "+DirToString(g_mtf.dominantDirection)+"  Align:"+DoubleToString(g_mtf.alignment,0)+"%", C_SUBTEXT);

   // Structure
   int majorC=0,minorC=0,bosC=0,chochC=0,mssC=0,protC=0;
   for(int i=0;i<g_structCount;i++)
   {
      if(g_structure[i].isMajor) majorC++; else minorC++;
      if(g_structure[i].isBOS) bosC++;
      if(g_structure[i].isCHoCH) chochC++;
      if(g_structure[i].isMSS) mssC++;
      if(g_structure[i].isProtected) protC++;
   }
   U("struct_row1", "Major:"+IntegerToString(majorC)+" Minor:"+IntegerToString(minorC)+" BOS:"+IntegerToString(bosC), C_WHITE);
   U("struct_row2", "CHoCH:"+IntegerToString(chochC)+" MSS:"+IntegerToString(mssC)+" Prot:"+IntegerToString(protC), mssC>0?C_MAGENTA:C_WHITE);

   // Volatility & momentum
   string volStr = "";
   switch(g_vol.state) { case VOL_LOW: volStr="LOW"; break; case VOL_NORMAL: volStr="NORMAL"; break; case VOL_HIGH: volStr="HIGH"; break; default: volStr="EXTREME"; break; }
   string dynStr = "";
   switch(g_vol.dynamic) { case VOLDYN_EXPANDING: dynStr="EXPANDING"; break; case VOLDYN_COMPRESSING: dynStr="COMPRESSING"; break; case VOLDYN_SPIKE: dynStr="SPIKE"; break; default: dynStr="STABLE"; break; }
   color volColor = (g_vol.state==VOL_EXTREME) ? C_RED : (g_vol.state==VOL_HIGH ? C_ORANGE : C_WHITE);
   U("vl_volstate", volStr+" / "+dynStr, volColor);
   U("vl_momrisk", "Mom:"+DoubleToString(g_momentumScore,0)+"  Risk:"+DoubleToString(InpRiskPercentPerTrade,1)+"%", C_WHITE);

   // Decision
   bool tradeNow = g_lastDecision.tradeApproved;
   string decisionWord = tradeNow ? (g_lastDecision.direction==DIR_LONG?"BUY":"SELL") : "HOLD";
   color decisionColor = tradeNow ? (g_lastDecision.direction==DIR_LONG?C_GREEN:C_RED) : C_ORANGE;
   U("fd_text", decisionWord, decisionColor);
   color fdBg = tradeNow ? ((g_lastDecision.direction==DIR_LONG)?C_DKGREEN:C_DKRED) : C_DGRAY;
   ObjectSetInteger(0, D+"dec_body", OBJPROP_BGCOLOR, fdBg);

   ENUM_STRATEGY_TYPE routed = RouteRegimeToStrategy(g_regime.regime);
   U("vl_router", "Strategy: "+((routed==STRAT_NONE)?"None":StrategyToString(routed)), (routed==STRAT_NONE)?C_MGRAY:C_WHITE);
   int hIdx = StrategyHealthIndex(routed);
   bool healthOk = (hIdx<0||hIdx>=8) ? true : g_health[hIdx].enabled;
   U("vl_healthgate", "Health: "+(healthOk?"OK":"PAUSED"), healthOk?C_GREEN:C_RED);
   U("vl_aistat", g_statusText, g_statusColor);

   // Liquidity & OB
   double nextPrice; string nextLabel;
   int wantDir = (g_mtf.dominantDirection != 0) ? g_mtf.dominantDirection : 1;
   if(GetNearestLiquidityTarget(wantDir, nextPrice, nextLabel))
      U("vl_nextliq", "Next: "+nextLabel+" "+DoubleToString(nextPrice,(int)SymbolInfoInteger(_Symbol,SYMBOL_DIGITS)), C_GOLD);
   else
      U("vl_nextliq", "Next: --", C_SUBTEXT);

   OrderBlockEx bestOB;
   bool haveOB = GetBestOrderBlock(g_mtf.dominantDirection>=0, bestOB);
   U("vl_obquality", haveOB ? ("OB Quality: "+DoubleToString(bestOB.qualityScore,0)) : "OB Quality: --", haveOB?C_WHITE:C_SUBTEXT);

   double price = SymbolInfoDouble(_Symbol,SYMBOL_BID);
   double atrRef = g_vol.atrCurrent>0?g_vol.atrCurrent:0.0001;
   int shown = 0;
   for(int i=0;i<g_liqPoolCount && shown<3;i++)
   {
      if(g_liquidityPools[i].swept) continue;
      double distATR = MathAbs(price-g_liquidityPools[i].price)/atrRef;
      color rowColor = g_liquidityPools[i].buySide ? C'0,190,255' : C'255,150,80';
      string row = g_liquidityPools[i].label+" "+DoubleToString(distATR,1)+"atr";
      U("liq_row"+IntegerToString(shown), row, rowColor);
      shown++;
   }
   for(int i=shown;i<3;i++) U("liq_row"+IntegerToString(i), "--", C_SUBTEXT);

   // Positions
   int openCount = PositionsTotalForMagic();
   U("vl_opcount", IntegerToString(openCount)+" open", openCount>0?C_GREEN:C_ORANGE);
   string rowText = "--";
   if(openCount>0)
   {
      for(int i=PositionsTotal()-1;i>=0;i--)
      {
         if(g_pos.SelectByIndex(i) && g_pos.Magic()==InpMagicNumber && g_pos.Symbol()==_Symbol)
         {
            string typeStr = (g_pos.PositionType()==POSITION_TYPE_BUY)?"BUY":"SELL";
            rowText = typeStr+" "+DoubleToString(g_pos.Volume(),2)+" | "+DoubleToString(g_pos.Profit(),2);
            break;
         }
      }
   }
   U("op_row0", rowText, openCount>0?C_WHITE:C_SUBTEXT);
   double floatPL = GetFloatingPL();
   U("vl_float", "Float: "+(floatPL>=0?"+":"")+DoubleToString(floatPL,2), floatPL>=0?C_GREEN:C_RED);

   // Account
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   U("vl_bal", "Bal: "+DoubleToString(balance,2), C_GREEN);
   U("vl_eq", "Eq: "+DoubleToString(equity,2), C_GREEN);
   double dayPL = equity - g_risk.dayStartEquity;
   U("vl_daypl", "Day: "+(dayPL>=0?"+":"")+DoubleToString(dayPL,2), dayPL>=0?C_GREEN:C_RED);
   int totalTrades = g_sessionWins+g_sessionLosses;
   double winRate = (totalTrades>0)?(100.0*g_sessionWins/totalTrades):0.0;
   U("vl_wr", "WR: "+DoubleToString(winRate,0)+"%", winRate>=50?C_GREEN:C_ORANGE);
   U("vl_dd", "DD: "+DoubleToString(g_risk.currentDrawdownPct,1)+"%", g_risk.currentDrawdownPct>5?C_RED:C_WHITE);
   U("vl_consec", "Losses: "+IntegerToString(g_risk.consecutiveLosses), g_risk.consecutiveLosses>=InpMaxConsecutiveLosses?C_RED:C_SUBTEXT);

   // Session tabs
   color londonOn = (g_session==SESSION_LONDON_OPEN||g_session==SESSION_LONDON_MID)?C_ORANGE:C_DGRAY;
   color nyOn     = (g_session==SESSION_NY_OPEN||g_session==SESSION_NY_PM)?C_ORANGE:C_DGRAY;
   color asiaOn   = (g_session==SESSION_ASIAN)?C_ORANGE:C_DGRAY;
   ObjectSetInteger(0, D+"tab_london", OBJPROP_BGCOLOR, londonOn);
   ObjectSetInteger(0, D+"tab_ny", OBJPROP_BGCOLOR, nyOn);
   ObjectSetInteger(0, D+"tab_asia", OBJPROP_BGCOLOR, asiaOn);
   U("tab_london_lbl","LONDON",(londonOn==C_ORANGE)?C_BG0:C_SUBTEXT);
   U("tab_ny_lbl","NY",(nyOn==C_ORANGE)?C_BG0:C_SUBTEXT);
   U("tab_asia_lbl","ASIA",(asiaOn==C_ORANGE)?C_BG0:C_SUBTEXT);

   U("ft_time", "Server: "+TimeToString(TimeCurrent(),TIME_MINUTES), C_DGRAY);
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
   if(InpLiquidityLookback > 60) { Print("ERROR: InpLiquidityLookback max 60. Current: ", InpLiquidityLookback); return INIT_PARAMETERS_INCORRECT; }

   ApplyBlackChartTheme();

   if(StringFind(_Symbol,"BTC")<0 && StringFind(_Symbol,"XBT")<0)
      Print("[BIE] WARNING: This EA is tuned for BTCUSD. Current symbol: ", _Symbol, " - inputs may not be optimal.");

   g_trade.SetExpertMagicNumber(InpMagicNumber);
   g_trade.SetDeviationInPoints(InpMaxSlippagePoints);
   g_trade.SetTypeFilling(GetFillMode());

   // Indicator handles per TF slot (EMA fast/slow + ATR)
   bool handleError = false;
   for(int i = 0; i < TF_COUNT; i++)
   {
      g_emaFast[i] = iMA(_Symbol, g_tfMap[i], InpEMAFastPeriod, 0, MODE_EMA, PRICE_CLOSE);
      g_emaSlow[i] = iMA(_Symbol, g_tfMap[i], InpEMASlowPeriod, 0, MODE_EMA, PRICE_CLOSE);
      g_atrHandle[i] = iATR(_Symbol, g_tfMap[i], InpATRPeriod);
      if(g_emaFast[i]==INVALID_HANDLE || g_emaSlow[i]==INVALID_HANDLE || g_atrHandle[i]==INVALID_HANDLE) handleError = true;
   }
   g_rsiHandle  = iRSI(_Symbol, PERIOD_M5, 14, PRICE_CLOSE);
   g_adxHandle  = iADX(_Symbol, PERIOD_M5, 14);
   g_macdHandle = iMACD(_Symbol, PERIOD_M5, 12, 26, 9, PRICE_CLOSE);
   if(g_rsiHandle==INVALID_HANDLE || g_adxHandle==INVALID_HANDLE || g_macdHandle==INVALID_HANDLE) handleError = true;

   if(handleError) { Print("ERROR: Indicator handle creation failed"); return INIT_FAILED; }

   g_dayStart = DayStart(TimeCurrent());
   g_weekStart = WeekStart(TimeCurrent());

   InitRiskState();
   InitStrategyHealth();

   g_regime.regime = REGIME_RANGE;
   g_regime.confidence = 0;
   g_regime.stability = 0;
   g_regime.sinceTime = TimeCurrent();
   g_regime.previousRegime = REGIME_RANGE;

   g_confidence.totalScore = 0;
   g_confidence.approved = false;
   g_confidence.rejectReason = "Not yet calculated";

   if(InpShowDash) InitDash();

   EventSetTimer(1);

   g_statusText = "WARMING UP";
   g_statusColor = C_ORANGE;
   g_lastAction = "Building buffers...";

   Print("=== BTC INSTITUTIONAL EA v1.0 ===");
   Print("Symbol: ", _Symbol, " | Magic: ", InpMagicNumber, " | Base Risk: ", InpRiskPercentPerTrade, "%");
   Print("Min Confidence: ", InpMinConfidenceScore, "% | Min Regime Confidence: ", InpMinRegimeConfidence, "%");
   Print("Dashboard: ", InpShowDash?"ENABLED":"DISABLED", " | Black Theme: ", InpEnableBlackTheme?"ON":"OFF");
   Print("Balance: $", AccountInfoDouble(ACCOUNT_BALANCE), " | Equity: $", AccountInfoDouble(ACCOUNT_EQUITY));

   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
   Print("=== BTC INSTITUTIONAL EA SESSION SUMMARY ===");
   Print("Trades: ", g_tradesToday, " | P&L: ", DoubleToString(g_sessionProfit,2));
   Print("WR: ", (g_sessionWins+g_sessionLosses>0) ? DoubleToString(100.0*g_sessionWins/(g_sessionWins+g_sessionLosses),1) : "0", "%");
   for(int i=0;i<8;i++)
      Print(g_health[i].name, ": ", g_health[i].totalTrades, " trades | WR=", DoubleToString(g_health[i].winRate,1), "% | Exp=", DoubleToString(g_health[i].expectancyR,2), "R");

   EventKillTimer();
   DeleteDash();
   ObjectsDeleteAll(0, OV);

   for(int i=0;i<TF_COUNT;i++)
   {
      IndicatorRelease(g_emaFast[i]);
      IndicatorRelease(g_emaSlow[i]);
      IndicatorRelease(g_atrHandle[i]);
   }
   IndicatorRelease(g_rsiHandle);
   IndicatorRelease(g_adxHandle);
   IndicatorRelease(g_macdHandle);
}

void OnTimer()
{
   if(g_lastCloseTime > 0)
   {
      int elapsed = (int)(TimeCurrent()-g_lastCloseTime);
      g_inCooldown = (elapsed < InpCooldownAfterCloseSec);
   }
   if(InpShowDash) UpdateDash();
}

void OnTick()
{
   if(g_lastCloseTime > 0)
   {
      int elapsed = (int)(TimeCurrent()-g_lastCloseTime);
      g_inCooldown = (elapsed < InpCooldownAfterCloseSec);
   }

   RolloverDailyWeeklyIfNeeded();

   if(Bars(_Symbol,PERIOD_MN1) < 3 || Bars(_Symbol,PERIOD_W1) < 5 ||
      Bars(_Symbol,PERIOD_D1) < InpEMASlowPeriod+5 || Bars(_Symbol,PERIOD_H4) < InpEMASlowPeriod+5 ||
      Bars(_Symbol,PERIOD_H1) < InpEMASlowPeriod+5 || Bars(_Symbol,PERIOD_M15) < InpEMASlowPeriod+5 ||
      Bars(_Symbol,PERIOD_M5) < InpATRLookback+5)
   {
      g_statusText = "BUFFERING"; g_statusColor = C_ORANGE;
      return;
   }

   bool isNewBar = IsNewBar();
   UpdateRiskState();

   if(HasManagedPosition())
   {
      ManageOpenPositions();
      g_statusText = "IN TRADE"; g_statusColor = C_GREEN;
      return;
   }

   if(isNewBar || TimeCurrent()-g_lastFullUpdate > 60)
   {
      UpdateSessionIntelligence();
      UpdateMTFNarrative();
      UpdateVolatilityIntelligence();
      UpdateNewsShockProxy();
      UpdateLiquidityStructure();       // equal highs/lows (g_eq) - needed by liquidity pool ranking below
      UpdatePremiumDiscountZone();       // needed by order block quality scoring below
      DetectMarketStructure();           // needed by order block breaker detection and structure scoring
      DetectOrderBlocks();               // depends on g_structCount + g_pdZone, both now fresh
      DetectFairValueGaps();
      BuildLiquidityPoolRanking();       // depends on g_eq + session anchor, both now fresh
      UpdateSessionVWAP();
      UpdateMomentumScore();
      UpdateRegimeClassification();      // depends on g_liquidityPools (RS_LiquidityHunt) - now fresh this cycle
      UpdateAllOverlays();                // pure drawing pass - all detection already fresh above
      g_lastFullUpdate = TimeCurrent();
   }

   RunMasterDecisionCycle();
}

void OnTradeTransaction(const MqlTradeTransaction &trans, const MqlTradeRequest &request, const MqlTradeResult &result)
{
   OnTradeTransactionHandler(trans, request, result);
}
