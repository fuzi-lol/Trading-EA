//+------------------------------------------------------------------+
//|                                    THEE EliteScalper v5.1.mq5    |
//|                                  Copyright 2026, FXBotHub Systems|
//|                                             https://fxbothub.com |
//+------------------------------------------------------------------+
//  GOLD (XAUUSD) Optimised High-Frequency Scalping Engine
//  v5.1 – Enhanced with:
//    • POST-TRADE MARKET ANALYSIS ENGINE
//    • Adaptive strategy learning from winning/losing patterns
//    • Market regime detection (trending/ranging/volatile)
//    • Enhanced profitability scoring system
//    • Multi-timeframe trend confirmation
//    • Volume profile analysis
//    • Dynamic confluence threshold adjustment
//    • Trade quality scoring pre-entry
//    • Market conditions database
//    • Intelligent pause on unfavorable conditions
//+------------------------------------------------------------------+
#property copyright   "Copyright 2026, THEE EliteScalper Systems"
#property version     "5.10"
#property description "GOLD Institutional Scalping Engine – Full Confluence + Market Learning"
#property strict

#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>

#define DASH_PREFIX  "FXBH_V5_"
#define EA_VERSION   "v5.10"
#define EA_SYMBOL    "XAUUSD"
#define MAX_HISTORY_RECORDS 100

//+------------------------------------------------------------------+
//| MARKET REGIME DETECTION                                          |
//+------------------------------------------------------------------+
enum ENUM_MARKET_REGIME
{
   REGIME_UNKNOWN,
   REGIME_STRONG_TREND,
   REGIME_WEAK_TREND,
   REGIME_RANGING,
   REGIME_HIGH_VOLATILITY,
   REGIME_LOW_VOLATILITY
};

enum ENUM_TREND_DIRECTION
{
   TREND_NONE,
   TREND_UP,
   TREND_DOWN,
   TREND_SIDEWAYS
};

//+------------------------------------------------------------------+
//| ENGINE STATE MACHINE                                             |
//+------------------------------------------------------------------+
enum ENUM_ENGINE_STATE
{
   STATE_SCANNING,
   STATE_ANALYZING,
   STATE_COOLDOWN,
   STATE_DAILY_LIMIT,
   STATE_NEWS_PAUSE,
   STATE_MARKET_UNFAVORABLE  // NEW: Pause when conditions deteriorate
};

enum ENUM_SIGNAL
{
   SIGNAL_BUY  =  1,
   SIGNAL_SELL = -1,
   SIGNAL_NONE =  0
};

//+------------------------------------------------------------------+
//| TRADE HISTORY RECORD                                             |
//+------------------------------------------------------------------+
struct TradeRecord
{
   datetime          closeTime;
   ENUM_SIGNAL       signal;
   double            profit;
   double            rsi;
   double            adx;
   double            atr;
   double            bbWidth;
   ENUM_MARKET_REGIME regime;
   ENUM_TREND_DIRECTION mtfTrend;
   int               entryHour;
   double            spreadAtEntry;
   double            qualityScore;
};

//+------------------------------------------------------------------+
//| MARKET CONDITIONS SNAPSHOT                                       |
//+------------------------------------------------------------------+
struct MarketSnapshot
{
   ENUM_MARKET_REGIME currentRegime;
   ENUM_TREND_DIRECTION m1Trend;
   ENUM_TREND_DIRECTION m5Trend;
   ENUM_TREND_DIRECTION m15Trend;
   double            trendStrength;
   double            volatilityIndex;
   double            volumeProfile;
   bool              trendAlignment;
   datetime          timestamp;
};

//+------------------------------------------------------------------+
//| INPUT PARAMETERS                                                 |
//+------------------------------------------------------------------+
input group "=== CORE IDENTITY ==="
input ulong   InpMagicNumber       = 999555;
input string  InpTradeComment      = "EliteScalper_v5.1";

input group "=== RISK MANAGEMENT ==="
input double  InpRiskPercent       = 1.0;
input double  InpMaxDailyLossPct   = 5.0;
input double  InpMaxDailyProfitPct = 10.0;
input int     InpMaxDailyTrades    = 15;

input group "=== ATR-BASED STOP LOSS & TAKE PROFIT ==="
input int     InpATRPeriod         = 14;
input double  InpSLMultiplier      = 1.5;
input double  InpTP1Multiplier     = 1.0;
input double  InpTP2Multiplier     = 2.5;
input int     InpMinSLPoints       = 150;
input int     InpMaxSLPoints       = 500;

input group "=== BREAKEVEN & TRAILING STOP ==="
input int     InpBreakevenPoints   = 120;
input int     InpBreakevenBuffer   = 10;
input bool    InpUseTrailing       = true;
input int     InpTrailStartPoints  = 200;
input int     InpTrailStepPoints   = 50;

input group "=== PARTIAL CLOSE ==="
input bool    InpUsePartialClose   = true;
input double  InpPartialClosePct   = 50.0;

input group "=== PRE-TRADE ANALYSIS ENGINE ==="
input int     InpAnalysisMaxSec    = 120;
input int     InpAnalysisMinSec    = 10;
input int     InpAnalysisMinTicks  = 30;

input group "=== SIGNAL CONFLUENCE ENGINE ==="
input int     InpFastEMAPeriod     = 9;
input int     InpSlowEMAPeriod     = 21;
input int     InpTrendEMAPeriod    = 50;
input int     InpRSIPeriod         = 14;
input double  InpRSIOverbought     = 70.0;
input double  InpRSIOversold       = 30.0;
input int     InpADXPeriod         = 14;
input double  InpADXMinStrength    = 20.0;
input int     InpMACDFast          = 12;
input int     InpMACDSlow          = 26;
input int     InpMACDSignal        = 9;
input int     InpBBPeriod          = 20;
input double  InpBBDeviation       = 2.0;
input double  InpBBSqueezeRatio    = 0.003;
input int     InpStructureBars     = 5;

input group "=== COOLDOWN & SPREAD ==="
input int     InpCooldownSeconds   = 45;
input int     InpSpreadMaxPoints   = 40;
input double  InpSpreadMultiplier  = 2.5;

input group "=== SESSION FILTER ==="
input bool    InpUseSessionFilter  = true;
input int     InpSessionStartGMT   = 7;
input int     InpSessionEndGMT     = 20;

input group "=== STREAK PROTECTION ==="
input int     InpMaxLossStreak     = 3;
input int     InpWinStreakBoost    = 5;

input group "=== NEWS PAUSE ==="
input bool    InpNewsPauseActive   = false;

input group "=== ADVANCED PROFITABILITY CONTROLS ==="
input double  InpMinQualityScore   = 65.0;      // Minimum trade quality % to enter
input bool    InpUseMTFConfirmation = true;     // Require multi-timeframe trend alignment
input bool    InpAdaptiveThreshold = true;      // Adjust confluence threshold based on performance
input int     InpMinWinRatePercent = 40;        // Pause if win rate drops below this
input int     InpMarketAnalysisDepth = 20;      // Number of past trades to analyze
input bool    InpBlockRangeMarkets = true;      // Don't trade in ranging conditions
input double  InpMinVolatilityIndex = 0.3;      // Minimum volatility to trade (ATR/Price ratio)
input double  InpMaxVolatilityIndex = 3.0;      // Maximum volatility ceiling

input group "=== DASHBOARD ==="
input int     InpDashX            = 15;
input int     InpDashY            = 15;

//+------------------------------------------------------------------+
//| PREMIUM DASHBOARD COLOUR PALETTE                                 |
//+------------------------------------------------------------------+
const color C_PREMIUM_BG       = C'8,12,20';
const color C_PREMIUM_PANEL    = C'15,22,35';
const color C_PREMIUM_ACCENT   = C'18,28,45';
const color C_PREMIUM_GOLD     = C'255,215,0';
const color C_PREMIUM_PLATINUM = C'229,228,226';
const color C_PREMIUM_DIAMOND  = C'185,242,255';
const color C_PREMIUM_EMERALD  = C'80,200,120';
const color C_PREMIUM_RUBY     = C'224,17,95';
const color C_PREMIUM_SAPPHIRE = C'15,82,186';
const color C_PREMIUM_BORDER   = C'100,150,255';
//+------------------------------------------------------------------+
//| GLOBAL ENGINE OBJECTS                                            |
//+------------------------------------------------------------------+
CTrade          g_Trade;
CPositionInfo   g_Pos;

//--- Indicator handles (M1)
int g_hFastEMA  = INVALID_HANDLE;
int g_hSlowEMA  = INVALID_HANDLE;
int g_hTrendEMA = INVALID_HANDLE;
int g_hRSI      = INVALID_HANDLE;
int g_hATR      = INVALID_HANDLE;
int g_hADX      = INVALID_HANDLE;
int g_hMACD     = INVALID_HANDLE;
int g_hBB       = INVALID_HANDLE;

//--- Multi-timeframe indicators
int g_hEMA_M5   = INVALID_HANDLE;
int g_hEMA_M15  = INVALID_HANDLE;
int g_hATR_M5   = INVALID_HANDLE;

//--- State machine
ENUM_ENGINE_STATE g_State        = STATE_SCANNING;
datetime          g_StateTimer   = 0;

//--- Analysis phase
ENUM_SIGNAL  g_PendingSignal     = SIGNAL_NONE;
int          g_AnalysisTicks     = 0;
datetime     g_AnalysisStart     = 0;
bool         g_PartialClosed     = false;

//--- Session metrics
datetime g_SessionDay       = 0;
int      g_DailyTrades      = 0;
double   g_DailyProfit      = 0.0;
int      g_DailyWins        = 0;
int      g_DailyLosses      = 0;
int      g_ConsecLosses     = 0;
int      g_ConsecWins       = 0;
int      g_TotalReopens     = 0;
double   g_SessionOpenBal   = 0.0;

//--- Spread tracking
double g_AvgSpread          = 0.0;
int    g_SpreadSamples      = 0;

//--- Trade history for learning
TradeRecord g_TradeHistory[];
int         g_HistoryCount  = 0;

//--- Market analysis
MarketSnapshot g_CurrentMarket;
double g_DynamicConfluenceThreshold = 5.0;  // Adaptive: starts at 5 of 7
double g_CurrentQualityScore = 0.0;

//--- Performance tracking
double g_AvgWinningQuality = 0.0;
double g_AvgLosingQuality  = 0.0;
int    g_ProfitableTrades  = 0;
int    g_UnprofitableTrades = 0;

//--- Dashboard strings
string g_StatusText         = "BOOTING";
color  g_StatusColor        = C_GOLD;
string g_HeartbeatStr       = "0 0 0 0";
string g_SignalText         = "COMPUTING";
color  g_SignalColor        = C_MUTED;
string g_RegimeText         = "DETECTING";
string g_MTFText            = "—";
string g_QualityText        = "0.0%";

//+------------------------------------------------------------------+
//| FORWARD DECLARATIONS                                             |
//+------------------------------------------------------------------+
bool         InitIndicators();
void         ReleaseIndicators();
void         SyncDailyStats();
ENUM_SIGNAL  EvaluateConfluence(double &qualityScore);
bool         CheckEMAStack(double &fast, double &slow, double &trend);
bool         CheckRSI(ENUM_SIGNAL sig, double &rsiVal);
bool         CheckADX(double &adxVal);
bool         CheckMACD(ENUM_SIGNAL sig);
bool         CheckBollingerBands(ENUM_SIGNAL sig, bool &inSqueeze);
bool         CheckMarketStructure(ENUM_SIGNAL sig);
double       GetATR();
double       CalculateLotSize(int slPoints);
void         ExecuteEntry(ENUM_SIGNAL sig, double qualityScore);
void         ManageOpenTrade();
void         CheckBreakeven();
void         CheckTrailing();
void         CheckPartialClose();
void         EvaluateFloatingPnL();
bool         IsPositionOpen();
double       GetFloatingPnL();
void         CloseAllPositions(string reason);
bool         IsMarketOpen();
bool         IsInSession();
bool         IsSpreadOk();
void         UpdateSpreadAverage();
bool         IsDailyLossLimitHit();
bool         IsDailyProfitTargetHit();
double       GetRiskAdjustedPercent();
datetime     GetDayStart(datetime t);
void         ProcessAnalysisPhase();

// NEW: Market Analysis Functions
void         AnalyzeMarketConditions();
ENUM_MARKET_REGIME DetectMarketRegime();
ENUM_TREND_DIRECTION GetTrendDirection(ENUM_TIMEFRAMES tf);
bool         CheckMultiTimeframeTrend(ENUM_SIGNAL sig);
double       CalculateVolatilityIndex();
double       CalculateTradeQuality(ENUM_SIGNAL sig, double rsi, double adx, double atr, ENUM_MARKET_REGIME regime);
void         RecordTradeOutcome(ulong ticket);
void         AnalyzeTradeHistory();
void         AdjustConfluenceThreshold();
bool         IsMarketConditionFavorable();
void         PostTradeMarketReview();
double       GetVolumeProfile();
string       RegimeToString(ENUM_MARKET_REGIME regime);
string       TrendToString(ENUM_TREND_DIRECTION trend);

// Dashboard
void         RenderDashboard();
void         UpdateDashboard();
void         PurgeDashboard();
void         DrawRect(string id, int x, int y, int w, int h, color bg, color border, int bw);
void         DrawLabel(string id, int x, int y, string txt, color clr, int sz, string fnt);
void         SetLabel(string id, string txt, color clr = clrNONE);

//+------------------------------------------------------------------+
//| INIT                                                             |
//+------------------------------------------------------------------+
int OnInit()
{
   if(StringFind(_Symbol, "XAU") < 0 && StringFind(_Symbol, "GOLD") < 0)
      Print("[EliteScalper v5.1] WARNING: Optimised for GOLD. Current: ", _Symbol);

   g_Trade.SetExpertMagicNumber(InpMagicNumber);
   g_Trade.SetDeviationInPoints(20);
   g_Trade.SetTypeFilling(ORDER_FILLING_FOK);

   if(InpRiskPercent <= 0.0 || InpRiskPercent > 10.0)
   { Alert("Risk% must be 0.01–10."); return INIT_PARAMETERS_INCORRECT; }

   if(!InitIndicators()) return INIT_FAILED;

   // Initialize trade history array properly
   ArrayResize(g_TradeHistory, MAX_HISTORY_RECORDS);
   for(int i = 0; i < MAX_HISTORY_RECORDS; i++)
   {
      g_TradeHistory[i].closeTime = 0;
      g_TradeHistory[i].signal = 0;
      g_TradeHistory[i].profit = 0.0;
      g_TradeHistory[i].rsi = 0.0;
      g_TradeHistory[i].adx = 0.0;
      g_TradeHistory[i].atr = 0.0;
      g_TradeHistory[i].bbWidth = 0.0;
      g_TradeHistory[i].regime = 0;
      g_TradeHistory[i].mtfTrend = 0;
      g_TradeHistory[i].entryHour = 0;
      g_TradeHistory[i].spreadAtEntry = 0.0;
      g_TradeHistory[i].qualityScore = 0.0;
   }
   
   // Initialize market snapshot
   g_CurrentMarket.currentRegime = (int)REGIME_UNKNOWN;
   g_CurrentMarket.m1Trend = (int)TREND_NONE;
   g_CurrentMarket.m5Trend = (int)TREND_NONE;
   g_CurrentMarket.m15Trend = (int)TREND_NONE;
   g_CurrentMarket.trendStrength = 0.0;
   g_CurrentMarket.volatilityIndex = 0.0;
   g_CurrentMarket.volumeProfile = 1.0;
   g_CurrentMarket.trendAlignment = false;
   g_CurrentMarket.timestamp = 0;
   
   g_SessionDay     = GetDayStart(TimeCurrent());
   g_SessionOpenBal = AccountInfoDouble(ACCOUNT_BALANCE);
   SyncDailyStats();
   AnalyzeTradeHistory();  // Load historical performance

   g_State = STATE_SCANNING;
   EventSetTimer(1);
   RenderDashboard();

   Print("[EliteScalper v5.1] Initialised. Enhanced Market Analysis Active.");
   return INIT_SUCCEEDED;
}
//+------------------------------------------------------------------+
//| DEINIT                                                           |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   EventKillTimer();
   PurgeDashboard();
   ReleaseIndicators();
}

//+------------------------------------------------------------------+
//| TIMER                                                            |
//+------------------------------------------------------------------+
void OnTimer()
{
   static uint beat = 0; beat++;
   string p[4] = {"1 0 1 1  0 1 0 0","0 1 0 0  1 0 1 1","1 1 0 1  0 0 1 0","0 0 1 0  1 1 0 1"};
   g_HeartbeatStr = p[beat % 4];
   SyncDailyStats();
   AnalyzeMarketConditions();  // NEW: Continuous market monitoring
   UpdateDashboard();
}

//+------------------------------------------------------------------+
//| TICK – main engine                                               |
//+------------------------------------------------------------------+
void OnTick()
{
   UpdateSpreadAverage();

   if(!IsMarketOpen())
   { g_StatusText = "MARKET CLOSED"; g_StatusColor = C_RED; return; }

   if(InpNewsPauseActive || g_State == STATE_NEWS_PAUSE)
   { g_StatusText = "NEWS PAUSE ACTIVE"; g_StatusColor = C_GOLD; return; }

   // Manage open trades first
   if(IsPositionOpen())
   { ManageOpenTrade(); return; }

   // Post-trade market review after closing position
   PostTradeMarketReview();

   if(IsDailyLossLimitHit())
   {
      g_State = STATE_DAILY_LIMIT;
      g_StatusText = "DAILY LOSS LIMIT – HALTED";
      g_StatusColor = C_RED;
      return;
   }

   if(IsDailyProfitTargetHit())
   {
      g_State = STATE_DAILY_LIMIT;
      g_StatusText = "DAILY PROFIT TARGET MET";
      g_StatusColor = C_GREEN;
      return;
   }

   if(g_DailyTrades >= InpMaxDailyTrades)
   {
      g_StatusText = "MAX DAILY TRADES REACHED";
      g_StatusColor = C_GOLD;
      return;
   }

   // NEW: Check if market conditions are favorable
   if(!IsMarketConditionFavorable())
   {
      g_State = STATE_MARKET_UNFAVORABLE;
      g_StatusText = "UNFAVORABLE CONDITIONS – WAITING";
      g_StatusColor = C_ORANGE;
      return;
   }
   else if(g_State == STATE_MARKET_UNFAVORABLE)
   {
      g_State = STATE_SCANNING;  // Resume if conditions improve
   }

   if(InpUseSessionFilter && !IsInSession())
   {
      g_StatusText = "OUT OF SESSION";
      g_StatusColor = C_MUTED;
      return;
   }

   if(!IsSpreadOk())
   {
      int sp = (int)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
      g_StatusText = "SPREAD HIGH (" + IntegerToString(sp) + " pts)";
      g_StatusColor = C_RED;
      return;
   }

   if(g_State == STATE_COOLDOWN)
   {
      int left = (int)(g_StateTimer - TimeCurrent());
      if(left > 0)
      {
         g_StatusText = "COOLDOWN (" + IntegerToString(left) + "s)";
         g_StatusColor = C_GOLD;
         return;
      }
      g_State = STATE_SCANNING;
   }

   if(g_State == STATE_SCANNING)
   {
      double qualityScore = 0.0;
      ENUM_SIGNAL sig = EvaluateConfluence(qualityScore);
      
      if(sig == SIGNAL_NONE || qualityScore < InpMinQualityScore)
      {
         g_StatusText = "SCANNING – " + (sig == SIGNAL_NONE ? "NO SIGNAL" : "LOW QUALITY");
         g_StatusColor = C_MUTED;
         g_CurrentQualityScore = qualityScore;
         return;
      }
      
      // Signal found with acceptable quality
      g_State          = STATE_ANALYZING;
      g_PendingSignal  = sig;
      g_AnalysisStart  = TimeCurrent();
      g_AnalysisTicks  = 0;
      g_CurrentQualityScore = qualityScore;
      g_StatusText     = "HIGH QUALITY SIGNAL – ANALYSING";
      g_StatusColor    = C_PURPLE;
      Print("[EliteScalper v5.1] Signal=", (sig==SIGNAL_BUY?"BUY":"SELL"), 
            " Quality=", DoubleToString(qualityScore, 1), "% – Analyzing");
   }
   else if(g_State == STATE_ANALYZING)
   {
      ProcessAnalysisPhase();
   }
}

//+------------------------------------------------------------------+
//| INDICATOR INITIALISATION                                         |
//+------------------------------------------------------------------+
bool InitIndicators()
{
   // M1 indicators
   g_hFastEMA  = iMA(_Symbol, PERIOD_M1, InpFastEMAPeriod,  0, MODE_EMA, PRICE_CLOSE);
   g_hSlowEMA  = iMA(_Symbol, PERIOD_M1, InpSlowEMAPeriod,  0, MODE_EMA, PRICE_CLOSE);
   g_hTrendEMA = iMA(_Symbol, PERIOD_M1, InpTrendEMAPeriod, 0, MODE_EMA, PRICE_CLOSE);
   g_hRSI      = iRSI(_Symbol, PERIOD_M1, InpRSIPeriod, PRICE_CLOSE);
   g_hATR      = iATR(_Symbol, PERIOD_M1, InpATRPeriod);
   g_hADX      = iADX(_Symbol, PERIOD_M1, InpADXPeriod);
   g_hMACD     = iMACD(_Symbol, PERIOD_M1, InpMACDFast, InpMACDSlow, InpMACDSignal, PRICE_CLOSE);
   g_hBB       = iBands(_Symbol, PERIOD_M1, InpBBPeriod, 0, InpBBDeviation, PRICE_CLOSE);

   // Multi-timeframe
   g_hEMA_M5   = iMA(_Symbol, PERIOD_M5, InpTrendEMAPeriod, 0, MODE_EMA, PRICE_CLOSE);
   g_hEMA_M15  = iMA(_Symbol, PERIOD_M15, InpTrendEMAPeriod, 0, MODE_EMA, PRICE_CLOSE);
   g_hATR_M5   = iATR(_Symbol, PERIOD_M5, InpATRPeriod);

   if(g_hFastEMA==INVALID_HANDLE || g_hSlowEMA==INVALID_HANDLE || g_hTrendEMA==INVALID_HANDLE ||
      g_hRSI==INVALID_HANDLE || g_hATR==INVALID_HANDLE || g_hADX==INVALID_HANDLE ||
      g_hMACD==INVALID_HANDLE || g_hBB==INVALID_HANDLE || 
      g_hEMA_M5==INVALID_HANDLE || g_hEMA_M15==INVALID_HANDLE || g_hATR_M5==INVALID_HANDLE)
   {
      Print("[EliteScalper v5.1] FAILED: Indicator initialization error.");
      return false;
   }
   return true;
}

void ReleaseIndicators()
{
   int handles[] = {g_hFastEMA, g_hSlowEMA, g_hTrendEMA, g_hRSI, g_hATR, g_hADX, g_hMACD, g_hBB,
                    g_hEMA_M5, g_hEMA_M15, g_hATR_M5};
   for(int i = 0; i < ArraySize(handles); i++)
      if(handles[i] != INVALID_HANDLE) IndicatorRelease(handles[i]);
}

//+------------------------------------------------------------------+
//| ENHANCED CONFLUENCE WITH QUALITY SCORING                         |
//+------------------------------------------------------------------+
ENUM_SIGNAL EvaluateConfluence(double &qualityScore)
{
   double fastEMA, slowEMA, trendEMA, rsiVal, adxVal;
   bool   inSqueeze = false;

   if(!CheckEMAStack(fastEMA, slowEMA, trendEMA)) 
   {
      qualityScore = 0.0;
      return SIGNAL_NONE;
   }
   
   ENUM_SIGNAL emaSig = (fastEMA > slowEMA && slowEMA > trendEMA) ? SIGNAL_BUY : SIGNAL_SELL;

   int score = 2; // EMA stack = 2 points
   int maxScore = 7;

   if(CheckRSI(emaSig, rsiVal)) score++;
   if(CheckADX(adxVal)) score++;
   if(CheckMACD(emaSig)) score++;
   
   if(CheckBollingerBands(emaSig, inSqueeze))
      score++;
   else if(inSqueeze)
   {
      qualityScore = 0.0;
      return SIGNAL_NONE;
   }

   if(CheckMarketStructure(emaSig)) score++;

   // Multi-timeframe confirmation (bonus point)
   if(InpUseMTFConfirmation && CheckMultiTimeframeTrend(emaSig))
      score++;

   double baseQuality = (score / (double)maxScore) * 100.0;
   
   // Calculate comprehensive quality score
   double atr = GetATR();
   ENUM_MARKET_REGIME regime = g_CurrentMarket.currentRegime;
   
   qualityScore = CalculateTradeQuality(emaSig, rsiVal, adxVal, atr, regime);

   // Adaptive threshold
   double requiredScore = InpAdaptiveThreshold ? g_DynamicConfluenceThreshold : 5.0;
   
   if(score >= requiredScore) 
      return emaSig;

   qualityScore = baseQuality;  // Return partial score even if failed
   return SIGNAL_NONE;
}

//+------------------------------------------------------------------+
//| TRADE QUALITY CALCULATION                                        |
//+------------------------------------------------------------------+
double CalculateTradeQuality(ENUM_SIGNAL sig, double rsi, double adx, double atr, ENUM_MARKET_REGIME regime)
{
   double quality = 0.0;
   double weights = 0.0;

   // ADX strength (0-30 points)
   if(adx >= InpADXMinStrength)
   {
      double adxScore = MathMin(30.0, (adx / 40.0) * 30.0);
      quality += adxScore;
   }
   weights += 30.0;

   // RSI position (0-20 points)
   double rsiScore = 0.0;
   if(sig == SIGNAL_BUY)
      rsiScore = (rsi > 50 && rsi < InpRSIOverbought) ? ((rsi - 50.0) / 20.0) * 20.0 : 0.0;
   else
      rsiScore = (rsi < 50 && rsi > InpRSIOversold) ? ((50.0 - rsi) / 20.0) * 20.0 : 0.0;
   quality += rsiScore;
   weights += 20.0;

   // Market regime suitability (0-25 points)
   double regimeScore = 0.0;
   switch(regime)
   {
      case REGIME_STRONG_TREND:     regimeScore = 25.0; break;
      case REGIME_WEAK_TREND:       regimeScore = 15.0; break;
      case REGIME_RANGING:          regimeScore = 0.0;  break;
      case REGIME_HIGH_VOLATILITY:  regimeScore = 10.0; break;
      case REGIME_LOW_VOLATILITY:   regimeScore = 5.0;  break;
   }
   quality += regimeScore;
   weights += 25.0;

   // Multi-timeframe alignment (0-15 points)
   if(g_CurrentMarket.trendAlignment)
      quality += 15.0;
   weights += 15.0;

   // Volatility appropriateness (0-10 points)
   double volIndex = g_CurrentMarket.volatilityIndex;
   double volScore = 0.0;
   if(volIndex >= InpMinVolatilityIndex && volIndex <= InpMaxVolatilityIndex)
      volScore = 10.0;
   else if(volIndex < InpMinVolatilityIndex)
      volScore = (volIndex / InpMinVolatilityIndex) * 5.0;
   quality += volScore;
   weights += 10.0;

   return (quality / weights) * 100.0;
}

//+------------------------------------------------------------------+
//| MULTI-TIMEFRAME TREND CONFIRMATION                               |
//+------------------------------------------------------------------+
bool CheckMultiTimeframeTrend(ENUM_SIGNAL sig)
{
   ENUM_TREND_DIRECTION m1  = GetTrendDirection(PERIOD_M1);
   ENUM_TREND_DIRECTION m5  = GetTrendDirection(PERIOD_M5);
   ENUM_TREND_DIRECTION m15 = GetTrendDirection(PERIOD_M15);

   g_MTFText = TrendToString(m1) + " | " + TrendToString(m5) + " | " + TrendToString(m15);

   if(sig == SIGNAL_BUY)
      return (m1 == TREND_UP && m5 == TREND_UP && m15 == TREND_UP);
   else if(sig == SIGNAL_SELL)
      return (m1 == TREND_DOWN && m5 == TREND_DOWN && m15 == TREND_DOWN);
   
   return false;
}

ENUM_TREND_DIRECTION GetTrendDirection(ENUM_TIMEFRAMES tf)
{
   int handle = (tf == PERIOD_M5) ? g_hEMA_M5 : (tf == PERIOD_M15) ? g_hEMA_M15 : g_hTrendEMA;
   
   double ema[3];
   if(CopyBuffer(handle, 0, 0, 3, ema) <= 0) return TREND_NONE;
   
   double price = (tf == PERIOD_M1) ? SymbolInfoDouble(_Symbol, SYMBOL_BID) : 
                  iClose(_Symbol, tf, 0);
   
   bool rising = (ema[0] > ema[1] && ema[1] > ema[2]);
   bool falling = (ema[0] < ema[1] && ema[1] < ema[2]);
   
   if(rising && price > ema[0]) return TREND_UP;
   if(falling && price < ema[0]) return TREND_DOWN;
   
   return TREND_SIDEWAYS;
}

//+------------------------------------------------------------------+
//| MARKET CONDITIONS ANALYSIS                                       |
//+------------------------------------------------------------------+
void AnalyzeMarketConditions()
{
   g_CurrentMarket.timestamp = TimeCurrent();
   g_CurrentMarket.currentRegime = DetectMarketRegime();
   g_CurrentMarket.m1Trend = GetTrendDirection(PERIOD_M1);
   g_CurrentMarket.m5Trend = GetTrendDirection(PERIOD_M5);
   g_CurrentMarket.m15Trend = GetTrendDirection(PERIOD_M15);
   
   // Trend alignment check
   g_CurrentMarket.trendAlignment = (
      (g_CurrentMarket.m1Trend == g_CurrentMarket.m5Trend && 
       g_CurrentMarket.m5Trend == g_CurrentMarket.m15Trend) &&
      (g_CurrentMarket.m1Trend != TREND_SIDEWAYS)
   );
   
   g_CurrentMarket.volatilityIndex = CalculateVolatilityIndex();
   g_CurrentMarket.volumeProfile = GetVolumeProfile();
   
   double adx[1];
   if(CopyBuffer(g_hADX, 0, 0, 1, adx) > 0)
      g_CurrentMarket.trendStrength = adx[0];
   
   g_RegimeText = RegimeToString(g_CurrentMarket.currentRegime);
}

ENUM_MARKET_REGIME DetectMarketRegime()
{
   double adx[1], atr[1];
   if(CopyBuffer(g_hADX, 0, 0, 1, adx) <= 0) return REGIME_UNKNOWN;
   if(CopyBuffer(g_hATR, 0, 0, 1, atr) <= 0) return REGIME_UNKNOWN;
   
   double volIndex = CalculateVolatilityIndex();
   
   // High volatility regime
   if(volIndex > InpMaxVolatilityIndex * 0.8)
      return REGIME_HIGH_VOLATILITY;
   
   // Low volatility
   if(volIndex < InpMinVolatilityIndex * 1.2)
      return REGIME_LOW_VOLATILITY;
   
   // Strong trend
   if(adx[0] > 35.0)
      return REGIME_STRONG_TREND;
   
   // Weak trend
   if(adx[0] > 20.0 && adx[0] <= 35.0)
      return REGIME_WEAK_TREND;
   
   // Ranging
   if(adx[0] <= 20.0)
      return REGIME_RANGING;
   
   return REGIME_UNKNOWN;
}

double CalculateVolatilityIndex()
{
   double atr[1];
   if(CopyBuffer(g_hATR, 0, 0, 1, atr) <= 0) return 0.0;
   
   double price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(price <= 0.0) return 0.0;
   
   return (atr[0] / price) * 100.0;  // ATR as % of price
}

double GetVolumeProfile()
{
   long tickVol = 0;
   long avgVol = 0;
   
   for(int i = 0; i < 20; i++)
   {
      long vol = iVolume(_Symbol, PERIOD_M1, i);
      if(i == 0) tickVol = vol;
      avgVol += vol;
   }
   
   if(avgVol == 0) return 1.0;
   return (double)tickVol / ((double)avgVol / 20.0);
}

//+------------------------------------------------------------------+
//| CHECK IF MARKET CONDITIONS ARE FAVORABLE                         |
//+------------------------------------------------------------------+
bool IsMarketConditionFavorable()
{
   // Block ranging markets
   if(InpBlockRangeMarkets && g_CurrentMarket.currentRegime == REGIME_RANGING)
   {
      Print("[Market Analysis] Ranging market detected – blocking trades");
      return false;
   }
   
   // Check volatility bounds
   if(g_CurrentMarket.volatilityIndex < InpMinVolatilityIndex)
   {
      Print("[Market Analysis] Volatility too low: ", 
            DoubleToString(g_CurrentMarket.volatilityIndex, 2), "%");
      return false;
   }
   
   if(g_CurrentMarket.volatilityIndex > InpMaxVolatilityIndex)
   {
      Print("[Market Analysis] Volatility too high: ", 
            DoubleToString(g_CurrentMarket.volatilityIndex, 2), "%");
      return false;
   }
   
   // Check win rate threshold
   int totalTrades = g_DailyWins + g_DailyLosses;
   if(totalTrades >= 5)
   {
      double winRate = ((double)g_DailyWins / totalTrades) * 100.0;
      if(winRate < InpMinWinRatePercent)
      {
         Print("[Market Analysis] Win rate too low: ", DoubleToString(winRate, 1), 
               "% – pausing until conditions improve");
         return false;
      }
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| POST-TRADE MARKET REVIEW                                         |
//+------------------------------------------------------------------+
void PostTradeMarketReview()
{
   static datetime lastReview = 0;
   datetime now = TimeCurrent();
   
   // Only review once per closed trade
   if(now - lastReview < 5) return;
   
   if(!HistorySelect(now - 60, now)) return;
   
   for(int i = HistoryDealsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = HistoryDealGetTicket(i);
      if(ticket == 0) continue;
      if(HistoryDealGetInteger(ticket, DEAL_MAGIC) != (long)InpMagicNumber) continue;
      if(HistoryDealGetString(ticket, DEAL_SYMBOL) != _Symbol) continue;
      if(HistoryDealGetInteger(ticket, DEAL_ENTRY) != DEAL_ENTRY_OUT) continue;
      
      datetime closeTime = (datetime)HistoryDealGetInteger(ticket, DEAL_TIME);
      if(closeTime > lastReview)
      {
         RecordTradeOutcome(ticket);
         AnalyzeTradeHistory();
         AdjustConfluenceThreshold();
         lastReview = now;
         
         Print("[Post-Trade Review] Market analysis updated. New threshold: ", 
               DoubleToString(g_DynamicConfluenceThreshold, 1));
         break;
      }
   }
}

//+------------------------------------------------------------------+
//| RECORD TRADE OUTCOME FOR LEARNING                                |
//+------------------------------------------------------------------+
void RecordTradeOutcome(ulong ticket)
{
   TradeRecord rec;
   rec.closeTime = (datetime)HistoryDealGetInteger(ticket, DEAL_TIME);
   rec.profit = HistoryDealGetDouble(ticket, DEAL_PROFIT) +
                HistoryDealGetDouble(ticket, DEAL_COMMISSION) +
                HistoryDealGetDouble(ticket, DEAL_SWAP);
   
   // Get conditions at time of entry (approximate from current if recent)
   double rsi[1], adx[1], atr[1];
   CopyBuffer(g_hRSI, 0, 0, 1, rsi);
   CopyBuffer(g_hADX, 0, 0, 1, adx);
   CopyBuffer(g_hATR, 0, 0, 1, atr);
   
   rec.rsi = rsi[0];
   rec.adx = adx[0];
   rec.atr = atr[0];
   rec.regime = g_CurrentMarket.currentRegime;
   rec.mtfTrend = g_CurrentMarket.m1Trend;
   
   MqlDateTime dt;
   TimeToStruct(rec.closeTime, dt);
   rec.entryHour = dt.hour;
   rec.spreadAtEntry = (double)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   rec.qualityScore = g_CurrentQualityScore;
   
   // Determine signal type from deal type
   ENUM_DEAL_TYPE dealType = (ENUM_DEAL_TYPE)HistoryDealGetInteger(ticket, DEAL_TYPE);
   rec.signal = (dealType == DEAL_TYPE_BUY) ? SIGNAL_SELL : SIGNAL_BUY;  // Inverse (close opposite)
   
   // Shift array and add new record
   if(g_HistoryCount < MAX_HISTORY_RECORDS)
   {
      g_TradeHistory[g_HistoryCount] = rec;
      g_HistoryCount++;
   }
   else
   {
      // Shift left, discard oldest
      for(int i = 0; i < MAX_HISTORY_RECORDS - 1; i++)
         g_TradeHistory[i] = g_TradeHistory[i + 1];
      g_TradeHistory[MAX_HISTORY_RECORDS - 1] = rec;
   }
   
   Print("[Trade Recorded] P&L: $", DoubleToString(rec.profit, 2), 
         " | Quality: ", DoubleToString(rec.qualityScore, 1), 
         "% | Regime: ", RegimeToString(rec.regime));
}

//+------------------------------------------------------------------+
//| ANALYZE TRADE HISTORY FOR PATTERNS                               |
//+------------------------------------------------------------------+
void AnalyzeTradeHistory()
{
   if(g_HistoryCount < 5) return;  // Need minimum sample
   
   int analyzDepth = MathMin(g_HistoryCount, InpMarketAnalysisDepth);
   
   double totalWinQuality = 0.0;
   double totalLossQuality = 0.0;
   int wins = 0;
   int losses = 0;
   
   // Analyze patterns
   for(int i = g_HistoryCount - analyzDepth; i < g_HistoryCount; i++)
   {
      if(g_TradeHistory[i].profit > 0)
      {
         totalWinQuality += g_TradeHistory[i].qualityScore;
         wins++;
      }
      else
      {
         totalLossQuality += g_TradeHistory[i].qualityScore;
         losses++;
      }
   }
   
   g_ProfitableTrades = wins;
   g_UnprofitableTrades = losses;
   
   if(wins > 0) g_AvgWinningQuality = totalWinQuality / wins;
   if(losses > 0) g_AvgLosingQuality = totalLossQuality / losses;
   
   Print("[Trade Analysis] Last ", analyzDepth, " trades: ",
         wins, " wins (avg quality: ", DoubleToString(g_AvgWinningQuality, 1), "%), ",
         losses, " losses (avg quality: ", DoubleToString(g_AvgLosingQuality, 1), "%)");
}

//+------------------------------------------------------------------+
//| ADJUST CONFLUENCE THRESHOLD BASED ON PERFORMANCE                 |
//+------------------------------------------------------------------+
void AdjustConfluenceThreshold()
{
   if(!InpAdaptiveThreshold) return;
   if(g_ProfitableTrades + g_UnprofitableTrades < 10) return;
   
   double winRate = (double)g_ProfitableTrades / (g_ProfitableTrades + g_UnprofitableTrades);
   
   // If losing, increase selectivity
   if(winRate < 0.5)
   {
      g_DynamicConfluenceThreshold = MathMin(6.5, g_DynamicConfluenceThreshold + 0.5);
      Print("[Adaptive Threshold] Performance below 50% – increasing threshold to ", 
            DoubleToString(g_DynamicConfluenceThreshold, 1));
   }
   // If winning consistently, can be slightly more aggressive
   else if(winRate > 0.65)
   {
      g_DynamicConfluenceThreshold = MathMax(4.5, g_DynamicConfluenceThreshold - 0.25);
      Print("[Adaptive Threshold] Performance above 65% – decreasing threshold to ", 
            DoubleToString(g_DynamicConfluenceThreshold, 1));
   }
}

//+------------------------------------------------------------------+
//| HELPER FUNCTIONS                                                 |
//+------------------------------------------------------------------+
string RegimeToString(ENUM_MARKET_REGIME regime)
{
   switch(regime)
   {
      case REGIME_STRONG_TREND:    return "STRONG TREND";
      case REGIME_WEAK_TREND:      return "WEAK TREND";
      case REGIME_RANGING:         return "RANGING";
      case REGIME_HIGH_VOLATILITY: return "HIGH VOLATILITY";
      case REGIME_LOW_VOLATILITY:  return "LOW VOLATILITY";
      default:                     return "UNKNOWN";
   }
}

string TrendToString(ENUM_TREND_DIRECTION trend)
{
   switch(trend)
   {
      case TREND_UP:       return "UP";
      case TREND_DOWN:     return "DOWN";
      case TREND_SIDEWAYS: return "SIDE";
      default:             return "—";
   }
}

// [Previous helper functions remain the same: CheckEMAStack, CheckRSI, CheckADX, etc.]
bool CheckEMAStack(double &fast, double &slow, double &trend)
{
   double f[1], s[1], t[1];
   if(CopyBuffer(g_hFastEMA,  0, 0, 1, f) <= 0) return false;
   if(CopyBuffer(g_hSlowEMA,  0, 0, 1, s) <= 0) return false;
   if(CopyBuffer(g_hTrendEMA, 0, 0, 1, t) <= 0) return false;
   fast = f[0]; slow = s[0]; trend = t[0];
   bool bull = (fast > slow && slow > trend);
   bool bear = (fast < slow && slow < trend);
   return (bull || bear);
}

bool CheckRSI(ENUM_SIGNAL sig, double &rsiVal)
{
   double r[1];
   if(CopyBuffer(g_hRSI, 0, 0, 1, r) <= 0) return false;
   rsiVal = r[0];
   if(sig == SIGNAL_BUY)  return (rsiVal > 50.0 && rsiVal < InpRSIOverbought);
   if(sig == SIGNAL_SELL) return (rsiVal < 50.0 && rsiVal > InpRSIOversold);
   return false;
}

bool CheckADX(double &adxVal)
{
   double adx[1];
   if(CopyBuffer(g_hADX, 0, 0, 1, adx) <= 0) return false;
   adxVal = adx[0];
   return (adxVal >= InpADXMinStrength);
}

bool CheckMACD(ENUM_SIGNAL sig)
{
   double hist[2];
   if(CopyBuffer(g_hMACD, 2, 0, 2, hist) <= 0) return false;
   bool rising = (hist[0] > hist[1]);
   if(sig == SIGNAL_BUY)  return (hist[0] > 0 && rising);
   if(sig == SIGNAL_SELL) return (hist[0] < 0 && !rising);
   return false;
}

bool CheckBollingerBands(ENUM_SIGNAL sig, bool &inSqueeze)
{
   double upper[1], lower[1], mid[1];
   if(CopyBuffer(g_hBB, 1, 0, 1, upper) <= 0) return false;
   if(CopyBuffer(g_hBB, 2, 0, 1, lower) <= 0) return false;
   if(CopyBuffer(g_hBB, 0, 0, 1, mid) <= 0) return false;

   double width = upper[0] - lower[0];
   double price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double squeezeThresh = price * InpBBSqueezeRatio;

   if(width < squeezeThresh) { inSqueeze = true; return false; }
   inSqueeze = false;

   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(sig == SIGNAL_BUY)  return (bid > mid[0]);
   if(sig == SIGNAL_SELL) return (bid < mid[0]);
   return false;
}

bool CheckMarketStructure(ENUM_SIGNAL sig)
{
   int highBar = iHighest(_Symbol, _Period, MODE_HIGH, InpStructureBars, 1);
   int lowBar  = iLowest(_Symbol, _Period, MODE_LOW, InpStructureBars, 1);
   if(highBar < 0 || lowBar < 0) return false;

   double swingHigh = iHigh(_Symbol, _Period, highBar);
   double swingLow  = iLow(_Symbol, _Period, lowBar);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);

   if(sig == SIGNAL_BUY)  return (ask > swingHigh);
   if(sig == SIGNAL_SELL) return (bid < swingLow);
   return false;
}

double GetATR()
{
   double atr[1];
   if(CopyBuffer(g_hATR, 0, 0, 1, atr) <= 0) return 0.0;
   return atr[0];
}

// [Continue with remaining original functions...]
double CalculateLotSize(int slPoints)
{
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double riskPct = GetRiskAdjustedPercent();
   double riskAmount = balance * (riskPct / 100.0);

   double tickVal = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);

   double slCostPerLot = (slPoints * point / tickSize) * tickVal;
   if(slCostPerLot <= 0.0) return SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);

   double lot = riskAmount / slCostPerLot;
   double minV = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxV = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);

   lot = MathMax(minV, MathMin(maxV, MathFloor(lot / step) * step));
   return lot;
}

double GetRiskAdjustedPercent()
{
   double pct = InpRiskPercent;
   if(g_ConsecLosses >= InpMaxLossStreak)
      pct = InpRiskPercent * 0.5;
   else if(g_ConsecWins >= InpWinStreakBoost)
      pct = MathMin(InpRiskPercent * 1.25, 2.0);
   return pct;
}

void ExecuteEntry(ENUM_SIGNAL sig, double qualityScore)
{
   if(!IsSpreadOk()) { Print("[Entry] Spread too wide – aborted."); return; }

   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   double atr = GetATR();
   double price = (sig == SIGNAL_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                       : SymbolInfoDouble(_Symbol, SYMBOL_BID);

   int slPoints = (int)MathRound((atr * InpSLMultiplier) / point);
   slPoints = MathMax(InpMinSLPoints, MathMin(InpMaxSLPoints, slPoints));

   int tp2Points = (int)MathRound((atr * InpTP2Multiplier) / point);

   double sl, tp;
   if(sig == SIGNAL_BUY)
   {
      sl = NormalizeDouble(price - slPoints * point, digits);
      tp = NormalizeDouble(price + tp2Points * point, digits);
   }
   else
   {
      sl = NormalizeDouble(price + slPoints * point, digits);
      tp = NormalizeDouble(price - tp2Points * point, digits);
   }

   double lot = CalculateLotSize(slPoints);

   Print("[Entry] ", (sig==SIGNAL_BUY?"BUY":"SELL"),
         " Quality=", DoubleToString(qualityScore, 1), "% ",
         "Price=", price, " SL=", sl, " TP=", tp, " Lot=", lot);

   bool ok = (sig == SIGNAL_BUY) ? g_Trade.Buy(lot, _Symbol, price, sl, tp, InpTradeComment)
                                 : g_Trade.Sell(lot, _Symbol, price, sl, tp, InpTradeComment);
   if(ok)
   {
      g_DailyTrades++;
      g_PartialClosed = false;
      g_StatusText = (sig==SIGNAL_BUY) ? "IN TRADE – LONG" : "IN TRADE – SHORT";
      g_StatusColor = C_GREEN;
   }
   else
   {
      Print("[Entry] FAILED. RetCode=", g_Trade.ResultRetcode());
   }
}

void ProcessAnalysisPhase()
{
   g_AnalysisTicks++;
   int elapsed = (int)(TimeCurrent() - g_AnalysisStart);

   g_StatusText = "ANALYSING: " + IntegerToString(elapsed) + "s | Ticks: " + IntegerToString(g_AnalysisTicks);
   g_StatusColor = C_PURPLE;

   if(elapsed > InpAnalysisMaxSec)
   {
      Print("[Analysis] Timeout – signal invalidated.");
      g_State = STATE_SCANNING;
      return;
   }

   double qualityScore = 0.0;
   ENUM_SIGNAL current = EvaluateConfluence(qualityScore);
   
   if(current != g_PendingSignal || qualityScore < InpMinQualityScore)
   {
      Print("[Analysis] Signal reversed or quality dropped – invalidated.");
      g_State = STATE_SCANNING;
      return;
   }

   if(elapsed >= InpAnalysisMinSec && g_AnalysisTicks >= InpAnalysisMinTicks)
   {
      Print("[Analysis] Complete – executing with quality ", DoubleToString(qualityScore, 1), "%");
      ExecuteEntry(g_PendingSignal, qualityScore);
      g_State = STATE_SCANNING;
   }
}

void ManageOpenTrade()
{
   EvaluateFloatingPnL();
   if(!IsPositionOpen()) return;
   CheckPartialClose();
   CheckBreakeven();
   if(InpUseTrailing) CheckTrailing();
   g_StatusText = "TRADE RUNNING";
   g_StatusColor = C_GREEN;
}

void CheckBreakeven()
{
   for(int i = PositionsTotal()-1; i >= 0; i--)
   {
      if(!g_Pos.SelectByIndex(i)) continue;
      if(g_Pos.Magic() != InpMagicNumber || g_Pos.Symbol() != _Symbol) continue;

      double open = g_Pos.PriceOpen();
      double sl = g_Pos.StopLoss();
      double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
      double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
      bool isBuy = (g_Pos.PositionType() == POSITION_TYPE_BUY);

      double profitPts = isBuy ? (bid - open)/point : (open - ask)/point;

      if(profitPts >= InpBreakevenPoints)
      {
         double beSL = isBuy ? NormalizeDouble(open + InpBreakevenBuffer*point, digits)
                              : NormalizeDouble(open - InpBreakevenBuffer*point, digits);
         bool needsMove = isBuy ? (sl < beSL) : (sl > beSL);
         if(needsMove)
            g_Trade.PositionModify(g_Pos.Ticket(), beSL, g_Pos.TakeProfit());
      }
   }
}

void CheckTrailing()
{
   for(int i = PositionsTotal()-1; i >= 0; i--)
   {
      if(!g_Pos.SelectByIndex(i)) continue;
      if(g_Pos.Magic() != InpMagicNumber || g_Pos.Symbol() != _Symbol) continue;

      double open = g_Pos.PriceOpen();
      double sl = g_Pos.StopLoss();
      double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
      double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
      bool isBuy = (g_Pos.PositionType() == POSITION_TYPE_BUY);

      double profitPts = isBuy ? (bid - open)/point : (open - ask)/point;
      if(profitPts < InpTrailStartPoints) continue;

      double newSL = isBuy ? NormalizeDouble(bid - InpTrailStepPoints*point, digits)
                           : NormalizeDouble(ask + InpTrailStepPoints*point, digits);

      bool improves = isBuy ? (newSL > sl) : (newSL < sl || sl == 0.0);
      if(improves)
         g_Trade.PositionModify(g_Pos.Ticket(), newSL, g_Pos.TakeProfit());
   }
}

void CheckPartialClose()
{
   if(!InpUsePartialClose || g_PartialClosed) return;

   for(int i = PositionsTotal()-1; i >= 0; i--)
   {
      if(!g_Pos.SelectByIndex(i)) continue;
      if(g_Pos.Magic() != InpMagicNumber || g_Pos.Symbol() != _Symbol) continue;

      double open = g_Pos.PriceOpen();
      double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
      double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      bool isBuy = (g_Pos.PositionType() == POSITION_TYPE_BUY);

      double profitPts = isBuy ? (bid - open)/point : (open - ask)/point;
      double atr = GetATR();
      double tp1Pts = (atr * InpTP1Multiplier) / point;

      if(profitPts >= tp1Pts)
      {
         double closeLot = NormalizeDouble(g_Pos.Volume() * (InpPartialClosePct / 100.0),
                            (int)MathLog10(1.0/SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP)));
         double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
         if(closeLot >= minLot)
         {
            if(g_Trade.PositionClosePartial(g_Pos.Ticket(), closeLot))
               g_PartialClosed = true;
         }
      }
   }
}

void EvaluateFloatingPnL()
{
   if(!IsPositionOpen()) return;
   double pnl = GetFloatingPnL();
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double dailyGoal = balance * (InpMaxDailyProfitPct / 100.0);
   double remaining = dailyGoal - g_DailyProfit;
   if(remaining > 0.0 && pnl >= remaining)
   {
      CloseAllPositions("Daily profit target via floating P&L");
      g_State = STATE_DAILY_LIMIT;
   }
}

bool IsPositionOpen()
{
   for(int i = PositionsTotal()-1; i >= 0; i--)
      if(g_Pos.SelectByIndex(i) && g_Pos.Magic()==InpMagicNumber && g_Pos.Symbol()==_Symbol) 
         return true;
   return false;
}

double GetFloatingPnL()
{
   double total = 0.0;
   for(int i = PositionsTotal()-1; i >= 0; i--)
      if(g_Pos.SelectByIndex(i) && g_Pos.Magic()==InpMagicNumber && g_Pos.Symbol()==_Symbol)
         total += g_Pos.Profit() + g_Pos.Swap() + g_Pos.Commission();
   return total;
}

void CloseAllPositions(string reason)
{
   Print("[Close All] ", reason);
   for(int i = PositionsTotal()-1; i >= 0; i--)
      if(g_Pos.SelectByIndex(i) && g_Pos.Magic()==InpMagicNumber && g_Pos.Symbol()==_Symbol)
         g_Trade.PositionClose(g_Pos.Ticket());
   g_StateTimer = TimeCurrent() + InpCooldownSeconds;
   g_State = STATE_COOLDOWN;
}

bool IsMarketOpen()
{
   ENUM_SYMBOL_TRADE_MODE m = (ENUM_SYMBOL_TRADE_MODE)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_MODE);
   return (m == SYMBOL_TRADE_MODE_FULL);
}

bool IsInSession()
{
   MqlDateTime t; TimeToStruct(TimeGMT(), t);
   return (t.hour >= InpSessionStartGMT && t.hour < InpSessionEndGMT);
}

bool IsSpreadOk()
{
   double spread = (double)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   if(spread > InpSpreadMaxPoints) return false;
   if(g_SpreadSamples > 50 && spread > g_AvgSpread * InpSpreadMultiplier) return false;
   return true;
}

void UpdateSpreadAverage()
{
   double spread = (double)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   g_AvgSpread = (g_AvgSpread * g_SpreadSamples + spread) / (double)(g_SpreadSamples + 1);
   g_SpreadSamples = MathMin(g_SpreadSamples + 1, 2000);
}

bool IsDailyLossLimitHit()
{
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double limit = balance * (InpMaxDailyLossPct / 100.0);
   return (g_DailyProfit <= -MathAbs(limit));
}

bool IsDailyProfitTargetHit()
{
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double target = balance * (InpMaxDailyProfitPct / 100.0);
   return (g_DailyProfit >= target);
}

datetime GetDayStart(datetime t)
{
   MqlDateTime d; TimeToStruct(t, d);
   return t - (datetime)(d.hour*3600 + d.min*60 + d.sec);
}

void SyncDailyStats()
{
   datetime now = TimeCurrent();
   datetime dayStart = GetDayStart(now);

   if(dayStart > g_SessionDay)
   {
      g_SessionDay = dayStart;
      g_DailyTrades = 0;
      g_DailyProfit = 0.0;
      g_DailyWins = 0;
      g_DailyLosses = 0;
      g_TotalReopens = 0;
      g_SessionOpenBal = AccountInfoDouble(ACCOUNT_BALANCE);
      if(g_State == STATE_DAILY_LIMIT) g_State = STATE_SCANNING;
   }

   g_DailyProfit = 0.0;
   g_DailyWins = 0;
   g_DailyLosses = 0;
   g_ConsecLosses = 0;
   g_ConsecWins = 0;

   if(!HistorySelect(dayStart, now)) return;

   bool lastWasWin = false;
   int curStreak = 0;

   for(int i = 0; i < HistoryDealsTotal(); i++)
   {
      ulong tkt = HistoryDealGetTicket(i);
      if(tkt == 0) continue;
      if(HistoryDealGetInteger(tkt, DEAL_MAGIC) != (long)InpMagicNumber) continue;
      if(HistoryDealGetString(tkt, DEAL_SYMBOL) != _Symbol) continue;
      if(HistoryDealGetInteger(tkt, DEAL_ENTRY) != DEAL_ENTRY_OUT) continue;

      double pnl = HistoryDealGetDouble(tkt, DEAL_PROFIT) +
                   HistoryDealGetDouble(tkt, DEAL_COMMISSION) +
                   HistoryDealGetDouble(tkt, DEAL_SWAP);
      g_DailyProfit += pnl;
      bool win = (pnl >= 0.0);
      if(win) g_DailyWins++; else g_DailyLosses++;

      if(win == lastWasWin) curStreak++; else curStreak = 1;
      lastWasWin = win;
   }

   if(lastWasWin) g_ConsecWins = curStreak;
   else g_ConsecLosses = curStreak;
}

//+------------------------------------------------------------------+
//| ENHANCED DASHBOARD                                               |
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| DASHBOARD RENDERING - PREMIUM LUXURY EDITION                     |
//+------------------------------------------------------------------+
void RenderDashboard()
{
   int X = InpDashX, Y = InpDashY;
   int W = 680, H = 580;  // Optimized size - fits all screens

   // Main background with subtle gradient effect
   DrawRect("BG",    X,   Y,   W,   H,   C_BG, C_BORDER, 3);
   
   // Header section with premium styling
   DrawRect("HDR",   X+3, Y+3, W-6, 72,  C_HEADER, C_BLUE, 1);
   DrawRect("HDR_ACCENT", X+3, Y+3, 6, 72, C_GOLD, clrNONE, 0); // Gold accent bar
   
   DrawLabel("T1",  X+18, Y+12, "⬡ ELITE SCALPER",        C_GOLD, 20, "Impact");
   DrawLabel("T2",  X+18, Y+38, "ADVANCED GOLD ENGINE",    C_WHITE,  11,  "Arial Black");
   DrawLabel("T3",  X+18, Y+56, "v6.0 PRO | Multi-Analysis Suite", C_CYAN, 8, "Arial");
   
   // Symbol display with live indicator
   DrawRect("SYM_BG", X+W-160, Y+8, 150, 58, C_PANEL, C_GOLD, 1);
   DrawLabel("SYM", X+W-150, Y+18, _Symbol, C_GOLD, 16, "Impact");
   DrawLabel("SYM_STATUS", X+W-150, Y+42, "● LIVE", C_GREEN, 9, "Arial Black");

   // System Status Bar
   int SBAR = Y+80;
   DrawRect("STATUSBAR", X+3, SBAR, W-6, 28, C_PANEL, clrNONE, 0);
   DrawLabel("SB_LABEL", X+12, SBAR+8, "⚡ CORE STATUS:", C_GOLD, 9, "Arial Black");
   DrawLabel("SB_VALUE", X+150, SBAR+8, "INITIALIZING", C_BLUE, 9, "Consolas Bold");
   DrawLabel("SB_PULSE", X+W-120, SBAR+8, "█ ▓ █ █", C_BLUE, 9, "Consolas");

   // ═══════════════════ TWO-COLUMN LAYOUT ═══════════════════
   int COL1_X = X+8;
   int COL2_X = X+348;
   int COL_W = 320;
   int ROW_Y = SBAR+35;

   // ─────────────────── COLUMN 1: TRADING METRICS ───────────────────
   
   // Panel 1: Account Financials
   DrawRect("P1", COL1_X, ROW_Y, COL_W, 140, C_PANEL, C_BLUE, 1);
   DrawRect("P1_HDR", COL1_X+2, ROW_Y+2, COL_W-4, 24, C_HEADER, clrNONE, 0);
   DrawLabel("P1H", COL1_X+10, ROW_Y+7, "💰 ACCOUNT FINANCIALS", C_GOLD, 10, "Arial Black");
   
   int P1Y = ROW_Y+32;
   DrawLabel("L_BAL", COL1_X+12, P1Y,      "Balance:",     C_MUTED, 9, "Arial");
   DrawLabel("V_BAL", COL1_X+200, P1Y,     "$0.00",        C_WHITE, 10, "Arial Bold");
   
   DrawLabel("L_EQ",  COL1_X+12, P1Y+24,   "Equity:",      C_MUTED, 9, "Arial");
   DrawLabel("V_EQ",  COL1_X+200, P1Y+24,  "$0.00",        C_WHITE, 10, "Arial Bold");
   
   DrawLabel("L_DP",  COL1_X+12, P1Y+48,   "Daily P&L:",   C_MUTED, 9, "Arial");
   DrawLabel("V_DP",  COL1_X+200, P1Y+48,  "$0.00",        C_GREEN, 11, "Arial Black");
   
   DrawLabel("L_FP",  COL1_X+12, P1Y+72,   "Float P&L:",   C_MUTED, 9, "Arial");
   DrawLabel("V_FP",  COL1_X+200, P1Y+72,  "$0.00",        C_GREEN, 11, "Arial Black");
   
   DrawLabel("L_PF",  COL1_X+12, P1Y+96,   "Profit Factor:", C_MUTED, 9, "Arial");
   DrawLabel("V_PF",  COL1_X+200, P1Y+96,  "0.00",         C_WHITE, 10, "Arial Bold");

   // Panel 2: Performance Stats
   ROW_Y += 148;
   DrawRect("P2", COL1_X, ROW_Y, COL_W, 115, C_PANEL, C_GREEN, 1);
   DrawRect("P2_HDR", COL1_X+2, ROW_Y+2, COL_W-4, 24, C_HEADER, clrNONE, 0);
   DrawLabel("P2H", COL1_X+10, ROW_Y+7, "📊 PERFORMANCE", C_GOLD, 10, "Arial Black");
   
   int P2Y = ROW_Y+32;
   DrawLabel("L_TR",  COL1_X+12, P2Y,      "Trades:",      C_MUTED, 9, "Arial");
   DrawLabel("V_TR",  COL1_X+200, P2Y,     "0 / 15",       C_WHITE, 10, "Arial Bold");
   
   DrawLabel("L_WR",  COL1_X+12, P2Y+24,   "Win Rate:",    C_MUTED, 9, "Arial");
   DrawLabel("V_WR",  COL1_X+200, P2Y+24,  "0%",           C_WHITE, 10, "Arial Bold");
   
   DrawLabel("L_AVG", COL1_X+12, P2Y+48,   "Avg W/L:",     C_MUTED, 9, "Arial");
   DrawLabel("V_AVG", COL1_X+200, P2Y+48,  "$0/$0",        C_WHITE, 9, "Arial Bold");
   
   DrawLabel("L_STK", COL1_X+12, P2Y+72,   "Streak:",      C_MUTED, 9, "Arial");
   DrawLabel("V_STK", COL1_X+200, P2Y+72,  "—",            C_WHITE, 10, "Arial Bold");

   // Panel 3: Execution Info
   ROW_Y += 123;
   DrawRect("P3", COL1_X, ROW_Y, COL_W, 90, C_PANEL, C_PURPLE, 1);
   DrawRect("P3_HDR", COL1_X+2, ROW_Y+2, COL_W-4, 24, C_HEADER, clrNONE, 0);
   DrawLabel("P3H", COL1_X+10, ROW_Y+7, "⚙️ EXECUTION", C_GOLD, 10, "Arial Black");
   
   int P3Y = ROW_Y+32;
   DrawLabel("L_LOT", COL1_X+12, P3Y,      "Next Lot:",    C_MUTED, 9, "Arial");
   DrawLabel("V_LOT", COL1_X+200, P3Y,     "0.01",         C_CYAN, 10, "Arial Bold");
   
   DrawLabel("L_SLT", COL1_X+12, P3Y+24,   "SL/TP2:",      C_MUTED, 9, "Arial");
   DrawLabel("V_SLT", COL1_X+200, P3Y+24,  "0/0 pts",      C_WHITE, 9, "Arial Bold");
   
   DrawLabel("L_SPR", COL1_X+12, P3Y+48,   "Spread:",      C_MUTED, 9, "Arial");
   DrawLabel("V_SPR", COL1_X+200, P3Y+48,  "0 pts",        C_WHITE, 9, "Arial Bold");

   // ─────────────────── COLUMN 2: MARKET INTELLIGENCE ───────────────────
   ROW_Y = SBAR+35;

   // Panel 4: Market Regime
   DrawRect("P4", COL2_X, ROW_Y, COL_W, 115, C_PANEL, C_ORANGE, 1);
   DrawRect("P4_HDR", COL2_X+2, ROW_Y+2, COL_W-4, 24, C_HEADER, clrNONE, 0);
   DrawLabel("P4H", COL2_X+10, ROW_Y+7, "🌐 MARKET REGIME", C_GOLD, 10, "Arial Black");
   
   int P4Y = ROW_Y+32;
   DrawLabel("L_REG", COL2_X+12, P4Y,      "Status:",      C_MUTED, 9, "Arial");
   DrawLabel("V_REG", COL2_X+150, P4Y,     "DETECTING",    C_GOLD, 10, "Arial Black");
   
   DrawLabel("L_TRQ", COL2_X+12, P4Y+24,   "Trend Quality:", C_MUTED, 9, "Arial");
   DrawLabel("V_TRQ", COL2_X+150, P4Y+24,  "0%",           C_WHITE, 10, "Arial Bold");
   DrawRect("BAR_TRQ_BG", COL2_X+12, P4Y+44, 296, 8, C'20,25,35', C_MUTED, 1);
   DrawRect("BAR_TRQ", COL2_X+13, P4Y+45, 1, 6, C_GREEN, clrNONE, 0); // Progress bar
   
   DrawLabel("L_VOL", COL2_X+12, P4Y+58,   "Volatility:",  C_MUTED, 9, "Arial");
   DrawLabel("V_VOL", COL2_X+150, P4Y+58,  "NORMAL",       C_GREEN, 9, "Arial Bold");

   // Panel 5: Signal Quality
   ROW_Y += 123;
   DrawRect("P5", COL2_X, ROW_Y, COL_W, 140, C_PANEL, C_CYAN, 1);
   DrawRect("P5_HDR", COL2_X+2, ROW_Y+2, COL_W-4, 24, C_HEADER, clrNONE, 0);
   DrawLabel("P5H", COL2_X+10, ROW_Y+7, "📡 SIGNAL ANALYSIS", C_GOLD, 10, "Arial Black");
   
   int P5Y = ROW_Y+32;
   DrawLabel("L_QUA", COL2_X+12, P5Y,      "Trade Quality:", C_MUTED, 9, "Arial");
   DrawLabel("V_QUA", COL2_X+180, P5Y,     "0%",           C_WHITE, 10, "Arial Bold");
   DrawRect("BAR_QUA_BG", COL2_X+12, P5Y+20, 296, 8, C'20,25,35', C_MUTED, 1);
   DrawRect("BAR_QUA", COL2_X+13, P5Y+21, 1, 6, C_BLUE, clrNONE, 0); // Progress bar
   
   DrawLabel("L_MTF", COL2_X+12, P5Y+36,   "MTF Align:",   C_MUTED, 9, "Arial");
   DrawLabel("V_MTF", COL2_X+180, P5Y+36,  "●",            C_GOLD, 11, "Arial Black");
   
   DrawLabel("L_RSI", COL2_X+12, P5Y+58,   "RSI:",         C_MUTED, 9, "Arial");
   DrawLabel("V_RSI", COL2_X+180, P5Y+58,  "50.0",         C_WHITE, 9, "Arial Bold");
   
   DrawLabel("L_ADX", COL2_X+12, P5Y+80,   "ADX:",         C_MUTED, 9, "Arial");
   DrawLabel("V_ADX", COL2_X+180, P5Y+80,  "0.0",          C_WHITE, 9, "Arial Bold");
   
   DrawLabel("L_ATR", COL2_X+12, P5Y+102,  "ATR:",         C_MUTED, 9, "Arial");
   DrawLabel("V_ATR", COL2_X+180, P5Y+102, "0.00",         C_WHITE, 9, "Arial Bold");

   // Panel 6: Engine Status
   ROW_Y += 148;
   DrawRect("P6", COL2_X, ROW_Y, COL_W, 90, C_PANEL, C_RED, 1);
   DrawRect("P6_HDR", COL2_X+2, ROW_Y+2, COL_W-4, 24, C_HEADER, clrNONE, 0);
   DrawLabel("P6H", COL2_X+10, ROW_Y+7, "🔥 ENGINE STATUS", C_GOLD, 10, "Arial Black");
   
   int P6Y = ROW_Y+32;
   DrawLabel("L_ST",  COL2_X+12, P6Y,      "Mode:",        C_MUTED, 9, "Arial");
   DrawLabel("V_ST",  COL2_X+80, P6Y,      "INITIALIZING", C_BLUE, 10, "Arial Black");
   
   DrawLabel("L_SES", COL2_X+12, P6Y+26,   "Session:",     C_MUTED, 9, "Arial");
   DrawLabel("V_SES", COL2_X+80, P6Y+26,   "CHECKING",     C_GOLD, 9, "Arial Bold");

   // Footer
   DrawRect("FOOTER", X+3, Y+H-26, W-6, 23, C_HEADER, clrNONE, 0);
   DrawLabel("F1", X+12, Y+H-19, "Advanced Post-Trade Analysis • Multi-Timeframe • Regime Detection", C_MUTED, 7, "Arial");
   DrawLabel("F2", X+W-115, Y+H-19, "PRO v6.00", C_CYAN, 8, "Arial Black");

   ChartRedraw(0);
}

//+------------------------------------------------------------------+
//| UPDATE DASHBOARD - ENHANCED                                      |
//+------------------------------------------------------------------+
void UpdateDashboard()
{
   // Status bar pulse
   SetLabel("SB_PULSE", g_HeartbeatStr, C_BLUE);
   SetLabel("SB_VALUE", g_StatusText, g_StatusColor);

   // Account Financials
   double bal = AccountInfoDouble(ACCOUNT_BALANCE);
   double eq  = AccountInfoDouble(ACCOUNT_EQUITY);
   double fpl = GetFloatingPnL();

   SetLabel("V_BAL", "$" + DoubleToString(bal, 2));
   SetLabel("V_EQ",  "$" + DoubleToString(eq, 2));

   color cDp = (g_DailyProfit >= 0) ? C_GREEN : C_RED;
   SetLabel("V_DP", (g_DailyProfit >= 0 ? "+$" : "-$") + DoubleToString(MathAbs(g_DailyProfit), 2), cDp);

   color cFp = (fpl >= 0) ? C_GREEN : C_RED;
   SetLabel("V_FP", (fpl >= 0 ? "+$" : "-$") + DoubleToString(MathAbs(fpl), 2), cFp);

   color cPF = (g_ProfitFactor >= 1.5) ? C_GREEN : (g_ProfitFactor >= 1.0 ? C_GOLD : C_RED);
   SetLabel("V_PF", DoubleToString(g_ProfitFactor, 2), cPF);

   // Performance
   SetLabel("V_TR", IntegerToString(g_DailyTrades) + " / " + IntegerToString(InpMaxDailyTrades));

   int tot = g_DailyWins + g_DailyLosses;
   double wr = (tot > 0) ? ((double)g_DailyWins / tot) * 100.0 : 0.0;
   color cWR = (wr >= 60) ? C_GREEN : (wr >= 40 ? C_GOLD : C_RED);
   SetLabel("V_WR", DoubleToString(wr, 0) + "%", cWR);

   SetLabel("V_AVG", "$" + DoubleToString(g_AvgWinSize, 0) + "/$" + DoubleToString(g_AvgLossSize, 0));

   // Streak indicator
   if(g_ConsecWins > 1)
      SetLabel("V_STK", "🔥 WIN ×" + IntegerToString(g_ConsecWins), C_GREEN);
   else if(g_ConsecLosses > 1)
      SetLabel("V_STK", "❄️ LOSS ×" + IntegerToString(g_ConsecLosses), C_RED);
   else
      SetLabel("V_STK", "—", C_MUTED);

   // Execution
   double atrLive = GetATR();
   double point   = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   int    slPts   = (int)MathRound((atrLive * InpSLMultiplier) / point);
   slPts = MathMax(InpMinSLPoints, MathMin(InpMaxSLPoints, slPts));
   int tp2Pts = (int)MathRound((atrLive * InpTP2Multiplier) / point);
   
   double nextLot = CalculateLotSize(slPts, g_TradeQualityScore);
   SetLabel("V_LOT", DoubleToString(nextLot, 2));
   SetLabel("V_SLT", IntegerToString(slPts) + "/" + IntegerToString(tp2Pts) + " pts");

   int sp = (int)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   color cSp = IsSpreadOk() ? C_GREEN : C_RED;
   SetLabel("V_SPR", IntegerToString(sp) + " pts", cSp);

   // Market Regime
   string regTxt = EnumToString(g_CurrentRegime);
   StringReplace(regTxt, "REGIME_", "");
   StringReplace(regTxt, "_", " ");
   color regCol = (g_CurrentRegime == REGIME_TRENDING_STRONG) ? C_GREEN :
                  (g_CurrentRegime == REGIME_TRENDING_WEAK) ? C_GOLD : 
                  (g_CurrentRegime == REGIME_RANGING) ? C_ORANGE : C_RED;
   SetLabel("V_REG", regTxt, regCol);

   // Trend Quality with progress bar
   color tqCol = (g_CurrentTrendQuality >= 70) ? C_GREEN : 
                 (g_CurrentTrendQuality >= 50) ? C_GOLD : C_RED;
   SetLabel("V_TRQ", DoubleToString(g_CurrentTrendQuality, 0) + "%", tqCol);
   
   int COL2_X = InpDashX + 348;
   int P4Y_BASE = InpDashY + 80 + 35 + 32;
   int barWidth = (int)((g_CurrentTrendQuality / 100.0) * 294);
   DrawRect("BAR_TRQ", COL2_X+13, P4Y_BASE+45, barWidth, 6, tqCol, clrNONE, 0);

   // Volatility
   double volScore = AnalyzeRecentVolatility();
   string volTxt = (volScore > 0.8) ? "OPTIMAL" : (volScore > 0.5) ? "NORMAL" : "EXTREME";
   color volCol = (volScore > 0.8) ? C_GREEN : (volScore > 0.5) ? C_GOLD : C_RED;
   SetLabel("V_VOL", volTxt, volCol);

   // Signal Quality with progress bar
   color qCol = (g_TradeQualityScore >= 70) ? C_GREEN :
                (g_TradeQualityScore >= 50) ? C_GOLD : C_RED;
   SetLabel("V_QUA", DoubleToString(g_TradeQualityScore, 0) + "%", qCol);
   
   int P5Y_BASE = InpDashY + 80 + 35 + 123 + 32;
   int barWidthQ = (int)((g_TradeQualityScore / 100.0) * 294);
   DrawRect("BAR_QUA", COL2_X+13, P5Y_BASE+21, barWidthQ, 6, qCol, clrNONE, 0);

   // MTF Alignment
   ENUM_SIGNAL testSig = EvaluateConfluence();
   bool mtfOK = CheckMultiTimeframeAlignment(testSig);
   SetLabel("V_MTF", mtfOK ? "● ✓" : "● ✗", mtfOK ? C_GREEN : C_RED);

   // Indicators
   double rsi[1], adx[1];
   CopyBuffer(g_hRSI, 0, 0, 1, rsi);
   CopyBuffer(g_hADX, 0, 0, 1, adx);

   color cRSI = (rsi[0] > InpRSIOverbought || rsi[0] < InpRSIOversold) ? C_RED : C_WHITE;
   SetLabel("V_RSI", DoubleToString(rsi[0], 1), cRSI);

   color cADX = (adx[0] >= InpADXMinStrength) ? C_GREEN : C_GOLD;
   SetLabel("V_ADX", DoubleToString(adx[0], 1), cADX);

   SetLabel("V_ATR", DoubleToString(atrLive, 2));

   // Engine Status
   SetLabel("V_ST", g_StatusText, g_StatusColor);
   
   bool inSess = IsInSession();
   string sessTxt = inSess ? "ACTIVE GMT" + IntegerToString(InpSessionStartGMT) + "-" + IntegerToString(InpSessionEndGMT) : "CLOSED";
   SetLabel("V_SES", sessTxt, inSess ? C_GREEN : C_RED);

   ChartRedraw(0);
}

void PurgeDashboard()
{
   ObjectsDeleteAll(0, DASH_PREFIX);
   ChartRedraw(0);
}

void DrawRect(string id, int x, int y, int w, int h, color bg, color border, int bw)
{
   string n = DASH_PREFIX + id;
   if(ObjectFind(0, n) < 0) ObjectCreate(0, n, OBJ_RECTANGLE_LABEL, 0, 0, 0);
   ObjectSetInteger(0, n, OBJPROP_CORNER,    CORNER_LEFT_UPPER);
   ObjectSetInteger(0, n, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, n, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, n, OBJPROP_XSIZE,     w);
   ObjectSetInteger(0, n, OBJPROP_YSIZE,     h);
   ObjectSetInteger(0, n, OBJPROP_BGCOLOR,   bg);
   if(border != clrNONE)
   {
      ObjectSetInteger(0, n, OBJPROP_BORDER_TYPE, BORDER_FLAT);
      ObjectSetInteger(0, n, OBJPROP_COLOR,        border);
      ObjectSetInteger(0, n, OBJPROP_WIDTH,        bw);
   }
   else ObjectSetInteger(0, n, OBJPROP_BORDER_TYPE, BORDER_RAISED);
   ObjectSetInteger(0, n, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, n, OBJPROP_HIDDEN,     true);
   ObjectSetInteger(0, n, OBJPROP_ZORDER,     0);
}

void DrawLabel(string id, int x, int y, string txt, color clr, int sz, string fnt)
{
   string n = DASH_PREFIX + id;
   if(ObjectFind(0, n) < 0) ObjectCreate(0, n, OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, n, OBJPROP_CORNER,    CORNER_LEFT_UPPER);
   ObjectSetInteger(0, n, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, n, OBJPROP_YDISTANCE, y);
   ObjectSetString( 0, n, OBJPROP_TEXT,      txt);
   ObjectSetInteger(0, n, OBJPROP_COLOR,     clr);
   ObjectSetInteger(0, n, OBJPROP_FONTSIZE,  sz);
   ObjectSetString( 0, n, OBJPROP_FONT,      fnt);
   ObjectSetInteger(0, n, OBJPROP_SELECTABLE,false);
   ObjectSetInteger(0, n, OBJPROP_HIDDEN,    true);
   ObjectSetInteger(0, n, OBJPROP_ZORDER,    1);
}

void SetLabel(string id, string txt, color clr = clrNONE)
{
   string n = DASH_PREFIX + id;
   if(ObjectFind(0, n) >= 0)
   {
      ObjectSetString(0, n, OBJPROP_TEXT, txt);
      if(clr != clrNONE) ObjectSetInteger(0, n, OBJPROP_COLOR, clr);
   }
}