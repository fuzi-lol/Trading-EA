//+------------------------------------------------------------------+
//|                                             THEE EliteScalper.mq5|
//|                                  Copyright 2026, FXBotHub Systems|
//|                                             https://fxbothub.com |
//+------------------------------------------------------------------+
#property copyright   "Copyright 2026, THEE EliteScalper Systems"
#property version     "5.00"
#property description "Institutional Bulk-Execution Engine"
#property description "Automated Matrix Grid with Individual Targets"
#property strict

#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>

#define DASH_PREFIX "FXBH_DS_"

//--- System State Machine
enum ENUM_ENGINE_STATE
{
   STATE_SCANNING,       // Looking for a signal
   STATE_BULK_OPENING,   // Actively opening the 10 trades
   STATE_WAITING_CLOSE,  // Waiting for all trades to hit profit
   STATE_COOLDOWN        // 1-minute anti-manipulation delay
};

//+------------------------------------------------------------------+
//| INPUT PARAMETERS                                                 |
//+------------------------------------------------------------------+
input group "=== CORE EXECUTIVE SETTINGS ==="
input ulong   InpMagicNumber       = 999111;    // Institutional Magic Number
input double  InpLotSize           = 0.01;      // Bulk Allocation Lot Size
input int     InpMaxDailyTrades    = 100;       // Maximum Daily Trades (Expanded for bulk)

input group "=== BULK EXECUTION SETTINGS ==="
input int     InpBulkMaxTrades     = 10;        // Total Trades per Cycle
input int     InpBulkIntervalSec   = 10;        // Interval Between Trades (s)
input double  InpPerTradeTargetUSD = 0.50;      // Take Profit PER TRADE ($)
input double  InpImmediateReopenPct= 0.15;      // Reopen Velocity Trigger Run (%)

input group "=== ANTI-MANIPULATION COOLDOWN ==="
input int     InpCooldownSeconds   = 60;        // Anti-Spread Manipulation Delay (s)

input group "=== ACCOUNT GUARDRAIL PROTECTION ==="
input int     InpStopLossPoints    = 300;       // Emergency Stop Loss (Points)
input int     InpTakeProfitPoints  = 600;       // Structural Take Profit (Points)
input int     InpMaxSpreadPoints   = 25;        // Maximum Allowed Spread Ceiling

input group "=== DUAL-CORE STRUCTURAL CONFIRMATION ==="
input int     InpFastEMAPeriod     = 9;         // Momentum Core Fast EMA
input int     InpSlowEMAPeriod     = 21;        // Structural Baseline Slow EMA
input int     InpMarketStructureBar= 5;         // Structural High/Low Breakout Bars

input group "=== INTERFACE DESIGN & LAYOUT ==="
input int     InpDashXOffset       = 15;        // Visual Matrix X Anchor Offset
input int     InpDashYOffset       = 15;        // Visual Matrix Y Anchor Offset

//+------------------------------------------------------------------+
//| FINTECH COLOR PALETTE CONSTANTS                                  |
//+------------------------------------------------------------------+
const color C_MATRIX_BG      = C'4,6,10';     // Deep Slate Black
const color C_PANEL_BG       = C'10,16,26';   // Dark FinTech Card Panel
const color C_HEADER_BAR     = C'14,32,66';   // Electric Corporate Navy
const color C_BORDER_GLOW    = C'0,90,180';   // Cyber Blue Line Glow
const color C_ACCENT_BLUE    = C'0,140,255';  // FXBotHub Primary Core Blue
const color C_NEON_GREEN     = C'0,225,120';  // High-Performance Profit Green
const color C_CRIMSON_RED    = C'235,45,65';  // Risk Liquidated Red
const color C_AMBER_GOLD     = C'255,185,25'; // Warning / System Delay Gold
const color C_PURPLE_SCAN    = C'180,0,255';  // Analysis Phase Purple
const color C_TEXT_LIGHT     = C'235,242,255';// Crisp Field Output White
const color C_TEXT_MUTED     = C'130,145,170';// Secondary Parameter Label Gray

//+------------------------------------------------------------------+
//| GLOBAL UTILITY VARIABLES                                         |
//+------------------------------------------------------------------+
CTrade          g_TradeEngine;
CPositionInfo   g_PositionManager;

int             g_FastEMAHandle      = INVALID_HANDLE;
int             g_SlowEMAHandle      = INVALID_HANDLE;
datetime        g_CurrentSessionDay  = 0;

//--- State Machine & Bulk Tracking Variables
ENUM_ENGINE_STATE g_EngineState      = STATE_SCANNING;
datetime        g_StateTimer         = 0;
ENUM_ORDER_TYPE g_PendingDirection   = ORDER_TYPE_BUY;

int             g_BulkTradesOpened   = 0;
datetime        g_LastTradeOpenTime  = 0;

//--- Operational Metrics
int             g_TotalDailyTrades   = 0;
double          g_TotalDailyProfit   = 0.0;
int             g_TotalDailyWins     = 0;
int             g_TotalDailyLosses   = 0;
int             g_TotalProfitReopens = 0;
string          g_SystemHeartbeatStr = "0 0 0 0";
string          g_EngineStatusText   = "BOOTING ENGINE";
color           g_EngineStatusColor  = C_AMBER_GOLD;

//+------------------------------------------------------------------+
//| FORWARD FUNCTION DECLARATIONS                                    |
//+------------------------------------------------------------------+
void            SynchronizeLedgerStats();
void            EvaluateActiveTargetProfits();
void            ProcessBulkOpening();
void            ExecuteMarketEntry(ENUM_ORDER_TYPE signal);
bool            VerifyMarketLiquidity();
void            LiquidateActivePositions(string logContext);
bool            IsPositionActive();
double          CalculateFloatingFinancials();
ENUM_ORDER_TYPE DetermineMarketArchitecture();
datetime        GetMidnightTimestamp(datetime timeValue);
void            RenderCoreDashboard();
void            RefreshDashboardVisuals();
void            PurgeDashboardObjects();
void            CreateInterfaceComponent(string nm, int x, int y, int w, int h, color bg, color border, int bw);
void            CreateTextComponent(string nm, int x, int y, string txt, color clr, int fsz, string font);
void            UpdateTextComponent(string nm, string txt, color clr = clrNONE);

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   g_TradeEngine.SetExpertMagicNumber(InpMagicNumber);
   g_TradeEngine.SetDeviationInPoints(15);
   
   if(InpLotSize <= 0.0) return INIT_PARAMETERS_INCORRECT;
   
   g_FastEMAHandle = iMA(_Symbol, _Period, InpFastEMAPeriod, 0, MODE_EMA, PRICE_CLOSE);
   g_SlowEMAHandle = iMA(_Symbol, _Period, InpSlowEMAPeriod, 0, MODE_EMA, PRICE_CLOSE);
   
   if(g_FastEMAHandle == INVALID_HANDLE || g_SlowEMAHandle == INVALID_HANDLE) return INIT_FAILED;
   
   g_CurrentSessionDay = GetMidnightTimestamp(TimeCurrent());
   SynchronizeLedgerStats();
   
   RenderCoreDashboard();
   
   g_EngineState = STATE_SCANNING;
   EventSetTimer(1);
   
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   EventKillTimer();
   PurgeDashboardObjects();
   if(g_FastEMAHandle != INVALID_HANDLE) IndicatorRelease(g_FastEMAHandle);
   if(g_SlowEMAHandle != INVALID_HANDLE) IndicatorRelease(g_SlowEMAHandle);
}

//+------------------------------------------------------------------+
//| Expert timer function                                            |
//+------------------------------------------------------------------+
void OnTimer()
{
   uint computationalCycle = GetTickCount() % 4;
   if(computationalCycle == 0) g_SystemHeartbeatStr = "1 0 1 1   0 1 0 0";
   if(computationalCycle == 1) g_SystemHeartbeatStr = "0 1 0 0   1 0 1 1";
   if(computationalCycle == 2) g_SystemHeartbeatStr = "1 1 0 1   0 0 1 0";
   if(computationalCycle == 3) g_SystemHeartbeatStr = "0 0 1 0   1 1 0 1";

   SynchronizeLedgerStats();
   RefreshDashboardVisuals();
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   if(!VerifyMarketLiquidity())
   {
      g_EngineStatusText = "MARKET SUSPENDED"; g_EngineStatusColor = C_CRIMSON_RED;
      return;
   }
   
   //--- 1. State: Waiting for all bulk trades to hit target individually
   if(g_EngineState == STATE_WAITING_CLOSE)
   {
      EvaluateActiveTargetProfits();
      
      // If all positions matching our magic number are closed
      if(!IsPositionActive()) 
      {
         g_StateTimer  = TimeCurrent() + InpCooldownSeconds;
         g_EngineState = STATE_COOLDOWN;
         g_EngineStatusText  = "CYCLE COMPLETE. COOLING DOWN."; 
         g_EngineStatusColor = C_NEON_GREEN;
      }
      return; 
   }
   
   //--- 2. Allocation Limits (Hard Cap)
   if(g_TotalDailyTrades >= InpMaxDailyTrades)
   {
      g_EngineStatusText = "ALLOCATION LIMIT REACHED";
      g_EngineStatusColor = C_AMBER_GOLD;
      return;
   }
   
   //--- 3. State: Actively opening the bulk matrix
   if(g_EngineState == STATE_BULK_OPENING)
   {
      ProcessBulkOpening();
      return;
   }

   //--- 4. State Machine Cooldown Routing
   if(g_EngineState == STATE_COOLDOWN)
   {
      int cooldownLeft = (int)(g_StateTimer - TimeCurrent());
      if(cooldownLeft > 0)
      {
         g_EngineStatusText = "ANTI-MANIPULATION DELAY... (" + IntegerToString(cooldownLeft) + "s)";
         g_EngineStatusColor = C_AMBER_GOLD;
         return;
      }
      g_EngineState = STATE_SCANNING; // Cooldown finished
   }

   int spread = (int)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   if(spread > InpMaxSpreadPoints)
   {
      g_EngineStatusText = "SPREAD SKEW ALERT (" + IntegerToString(spread) + " PTS)";
      g_EngineStatusColor = C_CRIMSON_RED;
      return;
   }

   //--- 5. State: Scanning for initial signal
   if(g_EngineState == STATE_SCANNING)
   {
      ENUM_ORDER_TYPE rawSignal = DetermineMarketArchitecture();
      g_EngineState       = STATE_BULK_OPENING;
      g_PendingDirection  = rawSignal;
      g_BulkTradesOpened  = 0;
      g_LastTradeOpenTime = 0;
      
      Print("[THEE EliteScalper] Signal Detected. Commencing Bulk Execution Sequence.");
   }
}

//+------------------------------------------------------------------+
//| Bulk Opening Logic (10-second intervals)                         |
//+------------------------------------------------------------------+
void ProcessBulkOpening()
{
   g_EngineStatusText  = "DEPLOYING BULK TRADES: " + IntegerToString(g_BulkTradesOpened) + "/" + IntegerToString(InpBulkMaxTrades);
   g_EngineStatusColor = C_PURPLE_SCAN;

   // Check if the specified interval has passed since the last trade
   if(TimeCurrent() - g_LastTradeOpenTime >= InpBulkIntervalSec)
   {
      ExecuteMarketEntry(g_PendingDirection);
      g_BulkTradesOpened++;
      g_LastTradeOpenTime = TimeCurrent();
      
      // Transition state if all bulk trades are deployed
      if(g_BulkTradesOpened >= InpBulkMaxTrades)
      {
         g_EngineState = STATE_WAITING_CLOSE;
         Print("[THEE EliteScalper] Bulk deployment complete. Awaiting targets.");
      }
   }
}

//+------------------------------------------------------------------+
//| Individual Target Evaluator                                      |
//+------------------------------------------------------------------+
void EvaluateActiveTargetProfits()
{
   g_EngineStatusText  = "WAITING FOR TARGETS ($" + DoubleToString(InpPerTradeTargetUSD, 2) + "/ea)";
   g_EngineStatusColor = C_ACCENT_BLUE;
   
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(g_PositionManager.SelectByIndex(i) && g_PositionManager.Magic() == InpMagicNumber && g_PositionManager.Symbol() == _Symbol)
      {
         // 1. Evaluate Net Profit (per trade)
         double singleTradePnL = g_PositionManager.Profit() + g_PositionManager.Swap() + g_PositionManager.Commission();
         if(singleTradePnL >= InpPerTradeTargetUSD)
         {
            g_TradeEngine.PositionClose(g_PositionManager.Ticket());
            Print("[THEE EliteScalper] Individual Bulk Trade Target Secured: +$", DoubleToString(singleTradePnL, 2));
            continue; // Move to the next position after closing
         }

         // 2. Evaluate Velocity Reopen (Optional structural safety net)
         double openPrice = g_PositionManager.PriceOpen();
         if(openPrice > 0.0)
         {
            double pctMove = 0.0;
            if(g_PositionManager.PositionType() == POSITION_TYPE_BUY)
               pctMove = ((SymbolInfoDouble(_Symbol, SYMBOL_BID) - openPrice) / openPrice) * 100.0;
            else
               pctMove = ((openPrice - SymbolInfoDouble(_Symbol, SYMBOL_ASK)) / openPrice) * 100.0;
               
            if(pctMove >= InpImmediateReopenPct)
            {
               g_TradeEngine.PositionClose(g_PositionManager.Ticket());
               g_TotalProfitReopens++;
               ENUM_ORDER_TYPE reopenDirection = (g_PositionManager.PositionType() == POSITION_TYPE_BUY) ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
               ExecuteMarketEntry(reopenDirection);
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Direct Dispatch Pipeline                                         |
//+------------------------------------------------------------------+
void ExecuteMarketEntry(ENUM_ORDER_TYPE signal)
{
   double price = (signal == ORDER_TYPE_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   int digits   = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   
   double minVol = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxVol = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double step   = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   double lot    = MathMax(minVol, MathMin(maxVol, MathRound(InpLotSize / step) * step));

   double sl = 0.0, tp = 0.0;
   if(InpStopLossPoints > 0)
      sl = (signal == ORDER_TYPE_BUY) ? price - (InpStopLossPoints * point) : price + (InpStopLossPoints * point);
   if(InpTakeProfitPoints > 0)
      tp = (signal == ORDER_TYPE_BUY) ? price + (InpTakeProfitPoints * point) : price - (InpTakeProfitPoints * point);

   sl = NormalizeDouble(sl, digits); tp = NormalizeDouble(tp, digits);
   bool ok = (signal == ORDER_TYPE_BUY) ? g_TradeEngine.Buy(lot, _Symbol, price, sl, tp, "THEE BulkScalper") 
                                        : g_TradeEngine.Sell(lot, _Symbol, price, sl, tp, "THEE BulkScalper");
   if(ok)
   {
      Print("[THEE BulkScalper DISPATCH] Executed: ", EnumToString(signal), " Allocation: ", lot);
      g_TotalDailyTrades++;
   }
}

//+------------------------------------------------------------------+
//| Dual-Core Market Structure Evaluator                             |
//+------------------------------------------------------------------+
ENUM_ORDER_TYPE DetermineMarketArchitecture()
{
   double fast[1], slow[1];
   if(CopyBuffer(g_FastEMAHandle, 0, 0, 1, fast) <= 0 || CopyBuffer(g_SlowEMAHandle, 0, 0, 1, slow) <= 0) return ORDER_TYPE_BUY;
   bool isBullTrend = (fast[0] > slow[0]);
   
   int highBar = iHighest(_Symbol, _Period, MODE_HIGH, InpMarketStructureBar, 1);
   int lowBar  = iLowest(_Symbol, _Period, MODE_LOW, InpMarketStructureBar, 1);
   double mid  = (iHigh(_Symbol, _Period, highBar) + iLow(_Symbol, _Period, lowBar)) / 2.0;
   bool isBullStruct = (SymbolInfoDouble(_Symbol, SYMBOL_BID) > mid);

   if(isBullTrend && isBullStruct) return ORDER_TYPE_BUY;
   if(!isBullTrend && !isBullStruct) return ORDER_TYPE_SELL;
   return (SymbolInfoDouble(_Symbol, SYMBOL_BID) > fast[0]) ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
}

//+------------------------------------------------------------------+
//| Ledger & Utility Functions                                       |
//+------------------------------------------------------------------+
void SynchronizeLedgerStats()
{
   datetime now = TimeCurrent();
   datetime mid = GetMidnightTimestamp(now);
   if(mid > g_CurrentSessionDay)
   {
      g_TotalDailyTrades = 0; g_TotalDailyProfit = 0.0; g_TotalDailyWins = 0;
      g_TotalDailyLosses = 0; g_TotalProfitReopens = 0;
      g_CurrentSessionDay = mid;
   }

   g_TotalDailyProfit = 0.0; g_TotalDailyWins = 0;
   g_TotalDailyLosses = 0;
   
   if(HistorySelect(g_CurrentSessionDay, now))
   {
      for(int i = 0; i < HistoryDealsTotal(); i++)
      {
         ulong tkt = HistoryDealGetTicket(i);
         if(tkt > 0 && HistoryDealGetInteger(tkt, DEAL_MAGIC) == InpMagicNumber && HistoryDealGetString(tkt, DEAL_SYMBOL) == _Symbol)
         {
            if(HistoryDealGetInteger(tkt, DEAL_ENTRY) == DEAL_ENTRY_OUT)
            {
               double pnl = HistoryDealGetDouble(tkt, DEAL_PROFIT) + HistoryDealGetDouble(tkt, DEAL_COMMISSION) + HistoryDealGetDouble(tkt, DEAL_SWAP);
               g_TotalDailyProfit += pnl;
               if(pnl >= 0.0) g_TotalDailyWins++; else g_TotalDailyLosses++;
            }
         }
      }
   }
}

void LiquidateActivePositions(string logContext)
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(g_PositionManager.SelectByIndex(i) && g_PositionManager.Magic() == InpMagicNumber && g_PositionManager.Symbol() == _Symbol)
         g_TradeEngine.PositionClose(g_PositionManager.Ticket());
   }
}

bool IsPositionActive()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
      if(g_PositionManager.SelectByIndex(i) && g_PositionManager.Magic() == InpMagicNumber && g_PositionManager.Symbol() == _Symbol) return true;
   return false;
}

double CalculateFloatingFinancials()
{
   double total = 0.0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
      if(g_PositionManager.SelectByIndex(i) && g_PositionManager.Magic() == InpMagicNumber && g_PositionManager.Symbol() == _Symbol)
         total += g_PositionManager.Profit() + g_PositionManager.Swap() + g_PositionManager.Commission();
   return total;
}

bool VerifyMarketLiquidity()
{
   ENUM_SYMBOL_TRADE_MODE mode = (ENUM_SYMBOL_TRADE_MODE)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_MODE);
   return (mode == SYMBOL_TRADE_MODE_FULL || mode == SYMBOL_TRADE_MODE_LONGONLY || mode == SYMBOL_TRADE_MODE_SHORTONLY);
}

datetime GetMidnightTimestamp(datetime t)
{
   MqlDateTime d;
   TimeToStruct(t, d);
   return t - (datetime)(d.hour * 3600 + d.min * 60 + d.sec);
}

//====================================================================
// DASHBOARD CORE GRAPHICS ENGINE
//====================================================================
void RenderCoreDashboard()
{
   int aX = InpDashXOffset, aY = InpDashYOffset;
   int dW = 440, dH = 555;

   CreateInterfaceComponent("Bg", aX, aY, dW, dH, C_MATRIX_BG, C_BORDER_GLOW, 2);
   CreateInterfaceComponent("Hdr", aX+2, aY+2, dW-4, 82, C_HEADER_BAR, C_BORDER_GLOW, 1);
   
   CreateTextComponent("T1", aX+16, aY+12, "THEE ELITE SCALPER", C_TEXT_LIGHT, 18, "Algerian");
   CreateTextComponent("T2", aX+16, aY+40, "AI POWERED BULK ENGINE", C_ACCENT_BLUE, 9, "Arial Black");
   CreateTextComponent("T3", aX+16, aY+58, "Executing Bulk Matrix with Auto-Cooldown Pipeline", C_TEXT_MUTED, 8, "Arial Italic");
   CreateTextComponent("Sym", aX+dW-110, aY+16, _Symbol, C_AMBER_GOLD, 14, "Impact");
   CreateInterfaceComponent("PulseBg", aX+2, aY+87, dW-4, 28, C_PANEL_BG, clrNONE, 0);
   CreateTextComponent("PulseLbl", aX+16, aY+94, "[ SUBSYSTEM FLOW RUN TIME MATRIX ] :", C_TEXT_MUTED, 8, "Consolas Black");
   CreateTextComponent("PulseVal", aX+215, aY+94, "0 0 0 0", C_ACCENT_BLUE, 9, "Consolas");

   int c1Y = aY + 120;
   CreateInterfaceComponent("C1", aX+2, c1Y, dW-4, 155, C_PANEL_BG, C_BORDER_GLOW, 1);
   CreateTextComponent("C1H", aX+16, c1Y+10, "LIVE FINANCIAL DYNAMICS", C_TEXT_LIGHT, 10, "Arial Black");
   CreateTextComponent("L_Bal", aX+22, c1Y+38, "Liquid Account Balance:", C_TEXT_MUTED, 9, "Arial");
   CreateTextComponent("V_Bal", aX+230, c1Y+38, "$ 0.00", C_TEXT_LIGHT, 10, "Arial Bold");
   CreateTextComponent("L_Eq", aX+22, c1Y+64, "Net Structural Equity:", C_TEXT_MUTED, 9, "Arial");
   CreateTextComponent("V_Eq", aX+230, c1Y+64, "$ 0.00", C_TEXT_LIGHT, 10, "Arial Bold");
   CreateTextComponent("L_Dp", aX+22, c1Y+90, "Session Daily Net Yield:", C_TEXT_MUTED, 9, "Arial");
   CreateTextComponent("V_Dp", aX+230, c1Y+90, "$ 0.00", C_NEON_GREEN, 10, "Arial Black");
   CreateTextComponent("L_Fp", aX+22, c1Y+116, "Running Floating P&L:", C_TEXT_MUTED, 9, "Arial");
   CreateTextComponent("V_Fp", aX+230, c1Y+116, "$ 0.00", C_NEON_GREEN, 10, "Arial Black");

   int c2Y = aY + 280;
   CreateInterfaceComponent("C2", aX+2, c2Y, dW-4, 185, C_PANEL_BG, C_BORDER_GLOW, 1);
   CreateTextComponent("C2H", aX+16, c2Y+10, "HIGH-FREQUENCY EXECUTION PIPELINE", C_TEXT_LIGHT, 10, "Artifakt Element Black");
   CreateTextComponent("L_St", aX+22, c2Y+38, "Engine running action:", C_TEXT_MUTED, 9, "Artifakt Element ");
   CreateTextComponent("V_St", aX+150, c2Y+38, "INITIALIZING THREADS", C_ACCENT_BLUE, 9, "Artifakt Element Black");
   CreateTextComponent("L_Tr", aX+22, c2Y+62, "Daily Cycle Counter:", C_TEXT_MUTED, 9, "Arial");
   CreateTextComponent("V_Tr", aX+230, c2Y+62, "0 / 100", C_TEXT_LIGHT, 9, "Arial Bold");
   CreateTextComponent("L_Wr", aX+22, c2Y+86, "Statistical Win Ratio:", C_TEXT_MUTED, 9, "Arial");
   CreateTextComponent("V_Wr", aX+230, c2Y+86, "0.0 %", C_TEXT_LIGHT, 9, "Arial Bold");
   CreateTextComponent("L_Tp", aX+22, c2Y+110, "Target Per Bulk Trade:", C_TEXT_MUTED, 9, "Arial");
   CreateTextComponent("V_Tp", aX+230, c2Y+110, "$ " + DoubleToString(InpPerTradeTargetUSD, 2), C_ACCENT_BLUE, 9, "Arial Bold");
   CreateTextComponent("L_Rp", aX+22, c2Y+134, "Velocity Pct Run Reopens:", C_TEXT_MUTED, 9, "Arial");
   CreateTextComponent("V_Rp", aX+230, c2Y+134, "0", C_NEON_GREEN, 9, "Arial Bold");
   CreateTextComponent("L_Dr", aX+22, c2Y+158, "Active Structural Matrix:", C_TEXT_MUTED, 9, "Arial");
   CreateTextComponent("V_Dr", aX+230, c2Y+158, "COMPUTING DIRECTION", C_TEXT_LIGHT, 9, "Arial Bold");

   int c3Y = aY + 470;
   CreateInterfaceComponent("C3", aX+2, c3Y, dW-4, 58, C_PANEL_BG, C_BORDER_GLOW, 1);
   CreateTextComponent("L_Sp", aX+16, c3Y+10, "Spread:", C_TEXT_MUTED, 8, "Arial");
   CreateTextComponent("V_Sp", aX+65, c3Y+10, "0 PTS", C_TEXT_LIGHT, 8, "Arial Bold");
   CreateTextComponent("L_Ms", aX+135, c3Y+10, "Market Status:", C_TEXT_MUTED, 8, "Arial");
   CreateTextComponent("V_Ms", aX+215, c3Y+10, "ACTIVE", C_NEON_GREEN, 8, "Arial Bold");
   CreateTextComponent("L_Sl", aX+290, c3Y+10, "SL / TP Rules:", C_TEXT_MUTED, 8, "Arial");
   CreateTextComponent("V_Sl", aX+365, c3Y+10, IntegerToString(InpStopLossPoints) + " / " + IntegerToString(InpTakeProfitPoints), C_TEXT_LIGHT, 8, "Arial Bold");
   CreateTextComponent("L_Mg", aX+16, c3Y+34, "Magic Allocation Protection Key ID Node :", C_TEXT_MUTED, 7, "Arial Black");
   CreateTextComponent("V_Mg", aX+225, c3Y+34, "NODE_" + IntegerToString((long)InpMagicNumber), C_TEXT_MUTED, 7, "Arial Black");
   CreateTextComponent("F1", aX+10, aY+535, "Fully Autonomous Algorithmic Engine Node Structure.", C_TEXT_MUTED, 7, "Arial");
   CreateTextComponent("F2", aX+270, aY+535, "PRO CORE ENGINE V5.00", C_TEXT_MUTED, 7, "Arial Black");

   ChartRedraw(0);
}

void RefreshDashboardVisuals()
{
   UpdateTextComponent("PulseVal", g_SystemHeartbeatStr, C_ACCENT_BLUE);
   UpdateTextComponent("V_Bal", "$ " + DoubleToString(AccountInfoDouble(ACCOUNT_BALANCE), 2));
   UpdateTextComponent("V_Eq",  "$ " + DoubleToString(AccountInfoDouble(ACCOUNT_EQUITY), 2));
   
   color cDp = (g_TotalDailyProfit >= 0.0) ? C_NEON_GREEN : C_CRIMSON_RED;
   UpdateTextComponent("V_Dp", (g_TotalDailyProfit >= 0.0 ? "+$ " : "-$ ") + DoubleToString(MathAbs(g_TotalDailyProfit), 2), cDp);
   double fpl = CalculateFloatingFinancials();
   color cFp = (fpl >= 0.0) ? C_NEON_GREEN : C_CRIMSON_RED;
   UpdateTextComponent("V_Fp", (fpl >= 0.0 ? "+$ " : "-$ ") + DoubleToString(MathAbs(fpl), 2), cFp);

   UpdateTextComponent("V_St", g_EngineStatusText, g_EngineStatusColor);
   UpdateTextComponent("V_Tr", IntegerToString(g_TotalDailyTrades) + " / " + IntegerToString(InpMaxDailyTrades));

   int tot = g_TotalDailyWins + g_TotalDailyLosses;
   double wr = (tot > 0) ? ((double)g_TotalDailyWins / (double)tot) * 100.0 : 0.0;
   UpdateTextComponent("V_Wr", DoubleToString(wr, 1) + " %");
   UpdateTextComponent("V_Rp", IntegerToString(g_TotalProfitReopens));

   ENUM_ORDER_TYPE dir = DetermineMarketArchitecture();
   UpdateTextComponent("V_Dr", (dir == ORDER_TYPE_BUY) ? "MATRIX BULLISH (BUY)" : "MATRIX BEARISH (SELL)", (dir == ORDER_TYPE_BUY) ? C_NEON_GREEN : C_CRIMSON_RED);
   UpdateTextComponent("V_Sp", IntegerToString((int)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD)) + " PTS");
   bool ml = VerifyMarketLiquidity();
   UpdateTextComponent("V_Ms", ml ? "TRADE RUNNING" : "OFFLINE BLOCKED", ml ? C_NEON_GREEN : C_CRIMSON_RED);

   ChartRedraw(0);
}

void PurgeDashboardObjects() { ObjectsDeleteAll(0, DASH_PREFIX); ChartRedraw(0); }

void CreateInterfaceComponent(string nm, int x, int y, int w, int h, color bg, color border, int bw)
{
   string qn = DASH_PREFIX + nm;
   ObjectCreate(0, qn, OBJ_RECTANGLE_LABEL, 0, 0, 0);
   ObjectSetInteger(0, qn, OBJPROP_CORNER, CORNER_LEFT_UPPER); ObjectSetInteger(0, qn, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, qn, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, qn, OBJPROP_XSIZE, w);
   ObjectSetInteger(0, qn, OBJPROP_YSIZE, h); ObjectSetInteger(0, qn, OBJPROP_BGCOLOR, bg);
   if(border != clrNONE) { ObjectSetInteger(0, qn, OBJPROP_BORDER_TYPE, BORDER_FLAT);
   ObjectSetInteger(0, qn, OBJPROP_COLOR, border); ObjectSetInteger(0, qn, OBJPROP_WIDTH, bw); }
   else ObjectSetInteger(0, qn, OBJPROP_BORDER_TYPE, BORDER_RAISED);
   ObjectSetInteger(0, qn, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, qn, OBJPROP_HIDDEN, true); ObjectSetInteger(0, qn, OBJPROP_ZORDER, 0);
}

void CreateTextComponent(string nm, int x, int y, string txt, color clr, int fsz, string font)
{
   string qn = DASH_PREFIX + nm;
   ObjectCreate(0, qn, OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, qn, OBJPROP_CORNER, CORNER_LEFT_UPPER); ObjectSetInteger(0, qn, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, qn, OBJPROP_YDISTANCE, y);
   ObjectSetString(0, qn, OBJPROP_TEXT, txt);
   ObjectSetInteger(0, qn, OBJPROP_COLOR, clr); ObjectSetInteger(0, qn, OBJPROP_FONTSIZE, fsz);
   ObjectSetString(0, qn, OBJPROP_FONT, font); ObjectSetInteger(0, qn, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, qn, OBJPROP_HIDDEN, true); ObjectSetInteger(0, qn, OBJPROP_ZORDER, 1);
}

void UpdateTextComponent(string nm, string txt, color clr = clrNONE)
{
   string qn = DASH_PREFIX + nm;
   if(ObjectFind(0, qn) >= 0) { ObjectSetString(0, qn, OBJPROP_TEXT, txt); if(clr != clrNONE) ObjectSetInteger(0, qn, OBJPROP_COLOR, clr); }
}
//+------------------------------------------------------------------+