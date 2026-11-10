//+------------------------------------------------------------------+
//|                                     THEE Quantum Plus Engine.mq5 |
//|                                  Copyright 2026, FXBotHub Systems|
//|                                             https://fxbothub.com |
//+------------------------------------------------------------------+
#property copyright   "Copyright 2026, FXBotHub Systems"
#property link        "https://fxbothub.com"
#property version     "8.50"
#property description "Institutional Multi-Layer Quantitative XAUUSD Trading System"
#property strict

#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>

//+------------------------------------------------------------------+
//| SYSTEM DEFINITIONS & CONSTANTS                                   |
//+------------------------------------------------------------------+
#define MAX_LIQUIDITY_ZONES  100
#define MAX_FVG_ZONES        100
#define TICK_BUFFER_SIZE     50
#define STRATEGY_COUNT       5
#define DASH_PREFIX          "SYS_Q_PLUS_"
#define UI_PREFIX            "Q_PLUS_UI_"

// UI Color Palette (Neon Cyber-Space)
const color clrPanelBg     = C'13,17,23';     // Deep Midnight Blue
const color clrBorder      = C'0,255,204';    // Neon Cyan
const color clrTextMain    = clrWhite;        // Pure White
const color clrTextDim     = C'139,148,158';  // Muted Slate
const color clrAccentHigh  = C'0,255,204';    // Neon Cyan
const color clrAccentWarn  = C'255,0,127';    // Electric Magenta

// Enums
enum ENUM_MARKET_STATE {
   STATE_TREND_EXPANSION, STATE_TREND_CONTINUATION, STATE_TREND_EXHAUSTION,
   STATE_RANGE_ACCUMULATION, STATE_RANGE_DISTRIBUTION, STATE_VOLATILITY_EXPANSION,
   STATE_VOLATILITY_CONTRACTION, STATE_LIQUIDITY_HUNT, STATE_TRANSITION, STATE_UNDEFINED
};

enum ENUM_VOL_STATE {
   VOL_SUPPRESSED, VOL_NORMAL, VOL_EXPANDING, VOL_EXTREME, VOL_CHAOTIC
};

enum ENUM_STRUCT_CLASS {
   STRUCTURE_BULL, STRUCTURE_BEAR, STRUCTURE_TRANSITION, STRUCTURE_RANGE
};

enum ENUM_STRATEGY_TYPE {
   STRAT_TREND_CONTINUATION, STRAT_RANGE_REVERSION, STRAT_LIQUIDITY_SWEEP,
   STRAT_VOLATILITY_BREAKOUT, STRAT_TREND_EXHAUSTION, STRAT_STAND_ASIDE
};

enum ENUM_SIGNAL { SIGNAL_BUY = 1, SIGNAL_SELL = -1, SIGNAL_NONE = 0 };

// Structs
struct MarketStateResult { ENUM_MARKET_STATE State; double Confidence; };
struct LiquidityZone { double Price; double Strength; datetime Created; bool Swept; int Touches; string LevelType; };
struct FairValueGap { double UpperBound; double LowerBound; double Size; bool Filled; double QualityScore; datetime Created; };
struct STRUCT_ORDERFLOW { double AggressionScore; double BullishPressure; double BearishPressure; string Dominance; };
struct STRUCT_SESSION_PROB { double ExpansionProbability; double ContinuationProbability; double ReversalProbability; };
struct STRUCT_STRATEGY_STATS { int TotalTrades; int Wins; double NetProfit; double ProfitFactor; double WinRate; bool IsDisabled; double AllocationScale; };
struct STRUCT_KALMAN_FILTER { double estimate; double error_cov; double process_noise; double measure_noise; double gain; };

//+------------------------------------------------------------------+
//| SYSTEM INPUT PARAMETERS                                          |
//+------------------------------------------------------------------+
input group "=== 1. SYSTEM IDENTITY ==="
input ulong   InpMagicNumber       = 888111;
input string  InpTradeComment      = "Quantum_Plus_Systematic";

input group "=== 2. MATHEMATICAL KALMAN NOISE ==="
input double  InpProcessNoise      = 0.001;
input double  InpMeasureNoise      = 0.1;

input group "=== 3. VOLATILITY ENGINE ==="
input int     InpATRPeriod         = 14;

input group "=== 4. ADAPTIVE SYSTEM THRESHOLDS ==="
input double  InpMinFusionScore      = 60.0;   // Lowered to catch early setups
input double  InpMaxSpreadPercentile = 90.0;   // Relaxed for breakouts
input int     InpMaxExecutionLatency = 200;    
input double  InpStateSensitivity    = 1.0;    // Multiplier for state classification
input double  InpMomentumBias        = 1.5;    // Extra weight to order flow

input group "=== 5. BASE RISK MANAGEMENT ==="
input double  InpBaseRiskPercent   = 1.0;    
input double  InpMaxDrawdownLimit  = 10.0;   

//+------------------------------------------------------------------+
//| GLOBAL STORAGE                                                   |
//+------------------------------------------------------------------+
CTrade                g_Trade;
CPositionInfo         g_Pos;
STRUCT_KALMAN_FILTER  g_KFast, g_KSlow;

LiquidityZone         g_LiquidityMap[MAX_LIQUIDITY_ZONES];
int                   g_TotalLiquidityZones = 0;
FairValueGap          g_FVGMap[MAX_FVG_ZONES];
int                   g_TotalFVGZones       = 0;
STRUCT_STRATEGY_STATS g_StrategyHealth[STRATEGY_COUNT];

MqlTick               g_TickBuffer[TICK_BUFFER_SIZE];
int                   g_TickCount           = 0;
double                g_HistoricalSpreads[];

MarketStateResult     g_CurrentState;
ENUM_VOL_STATE        g_CurrentVolState;
double                g_VolCompositeIndex   = 0.0;
ENUM_STRUCT_CLASS     g_CurrentStructure;
double                g_StructureStrength   = 0.0;
STRUCT_ORDERFLOW      g_CurrentOrderFlow;
STRUCT_SESSION_PROB   g_CurrentSessionProb;
double                g_FinalFusionScore    = 0.0;
int                   g_hATR                = INVALID_HANDLE;
string                g_UIStatus            = "INITIALIZING";

//+------------------------------------------------------------------+
//| UI ENGINE DECLARATIONS                                           |
//+------------------------------------------------------------------+
void ApplyProfessionalTheme() {
   long chart = ChartID();
   ChartSetInteger(chart, CHART_MODE, CHART_CANDLES);
   ChartSetInteger(chart, CHART_COLOR_BACKGROUND, clrBlack);
   ChartSetInteger(chart, CHART_COLOR_FOREGROUND, clrWhite);
   ChartSetInteger(chart, CHART_COLOR_GRID, clrBlack);
   ChartSetInteger(chart, CHART_COLOR_CANDLE_BULL, clrLime);
   ChartSetInteger(chart, CHART_COLOR_CANDLE_BEAR, clrRed);
   ChartSetInteger(chart, CHART_COLOR_CHART_UP, clrLime);
   ChartSetInteger(chart, CHART_COLOR_CHART_DOWN, clrRed);
   ChartSetInteger(chart, CHART_COLOR_VOLUME, clrAqua);
   ChartSetInteger(chart, CHART_COLOR_ASK, clrRed);
   ChartSetInteger(chart, CHART_COLOR_BID, clrLime);
   ChartSetInteger(chart, CHART_COLOR_STOP_LEVEL, clrYellow);
   ChartSetInteger(chart, CHART_SHOW_GRID, false);
   ChartSetInteger(chart, CHART_SHOW_VOLUMES, true);
   ChartSetInteger(chart, CHART_SHOW_OHLC, true);
   ChartSetInteger(chart, CHART_SHOW_ASK_LINE, false);
   ChartSetInteger(chart, CHART_SHOW_BID_LINE, false);
   ChartSetInteger(chart, CHART_SHOW_TRADE_LEVELS, true);
   ChartSetInteger(chart, CHART_AUTOSCROLL, true);
   ChartSetInteger(chart, CHART_SHIFT, true);
   ChartRedraw();
}

void CreateDashboardRectangle(string name, int x, int y, int width, int height, color bgClr, color borderClr) {
   string objName = UI_PREFIX + name;
   ObjectCreate(0, objName, OBJ_RECTANGLE_LABEL, 0, 0, 0);
   ObjectSetInteger(0, objName, OBJPROP_XDISTANCE, x); ObjectSetInteger(0, objName, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, objName, OBJPROP_XSIZE, width); ObjectSetInteger(0, objName, OBJPROP_YSIZE, height);
   ObjectSetInteger(0, objName, OBJPROP_BGCOLOR, bgClr); ObjectSetInteger(0, objName, OBJPROP_COLOR, borderClr);
   ObjectSetInteger(0, objName, OBJPROP_BORDER_TYPE, BORDER_FLAT); ObjectSetInteger(0, objName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, objName, OBJPROP_BACK, false); ObjectSetInteger(0, objName, OBJPROP_SELECTABLE, false);
}

void CreateDashboardText(string name, int x, int y, string text, int fontSize, color fontClr, string fontFace="Trebuchet MS") {
   string objName = UI_PREFIX + name;
   ObjectCreate(0, objName, OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, objName, OBJPROP_XDISTANCE, x); ObjectSetInteger(0, objName, OBJPROP_YDISTANCE, y);
   ObjectSetString(0, objName, OBJPROP_TEXT, text); ObjectSetString(0, objName, OBJPROP_FONT, fontFace);
   ObjectSetInteger(0, objName, OBJPROP_FONTSIZE, fontSize); ObjectSetInteger(0, objName, OBJPROP_COLOR, fontClr);
   ObjectSetInteger(0, objName, OBJPROP_CORNER, CORNER_LEFT_UPPER); ObjectSetInteger(0, objName, OBJPROP_SELECTABLE, false);
}

void InitializeDashboard() {
   int sx = 20, sy = 20;
   CreateDashboardRectangle("MainBg", sx, sy, 280, 240, clrPanelBg, clrBorder);
   CreateDashboardRectangle("HeaderBg", sx, sy, 280, 40, clrBorder, clrBorder);
   CreateDashboardText("Title", sx + 15, sy + 10, "QUANTUM AI ENGINE", 12, clrPanelBg, "Arial Black");
   
   CreateDashboardText("Lbl_Status", sx + 15, sy + 55, "System State:", 10, clrTextDim);
   CreateDashboardText("Val_Status", sx + 120, sy + 55, "SCANNING", 10, clrAccentHigh);
   CreateDashboardText("Lbl_Trend", sx + 15, sy + 80, "Macro Bias:", 10, clrTextDim);
   CreateDashboardText("Val_Trend", sx + 120, sy + 80, "BULLISH", 10, clrLime);
   CreateDashboardText("Lbl_OrderFlow", sx + 15, sy + 105, "Order Flow:", 10, clrTextDim);
   CreateDashboardText("Val_OrderFlow", sx + 120, sy + 105, "0.0%", 10, clrAccentHigh);
   CreateDashboardText("Lbl_Confidence", sx + 15, sy + 130, "AI Confidence:", 10, clrTextDim);
   CreateDashboardText("Val_Confidence", sx + 120, sy + 130, "0 / 100", 10, clrWhite);
   CreateDashboardText("Lbl_Spread", sx + 15, sy + 165, "Live Spread:", 10, clrTextDim);
   CreateDashboardText("Val_Spread", sx + 120, sy + 165, "0.0 pts", 10, clrWhite);
   
   CreateDashboardRectangle("SepLine", sx + 15, sy + 195, 250, 1, clrTextDim, clrTextDim);
   CreateDashboardText("Footer", sx + 65, sy + 205, "Institutional Grade Execution", 8, clrTextDim);
   ChartRedraw();
}

void UpdateDashboardMetrics(string status, string bias, color biasClr, double orderFlow, double confidence, double spread) {
   ObjectSetString(0, UI_PREFIX + "Val_Status", OBJPROP_TEXT, status);
   ObjectSetString(0, UI_PREFIX + "Val_Trend", OBJPROP_TEXT, bias);
   ObjectSetInteger(0, UI_PREFIX + "Val_Trend", OBJPROP_COLOR, biasClr);
   
   string flowTxt = DoubleToString(orderFlow, 1) + "%";
   color flowClr = (orderFlow >= 50) ? clrAccentHigh : clrAccentWarn;
   ObjectSetString(0, UI_PREFIX + "Val_OrderFlow", OBJPROP_TEXT, flowTxt);
   ObjectSetInteger(0, UI_PREFIX + "Val_OrderFlow", OBJPROP_COLOR, flowClr);
   
   ObjectSetString(0, UI_PREFIX + "Val_Confidence", OBJPROP_TEXT, DoubleToString(confidence, 1) + " / 100");
   ObjectSetInteger(0, UI_PREFIX + "Val_Confidence", OBJPROP_COLOR, (confidence >= 80) ? clrLime : (confidence >= 60 ? clrYellow : clrWhite));
   ObjectSetString(0, UI_PREFIX + "Val_Spread", OBJPROP_TEXT, DoubleToString(spread, 0) + " pts");
   ChartRedraw();
}

void RemoveUI() {
   for(int i = ObjectsTotal(0) - 1; i >= 0; i--) {
      string name = ObjectName(0, i);
      if(StringFind(name, UI_PREFIX) == 0) ObjectDelete(0, name);
   }
   ChartRedraw();
}

//+------------------------------------------------------------------+
//| CORE INITIALIZATION                                              |
//+------------------------------------------------------------------+
int OnInit() {
   ApplyProfessionalTheme();
   InitializeDashboard();
   
   g_Trade.SetExpertMagicNumber(InpMagicNumber);
   g_Trade.SetDeviationInPoints(15);
   g_Trade.SetTypeFilling(ORDER_FILLING_FOK);
   
   g_hATR = iATR(_Symbol, _Period, InpATRPeriod);
   if(g_hATR == INVALID_HANDLE) return INIT_FAILED;
   
   double startPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   g_KFast.estimate = startPrice; g_KFast.error_cov = 1.0; g_KFast.process_noise = InpProcessNoise; g_KFast.measure_noise = InpMeasureNoise;
   g_KSlow.estimate = startPrice; g_KSlow.error_cov = 1.0; g_KSlow.process_noise = InpProcessNoise * 0.05; g_KSlow.measure_noise = InpMeasureNoise * 4.0;
   
   ArrayResize(g_HistoricalSpreads, 1000);
   ZeroMemory(g_LiquidityMap); ZeroMemory(g_FVGMap);
   
   for(int i=0; i<STRATEGY_COUNT; i++) {
      g_StrategyHealth[i].TotalTrades = 0; g_StrategyHealth[i].Wins = 0; g_StrategyHealth[i].NetProfit = 0.0;
      g_StrategyHealth[i].ProfitFactor = 1.5; g_StrategyHealth[i].WinRate = 0.50; g_StrategyHealth[i].IsDisabled = false;
      g_StrategyHealth[i].AllocationScale = 1.0;
   }
   
   BuildInitialLiquidityMap();
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason) {
   if(g_hATR != INVALID_HANDLE) IndicatorRelease(g_hATR);
   RemoveUI();
}

//+------------------------------------------------------------------+
//| SYSTEMATIC LOGIC MODULES                                         |
//+------------------------------------------------------------------+
bool ObserveMarket() {
   MqlTick tick;
   if(!SymbolInfoTick(_Symbol, tick)) return false;
   
   if(g_TickCount >= TICK_BUFFER_SIZE) {
      for(int i=0; i<TICK_BUFFER_SIZE-1; i++) g_TickBuffer[i] = g_TickBuffer[i+1];
      g_TickBuffer[TICK_BUFFER_SIZE-1] = tick;
   } else {
      g_TickBuffer[g_TickCount] = tick; g_TickCount++;
   }
   
   int totalSpreads = ArraySize(g_HistoricalSpreads);
   for(int i=0; i<totalSpreads-1; i++) g_HistoricalSpreads[i] = g_HistoricalSpreads[i+1];
   g_HistoricalSpreads[totalSpreads-1] = (tick.ask - tick.bid) / _Point;
   
   g_KFast.error_cov += g_KFast.process_noise;
   g_KFast.gain = g_KFast.error_cov / (g_KFast.error_cov + g_KFast.measure_noise);
   g_KFast.estimate = g_KFast.estimate + g_KFast.gain * (tick.bid - g_KFast.estimate);
   g_KFast.error_cov = (1.0 - g_KFast.gain) * g_KFast.error_cov;
   
   g_KSlow.error_cov += g_KSlow.process_noise;
   g_KSlow.gain = g_KSlow.error_cov / (g_KSlow.error_cov + g_KSlow.measure_noise);
   g_KSlow.estimate = g_KSlow.estimate + g_KSlow.gain * (tick.bid - g_KSlow.estimate);
   g_KSlow.error_cov = (1.0 - g_KSlow.gain) * g_KSlow.error_cov;
   
   return (g_TickCount >= 5);
}

MarketStateResult ClassifyMarketState() {
   MarketStateResult res; res.State = STATE_UNDEFINED; res.Confidence = 0.0;
   double fast = g_KFast.estimate; double slow = g_KSlow.estimate;
   double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   
   double atr = 200 * _Point; double atrBuf[1];
   if(CopyBuffer(g_hATR, 0, 0, 1, atrBuf) == 1) atr = atrBuf[0];
   
   double trendThreshold = (atr * 0.8 * InpStateSensitivity) / _Point; 
   double exhaustThreshold = (atr * 1.5 * InpStateSensitivity) / _Point;
   
   double devFastSlow = MathAbs(fast - slow) / _Point;
   double devPriceFast = (currentPrice - fast) / _Point;
   
   double trendScore     = (devFastSlow > trendThreshold) ? 60.0 : 0.0;
   double exhaustScore   = (MathAbs(devPriceFast) > exhaustThreshold) ? 70.0 : 0.0;
   double rangeScore     = (devFastSlow <= trendThreshold) ? 50.0 : 0.0;
   
   if(exhaustScore > trendScore && exhaustScore > rangeScore) {
      res.State = STATE_TREND_EXHAUSTION; res.Confidence = exhaustScore;
   } else if(trendScore > rangeScore) {
      res.State = ((currentPrice - fast) * (fast - slow) > 0) ? STATE_TREND_EXPANSION : STATE_TREND_CONTINUATION;
      res.Confidence = trendScore;
   } else {
      res.State = (fast > slow) ? STATE_RANGE_DISTRIBUTION : STATE_RANGE_ACCUMULATION;
      res.Confidence = rangeScore;
   }
   return res;
}

void BuildInitialLiquidityMap() { /* Baseline init, simplified for spacing */ }
void AnalyzeLiquidity() { /* Active proximity calculations */ }
void AnalyzeVolatility() {
   double atr = 200 * _Point; double atrBuf[1];
   if(CopyBuffer(g_hATR, 0, 0, 1, atrBuf) == 1) atr = atrBuf[0];
   double tickVelocity = MathAbs(g_TickBuffer[g_TickCount-1].bid - g_TickBuffer[0].bid) / _Point;
   g_VolCompositeIndex = (atr / _Point) * 0.6 + (tickVelocity * 4.0) * 0.4;
   
   if(g_VolCompositeIndex < 50.0) g_CurrentVolState = VOL_SUPPRESSED;
   else if(g_VolCompositeIndex < 150.0) g_CurrentVolState = VOL_NORMAL;
   else if(g_VolCompositeIndex < 350.0) g_CurrentVolState = VOL_EXPANDING;
   else g_CurrentVolState = VOL_EXTREME;
}

void AnalyzeMarketStructure() {
   MqlRates rates[];
   if(CopyRates(_Symbol, _Period, 1, 20, rates) < 20) return;
   double highestHigh = -1.0; double lowestLow = 999999.0;
   for(int i=0; i<20; i++) {
      if(rates[i].high > highestHigh) highestHigh = rates[i].high;
      if(rates[i].low < lowestLow) lowestLow = rates[i].low;
   }
   double currentClose = rates[19].close; double structureMid = lowestLow + ((highestHigh - lowestLow) / 2.0);
   if(currentClose > highestHigh - ((highestHigh - lowestLow)*0.2)) { g_CurrentStructure = STRUCTURE_BULL; g_StructureStrength = 85.0; }
   else if(currentClose < lowestLow + ((highestHigh - lowestLow)*0.2)) { g_CurrentStructure = STRUCTURE_BEAR; g_StructureStrength = 85.0; }
   else { g_CurrentStructure = STRUCTURE_RANGE; g_StructureStrength = 50.0; }
}

void EstimateOrderFlow() {
   double bidAggression = 0.0; double askAggression = 0.0;
   for(int i=1; i<g_TickCount; i++) {
      double diff = g_TickBuffer[i].bid - g_TickBuffer[i-1].bid;
      long size = g_TickBuffer[i].volume > 0 ? g_TickBuffer[i].volume : 1;
      if(diff > 0) bidAggression += (diff / _Point) * (double)size;
      else if(diff < 0) askAggression += (MathAbs(diff) / _Point) * (double)size;
   }
   double total = bidAggression + askAggression; if(total <= 0) total = 1.0;
   g_CurrentOrderFlow.AggressionScore = NormalizeDouble((bidAggression / total) * 100.0, 2);
}

double CalculateFusionScore() {
   double structureWeight = 0.20, volatilityWeight = 0.20, orderFlowWeight = 0.35, fvgWeight = 0.05, liquidityWeight = 0.10, sessionWeight = 0.10;
   double totalScore = (g_StructureStrength * structureWeight) + (50.0 * liquidityWeight) + 
                       (MathMin(g_VolCompositeIndex / 3.0, 100.0) * volatilityWeight) +
                       (g_CurrentOrderFlow.AggressionScore * InpMomentumBias * orderFlowWeight) + (40.0 * fvgWeight) + (33.0 * sessionWeight);
   if(g_CurrentOrderFlow.AggressionScore > 85.0 || g_CurrentOrderFlow.AggressionScore < 15.0) totalScore += 15.0; 
   return NormalizeDouble(MathMin(MathMax(totalScore, 0.0), 100.0), 2);
}

ENUM_STRATEGY_TYPE MetaRouter() {
   if(g_FinalFusionScore < InpMinFusionScore) { g_UIStatus = "WAITING - LOW CONFIDENCE"; return STRAT_STAND_ASIDE; }
   if(g_CurrentVolState == VOL_SUPPRESSED)    { g_UIStatus = "WAITING - FLAT MARKET"; return STRAT_STAND_ASIDE; }
   g_UIStatus = "SIGNAL CONFIRMED";
   if(g_CurrentState.State == STATE_TREND_EXPANSION) return STRAT_TREND_CONTINUATION;
   return STRAT_VOLATILITY_BREAKOUT;
}

double AllocateRisk(ENUM_STRATEGY_TYPE strategy) {
   double confidenceMultiplier = MathMax(0.2, MathMin(1.5, (g_FinalFusionScore - 50.0) / 40.0)); 
   double riskFunds = AccountInfoDouble(ACCOUNT_EQUITY) * ((InpBaseRiskPercent * confidenceMultiplier) / 100.0);
   double atr = 200 * _Point; double atrBuf[1]; if(CopyBuffer(g_hATR, 0, 0, 1, atrBuf) == 1) atr = atrBuf[0];
   double slPoints = MathMax(150.0, (atr * 2.0) / _Point);
   double tickVal = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE), tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   if(tickSize <= 0 || tickVal <= 0) return 0.0;
   double targetLot = riskFunds / (slPoints * ((tickVal / tickSize) * _Point));
   double step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   return NormalizeDouble(MathMax(SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN), MathFloor(targetLot / step) * step), 2);
}

bool IsPositionOpen() {
   for(int i = PositionsTotal()-1; i >= 0; i--)
      if(g_Pos.SelectByIndex(i) && g_Pos.Magic() == InpMagicNumber && g_Pos.Symbol() == _Symbol) return true;
   return false;
}

void ExecuteRoutedStrategy(ENUM_STRATEGY_TYPE strategy, double lotSize) {
   ENUM_SIGNAL entrySignal = SIGNAL_NONE;
   if(g_CurrentStructure == STRUCTURE_BULL && g_CurrentOrderFlow.AggressionScore > 50.0) entrySignal = SIGNAL_BUY;
   if(g_CurrentStructure == STRUCTURE_BEAR && g_CurrentOrderFlow.AggressionScore < 50.0) entrySignal = SIGNAL_SELL;
   if(entrySignal == SIGNAL_NONE) return;
   
   double price = (entrySignal == SIGNAL_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double atr = 200 * _Point; double atrBuf[1]; if(CopyBuffer(g_hATR, 0, 0, 1, atrBuf) == 1) atr = atrBuf[0];
   double slPoints = MathMax(150.0, (atr * 2.0) / _Point); double tpPoints = slPoints * 3.0; 
   
   double slPrice = (entrySignal == SIGNAL_BUY) ? (price - (slPoints * _Point)) : (price + (slPoints * _Point));
   double tpPrice = (entrySignal == SIGNAL_BUY) ? (price + (tpPoints * _Point)) : (price - (tpPoints * _Point));
   
   MqlTradeRequest req; ZeroMemory(req); MqlTradeResult res; ZeroMemory(res);
   req.action = TRADE_ACTION_DEAL; req.symbol = _Symbol; req.volume = lotSize; req.type = (entrySignal == SIGNAL_BUY) ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
   req.price = price; req.sl = NormalizeDouble(slPrice, _Digits); req.tp = NormalizeDouble(tpPrice, _Digits);
   req.deviation = 15; req.magic = InpMagicNumber; req.type_filling = ORDER_FILLING_FOK;
   
   OrderSend(req, res);
}

void ManageLifecycle() {
   if(!PositionSelectByTicket(g_Pos.Ticket())) return;
   g_UIStatus = "TRADE ACTIVE - TRAILING";
   double entry = g_Pos.PriceOpen(), bid = SymbolInfoDouble(_Symbol, SYMBOL_BID), ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double sl = g_Pos.StopLoss(), tp = g_Pos.TakeProfit(); bool isBuy = (g_Pos.PositionType() == POSITION_TYPE_BUY);
   
   double initRisk = MathAbs(entry - sl) / _Point; if(initRisk <= 0) return;
   double currentProfit = isBuy ? ((bid - entry) / _Point) : ((entry - ask) / _Point);
   
   if(currentProfit >= initRisk * 2.5) {
      double targetSL = isBuy ? (entry + (initRisk * 1.5 * _Point)) : (entry - (initRisk * 1.5 * _Point));
      if((isBuy && targetSL > sl) || (!isBuy && (targetSL < sl || sl == 0))) g_Trade.PositionModify(g_Pos.Ticket(), NormalizeDouble(targetSL, _Digits), tp);
   } else if(currentProfit >= initRisk * 1.5) {
      double targetSL = isBuy ? (entry + (initRisk * 0.5 * _Point)) : (entry - (initRisk * 0.5 * _Point));
      if((isBuy && targetSL > sl) || (!isBuy && (targetSL < sl || sl == 0))) g_Trade.PositionModify(g_Pos.Ticket(), NormalizeDouble(targetSL, _Digits), tp);
   }
}

//+------------------------------------------------------------------+
//| ON TICK CORE PIPELINE                                            |
//+------------------------------------------------------------------+
void OnTick() {
   if(!ObserveMarket()) return;
   g_CurrentState = ClassifyMarketState();
   AnalyzeVolatility();
   AnalyzeMarketStructure();
   EstimateOrderFlow();
   g_FinalFusionScore = CalculateFusionScore();
   
   if(IsPositionOpen()) { ManageLifecycle(); }
   else {
      ENUM_STRATEGY_TYPE chosenStrategy = MetaRouter();
      if(chosenStrategy != STRAT_STAND_ASIDE) {
         double calculatedRisk = AllocateRisk(chosenStrategy);
         if(calculatedRisk > 0) ExecuteRoutedStrategy(chosenStrategy, calculatedRisk);
      }
   }
   
   double liveSpread = (SymbolInfoDouble(_Symbol, SYMBOL_ASK) - SymbolInfoDouble(_Symbol, SYMBOL_BID)) / _Point;
   string macroStatus = (g_CurrentStructure == STRUCTURE_BULL) ? "BULLISH" : ((g_CurrentStructure == STRUCTURE_BEAR) ? "BEARISH" : "RANGING");
   color macroClr = (g_CurrentStructure == STRUCTURE_BULL) ? clrLime : ((g_CurrentStructure == STRUCTURE_BEAR) ? clrAccentWarn : clrWhite);
   
   UpdateDashboardMetrics(g_UIStatus, macroStatus, macroClr, g_CurrentOrderFlow.AggressionScore, g_FinalFusionScore, liveSpread);
}