//+------------------------------------------------------------------+
//|                                           APEX BTC SCALPER V3    |
//|              Institutional Edition for Micro-Capital Trading     |
//|              v3.0 | 24/5 Autonomous HF Scalping System           |
//+------------------------------------------------------------------+
#property copyright   "APEX Quant Systems v3.0"
#property version     "3.00"
#property description "Optimized for BTCUSD Micro-Accounts. State Alignment Engine, strict 1-min delays, and deep fintech UI."

#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>
#include <Trade\AccountInfo.mqh>

//--- Dashboard namespace prefix
#define D "APX_"

//=======================================================================
//  COLOUR PALETTE – Deep-space luxury fintech
//=======================================================================
#define C_BG0       C'4,6,18'        // deepest background
#define C_BG1       C'8,12,28'       // panel background
#define C_BG2       C'12,18,42'      // card background
#define C_HDRBAR    C'10,16,38'      // header
#define C_BORDER    C'22,44,90'      // subtle border
#define C_ACBORD    C'0,160,220'     // accent border (cyan)
#define C_GOLD      C'255,200,40'    // gold accent
#define C_CYAN      C'0,220,220'     // cyan
#define C_LBLUE     C'80,160,255'    // light blue
#define C_WHITE     C'220,225,240'   // primary text
#define C_SUBTEXT   C'110,130,160'   // subdued label
#define C_GREEN     C'20,220,110'    // profit / bullish
#define C_RED       C'230,55,65'     // loss / bearish
#define C_ORANGE    C'255,145,0'     // warning / monitoring
#define C_DKGREEN   C'14,80,45'      // green fill
#define C_MGRAY     C'75,90,115'     // mid grey
#define C_DGRAY     C'40,52,72'      // dark grey

//=======================================================================
//  INPUT PARAMETERS
//=======================================================================
input group "╔══════  IDENTITY  ══════╗"
input ulong  InpMagicNumber     = 888222;              // Magic Number[cite: 1]
input string InpBotName         = "APEX BTC SCALPER AI"; // Bot Name[cite: 1]

input group "╔══════  SCALPING ENGINE  ══════╗"
input double InpLotSize         = 0.01;        // Lot Size[cite: 1]
input int    InpMaxSpreadPoints = 500;         // Max Spread (Points) to trade[cite: 1]
input double InpTargetUSD       = 1.00;        // Target Profit per trade ($)[cite: 1]
input double InpStopLossUSD     = 1.00;        // Hard Stop Loss ($)[cite: 1]

input group "╔══════  INDICATORS (M1/M5)  ══════╗"
input int    InpFastEMA         = 3;           // Fast Momentum EMA (M1)[cite: 1]
input int    InpSlowEMA         = 8;           // Trend Baseline EMA (M1)[cite: 1]
input int    InpM5TrendEMA      = 50;          // 5-Min Master Analysis Filter (M5)[cite: 1]

input group "╔══════  TRADE FREQUENCY  ══════╗"
input int    InpMaxDailyTrades  = 20;          // Max Trades Per Day (0=unlimited)[cite: 1]
input int    InpCooldownSec     = 60;          // Cooldown Seconds After Close[cite: 1]

input group "╔══════  DASHBOARD  ══════╗"
input bool   InpShowDash        = true;        // Show Dashboard[cite: 1]
input int    InpDashX           = 14;          // Dashboard X Position[cite: 1]
input int    InpDashY           = 14;          // Dashboard Y Position[cite: 1]

//=======================================================================
//  CONSTANTS & GLOBALS
//=======================================================================
const int     DW = 420;    // Dashboard width[cite: 1]
const int     DH = 620;    // Dashboard height[cite: 1]

CTrade        g_trade;
CPositionInfo g_pos;
CAccountInfo  g_account;

int           g_emaFastH   = INVALID_HANDLE;[cite: 1]
int           g_emaSlowH   = INVALID_HANDLE;[cite: 1]
int           g_m5TrendH   = INVALID_HANDLE;[cite: 1]

datetime      g_lastCloseTime  = 0;   [cite: 1]
datetime      g_sessionDay     = 0;   [cite: 1]

// Session stats
int           g_sessTradesTotal  = 0;[cite: 1]
int           g_sessTradesToday  = 0;[cite: 1]
double        g_sessProfit       = 0.0;[cite: 1]
int           g_sessWins         = 0;[cite: 1]
int           g_sessLosses       = 0;[cite: 1]
double        g_peakEquity       = 0.0;[cite: 1]
double        g_drawdown         = 0.0;[cite: 1]

// Dynamic states
string        g_statusText   = "STARTING";[cite: 1]
color         g_statusColor  = C_ORANGE;[cite: 1]
string        g_lastAction   = "Initializing engine...";[cite: 1]
string        g_m5Status     = "ANALYZING...";[cite: 1]
bool          g_inCooldown   = false;[cite: 1]
int           g_cooldownLeft = 0;[cite: 1]

//=======================================================================
//  FORWARD DECLARATIONS
//=======================================================================
void     RestoreSession();[cite: 1]
void     BuildSessionStats();[cite: 1]
bool     HasPosition();[cite: 1]
void     CloseAllPositions();[cite: 1]
double   GetFloatPL();[cite: 1]
bool     SpreadOK();[cite: 1]
datetime DayStart(datetime ts);[cite: 1]
void     InitDash();[cite: 1]
void     UpdateDash();[cite: 1]
void     DeleteDash();[cite: 1]
void     R(string nm, int x, int y, int w, int h, color bg, color brd=clrNONE, int bw=1);[cite: 1]
void     L(string nm, int x, int y, string txt, color clr, int fsz, string fnt="Arial Bold");[cite: 1]
void     U(string nm, string txt, color clr);[cite: 1]
void     Bar(string nm, int x, int y, int w, int h, double pct, color fg, color bg);[cite: 1]
void     UpdBar(string nm, double pct, color fg);[cite: 1]

//=======================================================================
//  OnInit
//=======================================================================
int OnInit()
{
   if(InpLotSize <= 0) { Alert("Lot size must be > 0"); return INIT_PARAMETERS_INCORRECT; }[cite: 1]

   g_trade.SetExpertMagicNumber(InpMagicNumber);[cite: 1]
   g_trade.SetDeviationInPoints(100); // Slippage tolerance for crypto[cite: 1]
   g_trade.SetTypeFilling(ORDER_FILLING_FOK);[cite: 1]

   // Indicators initialization
   g_emaFastH = iMA(Symbol(), PERIOD_CURRENT, InpFastEMA, 0, MODE_EMA, PRICE_CLOSE);[cite: 1]
   g_emaSlowH = iMA(Symbol(), PERIOD_CURRENT, InpSlowEMA, 0, MODE_EMA, PRICE_CLOSE);[cite: 1]
   g_m5TrendH = iMA(Symbol(), PERIOD_M5, InpM5TrendEMA, 0, MODE_EMA, PRICE_CLOSE);[cite: 1]

   if(g_emaFastH == INVALID_HANDLE || g_emaSlowH == INVALID_HANDLE || g_m5TrendH == INVALID_HANDLE)[cite: 1]
   { 
      Print("Indicator generation failed. Error code:", GetLastError()); 
      return INIT_FAILED; 
   }

   g_peakEquity  = AccountInfoDouble(ACCOUNT_EQUITY);[cite: 1]
   g_sessionDay  = DayStart(TimeCurrent());[cite: 1]

   RestoreSession();[cite: 1]
   BuildSessionStats();[cite: 1]

   if(InpShowDash) InitDash();[cite: 1]
   EventSetTimer(1);[cite: 1]

   g_lastAction  = "Scanning conditions...";[cite: 1]
   g_statusText  = "SCANNING";[cite: 1]
   g_statusColor = C_ORANGE;[cite: 1]

   return INIT_SUCCEEDED;[cite: 1]
}

//=======================================================================
//  OnDeinit
//=======================================================================
void OnDeinit(const int reason)
{
   EventKillTimer();[cite: 1]
   DeleteDash();[cite: 1]
   if(g_emaFastH != INVALID_HANDLE) IndicatorRelease(g_emaFastH);[cite: 1]
   if(g_emaSlowH != INVALID_HANDLE) IndicatorRelease(g_emaSlowH);[cite: 1]
   if(g_m5TrendH != INVALID_HANDLE) IndicatorRelease(g_m5TrendH);[cite: 1]
}

//=======================================================================
//  OnTimer
//=======================================================================
void OnTimer()
{
   if(g_lastCloseTime > 0)[cite: 1]
   {
      int elapsed = (int)(TimeCurrent() - g_lastCloseTime);[cite: 1]
      g_inCooldown   = (elapsed < InpCooldownSec);[cite: 1]
      g_cooldownLeft = g_inCooldown ? (InpCooldownSec - elapsed) : 0;[cite: 1]
   }
   else
   {
      g_inCooldown   = false;[cite: 1]
      g_cooldownLeft = 0;[cite: 1]
   }

   double eq = AccountInfoDouble(ACCOUNT_EQUITY);[cite: 1]
   if(eq > g_peakEquity) g_peakEquity = eq;[cite: 1]
   if(g_peakEquity > 0)[cite: 1]
      g_drawdown = (g_peakEquity - eq) / g_peakEquity * 100.0;[cite: 1]

   BuildSessionStats();[cite: 1]
   if(InpShowDash) UpdateDash();[cite: 1]
}

//=======================================================================
//  OnTick – Core Execution Engine (State Alignment Mechanism)
//=======================================================================
void OnTick()
{
   datetime todayStart = DayStart(TimeCurrent());[cite: 1]
   if(todayStart != g_sessionDay)[cite: 1]
   {
      g_sessionDay = todayStart;[cite: 1]
      BuildSessionStats();[cite: 1]
      g_lastAction = "New day session rolled over";[cite: 1]
   }

   // 1. Position Management & Micro-Target Guard[cite: 1]
   if(HasPosition())[cite: 1]
   {
      double floatPL = GetFloatPL();[cite: 1]
      if(floatPL >= InpTargetUSD || floatPL <= -InpStopLossUSD)[cite: 1]
      {
         g_lastAction = StringFormat((floatPL > 0) ? "Target $%.2f achieved" : "StopLoss $%.2f hit", floatPL);[cite: 1]
         CloseAllPositions();[cite: 1]
         g_lastCloseTime = TimeCurrent();[cite: 1]
         g_inCooldown    = true;[cite: 1]
         g_cooldownLeft  = InpCooldownSec;[cite: 1]
         g_statusText    = "COOLDOWN";[cite: 1]
         g_statusColor   = C_CYAN;[cite: 1]
         BuildSessionStats();[cite: 1]
         return;
      }
      g_statusText  = "IN TRADE";[cite: 1]
      g_statusColor = C_GREEN;[cite: 1]
      return;
   }

   // 2. Cooldown and Limits Verification
   if(g_inCooldown || !SpreadOK() || (InpMaxDailyTrades > 0 && g_sessTradesToday >= InpMaxDailyTrades))[cite: 1]
   {
      return; 
   }

   // 3. Multi-Timeframe M5 Trend Filter[cite: 1]
   double m5TrendArray[];[cite: 1]
   if(CopyBuffer(g_m5TrendH, 0, 1, 1, m5TrendArray) <= 0) return;[cite: 1]
   double currentPrice = SymbolInfoDouble(Symbol(), SYMBOL_BID);[cite: 1]
   
   bool isM5Bullish = currentPrice > m5TrendArray[0];[cite: 1]
   bool isM5Bearish = currentPrice < m5TrendArray[0];[cite: 1]
   g_m5Status = isM5Bullish ? "M5 BULLISH" : (isM5Bearish ? "M5 BEARISH" : "FLAT STRUCT");[cite: 1]

   // 4. M1 Momentum Data Stream
   double emaF[], emaS[];[cite: 1]
   if(CopyBuffer(g_emaFastH, 0, 1, 2, emaF) <= 0) return;[cite: 1]
   if(CopyBuffer(g_emaSlowH, 0, 1, 2, emaS) <= 0) return;[cite: 1]

   ArraySetAsSeries(emaF, true);[cite: 1]
   ArraySetAsSeries(emaS, true);[cite: 1]

   // State Alignment Logic: Prevents missing continuous runs while avoiding fakeouts[cite: 1]
   bool m1BullishStack = (emaF[0] > emaS[0]);[cite: 1]
   bool m1BearishStack = (emaF[0] < emaS[0]);[cite: 1]

   bool buyTrigger  = m1BullishStack && isM5Bullish;[cite: 1]
   bool sellTrigger = m1BearishStack && isM5Bearish;[cite: 1]

   g_statusText  = "SCANNING";[cite: 1]
   g_statusColor = C_ORANGE;[cite: 1]

   if(buyTrigger)[cite: 1]
   {
      g_statusText  = "OPENING";[cite: 1]
      g_statusColor = C_LBLUE;[cite: 1]
      double ask = SymbolInfoDouble(Symbol(), SYMBOL_ASK);[cite: 1]
      if(g_trade.Buy(InpLotSize, Symbol(), ask, 0, 0, InpBotName))[cite: 1]
      {
         g_sessTradesToday++;[cite: 1]
         g_lastAction = StringFormat("Long entry filled @ %.2f", ask);[cite: 1]
      }
   }
   else if(sellTrigger)[cite: 1]
   {
      g_statusText  = "OPENING";[cite: 1]
      g_statusColor = C_LBLUE;[cite: 1]
      double bid = SymbolInfoDouble(Symbol(), SYMBOL_BID);[cite: 1]
      if(g_trade.Sell(InpLotSize, Symbol(), bid, 0, 0, InpBotName))[cite: 1]
      {
         g_sessTradesToday++;[cite: 1]
         g_lastAction = StringFormat("Short entry filled @ %.2f", bid);[cite: 1]
      }
   }
}

//=======================================================================
//  POSITION UTILITIES
//=======================================================================
bool HasPosition()
{
   for(int i = PositionsTotal()-1; i >= 0; i--)[cite: 1]
   {
      if(!g_pos.SelectByIndex(i)) continue;[cite: 1]
      if(g_pos.Magic() == InpMagicNumber && g_pos.Symbol() == Symbol()) return true;[cite: 1]
   }
   return false;[cite: 1]
}

double GetFloatPL()
{
   double total = 0;[cite: 1]
   for(int i = PositionsTotal()-1; i >= 0; i--)[cite: 1]
   {
      if(!g_pos.SelectByIndex(i)) continue;[cite: 1]
      if(g_pos.Magic() == InpMagicNumber && g_pos.Symbol() == Symbol())[cite: 1]
         total += g_pos.Profit() + g_pos.Swap() + g_pos.Commission();[cite: 1]
   }
   return total;[cite: 1]
}

void CloseAllPositions()
{
   for(int i = PositionsTotal()-1; i >= 0; i--)[cite: 1]
   {
      if(!g_pos.SelectByIndex(i)) continue;[cite: 1]
      if(g_pos.Magic() != InpMagicNumber || g_pos.Symbol() != Symbol()) continue;[cite: 1]
      g_trade.PositionClose(g_pos.Ticket());[cite: 1]
   }
}

bool SpreadOK()
{
   if(InpMaxSpreadPoints <= 0) return true;[cite: 1]
   return ((int)SymbolInfoInteger(Symbol(), SYMBOL_SPREAD) <= InpMaxSpreadPoints);[cite: 1]
}

void RestoreSession()
{
   datetime ds = DayStart(TimeCurrent());[cite: 1]
   if(!HistorySelect(ds, TimeCurrent())) return;[cite: 1]
   int total = HistoryDealsTotal();[cite: 1]
   for(int i = 0; i < total; i++)[cite: 1]
   {
      ulong tk = HistoryDealGetTicket(i);[cite: 1]
      if(tk == 0 || (ulong)HistoryDealGetInteger(tk, DEAL_MAGIC) != InpMagicNumber) continue;[cite: 1]
      if(HistoryDealGetString(tk, DEAL_SYMBOL) != Symbol()) continue;[cite: 1]
      if(HistoryDealGetInteger(tk, DEAL_ENTRY) == DEAL_ENTRY_IN)[cite: 1]
      {
         g_sessTradesToday++;[cite: 1]
         g_lastCloseTime = (datetime)HistoryDealGetInteger(tk, DEAL_TIME);[cite: 1]
      }
   }
}

void BuildSessionStats()
{
   g_sessProfit = 0.0; g_sessWins = 0; g_sessLosses = 0; g_sessTradesTotal = 0;[cite: 1]
   datetime ds = DayStart(TimeCurrent());[cite: 1]
   if(!HistorySelect(ds, TimeCurrent())) return;[cite: 1]
   int total = HistoryDealsTotal();[cite: 1]
   for(int i = 0; i < total; i++)[cite: 1]
   {
      ulong tk = HistoryDealGetTicket(i);[cite: 1]
      if(tk == 0 || (ulong)HistoryDealGetInteger(tk, DEAL_MAGIC) != InpMagicNumber) continue;[cite: 1]
      if(HistoryDealGetString(tk, DEAL_SYMBOL) != Symbol()) continue;[cite: 1]
      long entry = HistoryDealGetInteger(tk, DEAL_ENTRY);[cite: 1]
      if(entry == DEAL_ENTRY_IN) { g_sessTradesTotal++; }[cite: 1]
      else if(entry == DEAL_ENTRY_OUT)[cite: 1]
      {
         double pnl = HistoryDealGetDouble(tk, DEAL_PROFIT) + HistoryDealGetDouble(tk, DEAL_SWAP) + HistoryDealGetDouble(tk, DEAL_COMMISSION);[cite: 1]
         g_sessProfit += pnl;[cite: 1]
         if(pnl >= 0) g_sessWins++; else g_sessLosses++;[cite: 1]
      }
   }
}

datetime DayStart(datetime ts)
{
   MqlDateTime d; TimeToStruct(ts, d);[cite: 1]
   return ts - (datetime)(d.hour*3600 + d.min*60 + d.sec);[cite: 1]
}

//=======================================================================
//  DASHBOARD GRAPHICS ENGINE
//=======================================================================
void R(string nm, int x, int y, int w, int h, color bg, color brd=clrNONE, int bw=1)
{
   string n = D + nm;[cite: 1]
   if(ObjectFind(0, n) >= 0) ObjectDelete(0, n);[cite: 1]
   ObjectCreate(0, n, OBJ_RECTANGLE_LABEL, 0, 0, 0);[cite: 1]
   ObjectSetInteger(0, n, OBJPROP_CORNER,    CORNER_LEFT_UPPER);[cite: 1]
   ObjectSetInteger(0, n, OBJPROP_XDISTANCE, x);[cite: 1]
   ObjectSetInteger(0, n, OBJPROP_YDISTANCE, y);[cite: 1]
   ObjectSetInteger(0, n, OBJPROP_XSIZE,     w);[cite: 1]
   ObjectSetInteger(0, n, OBJPROP_YSIZE,     h);[cite: 1]
   ObjectSetInteger(0, n, OBJPROP_BGCOLOR,   bg);[cite: 1]
   if(brd != clrNONE)[cite: 1]
   {
      ObjectSetInteger(0, n, OBJPROP_BORDER_TYPE, BORDER_FLAT);[cite: 1]
      ObjectSetInteger(0, n, OBJPROP_COLOR,       brd);[cite: 1]
      ObjectSetInteger(0, n, OBJPROP_WIDTH,        bw);[cite: 1]
   }
   else ObjectSetInteger(0, n, OBJPROP_BORDER_TYPE, BORDER_RAISED);[cite: 1]
   ObjectSetInteger(0, n, OBJPROP_SELECTABLE, false);[cite: 1]
   ObjectSetInteger(0, n, OBJPROP_HIDDEN,     true);[cite: 1]
}

void L(string nm, int x, int y, string txt, color clr, int fsz, string fnt="Arial Bold")
{
   string n = D + nm;[cite: 1]
   if(ObjectFind(0, n) >= 0) ObjectDelete(0, n);[cite: 1]
   ObjectCreate(0, n, OBJ_LABEL, 0, 0, 0);[cite: 1]
   ObjectSetInteger(0, n, OBJPROP_CORNER,    CORNER_LEFT_UPPER);[cite: 1]
   ObjectSetInteger(0, n, OBJPROP_XDISTANCE, x);[cite: 1]
   ObjectSetInteger(0, n, OBJPROP_YDISTANCE, y);[cite: 1]
   ObjectSetString (0, n, OBJPROP_TEXT,      txt);[cite: 1]
   ObjectSetInteger(0, n, OBJPROP_COLOR,     clr);[cite: 1]
   ObjectSetInteger(0, n, OBJPROP_FONTSIZE,  fsz);[cite: 1]
   ObjectSetString (0, n, OBJPROP_FONT,      fnt);[cite: 1]
   ObjectSetInteger(0, n, OBJPROP_SELECTABLE,false);[cite: 1]
   ObjectSetInteger(0, n, OBJPROP_HIDDEN,    true);[cite: 1]
}

void U(string nm, string txt, color clr=C_WHITE)
{
   string n = D + nm;[cite: 1]
   if(ObjectFind(0, n) >= 0)[cite: 1]
   {
      ObjectSetString (0, n, OBJPROP_TEXT,  txt);[cite: 1]
      ObjectSetInteger(0, n, OBJPROP_COLOR, clr);[cite: 1]
   }
}

void Bar(string nm, int x, int y, int w, int h, double pct, color fg, color bg_c)
{
   R(nm + "_bg", x, y, w, h, bg_c, C_BORDER, 1);[cite: 1]
   int fw = (int)MathMax(2, MathRound(pct / 100.0 * (w - 2)));[cite: 1]
   R(nm + "_fg", x+1, y+1, fw, h-2, fg, clrNONE);[cite: 1]
}

void UpdBar(string nm, double pct, color fg)
{
   string n = D + nm + "_fg";[cite: 1]
   string nb = D + nm + "_bg";[cite: 1]
   int w = 0;[cite: 1]
   if(ObjectFind(0, nb) >= 0) w = (int)ObjectGetInteger(0, nb, OBJPROP_XSIZE);[cite: 1]
   if(w <= 0) return;[cite: 1]
   int fw = (int)MathMax(2, MathRound(MathMin(pct, 100.0) / 100.0 * (w - 2)));[cite: 1]
   if(ObjectFind(0, n) >= 0)[cite: 1]
   {
      ObjectSetInteger(0, n, OBJPROP_XSIZE,   fw);[cite: 1]
      ObjectSetInteger(0, n, OBJPROP_BGCOLOR, fg);[cite: 1]
   }
}

void InitDash()
{
   int X = InpDashX, Y = InpDashY;[cite: 1]

   R("frame_outer", X,   Y,   DW,   DH,   C_BG0,   C_ACBORD,  2);[cite: 1]
   R("frame_inner", X+2, Y+2, DW-4, DH-4, C_BG0,   C_BORDER,  1);[cite: 1]

   R("hdr_bg",  X+2,  Y+2,  DW-4, 80,  C_HDRBAR, C_BORDER, 1);[cite: 1]
   R("hdr_acc", X+2,  Y+2,  DW-4,  3,  C_ACBORD);[cite: 1]

   L("h_name",  X+10, Y+10, InpBotName,                  C_GOLD,  12, "Arial Black");[cite: 1]
   L("h_tag",   X+10, Y+30, "Crypto Micro-Capital Layer  |  24/5 Autonomous", C_CYAN, 7, "Arial");[cite: 1]
   L("h_ver",   X+10, Y+44, "v3.0  +  Magic: " + IntegerToString((long)InpMagicNumber) + "  +  " + Symbol(), C_LBLUE, 7, "Arial");[cite: 1]

   R("live_bg", X+DW-80, Y+8, 64, 22, C_DKGREEN, C_GREEN, 1);[cite: 1]
   L("live_lbl",X+DW-72, Y+12, "● LIVE",               C_GREEN,  7, "Arial Bold");[cite: 1]
   R("div_hdr", X+2, Y+82, DW-4, 2, C_ACBORD);[cite: 1]

   R("stat_bg",  X+2,  Y+86, DW-4, 30,  C_BG2, C_BORDER, 1);[cite: 1]
   L("lb_stat",  X+14, Y+93, "STATUS",                   C_SUBTEXT, 8, "Arial");[cite: 1]
   L("vl_stat",  X+100,Y+93, "STARTING",                 C_ORANGE,  9, "Arial Black");[cite: 1]
   L("lb_act",   X+220,Y+93, "Last Action:",             C_SUBTEXT, 7, "Arial");[cite: 1]
   L("vl_act",   X+300,Y+93, "--",                       C_WHITE,   7, "Arial");[cite: 1]
   R("div_stat", X+2, Y+118, DW-4, 1, C_BORDER);[cite: 1]

   R("sec_a",   X+2,  Y+122, DW-4, 168, C_BG1, C_BORDER, 1);[cite: 1]
   R("sec_a_hd",X+2,  Y+122, DW-4,  22, C_HDRBAR, C_BORDER, 1);[cite: 1]
   L("sec_a_lb",X+10, Y+126, "▸  PERFORMANCE STATS",     C_GOLD, 8, "Arial Black");[cite: 1]
   R("div_a",   X+2,  Y+144, DW-4, 1,   C_BORDER);[cite: 1]

   L("lb_sp",  X+14, Y+149, "Session Profit",         C_SUBTEXT, 8, "Arial");[cite: 1]
   L("vl_sp",  X+200,Y+149, "$ 0.00",                 C_WHITE,   9, "Arial Bold");[cite: 1]
   L("vl_sp2", X+320,Y+149, "Today",                  C_SUBTEXT, 7, "Arial");[cite: 1]

   L("lb_fp",  X+14, Y+165, "Floating P&L",           C_SUBTEXT, 8, "Arial");[cite: 1]
   L("vl_fp",  X+200,Y+165, "$ 0.00",                 C_WHITE,   9, "Arial Bold");[cite: 1]

   L("lb_wl",  X+14, Y+181, "Win / Loss",             C_SUBTEXT, 8, "Arial");[cite: 1]
   L("vl_wl",  X+200,Y+181, "0W / 0L",                C_WHITE,   9, "Arial Bold");[cite: 1]

   L("lb_wr",  X+14, Y+197, "Win Rate",               C_SUBTEXT, 8, "Arial");[cite: 1]
   L("vl_wr",  X+200,Y+197, "0 %",                    C_WHITE,   9, "Arial Bold");[cite: 1]
   Bar("wr_bar", X+280, Y+199, 130, 12, 0, C_GREEN, C_DGRAY);[cite: 1]

   L("lb_dd",  X+14, Y+213, "Account Drawdown",       C_SUBTEXT, 8, "Arial");[cite: 1]
   L("vl_dd",  X+200,Y+213, "0.00 %",                 C_WHITE,   9, "Arial Bold");[cite: 1]
   Bar("dd_bar", X+280, Y+215, 130, 12, 0, C_RED, C_DGRAY);[cite: 1]

   L("lb_tt",  X+14, Y+229, "Trades Completed Today", C_SUBTEXT, 8, "Arial");[cite: 1]
   L("vl_tt",  X+200,Y+229, "0 / " + IntegerToString(InpMaxDailyTrades), C_WHITE, 9, "Arial Bold");[cite: 1]
   Bar("tt_bar", X+280, Y+231, 130, 12, 0, C_LBLUE, C_DGRAY);[cite: 1]
   R("div_a2", X+2, Y+292, DW-4, 1, C_BORDER);[cite: 1]

   R("sec_b",   X+2,  Y+296, DW-4, 106, C_BG1, C_BORDER, 1);[cite: 1]
   R("sec_b_hd",X+2,  Y+296, DW-4,  22, C_HDRBAR, C_BORDER, 1);[cite: 1]
   L("sec_b_lb",X+10, Y+300, "▸  MICRO ACCOUNT DATA",    C_GOLD, 8, "Arial Black");[cite: 1]
   R("div_b",   X+2,  Y+318, DW-4, 1,   C_BORDER);[cite: 1]

   L("lb_bal",  X+14, Y+323, "Balance",                C_SUBTEXT, 8, "Arial");[cite: 1]
   L("vl_bal",  X+200,Y+323, "$ 0.00",                 C_WHITE,   9, "Arial Bold");[cite: 1]

   L("lb_eq",   X+14, Y+339, "Equity",                 C_SUBTEXT, 8, "Arial");[cite: 1]
   L("vl_eq",   X+200,Y+339, "$ 0.00",                 C_WHITE,   9, "Arial Bold");[cite: 1]

   L("lb_mg",   X+14, Y+355, "Free Margin Available",  C_SUBTEXT, 8, "Arial");[cite: 1]
   L("vl_mg",   X+200,Y+355, "$ 0.00",                 C_WHITE,   9, "Arial Bold");[cite: 1]

   L("lb_ml",   X+14, Y+371, "Margin Level Ratio",     C_SUBTEXT, 8, "Arial");[cite: 1]
   L("vl_ml",   X+200,Y+371, "0.0 %",                  C_WHITE,   9, "Arial Bold");[cite: 1]
   Bar("ml_bar", X+280, Y+373, 130, 12, 0, C_CYAN, C_DGRAY);[cite: 1]
   R("div_b2",  X+2, Y+404, DW-4, 1, C_BORDER);[cite: 1]

   R("sec_c",   X+2,  Y+408, DW-4, 130, C_BG1, C_BORDER, 1);[cite: 1]
   R("sec_c_hd",X+2,  Y+408, DW-4,  22, C_HDRBAR, C_BORDER, 1);[cite: 1]
   L("sec_c_lb",X+10, Y+412, "▸  REALTIME ANALYSIS TARGET",C_GOLD, 8, "Arial Black");[cite: 1]
   R("div_c",   X+2,  Y+430, DW-4, 1,   C_BORDER);[cite: 1]

   L("lb_sym",  X+14, Y+435, "Active Symbol",          C_SUBTEXT, 8, "Arial");[cite: 1]
   L("vl_sym",  X+200,Y+435, Symbol(),                 C_CYAN,    9, "Arial Bold");[cite: 1]

   L("lb_dir",  X+14, Y+451, "M5 Structural Trend",    C_SUBTEXT, 8, "Arial");[cite: 1]
   L("vl_dir",  X+200,Y+451, "--",                     C_WHITE,   9, "Arial Bold");[cite: 1]

   L("lb_spr",  X+14, Y+467, "Current Spread",         C_SUBTEXT, 8, "Arial");[cite: 1]
   L("vl_spr",  X+200,Y+467, "0 pts",                  C_WHITE,   9, "Arial Bold");[cite: 1]

   L("lb_pos",  X+14, Y+483, "Active Market Direction",C_SUBTEXT, 8, "Arial");[cite: 1]
   L("vl_pos",  X+200,Y+483, "NONE",                   C_MGRAY,   9, "Arial Bold");[cite: 1]

   L("lb_fl",   X+14, Y+499, "Net Flow Position P&L",  C_SUBTEXT, 8, "Arial");[cite: 1]
   L("vl_fl",   X+200,Y+499, "$ 0.00",                 C_WHITE,   9, "Arial Bold");[cite: 1]

   L("lb_cd",   X+14, Y+515, "Frequency Cooldown",     C_SUBTEXT, 8, "Arial");[cite: 1]
   L("vl_cd",   X+200,Y+515, "Ready",                  C_GREEN,   9, "Arial Bold");[cite: 1]
   R("div_c2",  X+2, Y+540, DW-4, 1, C_BORDER);[cite: 1]

   R("sec_d",   X+2,  Y+544, DW-4, 56,  C_BG2, C_BORDER, 1);[cite: 1]
   L("cfg1",    X+14, Y+549, "Lot Size: " + DoubleToString(InpLotSize,2) + "  | Target profit: $" + DoubleToString(InpTargetUSD,2) + "  | Stoploss: $" + DoubleToString(InpStopLossUSD,2), C_LBLUE, 7, "Arial");[cite: 1]
   L("cfg2",    X+14, Y+563, "Frequency lock: " + IntegerToString(InpCooldownSec) + "s  | Max Session Daily trades: " + IntegerToString(InpMaxDailyTrades) + "  | Max Spread: " + IntegerToString(InpMaxSpreadPoints) + " pts", C_LBLUE, 7, "Arial");[cite: 1]
   R("div_d",   X+2, Y+600, DW-4, 1, C_BORDER);[cite: 1]

   R("ftr",     X+2,  Y+603, DW-4, 15, C_HDRBAR, C_BORDER, 1);[cite: 1]
   L("ft_time", X+10, Y+605, "Server time: --:--",     C_MGRAY, 7, "Arial");[cite: 1]
   L("ft_url",  X+DW-160, Y+605, "apexquant.space | APX v3.0", C_DGRAY, 7, "Arial");[cite: 1]

   ChartRedraw(0);[cite: 1]
}

void UpdateDash()
{
   if(!InpShowDash) return;[cite: 1]

   bool   hasPOS  = HasPosition();[cite: 1]
   double floatPL = GetFloatPL();[cite: 1]
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);[cite: 1]
   double equity  = AccountInfoDouble(ACCOUNT_EQUITY);[cite: 1]
   double freeMargin = AccountInfoDouble(ACCOUNT_MARGIN_FREE);[cite: 1]
   double marginLevel = (AccountInfoDouble(ACCOUNT_MARGIN) > 0) ? AccountInfoDouble(ACCOUNT_MARGIN_LEVEL) : 0.0;[cite: 1]
   int    spread  = (int)SymbolInfoInteger(Symbol(), SYMBOL_SPREAD);[cite: 1]

   U("vl_stat", g_statusText, g_statusColor);[cite: 1]
   U("vl_act",  g_lastAction, C_SUBTEXT);[cite: 1]

   color spClr = (g_sessProfit >= 0) ? C_GREEN : C_RED;[cite: 1]
   U("vl_sp", "$ " + DoubleToString(g_sessProfit, 2), spClr);[cite: 1]

   color fpClr = (floatPL >= 0) ? C_GREEN : C_RED;[cite: 1]
   U("vl_fp", "$ " + DoubleToString(floatPL, 2), fpClr);[cite: 1]
   U("vl_fl", "$ " + DoubleToString(floatPL, 2), fpClr);[cite: 1]

   int closed = g_sessWins + g_sessLosses;[cite: 1]
   U("vl_wl", IntegerToString(g_sessWins) + "W / " + IntegerToString(g_sessLosses) + "L", (g_sessWins >= g_sessLosses) ? C_GREEN : C_RED);[cite: 1]

   double wr = (closed > 0) ? ((double)g_sessWins / closed * 100.0) : 0.0;[cite: 1]
   color  wrClr = (wr >= 55) ? C_GREEN : (wr >= 45 ? C_ORANGE : C_RED);[cite: 1]
   U("vl_wr", DoubleToString(wr, 1) + " %", wrClr);[cite: 1]
   UpdBar("wr_bar", wr, wrClr);[cite: 1]

   U("vl_dd", DoubleToString(g_drawdown, 2) + " %", (g_drawdown < 5) ? C_GREEN : (g_drawdown < 15 ? C_ORANGE : C_RED));[cite: 1]
   UpdBar("dd_bar", MathMin(g_drawdown * 5.0, 100.0), (g_drawdown < 5) ? C_GREEN : (g_drawdown < 15 ? C_ORANGE : C_RED));[cite: 1]

   double tradePct = (InpMaxDailyTrades > 0) ? ((double)g_sessTradesToday / InpMaxDailyTrades * 100.0) : 0.0;[cite: 1]
   U("vl_tt", IntegerToString(g_sessTradesToday) + " / " + IntegerToString(InpMaxDailyTrades), (tradePct < 80) ? C_WHITE : C_ORANGE);[cite: 1]
   UpdBar("tt_bar", MathMin(tradePct, 100.0), (tradePct < 80) ? C_LBLUE : C_ORANGE);[cite: 1]

   U("vl_bal", "$ " + DoubleToString(balance, 2),     C_WHITE);[cite: 1]
   U("vl_eq",  "$ " + DoubleToString(equity,  2),     (equity >= balance) ? C_GREEN : C_RED);[cite: 1]
   U("vl_mg",  "$ " + DoubleToString(freeMargin, 2),  C_WHITE);[cite: 1]
   
   double mlPct = MathMin(marginLevel / 10.0, 100.0);[cite: 1]
   U("vl_ml",  DoubleToString(marginLevel, 1) + " %", (marginLevel > 500 || marginLevel == 0) ? C_GREEN : (marginLevel > 200 ? C_ORANGE : C_RED));[cite: 1]
   UpdBar("ml_bar", mlPct, (marginLevel > 500 || marginLevel == 0) ? C_GREEN : (marginLevel > 200 ? C_ORANGE : C_RED));[cite: 1]

   U("vl_dir", g_m5Status, (g_m5Status == "M5 BULLISH") ? C_GREEN : ((g_m5Status == "M5 BEARISH") ? C_RED : C_ORANGE));[cite: 1]
   U("vl_spr", IntegerToString(spread) + " pts", (spread <= InpMaxSpreadPoints) ? C_GREEN : C_RED);[cite: 1]

   if(hasPOS)[cite: 1]
   {
      for(int i=PositionsTotal()-1; i>=0; i--)[cite: 1]
      {
         if(g_pos.SelectByIndex(i) && g_pos.Magic()==InpMagicNumber && g_pos.Symbol()==Symbol())[cite: 1]
         {
            U("vl_pos", (g_pos.PositionType() == POSITION_TYPE_BUY ? "LONG BUY ▲" : "SHORT SELL ▼"), (g_pos.PositionType() == POSITION_TYPE_BUY ? C_GREEN : C_RED));[cite: 1]
            break;
         }
      }
   }
   else U("vl_pos", "NONE AVAILABLE", C_MGRAY);[cite: 1]

   if(g_inCooldown)[cite: 1]
      U("vl_cd", "Throttled: Wait " + IntegerToString(g_cooldownLeft) + "s", C_ORANGE);[cite: 1]
   else
      U("vl_cd", "Engine Ready", C_GREEN);[cite: 1]

   U("ft_time", "Server workspace: " + TimeToString(TimeCurrent(), TIME_SECONDS) + "  |  Local profile: " + TimeToString(TimeLocal(), TIME_MINUTES), C_DGRAY);[cite: 1]

   ChartRedraw(0);[cite: 1]
}

void DeleteDash()
{
   ObjectsDeleteAll(0, D);[cite: 1]
   ChartRedraw(0);[cite: 1]
}