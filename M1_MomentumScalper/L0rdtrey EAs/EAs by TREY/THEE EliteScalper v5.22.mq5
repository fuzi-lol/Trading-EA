//+------------------------------------------------------------------+
//|                                    THEE EliteScalper v6.0 PRO.mq5|
//|                                  Copyright 2026, FXBotHub Systems|
//|                                             https://fxbothub.com |
//+------------------------------------------------------------------+
//  GOLD (XAUUSD) Advanced Institutional Scalping Engine
//  v6.00 PRO – Premium Edition with Luxury Dashboard
//+------------------------------------------------------------------+
#property copyright   "Copyright 2026, THEE EliteScalper Systems"
#property version     "6.00"
#property description "GOLD Advanced Scalping Engine – Premium Dashboard Edition"
#property strict

#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>

#define DASH_PREFIX  "FXBH_V6_"
#define EA_VERSION   "v6.00 PRO"

//+------------------------------------------------------------------+
//| ENGINE STATE MACHINE                                             |
//+------------------------------------------------------------------+
enum ENUM_ENGINE_STATE
{
   STATE_SCANNING,
   STATE_ANALYZING,
   STATE_POST_TRADE_REVIEW,
   STATE_COOLDOWN,
   STATE_DAILY_LIMIT,
   STATE_NEWS_PAUSE
};

enum ENUM_SIGNAL
{
   SIGNAL_BUY  =  1,
   SIGNAL_SELL = -1,
   SIGNAL_NONE =  0
};

enum ENUM_MARKET_REGIME
{
   REGIME_TRENDING_STRONG,
   REGIME_TRENDING_WEAK,
   REGIME_RANGING,
   REGIME_CHOPPY
};

//+------------------------------------------------------------------+
//| INPUT PARAMETERS                                                 |
//+------------------------------------------------------------------+
input group "=== CORE IDENTITY ==="
input ulong   InpMagicNumber       = 999555;
input string  InpTradeComment      = "EliteScalper_v6_PRO";

input group "=== RISK MANAGEMENT ==="
input double  InpRiskPercent       = 1.0;        // Risk % per trade
input double  InpMaxDailyLossPct   = 5.0;        // Daily loss limit %
input double  InpMaxDailyProfitPct = 10.0;       // Daily profit target %
input int     InpMaxDailyTrades    = 15;         // Max trades per day

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

input group "=== PRE-TRADE ANALYSIS ==="
input int     InpAnalysisMaxSec    = 120;
input int     InpAnalysisMinSec    = 10;
input int     InpAnalysisMinTicks  = 30;

input group "=== POST-TRADE ANALYSIS ==="
input bool    InpUsePostTradeAnalysis = true;
input int     InpPostTradeReviewSec   = 30;
input int     InpTrendLookbackBars    = 20;
input double  InpMinTrendQuality      = 60.0;
input bool    InpBlockAfterLoss       = true;

input group "=== MULTI-TIMEFRAME FILTER ==="
input bool    InpUseMTFFilter         = true;
input ENUM_TIMEFRAMES InpMTF_Higher1  = PERIOD_M5;
input ENUM_TIMEFRAMES InpMTF_Higher2  = PERIOD_M15;

input group "=== MARKET REGIME DETECTOR ==="
input bool    InpUseRegimeFilter      = true;
input bool    InpAllowTrendingStrong  = true;
input bool    InpAllowTrendingWeak    = true;
input bool    InpAllowRanging         = false;
input bool    InpAllowChoppy          = false;
input int     InpRegimeLookback       = 50;

input group "=== TRADE QUALITY SCORING ==="
input double  InpMinTradeQuality      = 65.0;
input bool    InpAdaptiveLotByQuality = true;

input group "=== SIGNAL CONFLUENCE ==="
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

input group "=== DASHBOARD ==="
input int     InpDashX            = 20;
input int     InpDashY            = 20;

//+------------------------------------------------------------------+
//| COLOR PALETTE - PREMIUM                                          |
//+------------------------------------------------------------------+
const color C_BG          = C'5,8,14';
const color C_PANEL       = C'10,16,28';
const color C_HEADER      = C'14,30,65';
const color C_BORDER      = C'0,85,175';
const color C_BLUE        = C'0,140,255';
const color C_GREEN       = C'0,210,110';
const color C_RED         = C'230,45,65';
const color C_GOLD        = C'255,190,30';
const color C_PURPLE      = C'175,0,250';
const color C_WHITE       = C'235,242,255';
const color C_MUTED       = C'125,140,168';
const color C_ORANGE      = C'255,140,0';
const color C_CYAN        = C'0,200,200';

//+------------------------------------------------------------------+
//| GLOBAL OBJECTS                                                   |
//+------------------------------------------------------------------+
CTrade          g_Trade;
CPositionInfo   g_Pos;

int g_hFastEMA  = INVALID_HANDLE;
int g_hSlowEMA  = INVALID_HANDLE;
int g_hTrendEMA = INVALID_HANDLE;
int g_hRSI      = INVALID_HANDLE;
int g_hATR      = INVALID_HANDLE;
int g_hADX      = INVALID_HANDLE;
int g_hMACD     = INVALID_HANDLE;
int g_hBB       = INVALID_HANDLE;
int g_hEMA_MTF1 = INVALID_HANDLE;
int g_hEMA_MTF2 = INVALID_HANDLE;

ENUM_ENGINE_STATE g_State        = STATE_SCANNING;
datetime          g_StateTimer   = 0;

ENUM_SIGNAL  g_PendingSignal     = SIGNAL_NONE;
int          g_AnalysisTicks     = 0;
datetime     g_AnalysisStart     = 0;
bool         g_PartialClosed     = false;

datetime     g_LastTradeCloseTime = 0;
double       g_LastTradePnL       = 0.0;
bool         g_LastTradeWasWin    = false;
datetime     g_PostTradeReviewEnd = 0;
double       g_CurrentTrendQuality = 0.0;
ENUM_MARKET_REGIME g_CurrentRegime = REGIME_RANGING;
double       g_TradeQualityScore   = 0.0;

datetime g_SessionDay       = 0;
int      g_DailyTrades      = 0;
double   g_DailyProfit      = 0.0;
int      g_DailyWins        = 0;
int      g_DailyLosses      = 0;
int      g_ConsecLosses     = 0;
int      g_ConsecWins       = 0;
double   g_SessionOpenBal   = 0.0;

double   g_AvgWinSize       = 0.0;
double   g_AvgLossSize      = 0.0;
double   g_LargestWin       = 0.0;
double   g_LargestLoss      = 0.0;
double   g_ProfitFactor     = 0.0;

double g_AvgSpread          = 0.0;
int    g_SpreadSamples      = 0;

string g_StatusText         = "BOOTING";
color  g_StatusColor        = C_GOLD;
string g_HeartbeatStr       = "0 0 0 0";

//+------------------------------------------------------------------+
//| FUNCTION DECLARATIONS                                            |
//+------------------------------------------------------------------+
bool         InitIndicators();
void         ReleaseIndicators();
void         SyncDailyStats();
ENUM_SIGNAL  EvaluateConfluence();
bool         CheckEMAStack(double &fast, double &slow, double &trend);
bool         CheckRSI(ENUM_SIGNAL sig, double &rsiVal);
bool         CheckADX(double &adxVal);
bool         CheckMACD(ENUM_SIGNAL sig);
bool         CheckBollingerBands(ENUM_SIGNAL sig, bool &inSqueeze);
bool         CheckMarketStructure(ENUM_SIGNAL sig);
double       GetATR();
double       CalculateLotSize(int slPoints, double qualityMultiplier = 1.0);
void         ExecuteEntry(ENUM_SIGNAL sig);
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
void         ProcessPostTradeReview();
double       AnalyzeTrendQuality(int lookback);
ENUM_MARKET_REGIME DetectMarketRegime(int lookback);
bool         CheckMultiTimeframeAlignment(ENUM_SIGNAL sig);
double       CalculateTradeQualityScore(ENUM_SIGNAL sig);
bool         DetectPriceActionPattern(ENUM_SIGNAL sig);
double       AnalyzeRecentVolatility();
void         UpdatePerformanceMetrics();
void         OnTradeClose(double pnl, bool wasWin);
void         DetectTradeClose();
void         RenderDashboard();
void         UpdateDashboard();
void         PurgeDashboard();
void         DrawRect(string id, int x, int y, int w, int h, color bg, color border, int bw);
void         DrawLabel(string id, int x, int y, string txt, color clr, int sz, string fnt);
void         SetLabel(string id, string txt, color clr = clrNONE);

//+------------------------------------------------------------------+
//| INITIALIZATION                                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   if(StringFind(_Symbol, "XAU") < 0 && StringFind(_Symbol, "GOLD") < 0)
      Print("[EliteScalper v6 PRO] WARNING: Optimised for GOLD. Current: ", _Symbol);

   g_Trade.SetExpertMagicNumber(InpMagicNumber);
   g_Trade.SetDeviationInPoints(20);
   g_Trade.SetTypeFilling(ORDER_FILLING_FOK);

   if(InpRiskPercent <= 0.0 || InpRiskPercent > 10.0)
   { Alert("Risk% must be 0.01–10."); return INIT_PARAMETERS_INCORRECT; }

   if(!InitIndicators()) return INIT_FAILED;

   g_SessionDay     = GetDayStart(TimeCurrent());
   g_SessionOpenBal = AccountInfoDouble(ACCOUNT_BALANCE);
   SyncDailyStats();

   g_State = STATE_SCANNING;
   EventSetTimer(1);
   RenderDashboard();

   Print("[EliteScalper v6 PRO] Premium Edition Initialized");
   Print("[EliteScalper v6 PRO] MTF: ", EnumToString(InpMTF_Higher1), " & ", EnumToString(InpMTF_Higher2));
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| DEINITIALIZATION                                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   EventKillTimer();
   PurgeDashboard();
   ReleaseIndicators();
   Print("[EliteScalper v6 PRO] Shutdown complete");
}

//+------------------------------------------------------------------+
//| TIMER EVENT                                                      |
//+------------------------------------------------------------------+
void OnTimer()
{
   static uint beat = 0; beat++;
   string p[4] = {"█ ▓ █ █  ▓ █ ▓ ▓","▓ █ ▓ ▓  █ ▓ █ █","█ █ ▓ █  ▓ ▓ █ ▓","▓ ▓ █ ▓  █ █ ▓ █"};
   g_HeartbeatStr = p[beat % 4];
   SyncDailyStats();
   UpdateDashboard();
}

//+------------------------------------------------------------------+
//| TICK EVENT - MAIN ENGINE                                         |
//+------------------------------------------------------------------+
void OnTick()
{
   UpdateSpreadAverage();
   
   g_CurrentTrendQuality = AnalyzeTrendQuality(InpTrendLookbackBars);
   g_CurrentRegime = DetectMarketRegime(InpRegimeLookback);

   if(!IsMarketOpen())
   { g_StatusText = "MARKET CLOSED"; g_StatusColor = C_RED; return; }

   if(InpNewsPauseActive || g_State == STATE_NEWS_PAUSE)
   { g_StatusText = "NEWS PAUSE ACTIVE"; g_StatusColor = C_GOLD; return; }

   if(IsPositionOpen())
   { ManageOpenTrade(); return; }

   DetectTradeClose();

   if(g_State == STATE_POST_TRADE_REVIEW)
   {
      ProcessPostTradeReview();
      return;
   }

   if(IsDailyLossLimitHit())
   {
      g_State = STATE_DAILY_LIMIT;
      g_StatusText = "DAILY LOSS LIMIT";
      g_StatusColor = C_RED;
      return;
   }

   if(IsDailyProfitTargetHit())
   {
      g_State = STATE_DAILY_LIMIT;
      g_StatusText = "DAILY TARGET MET";
      g_StatusColor = C_GREEN;
      return;
   }

   if(g_DailyTrades >= InpMaxDailyTrades)
   {
      g_StatusText = "MAX DAILY TRADES";
      g_StatusColor = C_GOLD;
      return;
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
      g_StatusText = "SPREAD HIGH (" + IntegerToString(sp) + ")";
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
      ENUM_SIGNAL sig = EvaluateConfluence();
      if(sig == SIGNAL_NONE)
      {
         g_StatusText = "SCANNING – NO SIGNAL";
         g_StatusColor = C_MUTED;
         return;
      }

      g_TradeQualityScore = CalculateTradeQualityScore(sig);
      
      if(g_TradeQualityScore < InpMinTradeQuality)
      {
         g_StatusText = "LOW QUALITY (" + DoubleToString(g_TradeQualityScore, 0) + "%)";
         g_StatusColor = C_ORANGE;
         return;
      }

      g_State          = STATE_ANALYZING;
      g_PendingSignal  = sig;
      g_AnalysisStart  = TimeCurrent();
      g_AnalysisTicks  = 0;
      g_StatusText     = "ANALYZING Q=" + DoubleToString(g_TradeQualityScore, 0) + "%";
      g_StatusColor    = C_PURPLE;
      Print("[Signal] ", (sig==SIGNAL_BUY?"BUY":"SELL"), " Quality=", g_TradeQualityScore, "%");
   }
   else if(g_State == STATE_ANALYZING)
   {
      ProcessAnalysisPhase();
   }
}

//+------------------------------------------------------------------+
//| INDICATOR INITIALIZATION                                         |
//+------------------------------------------------------------------+
bool InitIndicators()
{
   g_hFastEMA  = iMA(_Symbol, _Period, InpFastEMAPeriod,  0, MODE_EMA, PRICE_CLOSE);
   g_hSlowEMA  = iMA(_Symbol, _Period, InpSlowEMAPeriod,  0, MODE_EMA, PRICE_CLOSE);
   g_hTrendEMA = iMA(_Symbol, _Period, InpTrendEMAPeriod, 0, MODE_EMA, PRICE_CLOSE);
   g_hRSI      = iRSI(_Symbol, _Period, InpRSIPeriod, PRICE_CLOSE);
   g_hATR      = iATR(_Symbol, _Period, InpATRPeriod);
   g_hADX      = iADX(_Symbol, _Period, InpADXPeriod);
   g_hMACD     = iMACD(_Symbol, _Period, InpMACDFast, InpMACDSlow, InpMACDSignal, PRICE_CLOSE);
   g_hBB       = iBands(_Symbol, _Period, InpBBPeriod, 0, InpBBDeviation, PRICE_CLOSE);

   if(InpUseMTFFilter)
   {
      g_hEMA_MTF1 = iMA(_Symbol, InpMTF_Higher1, InpTrendEMAPeriod, 0, MODE_EMA, PRICE_CLOSE);
      g_hEMA_MTF2 = iMA(_Symbol, InpMTF_Higher2, InpTrendEMAPeriod, 0, MODE_EMA, PRICE_CLOSE);
   }

   if(g_hFastEMA==INVALID_HANDLE || g_hSlowEMA==INVALID_HANDLE || g_hTrendEMA==INVALID_HANDLE ||
      g_hRSI==INVALID_HANDLE || g_hATR==INVALID_HANDLE || g_hADX==INVALID_HANDLE ||
      g_hMACD==INVALID_HANDLE || g_hBB==INVALID_HANDLE)
   {
      Print("[ERROR] Invalid indicator handle");
      return false;
   }

   if(InpUseMTFFilter && (g_hEMA_MTF1==INVALID_HANDLE || g_hEMA_MTF2==INVALID_HANDLE))
   {
      Print("[ERROR] Invalid MTF indicator handle");
      return false;
   }

   return true;
}

void ReleaseIndicators()
{
   if(g_hFastEMA != INVALID_HANDLE)  IndicatorRelease(g_hFastEMA);
   if(g_hSlowEMA != INVALID_HANDLE)  IndicatorRelease(g_hSlowEMA);
   if(g_hTrendEMA != INVALID_HANDLE) IndicatorRelease(g_hTrendEMA);
   if(g_hRSI != INVALID_HANDLE)      IndicatorRelease(g_hRSI);
   if(g_hATR != INVALID_HANDLE)      IndicatorRelease(g_hATR);
   if(g_hADX != INVALID_HANDLE)      IndicatorRelease(g_hADX);
   if(g_hMACD != INVALID_HANDLE)     IndicatorRelease(g_hMACD);
   if(g_hBB != INVALID_HANDLE)       IndicatorRelease(g_hBB);
   if(g_hEMA_MTF1 != INVALID_HANDLE) IndicatorRelease(g_hEMA_MTF1);
   if(g_hEMA_MTF2 != INVALID_HANDLE) IndicatorRelease(g_hEMA_MTF2);
}

//+------------------------------------------------------------------+
//| POST-TRADE ANALYSIS                                              |
//+------------------------------------------------------------------+
void ProcessPostTradeReview()
{
   int remaining = (int)(g_PostTradeReviewEnd - TimeCurrent());
   
   if(remaining > 0)
   {
      g_StatusText = "POST-ANALYSIS (" + IntegerToString(remaining) + "s)";
      g_StatusColor = C_CYAN;
      
      static datetime lastLog = 0;
      if(TimeCurrent() - lastLog > 10)
      {
         Print("[Post-Analysis] TrendQ=", g_CurrentTrendQuality, "% Regime=", EnumToString(g_CurrentRegime));
         lastLog = TimeCurrent();
      }
   }
   else
   {
      Print("[Review Complete] Quality=", g_CurrentTrendQuality, "% Regime=", EnumToString(g_CurrentRegime));
      
      if(InpBlockAfterLoss && !g_LastTradeWasWin && g_CurrentTrendQuality < 70.0)
      {
         Print("[Caution] Extended cooldown after loss");
         g_StateTimer = TimeCurrent() + InpCooldownSeconds;
         g_State = STATE_COOLDOWN;
         return;
      }
      
      g_State = STATE_SCANNING;
      g_StatusText = "REVIEW COMPLETE";
      g_StatusColor = C_GREEN;
   }
}

double AnalyzeTrendQuality(int lookback)
{
   double score = 0.0;
   
   double fast[1], slow[1], trend[1];
   if(CopyBuffer(g_hFastEMA, 0, 0, 1, fast) > 0 &&
      CopyBuffer(g_hSlowEMA, 0, 0, 1, slow) > 0 &&
      CopyBuffer(g_hTrendEMA, 0, 0, 1, trend) > 0)
   {
      bool bullAlign = (fast[0] > slow[0] && slow[0] > trend[0]);
      bool bearAlign = (fast[0] < slow[0] && slow[0] < trend[0]);
      if(bullAlign || bearAlign)
      {
         double separation = MathAbs(fast[0] - trend[0]) / trend[0] * 10000;
         score += MathMin(30.0, separation * 3.0);
      }
   }
   
   double adx[1];
   if(CopyBuffer(g_hADX, 0, 0, 1, adx) > 0)
      score += MathMin(25.0, adx[0] * 0.625);
   
   MqlRates rates[];
   if(CopyRates(_Symbol, _Period, 0, lookback, rates) == lookback)
   {
      int bullBars = 0, bearBars = 0;
      for(int i = 1; i < lookback; i++)
      {
         if(rates[i].close > rates[i].open) bullBars++;
         else if(rates[i].close < rates[i].open) bearBars++;
      }
      double consistency = MathMax(bullBars, bearBars) / (double)lookback;
      score += consistency * 25.0;
   }
   
   double atr = GetATR();
   double price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(atr > 0 && price > 0)
   {
      double volatilityRatio = (atr / price) * 100.0;
      if(volatilityRatio > 0.05 && volatilityRatio < 0.3)
         score += 20.0;
      else if(volatilityRatio >= 0.3 && volatilityRatio < 0.5)
         score += 10.0;
   }
   
   return MathMin(100.0, score);
}

ENUM_MARKET_REGIME DetectMarketRegime(int lookback)
{
   MqlRates rates[];
   if(CopyRates(_Symbol, _Period, 0, lookback, rates) < lookback)
      return REGIME_CHOPPY;
   
   double highest = rates[0].high;
   double lowest  = rates[0].low;
   for(int i = 1; i < lookback; i++)
   {
      if(rates[i].high > highest) highest = rates[i].high;
      if(rates[i].low < lowest)   lowest  = rates[i].low;
   }
   
   double range = highest - lowest;
   double priceMove = MathAbs(rates[lookback-1].close - rates[0].close);
   double trendRatio = (range > 0) ? priceMove / range : 0;
   
   double adx[1];
   bool adxOk = (CopyBuffer(g_hADX, 0, 0, 1, adx) > 0);
   
   if(adxOk && adx[0] > 30.0 && trendRatio > 0.6)
      return REGIME_TRENDING_STRONG;
   else if(adxOk && adx[0] > 20.0 && trendRatio > 0.4)
      return REGIME_TRENDING_WEAK;
   else if(trendRatio < 0.3)
   {
      int reversals = 0;
      for(int i = 2; i < lookback; i++)
      {
         bool prevUp = (rates[i-1].close > rates[i-2].close);
         bool curUp  = (rates[i].close > rates[i-1].close);
         if(prevUp != curUp) reversals++;
      }
      double choppiness = reversals / (double)(lookback - 2);
      return (choppiness > 0.6) ? REGIME_CHOPPY : REGIME_RANGING;
   }
   
   return REGIME_RANGING;
}

bool CheckMultiTimeframeAlignment(ENUM_SIGNAL sig)
{
   if(!InpUseMTFFilter) return true;
   
   double currentPrice = (sig == SIGNAL_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) 
                                              : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   
   double mtf1[1];
   if(CopyBuffer(g_hEMA_MTF1, 0, 0, 1, mtf1) <= 0) return false;
   bool mtf1OK = (sig == SIGNAL_BUY) ? (currentPrice > mtf1[0]) : (currentPrice < mtf1[0]);
   
   double mtf2[1];
   if(CopyBuffer(g_hEMA_MTF2, 0, 0, 1, mtf2) <= 0) return false;
   bool mtf2OK = (sig == SIGNAL_BUY) ? (currentPrice > mtf2[0]) : (currentPrice < mtf2[0]);
   
   return (mtf1OK && mtf2OK);
}

double CalculateTradeQualityScore(ENUM_SIGNAL sig)
{
   double score = 0.0;
   
   score += g_CurrentTrendQuality * 0.25;
   
   if((g_CurrentRegime == REGIME_TRENDING_STRONG && InpAllowTrendingStrong) ||
      (g_CurrentRegime == REGIME_TRENDING_WEAK && InpAllowTrendingWeak))
      score += 20.0;
   else if((g_CurrentRegime == REGIME_RANGING && InpAllowRanging))
      score += 10.0;
   else if((g_CurrentRegime == REGIME_CHOPPY && InpAllowChoppy))
      score += 5.0;
   
   if(CheckMultiTimeframeAlignment(sig))
      score += 20.0;
   
   int confirmations = 0;
   double fast, slow, trend, rsi, adx;
   if(CheckEMAStack(fast, slow, trend)) confirmations++;
   if(CheckRSI(sig, rsi)) confirmations++;
   if(CheckADX(adx)) confirmations++;
   if(CheckMACD(sig)) confirmations++;
   bool squeeze; 
   if(CheckBollingerBands(sig, squeeze) && !squeeze) confirmations++;
   if(CheckMarketStructure(sig)) confirmations++;
   score += (confirmations / 6.0) * 15.0;
   
   if(DetectPriceActionPattern(sig))
      score += 10.0;
   
   double volScore = AnalyzeRecentVolatility();
   score += volScore * 10.0;
   
   return MathMin(100.0, MathMax(0.0, score));
}

bool DetectPriceActionPattern(ENUM_SIGNAL sig)
{
   MqlRates rates[];
   if(CopyRates(_Symbol, _Period, 0, 3, rates) < 3) return false;
   
   for(int i = 0; i < 2; i++)
   {
      double body = MathAbs(rates[i].close - rates[i].open);
      double range = rates[i].high - rates[i].low;
      if(range == 0) continue;
      
      double upperWick = rates[i].high - MathMax(rates[i].open, rates[i].close);
      double lowerWick = MathMin(rates[i].open, rates[i].close) - rates[i].low;
      
      if(sig == SIGNAL_BUY && lowerWick > body * 2.0 && upperWick < body)
         return true;
      
      if(sig == SIGNAL_SELL && upperWick > body * 2.0 && lowerWick < body)
         return true;
   }
   
   if(sig == SIGNAL_BUY && 
      rates[1].close > rates[1].open &&
      rates[0].close < rates[0].open &&
      rates[1].close > rates[0].open &&
      rates[1].open < rates[0].close)
      return true;
   
   if(sig == SIGNAL_SELL && 
      rates[1].close < rates[1].open &&
      rates[0].close > rates[0].open &&
      rates[1].close < rates[0].open &&
      rates[1].open > rates[0].close)
      return true;
   
   return false;
}

double AnalyzeRecentVolatility()
{
   double atr = GetATR();
   if(atr == 0) return 0.5;
   
   double atrHistory[];
   if(CopyBuffer(g_hATR, 0, 0, 20, atrHistory) < 20) return 0.5;
   
   double avgATR = 0;
   for(int i = 0; i < 20; i++) avgATR += atrHistory[i];
   avgATR /= 20.0;
   
   if(avgATR == 0) return 0.5;
   double ratio = atr / avgATR;
   
   if(ratio >= 0.9 && ratio <= 1.3) return 1.0;
   else if(ratio >= 0.7 && ratio < 0.9) return 0.7;
   else if(ratio > 1.3 && ratio <= 1.6) return 0.7;
   else return 0.3;
}

//+------------------------------------------------------------------+
//| CONFLUENCE SIGNAL ENGINE                                         |
//+------------------------------------------------------------------+
ENUM_SIGNAL EvaluateConfluence()
{
   if(InpUseRegimeFilter)
   {
      bool regimeOK = false;
      if(g_CurrentRegime == REGIME_TRENDING_STRONG && InpAllowTrendingStrong) regimeOK = true;
      if(g_CurrentRegime == REGIME_TRENDING_WEAK && InpAllowTrendingWeak) regimeOK = true;
      if(g_CurrentRegime == REGIME_RANGING && InpAllowRanging) regimeOK = true;
      if(g_CurrentRegime == REGIME_CHOPPY && InpAllowChoppy) regimeOK = true;
      
      if(!regimeOK) return SIGNAL_NONE;
   }
   
   double fastEMA, slowEMA, trendEMA, rsiVal, adxVal;
   bool   inSqueeze = false;

   if(!CheckEMAStack(fastEMA, slowEMA, trendEMA)) return SIGNAL_NONE;
   ENUM_SIGNAL emaSig = (fastEMA > slowEMA && slowEMA > trendEMA) ? SIGNAL_BUY : SIGNAL_SELL;

   int score = 2;

   if(CheckRSI(emaSig, rsiVal)) score++;
   if(CheckADX(adxVal)) score++;
   if(CheckMACD(emaSig)) score++;
   if(CheckBollingerBands(emaSig, inSqueeze))
      score++;
   else if(inSqueeze)
      return SIGNAL_NONE;
   if(CheckMarketStructure(emaSig)) score++;

   if(score >= 5) return emaSig;
   return SIGNAL_NONE;
}

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
   bool rising  = (hist[0] > hist[1]);
   if(sig == SIGNAL_BUY)  return (hist[0] > 0 && rising);
   if(sig == SIGNAL_SELL) return (hist[0] < 0 && !rising);
   return false;
}

bool CheckBollingerBands(ENUM_SIGNAL sig, bool &inSqueeze)
{
   double upper[1], lower[1], mid[1];
   if(CopyBuffer(g_hBB, 1, 0, 1, upper) <= 0) return false;
   if(CopyBuffer(g_hBB, 2, 0, 1, lower) <= 0) return false;
   if(CopyBuffer(g_hBB, 0, 0, 1, mid)   <= 0) return false;

   double width      = upper[0] - lower[0];
   double price      = SymbolInfoDouble(_Symbol, SYMBOL_BID);
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
   int lowBar  = iLowest(_Symbol,  _Period, MODE_LOW,  InpStructureBars, 1);
   if(highBar < 0 || lowBar < 0) return false;

   double swingHigh = iHigh(_Symbol, _Period, highBar);
   double swingLow  = iLow(_Symbol,  _Period, lowBar);
   double bid       = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask       = SymbolInfoDouble(_Symbol, SYMBOL_ASK);

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

//+------------------------------------------------------------------+
//| LOT SIZING                                                       |
//+------------------------------------------------------------------+
double CalculateLotSize(int slPoints, double qualityMultiplier = 1.0)
{
   double balance    = AccountInfoDouble(ACCOUNT_BALANCE);
   double riskPct    = GetRiskAdjustedPercent();
   
   if(InpAdaptiveLotByQuality && qualityMultiplier > 0)
      riskPct *= (qualityMultiplier / 100.0);
   
   double riskAmount = balance * (riskPct / 100.0);

   double tickVal  = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   double point    = SymbolInfoDouble(_Symbol, SYMBOL_POINT);

   double slCostPerLot = (slPoints * point / tickSize) * tickVal;
   if(slCostPerLot <= 0.0) return SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);

   double lot  = riskAmount / slCostPerLot;
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

//+------------------------------------------------------------------+
//| ANALYSIS PHASE                                                   |
//+------------------------------------------------------------------+
void ProcessAnalysisPhase()
{
   g_AnalysisTicks++;
   int elapsed = (int)(TimeCurrent() - g_AnalysisStart);

   g_StatusText  = "ANALYZING " + IntegerToString(elapsed) + "s";
   g_StatusColor = C_PURPLE;

   if(elapsed > InpAnalysisMaxSec)
   {
      Print("[Analysis] Timeout");
      g_State = STATE_SCANNING;
      return;
   }

   ENUM_SIGNAL current = EvaluateConfluence();
   if(current != g_PendingSignal)
   {
      Print("[Analysis] Signal reversed");
      g_State = STATE_SCANNING;
      return;
   }

   if(elapsed >= InpAnalysisMinSec && g_AnalysisTicks >= InpAnalysisMinTicks)
   {
      Print("[Analysis] Complete – Executing");
      ExecuteEntry(g_PendingSignal);
      g_State = STATE_SCANNING;
   }
}

//+------------------------------------------------------------------+
//| TRADE EXECUTION                                                  |
//+------------------------------------------------------------------+
void ExecuteEntry(ENUM_SIGNAL sig)
{
   if(!IsSpreadOk()) { Print("[Entry] Spread too wide"); return; }

   double point  = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   int    digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   double atr    = GetATR();
   double price  = (sig == SIGNAL_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                       : SymbolInfoDouble(_Symbol, SYMBOL_BID);

   int slPoints  = (int)MathRound((atr * InpSLMultiplier) / point);
   slPoints      = MathMax(InpMinSLPoints, MathMin(InpMaxSLPoints, slPoints));

   int tp2Points = (int)MathRound((atr * InpTP2Multiplier) / point);

   double sl, tp;
   if(sig == SIGNAL_BUY)
   {
      sl = NormalizeDouble(price - slPoints  * point, digits);
      tp = NormalizeDouble(price + tp2Points * point, digits);
   }
   else
   {
      sl = NormalizeDouble(price + slPoints  * point, digits);
      tp = NormalizeDouble(price - tp2Points * point, digits);
   }

   double lot = CalculateLotSize(slPoints, g_TradeQualityScore);

   Print("[ENTRY] ", (sig==SIGNAL_BUY?"BUY":"SELL"),
         " Q=", g_TradeQualityScore, "% Lot=", lot,
         " Price=", price, " SL=", sl, " TP=", tp);

   bool ok = (sig == SIGNAL_BUY) ? g_Trade.Buy(lot, _Symbol, price, sl, tp, InpTradeComment)
                                 : g_Trade.Sell(lot, _Symbol, price, sl, tp, InpTradeComment);
   if(ok)
   {
      g_DailyTrades++;
      g_PartialClosed = false;
      g_StatusText  = (sig==SIGNAL_BUY) ? "LONG ACTIVE" : "SHORT ACTIVE";
      g_StatusColor = C_GREEN;
   }
   else
   {
      Print("[ENTRY FAILED] ", g_Trade.ResultRetcode(), " ", g_Trade.ResultRetcodeDescription());
   }
}

//+------------------------------------------------------------------+
//| TRADE MANAGEMENT                                                 |
//+------------------------------------------------------------------+
void ManageOpenTrade()
{
   EvaluateFloatingPnL();
   if(!IsPositionOpen()) return;
   CheckPartialClose();
   CheckBreakeven();
   if(InpUseTrailing) CheckTrailing();

   double pnl = GetFloatingPnL();
   g_StatusText  = "IN TRADE | " + (pnl >= 0 ? "+$" : "-$") + DoubleToString(MathAbs(pnl), 2);
   g_StatusColor = (pnl >= 0) ? C_GREEN : C_RED;
}

void EvaluateFloatingPnL()
{
   if(!IsPositionOpen()) return;
   double pnl = GetFloatingPnL();

   double balance    = AccountInfoDouble(ACCOUNT_BALANCE);
   double dailyGoal  = balance * (InpMaxDailyProfitPct / 100.0);
   double remaining  = dailyGoal - g_DailyProfit;
   if(remaining > 0.0 && pnl >= remaining)
   {
      CloseAllPositions("Daily target via float");
      g_State = STATE_DAILY_LIMIT;
   }
}

void CheckBreakeven()
{
   for(int i = PositionsTotal()-1; i >= 0; i--)
   {
      if(!g_Pos.SelectByIndex(i)) continue;
      if(g_Pos.Magic() != InpMagicNumber || g_Pos.Symbol() != _Symbol) continue;

      double open   = g_Pos.PriceOpen();
      double sl     = g_Pos.StopLoss();
      double point  = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
      double bid    = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      double ask    = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      int    digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
      bool   isBuy  = (g_Pos.PositionType() == POSITION_TYPE_BUY);

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

      double open   = g_Pos.PriceOpen();
      double sl     = g_Pos.StopLoss();
      double point  = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
      double bid    = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      double ask    = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      int    digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
      bool   isBuy  = (g_Pos.PositionType() == POSITION_TYPE_BUY);

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

      double open   = g_Pos.PriceOpen();
      double point  = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
      double bid    = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      double ask    = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      bool   isBuy  = (g_Pos.PositionType() == POSITION_TYPE_BUY);

      double profitPts = isBuy ? (bid - open)/point : (open - ask)/point;
      double atr       = GetATR();
      double tp1Pts    = (atr * InpTP1Multiplier) / point;

      if(profitPts >= tp1Pts)
      {
         double closeLot = NormalizeDouble(g_Pos.Volume() * (InpPartialClosePct / 100.0),
                            (int)MathLog10(1.0/SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP)));
         double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
         if(closeLot >= minLot)
         {
            if(g_Trade.PositionClosePartial(g_Pos.Ticket(), closeLot))
            {
               g_PartialClosed = true;
               Print("[Partial Close] ", closeLot, " lots at TP1");
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//| TRADE CLOSE DETECTION                                            |
//+------------------------------------------------------------------+
void DetectTradeClose()
{
   static int lastHistoryTotal = 0;
   int currentTotal = HistoryDealsTotal();
   
   if(currentTotal > lastHistoryTotal)
   {
      if(HistorySelect(TimeCurrent() - 60, TimeCurrent()))
      {
         for(int i = HistoryDealsTotal()-1; i >= 0; i--)
         {
            ulong tkt = HistoryDealGetTicket(i);
            if(tkt == 0) continue;
            if(HistoryDealGetInteger(tkt, DEAL_MAGIC) != (long)InpMagicNumber) continue;
            if(HistoryDealGetString(tkt, DEAL_SYMBOL) != _Symbol) continue;
            if(HistoryDealGetInteger(tkt, DEAL_ENTRY) != DEAL_ENTRY_OUT) continue;
            
            datetime closeTime = (datetime)HistoryDealGetInteger(tkt, DEAL_TIME);
            if(closeTime > g_LastTradeCloseTime)
            {
               double pnl = HistoryDealGetDouble(tkt, DEAL_PROFIT) +
                           HistoryDealGetDouble(tkt, DEAL_COMMISSION) +
                           HistoryDealGetDouble(tkt, DEAL_SWAP);
               
               bool wasWin = (pnl >= 0);
               OnTradeClose(pnl, wasWin);
               break;
            }
         }
      }
   }
   lastHistoryTotal = currentTotal;
}

void OnTradeClose(double pnl, bool wasWin)
{
   g_LastTradeCloseTime = TimeCurrent();
   g_LastTradePnL = pnl;
   g_LastTradeWasWin = wasWin;
   
   UpdatePerformanceMetrics();
   
   Print("[TRADE CLOSED] PnL=$", pnl, " Result=", (wasWin?"WIN":"LOSS"));
   
   if(InpUsePostTradeAnalysis)
   {
      g_PostTradeReviewEnd = TimeCurrent() + InpPostTradeReviewSec;
      g_State = STATE_POST_TRADE_REVIEW;
      Print("[Post-Review] Initiated");
   }
   else
   {
      g_StateTimer = TimeCurrent() + InpCooldownSeconds;
      g_State = STATE_COOLDOWN;
   }
}

void UpdatePerformanceMetrics()
{
   if(!HistorySelect(g_SessionDay, TimeCurrent())) return;
   
   double totalWins = 0, totalLosses = 0;
   int wins = 0, losses = 0;
   double largest_win = 0, largest_loss = 0;
   
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
      
      if(pnl >= 0)
      {
         totalWins += pnl;
         wins++;
         if(pnl > largest_win) largest_win = pnl;
      }
      else
      {
         totalLosses += MathAbs(pnl);
         losses++;
         if(MathAbs(pnl) > largest_loss) largest_loss = MathAbs(pnl);
      }
   }
   
   g_AvgWinSize = (wins > 0) ? totalWins / wins : 0;
   g_AvgLossSize = (losses > 0) ? totalLosses / losses : 0;
   g_LargestWin = largest_win;
   g_LargestLoss = largest_loss;
   g_ProfitFactor = (totalLosses > 0) ? totalWins / totalLosses : 0;
}

//+------------------------------------------------------------------+
//| DAILY STATS SYNC                                                 |
//+------------------------------------------------------------------+
void SyncDailyStats()
{
   datetime now = TimeCurrent();
   datetime dayStart = GetDayStart(now);

   if(dayStart > g_SessionDay)
   {
      g_SessionDay     = dayStart;
      g_DailyTrades    = 0;
      g_DailyProfit    = 0.0;
      g_DailyWins      = 0;
      g_DailyLosses    = 0;
      g_SessionOpenBal = AccountInfoDouble(ACCOUNT_BALANCE);
      if(g_State == STATE_DAILY_LIMIT) g_State = STATE_SCANNING;
   }

   g_DailyProfit  = 0.0;
   g_DailyWins    = 0;
   g_DailyLosses  = 0;
   g_ConsecLosses = 0;
   g_ConsecWins   = 0;

   if(!HistorySelect(dayStart, now)) return;

   bool lastWasWin = false;
   int  curStreak  = 0;

   for(int i = 0; i < HistoryDealsTotal(); i++)
   {
      ulong tkt = HistoryDealGetTicket(i);
      if(tkt == 0) continue;
      if(HistoryDealGetInteger(tkt, DEAL_MAGIC)  != (long)InpMagicNumber) continue;
      if(HistoryDealGetString(tkt, DEAL_SYMBOL)  != _Symbol) continue;
      if(HistoryDealGetInteger(tkt, DEAL_ENTRY)  != DEAL_ENTRY_OUT) continue;

      double pnl = HistoryDealGetDouble(tkt, DEAL_PROFIT)
                 + HistoryDealGetDouble(tkt, DEAL_COMMISSION)
                 + HistoryDealGetDouble(tkt, DEAL_SWAP);
      g_DailyProfit += pnl;
      bool win = (pnl >= 0.0);
      if(win) g_DailyWins++; else g_DailyLosses++;

      if(win == lastWasWin) curStreak++; else curStreak = 1;
      lastWasWin = win;
   }

   if(lastWasWin) g_ConsecWins = curStreak;
   else           g_ConsecLosses = curStreak;
   
   UpdatePerformanceMetrics();
}

//+------------------------------------------------------------------+
//| UTILITY FUNCTIONS                                                |
//+------------------------------------------------------------------+
bool IsPositionOpen()
{
   for(int i = PositionsTotal()-1; i >= 0; i--)
      if(g_Pos.SelectByIndex(i) && g_Pos.Magic()==InpMagicNumber && g_Pos.Symbol()==_Symbol) return true;
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
   return (m == SYMBOL_TRADE_MODE_FULL || m == SYMBOL_TRADE_MODE_LONGONLY || m == SYMBOL_TRADE_MODE_SHORTONLY);
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
   int    cap    = 2000;
   g_AvgSpread   = (g_AvgSpread * g_SpreadSamples + spread) / (double)(g_SpreadSamples + 1);
   g_SpreadSamples = MathMin(g_SpreadSamples + 1, cap);
}

bool IsDailyLossLimitHit()
{
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double limit   = balance * (InpMaxDailyLossPct / 100.0);
   return (g_DailyProfit <= -MathAbs(limit));
}

bool IsDailyProfitTargetHit()
{
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double target  = balance * (InpMaxDailyProfitPct / 100.0);
   return (g_DailyProfit >= target);
}

datetime GetDayStart(datetime t)
{
   MqlDateTime d; TimeToStruct(t, d);
   return t - (datetime)(d.hour*3600 + d.min*60 + d.sec);
}

//+------------------------------------------------------------------+
//| PREMIUM LUXURY DASHBOARD                                         |
//+------------------------------------------------------------------+
void RenderDashboard()
{
   int X = InpDashX, Y = InpDashY;
   int W = 680, H = 580;

   DrawRect("BG",    X,   Y,   W,   H,   C_BG, C_BORDER, 3);
   
   DrawRect("HDR",   X+3, Y+3, W-6, 72,  C_HEADER, C_BLUE, 1);
   DrawRect("HDR_ACCENT", X+3, Y+3, 6, 72, C_GOLD, clrNONE, 0);
   
   DrawLabel("T1",  X+18, Y+12, "⬡ ELITE SCALPER",        C_GOLD, 20, "Impact");
   DrawLabel("T2",  X+18, Y+38, "ADVANCED GOLD ENGINE",    C_WHITE,  11,  "Arial Black");
   DrawLabel("T3",  X+18, Y+56, "v6.0 PRO | Multi-Analysis Suite", C_CYAN, 8, "Arial");
   
   DrawRect("SYM_BG", X+W-160, Y+8, 150, 58, C_PANEL, C_GOLD, 1);
   DrawLabel("SYM", X+W-150, Y+18, _Symbol, C_GOLD, 16, "Impact");
   DrawLabel("SYM_STATUS", X+W-150, Y+42, "● LIVE", C_GREEN, 9, "Arial Black");

   int SBAR = Y+80;
   DrawRect("STATUSBAR", X+3, SBAR, W-6, 28, C_PANEL, clrNONE, 0);
   DrawLabel("SB_LABEL", X+12, SBAR+8, "⚡ CORE STATUS:", C_GOLD, 9, "Arial Black");
   DrawLabel("SB_VALUE", X+150, SBAR+8, "INITIALIZING", C_BLUE, 9, "Consolas Bold");
   DrawLabel("SB_PULSE", X+W-120, SBAR+8, "█ ▓ █ █", C_BLUE, 9, "Consolas");

   int COL1_X = X+8;
   int COL2_X = X+348;
   int COL_W = 320;
   int ROW_Y = SBAR+35;

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

   // Panel 2: Performance
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

   // Panel 3: Execution
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

   // Panel 4: Market Regime
   ROW_Y = SBAR+35;
   DrawRect("P4", COL2_X, ROW_Y, COL_W, 115, C_PANEL, C_ORANGE, 1);
   DrawRect("P4_HDR", COL2_X+2, ROW_Y+2, COL_W-4, 24, C_HEADER, clrNONE, 0);
   DrawLabel("P4H", COL2_X+10, ROW_Y+7, "🌐 MARKET REGIME", C_GOLD, 10, "Arial Black");
   
   int P4Y = ROW_Y+32;
   DrawLabel("L_REG", COL2_X+12, P4Y,      "Status:",      C_MUTED, 9, "Arial");
   DrawLabel("V_REG", COL2_X+150, P4Y,     "DETECTING",    C_GOLD, 10, "Arial Black");
   
   DrawLabel("L_TRQ", COL2_X+12, P4Y+24,   "Trend Quality:", C_MUTED, 9, "Arial");
   DrawLabel("V_TRQ", COL2_X+150, P4Y+24,  "0%",           C_WHITE, 10, "Arial Bold");
   DrawRect("BAR_TRQ_BG", COL2_X+12, P4Y+44, 296, 8, C'20,25,35', C_MUTED, 1);
   DrawRect("BAR_TRQ", COL2_X+13, P4Y+45, 1, 6, C_GREEN, clrNONE, 0);
   
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
   DrawRect("BAR_QUA", COL2_X+13, P5Y+21, 1, 6, C_BLUE, clrNONE, 0);
   
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

void UpdateDashboard()
{
   SetLabel("SB_PULSE", g_HeartbeatStr, C_BLUE);
   SetLabel("SB_VALUE", g_StatusText, g_StatusColor);

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

   SetLabel("V_TR", IntegerToString(g_DailyTrades) + " / " + IntegerToString(InpMaxDailyTrades));

   int tot = g_DailyWins + g_DailyLosses;
   double wr = (tot > 0) ? ((double)g_DailyWins / tot) * 100.0 : 0.0;
   color cWR = (wr >= 60) ? C_GREEN : (wr >= 40 ? C_GOLD : C_RED);
   SetLabel("V_WR", DoubleToString(wr, 0) + "%", cWR);

   SetLabel("V_AVG", "$" + DoubleToString(g_AvgWinSize, 0) + "/$" + DoubleToString(g_AvgLossSize, 0));

   if(g_ConsecWins > 1)
      SetLabel("V_STK", "🔥 WIN ×" + IntegerToString(g_ConsecWins), C_GREEN);
   else if(g_ConsecLosses > 1)
      SetLabel("V_STK", "❄️ LOSS ×" + IntegerToString(g_ConsecLosses), C_RED);
   else
      SetLabel("V_STK", "—", C_MUTED);

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

   string regTxt = EnumToString(g_CurrentRegime);
   StringReplace(regTxt, "REGIME_", "");
   StringReplace(regTxt, "_", " ");
   color regCol = (g_CurrentRegime == REGIME_TRENDING_STRONG) ? C_GREEN :
                  (g_CurrentRegime == REGIME_TRENDING_WEAK) ? C_GOLD : 
                  (g_CurrentRegime == REGIME_RANGING) ? C_ORANGE : C_RED;
   SetLabel("V_REG", regTxt, regCol);

   color tqCol = (g_CurrentTrendQuality >= 70) ? C_GREEN : 
                 (g_CurrentTrendQuality >= 50) ? C_GOLD : C_RED;
   SetLabel("V_TRQ", DoubleToString(g_CurrentTrendQuality, 0) + "%", tqCol);
   
   int COL2_X = InpDashX + 348;
   int P4Y_BASE = InpDashY + 80 + 35 + 32;
   int barWidth = (int)((g_CurrentTrendQuality / 100.0) * 294);
   DrawRect("BAR_TRQ", COL2_X+13, P4Y_BASE+45, barWidth, 6, tqCol, clrNONE, 0);

   double volScore = AnalyzeRecentVolatility();
   string volTxt = (volScore > 0.8) ? "OPTIMAL" : (volScore > 0.5) ? "NORMAL" : "EXTREME";
   color volCol = (volScore > 0.8) ? C_GREEN : (volScore > 0.5) ? C_GOLD : C_RED;
   SetLabel("V_VOL", volTxt, volCol);

   color qCol = (g_TradeQualityScore >= 70) ? C_GREEN :
                (g_TradeQualityScore >= 50) ? C_GOLD : C_RED;
   SetLabel("V_QUA", DoubleToString(g_TradeQualityScore, 0) + "%", qCol);
   
   int P5Y_BASE = InpDashY + 80 + 35 + 123 + 32;
   int barWidthQ = (int)((g_TradeQualityScore / 100.0) * 294);
   DrawRect("BAR_QUA", COL2_X+13, P5Y_BASE+21, barWidthQ, 6, qCol, clrNONE, 0);

   ENUM_SIGNAL testSig = EvaluateConfluence();
   bool mtfOK = CheckMultiTimeframeAlignment(testSig);
   SetLabel("V_MTF", mtfOK ? "● ✓" : "● ✗", mtfOK ? C_GREEN : C_RED);

   double rsi[1], adx[1];
   CopyBuffer(g_hRSI, 0, 0, 1, rsi);
   CopyBuffer(g_hADX, 0, 0, 1, adx);

   color cRSI = (rsi[0] > InpRSIOverbought || rsi[0] < InpRSIOversold) ? C_RED : C_WHITE;
   SetLabel("V_RSI", DoubleToString(rsi[0], 1), cRSI);

   color cADX = (adx[0] >= InpADXMinStrength) ? C_GREEN : C_GOLD;
   SetLabel("V_ADX", DoubleToString(adx[0], 1), cADX);

   SetLabel("V_ATR", DoubleToString(atrLive, 2));

   SetLabel("V_ST", g_StatusText, g_StatusColor);
   
   bool inSess = IsInSession();
   string sessTxt = inSess ? "ACTIVE" : "CLOSED";
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
//+------------------------------------------------------------------+
//| END OF FILE – EliteScalper v6.0 PRO                             |
//+------------------------------------------------------------------+