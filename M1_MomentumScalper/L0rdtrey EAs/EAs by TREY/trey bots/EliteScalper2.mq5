//+------------------------------------------------------------------+
//|                                                 EliteScalper.mq5 |
//|                                                                  |
//|  High-Frequency Institutional Scalper | 24/5 Autonomous Engine   |
//|  SMC Structural Imbalance Logic | Target Profit | Advanced Risk  |
//+------------------------------------------------------------------+
#property copyright   "EliteScalper Systems"
#property link        ""
#property version     "5.00"
#property description "Fully autonomous SMC displacement scalper with live dashboard."

#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>

//--- Dashboard Prefix & Brand Colors (Green, Blue, Black Palette)
#define DASH_PRE  "EliteScalper"

#define C_BG      C'4,6,10'       // Deep Black
#define C_PANEL   C'8,12,20'      // Off Black
#define C_HDRBAR  C'0,35,90'      // Deep Blue Accent
#define C_BORDER  C'0,60,150'     // Bright Blue
#define C_BRAND   C'0,120,255'    // EliteScalper Blue
#define C_WHITE   C'240,245,255'  // Crisp White
#define C_GREEN   C'0,230,115'    // Bright Profit Green
#define C_RED     C'240,50,60'    // Risk Red
#define C_GOLD    C'255,200,50'   // Warning/Wait Yellow
#define C_DGRAY   C'80,90,110'
#define C_TEXT    C'170,185,210'

//+------------------------------------------------------------------+
//|  INPUT PARAMETERS                                                |
//+------------------------------------------------------------------+
input group "=== Trading Engine ==="
input ulong   InpMagicNumber     = 88888;      // Institutional Magic Number
input double  InpLotSize         = 0.01;       // Lot Size
input int     InpMaxDailyTrades  = 20;         // Max Trades Per Day

input group "=== Rapid Profit & Re-entry ==="
input double  InpTargetProfitUSD = 1.0;        // Target Profit to Close ($)
input int     InpWaitSeconds     = 60;         // Cooldown Before Re-entry (Seconds)

input group "=== Risk Protection ==="
input int     InpStopLossPoints  = 500;        // Stop Loss (Points)
input int     InpTakeProfitPoints= 500;        // Take Profit (Points)
input int     InpMaxSpread       = 30;         // Max Allowed Spread (Points)

input group "=== Institutional SMC Logic ==="
input int     InpMinFvgImbalance = 150;        // Minimum FVG Imbalance (Points)

input group "=== Account Protection ==="
input long    InpAllowedAccount  = 5057245741;  // Allowed Account Number (0 = any)

input group "=== Interface ==="
input int     InpDashX           = 20;         // Dashboard X Offset
input int     InpDashY           = 30;         // Dashboard Y Offset

//+------------------------------------------------------------------+
//|  CONSTANTS & GLOBALS                                             |
//+------------------------------------------------------------------+
const int DW = 420;   // Expanded Width
const int DH = 540;   // Expanded Height

CTrade        g_trade;
CPositionInfo g_pos;

datetime      g_nextEntryTime = 0;
datetime      g_lastResetDay  = 0;
datetime      g_lastBarTime   = 0;             // Track candles to prevent machine-gun duplicate entries

// Live Stats
int           g_tradesToday   = 0;
double        g_profitToday   = 0.0;
string        g_digitFlow     = "";
string        g_statusMsg     = "INITIALIZING";
color         g_statusClr     = C_BRAND;

//+------------------------------------------------------------------+
//|  FORWARD DECLARATIONS                                            |
//+------------------------------------------------------------------+
void   BuildSessionStats();
void   CheckTargetProfit();
void   ExecuteEntry(datetime currentBar);
bool   IsMarketOpen();
void   CloseAllPositions(string reason);
bool   HasOpenPosition();
double GetFloatingProfit();
ENUM_ORDER_TYPE GetSmcDisplacement();
datetime DayMidnight(datetime ts);
void   InitDashboard();
void   UpdateDashboard();
void   DeleteDashboard();
void   MakeRect(string nm, int x, int y, int w, int h, color bg, color brd, int bw);
void   MakeLbl(string nm, int x, int y, string txt, color clr, int fsz, string font);
void   UpdLbl(string nm, string txt, color clr);

//+------------------------------------------------------------------+
//|  OnInit                                                          |
//+------------------------------------------------------------------+
int OnInit()
  {
   //--- Account Protection: block EA on unauthorized accounts
   if(InpAllowedAccount != 0 && AccountInfoInteger(ACCOUNT_LOGIN) != InpAllowedAccount)
     {
      Alert("EliteScalper2 BLOCKED! Account ",AccountInfoInteger(ACCOUNT_LOGIN),
            " is not authorized. Allowed: ",InpAllowedAccount);
      return INIT_FAILED;
     }

   g_trade.SetExpertMagicNumber(InpMagicNumber);
   g_trade.SetDeviationInPoints(10);

   InitDashboard();
   BuildSessionStats();

   // Start scanning immediately
   g_nextEntryTime = TimeCurrent();
   g_lastBarTime = 0;
   EventSetTimer(1);

   return INIT_SUCCEEDED;
  }

//+------------------------------------------------------------------+
//|  OnDeinit                                                        |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   EventKillTimer();
   DeleteDashboard();
  }

//+------------------------------------------------------------------+
//|  OnTimer (UI & System Activity)                                  |
//+------------------------------------------------------------------+
void OnTimer()
  {
   // Generate Digit Flow string to confirm background loop is active
   int tick = GetTickCount() % 4;
   if(tick == 0) g_digitFlow = "1 0 0 1  1 0";
   if(tick == 1) g_digitFlow = "0 1 1 0  0 1";
   if(tick == 2) g_digitFlow = "1 1 0 0  1 1";
   if(tick == 3) g_digitFlow = "0 0 1 1  0 0";

   BuildSessionStats();
   UpdateDashboard();
  }

//+------------------------------------------------------------------+
//|  OnTick (High-Frequency Execution Loop)                          |
//+------------------------------------------------------------------+
void OnTick()
  {
   if(!IsMarketOpen())
     {
      g_statusMsg = "MARKET CLOSED";
      g_statusClr = C_RED;
      return;
     }

// 1. Check for Target Profit Closure (Highest Priority)
   if(HasOpenPosition())
     {
      CheckTargetProfit();
      return; 
     }

// 2. Check Daily Limits
   if(g_tradesToday >= InpMaxDailyTrades)
     {
      g_statusMsg = "DAILY LIMIT REACHED";
      g_statusClr = C_GOLD;
      return;
     }

// 3. New Bar Protection Layer (Prevents over-trading on the stopped-out bar)
   datetime currentBarTime = (datetime)SeriesInfoInteger(Symbol(), PERIOD_CURRENT, SERIES_LASTBAR_DATE);
   
   if(TimeCurrent() < g_nextEntryTime)
     {
      int secs = (int)(g_nextEntryTime - TimeCurrent());
      g_statusMsg = "COOLDOWN: " + IntegerToString(secs) + "s";
      g_statusClr = C_GOLD;
      return;
     }
   else if(currentBarTime == g_lastBarTime)
     {
      g_statusMsg = "BAR LOCKED - WAITING NEW";
      g_statusClr = C_DGRAY;
      return;
     }

// 4. Spread Filter
   int spread = (int)SymbolInfoInteger(Symbol(), SYMBOL_SPREAD);
   if(spread > InpMaxSpread)
     {
      g_statusMsg = "SPREAD TOO HIGH ("+IntegerToString(spread)+")";
      g_statusClr = C_RED;
      return;
     }

// 5. Execute Trade Based on Institutional Footprint
   ExecuteEntry(currentBarTime);
  }

//+------------------------------------------------------------------+
//|  Closes trade immediately when Target Profit is hit              |
//+------------------------------------------------------------------+
void CheckTargetProfit()
  {
   double floatPL = GetFloatingProfit();
   if(floatPL >= InpTargetProfitUSD)
     {
      Print("Target Profit Hit: $", DoubleToString(floatPL, 2), " - Closing Position.");
      CloseAllPositions("Target Profit");

      // Set Cooldown Timer
      g_nextEntryTime = TimeCurrent() + InpWaitSeconds;
      g_statusMsg = "PROFIT LOCKED - COOLDOWN";
      g_statusClr = C_GREEN;
     }
   else
     {
      g_statusMsg = "IN TRANSACTION";
      g_statusClr = C_BRAND;
     }
  }

//+------------------------------------------------------------------+
//|  Opens trade based on Smart Money Order Flow                     |
//+------------------------------------------------------------------+
void ExecuteEntry(datetime currentBar)
  {
   ENUM_ORDER_TYPE dir = GetSmcDisplacement();

   if(dir == WRONG_VALUE)
     {
      g_statusMsg = "SCANNING: NO IMBALANCE";
      g_statusClr = C_TEXT;
      return;
     }

   double price = (dir == ORDER_TYPE_BUY) ? SymbolInfoDouble(Symbol(), SYMBOL_ASK)
                  : SymbolInfoDouble(Symbol(), SYMBOL_BID);

   double point = SymbolInfoDouble(Symbol(), SYMBOL_POINT);
   int digits   = (int)SymbolInfoInteger(Symbol(), SYMBOL_DIGITS);

   double sl = 0.0, tp = 0.0;
   if(InpStopLossPoints > 0)
     {
      sl = (dir == ORDER_TYPE_BUY) ? price - (InpStopLossPoints * point)
           : price + (InpStopLossPoints * point);
     }
   if(InpTakeProfitPoints > 0)
     {
      tp = (dir == ORDER_TYPE_BUY) ? price + (InpTakeProfitPoints * point)
           : price - (InpTakeProfitPoints * point);
     }

   sl = NormalizeDouble(sl, digits);
   tp = NormalizeDouble(tp, digits);

   bool ok = false;
   if(dir == ORDER_TYPE_BUY)
      ok = g_trade.Buy(InpLotSize, Symbol(), price, sl, tp, "EliteSMC Alpha");
   if(dir == ORDER_TYPE_SELL)
      ok = g_trade.Sell(InpLotSize, Symbol(), price, sl, tp, "EliteSMC Alpha");

   if(ok)
     {
      Print("SMC Order Entry: ", EnumToString(dir), " | Entry Price: ", price);
      g_tradesToday++;
      g_lastBarTime = currentBar; // Successfully lock this bar structure from multi-firing
     }
  }

//+------------------------------------------------------------------+
//|  SMC Displacement Engine (Fair Value Gap Finder)                 |
//+------------------------------------------------------------------+
ENUM_ORDER_TYPE GetSmcDisplacement()
  {
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   
   // Copy historical candle details to scan for inefficiencies
   if(CopyRates(Symbol(), PERIOD_CURRENT, 0, 4, rates) < 4)
      return WRONG_VALUE;

   double pt = SymbolInfoDouble(Symbol(), SYMBOL_POINT);
   double minGap = InpMinFvgImbalance * pt;

   // Bullish FVG Pattern Check (Bar 1 Low is greater than Bar 3 High)
   if((rates[1].low - rates[3].high) >= minGap)
     {
      if(rates[2].close > rates[2].open) // Confirming displacement bullish expansion
         return ORDER_TYPE_BUY;
     }

   // Bearish FVG Pattern Check (Bar 3 Low is greater than Bar 1 High)
   if((rates[3].low - rates[1].high) >= minGap)
     {
      if(rates[2].close < rates[2].open) // Confirming displacement bearish expansion
         return ORDER_TYPE_SELL;
     }

   return WRONG_VALUE;
  }

//+------------------------------------------------------------------+
//|  Utility Functions                                               |
//+------------------------------------------------------------------+
void CloseAllPositions(string reason)
  {
   for(int i = PositionsTotal()-1; i >= 0; i--)
     {
      if(g_pos.SelectByIndex(i) && g_pos.Magic() == InpMagicNumber && g_pos.Symbol() == Symbol())
        {
         g_trade.PositionClose(g_pos.Ticket());
        }
     }
  }

bool HasOpenPosition()
  {
   for(int i = PositionsTotal()-1; i >= 0; i--)
     {
      if(g_pos.SelectByIndex(i) && g_pos.Magic() == InpMagicNumber && g_pos.Symbol() == Symbol())
         return true;
     }
   return false;
  }

double GetFloatingProfit()
  {
   double total = 0.0;
   for(int i = PositionsTotal()-1; i >= 0; i--)
     {
      if(g_pos.SelectByIndex(i) && g_pos.Magic() == InpMagicNumber && g_pos.Symbol() == Symbol())
         total += g_pos.Profit() + g_pos.Swap() + g_pos.Commission();
     }
   return total;
  }

bool IsMarketOpen()
  {
   ENUM_SYMBOL_TRADE_MODE mode = (ENUM_SYMBOL_TRADE_MODE)SymbolInfoInteger(Symbol(), SYMBOL_TRADE_MODE);
   return (mode == SYMBOL_TRADE_MODE_FULL || mode == SYMBOL_TRADE_MODE_LONGONLY || mode == SYMBOL_TRADE_MODE_SHORTONLY);
  }

datetime DayMidnight(datetime ts)
  {
   MqlDateTime d;
   TimeToStruct(ts, d);
   return ts - (datetime)(d.hour*3600 + d.min*60 + d.sec);
  }

void BuildSessionStats()
  {
   datetime now = TimeCurrent();
   datetime todayMid = DayMidnight(now);

   if(todayMid > g_lastResetDay)
     {
      g_tradesToday = 0;
      g_profitToday = 0.0;
      g_lastResetDay = todayMid;
     }

   g_profitToday = 0.0;
   if(HistorySelect(todayMid, now))
     {
      for(int i = 0; i < HistoryDealsTotal(); i++)
        {
         ulong ticket = HistoryDealGetTicket(i);
         if(HistoryDealGetInteger(ticket, DEAL_MAGIC) == InpMagicNumber &&
            HistoryDealGetString(ticket, DEAL_SYMBOL) == Symbol() &&
            HistoryDealGetInteger(ticket, DEAL_ENTRY) == DEAL_ENTRY_OUT)
           {
            g_profitToday += HistoryDealGetDouble(ticket, DEAL_PROFIT) +
                             HistoryDealGetDouble(ticket, DEAL_COMMISSION) +
                             HistoryDealGetDouble(ticket, DEAL_SWAP);
           }
        }
     }
  }

//===================  DASHBOARD GRAPHICS  ==========================//
void InitDashboard()
  {
   int X = InpDashX, Y = InpDashY;

   MakeRect("bg", X, Y, DW, DH, C_BG, C_BORDER, 2);

   MakeRect("hdr", X+2, Y+2, DW-4, 80, C_HDRBAR, C_BORDER, 1);
   MakeLbl("htitle", X+15, Y+10, "EliteScalper Pro", C_WHITE, 16, "Arial Black");
   MakeLbl("hsub1",  X+15, Y+38, "SMC DISPLACEMENT ENGINE", C_BRAND, 10, "Arial Black");
   MakeLbl("hsub2",  X+15, Y+55, "Institutional Order Flow Vector Tracker", C_TEXT, 8, "Arial");

   MakeRect("act_bg", X+2, Y+85, DW-4, 30, C_PANEL, clrNONE, 0);
   MakeLbl("lbl_act", X+15, Y+92, "[ CORE FEED ]", C_DGRAY, 8, "Consolas");
   MakeLbl("val_act", X+120,Y+92, "0 0 0 0 0 0", C_BRAND, 9, "Consolas");

   MakeRect("pnl1", X+2, Y+120, DW-4, 150, C_PANEL, C_BORDER, 1);
   MakeLbl("hd1",  X+15, Y+128, "ACCOUNT DYNAMICS", C_WHITE, 10, "Arial Black");

   MakeLbl("lb_bal", X+20, Y+160, "Balance:", C_TEXT, 9, "Arial");
   MakeLbl("vl_bal", X+200,Y+160, "$ 0.00", C_WHITE, 10, "Arial Bold");

   MakeLbl("lb_eq",  X+20, Y+185, "Equity:", C_TEXT, 9, "Arial");
   MakeLbl("vl_eq",  X+200,Y+185, "$ 0.00", C_WHITE, 10, "Arial Bold");

   MakeLbl("lb_dp",  X+20, Y+210, "Today's Net Profit:", C_TEXT, 9, "Arial");
   MakeLbl("vl_dp",  X+200,Y+210, "$ 0.00", C_GREEN, 10, "Arial Bold");

   MakeLbl("lb_fp",  X+20, Y+235, "Floating P&L:", C_TEXT, 9, "Arial");
   MakeLbl("vl_fp",  X+200,Y+235, "$ 0.00", C_GREEN, 10, "Arial Bold");

   MakeRect("pnl2", X+2, Y+275, DW-4, 180, C_PANEL, C_BORDER, 1);
   MakeLbl("hd2",  X+15, Y+283, "EXECUTION MATRIX", C_WHITE, 10, "Arial Black");

   MakeLbl("lb_sta", X+20, Y+315, "Engine Status:", C_TEXT, 9, "Arial");
   MakeLbl("vl_sta", X+200,Y+315, "SCANNING", C_BRAND, 9, "Arial Bold");

   MakeLbl("lb_trd", X+20, Y+340, "Daily Trades:", C_TEXT, 9, "Arial");
   MakeLbl("vl_trd", X+200,Y+340, "0 / 20", C_WHITE, 9, "Arial Bold");

   MakeLbl("lb_tgt", X+20, Y+365, "Auto-Close Target:", C_TEXT, 9, "Arial");
   MakeLbl("vl_tgt", X+200,Y+365, "$ " + DoubleToString(InpTargetProfitUSD, 2), C_BRAND, 9, "Arial Bold");

   MakeLbl("lb_cd",  X+20, Y+390, "Re-entry Cooldown:", C_TEXT, 9, "Arial");
   MakeLbl("vl_cd",  X+200,Y+390, IntegerToString(InpWaitSeconds) + " sec", C_WHITE, 9, "Arial Bold");

   MakeLbl("lb_dir", X+20, Y+415, "SMC Order Flow:", C_TEXT, 9, "Arial");
   MakeLbl("vl_dir", X+200,Y+415, "ANALYZING", C_WHITE, 9, "Arial Bold");

   // Footer
   MakeRect("ftr", X+2, Y+460, DW-4, 78, C_BG, clrNONE, 0);
   MakeLbl("ft1", X+15, Y+470, "100% Autonomous 24/5 Operations", C_DGRAY, 8, "Arial");
   MakeLbl("ft2", X+15, Y+490, "SMC Vector Infrastructure Active", C_DGRAY, 8, "Arial");
   MakeLbl("ft3", X+15, Y+510, "Symbol: " + Symbol() + " | Magic: " + IntegerToString((long)InpMagicNumber), C_DGRAY, 8, "Arial");

   ChartRedraw(0);
  }

void UpdateDashboard()
  {
   UpdLbl("val_act", g_digitFlow, C_BRAND);

   double bal = AccountInfoDouble(ACCOUNT_BALANCE);
   double eq  = AccountInfoDouble(ACCOUNT_EQUITY);
   double fpl = GetFloatingProfit();

   UpdLbl("vl_bal", "$ " + DoubleToString(bal, 2));
   UpdLbl("vl_eq",  "$ " + DoubleToString(eq,  2));

   UpdLbl("vl_dp", (g_profitToday >= 0 ? "+$ " : "-$ ") + DoubleToString(MathAbs(g_profitToday), 2), (g_profitToday >= 0 ? C_GREEN : C_RED));
   UpdLbl("vl_fp", (fpl >= 0 ? "+$ " : "-$ ") + DoubleToString(MathAbs(fpl), 2), (fpl >= 0 ? C_GREEN : C_RED));

   UpdLbl("vl_sta", g_statusMsg, g_statusClr);
   UpdLbl("vl_trd", IntegerToString(g_tradesToday) + " / " + IntegerToString(InpMaxDailyTrades));

   ENUM_ORDER_TYPE dir = GetSmcDisplacement();
   if(g_statusMsg == "BAR LOCKED - WAITING NEW")
     {
      UpdLbl("vl_dir", "STRUCTURE LOCKED", C_DGRAY);
     }
   else if(dir == ORDER_TYPE_BUY)
     {
      UpdLbl("vl_dir", "BULLISH IMBALANCE", C_GREEN);
     }
   else if(dir == ORDER_TYPE_SELL)
     {
      UpdLbl("vl_dir", "BEARISH IMBALANCE", C_RED);
     }
   else
     {
      UpdLbl("vl_dir", "EQUILIBRIUM", C_TEXT);
     }

   ChartRedraw(0);
  }

void DeleteDashboard() { ObjectsDeleteAll(0, DASH_PRE); ChartRedraw(0); }

void MakeRect(string nm, int x, int y, int w, int h, color bg, color brd=clrNONE, int bw=0)
  {
   string n = DASH_PRE + nm;
   ObjectCreate(0, n, OBJ_RECTANGLE_LABEL, 0, 0, 0);
   ObjectSetInteger(0, n, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, n, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, n, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, n, OBJPROP_XSIZE, w);
   ObjectSetInteger(0, n, OBJPROP_YSIZE, h);
   ObjectSetInteger(0, n, OBJPROP_BGCOLOR, bg);
   if(brd != clrNONE)
     {
      ObjectSetInteger(0, n, OBJPROP_BORDER_TYPE, BORDER_FLAT);
      ObjectSetInteger(0, n, OBJPROP_COLOR, brd);
      ObjectSetInteger(0, n, OBJPROP_WIDTH, bw);
     }
   else
      ObjectSetInteger(0, n, OBJPROP_BORDER_TYPE, BORDER_RAISED);
   ObjectSetInteger(0, n, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, n, OBJPROP_HIDDEN, true);
   ObjectSetInteger(0, n, OBJPROP_ZORDER, 0);
  }

void MakeLbl(string nm, int x, int y, string txt, color clr, int fsz, string font)
  {
   string n = DASH_PRE + nm;
   ObjectCreate(0, n, OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, n, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, n, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, n, OBJPROP_YDISTANCE, y);
   ObjectSetString(0, n, OBJPROP_TEXT, txt);
   ObjectSetInteger(0, n, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, n, OBJPROP_FONTSIZE, fsz);
   ObjectSetString(0, n, OBJPROP_FONT, font);
   ObjectSetInteger(0, n, OBJPROP_SELECTABLE,false);
   ObjectSetInteger(0, n, OBJPROP_HIDDEN, true);
   ObjectSetInteger(0, n, OBJPROP_ZORDER, 1);
  }

void UpdLbl(string nm, string txt, color clr=clrNONE)
  {
   string n = DASH_PRE + nm;
   if(ObjectFind(0, n) >= 0)
     {
      ObjectSetString(0, n, OBJPROP_TEXT, txt);
      if(clr != clrNONE)
         ObjectSetInteger(0, n, OBJPROP_COLOR, clr);
     }
  }