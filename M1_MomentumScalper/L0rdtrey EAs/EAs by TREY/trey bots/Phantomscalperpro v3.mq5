//+------------------------------------------------------------------+
//|              PHANTOM SCALPER PRO  –  Institutional Edition       |
//|              v3.0  |  24/5 Autonomous HF Scalping System         |
//|              Profit-close + Smart Re-entry + Full Dashboard       |
//+------------------------------------------------------------------+
#property copyright   "PHANTOM SCALPER PRO  v3.0"
#property version     "3.00"
#property description "24/5 autonomous HF scalping | Profit-close | Smart re-entry | Live dashboard"

#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>
#include <Trade\AccountInfo.mqh>

//--- Dashboard namespace prefix
#define D "PSP_"

//=======================================================================
//  COLOUR PALETTE  –  Deep-space luxury fintech
//=======================================================================
#define C_BG0       C'4,6,18'        // deepest background
#define C_BG1       C'8,12,28'       // panel background
#define C_BG2       C'12,18,42'      // card background
#define C_HDRBAR    C'10,16,38'      // header
#define C_BORDER    C'22,44,90'      // subtle border
#define C_ACBORD    C'0,160,220'     // accent border (cyan)
#define C_ACBORD2   C'160,80,255'    // accent border (purple)
#define C_GOLD      C'255,200,40'    // gold accent
#define C_CYAN      C'0,220,220'     // cyan
#define C_PURPLE    C'180,100,255'   // purple
#define C_WHITE     C'220,225,240'   // primary text
#define C_SUBTEXT   C'110,130,160'   // subdued label
#define C_GREEN     C'20,220,110'    // profit / bullish
#define C_RED       C'230,55,65'     // loss / bearish
#define C_ORANGE    C'255,145,0'     // warning / monitoring
#define C_DKGREEN   C'14,80,45'      // green fill
#define C_DKRED     C'80,18,22'      // red fill
#define C_LBLUE     C'80,160,255'    // light blue
#define C_DGRAY     C'40,52,72'      // dark grey
#define C_MGRAY     C'75,90,115'     // mid grey
#define C_BADGE_BG  C'16,24,56'      // badge background

//=======================================================================
//  INPUT PARAMETERS
//=======================================================================
input group "╔══════  IDENTITY  ══════╗"
input ulong  InpMagicNumber     = 99999;       // Magic Number
input string InpBotName         = "PHANTOM SCALPER PRO"; // Bot Name

input group "╔══════  LOT & RISK  ══════╗"
input double InpLotSize         = 0.01;        // Lot Size
input double InpProfitTargetUSD = 1.00;        // Profit Target per Trade (USD)
input double InpStopLossPct     = 1.5;         // Stop Loss % from entry (0=off)
input double InpTakeProfitPct   = 3.0;         // Take Profit % from entry (0=off)
input double InpMaxDailyLossPct = 5.0;         // Max Daily Loss % of Balance (0=off)
input double InpMaxDailyProfitPct = 10.0;      // Max Daily Profit % of Balance (0=off)

input group "╔══════  TRADE FREQUENCY  ══════╗"
input int    InpMaxDailyTrades  = 6;          // Max Trades Per Day (0=unlimited)
input int    InpCooldownSec     = 60;          // Cooldown Seconds After Close
input bool   InpTradeWeekends   = false;       // Allow Weekend Trading

input group "╔══════  DIRECTION FILTER  ══════╗"
input bool   InpAllowBuy        = true;        // Allow BUY trades
input bool   InpAllowSell       = true;        // Allow SELL trades
input int    InpEMAFast         = 9;           // Fast EMA Period
input int    InpEMASlow         = 21;          // Slow EMA Period
input int    InpRSIPeriod       = 14;          // RSI Period
input double InpRSIOverbought   = 70.0;        // RSI Overbought Level
input double InpRSIOversold     = 30.0;        // RSI Oversold Level
input int    InpMaxSpreadPoints = 30;          // Max Spread (points) to trade

input group "╔══════  DASHBOARD  ══════╗"
input bool   InpShowDash        = true;        // Show Dashboard
input int    InpDashX           = 14;          // Dashboard X Position
input int    InpDashY           = 14;          // Dashboard Y Position

//=======================================================================
//  CONSTANTS
//=======================================================================
const int    DW = 420;    // dashboard width
const int    DH = 620;    // dashboard height

//=======================================================================
//  GLOBALS
//=======================================================================
CTrade        g_trade;
CPositionInfo g_pos;
CAccountInfo  g_account;

int           g_emaFastH  = INVALID_HANDLE;
int           g_emaSlowH  = INVALID_HANDLE;
int           g_rsiH      = INVALID_HANDLE;

datetime      g_lastCloseTime  = 0;    // when the last trade closed
datetime      g_sessionDay     = 0;    // current session day start

// Session stats (rebuilt on restart from deal history)
int           g_sessTradesTotal  = 0;
int           g_sessTradesToday  = 0;
double        g_sessProfit       = 0.0;
int           g_sessWins         = 0;
int           g_sessLosses       = 0;
double        g_peakEquity       = 0.0;
double        g_drawdown         = 0.0;
int           g_totalTrades      = 0;

// Status strings for dashboard
string        g_statusText   = "STARTING";
color         g_statusColor  = C_ORANGE;
string        g_lastAction   = "Initializing...";
bool          g_inCooldown   = false;
int           g_cooldownLeft = 0;

//=======================================================================
//  FORWARD DECLARATIONS
//=======================================================================
void     RestoreSession();
void     BuildSessionStats();
bool     HasPosition();
bool     OpenTrade(ENUM_ORDER_TYPE otype);
void     CloseAllPositions();
double   GetFloatPL();
double   GetPositionOpenPrice();
ENUM_ORDER_TYPE GetPositionType();
ENUM_ORDER_TYPE GetMarketDirection();
bool     IsMarketOpen();
bool     IsWeekend();
bool     SpreadOK();
bool     DailyLimitsOK();
void     AdjustStops(double price, ENUM_ORDER_TYPE otype, double &sl, double &tp);
double   NPrice(double p);
ENUM_ORDER_TYPE_FILLING GetFillMode();
datetime DayStart(datetime ts);
string   P2(int v);
string   TimeHMS(int secs);
// Dashboard
void     InitDash();
void     UpdateDash();
void     DeleteDash();
void     R(string nm, int x, int y, int w, int h, color bg, color brd=clrNONE, int bw=1);
void     L(string nm, int x, int y, string txt, color clr, int fsz, string fnt="Arial Bold");
void     U(string nm, string txt, color clr);
void     Bar(string nm, int x, int y, int w, int h, double pct, color fg, color bg);
void     UpdBar(string nm, double pct, color fg);

//=======================================================================
//  OnInit
//=======================================================================
int OnInit()
{
   if(InpLotSize <= 0) { Alert("Lot size must be > 0"); return INIT_PARAMETERS_INCORRECT; }

   g_trade.SetExpertMagicNumber(InpMagicNumber);
   g_trade.SetDeviationInPoints(30);
   g_trade.SetTypeFilling(GetFillMode());
   g_trade.LogLevel(LOG_LEVEL_ALL);

   g_emaFastH = iMA(Symbol(), PERIOD_CURRENT, InpEMAFast, 0, MODE_EMA, PRICE_CLOSE);
   g_emaSlowH = iMA(Symbol(), PERIOD_CURRENT, InpEMASlow, 0, MODE_EMA, PRICE_CLOSE);
   g_rsiH     = iRSI(Symbol(), PERIOD_CURRENT, InpRSIPeriod, PRICE_CLOSE);

   if(g_emaFastH == INVALID_HANDLE || g_emaSlowH == INVALID_HANDLE || g_rsiH == INVALID_HANDLE)
   { Print("Indicator init failed. Error:", GetLastError()); return INIT_FAILED; }

   g_peakEquity  = AccountInfoDouble(ACCOUNT_EQUITY);
   g_sessionDay  = DayStart(TimeCurrent());

   RestoreSession();
   BuildSessionStats();

   if(InpShowDash) InitDash();

   EventSetTimer(1);

   Print("PHANTOM SCALPER PRO v3.0 | Magic:", InpMagicNumber,
         " | ", Symbol(), " | MaxTrades/Day:", InpMaxDailyTrades,
         " | ProfitTarget: $", InpProfitTargetUSD,
         " | Cooldown:", InpCooldownSec, "s");

   g_lastAction  = "EA Attached - Scanning...";
   g_statusText  = "SCANNING";
   g_statusColor = C_ORANGE;

   return INIT_SUCCEEDED;
}

//=======================================================================
//  OnDeinit
//=======================================================================
void OnDeinit(const int reason)
{
   EventKillTimer();
   DeleteDash();
   if(g_emaFastH != INVALID_HANDLE) IndicatorRelease(g_emaFastH);
   if(g_emaSlowH != INVALID_HANDLE) IndicatorRelease(g_emaSlowH);
   if(g_rsiH     != INVALID_HANDLE) IndicatorRelease(g_rsiH);
   Print("PHANTOM SCALPER PRO deinitialized. Reason:", reason);
}

//=======================================================================
//  OnTimer – 1s heartbeat
//=======================================================================
void OnTimer()
{
   // Update cooldown counter
   if(g_lastCloseTime > 0)
   {
      int elapsed = (int)(TimeCurrent() - g_lastCloseTime);
      g_inCooldown   = (elapsed < InpCooldownSec);
      g_cooldownLeft = g_inCooldown ? (InpCooldownSec - elapsed) : 0;
   }
   else
   {
      g_inCooldown   = false;
      g_cooldownLeft = 0;
   }

   // Update peak equity / drawdown
   double eq = AccountInfoDouble(ACCOUNT_EQUITY);
   if(eq > g_peakEquity) g_peakEquity = eq;
   if(g_peakEquity > 0)
      g_drawdown = (g_peakEquity - eq) / g_peakEquity * 100.0;

   BuildSessionStats();
   if(InpShowDash) UpdateDash();
}

//=======================================================================
//  OnTick – main execution engine
//=======================================================================
void OnTick()
{
   // --- Roll session if new day ---
   datetime todayStart = DayStart(TimeCurrent());
   if(todayStart != g_sessionDay)
   {
      g_sessionDay = todayStart;
      BuildSessionStats();
      g_lastAction = "New session started";
   }

   // --- Weekend guard ---
   if(IsWeekend() && !InpTradeWeekends)
   {
      g_statusText  = "WEEKEND";
      g_statusColor = C_MGRAY;
      return;
   }

   // --- Market open guard ---
   if(!IsMarketOpen())
   {
      g_statusText  = "MKT CLOSED";
      g_statusColor = C_RED;
      return;
   }

   // === POSITION MANAGEMENT (profit close) ===
   if(HasPosition())
   {
      double floatPL = GetFloatPL();
      if(floatPL >= InpProfitTargetUSD)
      {
         g_lastAction  = StringFormat("Profit $%.2f hit – closing", floatPL);
         Print("Profit target $", InpProfitTargetUSD, " hit | Float: $", floatPL, " – closing.");
         CloseAllPositions();
         g_lastCloseTime = TimeCurrent();
         g_inCooldown    = true;
         g_cooldownLeft  = InpCooldownSec;
         g_statusText    = "COOLDOWN";
         g_statusColor   = C_CYAN;
         BuildSessionStats();
         return;
      }
      g_statusText  = "IN TRADE";
      g_statusColor = C_GREEN;
      return;
   }

   // === COOLDOWN CHECK ===
   if(g_inCooldown)
   {
      g_statusText  = "COOLDOWN";
      g_statusColor = C_CYAN;
      return;
   }

   // === DAILY LIMITS CHECK ===
   if(!DailyLimitsOK())
   {
      g_statusText  = "LIMIT HIT";
      g_statusColor = C_RED;
      return;
   }

   // === SPREAD CHECK ===
   if(!SpreadOK())
   {
      g_statusText  = "HIGH SPREAD";
      g_statusColor = C_ORANGE;
      return;
   }

   // === GET DIRECTION ===
   ENUM_ORDER_TYPE dir = GetMarketDirection();

   if(dir == ORDER_TYPE_BUY  && !InpAllowBuy)  { g_statusText="NO BUY";  g_statusColor=C_ORANGE; return; }
   if(dir == ORDER_TYPE_SELL && !InpAllowSell) { g_statusText="NO SELL"; g_statusColor=C_ORANGE; return; }

   // === OPEN TRADE ===
   g_statusText  = "OPENING";
   g_statusColor = C_LBLUE;
   if(OpenTrade(dir))
   {
      g_statusText  = "IN TRADE";
      g_statusColor = C_GREEN;
      g_sessTradesToday++;
      g_totalTrades++;
      g_lastAction  = StringFormat("Opened %s @ %.5f",
                       (dir == ORDER_TYPE_BUY ? "BUY" : "SELL"),
                       SymbolInfoDouble(Symbol(), dir == ORDER_TYPE_BUY ? SYMBOL_ASK : SYMBOL_BID));
   }
   else
   {
      g_statusText  = "OPEN FAIL";
      g_statusColor = C_RED;
   }
}

//=======================================================================
//  OpenTrade
//=======================================================================
bool OpenTrade(ENUM_ORDER_TYPE otype)
{
   if(!TerminalInfoInteger(TERMINAL_TRADE_ALLOWED))
   { Print("AutoTrading disabled."); return false; }
   if(!MQLInfoInteger(MQL_TRADE_ALLOWED))
   { Print("EA trading not allowed."); return false; }

   double price = (otype == ORDER_TYPE_BUY)
                  ? SymbolInfoDouble(Symbol(), SYMBOL_ASK)
                  : SymbolInfoDouble(Symbol(), SYMBOL_BID);
   if(price <= 0.0) return false;

   double lotMin  = SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_MIN);
   double lotMax  = SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_MAX);
   double lotStep = SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_STEP);
   double lot     = MathMax(lotMin, MathMin(lotMax,
                    MathRound(InpLotSize / lotStep) * lotStep));

   double sl = 0.0, tp = 0.0;
   if(InpStopLossPct > 0.0)
   {
      sl = (otype == ORDER_TYPE_BUY)
           ? NPrice(price * (1.0 - InpStopLossPct  / 100.0))
           : NPrice(price * (1.0 + InpStopLossPct  / 100.0));
   }
   if(InpTakeProfitPct > 0.0)
   {
      tp = (otype == ORDER_TYPE_BUY)
           ? NPrice(price * (1.0 + InpTakeProfitPct / 100.0))
           : NPrice(price * (1.0 - InpTakeProfitPct / 100.0));
   }

   AdjustStops(price, otype, sl, tp);

   bool ok = (otype == ORDER_TYPE_BUY)
             ? g_trade.Buy (lot, Symbol(), price, sl, tp, InpBotName)
             : g_trade.Sell(lot, Symbol(), price, sl, tp, InpBotName);

   if(ok)
      Print("OpenTrade OK | ", EnumToString(otype),
            " | Ticket:", g_trade.ResultOrder(),
            " | Entry:", price, " SL:", sl, " TP:", tp);
   else
      Print("OpenTrade FAIL | Retcode:", g_trade.ResultRetcode(),
            " | ", g_trade.ResultRetcodeDescription());

   return ok;
}

//=======================================================================
//  GetMarketDirection  –  Dual-EMA crossover + RSI filter
//=======================================================================
ENUM_ORDER_TYPE GetMarketDirection()
{
   double emaF[2], emaS[2], rsi[1];
   if(CopyBuffer(g_emaFastH, 0, 0, 2, emaF) <= 0) return ORDER_TYPE_BUY;
   if(CopyBuffer(g_emaSlowH, 0, 0, 2, emaS) <= 0) return ORDER_TYPE_BUY;
   if(CopyBuffer(g_rsiH,     0, 0, 1, rsi)  <= 0) return ORDER_TYPE_BUY;

   bool emaUpNow  = emaF[0] > emaS[0];
   bool emaUpPrev = emaF[1] > emaS[1];

   // RSI confirmation
   bool rsiBullish = (rsi[0] > 50.0 && rsi[0] < InpRSIOverbought);
   bool rsiBearish = (rsi[0] < 50.0 && rsi[0] > InpRSIOversold);

   if(emaUpNow && rsiBullish)  return ORDER_TYPE_BUY;
   if(!emaUpNow && rsiBearish) return ORDER_TYPE_SELL;

   // Fall back to pure EMA bias
   return emaUpNow ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
}

//=======================================================================
//  CloseAllPositions
//=======================================================================
void CloseAllPositions()
{
   for(int i = PositionsTotal()-1; i >= 0; i--)
   {
      if(!g_pos.SelectByIndex(i)) continue;
      if(g_pos.Magic() != InpMagicNumber || g_pos.Symbol() != Symbol()) continue;
      if(g_trade.PositionClose(g_pos.Ticket()))
         Print("Closed ticket #", g_pos.Ticket());
      else
         Print("Close FAILED #", g_pos.Ticket(), " – ", g_trade.ResultRetcodeDescription());
   }
}

//=======================================================================
//  Utility helpers
//=======================================================================
bool HasPosition()
{
   for(int i = PositionsTotal()-1; i >= 0; i--)
   {
      if(!g_pos.SelectByIndex(i)) continue;
      if(g_pos.Magic() == InpMagicNumber && g_pos.Symbol() == Symbol()) return true;
   }
   return false;
}

double GetFloatPL()
{
   double t = 0;
   for(int i = PositionsTotal()-1; i >= 0; i--)
   {
      if(!g_pos.SelectByIndex(i)) continue;
      if(g_pos.Magic() == InpMagicNumber && g_pos.Symbol() == Symbol())
         t += g_pos.Profit() + g_pos.Swap() + g_pos.Commission();
   }
   return t;
}

double GetPositionOpenPrice()
{
   for(int i = PositionsTotal()-1; i >= 0; i--)
   {
      if(!g_pos.SelectByIndex(i)) continue;
      if(g_pos.Magic() == InpMagicNumber && g_pos.Symbol() == Symbol()) return g_pos.PriceOpen();
   }
   return 0.0;
}

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

bool IsMarketOpen()
{
   ENUM_SYMBOL_TRADE_MODE m = (ENUM_SYMBOL_TRADE_MODE)SymbolInfoInteger(Symbol(), SYMBOL_TRADE_MODE);
   return (m == SYMBOL_TRADE_MODE_FULL || m == SYMBOL_TRADE_MODE_LONGONLY || m == SYMBOL_TRADE_MODE_SHORTONLY);
}

bool IsWeekend()
{
   MqlDateTime dt; TimeToStruct(TimeCurrent(), dt);
   return (dt.day_of_week == 0 || dt.day_of_week == 6);
}

bool SpreadOK()
{
   if(InpMaxSpreadPoints <= 0) return true;
   return ((int)SymbolInfoInteger(Symbol(), SYMBOL_SPREAD) <= InpMaxSpreadPoints);
}

bool DailyLimitsOK()
{
   double bal = AccountInfoDouble(ACCOUNT_BALANCE);
   if(bal <= 0) return true;

   // Max daily trades
   if(InpMaxDailyTrades > 0 && g_sessTradesToday >= InpMaxDailyTrades) return false;

   // Max daily loss
   if(InpMaxDailyLossPct > 0.0 && g_sessProfit < -(bal * InpMaxDailyLossPct / 100.0)) return false;

   // Max daily profit
   if(InpMaxDailyProfitPct > 0.0 && g_sessProfit >= (bal * InpMaxDailyProfitPct / 100.0)) return false;

   return true;
}

void RestoreSession()
{
   datetime ds = DayStart(TimeCurrent());
   if(!HistorySelect(ds, TimeCurrent())) return;
   int total = HistoryDealsTotal();
   for(int i = 0; i < total; i++)
   {
      ulong tk = HistoryDealGetTicket(i);
      if(tk == 0) continue;
      if((ulong)HistoryDealGetInteger(tk, DEAL_MAGIC) != InpMagicNumber) continue;
      if(HistoryDealGetString(tk, DEAL_SYMBOL) != Symbol()) continue;
      if(HistoryDealGetInteger(tk, DEAL_ENTRY) == DEAL_ENTRY_IN)
      {
         g_sessTradesToday++;
         g_lastCloseTime = (datetime)HistoryDealGetInteger(tk, DEAL_TIME);
      }
   }
   Print("RestoreSession: ", g_sessTradesToday, " trades found today.");
}

void BuildSessionStats()
{
   g_sessProfit = 0.0; g_sessWins = 0; g_sessLosses = 0; g_sessTradesTotal = 0;
   datetime ds = DayStart(TimeCurrent());
   if(!HistorySelect(ds, TimeCurrent())) return;
   int total = HistoryDealsTotal();
   for(int i = 0; i < total; i++)
   {
      ulong tk = HistoryDealGetTicket(i);
      if(tk == 0) continue;
      if((ulong)HistoryDealGetInteger(tk, DEAL_MAGIC) != InpMagicNumber) continue;
      if(HistoryDealGetString(tk, DEAL_SYMBOL) != Symbol()) continue;
      long entry = HistoryDealGetInteger(tk, DEAL_ENTRY);
      if(entry == DEAL_ENTRY_IN)  { g_sessTradesTotal++; }
      else if(entry == DEAL_ENTRY_OUT)
      {
         double pnl = HistoryDealGetDouble(tk, DEAL_PROFIT)
                    + HistoryDealGetDouble(tk, DEAL_SWAP)
                    + HistoryDealGetDouble(tk, DEAL_COMMISSION);
         g_sessProfit += pnl;
         if(pnl >= 0) g_sessWins++; else g_sessLosses++;
      }
   }
}

void AdjustStops(double price, ENUM_ORDER_TYPE otype, double &sl, double &tp)
{
   int    stopsLevel = (int)SymbolInfoInteger(Symbol(), SYMBOL_TRADE_STOPS_LEVEL);
   double point      = SymbolInfoDouble(Symbol(), SYMBOL_POINT);
   double minDist    = stopsLevel * point;
   if(otype == ORDER_TYPE_BUY)
   {
      if(sl > 0.0 && (price - sl) < minDist) sl = NPrice(price - minDist);
      if(tp > 0.0 && (tp - price) < minDist) tp = NPrice(price + minDist);
   }
   else
   {
      if(sl > 0.0 && (sl - price) < minDist) sl = NPrice(price + minDist);
      if(tp > 0.0 && (price - tp) < minDist) tp = NPrice(price - minDist);
   }
}

double NPrice(double p)
{ return NormalizeDouble(p, (int)SymbolInfoInteger(Symbol(), SYMBOL_DIGITS)); }

ENUM_ORDER_TYPE_FILLING GetFillMode()
{
   uint f = (uint)SymbolInfoInteger(Symbol(), SYMBOL_FILLING_MODE);
   if((f & SYMBOL_FILLING_FOK) != 0) return ORDER_FILLING_FOK;
   if((f & SYMBOL_FILLING_IOC) != 0) return ORDER_FILLING_IOC;
   return ORDER_FILLING_RETURN;
}

datetime DayStart(datetime ts)
{
   MqlDateTime d; TimeToStruct(ts, d);
   return ts - (datetime)(d.hour*3600 + d.min*60 + d.sec);
}

string P2(int v) { return(v < 10 ? "0" : "") + IntegerToString(v); }

string TimeHMS(int secs)
{
   int h = secs / 3600, m = (secs % 3600) / 60, s = secs % 60;
   return P2(h) + ":" + P2(m) + ":" + P2(s);
}

//=======================================================================
//  DASHBOARD  –  build / update / delete
//=======================================================================
void R(string nm, int x, int y, int w, int h,
       color bg, color brd=clrNONE, int bw=1)
{
   string n = D + nm;
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
   else ObjectSetInteger(0, n, OBJPROP_BORDER_TYPE, BORDER_RAISED);
   ObjectSetInteger(0, n, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, n, OBJPROP_HIDDEN,     true);
   ObjectSetInteger(0, n, OBJPROP_BACK,       false);
   ObjectSetInteger(0, n, OBJPROP_ZORDER,     0);
}

void L(string nm, int x, int y, string txt, color clr, int fsz, string fnt="Arial Bold")
{
   string n = D + nm;
   if(ObjectFind(0, n) >= 0) ObjectDelete(0, n);
   ObjectCreate(0, n, OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, n, OBJPROP_CORNER,    CORNER_LEFT_UPPER);
   ObjectSetInteger(0, n, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, n, OBJPROP_YDISTANCE, y);
   ObjectSetString (0, n, OBJPROP_TEXT,      txt);
   ObjectSetInteger(0, n, OBJPROP_COLOR,     clr);
   ObjectSetInteger(0, n, OBJPROP_FONTSIZE,  fsz);
   ObjectSetString (0, n, OBJPROP_FONT,      fnt);
   ObjectSetInteger(0, n, OBJPROP_SELECTABLE,false);
   ObjectSetInteger(0, n, OBJPROP_HIDDEN,    true);
   ObjectSetInteger(0, n, OBJPROP_BACK,      false);
   ObjectSetInteger(0, n, OBJPROP_ZORDER,    1);
}

void U(string nm, string txt, color clr=C'220,225,240')
{
   string n = D + nm;
   if(ObjectFind(0, n) >= 0)
   {
      ObjectSetString (0, n, OBJPROP_TEXT,  txt);
      ObjectSetInteger(0, n, OBJPROP_COLOR, clr);
   }
}

// Progress-bar pair: bg + fill
void Bar(string nm, int x, int y, int w, int h, double pct, color fg, color bg_c)
{
   R(nm + "_bg", x, y, w, h, bg_c, C_BORDER, 1);
   int fw = (int)MathMax(2, MathRound(pct / 100.0 * (w - 2)));
   R(nm + "_fg", x+1, y+1, fw, h-2, fg, clrNONE);
}

void UpdBar(string nm, double pct, color fg)
{
   string n = D + nm + "_fg";
   string nb = D + nm + "_bg";
   int w = 0;
   if(ObjectFind(0, nb) >= 0) w = (int)ObjectGetInteger(0, nb, OBJPROP_XSIZE);
   if(w <= 0) return;
   int fw = (int)MathMax(2, MathRound(pct / 100.0 * (w - 2)));
   if(ObjectFind(0, n) >= 0)
   {
      ObjectSetInteger(0, n, OBJPROP_XSIZE,   fw);
      ObjectSetInteger(0, n, OBJPROP_BGCOLOR, fg);
   }
}

//+------------------------------------------------------------------+
//  InitDash – build all chart objects
//+------------------------------------------------------------------+
void InitDash()
{
   int X = InpDashX, Y = InpDashY;
   int cx = X + DW/2;   // centre X

   //================================================================
   //  OUTER FRAME
   //================================================================
   R("frame_outer", X,   Y,   DW,   DH,   C_BG0,   C_ACBORD,  2);
   R("frame_inner", X+2, Y+2, DW-4, DH-4, C_BG0,   C_BORDER,  1);

   //================================================================
   //  HEADER BAND
   //================================================================
   R("hdr_bg",  X+2,  Y+2,  DW-4, 80,  C_HDRBAR, C_BORDER, 1);
   // Accent line at top of header
   R("hdr_acc", X+2,  Y+2,  DW-4,  3,  C_ACBORD);

   // Bot name (big, centred)
   L("h_name",  X+10, Y+10, InpBotName,                  C_GOLD,  12, "Arial Black");
   L("h_tag",   X+10, Y+30, "Institutional HF Scalping Engine  |  24/5 Autonomous", C_CYAN, 7, "Arial");
   L("h_ver",   X+10, Y+44, "v3.0  +  Magic: " + IntegerToString((long)InpMagicNumber)
                             + "  +  " + Symbol(),        C_LBLUE,  7, "Arial");

   // LIVE badge
   R("live_bg", X+DW-80, Y+8, 64, 22, C_DKGREEN, C_GREEN, 1);
   L("live_lbl",X+DW-72, Y+12, "● LIVE",               C_GREEN,  7, "Arial Bold");

   // Divider
   R("div_hdr", X+2, Y+82, DW-4, 2, C_ACBORD);

   //================================================================
   //  STATUS PILL   (row Y+86)
   //================================================================
   R("stat_bg",  X+2,  Y+86, DW-4, 30,  C_BG2, C_BORDER, 1);
   L("lb_stat",  X+14, Y+93, "STATUS",                   C_SUBTEXT, 8, "Arial");
   L("vl_stat",  X+100,Y+93, "STARTING",                 C_ORANGE,  9, "Arial Black");
   L("lb_act",   X+220,Y+93, "Last action:",             C_SUBTEXT, 7, "Arial");
   L("vl_act",   X+300,Y+93, "--",                       C_WHITE,   7, "Arial");

   R("div_stat", X+2, Y+118, DW-4, 1, C_BORDER);

   //================================================================
   //  SECTION A  –  PERFORMANCE   Y+122
   //================================================================
   R("sec_a",   X+2,  Y+122, DW-4, 168, C_BG1, C_BORDER, 1);
   R("sec_a_hd",X+2,  Y+122, DW-4,  22, C_HDRBAR, C_BORDER, 1);
   L("sec_a_lb",X+10, Y+126, "▸  PERFORMANCE",           C_GOLD, 8, "Arial Black");
   R("div_a",   X+2,  Y+144, DW-4, 1,   C_BORDER);

   // 3-column layout: left Y value | centre % | right secondary
   // Row 1: Session Profit
   L("lb_sp",  X+14, Y+149, "Session Profit",         C_SUBTEXT, 8, "Arial");
   L("vl_sp",  X+200,Y+149, "$ 0.00",                 C_WHITE,   9, "Arial Bold");
   L("vl_sp2", X+320,Y+149, "Today",                  C_SUBTEXT, 7, "Arial");

   // Row 2: Floating P&L
   L("lb_fp",  X+14, Y+165, "Floating P&L",           C_SUBTEXT, 8, "Arial");
   L("vl_fp",  X+200,Y+165, "$ 0.00",                 C_WHITE,   9, "Arial Bold");

   // Row 3: Win/Loss
   L("lb_wl",  X+14, Y+181, "Win / Loss",             C_SUBTEXT, 8, "Arial");
   L("vl_wl",  X+200,Y+181, "0W / 0L",                C_WHITE,   9, "Arial Bold");

   // Row 4: Win Rate bar
   L("lb_wr",  X+14, Y+197, "Win Rate",               C_SUBTEXT, 8, "Arial");
   L("vl_wr",  X+200,Y+197, "0 %",                    C_WHITE,   9, "Arial Bold");
   Bar("wr_bar", X+280, Y+199, 130, 12, 0, C_GREEN, C_DGRAY);

   // Row 5: Drawdown bar
   L("lb_dd",  X+14, Y+213, "Drawdown",               C_SUBTEXT, 8, "Arial");
   L("vl_dd",  X+200,Y+213, "0.00 %",                 C_WHITE,   9, "Arial Bold");
   Bar("dd_bar", X+280, Y+215, 130, 12, 0, C_RED, C_DGRAY);

   // Row 6: Total trades today
   L("lb_tt",  X+14, Y+229, "Trades Today",           C_SUBTEXT, 8, "Arial");
   L("vl_tt",  X+200,Y+229, "0 / " + IntegerToString(InpMaxDailyTrades), C_WHITE, 9, "Arial Bold");
   Bar("tt_bar", X+280, Y+231, 130, 12, 0, C_LBLUE, C_DGRAY);

   R("div_a2", X+2, Y+292, DW-4, 1, C_BORDER);

   //================================================================
   //  SECTION B  –  ACCOUNT INFO   Y+296
   //================================================================
   R("sec_b",   X+2,  Y+296, DW-4, 106, C_BG1, C_BORDER, 1);
   R("sec_b_hd",X+2,  Y+296, DW-4,  22, C_HDRBAR, C_BORDER, 1);
   L("sec_b_lb",X+10, Y+300, "▸  ACCOUNT",             C_GOLD, 8, "Arial Black");
   R("div_b",   X+2,  Y+318, DW-4, 1,   C_BORDER);

   L("lb_bal",  X+14, Y+323, "Balance",                C_SUBTEXT, 8, "Arial");
   L("vl_bal",  X+200,Y+323, "$ 0.00",                 C_WHITE,   9, "Arial Bold");

   L("lb_eq",   X+14, Y+339, "Equity",                 C_SUBTEXT, 8, "Arial");
   L("vl_eq",   X+200,Y+339, "$ 0.00",                 C_WHITE,   9, "Arial Bold");

   L("lb_mg",   X+14, Y+355, "Free Margin",            C_SUBTEXT, 8, "Arial");
   L("vl_mg",   X+200,Y+355, "$ 0.00",                 C_WHITE,   9, "Arial Bold");

   L("lb_ml",   X+14, Y+371, "Margin Level",           C_SUBTEXT, 8, "Arial");
   L("vl_ml",   X+200,Y+371, "0.0 %",                  C_WHITE,   9, "Arial Bold");
   Bar("ml_bar", X+280, Y+373, 130, 12, 0, C_PURPLE, C_DGRAY);

   R("div_b2",  X+2, Y+404, DW-4, 1, C_BORDER);

   //================================================================
   //  SECTION C  –  MARKET STATUS   Y+408
   //================================================================
   R("sec_c",   X+2,  Y+408, DW-4, 130, C_BG1, C_BORDER, 1);
   R("sec_c_hd",X+2,  Y+408, DW-4,  22, C_HDRBAR, C_BORDER, 1);
   L("sec_c_lb",X+10, Y+412, "▸  MARKET STATUS",       C_GOLD, 8, "Arial Black");
   R("div_c",   X+2,  Y+430, DW-4, 1,   C_BORDER);

   L("lb_sym",  X+14, Y+435, "Symbol",                 C_SUBTEXT, 8, "Arial");
   L("vl_sym",  X+200,Y+435, Symbol(),                 C_CYAN,    9, "Arial Bold");

   L("lb_dir",  X+14, Y+451, "EMA Direction",          C_SUBTEXT, 8, "Arial");
   L("vl_dir",  X+200,Y+451, "--",                     C_WHITE,   9, "Arial Bold");

   L("lb_spr",  X+14, Y+467, "Spread",                 C_SUBTEXT, 8, "Arial");
   L("vl_spr",  X+200,Y+467, "0 pts",                  C_WHITE,   9, "Arial Bold");

   L("lb_pos",  X+14, Y+483, "Open Position",          C_SUBTEXT, 8, "Arial");
   L("vl_pos",  X+200,Y+483, "NONE",                   C_MGRAY,   9, "Arial Bold");

   L("lb_fl",   X+14, Y+499, "Float P&L",              C_SUBTEXT, 8, "Arial");
   L("vl_fl",   X+200,Y+499, "$ 0.00",                 C_WHITE,   9, "Arial Bold");

   L("lb_cd",   X+14, Y+515, "Cooldown",               C_SUBTEXT, 8, "Arial");
   L("vl_cd",   X+200,Y+515, "Ready",                  C_GREEN,   9, "Arial Bold");

   R("div_c2",  X+2, Y+540, DW-4, 1, C_BORDER);

   //================================================================
   //  SECTION D  –  CONFIG SUMMARY   Y+544
   //================================================================
   R("sec_d",   X+2,  Y+544, DW-4, 56,  C_BG2, C_BORDER, 1);
   L("cfg1",    X+14, Y+549, "Lot: " + DoubleToString(InpLotSize,2)
                              + "  |  Target: $" + DoubleToString(InpProfitTargetUSD,2)
                              + "  |  SL: " + DoubleToString(InpStopLossPct,1) + "%"
                              + "  |  TP: " + DoubleToString(InpTakeProfitPct,1) + "%",
                             C_LBLUE, 7, "Arial");
   L("cfg2",    X+14, Y+563, "Cooldown: " + IntegerToString(InpCooldownSec) + "s"
                              + "  |  Max Trades/Day: " + IntegerToString(InpMaxDailyTrades)
                              + "  |  Max Spread: " + IntegerToString(InpMaxSpreadPoints) + " pts",
                             C_LBLUE, 7, "Arial");

   R("div_d",   X+2, Y+600, DW-4, 1, C_BORDER);

   //================================================================
   //  FOOTER   Y+603
   //================================================================
   R("ftr",     X+2,  Y+603, DW-4, 15, C_HDRBAR, C_BORDER, 1);
   L("ft_time", X+10, Y+605, "Server: --:--",          C_MGRAY, 7, "Arial");
   L("ft_url",  X+DW-160, Y+605, "derivforge.com  |  PSP v3.0", C_DGRAY, 7, "Arial");

   ChartRedraw(0);
}

//+------------------------------------------------------------------+
//  UpdateDash – refresh all dynamic labels
//+------------------------------------------------------------------+
void UpdateDash()
{
   if(!InpShowDash) return;

   bool   hasPOS  = HasPosition();
   bool   mktOPN  = IsMarketOpen();
   double floatPL = GetFloatPL();
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double equity  = AccountInfoDouble(ACCOUNT_EQUITY);
   double freeMargin = AccountInfoDouble(ACCOUNT_MARGIN_FREE);
   double marginLevel = (AccountInfoDouble(ACCOUNT_MARGIN) > 0)
                        ? AccountInfoDouble(ACCOUNT_MARGIN_LEVEL)
                        : 0.0;
   int    spread  = (int)SymbolInfoInteger(Symbol(), SYMBOL_SPREAD);

   // STATUS
   U("vl_stat", g_statusText, g_statusColor);
   U("vl_act",  g_lastAction, C_SUBTEXT);

   // PERFORMANCE
   color spClr = (g_sessProfit >= 0) ? C_GREEN : C_RED;
   U("vl_sp", "$ " + DoubleToString(g_sessProfit, 2), spClr);

   color fpClr = (floatPL >= 0) ? C_GREEN : C_RED;
   U("vl_fp", "$ " + DoubleToString(floatPL, 2), fpClr);
   U("vl_fl", "$ " + DoubleToString(floatPL, 2), fpClr);

   int closed = g_sessWins + g_sessLosses;
   U("vl_wl", IntegerToString(g_sessWins) + "W / " + IntegerToString(g_sessLosses) + "L",
     (g_sessWins >= g_sessLosses) ? C_GREEN : C_RED);

   double wr = (closed > 0) ? ((double)g_sessWins / closed * 100.0) : 0.0;
   color  wrClr = (wr >= 55) ? C_GREEN : (wr >= 45 ? C_ORANGE : C_RED);
   U("vl_wr", DoubleToString(wr, 1) + " %", wrClr);
   UpdBar("wr_bar", wr, wrClr);

   U("vl_dd", DoubleToString(g_drawdown, 2) + " %",
     (g_drawdown < 5) ? C_GREEN : (g_drawdown < 15 ? C_ORANGE : C_RED));
   UpdBar("dd_bar", MathMin(g_drawdown * 5.0, 100.0),
          (g_drawdown < 5) ? C_GREEN : (g_drawdown < 15 ? C_ORANGE : C_RED));

   double tradePct = (InpMaxDailyTrades > 0)
                     ? ((double)g_sessTradesToday / InpMaxDailyTrades * 100.0) : 0.0;
   U("vl_tt", IntegerToString(g_sessTradesToday) + " / " + IntegerToString(InpMaxDailyTrades),
     (tradePct < 80) ? C_WHITE : C_ORANGE);
   UpdBar("tt_bar", MathMin(tradePct, 100.0), (tradePct < 80) ? C_LBLUE : C_ORANGE);

   // ACCOUNT
   U("vl_bal", "$ " + DoubleToString(balance, 2),     C_WHITE);
   U("vl_eq",  "$ " + DoubleToString(equity,  2),     (equity >= balance) ? C_GREEN : C_RED);
   U("vl_mg",  "$ " + DoubleToString(freeMargin, 2),  C_WHITE);
   double mlPct = MathMin(marginLevel / 10.0, 100.0);
   U("vl_ml",  DoubleToString(marginLevel, 1) + " %",
     (marginLevel > 500 || marginLevel == 0) ? C_GREEN :
     (marginLevel > 200 ? C_ORANGE : C_RED));
   UpdBar("ml_bar", mlPct,
     (marginLevel > 500 || marginLevel == 0) ? C_GREEN :
     (marginLevel > 200 ? C_ORANGE : C_RED));

   // MARKET STATUS
   if(g_emaFastH != INVALID_HANDLE)
   {
      ENUM_ORDER_TYPE d = GetMarketDirection();
      U("vl_dir", (d == ORDER_TYPE_BUY ? "BUY  ▲  (Bullish)" : "SELL  ▼  (Bearish)"),
        (d == ORDER_TYPE_BUY ? C_GREEN : C_RED));
   }

   int spr = spread;
   U("vl_spr", IntegerToString(spr) + " pts", (spr <= InpMaxSpreadPoints) ? C_GREEN : C_RED);

   if(hasPOS)
   {
      ENUM_ORDER_TYPE pt = GetPositionType();
      U("vl_pos", (pt == ORDER_TYPE_BUY ? "BUY  ▲" : "SELL  ▼"),
        (pt == ORDER_TYPE_BUY ? C_GREEN : C_RED));
   }
   else U("vl_pos", "NONE", C_MGRAY);

   if(g_inCooldown)
      U("vl_cd", "Wait " + IntegerToString(g_cooldownLeft) + "s", C_ORANGE);
   else
      U("vl_cd", "Ready", C_GREEN);

   // FOOTER
   U("ft_time",
     "Server: " + TimeToString(TimeCurrent(), TIME_SECONDS) +
     "  |  Local: " + TimeToString(TimeLocal(), TIME_MINUTES),
     C_DGRAY);

   ChartRedraw(0);
}

//+------------------------------------------------------------------+
void DeleteDash()
{
   ObjectsDeleteAll(0, D);
   ChartRedraw(0);
}
//+------------------------------------------------------------------+