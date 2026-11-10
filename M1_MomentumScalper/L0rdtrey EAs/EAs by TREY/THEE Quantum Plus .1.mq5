//+------------------------------------------------------------------+
//|                                     THEE Quantum Plus Engine.mq5 |
//|                                  Copyright 2026, FXBotHub Systems|
//|                                             https://fxbothub.com |
//+------------------------------------------------------------------+
#property copyright   "Copyright 2026, FXBotHub Systems"
#property link        "https://fxbothub.com"
#property version     "8.60"
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
   STATE_TREND_EXPANSION, 
   STATE_TREND_CONTINUATION, 
   STATE_TREND_EXHAUSTION,
   STATE_RANGE_ACCUMULATION, 
   STATE_RANGE_DISTRIBUTION, 
   STATE_VOLATILITY_EXPANSION,
   STATE_VOLATILITY_CONTRACTION, 
   STATE_LIQUIDITY_HUNT, 
   STATE_TRANSITION, 
   STATE_UNDEFINED
};

enum ENUM_VOL_STATE {
   VOL_SUPPRESSED, 
   VOL_NORMAL, 
   VOL_EXPANDING, 
   VOL_EXTREME, 
   VOL_CHAOTIC
};

enum ENUM_STRUCT_CLASS {
   STRUCTURE_BULL, 
   STRUCTURE_BEAR, 
   STRUCTURE_TRANSITION, 
   STRUCTURE_RANGE
};

enum ENUM_STRATEGY_TYPE {
   STRAT_TREND_CONTINUATION, 
   STRAT_RANGE_REVERSION, 
   STRAT_LIQUIDITY_SWEEP,
   STRAT_VOLATILITY_BREAKOUT, 
   STRAT_TREND_EXHAUSTION, 
   STRAT_STAND_ASIDE
};

enum ENUM_SIGNAL { 
   SIGNAL_BUY = 1, 
   SIGNAL_SELL = -1, 
   SIGNAL_NONE = 0 
};

// Structs
struct MarketStateResult { 
   ENUM_MARKET_STATE State; 
   double Confidence; 
};

struct LiquidityZone { 
   double Price; 
   double Strength; 
   datetime Created; 
   bool Swept; 
   int Touches; 
   string LevelType; 
};

struct FairValueGap { 
   double UpperBound; 
   double LowerBound; 
   double Size; 
   bool Filled; 
   double QualityScore; 
   datetime Created; 
};

struct STRUCT_ORDERFLOW { 
   double AggressionScore; 
   double BullishPressure; 
   double BearishPressure; 
   string Dominance; 
};

struct STRUCT_SESSION_PROB { 
   double ExpansionProbability; 
   double ContinuationProbability; 
   double ReversalProbability; 
};

struct STRUCT_STRATEGY_STATS { 
   int TotalTrades; 
   int Wins; 
   double NetProfit; 
   double ProfitFactor; 
   double WinRate; 
   bool IsDisabled; 
   double AllocationScale; 
};

struct STRUCT_KALMAN_FILTER { 
   double estimate; 
   double error_cov; 
   double process_noise; 
   double measure_noise; 
   double gain; 
};

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
input double  InpMinFusionScore      = 65.0;   // Minimum confidence for entry
input double  InpMaxSpreadPercentile = 85.0;   // Maximum allowed spread percentile
input int     InpMaxExecutionLatency = 200;    
input double  InpStateSensitivity    = 1.0;    // Multiplier for state classification
input double  InpMomentumBias        = 1.2;    // Extra weight to order flow (reduced from 1.5)

input group "=== 5. RISK MANAGEMENT ==="
input double  InpBaseRiskPercent   = 1.0;      // Risk per trade (%)
input double  InpMaxDrawdownLimit  = 10.0;     // Maximum drawdown limit (%)
input double  InpRiskRewardRatio   = 2.5;      // Target Risk:Reward Ratio
input double  InpStopLossATRMulti  = 1.8;      // Stop Loss ATR Multiplier
input double  InpTakeProfitATRMulti = 4.5;     // Take Profit ATR Multiplier
input double  InpMinStopLossPoints = 200.0;    // Minimum SL in points (for XAUUSD)
input double  InpMaxStopLossPoints = 800.0;    // Maximum SL in points

input group "=== 6. TRAILING STOP SETTINGS ==="
input bool    InpUseTrailingStop   = true;     // Enable Trailing Stop
input double  InpTrailStartRR      = 1.5;      // Start trailing at R:R ratio
input double  InpTrailStepRR       = 0.5;      // Trail step in R multiples
input double  InpBreakEvenRR       = 1.0;      // Move to breakeven at R:R

input group "=== 7. TRADE FILTERS ==="
input double  InpMaxSpreadPoints   = 50.0;     // Maximum spread in points
input int     InpMinBarsBetween    = 5;        // Minimum bars between trades
input bool    InpOnlyTradeTrends   = false;    // Only trade trending markets

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
datetime              g_LastTradeTime       = 0;
ulong                 g_CurrentTicket       = 0;
double                g_InitialRiskPoints   = 0;

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

void CreateDashboardRectangle(string name, int x, int y, int width, int height, 
                               color bgClr, color borderClr) {
   string objName = UI_PREFIX + name;
   ObjectCreate(0, objName, OBJ_RECTANGLE_LABEL, 0, 0, 0);
   ObjectSetInteger(0, objName, OBJPROP_XDISTANCE, x); 
   ObjectSetInteger(0, objName, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, objName, OBJPROP_XSIZE, width); 
   ObjectSetInteger(0, objName, OBJPROP_YSIZE, height);
   ObjectSetInteger(0, objName, OBJPROP_BGCOLOR, bgClr); 
   ObjectSetInteger(0, objName, OBJPROP_COLOR, borderClr);
   ObjectSetInteger(0, objName, OBJPROP_BORDER_TYPE, BORDER_FLAT); 
   ObjectSetInteger(0, objName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, objName, OBJPROP_BACK, false); 
   ObjectSetInteger(0, objName, OBJPROP_SELECTABLE, false);
}

void CreateDashboardText(string name, int x, int y, string text, int fontSize, 
                         color fontClr, string fontFace="Trebuchet MS") {
   string objName = UI_PREFIX + name;
   ObjectCreate(0, objName, OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, objName, OBJPROP_XDISTANCE, x); 
   ObjectSetInteger(0, objName, OBJPROP_YDISTANCE, y);
   ObjectSetString(0, objName, OBJPROP_TEXT, text); 
   ObjectSetString(0, objName, OBJPROP_FONT, fontFace);
   ObjectSetInteger(0, objName, OBJPROP_FONTSIZE, fontSize); 
   ObjectSetInteger(0, objName, OBJPROP_COLOR, fontClr);
   ObjectSetInteger(0, objName, OBJPROP_CORNER, CORNER_LEFT_UPPER); 
   ObjectSetInteger(0, objName, OBJPROP_SELECTABLE, false);
}

void InitializeDashboard() {
   int sx = 20, sy = 20;
   CreateDashboardRectangle("MainBg", sx, sy, 320, 280, clrPanelBg, clrBorder);
   CreateDashboardRectangle("HeaderBg", sx, sy, 320, 40, clrBorder, clrBorder);
   CreateDashboardText("Title", sx + 15, sy + 10, "QUANTUM AI ENGINE v8.60", 12, 
                       clrPanelBg, "Arial Black");
   
   CreateDashboardText("Lbl_Status", sx + 15, sy + 55, "System State:", 10, clrTextDim);
   CreateDashboardText("Val_Status", sx + 140, sy + 55, "SCANNING", 10, clrAccentHigh);
   
   CreateDashboardText("Lbl_Trend", sx + 15, sy + 80, "Macro Bias:", 10, clrTextDim);
   CreateDashboardText("Val_Trend", sx + 140, sy + 80, "BULLISH", 10, clrLime);
   
   CreateDashboardText("Lbl_OrderFlow", sx + 15, sy + 105, "Order Flow:", 10, clrTextDim);
   CreateDashboardText("Val_OrderFlow", sx + 140, sy + 105, "0.0%", 10, clrAccentHigh);
   
   CreateDashboardText("Lbl_Confidence", sx + 15, sy + 130, "AI Confidence:", 10, clrTextDim);
   CreateDashboardText("Val_Confidence", sx + 140, sy + 130, "0 / 100", 10, clrWhite);
   
   CreateDashboardText("Lbl_Spread", sx + 15, sy + 155, "Live Spread:", 10, clrTextDim);
   CreateDashboardText("Val_Spread", sx + 140, sy + 155, "0.0 pts", 10, clrWhite);
   
   CreateDashboardText("Lbl_RR", sx + 15, sy + 180, "Target R:R:", 10, clrTextDim);
   CreateDashboardText("Val_RR", sx + 140, sy + 180, 
                       DoubleToString(InpRiskRewardRatio, 1) + ":1", 10, clrAccentHigh);
   
   CreateDashboardText("Lbl_Position", sx + 15, sy + 205, "Position:", 10, clrTextDim);
   CreateDashboardText("Val_Position", sx + 140, sy + 205, "NONE", 10, clrWhite);
   
   CreateDashboardRectangle("SepLine", sx + 15, sy + 235, 290, 1, clrTextDim, clrTextDim);
   CreateDashboardText("Footer", sx + 45, sy + 245, 
                       "Institutional Grade Execution", 8, clrTextDim);
   ChartRedraw();
}

void UpdateDashboardMetrics(string status, string bias, color biasClr, 
                            double orderFlow, double confidence, double spread,
                            string positionInfo) {
   ObjectSetString(0, UI_PREFIX + "Val_Status", OBJPROP_TEXT, status);
   ObjectSetString(0, UI_PREFIX + "Val_Trend", OBJPROP_TEXT, bias);
   ObjectSetInteger(0, UI_PREFIX + "Val_Trend", OBJPROP_COLOR, biasClr);
   
   string flowTxt = DoubleToString(orderFlow, 1) + "%";
   color flowClr = (orderFlow >= 60) ? clrAccentHigh : 
                   (orderFlow <= 40) ? clrAccentWarn : clrWhite;
   ObjectSetString(0, UI_PREFIX + "Val_OrderFlow", OBJPROP_TEXT, flowTxt);
   ObjectSetInteger(0, UI_PREFIX + "Val_OrderFlow", OBJPROP_COLOR, flowClr);
   
   ObjectSetString(0, UI_PREFIX + "Val_Confidence", OBJPROP_TEXT, 
                   DoubleToString(confidence, 1) + " / 100");
   ObjectSetInteger(0, UI_PREFIX + "Val_Confidence", OBJPROP_COLOR, 
                    (confidence >= 80) ? clrLime : 
                    (confidence >= 65 ? clrYellow : clrWhite));
   
   ObjectSetString(0, UI_PREFIX + "Val_Spread", OBJPROP_TEXT, 
                   DoubleToString(spread, 1) + " pts");
   color spreadClr = (spread <= 30) ? clrLime : 
                     (spread <= 50) ? clrYellow : clrRed;
   ObjectSetInteger(0, UI_PREFIX + "Val_Spread", OBJPROP_COLOR, spreadClr);
   
   ObjectSetString(0, UI_PREFIX + "Val_Position", OBJPROP_TEXT, positionInfo);
   
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
   // Apply visual theme
   ApplyProfessionalTheme();
   InitializeDashboard();
   
   // Setup trade object
   g_Trade.SetExpertMagicNumber(InpMagicNumber);
   g_Trade.SetDeviationInPoints(15);
   g_Trade.SetTypeFilling(ORDER_FILLING_FOK);
   g_Trade.SetAsyncMode(false);
   g_Trade.LogLevel(LOG_LEVEL_ERRORS);
   
   // Initialize ATR indicator
   g_hATR = iATR(_Symbol, _Period, InpATRPeriod);
   if(g_hATR == INVALID_HANDLE) {
      Print("ERROR: Failed to create ATR indicator!");
      return INIT_FAILED;
   }
   
   // Wait for indicator data
   if(CopyBuffer(g_hATR, 0, 0, 1, g_HistoricalSpreads) <= 0) {
      Print("WARNING: ATR data not ready, waiting...");
   }
   
   // Initialize Kalman filters
   double startPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(startPrice == 0) {
      Print("ERROR: Cannot get symbol price!");
      return INIT_FAILED;
   }
   
   g_KFast.estimate = startPrice; 
   g_KFast.error_cov = 1.0; 
   g_KFast.process_noise = InpProcessNoise; 
   g_KFast.measure_noise = InpMeasureNoise;
   
   g_KSlow.estimate = startPrice; 
   g_KSlow.error_cov = 1.0; 
   g_KSlow.process_noise = InpProcessNoise * 0.05; 
   g_KSlow.measure_noise = InpMeasureNoise * 4.0;
   
   // Initialize arrays
   ArrayResize(g_HistoricalSpreads, 1000);
   ArrayInitialize(g_HistoricalSpreads, 0);
   
   ZeroMemory(g_LiquidityMap); 
   ZeroMemory(g_FVGMap);
   
   // Initialize strategy health
   for(int i=0; i<STRATEGY_COUNT; i++) {
      g_StrategyHealth[i].TotalTrades = 0; 
      g_StrategyHealth[i].Wins = 0; 
      g_StrategyHealth[i].NetProfit = 0.0;
      g_StrategyHealth[i].ProfitFactor = 1.5; 
      g_StrategyHealth[i].WinRate = 0.50; 
      g_StrategyHealth[i].IsDisabled = false;
      g_StrategyHealth[i].AllocationScale = 1.0;
   }
   
   // Initialize order flow
   g_CurrentOrderFlow.AggressionScore = 50.0;
   g_CurrentOrderFlow.BullishPressure = 0;
   g_CurrentOrderFlow.BearishPressure = 0;
   g_CurrentOrderFlow.Dominance = "NEUTRAL";
   
   g_LastTradeTime = 0;
   
   Print("=== QUANTUM PLUS ENGINE v8.60 INITIALIZED ===");
   Print("Symbol: ", _Symbol);
   Print("Magic Number: ", InpMagicNumber);
   Print("Risk per Trade: ", InpBaseRiskPercent, "%");
   Print("Target R:R: ", InpRiskRewardRatio, ":1");
   Print("SL ATR Multi: ", InpStopLossATRMulti);
   Print("TP ATR Multi: ", InpTakeProfitATRMulti);
   
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason) {
   if(g_hATR != INVALID_HANDLE) IndicatorRelease(g_hATR);
   RemoveUI();
   
   Print("=== QUANTUM PLUS ENGINE SHUTDOWN ===");
   Print("Reason: ", reason);
}

//+------------------------------------------------------------------+
//| SYSTEMATIC LOGIC MODULES                                         |
//+------------------------------------------------------------------+
bool ObserveMarket() {
   MqlTick tick;
   if(!SymbolInfoTick(_Symbol, tick)) {
      Print("ERROR: Failed to get tick data");
      return false;
   }
   
   // Store tick in buffer
   if(g_TickCount >= TICK_BUFFER_SIZE) {
      for(int i=0; i<TICK_BUFFER_SIZE-1; i++) 
         g_TickBuffer[i] = g_TickBuffer[i+1];
      g_TickBuffer[TICK_BUFFER_SIZE-1] = tick;
   } else {
      g_TickBuffer[g_TickCount] = tick; 
      g_TickCount++;
   }
   
   // Store spread history
   int totalSpreads = ArraySize(g_HistoricalSpreads);
   if(totalSpreads > 0) {
      for(int i=0; i<totalSpreads-1; i++) 
         g_HistoricalSpreads[i] = g_HistoricalSpreads[i+1];
      g_HistoricalSpreads[totalSpreads-1] = (tick.ask - tick.bid) / _Point;
   }
   
   // Update Kalman Fast
   g_KFast.error_cov += g_KFast.process_noise;
   g_KFast.gain = g_KFast.error_cov / (g_KFast.error_cov + g_KFast.measure_noise);
   g_KFast.estimate = g_KFast.estimate + g_KFast.gain * (tick.bid - g_KFast.estimate);
   g_KFast.error_cov = (1.0 - g_KFast.gain) * g_KFast.error_cov;
   
   // Update Kalman Slow
   g_KSlow.error_cov += g_KSlow.process_noise;
   g_KSlow.gain = g_KSlow.error_cov / (g_KSlow.error_cov + g_KSlow.measure_noise);
   g_KSlow.estimate = g_KSlow.estimate + g_KSlow.gain * (tick.bid - g_KSlow.estimate);
   g_KSlow.error_cov = (1.0 - g_KSlow.gain) * g_KSlow.error_cov;
   
   return (g_TickCount >= 10); // Need minimum data
}

MarketStateResult ClassifyMarketState() {
   MarketStateResult res; 
   res.State = STATE_UNDEFINED; 
   res.Confidence = 0.0;
   
   double fast = g_KFast.estimate; 
   double slow = g_KSlow.estimate;
   double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   
   // Get ATR
   double atr = 200 * _Point; 
   double atrBuf[1];
   if(CopyBuffer(g_hATR, 0, 0, 1, atrBuf) == 1) 
      atr = atrBuf[0];
   else {
      Print("WARNING: ATR data not available");
      return res;
   }
   
   double trendThreshold = (atr * 0.5 * InpStateSensitivity) / _Point; 
   double exhaustThreshold = (atr * 2.0 * InpStateSensitivity) / _Point;
   
   double devFastSlow = MathAbs(fast - slow) / _Point;
   double devPriceFast = (currentPrice - fast) / _Point;
   
   // Classification logic
   if(MathAbs(devPriceFast) > exhaustThreshold) {
      res.State = STATE_TREND_EXHAUSTION; 
      res.Confidence = 75.0;
   } 
   else if(devFastSlow > trendThreshold) {
      if((currentPrice > fast && fast > slow) || (currentPrice < fast && fast < slow))
         res.State = STATE_TREND_CONTINUATION;
      else
         res.State = STATE_TREND_EXPANSION;
      res.Confidence = 70.0;
   } 
   else {
      res.State = (fast > slow) ? STATE_RANGE_DISTRIBUTION : STATE_RANGE_ACCUMULATION;
      res.Confidence = 55.0;
   }
   
   return res;
}

void AnalyzeVolatility() {
   double atrBuf[1];
   double atr = 200 * _Point;
   
   if(CopyBuffer(g_hATR, 0, 0, 1, atrBuf) == 1) 
      atr = atrBuf[0];
   
   // Calculate tick velocity
   double tickVelocity = 0;
   if(g_TickCount >= 2) {
      tickVelocity = MathAbs(g_TickBuffer[g_TickCount-1].bid - 
                             g_TickBuffer[0].bid) / _Point;
   }
   
   // Composite volatility index
   g_VolCompositeIndex = (atr / _Point) * 0.7 + (tickVelocity * 2.0) * 0.3;
   
   // Classify volatility state
   if(g_VolCompositeIndex < 80.0) 
      g_CurrentVolState = VOL_SUPPRESSED;
   else if(g_VolCompositeIndex < 200.0) 
      g_CurrentVolState = VOL_NORMAL;
   else if(g_VolCompositeIndex < 400.0) 
      g_CurrentVolState = VOL_EXPANDING;
   else 
      g_CurrentVolState = VOL_EXTREME;
}

void AnalyzeMarketStructure() {
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   
   if(CopyRates(_Symbol, _Period, 0, 30, rates) < 30) {
      Print("WARNING: Insufficient bar data for structure analysis");
      g_CurrentStructure = STRUCTURE_RANGE;
      g_StructureStrength = 40.0;
      return;
   }
   
   // Find swing highs and lows
   double highestHigh = rates[0].high;
   double lowestLow = rates[0].low;
   
   for(int i=1; i<30; i++) {
      if(rates[i].high > highestHigh) highestHigh = rates[i].high;
      if(rates[i].low < lowestLow) lowestLow = rates[i].low;
   }
   
   double currentClose = rates[0].close;
   double range = highestHigh - lowestLow;
   double upperThird = highestHigh - (range * 0.25);
   double lowerThird = lowestLow + (range * 0.25);
   
   // Higher highs and higher lows check
   bool higherHighs = (rates[0].high > rates[10].high) && 
                      (rates[10].high > rates[20].high);
   bool higherLows = (rates[0].low > rates[10].low) && 
                     (rates[10].low > rates[20].low);
   bool lowerHighs = (rates[0].high < rates[10].high) && 
                     (rates[10].high < rates[20].high);
   bool lowerLows = (rates[0].low < rates[10].low) && 
                    (rates[10].low < rates[20].low);
   
   // Structure classification
   if((currentClose > upperThird) && (higherHighs || higherLows)) {
      g_CurrentStructure = STRUCTURE_BULL;
      g_StructureStrength = 80.0;
   }
   else if((currentClose < lowerThird) && (lowerHighs || lowerLows)) {
      g_CurrentStructure = STRUCTURE_BEAR;
      g_StructureStrength = 80.0;
   }
   else {
      g_CurrentStructure = STRUCTURE_RANGE;
      g_StructureStrength = 50.0;
   }
}

void EstimateOrderFlow() {
   if(g_TickCount < 5) {
      g_CurrentOrderFlow.AggressionScore = 50.0;
      g_CurrentOrderFlow.Dominance = "NEUTRAL";
      return;
   }
   
   double bidAggression = 0.0;
   double askAggression = 0.0;
   
   for(int i=1; i<g_TickCount; i++) {
      double priceDiff = g_TickBuffer[i].bid - g_TickBuffer[i-1].bid;
      double volumeWeight = (g_TickBuffer[i].volume > 0) ? 
                           (double)g_TickBuffer[i].volume : 1.0;
      
      if(priceDiff > 0) {
         bidAggression += (priceDiff / _Point) * volumeWeight;
      }
      else if(priceDiff < 0) {
         askAggression += (MathAbs(priceDiff) / _Point) * volumeWeight;
      }
   }
   
   double total = bidAggression + askAggression;
   if(total <= 0) total = 1.0;
   
   g_CurrentOrderFlow.BullishPressure = bidAggression;
   g_CurrentOrderFlow.BearishPressure = askAggression;
   g_CurrentOrderFlow.AggressionScore = NormalizeDouble((bidAggression / total) * 100.0, 2);
   
   if(g_CurrentOrderFlow.AggressionScore > 60)
      g_CurrentOrderFlow.Dominance = "BULLISH";
   else if(g_CurrentOrderFlow.AggressionScore < 40)
      g_CurrentOrderFlow.Dominance = "BEARISH";
   else
      g_CurrentOrderFlow.Dominance = "NEUTRAL";
}

double CalculateFusionScore() {
   // Weight distribution
   double structureWeight = 0.25;
   double volatilityWeight = 0.15;
   double orderFlowWeight = 0.35;
   double stateWeight = 0.25;
   
   // Normalize components
   double structureScore = g_StructureStrength;
   
   double volatilityScore = 0;
   switch(g_CurrentVolState) {
      case VOL_SUPPRESSED: volatilityScore = 30.0; break;
      case VOL_NORMAL: volatilityScore = 70.0; break;
      case VOL_EXPANDING: volatilityScore = 85.0; break;
      case VOL_EXTREME: volatilityScore = 50.0; break; // Too volatile
   }
   
   double orderFlowScore = g_CurrentOrderFlow.AggressionScore;
   if(orderFlowScore > 50) 
      orderFlowScore = ((orderFlowScore - 50) * 2); // Scale bullish
   else 
      orderFlowScore = ((50 - orderFlowScore) * 2); // Scale bearish
   
   double stateScore = g_CurrentState.Confidence;
   
   // Calculate weighted score
   double totalScore = (structureScore * structureWeight) +
                       (volatilityScore * volatilityWeight) +
                       (orderFlowScore * orderFlowWeight * InpMomentumBias) +
                       (stateScore * stateWeight);
   
   // Boost for strong alignment
   if((g_CurrentStructure == STRUCTURE_BULL && 
       g_CurrentOrderFlow.AggressionScore > 65) ||
      (g_CurrentStructure == STRUCTURE_BEAR && 
       g_CurrentOrderFlow.AggressionScore < 35)) {
      totalScore += 10.0;
   }
   
   return NormalizeDouble(MathMin(MathMax(totalScore, 0.0), 100.0), 2);
}

ENUM_STRATEGY_TYPE MetaRouter() {
   // Check minimum confidence
   if(g_FinalFusionScore < InpMinFusionScore) {
      g_UIStatus = "WAITING - LOW CONFIDENCE";
      return STRAT_STAND_ASIDE;
   }
   
   // Check volatility
   if(g_CurrentVolState == VOL_SUPPRESSED) {
      g_UIStatus = "WAITING - LOW VOLATILITY";
      return STRAT_STAND_ASIDE;
   }
   
   if(g_CurrentVolState == VOL_EXTREME) {
      g_UIStatus = "WAITING - EXTREME VOLATILITY";
      return STRAT_STAND_ASIDE;
   }
   
   // Check spread
   double currentSpread = (SymbolInfoDouble(_Symbol, SYMBOL_ASK) - 
                          SymbolInfoDouble(_Symbol, SYMBOL_BID)) / _Point;
   if(currentSpread > InpMaxSpreadPoints) {
      g_UIStatus = "WAITING - HIGH SPREAD";
      return STRAT_STAND_ASIDE;
   }
   
   // Check time filter
   if(InpMinBarsBetween > 0 && g_LastTradeTime > 0) {
      int barsSinceTrade = Bars(_Symbol, _Period, g_LastTradeTime, TimeCurrent());
      if(barsSinceTrade < InpMinBarsBetween) {
         g_UIStatus = "WAITING - COOLDOWN";
         return STRAT_STAND_ASIDE;
      }
   }
   
   // Only trade trends filter
   if(InpOnlyTradeTrends && g_CurrentStructure == STRUCTURE_RANGE) {
      g_UIStatus = "WAITING - RANGING MARKET";
      return STRAT_STAND_ASIDE;
   }
   
   // Route to strategy
   g_UIStatus = "SIGNAL CONFIRMED";
   
   if(g_CurrentState.State == STATE_TREND_EXPANSION || 
      g_CurrentState.State == STATE_TREND_CONTINUATION) {
      return STRAT_TREND_CONTINUATION;
   }
   
   if(g_CurrentVolState == VOL_EXPANDING) {
      return STRAT_VOLATILITY_BREAKOUT;
   }
   
   return STRAT_TREND_CONTINUATION;
}

//+------------------------------------------------------------------+
//| Calculate Stop Loss and Take Profit                              |
//+------------------------------------------------------------------+
bool CalculateSLTP(ENUM_SIGNAL signal, double entryPrice, 
                   double &slPrice, double &tpPrice, double &riskPoints) {
   
   // Get ATR
   double atrBuf[1];
   double atr = 200 * _Point;
   if(CopyBuffer(g_hATR, 0, 0, 1, atrBuf) == 1) 
      atr = atrBuf[0];
   
   // Calculate SL in points
   double slPoints = (atr * InpStopLossATRMulti) / _Point;
   
   // Apply min/max limits
   slPoints = MathMax(slPoints, InpMinStopLossPoints);
   slPoints = MathMin(slPoints, InpMaxStopLossPoints);
   
   // Calculate TP based on R:R
   double tpPoints = slPoints * InpRiskRewardRatio;
   
   // Calculate actual prices
   if(signal == SIGNAL_BUY) {
      slPrice = NormalizeDouble(entryPrice - (slPoints * _Point), _Digits);
      tpPrice = NormalizeDouble(entryPrice + (tpPoints * _Point), _Digits);
   }
   else if(signal == SIGNAL_SELL) {
      slPrice = NormalizeDouble(entryPrice + (slPoints * _Point), _Digits);
      tpPrice = NormalizeDouble(entryPrice - (tpPoints * _Point), _Digits);
   }
   else {
      return false;
   }
   
   riskPoints = slPoints;
   
   // Validate levels
   double minStopLevel = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL) * _Point;
   double slDistance = MathAbs(entryPrice - slPrice);
   double tpDistance = MathAbs(entryPrice - tpPrice);
   
   if(slDistance < minStopLevel || tpDistance < minStopLevel) {
      Print("ERROR: SL/TP too close to entry. Min distance: ", minStopLevel/_Point, " points");
      return false;
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| Calculate Position Size Based on Risk                            |
//+------------------------------------------------------------------+
double AllocateRisk(ENUM_STRATEGY_TYPE strategy, double slPoints) {
   
   if(slPoints <= 0) {
      Print("ERROR: Invalid SL points for position sizing");
      return 0;
   }
   
   // Get account equity
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   if(equity <= 0) {
      Print("ERROR: Invalid account equity");
      return 0;
   }
   
   // Check drawdown limit
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double currentDrawdown = 0;
   if(balance > equity) {
      currentDrawdown = ((balance - equity) / balance) * 100.0;
   }
   
   if(currentDrawdown >= InpMaxDrawdownLimit) {
      Print("WARNING: Maximum drawdown limit reached: ", 
            DoubleToString(currentDrawdown, 2), "%");
      return 0;
   }
   
   // Adjust risk based on confidence
   double confidenceMultiplier = (g_FinalFusionScore - 50.0) / 50.0; // 0 to 1
   confidenceMultiplier = MathMax(0.5, MathMin(1.2, confidenceMultiplier));
   
   // Calculate risk amount
   double riskPercent = InpBaseRiskPercent * confidenceMultiplier;
   riskPercent = MathMin(riskPercent, InpBaseRiskPercent * 1.5); // Cap at 150%
   
   double riskAmount = equity * (riskPercent / 100.0);
   
   // Get tick value
   double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   
   if(tickSize <= 0 || tickValue <= 0) {
      Print("ERROR: Invalid tick size or tick value");
      return 0;
   }
   
   // Calculate lot size
   double lotSize = riskAmount / (slPoints * ((tickValue / tickSize) * _Point));
   
   // Normalize to lot step
   double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   
   if(lotStep > 0) {
      lotSize = MathFloor(lotSize / lotStep) * lotStep;
   }
   
   lotSize = MathMax(minLot, lotSize);
   lotSize = MathMin(maxLot, lotSize);
   
   lotSize = NormalizeDouble(lotSize, 2);
   
   Print("Position Sizing - Risk: ", DoubleToString(riskPercent, 2), 
         "% | Amount: $", DoubleToString(riskAmount, 2),
         " | SL Points: ", DoubleToString(slPoints, 0),
         " | Lot Size: ", DoubleToString(lotSize, 2));
   
   return lotSize;
}

//+------------------------------------------------------------------+
//| Check if position is open                                        |
//+------------------------------------------------------------------+
bool IsPositionOpen() {
   for(int i = PositionsTotal()-1; i >= 0; i--) {
      if(g_Pos.SelectByIndex(i)) {
         if(g_Pos.Magic() == InpMagicNumber && g_Pos.Symbol() == _Symbol) {
            g_CurrentTicket = g_Pos.Ticket();
            return true;
         }
      }
   }
   g_CurrentTicket = 0;
   return false;
}

//+------------------------------------------------------------------+
//| Execute Trade                                                     |
//+------------------------------------------------------------------+
void ExecuteRoutedStrategy(ENUM_STRATEGY_TYPE strategy, double lotSize) {
   
   // Determine signal
   ENUM_SIGNAL entrySignal = SIGNAL_NONE;
   
   if(g_CurrentStructure == STRUCTURE_BULL && 
      g_CurrentOrderFlow.AggressionScore > 55.0) {
      entrySignal = SIGNAL_BUY;
   }
   else if(g_CurrentStructure == STRUCTURE_BEAR && 
           g_CurrentOrderFlow.AggressionScore < 45.0) {
      entrySignal = SIGNAL_SELL;
   }
   
   // Additional confirmation for ranging markets
   if(g_CurrentStructure == STRUCTURE_RANGE) {
      if(g_CurrentOrderFlow.AggressionScore > 65.0)
         entrySignal = SIGNAL_BUY;
      else if(g_CurrentOrderFlow.AggressionScore < 35.0)
         entrySignal = SIGNAL_SELL;
   }
   
   if(entrySignal == SIGNAL_NONE) {
      Print("No clear signal - skipping trade");
      return;
   }
   
   // Get entry price
   double entryPrice = (entrySignal == SIGNAL_BUY) ? 
                       SymbolInfoDouble(_Symbol, SYMBOL_ASK) : 
                       SymbolInfoDouble(_Symbol, SYMBOL_BID);
   
   if(entryPrice == 0) {
      Print("ERROR: Invalid entry price");
      return;
   }
   
   // Calculate SL and TP
   double slPrice = 0, tpPrice = 0, riskPoints = 0;
   if(!CalculateSLTP(entrySignal, entryPrice, slPrice, tpPrice, riskPoints)) {
      Print("ERROR: Failed to calculate SL/TP");
      return;
   }
   
   // Recalculate lot size with actual SL
   lotSize = AllocateRisk(strategy, riskPoints);
   
   if(lotSize <= 0) {
      Print("ERROR: Invalid lot size calculated");
      return;
   }
   
   // Store initial risk for trailing
   g_InitialRiskPoints = riskPoints;
   
   // Prepare order
   MqlTradeRequest req;
   MqlTradeResult res;
   ZeroMemory(req);
   ZeroMemory(res);
   
   req.action = TRADE_ACTION_DEAL;
   req.symbol = _Symbol;
   req.volume = lotSize;
   req.type = (entrySignal == SIGNAL_BUY) ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
   req.price = NormalizeDouble(entryPrice, _Digits);
   req.sl = slPrice;
   req.tp = tpPrice;
   req.deviation = 15;
   req.magic = InpMagicNumber;
   req.comment = InpTradeComment;
   req.type_filling = ORDER_FILLING_FOK;
   
   // Send order
   if(!OrderSend(req, res)) {
      Print("ERROR: OrderSend failed. Error: ", GetLastError());
      Print("RetCode: ", res.retcode, " | ", res.comment);
      return;
   }
   
   if(res.retcode == TRADE_RETCODE_DONE || res.retcode == TRADE_RETCODE_PLACED) {
      g_LastTradeTime = TimeCurrent();
      g_CurrentTicket = res.order;
      
      Print("=== TRADE EXECUTED ===");
      Print("Signal: ", (entrySignal == SIGNAL_BUY) ? "BUY" : "SELL");
      Print("Strategy: ", EnumToString(strategy));
      Print("Entry: ", DoubleToString(entryPrice, _Digits));
      Print("SL: ", DoubleToString(slPrice, _Digits), " (", 
            DoubleToString(riskPoints, 0), " pts)");
      Print("TP: ", DoubleToString(tpPrice, _Digits), " (", 
            DoubleToString(riskPoints * InpRiskRewardRatio, 0), " pts)");
      Print("Lot Size: ", DoubleToString(lotSize, 2));
      Print("Risk:Reward = 1:", DoubleToString(InpRiskRewardRatio, 1));
      Print("Confidence: ", DoubleToString(g_FinalFusionScore, 1), "%");
   }
   else {
      Print("ERROR: Order failed. RetCode: ", res.retcode, " | ", res.comment);
   }
}

//+------------------------------------------------------------------+
//| Manage Open Position (Trailing Stop, Break-even)                |
//+------------------------------------------------------------------+
void ManageLifecycle() {
   
   if(g_CurrentTicket == 0 || !PositionSelectByTicket(g_CurrentTicket)) 
      return;
   
   if(!g_Pos.SelectByTicket(g_CurrentTicket))
      return;
   
   double entry = g_Pos.PriceOpen();
   double currentSL = g_Pos.StopLoss();
   double currentTP = g_Pos.TakeProfit();
   bool isBuy = (g_Pos.PositionType() == POSITION_TYPE_BUY);
   
   double currentPrice = isBuy ? SymbolInfoDouble(_Symbol, SYMBOL_BID) : 
                                 SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   
   if(g_InitialRiskPoints <= 0) {
      g_InitialRiskPoints = MathAbs(entry - currentSL) / _Point;
   }
   
   if(g_InitialRiskPoints <= 0) return;
   
   // Calculate current profit in R multiples
   double currentProfit = isBuy ? (currentPrice - entry) : (entry - currentPrice);
   double currentRMultiple = currentProfit / (g_InitialRiskPoints * _Point);
   
   double newSL = currentSL;
   bool shouldModify = false;
   
   // Move to break-even
   if(InpBreakEvenRR > 0 && currentRMultiple >= InpBreakEvenRR) {
      double breakEvenSL = isBuy ? (entry + (5 * _Point)) : (entry - (5 * _Point));
      if((isBuy && breakEvenSL > currentSL) || 
         (!isBuy && (breakEvenSL < currentSL || currentSL == 0))) {
         newSL = breakEvenSL;
         shouldModify = true;
         Print("Moving to break-even at R=", DoubleToString(currentRMultiple, 2));
      }
   }
   
   // Trailing stop
   if(InpUseTrailingStop && InpTrailStartRR > 0 && 
      currentRMultiple >= InpTrailStartRR) {
      
      double trailDistance = g_InitialRiskPoints * InpTrailStepRR * _Point;
      double trailSL = isBuy ? (currentPrice - trailDistance) : 
                               (currentPrice + trailDistance);
      
      trailSL = NormalizeDouble(trailSL, _Digits);
      
      if((isBuy && trailSL > currentSL) || 
         (!isBuy && (trailSL < currentSL || currentSL == 0))) {
         newSL = trailSL;
         shouldModify = true;
         Print("Trailing stop to ", DoubleToString(newSL, _Digits), 
               " at R=", DoubleToString(currentRMultiple, 2));
      }
   }
   
   // Execute modification
   if(shouldModify && newSL != currentSL) {
      if(!g_Trade.PositionModify(g_CurrentTicket, 
                                  NormalizeDouble(newSL, _Digits), 
                                  currentTP)) {
         Print("ERROR: Failed to modify position. Error: ", GetLastError());
      }
   }
   
   // Update UI
   g_UIStatus = StringFormat("ACTIVE | P/L: %.1fR", currentRMultiple);
}

//+------------------------------------------------------------------+
//| Get Position Info String                                         |
//+------------------------------------------------------------------+
string GetPositionInfoString() {
   if(g_CurrentTicket == 0) return "NONE";
   
   if(!g_Pos.SelectByTicket(g_CurrentTicket)) return "NONE";
   
   bool isBuy = (g_Pos.PositionType() == POSITION_TYPE_BUY);
   double profit = g_Pos.Profit();
   
   string direction = isBuy ? "BUY" : "SELL";
   string profitStr = (profit >= 0) ? "+" : "";
   profitStr += DoubleToString(profit, 2);
   
   return direction + " | " + profitStr;
}

//+------------------------------------------------------------------+
//| ON TICK CORE PIPELINE                                            |
//+------------------------------------------------------------------+
void OnTick() {
   
   // Observe market
   if(!ObserveMarket()) return;
   
   // Analyze market
   g_CurrentState = ClassifyMarketState();
   AnalyzeVolatility();
   AnalyzeMarketStructure();
   EstimateOrderFlow();
   
   // Calculate fusion score
   g_FinalFusionScore = CalculateFusionScore();
   
   // Manage existing position
   if(IsPositionOpen()) {
      ManageLifecycle();
   }
   else {
      // Look for new trade
      ENUM_STRATEGY_TYPE chosenStrategy = MetaRouter();
      
      if(chosenStrategy != STRAT_STAND_ASIDE) {
         ExecuteRoutedStrategy(chosenStrategy, 0); // Lot size calculated inside
      }
   }
   
   // Update UI
   double liveSpread = (SymbolInfoDouble(_Symbol, SYMBOL_ASK) - 
                        SymbolInfoDouble(_Symbol, SYMBOL_BID)) / _Point;
   
   string macroStatus = "RANGING";
   color macroClr = clrWhite;
   
   if(g_CurrentStructure == STRUCTURE_BULL) {
      macroStatus = "BULLISH";
      macroClr = clrLime;
   }
   else if(g_CurrentStructure == STRUCTURE_BEAR) {
      macroStatus = "BEARISH";
      macroClr = clrAccentWarn;
   }
   
   string posInfo = GetPositionInfoString();
   
   UpdateDashboardMetrics(
      g_UIStatus, 
      macroStatus, 
      macroClr, 
      g_CurrentOrderFlow.AggressionScore, 
      g_FinalFusionScore, 
      liveSpread,
      posInfo
   );
}