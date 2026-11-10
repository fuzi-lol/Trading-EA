//+------------------------------------------------------------------+
//|                                QUANTUM_PLUS_SYSTEMATIC_EA_v9.mq5 |
//|                                  Copyright 2026, FXBotHub Systems|
//|                                             https://fxbothub.com |
//+------------------------------------------------------------------+
#property copyright   "Copyright 2026, FXBotHub Systems"
#property link        "https://fxbothub.com"
#property version     "9.00"
#property description "Institutional Multi-Layer Quantitative XAUUSD Scalping System - NEURA AI DASHBOARD"
#property strict

#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>

//+------------------------------------------------------------------+
//| SYSTEM DEFINITIONS & CONSTANTS                                   |
//+------------------------------------------------------------------+
#define MAX_LIQUIDITY_ZONES  100
#define MAX_FVG_ZONES        100
#define TICK_BUFFER_SIZE     50
#define STRATEGY_COUNT       5
#define DASH_PREFIX          "SYS_Q_PLUS_"

// --- Luxury "Neura AI" dashboard palette --------------------------
#define CLR_PANEL_BG       C'6,10,20'        // deep midnight-blue / near-black
#define CLR_PANEL_BG2      C'10,16,30'
#define CLR_NEON_CYAN      C'0,229,255'
#define CLR_NEON_MAGENTA   C'255,0,170'
#define CLR_GOLD           C'255,200,60'
#define CLR_GLASS_GREEN    C'0,255,170'
#define CLR_TEXT_DIM       C'140,160,190'
#define CLR_TEXT_BRIGHT    clrWhite
#define CLR_WARN_RED       C'255,70,70'

//+------------------------------------------------------------------+
//| SYSTEM PIPELINE ENUMS                                            |
//+------------------------------------------------------------------+
enum ENUM_MARKET_STATE
{
   STATE_TREND_EXPANSION,
   STATE_TREND_CONTINUATION,
   STATE_TREND_EXHAUSTION,
   STATE_RANGE_ACCUMULATION,
   STATE_RANGE_DISTRIBUTION,
   STATE_VOLATILITY_EXPANSION,
   STATE_VOLATILITY_CONTRACTION,
   STATE_LIQUIDITY_HUNT,
   STATE_TRANSITION,
   STATE_UNDEFINED
};

enum ENUM_VOL_STATE
{
   VOL_SUPPRESSED,
   VOL_NORMAL,
   VOL_EXPANDING,
   VOL_EXTREME,
   VOL_CHAOTIC
};

enum ENUM_STRUCT_CLASS
{
   STRUCTURE_BULL,
   STRUCTURE_BEAR,
   STRUCTURE_TRANSITION,
   STRUCTURE_RANGE
};

enum ENUM_STRATEGY_TYPE
{
   STRAT_TREND_CONTINUATION,
   STRAT_RANGE_REVERSION,
   STRAT_LIQUIDITY_SWEEP,
   STRAT_VOLATILITY_BREAKOUT,
   STRAT_TREND_EXHAUSTION,
   STRAT_STAND_ASIDE
};

enum ENUM_SIGNAL
{
   SIGNAL_BUY  =  1,
   SIGNAL_SELL = -1,
   SIGNAL_NONE =  0
};

//+------------------------------------------------------------------+
//| PIPELINE RETURN STRUCTURES                                       |
//+------------------------------------------------------------------+
struct MarketStateResult
{
   ENUM_MARKET_STATE State;
   double Confidence;
};

struct LiquidityZone
{
   double Price;
   double Strength;
   datetime Created;
   bool Swept;
   int Touches;
   string LevelType;
};

struct FairValueGap
{
   double UpperBound;
   double LowerBound;
   double Size;
   bool Filled;
   double QualityScore;
   datetime Created;
};

struct STRUCT_ORDERFLOW
{
   double AggressionScore;
   double BullishPressure;
   double BearishPressure;
   string Dominance;
   bool   SyntheticVolume;   // true = broker feed has no real tick volume (proxy only)
};

struct STRUCT_SESSION_PROB
{
   double ExpansionProbability;
   double ContinuationProbability;
   double ReversalProbability;
   string SessionName;
};

struct STRUCT_STRATEGY_STATS
{
   int TotalTrades;
   int Wins;
   double NetProfit;
   double ProfitFactor;
   double WinRate;
   bool IsDisabled;
   double AllocationScale;
};

struct STRUCT_KALMAN_FILTER
{
   double estimate;
   double error_cov;
   double process_noise;
   double measure_noise;
   double gain;
};

//+------------------------------------------------------------------+
//| SYSTEM INPUT PARAMETERS                                          |
//+------------------------------------------------------------------+
input group "=== 1. SYSTEM IDENTITY ==="
input ulong   InpMagicNumber       = 888111;
input string  InpTradeComment      = "Quantum_Plus_Scalper";

input group "=== 2. MATHEMATICAL KALMAN NOISE ==="
input double  InpProcessNoise      = 0.001;
input double  InpMeasureNoise      = 0.1;

input group "=== 3. VOLATILITY ENGINE ==="
input int     InpATRPeriod         = 14;
input int     InpPercentilePeriod  = 200;

input group "=== 4. SYSTEM PIPELINE THRESHOLDS ==="
input double  InpMinFusionScore      = 58.0;   // BASELINE only - actual gate is now adaptive, see AdaptiveMinFusionScore()
input double  InpAdaptiveBandWidth   = 14.0;   // How far the adaptive gate can move from baseline in either direction
input double  InpMaxSpreadPercentile = 90.0;
input int     InpMaxExecutionLatencyMs = 200;

input group "=== 5. ADAPTIVE SENSITIVITY ==="
input double  InpStateSensitivity    = 1.0;
input double  InpMomentumBias        = 1.5;

input group "=== 6. BASE RISK MANAGEMENT ==="
input double  InpBaseRiskPercent   = 1.0;
input double  InpMaxDailyDrawdownPct = 3.0;     // NOW ENFORCED: hard daily capital preservation halt
input int     InpMaxTradesPerDay   = 14;        // RAISED: a real scalper takes the entries the market offers, not an arbitrary daily cap
input int     InpMaxConsecutiveLosses = 4;      // RAISED slightly: 3 was cutting off viable sessions on normal variance
input int     InpCooldownMinutes   = 30;        // SHORTENED: long cooldowns mean missing the next real setup, not just avoiding tilt

input group "=== 6b. ACCOUNT-ADAPTIVE SL/TP/LOT SCALING ==="
input double  InpReferenceEquity     = 1000.0;  // Equity at which scale factor = 1.0 (baseline)
input double  InpScalingExponent     = 0.30;    // Sub-linear growth: small accounts get tight SL/TP, big accounts get wider, without exploding lot risk
input double  InpMinScaleFactor      = 0.35;    // Floor: even a $10 account keeps a sane minimum SL/TP distance
input double  InpMaxScaleFactor      = 3.0;     // Ceiling: prevents runaway SL/TP distance on very large accounts
input double  InpBaseATRMultiplier   = 2.0;     // Base SL = ATR * this, before equity scaling is applied
input double  InpBaseMinSLPoints     = 150.0;   // Base SL floor (points) before equity scaling is applied
input double  InpMaxAcceptableRiskMultiple = 2.0; // Safety: if broker min-lot forces risk above (BaseRisk% * this), the trade is skipped

input group "=== 7. GOLD SCALPING MICROSTRUCTURE FILTERS ==="
input bool    InpUseRolloverFilter   = true;    // Block trading during broker rollover spread spike
input int     InpRolloverStartHour   = 23;      // Broker time
input int     InpRolloverEndHourMin  = 30;      // minutes past 00:xx broker time considered rollover
input bool    InpUseNewsBlackout     = true;    // Manual high-impact news blackout window(s)
input string  InpNewsBlackoutHoursUTC= "13:25-13:35,14:55-15:05"; // comma list HH:MM-HH:MM (NFP/CPI/FOMC style)
input bool    InpUseHTFTrendFilter   = true;    // Require H1 EMA trend alignment for trend strategies
input int     InpHTFEmaPeriod        = 50;

input group "=== 8. TRADE LIFECYCLE / SCALP EXITS ==="
input bool    InpUsePartialClose     = true;
input double  InpPartialClosePct     = 50.0;    // % of position closed at 1R
input bool    InpUseTimeStop         = true;
input int     InpMaxHoldMinutes      = 90;       // scalp time-stop: exit if no progress
input double  InpTimeStopMinRProgress= 0.3;      // if profit < 0.3R after MaxHoldMinutes, exit

input group "=== 9. DASHBOARD ==="
input bool    InpShowDashboard       = true;
input bool    InpApplyChartTheme     = true;

//+------------------------------------------------------------------+
//| GLOBAL SYSTEM CORE STORAGE                                       |
//+------------------------------------------------------------------+
CTrade                g_Trade;
CPositionInfo         g_Pos;
STRUCT_KALMAN_FILTER  g_KFast;
STRUCT_KALMAN_FILTER  g_KSlow;

LiquidityZone         g_LiquidityMap[MAX_LIQUIDITY_ZONES];
int                   g_TotalLiquidityZones = 0;
FairValueGap          g_FVGMap[MAX_FVG_ZONES];
int                   g_TotalFVGZones       = 0;
STRUCT_STRATEGY_STATS g_StrategyHealth[STRATEGY_COUNT];

MqlTick               g_TickBuffer[TICK_BUFFER_SIZE];
int                   g_TickCount           = 0;
int                   g_TickFilled          = 0;     // FIX: tracks how many slots are genuinely valid
double                g_HistoricalSpreads[];

MarketStateResult     g_CurrentState;
ENUM_VOL_STATE        g_CurrentVolState;
double                g_VolCompositeIndex   = 0.0;
ENUM_STRUCT_CLASS     g_CurrentStructure;
double                g_StructureStrength   = 0.0;
STRUCT_ORDERFLOW      g_CurrentOrderFlow;
STRUCT_SESSION_PROB   g_CurrentSessionProb;
double                g_FinalFusionScore    = 0.0;
ENUM_STRATEGY_TYPE    g_LastChosenStrategy  = STRAT_STAND_ASIDE;
string                g_FinalDecisionText   = "HOLD";

// Risk-guard state
double                g_DayStartEquity      = 0.0;
datetime              g_CurrentDay          = 0;
int                   g_TradesToday         = 0;
int                   g_ConsecutiveLosses   = 0;
datetime              g_CooldownUntil       = 0;
bool                  g_DailyHaltActive     = false;
ulong                 g_LastSignalTickMs    = 0;

// Lifecycle helper
bool                  g_PartialDoneForTicket[]; // parallel storage keyed by ticket via array below
ulong                 g_PartialTickets[];

// Indicators
int                   g_hATR                = INVALID_HANDLE;
int                   g_hHTF_EMA            = INVALID_HANDLE;

//+------------------------------------------------------------------+
//| CHART THEME ENGINE (candlestick chart - BTC/Gold scalping style) |
//+------------------------------------------------------------------+
void ApplyProfessionalTheme()
{
   long chart_id = ChartID();

   ChartSetInteger(chart_id, CHART_MODE,               CHART_CANDLES);
   ChartSetInteger(chart_id, CHART_COLOR_BACKGROUND,   clrBlack);
   ChartSetInteger(chart_id, CHART_COLOR_FOREGROUND,   clrWhite);
   ChartSetInteger(chart_id, CHART_COLOR_GRID,         clrBlack);

   ChartSetInteger(chart_id, CHART_COLOR_CANDLE_BULL,  clrLime);
   ChartSetInteger(chart_id, CHART_COLOR_CANDLE_BEAR,  clrRed);
   ChartSetInteger(chart_id, CHART_COLOR_CHART_UP,     clrLime);
   ChartSetInteger(chart_id, CHART_COLOR_CHART_DOWN,   clrRed);
   ChartSetInteger(chart_id, CHART_COLOR_VOLUME,       clrAqua);
   ChartSetInteger(chart_id, CHART_COLOR_BID,          clrLime);
   ChartSetInteger(chart_id, CHART_COLOR_ASK,          clrRed);
   ChartSetInteger(chart_id, CHART_COLOR_STOP_LEVEL,   clrYellow);

   ChartSetInteger(chart_id, CHART_SHOW_GRID,          false);
   ChartSetInteger(chart_id, CHART_SHOW_VOLUMES,       true);
   ChartSetInteger(chart_id, CHART_SHOW_OHLC,          true);
   ChartSetInteger(chart_id, CHART_SHOW_ASK_LINE,      false);
   ChartSetInteger(chart_id, CHART_SHOW_BID_LINE,      false);
   ChartSetInteger(chart_id, CHART_SHOW_TRADE_LEVELS,  true);
   ChartSetInteger(chart_id, CHART_SHIFT,              true);
   ChartSetInteger(chart_id, CHART_AUTOSCROLL,         true);

   ChartRedraw(chart_id);
}

//+------------------------------------------------------------------+
//| INITIALIZATION PIPELINE                                          |
//+------------------------------------------------------------------+
int OnInit()
{
   if(InpApplyChartTheme) ApplyProfessionalTheme();

   g_Trade.SetExpertMagicNumber(InpMagicNumber);
   g_Trade.SetDeviationInPoints(15);
   g_Trade.SetTypeFilling(ORDER_FILLING_FOK);

   g_hATR = iATR(_Symbol, _Period, InpATRPeriod);
   if(g_hATR == INVALID_HANDLE) return INIT_FAILED;

   g_hHTF_EMA = iMA(_Symbol, PERIOD_H1, InpHTFEmaPeriod, 0, MODE_EMA, PRICE_CLOSE);
   if(g_hHTF_EMA == INVALID_HANDLE) return INIT_FAILED;

   double startPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   g_KFast.estimate = startPrice; g_KFast.error_cov = 1.0; g_KFast.process_noise = InpProcessNoise; g_KFast.measure_noise = InpMeasureNoise;
   g_KSlow.estimate = startPrice; g_KSlow.error_cov = 1.0; g_KSlow.process_noise = InpProcessNoise * 0.05; g_KSlow.measure_noise = InpMeasureNoise * 4.0;

   ArrayResize(g_HistoricalSpreads, 1000);
   ArrayInitialize(g_HistoricalSpreads, 0.0);
   ZeroMemory(g_LiquidityMap);
   ZeroMemory(g_FVGMap);

   for(int i=0; i<STRATEGY_COUNT; i++)
   {
      g_StrategyHealth[i].TotalTrades = 0;
      g_StrategyHealth[i].Wins = 0;
      g_StrategyHealth[i].NetProfit = 0.0;
      g_StrategyHealth[i].ProfitFactor = 1.5;
      g_StrategyHealth[i].WinRate = 0.50;
      g_StrategyHealth[i].IsDisabled = false;
      g_StrategyHealth[i].AllocationScale = 1.0;
   }

   BuildInitialLiquidityMap();
   ScanFairValueGaps();

   g_DayStartEquity = AccountInfoDouble(ACCOUNT_EQUITY);
   g_CurrentDay     = TimeCurrent() - (TimeCurrent() % 86400);

   if(InpShowDashboard) EventSetTimer(1); // 1-second dashboard refresh independent of ticks

   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
   if(g_hATR != INVALID_HANDLE) IndicatorRelease(g_hATR);
   if(g_hHTF_EMA != INVALID_HANDLE) IndicatorRelease(g_hHTF_EMA);
   EventKillTimer();
   ObjectsDeleteAll(0, DASH_PREFIX);
}

void OnTimer()
{
   if(InpShowDashboard) DrawDashboard();
}

//+------------------------------------------------------------------+
//| EXPLICIT SYSTEMATIC PIPELINE CORE                                |
//+------------------------------------------------------------------+
void OnTick()
{
   ulong tickStartMs = GetTickCount64();

   ResetDailyCountersIfNewDay();

   if(!ObserveMarket()) return;

   // LAYER 0: Capital preservation circuit breaker (FIX: input was previously dead/unused)
   if(CheckDailyDrawdownHalt())
   {
      g_FinalDecisionText = "HALT - DD LIMIT";
      return;
   }

   // LAYER 0b: Consecutive-loss cooldown
   if(TimeCurrent() < g_CooldownUntil)
   {
      g_FinalDecisionText = "COOLDOWN";
      return;
   }

   // LAYER 0c: Microstructure blackout filters (rollover spread spike + manual news windows)
   if(InGoldScalpingBlackout())
   {
      g_FinalDecisionText = "BLACKOUT WINDOW";
      ManageOpenPositionsOnly();
      return;
   }

   g_CurrentState = ClassifyMarketState();
   AnalyzeLiquidity();
   AnalyzeVolatility();
   AnalyzeMarketStructure();
   EstimateOrderFlow();
   g_FinalFusionScore = CalculateFusionScore();

   ENUM_STRATEGY_TYPE chosenStrategy = MetaRouter();
   g_LastChosenStrategy = chosenStrategy;

   if(chosenStrategy == STRAT_STAND_ASIDE)
   {
      g_FinalDecisionText = "HOLD";
      ManageOpenPositionsOnly();
      return;
   }

   if(IsPositionOpen())
   {
      ManageLifecycle();
      return;
   }

   if(g_TradesToday >= InpMaxTradesPerDay)
   {
      g_FinalDecisionText = "DAILY TRADE CAP";
      return;
   }

   double calculatedRisk = AllocateRisk(chosenStrategy);
   if(calculatedRisk <= 0) return;

   if(!VerifyExecutionQuality()) return;

   // LAYER 9b: Execution latency gate (FIX: input now enforced, was previously declared & ignored)
   ulong elapsedMs = GetTickCount64() - tickStartMs;
   if(elapsedMs > (ulong)InpMaxExecutionLatencyMs)
   {
      Print("[LATENCY GATE] Execution aborted. Pipeline latency ", elapsedMs, "ms exceeded limit.");
      return;
   }

   ExecuteRoutedStrategy(chosenStrategy, calculatedRisk);
}

void ManageOpenPositionsOnly()
{
   if(IsPositionOpen()) ManageLifecycle();
}

//+------------------------------------------------------------------+
//| RISK GUARD SUBSYSTEM                                             |
//+------------------------------------------------------------------+
void ResetDailyCountersIfNewDay()
{
   datetime today = TimeCurrent() - (TimeCurrent() % 86400);
   if(today != g_CurrentDay)
   {
      g_CurrentDay      = today;
      g_DayStartEquity  = AccountInfoDouble(ACCOUNT_EQUITY);
      g_TradesToday     = 0;
      g_DailyHaltActive = false;
      // Note: consecutive-loss streak intentionally persists across midnight; cooldown is time-based, not day-based.
   }
}

bool CheckDailyDrawdownHalt()
{
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   if(g_DayStartEquity <= 0) return false;
   double ddPct = (g_DayStartEquity - equity) / g_DayStartEquity * 100.0;
   if(ddPct >= InpMaxDailyDrawdownPct)
   {
      if(!g_DailyHaltActive)
      {
         Print("[RISK GUARD] Daily drawdown limit hit (", DoubleToString(ddPct,2), "%). Trading halted until next session day.");
         g_DailyHaltActive = true;
      }
      return true;
   }
   return false;
}

void RegisterTradeResult(bool isWin)
{
   g_TradesToday++;
   if(isWin)
   {
      g_ConsecutiveLosses = 0;
   }
   else
   {
      g_ConsecutiveLosses++;
      if(g_ConsecutiveLosses >= InpMaxConsecutiveLosses)
      {
         g_CooldownUntil = TimeCurrent() + InpCooldownMinutes * 60;
         Print("[RISK GUARD] Consecutive loss limit reached. Cooldown active for ", InpCooldownMinutes, " minutes.");
         g_ConsecutiveLosses = 0;
      }
   }
}

//+------------------------------------------------------------------+
//| GOLD MICROSTRUCTURE BLACKOUT FILTERS                             |
//+------------------------------------------------------------------+
bool InGoldScalpingBlackout()
{
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);

   // --- Rollover spread-spike window (broker time) ---
   if(InpUseRolloverFilter)
   {
      if(dt.hour == InpRolloverStartHour) return true;
      if(dt.hour == 0 && dt.min <= InpRolloverEndHourMin) return true;
   }

   // --- Manual high-impact news blackout windows (UTC, comma separated HH:MM-HH:MM) ---
   if(InpUseNewsBlackout)
   {
      MqlDateTime utc;
      TimeToStruct(TimeGMT(), utc);
      int nowMinutes = utc.hour * 60 + utc.min;

      string windows[];
      int count = StringSplit(InpNewsBlackoutHoursUTC, ',', windows);
      for(int i=0; i<count; i++)
      {
         string w = windows[i];
         StringTrimLeft(w); StringTrimRight(w);
         int dash = StringFind(w, "-");
         if(dash < 0) continue;
         string startS = StringSubstr(w, 0, dash);
         string endS   = StringSubstr(w, dash+1);
         int sH, sM, eH, eM;
         if(!ParseHHMM(startS, sH, sM)) continue;
         if(!ParseHHMM(endS, eH, eM)) continue;
         int startMin = sH*60 + sM;
         int endMin   = eH*60 + eM;
         if(nowMinutes >= startMin && nowMinutes <= endMin) return true;
      }
   }

   return false;
}

bool ParseHHMM(const string s, int &h, int &m)
{
   int colon = StringFind(s, ":");
   if(colon < 0) return false;
   h = (int)StringToInteger(StringSubstr(s, 0, colon));
   m = (int)StringToInteger(StringSubstr(s, colon+1));
   return true;
}

//+------------------------------------------------------------------+
//| LAYER 1: MARKET OBSERVATION LAYER                                |
//+------------------------------------------------------------------+
bool ObserveMarket()
{
   MqlTick tick;
   if(!SymbolInfoTick(_Symbol, tick)) return false;

   if(g_TickCount >= TICK_BUFFER_SIZE)
   {
      for(int i=0; i<TICK_BUFFER_SIZE-1; i++) g_TickBuffer[i] = g_TickBuffer[i+1];
      g_TickBuffer[TICK_BUFFER_SIZE-1] = tick;
   }
   else
   {
      g_TickBuffer[g_TickCount] = tick;
      g_TickCount++;
   }
   g_TickFilled = MathMin(g_TickCount, TICK_BUFFER_SIZE); // FIX: explicit valid-slot tracker

   int totalSpreads = ArraySize(g_HistoricalSpreads);
   for(int i=0; i<totalSpreads-1; i++) g_HistoricalSpreads[i] = g_HistoricalSpreads[i+1];
   g_HistoricalSpreads[totalSpreads-1] = (tick.ask - tick.bid) / _Point;

   g_KFast.error_cov += g_KFast.process_noise;
   g_KFast.gain = g_KFast.error_cov / (g_KFast.error_cov + g_KFast.measure_noise);
   g_KFast.estimate = g_KFast.estimate + g_KFast.gain * (tick.bid - g_KFast.estimate);
   g_KFast.error_cov = (1.0 - g_KFast.gain) * g_KFast.error_cov;

   g_KSlow.error_cov += g_KSlow.process_noise;
   g_KSlow.gain = g_KSlow.error_cov / (g_KSlow.error_cov + g_KSlow.measure_noise);
   g_KSlow.estimate = g_KSlow.estimate + g_KSlow.gain * (tick.bid - g_KSlow.estimate);
   g_KSlow.error_cov = (1.0 - g_KSlow.gain) * g_KSlow.error_cov;

   return (g_TickCount >= 5);
}

//+------------------------------------------------------------------+
//| LAYER 2: INSTITUTIONAL MARKET STATE ENGINE                       |
//+------------------------------------------------------------------+
MarketStateResult ClassifyMarketState()
{
   MarketStateResult res;
   res.State = STATE_UNDEFINED;
   res.Confidence = 0.0;

   double fast = g_KFast.estimate;
   double slow = g_KSlow.estimate;
   double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);

   double atr = 0.0; double atrBuf[1];
   if(CopyBuffer(g_hATR, 0, 0, 1, atrBuf) == 1) atr = atrBuf[0];
   if(atr <= 0) atr = 200 * _Point;

   double trendThreshold   = (atr * 0.8 * InpStateSensitivity) / _Point;
   double exhaustThreshold = (atr * 1.5 * InpStateSensitivity) / _Point;

   double devFastSlow = MathAbs(fast - slow) / _Point;
   double devPriceFast = (currentPrice - fast) / _Point;

   double trendScore   = (devFastSlow > trendThreshold) ? 60.0 : 0.0;
   double exhaustScore = (MathAbs(devPriceFast) > exhaustThreshold) ? 70.0 : 0.0;
   double rangeScore   = (devFastSlow <= trendThreshold) ? 50.0 : 0.0;

   if(exhaustScore > trendScore && exhaustScore > rangeScore)
   {
      res.State = STATE_TREND_EXHAUSTION;
      res.Confidence = exhaustScore;
   }
   else if(trendScore > rangeScore)
   {
      res.State = ((currentPrice - fast) * (fast - slow) > 0) ? STATE_TREND_EXPANSION : STATE_TREND_CONTINUATION;
      res.Confidence = trendScore;
   }
   else
   {
      res.State = (fast > slow) ? STATE_RANGE_DISTRIBUTION : STATE_RANGE_ACCUMULATION;
      res.Confidence = rangeScore;
   }

   return res;
}

//+------------------------------------------------------------------+
//| LAYER 3: INSTITUTIONAL LIQUIDITY INTELLIGENCE ENGINE             |
//+------------------------------------------------------------------+
void BuildInitialLiquidityMap()
{
   g_TotalLiquidityZones = 0;
   MqlRates dailyRates[];
   if(CopyRates(_Symbol, PERIOD_D1, 1, 10, dailyRates) > 0)
   {
      for(int i=0; i<ArraySize(dailyRates); i++)
      {
         // FIX: bounds-check BEFORE each individual write (original could overflow array by 1 on the high-write)
         if(g_TotalLiquidityZones >= MAX_LIQUIDITY_ZONES) break;
         g_LiquidityMap[g_TotalLiquidityZones].Price = dailyRates[i].high;
         g_LiquidityMap[g_TotalLiquidityZones].Strength = 75.0;
         g_LiquidityMap[g_TotalLiquidityZones].Created = dailyRates[i].time;
         g_LiquidityMap[g_TotalLiquidityZones].Swept = false;
         g_LiquidityMap[g_TotalLiquidityZones].Touches = 0;
         g_LiquidityMap[g_TotalLiquidityZones].LevelType = "Daily_High";
         g_TotalLiquidityZones++;

         if(g_TotalLiquidityZones >= MAX_LIQUIDITY_ZONES) break;
         g_LiquidityMap[g_TotalLiquidityZones].Price = dailyRates[i].low;
         g_LiquidityMap[g_TotalLiquidityZones].Strength = 75.0;
         g_LiquidityMap[g_TotalLiquidityZones].Created = dailyRates[i].time;
         g_LiquidityMap[g_TotalLiquidityZones].Swept = false;
         g_LiquidityMap[g_TotalLiquidityZones].Touches = 0;
         g_LiquidityMap[g_TotalLiquidityZones].LevelType = "Daily_Low";
         g_TotalLiquidityZones++;
      }
   }
}

void AnalyzeLiquidity()
{
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);

   for(int i=0; i<g_TotalLiquidityZones; i++)
   {
      if(g_LiquidityMap[i].Swept) continue;

      if(g_LiquidityMap[i].LevelType == "Daily_High" && ask >= g_LiquidityMap[i].Price)
      {
         g_LiquidityMap[i].Swept = true;
         continue;
      }
      if(g_LiquidityMap[i].LevelType == "Daily_Low" && bid <= g_LiquidityMap[i].Price)
      {
         g_LiquidityMap[i].Swept = true;
         continue;
      }

      double dist = MathAbs(bid - g_LiquidityMap[i].Price) / _Point;
      double proximityScore = (dist > 500.0) ? 10.0 : (1.0 - (dist / 500.0)) * 50.0;
      double structuralAgeWeight = (double)(TimeCurrent() - g_LiquidityMap[i].Created) / 86400.0;
      double ageScore = MathMax(0.0, 30.0 - (structuralAgeWeight * 2.0));

      g_LiquidityMap[i].Strength = NormalizeDouble(proximityScore + ageScore + (g_LiquidityMap[i].Touches * 10.0), 2);
      g_LiquidityMap[i].Strength = MathMin(MathMax(g_LiquidityMap[i].Strength, 0.0), 100.0);
   }
}

//+------------------------------------------------------------------+
//| LAYER 4: ADAPTIVE VOLATILITY INTELLIGENCE ENGINE                 |
//+------------------------------------------------------------------+
void AnalyzeVolatility()
{
   double atr = 0.0;
   double atrBuffer[1];
   if(CopyBuffer(g_hATR, 0, 0, 1, atrBuffer) == 1) atr = atrBuffer[0];
   else return;

   if(g_TickFilled < 2) return; // FIX: need at least 2 valid samples for a velocity delta

   double currentPrice = g_TickBuffer[g_TickFilled-1].bid;
   double startPrice   = g_TickBuffer[0].bid; // FIX: g_TickBuffer[0] is now guaranteed valid via g_TickFilled gating
   double tickVelocity = MathAbs(currentPrice - startPrice) / _Point;

   g_VolCompositeIndex = (atr / _Point) * 0.6 + (tickVelocity * 4.0) * 0.4;

   if(g_VolCompositeIndex < 50.0)       g_CurrentVolState = VOL_SUPPRESSED;
   else if(g_VolCompositeIndex < 150.0) g_CurrentVolState = VOL_NORMAL;
   else if(g_VolCompositeIndex < 350.0) g_CurrentVolState = VOL_EXPANDING;
   else if(g_VolCompositeIndex < 600.0) g_CurrentVolState = VOL_EXTREME;
   else                                 g_CurrentVolState = VOL_CHAOTIC;
}

//+------------------------------------------------------------------+
//| LAYER 5: MARKET STRUCTURE SWING ENGINE V2 (+ HTF trend filter)   |
//+------------------------------------------------------------------+
void AnalyzeMarketStructure()
{
   MqlRates rates[];
   if(CopyRates(_Symbol, _Period, 1, 20, rates) < 20) return;

   double highestHigh = -1.0; double lowestLow = 999999.0;
   for(int i=0; i<20; i++)
   {
      if(rates[i].high > highestHigh) highestHigh = rates[i].high;
      if(rates[i].low < lowestLow)   lowestLow   = rates[i].low;
   }

   double currentClose = rates[19].close;
   double structureMid = lowestLow + ((highestHigh - lowestLow) / 2.0);

   if(currentClose > highestHigh - ((highestHigh - lowestLow)*0.2))
   {
      g_CurrentStructure = STRUCTURE_BULL;
      g_StructureStrength = 85.0;
   }
   else if(currentClose < lowestLow + ((highestHigh - lowestLow)*0.2))
   {
      g_CurrentStructure = STRUCTURE_BEAR;
      g_StructureStrength = 85.0;
   }
   else
   {
      g_CurrentStructure = (MathAbs(currentClose - structureMid) / _Point < 100.0) ? STRUCTURE_RANGE : STRUCTURE_TRANSITION;
      g_StructureStrength = 50.0;
   }
}

// NEW: H1 EMA directional bias - returns true if M1/M15 structure direction agrees with H1 trend
bool HTFTrendAligned(ENUM_SIGNAL proposedDirection)
{
   if(!InpUseHTFTrendFilter) return true;

   double emaBuf[1];
   if(CopyBuffer(g_hHTF_EMA, 0, 0, 1, emaBuf) != 1) return true; // fail-open rather than block all trading on data hiccup

   double h1Close = iClose(_Symbol, PERIOD_H1, 0);
   bool htfBull = h1Close > emaBuf[0];

   if(proposedDirection == SIGNAL_BUY)  return htfBull;
   if(proposedDirection == SIGNAL_SELL) return !htfBull;
   return true;
}

//+------------------------------------------------------------------+
//| LAYER 6: INSTITUTIONAL ORDER FLOW PROXY ENGINE                   |
//+------------------------------------------------------------------+
void EstimateOrderFlow()
{
   double bidAggression = 0.0; double askAggression = 0.0;
   bool anyRealVolume = false;

   int n = g_TickFilled;
   for(int i=1; i<n; i++)
   {
      double diff = g_TickBuffer[i].bid - g_TickBuffer[i-1].bid;
      long size = g_TickBuffer[i].volume;
      if(size > 0) anyRealVolume = true;
      if(size <= 0) size = 1;

      if(diff > 0)      bidAggression += (diff / _Point) * (double)size;
      else if(diff < 0) askAggression += (MathAbs(diff) / _Point) * (double)size;
   }

   double totalAggression = bidAggression + askAggression;
   if(totalAggression <= 0) totalAggression = 1.0;

   g_CurrentOrderFlow.AggressionScore  = NormalizeDouble((bidAggression / totalAggression) * 100.0, 2);
   g_CurrentOrderFlow.BullishPressure  = NormalizeDouble(bidAggression, 2);
   g_CurrentOrderFlow.BearishPressure  = NormalizeDouble(askAggression, 2);
   g_CurrentOrderFlow.Dominance        = (g_CurrentOrderFlow.AggressionScore > 55.0) ? "BULLS" : ((g_CurrentOrderFlow.AggressionScore < 45.0) ? "BEARS" : "NEUTRAL");
   g_CurrentOrderFlow.SyntheticVolume  = !anyRealVolume; // FIX: surfaced explicitly instead of silently faking real order-flow
}

//+------------------------------------------------------------------+
//| LAYER 6 (Cont.): PURE FAIR VALUE GAP DETECTION MODULE             |
//+------------------------------------------------------------------+
void ScanFairValueGaps()
{
   MqlRates rates[];
   if(CopyRates(_Symbol, _Period, 1, 5, rates) < 5) return;

   g_TotalFVGZones = 0;

   if(rates[4].low > rates[2].high)
   {
      g_FVGMap[g_TotalFVGZones].UpperBound   = rates[4].low;
      g_FVGMap[g_TotalFVGZones].LowerBound   = rates[2].high;
      g_FVGMap[g_TotalFVGZones].Size         = (rates[4].low - rates[2].high) / _Point;
      g_FVGMap[g_TotalFVGZones].Filled       = false;
      g_FVGMap[g_TotalFVGZones].Created      = rates[3].time;
      g_FVGMap[g_TotalFVGZones].QualityScore = MathMin((g_FVGMap[g_TotalFVGZones].Size / 50.0) * 100.0, 100.0);
      g_TotalFVGZones++;
   }
   else if(rates[4].high < rates[2].low)
   {
      g_FVGMap[g_TotalFVGZones].UpperBound   = rates[2].low;
      g_FVGMap[g_TotalFVGZones].LowerBound   = rates[4].high;
      g_FVGMap[g_TotalFVGZones].Size         = (rates[2].low - rates[4].high) / _Point;
      g_FVGMap[g_TotalFVGZones].Filled       = false;
      g_FVGMap[g_TotalFVGZones].Created      = rates[3].time;
      g_FVGMap[g_TotalFVGZones].QualityScore = MathMin((g_FVGMap[g_TotalFVGZones].Size / 50.0) * 100.0, 100.0);
      g_TotalFVGZones++;
   }
}

//+------------------------------------------------------------------+
//| LAYER 6 (Cont.): SESSION MICROSTRUCTURE DECODER                  |
//+------------------------------------------------------------------+
void CalculateSessionProbability()
{
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);

   g_CurrentSessionProb.ExpansionProbability    = 33.0;
   g_CurrentSessionProb.ContinuationProbability = 33.0;
   g_CurrentSessionProb.ReversalProbability     = 33.0;
   g_CurrentSessionProb.SessionName             = "ASIA";

   if(dt.hour >= 0 && dt.hour < 7)
   {
      g_CurrentSessionProb.ExpansionProbability    = 15.0;
      g_CurrentSessionProb.ContinuationProbability = 20.0;
      g_CurrentSessionProb.ReversalProbability     = 65.0;
      g_CurrentSessionProb.SessionName             = "ASIA";
   }
   else if(dt.hour >= 7 && dt.hour < 13)
   {
      g_CurrentSessionProb.ExpansionProbability    = 70.0;
      g_CurrentSessionProb.ContinuationProbability = 20.0;
      g_CurrentSessionProb.ReversalProbability     = 10.0;
      g_CurrentSessionProb.SessionName             = "LONDON";
   }
   else if(dt.hour >= 13 && dt.hour < 20)
   {
      g_CurrentSessionProb.ExpansionProbability    = 40.0;
      g_CurrentSessionProb.ContinuationProbability = 50.0;
      g_CurrentSessionProb.ReversalProbability     = 10.0;
      g_CurrentSessionProb.SessionName             = "NEW YORK";
   }
   else // FIX: 20:00-24:00 window previously left stale values from prior branch
   {
      g_CurrentSessionProb.ExpansionProbability    = 20.0;
      g_CurrentSessionProb.ContinuationProbability = 25.0;
      g_CurrentSessionProb.ReversalProbability     = 55.0;
      g_CurrentSessionProb.SessionName             = "LATE NY / ASIA OPEN";
   }
}

//+------------------------------------------------------------------+
//| LAYER 7: MATHEMATICAL PROBABILITY FUSION ENGINE                  |
//+------------------------------------------------------------------+
double CalculateFusionScore()
{
   ScanFairValueGaps();
   CalculateSessionProbability();

   double orderFlowWeight  = 0.35;
   double structureWeight  = 0.20;
   double volatilityWeight = 0.20;
   double liquidityWeight  = 0.10;
   double sessionWeight    = 0.10;
   double fvgWeight        = 0.05;

   // FIX: if the broker feed has no real tick volume, order-flow is a directional proxy only -
   // de-weight it slightly and redistribute to structure/session rather than silently overstating confidence.
   if(g_CurrentOrderFlow.SyntheticVolume)
   {
      orderFlowWeight  = 0.22;
      structureWeight  = 0.27;
      sessionWeight    = 0.16;
   }

   double fvgScore = (g_TotalFVGZones > 0) ? g_FVGMap[0].QualityScore : 40.0;
   double liquidityScore = 50.0;

   for(int i=0; i<g_TotalLiquidityZones; i++)
   {
      if(!g_LiquidityMap[i].Swept && g_LiquidityMap[i].Strength > liquidityScore)
         liquidityScore = g_LiquidityMap[i].Strength;
   }

   double totalScore = (g_StructureStrength * structureWeight) +
                       (liquidityScore * liquidityWeight) +
                       (MathMin(g_VolCompositeIndex / 3.0, 100.0) * volatilityWeight) +
                       (g_CurrentOrderFlow.AggressionScore * InpMomentumBias * orderFlowWeight) +
                       (g_CurrentSessionProb.ContinuationProbability * sessionWeight) +
                       (fvgScore * fvgWeight);

   if(g_CurrentOrderFlow.AggressionScore > 85.0 || g_CurrentOrderFlow.AggressionScore < 15.0)
   {
      totalScore += 15.0;
   }

   return NormalizeDouble(MathMin(MathMax(totalScore, 0.0), 100.0), 2);
}

//+------------------------------------------------------------------+
//| ADAPTIVE EDGE-RESPONSIVE GATE                                    |
//| A single fixed cutoff is either too strict (misses real moves)   |
//| or too loose (lets noise through). This computes a moving gate   |
//| within a bounded band around the baseline, driven by genuine     |
//| condition quality - not by recent P&L chasing, which would just  |
//| create a lagging, self-defeating filter.                          |
//+------------------------------------------------------------------+
double AdaptiveMinFusionScore()
{
   double adj = 0.0; // positive = stricter, negative = looser

   // Volatility state: chaotic/extreme conditions raise the bar (false breakouts more common),
   // but suppressed is already hard-blocked elsewhere so we don't double-penalize it here.
   if(g_CurrentVolState == VOL_CHAOTIC)    adj += InpAdaptiveBandWidth * 0.85;
   else if(g_CurrentVolState == VOL_EXTREME) adj += InpAdaptiveBandWidth * 0.35;
   else if(g_CurrentVolState == VOL_EXPANDING) adj -= InpAdaptiveBandWidth * 0.30; // healthy expansion = real opportunity, lower the bar a touch

   // Session quality: London/NY expansion windows are where real edge concentrates - loosen there;
   // thin Asia/late-NY chop gets stricter so the EA doesn't force trades into dead liquidity.
   if(g_CurrentSessionProb.SessionName == "LONDON")    adj -= InpAdaptiveBandWidth * 0.35;
   else if(g_CurrentSessionProb.SessionName == "NEW YORK") adj -= InpAdaptiveBandWidth * 0.20;
   else if(g_CurrentSessionProb.SessionName == "ASIA") adj += InpAdaptiveBandWidth * 0.30;

   // Strategy health: if the currently-routed strategy has been performing, trust it a little more;
   // if it's been struggling, demand more confirmation before letting it trade again.
   int idx = (int)g_LastChosenStrategy;
   if(idx >= 0 && idx < STRATEGY_COUNT)
   {
      double pf = g_StrategyHealth[idx].ProfitFactor;
      if(pf >= 1.5)      adj -= InpAdaptiveBandWidth * 0.25;
      else if(pf < 1.0)  adj += InpAdaptiveBandWidth * 0.40;
   }

   // Violent, decisive order flow is the clearest real-time signal the market gives a scalper -
   // when it's this one-sided, waiting for a "perfect" score just means missing the move.
   if(g_CurrentOrderFlow.AggressionScore > 80.0 || g_CurrentOrderFlow.AggressionScore < 20.0)
      adj -= InpAdaptiveBandWidth * 0.40;

   double gate = InpMinFusionScore + MathMax(-InpAdaptiveBandWidth, MathMin(InpAdaptiveBandWidth, adj));
   return MathMax(40.0, MathMin(78.0, gate)); // hard floor/ceiling so the gate can never collapse to "always trade" or "never trade"
}

//+------------------------------------------------------------------+
//| LAYER 8: META-ROUTER ENGINE                                      |
//+------------------------------------------------------------------+
ENUM_STRATEGY_TYPE MetaRouter()
{
   double activeGate = AdaptiveMinFusionScore();
   if(g_FinalFusionScore < activeGate) return STRAT_STAND_ASIDE;
   if(g_CurrentVolState == VOL_SUPPRESSED)    return STRAT_STAND_ASIDE; // dead market is the one condition nothing should override

   if(g_CurrentState.State == STATE_TREND_EXPANSION && g_CurrentStructure == STRUCTURE_BULL)
      return HTFTrendAligned(SIGNAL_BUY)  ? STRAT_TREND_CONTINUATION : STRAT_STAND_ASIDE;
   if(g_CurrentState.State == STATE_TREND_EXPANSION && g_CurrentStructure == STRUCTURE_BEAR)
      return HTFTrendAligned(SIGNAL_SELL) ? STRAT_TREND_CONTINUATION : STRAT_STAND_ASIDE;

   if(g_CurrentState.State == STATE_LIQUIDITY_HUNT)       return STRAT_LIQUIDITY_SWEEP;
   if(g_CurrentState.State == STATE_RANGE_ACCUMULATION)   return STRAT_RANGE_REVERSION;
   if(g_CurrentState.State == STATE_VOLATILITY_EXPANSION) return STRAT_VOLATILITY_BREAKOUT;
   if(g_CurrentState.State == STATE_TREND_EXHAUSTION)     return STRAT_TREND_EXHAUSTION;

   return STRAT_STAND_ASIDE;
}

//+------------------------------------------------------------------+
//| ACCOUNT-ADAPTIVE SL/TP/LOT SCALING ENGINE                        |
//| Small accounts (e.g. $30) get tight SL/TP distance & tiny lots.  |
//| Large accounts (e.g. $1000+) get proportionally wider SL/TP and  |
//| larger lots. Growth is sub-linear (exponent <1) so risk doesn't  |
//| explode on big accounts, and clamped so micro accounts never get |
//| an unworkable near-zero stop.                                    |
//+------------------------------------------------------------------+
double GetEquityScaleFactor()
{
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   if(equity <= 0 || InpReferenceEquity <= 0) return 1.0;

   double factor = MathPow(equity / InpReferenceEquity, InpScalingExponent);
   factor = MathMax(InpMinScaleFactor, MathMin(InpMaxScaleFactor, factor));
   return factor;
}

// Returns the SL distance in POINTS, already scaled to account size and
// normalized for live spread. Both AllocateRisk() and ExecuteRoutedStrategy()
// call this so sizing and the actual order always agree on the same distance.
double GetDynamicSLDistancePoints(double atr, double spreadPoints)
{
   double scaleFactor = GetEquityScaleFactor();

   double slDistancePoints = (atr * InpBaseATRMultiplier * scaleFactor) / _Point + spreadPoints;

   double scaledFloor = InpBaseMinSLPoints * scaleFactor;
   if(scaledFloor < 30.0) scaledFloor = 30.0; // absolute hard floor - never allow a near-zero stop regardless of scaling
   if(slDistancePoints < scaledFloor) slDistancePoints = scaledFloor;

   return slDistancePoints;
}

//+------------------------------------------------------------------+
//| LAYER 8 (Cont.): DYNAMIC RISK ALLOCATION ENGINE                  |
//+------------------------------------------------------------------+
double AllocateRisk(ENUM_STRATEGY_TYPE strategy)
{
   int index = (int)strategy;
   if(index < 0 || index >= STRATEGY_COUNT || g_StrategyHealth[index].IsDisabled) return 0.0;

   double confidenceMultiplier = (g_FinalFusionScore - 50.0) / 40.0;
   confidenceMultiplier = MathMax(0.2, MathMin(1.5, confidenceMultiplier));

   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   double absoluteRiskFunds = equity * ((InpBaseRiskPercent * confidenceMultiplier) / 100.0);

   double atr = 0.0; double atrBuf[1];
   if(CopyBuffer(g_hATR, 0, 0, 1, atrBuf) == 1) atr = atrBuf[0];
   if(atr <= 0) return 0.0;

   // NEW: SL distance now scales with account equity (small account -> tight stop, large account -> wider stop)
   MqlTick tick; SymbolInfoTick(_Symbol, tick);
   double spreadPoints = (tick.ask - tick.bid) / _Point;
   double slDistancePoints = GetDynamicSLDistancePoints(atr, spreadPoints);

   double tickVal  = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   if(tickSize <= 0 || tickVal <= 0) return 0.0;

   double pointCost = (tickVal / tickSize) * _Point;
   double targetLot = absoluteRiskFunds / (slDistancePoints * pointCost);

   double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);

   double stepNormalizedLot = MathFloor(targetLot / lotStep) * lotStep;
   bool forcedToMinLot = false;
   if(stepNormalizedLot < minLot)
   {
      stepNormalizedLot = minLot;
      forcedToMinLot = true;
   }
   if(stepNormalizedLot > maxLot) stepNormalizedLot = maxLot;

   // NEW: micro-account safety net. If the broker's minimum lot, at this SL distance,
   // would force real risk well above what the account size targets, skip the trade
   // rather than silently over-risking a small account just to satisfy a broker floor.
   if(forcedToMinLot)
   {
      double actualRiskFunds = stepNormalizedLot * slDistancePoints * pointCost;
      double actualRiskPct   = (equity > 0) ? (actualRiskFunds / equity) * 100.0 : 999.0;
      double maxAcceptablePct = InpBaseRiskPercent * InpMaxAcceptableRiskMultiple;
      if(actualRiskPct > maxAcceptablePct)
      {
         Print("[ACCOUNT SCALING GUARD] Skipped trade: broker min-lot forces ", DoubleToString(actualRiskPct,2),
               "% risk on this equity, exceeding cap of ", DoubleToString(maxAcceptablePct,2), "%.");
         return 0.0;
      }
   }

   return NormalizeDouble(stepNormalizedLot, 2);
}

//+------------------------------------------------------------------+
//| LAYER 9: INSTITUTIONAL EXECUTION ENGINE                          |
//+------------------------------------------------------------------+
bool VerifyExecutionQuality()
{
   MqlTick tick;
   if(!SymbolInfoTick(_Symbol, tick)) return false;

   double liveSpreadPoints = (tick.ask - tick.bid) / _Point;

   int samples = ArraySize(g_HistoricalSpreads);
   int higherCount = 0;
   for(int i=0; i<samples; i++)
   {
      if(g_HistoricalSpreads[i] < liveSpreadPoints) higherCount++;
   }

   double liveSpreadPercentile = ((double)higherCount / (double)samples) * 100.0;
   if(liveSpreadPercentile > InpMaxSpreadPercentile)
   {
      Print("[EXECUTION PRE-GATES] Execution aborted. Spread conditions too wide: Percentile ", DoubleToString(liveSpreadPercentile, 1));
      return false;
   }

   return true;
}

//+------------------------------------------------------------------+
//| EXECUTION STRATEGIC ROUTER TRANSACTION ENGINE                    |
//+------------------------------------------------------------------+
void ExecuteRoutedStrategy(ENUM_STRATEGY_TYPE strategy, double lotSize)
{
   ENUM_SIGNAL entrySignal = SIGNAL_NONE;

   if(strategy == STRAT_TREND_CONTINUATION || strategy == STRAT_VOLATILITY_BREAKOUT)
   {
      if(g_CurrentStructure == STRUCTURE_BULL && g_CurrentOrderFlow.AggressionScore > 50.0) entrySignal = SIGNAL_BUY;
      if(g_CurrentStructure == STRUCTURE_BEAR && g_CurrentOrderFlow.AggressionScore < 50.0) entrySignal = SIGNAL_SELL;
   }
   else if(strategy == STRAT_RANGE_REVERSION || strategy == STRAT_TREND_EXHAUSTION)
   {
      if(g_CurrentOrderFlow.AggressionScore < 40.0) entrySignal = SIGNAL_SELL;
      if(g_CurrentOrderFlow.AggressionScore > 60.0) entrySignal = SIGNAL_BUY;
   }
   else if(strategy == STRAT_LIQUIDITY_SWEEP)
   {
      for(int i=0; i<g_TotalLiquidityZones; i++)
      {
         if(g_LiquidityMap[i].Swept && (TimeCurrent() - g_LiquidityMap[i].Created < 3600))
         {
            if(g_LiquidityMap[i].LevelType == "Daily_High" && g_CurrentOrderFlow.AggressionScore < 45.0) entrySignal = SIGNAL_SELL;
            if(g_LiquidityMap[i].LevelType == "Daily_Low"  && g_CurrentOrderFlow.AggressionScore > 55.0) entrySignal = SIGNAL_BUY;
         }
      }
   }

   if(entrySignal == SIGNAL_NONE) return;

   // NOTE: HTF veto only applies to strategies that are SUPPOSED to follow the higher-timeframe trend.
   // Range reversion, liquidity sweeps, and exhaustion reversals are counter-trend BY DESIGN -
   // vetoing them against H1 direction would block exactly the setups they exist to catch.
   bool isTrendFollowingStrategy = (strategy == STRAT_TREND_CONTINUATION || strategy == STRAT_VOLATILITY_BREAKOUT);
   if(isTrendFollowingStrategy && !HTFTrendAligned(entrySignal)) return;

   double price = (entrySignal == SIGNAL_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double atr = 0.0; double atrBuf[1];
   if(CopyBuffer(g_hATR, 0, 0, 1, atrBuf) == 1) atr = atrBuf[0];
   if(atr <= 0) return;

   MqlTick tick; SymbolInfoTick(_Symbol, tick);
   double spreadPoints = (tick.ask - tick.bid) / _Point;

   // FIX: use the SAME scaled distance function as AllocateRisk() so the lot size that
   // was calculated for a given risk% actually matches the stop distance placed on the order.
   double slDistancePoints = GetDynamicSLDistancePoints(atr, spreadPoints);
   double tpDistancePoints = slDistancePoints * 3.0;

   double slPrice = (entrySignal == SIGNAL_BUY) ? (price - (slDistancePoints * _Point)) : (price + (slDistancePoints * _Point));
   double tpPrice = (entrySignal == SIGNAL_BUY) ? (price + (tpDistancePoints * _Point)) : (price - (tpDistancePoints * _Point));

   MqlTradeRequest request; ZeroMemory(request);
   MqlTradeResult  result;  ZeroMemory(result);

   request.action       = TRADE_ACTION_DEAL;
   request.symbol       = _Symbol;
   request.volume       = lotSize;
   request.type         = (entrySignal == SIGNAL_BUY) ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
   request.price        = price;
   request.sl           = NormalizeDouble(slPrice, _Digits);
   request.tp           = NormalizeDouble(tpPrice, _Digits);
   request.deviation    = 15;
   request.magic        = InpMagicNumber;
   request.comment      = InpTradeComment + "_" + IntegerToString((int)strategy);
   request.type_filling = ORDER_FILLING_FOK;

   for(int i=0; i<3; i++)
   {
      if(OrderSend(request, result))
      {
         if(result.retcode == TRADE_RETCODE_DONE || result.retcode == TRADE_RETCODE_PLACED)
         {
            Print("[SYSTEM TRANSACTION] Order executed. Strategy Ticket ID allocation: ", result.deal);
            break;
         }
      }
      if(result.retcode == TRADE_RETCODE_REQUOTE || result.retcode == TRADE_RETCODE_PRICE_OFF)
      {
         Sleep(100);
         request.price = (entrySignal == SIGNAL_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);
      }
      else break;
   }
}

//+------------------------------------------------------------------+
//| LAYER 10: TRADE LIFECYCLE MANAGEMENT (+ partial close + time-stop)|
//+------------------------------------------------------------------+
void ManageLifecycle()
{
   if(!PositionSelectByTicket(g_Pos.Ticket())) return;

   ulong  ticket     = g_Pos.Ticket();
   double entryPrice = g_Pos.PriceOpen();
   double currentBid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double currentAsk = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double stopLoss   = g_Pos.StopLoss();
   double takeProfit = g_Pos.TakeProfit();
   bool   isBuy      = (g_Pos.PositionType() == POSITION_TYPE_BUY);
   double volume     = g_Pos.Volume();
   datetime openTime = (datetime)g_Pos.Time();

   double initialRiskPoints = MathAbs(entryPrice - stopLoss) / _Point;
   if(initialRiskPoints <= 0) return;

   double currentProfitPoints = isBuy ? ((currentBid - entryPrice) / _Point) : ((entryPrice - currentAsk) / _Point);
   double rMultiple = currentProfitPoints / initialRiskPoints;

   // NEW: Partial close at 1R - banks profit and reduces variance, a proven scalping practice
   if(InpUsePartialClose && rMultiple >= 1.0 && !PartialAlreadyDone(ticket))
   {
      double closeVolume = NormalizeDouble(volume * (InpPartialClosePct / 100.0), 2);
      double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
      if(closeVolume >= minLot && closeVolume < volume)
      {
         if(g_Trade.PositionClosePartial(ticket, closeVolume))
         {
            MarkPartialDone(ticket);
            Print("[LIFECYCLE ENGINE] Partial close executed at 1R for ticket ", ticket);
            // Move SL to breakeven on the remainder immediately after banking partial profit
            double beSL = isBuy ? entryPrice : entryPrice;
            if((isBuy && beSL > stopLoss) || (!isBuy && (beSL < stopLoss || stopLoss == 0)))
               g_Trade.PositionModify(ticket, NormalizeDouble(beSL, _Digits), NormalizeDouble(takeProfit, _Digits));
         }
      }
   }

   // NEW: Time-stop - scalp setups that stall are cut rather than left to drift into noise/spread cost
   if(InpUseTimeStop)
   {
      int heldMinutes = (int)((TimeCurrent() - openTime) / 60);
      if(heldMinutes >= InpMaxHoldMinutes && rMultiple < InpTimeStopMinRProgress)
      {
         g_Trade.PositionClose(ticket);
         Print("[LIFECYCLE ENGINE] Time-stop triggered after ", heldMinutes, " minutes with ", DoubleToString(rMultiple,2), "R progress.");
         RegisterTradeResult(rMultiple > 0);
         return;
      }
   }

   // Structured Multi-tier Trailing Engine (unchanged logic, locks profits forward, never backward)
   double milestone1Trigger = initialRiskPoints * 1.5;
   double milestone1Lock    = initialRiskPoints * 0.5;
   double milestone2Trigger = initialRiskPoints * 2.5;
   double milestone2Lock    = initialRiskPoints * 1.5;

   if(currentProfitPoints >= milestone2Trigger)
   {
      double targetSL = isBuy ? (entryPrice + (milestone2Lock * _Point)) : (entryPrice - (milestone2Lock * _Point));
      if((isBuy && targetSL > stopLoss) || (!isBuy && (targetSL < stopLoss || stopLoss == 0)))
      {
         g_Trade.PositionModify(ticket, NormalizeDouble(targetSL, _Digits), NormalizeDouble(takeProfit, _Digits));
         Print("[LIFECYCLE ENGINE] Advanced Trailing Execution: Tier 2 Lock Active.");
      }
   }
   else if(currentProfitPoints >= milestone1Trigger)
   {
      double targetSL = isBuy ? (entryPrice + (milestone1Lock * _Point)) : (entryPrice - (milestone1Lock * _Point));
      if((isBuy && targetSL > stopLoss) || (!isBuy && (targetSL < stopLoss || stopLoss == 0)))
      {
         g_Trade.PositionModify(ticket, NormalizeDouble(targetSL, _Digits), NormalizeDouble(takeProfit, _Digits));
         Print("[LIFECYCLE ENGINE] Advanced Trailing Execution: Tier 1 Lock Active.");
      }
   }
}

bool PartialAlreadyDone(ulong ticket)
{
   for(int i=0; i<ArraySize(g_PartialTickets); i++)
      if(g_PartialTickets[i] == ticket) return true;
   return false;
}
void MarkPartialDone(ulong ticket)
{
   int n = ArraySize(g_PartialTickets);
   ArrayResize(g_PartialTickets, n+1);
   g_PartialTickets[n] = ticket;
}

//+------------------------------------------------------------------+
//| TRADE TRANSACTION HOOK - feeds win/loss into risk-guard subsystem |
//+------------------------------------------------------------------+
void OnTradeTransaction(const MqlTradeTransaction &trans, const MqlTradeRequest &request, const MqlTradeResult &result)
{
   if(trans.type == TRADE_TRANSACTION_DEAL_ADD)
   {
      if(HistoryDealSelect(trans.deal))
      {
         long dealMagic = HistoryDealGetInteger(trans.deal, DEAL_MAGIC);
         long entryType = HistoryDealGetInteger(trans.deal, DEAL_ENTRY);
         if(dealMagic == (long)InpMagicNumber && entryType == DEAL_ENTRY_OUT)
         {
            double profit = HistoryDealGetDouble(trans.deal, DEAL_PROFIT) + HistoryDealGetDouble(trans.deal, DEAL_SWAP) + HistoryDealGetDouble(trans.deal, DEAL_COMMISSION);
            RegisterTradeResult(profit > 0);
         }
      }
   }
}

//+------------------------------------------------------------------+
//| PIPELINE ACCOUNT VALIDATION HOOKS                                |
//+------------------------------------------------------------------+
bool IsPositionOpen()
{
   for(int i = PositionsTotal()-1; i >= 0; i--)
   {
      if(g_Pos.SelectByIndex(i) && g_Pos.Magic() == InpMagicNumber && g_Pos.Symbol() == _Symbol) return true;
   }
   return false;
}

//+------------------------------------------------------------------+
//| NEURA AI ENGINE DASHBOARD - luxury midnight/neon/gold/glass UI   |
//+------------------------------------------------------------------+
void DashLabel(string name, string text, int x, int y, color clr, int size=9, string font="Consolas")
{
   string full = DASH_PREFIX + name;
   if(ObjectFind(0, full) < 0)
   {
      ObjectCreate(0, full, OBJ_LABEL, 0, 0, 0);
      ObjectSetInteger(0, full, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(0, full, OBJPROP_HIDDEN, true);
      ObjectSetInteger(0, full, OBJPROP_BACK, false);
      ObjectSetInteger(0, full, OBJPROP_SELECTABLE, false);
   }
   ObjectSetInteger(0, full, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, full, OBJPROP_YDISTANCE, y);
   ObjectSetString(0, full, OBJPROP_TEXT, text);
   ObjectSetInteger(0, full, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, full, OBJPROP_FONTSIZE, size);
   ObjectSetString(0, full, OBJPROP_FONT, font);
}

void DashRect(string name, int x, int y, int w, int h, color bg, color border)
{
   string full = DASH_PREFIX + name;
   if(ObjectFind(0, full) < 0)
   {
      ObjectCreate(0, full, OBJ_RECTANGLE_LABEL, 0, 0, 0);
      ObjectSetInteger(0, full, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(0, full, OBJPROP_BACK, false);
      ObjectSetInteger(0, full, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, full, OBJPROP_HIDDEN, true);
   }
   ObjectSetInteger(0, full, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, full, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, full, OBJPROP_XSIZE, w);
   ObjectSetInteger(0, full, OBJPROP_YSIZE, h);
   ObjectSetInteger(0, full, OBJPROP_BGCOLOR, bg);
   ObjectSetInteger(0, full, OBJPROP_COLOR, border);
   ObjectSetInteger(0, full, OBJPROP_STYLE, STYLE_SOLID);
   ObjectSetInteger(0, full, OBJPROP_WIDTH, 1);
}

string StrategyName(ENUM_STRATEGY_TYPE s)
{
   switch(s)
   {
      case STRAT_TREND_CONTINUATION: return "TREND CONT.";
      case STRAT_RANGE_REVERSION:    return "RANGE REV.";
      case STRAT_LIQUIDITY_SWEEP:    return "LIQ SWEEP";
      case STRAT_VOLATILITY_BREAKOUT:return "VOL BREAKOUT";
      case STRAT_TREND_EXHAUSTION:   return "EXHAUSTION";
      default:                       return "STAND ASIDE";
   }
}

void DrawDashboard()
{
   int x0 = 15, y0 = 25, w = 300;
   int y = y0;

   // Outer panel - deep midnight-blue glass
   DashRect("PANEL_BG", x0-8, y0-8, w, 486, CLR_PANEL_BG, CLR_NEON_CYAN);

   // Title / engine header
   DashLabel("TITLE", "NEURA AI ENGINE", x0, y, CLR_NEON_CYAN, 12, "Consolas Bold"); y += 22;
   DashLabel("SUB", g_FinalDecisionText=="HALT - DD LIMIT" ? "STATUS: RISK HALTED" : "STATUS: " + (IsPositionOpen()? "MANAGING" : "SCANNING"), x0, y, CLR_GLASS_GREEN, 9); y += 24;

   // Market info block
   DashRect("MKT_BG", x0-4, y-4, w-8, 78, CLR_PANEL_BG2, CLR_NEON_MAGENTA);
   DashLabel("MKT_HDR", "MARKET INFO", x0, y, CLR_NEON_MAGENTA, 9, "Consolas Bold"); y += 16;
   MqlTick t; SymbolInfoTick(_Symbol, t);
   DashLabel("BID", "Bid   " + DoubleToString(t.bid,_Digits), x0, y, CLR_TEXT_BRIGHT, 9);
   DashLabel("ASK", "Ask   " + DoubleToString(t.ask,_Digits), x0+150, y, CLR_TEXT_BRIGHT, 9); y += 14;
   double atrV=0; double ab[1]; if(CopyBuffer(g_hATR,0,0,1,ab)==1) atrV=ab[0];
   DashLabel("SPR", "Spread " + DoubleToString((t.ask-t.bid)/_Point,1)+" pts", x0, y, CLR_GLASS_GREEN, 9);
   DashLabel("ATR", "ATR(" + IntegerToString(InpATRPeriod) + ") " + DoubleToString(atrV/_Point,0)+" pts", x0+150, y, CLR_GLASS_GREEN, 9); y += 14;
   DashLabel("SYM", _Symbol + "  " + EnumToString((ENUM_TIMEFRAMES)_Period), x0, y, CLR_GOLD, 9);
   DashLabel("VOLF", g_CurrentOrderFlow.SyntheticVolume ? "Vol: SYNTH" : "Vol: REAL", x0+150, y, g_CurrentOrderFlow.SyntheticVolume? CLR_WARN_RED : CLR_GLASS_GREEN, 9); y += 24;

   // Fusion / signal block
   DashRect("SIG_BG", x0-4, y-4, w-8, 90, CLR_PANEL_BG2, CLR_GOLD);
   DashLabel("SIG_HDR", "FUSION SIGNAL ENGINE", x0, y, CLR_GOLD, 9, "Consolas Bold"); y += 16;
   DashLabel("FUSION", "Fusion Score   " + DoubleToString(g_FinalFusionScore,1) + "  /  Gate " + DoubleToString(AdaptiveMinFusionScore(),1), x0, y, CLR_NEON_CYAN, 9); y += 14;
   DashLabel("STRUCT", "Structure   " + EnumToString(g_CurrentStructure), x0, y, CLR_TEXT_BRIGHT, 9); y += 14;
   DashLabel("VOLSTATE", "Vol State   " + EnumToString(g_CurrentVolState), x0, y, CLR_TEXT_BRIGHT, 9); y += 14;
   DashLabel("FLOW", "Order Flow  " + g_CurrentOrderFlow.Dominance + " (" + DoubleToString(g_CurrentOrderFlow.AggressionScore,1) + ")", x0, y, CLR_TEXT_BRIGHT, 9); y += 18;

   // Final decision banner
   color decisionClr = CLR_GOLD;
   if(StringFind(g_FinalDecisionText,"BUY")>=0) decisionClr = CLR_GLASS_GREEN;
   else if(StringFind(g_FinalDecisionText,"SELL")>=0) decisionClr = CLR_WARN_RED;
   else if(g_FinalDecisionText=="HOLD") decisionClr = CLR_GOLD;
   DashRect("DEC_BG", x0-4, y-4, w-8, 30, CLR_PANEL_BG2, CLR_NEON_CYAN);
   DashLabel("DEC_HDR", "FINAL DECISION", x0, y, CLR_NEON_CYAN, 9, "Consolas Bold"); y += 14;
   DashLabel("DEC", g_FinalDecisionText + "   [" + StrategyName(g_LastChosenStrategy) + "]", x0, y, decisionClr, 10, "Consolas Bold"); y += 26;

   // Open positions
   DashRect("POS_BG", x0-4, y-4, w-8, 50, CLR_PANEL_BG2, CLR_GLASS_GREEN);
   DashLabel("POS_HDR", "OPEN POSITIONS", x0, y, CLR_GLASS_GREEN, 9, "Consolas Bold"); y += 16;
   if(IsPositionOpen() && PositionSelectByTicket(g_Pos.Ticket()))
   {
      string side = (g_Pos.PositionType()==POSITION_TYPE_BUY) ? "BUY" : "SELL";
      DashLabel("POS_LINE", side + "  " + DoubleToString(g_Pos.Volume(),2) + " @ " + DoubleToString(g_Pos.PriceOpen(),_Digits) +
                 "  P/L: " + DoubleToString(g_Pos.Profit(),2), x0, y, (g_Pos.Profit()>=0?CLR_GLASS_GREEN:CLR_WARN_RED), 9);
   }
   else
   {
      DashLabel("POS_LINE", "0 open", x0, y, CLR_TEXT_DIM, 9);
   }
   y += 24;

   // Account info
   DashRect("ACC_BG", x0-4, y-4, w-8, 106, CLR_PANEL_BG2, CLR_GOLD);
   DashLabel("ACC_HDR", "ACCOUNT INFO", x0, y, CLR_GOLD, 9, "Consolas Bold"); y += 16;
   double eq = AccountInfoDouble(ACCOUNT_EQUITY);
   double bal = AccountInfoDouble(ACCOUNT_BALANCE);
   double dayPL = eq - g_DayStartEquity;
   double ddPct = g_DayStartEquity>0 ? (g_DayStartEquity-eq)/g_DayStartEquity*100.0 : 0.0;
   DashLabel("BAL", "Balance " + DoubleToString(bal,2), x0, y, CLR_TEXT_BRIGHT, 9); y += 14;
   DashLabel("EQ",  "Equity  " + DoubleToString(eq,2), x0, y, CLR_TEXT_BRIGHT, 9); y += 14;
   DashLabel("PL",  "Day P&L " + DoubleToString(dayPL,2) + "  DD " + DoubleToString(ddPct,2) + "%", x0, y, dayPL>=0?CLR_GLASS_GREEN:CLR_WARN_RED, 9); y += 14;
   DashLabel("TRD",  "Trades Today " + IntegerToString(g_TradesToday) + "/" + IntegerToString(InpMaxTradesPerDay) +
             "   Session: " + g_CurrentSessionProb.SessionName, x0, y, CLR_NEON_MAGENTA, 9); y += 14;
   DashLabel("SCALE", "Equity Scale x" + DoubleToString(GetEquityScaleFactor(),2) +
             "  (Ref $" + DoubleToString(InpReferenceEquity,0) + ")", x0, y, CLR_GOLD, 9);

   ChartRedraw(0);
}
