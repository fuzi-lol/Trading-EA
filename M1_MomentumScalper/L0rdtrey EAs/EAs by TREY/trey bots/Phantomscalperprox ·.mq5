//+------------------------------------------------------------------+
//|                    PHANTOM SCALPER PRO X                        |
//|          Institutional AI Gold Scalper - XAUUSD                 |
//|          Version 4.0 | Multi-Layer Intelligence Engine          |
//+------------------------------------------------------------------+
//  ARCHITECTURE:
//  Layer 1 - Market Intelligence Engine
//  Layer 2 - Smart Money Concepts Engine (ICT/SMC)
//  Layer 3 - AI Scoring & Decision Engine
//  Layer 4 - Adaptive Statistical Learning (ML-Proxy)
//  Layer 5 - Risk Intelligence Engine
//  Layer 6 - Institutional Execution Engine
//  Layer 7 - Dynamic Trade Management
//  Layer 8 - Self-Learning Database
//  Layer 9 - Institutional Dashboard
//+------------------------------------------------------------------+
#property copyright   "Phantom Scalper Pro X"
#property version     "4.00"
#property strict

#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>
#include <Trade\OrderInfo.mqh>

//+------------------------------------------------------------------+
//| INPUT PARAMETERS - ORGANIZED BY LAYER                           |
//+------------------------------------------------------------------+

// --- GENERAL ---
input group "=== GENERAL SETTINGS ==="
input string   EA_Name              = "PhantomScalperProX";
input bool     EA_Active            = true;
input string   TradeComment         = "PSPX";
input int      MagicNumber          = 202400;

// --- AI THRESHOLDS ---
input group "=== AI DECISION THRESHOLDS ==="
input double   MinAIConfidence      = 72.0;    // Minimum AI confidence to trade (%)
input double   MinTradeScore        = 70.0;    // Minimum total trade score (%)
input bool     RequireGradeA        = true;    // Only trade Grade A+ and Grade A setups
input bool     RequireHTFAlignment  = true;    // Require higher TF alignment

// --- RISK MANAGEMENT ---
input group "=== RISK MANAGEMENT ==="
input double   RiskPerTrade         = 1.0;     // Risk per trade (% of balance)
input double   MaxRiskPerTrade      = 2.5;     // Maximum risk per trade (%)
input double   DailyDrawdownLimit   = 4.0;     // Daily drawdown limit (%)
input double   WeeklyDrawdownLimit  = 8.0;     // Weekly drawdown limit (%)
input double   MonthlyDrawdownLimit = 15.0;    // Monthly drawdown limit (%)
input int      MaxConsecLosses      = 4;       // Max consecutive losses before pause
input double   EquityProtection     = 20.0;    // Hard equity stop (% loss from peak)
input bool     CapitalPreservation  = true;    // Enable capital preservation mode

// --- SMART MONEY CONCEPTS ---
input group "=== SMART MONEY CONCEPTS ==="
input bool     UseSMC               = true;    // Enable SMC analysis
input int      StructureLookback    = 50;      // Bars for structure analysis
input int      OrderBlockLookback   = 30;      // Bars for order block detection
input int      FVGMinSize           = 3;       // Minimum FVG size (points)
input bool     UseEqualHighsLows    = true;    // Detect equal highs/lows
input bool     UseLiquiditySweeps   = true;    // Detect liquidity sweeps
input int      EQLTolerance         = 5;       // Equal H/L tolerance (points)

// --- SESSION FILTERS ---
input group "=== SESSION FILTERS ==="
input bool     TradeAsian           = false;   // Trade Asian session
input bool     TradeLondon          = true;    // Trade London session
input bool     TradeNewYork         = true;    // Trade New York session
input bool     TradeOverlap         = true;    // Trade London-NY overlap
input int      AsianOpen            = 0;       // Asian open (server hour)
input int      AsianClose           = 8;       // Asian close (server hour)
input int      LondonOpen           = 8;       // London open (server hour)
input int      LondonClose          = 16;      // London close (server hour)
input int      NYOpen               = 13;      // New York open (server hour)
input int      NYClose              = 21;      // New York close (server hour)

// --- TRADE ENTRY ---
input group "=== TRADE ENTRY ==="
input double   SL_ATR_Multiplier    = 1.5;     // SL = ATR * multiplier
input double   TP_RR_Ratio          = 2.0;     // TP = SL * RR ratio
input double   MaxSpreadPoints      = 30.0;    // Maximum allowed spread (points)
input int      ATR_Period           = 14;      // ATR period
input int      MaxTradesPerDay      = 3;       // Max trades per day
input int      MaxOpenTrades        = 2;       // Max simultaneous open trades

// --- TRADE MANAGEMENT ---
input group "=== TRADE MANAGEMENT ==="
input bool     UseBreakEven         = true;    // Enable break-even
input double   BE_TriggerRR        = 1.0;     // Move BE at this R multiple
input bool     UseTrailingStop      = true;    // Enable trailing stop
input double   TrailATR_Multiplier  = 1.0;    // Trail stop ATR multiplier
input bool     UsePartialClose      = true;    // Enable partial close
input double   PartialCloseRR      = 1.5;     // Partial close at R multiple
input double   PartialClosePercent  = 50.0;   // Percent to close partially

// --- NEWS FILTER ---
input group "=== NEWS FILTER ==="
input bool     UseNewsFilter        = true;    // Enable news filtering
input int      NewsMinutesBefore    = 30;      // Avoid trading X mins before news
input int      NewsMinutesAfter     = 15;      // Avoid trading X mins after news
input bool     PauseOnHighImpact    = true;    // Pause on high-impact news

// --- EXECUTION ---
input group "=== EXECUTION ==="
input int      Slippage             = 3;       // Maximum slippage (points)
input int      MaxRetries           = 3;       // Order retry attempts
input int      RetryDelay           = 500;     // Retry delay (ms)

// --- DASHBOARD ---
input group "=== DASHBOARD ==="
input bool     ShowDashboard        = true;    // Show institutional dashboard
input bool     ShowDetailedStats    = true;    // Show detailed statistics
input color    DashBGColor          = C'10,14,24';   // Dashboard background
input color    AccentColor          = C'0,212,255';  // Accent color
input color    ProfitColor          = C'0,230,118';  // Profit color
input color    LossColor            = C'255,69,58';  // Loss color
input color    NeutralColor         = C'180,190,210'; // Neutral color
input int      DashboardX          = 10;       // Dashboard X position
input int      DashboardY          = 30;       // Dashboard Y position

// --- ALERTS ---
input group "=== ALERTS ==="
input bool     AlertOnTrade         = true;
input bool     AlertOnHighConf      = true;
input bool     AlertPushNotify      = false;
input bool     AlertEmail           = false;

//+------------------------------------------------------------------+
//| ENUMERATIONS                                                     |
//+------------------------------------------------------------------+
enum ENUM_MARKET_STATE
{
   STATE_TRENDING_BULL,
   STATE_TRENDING_BEAR,
   STATE_RANGING,
   STATE_ACCUMULATION,
   STATE_DISTRIBUTION,
   STATE_EXPANSION,
   STATE_COMPRESSION,
   STATE_HIGH_VOLATILITY,
   STATE_LOW_VOLATILITY,
   STATE_MANIPULATION,
   STATE_NEWS_EVENT,
   STATE_UNKNOWN
};

enum ENUM_SETUP_GRADE
{
   GRADE_A_PLUS,
   GRADE_A,
   GRADE_B,
   GRADE_C,
   GRADE_NO_SETUP
};

enum ENUM_SESSION
{
   SESSION_ASIAN,
   SESSION_LONDON,
   SESSION_NEW_YORK,
   SESSION_OVERLAP,
   SESSION_CLOSED
};

enum ENUM_TRADE_DIRECTION
{
   DIR_LONG,
   DIR_SHORT,
   DIR_NONE
};

enum ENUM_INST_BIAS
{
   BIAS_BULLISH,
   BIAS_BEARISH,
   BIAS_NEUTRAL
};

//+------------------------------------------------------------------+
//| STRUCTURES                                                       |
//+------------------------------------------------------------------+

// --- AI Confidence Score Bundle ---
struct SAIScore
{
   double TrendScore;
   double StructureScore;
   double LiquidityScore;
   double OrderBlockScore;
   double FVGScore;
   double VolatilityScore;
   double SessionScore;
   double NewsScore;
   double ExecutionScore;
   double HistoricalScore;
   double TotalScore;
   double Confidence;
   ENUM_SETUP_GRADE Grade;
   ENUM_TRADE_DIRECTION Direction;
   bool   TradePermitted;
};

// --- Market State Snapshot ---
struct SMarketState
{
   ENUM_MARKET_STATE  State;
   ENUM_INST_BIAS     HTFBias;      // H4+ bias
   ENUM_INST_BIAS     MTFBias;      // H1 bias
   ENUM_INST_BIAS     LTFBias;      // M15 bias
   ENUM_SESSION       CurrentSession;
   double             ATR_H1;
   double             ATR_M15;
   double             ATR_M5;
   double             Spread;
   double             Volatility;    // 0-100 normalized
   bool               NewsRisk;
   bool               HighImpactNear;
   double             ExpectedMove;
   double             MarketConfidence; // 0-100
   string             StateLabel;
};

// --- SMC Setup ---
struct SSMCSetup
{
   bool               BOS_Bull;
   bool               BOS_Bear;
   bool               CHOCH_Bull;
   bool               CHOCH_Bear;
   bool               LiqSweep_Bull;
   bool               LiqSweep_Bear;
   bool               EqualHighs;
   bool               EqualLows;
   bool               FVG_Bull;
   bool               FVG_Bear;
   double             FVG_High;
   double             FVG_Low;
   bool               OrderBlock_Bull;
   bool               OrderBlock_Bear;
   double             OB_High;
   double             OB_Low;
   bool               BreakerBlock_Bull;
   bool               BreakerBlock_Bear;
   bool               InPremium;
   bool               InDiscount;
   bool               InFairValue;
   double             PremiumLevel;
   double             DiscountLevel;
   int                SetupStrength;  // 0-10
};

// --- Trade Record (for self-learning DB) ---
struct STradeRecord
{
   datetime  EntryTime;
   datetime  ExitTime;
   double    EntryPrice;
   double    ExitPrice;
   double    StopLoss;
   double    TakeProfit;
   double    Profit;
   double    RMultiple;
   double    AIConfidence;
   double    TradeScore;
   ENUM_SETUP_GRADE Grade;
   ENUM_MARKET_STATE MarketState;
   ENUM_SESSION Session;
   double    Spread;
   double    ATR;
   double    Volatility;
   bool      IsWin;
   string    SetupType;
   int       DayOfWeek;
};

// --- Session Performance (learning) ---
struct SSessionPerf
{
   int    Trades;
   int    Wins;
   double TotalProfit;
   double ProfitFactor;
   double WinRate;
   double AvgRMultiple;
   double Weight;        // adaptive weight 0-2.0
};

// --- Setup Type Performance (learning) ---
struct SSetupPerf
{
   string SetupName;
   int    Trades;
   int    Wins;
   double TotalProfit;
   double ProfitFactor;
   double WinRate;
   double AvgConfidence;
   double Weight;
};

// --- Equity Statistics ---
struct SEquityStats
{
   double PeakEquity;
   double DailyStart;
   double WeeklyStart;
   double MonthlyStart;
   double DailyPnL;
   double WeeklyPnL;
   double MonthlyPnL;
   double CurrentDrawdown;
   double MaxDrawdown;
   int    ConsecLosses;
   int    ConsecWins;
   bool   DailyLimitHit;
   bool   WeeklyLimitHit;
   bool   MonthlyLimitHit;
   bool   EquityProtectionHit;
   bool   ConsecLossLimit;
};

// --- Overall Performance Stats ---
struct SPerformance
{
   int    TotalTrades;
   int    WinTrades;
   int    LossTrades;
   double WinRate;
   double ProfitFactor;
   double Expectancy;
   double SharpeRatio;
   double AvgWin;
   double AvgLoss;
   double AvgRMultiple;
   double TotalProfit;
   int    TodayTrades;
};

//+------------------------------------------------------------------+
//| GLOBAL VARIABLES                                                 |
//+------------------------------------------------------------------+

// Core Objects
CTrade             g_Trade;
CPositionInfo      g_Position;

// State Objects
SMarketState       g_Market;
SAIScore           g_AIScore;
SSMCSetup          g_SMC;
SEquityStats       g_Equity;
SPerformance       g_Perf;
SSessionPerf       g_SessionPerf[4];   // Asian, London, NY, Overlap
SSetupPerf         g_SetupPerf[8];     // Up to 8 setup types tracked

// Indicator handles
int h_ATR_H1, h_ATR_M15, h_ATR_M5;
int h_MA_Fast, h_MA_Slow, h_MA_Trend;
int h_RSI_H1, h_RSI_M15;
int h_MACD_H1;
int h_BB_M15;
int h_ADX_H1;

// Timing
datetime g_LastBarTime_M5;
datetime g_LastBarTime_M1;
datetime g_LastAnalysisTime;
datetime g_DayStart;
datetime g_WeekStart;
datetime g_MonthStart;

// Persistent state
int      g_AnalysisCycleCount;
bool     g_EmergencyStop;
string   g_DBFileName;
double   g_PointValue;
double   g_PipValue;
int      g_Digits;

// Dashboard state
string   g_DashObjects[];
int      g_DashObjCount;

//+------------------------------------------------------------------+
//| EXPERT INITIALIZATION                                            |
//+------------------------------------------------------------------+
int OnInit()
{
   Print("=== PHANTOM SCALPER PRO X v4.0 - INITIALIZING ===");

   // Basic setup
   g_PointValue = _Point;
   g_Digits     = _Digits;
   g_PipValue   = _Point * 10;

   // Configure trade object
   g_Trade.SetExpertMagicNumber(MagicNumber);
   g_Trade.SetDeviationInPoints(Slippage);
   g_Trade.SetTypeFilling(ORDER_FILLING_IOC);
   g_Trade.LogLevel(LOG_LEVEL_NO);

   // Initialize DB filename
   g_DBFileName = "PSPX_TradeDB_" + Symbol() + ".csv";

   // Initialize Indicators
   if(!InitIndicators())
   {
      Print("ERROR: Indicator initialization failed");
      return INIT_FAILED;
   }

   // Initialize equity stats
   InitEquityStats();

   // Initialize session performance (load from DB if exists)
   InitSessionPerformance();

   // Initialize setup performance
   InitSetupPerformance();

   // Load historical performance from DB
   LoadTradeDatabase();

   // Initialize market state
   ZeroMemory(g_Market);
   ZeroMemory(g_AIScore);
   ZeroMemory(g_SMC);
   g_Market.State = STATE_UNKNOWN;

   // Timing init
   g_LastBarTime_M5   = 0;
   g_LastBarTime_M1   = 0;
   g_LastAnalysisTime = 0;
   g_DayStart         = GetDayStart();
   g_WeekStart        = GetWeekStart();
   g_MonthStart       = GetMonthStart();
   g_AnalysisCycleCount = 0;
   g_EmergencyStop    = false;

   // Dashboard
   if(ShowDashboard)
      BuildDashboard();

   EventSetTimer(60); // 60-second timer for non-tick updates

   Print("=== PHANTOM SCALPER PRO X - READY ===");
   Print("Symbol: ", Symbol(), " | Magic: ", MagicNumber, " | Min AI: ", MinAIConfidence, "%");
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| INDICATOR INITIALIZATION                                         |
//+------------------------------------------------------------------+
bool InitIndicators()
{
   // ATR across timeframes
   h_ATR_H1  = iATR(Symbol(), PERIOD_H1,  ATR_Period);
   h_ATR_M15 = iATR(Symbol(), PERIOD_M15, ATR_Period);
   h_ATR_M5  = iATR(Symbol(), PERIOD_M5,  ATR_Period);

   // Moving averages for trend (on H1)
   h_MA_Trend = iMA(Symbol(), PERIOD_H4, 50, 0, MODE_EMA, PRICE_CLOSE);
   h_MA_Fast  = iMA(Symbol(), PERIOD_H1, 20, 0, MODE_EMA, PRICE_CLOSE);
   h_MA_Slow  = iMA(Symbol(), PERIOD_H1, 50, 0, MODE_EMA, PRICE_CLOSE);

   // RSI for momentum
   h_RSI_H1  = iRSI(Symbol(), PERIOD_H1,  14, PRICE_CLOSE);
   h_RSI_M15 = iRSI(Symbol(), PERIOD_M15, 14, PRICE_CLOSE);

   // MACD for momentum confirmation
   h_MACD_H1 = iMACD(Symbol(), PERIOD_H1, 12, 26, 9, PRICE_CLOSE);

   // Bollinger for volatility
   h_BB_M15  = iBands(Symbol(), PERIOD_M15, 20, 0, 2.0, PRICE_CLOSE);

   // ADX for trend strength
   h_ADX_H1  = iADX(Symbol(), PERIOD_H1, 14);

   // Validate all handles
   if(h_ATR_H1 == INVALID_HANDLE  || h_ATR_M15 == INVALID_HANDLE ||
      h_ATR_M5 == INVALID_HANDLE  || h_MA_Trend == INVALID_HANDLE ||
      h_MA_Fast == INVALID_HANDLE || h_MA_Slow  == INVALID_HANDLE ||
      h_RSI_H1  == INVALID_HANDLE || h_RSI_M15  == INVALID_HANDLE ||
      h_MACD_H1 == INVALID_HANDLE || h_BB_M15   == INVALID_HANDLE ||
      h_ADX_H1  == INVALID_HANDLE)
   {
      return false;
   }
   return true;
}

//+------------------------------------------------------------------+
//| EXPERT DEINITIALIZATION                                          |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   EventKillTimer();
   RemoveDashboard();
   // Release indicator handles
   IndicatorRelease(h_ATR_H1);
   IndicatorRelease(h_ATR_M15);
   IndicatorRelease(h_ATR_M5);
   IndicatorRelease(h_MA_Trend);
   IndicatorRelease(h_MA_Fast);
   IndicatorRelease(h_MA_Slow);
   IndicatorRelease(h_RSI_H1);
   IndicatorRelease(h_RSI_M15);
   IndicatorRelease(h_MACD_H1);
   IndicatorRelease(h_BB_M15);
   IndicatorRelease(h_ADX_H1);
   Print("PHANTOM SCALPER PRO X - Deinitialized. Reason: ", reason);
}

//+------------------------------------------------------------------+
//| ONTICK - MAIN EXECUTION LOOP                                     |
//+------------------------------------------------------------------+
void OnTick()
{
   if(!EA_Active || g_EmergencyStop) return;

   // Update equity stats every tick
   UpdateEquityStats();

   // Emergency protection check
   if(CheckEmergencyStop()) return;

   // --- M5 BAR LOGIC (main analysis cycle) ---
   datetime currentBarTime_M5 = iTime(Symbol(), PERIOD_M5, 0);
   if(currentBarTime_M5 != g_LastBarTime_M5)
   {
      g_LastBarTime_M5 = currentBarTime_M5;
      RunM5AnalysisCycle();
   }

   // --- M1 BAR LOGIC (execution precision) ---
   datetime currentBarTime_M1 = iTime(Symbol(), PERIOD_M1, 0);
   if(currentBarTime_M1 != g_LastBarTime_M1)
   {
      g_LastBarTime_M1 = currentBarTime_M1;
      RunM1ExecutionCycle();
   }

   // Dashboard update
   if(ShowDashboard)
      UpdateDashboard();
}

//+------------------------------------------------------------------+
//| TIMER (every 60 seconds)                                         |
//+------------------------------------------------------------------+
void OnTimer()
{
   // Reset daily/weekly/monthly anchors if needed
   UpdatePeriodAnchors();
   // Save performance DB periodically
   SaveTradeDatabase();
}

//+------------------------------------------------------------------+
//| M5 ANALYSIS CYCLE - Full market scan                            |
//+------------------------------------------------------------------+
void RunM5AnalysisCycle()
{
   g_AnalysisCycleCount++;

   // 1. Session Analysis
   AnalyzeSession();

   // 2. Multi-Timeframe Market Structure
   AnalyzeMultiTimeframeStructure();

   // 3. Volatility Engine
   AnalyzeVolatility();

   // 4. SMC Engine
   if(UseSMC) AnalyzeSMC();

   // 5. News Risk
   if(UseNewsFilter) AnalyzeNewsRisk();

   // 6. Gold-Specific Intelligence
   AnalyzeGoldIntelligence();

   // 7. Market Classification (ML proxy)
   ClassifyMarketState();

   // 8. AI Scoring
   RunAIScoring();

   // 9. Manage open trades
   ManageOpenTrades();

   // 10. Evaluate entry signal
   if(CanTrade())
      EvaluateEntrySignal();
}

//+------------------------------------------------------------------+
//| M1 EXECUTION CYCLE - Precision execution management             |
//+------------------------------------------------------------------+
void RunM1ExecutionCycle()
{
   // Fast trade management on M1
   ManageTrailingStop();
   CheckBreakEven();
   CheckPartialClose();
}

//+------------------------------------------------------------------+
//| SESSION ANALYSIS ENGINE                                          |
//+------------------------------------------------------------------+
void AnalyzeSession()
{
   MqlDateTime tm;
TimeToStruct(TimeCurrent(), tm);
int hour = tm.hour;

   bool inAsian   = (hour >= AsianOpen  && hour < AsianClose);
   bool inLondon  = (hour >= LondonOpen && hour < LondonClose);
   bool inNY      = (hour >= NYOpen     && hour < NYClose);
   bool inOverlap = (inLondon && inNY);

   if(inOverlap)
      g_Market.CurrentSession = SESSION_OVERLAP;
   else if(inNY)
      g_Market.CurrentSession = SESSION_NEW_YORK;
   else if(inLondon)
      g_Market.CurrentSession = SESSION_LONDON;
   else if(inAsian)
      g_Market.CurrentSession = SESSION_ASIAN;
   else
      g_Market.CurrentSession = SESSION_CLOSED;
}

//+------------------------------------------------------------------+
//| MULTI-TIMEFRAME STRUCTURE ANALYSIS                              |
//+------------------------------------------------------------------+
void AnalyzeMultiTimeframeStructure()
{
   // H4 macro bias (trend direction)
   double ma_h4[];
   ArraySetAsSeries(ma_h4, true);
   if(CopyBuffer(h_MA_Trend, 0, 0, 3, ma_h4) < 3) return;

   double price_h4 = iClose(Symbol(), PERIOD_H4, 1);
   ENUM_INST_BIAS h4bias = BIAS_NEUTRAL;
   if(price_h4 > ma_h4[0]) h4bias = BIAS_BULLISH;
   else if(price_h4 < ma_h4[0]) h4bias = BIAS_BEARISH;
   g_Market.HTFBias = h4bias;

   // H1 momentum bias
   double rsi_h1[];
   ArraySetAsSeries(rsi_h1, true);
   if(CopyBuffer(h_RSI_H1, 0, 0, 3, rsi_h1) < 3) return;

   ENUM_INST_BIAS h1bias = BIAS_NEUTRAL;
   if(rsi_h1[0] > 55 && rsi_h1[0] < 75) h1bias = BIAS_BULLISH;
   else if(rsi_h1[0] < 45 && rsi_h1[0] > 25) h1bias = BIAS_BEARISH;
   g_Market.MTFBias = h1bias;

   // M15 short-term bias
   double rsi_m15[];
   ArraySetAsSeries(rsi_m15, true);
   if(CopyBuffer(h_RSI_M15, 0, 0, 3, rsi_m15) < 3) return;

   ENUM_INST_BIAS m15bias = BIAS_NEUTRAL;
   if(rsi_m15[0] > 52) m15bias = BIAS_BULLISH;
   else if(rsi_m15[0] < 48) m15bias = BIAS_BEARISH;
   g_Market.LTFBias = m15bias;

   // HTF Alignment check - count aligned biases
   int alignCount = 0;
   if(g_Market.HTFBias == g_Market.MTFBias) alignCount++;
   if(g_Market.MTFBias == g_Market.LTFBias) alignCount++;
   if(g_Market.HTFBias == g_Market.LTFBias) alignCount++;
   g_Market.MarketConfidence = (alignCount / 3.0) * 100.0;
}

//+------------------------------------------------------------------+
//| VOLATILITY ENGINE                                               |
//+------------------------------------------------------------------+
void AnalyzeVolatility()
{
   double atr_h1[], atr_m15[], atr_m5[];
   ArraySetAsSeries(atr_h1,  true);
   ArraySetAsSeries(atr_m15, true);
   ArraySetAsSeries(atr_m5,  true);

   if(CopyBuffer(h_ATR_H1,  0, 0, 20, atr_h1)  < 20) return;
   if(CopyBuffer(h_ATR_M15, 0, 0, 5,  atr_m15) < 5)  return;
   if(CopyBuffer(h_ATR_M5,  0, 0, 5,  atr_m5)  < 5)  return;

   g_Market.ATR_H1  = atr_h1[0];
   g_Market.ATR_M15 = atr_m15[0];
   g_Market.ATR_M5  = atr_m5[0];

   // Compute average ATR over last 20 bars for normalization
   double sumATR = 0;
   for(int i = 0; i < 20; i++) sumATR += atr_h1[i];
   double avgATR = sumATR / 20.0;

   // Normalized volatility 0-100
   if(avgATR > 0)
      g_Market.Volatility = MathMin(100, (atr_h1[0] / avgATR) * 50.0);
   else
      g_Market.Volatility = 50;

   // Expected move = ATR-based expansion estimate
   g_Market.ExpectedMove = g_Market.ATR_H1 * 1.5;

   // Current spread
   g_Market.Spread = (double)SymbolInfoInteger(Symbol(), SYMBOL_SPREAD) * _Point;
}

//+------------------------------------------------------------------+
//| SMART MONEY CONCEPTS ENGINE                                     |
//+------------------------------------------------------------------+
void AnalyzeSMC()
{
   ZeroMemory(g_SMC);

   double high[], low[], close[], open[];
   ArraySetAsSeries(high,  true);
   ArraySetAsSeries(low,   true);
   ArraySetAsSeries(close, true);
   ArraySetAsSeries(open,  true);

   int bars = MathMax(StructureLookback, OrderBlockLookback) + 5;
   if(CopyHigh(Symbol(),  PERIOD_M15, 0, bars, high)  < bars) return;
   if(CopyLow(Symbol(),   PERIOD_M15, 0, bars, low)   < bars) return;
   if(CopyClose(Symbol(), PERIOD_M15, 0, bars, close) < bars) return;
   if(CopyOpen(Symbol(),  PERIOD_M15, 0, bars, open)  < bars) return;

   // --- Break of Structure ---
   DetectBOS(high, low, close);

   // --- Change of Character ---
   DetectCHOCH(high, low, close);

   // --- Liquidity Sweeps ---
   if(UseLiquiditySweeps)
      DetectLiquiditySweeps(high, low, close);

   // --- Equal Highs / Equal Lows ---
   if(UseEqualHighsLows)
      DetectEqualHighsLows(high, low);

   // --- Fair Value Gaps ---
   DetectFVG(high, low, close, open);

   // --- Order Blocks ---
   DetectOrderBlocks(high, low, close, open);

   // --- Premium / Discount Zones ---
   DetectPremiumDiscount(high, low);

   // --- Composite setup strength ---
   int strength = 0;
   if(g_SMC.BOS_Bull   || g_SMC.BOS_Bear)   strength += 2;
   if(g_SMC.CHOCH_Bull || g_SMC.CHOCH_Bear) strength += 2;
   if(g_SMC.LiqSweep_Bull || g_SMC.LiqSweep_Bear) strength += 2;
   if(g_SMC.FVG_Bull   || g_SMC.FVG_Bear)   strength += 1;
   if(g_SMC.OrderBlock_Bull || g_SMC.OrderBlock_Bear) strength += 2;
   if(g_SMC.EqualHighs || g_SMC.EqualLows)  strength += 1;
   g_SMC.SetupStrength = MathMin(10, strength);
}

//+------------------------------------------------------------------+
//| BOS Detection                                                    |
//+------------------------------------------------------------------+
void DetectBOS(const double &high[], const double &low[], const double &close[])
{
   // Find recent swing high/low
   int swingHighBar = -1, swingLowBar = -1;
   double swingHigh = 0, swingLow = DBL_MAX;

   for(int i = 2; i < StructureLookback - 2; i++)
   {
      if(high[i] > high[i+1] && high[i] > high[i-1] &&
         high[i] > high[i+2] && high[i] > high[i-2])
      {
         if(high[i] > swingHigh) { swingHigh = high[i]; swingHighBar = i; }
      }
      if(low[i] < low[i+1] && low[i] < low[i-1] &&
         low[i] < low[i+2] && low[i] < low[i-2])
      {
         if(low[i] < swingLow) { swingLow = low[i]; swingLowBar = i; }
      }
   }

   double currentClose = close[1];
   if(swingHighBar > 0 && currentClose > swingHigh)
      g_SMC.BOS_Bull = true;
   if(swingLowBar > 0 && currentClose < swingLow)
      g_SMC.BOS_Bear = true;
}

//+------------------------------------------------------------------+
//| CHOCH Detection                                                  |
//+------------------------------------------------------------------+
void DetectCHOCH(const double &high[], const double &low[], const double &close[])
{
   // Look for first opposite BOS after a structure shift
   // Simplified: detect momentum divergence from dominant trend
   if(g_Market.HTFBias == BIAS_BULLISH)
   {
      // In bull trend, CHOCH = price makes lower low
      double recentLow = low[1];
      for(int i = 2; i < 15; i++)
         recentLow = MathMin(recentLow, low[i]);
      // If current bar makes lower low below prior 5 bars
      if(low[0] < low[1] && low[0] < low[2] && low[0] < low[3])
         if(low[0] < recentLow)
            g_SMC.CHOCH_Bear = true;
   }
   else if(g_Market.HTFBias == BIAS_BEARISH)
   {
      double recentHigh = high[1];
      for(int i = 2; i < 15; i++)
         recentHigh = MathMax(recentHigh, high[i]);
      if(high[0] > high[1] && high[0] > high[2] && high[0] > high[3])
         if(high[0] > recentHigh)
            g_SMC.CHOCH_Bull = true;
   }
}

//+------------------------------------------------------------------+
//| Liquidity Sweep Detection                                        |
//+------------------------------------------------------------------+
void DetectLiquiditySweeps(const double &high[], const double &low[], const double &close[])
{
   // Detect wick through equal highs/lows with quick reversal
   int period = MathMin(20, StructureLookback);

   double refHigh = high[2];
   double refLow  = low[2];
   for(int i = 3; i < period; i++)
   {
      refHigh = MathMax(refHigh, high[i]);
      refLow  = MathMin(refLow,  low[i]);
   }

   // Bullish sweep: price swept below key low then closed above it
   if(low[1] < refLow && close[1] > refLow)
      g_SMC.LiqSweep_Bull = true;

   // Bearish sweep: price swept above key high then closed below it
   if(high[1] > refHigh && close[1] < refHigh)
      g_SMC.LiqSweep_Bear = true;
}

//+------------------------------------------------------------------+
//| Equal Highs / Equal Lows Detection                              |
//+------------------------------------------------------------------+
void DetectEqualHighsLows(const double &high[], const double &low[])
{
   double tol = EQLTolerance * _Point;
   int period = MathMin(30, StructureLookback);

   for(int i = 2; i < period; i++)
   {
      for(int j = i + 2; j < period; j++)
      {
         if(MathAbs(high[i] - high[j]) <= tol)
            g_SMC.EqualHighs = true;
         if(MathAbs(low[i]  - low[j])  <= tol)
            g_SMC.EqualLows  = true;
      }
      if(g_SMC.EqualHighs && g_SMC.EqualLows) break;
   }
}

//+------------------------------------------------------------------+
//| Fair Value Gap Detection                                         |
//+------------------------------------------------------------------+
void DetectFVG(const double &high[], const double &low[], const double &close[], const double &open[])
{
   double price = close[0];
   double minSize = FVGMinSize * _Point;

   // Check recent bars for FVG (3-candle pattern)
   for(int i = 2; i < 15; i++)
   {
      // Bullish FVG: gap between candle[i+1] high and candle[i-1] low
      double fvgTop    = low[i-1];
      double fvgBottom = high[i+1];
      if(fvgTop > fvgBottom && (fvgTop - fvgBottom) >= minSize)
      {
         g_SMC.FVG_Bull = true;
         g_SMC.FVG_High = fvgTop;
         g_SMC.FVG_Low  = fvgBottom;
         break;
      }

      // Bearish FVG: gap between candle[i+1] low and candle[i-1] high
      double fvgTop2    = low[i+1];
      double fvgBottom2 = high[i-1];
      if(fvgTop2 > fvgBottom2 && (fvgTop2 - fvgBottom2) >= minSize)
      {
         g_SMC.FVG_Bear = true;
         g_SMC.FVG_High = fvgTop2;
         g_SMC.FVG_Low  = fvgBottom2;
         break;
      }
   }
}

//+------------------------------------------------------------------+
//| Order Block Detection                                            |
//+------------------------------------------------------------------+
void DetectOrderBlocks(const double &high[], const double &low[], const double &close[], const double &open[])
{
   double price = close[0];
   int lookback = MathMin(OrderBlockLookback, ArraySize(high) - 5);

   for(int i = 3; i < lookback; i++)
   {
      // Bearish OB in bullish market: last bearish candle before bullish impulse
      bool isBearishCandle = (close[i] < open[i]);
      bool followedByBull  = (close[i-1] > high[i] || close[i-2] > high[i]);

      if(isBearishCandle && followedByBull)
      {
         // Price returns to this OB zone = Bullish OB (demand zone)
         if(price >= low[i] && price <= high[i])
         {
            g_SMC.OrderBlock_Bull = true;
            g_SMC.OB_High = high[i];
            g_SMC.OB_Low  = low[i];
            break;
         }
      }

      // Bullish OB in bearish market: last bullish candle before bearish impulse
      bool isBullishCandle = (close[i] > open[i]);
      bool followedByBear  = (close[i-1] < low[i] || close[i-2] < low[i]);

      if(isBullishCandle && followedByBear)
      {
         if(price >= low[i] && price <= high[i])
         {
            g_SMC.OrderBlock_Bear = true;
            g_SMC.OB_High = high[i];
            g_SMC.OB_Low  = low[i];
            break;
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Premium / Discount Zone Detection                               |
//+------------------------------------------------------------------+
void DetectPremiumDiscount(const double &high[], const double &low[])
{
   // Use swing range to determine 50% equilibrium
   int period = MathMin(StructureLookback, ArraySize(high));
   double rangeHigh = high[0];
   double rangeLow  = low[0];

   for(int i = 1; i < period; i++)
   {
      rangeHigh = MathMax(rangeHigh, high[i]);
      rangeLow  = MathMin(rangeLow,  low[i]);
   }

   double midpoint = (rangeHigh + rangeLow) / 2.0;
   double price    = iClose(Symbol(), PERIOD_M15, 0);

   g_SMC.PremiumLevel  = rangeHigh;
   g_SMC.DiscountLevel = rangeLow;

   g_SMC.InPremium   = (price > midpoint + (rangeHigh - midpoint) * 0.5);
   g_SMC.InDiscount  = (price < midpoint - (midpoint - rangeLow) * 0.5);
   g_SMC.InFairValue = (!g_SMC.InPremium && !g_SMC.InDiscount);
}

//+------------------------------------------------------------------+
//| NEWS RISK ANALYSIS                                              |
//+------------------------------------------------------------------+
void AnalyzeNewsRisk()
{
   // Note: MT5 does not provide a built-in economic calendar API
   // This module uses time-based heuristics and hardcoded windows
   // For production: integrate with MQL5 Economic Calendar (EventsCountry etc.)
   // or use a CSV-based news feed

   g_Market.NewsRisk        = false;
   g_Market.HighImpactNear  = false;

   

datetime now = TimeCurrent();

MqlDateTime timeStruct;
TimeToStruct(now, timeStruct);

int hourNow = timeStruct.hour;
int minNow  = timeStruct.min;

   // Common high-impact windows (all times server-relative, adjust to your broker)
   // NFP: First Friday each month ~13:30 UTC
   // CPI: ~13:30 UTC
   // FOMC: ~19:00 UTC
   // These are approximations - connect to a real calendar in production

   MqlDateTime dt;
   TimeToStruct(now, dt);

   // Friday 13:00-14:30 UTC = potential NFP window
   if(dt.day_of_week == 5 && hourNow == 13 && minNow >= 0)
   {
      g_Market.NewsRisk       = true;
      g_Market.HighImpactNear = true;
   }

   // Wednesday 13:30-14:30 = CPI/Fed speak
   if(dt.day_of_week == 3 && hourNow == 13)
   {
      g_Market.NewsRisk = true;
   }
}

//+------------------------------------------------------------------+
//| GOLD-SPECIFIC INTELLIGENCE MODULE                               |
//+------------------------------------------------------------------+
void AnalyzeGoldIntelligence()
{
   // Gold intelligence: session-based behavioral analysis
   // In a live deployment, you would correlate with DXY tick data
   // and US10Y rates via custom symbol feeds or broker data

   // Risk environment proxy via volatility + session
   double vix_proxy = g_Market.Volatility;

   // Risk-off: Gold tends to rally (DXY weak, yields falling)
   // Risk-on:  Gold may be pressured (DXY strong, equities bid)
   // We approximate via ATR expansion in NY session

   bool riskOff = (g_Market.Volatility > 65 &&
                   g_Market.CurrentSession == SESSION_NEW_YORK);
   bool riskOn  = (g_Market.Volatility < 35 &&
                   g_Market.HTFBias == BIAS_BEARISH);

   // This modulates the confidence score in the AI layer
   // (stored in MarketConfidence)
   if(riskOff && g_Market.HTFBias == BIAS_BULLISH)
      g_Market.MarketConfidence = MathMin(100, g_Market.MarketConfidence + 10);
   else if(riskOn && g_Market.HTFBias == BIAS_BEARISH)
      g_Market.MarketConfidence = MathMin(100, g_Market.MarketConfidence + 10);
}

//+------------------------------------------------------------------+
//| MARKET CLASSIFICATION ENGINE (ML Proxy)                         |
//+------------------------------------------------------------------+
void ClassifyMarketState()
{
   // Statistical rule-based classification with adaptive weighting
   // This is the ML proxy - weighted rules that self-adjust via performance

   double adx_val[];
   ArraySetAsSeries(adx_val, true);
   if(CopyBuffer(h_ADX_H1, 0, 0, 5, adx_val) < 5) return;

   double adx = adx_val[0];
   double vol = g_Market.Volatility;
   ENUM_INST_BIAS htf = g_Market.HTFBias;
   ENUM_INST_BIAS mtf = g_Market.MTFBias;

   ENUM_MARKET_STATE newState;

   if(g_Market.NewsRisk && g_Market.HighImpactNear)
      newState = STATE_NEWS_EVENT;
   else if(adx > 30 && vol > 65)
      newState = STATE_HIGH_VOLATILITY;
   else if(adx > 25 && htf == BIAS_BULLISH && mtf == BIAS_BULLISH)
      newState = STATE_TRENDING_BULL;
   else if(adx > 25 && htf == BIAS_BEARISH && mtf == BIAS_BEARISH)
      newState = STATE_TRENDING_BEAR;
   else if(adx < 20 && vol > 60)
      newState = STATE_EXPANSION;
   else if(adx < 15 && vol < 30)
      newState = STATE_COMPRESSION;
   else if(adx < 20 && vol < 50)
      newState = STATE_RANGING;
   else if(vol < 25)
      newState = STATE_LOW_VOLATILITY;
   else if(g_SMC.LiqSweep_Bull || g_SMC.LiqSweep_Bear)
      newState = STATE_MANIPULATION;
   else
      newState = STATE_RANGING;

   g_Market.State = newState;
   g_Market.StateLabel = GetStateLabel(newState);
}

//+------------------------------------------------------------------+
//| AI SCORING ENGINE                                               |
//+------------------------------------------------------------------+
void RunAIScoring()
{
   ZeroMemory(g_AIScore);

   // --- 1. Trend Quality Score (0-100) ---
   double trendScore = ScoreTrend();

   // --- 2. Structure Quality Score ---
   double structScore = ScoreStructure();

   // --- 3. Liquidity Quality Score ---
   double liqScore = ScoreLiquidity();

   // --- 4. Order Block Quality Score ---
   double obScore = ScoreOrderBlocks();

   // --- 5. FVG Quality Score ---
   double fvgScore = ScoreFVG();

   // --- 6. Volatility Quality Score ---
   double volScore = ScoreVolatility();

   // --- 7. Session Quality Score ---
   double sessScore = ScoreSession();

   // --- 8. News Environment Score ---
   double newsScore = ScoreNewsEnvironment();

   // --- 9. Execution Quality Score ---
   double execScore = ScoreExecution();

   // --- 10. Historical Performance Score ---
   double histScore = ScoreHistorical();

   // Store individual scores
   g_AIScore.TrendScore     = trendScore;
   g_AIScore.StructureScore = structScore;
   g_AIScore.LiquidityScore = liqScore;
   g_AIScore.OrderBlockScore= obScore;
   g_AIScore.FVGScore       = fvgScore;
   g_AIScore.VolatilityScore= volScore;
   g_AIScore.SessionScore   = sessScore;
   g_AIScore.NewsScore      = newsScore;
   g_AIScore.ExecutionScore = execScore;
   g_AIScore.HistoricalScore= histScore;

   // --- Adaptive Weighted Total Score ---
   // Session weight modulated by learning
   double sessWeight = GetSessionWeight();

   double weightedSum =
      trendScore   * 0.20 +
      structScore  * 0.18 +
      liqScore     * 0.12 +
      obScore      * 0.12 +
      fvgScore     * 0.08 +
      volScore     * 0.08 +
      sessScore    * sessWeight * 0.10 +
      newsScore    * 0.06 +
      execScore    * 0.03 +
      histScore    * 0.03;

   // Normalize if session weight != 1.0
   double totalWeight = 0.20+0.18+0.12+0.12+0.08+0.08+(sessWeight*0.10)+0.06+0.03+0.03;
   g_AIScore.TotalScore = (totalWeight > 0) ? (weightedSum / totalWeight) * 100.0 : 0;
   g_AIScore.TotalScore = MathMin(100, MathMax(0, g_AIScore.TotalScore));

   // AI Confidence = total score modulated by market confidence
   g_AIScore.Confidence = (g_AIScore.TotalScore * 0.75) +
                          (g_Market.MarketConfidence * 0.25);
   g_AIScore.Confidence = MathMin(100, MathMax(0, g_AIScore.Confidence));

   // Assign Setup Grade
   g_AIScore.Grade = AssignGrade(g_AIScore.Confidence);

   // Determine direction
   g_AIScore.Direction = DetermineTradeDirection();

   // Trade permission
   g_AIScore.TradePermitted =
      (g_AIScore.Confidence >= MinAIConfidence) &&
      (g_AIScore.TotalScore  >= MinTradeScore)  &&
      (g_AIScore.Direction   != DIR_NONE)        &&
      (!RequireGradeA || g_AIScore.Grade <= GRADE_A);
}

//+------------------------------------------------------------------+
//| SCORING SUBFUNCTIONS                                            |
//+------------------------------------------------------------------+

double ScoreTrend()
{
   double score = 50.0;

   // HTF/MTF alignment bonus
   if(g_Market.HTFBias == g_Market.MTFBias &&
      g_Market.MTFBias == g_Market.LTFBias)
      score += 35.0;
   else if(g_Market.HTFBias == g_Market.MTFBias)
      score += 20.0;
   else if(g_Market.HTFBias == g_Market.LTFBias)
      score += 10.0;
   else
      score -= 10.0;

   // Trending state bonus
   if(g_Market.State == STATE_TRENDING_BULL || g_Market.State == STATE_TRENDING_BEAR)
      score += 15.0;
   else if(g_Market.State == STATE_RANGING)
      score -= 15.0;

   return MathMin(100, MathMax(0, score));
}

double ScoreStructure()
{
   double score = 30.0;
   score += g_SMC.SetupStrength * 7.0;

   if(g_SMC.BOS_Bull  || g_SMC.BOS_Bear)   score += 10.0;
   if(g_SMC.CHOCH_Bull|| g_SMC.CHOCH_Bear) score += 10.0;

   return MathMin(100, MathMax(0, score));
}

double ScoreLiquidity()
{
   double score = 40.0;
   if(g_SMC.LiqSweep_Bull || g_SMC.LiqSweep_Bear) score += 30.0;
   if(g_SMC.EqualHighs    || g_SMC.EqualLows)     score += 20.0;
   if(g_SMC.InDiscount    && g_Market.HTFBias == BIAS_BULLISH) score += 10.0;
   if(g_SMC.InPremium     && g_Market.HTFBias == BIAS_BEARISH) score += 10.0;
   return MathMin(100, MathMax(0, score));
}

double ScoreOrderBlocks()
{
   double score = 20.0;
   if(g_SMC.OrderBlock_Bull || g_SMC.OrderBlock_Bear) score += 60.0;
   if(g_SMC.BreakerBlock_Bull|| g_SMC.BreakerBlock_Bear) score += 20.0;
   return MathMin(100, MathMax(0, score));
}

double ScoreFVG()
{
   double score = 20.0;
   if(g_SMC.FVG_Bull || g_SMC.FVG_Bear) score += 60.0;
   return MathMin(100, MathMax(0, score));
}

double ScoreVolatility()
{
   double score = 50.0;
   double vol = g_Market.Volatility;

   // Ideal volatility for scalping: 35-70
   if(vol >= 35 && vol <= 70) score += 30.0;
   else if(vol > 70)          score -= 20.0;
   else if(vol < 25)          score -= 30.0;

   // State-based
   if(g_Market.State == STATE_COMPRESSION) score -= 20.0;
   if(g_Market.State == STATE_EXPANSION)   score += 10.0;

   return MathMin(100, MathMax(0, score));
}

double ScoreSession()
{
   double score = 0.0;
   switch(g_Market.CurrentSession)
   {
      case SESSION_OVERLAP:   score = 95.0; break;
      case SESSION_NEW_YORK:  score = 85.0; break;
      case SESSION_LONDON:    score = 80.0; break;
      case SESSION_ASIAN:     score = 40.0; break;
      case SESSION_CLOSED:    score = 0.0;  break;
   }
   return score;
}

double ScoreNewsEnvironment()
{
   if(g_Market.HighImpactNear) return 10.0;
   if(g_Market.NewsRisk)       return 40.0;
   return 90.0;
}

double ScoreExecution()
{
   double score = 80.0;
   double spreadLimit = MaxSpreadPoints * _Point;
   if(g_Market.Spread > spreadLimit)
      score -= 50.0;
   else if(g_Market.Spread > spreadLimit * 0.7)
      score -= 20.0;
   return MathMin(100, MathMax(0, score));
}

double ScoreHistorical()
{
   // Modulate by learned win rate
   double score = 50.0;
   if(g_Perf.TotalTrades >= 10)
   {
      score = g_Perf.WinRate;
      if(g_Perf.ProfitFactor > 1.5) score += 10.0;
      else if(g_Perf.ProfitFactor < 1.0) score -= 20.0;
   }
   return MathMin(100, MathMax(0, score));
}

double GetSessionWeight()
{
   int sessIdx = (int)g_Market.CurrentSession;
   if(sessIdx < 0 || sessIdx > 3) return 1.0;
   return g_SessionPerf[sessIdx].Weight;
}

ENUM_SETUP_GRADE AssignGrade(double confidence)
{
   if(confidence >= 90) return GRADE_A_PLUS;
   if(confidence >= 80) return GRADE_A;
   if(confidence >= 70) return GRADE_B;
   if(confidence >= 60) return GRADE_C;
   return GRADE_NO_SETUP;
}

ENUM_TRADE_DIRECTION DetermineTradeDirection()
{
   bool bullConditions =
      g_Market.HTFBias == BIAS_BULLISH &&
      (g_SMC.BOS_Bull || g_SMC.LiqSweep_Bull || g_SMC.OrderBlock_Bull || g_SMC.FVG_Bull) &&
      (g_SMC.InDiscount || g_SMC.InFairValue);

   bool bearConditions =
      g_Market.HTFBias == BIAS_BEARISH &&
      (g_SMC.BOS_Bear || g_SMC.LiqSweep_Bear || g_SMC.OrderBlock_Bear || g_SMC.FVG_Bear) &&
      (g_SMC.InPremium || g_SMC.InFairValue);

   if(bullConditions && !bearConditions) return DIR_LONG;
   if(bearConditions && !bullConditions) return DIR_SHORT;

   // Both present: higher confidence wins
   if(bullConditions && bearConditions)
   {
      if(g_Market.HTFBias == BIAS_BULLISH) return DIR_LONG;
      if(g_Market.HTFBias == BIAS_BEARISH) return DIR_SHORT;
   }

   return DIR_NONE;
}

//+------------------------------------------------------------------+
//| TRADE EXECUTION GATE                                            |
//+------------------------------------------------------------------+
bool CanTrade()
{
   if(!EA_Active)            return false;
   if(g_EmergencyStop)       return false;
   if(g_Equity.DailyLimitHit)   return false;
   if(g_Equity.WeeklyLimitHit)  return false;
   if(g_Equity.MonthlyLimitHit) return false;
   if(g_Equity.EquityProtectionHit) return false;
   if(g_Equity.ConsecLossLimit)  return false;
   if(g_Market.CurrentSession == SESSION_CLOSED) return false;
   if(!IsSessionAllowed())   return false;
   if(g_Market.HighImpactNear && PauseOnHighImpact) return false;

   // Count today's trades
   if(g_Perf.TodayTrades >= MaxTradesPerDay) return false;

   // Count open trades
   if(CountOpenTrades() >= MaxOpenTrades) return false;

   return true;
}

bool IsSessionAllowed()
{
   switch(g_Market.CurrentSession)
   {
      case SESSION_ASIAN:   return TradeAsian;
      case SESSION_LONDON:  return TradeLondon;
      case SESSION_NEW_YORK:return TradeNewYork;
      case SESSION_OVERLAP: return TradeOverlap;
      default:              return false;
   }
}

//+------------------------------------------------------------------+
//| ENTRY SIGNAL EVALUATION                                         |
//+------------------------------------------------------------------+
void EvaluateEntrySignal()
{
   if(!g_AIScore.TradePermitted) return;

   double price  = SymbolInfoDouble(Symbol(), SYMBOL_BID);
   double ask    = SymbolInfoDouble(Symbol(), SYMBOL_ASK);
   double spread = ask - price;
   double atr    = g_Market.ATR_M15;

   if(atr <= 0) return;

   // Spread check
   if(spread > MaxSpreadPoints * _Point) return;

   double sl = 0, tp = 0, entryPrice = 0;
   ENUM_ORDER_TYPE orderType;

   if(g_AIScore.Direction == DIR_LONG)
   {
      entryPrice = ask;
      sl = entryPrice - atr * SL_ATR_Multiplier;
      tp = entryPrice + atr * SL_ATR_Multiplier * TP_RR_Ratio;
      orderType = ORDER_TYPE_BUY;
   }
   else if(g_AIScore.Direction == DIR_SHORT)
   {
      entryPrice = price;
      sl = entryPrice + atr * SL_ATR_Multiplier;
      tp = entryPrice - atr * SL_ATR_Multiplier * TP_RR_Ratio;
      orderType = ORDER_TYPE_SELL;
   }
   else return;

   // Calculate lot size
   double lotSize = CalculateLotSize(sl, entryPrice);
   if(lotSize <= 0) return;

   // Execute trade
   ExecuteTrade(orderType, entryPrice, sl, tp, lotSize);
}

//+------------------------------------------------------------------+
//| ADAPTIVE LOT SIZE CALCULATION                                   |
//+------------------------------------------------------------------+
double CalculateLotSize(double sl, double entry)
{
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double equity  = AccountInfoDouble(ACCOUNT_EQUITY);
   double useBalance = MathMin(balance, equity);

   // Adaptive risk: scale with AI confidence
   double riskPct = RiskPerTrade;
   if(g_AIScore.Confidence >= 90)
      riskPct = MathMin(MaxRiskPerTrade, RiskPerTrade * 1.5);
   else if(g_AIScore.Confidence >= 85)
      riskPct = MathMin(MaxRiskPerTrade, RiskPerTrade * 1.2);
   else if(g_AIScore.Confidence < 75)
      riskPct = RiskPerTrade * 0.7;

   // Capital preservation mode: reduce risk during drawdown
   if(CapitalPreservation && g_Equity.CurrentDrawdown > 5.0)
      riskPct *= 0.5;

   double riskAmount = useBalance * riskPct / 100.0;
   double slPoints   = MathAbs(entry - sl) / _Point;
   if(slPoints <= 0) return 0;

   double tickValue = SymbolInfoDouble(Symbol(), SYMBOL_TRADE_TICK_VALUE);
   double tickSize  = SymbolInfoDouble(Symbol(), SYMBOL_TRADE_TICK_SIZE);

   if(tickSize <= 0 || tickValue <= 0) return 0;

   double lotSize = riskAmount / (slPoints * tickValue / tickSize);

   // Normalize to broker lot constraints
   double lotMin  = SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_MIN);
   double lotMax  = SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_MAX);
   double lotStep = SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_STEP);

   lotSize = MathMax(lotMin, MathMin(lotMax, lotSize));
   lotSize = MathRound(lotSize / lotStep) * lotStep;

   return NormalizeDouble(lotSize, 2);
}

//+------------------------------------------------------------------+
//| INSTITUTIONAL EXECUTION ENGINE                                  |
//+------------------------------------------------------------------+
void ExecuteTrade(ENUM_ORDER_TYPE type, double price, double sl, double tp, double lots)
{
   // Pre-execution quality checks
   if(!VerifyExecutionQuality()) return;

   string comment = TradeComment + "_" +
                    DoubleToString(g_AIScore.Confidence, 1) + "_" +
                    GetGradeLabel(g_AIScore.Grade);

   bool success = false;
   for(int attempt = 1; attempt <= MaxRetries; attempt++)
   {
      if(type == ORDER_TYPE_BUY)
         success = g_Trade.Buy(lots, Symbol(), 0, sl, tp, comment);
      else
         success = g_Trade.Sell(lots, Symbol(), 0, sl, tp, comment);

      if(success)
      {
         Print("TRADE OPENED | Type:", EnumToString(type),
               " | Lots:", lots, " | SL:", sl, " | TP:", tp,
               " | AI:", DoubleToString(g_AIScore.Confidence, 1), "%",
               " | Grade:", GetGradeLabel(g_AIScore.Grade));

         g_Perf.TodayTrades++;

         // Alert
         if(AlertOnTrade)
         {
            string msg = "PSPX TRADE: " + (type==ORDER_TYPE_BUY?"BUY":"SELL") +
                         " | AI: " + DoubleToString(g_AIScore.Confidence,1) + "%" +
                         " | Grade: " + GetGradeLabel(g_AIScore.Grade);
            Alert(msg);
            if(AlertPushNotify) SendNotification(msg);
            if(AlertEmail)      SendMail("PSPX Trade Alert", msg);
         }
         break;
      }
      else
      {
         Print("Trade attempt ", attempt, " failed. Error: ", GetLastError());
         Sleep(RetryDelay);
         // Refresh price on retry
         if(type == ORDER_TYPE_BUY)
            price = SymbolInfoDouble(Symbol(), SYMBOL_ASK);
         else
            price = SymbolInfoDouble(Symbol(), SYMBOL_BID);
      }
   }

   if(!success)
      Print("ERROR: Trade execution failed after ", MaxRetries, " attempts");
}

bool VerifyExecutionQuality()
{
   // Spread check
   double spread = (SymbolInfoDouble(Symbol(), SYMBOL_ASK) -
                    SymbolInfoDouble(Symbol(), SYMBOL_BID));
   if(spread > MaxSpreadPoints * _Point) return false;

   // Basic tick availability
   if(SymbolInfoDouble(Symbol(), SYMBOL_BID) <= 0) return false;

   return true;
}

//+------------------------------------------------------------------+
//| TRADE MANAGEMENT ENGINE                                         |
//+------------------------------------------------------------------+
void ManageOpenTrades()
{
   // Scan all open positions with our magic number
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(!g_Position.SelectByIndex(i)) continue;
      if(g_Position.Magic() != MagicNumber) continue;
      if(g_Position.Symbol() != Symbol()) continue;

      // Check for time-based exit (news protection)
      if(g_Market.HighImpactNear && PauseOnHighImpact)
      {
         ClosePosition(g_Position.Ticket(), "NewsRiskClose");
         continue;
      }
   }
}

void ManageTrailingStop()
{
   if(!UseTrailingStop) return;

   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(!g_Position.SelectByIndex(i)) continue;
      if(g_Position.Magic()  != MagicNumber) continue;
      if(g_Position.Symbol() != Symbol()) continue;

      double atr     = g_Market.ATR_M15;
      double trailDist = atr * TrailATR_Multiplier;
      double currentSL = g_Position.StopLoss();
      double price;

      if(g_Position.PositionType() == POSITION_TYPE_BUY)
      {
         price = SymbolInfoDouble(Symbol(), SYMBOL_BID);
         double newSL = price - trailDist;
         if(newSL > currentSL + _Point * 2)
            g_Trade.PositionModify(g_Position.Ticket(), newSL, g_Position.TakeProfit());
      }
      else
      {
         price = SymbolInfoDouble(Symbol(), SYMBOL_ASK);
         double newSL = price + trailDist;
         if(newSL < currentSL - _Point * 2 || currentSL == 0)
            g_Trade.PositionModify(g_Position.Ticket(), newSL, g_Position.TakeProfit());
      }
   }
}

void CheckBreakEven()
{
   if(!UseBreakEven) return;

   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(!g_Position.SelectByIndex(i)) continue;
      if(g_Position.Magic()  != MagicNumber) continue;
      if(g_Position.Symbol() != Symbol()) continue;

      double openPrice = g_Position.PriceOpen();
      double currentSL = g_Position.StopLoss();
      double atr = g_Market.ATR_M15;
      double beTrigger = atr * SL_ATR_Multiplier * BE_TriggerRR;

      if(g_Position.PositionType() == POSITION_TYPE_BUY)
      {
         double price = SymbolInfoDouble(Symbol(), SYMBOL_BID);
         double beLevel = openPrice + 2 * _Point; // BE + small buffer
         if((price - openPrice) >= beTrigger && currentSL < beLevel)
            g_Trade.PositionModify(g_Position.Ticket(), beLevel, g_Position.TakeProfit());
      }
      else
      {
         double price = SymbolInfoDouble(Symbol(), SYMBOL_ASK);
         double beLevel = openPrice - 2 * _Point;
         if((openPrice - price) >= beTrigger && (currentSL > beLevel || currentSL == 0))
            g_Trade.PositionModify(g_Position.Ticket(), beLevel, g_Position.TakeProfit());
      }
   }
}

void CheckPartialClose()
{
   if(!UsePartialClose) return;

   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(!g_Position.SelectByIndex(i)) continue;
      if(g_Position.Magic()  != MagicNumber) continue;
      if(g_Position.Symbol() != Symbol()) continue;

      double openPrice = g_Position.PriceOpen();
      double atr = g_Market.ATR_M15;
      double partialTrigger = atr * SL_ATR_Multiplier * PartialCloseRR;
      double currentVol = g_Position.Volume();

      if(g_Position.PositionType() == POSITION_TYPE_BUY)
      {
         double price = SymbolInfoDouble(Symbol(), SYMBOL_BID);
         if((price - openPrice) >= partialTrigger && currentVol > 0)
         {
            double closeVol = NormalizeDouble(currentVol * PartialClosePercent / 100.0,
                                              (int)MathLog10(1.0 / SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_STEP)));
            if(closeVol >= SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_MIN))
               g_Trade.PositionClosePartial(g_Position.Ticket(), closeVol);
         }
      }
      else
      {
         double price = SymbolInfoDouble(Symbol(), SYMBOL_ASK);
         if((openPrice - price) >= partialTrigger && currentVol > 0)
         {
            double closeVol = NormalizeDouble(currentVol * PartialClosePercent / 100.0,
                                              (int)MathLog10(1.0 / SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_STEP)));
            if(closeVol >= SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_MIN))
               g_Trade.PositionClosePartial(g_Position.Ticket(), closeVol);
         }
      }
   }
}

void ClosePosition(ulong ticket, string reason)
{
   if(g_Trade.PositionClose(ticket))
      Print("Position ", ticket, " closed. Reason: ", reason);
}

int CountOpenTrades()
{
   int count = 0;
   for(int i = 0; i < PositionsTotal(); i++)
   {
      if(g_Position.SelectByIndex(i))
         if(g_Position.Magic() == MagicNumber && g_Position.Symbol() == Symbol())
            count++;
   }
   return count;
}

//+------------------------------------------------------------------+
//| EQUITY & RISK MANAGEMENT                                        |
//+------------------------------------------------------------------+
void InitEquityStats()
{
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   g_Equity.PeakEquity   = equity;
   g_Equity.DailyStart   = equity;
   g_Equity.WeeklyStart  = equity;
   g_Equity.MonthlyStart = equity;
   g_Equity.DailyPnL     = 0;
   g_Equity.WeeklyPnL    = 0;
   g_Equity.MonthlyPnL   = 0;
   g_Equity.CurrentDrawdown = 0;
   g_Equity.MaxDrawdown  = 0;
   g_Equity.ConsecLosses = 0;
   g_Equity.ConsecWins   = 0;
   g_Equity.DailyLimitHit   = false;
   g_Equity.WeeklyLimitHit  = false;
   g_Equity.MonthlyLimitHit = false;
   g_Equity.EquityProtectionHit = false;
   g_Equity.ConsecLossLimit = false;
}

void UpdateEquityStats()
{
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);

   // Update peak
   if(equity > g_Equity.PeakEquity)
      g_Equity.PeakEquity = equity;

   // Current drawdown from peak
   if(g_Equity.PeakEquity > 0)
      g_Equity.CurrentDrawdown = (g_Equity.PeakEquity - equity) / g_Equity.PeakEquity * 100.0;
   else
      g_Equity.CurrentDrawdown = 0;

   g_Equity.MaxDrawdown = MathMax(g_Equity.MaxDrawdown, g_Equity.CurrentDrawdown);

   // Period PnL
   g_Equity.DailyPnL   = equity - g_Equity.DailyStart;
   g_Equity.WeeklyPnL  = equity - g_Equity.WeeklyStart;
   g_Equity.MonthlyPnL = equity - g_Equity.MonthlyStart;

   // Limit checks
   if(g_Equity.DailyStart > 0)
      g_Equity.DailyLimitHit =
         ((g_Equity.DailyStart - equity) / g_Equity.DailyStart * 100.0) >= DailyDrawdownLimit;

   if(g_Equity.WeeklyStart > 0)
      g_Equity.WeeklyLimitHit =
         ((g_Equity.WeeklyStart - equity) / g_Equity.WeeklyStart * 100.0) >= WeeklyDrawdownLimit;

   if(g_Equity.MonthlyStart > 0)
      g_Equity.MonthlyLimitHit =
         ((g_Equity.MonthlyStart - equity) / g_Equity.MonthlyStart * 100.0) >= MonthlyDrawdownLimit;

   if(g_Equity.PeakEquity > 0)
      g_Equity.EquityProtectionHit =
         ((g_Equity.PeakEquity - equity) / g_Equity.PeakEquity * 100.0) >= EquityProtection;

   g_Equity.ConsecLossLimit = (g_Equity.ConsecLosses >= MaxConsecLosses);
}

bool CheckEmergencyStop()
{
   if(g_Equity.EquityProtectionHit)
   {
      if(!g_EmergencyStop)
      {
         g_EmergencyStop = true;
         CloseAllPositions();
         Alert("PSPX EMERGENCY STOP: Equity protection triggered!");
         Print("EMERGENCY STOP: Equity drawdown exceeded ", EquityProtection, "%");
      }
      return true;
   }
   return false;
}

void CloseAllPositions()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(g_Position.SelectByIndex(i))
         if(g_Position.Magic() == MagicNumber)
            g_Trade.PositionClose(g_Position.Ticket());
   }
}

void UpdatePeriodAnchors()
{
   datetime now = TimeCurrent();
   MqlDateTime dt;
   TimeToStruct(now, dt);

   // New day
   datetime newDayStart = GetDayStart();
   if(newDayStart != g_DayStart)
   {
      g_DayStart = newDayStart;
      g_Equity.DailyStart = AccountInfoDouble(ACCOUNT_EQUITY);
      g_Equity.DailyLimitHit = false;
      g_Perf.TodayTrades = 0;
      Print("New trading day started. Equity anchor: ", g_Equity.DailyStart);
   }

   // New week
   datetime newWeekStart = GetWeekStart();
   if(newWeekStart != g_WeekStart)
   {
      g_WeekStart = newWeekStart;
      g_Equity.WeeklyStart = AccountInfoDouble(ACCOUNT_EQUITY);
      g_Equity.WeeklyLimitHit = false;
      g_Equity.ConsecLossLimit = false;
      g_Equity.ConsecLosses = 0;
   }

   // New month
   datetime newMonthStart = GetMonthStart();
   if(newMonthStart != g_MonthStart)
   {
      g_MonthStart = newMonthStart;
      g_Equity.MonthlyStart = AccountInfoDouble(ACCOUNT_EQUITY);
      g_Equity.MonthlyLimitHit = false;
   }
}

//+------------------------------------------------------------------+
//| ONTRADE EVENT - Trade closed handler                            |
//+------------------------------------------------------------------+
void OnTrade()
{
   // Scan closed deals and update performance
   HistorySelect(g_DayStart, TimeCurrent());
   int deals = HistoryDealsTotal();

   for(int i = deals - 1; i >= 0; i--)
   {
      ulong ticket = HistoryDealGetTicket(i);
      if(HistoryDealGetInteger(ticket, DEAL_MAGIC) != MagicNumber) continue;
      if(HistoryDealGetInteger(ticket, DEAL_ENTRY) != DEAL_ENTRY_OUT) continue;

      double profit = HistoryDealGetDouble(ticket, DEAL_PROFIT);
      double swap   = HistoryDealGetDouble(ticket, DEAL_SWAP);
      double commission = HistoryDealGetDouble(ticket, DEAL_COMMISSION);
      double netProfit = profit + swap + commission;

      // Update consecutive win/loss
      if(netProfit >= 0)
      {
         g_Equity.ConsecWins++;
         g_Equity.ConsecLosses = 0;
      }
      else
      {
         g_Equity.ConsecLosses++;
         g_Equity.ConsecWins = 0;
      }

      // Update performance metrics
      UpdatePerformanceMetrics(netProfit);

      // Update adaptive session weights
      UpdateSessionWeights(netProfit);

      // Record to database
      RecordTrade(ticket, netProfit);

      break; // Only process the most recent closed deal
   }
}

void UpdatePerformanceMetrics(double netProfit)
{
   g_Perf.TotalTrades++;
   g_Perf.TotalProfit += netProfit;

   if(netProfit >= 0)
   {
      g_Perf.WinTrades++;
      g_Perf.AvgWin = (g_Perf.AvgWin * (g_Perf.WinTrades - 1) + netProfit) / g_Perf.WinTrades;
   }
   else
   {
      g_Perf.LossTrades++;
      g_Perf.AvgLoss = (g_Perf.AvgLoss * (g_Perf.LossTrades - 1) + MathAbs(netProfit)) /
                        g_Perf.LossTrades;
   }

   if(g_Perf.TotalTrades > 0)
      g_Perf.WinRate = (double)g_Perf.WinTrades / g_Perf.TotalTrades * 100.0;

   if(g_Perf.AvgLoss > 0)
      g_Perf.ProfitFactor = (g_Perf.AvgWin * g_Perf.WinTrades) /
                             (g_Perf.AvgLoss * g_Perf.LossTrades);

   g_Perf.Expectancy = (g_Perf.WinRate/100.0 * g_Perf.AvgWin) -
                        ((1-g_Perf.WinRate/100.0) * g_Perf.AvgLoss);
}

//+------------------------------------------------------------------+
//| ADAPTIVE SESSION WEIGHTS (Reinforcement Learning Proxy)         |
//+------------------------------------------------------------------+
void InitSessionPerformance()
{
   // Default weights
   for(int i = 0; i < 4; i++)
   {
      g_SessionPerf[i].Weight = 1.0;
      g_SessionPerf[i].Trades = 0;
      g_SessionPerf[i].Wins   = 0;
      g_SessionPerf[i].WinRate = 50.0;
   }
}

void UpdateSessionWeights(double netProfit)
{
   int sessIdx = (int)g_Market.CurrentSession;
   if(sessIdx < 0 || sessIdx > 3) return;

   g_SessionPerf[sessIdx].Trades++;
   g_SessionPerf[sessIdx].TotalProfit += netProfit;

   if(netProfit >= 0) g_SessionPerf[sessIdx].Wins++;

   g_SessionPerf[sessIdx].WinRate =
      (double)g_SessionPerf[sessIdx].Wins /
      g_SessionPerf[sessIdx].Trades * 100.0;

   // Adaptive weight: range 0.5 - 1.5
   // Reward profitable sessions, penalize losing ones
   if(g_SessionPerf[sessIdx].Trades >= 5)
   {
      double winRate = g_SessionPerf[sessIdx].WinRate;
      // Map 0-100% win rate to 0.5-1.5 weight
      g_SessionPerf[sessIdx].Weight = 0.5 + (winRate / 100.0);
   }
}

void InitSetupPerformance()
{
   string setups[] = {"BOS_Bull","BOS_Bear","CHOCH_Bull","CHOCH_Bear",
                      "LiqSweep","FVG","OrderBlock","Mixed"};
   for(int i = 0; i < 8; i++)
   {
      g_SetupPerf[i].SetupName = setups[i];
      g_SetupPerf[i].Weight    = 1.0;
      g_SetupPerf[i].Trades    = 0;
   }
}

//+------------------------------------------------------------------+
//| SELF-LEARNING DATABASE                                          |
//+------------------------------------------------------------------+
void LoadTradeDatabase()
{
   int handle = FileOpen(g_DBFileName, FILE_READ | FILE_CSV | FILE_COMMON);
   if(handle == INVALID_HANDLE)
   {
      Print("No existing trade DB found. Starting fresh.");
      return;
   }

   int count = 0;
   // Skip header
   if(!FileIsEnding(handle)) FileReadString(handle);

   while(!FileIsEnding(handle))
   {
      string line = FileReadString(handle);
      if(StringLen(line) < 10) continue;

      // Parse CSV: profit, winrate contribution
      string parts[];
      int numParts = StringSplit(line, ',', parts);
      if(numParts < 3) continue;

      double profit = StringToDouble(parts[2]);
      g_Perf.TotalTrades++;
      g_Perf.TotalProfit += profit;
      if(profit >= 0)
      {
         g_Perf.WinTrades++;
         g_Perf.AvgWin += profit;
      }
      else
      {
         g_Perf.LossTrades++;
         g_Perf.AvgLoss += MathAbs(profit);
      }
      count++;
   }

   FileClose(handle);

   // Finalize stats
   if(g_Perf.TotalTrades > 0)
      g_Perf.WinRate = (double)g_Perf.WinTrades / g_Perf.TotalTrades * 100.0;
   if(g_Perf.WinTrades > 0)
      g_Perf.AvgWin  /= g_Perf.WinTrades;
   if(g_Perf.LossTrades > 0)
      g_Perf.AvgLoss /= g_Perf.LossTrades;
   if(g_Perf.AvgLoss > 0 && g_Perf.LossTrades > 0)
      g_Perf.ProfitFactor = (g_Perf.AvgWin * g_Perf.WinTrades) /
                             (g_Perf.AvgLoss * g_Perf.LossTrades);

   Print("Trade DB loaded: ", count, " historical trades. WinRate: ",
         DoubleToString(g_Perf.WinRate, 1), "%");
}

void SaveTradeDatabase()
{
   // Save session weights for persistence
   string sessFile = "PSPX_SessionWeights_" + Symbol() + ".csv";
   int handle = FileOpen(sessFile, FILE_WRITE | FILE_CSV | FILE_COMMON);
   if(handle == INVALID_HANDLE) return;

   FileWrite(handle, "Session,Trades,Wins,WinRate,Weight");
   string sessNames[] = {"Asian","London","NewYork","Overlap"};
   for(int i = 0; i < 4; i++)
   {
      FileWrite(handle,
         sessNames[i] + "," +
         IntegerToString(g_SessionPerf[i].Trades) + "," +
         IntegerToString(g_SessionPerf[i].Wins) + "," +
         DoubleToString(g_SessionPerf[i].WinRate, 2) + "," +
         DoubleToString(g_SessionPerf[i].Weight, 4));
   }
   FileClose(handle);
}

void RecordTrade(ulong ticket, double netProfit)
{
   int handle = FileOpen(g_DBFileName,
                         FILE_READ | FILE_WRITE | FILE_CSV | FILE_COMMON);
   if(handle == INVALID_HANDLE)
   {
      handle = FileOpen(g_DBFileName,
                        FILE_WRITE | FILE_CSV | FILE_COMMON);
      if(handle == INVALID_HANDLE) return;
      FileWrite(handle, "Ticket,Time,Profit,AIConf,Grade,Session,State,Spread,ATR");
   }

   FileSeek(handle, 0, SEEK_END);
   FileWrite(handle,
      IntegerToString((int)ticket) + "," +
      TimeToString(TimeCurrent()) + "," +
      DoubleToString(netProfit, 2) + "," +
      DoubleToString(g_AIScore.Confidence, 1) + "," +
      GetGradeLabel(g_AIScore.Grade) + "," +
      IntegerToString((int)g_Market.CurrentSession) + "," +
      IntegerToString((int)g_Market.State) + "," +
      DoubleToString(g_Market.Spread / _Point, 1) + "," +
      DoubleToString(g_Market.ATR_M15 / _Point, 1));

   FileClose(handle);
}

//+------------------------------------------------------------------+
//| INSTITUTIONAL DASHBOARD                                         |
//+------------------------------------------------------------------+
void BuildDashboard()
{
   // Remove any existing dashboard objects
   RemoveDashboard();

   // Dashboard dimensions
   int panelW = 310;
   int panelH = 720;
   int x = DashboardX;
   int y = DashboardY;

   // --- Main Background Panel ---
   CreateRect("PSPXBg", x, y, panelW, panelH, DashBGColor, 210);
   CreateRect("PSPXBorder", x, y, panelW, 3, AccentColor, 255);

   // --- Header ---
   CreateLabel("PSPXTitle",   x+10, y+10,  "⚡ PHANTOM SCALPER PRO X",  AccentColor,  12, "Arial Bold");
   CreateLabel("PSPXSubtitle",x+10, y+28,  "Institutional AI Gold Engine", NeutralColor, 8, "Arial");
   CreateLabel("PSPXSymbol",  x+10, y+46,  Symbol() + " | AI-Powered", C'255,200,0', 8, "Arial Bold");
   CreateRect ("PSPXDiv1",    x+5,  y+60,  panelW-10, 1, C'40,50,70', 200);

   // --- AI Status Section ---
   CreateLabel("LblAI",  x+10, y+68,  "◈ AI INTELLIGENCE",  AccentColor, 9, "Arial Bold");
   CreateLabel("LblConf",x+10, y+84,  "AI Confidence:",      NeutralColor, 8, "Arial");
   CreateLabel("ValConf",x+170,y+84,  "0.0%",                AccentColor,  9, "Arial Bold");
   CreateLabel("LblScore",x+10,y+98,  "Trade Score:",        NeutralColor, 8, "Arial");
   CreateLabel("ValScore",x+170,y+98, "0.0%",                AccentColor,  9, "Arial Bold");
   CreateLabel("LblGrade",x+10,y+112, "Setup Grade:",        NeutralColor, 8, "Arial");
   CreateLabel("ValGrade",x+170,y+112,"---",                  ProfitColor,  9, "Arial Bold");

   CreateRect ("PSPXDiv2",x+5,y+126,  panelW-10, 1, C'40,50,70', 200);

   // --- Market State Section ---
   CreateLabel("LblMkt",  x+10, y+132, "◈ MARKET INTELLIGENCE", AccentColor, 9, "Arial Bold");
   CreateLabel("LblState",x+10, y+148, "Market State:",          NeutralColor,8,"Arial");
   CreateLabel("ValState",x+170,y+148, "UNKNOWN",                NeutralColor,8,"Arial Bold");
   CreateLabel("LblBias", x+10, y+162, "HTF Bias:",              NeutralColor,8,"Arial");
   CreateLabel("ValBias", x+170,y+162, "NEUTRAL",                NeutralColor,8,"Arial Bold");
   CreateLabel("LblMBias",x+10, y+176, "MTF Bias:",              NeutralColor,8,"Arial");
   CreateLabel("ValMBias",x+170,y+176, "NEUTRAL",                NeutralColor,8,"Arial Bold");
   CreateLabel("LblDir",  x+10, y+190, "Direction:",             NeutralColor,8,"Arial");
   CreateLabel("ValDir",  x+170,y+190, "NONE",                   NeutralColor,8,"Arial Bold");

   CreateRect ("PSPXDiv3",x+5,y+204,panelW-10, 1, C'40,50,70', 200);

   // --- SMC Section ---
   CreateLabel("LblSMC",  x+10, y+210, "◈ SMART MONEY",         AccentColor, 9, "Arial Bold");
   CreateLabel("LblBOS",  x+10, y+226, "BOS/CHOCH:",            NeutralColor,8,"Arial");
   CreateLabel("ValBOS",  x+170,y+226, "---",                   NeutralColor,8,"Arial Bold");
   CreateLabel("LblFVG",  x+10, y+240, "FVG:",                  NeutralColor,8,"Arial");
   CreateLabel("ValFVG",  x+170,y+240, "---",                   NeutralColor,8,"Arial Bold");
   CreateLabel("LblOB",   x+10, y+254, "Order Block:",          NeutralColor,8,"Arial");
   CreateLabel("ValOB",   x+170,y+254, "---",                   NeutralColor,8,"Arial Bold");
   CreateLabel("LblLiq",  x+10, y+268, "Liq Sweep:",            NeutralColor,8,"Arial");
   CreateLabel("ValLiq",  x+170,y+268, "---",                   NeutralColor,8,"Arial Bold");
   CreateLabel("LblZone", x+10, y+282, "Price Zone:",           NeutralColor,8,"Arial");
   CreateLabel("ValZone", x+170,y+282, "---",                   NeutralColor,8,"Arial Bold");

   CreateRect ("PSPXDiv4",x+5,y+296,panelW-10, 1, C'40,50,70', 200);

   // --- Session & Volatility ---
   CreateLabel("LblVol",  x+10, y+302, "◈ ENVIRONMENT",         AccentColor, 9, "Arial Bold");
   CreateLabel("LblSess", x+10, y+318, "Session:",              NeutralColor,8,"Arial");
   CreateLabel("ValSess", x+170,y+318, "---",                   AccentColor, 8,"Arial Bold");
   CreateLabel("LblVlt",  x+10, y+332, "Volatility:",           NeutralColor,8,"Arial");
   CreateLabel("ValVlt",  x+170,y+332, "---",                   NeutralColor,8,"Arial Bold");
   CreateLabel("LblSprd", x+10, y+346, "Spread:",               NeutralColor,8,"Arial");
   CreateLabel("ValSprd", x+170,y+346, "---",                   NeutralColor,8,"Arial Bold");
   CreateLabel("LblNews", x+10, y+360, "News Risk:",            NeutralColor,8,"Arial");
   CreateLabel("ValNews", x+170,y+360, "---",                   NeutralColor,8,"Arial Bold");
   CreateLabel("LblATR",  x+10, y+374, "ATR (H1):",             NeutralColor,8,"Arial");
   CreateLabel("ValATR",  x+170,y+374, "---",                   NeutralColor,8,"Arial Bold");

   CreateRect ("PSPXDiv5",x+5,y+388,panelW-10, 1, C'40,50,70', 200);

   // --- Risk & Drawdown ---
   CreateLabel("LblRisk", x+10, y+394, "◈ RISK MANAGEMENT",     AccentColor, 9, "Arial Bold");
   CreateLabel("LblDD",   x+10, y+410, "Drawdown:",             NeutralColor,8,"Arial");
   CreateLabel("ValDD",   x+170,y+410, "0.00%",                 ProfitColor, 8,"Arial Bold");
   CreateLabel("LblDayL", x+10, y+424, "Daily Limit:",          NeutralColor,8,"Arial");
   CreateLabel("ValDayL", x+170,y+424, "OK",                    ProfitColor, 8,"Arial Bold");
   CreateLabel("LblCons", x+10, y+438, "Consec Losses:",        NeutralColor,8,"Arial");
   CreateLabel("ValCons", x+170,y+438, "0",                     ProfitColor, 8,"Arial Bold");

   CreateRect ("PSPXDiv6",x+5,y+452,panelW-10, 1, C'40,50,70', 200);

   // --- Performance Stats ---
   CreateLabel("LblPerf", x+10, y+458, "◈ PERFORMANCE",         AccentColor, 9, "Arial Bold");
   CreateLabel("LblWR",   x+10, y+474, "Win Rate:",             NeutralColor,8,"Arial");
   CreateLabel("ValWR",   x+170,y+474, "0.0%",                  NeutralColor,8,"Arial Bold");
   CreateLabel("LblPF",   x+10, y+488, "Profit Factor:",        NeutralColor,8,"Arial");
   CreateLabel("ValPF",   x+170,y+488, "0.00",                  NeutralColor,8,"Arial Bold");
   CreateLabel("LblTot",  x+10, y+502, "Total Trades:",         NeutralColor,8,"Arial");
   CreateLabel("ValTot",  x+170,y+502, "0",                     NeutralColor,8,"Arial Bold");
   CreateLabel("LblDPnL", x+10, y+516, "Daily PnL:",            NeutralColor,8,"Arial");
   CreateLabel("ValDPnL", x+170,y+516, "$0.00",                 NeutralColor,8,"Arial Bold");
   CreateLabel("LblWPnL", x+10, y+530, "Weekly PnL:",           NeutralColor,8,"Arial");
   CreateLabel("ValWPnL", x+170,y+530, "$0.00",                 NeutralColor,8,"Arial Bold");
   CreateLabel("LblMPnL", x+10, y+544, "Monthly PnL:",          NeutralColor,8,"Arial");
   CreateLabel("ValMPnL", x+170,y+544, "$0.00",                 NeutralColor,8,"Arial Bold");

   CreateRect ("PSPXDiv7",x+5,y+558,panelW-10, 1, C'40,50,70', 200);

   // --- System Health ---
   CreateLabel("LblSys",  x+10, y+564, "◈ SYSTEM HEALTH",       AccentColor, 9, "Arial Bold");
   CreateLabel("LblOpen", x+10, y+580, "Open Trades:",          NeutralColor,8,"Arial");
   CreateLabel("ValOpen", x+170,y+580, "0",                     NeutralColor,8,"Arial Bold");
   CreateLabel("LblDay",  x+10, y+594, "Today's Trades:",       NeutralColor,8,"Arial");
   CreateLabel("ValDay",  x+170,y+594, "0",                     NeutralColor,8,"Arial Bold");
   CreateLabel("LblEmg",  x+10, y+608, "EA Status:",            NeutralColor,8,"Arial");
   CreateLabel("ValEmg",  x+170,y+608, "● ACTIVE",              ProfitColor, 8,"Arial Bold");
   CreateLabel("LblLearn",x+10, y+622, "Learning:",             NeutralColor,8,"Arial");
   CreateLabel("ValLearn",x+170,y+622, "ADAPTIVE",              AccentColor, 8,"Arial Bold");

   // Footer
   CreateRect ("PSPXFooterBg",x, y+panelH-24, panelW, 24, C'5,8,18', 220);
   CreateLabel("PSPXFooter",  x+10, y+panelH-14, "v4.0 | " + TimeToString(TimeCurrent(), TIME_DATE),
               C'60,80,100', 7, "Arial");

   ChartRedraw();
}

void UpdateDashboard()
{
   if(!ShowDashboard) return;

   // AI Scores
   color confColor = (g_AIScore.Confidence >= MinAIConfidence) ? ProfitColor : LossColor;
   UpdateLabel("ValConf",  DoubleToString(g_AIScore.Confidence, 1) + "%", confColor);
   UpdateLabel("ValScore", DoubleToString(g_AIScore.TotalScore, 1) + "%",
               g_AIScore.TotalScore >= MinTradeScore ? ProfitColor : LossColor);
   UpdateLabel("ValGrade", GetGradeLabel(g_AIScore.Grade),
               g_AIScore.Grade <= GRADE_A ? ProfitColor : NeutralColor);

   // Market State
   UpdateLabel("ValState", g_Market.StateLabel, GetStateColor(g_Market.State));
   UpdateLabel("ValBias",  GetBiasLabel(g_Market.HTFBias), GetBiasColor(g_Market.HTFBias));
   UpdateLabel("ValMBias", GetBiasLabel(g_Market.MTFBias), GetBiasColor(g_Market.MTFBias));
   UpdateLabel("ValDir",   GetDirLabel(g_AIScore.Direction),
               g_AIScore.Direction == DIR_LONG ? ProfitColor :
               g_AIScore.Direction == DIR_SHORT ? LossColor : NeutralColor);

   // SMC
   string bosStr = "";
   if(g_SMC.BOS_Bull)   bosStr += "BOS↑ ";
   if(g_SMC.BOS_Bear)   bosStr += "BOS↓ ";
   if(g_SMC.CHOCH_Bull) bosStr += "CHoCH↑";
   if(g_SMC.CHOCH_Bear) bosStr += "CHoCH↓";
   if(bosStr == "") bosStr = "None";
   UpdateLabel("ValBOS", bosStr, g_SMC.BOS_Bull||g_SMC.BOS_Bear||g_SMC.CHOCH_Bull||g_SMC.CHOCH_Bear ? ProfitColor : NeutralColor);

   string fvgStr = (g_SMC.FVG_Bull ? "Bull FVG" : (g_SMC.FVG_Bear ? "Bear FVG" : "None"));
   UpdateLabel("ValFVG", fvgStr, g_SMC.FVG_Bull||g_SMC.FVG_Bear ? AccentColor : NeutralColor);

   string obStr = (g_SMC.OrderBlock_Bull ? "Demand OB" : (g_SMC.OrderBlock_Bear ? "Supply OB" : "None"));
   UpdateLabel("ValOB", obStr, g_SMC.OrderBlock_Bull||g_SMC.OrderBlock_Bear ? AccentColor : NeutralColor);

   string liqStr = (g_SMC.LiqSweep_Bull ? "Bull Sweep" : (g_SMC.LiqSweep_Bear ? "Bear Sweep" : "None"));
   UpdateLabel("ValLiq", liqStr, g_SMC.LiqSweep_Bull||g_SMC.LiqSweep_Bear ? C'255,200,0' : NeutralColor);

   string zoneStr = (g_SMC.InPremium ? "PREMIUM" : (g_SMC.InDiscount ? "DISCOUNT" : "FAIR VALUE"));
   color zoneColor = g_SMC.InDiscount ? ProfitColor : (g_SMC.InPremium ? LossColor : AccentColor);
   UpdateLabel("ValZone", zoneStr, zoneColor);

   // Session & Volatility
   UpdateLabel("ValSess", GetSessionLabel(g_Market.CurrentSession), AccentColor);
   UpdateLabel("ValVlt",  DoubleToString(g_Market.Volatility, 1) + "%",
               g_Market.Volatility > 65 ? LossColor :
               g_Market.Volatility < 30 ? C'255,200,0' : ProfitColor);
   UpdateLabel("ValSprd", DoubleToString(g_Market.Spread / _Point, 1) + " pts",
               g_Market.Spread <= MaxSpreadPoints * _Point ? ProfitColor : LossColor);
   UpdateLabel("ValNews", g_Market.HighImpactNear ? "HIGH IMPACT!" : (g_Market.NewsRisk ? "MEDIUM" : "CLEAR"),
               g_Market.HighImpactNear ? LossColor : (g_Market.NewsRisk ? C'255,165,0' : ProfitColor));
   UpdateLabel("ValATR",  DoubleToString(g_Market.ATR_H1 / _Point, 1) + " pts", NeutralColor);

   // Risk
   color ddColor = g_Equity.CurrentDrawdown > DailyDrawdownLimit * 0.7 ? LossColor : ProfitColor;
   UpdateLabel("ValDD",   DoubleToString(g_Equity.CurrentDrawdown, 2) + "%", ddColor);
   UpdateLabel("ValDayL", g_Equity.DailyLimitHit ? "LIMIT HIT" : "OK",
               g_Equity.DailyLimitHit ? LossColor : ProfitColor);
   UpdateLabel("ValCons", IntegerToString(g_Equity.ConsecLosses),
               g_Equity.ConsecLosses >= MaxConsecLosses ? LossColor : ProfitColor);

   // Performance
   UpdateLabel("ValWR",   DoubleToString(g_Perf.WinRate, 1) + "%",
               g_Perf.WinRate >= 55 ? ProfitColor : (g_Perf.WinRate < 45 ? LossColor : NeutralColor));
   UpdateLabel("ValPF",   DoubleToString(g_Perf.ProfitFactor, 2),
               g_Perf.ProfitFactor >= 1.5 ? ProfitColor : (g_Perf.ProfitFactor < 1.0 ? LossColor : NeutralColor));
   UpdateLabel("ValTot",  IntegerToString(g_Perf.TotalTrades), NeutralColor);

   color dayPnLColor = g_Equity.DailyPnL >= 0 ? ProfitColor : LossColor;
   UpdateLabel("ValDPnL", "$" + DoubleToString(g_Equity.DailyPnL, 2),   dayPnLColor);
   UpdateLabel("ValWPnL", "$" + DoubleToString(g_Equity.WeeklyPnL, 2),
               g_Equity.WeeklyPnL  >= 0 ? ProfitColor : LossColor);
   UpdateLabel("ValMPnL", "$" + DoubleToString(g_Equity.MonthlyPnL, 2),
               g_Equity.MonthlyPnL >= 0 ? ProfitColor : LossColor);

   // System Health
   UpdateLabel("ValOpen", IntegerToString(CountOpenTrades()), NeutralColor);
   UpdateLabel("ValDay",  IntegerToString(g_Perf.TodayTrades) + "/" +
                          IntegerToString(MaxTradesPerDay), NeutralColor);
   UpdateLabel("ValEmg",  g_EmergencyStop ? "● EMERGENCY STOP" : "● ACTIVE",
               g_EmergencyStop ? LossColor : ProfitColor);
   UpdateLabel("ValLearn","Cycles: " + IntegerToString(g_AnalysisCycleCount), AccentColor);

   ChartRedraw();
}

//+------------------------------------------------------------------+
//| DASHBOARD HELPERS                                               |
//+------------------------------------------------------------------+
void CreateRect(string name, int x, int y, int w, int h, color clr, int alpha)
{
   if(ObjectFind(0, name) >= 0) ObjectDelete(0, name);
   ObjectCreate(0, name, OBJ_RECTANGLE_LABEL, 0, 0, 0);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE,  x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE,  y);
   ObjectSetInteger(0, name, OBJPROP_XSIZE,      w);
   ObjectSetInteger(0, name, OBJPROP_YSIZE,      h);
   ObjectSetInteger(0, name, OBJPROP_BGCOLOR,    clr);
   ObjectSetInteger(0, name, OBJPROP_BORDER_TYPE,BORDER_FLAT);
   ObjectSetInteger(0, name, OBJPROP_COLOR,      clr);
   ObjectSetInteger(0, name, OBJPROP_BACK,       false);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN,     true);
}

void CreateLabel(string name, int x, int y, string text, color clr, int fontSize, string font)
{
   if(ObjectFind(0, name) >= 0) ObjectDelete(0, name);
   ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE,  x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE,  y);
   ObjectSetString (0, name, OBJPROP_TEXT,       text);
   ObjectSetInteger(0, name, OBJPROP_COLOR,      clr);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE,   fontSize);
   ObjectSetString (0, name, OBJPROP_FONT,       font);
   ObjectSetInteger(0, name, OBJPROP_CORNER,     CORNER_LEFT_UPPER);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN,     true);
}

void UpdateLabel(string name, string text, color clr)
{
   if(ObjectFind(0, name) < 0) return;
   ObjectSetString (0, name, OBJPROP_TEXT,  text);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
}

void RemoveDashboard()
{
   string prefix = "PSPX";
   for(int i = ObjectsTotal(0) - 1; i >= 0; i--)
   {
      string objName = ObjectName(0, i);
      if(StringFind(objName, prefix) == 0)
         ObjectDelete(0, objName);
   }
   ChartRedraw();
}

//+------------------------------------------------------------------+
//| LABEL HELPERS                                                   |
//+------------------------------------------------------------------+
string GetStateLabel(ENUM_MARKET_STATE state)
{
   switch(state)
   {
      case STATE_TRENDING_BULL:  return "TRENDING BULL";
      case STATE_TRENDING_BEAR:  return "TRENDING BEAR";
      case STATE_RANGING:        return "RANGING";
      case STATE_ACCUMULATION:   return "ACCUMULATION";
      case STATE_DISTRIBUTION:   return "DISTRIBUTION";
      case STATE_EXPANSION:      return "EXPANSION";
      case STATE_COMPRESSION:    return "COMPRESSION";
      case STATE_HIGH_VOLATILITY:return "HIGH VOLATILITY";
      case STATE_LOW_VOLATILITY: return "LOW VOLATILITY";
      case STATE_MANIPULATION:   return "MANIPULATION";
      case STATE_NEWS_EVENT:     return "NEWS EVENT";
      default:                   return "UNKNOWN";
   }
}

color GetStateColor(ENUM_MARKET_STATE state)
{
   switch(state)
   {
      case STATE_TRENDING_BULL:  return ProfitColor;
      case STATE_TRENDING_BEAR:  return LossColor;
      case STATE_HIGH_VOLATILITY:return LossColor;
      case STATE_NEWS_EVENT:     return LossColor;
      case STATE_EXPANSION:      return AccentColor;
      default:                   return NeutralColor;
   }
}

string GetBiasLabel(ENUM_INST_BIAS bias)
{
   switch(bias)
   {
      case BIAS_BULLISH: return "BULLISH";
      case BIAS_BEARISH: return "BEARISH";
      default:           return "NEUTRAL";
   }
}

color GetBiasColor(ENUM_INST_BIAS bias)
{
   switch(bias)
   {
      case BIAS_BULLISH: return ProfitColor;
      case BIAS_BEARISH: return LossColor;
      default:           return NeutralColor;
   }
}

string GetDirLabel(ENUM_TRADE_DIRECTION dir)
{
   switch(dir)
   {
      case DIR_LONG:  return "⬆ LONG";
      case DIR_SHORT: return "⬇ SHORT";
      default:        return "── NONE";
   }
}

string GetGradeLabel(ENUM_SETUP_GRADE grade)
{
   switch(grade)
   {
      case GRADE_A_PLUS: return "A+  INSTITUTIONAL";
      case GRADE_A:      return "A   HIGH QUALITY";
      case GRADE_B:      return "B   MODERATE";
      case GRADE_C:      return "C   MARGINAL";
      default:           return "NO SETUP";
   }
}

string GetSessionLabel(ENUM_SESSION sess)
{
   switch(sess)
   {
      case SESSION_ASIAN:   return "ASIAN";
      case SESSION_LONDON:  return "LONDON";
      case SESSION_NEW_YORK:return "NEW YORK";
      case SESSION_OVERLAP: return "OVERLAP ★";
      default:              return "CLOSED";
   }
}

//+------------------------------------------------------------------+
//| DATE/TIME HELPERS                                               |
//+------------------------------------------------------------------+
datetime GetDayStart()
{
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   dt.hour = 0; dt.min = 0; dt.sec = 0;
   return StructToTime(dt);
}

datetime GetWeekStart()
{
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   int dayOffset = dt.day_of_week; // 0=Sun, 1=Mon...
   datetime weekStart = TimeCurrent() - dayOffset * 86400;
   TimeToStruct(weekStart, dt);
   dt.hour = 0; dt.min = 0; dt.sec = 0;
   return StructToTime(dt);
}

datetime GetMonthStart()
{
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   dt.day = 1; dt.hour = 0; dt.min = 0; dt.sec = 0;
   return StructToTime(dt);
}

//+------------------------------------------------------------------+
//| END OF PHANTOM SCALPER PRO X                                    |
//+------------------------------------------------------------------+