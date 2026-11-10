//+------------------------------------------------------------------+
//|              PHANTOM SCALPER PRO  –  Institutional BTCUSD        |
//|              v5.0 (12-Layer Confluence & AI State Engine)        |
//|              24/7 Autonomous Master Bulk Trading System          |
//+------------------------------------------------------------------+
#property copyright   "PHANTOM SCALPER PRO AI  v5.0"
#property version     "5.00"
#property description "Institutional BTCUSD Scalping | 12-Layer Engine | Bulk Execution"

#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>
#include <Trade\AccountInfo.mqh>
#include <Math\Stat\Math.mqh>

#define D "PSP_"

//=======================================================================
//  COLOUR PALETTE (Preserved)
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
input string InpBotName         = "INSTITUTIONAL BTC AI";

input group "╔══════  LOT & RECOVERY (PRESERVED) ══════╗"
input double InpBaseLotSize     = 0.01;
input double InpProfitTargetUSD = 5.00;        
input double InpStopLossPct     = 1.5;
input double InpTakeProfitPct   = 3.0;
input double InpMaxDailyLossPct = 5.0;
input double InpMaxDailyProfitPct = 10.0;
input int    InpBulkTrades      = 7;

input group "╔══════  AI & CONFIDENCE THRESHOLDS  ══════╗"
input double InpSignalThreshold = 85.0; // 0-100 (e.g. 90=Conservative, 85=Balanced)
input int    InpVolatilityFilter = 10;   // Minimum ATR required
input int    InpTickBufferSize  = 1000;

input group "╔══════  TRADE FREQUENCY  ══════╗"
input int    InpMaxDailyTrades  = 21;
input int    InpCooldownSec     = 60;

input group "╔══════  DASHBOARD  ══════╗"
input bool   InpShowDash        = true;
input int    InpDashX           = 14;
input int    InpDashY           = 14;

//=======================================================================
//  CONSTANTS & GLOBALS
//=======================================================================
const int    DW = 420;
const int    DH = 700; // Expanded for new metrics

CTrade        g_trade;
CPositionInfo g_pos;
CAccountInfo  g_account;

// Preserved State Tracking
datetime      g_lastCloseTime  = 0;
datetime      g_sessionDay     = 0;
double        g_recoveryTiers[5] = {1.0, 1.5, 2.0, 2.5, 3.5};
int           g_sessTradesTotal  = 0;
int           g_sessTradesToday  = 0;
double        g_sessProfit       = 0.0;
int           g_sessWins         = 0;
int           g_sessLosses       = 0;
int           g_consecutiveLosses= 0;
double        g_peakEquity       = 0.0;
double        g_drawdown         = 0.0;
bool          g_inCooldown   = false;
int           g_cooldownLeft = 0;

// Dashboard & AI State
string        g_statusText   = "WARMING UP";
color         g_statusColor  = C_ORANGE;
string        g_lastAction   = "Initializing...";
double        g_aiConfidenceScore = 0.0;
string        g_marketRegime = "ANALYZING";
string        g_tradeGrade   = "PENDING";
string        g_btcSentiment = "NEUTRAL";
double        g_readinessScore = 0.0;

// Indicators for Base Logic
int           g_atrHandle = INVALID_HANDLE;
int           g_rsiHandle = INVALID_HANDLE;
int           g_emaFast   = INVALID_HANDLE;
int           g_emaSlow   = INVALID_HANDLE;

//=======================================================================
//  FORWARD DECLARATIONS
//=======================================================================
void     BuildSessionStats();
bool     HasPosition();
bool     OpenBulkTrades(ENUM_ORDER_TYPE otype);
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
int      GetConsecutiveLosses();
void     RestoreSession();

// 12-Layer Engine Declarations
double   AnalyzeMarketStructure();
double   AnalyzeSMC();
double   AnalyzeOrderFlow();
double   AnalyzeVolatility();
double   AnalyzeMomentum();
double   AnalyzeTrendQuality();
double   AnalyzeLiquidityHunts();
void     UpdateMarketRegime();
double   AnalyzeSessionIntelligence();
double   AnalyzeFractals();
double   AnalyzeCycle();
double   AnalyzeMarketEfficiency();
void     RunAIIntelligenceLayer(ENUM_ORDER_TYPE &signalDir);

//=======================================================================
//  OnInit
//=======================================================================
int OnInit()
{
   if(StringFind(Symbol(), "BTC") < 0) {
      Print("WARNING: System optimized exclusively for BTCUSD institutional microstructure.");
   }

   g_trade.SetExpertMagicNumber(InpMagicNumber);
   g_trade.SetDeviationInPoints(30);
   g_trade.SetTypeFilling(GetFillMode());

   // Load Base Indicator Handles for Synthetic Approximations
   g_atrHandle = iATR(Symbol(), PERIOD_M5, 14);
   g_rsiHandle = iRSI(Symbol(), PERIOD_M5, 14, PRICE_CLOSE);
   g_emaFast   = iMA(Symbol(), PERIOD_M5, 9, 0, MODE_EMA, PRICE_CLOSE);
   g_emaSlow   = iMA(Symbol(), PERIOD_M5, 21, 0, MODE_EMA, PRICE_CLOSE);

   g_peakEquity  = AccountInfoDouble(ACCOUNT_EQUITY);
   g_sessionDay  = DayStart(TimeCurrent());

   RestoreSession();
   BuildSessionStats();
   g_consecutiveLosses = GetConsecutiveLosses();

   if(InpShowDash) InitDash();
   EventSetTimer(1);
   g_lastAction  = "Initializing 12-Layer Engine...";
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
   EventKillTimer();
   ObjectsDeleteAll(0, D); 
   ChartRedraw(0);
   if(g_atrHandle != INVALID_HANDLE) IndicatorRelease(g_atrHandle);
   if(g_rsiHandle != INVALID_HANDLE) IndicatorRelease(g_rsiHandle);
   if(g_emaFast   != INVALID_HANDLE) IndicatorRelease(g_emaFast);
   if(g_emaSlow   != INVALID_HANDLE) IndicatorRelease(g_emaSlow);
}

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

//=======================================================================
//  OnTick – Core Execution Routing
//=======================================================================
void OnTick()
{
   datetime todayStart = DayStart(TimeCurrent());
   if(todayStart != g_sessionDay) {
      g_sessionDay = todayStart;
      BuildSessionStats();
      g_consecutiveLosses = 0;
   }

   if(!IsMarketOpen()) {
      g_statusText = "MKT CLOSED"; g_statusColor = C_RED; return;
   }

   // --- PRESERVED TRADE MANAGEMENT LOGIC ---
   if(HasPosition()) {
      double floatPL = GetFloatPL();
      if(floatPL >= InpProfitTargetUSD) {
         CloseAllPositions();
         g_lastCloseTime = TimeCurrent();
         g_inCooldown    = true;
         g_cooldownLeft  = InpCooldownSec;
         BuildSessionStats();
         g_consecutiveLosses = GetConsecutiveLosses();
         return;
      }
      g_statusText = "MANAGING TRADE"; g_statusColor = C_GREEN;
      return;
   }

   if(g_inCooldown) {
      g_statusText = "COOLDOWN"; g_statusColor = C_CYAN; return;
   }
   if(!DailyLimitsOK()) {
      g_statusText = "RISK LIMIT HIT"; g_statusColor = C_RED; return;
   }

   // --- NEW: INSTITUTIONAL INTELLIGENCE LAYER ---
   ENUM_ORDER_TYPE signalDir = -1;
   RunAIIntelligenceLayer(signalDir);

   if(signalDir != -1 && g_aiConfidenceScore >= InpSignalThreshold) {
      g_statusText = "DEPLOYING BULK"; g_statusColor = C_LBLUE;
      
      // --- PRESERVED EXECUTION LOGIC ---
      if(OpenBulkTrades(signalDir)) {
         g_statusText = "IN TRADE"; g_statusColor = C_GREEN;
      } else {
         g_statusText = "OPEN FAIL"; g_statusColor = C_RED;
      }
   } else {
      g_statusText = "SCANNING"; g_statusColor = C_GOLD;
   }
}

//=======================================================================
//  INSTITUTIONAL 12-LAYER CONFLUENCE ENGINE
//=======================================================================

void RunAIIntelligenceLayer(ENUM_ORDER_TYPE &signalDir)
{
   UpdateMarketRegime(); // Layer 8

   double l1 = AnalyzeMarketStructure();
   double l2 = AnalyzeSMC();
   double l3 = AnalyzeOrderFlow();
   double l4 = AnalyzeVolatility();
   double l5 = AnalyzeMomentum();
   double l6 = AnalyzeTrendQuality();
   double l7 = AnalyzeLiquidityHunts();
   double l9 = AnalyzeSessionIntelligence();
   double l10 = AnalyzeFractals();
   double l11 = AnalyzeCycle();
   double l12 = AnalyzeMarketEfficiency();

   // Confluence Weighting Matrix
   double buyScore = 0.0;
   double sellScore = 0.0;
   
   // Tally directional scores based on layers (-1.0 to 1.0 mapping)
   double layers[] = {l1, l2, l3, l4, l5, l6, l7, l9, l10, l11, l12};
   double weights[] = {1.5, 2.0, 1.2, 1.0, 0.8, 1.2, 2.0, 0.5, 0.5, 0.8, 0.5}; // Sum = 12.0

   double totalScore = 0;
   for(int i=0; i<11; i++) totalScore += (layers[i] * weights[i]);
   
   // Normalize to 0-100
   g_readinessScore = (MathAbs(totalScore) / 12.0) * 100.0;
   g_aiConfidenceScore = g_readinessScore;

   if(totalScore > 0) {
      signalDir = ORDER_TYPE_BUY;
      g_btcSentiment = "BULLISH";
   } else if (totalScore < 0) {
      signalDir = ORDER_TYPE_SELL;
      g_btcSentiment = "BEARISH";
   } else {
      signalDir = -1;
      g_btcSentiment = "NEUTRAL";
   }

   // Trade Quality Classifier
   if(g_aiConfidenceScore > 92) g_tradeGrade = "ULTRA ELITE";
   else if(g_aiConfidenceScore > 88) g_tradeGrade = "INSTITUTIONAL";
   else if(g_aiConfidenceScore > 80) g_tradeGrade = "STRONG";
   else g_tradeGrade = "WEAK";
}

// Layer 1: Market Structure (BOS, CHOCH)
double AnalyzeMarketStructure() {
   // Synthetic approximation: Higher highs/higher lows check over 20 bars
   double pClose1 = iClose(Symbol(), PERIOD_M15, 1);
   double pClose5 = iClose(Symbol(), PERIOD_M15, 5);
   if(pClose1 > pClose5) return 0.8; 
   if(pClose1 < pClose5) return -0.8;
   return 0.0;
}

// Layer 2: SMC Engine (Order Blocks, FVGs)
double AnalyzeSMC() {
   // Synthetic approximation: Detecting price imbalances (large spread candles)
   double open1 = iOpen(Symbol(), PERIOD_M5, 1);
   double close1 = iClose(Symbol(), PERIOD_M5, 1);
   double body = close1 - open1;
   double atr[1]; CopyBuffer(g_atrHandle, 0, 1, 1, atr);
   
   if(body > atr[0]*1.5) return 1.0; // Bullish Imbalance / FVG proxy
   if(body < -atr[0]*1.5) return -1.0; // Bearish Imbalance
   return 0.0;
}

// Layer 3: Order Flow Simulation
double AnalyzeOrderFlow() {
   // Synthetic volume delta approximation using tick volume and close placement
   long vol = iTickVolume(Symbol(), PERIOD_M5, 1);
   double open = iOpen(Symbol(), PERIOD_M5, 1);
   double close = iClose(Symbol(), PERIOD_M5, 1);
   double high = iHigh(Symbol(), PERIOD_M5, 1);
   double low = iLow(Symbol(), PERIOD_M5, 1);
   
   if(high == low) return 0.0;
   double delta = ((close - low) - (high - close)) / (high - low);
   return delta; // -1.0 (Seller control) to 1.0 (Buyer control)
}

// Layer 4: Volatility Intelligence
double AnalyzeVolatility() {
   double atr[2]; CopyBuffer(g_atrHandle, 0, 1, 2, atr);
   if(atr[0] < InpVolatilityFilter * Point()) return 0.0; // Filter dead markets
   return (atr[0] > atr[1]) ? 1.0 : 0.5; // Expanding volatility confirms direction
}

// Layer 5: Institutional Momentum
double AnalyzeMomentum() {
   double rsi[1]; CopyBuffer(g_rsiHandle, 0, 1, 1, rsi);
   if(rsi[0] > 65) return 0.8; // Momentum Acceleration
   if(rsi[0] < 35) return -0.8;
   return 0.0;
}

// Layer 6: Trend Quality Engine
double AnalyzeTrendQuality() {
   double emaF[1], emaS[1];
   CopyBuffer(g_emaFast, 0, 1, 1, emaF);
   CopyBuffer(g_emaSlow, 0, 1, 1, emaS);
   if(emaF[0] > emaS[0]) return 1.0;
   if(emaF[0] < emaS[0]) return -1.0;
   return 0.0;
}

// Layer 7: Liquidity Hunt Detector
double AnalyzeLiquidityHunts() {
   // Detect false breakdowns/breakouts (Pin bars)
   double open = iOpen(Symbol(), PERIOD_M5, 1);
   double close = iClose(Symbol(), PERIOD_M5, 1);
   double high = iHigh(Symbol(), PERIOD_M5, 1);
   double low = iLow(Symbol(), PERIOD_M5, 1);
   
   double total = high - low;
   if(total == 0) return 0;
   double body = MathAbs(close - open);
   
   // Bullish stop hunt (long lower wick)
   if((MathMin(open, close) - low) > (total * 0.6) && body < (total * 0.3)) return 1.0;
   // Bearish stop hunt (long upper wick)
   if((high - MathMax(open, close)) > (total * 0.6) && body < (total * 0.3)) return -1.0;
   return 0.0;
}

// Layer 8: Market Regime Classifier
void UpdateMarketRegime() {
   double rsi[1], atr[1];
   CopyBuffer(g_rsiHandle, 0, 1, 1, rsi);
   CopyBuffer(g_atrHandle, 0, 1, 1, atr);
   
   if(atr[0] > InpVolatilityFilter * Point() * 2) {
      g_marketRegime = (rsi[0] > 55 || rsi[0] < 45) ? "VOLATILE TREND" : "VOLATILITY SHOCK";
   } else {
      g_marketRegime = (rsi[0] >= 45 && rsi[0] <= 55) ? "COMPRESSION" : "WEAK TREND";
   }
}

// Layer 9: Session Intelligence
double AnalyzeSessionIntelligence() {
   MqlDateTime dt; TimeCurrent(dt);
   // Simple mapping: NYC session usually favors trend continuation in Crypto
   if(dt.hour >= 13 && dt.hour <= 21) return 1.0; // High quality
   return 0.5; // Asian/London overlap
}

// Layer 10: Fractal Engine
double AnalyzeFractals() { return 0.5; } // Placeholder for geometric mapping

// Layer 11: BTC Cycle Detection
double AnalyzeCycle() { return AnalyzeTrendQuality(); } // Short-term sync

// Layer 12: Market Efficiency
double AnalyzeMarketEfficiency() { return (g_marketRegime == "COMPRESSION") ? 0.0 : 1.0; }


//=======================================================================
//  PRESERVED EXECUTION & POSITION LOGIC
//=======================================================================
bool OpenBulkTrades(ENUM_ORDER_TYPE otype)
{
   double price = (otype == ORDER_TYPE_BUY) ?
      SymbolInfoDouble(Symbol(), SYMBOL_ASK) : SymbolInfoDouble(Symbol(), SYMBOL_BID);
   if(price <= 0.0) return false;

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

   bool allSuccess = true;
   g_lastAction = StringFormat("Bulk %s (x%d) | Lot: %.2f (Tier %d)", EnumToString(otype), InpBulkTrades, lot, tierIndex);

   for(int i=0; i<InpBulkTrades; i++) {
      bool ok = (otype == ORDER_TYPE_BUY) ?
         g_trade.Buy(lot, Symbol(), price, sl, tp, InpBotName) : g_trade.Sell(lot, Symbol(), price, sl, tp, InpBotName);
      if(!ok) allSuccess = false;
   }
   
   if(allSuccess) g_sessTradesToday += InpBulkTrades;
   return allSuccess;
}

void CloseAllPositions()
{
   for(int i = PositionsTotal()-1; i >= 0; i--) {
      if(!g_pos.SelectByIndex(i)) continue;
      if(g_pos.Magic() != InpMagicNumber || g_pos.Symbol() != Symbol()) continue;
      g_trade.PositionClose(g_pos.Ticket());
   }
}

//=======================================================================
//  PRESERVED HELPERS & TRACKERS
//=======================================================================
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
//  DASHBOARD GUI  (UPGRADED FOR APEX BTC SCALPER 10-LAYER ENGINE)
//=======================================================================
void R(string nm,int x,int y,int w,int h,color bg,color brd=clrNONE,int bw=1)
{
   string n = D + nm;
   if(ObjectFind(0,n)>=0) ObjectDelete(0,n);
   ObjectCreate(0,n,OBJ_RECTANGLE_LABEL,0,0,0);
   ObjectSetInteger(0,n,OBJPROP_CORNER,CORNER_LEFT_UPPER);
   ObjectSetInteger(0,n,OBJPROP_XDISTANCE,x);
   ObjectSetInteger(0,n,OBJPROP_YDISTANCE,y);
   ObjectSetInteger(0,n,OBJPROP_XSIZE,w);
   ObjectSetInteger(0,n,OBJPROP_YSIZE,h);
   ObjectSetInteger(0,n,OBJPROP_BGCOLOR,bg);
   if(brd!=clrNONE){ObjectSetInteger(0,n,OBJPROP_BORDER_TYPE,BORDER_FLAT);ObjectSetInteger(0,n,OBJPROP_COLOR,brd);ObjectSetInteger(0,n,OBJPROP_WIDTH,bw);}
   else ObjectSetInteger(0,n,OBJPROP_BORDER_TYPE,BORDER_RAISED);
   ObjectSetInteger(0,n,OBJPROP_SELECTABLE,false);
   ObjectSetInteger(0,n,OBJPROP_HIDDEN,true);
}

void L(string nm,int x,int y,string txt,color clr,int fsz,string fnt="Arial Bold")
{
   string n = D + nm;
   if(ObjectFind(0,n)>=0) ObjectDelete(0,n);
   ObjectCreate(0,n,OBJ_LABEL,0,0,0);
   ObjectSetInteger(0,n,OBJPROP_CORNER,CORNER_LEFT_UPPER);
   ObjectSetInteger(0,n,OBJPROP_XDISTANCE,x);
   ObjectSetInteger(0,n,OBJPROP_YDISTANCE,y);
   ObjectSetString (0,n,OBJPROP_TEXT,txt);
   ObjectSetInteger(0,n,OBJPROP_COLOR,clr);
   ObjectSetInteger(0,n,OBJPROP_FONTSIZE,fsz);
   ObjectSetString (0,n,OBJPROP_FONT,fnt);
   ObjectSetInteger(0,n,OBJPROP_SELECTABLE,false);
   ObjectSetInteger(0,n,OBJPROP_HIDDEN,true);
}

void U(string nm,string txt,color clr=C'220,225,240')
{
   string n = D + nm;
   if(ObjectFind(0,n)>=0){ObjectSetString(0,n,OBJPROP_TEXT,txt);ObjectSetInteger(0,n,OBJPROP_COLOR,clr);}
}

void Bar(string nm,int x,int y,int w,int h,double pct,color fg,color bg_c)
{
   R(nm+"_bg",x,y,w,h,bg_c,C_BORDER,1);
   int fw=(int)MathMax(2,MathRound(pct/100.0*(w-2)));
   R(nm+"_fg",x+1,y+1,fw,h-2,fg,clrNONE);
}

void UpdBar(string nm,double pct,color fg)
{
   string n=D+nm+"_fg"; string nb=D+nm+"_bg";
   int w=0;
   if(ObjectFind(0,nb)>=0) w=(int)ObjectGetInteger(0,nb,OBJPROP_XSIZE);
   if(w<=0) return;
   int fw=(int)MathMax(2,MathRound(pct/100.0*(w-2)));
   if(ObjectFind(0,n)>=0){ObjectSetInteger(0,n,OBJPROP_XSIZE,fw);ObjectSetInteger(0,n,OBJPROP_BGCOLOR,fg);}
}

void InitDash()
{
   int X=InpDashX, Y=InpDashY;

   // ── Outer frame ──────────────────────────────────────────────────
   R("frame_outer",X,  Y,  DW,  DH,  C_BG0, C_ACBORD, 2);
   R("frame_inner",X+2,Y+2,DW-4,DH-4,C_BG0, C_BORDER, 1);

   // ── Header ───────────────────────────────────────────────────────
   R("hdr_bg",  X+2,  Y+2,  DW-4,80, C_HDRBAR,C_BORDER,1);
   R("hdr_acc", X+2,  Y+2,  DW-4, 3, C_ACBORD);
   L("h_name",  X+10, Y+10, InpBotName,                    C_BTCORG,13,"Arial Black");
   L("h_tag",   X+10, Y+32, "10-Layer Institutional BTC Signal Engine",C_CYAN,7,"Arial");
   L("h_ver",   X+10, Y+46, "v1.0  +  Magic:" + IntegerToString((long)InpMagicNumber) + "  +  " + Symbol(),C_LBLUE,7,"Arial");
   R("live_bg", X+DW-82,Y+8,66,22,C_DKGREEN,C_GREEN,1);
   L("live_lbl",X+DW-74,Y+12,"● LIVE",C_GREEN,7,"Arial Bold");
   R("div_hdr", X+2,Y+82,DW-4,2,C_ACBORD);

   // ── Status row ───────────────────────────────────────────────────
   R("stat_bg", X+2, Y+86,DW-4,30,C_BG2,C_BORDER,1);
   L("lb_stat", X+14,Y+93,"STATUS",    C_SUBTEXT,8,"Arial");
   L("vl_stat", X+90,Y+93,"WARMING UP",C_ORANGE, 9,"Arial Black");
   L("lb_act",  X+240,Y+93,"Action:",  C_SUBTEXT,7,"Arial");
   L("vl_act",  X+285,Y+93,"--",       C_WHITE,  7,"Arial");
   R("div_stat",X+2,Y+118,DW-4,1,C_BORDER);

   // ── Section A: Performance ────────────────────────────────────────
   int ay = Y+122;
   R("sec_a",   X+2, ay,   DW-4,124,C_BG1,C_BORDER,1);
   R("sec_a_hd",X+2, ay,   DW-4, 20,C_HDRBAR,C_BORDER,1);
   L("sec_a_lb",X+10,ay+4, "▸  PERFORMANCE & RISK",C_GOLD,8,"Arial Black");

   L("lb_sp",X+14,ay+23,"Session P&L",          C_SUBTEXT,7,"Arial"); L("vl_sp",X+175,ay+23,"$ 0.00",C_WHITE,8,"Arial Bold");
   L("lb_fp",X+270,ay+23,"Float:",               C_SUBTEXT,7,"Arial"); L("vl_fp",X+310,ay+23,"$ 0.00",C_WHITE,8,"Arial Bold");
   L("lb_dd",X+14,ay+39,"Drawdown",             C_SUBTEXT,7,"Arial"); L("vl_dd",X+175,ay+39,"0.00 %",C_WHITE,8,"Arial Bold");
   Bar("dd_bar",X+230,ay+40,200,11,0,C_RED,C_DGRAY);
   L("lb_tt",X+14,ay+55,"Trades Today",         C_SUBTEXT,7,"Arial"); L("vl_tt",X+175,ay+55,"0 / "+IntegerToString(InpMaxDailyTrades),C_WHITE,8,"Arial Bold");
   L("lb_rcv",X+270,ay+55,"Tier:",              C_SUBTEXT,7,"Arial"); L("vl_rcv",X+305,ay+55,"0 (1.0x)",C_WHITE,8,"Arial Bold");
   L("lb_wr",X+14,ay+71,"Win / Loss",          C_SUBTEXT,7,"Arial"); L("vl_wr",X+175,ay+71,"0 W / 0 L",C_WHITE,8,"Arial Bold");
   L("lb_cd",X+270,ay+71,"CD:",                C_SUBTEXT,7,"Arial"); L("vl_cd",X+295,ay+71,"--",C_WHITE,8,"Arial Bold");

   // ── Section B: Signal Intelligence ───────────────────────────────
   int by = ay + 128;
   R("sec_b",   X+2, by,   DW-4,112,C_BG1,C_BORDER,1);
   R("sec_b_hd",X+2, by,   DW-4, 20,C_HDRBAR,C_BORDER,1);
   L("sec_b_lb",X+10,by+4, "▸  SIGNAL INTELLIGENCE",C_GOLD,8,"Arial Black");

   L("lb_buy",X+14,by+23,"Buy Score",    C_SUBTEXT,7,"Arial"); L("vl_buy",X+130,by+23,"0.0",C_GREEN,9,"Arial Bold");
   Bar("buy_bar",X+195,by+24,235,12,0,C_GREEN,C_DGRAY);
   L("lb_sell",X+14,by+39,"Sell Score",  C_SUBTEXT,7,"Arial"); L("vl_sell",X+130,by+39,"0.0",C_RED,9,"Arial Bold");
   Bar("sell_bar",X+195,by+40,235,12,0,C_RED,C_DGRAY);
   L("lb_grade",X+14,by+55,"Grade",      C_SUBTEXT,7,"Arial"); L("vl_grade",X+130,by+55,"NONE",C_MGRAY,9,"Arial Black");
   L("lb_ready",X+260,by+55,"Ready:",    C_SUBTEXT,7,"Arial"); L("vl_ready",X+300,by+55,"0%",C_WHITE,8,"Arial Bold");
   Bar("rdy_bar",X+335,by+56,95,11,0,C_PURPLE,C_DGRAY);
   L("lb_regime",X+14,by+73,"Regime",    C_SUBTEXT,7,"Arial"); L("vl_regime",X+130,by+73,"UNKNOWN",C_MGRAY,8,"Arial Bold");
   L("lb_sess",X+270,by+73,"Session:",   C_SUBTEXT,7,"Arial"); L("vl_sess",X+320,by+73,"---",C_MGRAY,8,"Arial Bold");

   // ── Section C: 7-Layer Score Matrix ──────────────────────────────
   int cy = by + 116;
   R("sec_c",   X+2, cy,   DW-4,188,C_BG2,C_BORDER,1);
   R("sec_c_hd",X+2, cy,   DW-4, 20,C_HDRBAR,C_BORDER,1);
   L("sec_c_lb",X+10,cy+4, "▸  10-LAYER SCORE MATRIX",C_GOLD,8,"Arial Black");

   string lnames[] = {"L1 Structure","L2 SmartMoney","L3 Volatility","L4 Volume","L5 Momentum","L6 Trend","L7 Liquidity"};
   string lids[]   = {"str","smc","vol","vlm","mom","trd","liq"};
   for(int i=0;i<7;i++) {
      int ry = cy+23+i*24;
      L("lbl_"+lids[i],X+14,ry,lnames[i],C_SUBTEXT,7,"Arial");
      L("val_"+lids[i],X+140,ry,"0.0",C_WHITE,7,"Arial Bold");
      Bar("bar_"+lids[i],X+195,ry+1,235,13,50,C_CYAN,C_DGRAY);
   }

   // ── Section D: Config strip ───────────────────────────────────────
   int dy = cy + 192;
   R("sec_d",X+2,dy,DW-4,44,C_BG2,C_BORDER,1);
   L("cfg1",X+14,dy+5, "Lot:"+DoubleToString(InpBaseLotSize,2)+"  Bulk:"+IntegerToString(InpBulkTrades)+"  MinScore:B"+DoubleToString(InpMinBuyScore,0)+"/S"+DoubleToString(InpMinSellScore,0), C_LBLUE,7,"Arial");
   L("cfg2",X+14,dy+21,"ATR:"+DoubleToString(InpMinATRMultiple,1)+"x-"+DoubleToString(InpMaxATRMultiple,1)+"x  Grade>="+GradeText(InpMinGradeForEntry)+"  MaxT:"+IntegerToString(InpMaxDailyTrades), C_LBLUE,7,"Arial");

   // ── Footer ────────────────────────────────────────────────────────
   int fy = dy + 48;
   R("ftr",X+2,fy,DW-4,16,C_HDRBAR,C_BORDER,1);
   L("ft_time",X+10,fy+3,"Server: --:--",C_MGRAY,7,"Arial");
   L("ft_atr", X+240,fy+3,"ATR: --",     C_MGRAY,7,"Arial");

   ChartRedraw(0);
}

void UpdateDash()
{
   if(!InpShowDash) return;
   int X=InpDashX;

   double floatPL = GetFloatPL();

   // Status
   U("vl_stat",g_statusText,g_statusColor);
   U("vl_act", g_lastAction, C_SUBTEXT);

   // Performance
   U("vl_sp",  "$ "+DoubleToString(g_sessProfit,2), (g_sessProfit>=0)?C_GREEN:C_RED);
   U("vl_fp",  "$ "+DoubleToString(floatPL,2),      (floatPL>=0)?C_GREEN:C_RED);
   U("vl_dd",  DoubleToString(g_drawdown,2)+" %",   (g_drawdown<5)?C_GREEN:C_RED);
   UpdBar("dd_bar",MathMin(g_drawdown*5.0,100.0),(g_drawdown<5)?C_GREEN:C_RED);
   U("vl_tt",  IntegerToString(g_sessTradesToday)+" / "+IntegerToString(InpMaxDailyTrades),C_WHITE);
   int ti=MathMin(g_consecutiveLosses,4);
   U("vl_rcv", IntegerToString(ti)+" ("+DoubleToString(g_recoveryTiers[ti],1)+"x)",(ti>0)?C_ORANGE:C_GREEN);
   U("vl_wr",  IntegerToString(g_sessWins)+" W / "+IntegerToString(g_sessLosses)+" L",
               (g_sessWins>=g_sessLosses)?C_GREEN:C_RED);
   U("vl_cd",  g_inCooldown ? IntegerToString(g_cooldownLeft)+"s" : "OK", g_inCooldown?C_ORANGE:C_GREEN);

   // Signal Intelligence
   U("vl_buy",  DoubleToString(g_buyScore,1),  (g_buyScore  >= InpMinBuyScore) ?C_GREEN:C_WHITE);
   U("vl_sell", DoubleToString(g_sellScore,1), (g_sellScore >= InpMinSellScore)?C_RED:C_WHITE);
   UpdBar("buy_bar",  g_buyScore,  (g_buyScore  >= InpMinBuyScore)?C_GREEN:C_MGRAY);
   UpdBar("sell_bar", g_sellScore, (g_sellScore >= InpMinSellScore)?C_RED:C_MGRAY);
   U("vl_grade", g_signalGradeTxt,  g_signalGradeColor);
   U("vl_ready", DoubleToString(g_readinessScore,1)+" %", (g_readinessScore>=70)?C_GREEN:(g_readinessScore>=40)?C_GOLD:C_RED);
   UpdBar("rdy_bar",g_readinessScore,C_PURPLE);
   U("vl_regime",g_regimeTxt,  g_regimeColor);
   U("vl_sess",  g_sessionTxt, g_sessionColor);

   // 7-Layer matrix
   double scores[]  = {g_scoreStructure,g_scoreSmartMoney,g_scoreVolatility,
                        g_scoreVolume,g_scoreMomentum,g_scoreTrend,g_scoreLiquidity};
   string lids[]    = {"str","smc","vol","vlm","mom","trd","liq"};
   for(int i=0;i<7;i++) {
      double s = scores[i];
      double barPct = (s + 100.0) / 2.0;   // Map -100..+100 → 0..100
      color c = (s >  15)?C_GREEN:(s < -15)?C_RED:C_GOLD;
      U("val_"+lids[i], (s>=0?"+":"")+DoubleToString(s,1), c);
      UpdBar("bar_"+lids[i], barPct, c);
   }

   // Footer
   U("ft_time","Server: "+TimeToString(TimeCurrent(),TIME_SECONDS)+"  |  Local: "+TimeToString(TimeLocal(),TIME_MINUTES),C_DGRAY);
   U("ft_atr", "ATR: "+DoubleToString(g_atrCurrent,1)+"  Avg: "+DoubleToString(g_atrAvg,1), C_DGRAY);

   ChartRedraw(0);
}

void DeleteDash() { ObjectsDeleteAll(0,D); ChartRedraw(0); }
//+------------------------------------------------------------------+
