//+------------------------------------------------------------------+
//|                          THEE EliteScalper v6.0 PRO - OPTIMIZED |
//|                                  Copyright 2026, FXBotHub Systems|
//|                                             https://fxbothub.com |
//+------------------------------------------------------------------+
//  GOLD (XAUUSD) Advanced Scalping Engine - OPTIMIZED RR RATIO
//  Key Improvements:
//    • 1:3 Risk-Reward Ratio (1 win = 3 losses covered)
//    • Profit Reversal Protection (auto-close on profit drop)
//    • 3-Level TP System (TP1=2x, TP2=3x, TP3=4x ATR)
//    • Tighter SL, Aggressive TP
//    • Smart Profit Lock System
//+------------------------------------------------------------------+
#property copyright   "Copyright 2026, THEE EliteScalper Systems"
#property version     "6.00"
#property description "GOLD Advanced Scalping Engine – Optimized RR Ratio"
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
//| INPUT PARAMETERS - OPTIMIZED                                     |
//+------------------------------------------------------------------+
input group "=== CORE IDENTITY ==="
input ulong   InpMagicNumber       = 999555;
input string  InpTradeComment      = "EliteScalper_v6_PRO";

input group "=== RISK MANAGEMENT ==="
input double  InpRiskPercent       = 1.0;        // Risk % per trade
input double  InpMaxDailyLossPct   = 5.0;        // Daily loss limit %
input double  InpMaxDailyProfitPct = 10.0;       // Daily profit target %
input int     InpMaxDailyTrades    = 15;         // Max trades per day

input group "=== ★★★ OPTIMIZED SL/TP - BETTER RISK-REWARD ★★★ ==="
input int     InpATRPeriod         = 14;         // ATR period
input double  InpSLMultiplier      = 1.0;        // SL = ATR × 1.0 (TIGHTER!)
input double  InpTP1Multiplier     = 2.0;        // TP1 = ATR × 2.0 (1:2 RR)
input double  InpTP2Multiplier     = 3.0;        // TP2 = ATR × 3.0 (1:3 RR)
input double  InpTP3Multiplier     = 4.0;        // TP3 = ATR × 4.0 (1:4 RR - Final Target)
input int     InpMinSLPoints       = 100;        // Minimum SL (tighter)
input int     InpMaxSLPoints       = 300;        // Maximum SL (reduced)

input group "=== ★★★ PROFIT REVERSAL PROTECTION ★★★ ==="
input bool    InpUseReversalProtection = true;   // Enable profit reversal auto-close
input double  InpMaxProfitDropDollars  = 2.0;    // Close if profit drops by $X from peak
input double  InpMinProfitToProtect    = 0.5;    // Only protect if profit > $X

input group "=== BREAKEVEN & TRAILING - AGGRESSIVE ==="
input int     InpBreakevenPoints   = 80;         // Move to BE faster (was 120)
input int     InpBreakevenBuffer   = 5;          // Smaller buffer
input bool    InpUseTrailing       = true;       // Enable trailing
input int     InpTrailStartPoints  = 100;        // Start trailing earlier (was 200)
input int     InpTrailStepPoints   = 30;         // Tighter trail step (was 50)

input group "=== PARTIAL CLOSE - 3 LEVELS ==="
input bool    InpUsePartialClose   = true;       // Enable partial close
input double  InpPartialTP1Pct     = 30.0;       // Close 30% at TP1 (2x RR)
input double  InpPartialTP2Pct     = 40.0;       // Close 40% at TP2 (3x RR)
// Remaining 30% rides to TP3 or trailing stop

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
input double  InpMinTradeQuality      = 70.0;    // Higher quality threshold
input bool    InpAdaptiveLotByQuality = true;

input group "=== SIGNAL CONFLUENCE ==="
input int     InpFastEMAPeriod     = 9;
input int     InpSlowEMAPeriod     = 21;
input int     InpTrendEMAPeriod    = 50;
input int     InpRSIPeriod         = 14;
input double  InpRSIOverbought     = 70.0;
input double  InpRSIOversold       = 30.0;
input int     InpADXPeriod         = 14;
input double  InpADXMinStrength    = 25.0;       // Stronger trend required
input int     InpMACDFast          = 12;
input int     InpMACDSlow          = 26;
input int     InpMACDSignal        = 9;
input int     InpBBPeriod          = 20;
input double  InpBBDeviation       = 2.0;
input double  InpBBSqueezeRatio    = 0.003;
input int     InpStructureBars     = 5;

input group "=== COOLDOWN & SPREAD ==="
input int     InpCooldownSeconds   = 45;
input int     InpSpreadMaxPoints   = 30;         // Tighter spread requirement
input double  InpSpreadMultiplier  = 2.0;

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
//| COLOR PALETTE                                                    |
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
//| GLOBAL VARIABLES                                                 |
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

// Partial close tracking
bool         g_PartialTP1Closed  = false;
bool         g_PartialTP2Closed  = false;

// Profit reversal protection
double       g_PeakProfit        = 0.0;
bool         g_ProfitProtectionActive = false;

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
void         CheckProfitReversalProtection();
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

   // Validate RR ratio
   double minRR = InpTP1Multiplier / InpSLMultiplier;
   if(minRR < 1.5)
   {
      Alert("WARNING: Risk-Reward ratio is ", DoubleToString(minRR, 2), ":1. Recommended minimum is 1.5:1");
   }
   else
   {
      Print("[RR Ratio] TP1=", DoubleToString(minRR, 2), ":1 | TP2=", DoubleToString(InpTP2Multiplier/InpSLMultiplier, 2), ":1 | TP3=", DoubleToString(InpTP3Multiplier/InpSLMultiplier, 2), ":1");
   }

   if(!InitIndicators()) return INIT_FAILED;

   g_SessionDay     = GetDayStart(TimeCurrent());
   g_SessionOpenBal = AccountInfoDouble(ACCOUNT_BALANCE);
   SyncDailyStats();

   g_State = STATE_SCANNING;
   EventSetTimer(1);
   RenderDashboard();

   Print("[EliteScalper v6 PRO] OPTIMIZED EDITION INITIALIZED");
   Print("[Features] Profit Reversal Protection | 3-Level TP | 1:3+ RR Ratio");
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
   string p[4] = {"█ ▓ █ █  ▓ █ ▓ ▓","▓ █ ▓ ▓  █ ▓ █ █","█ █ ▓ █  ▓ ▓ █ ▓","▓ ▓ █ ▓  █ █ ▓ █"};
   g_HeartbeatStr = p[beat % 4];
   SyncDailyStats();
   UpdateDashboard();
}

//+------------------------------------------------------------------+
//| TICK EVENT                                                       |
//+------------------------------------------------------------------+
void OnTick()
{
   UpdateSpreadAverage();
   
   g_CurrentTrendQuality = AnalyzeTrendQuality(InpTrendLookbackBars);
   g_CurrentRegime = DetectMarketRegime(InpRegimeLookback);

   if(!IsMarketOpen())
   { g_StatusText = "MARKET CLOSED"; g_StatusColor = C_RED; return; }

   if(InpNewsPauseActive || g_State == STATE_NEWS_PAUSE)
   { g_StatusText = "NEWS PAUSE"; g_StatusColor = C_GOLD; return; }

   if(IsPositionOpen())
   { ManageOpenTrade(); return; }

   DetectTradeClose();

   if(g_State == STATE_POST_TRADE_REVIEW)
   { ProcessPostTradeReview(); return; }

   if(IsDailyLossLimitHit())
   { g_State = STATE_DAILY_LIMIT; g_StatusText = "DAILY LOSS LIMIT"; g_StatusColor = C_RED; return; }

   if(IsDailyProfitTargetHit())
   { g_State = STATE_DAILY_LIMIT; g_StatusText = "DAILY TARGET MET"; g_StatusColor = C_GREEN; return; }

   if(g_DailyTrades >= InpMaxDailyTrades)
   { g_StatusText = "MAX DAILY TRADES"; g_StatusColor = C_GOLD; return; }

   if(InpUseSessionFilter && !IsInSession())
   { g_StatusText = "OUT OF SESSION"; g_StatusColor = C_MUTED; return; }

   if(!IsSpreadOk())
   { g_StatusText = "SPREAD HIGH"; g_StatusColor = C_RED; return; }

   if(g_State == STATE_COOLDOWN)
   {
      int left = (int)(g_StateTimer - TimeCurrent());
      if(left > 0) { g_StatusText = "COOLDOWN " + IntegerToString(left) + "s"; g_StatusColor = C_GOLD; return; }
      g_State = STATE_SCANNING;
   }

   if(g_State == STATE_SCANNING)
   {
      ENUM_SIGNAL sig = EvaluateConfluence();
      if(sig == SIGNAL_NONE)
      { g_StatusText = "SCANNING"; g_StatusColor = C_MUTED; return; }

      g_TradeQualityScore = CalculateTradeQualityScore(sig);
      
      if(g_TradeQualityScore < InpMinTradeQuality)
      { g_StatusText = "LOW QUALITY " + DoubleToString(g_TradeQualityScore, 0) + "%"; g_StatusColor = C_ORANGE; return; }

      g_State = STATE_ANALYZING;
      g_PendingSignal = sig;
      g_AnalysisStart = TimeCurrent();
      g_AnalysisTicks = 0;
      g_StatusText = "ANALYZING Q=" + DoubleToString(g_TradeQualityScore, 0) + "%";
      g_StatusColor = C_PURPLE;
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
      return false;

   if(InpUseMTFFilter && (g_hEMA_MTF1==INVALID_HANDLE || g_hEMA_MTF2==INVALID_HANDLE))
      return false;

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
//| TRADE EXECUTION - OPTIMIZED RR RATIO                             |
//+------------------------------------------------------------------+
void ExecuteEntry(ENUM_SIGNAL sig)
{
   if(!IsSpreadOk()) { Print("[Entry] Spread too wide"); return; }

   double point  = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   int    digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   double atr    = GetATR();
   double price  = (sig == SIGNAL_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                       : SymbolInfoDouble(_Symbol, SYMBOL_BID);

   // OPTIMIZED: Tighter SL
   int slPoints  = (int)MathRound((atr * InpSLMultiplier) / point);
   slPoints      = MathMax(InpMinSLPoints, MathMin(InpMaxSLPoints, slPoints));

   // OPTIMIZED: TP3 as main target (1:4 RR)
   int tp3Points = (int)MathRound((atr * InpTP3Multiplier) / point);

   double sl, tp;
   if(sig == SIGNAL_BUY)
   {
      sl = NormalizeDouble(price - slPoints  * point, digits);
      tp = NormalizeDouble(price + tp3Points * point, digits);
   }
   else
   {
      sl = NormalizeDouble(price + slPoints  * point, digits);
      tp = NormalizeDouble(price - tp3Points * point, digits);
   }

   double lot = CalculateLotSize(slPoints, g_TradeQualityScore);

   // Calculate RR ratio
   double rrRatio = (double)tp3Points / (double)slPoints;

   Print("[ENTRY] ", (sig==SIGNAL_BUY?"BUY":"SELL"),
         " Quality=", g_TradeQualityScore, "%",
         " Lot=", lot,
         " SL=", slPoints, "pts",
         " TP=", tp3Points, "pts",
         " RR=1:", DoubleToString(rrRatio, 2));

   bool ok = (sig == SIGNAL_BUY) ? g_Trade.Buy(lot, _Symbol, price, sl, tp, InpTradeComment)
                                 : g_Trade.Sell(lot, _Symbol, price, sl, tp, InpTradeComment);
   if(ok)
   {
      g_DailyTrades++;
      g_PartialTP1Closed = false;
      g_PartialTP2Closed = false;
      g_PeakProfit = 0.0;
      g_ProfitProtectionActive = false;
      g_StatusText  = (sig==SIGNAL_BUY) ? "LONG ACTIVE" : "SHORT ACTIVE";
      g_StatusColor = C_GREEN;
   }
}

//+------------------------------------------------------------------+
//| TRADE MANAGEMENT - ENHANCED                                      |
//+------------------------------------------------------------------+
void ManageOpenTrade()
{
   if(!IsPositionOpen()) return;
   
   CheckProfitReversalProtection();  // NEW: Auto-close on profit drop
   CheckPartialClose();              // 3-level partial close
   CheckBreakeven();                 // Move to BE
   if(InpUseTrailing) CheckTrailing(); // Aggressive trailing
   EvaluateFloatingPnL();            // Daily target check

   double pnl = GetFloatingPnL();
   g_StatusText  = "IN TRADE | " + (pnl >= 0 ? "+$" : "-$") + DoubleToString(MathAbs(pnl), 2);
   g_StatusColor = (pnl >= 0) ? C_GREEN : C_RED;
}

//+------------------------------------------------------------------+
//| ★★★ PROFIT REVERSAL PROTECTION - NEW FEATURE ★★★               |
//+------------------------------------------------------------------+
void CheckProfitReversalProtection()
{
   if(!InpUseReversalProtection) return;
   
   double currentPnL = GetFloatingPnL();
   
   // Track peak profit
   if(currentPnL > g_PeakProfit)
      g_PeakProfit = currentPnL;
   
   // Only activate protection if we've made meaningful profit
   if(g_PeakProfit >= InpMinProfitToProtect)
      g_ProfitProtectionActive = true;
   
   // If profit drops by threshold from peak, close immediately
   if(g_ProfitProtectionActive)
   {
      double profitDrop = g_PeakProfit - currentPnL;
      
      if(profitDrop >= InpMaxProfitDropDollars)
      {
         Print("[PROFIT REVERSAL] Closing trade. Peak=$", g_PeakProfit, 
               " Current=$", currentPnL, 
               " Drop=$", profitDrop);
         CloseAllPositions("Profit reversal protection triggered");
      }
   }
}

//+------------------------------------------------------------------+
//| PARTIAL CLOSE - 3 LEVELS                                         |
//+------------------------------------------------------------------+
void CheckPartialClose()
{
   if(!InpUsePartialClose) return;

   for(int i = PositionsTotal()-1; i >= 0; i--)
   {
      if(!g_Pos.SelectByIndex(i)) continue;
      if(g_Pos.Magic() != InpMagicNumber || g_Pos.Symbol() != _Symbol) continue;

      double open   = g_Pos.PriceOpen();
      double point  = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
      double bid    = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      double ask    = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      bool   isBuy  = (g_Pos.PositionType() == POSITION_TYPE_BUY);
      double atr    = GetATR();

      double profitPts = isBuy ? (bid - open)/point : (open - ask)/point;
      
      double tp1Pts = (atr * InpTP1Multiplier) / point;
      double tp2Pts = (atr * InpTP2Multiplier) / point;

      // TP1: Close first portion (30%)
      if(!g_PartialTP1Closed && profitPts >= tp1Pts)
      {
         double originalVol = g_Pos.Volume();
         double closeLot = NormalizeDouble(originalVol * (InpPartialTP1Pct / 100.0),
                            (int)MathLog10(1.0/SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP)));
         double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
         
         if(closeLot >= minLot)
         {
            if(g_Trade.PositionClosePartial(g_Pos.Ticket(), closeLot))
            {
               g_PartialTP1Closed = true;
               Print("[TP1 HIT] Closed ", InpPartialTP1Pct, "% at 1:", DoubleToString(InpTP1Multiplier/InpSLMultiplier, 1), " RR");
            }
         }
      }
      
      // TP2: Close second portion (40%)
      if(!g_PartialTP2Closed && profitPts >= tp2Pts)
      {
         double originalVol = g_Pos.Volume();
         double closeLot = NormalizeDouble(originalVol * (InpPartialTP2Pct / (100.0 - InpPartialTP1Pct)),
                            (int)MathLog10(1.0/SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP)));
         double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
         
         if(closeLot >= minLot)
         {
            if(g_Trade.PositionClosePartial(g_Pos.Ticket(), closeLot))
            {
               g_PartialTP2Closed = true;
               Print("[TP2 HIT] Closed ", InpPartialTP2Pct, "% at 1:", DoubleToString(InpTP2Multiplier/InpSLMultiplier, 1), " RR");
            }
         }
      }
      
      // Remaining 30% rides to TP3 or trailing stop
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
         {
            if(g_Trade.PositionModify(g_Pos.Ticket(), beSL, g_Pos.TakeProfit()))
               Print("[BREAKEVEN] SL moved to entry +", InpBreakevenBuffer, "pts");
         }
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

//+------------------------------------------------------------------+
//| ANALYSIS & SIGNAL FUNCTIONS                                      |
//+------------------------------------------------------------------+
void ProcessAnalysisPhase()
{
   g_AnalysisTicks++;
   int elapsed = (int)(TimeCurrent() - g_AnalysisStart);

   if(elapsed > InpAnalysisMaxSec)
   { g_State = STATE_SCANNING; return; }

   ENUM_SIGNAL current = EvaluateConfluence();
   if(current != g_PendingSignal)
   { g_State = STATE_SCANNING; return; }

   if(elapsed >= InpAnalysisMinSec && g_AnalysisTicks >= InpAnalysisMinTicks)
   {
      ExecuteEntry(g_PendingSignal);
      g_State = STATE_SCANNING;
   }
}

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
   if(CheckBollingerBands(emaSig, inSqueeze)) score++;
   else if(inSqueeze) return SIGNAL_NONE;
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
   return ((fast > slow && slow > trend) || (fast < slow && slow < trend));
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
   if(CopyBuffer(g_hBB, 0, 0, 1, mid)   <= 0) return false;

   double width = upper[0] - lower[0];
   double price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(width < price * InpBBSqueezeRatio) { inSqueeze = true; return false; }
   inSqueeze = false;

   if(sig == SIGNAL_BUY)  return (price > mid[0]);
   if(sig == SIGNAL_SELL) return (price < mid[0]);
   return false;
}

bool CheckMarketStructure(ENUM_SIGNAL sig)
{
   int highBar = iHighest(_Symbol, _Period, MODE_HIGH, InpStructureBars, 1);
   int lowBar  = iLowest(_Symbol,  _Period, MODE_LOW,  InpStructureBars, 1);
   if(highBar < 0 || lowBar < 0) return false;

   double swingHigh = iHigh(_Symbol, _Period, highBar);
   double swingLow  = iLow(_Symbol,  _Period, lowBar);
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

double CalculateLotSize(int slPoints, double qualityMultiplier = 1.0)
{
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double riskPct = GetRiskAdjustedPercent();
   
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
   if(g_ConsecLosses >= InpMaxLossStreak) pct = InpRiskPercent * 0.5;
   else if(g_ConsecWins >= InpWinStreakBoost) pct = MathMin(InpRiskPercent * 1.25, 2.0);
   return pct;
}

// Include all other analysis functions from previous version
void ProcessPostTradeReview()
{
   int remaining = (int)(g_PostTradeReviewEnd - TimeCurrent());
   if(remaining > 0)
   {
      g_StatusText = "POST-ANALYSIS " + IntegerToString(remaining) + "s";
      g_StatusColor = C_CYAN;
   }
   else
   {
      if(InpBlockAfterLoss && !g_LastTradeWasWin && g_CurrentTrendQuality < 70.0)
      {
         g_StateTimer = TimeCurrent() + InpCooldownSeconds;
         g_State = STATE_COOLDOWN;
         return;
      }
      g_State = STATE_SCANNING;
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
   if(CopyBuffer(g_hADX, 0, 0, 1, adx) > 0) score += MathMin(25.0, adx[0] * 0.625);
   return MathMin(100.0, score);
}

ENUM_MARKET_REGIME DetectMarketRegime(int lookback)
{
   MqlRates rates[];
   if(CopyRates(_Symbol, _Period, 0, lookback, rates) < lookback) return REGIME_CHOPPY;
   double highest = rates[0].high, lowest = rates[0].low;
   for(int i = 1; i < lookback; i++)
   {
      if(rates[i].high > highest) highest = rates[i].high;
      if(rates[i].low < lowest) lowest = rates[i].low;
   }
   double trendRatio = (highest > lowest) ? MathAbs(rates[lookback-1].close - rates[0].close) / (highest - lowest) : 0;
   double adx[1];
   bool adxOk = (CopyBuffer(g_hADX, 0, 0, 1, adx) > 0);
   if(adxOk && adx[0] > 30.0 && trendRatio > 0.6) return REGIME_TRENDING_STRONG;
   else if(adxOk && adx[0] > 20.0 && trendRatio > 0.4) return REGIME_TRENDING_WEAK;
   else if(trendRatio < 0.3) return REGIME_RANGING;
   return REGIME_CHOPPY;
}

bool CheckMultiTimeframeAlignment(ENUM_SIGNAL sig)
{
   if(!InpUseMTFFilter) return true;
   double currentPrice = (sig == SIGNAL_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double mtf1[1], mtf2[1];
   if(CopyBuffer(g_hEMA_MTF1, 0, 0, 1, mtf1) <= 0) return false;
   if(CopyBuffer(g_hEMA_MTF2, 0, 0, 1, mtf2) <= 0) return false;
   bool mtf1OK = (sig == SIGNAL_BUY) ? (currentPrice > mtf1[0]) : (currentPrice < mtf1[0]);
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
   if(CheckMultiTimeframeAlignment(sig)) score += 20.0;
   int confirmations = 0;
   double fast, slow, trend, rsi, adx;
   if(CheckEMAStack(fast, slow, trend)) confirmations++;
   if(CheckRSI(sig, rsi)) confirmations++;
   if(CheckADX(adx)) confirmations++;
   if(CheckMACD(sig)) confirmations++;
   bool squeeze;
   if(CheckBollingerBands(sig, squeeze) && !squeeze) confirmations++;
   if(CheckMarketStructure(sig)) confirmations++;
   score += (confirmations / 6.0) * 35.0;
   return MathMin(100.0, score);
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
      if(sig == SIGNAL_BUY && lowerWick > body * 2.0 && upperWick < body) return true;
      if(sig == SIGNAL_SELL && upperWick > body * 2.0 && lowerWick < body) return true;
   }
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
               OnTradeClose(pnl, (pnl >= 0));
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
      if(pnl >= 0) { totalWins += pnl; wins++; }
      else { totalLosses += MathAbs(pnl); losses++; }
   }
   g_AvgWinSize = (wins > 0) ? totalWins / wins : 0;
   g_AvgLossSize = (losses > 0) ? totalLosses / losses : 0;
   g_ProfitFactor = (totalLosses > 0) ? totalWins / totalLosses : 0;
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
   UpdatePerformanceMetrics();
}

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

//+------------------------------------------------------------------+
//| PREMIUM DASHBOARD - Updated with new metrics                     |
//+------------------------------------------------------------------+
void RenderDashboard()
{
   int X = InpDashX, Y = InpDashY;
   int W = 680, H = 600;

   DrawRect("BG", X, Y, W, H, C_BG, C_BORDER, 3);
   DrawRect("HDR", X+3, Y+3, W-6, 72, C_HEADER, C_BLUE, 1);
   DrawRect("HDR_ACCENT", X+3, Y+3, 6, 72, C_GOLD, clrNONE, 0);
   
   DrawLabel("T1", X+18, Y+12, "⬡ ELITE SCALPER", C_GOLD, 20, "Impact");
   DrawLabel("T2", X+18, Y+38, "OPTIMIZED RR ENGINE", C_WHITE, 11, "Arial Black");
   DrawLabel("T3", X+18, Y+56, "v6.0 PRO | 1:3+ Risk-Reward | Profit Lock", C_CYAN, 8, "Arial");
   
   DrawRect("SYM_BG", X+W-160, Y+8, 150, 58, C_PANEL, C_GOLD, 1);
   DrawLabel("SYM", X+W-150, Y+18, _Symbol, C_GOLD, 16, "Impact");
   DrawLabel("SYM_RR", X+W-150, Y+42, "RR: 1:3+", C_GREEN, 9, "Arial Black");

   int SBAR = Y+80;
   DrawRect("STATUSBAR", X+3, SBAR, W-6, 28, C_PANEL, clrNONE, 0);
   DrawLabel("SB_LABEL", X+12, SBAR+8, "⚡ ENGINE:", C_GOLD, 9, "Arial Black");
   DrawLabel("SB_VALUE", X+120, SBAR+8, "READY", C_BLUE, 9, "Consolas Bold");
   DrawLabel("SB_PULSE", X+W-120, SBAR+8, "█ ▓ █ █", C_BLUE, 9, "Consolas");

   int COL1_X = X+8;
   int COL2_X = X+348;
   int COL_W = 320;
   int ROW_Y = SBAR+35;

   // Panel 1: Financials
   DrawRect("P1", COL1_X, ROW_Y, COL_W, 160, C_PANEL, C_BLUE, 1);
   DrawRect("P1_HDR", COL1_X+2, ROW_Y+2, COL_W-4, 24, C_HEADER, clrNONE, 0);
   DrawLabel("P1H", COL1_X+10, ROW_Y+7, "💰 ACCOUNT", C_GOLD, 10, "Arial Black");
   
   int P1Y = ROW_Y+32;
   DrawLabel("L_BAL", COL1_X+12, P1Y, "Balance:", C_MUTED, 9, "Arial");
   DrawLabel("V_BAL", COL1_X+200, P1Y, "$0", C_WHITE, 10, "Arial Bold");
   DrawLabel("L_EQ", COL1_X+12, P1Y+24, "Equity:", C_MUTED, 9, "Arial");
   DrawLabel("V_EQ", COL1_X+200, P1Y+24, "$0", C_WHITE, 10, "Arial Bold");
   DrawLabel("L_DP", COL1_X+12, P1Y+48, "Daily P&L:", C_MUTED, 9, "Arial");
   DrawLabel("V_DP", COL1_X+200, P1Y+48, "$0", C_GREEN, 11, "Arial Black");
   DrawLabel("L_FP", COL1_X+12, P1Y+72, "Float P&L:", C_MUTED, 9, "Arial");
   DrawLabel("V_FP", COL1_X+200, P1Y+72, "$0", C_GREEN, 11, "Arial Black");
   DrawLabel("L_PEAK", COL1_X+12, P1Y+96, "Peak Profit:", C_MUTED, 9, "Arial");
   DrawLabel("V_PEAK", COL1_X+200, P1Y+96, "$0", C_CYAN, 10, "Arial Bold");
   DrawLabel("L_PF", COL1_X+12, P1Y+120, "Profit Factor:", C_MUTED, 9, "Arial");
   DrawLabel("V_PF", COL1_X+200, P1Y+120, "0.00", C_WHITE, 10, "Arial Bold");

   ROW_Y += 168;
   DrawRect("P2", COL1_X, ROW_Y, COL_W, 135, C_PANEL, C_GREEN, 1);
   DrawRect("P2_HDR", COL1_X+2, ROW_Y+2, COL_W-4, 24, C_HEADER, clrNONE, 0);
   DrawLabel("P2H", COL1_X+10, ROW_Y+7, "📊 PERFORMANCE", C_GOLD, 10, "Arial Black");
   
   int P2Y = ROW_Y+32;
   DrawLabel("L_TR", COL1_X+12, P2Y, "Trades:", C_MUTED, 9, "Arial");
   DrawLabel("V_TR", COL1_X+200, P2Y, "0/15", C_WHITE, 10, "Arial Bold");
   DrawLabel("L_WR", COL1_X+12, P2Y+24, "Win Rate:", C_MUTED, 9, "Arial");
   DrawLabel("V_WR", COL1_X+200, P2Y+24, "0%", C_WHITE, 10, "Arial Bold");
   DrawLabel("L_AVG", COL1_X+12, P2Y+48, "Avg W/L:", C_MUTED, 9, "Arial");
   DrawLabel("V_AVG", COL1_X+200, P2Y+48, "$0/$0", C_WHITE, 9, "Arial Bold");
   DrawLabel("L_RRR", COL1_X+12, P2Y+72, "Actual RR:", C_MUTED, 9, "Arial");
   DrawLabel("V_RRR", COL1_X+200, P2Y+72, "1:0", C_WHITE, 10, "Arial Bold");
   DrawLabel("L_STK", COL1_X+12, P2Y+96, "Streak:", C_MUTED, 9, "Arial");
   DrawLabel("V_STK", COL1_X+200, P2Y+96, "—", C_WHITE, 10, "Arial Bold");

   ROW_Y = SBAR+35;
   DrawRect("P3", COL2_X, ROW_Y, COL_W, 135, C_PANEL, C_ORANGE, 1);
   DrawRect("P3_HDR", COL2_X+2, ROW_Y+2, COL_W-4, 24, C_HEADER, clrNONE, 0);
   DrawLabel("P3H", COL2_X+10, ROW_Y+7, "🌐 MARKET STATUS", C_GOLD, 10, "Arial Black");
   
   int P3Y = ROW_Y+32;
   DrawLabel("L_REG", COL2_X+12, P3Y, "Regime:", C_MUTED, 9, "Arial");
   DrawLabel("V_REG", COL2_X+150, P3Y, "DETECTING", C_GOLD, 10, "Arial Black");
   DrawLabel("L_TRQ", COL2_X+12, P3Y+24, "Trend Q:", C_MUTED, 9, "Arial");
   DrawLabel("V_TRQ", COL2_X+150, P3Y+24, "0%", C_WHITE, 10, "Arial Bold");
   DrawLabel("L_VOL", COL2_X+12, P3Y+48, "Volatility:", C_MUTED, 9, "Arial");
   DrawLabel("V_VOL", COL2_X+150, P3Y+48, "NORMAL", C_GREEN, 9, "Arial Bold");
   DrawLabel("L_SPR", COL2_X+12, P3Y+72, "Spread:", C_MUTED, 9, "Arial");
   DrawLabel("V_SPR", COL2_X+150, P3Y+72, "0 pts", C_WHITE, 9, "Arial Bold");
   DrawLabel("L_ATR", COL2_X+12, P3Y+96, "ATR:", C_MUTED, 9, "Arial");
   DrawLabel("V_ATR", COL2_X+150, P3Y+96, "0.00", C_WHITE, 9, "Arial Bold");

   ROW_Y += 143;
   DrawRect("P4", COL2_X, ROW_Y, COL_W, 160, C_PANEL, C_CYAN, 1);
   DrawRect("P4_HDR", COL2_X+2, ROW_Y+2, COL_W-4, 24, C_HEADER, clrNONE, 0);
   DrawLabel("P4H", COL2_X+10, ROW_Y+7, "📡 TRADE SETUP", C_GOLD, 10, "Arial Black");
   
   int P4Y = ROW_Y+32;
   DrawLabel("L_QUA", COL2_X+12, P4Y, "Quality:", C_MUTED, 9, "Arial");
   DrawLabel("V_QUA", COL2_X+150, P4Y, "0%", C_WHITE, 10, "Arial Bold");
   DrawLabel("L_MTF", COL2_X+12, P4Y+24, "MTF:", C_MUTED, 9, "Arial");
   DrawLabel("V_MTF", COL2_X+150, P4Y+24, "●", C_GOLD, 11, "Arial Black");
   DrawLabel("L_RSI", COL2_X+12, P4Y+48, "RSI:", C_MUTED, 9, "Arial");
   DrawLabel("V_RSI", COL2_X+150, P4Y+48, "50", C_WHITE, 9, "Arial Bold");
   DrawLabel("L_ADX", COL2_X+12, P4Y+72, "ADX:", C_MUTED, 9, "Arial");
   DrawLabel("V_ADX", COL2_X+150, P4Y+72, "0", C_WHITE, 9, "Arial Bold");
   DrawLabel("L_LOT", COL2_X+12, P4Y+96, "Next Lot:", C_MUTED, 9, "Arial");
   DrawLabel("V_LOT", COL2_X+150, P4Y+96, "0.01", C_CYAN, 10, "Arial Bold");
   DrawLabel("L_SLTP", COL2_X+12, P4Y+120, "SL/TP:", C_MUTED, 9, "Arial");
   DrawLabel("V_SLTP", COL2_X+150, P4Y+120, "0/0", C_WHITE, 9, "Arial Bold");

   DrawRect("FOOTER", X+3, Y+H-26, W-6, 23, C_HEADER, clrNONE, 0);
   DrawLabel("F1", X+12, Y+H-19, "Optimized 1:3+ RR | Profit Reversal Protection | 3-Level TP System", C_MUTED, 7, "Arial");
   DrawLabel("F2", X+W-115, Y+H-19, "PRO v6.00", C_CYAN, 8, "Arial Black");

   ChartRedraw(0);
}

void UpdateDashboard()
{
   SetLabel("SB_PULSE", g_HeartbeatStr, C_BLUE);
   SetLabel("SB_VALUE", g_StatusText, g_StatusColor);

   double bal = AccountInfoDouble(ACCOUNT_BALANCE);
   double eq = AccountInfoDouble(ACCOUNT_EQUITY);
   double fpl = GetFloatingPnL();

   SetLabel("V_BAL", "$" + DoubleToString(bal, 2));
   SetLabel("V_EQ", "$" + DoubleToString(eq, 2));
   SetLabel("V_DP", (g_DailyProfit >= 0 ? "+$" : "-$") + DoubleToString(MathAbs(g_DailyProfit), 2), (g_DailyProfit >= 0) ? C_GREEN : C_RED);
   SetLabel("V_FP", (fpl >= 0 ? "+$" : "-$") + DoubleToString(MathAbs(fpl), 2), (fpl >= 0) ? C_GREEN : C_RED);
   SetLabel("V_PEAK", "$" + DoubleToString(g_PeakProfit, 2), C_CYAN);
   SetLabel("V_PF", DoubleToString(g_ProfitFactor, 2), (g_ProfitFactor >= 1.5) ? C_GREEN : C_WHITE);

   SetLabel("V_TR", IntegerToString(g_DailyTrades) + "/" + IntegerToString(InpMaxDailyTrades));
   int tot = g_DailyWins + g_DailyLosses;
   double wr = (tot > 0) ? ((double)g_DailyWins / tot) * 100.0 : 0.0;
   SetLabel("V_WR", DoubleToString(wr, 0) + "%", (wr >= 60) ? C_GREEN : C_WHITE);
   SetLabel("V_AVG", "$" + DoubleToString(g_AvgWinSize, 0) + "/$" + DoubleToString(g_AvgLossSize, 0));

   // Actual RR ratio
   double actualRR = (g_AvgLossSize > 0) ? g_AvgWinSize / g_AvgLossSize : 0;
   SetLabel("V_RRR", "1:" + DoubleToString(actualRR, 2), (actualRR >= 2.0) ? C_GREEN : C_WHITE);

   if(g_ConsecWins > 1) SetLabel("V_STK", "🔥 ×" + IntegerToString(g_ConsecWins), C_GREEN);
   else if(g_ConsecLosses > 1) SetLabel("V_STK", "❄️ ×" + IntegerToString(g_ConsecLosses), C_RED);
   else SetLabel("V_STK", "—", C_MUTED);

   string regTxt = EnumToString(g_CurrentRegime);
   StringReplace(regTxt, "REGIME_", "");
   StringReplace(regTxt, "_", " ");
   SetLabel("V_REG", regTxt, (g_CurrentRegime == REGIME_TRENDING_STRONG) ? C_GREEN : C_ORANGE);
   SetLabel("V_TRQ", DoubleToString(g_CurrentTrendQuality, 0) + "%");

   double volScore = AnalyzeRecentVolatility();
   SetLabel("V_VOL", (volScore > 0.8) ? "OPTIMAL" : "NORMAL", (volScore > 0.8) ? C_GREEN : C_WHITE);

   int sp = (int)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   SetLabel("V_SPR", IntegerToString(sp) + " pts", IsSpreadOk() ? C_GREEN : C_RED);

   double atr = GetATR();
   SetLabel("V_ATR", DoubleToString(atr, 2));
   SetLabel("V_QUA", DoubleToString(g_TradeQualityScore, 0) + "%", (g_TradeQualityScore >= 70) ? C_GREEN : C_WHITE);

   ENUM_SIGNAL testSig = EvaluateConfluence();
   bool mtfOK = CheckMultiTimeframeAlignment(testSig);
   SetLabel("V_MTF", mtfOK ? "✓" : "✗", mtfOK ? C_GREEN : C_RED);

   double rsi[1], adx[1];
   CopyBuffer(g_hRSI, 0, 0, 1, rsi);
   CopyBuffer(g_hADX, 0, 0, 1, adx);
   SetLabel("V_RSI", DoubleToString(rsi[0], 1));
   SetLabel("V_ADX", DoubleToString(adx[0], 1));

   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   int slPts = (int)MathRound((atr * InpSLMultiplier) / point);
   slPts = MathMax(InpMinSLPoints, MathMin(InpMaxSLPoints, slPts));
   int tp3Pts = (int)MathRound((atr * InpTP3Multiplier) / point);

   double nextLot = CalculateLotSize(slPts, g_TradeQualityScore);
   SetLabel("V_LOT", DoubleToString(nextLot, 2));
   SetLabel("V_SLTP", IntegerToString(slPts) + "/" + IntegerToString(tp3Pts));

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
//| END - ELITE SCALPER v6.0 PRO OPTIMIZED                          |
//+------------------------------------------------------------------+