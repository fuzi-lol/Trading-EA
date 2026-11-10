//+------------------------------------------------------------------+
//|  PhantomScalperPro_X.mq5                                        |
//|  Professional XAUUSD Scalping System                             |
//|  v1.0 — Market Structure + SMC + Adaptive Risk + Smart Exit      |
//+------------------------------------------------------------------+
#property copyright   "PhantomScalperPro X  v1.0"
#property version     "1.00"
#property description "Professional XAUUSD Scalping | Structure + SMC | Adaptive Risk"

#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>
#include <Trade\AccountInfo.mqh>
#include "Core\StructureEngine.mqh"
#include "Core\SmartMoneyFilter.mqh"
#include "Core\SessionFilter.mqh"
#include "Core\RiskManager.mqh"
#include "Core\ExitManager.mqh"
#include "Core\Dashboard.mqh"
#include "Core\TradeDatabase.mqh"

//=======================================================================
//  INPUT PARAMETERS
//=======================================================================
input group "═══════  IDENTITY  ═══════"
input ulong  InpMagic           = 10001;
input string InpBotLabel        = "PSP-X";

input group "═══════  RISK MANAGEMENT  ═══════"
input double InpBaseRisk        = 1.0;    // Base risk per trade (% of balance)
input double InpMaxDailyLoss    = 3.0;    // Max daily loss % before halt
input double InpMaxDailyProfit  = 5.0;    // Daily profit target % (halt after)
input double InpMaxWeeklyLoss   = 6.0;    // Max weekly loss %
input double InpMaxDrawdown     = 10.0;   // Max drawdown % before halt
input int    InpMaxConsecLoss   = 4;      // Consecutive losses before pause
input int    InpPauseDuration   = 60;     // Pause duration in minutes after loss streak

input group "═══════  PROFIT TARGET  ═══════"
input double InpProfitMultiplier= 1.0;    // USD per 0.01 lot (1.0 = $1 per 0.01 lot)

input group "═══════  TRADE QUALITY  ═══════"
input double InpMinTradeScore   = 80.0;   // Minimum score to allow trade (0–100)
input double InpMinAlignment    = 0.67;   // Min MTF alignment ratio (0–1)

input group "═══════  MARKET STRUCTURE  ═══════"
input int    InpSwingLookback   = 3;      // Bars each side to confirm swing

input group "═══════  SESSION FILTERS  ═══════"
input bool   InpAllowAsian      = false;
input bool   InpAllowLondon     = true;
input bool   InpAllowNewYork    = true;
input bool   InpAllowOverlap    = true;
input int    InpBrokerGMTOffset = 2;      // Your broker's GMT offset (e.g., 2 = GMT+2)

input group "═══════  EXECUTION QUALITY  ═══════"
input int    InpMaxSpreadPts    = 30;     // Max spread in points to allow trade
input double InpMinATRRatio     = 0.5;    // Min ATR ratio (filters dead markets)
input double InpMaxATRRatio     = 3.0;    // Max ATR ratio (filters extreme moves)

input group "═══════  EXIT MANAGEMENT  ═══════"
input double InpBreakevenPct    = 0.50;   // Move to BE when this % of target reached
input double InpPartialPct      = 0.70;   // Close partial at this % of target
input double InpPartialFraction = 0.50;   // What fraction to close (0.5 = 50%)
input double InpTrailATRMult    = 1.0;    // ATR multiplier for trailing stop

input group "═══════  DASHBOARD  ═══════"
input bool   InpShowDash        = true;
input int    InpDashX           = 14;
input int    InpDashY           = 14;

input group "═══════  ALERTS  ═══════"
input bool   InpAlertTrade      = true;
input bool   InpAlertScore      = true;
input bool   InpPushNotify      = false;
input bool   InpEmailNotify     = false;

//=======================================================================
//  GLOBALS
//=======================================================================
CStructureEngine  g_structure;
CSmartMoneyFilter g_smc;
CSessionFilter    g_session;
CRiskManager      g_risk;
CExitManager      g_exit;
CDashboard        g_dash;
CTradeDatabase    g_db;

CTrade            g_trade;
CPositionInfo     g_posInfo;
CAccountInfo      g_account;

// Momentum indicators (M5 execution TF)
int g_emaFastH  = INVALID_HANDLE;
int g_emaSlowH  = INVALID_HANDLE;
int g_rsiH      = INVALID_HANDLE;

// State
datetime g_lastM5Bar    = 0;
datetime g_lastM15Bar   = 0;
datetime g_lastDay      = 0;
bool     g_inCooldown   = false;
datetime g_cooldownEnd  = 0;
int      g_cooldownSec  = 60; // Seconds after position close before re-evaluation

// Performance tracking
int    g_todayTrades   = 0;
int    g_totalWins     = 0;
int    g_totalLosses   = 0;
double g_totalPnL      = 0;
double g_profitFactor  = 0;

// Current open position tracking
double g_openProfitTarget = 0;
ENUM_SESSION g_openSession = SESSION_OFF;

// Trade state for database logging
double g_openTradeScore   = 0;
string g_openGrade        = "";
string g_openMarketState  = "";
bool   g_openHasFVG       = false;
bool   g_openHasOB        = false;
bool   g_openHasSweep     = false;

// Dashboard state
DashData g_dashData;

//=======================================================================
//  HELPERS
//=======================================================================
bool HasPosition()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--) {
      if(g_posInfo.SelectByIndex(i) &&
         g_posInfo.Magic()  == InpMagic &&
         g_posInfo.Symbol() == Symbol()) return true;
   }
   return false;
}

double GetFloatPnL()
{
   double total = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--) {
      if(g_posInfo.SelectByIndex(i) &&
         g_posInfo.Magic()  == InpMagic &&
         g_posInfo.Symbol() == Symbol()) {
         total += g_posInfo.Profit() + g_posInfo.Swap() + g_posInfo.Commission();
      }
   }
   return total;
}

ulong GetOpenTicket()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--) {
      if(g_posInfo.SelectByIndex(i) &&
         g_posInfo.Magic()  == InpMagic &&
         g_posInfo.Symbol() == Symbol()) return g_posInfo.Ticket();
   }
   return 0;
}

double NPrice(double p)
{
   return NormalizeDouble(p, (int)SymbolInfoInteger(Symbol(), SYMBOL_DIGITS));
}

ENUM_ORDER_TYPE_FILLING GetFillMode()
{
   uint f = (uint)SymbolInfoInteger(Symbol(), SYMBOL_FILLING_MODE);
   if((f & SYMBOL_FILLING_FOK) != 0) return ORDER_FILLING_FOK;
   if((f & SYMBOL_FILLING_IOC) != 0) return ORDER_FILLING_IOC;
   return ORDER_FILLING_RETURN;
}

void SendAlert(string msg, bool push = false, bool email = false)
{
   Alert(msg);
   if(push)  SendNotification(msg);
   if(email) SendMail("PSP-X Alert", msg);
}

datetime DayStart(datetime ts)
{
   MqlDateTime d; TimeToStruct(ts, d);
   return ts - (datetime)(d.hour * 3600 + d.min * 60 + d.sec);
}

//=======================================================================
//  TRADE QUALITY SCORING
//=======================================================================
struct TradeQuality {
   double  score;         // 0–100 composite
   string  grade;         // A+, A, B, C, REJECT
   bool    canTrade;
   // Component breakdown for dashboard
   double  structureScore;
   double  smcScore;
   double  momentumScore;
   double  sessionScore;
   double  volatilityScore;
   bool    forBuy;
};

double GetMomentumScore(bool forBuy)
{
   double emaF[1], emaS[1], rsi[1];
   if(CopyBuffer(g_emaFastH, 0, 1, 1, emaF) < 1) return 50;
   if(CopyBuffer(g_emaSlowH, 0, 1, 1, emaS) < 1) return 50;
   if(CopyBuffer(g_rsiH,     0, 1, 1, rsi)  < 1) return 50;

   double score = 0;
   bool emaAligned = forBuy ? (emaF[0] > emaS[0]) : (emaF[0] < emaS[0]);
   bool rsiAligned = forBuy ? (rsi[0] > 50 && rsi[0] < 75) : (rsi[0] < 50 && rsi[0] > 25);
   bool rsiExtreme = forBuy ? (rsi[0] >= 75) : (rsi[0] <= 25); // Overextended

   if(emaAligned)  score += 50;
   if(rsiAligned)  score += 35;
   if(rsiExtreme)  score -= 30; // Penalty for chasing

   // RSI divergence from 50 adds confidence
   double rsiStrength = MathAbs(rsi[0] - 50.0) / 50.0;
   score += rsiStrength * 15;

   return MathMax(0, MathMin(100, score));
}

TradeQuality EvaluateTrade(bool forBuy)
{
   TradeQuality q;
   ZeroMemory(q);
   q.forBuy = forBuy;

   // 1. Multi-timeframe structure (40% weight)
   q.structureScore = g_structure.GetStructureScore(forBuy);
   double alignScore = g_structure.GetAlignmentScore(forBuy) * 100.0;

   // 2. SMC filters (25% weight)
   SMCSignal smcSig = g_smc.GetSignal(forBuy);
   q.smcScore = smcSig.smcScore;

   // 3. Momentum (20% weight)
   q.momentumScore = GetMomentumScore(forBuy);

   // 4. Session (10% weight)
   q.sessionScore = g_session.GetSessionScore();

   // 5. Volatility (5% weight)
   VolatilityState vs = g_session.GetVolatilityState();
   q.volatilityScore = vs.volatilityScore;

   // Weighted composite
   q.score = (q.structureScore * 0.40) +
             (q.smcScore       * 0.25) +
             (q.momentumScore  * 0.20) +
             (q.sessionScore   * 0.10) +
             (q.volatilityScore* 0.05);

   // Alignment penalty: poor MTF alignment hard-caps the score
   if(alignScore < 67.0) q.score *= 0.70; // <2/3 aligned = 30% penalty

   q.score = MathMin(q.score, 100.0);

   // Grade
   if(q.score >= 90)          q.grade = "A+";
   else if(q.score >= 85)     q.grade = "A";
   else if(q.score >= InpMinTradeScore) q.grade = "B";
   else if(q.score >= 65)     q.grade = "C";
   else                       q.grade = "REJECT";

   q.canTrade = (q.score >= InpMinTradeScore) &&
                g_structure.IsTradeableCondition() &&
                (g_structure.GetAlignmentScore(forBuy) >= InpMinAlignment);

   return q;
}

//=======================================================================
//  EXECUTION
//=======================================================================
bool OpenTrade(bool forBuy, const RiskSnapshot &risk)
{
   if(risk.lotSize <= 0) { Print("OpenTrade: Invalid lot size"); return false; }

   double price = forBuy ? SymbolInfoDouble(Symbol(), SYMBOL_ASK)
                         : SymbolInfoDouble(Symbol(), SYMBOL_BID);
   if(price <= 0) return false;

   double point  = SymbolInfoDouble(Symbol(), SYMBOL_POINT);
   double spread = SymbolInfoDouble(Symbol(), SYMBOL_SPREAD) * point;

   // SL from ATR
   double slDist = risk.slPoints * point;
   double sl = forBuy ? NPrice(price - slDist) : NPrice(price + slDist);

   // TP: minimum 1.5R
   double tpDist = slDist * 1.5;
   double tp = forBuy ? NPrice(price + tpDist) : NPrice(price - tpDist);

   // Verify stops meet broker minimum
   int minStop = (int)SymbolInfoInteger(Symbol(), SYMBOL_TRADE_STOPS_LEVEL);
   double minDist = (minStop + 5) * point;
   if(forBuy) {
      if((price - sl) < minDist) sl = NPrice(price - minDist);
      if((tp - price) < minDist) tp = NPrice(price + minDist);
   } else {
      if((sl - price) < minDist) sl = NPrice(price + minDist);
      if((price - tp) < minDist) tp = NPrice(price - minDist);
   }

   bool ok;
   if(forBuy) ok = g_trade.Buy(risk.lotSize,  Symbol(), price, sl, tp, InpBotLabel);
   else       ok = g_trade.Sell(risk.lotSize, Symbol(), price, sl, tp, InpBotLabel);

   if(!ok) {
      Print("OpenTrade FAILED: ", g_trade.ResultRetcodeDescription(),
            " | Bid=", SymbolInfoDouble(Symbol(), SYMBOL_BID),
            " Ask=", SymbolInfoDouble(Symbol(), SYMBOL_ASK),
            " SL=", sl, " TP=", tp, " Lot=", risk.lotSize);
      return false;
   }

   ulong ticket = g_trade.ResultDeal();

   // Calculate dollar profit target
   double profitTarget = g_risk.GetProfitTarget(risk.lotSize);

   // Register with exit manager
   g_exit.RegisterPosition(ticket, price, sl, tp, risk.lotSize, profitTarget,
                            forBuy ? ORDER_TYPE_BUY : ORDER_TYPE_SELL);

   g_openProfitTarget = profitTarget;
   g_openSession      = g_session.GetCurrentSession();

   // Capture context for trade database logging on close
   g_openTradeScore  = 0; // will be set by caller
   g_openGrade       = "";
   g_openMarketState = "";
   g_todayTrades++;

   string msg = StringFormat("PSP-X: %s OPEN | Lot: %.2f | SL: %.5f | TP: %.5f | Target: $%.2f",
                             forBuy ? "BUY" : "SELL", risk.lotSize, sl, tp, profitTarget);
   Print(msg);
   if(InpAlertTrade) SendAlert(msg, InpPushNotify, InpEmailNotify);

   return true;
}

void CloseAllPositions(string reason)
{
   for(int i = PositionsTotal() - 1; i >= 0; i--) {
      if(!g_posInfo.SelectByIndex(i)) continue;
      if(g_posInfo.Magic()  != InpMagic) continue;
      if(g_posInfo.Symbol() != Symbol()) continue;
      double pnl = g_posInfo.Profit() + g_posInfo.Swap() + g_posInfo.Commission();
      g_trade.PositionClose(g_posInfo.Ticket());
      Print("PSP-X: Close (", reason, ") | PnL: $", NormalizeDouble(pnl, 2));
   }

   g_cooldownEnd    = TimeCurrent() + g_cooldownSec;
   g_inCooldown     = true;
   g_openProfitTarget = 0;
}

//=======================================================================
//  PERFORMANCE STATS (from history)
//=======================================================================
void BuildPerformanceStats()
{
   g_todayTrades = 0; g_totalWins = 0; g_totalLosses = 0;
   g_totalPnL = 0; g_profitFactor = 0;

   datetime dayStart = DayStart(TimeCurrent());
   if(!HistorySelect(dayStart, TimeCurrent())) return;

   double totalGain = 0, totalLoss = 0;

   for(int i = 0; i < HistoryDealsTotal(); i++) {
      ulong tk = HistoryDealGetTicket(i);
      if(HistoryDealGetInteger(tk, DEAL_MAGIC)  != (long)InpMagic) continue;
      if(HistoryDealGetString(tk,  DEAL_SYMBOL) != Symbol()) continue;
      if(HistoryDealGetInteger(tk, DEAL_ENTRY)  != DEAL_ENTRY_OUT) continue;

      double pnl = HistoryDealGetDouble(tk, DEAL_PROFIT)
                 + HistoryDealGetDouble(tk, DEAL_SWAP)
                 + HistoryDealGetDouble(tk, DEAL_COMMISSION);

      g_totalPnL += pnl;
      g_todayTrades++;
      if(pnl >= 0) { g_totalWins++;  totalGain += pnl; }
      else         { g_totalLosses++; totalLoss += MathAbs(pnl); }
   }

   g_profitFactor = (totalLoss > 0) ? totalGain / totalLoss : (totalGain > 0 ? 999 : 0);
}

//=======================================================================
//  OnInit
//=======================================================================
int OnInit()
{
   if(StringFind(Symbol(), "XAU") < 0 && StringFind(Symbol(), "Gold") < 0 &&
      StringFind(Symbol(), "GOLD") < 0) {
      Print("WARNING: This EA is tuned for XAUUSD. Current symbol: ", Symbol());
      // Not a hard stop — allow user to run on similar instruments
   }

   // Initialize modules
   g_structure.Init(Symbol(), InpSwingLookback);
   g_smc.Init(Symbol(), PERIOD_M15, PERIOD_M5, 60);
   g_session.Init(Symbol(), InpMaxSpreadPts, InpMinATRRatio, InpMaxATRRatio,
                  InpBrokerGMTOffset);
   g_risk.Init(Symbol(), InpMagic,
               InpBaseRisk, InpMaxDailyLoss, InpMaxDailyProfit,
               InpMaxWeeklyLoss, InpMaxDrawdown, InpMaxConsecLoss, InpPauseDuration,
               InpProfitMultiplier);
   g_exit.Init(Symbol(), InpMagic,
               InpBreakevenPct, InpPartialPct, InpPartialFraction, InpTrailATRMult);

   // Momentum indicators
   g_emaFastH = iMA(Symbol(), PERIOD_M5, 9,  0, MODE_EMA, PRICE_CLOSE);
   g_emaSlowH = iMA(Symbol(), PERIOD_M5, 21, 0, MODE_EMA, PRICE_CLOSE);
   g_rsiH     = iRSI(Symbol(), PERIOD_M5, 14, PRICE_CLOSE);

   if(g_emaFastH == INVALID_HANDLE || g_emaSlowH == INVALID_HANDLE || g_rsiH == INVALID_HANDLE) {
      Print("CRITICAL: Failed to create indicator handles. Check symbol/terminal.");
      return INIT_FAILED;
   }

   // Trade execution settings
   g_trade.SetExpertMagicNumber(InpMagic);
   g_trade.SetDeviationInPoints(30);
   g_trade.SetTypeFilling(GetFillMode());

   // Restore state from history
   g_risk.RebuildConsecutiveLosses();
   BuildPerformanceStats();

   // Trade database
   g_db.Init(Symbol(), InpMagic);

   // Dashboard
   if(InpShowDash) {
      g_dash.Init(InpDashX, InpDashY);
   }

   EventSetTimer(1);
   Print("PSP-X Initialized | Symbol: ", Symbol(), " | Magic: ", InpMagic);
   return INIT_SUCCEEDED;
}

//=======================================================================
//  OnDeinit
//=======================================================================
void OnDeinit(const int reason)
{
   EventKillTimer();
   if(InpShowDash) g_dash.Delete();
   if(g_emaFastH != INVALID_HANDLE) IndicatorRelease(g_emaFastH);
   if(g_emaSlowH != INVALID_HANDLE) IndicatorRelease(g_emaSlowH);
   if(g_rsiH     != INVALID_HANDLE) IndicatorRelease(g_rsiH);
}

//=======================================================================
//  OnTimer — 1-second heartbeat for dashboard and cooldown
//=======================================================================
void OnTimer()
{
   // Cooldown check
   if(g_inCooldown && TimeCurrent() >= g_cooldownEnd) {
      g_inCooldown = false;
   }

   // Risk update (checks day rollover, rebuilds PnL stats)
   g_risk.Update();

   // Dashboard update
   if(InpShowDash) {
      PopulateDashData();
      g_dash.Update(g_dashData);
   }
}

//=======================================================================
//  PopulateDashData — gather all stats for dashboard
//=======================================================================
void PopulateDashData()
{
   // Status fields are written by OnTick state machine — preserve them here,
   // but ensure they have a valid default if OnTick hasn't written yet.
   if(g_dashData.statusText == "")
      g_dashData.statusText = "INITIALIZING";
   if(g_dashData.statusColor == 0)
      g_dashData.statusColor = C_ORANGE;

   // Market state
   MarketStructure htf = g_structure.GetHTF();
   MarketStructure mtf = g_structure.GetMTF();
   g_dashData.marketState = g_structure.StateToString(htf.state);

   if(htf.bullishBias)      g_dashData.trendBias = "BULLISH";
   else if(htf.bearishBias) g_dashData.trendBias = "BEARISH";
   else                     g_dashData.trendBias = "NEUTRAL";

   // Structure event
   switch(htf.lastEvent) {
      case STRUCT_BOS_BULLISH:  g_dashData.structureBias = "BOS ▲"; break;
      case STRUCT_BOS_BEARISH:  g_dashData.structureBias = "BOS ▼"; break;
      case STRUCT_CHOCH_BULLISH:g_dashData.structureBias = "CHOCH ▲"; break;
      case STRUCT_CHOCH_BEARISH:g_dashData.structureBias = "CHOCH ▼"; break;
      default:                  g_dashData.structureBias = "RANGING"; break;
   }

   g_dashData.session = g_session.SessionName(g_session.GetCurrentSession());

   VolatilityState vs = g_session.GetVolatilityState();
   g_dashData.spread    = vs.spread;
   g_dashData.atrRatio  = vs.atrRatio;
   if(vs.atrRatio > 1.3)      g_dashData.volatilityState = "EXPANSION";
   else if(vs.atrRatio < 0.7) g_dashData.volatilityState = "COMPRESSION";
   else                       g_dashData.volatilityState = "NORMAL";

   // SMC state (use last evaluated direction)
   SMCSignal smcBuy  = g_smc.GetSignal(true);
   SMCSignal smcSell = g_smc.GetSignal(false);
   g_dashData.hasFVG   = smcBuy.hasBullishFVG || smcSell.hasBearishFVG;
   g_dashData.hasOB    = smcBuy.hasBullishOB   || smcSell.hasBearishOB;
   g_dashData.hasSweep = g_smc.HasRecentSweep();
   g_dashData.inDiscount = smcBuy.inDiscount;

   // Risk
   RiskSnapshot rsnap = g_risk.GetSnapshot(g_dashData.tradeScore > 0 ? g_dashData.tradeScore : 50);
   g_dashData.riskLevel     = rsnap.statusMessage;
   g_dashData.dailyPnL      = g_risk.GetDailyPnL();
   g_dashData.weeklyPnL     = g_risk.GetWeeklyPnL();
   g_dashData.drawdownPct   = g_risk.GetDrawdownPct();
   g_dashData.consecLosses  = g_risk.GetConsecLosses();

   // Performance
   int totalClosed = g_totalWins + g_totalLosses;
   g_dashData.winRate     = (totalClosed > 0) ? (double)g_totalWins / totalClosed * 100.0 : 0;
   g_dashData.todayTrades = g_todayTrades;

   // Open position
   g_dashData.hasPosition = HasPosition();
   if(g_dashData.hasPosition) {
      double fpnl = GetFloatPnL();
      g_dashData.floatPnL     = fpnl;
      g_dashData.profitTarget = g_openProfitTarget;
      g_dashData.pctToTarget  = (g_openProfitTarget > 0) ? fpnl / g_openProfitTarget : 0;

      ulong tk = GetOpenTicket();
      if(tk > 0 && g_posInfo.SelectByTicket(tk)) {
         // Derive phase label from profit progress
         double pct = (g_openProfitTarget > 0) ? fpnl / g_openProfitTarget : 0;
         if(pct >= 0.70)      g_dashData.exitPhase = "TRAILING";
         else if(pct >= 0.50) g_dashData.exitPhase = "BREAKEVEN";
         else                 g_dashData.exitPhase = "OPEN";
      }
   } else {
      g_dashData.floatPnL    = 0;
      g_dashData.profitTarget= 0;
      g_dashData.pctToTarget = 0;
      g_dashData.exitPhase   = "--";
   }

   // Re-entry readiness
   g_dashData.reentryReady = !g_inCooldown && !HasPosition() && g_risk.CanTrade();

   // System health
   ENUM_RISK_STATE rs = g_risk.GetRiskState();
   switch(rs) {
      case RISK_NORMAL:       g_dashData.systemHealth = "OPTIMAL";     break;
      case RISK_REDUCED:      g_dashData.systemHealth = "REDUCED";     break;
      case RISK_CONSERVATIVE: g_dashData.systemHealth = "CONSERVATIVE";break;
      case RISK_PAUSED:       g_dashData.systemHealth = "PAUSED";      break;
      case RISK_HALTED:       g_dashData.systemHealth = "HALTED";      break;
   }
}

//=======================================================================
//  OnTick — Main Execution Engine
//=======================================================================
void OnTick()
{
   //--- Day rollover check
   datetime today = DayStart(TimeCurrent());
   if(today != g_lastDay) {
      g_lastDay = today;
      BuildPerformanceStats();
      g_risk.Update();
   }

   //--- Manage open positions (runs every tick for trailing/BE)
   g_exit.Update();

   //--- If position open: check profit target
   if(HasPosition()) {
      double fpnl = GetFloatPnL();
      if(fpnl >= g_openProfitTarget && g_openProfitTarget > 0) {
         ulong closedTicket = GetOpenTicket(); // capture BEFORE close
         CloseAllPositions("ProfitTarget");

         // Record in session stats
         RiskSnapshot rsnap = g_risk.GetSnapshot(50);
         g_session.RecordTrade(g_openSession, fpnl, fpnl / (rsnap.riskPct * AccountInfoDouble(ACCOUNT_BALANCE) / 100.0));
         g_risk.OnTradeClosed(fpnl);

         BuildPerformanceStats();
         g_risk.RebuildConsecutiveLosses();

         g_db.LogTrade(
            closedTicket,
            g_openProfitTarget,
            g_openTradeScore,
            g_openGrade,
            g_session.SessionName(g_openSession),
            g_openMarketState,
            g_openHasFVG,
            g_openHasOB,
            g_openHasSweep,
            "TARGET"
         );

         g_dashData.statusText  = "TARGET HIT";
         g_dashData.statusColor = C_GREEN;
         g_dashData.lastAction  = StringFormat("Closed at $%.2f | Target: $%.2f", fpnl, g_openProfitTarget);

         if(InpAlertTrade)
            SendAlert(StringFormat("PSP-X: Profit Target Hit! PnL: $%.2f", fpnl),
                      InpPushNotify, InpEmailNotify);
      } else {
         g_dashData.statusText  = "IN TRADE";
         g_dashData.statusColor = C_GREEN;
      }
      return;
   }

   //--- No position — check for new entry on M5 bar close
   datetime currentM5Bar = iTime(Symbol(), PERIOD_M5, 1);
   if(currentM5Bar == g_lastM5Bar) return; // Not a new bar
   g_lastM5Bar = currentM5Bar;

   //--- Update structure on new bar (internal change detection)
   g_structure.Update();
   g_smc.Update();

   //--- Hard gates
   if(g_inCooldown) {
      g_dashData.statusText  = "COOLDOWN";
      g_dashData.statusColor = C_CYAN;
      g_dashData.lastAction  = StringFormat("Cooldown: %ds remaining",
                               MathMax(0,(int)(g_cooldownEnd - TimeCurrent())));
      return;
   }

   if(!g_risk.CanTrade()) {
      ENUM_RISK_STATE rs = g_risk.GetRiskState();
      if(rs == RISK_HALTED) {
         g_dashData.statusText  = "HALTED";
         g_dashData.statusColor = C_RED;
         g_dashData.lastAction  = "Daily/weekly limit reached";
      } else if(rs == RISK_PAUSED) {
         g_dashData.statusText  = "PAUSED";
         g_dashData.statusColor = C_ORANGE;
         g_dashData.lastAction  = StringFormat("Loss streak pause — %ds left",
                                  g_risk.PauseSecondsLeft());
      }
      return;
   }

   if(!g_session.GateCheck(InpAllowAsian, InpAllowLondon, InpAllowNewYork, InpAllowOverlap)) {
      g_dashData.statusText  = "GATED";
      g_dashData.statusColor = C_MGRAY;
      g_dashData.lastAction  = "Session/spread/volatility gate";
      return;
   }

   if(!g_structure.IsTradeableCondition()) {
      g_dashData.statusText  = "CHOPPY";
      g_dashData.statusColor = C_ORANGE;
      g_dashData.lastAction  = "Market structure unfavorable";
      return;
   }

   //--- Evaluate both directions
   TradeQuality buyQ  = EvaluateTrade(true);
   TradeQuality sellQ = EvaluateTrade(false);

   // Update dashboard with best score seen
   TradeQuality bestQ = (buyQ.score >= sellQ.score) ? buyQ : sellQ;
   g_dashData.tradeScore = bestQ.score;
   g_dashData.tradeGrade = bestQ.grade;

   //--- Select direction
   bool tryBuy  = buyQ.canTrade  && buyQ.score  >= InpMinTradeScore;
   bool trySell = sellQ.canTrade && sellQ.score >= InpMinTradeScore;

   // If both valid, pick higher score (ties go to structure alignment)
   bool execBuy = false, execSell = false;
   if(tryBuy && trySell) {
      if(buyQ.score >= sellQ.score) execBuy  = true;
      else                          execSell = true;
   } else if(tryBuy)  execBuy  = true;
   else if(trySell) execSell = true;

   if(!execBuy && !execSell) {
      g_dashData.statusText  = "ANALYZING";
      g_dashData.statusColor = C_GOLD;
      g_dashData.lastAction  = StringFormat("Best score: %.1f (need %.0f)",
                                            bestQ.score, InpMinTradeScore);

      if(InpAlertScore && bestQ.score >= InpMinTradeScore - 5 && bestQ.score < InpMinTradeScore) {
         // Near-miss alert
         Print("PSP-X: Near-miss score ", DoubleToString(bestQ.score, 1),
               " — threshold is ", InpMinTradeScore);
      }
      return;
   }

   //--- Get risk parameters
   bool forBuy = execBuy;
   RiskSnapshot risk = g_risk.GetSnapshot(bestQ.score);

   if(risk.state == RISK_HALTED || risk.state == RISK_PAUSED) return;
   if(risk.lotSize <= 0) {
      Print("PSP-X: Lot calculation returned 0 — skipping");
      return;
   }

   //--- Execute
   g_dashData.statusText  = "EXECUTING";
   g_dashData.statusColor = C_LBLUE;
   g_dashData.lastAction  = StringFormat("%s | Score: %.1f | Grade: %s | Lot: %.2f",
                                         forBuy ? "BUY" : "SELL",
                                         bestQ.score, bestQ.grade, risk.lotSize);

   // Pre-fill context for database logging on close
   SMCSignal smcCtx      = g_smc.GetSignal(forBuy);
   MarketStructure htfCtx= g_structure.GetHTF();
   g_openTradeScore  = bestQ.score;
   g_openGrade       = bestQ.grade;
   g_openMarketState = g_structure.StateToString(htfCtx.state);
   g_openHasFVG      = smcCtx.hasBullishFVG || smcCtx.hasBearishFVG;
   g_openHasOB       = smcCtx.hasBullishOB  || smcCtx.hasBearishOB;
   g_openHasSweep    = g_smc.HasRecentSweep();

   if(OpenTrade(forBuy, risk)) {
      g_dashData.statusText  = "IN TRADE";
      g_dashData.statusColor = C_GREEN;
   } else {
      g_dashData.statusText  = "OPEN FAIL";
      g_dashData.statusColor = C_RED;
      g_dashData.lastAction  = "Order rejected — see journal";
   }
}

//=======================================================================
//  OnTradeTransaction — detect externally closed positions
//=======================================================================
void OnTradeTransaction(const MqlTradeTransaction &trans,
                        const MqlTradeRequest     &request,
                        const MqlTradeResult      &result)
{
   // Position closed (by SL, TP, or manual)
   if(trans.type == TRADE_TRANSACTION_DEAL_ADD) {
      if(!HistoryDealSelect(trans.deal)) return;
      if(HistoryDealGetInteger(trans.deal, DEAL_MAGIC)  != (long)InpMagic) return;
      if(HistoryDealGetString(trans.deal, DEAL_SYMBOL)  != Symbol()) return;
      if(HistoryDealGetInteger(trans.deal, DEAL_ENTRY)  != DEAL_ENTRY_OUT) return;

      double pnl = HistoryDealGetDouble(trans.deal, DEAL_PROFIT)
                 + HistoryDealGetDouble(trans.deal, DEAL_SWAP)
                 + HistoryDealGetDouble(trans.deal, DEAL_COMMISSION);

      g_risk.OnTradeClosed(pnl);
      g_session.RecordTrade(g_openSession, pnl, 0);
      BuildPerformanceStats();

      // Log to persistent database
      // Determine exit reason from context
      string exitReason = (pnl >= 0) ? "TARGET" : "SL";
      // Note: if closed by trailing stop, SL was moved — still records as SL hit
      g_db.LogTrade(
         trans.position,          // position ticket (not deal ticket)
         g_openProfitTarget,
         g_openTradeScore,
         g_openGrade,
         g_session.SessionName(g_openSession),
         g_openMarketState,
         g_openHasFVG,
         g_openHasOB,
         g_openHasSweep,
         exitReason
      );

      g_cooldownEnd    = TimeCurrent() + g_cooldownSec;
      g_inCooldown     = true;
      g_openProfitTarget = 0;

      string reason = (pnl >= 0) ? "WIN" : "LOSS";
      g_dashData.lastAction = StringFormat("Position %s | PnL: $%.2f", reason, pnl);

      if(InpAlertTrade)
         SendAlert(StringFormat("PSP-X: Trade %s | PnL: $%.2f", reason, pnl),
                   InpPushNotify, InpEmailNotify);
   }
}
//+------------------------------------------------------------------+
