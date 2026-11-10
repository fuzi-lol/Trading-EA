//+------------------------------------------------------------------+
//|                                    THEE EliteScalper v6.0.mq5    |
//|                                  Copyright 2026, FXBotHub Systems|
//|                                             https://fxbothub.com |
//+------------------------------------------------------------------+
#property copyright   "Copyright 2026, THEE EliteScalper Systems"
#property version     "6.00"
#property description "GOLD Institutional Scalper – Advanced Smart Money Indicators"
#property strict

#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>

#define DASH_PREFIX  "FXBH_V6_"
#define EA_VERSION   "v6.00"
#define MAX_HISTORY_RECORDS 100

//+------------------------------------------------------------------+
//| ENUMERATIONS                                                     |
//+------------------------------------------------------------------+
enum ENUM_MARKET_REGIME
{
   REGIME_UNKNOWN,
   REGIME_STRONG_TREND,
   REGIME_WEAK_TREND,
   REGIME_RANGING,
   REGIME_HIGH_VOLATILITY,
   REGIME_LOW_VOLATILITY,
   REGIME_ACCUMULATION,
   REGIME_DISTRIBUTION
};

enum ENUM_TREND_DIRECTION
{
   TREND_NONE,
   TREND_UP,
   TREND_DOWN,
   TREND_SIDEWAYS
};

enum ENUM_ENGINE_STATE
{
   STATE_SCANNING,
   STATE_ANALYZING,
   STATE_COOLDOWN,
   STATE_DAILY_LIMIT,
   STATE_NEWS_PAUSE,
   STATE_MARKET_UNFAVORABLE
};

enum ENUM_SIGNAL
{
   SIGNAL_BUY  =  1,
   SIGNAL_SELL = -1,
   SIGNAL_NONE =  0
};

//+------------------------------------------------------------------+
//| STRUCTURES                                                       |
//+------------------------------------------------------------------+
struct TradeRecord
{
   datetime          closeTime;
   int               signal;
   double            profit;
   double            rsi;
   double            adx;
   double            atr;
   double            bbWidth;
   int               regime;
   int               mtfTrend;
   int               entryHour;
   double            spreadAtEntry;
   double            qualityScore;
};

struct MarketSnapshot
{
   int               currentRegime;
   int               m1Trend;
   int               m5Trend;
   int               m15Trend;
   double            trendStrength;
   double            volatilityIndex;
   double            volumeProfile;
   double            orderFlow;
   double            smartMoneyIndex;
   bool              trendAlignment;
   datetime          timestamp;
};

//+------------------------------------------------------------------+
//| INPUT PARAMETERS                                                 |
//+------------------------------------------------------------------+
input group "=== CORE IDENTITY ==="
input ulong   InpMagicNumber       = 999555;
input string  InpTradeComment      = "EliteScalper_v6";

input group "=== RISK MANAGEMENT ==="
input double  InpRiskPercent       = 1.0;
input double  InpMaxDailyLossPct   = 5.0;
input double  InpMaxDailyProfitPct = 10.0;
input int     InpMaxDailyTrades    = 20;

input group "=== OPTIMIZED STOP LOSS & TAKE PROFIT ==="
input int     InpATRPeriod         = 14;
input double  InpSLMultiplier      = 0.8;
input double  InpTP1Multiplier     = 1.2;
input double  InpTP2Multiplier     = 2.0;
input double  InpTP3Multiplier     = 3.0;
input int     InpMinSLPoints       = 80;
input int     InpMaxSLPoints       = 250;

input group "=== INTELLIGENT PROFIT PROTECTION ==="
input bool    InpUseProfitProtection = true;
input double  InpProfitProtectionTrigger = 1.5;
input double  InpProfitProtectionTrail = 0.8;
input int     InpProfitLockMinPoints = 30;

input group "=== BREAKEVEN & TRAILING ==="
input int     InpBreakevenPoints   = 80;
input int     InpBreakevenBuffer   = 5;
input bool    InpUseTrailing       = true;
input int     InpTrailStartPoints  = 120;
input int     InpTrailStepPoints   = 30;

input group "=== ENHANCED PARTIAL CLOSE ==="
input bool    InpUsePartialClose   = true;
input double  InpPartialClose1Pct  = 30.0;
input double  InpPartialClose2Pct  = 40.0;

input group "=== ADVANCED SMART MONEY INDICATORS ==="
input int     InpSuperTrendPeriod  = 10;         // SuperTrend ATR Period
input double  InpSuperTrendMultiplier = 3.0;     // SuperTrend Multiplier
input int     InpVWAPPeriod        = 24;         // VWAP Session Bars
input int     InpRVIPeriod         = 14;         // RVI Period (Relative Vigor Index)
input int     InpStochPeriod       = 14;         // Stochastic K Period
input int     InpStochSlowing      = 3;          // Stochastic Slowing
input int     InpCCIPeriod         = 20;         // CCI Period (Commodity Channel Index)
input double  InpCCIOverbought     = 100.0;      // CCI Overbought
input double  InpCCIOversold       = -100.0;     // CCI Oversold
input int     InpMomentumPeriod    = 10;         // Momentum Period
input int     InpWilliamsPeriod    = 14;         // Williams %R Period

input group "=== MARKET STRUCTURE & ORDER FLOW ==="
input int     InpSwingPeriod       = 20;         // Swing High/Low Period
input int     InpVolumeThreshold   = 150;        // Volume Spike % Threshold
input bool    InpUseLiquidityZones = true;       // Detect Liquidity Zones
input int     InpLiquidityBars     = 50;         // Liquidity Zone Lookback

input group "=== SIGNAL QUALITY CONTROL ==="
input double  InpMinQualityScore   = 60.0;       // Min Quality Score (lowered from 65)
input int     InpMinConfluence     = 6;          // Min Indicators Aligned (out of 10)
input bool    InpUseMTFConfirmation = true;      // Multi-Timeframe Filter
input bool    InpAdaptiveThreshold = true;       // Adaptive Learning

input group "=== COOLDOWN & SPREAD ==="
input int     InpCooldownSeconds   = 30;         // Reduced cooldown
input int     InpSpreadMaxPoints   = 40;
input double  InpSpreadMultiplier  = 2.5;

input group "=== SESSION FILTER ==="
input bool    InpUseSessionFilter  = true;
input int     InpSessionStartGMT   = 7;
input int     InpSessionEndGMT     = 20;

input group "=== ADVANCED SETTINGS ==="
input int     InpMinWinRatePercent = 35;         // Lower threshold
input int     InpMarketAnalysisDepth = 20;
input bool    InpBlockRangeMarkets = false;      // Allow ranging (with caution)
input double  InpMinVolatilityIndex = 0.25;      // Lower minimum
input double  InpMaxVolatilityIndex = 3.5;       // Higher maximum
input bool    InpNewsPauseActive    = true;

input group "=== DASHBOARD ==="
input int     InpDashX            = 10;
input int     InpDashY            = 10;

//+------------------------------------------------------------------+
//| PREMIUM COLOUR PALETTE                                           |
//+------------------------------------------------------------------+
const color C_BG       = C'6,10,18';
const color C_PANEL    = C'12,18,28';
const color C_ACCENT   = C'16,25,40';
const color C_GOLD     = C'255,215,0';
const color C_PLATINUM = C'229,228,226';
const color C_DIAMOND  = C'185,242,255';
const color C_EMERALD  = C'80,200,120';
const color C_RUBY     = C'224,17,95';
const color C_SAPPHIRE = C'15,82,186';
const color C_BORDER   = C'100,150,255';
const color C_VIOLET   = C'148,0,211';
const color C_ORANGE   = C'255,140,0';

//+------------------------------------------------------------------+
//| GLOBAL OBJECTS                                                   |
//+------------------------------------------------------------------+
CTrade          g_Trade;
CPositionInfo   g_Pos;

// Advanced Indicator Handles
int g_hATR      = INVALID_HANDLE;
int g_hRVI      = INVALID_HANDLE;
int g_hStoch    = INVALID_HANDLE;
int g_hCCI      = INVALID_HANDLE;
int g_hMomentum = INVALID_HANDLE;
int g_hWilliams = INVALID_HANDLE;
int g_hADX      = INVALID_HANDLE;
int g_hMACD     = INVALID_HANDLE;
int g_hBB       = INVALID_HANDLE;
int g_hEMA_M5   = INVALID_HANDLE;
int g_hEMA_M15  = INVALID_HANDLE;
int g_hEMA_Fast = INVALID_HANDLE;
int g_hEMA_Slow = INVALID_HANDLE;

// State
ENUM_ENGINE_STATE g_State        = STATE_SCANNING;
datetime          g_StateTimer   = 0;
ENUM_SIGNAL  g_PendingSignal     = SIGNAL_NONE;
int          g_AnalysisTicks     = 0;
datetime     g_AnalysisStart     = 0;
bool         g_PartialClosed1    = false;
bool         g_PartialClosed2    = false;

// Daily Stats
datetime g_SessionDay       = 0;
int      g_DailyTrades      = 0;
double   g_DailyProfit      = 0.0;
int      g_DailyWins        = 0;
int      g_DailyLosses      = 0;
int      g_ConsecLosses     = 0;
int      g_ConsecWins       = 0;
double   g_SessionOpenBal   = 0.0;

// Spread
double g_AvgSpread          = 0.0;
int    g_SpreadSamples      = 0;

// History
TradeRecord g_TradeHistory[];
int         g_HistoryCount  = 0;

// Market Analysis
MarketSnapshot g_CurrentMarket;
double g_DynamicConfluenceThreshold = 6.0;
double g_CurrentQualityScore = 0.0;
double g_AvgWinningQuality = 0.0;
double g_AvgLosingQuality  = 0.0;
int    g_ProfitableTrades  = 0;
int    g_UnprofitableTrades = 0;

// Profit Protection
double g_PeakProfit        = 0.0;
bool   g_ProfitProtectionActive = false;

// VWAP Calculation
double g_VWAP = 0.0;
double g_SuperTrend = 0.0;
int    g_SuperTrendDirection = 0;

// Dashboard
string g_StatusText         = "INITIALIZING";
color  g_StatusColor        = C_GOLD;
string g_HeartbeatStr       = "■ ■ ■";
string g_RegimeText         = "DETECTING";
string g_MTFText            = "—|—|—";
string g_SignalQuality      = "0%";

//+------------------------------------------------------------------+
//| FORWARD DECLARATIONS                                             |
//+------------------------------------------------------------------+
bool         InitIndicators();
void         ReleaseIndicators();
void         InitTradeRecord(TradeRecord &rec);
void         InitMarketSnapshot(MarketSnapshot &snap);
void         SyncDailyStats();
ENUM_SIGNAL  EvaluateAdvancedConfluence(double &qualityScore);
double       CalculateVWAP();
void         CalculateSuperTrend(double &st, int &direction);
double       GetATR();
bool         CheckSmartMoneyDivergence(ENUM_SIGNAL sig);
bool         CheckLiquidityZones(ENUM_SIGNAL sig);
double       CalculateOrderFlow();
double       CalculateSmartMoneyIndex();
bool         CheckVolumeConfirmation(ENUM_SIGNAL sig);
ENUM_TREND_DIRECTION GetTrendDirection(ENUM_TIMEFRAMES tf);
bool         CheckMultiTimeframeTrend(ENUM_SIGNAL sig);
double       CalculateVolatilityIndex();
double       CalculateTradeQuality(ENUM_SIGNAL sig);
void         AnalyzeMarketConditions();
ENUM_MARKET_REGIME DetectMarketRegime();
double       GetVolumeProfile();
bool         IsMarketConditionFavorable();
void         PostTradeMarketReview();
void         RecordTradeOutcome(ulong ticket);
void         AnalyzeTradeHistory();
void         AdjustConfluenceThreshold();
string       RegimeToString(ENUM_MARKET_REGIME regime);
string       TrendToString(ENUM_TREND_DIRECTION trend);
double       CalculateLotSize(int slPoints);
double       GetRiskAdjustedPercent();
void         ExecuteEntry(ENUM_SIGNAL sig, double qualityScore);
void         ProcessAnalysisPhase();
void         ManageOpenTrade();
void         CheckBreakeven();
void         CheckTrailing();
void         CheckPartialClose();
void         CheckProfitProtection();
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
datetime     GetDayStart(datetime t);
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
      Print("[EliteScalper v6.0] WARNING: Optimised for GOLD. Current: ", _Symbol);

   g_Trade.SetExpertMagicNumber(InpMagicNumber);
   g_Trade.SetDeviationInPoints(20);
   g_Trade.SetTypeFilling(ORDER_FILLING_FOK);

   if(InpRiskPercent <= 0.0 || InpRiskPercent > 10.0)
   { Alert("Risk% must be 0.01–10."); return INIT_PARAMETERS_INCORRECT; }

   if(!InitIndicators()) return INIT_FAILED;

   ArrayResize(g_TradeHistory, MAX_HISTORY_RECORDS);
   for(int i = 0; i < MAX_HISTORY_RECORDS; i++)
      InitTradeRecord(g_TradeHistory[i]);
   
   InitMarketSnapshot(g_CurrentMarket);
   
   g_SessionDay     = GetDayStart(TimeCurrent());
   g_SessionOpenBal = AccountInfoDouble(ACCOUNT_BALANCE);
   SyncDailyStats();
   AnalyzeTradeHistory();

   g_State = STATE_SCANNING;
   EventSetTimer(1);
   RenderDashboard();

   Print("[EliteScalper v6.0] Initialized. Advanced Smart Money Indicators Active.");
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
   EventKillTimer();
   PurgeDashboard();
   ReleaseIndicators();
}

void OnTimer()
{
   static uint beat = 0; beat++;
   string p[3] = {"■ □ ■","□ ■ □","■ ■ □"};
   g_HeartbeatStr = p[beat % 3];
   SyncDailyStats();
   AnalyzeMarketConditions();
   UpdateDashboard();
}

void OnTick()
{
   UpdateSpreadAverage();

   if(!IsMarketOpen())
   { g_StatusText = "MARKET CLOSED"; g_StatusColor = C_RUBY; return; }

   if(InpNewsPauseActive || g_State == STATE_NEWS_PAUSE)
   { g_StatusText = "NEWS PAUSE"; g_StatusColor = C_GOLD; return; }

   if(IsPositionOpen())
   { ManageOpenTrade(); return; }
   
   g_PeakProfit = 0.0;
   g_ProfitProtectionActive = false;
   g_PartialClosed1 = false;
   g_PartialClosed2 = false;

   PostTradeMarketReview();

   if(IsDailyLossLimitHit())
   {
      g_State = STATE_DAILY_LIMIT;
      g_StatusText = "DAILY LOSS LIMIT";
      g_StatusColor = C_RUBY;
      return;
   }

   if(IsDailyProfitTargetHit())
   {
      g_State = STATE_DAILY_LIMIT;
      g_StatusText = "DAILY TARGET MET";
      g_StatusColor = C_EMERALD;
      return;
   }

   if(g_DailyTrades >= InpMaxDailyTrades)
   {
      g_StatusText = "MAX TRADES REACHED";
      g_StatusColor = C_GOLD;
      return;
   }

   if(!IsMarketConditionFavorable())
   {
      g_State = STATE_MARKET_UNFAVORABLE;
      g_StatusText = "UNFAVORABLE CONDITIONS";
      g_StatusColor = C_ORANGE;
      return;
   }
   else if(g_State == STATE_MARKET_UNFAVORABLE)
   {
      g_State = STATE_SCANNING;
   }

   if(InpUseSessionFilter && !IsInSession())
   {
      g_StatusText = "OUT OF SESSION";
      g_StatusColor = C_PLATINUM;
      return;
   }

   if(!IsSpreadOk())
   {
      int sp = (int)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
      g_StatusText = "SPREAD HIGH (" + IntegerToString(sp) + ")";
      g_StatusColor = C_RUBY;
      return;
   }

   if(g_State == STATE_COOLDOWN)
   {
      int left = (int)(g_StateTimer - TimeCurrent());
      if(left > 0)
      {
         g_StatusText = "COOLDOWN " + IntegerToString(left) + "s";
         g_StatusColor = C_SAPPHIRE;
         return;
      }
      g_State = STATE_SCANNING;
   }

   if(g_State == STATE_SCANNING)
   {
      double qualityScore = 0.0;
      ENUM_SIGNAL sig = EvaluateAdvancedConfluence(qualityScore);
      
      if(sig == SIGNAL_NONE || qualityScore < InpMinQualityScore)
      {
         g_StatusText = "SCANNING";
         g_StatusColor = C_EMERALD;
         g_CurrentQualityScore = qualityScore;
         return;
      }
      
      g_State          = STATE_ANALYZING;
      g_PendingSignal  = sig;
      g_AnalysisStart  = TimeCurrent();
      g_AnalysisTicks  = 0;
      g_CurrentQualityScore = qualityScore;
      g_StatusText     = "SIGNAL DETECTED";
      g_StatusColor = C_VIOLET;
      Print("[v6.0] Signal=", (sig==SIGNAL_BUY?"BUY":"SELL"), 
            " Quality=", DoubleToString(qualityScore, 1), "%");
   }
   else if(g_State == STATE_ANALYZING)
   {
      ProcessAnalysisPhase();
   }
}

//+------------------------------------------------------------------+
//| ADVANCED INDICATOR INITIALIZATION                                |
//+------------------------------------------------------------------+
bool InitIndicators()
{
   g_hATR      = iATR(_Symbol, PERIOD_M1, InpATRPeriod);
   g_hRVI      = iRVI(_Symbol, PERIOD_M1, InpRVIPeriod);
   g_hStoch    = iStochastic(_Symbol, PERIOD_M1, InpStochPeriod, 3, InpStochSlowing, MODE_SMA, STO_LOWHIGH);
   g_hCCI      = iCCI(_Symbol, PERIOD_M1, InpCCIPeriod, PRICE_TYPICAL);
   g_hMomentum = iMomentum(_Symbol, PERIOD_M1, InpMomentumPeriod, PRICE_CLOSE);
   g_hWilliams = iWPR(_Symbol, PERIOD_M1, InpWilliamsPeriod);
   g_hADX      = iADX(_Symbol, PERIOD_M1, 14);
   g_hMACD     = iMACD(_Symbol, PERIOD_M1, 12, 26, 9, PRICE_CLOSE);
   g_hBB       = iBands(_Symbol, PERIOD_M1, 20, 0, 2.0, PRICE_CLOSE);
   g_hEMA_M5   = iMA(_Symbol, PERIOD_M5, 50, 0, MODE_EMA, PRICE_CLOSE);
   g_hEMA_M15  = iMA(_Symbol, PERIOD_M15, 50, 0, MODE_EMA, PRICE_CLOSE);
   g_hEMA_Fast = iMA(_Symbol, PERIOD_M1, 9, 0, MODE_EMA, PRICE_CLOSE);
   g_hEMA_Slow = iMA(_Symbol, PERIOD_M1, 21, 0, MODE_EMA, PRICE_CLOSE);

   if(g_hATR==INVALID_HANDLE || g_hRVI==INVALID_HANDLE || g_hStoch==INVALID_HANDLE ||
      g_hCCI==INVALID_HANDLE || g_hMomentum==INVALID_HANDLE || g_hWilliams==INVALID_HANDLE ||
      g_hADX==INVALID_HANDLE || g_hMACD==INVALID_HANDLE || g_hBB==INVALID_HANDLE ||
      g_hEMA_M5==INVALID_HANDLE || g_hEMA_M15==INVALID_HANDLE || 
      g_hEMA_Fast==INVALID_HANDLE || g_hEMA_Slow==INVALID_HANDLE)
   {
      Print("[v6.0] FAILED: Indicator initialization error.");
      return false;
   }
   return true;
}

void ReleaseIndicators()
{
   int handles[] = {g_hATR, g_hRVI, g_hStoch, g_hCCI, g_hMomentum, g_hWilliams,
                    g_hADX, g_hMACD, g_hBB, g_hEMA_M5, g_hEMA_M15, g_hEMA_Fast, g_hEMA_Slow};
   for(int i = 0; i < ArraySize(handles); i++)
      if(handles[i] != INVALID_HANDLE) IndicatorRelease(handles[i]);
}

void InitTradeRecord(TradeRecord &rec)
{
   rec.closeTime = 0; rec.signal = 0; rec.profit = 0.0;
   rec.rsi = 0.0; rec.adx = 0.0; rec.atr = 0.0; rec.bbWidth = 0.0;
   rec.regime = 0; rec.mtfTrend = 0; rec.entryHour = 0;
   rec.spreadAtEntry = 0.0; rec.qualityScore = 0.0;
}

void InitMarketSnapshot(MarketSnapshot &snap)
{
   snap.currentRegime = (int)REGIME_UNKNOWN;
   snap.m1Trend = (int)TREND_NONE;
   snap.m5Trend = (int)TREND_NONE;
   snap.m15Trend = (int)TREND_NONE;
   snap.trendStrength = 0.0;
   snap.volatilityIndex = 0.0;
   snap.volumeProfile = 1.0;
   snap.orderFlow = 0.0;
   snap.smartMoneyIndex = 0.0;
   snap.trendAlignment = false;
   snap.timestamp = 0;
}

//+------------------------------------------------------------------+
//| ADVANCED CONFLUENCE ENGINE - 10 INDICATORS                       |
//+------------------------------------------------------------------+
ENUM_SIGNAL EvaluateAdvancedConfluence(double &qualityScore)
{
   int score = 0;
   int maxScore = 10;
   ENUM_SIGNAL primarySignal = SIGNAL_NONE;

   // 1. VWAP (Volume Weighted Average Price)
   g_VWAP = CalculateVWAP();
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(g_VWAP > 0)
   {
      if(bid > g_VWAP) { score++; primarySignal = SIGNAL_BUY; }
      else if(bid < g_VWAP) { score++; primarySignal = SIGNAL_SELL; }
   }

   // 2. SuperTrend
   CalculateSuperTrend(g_SuperTrend, g_SuperTrendDirection);
   if(g_SuperTrendDirection == 1 && primarySignal == SIGNAL_BUY) score++;
   else if(g_SuperTrendDirection == -1 && primarySignal == SIGNAL_SELL) score++;

   // 3. RVI (Relative Vigor Index) - Momentum confirmation
   double rvi_main[1], rvi_signal[1];
   if(CopyBuffer(g_hRVI, 0, 0, 1, rvi_main) > 0 && CopyBuffer(g_hRVI, 1, 0, 1, rvi_signal) > 0)
   {
      if(rvi_main[0] > rvi_signal[0] && primarySignal == SIGNAL_BUY) score++;
      else if(rvi_main[0] < rvi_signal[0] && primarySignal == SIGNAL_SELL) score++;
   }

   // 4. Stochastic
   double stoch_main[1], stoch_signal[1];
   if(CopyBuffer(g_hStoch, 0, 0, 1, stoch_main) > 0 && CopyBuffer(g_hStoch, 1, 0, 1, stoch_signal) > 0)
   {
      if(primarySignal == SIGNAL_BUY && stoch_main[0] < 80 && stoch_main[0] > stoch_signal[0]) score++;
      else if(primarySignal == SIGNAL_SELL && stoch_main[0] > 20 && stoch_main[0] < stoch_signal[0]) score++;
   }

   // 5. CCI (Commodity Channel Index)
   double cci[1];
   if(CopyBuffer(g_hCCI, 0, 0, 1, cci) > 0)
   {
      if(primarySignal == SIGNAL_BUY && cci[0] > 0 && cci[0] < InpCCIOverbought) score++;
      else if(primarySignal == SIGNAL_SELL && cci[0] < 0 && cci[0] > InpCCIOversold) score++;
   }

   // 6. Williams %R
   double williams[1];
   if(CopyBuffer(g_hWilliams, 0, 0, 1, williams) > 0)
   {
      if(primarySignal == SIGNAL_BUY && williams[0] > -80 && williams[0] < -20) score++;
      else if(primarySignal == SIGNAL_SELL && williams[0] < -20 && williams[0] > -80) score++;
   }

   // 7. Momentum
   double momentum[2];
   if(CopyBuffer(g_hMomentum, 0, 0, 2, momentum) > 0)
   {
      if(primarySignal == SIGNAL_BUY && momentum[0] > momentum[1]) score++;
      else if(primarySignal == SIGNAL_SELL && momentum[0] < momentum[1]) score++;
   }

   // 8. EMA Crossover (Fast vs Slow)
   double ema_fast[1], ema_slow[1];
   if(CopyBuffer(g_hEMA_Fast, 0, 0, 1, ema_fast) > 0 && CopyBuffer(g_hEMA_Slow, 0, 0, 1, ema_slow) > 0)
   {
      if(primarySignal == SIGNAL_BUY && ema_fast[0] > ema_slow[0]) score++;
      else if(primarySignal == SIGNAL_SELL && ema_fast[0] < ema_slow[0]) score++;
   }

   // 9. Volume Confirmation
   if(CheckVolumeConfirmation(primarySignal)) score++;

   // 10. Liquidity Zones
   if(InpUseLiquidityZones && CheckLiquidityZones(primarySignal)) score++;

   // Multi-Timeframe Filter (bonus point)
   if(InpUseMTFConfirmation && CheckMultiTimeframeTrend(primarySignal)) score++;

   // Calculate quality score
   qualityScore = CalculateTradeQuality(primarySignal);

   // Require minimum confluence
   if(score >= InpMinConfluence && primarySignal != SIGNAL_NONE)
      return primarySignal;

   return SIGNAL_NONE;
}

//+------------------------------------------------------------------+
//| VWAP CALCULATION                                                 |
//+------------------------------------------------------------------+
double CalculateVWAP()
{
   double sumPV = 0.0;
   double sumV = 0.0;
   
   for(int i = 0; i < InpVWAPPeriod; i++)
   {
      double high   = iHigh(_Symbol, PERIOD_M1, i);
      double low    = iLow(_Symbol, PERIOD_M1, i);
      double close  = iClose(_Symbol, PERIOD_M1, i);
      long   volume = iVolume(_Symbol, PERIOD_M1, i);
      
      double typical = (high + low + close) / 3.0;
      sumPV += typical * volume;
      sumV  += volume;
   }
   
   if(sumV > 0) return sumPV / sumV;
   return 0.0;
}

//+------------------------------------------------------------------+
//| SUPERTREND CALCULATION                                           |
//+------------------------------------------------------------------+
void CalculateSuperTrend(double &st, int &direction)
{
   double atr[1];
   if(CopyBuffer(g_hATR, 0, 0, 1, atr) <= 0) { st = 0.0; direction = 0; return; }
   
   double high = iHigh(_Symbol, PERIOD_M1, 0);
   double low  = iLow(_Symbol, PERIOD_M1, 0);
   double close = iClose(_Symbol, PERIOD_M1, 0);
   
   double hl2 = (high + low) / 2.0;
   double upperBand = hl2 + (InpSuperTrendMultiplier * atr[0]);
   double lowerBand = hl2 - (InpSuperTrendMultiplier * atr[0]);
   
   if(close > upperBand) { direction = 1; st = lowerBand; }
   else if(close < lowerBand) { direction = -1; st = upperBand; }
   else { direction = 0; st = hl2; }
}

//+------------------------------------------------------------------+
//| VOLUME CONFIRMATION                                              |
//+------------------------------------------------------------------+
bool CheckVolumeConfirmation(ENUM_SIGNAL sig)
{
   long currentVol = iVolume(_Symbol, PERIOD_M1, 0);
   long avgVol = 0;
   
   for(int i = 1; i <= 20; i++)
      avgVol += iVolume(_Symbol, PERIOD_M1, i);
   
   avgVol /= 20;
   
   // Volume spike confirmation
   return (currentVol > avgVol * (InpVolumeThreshold / 100.0));
}

//+------------------------------------------------------------------+
//| LIQUIDITY ZONES DETECTION                                        |
//+------------------------------------------------------------------+
bool CheckLiquidityZones(ENUM_SIGNAL sig)
{
   int highBar = iHighest(_Symbol, PERIOD_M1, MODE_HIGH, InpLiquidityBars, 1);
   int lowBar  = iLowest(_Symbol, PERIOD_M1, MODE_LOW, InpLiquidityBars, 1);
   
   if(highBar < 0 || lowBar < 0) return false;
   
   double liquidityHigh = iHigh(_Symbol, PERIOD_M1, highBar);
   double liquidityLow  = iLow(_Symbol, PERIOD_M1, lowBar);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   
   if(sig == SIGNAL_BUY)  return (bid > liquidityLow);
   if(sig == SIGNAL_SELL) return (bid < liquidityHigh);
   
   return false;
}

//+------------------------------------------------------------------+
//| ORDER FLOW CALCULATION                                           |
//+------------------------------------------------------------------+
double CalculateOrderFlow()
{
   double buyPressure = 0.0;
   double sellPressure = 0.0;
   
   for(int i = 0; i < 10; i++)
   {
      double open  = iOpen(_Symbol, PERIOD_M1, i);
      double close = iClose(_Symbol, PERIOD_M1, i);
      long   volume = iVolume(_Symbol, PERIOD_M1, i);
      
      if(close > open)
         buyPressure += volume;
      else
         sellPressure += volume;
   }
   
   double total = buyPressure + sellPressure;
   if(total > 0) return (buyPressure - sellPressure) / total;
   return 0.0;
}

//+------------------------------------------------------------------+
//| SMART MONEY INDEX                                                |
//+------------------------------------------------------------------+
double CalculateSmartMoneyIndex()
{
   // Simplified SMI calculation based on intraday momentum
   double openPrice = iOpen(_Symbol, PERIOD_M1, 0);
   double closePrice = iClose(_Symbol, PERIOD_M1, 0);
   double volumeNow = (double)iVolume(_Symbol, PERIOD_M1, 0);
   
   if(volumeNow > 0)
      return ((closePrice - openPrice) / openPrice) * volumeNow;
   
   return 0.0;
}

double GetATR()
{
   double atr[1];
   if(CopyBuffer(g_hATR, 0, 0, 1, atr) <= 0) return 0.0;
   return atr[0];
}

//+------------------------------------------------------------------+
//| TRADE QUALITY CALCULATION                                        |
//+------------------------------------------------------------------+
double CalculateTradeQuality(ENUM_SIGNAL sig)
{
   double quality = 0.0;
   double weights = 0.0;

   // 1. ADX Strength (25%)
   double adx[1];
   if(CopyBuffer(g_hADX, 0, 0, 1, adx) > 0)
   {
      quality += MathMin(25.0, (adx[0] / 40.0) * 25.0);
   }
   weights += 25.0;

   // 2. Regime Suitability (25%)
   ENUM_MARKET_REGIME regime = (ENUM_MARKET_REGIME)g_CurrentMarket.currentRegime;
   double regimeScore = 0.0;
   switch(regime)
   {
      case REGIME_STRONG_TREND: regimeScore = 25.0; break;
      case REGIME_WEAK_TREND:   regimeScore = 15.0; break;
      case REGIME_ACCUMULATION: regimeScore = 20.0; break;
      case REGIME_DISTRIBUTION: regimeScore = 20.0; break;
      case REGIME_RANGING:      regimeScore = 5.0;  break;
      default: regimeScore = 10.0;
   }
   quality += regimeScore;
   weights += 25.0;

   // 3. MTF Alignment (20%)
   if(g_CurrentMarket.trendAlignment)
      quality += 20.0;
   weights += 20.0;

   // 4. Order Flow (15%)
   double orderFlow = g_CurrentMarket.orderFlow;
   if(sig == SIGNAL_BUY && orderFlow > 0.2)
      quality += 15.0;
   else if(sig == SIGNAL_SELL && orderFlow < -0.2)
      quality += 15.0;
   else
      quality += MathAbs(orderFlow) * 50.0;
   weights += 15.0;

   // 5. Volatility (15%)
   double volIndex = g_CurrentMarket.volatilityIndex;
   if(volIndex >= InpMinVolatilityIndex && volIndex <= InpMaxVolatilityIndex)
      quality += 15.0;
   else
      quality += 7.5;
   weights += 15.0;

   return (quality / weights) * 100.0;
}

bool CheckMultiTimeframeTrend(ENUM_SIGNAL sig)
{
   ENUM_TREND_DIRECTION m1  = GetTrendDirection(PERIOD_M1);
   ENUM_TREND_DIRECTION m5  = GetTrendDirection(PERIOD_M5);
   ENUM_TREND_DIRECTION m15 = GetTrendDirection(PERIOD_M15);

   g_MTFText = TrendToString(m1) + "|" + TrendToString(m5) + "|" + TrendToString(m15);

   if(sig == SIGNAL_BUY)
      return (m1 == TREND_UP && (m5 == TREND_UP || m5 == TREND_SIDEWAYS));
   else if(sig == SIGNAL_SELL)
      return (m1 == TREND_DOWN && (m5 == TREND_DOWN || m5 == TREND_SIDEWAYS));
   
   return false;
}

ENUM_TREND_DIRECTION GetTrendDirection(ENUM_TIMEFRAMES tf)
{
   int handle = (tf == PERIOD_M5) ? g_hEMA_M5 : (tf == PERIOD_M15) ? g_hEMA_M15 : g_hEMA_Fast;
   
   double ema[3];
   if(CopyBuffer(handle, 0, 0, 3, ema) <= 0) return TREND_NONE;
   
   double price = (tf == PERIOD_M1) ? SymbolInfoDouble(_Symbol, SYMBOL_BID) : iClose(_Symbol, tf, 0);
   
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
   g_CurrentMarket.currentRegime = (int)DetectMarketRegime();
   g_CurrentMarket.m1Trend = (int)GetTrendDirection(PERIOD_M1);
   g_CurrentMarket.m5Trend = (int)GetTrendDirection(PERIOD_M5);
   g_CurrentMarket.m15Trend = (int)GetTrendDirection(PERIOD_M15);
   
   g_CurrentMarket.trendAlignment = (
      (g_CurrentMarket.m1Trend == g_CurrentMarket.m5Trend) ||
      (g_CurrentMarket.m1Trend != (int)TREND_SIDEWAYS && g_CurrentMarket.m5Trend != (int)TREND_SIDEWAYS)
   );
   
   g_CurrentMarket.volatilityIndex = CalculateVolatilityIndex();
   g_CurrentMarket.volumeProfile = GetVolumeProfile();
   g_CurrentMarket.orderFlow = CalculateOrderFlow();
   g_CurrentMarket.smartMoneyIndex = CalculateSmartMoneyIndex();
   
   double adx[1];
   if(CopyBuffer(g_hADX, 0, 0, 1, adx) > 0)
      g_CurrentMarket.trendStrength = adx[0];
   
   g_RegimeText = RegimeToString((ENUM_MARKET_REGIME)g_CurrentMarket.currentRegime);
}

ENUM_MARKET_REGIME DetectMarketRegime()
{
   double adx[1];
   if(CopyBuffer(g_hADX, 0, 0, 1, adx) <= 0) return REGIME_UNKNOWN;
   
   double volIndex = CalculateVolatilityIndex();
   double orderFlow = CalculateOrderFlow();
   
   // High volatility
   if(volIndex > InpMaxVolatilityIndex * 0.75)
      return REGIME_HIGH_VOLATILITY;
   
   // Low volatility
   if(volIndex < InpMinVolatilityIndex * 1.3)
      return REGIME_LOW_VOLATILITY;
   
   // Strong trend
   if(adx[0] > 30.0)
      return REGIME_STRONG_TREND;
   
   // Accumulation (buy pressure)
   if(orderFlow > 0.3 && adx[0] < 25.0)
      return REGIME_ACCUMULATION;
   
   // Distribution (sell pressure)
   if(orderFlow < -0.3 && adx[0] < 25.0)
      return REGIME_DISTRIBUTION;
   
   // Weak trend
   if(adx[0] > 18.0 && adx[0] <= 30.0)
      return REGIME_WEAK_TREND;
   
   // Ranging
   if(adx[0] <= 18.0)
      return REGIME_RANGING;
   
   return REGIME_UNKNOWN;
}

double CalculateVolatilityIndex()
{
   double atr[1];
   if(CopyBuffer(g_hATR, 0, 0, 1, atr) <= 0) return 0.0;
   
   double price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(price <= 0.0) return 0.0;
   
   return (atr[0] / price) * 100.0;
}

double GetVolumeProfile()
{
   long tickVol = iVolume(_Symbol, PERIOD_M1, 0);
   long avgVol = 0;
   
   for(int i = 1; i <= 20; i++)
      avgVol += iVolume(_Symbol, PERIOD_M1, i);
   
   if(avgVol == 0) return 1.0;
   return (double)tickVol / ((double)avgVol / 20.0);
}

bool IsMarketConditionFavorable()
{
   ENUM_MARKET_REGIME regime = (ENUM_MARKET_REGIME)g_CurrentMarket.currentRegime;
   
   // Allow most regimes except extreme volatility
   if(regime == REGIME_HIGH_VOLATILITY && g_CurrentMarket.volatilityIndex > InpMaxVolatilityIndex)
   {
      Print("[Market] Extreme volatility - pausing");
      return false;
   }
   
   // Check win rate only after meaningful sample
   int totalTrades = g_DailyWins + g_DailyLosses;
   if(totalTrades >= 8)
   {
      double winRate = ((double)g_DailyWins / totalTrades) * 100.0;
      if(winRate < InpMinWinRatePercent)
      {
         Print("[Market] Win rate low: ", DoubleToString(winRate, 1), "%");
         return false;
      }
   }
   
   return true;
}

void PostTradeMarketReview()
{
   static datetime lastReview = 0;
   datetime now = TimeCurrent();
   
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
         break;
      }
   }
}

void RecordTradeOutcome(ulong ticket)
{
   TradeRecord rec;
   rec.closeTime = (datetime)HistoryDealGetInteger(ticket, DEAL_TIME);
   rec.profit = HistoryDealGetDouble(ticket, DEAL_PROFIT) +
                HistoryDealGetDouble(ticket, DEAL_COMMISSION) +
                HistoryDealGetDouble(ticket, DEAL_SWAP);
   
   rec.regime = (int)g_CurrentMarket.currentRegime;
   rec.qualityScore = g_CurrentQualityScore;
   
   ENUM_DEAL_TYPE dealType = (ENUM_DEAL_TYPE)HistoryDealGetInteger(ticket, DEAL_TYPE);
   rec.signal = (dealType == DEAL_TYPE_BUY) ? -1 : 1;
   
   if(g_HistoryCount < MAX_HISTORY_RECORDS)
   {
      g_TradeHistory[g_HistoryCount] = rec;
      g_HistoryCount++;
   }
   else
   {
      for(int i = 0; i < MAX_HISTORY_RECORDS - 1; i++)
         g_TradeHistory[i] = g_TradeHistory[i + 1];
      g_TradeHistory[MAX_HISTORY_RECORDS - 1] = rec;
   }
}

void AnalyzeTradeHistory()
{
   if(g_HistoryCount < 5) return;
   
   int depth = MathMin(g_HistoryCount, InpMarketAnalysisDepth);
   double totalWinQual = 0.0, totalLossQual = 0.0;
   int wins = 0, losses = 0;
   
   for(int i = g_HistoryCount - depth; i < g_HistoryCount; i++)
   {
      if(g_TradeHistory[i].profit > 0)
      {
         totalWinQual += g_TradeHistory[i].qualityScore;
         wins++;
      }
      else
      {
         totalLossQual += g_TradeHistory[i].qualityScore;
         losses++;
      }
   }
   
   g_ProfitableTrades = wins;
   g_UnprofitableTrades = losses;
   if(wins > 0) g_AvgWinningQuality = totalWinQual / wins;
   if(losses > 0) g_AvgLosingQuality = totalLossQual / losses;
}

void AdjustConfluenceThreshold()
{
   if(!InpAdaptiveThreshold) return;
   if(g_ProfitableTrades + g_UnprofitableTrades < 10) return;
   
   double winRate = (double)g_ProfitableTrades / (g_ProfitableTrades + g_UnprofitableTrades);
   
   if(winRate < 0.45)
      g_DynamicConfluenceThreshold = MathMin(8.0, g_DynamicConfluenceThreshold + 0.5);
   else if(winRate > 0.65)
      g_DynamicConfluenceThreshold = MathMax(5.0, g_DynamicConfluenceThreshold - 0.25);
}

string RegimeToString(ENUM_MARKET_REGIME regime)
{
   switch(regime)
   {
      case REGIME_STRONG_TREND:    return "STRONG TREND";
      case REGIME_WEAK_TREND:      return "WEAK TREND";
      case REGIME_RANGING:         return "RANGE";
      case REGIME_HIGH_VOLATILITY: return "HIGH VOL";
      case REGIME_LOW_VOLATILITY:  return "LOW VOL";
      case REGIME_ACCUMULATION:    return "ACCUMULATION";
      case REGIME_DISTRIBUTION:    return "DISTRIBUTION";
      default:                     return "UNKNOWN";
   }
}

string TrendToString(ENUM_TREND_DIRECTION trend)
{
   switch(trend)
   {
      case TREND_UP:       return "▲";
      case TREND_DOWN:     return "▼";
      case TREND_SIDEWAYS: return "◆";
      default:             return "—";
   }
}

//+------------------------------------------------------------------+
//| EXECUTION & MANAGEMENT (Same as v5.2)                           |
//+------------------------------------------------------------------+
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
   if(g_ConsecLosses >= 3) pct = InpRiskPercent * 0.5;
   else if(g_ConsecWins >= 5) pct = MathMin(InpRiskPercent * 1.2, 2.0);
   return pct;
}

void ExecuteEntry(ENUM_SIGNAL sig, double qualityScore)
{
   if(!IsSpreadOk()) return;

   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   double atr = GetATR();
   double price = (sig == SIGNAL_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                       : SymbolInfoDouble(_Symbol, SYMBOL_BID);

   int slPoints = (int)MathRound((atr * InpSLMultiplier) / point);
   slPoints = MathMax(InpMinSLPoints, MathMin(InpMaxSLPoints, slPoints));
   int tp3Points = (int)MathRound((atr * InpTP3Multiplier) / point);

   double sl, tp;
   if(sig == SIGNAL_BUY)
   {
      sl = NormalizeDouble(price - slPoints * point, digits);
      tp = NormalizeDouble(price + tp3Points * point, digits);
   }
   else
   {
      sl = NormalizeDouble(price + slPoints * point, digits);
      tp = NormalizeDouble(price - tp3Points * point, digits);
   }

   double lot = CalculateLotSize(slPoints);
   
   Print("[Entry] ", (sig==SIGNAL_BUY?"BUY":"SELL"),
         " Q=", DoubleToString(qualityScore, 1), "%",
         " RR=1:", DoubleToString((double)tp3Points/slPoints, 2),
         " Lot=", lot);

   bool ok = (sig == SIGNAL_BUY) ? g_Trade.Buy(lot, _Symbol, price, sl, tp, InpTradeComment)
                                 : g_Trade.Sell(lot, _Symbol, price, sl, tp, InpTradeComment);
   if(ok)
   {
      g_DailyTrades++;
      g_PartialClosed1 = false;
      g_PartialClosed2 = false;
      g_PeakProfit = 0.0;
      g_StatusText = "TRADE ACTIVE";
      g_StatusColor = C_EMERALD;
   }
}

void ProcessAnalysisPhase()
{
   g_AnalysisTicks++;
   int elapsed = (int)(TimeCurrent() - g_AnalysisStart);

   g_StatusText = "ANALYSING " + IntegerToString(elapsed) + "s";
   g_StatusColor = C_VIOLET;

   if(elapsed > 90)
   {
      g_State = STATE_SCANNING;
      return;
   }

   double qualityScore = 0.0;
   ENUM_SIGNAL current = EvaluateAdvancedConfluence(qualityScore);
   
   if(current != g_PendingSignal || qualityScore < InpMinQualityScore)
   {
      g_State = STATE_SCANNING;
      return;
   }

   if(elapsed >= 5 && g_AnalysisTicks >= 20)
   {
      ExecuteEntry(g_PendingSignal, qualityScore);
      g_State = STATE_SCANNING;
   }
}

void ManageOpenTrade()
{
   EvaluateFloatingPnL();
   if(!IsPositionOpen()) return;
   CheckProfitProtection();
   CheckPartialClose();
   CheckBreakeven();
   if(InpUseTrailing) CheckTrailing();
   g_StatusText = "IN TRADE";
   g_StatusColor = C_EMERALD;
}

void CheckProfitProtection()
{
   if(!InpUseProfitProtection) return;
   
   double currentProfit = GetFloatingPnL();
   if(currentProfit > g_PeakProfit) g_PeakProfit = currentProfit;
   if(g_PeakProfit >= InpProfitProtectionTrigger) g_ProfitProtectionActive = true;
   
   if(g_ProfitProtectionActive)
   {
      double trailThreshold = g_PeakProfit * InpProfitProtectionTrail;
      if(currentProfit < trailThreshold && currentProfit > 0)
      {
         CloseAllPositions("Profit protection");
         return;
      }
   }
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
      int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
      bool isBuy = (g_Pos.PositionType() == POSITION_TYPE_BUY);

      double profitPts = isBuy ? (bid - open)/point : (open - SymbolInfoDouble(_Symbol, SYMBOL_ASK))/point;

      if(profitPts >= InpBreakevenPoints)
      {
         double beSL = isBuy ? NormalizeDouble(open + InpBreakevenBuffer*point, digits)
                              : NormalizeDouble(open - InpBreakevenBuffer*point, digits);
         bool needsMove = isBuy ? (sl < beSL) : (sl > beSL);
         if(needsMove) g_Trade.PositionModify(g_Pos.Ticket(), beSL, g_Pos.TakeProfit());
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
      if(improves) g_Trade.PositionModify(g_Pos.Ticket(), newSL, g_Pos.TakeProfit());
   }
}

void CheckPartialClose()
{
   if(!InpUsePartialClose) return;

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
      double tp2Pts = (atr * InpTP2Multiplier) / point;

      if(!g_PartialClosed1 && profitPts >= tp1Pts)
      {
         double closeLot = NormalizeDouble(g_Pos.Volume() * (InpPartialClose1Pct / 100.0), 2);
         if(closeLot >= SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN))
         {
            if(g_Trade.PositionClosePartial(g_Pos.Ticket(), closeLot))
               g_PartialClosed1 = true;
         }
      }
      
      if(g_PartialClosed1 && !g_PartialClosed2 && profitPts >= tp2Pts)
      {
         double closeLot = NormalizeDouble(g_Pos.Volume() * (InpPartialClose2Pct / 100.0), 2);
         if(closeLot >= SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN))
         {
            if(g_Trade.PositionClosePartial(g_Pos.Ticket(), closeLot))
               g_PartialClosed2 = true;
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
      CloseAllPositions("Daily target");
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
   Print("[Close] ", reason);
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
//| ULTRA-COMPACT PREMIUM DASHBOARD                                 |
//+------------------------------------------------------------------+
void RenderDashboard()
{
   int X = InpDashX, Y = InpDashY;
   int W = 320, H = 440;

   DrawRect("BG", X, Y, W, H, C_BG, C_BORDER, 2);
   DrawRect("HDR", X+2, Y+2, W-4, 48, C_ACCENT, C_GOLD, 1);
   
   DrawLabel("TITLE", X+10, Y+8, "⬥ ELITE SCALPER v6 ⬥", C_GOLD, 13, "Arial Black");
   DrawLabel("SUB", X+10, Y+28, "Smart Money Engine", C_PLATINUM, 7, "Arial");
   
   DrawRect("SYM_BOX", X+W-75, Y+8, 65, 32, C_PANEL, C_GOLD, 1);
   DrawLabel("SYM", X+W-68, Y+14, _Symbol, C_GOLD, 10, "Impact");

   int S1 = Y+54;
   DrawRect("S1", X+2, S1, W-4, 90, C_PANEL, C_BORDER, 1);
   DrawLabel("S1H", X+8, S1+4, "■ CAPITAL", C_EMERALD, 8, "Arial Black");
   
   DrawLabel("L_BAL", X+10, S1+22, "Balance", C_PLATINUM, 7, "Arial");
   DrawLabel("V_BAL", X+110, S1+22, "$0", C_GOLD, 8, "Arial Bold");
   
   DrawLabel("L_DP", X+10, S1+38, "Daily P&L", C_PLATINUM, 7, "Arial");
   DrawLabel("V_DP", X+110, S1+38, "$0", C_EMERALD, 8, "Arial Bold");
   
   DrawLabel("L_FP", X+10, S1+54, "Floating", C_PLATINUM, 7, "Arial");
   DrawLabel("V_FP", X+110, S1+54, "$0", C_DIAMOND, 8, "Arial Bold");
   
   DrawLabel("L_RR", X+10, S1+70, "RR Ratio", C_PLATINUM, 7, "Arial");
   DrawLabel("V_RR", X+110, S1+70, "1:3.75", C_EMERALD, 8, "Arial Bold");

   int S2 = S1+94;
   DrawRect("S2", X+2, S2, W-4, 140, C_PANEL, C_BORDER, 1);
   DrawLabel("S2H", X+8, S2+4, "■ MARKET INTEL", C_SAPPHIRE, 8, "Arial Black");
   
   DrawLabel("L_REG", X+10, S2+22, "Regime", C_PLATINUM, 7, "Arial");
   DrawLabel("V_REG", X+100, S2+22, "DETECTING", C_GOLD, 7, "Arial Bold");
   
   DrawLabel("L_MTF", X+10, S2+38, "MTF", C_PLATINUM, 7, "Arial");
   DrawLabel("V_MTF", X+100, S2+38, "—|—|—", C_PLATINUM, 7, "Courier New");
   
   DrawLabel("L_VWAP", X+10, S2+54, "VWAP", C_PLATINUM, 7, "Arial");
   DrawLabel("V_VWAP", X+100, S2+54, "—", C_DIAMOND, 7, "Courier New");
   
   DrawLabel("L_ST", X+10, S2+70, "SuperTrend", C_PLATINUM, 7, "Arial");
   DrawLabel("V_ST", X+100, S2+70, "—", C_VIOLET, 7, "Arial Bold");
   
   DrawLabel("L_QUAL", X+10, S2+86, "Signal Q", C_PLATINUM, 7, "Arial");
   DrawRect("QUAL_BG", X+100, S2+88, 80, 10, C_BG, C_BORDER, 1);
   DrawRect("QUAL_BAR", X+102, S2+90, 40, 6, C_GOLD, clrNONE, 0);
   DrawLabel("V_QUAL", X+190, S2+86, "0%", C_GOLD, 7, "Arial Bold");
   
   DrawLabel("L_OF", X+10, S2+104, "Order Flow", C_PLATINUM, 7, "Arial");
   DrawLabel("V_OF", X+100, S2+104, "—", C_EMERALD, 7, "Courier New");
   
   DrawLabel("L_VOL", X+10, S2+120, "Volume", C_PLATINUM, 7, "Arial");
   DrawLabel("V_VOL", X+100, S2+120, "—", C_ORANGE, 7, "Courier New");

   int S3 = S2+144;
   DrawRect("S3", X+2, S3, W-4, 110, C_PANEL, C_BORDER, 1);
   DrawLabel("S3H", X+8, S3+4, "■ EXECUTION", C_RUBY, 8, "Arial Black");
   
   DrawLabel("STATUS_DOT", X+10, S3+22, "●", C_EMERALD, 10, "Arial");
   DrawLabel("V_STATUS", X+24, S3+22, "INITIALIZING", C_EMERALD, 7, "Arial Bold");
   
   DrawLabel("L_TR", X+10, S3+40, "Trades", C_PLATINUM, 7, "Arial");
   DrawLabel("V_TR", X+100, S3+40, "0/20", C_DIAMOND, 7, "Courier New");
   
   DrawLabel("L_WR", X+10, S3+56, "Win Rate", C_PLATINUM, 7, "Arial");
   DrawLabel("V_WR", X+100, S3+56, "0%", C_EMERALD, 7, "Arial Bold");
   
   DrawLabel("L_PP", X+10, S3+72, "Protection", C_PLATINUM, 7, "Arial");
   DrawLabel("V_PP", X+100, S3+72, "INACTIVE", C_DIAMOND, 7, "Arial Bold");
   
   DrawLabel("L_HEART", X+10, S3+88, "System", C_PLATINUM, 7, "Arial");
   DrawLabel("V_HEART", X+100, S3+88, "■ ■ ■", C_SAPPHIRE, 7, "Courier New");

   DrawRect("FOOTER", X+2, Y+H-18, W-4, 16, C_ACCENT, clrNONE, 0);
   DrawLabel("F_L", X+8, Y+H-12, "© 2026 Elite Scalper", C_PLATINUM, 6, "Arial");
   DrawLabel("F_R", X+W-80, Y+H-12, "SMART MONEY v6", C_EMERALD, 6, "Arial Bold");

   ChartRedraw(0);
}

void UpdateDashboard()
{
   SetLabel("V_HEART", g_HeartbeatStr, C_SAPPHIRE);

   double bal = AccountInfoDouble(ACCOUNT_BALANCE);
   double fpl = GetFloatingPnL();

   SetLabel("V_BAL", "$" + DoubleToString(bal, 0), C_GOLD);
   
   color cDp = (g_DailyProfit >= 0) ? C_EMERALD : C_RUBY;
   SetLabel("V_DP", (g_DailyProfit >= 0 ? "+$" : "-$") + DoubleToString(MathAbs(g_DailyProfit), 2), cDp);

   color cFp = (fpl >= 0) ? C_EMERALD : C_RUBY;
   SetLabel("V_FP", (fpl >= 0 ? "+$" : "-$") + DoubleToString(MathAbs(fpl), 2), cFp);

   double atr = GetATR();
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   int slPts = (int)MathRound((atr * InpSLMultiplier) / point);
   slPts = MathMax(InpMinSLPoints, MathMin(InpMaxSLPoints, slPts));
   int tp3Pts = (int)MathRound((atr * InpTP3Multiplier) / point);
   double rr = (double)tp3Pts / slPts;
   SetLabel("V_RR", "1:" + DoubleToString(rr, 1), C_EMERALD);

   SetLabel("V_REG", g_RegimeText, C_GOLD);
   SetLabel("V_MTF", g_MTFText, g_CurrentMarket.trendAlignment ? C_EMERALD : C_PLATINUM);
   
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   string vwapStatus = (g_VWAP > 0) ? ((bid > g_VWAP) ? "▲ ABOVE" : "▼ BELOW") : "—";
   SetLabel("V_VWAP", vwapStatus, (bid > g_VWAP) ? C_EMERALD : C_RUBY);
   
   string stStatus = (g_SuperTrendDirection == 1) ? "▲ BULL" : (g_SuperTrendDirection == -1) ? "▼ BEAR" : "—";
   SetLabel("V_ST", stStatus, (g_SuperTrendDirection == 1) ? C_EMERALD : C_RUBY);
   
   int qualWidth = (int)(g_CurrentQualityScore / 100.0 * 76);
   qualWidth = MathMax(2, MathMin(76, qualWidth));
   color qualColor = (g_CurrentQualityScore >= 70) ? C_EMERALD : 
                     (g_CurrentQualityScore >= 50) ? C_GOLD : C_RUBY;
   string qualBar = DASH_PREFIX + "QUAL_BAR";
   if(ObjectFind(0, qualBar) >= 0)
   {
      ObjectSetInteger(0, qualBar, OBJPROP_XSIZE, qualWidth);
      ObjectSetInteger(0, qualBar, OBJPROP_BGCOLOR, qualColor);
   }
   SetLabel("V_QUAL", DoubleToString(g_CurrentQualityScore, 0) + "%", qualColor);
   
   SetLabel("V_OF", DoubleToString(g_CurrentMarket.orderFlow, 2), 
            (g_CurrentMarket.orderFlow > 0) ? C_EMERALD : C_RUBY);
   
   SetLabel("V_VOL", DoubleToString(g_CurrentMarket.volumeProfile, 1) + "x", 
            (g_CurrentMarket.volumeProfile > 1.2) ? C_EMERALD : C_PLATINUM);

   SetLabel("V_STATUS", g_StatusText, g_StatusColor);
   string statusDot = DASH_PREFIX + "STATUS_DOT";
   if(ObjectFind(0, statusDot) >= 0)
      ObjectSetInteger(0, statusDot, OBJPROP_COLOR, g_StatusColor);

   SetLabel("V_TR", IntegerToString(g_DailyTrades) + "/" + IntegerToString(InpMaxDailyTrades), C_DIAMOND);

   int tot = g_DailyWins + g_DailyLosses;
   double wr = (tot > 0) ? ((double)g_DailyWins / tot) * 100.0 : 0.0;
   SetLabel("V_WR", DoubleToString(wr, 0) + "%", 
            (wr >= 55) ? C_EMERALD : (wr >= 40) ? C_GOLD : C_RUBY);

   string ppStatus = g_ProfitProtectionActive ? "ACTIVE" : "INACTIVE";
   SetLabel("V_PP", ppStatus, g_ProfitProtectionActive ? C_EMERALD : C_DIAMOND);

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
   ObjectSetInteger(0, n, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, n, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, n, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, n, OBJPROP_XSIZE, w);
   ObjectSetInteger(0, n, OBJPROP_YSIZE, h);
   ObjectSetInteger(0, n, OBJPROP_BGCOLOR, bg);
   if(border != clrNONE)
   {
      ObjectSetInteger(0, n, OBJPROP_BORDER_TYPE, BORDER_FLAT);
      ObjectSetInteger(0, n, OBJPROP_COLOR, border);
      ObjectSetInteger(0, n, OBJPROP_WIDTH, bw);
   }
   ObjectSetInteger(0, n, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, n, OBJPROP_HIDDEN, true);
}

void DrawLabel(string id, int x, int y, string txt, color clr, int sz, string fnt)
{
   string n = DASH_PREFIX + id;
   if(ObjectFind(0, n) < 0) ObjectCreate(0, n, OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, n, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, n, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, n, OBJPROP_YDISTANCE, y);
   ObjectSetString(0, n, OBJPROP_TEXT, txt);
   ObjectSetInteger(0, n, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, n, OBJPROP_FONTSIZE, sz);
   ObjectSetString(0, n, OBJPROP_FONT, fnt);
   ObjectSetInteger(0, n, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, n, OBJPROP_HIDDEN, true);
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
//+------------------------------------------------------------------+