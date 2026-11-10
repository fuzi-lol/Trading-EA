//+------------------------------------------------------------------+
//|                                     THEE Quantum Plus Engine.mq5 |
//|                                  Copyright 2026, FXBotHub Systems|
//|                                             https://fxbothub.com |
//+------------------------------------------------------------------+
#property copyright   "Copyright 2026, FXBotHub Systems"
#property link        "https://fxbothub.com"
#property version     "8.60"
#property description "Institutional Multi-Layer Quantitative XAUUSD Trading System - ENHANCED"
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
input double  InpMinFusionScore      = 65.0;   // Minimum AI confidence to trade
input double  InpMaxSpreadPoints     = 50.0;   // Maximum spread in points
input int     InpMaxExecutionLatency = 200;    
input double  InpStateSensitivity    = 1.0;    // Multiplier for state classification
input double  InpMomentumBias        = 1.2;    // Extra weight to order flow

input group "=== 5. RISK MANAGEMENT (ENHANCED) ==="
input double  InpBaseRiskPercent   = 1.0;      // Risk per trade (% of equity)
input double  InpMaxDrawdownLimit  = 10.0;     // Maximum drawdown before stopping
input double  InpMinRiskReward     = 1.5;      // Minimum risk:reward ratio
input double  InpMaxRiskReward     = 3.5;      // Maximum risk:reward ratio
input double  InpSLMultiplierATR   = 1.8;      // SL = ATR × this multiplier
input double  InpMinSLPoints       = 100.0;    // Minimum SL in points
input double  InpMaxSLPoints       = 500.0;    // Maximum SL in points
input bool    InpUseBreakeven      = true;     // Move SL to breakeven
input double  InpBreakevenTrigger  = 1.2;      // Trigger BE at profit = risk × this
input bool    InpUseTrailingStop   = true;     // Enable trailing stop
input double  InpTrailTrigger      = 1.5;      // Start trailing at profit = risk × this
input double  InpTrailDistance     = 0.5;      // Trail distance = risk × this

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

// Enhanced tracking
double                g_InitialBalance      = 0.0;
double                g_PeakBalance         = 0.0;
double                g_CurrentDrawdown     = 0.0;
bool                  g_TradingEnabled      = true;
datetime              g_LastTradeTime       = 0;
int                   g_MinBarsBetweenTrades = 5;

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

void CreateDashboardText(string name, int x, int y, string text, int fontSize, color fontClr, string fontFace="Trebuchet MS") {
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
   CreateDashboardRectangle("MainBg", sx, sy, 300, 280, clrPanelBg, clrBorder);
   CreateDashboardRectangle("HeaderBg", sx, sy, 300, 40, clrBorder, clrBorder);
   CreateDashboardText("Title", sx + 15, sy + 10, "QUANTUM AI ENGINE v8.6", 11, clrPanelBg, "Arial Black");
   
   CreateDashboardText("Lbl_Status", sx + 15, sy + 55, "System State:", 9, clrTextDim);
   CreateDashboardText("Val_Status", sx + 120, sy + 55, "SCANNING", 9, clrAccentHigh);
   
   CreateDashboardText("Lbl_Trend", sx + 15, sy + 75, "Macro Bias:", 9, clrTextDim);
   CreateDashboardText("Val_Trend", sx + 120, sy + 75, "BULLISH", 9, clrLime);
   
   CreateDashboardText("Lbl_OrderFlow", sx + 15, sy + 95, "Order Flow:", 9, clrTextDim);
   CreateDashboardText("Val_OrderFlow", sx + 120, sy + 95, "0.0%", 9, clrAccentHigh);
   
   CreateDashboardText("Lbl_Confidence", sx + 15, sy + 115, "AI Confidence:", 9, clrTextDim);
   CreateDashboardText("Val_Confidence", sx + 120, sy + 115, "0 / 100", 9, clrWhite);
   
   CreateDashboardText("Lbl_Spread", sx + 15, sy + 135, "Live Spread:", 9, clrTextDim);
   CreateDashboardText("Val_Spread", sx + 120, sy + 135, "0.0 pts", 9, clrWhite);
   
   CreateDashboardText("Lbl_RR", sx + 15, sy + 155, "Risk:Reward:", 9, clrTextDim);
   CreateDashboardText("Val_RR", sx + 120, sy + 155, "1:0.0", 9, clrWhite);
   
   CreateDashboardText("Lbl_DD", sx + 15, sy + 175, "Drawdown:", 9, clrTextDim);
   CreateDashboardText("Val_DD", sx + 120, sy + 175, "0.0%", 9, clrWhite);
   
   CreateDashboardText("Lbl_Trading", sx + 15, sy + 195, "Trading Status:", 9, clrTextDim);
   CreateDashboardText("Val_Trading", sx + 120, sy + 195, "ENABLED", 9, clrLime);
   
   CreateDashboardRectangle("SepLine", sx + 15, sy + 220, 270, 1, clrTextDim, clrTextDim);
   CreateDashboardText("Footer", sx + 50, sy + 235, "Institutional Grade Execution", 8, clrTextDim);
   CreateDashboardText("Footer2", sx + 75, sy + 255, "Enhanced Risk Control", 8, clrAccentHigh);
   ChartRedraw();
}

void UpdateDashboardMetrics(string status, string bias, color biasClr, double orderFlow, double confidence, 
                            double spread, double rrRatio, double drawdown, bool tradingEnabled) {
   ObjectSetString(0, UI_PREFIX + "Val_Status", OBJPROP_TEXT, status);
   ObjectSetString(0, UI_PREFIX + "Val_Trend", OBJPROP_TEXT, bias);
   ObjectSetInteger(0, UI_PREFIX + "Val_Trend", OBJPROP_COLOR, biasClr);
   
   string flowTxt = DoubleToString(orderFlow, 1) + "%";
   color flowClr = (orderFlow >= 50) ? clrAccentHigh : clrAccentWarn;
   ObjectSetString(0, UI_PREFIX + "Val_OrderFlow", OBJPROP_TEXT, flowTxt);
   ObjectSetInteger(0, UI_PREFIX + "Val_OrderFlow", OBJPROP_COLOR, flowClr);
   
   ObjectSetString(0, UI_PREFIX + "Val_Confidence", OBJPROP_TEXT, DoubleToString(confidence, 1) + " / 100");
   ObjectSetInteger(0, UI_PREFIX + "Val_Confidence", OBJPROP_COLOR, 
                    (confidence >= 80) ? clrLime : (confidence >= 65 ? clrYellow : clrOrange));
   
   ObjectSetString(0, UI_PREFIX + "Val_Spread", OBJPROP_TEXT, DoubleToString(spread, 1) + " pts");
   color spreadClr = (spread <= InpMaxSpreadPoints * 0.5) ? clrLime : 
                     (spread <= InpMaxSpreadPoints) ? clrYellow : clrRed;
   ObjectSetInteger(0, UI_PREFIX + "Val_Spread", OBJPROP_COLOR, spreadClr);
   
   ObjectSetString(0, UI_PREFIX + "Val_RR", OBJPROP_TEXT, "1:" + DoubleToString(rrRatio, 1));
   color rrClr = (rrRatio >= InpMinRiskReward) ? clrLime : clrOrange;
   ObjectSetInteger(0, UI_PREFIX + "Val_RR", OBJPROP_COLOR, rrClr);
   
   ObjectSetString(0, UI_PREFIX + "Val_DD", OBJPROP_TEXT, DoubleToString(drawdown, 2) + "%");
   color ddClr = (drawdown < 3.0) ? clrLime : (drawdown < 6.0 ? clrYellow : clrRed);
   ObjectSetInteger(0, UI_PREFIX + "Val_DD", OBJPROP_COLOR, ddClr);
   
   ObjectSetString(0, UI_PREFIX + "Val_Trading", OBJPROP_TEXT, tradingEnabled ? "ENABLED" : "DISABLED");
   ObjectSetInteger(0, UI_PREFIX + "Val_Trading", OBJPROP_COLOR, tradingEnabled ? clrLime : clrRed);
   
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
   g_Trade.SetAsyncMode(false);
   
   g_hATR = iATR(_Symbol, _Period, InpATRPeriod);
   if(g_hATR == INVALID_HANDLE) {
      Print("ERROR: Failed to create ATR indicator");
      return INIT_FAILED;
   }
   
   double startPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   g_KFast.estimate = startPrice; 
   g_KFast.error_cov = 1.0; 
   g_KFast.process_noise = InpProcessNoise; 
   g_KFast.measure_noise = InpMeasureNoise;
   
   g_KSlow.estimate = startPrice; 
   g_KSlow.error_cov = 1.0; 
   g_KSlow.process_noise = InpProcessNoise * 0.05; 
   g_KSlow.measure_noise = InpMeasureNoise * 4.0;
   
   ArrayResize(g_HistoricalSpreads, 1000);
   ArrayInitialize(g_HistoricalSpreads, 0);
   
   ZeroMemory(g_LiquidityMap); 
   ZeroMemory(g_FVGMap);
   
   for(int i=0; i<STRATEGY_COUNT; i++) {
      g_StrategyHealth[i].TotalTrades = 0; 
      g_StrategyHealth[i].Wins = 0; 
      g_StrategyHealth[i].NetProfit = 0.0;
      g_StrategyHealth[i].ProfitFactor = 1.5; 
      g_StrategyHealth[i].WinRate = 0.50; 
      g_StrategyHealth[i].IsDisabled = false;
      g_StrategyHealth[i].AllocationScale = 1.0;
   }
   
   g_InitialBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   g_PeakBalance = g_InitialBalance;
   g_TradingEnabled = true;
   
   Print("Quantum Plus Engine v8.6 - Initialized Successfully");
   Print("Initial Balance: ", g_InitialBalance);
   Print("Risk per trade: ", InpBaseRiskPercent, "%");
   Print("Min R:R Ratio: 1:", InpMinRiskReward);
   
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason) {
   if(g_hATR != INVALID_HANDLE) IndicatorRelease(g_hATR);
   RemoveUI();
   Print("Quantum Plus Engine v8.6 - Deinitialized. Reason: ", reason);
}

//+------------------------------------------------------------------+
//| RISK MANAGEMENT FUNCTIONS                                        |
//+------------------------------------------------------------------+
void UpdateDrawdownMetrics() {
   double currentBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   
   if(currentBalance > g_PeakBalance) {
      g_PeakBalance = currentBalance;
   }
   
   if(g_PeakBalance > 0) {
      g_CurrentDrawdown = ((g_PeakBalance - currentBalance) / g_PeakBalance) * 100.0;
   }
   
   // Disable trading if max drawdown exceeded
   if(g_CurrentDrawdown >= InpMaxDrawdownLimit) {
      g_TradingEnabled = false;
      g_UIStatus = "TRADING HALTED - MAX DD REACHED";
      Print("WARNING: Maximum drawdown limit reached! Trading disabled.");
   }
}

bool ValidateSpread() {
   MqlTick tick;
   if(!SymbolInfoTick(_Symbol, tick)) return false;
   
   double spreadPoints = (tick.ask - tick.bid) / _Point;
   
   if(spreadPoints > InpMaxSpreadPoints) {
      g_UIStatus = "WAITING - SPREAD TOO WIDE";
      return false;
   }
   
   return true;
}

bool ValidateMinTimeBetweenTrades() {
   if(g_LastTradeTime == 0) return true;
   
   datetime currentBarTime = iTime(_Symbol, _Period, 0);
   int barsSinceLastTrade = Bars(_Symbol, _Period, g_LastTradeTime, currentBarTime);
   
   if(barsSinceLastTrade < g_MinBarsBetweenTrades) {
      g_UIStatus = "WAITING - COOLDOWN PERIOD";
      return false;
   }
   
   return true;
}

double CalculateOptimalSL(double entryPrice, bool isBuy, double atr) {
   // Calculate SL based on ATR with limits
   double slDistance = MathMax(InpMinSLPoints, MathMin(InpMaxSLPoints, (atr / _Point) * InpSLMultiplierATR));
   
   double slPrice;
   if(isBuy) {
      slPrice = entryPrice - (slDistance * _Point);
   } else {
      slPrice = entryPrice + (slDistance * _Point);
   }
   
   // Validate against SYMBOL_TRADE_STOPS_LEVEL
   int stopsLevel = (int)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   double minDistance = stopsLevel * _Point;
   
   if(isBuy && (entryPrice - slPrice) < minDistance) {
      slPrice = entryPrice - minDistance;
   } else if(!isBuy && (slPrice - entryPrice) < minDistance) {
      slPrice = entryPrice + minDistance;
   }
   
   return NormalizeDouble(slPrice, _Digits);
}

double CalculateOptimalTP(double entryPrice, double slPrice, bool isBuy, double &rrRatio) {
   double slDistance = MathAbs(entryPrice - slPrice);
   
   // Dynamic R:R based on market conditions
   double dynamicRR = InpMinRiskReward;
   
   // Increase R:R in trending markets
   if(g_CurrentState.State == STATE_TREND_EXPANSION || 
      g_CurrentState.State == STATE_TREND_CONTINUATION) {
      dynamicRR = MathMin(InpMaxRiskReward, InpMinRiskReward * 1.5);
   }
   
   // Adjust based on volatility
   if(g_CurrentVolState == VOL_EXPANDING || g_CurrentVolState == VOL_EXTREME) {
      dynamicRR = MathMin(InpMaxRiskReward, dynamicRR * 1.3);
   }
   
   // Adjust based on confidence
   if(g_FinalFusionScore >= 85.0) {
      dynamicRR = MathMin(InpMaxRiskReward, dynamicRR * 1.2);
   }
   
   rrRatio = dynamicRR;
   
   double tpDistance = slDistance * dynamicRR;
   double tpPrice;
   
   if(isBuy) {
      tpPrice = entryPrice + tpDistance;
   } else {
      tpPrice = entryPrice - tpDistance;
   }
   
   return NormalizeDouble(tpPrice, _Digits);
}

bool ValidatePriceLevels(double entryPrice, double slPrice, double tpPrice, bool isBuy) {
   // Basic sanity checks
   if(entryPrice <= 0 || slPrice <= 0 || tpPrice <= 0) {
      Print("ERROR: Invalid price levels - zero or negative");
      return false;
   }
   
   // Check logical order
   if(isBuy) {
      if(slPrice >= entryPrice) {
         Print("ERROR: BUY - SL must be below entry");
         return false;
      }
      if(tpPrice <= entryPrice) {
         Print("ERROR: BUY - TP must be above entry");
         return false;
      }
   } else {
      if(slPrice <= entryPrice) {
         Print("ERROR: SELL - SL must be above entry");
         return false;
      }
      if(tpPrice >= entryPrice) {
         Print("ERROR: SELL - TP must be below entry");
         return false;
      }
   }
   
   // Check minimum distance
   int stopsLevel = (int)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   double minDistance = stopsLevel * _Point;
   
   if(MathAbs(entryPrice - slPrice) < minDistance || 
      MathAbs(entryPrice - tpPrice) < minDistance) {
      Print("ERROR: SL/TP too close to entry price. Min distance: ", minDistance);
      return false;
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| SYSTEMATIC LOGIC MODULES                                         |
//+------------------------------------------------------------------+
bool ObserveMarket() {
   MqlTick tick;
   if(!SymbolInfoTick(_Symbol, tick)) {
      Print("ERROR: Failed to get current tick");
      return false;
   }
   
   // Update tick buffer
   if(g_TickCount >= TICK_BUFFER_SIZE) {
      for(int i=0; i<TICK_BUFFER_SIZE-1; i++) 
         g_TickBuffer[i] = g_TickBuffer[i+1];
      g_TickBuffer[TICK_BUFFER_SIZE-1] = tick;
   } else {
      g_TickBuffer[g_TickCount] = tick; 
      g_TickCount++;
   }
   
   // Update spread history
   int totalSpreads = ArraySize(g_HistoricalSpreads);
   if(totalSpreads > 0) {
      for(int i=0; i<totalSpreads-1; i++) 
         g_HistoricalSpreads[i] = g_HistoricalSpreads[i+1];
      g_HistoricalSpreads[totalSpreads-1] = (tick.ask - tick.bid) / _Point;
   }
   
   // Update Kalman filters
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
   MarketStateResult res; 
   res.State = STATE_UNDEFINED; 
   res.Confidence = 0.0;
   
   double fast = g_KFast.estimate; 
   double slow = g_KSlow.estimate;
   double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   
   double atr = 200 * _Point;
   double atrBuf[1];
   if(CopyBuffer(g_hATR, 0, 0, 1, atrBuf) == 1) {
      atr = atrBuf[0];
   }
   
   double trendThreshold = (atr * 0.8 * InpStateSensitivity) / _Point; 
   double exhaustThreshold = (atr * 1.5 * InpStateSensitivity) / _Point;
   
   double devFastSlow = MathAbs(fast - slow) / _Point;
   double devPriceFast = (currentPrice - fast) / _Point;
   
   double trendScore = (devFastSlow > trendThreshold) ? 60.0 : 0.0;
   double exhaustScore = (MathAbs(devPriceFast) > exhaustThreshold) ? 70.0 : 0.0;
   double rangeScore = (devFastSlow <= trendThreshold) ? 50.0 : 0.0;
   
   if(exhaustScore > trendScore && exhaustScore > rangeScore) {
      res.State = STATE_TREND_EXHAUSTION; 
      res.Confidence = exhaustScore;
   } else if(trendScore > rangeScore) {
      res.State = ((currentPrice - fast) * (fast - slow) > 0) ? 
                  STATE_TREND_EXPANSION : STATE_TREND_CONTINUATION;
      res.Confidence = trendScore;
   } else {
      res.State = (fast > slow) ? STATE_RANGE_DISTRIBUTION : STATE_RANGE_ACCUMULATION;
      res.Confidence = rangeScore;
   }
   
   return res;
}

void AnalyzeVolatility() {
   double atr = 200 * _Point;
   double atrBuf[1];
   if(CopyBuffer(g_hATR, 0, 0, 1, atrBuf) == 1) {
      atr = atrBuf[0];
   }
   
   double tickVelocity = 0;
   if(g_TickCount > 1) {
      tickVelocity = MathAbs(g_TickBuffer[g_TickCount-1].bid - g_TickBuffer[0].bid) / _Point;
   }
   
   g_VolCompositeIndex = (atr / _Point) * 0.6 + (tickVelocity * 4.0) * 0.4;
   
   if(g_VolCompositeIndex < 50.0) {
      g_CurrentVolState = VOL_SUPPRESSED;
   } else if(g_VolCompositeIndex < 150.0) {
      g_CurrentVolState = VOL_NORMAL;
   } else if(g_VolCompositeIndex < 350.0) {
      g_CurrentVolState = VOL_EXPANDING;
   } else {
      g_CurrentVolState = VOL_EXTREME;
   }
}

void AnalyzeMarketStructure() {
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   
   if(CopyRates(_Symbol, _Period, 0, 20, rates) < 20) {
      Print("ERROR: Failed to copy rates for structure analysis");
      return;
   }
   
   double highestHigh = -1.0; 
   double lowestLow = DBL_MAX;
   
   for(int i=0; i<20; i++) {
      if(rates[i].high > highestHigh) highestHigh = rates[i].high;
      if(rates[i].low < lowestLow) lowestLow = rates[i].low;
   }
   
   double currentClose = rates[0].close;
   double range = highestHigh - lowestLow;
   double upperThird = highestHigh - (range * 0.25);
   double lowerThird = lowestLow + (range * 0.25);
   
   if(currentClose > upperThird) {
      g_CurrentStructure = STRUCTURE_BULL;
      g_StructureStrength = 75.0 + ((currentClose - upperThird) / (highestHigh - upperThird)) * 25.0;
   } else if(currentClose < lowerThird) {
      g_CurrentStructure = STRUCTURE_BEAR;
      g_StructureStrength = 75.0 + ((lowerThird - currentClose) / (lowerThird - lowestLow)) * 25.0;
   } else {
      g_CurrentStructure = STRUCTURE_RANGE;
      g_StructureStrength = 50.0;
   }
}

void EstimateOrderFlow() {
   double bidAggression = 0.0; 
   double askAggression = 0.0;
   
   for(int i=1; i<g_TickCount; i++) {
      double diff = g_TickBuffer[i].bid - g_TickBuffer[i-1].bid;
      long size = g_TickBuffer[i].volume > 0 ? g_TickBuffer[i].volume : 1;
      
      if(diff > 0) {
         bidAggression += (diff / _Point) * (double)size;
      } else if(diff < 0) {
         askAggression += (MathAbs(diff) / _Point) * (double)size;
      }
   }
   
   double total = bidAggression + askAggression; 
   if(total <= 0) total = 1.0;
   
   g_CurrentOrderFlow.BullishPressure = bidAggression;
   g_CurrentOrderFlow.BearishPressure = askAggression;
   g_CurrentOrderFlow.AggressionScore = NormalizeDouble((bidAggression / total) * 100.0, 2);
   
   if(g_CurrentOrderFlow.AggressionScore > 60.0) {
      g_CurrentOrderFlow.Dominance = "BULLISH";
   } else if(g_CurrentOrderFlow.AggressionScore < 40.0) {
      g_CurrentOrderFlow.Dominance = "BEARISH";
   } else {
      g_CurrentOrderFlow.Dominance = "NEUTRAL";
   }
}

double CalculateFusionScore() {
   double structureWeight = 0.25;
   double volatilityWeight = 0.15;
   double orderFlowWeight = 0.35;
   double stateWeight = 0.25;
   
   // Normalize volatility component
   double volScore = MathMin(g_VolCompositeIndex / 3.0, 100.0);
   
   // State confidence component
   double stateScore = g_CurrentState.Confidence;
   
   // Order flow component with momentum bias
   double flowScore = g_CurrentOrderFlow.AggressionScore * InpMomentumBias;
   flowScore = MathMin(flowScore, 100.0);
   
   // Calculate weighted score
   double totalScore = (g_StructureStrength * structureWeight) + 
                       (volScore * volatilityWeight) +
                       (flowScore * orderFlowWeight) + 
                       (stateScore * stateWeight);
   
   // Bonus for extreme order flow (conviction)
   if(g_CurrentOrderFlow.AggressionScore > 85.0 || g_CurrentOrderFlow.AggressionScore < 15.0) {
      totalScore += 10.0;
   }
   
   // Bonus for aligned structure and order flow
   if((g_CurrentStructure == STRUCTURE_BULL && g_CurrentOrderFlow.AggressionScore > 60.0) ||
      (g_CurrentStructure == STRUCTURE_BEAR && g_CurrentOrderFlow.AggressionScore < 40.0)) {
      totalScore += 5.0;
   }
   
   return NormalizeDouble(MathMin(MathMax(totalScore, 0.0), 100.0), 2);
}

ENUM_STRATEGY_TYPE MetaRouter() {
   // Check if trading is enabled
   if(!g_TradingEnabled) {
      g_UIStatus = "TRADING DISABLED - DD LIMIT";
      return STRAT_STAND_ASIDE;
   }
   
   // Check minimum confidence
   if(g_FinalFusionScore < InpMinFusionScore) {
      g_UIStatus = "WAITING - LOW CONFIDENCE";
      return STRAT_STAND_ASIDE;
   }
   
   // Check volatility
   if(g_CurrentVolState == VOL_SUPPRESSED) {
      g_UIStatus = "WAITING - FLAT MARKET";
      return STRAT_STAND_ASIDE;
   }
   
   // Check spread
   if(!ValidateSpread()) {
      return STRAT_STAND_ASIDE;
   }
   
   // Check time between trades
   if(!ValidateMinTimeBetweenTrades()) {
      return STRAT_STAND_ASIDE;
   }
   
   g_UIStatus = "SIGNAL CONFIRMED";
   
   // Route to strategy based on market state
   if(g_CurrentState.State == STATE_TREND_EXPANSION || 
      g_CurrentState.State == STATE_TREND_CONTINUATION) {
      return STRAT_TREND_CONTINUATION;
   }
   
   if(g_CurrentState.State == STATE_VOLATILITY_EXPANSION || 
      g_CurrentVolState == VOL_EXPANDING) {
      return STRAT_VOLATILITY_BREAKOUT;
   }
   
   return STRAT_TREND_CONTINUATION;
}

double AllocateRisk(ENUM_STRATEGY_TYPE strategy, double &slPoints, double &rrRatio) {
   // Calculate confidence-based risk multiplier
   double confidenceMultiplier = MathMax(0.5, MathMin(1.5, (g_FinalFusionScore - 50.0) / 40.0));
   
   // Get account equity
   double equity = AccountInfoDouble(ACCOUNT_BALANCE);
   if(equity <= 0) {
      Print("ERROR: Invalid account equity");
      return 0.0;
   }
   
   // Calculate risk amount
   double riskAmount = equity * ((InpBaseRiskPercent * confidenceMultiplier) / 100.0);
   
   // Get ATR for SL calculation
   double atr = 200 * _Point;
   double atrBuf[1];
   if(CopyBuffer(g_hATR, 0, 0, 1, atrBuf) == 1) {
      atr = atrBuf[0];
   }
   
   // Calculate SL distance in points
   slPoints = MathMax(InpMinSLPoints, 
                     MathMin(InpMaxSLPoints, (atr / _Point) * InpSLMultiplierATR));
   
   // Calculate R:R ratio
   rrRatio = InpMinRiskReward;
   if(g_CurrentState.State == STATE_TREND_EXPANSION || 
      g_CurrentState.State == STATE_TREND_CONTINUATION) {
      rrRatio = MathMin(InpMaxRiskReward, InpMinRiskReward * 1.5);
   }
   
   // Calculate lot size
   double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   
   if(tickSize <= 0 || tickValue <= 0) {
      Print("ERROR: Invalid tick value or size");
      return 0.0;
   }
   
   double pointValue = (tickValue / tickSize) * _Point;
   double targetLot = riskAmount / (slPoints * pointValue);
   
   // Normalize lot size
   double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   
   if(lotStep <= 0) lotStep = 0.01;
   
   targetLot = MathFloor(targetLot / lotStep) * lotStep;
   targetLot = MathMax(minLot, MathMin(maxLot, targetLot));
   
   return NormalizeDouble(targetLot, 2);
}

bool IsPositionOpen() {
   for(int i = PositionsTotal()-1; i >= 0; i--) {
      if(g_Pos.SelectByIndex(i) && 
         g_Pos.Magic() == InpMagicNumber && 
         g_Pos.Symbol() == _Symbol) {
         return true;
      }
   }
   return false;
}

void ExecuteRoutedStrategy(ENUM_STRATEGY_TYPE strategy, double lotSize, double slPoints, double rrRatio) {
   if(lotSize <= 0) {
      Print("ERROR: Invalid lot size");
      return;
   }
   
   // Determine entry signal
   ENUM_SIGNAL entrySignal = SIGNAL_NONE;
   
   if(g_CurrentStructure == STRUCTURE_BULL && g_CurrentOrderFlow.AggressionScore > 55.0) {
      entrySignal = SIGNAL_BUY;
   } else if(g_CurrentStructure == STRUCTURE_BEAR && g_CurrentOrderFlow.AggressionScore < 45.0) {
      entrySignal = SIGNAL_SELL;
   }
   
   if(entrySignal == SIGNAL_NONE) {
      g_UIStatus = "NO CLEAR SIGNAL";
      return;
   }
   
   // Get entry price
   bool isBuy = (entrySignal == SIGNAL_BUY);
   double entryPrice = isBuy ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : 
                               SymbolInfoDouble(_Symbol, SYMBOL_BID);
   
   // Get ATR
   double atr = 200 * _Point;
   double atrBuf[1];
   if(CopyBuffer(g_hATR, 0, 0, 1, atrBuf) == 1) {
      atr = atrBuf[0];
   }
   
   // Calculate SL and TP
   double slPrice = CalculateOptimalSL(entryPrice, isBuy, atr);
   double tpPrice = CalculateOptimalTP(entryPrice, slPrice, isBuy, rrRatio);
   
   // Validate price levels
   if(!ValidatePriceLevels(entryPrice, slPrice, tpPrice, isBuy)) {
      Print("ERROR: Invalid price levels, trade aborted");
      return;
   }
   
   // Prepare trade request
   MqlTradeRequest req;
   MqlTradeResult res;
   ZeroMemory(req);
   ZeroMemory(res);
   
   req.action = TRADE_ACTION_DEAL;
   req.symbol = _Symbol;
   req.volume = lotSize;
   req.type = isBuy ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
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
      Print("Entry: ", entryPrice, " SL: ", slPrice, " TP: ", tpPrice);
      return;
   }
   
   if(res.retcode == TRADE_RETCODE_DONE || res.retcode == TRADE_RETCODE_PLACED) {
      g_LastTradeTime = TimeCurrent();
      g_UIStatus = "TRADE EXECUTED";
      
      Print("=== TRADE EXECUTED ===");
      Print("Type: ", isBuy ? "BUY" : "SELL");
      Print("Lot Size: ", lotSize);
      Print("Entry: ", entryPrice);
      Print("SL: ", slPrice, " (", DoubleToString(MathAbs(entryPrice - slPrice) / _Point, 1), " pts)");
      Print("TP: ", tpPrice, " (", DoubleToString(MathAbs(tpPrice - entryPrice) / _Point, 1), " pts)");
      Print("R:R Ratio: 1:", DoubleToString(rrRatio, 2));
      Print("Confidence: ", g_FinalFusionScore);
      Print("=====================");
   } else {
      Print("ERROR: Trade rejected. Return code: ", res.retcode);
   }
}

void ManageLifecycle() {
   // Find and select the position
   bool positionFound = false;
   for(int i = PositionsTotal()-1; i >= 0; i--) {
      if(g_Pos.SelectByIndex(i) && 
         g_Pos.Magic() == InpMagicNumber && 
         g_Pos.Symbol() == _Symbol) {
         positionFound = true;
         break;
      }
   }
   
   if(!positionFound) return;
   
   g_UIStatus = "TRADE ACTIVE - MANAGING";
   
   double entry = g_Pos.PriceOpen();
   double sl = g_Pos.StopLoss();
   double tp = g_Pos.TakeProfit();
   bool isBuy = (g_Pos.PositionType() == POSITION_TYPE_BUY);
   
   double currentPrice = isBuy ? SymbolInfoDouble(_Symbol, SYMBOL_BID) : 
                                 SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   
   // Calculate initial risk
   double initRisk = MathAbs(entry - sl) / _Point;
   if(initRisk <= 0) return;
   
   // Calculate current profit in points
   double currentProfit = isBuy ? ((currentPrice - entry) / _Point) : 
                                  ((entry - currentPrice) / _Point);
   
   bool slModified = false;
   double newSL = sl;
   
   // Breakeven logic
   if(InpUseBreakeven && currentProfit >= (initRisk * InpBreakevenTrigger)) {
      double breakeven = entry + (isBuy ? (5 * _Point) : -(5 * _Point)); // Small buffer
      
      if(isBuy && (sl < breakeven)) {
         newSL = breakeven;
         slModified = true;
         g_UIStatus = "MOVED TO BREAKEVEN";
      } else if(!isBuy && (sl > breakeven || sl == 0)) {
         newSL = breakeven;
         slModified = true;
         g_UIStatus = "MOVED TO BREAKEVEN";
      }
   }
   
   // Trailing stop logic
   if(InpUseTrailingStop && currentProfit >= (initRisk * InpTrailTrigger)) {
      double trailDistance = initRisk * InpTrailDistance;
      double trailSL = isBuy ? (currentPrice - (trailDistance * _Point)) : 
                               (currentPrice + (trailDistance * _Point));
      
      if(isBuy && trailSL > newSL) {
         newSL = trailSL;
         slModified = true;
         g_UIStatus = "TRAILING STOP ACTIVE";
      } else if(!isBuy && (trailSL < newSL || newSL == 0)) {
         newSL = trailSL;
         slModified = true;
         g_UIStatus = "TRAILING STOP ACTIVE";
      }
   }
   
   // Apply SL modification
   if(slModified) {
      newSL = NormalizeDouble(newSL, _Digits);
      if(g_Trade.PositionModify(g_Pos.Ticket(), newSL, tp)) {
         Print("Position modified - New SL: ", newSL);
      }
   }
}

//+------------------------------------------------------------------+
//| ON TICK CORE PIPELINE                                            |
//+------------------------------------------------------------------+
void OnTick() {
   // Update drawdown metrics
   UpdateDrawdownMetrics();
   
   // Observe market
   if(!ObserveMarket()) return;
   
   // Run analysis modules
   g_CurrentState = ClassifyMarketState();
   AnalyzeVolatility();
   AnalyzeMarketStructure();
   EstimateOrderFlow();
   g_FinalFusionScore = CalculateFusionScore();
   
   // Manage existing position or look for new entry
   if(IsPositionOpen()) {
      ManageLifecycle();
   } else {
      // Check if we should enter a trade
      ENUM_STRATEGY_TYPE chosenStrategy = MetaRouter();
      
      if(chosenStrategy != STRAT_STAND_ASIDE) {
         double slPoints = 0;
         double rrRatio = 0;
         double calculatedRisk = AllocateRisk(chosenStrategy, slPoints, rrRatio);
         
         if(calculatedRisk > 0) {
            ExecuteRoutedStrategy(chosenStrategy, calculatedRisk, slPoints, rrRatio);
         }
      }
   }
   
   // Update UI
   MqlTick tick;
   if(SymbolInfoTick(_Symbol, tick)) {
      double liveSpread = (tick.ask - tick.bid) / _Point;
      string macroStatus = (g_CurrentStructure == STRUCTURE_BULL) ? "BULLISH" : 
                          ((g_CurrentStructure == STRUCTURE_BEAR) ? "BEARISH" : "RANGING");
      color macroClr = (g_CurrentStructure == STRUCTURE_BULL) ? clrLime : 
                       ((g_CurrentStructure == STRUCTURE_BEAR) ? clrAccentWarn : clrWhite);
      
      double currentRR = InpMinRiskReward;
      
      UpdateDashboardMetrics(g_UIStatus, macroStatus, macroClr, 
                           g_CurrentOrderFlow.AggressionScore, 
                           g_FinalFusionScore, liveSpread, 
                           currentRR, g_CurrentDrawdown, g_TradingEnabled);
   }
}