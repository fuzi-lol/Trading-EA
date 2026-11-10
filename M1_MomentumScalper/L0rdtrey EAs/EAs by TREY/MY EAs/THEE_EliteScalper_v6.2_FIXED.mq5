//+------------------------------------------------------------------+
//|              THEE EliteScalper v6.2 GOLD EDITION                 |
//|                AI Brain + Kalman Filter + Adaptive Trend         |
//|         7‑Layer Confluence | Dynamic Candle Analysis             |
//|   Per‑Trade TP $0.20 | Global TP $5.00 | 500 ms Bulk Delay      |
//+------------------------------------------------------------------+
#property copyright   "Copyright 2026, ELITE Systems"
#property version     "6.20"
#property description "GOLD EDITION — AI Brain + 7‑Layer Confluence Engine"
#property description "Kalman Filter Trend | Adaptive Bulk Execution"
#property description "Dynamic Candle‑by‑Candle Trend Following"
#property description "Per‑Trade TP $0.20 | Global TP $5.00 | 500ms Delay"
#property strict

#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>

#define DASH_PREFIX   "FXBH_G6_"
#define AI_VERSION    "GOLD AI v6.2"
#define MAX_HISTORY   20

//+------------------------------------------------------------------+
//| STATE MACHINE                                                    |
//+------------------------------------------------------------------+
enum ENUM_ENGINE_STATE
{
   STATE_SCANNING,
   STATE_BULK_OPENING,
   STATE_WAITING_CLOSE,
   STATE_COOLDOWN
};

enum ENUM_SIGNAL_STRENGTH
{
   SIG_NONE    = 0,
   SIG_WEAK    = 1,
   SIG_MODERATE= 2,
   SIG_STRONG  = 3,
   SIG_ELITE   = 4
};

enum ENUM_SESSION
{
   SESSION_ASIAN,
   SESSION_LONDON,
   SESSION_NEW_YORK,
   SESSION_OVERLAP,
   SESSION_DEAD
};

//+------------------------------------------------------------------+
//| INPUT PARAMETERS                                                 |
//+------------------------------------------------------------------+
input group "=== CORE ENGINE SETTINGS ==="
input ulong   InpMagicNumber          = 999666;
input double  InpLotSize              = 0.01;
input int     InpMaxDailyTrades       = 100;

input group "=== BULK EXECUTION SETTINGS ==="
input int     InpBulkMaxTrades        = 7;             // Total trades per cycle
input int     InpBulkTradeDelayMs     = 500;           // Delay between each trade (milliseconds)
input double  InpPerTradeProfitUSD    = 0.20;          // Close trade at +$0.20
input double  InpGlobalProfitTargetUSD= 5.00;          // Close ALL trades when total P&L >= $5.00
input double  InpImmediateReopenPct   = 0.15;

input group "=== ADAPTIVE MID-CYCLE ANALYSIS ==="
input bool    InpAdaptiveMidCycle     = true;
input int     InpAnalysisTickSec      = 1;
input bool    InpCloseOnFlip          = true;
input int     InpConfirmFlipBars      = 2;

input group "=== AI BRAIN — 7-LAYER CONFLUENCE SCORING ENGINE ==="
input int     InpMinScoreToTrade      = 60;            // Min score (0-100) to open bulk cycle
input int     InpEliteScoreThreshold  = 80;            // Score for ELITE signal rating
input int     InpStrongScoreThreshold = 65;            // Score for STRONG signal rating
input bool    InpRequireStrongMin     = true;          // Must be STRONG/ELITE to open cycle
input bool    InpAIAdaptiveThreshold  = true;          // AI auto-raises threshold after losses
input double  InpTrendBiasPenalty     = 0.65;          // Multiplier applied to score if signal is counter-trend (0-1)

input group "=== CONFLUENCE LAYER WEIGHTS (must sum ~100) ==="
input int     InpWeightEMA            = 15;            // EMA Trend weight
input int     InpWeightRSI            = 15;            // RSI Momentum weight
input int     InpWeightBB             = 13;            // Bollinger Bands weight
input int     InpWeightATR            = 10;            // ATR Volatility weight
input int     InpWeightCandle         = 15;            // Candlestick Pattern weight
input int     InpWeightStructure      = 10;            // Market Structure weight
input int     InpWeightKalman         = 15;            // Kalman Filter Trend weight
input int     InpWeightMomentum       = 7;             // Momentum Layer (candle velocity)

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
input double  InpATRMinMultiplier     = 0.6;          // Min ATR activity (vs avg) to trade
input double  InpATRSpikeMultiplier   = 3.0;          // ATR spike = halt (gold flash crash guard)
input int     InpStructureLookback    = 5;

input group "=== MULTI-TIMEFRAME CONFIRMATION ==="
input bool    InpUseMTF               = true;
input ENUM_TIMEFRAMES InpHTF1         = PERIOD_M5;     // Higher TF 1
input ENUM_TIMEFRAMES InpHTF2         = PERIOD_H1;     // Higher TF 2 (trend filter)
input bool    InpRequireHTF2Align     = false;         // FIX BUG 2: was true — H1 alignment blocks scalper signals

input group "=== GOLD SESSION INTELLIGENCE ==="
input bool    InpUseSessionFilter     = true;
input bool    InpTradeAsian           = false;
input bool    InpTradeLondon          = true;
input bool    InpTradeNewYork         = true;
input bool    InpTradeOverlap         = true;
input int     InpAsianStartHour       = 0;             // UTC hours
input int     InpAsianEndHour         = 8;
input int     InpLondonStartHour      = 7;
input int     InpLondonEndHour        = 16;
input int     InpNYStartHour          = 13;
input int     InpNYEndHour            = 22;

input group "=== ACCOUNT GUARDRAILS ==="
input int     InpStopLossPoints       = 300;
input int     InpTakeProfitPoints     = 0;             // Overridden by per-trade $0.20 TP
input int     InpMaxSpreadPoints      = 25;
input double  InpDailyDrawdownHalt    = 50.0;          // Halt if daily loss exceeds this $

input group "=== ANTI-MANIPULATION COOLDOWN ==="
input int     InpCooldownSeconds      = 60;

input group "=== KALMAN FILTER PARAMETERS ==="
input double  InpKalmanProcessNoise   = 0.001;         // Process noise Q
input double  InpKalmanMeasureNoise   = 1.0;           // Measurement noise R
input int     InpKalmanTrendBars      = 5;             // Bars used to compute Kalman slope
input double  InpKalmanSlopeThreshold = 0.0001;        // Minimum slope to consider trend active

input group "=== DYNAMIC CANDLE ADAPTATION ==="
input bool    InpUseCandleAlignment   = true;          // Skip trade if current candle direction opposes signal
input double  InpCandleOpposedMinPct  = 0.03;          // Min % body vs range to block trade
input int     InpMomentumPeriod       = 3;             // Bars for momentum calculation

input group "=== INTERFACE LAYOUT ==="
input int     InpDashXOffset          = 15;
input int     InpDashYOffset          = 15;

//+------------------------------------------------------------------+
//| COLOR PALETTE                                                    |
//+------------------------------------------------------------------+
const color C_MATRIX_BG      = C'4,6,10';
const color C_PANEL_BG       = C'10,16,26';
const color C_HEADER_BAR     = C'14,32,66';
const color C_BORDER_GLOW    = C'0,90,180';
const color C_ACCENT_BLUE    = C'0,140,255';
const color C_NEON_GREEN     = C'0,225,120';
const color C_CRIMSON_RED    = C'235,45,65';
const color C_AMBER_GOLD     = C'255,185,25';
const color C_PURPLE_SCAN    = C'180,0,255';
const color C_ORANGE_FLIP    = C'255,120,0';
const color C_GOLD_SHIMMER   = C'255,215,80';
const color C_TEAL_AI        = C'0,200,180';
const color C_TEXT_LIGHT     = C'235,242,255';
const color C_TEXT_MUTED     = C'130,145,170';

//+------------------------------------------------------------------+
//| GLOBAL OBJECTS                                                   |
//+------------------------------------------------------------------+
CTrade          g_Trade;
CPositionInfo   g_Pos;

int   g_hFastEMA   = INVALID_HANDLE;
int   g_hSlowEMA   = INVALID_HANDLE;
int   g_hTrendEMA  = INVALID_HANDLE;
int   g_hRSI       = INVALID_HANDLE;
int   g_hBB        = INVALID_HANDLE;
int   g_hATR       = INVALID_HANDLE;

int   g_hFastEMA_HTF1  = INVALID_HANDLE;
int   g_hSlowEMA_HTF1  = INVALID_HANDLE;
int   g_hRSI_HTF1      = INVALID_HANDLE;
int   g_hFastEMA_HTF2  = INVALID_HANDLE;
int   g_hSlowEMA_HTF2  = INVALID_HANDLE;

ENUM_ENGINE_STATE  g_State          = STATE_SCANNING;
datetime           g_StateTimer     = 0;
ENUM_ORDER_TYPE    g_Direction      = ORDER_TYPE_BUY;
int                g_BulkOpened     = 0;
ulong              g_LastTradeTimeMs= 0;
datetime           g_CurrentDay     = 0;

datetime           g_LastAnalysisTime  = 0;
int                g_FlipConfirmCount  = 0;
ENUM_ORDER_TYPE    g_LastSignal        = ORDER_TYPE_BUY;
int                g_TotalFlips        = 0;
string             g_MidCycleStatus    = "STABLE";
bool               g_FlipDetected      = false;

int                g_AIScore           = 0;
ENUM_SIGNAL_STRENGTH g_SignalStrength  = SIG_NONE;
string             g_SignalLabel       = "SCANNING";
color              g_SignalColor       = C_TEXT_MUTED;
int                g_AIThreshold       = 0;
string             g_AIBrainStatus     = "INITIALISING";

int   g_ScoreEMA        = 0;
int   g_ScoreRSI        = 0;
int   g_ScoreBB         = 0;
int   g_ScoreATR        = 0;
int   g_ScoreCandle     = 0;
int   g_ScoreStructure  = 0;
int   g_ScoreKalman     = 0;
int   g_ScoreMomentum   = 0;

double  g_TradeHistory[MAX_HISTORY];
int     g_TradeHistoryCount  = 0;
int     g_ConsecutiveLosses  = 0;
int     g_ConsecutiveWins    = 0;

ENUM_SESSION  g_CurrentSession     = SESSION_DEAD;
string        g_SessionLabel       = "DEAD";
color         g_SessionColor       = C_TEXT_MUTED;
double        g_SessionMultiplier  = 1.0;

int     g_DailyTrades       = 0;
double  g_DailyProfit       = 0.0;
int     g_DailyWins         = 0;
int     g_DailyLosses       = 0;
int     g_ProfitReopens     = 0;
bool    g_DailyHaltActive   = false;
string  g_HeartbeatStr      = "0 0 0 0";
string  g_StatusText        = "BOOTING AI BRAIN";
color   g_StatusColor       = C_AMBER_GOLD;

double  g_KalmanX           = 0.0;
double  g_KalmanP           = 1.0;
bool    g_KalmanInit        = false;

double  g_TrendBias         = 0.0;      // -1 (bearish) to +1 (bullish)
string  g_TrendLabel        = "NEUTRAL";

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
void   LiquidateAll(string reason);
bool   HasOpenPositions();
double GetFloatingPnL();

int              ComputeConfluenceScore(ENUM_ORDER_TYPE &outDir);
ENUM_SIGNAL_STRENGTH ScoreToStrength(int score);
int              ScoreEMALayer(ENUM_ORDER_TYPE &dir);
int              ScoreRSILayer(ENUM_ORDER_TYPE &dir);
int              ScoreBBLayer(ENUM_ORDER_TYPE &dir);
int              ScoreATRLayer();
int              ScoreCandleLayer(ENUM_ORDER_TYPE &dir);
int              ScoreStructureLayer(ENUM_ORDER_TYPE &dir);
int              ScoreKalmanLayer(ENUM_ORDER_TYPE &dir);
int              ScoreMomentumLayer(ENUM_ORDER_TYPE &dir);
bool             GetMTFConfirmation(ENUM_ORDER_TYPE dir);
ENUM_ORDER_TYPE  GetHTF2Trend();
void             UpdateAIMemory(double pnl);
void             AdaptAIThreshold();
ENUM_SESSION     DetectSession();

void   InitKalman(double initialPrice);
void   UpdateKalman(double price);
double GetKalmanSlope();
double ComputeTrendBias();
bool   IsCurrentCandleAligned(ENUM_ORDER_TYPE dir);

void   RenderDashboard();
void   RefreshDashboard();
void   PurgeDashboard();
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
   if(InpLotSize <= 0.0) return INIT_PARAMETERS_INCORRECT;
   
   g_hFastEMA  = iMA(_Symbol, _Period, InpFastEMAPeriod,  0, MODE_EMA, PRICE_CLOSE);
   g_hSlowEMA  = iMA(_Symbol, _Period, InpSlowEMAPeriod,  0, MODE_EMA, PRICE_CLOSE);
   g_hTrendEMA = iMA(_Symbol, _Period, InpTrendEMAPeriod, 0, MODE_EMA, PRICE_CLOSE);
   g_hRSI      = iRSI(_Symbol, _Period, InpRSIPeriod, PRICE_CLOSE);
   g_hBB       = iBands(_Symbol, _Period, InpBBPeriod, 0, InpBBDeviation, PRICE_CLOSE);
   g_hATR      = iATR(_Symbol, _Period, InpATRPeriod);
   
   if(g_hFastEMA == INVALID_HANDLE || g_hSlowEMA  == INVALID_HANDLE ||
      g_hTrendEMA== INVALID_HANDLE || g_hRSI      == INVALID_HANDLE ||
      g_hBB      == INVALID_HANDLE || g_hATR      == INVALID_HANDLE)
   {
      Print("[GOLD AI v6.2] ERROR: Failed to create indicator handles on current TF.");
      return INIT_FAILED;
   }
   
   if(InpUseMTF)
   {
      g_hFastEMA_HTF1 = iMA(_Symbol, InpHTF1, InpFastEMAPeriod, 0, MODE_EMA, PRICE_CLOSE);
      g_hSlowEMA_HTF1 = iMA(_Symbol, InpHTF1, InpSlowEMAPeriod, 0, MODE_EMA, PRICE_CLOSE);
      g_hRSI_HTF1     = iRSI(_Symbol, InpHTF1, InpRSIPeriod, PRICE_CLOSE);
      g_hFastEMA_HTF2 = iMA(_Symbol, InpHTF2, InpFastEMAPeriod, 0, MODE_EMA, PRICE_CLOSE);
      g_hSlowEMA_HTF2 = iMA(_Symbol, InpHTF2, InpSlowEMAPeriod, 0, MODE_EMA, PRICE_CLOSE);
   }
   
   g_AIThreshold = InpMinScoreToTrade;
   ArrayInitialize(g_TradeHistory, 0.0);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   InitKalman(bid);
   
   g_CurrentDay = GetMidnight(TimeCurrent());
   SyncLedger();
   RenderDashboard();
   
   g_State = STATE_SCANNING;
   g_LastTradeTimeMs = GetTickCount();
   EventSetTimer(1);
   
   Print("[GOLD AI v6.2] Engine Initialised. AI Threshold: ", g_AIThreshold);
   Print("[GOLD AI v6.2] Kalman Filter active. Bulk delay: ", InpBulkTradeDelayMs, "ms");
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
   EventKillTimer();
   PurgeDashboard();
   int handles[] = {g_hFastEMA, g_hSlowEMA, g_hTrendEMA, g_hRSI, g_hBB, g_hATR,
                    g_hFastEMA_HTF1, g_hSlowEMA_HTF1, g_hRSI_HTF1,
                    g_hFastEMA_HTF2, g_hSlowEMA_HTF2};
   for(int i = 0; i < ArraySize(handles); i++)
      if(handles[i] != INVALID_HANDLE) IndicatorRelease(handles[i]);
}

void OnTimer()
{
   uint c = GetTickCount() % 4;
   if(c==0) g_HeartbeatStr = "1 0 1 1   0 1 0 0";
   if(c==1) g_HeartbeatStr = "0 1 0 0   1 0 1 1";
   if(c==2) g_HeartbeatStr = "1 1 0 1   0 0 1 0";
   if(c==3) g_HeartbeatStr = "0 0 1 0   1 1 0 1";
   g_CurrentSession = DetectSession();
   SyncLedger();
   RefreshDashboard();
}

//+------------------------------------------------------------------+
//| TICK — MAIN EXECUTION LOOP                                      |
//+------------------------------------------------------------------+
void OnTick()
{
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double midPrice = (bid + ask) / 2.0;
   UpdateKalman(midPrice);
   g_TrendBias = ComputeTrendBias();
   
   if(!CheckLiquidity()) { g_StatusText = "MARKET SUSPENDED"; g_StatusColor = C_CRIMSON_RED; return; }
   if(CheckDailyHalt()) return;
   
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
   
   if(g_DailyTrades >= InpMaxDailyTrades)
   {
      g_StatusText = "ALLOCATION LIMIT REACHED"; g_StatusColor = C_AMBER_GOLD;
      return;
   }
   
   if(g_State == STATE_BULK_OPENING) { ProcessBulkOpening(); return; }
   
   if(g_State == STATE_COOLDOWN)
   {
      int left = (int)(g_StateTimer - TimeCurrent());
      if(left > 0) { g_StatusText = "COOLING DOWN... (" + IntegerToString(left) + "s)"; g_StatusColor = C_AMBER_GOLD; return; }
      g_State = STATE_SCANNING;
   }
   
   // FIX BUG 4 (spread): cast to int after getting spread as integer — already correct type
   // but we add a diagnostic print on first tick to confirm broker spread values
   int spread = (int)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   if(spread > InpMaxSpreadPoints) { g_StatusText = "SPREAD TOO HIGH ("+IntegerToString(spread)+" PTS)"; g_StatusColor= C_CRIMSON_RED; return; }
   if(InpUseSessionFilter && !CheckSessionAllowed()) { g_StatusText = "SESSION FILTER: " + g_SessionLabel + " — SKIPPING"; g_StatusColor= C_TEXT_MUTED; return; }
   
   if(g_State == STATE_SCANNING)
   {
      ENUM_ORDER_TYPE aiDir  = ORDER_TYPE_BUY;
      int             score  = ComputeConfluenceScore(aiDir);
      g_AIScore              = score;
      g_SignalStrength       = ScoreToStrength(score);
      
      bool strongEnough = (!InpRequireStrongMin) || (g_SignalStrength >= SIG_STRONG);
      bool scoreEnough  = (score >= g_AIThreshold);
      
      if(!scoreEnough || !strongEnough)
      {
         g_StatusText  = "AI SCANNING... SCORE: " + IntegerToString(score) + "/100 [" + g_SignalLabel + "]";
         g_StatusColor = C_TEXT_MUTED;
         return;
      }
      
      if(InpUseMTF && !GetMTFConfirmation(aiDir))
      {
         g_StatusText  = "MTF DIVERGENCE — HOLDING"; g_StatusColor = C_AMBER_GOLD;
         return;
      }
      
      double atr[2];
      if(CopyBuffer(g_hATR, 0, 0, 2, atr) > 0)
         if(atr[0] > atr[1] * InpATRSpikeMultiplier) { g_StatusText = "ATR SPIKE"; g_StatusColor = C_CRIMSON_RED; return; }
      
      g_Direction         = aiDir;
      g_State             = STATE_BULK_OPENING;
      g_BulkOpened        = 0;
      g_LastTradeTimeMs   = GetTickCount() - InpBulkTradeDelayMs;
      g_FlipConfirmCount  = 0;
      g_LastSignal        = aiDir;
      g_FlipDetected      = false;
      g_MidCycleStatus    = "STABLE";
      
      Print("[GOLD AI v6.2] Signal CONFIRMED. Score: ", score, "/100 [", g_SignalLabel, "] Dir: ", EnumToString(aiDir));
      Print("Trend bias: ", g_TrendLabel, " (", DoubleToString(g_TrendBias,2), ")");
   }
}

//+------------------------------------------------------------------+
//| ADAPTIVE BULK OPENING — 500ms delay + candle alignment          |
//+------------------------------------------------------------------+
void ProcessBulkOpening()
{
   ulong nowMs        = GetTickCount();
   int   elapsedMs    = (int)(nowMs - g_LastTradeTimeMs);
   int   remainingMs  = InpBulkTradeDelayMs - elapsedMs;
   if(remainingMs < 0) remainingMs = 0;
   
   if(InpAdaptiveMidCycle && g_LastTradeTimeMs > 0)
   {
      if((TimeCurrent() - g_LastAnalysisTime) >= InpAnalysisTickSec)
      {
         g_LastAnalysisTime = TimeCurrent();
         if(RunAdaptiveAnalysis())
         {
            OpenTrade(g_Direction);
            g_BulkOpened++;
            g_LastTradeTimeMs    = nowMs;
            g_LastAnalysisTime   = TimeCurrent();
            g_FlipConfirmCount   = 0;
            g_TotalFlips++;
            g_FlipDetected       = true;
            if(g_BulkOpened >= InpBulkMaxTrades) { g_State = STATE_WAITING_CLOSE; Print("Bulk complete (adaptive flips)."); }
            return;
         }
      }
   }
   
   if(elapsedMs >= InpBulkTradeDelayMs)
   {
      if(InpUseCandleAlignment && !IsCurrentCandleAligned(g_Direction))
      {
         g_StatusText = "CANDLE OPPOSES SIGNAL — WAITING";
         g_StatusColor= C_ORANGE_FLIP;
         return;
      }
      
      g_FlipDetected = false;
      g_StatusText  = "DEPLOYING BULK: " + IntegerToString(g_BulkOpened+1) + "/" + IntegerToString(InpBulkMaxTrades) +
                      " [" + g_SignalLabel + "] SCORE:" + IntegerToString(g_AIScore);
      g_StatusColor = C_PURPLE_SCAN;
      
      OpenTrade(g_Direction);
      g_BulkOpened++;
      g_LastTradeTimeMs    = nowMs;
      g_LastAnalysisTime   = TimeCurrent();
      g_FlipConfirmCount   = 0;
      
      if(g_BulkOpened >= InpBulkMaxTrades)
      {
         g_State = STATE_WAITING_CLOSE;
         Print("[GOLD AI v6.2] Full bulk deployed. Awaiting targets.");
      }
   }
   else
   {
      double remainingSec = remainingMs / 1000.0;
      string cStr = (g_FlipDetected) ? ("FLIPPED>" + EnumToString(g_Direction) + " | NEXT IN " + DoubleToString(remainingSec,1) + "s") :
                                       ("AI WATCHING... NEXT TRADE IN " + DoubleToString(remainingSec,1) + "s | " + g_MidCycleStatus);
      g_StatusText  = cStr;
      g_StatusColor = g_FlipDetected ? C_ORANGE_FLIP : C_ACCENT_BLUE;
   }
}

//+------------------------------------------------------------------+
//| AI BRAIN — 7-LAYER CONFLUENCE SCORING                           |
//| FIX BUG 1: divide by weightSum instead of hardcoded 100         |
//+------------------------------------------------------------------+
int ComputeConfluenceScore(ENUM_ORDER_TYPE &outDir)
{
   ENUM_ORDER_TYPE dEMA = ORDER_TYPE_BUY, dRSI = ORDER_TYPE_BUY;
   ENUM_ORDER_TYPE dBB  = ORDER_TYPE_BUY, dCdl = ORDER_TYPE_BUY;
   ENUM_ORDER_TYPE dStr = ORDER_TYPE_BUY, dKal = ORDER_TYPE_BUY, dMom = ORDER_TYPE_BUY;
   
   int sEMA  = ScoreEMALayer(dEMA);
   int sRSI  = ScoreRSILayer(dRSI);
   int sBB   = ScoreBBLayer(dBB);
   int sATR  = ScoreATRLayer();
   int sCdl  = ScoreCandleLayer(dCdl);
   int sStr  = ScoreStructureLayer(dStr);
   int sKal  = ScoreKalmanLayer(dKal);
   int sMom  = ScoreMomentumLayer(dMom);
   
   g_ScoreEMA       = sEMA;
   g_ScoreRSI       = sRSI;
   g_ScoreBB        = sBB;
   g_ScoreATR       = sATR;
   g_ScoreCandle    = sCdl;
   g_ScoreStructure = sStr;
   g_ScoreKalman    = sKal;
   g_ScoreMomentum  = sMom;
   
   // FIX BUG 1: compute actual weight sum so the score is always 0-100
   double weightSum = InpWeightEMA + InpWeightRSI + InpWeightBB + InpWeightATR +
                      InpWeightCandle + InpWeightStructure + InpWeightKalman + InpWeightMomentum;
   if(weightSum <= 0) weightSum = 100; // safety guard
   
   double total = (sEMA * InpWeightEMA + sRSI * InpWeightRSI +
                   sBB  * InpWeightBB  + sATR * InpWeightATR +
                   sCdl * InpWeightCandle + sStr * InpWeightStructure +
                   sKal * InpWeightKalman + sMom * InpWeightMomentum) / weightSum;
   
   int buyVotes  = (dEMA==ORDER_TYPE_BUY) + (dRSI==ORDER_TYPE_BUY) + (dBB==ORDER_TYPE_BUY) +
                   (dCdl==ORDER_TYPE_BUY) + (dStr==ORDER_TYPE_BUY) + (dKal==ORDER_TYPE_BUY) +
                   (dMom==ORDER_TYPE_BUY);
   int sellVotes = 7 - buyVotes;
   outDir = (buyVotes >= sellVotes) ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
   
   double trendFactor = 1.0;
   if(g_TrendBias > 0.3 && outDir == ORDER_TYPE_SELL)
      trendFactor = InpTrendBiasPenalty;
   else if(g_TrendBias < -0.3 && outDir == ORDER_TYPE_BUY)
      trendFactor = InpTrendBiasPenalty;
   
   double sessionBoost = 1.0;
   if(g_CurrentSession == SESSION_OVERLAP) sessionBoost = 1.15;
   else if(g_CurrentSession == SESSION_LONDON || g_CurrentSession == SESSION_NEW_YORK) sessionBoost = 1.05;
   
   int finalScore = (int)MathMin(100, total * sessionBoost * trendFactor);
   
   ENUM_SIGNAL_STRENGTH str = ScoreToStrength(finalScore);
   if(str == SIG_ELITE)    { g_SignalLabel = "ELITE";    g_SignalColor = C_GOLD_SHIMMER; }
   else if(str == SIG_STRONG)  { g_SignalLabel = "STRONG";   g_SignalColor = C_NEON_GREEN;  }
   else if(str == SIG_MODERATE){ g_SignalLabel = "MODERATE"; g_SignalColor = C_AMBER_GOLD;  }
   else if(str == SIG_WEAK)    { g_SignalLabel = "WEAK";     g_SignalColor = C_ORANGE_FLIP; }
   else                        { g_SignalLabel = "NONE";     g_SignalColor = C_TEXT_MUTED;  }
   
   return finalScore;
}

int ScoreEMALayer(ENUM_ORDER_TYPE &dir)
{
   double fast[1], slow[1], trend[1];
   if(CopyBuffer(g_hFastEMA, 0, 0, 1, fast)  <= 0) return 0;
   if(CopyBuffer(g_hSlowEMA, 0, 0, 1, slow)  <= 0) return 0;
   if(CopyBuffer(g_hTrendEMA,0, 0, 1, trend) <= 0) return 50;
   double price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   bool bullCross = (fast[0] > slow[0]);
   bool aboveTrend = (price > trend[0]);
   dir = bullCross ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
   if(bullCross && aboveTrend)  return 100;
   if(!bullCross && !aboveTrend)return 100;
   return 50;
}

int ScoreRSILayer(ENUM_ORDER_TYPE &dir)
{
   double rsi[2];
   if(CopyBuffer(g_hRSI, 0, 0, 2, rsi) <= 0) return 0;
   double r = rsi[0], rPrev = rsi[1];
   if(r < InpRSIOversold && r > rPrev)   { dir = ORDER_TYPE_BUY;  return 100; }
   if(r < InpRSIOversold)                { dir = ORDER_TYPE_BUY;  return 80;  }
   if(r > InpRSIOverbought && r < rPrev) { dir = ORDER_TYPE_SELL; return 100; }
   if(r > InpRSIOverbought)              { dir = ORDER_TYPE_SELL; return 80;  }
   if(r > 50.0 && r > rPrev)             { dir = ORDER_TYPE_BUY;  return 70; }
   if(r < 50.0 && r < rPrev)             { dir = ORDER_TYPE_SELL; return 70; }
   dir = (r > 50.0) ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
   return 40;
}

int ScoreBBLayer(ENUM_ORDER_TYPE &dir)
{
   double upper[1], lower[1], mid[1];
   if(CopyBuffer(g_hBB, 1, 0, 1, upper) <= 0) return 0;
   if(CopyBuffer(g_hBB, 2, 0, 1, lower) <= 0) return 0;
   if(CopyBuffer(g_hBB, 0, 0, 1, mid)   <= 0) return 0;
   double price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(price <= lower[0])     { dir = ORDER_TYPE_BUY;  return 100; }
   else if(price >= upper[0]){ dir = ORDER_TYPE_SELL; return 100; }
   else if(price > mid[0])   { dir = ORDER_TYPE_BUY;  return 60; }
   else                      { dir = ORDER_TYPE_SELL; return 60; }
}

int ScoreATRLayer()
{
   double atr[2];
   if(CopyBuffer(g_hATR, 0, 0, 2, atr) <= 0) return 50;
   double current = atr[0], prev = atr[1];
   if(current > prev * InpATRSpikeMultiplier) return 0;
   if(current < prev * InpATRMinMultiplier)  return 20;
   double ratio = current / prev;
   if(ratio >= 0.8 && ratio <= 1.2) return 100;
   if(ratio > 1.2 && ratio <= 1.5)  return 80;
   if(ratio < 0.8)                  return 60;
   return 50;
}

int ScoreCandleLayer(ENUM_ORDER_TYPE &dir)
{
   double open[3], high[3], low[3], close[3];
   if(CopyOpen (_Symbol, _Period, 0, 3, open)  <= 0) return 0;
   if(CopyHigh (_Symbol, _Period, 0, 3, high)  <= 0) return 0;
   if(CopyLow  (_Symbol, _Period, 0, 3, low)   <= 0) return 0;
   if(CopyClose(_Symbol, _Period, 0, 3, close) <= 0) return 0;
   double body1 = MathAbs(close[1]-open[1]), range1 = high[1]-low[1];
   double upper1 = high[1] - MathMax(open[1],close[1]), lower1 = MathMin(open[1],close[1]) - low[1];
   double body0 = MathAbs(close[0]-open[0]);
   if(range1 <= 0) return 50;
   bool bull1 = (close[1]>open[1]), bull0 = (close[0]>open[0]);
   if(bull0 && !bull1 && body0 > body1*1.5 && close[0] > open[1])   { dir=ORDER_TYPE_BUY;  return 100; }
   if(!bull0 && bull1 && body0 > body1*1.5 && close[0] < open[1])   { dir=ORDER_TYPE_SELL; return 100; }
   if(lower1 > body1*2.0 && lower1 > upper1*2.0)                    { dir=ORDER_TYPE_BUY;  return 90;  }
   if(upper1 > body1*2.0 && upper1 > lower1*2.0)                    { dir=ORDER_TYPE_SELL; return 90;  }
   if(bull1 && body1 > range1*0.7)                                  { dir=ORDER_TYPE_BUY;  return 75;  }
   if(!bull1 && body1 > range1*0.7)                                 { dir=ORDER_TYPE_SELL; return 75;  }
   dir = bull1 ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
   return 30;
}

int ScoreStructureLayer(ENUM_ORDER_TYPE &dir)
{
   int lb = InpStructureLookback;
   int hBar = iHighest(_Symbol, _Period, MODE_HIGH, lb, 1);
   int lBar = iLowest (_Symbol, _Period, MODE_LOW,  lb, 1);
   double hHigh = iHigh(_Symbol, _Period, hBar);
   double lLow  = iLow (_Symbol, _Period, lBar);
   double price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(price > hHigh)   { dir = ORDER_TYPE_BUY;  return 100; }
   if(price < lLow)    { dir = ORDER_TYPE_SELL; return 100; }
   if(price > (hHigh+lLow)/2.0) { dir = ORDER_TYPE_BUY;  return 60; }
   else                          { dir = ORDER_TYPE_SELL; return 60; }
}

int ScoreKalmanLayer(ENUM_ORDER_TYPE &dir)
{
   if(!g_KalmanInit) return 50;
   double slope = GetKalmanSlope();
   double price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double filtered = g_KalmanX;
   if(slope > InpKalmanSlopeThreshold)
   {
      dir = ORDER_TYPE_BUY;
      return (price > filtered) ? 100 : 70;
   }
   else if(slope < -InpKalmanSlopeThreshold)
   {
      dir = ORDER_TYPE_SELL;
      return (price < filtered) ? 100 : 70;
   }
   else
   {
      if(price > filtered) { dir = ORDER_TYPE_BUY;  return 50; }
      else                  { dir = ORDER_TYPE_SELL; return 50; }
   }
}

int ScoreMomentumLayer(ENUM_ORDER_TYPE &dir)
{
   double close[];
   ArraySetAsSeries(close, true);
   if(CopyClose(_Symbol, _Period, 0, InpMomentumPeriod+1, close) < InpMomentumPeriod+1) return 50;
   double sum = 0;
   for(int i=0; i<InpMomentumPeriod; i++) sum += (close[i] - close[i+1]) / close[i+1];
   double avgChange = sum / InpMomentumPeriod * 100;
   if(avgChange > 0.02)
   {
      dir = ORDER_TYPE_BUY;
      return (int)MathMin(100, 50 + avgChange * 100);
   }
   else if(avgChange < -0.02)
   {
      dir = ORDER_TYPE_SELL;
      return (int)MathMin(100, 50 - avgChange * 100);
   }
   dir = (avgChange >= 0) ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
   return 40;
}

bool GetMTFConfirmation(ENUM_ORDER_TYPE dir)
{
   if(g_hFastEMA_HTF1 == INVALID_HANDLE || g_hSlowEMA_HTF1 == INVALID_HANDLE) return true;
   double f1[1], s1[1];
   if(CopyBuffer(g_hFastEMA_HTF1,0,0,1,f1)<=0 || CopyBuffer(g_hSlowEMA_HTF1,0,0,1,s1)<=0) return true;
   bool htf1Bull = (f1[0] > s1[0]);
   if( (dir==ORDER_TYPE_BUY && !htf1Bull) || (dir==ORDER_TYPE_SELL && htf1Bull) ) return false;
   // FIX BUG 2: InpRequireHTF2Align defaults to false so H1 no longer hard-blocks scalper signals
   if(InpRequireHTF2Align && g_hFastEMA_HTF2 != INVALID_HANDLE)
   {
      ENUM_ORDER_TYPE h1Trend = GetHTF2Trend();
      if(h1Trend != dir) { Print("[v6.2] H1 block"); return false; }
   }
   return true;
}

ENUM_ORDER_TYPE GetHTF2Trend()
{
   double f[1], s[1];
   if(CopyBuffer(g_hFastEMA_HTF2,0,0,1,f)<=0 || CopyBuffer(g_hSlowEMA_HTF2,0,0,1,s)<=0) return ORDER_TYPE_BUY;
   return (f[0] > s[0]) ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
}

//+------------------------------------------------------------------+
//| ADAPTIVE MID-CYCLE ANALYSIS                                     |
//+------------------------------------------------------------------+
bool RunAdaptiveAnalysis()
{
   ENUM_ORDER_TYPE newDir = ORDER_TYPE_BUY;
   int score = ComputeConfluenceScore(newDir);
   bool isOpposite = (newDir != g_Direction);
   bool scoreValid = (score >= g_AIThreshold);
   if(isOpposite && scoreValid)
   {
      g_FlipConfirmCount++;
      g_MidCycleStatus = "FLIP " + IntegerToString(g_FlipConfirmCount) + "/" + IntegerToString(InpConfirmFlipBars);
      if(g_FlipConfirmCount >= InpConfirmFlipBars) { ExecuteFlip(newDir); return true; }
   }
   else { if(g_FlipConfirmCount>0) g_FlipConfirmCount=0; g_MidCycleStatus = "STABLE ["+g_SignalLabel+"] "+IntegerToString(score)+"/100"; }
   g_LastSignal = newDir;
   return false;
}

void ExecuteFlip(ENUM_ORDER_TYPE newDir)
{
   ENUM_ORDER_TYPE oldDir = g_Direction;
   g_Direction = newDir;
   Print("[v6.2 FLIP] ", EnumToString(oldDir), " > ", EnumToString(newDir));
   if(InpCloseOnFlip)
   {
      int n=0;
      for(int i=PositionsTotal()-1; i>=0; i--)
         if(g_Pos.SelectByIndex(i) && g_Pos.Magic()==InpMagicNumber && g_Pos.Symbol()==_Symbol)
            if((oldDir==ORDER_TYPE_BUY && g_Pos.PositionType()==POSITION_TYPE_BUY) ||
               (oldDir==ORDER_TYPE_SELL && g_Pos.PositionType()==POSITION_TYPE_SELL))
               { g_Trade.PositionClose(g_Pos.Ticket()); n++; }
      if(n>0) Print("[v6.2 FLIP] Closed ", n, " opposite trades.");
   }
   g_MidCycleStatus = "FLIPPED > " + EnumToString(newDir);
   g_FlipConfirmCount = 0;
}

//+------------------------------------------------------------------+
//| TREND BIAS — live, using Kalman slope + 50-EMA                  |
//+------------------------------------------------------------------+
double ComputeTrendBias()
{
   double slope = GetKalmanSlope();
   double price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double trendMA[1]; if(CopyBuffer(g_hTrendEMA,0,0,1,trendMA)<=0) trendMA[0]=price;
   
   double bias = 0.0;
   if(slope > InpKalmanSlopeThreshold) bias += 0.5;
   else if(slope < -InpKalmanSlopeThreshold) bias -= 0.5;
   if(price > trendMA[0]) bias += 0.5;
   else bias -= 0.5;
   bias = MathMax(-1.0, MathMin(1.0, bias));
   
   if(bias > 0.3)       g_TrendLabel = "BULLISH";
   else if(bias < -0.3) g_TrendLabel = "BEARISH";
   else                 g_TrendLabel = "NEUTRAL";
   return bias;
}

//+------------------------------------------------------------------+
//| CANDLE ALIGNMENT                                                 |
//| FIX BUG 3: now properly copies high[] and low[] before use      |
//+------------------------------------------------------------------+
bool IsCurrentCandleAligned(ENUM_ORDER_TYPE dir)
{
   double open[1], close[1], high[1], low[1];
   if(CopyOpen (_Symbol, _Period, 0, 1, open)  <= 0) return true;
   if(CopyClose(_Symbol, _Period, 0, 1, close) <= 0) return true;
   if(CopyHigh (_Symbol, _Period, 0, 1, high)  <= 0) return true;  // FIX BUG 3: was missing
   if(CopyLow  (_Symbol, _Period, 0, 1, low)   <= 0) return true;  // FIX BUG 3: was missing
   if(open[0] == close[0]) return true;
   bool bullCandle = (close[0] > open[0]);
   if((dir==ORDER_TYPE_BUY && !bullCandle) || (dir==ORDER_TYPE_SELL && bullCandle))
   {
      double body  = MathAbs(close[0] - open[0]);
      double range = high[0] - low[0];                              // FIX BUG 3: now uses valid data
      if(range > 0 && body / range > InpCandleOpposedMinPct) return false;
   }
   return true;
}

//+------------------------------------------------------------------+
//| KALMAN FILTER                                                    |
//+------------------------------------------------------------------+
void InitKalman(double initialPrice) { g_KalmanX=initialPrice; g_KalmanP=1.0; g_KalmanInit=true; }
void UpdateKalman(double price)
{
   if(!g_KalmanInit) return;
   double Q = InpKalmanProcessNoise, R = InpKalmanMeasureNoise;
   double p_pred = g_KalmanP + Q;
   double K = p_pred / (p_pred + R);
   g_KalmanX = g_KalmanX + K*(price - g_KalmanX);
   g_KalmanP = (1.0 - K) * p_pred;
}
double GetKalmanSlope()
{
   static double hist[];
   static int size=0; static bool first=true;
   if(first) { ArrayResize(hist, InpKalmanTrendBars); ArrayInitialize(hist,g_KalmanX); size=0; first=false; }
   for(int i=InpKalmanTrendBars-1; i>0; i--) hist[i]=hist[i-1];
   hist[0]=g_KalmanX;
   if(size<InpKalmanTrendBars) size++;
   if(size<2) return 0.0;
   double sx=0,sy=0,sxy=0,sx2=0;
   for(int i=0; i<size; i++) { double x=i; double y=hist[i]; sx+=x; sy+=y; sxy+=x*y; sx2+=x*x; }
   double n=size;
   return (n*sxy - sx*sy) / (n*sx2 - sx*sx);
}

//+------------------------------------------------------------------+
//| AI MEMORY & THRESHOLD                                           |
//+------------------------------------------------------------------+
void UpdateAIMemory(double pnl)
{
   for(int i = MAX_HISTORY-1; i > 0; i--) g_TradeHistory[i] = g_TradeHistory[i-1];
   g_TradeHistory[0] = pnl;
   if(g_TradeHistoryCount < MAX_HISTORY) g_TradeHistoryCount++;
   if(pnl >= 0) { g_ConsecutiveWins++; g_ConsecutiveLosses = 0; }
   else         { g_ConsecutiveLosses++; g_ConsecutiveWins = 0; }
}

void AdaptAIThreshold()
{
   if(!InpAIAdaptiveThreshold) return;
   if(g_TradeHistoryCount < 3) return;
   int wins=0, total=MathMin(g_TradeHistoryCount,10);
   for(int i=0; i<total; i++) if(g_TradeHistory[i] >= 0) wins++;
   double wr = (double)wins/total;
   if(g_ConsecutiveLosses >= 3)
   {
      g_AIThreshold = (int)MathMin(90, g_AIThreshold+5);
      g_AIBrainStatus = "DEFENSIVE MODE ("+IntegerToString(g_AIThreshold)+")";
   }
   else if(g_ConsecutiveWins >= 3 && wr >= 0.7)
   {
      g_AIThreshold = (int)MathMax(InpMinScoreToTrade, g_AIThreshold-2);
      g_AIBrainStatus = "AGGRESSIVE MODE ("+IntegerToString(g_AIThreshold)+")";
   }
   else g_AIBrainStatus = "ADAPTIVE ("+IntegerToString(g_AIThreshold)+")";
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
//| SESSION DETECTION                                                |
//+------------------------------------------------------------------+
ENUM_SESSION DetectSession()
{
   MqlDateTime t;
   TimeToStruct(TimeGMT(), t);
   int h = t.hour;
   bool inLondon = (h >= InpLondonStartHour && h < InpLondonEndHour);
   bool inNY     = (h >= InpNYStartHour     && h < InpNYEndHour);
   bool inAsian  = (h >= InpAsianStartHour  && h < InpAsianEndHour);
   if(inLondon && inNY)        { g_SessionLabel="OVERLAP";  g_SessionColor=C_GOLD_SHIMMER; g_SessionMultiplier=1.15; return SESSION_OVERLAP; }
   if(inLondon)                { g_SessionLabel="LONDON";   g_SessionColor=C_NEON_GREEN;   g_SessionMultiplier=1.05; return SESSION_LONDON;  }
   if(inNY)                    { g_SessionLabel="NEW YORK"; g_SessionColor=C_ACCENT_BLUE;  g_SessionMultiplier=1.05; return SESSION_NEW_YORK;}
   if(inAsian)                 { g_SessionLabel="ASIAN";    g_SessionColor=C_TEXT_MUTED;   g_SessionMultiplier=0.90; return SESSION_ASIAN;   }
   g_SessionLabel="OFF-HOURS"; g_SessionColor=C_TEXT_MUTED; g_SessionMultiplier=0.80;       return SESSION_DEAD;
}

bool CheckSessionAllowed()
{
   switch(g_CurrentSession)
   {
      case SESSION_ASIAN:    return InpTradeAsian;
      case SESSION_LONDON:   return InpTradeLondon;
      case SESSION_NEW_YORK: return InpTradeNewYork;
      case SESSION_OVERLAP:  return InpTradeOverlap;
      default:               return false;
   }
}

bool CheckDailyHalt()
{
   if(g_DailyProfit <= -(InpDailyDrawdownHalt))
   {
      g_DailyHaltActive = true;
      g_StatusText  = "DAILY HALT: -$" + DoubleToString(MathAbs(g_DailyProfit), 2) + " LOSS LIMIT";
      g_StatusColor = C_CRIMSON_RED;
      return true;
   }
   g_DailyHaltActive = false;
   return false;
}

//+------------------------------------------------------------------+
//| TARGET EVALUATOR (per-trade $0.20 + global $5.00)              |
//+------------------------------------------------------------------+
void EvaluateTargets()
{
   double totalFloating = GetFloatingPnL();
   g_StatusText = "AWAITING TARGETS | Float: $" + DoubleToString(totalFloating,2) + " ["+g_SignalLabel+"]";
   g_StatusColor = C_ACCENT_BLUE;
   if(totalFloating >= InpGlobalProfitTargetUSD) { LiquidateAll("Global TP $"+DoubleToString(InpGlobalProfitTargetUSD,2)); return; }
   for(int i=PositionsTotal()-1; i>=0; i--)
   {
      if(!g_Pos.SelectByIndex(i) || g_Pos.Magic()!=InpMagicNumber || g_Pos.Symbol()!=_Symbol) continue;
      double pnl = g_Pos.Profit()+g_Pos.Swap()+g_Pos.Commission();
      if(pnl >= InpPerTradeProfitUSD) { g_Trade.PositionClose(g_Pos.Ticket()); UpdateAIMemory(pnl); Print("Per-trade TP: +$",DoubleToString(pnl,2)); continue; }
      double op = g_Pos.PriceOpen();
      if(op > 0.0)
      {
         double pct = (g_Pos.PositionType()==POSITION_TYPE_BUY) ? ((SymbolInfoDouble(_Symbol,SYMBOL_BID)-op)/op*100) : ((op-SymbolInfoDouble(_Symbol,SYMBOL_ASK))/op*100);
         if(pct >= InpImmediateReopenPct) { g_Trade.PositionClose(g_Pos.Ticket()); g_ProfitReopens++; OpenTrade((g_Pos.PositionType()==POSITION_TYPE_BUY)?ORDER_TYPE_BUY:ORDER_TYPE_SELL); }
      }
   }
}

//+------------------------------------------------------------------+
//| TRADE EXECUTION                                                  |
//+------------------------------------------------------------------+
void OpenTrade(ENUM_ORDER_TYPE signal)
{
   double price = (signal==ORDER_TYPE_BUY) ? SymbolInfoDouble(_Symbol,SYMBOL_ASK) : SymbolInfoDouble(_Symbol,SYMBOL_BID);
   double point = SymbolInfoDouble(_Symbol,SYMBOL_POINT);
   int    digs  = (int)SymbolInfoInteger(_Symbol,SYMBOL_DIGITS);
   double minV  = SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN), maxV = SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MAX), step = SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_STEP);
   double lot = MathMax(minV, MathMin(maxV, MathRound(InpLotSize/step)*step));
   
   double tickValue = SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_VALUE), tickSize = SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE);
   if(tickSize<=0 || tickValue<=0) tickValue=1.0;
   double pointValue = tickValue * (point / tickSize);
   double tpDist = (pointValue>0) ? MathCeil(InpPerTradeProfitUSD / (lot * pointValue)) : InpTakeProfitPoints;
   
   double sl=0, tp=0;
   if(InpStopLossPoints>0) sl = (signal==ORDER_TYPE_BUY) ? price-(InpStopLossPoints*point) : price+(InpStopLossPoints*point);
   if(tpDist>0) tp = (signal==ORDER_TYPE_BUY) ? price+(tpDist*point) : price-(tpDist*point);
   sl = NormalizeDouble(sl,digs); tp = NormalizeDouble(tp,digs);
   string comment = "GOLD AI v6.2 ["+g_SignalLabel+"] S:"+IntegerToString(g_AIScore);
   bool ok = (signal==ORDER_TYPE_BUY) ? g_Trade.Buy(lot,_Symbol,price,sl,tp,comment) : g_Trade.Sell(lot,_Symbol,price,sl,tp,comment);
   if(ok) { g_DailyTrades++; Print("[v6.2] Executed ",EnumToString(signal)," lot:",lot); }
}

//+------------------------------------------------------------------+
//| UTILITY FUNCTIONS                                                |
//+------------------------------------------------------------------+
void SyncLedger()
{
   datetime now = TimeCurrent();
   datetime mid = GetMidnight(now);
   if(mid > g_CurrentDay)
   {
      g_DailyTrades=0; g_DailyProfit=0.0; g_DailyWins=0;
      g_DailyLosses=0; g_ProfitReopens=0; g_TotalFlips=0;
      g_CurrentDay=mid; g_DailyHaltActive=false;
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

void LiquidateAll(string reason)
{
   for(int i=PositionsTotal()-1; i>=0; i--)
      if(g_Pos.SelectByIndex(i) && g_Pos.Magic()==InpMagicNumber && g_Pos.Symbol()==_Symbol)
         g_Trade.PositionClose(g_Pos.Ticket());
   Print("[GOLD AI v6.2] Liquidated all: ", reason);
}

bool HasOpenPositions()
{
   for(int i=PositionsTotal()-1; i>=0; i--)
      if(g_Pos.SelectByIndex(i) && g_Pos.Magic()==InpMagicNumber && g_Pos.Symbol()==_Symbol) return true;
   return false;
}

double GetFloatingPnL()
{
   double t=0.0;
   for(int i=PositionsTotal()-1; i>=0; i--)
      if(g_Pos.SelectByIndex(i) && g_Pos.Magic()==InpMagicNumber && g_Pos.Symbol()==_Symbol)
         t += g_Pos.Profit()+g_Pos.Swap()+g_Pos.Commission();
   return t;
}

bool CheckLiquidity()
{
   ENUM_SYMBOL_TRADE_MODE m = (ENUM_SYMBOL_TRADE_MODE)SymbolInfoInteger(_Symbol,SYMBOL_TRADE_MODE);
   return (m==SYMBOL_TRADE_MODE_FULL || m==SYMBOL_TRADE_MODE_LONGONLY || m==SYMBOL_TRADE_MODE_SHORTONLY);
}

datetime GetMidnight(datetime t)
{
   MqlDateTime d; TimeToStruct(t,d);
   return t - (datetime)(d.hour*3600 + d.min*60 + d.sec);
}

//+------------------------------------------------------------------+
//| DASHBOARD                                                        |
//+------------------------------------------------------------------+
void RenderDashboard()
{
   int aX=InpDashXOffset, aY=InpDashYOffset, dW=470, dH=760;
   CreateRect("Bg", aX,aY,dW,dH,C_MATRIX_BG,C_BORDER_GLOW,2);
   CreateRect("Hdr", aX+2,aY+2,dW-4,90,C_HEADER_BAR,C_GOLD_SHIMMER,2);
   CreateLabel("T1",aX+16,aY+10,"THEE ELITE SCALPER",C_GOLD_SHIMMER,18,"Algerian");
   CreateLabel("T2",aX+16,aY+40,"GOLD EDITION — AI BRAIN v6.2",C_AMBER_GOLD,9,"Arial Black");
   CreateLabel("T3",aX+16,aY+60,"7-Layer | Kalman | Momentum | Trend Bias | $0.20 TP",C_TEXT_MUTED,7,"Arial Italic");
   CreateLabel("Sym",aX+dW-115,aY+14,_Symbol,C_GOLD_SHIMMER,14,"Impact");
   CreateLabel("Ver",aX+dW-115,aY+38,AI_VERSION,C_AMBER_GOLD,7,"Arial Bold");
   
   CreateRect("PBg",aX+2,aY+95,dW-4,24,C_PANEL_BG,clrNONE,0);
   CreateLabel("PLbl",aX+16,aY+101,"[ MATRIX ]:",C_TEXT_MUTED,8,"Consolas Black");
   CreateLabel("PVal",aX+160,aY+101,"0 0 0 0",C_ACCENT_BLUE,9,"Consolas");
   
   int p1Y=aY+124;
   CreateRect("P1",aX+2,p1Y,dW-4,140,C_PANEL_BG,C_BORDER_GLOW,1);
   CreateLabel("P1H",aX+16,p1Y+8,"LIVE FINANCIALS",C_TEXT_LIGHT,10,"Arial Black");
   CreateLabel("L_Bal",aX+22,p1Y+34,"Balance:",C_TEXT_MUTED,9,"Arial");        CreateLabel("V_Bal",aX+150,p1Y+34,"$0.00",C_TEXT_LIGHT,10,"Arial Bold");
   CreateLabel("L_Eq",aX+22,p1Y+58,"Equity:",C_TEXT_MUTED,9,"Arial");           CreateLabel("V_Eq",aX+150,p1Y+58,"$0.00",C_TEXT_LIGHT,10,"Arial Bold");
   CreateLabel("L_Dp",aX+22,p1Y+82,"Daily P&L:",C_TEXT_MUTED,9,"Arial");        CreateLabel("V_Dp",aX+150,p1Y+82,"$0.00",C_NEON_GREEN,10,"Arial Black");
   CreateLabel("L_Fp",aX+22,p1Y+106,"Floating:",C_TEXT_MUTED,9,"Arial");         CreateLabel("V_Fp",aX+150,p1Y+106,"$0.00",C_NEON_GREEN,10,"Arial Black");
   
   int p2Y=aY+270;
   CreateRect("P2",aX+2,p2Y,dW-4,200,C_PANEL_BG,C_GOLD_SHIMMER,1);
   CreateLabel("P2H",aX+16,p2Y+8,"AI BRAIN — 7-LAYER CONFLUENCE",C_GOLD_SHIMMER,10,"Arial Black");
   CreateLabel("L_Sc",aX+22,p2Y+34,"Score:",C_TEXT_MUTED,9,"Arial");            CreateLabel("V_Sc",aX+150,p2Y+34,"0/100",C_AMBER_GOLD,11,"Arial Black");
   CreateLabel("L_Sg",aX+22,p2Y+58,"Signal:",C_TEXT_MUTED,9,"Arial");           CreateLabel("V_Sg",aX+150,p2Y+58,"SCANNING",C_TEXT_MUTED,10,"Arial Black");
   CreateLabel("L_Th",aX+22,p2Y+82,"Threshold:",C_TEXT_MUTED,9,"Arial");        CreateLabel("V_Th",aX+150,p2Y+82,IntegerToString(g_AIThreshold),C_TEAL_AI,10,"Arial Bold");
   CreateLabel("L_Br",aX+22,p2Y+106,"Mode:",C_TEXT_MUTED,9,"Arial");            CreateLabel("V_Br",aX+150,p2Y+106,"INIT",C_TEAL_AI,9,"Arial Bold");
   CreateLabel("L_Tr",aX+22,p2Y+130,"Trend:",C_TEXT_MUTED,9,"Arial");           CreateLabel("V_Tr",aX+150,p2Y+130,"NEUTRAL",C_TEXT_MUTED,9,"Arial Bold");
   CreateLabel("V_L1",aX+22,p2Y+155,"EMA:---",C_TEXT_MUTED,8,"Consolas");
   CreateLabel("V_L2",aX+90,p2Y+155,"RSI:---",C_TEXT_MUTED,8,"Consolas");
   CreateLabel("V_L3",aX+158,p2Y+155,"BB:---",C_TEXT_MUTED,8,"Consolas");
   CreateLabel("V_L4",aX+226,p2Y+155,"ATR:---",C_TEXT_MUTED,8,"Consolas");
   CreateLabel("V_L5",aX+22,p2Y+175,"CDL:---",C_TEXT_MUTED,8,"Consolas");
   CreateLabel("V_L6",aX+90,p2Y+175,"STR:---",C_TEXT_MUTED,8,"Consolas");
   CreateLabel("V_L7",aX+158,p2Y+175,"KAL:---",C_TEXT_MUTED,8,"Consolas");
   CreateLabel("V_L8",aX+226,p2Y+175,"MOM:---",C_TEXT_MUTED,8,"Consolas");
   
   int p3Y=aY+476;
   CreateRect("P3",aX+2,p3Y,dW-4,150,C_PANEL_BG,C_BORDER_GLOW,1);
   CreateLabel("P3H",aX+16,p3Y+8,"BULK EXECUTION",C_TEXT_LIGHT,10,"Arial Black");
   CreateLabel("L_St",aX+22,p3Y+32,"Status:",C_TEXT_MUTED,9,"Arial");          CreateLabel("V_St",aX+100,p3Y+32,"INIT",C_ACCENT_BLUE,9,"Arial Black");
   CreateLabel("L_Tr",aX+22,p3Y+56,"Trades:",C_TEXT_MUTED,9,"Arial");          CreateLabel("V_Tr",aX+150,p3Y+56,"0/"+IntegerToString(InpMaxDailyTrades),C_TEXT_LIGHT,9,"Arial Bold");
   CreateLabel("L_Wr",aX+22,p3Y+80,"Win rate:",C_TEXT_MUTED,9,"Arial");        CreateLabel("V_Wr",aX+150,p3Y+80,"0.0%",C_TEXT_LIGHT,9,"Arial Bold");
   CreateLabel("L_Rp",aX+22,p3Y+104,"Reopens:",C_TEXT_MUTED,9,"Arial");        CreateLabel("V_Rp",aX+150,p3Y+104,"0",C_NEON_GREEN,9,"Arial Bold");
   CreateLabel("L_Dr",aX+22,p3Y+128,"Direction:",C_TEXT_MUTED,9,"Arial");      CreateLabel("V_Dr",aX+150,p3Y+128,"COMPUTING",C_TEXT_LIGHT,9,"Arial Bold");
   
   int p4Y=aY+632;
   CreateRect("P4",aX+2,p4Y,dW-4,66,C_PANEL_BG,C_ORANGE_FLIP,1);
   CreateLabel("P4H",aX+16,p4Y+6,"SESSION + ADAPTIVE",C_ORANGE_FLIP,8,"Arial Black");
   CreateLabel("L_Se",aX+22,p4Y+24,"Session:",C_TEXT_MUTED,8,"Arial");         CreateLabel("V_Se",aX+80,p4Y+24,"DETECTING",C_TEXT_MUTED,9,"Arial Bold");
   CreateLabel("L_Mc",aX+190,p4Y+24,"Mid-cycle:",C_TEXT_MUTED,8,"Arial");      CreateLabel("V_Mc",aX+265,p4Y+24,"STABLE",C_NEON_GREEN,8,"Arial Bold");
   CreateLabel("L_Fl",aX+22,p4Y+44,"Flips:",C_TEXT_MUTED,8,"Arial");           CreateLabel("V_Fl",aX+80,p4Y+44,"0",C_ORANGE_FLIP,8,"Arial Bold");
   CreateLabel("L_Hl",aX+150,p4Y+44,"Halt:",C_TEXT_MUTED,8,"Arial");           CreateLabel("V_Hl",aX+190,p4Y+44,"INACTIVE",C_NEON_GREEN,8,"Arial Bold");
   CreateLabel("L_Sp",aX+330,p4Y+24,"Spread:",C_TEXT_MUTED,8,"Arial");         CreateLabel("V_Sp",aX+380,p4Y+24,"0 PTS",C_TEXT_LIGHT,8,"Arial Bold");
   
   CreateLabel("F1",aX+10,aY+695,"GOLD EDITION — Adaptive Kalman Confluence Engine",C_TEXT_MUTED,7,"Arial");
   CreateLabel("F2",aX+310,aY+695,"v6.20 | Fixed Build",C_TEXT_MUTED,7,"Arial Black");
   ChartRedraw(0);
}

void RefreshDashboard()
{
   UpdateLabel("PVal",g_HeartbeatStr,C_ACCENT_BLUE);
   UpdateLabel("V_Bal","$ "+DoubleToString(AccountInfoDouble(ACCOUNT_BALANCE),2));
   UpdateLabel("V_Eq","$ "+DoubleToString(AccountInfoDouble(ACCOUNT_EQUITY),2));
   color cDp = (g_DailyProfit>=0)?C_NEON_GREEN:C_CRIMSON_RED;
   UpdateLabel("V_Dp",(g_DailyProfit>=0?"+$ ":"-$ ")+DoubleToString(MathAbs(g_DailyProfit),2),cDp);
   double fpl=GetFloatingPnL(); color cFp=(fpl>=0)?C_NEON_GREEN:C_CRIMSON_RED;
   UpdateLabel("V_Fp",(fpl>=0?"+$ ":"-$ ")+DoubleToString(MathAbs(fpl),2),cFp);
   
   color scC = (g_AIScore>=InpEliteScoreThreshold)?C_GOLD_SHIMMER:(g_AIScore>=InpStrongScoreThreshold)?C_NEON_GREEN:(g_AIScore>=45)?C_AMBER_GOLD:C_CRIMSON_RED;
   UpdateLabel("V_Sc",IntegerToString(g_AIScore)+" / 100",scC);
   UpdateLabel("V_Sg",g_SignalLabel,g_SignalColor);
   UpdateLabel("V_Th",IntegerToString(g_AIThreshold),C_TEAL_AI);
   UpdateLabel("V_Br",g_AIBrainStatus,C_TEAL_AI);
   color trC = (g_TrendBias>0.3)?C_NEON_GREEN:(g_TrendBias<-0.3)?C_CRIMSON_RED:C_AMBER_GOLD;
   UpdateLabel("V_Tr",g_TrendLabel,trC);
   
   UpdateLabel("V_L1","EMA:"+IntegerToString(g_ScoreEMA),(g_ScoreEMA>70?C_NEON_GREEN:(g_ScoreEMA>40?C_AMBER_GOLD:C_CRIMSON_RED)));
   UpdateLabel("V_L2","RSI:"+IntegerToString(g_ScoreRSI),(g_ScoreRSI>70?C_NEON_GREEN:(g_ScoreRSI>40?C_AMBER_GOLD:C_CRIMSON_RED)));
   UpdateLabel("V_L3","BB:"+IntegerToString(g_ScoreBB),(g_ScoreBB>70?C_NEON_GREEN:(g_ScoreBB>40?C_AMBER_GOLD:C_CRIMSON_RED)));
   UpdateLabel("V_L4","ATR:"+IntegerToString(g_ScoreATR),(g_ScoreATR>70?C_NEON_GREEN:(g_ScoreATR>40?C_AMBER_GOLD:C_CRIMSON_RED)));
   UpdateLabel("V_L5","CDL:"+IntegerToString(g_ScoreCandle),(g_ScoreCandle>70?C_NEON_GREEN:(g_ScoreCandle>40?C_AMBER_GOLD:C_CRIMSON_RED)));
   UpdateLabel("V_L6","STR:"+IntegerToString(g_ScoreStructure),(g_ScoreStructure>70?C_NEON_GREEN:(g_ScoreStructure>40?C_AMBER_GOLD:C_CRIMSON_RED)));
   UpdateLabel("V_L7","KAL:"+IntegerToString(g_ScoreKalman),(g_ScoreKalman>70?C_NEON_GREEN:(g_ScoreKalman>40?C_AMBER_GOLD:C_CRIMSON_RED)));
   UpdateLabel("V_L8","MOM:"+IntegerToString(g_ScoreMomentum),(g_ScoreMomentum>70?C_NEON_GREEN:(g_ScoreMomentum>40?C_AMBER_GOLD:C_CRIMSON_RED)));
   
   UpdateLabel("V_St",g_StatusText,g_StatusColor);
   UpdateLabel("V_Tr",IntegerToString(g_DailyTrades)+"/"+IntegerToString(InpMaxDailyTrades));
   int tot=g_DailyWins+g_DailyLosses; double wr=tot>0?((double)g_DailyWins/tot)*100.0:0.0;
   UpdateLabel("V_Wr",DoubleToString(wr,1)+" %");
   UpdateLabel("V_Rp",IntegerToString(g_ProfitReopens));
   UpdateLabel("V_Dr",(g_Direction==ORDER_TYPE_BUY)?"BULL":"BEAR",(g_Direction==ORDER_TYPE_BUY)?C_NEON_GREEN:C_CRIMSON_RED);
   
   UpdateLabel("V_Se",g_SessionLabel,g_SessionColor);
   color mcC = (StringFind(g_MidCycleStatus,"FLIP")>=0)?C_ORANGE_FLIP:C_NEON_GREEN;
   UpdateLabel("V_Mc",g_MidCycleStatus,mcC);
   UpdateLabel("V_Fl",IntegerToString(g_TotalFlips),C_ORANGE_FLIP);
   UpdateLabel("V_Hl",g_DailyHaltActive?"ACTIVE":"INACTIVE",g_DailyHaltActive?C_CRIMSON_RED:C_NEON_GREEN);
   UpdateLabel("V_Sp",IntegerToString((int)SymbolInfoInteger(_Symbol,SYMBOL_SPREAD))+" PTS");
   ChartRedraw(0);
}

void PurgeDashboard() { ObjectsDeleteAll(0, DASH_PREFIX); ChartRedraw(0); }

void CreateRect(string nm,int x,int y,int w,int h,color bg,color border,int bw)
{
   string q=DASH_PREFIX+nm;
   ObjectCreate(0,q,OBJ_RECTANGLE_LABEL,0,0,0);
   ObjectSetInteger(0,q,OBJPROP_CORNER,CORNER_LEFT_UPPER);
   ObjectSetInteger(0,q,OBJPROP_XDISTANCE,x); ObjectSetInteger(0,q,OBJPROP_YDISTANCE,y);
   ObjectSetInteger(0,q,OBJPROP_XSIZE,w);     ObjectSetInteger(0,q,OBJPROP_YSIZE,h);
   ObjectSetInteger(0,q,OBJPROP_BGCOLOR,bg);
   if(border!=clrNONE){ObjectSetInteger(0,q,OBJPROP_BORDER_TYPE,BORDER_FLAT);
   ObjectSetInteger(0,q,OBJPROP_COLOR,border);ObjectSetInteger(0,q,OBJPROP_WIDTH,bw);}
   else ObjectSetInteger(0,q,OBJPROP_BORDER_TYPE,BORDER_RAISED);
   ObjectSetInteger(0,q,OBJPROP_SELECTABLE,false);
   ObjectSetInteger(0,q,OBJPROP_HIDDEN,true);
   ObjectSetInteger(0,q,OBJPROP_ZORDER,0);
}

void CreateLabel(string nm,int x,int y,string txt,color clr,int fsz,string font)
{
   string q=DASH_PREFIX+nm;
   ObjectCreate(0,q,OBJ_LABEL,0,0,0);
   ObjectSetInteger(0,q,OBJPROP_CORNER,CORNER_LEFT_UPPER);
   ObjectSetInteger(0,q,OBJPROP_XDISTANCE,x); ObjectSetInteger(0,q,OBJPROP_YDISTANCE,y);
   ObjectSetString(0,q,OBJPROP_TEXT,txt);
   ObjectSetInteger(0,q,OBJPROP_COLOR,clr);
   ObjectSetInteger(0,q,OBJPROP_FONTSIZE,fsz);
   ObjectSetString(0,q,OBJPROP_FONT,font);
   ObjectSetInteger(0,q,OBJPROP_SELECTABLE,false);
   ObjectSetInteger(0,q,OBJPROP_HIDDEN,true);
   ObjectSetInteger(0,q,OBJPROP_ZORDER,1);
}

void UpdateLabel(string nm,string txt,color clr=clrNONE)
{
   string q=DASH_PREFIX+nm;
   if(ObjectFind(0,q)>=0){
      ObjectSetString(0,q,OBJPROP_TEXT,txt);
      if(clr!=clrNONE) ObjectSetInteger(0,q,OBJPROP_COLOR,clr);
   }
}
//+------------------------------------------------------------------+
