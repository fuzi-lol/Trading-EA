//+------------------------------------------------------------------+
//|  THEE EliteScalper — MicroGrid Edition  v2.0                    |
//|  Base: EliteScalper MicroGrid  +  Phantom Scalper PRO logic      |
//|  Symbol   : XAUUSD                                               |
//|  Timeframe: M1 primary / M5 trend filter                        |
//|  Features : Progressive tiers | Dual-EMA+RSI signal | Cooldown  |
//|             Full PSP luxury dashboard | Session restore          |
//|             Circuit breaker | Daily limits | Lot scaling         |
//+------------------------------------------------------------------+
#property copyright "THEE EliteScalper v2.0 | MicroGrid + Phantom Logic"
#property version   "2.00"
#property strict

#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>
#include <Trade\AccountInfo.mqh>

//=======================================================================
//  DASHBOARD NAMESPACE
//=======================================================================
#define D "ES2_"

//=======================================================================
//  COLOUR PALETTE  —  Deep-space luxury fintech (from Phantom Scalper)
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

//=======================================================================
//  INPUT PARAMETERS
//=======================================================================

input group "╔══════  IDENTITY  ══════╗"
input ulong  InpMagicNumber        = 20250609;
input string InpBotName            = "THEE EliteScalper";

input group "╔══════  LOT & SCALING  ══════╗"
input double InpBaseLotSize        = 0.01;       // Starting lot size
input bool   InpAllowLotScaling    = true;        // Scale lot with cumulative profit
input bool   InpAllowTPScaling     = true;        // Scale TP with tier
input bool   InpAllowTradeCount    = true;        // Scale max trades with tier

input group "╔══════  RISK  ══════╗"
input double InpStopLossPct        = 1.5;         // SL % from entry (0=ATR-based)
input double InpTakeProfitPct      = 3.0;         // Broker TP % from entry (0=off)
input double InpMaxDailyLossPct    = 20.0;        // Max daily loss % of balance
input double InpMaxDailyProfitPct  = 0.0;         // Max daily profit % (0=off)
input double InpMaxDrawdownPct     = 40.0;        // Circuit breaker drawdown %

input group "╔══════  SIGNAL  ══════╗"
input int    InpEMAFast            = 9;           // Fast EMA period
input int    InpEMASlow            = 21;          // Slow EMA period
input int    InpRSIPeriod          = 14;          // RSI period
input double InpRSIOverbought      = 70.0;        // RSI overbought level
input double InpRSIOversold        = 30.0;        // RSI oversold level
input int    InpATRPeriod          = 14;          // ATR period
input double InpMinATRPips         = 0.5;         // Min ATR pips (volatility gate)
input double InpMaxATRPips         = 8.0;         // Max ATR pips (news spike filter)
input int    InpMaxSpreadPoints    = 30;          // Max spread in points

input group "╔══════  TRADE FREQUENCY  ══════╗"
input int    InpCooldownSec        = 60;          // Cooldown seconds after close
input bool   InpAllowBuy           = true;        // Allow BUY trades
input bool   InpAllowSell          = true;        // Allow SELL trades
input bool   InpTradeWeekends      = false;       // Allow weekend trading

input group "╔══════  SESSIONS  ══════╗"
input bool   InpTradeLondon        = true;        // Trade London session
input bool   InpTradeNewYork       = true;        // Trade New York session

input group "╔══════  SYSTEM  ══════╗"
input bool   InpResetCumulative    = false;       // Reset cumulative profit on start
input bool   InpShowDash           = true;        // Show dashboard
input int    InpDashX              = 14;          // Dashboard X position
input int    InpDashY              = 14;          // Dashboard Y position

//=======================================================================
//  DASHBOARD DIMENSIONS
//=======================================================================
const int DW = 440;
const int DH = 720;

//=======================================================================
//  GLOBALS
//=======================================================================
CTrade        g_trade;
CPositionInfo g_pos;
CAccountInfo  g_account;

// Indicator handles
int g_emaFastH = INVALID_HANDLE;
int g_emaSlowH = INVALID_HANDLE;
int g_rsiH     = INVALID_HANDLE;
int g_atrH     = INVALID_HANDLE;

// Session / cooldown (from Phantom)
datetime g_lastCloseTime  = 0;
datetime g_sessionDay     = 0;
bool     g_inCooldown     = false;
int      g_cooldownLeft   = 0;

// Session stats
int    g_sessTradesTotal  = 0;
int    g_sessTradesToday  = 0;
double g_sessProfit       = 0.0;
int    g_sessWins         = 0;
int    g_sessLosses       = 0;
double g_peakEquity       = 0.0;
double g_drawdown         = 0.0;

// EA state flags
bool   g_haltedToday      = false;
bool   g_circuitBroken    = false;

// Dashboard status
string g_statusText  = "STARTING";
color  g_statusColor = C_ORANGE;
string g_lastAction  = "Initializing...";

// Global variable keys
string GV_DAILY     = "";
string GV_CUMUL     = "ELITE2_CUMULATIVE";
string GV_DISABLED  = "ELITE2_DISABLED";

//=======================================================================
//  FORWARD DECLARATIONS
//=======================================================================
void   RestoreSession();
void   BuildSessionStats();
bool   HasPosition();
int    CountOpenPositions();
void   OpenEliteTrade(ENUM_ORDER_TYPE otype);
void   CloseAllPositions(string reason);
void   CheckAndCloseByProfit();
double GetFloatPL();
ENUM_ORDER_TYPE GetPositionType();
ENUM_ORDER_TYPE GetMarketDirection();
bool   IsMarketOpen();
bool   IsWeekend();
bool   SpreadOK();
bool   IsInSession();
bool   DailyLimitsOK();
bool   IsSafeToTrade();
void   CheckDayChange();
int    GetTier();
string GetTierName(int t);
int    GetMaxTrades(int t);
double GetTierTP(int t);
double GetCurrentLot();
double GetDailyProfit();
double GetCumulativeProfit();
void   AddProfit(double amount);
double GetPipValue();
double CalcTPPrice(double tpUSD, double lot);
double CalcSLDistance(double price);
void   AdjustStops(double price, ENUM_ORDER_TYPE otype, double &sl, double &tp);
double NPrice(double p);
ENUM_ORDER_TYPE_FILLING GetFillMode();
datetime DayStart(datetime ts);
string P2(int v);
// Dashboard
void InitDash();
void UpdateDash();
void DeleteDash();
void DR(string nm, int x, int y, int w, int h, color bg, color brd=clrNONE, int bw=1);
void DL(string nm, int x, int y, string txt, color clr, int fsz, string fnt="Arial Bold");
void DU(string nm, string txt, color clr);
void DBar(string nm, int x, int y, int w, int h, double pct, color fg, color bg);
void DUpdBar(string nm, double pct, color fg);

//=======================================================================
//  OnInit
//=======================================================================
int OnInit()
{
   if(InpBaseLotSize <= 0) { Alert("Lot size must be > 0"); return INIT_PARAMETERS_INCORRECT; }

   g_trade.SetExpertMagicNumber(InpMagicNumber);
   g_trade.SetDeviationInPoints(30);
   g_trade.SetTypeFilling(GetFillMode());
   g_trade.LogLevel(LOG_LEVEL_ALL);

   // Init indicators
   g_emaFastH = iMA(_Symbol, PERIOD_M1, InpEMAFast, 0, MODE_EMA, PRICE_CLOSE);
   g_emaSlowH = iMA(_Symbol, PERIOD_M5, InpEMASlow, 0, MODE_EMA, PRICE_CLOSE);
   g_rsiH     = iRSI(_Symbol, PERIOD_M1, InpRSIPeriod, PRICE_CLOSE);
   g_atrH     = iATR(_Symbol, PERIOD_M1, InpATRPeriod);

   if(g_emaFastH == INVALID_HANDLE || g_emaSlowH == INVALID_HANDLE ||
      g_rsiH == INVALID_HANDLE     || g_atrH == INVALID_HANDLE)
   { Print("Indicator init failed. Error:", GetLastError()); return INIT_FAILED; }

   g_peakEquity = AccountInfoDouble(ACCOUNT_EQUITY);
   g_sessionDay = DayStart(TimeCurrent());

   // Init global vars
   if(InpResetCumulative) GlobalVariableSet(GV_CUMUL, 0.0);
   if(!GlobalVariableCheck(GV_CUMUL)) GlobalVariableSet(GV_CUMUL, 0.0);
   if(GlobalVariableCheck(GV_DISABLED)) GlobalVariableSet(GV_DISABLED, 0);

   MqlDateTime t; TimeToStruct(TimeCurrent(), t);
   GV_DAILY = "ELITE2_DAILY_" + IntegerToString(t.day);
   if(!GlobalVariableCheck(GV_DAILY)) GlobalVariableSet(GV_DAILY, 0.0);

   RestoreSession();
   BuildSessionStats();

   if(InpShowDash) { DeleteDash(); InitDash(); }

   EventSetTimer(1);

   Print("THEE EliteScalper v2.0 | Magic:", InpMagicNumber,
         " | ", _Symbol, " | Cooldown:", InpCooldownSec, "s");

   g_lastAction = "EA Attached - Scanning...";
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
   Print("THEE EliteScalper v2.0 deinitialized. Reason:", reason);
}

//=======================================================================
//  OnTimer — 1s heartbeat (from Phantom)
//=======================================================================
void OnTimer()
{
   // Cooldown counter
   if(g_lastCloseTime > 0)
   {
      int elapsed    = (int)(TimeCurrent() - g_lastCloseTime);
      g_inCooldown   = (elapsed < InpCooldownSec);
      g_cooldownLeft = g_inCooldown ? (InpCooldownSec - elapsed) : 0;
   }
   else { g_inCooldown = false; g_cooldownLeft = 0; }

   // Peak equity / drawdown tracking
   double eq = AccountInfoDouble(ACCOUNT_EQUITY);
   if(eq > g_peakEquity) g_peakEquity = eq;
   if(g_peakEquity > 0)  g_drawdown   = (g_peakEquity - eq) / g_peakEquity * 100.0;

   BuildSessionStats();
   if(InpShowDash) UpdateDash();
}

//=======================================================================
//  OnTick — main execution engine
//=======================================================================
void OnTick()
{
   // --- Day change ---
   CheckDayChange();

   // --- Soft TP monitor: close individual positions at tier TP ---
   CheckAndCloseByProfit();

   // --- Weekend guard (from Phantom) ---
   if(IsWeekend() && !InpTradeWeekends)
   {
      g_statusText = "WEEKEND"; g_statusColor = C_MGRAY;
      if(InpShowDash) UpdateDash();
      return;
   }

   // --- Market open (from Phantom) ---
   if(!IsMarketOpen())
   {
      g_statusText = "MKT CLOSED"; g_statusColor = C_RED;
      if(InpShowDash) UpdateDash();
      return;
   }

   // --- Safety / circuit breaker ---
   if(!IsSafeToTrade())
   {
      if(InpShowDash) UpdateDash();
      return;
   }

   // --- Cooldown check (from Phantom) ---
   if(g_inCooldown)
   {
      g_statusText = "COOLDOWN"; g_statusColor = C_CYAN;
      if(InpShowDash) UpdateDash();
      return;
   }

   // --- Daily limits check (from Phantom) ---
   if(!DailyLimitsOK())
   {
      g_statusText = "LIMIT HIT"; g_statusColor = C_RED;
      if(InpShowDash) UpdateDash();
      return;
   }

   // --- Session filter ---
   if(!IsInSession())
   {
      g_statusText = "OUT OF SESSION"; g_statusColor = C_MGRAY;
      if(InpShowDash) UpdateDash();
      return;
   }

   // --- Spread check ---
   if(!SpreadOK())
   {
      g_statusText = "HIGH SPREAD"; g_statusColor = C_ORANGE;
      if(InpShowDash) UpdateDash();
      return;
   }

   // --- Tier & trade count ---
   int tier      = GetTier();
   int openCount = CountOpenPositions();
   int maxTrades = GetMaxTrades(tier);

   // If at capacity, just monitor
   if(openCount >= maxTrades)
   {
      g_statusText = "IN TRADE"; g_statusColor = C_GREEN;
      if(InpShowDash) UpdateDash();
      return;
   }

   // --- Signal (new bar only) ---
   static datetime lastBar = 0;
   datetime curBar = iTime(_Symbol, PERIOD_M1, 0);
   if(curBar == lastBar) { if(InpShowDash) UpdateDash(); return; }
   lastBar = curBar;

   ENUM_ORDER_TYPE dir = GetMarketDirection();

   if(dir == ORDER_TYPE_BUY  && !InpAllowBuy)  { g_statusText="NO BUY";  g_statusColor=C_ORANGE; if(InpShowDash) UpdateDash(); return; }
   if(dir == ORDER_TYPE_SELL && !InpAllowSell) { g_statusText="NO SELL"; g_statusColor=C_ORANGE; if(InpShowDash) UpdateDash(); return; }

   // --- ATR volatility gate ---
   double atrBuf[1];
   if(CopyBuffer(g_atrH, 0, 0, 1, atrBuf) <= 0) { if(InpShowDash) UpdateDash(); return; }
   double atrPips = atrBuf[0] / (SymbolInfoDouble(_Symbol, SYMBOL_POINT) * 10.0);
   if(atrPips < InpMinATRPips || atrPips > InpMaxATRPips)
   {
      g_statusText = "ATR FILTER"; g_statusColor = C_ORANGE;
      if(InpShowDash) UpdateDash();
      return;
   }

   // --- Open trade ---
   g_statusText = "OPENING"; g_statusColor = C_LBLUE;
   OpenEliteTrade(dir);

   if(InpShowDash) UpdateDash();
}

//=======================================================================
//  GetMarketDirection — Dual-EMA crossover + RSI filter (from Phantom)
//  Uses: FastEMA on M1 + SlowEMA on M5 + RSI on M1
//=======================================================================
ENUM_ORDER_TYPE GetMarketDirection()
{
   double emaF[2], emaS[1], rsi[1];
   if(CopyBuffer(g_emaFastH, 0, 0, 2, emaF) <= 0) return ORDER_TYPE_BUY;
   if(CopyBuffer(g_emaSlowH, 0, 0, 1, emaS) <= 0) return ORDER_TYPE_BUY;
   if(CopyBuffer(g_rsiH,     0, 0, 1, rsi)  <= 0) return ORDER_TYPE_BUY;

   double closeM1 = iClose(_Symbol, PERIOD_M1, 0);

   // EMA cross on M1 (fast) vs M5 (slow) = multi-timeframe confluence
   bool emaUpNow  = (emaF[0] > emaS[0]);
   bool emaUpPrev = (emaF[1] > emaS[0]);

   bool rsiBullish = (rsi[0] > 50.0 && rsi[0] < InpRSIOverbought);
   bool rsiBearish = (rsi[0] < 50.0 && rsi[0] > InpRSIOversold);

   if(emaUpNow && rsiBullish)  return ORDER_TYPE_BUY;
   if(!emaUpNow && rsiBearish) return ORDER_TYPE_SELL;

   // Fallback to EMA bias
   return emaUpNow ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
}

//=======================================================================
//  OpenEliteTrade — Progressive tiers + Phantom-style order execution
//=======================================================================
void OpenEliteTrade(ENUM_ORDER_TYPE otype)
{
   if(!TerminalInfoInteger(TERMINAL_TRADE_ALLOWED))
   { Print("AutoTrading disabled."); return; }
   if(!MQLInfoInteger(MQL_TRADE_ALLOWED))
   { Print("EA trading not allowed."); return; }

   int    tier  = GetTier();
   double lot   = GetCurrentLot();
   double tpUSD = GetTierTP(tier);

   // Normalize lot to broker constraints
   double lotMin  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double lotMax  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   lot = MathMax(lotMin, MathMin(lotMax, MathRound(lot / lotStep) * lotStep));

   double price = (otype == ORDER_TYPE_BUY)
                  ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                  : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(price <= 0.0) return;

   double sl = 0.0, tp = 0.0;

   // SL: use % from entry (Phantom method) or ATR if % is 0
   if(InpStopLossPct > 0.0)
   {
      sl = (otype == ORDER_TYPE_BUY)
           ? NPrice(price * (1.0 - InpStopLossPct / 100.0))
           : NPrice(price * (1.0 + InpStopLossPct / 100.0));
   }
   else
   {
      double slDist = CalcSLDistance(price);
      sl = (otype == ORDER_TYPE_BUY)
           ? NPrice(price - slDist)
           : NPrice(price + slDist);
   }

   // Broker TP (optional — EA also has soft tick-based TP monitor)
   if(InpTakeProfitPct > 0.0)
   {
      tp = (otype == ORDER_TYPE_BUY)
           ? NPrice(price * (1.0 + InpTakeProfitPct / 100.0))
           : NPrice(price * (1.0 - InpTakeProfitPct / 100.0));
   }

   AdjustStops(price, otype, sl, tp);

   string comment = InpBotName + "_T" + IntegerToString(tier)
                    + "_TP$" + DoubleToString(tpUSD, 2);
   bool ok = (otype == ORDER_TYPE_BUY)
             ? g_trade.Buy (lot, _Symbol, price, sl, tp, comment)
             : g_trade.Sell(lot, _Symbol, price, sl, tp, comment);

   if(ok)
   {
      g_sessTradesToday++;
      g_statusText = "IN TRADE"; g_statusColor = C_GREEN;
      g_lastAction = StringFormat("Opened %s %.2f lot @ %.2f | TP $%.2f | Tier %d",
                     (otype == ORDER_TYPE_BUY ? "BUY" : "SELL"), lot, price, tpUSD, tier);
      Print("EliteScalper: OpenTrade OK | ", EnumToString(otype),
            " | Ticket:", g_trade.ResultOrder(),
            " | Lot:", lot, " Entry:", price, " SL:", sl, " TP:", tp,
            " | TierTP: $", tpUSD);
   }
   else
   {
      g_statusText = "OPEN FAIL"; g_statusColor = C_RED;
      g_lastAction = "Open FAILED: " + g_trade.ResultRetcodeDescription();
      Print("EliteScalper: OpenTrade FAIL | Retcode:", g_trade.ResultRetcode(),
            " | ", g_trade.ResultRetcodeDescription());
   }
}

//=======================================================================
//  CheckAndCloseByProfit — soft TP monitor per trade (EliteScalper core)
//=======================================================================
void CheckAndCloseByProfit()
{
   int    tier  = GetTier();
   double tpUSD = GetTierTP(tier);

   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(!g_pos.SelectByIndex(i)) continue;
      if(g_pos.Magic()  != InpMagicNumber) continue;
      if(g_pos.Symbol() != _Symbol)         continue;

      double profit = g_pos.Profit() + g_pos.Swap() + g_pos.Commission();
      if(profit >= tpUSD)
      {
         if(g_trade.PositionClose(g_pos.Ticket(), 50))
         {
            AddProfit(profit);
            g_lastCloseTime = TimeCurrent();
            g_inCooldown    = true;
            g_cooldownLeft  = InpCooldownSec;
            g_statusText    = "COOLDOWN";
            g_statusColor   = C_CYAN;
            g_lastAction    = StringFormat("Profit $%.2f hit – closed #%d",
                                           profit, (int)g_pos.Ticket());
            Print("EliteScalper: Closed #", g_pos.Ticket(),
                  " profit=", profit, " tierTP=", tpUSD);
            BuildSessionStats();
         }
      }
   }
}

//=======================================================================
//  CloseAllPositions  (from Phantom)
//=======================================================================
void CloseAllPositions(string reason)
{
   Print("EliteScalper: Closing ALL — ", reason);
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(!g_pos.SelectByIndex(i)) continue;
      if(g_pos.Magic()  != InpMagicNumber) continue;
      if(g_pos.Symbol() != _Symbol)         continue;
      if(g_trade.PositionClose(g_pos.Ticket()))
         Print("Closed ticket #", g_pos.Ticket());
      else
         Print("Close FAILED #", g_pos.Ticket(), " – ", g_trade.ResultRetcodeDescription());
   }
}

//=======================================================================
//  SAFETY CHECK (EliteScalper circuit breaker + Phantom daily limits)
//=======================================================================
bool IsSafeToTrade()
{
   // Global circuit breaker
   if(GlobalVariableCheck(GV_DISABLED) && GlobalVariableGet(GV_DISABLED) == 1)
   {
      g_circuitBroken = true;
      g_statusText = "CIRCUIT BREAK"; g_statusColor = C_RED;
      return false;
   }

   if(g_haltedToday)
   {
      g_statusText = "DAY HALTED"; g_statusColor = C_RED;
      return false;
   }

   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double equity  = AccountInfoDouble(ACCOUNT_EQUITY);

   // Daily loss halt
   if(InpMaxDailyLossPct > 0.0 && balance > 0.0)
   {
      double dailyLoss = -(g_sessProfit);
      if(dailyLoss > 0.0)
      {
         double pct = (dailyLoss / balance) * 100.0;
         if(pct >= InpMaxDailyLossPct)
         {
            CloseAllPositions("Daily Loss Halt");
            g_haltedToday = true;
            g_statusText  = "DAY HALTED"; g_statusColor = C_RED;
            Print("EliteScalper: DAILY LOSS HALT — ", pct, "%");
            return false;
         }
      }
   }

   // Max drawdown circuit breaker
   if(InpMaxDrawdownPct > 0.0 && balance > 0.0)
   {
      double ddPct = ((balance - equity) / balance) * 100.0;
      if(ddPct >= InpMaxDrawdownPct)
      {
         CloseAllPositions("Circuit Breaker");
         GlobalVariableSet(GV_DISABLED, 1);
         g_circuitBroken = true;
         g_statusText    = "CIRCUIT BREAK"; g_statusColor = C_RED;
         Print("EliteScalper: CIRCUIT BREAKER — drawdown=", ddPct, "%");
         Alert("THEE EliteScalper CIRCUIT BREAKER TRIGGERED on ", _Symbol);
         return false;
      }
   }

   // Emergency spread close
   double spread = (SymbolInfoDouble(_Symbol, SYMBOL_ASK) - SymbolInfoDouble(_Symbol, SYMBOL_BID))
                   / (SymbolInfoDouble(_Symbol, SYMBOL_POINT) * 10.0);
   double maxSpreadPips = InpMaxSpreadPoints / 10.0;
   if(spread > maxSpreadPips * 2.0)
   {
      CloseAllPositions("Emergency spread=" + DoubleToString(spread, 1) + " pips");
      return false;
   }

   return true;
}

//=======================================================================
//  DAY CHANGE CHECK
//=======================================================================
void CheckDayChange()
{
   datetime todayStart = DayStart(TimeCurrent());
   if(todayStart != g_sessionDay)
   {
      g_sessionDay  = todayStart;
      g_haltedToday = false;
      MqlDateTime t; TimeToStruct(TimeCurrent(), t);
      GV_DAILY = "ELITE2_DAILY_" + IntegerToString(t.day);
      GlobalVariableSet(GV_DAILY, 0.0);
      BuildSessionStats();
      g_lastAction = "New trading day — stats reset";
      Print("EliteScalper: New day — daily profit reset");
   }
}

//=======================================================================
//  PROGRESSIVE TIER ENGINE  (EliteScalper)
//=======================================================================
int GetTier()
{
   double dp = GetDailyProfit();
   if(dp <= 2.00)  return 1;
   if(dp <= 10.00) return 2;
   if(dp <= 30.00) return 3;
   return 4;
}

string GetTierName(int t)
{
   switch(t)
   {
      case 1: return "SEED";
      case 2: return "GROWTH";
      case 3: return "SCALE";
      case 4: return "ELITE";
   }
   return "UNKNOWN";
}

int GetMaxTrades(int t)
{
   if(!InpAllowTradeCount) return 2;
   switch(t)
   {
      case 1: return 2;
      case 2: return 4;
      case 3: return 6;
      case 4: return 10;
   }
   return 2;
}

double GetTierTP(int t)
{
   if(!InpAllowTPScaling) return 0.15;
   switch(t)
   {
      case 1: return 0.15;
      case 2: return 0.22;
      case 3: return 0.35;
      case 4: return 0.50;
   }
   return 0.15;
}

double GetCurrentLot()
{
   if(!InpAllowLotScaling) return InpBaseLotSize;
   double c = GetCumulativeProfit();
   if(c < 100.0)  return 0.01;
   if(c < 300.0)  return 0.02;
   if(c < 600.0)  return 0.03;
   if(c < 1000.0) return 0.05;
   return 0.10;
}

//=======================================================================
//  GLOBAL VARIABLE PROFIT HELPERS
//=======================================================================
double GetDailyProfit()
{
   if(!GlobalVariableCheck(GV_DAILY)) return 0.0;
   return GlobalVariableGet(GV_DAILY);
}

double GetCumulativeProfit()
{
   if(!GlobalVariableCheck(GV_CUMUL)) return 0.0;
   return GlobalVariableGet(GV_CUMUL);
}

void AddProfit(double amount)
{
   GlobalVariableSet(GV_DAILY, GetDailyProfit() + amount);
   GlobalVariableSet(GV_CUMUL, GetCumulativeProfit() + amount);
}

//=======================================================================
//  UTILITY HELPERS  (merged from both EAs)
//=======================================================================
double GetPipValue()
{
   double tickVal  = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   double point    = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   double pipSize  = point * 10.0;
   if(tickSize == 0) return 0;
   return (pipSize / tickSize) * tickVal;
}

double CalcTPPrice(double tpUSD, double lot)
{
   double pv = GetPipValue();
   if(pv == 0 || lot == 0) return 0;
   return (tpUSD / (lot * pv)) * SymbolInfoDouble(_Symbol, SYMBOL_POINT) * 10.0;
}

double CalcSLDistance(double price)
{
   double atrBuf[1];
   if(CopyBuffer(g_atrH, 0, 0, 1, atrBuf) <= 0) return price * 0.015;
   double slDist = atrBuf[0] * 1.5;
   double minDist = 5.0 * SymbolInfoDouble(_Symbol, SYMBOL_POINT) * 10.0;
   double maxDist = 15.0 * SymbolInfoDouble(_Symbol, SYMBOL_POINT) * 10.0;
   if(slDist < minDist) slDist = minDist;
   if(slDist > maxDist) slDist = maxDist;
   return slDist;
}

void AdjustStops(double price, ENUM_ORDER_TYPE otype, double &sl, double &tp)
{
   int    stopsLvl = (int)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   double point    = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   double minDist  = stopsLvl * point;
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
{ return NormalizeDouble(p, (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS)); }

ENUM_ORDER_TYPE_FILLING GetFillMode()
{
   uint f = (uint)SymbolInfoInteger(_Symbol, SYMBOL_FILLING_MODE);
   if((f & SYMBOL_FILLING_FOK) != 0) return ORDER_FILLING_FOK;
   if((f & SYMBOL_FILLING_IOC) != 0) return ORDER_FILLING_IOC;
   return ORDER_FILLING_RETURN;
}

datetime DayStart(datetime ts)
{
   MqlDateTime d; TimeToStruct(ts, d);
   return ts - (datetime)(d.hour * 3600 + d.min * 60 + d.sec);
}

string P2(int v) { return (v < 10 ? "0" : "") + IntegerToString(v); }

int CountOpenPositions()
{
   int n = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(!g_pos.SelectByIndex(i)) continue;
      if(g_pos.Magic() == InpMagicNumber && g_pos.Symbol() == _Symbol) n++;
   }
   return n;
}

bool HasPosition()
{ return CountOpenPositions() > 0; }

double GetFloatPL()
{
   double t = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(!g_pos.SelectByIndex(i)) continue;
      if(g_pos.Magic() == InpMagicNumber && g_pos.Symbol() == _Symbol)
         t += g_pos.Profit() + g_pos.Swap() + g_pos.Commission();
   }
   return t;
}

ENUM_ORDER_TYPE GetPositionType()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(!g_pos.SelectByIndex(i)) continue;
      if(g_pos.Magic() == InpMagicNumber && g_pos.Symbol() == _Symbol)
         return (ENUM_ORDER_TYPE)g_pos.PositionType();
   }
   return ORDER_TYPE_BUY;
}

bool IsMarketOpen()
{
   ENUM_SYMBOL_TRADE_MODE m = (ENUM_SYMBOL_TRADE_MODE)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_MODE);
   return (m == SYMBOL_TRADE_MODE_FULL ||
           m == SYMBOL_TRADE_MODE_LONGONLY ||
           m == SYMBOL_TRADE_MODE_SHORTONLY);
}

bool IsWeekend()
{
   MqlDateTime dt; TimeToStruct(TimeCurrent(), dt);
   return (dt.day_of_week == 0 || dt.day_of_week == 6);
}

bool SpreadOK()
{
   if(InpMaxSpreadPoints <= 0) return true;
   return ((int)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD) <= InpMaxSpreadPoints);
}

bool IsInSession()
{
   datetime utc = TimeGMT();
   MqlDateTime t; TimeToStruct(utc, t);
   int hhmm = t.hour * 100 + t.min;
   if(InpTradeLondon  && hhmm >= 800  && hhmm < 1200) return true;
   if(InpTradeNewYork && hhmm >= 1300 && hhmm < 1700) return true;
   return false;
}

string GetSessionName()
{
   datetime utc = TimeGMT();
   MqlDateTime t; TimeToStruct(utc, t);
   int hhmm = t.hour * 100 + t.min;
   if(InpTradeLondon  && hhmm >= 800  && hhmm < 1200) return "LONDON";
   if(InpTradeNewYork && hhmm >= 1300 && hhmm < 1700) return "NEW YORK";
   return "CLOSED";
}

bool DailyLimitsOK()
{
   double bal = AccountInfoDouble(ACCOUNT_BALANCE);
   if(bal <= 0) return true;
   if(g_sessTradesToday >= 50) return false; // absolute safety cap
   if(InpMaxDailyLossPct > 0.0  && g_sessProfit < -(bal * InpMaxDailyLossPct  / 100.0)) return false;
   if(InpMaxDailyProfitPct > 0.0 && g_sessProfit >= (bal * InpMaxDailyProfitPct / 100.0)) return false;
   return true;
}

//=======================================================================
//  SESSION RESTORE  (from Phantom)
//=======================================================================
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
      if(HistoryDealGetString(tk, DEAL_SYMBOL) != _Symbol) continue;
      if(HistoryDealGetInteger(tk, DEAL_ENTRY) == DEAL_ENTRY_IN)
      {
         g_sessTradesToday++;
         g_lastCloseTime = (datetime)HistoryDealGetInteger(tk, DEAL_TIME);
      }
   }
   Print("EliteScalper: RestoreSession — ", g_sessTradesToday, " trades found today.");
}

//=======================================================================
//  BUILD SESSION STATS  (from Phantom)
//=======================================================================
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
      if(HistoryDealGetString(tk, DEAL_SYMBOL) != _Symbol) continue;
      long entry = HistoryDealGetInteger(tk, DEAL_ENTRY);
      if(entry == DEAL_ENTRY_IN) { g_sessTradesTotal++; }
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

//=======================================================================
//  DASHBOARD  —  PSP luxury style (rebuilt for EliteScalper data)
//=======================================================================
void DR(string nm, int x, int y, int w, int h, color bg, color brd=clrNONE, int bw=1)
{
   string n = D + nm;
   if(ObjectFind(0, n) >= 0) ObjectDelete(0, n);
   ObjectCreate(0, n, OBJ_RECTANGLE_LABEL, 0, 0, 0);
   ObjectSetInteger(0, n, OBJPROP_CORNER,     CORNER_LEFT_UPPER);
   ObjectSetInteger(0, n, OBJPROP_XDISTANCE,  x);
   ObjectSetInteger(0, n, OBJPROP_YDISTANCE,  y);
   ObjectSetInteger(0, n, OBJPROP_XSIZE,      w);
   ObjectSetInteger(0, n, OBJPROP_YSIZE,      h);
   ObjectSetInteger(0, n, OBJPROP_BGCOLOR,    bg);
   if(brd != clrNONE)
   { ObjectSetInteger(0, n, OBJPROP_BORDER_TYPE, BORDER_FLAT); ObjectSetInteger(0, n, OBJPROP_COLOR, brd); ObjectSetInteger(0, n, OBJPROP_WIDTH, bw); }
   else ObjectSetInteger(0, n, OBJPROP_BORDER_TYPE, BORDER_RAISED);
   ObjectSetInteger(0, n, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, n, OBJPROP_HIDDEN,     true);
   ObjectSetInteger(0, n, OBJPROP_BACK,       false);
   ObjectSetInteger(0, n, OBJPROP_ZORDER,     0);
}

void DL(string nm, int x, int y, string txt, color clr, int fsz, string fnt="Arial Bold")
{
   string n = D + nm;
   if(ObjectFind(0, n) >= 0) ObjectDelete(0, n);
   ObjectCreate(0, n, OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, n, OBJPROP_CORNER,     CORNER_LEFT_UPPER);
   ObjectSetInteger(0, n, OBJPROP_XDISTANCE,  x);
   ObjectSetInteger(0, n, OBJPROP_YDISTANCE,  y);
   ObjectSetString(0,  n, OBJPROP_TEXT,       txt);
   ObjectSetInteger(0, n, OBJPROP_COLOR,      clr);
   ObjectSetInteger(0, n, OBJPROP_FONTSIZE,   fsz);
   ObjectSetString(0,  n, OBJPROP_FONT,       fnt);
   ObjectSetInteger(0, n, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, n, OBJPROP_HIDDEN,     true);
   ObjectSetInteger(0, n, OBJPROP_BACK,       false);
   ObjectSetInteger(0, n, OBJPROP_ZORDER,     1);
}

void DU(string nm, string txt, color clr=C'220,225,240')
{
   string n = D + nm;
   if(ObjectFind(0, n) >= 0)
   { ObjectSetString(0, n, OBJPROP_TEXT, txt); ObjectSetInteger(0, n, OBJPROP_COLOR, clr); }
}

void DBar(string nm, int x, int y, int w, int h, double pct, color fg, color bg_c)
{
   DR(nm + "_bg", x, y, w, h, bg_c, C_BORDER, 1);
   int fw = (int)MathMax(2, MathRound(pct / 100.0 * (w - 2)));
   DR(nm + "_fg", x+1, y+1, fw, h-2, fg, clrNONE);
}

void DUpdBar(string nm, double pct, color fg)
{
   string n  = D + nm + "_fg";
   string nb = D + nm + "_bg";
   int w = 0;
   if(ObjectFind(0, nb) >= 0) w = (int)ObjectGetInteger(0, nb, OBJPROP_XSIZE);
   if(w <= 0) return;
   int fw = (int)MathMax(2, MathRound(pct / 100.0 * (w - 2)));
   if(ObjectFind(0, n) >= 0)
   { ObjectSetInteger(0, n, OBJPROP_XSIZE, fw); ObjectSetInteger(0, n, OBJPROP_BGCOLOR, fg); }
}

void DeleteDash() { ObjectsDeleteAll(0, D); ChartRedraw(0); }

void InitDash()
{
   int X = InpDashX, Y = InpDashY;

   // === OUTER FRAME ===
   DR("frame_outer", X,   Y,   DW,   DH,   C_BG0,   C_ACBORD,  2);
   DR("frame_inner", X+2, Y+2, DW-4, DH-4, C_BG0,   C_BORDER,  1);

   // === HEADER ===
   DR("hdr_bg",  X+2,  Y+2,  DW-4, 85,  C_HDRBAR, C_BORDER, 1);
   DR("hdr_acc", X+2,  Y+2,  DW-4,  3,  C_ACBORD);
   DL("h_name",  X+10, Y+10, InpBotName,                           C_GOLD,   13, "Arial Black");
   DL("h_tag",   X+10, Y+32, "MicroGrid Edition  |  XAUUSD  |  M1/M5 Confluence", C_CYAN, 7, "Arial");
   DL("h_ver",   X+10, Y+48, "v2.0  +  Magic: " + IntegerToString((long)InpMagicNumber) + "  +  " + _Symbol, C_LBLUE, 7, "Arial");
   DR("live_bg", X+DW-85, Y+8, 70, 22, C_DKGREEN, C_GREEN, 1);
   DL("live_lbl",X+DW-78, Y+13, "● LIVE",  C_GREEN, 7, "Arial Bold");
   DR("div_hdr", X+2, Y+87, DW-4, 2, C_ACBORD);

   // === STATUS ROW ===
   DR("stat_bg",  X+2,  Y+91,  DW-4, 30, C_BG2, C_BORDER, 1);
   DL("lb_stat",  X+14, Y+98,  "STATUS",       C_SUBTEXT, 8, "Arial");
   DL("vl_stat",  X+100,Y+98,  "STARTING",     C_ORANGE,  9, "Arial Black");
   DL("lb_act",   X+220,Y+98,  "Last action:", C_SUBTEXT, 7, "Arial");
   DL("vl_act",   X+300,Y+98,  "--",           C_WHITE,   7, "Arial");
   DR("div_stat", X+2, Y+123, DW-4, 1, C_BORDER);

   // === SECTION A: PERFORMANCE ===
   DR("sec_a",    X+2,  Y+127, DW-4, 186, C_BG1, C_BORDER, 1);
   DR("sec_a_hd", X+2,  Y+127, DW-4,  22, C_HDRBAR, C_BORDER, 1);
   DL("sec_a_lb", X+10, Y+131, "▸  PERFORMANCE",  C_GOLD, 8, "Arial Black");
   DR("div_a",    X+2,  Y+149, DW-4, 1, C_BORDER);

   DL("lb_dp",  X+14, Y+154, "Daily Profit",         C_SUBTEXT, 8, "Arial");
   DL("vl_dp",  X+210,Y+154, "$ 0.00",               C_WHITE,   9, "Arial Bold");
   DL("lb_cp",  X+14, Y+170, "Cumulative Profit",    C_SUBTEXT, 8, "Arial");
   DL("vl_cp",  X+210,Y+170, "$ 0.00",               C_WHITE,   9, "Arial Bold");
   DL("lb_fp",  X+14, Y+186, "Floating P&L",         C_SUBTEXT, 8, "Arial");
   DL("vl_fp",  X+210,Y+186, "$ 0.00",               C_WHITE,   9, "Arial Bold");
   DL("lb_wl",  X+14, Y+202, "Win / Loss",           C_SUBTEXT, 8, "Arial");
   DL("vl_wl",  X+210,Y+202, "0W / 0L",              C_WHITE,   9, "Arial Bold");
   DL("lb_wr",  X+14, Y+218, "Win Rate",             C_SUBTEXT, 8, "Arial");
   DL("vl_wr",  X+210,Y+218, "0 %",                  C_WHITE,   9, "Arial Bold");
   DBar("wr_bar", X+290, Y+220, 140, 12, 0, C_GREEN, C_DGRAY);
   DL("lb_dd",  X+14, Y+234, "Drawdown",             C_SUBTEXT, 8, "Arial");
   DL("vl_dd",  X+210,Y+234, "0.00 %",               C_WHITE,   9, "Arial Bold");
   DBar("dd_bar", X+290, Y+236, 140, 12, 0, C_RED, C_DGRAY);
   DL("lb_tt",  X+14, Y+250, "Trades Today",         C_SUBTEXT, 8, "Arial");
   DL("vl_tt",  X+210,Y+250, "0",                    C_WHITE,   9, "Arial Bold");
   DBar("tt_bar", X+290, Y+252, 140, 12, 0, C_LBLUE, C_DGRAY);
   DR("div_a2", X+2, Y+313, DW-4, 1, C_BORDER);

   // === SECTION B: TIER ENGINE ===
   DR("sec_b",    X+2,  Y+317, DW-4, 120, C_BG1, C_BORDER, 1);
   DR("sec_b_hd", X+2,  Y+317, DW-4,  22, C_HDRBAR, C_BORDER, 1);
   DL("sec_b_lb", X+10, Y+321, "▸  MICROGRID TIER ENGINE",  C_GOLD, 8, "Arial Black");
   DR("div_b",    X+2,  Y+339, DW-4, 1, C_BORDER);

   DL("lb_tier", X+14, Y+344, "Active Tier",         C_SUBTEXT, 8, "Arial");
   DL("vl_tier", X+210,Y+344, "SEED",                C_PURPLE,  9, "Arial Black");
   DL("lb_op",   X+14, Y+360, "Open Trades",         C_SUBTEXT, 8, "Arial");
   DL("vl_op",   X+210,Y+360, "0 / 2",               C_WHITE,   9, "Arial Bold");
   DBar("op_bar", X+290, Y+362, 140, 12, 0, C_PURPLE, C_DGRAY);
   DL("lb_lot",  X+14, Y+376, "Lot Size",            C_SUBTEXT, 8, "Arial");
   DL("vl_lot",  X+210,Y+376, "0.01",                C_WHITE,   9, "Arial Bold");
   DL("lb_tp",   X+14, Y+392, "TP per Trade",        C_SUBTEXT, 8, "Arial");
   DL("vl_tp",   X+210,Y+392, "$0.15",               C_CYAN,    9, "Arial Bold");
   DR("div_b2",  X+2, Y+437, DW-4, 1, C_BORDER);

   // === SECTION C: ACCOUNT ===
   DR("sec_c",    X+2,  Y+441, DW-4, 100, C_BG1, C_BORDER, 1);
   DR("sec_c_hd", X+2,  Y+441, DW-4,  22, C_HDRBAR, C_BORDER, 1);
   DL("sec_c_lb", X+10, Y+445, "▸  ACCOUNT",         C_GOLD, 8, "Arial Black");
   DR("div_c",    X+2,  Y+463, DW-4, 1, C_BORDER);

   DL("lb_bal",  X+14, Y+468, "Balance",             C_SUBTEXT, 8, "Arial");
   DL("vl_bal",  X+210,Y+468, "$ 0.00",              C_WHITE,   9, "Arial Bold");
   DL("lb_eq",   X+14, Y+484, "Equity",              C_SUBTEXT, 8, "Arial");
   DL("vl_eq",   X+210,Y+484, "$ 0.00",              C_WHITE,   9, "Arial Bold");
   DL("lb_mg",   X+14, Y+500, "Free Margin",         C_SUBTEXT, 8, "Arial");
   DL("vl_mg",   X+210,Y+500, "$ 0.00",              C_WHITE,   9, "Arial Bold");
   DR("div_c2",  X+2, Y+541, DW-4, 1, C_BORDER);

   // === SECTION D: MARKET ===
   DR("sec_d",    X+2,  Y+545, DW-4, 120, C_BG1, C_BORDER, 1);
   DR("sec_d_hd", X+2,  Y+545, DW-4,  22, C_HDRBAR, C_BORDER, 1);
   DL("sec_d_lb", X+10, Y+549, "▸  MARKET STATUS",   C_GOLD, 8, "Arial Black");
   DR("div_d",    X+2,  Y+567, DW-4, 1, C_BORDER);

   DL("lb_dir",  X+14, Y+572, "EMA Direction",       C_SUBTEXT, 8, "Arial");
   DL("vl_dir",  X+210,Y+572, "--",                  C_WHITE,   9, "Arial Bold");
   DL("lb_spr",  X+14, Y+588, "Spread",              C_SUBTEXT, 8, "Arial");
   DL("vl_spr",  X+210,Y+588, "0 pts",               C_WHITE,   9, "Arial Bold");
   DL("lb_ses",  X+14, Y+604, "Session",             C_SUBTEXT, 8, "Arial");
   DL("vl_ses",  X+210,Y+604, "--",                  C_WHITE,   9, "Arial Bold");
   DL("lb_cd",   X+14, Y+620, "Cooldown",            C_SUBTEXT, 8, "Arial");
   DL("vl_cd",   X+210,Y+620, "Ready",               C_GREEN,   9, "Arial Bold");
   DR("div_d2",  X+2, Y+665, DW-4, 1, C_BORDER);

   // === FOOTER ===
   DR("ftr",     X+2,  Y+668, DW-4, 16, C_HDRBAR, C_BORDER, 1);
   DL("ft_time", X+10, Y+670, "Server: --:--",                   C_MGRAY, 7, "Arial");
   DL("ft_url",  X+DW-175, Y+670, "fxbothub.com  |  EliteScalper v2.0", C_DGRAY, 7, "Arial");

   ChartRedraw(0);
}

void UpdateDash()
{
   if(!InpShowDash) return;

   int    tier      = GetTier();
   int    openCount = CountOpenPositions();
   int    maxTrades = GetMaxTrades(tier);
   double lot       = GetCurrentLot();
   double tpUSD     = GetTierTP(tier);
   double dailyP    = GetDailyProfit();
   double cumulP    = GetCumulativeProfit();
   double floatPL   = GetFloatPL();
   double balance   = AccountInfoDouble(ACCOUNT_BALANCE);
   double equity    = AccountInfoDouble(ACCOUNT_EQUITY);
   double freeMargin= AccountInfoDouble(ACCOUNT_MARGIN_FREE);
   int    spread    = (int)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);

   // Status
   DU("vl_stat", g_statusText,  g_statusColor);
   DU("vl_act",  g_lastAction,  C_SUBTEXT);

   // Performance
   color dpClr = (dailyP >= 0) ? C_GREEN : C_RED;
   color cpClr = (cumulP >= 0) ? C_GREEN : C_RED;
   color fpClr = (floatPL >= 0) ? C_GREEN : C_RED;
   DU("vl_dp", "$ " + DoubleToString(dailyP,  2), dpClr);
   DU("vl_cp", "$ " + DoubleToString(cumulP,  2), cpClr);
   DU("vl_fp", "$ " + DoubleToString(floatPL, 2), fpClr);

   int closed = g_sessWins + g_sessLosses;
   DU("vl_wl", IntegerToString(g_sessWins) + "W / " + IntegerToString(g_sessLosses) + "L",
      (g_sessWins >= g_sessLosses) ? C_GREEN : C_RED);
   double wr = (closed > 0) ? ((double)g_sessWins / closed * 100.0) : 0.0;
   color  wrClr = (wr >= 55) ? C_GREEN : (wr >= 45 ? C_ORANGE : C_RED);
   DU("vl_wr", DoubleToString(wr, 1) + " %", wrClr);
   DUpdBar("wr_bar", wr, wrClr);

   color ddClr = (g_drawdown < 5) ? C_GREEN : (g_drawdown < 15 ? C_ORANGE : C_RED);
   DU("vl_dd", DoubleToString(g_drawdown, 2) + " %", ddClr);
   DUpdBar("dd_bar", MathMin(g_drawdown * 5.0, 100.0), ddClr);

   DU("vl_tt", IntegerToString(g_sessTradesToday), C_WHITE);
   DUpdBar("tt_bar", MathMin((double)g_sessTradesToday * 5.0, 100.0), C_LBLUE);

   // Tier engine
   color tierClr;
   switch(tier)
   {
      case 1: tierClr = C_LBLUE;  break;
      case 2: tierClr = C_GREEN;  break;
      case 3: tierClr = C_ORANGE; break;
      case 4: tierClr = C_GOLD;   break;
      default: tierClr = C_WHITE;
   }
   DU("vl_tier", GetTierName(tier), tierClr);
   DU("vl_op",   IntegerToString(openCount) + " / " + IntegerToString(maxTrades), C_WHITE);
   DUpdBar("op_bar", (maxTrades > 0) ? ((double)openCount / maxTrades * 100.0) : 0.0, tierClr);
   DU("vl_lot",  DoubleToString(lot, 2), C_WHITE);
   DU("vl_tp",   "$ " + DoubleToString(tpUSD, 2), C_CYAN);

   // Account
   DU("vl_bal", "$ " + DoubleToString(balance,    2), C_WHITE);
   DU("vl_eq",  "$ " + DoubleToString(equity,     2), (equity >= balance) ? C_GREEN : C_RED);
   DU("vl_mg",  "$ " + DoubleToString(freeMargin, 2), C_WHITE);

   // Market
   if(g_emaFastH != INVALID_HANDLE)
   {
      ENUM_ORDER_TYPE d = GetMarketDirection();
      DU("vl_dir", (d == ORDER_TYPE_BUY ? "BUY  ▲  (Bullish)" : "SELL  ▼  (Bearish)"),
         (d == ORDER_TYPE_BUY ? C_GREEN : C_RED));
   }
   DU("vl_spr", IntegerToString(spread) + " pts",
      (spread <= InpMaxSpreadPoints) ? C_GREEN : C_RED);
   DU("vl_ses", GetSessionName(),
      (IsInSession() ? C_GREEN : C_MGRAY));

   if(g_inCooldown)
      DU("vl_cd", "Wait " + IntegerToString(g_cooldownLeft) + "s", C_ORANGE);
   else
      DU("vl_cd", "Ready", C_GREEN);

   // Footer
   DU("ft_time",
      "Server: " + TimeToString(TimeCurrent(), TIME_SECONDS) +
      "  |  Local: " + TimeToString(TimeLocal(), TIME_MINUTES),
      C_DGRAY);

   ChartRedraw(0);
}
//+------------------------------------------------------------------+
