//+------------------------------------------------------------------+
//| InstitutionalHFTScalperPro.mq5                                   |
//| Clean compile-ready MQL5 EA                                      |
//+------------------------------------------------------------------+
#property strict
#property version   "3.10"
#property description "Autonomous institutional-style scalper with dashboard, SL/TP, profit close/reopen, and daily limits."

#include <Trade/Trade.mqh>
#include <Trade/PositionInfo.mqh>

CTrade         trade;
CPositionInfo   pos;

//============================ INPUTS ===============================//
input group "General"
input ulong   InpMagicNumber        = 909090;
input double  InpLotSize            = 0.01;
input int     InpMaxTradesPerDay    = 20;
input bool    InpAutoStart          = true;
input bool    InpAllowBuy           = true;
input bool    InpAllowSell          = true;
input string  InpBotName            = "INSTITUTIONAL HFT SCALPER PRO";

input group "Profit Engine"
input double  InpProfitTargetMoney  = 1.00;
input double  InpProfitClosePct     = 0.30;
input int     InpReEntryDelaySec    = 60;

input group "Risk Management"
input double  InpStopLossPercent    = 0.80;
input double  InpTakeProfitPercent  = 1.50;
input int     InpMaxSpreadPoints    = 35;
input bool    InpUseDailyLossStop   = true;
input double  InpMaxDailyLossMoney  = 10.0;

input group "Market Filters"
input int     InpFastEMA            = 20;
input int     InpSlowEMA            = 50;
input int     InpATRPeriod          = 14;
input double  InpMinATR             = 0.0;

input group "Dashboard"
input bool    InpShowDashboard      = true;
input int     InpDashX              = 20;
input int     InpDashY              = 20;

//=========================== CONSTANTS =============================//
#define DASH_PREFIX "INST_HFT_"

// Palette
#define C_BG        C'8,12,22'
#define C_PANEL     C'15,20,36'
#define C_PANEL2    C'20,28,50'
#define C_BORDER    C'40,70,120'
#define C_ACCENT    C'0,170,220'
#define C_GOLD      C'255,198,32'
#define C_WHITE     C'230,235,245'
#define C_GREEN     C'30,220,120'
#define C_RED       C'220,60,60'
#define C_ORANGE    C'255,150,40'
#define C_BLUE      C'95,150,255'
#define C_GRAY      C'140,150,170'
#define C_DARKGRAY  C'80,90,110'

//============================ GLOBALS ==============================//
int      g_fastHandle = INVALID_HANDLE;
int      g_slowHandle = INVALID_HANDLE;
int      g_atrHandle  = INVALID_HANDLE;

datetime g_lastTradeTime     = 0;
datetime g_reentryAllowedAt  = 0;
datetime g_dayStart          = 0;
int      g_tradeCountToday   = 0;
int      g_totalReopens      = 0;
double   g_dayProfit         = 0.0;
int      g_wins              = 0;
int      g_losses            = 0;

//=========================== DECLARATIONS ===========================//
void   ResetDayIfNeeded();
void   RebuildDailyStats();
void   UpdateDashboard();
void   CreateDashboard();
void   DeleteDashboard();
void   CreatePanel(const string name,int x,int y,int w,int h,color bg,color border);
void   CreateText(const string name,const string text,int x,int y,color clr,int size,const string font="Arial");
void   SetText(const string name,const string text,color clr);
string Pad2(int v);
datetime Midnight(datetime t);
bool   IsMarketOpen();
int    SpreadPoints();
bool   HasOpenPosition();
void   CloseAllPositions();
double FloatingProfit();
double PositionOpenPrice();
ENUM_ORDER_TYPE PositionType();
ENUM_ORDER_TYPE DetectDirection();
bool   VolatilityValid();
void   ExecuteTrade(ENUM_ORDER_TYPE type);
void   ProfitManage();
double NormalizeVol(double vol);
void   AdjustStops(ENUM_ORDER_TYPE type,double entry,double &sl,double &tp);
double SessionProfitFromHistory();
int    SessionTradesFromHistory();
int    SessionWinsFromHistory();
int    SessionLossesFromHistory();

//============================== INIT ===============================//
int OnInit()
{
if(InpLotSize <= 0.0 || InpMaxTradesPerDay <= 0)
return INIT_PARAMETERS_INCORRECT;

trade.SetExpertMagicNumber(InpMagicNumber);
trade.SetDeviationInPoints(10);

g_fastHandle = iMA(Symbol(), PERIOD_CURRENT, InpFastEMA, 0, MODE_EMA, PRICE_CLOSE);
g_slowHandle = iMA(Symbol(), PERIOD_CURRENT, InpSlowEMA, 0, MODE_EMA, PRICE_CLOSE);
g_atrHandle  = iATR(Symbol(), PERIOD_CURRENT, InpATRPeriod);

if(g_fastHandle == INVALID_HANDLE || g_slowHandle == INVALID_HANDLE || g_atrHandle == INVALID_HANDLE)
{
Print("Indicator handle creation failed. Error: ", GetLastError());
return INIT_FAILED;
}

g_dayStart = Midnight(TimeCurrent());
RebuildDailyStats();

if(InpShowDashboard)
CreateDashboard();

EventSetTimer(1);
Print(InpBotName, " initialized on ", Symbol());
return INIT_SUCCEEDED;
}

//============================= DEINIT ===============================//
void OnDeinit(const int reason)
{
EventKillTimer();
DeleteDashboard();

if(g_fastHandle != INVALID_HANDLE) IndicatorRelease(g_fastHandle);
if(g_slowHandle != INVALID_HANDLE) IndicatorRelease(g_slowHandle);
if(g_atrHandle  != INVALID_HANDLE) IndicatorRelease(g_atrHandle);
}

//============================== TIMER ===============================//
void OnTimer()
{
ResetDayIfNeeded();
RebuildDailyStats();
if(InpShowDashboard)
UpdateDashboard();
}

//============================== TICK ================================//
void OnTick()
{
if(!InpAutoStart)
return;

ResetDayIfNeeded();

if(!IsMarketOpen())
return;

if(InpUseDailyLossStop && g_dayProfit <= -InpMaxDailyLossMoney)
return;

ProfitManage();

if(HasOpenPosition())
return;

if(g_tradeCountToday >= InpMaxTradesPerDay)
return;

if(TimeCurrent() < g_reentryAllowedAt)
return;

if(SpreadPoints() > InpMaxSpreadPoints)
return;

if(!VolatilityValid())
return;

ENUM_ORDER_TYPE dir = DetectDirection();
if(dir == ORDER_TYPE_BUY && !InpAllowBuy)
return;
if(dir == ORDER_TYPE_SELL && !InpAllowSell)
return;

ExecuteTrade(dir);
}

//=========================== TRADE LOGIC ============================//
void ProfitManage()
{
if(!HasOpenPosition())
return;

double openPrice = PositionOpenPrice();
if(openPrice <= 0.0)
return;

ENUM_ORDER_TYPE type = PositionType();
double price = (type == ORDER_TYPE_BUY)
? SymbolInfoDouble(Symbol(), SYMBOL_BID)
: SymbolInfoDouble(Symbol(), SYMBOL_ASK);
if(price <= 0.0)
return;

double movePct = 0.0;
if(type == ORDER_TYPE_BUY)
movePct = ((price - openPrice) / openPrice) * 100.0;
else
movePct = ((openPrice - price) / openPrice) * 100.0;

double floating = FloatingProfit();

if(floating >= InpProfitTargetMoney || movePct >= InpProfitClosePct)
{
CloseAllPositions();
g_totalReopens++;
g_reentryAllowedAt = TimeCurrent() + InpReEntryDelaySec;
}
}

void ExecuteTrade(ENUM_ORDER_TYPE type)
{
double lot = NormalizeVol(InpLotSize);
if(lot <= 0.0)
return;

double entry = (type == ORDER_TYPE_BUY)
? SymbolInfoDouble(Symbol(), SYMBOL_ASK)
: SymbolInfoDouble(Symbol(), SYMBOL_BID);
if(entry <= 0.0)
return;

double sl = 0.0;
double tp = 0.0;

if(InpStopLossPercent > 0.0)
{
if(type == ORDER_TYPE_BUY)
sl = entry * (1.0 - InpStopLossPercent / 100.0);
else
sl = entry * (1.0 + InpStopLossPercent / 100.0);
}

if(InpTakeProfitPercent > 0.0)
{
if(type == ORDER_TYPE_BUY)
tp = entry * (1.0 + InpTakeProfitPercent / 100.0);
else
tp = entry * (1.0 - InpTakeProfitPercent / 100.0);
}

AdjustStops(type, entry, sl, tp);

bool ok = false;
if(type == ORDER_TYPE_BUY)
ok = trade.Buy(lot, Symbol(), 0.0, sl, tp, InpBotName);
else
ok = trade.Sell(lot, Symbol(), 0.0, sl, tp, InpBotName);

if(ok)
{
g_tradeCountToday++;
g_lastTradeTime = TimeCurrent();
Print("Opened ", EnumToString(type), " lot=", DoubleToString(lot, 2), " sl=", sl, " tp=", tp);
}
else
{
Print("Order failed: ", trade.ResultRetcode(), " | ", trade.ResultRetcodeDescription());
}
}

ENUM_ORDER_TYPE DetectDirection()
{
double fast[2];
double slow[2];

if(CopyBuffer(g_fastHandle, 0, 0, 2, fast) <= 0)
return ORDER_TYPE_BUY;
if(CopyBuffer(g_slowHandle, 0, 0, 2, slow) <= 0)
return ORDER_TYPE_BUY;

if(fast[0] >= slow[0])
return ORDER_TYPE_BUY;

return ORDER_TYPE_SELL;
}

bool VolatilityValid()
{
if(g_atrHandle == INVALID_HANDLE)
return true;

if(InpMinATR <= 0.0)
return true;

double atr[1];
if(CopyBuffer(g_atrHandle, 0, 0, 1, atr) <= 0)
return false;

return atr[0] >= InpMinATR;
}

//=========================== POSITION OPS ===========================//
bool HasOpenPosition()
{
for(int i = PositionsTotal() - 1; i >= 0; --i)
{
if(!pos.SelectByIndex(i))
continue;
if(pos.Magic() == InpMagicNumber && pos.Symbol() == Symbol())
return true;
}
return false;
}

void CloseAllPositions()
{
for(int i = PositionsTotal() - 1; i >= 0; --i)
{
if(!pos.SelectByIndex(i))
continue;
if(pos.Magic() != InpMagicNumber || pos.Symbol() != Symbol())
continue;

```
  if(!trade.PositionClose(pos.Ticket()))
     Print("Close failed ticket=", pos.Ticket(), " | ", trade.ResultRetcodeDescription());
```

}
}

double FloatingProfit()
{
double total = 0.0;
for(int i = PositionsTotal() - 1; i >= 0; --i)
{
if(!pos.SelectByIndex(i))
continue;
if(pos.Magic() == InpMagicNumber && pos.Symbol() == Symbol())
total += pos.Profit() + pos.Swap() + pos.Commission();
}
return total;
}

double PositionOpenPrice()
{
for(int i = PositionsTotal() - 1; i >= 0; --i)
{
if(!pos.SelectByIndex(i))
continue;
if(pos.Magic() == InpMagicNumber && pos.Symbol() == Symbol())
return pos.PriceOpen();
}
return 0.0;
}

ENUM_ORDER_TYPE PositionType()
{
for(int i = PositionsTotal() - 1; i >= 0; --i)
{
if(!pos.SelectByIndex(i))
continue;
if(pos.Magic() == InpMagicNumber && pos.Symbol() == Symbol())
return (ENUM_ORDER_TYPE)pos.PositionType();
}
return ORDER_TYPE_BUY;
}

//=========================== MARKET OPS =============================//
bool IsMarketOpen()
{
ENUM_SYMBOL_TRADE_MODE mode = (ENUM_SYMBOL_TRADE_MODE)SymbolInfoInteger(Symbol(), SYMBOL_TRADE_MODE);
return (mode == SYMBOL_TRADE_MODE_FULL || mode == SYMBOL_TRADE_MODE_LONGONLY || mode == SYMBOL_TRADE_MODE_SHORTONLY);
}

int SpreadPoints()
{
return (int)SymbolInfoInteger(Symbol(), SYMBOL_SPREAD);
}

//=========================== DAILY STATS ============================//
datetime Midnight(datetime t)
{
MqlDateTime s;
TimeToStruct(t, s);
return t - (s.hour * 3600 + s.min * 60 + s.sec);
}

void ResetDayIfNeeded()
{
datetime nowMid = Midnight(TimeCurrent());
if(nowMid != g_dayStart)
{
g_dayStart = nowMid;
g_tradeCountToday = 0;
g_totalReopens = 0;
g_reentryAllowedAt = 0;
RebuildDailyStats();
}
}

void RebuildDailyStats()
{
g_dayProfit       = SessionProfitFromHistory();
g_tradeCountToday = SessionTradesFromHistory();
g_wins            = SessionWinsFromHistory();
g_losses          = SessionLossesFromHistory();
}

double SessionProfitFromHistory()
{
datetime from = g_dayStart;
datetime to   = TimeCurrent();
if(!HistorySelect(from, to))
return 0.0;

double sum = 0.0;
int total = HistoryDealsTotal();
for(int i = 0; i < total; ++i)
{
ulong ticket = HistoryDealGetTicket(i);
if(ticket == 0)
continue;
if((ulong)HistoryDealGetInteger(ticket, DEAL_MAGIC) != InpMagicNumber)
continue;
if(HistoryDealGetString(ticket, DEAL_SYMBOL) != Symbol())
continue;
if(HistoryDealGetInteger(ticket, DEAL_ENTRY) != DEAL_ENTRY_OUT)
continue;

```
  sum += HistoryDealGetDouble(ticket, DEAL_PROFIT)
       + HistoryDealGetDouble(ticket, DEAL_SWAP)
       + HistoryDealGetDouble(ticket, DEAL_COMMISSION);
```

}
return sum;
}

int SessionTradesFromHistory()
{
datetime from = g_dayStart;
datetime to   = TimeCurrent();
if(!HistorySelect(from, to))
return 0;

int count = 0;
int total = HistoryDealsTotal();
for(int i = 0; i < total; ++i)
{
ulong ticket = HistoryDealGetTicket(i);
if(ticket == 0)
continue;
if((ulong)HistoryDealGetInteger(ticket, DEAL_MAGIC) != InpMagicNumber)
continue;
if(HistoryDealGetString(ticket, DEAL_SYMBOL) != Symbol())
continue;
if(HistoryDealGetInteger(ticket, DEAL_ENTRY) == DEAL_ENTRY_IN)
count++;
}
return count;
}

int SessionWinsFromHistory()
{
datetime from = g_dayStart;
datetime to   = TimeCurrent();
if(!HistorySelect(from, to))
return 0;

int count = 0;
int total = HistoryDealsTotal();
for(int i = 0; i < total; ++i)
{
ulong ticket = HistoryDealGetTicket(i);
if(ticket == 0)
continue;
if((ulong)HistoryDealGetInteger(ticket, DEAL_MAGIC) != InpMagicNumber)
continue;
if(HistoryDealGetString(ticket, DEAL_SYMBOL) != Symbol())
continue;
if(HistoryDealGetInteger(ticket, DEAL_ENTRY) != DEAL_ENTRY_OUT)
continue;

```
  double p = HistoryDealGetDouble(ticket, DEAL_PROFIT)
           + HistoryDealGetDouble(ticket, DEAL_SWAP)
           + HistoryDealGetDouble(ticket, DEAL_COMMISSION);
  if(p >= 0.0)
     count++;
```

}
return count;
}

int SessionLossesFromHistory()
{
datetime from = g_dayStart;
datetime to   = TimeCurrent();
if(!HistorySelect(from, to))
return 0;

int count = 0;
int total = HistoryDealsTotal();
for(int i = 0; i < total; ++i)
{
ulong ticket = HistoryDealGetTicket(i);
if(ticket == 0)
continue;
if((ulong)HistoryDealGetInteger(ticket, DEAL_MAGIC) != InpMagicNumber)
continue;
if(HistoryDealGetString(ticket, DEAL_SYMBOL) != Symbol())
continue;
if(HistoryDealGetInteger(ticket, DEAL_ENTRY) != DEAL_ENTRY_OUT)
continue;

```
  double p = HistoryDealGetDouble(ticket, DEAL_PROFIT)
           + HistoryDealGetDouble(ticket, DEAL_SWAP)
           + HistoryDealGetDouble(ticket, DEAL_COMMISSION);
  if(p < 0.0)
     count++;
```

}
return count;
}

//=========================== NORMALIZATION =========================//
double NormalizeVol(double vol)
{
double minv = SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_MIN);
double maxv = SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_MAX);
double step = SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_STEP);

if(step <= 0.0)
step = 0.01;

vol = MathMax(minv, MathMin(maxv, vol));
vol = MathFloor(vol / step) * step;
return NormalizeDouble(vol, 2);
}

void AdjustStops(ENUM_ORDER_TYPE type,double entry,double &sl,double &tp)
{
int stopLevel = (int)SymbolInfoInteger(Symbol(), SYMBOL_TRADE_STOPS_LEVEL);
double point  = SymbolInfoDouble(Symbol(), SYMBOL_POINT);
double minDst  = stopLevel * point;

if(type == ORDER_TYPE_BUY)
{
if(sl > 0.0 && (entry - sl) < minDst) sl = entry - minDst;
if(tp > 0.0 && (tp - entry) < minDst) tp = entry + minDst;
}
else
{
if(sl > 0.0 && (sl - entry) < minDst) sl = entry + minDst;
if(tp > 0.0 && (entry - tp) < minDst) tp = entry - minDst;
}

sl = NormalizeDouble(sl, _Digits);
tp = NormalizeDouble(tp, _Digits);
}

//=========================== DASHBOARD =============================//
void CreatePanel(const string name,int x,int y,int w,int h,color bg,color border)
{
if(ObjectFind(0, name) >= 0)
ObjectDelete(0, name);

ObjectCreate(0, name, OBJ_RECTANGLE_LABEL, 0, 0, 0);
ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
ObjectSetInteger(0, name, OBJPROP_XSIZE, w);
ObjectSetInteger(0, name, OBJPROP_YSIZE, h);
ObjectSetInteger(0, name, OBJPROP_BGCOLOR, bg);
ObjectSetInteger(0, name, OBJPROP_COLOR, border);
ObjectSetInteger(0, name, OBJPROP_WIDTH, 1);
ObjectSetInteger(0, name, OBJPROP_BACK, false);
ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
}

void CreateText(const string name,const string text,int x,int y,color clr,int size,const string font)
{
if(ObjectFind(0, name) >= 0)
ObjectDelete(0, name);

ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
ObjectSetString(0, name, OBJPROP_TEXT, text);
ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
ObjectSetInteger(0, name, OBJPROP_FONTSIZE, size);
ObjectSetString(0, name, OBJPROP_FONT, font);
ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
}

void SetText(const string name,const string text,color clr)
{
if(ObjectFind(0, name) >= 0)
{
ObjectSetString(0, name, OBJPROP_TEXT, text);
ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
}
}

void CreateDashboard()
{
int X = InpDashX;
int Y = InpDashY;
int W = 460;
int H = 560;

CreatePanel(DASH_PREFIX + "MAIN", X, Y, W, H, C_BG, C_BORDER);
CreatePanel(DASH_PREFIX + "HEAD", X + 2, Y + 2, W - 4, 74, C_PANEL2, C_BORDER);
CreatePanel(DASH_PREFIX + "SEC1", X + 2, Y + 80, W - 4, 145, C_PANEL, C_BORDER);
CreatePanel(DASH_PREFIX + "SEC2", X + 2, Y + 229, W - 4, 150, C_PANEL, C_BORDER);
CreatePanel(DASH_PREFIX + "SEC3", X + 2, Y + 383, W - 4, 102, C_PANEL, C_BORDER);
CreatePanel(DASH_PREFIX + "FOOT", X + 2, Y + 490, W - 4, 66, C_PANEL2, C_BORDER);

CreateText(DASH_PREFIX + "TITLE", InpBotName, X + 16, Y + 12, C_GOLD, 14, "Arial Black");
CreateText(DASH_PREFIX + "SUB1", "AUTONOMOUS INSTITUTIONAL SCALPING ENGINE", X + 16, Y + 38, C_ACCENT, 9, "Arial");
CreateText(DASH_PREFIX + "SUB2", "24/5 LIVE SCAN | RAPID EXECUTION | MAGIC-ISOLATED", X + 16, Y + 55, C_GRAY, 8, "Arial");

CreateText(DASH_PREFIX + "S1", "PERFORMANCE", X + 16, Y + 86, C_GOLD, 10, "Arial Black");
CreateText(DASH_PREFIX + "L1", "Session Profit", X + 16, Y + 112, C_GRAY, 9, "Arial");
CreateText(DASH_PREFIX + "V1", "0.00", X + 270, Y + 112, C_WHITE, 9, "Arial Bold");
CreateText(DASH_PREFIX + "L2", "Floating P/L", X + 16, Y + 138, C_GRAY, 9, "Arial");
CreateText(DASH_PREFIX + "V2", "0.00", X + 270, Y + 138, C_WHITE, 9, "Arial Bold");
CreateText(DASH_PREFIX + "L3", "Trades Today", X + 16, Y + 164, C_GRAY, 9, "Arial");
CreateText(DASH_PREFIX + "V3", "0", X + 270, Y + 164, C_WHITE, 9, "Arial Bold");
CreateText(DASH_PREFIX + "L4", "Win Rate", X + 16, Y + 190, C_GRAY, 9, "Arial");
CreateText(DASH_PREFIX + "V4", "0%", X + 270, Y + 190, C_WHITE, 9, "Arial Bold");
CreateText(DASH_PREFIX + "L5", "Profit Reopens", X + 16, Y + 216, C_GRAY, 9, "Arial");
CreateText(DASH_PREFIX + "V5", "0", X + 270, Y + 216, C_ACCENT, 9, "Arial Bold");

CreateText(DASH_PREFIX + "S2", "TRADING STATUS", X + 16, Y + 235, C_GOLD, 10, "Arial Black");
CreateText(DASH_PREFIX + "L6", "Status", X + 16, Y + 261, C_GRAY, 9, "Arial");
CreateText(DASH_PREFIX + "V6", "SCANNING", X + 270, Y + 261, C_ORANGE, 9, "Arial Bold");
CreateText(DASH_PREFIX + "L7", "Symbol", X + 16, Y + 287, C_GRAY, 9, "Arial");
CreateText(DASH_PREFIX + "V7", Symbol(), X + 270, Y + 287, C_ACCENT, 9, "Arial Bold");
CreateText(DASH_PREFIX + "L8", "Direction", X + 16, Y + 313, C_GRAY, 9, "Arial");
CreateText(DASH_PREFIX + "V8", "--", X + 270, Y + 313, C_WHITE, 9, "Arial Bold");
CreateText(DASH_PREFIX + "L9", "Spread", X + 16, Y + 339, C_GRAY, 9, "Arial");
CreateText(DASH_PREFIX + "V9", "0", X + 270, Y + 339, C_WHITE, 9, "Arial Bold");
CreateText(DASH_PREFIX + "L10", "Market", X + 16, Y + 365, C_GRAY, 9, "Arial");
CreateText(DASH_PREFIX + "V10", "OPEN", X + 270, Y + 365, C_GREEN, 9, "Arial Bold");

CreateText(DASH_PREFIX + "S3", "SYSTEM INFO", X + 16, Y + 389, C_GOLD, 10, "Arial Black");
CreateText(DASH_PREFIX + "L11", "Magic Number", X + 16, Y + 415, C_GRAY, 9, "Arial");
CreateText(DASH_PREFIX + "V11", IntegerToString((long)InpMagicNumber), X + 270, Y + 415, C_BLUE, 9, "Arial Bold");
CreateText(DASH_PREFIX + "L12", "Daily Limit", X + 16, Y + 441, C_GRAY, 9, "Arial");
CreateText(DASH_PREFIX + "V12", IntegerToString(InpMaxTradesPerDay), X + 270, Y + 441, C_BLUE, 9, "Arial Bold");
CreateText(DASH_PREFIX + "L13", "SL / TP", X + 16, Y + 467, C_GRAY, 9, "Arial");
CreateText(DASH_PREFIX + "V13", DoubleToString(InpStopLossPercent, 2) + "% / " + DoubleToString(InpTakeProfitPercent, 2) + "%", X + 270, Y + 467, C_BLUE, 9, "Arial Bold");

CreateText(DASH_PREFIX + "F1", "Server: --:--", X + 16, Y + 516, C_DARKGRAY, 8, "Arial");
CreateText(DASH_PREFIX + "F2", "DBS PRO  |  HFT EDITION", X + 270, Y + 516, C_DARKGRAY, 8, "Arial");
}

void UpdateDashboard()
{
if(!InpShowDashboard)
return;

RebuildDailyStats();

double floating = FloatingProfit();
int winrate = (g_wins + g_losses > 0) ? (int)MathRound((double)g_wins / (g_wins + g_losses) * 100.0) : 0;
ENUM_ORDER_TYPE dir = DetectDirection();

SetText(DASH_PREFIX + "V1", DoubleToString(g_dayProfit, 2), (g_dayProfit >= 0.0 ? C_GREEN : C_RED));
SetText(DASH_PREFIX + "V2", DoubleToString(floating, 2), (floating >= 0.0 ? C_GREEN : C_RED));
SetText(DASH_PREFIX + "V3", IntegerToString(g_tradeCountToday), C_WHITE);
SetText(DASH_PREFIX + "V4", IntegerToString(winrate) + "%", (winrate >= 50 ? C_GREEN : C_RED));
SetText(DASH_PREFIX + "V5", IntegerToString(g_totalReopens), C_ACCENT);

if(HasOpenPosition())
SetText(DASH_PREFIX + "V6", "IN TRADE", C_GREEN);
else if(TimeCurrent() < g_reentryAllowedAt)
SetText(DASH_PREFIX + "V6", "WAITING RE-ENTRY", C_ORANGE);
else
SetText(DASH_PREFIX + "V6", "SCANNING", C_ORANGE);

SetText(DASH_PREFIX + "V8", (dir == ORDER_TYPE_BUY ? "BUY BIAS" : "SELL BIAS"), (dir == ORDER_TYPE_BUY ? C_GREEN : C_RED));
SetText(DASH_PREFIX + "V9", IntegerToString(SpreadPoints()), C_WHITE);
SetText(DASH_PREFIX + "V10", IsMarketOpen() ? "OPEN" : "CLOSED", IsMarketOpen() ? C_GREEN : C_RED);
SetText(DASH_PREFIX + "F1", "Server: " + TimeToString(TimeCurrent(), TIME_MINUTES), C_DARKGRAY);
}

void DeleteDashboard()
{
string names[] =
{
"MAIN","HEAD","SEC1","SEC2","SEC3","FOOT",
"TITLE","SUB1","SUB2",
"S1","L1","V1","L2","V2","L3","V3","L4","V4","L5","V5",
"S2","L6","V6","L7","V7","L8","V8","L9","V9","L10","V10",
"S3","L11","V11","L12","V12","L13","V13","F1","F2"
};

for(int i = 0; i < ArraySize(names); ++i)
ObjectDelete(0, DASH_PREFIX + names[i]);
}

//=========================== HELPERS ===============================//
string Pad2(int v)
{
return (v < 10 ? "0" : "") + IntegerToString(v);
}

//+------------------------------------------------------------------+
