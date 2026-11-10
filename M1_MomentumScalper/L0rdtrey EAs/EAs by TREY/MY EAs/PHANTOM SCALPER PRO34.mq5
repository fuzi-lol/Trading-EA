//+------------------------------------------------------------------+
//|              PHANTOM SCALPER PRO  –  Institutional AI Edition    |
//|                    v4.0 (Asynchronous Interval Variant)          |
//|                  24/5 Autonomous HF Scalping System                  |
//+------------------------------------------------------------------+
#property copyright   "PHANTOM SCALPER PRO AI  v4.0"
#property version     "4.00"
#property description "AI-Driven XAUUSD Scalping | Microstructure | Tiered Recovery"

#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>
#include <Trade\AccountInfo.mqh>

//--- Dashboard namespace prefix
#define D "PSP_"

//=======================================================================
//  COLOUR PALETTE
//=======================================================================
#define C_BG0       C'4,6,18'        
#define C_BG1       C'8,12,28'       
#define C_BG2       C'12,18,42'      
#define C_HDRBAR    C'10,16,38'      
#define C_BORDER    C'22,44,90'      
#define C_ACBORD    C'0,160,220'     
#define C_GOLD      C'255,200,40'    
#define C_CYAN      C'0,220,220'     
#define C_PURPLE    C'180,100,255'   
#define C_WHITE     C'220,225,240'   
#define C_SUBTEXT   C'110,130,160'   
#define C_GREEN     C'20,220,110'    
#define C_RED       C'230,55,65'     
#define C_ORANGE    C'255,145,0'     
#define C_DKGREEN   C'14,80,45'      
#define C_LBLUE     C'80,160,255'    
#define C_DGRAY     C'40,52,72'      
#define C_MGRAY     C'75,90,115'     

//=======================================================================
//  INPUT PARAMETERS
//=======================================================================
input group "╔══════  IDENTITY  ══════╗"
input ulong  InpMagicNumber     = 99999;
input string InpBotName         = "PHANTOM SCALPER AI";

input group "╔══════  LOT & RECOVERY  ══════╗"
input double InpBaseLotSize     = 0.01;
input double InpProfitTargetUSD = 5.00;        
input double InpStopLossPct     = 1.5;
input double InpTakeProfitPct   = 3.0;
input double InpMaxDailyLossPct = 5.0;
input double InpMaxDailyProfitPct = 10.0;
input int    InpBulkTrades      = 7;       // Bulk trade execution count

input group "╔══════  INTERVAL TIMING  ══════╗"
input int    InpBulkIntervalSec = 10;      // Seconds to wait between positions while re-analyzing

input group "╔══════  AI & MICROSTRUCTURE  ══════╗"
input double InpMLThreshold     = 0.75;    // ML Confidence required [0.0 - 1.0]
input int    InpTickBufferSize  = 500;     // Rolling tick buffer for Chi-Square

input group "╔══════  TRADE FREQUENCY  ══════╗"
input int    InpMaxDailyTrades  = 21;      // Adjusted for bulk trades (3 signals * 7)
input int    InpCooldownSec     = 60;

input group "╔══════  DASHBOARD  ══════╗"
input bool   InpShowDash        = true;
input int    InpDashX           = 14;
input int    InpDashY           = 14;

//=======================================================================
//  CONSTANTS & GLOBALS
//=======================================================================
const int    DW = 420;
const int    DH = 620;

CTrade        g_trade;
CPositionInfo g_pos;
CAccountInfo  g_account;

// Indicator Handles
int           g_emaFastH  = INVALID_HANDLE;
int           g_emaSlowH  = INVALID_HANDLE;
int           g_rsiH      = INVALID_HANDLE;

// Rolling Buffers & Analysis
MqlTick       g_tickBuffer[];
int           g_tickCount = 0;
double        g_lastMLConfidence = 0.5;
double        g_chiSquareScore = 0.0;

// State Tracking
datetime      g_lastCloseTime  = 0;
datetime      g_sessionDay     = 0;
bool          g_needsAnalysisReset = false;

// Asynchronous Sequence Engine Variables
bool            g_isBulkExecuting   = false;
ENUM_ORDER_TYPE g_bulkTargetDir     = WRONG_VALUE;
int             g_bulkTradesSent    = 0;
datetime        g_lastBulkTradeTime = 0;

// Tiered Recovery Array
double        g_recoveryTiers[5] = {1.0, 1.5, 2.0, 2.5, 3.5};

// Stats
int           g_sessTradesTotal  = 0;
int           g_sessTradesToday  = 0;
double        g_sessProfit       = 0.0;
int           g_sessWins         = 0;
int           g_sessLosses       = 0;
int           g_consecutiveLosses= 0;
double        g_peakEquity       = 0.0;
double        g_drawdown         = 0.0;

// Dashboard Status
string        g_statusText   = "WARMING UP";
color         g_statusColor  = C_ORANGE;
string        g_lastAction   = "Initializing...";
bool          g_inCooldown   = false;
int           g_cooldownLeft = 0;

//=======================================================================
//  FORWARD DECLARATIONS
//=======================================================================
void     ResetAnalysis();
void     UpdateTickBuffer();
double   CalculatePosteriorProbability();
double   GetChiSquareDrift();
double   GetLiquidityDelta();
int      GetConsecutiveLosses();
void     RestoreSession();
void     BuildSessionStats();
bool     HasPosition();
bool     ExecuteSingleBulkTrade(ENUM_ORDER_TYPE otype);
void     CloseAllPositions();
double   GetFloatPL();
bool     IsMarketOpen();
bool     DailyLimitsOK();
void     AdjustStops(double price, ENUM_ORDER_TYPE otype, double &sl, double &tp);
double   NPrice(double p);
ENUM_ORDER_TYPE_FILLING GetFillMode();
datetime DayStart(datetime ts);

void     InitDash();
void     UpdateDash();
void     DeleteDash();
void     R(string nm, int x, int y, int w, int h, color bg, color brd=clrNONE, int bw=1);
void     L(string nm, int x, int y, string txt, color clr, int fsz, string fnt="Arial Bold");
void     U(string nm, string txt, color clr);
void     Bar(string nm, int x, int y, int w, int h, double pct, color fg, color bg);
void     UpdBar(string nm, double pct, color fg);

//+------------------------------------------------------------------+
//|  OnInit                                                          |
//+------------------------------------------------------------------+
int OnInit()
{
   if(Symbol() != "XAUUSD" && StringFind(Symbol(), "XAU") < 0) {
      Print("Warning: This engine is explicitly tuned for Gold (XAUUSD) microstructure.");
   }

   ArrayResize(g_tickBuffer, InpTickBufferSize);
   
   g_trade.SetExpertMagicNumber(InpMagicNumber);
   g_trade.SetDeviationInPoints(30);
   g_trade.SetTypeFilling(GetFillMode());

   g_emaFastH = iMA(Symbol(), PERIOD_M5, 9, 0, MODE_EMA, PRICE_CLOSE);
   g_emaSlowH = iMA(Symbol(), PERIOD_M5, 21, 0, MODE_EMA, PRICE_CLOSE);
   g_rsiH     = iRSI(Symbol(), PERIOD_M5, 14, PRICE_CLOSE);
   g_peakEquity  = AccountInfoDouble(ACCOUNT_EQUITY);
   g_sessionDay  = DayStart(TimeCurrent());

   RestoreSession();
   BuildSessionStats();
   g_consecutiveLosses = GetConsecutiveLosses();

   if(InpShowDash) InitDash();
   EventSetTimer(1);
   g_lastAction  = "Building tick buffer...";
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//|  OnDeinit                                                        |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   EventKillTimer();
   DeleteDash();
   if(g_emaFastH != INVALID_HANDLE) IndicatorRelease(g_emaFastH);
   if(g_emaSlowH != INVALID_HANDLE) IndicatorRelease(g_emaSlowH);
   if(g_rsiH     != INVALID_HANDLE) IndicatorRelease(g_rsiH);
}

//+------------------------------------------------------------------+
//|  OnTimer                                                         |
//+------------------------------------------------------------------+
void OnTimer()
{
   if(g_lastCloseTime > 0) {
      int elapsed = (int)(TimeCurrent() - g_lastCloseTime);
      g_inCooldown   = (elapsed < InpCooldownSec);
      g_cooldownLeft = g_inCooldown ? (InpCooldownSec - elapsed) : 0;
   } else {
      g_inCooldown   = false;
      g_cooldownLeft = 0;
   }

   double eq = AccountInfoDouble(ACCOUNT_EQUITY);
   if(eq > g_peakEquity) g_peakEquity = eq;
   if(g_peakEquity > 0) g_drawdown = (g_peakEquity - eq) / g_peakEquity * 100.0;
   
   if(InpShowDash) UpdateDash();
}

//+------------------------------------------------------------------+
//|  OnTick – Core Execution Engine                                  |
//+------------------------------------------------------------------+
void OnTick()
{
   datetime todayStart = DayStart(TimeCurrent());
   if(todayStart != g_sessionDay) {
      g_sessionDay = todayStart;
      BuildSessionStats();
      g_consecutiveLosses = 0;
      ResetAnalysis();
   }

   if(!IsMarketOpen()) {
      g_statusText = "MKT CLOSED"; g_statusColor = C_RED; return;
   }

   // Update rolling microstructure buffers continuously
   UpdateTickBuffer();

   // --- TARGET BASKETS MONITOR (Global Check) ---
   if(HasPosition()) {
      double floatPL = GetFloatPL();
      if(floatPL >= InpProfitTargetUSD) {
         CloseAllPositions();
         g_lastCloseTime = TimeCurrent();
         g_inCooldown    = true;
         g_cooldownLeft  = InpCooldownSec;
         BuildSessionStats();
         g_consecutiveLosses = GetConsecutiveLosses();
         ResetAnalysis();
         g_isBulkExecuting   = false; // Cancel ongoing drip pipelines
         return;
      }
   }

   if(g_inCooldown) {
      g_statusText = "COOLDOWN"; g_statusColor = C_CYAN; return;
   }
   if(!DailyLimitsOK()) {
      g_statusText = "LIMIT HIT"; g_statusColor = C_RED; return;
   }

   // Buffer warmup guard
   if(g_tickCount < InpTickBufferSize) {
       g_statusText = "BUFFERING";
       g_statusColor = C_ORANGE; return;
   }

   // ===================================================================
   //  ACTIVE BATCH SEQUENCE HANDLER (Asynchronous Interval Loop)
   // ===================================================================
   if(g_isBulkExecuting) {
      // 1. Run live mathematical inference on the CURRENT tick mid-interval
      g_lastMLConfidence = CalculatePosteriorProbability();
      
      ENUM_ORDER_TYPE live_signal = WRONG_VALUE;
      if(g_lastMLConfidence >= InpMLThreshold) live_signal = ORDER_TYPE_BUY;
      if((1.0 - g_lastMLConfidence) >= InpMLThreshold) live_signal = ORDER_TYPE_SELL;
      
      // 2. ADAPTIVE SWITCH: If the system projects a directional vector shift mid-sequence
      if(live_signal != WRONG_VALUE && live_signal != g_bulkTargetDir) {
         g_bulkTargetDir = live_signal;
         g_lastAction = StringFormat("🔄 Pivot mid-sequence! Vector flipped to: %s", EnumToString(g_bulkTargetDir));
         ResetAnalysis(); // Immediately reset statistics completely fresh for the new vector
      }
      
      // 3. INTERVAL EXECUTION VALVE
      if((int)(TimeCurrent() - g_lastBulkTradeTime) >= InpBulkIntervalSec) {
         if(ExecuteSingleBulkTrade(g_bulkTargetDir)) {
            g_bulkTradesSent++;
            g_lastBulkTradeTime = TimeCurrent();
            ResetAnalysis(); // Reset data buffers completely fresh AFTER every single execution
         }
         
         // If all individual items inside our bulk batch have gone through, complete processing
         if(g_bulkTradesSent >= InpBulkTrades) {
            g_isBulkExecuting = false;
            g_lastAction = "Bulk batch execution pipeline filled.";
         }
      }
      
      g_statusText = "BULK PIPELN"; g_statusColor = C_PURPLE;
      return;
   }

   // If positions exist but we aren't filling a batch, standard monitoring state
   if(HasPosition()) {
      g_statusText = "IN TRADE"; g_statusColor = C_GREEN;
      return;
   }

   // === ML INFERENCE CRADLE (Find initial batch signal) ===
   g_lastMLConfidence = CalculatePosteriorProbability();
   ENUM_ORDER_TYPE dir = WRONG_VALUE;
   if(g_lastMLConfidence >= InpMLThreshold) dir = ORDER_TYPE_BUY;
   if((1.0 - g_lastMLConfidence) >= InpMLThreshold) dir = ORDER_TYPE_SELL;

   if(dir != WRONG_VALUE) {
      g_statusText = "STARTING"; g_statusColor = C_LBLUE;
      
      // Arm the state machine to drip trades sequentially instead of dumping simultaneously
      g_isBulkExecuting   = true;
      g_bulkTargetDir     = dir;
      g_bulkTradesSent    = 0;
      g_lastBulkTradeTime = 0; // Setting to 0 triggers the first trade instantly on next line
   } else {
      g_statusText = "ANALYZING"; g_statusColor = C_GOLD;
   }
}

//+------------------------------------------------------------------+
//|  Analysis & Microstructure Methods                               |
//+------------------------------------------------------------------+
void ResetAnalysis()
{
   ZeroMemory(g_tickBuffer);
   g_tickCount = 0;
   g_lastMLConfidence = 0.5;
   g_chiSquareScore = 0.0;
   g_lastAction = "Analysis reset fresh.";
}

void UpdateTickBuffer()
{
   MqlTick tick;
   if(SymbolInfoTick(Symbol(), tick)) {
      if(g_tickCount < InpTickBufferSize) {
         g_tickBuffer[g_tickCount] = tick;
         g_tickCount++;
      } else {
         // Shift buffer left (rolling)
         for(int i=0; i<InpTickBufferSize-1; i++) {
            g_tickBuffer[i] = g_tickBuffer[i+1];
         }
         g_tickBuffer[InpTickBufferSize-1] = tick;
      }
   }
}

double GetChiSquareDrift()
{
   if(g_tickCount < 10) return 0;
   int upTicks = 0, downTicks = 0;
   for(int i=1; i<g_tickCount; i++) {
      if(g_tickBuffer[i].last > g_tickBuffer[i-1].last) upTicks++;
      else if(g_tickBuffer[i].last < g_tickBuffer[i-1].last) downTicks++;
   }
   
   int total = upTicks + downTicks;
   if(total == 0) return 0;
   double expected = total / 2.0;
   double chiSq = (MathPow(upTicks - expected, 2) / expected) + (MathPow(downTicks - expected, 2) / expected);
   g_chiSquareScore = chiSq;
   
   // Normalize and return directional drift
   double normDrift = MathMin(chiSq / 50.0, 1.0);
   return (upTicks > downTicks) ? normDrift : -normDrift;
}

double GetLiquidityDelta()
{
   double askVol = 0, bidVol = 0;
   for(int i=0; i<g_tickCount; i++) {
      if((g_tickBuffer[i].flags & TICK_FLAG_ASK) == TICK_FLAG_ASK) askVol += g_tickBuffer[i].volume_real;
      if((g_tickBuffer[i].flags & TICK_FLAG_BID) == TICK_FLAG_BID) bidVol += g_tickBuffer[i].volume_real;
   }
   double total = askVol + bidVol;
   if(total == 0) return 0;
   return (askVol - bidVol) / total;
}

double CalculatePosteriorProbability()
{
   // 1. Technical Momentum (EMA & RSI)
   double emaF[1], emaS[1], rsi[1];
   CopyBuffer(g_emaFastH, 0, 0, 1, emaF);
   CopyBuffer(g_emaSlowH, 0, 0, 1, emaS);
   CopyBuffer(g_rsiH,     0, 0, 1, rsi);
   double f1_trend = (emaF[0] > emaS[0]) ? 1.0 : -1.0;
   double f2_mom   = (rsi[0] - 50.0) / 50.0;

   // 2. Microstructure (Chi-Square & Liquidity)
   double f3_drift = GetChiSquareDrift();
   double f4_liq   = GetLiquidityDelta();

   // Optimal weights for XAUUSD M5
   double w1 = 0.35, w2 = 0.20, w3 = 0.25, w4 = 0.20;
   double logit = (f1_trend * w1) + (f2_mom * w2) + (f3_drift * w3) + (f4_liq * w4);

   // Sigmoid activation function
   double probability = 1.0 / (1.0 + MathExp(-logit * 3.5));
   return probability;
}

//+------------------------------------------------------------------+
//|  Execution Pipelines                                             |
//+------------------------------------------------------------------+
bool ExecuteSingleBulkTrade(ENUM_ORDER_TYPE otype)
{
   double price = (otype == ORDER_TYPE_BUY) ?
                  SymbolInfoDouble(Symbol(), SYMBOL_ASK) : SymbolInfoDouble(Symbol(), SYMBOL_BID);
   if(price <= 0.0) return false;

   // Tiered Recovery Logic
   int tierIndex = MathMin(g_consecutiveLosses, 4);
   double targetLot = InpBaseLotSize * g_recoveryTiers[tierIndex];
   double lotMin  = SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_MIN);
   double lotMax  = SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_MAX);
   double lotStep = SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_STEP);
   double lot     = MathMax(lotMin, MathMin(lotMax, MathRound(targetLot / lotStep) * lotStep));

   double sl = 0.0, tp = 0.0;
   if(InpStopLossPct > 0.0) {
      sl = (otype == ORDER_TYPE_BUY) ?
           NPrice(price * (1.0 - InpStopLossPct/100.0)) : NPrice(price * (1.0 + InpStopLossPct/100.0));
   }
   AdjustStops(price, otype, sl, tp);

   g_lastAction = StringFormat("Bulk execution (#%d/%d) %s | Lot: %.2f", g_bulkTradesSent + 1, InpBulkTrades, EnumToString(otype), lot);

   bool ok = (otype == ORDER_TYPE_BUY) ?
             g_trade.Buy(lot, Symbol(), price, sl, tp, InpBotName) : g_trade.Sell(lot, Symbol(), price, sl, tp, InpBotName);
   
   if(ok) g_sessTradesToday++;
   return ok;
}

void CloseAllPositions()
{
   for(int i = PositionsTotal()-1; i >= 0; i--) {
      if(!g_pos.SelectByIndex(i)) continue;
      if(g_pos.Magic() != InpMagicNumber || g_pos.Symbol() != Symbol()) continue;
      g_trade.PositionClose(g_pos.Ticket());
   }
}

//+------------------------------------------------------------------+
//|  Helpers & Trackers                                              |
//+------------------------------------------------------------------+
bool HasPosition()
{
   for(int i = PositionsTotal()-1; i >= 0; i--) {
      if(g_pos.SelectByIndex(i) && g_pos.Magic() == InpMagicNumber && g_pos.Symbol() == Symbol()) return true;
   }
   return false;
}

double GetFloatPL()
{
   double t = 0;
   for(int i = PositionsTotal()-1; i >= 0; i--) {
      if(g_pos.SelectByIndex(i) && g_pos.Magic() == InpMagicNumber && g_pos.Symbol() == Symbol())
         t += g_pos.Profit() + g_pos.Swap() + g_pos.Commission();
   }
   return t;
}

int GetConsecutiveLosses()
{
   int losses = 0;
   datetime ds = DayStart(TimeCurrent());
   if(HistorySelect(0, TimeCurrent())) {
      int total = HistoryDealsTotal();
      for(int i = total-1; i >= 0; i--) {
         ulong tk = HistoryDealGetTicket(i);
         if(HistoryDealGetInteger(tk, DEAL_MAGIC) != InpMagicNumber) continue;
         if(HistoryDealGetString(tk, DEAL_SYMBOL) != Symbol()) continue;
         if(HistoryDealGetInteger(tk, DEAL_ENTRY) == DEAL_ENTRY_OUT) {
            double pnl = HistoryDealGetDouble(tk, DEAL_PROFIT) + HistoryDealGetDouble(tk, DEAL_SWAP) + HistoryDealGetDouble(tk, DEAL_COMMISSION);
            if(pnl < 0) losses++;
            else break;
         }
      }
   }
   return losses;
}

bool IsMarketOpen()
{
   ENUM_SYMBOL_TRADE_MODE m = (ENUM_SYMBOL_TRADE_MODE)SymbolInfoInteger(Symbol(), SYMBOL_TRADE_MODE);
   return (m == SYMBOL_TRADE_MODE_FULL || m == SYMBOL_TRADE_MODE_LONGONLY || m == SYMBOL_TRADE_MODE_SHORTONLY);
}

bool DailyLimitsOK()
{
   double bal = AccountInfoDouble(ACCOUNT_BALANCE);
   if(bal <= 0) return true;
   if(InpMaxDailyTrades > 0 && g_sessTradesToday >= InpMaxDailyTrades) return false;
   if(InpMaxDailyLossPct > 0.0 && g_sessProfit < -(bal * InpMaxDailyLossPct / 100.0)) return false;
   if(InpMaxDailyProfitPct > 0.0 && g_sessProfit >= (bal * InpMaxDailyProfitPct / 100.0)) return false;
   return true;
}

void AdjustStops(double price, ENUM_ORDER_TYPE otype, double &sl, double &tp)
{
   int stopsLevel = (int)SymbolInfoInteger(Symbol(), SYMBOL_TRADE_STOPS_LEVEL);
   double point = SymbolInfoDouble(Symbol(), SYMBOL_POINT);
   double minDist = stopsLevel * point;
   if(otype == ORDER_TYPE_BUY) {
      if(sl > 0.0 && (price - sl) < minDist) sl = NPrice(price - minDist);
      if(tp > 0.0 && (tp - price) < minDist) tp = NPrice(price + minDist);
   } else {
      if(sl > 0.0 && (sl - price) < minDist) sl = NPrice(price + minDist);
      if(tp > 0.0 && (price - tp) < minDist) tp = NPrice(price - minDist);
   }
}

double NPrice(double p) { return NormalizeDouble(p, (int)SymbolInfoInteger(Symbol(), SYMBOL_DIGITS)); }

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

void RestoreSession()
{
   datetime ds = DayStart(TimeCurrent());
   if(!HistorySelect(ds, TimeCurrent())) return;
   for(int i = 0; i < HistoryDealsTotal(); i++) {
      ulong tk = HistoryDealGetTicket(i);
      if((ulong)HistoryDealGetInteger(tk, DEAL_MAGIC) == InpMagicNumber && HistoryDealGetString(tk, DEAL_SYMBOL) == Symbol()) {
         if(HistoryDealGetInteger(tk, DEAL_ENTRY) == DEAL_ENTRY_IN) g_sessTradesToday++;
      }
   }
}

void BuildSessionStats()
{
   g_sessProfit = 0.0; g_sessWins = 0; g_sessLosses = 0;
   if(!HistorySelect(DayStart(TimeCurrent()), TimeCurrent())) return;
   for(int i = 0; i < HistoryDealsTotal(); i++) {
      ulong tk = HistoryDealGetTicket(i);
      if((ulong)HistoryDealGetInteger(tk, DEAL_MAGIC) != InpMagicNumber || HistoryDealGetString(tk, DEAL_SYMBOL) != Symbol()) continue;
      if(HistoryDealGetInteger(tk, DEAL_ENTRY) == DEAL_ENTRY_OUT) {
         double pnl = HistoryDealGetDouble(tk, DEAL_PROFIT) + HistoryDealGetDouble(tk, DEAL_SWAP) + HistoryDealGetDouble(tk, DEAL_COMMISSION);
         g_sessProfit += pnl;
         if(pnl >= 0) g_sessWins++; else g_sessLosses++;
      }
   }
}

//=======================================================================
//  DASHBOARD GUI
//=======================================================================
void R(string nm, int x, int y, int w, int h, color bg, color brd=clrNONE, int bw=1)
{
   string n = D + nm;
   if(ObjectFind(0, n) >= 0) ObjectDelete(0, n);
   ObjectCreate(0, n, OBJ_RECTANGLE_LABEL, 0, 0, 0);
   ObjectSetInteger(0, n, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, n, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, n, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, n, OBJPROP_XSIZE, w);
   ObjectSetInteger(0, n, OBJPROP_YSIZE, h);
   ObjectSetInteger(0, n, OBJPROP_BGCOLOR, bg);
   if(brd != clrNONE) {
      ObjectSetInteger(0, n, OBJPROP_BORDER_TYPE, BORDER_FLAT);
      ObjectSetInteger(0, n, OBJPROP_COLOR, brd);
      ObjectSetInteger(0, n, OBJPROP_WIDTH, bw);
   } else ObjectSetInteger(0, n, OBJPROP_BORDER_TYPE, BORDER_RAISED);
   ObjectSetInteger(0, n, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, n, OBJPROP_HIDDEN, true);
}

void L(string nm, int x, int y, string txt, color clr, int fsz, string fnt="Arial Bold")
{
   string n = D + nm;
   if(ObjectFind(0, n) >= 0) ObjectDelete(0, n);
   ObjectCreate(0, n, OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, n, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, n, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, n, OBJPROP_YDISTANCE, y);
   ObjectSetString (0, n, OBJPROP_TEXT, txt);
   ObjectSetInteger(0, n, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, n, OBJPROP_FONTSIZE, fsz);
   ObjectSetString (0, n, OBJPROP_FONT, fnt);
   ObjectSetInteger(0, n, OBJPROP_SELECTABLE,false);
   ObjectSetInteger(0, n, OBJPROP_HIDDEN, true);
}

void U(string nm, string txt, color clr=C'220,225,240')
{
   string n = D + nm;
   if(ObjectFind(0, n) >= 0) {
      ObjectSetString(0, n, OBJPROP_TEXT, txt);
      ObjectSetInteger(0, n, OBJPROP_COLOR, clr);
   }
}

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
   if(ObjectFind(0, n) >= 0) {
      ObjectSetInteger(0, n, OBJPROP_XSIZE, fw);
      ObjectSetInteger(0, n, OBJPROP_BGCOLOR, fg);
   }
}

void InitDash()
{
   int X = InpDashX, Y = InpDashY;
   R("frame_outer", X,   Y,   DW,   DH,   C_BG0,   C_ACBORD,  2);
   R("frame_inner", X+2, Y+2, DW-4, DH-4, C_BG0,   C_BORDER,  1);
   R("hdr_bg",  X+2,  Y+2,  DW-4, 80,  C_HDRBAR, C_BORDER, 1);
   R("hdr_acc", X+2,  Y+2,  DW-4,  3,  C_ACBORD);
   L("h_name",  X+10, Y+10, InpBotName,                  C_GOLD,  12, "Arial Black");
   L("h_tag",   X+10, Y+30, "AI & ML Microstructure Engine | Tiered Recovery", C_CYAN, 7, "Arial");
   L("h_ver",   X+10, Y+44, "v4.0  +  Magic: " + IntegerToString((long)InpMagicNumber) + "  +  " + Symbol(), C_LBLUE, 7, "Arial");
   R("live_bg", X+DW-80, Y+8, 64, 22, C_DKGREEN, C_GREEN, 1);
   L("live_lbl",X+DW-72, Y+12, "● LIVE",               C_GREEN,  7, "Arial Bold");
   R("div_hdr", X+2, Y+82, DW-4, 2, C_ACBORD);

   R("stat_bg",  X+2,  Y+86, DW-4, 30,  C_BG2, C_BORDER, 1);
   L("lb_stat",  X+14, Y+93, "STATUS",                   C_SUBTEXT, 8, "Arial");
   L("vl_stat",  X+100,Y+93, "WARMING UP",               C_ORANGE,  9, "Arial Black");
   L("lb_act",   X+220,Y+93, "Action:",                  C_SUBTEXT, 7, "Arial");
   L("vl_act",   X+260,Y+93, "--",                       C_WHITE,   7, "Arial");
   R("div_stat", X+2, Y+118, DW-4, 1, C_BORDER);

   R("sec_a",   X+2,  Y+122, DW-4, 168, C_BG1, C_BORDER, 1);
   R("sec_a_hd",X+2,  Y+122, DW-4,  22, C_HDRBAR, C_BORDER, 1);
   L("sec_a_lb",X+10, Y+126, "▸  PERFORMANCE & RISK",           C_GOLD, 8, "Arial Black");
   L("lb_sp",  X+14, Y+149, "Session Profit",         C_SUBTEXT, 8, "Arial");
   L("vl_sp",  X+200,Y+149, "$ 0.00",                 C_WHITE,   9, "Arial Bold");
   L("lb_fp",  X+14, Y+165, "Floating P&L",           C_SUBTEXT, 8, "Arial");
   L("vl_fp",  X+200,Y+165, "$ 0.00",                 C_WHITE,   9, "Arial Bold");
   L("lb_dd",  X+14, Y+181, "Drawdown",               C_SUBTEXT, 8, "Arial");
   L("vl_dd",  X+200,Y+181, "0.00 %",                 C_WHITE,   9, "Arial Bold");
   Bar("dd_bar", X+280, Y+183, 130, 12, 0, C_RED, C_DGRAY);
   
   L("lb_tt",  X+14, Y+197, "Bulk Trades Executed",   C_SUBTEXT, 8, "Arial");
   L("vl_tt",  X+200,Y+197, "0 / " + IntegerToString(InpMaxDailyTrades), C_WHITE, 9, "Arial Bold");
   L("lb_rcv", X+14, Y+213, "Recovery Tier",          C_SUBTEXT, 8, "Arial");
   L("vl_rcv", X+200,Y+213, "Tier 0 (1.0x)",          C_WHITE,   9, "Arial Bold");
   R("sec_c",   X+2,  Y+296, DW-4, 160, C_BG1, C_BORDER, 1);
   R("sec_c_hd",X+2,  Y+296, DW-4,  22, C_HDRBAR, C_BORDER, 1);
   L("sec_c_lb",X+10, Y+300, "▸  AI & MICROSTRUCTURE",       C_GOLD, 8, "Arial Black");
   L("lb_mlc",  X+14, Y+327, "AI Confidence Score",    C_SUBTEXT, 8, "Arial");
   L("vl_mlc",  X+200,Y+327, "50.0 %",                 C_CYAN,    9, "Arial Bold");
   Bar("ml_bar", X+280, Y+329, 130, 12, 50, C_CYAN, C_DGRAY);
   
   L("lb_dir",  X+14, Y+343, "Projected Vector",       C_SUBTEXT, 8, "Arial");
   L("vl_dir",  X+200,Y+343, "--",                     C_WHITE,   9, "Arial Bold");
   L("lb_chi",  X+14, Y+359, "Chi-Square Drift",       C_SUBTEXT, 8, "Arial");
   L("vl_chi",  X+200,Y+359, "0.00",                   C_WHITE,   9, "Arial Bold");
   L("lb_buf",  X+14, Y+375, "Tick Buffer Status",     C_SUBTEXT, 8, "Arial");
   L("vl_buf",  X+200,Y+375, "0 / " + IntegerToString(InpTickBufferSize), C_WHITE, 9, "Arial Bold");
   Bar("buf_bar", X+280, Y+377, 130, 12, 0, C_PURPLE, C_DGRAY);
   R("sec_d",   X+2,  Y+464, DW-4, 56,  C_BG2, C_BORDER, 1);
   L("cfg1",    X+14, Y+469, "Lot: " + DoubleToString(InpBaseLotSize,2) + "  |  Bulk Size: " + IntegerToString(InpBulkTrades) + " trades", C_LBLUE, 7, "Arial");
   L("cfg2",    X+14, Y+483, "ML Threshold: " + DoubleToString(InpMLThreshold*100, 1) + "%  |  Target: $" + DoubleToString(InpProfitTargetUSD,2), C_LBLUE, 7, "Arial");
   R("ftr",     X+2,  Y+603, DW-4, 15, C_HDRBAR, C_BORDER, 1);
   L("ft_time", X+10, Y+605, "Server: --:--",          C_MGRAY, 7, "Arial");
   
   ChartRedraw(0);
}

void UpdateDash()
{
   if(!InpShowDash) return;

   double floatPL = GetFloatPL();
   U("vl_stat", g_statusText, g_statusColor);
   U("vl_act",  g_lastAction, C_SUBTEXT);
   U("vl_sp", "$ " + DoubleToString(g_sessProfit, 2), (g_sessProfit >= 0) ? C_GREEN : C_RED);
   U("vl_fp", "$ " + DoubleToString(floatPL, 2), (floatPL >= 0) ? C_GREEN : C_RED);
   U("vl_dd", DoubleToString(g_drawdown, 2) + " %", (g_drawdown < 5) ? C_GREEN : C_RED);
   UpdBar("dd_bar", MathMin(g_drawdown * 5.0, 100.0), (g_drawdown < 5) ? C_GREEN : C_RED);
   U("vl_tt", IntegerToString(g_sessTradesToday) + " / " + IntegerToString(InpMaxDailyTrades), C_WHITE);
   
   int trIndex = MathMin(g_consecutiveLosses, 4);
   U("vl_rcv", "Tier " + IntegerToString(trIndex) + " (" + DoubleToString(g_recoveryTiers[trIndex], 1) + "x)", (trIndex > 0) ? C_ORANGE : C_GREEN);
   
   // AI & ML Status Updates
   U("vl_mlc", DoubleToString(g_lastMLConfidence * 100.0, 1) + " %", (g_lastMLConfidence > InpMLThreshold) ? C_GREEN : ((1.0-g_lastMLConfidence) > InpMLThreshold ? C_RED : C_CYAN));
   UpdBar("ml_bar", g_lastMLConfidence * 100.0, (g_lastMLConfidence > 0.5) ? C_GREEN : C_RED);
   
   if(g_lastMLConfidence >= InpMLThreshold) U("vl_dir", "BULLISH", C_GREEN);
   else if((1.0 - g_lastMLConfidence) >= InpMLThreshold) U("vl_dir", "BEARISH", C_RED);
   else U("vl_dir", "NEUTRAL", C_MGRAY);
   
   U("vl_chi", DoubleToString(g_chiSquareScore, 2), C_WHITE);
   U("vl_buf", IntegerToString(g_tickCount) + " / " + IntegerToString(InpTickBufferSize), (g_tickCount == InpTickBufferSize) ? C_GREEN : C_ORANGE);
   UpdBar("buf_bar", ((double)g_tickCount / InpTickBufferSize) * 100.0, C_PURPLE);

   U("ft_time", "Server: " + TimeToString(TimeCurrent(), TIME_SECONDS) + "  |  Local: " + TimeToString(TimeLocal(), TIME_MINUTES), C_DGRAY);
   ChartRedraw(0);
}

void DeleteDash() { ObjectsDeleteAll(0, D); ChartRedraw(0); }
//+------------------------------------------------------------------+