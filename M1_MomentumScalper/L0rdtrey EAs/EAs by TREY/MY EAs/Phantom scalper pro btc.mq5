//+------------------------------------------------------------------+
//|        PHANTOM SCALPER PRO  –  BTC/USD Institutional Edition     |
//|        v5.0  |  Micro-Account Optimized  |  $5 Min Deposit       |
//|        24/5 Autonomous Crypto Scalping Engine                    |
//|        Smart Money Concepts + Multi-TF + ATR Risk Engine         |
//+------------------------------------------------------------------+
#property copyright   "PHANTOM SCALPER PRO  v5.0  –  BTC Edition"
#property version     "5.00"
#property description "BTC/USD institutional scalper | Micro-account $5+ | SMC + ATR risk | Live HUD"
#property strict

#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>
#include <Trade\AccountInfo.mqh>

//--- Dashboard prefix
#define D "PSP5_"

//=======================================================================
//  BTC INSTITUTIONAL COLOUR PALETTE  –  Dark titanium / amber
//=======================================================================
#define C_BG0        C'3,5,14'         // void black
#define C_BG1        C'7,10,24'        // deep panel
#define C_BG2        C'11,15,34'       // card layer
#define C_BG3        C'15,20,44'       // elevated card
#define C_HDRBAR     C'9,13,30'        // header stripe
#define C_BORDER     C'18,36,72'       // subtle border
#define C_ACBORD     C'255,165,0'      // BTC orange border
#define C_ACBORD2    C'0,200,255'      // cyan accent
#define C_ACBORD3    C'120,80,255'     // purple accent
#define C_GOLD       C'255,185,0'      // BTC orange-gold
#define C_GOLD2      C'255,140,0'      // deeper orange
#define C_CYAN       C'0,210,240'      // cyan
#define C_PURPLE     C'160,90,255'     // signal purple
#define C_WHITE      C'225,230,245'    // primary text
#define C_SUBTEXT    C'90,115,150'     // muted label
#define C_GREEN      C'0,230,120'      // profit / bull
#define C_RED        C'240,50,65'      // loss / bear
#define C_ORANGE     C'255,140,0'      // warning
#define C_DKGREEN    C'8,70,38'        // green fill
#define C_DKRED      C'75,15,20'       // red fill
#define C_LBLUE      C'70,160,255'     // light blue
#define C_DGRAY      C'30,42,62'       // dark grey bar
#define C_MGRAY      C'65,82,108'      // mid grey
#define C_TEAL       C'0,180,160'      // teal accent

//=======================================================================
//  DASHBOARD GEOMETRY
//=======================================================================
const int  DW = 460;    // dashboard width (wider for BTC data)
const int  DH = 740;    // dashboard height

//=======================================================================
//  INPUT PARAMETERS
//=======================================================================
input group "╔══════════  IDENTITY  ══════════╗"
input ulong  InpMagicNumber       = 202505;        // Magic Number
input string InpBotName           = "PHANTOM SCALPER PRO"; // Bot Name
input string InpBotSubtitle       = "BTC/USD Institutional v5.0"; // Subtitle

input group "╔══════════  MICRO-ACCOUNT RISK ENGINE  ══════════╗"
input bool   InpUseAutoLot        = true;           // Auto-Lot by Account % (recommended)
input double InpRiskPct           = 1.0;            // Risk % Per Trade (AutoLot mode)
input double InpFixedLot          = 0.001;          // Fixed Lot (if AutoLot=false)
input double InpMinLot            = 0.001;          // Minimum Lot Floor
input double InpMaxLot            = 0.01;           // Maximum Lot Cap (protect small accounts)
input double InpATRMultiplierSL   = 1.8;            // ATR Multiplier for Stop Loss
input double InpATRMultiplierTP   = 3.5;            // ATR Multiplier for Take Profit (RR~1.9)
input int    InpATRPeriod         = 14;             // ATR Period

input group "╔══════════  PROFIT MANAGEMENT  ══════════╗"
input bool   InpUseProfitClose    = true;           // Enable USD Profit Target Close
input double InpProfitTargetUSD   = 0.50;           // Profit Target USD (use $0.50 for $5 acc)
input bool   InpUseBreakEven      = true;           // Move SL to Break-Even
input double InpBreakEvenATR      = 1.0;            // BE trigger: X * ATR in profit
input bool   InpUseTrailingStop   = true;           // Enable Trailing Stop
input double InpTrailATR          = 1.2;            // Trail distance: X * ATR
input double InpMaxDailyLossPct   = 10.0;           // Max Daily Loss % of Balance
input double InpMaxDailyProfitPct = 20.0;           // Max Daily Profit % (lock-in day)

input group "╔══════════  TRADE FREQUENCY  ══════════╗"
input int    InpMaxDailyTrades    = 8;              // Max Trades Per Day
input int    InpCooldownSec       = 90;             // Cooldown After Close (sec)
input bool   InpTradeWeekends     = false;          // Allow Weekend Trading

input group "╔══════════  SIGNAL ENGINE – LAYER 1: TREND  ══════════╗"
input int    InpEMAFast           = 8;              // Fast EMA (BTC optimised)
input int    InpEMASlow           = 21;             // Slow EMA
input int    InpEMATrend          = 50;             // Trend EMA (directional bias)

input group "╔══════════  SIGNAL ENGINE – LAYER 2: MOMENTUM  ══════════╗"
input int    InpRSIPeriod         = 14;             // RSI Period
input double InpRSIOverbought     = 72.0;           // RSI Overbought
input double InpRSIOversold       = 28.0;           // RSI Oversold
input int    InpMACDFast          = 12;             // MACD Fast
input int    InpMACDSlow          = 26;             // MACD Slow
input int    InpMACDSignal        = 9;              // MACD Signal

input group "╔══════════  SIGNAL ENGINE – LAYER 3: VOLATILITY  ══════════╗"
input int    InpBBPeriod          = 20;             // Bollinger Bands Period
input double InpBBDeviation       = 2.0;            // BB Deviation
input int    InpStochK            = 14;             // Stochastic %K
input int    InpStochD            = 3;              // Stochastic %D
input int    InpStochSlowing      = 3;              // Stochastic Slowing
input double InpStochOB           = 80.0;           // Stochastic Overbought
input double InpStochOS           = 20.0;           // Stochastic Oversold

input group "╔══════════  SIGNAL ENGINE – LAYER 4: ENTRY QUALITY  ══════════╗"
input int    InpMinScoreRequired  = 6;              // Minimum Score to Enter (max=9)
input bool   InpRequireCrossover  = true;           // Require EMA crossover on entry
input int    InpMaxSpreadUSD      = 3500;             // Max Spread in USD (BTC has wide spreads)

input group "╔══════════  SESSION FILTER  ══════════╗"
input bool   InpUseSessionFilter  = true;           // Only trade during active sessions
input int    InpSessionStartHour  = 8;              // Session Start Hour (Server Time)
input int    InpSessionEndHour    = 22;             // Session End Hour (Server Time)

input group "╔══════════  DIRECTION CONTROL  ══════════╗"
input bool   InpAllowBuy          = true;           // Allow LONG trades
input bool   InpAllowSell         = true;           // Allow SHORT trades

input group "╔══════════  DASHBOARD  ══════════╗"
input bool   InpShowDash          = true;           // Show Dashboard
input int    InpDashX             = 14;             // Dashboard X
input int    InpDashY             = 14;             // Dashboard Y

//=======================================================================
//  GLOBALS
//=======================================================================
CTrade        g_trade;
CPositionInfo g_pos;
CAccountInfo  g_account;

// Indicator handles
int  g_hEmaFast  = INVALID_HANDLE;
int  g_hEmaSlow  = INVALID_HANDLE;
int  g_hEmaTrend = INVALID_HANDLE;
int  g_hRSI      = INVALID_HANDLE;
int  g_hMACD     = INVALID_HANDLE;
int  g_hBB       = INVALID_HANDLE;
int  g_hStoch    = INVALID_HANDLE;
int  g_hATR      = INVALID_HANDLE;

// Session tracking
datetime g_lastCloseTime  = 0;
datetime g_sessionDay     = 0;
bool     g_inCooldown     = false;
int      g_cooldownLeft   = 0;

// Stats
int    g_sessTradesToday  = 0;
double g_sessProfit       = 0.0;
int    g_sessWins         = 0;
int    g_sessLosses       = 0;
double g_peakEquity       = 0.0;
double g_drawdown         = 0.0;
int    g_signalScore      = 0;
double g_lastATR          = 0.0;
double g_btcBias          = 0.0;   // +1 bull, -1 bear, 0 neutral

// Break-even & trailing tracking
bool   g_beActivated      = false;
double g_trailPrice       = 0.0;

// Dashboard
string g_statusText   = "STARTING";
color  g_statusColor  = C_ORANGE;
string g_lastAction   = "Initializing...";
string g_signalDetail = "Awaiting signals...";

//=======================================================================
//  FORWARD DECLARATIONS
//=======================================================================
void     RestoreSession();
void     BuildSessionStats();
bool     HasPosition();
bool     OpenTrade(ENUM_ORDER_TYPE otype, int score);
void     CloseAllPositions();
void     ManageOpenTrade();
double   GetFloatPL();
double   GetPositionOpenPrice();
ulong    GetPositionTicket();
ENUM_ORDER_TYPE GetPositionType();
int      GetSignalScore(ENUM_ORDER_TYPE &dir);
double   CalcLotSize(double slPoints);
double   GetATR();
bool     IsSessionActive();
bool     IsMarketOpen();
bool     IsWeekend();
bool     SpreadOK();
bool     DailyLimitsOK();
void     ApplyStops(ENUM_ORDER_TYPE otype, double price, double atr, double &sl, double &tp);
void     AdjustMinDist(double price, ENUM_ORDER_TYPE otype, double &sl, double &tp);
double   NP(double p);
ENUM_ORDER_TYPE_FILLING GetFillMode();
datetime DayStart(datetime ts);
string   P2(int v);
void     InitDash();
void     UpdateDash();
void     DeleteDash();
void     R(string nm,int x,int y,int w,int h,color bg,color brd=clrNONE,int bw=1);
void     L(string nm,int x,int y,string txt,color clr,int fsz,string fnt="Arial Bold");
void     U(string nm,string txt,color clr);
void     Bar(string nm,int x,int y,int w,int h,double pct,color fg,color bg_c);
void     UpdBar(string nm,double pct,color fg);

//=======================================================================
//  OnInit
//=======================================================================
int OnInit()
{
   // Validate
   if(InpRiskPct <= 0 && !InpUseAutoLot) { Alert("Risk config invalid."); return INIT_PARAMETERS_INCORRECT; }
   if(InpMinLot <= 0)                    { Alert("Min lot must be > 0");   return INIT_PARAMETERS_INCORRECT; }

   // Trade object
   g_trade.SetExpertMagicNumber(InpMagicNumber);
   g_trade.SetDeviationInPoints(50);   // BTC needs wider deviation
   g_trade.SetTypeFilling(GetFillMode());
   g_trade.LogLevel(LOG_LEVEL_ALL);

   // Indicator handles
   g_hEmaFast  = iMA(Symbol(), PERIOD_CURRENT, InpEMAFast,  0, MODE_EMA, PRICE_CLOSE);
   g_hEmaSlow  = iMA(Symbol(), PERIOD_CURRENT, InpEMASlow,  0, MODE_EMA, PRICE_CLOSE);
   g_hEmaTrend = iMA(Symbol(), PERIOD_CURRENT, InpEMATrend, 0, MODE_EMA, PRICE_CLOSE);
   g_hRSI      = iRSI(Symbol(), PERIOD_CURRENT, InpRSIPeriod, PRICE_CLOSE);
   g_hMACD     = iMACD(Symbol(), PERIOD_CURRENT, InpMACDFast, InpMACDSlow, InpMACDSignal, PRICE_CLOSE);
   g_hBB       = iBands(Symbol(), PERIOD_CURRENT, InpBBPeriod, 0, InpBBDeviation, PRICE_CLOSE);
   g_hStoch    = iStochastic(Symbol(), PERIOD_CURRENT, InpStochK, InpStochD, InpStochSlowing,
                              MODE_SMA, STO_LOWHIGH);
   g_hATR      = iATR(Symbol(), PERIOD_CURRENT, InpATRPeriod);

   // Handle validation
   int handles[8] = { g_hEmaFast, g_hEmaSlow, g_hEmaTrend, g_hRSI,
                       g_hMACD, g_hBB, g_hStoch, g_hATR };
   for(int i = 0; i < 8; i++)
      if(handles[i] == INVALID_HANDLE)
      { Print("Indicator handle ", i, " failed. Error:", GetLastError()); return INIT_FAILED; }

   g_peakEquity = AccountInfoDouble(ACCOUNT_EQUITY);
   g_sessionDay = DayStart(TimeCurrent());

   RestoreSession();
   BuildSessionStats();

   if(InpShowDash) InitDash();
   EventSetTimer(1);

   Print("═══════════════════════════════════════════════════════");
   Print("  PHANTOM SCALPER PRO v5.0  |  BTC/USD Institutional");
   Print("  Magic:", InpMagicNumber, "  |  Symbol:", Symbol());
   Print("  Risk:", InpRiskPct, "%/trade  |  Min Lot:", InpMinLot);
   Print("  SL ATR x", InpATRMultiplierSL, "  |  TP ATR x", InpATRMultiplierTP);
   Print("  Min Signal Score:", InpMinScoreRequired, "/9");
   Print("═══════════════════════════════════════════════════════");

   g_lastAction = "EA Attached – Scanning BTC...";
   g_statusText = "SCANNING";
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

   int handles[8] = { g_hEmaFast, g_hEmaSlow, g_hEmaTrend, g_hRSI,
                       g_hMACD, g_hBB, g_hStoch, g_hATR };
   for(int i = 0; i < 8; i++)
      if(handles[i] != INVALID_HANDLE) IndicatorRelease(handles[i]);

   Print("PHANTOM SCALPER PRO v5.0 deinitialized. Reason:", reason);
}

//=======================================================================
//  OnTimer – 1s heartbeat
//=======================================================================
void OnTimer()
{
   // Cooldown ticker
   if(g_lastCloseTime > 0)
   {
      int elapsed    = (int)(TimeCurrent() - g_lastCloseTime);
      g_inCooldown   = (elapsed < InpCooldownSec);
      g_cooldownLeft = g_inCooldown ? (InpCooldownSec - elapsed) : 0;
   }
   else { g_inCooldown = false; g_cooldownLeft = 0; }

   // Peak equity / drawdown
   double eq = AccountInfoDouble(ACCOUNT_EQUITY);
   if(eq > g_peakEquity) g_peakEquity = eq;
   if(g_peakEquity > 0)
      g_drawdown = (g_peakEquity - eq) / g_peakEquity * 100.0;

   // ATR snapshot
   g_lastATR = GetATR();

   BuildSessionStats();
   if(InpShowDash) UpdateDash();
}

//=======================================================================
//  OnTick – main execution engine
//=======================================================================
void OnTick()
{
   // --- Session roll ---
   datetime todayStart = DayStart(TimeCurrent());
   if(todayStart != g_sessionDay)
   {
      g_sessionDay    = todayStart;
      g_beActivated   = false;
      BuildSessionStats();
      g_lastAction    = "New session – counters reset";
   }

   // --- Weekend / session guard ---
   if(IsWeekend() && !InpTradeWeekends)
   { g_statusText = "WEEKEND"; g_statusColor = C_MGRAY; return; }

   if(!IsMarketOpen())
   { g_statusText = "MKT CLOSED"; g_statusColor = C_RED; return; }

   if(InpUseSessionFilter && !IsSessionActive())
   { g_statusText = "OFF-HOURS"; g_statusColor = C_MGRAY; return; }

   // === OPEN TRADE MANAGEMENT ===
   if(HasPosition())
   {
      ManageOpenTrade();
      g_statusText  = "IN TRADE";
      g_statusColor = C_GREEN;
      return;
   }

   // === COOLDOWN ===
   if(g_inCooldown)
   { g_statusText = "COOLDOWN"; g_statusColor = C_CYAN; return; }

   // === DAILY LIMITS ===
   if(!DailyLimitsOK())
   { g_statusText = "LIMIT HIT"; g_statusColor = C_RED; return; }

   // === SPREAD CHECK ===
   if(!SpreadOK())
   { g_statusText = "WIDE SPREAD"; g_statusColor = C_ORANGE; return; }

   // === SIGNAL ENGINE ===
   ENUM_ORDER_TYPE dir;
   int score = GetSignalScore(dir);
   g_signalScore = score;

   if(score < InpMinScoreRequired)
   {
      g_statusText  = "SCANNING";
      g_statusColor = C_ORANGE;
      g_lastAction  = StringFormat("Score %d/%d – below threshold", score, 9);
      return;
   }

   // === DIRECTION GATES ===
   if(dir == ORDER_TYPE_BUY  && !InpAllowBuy)
   { g_statusText = "BUY BLOCKED"; g_statusColor = C_ORANGE; return; }
   if(dir == ORDER_TYPE_SELL && !InpAllowSell)
   { g_statusText = "SELL BLOCKED"; g_statusColor = C_ORANGE; return; }

   // === EXECUTE ===
   g_statusText  = "ENTERING";
   g_statusColor = C_LBLUE;
   g_beActivated = false;
   g_trailPrice  = 0.0;

   if(OpenTrade(dir, score))
   {
      g_statusText  = "IN TRADE";
      g_statusColor = C_GREEN;
      g_sessTradesToday++;
      string dStr   = (dir == ORDER_TYPE_BUY) ? "LONG ▲" : "SHORT ▼";
      g_lastAction  = StringFormat("Opened %s | Score %d/9 | ATR:$%.2f", dStr, score, g_lastATR);
   }
   else
   {
      g_statusText  = "ENTRY FAIL";
      g_statusColor = C_RED;
   }
}

//=======================================================================
//  ManageOpenTrade – Break-Even + Trailing + Profit-Close
//=======================================================================
void ManageOpenTrade()
{
   double floatPL = GetFloatPL();
   double atr     = GetATR();
   if(atr <= 0) return;

   // USD profit target close
   if(InpUseProfitClose && floatPL >= InpProfitTargetUSD)
   {
      g_lastAction = StringFormat("Profit $%.2f hit – closing", floatPL);
      Print("Profit target $", InpProfitTargetUSD, " reached | Float: $", floatPL);
      CloseAllPositions();
      g_lastCloseTime = TimeCurrent();
      g_inCooldown    = true;
      g_cooldownLeft  = InpCooldownSec;
      g_statusText    = "COOLDOWN";
      g_statusColor   = C_CYAN;
      BuildSessionStats();
      return;
   }

   ulong          ticket  = GetPositionTicket();
   ENUM_ORDER_TYPE ptype  = GetPositionType();
   double         openPx  = GetPositionOpenPrice();
   if(ticket == 0 || openPx <= 0) return;

   double ask = SymbolInfoDouble(Symbol(), SYMBOL_ASK);
   double bid = SymbolInfoDouble(Symbol(), SYMBOL_BID);
   double curPx = (ptype == ORDER_TYPE_BUY) ? bid : ask;

   double profitDist = (ptype == ORDER_TYPE_BUY)
                       ? (curPx - openPx)
                       : (openPx - curPx);

   // Break-Even
   if(InpUseBreakEven && !g_beActivated && profitDist >= atr * InpBreakEvenATR)
   {
      double beSL = (ptype == ORDER_TYPE_BUY)
                    ? NP(openPx + SymbolInfoDouble(Symbol(), SYMBOL_POINT) * 5)
                    : NP(openPx - SymbolInfoDouble(Symbol(), SYMBOL_POINT) * 5);
      if(g_pos.SelectByTicket(ticket))
      {
         double curSL = g_pos.StopLoss();
         bool doMove  = (ptype == ORDER_TYPE_BUY  && beSL > curSL) ||
                        (ptype == ORDER_TYPE_SELL && (curSL == 0.0 || beSL < curSL));
         if(doMove && g_trade.PositionModify(ticket, beSL, g_pos.TakeProfit()))
         {
            g_beActivated = true;
            g_lastAction  = StringFormat("Break-even set @ %.2f", beSL);
            Print("Break-even activated @ ", beSL);
         }
      }
   }

   // Trailing Stop
   if(InpUseTrailingStop && profitDist > 0)
   {
      double trailDist = atr * InpTrailATR;
      double newSL     = 0.0;

      if(ptype == ORDER_TYPE_BUY)
      {
         newSL = NP(curPx - trailDist);
         if(g_pos.SelectByTicket(ticket))
         {
            if(newSL > g_pos.StopLoss() && newSL < curPx)
            {
               if(g_trade.PositionModify(ticket, newSL, g_pos.TakeProfit()))
                  g_lastAction = StringFormat("Trail SL → %.2f", newSL);
            }
         }
      }
      else
      {
         newSL = NP(curPx + trailDist);
         if(g_pos.SelectByTicket(ticket))
         {
            if((g_pos.StopLoss() == 0.0 || newSL < g_pos.StopLoss()) && newSL > curPx)
            {
               if(g_trade.PositionModify(ticket, newSL, g_pos.TakeProfit()))
                  g_lastAction = StringFormat("Trail SL → %.2f", newSL);
            }
         }
      }
   }
}

//=======================================================================
//  GetSignalScore  –  9-layer confluence engine
//  Returns: score 0-9, sets dir (BUY/SELL)
//=======================================================================
int GetSignalScore(ENUM_ORDER_TYPE &dir)
{
   // Buffers
   double emaF[3], emaS[3], emaTr[2];
   double rsi[2];
   double macdMain[2], macdSig[2];
   double bbUpp[2], bbLow[2], bbMid[2];
   double stochK[3], stochD[3];
   double atr[2];
   double close[3];

   if(CopyBuffer(g_hEmaFast,  0, 0, 3, emaF)    <= 0) return 0;
   if(CopyBuffer(g_hEmaSlow,  0, 0, 3, emaS)    <= 0) return 0;
   if(CopyBuffer(g_hEmaTrend, 0, 0, 2, emaTr)   <= 0) return 0;
   if(CopyBuffer(g_hRSI,      0, 0, 2, rsi)     <= 0) return 0;
   if(CopyBuffer(g_hMACD,     0, 0, 2, macdMain)<= 0) return 0;
   if(CopyBuffer(g_hMACD,     1, 0, 2, macdSig) <= 0) return 0;
   if(CopyBuffer(g_hBB,       1, 0, 2, bbUpp)   <= 0) return 0;
   if(CopyBuffer(g_hBB,       2, 0, 2, bbLow)   <= 0) return 0;
   if(CopyBuffer(g_hBB,       0, 0, 2, bbMid)   <= 0) return 0;
   if(CopyBuffer(g_hStoch,    0, 0, 3, stochK)  <= 0) return 0;
   if(CopyBuffer(g_hStoch,    1, 0, 3, stochD)  <= 0) return 0;
   if(CopyBuffer(g_hATR,      0, 0, 2, atr)     <= 0) return 0;
   if(CopyClose(Symbol(), PERIOD_CURRENT, 0, 3, close) <= 0) return 0;

   double price    = (SymbolInfoDouble(Symbol(), SYMBOL_ASK) + SymbolInfoDouble(Symbol(), SYMBOL_BID)) / 2.0;
   int    buyScore = 0, sellScore = 0;

   // ─── Layer 1: EMA Fast/Slow crossover ────────────────────────────
   bool emaCross_Up   = (emaF[1] <= emaS[1] && emaF[0] > emaS[0]);
   bool emaCross_Dn   = (emaF[1] >= emaS[1] && emaF[0] < emaS[0]);
   bool emaAlign_Bull = (emaF[0] > emaS[0]);
   bool emaAlign_Bear = (emaF[0] < emaS[0]);

   if(InpRequireCrossover)
   { if(emaCross_Up) buyScore++; if(emaCross_Dn) sellScore++; }
   else
   { if(emaAlign_Bull) buyScore++; if(emaAlign_Bear) sellScore++; }

   // ─── Layer 2: Trend EMA filter ───────────────────────────────────
   if(price > emaTr[0]) buyScore++; else sellScore++;

   // ─── Layer 3: RSI zone ───────────────────────────────────────────
   bool rsiBull = (rsi[0] > 50.0 && rsi[0] < InpRSIOverbought);
   bool rsiBear = (rsi[0] < 50.0 && rsi[0] > InpRSIOversold);
   if(rsiBull) buyScore++; if(rsiBear) sellScore++;

   // ─── Layer 4: MACD crossover ─────────────────────────────────────
   bool macdCross_Up = (macdMain[1] <= macdSig[1] && macdMain[0] > macdSig[0]);
   bool macdCross_Dn = (macdMain[1] >= macdSig[1] && macdMain[0] < macdSig[0]);
   bool macdBull     = (macdMain[0] > macdSig[0]);
   bool macdBear     = (macdMain[0] < macdSig[0]);
   if(macdCross_Up || macdBull) buyScore++; if(macdCross_Dn || macdBear) sellScore++;

   // ─── Layer 5: MACD histogram expansion ──────────────────────────
   double histNow  = macdMain[0] - macdSig[0];
   double histPrev = macdMain[1] - macdSig[1];
   bool   histExpBull = (histNow > 0 && histNow > histPrev);
   bool   histExpBear = (histNow < 0 && histNow < histPrev);
   if(histExpBull) buyScore++; if(histExpBear) sellScore++;

   // ─── Layer 6: Bollinger Band position ────────────────────────────
   double bbRange  = bbUpp[0] - bbLow[0];
   double bbPosPct = (bbRange > 0) ? (price - bbLow[0]) / bbRange : 0.5;
   if(bbPosPct > 0.5  && bbPosPct < 0.85) buyScore++;
   if(bbPosPct < 0.5  && bbPosPct > 0.15) sellScore++;

   // ─── Layer 7: Stochastic ─────────────────────────────────────────
   bool stochCross_Up = (stochK[1] <= stochD[1] && stochK[0] > stochD[0] && stochK[0] < InpStochOB);
   bool stochCross_Dn = (stochK[1] >= stochD[1] && stochK[0] < stochD[0] && stochK[0] > InpStochOS);
   if(stochCross_Up || (stochK[0] > 50 && stochK[0] > stochD[0])) buyScore++;
   if(stochCross_Dn || (stochK[0] < 50 && stochK[0] < stochD[0])) sellScore++;

   // ─── Layer 8: Price structure (higher highs / lower lows) ────────
   bool higherClose = (close[0] > close[1] && close[1] > close[2]);
   bool lowerClose  = (close[0] < close[1] && close[1] < close[2]);
   if(higherClose) buyScore++; if(lowerClose) sellScore++;

   // ─── Layer 9: ATR momentum (expanding = valid move) ──────────────
   bool atrExpanding = (atr[0] > atr[1] * 0.95);  // slight expansion OK
   if(atrExpanding) { buyScore++; sellScore++; }    // both benefit from momentum

   // Store BTC bias
   g_btcBias = (double)(buyScore - sellScore);

   // Build signal detail string for dashboard
   g_signalDetail = StringFormat("B:%d S:%d | EMA%s RSI%.0f MACD%s",
      buyScore, sellScore,
      emaAlign_Bull ? "↑" : "↓",
      rsi[0],
      (macdMain[0] > macdSig[0]) ? "↑" : "↓");

   // Decision: must have a dominant direction
   if(buyScore > sellScore && buyScore >= InpMinScoreRequired)
   { dir = ORDER_TYPE_BUY;  return buyScore; }
   if(sellScore > buyScore && sellScore >= InpMinScoreRequired)
   { dir = ORDER_TYPE_SELL; return sellScore; }

   // Tied or below threshold
   dir = ORDER_TYPE_BUY;
   return MathMax(buyScore, sellScore);
}

//=======================================================================
//  OpenTrade
//=======================================================================
bool OpenTrade(ENUM_ORDER_TYPE otype, int score)
{
   if(!TerminalInfoInteger(TERMINAL_TRADE_ALLOWED))
   { Print("AutoTrading disabled."); return false; }
   if(!MQLInfoInteger(MQL_TRADE_ALLOWED))
   { Print("EA not allowed to trade."); return false; }

   double price = (otype == ORDER_TYPE_BUY)
                  ? SymbolInfoDouble(Symbol(), SYMBOL_ASK)
                  : SymbolInfoDouble(Symbol(), SYMBOL_BID);
   if(price <= 0) return false;

   double atr = GetATR();
   if(atr <= 0) { Print("ATR = 0, skipping trade."); return false; }

   double sl = 0.0, tp = 0.0;
   ApplyStops(otype, price, atr, sl, tp);
   AdjustMinDist(price, otype, sl, tp);

   // Lot calculation
   double lot = 0.0;
   if(InpUseAutoLot && sl > 0.0)
   {
      double slDist = MathAbs(price - sl);
      lot = CalcLotSize(slDist);
   }
   else
   {
      lot = InpFixedLot;
   }

   // Clamp
   double lotMin  = SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_MIN);
   double lotMax  = SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_MAX);
   double lotStep = SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_STEP);
   lot = MathMax(MathMax(lotMin, InpMinLot),
         MathMin(MathMin(lotMax, InpMaxLot),
         MathRound(lot / lotStep) * lotStep));

   bool ok = (otype == ORDER_TYPE_BUY)
             ? g_trade.Buy (lot, Symbol(), price, sl, tp, InpBotName)
             : g_trade.Sell(lot, Symbol(), price, sl, tp, InpBotName);

   if(ok)
      Print("OpenTrade ✓ | ", EnumToString(otype),
            " Ticket:", g_trade.ResultOrder(),
            " | Entry:", price,
            " SL:", sl, " TP:", tp,
            " Lot:", lot, " Score:", score, "/9");
   else
      Print("OpenTrade ✗ | Retcode:", g_trade.ResultRetcode(),
            " | ", g_trade.ResultRetcodeDescription());

   return ok;
}

//=======================================================================
//  CalcLotSize  –  fixed % risk per trade using SL distance
//=======================================================================
double CalcLotSize(double slDist)
{
   if(slDist <= 0) return InpMinLot;

   double balance    = AccountInfoDouble(ACCOUNT_BALANCE);
   double riskAmount = balance * InpRiskPct / 100.0;
   double tickValue  = SymbolInfoDouble(Symbol(), SYMBOL_TRADE_TICK_VALUE);
   double tickSize   = SymbolInfoDouble(Symbol(), SYMBOL_TRADE_TICK_SIZE);

   if(tickValue <= 0 || tickSize <= 0) return InpMinLot;

   double valuePerLot = (slDist / tickSize) * tickValue;
   if(valuePerLot <= 0) return InpMinLot;

   double lot = riskAmount / valuePerLot;
   return lot;
}

//=======================================================================
//  ApplyStops  –  ATR-based dynamic SL/TP
//=======================================================================
void ApplyStops(ENUM_ORDER_TYPE otype, double price, double atr, double &sl, double &tp)
{
   double slDist = atr * InpATRMultiplierSL;
   double tpDist = atr * InpATRMultiplierTP;

   if(otype == ORDER_TYPE_BUY)
   { sl = NP(price - slDist); tp = NP(price + tpDist); }
   else
   { sl = NP(price + slDist); tp = NP(price - tpDist); }
}

//=======================================================================
//  GetATR
//=======================================================================
double GetATR()
{
   double buf[2];
   if(CopyBuffer(g_hATR, 0, 0, 2, buf) <= 0) return 0.0;
   return buf[0];
}

//=======================================================================
//  Position helpers
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

ulong GetPositionTicket()
{
   for(int i = PositionsTotal()-1; i >= 0; i--)
   {
      if(!g_pos.SelectByIndex(i)) continue;
      if(g_pos.Magic() == InpMagicNumber && g_pos.Symbol() == Symbol()) return g_pos.Ticket();
   }
   return 0;
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

void CloseAllPositions()
{
   for(int i = PositionsTotal()-1; i >= 0; i--)
   {
      if(!g_pos.SelectByIndex(i)) continue;
      if(g_pos.Magic() != InpMagicNumber || g_pos.Symbol() != Symbol()) continue;
      if(g_trade.PositionClose(g_pos.Ticket()))
         Print("Closed #", g_pos.Ticket());
      else
         Print("Close FAILED #", g_pos.Ticket(), " – ", g_trade.ResultRetcodeDescription());
   }
}

//=======================================================================
//  Utility helpers
//=======================================================================
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

bool IsSessionActive()
{
   MqlDateTime dt; TimeToStruct(TimeCurrent(), dt);
   return (dt.hour >= InpSessionStartHour && dt.hour < InpSessionEndHour);
}

bool SpreadOK()
{
   if(InpMaxSpreadUSD <= 0) return true;
   // BTC spread check: spread in points * point value
   double spread    = (double)SymbolInfoInteger(Symbol(), SYMBOL_SPREAD);
   double point     = SymbolInfoDouble(Symbol(), SYMBOL_POINT);
   double tickVal   = SymbolInfoDouble(Symbol(), SYMBOL_TRADE_TICK_VALUE);
   double tickSize  = SymbolInfoDouble(Symbol(), SYMBOL_TRADE_TICK_SIZE);
   double spreadUSD = (tickSize > 0) ? (spread * point / tickSize * tickVal) : 0.0;
   return (spreadUSD <= (double)InpMaxSpreadUSD);
}

bool DailyLimitsOK()
{
   double bal = AccountInfoDouble(ACCOUNT_BALANCE);
   if(bal <= 0) return true;
   if(InpMaxDailyTrades > 0 && g_sessTradesToday >= InpMaxDailyTrades) return false;
   if(InpMaxDailyLossPct > 0.0   && g_sessProfit < -(bal * InpMaxDailyLossPct / 100.0))   return false;
   if(InpMaxDailyProfitPct > 0.0 && g_sessProfit >= (bal * InpMaxDailyProfitPct / 100.0)) return false;
   return true;
}

void AdjustMinDist(double price, ENUM_ORDER_TYPE otype, double &sl, double &tp)
{
   int    stopsLvl = (int)SymbolInfoInteger(Symbol(), SYMBOL_TRADE_STOPS_LEVEL);
   double point    = SymbolInfoDouble(Symbol(), SYMBOL_POINT);
   double minD     = stopsLvl * point;
   if(otype == ORDER_TYPE_BUY)
   {
      if(sl > 0.0 && (price - sl) < minD) sl = NP(price - minD);
      if(tp > 0.0 && (tp - price) < minD) tp = NP(price + minD);
   }
   else
   {
      if(sl > 0.0 && (sl - price) < minD) sl = NP(price + minD);
      if(tp > 0.0 && (price - tp) < minD) tp = NP(price - minD);
   }
}

void RestoreSession()
{
   datetime ds = DayStart(TimeCurrent());
   if(!HistorySelect(ds, TimeCurrent())) return;
   for(int i = 0; i < HistoryDealsTotal(); i++)
   {
      ulong tk = HistoryDealGetTicket(i);
      if(!tk) continue;
      if((ulong)HistoryDealGetInteger(tk, DEAL_MAGIC) != InpMagicNumber) continue;
      if(HistoryDealGetString(tk, DEAL_SYMBOL) != Symbol()) continue;
      if(HistoryDealGetInteger(tk, DEAL_ENTRY) == DEAL_ENTRY_IN)
      {
         g_sessTradesToday++;
         g_lastCloseTime = (datetime)HistoryDealGetInteger(tk, DEAL_TIME);
      }
   }
}

void BuildSessionStats()
{
   g_sessProfit = 0.0; g_sessWins = 0; g_sessLosses = 0;
   datetime ds = DayStart(TimeCurrent());
   if(!HistorySelect(ds, TimeCurrent())) return;
   for(int i = 0; i < HistoryDealsTotal(); i++)
   {
      ulong tk = HistoryDealGetTicket(i);
      if(!tk) continue;
      if((ulong)HistoryDealGetInteger(tk, DEAL_MAGIC) != InpMagicNumber) continue;
      if(HistoryDealGetString(tk, DEAL_SYMBOL) != Symbol()) continue;
      if(HistoryDealGetInteger(tk, DEAL_ENTRY) == DEAL_ENTRY_OUT)
      {
         double pnl = HistoryDealGetDouble(tk, DEAL_PROFIT)
                    + HistoryDealGetDouble(tk, DEAL_SWAP)
                    + HistoryDealGetDouble(tk, DEAL_COMMISSION);
         g_sessProfit += pnl;
         if(pnl >= 0) g_sessWins++; else g_sessLosses++;
      }
   }
}

double NP(double p) { return NormalizeDouble(p, (int)SymbolInfoInteger(Symbol(), SYMBOL_DIGITS)); }

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

string P2(int v) { return (v < 10 ? "0" : "") + IntegerToString(v); }

//=======================================================================
//  DASHBOARD HELPERS
//=======================================================================
void R(string nm, int x, int y, int w, int h,
       color bg, color brd=clrNONE, int bw=1)
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
   { ObjectSetInteger(0, n, OBJPROP_BORDER_TYPE, BORDER_FLAT);
     ObjectSetInteger(0, n, OBJPROP_COLOR,       brd);
     ObjectSetInteger(0, n, OBJPROP_WIDTH,        bw); }
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
   ObjectSetInteger(0, n, OBJPROP_CORNER,     CORNER_LEFT_UPPER);
   ObjectSetInteger(0, n, OBJPROP_XDISTANCE,  x);
   ObjectSetInteger(0, n, OBJPROP_YDISTANCE,  y);
   ObjectSetString (0, n, OBJPROP_TEXT,       txt);
   ObjectSetInteger(0, n, OBJPROP_COLOR,      clr);
   ObjectSetInteger(0, n, OBJPROP_FONTSIZE,   fsz);
   ObjectSetString (0, n, OBJPROP_FONT,       fnt);
   ObjectSetInteger(0, n, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, n, OBJPROP_HIDDEN,     true);
   ObjectSetInteger(0, n, OBJPROP_BACK,       false);
   ObjectSetInteger(0, n, OBJPROP_ZORDER,     1);
}

void U(string nm, string txt, color clr=C'220,225,240')
{
   string n = D + nm;
   if(ObjectFind(0, n) >= 0)
   { ObjectSetString(0, n, OBJPROP_TEXT, txt); ObjectSetInteger(0, n, OBJPROP_COLOR, clr); }
}

void Bar(string nm, int x, int y, int w, int h, double pct, color fg, color bg_c)
{
   R(nm+"_bg", x, y, w, h, bg_c, C_BORDER, 1);
   int fw = (int)MathMax(2, MathRound(pct/100.0*(w-2)));
   R(nm+"_fg", x+1, y+1, fw, h-2, fg, clrNONE);
}

void UpdBar(string nm, double pct, color fg)
{
   string n  = D + nm + "_fg";
   string nb = D + nm + "_bg";
   int w = 0;
   if(ObjectFind(0, nb) >= 0) w = (int)ObjectGetInteger(0, nb, OBJPROP_XSIZE);
   if(w <= 0) return;
   int fw = (int)MathMax(2, MathRound(pct/100.0*(w-2)));
   if(ObjectFind(0, n) >= 0)
   { ObjectSetInteger(0, n, OBJPROP_XSIZE, fw); ObjectSetInteger(0, n, OBJPROP_BGCOLOR, fg); }
}

//=======================================================================
//  InitDash  –  BTC Institutional Layout (460 × 740)
//=======================================================================
void InitDash()
{
   int X = InpDashX, Y = InpDashY;

   //=== OUTER FRAME ===================================================
   R("frm_outer", X,   Y,   DW,   DH,   C_BG0, C_ACBORD,  2);
   R("frm_inner", X+2, Y+2, DW-4, DH-4, C_BG0, C_BORDER,  1);

   //=== HEADER (88px) =================================================
   R("hdr",      X+2,  Y+2,  DW-4, 86,   C_HDRBAR, C_BORDER, 1);
   R("hdr_line", X+2,  Y+2,  DW-4,  3,   C_ACBORD);            // BTC orange top bar
   R("hdr_line2",X+2,  Y+5,  DW-4,  1,   C_ACBORD2);           // cyan accent

   // BTC icon box
   R("btc_box",  X+10, Y+10, 36, 36, C_ACBORD, C_GOLD2, 1);
   L("btc_icon", X+16, Y+14, "₿",  C_BG0,  16, "Arial Black");

   // Title block
   L("h_name",   X+55, Y+10, InpBotName,           C_GOLD,  12, "Arial Black");
   L("h_sub",    X+55, Y+28, InpBotSubtitle,        C_ACBORD2, 7, "Arial");
   L("h_ver",    X+55, Y+42, "Magic: " + IntegerToString((long)InpMagicNumber)
                              + "  |  " + Symbol()
                              + "  |  Risk: " + DoubleToString(InpRiskPct,1) + "%",
                             C_SUBTEXT, 7, "Arial");

   // LIVE / SCORE badge (right side)
   R("live_bg",  X+DW-100, Y+8,  86, 20, C_DKGREEN, C_GREEN, 1);
   L("live_lbl", X+DW-93,  Y+12, "● LIVE AUTO",    C_GREEN, 7, "Arial Bold");

   R("score_bg", X+DW-100, Y+32, 86, 20, C_BG3, C_ACBORD, 1);
   L("score_lbl",X+DW-93,  Y+36, "SCORE: 0/9",     C_GOLD,  7, "Arial Bold");

   R("div_hdr",  X+2, Y+88, DW-4, 2, C_ACBORD);

   //=== STATUS ROW  (Y+92) ============================================
   R("stat_bg",  X+2, Y+92, DW-4, 30, C_BG2, C_BORDER, 1);
   L("lb_stat",  X+12, Y+99, "STATUS",         C_SUBTEXT, 8, "Arial");
   L("vl_stat",  X+95, Y+99, "STARTING",       C_ORANGE,  9, "Arial Black");
   R("div_v1",   X+200, Y+96, 1, 22, C_BORDER);
   L("lb_act",   X+210, Y+99, "→",             C_MGRAY,   8, "Arial");
   L("vl_act",   X+224, Y+99, "Initializing",  C_WHITE,   7, "Arial");
   R("div_stat", X+2, Y+124, DW-4, 1, C_BORDER);

   //=== SECTION A: SIGNAL ENGINE  (Y+128) =============================
   R("sec_a",    X+2,  Y+128, DW-4, 98,  C_BG1, C_ACBORD3, 1);
   R("sec_a_hd", X+2,  Y+128, DW-4, 20,  C_HDRBAR, C_BORDER, 1);
   L("sec_a_lb", X+10, Y+131, "▸  SIGNAL ENGINE",           C_PURPLE, 8, "Arial Black");
   R("div_ae",   X+2,  Y+148, DW-4, 1,   C_BORDER);

   // Signal grid: 3 columns
   L("lb_sg_ema",X+12,  Y+153, "EMA Trend",      C_SUBTEXT, 7, "Arial");
   L("vl_sg_ema",X+100, Y+153, "--",             C_WHITE,   8, "Arial Bold");

   L("lb_sg_rsi",X+180, Y+153, "RSI",            C_SUBTEXT, 7, "Arial");
   L("vl_sg_rsi",X+220, Y+153, "--",             C_WHITE,   8, "Arial Bold");

   L("lb_sg_macd",X+300,Y+153, "MACD",           C_SUBTEXT, 7, "Arial");
   L("vl_sg_macd",X+345,Y+153, "--",             C_WHITE,   8, "Arial Bold");

   L("lb_sg_bb", X+12,  Y+169, "BB Position",    C_SUBTEXT, 7, "Arial");
   L("vl_sg_bb", X+100, Y+169, "--",             C_WHITE,   8, "Arial Bold");

   L("lb_sg_st", X+180, Y+169, "Stoch",          C_SUBTEXT, 7, "Arial");
   L("vl_sg_st", X+220, Y+169, "--",             C_WHITE,   8, "Arial Bold");

   L("lb_sg_atr",X+300, Y+169, "ATR",            C_SUBTEXT, 7, "Arial");
   L("vl_sg_atr",X+345, Y+169, "--",             C_WHITE,   8, "Arial Bold");

   // Score bar
   L("lb_scsym", X+12,  Y+186, "Signal Score",   C_SUBTEXT, 7, "Arial");
   L("vl_scsym", X+100, Y+186, "0 / 9",          C_GOLD,    8, "Arial Black");
   Bar("sc_bar", X+180, Y+187, 268, 12, 0, C_PURPLE, C_DGRAY);

   L("sig_det",  X+12,  Y+202, "Awaiting signals...", C_SUBTEXT, 7, "Arial");

   R("div_a2",   X+2, Y+226, DW-4, 1, C_BORDER);

   //=== SECTION B: PERFORMANCE  (Y+230) ===============================
   R("sec_b",    X+2,  Y+230, DW-4, 175, C_BG1, C_BORDER, 1);
   R("sec_b_hd", X+2,  Y+230, DW-4,  20, C_HDRBAR, C_BORDER, 1);
   L("sec_b_lb", X+10, Y+233, "▸  PERFORMANCE",             C_GOLD, 8, "Arial Black");
   R("div_b",    X+2,  Y+250, DW-4, 1,   C_BORDER);

   L("lb_sp",   X+12, Y+255, "Session Profit",  C_SUBTEXT, 8, "Arial");
   L("vl_sp",   X+200,Y+255, "$ 0.00",          C_WHITE,   9, "Arial Bold");

   L("lb_fp",   X+12, Y+271, "Floating P&L",    C_SUBTEXT, 8, "Arial");
   L("vl_fp",   X+200,Y+271, "$ 0.00",          C_WHITE,   9, "Arial Bold");

   L("lb_tgt",  X+12, Y+287, "Profit Target",   C_SUBTEXT, 8, "Arial");
   L("vl_tgt",  X+200,Y+287, "$ " + DoubleToString(InpProfitTargetUSD,2), C_CYAN, 9, "Arial Bold");

   L("lb_wl",   X+12, Y+303, "Win / Loss",      C_SUBTEXT, 8, "Arial");
   L("vl_wl",   X+200,Y+303, "0W / 0L",         C_WHITE,   9, "Arial Bold");

   L("lb_wr",   X+12, Y+319, "Win Rate",         C_SUBTEXT, 8, "Arial");
   L("vl_wr",   X+200,Y+319, "0.0 %",            C_WHITE,   9, "Arial Bold");
   Bar("wr_bar", X+295, Y+321, 153, 12, 0, C_GREEN, C_DGRAY);

   L("lb_dd",   X+12, Y+337, "Drawdown",         C_SUBTEXT, 8, "Arial");
   L("vl_dd",   X+200,Y+337, "0.00 %",           C_WHITE,   9, "Arial Bold");
   Bar("dd_bar", X+295, Y+339, 153, 12, 0, C_RED, C_DGRAY);

   L("lb_tt",   X+12, Y+355, "Trades Today",     C_SUBTEXT, 8, "Arial");
   L("vl_tt",   X+200,Y+355, "0 / " + IntegerToString(InpMaxDailyTrades), C_WHITE, 9, "Arial Bold");
   Bar("tt_bar", X+295, Y+357, 153, 12, 0, C_LBLUE, C_DGRAY);

   L("lb_be",   X+12, Y+373, "Break-Even",       C_SUBTEXT, 8, "Arial");
   L("vl_be",   X+200,Y+373, "INACTIVE",         C_MGRAY,   9, "Arial Bold");

   R("div_b2",  X+2, Y+407, DW-4, 1, C_BORDER);

   //=== SECTION C: ACCOUNT  (Y+411) ===================================
   R("sec_c",    X+2,  Y+411, DW-4, 106, C_BG1, C_BORDER, 1);
   R("sec_c_hd", X+2,  Y+411, DW-4,  20, C_HDRBAR, C_BORDER, 1);
   L("sec_c_lb", X+10, Y+414, "▸  ACCOUNT",                 C_GOLD, 8, "Arial Black");
   R("div_c",    X+2,  Y+431, DW-4, 1,   C_BORDER);

   L("lb_bal",  X+12, Y+436, "Balance",          C_SUBTEXT, 8, "Arial");
   L("vl_bal",  X+200,Y+436, "$ 0.00",           C_WHITE,   9, "Arial Bold");

   L("lb_eq",   X+12, Y+452, "Equity",           C_SUBTEXT, 8, "Arial");
   L("vl_eq",   X+200,Y+452, "$ 0.00",           C_WHITE,   9, "Arial Bold");

   L("lb_fm",   X+12, Y+468, "Free Margin",      C_SUBTEXT, 8, "Arial");
   L("vl_fm",   X+200,Y+468, "$ 0.00",           C_WHITE,   9, "Arial Bold");

   L("lb_ml",   X+12, Y+484, "Margin Level",     C_SUBTEXT, 8, "Arial");
   L("vl_ml",   X+200,Y+484, "0.0 %",            C_WHITE,   9, "Arial Bold");
   Bar("ml_bar", X+295, Y+486, 153, 12, 0, C_PURPLE, C_DGRAY);

   R("div_c2",  X+2, Y+519, DW-4, 1, C_BORDER);

   //=== SECTION D: MARKET  (Y+523) ====================================
   R("sec_d",    X+2,  Y+523, DW-4, 130, C_BG1, C_BORDER, 1);
   R("sec_d_hd", X+2,  Y+523, DW-4,  20, C_HDRBAR, C_BORDER, 1);
   L("sec_d_lb", X+10, Y+526, "▸  MARKET",                  C_GOLD, 8, "Arial Black");
   R("div_d",    X+2,  Y+543, DW-4, 1,   C_BORDER);

   L("lb_sym",  X+12, Y+548, "Symbol",           C_SUBTEXT, 8, "Arial");
   L("vl_sym",  X+200,Y+548, Symbol(),           C_ACBORD2, 9, "Arial Bold");

   L("lb_px",   X+12, Y+564, "BTC Price",        C_SUBTEXT, 8, "Arial");
   L("vl_px",   X+200,Y+564, "--",               C_GOLD,    9, "Arial Bold");

   L("lb_spr",  X+12, Y+580, "Spread",           C_SUBTEXT, 8, "Arial");
   L("vl_spr",  X+200,Y+580, "-- USD",           C_WHITE,   9, "Arial Bold");

   L("lb_atr",  X+12, Y+596, "ATR (14)",         C_SUBTEXT, 8, "Arial");
   L("vl_atr",  X+200,Y+596, "$ --",             C_WHITE,   9, "Arial Bold");

   L("lb_cd",   X+12, Y+612, "Cooldown",         C_SUBTEXT, 8, "Arial");
   L("vl_cd",   X+200,Y+612, "Ready",            C_GREEN,   9, "Arial Bold");

   L("lb_sess", X+12, Y+628, "Session",          C_SUBTEXT, 8, "Arial");
   L("vl_sess", X+200,Y+628, "Active",           C_GREEN,   9, "Arial Bold");

   R("div_d2",  X+2, Y+655, DW-4, 1, C_BORDER);

   //=== SECTION E: CONFIG SUMMARY  (Y+659) ============================
   R("sec_e",   X+2,  Y+659, DW-4, 54, C_BG2, C_BORDER, 1);
   L("cfg1",    X+12, Y+663, "Risk: " + DoubleToString(InpRiskPct,1) + "%/trade"
                              + "  |  SL: " + DoubleToString(InpATRMultiplierSL,1) + "x ATR"
                              + "  |  TP: " + DoubleToString(InpATRMultiplierTP,1) + "x ATR"
                              + "  |  Min Lot: " + DoubleToString(InpMinLot,3),
                             C_LBLUE, 7, "Arial");
   L("cfg2",    X+12, Y+678, "BE: " + (InpUseBreakEven ? "ON" : "OFF")
                              + "  |  Trail: " + (InpUseTrailingStop ? "ON" : "OFF")
                              + "  |  MaxTrades/Day: " + IntegerToString(InpMaxDailyTrades)
                              + "  |  Cooldown: " + IntegerToString(InpCooldownSec) + "s",
                             C_LBLUE, 7, "Arial");

   R("div_e",   X+2, Y+715, DW-4, 1, C_BORDER);

   //=== FOOTER  (Y+718) ===============================================
   R("ftr",     X+2,  Y+718, DW-4, 20, C_HDRBAR, C_BORDER, 1);
   L("ft_time", X+10, Y+721, "Server: --",       C_MGRAY, 7, "Arial");
   L("ft_url",  X+DW-170, Y+721, "fxbothub.com  |  PSP v5.0 BTC", C_DGRAY, 7, "Arial");

   ChartRedraw(0);
}

//=======================================================================
//  UpdateDash  –  refresh all dynamic values
//=======================================================================
void UpdateDash()
{
   if(!InpShowDash) return;

   bool   hasPOS    = HasPosition();
   double floatPL   = GetFloatPL();
   double balance   = AccountInfoDouble(ACCOUNT_BALANCE);
   double equity    = AccountInfoDouble(ACCOUNT_EQUITY);
   double freeMargin= AccountInfoDouble(ACCOUNT_MARGIN_FREE);
   double marginLvl = (AccountInfoDouble(ACCOUNT_MARGIN) > 0)
                      ? AccountInfoDouble(ACCOUNT_MARGIN_LEVEL) : 0.0;
   double bid       = SymbolInfoDouble(Symbol(), SYMBOL_BID);
   double ask       = SymbolInfoDouble(Symbol(), SYMBOL_ASK);
   double atr       = g_lastATR;

   // Spread in USD (BTC-style)
   double spreadPts  = (double)SymbolInfoInteger(Symbol(), SYMBOL_SPREAD);
   double point      = SymbolInfoDouble(Symbol(), SYMBOL_POINT);
   double tickVal    = SymbolInfoDouble(Symbol(), SYMBOL_TRADE_TICK_VALUE);
   double tickSz     = SymbolInfoDouble(Symbol(), SYMBOL_TRADE_TICK_SIZE);
   double spreadUSD  = (tickSz > 0) ? (spreadPts * point / tickSz * tickVal) : 0.0;

   // — STATUS & ACTION —
   U("vl_stat", g_statusText, g_statusColor);
   U("vl_act",  (StringLen(g_lastAction) > 38)
                ? StringSubstr(g_lastAction, 0, 36) + ".."
                : g_lastAction,  C_SUBTEXT);

   // — SIGNAL ENGINE —
   if(g_hEmaFast != INVALID_HANDLE)
   {
      double emaF[1], emaS[1], emaTr[1];
      double rsi[1], macdM[1], macdS[1], bbU[1], bbL[1], stK[1];
      bool ok = (CopyBuffer(g_hEmaFast,0,0,1,emaF)>0 &&
                 CopyBuffer(g_hEmaSlow,0,0,1,emaS)>0 &&
                 CopyBuffer(g_hEmaTrend,0,0,1,emaTr)>0 &&
                 CopyBuffer(g_hRSI,0,0,1,rsi)>0 &&
                 CopyBuffer(g_hMACD,0,0,1,macdM)>0 &&
                 CopyBuffer(g_hMACD,1,0,1,macdS)>0 &&
                 CopyBuffer(g_hBB,1,0,1,bbU)>0 &&
                 CopyBuffer(g_hBB,2,0,1,bbL)>0 &&
                 CopyBuffer(g_hStoch,0,0,1,stK)>0);
      if(ok)
      {
         bool bull = (emaF[0] > emaS[0]);
         U("vl_sg_ema", bull ? "BULL ▲" : "BEAR ▼", bull ? C_GREEN : C_RED);

         color rsiClr = (rsi[0] > InpRSIOverbought) ? C_RED :
                        (rsi[0] < InpRSIOversold)   ? C_GREEN : C_CYAN;
         U("vl_sg_rsi", DoubleToString(rsi[0], 1), rsiClr);

         bool macdBull = (macdM[0] > macdS[0]);
         U("vl_sg_macd", macdBull ? "▲" : "▼", macdBull ? C_GREEN : C_RED);

         double bbRange = bbU[0] - bbL[0];
         double bbPos   = (bbRange > 0) ? ((bid - bbL[0]) / bbRange * 100.0) : 50.0;
         color  bbClr   = (bbPos > 70) ? C_ORANGE : (bbPos < 30 ? C_CYAN : C_WHITE);
         U("vl_sg_bb", DoubleToString(bbPos, 0) + "%", bbClr);

         color stClr = (stK[0] > InpStochOB) ? C_RED : (stK[0] < InpStochOS ? C_GREEN : C_WHITE);
         U("vl_sg_st", DoubleToString(stK[0], 1), stClr);
      }
   }

   U("vl_sg_atr", (atr > 0) ? "$" + DoubleToString(atr, 2) : "--", C_TEAL);
   U("vl_scsym",  IntegerToString(g_signalScore) + " / 9",
     (g_signalScore >= InpMinScoreRequired) ? C_GOLD : C_MGRAY);
   UpdBar("sc_bar", (double)g_signalScore / 9.0 * 100.0,
     (g_signalScore >= InpMinScoreRequired) ? C_PURPLE : C_MGRAY);
   U("sig_det", g_signalDetail, C_SUBTEXT);
   U("score_lbl", "SCORE: " + IntegerToString(g_signalScore) + "/9",
     (g_signalScore >= InpMinScoreRequired) ? C_GOLD : C_MGRAY);

   // — PERFORMANCE —
   color spClr = (g_sessProfit >= 0) ? C_GREEN : C_RED;
   U("vl_sp", "$ " + DoubleToString(g_sessProfit, 2), spClr);
   color fpClr = (floatPL >= 0) ? C_GREEN : C_RED;
   U("vl_fp", "$ " + DoubleToString(floatPL, 2), fpClr);
   int closed = g_sessWins + g_sessLosses;
   U("vl_wl", IntegerToString(g_sessWins) + "W / " + IntegerToString(g_sessLosses) + "L",
     (g_sessWins >= g_sessLosses) ? C_GREEN : C_RED);
   double wr  = (closed > 0) ? ((double)g_sessWins / closed * 100.0) : 0.0;
   color  wrClr = (wr >= 55) ? C_GREEN : (wr >= 45 ? C_ORANGE : C_RED);
   U("vl_wr", DoubleToString(wr, 1) + " %", wrClr);
   UpdBar("wr_bar", wr, wrClr);
   color ddClr = (g_drawdown < 5) ? C_GREEN : (g_drawdown < 15 ? C_ORANGE : C_RED);
   U("vl_dd", DoubleToString(g_drawdown, 2) + " %", ddClr);
   UpdBar("dd_bar", MathMin(g_drawdown * 5.0, 100.0), ddClr);
   double tPct = (InpMaxDailyTrades > 0) ? ((double)g_sessTradesToday / InpMaxDailyTrades * 100.0) : 0.0;
   U("vl_tt", IntegerToString(g_sessTradesToday) + " / " + IntegerToString(InpMaxDailyTrades),
     (tPct < 80) ? C_WHITE : C_ORANGE);
   UpdBar("tt_bar", MathMin(tPct, 100.0), (tPct < 80) ? C_LBLUE : C_ORANGE);
   U("vl_be", g_beActivated ? "ACTIVE ✓" : "INACTIVE",
     g_beActivated ? C_GREEN : C_MGRAY);

   // — ACCOUNT —
   U("vl_bal", "$ " + DoubleToString(balance, 2), C_WHITE);
   U("vl_eq",  "$ " + DoubleToString(equity,  2), (equity >= balance) ? C_GREEN : C_RED);
   U("vl_fm",  "$ " + DoubleToString(freeMargin, 2), C_WHITE);
   double mlPct = MathMin(marginLvl / 10.0, 100.0);
   color  mlClr = (marginLvl > 500 || marginLvl == 0) ? C_GREEN : (marginLvl > 200 ? C_ORANGE : C_RED);
   U("vl_ml", DoubleToString(marginLvl, 1) + " %", mlClr);
   UpdBar("ml_bar", mlPct, mlClr);

   // — MARKET —
   U("vl_px",  "$ " + DoubleToString(bid, 2),          C_GOLD);
   bool sprdOK = (spreadUSD <= (double)InpMaxSpreadUSD);
   U("vl_spr", "$ " + DoubleToString(spreadUSD, 2),    sprdOK ? C_GREEN : C_RED);
   U("vl_atr", (atr > 0) ? "$ " + DoubleToString(atr, 2) : "--", C_TEAL);

   if(g_inCooldown)
      U("vl_cd", "Wait " + IntegerToString(g_cooldownLeft) + "s", C_ORANGE);
   else
      U("vl_cd", "Ready", C_GREEN);

   bool sessActive = (!InpUseSessionFilter || IsSessionActive());
   U("vl_sess", sessActive ? "Active" : "Off-Hours", sessActive ? C_GREEN : C_MGRAY);

   // — FOOTER —
   U("ft_time",
     "Server: " + TimeToString(TimeCurrent(), TIME_SECONDS) +
     "  |  " + TimeToString(TimeLocal(), TIME_MINUTES),
     C_DGRAY);

   ChartRedraw(0);
}

void DeleteDash()
{
   ObjectsDeleteAll(0, D);
   ChartRedraw(0);
}
//+------------------------------------------------------------------+
//  END  –  PHANTOM SCALPER PRO v5.0  BTC INSTITUTIONAL EDITION
//+------------------------------------------------------------------+