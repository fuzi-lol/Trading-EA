//+------------------------------------------------------------------+
//|  THEE EliteScalper — MicroGrid Edition  v3.0                    |
//|  FIXED: Simple reliable signal that actually fires trades        |
//|  Signal: EMA8 > EMA21 + RSI > 55 = BUY                         |
//|          EMA8 < EMA21 + RSI < 45 = SELL                        |
//|  No GMT session filter | ATR gate removed | All on M1           |
//+------------------------------------------------------------------+
#property copyright "THEE EliteScalper v3.0"
#property version   "3.00"
#property strict

#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>
#include <Trade\AccountInfo.mqh>

#define D "ES3_"

//=======================================================================
//  COLOUR PALETTE
//=======================================================================
#define C_BG0    C'4,6,18'
#define C_BG1    C'8,12,28'
#define C_BG2    C'12,18,42'
#define C_HDRBAR C'10,16,38'
#define C_BORDER C'22,44,90'
#define C_ACBORD C'0,160,220'
#define C_GOLD   C'255,200,40'
#define C_CYAN   C'0,220,220'
#define C_PURPLE C'180,100,255'
#define C_WHITE  C'220,225,240'
#define C_SUB    C'110,130,160'
#define C_GREEN  C'20,220,110'
#define C_RED    C'230,55,65'
#define C_ORANGE C'255,145,0'
#define C_DKGRN  C'14,80,45'
#define C_LBLUE  C'80,160,255'
#define C_DGRAY  C'40,52,72'
#define C_MGRAY  C'75,90,115'

//=======================================================================
//  INPUTS
//=======================================================================
input group "=== IDENTITY ==="
input ulong  InpMagic      = 20250609;
input string InpBotName    = "THEE EliteScalper";

input group "=== LOT & SCALING ==="
input double InpBaseLot    = 0.01;  // Base lot size
input bool   InpLotScale   = true;  // Scale lot with cumulative profit
input bool   InpTPScale    = true;  // Scale TP target with tier
input bool   InpCountScale = true;  // Scale max trades with tier

input group "=== RISK ==="
input double InpSLPips     = 15.0;  // Stop loss pips (XAUUSD: 10-20 normal)
input double InpMaxDayLoss = 20.0;  // Max daily loss % of balance
input double InpMaxDD      = 40.0;  // Circuit breaker drawdown %

input group "=== SIGNAL ==="
input int    InpFastEMA    = 8;     // Fast EMA period
input int    InpSlowEMA    = 21;    // Slow EMA period
input int    InpRSI        = 14;    // RSI period
input double InpRSIBuy     = 55.0;  // RSI min for BUY  (above = bullish momentum)
input double InpRSISell    = 45.0;  // RSI max for SELL (below = bearish momentum)
input int    InpMaxSpread  = 80;    // Max spread in POINTS (80 = 8 pips for XAUUSD)

input group "=== TRADE MANAGEMENT ==="
input int    InpCooldown   = 30;    // Cooldown seconds after each close
input bool   InpAllowBuy   = true;
input bool   InpAllowSell  = true;

input group "=== SYSTEM ==="
input bool   InpResetCumul = false;
input bool   InpShowDash   = true;
input int    InpDashX      = 14;
input int    InpDashY      = 14;

//=======================================================================
//  DASHBOARD DIMENSIONS
//=======================================================================
const int DW = 440;
const int DH = 660;

//=======================================================================
//  GLOBALS
//=======================================================================
CTrade        g_trade;
CPositionInfo g_pos;
CAccountInfo  g_acct;

int g_fastH = INVALID_HANDLE;
int g_slowH = INVALID_HANDLE;
int g_rsiH  = INVALID_HANDLE;

datetime g_lastClose = 0;
datetime g_sessDay   = 0;
bool     g_cooldown  = false;
int      g_cdLeft    = 0;

int    g_tradesToday = 0;
double g_sessProfit  = 0.0;
int    g_wins        = 0;
int    g_losses      = 0;
double g_peakEq      = 0.0;
double g_drawdown    = 0.0;

bool   g_halted      = false;
bool   g_broken      = false;

string g_status      = "STARTING";
color  g_statusClr   = C_ORANGE;
string g_lastAct     = "Initializing...";
string g_blockReason = "";

string GV_DAILY = "";
string GV_CUMUL = "ES3_CUMULATIVE";
string GV_OFF   = "ES3_DISABLED";

//=======================================================================
//  FORWARD DECLARATIONS
//=======================================================================
void   RestoreSession();
void   BuildStats();
int    CountPos();
bool   HasPos();
void   OpenTrade(ENUM_ORDER_TYPE otype);
void   CloseAll(string reason);
void   CheckSoftTP();
double FloatPL();
ENUM_ORDER_TYPE GetDirection();
ENUM_ORDER_TYPE GetPosType();
bool   SafeToTrade();
void   CheckDay();
bool   SpreadOK();
int    GetTier();
string TierName(int t);
int    MaxTrades(int t);
double TierTP(int t);
double CurrentLot();
double DailyProfit();
double CumulProfit();
void   AddProfit(double v);
double NP(double p);
ENUM_ORDER_TYPE_FILLING FillMode();
datetime DayStart(datetime ts);
void   InitDash();
void   UpdateDash();
void   DeleteDash();
void   DR(string n,int x,int y,int w,int h,color bg,color brd=clrNONE,int bw=1);
void   DL(string n,int x,int y,string t,color c,int s,string f="Arial Bold");
void   DU(string n,string t,color c);
void   DBar(string n,int x,int y,int w,int h,double pct,color fg,color bg);
void   DUpdBar(string n,double pct,color fg);

//=======================================================================
//  OnInit
//=======================================================================
int OnInit()
{
   if(InpBaseLot <= 0){ Alert("Lot must be > 0"); return INIT_PARAMETERS_INCORRECT; }

   g_trade.SetExpertMagicNumber(InpMagic);
   g_trade.SetDeviationInPoints(50);
   g_trade.SetTypeFilling(FillMode());

   // All indicators on M1 — consistent, no cross-timeframe buffer issues
   g_fastH = iMA(_Symbol, PERIOD_M1, InpFastEMA, 0, MODE_EMA, PRICE_CLOSE);
   g_slowH = iMA(_Symbol, PERIOD_M1, InpSlowEMA, 0, MODE_EMA, PRICE_CLOSE);
   g_rsiH  = iRSI(_Symbol, PERIOD_M1, InpRSI, PRICE_CLOSE);

   if(g_fastH==INVALID_HANDLE||g_slowH==INVALID_HANDLE||g_rsiH==INVALID_HANDLE)
   { Print("Indicator init FAILED. Error:",GetLastError()); return INIT_FAILED; }

   g_peakEq  = AccountInfoDouble(ACCOUNT_EQUITY);
   g_sessDay = DayStart(TimeCurrent());

   if(InpResetCumul) GlobalVariableSet(GV_CUMUL, 0.0);
   if(!GlobalVariableCheck(GV_CUMUL)) GlobalVariableSet(GV_CUMUL, 0.0);
   if(GlobalVariableCheck(GV_OFF))    GlobalVariableSet(GV_OFF, 0);

   MqlDateTime t; TimeToStruct(TimeCurrent(),t);
   GV_DAILY = "ES3_DAILY_" + IntegerToString(t.day);
   if(!GlobalVariableCheck(GV_DAILY)) GlobalVariableSet(GV_DAILY, 0.0);

   RestoreSession();
   BuildStats();

   if(InpShowDash){ DeleteDash(); InitDash(); }

   EventSetTimer(1);

   g_status    = "SCANNING";
   g_statusClr = C_ORANGE;
   g_lastAct   = "EA started — scanning for signal...";

   Print("THEE EliteScalper v3.0 | Magic:",InpMagic," | ",_Symbol,
         " | EMA(",InpFastEMA,"/",InpSlowEMA,") RSI(",InpRSI,")",
         " | Buy>",InpRSIBuy," Sell<",InpRSISell,
         " | MaxSpread:",InpMaxSpread,"pts");
   return INIT_SUCCEEDED;
}

//=======================================================================
//  OnDeinit
//=======================================================================
void OnDeinit(const int reason)
{
   EventKillTimer();
   DeleteDash();
   if(g_fastH!=INVALID_HANDLE) IndicatorRelease(g_fastH);
   if(g_slowH!=INVALID_HANDLE) IndicatorRelease(g_slowH);
   if(g_rsiH !=INVALID_HANDLE) IndicatorRelease(g_rsiH);
}

//=======================================================================
//  OnTimer — 1s heartbeat
//=======================================================================
void OnTimer()
{
   if(g_lastClose > 0)
   {
      int elapsed = (int)(TimeCurrent() - g_lastClose);
      g_cooldown  = (elapsed < InpCooldown);
      g_cdLeft    = g_cooldown ? (InpCooldown - elapsed) : 0;
   }
   else { g_cooldown=false; g_cdLeft=0; }

   double eq = AccountInfoDouble(ACCOUNT_EQUITY);
   if(eq > g_peakEq) g_peakEq = eq;
   if(g_peakEq > 0)  g_drawdown = (g_peakEq - eq) / g_peakEq * 100.0;

   BuildStats();
   if(InpShowDash) UpdateDash();
}

//=======================================================================
//  OnTick — MAIN ENGINE
//=======================================================================
void OnTick()
{
   CheckDay();
   CheckSoftTP();

   // Safety checks
   if(!SafeToTrade())
   { if(InpShowDash) UpdateDash(); return; }

   // Cooldown
   if(g_cooldown)
   {
      g_status      = "COOLDOWN";
      g_statusClr   = C_CYAN;
      g_blockReason = "Cooldown: " + IntegerToString(g_cdLeft) + "s remaining";
      if(InpShowDash) UpdateDash();
      return;
   }

   // Spread check
   if(!SpreadOK())
   {
      g_status      = "HIGH SPREAD";
      g_statusClr   = C_ORANGE;
      g_blockReason = "Spread " + IntegerToString((int)SymbolInfoInteger(_Symbol,SYMBOL_SPREAD))
                      + " > max " + IntegerToString(InpMaxSpread) + " pts";
      if(InpShowDash) UpdateDash();
      return;
   }

   // Tier capacity
   int tier  = GetTier();
   int open  = CountPos();
   int maxT  = MaxTrades(tier);

   if(open >= maxT)
   {
      g_status      = "AT CAPACITY";
      g_statusClr   = C_GREEN;
      g_blockReason = "Max trades open: " + IntegerToString(open) + "/" + IntegerToString(maxT);
      if(InpShowDash) UpdateDash();
      return;
   }

   // -------------------------------------------------------
   //  SIGNAL — EMA position + RSI zone
   //  Runs every tick. No bar filter, no cross required.
   //  Fast > Slow AND RSI > InpRSIBuy  → BUY
   //  Fast < Slow AND RSI < InpRSISell → SELL
   // -------------------------------------------------------
   double fast[1], slow[1], rsi[1];
   if(CopyBuffer(g_fastH,0,0,1,fast) <= 0){ Print("EMA fast buffer error"); return; }
   if(CopyBuffer(g_slowH,0,0,1,slow) <= 0){ Print("EMA slow buffer error"); return; }
   if(CopyBuffer(g_rsiH, 0,0,1,rsi)  <= 0){ Print("RSI buffer error");      return; }

   bool buySignal  = (fast[0] > slow[0]) && (rsi[0] > InpRSIBuy)  && InpAllowBuy;
   bool sellSignal = (fast[0] < slow[0]) && (rsi[0] < InpRSISell) && InpAllowSell;

   // Log signal state once per bar (to journal, not every tick)
   static datetime lastLogBar = 0;
   datetime curBar = iTime(_Symbol, PERIOD_M1, 0);
   if(curBar != lastLogBar)
   {
      lastLogBar = curBar;
      Print(StringFormat("[SIGNAL] Fast=%.2f Slow=%.2f Diff=%+.2f | RSI=%.1f | BUY=%s SELL=%s | Open=%d/%d | Spread=%d",
            fast[0], slow[0], fast[0]-slow[0], rsi[0],
            buySignal?"YES":"no", sellSignal?"YES":"no",
            open, maxT,
            (int)SymbolInfoInteger(_Symbol,SYMBOL_SPREAD)));
   }

   if(!buySignal && !sellSignal)
   {
      g_blockReason = StringFormat("No signal | EMA diff:%+.1f | RSI:%.1f (need >%.0f or <%.0f)",
                                   fast[0]-slow[0], rsi[0], InpRSIBuy, InpRSISell);
      g_status    = "SCANNING";
      g_statusClr = C_ORANGE;
      if(InpShowDash) UpdateDash();
      return;
   }

   // Signal confirmed — open trade
   ENUM_ORDER_TYPE dir = buySignal ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
   g_blockReason = "";
   g_status      = "OPENING";
   g_statusClr   = C_LBLUE;
   OpenTrade(dir);
   if(InpShowDash) UpdateDash();
}

//=======================================================================
//  GetDirection — dashboard display only
//=======================================================================
ENUM_ORDER_TYPE GetDirection()
{
   double fast[1], slow[1];
   if(CopyBuffer(g_fastH,0,0,1,fast) <= 0) return ORDER_TYPE_BUY;
   if(CopyBuffer(g_slowH,0,0,1,slow) <= 0) return ORDER_TYPE_BUY;
   return (fast[0] > slow[0]) ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
}

//=======================================================================
//  OpenTrade
//=======================================================================
void OpenTrade(ENUM_ORDER_TYPE otype)
{
   if(!TerminalInfoInteger(TERMINAL_TRADE_ALLOWED)){ Print("AutoTrading disabled"); return; }
   if(!MQLInfoInteger(MQL_TRADE_ALLOWED))          { Print("EA trading not allowed"); return; }

   int    tier = GetTier();
   double lot  = CurrentLot();
   double tpU  = TierTP(tier);

   // Normalize lot to broker spec
   double lotMin  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double lotMax  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   lot = MathMax(lotMin, MathMin(lotMax, MathRound(lot/lotStep)*lotStep));

   double ask   = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid   = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double price = (otype == ORDER_TYPE_BUY) ? ask : bid;
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   double pip   = point * 10.0;

   // SL distance — pips converted to price
   double slDist = InpSLPips * pip;
   double minStop = (double)((int)SymbolInfoInteger(_Symbol,SYMBOL_TRADE_STOPS_LEVEL)) * point;
   if(slDist < minStop * 1.5) slDist = minStop * 1.5;

   double sl = (otype == ORDER_TYPE_BUY) ? NP(price - slDist) : NP(price + slDist);

   // Broker TP — calculate from USD target
   double tickVal  = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   double tp = 0;
   if(tickVal > 0 && tickSize > 0 && lot > 0)
   {
      double pipVal = (pip / tickSize) * tickVal * lot;
      if(pipVal > 0)
      {
         double tpPips = tpU / pipVal;
         double tpDist = tpPips * pip;
         if(tpDist > minStop)
            tp = (otype == ORDER_TYPE_BUY) ? NP(price + tpDist) : NP(price - tpDist);
      }
   }

   string comment = InpBotName + "_T" + IntegerToString(tier)
                    + "_$" + DoubleToString(tpU,2);

   bool ok = (otype == ORDER_TYPE_BUY)
             ? g_trade.Buy (lot, _Symbol, price, sl, tp, comment)
             : g_trade.Sell(lot, _Symbol, price, sl, tp, comment);

   if(ok)
   {
      g_tradesToday++;
      g_status    = "IN TRADE";
      g_statusClr = C_GREEN;
      g_lastAct   = StringFormat("%s %.2flot @ %.2f SL:%.2f TierTP:$%.2f",
                    (otype==ORDER_TYPE_BUY?"BUY":"SELL"), lot, price, sl, tpU);
      Print("EliteScalper OPENED | ", EnumToString(otype),
            " | Lot:", lot, " @ ", price,
            " SL:", sl, " TP:", tp,
            " | TierTP:$", tpU,
            " | Ticket:", g_trade.ResultOrder());
   }
   else
   {
      g_status    = "OPEN FAIL";
      g_statusClr = C_RED;
      g_lastAct   = "FAIL: " + g_trade.ResultRetcodeDescription();
      Print("EliteScalper OPEN FAIL | Code:", g_trade.ResultRetcode(),
            " | ", g_trade.ResultRetcodeDescription());
   }
}

//=======================================================================
//  CheckSoftTP — close each position when profit >= tier TP
//=======================================================================
void CheckSoftTP()
{
   int    tier = GetTier();
   double tp   = TierTP(tier);

   for(int i = PositionsTotal()-1; i >= 0; i--)
   {
      if(!g_pos.SelectByIndex(i)) continue;
      if(g_pos.Magic()  != InpMagic)  continue;
      if(g_pos.Symbol() != _Symbol)   continue;

      double pnl = g_pos.Profit() + g_pos.Swap() + g_pos.Commission();
      if(pnl >= tp)
      {
         if(g_trade.PositionClose(g_pos.Ticket(), 50))
         {
            AddProfit(pnl);
            g_lastClose = TimeCurrent();
            g_cooldown  = true;
            g_cdLeft    = InpCooldown;
            g_status    = "COOLDOWN";
            g_statusClr = C_CYAN;
            g_lastAct   = StringFormat("Closed #%d P&L=$%.2f | TP hit $%.2f",
                          (int)g_pos.Ticket(), pnl, tp);
            Print("EliteScalper CLOSED #", g_pos.Ticket(),
                  " pnl=", pnl, " tierTP=", tp);
            BuildStats();
         }
      }
   }
}

//=======================================================================
//  CloseAll
//=======================================================================
void CloseAll(string reason)
{
   Print("EliteScalper CloseAll: ", reason);
   for(int i = PositionsTotal()-1; i >= 0; i--)
   {
      if(!g_pos.SelectByIndex(i)) continue;
      if(g_pos.Magic()!=InpMagic || g_pos.Symbol()!=_Symbol) continue;
      g_trade.PositionClose(g_pos.Ticket());
   }
}

//=======================================================================
//  SafeToTrade
//=======================================================================
bool SafeToTrade()
{
   if(GlobalVariableCheck(GV_OFF) && GlobalVariableGet(GV_OFF)==1)
   {
      g_broken      = true;
      g_status      = "CIRCUIT BREAK";
      g_statusClr   = C_RED;
      g_blockReason = "Circuit breaker active — remove EA and reset";
      return false;
   }
   if(g_halted)
   {
      g_status      = "DAY HALTED";
      g_statusClr   = C_RED;
      g_blockReason = "Daily loss limit hit — resumes tomorrow";
      return false;
   }

   double bal = AccountInfoDouble(ACCOUNT_BALANCE);
   double eq  = AccountInfoDouble(ACCOUNT_EQUITY);

   // Daily loss halt
   if(InpMaxDayLoss > 0 && bal > 0 && g_sessProfit < -(bal * InpMaxDayLoss / 100.0))
   {
      CloseAll("Daily loss halt");
      g_halted      = true;
      g_status      = "DAY HALTED";
      g_statusClr   = C_RED;
      g_blockReason = "Daily loss " + DoubleToString(InpMaxDayLoss,0) + "% triggered";
      Print("EliteScalper: DAILY HALT");
      return false;
   }

   // Max drawdown circuit breaker
   if(InpMaxDD > 0 && bal > 0)
   {
      double dd = (bal - eq) / bal * 100.0;
      if(dd >= InpMaxDD)
      {
         CloseAll("Circuit breaker");
         GlobalVariableSet(GV_OFF, 1);
         g_broken      = true;
         g_status      = "CIRCUIT BREAK";
         g_statusClr   = C_RED;
         g_blockReason = "Drawdown " + DoubleToString(dd,1) + "% >= " + DoubleToString(InpMaxDD,0) + "%";
         Alert("THEE EliteScalper CIRCUIT BREAKER on ", _Symbol);
         return false;
      }
   }

   // Emergency spread close (3x limit)
   int spr = (int)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   if(spr > InpMaxSpread * 3)
   {
      CloseAll("Emergency spread=" + IntegerToString(spr));
      g_blockReason = "Emergency spread: " + IntegerToString(spr) + " pts";
      return false;
   }

   return true;
}

//=======================================================================
//  DAY CHANGE
//=======================================================================
void CheckDay()
{
   datetime today = DayStart(TimeCurrent());
   if(today != g_sessDay)
   {
      g_sessDay  = today;
      g_halted   = false;
      MqlDateTime t; TimeToStruct(TimeCurrent(), t);
      GV_DAILY = "ES3_DAILY_" + IntegerToString(t.day);
      GlobalVariableSet(GV_DAILY, 0.0);
      BuildStats();
      g_lastAct = "New trading day — stats reset";
   }
}

bool SpreadOK()
{
   if(InpMaxSpread <= 0) return true;
   return ((int)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD) <= InpMaxSpread);
}

//=======================================================================
//  TIER ENGINE
//=======================================================================
int GetTier()
{
   double dp = DailyProfit();
   if(dp <= 2.00)  return 1;
   if(dp <= 10.00) return 2;
   if(dp <= 30.00) return 3;
   return 4;
}

string TierName(int t)
{
   if(t==1) return "SEED";
   if(t==2) return "GROWTH";
   if(t==3) return "SCALE";
   return "ELITE";
}

int MaxTrades(int t)
{
   if(!InpCountScale) return 2;
   if(t==1) return 2;
   if(t==2) return 4;
   if(t==3) return 6;
   return 10;
}

double TierTP(int t)
{
   if(!InpTPScale) return 0.15;
   if(t==1) return 0.15;
   if(t==2) return 0.22;
   if(t==3) return 0.35;
   return 0.50;
}

double CurrentLot()
{
   if(!InpLotScale) return InpBaseLot;
   double c = CumulProfit();
   if(c < 100.0)  return 0.01;
   if(c < 300.0)  return 0.02;
   if(c < 600.0)  return 0.03;
   if(c < 1000.0) return 0.05;
   return 0.10;
}

//=======================================================================
//  PROFIT HELPERS
//=======================================================================
double DailyProfit()
{ return GlobalVariableCheck(GV_DAILY) ? GlobalVariableGet(GV_DAILY) : 0.0; }

double CumulProfit()
{ return GlobalVariableCheck(GV_CUMUL) ? GlobalVariableGet(GV_CUMUL) : 0.0; }

void AddProfit(double v)
{
   GlobalVariableSet(GV_DAILY, DailyProfit() + v);
   GlobalVariableSet(GV_CUMUL, CumulProfit() + v);
}

//=======================================================================
//  UTILITIES
//=======================================================================
int CountPos()
{
   int n = 0;
   for(int i=PositionsTotal()-1; i>=0; i--)
   {
      if(!g_pos.SelectByIndex(i)) continue;
      if(g_pos.Magic()==InpMagic && g_pos.Symbol()==_Symbol) n++;
   }
   return n;
}

bool HasPos() { return CountPos() > 0; }

double FloatPL()
{
   double t = 0;
   for(int i=PositionsTotal()-1; i>=0; i--)
   {
      if(!g_pos.SelectByIndex(i)) continue;
      if(g_pos.Magic()==InpMagic && g_pos.Symbol()==_Symbol)
         t += g_pos.Profit() + g_pos.Swap() + g_pos.Commission();
   }
   return t;
}

ENUM_ORDER_TYPE GetPosType()
{
   for(int i=PositionsTotal()-1; i>=0; i--)
   {
      if(!g_pos.SelectByIndex(i)) continue;
      if(g_pos.Magic()==InpMagic && g_pos.Symbol()==_Symbol)
         return (ENUM_ORDER_TYPE)g_pos.PositionType();
   }
   return ORDER_TYPE_BUY;
}

double NP(double p)
{ return NormalizeDouble(p, (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS)); }

ENUM_ORDER_TYPE_FILLING FillMode()
{
   uint f = (uint)SymbolInfoInteger(_Symbol, SYMBOL_FILLING_MODE);
   if((f & SYMBOL_FILLING_FOK) != 0) return ORDER_FILLING_FOK;
   if((f & SYMBOL_FILLING_IOC) != 0) return ORDER_FILLING_IOC;
   return ORDER_FILLING_RETURN;
}

datetime DayStart(datetime ts)
{
   MqlDateTime d; TimeToStruct(ts, d);
   return ts - (datetime)(d.hour*3600 + d.min*60 + d.sec);
}

void RestoreSession()
{
   datetime ds = DayStart(TimeCurrent());
   if(!HistorySelect(ds, TimeCurrent())) return;
   for(int i=0; i<HistoryDealsTotal(); i++)
   {
      ulong tk = HistoryDealGetTicket(i);
      if(!tk) continue;
      if((ulong)HistoryDealGetInteger(tk,DEAL_MAGIC) != InpMagic) continue;
      if(HistoryDealGetString(tk,DEAL_SYMBOL) != _Symbol)         continue;
      if(HistoryDealGetInteger(tk,DEAL_ENTRY) == DEAL_ENTRY_IN)
      { g_tradesToday++; g_lastClose=(datetime)HistoryDealGetInteger(tk,DEAL_TIME); }
   }
   Print("RestoreSession: ", g_tradesToday, " trades found today.");
}

void BuildStats()
{
   g_sessProfit=0; g_wins=0; g_losses=0;
   datetime ds = DayStart(TimeCurrent());
   if(!HistorySelect(ds, TimeCurrent())) return;
   for(int i=0; i<HistoryDealsTotal(); i++)
   {
      ulong tk = HistoryDealGetTicket(i);
      if(!tk) continue;
      if((ulong)HistoryDealGetInteger(tk,DEAL_MAGIC) != InpMagic) continue;
      if(HistoryDealGetString(tk,DEAL_SYMBOL) != _Symbol)         continue;
      if(HistoryDealGetInteger(tk,DEAL_ENTRY) == DEAL_ENTRY_OUT)
      {
         double pnl = HistoryDealGetDouble(tk,DEAL_PROFIT)
                    + HistoryDealGetDouble(tk,DEAL_SWAP)
                    + HistoryDealGetDouble(tk,DEAL_COMMISSION);
         g_sessProfit += pnl;
         if(pnl >= 0) g_wins++; else g_losses++;
      }
   }
}

//=======================================================================
//  DASHBOARD
//=======================================================================
void DR(string nm,int x,int y,int w,int h,color bg,color brd=clrNONE,int bw=1)
{
   string n=D+nm;
   if(ObjectFind(0,n)>=0) ObjectDelete(0,n);
   ObjectCreate(0,n,OBJ_RECTANGLE_LABEL,0,0,0);
   ObjectSetInteger(0,n,OBJPROP_CORNER,CORNER_LEFT_UPPER);
   ObjectSetInteger(0,n,OBJPROP_XDISTANCE,x);
   ObjectSetInteger(0,n,OBJPROP_YDISTANCE,y);
   ObjectSetInteger(0,n,OBJPROP_XSIZE,w);
   ObjectSetInteger(0,n,OBJPROP_YSIZE,h);
   ObjectSetInteger(0,n,OBJPROP_BGCOLOR,bg);
   if(brd!=clrNONE)
   { ObjectSetInteger(0,n,OBJPROP_BORDER_TYPE,BORDER_FLAT);
     ObjectSetInteger(0,n,OBJPROP_COLOR,brd);
     ObjectSetInteger(0,n,OBJPROP_WIDTH,bw); }
   else ObjectSetInteger(0,n,OBJPROP_BORDER_TYPE,BORDER_RAISED);
   ObjectSetInteger(0,n,OBJPROP_SELECTABLE,false);
   ObjectSetInteger(0,n,OBJPROP_HIDDEN,true);
   ObjectSetInteger(0,n,OBJPROP_BACK,false);
   ObjectSetInteger(0,n,OBJPROP_ZORDER,0);
}

void DL(string nm,int x,int y,string txt,color clr,int fsz,string fnt="Arial Bold")
{
   string n=D+nm;
   if(ObjectFind(0,n)>=0) ObjectDelete(0,n);
   ObjectCreate(0,n,OBJ_LABEL,0,0,0);
   ObjectSetInteger(0,n,OBJPROP_CORNER,CORNER_LEFT_UPPER);
   ObjectSetInteger(0,n,OBJPROP_XDISTANCE,x);
   ObjectSetInteger(0,n,OBJPROP_YDISTANCE,y);
   ObjectSetString(0,n,OBJPROP_TEXT,txt);
   ObjectSetInteger(0,n,OBJPROP_COLOR,clr);
   ObjectSetInteger(0,n,OBJPROP_FONTSIZE,fsz);
   ObjectSetString(0,n,OBJPROP_FONT,fnt);
   ObjectSetInteger(0,n,OBJPROP_SELECTABLE,false);
   ObjectSetInteger(0,n,OBJPROP_HIDDEN,true);
   ObjectSetInteger(0,n,OBJPROP_BACK,false);
   ObjectSetInteger(0,n,OBJPROP_ZORDER,1);
}

void DU(string nm,string txt,color clr=C'220,225,240')
{
   string n=D+nm;
   if(ObjectFind(0,n)>=0)
   { ObjectSetString(0,n,OBJPROP_TEXT,txt); ObjectSetInteger(0,n,OBJPROP_COLOR,clr); }
}

void DBar(string nm,int x,int y,int w,int h,double pct,color fg,color bg)
{
   DR(nm+"_bg",x,y,w,h,bg,C_BORDER,1);
   int fw=(int)MathMax(2,MathRound(pct/100.0*(w-2)));
   DR(nm+"_fg",x+1,y+1,fw,h-2,fg,clrNONE);
}

void DUpdBar(string nm,double pct,color fg)
{
   string n=D+nm+"_fg", nb=D+nm+"_bg";
   int w=0;
   if(ObjectFind(0,nb)>=0) w=(int)ObjectGetInteger(0,nb,OBJPROP_XSIZE);
   if(w<=0) return;
   int fw=(int)MathMax(2,MathRound(pct/100.0*(w-2)));
   if(ObjectFind(0,n)>=0)
   { ObjectSetInteger(0,n,OBJPROP_XSIZE,fw); ObjectSetInteger(0,n,OBJPROP_BGCOLOR,fg); }
}

void DeleteDash(){ ObjectsDeleteAll(0,D); ChartRedraw(0); }

void InitDash()
{
   int X=InpDashX, Y=InpDashY;

   // Outer frame
   DR("frame", X,   Y,   DW,   DH,   C_BG0,   C_ACBORD, 2);
   DR("inner", X+2, Y+2, DW-4, DH-4, C_BG0,   C_BORDER, 1);

   // Header
   DR("hdr",    X+2, Y+2,  DW-4, 80, C_HDRBAR, C_BORDER, 1);
   DR("hdrbar", X+2, Y+2,  DW-4,  3, C_ACBORD);
   DL("hname",  X+10, Y+10, InpBotName,  C_GOLD, 13, "Arial Black");
   DL("htag",   X+10, Y+32, "MicroGrid v3.0  |  "+_Symbol+"  |  EMA+RSI Scalper", C_CYAN, 7, "Arial");
   DL("hver",   X+10, Y+48, "Magic:"+IntegerToString((long)InpMagic)
                             +"  EMA("+IntegerToString(InpFastEMA)+"/"+IntegerToString(InpSlowEMA)
                             +")  RSI("+IntegerToString(InpRSI)+")",  C_LBLUE, 7, "Arial");
   DR("livebg", X+DW-85, Y+8, 70, 22, C_DKGRN, C_GREEN, 1);
   DL("livetx", X+DW-78, Y+13, "● LIVE", C_GREEN, 7);
   DR("hdrdiv", X+2, Y+82, DW-4, 2, C_ACBORD);

   // Status row
   DR("statbg", X+2, Y+86,  DW-4, 28, C_BG2, C_BORDER, 1);
   DL("lbstat", X+14, Y+93,  "STATUS",    C_SUB,   8, "Arial");
   DL("vlstat", X+100,Y+93,  "STARTING",  C_ORANGE, 9, "Arial Black");
   DL("lbact",  X+210,Y+93,  "Action:",   C_SUB,   7, "Arial");
   DL("vlact",  X+265,Y+93,  "--",        C_WHITE,  7, "Arial");
   DR("statdv", X+2, Y+116, DW-4, 1, C_BORDER);

   // Block reason row — KEY new feature: tells you WHY no trade
   DR("blkbg",  X+2, Y+119, DW-4, 20, C_BG2, C_BORDER, 1);
   DL("lbblk",  X+14,Y+124, "Blocked:",  C_SUB,  7, "Arial");
   DL("vlblk",  X+80,Y+124, "—",         C_MGRAY, 7, "Arial");
   DR("blkdv",  X+2, Y+141, DW-4, 1, C_BORDER);

   // Signal state row — live signal indicator
   DR("sigbg",  X+2, Y+144, DW-4, 22, C_BG2, C_BORDER, 1);
   DL("lbsig",  X+14, Y+150, "Signal:",   C_SUB,  7, "Arial");
   DL("vlsig",  X+75, Y+150, "--",        C_WHITE, 8, "Arial Bold");
   DL("lbema",  X+180,Y+150, "EMA diff:", C_SUB,  7, "Arial");
   DL("vlema",  X+255,Y+150, "--",        C_WHITE, 7, "Arial");
   DL("lbrsi",  X+325,Y+150, "RSI:",      C_SUB,  7, "Arial");
   DL("vlrsi",  X+360,Y+150, "--",        C_WHITE, 7, "Arial");
   DR("sigdv",  X+2, Y+168, DW-4, 1, C_BORDER);

   // Section A: Performance
   DR("seca",   X+2, Y+172, DW-4, 160, C_BG1, C_BORDER, 1);
   DR("secahd", X+2, Y+172, DW-4,  22, C_HDRBAR, C_BORDER, 1);
   DL("sealbA", X+10,Y+176, "▸  PERFORMANCE", C_GOLD, 8, "Arial Black");
   DR("secadv", X+2, Y+194, DW-4, 1, C_BORDER);

   DL("lbdp",X+14,Y+199,"Daily Profit",    C_SUB,8,"Arial"); DL("vldp",X+220,Y+199,"$0.00",C_WHITE,9,"Arial Bold");
   DL("lbcp",X+14,Y+215,"Cumulative",      C_SUB,8,"Arial"); DL("vlcp",X+220,Y+215,"$0.00",C_WHITE,9,"Arial Bold");
   DL("lbfp",X+14,Y+231,"Floating P&L",    C_SUB,8,"Arial"); DL("vlfp",X+220,Y+231,"$0.00",C_WHITE,9,"Arial Bold");
   DL("lbwl",X+14,Y+247,"Win / Loss",      C_SUB,8,"Arial"); DL("vlwl",X+220,Y+247,"0W/0L",C_WHITE,9,"Arial Bold");
   DL("lbwr",X+14,Y+263,"Win Rate",        C_SUB,8,"Arial"); DL("vlwr",X+220,Y+263,"0%",   C_WHITE,9,"Arial Bold");
   DBar("wrbar",X+295,Y+265,135,11,0,C_GREEN,C_DGRAY);
   DL("lbdd",X+14,Y+279,"Drawdown",        C_SUB,8,"Arial"); DL("vldd",X+220,Y+279,"0%",   C_WHITE,9,"Arial Bold");
   DBar("ddbar",X+295,Y+281,135,11,0,C_RED,C_DGRAY);
   DL("lbtr",X+14,Y+295,"Trades Today",    C_SUB,8,"Arial"); DL("vltr",X+220,Y+295,"0",    C_WHITE,9,"Arial Bold");
   DR("secadv2",X+2,Y+332,DW-4,1,C_BORDER);

   // Section B: Tier Engine
   DR("secb",   X+2, Y+336, DW-4, 108, C_BG1, C_BORDER, 1);
   DR("secbhd", X+2, Y+336, DW-4,  22, C_HDRBAR, C_BORDER, 1);
   DL("sealbB", X+10,Y+340, "▸  MICROGRID TIER ENGINE", C_GOLD, 8, "Arial Black");
   DR("secbdv", X+2, Y+358, DW-4, 1, C_BORDER);

   DL("lbtier",X+14,Y+363,"Active Tier",  C_SUB,8,"Arial"); DL("vltier",X+220,Y+363,"SEED",C_PURPLE,9,"Arial Black");
   DL("lbop",  X+14,Y+379,"Open Trades",  C_SUB,8,"Arial"); DL("vlop",  X+220,Y+379,"0/2", C_WHITE, 9,"Arial Bold");
   DBar("opbar",X+295,Y+381,135,11,0,C_PURPLE,C_DGRAY);
   DL("lblot", X+14,Y+395,"Lot Size",     C_SUB,8,"Arial"); DL("vllot", X+220,Y+395,"0.01",C_WHITE, 9,"Arial Bold");
   DL("lbtp",  X+14,Y+411,"TP / Trade",   C_SUB,8,"Arial"); DL("vltp",  X+220,Y+411,"$0.15",C_CYAN, 9,"Arial Bold");
   DR("secbdv2",X+2,Y+444,DW-4,1,C_BORDER);

   // Section C: Account
   DR("secc",   X+2, Y+448, DW-4, 90, C_BG1, C_BORDER, 1);
   DR("secchd", X+2, Y+448, DW-4, 22, C_HDRBAR, C_BORDER, 1);
   DL("sealbC", X+10,Y+452, "▸  ACCOUNT", C_GOLD, 8, "Arial Black");
   DR("seccdv", X+2, Y+470, DW-4, 1, C_BORDER);

   DL("lbbal",X+14,Y+475,"Balance",    C_SUB,8,"Arial"); DL("vlbal",X+220,Y+475,"$0.00",C_WHITE,9,"Arial Bold");
   DL("lbeq", X+14,Y+491,"Equity",     C_SUB,8,"Arial"); DL("vleq", X+220,Y+491,"$0.00",C_WHITE,9,"Arial Bold");
   DL("lbmg", X+14,Y+507,"Free Margin",C_SUB,8,"Arial"); DL("vlmg", X+220,Y+507,"$0.00",C_WHITE,9,"Arial Bold");
   DR("seccdv2",X+2,Y+538,DW-4,1,C_BORDER);

   // Section D: Market
   DR("secd",   X+2, Y+542, DW-4, 76, C_BG1, C_BORDER, 1);
   DR("secdhd", X+2, Y+542, DW-4, 22, C_HDRBAR, C_BORDER, 1);
   DL("sealbD", X+10,Y+546, "▸  MARKET", C_GOLD, 8, "Arial Black");
   DR("secddv", X+2, Y+564, DW-4, 1, C_BORDER);

   DL("lbdir",X+14,Y+569,"Direction", C_SUB,8,"Arial"); DL("vldir",X+220,Y+569,"--",    C_WHITE,9,"Arial Bold");
   DL("lbspr",X+14,Y+585,"Spread",    C_SUB,8,"Arial"); DL("vlspr",X+220,Y+585,"0 pts", C_WHITE,9,"Arial Bold");
   DL("lbcd", X+14,Y+601,"Cooldown",  C_SUB,8,"Arial"); DL("vlcd", X+220,Y+601,"Ready", C_GREEN,9,"Arial Bold");
   DR("secddv2",X+2,Y+618,DW-4,1,C_BORDER);

   // Footer
   DR("ftr",    X+2, Y+621, DW-4, 18, C_HDRBAR, C_BORDER, 1);
   DL("fttime", X+10,Y+624, "Server: --",                           C_MGRAY, 7, "Arial");
   DL("fturl",  X+DW-185,Y+624, "fxbothub.com  |  EliteScalper v3.0", C_DGRAY, 7, "Arial");

   ChartRedraw(0);
}

void UpdateDash()
{
   if(!InpShowDash) return;

   int    tier = GetTier();
   int    open = CountPos();
   int    maxT = MaxTrades(tier);
   double lot  = CurrentLot();
   double tp   = TierTP(tier);
   double dp   = DailyProfit();
   double cp   = CumulProfit();
   double fp   = FloatPL();
   double bal  = AccountInfoDouble(ACCOUNT_BALANCE);
   double eq   = AccountInfoDouble(ACCOUNT_EQUITY);
   double mg   = AccountInfoDouble(ACCOUNT_MARGIN_FREE);
   int    spr  = (int)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);

   // Signal state
   double fast[1], slow[1], rsi[1];
   bool gotSig = (CopyBuffer(g_fastH,0,0,1,fast)>0 &&
                  CopyBuffer(g_slowH,0,0,1,slow)>0 &&
                  CopyBuffer(g_rsiH, 0,0,1,rsi) >0);

   DU("vlstat", g_status,      g_statusClr);
   DU("vlact",  g_lastAct,     C_SUB);
   DU("vlblk",  g_blockReason, C_ORANGE);

   if(gotSig)
   {
      bool bs = (fast[0]>slow[0]) && (rsi[0]>InpRSIBuy);
      bool ss = (fast[0]<slow[0]) && (rsi[0]<InpRSISell);
      string sigTxt = bs ? "BUY ▲" : (ss ? "SELL ▼" : "NEUTRAL");
      color  sigClr = bs ? C_GREEN  : (ss ? C_RED   : C_MGRAY);
      DU("vlsig", sigTxt, sigClr);
      DU("vlema", DoubleToString(fast[0]-slow[0],2),
         (fast[0]>slow[0]) ? C_GREEN : C_RED);
      DU("vlrsi", DoubleToString(rsi[0],1),
         (rsi[0]>60)?C_GREEN:(rsi[0]<40?C_RED:C_ORANGE));
   }

   // Performance
   DU("vldp","$ "+DoubleToString(dp,2),(dp>=0)?C_GREEN:C_RED);
   DU("vlcp","$ "+DoubleToString(cp,2),(cp>=0)?C_GREEN:C_RED);
   DU("vlfp","$ "+DoubleToString(fp,2),(fp>=0)?C_GREEN:C_RED);

   int cl = g_wins+g_losses;
   DU("vlwl",IntegerToString(g_wins)+"W / "+IntegerToString(g_losses)+"L",
      (g_wins>=g_losses)?C_GREEN:C_RED);
   double wr = (cl>0)?((double)g_wins/cl*100.0):0.0;
   color wrC = (wr>=55)?C_GREEN:(wr>=45?C_ORANGE:C_RED);
   DU("vlwr",DoubleToString(wr,1)+" %",wrC);
   DUpdBar("wrbar",wr,wrC);
   color ddC = (g_drawdown<5)?C_GREEN:(g_drawdown<15?C_ORANGE:C_RED);
   DU("vldd",DoubleToString(g_drawdown,2)+" %",ddC);
   DUpdBar("ddbar",MathMin(g_drawdown*5.0,100.0),ddC);
   DU("vltr",IntegerToString(g_tradesToday),C_WHITE);

   // Tier engine
   color tierC;
   switch(tier)
   { case 1:tierC=C_LBLUE;break; case 2:tierC=C_GREEN;break;
     case 3:tierC=C_ORANGE;break; default:tierC=C_GOLD; }
   DU("vltier",TierName(tier),tierC);
   DU("vlop",IntegerToString(open)+" / "+IntegerToString(maxT),C_WHITE);
   DUpdBar("opbar",(maxT>0)?((double)open/maxT*100.0):0.0,tierC);
   DU("vllot",DoubleToString(lot,2),C_WHITE);
   DU("vltp","$ "+DoubleToString(tp,2),C_CYAN);

   // Account
   DU("vlbal","$ "+DoubleToString(bal,2),C_WHITE);
   DU("vleq", "$ "+DoubleToString(eq, 2),(eq>=bal)?C_GREEN:C_RED);
   DU("vlmg", "$ "+DoubleToString(mg, 2),C_WHITE);

   // Market
   ENUM_ORDER_TYPE d = GetDirection();
   DU("vldir",(d==ORDER_TYPE_BUY?"BUY ▲  Bullish":"SELL ▼  Bearish"),
      (d==ORDER_TYPE_BUY)?C_GREEN:C_RED);
   DU("vlspr",IntegerToString(spr)+" pts",(spr<=InpMaxSpread)?C_GREEN:C_RED);
   DU("vlcd", g_cooldown?"Wait "+IntegerToString(g_cdLeft)+"s":"Ready",
      g_cooldown?C_ORANGE:C_GREEN);

   DU("fttime","Server: "+TimeToString(TimeCurrent(),TIME_SECONDS)
               +"  Local: "+TimeToString(TimeLocal(),TIME_MINUTES), C_DGRAY);

   ChartRedraw(0);
}
//+------------------------------------------------------------------+
