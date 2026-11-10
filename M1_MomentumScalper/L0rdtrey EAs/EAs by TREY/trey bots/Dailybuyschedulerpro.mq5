//+------------------------------------------------------------------+
//|                               DailyBuySchedulerPro.mq5          |
//|                                                                  |
//|  Scheduled daily BUY/SELL | Profit reopen | Live dashboard       |
//|  24/7 autonomous | Isolated by magic number | State-restoring    |
//+------------------------------------------------------------------+
#property copyright   "Daily Buy Scheduler Pro v2.0"
#property link        ""
#property version     "2.00"
#property description "Scheduled trading with profit reopen, SL/TP, and live dashboard."

#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>

//--- Dashboard object name prefix (keeps objects isolated from other EAs)
#define DASH_PRE  "DBS_"

//--- Color palette (dark luxury fintech theme)
#define C_BG      C'6,10,22'
#define C_PANEL   C'12,18,36'
#define C_HDRBAR  C'16,26,54'
#define C_BORDER  C'28,55,110'
#define C_ACBORDER C'0,140,200'
#define C_GOLD    C'255,198,32'
#define C_CYAN    C'0,210,210'
#define C_WHITE   C'215,220,232'
#define C_GREEN   C'20,210,100'
#define C_RED     C'215,55,55'
#define C_ORANGE  C'255,138,0'
#define C_LBLUE   C'90,155,255'
#define C_DGRAY   C'55,65,85'
#define C_MGRAY   C'100,115,140'

//+------------------------------------------------------------------+
//|  INPUT PARAMETERS                                                |
//+------------------------------------------------------------------+
input group "=== General ==="
input ulong  InpMagicNumber      = 77777;      // Magic Number
input double InpLotSize          = 0.01;       // Lot Size
input string InpBotLabel         = "DAILY BUY SCHEDULER PRO"; // Dashboard Title

input group "=== Schedule ==="
input int    InpOpenHour         = 1;          // Open Hour  (0-23)
input int    InpOpenMinute       = 5;          // Open Minute (0-59)
input int    InpCloseHour        = 22;         // Close Hour  (0-23)
input int    InpCloseMinute      = 55;         // Close Minute (0-59)
input bool   InpUseTimeClose     = true;       // Close at Close Time

input group "=== Risk Management ==="
input double InpStopLossPct      = 1.0;        // Stop Loss %   (0 = disabled)
input double InpTakeProfitPct    = 2.0;        // Take Profit % (0 = disabled)

input group "=== Auto Profit Reopen ==="
input bool   InpReopenOnProfit   = true;       // Reopen When Profit Target Hit
input double InpReopenPct        = 0.5;        // Price Move % to Trigger Reopen
input bool   InpAllowSell        = true;       // Allow SELL Direction on Reopen
input int    InpEMAPeriod        = 21;         // EMA Period for Direction Detection

input group "=== Dashboard ==="
input bool   InpShowDash         = true;       // Show Dashboard
input int    InpDashX            = 18;         // Dashboard X Position
input int    InpDashY            = 22;         // Dashboard Y Position

//+------------------------------------------------------------------+
//|  CONSTANTS                                                       |
//+------------------------------------------------------------------+
const int DW = 385;   // dashboard width
const int DH = 478;   // dashboard height

//+------------------------------------------------------------------+
//|  GLOBALS                                                         |
//+------------------------------------------------------------------+
CTrade        g_trade;
CPositionInfo g_pos;

datetime      g_lastOpenDay    = 0;
int           g_emaHandle      = INVALID_HANDLE;

// Session statistics (rebuilt from history on restart)
int           g_sessionTrades  = 0;
double        g_sessionProfit  = 0.0;
int           g_sessionWins    = 0;
int           g_sessionLosses  = 0;
int           g_totalReopens   = 0;

//+------------------------------------------------------------------+
//|  FORWARD DECLARATIONS                                            |
//+------------------------------------------------------------------+
void     RestoreState();
void     BuildSessionStats();
void     CheckProfitReopen();
void     OpenTrade(ENUM_ORDER_TYPE otype);
void     CloseAllPositions();
bool     HasOpenPosition();
double   GetFloatingProfit();
ENUM_ORDER_TYPE GetMarketDirection();
ENUM_ORDER_TYPE GetPositionType();
double   GetPositionOpenPrice();
bool     IsMarketOpen();
void     AdjustStops(double price, ENUM_ORDER_TYPE otype, double &sl, double &tp);
double   NormalizePrice(double price);
ENUM_ORDER_TYPE_FILLING GetFillMode();
datetime DayMidnight(datetime ts);
string   Pad2(int v);
void     InitDashboard();
void     UpdateDashboard();
void     DeleteDashboard();
void     MakeRect(string nm, int x, int y, int w, int h, color bg, color brd, int bw);
void     MakeLbl(string nm, int x, int y, string txt, color clr, int fsz, string font);
void     UpdLbl(string nm, string txt, color clr);

//+------------------------------------------------------------------+
//|  OnInit                                                          |
//+------------------------------------------------------------------+
int OnInit()
{
   if(InpOpenHour   < 0  || InpOpenHour   > 23) { Alert("Invalid Open Hour");    return INIT_PARAMETERS_INCORRECT; }
   if(InpOpenMinute < 0  || InpOpenMinute > 59)  { Alert("Invalid Open Minute");  return INIT_PARAMETERS_INCORRECT; }
   if(InpCloseHour  < 0  || InpCloseHour  > 23)  { Alert("Invalid Close Hour");   return INIT_PARAMETERS_INCORRECT; }
   if(InpCloseMinute< 0  || InpCloseMinute> 59)   { Alert("Invalid Close Minute"); return INIT_PARAMETERS_INCORRECT; }
   if(InpLotSize    <= 0.0)                        { Alert("Lot size must be > 0"); return INIT_PARAMETERS_INCORRECT; }

   g_trade.SetExpertMagicNumber(InpMagicNumber);
   g_trade.SetDeviationInPoints(20);
   g_trade.SetTypeFilling(GetFillMode());
   g_trade.LogLevel(LOG_LEVEL_ALL);

   g_emaHandle = iMA(Symbol(), PERIOD_CURRENT, InpEMAPeriod, 0, MODE_EMA, PRICE_CLOSE);
   if(g_emaHandle == INVALID_HANDLE)
   { Print("EMA handle creation failed. Error: ", GetLastError()); return INIT_FAILED; }

   RestoreState();
   BuildSessionStats();

   if(InpShowDash) InitDashboard();

   EventSetTimer(1);

   Print("DailyBuySchedulerPro v2.0 | Magic:", InpMagicNumber,
         " | ", Symbol(), " | Open:", InpOpenHour, ":", Pad2(InpOpenMinute),
         " | Close:", InpCloseHour, ":", Pad2(InpCloseMinute));
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//|  OnDeinit                                                        |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   EventKillTimer();
   DeleteDashboard();
   if(g_emaHandle != INVALID_HANDLE) IndicatorRelease(g_emaHandle);
   Print("DailyBuySchedulerPro deinitialized. Reason:", reason);
}

//+------------------------------------------------------------------+
//|  OnTimer - 1-second heartbeat for dashboard refresh              |
//+------------------------------------------------------------------+
void OnTimer()
{
   BuildSessionStats();
   if(InpShowDash) UpdateDashboard();
}

//+------------------------------------------------------------------+
//|  OnTick                                                          |
//+------------------------------------------------------------------+
void OnTick()
{
   if(!IsMarketOpen()) return;

   datetime now      = TimeCurrent();
   datetime todayMid = DayMidnight(now);

   MqlDateTime dt;
   TimeToStruct(now, dt);
   int curMOD   = dt.hour * 60 + dt.min;
   int openMOD  = InpOpenHour  * 60 + InpOpenMinute;
   int closeMOD = InpCloseHour * 60 + InpCloseMinute;

   //--- 1. PROFIT REOPEN CHECK (highest priority)
   if(InpReopenOnProfit && HasOpenPosition())
      CheckProfitReopen();

   //--- 2. TIME-BASED CLOSE
   if(InpUseTimeClose && HasOpenPosition() && curMOD >= closeMOD)
   {
      Print("Time-close triggered at ", TimeToString(now), " – closing position.");
      CloseAllPositions();
      return;
   }

   //--- 3. DAILY SCHEDULED OPEN
   if(g_lastOpenDay < todayMid
      && !HasOpenPosition()
      && curMOD >= openMOD
      && (!InpUseTimeClose || curMOD < closeMOD))
   {
      Print("Scheduled open time reached – opening BUY.");
      OpenTrade(ORDER_TYPE_BUY);
   }
}

//+------------------------------------------------------------------+
//|  Check if current position has hit the profit reopen threshold   |
//+------------------------------------------------------------------+
void CheckProfitReopen()
{
   double openPrice = GetPositionOpenPrice();
   if(openPrice <= 0.0) return;

   ENUM_ORDER_TYPE posType = GetPositionType();
   double curPrice = (posType == ORDER_TYPE_BUY)
                     ? SymbolInfoDouble(Symbol(), SYMBOL_BID)
                     : SymbolInfoDouble(Symbol(), SYMBOL_ASK);
   if(curPrice <= 0.0) return;

   double pctMove = 0.0;
   if(posType == ORDER_TYPE_BUY)
      pctMove = (curPrice - openPrice) / openPrice * 100.0;
   else
      pctMove = (openPrice - curPrice) / openPrice * 100.0;

   if(pctMove >= InpReopenPct)
   {
      Print("Profit reopen triggered | Move: ", DoubleToString(pctMove, 4),
            "% | Threshold: ", InpReopenPct, "%");
      CloseAllPositions();

      if(!HasOpenPosition())
      {
         ENUM_ORDER_TYPE newDir = GetMarketDirection();
         Print("Reopening | New direction: ", EnumToString(newDir));
         OpenTrade(newDir);
         g_totalReopens++;
      }
   }
}

//+------------------------------------------------------------------+
//|  Open a trade (BUY or SELL)                                      |
//+------------------------------------------------------------------+
void OpenTrade(ENUM_ORDER_TYPE otype)
{
   if(!TerminalInfoInteger(TERMINAL_TRADE_ALLOWED))
   { Print("OpenTrade BLOCKED: AutoTrading disabled in terminal."); return; }
   if(!MQLInfoInteger(MQL_TRADE_ALLOWED))
   { Print("OpenTrade BLOCKED: EA trading not allowed (check EA button)."); return; }

   double price = (otype == ORDER_TYPE_BUY)
                  ? SymbolInfoDouble(Symbol(), SYMBOL_ASK)
                  : SymbolInfoDouble(Symbol(), SYMBOL_BID);
   if(price <= 0.0) { Print("OpenTrade: invalid price."); return; }

   double lotMin  = SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_MIN);
   double lotMax  = SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_MAX);
   double lotStep = SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_STEP);
   double lot     = MathMax(lotMin, MathMin(lotMax,
                    MathRound(InpLotSize / lotStep) * lotStep));

   double sl = 0.0, tp = 0.0;
   if(InpStopLossPct > 0.0)
   {
      if(otype == ORDER_TYPE_BUY)
         sl = NormalizePrice(price * (1.0 - InpStopLossPct  / 100.0));
      else
         sl = NormalizePrice(price * (1.0 + InpStopLossPct  / 100.0));
   }
   if(InpTakeProfitPct > 0.0)
   {
      if(otype == ORDER_TYPE_BUY)
         tp = NormalizePrice(price * (1.0 + InpTakeProfitPct / 100.0));
      else
         tp = NormalizePrice(price * (1.0 - InpTakeProfitPct / 100.0));
   }

   AdjustStops(price, otype, sl, tp);

   bool ok = (otype == ORDER_TYPE_BUY)
             ? g_trade.Buy (lot, Symbol(), price, sl, tp, InpBotLabel)
             : g_trade.Sell(lot, Symbol(), price, sl, tp, InpBotLabel);

   if(ok)
   {
      g_lastOpenDay = DayMidnight(TimeCurrent());
      Print("OpenTrade SUCCESS | ", EnumToString(otype),
            " | Ticket:", g_trade.ResultOrder(),
            " | Price:", price, " SL:", sl, " TP:", tp);
   }
   else
   {
      Print("OpenTrade FAILED | Retcode:", g_trade.ResultRetcode(),
            " | ", g_trade.ResultRetcodeDescription());
   }
}

//+------------------------------------------------------------------+
//|  Determine market direction using EMA                            |
//+------------------------------------------------------------------+
ENUM_ORDER_TYPE GetMarketDirection()
{
   if(!InpAllowSell) return ORDER_TYPE_BUY;
   if(g_emaHandle == INVALID_HANDLE) return ORDER_TYPE_BUY;

   double ema[1];
   if(CopyBuffer(g_emaHandle, 0, 0, 1, ema) <= 0)
   { Print("GetMarketDirection: CopyBuffer failed – defaulting BUY."); return ORDER_TYPE_BUY; }

   double bid = SymbolInfoDouble(Symbol(), SYMBOL_BID);
   return (bid > ema[0]) ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
}

//+------------------------------------------------------------------+
//|  Close all positions with our magic on this symbol               |
//+------------------------------------------------------------------+
void CloseAllPositions()
{
   for(int i = PositionsTotal()-1; i >= 0; i--)
   {
      if(!g_pos.SelectByIndex(i)) continue;
      if(g_pos.Magic() != InpMagicNumber) continue;
      if(g_pos.Symbol() != Symbol())      continue;

      if(g_trade.PositionClose(g_pos.Ticket()))
         Print("Closed #", g_pos.Ticket());
      else
         Print("Close FAILED #", g_pos.Ticket(),
               " | ", g_trade.ResultRetcodeDescription());
   }
}

//+------------------------------------------------------------------+
bool HasOpenPosition()
{
   for(int i = PositionsTotal()-1; i >= 0; i--)
   {
      if(!g_pos.SelectByIndex(i)) continue;
      if(g_pos.Magic() == InpMagicNumber && g_pos.Symbol() == Symbol())
         return true;
   }
   return false;
}

//+------------------------------------------------------------------+
double GetFloatingProfit()
{
   double total = 0.0;
   for(int i = PositionsTotal()-1; i >= 0; i--)
   {
      if(!g_pos.SelectByIndex(i)) continue;
      if(g_pos.Magic() == InpMagicNumber && g_pos.Symbol() == Symbol())
         total += g_pos.Profit() + g_pos.Swap() + g_pos.Commission();
   }
   return total;
}

//+------------------------------------------------------------------+
double GetPositionOpenPrice()
{
   for(int i = PositionsTotal()-1; i >= 0; i--)
   {
      if(!g_pos.SelectByIndex(i)) continue;
      if(g_pos.Magic() == InpMagicNumber && g_pos.Symbol() == Symbol())
         return g_pos.PriceOpen();
   }
   return 0.0;
}

//+------------------------------------------------------------------+
ENUM_ORDER_TYPE GetPositionType()
{
   for(int i = PositionsTotal()-1; i >= 0; i--)
   {
      if(!g_pos.SelectByIndex(i)) continue;
      if(g_pos.Magic() == InpMagicNumber && g_pos.Symbol() == Symbol())
         return (ENUM_ORDER_TYPE)g_pos.PositionType();
   }
   return ORDER_TYPE_BUY;
}

//+------------------------------------------------------------------+
bool IsMarketOpen()
{
   ENUM_SYMBOL_TRADE_MODE mode =
      (ENUM_SYMBOL_TRADE_MODE)SymbolInfoInteger(Symbol(), SYMBOL_TRADE_MODE);
   return (mode == SYMBOL_TRADE_MODE_FULL      ||
           mode == SYMBOL_TRADE_MODE_LONGONLY  ||
           mode == SYMBOL_TRADE_MODE_SHORTONLY);
}

//+------------------------------------------------------------------+
void RestoreState()
{
   datetime now      = TimeCurrent();
   datetime todayMid = DayMidnight(now);

   if(HasOpenPosition())
   { g_lastOpenDay = todayMid; Print("RestoreState: open position found."); return; }

   if(!HistorySelect(todayMid, now)) { Print("RestoreState: HistorySelect failed."); return; }

   int total = HistoryDealsTotal();
   for(int i = 0; i < total; i++)
   {
      ulong ticket = HistoryDealGetTicket(i);
      if(ticket == 0) continue;
      if((ulong)HistoryDealGetInteger(ticket, DEAL_MAGIC) != InpMagicNumber) continue;
      if(HistoryDealGetString(ticket, DEAL_SYMBOL)        != Symbol())       continue;
      if(HistoryDealGetInteger(ticket, DEAL_ENTRY)        != DEAL_ENTRY_IN)  continue;
      g_lastOpenDay = todayMid;
      Print("RestoreState: entry deal #", ticket, " found.");
      return;
   }
   Print("RestoreState: no trade today. Ready to open.");
}

//+------------------------------------------------------------------+
void BuildSessionStats()
{
   g_sessionProfit = 0.0;
   g_sessionWins   = 0;
   g_sessionLosses = 0;
   g_sessionTrades = 0;

   datetime dayStart = DayMidnight(TimeCurrent());
   if(!HistorySelect(dayStart, TimeCurrent())) return;

   int total = HistoryDealsTotal();
   for(int i = 0; i < total; i++)
   {
      ulong ticket = HistoryDealGetTicket(i);
      if(ticket == 0) continue;
      if((ulong)HistoryDealGetInteger(ticket, DEAL_MAGIC) != InpMagicNumber) continue;
      if(HistoryDealGetString(ticket, DEAL_SYMBOL)        != Symbol())       continue;

      long entry = HistoryDealGetInteger(ticket, DEAL_ENTRY);
      if(entry == DEAL_ENTRY_IN)
      {
         g_sessionTrades++;
      }
      else if(entry == DEAL_ENTRY_OUT)
      {
         double profit = HistoryDealGetDouble(ticket, DEAL_PROFIT)
                       + HistoryDealGetDouble(ticket, DEAL_SWAP)
                       + HistoryDealGetDouble(ticket, DEAL_COMMISSION);
         g_sessionProfit += profit;
         if(profit >= 0.0) g_sessionWins++; else g_sessionLosses++;
      }
   }
}

//+------------------------------------------------------------------+
void AdjustStops(double price, ENUM_ORDER_TYPE otype, double &sl, double &tp)
{
   int    stopLevel = (int)SymbolInfoInteger(Symbol(), SYMBOL_TRADE_STOPS_LEVEL);
   double point     = SymbolInfoDouble(Symbol(), SYMBOL_POINT);
   double minDist   = stopLevel * point;

   if(otype == ORDER_TYPE_BUY)
   {
      if(sl > 0.0 && (price - sl) < minDist) { sl = NormalizePrice(price - minDist); Print("SL adjusted:", sl); }
      if(tp > 0.0 && (tp - price) < minDist) { tp = NormalizePrice(price + minDist); Print("TP adjusted:", tp); }
   }
   else
   {
      if(sl > 0.0 && (sl - price) < minDist) { sl = NormalizePrice(price + minDist); Print("SL adjusted:", sl); }
      if(tp > 0.0 && (price - tp) < minDist) { tp = NormalizePrice(price - minDist); Print("TP adjusted:", tp); }
   }
}

//+------------------------------------------------------------------+
double NormalizePrice(double price)
{ return NormalizeDouble(price, (int)SymbolInfoInteger(Symbol(), SYMBOL_DIGITS)); }

//+------------------------------------------------------------------+
ENUM_ORDER_TYPE_FILLING GetFillMode()
{
   uint f = (uint)SymbolInfoInteger(Symbol(), SYMBOL_FILLING_MODE);
   if((f & SYMBOL_FILLING_FOK) != 0) return ORDER_FILLING_FOK;
   if((f & SYMBOL_FILLING_IOC) != 0) return ORDER_FILLING_IOC;
   return ORDER_FILLING_RETURN;
}

//+------------------------------------------------------------------+
datetime DayMidnight(datetime ts)
{
   MqlDateTime d; TimeToStruct(ts, d);
   return ts - (datetime)(d.hour*3600 + d.min*60 + d.sec);
}

//+------------------------------------------------------------------+
string Pad2(int v) { return(v < 10 ? "0" : "") + IntegerToString(v); }

//===================  DASHBOARD  ===================================//

void MakeRect(string nm, int x, int y, int w, int h,
              color bg, color brd=clrNONE, int bw=0)
{
   string n = DASH_PRE + nm;
   if(ObjectFind(0, n) >= 0) ObjectDelete(0, n);
   ObjectCreate(0, n, OBJ_RECTANGLE_LABEL, 0, 0, 0);
   ObjectSetInteger(0, n, OBJPROP_CORNER,    CORNER_LEFT_UPPER);
   ObjectSetInteger(0, n, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, n, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, n, OBJPROP_XSIZE,     w);
   ObjectSetInteger(0, n, OBJPROP_YSIZE,     h);
   ObjectSetInteger(0, n, OBJPROP_BGCOLOR,   bg);
   if(brd != clrNONE)
   {
      ObjectSetInteger(0, n, OBJPROP_BORDER_TYPE, BORDER_FLAT);
      ObjectSetInteger(0, n, OBJPROP_COLOR,       brd);
      ObjectSetInteger(0, n, OBJPROP_WIDTH,        bw);
   }
   else
      ObjectSetInteger(0, n, OBJPROP_BORDER_TYPE, BORDER_RAISED);
   ObjectSetInteger(0, n, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, n, OBJPROP_HIDDEN,     true);
   ObjectSetInteger(0, n, OBJPROP_BACK,       false);
   ObjectSetInteger(0, n, OBJPROP_ZORDER,     0);
}

void MakeLbl(string nm, int x, int y, string txt, color clr, int fsz,
             string font="Arial Bold")
{
   string n = DASH_PRE + nm;
   if(ObjectFind(0, n) >= 0) ObjectDelete(0, n);
   ObjectCreate(0, n, OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, n, OBJPROP_CORNER,    CORNER_LEFT_UPPER);
   ObjectSetInteger(0, n, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, n, OBJPROP_YDISTANCE, y);
   ObjectSetString (0, n, OBJPROP_TEXT,      txt);
   ObjectSetInteger(0, n, OBJPROP_COLOR,     clr);
   ObjectSetInteger(0, n, OBJPROP_FONTSIZE,  fsz);
   ObjectSetString (0, n, OBJPROP_FONT,      font);
   ObjectSetInteger(0, n, OBJPROP_SELECTABLE,false);
   ObjectSetInteger(0, n, OBJPROP_HIDDEN,    true);
   ObjectSetInteger(0, n, OBJPROP_BACK,      false);
   ObjectSetInteger(0, n, OBJPROP_ZORDER,    1);
}

void UpdLbl(string nm, string txt, color clr=C'215,220,232')
{
   string n = DASH_PRE + nm;
   if(ObjectFind(0, n) >= 0)
   {
      ObjectSetString (0, n, OBJPROP_TEXT,  txt);
      ObjectSetInteger(0, n, OBJPROP_COLOR, clr);
   }
}

//+------------------------------------------------------------------+
//|  Build all dashboard chart objects                               |
//+------------------------------------------------------------------+
void InitDashboard()
{
   int X = InpDashX, Y = InpDashY;

   // == MAIN BACKGROUND ==
   MakeRect("bg",     X,    Y,    DW,    DH,    C_BG,     C_ACBORDER, 2);

   // == HEADER BAND ==
   MakeRect("hdr",    X+2,  Y+2,  DW-4,  68,    C_HDRBAR, C_BORDER,   1);
   MakeLbl ("htitle", X+10, Y+8,  InpBotLabel,              C_GOLD,   11, "Arial Black");
   MakeLbl ("hsub1",  X+10, Y+28, "Autonomous Scheduled Trading Engine", C_CYAN,    8, "Arial");
   MakeLbl ("hsub2",  X+10, Y+44, "v2.0  |  Isolated  |  Magic: "+IntegerToString((long)InpMagicNumber),
                                                             C_LBLUE,   7, "Arial");
   MakeLbl ("hright", X+DW-90, Y+14, Symbol(),              C_GOLD,   10, "Arial Black");

   // Thin accent divider
   MakeRect("div0",   X+2,  Y+72, DW-4,   2,    C_ACBORDER);

   // == PERFORMANCE SECTION ==
   MakeRect("prf_bg", X+2,  Y+76, DW-4,  136,   C_PANEL,  C_BORDER,   1);
   MakeLbl ("prf_hd", X+10, Y+82, "  PERFORMANCE",         C_GOLD,    9, "Arial Black");
   MakeRect("div1",   X+2,  Y+98, DW-4,    1,   C_BORDER);

   // Row data: label / value
   MakeLbl ("lb_sp",  X+14, Y+105, "Session Profit",        C_MGRAY,  8, "Arial");
   MakeLbl ("vl_sp",  X+245,Y+105, "$ 0.00",                C_WHITE,  8, "Arial Bold");

   MakeLbl ("lb_fp",  X+14, Y+121, "Floating P&L",          C_MGRAY,  8, "Arial");
   MakeLbl ("vl_fp",  X+245,Y+121, "$ 0.00",                C_WHITE,  8, "Arial Bold");

   MakeLbl ("lb_tr",  X+14, Y+137, "Trades Today",          C_MGRAY,  8, "Arial");
   MakeLbl ("vl_tr",  X+245,Y+137, "0",                     C_WHITE,  8, "Arial Bold");

   MakeLbl ("lb_wr",  X+14, Y+153, "Win Rate",              C_MGRAY,  8, "Arial");
   MakeLbl ("vl_wr",  X+245,Y+153, "0 %",                   C_WHITE,  8, "Arial Bold");

   MakeLbl ("lb_rp",  X+14, Y+169, "Profit Reopens",        C_MGRAY,  8, "Arial");
   MakeLbl ("vl_rp",  X+245,Y+169, "0",                     C_CYAN,   8, "Arial Bold");

   // == TRADING STATUS SECTION ==
   MakeRect("ts_bg",  X+2,  Y+214, DW-4, 136,   C_PANEL,  C_BORDER,   1);
   MakeLbl ("ts_hd",  X+10, Y+220, "  TRADING STATUS",      C_GOLD,    9, "Arial Black");
   MakeRect("div2",   X+2,  Y+236, DW-4,   1,   C_BORDER);

   MakeLbl ("lb_sym", X+14, Y+243, "Symbol",                C_MGRAY,  8, "Arial");
   MakeLbl ("vl_sym", X+245,Y+243, Symbol(),                C_CYAN,   8, "Arial Bold");

   MakeLbl ("lb_sta", X+14, Y+259, "Status",                C_MGRAY,  8, "Arial");
   MakeLbl ("vl_sta", X+245,Y+259, "STARTING",              C_ORANGE, 8, "Arial Bold");

   MakeLbl ("lb_dir", X+14, Y+275, "EMA Direction",         C_MGRAY,  8, "Arial");
   MakeLbl ("vl_dir", X+245,Y+275, "--",                    C_WHITE,  8, "Arial Bold");

   MakeLbl ("lb_pos", X+14, Y+291, "Open Position",         C_MGRAY,  8, "Arial");
   MakeLbl ("vl_pos", X+245,Y+291, "NONE",                  C_MGRAY,  8, "Arial Bold");

   MakeLbl ("lb_spr", X+14, Y+307, "Spread (pts)",          C_MGRAY,  8, "Arial");
   MakeLbl ("vl_spr", X+245,Y+307, "0",                     C_WHITE,  8, "Arial Bold");

   MakeLbl ("lb_mkt", X+14, Y+323, "Market",                C_MGRAY,  8, "Arial");
   MakeLbl ("vl_mkt", X+245,Y+323, "OPEN",                  C_GREEN,  8, "Arial Bold");

   // == SYSTEM INFO SECTION ==
   MakeRect("si_bg",  X+2,  Y+352, DW-4, 104,   C_PANEL,  C_BORDER,   1);
   MakeLbl ("si_hd",  X+10, Y+358, "  SYSTEM INFO",         C_GOLD,    9, "Arial Black");
   MakeRect("div3",   X+2,  Y+374, DW-4,   1,   C_BORDER);

   MakeLbl ("lb_mag", X+14, Y+381, "Magic Number",          C_MGRAY,  8, "Arial");
   MakeLbl ("vl_mag", X+245,Y+381, IntegerToString((long)InpMagicNumber), C_LBLUE, 8, "Arial Bold");

   MakeLbl ("lb_oct", X+14, Y+397, "Open Time",             C_MGRAY,  8, "Arial");
   MakeLbl ("vl_oct", X+245,Y+397, IntegerToString(InpOpenHour)+":"+Pad2(InpOpenMinute),
                                                             C_LBLUE,  8, "Arial Bold");

   MakeLbl ("lb_clt", X+14, Y+413, "Close Time",            C_MGRAY,  8, "Arial");
   MakeLbl ("vl_clt", X+245,Y+413, InpUseTimeClose
                                   ? IntegerToString(InpCloseHour)+":"+Pad2(InpCloseMinute)
                                   : "Disabled",             C_LBLUE,  8, "Arial Bold");

   MakeLbl ("lb_slr", X+14, Y+429, "SL / TP",               C_MGRAY,  8, "Arial");
   MakeLbl ("vl_slr", X+245,Y+429, DoubleToString(InpStopLossPct,1)+"% / "
                                   +DoubleToString(InpTakeProfitPct,1)+"%",
                                                             C_LBLUE,  8, "Arial Bold");

   // == FOOTER ==
   MakeRect("ftr",    X+2,  Y+458, DW-4,  18,   C_HDRBAR, C_BORDER,   1);
   MakeLbl ("ft_tm",  X+10, Y+461, "Server: --:--",         C_DGRAY,   7, "Arial");
   MakeLbl ("ft_ver", X+DW-120, Y+461, "DBS Pro  v2.0",     C_DGRAY,   7, "Arial");

   ChartRedraw(0);
}

//+------------------------------------------------------------------+
//|  Refresh all dynamic values on the dashboard                     |
//+------------------------------------------------------------------+
void UpdateDashboard()
{
   if(!InpShowDash) return;

   bool   posOpen  = HasOpenPosition();
   bool   mktOpen  = IsMarketOpen();
   double floatPL  = GetFloatingProfit();
   int    spread   = (int)SymbolInfoInteger(Symbol(), SYMBOL_SPREAD);

   // --- Performance ---
   color spClr = (g_sessionProfit >= 0.0) ? C_GREEN : C_RED;
   UpdLbl("vl_sp", "$ " + DoubleToString(g_sessionProfit, 2), spClr);

   color fpClr = (floatPL >= 0.0) ? C_GREEN : C_RED;
   UpdLbl("vl_fp", "$ " + DoubleToString(floatPL, 2), fpClr);

   UpdLbl("vl_tr", IntegerToString(g_sessionTrades));

   int winrate = (g_sessionTrades > 0)
                 ? (int)MathRound((double)g_sessionWins / g_sessionTrades * 100.0)
                 : 0;
   color wrClr = (winrate >= 50) ? C_GREEN : C_RED;
   UpdLbl("vl_wr", IntegerToString(winrate) + " %", wrClr);
   UpdLbl("vl_rp", IntegerToString(g_totalReopens), C_CYAN);

   // --- Trading Status ---
   if(!mktOpen)
      UpdLbl("vl_sta", "MARKET CLOSED", C_RED);
   else if(posOpen)
      UpdLbl("vl_sta", "  IN TRADE", C_GREEN);
   else
      UpdLbl("vl_sta", "MONITORING", C_ORANGE);

   if(g_emaHandle != INVALID_HANDLE)
   {
      ENUM_ORDER_TYPE dir = GetMarketDirection();
      if(dir == ORDER_TYPE_BUY)
         UpdLbl("vl_dir", "BUY  (Bullish)", C_GREEN);
      else
         UpdLbl("vl_dir", "SELL (Bearish)", C_RED);
   }

   if(posOpen)
   {
      ENUM_ORDER_TYPE pt = GetPositionType();
      UpdLbl("vl_pos", (pt == ORDER_TYPE_BUY ? "BUY" : "SELL"),
             (pt == ORDER_TYPE_BUY ? C_GREEN : C_RED));
   }
   else
      UpdLbl("vl_pos", "NONE", C_MGRAY);

   UpdLbl("vl_spr", IntegerToString(spread));
   UpdLbl("vl_mkt", mktOpen ? "OPEN" : "CLOSED", mktOpen ? C_GREEN : C_RED);

   // --- Footer ---
   UpdLbl("ft_tm",
          "Server: " + TimeToString(TimeCurrent(), TIME_MINUTES) +
          "  |  Local: " + TimeToString(TimeLocal(), TIME_MINUTES),
          C_DGRAY);

   ChartRedraw(0);
}

//+------------------------------------------------------------------+
void DeleteDashboard()
{
   ObjectsDeleteAll(0, DASH_PRE);
   ChartRedraw(0);
}
//+------------------------------------------------------------------+