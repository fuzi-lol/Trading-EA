//+------------------------------------------------------------------+
//|  THEE EliteScalper — MicroGrid Edition  v4.0                    |
//|  TREND FOLLOWING EDITION                                        |
//|  3-Layer Trend Engine:                                          |
//|    Layer 1 — H1  EMA200  (macro trend, master filter)           |
//|    Layer 2 — M15 EMA50   (swing trend confirmation)             |
//|    Layer 3 — M1  EMA8/21 + RSI (entry timing)                  |
//|  ALL 3 layers must agree. Zero counter-trend trades.            |
//+------------------------------------------------------------------+
#property copyright "THEE EliteScalper v4.0 — Trend Edition"
#property version   "4.00"
#property strict

#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>
#include <Trade\AccountInfo.mqh>

#define D "ES4_"

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
input ulong  InpMagic       = 20250609;
input string InpBotName     = "THEE EliteScalper";

input group "=== LOT & SCALING ==="
input double InpBaseLot     = 0.01;
input bool   InpLotScale    = true;
input bool   InpTPScale     = true;
input bool   InpCountScale  = true;

input group "=== RISK ==="
input double InpSLPips      = 15.0;   // SL in pips
input double InpMaxDayLoss  = 20.0;   // Max daily loss %
input double InpMaxDD       = 40.0;   // Circuit breaker %

input group "=== TREND FILTER (Higher Timeframes) ==="
input int    InpH1_EMA      = 200;    // H1 EMA period  (macro trend)
input int    InpM15_EMA     = 50;     // M15 EMA period (swing trend)
input bool   InpUseTrendFilter = true; // Enable 3-layer trend filter (RECOMMENDED: true)

input group "=== ENTRY SIGNAL (M1) ==="
input int    InpFastEMA     = 8;      // M1 Fast EMA
input int    InpSlowEMA     = 21;     // M1 Slow EMA
input int    InpRSI         = 14;     // RSI period
input double InpRSIBuy      = 52.0;   // RSI min for BUY  (relaxed from 55)
input double InpRSISell     = 48.0;   // RSI max for SELL (relaxed from 45)
input double InpMinEMADiff  = 1.5;    // Min M1 EMA diff in pips to confirm trend strength
input int    InpMaxSpread   = 80;     // Max spread in points

input group "=== TRADE MANAGEMENT ==="
input int    InpCooldown    = 20;     // Cooldown seconds after close
input bool   InpAllowBuy    = true;
input bool   InpAllowSell   = true;

input group "=== SYSTEM ==="
input bool   InpResetCumul  = false;
input bool   InpShowDash    = true;
input int    InpDashX       = 14;
input int    InpDashY       = 14;

//=======================================================================
//  DASHBOARD SIZE
//=======================================================================
const int DW = 450;
const int DH = 730;

//=======================================================================
//  GLOBALS
//=======================================================================
CTrade        g_trade;
CPositionInfo g_pos;
CAccountInfo  g_acct;

// M1 entry indicators
int g_fastH  = INVALID_HANDLE;
int g_slowH  = INVALID_HANDLE;
int g_rsiH   = INVALID_HANDLE;
// H1 macro trend
int g_h1EmaH = INVALID_HANDLE;
// M15 swing trend
int g_m15EmaH = INVALID_HANDLE;

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

// Trend state strings for dashboard
string g_trendH1     = "--";
string g_trendM15    = "--";
string g_trendM1     = "--";
color  g_trendH1Clr  = C_MGRAY;
color  g_trendM15Clr = C_MGRAY;
color  g_trendM1Clr  = C_MGRAY;

string GV_DAILY = "";
string GV_CUMUL = "ES4_CUMULATIVE";
string GV_OFF   = "ES4_DISABLED";

//=======================================================================
//  FORWARD DECLARATIONS
//=======================================================================
void   RestoreSession();
void   BuildStats();
int    CountPos();
void   OpenTrade(ENUM_ORDER_TYPE otype);
void   CloseAll(string reason);
void   CheckSoftTP();
double FloatPL();
int    GetTrendH1();      // +1 bullish, -1 bearish, 0 neutral
int    GetTrendM15();
int    GetTrendM1();
int    GetSignalDirection(); // final signal: +1 BUY, -1 SELL, 0 none
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

   // M1 entry indicators
   g_fastH   = iMA(_Symbol, PERIOD_M1,  InpFastEMA, 0, MODE_EMA, PRICE_CLOSE);
   g_slowH   = iMA(_Symbol, PERIOD_M1,  InpSlowEMA, 0, MODE_EMA, PRICE_CLOSE);
   g_rsiH    = iRSI(_Symbol, PERIOD_M1, InpRSI, PRICE_CLOSE);
   // Higher timeframe trend filters
   g_h1EmaH  = iMA(_Symbol, PERIOD_H1,  InpH1_EMA,  0, MODE_EMA, PRICE_CLOSE);
   g_m15EmaH = iMA(_Symbol, PERIOD_M15, InpM15_EMA, 0, MODE_EMA, PRICE_CLOSE);

   if(g_fastH==INVALID_HANDLE  || g_slowH==INVALID_HANDLE  || g_rsiH==INVALID_HANDLE ||
      g_h1EmaH==INVALID_HANDLE || g_m15EmaH==INVALID_HANDLE)
   { Print("Indicator init FAILED. Error:",GetLastError()); return INIT_FAILED; }

   g_peakEq  = AccountInfoDouble(ACCOUNT_EQUITY);
   g_sessDay = DayStart(TimeCurrent());

   if(InpResetCumul) GlobalVariableSet(GV_CUMUL, 0.0);
   if(!GlobalVariableCheck(GV_CUMUL)) GlobalVariableSet(GV_CUMUL, 0.0);
   if(GlobalVariableCheck(GV_OFF))    GlobalVariableSet(GV_OFF, 0);

   MqlDateTime t; TimeToStruct(TimeCurrent(),t);
   GV_DAILY = "ES4_DAILY_" + IntegerToString(t.day);
   if(!GlobalVariableCheck(GV_DAILY)) GlobalVariableSet(GV_DAILY, 0.0);

   RestoreSession();
   BuildStats();

   if(InpShowDash){ DeleteDash(); InitDash(); }
   EventSetTimer(1);

   g_status    = "SCANNING";
   g_statusClr = C_ORANGE;
   g_lastAct   = "EA started — 3-layer trend filter active";

   Print("THEE EliteScalper v4.0 | Magic:",InpMagic," | ",_Symbol,
         " | H1 EMA",InpH1_EMA," | M15 EMA",InpM15_EMA,
         " | M1 EMA(",InpFastEMA,"/",InpSlowEMA,") RSI",InpRSI,
         " | TrendFilter:",InpUseTrendFilter?"ON":"OFF");
   return INIT_SUCCEEDED;
}

//=======================================================================
//  OnDeinit
//=======================================================================
void OnDeinit(const int reason)
{
   EventKillTimer();
   DeleteDash();
   if(g_fastH  !=INVALID_HANDLE) IndicatorRelease(g_fastH);
   if(g_slowH  !=INVALID_HANDLE) IndicatorRelease(g_slowH);
   if(g_rsiH   !=INVALID_HANDLE) IndicatorRelease(g_rsiH);
   if(g_h1EmaH !=INVALID_HANDLE) IndicatorRelease(g_h1EmaH);
   if(g_m15EmaH!=INVALID_HANDLE) IndicatorRelease(g_m15EmaH);
}

//=======================================================================
//  OnTimer
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

   if(!SafeToTrade())   { if(InpShowDash) UpdateDash(); return; }
   if(g_cooldown)
   {
      g_status="COOLDOWN"; g_statusClr=C_CYAN;
      g_blockReason="Cooldown: "+IntegerToString(g_cdLeft)+"s";
      if(InpShowDash) UpdateDash(); return;
   }
   if(!SpreadOK())
   {
      g_status="HIGH SPREAD"; g_statusClr=C_ORANGE;
      g_blockReason="Spread "+IntegerToString((int)SymbolInfoInteger(_Symbol,SYMBOL_SPREAD))+" > "+IntegerToString(InpMaxSpread)+" pts";
      if(InpShowDash) UpdateDash(); return;
   }

   int tier = GetTier();
   int open = CountPos();
   int maxT = MaxTrades(tier);
   if(open >= maxT)
   {
      g_status="AT CAPACITY"; g_statusClr=C_GREEN;
      g_blockReason="Open: "+IntegerToString(open)+"/"+IntegerToString(maxT);
      if(InpShowDash) UpdateDash(); return;
   }

   // --- GET SIGNAL (new bar only to avoid spam opens) ---
   static datetime lastBar = 0;
   datetime curBar = iTime(_Symbol, PERIOD_M1, 0);
   bool     newBar = (curBar != lastBar);
   if(newBar) lastBar = curBar;

   int signal = GetSignalDirection();  // updates trend state globals too

   // Log every new bar
   if(newBar)
   {
      Print(StringFormat("[v4 SIGNAL] H1=%s M15=%s M1=%s | Result=%s | Open=%d/%d | Spread=%d",
            g_trendH1, g_trendM15, g_trendM1,
            signal==1?"BUY":signal==-1?"SELL":"NONE",
            open, maxT,
            (int)SymbolInfoInteger(_Symbol,SYMBOL_SPREAD)));
   }

   if(signal == 0)
   { if(InpShowDash) UpdateDash(); return; }

   // Signal confirmed — open trade
   g_blockReason = "";
   g_status      = "OPENING";
   g_statusClr   = C_LBLUE;
   OpenTrade(signal == 1 ? ORDER_TYPE_BUY : ORDER_TYPE_SELL);
   if(InpShowDash) UpdateDash();
}

//=======================================================================
//  LAYER 1 — H1 EMA200: macro trend
//  +1 = price above EMA200 on H1 (bull)
//  -1 = price below EMA200 on H1 (bear)
//=======================================================================
int GetTrendH1()
{
   double ema[1];
   if(CopyBuffer(g_h1EmaH, 0, 0, 1, ema) <= 0) return 0;
   double closeH1 = iClose(_Symbol, PERIOD_H1, 0);
   if(closeH1 <= 0) return 0;

   if(closeH1 > ema[0])
   {
      g_trendH1    = "BULL ▲";
      g_trendH1Clr = C_GREEN;
      return 1;
   }
   g_trendH1    = "BEAR ▼";
   g_trendH1Clr = C_RED;
   return -1;
}

//=======================================================================
//  LAYER 2 — M15 EMA50: swing trend
//  +1 = price above EMA50 AND EMA50 slope up
//  -1 = price below EMA50 AND EMA50 slope down
//=======================================================================
int GetTrendM15()
{
   double ema[3];  // need 3 bars to check slope
   if(CopyBuffer(g_m15EmaH, 0, 0, 3, ema) <= 0) return 0;
   double closeM15 = iClose(_Symbol, PERIOD_M15, 0);
   if(closeM15 <= 0) return 0;

   // ema[0] = current, ema[1] = 1 bar ago, ema[2] = 2 bars ago
   bool slopeUp   = (ema[0] > ema[1]) && (ema[1] > ema[2]);
   bool slopeDown = (ema[0] < ema[1]) && (ema[1] < ema[2]);
   bool aboveEMA  = (closeM15 > ema[0]);
   bool belowEMA  = (closeM15 < ema[0]);

   if(aboveEMA && slopeUp)
   {
      g_trendM15    = "BULL ▲";
      g_trendM15Clr = C_GREEN;
      return 1;
   }
   if(belowEMA && slopeDown)
   {
      g_trendM15    = "BEAR ▼";
      g_trendM15Clr = C_RED;
      return -1;
   }
   g_trendM15    = "MIXED ~";
   g_trendM15Clr = C_ORANGE;
   return 0;
}

//=======================================================================
//  LAYER 3 — M1 EMA8/21 + RSI: entry timing
//  +1 = EMA8 > EMA21, diff > MinEMADiff pips, RSI > InpRSIBuy
//  -1 = EMA8 < EMA21, diff > MinEMADiff pips, RSI < InpRSISell
//=======================================================================
int GetTrendM1()
{
   double fast[1], slow[1], rsi[1];
   if(CopyBuffer(g_fastH, 0, 0, 1, fast) <= 0) return 0;
   if(CopyBuffer(g_slowH, 0, 0, 1, slow) <= 0) return 0;
   if(CopyBuffer(g_rsiH,  0, 0, 1, rsi)  <= 0) return 0;

   double pip      = SymbolInfoDouble(_Symbol, SYMBOL_POINT) * 10.0;
   double emaDiff  = MathAbs(fast[0] - slow[0]);
   double diffPips = (pip > 0) ? emaDiff / pip : 0;

   // Require minimum EMA separation to avoid noise in sideways markets
   if(diffPips < InpMinEMADiff)
   {
      g_trendM1    = "WEAK ~";
      g_trendM1Clr = C_MGRAY;
      return 0;
   }

   bool bullM1 = (fast[0] > slow[0]) && (rsi[0] > InpRSIBuy);
   bool bearM1 = (fast[0] < slow[0]) && (rsi[0] < InpRSISell);

   if(bullM1)
   {
      g_trendM1    = "BULL ▲";
      g_trendM1Clr = C_GREEN;
      return 1;
   }
   if(bearM1)
   {
      g_trendM1    = "BEAR ▼";
      g_trendM1Clr = C_RED;
      return -1;
   }
   g_trendM1    = "WAIT ~";
   g_trendM1Clr = C_ORANGE;
   return 0;
}

//=======================================================================
//  FINAL SIGNAL — all 3 layers must agree
//  BUY:  H1=bull AND M15=bull AND M1=bull
//  SELL: H1=bear AND M15=bear AND M1=bear
//  Otherwise: NO TRADE
//=======================================================================
int GetSignalDirection()
{
   int h1  = GetTrendH1();
   int m15 = GetTrendM15();
   int m1  = GetTrendM1();

   if(!InpUseTrendFilter)
   {
      // Trend filter disabled — M1 only (not recommended)
      if(m1 == 1 && InpAllowBuy)  { g_blockReason=""; return 1; }
      if(m1 ==-1 && InpAllowSell) { g_blockReason=""; return -1; }
      g_blockReason = "M1: "+g_trendM1;
      g_status="SCANNING"; g_statusClr=C_ORANGE;
      return 0;
   }

   // All 3 must agree
   if(h1==1 && m15==1 && m1==1 && InpAllowBuy)
   {
      g_blockReason = "";
      g_status      = "BUY SIGNAL";
      g_statusClr   = C_GREEN;
      return 1;
   }
   if(h1==-1 && m15==-1 && m1==-1 && InpAllowSell)
   {
      g_blockReason = "";
      g_status      = "SELL SIGNAL";
      g_statusClr   = C_RED;
      return -1;
   }

   // Build informative block reason
   string why = "";
   if(h1 == 0)       why = "H1: neutral";
   else if(m15 == 0) why = "M15: mixed/neutral";
   else if(m1  == 0) why = "M1: "+g_trendM1;
   else if(h1 != m15)why = "H1 "+g_trendH1+" vs M15 "+g_trendM15+" — conflict";
   else if(m15!= m1) why = "M15 "+g_trendM15+" vs M1 "+g_trendM1+" — conflict";
   else               why = "Layers misaligned";

   g_blockReason = why;
   g_status      = "SCANNING";
   g_statusClr   = C_ORANGE;
   return 0;
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

   double lotMin  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double lotMax  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   lot = MathMax(lotMin, MathMin(lotMax, MathRound(lot/lotStep)*lotStep));

   double ask   = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid   = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double price = (otype==ORDER_TYPE_BUY) ? ask : bid;
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   double pip   = point * 10.0;

   double slDist  = InpSLPips * pip;
   double minStop = (double)((int)SymbolInfoInteger(_Symbol,SYMBOL_TRADE_STOPS_LEVEL)) * point;
   if(slDist < minStop * 1.5) slDist = minStop * 1.5;

   double sl = (otype==ORDER_TYPE_BUY) ? NP(price - slDist) : NP(price + slDist);

   // Broker TP from USD target
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
            tp = (otype==ORDER_TYPE_BUY) ? NP(price+tpDist) : NP(price-tpDist);
      }
   }

   string comment = InpBotName+"_T"+IntegerToString(tier)
                    +"_$"+DoubleToString(tpU,2)
                    +(otype==ORDER_TYPE_BUY?"_BUY":"_SELL");

   bool ok = (otype==ORDER_TYPE_BUY)
             ? g_trade.Buy (lot,_Symbol,price,sl,tp,comment)
             : g_trade.Sell(lot,_Symbol,price,sl,tp,comment);

   if(ok)
   {
      g_tradesToday++;
      g_status    = "IN TRADE";
      g_statusClr = (otype==ORDER_TYPE_BUY) ? C_GREEN : C_RED;
      g_lastAct   = StringFormat("%s %.2flot @ %.2f | SL:%.2f | TierTP:$%.2f | T%d",
                    (otype==ORDER_TYPE_BUY?"BUY":"SELL"), lot, price, sl, tpU, tier);
      Print("EliteScalper v4 OPENED | ",EnumToString(otype),
            " | Lot:",lot," @ ",price," SL:",sl," TP:",tp,
            " | TierTP:$",tpU," T",tier,
            " | H1:",g_trendH1," M15:",g_trendM15," M1:",g_trendM1,
            " | Ticket:",g_trade.ResultOrder());
   }
   else
   {
      g_status    = "OPEN FAIL";
      g_statusClr = C_RED;
      g_lastAct   = "FAIL: "+g_trade.ResultRetcodeDescription();
      Print("EliteScalper FAIL | ",g_trade.ResultRetcode()," | ",g_trade.ResultRetcodeDescription());
   }
}

//=======================================================================
//  CheckSoftTP
//=======================================================================
void CheckSoftTP()
{
   int    tier = GetTier();
   double tp   = TierTP(tier);

   for(int i=PositionsTotal()-1; i>=0; i--)
   {
      if(!g_pos.SelectByIndex(i)) continue;
      if(g_pos.Magic()!=InpMagic || g_pos.Symbol()!=_Symbol) continue;
      double pnl = g_pos.Profit()+g_pos.Swap()+g_pos.Commission();
      if(pnl >= tp)
      {
         if(g_trade.PositionClose(g_pos.Ticket(),50))
         {
            AddProfit(pnl);
            g_lastClose = TimeCurrent();
            g_cooldown  = true;
            g_cdLeft    = InpCooldown;
            g_status    = "COOLDOWN";
            g_statusClr = C_CYAN;
            g_lastAct   = StringFormat("Closed #%d P&L=$%.2f TP=$%.2f",(int)g_pos.Ticket(),pnl,tp);
            Print("EliteScalper CLOSED #",g_pos.Ticket()," pnl=",pnl," tierTP=",tp);
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
   Print("EliteScalper CloseAll: ",reason);
   for(int i=PositionsTotal()-1; i>=0; i--)
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
   if(GlobalVariableCheck(GV_OFF)&&GlobalVariableGet(GV_OFF)==1)
   { g_broken=true; g_status="CIRCUIT BREAK"; g_statusClr=C_RED;
     g_blockReason="Circuit breaker — remove EA to reset"; return false; }
   if(g_halted)
   { g_status="DAY HALTED"; g_statusClr=C_RED;
     g_blockReason="Daily loss limit — resumes tomorrow"; return false; }

   double bal = AccountInfoDouble(ACCOUNT_BALANCE);
   double eq  = AccountInfoDouble(ACCOUNT_EQUITY);

   if(InpMaxDayLoss>0 && bal>0 && g_sessProfit < -(bal*InpMaxDayLoss/100.0))
   {
      CloseAll("Daily loss halt");
      g_halted=true; g_status="DAY HALTED"; g_statusClr=C_RED;
      g_blockReason="Daily loss "+DoubleToString(InpMaxDayLoss,0)+"% triggered";
      return false;
   }
   if(InpMaxDD>0 && bal>0)
   {
      double dd=(bal-eq)/bal*100.0;
      if(dd>=InpMaxDD)
      {
         CloseAll("Circuit breaker");
         GlobalVariableSet(GV_OFF,1);
         g_broken=true; g_status="CIRCUIT BREAK"; g_statusClr=C_RED;
         Alert("THEE EliteScalper CIRCUIT BREAKER on ",_Symbol);
         return false;
      }
   }
   int spr=(int)SymbolInfoInteger(_Symbol,SYMBOL_SPREAD);
   if(spr>InpMaxSpread*3){ CloseAll("Emergency spread="+IntegerToString(spr)); return false; }
   return true;
}

//=======================================================================
//  DAY CHANGE
//=======================================================================
void CheckDay()
{
   datetime today=DayStart(TimeCurrent());
   if(today!=g_sessDay)
   {
      g_sessDay=today; g_halted=false;
      MqlDateTime t; TimeToStruct(TimeCurrent(),t);
      GV_DAILY="ES4_DAILY_"+IntegerToString(t.day);
      GlobalVariableSet(GV_DAILY,0.0);
      BuildStats();
      g_lastAct="New trading day";
   }
}

bool SpreadOK()
{ return (InpMaxSpread<=0) || ((int)SymbolInfoInteger(_Symbol,SYMBOL_SPREAD)<=InpMaxSpread); }

//=======================================================================
//  TIER ENGINE
//=======================================================================
int GetTier()
{
   double dp=DailyProfit();
   if(dp<=2.00) return 1; if(dp<=10.00) return 2;
   if(dp<=30.00) return 3; return 4;
}
string TierName(int t){ if(t==1)return"SEED"; if(t==2)return"GROWTH"; if(t==3)return"SCALE"; return"ELITE"; }
int MaxTrades(int t){ if(!InpCountScale)return 2; if(t==1)return 2; if(t==2)return 4; if(t==3)return 6; return 10; }
double TierTP(int t){ if(!InpTPScale)return 0.15; if(t==1)return 0.15; if(t==2)return 0.22; if(t==3)return 0.35; return 0.50; }
double CurrentLot()
{
   if(!InpLotScale) return InpBaseLot;
   double c=CumulProfit();
   if(c<100.0)return 0.01; if(c<300.0)return 0.02;
   if(c<600.0)return 0.03; if(c<1000.0)return 0.05; return 0.10;
}

//=======================================================================
//  PROFIT / STATS / UTILS
//=======================================================================
double DailyProfit(){ return GlobalVariableCheck(GV_DAILY)?GlobalVariableGet(GV_DAILY):0.0; }
double CumulProfit(){ return GlobalVariableCheck(GV_CUMUL)?GlobalVariableGet(GV_CUMUL):0.0; }
void   AddProfit(double v){ GlobalVariableSet(GV_DAILY,DailyProfit()+v); GlobalVariableSet(GV_CUMUL,CumulProfit()+v); }

int CountPos()
{
   int n=0;
   for(int i=PositionsTotal()-1;i>=0;i--)
   { if(!g_pos.SelectByIndex(i))continue; if(g_pos.Magic()==InpMagic&&g_pos.Symbol()==_Symbol)n++; }
   return n;
}

double FloatPL()
{
   double t=0;
   for(int i=PositionsTotal()-1;i>=0;i--)
   { if(!g_pos.SelectByIndex(i))continue; if(g_pos.Magic()==InpMagic&&g_pos.Symbol()==_Symbol) t+=g_pos.Profit()+g_pos.Swap()+g_pos.Commission(); }
   return t;
}

double NP(double p){ return NormalizeDouble(p,(int)SymbolInfoInteger(_Symbol,SYMBOL_DIGITS)); }

ENUM_ORDER_TYPE_FILLING FillMode()
{
   uint f=(uint)SymbolInfoInteger(_Symbol,SYMBOL_FILLING_MODE);
   if((f&SYMBOL_FILLING_FOK)!=0)return ORDER_FILLING_FOK;
   if((f&SYMBOL_FILLING_IOC)!=0)return ORDER_FILLING_IOC;
   return ORDER_FILLING_RETURN;
}

datetime DayStart(datetime ts){ MqlDateTime d; TimeToStruct(ts,d); return ts-(datetime)(d.hour*3600+d.min*60+d.sec); }

void RestoreSession()
{
   datetime ds=DayStart(TimeCurrent());
   if(!HistorySelect(ds,TimeCurrent()))return;
   for(int i=0;i<HistoryDealsTotal();i++)
   {
      ulong tk=HistoryDealGetTicket(i); if(!tk)continue;
      if((ulong)HistoryDealGetInteger(tk,DEAL_MAGIC)!=InpMagic)continue;
      if(HistoryDealGetString(tk,DEAL_SYMBOL)!=_Symbol)continue;
      if(HistoryDealGetInteger(tk,DEAL_ENTRY)==DEAL_ENTRY_IN)
      { g_tradesToday++; g_lastClose=(datetime)HistoryDealGetInteger(tk,DEAL_TIME); }
   }
}

void BuildStats()
{
   g_sessProfit=0; g_wins=0; g_losses=0;
   datetime ds=DayStart(TimeCurrent());
   if(!HistorySelect(ds,TimeCurrent()))return;
   for(int i=0;i<HistoryDealsTotal();i++)
   {
      ulong tk=HistoryDealGetTicket(i); if(!tk)continue;
      if((ulong)HistoryDealGetInteger(tk,DEAL_MAGIC)!=InpMagic)continue;
      if(HistoryDealGetString(tk,DEAL_SYMBOL)!=_Symbol)continue;
      if(HistoryDealGetInteger(tk,DEAL_ENTRY)==DEAL_ENTRY_OUT)
      {
         double pnl=HistoryDealGetDouble(tk,DEAL_PROFIT)+HistoryDealGetDouble(tk,DEAL_SWAP)+HistoryDealGetDouble(tk,DEAL_COMMISSION);
         g_sessProfit+=pnl; if(pnl>=0)g_wins++; else g_losses++;
      }
   }
}

//=======================================================================
//  DASHBOARD
//=======================================================================
void DR(string nm,int x,int y,int w,int h,color bg,color brd=clrNONE,int bw=1)
{
   string n=D+nm; if(ObjectFind(0,n)>=0)ObjectDelete(0,n);
   ObjectCreate(0,n,OBJ_RECTANGLE_LABEL,0,0,0);
   ObjectSetInteger(0,n,OBJPROP_CORNER,CORNER_LEFT_UPPER);
   ObjectSetInteger(0,n,OBJPROP_XDISTANCE,x); ObjectSetInteger(0,n,OBJPROP_YDISTANCE,y);
   ObjectSetInteger(0,n,OBJPROP_XSIZE,w);     ObjectSetInteger(0,n,OBJPROP_YSIZE,h);
   ObjectSetInteger(0,n,OBJPROP_BGCOLOR,bg);
   if(brd!=clrNONE){ObjectSetInteger(0,n,OBJPROP_BORDER_TYPE,BORDER_FLAT);ObjectSetInteger(0,n,OBJPROP_COLOR,brd);ObjectSetInteger(0,n,OBJPROP_WIDTH,bw);}
   else ObjectSetInteger(0,n,OBJPROP_BORDER_TYPE,BORDER_RAISED);
   ObjectSetInteger(0,n,OBJPROP_SELECTABLE,false); ObjectSetInteger(0,n,OBJPROP_HIDDEN,true);
   ObjectSetInteger(0,n,OBJPROP_BACK,false);        ObjectSetInteger(0,n,OBJPROP_ZORDER,0);
}

void DL(string nm,int x,int y,string txt,color clr,int fsz,string fnt="Arial Bold")
{
   string n=D+nm; if(ObjectFind(0,n)>=0)ObjectDelete(0,n);
   ObjectCreate(0,n,OBJ_LABEL,0,0,0);
   ObjectSetInteger(0,n,OBJPROP_CORNER,CORNER_LEFT_UPPER);
   ObjectSetInteger(0,n,OBJPROP_XDISTANCE,x); ObjectSetInteger(0,n,OBJPROP_YDISTANCE,y);
   ObjectSetString(0,n,OBJPROP_TEXT,txt);      ObjectSetInteger(0,n,OBJPROP_COLOR,clr);
   ObjectSetInteger(0,n,OBJPROP_FONTSIZE,fsz); ObjectSetString(0,n,OBJPROP_FONT,fnt);
   ObjectSetInteger(0,n,OBJPROP_SELECTABLE,false); ObjectSetInteger(0,n,OBJPROP_HIDDEN,true);
   ObjectSetInteger(0,n,OBJPROP_BACK,false);        ObjectSetInteger(0,n,OBJPROP_ZORDER,1);
}

void DU(string nm,string txt,color clr=C'220,225,240')
{
   string n=D+nm;
   if(ObjectFind(0,n)>=0){ObjectSetString(0,n,OBJPROP_TEXT,txt);ObjectSetInteger(0,n,OBJPROP_COLOR,clr);}
}

void DBar(string nm,int x,int y,int w,int h,double pct,color fg,color bg)
{
   DR(nm+"_bg",x,y,w,h,bg,C_BORDER,1);
   int fw=(int)MathMax(2,MathRound(pct/100.0*(w-2)));
   DR(nm+"_fg",x+1,y+1,fw,h-2,fg,clrNONE);
}

void DUpdBar(string nm,double pct,color fg)
{
   string n=D+nm+"_fg",nb=D+nm+"_bg"; int w=0;
   if(ObjectFind(0,nb)>=0) w=(int)ObjectGetInteger(0,nb,OBJPROP_XSIZE);
   if(w<=0)return;
   int fw=(int)MathMax(2,MathRound(pct/100.0*(w-2)));
   if(ObjectFind(0,n)>=0){ObjectSetInteger(0,n,OBJPROP_XSIZE,fw);ObjectSetInteger(0,n,OBJPROP_BGCOLOR,fg);}
}

void DeleteDash(){ ObjectsDeleteAll(0,D); ChartRedraw(0); }

void InitDash()
{
   int X=InpDashX, Y=InpDashY;

   DR("frame",X,Y,DW,DH,C_BG0,C_ACBORD,2);
   DR("inner",X+2,Y+2,DW-4,DH-4,C_BG0,C_BORDER,1);

   // Header
   DR("hdr",   X+2,Y+2,  DW-4,80,C_HDRBAR,C_BORDER,1);
   DR("hdrbar",X+2,Y+2,  DW-4, 3,C_ACBORD);
   DL("hname", X+10,Y+10,InpBotName,                               C_GOLD,13,"Arial Black");
   DL("htag",  X+10,Y+32,"MicroGrid v4.0  |  "+_Symbol+"  |  3-Layer Trend Engine",C_CYAN,7,"Arial");
   DL("hver",  X+10,Y+48,"H1(EMA"+IntegerToString(InpH1_EMA)+") + M15(EMA"+IntegerToString(InpM15_EMA)+") + M1(EMA"+IntegerToString(InpFastEMA)+"/"+IntegerToString(InpSlowEMA)+")",C_LBLUE,7,"Arial");
   DR("livebg",X+DW-85,Y+8,70,22,C_DKGRN,C_GREEN,1);
   DL("livetx",X+DW-78,Y+13,"● LIVE",C_GREEN,7);
   DR("hdrdv", X+2,Y+82,DW-4,2,C_ACBORD);

   // Status row
   DR("statbg",X+2,Y+86,DW-4,28,C_BG2,C_BORDER,1);
   DL("lbstat",X+14,Y+93,  "STATUS",   C_SUB,  8,"Arial");
   DL("vlstat",X+100,Y+93, "STARTING", C_ORANGE,9,"Arial Black");
   DL("lbact", X+210,Y+93, "Action:",  C_SUB,  7,"Arial");
   DL("vlact", X+265,Y+93, "--",       C_WHITE, 7,"Arial");
   DR("statdv",X+2,Y+116,DW-4,1,C_BORDER);

   // Block reason
   DR("blkbg", X+2,Y+119,DW-4,20,C_BG2,C_BORDER,1);
   DL("lbblk", X+14,Y+124,"Blocked:", C_SUB,  7,"Arial");
   DL("vlblk", X+80,Y+124,"—",        C_MGRAY, 7,"Arial");
   DR("blkdv", X+2,Y+141,DW-4,1,C_BORDER);

   // ===== 3-LAYER TREND SECTION =====
   DR("secT",  X+2,Y+144,DW-4,100,C_BG1,C_BORDER,1);
   DR("secThd",X+2,Y+144,DW-4, 22,C_HDRBAR,C_BORDER,1);
   DL("secTlb",X+10,Y+148,"▸  3-LAYER TREND ENGINE",C_GOLD,8,"Arial Black");
   DR("secTdv",X+2,Y+166,DW-4,1,C_BORDER);

   // H1 row
   DR("h1bg",  X+4, Y+170,DW-8,22,C_BG2,C_BORDER,1);
   DL("lbH1",  X+14,Y+175,"H1  EMA"+IntegerToString(InpH1_EMA)+" (Macro):",  C_SUB,8,"Arial");
   DL("vlH1",  X+220,Y+175,"--",C_MGRAY,9,"Arial Black");
   DL("lbH1d", X+310,Y+175,"Master trend filter",C_DGRAY,7,"Arial");

   // M15 row
   DR("m15bg", X+4, Y+194,DW-8,22,C_BG2,C_BORDER,1);
   DL("lbM15", X+14,Y+199,"M15 EMA"+IntegerToString(InpM15_EMA)+" (Swing):", C_SUB,8,"Arial");
   DL("vlM15", X+220,Y+199,"--",C_MGRAY,9,"Arial Black");
   DL("lbM15d",X+310,Y+199,"Swing confirmation",C_DGRAY,7,"Arial");

   // M1 row
   DR("m1bg",  X+4, Y+218,DW-8,22,C_BG2,C_BORDER,1);
   DL("lbM1",  X+14,Y+223,"M1  EMA"+IntegerToString(InpFastEMA)+"/"+IntegerToString(InpSlowEMA)+" (Entry):",C_SUB,8,"Arial");
   DL("vlM1",  X+220,Y+223,"--",C_MGRAY,9,"Arial Black");
   DL("lbM1d", X+310,Y+223,"Entry timing",C_DGRAY,7,"Arial");

   DR("secTdv2",X+2,Y+244,DW-4,1,C_BORDER);

   // Section A: Performance
   DR("secA",  X+2,Y+248,DW-4,168,C_BG1,C_BORDER,1);
   DR("secAhd",X+2,Y+248,DW-4, 22,C_HDRBAR,C_BORDER,1);
   DL("secAlb",X+10,Y+252,"▸  PERFORMANCE",C_GOLD,8,"Arial Black");
   DR("secAdv",X+2,Y+270,DW-4,1,C_BORDER);

   DL("lbdp",X+14,Y+275,"Daily Profit",  C_SUB,8,"Arial"); DL("vldp",X+225,Y+275,"$0.00",C_WHITE,9,"Arial Bold");
   DL("lbcp",X+14,Y+291,"Cumulative",    C_SUB,8,"Arial"); DL("vlcp",X+225,Y+291,"$0.00",C_WHITE,9,"Arial Bold");
   DL("lbfp",X+14,Y+307,"Floating P&L",  C_SUB,8,"Arial"); DL("vlfp",X+225,Y+307,"$0.00",C_WHITE,9,"Arial Bold");
   DL("lbwl",X+14,Y+323,"Win / Loss",    C_SUB,8,"Arial"); DL("vlwl",X+225,Y+323,"0W/0L",C_WHITE,9,"Arial Bold");
   DL("lbwr",X+14,Y+339,"Win Rate",      C_SUB,8,"Arial"); DL("vlwr",X+225,Y+339,"0%",   C_WHITE,9,"Arial Bold");
   DBar("wrbar",X+300,Y+341,138,11,0,C_GREEN,C_DGRAY);
   DL("lbdd",X+14,Y+355,"Drawdown",      C_SUB,8,"Arial"); DL("vldd",X+225,Y+355,"0%",   C_WHITE,9,"Arial Bold");
   DBar("ddbar",X+300,Y+357,138,11,0,C_RED,C_DGRAY);
   DL("lbtr",X+14,Y+371,"Trades Today",  C_SUB,8,"Arial"); DL("vltr",X+225,Y+371,"0",    C_WHITE,9,"Arial Bold");
   DR("secAdv2",X+2,Y+416,DW-4,1,C_BORDER);

   // Section B: Tier
   DR("secB",  X+2,Y+420,DW-4,108,C_BG1,C_BORDER,1);
   DR("secBhd",X+2,Y+420,DW-4, 22,C_HDRBAR,C_BORDER,1);
   DL("secBlb",X+10,Y+424,"▸  MICROGRID TIER ENGINE",C_GOLD,8,"Arial Black");
   DR("secBdv",X+2,Y+442,DW-4,1,C_BORDER);

   DL("lbtier",X+14,Y+447,"Active Tier",  C_SUB,8,"Arial"); DL("vltier",X+225,Y+447,"SEED",  C_PURPLE,9,"Arial Black");
   DL("lbop",  X+14,Y+463,"Open Trades",  C_SUB,8,"Arial"); DL("vlop",  X+225,Y+463,"0/2",   C_WHITE, 9,"Arial Bold");
   DBar("opbar",X+300,Y+465,138,11,0,C_PURPLE,C_DGRAY);
   DL("lblot", X+14,Y+479,"Lot Size",     C_SUB,8,"Arial"); DL("vllot", X+225,Y+479,"0.01",  C_WHITE, 9,"Arial Bold");
   DL("lbtp",  X+14,Y+495,"TP / Trade",   C_SUB,8,"Arial"); DL("vltp",  X+225,Y+495,"$0.15", C_CYAN,  9,"Arial Bold");
   DR("secBdv2",X+2,Y+528,DW-4,1,C_BORDER);

   // Section C: Account
   DR("secC",  X+2,Y+532,DW-4,90,C_BG1,C_BORDER,1);
   DR("secChd",X+2,Y+532,DW-4,22,C_HDRBAR,C_BORDER,1);
   DL("secClb",X+10,Y+536,"▸  ACCOUNT",C_GOLD,8,"Arial Black");
   DR("secCdv",X+2,Y+554,DW-4,1,C_BORDER);

   DL("lbbal",X+14,Y+559,"Balance",     C_SUB,8,"Arial"); DL("vlbal",X+225,Y+559,"$0.00",C_WHITE,9,"Arial Bold");
   DL("lbeq", X+14,Y+575,"Equity",      C_SUB,8,"Arial"); DL("vleq", X+225,Y+575,"$0.00",C_WHITE,9,"Arial Bold");
   DL("lbmg", X+14,Y+591,"Free Margin", C_SUB,8,"Arial"); DL("vlmg", X+225,Y+591,"$0.00",C_WHITE,9,"Arial Bold");
   DR("secCdv2",X+2,Y+622,DW-4,1,C_BORDER);

   // Section D: Market
   DR("secD",  X+2,Y+626,DW-4,60,C_BG1,C_BORDER,1);
   DR("secDhd",X+2,Y+626,DW-4,22,C_HDRBAR,C_BORDER,1);
   DL("secDlb",X+10,Y+630,"▸  MARKET",C_GOLD,8,"Arial Black");
   DR("secDdv",X+2,Y+648,DW-4,1,C_BORDER);

   DL("lbspr",X+14,Y+653,"Spread",   C_SUB,8,"Arial"); DL("vlspr",X+225,Y+653,"0 pts",C_WHITE,9,"Arial Bold");
   DL("lbcd", X+14,Y+669,"Cooldown", C_SUB,8,"Arial"); DL("vlcd", X+225,Y+669,"Ready",C_GREEN,9,"Arial Bold");
   DR("secDdv2",X+2,Y+686,DW-4,1,C_BORDER);

   // Footer
   DR("ftr",   X+2,Y+689,DW-4,18,C_HDRBAR,C_BORDER,1);
   DL("fttime",X+10,Y+692,"Server: --",                          C_MGRAY,7,"Arial");
   DL("fturl", X+DW-190,Y+692,"fxbothub.com  |  EliteScalper v4.0",C_DGRAY,7,"Arial");

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
   int    spr  = (int)SymbolInfoInteger(_Symbol,SYMBOL_SPREAD);

   DU("vlstat",g_status,     g_statusClr);
   DU("vlact", g_lastAct,    C_SUB);
   DU("vlblk", g_blockReason,C_ORANGE);

   // 3-layer trend indicators
   DU("vlH1",  g_trendH1,  g_trendH1Clr);
   DU("vlM15", g_trendM15, g_trendM15Clr);
   DU("vlM1",  g_trendM1,  g_trendM1Clr);

   // Performance
   DU("vldp","$ "+DoubleToString(dp,2),(dp>=0)?C_GREEN:C_RED);
   DU("vlcp","$ "+DoubleToString(cp,2),(cp>=0)?C_GREEN:C_RED);
   DU("vlfp","$ "+DoubleToString(fp,2),(fp>=0)?C_GREEN:C_RED);
   int cl=g_wins+g_losses;
   DU("vlwl",IntegerToString(g_wins)+"W / "+IntegerToString(g_losses)+"L",(g_wins>=g_losses)?C_GREEN:C_RED);
   double wr=(cl>0)?((double)g_wins/cl*100.0):0.0;
   color wrC=(wr>=55)?C_GREEN:(wr>=45?C_ORANGE:C_RED);
   DU("vlwr",DoubleToString(wr,1)+" %",wrC); DUpdBar("wrbar",wr,wrC);
   color ddC=(g_drawdown<5)?C_GREEN:(g_drawdown<15?C_ORANGE:C_RED);
   DU("vldd",DoubleToString(g_drawdown,2)+" %",ddC); DUpdBar("ddbar",MathMin(g_drawdown*5.0,100.0),ddC);
   DU("vltr",IntegerToString(g_tradesToday),C_WHITE);

   // Tier
   color tierC; switch(tier){case 1:tierC=C_LBLUE;break;case 2:tierC=C_GREEN;break;case 3:tierC=C_ORANGE;break;default:tierC=C_GOLD;}
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
   DU("vlspr",IntegerToString(spr)+" pts",(spr<=InpMaxSpread)?C_GREEN:C_RED);
   DU("vlcd", g_cooldown?"Wait "+IntegerToString(g_cdLeft)+"s":"Ready",g_cooldown?C_ORANGE:C_GREEN);

   DU("fttime","Server: "+TimeToString(TimeCurrent(),TIME_SECONDS)+"  Local: "+TimeToString(TimeLocal(),TIME_MINUTES),C_DGRAY);
   ChartRedraw(0);
}
//+------------------------------------------------------------------+
