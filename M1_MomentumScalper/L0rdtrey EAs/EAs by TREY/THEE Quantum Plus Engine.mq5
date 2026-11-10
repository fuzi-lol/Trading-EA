//+------------------------------------------------------------------+
//|                                     THEE Quantum Plus Engine.mq5 |
//|                                  Copyright 2026, FXBotHub Systems|
//|                                             https://fxbothub.com |
//+------------------------------------------------------------------+
//  QUANTUM PLUS – Institutional Microstructure Engine
//    • 1D Recursive Kalman Filter (Noise Cancellation)
//    • SMC Fair Value Gap (FVG) Orderflow Validation
//    • Dynamic R:R Matrix & Positive Expectancy Lock
//    • Micro-Account Compounding Allocation ($10+ Ready)
//    • Stealth Executions & Requote Recovery Loops
//+------------------------------------------------------------------+
#property copyright   "Copyright 2026, scalping Systems"
#property version     "7.00"
#property description "Quantum Plus Institutional Microstructure Engine"
#property strict

#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>

#define DASH_PREFIX  "Q_PLUS_"
#define EA_VERSION   "v7.00 PRO"

//+------------------------------------------------------------------+
//| ENUMS & STRUCTURES                                               |
//+------------------------------------------------------------------+
enum ENUM_ENGINE_STATE {
   STATE_SCANNING,
   STATE_COOLDOWN,
   STATE_DAILY_LIMIT,
   STATE_NEWS_PAUSE
};

enum ENUM_SIGNAL {
   SIGNAL_BUY  =  1,
   SIGNAL_SELL = -1,
   SIGNAL_NONE =  0
};

struct STRUCT_KALMAN_ENGINE {
   double estimate;      
   double error_cov;     
   double process_noise; 
   double measure_noise; 
   double gain;          
};

//+------------------------------------------------------------------+
//| INPUT PARAMETERS                                                 |
//+------------------------------------------------------------------+
input group "=== CORE IDENTITY ==="
input ulong   InpMagicNumber       = 999777;
input string  InpTradeComment      = "Quantum_Plus_Engine";

input group "=== QUANTUM & SMC FILTERS ==="
input double  InpProcessNoise      = 0.0001;  // Q parameter (Speed)
input double  InpMeasureNoise      = 0.01;    // R parameter (Smoothness)
input int     InpATRPeriod         = 14;     // Volatility mapping
input double  InpMinDeviationPoints = 40.0;  // Lower to 30-50 for faster scalping triggers
input bool    InpRequireFVG         = false; // Set to false to stop waiting for perfect gaps


input group "=== MICRO-ACCOUNT COMPOUNDING ==="
input double  InpRiskPercent       = 2.0;    // Base Risk % per trade
input double  InpSLMultiplier      = 1.5;    // ATR Multiplier for Stop Loss
input double  InpHardTPMultiplier  = 3.0;    // Absolute Minimum R:R (e.g., 1:3)
input int     InpMinSLPoints       = 150;    // Minimum allowable stop distance

input group "=== LIVE NEWS INTELLIGENCE ==="
input bool    InpUseNewsFilter     = true;
input int     InpNewsPauseBefore   = 15;     // Mins before high-impact USD news
input int     InpNewsPauseAfter    = 30;     // Mins after news

input group "=== ENGINE DISCIPLINE ==="
input int     InpReEntryCooldownSec = 60;    // Absolute cooldown after any close
input int     InpMaxDailyTrades     = 10;    // Daily execution limit

//+------------------------------------------------------------------+
//| GLOBAL OBJECTS & VARIABLES                                       |
//+------------------------------------------------------------------+
CTrade               g_Trade;
CPositionInfo        g_Pos;
STRUCT_KALMAN_ENGINE g_QuantumFast;
STRUCT_KALMAN_ENGINE g_QuantumSlow;

int          g_hATR            = INVALID_HANDLE;
ENUM_ENGINE_STATE g_State      = STATE_SCANNING;
datetime     g_StateTimer      = 0;
int          g_DailyTrades     = 0;
int          g_TradeScore      = 0;
double       g_AvgSpread       = 0.0;
int          g_SpreadSamples   = 0;

string       g_StatusText      = "BOOTING QUANTUM CORE";
color        g_StatusColor     = clrGold;

//+------------------------------------------------------------------+
//| FORWARD DECLARATIONS                                             |
//+------------------------------------------------------------------+
void         InitQuantumEngine();
double       UpdateKalman(STRUCT_KALMAN_ENGINE &k, double currentPrice);
bool         DetectInstitutionalFVG(ENUM_SIGNAL direction);
ENUM_SIGNAL EvaluateQuantumConfluence() {
   double currentBid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double fastState  = UpdateKalman(g_QuantumFast, currentBid);
   double slowState  = UpdateKalman(g_QuantumSlow, currentBid);
   
   // 1. Core Trend Alignment (Absolute rule: Do not buy if macro is dropping)
   bool isMacroBullish = (fastState > slowState);
   bool isMacroBearish = (fastState < slowState);
   
   // 2. Micro Deviation (Rubber band effect - now adjustable)
   double deviation = (currentBid - fastState) / _Point;
   
   ENUM_SIGNAL structuralBias = SIGNAL_NONE;
   
   // Trigger entries earlier before the move exhausts itself
   if(isMacroBearish && deviation > InpMinDeviationPoints)       structuralBias = SIGNAL_SELL; 
   else if(isMacroBullish && deviation < -InpMinDeviationPoints) structuralBias = SIGNAL_BUY;
   
   if(structuralBias == SIGNAL_NONE) return SIGNAL_NONE;
   
   // 3. FVG Institutional Validation (Now optional so it doesn't block good trades)
   if(InpRequireFVG) {
      if(DetectInstitutionalFVG(structuralBias)) {
         g_TradeScore = 9; // Elite validation
         return structuralBias;
      } else {
         return SIGNAL_NONE; // Blocked by FVG requirement
      }
   }
   
   // If FVG is turned off, base the score purely on trend alignment strength
   g_TradeScore = 7; 
   return structuralBias;
}
//+------------------------------------------------------------------+
//| INIT / DEINIT / TIMER                                            |
//+------------------------------------------------------------------+
int OnInit() {
   g_Trade.SetExpertMagicNumber(InpMagicNumber);
   g_Trade.SetDeviationInPoints(20);
   g_Trade.SetTypeFilling(ORDER_FILLING_FOK);

   g_hATR = iATR(_Symbol, _Period, InpATRPeriod);
   if(g_hATR == INVALID_HANDLE) {
      Print("[QUANTUM CORE] Failed to load ATR. Error: ", GetLastError());
      return INIT_FAILED;
   }

   InitQuantumEngine();
   EventSetTimer(1);
   Print("[QUANTUM CORE] Engine Initialized. Securing Market Microstructure.");
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason) {
   EventKillTimer();
   if(g_hATR != INVALID_HANDLE) IndicatorRelease(g_hATR);
}

void OnTimer() {
   CheckNewsIntelligence();
   // Dashboard update will go here in Phase 2
}

//+------------------------------------------------------------------+
//| TRANSACTION HOOK - STRICT COOLDOWN ENFORCEMENT                   |
//+------------------------------------------------------------------+
void OnTradeTransaction(const MqlTradeTransaction &trans, const MqlTradeRequest &request, const MqlTradeResult &result) {
   if(trans.type != TRADE_TRANSACTION_DEAL_ADD) return;
   if(!HistoryDealSelect(trans.deal)) return;

   long magic = HistoryDealGetInteger(trans.deal, DEAL_MAGIC);
   string sym = HistoryDealGetString(trans.deal, DEAL_SYMBOL);
   long entry = HistoryDealGetInteger(trans.deal, DEAL_ENTRY);

   if(magic != (long)InpMagicNumber || sym != _Symbol) return;
   if(entry == DEAL_ENTRY_OUT || entry == DEAL_ENTRY_OUT_BY) {
      RegisterTradeClose();
   }
}

void RegisterTradeClose() {
   g_State      = STATE_COOLDOWN;
   g_StateTimer = TimeCurrent() + InpReEntryCooldownSec;
   g_StatusText = "QUANTUM COOLDOWN ACTIVE";
   g_StatusColor = clrOrange;
}

//+------------------------------------------------------------------+
//| TICK - MAIN EXECUTION LOOP                                       |
//+------------------------------------------------------------------+
void OnTick() {
   UpdateSpreadAverage();

   if(IsPositionOpen()) { 
      ManageOpenTradeQuantum(); 
      return;
   }

   if(g_State == STATE_NEWS_PAUSE) return;

   if(g_State == STATE_COOLDOWN) {
      if(TimeCurrent() >= g_StateTimer) g_State = STATE_SCANNING;
      else return;
   }

   if(g_State == STATE_SCANNING) {
      ENUM_SIGNAL sig = EvaluateQuantumConfluence();
      if(sig != SIGNAL_NONE) {
         ExecuteQuantumEntry(sig);
      } else {
         g_StatusText = "SCANNING MICROSTRUCTURE";
         g_StatusColor = clrGray;
      }
   }
}

//+------------------------------------------------------------------+
//| QUANTUM MATH & MICROSTRUCTURE LOGIC                              |
//+------------------------------------------------------------------+
void InitQuantumEngine() {
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   
   // Fast Tracker (Microstructure)
   g_QuantumFast.estimate      = bid;
   g_QuantumFast.error_cov     = 1.0;
   g_QuantumFast.process_noise = InpProcessNoise; 
   g_QuantumFast.measure_noise = InpMeasureNoise; 
   
   // Slow Tracker (Macro Trend Alignment)
   g_QuantumSlow.estimate      = bid;
   g_QuantumSlow.error_cov     = 1.0;
   g_QuantumSlow.process_noise = InpProcessNoise * 0.01; // Highly resistant to noise
   g_QuantumSlow.measure_noise = InpMeasureNoise * 5.0; 
}

double UpdateKalman(STRUCT_KALMAN_ENGINE &k, double currentPrice) {
   k.error_cov += k.process_noise;
   k.gain = k.error_cov / (k.error_cov + k.measure_noise);
   k.estimate = k.estimate + k.gain * (currentPrice - k.estimate);
   k.error_cov = (1.0 - k.gain) * k.error_cov;
   return k.estimate;
}

bool DetectInstitutionalFVG(ENUM_SIGNAL direction) {
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   if(CopyRates(_Symbol, _Period, 1, 4, rates) < 4) return false;
   
   if(direction == SIGNAL_BUY) {
      if(rates[0].low > rates[2].high) return true; // Bullish Gap
   }
   else if(direction == SIGNAL_SELL) {
      if(rates[0].high < rates[2].low) return true; // Bearish Gap
   }
   return false;
}

ENUM_SIGNAL EvaluateConfluence() {
   double currentBid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double fastState  = UpdateKalman(g_QuantumFast, currentBid);
   double slowState  = UpdateKalman(g_QuantumSlow, currentBid);
   
   // 1. Core Trend Alignment (Absolute rule: Do not buy if macro is dropping)
   bool isMacroBullish = (fastState > slowState);
   bool isMacroBearish = (fastState < slowState);
   
   // 2. Micro Deviation (Rubber band effect)
   double deviation = (currentBid - fastState) / _Point;
   
   ENUM_SIGNAL structuralBias = SIGNAL_NONE;
   
   if(isMacroBearish && deviation > 100.0)       structuralBias = SIGNAL_SELL; 
   else if(isMacroBullish && deviation < -100.0) structuralBias = SIGNAL_BUY;
   
   if(structuralBias == SIGNAL_NONE) return SIGNAL_NONE;
   
   // 3. FVG Institutional Validation
   if(DetectInstitutionalFVG(structuralBias)) {
      g_TradeScore = 9; // Elite validation
      return structuralBias;
   }
   
   return SIGNAL_NONE;
}

//+------------------------------------------------------------------+
//| COMPOUNDING SIZING & EXECUTION                                   |
//+------------------------------------------------------------------+
double CalculateMicroCompoundingLot(int slPoints, int setupScore) {
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   double riskFunds = equity * (InpRiskPercent / 100.0);
   
   double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double tickSize  = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   if(tickSize <= 0 || tickValue <= 0) return SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   
   double pointsValueCalculated = (tickValue / tickSize) * _Point;
   double rawLot = riskFunds / (slPoints * pointsValueCalculated);
   
   double minLot  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxLot  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   
   double normalizedLot = MathFloor(rawLot / lotStep) * lotStep;
   if(normalizedLot < minLot) normalizedLot = minLot;
   if(normalizedLot > maxLot) normalizedLot = maxLot;
   
   return NormalizeDouble(normalizedLot, 2);
}

void ExecuteQuantumEntry(ENUM_SIGNAL sig) {
   if(IsPositionOpen() || g_DailyTrades >= InpMaxDailyTrades) return;
   
   ENUM_ORDER_TYPE orderType = (sig == SIGNAL_BUY) ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
   double price = (sig == SIGNAL_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   
   double atr = GetATR();
   if(atr <= 0) return;
   
   int calcSLPoints = (int)MathMax(InpMinSLPoints, (atr * InpSLMultiplier) / _Point);
   int calcTPPoints = (int)(calcSLPoints * InpHardTPMultiplier); // Enforce mathematical expectancy
   
   double lotSize = CalculateMicroCompoundingLot(calcSLPoints, g_TradeScore);
   
   double slPrice = (sig == SIGNAL_BUY) ? (price - (calcSLPoints * _Point)) : (price + (calcSLPoints * _Point));
   double tpPrice = (sig == SIGNAL_BUY) ? (price + (calcTPPoints * _Point)) : (price - (calcTPPoints * _Point));
   
   MqlTradeRequest request;  ZeroMemory(request);
   MqlTradeResult  result;   ZeroMemory(result);
   
   request.action       = TRADE_ACTION_DEAL;
   request.symbol       = _Symbol;
   request.volume       = lotSize;
   request.type         = orderType;
   request.price        = price;
   request.sl           = NormalizeDouble(slPrice, _Digits);
   request.tp           = NormalizeDouble(tpPrice, _Digits);
   request.deviation    = 20;
   request.magic        = InpMagicNumber;
   request.comment      = InpTradeComment;
   request.type_filling = ORDER_FILLING_FOK;
   
   for(int i = 0; i < 3; i++) {
      if(OrderSend(request, result)) {
         if(result.retcode == TRADE_RETCODE_DONE || result.retcode == TRADE_RETCODE_PLACED) {
            g_DailyTrades++;
            g_StatusText = "QUANTUM DEAL ACTIVE";
            g_StatusColor = clrLime;
            break;
         }
      }
      if(result.retcode == TRADE_RETCODE_REQUOTE || result.retcode == TRADE_RETCODE_PRICE_OFF) {
         Sleep(150);
         request.price = (sig == SIGNAL_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);
      } else break; // Fatal error
   }
}

//+------------------------------------------------------------------+
//| POSITIVE EXPECTANCY MANAGEMENT (Dynamic R:R Trails)              |
//+------------------------------------------------------------------+
void ManageOpenTradeQuantum() {
   if(!PositionSelectByTicket(g_Pos.Ticket())) return;
   
   double entryPrice = g_Pos.PriceOpen();
   double currentBid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double currentAsk = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double stopLoss   = g_Pos.StopLoss();
   double takeProfit = g_Pos.TakeProfit();
   bool   isBuy      = (g_Pos.PositionType() == POSITION_TYPE_BUY);
   
   double initialRiskPoints = MathAbs(entryPrice - stopLoss) / _Point;
   if(initialRiskPoints <= 0) return;
   
   double currentProfitPoints = isBuy ? ((currentBid - entryPrice) / _Point) : ((entryPrice - currentAsk) / _Point);
   
   // Tiered Locking: Only lock forward, never backward.
   double tier1Trigger = initialRiskPoints * 1.5;
   double tier1Lock    = initialRiskPoints * 0.5; // Secure 0.5R
   
   double tier2Trigger = initialRiskPoints * 2.5;
   double tier2Lock    = initialRiskPoints * 1.5; // Secure 1.5R
   
   if(currentProfitPoints >= tier2Trigger) {
      double newSL = isBuy ? (entryPrice + (tier2Lock * _Point)) : (entryPrice - (tier2Lock * _Point));
      if((isBuy && newSL > stopLoss) || (!isBuy && (newSL < stopLoss || stopLoss == 0))) {
         g_Trade.PositionModify(g_Pos.Ticket(), NormalizeDouble(newSL, _Digits), NormalizeDouble(takeProfit, _Digits));
      }
   }
   else if(currentProfitPoints >= tier1Trigger) {
      double newSL = isBuy ? (entryPrice + (tier1Lock * _Point)) : (entryPrice - (tier1Lock * _Point));
      if((isBuy && newSL > stopLoss) || (!isBuy && (newSL < stopLoss || stopLoss == 0))) {
         g_Trade.PositionModify(g_Pos.Ticket(), NormalizeDouble(newSL, _Digits), NormalizeDouble(takeProfit, _Digits));
      }
   }
}

//+------------------------------------------------------------------+
//| UTILITIES & NEWS INTELLIGENCE                                    |
//+------------------------------------------------------------------+
void CheckNewsIntelligence() {
   if(!InpUseNewsFilter) return;
   
   MqlCalendarValue values[];
   datetime start = TimeCurrent() - (InpNewsPauseBefore * 60);
   datetime end   = TimeCurrent() + (InpNewsPauseAfter * 60);
   
   if(CalendarValueHistory(values, start, end, NULL, "USD")) {
      for(int i = 0; i < ArraySize(values); i++) {
         MqlCalendarEvent ev;
         if(CalendarEventById(values[i].event_id, ev)) {
            if(ev.importance == CALENDAR_IMPORTANCE_HIGH) {
               g_State = STATE_NEWS_PAUSE;
               g_StatusText = "HIGH IMPACT NEWS PAUSE";
               g_StatusColor = clrRed;
               return;
            }
         }
      }
   }
   if(g_State == STATE_NEWS_PAUSE) g_State = STATE_SCANNING;
}

double GetATR() {
   double a[1];
   if(CopyBuffer(g_hATR, 0, 0, 1, a) != 1) return 0.0;
   return a[0];
}

bool IsPositionOpen() {
   for(int i = PositionsTotal()-1; i >= 0; i--) {
      if(g_Pos.SelectByIndex(i) && g_Pos.Magic() == InpMagicNumber && g_Pos.Symbol() == _Symbol) return true;
   }
   return false;
}

void UpdateSpreadAverage() {
   double spread = (double)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   g_AvgSpread = (g_AvgSpread * g_SpreadSamples + spread) / (double)(g_SpreadSamples + 1);
   g_SpreadSamples = MathMin(g_SpreadSamples + 1, 1000);
}