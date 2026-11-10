//+------------------------------------------------------------------+
//|              PHANTOM SCALPER PRO  –  Institutional Edition       |
//|              v3.5  |  24/5 Autonomous HF Crypto Scalper          |
//|              Optimized for BTCUSD & Micro-Accounts ($5+)         |
//+------------------------------------------------------------------+
#property copyright   "PHANTOM SCALPER PRO v3.5"
#property version     "3.50"
#property description "Institutional crypto scalper featuring Micro-Account protection & ATR volatility filtering"

#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>
#include <Trade\AccountInfo.mqh>

//--- Dashboard namespace prefix
#define D "PSP_"

//=======================================================================
//  COLOUR PALETTE  –  Deep-space luxury fintech
//=======================================================================
#define C_BG0       C'4,6,18'        
#define C_BG1       C'8,12,28'       
#define C_BG2       C'12,18,42'      
#define C_HDRBAR    C'10,16,38'      
#define C_BORDER    C'22,44,90'      
#define C_ACBORD    C'0,160,220'     
#define C_ACBORD2   C'160,80,255'    
#define C_GOLD      C'255,200,40'    
#define C_CYAN      C'0,220,220'     
#define C_PURPLE    C'180,100,255'   
#define C_WHITE     C'220,225,240'   
#define C_SUBTEXT   C'110,130,160'   
#define C_GREEN     C'20,220,110'    
#define C_RED       C'230,55,65'     
#define C_ORANGE    C'255,145,0'     
#define C_DKGREEN   C'14,80,45'      
#define C_DKRED     C'80,18,22'      
#define C_LBLUE     C'80,160,255'    
#define C_DGRAY     C'40,52,72'      
#define C_MGRAY     C'75,90,115'     
#define C_BADGE_BG  C'16,24,56'      

//=======================================================================
//  INPUT PARAMETERS
//=======================================================================
input group "╔══════  IDENTITY  ══════╗"
input ulong  InpMagicNumber     = 88888;       // Magic Number
input string InpBotName         = "PHANTOM INSTITUTIONAL"; // Bot Name

input group "╔══════  MICRO-ACCOUNT RISK PROTECTION  ══════╗"
input bool   InpAutoMicroScale  = true;        // Auto-Scale Settings for Small Accounts (<$50)
input double InpTargetProfitPct = 1.0;         // Target Profit % per trade if Micro-scaled (e.g. 1% of $5 = $0.05)
input double InpLotSize         = 0.01;        // Default Base Lot Size (Overrides if AutoMicroScale is active)
input double InpFixedTargetUSD  = 0.10;        // Fallback Fixed Profit Target (USD)
input double InpStopLossPct     = 0.5;         // Stop Loss % from entry (Strictly minimized for BTC)
input double InpTakeProfitPct   = 1.0;         // Take Profit % from entry

input group "╔══════  INSTITUTIONAL VOLATILITY FILTER  ══════╗"
input int    InpATRPeriod       = 14;          // ATR Period
input double InpMaxSpreadPoints = 500;         // Max Spread in Points (Calibrated for BTCUSD)
input bool   InpUseATRFilter    = true;        // Block entry during toxic volatility spikes

input group "╔══════  TRADE FREQUENCY  ══════╗"
input int    InpMaxDailyTrades  = 20;          // Max Trades Per Day
input int    InpCooldownSec     = 30;          // Cooldown Seconds After Close
input bool   InpTradeWeekends   = true;        // Crypto runs 24/7

input group "╔══════  ALGOREX DIRECTION FILTER  ══════╗"
input bool   InpAllowBuy        = true;        // Allow BUY
input bool   InpAllowSell       = true;        // Allow SELL
input int    InpEMAFast         = 9;           // Fast EMA
input int    InpEMASlow         = 21;          // Slow EMA
input int    InpRSIPeriod       = 14;          // RSI Period
input double InpRSIOverbought   = 65.0;        // Overbought Level
input double InpRSIOversold     = 35.0;        // Oversold Level

input group "╔══════  DASHBOARD  ══════╗"
input bool   InpShowDash        = true;        // Show Dashboard
input int    InpDashX           = 14;          // Dashboard X
input int    InpDashY           = 14;          // Dashboard Y

//=======================================================================
//  CONSTANTS & GLOBALS
//=======================================================================
const int    DW = 420;    
const int    DH = 620;    

CTrade        g_trade;
CPositionInfo g_pos;
CAccountInfo  g_account;

int           g_emaFastH  = INVALID_HANDLE;
int           g_emaSlowH  = INVALID_HANDLE;
int           g_rsiH      = INVALID_HANDLE;
int           g_atrH      = INVALID_HANDLE;

datetime      g_lastCloseTime  = 0;    
datetime      g_sessionDay     = 0;    

int           g_sessTradesTotal  = 0;
int           g_sessTradesToday  = 0;
double        g_sessProfit       = 0.0;
int           g_sessWins         = 0;
int           g_sessLosses       = 0;
double        g_peakEquity       = 0.0;
double        g_drawdown         = 0.0;
int           g_totalTrades      = 0;

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
double   CalculateDynamicTarget();
ENUM_ORDER_TYPE GetPositionType();
ENUM_ORDER_TYPE GetMarketDirection();
bool     IsMarketOpen();
bool     SpreadOK();
bool     VolatilityOK();
bool     DailyLimitsOK();
void     AdjustStops(double price, ENUM_ORDER_TYPE otype, double &sl, double &tp);
double   NPrice(double p);
ENUM_ORDER_TYPE_FILLING GetFillMode();
datetime DayStart(datetime ts);
string   P2(int v);
string   TimeHMS(int secs);
// Dashboard UI Engine
void     InitDash();
void     UpdateDash();
void     DeleteDash();
void     R(string nm, int x, int y, int w, int h, color bg, color brd=clrNONE, int bw=1);
void     L(string nm, int x, int y, string txt, color clr, int fsz, string fnt="Arial Bold");
void     U(string nm, string txt, color clr);
void     Bar(string nm, int x, int y, int w, int h, double pct, color fg, color bg);
void     UpdBar(string nm, double pct, color fg);

//=======================================================================
//  OnInit Engine
//=======================================================================
int OnInit()
{
   g_trade.SetExpertMagicNumber(InpMagicNumber);
   g_trade.SetDeviationInPoints(50);
   g_trade.SetTypeFilling(GetFillMode());
   g_trade.LogLevel(LOG_LEVEL_ERRORS);

   g_emaFastH = iMA(Symbol(), PERIOD_CURRENT, InpEMAFast, 0, MODE_EMA, PRICE_CLOSE);
   g_emaSlowH = iMA(Symbol(), PERIOD_CURRENT, InpEMASlow, 0, MODE_EMA, PRICE_CLOSE);
   g_rsiH     = iRSI(Symbol(), PERIOD_CURRENT, InpRSIPeriod, PRICE_CLOSE);
   g_atrH     = iATR(Symbol(), PERIOD_CURRENT, InpATRPeriod);

   if(g_emaFastH == INVALID_HANDLE || g_emaSlowH == INVALID_HANDLE || g_rsiH == INVALID_HANDLE || g_atrH == INVALID_HANDLE)
   { Print("[CRITICAL] Indicator engine failure."); return INIT_FAILED; }

   g_peakEquity  = AccountInfoDouble(ACCOUNT_EQUITY);
   g_sessionDay  = DayStart(TimeCurrent());

   RestoreSession();
   BuildSessionStats();

   if(InpShowDash) InitDash();
   EventSetTimer(1);

   g_lastAction  = "Algorithmic Scan Active...";
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
   if(g_atrH     != INVALID_HANDLE) IndicatorRelease(g_atrH);
}

//=======================================================================
//  OnTimer Heartbeat
//=======================================================================
void OnTimer()
{
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

   double eq = AccountInfoDouble(ACCOUNT_EQUITY);
   if(eq > g_peakEquity) g_peakEquity = eq;
   if(g_peakEquity > 0)
      g_drawdown = (g_peakEquity - eq) / g_peakEquity * 100.0;

   BuildSessionStats();
   if(InpShowDash) UpdateDash();
}

//=======================================================================
//  Execution Engine (OnTick)
//=======================================================================
void OnTick()
{
   datetime todayStart = DayStart(TimeCurrent());
   if(todayStart != g_sessionDay)
   {
      g_sessionDay = todayStart;
      BuildSessionStats();
   }

   if(!IsMarketOpen())
   {
      g_statusText  = "MKT CLOSED";
      g_statusColor = C_RED;
      return;
   }

   // === POSITION MANAGEMENT & PROFIT TARGET CALCULATOR ===
   if(HasPosition())
   {
      double floatPL = GetFloatPL();
      double dynamicTarget = CalculateDynamicTarget();

      if(floatPL >= dynamicTarget)
      {
         g_lastAction  = StringFormat("Target reached! +$%.3f", floatPL);
         CloseAllPositions();
         g_lastCloseTime = TimeCurrent();
         g_inCooldown    = true;
         g_statusText    = "COOLDOWN";
         g_statusColor   = C_CYAN;
         BuildSessionStats();
         return;
      }
      g_statusText  = "IN POSITION";
      g_statusColor = C_GREEN;
      return;
   }

   if(g_inCooldown)
   {
      g_statusText  = "COOLDOWN";
      g_statusColor = C_CYAN;
      return;
   }

   if(!DailyLimitsOK())   { g_statusText = "LIMIT BLOCK"; g_statusColor = C_RED; return; }
   if(!SpreadOK())        { g_statusText = "HIGH SPREAD"; g_statusColor = C_ORANGE; return; }
   if(!VolatilityOK())    { g_statusText = "TOXIC VOL";   g_statusColor = C_ORANGE; return; }

   // === SIGNAL PARSING ===
   ENUM_ORDER_TYPE dir = GetMarketDirection();

   if(dir == ORDER_TYPE_BUY  && !InpAllowBuy)  return;
   if(dir == ORDER_TYPE_SELL && !InpAllowSell) return;

   // === ORDER ROUTING ===
   g_statusText  = "EXECUTING";
   g_statusColor = C_LBLUE;
   if(OpenTrade(dir))
   {
      g_statusText  = "IN POSITION";
      g_statusColor = C_GREEN;
      g_sessTradesToday++;
      g_totalTrades++;
      g_lastAction  = StringFormat("Opened %s", (dir == ORDER_TYPE_BUY ? "BUY" : "SELL"));
   }
   else
   {
      g_statusText  = "REJECTED";
      g_statusColor = C_RED;
   }
}

//=======================================================================
//  Smart Risk Order Routing
//=======================================================================
bool OpenTrade(ENUM_ORDER_TYPE otype)
{
   if(!TerminalInfoInteger(TERMINAL_TRADE_ALLOWED) || !MQLInfoInteger(MQL_TRADE_ALLOWED))
      return false;

   double price = (otype == ORDER_TYPE_BUY) ? SymbolInfoDouble(Symbol(), SYMBOL_ASK) : SymbolInfoDouble(Symbol(), SYMBOL_BID);
   if(price <= 0.0) return false;

   // Institutional Micro-Lot Protection Override
   double lotMin  = SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_MIN);
   double lotMax  = SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_MAX);
   double lotStep = SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_STEP);
   
   double computedLot = InpLotSize;
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   
   // If the account is a $5 micro-account, strictly override to broker minimum volume limit
   if(InpAutoMicroScale && balance < 50.0)
   {
      computedLot = lotMin; 
   }

   double lot = MathMax(lotMin, MathMin(lotMax, MathRound(computedLot / lotStep) * lotStep));

   // Hard Protective Stops Setup
   double sl = 0.0, tp = 0.0;
   if(InpStopLossPct > 0.0)
      sl = (otype == ORDER_TYPE_BUY) ? NPrice(price * (1.0 - InpStopLossPct / 100.0)) : NPrice(price * (1.0 + InpStopLossPct / 100.0));
   if(InpTakeProfitPct > 0.0)
      tp = (otype == ORDER_TYPE_BUY) ? NPrice(price * (1.0 + InpTakeProfitPct / 100.0)) : NPrice(price * (1.0 - InpTakeProfitPct / 100.0));

   AdjustStops(price, otype, sl, tp);

   return (otype == ORDER_TYPE_BUY) 
             ? g_trade.Buy (lot, Symbol(), price, sl, tp, InpBotName)
             : g_trade.Sell(lot, Symbol(), price, sl, tp, InpBotName);
}

//=======================================================================
//  Dynamic Target Optimization Module
//=======================================================================
double CalculateDynamicTarget()
{
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   if(InpAutoMicroScale && balance < 50.0)
   {
      // Convert standard target logic into absolute safety tranches (e.g., 1% of $5 = $0.05 target)
      return MathMax(0.01, balance * (InpTargetProfitPct / 100.0));
   }
   return InpFixedTargetUSD;
}

//=======================================================================
//  Signal Intelligence: Dual EMA Cross + RSI Trend-Surfing
//=======================================================================
ENUM_ORDER_TYPE GetMarketDirection()
{
   double emaF[2], emaS[2], rsi[1];
   if(CopyBuffer(g_emaFastH, 0, 0, 2, emaF) <= 0) return ORDER_TYPE_BUY;
   if(CopyBuffer(g_emaSlowH, 0, 0, 2, emaS) <= 0) return ORDER_TYPE_BUY;
   if(CopyBuffer(g_rsiH,     0, 0, 1, rsi)  <= 0) return ORDER_TYPE_BUY;

   bool emaUpNow  = emaF[0] > emaS[0];
   bool rsiBullish = (rsi[0] > 50.0 && rsi[0] < InpRSIOverbought);
   bool rsiBearish = (rsi[0] < 50.0 && rsi[0] > InpRSIOversold);

   if(emaUpNow && rsiBullish)  return ORDER_TYPE_BUY;
   if(!emaUpNow && rsiBearish) return ORDER_TYPE_SELL;

   return emaUpNow ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
}

//=======================================================================
//  System Protection Gateways
//=======================================================================
bool VolatilityOK()
{
   if(!InpUseATRFilter) return true;
   double atr[1];
   if(CopyBuffer(g_atrH, 0, 0, 1, atr) <= 0) return true;
   
   // Cancel inputs if instantaneous volatility threatens micro account balance stability
   double point = SymbolInfoDouble(Symbol(), SYMBOL_POINT);
   double atrPoints = atr[0] / point;
   return (atrPoints < (InpMaxSpreadPoints * 3.0));
}

bool SpreadOK()
{
   int spread = (int)SymbolInfoInteger(Symbol(), SYMBOL_SPREAD);
   return (spread <= InpMaxSpreadPoints);
}

bool DailyLimitsOK()
{
   if(InpMaxDailyTrades > 0 && g_sessTradesToday >= InpMaxDailyTrades) return false;
   return true;
}

void CloseAllPositions()
{
   for(int i = PositionsTotal()-1; i >= 0; i--)
   {
      if(!g_pos.SelectByIndex(i)) continue;
      if(g_pos.Magic() != InpMagicNumber || g_pos.Symbol() != Symbol()) continue;
      g_trade.PositionClose(g_pos.Ticket());
   }
}

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

double NPrice(double p) { return NormalizeDouble(p, (int)SymbolInfoInteger(Symbol(), SYMBOL_DIGITS)); }
ENUM_ORDER_TYPE_FILLING GetFillMode() { uint f = (uint)SymbolInfoInteger(Symbol(), SYMBOL_FILLING_MODE); if((f & SYMBOL_FILLING_FOK) != 0) return ORDER_FILLING_FOK; if((f & SYMBOL_FILLING_IOC) != 0) return ORDER_FILLING_IOC; return ORDER_FILLING_RETURN; }
datetime DayStart(datetime ts) { MqlDateTime d; TimeToStruct(ts, d); return ts - (datetime)(d.hour*3600 + d.min*60 + d.sec); }

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
      if(HistoryDealGetInteger(tk, DEAL_ENTRY) == DEAL_ENTRY_IN) g_sessTradesToday++;
   }
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
         double pnl = HistoryDealGetDouble(tk, DEAL_PROFIT) + HistoryDealGetDouble(tk, DEAL_SWAP) + HistoryDealGetDouble(tk, DEAL_COMMISSION);
         g_sessProfit += pnl;
         if(pnl >= 0) g_sessWins++; else g_sessLosses++;
      }
   }
}

//=======================================================================
//  Dashboard Engine UI Rendering
//=======================================================================
void R(string nm, int x, int y, int w, int h, color bg, color brd, int bw) { string n = D + nm; if(ObjectFind(0, n) >= 0) ObjectDelete(0, n); ObjectCreate(0, n, OBJ_RECTANGLE_LABEL, 0, 0, 0); ObjectSetInteger(0, n, OBJPROP_CORNER, CORNER_LEFT_UPPER); ObjectSetInteger(0, n, OBJPROP_XDISTANCE, x); ObjectSetInteger(0, n, OBJPROP_YDISTANCE, y); ObjectSetInteger(0, n, OBJPROP_XSIZE, w); ObjectSetInteger(0, n, OBJPROP_YSIZE, h); ObjectSetInteger(0, n, OBJPROP_BGCOLOR, bg); if(brd != clrNONE) { ObjectSetInteger(0, n, OBJPROP_BORDER_TYPE, BORDER_FLAT); ObjectSetInteger(0, n, OBJPROP_COLOR, brd); ObjectSetInteger(0, n, OBJPROP_WIDTH, bw); } else ObjectSetInteger(0, n, OBJPROP_BORDER_TYPE, BORDER_RAISED); ObjectSetInteger(0, n, OBJPROP_SELECTABLE, false); ObjectSetInteger(0, n, OBJPROP_HIDDEN, true); }
void L(string nm, int x, int y, string txt, color clr, int fsz, string fnt) { string n = D + nm; if(ObjectFind(0, n) >= 0) ObjectDelete(0, n); ObjectCreate(0, n, OBJ_LABEL, 0, 0, 0); ObjectSetInteger(0, n, OBJPROP_CORNER, CORNER_LEFT_UPPER); ObjectSetInteger(0, n, OBJPROP_XDISTANCE, x); ObjectSetInteger(0, n, OBJPROP_YDISTANCE, y); ObjectSetString(0, n, OBJPROP_TEXT, txt); ObjectSetInteger(0, n, OBJPROP_COLOR, clr); ObjectSetInteger(0, n, OBJPROP_FONTSIZE, fsz); ObjectSetString(0, n, OBJPROP_FONT, fnt); ObjectSetInteger(0, n, OBJPROP_SELECTABLE, false); ObjectSetInteger(0, n, OBJPROP_HIDDEN, true); }
void U(string nm, string txt, color clr) { string n = D + nm; if(ObjectFind(0, n) >= 0) { ObjectSetString(0, n, OBJPROP_TEXT, txt); ObjectSetInteger(0, n, OBJPROP_COLOR, clr); } }
void Bar(string nm, int x, int y, int w, int h, double pct, color fg, color bg_c) { R(nm + "_bg", x, y, w, h, bg_c, C_BORDER, 1); int fw = (int)MathMax(2, MathRound(pct / 100.0 * (w - 2))); R(nm + "_fg", x+1, y+1, fw, h-2, fg, clrNONE); }
void UpdBar(string nm, double pct, color fg) { string n = D + nm + "_fg"; string nb = D + nm + "_bg"; int w = 0; if(ObjectFind(0, nb) >= 0) w = (int)ObjectGetInteger(0, nb, OBJPROP_XSIZE); if(w <= 0) return; int fw = (int)MathMax(2, MathRound(pct / 100.0 * (w - 2))); if(ObjectFind(0, n) >= 0) { ObjectSetInteger(0, n, OBJPROP_XSIZE, fw); ObjectSetInteger(0, n, OBJPROP_BGCOLOR, fg); } }

void InitDash()
{
   int X = InpDashX, Y = InpDashY;
   R("frame_outer", X, Y, DW, DH, C_BG0, C_ACBORD, 2);
   R("frame_inner", X+2, Y+2, DW-4, DH-4, C_BG0, C_BORDER, 1);
   R("hdr_bg", X+2, Y+2, DW-4, 80, C_HDRBAR, C_BORDER, 1);
   R("hdr_acc", X+2, Y+2, DW-4, 3, C_ACBORD2);

   L("h_name", X+10, Y+10, InpBotName, C_GOLD, 12, "Arial Black");
   L("h_tag", X+10, Y+30, "Institutional Small-Account Safeguard", C_CYAN, 7, "Arial");
   L("h_ver", X+10, Y+44, "v3.5 Crypto-Edition | " + Symbol(), C_LBLUE, 7, "Arial");

   R("live_bg", X+DW-80, Y+8, 64, 22, C_DKGREEN, C_GREEN, 1);
   L("live_lbl",X+DW-72, Y+12, "● LIVE", C_GREEN, 7, "Arial Bold");
   R("div_hdr", X+2, Y+82, DW-4, 2, C_ACBORD2);

   R("stat_bg", X+2, Y+86, DW-4, 30, C_BG2, C_BORDER, 1);
   L("lb_stat", X+14, Y+93, "ENGINE", C_SUBTEXT, 8, "Arial");
   L("vl_stat", X+100,Y+93, "STARTING", C_ORANGE, 9, "Arial Black");
   L("lb_act", X+210,Y+93, "Log:", C_SUBTEXT, 7, "Arial");
   L("vl_act", X+245,Y+93, "--", C_WHITE, 7, "Arial");

   R("sec_a", X+2, Y+122, DW-4, 168, C_BG1, C_BORDER, 1);
   R("sec_a_hd",X+2, Y+122, DW-4, 22, C_HDRBAR, C_BORDER, 1);
   L("sec_a_lb",X+10, Y+126, "▸ PERFORMANCE MONITOR", C_GOLD, 8, "Arial Black");

   L("lb_sp", X+14, Y+149, "Session P&L", C_SUBTEXT, 8, "Arial");
   L("vl_sp", X+200,Y+149, "$ 0.00", C_WHITE, 9, "Arial Bold");
   L("lb_fp", X+14, Y+165, "Floating P&L", C_SUBTEXT, 8, "Arial");
   L("vl_fp", X+200,Y+165, "$ 0.00", C_WHITE, 9, "Arial Bold");
   L("lb_wl", X+14, Y+181, "Win / Loss Ratio", C_SUBTEXT, 8, "Arial");
   L("vl_wl", X+200,Y+181, "0W / 0L", C_WHITE, 9, "Arial Bold");

   L("lb_wr", X+14, Y+197, "Win Rate", C_SUBTEXT, 8, "Arial");
   L("vl_wr", X+200,Y+197, "0 %", C_WHITE, 9, "Arial Bold");
   Bar("wr_bar", X+280, Y+199, 130, 12, 0, C_GREEN, C_DGRAY);

   L("lb_dd", X+14, Y+213, "Max Drawdown", C_SUBTEXT, 8, "Arial");
   L("vl_dd", X+200,Y+213, "0.00 %", C_WHITE, 9, "Arial Bold");
   Bar("dd_bar", X+280, Y+215, 130, 12, 0, C_RED, C_DGRAY);

   L("lb_tt", X+14, Y+229, "Cycles Consumed", C_SUBTEXT, 8, "Arial");
   L("vl_tt", X+200,Y+229, "0 / 20", C_WHITE, 9, "Arial Bold");
   Bar("tt_bar", X+280, Y+231, 130, 12, 0, C_LBLUE, C_DGRAY);

   R("sec_b", X+2, Y+296, DW-4, 106, C_BG1, C_BORDER, 1);
   R("sec_b_hd",X+2, Y+296, DW-4, 22, C_HDRBAR, C_BORDER, 1);
   L("sec_b_lb",X+10, Y+300, "▸ CAPITAL DEPLOYMENT", C_GOLD, 8, "Arial Black");

   L("lb_bal", X+14, Y+323, "Balance", C_SUBTEXT, 8, "Arial");
   L("vl_bal", X+200,Y+323, "$ 0.00", C_WHITE, 9, "Arial Bold");
   L("lb_eq", X+14, Y+339, "Equity", C_SUBTEXT, 8, "Arial");
   L("vl_eq", X+200,Y+339, "$ 0.00", C_WHITE, 9, "Arial Bold");
   L("lb_mg", X+14, Y+355, "Available Margin", C_SUBTEXT, 8, "Arial");
   L("vl_mg", X+200,Y+355, "$ 0.00", C_WHITE, 9, "Arial Bold");

   R("sec_c", X+2, Y+408, DW-4, 130, C_BG1, C_BORDER, 1);
   R("sec_c_hd",X+2, Y+408, DW-4, 22, C_HDRBAR, C_BORDER, 1);
   L("sec_c_lb",X+10, Y+412, "▸ MARKET INTEGRITY STATUS",C_GOLD, 8, "Arial Black");

   L("lb_sym", X+14, Y+435, "Instrument", C_SUBTEXT, 8, "Arial");
   L("vl_sym", X+200,Y+435, Symbol(), C_CYAN, 9, "Arial Bold");
   L("lb_dir", X+14, Y+451, "Structural Bias", C_SUBTEXT, 8, "Arial");
   L("vl_dir", X+200,Y+451, "--", C_WHITE, 9, "Arial Bold");
   L("lb_spr", X+14, Y+467, "Spread", C_SUBTEXT, 8, "Arial");
   L("vl_spr", X+200,Y+467, "0 pts", C_WHITE, 9, "Arial Bold");
   L("lb_cd", X+14, Y+483, "System Gate", C_SUBTEXT, 8, "Arial");
   L("vl_cd", X+200,Y+483, "Ready", C_GREEN, 9, "Arial Bold");

   R("sec_d", X+2, Y+544, DW-4, 56, C_BG2, C_BORDER, 1);
   L("cfg1", X+14, Y+549, "Mode: Auto Protection Sizing for Micro accounts Active.", C_GOLD, 7, "Arial");
   L("cfg2", X+14, Y+563, "Dynamic Target Calculation Engine Enabled.", C_LBLUE, 7, "Arial");

   R("ftr", X+2, Y+603, DW-4, 15, C_HDRBAR, C_BORDER, 1);
   L("ft_time", X+10, Y+605, "Syncing server clock...", C_MGRAY, 7, "Arial");
   ChartRedraw(0);
}

void UpdateDash()
{
   if(!InpShowDash) return;
   double floatPL = GetFloatPL();
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double equity  = AccountInfoDouble(ACCOUNT_EQUITY);
   int spread = (int)SymbolInfoInteger(Symbol(), SYMBOL_SPREAD);

   U("vl_stat", g_statusText, g_statusColor);
   U("vl_act", g_lastAction, C_WHITE);
   U("vl_sp", "$ " + DoubleToString(g_sessProfit, 2), (g_sessProfit >= 0) ? C_GREEN : C_RED);
   U("vl_fp", "$ " + DoubleToString(floatPL, 2), (floatPL >= 0) ? C_GREEN : C_RED);

   int closed = g_sessWins + g_sessLosses;
   U("vl_wl", IntegerToString(g_sessWins) + "W / " + IntegerToString(g_sessLosses) + "L", C_WHITE);

   double wr = (closed > 0) ? ((double)g_sessWins / closed * 100.0) : 0.0;
   U("vl_wr", DoubleToString(wr, 1) + " %", C_GREEN);
   UpdBar("wr_bar", wr, C_GREEN);

   U("vl_dd", DoubleToString(g_drawdown, 2) + " %", C_RED);
   UpdBar("dd_bar", MathMin(g_drawdown * 10, 100), C_RED);

   U("vl_bal", "$ " + DoubleToString(balance, 2), C_WHITE);
   U("vl_eq", "$ " + DoubleToString(equity, 2), C_WHITE);
   U("vl_mg", "$ " + DoubleToString(AccountInfoDouble(ACCOUNT_MARGIN_FREE), 2), C_WHITE);

   ENUM_ORDER_TYPE d = GetMarketDirection();
   U("vl_dir", (d == ORDER_TYPE_BUY ? "BULLISH" : "BEARISH"), (d == ORDER_TYPE_BUY ? C_GREEN : C_RED));
   U("vl_spr", IntegerToString(spread) + " pts", (spread <= InpMaxSpreadPoints) ? C_GREEN : C_ORANGE);

   if(g_inCooldown) U("vl_cd", "Hold " + IntegerToString(g_cooldownLeft) + "s", C_ORANGE);
   else U("vl_cd", "Ready", C_GREEN);

   U("ft_time", "Server Time: " + TimeToString(TimeCurrent(), TIME_SECONDS), C_MGRAY);
   ChartRedraw(0);
}

void DeleteDash() { ObjectsDeleteAll(0, D); ChartRedraw(0); }