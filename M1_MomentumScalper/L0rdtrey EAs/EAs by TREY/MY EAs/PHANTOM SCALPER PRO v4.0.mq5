//+------------------------------------------------------------------+
//|              PHANTOM SCALPER PRO v4.0 – INSTITUTIONAL AI         |
//|              Gold Scalping Intelligence System                    |
//|              Machine Learning + Smart Money Concepts + AI         |
//+------------------------------------------------------------------+
#property copyright   "PHANTOM SCALPER PRO v4.0 – Institutional AI Edition"
#property version     "4.00"
#property description "AI-Powered Gold Scalper | ML Classification | Smart Money Concepts"
#property strict

#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>
#include <Trade\AccountInfo.mqh>
#include <Arrays\ArrayObj.mqh>

//=======================================================================
//  ADVANCED COLOR PALETTE – Institutional Fintech Terminal
//=======================================================================
#define C_BG0           C'3,5,15'        // Deep background
#define C_BG1           C'8,12,24'       // Panel background
#define C_BG2           C'12,18,36'      // Card background
#define C_GLASS         C'15,22,42'      // Glassmorphism overlay
#define C_HDRBAR        C'10,15,32'      // Header bar
#define C_BORDER        C'25,40,75'      // Border
#define C_ACBORD        C'0,180,255'     // Accent cyan
#define C_ACBORD2       C'180,80,255'    // Accent purple
#define C_GOLD          C'255,215,0'     // Gold accent
#define C_CYAN          C'0,240,255'     // Bright cyan
#define C_PURPLE        C'200,100,255'   // Bright purple
#define C_WHITE         C'230,235,245'   // Primary text
#define C_SUBTEXT       C'120,135,165'   // Secondary text
#define C_GREEN         C'20,255,140'    // Success/Buy
#define C_RED           C'255,60,80'     // Danger/Sell
#define C_ORANGE        C'255,165,0'     // Warning
#define C_YELLOW        C'255,220,0'     // Alert
#define C_DKGREEN       C'10,60,35'      // Dark green fill
#define C_DKRED         C'60,10,20'      // Dark red fill
#define C_LBLUE         C'100,180,255'   // Light blue
#define C_DGRAY         C'40,50,65'      // Dark gray
#define C_MGRAY         C'75,90,115'     // Mid gray
#define C_BADGE_BG      C'18,26,48'      // Badge background
#define C_AI_GLOW       C'0,255,200'     // AI indicator glow

//=======================================================================
//  DASHBOARD CONFIGURATION
//=======================================================================
#define D "PSP4_"
const int DASH_WIDTH  = 580;    // Wider for institutional layout
const int DASH_HEIGHT = 920;    // Taller for comprehensive data

//=======================================================================
//  INPUT PARAMETERS – ORGANIZED BY CATEGORY
//=======================================================================

//--- Core Identity
input group "╔═══════════ CORE IDENTITY ═══════════╗"
input ulong  InpMagicNumber          = 888888;           // Magic Number
input string InpBotName              = "PHANTOM AI GOLD SCALPER"; // Bot Name
input string InpComment              = "PSP4_AI";        // Trade Comment

//--- Lot & Risk Management
input group "╔═══════════ RISK MANAGEMENT ═══════════╗"
input double InpBaseLotSize          = 0.01;             // Base Lot Size
input bool   InpUseDynamicLots       = true;             // Use AI Dynamic Lot Sizing
input double InpRiskPercentage       = 1.0;              // Risk Per Trade (% of Balance)
input double InpMaxDailyDrawdown     = 5.0;              // Max Daily Drawdown % (0=off)
input double InpMaxWeeklyDrawdown    = 10.0;             // Max Weekly Drawdown % (0=off)
input double InpMaxMonthlyDrawdown   = 15.0;             // Max Monthly Drawdown % (0=off)
input int    InpMaxConsecutiveLosses = 3;                // Max Consecutive Losses

//--- AI & Machine Learning
input group "╔═══════════ AI & MACHINE LEARNING ═══════════╗"
input double InpMinAIConfidence      = 75.0;             // Minimum AI Confidence to Trade (%)
input double InpMinTradeScore        = 70.0;             // Minimum Trade Score (%)
input bool   InpEnableSelfLearning   = true;             // Enable Reinforcement Learning
input bool   InpEnableMLClassifier   = true;             // Enable ML Market Classification
input int    InpLearningPeriod       = 100;              // Learning Sample Size (trades)

//--- Smart Money Concepts
input group "╔═══════════ SMART MONEY CONCEPTS ═══════════╗"
input bool   InpUseSMC               = true;             // Enable Smart Money Concepts
input bool   InpRequireBOS           = true;             // Require Break of Structure
input bool   InpRequireFVG           = false;            // Require Fair Value Gap
input bool   InpRequireOB            = true;             // Require Order Block
input bool   InpUseLiquiditySweeps   = true;             // Trade Liquidity Sweeps
input int    InpMinSetupGrade        = 2;                // Min Setup Grade (1=C, 2=B, 3=A, 4=A+)

//--- Multi-Timeframe Analysis
input group "╔═══════════ TIMEFRAME ANALYSIS ═══════════╗"
input ENUM_TIMEFRAMES InpTF_Macro    = PERIOD_D1;        // Macro Timeframe (Direction)
input ENUM_TIMEFRAMES InpTF_Structure= PERIOD_H4;        // Structure Timeframe
input ENUM_TIMEFRAMES InpTF_Entry    = PERIOD_M15;       // Entry Timeframe
input ENUM_TIMEFRAMES InpTF_Execution= PERIOD_M5;        // Execution Timeframe
input bool   InpRequireMTFAlignment  = true;             // Require MTF Alignment

//--- Session Intelligence
input group "╔═══════════ SESSION INTELLIGENCE ═══════════╗"
input bool   InpTradeAsian           = false;            // Trade Asian Session
input bool   InpTradeLondon          = true;             // Trade London Session
input bool   InpTradeNewYork         = true;             // Trade New York Session
input bool   InpTradeOverlap         = true;             // Prioritize London-NY Overlap
input bool   InpTradeWeekends        = false;            // Allow Weekend Trading

//--- News & Economic Intelligence
input group "╔═══════════ NEWS INTELLIGENCE ═══════════╗"
input bool   InpEnableNewsFilter     = true;             // Enable News Filter
input int    InpNewsBufferMinutes    = 30;               // Minutes Before/After News
input bool   InpHaltOnHighImpact     = true;             // Halt on High Impact News

//--- Trade Execution
input group "╔═══════════ EXECUTION SETTINGS ═══════════╗"
input int    InpMaxSpreadPoints      = 25;               // Max Spread (points)
input int    InpMaxSlippagePoints    = 10;               // Max Slippage (points)
input int    InpMinTickVelocity      = 5;                // Min Tick Velocity for Entry
input double InpMinATR               = 0.5;              // Min ATR (dollars) for Trading

//--- Trade Management
input group "╔═══════════ TRADE MANAGEMENT ═══════════╗"
input double InpDefaultSLPips        = 10.0;             // Default Stop Loss (pips)
input double InpDefaultTPPips        = 20.0;             // Default Take Profit (pips)
input bool   InpUseDynamicTP         = true;             // Use Dynamic TP (Volatility-Based)
input bool   InpUseBreakeven         = true;             // Move to Breakeven
input double InpBreakevenTriggerPips = 8.0;              // Breakeven Trigger (pips in profit)
input double InpBreakevenOffsetPips  = 2.0;              // Breakeven Offset (pips)
input bool   InpUseTrailingStop      = true;             // Use Trailing Stop
input double InpTrailingStartPips    = 12.0;             // Trailing Start (pips in profit)
input double InpTrailingStepPips     = 5.0;              // Trailing Step (pips)
input bool   InpUsePartialClose      = true;             // Use Partial Close
input double InpPartialClosePct      = 50.0;             // Partial Close % of Lot
input double InpPartialClosePips     = 15.0;             // Partial Close Trigger (pips)

//--- Frequency Control
input group "╔═══════════ FREQUENCY CONTROL ═══════════╗"
input int    InpMaxDailyTrades       = 10;               // Max Trades Per Day (0=unlimited)
input int    InpCooldownSeconds      = 300;              // Cooldown After Trade Close (sec)
input int    InpAnalysisCycleSeconds = 300;              // Market Analysis Cycle (sec)

//--- Dashboard
input group "╔═══════════ DASHBOARD ═══════════╗"
input bool   InpShowDashboard        = true;             // Show Dashboard
input int    InpDashX                = 10;               // Dashboard X Position
input int    InpDashY                = 10;               // Dashboard Y Position
input bool   InpEnableAnimations     = true;             // Enable Smooth Animations
input bool   InpShowAIInsights       = true;             // Show AI Insights Panel

//--- Notifications
input group "╔═══════════ NOTIFICATIONS ═══════════╗"
input bool   InpAlertOnTrade         = true;             // Alert on Trade Open/Close
input bool   InpAlertOnHighConfidence= true;             // Alert on High AI Confidence
input bool   InpSendNotifications    = false;            // Send Push Notifications
input bool   InpSendEmail            = false;            // Send Email Notifications

//=======================================================================
//  ENUMERATION TYPES
//=======================================================================

// Market State Classification
enum ENUM_MARKET_STATE
{
   MARKET_TRENDING_BULL,
   MARKET_TRENDING_BEAR,
   MARKET_RANGING,
   MARKET_ACCUMULATION,
   MARKET_DISTRIBUTION,
   MARKET_EXPANSION,
   MARKET_COMPRESSION,
   MARKET_HIGH_VOLATILITY,
   MARKET_LOW_VOLATILITY,
   MARKET_MANIPULATION,
   MARKET_NEWS_EVENT,
   MARKET_UNDEFINED
};

// Setup Grade
enum ENUM_SETUP_GRADE
{
   GRADE_C = 1,    // Low quality
   GRADE_B = 2,    // Medium quality
   GRADE_A = 3,    // High quality
   GRADE_A_PLUS = 4 // Institutional grade
};

// Session Type
enum ENUM_SESSION
{
   SESSION_ASIAN,
   SESSION_LONDON,
   SESSION_NEWYORK,
   SESSION_OVERLAP,
   SESSION_NONE
};

// Risk Environment
enum ENUM_RISK_ENVIRONMENT
{
   RISK_LOW,
   RISK_MEDIUM,
   RISK_HIGH,
   RISK_EXTREME
};

// Trade Direction Bias
enum ENUM_BIAS
{
   BIAS_BULLISH,
   BIAS_BEARISH,
   BIAS_NEUTRAL
};

//=======================================================================
//  STRUCTURE DEFINITIONS
//=======================================================================

// Market Intelligence Data
struct SMarketIntelligence
{
   ENUM_MARKET_STATE state;
   ENUM_BIAS         institutionalBias;
   ENUM_BIAS         trendBias;
   ENUM_RISK_ENVIRONMENT riskEnv;
   double            volatility;
   double            liquidity;
   double            momentum;
   double            confidence;
   datetime          lastUpdate;
   
   void Reset()
   {
      state = MARKET_UNDEFINED;
      institutionalBias = BIAS_NEUTRAL;
      trendBias = BIAS_NEUTRAL;
      riskEnv = RISK_MEDIUM;
      volatility = 0;
      liquidity = 0;
      momentum = 0;
      confidence = 0;
      lastUpdate = 0;
   }
};

// Smart Money Setup
struct SSMCSetup
{
   bool              valid;
   ENUM_SETUP_GRADE  grade;
   ENUM_ORDER_TYPE   direction;
   double            entryPrice;
   double            stopLoss;
   double            takeProfit;
   string            setupType;      // "BOS+OB", "FVG+Liquidity", etc.
   double            qualityScore;
   bool              hasBOS;
   bool              hasCHOCH;
   bool              hasFVG;
   bool              hasOB;
   bool              hasLiquiditySweep;
   datetime          detectedTime;
   
   void Reset()
   {
      valid = false;
      grade = GRADE_C;
      direction = ORDER_TYPE_BUY;
      entryPrice = 0;
      stopLoss = 0;
      takeProfit = 0;
      setupType = "";
      qualityScore = 0;
      hasBOS = false;
      hasCHOCH = false;
      hasFVG = false;
      hasOB = false;
      hasLiquiditySweep = false;
      detectedTime = 0;
   }
};

// AI Trade Scoring
struct SAIScore
{
   double overall;           // 0-100
   double trendQuality;
   double structureQuality;
   double liquidityQuality;
   double volatilityQuality;
   double sessionQuality;
   double newsEnvironment;
   double executionQuality;
   double historicalPerformance;
   double confidence;        // 0-100
   
   void Reset()
   {
      overall = 0;
      trendQuality = 0;
      structureQuality = 0;
      liquidityQuality = 0;
      volatilityQuality = 0;
      sessionQuality = 0;
      newsEnvironment = 0;
      executionQuality = 0;
      historicalPerformance = 0;
      confidence = 0;
   }
};

// Trade Record for Machine Learning
struct STradeRecord
{
   datetime          openTime;
   datetime          closeTime;
   ENUM_ORDER_TYPE   type;
   double            entryPrice;
   double            exitPrice;
   double            lotSize;
   double            profit;
   double            profitPips;
   double            rMultiple;
   ENUM_MARKET_STATE marketState;
   ENUM_SESSION      session;
   string            setupType;
   double            aiConfidence;
   double            tradeScore;
   double            spreadAtEntry;
   double            atrAtEntry;
   double            volatilityAtEntry;
   bool              winner;
   
   void Init()
   {
      openTime = 0;
      closeTime = 0;
      type = ORDER_TYPE_BUY;
      entryPrice = 0;
      exitPrice = 0;
      lotSize = 0;
      profit = 0;
      profitPips = 0;
      rMultiple = 0;
      marketState = MARKET_UNDEFINED;
      session = SESSION_NONE;
      setupType = "";
      aiConfidence = 0;
      tradeScore = 0;
      spreadAtEntry = 0;
      atrAtEntry = 0;
      volatilityAtEntry = 0;
      winner = false;
   }
};

// Session Statistics
struct SSessionStats
{
   int    trades;
   int    wins;
   int    losses;
   double profit;
   double winRate;
   double profitFactor;
   double avgProfit;
   double avgLoss;
   
   void Reset()
   {
      trades = 0;
      wins = 0;
      losses = 0;
      profit = 0;
      winRate = 0;
      profitFactor = 0;
      avgProfit = 0;
      avgLoss = 0;
   }
   
   void Calculate()
   {
      if(trades > 0)
      {
         winRate = (wins / (double)trades) * 100.0;
         if(losses > 0 && avgLoss != 0)
            profitFactor = (wins * avgProfit) / (losses * MathAbs(avgLoss));
      }
   }
};

// Multi-Timeframe Analysis
struct SMTFAnalysis
{
   ENUM_BIAS    macroTrend;        // Daily/Weekly
   ENUM_BIAS    structureTrend;    // H4
   ENUM_BIAS    entryTrend;        // M15
   bool         aligned;
   double       confidence;
   
   void Reset()
   {
      macroTrend = BIAS_NEUTRAL;
      structureTrend = BIAS_NEUTRAL;
      entryTrend = BIAS_NEUTRAL;
      aligned = false;
      confidence = 0;
   }
};

//=======================================================================
//  GLOBAL OBJECTS
//=======================================================================
CTrade          g_trade;
CPositionInfo   g_pos;
CAccountInfo    g_account;

//=======================================================================
//  INDICATOR HANDLES
//=======================================================================
int g_atrHandle     = INVALID_HANDLE;
int g_emaFast_H     = INVALID_HANDLE;
int g_emaSlow_H     = INVALID_HANDLE;
int g_rsiHandle     = INVALID_HANDLE;

// Multi-timeframe handles
int g_ema_Macro     = INVALID_HANDLE;
int g_ema_Structure = INVALID_HANDLE;
int g_ema_Entry     = INVALID_HANDLE;

//=======================================================================
//  GLOBAL STATE VARIABLES
//=======================================================================

// Market Intelligence
SMarketIntelligence  g_marketIntel;
SSMCSetup            g_currentSetup;
SAIScore             g_aiScore;
SMTFAnalysis         g_mtfAnalysis;

// Session tracking
ENUM_SESSION         g_currentSession = SESSION_NONE;
SSessionStats        g_asianStats;
SSessionStats        g_londonStats;
SSessionStats        g_newYorkStats;
SSessionStats        g_overlapStats;

// Trade database (machine learning)
STradeRecord         g_tradeHistory[];
int                  g_tradeHistorySize = 0;

// Performance tracking
datetime             g_sessionDay = 0;
datetime             g_weekStart  = 0;
datetime             g_monthStart = 0;

double               g_dailyProfit   = 0;
double               g_weeklyProfit  = 0;
double               g_monthlyProfit = 0;

int                  g_dailyTrades   = 0;
int                  g_weeklyTrades  = 0;
int                  g_monthlyTrades = 0;

int                  g_totalWins     = 0;
int                  g_totalLosses   = 0;
int                  g_consecutiveLosses = 0;

double               g_peakEquity    = 0;
double               g_dailyDrawdown = 0;
double               g_weeklyDrawdown = 0;
double               g_monthlyDrawdown = 0;

// Cooldown & timing
datetime             g_lastTradeCloseTime = 0;
datetime             g_lastAnalysisTime   = 0;
bool                 g_inCooldown         = false;
int                  g_cooldownRemaining  = 0;

// Status
string               g_statusText    = "INITIALIZING";
color                g_statusColor   = C_ORANGE;
string               g_lastAction    = "System starting...";
string               g_marketStateText = "Analyzing...";

// AI & ML state
bool                 g_learningActive = false;
double               g_mlConfidence   = 0;
string               g_mlPrediction   = "Neutral";

// News flag
bool                 g_newsHaltActive = false;
datetime             g_newsHaltUntil  = 0;

// Execution quality tracking
double               g_avgSpreadEntry = 0;
double               g_avgSlippage    = 0;
int                  g_executionCount = 0;

//=======================================================================
//  CONSTANTS
//=======================================================================
const double GOLD_POINT_VALUE = 0.01;   // For XAUUSD pip calculation
const double GOLD_PIP = 0.1;            // 1 pip = 0.1 for Gold

//=======================================================================
//  FORWARD DECLARATIONS
//=======================================================================

// Initialization
bool InitIndicators();
void InitTradeDatabase();
void RestoreSessionData();

// Market Intelligence
void AnalyzeMarket();
void ClassifyMarketState();
void AnalyzeLiquidity();
void AnalyzeVolatility();
void DetectSession();
void AnalyzeSMC();
ENUM_BIAS GetTrendBias(ENUM_TIMEFRAMES tf);
bool DetectBOS();
bool DetectCHOCH();
bool DetectFVG();
bool DetectOrderBlock();
bool DetectLiquiditySweep();

// AI & Machine Learning
void CalculateAIScore();
void MLClassifyMarket();
void UpdateLearningDatabase(ulong ticket);
void AnalyzeHistoricalPerformance();
double CalculateSetupQuality();
ENUM_SETUP_GRADE GradeSetup();

// Multi-Timeframe
void AnalyzeMTF();
bool CheckMTFAlignment();

// Risk Management
bool CheckRiskLimits();
double CalculateLotSize();
double CalculateDynamicSL(ENUM_ORDER_TYPE type);
double CalculateDynamicTP(ENUM_ORDER_TYPE type);
bool IsDrawdownExceeded();

// Trade Execution
bool ExecuteTrade();
bool OpenPosition(ENUM_ORDER_TYPE type, double lot, double price, double sl, double tp);
void ManageOpenPositions();
void CheckBreakeven();
void CheckTrailing();
void CheckPartialClose();
void ClosePosition(ulong ticket, string reason);

// Utility
double GetATR(int period = 14);
double GetSpread();
double PipsToPrice(double pips);
double PriceToPips(double price);
bool IsSessionActive();
bool IsNewsTime();
datetime GetDayStart(datetime time);
datetime GetWeekStart(datetime time);
datetime GetMonthStart(datetime time);
string SessionToString(ENUM_SESSION session);
string MarketStateToString(ENUM_MARKET_STATE state);
string BiasToString(ENUM_BIAS bias);

// Dashboard
void InitDashboard();
void UpdateDashboard();
void DeleteDashboard();
void DrawGlassPanel(string name, int x, int y, int w, int h, color bgColor, color borderColor);
void DrawLabel(string name, int x, int y, string text, color clr, int size, string font = "Segoe UI");
void DrawProgressBar(string name, int x, int y, int w, int h, double percent, color fillColor, color bgColor);
void UpdateLabel(string name, string text, color clr = clrNONE);
void UpdateProgressBar(string name, double percent, color fillColor);
void DrawAIGlow(string name, int x, int y, int radius, color glowColor);

//=======================================================================
//  OnInit
//=======================================================================
int OnInit()
{
   // Validate inputs
   if(InpBaseLotSize <= 0)
   {
      Alert("Base lot size must be greater than 0");
      return INIT_PARAMETERS_INCORRECT;
   }
   
   if(InpMinAIConfidence < 0 || InpMinAIConfidence > 100)
   {
      Alert("AI Confidence must be between 0 and 100");
      return INIT_PARAMETERS_INCORRECT;
   }
   
   // Setup trade object
   g_trade.SetExpertMagicNumber(InpMagicNumber);
   g_trade.SetDeviationInPoints(InpMaxSlippagePoints);
   g_trade.SetTypeFilling(ORDER_FILLING_FOK);
   g_trade.LogLevel(LOG_LEVEL_ERRORS);
   
   // Initialize indicators
   if(!InitIndicators())
   {
      Print("Failed to initialize indicators");
      return INIT_FAILED;
   }
   
   // Initialize states
   g_marketIntel.Reset();
   g_currentSetup.Reset();
   g_aiScore.Reset();
   g_mtfAnalysis.Reset();
   
   g_asianStats.Reset();
   g_londonStats.Reset();
   g_newYorkStats.Reset();
   g_overlapStats.Reset();
   
   // Set initial equity
   g_peakEquity = AccountInfoDouble(ACCOUNT_EQUITY);
   
   // Initialize time tracking
   g_sessionDay  = GetDayStart(TimeCurrent());
   g_weekStart   = GetWeekStart(TimeCurrent());
   g_monthStart  = GetMonthStart(TimeCurrent());
   
   // Restore session data
   RestoreSessionData();
   
   // Initialize trade database
   InitTradeDatabase();
   
   // Initialize dashboard
   if(InpShowDashboard)
      InitDashboard();
   
   // Set timer for 1-second updates
   EventSetTimer(1);
   
   Print("═══════════════════════════════════════════════════════");
   Print("PHANTOM SCALPER PRO v4.0 – INSTITUTIONAL AI EDITION");
   Print("Gold Scalping Intelligence System ACTIVATED");
   Print("Symbol: ", Symbol());
   Print("Magic Number: ", InpMagicNumber);
   Print("AI Confidence Threshold: ", InpMinAIConfidence, "%");
   Print("Smart Money Concepts: ", (InpUseSMC ? "ENABLED" : "DISABLED"));
   Print("Machine Learning: ", (InpEnableMLClassifier ? "ENABLED" : "DISABLED"));
   Print("Self-Learning: ", (InpEnableSelfLearning ? "ENABLED" : "DISABLED"));
   Print("═══════════════════════════════════════════════════════");
   
   g_lastAction = "System initialized successfully";
   g_statusText = "ACTIVE";
   g_statusColor = C_GREEN;
   
   return INIT_SUCCEEDED;
}

//=======================================================================
//  OnDeinit
//=======================================================================
void OnDeinit(const int reason)
{
   EventKillTimer();
   
   // Release indicators
   if(g_atrHandle != INVALID_HANDLE) IndicatorRelease(g_atrHandle);
   if(g_emaFast_H != INVALID_HANDLE) IndicatorRelease(g_emaFast_H);
   if(g_emaSlow_H != INVALID_HANDLE) IndicatorRelease(g_emaSlow_H);
   if(g_rsiHandle != INVALID_HANDLE) IndicatorRelease(g_rsiHandle);
   if(g_ema_Macro != INVALID_HANDLE) IndicatorRelease(g_ema_Macro);
   if(g_ema_Structure != INVALID_HANDLE) IndicatorRelease(g_ema_Structure);
   if(g_ema_Entry != INVALID_HANDLE) IndicatorRelease(g_ema_Entry);
   
   // Delete dashboard
   DeleteDashboard();
   
   Print("PHANTOM SCALPER PRO v4.0 deinitialized. Reason: ", reason);
}

//=======================================================================
//  OnTimer – 1-second heartbeat
//=======================================================================
void OnTimer()
{
   // Update cooldown counter
   if(g_lastTradeCloseTime > 0)
   {
      int elapsed = (int)(TimeCurrent() - g_lastTradeCloseTime);
      g_inCooldown = (elapsed < InpCooldownSeconds);
      g_cooldownRemaining = g_inCooldown ? (InpCooldownSeconds - elapsed) : 0;
   }
   else
   {
      g_inCooldown = false;
      g_cooldownRemaining = 0;
   }
   
   // Update news halt
   if(g_newsHaltActive && TimeCurrent() >= g_newsHaltUntil)
   {
      g_newsHaltActive = false;
      g_lastAction = "News halt lifted - resuming trading";
   }
   
   // Update equity tracking
   double currentEquity = AccountInfoDouble(ACCOUNT_EQUITY);
   if(currentEquity > g_peakEquity)
      g_peakEquity = currentEquity;
   
   // Calculate drawdowns
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   if(balance > 0)
   {
      g_dailyDrawdown   = ((balance - (balance + g_dailyProfit)) / balance) * 100.0;
      g_weeklyDrawdown  = ((balance - (balance + g_weeklyProfit)) / balance) * 100.0;
      g_monthlyDrawdown = ((balance - (balance + g_monthlyProfit)) / balance) * 100.0;
   }
   
   // Perform periodic market analysis
   if(TimeCurrent() - g_lastAnalysisTime >= InpAnalysisCycleSeconds)
   {
      AnalyzeMarket();
      g_lastAnalysisTime = TimeCurrent();
   }
   
   // Update dashboard
   if(InpShowDashboard)
      UpdateDashboard();
}

//=======================================================================
//  OnTick – Main execution engine
//=======================================================================
void OnTick()
{
   // Check for new day/week/month
   datetime currentDay = GetDayStart(TimeCurrent());
   if(currentDay != g_sessionDay)
   {
      g_sessionDay = currentDay;
      g_dailyProfit = 0;
      g_dailyTrades = 0;
      g_dailyDrawdown = 0;
      g_lastAction = "New trading day started";
   }
   
   datetime currentWeek = GetWeekStart(TimeCurrent());
   if(currentWeek != g_weekStart)
   {
      g_weekStart = currentWeek;
      g_weeklyProfit = 0;
      g_weeklyTrades = 0;
      g_weeklyDrawdown = 0;
   }
   
   datetime currentMonth = GetMonthStart(TimeCurrent());
   if(currentMonth != g_monthStart)
   {
      g_monthStart = currentMonth;
      g_monthlyProfit = 0;
      g_monthlyTrades = 0;
      g_monthlyDrawdown = 0;
   }
   
   // Weekend guard
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   if((dt.day_of_week == 0 || dt.day_of_week == 6) && !InpTradeWeekends)
   {
      g_statusText = "WEEKEND";
      g_statusColor = C_MGRAY;
      return;
   }
   
   // Manage existing positions
   ManageOpenPositions();
   
   // Check if we have an open position
   bool hasPosition = false;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(g_pos.SelectByIndex(i))
      {
         if(g_pos.Magic() == InpMagicNumber && g_pos.Symbol() == Symbol())
         {
            hasPosition = true;
            g_statusText = "IN TRADE";
            g_statusColor = C_GREEN;
            break;
         }
      }
   }
   
   // If position exists, don't look for new entries
   if(hasPosition)
      return;
   
   // Cooldown check
   if(g_inCooldown)
   {
      g_statusText = "COOLDOWN";
      g_statusColor = C_CYAN;
      return;
   }
   
   // News halt check
   if(g_newsHaltActive)
   {
      g_statusText = "NEWS HALT";
      g_statusColor = C_ORANGE;
      return;
   }
   
   // Risk limit checks
   if(!CheckRiskLimits())
   {
      g_statusText = "RISK LIMIT";
      g_statusColor = C_RED;
      return;
   }
   
   // Session filter
   if(!IsSessionActive())
   {
      g_statusText = "SESSION INACTIVE";
      g_statusColor = C_MGRAY;
      return;
   }
   
   // News time filter
   if(IsNewsTime())
   {
      g_statusText = "NEWS TIME";
      g_statusColor = C_YELLOW;
      return;
   }
   
   // Spread check
   if(GetSpread() > InpMaxSpreadPoints * GOLD_POINT_VALUE)
   {
      g_statusText = "HIGH SPREAD";
      g_statusColor = C_ORANGE;
      return;
   }
   
   // ATR check (minimum volatility)
   double atr = GetATR();
   if(atr < InpMinATR)
   {
      g_statusText = "LOW VOLATILITY";
      g_statusColor = C_ORANGE;
      return;
   }
   
   // Perform comprehensive analysis
   AnalyzeMarket();
   
   // Check AI confidence
   if(g_aiScore.confidence < InpMinAIConfidence)
   {
      g_statusText = "LOW AI CONFIDENCE";
      g_statusColor = C_ORANGE;
      return;
   }
   
   // Check trade score
   if(g_aiScore.overall < InpMinTradeScore)
   {
      g_statusText = "LOW TRADE SCORE";
      g_statusColor = C_ORANGE;
      return;
   }
   
   // Check setup validity
   if(!g_currentSetup.valid)
   {
      g_statusText = "NO VALID SETUP";
      g_statusColor = C_ORANGE;
      return;
   }
   
   // Check setup grade
   if((int)g_currentSetup.grade < InpMinSetupGrade)
   {
      g_statusText = "SETUP GRADE LOW";
      g_statusColor = C_ORANGE;
      return;
   }
   
   // Check MTF alignment if required
   if(InpRequireMTFAlignment && !g_mtfAnalysis.aligned)
   {
      g_statusText = "MTF NOT ALIGNED";
      g_statusColor = C_ORANGE;
      return;
   }
   
   // All checks passed - execute trade
   g_statusText = "EXECUTING";
   g_statusColor = C_LBLUE;
   
   if(ExecuteTrade())
   {
      g_dailyTrades++;
      g_weeklyTrades++;
      g_monthlyTrades++;
      g_statusText = "TRADE OPENED";
      g_statusColor = C_GREEN;
      
      if(InpAlertOnTrade)
         Alert("PHANTOM AI: Trade opened - ", EnumToString(g_currentSetup.direction),
               " | AI Confidence: ", DoubleToString(g_aiScore.confidence, 1), "%");
   }
   else
   {
      g_statusText = "EXECUTION FAILED";
      g_statusColor = C_RED;
   }
}

//=======================================================================
//  INITIALIZATION FUNCTIONS
//=======================================================================

bool InitIndicators()
{
   // ATR
   g_atrHandle = iATR(Symbol(), PERIOD_CURRENT, 14);
   
   // Fast/Slow EMA for execution timeframe
   g_emaFast_H = iMA(Symbol(), InpTF_Execution, 9, 0, MODE_EMA, PRICE_CLOSE);
   g_emaSlow_H = iMA(Symbol(), InpTF_Execution, 21, 0, MODE_EMA, PRICE_CLOSE);
   
   // RSI
   g_rsiHandle = iRSI(Symbol(), InpTF_Execution, 14, PRICE_CLOSE);
   
   // Multi-timeframe EMAs
   g_ema_Macro = iMA(Symbol(), InpTF_Macro, 50, 0, MODE_EMA, PRICE_CLOSE);
   g_ema_Structure = iMA(Symbol(), InpTF_Structure, 50, 0, MODE_EMA, PRICE_CLOSE);
   g_ema_Entry = iMA(Symbol(), InpTF_Entry, 21, 0, MODE_EMA, PRICE_CLOSE);
   
   // Validate handles
   if(g_atrHandle == INVALID_HANDLE || 
      g_emaFast_H == INVALID_HANDLE || 
      g_emaSlow_H == INVALID_HANDLE ||
      g_rsiHandle == INVALID_HANDLE ||
      g_ema_Macro == INVALID_HANDLE ||
      g_ema_Structure == INVALID_HANDLE ||
      g_ema_Entry == INVALID_HANDLE)
   {
      Print("Failed to create indicator handles. Error: ", GetLastError());
      return false;
   }
   
   return true;
}

void InitTradeDatabase()
{
   ArrayResize(g_tradeHistory, 0);
   g_tradeHistorySize = 0;
}

void RestoreSessionData()
{
   // Restore from deal history
   if(!HistorySelect(g_sessionDay, TimeCurrent()))
      return;
   
   int totalDeals = HistoryDealsTotal();
   
   for(int i = 0; i < totalDeals; i++)
   {
      ulong ticket = HistoryDealGetTicket(i);
      if(ticket == 0) continue;
      
      if(HistoryDealGetInteger(ticket, DEAL_MAGIC) != InpMagicNumber)
         continue;
      
      if(HistoryDealGetString(ticket, DEAL_SYMBOL) != Symbol())
         continue;
      
      long dealEntry = HistoryDealGetInteger(ticket, DEAL_ENTRY);
      
      if(dealEntry == DEAL_ENTRY_OUT)
      {
         double profit = HistoryDealGetDouble(ticket, DEAL_PROFIT);
         profit += HistoryDealGetDouble(ticket, DEAL_SWAP);
         profit += HistoryDealGetDouble(ticket, DEAL_COMMISSION);
         
         g_dailyProfit += profit;
         
         if(profit > 0)
         {
            g_totalWins++;
            g_consecutiveLosses = 0;
         }
         else if(profit < 0)
         {
            g_totalLosses++;
            g_consecutiveLosses++;
         }
      }
   }
   
   Print("Session data restored: Profit=", g_dailyProfit, 
         " Wins=", g_totalWins, " Losses=", g_totalLosses);
}

//=======================================================================
//  MARKET INTELLIGENCE ENGINE
//=======================================================================

void AnalyzeMarket()
{
   // Detect current session
   DetectSession();
   
   // Classify market state
   ClassifyMarketState();
   
   // Analyze liquidity
   AnalyzeLiquidity();
   
   // Analyze volatility
   AnalyzeVolatility();
   
   // Multi-timeframe analysis
   AnalyzeMTF();
   
   // Smart Money Concepts analysis
   if(InpUseSMC)
      AnalyzeSMC();
   
   // Machine Learning classification
   if(InpEnableMLClassifier)
      MLClassifyMarket();
   
   // Calculate AI score
   CalculateAIScore();
   
   // Update market intelligence timestamp
   g_marketIntel.lastUpdate = TimeCurrent();
}

void ClassifyMarketState()
{
   double atr = GetATR();
   double avgATR = GetATR(50); // Longer period for comparison
   
   // Get price action
   double close0 = iClose(Symbol(), InpTF_Entry, 0);
   double close1 = iClose(Symbol(), InpTF_Entry, 1);
   double high0  = iHigh(Symbol(), InpTF_Entry, 0);
   double low0   = iLow(Symbol(), InpTF_Entry, 0);
   
   double range = high0 - low0;
   
   // Trend detection
   ENUM_BIAS trend = GetTrendBias(InpTF_Entry);
   
   // Volatility comparison
   bool highVol = (atr > avgATR * 1.5);
   bool lowVol  = (atr < avgATR * 0.7);
   
   // Range detection (narrow range compared to ATR)
   bool ranging = (range < atr * 0.5);
   
   // Classify state
   if(highVol && !ranging)
   {
      if(trend == BIAS_BULLISH)
         g_marketIntel.state = MARKET_TRENDING_BULL;
      else if(trend == BIAS_BEARISH)
         g_marketIntel.state = MARKET_TRENDING_BEAR;
      else
         g_marketIntel.state = MARKET_HIGH_VOLATILITY;
   }
   else if(lowVol)
   {
      if(ranging)
         g_marketIntel.state = MARKET_COMPRESSION;
      else
         g_marketIntel.state = MARKET_LOW_VOLATILITY;
   }
   else if(ranging)
   {
      g_marketIntel.state = MARKET_RANGING;
   }
   else
   {
      if(trend == BIAS_BULLISH)
         g_marketIntel.state = MARKET_TRENDING_BULL;
      else if(trend == BIAS_BEARISH)
         g_marketIntel.state = MARKET_TRENDING_BEAR;
      else
         g_marketIntel.state = MARKET_RANGING;
   }
   
   g_marketIntel.trendBias = trend;
   g_marketIntel.volatility = atr;
   
   g_marketStateText = MarketStateToString(g_marketIntel.state);
}

void AnalyzeLiquidity()
{
   // Simplified liquidity analysis based on volume and spread
   double spread = GetSpread();
   double avgSpread = 0.15; // Average spread for Gold (adjust based on broker)
   
   // Liquidity score: lower spread = higher liquidity
   if(spread <= avgSpread * 0.8)
      g_marketIntel.liquidity = 90.0;
   else if(spread <= avgSpread * 1.2)
      g_marketIntel.liquidity = 70.0;
   else if(spread <= avgSpread * 1.5)
      g_marketIntel.liquidity = 50.0;
   else
      g_marketIntel.liquidity = 30.0;
}

void AnalyzeVolatility()
{
   double atr = GetATR();
   
   // Gold typical ATR ranges (adjust based on market conditions)
   // Low: < $2, Medium: $2-5, High: $5-10, Extreme: > $10
   
   if(atr < 2.0)
      g_marketIntel.riskEnv = RISK_LOW;
   else if(atr < 5.0)
      g_marketIntel.riskEnv = RISK_MEDIUM;
   else if(atr < 10.0)
      g_marketIntel.riskEnv = RISK_HIGH;
   else
      g_marketIntel.riskEnv = RISK_EXTREME;
}

void DetectSession()
{
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   
   int hour = dt.hour;
   
   // Session times (UTC/GMT):
   // Asian: 23:00-08:00
   // London: 08:00-16:00
   // New York: 13:00-22:00
   // Overlap: 13:00-16:00
   
   if(hour >= 13 && hour < 16)
      g_currentSession = SESSION_OVERLAP;
   else if(hour >= 8 && hour < 16)
      g_currentSession = SESSION_LONDON;
   else if(hour >= 13 && hour < 22)
      g_currentSession = SESSION_NEWYORK;
   else if((hour >= 23) || (hour < 8))
      g_currentSession = SESSION_ASIAN;
   else
      g_currentSession = SESSION_NONE;
}

ENUM_BIAS GetTrendBias(ENUM_TIMEFRAMES tf)
{
   double ema[];
   ArraySetAsSeries(ema, true);
   
   int handle = iMA(Symbol(), tf, 50, 0, MODE_EMA, PRICE_CLOSE);
   if(handle == INVALID_HANDLE)
      return BIAS_NEUTRAL;
   
   if(CopyBuffer(handle, 0, 0, 3, ema) <= 0)
   {
      IndicatorRelease(handle);
      return BIAS_NEUTRAL;
   }
   
   double close = iClose(Symbol(), tf, 0);
   
   ENUM_BIAS bias = BIAS_NEUTRAL;
   
   // Price above EMA and EMA rising = bullish
   if(close > ema[0] && ema[0] > ema[1])
      bias = BIAS_BULLISH;
   // Price below EMA and EMA falling = bearish
   else if(close < ema[0] && ema[0] < ema[1])
      bias = BIAS_BEARISH;
   
   IndicatorRelease(handle);
   
   return bias;
}

//=======================================================================
//  SMART MONEY CONCEPTS ENGINE
//=======================================================================

void AnalyzeSMC()
{
   g_currentSetup.Reset();
   
   // Detect SMC elements
   bool bos = DetectBOS();
   bool choch = DetectCHOCH();
   bool fvg = DetectFVG();
   bool ob = DetectOrderBlock();
   bool liqSweep = DetectLiquiditySweep();
   
   g_currentSetup.hasBOS = bos;
   g_currentSetup.hasCHOCH = choch;
   g_currentSetup.hasFVG = fvg;
   g_currentSetup.hasOB = ob;
   g_currentSetup.hasLiquiditySweep = liqSweep;
   
   // Check minimum requirements
   if(InpRequireBOS && !bos)
      return;
   
   if(InpRequireFVG && !fvg)
      return;
   
   if(InpRequireOB && !ob)
      return;
   
   // Determine direction based on trend bias
   ENUM_BIAS bias = g_marketIntel.trendBias;
   if(bias == BIAS_NEUTRAL)
      return;
   
   g_currentSetup.direction = (bias == BIAS_BULLISH) ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
   
   // Calculate quality score
   g_currentSetup.qualityScore = CalculateSetupQuality();
   
   // Grade setup
   g_currentSetup.grade = GradeSetup();
   
   // Build setup type string
   string setupStr = "";
   if(bos) setupStr += "BOS+";
   if(choch) setupStr += "CHOCH+";
   if(fvg) setupStr += "FVG+";
   if(ob) setupStr += "OB+";
   if(liqSweep) setupStr += "LIQ+";
   
   if(StringLen(setupStr) > 0)
      setupStr = StringSubstr(setupStr, 0, StringLen(setupStr) - 1);
   
   g_currentSetup.setupType = setupStr;
   
   // Set entry price (current price)
   g_currentSetup.entryPrice = (g_currentSetup.direction == ORDER_TYPE_BUY) 
                                ? SymbolInfoDouble(Symbol(), SYMBOL_ASK)
                                : SymbolInfoDouble(Symbol(), SYMBOL_BID);
   
   // Calculate SL/TP
   g_currentSetup.stopLoss = CalculateDynamicSL(g_currentSetup.direction);
   g_currentSetup.takeProfit = CalculateDynamicTP(g_currentSetup.direction);
   
   g_currentSetup.detectedTime = TimeCurrent();
   g_currentSetup.valid = true;
}

bool DetectBOS()
{
   // Simplified BOS detection: price breaks recent swing high/low
   double high1 = iHigh(Symbol(), InpTF_Entry, 1);
   double high2 = iHigh(Symbol(), InpTF_Entry, 2);
   double high3 = iHigh(Symbol(), InpTF_Entry, 3);
   
   double low1 = iLow(Symbol(), InpTF_Entry, 1);
   double low2 = iLow(Symbol(), InpTF_Entry, 2);
   double low3 = iLow(Symbol(), InpTF_Entry, 3);
   
   double close0 = iClose(Symbol(), InpTF_Entry, 0);
   
   // Bullish BOS: break above recent swing high
   if(close0 > MathMax(high1, MathMax(high2, high3)))
      return true;
   
   // Bearish BOS: break below recent swing low
   if(close0 < MathMin(low1, MathMin(low2, low3)))
      return true;
   
   return false;
}

bool DetectCHOCH()
{
   // Change of Character: momentum shift
   // Simplified: RSI crossing 50 level
   double rsi[];
   ArraySetAsSeries(rsi, true);
   
   if(CopyBuffer(g_rsiHandle, 0, 0, 3, rsi) <= 0)
      return false;
   
   // Bullish CHOCH: RSI crosses above 50
   if(rsi[1] < 50 && rsi[0] > 50)
      return true;
   
   // Bearish CHOCH: RSI crosses below 50
   if(rsi[1] > 50 && rsi[0] < 50)
      return true;
   
   return false;
}

bool DetectFVG()
{
   // Fair Value Gap: gap in 3-candle sequence
   double high1 = iHigh(Symbol(), InpTF_Entry, 1);
   double high2 = iHigh(Symbol(), InpTF_Entry, 2);
   double high3 = iHigh(Symbol(), InpTF_Entry, 3);
   
   double low1 = iLow(Symbol(), InpTF_Entry, 1);
   double low2 = iLow(Symbol(), InpTF_Entry, 2);
   double low3 = iLow(Symbol(), InpTF_Entry, 3);
   
   // Bullish FVG: gap between candle 3 high and candle 1 low
   if(low1 > high3)
      return true;
   
   // Bearish FVG: gap between candle 3 low and candle 1 high
   if(high1 < low3)
      return true;
   
   return false;
}

bool DetectOrderBlock()
{
   // Order Block: strong momentum candle before reversal
   double close1 = iClose(Symbol(), InpTF_Entry, 1);
   double close2 = iClose(Symbol(), InpTF_Entry, 2);
   double open1  = iOpen(Symbol(), InpTF_Entry, 1);
   double open2  = iOpen(Symbol(), InpTF_Entry, 2);
   
   double body1 = MathAbs(close1 - open1);
   double body2 = MathAbs(close2 - open2);
   
   double atr = GetATR();
   
   // Strong bullish candle followed by potential reversal
   if(close1 > open1 && body1 > atr * 0.5)
      return true;
   
   // Strong bearish candle followed by potential reversal
   if(close1 < open1 && body1 > atr * 0.5)
      return true;
   
   return false;
}

bool DetectLiquiditySweep()
{
   // Liquidity sweep: price briefly breaks level then reverses
   double high1 = iHigh(Symbol(), InpTF_Entry, 1);
   double high2 = iHigh(Symbol(), InpTF_Entry, 2);
   double low1  = iLow(Symbol(), InpTF_Entry, 1);
   double low2  = iLow(Symbol(), InpTF_Entry, 2);
   
   double close0 = iClose(Symbol(), InpTF_Entry, 0);
   double close1 = iClose(Symbol(), InpTF_Entry, 1);
   
   // Bullish sweep: swept below recent low then closed back up
   if(low1 < low2 && close1 > low2)
      return true;
   
   // Bearish sweep: swept above recent high then closed back down
   if(high1 > high2 && close1 < high2)
      return true;
   
   return false;
}

double CalculateSetupQuality()
{
   double score = 0;
   
   // Each SMC element adds points
   if(g_currentSetup.hasBOS) score += 25;
   if(g_currentSetup.hasCHOCH) score += 20;
   if(g_currentSetup.hasFVG) score += 20;
   if(g_currentSetup.hasOB) score += 25;
   if(g_currentSetup.hasLiquiditySweep) score += 10;
   
   return MathMin(score, 100.0);
}

ENUM_SETUP_GRADE GradeSetup()
{
   double quality = g_currentSetup.qualityScore;
   
   if(quality >= 90)
      return GRADE_A_PLUS;
   else if(quality >= 75)
      return GRADE_A;
   else if(quality >= 60)
      return GRADE_B;
   else
      return GRADE_C;
}

//=======================================================================
//  AI SCORING ENGINE
//=======================================================================

void CalculateAIScore()
{
   g_aiScore.Reset();
   
   // 1. Trend Quality (0-100)
   ENUM_BIAS macro = GetTrendBias(InpTF_Macro);
   ENUM_BIAS structure = GetTrendBias(InpTF_Structure);
   ENUM_BIAS entry = GetTrendBias(InpTF_Entry);
   
   int trendAlignment = 0;
   if(macro == structure) trendAlignment++;
   if(structure == entry) trendAlignment++;
   if(macro == entry) trendAlignment++;
   
   g_aiScore.trendQuality = (trendAlignment / 3.0) * 100.0;
   
   // 2. Structure Quality (setup quality)
   g_aiScore.structureQuality = g_currentSetup.qualityScore;
   
   // 3. Liquidity Quality
   g_aiScore.liquidityQuality = g_marketIntel.liquidity;
   
   // 4. Volatility Quality (optimal ATR range)
   double atr = GetATR();
   if(atr >= 2.0 && atr <= 8.0)
      g_aiScore.volatilityQuality = 90.0;
   else if(atr >= 1.0 && atr <= 10.0)
      g_aiScore.volatilityQuality = 70.0;
   else
      g_aiScore.volatilityQuality = 40.0;
   
   // 5. Session Quality
   double sessQuality = 50.0;
   if(g_currentSession == SESSION_OVERLAP)
      sessQuality = 95.0;
   else if(g_currentSession == SESSION_LONDON || g_currentSession == SESSION_NEWYORK)
      sessQuality = 80.0;
   else if(g_currentSession == SESSION_ASIAN)
      sessQuality = 60.0;
   
   g_aiScore.sessionQuality = sessQuality;
   
   // 6. News Environment (simplified)
   g_aiScore.newsEnvironment = IsNewsTime() ? 30.0 : 90.0;
   
   // 7. Execution Quality (spread & slippage)
   double spread = GetSpread();
   double execQuality = 100.0;
   if(spread > 0.10)
      execQuality = 90.0;
   if(spread > 0.15)
      execQuality = 70.0;
   if(spread > 0.20)
      execQuality = 50.0;
   
   g_aiScore.executionQuality = execQuality;
   
   // 8. Historical Performance (win rate influence)
   int totalTrades = g_totalWins + g_totalLosses;
   double winRate = (totalTrades > 0) ? ((double)g_totalWins / totalTrades * 100.0) : 50.0;
   g_aiScore.historicalPerformance = winRate;
   
   // Calculate overall score (weighted average)
   g_aiScore.overall = (
      g_aiScore.trendQuality * 0.20 +
      g_aiScore.structureQuality * 0.25 +
      g_aiScore.liquidityQuality * 0.10 +
      g_aiScore.volatilityQuality * 0.10 +
      g_aiScore.sessionQuality * 0.10 +
      g_aiScore.newsEnvironment * 0.10 +
      g_aiScore.executionQuality * 0.05 +
      g_aiScore.historicalPerformance * 0.10
   );
   
   // Confidence is based on consistency of scores
   double avgScore = g_aiScore.overall;
   double variance = 0;
   
   variance += MathPow(g_aiScore.trendQuality - avgScore, 2);
   variance += MathPow(g_aiScore.structureQuality - avgScore, 2);
   variance += MathPow(g_aiScore.liquidityQuality - avgScore, 2);
   variance += MathPow(g_aiScore.volatilityQuality - avgScore, 2);
   variance += MathPow(g_aiScore.sessionQuality - avgScore, 2);
   
   variance /= 5.0;
   double stdDev = MathSqrt(variance);
   
   // Lower variance = higher confidence
   g_aiScore.confidence = MathMax(0, 100.0 - stdDev);
   
   // Alert on high confidence setups
   if(InpAlertOnHighConfidence && g_aiScore.confidence >= 90.0 && g_currentSetup.valid)
   {
      g_lastAction = "HIGH CONFIDENCE SETUP DETECTED!";
      if(InpAlertOnTrade)
         Alert("PHANTOM AI: High confidence setup! AI=", DoubleToString(g_aiScore.confidence, 1), 
               "% Score=", DoubleToString(g_aiScore.overall, 1), "%");
   }
}

//=======================================================================
//  MACHINE LEARNING CLASSIFICATION
//=======================================================================

void MLClassifyMarket()
{
   // Simplified ML classification using pattern recognition
   // In production, this would use a trained ML model
   
   double atr = GetATR();
   double avgATR = GetATR(50);
   double close = iClose(Symbol(), InpTF_Entry, 0);
   double ema50 = 0;
   
   double emaBuffer[];
   ArraySetAsSeries(emaBuffer, true);
   if(CopyBuffer(g_ema_Entry, 0, 0, 1, emaBuffer) > 0)
      ema50 = emaBuffer[0];
   
   // Feature extraction
   double volatilityRatio = (avgATR > 0) ? (atr / avgATR) : 1.0;
   double trendStrength = MathAbs(close - ema50) / atr;
   
   // Simple rule-based classification (placeholder for actual ML)
   if(volatilityRatio > 1.3 && trendStrength > 1.0)
   {
      g_mlPrediction = (close > ema50) ? "Strong Bull" : "Strong Bear";
      g_mlConfidence = 85.0;
   }
   else if(volatilityRatio < 0.7 && trendStrength < 0.5)
   {
      g_mlPrediction = "Range/Compression";
      g_mlConfidence = 75.0;
   }
   else
   {
      g_mlPrediction = (close > ema50) ? "Weak Bull" : "Weak Bear";
      g_mlConfidence = 60.0;
   }
}

//=======================================================================
//  MULTI-TIMEFRAME ANALYSIS
//=======================================================================

void AnalyzeMTF()
{
   g_mtfAnalysis.Reset();
   
   g_mtfAnalysis.macroTrend = GetTrendBias(InpTF_Macro);
   g_mtfAnalysis.structureTrend = GetTrendBias(InpTF_Structure);
   g_mtfAnalysis.entryTrend = GetTrendBias(InpTF_Entry);
   
   // Check alignment
   if(g_mtfAnalysis.macroTrend == g_mtfAnalysis.structureTrend &&
      g_mtfAnalysis.structureTrend == g_mtfAnalysis.entryTrend &&
      g_mtfAnalysis.macroTrend != BIAS_NEUTRAL)
   {
      g_mtfAnalysis.aligned = true;
      g_mtfAnalysis.confidence = 95.0;
   }
   else if(g_mtfAnalysis.structureTrend == g_mtfAnalysis.entryTrend &&
           g_mtfAnalysis.structureTrend != BIAS_NEUTRAL)
   {
      g_mtfAnalysis.aligned = true;
      g_mtfAnalysis.confidence = 75.0;
   }
   else
   {
      g_mtfAnalysis.aligned = false;
      g_mtfAnalysis.confidence = 40.0;
   }
}

bool CheckMTFAlignment()
{
   return g_mtfAnalysis.aligned;
}

//=======================================================================
//  RISK MANAGEMENT
//=======================================================================

bool CheckRiskLimits()
{
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   if(balance <= 0) return false;
   
   // Daily drawdown limit
   if(InpMaxDailyDrawdown > 0)
   {
      if(g_dailyDrawdown >= InpMaxDailyDrawdown)
      {
         g_lastAction = "Daily drawdown limit reached";
         return false;
      }
   }
   
   // Weekly drawdown limit
   if(InpMaxWeeklyDrawdown > 0)
   {
      if(g_weeklyDrawdown >= InpMaxWeeklyDrawdown)
      {
         g_lastAction = "Weekly drawdown limit reached";
         return false;
      }
   }
   
   // Monthly drawdown limit
   if(InpMaxMonthlyDrawdown > 0)
   {
      if(g_monthlyDrawdown >= InpMaxMonthlyDrawdown)
      {
         g_lastAction = "Monthly drawdown limit reached";
         return false;
      }
   }
   
   // Max daily trades
   if(InpMaxDailyTrades > 0 && g_dailyTrades >= InpMaxDailyTrades)
   {
      g_lastAction = "Daily trade limit reached";
      return false;
   }
   
   // Max consecutive losses
   if(InpMaxConsecutiveLosses > 0 && g_consecutiveLosses >= InpMaxConsecutiveLosses)
   {
      g_lastAction = "Max consecutive losses reached";
      return false;
   }
   
   return true;
}

double CalculateLotSize()
{
   if(!InpUseDynamicLots)
      return InpBaseLotSize;
   
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double riskAmount = balance * (InpRiskPercentage / 100.0);
   
   double slPips = InpDefaultSLPips;
   if(InpUseDynamicTP)
   {
      double atr = GetATR();
      slPips = PriceToPips(atr * 1.5);
   }
   
   double tickValue = SymbolInfoDouble(Symbol(), SYMBOL_TRADE_TICK_VALUE);
   double tickSize = SymbolInfoDouble(Symbol(), SYMBOL_TRADE_TICK_SIZE);
   
   double lotSize = (riskAmount / (slPips * 10)) / tickValue * tickSize;
   
   // Apply lot limits
   double minLot = SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_MIN);
   double maxLot = SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_MAX);
   double lotStep = SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_STEP);
   
   lotSize = MathMax(minLot, lotSize);
   lotSize = MathMin(maxLot, lotSize);
   lotSize = MathRound(lotSize / lotStep) * lotStep;
   
   // AI confidence modifier
   if(g_aiScore.confidence >= 90)
      lotSize *= 1.2;  // Increase lot by 20% for very high confidence
   else if(g_aiScore.confidence < 70)
      lotSize *= 0.8;  // Decrease lot by 20% for lower confidence
   
   lotSize = MathRound(lotSize / lotStep) * lotStep;
   lotSize = MathMax(minLot, MathMin(maxLot, lotSize));
   
   return lotSize;
}

double CalculateDynamicSL(ENUM_ORDER_TYPE type)
{
   double price = (type == ORDER_TYPE_BUY) 
                  ? SymbolInfoDouble(Symbol(), SYMBOL_ASK)
                  : SymbolInfoDouble(Symbol(), SYMBOL_BID);
   
   double slDistance = PipsToPrice(InpDefaultSLPips);
   
   if(InpUseDynamicTP)
   {
      double atr = GetATR();
      slDistance = atr * 1.5;  // 1.5x ATR
   }
   
   double sl = 0;
   if(type == ORDER_TYPE_BUY)
      sl = price - slDistance;
   else
      sl = price + slDistance;
   
   return NormalizeDouble(sl, (int)SymbolInfoInteger(Symbol(), SYMBOL_DIGITS));
}

double CalculateDynamicTP(ENUM_ORDER_TYPE type)
{
   double price = (type == ORDER_TYPE_BUY) 
                  ? SymbolInfoDouble(Symbol(), SYMBOL_ASK)
                  : SymbolInfoDouble(Symbol(), SYMBOL_BID);
   
   double tpDistance = PipsToPrice(InpDefaultTPPips);
   
   if(InpUseDynamicTP)
   {
      double atr = GetATR();
      tpDistance = atr * 2.5;  // 2.5x ATR for better R:R
      
      // Adjust based on volatility regime
      if(g_marketIntel.riskEnv == RISK_HIGH || g_marketIntel.riskEnv == RISK_EXTREME)
         tpDistance = atr * 3.0;  // Wider TP in high volatility
   }
   
   double tp = 0;
   if(type == ORDER_TYPE_BUY)
      tp = price + tpDistance;
   else
      tp = price - tpDistance;
   
   return NormalizeDouble(tp, (int)SymbolInfoInteger(Symbol(), SYMBOL_DIGITS));
}

bool IsDrawdownExceeded()
{
   if(InpMaxDailyDrawdown > 0 && g_dailyDrawdown >= InpMaxDailyDrawdown)
      return true;
   if(InpMaxWeeklyDrawdown > 0 && g_weeklyDrawdown >= InpMaxWeeklyDrawdown)
      return true;
   if(InpMaxMonthlyDrawdown > 0 && g_monthlyDrawdown >= InpMaxMonthlyDrawdown)
      return true;
   
   return false;
}

//=======================================================================
//  TRADE EXECUTION
//=======================================================================

bool ExecuteTrade()
{
   if(!g_currentSetup.valid)
      return false;
   
   ENUM_ORDER_TYPE type = g_currentSetup.direction;
   double price = (type == ORDER_TYPE_BUY) 
                  ? SymbolInfoDouble(Symbol(), SYMBOL_ASK)
                  : SymbolInfoDouble(Symbol(), SYMBOL_BID);
   
   double lot = CalculateLotSize();
   double sl = g_currentSetup.stopLoss;
   double tp = g_currentSetup.takeProfit;
   
   if(sl == 0) sl = CalculateDynamicSL(type);
   if(tp == 0) tp = CalculateDynamicTP(type);
   
   bool result = OpenPosition(type, lot, price, sl, tp);
   
   if(result)
   {
      g_lastAction = StringFormat("Trade opened: %s %.2f lots @ %.5f | Setup: %s | AI: %.1f%%",
                                  EnumToString(type), lot, price, 
                                  g_currentSetup.setupType, g_aiScore.confidence);
      
      Print("═══ TRADE OPENED ═══");
      Print("Type: ", EnumToString(type));
      Print("Lot: ", lot);
      Print("Entry: ", price);
      Print("SL: ", sl, " (", DoubleToString(PriceToPips(MathAbs(price - sl)), 1), " pips)");
      Print("TP: ", tp, " (", DoubleToString(PriceToPips(MathAbs(tp - price)), 1), " pips)");
      Print("Setup: ", g_currentSetup.setupType);
      Print("Grade: ", g_currentSetup.grade);
      Print("AI Confidence: ", g_aiScore.confidence, "%");
      Print("Trade Score: ", g_aiScore.overall, "%");
      Print("═══════════════════");
   }
   
   return result;
}

bool OpenPosition(ENUM_ORDER_TYPE type, double lot, double price, double sl, double tp)
{
   string comment = InpComment + "|" + g_currentSetup.setupType + 
                    "|AI:" + DoubleToString(g_aiScore.confidence, 0);
   
   bool result = false;
   
   if(type == ORDER_TYPE_BUY)
      result = g_trade.Buy(lot, Symbol(), price, sl, tp, comment);
   else
      result = g_trade.Sell(lot, Symbol(), price, sl, tp, comment);
   
   if(result)
   {
      // Update execution quality metrics
      g_avgSpreadEntry = ((g_avgSpreadEntry * g_executionCount) + GetSpread()) / (g_executionCount + 1);
      g_executionCount++;
   }
   else
   {
      Print("Trade execution failed: ", g_trade.ResultRetcodeDescription());
   }
   
   return result;
}

//=======================================================================
//  TRADE MANAGEMENT
//=======================================================================

void ManageOpenPositions()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(!g_pos.SelectByIndex(i))
         continue;
      
      if(g_pos.Magic() != InpMagicNumber || g_pos.Symbol() != Symbol())
         continue;
      
      ulong ticket = g_pos.Ticket();
      
      // Breakeven
      if(InpUseBreakeven)
         CheckBreakeven();
      
      // Trailing stop
      if(InpUseTrailingStop)
         CheckTrailing();
      
      // Partial close
      if(InpUsePartialClose)
         CheckPartialClose();
   }
}

void CheckBreakeven()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(!g_pos.SelectByIndex(i))
         continue;
      
      if(g_pos.Magic() != InpMagicNumber || g_pos.Symbol() != Symbol())
         continue;
      
      double openPrice = g_pos.PriceOpen();
      double sl = g_pos.StopLoss();
      double currentPrice = (g_pos.PositionType() == POSITION_TYPE_BUY)
                            ? SymbolInfoDouble(Symbol(), SYMBOL_BID)
                            : SymbolInfoDouble(Symbol(), SYMBOL_ASK);
      
      double profitPips = 0;
      if(g_pos.PositionType() == POSITION_TYPE_BUY)
         profitPips = PriceToPips(currentPrice - openPrice);
      else
         profitPips = PriceToPips(openPrice - currentPrice);
      
      // Check if profit reached breakeven trigger
      if(profitPips >= InpBreakevenTriggerPips)
      {
         double newSL = 0;
         if(g_pos.PositionType() == POSITION_TYPE_BUY)
            newSL = openPrice + PipsToPrice(InpBreakevenOffsetPips);
         else
            newSL = openPrice - PipsToPrice(InpBreakevenOffsetPips);
         
         newSL = NormalizeDouble(newSL, (int)SymbolInfoInteger(Symbol(), SYMBOL_DIGITS));
         
         // Only move SL if it improves position
         bool shouldModify = false;
         if(g_pos.PositionType() == POSITION_TYPE_BUY && newSL > sl)
            shouldModify = true;
         else if(g_pos.PositionType() == POSITION_TYPE_SELL && (sl == 0 || newSL < sl))
            shouldModify = true;
         
         if(shouldModify)
         {
            if(g_trade.PositionModify(g_pos.Ticket(), newSL, g_pos.TakeProfit()))
            {
               Print("Breakeven set for ticket #", g_pos.Ticket(), " at ", newSL);
               g_lastAction = "Breakeven activated";
            }
         }
      }
   }
}

void CheckTrailing()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(!g_pos.SelectByIndex(i))
         continue;
      
      if(g_pos.Magic() != InpMagicNumber || g_pos.Symbol() != Symbol())
         continue;
      
      double openPrice = g_pos.PriceOpen();
      double sl = g_pos.StopLoss();
      double currentPrice = (g_pos.PositionType() == POSITION_TYPE_BUY)
                            ? SymbolInfoDouble(Symbol(), SYMBOL_BID)
                            : SymbolInfoDouble(Symbol(), SYMBOL_ASK);
      
      double profitPips = 0;
      if(g_pos.PositionType() == POSITION_TYPE_BUY)
         profitPips = PriceToPips(currentPrice - openPrice);
      else
         profitPips = PriceToPips(openPrice - currentPrice);
      
      // Check if profit reached trailing start
      if(profitPips >= InpTrailingStartPips)
      {
         double newSL = 0;
         if(g_pos.PositionType() == POSITION_TYPE_BUY)
            newSL = currentPrice - PipsToPrice(InpTrailingStepPips);
         else
            newSL = currentPrice + PipsToPrice(InpTrailingStepPips);
         
         newSL = NormalizeDouble(newSL, (int)SymbolInfoInteger(Symbol(), SYMBOL_DIGITS));
         
         // Only move SL if it improves position
         bool shouldModify = false;
         if(g_pos.PositionType() == POSITION_TYPE_BUY && newSL > sl)
            shouldModify = true;
         else if(g_pos.PositionType() == POSITION_TYPE_SELL && (sl == 0 || newSL < sl))
            shouldModify = true;
         
         if(shouldModify)
         {
            if(g_trade.PositionModify(g_pos.Ticket(), newSL, g_pos.TakeProfit()))
            {
               Print("Trailing stop updated for ticket #", g_pos.Ticket(), " at ", newSL);
            }
         }
      }
   }
}

void CheckPartialClose()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(!g_pos.SelectByIndex(i))
         continue;
      
      if(g_pos.Magic() != InpMagicNumber || g_pos.Symbol() != Symbol())
         continue;
      
      // Check if already partially closed (comment contains "PARTIAL")
      if(StringFind(g_pos.Comment(), "PARTIAL") >= 0)
         continue;
      
      double openPrice = g_pos.PriceOpen();
      double currentPrice = (g_pos.PositionType() == POSITION_TYPE_BUY)
                            ? SymbolInfoDouble(Symbol(), SYMBOL_BID)
                            : SymbolInfoDouble(Symbol(), SYMBOL_ASK);
      
      double profitPips = 0;
      if(g_pos.PositionType() == POSITION_TYPE_BUY)
         profitPips = PriceToPips(currentPrice - openPrice);
      else
         profitPips = PriceToPips(openPrice - currentPrice);
      
      // Check if profit reached partial close trigger
      if(profitPips >= InpPartialClosePips)
      {
         double currentLot = g_pos.Volume();
         double closeLot = NormalizeDouble(currentLot * (InpPartialClosePct / 100.0),
                                          (int)SymbolInfoInteger(Symbol(), (SYMBOL_VOLUME_DIGITS));
         
         double minLot = SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_MIN);
         if(closeLot >= minLot && (currentLot - closeLot) >= minLot)
         {
            if(g_trade.PositionClosePartial(g_pos.Ticket(), closeLot))
            {
               Print("Partial close: ", closeLot, " lots closed from ticket #", g_pos.Ticket());
               g_lastAction = "Partial profit taken";
            }
         }
      }
   }
}

void ClosePosition(ulong ticket, string reason)
{
   if(g_trade.PositionClose(ticket))
   {
      Print("Position closed: Ticket #", ticket, " Reason: ", reason);
      g_lastAction = "Position closed: " + reason;
      g_lastTradeCloseTime = TimeCurrent();
      
      // Update learning database
      if(InpEnableSelfLearning)
         UpdateLearningDatabase(ticket);
   }
}

//=======================================================================
//  MACHINE LEARNING DATABASE
//=======================================================================

void UpdateLearningDatabase(ulong ticket)
{
   // Get deal information from history
   if(!HistorySelectByPosition(HistoryOrderGetInteger(ticket, ORDER_POSITION_ID)))
      return;
   
   int totalDeals = HistoryDealsTotal();
   if(totalDeals < 2) return;
   
   ulong entryTicket = HistoryDealGetTicket(0);
   ulong exitTicket = HistoryDealGetTicket(totalDeals - 1);
   
   if(entryTicket == 0 || exitTicket == 0)
      return;
   
   STradeRecord record;
   record.Init();
   
   record.openTime = (datetime)HistoryDealGetInteger(entryTicket, DEAL_TIME);
   record.closeTime = (datetime)HistoryDealGetInteger(exitTicket, DEAL_TIME);
   record.type = (ENUM_ORDER_TYPE)HistoryDealGetInteger(entryTicket, DEAL_TYPE);
   record.entryPrice = HistoryDealGetDouble(entryTicket, DEAL_PRICE);
   record.exitPrice = HistoryDealGetDouble(exitTicket, DEAL_PRICE);
   record.lotSize = HistoryDealGetDouble(entryTicket, DEAL_VOLUME);
   
   record.profit = HistoryDealGetDouble(exitTicket, DEAL_PROFIT);
   record.profit += HistoryDealGetDouble(exitTicket, DEAL_SWAP);
   record.profit += HistoryDealGetDouble(exitTicket, DEAL_COMMISSION);
   
   if(record.type == ORDER_TYPE_BUY)
      record.profitPips = PriceToPips(record.exitPrice - record.entryPrice);
   else
      record.profitPips = PriceToPips(record.entryPrice - record.exitPrice);
   
   record.winner = (record.profit > 0);
   
   // Store contextual data
   record.marketState = g_marketIntel.state;
   record.session = g_currentSession;
   record.setupType = g_currentSetup.setupType;
   record.aiConfidence = g_aiScore.confidence;
   record.tradeScore = g_aiScore.overall;
   record.spreadAtEntry = g_avgSpreadEntry;
   record.atrAtEntry = GetATR();
   record.volatilityAtEntry = g_marketIntel.volatility;
   
   // Add to database
   ArrayResize(g_tradeHistory, g_tradeHistorySize + 1);
   g_tradeHistory[g_tradeHistorySize] = record;
   g_tradeHistorySize++;
   
   // Update global stats
   if(record.winner)
   {
      g_totalWins++;
      g_consecutiveLosses = 0;
   }
   else
   {
      g_totalLosses++;
      g_consecutiveLosses++;
   }
   
   g_dailyProfit += record.profit;
   g_weeklyProfit += record.profit;
   g_monthlyProfit += record.profit;
   
   // Update session stats
   UpdateSessionStats(record);
   
   Print("Trade recorded in learning database. Total records: ", g_tradeHistorySize);
}

void UpdateSessionStats(const STradeRecord &record)
{
   SSessionStats *stats = NULL;
   
   switch(record.session)
   {
      case SESSION_ASIAN:   stats = GetPointer(g_asianStats); break;
      case SESSION_LONDON:  stats = GetPointer(g_londonStats); break;
      case SESSION_NEWYORK: stats = GetPointer(g_newYorkStats); break;
      case SESSION_OVERLAP: stats = GetPointer(g_overlapStats); break;
   }
   
   if(stats ) return;
   
   stats.trades++;
   stats.profit += record.profit;
   
   if(record.winner)
   {
      stats.wins++;
      stats.avgProfit = ((stats.avgProfit * (stats.wins - 1)) + record.profit) / stats.wins;
   }
   else
   {
      stats.losses++;
      stats.avgLoss = ((stats.avgLoss * (stats.losses - 1)) + record.profit) / stats.losses;
   }
   
   stats.Calculate();
}

void AnalyzeHistoricalPerformance()
{
   // Analyze trade database to extract insights
   // This is a simplified version - in production, use proper statistical analysis
   
   if(g_tradeHistorySize < InpLearningPeriod)
      return;
   
   // Calculate overall statistics
   int wins = 0, losses = 0;
   double totalProfit = 0;
   
   for(int i = 0; i < g_tradeHistorySize; i++)
   {
      if(g_tradeHistory[i].winner)
         wins++;
      else
         losses++;
      
      totalProfit += g_tradeHistory[i].profit;
   }
   
   Print("═══ LEARNING ANALYSIS ═══");
   Print("Total Trades: ", g_tradeHistorySize);
   Print("Win Rate: ", DoubleToString((wins / (double)g_tradeHistorySize) * 100, 2), "%");
   Print("Total Profit: $", DoubleToString(totalProfit, 2));
   Print("Avg AI Confidence: ", DoubleToString(g_aiScore.confidence, 1), "%");
   Print("═════════════════════════");
}

//=======================================================================
//  UTILITY FUNCTIONS
//=======================================================================

double GetATR(int period = 14)
{
   double atr[];
   ArraySetAsSeries(atr, true);
   
   if(CopyBuffer(g_atrHandle, 0, 0, 1, atr) <= 0)
      return 0;
   
   return atr[0];
}

double GetSpread()
{
   return SymbolInfoDouble(Symbol(), SYMBOL_ASK) - SymbolInfoDouble(Symbol(), SYMBOL_BID);
}

double PipsToPrice(double pips)
{
   return pips * GOLD_PIP;
}

double PriceToPips(double price)
{
   return price / GOLD_PIP;
}

bool IsSessionActive()
{
   if(g_currentSession == SESSION_ASIAN && !InpTradeAsian)
      return false;
   if(g_currentSession == SESSION_LONDON && !InpTradeLondon)
      return false;
   if(g_currentSession == SESSION_NEWYORK && !InpTradeNewYork)
      return false;
   if(g_currentSession == SESSION_OVERLAP && !InpTradeOverlap)
      return false;
   
   return true;
}

bool IsNewsTime()
{
   if(!InpEnableNewsFilter)
      return false;
   
   // Simplified news detection - in production, integrate with economic calendar
   // For now, just check if we're in a news halt
   return g_newsHaltActive;
}

datetime GetDayStart(datetime time)
{
   MqlDateTime dt;
   TimeToStruct(time, dt);
   dt.hour = 0;
   dt.min = 0;
   dt.sec = 0;
   return StructToTime(dt);
}

datetime GetWeekStart(datetime time)
{
   MqlDateTime dt;
   TimeToStruct(time, dt);
   
   int daysToSubtract = dt.day_of_week; // 0=Sunday
   if(daysToSubtract == 0) daysToSubtract = 7;
   
   return time - (daysToSubtract * 86400);
}

datetime GetMonthStart(datetime time)
{
   MqlDateTime dt;
   TimeToStruct(time, dt);
   dt.day = 1;
   dt.hour = 0;
   dt.min = 0;
   dt.sec = 0;
   return StructToTime(dt);
}

string SessionToString(ENUM_SESSION session)
{
   switch(session)
   {
      case SESSION_ASIAN:   return "Asian";
      case SESSION_LONDON:  return "London";
      case SESSION_NEWYORK: return "New York";
      case SESSION_OVERLAP: return "Overlap";
      default:              return "None";
   }
}

string MarketStateToString(ENUM_MARKET_STATE state)
{
   switch(state)
   {
      case MARKET_TRENDING_BULL:     return "Trending Bullish";
      case MARKET_TRENDING_BEAR:     return "Trending Bearish";
      case MARKET_RANGING:           return "Ranging";
      case MARKET_ACCUMULATION:      return "Accumulation";
      case MARKET_DISTRIBUTION:      return "Distribution";
      case MARKET_EXPANSION:         return "Expansion";
      case MARKET_COMPRESSION:       return "Compression";
      case MARKET_HIGH_VOLATILITY:   return "High Volatility";
      case MARKET_LOW_VOLATILITY:    return "Low Volatility";
      case MARKET_MANIPULATION:      return "Manipulation";
      case MARKET_NEWS_EVENT:        return "News Event";
      default:                       return "Undefined";
   }
}

string BiasToString(ENUM_BIAS bias)
{
   switch(bias)
   {
      case BIAS_BULLISH: return "Bullish";
      case BIAS_BEARISH: return "Bearish";
      default:           return "Neutral";
   }
}

//=======================================================================
//  DASHBOARD FUNCTIONS
//=======================================================================

void InitDashboard()
{
   int X = InpDashX;
   int Y = InpDashY;
   int W = DASH_WIDTH;
   int H = DASH_HEIGHT;
   
   // Main background panel with glassmorphism effect
   DrawGlassPanel("main_bg", X, Y, W, H, C_BG0, C_ACBORD);
   
   // Header section
   DrawGlassPanel("header", X+10, Y+10, W-20, 80, C_GLASS, C_ACBORD2);
   DrawLabel("title", X+25, Y+20, InpBotName, C_GOLD, 14, "Arial Black");
   DrawLabel("subtitle", X+25, Y+42, "Institutional AI Gold Scalper v4.0", C_CYAN, 9);
   DrawLabel("magic", X+25, Y+60, "Magic: " + IntegerToString(InpMagicNumber) + " | " + Symbol(), C_SUBTEXT, 8);
   
   // AI Glow effect
   if(InpEnableAnimations)
      DrawAIGlow("ai_glow", X+W-60, Y+35, 25, C_AI_GLOW);
   
   // Status section
   DrawGlassPanel("status_panel", X+10, Y+100, W-20, 60, C_GLASS, C_BORDER);
   DrawLabel("lb_status", X+25, Y+110, "STATUS", C_SUBTEXT, 9);
   DrawLabel("vl_status", X+25, Y+128, "ACTIVE", C_GREEN, 12, "Arial Black");
   DrawLabel("lb_action", X+25, Y+148, "Last Action:", C_SUBTEXT, 8);
   DrawLabel("vl_action", X+140, Y+148, "Initializing...", C_WHITE, 8);
   
   // AI Insights section
   int yPos = Y+170;
   DrawGlassPanel("ai_panel", X+10, yPos, W-20, 180, C_GLASS, C_BORDER);
   DrawLabel("ai_header", X+25, yPos+10, "▸ AI INTELLIGENCE", C_GOLD, 10, "Arial Black");
   
   DrawLabel("lb_ai_conf", X+25, yPos+35, "AI Confidence", C_SUBTEXT, 9);
   DrawLabel("vl_ai_conf", X+220, yPos+35, "0%", C_WHITE, 10, "Arial Bold");
   DrawProgressBar("ai_conf_bar", X+300, yPos+37, W-340, 14, 0, C_CYAN, C_DGRAY);
   
   DrawLabel("lb_trade_score", X+25, yPos+58, "Trade Score", C_SUBTEXT, 9);
   DrawLabel("vl_trade_score", X+220, yPos+58, "0%", C_WHITE, 10, "Arial Bold");
   DrawProgressBar("trade_score_bar", X+300, yPos+60, W-340, 14, 0, C_PURPLE, C_DGRAY);
   
   DrawLabel("lb_market_state", X+25, yPos+81, "Market State", C_SUBTEXT, 9);
   DrawLabel("vl_market_state", X+220, yPos+81, "Analyzing...", C_WHITE, 10);
   
   DrawLabel("lb_ml_pred", X+25, yPos+104, "ML Prediction", C_SUBTEXT, 9);
   DrawLabel("vl_ml_pred", X+220, yPos+104, "Neutral", C_WHITE, 10);
   
   DrawLabel("lb_setup", X+25, yPos+127, "Setup Detected", C_SUBTEXT, 9);
   DrawLabel("vl_setup", X+220, yPos+127, "None", C_MGRAY, 10);
   
   DrawLabel("lb_mtf", X+25, yPos+150, "MTF Alignment", C_SUBTEXT, 9);
   DrawLabel("vl_mtf", X+220, yPos+150, "Not Aligned", C_ORANGE, 10);
   
   // Performance section
   yPos += 190;
   DrawGlassPanel("perf_panel", X+10, yPos, W-20, 180, C_GLASS, C_BORDER);
   DrawLabel("perf_header", X+25, yPos+10, "▸ PERFORMANCE", C_GOLD, 10, "Arial Black");
   
   DrawLabel("lb_daily_pnl", X+25, yPos+35, "Daily P&L", C_SUBTEXT, 9);
   DrawLabel("vl_daily_pnl", X+220, yPos+35, "$0.00", C_WHITE, 11, "Arial Bold");
   
   DrawLabel("lb_weekly_pnl", X+25, yPos+58, "Weekly P&L", C_SUBTEXT, 9);
   DrawLabel("vl_weekly_pnl", X+220, yPos+58, "$0.00", C_WHITE, 10);
   
   DrawLabel("lb_monthly_pnl", X+25, yPos+81, "Monthly P&L", C_SUBTEXT, 9);
   DrawLabel("vl_monthly_pnl", X+220, yPos+81, "$0.00", C_WHITE, 10);
   
   DrawLabel("lb_win_rate", X+25, yPos+104, "Win Rate", C_SUBTEXT, 9);
   DrawLabel("vl_win_rate", X+220, yPos+104, "0%", C_WHITE, 10);
   DrawProgressBar("win_rate_bar", X+300, yPos+106, W-340, 14, 0, C_GREEN, C_DGRAY);
   
   DrawLabel("lb_trades", X+25, yPos+127, "Trades Today", C_SUBTEXT, 9);
   DrawLabel("vl_trades", X+220, yPos+127, "0 / " + IntegerToString(InpMaxDailyTrades), C_WHITE, 10);
   
   DrawLabel("lb_dd", X+25, yPos+150, "Drawdown", C_SUBTEXT, 9);
   DrawLabel("vl_dd", X+220, yPos+150, "0.00%", C_WHITE, 10);
   DrawProgressBar("dd_bar", X+300, yPos+152, W-340, 14, 0, C_RED, C_DGRAY);
   
   // Account section
   yPos += 190;
   DrawGlassPanel("account_panel", X+10, yPos, W-20, 130, C_GLASS, C_BORDER);
   DrawLabel("account_header", X+25, yPos+10, "▸ ACCOUNT", C_GOLD, 10, "Arial Black");
   
   DrawLabel("lb_balance", X+25, yPos+35, "Balance", C_SUBTEXT, 9);
   DrawLabel("vl_balance", X+220, yPos+35, "$0.00", C_WHITE, 10);
   
   DrawLabel("lb_equity", X+25, yPos+58, "Equity", C_SUBTEXT, 9);
   DrawLabel("vl_equity", X+220, yPos+58, "$0.00", C_WHITE, 10);
   
   DrawLabel("lb_margin", X+25, yPos+81, "Free Margin", C_SUBTEXT, 9);
   DrawLabel("vl_margin", X+220, yPos+81, "$0.00", C_WHITE, 10);
   
   DrawLabel("lb_margin_level", X+25, yPos+104, "Margin Level", C_SUBTEXT, 9);
   DrawLabel("vl_margin_level", X+220, yPos+104, "0%", C_WHITE, 10);
   
   // Market section
   yPos += 140;
   DrawGlassPanel("market_panel", X+10, yPos, W-20, 130, C_GLASS, C_BORDER);
   DrawLabel("market_header", X+25, yPos+10, "▸ MARKET CONDITIONS", C_GOLD, 10, "Arial Black");
   
   DrawLabel("lb_session", X+25, yPos+35, "Session", C_SUBTEXT, 9);
   DrawLabel("vl_session", X+220, yPos+35, "None", C_WHITE, 10);
   
   DrawLabel("lb_spread", X+25, yPos+58, "Spread", C_SUBTEXT, 9);
   DrawLabel("vl_spread", X+220, yPos+58, "0.0 pips", C_WHITE, 10);
   
   DrawLabel("lb_volatility", X+25, yPos+81, "Volatility (ATR)", C_SUBTEXT, 9);
   DrawLabel("vl_volatility", X+220, yPos+81, "$0.00", C_WHITE, 10);
   
   DrawLabel("lb_cooldown", X+25, yPos+104, "Cooldown", C_SUBTEXT, 9);
   DrawLabel("vl_cooldown", X+220, yPos+104, "Ready", C_GREEN, 10);
   
   // Footer
   yPos += 140;
   DrawGlassPanel("footer", X+10, yPos, W-20, 30, C_HDRBAR, C_BORDER);
   DrawLabel("footer_time", X+25, yPos+8, "Server: --:--:--", C_SUBTEXT, 8);
   DrawLabel("footer_copy", X+W-180, yPos+8, "© PHANTOM AI v4.0", C_DGRAY, 8);
   
   ChartRedraw(0);
   
   Print("Dashboard initialized successfully");
}

void UpdateDashboard()
{
   if(!InpShowDashboard)
      return;
   
   // Status
   UpdateLabel("vl_status", g_statusText, g_statusColor);
   UpdateLabel("vl_action", g_lastAction, C_SUBTEXT);
   
   // AI Intelligence
   UpdateLabel("vl_ai_conf", DoubleToString(g_aiScore.confidence, 1) + "%", 
               (g_aiScore.confidence >= 80 ? C_GREEN : (g_aiScore.confidence >= 60 ? C_ORANGE : C_RED)));
   UpdateProgressBar("ai_conf_bar", g_aiScore.confidence, 
                     (g_aiScore.confidence >= 80 ? C_CYAN : (g_aiScore.confidence >= 60 ? C_ORANGE : C_RED)));
   
   UpdateLabel("vl_trade_score", DoubleToString(g_aiScore.overall, 1) + "%",
               (g_aiScore.overall >= 75 ? C_GREEN : (g_aiScore.overall >= 60 ? C_ORANGE : C_RED)));
   UpdateProgressBar("trade_score_bar", g_aiScore.overall,
                     (g_aiScore.overall >= 75 ? C_PURPLE : (g_aiScore.overall >= 60 ? C_ORANGE : C_RED)));
   
   UpdateLabel("vl_market_state", g_marketStateText, C_WHITE);
   UpdateLabel("vl_ml_pred", g_mlPrediction, C_LBLUE);
   UpdateLabel("vl_setup", g_currentSetup.valid ? g_currentSetup.setupType : "None",
               g_currentSetup.valid ? C_GREEN : C_MGRAY);
   UpdateLabel("vl_mtf", g_mtfAnalysis.aligned ? "Aligned ✓" : "Not Aligned",
               g_mtfAnalysis.aligned ? C_GREEN : C_ORANGE);
   
   // Performance
   color pnlColor = (g_dailyProfit >= 0 ? C_GREEN : C_RED);
   UpdateLabel("vl_daily_pnl", "$" + DoubleToString(g_dailyProfit, 2), pnlColor);
   UpdateLabel("vl_weekly_pnl", "$" + DoubleToString(g_weeklyProfit, 2), 
               (g_weeklyProfit >= 0 ? C_GREEN : C_RED));
   UpdateLabel("vl_monthly_pnl", "$" + DoubleToString(g_monthlyProfit, 2),
               (g_monthlyProfit >= 0 ? C_GREEN : C_RED));
   
   int totalTrades = g_totalWins + g_totalLosses;
   double winRate = (totalTrades > 0) ? ((double)g_totalWins / totalTrades * 100.0) : 0;
   UpdateLabel("vl_win_rate", DoubleToString(winRate, 1) + "%",
               (winRate >= 55 ? C_GREEN : (winRate >= 45 ? C_ORANGE : C_RED)));
   UpdateProgressBar("win_rate_bar", winRate,
                     (winRate >= 55 ? C_GREEN : (winRate >= 45 ? C_ORANGE : C_RED)));
   
   UpdateLabel("vl_trades", IntegerToString(g_dailyTrades) + " / " + IntegerToString(InpMaxDailyTrades),
               (g_dailyTrades < InpMaxDailyTrades * 0.8 ? C_WHITE : C_ORANGE));
   
   UpdateLabel("vl_dd", DoubleToString(g_dailyDrawdown, 2) + "%",
               (g_dailyDrawdown < 2 ? C_GREEN : (g_dailyDrawdown < 4 ? C_ORANGE : C_RED)));
   UpdateProgressBar("dd_bar", MathMin(g_dailyDrawdown * 10, 100),
                     (g_dailyDrawdown < 2 ? C_GREEN : (g_dailyDrawdown < 4 ? C_ORANGE : C_RED)));
   
   // Account
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   double freeMargin = AccountInfoDouble(ACCOUNT_MARGIN_FREE);
   double marginLevel = AccountInfoDouble(ACCOUNT_MARGIN_LEVEL);
   
   UpdateLabel("vl_balance", "$" + DoubleToString(balance, 2), C_WHITE);
   UpdateLabel("vl_equity", "$" + DoubleToString(equity, 2),
               (equity >= balance ? C_GREEN : C_RED));
   UpdateLabel("vl_margin", "$" + DoubleToString(freeMargin, 2), C_WHITE);
   UpdateLabel("vl_margin_level", DoubleToString(marginLevel, 1) + "%",
               (marginLevel > 500 || marginLevel == 0 ? C_GREEN : 
                (marginLevel > 200 ? C_ORANGE : C_RED)));
   
   // Market
   UpdateLabel("vl_session", SessionToString(g_currentSession), C_CYAN);
   
   double spread = GetSpread();
   UpdateLabel("vl_spread", DoubleToString(PriceToPips(spread), 1) + " pips",
               (spread <= 0.15 ? C_GREEN : (spread <= 0.25 ? C_ORANGE : C_RED)));
   
   double atr = GetATR();
   UpdateLabel("vl_volatility", "$" + DoubleToString(atr, 2), C_WHITE);
   
   if(g_inCooldown)
      UpdateLabel("vl_cooldown", IntegerToString(g_cooldownRemaining) + "s", C_ORANGE);
   else
      UpdateLabel("vl_cooldown", "Ready", C_GREEN);
   
   // Footer
   UpdateLabel("footer_time", "Server: " + TimeToString(TimeCurrent(), TIME_SECONDS), C_SUBTEXT);
   
   ChartRedraw(0);
}

void DeleteDashboard()
{
   ObjectsDeleteAll(0, D);
   ChartRedraw(0);
}

void DrawGlassPanel(string name, int x, int y, int w, int h, color bgColor, color borderColor)
{
   string objName = D + name;
   
   if(ObjectFind(0, objName) >= 0)
      ObjectDelete(0, objName);
   
   ObjectCreate(0, objName, OBJ_RECTANGLE_LABEL, 0, 0, 0);
   ObjectSetInteger(0, objName, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, objName, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, objName, OBJPROP_XSIZE, w);
   ObjectSetInteger(0, objName, OBJPROP_YSIZE, h);
   ObjectSetInteger(0, objName, OBJPROP_BGCOLOR, bgColor);
   ObjectSetInteger(0, objName, OBJPROP_BORDER_TYPE, BORDER_FLAT);
   ObjectSetInteger(0, objName, OBJPROP_COLOR, borderColor);
   ObjectSetInteger(0, objName, OBJPROP_WIDTH, 2);
   ObjectSetInteger(0, objName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, objName, OBJPROP_BACK, false);
   ObjectSetInteger(0, objName, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, objName, OBJPROP_HIDDEN, true);
}

void DrawLabel(string name, int x, int y, string text, color clr, int size, string font = "Segoe UI")
{
   string objName = D + name;
   
   if(ObjectFind(0, objName) >= 0)
      ObjectDelete(0, objName);
   
   ObjectCreate(0, objName, OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, objName, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, objName, OBJPROP_YDISTANCE, y);
   ObjectSetString(0, objName, OBJPROP_TEXT, text);
   ObjectSetInteger(0, objName, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, objName, OBJPROP_FONTSIZE, size);
   ObjectSetString(0, objName, OBJPROP_FONT, font);
   ObjectSetInteger(0, objName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, objName, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, objName, OBJPROP_HIDDEN, true);
}

void DrawProgressBar(string name, int x, int y, int w, int h, double percent, color fillColor, color bgColor)
{
   // Background
   string bgName = D + name + "_bg";
   if(ObjectFind(0, bgName) >= 0)
      ObjectDelete(0, bgName);
   
   ObjectCreate(0, bgName, OBJ_RECTANGLE_LABEL, 0, 0, 0);
   ObjectSetInteger(0, bgName, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, bgName, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, bgName, OBJPROP_XSIZE, w);
   ObjectSetInteger(0, bgName, OBJPROP_YSIZE, h);
   ObjectSetInteger(0, bgName, OBJPROP_BGCOLOR, bgColor);
   ObjectSetInteger(0, bgName, OBJPROP_BORDER_TYPE, BORDER_FLAT);
   ObjectSetInteger(0, bgName, OBJPROP_COLOR, C_BORDER);
   ObjectSetInteger(0, bgName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, bgName, OBJPROP_BACK, false);
   ObjectSetInteger(0, bgName, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, bgName, OBJPROP_HIDDEN, true);
   
   // Fill
   string fillName = D + name + "_fill";
   if(ObjectFind(0, fillName) >= 0)
      ObjectDelete(0, fillName);
   
   int fillWidth = (int)MathMax(2, (percent / 100.0) * (w - 4));
   
   ObjectCreate(0, fillName, OBJ_RECTANGLE_LABEL, 0, 0, 0);
   ObjectSetInteger(0, fillName, OBJPROP_XDISTANCE, x + 2);
   ObjectSetInteger(0, fillName, OBJPROP_YDISTANCE, y + 2);
   ObjectSetInteger(0, fillName, OBJPROP_XSIZE, fillWidth);
   ObjectSetInteger(0, fillName, OBJPROP_YSIZE, h - 4);
   ObjectSetInteger(0, fillName, OBJPROP_BGCOLOR, fillColor);
   ObjectSetInteger(0, fillName, OBJPROP_BORDER_TYPE, BORDER_FLAT);
   ObjectSetInteger(0, fillName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, fillName, OBJPROP_BACK, false);
   ObjectSetInteger(0, fillName, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, fillName, OBJPROP_HIDDEN, true);
}

void UpdateLabel(string name, string text, color clr = clrNONE)
{
   string objName = D + name;
   if(ObjectFind(0, objName) >= 0)
   {
      ObjectSetString(0, objName, OBJPROP_TEXT, text);
      if(clr != clrNONE)
         ObjectSetInteger(0, objName, OBJPROP_COLOR, clr);
   }
}

void UpdateProgressBar(string name, double percent, color fillColor)
{
   string fillName = D + name + "_fill";
   string bgName = D + name + "_bg";
   
   if(ObjectFind(0, bgName) < 0)
      return;
   
   int w = (int)ObjectGetInteger(0, bgName, OBJPROP_XSIZE);
   int h = (int)ObjectGetInteger(0, bgName, OBJPROP_YSIZE);
   int fillWidth = (int)MathMax(2, (percent / 100.0) * (w - 4));
   
   if(ObjectFind(0, fillName) >= 0)
   {
      ObjectSetInteger(0, fillName, OBJPROP_XSIZE, fillWidth);
      ObjectSetInteger(0, fillName, OBJPROP_BGCOLOR, fillColor);
   }
}

void DrawAIGlow(string name, int x, int y, int radius, color glowColor)
{
   // Create circular glow effect (simplified as label with special character)
   string objName = D + name;
   
   if(ObjectFind(0, objName) >= 0)
      ObjectDelete(0, objName);
   
   ObjectCreate(0, objName, OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, objName, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, objName, OBJPROP_YDISTANCE, y);
   ObjectSetString(0, objName, OBJPROP_TEXT, "●");
   ObjectSetInteger(0, objName, OBJPROP_COLOR, glowColor);
   ObjectSetInteger(0, objName, OBJPROP_FONTSIZE, radius);
   ObjectSetString(0, objName, OBJPROP_FONT, "Arial");
   ObjectSetInteger(0, objName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, objName, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, objName, OBJPROP_HIDDEN, true);
}

//+------------------------------------------------------------------+