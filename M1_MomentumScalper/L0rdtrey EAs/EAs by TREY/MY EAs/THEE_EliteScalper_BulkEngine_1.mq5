//+------------------------------------------------------------------+
//|                       THEE EliteScalper — BULK ENGINE v5.0      |
//|                                     Copyright 2026, elites      |
//+------------------------------------------------------------------+
//  BULK TRADE MODE:
//  - Fires 10 trades, one every 10 seconds (same direction)
//  - Each trade auto-closes individually when profit >= $0.50
//  - After ALL 10 trades are closed → 60-second cooldown
//  - Then opens a brand new bulk round
//  - new york time
//+------------------------------------------------------------------+
#property copyright   "Copyright 2026, NYT"
#property version     "5.00"
#property description "THEE EliteScalper — Institutional Bulk Execution Engine"
#property description "10-Trade Burst | Per-Trade $0.50 Auto-Close | 60s Cooldown"
#property strict

#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>

#define DASH_PREFIX "FXBH_BLK_"

//+------------------------------------------------------------------+
//| BULK ENGINE STATE MACHINE                                        |
//+------------------------------------------------------------------+
enum ENUM_BULK_STATE
{
   BULK_STATE_SCANNING,      // Waiting for signal
   BULK_STATE_ANALYZING,     // Pre-trade analysis phase
   BULK_STATE_FIRING,        // Actively firing trades (10 trades, 10s apart)
   BULK_STATE_MONITORING,    // All trades fired – watching each for $0.50 profit
   BULK_STATE_COOLDOWN       // All closed – cooling down 60s before next round
};

//+------------------------------------------------------------------+
//| INPUT PARAMETERS                                                 |
//+------------------------------------------------------------------+
input group "=== BULK ENGINE CORE SETTINGS ==="
input ulong   InpMagicNumber        = 999555;    // Bulk Engine Magic Number
input double  InpLotSize            = 0.01;      // Lot Size Per Trade
input int     InpMaxDailyRounds     = 10;        // Max Bulk Rounds Per Day
input int     InpBulkTradeCount     = 10;        // Trades Per Bulk Round
input int     InpFireIntervalSec    = 10;        // Seconds Between Each Trade Fire

input group "=== PER-TRADE AUTO-CLOSE PROFIT ==="
input double  InpProfitPerTrade     = 0.50;      // Auto-Close Profit Per Trade ($)

input group "=== ANTI-MANIPULATION COOLDOWN ==="
input int     InpCooldownSeconds    = 60;        // Cooldown After All Trades Closed (s)

input group "=== PRE-TRADE ANALYSIS ENGINE ==="
input int     InpAnalysisMaxSeconds = 180;       // Max Analysis Window (Seconds)
input int     InpAnalysisMinTicks   = 45;        // Min Tick Volume to Confirm
input int     InpAnalysisMinSeconds = 5;         // Minimum Observation Time (Seconds)

input group "=== ACCOUNT GUARDRAIL PROTECTION ==="
input int     InpStopLossPoints     = 300;       // Emergency Stop Loss (Points)
input int     InpTakeProfitPoints   = 600;       // Structural Take Profit (Points)
input int     InpMaxSpreadPoints    = 25;        // Maximum Allowed Spread

input group "=== DUAL-CORE STRUCTURAL CONFIRMATION ==="
input int     InpFastEMAPeriod      = 9;         // Fast EMA Period
input int     InpSlowEMAPeriod      = 21;        // Slow EMA Period
input int     InpMarketStructureBar = 5;         // Structure High/Low Lookback Bars

input group "=== INTERFACE LAYOUT ==="
input int     InpDashXOffset        = 15;        // Dashboard X Anchor
input int     InpDashYOffset        = 15;        // Dashboard Y Anchor

//+------------------------------------------------------------------+
//| FINTECH COLOR PALETTE                                            |
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
const color C_ORANGE_FIRE    = C'255,110,0';
const color C_TEXT_LIGHT     = C'235,242,255';
const color C_TEXT_MUTED     = C'130,145,170';

//+------------------------------------------------------------------+
//| GLOBAL ENGINE OBJECTS                                            |
//+------------------------------------------------------------------+
CTrade          g_Trade;
CPositionInfo   g_PosInfo;

int             g_FastEMAHandle     = INVALID_HANDLE;
int             g_SlowEMAHandle     = INVALID_HANDLE;

//--- State Machine
ENUM_BULK_STATE g_BulkState         = BULK_STATE_SCANNING;
datetime        g_StateTimer        = 0;

//--- Pre-Trade Analysis
ENUM_ORDER_TYPE g_PendingDirection  = ORDER_TYPE_BUY;
int             g_AnalysisTickCount = 0;
datetime        g_AnalysisStartTime = 0;

//--- Bulk Firing Tracker
int             g_TradesFired       = 0;        // How many trades fired this round
datetime        g_NextFireTime      = 0;        // When to fire the next trade
ENUM_ORDER_TYPE g_BulkDirection     = ORDER_TYPE_BUY; // Direction locked for the round

//--- Ticket registry for this round (track each of the 10 trades)
ulong           g_RoundTickets[10];
bool            g_TicketClosed[10];
int             g_TicketsRegistered = 0;

//--- Session Stats
int             g_TotalDailyRounds  = 0;
int             g_TotalDailyTrades  = 0;
double          g_TotalDailyProfit  = 0.0;
int             g_TotalDailyWins    = 0;
int             g_TotalDailyLosses  = 0;
datetime        g_CurrentSessionDay = 0;

//--- Dashboard strings
string          g_HeartbeatStr      = "0 0 0 0";
string          g_StatusText        = "BOOTING ENGINE";
color           g_StatusColor       = C_AMBER_GOLD;

//+------------------------------------------------------------------+
//| FORWARD DECLARATIONS                                             |
//+------------------------------------------------------------------+
void            ProcessAnalysisPhase();
void            FireNextBulkTrade();
void            MonitorOpenTrades();
bool            AllRoundTradesClosed();
int             CountOpenBulkPositions();
void            ExecuteSingleTrade(ENUM_ORDER_TYPE dir);
void            RegisterTicket(ulong ticket);
bool            VerifyMarketLiquidity();
ENUM_ORDER_TYPE DetermineMarketArchitecture();
double          CalculateFloatingPnL();
void            SynchronizeLedgerStats();
datetime        GetMidnightTimestamp(datetime t);

void            RenderDashboard();
void            RefreshDashboard();
void            PurgeDashboard();
void            MakeBox(string nm, int x, int y, int w, int h, color bg, color border, int bw);
void            MakeLabel(string nm, int x, int y, string txt, color clr, int fsz, string font);
void            SetLabel(string nm, string txt, color clr = clrNONE);

//+------------------------------------------------------------------+
//| OnInit                                                           |
//+------------------------------------------------------------------+
int OnInit()
{
   g_Trade.SetExpertMagicNumber(InpMagicNumber);
   g_Trade.SetDeviationInPoints(15);

   if(InpLotSize <= 0.0 || InpBulkTradeCount < 1 || InpBulkTradeCount > 10) return INIT_PARAMETERS_INCORRECT;

   g_FastEMAHandle = iMA(_Symbol, _Period, InpFastEMAPeriod, 0, MODE_EMA, PRICE_CLOSE);
   g_SlowEMAHandle = iMA(_Symbol, _Period, InpSlowEMAPeriod, 0, MODE_EMA, PRICE_CLOSE);
   if(g_FastEMAHandle == INVALID_HANDLE || g_SlowEMAHandle == INVALID_HANDLE) return INIT_FAILED;

   g_CurrentSessionDay = GetMidnightTimestamp(TimeCurrent());
   SynchronizeLedgerStats();

   ArrayInitialize(g_RoundTickets, 0);
   ArrayInitialize(g_TicketClosed, true); // all closed by default

   RenderDashboard();
   EventSetTimer(1);
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| OnDeinit                                                         |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   EventKillTimer();
   PurgeDashboard();
   if(g_FastEMAHandle != INVALID_HANDLE) IndicatorRelease(g_FastEMAHandle);
   if(g_SlowEMAHandle != INVALID_HANDLE) IndicatorRelease(g_SlowEMAHandle);
}

//+------------------------------------------------------------------+
//| OnTimer — heartbeat + dashboard refresh                          |
//+------------------------------------------------------------------+
void OnTimer()
{
   uint c = GetTickCount() % 4;
   if(c == 0) g_HeartbeatStr = "1 0 1 1   0 1 0 0";
   if(c == 1) g_HeartbeatStr = "0 1 0 0   1 0 1 1";
   if(c == 2) g_HeartbeatStr = "1 1 0 1   0 0 1 0";
   if(c == 3) g_HeartbeatStr = "0 0 1 0   1 1 0 1";

   SynchronizeLedgerStats();
   RefreshDashboard();
}

//+------------------------------------------------------------------+
//| OnTick — Main Engine                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   if(!VerifyMarketLiquidity())
   {
      g_StatusText = "MARKET SUSPENDED"; g_StatusColor = C_CRIMSON_RED; return;
   }

   //--------------------------------------------------------------------
   // STATE: COOLDOWN — wait 60s after round, then scan again
   //--------------------------------------------------------------------
   if(g_BulkState == BULK_STATE_COOLDOWN)
   {
      int left = (int)(g_StateTimer - TimeCurrent());
      if(left > 0)
      {
         g_StatusText  = "COOLDOWN: NEXT ROUND IN " + IntegerToString(left) + "s";
         g_StatusColor = C_AMBER_GOLD;
         return;
      }
      // Cooldown done
      g_BulkState   = BULK_STATE_SCANNING;
      g_StatusText  = "SCANNING MARKET";
      g_StatusColor = C_ACCENT_BLUE;
   }

   //--------------------------------------------------------------------
   // DAILY ROUND LIMIT
   //--------------------------------------------------------------------
   if(g_TotalDailyRounds >= InpMaxDailyRounds)
   {
      g_StatusText = "DAILY ROUND LIMIT REACHED"; g_StatusColor = C_AMBER_GOLD; return;
   }

   //--------------------------------------------------------------------
   // ACTIVE ROUND — unified FIRING + MONITORING block
   // Firing  : sends trades every 10s until InpBulkTradeCount reached
   // Monitoring: watches every open trade for $0.50 auto-close
   // Both phases run in the same block so firing never gets dropped
   //--------------------------------------------------------------------
   if(g_BulkState == BULK_STATE_FIRING || g_BulkState == BULK_STATE_MONITORING)
   {
      // Step 1: Always monitor open trades for per-trade profit target
      MonitorOpenTrades();

      // Step 2: Keep firing until all trades are sent
      if(g_TradesFired < InpBulkTradeCount)
      {
         if(TimeCurrent() >= g_NextFireTime)
            FireNextBulkTrade();

         int secLeft = (int)(g_NextFireTime - TimeCurrent());
         g_StatusText  = "FIRING " + IntegerToString(g_TradesFired) + "/" + IntegerToString(InpBulkTradeCount)
                       + " | NEXT IN " + IntegerToString(MathMax(0, secLeft)) + "s"
                       + " | OPEN: " + IntegerToString(CountOpenBulkPositions());
         g_StatusColor = C_ORANGE_FIRE;
         g_BulkState   = BULK_STATE_FIRING;
      }
      else
      {
         // All trades fired — pure monitoring phase
         g_BulkState   = BULK_STATE_MONITORING;
         int openCnt   = CountOpenBulkPositions();
         g_StatusText  = "WAITING FOR TARGETS ($" + DoubleToString(InpProfitPerTrade, 2) + "/ea)"
                       + " | OPEN: " + IntegerToString(openCnt);
         g_StatusColor = C_ACCENT_BLUE;
      }

      // Step 3: Round complete only when ALL fired AND all closed
      if(AllRoundTradesClosed())
      {
         g_TotalDailyRounds++;
         g_BulkState   = BULK_STATE_COOLDOWN;
         g_StateTimer  = TimeCurrent() + InpCooldownSeconds;
         g_StatusText  = "ROUND " + IntegerToString(g_TotalDailyRounds) + " COMPLETE — COOLING " + IntegerToString(InpCooldownSeconds) + "s";
         g_StatusColor = C_NEON_GREEN;
         Print("[BulkEngine] Round ", g_TotalDailyRounds, " complete. Cooling down ", InpCooldownSeconds, "s.");
      }
      return;
   }

   //--------------------------------------------------------------------
   // SPREAD CHECK
   //--------------------------------------------------------------------
   int spread = (int)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   if(spread > InpMaxSpreadPoints)
   {
      g_StatusText = "SPREAD SKEW (" + IntegerToString(spread) + " PTS)"; g_StatusColor = C_CRIMSON_RED; return;
   }

   //--------------------------------------------------------------------
   // STATE: SCANNING — detect signal → go to analysis
   //--------------------------------------------------------------------
   if(g_BulkState == BULK_STATE_SCANNING)
   {
      ENUM_ORDER_TYPE sig = DetermineMarketArchitecture();
      g_BulkState         = BULK_STATE_ANALYZING;
      g_PendingDirection  = sig;
      g_AnalysisStartTime = TimeCurrent();
      g_AnalysisTickCount = 0;
      g_StatusText        = "SIGNAL DETECTED — ANALYZING...";
      g_StatusColor       = C_PURPLE_SCAN;
      Print("[BulkEngine] Signal: ", EnumToString(sig), " — entering analysis phase.");
   }

   //--------------------------------------------------------------------
   // STATE: ANALYZING — confirm before firing bulk round
   //--------------------------------------------------------------------
   else if(g_BulkState == BULK_STATE_ANALYZING)
   {
      ProcessAnalysisPhase();
   }
}

//+------------------------------------------------------------------+
//| Pre-Trade Analysis Phase                                         |
//+------------------------------------------------------------------+
void ProcessAnalysisPhase()
{
   g_AnalysisTickCount++;
   int elapsed = (int)(TimeCurrent() - g_AnalysisStartTime);

   g_StatusText  = "ANALYZING: " + IntegerToString(elapsed) + "s | TICKS: " + IntegerToString(g_AnalysisTickCount);
   g_StatusColor = C_PURPLE_SCAN;

   if(elapsed > InpAnalysisMaxSeconds)
   {
      Print("[BulkEngine] Analysis timeout. Resetting.");
      g_BulkState = BULK_STATE_SCANNING; return;
   }

   ENUM_ORDER_TYPE curr = DetermineMarketArchitecture();
   if(curr != g_PendingDirection)
   {
      Print("[BulkEngine] Setup invalidated — market reversed during analysis.");
      g_BulkState = BULK_STATE_SCANNING; return;
   }

   if(elapsed >= InpAnalysisMinSeconds && g_AnalysisTickCount >= InpAnalysisMinTicks)
   {
      Print("[BulkEngine] Analysis confirmed. Launching bulk round.");

      // Lock the direction and reset round state
      g_BulkDirection     = g_PendingDirection;
      g_TradesFired       = 0;
      g_TicketsRegistered = 0;
      ArrayInitialize(g_RoundTickets, 0);
      // Mark ALL slots as closed initially — each slot flips to false only when a real ticket is registered.
      // This prevents AllRoundTradesClosed() from returning true before all trades have been fired.
      ArrayInitialize(g_TicketClosed, true);

      // Fire first trade immediately, schedule next
      g_BulkState    = BULK_STATE_FIRING;
      g_NextFireTime = TimeCurrent(); // fire now
      FireNextBulkTrade();
   }
}

//+------------------------------------------------------------------+
//| Fire One Trade in the Bulk Round                                 |
//+------------------------------------------------------------------+
void FireNextBulkTrade()
{
   if(g_TradesFired >= InpBulkTradeCount) return;

   int spread = (int)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   if(spread > InpMaxSpreadPoints)
   {
      Print("[BulkEngine] Skipping fire #", g_TradesFired+1, " — spread too high: ", spread);
      g_NextFireTime = TimeCurrent() + InpFireIntervalSec;
      return;
   }

   ExecuteSingleTrade(g_BulkDirection);
   g_TradesFired++;
   g_NextFireTime = TimeCurrent() + InpFireIntervalSec;

   Print("[BulkEngine] Fired trade ", g_TradesFired, "/", InpBulkTradeCount, " | Direction: ", EnumToString(g_BulkDirection));
}

//+------------------------------------------------------------------+
//| Execute One Market Trade & Register Its Ticket                   |
//+------------------------------------------------------------------+
void ExecuteSingleTrade(ENUM_ORDER_TYPE dir)
{
   double price = (dir == ORDER_TYPE_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   int    digs  = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);

   double minV = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxV = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   double lot  = MathMax(minV, MathMin(maxV, MathRound(InpLotSize / step) * step));

   double sl = 0.0, tp = 0.0;
   if(InpStopLossPoints > 0)
      sl = (dir == ORDER_TYPE_BUY) ? price - (InpStopLossPoints * point) : price + (InpStopLossPoints * point);
   if(InpTakeProfitPoints > 0)
      tp = (dir == ORDER_TYPE_BUY) ? price + (InpTakeProfitPoints * point) : price - (InpTakeProfitPoints * point);

   sl = NormalizeDouble(sl, digs);
   tp = NormalizeDouble(tp, digs);

   bool ok = (dir == ORDER_TYPE_BUY)
             ? g_Trade.Buy(lot, _Symbol, price, sl, tp, "BulkEngine|Round")
             : g_Trade.Sell(lot, _Symbol, price, sl, tp, "BulkEngine|Round");

   if(ok)
   {
      ulong ticket = g_Trade.ResultOrder();
      RegisterTicket(ticket);
      g_TotalDailyTrades++;
      Print("[BulkEngine] Trade OK — Ticket: ", ticket, " Lot: ", lot, " Dir: ", EnumToString(dir));
   }
   else
   {
      Print("[BulkEngine] Trade FAILED — Code: ", g_Trade.ResultRetcode(), " Desc: ", g_Trade.ResultRetcodeDescription());
   }
}

//+------------------------------------------------------------------+
//| Register ticket into the round array                             |
//+------------------------------------------------------------------+
void RegisterTicket(ulong ticket)
{
   if(g_TicketsRegistered < 10)
   {
      g_RoundTickets[g_TicketsRegistered] = ticket;
      g_TicketClosed[g_TicketsRegistered] = false;  // slot is now OPEN — a real trade exists
      g_TicketsRegistered++;
   }
}

//+------------------------------------------------------------------+
//| Monitor all open trades — close each when profit >= $0.50        |
//+------------------------------------------------------------------+
void MonitorOpenTrades()
{
   for(int i = 0; i < g_TicketsRegistered; i++)
   {
      if(g_TicketClosed[i]) continue;  // already closed

      ulong tkt = g_RoundTickets[i];
      if(tkt == 0) { g_TicketClosed[i] = true; continue; }

      // Check if position still exists
      if(!PositionSelectByTicket(tkt))
      {
         // Position gone (closed by SL/TP or manually) — mark as closed
         g_TicketClosed[i] = true;
         continue;
      }

      // Position is open — check profit
      double profit = PositionGetDouble(POSITION_PROFIT)
                    + PositionGetDouble(POSITION_SWAP);
      // Note: commission is not accessible directly via PositionGetDouble for open trade

      if(profit >= InpProfitPerTrade)
      {
         Print("[BulkEngine] Trade ", tkt, " profit $", DoubleToString(profit, 2), " >= target $", DoubleToString(InpProfitPerTrade, 2), " — closing.");
         if(g_Trade.PositionClose(tkt))
         {
            g_TicketClosed[i] = true;
            Print("[BulkEngine] Trade ", tkt, " closed successfully.");
         }
         else
         {
            Print("[BulkEngine] Close failed for ticket ", tkt, " — will retry next tick.");
         }
      }
   }

   // Update status text
   int openCount = CountOpenBulkPositions();
   if(g_BulkState == BULK_STATE_MONITORING)
   {
      g_StatusText  = "MONITORING " + IntegerToString(openCount) + " OPEN | CLOSED " + IntegerToString(g_TradesFired - openCount) + "/" + IntegerToString(g_TradesFired);
      g_StatusColor = C_ACCENT_BLUE;
   }
}

//+------------------------------------------------------------------+
//| Are all registered tickets in this round closed?                 |
//+------------------------------------------------------------------+
bool AllRoundTradesClosed()
{
   // Round is NOT complete until all trades have been fired
   if(g_TradesFired < InpBulkTradeCount) return false;
   // Then check no open positions remain for this EA
   if(CountOpenBulkPositions() > 0) return false;
   return true;
}

//+------------------------------------------------------------------+
//| Count open positions for this EA on this symbol                  |
//+------------------------------------------------------------------+
int CountOpenBulkPositions()
{
   int cnt = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
      if(g_PosInfo.SelectByIndex(i) && g_PosInfo.Magic() == InpMagicNumber && g_PosInfo.Symbol() == _Symbol)
         cnt++;
   return cnt;
}

//+------------------------------------------------------------------+
//| Dual-Core Market Structure Evaluator                             |
//+------------------------------------------------------------------+
ENUM_ORDER_TYPE DetermineMarketArchitecture()
{
   double fast[1], slow[1];
   if(CopyBuffer(g_FastEMAHandle, 0, 0, 1, fast) <= 0 || CopyBuffer(g_SlowEMAHandle, 0, 0, 1, slow) <= 0)
      return ORDER_TYPE_BUY;

   bool bullTrend  = (fast[0] > slow[0]);
   int  highBar    = iHighest(_Symbol, _Period, MODE_HIGH, InpMarketStructureBar, 1);
   int  lowBar     = iLowest(_Symbol, _Period, MODE_LOW, InpMarketStructureBar, 1);
   double mid      = (iHigh(_Symbol, _Period, highBar) + iLow(_Symbol, _Period, lowBar)) / 2.0;
   bool bullStruct = (SymbolInfoDouble(_Symbol, SYMBOL_BID) > mid);

   if(bullTrend && bullStruct)   return ORDER_TYPE_BUY;
   if(!bullTrend && !bullStruct) return ORDER_TYPE_SELL;
   return (SymbolInfoDouble(_Symbol, SYMBOL_BID) > fast[0]) ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
}

//+------------------------------------------------------------------+
//| Market open check                                                |
//+------------------------------------------------------------------+
bool VerifyMarketLiquidity()
{
   ENUM_SYMBOL_TRADE_MODE mode = (ENUM_SYMBOL_TRADE_MODE)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_MODE);
   return (mode == SYMBOL_TRADE_MODE_FULL || mode == SYMBOL_TRADE_MODE_LONGONLY || mode == SYMBOL_TRADE_MODE_SHORTONLY);
}

//+------------------------------------------------------------------+
//| Floating PnL for all open positions                              |
//+------------------------------------------------------------------+
double CalculateFloatingPnL()
{
   double total = 0.0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
      if(g_PosInfo.SelectByIndex(i) && g_PosInfo.Magic() == InpMagicNumber && g_PosInfo.Symbol() == _Symbol)
         total += g_PosInfo.Profit() + g_PosInfo.Swap() + g_PosInfo.Commission();
   return total;
}

//+------------------------------------------------------------------+
//| Daily ledger synchronization                                     |
//+------------------------------------------------------------------+
void SynchronizeLedgerStats()
{
   datetime now = TimeCurrent();
   datetime mid = GetMidnightTimestamp(now);
   if(mid > g_CurrentSessionDay)
   {
      g_TotalDailyRounds = 0; g_TotalDailyTrades = 0;
      g_TotalDailyProfit = 0.0; g_TotalDailyWins = 0; g_TotalDailyLosses = 0;
      g_CurrentSessionDay = mid;
   }

   g_TotalDailyProfit = 0.0; g_TotalDailyWins = 0; g_TotalDailyLosses = 0;
   if(HistorySelect(g_CurrentSessionDay, now))
   {
      for(int i = 0; i < HistoryDealsTotal(); i++)
      {
         ulong tkt = HistoryDealGetTicket(i);
         if(tkt > 0 && HistoryDealGetInteger(tkt, DEAL_MAGIC) == InpMagicNumber && HistoryDealGetString(tkt, DEAL_SYMBOL) == _Symbol)
         {
            if(HistoryDealGetInteger(tkt, DEAL_ENTRY) == DEAL_ENTRY_OUT)
            {
               double pnl = HistoryDealGetDouble(tkt, DEAL_PROFIT)
                          + HistoryDealGetDouble(tkt, DEAL_COMMISSION)
                          + HistoryDealGetDouble(tkt, DEAL_SWAP);
               g_TotalDailyProfit += pnl;
               if(pnl >= 0.0) g_TotalDailyWins++; else g_TotalDailyLosses++;
            }
         }
      }
   }
}

datetime GetMidnightTimestamp(datetime t)
{
   MqlDateTime d; TimeToStruct(t, d);
   return t - (datetime)(d.hour * 3600 + d.min * 60 + d.sec);
}

//====================================================================
//  DASHBOARD ENGINE — BULK EDITION
//====================================================================
void RenderDashboard()
{
   int aX = InpDashXOffset, aY = InpDashYOffset;
   int dW = 460, dH = 620;

   // --- Background & Header
   MakeBox("Bg",  aX,   aY,   dW,   dH,   C_MATRIX_BG,  C_BORDER_GLOW, 2);
   MakeBox("Hdr", aX+2, aY+2, dW-4, 82,   C_HEADER_BAR, C_BORDER_GLOW, 1);

   MakeLabel("T1",  aX+16, aY+12, "THEE ELITE SCALPER",             C_TEXT_LIGHT,  18, "Algerian");
   MakeLabel("T2",  aX+16, aY+40, "BULK EXECUTION ENGINE v5.0",     C_ACCENT_BLUE,  9, "Arial Black");
   MakeLabel("T3",  aX+16, aY+58, "10-Trade Burst | $0.50 Per-Trade Auto-Close | 60s Cooldown", C_TEXT_MUTED, 8, "Arial Italic");
   MakeLabel("Sym", aX+dW-120, aY+16, _Symbol,                      C_AMBER_GOLD,  14, "Impact");

   // --- Heartbeat row
   MakeBox("PBg", aX+2, aY+87, dW-4, 28, C_PANEL_BG, clrNONE, 0);
   MakeLabel("PLbl", aX+16,  aY+94, "[ BULK ENGINE RUNTIME MATRIX ] :",  C_TEXT_MUTED, 8, "Consolas Black");
   MakeLabel("PVal", aX+220, aY+94, "0 0 0 0",                           C_ACCENT_BLUE, 9, "Consolas");

   // --- PANEL 1: Live Financial Dynamics
   int p1Y = aY + 120;
   MakeBox("P1", aX+2, p1Y, dW-4, 155, C_PANEL_BG, C_BORDER_GLOW, 1);
   MakeLabel("P1H",  aX+16,  p1Y+10, "LIVE FINANCIAL DYNAMICS",       C_TEXT_LIGHT, 10, "Arial Black");
   MakeLabel("L_Bal",aX+22,  p1Y+38, "Account Balance:",               C_TEXT_MUTED,  9, "Arial");
   MakeLabel("V_Bal",aX+240, p1Y+38, "$ 0.00",                         C_TEXT_LIGHT, 10, "Arial Bold");
   MakeLabel("L_Eq", aX+22,  p1Y+62, "Net Equity:",                    C_TEXT_MUTED,  9, "Arial");
   MakeLabel("V_Eq", aX+240, p1Y+62, "$ 0.00",                         C_TEXT_LIGHT, 10, "Arial Bold");
   MakeLabel("L_Dp", aX+22,  p1Y+86, "Daily Net Yield:",               C_TEXT_MUTED,  9, "Arial");
   MakeLabel("V_Dp", aX+240, p1Y+86, "$ 0.00",                         C_NEON_GREEN,  10, "Arial Black");
   MakeLabel("L_Fp", aX+22,  p1Y+110,"Floating P&L (All Open):",       C_TEXT_MUTED,  9, "Arial");
   MakeLabel("V_Fp", aX+240, p1Y+110,"$ 0.00",                         C_NEON_GREEN,  10, "Arial Black");

   // --- PANEL 2: Bulk Execution Status
   int p2Y = aY + 282;
   MakeBox("P2", aX+2, p2Y, dW-4, 235, C_PANEL_BG, C_BORDER_GLOW, 1);
   MakeLabel("P2H",  aX+16,  p2Y+10,  "BULK EXECUTION PIPELINE",      C_TEXT_LIGHT, 10, "Arial Black");
   MakeLabel("L_St", aX+22,  p2Y+38,  "Engine Status:",                C_TEXT_MUTED,  9, "Arial");
   MakeLabel("V_St", aX+155, p2Y+38,  "INITIALIZING",                  C_ACCENT_BLUE, 9, "Arial Black");
   MakeLabel("L_Rnd",aX+22,  p2Y+62,  "Bulk Rounds Today:",            C_TEXT_MUTED,  9, "Arial");
   MakeLabel("V_Rnd",aX+240, p2Y+62,  "0 / 10",                        C_TEXT_LIGHT,  9, "Arial Bold");
   MakeLabel("L_Frd",aX+22,  p2Y+86,  "Trades Fired This Round:",      C_TEXT_MUTED,  9, "Arial");
   MakeLabel("V_Frd",aX+240, p2Y+86,  "0 / 10",                        C_ORANGE_FIRE, 9, "Arial Bold");
   MakeLabel("L_Opn",aX+22,  p2Y+110, "Currently Open Trades:",        C_TEXT_MUTED,  9, "Arial");
   MakeLabel("V_Opn",aX+240, p2Y+110, "0",                             C_TEXT_LIGHT,  9, "Arial Bold");
   MakeLabel("L_Tgt",aX+22,  p2Y+134, "Per-Trade Close Target:",       C_TEXT_MUTED,  9, "Arial");
   MakeLabel("V_Tgt",aX+240, p2Y+134, "$ " + DoubleToString(InpProfitPerTrade, 2), C_NEON_GREEN, 9, "Arial Bold");
   MakeLabel("L_Dir",aX+22,  p2Y+158, "Locked Round Direction:",       C_TEXT_MUTED,  9, "Arial");
   MakeLabel("V_Dir",aX+240, p2Y+158, "COMPUTING...",                  C_TEXT_LIGHT,  9, "Arial Bold");
   MakeLabel("L_Wr", aX+22,  p2Y+182, "Win Ratio:",                    C_TEXT_MUTED,  9, "Arial");
   MakeLabel("V_Wr", aX+240, p2Y+182, "0.0 %",                         C_TEXT_LIGHT,  9, "Arial Bold");
   MakeLabel("L_Tr", aX+22,  p2Y+206, "Total Trades Today:",           C_TEXT_MUTED,  9, "Arial");
   MakeLabel("V_Tr", aX+240, p2Y+206, "0",                             C_TEXT_LIGHT,  9, "Arial Bold");

   // --- PANEL 3: Market vitals footer
   int p3Y = aY + 525;
   MakeBox("P3", aX+2, p3Y, dW-4, 60, C_PANEL_BG, C_BORDER_GLOW, 1);
   MakeLabel("L_Sp", aX+16,  p3Y+10, "Spread:",         C_TEXT_MUTED, 8, "Arial");
   MakeLabel("V_Sp", aX+68,  p3Y+10, "0 PTS",           C_TEXT_LIGHT, 8, "Arial Bold");
   MakeLabel("L_Ms", aX+130, p3Y+10, "Market:",         C_TEXT_MUTED, 8, "Arial");
   MakeLabel("V_Ms", aX+190, p3Y+10, "ACTIVE",          C_NEON_GREEN, 8, "Arial Bold");
   MakeLabel("L_Sl", aX+265, p3Y+10, "SL / TP:",        C_TEXT_MUTED, 8, "Arial");
   MakeLabel("V_Sl", aX+315, p3Y+10, IntegerToString(InpStopLossPoints)+"/"+IntegerToString(InpTakeProfitPoints), C_TEXT_LIGHT, 8, "Arial Bold");
   MakeLabel("L_Mg", aX+16,  p3Y+34, "Magic Key Node:", C_TEXT_MUTED, 7, "Arial Black");
   MakeLabel("V_Mg", aX+115, p3Y+34, "NODE_"+IntegerToString((long)InpMagicNumber), C_TEXT_MUTED, 7, "Arial Black");

   // Footer
   MakeLabel("Ft1", aX+10,   aY+592, "Fully Autonomous Bulk Algorithmic Scalping Engine.",  C_TEXT_MUTED, 7, "Arial");
   MakeLabel("Ft2", aX+285,  aY+592, "BULK ENGINE v5.00",                                   C_TEXT_MUTED, 7, "Arial Black");

   ChartRedraw(0);
}

void RefreshDashboard()
{
   SetLabel("PVal", g_HeartbeatStr, C_ACCENT_BLUE);

   SetLabel("V_Bal", "$ " + DoubleToString(AccountInfoDouble(ACCOUNT_BALANCE), 2));
   SetLabel("V_Eq",  "$ " + DoubleToString(AccountInfoDouble(ACCOUNT_EQUITY), 2));

   color cDp = (g_TotalDailyProfit >= 0.0) ? C_NEON_GREEN : C_CRIMSON_RED;
   SetLabel("V_Dp", (g_TotalDailyProfit >= 0.0 ? "+$ " : "-$ ") + DoubleToString(MathAbs(g_TotalDailyProfit), 2), cDp);

   double fpl = CalculateFloatingPnL();
   color cFp = (fpl >= 0.0) ? C_NEON_GREEN : C_CRIMSON_RED;
   SetLabel("V_Fp", (fpl >= 0.0 ? "+$ " : "-$ ") + DoubleToString(MathAbs(fpl), 2), cFp);

   SetLabel("V_St",  g_StatusText, g_StatusColor);
   SetLabel("V_Rnd", IntegerToString(g_TotalDailyRounds) + " / " + IntegerToString(InpMaxDailyRounds));
   SetLabel("V_Frd", IntegerToString(g_TradesFired) + " / " + IntegerToString(InpBulkTradeCount),
            (g_TradesFired >= InpBulkTradeCount) ? C_NEON_GREEN : C_ORANGE_FIRE);
   SetLabel("V_Opn", IntegerToString(CountOpenBulkPositions()));

   // Direction
   string dirStr = "SCANNING...";
   color  dirCol = C_TEXT_MUTED;
   if(g_BulkState == BULK_STATE_FIRING || g_BulkState == BULK_STATE_MONITORING)
   {
      dirStr = (g_BulkDirection == ORDER_TYPE_BUY) ? "LOCKED BUY  (BULLISH)" : "LOCKED SELL (BEARISH)";
      dirCol = (g_BulkDirection == ORDER_TYPE_BUY) ? C_NEON_GREEN : C_CRIMSON_RED;
   }
   SetLabel("V_Dir", dirStr, dirCol);

   int tot = g_TotalDailyWins + g_TotalDailyLosses;
   double wr = (tot > 0) ? ((double)g_TotalDailyWins / (double)tot) * 100.0 : 0.0;
   SetLabel("V_Wr", DoubleToString(wr, 1) + " %");
   SetLabel("V_Tr", IntegerToString(g_TotalDailyTrades));

   SetLabel("V_Sp", IntegerToString((int)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD)) + " PTS");
   bool ml = VerifyMarketLiquidity();
   SetLabel("V_Ms", ml ? "ACTIVE" : "SUSPENDED", ml ? C_NEON_GREEN : C_CRIMSON_RED);

   ChartRedraw(0);
}

void PurgeDashboard() { ObjectsDeleteAll(0, DASH_PREFIX); ChartRedraw(0); }

void MakeBox(string nm, int x, int y, int w, int h, color bg, color border, int bw)
{
   string n = DASH_PREFIX + nm;
   ObjectCreate(0, n, OBJ_RECTANGLE_LABEL, 0, 0, 0);
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

void MakeLabel(string nm, int x, int y, string txt, color clr, int fsz, string font)
{
   string n = DASH_PREFIX + nm;
   ObjectCreate(0, n, OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, n, OBJPROP_CORNER,    CORNER_LEFT_UPPER);
   ObjectSetInteger(0, n, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, n, OBJPROP_YDISTANCE, y);
   ObjectSetString(0,  n, OBJPROP_TEXT,      txt);
   ObjectSetInteger(0, n, OBJPROP_COLOR,     clr);
   ObjectSetInteger(0, n, OBJPROP_FONTSIZE,  fsz);
   ObjectSetString(0,  n, OBJPROP_FONT,      font);
   ObjectSetInteger(0, n, OBJPROP_SELECTABLE,false);
   ObjectSetInteger(0, n, OBJPROP_HIDDEN,    true);
   ObjectSetInteger(0, n, OBJPROP_ZORDER,    1);
}

void SetLabel(string nm, string txt, color clr = clrNONE)
{
   string n = DASH_PREFIX + nm;
   if(ObjectFind(0, n) >= 0)
   {
      ObjectSetString(0, n, OBJPROP_TEXT, txt);
      if(clr != clrNONE) ObjectSetInteger(0, n, OBJPROP_COLOR, clr);
   }
}
//+------------------------------------------------------------------+
