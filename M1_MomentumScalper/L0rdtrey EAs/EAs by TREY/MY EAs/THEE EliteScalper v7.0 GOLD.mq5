//+------------------------------------------------------------------+
//|                            THEE EliteScalper v7.0 GOLD EDITION  |
//|                                     Upgraded Core Architecture  |
//+------------------------------------------------------------------+
#property copyright   "Copyright 2026, ELITE Systems"
#property version     "7.00"
#property description "GOLD EDITION — Fixed Net-Confluence Engine"
#property description "True Basket Target | Time-Synced Execution"
#property strict

#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>

#define DASH_PREFIX   "FXBH_G7_"
#define AI_VERSION    "GOLD AI v7.0"
#define MAX_HISTORY   20

//+------------------------------------------------------------------+
//| STATE MACHINE & ENUMS                                            |
//+------------------------------------------------------------------+
enum ENUM_ENGINE_STATE { STATE_SCANNING, STATE_BULK_OPENING, STATE_WAITING_CLOSE, STATE_COOLDOWN };
enum ENUM_SIGNAL_STRENGTH { SIG_NONE=0, SIG_WEAK=1, SIG_MODERATE=2, SIG_STRONG=3, SIG_ELITE=4 };
enum ENUM_SESSION { SESSION_ASIAN, SESSION_LONDON, SESSION_NEW_YORK, SESSION_OVERLAP, SESSION_DEAD };

//+------------------------------------------------------------------+
//| INPUT PARAMETERS                                                 |
//+------------------------------------------------------------------+
input group "=== CORE ENGINE SETTINGS ==="
input ulong   InpMagicNumber          = 999666;
input double  InpLotSize              = 0.01;
input int     InpMaxDailyTrades       = 100;

input group "=== BULK BASKET SETTINGS ==="
input int     InpBulkMaxTrades        = 5;
input int     InpBulkIntervalBars     = 1;         // Wait N Bars (not seconds) between bulk entries
input double  InpBasketTargetUSD      = 5.00;      // Total Net Profit required to close the entire cycle
input double  InpBasketStopLossUSD    = 15.00;     // Total Net Loss to hard-cut the cycle (Risk limits)

input group "=== ADAPTIVE MID-CYCLE ANALYSIS ==="
input bool    InpAdaptiveMidCycle     = true;
input int     InpConfirmFlipBars      = 2;         // Number of contiguous bars confirming trend flip

input group "=== AI BRAIN — NET CONFLUENCE ENGINE ==="
input int     InpMinScoreToTrade      = 60;
input int     InpEliteScoreThreshold  = 80;
input int     InpStrongScoreThreshold = 65;
input bool    InpRequireStrongMin     = true;
input bool    InpAIAdaptiveThreshold  = true;

input group "=== CONFLUENCE LAYER WEIGHTS ==="
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
input int     InpAsianStartHour       = 0, InpAsianEndHour  = 8;
input int     InpLondonStartHour      = 7, InpLondonEndHour = 16;
input int     InpNYStartHour          = 13, InpNYEndHour    = 22;

input group "=== ACCOUNT GUARDRAILS ==="
input int     InpMaxSpreadPoints      = 25;
input double  InpDailyDrawdownHalt    = 50.0;
input int     InpCooldownSeconds      = 60;

//+------------------------------------------------------------------+
//| GLOBAL OBJECTS & STATE VARIABLES                                 |
//+------------------------------------------------------------------+
CTrade          g_Trade;
CPositionInfo   g_Pos;

int   g_hFastEMA=INVALID_HANDLE, g_hSlowEMA=INVALID_HANDLE, g_hTrendEMA=INVALID_HANDLE;
int   g_hRSI=INVALID_HANDLE, g_hBB=INVALID_HANDLE, g_hATR=INVALID_HANDLE;
int   g_hFastEMA_HTF1=INVALID_HANDLE, g_hSlowEMA_HTF1=INVALID_HANDLE, g_hRSI_HTF1=INVALID_HANDLE;
int   g_hFastEMA_HTF2=INVALID_HANDLE, g_hSlowEMA_HTF2=INVALID_HANDLE;

ENUM_ENGINE_STATE  g_State          = STATE_SCANNING;
datetime           g_StateTimer     = 0;
datetime           g_LastBarTime    = 0;
datetime           g_LastTradeBar   = 0;
ENUM_ORDER_TYPE    g_Direction      = ORDER_TYPE_BUY;
int                g_BulkOpened     = 0;
datetime           g_CurrentDay     = 0;
int                g_FlipConfirmCount=0;
ENUM_ORDER_TYPE    g_LastSignal     = ORDER_TYPE_BUY;

int                g_AIScore           = 0;
ENUM_SIGNAL_STRENGTH g_SignalStrength  = SIG_NONE;
string             g_SignalLabel       = "SCANNING";
int                g_AIThreshold       = 0;
double             g_TradeHistory[MAX_HISTORY];
int                g_TradeHistoryCount = 0;
int                g_ConsecutiveLosses = 0;
int                g_ConsecutiveWins   = 0;

ENUM_SESSION       g_CurrentSession    = SESSION_DEAD;
string             g_SessionLabel      = "DEAD";
double             g_SessionMultiplier = 1.0;

int g_DailyTrades=0, g_DailyWins=0, g_DailyLosses=0, g_TotalFlips=0;
double g_DailyProfit=0.0;
bool g_DailyHaltActive=false;
string g_StatusText="BOOTING";

//+------------------------------------------------------------------+
//| INITIALIZATION                                                   |
//+------------------------------------------------------------------+
int OnInit() {
   g_Trade.SetExpertMagicNumber(InpMagicNumber);
   g_Trade.SetDeviationInPoints(15);
   
   if(InpLotSize <= 0.0) return INIT_PARAMETERS_INCORRECT;
   
   g_hFastEMA = iMA(_Symbol, _Period, InpFastEMAPeriod, 0, MODE_EMA, PRICE_CLOSE);
   g_hSlowEMA = iMA(_Symbol, _Period, InpSlowEMAPeriod, 0, MODE_EMA, PRICE_CLOSE);
   g_hTrendEMA= iMA(_Symbol, _Period, InpTrendEMAPeriod, 0, MODE_EMA, PRICE_CLOSE);
   g_hRSI     = iRSI(_Symbol, _Period, InpRSIPeriod, PRICE_CLOSE);
   g_hBB      = iBands(_Symbol, _Period, InpBBPeriod, 0, InpBBDeviation, PRICE_CLOSE);
   g_hATR     = iATR(_Symbol, _Period, InpATRPeriod);
   
   if(InpUseMTF) {
      g_hFastEMA_HTF1 = iMA(_Symbol, InpHTF1, InpFastEMAPeriod, 0, MODE_EMA, PRICE_CLOSE);
      g_hSlowEMA_HTF1 = iMA(_Symbol, InpHTF1, InpSlowEMAPeriod, 0, MODE_EMA, PRICE_CLOSE);
      g_hFastEMA_HTF2 = iMA(_Symbol, InpHTF2, InpFastEMAPeriod, 0, MODE_EMA, PRICE_CLOSE);
      g_hSlowEMA_HTF2 = iMA(_Symbol, InpHTF2, InpSlowEMAPeriod, 0, MODE_EMA, PRICE_CLOSE);
   }
   
   g_AIThreshold = InpMinScoreToTrade;
   ArrayInitialize(g_TradeHistory, 0.0);
   g_CurrentDay = GetMidnight(TimeCurrent());
   
   g_State = STATE_SCANNING;
   EventSetTimer(1);
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason) {
   EventKillTimer();
}

void OnTimer() {
   g_CurrentSession = DetectSession();
}

//+------------------------------------------------------------------+
//| TIME SYNCHRONIZATION ENGINE                                      |
//+------------------------------------------------------------------+
bool IsNewBar() {
   datetime currentBar = iTime(_Symbol, _Period, 0);
   if(currentBar != g_LastBarTime) {
      g_LastBarTime = currentBar;
      return true;
   }
   return false;
}

//+------------------------------------------------------------------+
//| TICK EXECUTION LOOP                                              |
//+------------------------------------------------------------------+
void OnTick() {
   if(!CheckLiquidity()) { g_StatusText = "MARKET SUSPENDED"; return; }
   if(CheckDailyHalt()) return;
   
   // STATE: TARGET EVALUATION (Continuous Tick Checking)
   if(g_State == STATE_WAITING_CLOSE) {
      EvaluateBasketTargets();
      if(!HasOpenPositions()) {
         g_StateTimer = TimeCurrent() + InpCooldownSeconds;
         g_State      = STATE_COOLDOWN;
         AdaptAIThreshold();
      }
      return;
   }
   
   if(g_DailyTrades >= InpMaxDailyTrades) return;

   // STATE: BULK OPENING (Bar Synchronized)
   if(g_State == STATE_BULK_OPENING) {
      ProcessBulkOpening();
      return;
   }
   
   // STATE: COOLDOWN
   if(g_State == STATE_COOLDOWN) {
      if(TimeCurrent() < g_StateTimer) return;
      g_State = STATE_SCANNING;
   }
   
   int spread = (int)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   if(spread > InpMaxSpreadPoints) return;
   if(InpUseSessionFilter && !CheckSessionAllowed()) return;
   
   // STATE: SCANNING (Bar Synchronized)
   if(g_State == STATE_SCANNING && IsNewBar()) {
      ENUM_ORDER_TYPE aiDir = ORDER_TYPE_BUY;
      int score = ComputeNetConfluenceScore(aiDir);
      g_AIScore = score;
      g_SignalStrength = ScoreToStrength(score);
      
      bool strongEnough = (!InpRequireStrongMin) || (g_SignalStrength >= SIG_STRONG);
      if(score < g_AIThreshold || !strongEnough) return;
      if(InpUseMTF && !GetMTFConfirmation(aiDir)) return;
      if(DetectATRSpike()) return;
      
      // Cycle Approved
      g_Direction = aiDir;
      g_State = STATE_BULK_OPENING;
      g_BulkOpened = 0;
      g_LastTradeBar = 0;
      g_FlipConfirmCount = 0;
   }
}

//+------------------------------------------------------------------+
//| BULK DEPLOYMENT (FIXED INTERVAL)                                 |
//+------------------------------------------------------------------+
void ProcessBulkOpening() {
   // Only analyze and open on new bars
   if(!IsNewBar()) return;
   
   datetime currentBar = iTime(_Symbol, _Period, 0);
   int barsSinceLast = (g_LastTradeBar == 0) ? InpBulkIntervalBars : (int)((currentBar - g_LastTradeBar) / PeriodSeconds(_Period));
   
   // Adaptive Flip check
   if(InpAdaptiveMidCycle && g_BulkOpened > 0) {
      ENUM_ORDER_TYPE newDir;
      int currentScore = ComputeNetConfluenceScore(newDir);
      
      if(newDir != g_Direction && currentScore >= g_AIThreshold) {
         g_FlipConfirmCount++;
         if(g_FlipConfirmCount >= InpConfirmFlipBars) {
            ExecuteFlip(newDir);
            return;
         }
      } else {
         g_FlipConfirmCount = 0;
      }
   }
   
   // Open next interval trade
   if(barsSinceLast >= InpBulkIntervalBars) {
      OpenTrade(g_Direction);
      g_BulkOpened++;
      g_LastTradeBar = currentBar;
      
      if(g_BulkOpened >= InpBulkMaxTrades) {
         g_State = STATE_WAITING_CLOSE;
      }
   }
}

//+------------------------------------------------------------------+
//| TRUE BASKET EVALUATOR                                            |
//+------------------------------------------------------------------+
void EvaluateBasketTargets() {
   double totalBasketPnL = 0;
   int openCount = 0;
   
   for(int i = PositionsTotal()-1; i >= 0; i--) {
      if(g_Pos.SelectByIndex(i) && g_Pos.Magic()==InpMagicNumber && g_Pos.Symbol()==_Symbol) {
         totalBasketPnL += g_Pos.Profit() + g_Pos.Swap() + g_Pos.Commission();
         openCount++;
      }
   }
   
   if(openCount == 0) return;

   // Evaluate net portfolio status instead of single trades
   if(totalBasketPnL >= InpBasketTargetUSD) {
      LiquidateAll("BASKET TARGET SECURED");
      UpdateAIMemory(totalBasketPnL);
   } else if(totalBasketPnL <= -InpBasketStopLossUSD) {
      LiquidateAll("BASKET RISK CUT");
      UpdateAIMemory(totalBasketPnL);
   }
}

//+------------------------------------------------------------------+
//| NET CONFLUENCE SCORING ENGINE (Conflict Penalty Fixed)           |
//+------------------------------------------------------------------+
int ComputeNetConfluenceScore(ENUM_ORDER_TYPE &outDir) {
   int buyScore = 0;
   int sellScore = 0;
   
   ENUM_ORDER_TYPE dE, dR, dB, dC, dS;
   
   // Accumulate raw positional scores
   int sEMA = ScoreEMALayer(dE);
   if(dE == ORDER_TYPE_BUY) buyScore += sEMA * InpWeightEMA; else sellScore += sEMA * InpWeightEMA;
   
   int sRSI = ScoreRSILayer(dR);
   if(dR == ORDER_TYPE_BUY) buyScore += sRSI * InpWeightRSI; else sellScore += sRSI * InpWeightRSI;
   
   int sBB = ScoreBBLayer(dB);
   if(dB == ORDER_TYPE_BUY) buyScore += sBB * InpWeightBB; else sellScore += sBB * InpWeightBB;
   
   int sCdl = ScoreCandleLayer(dC);
   if(dC == ORDER_TYPE_BUY) buyScore += sCdl * InpWeightCandle; else sellScore += sCdl * InpWeightCandle;
   
   int sStr = ScoreStructureLayer(dS);
   if(dS == ORDER_TYPE_BUY) buyScore += sStr * InpWeightStructure; else sellScore += sStr * InpWeightStructure;
   
   // NET SCORE: Subtracting contradictions to prevent fake high scores
   int netDifference = MathAbs(buyScore - sellScore);
   outDir = (buyScore > sellScore) ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
   
   // Volatility multiplier (scales down if market is flat)
   double atrMultiplier = ScoreATRLayer() / 100.0;
   
   int finalScore = (int)((netDifference / 100.0) * atrMultiplier * g_SessionMultiplier);
   return (int)MathMin(100, finalScore);
}

//--- Indicator Scoring Logic Remains Structurally Similar but Fed into Net Calculator
int ScoreEMALayer(ENUM_ORDER_TYPE &dir) {
   double fast[1], slow[1], trend[1];
   if(CopyBuffer(g_hFastEMA, 0, 0, 1, fast) <= 0 || CopyBuffer(g_hSlowEMA, 0, 0, 1, slow) <= 0 || CopyBuffer(g_hTrendEMA,0,0,1,trend)<=0) return 0;
   double price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   bool bullCross = (fast[0] > slow[0]); bool aboveTrend = (price > trend[0]);
   dir = bullCross ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
   if(bullCross == aboveTrend) return 100;
   return 0; // Penalize mixed signals heavily
}

int ScoreRSILayer(ENUM_ORDER_TYPE &dir) {
   double rsi[2]; if(CopyBuffer(g_hRSI, 0, 0, 2, rsi) <= 0) return 0;
   dir = (rsi[0] > 50) ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
   if(rsi[0] < InpRSIOversold || rsi[0] > InpRSIOverbought) return 100;
   return 50;
}

int ScoreBBLayer(ENUM_ORDER_TYPE &dir) {
   double upper[1], lower[1], mid[1];
   if(CopyBuffer(g_hBB, 1, 0, 1, upper)<=0 || CopyBuffer(g_hBB, 2, 0, 1, lower)<=0 || CopyBuffer(g_hBB, 0, 0, 1, mid)<=0) return 0;
   double price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   dir = (price > mid[0]) ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
   if(price <= lower[0] || price >= upper[0]) return 100;
   return 40;
}

int ScoreATRLayer() {
   double atr[2]; if(CopyBuffer(g_hATR, 0, 0, 2, atr) <= 0) return 50;
   if(atr[0] < atr[1] * InpATRMinMultiplier) return 20; // Flat
   return 100; // Optimal Volatility
}

int ScoreCandleLayer(ENUM_ORDER_TYPE &dir) {
   double o[2], h[2], l[2], c[2];
   if(CopyOpen(_Symbol,_Period,0,2,o)<=0 || CopyClose(_Symbol,_Period,0,2,c)<=0) return 0;
   dir = (c[1] > o[1]) ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
   return 80; 
}

int ScoreStructureLayer(ENUM_ORDER_TYPE &dir) {
   int lb = InpStructureLookback;
   int hBar = iHighest(_Symbol, _Period, MODE_HIGH, lb, 1);
   int lBar = iLowest(_Symbol, _Period, MODE_LOW, lb, 1);
   double mid = (iHigh(_Symbol, _Period, hBar) + iLow(_Symbol, _Period, lBar)) / 2.0;
   dir = (SymbolInfoDouble(_Symbol, SYMBOL_BID) > mid) ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
   return 100;
}

//+------------------------------------------------------------------+
//| SUPPORTING FUNCTIONS                                             |
//+------------------------------------------------------------------+
bool GetMTFConfirmation(ENUM_ORDER_TYPE dir) {
   double f1[1], s1[1], f2[1], s2[1];
   if(CopyBuffer(g_hFastEMA_HTF1,0,0,1,f1)<=0 || CopyBuffer(g_hSlowEMA_HTF1,0,0,1,s1)<=0) return true;
   bool mt1Bull = (f1[0] > s1[0]);
   if((dir == ORDER_TYPE_BUY && !mt1Bull) || (dir == ORDER_TYPE_SELL && mt1Bull)) return false;
   return true;
}

bool DetectATRSpike() {
   double atr[2];
   if(CopyBuffer(g_hATR, 0, 0, 2, atr) > 0) {
      return (atr[0] > atr[1] * InpATRSpikeMultiplier);
   }
   return false;
}

void ExecuteFlip(ENUM_ORDER_TYPE newDir) {
   LiquidateAll("ADAPTIVE FLIP TRIGGERED");
   g_Direction = newDir;
   g_FlipConfirmCount = 0;
   g_TotalFlips++;
}

void AdaptAIThreshold() {
   if(!InpAIAdaptiveThreshold || g_TradeHistoryCount < 3) return;
   
   // FIX: Do not push thresholds to impossible limits
   if(g_ConsecutiveLosses >= 2) {
      g_AIThreshold = (int)MathMin(InpEliteScoreThreshold, g_AIThreshold + 2); // Cap the increase
   } else if(g_ConsecutiveWins >= 2) {
      g_AIThreshold = (int)MathMax(InpMinScoreToTrade, g_AIThreshold - 2);
   }
}

void UpdateAIMemory(double pnl) {
   for(int i = MAX_HISTORY-1; i > 0; i--) g_TradeHistory[i] = g_TradeHistory[i-1];
   g_TradeHistory[0] = pnl;
   if(g_TradeHistoryCount < MAX_HISTORY) g_TradeHistoryCount++;
   if(pnl >= 0) { g_ConsecutiveWins++; g_ConsecutiveLosses=0; } else { g_ConsecutiveLosses++; g_ConsecutiveWins=0; }
}

ENUM_SESSION DetectSession() {
   MqlDateTime t; TimeToStruct(TimeGMT(), t);
   int h = t.hour;
   bool inLon = (h >= InpLondonStartHour && h < InpLondonEndHour);
   bool inNY  = (h >= InpNYStartHour && h < InpNYEndHour);
   if(inLon && inNY) return SESSION_OVERLAP;
   if(inLon) return SESSION_LONDON;
   if(inNY) return SESSION_NEW_YORK;
   return SESSION_DEAD;
}

bool CheckSessionAllowed() {
   if(g_CurrentSession == SESSION_LONDON) return InpTradeLondon;
   if(g_CurrentSession == SESSION_NEW_YORK) return InpTradeNewYork;
   if(g_CurrentSession == SESSION_OVERLAP) return InpTradeOverlap;
   return false;
}

bool CheckDailyHalt() {
   if(g_DailyProfit <= -(InpDailyDrawdownHalt)) return true;
   return false;
}

void OpenTrade(ENUM_ORDER_TYPE signal) {
   double price = (signal==ORDER_TYPE_BUY) ? SymbolInfoDouble(_Symbol,SYMBOL_ASK) : SymbolInfoDouble(_Symbol,SYMBOL_BID);
   double step  = SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_STEP);
   double lot   = MathRound(InpLotSize/step)*step;
   string comment = "GOLD AI v7 [" + EnumToString(signal) + "]";
   
   if(signal==ORDER_TYPE_BUY) g_Trade.Buy(lot, _Symbol, price, 0, 0, comment);
   else g_Trade.Sell(lot, _Symbol, price, 0, 0, comment);
   
   g_DailyTrades++;
}

void LiquidateAll(string reason) {
   for(int i=PositionsTotal()-1; i>=0; i--) {
      if(g_Pos.SelectByIndex(i) && g_Pos.Magic()==InpMagicNumber && g_Pos.Symbol()==_Symbol) {
         g_Trade.PositionClose(g_Pos.Ticket());
      }
   }
}

bool HasOpenPositions() {
   for(int i=PositionsTotal()-1; i>=0; i--) {
      if(g_Pos.SelectByIndex(i) && g_Pos.Magic()==InpMagicNumber && g_Pos.Symbol()==_Symbol) return true;
   }
   return false;
}

bool CheckLiquidity() {
   ENUM_SYMBOL_TRADE_MODE m = (ENUM_SYMBOL_TRADE_MODE)SymbolInfoInteger(_Symbol,SYMBOL_TRADE_MODE);
   return (m==SYMBOL_TRADE_MODE_FULL || m==SYMBOL_TRADE_MODE_LONGONLY || m==SYMBOL_TRADE_MODE_SHORTONLY);
}

datetime GetMidnight(datetime t) {
   MqlDateTime d; TimeToStruct(t,d);
   return t - (datetime)(d.hour*3600 + d.min*60 + d.sec);
}

ENUM_SIGNAL_STRENGTH ScoreToStrength(int score) {
   if(score >= InpEliteScoreThreshold)  return SIG_ELITE;
   if(score >= InpStrongScoreThreshold) return SIG_STRONG;
   if(score >= 45) return SIG_MODERATE;
   if(score > 0) return SIG_WEAK;
   return SIG_NONE;
}
//+------------------------------------------------------------------+