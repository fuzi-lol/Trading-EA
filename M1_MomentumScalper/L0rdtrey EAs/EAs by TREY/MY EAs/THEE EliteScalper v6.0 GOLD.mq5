//+------------------------------------------------------------------+
//|                            THEE EliteScalper v7.0 GOLD EDITION  |
//|                    FIXED & HARDENED — Score Normalized          |
//+------------------------------------------------------------------+
#property copyright   "Copyright 2026, ELITE Systems - Refactored"
#property version     "7.00"
#property description "GOLD EDITION — AI Brain + 6-Layer Confluence [CORRECTED]"
#property description "Real risk guards | Robust AI memory | Corrected scoring"
#property strict

#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>
#include <Trade\HistoryOrderInfo.mqh>
#include <Trade\DealInfo.mqh>

#define DASH_PREFIX   "FXBH_G7_"
#define AI_VERSION    "GOLD AI v7.0"
#define MAX_HISTORY   30

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

// --- Inputs ---
input group "=== CORE ENGINE SETTINGS ==="
input long    InpMagicNumber          = 999666;
input double  InpLotSize              = 0.01;
input int     InpMaxDailyTrades       = 100;

input group "=== BULK EXECUTION SETTINGS ==="
input int     InpBulkMaxTrades        = 10;
input int     InpBulkIntervalSec      = 10;
input double  InpPerTradeTargetUSD    = 0.50;
input bool    InpAllowReopen          = false;

input group "=== ADAPTIVE MID-CYCLE ANALYSIS ==="
input bool    InpAdaptiveMidCycle     = true;
input int     InpAnalysisTickSec      = 2;
input bool    InpCloseOnFlip          = true;
input int     InpConfirmFlipChecks    = 5;

input group "=== AI BRAIN — CONFLUENCE SCORING ENGINE ==="
input int     InpMinScoreToTrade      = 60;
input int     InpEliteScoreThreshold  = 80;
input int     InpStrongScoreThreshold = 65;
input bool    InpRequireStrongMin     = true;
input bool    InpAIAdaptiveThreshold  = true;

input group "=== CONFLUENCE LAYER WEIGHTS (must sum ~100) ==="
input int     InpWeightEMA            = 20;
input int     InpWeightRSI            = 20;
input int     InpWeightBB             = 20;
input int     InpWeightATR            = 15;
input int     InpWeightCandle         = 15;
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
input int     InpBrokerUTCOffsetHours = 0;
input int     InpAsianStartHour       = 0;
input int     InpAsianEndHour         = 8;
input int     InpLondonStartHour      = 7;
input int     InpLondonEndHour        = 16;
input int     InpNYStartHour          = 13;
input int     InpNYEndHour            = 22;

input group "=== ACCOUNT GUARDRAILS ==="
input int     InpStopLossPoints       = 300;
input int     InpTakeProfitPoints     = 0;
input int     InpMaxSpreadPoints      = 25;
input double  InpDailyDrawdownHalt    = 50.0;

input group "=== ANTI-MANIPULATION COOLDOWN ==="
input int     InpCooldownSeconds      = 60;

input group "=== INTERFACE LAYOUT ==="
input int     InpDashXOffset          = 15;
input int     InpDashYOffset          = 15;

// --- Colors ---
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

// --- Globals ---
CTrade            g_Trade;
CPositionInfo     g_Pos;
CHistoryOrderInfo g_HistOrder;
CDealInfo         g_Deal;

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
datetime           g_LastTradeTime  = 0;
datetime           g_CurrentDay     = 0;

datetime           g_LastAnalysisTime  = 0;
int                g_FlipConfirmCount  = 0;
int                g_TotalFlips        = 0;
string             g_MidCycleStatus    = "STABLE";

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

double  g_TradeHistory[MAX_HISTORY];
int     g_TradeHistoryCount  = 0;
int     g_ConsecutiveLosses  = 0;
int     g_ConsecutiveWins    = 0;
double  g_RecentNetPnL       = 0.0;

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

// --- Forward declarations ---
void   SyncLedger();
void   ProcessBulkOpening();
bool   RunAdaptiveAnalysis();
void   ExecuteFlip(ENUM_ORDER_TYPE newDir);
void   OpenTrade(ENUM_ORDER_TYPE signal, bool isFlip = false);
bool   CheckLiquidity();
bool   CheckSessionAllowed();
bool   CheckDailyHalt();
void   LiquidateAll(string reason);
void   CloseWrongDirectionTrades(ENUM_ORDER_TYPE wrongDir);
void   CloseAllPositionsByMagic();
bool   HasOpenPositions();
double GetFloatingPnL();

int              ComputeConfluenceScore(ENUM_ORDER_TYPE &outDir, double &buyWeight, double &sellWeight);
ENUM_SIGNAL_STRENGTH ScoreToStrength(int score);
void             ScoreEMALayer(int &score, ENUM_ORDER_TYPE &dir);
void             ScoreRSILayer(int &score, ENUM_ORDER_TYPE &dir);
void             ScoreBBLayer(int &score, ENUM_ORDER_TYPE &dir);
void             ScoreATRLayer(int &score);
void             ScoreCandleLayer(int &score, ENUM_ORDER_TYPE &dir);
void             ScoreStructureLayer(int &score, ENUM_ORDER_TYPE &dir);
bool             GetMTFConfirmation(ENUM_ORDER_TYPE dir);
ENUM_ORDER_TYPE  GetHTF2Trend();
void             UpdateAIMemory(double pnl);
void             AdaptAIThreshold();
void             ScanClosedDeals();
ENUM_SESSION     DetectSession();

void   RenderDashboard();
void   RefreshDashboard();
void   PurgeDashboard();
void   CreateRect(string nm,int x,int y,int w,int h,color bg,color border,int bw);
void   CreateLabel(string nm,int x,int y,string txt,color clr,int fsz,string font);
void   UpdateLabel(string nm,string txt,color clr=clrNONE);
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
   
   if(g_hFastEMA==INVALID_HANDLE||g_hSlowEMA==INVALID_HANDLE||g_hTrendEMA==INVALID_HANDLE||
      g_hRSI==INVALID_HANDLE||g_hBB==INVALID_HANDLE||g_hATR==INVALID_HANDLE)
   {
      Print("[GOLD AI v7] ERROR: Main indicator handles failed.");
      return INIT_FAILED;
   }
   
   if(InpUseMTF)
   {
      g_hFastEMA_HTF1 = iMA(_Symbol, InpHTF1, InpFastEMAPeriod, 0, MODE_EMA, PRICE_CLOSE);
      g_hSlowEMA_HTF1 = iMA(_Symbol, InpHTF1, InpSlowEMAPeriod, 0, MODE_EMA, PRICE_CLOSE);
      g_hRSI_HTF1     = iRSI(_Symbol, InpHTF1, InpRSIPeriod, PRICE_CLOSE);
      g_hFastEMA_HTF2 = iMA(_Symbol, InpHTF2, InpFastEMAPeriod, 0, MODE_EMA, PRICE_CLOSE);
      g_hSlowEMA_HTF2 = iMA(_Symbol, InpHTF2, InpSlowEMAPeriod, 0, MODE_EMA, PRICE_CLOSE);
      
      if(g_hFastEMA_HTF1==INVALID_HANDLE || g_hSlowEMA_HTF1==INVALID_HANDLE ||
         g_hRSI_HTF1==INVALID_HANDLE     || g_hFastEMA_HTF2==INVALID_HANDLE ||
         g_hSlowEMA_HTF2==INVALID_HANDLE)
         Print("[GOLD AI v7] WARNING: Some HTF handles failed. MTF disabled.");
   }
   
   g_AIThreshold = InpMinScoreToTrade;
   ArrayInitialize(g_TradeHistory, 0.0);
   
   g_CurrentDay = GetMidnight(TimeCurrent());
   SyncLedger();
   RenderDashboard();
   
   g_State = STATE_SCANNING;
   EventSetTimer(1);
   
   Print("[GOLD AI v7.0] Engine Initialised. AI Threshold: ", g_AIThreshold);
   Print("[GOLD AI v7.0] MTF: M1+", EnumToString(InpHTF1), "+", EnumToString(InpHTF2));
   Print("[GOLD AI v7.0] Broker UTC Offset: ", InpBrokerUTCOffsetHours, "h");
   
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| DEINIT                                                           |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   EventKillTimer();
   PurgeDashboard();
   
   int handles[] = {g_hFastEMA, g_hSlowEMA, g_hTrendEMA, g_hRSI, g_hBB, g_hATR,
                    g_hFastEMA_HTF1, g_hSlowEMA_HTF1, g_hRSI_HTF1,
                    g_hFastEMA_HTF2, g_hSlowEMA_HTF2};
   for(int i=0; i<ArraySize(handles); i++)
      if(handles[i]!=INVALID_HANDLE) IndicatorRelease(handles[i]);
}

//+------------------------------------------------------------------+
//| TIMER                                                           |
//+------------------------------------------------------------------+
void OnTimer()
{
   static int tickCount = 0;
   tickCount++;
   if(tickCount % 3 == 0)
   {
      g_CurrentSession = DetectSession();
      SyncLedger();
      ScanClosedDeals();
      AdaptAIThreshold();
      RefreshDashboard();
   }
}

//+------------------------------------------------------------------+
//| TICK — MAIN LOOP                                                |
//+------------------------------------------------------------------+
void OnTick()
{
   if(!CheckLiquidity()) { g_StatusText="MARKET SUSPENDED"; g_StatusColor=C_CRIMSON_RED; return; }
   if(CheckDailyHalt()) return;
   
   int spread = (int)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   if(spread > InpMaxSpreadPoints)
   {
      g_StatusText = "SPREAD TOO HIGH (" + IntegerToString(spread) + " PTS)";
      g_StatusColor= C_CRIMSON_RED;
      if(g_State == STATE_BULK_OPENING) return;
      return;
   }
   if(InpUseSessionFilter && !CheckSessionAllowed())
   {
      g_StatusText = "SESSION FILTER: " + g_SessionLabel + " — SKIPPING";
      g_StatusColor= C_TEXT_MUTED;
      if(g_State == STATE_BULK_OPENING) return;
      return;
   }
   double atr[2];
   if(CopyBuffer(g_hATR, 0, 0, 2, atr) > 0 && atr[0] > atr[1] * InpATRSpikeMultiplier)
   {
      g_StatusText  = "ATR SPIKE — HALT ALL";
      g_StatusColor = C_CRIMSON_RED;
      if(g_State == STATE_BULK_OPENING) return;
      return;
   }
   
   if(g_State == STATE_WAITING_CLOSE)
   {
      EvaluateTargets();
      if(!HasOpenPositions())
      {
         g_StateTimer = TimeCurrent() + InpCooldownSeconds;
         g_State      = STATE_COOLDOWN;
         g_StatusText = "CYCLE COMPLETE — COOLING DOWN";
         g_StatusColor= C_NEON_GREEN;
      }
      return;
   }
   
   if(g_DailyTrades >= InpMaxDailyTrades)
   {
      g_StatusText = "ALLOCATION LIMIT REACHED"; g_StatusColor = C_AMBER_GOLD;
      return;
   }
   
   if(g_State == STATE_BULK_OPENING)
   {
      ProcessBulkOpening();
      return;
   }
   
   if(g_State == STATE_COOLDOWN)
   {
      int left = (int)(g_StateTimer - TimeCurrent());
      if(left > 0)
      {
         g_StatusText  = "COOLING DOWN... (" + IntegerToString(left) + "s)";
         g_StatusColor = C_AMBER_GOLD;
         return;
      }
      g_State = STATE_SCANNING;
   }
   
   if(g_State == STATE_SCANNING)
   {
      ENUM_ORDER_TYPE aiDir  = ORDER_TYPE_BUY;
      double buyW, sellW;
      int score = ComputeConfluenceScore(aiDir, buyW, sellW);
      g_AIScore = score;
      g_SignalStrength = ScoreToStrength(score);
      
      bool strongEnough = (!InpRequireStrongMin) || (g_SignalStrength >= SIG_STRONG);
      bool scoreEnough  = (score >= g_AIThreshold);
      
      if(!scoreEnough || !strongEnough)
      {
         g_StatusText  = "AI SCANNING... SCORE:" + IntegerToString(score) + "/100 [" + g_SignalLabel + "]";
         g_StatusColor = C_TEXT_MUTED;
         return;
      }
      
      if(InpUseMTF && !GetMTFConfirmation(aiDir))
      {
         g_StatusText  = "MTF DIVERGENCE — HOLDING";
         g_StatusColor = C_AMBER_GOLD;
         return;
      }
      
      g_Direction         = aiDir;
      g_State             = STATE_BULK_OPENING;
      g_BulkOpened        = 0;
      g_LastTradeTime     = 0;
      g_FlipConfirmCount  = 0;
      g_MidCycleStatus    = "STABLE";
      
      Print("[GOLD AI v7] Signal CONFIRMED. Score: ", score, " [", g_SignalLabel, "] Dir: ", EnumToString(aiDir));
   }
}

//+------------------------------------------------------------------+
//| BULK OPENING                                                    |
//+------------------------------------------------------------------+
void ProcessBulkOpening()
{
   if(g_BulkOpened > 0 && !HasOpenPositions())
   {
      Print("[v7] All positions vanished during bulk cycle. Aborting.");
      g_State = STATE_COOLDOWN;
      g_StateTimer = TimeCurrent() + InpCooldownSeconds;
      return;
   }
   
   datetime now     = TimeCurrent();
   int elapsed      = (int)(now - g_LastTradeTime);
   int remaining    = InpBulkIntervalSec - elapsed;
   if(remaining < 0) remaining = 0;
   
   if(InpAdaptiveMidCycle && g_LastTradeTime > 0)
   {
      if((now - g_LastAnalysisTime) >= InpAnalysisTickSec)
      {
         g_LastAnalysisTime = now;
         bool flipped = RunAdaptiveAnalysis();
         if(flipped)
         {
            g_BulkOpened++;
            g_LastTradeTime    = now;
            g_LastAnalysisTime = now;
            g_FlipConfirmCount = 0;
            g_TotalFlips++;
            if(g_BulkOpened >= InpBulkMaxTrades)
               g_State = STATE_WAITING_CLOSE;
            return;
         }
      }
   }
   
   if(elapsed >= InpBulkIntervalSec)
   {
      if(!CheckDailyHalt() && CheckLiquidity() && CheckSessionAllowed())
      {
         int spread = (int)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
         if(spread <= InpMaxSpreadPoints)
         {
            g_StatusText = "DEPLOYING BULK: " + IntegerToString(g_BulkOpened)+"/"+IntegerToString(InpBulkMaxTrades);
            g_StatusColor = C_PURPLE_SCAN;
            OpenTrade(g_Direction, false);
            g_BulkOpened++;
            g_LastTradeTime = now;
            g_LastAnalysisTime = now;
            g_FlipConfirmCount = 0;
         }
      }
      if(g_BulkOpened >= InpBulkMaxTrades)
         g_State = STATE_WAITING_CLOSE;
   }
   else
   {
      g_StatusText = "AI WATCHING... NEXT IN " + IntegerToString(remaining) + "s | " + g_MidCycleStatus;
      g_StatusColor = C_ACCENT_BLUE;
   }
}

//+------------------------------------------------------------------+
//| EVALUATE TARGETS (dollar-based)                                  |
//+------------------------------------------------------------------+
void EvaluateTargets()
{
   g_StatusText  = "WAITING TARGETS ($" + DoubleToString(InpPerTradeTargetUSD,2) + "/ea)";
   g_StatusColor = C_ACCENT_BLUE;
   
   ulong tickets[];
   int count = 0;
   for(int i = PositionsTotal()-1; i >= 0; i--)
   {
      if(g_Pos.SelectByIndex(i) && g_Pos.Magic()==InpMagicNumber && g_Pos.Symbol()==_Symbol)
      {
         double pnl = g_Pos.Profit() + g_Pos.Swap() + g_Pos.Commission();
         if(pnl >= InpPerTradeTargetUSD)
         {
            ArrayResize(tickets, count+1);
            tickets[count++] = g_Pos.Ticket();
         }
      }
   }
   for(int i=0; i<count; i++)
      g_Trade.PositionClose(tickets[i]);
}

//+------------------------------------------------------------------+
//| MID-CYCLE ADAPTIVE ANALYSIS                                     |
//+------------------------------------------------------------------+
bool RunAdaptiveAnalysis()
{
   ENUM_ORDER_TYPE newDir = ORDER_TYPE_BUY;
   double buyW, sellW;
   int score = ComputeConfluenceScore(newDir, buyW, sellW);
   
   bool isOpposite = (newDir != g_Direction);
   bool scoreValid = (score >= g_AIThreshold);
   
   if(isOpposite && scoreValid)
   {
      g_FlipConfirmCount++;
      g_MidCycleStatus = "FLIP " + IntegerToString(g_FlipConfirmCount) + "/" + IntegerToString(InpConfirmFlipChecks);
      if(g_FlipConfirmCount >= InpConfirmFlipChecks)
      {
         ExecuteFlip(newDir);
         return true;
      }
   }
   else
   {
      g_FlipConfirmCount = 0;
      g_MidCycleStatus = "STABLE [" + g_SignalLabel + "] " + IntegerToString(score) + "/100";
   }
   return false;
}

void ExecuteFlip(ENUM_ORDER_TYPE newDir)
{
   Print("[v7 FLIP] ", EnumToString(g_Direction), " → ", EnumToString(newDir),
         " | Score: ", g_AIScore);
   if(InpCloseOnFlip)
      CloseWrongDirectionTrades(g_Direction);
   g_Direction = newDir;
   OpenTrade(newDir, true);
   g_MidCycleStatus = "FLIPPED → " + (newDir==ORDER_TYPE_BUY ? "BUY" : "SELL");
   g_FlipConfirmCount = 0;
}

//+------------------------------------------------------------------+
//| SAFE CLOSE FUNCTIONS (no index shift bug)                       |
//+------------------------------------------------------------------+
void CloseWrongDirectionTrades(ENUM_ORDER_TYPE wrongDir)
{
   ulong tickets[];
   int cnt = 0;
   for(int i=PositionsTotal()-1; i>=0; i--)
   {
      if(g_Pos.SelectByIndex(i) && g_Pos.Magic()==InpMagicNumber && g_Pos.Symbol()==_Symbol)
      {
         bool isBuy = (g_Pos.PositionType()==POSITION_TYPE_BUY);
         if((wrongDir==ORDER_TYPE_BUY && isBuy) || (wrongDir==ORDER_TYPE_SELL && !isBuy))
         {
            ArrayResize(tickets, cnt+1);
            tickets[cnt++] = g_Pos.Ticket();
         }
      }
   }
   for(int i=0; i<cnt; i++) g_Trade.PositionClose(tickets[i]);
}

void CloseAllPositionsByMagic()
{
   ulong tickets[];
   int cnt = 0;
   for(int i=PositionsTotal()-1; i>=0; i--)
   {
      if(g_Pos.SelectByIndex(i) && g_Pos.Magic()==InpMagicNumber && g_Pos.Symbol()==_Symbol)
      {
         ArrayResize(tickets, cnt+1);
         tickets[cnt++] = g_Pos.Ticket();
      }
   }
   for(int i=0; i<cnt; i++) g_Trade.PositionClose(tickets[i]);
}

//+------------------------------------------------------------------+
//| CONFLUENCE SCORING — CORRECTED NORMALIZATION                    |
//+------------------------------------------------------------------+
int ComputeConfluenceScore(ENUM_ORDER_TYPE &outDir, double &buyWeight, double &sellWeight)
{
   int sEMA, sRSI, sBB, sATR, sCdl, sStr;
   ENUM_ORDER_TYPE dEMA, dRSI, dBB, dCdl, dStr;
   
   ScoreEMALayer(sEMA, dEMA);
   ScoreRSILayer(sRSI, dRSI);
   ScoreBBLayer(sBB, dBB);
   ScoreATRLayer(sATR);
   ScoreCandleLayer(sCdl, dCdl);
   ScoreStructureLayer(sStr, dStr);
   
   g_ScoreEMA = sEMA; g_ScoreRSI = sRSI; g_ScoreBB = sBB;
   g_ScoreATR = sATR; g_ScoreCandle = sCdl; g_ScoreStructure = sStr;
   
   double buyScore = 0, sellScore = 0;
   if(dEMA == ORDER_TYPE_BUY)  buyScore  += sEMA * InpWeightEMA;   else sellScore += sEMA * InpWeightEMA;
   if(dRSI == ORDER_TYPE_BUY)  buyScore  += sRSI * InpWeightRSI;   else sellScore += sRSI * InpWeightRSI;
   if(dBB  == ORDER_TYPE_BUY)  buyScore  += sBB  * InpWeightBB;    else sellScore += sBB  * InpWeightBB;
   if(dCdl == ORDER_TYPE_BUY)  buyScore  += sCdl * InpWeightCandle; else sellScore += sCdl * InpWeightCandle;
   if(dStr == ORDER_TYPE_BUY)  buyScore  += sStr * InpWeightStructure; else sellScore += sStr * InpWeightStructure;
   // ATR is non-directional, split equally
   double atrWeight = sATR * InpWeightATR / 2.0;
   buyScore  += atrWeight;
   sellScore += atrWeight;
   
   outDir = (buyScore > sellScore) ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
   buyWeight = buyScore; sellWeight = sellScore;
   
   // --- CORRECTED MAX POSSIBLE SCORE ---
   // All directional weights * 100 (if all layers score 100 and align) + half ATR weight * 100
   double maxPossible = (InpWeightEMA + InpWeightRSI + InpWeightBB + InpWeightCandle + InpWeightStructure) * 100.0
                        + (InpWeightATR * 100.0) / 2.0;
   double maxScore = MathMax(buyScore, sellScore);
   int total = (int)((maxScore / maxPossible) * 100.0);
   
   double sessionBoost = (g_CurrentSession == SESSION_OVERLAP) ? 1.15 :
                         (g_CurrentSession == SESSION_LONDON || g_CurrentSession == SESSION_NEW_YORK) ? 1.05 : 1.0;
   int finalScore = (int)MathMin(100, total * sessionBoost);
   
   ENUM_SIGNAL_STRENGTH str = ScoreToStrength(finalScore);
   if(str == SIG_ELITE)    { g_SignalLabel = "ELITE";    g_SignalColor = C_GOLD_SHIMMER; }
   else if(str == SIG_STRONG)  { g_SignalLabel = "STRONG";   g_SignalColor = C_NEON_GREEN;  }
   else if(str == SIG_MODERATE){ g_SignalLabel = "MODERATE"; g_SignalColor = C_AMBER_GOLD;  }
   else if(str == SIG_WEAK)    { g_SignalLabel = "WEAK";     g_SignalColor = C_ORANGE_FLIP; }
   else                        { g_SignalLabel = "NONE";     g_SignalColor = C_TEXT_MUTED;  }
   
   return finalScore;
}

//+------------------------------------------------------------------+
//| LAYER SCORING FUNCTIONS (unchanged, fixed earlier)              |
//+------------------------------------------------------------------+
void ScoreEMALayer(int &score, ENUM_ORDER_TYPE &dir)
{
   double fast[2], slow[2], trend[1];
   if(CopyBuffer(g_hFastEMA,0,0,2,fast)<=0 || CopyBuffer(g_hSlowEMA,0,0,2,slow)<=0)
   { score=0; dir=ORDER_TYPE_BUY; return; }
   if(CopyBuffer(g_hTrendEMA,0,0,1,trend)<=0) trend[0] = 0;
   
   double price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   bool crossUp   = (fast[1] <= slow[1] && fast[0] > slow[0]);
   bool crossDown = (fast[1] >= slow[1] && fast[0] < slow[0]);
   bool aboveFast = (price > fast[0]);
   bool aboveTrend = (price > trend[0]);
   double slope = (fast[0] - fast[1]);
   
   if(crossUp && aboveTrend)       { score=100; dir=ORDER_TYPE_BUY;  return; }
   if(crossDown && !aboveTrend)    { score=100; dir=ORDER_TYPE_SELL; return; }
   if(aboveFast && slope>0)        { score=75;  dir=ORDER_TYPE_BUY;  return; }
   if(!aboveFast && slope<0)       { score=75;  dir=ORDER_TYPE_SELL; return; }
   if(aboveFast)                   { score=45;  dir=ORDER_TYPE_BUY;  return; }
   score=45; dir=ORDER_TYPE_SELL;
}

void ScoreRSILayer(int &score, ENUM_ORDER_TYPE &dir)
{
   double rsi[2];
   if(CopyBuffer(g_hRSI,0,0,2,rsi)<=0) { score=0; dir=ORDER_TYPE_BUY; return; }
   double r = rsi[0], rPrev = rsi[1];
   bool rising = (r > rPrev);
   
   if(r < InpRSIOversold && rising)       { score=100; dir=ORDER_TYPE_BUY;  return; }
   if(r > InpRSIOverbought && !rising)    { score=100; dir=ORDER_TYPE_SELL; return; }
   if(r > 50 && rising)                   { score=65;  dir=ORDER_TYPE_BUY;  return; }
   if(r < 50 && !rising)                  { score=65;  dir=ORDER_TYPE_SELL; return; }
   if(r > 50)                             { score=40;  dir=ORDER_TYPE_BUY;  return; }
   score=40; dir=ORDER_TYPE_SELL;
}

void ScoreBBLayer(int &score, ENUM_ORDER_TYPE &dir)
{
   double upper[1], lower[1], mid[1];
   if(CopyBuffer(g_hBB,1,0,1,upper)<=0 || CopyBuffer(g_hBB,2,0,1,lower)<=0 || CopyBuffer(g_hBB,0,0,1,mid)<=0)
   { score=0; dir=ORDER_TYPE_BUY; return; }
   double price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(price <= lower[0])      { score=100; dir=ORDER_TYPE_BUY;  return; }
   if(price >= upper[0])      { score=100; dir=ORDER_TYPE_SELL; return; }
   if(price > mid[0])         { score=60;  dir=ORDER_TYPE_BUY;  return; }
   score=60; dir=ORDER_TYPE_SELL;
}

void ScoreATRLayer(int &score)
{
   double atr[2];
   if(CopyBuffer(g_hATR,0,0,2,atr)<=0) { score=50; return; }
   double curr=atr[0], prev=atr[1];
   if(curr > prev * InpATRSpikeMultiplier) { score=0;  return; }
   if(curr < prev * InpATRMinMultiplier)   { score=20; return; }
   if(curr >= prev*0.8 && curr <= prev*1.5) { score=100; return; }
   score=60;
}

void ScoreCandleLayer(int &score, ENUM_ORDER_TYPE &dir)
{
   double open[2], high[2], low[2], close[2];
   if(CopyOpen(_Symbol,_Period,0,2,open)<=0 || CopyHigh(_Symbol,_Period,0,2,high)<=0 ||
      CopyLow(_Symbol,_Period,0,2,low)<=0   || CopyClose(_Symbol,_Period,0,2,close)<=0)
   { score=0; dir=ORDER_TYPE_BUY; return; }
   
   double body1  = MathAbs(close[1]-open[1]);
   double range1 = high[1]-low[1];
   double upperWick = high[1]-MathMax(open[1],close[1]);
   double lowerWick = MathMin(open[1],close[1])-low[1];
   if(range1<=0) { score=50; dir=(close[1]>open[1])?ORDER_TYPE_BUY:ORDER_TYPE_SELL; return; }
   
   bool bull1 = (close[1] > open[1]);
   
   double trend[1];
   if(CopyBuffer(g_hTrendEMA,0,0,1,trend)>0)
   {
      bool trendUp = (SymbolInfoDouble(_Symbol,SYMBOL_BID) > trend[0]);
      if(bull1 && !trendUp)  { score=30; dir=ORDER_TYPE_BUY; return; }
      if(!bull1 && trendUp)  { score=30; dir=ORDER_TYPE_SELL; return; }
   }
   
   if(bull1 && lowerWick > body1*2 && lowerWick > upperWick*2)
   { score=90; dir=ORDER_TYPE_BUY; return; }
   if(!bull1 && upperWick > body1*2 && upperWick > lowerWick*2)
   { score=90; dir=ORDER_TYPE_SELL; return; }
   if(bull1 && body1 > range1*0.7)  { score=75; dir=ORDER_TYPE_BUY;  return; }
   if(!bull1 && body1 > range1*0.7) { score=75; dir=ORDER_TYPE_SELL; return; }
   
   score=30; dir=bull1?ORDER_TYPE_BUY:ORDER_TYPE_SELL;
}

void ScoreStructureLayer(int &score, ENUM_ORDER_TYPE &dir)
{
   int lb = InpStructureLookback;
   int hBar = iHighest(_Symbol,_Period,MODE_HIGH,lb,1);
   int lBar = iLowest(_Symbol,_Period,MODE_LOW,lb,1);
   double hHigh = iHigh(_Symbol,_Period,hBar);
   double lLow  = iLow(_Symbol,_Period,lBar);
   double price = SymbolInfoDouble(_Symbol,SYMBOL_BID);
   
   if(price > hHigh) { score=100; dir=ORDER_TYPE_BUY;  return; }
   if(price < lLow)  { score=100; dir=ORDER_TYPE_SELL; return; }
   double mid = (hHigh+lLow)/2.0;
   if(price > mid)   { score=60; dir=ORDER_TYPE_BUY;  return; }
   score=60; dir=ORDER_TYPE_SELL;
}

//+------------------------------------------------------------------+
//| MTF CONFIRMATION                                                |
//+------------------------------------------------------------------+
bool GetMTFConfirmation(ENUM_ORDER_TYPE dir)
{
   if(g_hFastEMA_HTF1==INVALID_HANDLE || g_hSlowEMA_HTF1==INVALID_HANDLE) return true;
   
   double htf1Fast[1], htf1Slow[1];
   if(CopyBuffer(g_hFastEMA_HTF1,0,0,1,htf1Fast)<=0 || CopyBuffer(g_hSlowEMA_HTF1,0,0,1,htf1Slow)<=0)
      return false;
   bool htf1Bull = (htf1Fast[0] > htf1Slow[0]);
   if((dir==ORDER_TYPE_BUY && !htf1Bull) || (dir==ORDER_TYPE_SELL && htf1Bull)) return false;
   
   if(InpRequireHTF2Align && g_hFastEMA_HTF2!=INVALID_HANDLE)
   {
      ENUM_ORDER_TYPE h1Trend = GetHTF2Trend();
      if(h1Trend != dir) return false;
   }
   return true;
}

ENUM_ORDER_TYPE GetHTF2Trend()
{
   double f[1], s[1];
   if(CopyBuffer(g_hFastEMA_HTF2,0,0,1,f)<=0 || CopyBuffer(g_hSlowEMA_HTF2,0,0,1,s)<=0)
      return ORDER_TYPE_BUY;
   return (f[0] > s[0]) ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
}

//+------------------------------------------------------------------+
//| AI MEMORY & ADAPTIVE THRESHOLD                                  |
//+------------------------------------------------------------------+
void ScanClosedDeals()
{
   HistorySelect(g_CurrentDay, TimeCurrent());
   for(int i=HistoryDealsTotal()-1; i>=0; i--)
   {
      ulong ticket = HistoryDealGetTicket(i);
      if(ticket>0 && HistoryDealGetInteger(ticket,DEAL_MAGIC)==InpMagicNumber &&
         HistoryDealGetString(ticket,DEAL_SYMBOL)==_Symbol &&
         HistoryDealGetInteger(ticket,DEAL_ENTRY)==DEAL_ENTRY_OUT)
      {
         double pnl = HistoryDealGetDouble(ticket,DEAL_PROFIT) +
                      HistoryDealGetDouble(ticket,DEAL_COMMISSION) +
                      HistoryDealGetDouble(ticket,DEAL_SWAP);
         UpdateAIMemory(pnl);
      }
   }
}

void UpdateAIMemory(double pnl)
{
   static datetime lastDealTime = 0;
   if(TimeCurrent() == lastDealTime) return;
   lastDealTime = TimeCurrent();
   
   for(int i=MAX_HISTORY-1; i>0; i--) g_TradeHistory[i] = g_TradeHistory[i-1];
   g_TradeHistory[0] = pnl;
   if(g_TradeHistoryCount < MAX_HISTORY) g_TradeHistoryCount++;
   
   if(pnl >= 0) { g_ConsecutiveWins++; g_ConsecutiveLosses = 0; }
   else         { g_ConsecutiveLosses++; g_ConsecutiveWins = 0; }
   
   g_RecentNetPnL = 0;
   int count = MathMin(g_TradeHistoryCount, 20);
   for(int i=0; i<count; i++) g_RecentNetPnL += g_TradeHistory[i];
}

void AdaptAIThreshold()
{
   if(!InpAIAdaptiveThreshold || g_TradeHistoryCount < 5) return;
   
   double avgPnl = (g_TradeHistoryCount>0) ? (g_RecentNetPnL / MathMin(g_TradeHistoryCount,20)) : 0;
   
   if(g_ConsecutiveLosses >= 3 || avgPnl < -0.5)
   {
      g_AIThreshold = (int)MathMin(90, g_AIThreshold + 5);
      g_AIBrainStatus = "DEFENSIVE (" + IntegerToString(g_AIThreshold) + ")";
   }
   else if(g_ConsecutiveWins >= 4 && avgPnl > 0.3)
   {
      g_AIThreshold = (int)MathMax(InpMinScoreToTrade, g_AIThreshold - 2);
      g_AIBrainStatus = "AGGRESSIVE (" + IntegerToString(g_AIThreshold) + ")";
   }
   else
   {
      g_AIBrainStatus = "NEUTRAL (" + IntegerToString(g_AIThreshold) + ")";
   }
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
//| SESSION DETECTION (with offset)                                 |
//+------------------------------------------------------------------+
ENUM_SESSION DetectSession()
{
   datetime gmt = TimeGMT() + InpBrokerUTCOffsetHours * 3600;
   MqlDateTime t;
   TimeToStruct(gmt, t);
   int h = t.hour;
   
   bool inLondon = (h >= InpLondonStartHour && h < InpLondonEndHour);
   bool inNY     = (h >= InpNYStartHour     && h < InpNYEndHour);
   bool inAsian  = (h >= InpAsianStartHour  && h < InpAsianEndHour);
   
   if(inLondon && inNY) { g_SessionLabel="OVERLAP"; g_SessionColor=C_GOLD_SHIMMER; g_SessionMultiplier=1.15; return SESSION_OVERLAP; }
   if(inLondon)         { g_SessionLabel="LONDON";  g_SessionColor=C_NEON_GREEN;  g_SessionMultiplier=1.05; return SESSION_LONDON;  }
   if(inNY)             { g_SessionLabel="NEW YORK";g_SessionColor=C_ACCENT_BLUE; g_SessionMultiplier=1.05; return SESSION_NEW_YORK;}
   if(inAsian)          { g_SessionLabel="ASIAN";   g_SessionColor=C_TEXT_MUTED;  g_SessionMultiplier=0.90; return SESSION_ASIAN;   }
   g_SessionLabel="OFF-HOURS"; g_SessionColor=C_TEXT_MUTED; g_SessionMultiplier=0.80; return SESSION_DEAD;
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

//+------------------------------------------------------------------+
//| DAILY HALT                                                      |
//+------------------------------------------------------------------+
bool CheckDailyHalt()
{
   if(g_DailyProfit <= -(InpDailyDrawdownHalt))
   {
      g_DailyHaltActive = true;
      g_StatusText  = "DAILY HALT: -$" + DoubleToString(MathAbs(g_DailyProfit),2);
      g_StatusColor = C_CRIMSON_RED;
      return true;
   }
   g_DailyHaltActive = false;
   return false;
}

//+------------------------------------------------------------------+
//| TRADE EXECUTION (with error handling)                           |
//+------------------------------------------------------------------+
void OpenTrade(ENUM_ORDER_TYPE signal, bool isFlip = false)
{
   MqlTick tick;
   if(!SymbolInfoTick(_Symbol, tick)) return;
   double price = (signal==ORDER_TYPE_BUY) ? tick.ask : tick.bid;
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   int    digs  = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   double minV  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxV  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double step  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   double lot   = MathMax(minV, MathMin(maxV, MathRound(InpLotSize/step)*step));
   
   double sl = 0.0, tp = 0.0;
   if(InpStopLossPoints > 0)
      sl = (signal==ORDER_TYPE_BUY) ? price - InpStopLossPoints*point : price + InpStopLossPoints*point;
   if(InpTakeProfitPoints > 0)
      tp = (signal==ORDER_TYPE_BUY) ? price + InpTakeProfitPoints*point : price - InpTakeProfitPoints*point;
   sl = NormalizeDouble(sl, digs);
   tp = NormalizeDouble(tp, digs);
   
   string comment = "GOLD v7 [" + g_SignalLabel + "] S:" + IntegerToString(g_AIScore);
   if(isFlip) comment += " FLIP";
   
   bool ok = false;
   if(signal==ORDER_TYPE_BUY)
      ok = g_Trade.Buy(lot, _Symbol, price, sl, tp, comment);
   else
      ok = g_Trade.Sell(lot, _Symbol, price, sl, tp, comment);
   
   if(ok)
   {
      g_DailyTrades++;
      Print("[GOLD v7] Trade opened: ", EnumToString(signal), " lot:", lot, " price:", price);
   }
   else
   {
      Print("[GOLD v7] Trade FAILED: ", g_Trade.ResultRetcodeDescription(), " retcode=", g_Trade.ResultRetcode());
   }
}

//+------------------------------------------------------------------+
//| UTILITY                                                         |
//+------------------------------------------------------------------+
void SyncLedger()
{
   datetime now = TimeCurrent();
   datetime mid = GetMidnight(now);
   if(mid > g_CurrentDay)
   {
      g_DailyTrades=0; g_DailyProfit=0.0; g_DailyWins=0; g_DailyLosses=0;
      g_ProfitReopens=0; g_TotalFlips=0; g_CurrentDay=mid; g_DailyHaltActive=false;
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
   CloseAllPositionsByMagic();
   Print("[GOLD v7] Liquidated all: ", reason);
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
//| DASHBOARD                                                       |
//+------------------------------------------------------------------+
void RenderDashboard()
{
   int aX=InpDashXOffset, aY=InpDashYOffset;
   int dW=460, dH=740;

   CreateRect("Bg",  aX,   aY,   dW,   dH,   C_MATRIX_BG, C_BORDER_GLOW, 2);
   CreateRect("Hdr", aX+2, aY+2, dW-4, 90,   C_HEADER_BAR, C_GOLD_SHIMMER, 2);

   CreateLabel("T1",  aX+16, aY+10, "THEE ELITE SCALPER",           C_GOLD_SHIMMER, 18, "Algerian");
   CreateLabel("T2",  aX+16, aY+40, "GOLD EDITION — AI BRAIN v7.0", C_AMBER_GOLD,    9, "Arial Black");
   CreateLabel("T3",  aX+16, aY+60, "6-Layer Confluence | Corrected Logic | Real Guards", C_TEXT_MUTED, 7, "Arial Italic");
   CreateLabel("Sym", aX+dW-115, aY+14, _Symbol, C_GOLD_SHIMMER, 14, "Impact");
   CreateLabel("Ver", aX+dW-115, aY+38, AI_VERSION, C_AMBER_GOLD, 7, "Arial Bold");

   CreateRect("PBg", aX+2, aY+95, dW-4, 24, C_PANEL_BG, clrNONE, 0);
   CreateLabel("PLbl", aX+16, aY+101, "[ MATRIX ]", C_TEXT_MUTED, 8, "Consolas Black");
   CreateLabel("PVal", aX+120, aY+101, "0 0 0 0", C_ACCENT_BLUE, 9, "Consolas");

   int p1Y=aY+124;
   CreateRect("P1", aX+2, p1Y, dW-4, 140, C_PANEL_BG, C_BORDER_GLOW, 1);
   CreateLabel("P1H",  aX+16,  p1Y+8,  "LIVE FINANCIAL DYNAMICS",    C_TEXT_LIGHT,  10, "Arial Black");
   CreateLabel("L_Bal",aX+22,  p1Y+34, "Account Balance:",            C_TEXT_MUTED,  9,  "Arial");
   CreateLabel("V_Bal",aX+230, p1Y+34, "$ 0.00",                      C_TEXT_LIGHT,  10, "Arial Bold");
   CreateLabel("L_Eq", aX+22,  p1Y+58, "Net Equity:",                 C_TEXT_MUTED,  9,  "Arial");
   CreateLabel("V_Eq", aX+230, p1Y+58, "$ 0.00",                      C_TEXT_LIGHT,  10, "Arial Bold");
   CreateLabel("L_Dp", aX+22,  p1Y+82, "Daily Net Yield:",            C_TEXT_MUTED,  9,  "Arial");
   CreateLabel("V_Dp", aX+230, p1Y+82, "$ 0.00",                      C_NEON_GREEN,  10, "Arial Black");
   CreateLabel("L_Fp", aX+22,  p1Y+106,"Floating P&L:",               C_TEXT_MUTED,  9,  "Arial");
   CreateLabel("V_Fp", aX+230, p1Y+106,"$ 0.00",                      C_NEON_GREEN,  10, "Arial Black");

   int p2Y=aY+270;
   CreateRect("P2", aX+2, p2Y, dW-4, 170, C_PANEL_BG, C_GOLD_SHIMMER, 1);
   CreateLabel("P2H",  aX+16,  p2Y+8,  "AI BRAIN — CONFLUENCE ENGINE",  C_GOLD_SHIMMER, 10, "Arial Black");
   CreateLabel("L_Sc", aX+22,  p2Y+34, "Total Confluence Score:",        C_TEXT_MUTED,   9,  "Arial");
   CreateLabel("V_Sc", aX+230, p2Y+34, "0 / 100",                        C_AMBER_GOLD,   11, "Arial Black");
   CreateLabel("L_Sg", aX+22,  p2Y+58, "Signal Strength:",               C_TEXT_MUTED,   9,  "Arial");
   CreateLabel("V_Sg", aX+230, p2Y+58, "SCANNING",                       C_TEXT_MUTED,   10, "Arial Black");
   CreateLabel("L_Th", aX+22,  p2Y+82, "AI Threshold (adaptive):",       C_TEXT_MUTED,   9,  "Arial");
   CreateLabel("V_Th", aX+230, p2Y+82, IntegerToString(g_AIThreshold),   C_TEAL_AI,      10, "Arial Bold");
   CreateLabel("L_Br", aX+22,  p2Y+106,"AI Brain Mode:",                 C_TEXT_MUTED,   9,  "Arial");
   CreateLabel("V_Br", aX+230, p2Y+106,"INITIALISING",                   C_TEAL_AI,      9,  "Arial Bold");

   CreateLabel("L_Ly", aX+22,  p2Y+130,"Layers:",          C_TEXT_MUTED, 8, "Arial");
   CreateLabel("V_L1", aX+75,  p2Y+130,"EMA:--",           C_TEXT_MUTED, 8, "Consolas");
   CreateLabel("V_L2", aX+140, p2Y+130,"RSI:--",           C_TEXT_MUTED, 8, "Consolas");
   CreateLabel("V_L3", aX+205, p2Y+130,"BB:--",            C_TEXT_MUTED, 8, "Consolas");
   CreateLabel("V_L4", aX+260, p2Y+130,"ATR:--",           C_TEXT_MUTED, 8, "Consolas");
   CreateLabel("V_L5", aX+315, p2Y+130,"CDL:--",           C_TEXT_MUTED, 8, "Consolas");
   CreateLabel("V_L6", aX+370, p2Y+130,"STR:--",           C_TEXT_MUTED, 8, "Consolas");

   int p3Y=aY+446;
   CreateRect("P3", aX+2, p3Y, dW-4, 150, C_PANEL_BG, C_BORDER_GLOW, 1);
   CreateLabel("P3H",  aX+16,  p3Y+8,  "BULK EXECUTION PIPELINE",     C_TEXT_LIGHT, 10, "Arial Black");
   CreateLabel("L_St", aX+22,  p3Y+32, "Engine Status:",               C_TEXT_MUTED,  9, "Arial");
   CreateLabel("V_St", aX+150, p3Y+32, "INITIALIZING",                 C_ACCENT_BLUE, 9, "Arial Black");
   CreateLabel("L_Tr", aX+22,  p3Y+56, "Daily Counter:",               C_TEXT_MUTED,  9, "Arial");
   CreateLabel("V_Tr", aX+230, p3Y+56, "0 / 100",                      C_TEXT_LIGHT,  9, "Arial Bold");
   CreateLabel("L_Wr", aX+22,  p3Y+80, "Win Ratio:",                   C_TEXT_MUTED,  9, "Arial");
   CreateLabel("V_Wr", aX+230, p3Y+80, "0.0 %",                        C_TEXT_LIGHT,  9, "Arial Bold");
   CreateLabel("L_Rp", aX+22,  p3Y+104,"Reopens:",                     C_TEXT_MUTED,  9, "Arial");
   CreateLabel("V_Rp", aX+230, p3Y+104,"0",                            C_NEON_GREEN,  9, "Arial Bold");
   CreateLabel("L_Dr", aX+22,  p3Y+128,"Active Direction:",            C_TEXT_MUTED,  9, "Arial");
   CreateLabel("V_Dr", aX+230, p3Y+128,"COMPUTING",                    C_TEXT_LIGHT,  9, "Arial Bold");

   int p4Y=aY+602;
   CreateRect("P4", aX+2, p4Y, dW-4, 66, C_PANEL_BG, C_ORANGE_FLIP, 1);
   CreateLabel("P4H",  aX+16,  p4Y+6,  "SESSION INTEL + ADAPTIVE",    C_ORANGE_FLIP, 8, "Arial Black");
   CreateLabel("L_Se", aX+22,  p4Y+24, "Session:",     C_TEXT_MUTED, 8, "Arial");
   CreateLabel("V_Se", aX+80,  p4Y+24, "DETECTING",   C_TEXT_MUTED, 9, "Arial Bold");
   CreateLabel("L_Mc", aX+190, p4Y+24, "Mid-Cycle:",   C_TEXT_MUTED, 8, "Arial");
   CreateLabel("V_Mc", aX+265, p4Y+24, "STABLE",       C_NEON_GREEN, 8, "Arial Bold");
   CreateLabel("L_Fl", aX+22,  p4Y+44, "Flips Today:", C_TEXT_MUTED, 8, "Arial");
   CreateLabel("V_Fl", aX+90,  p4Y+44, "0",            C_ORANGE_FLIP,8, "Arial Bold");
   CreateLabel("L_Hl", aX+170, p4Y+44, "Daily Halt:",  C_TEXT_MUTED, 8, "Arial");
   CreateLabel("V_Hl", aX+240, p4Y+44, "INACTIVE",     C_NEON_GREEN, 8, "Arial Bold");
   CreateLabel("L_Sp", aX+330, p4Y+24, "Spread:",      C_TEXT_MUTED, 8, "Arial");
   CreateLabel("V_Sp", aX+380, p4Y+24, "0 PTS",        C_TEXT_LIGHT, 8, "Arial Bold");

   CreateLabel("F1", aX+10, aY+675, "GOLD EDITION — Autonomous AI Confluence Engine v7", C_TEXT_MUTED, 7, "Arial");
   CreateLabel("F2", aX+320, aY+675, "FIXED & HARDENED", C_TEXT_MUTED, 7, "Arial Black");
   ChartRedraw(0);
}

void RefreshDashboard()
{
   UpdateLabel("PVal", g_HeartbeatStr, C_ACCENT_BLUE);
   UpdateLabel("V_Bal", "$ " + DoubleToString(AccountInfoDouble(ACCOUNT_BALANCE),2));
   UpdateLabel("V_Eq",  "$ " + DoubleToString(AccountInfoDouble(ACCOUNT_EQUITY),2));
   color cDp = (g_DailyProfit>=0) ? C_NEON_GREEN : C_CRIMSON_RED;
   UpdateLabel("V_Dp", (g_DailyProfit>=0?"+$ ":"-$ ")+DoubleToString(MathAbs(g_DailyProfit),2), cDp);
   double fpl = GetFloatingPnL();
   color cFp = (fpl>=0) ? C_NEON_GREEN : C_CRIMSON_RED;
   UpdateLabel("V_Fp", (fpl>=0?"+$ ":"-$ ")+DoubleToString(MathAbs(fpl),2), cFp);
   
   color scColor = (g_AIScore>=InpEliteScoreThreshold) ? C_GOLD_SHIMMER :
                   (g_AIScore>=InpStrongScoreThreshold) ? C_NEON_GREEN  : C_AMBER_GOLD;
   UpdateLabel("V_Sc", IntegerToString(g_AIScore) + " / 100", scColor);
   UpdateLabel("V_Sg", g_SignalLabel, g_SignalColor);
   UpdateLabel("V_Th", IntegerToString(g_AIThreshold), C_TEAL_AI);
   UpdateLabel("V_Br", g_AIBrainStatus, C_TEAL_AI);
   
   color c1=(g_ScoreEMA>70)?C_NEON_GREEN:(g_ScoreEMA>40)?C_AMBER_GOLD:C_CRIMSON_RED;
   color c2=(g_ScoreRSI>70)?C_NEON_GREEN:(g_ScoreRSI>40)?C_AMBER_GOLD:C_CRIMSON_RED;
   color c3=(g_ScoreBB>70)?C_NEON_GREEN:(g_ScoreBB>40)?C_AMBER_GOLD:C_CRIMSON_RED;
   color c4=(g_ScoreATR>70)?C_NEON_GREEN:(g_ScoreATR>40)?C_AMBER_GOLD:C_CRIMSON_RED;
   color c5=(g_ScoreCandle>70)?C_NEON_GREEN:(g_ScoreCandle>40)?C_AMBER_GOLD:C_CRIMSON_RED;
   color c6=(g_ScoreStructure>70)?C_NEON_GREEN:(g_ScoreStructure>40)?C_AMBER_GOLD:C_CRIMSON_RED;
   UpdateLabel("V_L1","EMA:"+IntegerToString(g_ScoreEMA),c1);
   UpdateLabel("V_L2","RSI:"+IntegerToString(g_ScoreRSI),c2);
   UpdateLabel("V_L3","BB:"+IntegerToString(g_ScoreBB),c3);
   UpdateLabel("V_L4","ATR:"+IntegerToString(g_ScoreATR),c4);
   UpdateLabel("V_L5","CDL:"+IntegerToString(g_ScoreCandle),c5);
   UpdateLabel("V_L6","STR:"+IntegerToString(g_ScoreStructure),c6);
   
   UpdateLabel("V_St", g_StatusText, g_StatusColor);
   UpdateLabel("V_Tr", IntegerToString(g_DailyTrades)+"/"+IntegerToString(InpMaxDailyTrades));
   int tot=g_DailyWins+g_DailyLosses;
   double wr=(tot>0)?((double)g_DailyWins/tot)*100.0:0.0;
   UpdateLabel("V_Wr", DoubleToString(wr,1)+" %");
   UpdateLabel("V_Rp", IntegerToString(g_ProfitReopens));
   UpdateLabel("V_Dr",(g_Direction==ORDER_TYPE_BUY)?"BULLISH":"BEARISH",
               (g_Direction==ORDER_TYPE_BUY)?C_NEON_GREEN:C_CRIMSON_RED);
   
   UpdateLabel("V_Se", g_SessionLabel, g_SessionColor);
   color mcC = (StringFind(g_MidCycleStatus,"FLIP")>=0) ? C_ORANGE_FLIP : C_NEON_GREEN;
   UpdateLabel("V_Mc", g_MidCycleStatus, mcC);
   UpdateLabel("V_Fl", IntegerToString(g_TotalFlips), C_ORANGE_FLIP);
   UpdateLabel("V_Hl", g_DailyHaltActive?"ACTIVE":"INACTIVE", g_DailyHaltActive?C_CRIMSON_RED:C_NEON_GREEN);
   UpdateLabel("V_Sp", IntegerToString((int)SymbolInfoInteger(_Symbol,SYMBOL_SPREAD))+" PTS");
   
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