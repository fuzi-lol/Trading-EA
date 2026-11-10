//+------------------------------------------------------------------+
//|                    THEE EliteScalper v6.1 INTELLIGENCE EDITION   |
//|                                  Copyright 2026, FXBotHub Systems|
//|                                             https://fxbothub.com |
//+------------------------------------------------------------------+
#property copyright   "Copyright 2026, THEE EliteScalper Intelligence"
#property version     "6.10"
#property description "GOLD Intelligence Engine – FIXED Signal System"
#property strict

#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>

#define DASH_PREFIX  "FXBH_V61_"

//+------------------------------------------------------------------+
//| ENUMS                                                            |
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

enum ENUM_MARKET_STRUCTURE
{
   STRUCTURE_BULLISH,
   STRUCTURE_BEARISH,
   STRUCTURE_NEUTRAL
};

//+------------------------------------------------------------------+
//| INPUTS                                                           |
//+------------------------------------------------------------------+
input group "=== CORE IDENTITY ==="
input ulong   InpMagicNumber       = 999556;
input string  InpTradeComment      = "EliteScalper_v6.1_Intelligence";

input group "=== RISK MANAGEMENT ==="
input double  InpRiskPercent       = 1.0;
input double  InpMaxDailyLossPct   = 5.0;
input double  InpMaxDailyProfitPct = 10.0;
input int     InpMaxDailyTrades    = 20;

input group "=== OPTIMIZED SL/TP ==="
input int     InpATRPeriod         = 14;
input double  InpSLMultiplier      = 1.0;
input double  InpTP1Multiplier     = 2.0;
input double  InpTP2Multiplier     = 3.0;
input double  InpTP3Multiplier     = 4.5;
input int     InpMinSLPoints       = 100;
input int     InpMaxSLPoints       = 300;

input group "=== PROFIT PROTECTION ==="
input bool    InpUseReversalProtection = true;
input double  InpMaxProfitDropDollars  = 2.5;
input double  InpMinProfitToProtect    = 0.8;

input group "=== TRADE MANAGEMENT ==="
input int     InpBreakevenPoints   = 70;
input int     InpBreakevenBuffer   = 5;
input bool    InpUseTrailing       = true;
input int     InpTrailStartPoints  = 90;
input int     InpTrailStepPoints   = 25;

input group "=== PARTIAL CLOSE ==="
input bool    InpUsePartialClose   = true;
input double  InpPartialTP1Pct     = 30.0;
input double  InpPartialTP2Pct     = 40.0;

input group "=== ★★★ INTELLIGENT SIGNAL SYSTEM ★★★ ==="
input double  InpSignalThreshold   = 60.0;      // Minimum signal strength (0-100)
input bool    InpUseDynamicThreshold = true;    // Adapt threshold to market conditions
input bool    InpRequireStructureConfirm = false; // Require market structure alignment (set false for more trades)
input bool    InpRequireVolumeConfirm = false;    // Require volume confirmation (set false for more trades)
input int     InpMinConfirmations  = 3;          // Minimum indicator confirmations (out of 8)

input group "=== ★★★ SMART MONEY CONCEPTS ★★★ ==="
input bool    InpUseSMC            = true;
input int     InpOrderBlockBars    = 10;
input bool    InpDetectLiquidityGrab = true;
input int     InpLiquidityLookback = 20;

input group "=== ★★★ VOLUME ANALYSIS ★★★ ==="
input bool    InpUseVolumeAnalysis = true;
input int     InpVolumePeriod      = 20;
input double  InpVolumeThreshold   = 1.2;        // Lowered from 1.3 for more signals

input group "=== ★★★ MARKET STRUCTURE ★★★ ==="
input int     InpStructureBars     = 8;
input bool    InpTradeWithStructure = false;     // Set false to allow more trades

input group "=== ★★★ ADVANCED INDICATORS ★★★ ==="
input int     InpSuperTrendPeriod  = 10;
input double  InpSuperTrendMultiplier = 3.0;
input int     InpVWAPPeriod        = 20;
input bool    InpUseFibLevels      = true;
input int     InpFibLookback       = 50;

input group "=== CONFLUENCE INDICATORS ==="
input int     InpFastEMAPeriod     = 9;
input int     InpSlowEMAPeriod     = 21;
input int     InpTrendEMAPeriod    = 50;
input int     InpRSIPeriod         = 14;
input double  InpRSIOverbought     = 72.0;
input double  InpRSIOversold       = 28.0;
input int     InpADXPeriod         = 14;
input double  InpADXMinStrength    = 20.0;       // Lowered from 22
input int     InpStochPeriod       = 14;
input int     InpStochK            = 3;
input int     InpStochD            = 3;

input group "=== REGIME DETECTION ==="
input bool    InpUseRegimeFilter   = true;
input bool    InpAllowTrendingStrong = true;
input bool    InpAllowTrendingWeak = true;
input bool    InpAllowRanging      = true;      // Changed to true
input bool    InpAllowChoppy       = false;
input int     InpRegimeLookback    = 50;

input group "=== FILTERS ==="
input int     InpCooldownSeconds   = 25;         // Reduced cooldown
input int     InpSpreadMaxPoints   = 35;
input double  InpSpreadMultiplier  = 2.2;
input bool    InpUseSessionFilter  = true;
input int     InpSessionStartGMT   = 7;
input int     InpSessionEndGMT     = 20;

input group "=== DASHBOARD ==="
input int     InpDashX            = 15;
input int     InpDashY            = 15;

//+------------------------------------------------------------------+
//| COLORS                                                           |
//+------------------------------------------------------------------+
const color C_BG          = C'8,12,22';
const color C_PANEL       = C'12,18,32';
const color C_HEADER      = C'18,35,75';
const color C_BORDER      = C'0,100,200';
const color C_BLUE        = C'0,150,255';
const color C_GREEN       = C'0,220,120';
const color C_RED         = C'240,50,70';
const color C_GOLD        = C'255,195,35';
const color C_PURPLE      = C'180,0,255';
const color C_WHITE       = C'240,245,255';
const color C_MUTED       = C'130,145,175';
const color C_ORANGE      = C'255,145,0';
const color C_CYAN        = C'0,210,210';
const color C_DARK        = C'15,20,30';

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
int g_hStoch    = INVALID_HANDLE;

// SuperTrend state
double g_SuperTrendUp = 0.0;
double g_SuperTrendDown = 0.0;
int g_SuperTrendDirection = 0;

ENUM_ENGINE_STATE g_State = STATE_SCANNING;
datetime g_StateTimer = 0;

ENUM_SIGNAL g_PendingSignal = SIGNAL_NONE;
int g_AnalysisTicks = 0;
datetime g_AnalysisStart = 0;

bool g_PartialTP1Closed = false;
bool g_PartialTP2Closed = false;

double g_PeakProfit = 0.0;
bool g_ProfitProtectionActive = false;

datetime g_LastTradeCloseTime = 0;
double g_LastTradePnL = 0.0;
bool g_LastTradeWasWin = false;
datetime g_PostTradeReviewEnd = 0;

double g_CurrentTrendQuality = 0.0;
ENUM_MARKET_REGIME g_CurrentRegime = REGIME_RANGING;
ENUM_MARKET_STRUCTURE g_CurrentStructure = STRUCTURE_NEUTRAL;
double g_SignalStrength = 0.0;
double g_VolumeStrength = 100.0;

datetime g_SessionDay = 0;
int g_DailyTrades = 0;
double g_DailyProfit = 0.0;
int g_DailyWins = 0;
int g_DailyLosses = 0;
int g_ConsecLosses = 0;
int g_ConsecWins = 0;
double g_SessionOpenBal = 0.0;

double g_AvgWinSize = 0.0;
double g_AvgLossSize = 0.0;
double g_ProfitFactor = 0.0;

double g_AvgSpread = 0.0;
int g_SpreadSamples = 0;

double g_LastHighSwing = 0.0;
double g_LastLowSwing = 0.0;
bool g_LiquidityGrabDetected = false;
double g_VWAP = 0.0;
double g_LastStochMain = 50.0;

string g_StatusText = "INITIALIZING";
color g_StatusColor = C_GOLD;
string g_HeartbeatStr = "█ ▓ █ █";

// Indicator values cache
double g_CachedRSI = 50.0;
double g_CachedADX = 0.0;
double g_CachedStoch = 50.0;

//+------------------------------------------------------------------+
//| FORWARD DECLARATIONS                                             |
//+------------------------------------------------------------------+
bool InitIndicators();
void ReleaseIndicators();
void SyncDailyStats();

double GenerateIntelligentSignal(ENUM_SIGNAL &signal);
void UpdateSuperTrend();
bool CheckSuperTrend(ENUM_SIGNAL sig);
void UpdateVWAP();
bool CheckVolumeConfirmation(ENUM_SIGNAL sig);
bool CheckMarketStructure(ENUM_SIGNAL sig);
bool DetectOrderBlock(ENUM_SIGNAL sig);
bool DetectLiquidityGrab(ENUM_SIGNAL sig);
bool CheckStochastic(ENUM_SIGNAL sig);
double GetDynamicThreshold();

bool CheckEMAStack(double &fast, double &slow, double &trend);
bool CheckRSI(ENUM_SIGNAL sig, double &rsiVal);
bool CheckADX(double &adxVal);
double GetATR();

ENUM_MARKET_REGIME DetectMarketRegime(int lookback);
ENUM_MARKET_STRUCTURE AnalyzeMarketStructure();
double AnalyzeTrendQuality(int lookback);
void UpdateMarketContext();

double CalculateLotSize(int slPoints, double qualityMultiplier = 1.0);
void ExecuteEntry(ENUM_SIGNAL sig);
void ManageOpenTrade();
void CheckBreakeven();
void CheckTrailing();
void CheckPartialClose();
void CheckProfitReversalProtection();
void EvaluateFloatingPnL();

bool IsPositionOpen();
double GetFloatingPnL();
void CloseAllPositions(string reason);
bool IsMarketOpen();
bool IsInSession();
bool IsSpreadOk();
void UpdateSpreadAverage();
bool IsDailyLossLimitHit();
bool IsDailyProfitTargetHit();
double GetRiskAdjustedPercent();
datetime GetDayStart(datetime t);

void ProcessAnalysisPhase();
void ProcessPostTradeReview();
void DetectTradeClose();
void OnTradeClose(double pnl, bool wasWin);
void UpdatePerformanceMetrics();

void RenderDashboard();
void UpdateDashboard();
void PurgeDashboard();
void DrawRect(string id, int x, int y, int w, int h, color bg, color border, int bw);
void DrawLabel(string id, int x, int y, string txt, color clr, int sz, string fnt);
void SetLabel(string id, string txt, color clr = clrNONE);

//+------------------------------------------------------------------+
//| INITIALIZATION                                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   if(StringFind(_Symbol, "XAU") < 0 && StringFind(_Symbol, "GOLD") < 0)
      Print("[EliteScalper v6.1] WARNING: Optimised for GOLD");

   g_Trade.SetExpertMagicNumber(InpMagicNumber);
   g_Trade.SetDeviationInPoints(20);
   g_Trade.SetTypeFilling(ORDER_FILLING_FOK);

   if(!InitIndicators()) return INIT_FAILED;

   g_SessionDay = GetDayStart(TimeCurrent());
   g_SessionOpenBal = AccountInfoDouble(ACCOUNT_BALANCE);
   SyncDailyStats();

   // Initialize VWAP
   UpdateVWAP();
   UpdateSuperTrend();

   g_State = STATE_SCANNING;
   EventSetTimer(1);
   RenderDashboard();

   Print("═══════════════════════════════════════════════════════");
   Print("  ELITE SCALPER v6.1 INTELLIGENCE EDITION - FIXED");
   Print("  Signal System: ACTIVE");
   Print("  VWAP: ACTIVE");
   Print("  SuperTrend: ACTIVE");
   Print("  Signal Threshold: ", InpSignalThreshold, "%");
   Print("═══════════════════════════════════════════════════════");
   
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
   string p[4] = {"█ ▓ █ █","▓ █ ▓ ▓","█ █ ▓ █","▓ ▓ █ ▓"};
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
   UpdateMarketContext();

   if(!IsMarketOpen())
   { g_StatusText = "MARKET CLOSED"; g_StatusColor = C_RED; return; }

   if(InpUseSessionFilter && !IsInSession())
   { g_StatusText = "OUT OF SESSION"; g_StatusColor = C_MUTED; return; }

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
      ENUM_SIGNAL sig = SIGNAL_NONE;
      double strength = GenerateIntelligentSignal(sig);
      g_SignalStrength = strength;

      double threshold = GetDynamicThreshold();

      if(sig == SIGNAL_NONE || strength < threshold)
      {
         g_StatusText = "SCANNING | S:" + DoubleToString(strength, 0) + "% | T:" + DoubleToString(threshold, 0) + "%";
         g_StatusColor = C_MUTED;
         return;
      }

      g_State = STATE_ANALYZING;
      g_PendingSignal = sig;
      g_AnalysisStart = TimeCurrent();
      g_AnalysisTicks = 0;
      g_StatusText = (sig==SIGNAL_BUY?"BUY ":"SELL ") + DoubleToString(strength, 0) + "%";
      g_StatusColor = C_PURPLE;
      Print("[SIGNAL] ", (sig==SIGNAL_BUY?"BUY":"SELL"), " Strength=", strength, "% Threshold=", threshold, "%");
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
   g_hFastEMA  = iMA(_Symbol, _Period, InpFastEMAPeriod, 0, MODE_EMA, PRICE_CLOSE);
   g_hSlowEMA  = iMA(_Symbol, _Period, InpSlowEMAPeriod, 0, MODE_EMA, PRICE_CLOSE);
   g_hTrendEMA = iMA(_Symbol, _Period, InpTrendEMAPeriod, 0, MODE_EMA, PRICE_CLOSE);
   g_hRSI      = iRSI(_Symbol, _Period, InpRSIPeriod, PRICE_CLOSE);
   g_hATR      = iATR(_Symbol, _Period, InpATRPeriod);
   g_hADX      = iADX(_Symbol, _Period, InpADXPeriod);
   g_hStoch    = iStochastic(_Symbol, _Period, InpStochPeriod, InpStochK, InpStochD, MODE_SMA, STO_LOWHIGH);

   if(g_hFastEMA==INVALID_HANDLE || g_hSlowEMA==INVALID_HANDLE || g_hTrendEMA==INVALID_HANDLE ||
      g_hRSI==INVALID_HANDLE || g_hATR==INVALID_HANDLE || g_hADX==INVALID_HANDLE || g_hStoch==INVALID_HANDLE)
   {
      Print("[ERROR] Failed to initialize indicators");
      return false;
   }

   return true;
}

void ReleaseIndicators()
{
   if(g_hFastEMA != INVALID_HANDLE) IndicatorRelease(g_hFastEMA);
   if(g_hSlowEMA != INVALID_HANDLE) IndicatorRelease(g_hSlowEMA);
   if(g_hTrendEMA != INVALID_HANDLE) IndicatorRelease(g_hTrendEMA);
   if(g_hRSI != INVALID_HANDLE) IndicatorRelease(g_hRSI);
   if(g_hATR != INVALID_HANDLE) IndicatorRelease(g_hATR);
   if(g_hADX != INVALID_HANDLE) IndicatorRelease(g_hADX);
   if(g_hStoch != INVALID_HANDLE) IndicatorRelease(g_hStoch);
}

//+------------------------------------------------------------------+
//| ★★★ INTELLIGENT SIGNAL GENERATION - FIXED ★★★                  |
//+------------------------------------------------------------------+
double GenerateIntelligentSignal(ENUM_SIGNAL &signal)
{
   signal = SIGNAL_NONE;
   
   // Check regime filter
   if(InpUseRegimeFilter)
   {
      bool regimeOK = false;
      if(g_CurrentRegime == REGIME_TRENDING_STRONG && InpAllowTrendingStrong) regimeOK = true;
      if(g_CurrentRegime == REGIME_TRENDING_WEAK && InpAllowTrendingWeak) regimeOK = true;
      if(g_CurrentRegime == REGIME_RANGING && InpAllowRanging) regimeOK = true;
      if(g_CurrentRegime == REGIME_CHOPPY && InpAllowChoppy) regimeOK = true;
      if(!regimeOK) return 0.0;
   }

   double bullScore = 0.0, bearScore = 0.0;
   int bullConfirm = 0, bearConfirm = 0;

   // Layer 1: Trend Direction (20 pts)
   double fast, slow, trend;
   if(CheckEMAStack(fast, slow, trend))
   {
      if(fast > slow && slow > trend) 
      {
         bullScore += 20.0;
         bullConfirm++;
      }
      else if(fast < slow && slow < trend)
      {
         bearScore += 20.0;
         bearConfirm++;
      }
   }

   // Layer 2: RSI Momentum (15 pts)
   double rsiVal;
   if(CheckRSI(SIGNAL_BUY, rsiVal))
   {
      bullScore += 15.0;
      bullConfirm++;
   }
   else if(CheckRSI(SIGNAL_SELL, rsiVal))
   {
      bearScore += 15.0;
      bearConfirm++;
   }

   // Layer 3: ADX Strength (15 pts)
   double adxVal;
   if(CheckADX(adxVal))
   {
      double adxBonus = MathMin(15.0, (adxVal / InpADXMinStrength) * 15.0);
      if(fast > slow) bullScore += adxBonus;
      else bearScore += adxBonus;
      if(fast > slow) bullConfirm++;
      else bearConfirm++;
   }

   // Layer 4: SuperTrend (15 pts)
   if(CheckSuperTrend(SIGNAL_BUY))
   {
      bullScore += 15.0;
      bullConfirm++;
   }
   else if(CheckSuperTrend(SIGNAL_SELL))
   {
      bearScore += 15.0;
      bearConfirm++;
   }

   // Layer 5: Stochastic (10 pts)
   if(CheckStochastic(SIGNAL_BUY))
   {
      bullScore += 10.0;
      bullConfirm++;
   }
   else if(CheckStochastic(SIGNAL_SELL))
   {
      bearScore += 10.0;
      bearConfirm++;
   }

   // Layer 6: Volume Confirmation (10 pts) - Optional
   if(InpRequireVolumeConfirm && InpUseVolumeAnalysis)
   {
      if(CheckVolumeConfirmation(SIGNAL_BUY))
      {
         bullScore += 10.0;
         bullConfirm++;
      }
      else if(CheckVolumeConfirmation(SIGNAL_SELL))
      {
         bearScore += 10.0;
         bearConfirm++;
      }
   }
   else if(InpUseVolumeAnalysis)
   {
      // Give points even without strict confirmation
      if(g_VWAP > 0)
      {
         double price = iClose(_Symbol, _Period, 0);
         if(price > g_VWAP) { bullScore += 5.0; bullConfirm++; }
         else if(price < g_VWAP) { bearScore += 5.0; bearConfirm++; }
      }
   }

   // Layer 7: Market Structure (10 pts) - Optional
   if(InpRequireStructureConfirm && InpTradeWithStructure)
   {
      if(CheckMarketStructure(SIGNAL_BUY))
      {
         bullScore += 10.0;
         bullConfirm++;
      }
      else if(CheckMarketStructure(SIGNAL_SELL))
      {
         bearScore += 10.0;
         bearConfirm++;
      }
   }
   else
   {
      // Give bonus points based on structure even without strict requirement
      if(g_CurrentStructure == STRUCTURE_BULLISH) { bullScore += 5.0; bullConfirm++; }
      else if(g_CurrentStructure == STRUCTURE_BEARISH) { bearScore += 5.0; bearConfirm++; }
   }

   // Layer 8: Smart Money Concepts (5 pts)
   if(InpUseSMC)
   {
      if(DetectOrderBlock(SIGNAL_BUY))
      {
         bullScore += 5.0;
         bullConfirm++;
      }
      else if(DetectOrderBlock(SIGNAL_SELL))
      {
         bearScore += 5.0;
         bearConfirm++;
      }
   }

   // Check minimum confirmations
   int maxConfirm = MathMax(bullConfirm, bearConfirm);
   if(maxConfirm < InpMinConfirmations)
   {
      Print("[Signal] Insufficient confirmations: ", maxConfirm, " < ", InpMinConfirmations);
      return 0.0;
   }

   // Determine signal
   if(bullScore > bearScore && bullScore >= 40.0)
   {
      signal = SIGNAL_BUY;
      Print("[Signal Breakdown] BUY - Bull:", bullScore, "% Bear:", bearScore, "% Confirms:", bullConfirm);
      return bullScore;
   }
   else if(bearScore > bullScore && bearScore >= 40.0)
   {
      signal = SIGNAL_SELL;
      Print("[Signal Breakdown] SELL - Bull:", bullScore, "% Bear:", bearScore, "% Confirms:", bearConfirm);
      return bearScore;
   }

   return 0.0;
}

//+------------------------------------------------------------------+
//| DYNAMIC THRESHOLD - FIXED                                        |
//+------------------------------------------------------------------+
double GetDynamicThreshold()
{
   if(!InpUseDynamicThreshold)
      return InpSignalThreshold;

   double threshold = InpSignalThreshold;

   // Adjust based on regime
   if(g_CurrentRegime == REGIME_TRENDING_STRONG)
      threshold -= 5.0;
   else if(g_CurrentRegime == REGIME_CHOPPY)
      threshold += 10.0;
   else if(g_CurrentRegime == REGIME_RANGING)
      threshold += 2.0;

   // Adjust based on performance
   if(g_ConsecLosses >= 3)
      threshold += 8.0;
   else if(g_ConsecWins >= 3)
      threshold -= 3.0;

   // Adjust based on trend quality
   if(g_CurrentTrendQuality >= 75.0)
      threshold -= 5.0;
   else if(g_CurrentTrendQuality < 40.0)
      threshold += 8.0;

   return MathMax(50.0, MathMin(80.0, threshold));
}

//+------------------------------------------------------------------+
//| SUPERTREND - FIXED CALCULATION                                   |
//+------------------------------------------------------------------+
void UpdateSuperTrend()
{
   double atr = GetATR();
   if(atr == 0) return;

   double hl2 = (iHigh(_Symbol, _Period, 0) + iLow(_Symbol, _Period, 0)) / 2.0;
   
   double basicUp = hl2 - (InpSuperTrendMultiplier * atr);
   double basicDown = hl2 + (InpSuperTrendMultiplier * atr);
   
   double close = iClose(_Symbol, _Period, 0);
   double prevClose = iClose(_Symbol, _Period, 1);
   
   // Update final bands
   if(g_SuperTrendUp == 0.0 || basicUp > g_SuperTrendUp || prevClose < g_SuperTrendUp)
      g_SuperTrendUp = basicUp;
   else
      g_SuperTrendUp = (g_SuperTrendUp > basicUp) ? g_SuperTrendUp : basicUp;
   
   if(g_SuperTrendDown == 0.0 || basicDown < g_SuperTrendDown || prevClose > g_SuperTrendDown)
      g_SuperTrendDown = basicDown;
   else
      g_SuperTrendDown = (g_SuperTrendDown < basicDown) ? g_SuperTrendDown : basicDown;
   
   // Determine trend
   if(close > g_SuperTrendDown)
      g_SuperTrendDirection = 1; // Bullish
   else if(close < g_SuperTrendUp)
      g_SuperTrendDirection = -1; // Bearish
   // else keep previous direction
}

bool CheckSuperTrend(ENUM_SIGNAL sig)
{
   if(sig == SIGNAL_BUY && g_SuperTrendDirection == 1) return true;
   if(sig == SIGNAL_SELL && g_SuperTrendDirection == -1) return true;
   return false;
}

//+------------------------------------------------------------------+
//| VWAP - FIXED CALCULATION                                         |
//+------------------------------------------------------------------+
void UpdateVWAP()
{
   double sumPV = 0.0, sumV = 0.0;
   
   for(int i = 0; i < InpVWAPPeriod; i++)
   {
      long tickVol = iVolume(_Symbol, _Period, i);
      double typical = (iHigh(_Symbol, _Period, i) + iLow(_Symbol, _Period, i) + iClose(_Symbol, _Period, i)) / 3.0;
      
      sumPV += typical * tickVol;
      sumV += tickVol;
   }
   
   g_VWAP = (sumV > 0) ? sumPV / sumV : 0.0;
}

//+------------------------------------------------------------------+
//| VOLUME CONFIRMATION - FIXED                                      |
//+------------------------------------------------------------------+
bool CheckVolumeConfirmation(ENUM_SIGNAL sig)
{
   if(!InpUseVolumeAnalysis) return true;

   // Calculate average volume
   double volumeSum = 0.0;
   for(int i = 1; i <= InpVolumePeriod; i++)
      volumeSum += (double)iVolume(_Symbol, _Period, i);
   
   double avgVolume = volumeSum / InpVolumePeriod;
   double currentVolume = (double)iVolume(_Symbol, _Period, 0);
   
   g_VolumeStrength = (avgVolume > 0) ? (currentVolume / avgVolume) * 100.0 : 100.0;

   // Check volume spike
   bool volumeOK = (currentVolume >= avgVolume * InpVolumeThreshold);
   
   // Check VWAP alignment
   if(g_VWAP > 0)
   {
      double price = iClose(_Symbol, _Period, 0);
      bool vwapOK = false;
      
      if(sig == SIGNAL_BUY && price > g_VWAP) vwapOK = true;
      if(sig == SIGNAL_SELL && price < g_VWAP) vwapOK = true;
      
      return (volumeOK && vwapOK);
   }
   
   return volumeOK;
}

//+------------------------------------------------------------------+
//| MARKET STRUCTURE - FIXED                                         |
//+------------------------------------------------------------------+
ENUM_MARKET_STRUCTURE AnalyzeMarketStructure()
{
   int lookback = InpStructureBars * 3;
   MqlRates rates[];
   
   if(CopyRates(_Symbol, _Period, 0, lookback, rates) < lookback)
      return STRUCTURE_NEUTRAL;

   int higherHighs = 0, lowerLows = 0;
   double lastHigh = 0, lastLow = 999999;
   
   for(int i = InpStructureBars; i < lookback - InpStructureBars; i++)
   {
      bool isSwingHigh = true;
      bool isSwingLow = true;
      
      for(int j = 1; j <= InpStructureBars; j++)
      {
         if(rates[i].high <= rates[i-j].high || rates[i].high <= rates[i+j].high)
            isSwingHigh = false;
         if(rates[i].low >= rates[i-j].low || rates[i].low >= rates[i+j].low)
            isSwingLow = false;
      }
      
      if(isSwingHigh)
      {
         if(rates[i].high > lastHigh && lastHigh > 0) higherHighs++;
         lastHigh = rates[i].high;
         g_LastHighSwing = rates[i].high;
      }
      
      if(isSwingLow)
      {
         if(rates[i].low < lastLow && lastLow < 999999) lowerLows++;
         lastLow = rates[i].low;
         g_LastLowSwing = rates[i].low;
      }
   }

   if(higherHighs >= 2 && lowerLows <= 1) return STRUCTURE_BULLISH;
   if(lowerLows >= 2 && higherHighs <= 1) return STRUCTURE_BEARISH;
   return STRUCTURE_NEUTRAL;
}

bool CheckMarketStructure(ENUM_SIGNAL sig)
{
   if(!InpTradeWithStructure) return true;
   if(sig == SIGNAL_BUY && g_CurrentStructure == STRUCTURE_BULLISH) return true;
   if(sig == SIGNAL_SELL && g_CurrentStructure == STRUCTURE_BEARISH) return true;
   return false;
}

//+------------------------------------------------------------------+
//| SMART MONEY CONCEPTS - FIXED                                     |
//+------------------------------------------------------------------+
bool DetectOrderBlock(ENUM_SIGNAL sig)
{
   if(!InpUseSMC) return true;

   MqlRates rates[];
   if(CopyRates(_Symbol, _Period, 0, InpOrderBlockBars + 5, rates) < InpOrderBlockBars + 5)
      return false;

   for(int i = 2; i < InpOrderBlockBars; i++)
   {
      double body = MathAbs(rates[i].close - rates[i].open);
      double range = rates[i].high - rates[i].low;
      
      if(range == 0) continue;
      
      double bodyRatio = body / range;
      
      if(sig == SIGNAL_BUY && rates[i].close > rates[i].open && bodyRatio > 0.55)
      {
         double orderBlockHigh = rates[i].high;
         double currentPrice = rates[0].close;
         if(currentPrice > orderBlockHigh * 0.997) return true;
      }
      
      if(sig == SIGNAL_SELL && rates[i].close < rates[i].open && bodyRatio > 0.55)
      {
         double orderBlockLow = rates[i].low;
         double currentPrice = rates[0].close;
         if(currentPrice < orderBlockLow * 1.003) return true;
      }
   }
   
   return false;
}

bool DetectLiquidityGrab(ENUM_SIGNAL sig)
{
   if(!InpDetectLiquidityGrab) return false;

   MqlRates rates[];
   if(CopyRates(_Symbol, _Period, 0, 5, rates) < 5) return false;

   double prevLow = rates[1].low;
   double prevHigh = rates[1].high;
   double currentLow = rates[0].low;
   double currentHigh = rates[0].high;
   
   if(sig == SIGNAL_BUY)
   {
      if(g_LastLowSwing > 0 && prevLow < g_LastLowSwing && currentLow > g_LastLowSwing)
      {
         g_LiquidityGrabDetected = true;
         return true;
      }
   }
   
   if(sig == SIGNAL_SELL)
   {
      if(g_LastHighSwing > 0 && prevHigh > g_LastHighSwing && currentHigh < g_LastHighSwing)
      {
         g_LiquidityGrabDetected = true;
         return true;
      }
   }
   
   g_LiquidityGrabDetected = false;
   return false;
}

//+------------------------------------------------------------------+
//| STOCHASTIC - FIXED                                               |
//+------------------------------------------------------------------+
bool CheckStochastic(ENUM_SIGNAL sig)
{
   double main[2], signal[2];
   
   if(CopyBuffer(g_hStoch, 0, 0, 2, main) <= 0) return false;
   if(CopyBuffer(g_hStoch, 1, 0, 2, signal) <= 0) return false;

   g_CachedStoch = main[0];

   if(sig == SIGNAL_BUY)
   {
      // Bullish: crossing up in oversold or just crossed up
      if((main[0] < 35 && main[0] > signal[0]) || (main[1] < main[0] && main[0] > 50)) 
         return true;
   }
   else if(sig == SIGNAL_SELL)
   {
      // Bearish: crossing down in overbought or just crossed down
      if((main[0] > 65 && main[0] < signal[0]) || (main[1] > main[0] && main[0] < 50)) 
         return true;
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| CLASSIC INDICATORS - FIXED                                       |
//+------------------------------------------------------------------+
bool CheckEMAStack(double &fast, double &slow, double &trend)
{
   double f[1], s[1], t[1];
   if(CopyBuffer(g_hFastEMA, 0, 0, 1, f) <= 0) return false;
   if(CopyBuffer(g_hSlowEMA, 0, 0, 1, s) <= 0) return false;
   if(CopyBuffer(g_hTrendEMA, 0, 0, 1, t) <= 0) return false;
   fast = f[0]; slow = s[0]; trend = t[0];
   return ((fast > slow && slow > trend) || (fast < slow && slow < trend));
}

bool CheckRSI(ENUM_SIGNAL sig, double &rsiVal)
{
   double r[1];
   if(CopyBuffer(g_hRSI, 0, 0, 1, r) <= 0) return false;
   rsiVal = r[0];
   g_CachedRSI = rsiVal;
   
   if(sig == SIGNAL_BUY) return (rsiVal > 40.0 && rsiVal < InpRSIOverbought);
   if(sig == SIGNAL_SELL) return (rsiVal < 60.0 && rsiVal > InpRSIOversold);
   return false;
}

bool CheckADX(double &adxVal)
{
   double adx[1];
   if(CopyBuffer(g_hADX, 0, 0, 1, adx) <= 0) return false;
   adxVal = adx[0];
   g_CachedADX = adxVal;
   return (adxVal >= InpADXMinStrength);
}

double GetATR()
{
   double atr[1];
   if(CopyBuffer(g_hATR, 0, 0, 1, atr) <= 0) return 0.0;
   return atr[0];
}

//+------------------------------------------------------------------+
//| MARKET CONTEXT UPDATE - FIXED                                    |
//+------------------------------------------------------------------+
void UpdateMarketContext()
{
   g_CurrentTrendQuality = AnalyzeTrendQuality(20);
   g_CurrentRegime = DetectMarketRegime(InpRegimeLookback);
   g_CurrentStructure = AnalyzeMarketStructure();
   
   UpdateVWAP();
   UpdateSuperTrend();
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
         score += MathMin(40.0, separation * 4.0);
      }
   }
   
   double adx[1];
   if(CopyBuffer(g_hADX, 0, 0, 1, adx) > 0)
      score += MathMin(30.0, adx[0] * 0.75);
   
   if(g_CurrentStructure != STRUCTURE_NEUTRAL)
      score += 30.0;
   
   return MathMin(100.0, score);
}

ENUM_MARKET_REGIME DetectMarketRegime(int lookback)
{
   MqlRates rates[];
   if(CopyRates(_Symbol, _Period, 0, lookback, rates) < lookback)
      return REGIME_CHOPPY;
   
   double highest = rates[0].high, lowest = rates[0].low;
   for(int i = 1; i < lookback; i++)
   {
      if(rates[i].high > highest) highest = rates[i].high;
      if(rates[i].low < lowest) lowest = rates[i].low;
   }
   
   double range = highest - lowest;
   double priceMove = MathAbs(rates[lookback-1].close - rates[0].close);
   double trendRatio = (range > 0) ? priceMove / range : 0;
   
   double adx[1];
   bool adxOk = (CopyBuffer(g_hADX, 0, 0, 1, adx) > 0);
   
   if(adxOk && adx[0] > 30.0 && trendRatio > 0.6)
      return REGIME_TRENDING_STRONG;
   else if(adxOk && adx[0] > 20.0 && trendRatio > 0.35)
      return REGIME_TRENDING_WEAK;
   else if(trendRatio < 0.25)
      return REGIME_CHOPPY;
   
   return REGIME_RANGING;
}

//+------------------------------------------------------------------+
//| TRADE EXECUTION & MANAGEMENT                                     |
//+------------------------------------------------------------------+
void ProcessAnalysisPhase()
{
   g_AnalysisTicks++;
   int elapsed = (int)(TimeCurrent() - g_AnalysisStart);

   if(elapsed > 45)
   { g_State = STATE_SCANNING; return; }

   ENUM_SIGNAL current = SIGNAL_NONE;
   double strength = GenerateIntelligentSignal(current);
   
   if(current != g_PendingSignal || strength < GetDynamicThreshold())
   { 
      Print("[Analysis] Signal changed or weakened");
      g_State = STATE_SCANNING; 
      return; 
   }

   if(elapsed >= 3 && g_AnalysisTicks >= 10)
   {
      ExecuteEntry(g_PendingSignal);
      g_State = STATE_SCANNING;
   }
}

void ExecuteEntry(ENUM_SIGNAL sig)
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

   double lot = CalculateLotSize(slPoints, g_SignalStrength);

   Print("[ENTRY] ", (sig==SIGNAL_BUY?"BUY":"SELL"),
         " Strength=", g_SignalStrength, "%",
         " Lot=", lot,
         " RR=1:", DoubleToString((double)tp3Points / slPoints, 1));

   bool ok = (sig == SIGNAL_BUY) ? g_Trade.Buy(lot, _Symbol, price, sl, tp, InpTradeComment)
                                 : g_Trade.Sell(lot, _Symbol, price, sl, tp, InpTradeComment);
   if(ok)
   {
      g_DailyTrades++;
      g_PartialTP1Closed = false;
      g_PartialTP2Closed = false;
      g_PeakProfit = 0.0;
      g_ProfitProtectionActive = false;
      g_StatusText = (sig==SIGNAL_BUY) ? "LONG ACTIVE" : "SHORT ACTIVE";
      g_StatusColor = C_GREEN;
   }
}

void ManageOpenTrade()
{
   if(!IsPositionOpen()) return;
   CheckProfitReversalProtection();
   CheckPartialClose();
   CheckBreakeven();
   if(InpUseTrailing) CheckTrailing();
   EvaluateFloatingPnL();

   double pnl = GetFloatingPnL();
   g_StatusText = "IN TRADE | " + (pnl >= 0 ? "+$" : "-$") + DoubleToString(MathAbs(pnl), 2);
   g_StatusColor = (pnl >= 0) ? C_GREEN : C_RED;
}

void CheckProfitReversalProtection()
{
   if(!InpUseReversalProtection) return;
   double currentPnL = GetFloatingPnL();
   if(currentPnL > g_PeakProfit) g_PeakProfit = currentPnL;
   if(g_PeakProfit >= InpMinProfitToProtect) g_ProfitProtectionActive = true;
   if(g_ProfitProtectionActive)
   {
      double profitDrop = g_PeakProfit - currentPnL;
      if(profitDrop >= InpMaxProfitDropDollars)
      {
         Print("[PROFIT LOCK] Peak=$", g_PeakProfit, " Current=$", currentPnL);
         CloseAllPositions("Profit reversal protection");
      }
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
      double atr = GetATR();
      double profitPts = isBuy ? (bid - open)/point : (open - ask)/point;
      double tp1Pts = (atr * InpTP1Multiplier) / point;
      double tp2Pts = (atr * InpTP2Multiplier) / point;
      if(!g_PartialTP1Closed && profitPts >= tp1Pts)
      {
         double closeLot = NormalizeDouble(g_Pos.Volume() * (InpPartialTP1Pct / 100.0),
                            (int)MathLog10(1.0/SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP)));
         if(closeLot >= SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN))
         {
            if(g_Trade.PositionClosePartial(g_Pos.Ticket(), closeLot))
            {
               g_PartialTP1Closed = true;
               Print("[TP1] ", InpPartialTP1Pct, "%");
            }
         }
      }
      if(!g_PartialTP2Closed && profitPts >= tp2Pts)
      {
         double closeLot = NormalizeDouble(g_Pos.Volume() * (InpPartialTP2Pct / (100.0 - InpPartialTP1Pct)),
                            (int)MathLog10(1.0/SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP)));
         if(closeLot >= SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN))
         {
            if(g_Trade.PositionClosePartial(g_Pos.Ticket(), closeLot))
            {
               g_PartialTP2Closed = true;
               Print("[TP2] ", InpPartialTP2Pct, "%");
            }
         }
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

double CalculateLotSize(int slPoints, double qualityMultiplier = 1.0)
{
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double riskPct = GetRiskAdjustedPercent();
   if(qualityMultiplier > 0 && qualityMultiplier < 100.0)
      riskPct *= (qualityMultiplier / 100.0);
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
   if(g_ConsecLosses >= 3) pct *= 0.5;
   else if(g_ConsecWins >= 5) pct = MathMin(pct * 1.2, 2.0);
   return pct;
}

//+------------------------------------------------------------------+
//| UTILITY FUNCTIONS                                                |
//+------------------------------------------------------------------+
void ProcessPostTradeReview()
{
   int remaining = (int)(g_PostTradeReviewEnd - TimeCurrent());
   if(remaining > 0)
   {
      g_StatusText = "POST-ANALYSIS " + IntegerToString(remaining) + "s";
      g_StatusColor = C_CYAN;
   }
   else g_State = STATE_SCANNING;
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
   Print("[CLOSED] PnL=$", pnl, " Result=", (wasWin?"WIN":"LOSS"));
   g_StateTimer = TimeCurrent() + InpCooldownSeconds;
   g_State = STATE_COOLDOWN;
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
//| ★★★ PREMIUM COMPACT DASHBOARD - 600×520px ★★★                  |
//+------------------------------------------------------------------+
void RenderDashboard()
{
   int X = InpDashX, Y = InpDashY;
   int W = 600, H = 520;

   DrawRect("BG", X, Y, W, H, C_BG, C_BORDER, 3);
   DrawRect("HDR", X+3, Y+3, W-6, 65, C_HEADER, C_BLUE, 2);
   DrawRect("HDR_ACC", X+3, Y+3, 5, 65, C_GOLD, clrNONE, 0);
   
   DrawLabel("T1", X+16, Y+10, "⬡ ELITE SCALPER", C_GOLD, 18, "Impact");
   DrawLabel("T2", X+16, Y+32, "INTELLIGENCE EDITION", C_WHITE, 10, "Arial Black");
   DrawLabel("T3", X+16, Y+50, "v6.1 FIXED | Smart Money • Volume • Structure", C_CYAN, 7, "Arial");
   
   DrawRect("LIVE_BG", X+W-140, Y+8, 130, 50, C_DARK, C_GOLD, 1);
   DrawLabel("LIVE_SYM", X+W-130, Y+16, _Symbol, C_GOLD, 14, "Impact");
   DrawRect("LIVE_DOT", X+W-130, Y+36, 8, 8, C_GREEN, clrNONE, 0);
   DrawLabel("LIVE_TXT", X+W-118, Y+34, "INTELLIGENCE", C_GREEN, 7, "Arial Black");

   int SB = Y+73;
   DrawRect("SB", X+3, SB, W-6, 24, C_PANEL, clrNONE, 0);
   DrawLabel("SB_L", X+10, SB+7, "⚡ ENGINE:", C_GOLD, 8, "Arial Black");
   DrawLabel("SB_V", X+100, SB+7, "READY", C_BLUE, 8, "Consolas Bold");
   DrawLabel("SB_P", X+W-100, SB+7, "█ ▓ █ █", C_CYAN, 8, "Consolas");

   int C1X = X+6;
   int C2X = X+306;
   int CW = 288;
   int RY = SB+30;

   DrawRect("P1", C1X, RY, CW, 135, C_PANEL, C_BLUE, 1);
   DrawRect("P1H", C1X+2, RY+2, CW-4, 22, C_HEADER, clrNONE, 0);
   DrawLabel("P1T", C1X+8, RY+6, "💰 ACCOUNT", C_GOLD, 9, "Arial Black");
   
   int P1Y = RY+28;
   DrawLabel("L_BAL", C1X+10, P1Y, "Balance:", C_MUTED, 8, "Arial");
   DrawLabel("V_BAL", C1X+180, P1Y, "$0", C_WHITE, 9, "Arial Bold");
   DrawLabel("L_EQ", C1X+10, P1Y+20, "Equity:", C_MUTED, 8, "Arial");
   DrawLabel("V_EQ", C1X+180, P1Y+20, "$0", C_WHITE, 9, "Arial Bold");
   DrawLabel("L_DP", C1X+10, P1Y+40, "Daily P&L:", C_MUTED, 8, "Arial");
   DrawLabel("V_DP", C1X+180, P1Y+40, "$0", C_GREEN, 10, "Arial Black");
   DrawLabel("L_FP", C1X+10, P1Y+60, "Float P&L:", C_MUTED, 8, "Arial");
   DrawLabel("V_FP", C1X+180, P1Y+60, "$0", C_GREEN, 10, "Arial Black");
   DrawLabel("L_PEAK", C1X+10, P1Y+80, "Peak $:", C_MUTED, 8, "Arial");
   DrawLabel("V_PEAK", C1X+180, P1Y+80, "$0", C_CYAN, 9, "Arial Bold");

   RY += 140;
   DrawRect("P2", C1X, RY, CW, 110, C_PANEL, C_GREEN, 1);
   DrawRect("P2H", C1X+2, RY+2, CW-4, 22, C_HEADER, clrNONE, 0);
   DrawLabel("P2T", C1X+8, RY+6, "📊 PERFORMANCE", C_GOLD, 9, "Arial Black");
   
   int P2Y = RY+28;
   DrawLabel("L_TR", C1X+10, P2Y, "Trades:", C_MUTED, 8, "Arial");
   DrawLabel("V_TR", C1X+180, P2Y, "0/20", C_WHITE, 9, "Arial Bold");
   DrawLabel("L_WR", C1X+10, P2Y+20, "Win Rate:", C_MUTED, 8, "Arial");
   DrawLabel("V_WR", C1X+180, P2Y+20, "0%", C_WHITE, 9, "Arial Bold");
   DrawLabel("L_PF", C1X+10, P2Y+40, "Profit Factor:", C_MUTED, 8, "Arial");
   DrawLabel("V_PF", C1X+180, P2Y+40, "0.00", C_WHITE, 9, "Arial Bold");
   DrawLabel("L_RR", C1X+10, P2Y+60, "Actual RR:", C_MUTED, 8, "Arial");
   DrawLabel("V_RR", C1X+180, P2Y+60, "1:0", C_WHITE, 9, "Arial Bold");

   RY += 115;
   DrawRect("P3", C1X, RY, CW, 85, C_PANEL, C_PURPLE, 1);
   DrawRect("P3H", C1X+2, RY+2, CW-4, 22, C_HEADER, clrNONE, 0);
   DrawLabel("P3T", C1X+8, RY+6, "⚙️ EXECUTION", C_GOLD, 9, "Arial Black");
   
   int P3Y = RY+28;
   DrawLabel("L_LOT", C1X+10, P3Y, "Next Lot:", C_MUTED, 8, "Arial");
   DrawLabel("V_LOT", C1X+180, P3Y, "0.01", C_CYAN, 9, "Arial Bold");
   DrawLabel("L_SLTP", C1X+10, P3Y+20, "SL/TP pts:", C_MUTED, 8, "Arial");
   DrawLabel("V_SLTP", C1X+180, P3Y+20, "0/0", C_WHITE, 8, "Arial Bold");
   DrawLabel("L_SPR", C1X+10, P3Y+40, "Spread:", C_MUTED, 8, "Arial");
   DrawLabel("V_SPR", C1X+180, P3Y+40, "0 pts", C_WHITE, 8, "Arial Bold");

   RY = SB+30;
   DrawRect("P4", C2X, RY, CW, 155, C_PANEL, C_ORANGE, 1);
   DrawRect("P4H", C2X+2, RY+2, CW-4, 22, C_HEADER, clrNONE, 0);
   DrawLabel("P4T", C2X+8, RY+6, "🧠 INTELLIGENCE", C_GOLD, 9, "Arial Black");
   
   int P4Y = RY+28;
   DrawLabel("L_SIG", C2X+10, P4Y, "Signal Strength:", C_MUTED, 8, "Arial");
   DrawLabel("V_SIG", C2X+160, P4Y, "0%", C_WHITE, 9, "Arial Bold");
   DrawRect("BAR_SIG_BG", C2X+10, P4Y+18, 268, 6, C_DARK, C_MUTED, 1);
   DrawRect("BAR_SIG", C2X+11, P4Y+19, 1, 4, C_BLUE, clrNONE, 0);
   
   DrawLabel("L_THR", C2X+10, P4Y+32, "Threshold:", C_MUTED, 8, "Arial");
   DrawLabel("V_THR", C2X+160, P4Y+32, "60%", C_GOLD, 8, "Arial Bold");
   
   DrawLabel("L_REG", C2X+10, P4Y+50, "Regime:", C_MUTED, 8, "Arial");
   DrawLabel("V_REG", C2X+160, P4Y+50, "DETECTING", C_WHITE, 8, "Arial Bold");
   
   DrawLabel("L_STR", C2X+10, P4Y+68, "Structure:", C_MUTED, 8, "Arial");
   DrawLabel("V_STR", C2X+160, P4Y+68, "NEUTRAL", C_WHITE, 8, "Arial Bold");
   
   DrawLabel("L_TRQ", C2X+10, P4Y+86, "Trend Quality:", C_MUTED, 8, "Arial");
   DrawLabel("V_TRQ", C2X+160, P4Y+86, "0%", C_WHITE, 8, "Arial Bold");
   
   DrawLabel("L_VOL", C2X+10, P4Y+104, "Volume:", C_MUTED, 8, "Arial");
   DrawLabel("V_VOL", C2X+160, P4Y+104, "100%", C_WHITE, 8, "Arial Bold");

   RY += 160;
   DrawRect("P5", C2X, RY, CW, 135, C_PANEL, C_CYAN, 1);
   DrawRect("P5H", C2X+2, RY+2, CW-4, 22, C_HEADER, clrNONE, 0);
   DrawLabel("P5T", C2X+8, RY+6, "📡 INDICATORS", C_GOLD, 9, "Arial Black");
   
   int P5Y = RY+28;
   DrawLabel("L_RSI", C2X+10, P5Y, "RSI:", C_MUTED, 8, "Arial");
   DrawLabel("V_RSI", C2X+160, P5Y, "50", C_WHITE, 8, "Arial Bold");
   
   DrawLabel("L_ADX", C2X+10, P5Y+20, "ADX:", C_MUTED, 8, "Arial");
   DrawLabel("V_ADX", C2X+160, P5Y+20, "0", C_WHITE, 8, "Arial Bold");
   
   DrawLabel("L_STOCH", C2X+10, P5Y+40, "Stochastic:", C_MUTED, 8, "Arial");
   DrawLabel("V_STOCH", C2X+160, P5Y+40, "50", C_WHITE, 8, "Arial Bold");
   
   DrawLabel("L_VWAP", C2X+10, P5Y+60, "VWAP:", C_MUTED, 8, "Arial");
   DrawLabel("V_VWAP", C2X+160, P5Y+60, "0.00", C_WHITE, 8, "Arial Bold");
   
   DrawLabel("L_ST", C2X+10, P5Y+80, "SuperTrend:", C_MUTED, 8, "Arial");
   DrawLabel("V_ST", C2X+160, P5Y+80, "●", C_GOLD, 10, "Arial Black");

   RY += 140;
   DrawRect("P6", C2X, RY, CW, 60, C_PANEL, C_RED, 1);
   DrawRect("P6H", C2X+2, RY+2, CW-4, 22, C_HEADER, clrNONE, 0);
   DrawLabel("P6T", C2X+8, RY+6, "🔥 STATUS", C_GOLD, 9, "Arial Black");
   
   int P6Y = RY+28;
   DrawLabel("L_MODE", C2X+10, P6Y, "Mode:", C_MUTED, 8, "Arial");
   DrawLabel("V_MODE", C2X+70, P6Y, "SCANNING", C_BLUE, 9, "Arial Black");

   DrawRect("FTR", X+3, Y+H-22, W-6, 19, C_HEADER, clrNONE, 0);
   DrawLabel("F1", X+10, Y+H-16, "Intelligence System FIXED • Real-time Signal Generation", C_MUTED, 6, "Arial");
   DrawLabel("F2", X+W-100, Y+H-16, "v6.1 INTEL", C_CYAN, 7, "Arial Black");

   ChartRedraw(0);
}

void UpdateDashboard()
{
   SetLabel("SB_V", g_StatusText, g_StatusColor);
   SetLabel("SB_P", g_HeartbeatStr, C_CYAN);

   double bal = AccountInfoDouble(ACCOUNT_BALANCE);
   double eq = AccountInfoDouble(ACCOUNT_EQUITY);
   double fpl = GetFloatingPnL();

   SetLabel("V_BAL", "$" + DoubleToString(bal, 2));
   SetLabel("V_EQ", "$" + DoubleToString(eq, 2));
   SetLabel("V_DP", (g_DailyProfit >= 0 ? "+$" : "-$") + DoubleToString(MathAbs(g_DailyProfit), 2), (g_DailyProfit >= 0) ? C_GREEN : C_RED);
   SetLabel("V_FP", (fpl >= 0 ? "+$" : "-$") + DoubleToString(MathAbs(fpl), 2), (fpl >= 0) ? C_GREEN : C_RED);
   SetLabel("V_PEAK", "$" + DoubleToString(g_PeakProfit, 2), C_CYAN);

   SetLabel("V_TR", IntegerToString(g_DailyTrades) + "/" + IntegerToString(InpMaxDailyTrades));
   int tot = g_DailyWins + g_DailyLosses;
   double wr = (tot > 0) ? ((double)g_DailyWins / tot) * 100.0 : 0.0;
   SetLabel("V_WR", DoubleToString(wr, 0) + "%", (wr >= 60) ? C_GREEN : C_WHITE);
   SetLabel("V_PF", DoubleToString(g_ProfitFactor, 2), (g_ProfitFactor >= 1.5) ? C_GREEN : C_WHITE);
   
   double actualRR = (g_AvgLossSize > 0) ? g_AvgWinSize / g_AvgLossSize : 0;
   SetLabel("V_RR", "1:" + DoubleToString(actualRR, 1), (actualRR >= 2.0) ? C_GREEN : C_WHITE);

   double atr = GetATR();
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   int slPts = (int)MathRound((atr * InpSLMultiplier) / point);
   slPts = MathMax(InpMinSLPoints, MathMin(InpMaxSLPoints, slPts));
   int tp3Pts = (int)MathRound((atr * InpTP3Multiplier) / point);

   double nextLot = CalculateLotSize(slPts, g_SignalStrength);
   SetLabel("V_LOT", DoubleToString(nextLot, 2));
   SetLabel("V_SLTP", IntegerToString(slPts) + "/" + IntegerToString(tp3Pts));

   int sp = (int)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   SetLabel("V_SPR", IntegerToString(sp) + " pts", IsSpreadOk() ? C_GREEN : C_RED);

   color sigCol = (g_SignalStrength >= 75) ? C_GREEN : (g_SignalStrength >= 60) ? C_GOLD : C_RED;
   SetLabel("V_SIG", DoubleToString(g_SignalStrength, 0) + "%", sigCol);
   
   int C2X = InpDashX + 306;
   int P4Y_BASE = InpDashY + 73 + 30 + 28;
   int barWidth = (int)((g_SignalStrength / 100.0) * 266);
   DrawRect("BAR_SIG", C2X+11, P4Y_BASE+19, barWidth, 4, sigCol, clrNONE, 0);
   
   double dynThreshold = GetDynamicThreshold();
   SetLabel("V_THR", DoubleToString(dynThreshold, 0) + "%", C_GOLD);

   string regTxt = EnumToString(g_CurrentRegime);
   StringReplace(regTxt, "REGIME_", "");
   StringReplace(regTxt, "_", " ");
   SetLabel("V_REG", regTxt, (g_CurrentRegime == REGIME_TRENDING_STRONG) ? C_GREEN : C_ORANGE);

   string strTxt = EnumToString(g_CurrentStructure);
   StringReplace(strTxt, "STRUCTURE_", "");
   SetLabel("V_STR", strTxt, (g_CurrentStructure == STRUCTURE_BULLISH) ? C_GREEN : (g_CurrentStructure == STRUCTURE_BEARISH) ? C_RED : C_MUTED);

   SetLabel("V_TRQ", DoubleToString(g_CurrentTrendQuality, 0) + "%", (g_CurrentTrendQuality >= 70) ? C_GREEN : C_WHITE);
   SetLabel("V_VOL", DoubleToString(g_VolumeStrength, 0) + "%", (g_VolumeStrength >= 130) ? C_GREEN : C_WHITE);

   SetLabel("V_RSI", DoubleToString(g_CachedRSI, 1));
   SetLabel("V_ADX", DoubleToString(g_CachedADX, 1), (g_CachedADX >= InpADXMinStrength) ? C_GREEN : C_WHITE);
   SetLabel("V_STOCH", DoubleToString(g_CachedStoch, 1));
   SetLabel("V_VWAP", DoubleToString(g_VWAP, 2));
   
   string stTxt = (g_SuperTrendDirection == 1) ? "● BULL" : (g_SuperTrendDirection == -1) ? "● BEAR" : "● NEUTRAL";
   color stCol = (g_SuperTrendDirection == 1) ? C_GREEN : (g_SuperTrendDirection == -1) ? C_RED : C_GOLD;
   SetLabel("V_ST", stTxt, stCol);

   SetLabel("V_MODE", g_StatusText, g_StatusColor);

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
//| END - ELITE SCALPER v6.1 INTELLIGENCE EDITION - FIXED            |
//+------------------------------------------------------------------+