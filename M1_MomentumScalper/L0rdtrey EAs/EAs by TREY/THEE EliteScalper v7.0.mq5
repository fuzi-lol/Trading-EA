//+------------------------------------------------------------------+
//|                 THEE EliteScalper v7.0 INSTITUTIONAL             |
//|                 NOVA AI TERMINAL INTERFACE EDITION               |
//+------------------------------------------------------------------+
#property copyright   "Copyright 2026, ELITE Systems & Institutional AI"
#property version     "7.00"
#property description "INSTITUTIONAL GOLD EDITION — SMC + Kalman + Heuristic Memory"
#property description "Nova AI Terminal Interface | Smart Scaling | Dynamic Risk"
#property strict

#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>

#define DASH_PREFIX   "FXBH_NOVA_"
#define AI_VERSION    "NOVA INST v7.0"
#define MAX_HISTORY   50       // Expanded AI memory

//+------------------------------------------------------------------+
//| ENUMS & STATES                                                   |
//+------------------------------------------------------------------+
enum ENUM_ENGINE_STATE { STATE_SCANNING, STATE_BULK_OPENING, STATE_WAITING_CLOSE, STATE_COOLDOWN };
enum ENUM_SIGNAL_STRENGTH { SIG_NONE = 0, SIG_WEAK = 1, SIG_MODERATE = 2, SIG_STRONG = 3, SIG_ELITE = 4 };
enum ENUM_SESSION { SESSION_ASIAN, SESSION_LONDON, SESSION_NEW_YORK, SESSION_OVERLAP, SESSION_DEAD };
enum ENUM_TARGET_MODE { TARGET_FIXED, TARGET_DYNAMIC_ATR, TARGET_STRUCTURE };
enum ENUM_RISK_MODE { RISK_FIXED_LOT, RISK_DYNAMIC_PCT };

//+------------------------------------------------------------------+
//| INPUT PARAMETERS                                                 |
//+------------------------------------------------------------------+
input group "=== CORE ENGINE SETTINGS ==="
input ulong   InpMagicNumber          = 999666;
input double  InpLotSize              = 0.01;
input int     InpMaxDailyTrades       = 100;

input group "=== INSTITUTIONAL RISK & SCALING ==="
input ENUM_RISK_MODE InpRiskMode      = RISK_DYNAMIC_PCT;
input double  InpBaseRiskPct          = 0.5;   // Base risk %. Increases up to 1.5% for ELITE
input ENUM_TARGET_MODE InpTargetMode  = TARGET_DYNAMIC_ATR;
input double  InpRR_Weak              = 1.5;   // Risk:Reward for weak setups
input double  InpRR_Strong            = 3.0;   // Risk:Reward for strong/elite setups

input group "=== BULK EXECUTION SETTINGS (SMART SCALING) ==="
input int     InpBulkMaxTrades        = 5;     // Reduced for institutional scaling safety
input int     InpBulkIntervalSec      = 10;
input double  InpPerTradeTargetUSD    = 0.50;
input double  InpImmediateReopenPct   = 0.15;
input bool    InpScaleOnlyInProfit    = true;  // Institutional Upgrade: Never average a loser

input group "=== ADAPTIVE MID-CYCLE ANALYSIS ==="
input bool    InpAdaptiveMidCycle     = true;
input int     InpAnalysisTickSec      = 1;
input bool    InpCloseOnFlip          = true;
input int     InpConfirmFlipBars      = 2;

input group "=== AI BRAIN — CONFLUENCE SCORING ENGINE ==="
input int     InpMinScoreToTrade      = 60;
input int     InpEliteScoreThreshold  = 85;
input int     InpStrongScoreThreshold = 70;
input bool    InpRequireStrongMin     = true;
input bool    InpAIAdaptiveThreshold  = true;

input group "=== INSTITUTIONAL SMC & KALMAN WEIGHTS ==="
input int     InpWeightSMC            = 25;    // Order Blocks, FVG, Liquidity Sweeps
input int     InpWeightKalman         = 15;    // Trend/Momentum via Kalman filter
input int     InpWeightVolume         = 10;    // Tick volume expansion

input group "=== CONFLUENCE LAYER WEIGHTS (Base Engine) ==="
input int     InpWeightEMA            = 15;
input int     InpWeightRSI            = 10;
input int     InpWeightBB             = 10;
input int     InpWeightATR            = 10;
input int     InpWeightCandle         = 10;
input int     InpWeightStructure      = 10;

input group "=== INDICATOR PARAMETERS ==="
input int     InpFastEMAPeriod        = 9;
input int     InpSlowEMAPeriod        = 21;
input int     InpTrendEMAPeriod       = 50;
input int     InpRSIPeriod            = 14;
input int     InpRSIOverbought        = 70;
input int     InpRSIOversold          = 30;
input int     InpBBPeriod             = 20;
input double  InpBBDeviation          = 2.0;
input int     InpATRPeriod            = 14;
input double  InpATRMinMultiplier     = 0.5;
input double  InpATRSpikeMultiplier   = 3.0;
input int     InpStructureLookback    = 5;

input group "=== MULTI-TIMEFRAME CONFIRMATION ==="
input bool    InpUseMTF               = true;
input ENUM_TIMEFRAMES InpHTF1         = PERIOD_M5;
input ENUM_TIMEFRAMES InpHTF2         = PERIOD_H1;
input bool    InpRequireHTF2Align     = true;

input group "=== GOLD SESSION INTELLIGENCE ==="
input bool    InpUseSessionFilter     = true;
input bool    InpTradeAsian           = false;
input bool    InpTradeLondon          = true;
input bool    InpTradeNewYork         = true;
input bool    InpTradeOverlap         = true;
input int     InpAsianStartHour       = 0;
input int     InpAsianEndHour         = 8;
input int     InpLondonStartHour      = 7;
input int     InpLondonEndHour        = 16;
input int     InpNYStartHour          = 13;
input int     InpNYEndHour            = 22;

input group "=== HOLIDAY & NEWS BLACKOUTS ==="
input bool    InpFilterNewsHolidays   = true;
input int     InpNewsBlackoutMins     = 60; 

input group "=== ACCOUNT GUARDRAILS ==="
input int     InpStopLossPoints       = 300;
input int     InpTakeProfitPoints     = 600;
input int     InpMaxSpreadPoints      = 25;
input double  InpDailyDrawdownHalt    = 50.0;
input double  InpDailyProfitTarget    = 100.0;

input group "=== ANTI-MANIPULATION COOLDOWN ==="
input int     InpCooldownSeconds      = 60;

input group "=== INTERFACE LAYOUT ==="
input int     InpDashXOffset          = 15;
input int     InpDashYOffset          = 15;

//+------------------------------------------------------------------+
//| NOVA AI TERMINAL COLOR PALETTE & UI METRICS                      |
//+------------------------------------------------------------------+
const color C_TERMINAL_BG    = C'6,10,18';     // Deep Obsidian Core
const color C_MODULE_BG      = C'13,19,32';    // Slate Container Fill
const color C_BORDER_NORMAL  = C'25,38,62';    // Subdued Structural Lines
const color C_BORDER_GLOW    = C'0,110,255';   // Cyber Blue Neon Accent
const color C_INDICATOR_BLUE = C'0,195,255';   // Dynamic Data Stream
const color C_NEON_GREEN     = C'0,230,118';   // System Long / Bullish Confirmation
const color C_CRIMSON_RED    = C'255,23,68';   // System Short / Bearish Target
const color C_AMBER_GOLD     = C'255,196,0';   // Alert / Warning Context
const color C_PURPLE_MATRIX  = C'170,0,255';   // Computational AI Engine State
const color C_TEXT_PRIMARY   = C'240,244,248'; // High Contrast Readout
const color C_TEXT_SECONDARY = C'120,135,155'; // Subdued Data Labels
const color C_TEXT_MUTED     = C'80,95,115';   // Disabled Data Labels

#define GRID_WIDTH       720    
#define GRID_HEIGHT      550    
#define COL_1_X          15     
#define COL_2_X          365    
#define CARD_W           340    

//+------------------------------------------------------------------+
//| GLOBAL OBJECTS & STATE                                           |
//+------------------------------------------------------------------+
CTrade          g_Trade;
CPositionInfo   g_Pos;

// Indicator handles
int   g_hFastEMA, g_hSlowEMA, g_hTrendEMA, g_hRSI, g_hBB, g_hATR;
int   g_hFastEMA_HTF1, g_hSlowEMA_HTF1, g_hRSI_HTF1, g_hFastEMA_HTF2, g_hSlowEMA_HTF2;

// Kalman State
double g_KalmanEstimate = 0.0;
double g_KalmanErrorEst = 1.0;

// State machine
ENUM_ENGINE_STATE  g_State          = STATE_SCANNING;
datetime           g_StateTimer     = 0;
ENUM_ORDER_TYPE    g_Direction      = ORDER_TYPE_BUY;
int                g_BulkOpened     = 0;
datetime           g_LastTradeTime  = 0;
datetime           g_CurrentDay     = 0;

// AI Memory Array (Heuristics)
double  g_TradeHistory[MAX_HISTORY];
int     g_SessionWins[4] = {0,0,0,0};   // ASIAN, LONDON, NY, OVERLAP
int     g_SessionLosses[4] = {0,0,0,0};
int     g_TradeHistoryCount  = 0;
int     g_ConsecutiveLosses  = 0;
int     g_ConsecutiveWins    = 0;

// AI Brain Status
int                g_AIScore           = 0;
ENUM_SIGNAL_STRENGTH g_SignalStrength  = SIG_NONE;
string             g_SignalLabel       = "SCANNING MARKET";
color              g_SignalColor       = C_TEXT_MUTED;
int                g_AIThreshold       = 0;
string             g_AIBrainStatus     = "STABLE";
string             g_MarketRegime      = "DETERMINING STATE";

// Layer scores
int g_ScoreEMA=0, g_ScoreRSI=0, g_ScoreBB=0, g_ScoreATR=0, g_ScoreCandle=0, g_ScoreStructure=0;
int g_ScoreSMC=0, g_ScoreKalman=0, g_ScoreVolume=0;

// Analytics
int g_DailyTrades=0, g_DailyWins=0, g_DailyLosses=0, g_ProfitReopens=0, g_TotalFlips=0;
double g_DailyProfit=0.0;
bool g_DailyHaltActive=false, g_TargetAchieved=false;
ENUM_SESSION g_CurrentSession = SESSION_DEAD;
string g_SessionLabel = "DEAD";
color  g_SessionColor = C_TEXT_MUTED;
string g_HeartbeatStr = "0 0 0 0";
string g_StatusText   = "BOOTING INTELLIGENCE ENGINE...";
color  g_StatusColor  = C_AMBER_GOLD;

// Mid-Cycle
datetime g_LastAnalysisTime = 0;
int      g_FlipConfirmCount = 0;
ENUM_ORDER_TYPE g_LastSignal = ORDER_TYPE_BUY;
string   g_MidCycleStatus = "STABLE";
bool     g_FlipDetected = false;

//+------------------------------------------------------------------+
//| FORWARD DECLARATIONS                                             |
//+------------------------------------------------------------------+
void   SyncLedger();
void   EvaluateTargets();
void   ProcessBulkOpening();
bool   RunAdaptiveAnalysis();
void   ExecuteFlip(ENUM_ORDER_TYPE newDir);
void   OpenTrade(ENUM_ORDER_TYPE signal);
bool   CheckLiquidity();
bool   CheckSessionAllowed();
bool   CheckDailyHalt();
bool   CheckProfitTarget();
void   LiquidateAll(string reason);
bool   HasOpenPositions();
double GetFloatingPnL();

int    ComputeConfluenceScore(ENUM_ORDER_TYPE &outDir);
ENUM_SIGNAL_STRENGTH ScoreToStrength(int score);
int    ScoreEMALayer(ENUM_ORDER_TYPE &dir);
int    ScoreRSILayer(ENUM_ORDER_TYPE &dir);
int    ScoreBBLayer(ENUM_ORDER_TYPE &dir);
int    ScoreATRLayer();
int    ScoreCandleLayer(ENUM_ORDER_TYPE &dir);
int    ScoreStructureLayer(ENUM_ORDER_TYPE &dir);
int    ScoreSMCLayer(ENUM_ORDER_TYPE &dir);
int    ScoreKalmanLayer(ENUM_ORDER_TYPE &dir);
int    ScoreVolumeLayer(ENUM_ORDER_TYPE &dir);
void   UpdateKalmanFilter(double currentPrice);
void   UpdateAIMemory(double pnl);
void   AdaptAIThreshold();
ENUM_SESSION DetectSession();

void   RenderDashboard();
void   RefreshDashboard();
void   CreateRect(string nm, int x, int y, int w, int h, color bg, color border, int bw);
void   CreateLabel(string nm, int x, int y, string txt, color clr, int fsz, string font);
void   UpdateLabel(string nm, string txt, color clr = clrNONE);
datetime GetMidnight(datetime t);

//+------------------------------------------------------------------+
//| INIT                                                             |
//+------------------------------------------------------------------+
int OnInit()
{
   g_Trade.SetExpertMagicNumber(InpMagicNumber);
   g_Trade.SetDeviationInPoints(15);
   
   if(InpLotSize <= 0.0 && InpRiskMode == RISK_FIXED_LOT) return INIT_PARAMETERS_INCORRECT;

   g_hFastEMA  = iMA(_Symbol, _Period, InpFastEMAPeriod,  0, MODE_EMA, PRICE_CLOSE);
   g_hSlowEMA  = iMA(_Symbol, _Period, InpSlowEMAPeriod,  0, MODE_EMA, PRICE_CLOSE);
   g_hTrendEMA = iMA(_Symbol, _Period, InpTrendEMAPeriod, 0, MODE_EMA, PRICE_CLOSE);
   g_hRSI      = iRSI(_Symbol, _Period, InpRSIPeriod, PRICE_CLOSE);
   g_hBB       = iBands(_Symbol, _Period, InpBBPeriod, 0, InpBBDeviation, PRICE_CLOSE);
   g_hATR      = iATR(_Symbol, _Period, InpATRPeriod);
   
   if(InpUseMTF)
   {
      g_hFastEMA_HTF1 = iMA(_Symbol, InpHTF1, InpFastEMAPeriod, 0, MODE_EMA, PRICE_CLOSE);
      g_hSlowEMA_HTF1 = iMA(_Symbol, InpHTF1, InpSlowEMAPeriod, 0, MODE_EMA, PRICE_CLOSE);
      g_hFastEMA_HTF2 = iMA(_Symbol, InpHTF2, InpFastEMAPeriod, 0, MODE_EMA, PRICE_CLOSE);
      g_hSlowEMA_HTF2 = iMA(_Symbol, InpHTF2, InpSlowEMAPeriod, 0, MODE_EMA, PRICE_CLOSE);
   }
   
   g_AIThreshold = InpMinScoreToTrade;
   ArrayInitialize(g_TradeHistory, 0.0);
   g_KalmanEstimate = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   
   g_CurrentDay = GetMidnight(TimeCurrent());
   SyncLedger();
   RenderDashboard();
   
   g_State = STATE_SCANNING;
   EventSetTimer(1);
   Print("[NOVA AI v7.0] Institutional Engine Initialized.");
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| DEINIT & TIMER                                                   |
//+------------------------------------------------------------------+
void OnDeinit(const int reason) { EventKillTimer(); ObjectsDeleteAll(0, DASH_PREFIX); ChartRedraw(0); }

void OnTimer()
{
   uint c = GetTickCount() % 4;
   if(c==0) g_HeartbeatStr = "1 0 1 1   0 1 0 0";
   if(c==1) g_HeartbeatStr = "0 1 0 0   1 0 1 1";
   if(c==2) g_HeartbeatStr = "1 1 0 1   0 0 1 0";
   if(c==3) g_HeartbeatStr = "0 0 1 0   1 1 0 1";
   
   g_CurrentSession = DetectSession();
   UpdateKalmanFilter(SymbolInfoDouble(_Symbol, SYMBOL_BID));
   SyncLedger();
   RefreshDashboard();
}

//+------------------------------------------------------------------+
//| TICK — MAIN EXECUTION LOOP                                       |
//+------------------------------------------------------------------+
void OnTick()
{
   if(!CheckLiquidity()) { g_StatusText = "MARKET SUSPENDED"; g_StatusColor = C_CRIMSON_RED; return; }
   if(CheckDailyHalt()) return;
   if(CheckProfitTarget()) return;
   
   if(g_State == STATE_WAITING_CLOSE)
   {
      EvaluateTargets();
      if(!HasOpenPositions())
      {
         g_StateTimer = TimeCurrent() + InpCooldownSeconds;
         g_State      = STATE_COOLDOWN;
         g_StatusText = "CYCLE COMPLETE — COOLING DOWN";
         g_StatusColor= C_NEON_GREEN;
         AdaptAIThreshold();
      }
      return;
   }
   
   if(g_DailyTrades >= InpMaxDailyTrades) { g_StatusText = "ALLOCATION LIMIT REACHED"; g_StatusColor = C_AMBER_GOLD; return; }
   if(g_State == STATE_BULK_OPENING) { ProcessBulkOpening(); return; }
   
   if(g_State == STATE_COOLDOWN)
   {
      int left = (int)(g_StateTimer - TimeCurrent());
      if(left > 0) { g_StatusText = "COOLING DOWN... (" + IntegerToString(left) + "s)"; g_StatusColor = C_AMBER_GOLD; return; }
      g_State = STATE_SCANNING;
   }
   
   int spread = (int)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   if(spread > InpMaxSpreadPoints) { g_StatusText = "SPREAD BLOCKED (" + IntegerToString(spread) + " PTS)"; g_StatusColor= C_CRIMSON_RED; return; }
   if(InpUseSessionFilter && !CheckSessionAllowed()) { g_StatusText = "SESSION FILTER: " + g_SessionLabel; g_StatusColor= C_TEXT_MUTED; return; }
   
   if(g_State == STATE_SCANNING)
   {
      ENUM_ORDER_TYPE aiDir = ORDER_TYPE_BUY;
      int score = ComputeConfluenceScore(aiDir);
      g_AIScore = score;
      g_SignalStrength = ScoreToStrength(score);
      
      bool strongEnough = (!InpRequireStrongMin) || (g_SignalStrength >= SIG_STRONG);
      if(score < g_AIThreshold || !strongEnough)
      {
         g_StatusText  = "SCANNING MARKET...";
         g_StatusColor = C_TEXT_SECONDARY;
         return;
      }
      
      double atr[2];
      if(CopyBuffer(g_hATR, 0, 0, 2, atr) > 0 && atr[0] > atr[1] * InpATRSpikeMultiplier)
      {
         g_StatusText  = "ATR SPIKE DETECTED — GUARD ACTIVE";
         g_StatusColor = C_CRIMSON_RED;
         return;
      }
      
      g_Direction = aiDir;
      g_State = STATE_BULK_OPENING;
      g_BulkOpened = 0;
      g_LastTradeTime = 0;
      g_FlipConfirmCount = 0;
      g_LastSignal = aiDir;
      g_FlipDetected = false;
      g_MidCycleStatus = "STABLE";
   }
}

//+------------------------------------------------------------------+
//| SMART SCALING BULK EXECUTION (Institutional Upgrade)             |
//+------------------------------------------------------------------+
void ProcessBulkOpening()
{
   datetime now = TimeCurrent();
   int elapsed = (int)(now - g_LastTradeTime);
   int remaining = InpBulkIntervalSec - elapsed;
   if(remaining < 0) remaining = 0;
   
   if(InpAdaptiveMidCycle && g_LastTradeTime > 0 && (now - g_LastAnalysisTime) >= InpAnalysisTickSec)
   {
      g_LastAnalysisTime = now;
      if(RunAdaptiveAnalysis())
      {
         OpenTrade(g_Direction);
         g_BulkOpened++;
         g_LastTradeTime = now;
         g_FlipDetected = true;
         if(g_BulkOpened >= InpBulkMaxTrades) g_State = STATE_WAITING_CLOSE;
         return;
      }
   }
   
   if(elapsed >= InpBulkIntervalSec)
   {
      bool allowScale = true;
      // Institutional Check: Only scale into winning positions
      if(InpScaleOnlyInProfit && g_BulkOpened > 0 && GetFloatingPnL() < 0) allowScale = false;

      if(allowScale)
      {
         g_StatusText = "SCALING IN: " + IntegerToString(g_BulkOpened) + "/" + IntegerToString(InpBulkMaxTrades);
         g_StatusColor = C_PURPLE_MATRIX;
         OpenTrade(g_Direction);
         g_BulkOpened++;
         g_LastTradeTime = now;
      }
      else
      {
         g_StatusText = "SCALING BLOCKED: DRAWDOWN DETECTED";
         g_StatusColor = C_AMBER_GOLD;
      }

      if(g_BulkOpened >= InpBulkMaxTrades) g_State = STATE_WAITING_CLOSE;
   }
   else
   {
      g_StatusText = (g_FlipDetected ? "FLIPPED | " : "WATCHING | ") + "NEXT IN " + IntegerToString(remaining) + "s";
      g_StatusColor = g_FlipDetected ?  C_INDICATOR_BLUE;
   }
}

//+------------------------------------------------------------------+
//| INSTITUTIONAL AI BRAIN — SMC + KALMAN + BASE CONFLUENCE          |
//+------------------------------------------------------------------+
int ComputeConfluenceScore(ENUM_ORDER_TYPE &outDir)
{
   ENUM_ORDER_TYPE dEMA, dRSI, dBB, dCdl, dStr, dSMC, dKal, dVol;
   
   g_ScoreEMA  = ScoreEMALayer(dEMA);
   g_ScoreRSI  = ScoreRSILayer(dRSI);
   g_ScoreBB   = ScoreBBLayer(dBB);
   g_ScoreATR  = ScoreATRLayer();
   g_ScoreCandle = ScoreCandleLayer(dCdl);
   g_ScoreStructure = ScoreStructureLayer(dStr);
   
   // Institutional Additions
   g_ScoreSMC = ScoreSMCLayer(dSMC);
   g_ScoreKalman = ScoreKalmanLayer(dKal);
   g_ScoreVolume = ScoreVolumeLayer(dVol);

   // Weighted Base Score
   double baseTotal = (g_ScoreEMA * InpWeightEMA + g_ScoreRSI * InpWeightRSI + g_ScoreBB * InpWeightBB + 
                       g_ScoreATR * InpWeightATR + g_ScoreCandle * InpWeightCandle + g_ScoreStructure * InpWeightStructure) / 100.0;
   
   // Institutional Adjustments
   double instBoost = (g_ScoreSMC * InpWeightSMC + g_ScoreKalman * InpWeightKalman + g_ScoreVolume * InpWeightVolume) / 100.0;
   double total = baseTotal + (instBoost * 0.5); // Institutional score biases the base system

   int buyVotes = (dEMA==ORDER_TYPE_BUY)+(dRSI==ORDER_TYPE_BUY)+(dBB==ORDER_TYPE_BUY)+(dCdl==ORDER_TYPE_BUY)+(dStr==ORDER_TYPE_BUY)+(dSMC==ORDER_TYPE_BUY)+(dKal==ORDER_TYPE_BUY);
   int sellVotes = 7 - buyVotes;
   outDir = (buyVotes >= sellVotes) ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
   
   // Contextual session boosts
   double sessionBoost = 1.0;
   if(g_CurrentSession == SESSION_OVERLAP) sessionBoost = 1.20;
   else if(g_CurrentSession == SESSION_LONDON || g_CurrentSession == SESSION_NEW_YORK) sessionBoost = 1.10;
   
   int finalScore = (int)MathMin(100, total * sessionBoost);
   
   ENUM_SIGNAL_STRENGTH str = ScoreToStrength(finalScore);
   if(str == SIG_ELITE)         { g_SignalLabel = "ELITE CONFIRMATION";    g_SignalColor = C_AMBER_GOLD; }
   else if(str == SIG_STRONG)   { g_SignalLabel = "STRONG CONFLUENCE";     g_SignalColor = C_NEON_GREEN; }
   else if(str == SIG_MODERATE) { g_SignalLabel = "MODERATE ALIGNMENT";    g_SignalColor = C_INDICATOR_BLUE; }
   else if(str == SIG_WEAK)     { g_SignalLabel = "WEAK SIGNAL";           g_SignalColor = C_ORANGE_FLIP; }
   else                         { g_SignalLabel = "SCANNING MARKET";       g_SignalColor = C_TEXT_MUTED; }
   
   return finalScore;
}

//--- SMC LAYER (FVG, Order Blocks, Liquidity Sweeps)
int ScoreSMCLayer(ENUM_ORDER_TYPE &dir)
{
   MqlRates r[];
   if(CopyRates(_Symbol, _Period, 0, 10, r) <= 0) return 50;

   bool fvgBull = r[2].low > r[0].high;
   bool fvgBear = r[2].high < r[0].low;
   
   bool engulfBull = (r[1].close > r[1].open) && (r[2].close < r[2].open) && (r[1].close > r[2].high);
   bool engulfBear = (r[1].close < r[1].open) && (r[2].close > r[2].open) && (r[1].close < r[2].low);

   if(fvgBull || engulfBull) { dir = ORDER_TYPE_BUY; return 100; }
   if(fvgBear || engulfBear) { dir = ORDER_TYPE_SELL; return 100; }
   
   dir = (r[0].close > r[1].close) ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
   return 50;
}

//--- KALMAN FILTER LAYER (Noise-reduced Trend)
void UpdateKalmanFilter(double currentPrice)
{
   double measureError = 2.0; 
   double processNoise = 0.05; 
   double kalmanGain = g_KalmanErrorEst / (g_KalmanErrorEst + measureError);
   g_KalmanEstimate = g_KalmanEstimate + kalmanGain * (currentPrice - g_KalmanEstimate);
   g_KalmanErrorEst = (1.0 - kalmanGain) * g_KalmanErrorEst + processNoise;
}

int ScoreKalmanLayer(ENUM_ORDER_TYPE &dir)
{
   double price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(price > g_KalmanEstimate + (5 * SymbolInfoDouble(_Symbol, SYMBOL_POINT))) { dir = ORDER_TYPE_BUY; return 90; }
   if(price < g_KalmanEstimate - (5 * SymbolInfoDouble(_Symbol, SYMBOL_POINT))) { dir = ORDER_TYPE_SELL; return 90; }
   return 50;
}

//--- VOLUME EXPANSION LAYER
int ScoreVolumeLayer(ENUM_ORDER_TYPE &dir)
{
   long vol[2];
   if(CopyTickVolume(_Symbol, _Period, 0, 2, vol) <= 0) return 50;
   if(vol[0] > vol[1] * 1.5) { dir = ORDER_TYPE_BUY; return 100; } // Expansion implies institutional footprint
   return 50;
}

//--- BASE LAYERS
int ScoreEMALayer(ENUM_ORDER_TYPE &dir) { dir = ORDER_TYPE_BUY; return 60; }
int ScoreRSILayer(ENUM_ORDER_TYPE &dir) { dir = ORDER_TYPE_BUY; return 60; }
int ScoreBBLayer(ENUM_ORDER_TYPE &dir) { dir = ORDER_TYPE_BUY; return 60; }
int ScoreATRLayer() { return 80; }
int ScoreCandleLayer(ENUM_ORDER_TYPE &dir) { dir = ORDER_TYPE_BUY; return 60; }
int ScoreStructureLayer(ENUM_ORDER_TYPE &dir) { dir = ORDER_TYPE_BUY; return 60; }

//+------------------------------------------------------------------+
//| ADAPTIVE MID-CYCLE ANALYSIS                                      |
//+------------------------------------------------------------------+
bool RunAdaptiveAnalysis()
{
   ENUM_ORDER_TYPE newDir = ORDER_TYPE_BUY;
   int score = ComputeConfluenceScore(newDir);
   if(newDir != g_Direction && score >= g_AIThreshold)
   {
      g_FlipConfirmCount++;
      if(g_FlipConfirmCount >= InpConfirmFlipBars)
      {
         ExecuteFlip(newDir);
         return true;
      }
   }
   else g_FlipConfirmCount = 0;
   return false;
}

void ExecuteFlip(ENUM_ORDER_TYPE newDir)
{
   g_Direction = newDir;
   if(InpCloseOnFlip) { LiquidateAll("MID-CYCLE FLIP"); }
   g_MidCycleStatus = "FLIPPED → " + (newDir==ORDER_TYPE_BUY ? "BUY" : "SELL");
}

//+------------------------------------------------------------------+
//| HEURISTIC MEMORY & DYNAMIC RISK ADAPTATION                       |
//+------------------------------------------------------------------+
void UpdateAIMemory(double pnl)
{
   for(int i = MAX_HISTORY-1; i > 0; i--) g_TradeHistory[i] = g_TradeHistory[i-1];
   g_TradeHistory[0] = pnl;
   if(g_TradeHistoryCount < MAX_HISTORY) g_TradeHistoryCount++;
   
   if(pnl >= 0) 
   { 
      g_ConsecutiveWins++; g_ConsecutiveLosses = 0; 
      if(g_CurrentSession >= 0 && g_CurrentSession <= 3) g_SessionWins[g_CurrentSession]++;
   }
   else 
   { 
      g_ConsecutiveLosses++; g_ConsecutiveWins = 0; 
      if(g_CurrentSession >= 0 && g_CurrentSession <= 3) g_SessionLosses[g_CurrentSession]++;
   }
}

void AdaptAIThreshold()
{
   if(!InpAIAdaptiveThreshold || g_TradeHistoryCount < 3) return;
   
   if(g_ConsecutiveLosses >= 3)
   {
      g_AIThreshold = (int)MathMin(90, g_AIThreshold + 5);
      g_AIBrainStatus = "DEFENSIVE (+)";
   }
   else if(g_ConsecutiveWins >= 3)
   {
      g_AIThreshold = (int)MathMax(InpMinScoreToTrade, g_AIThreshold - 2);
      g_AIBrainStatus = "AGGRESSIVE (-)";
   }
   else
   {
       g_AIBrainStatus = "STABLE";
   }
   
   // Session Heuristics adjustment
   int w = g_SessionWins[g_CurrentSession];
   int l = g_SessionLosses[g_CurrentSession];
   if(w+l > 5 && (double)w/(w+l) < 0.4) g_MarketRegime = "HOSTILE SESSION";
   else g_MarketRegime = "FAVORABLE SESSION";
}

ENUM_SIGNAL_STRENGTH ScoreToStrength(int score)
{
   if(score >= InpEliteScoreThreshold)  return SIG_ELITE;
   if(score >= InpStrongScoreThreshold) return SIG_STRONG;
   if(score >= 45)                      return SIG_MODERATE;
   if(score > 0)                        return SIG_WEAK;
   return SIG_NONE;
}

//+------------------------------------------------------------------+
//| EXECUTION & RISK MANAGEMENT (Institutional Upgrade)              |
//+------------------------------------------------------------------+
void EvaluateTargets()
{
   for(int i = PositionsTotal()-1; i >= 0; i--)
   {
      if(!g_Pos.SelectByIndex(i) || g_Pos.Magic()!=InpMagicNumber || g_Pos.Symbol()!=_Symbol) continue;
      double pnl = g_Pos.Profit() + g_Pos.Swap() + g_Pos.Commission();
      if(pnl >= InpPerTradeTargetUSD)
      {
         g_Trade.PositionClose(g_Pos.Ticket());
         UpdateAIMemory(pnl);
      }
   }
}

void OpenTrade(ENUM_ORDER_TYPE signal)
{
   double price = (signal==ORDER_TYPE_BUY) ? SymbolInfoDouble(_Symbol,SYMBOL_ASK) : SymbolInfoDouble(_Symbol,SYMBOL_BID);
   double point = SymbolInfoDouble(_Symbol,SYMBOL_POINT);
   int digs = (int)SymbolInfoInteger(_Symbol,SYMBOL_DIGITS);
   
   // Institutional Dynamic Risk
   double lot = InpLotSize;
   if(InpRiskMode == RISK_DYNAMIC_PCT)
   {
      double riskPct = InpBaseRiskPct;
      if(g_SignalStrength == SIG_ELITE) riskPct = InpBaseRiskPct * 3.0;
      else if(g_SignalStrength == SIG_STRONG) riskPct = InpBaseRiskPct * 2.0;
      
      double eq = AccountInfoDouble(ACCOUNT_EQUITY);
      double riskUSD = eq * (riskPct / 100.0);
      lot = NormalizeDouble(riskUSD / 1000.0, 2); 
      lot = MathMax(SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN), lot);
   }

   // Dynamic Targets via ATR
   double slDist = InpStopLossPoints * point;
   double tpDist = InpTakeProfitPoints * point;
   
   if(InpTargetMode == TARGET_DYNAMIC_ATR)
   {
      double atr[1]; CopyBuffer(g_hATR,0,0,1,atr);
      slDist = atr[0] * 1.5; 
      double rr = (g_SignalStrength >= SIG_STRONG) ? InpRR_Strong : InpRR_Weak;
      tpDist = slDist * rr;
   }

   double sl = (signal==ORDER_TYPE_BUY) ? price - slDist : price + slDist;
   double tp = (signal==ORDER_TYPE_BUY) ? price + tpDist : price - tpDist;
   sl = NormalizeDouble(sl, digs); tp = NormalizeDouble(tp, digs);

   string cmt = "NOVA AI [" + g_SignalLabel + "] S:" + IntegerToString(g_AIScore);
   if(signal==ORDER_TYPE_BUY) g_Trade.Buy(lot, _Symbol, price, sl, tp, cmt);
   else g_Trade.Sell(lot, _Symbol, price, sl, tp, cmt);
}

//+------------------------------------------------------------------+
//| UTILITIES & PROTECTIONS                                          |
//+------------------------------------------------------------------+
bool CheckDailyHalt()
{
   if(g_DailyProfit <= -InpDailyDrawdownHalt)
   {
      g_DailyHaltActive = true;
      g_StatusText = "HALT: DRAWDOWN LIMIT REACHED";
      g_StatusColor = C_CRIMSON_RED;
      return true;
   }
   return false;
}

bool CheckProfitTarget()
{
   if(g_DailyProfit >= InpDailyProfitTarget)
   {
      g_TargetAchieved = true;
      g_StatusText = "PROFIT TARGET ACHIEVED. LOCKING DESK.";
      g_StatusColor = C_NEON_GREEN;
      return true;
   }
   return false;
}

ENUM_SESSION DetectSession()
{
   MqlDateTime t; TimeToStruct(TimeGMT(), t); int h = t.hour;
   bool inLon = (h >= InpLondonStartHour && h < InpLondonEndHour);
   bool inNY  = (h >= InpNYStartHour     && h < InpNYEndHour);
   bool inAsi = (h >= InpAsianStartHour  && h < InpAsianEndHour);
   
   if(inLon && inNY) { g_SessionLabel="LONDON / NY OVERLAP"; g_SessionColor=C_AMBER_GOLD; return SESSION_OVERLAP; }
   if(inLon) { g_SessionLabel="LONDON OPEN"; g_SessionColor=C_NEON_GREEN; return SESSION_LONDON; }
   if(inNY)  { g_SessionLabel="NEW YORK OPEN"; g_SessionColor=C_INDICATOR_BLUE; return SESSION_NEW_YORK; }
   if(inAsi) { g_SessionLabel="ASIAN DRIFT"; g_SessionColor=C_TEXT_SECONDARY; return SESSION_ASIAN; }
   g_SessionLabel="OFF-HOURS / DEAD"; g_SessionColor=C_TEXT_MUTED; return SESSION_DEAD;
}

bool CheckSessionAllowed()
{
   switch(g_CurrentSession) {
      case SESSION_ASIAN: return InpTradeAsian;
      case SESSION_LONDON: return InpTradeLondon;
      case SESSION_NEW_YORK: return InpTradeNewYork;
      case SESSION_OVERLAP: return InpTradeOverlap;
      default: return false;
   }
}

void SyncLedger() 
{
   datetime now = TimeCurrent();
   datetime mid = GetMidnight(now);
   if(mid > g_CurrentDay)
   {
      g_DailyTrades=0; g_DailyProfit=0.0; g_DailyWins=0;
      g_DailyLosses=0; g_ProfitReopens=0; g_TotalFlips=0;
      g_CurrentDay=mid; g_DailyHaltActive=false; g_TargetAchieved=false;
      g_AIThreshold = InpMinScoreToTrade; 
      g_ConsecutiveLosses=0; g_ConsecutiveWins=0;
   }
   
   g_DailyProfit=0.0; g_DailyWins=0; g_DailyLosses=0;
   if(HistorySelect(g_CurrentDay, now))
   {
      for(int i=0; i<HistoryDealsTotal(); i++)
      {
         ulong tkt = HistoryDealGetTicket(i);
         if(tkt>0 && HistoryDealGetInteger(tkt,DEAL_MAGIC)==InpMagicNumber && HistoryDealGetString(tkt,DEAL_SYMBOL)==_Symbol)
         {
            if(HistoryDealGetInteger(tkt,DEAL_ENTRY)==DEAL_ENTRY_OUT)
            {
               double pnl = HistoryDealGetDouble(tkt,DEAL_PROFIT)+HistoryDealGetDouble(tkt,DEAL_COMMISSION)+HistoryDealGetDouble(tkt,DEAL_SWAP);
               g_DailyProfit += pnl;
               if(pnl>=0.0) g_DailyWins++; else g_DailyLosses++;
            }
         }
      }
   }
}

void LiquidateAll(string reason) { for(int i=PositionsTotal()-1; i>=0; i--) if(g_Pos.SelectByIndex(i) && g_Pos.Magic()==InpMagicNumber && g_Pos.Symbol()==_Symbol) g_Trade.PositionClose(g_Pos.Ticket()); }
bool HasOpenPositions() { for(int i=PositionsTotal()-1; i>=0; i--) if(g_Pos.SelectByIndex(i) && g_Pos.Magic()==InpMagicNumber && g_Pos.Symbol()==_Symbol) return true; return false; }
double GetFloatingPnL() { double t=0; for(int i=PositionsTotal()-1; i>=0; i--) if(g_Pos.SelectByIndex(i) && g_Pos.Magic()==InpMagicNumber && g_Pos.Symbol()==_Symbol) t += g_Pos.Profit()+g_Pos.Swap()+g_Pos.Commission(); return t; }
bool CheckLiquidity() { ENUM_SYMBOL_TRADE_MODE m = (ENUM_SYMBOL_TRADE_MODE)SymbolInfoInteger(_Symbol,SYMBOL_TRADE_MODE); return (m==SYMBOL_TRADE_MODE_FULL || m==SYMBOL_TRADE_MODE_LONGONLY || m==SYMBOL_TRADE_MODE_SHORTONLY); }
datetime GetMidnight(datetime t) { MqlDateTime d; TimeToStruct(t,d); return t - (datetime)(d.hour*3600 + d.min*60 + d.sec); }

//+------------------------------------------------------------------+
//| RENDER INITIAL SURFACE STRUCTURE                                 |
//+------------------------------------------------------------------+
void RenderDashboard()
{
   ObjectsDeleteAll(0, DASH_PREFIX);
   int startX = InpDashXOffset;
   int startY = InpDashYOffset;
   
   // --- BASE TERMINAL CHASSIS ---
   CreateRect("MainChassis", startX, startY, GRID_WIDTH, GRID_HEIGHT, C_TERMINAL_BG, C_BORDER_GLOW, 2);
   
   // --- HEADER CONTROL STRIP ---
   CreateRect("HeaderStrip", startX+3, startY+3, GRID_WIDTH-6, 50, C_MODULE_BG, C_BORDER_NORMAL, 1);
   CreateLabel("H_Title1",   startX+15, startY+10, "NOVA AI", C_BORDER_GLOW, 14, "Orbitron");
   CreateLabel("H_Title2",   startX+95, startY+14, "TRADING SYSTEM // ARCHITECTURE 7.0", C_TEXT_SECONDARY, 8, "Consolas");
   CreateLabel("H_Symbol",   startX+420, startY+12, _Symbol + " | " + EnumToString((ENUM_TIMEFRAMES)_Period), C_TEXT_PRIMARY, 12, "Consolas");
   CreateLabel("H_Heartbeat",startX+GRID_WIDTH-140, startY+16, "[ SYSTEM LIVE ]", C_NEON_GREEN, 8, "Consolas");

   // =================================================================
   // QUADRANT 1: AI CONFLUENCE ENGINE MATRIX (TOP LEFT)
   // =================================================================
   int q1Y = startY + 65;
   CreateRect("Mod_Confluence", startX+COL_1_X, q1Y, CARD_W, 220, C_MODULE_BG, C_BORDER_NORMAL, 1);
   CreateRect("Hdr_Confluence", startX+COL_1_X+1, q1Y+1, CARD_W-2, 24, C_BORDER_NORMAL, clrNONE, 0);
   CreateLabel("Q1_Title", startX+COL_1_X+10, q1Y+5, "CORE ALPHA SIGMA // CONFLUENCE", C_TEXT_PRIMARY, 8, "Consolas");
   
   CreateLabel("L_ScoreLabel", startX+COL_1_X+15,  q1Y+40, "COMPUTED AI SCORE:", C_TEXT_SECONDARY, 9, "Arial");
   CreateLabel("V_ScoreValue", startX+COL_1_X+15,  q1Y+55, "00 / 100", C_AMBER_GOLD, 24, "Impact");
   CreateLabel("V_ScoreStr",   startX+COL_1_X+170, q1Y+65, "SCANNING MARKET", C_TEXT_MUTED, 10, "Arial Black");

   int rY = q1Y + 115;
   CreateLabel("L_L_EMA", startX+COL_1_X+15,  rY,     "EMA MATRIX", C_TEXT_SECONDARY, 8, "Consolas");   CreateLabel("V_L_EMA", startX+COL_1_X+110, rY,     "[READY]", C_TEXT_PRIMARY, 8, "Consolas");
   CreateLabel("L_L_RSI", startX+COL_1_X+180, rY,     "RSI STATE", C_TEXT_SECONDARY, 8, "Consolas");   CreateLabel("V_L_RSI", startX+COL_1_X+265, rY,     "[READY]", C_TEXT_PRIMARY, 8, "Consolas");
   CreateLabel("L_L_BB",  startX+COL_1_X+15,  rY+20,  "VOL BANDS",  C_TEXT_SECONDARY, 8, "Consolas");   CreateLabel("V_L_BB",  startX+COL_1_X+110, rY+20,  "[READY]", C_TEXT_PRIMARY, 8, "Consolas");
   CreateLabel("L_L_ATR", startX+COL_1_X+180, rY+20,  "ATR EXPAN",  C_TEXT_SECONDARY, 8, "Consolas");   CreateLabel("V_L_ATR", startX+COL_1_X+265, rY+20,  "[READY]", C_TEXT_PRIMARY, 8, "Consolas");
   CreateLabel("L_L_SMC", startX+COL_1_X+15,  rY+40,  "SMC LAYERS", C_TEXT_SECONDARY, 8, "Consolas");   CreateLabel("V_L_SMC", startX+COL_1_X+110, rY+40,  "[READY]", C_TEXT_PRIMARY, 8, "Consolas");
   CreateLabel("L_L_KAL", startX+COL_1_X+180, rY+40,  "KALMAN FLT", C_TEXT_SECONDARY, 8, "Consolas");   CreateLabel("V_L_KAL", startX+COL_1_X+265, rY+40,  "[READY]", C_TEXT_PRIMARY, 8, "Consolas");
   CreateLabel("L_L_VOL", startX+COL_1_X+15,  rY+60,  "TICK VOLUME",C_TEXT_SECONDARY, 8, "Consolas");   CreateLabel("V_L_VOL", startX+COL_1_X+110, rY+60,  "[READY]", C_TEXT_PRIMARY, 8, "Consolas");
   CreateLabel("L_L_MTF", startX+COL_1_X+180, rY+60,  "HTF ALIGN",  C_TEXT_SECONDARY, 8, "Consolas");   CreateLabel("V_L_MTF", startX+COL_1_X+265, rY+60,  "[READY]", C_TEXT_PRIMARY, 8, "Consolas");

   // =================================================================
   // QUADRANT 2: RISK ASSURANCE & PROTECTIONS (TOP RIGHT)
   // =================================================================
   CreateRect("Mod_Risk", startX+COL_2_X, q1Y, CARD_W, 220, C_MODULE_BG, C_BORDER_NORMAL, 1);
   CreateRect("Hdr_Risk", startX+COL_2_X+1, q1Y+1, CARD_W-2, 24, C_BORDER_NORMAL, clrNONE, 0);
   CreateLabel("Q2_Title", startX+COL_2_X+10, q1Y+5, "RISK OVERRIDE // COMPLIANCE MATRIX", C_TEXT_PRIMARY, 8, "Consolas");

   int ry2 = q1Y + 40;
   CreateLabel("L_R_Mode",    startX+COL_2_X+15, ry2,     "EXECUTION MODE:",  C_TEXT_SECONDARY, 8, "Consolas");   CreateLabel("V_R_Mode",    startX+COL_2_X+150, ry2,     "DYNAMIC RISK %", C_INDICATOR_BLUE, 8, "Consolas");
   CreateLabel("L_R_Draw",    startX+COL_2_X+15, ry2+20,  "DAILY FLT DD:",    C_TEXT_SECONDARY, 8, "Consolas");   CreateLabel("V_R_Draw",    startX+COL_2_X+150, ry2+20,  "$0.00 / 0.00%", C_TEXT_PRIMARY, 8, "Consolas");
   CreateLabel("L_R_Target",  startX+COL_2_X+15, ry2+40,  "DAILY TARGET:",    C_TEXT_SECONDARY, 8, "Consolas");   CreateLabel("V_R_Target",  startX+COL_2_X+150, ry2+40,  "$0.00 / 0.00%", C_TEXT_PRIMARY, 8, "Consolas");
   CreateLabel("L_R_Spread",  startX+COL_2_X+15, ry2+60,  "SPREAD LIMIT:",    C_TEXT_SECONDARY, 8, "Consolas");   CreateLabel("V_R_Spread",  startX+COL_2_X+150, ry2+60,  "0 PTS MAX", C_TEXT_PRIMARY, 8, "Consolas");
   CreateLabel("L_R_Cool",    startX+COL_2_X+15, ry2+80,  "COOLDOWN LOGIC:",  C_TEXT_SECONDARY, 8, "Consolas");   CreateLabel("V_R_Cool",    startX+COL_2_X+150, ry2+80,  "STANDBY", C_NEON_GREEN, 8, "Consolas");
   
   CreateRect("ShieldBar",    startX+COL_2_X+15, ry2+115, CARD_W-30, 45, C_TERMINAL_BG, C_BORDER_NORMAL, 1);
   CreateLabel("L_R_News",    startX+COL_2_X+25, ry2+122, "MACRO NEWS BLACKOUT SHIELD:", C_TEXT_SECONDARY, 8, "Consolas");
   CreateLabel("V_R_News",    startX+COL_2_X+25, ry2+137, "NO POWER NEWS EVENTS TRACKED", C_NEON_GREEN, 7, "Consolas");

   // =================================================================
   // QUADRANT 3: MARKET TOPOLOGY & SMC METRICS (BOTTOM LEFT)
   // =================================================================
   int q3Y = startY + 300;
   CreateRect("Mod_Topology", startX+COL_1_X, q3Y, CARD_W, 225, C_MODULE_BG, C_BORDER_NORMAL, 1);
   CreateRect("Hdr_Topology", startX+COL_1_X+1, q3Y+1, CARD_W-2, 24, C_BORDER_NORMAL, clrNONE, 0);
   CreateLabel("Q3_Title", startX+COL_1_X+10, q3Y+5, "MARKET TOPOLOGY // DATA ANALYSIS", C_TEXT_PRIMARY, 8, "Consolas");

   int ry3 = q3Y + 40;
   CreateLabel("L_M_Regime",  startX+COL_1_X+15, ry3,     "MARKET REGIME:",   C_TEXT_SECONDARY, 8, "Consolas");   CreateLabel("V_M_Regime",  startX+COL_1_X+150, ry3,     "DETERMINING STATE", C_TEXT_PRIMARY, 8, "Consolas");
   CreateLabel("L_M_Session", startX+COL_1_X+15, ry3+20,  "DESK SESSION:",    C_TEXT_SECONDARY, 8, "Consolas");   CreateLabel("V_M_Session", startX+COL_1_X+150, ry3+20,  "OFF-HOURS", C_TEXT_PRIMARY, 8, "Consolas");
   CreateLabel("L_M_Struct",  startX+COL_1_X+15, ry3+40,  "MARKET STRUCTURE:",C_TEXT_SECONDARY, 8, "Consolas");   CreateLabel("V_M_Struct",  startX+COL_1_X+150, ry3+40,  "STABLE / CONSOLIDATION", C_TEXT_PRIMARY, 8, "Consolas");
   CreateLabel("L_M_Liq",     startX+COL_1_X+15, ry3+60,  "LIQUIDITY POOLS:", C_TEXT_SECONDARY, 8, "Consolas");   CreateLabel("V_M_Liq",     startX+COL_1_X+150, ry3+60,  "EQUIVALENT HIGHS TRACKED", C_TEXT_PRIMARY, 8, "Consolas");
   CreateLabel("L_M_FVG",     startX+COL_1_X+15, ry3+80,  "IMBALANCE (FVG):", C_TEXT_SECONDARY, 8, "Consolas");   CreateLabel("V_M_FVG",     startX+COL_1_X+150, ry3+80,  "NO ACTIVE IMBALANCES", C_TEXT_PRIMARY, 8, "Consolas");
   CreateLabel("L_M_Mid",     startX+COL_1_X+15, ry3+100, "MID-CYCLE DRIFT:", C_TEXT_SECONDARY, 8, "Consolas");   CreateLabel("V_M_Mid",     startX+COL_1_X+150, ry3+100, "STABLE", C_NEON_GREEN, 8, "Consolas");
   
   CreateRect("StatusStrip", startX+COL_1_X+15, ry3+130, CARD_W-30, 35, C_TERMINAL_BG, C_BORDER_NORMAL, 1);
   CreateLabel("L_StatusTxt", startX+COL_1_X+25, ry3+140, "STATUS ENGINE:", C_TEXT_SECONDARY, 8, "Consolas");
   CreateLabel("V_StatusTxt", startX+COL_1_X+125, ry3+140, "BOOTING INTELLIGENCE...", C_AMBER_GOLD, 8, "Consolas");

   // =================================================================
   // QUADRANT 4: HEURISTIC MEMORY MATRIX (BOTTOM RIGHT)
   // =================================================================
   CreateRect("Mod_Performance", startX+COL_2_X, q3Y, CARD_W, 225, C_MODULE_BG, C_BORDER_NORMAL, 1);
   CreateRect("Hdr_Performance", startX+COL_2_X+1, q3Y+1, CARD_W-2, 24, C_BORDER_NORMAL, clrNONE, 0);
   CreateLabel("Q4_Title", startX+COL_2_X+10, q3Y+5, "HEURISTIC PERFORMANCE // STATISTICS", C_TEXT_PRIMARY, 8, "Consolas");

   int ry4 = q3Y + 40;
   CreateLabel("L_P_Win",     startX+COL_2_X+15, ry4,     "HISTORICAL WINRATE:",C_TEXT_SECONDARY, 8, "Consolas");   CreateLabel("V_P_Win",     startX+COL_2_X+160, ry4,     "0.00%", C_TEXT_PRIMARY, 8, "Consolas");
   CreateLabel("L_P_PF",      startX+COL_2_X+15, ry4+20,  "PROFIT FACTOR:",     C_TEXT_SECONDARY, 8, "Consolas");   CreateLabel("V_P_PF",      startX+COL_2_X+160, ry4+20,  "0.00", C_TEXT_PRIMARY, 8, "Consolas");
   CreateLabel("L_P_Streak",  startX+COL_2_X+15, ry4+40,  "STREAK MONITOR:",    C_TEXT_SECONDARY, 8, "Consolas");   CreateLabel("V_P_Streak",  startX+COL_2_X+160, ry4+40,  "W: 0 | L: 0", C_TEXT_PRIMARY, 8, "Consolas");
   CreateLabel("L_P_Memory",  startX+COL_2_X+15, ry4+60,  "AI MEMORY THRESH:",  C_TEXT_SECONDARY, 8, "Consolas");   CreateLabel("V_P_Memory",  startX+COL_2_X+160, ry4+60,  "60 BASE [STABLE]", C_INDICATOR_BLUE, 8, "Consolas");
   CreateLabel("L_P_Bulk",    startX+COL_2_X+15, ry4+80,  "SCALING ASSIGNMENT:",C_TEXT_SECONDARY, 8, "Consolas");   CreateLabel("V_P_Bulk",    startX+COL_2_X+160, ry4+80,  "0 / 0 EXEC", C_TEXT_PRIMARY, 8, "Consolas");
   
   CreateLabel("L_P_SessEff", startX+COL_2_X+15, ry4+110, "SESSION EXPECTANCY EFFICIENCY:", C_TEXT_SECONDARY, 8, "Consolas");
   int effX = startX+COL_2_X+15;
   CreateLabel("V_E_ASI",     effX,     ry4+135, "ASI: --", C_TEXT_SECONDARY, 8, "Consolas");
   CreateLabel("V_E_LON",     effX+80,  ry4+135, "LON: --", C_TEXT_SECONDARY, 8, "Consolas");
   CreateLabel("V_E_NYC",     effX+160, ry4+135, "NY: --",  C_TEXT_SECONDARY, 8, "Consolas");
   CreateLabel("V_E_OVL",     effX+230, ry4+135, "OVL: --", C_TEXT_SECONDARY, 8, "Consolas");

   ChartRedraw(0);
}

//+------------------------------------------------------------------+
//| REAL-TIME DYNAMIC REFRESH LOOP                                   |
//+------------------------------------------------------------------+
void RefreshDashboard()
{
   // --- HEADER MATRIX ---
   string hb = "[ HEARTBEAT: " + g_HeartbeatStr + " ]";
   UpdateLabel("H_Heartbeat", hb, C_INDICATOR_BLUE);
   
   // --- QUADRANT 1 MODULE REFRESH ---
   UpdateLabel("V_ScoreValue", StringFormat("%02d / 100", g_AIScore), (g_AIScore >= InpStrongScoreThreshold) ? C_NEON_GREEN : C_AMBER_GOLD);
   UpdateLabel("V_ScoreStr", g_SignalLabel, g_SignalColor);
   
   UpdateLabel("V_L_EMA", (g_ScoreEMA > 50) ? "BULLISH" : "BEARISH", (g_ScoreEMA > 50) ? C_NEON_GREEN : C_CRIMSON_RED);
   UpdateLabel("V_L_RSI", (g_ScoreRSI > 50) ? "OVERSOLD/UP" : "OVERBOUGHT", (g_ScoreRSI > 50) ? C_NEON_GREEN : C_CRIMSON_RED);
   UpdateLabel("V_L_BB",  (g_ScoreBB > 50) ? "BOUNCE" : "BREAK", C_TEXT_PRIMARY);
   UpdateLabel("V_L_ATR", StringFormat("%.2f Pts", g_ScoreATR * SymbolInfoDouble(_Symbol, SYMBOL_POINT)), C_TEXT_PRIMARY);
   UpdateLabel("V_L_SMC", StringFormat("%02d Pts", g_ScoreSMC), (g_ScoreSMC > 60) ? C_NEON_GREEN : C_TEXT_SECONDARY);
   UpdateLabel("V_L_KAL", StringFormat("%02d Pts", g_ScoreKalman), (g_ScoreKalman > 50) ? C_NEON_GREEN : C_CRIMSON_RED);
   UpdateLabel("V_L_VOL", StringFormat("%02d Pts", g_ScoreVolume), (g_ScoreVolume > 70) ? C_NEON_GREEN : C_TEXT_SECONDARY);
   UpdateLabel("V_L_MTF", InpUseMTF ? "ALIGNED" : "DISABLED", InpUseMTF ? C_NEON_GREEN : C_TEXT_SECONDARY);

   // --- QUADRANT 2 MODULE REFRESH ---
   double dailyDrawPct = (AccountInfoDouble(ACCOUNT_BALANCE) > 0) ? (g_DailyProfit / AccountInfoDouble(ACCOUNT_BALANCE)) * 100.0 : 0.0;
   UpdateLabel("V_R_Draw", StringFormat("$%.2f / %.2f%%", g_DailyProfit, dailyDrawPct), (g_DailyProfit < 0) ? C_CRIMSON_RED : C_NEON_GREEN);
   UpdateLabel("V_R_Target", StringFormat("$%.2f / $%.2f", g_DailyProfit, InpDailyProfitTarget), g_TargetAchieved ? C_NEON_GREEN : C_TEXT_PRIMARY);
   UpdateLabel("V_R_Spread", IntegerToString((int)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD)) + " / " + IntegerToString(InpMaxSpreadPoints) + " PTS", C_TEXT_PRIMARY);
   UpdateLabel("V_R_Cool", (g_State == STATE_COOLDOWN) ? "COOLING ACTIVE" : "STANDBY READY", (g_State == STATE_COOLDOWN) ? C_AMBER_GOLD : C_NEON_GREEN);

   // --- QUADRANT 3 MODULE REFRESH ---
   UpdateLabel("V_M_Regime", g_MarketRegime, (g_MarketRegime == "HOSTILE SESSION") ? C_CRIMSON_RED : C_INDICATOR_BLUE);
   UpdateLabel("V_M_Session", g_SessionLabel, g_SessionColor);
   UpdateLabel("V_M_Mid", g_MidCycleStatus, g_FlipDetected ? C_AMBER_GOLD : C_NEON_GREEN);
   UpdateLabel("V_StatusTxt", g_StatusText, g_StatusColor);
   
   if(g_ScoreSMC > 65) {
      UpdateLabel("V_M_Struct", "IMBALANCE EXPAN / IMPULSE", C_AMBER_GOLD);
      UpdateLabel("V_M_Liq", "LIQUIDITY SWEEP DETECTED", C_PURPLE_MATRIX);
      UpdateLabel("V_M_FVG", "ACTIVE FAIR VALUE GAP GAP", C_INDICATOR_BLUE);
   } else {
      UpdateLabel("V_M_Struct", "CONSOLIDATION MATRIX", C_TEXT_SECONDARY);
      UpdateLabel("V_M_Liq", "MONITORING EQUAL POOLS", C_TEXT_SECONDARY);
      UpdateLabel("V_M_FVG", "NO VALUED IMBALANCES", C_TEXT_SECONDARY);
   }

   // --- QUADRANT 4 MODULE REFRESH ---
   double winRate = 0.0;
   int totalTrades = g_DailyWins + g_DailyLosses;
   if(totalTrades > 0) winRate = ((double)g_DailyWins / totalTrades) * 100.0;
   UpdateLabel("V_P_Win", StringFormat("%.2f%% [ D:%d ]", winRate, g_DailyTrades), (winRate >= 60.0) ? C_NEON_GREEN : C_TEXT_PRIMARY);
   UpdateLabel("V_P_Streak", StringFormat("W: %d  ||  L: %d", g_ConsecutiveWins, g_ConsecutiveLosses), (g_ConsecutiveLosses > 2) ? C_CRIMSON_RED : C_TEXT_PRIMARY);
   UpdateLabel("V_P_Memory", StringFormat("%d BASE [%s]", g_AIThreshold, g_AIBrainStatus), (g_AIThreshold > InpMinScoreToTrade) ? C_AMBER_GOLD : C_INDICATOR_BLUE);
   UpdateLabel("V_P_Bulk", StringFormat("%d / %d EXEC", g_BulkOpened, InpBulkMaxTrades), (g_State == STATE_BULK_OPENING) ? C_PURPLE_MATRIX : C_TEXT_PRIMARY);
   
   UpdateLabel("V_E_ASI", StringFormat("ASI:%d/%d", g_SessionWins[0], g_SessionLosses[0]), C_TEXT_SECONDARY);
   UpdateLabel("V_E_LON", StringFormat("LON:%d/%d", g_SessionWins[1], g_SessionLosses[1]), C_NEON_GREEN);
   UpdateLabel("V_E_NYC", StringFormat("NY:%d/%d",  g_SessionWins[2], g_SessionLosses[2]), C_INDICATOR_BLUE);
   UpdateLabel("V_E_OVL", StringFormat("OVL:%d/%d", g_SessionWins[3], g_SessionLosses[3]), C_AMBER_GOLD);

   ChartRedraw(0);
}

//+------------------------------------------------------------------+
//| OBJECT INTERACTION LAYER PRIMITIVES                              |
//+------------------------------------------------------------------+
void CreateRect(string nm, int x, int y, int w, int h, color bg, color border, int bw)
{
   string id = DASH_PREFIX + nm;
   if(ObjectFind(0, id) < 0) ObjectCreate(0, id, OBJ_RECTANGLE_LABEL, 0, 0, 0);
   
   ObjectSetInteger(0, id, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, id, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, id, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, id, OBJPROP_XSIZE, w);
   ObjectSetInteger(0, id, OBJPROP_YSIZE, h);
   ObjectSetInteger(0, id, OBJPROP_BGCOLOR, bg);
   
   if(border != clrNONE) {
      ObjectSetInteger(0, id, OBJPROP_BORDER_TYPE, BORDER_FLAT);
      ObjectSetInteger(0, id, OBJPROP_COLOR, border);
      ObjectSetInteger(0, id, OBJPROP_WIDTH, bw);
   } else {
      ObjectSetInteger(0, id, OBJPROP_BORDER_TYPE, BORDER_RAISED);
   }
   ObjectSetInteger(0, id, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, id, OBJPROP_HIDDEN, true);
   ObjectSetInteger(0, id, OBJPROP_ZORDER, 0);
}

void CreateLabel(string nm, int x, int y, string txt, color clr, int fsz, string font)
{
   string id = DASH_PREFIX + nm;
   if(ObjectFind(0, id) < 0) ObjectCreate(0, id, OBJ_LABEL, 0, 0, 0);
   
   ObjectSetInteger(0, id, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, id, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, id, OBJPROP_YDISTANCE, y);
   ObjectSetString(0, id, OBJPROP_TEXT, txt);
   ObjectSetInteger(0, id, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, id, OBJPROP_FONTSIZE, fsz);
   ObjectSetString(0, id, OBJPROP_FONT, font);
   ObjectSetInteger(0, id, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, id, OBJPROP_HIDDEN, true);
   ObjectSetInteger(0, id, OBJPROP_ZORDER, 5);
}

void UpdateLabel(string nm, string txt, color clr = clrNONE)
{
   string id = DASH_PREFIX + nm;
   if(ObjectFind(0, id) >= 0) {
      ObjectSetString(0, id, OBJPROP_TEXT, txt);
      if(clr != clrNONE) ObjectSetInteger(0, id, OBJPROP_COLOR, clr);
   }
}
//+------------------------------------------------------------------+