//+------------------------------------------------------------------+
//|                 QUANTUM GRID COMMAND CENTER v9.0                  |
//|          Adaptive Liquidity Intelligence Trading System           |
//|          Professional Dashboard - Fully Responsive Design         |
//+------------------------------------------------------------------+
#property copyright "Quantum Technologies © 2024"
#property version   "9.00"
#property description "Institutional-Grade Grid EA with Real-Time Intelligence Dashboard"
#property strict

#include <Trade\Trade.mqh>

//+------------------------------------------------------------------+
//| RESPONSIVE DASHBOARD CONFIGURATION                                |
//+------------------------------------------------------------------+
#define DASH_PREFIX "QG_"
#define MIN_PANEL_WIDTH 380
#define MAX_PANEL_WIDTH 480
#define PANEL_WIDTH_PCT 28        // 28% of chart width
#define MARGIN_TOP 15
#define MARGIN_SIDE 15
#define MARGIN_BOTTOM 50          // Space from chart bottom
#define CARD_SPACING 10
#define CARD_PADDING 12
#define ROW_HEIGHT 22

// Quantum Grid Color System
#define QG_BG_DEEP        C'15,23,42'
#define QG_CARD_BG        C'51,65,85'
#define QG_BORDER         C'71,85,105'
#define QG_TEXT_PRIMARY   C'248,250,252'
#define QG_TEXT_SECONDARY C'148,163,184'
#define QG_TEXT_DIM       C'100,116,139'
#define QG_ACCENT_CYAN    C'6,182,212'
#define QG_ACCENT_PURPLE  C'168,85,247'
#define QG_SUCCESS        C'16,185,129'
#define QG_DANGER         C'239,68,68'
#define QG_WARNING        C'245,158,11'
#define QG_INFO           C'59,130,246'

// Chart Theme
#define QG_CHART_BG       C'10,15,30'
#define QG_CHART_GRID     C'30,41,59'
#define QG_CHART_BULL     C'16,185,129'
#define QG_CHART_BEAR     C'239,68,68'

// Control Names
#define BTN_CLOSE_PROFIT  "BTN_PROFIT"
#define BTN_CLOSE_LOSS    "BTN_LOSS"
#define BTN_TOGGLE_TRADE  "BTN_TOGGLE"

//+------------------------------------------------------------------+
//| LIQUIDITY INTELLIGENCE ENUMS                                      |
//+------------------------------------------------------------------+
enum LiquidityState
{
   LIQ_VERY_LOW    = 0,
   LIQ_LOW         = 1,
   LIQ_NORMAL      = 2,
   LIQ_HIGH        = 3,
   LIQ_VERY_HIGH   = 4
};

enum VolatilityRegime
{
   VOL_DORMANT     = 0,
   VOL_LOW         = 1,
   VOL_NORMAL      = 2,
   VOL_HIGH        = 3,
   VOL_EXTREME     = 4
};

enum MarketMomentum
{
   MOM_STRONG_BEAR = -2,
   MOM_WEAK_BEAR   = -1,
   MOM_NEUTRAL     = 0,
   MOM_WEAK_BULL   = 1,
   MOM_STRONG_BULL = 2
};

enum ExecutionMode
{
   Stealth      = 1,
   Adaptive     = 2,
   Aggressive   = 3
};

//+------------------------------------------------------------------+
//| INPUT PARAMETERS                                                  |
//+------------------------------------------------------------------+
input group "═══ GRID CONFIGURATION ═══"
input ExecutionMode InpMode = Aggressive;
input int InpOrdersPerSide = 10;
input int InpMaxOrderLifetimeSeconds = 60;
input bool InpAutoRecycleStaleOrders = true;

input group "═══ BALANCED TARGETS (R:R) ═══"
input bool InpUseDynamicTargets = true;
input double InpMinRiskRewardRatio = 1.8;
input double InpScalpTargetMultiplier = 2.2;
input bool InpAllowEarlyExit = true;

input group "═══ LIQUIDITY INTELLIGENCE ═══"
input bool InpUseLiquidityFilter = true;
input int InpVolumeLookback = 20;
input double InpMinVolumeRatio = 0.7;
input bool InpUseMomentumFilter = true;
input int InpMomentumPeriod = 14;
input bool InpTradeWithTrend = true;
input bool InpUseVolatilityAdaptation = true;

input group "═══ ORDER PROXIMITY ═══"
input double InpMinOrderDistanceATR = 0.15;
input double InpMaxOrderDistanceATR = 0.5;
input double InpGridStepATR = 0.035;

input group "═══ RISK MANAGEMENT ═══"
input double InpBaseLot = 0.15;
input double InpRiskPercent = 0.5;
input double InpMaxTotalLots = 3.0;
input double InpSLATRMult = 1.0;
input double InpTPATRMult = 2.2;

input group "═══ EXECUTION ENGINE ═══"
input bool InpUseTickDrivenMgmt = true;
input int InpTradeDeviationPts = 5;
input int InpTimerMs = 100;

input group "═══ POSITION MANAGEMENT ═══"
input int InpMaxHoldMinutes = 60;
input bool InpForceCloseAtMaxHold = false;
input bool InpUseBreakeven = true;
input double InpBreakevenATR = 0.6;
input double InpBreakevenBufferPts = 10;
input bool InpUseTrailing = true;
input double InpTrailStartATR = 1.2;
input double InpTrailATR = 0.4;

input group "═══ CIRCUIT BREAKER ═══"
input double InpDailyProfitTarget = 50.0;
input double InpDailyLossLimit = 30.0;
input bool InpCloseAllOnLossLimit = true;
input double InpMaxDrawdownPct = 8.0;

input group "═══ ANALYSIS ═══"
input ENUM_TIMEFRAMES InpAnalysisTF = PERIOD_M1;
input int InpATRPeriod = 14;
input int InpMaxSpreadPoints = 80;
input int InpEMAPeriod = 20;

input group "═══ DASHBOARD ═══"
input bool InpShowDashboard = true;
input bool InpAutoStyleChart = true;
input bool InpHideGridLines = true;
input bool InpRestoreChartOnRemove = false;

input group "═══ SESSION FILTER ═══"
input bool InpTradeAllSessions = true;
input bool InpTradeSydneySession = true;
input int  InpSydneyStartHour = 21;
input int  InpSydneyEndHour = 6;
input bool InpTradeTokyoSession = true;
input int  InpTokyoStartHour = 0;
input int  InpTokyoEndHour = 9;
input bool InpTradeLondonSession = true;
input int  InpLondonStartHour = 7;
input int  InpLondonEndHour = 16;
input bool InpTradeNewYorkSession = true;
input int  InpNewYorkStartHour = 12;
input int  InpNewYorkEndHour = 21;

//+------------------------------------------------------------------+
//| GLOBAL VARIABLES                                                  |
//+------------------------------------------------------------------+
CTrade trade;
int handleATR;
int handleEMA;
datetime lastBarTime = 0;
int magic = 990090;

// Account tracking
double dayStartBalance = 0.0;
int lastDayChecked = -1;
double dailyProfit = 0.0;
double peakEquity = 0.0;
double grossProfit = 0.0, grossLoss = 0.0;
int totalWins = 0, totalLosses = 0;
bool tradingEnabled = true;
double recentProfitFactor = 1.0;

// Scalping metrics
double totalScalpProfit = 0.0;
int scalpWins = 0;
double avgWinSize = 0.0;
double avgLossSize = 0.0;
double realizedRR = 0.0;

// Timing
datetime lastTickManagement = 0;
datetime lastGridDeployTime = 0;
datetime lastFillTime = 0;
ulong lastFilledOrderTicket = 0;
datetime eaStartTime = 0;

// Symbol info
int symbolDigits = 0;
double symbolPoint = 0.0, pipSize = 0.0;
bool isJPYPair = false;

// Cache
double cachedATR = 0.0;
datetime atrCacheTime = 0;
double cachedEMA = 0.0;
datetime emaCacheTime = 0;

//+------------------------------------------------------------------+
//| LIQUIDITY INTELLIGENCE STATE                                      |
//+------------------------------------------------------------------+
struct LiquidityIntelligence
{
   double avgVolume;
   double currentVolume;
   double volumeRatio;
   double volumeStdDev;
   
   double momentum;
   double acceleration;
   MarketMomentum momentumState;
   
   double currentATR;
   double avgATR;
   double atrRatio;
   VolatilityRegime volRegime;
   
   LiquidityState liquidityState;
   double liquidityScore;
   
   double bidAskSpread;
   double spreadRatio;
   int ticksPerSecond;
   double priceVelocity;
   
   double dynamicTPMultiplier;
   double dynamicSLMultiplier;
   double recommendedRR;
   
   bool allowLongEntry;
   bool allowShortEntry;
   double lotSizeMultiplier;
   
   datetime lastUpdate;
} LiqIntel;

//+------------------------------------------------------------------+
//| RESPONSIVE DASHBOARD STATE                                        |
//+------------------------------------------------------------------+
struct QuantumDashboard
{
   // Dynamic positioning
   int chartWidth;
   int chartHeight;
   int panelWidth;
   int panelHeight;
   int x;
   int y;
   int currentY;
   
   // State
   int objectCount;
   bool initialized;
   datetime lastUpdate;
   datetime lastResize;
   string statusMessage;
   
   // Dimensions
   int headerHeight;
   int signalHeight;
   int metricsHeight;
   int liqHeight;
   int posHeight;
   int accHeight;
   int ctrlHeight;
} qDash;

//+------------------------------------------------------------------+
//| INITIALIZATION                                                    |
//+------------------------------------------------------------------+
int OnInit()
{
   if(InpRiskPercent > 10.0)
   {
      Print("⚠ ERROR: Risk % exceeds safety limit");
      return INIT_PARAMETERS_INCORRECT;
   }
   
   if(InpOrdersPerSide < 1 || InpOrdersPerSide > 50)
   {
      Print("⚠ ERROR: Orders per side must be 1-50");
      return INIT_PARAMETERS_INCORRECT;
   }
   
   if(InpMinRiskRewardRatio < 1.0)
   {
      Print("⚠ ERROR: Minimum R:R must be >= 1.0");
      return INIT_PARAMETERS_INCORRECT;
   }

   // Symbol info
   symbolDigits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   symbolPoint = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   
   string symbolName = _Symbol;
   isJPYPair = (StringFind(symbolName, "JPY") >= 0);
   
   if(isJPYPair)
      pipSize = 0.01;
   else if(symbolDigits == 3 || symbolDigits == 2)
      pipSize = 0.01;
   else
      pipSize = 0.0001;

   // Trade setup
   trade.SetExpertMagicNumber(magic);
   trade.SetDeviationInPoints(InpTradeDeviationPts);
   trade.SetTypeFillingBySymbol(_Symbol);

   // Indicators
   handleATR = iATR(_Symbol, InpAnalysisTF, InpATRPeriod);
   if(handleATR == INVALID_HANDLE)
   {
      Print("⚠ ERROR: ATR indicator failed");
      return INIT_FAILED;
   }

   handleEMA = iMA(_Symbol, InpAnalysisTF, InpEMAPeriod, 0, MODE_EMA, PRICE_CLOSE);
   if(handleEMA == INVALID_HANDLE)
   {
      Print("⚠ ERROR: EMA indicator failed");
      return INIT_FAILED;
   }

   // Timer
   EventSetMillisecondTimer(InpTimerMs);
   
   // Account tracking
   peakEquity = AccountInfoDouble(ACCOUNT_EQUITY);
   dayStartBalance = AccountInfoDouble(ACCOUNT_BALANCE);

   MqlDateTime tm;
   TimeToStruct(TimeCurrent(), tm);
   lastDayChecked = tm.day;
   
   eaStartTime = TimeCurrent();

   // Liquidity intelligence
   ZeroMemory(LiqIntel);
   UpdateLiquidityIntelligence();

   // Chart theme
   if(InpAutoStyleChart)
      ApplyQuantumChartTheme();

   // Dashboard
   if(InpShowDashboard)
      InitQuantumDashboard();

   Print("═══════════════════════════════════════════════════");
   Print("⚡ QUANTUM GRID COMMAND CENTER v9.0 ONLINE");
   Print("Symbol: ", _Symbol, " | Digits: ", symbolDigits);
   Print("Grid: ", InpOrdersPerSide, " BUY + ", InpOrdersPerSide, " SELL");
   Print("Min R:R: 1:", DoubleToString(InpMinRiskRewardRatio, 1));
   Print("Dashboard: ", InpShowDashboard ? "ACTIVE" : "DISABLED");
   Print("═══════════════════════════════════════════════════");
   
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| DEINITIALIZATION                                                  |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   EventKillTimer();
   IndicatorRelease(handleATR);
   IndicatorRelease(handleEMA);
   
   if(InpShowDashboard)
      DestroyQuantumDashboard();

   if(InpRestoreChartOnRemove)
   {
      ChartSetInteger(0, CHART_COLOR_BACKGROUND, clrWhite);
      ChartSetInteger(0, CHART_COLOR_FOREGROUND, clrBlack);
      ChartSetInteger(0, CHART_SHOW_GRID, true);
      ChartSetInteger(0, CHART_COLOR_GRID, C'218,223,225');
      ChartRedraw(0);
   }
   
   Print("═══════════════════════════════════════════════════");
   Print("⚡ QUANTUM GRID SHUTDOWN");
   Print("Session: ", totalWins, "W / ", totalLosses, "L");
   if(totalWins > 0)
      Print("Avg Win: $", DoubleToString(avgWinSize, 2));
   if(totalLosses > 0)
      Print("Avg Loss: $", DoubleToString(avgLossSize, 2));
   if(totalWins + totalLosses > 0)
      Print("Realized R:R: 1:", DoubleToString(realizedRR, 2));
   Print("Net P/L: $", DoubleToString(grossProfit - grossLoss, 2));
   Print("═══════════════════════════════════════════════════");
}

//+------------------------------------------------------------------+
//| CHART THEME                                                       |
//+------------------------------------------------------------------+
void ApplyQuantumChartTheme()
{
   ChartSetInteger(0, CHART_COLOR_BACKGROUND, QG_CHART_BG);
   ChartSetInteger(0, CHART_COLOR_FOREGROUND, QG_TEXT_PRIMARY);
   ChartSetInteger(0, CHART_COLOR_GRID, QG_CHART_GRID);
   ChartSetInteger(0, CHART_SHOW_GRID, !InpHideGridLines);
   ChartSetInteger(0, CHART_MODE, CHART_CANDLES);
   ChartSetInteger(0, CHART_COLOR_CANDLE_BULL, QG_CHART_BULL);
   ChartSetInteger(0, CHART_COLOR_CANDLE_BEAR, QG_CHART_BEAR);
   ChartSetInteger(0, CHART_COLOR_CHART_UP, QG_CHART_BULL);
   ChartSetInteger(0, CHART_COLOR_CHART_DOWN, QG_CHART_BEAR);
   ChartSetInteger(0, CHART_SHOW_OBJECT_DESCR, false);
   ChartSetInteger(0, CHART_SHOW_OHLC, false);
   ChartRedraw(0);
}

//+------------------------------------------------------------------+
//| DASHBOARD PRIMITIVES - RESPONSIVE                                 |
//+------------------------------------------------------------------+
void QG_CreateRect(string name, int x, int y, int w, int h, color bg)
{
   string objName = DASH_PREFIX + name;
   
   if(ObjectFind(0, objName) < 0)
   {
      ObjectCreate(0, objName, OBJ_RECTANGLE_LABEL, 0, 0, 0);
      qDash.objectCount++;
   }
   
   ObjectSetInteger(0, objName, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, objName, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, objName, OBJPROP_XSIZE, w);
   ObjectSetInteger(0, objName, OBJPROP_YSIZE, h);
   ObjectSetInteger(0, objName, OBJPROP_BGCOLOR, bg);
   ObjectSetInteger(0, objName, OBJPROP_BORDER_TYPE, BORDER_FLAT);
   ObjectSetInteger(0, objName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, objName, OBJPROP_BACK, true);
   ObjectSetInteger(0, objName, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, objName, OBJPROP_HIDDEN, true);
}

void QG_CreateText(string name, int x, int y, string text, color clr, int size = 9, 
                   string font = "Segoe UI Semibold", int anchor = ANCHOR_LEFT_UPPER)
{
   string objName = DASH_PREFIX + name;
   
   if(ObjectFind(0, objName) < 0)
   {
      ObjectCreate(0, objName, OBJ_LABEL, 0, 0, 0);
      qDash.objectCount++;
   }
   
   ObjectSetInteger(0, objName, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, objName, OBJPROP_YDISTANCE, y);
   ObjectSetString(0, objName, OBJPROP_TEXT, text);
   ObjectSetInteger(0, objName, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, objName, OBJPROP_FONTSIZE, size);
   ObjectSetString(0, objName, OBJPROP_FONT, font);
   ObjectSetInteger(0, objName, OBJPROP_ANCHOR, anchor);
   ObjectSetInteger(0, objName, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, objName, OBJPROP_HIDDEN, true);
}

void QG_UpdateText(string name, string newText)
{
   ObjectSetString(0, DASH_PREFIX + name, OBJPROP_TEXT, newText);
}

void QG_UpdateColor(string name, color newColor)
{
   ObjectSetInteger(0, DASH_PREFIX + name, OBJPROP_COLOR, newColor);
}

void QG_CreateButton(string name, int x, int y, int w, int h, string text, 
                     color bg, color txtColor, int fontSize = 10)
{
   string objName = DASH_PREFIX + name;
   
   if(ObjectFind(0, objName) < 0)
   {
      ObjectCreate(0, objName, OBJ_BUTTON, 0, 0, 0);
      qDash.objectCount++;
   }
   
   ObjectSetInteger(0, objName, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, objName, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, objName, OBJPROP_XSIZE, w);
   ObjectSetInteger(0, objName, OBJPROP_YSIZE, h);
   ObjectSetString(0, objName, OBJPROP_TEXT, text);
   ObjectSetInteger(0, objName, OBJPROP_BGCOLOR, bg);
   ObjectSetInteger(0, objName, OBJPROP_COLOR, txtColor);
   ObjectSetInteger(0, objName, OBJPROP_BORDER_COLOR, bg);
   ObjectSetInteger(0, objName, OBJPROP_FONTSIZE, fontSize);
   ObjectSetString(0, objName, OBJPROP_FONT, "Segoe UI Black");
   ObjectSetInteger(0, objName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, objName, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, objName, OBJPROP_HIDDEN, true);
   ObjectSetInteger(0, objName, OBJPROP_STATE, false);
}

//+------------------------------------------------------------------+
//| CALCULATE RESPONSIVE DIMENSIONS                                   |
//+------------------------------------------------------------------+
void CalculateDashboardDimensions()
{
   // Get current chart dimensions
   qDash.chartWidth = (int)ChartGetInteger(0, CHART_WIDTH_IN_PIXELS);
   qDash.chartHeight = (int)ChartGetInteger(0, CHART_HEIGHT_IN_PIXELS);
   
   // Calculate responsive panel width
   qDash.panelWidth = (qDash.chartWidth * PANEL_WIDTH_PCT) / 100;
   qDash.panelWidth = MathMax(MIN_PANEL_WIDTH, MathMin(MAX_PANEL_WIDTH, qDash.panelWidth));
   
   // Position from top-left
   qDash.x = MARGIN_SIDE;
   qDash.y = MARGIN_TOP;
   
   // Calculate component heights (responsive to content)
   qDash.headerHeight = 70;
   qDash.signalHeight = 90;
   qDash.metricsHeight = 130;
   qDash.liqHeight = 120;
   qDash.posHeight = 100;
   qDash.accHeight = 120;
   qDash.ctrlHeight = 130;
   
   // Total panel height
   qDash.panelHeight = qDash.headerHeight + qDash.signalHeight + qDash.metricsHeight +
                       qDash.liqHeight + qDash.posHeight + qDash.accHeight + 
                       qDash.ctrlHeight + (CARD_SPACING * 7) + 10;
   
   // Ensure panel fits in chart height
   int maxHeight = qDash.chartHeight - MARGIN_TOP - MARGIN_BOTTOM;
   if(qDash.panelHeight > maxHeight)
   {
      // Scale down if necessary
      double scale = (double)maxHeight / qDash.panelHeight;
      qDash.headerHeight = (int)(qDash.headerHeight * scale);
      qDash.signalHeight = (int)(qDash.signalHeight * scale);
      qDash.metricsHeight = (int)(qDash.metricsHeight * scale);
      qDash.liqHeight = (int)(qDash.liqHeight * scale);
      qDash.posHeight = (int)(qDash.posHeight * scale);
      qDash.accHeight = (int)(qDash.accHeight * scale);
      qDash.ctrlHeight = (int)(qDash.ctrlHeight * scale);
      qDash.panelHeight = maxHeight;
   }
   
   qDash.currentY = qDash.y;
}

//+------------------------------------------------------------------+
//| INITIALIZE DASHBOARD                                              |
//+------------------------------------------------------------------+
void InitQuantumDashboard()
{
   CalculateDashboardDimensions();
   
   qDash.objectCount = 0;
   qDash.initialized = true;
   qDash.lastUpdate = 0;
   qDash.lastResize = TimeCurrent();
   qDash.statusMessage = "System Online";
   
   Print("✅ Quantum Dashboard initialized: ", qDash.panelWidth, "x", qDash.panelHeight, "px");
}

//+------------------------------------------------------------------+
//| DESTROY DASHBOARD                                                 |
//+------------------------------------------------------------------+
void DestroyQuantumDashboard()
{
   ObjectsDeleteAll(0, DASH_PREFIX);
   qDash.initialized = false;
   Print("🗑 Quantum Dashboard destroyed - ", qDash.objectCount, " objects removed");
}

//+------------------------------------------------------------------+
//| DRAW HEADER                                                       |
//+------------------------------------------------------------------+
void DrawQuantumHeader()
{
   int y = qDash.currentY;
   int pad = CARD_PADDING;
   int cardW = qDash.panelWidth - 5;
   
   // Main background
   QG_CreateRect("MAIN_BG", qDash.x, y, qDash.panelWidth, qDash.panelHeight, QG_BG_DEEP);
   
   // Accent stripe
   QG_CreateRect("ACCENT_STRIPE", qDash.x, y, 5, qDash.panelHeight, QG_ACCENT_CYAN);
   
   // Header card
   QG_CreateRect("HEADER_CARD", qDash.x + 5, y, cardW, qDash.headerHeight, QG_CARD_BG);
   
   // EA Title
   QG_CreateText("EA_NAME", qDash.x + pad + 5, y + pad, 
                 "QUANTUM GRID", QG_ACCENT_CYAN, 14, "Segoe UI Black");
   QG_CreateText("EA_SUBTITLE", qDash.x + pad + 5, y + pad + 22, 
                 "LIQUIDITY INTELLIGENCE ENGINE", QG_TEXT_SECONDARY, 8);
   
   // Status indicator
   string statusText = tradingEnabled ? "ACTIVE" : "PAUSED";
   color statusColor = tradingEnabled ? QG_SUCCESS : QG_DANGER;
   
   int ledX = qDash.x + cardW - pad - 65;
   QG_CreateRect("STATUS_LED", ledX, y + pad, 10, 10, statusColor);
   QG_CreateText("STATUS_TEXT", ledX + 15, y + pad - 2, 
                 statusText, statusColor, 9, "Segoe UI Bold");
   
   // Symbol & Time
   QG_CreateText("SYMBOL", qDash.x + pad + 5, y + pad + 40, 
                 _Symbol, QG_TEXT_PRIMARY, 11, "Consolas");
   
   string timeStr = TimeToString(TimeCurrent(), TIME_MINUTES);
   QG_CreateText("TIME", qDash.x + cardW - pad, y + pad + 40, 
                 timeStr, QG_TEXT_SECONDARY, 9, "Consolas", ANCHOR_RIGHT_UPPER);
   
   qDash.currentY = y + qDash.headerHeight + CARD_SPACING;
}

//+------------------------------------------------------------------+
//| DRAW SIGNAL PANEL                                                 |
//+------------------------------------------------------------------+
void DrawSignalPanel()
{
   int y = qDash.currentY;
   int pad = CARD_PADDING;
   int cardX = qDash.x + 5;
   int cardW = qDash.panelWidth - 5;
   
   QG_CreateRect("SIGNAL_CARD", cardX, y, cardW, qDash.signalHeight, QG_CARD_BG);
   
   QG_CreateText("SIGNAL_LBL", cardX + pad, y + pad, 
                 "MARKET SIGNAL", QG_TEXT_SECONDARY, 8);
   
   // Determine signal
   string signalText = "WAIT";
   color signalColor = QG_TEXT_DIM;
   
   if(!IsTradingSessionAllowed())
   {
      signalText = "SESSION CLOSED";
      signalColor = QG_TEXT_DIM;
   }
   else if(!tradingEnabled)
   {
      signalText = "PAUSED";
      signalColor = QG_WARNING;
   }
   else if(InpUseLiquidityFilter && LiqIntel.liquidityState == LIQ_VERY_LOW)
   {
      signalText = "LOW LIQUIDITY";
      signalColor = QG_DANGER;
   }
   else if(LiqIntel.allowLongEntry && !LiqIntel.allowShortEntry)
   {
      signalText = "BUY SIGNAL";
      signalColor = QG_SUCCESS;
   }
   else if(LiqIntel.allowShortEntry && !LiqIntel.allowLongEntry)
   {
      signalText = "SELL SIGNAL";
      signalColor = QG_DANGER;
   }
   else if(LiqIntel.allowLongEntry && LiqIntel.allowShortEntry)
   {
      signalText = "GRID READY";
      signalColor = QG_ACCENT_PURPLE;
   }
   
   // Signal box
   int boxH = qDash.signalHeight - pad - 30;
   QG_CreateRect("SIGNAL_BOX", cardX + pad, y + 30, cardW - 2*pad, boxH, QG_BG_DEEP);
   QG_CreateText("SIGNAL_MAIN", cardX + cardW/2, y + 30 + boxH/2 - 8, 
                 signalText, signalColor, 16, "Segoe UI Black", ANCHOR_CENTER);
   
   qDash.currentY = y + qDash.signalHeight + CARD_SPACING;
}

//+------------------------------------------------------------------+
//| DRAW METRIC BOX                                                   |
//+------------------------------------------------------------------+
void DrawMetricBox(string name, int x, int y, int w, int h, string label, string value, color accentColor)
{
   QG_CreateRect(name + "_BG", x, y, w, h, QG_BG_DEEP);
   QG_CreateRect(name + "_ACCENT", x, y, w, 2, accentColor);
   QG_CreateText(name + "_LBL", x + w/2, y + 8, label, QG_TEXT_DIM, 7, "Segoe UI", ANCHOR_CENTER);
   QG_CreateText(name + "_VAL", x + w/2, y + 22, value, QG_TEXT_PRIMARY, 11, "Consolas", ANCHOR_CENTER);
}

//+------------------------------------------------------------------+
//| DRAW MARKET METRICS                                               |
//+------------------------------------------------------------------+
void DrawMarketMetrics()
{
   int y = qDash.currentY;
   int pad = CARD_PADDING;
   int cardX = qDash.x + 5;
   int cardW = qDash.panelWidth - 5;
   
   QG_CreateRect("METRICS_CARD", cardX, y, cardW, qDash.metricsHeight, QG_CARD_BG);
   
   QG_CreateText("METRICS_LBL", cardX + pad, y + pad, 
                 "MARKET METRICS", QG_TEXT_SECONDARY, 8);
   
   MqlTick tick;
   SymbolInfoTick(_Symbol, tick);
   double atr = GetCurrentATR();
   double spread = (tick.ask - tick.bid) / symbolPoint;
   
   int boxW = (cardW - 3*pad) / 2;
   int boxH = 45;
   
   DrawMetricBox("M1", cardX + pad, y + 25, boxW, boxH, 
                 "BID", DoubleToString(tick.bid, symbolDigits), QG_INFO);
   
   DrawMetricBox("M2", cardX + pad + boxW + pad, y + 25, boxW, boxH, 
                 "ASK", DoubleToString(tick.ask, symbolDigits), QG_ACCENT_PURPLE);
   
   color atrColor = (atr > 0) ? QG_SUCCESS : QG_DANGER;
   DrawMetricBox("M3", cardX + pad, y + 75, boxW, boxH, 
                 "ATR", DoubleToString(atr/pipSize, 1) + "p", atrColor);
   
   color spreadColor = (spread <= InpMaxSpreadPoints) ? QG_SUCCESS : QG_DANGER;
   DrawMetricBox("M4", cardX + pad + boxW + pad, y + 75, boxW, boxH, 
                 "SPREAD", DoubleToString(spread, 0) + "p", spreadColor);
   
   qDash.currentY = y + qDash.metricsHeight + CARD_SPACING;
}

//+------------------------------------------------------------------+
//| DRAW INFO ROW                                                     |
//+------------------------------------------------------------------+
void DrawInfoRow(string name, int x, int y, int w, string label, string value, color valueColor)
{
   QG_CreateText(name + "_LBL", x, y, label, QG_TEXT_SECONDARY, 8);
   QG_CreateText(name + "_VAL", x + w, y, value, valueColor, 9, "Segoe UI Bold", ANCHOR_RIGHT_UPPER);
}

//+------------------------------------------------------------------+
//| DRAW LIQUIDITY PANEL                                              |
//+------------------------------------------------------------------+
void DrawLiquidityPanel()
{
   int y = qDash.currentY;
   int pad = CARD_PADDING;
   int cardX = qDash.x + 5;
   int cardW = qDash.panelWidth - 5;
   
   QG_CreateRect("LIQ_CARD", cardX, y, cardW, qDash.liqHeight, QG_CARD_BG);
   
   QG_CreateText("LIQ_LBL", cardX + pad, y + pad, 
                 "LIQUIDITY INTELLIGENCE", QG_TEXT_SECONDARY, 8);
   
   string liqText = LiquidityStateToString(LiqIntel.liquidityState);
   color liqColor = LiquidityStateColor(LiqIntel.liquidityState);
   
   DrawInfoRow("LIQ_STATE", cardX + pad, y + 25, cardW - 2*pad, 
               "STATE", liqText, liqColor);
   
   color volColor = (LiqIntel.volumeRatio >= InpMinVolumeRatio) ? QG_SUCCESS : QG_DANGER;
   DrawInfoRow("LIQ_VOL", cardX + pad, y + 45, cardW - 2*pad, 
               "VOLUME", DoubleToString(LiqIntel.volumeRatio, 2) + "×", volColor);
   
   string momText = MomentumToString(LiqIntel.momentumState);
   color momColor = (LiqIntel.momentumState > 0) ? QG_SUCCESS : 
                    (LiqIntel.momentumState < 0) ? QG_DANGER : QG_TEXT_DIM;
   DrawInfoRow("LIQ_MOM", cardX + pad, y + 65, cardW - 2*pad, 
               "MOMENTUM", momText, momColor);
   
   color rrColor = (LiqIntel.recommendedRR >= InpMinRiskRewardRatio) ? QG_SUCCESS : QG_WARNING;
   DrawInfoRow("LIQ_RR", cardX + pad, y + 85, cardW - 2*pad, 
               "TARGET R:R", "1:" + DoubleToString(LiqIntel.recommendedRR, 1), rrColor);
   
   qDash.currentY = y + qDash.liqHeight + CARD_SPACING;
}

//+------------------------------------------------------------------+
//| DRAW POSITION SUMMARY                                             |
//+------------------------------------------------------------------+
void DrawPositionSummary()
{
   int y = qDash.currentY;
   int pad = CARD_PADDING;
   int cardX = qDash.x + 5;
   int cardW = qDash.panelWidth - 5;
   
   int buyCount = 0, sellCount = 0;
   double totalFloat = 0.0;
   
   for(int i = 0; i < PositionsTotal(); i++)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket > 0 && PositionSelectByTicket(ticket))
      {
         if(PositionGetString(POSITION_SYMBOL) == _Symbol && 
            PositionGetInteger(POSITION_MAGIC) == magic)
         {
            ENUM_POSITION_TYPE ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
            if(ptype == POSITION_TYPE_BUY) buyCount++;
            else sellCount++;
            
            totalFloat += PositionGetDouble(POSITION_PROFIT) + 
                         PositionGetDouble(POSITION_SWAP) + 
                         PositionGetDouble(POSITION_COMMISSION);
         }
      }
   }
   
   int totalPos = buyCount + sellCount;
   
   QG_CreateRect("POS_CARD", cardX, y, cardW, qDash.posHeight, QG_CARD_BG);
   
   QG_CreateText("POS_LBL", cardX + pad, y + pad, 
                 "POSITIONS", QG_TEXT_SECONDARY, 8);
   
   QG_CreateText("POS_COUNT", cardX + cardW - pad, y + pad, 
                 IntegerToString(totalPos) + " OPEN", QG_TEXT_PRIMARY, 9, "Segoe UI Bold", ANCHOR_RIGHT_UPPER);
   
   DrawInfoRow("POS_BUY", cardX + pad, y + 30, cardW - 2*pad, 
               "BUY", IntegerToString(buyCount), QG_SUCCESS);
   DrawInfoRow("POS_SELL", cardX + pad, y + 50, cardW - 2*pad, 
               "SELL", IntegerToString(sellCount), QG_DANGER);
   
   color floatColor = (totalFloat >= 0) ? QG_SUCCESS : QG_DANGER;
   string floatStr = (totalFloat >= 0 ? "+" : "") + DoubleToString(totalFloat, 2);
   DrawInfoRow("POS_FLOAT", cardX + pad, y + 70, cardW - 2*pad, 
               "FLOAT P/L", floatStr, floatColor);
   
   qDash.currentY = y + qDash.posHeight + CARD_SPACING;
}

//+------------------------------------------------------------------+
//| DRAW ACCOUNT STATS                                                |
//+------------------------------------------------------------------+
void DrawAccountStats()
{
   int y = qDash.currentY;
   int pad = CARD_PADDING;
   int cardX = qDash.x + 5;
   int cardW = qDash.panelWidth - 5;
   
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   
   QG_CreateRect("ACC_CARD", cardX, y, cardW, qDash.accHeight, QG_CARD_BG);
   
   QG_CreateText("ACC_LBL", cardX + pad, y + pad, 
                 "ACCOUNT", QG_TEXT_SECONDARY, 8);
   
   DrawInfoRow("ACC_BAL", cardX + pad, y + 30, cardW - 2*pad, 
               "BALANCE", "$" + DoubleToString(balance, 2), QG_TEXT_PRIMARY);
   
   color eqColor = (equity >= balance) ? QG_SUCCESS : QG_DANGER;
   DrawInfoRow("ACC_EQ", cardX + pad, y + 50, cardW - 2*pad, 
               "EQUITY", "$" + DoubleToString(equity, 2), eqColor);
   
   color plColor = (dailyProfit >= 0) ? QG_SUCCESS : QG_DANGER;
   string plStr = (dailyProfit >= 0 ? "+" : "") + DoubleToString(dailyProfit, 2);
   DrawInfoRow("ACC_DAY", cardX + pad, y + 70, cardW - 2*pad, 
               "TODAY", plStr, plColor);
   
   double winRate = (totalWins + totalLosses > 0) ? 
                    totalWins * 100.0 / (totalWins + totalLosses) : 0.0;
   color wrColor = (winRate >= 50) ? QG_SUCCESS : QG_WARNING;
   DrawInfoRow("ACC_WR", cardX + pad, y + 90, cardW - 2*pad, 
               "WIN RATE", DoubleToString(winRate, 0) + "%", wrColor);
   
   qDash.currentY = y + qDash.accHeight + CARD_SPACING;
}

//+------------------------------------------------------------------+
//| DRAW CONTROL PANEL                                                |
//+------------------------------------------------------------------+
void DrawControlPanel()
{
   int y = qDash.currentY;
   int pad = CARD_PADDING;
   int cardX = qDash.x + 5;
   int cardW = qDash.panelWidth - 5;
   
   QG_CreateRect("CTRL_CARD", cardX, y, cardW, qDash.ctrlHeight, QG_CARD_BG);
   
   QG_CreateText("CTRL_LBL", cardX + pad, y + pad, 
                 "CONTROL PANEL", QG_TEXT_SECONDARY, 8);
   
   int btnW = (cardW - 3*pad) / 2;
   int btnH = 36;
   
   QG_CreateButton(BTN_CLOSE_PROFIT, cardX + pad, y + 30, btnW, btnH, 
                   "CLOSE PROFIT", QG_SUCCESS, QG_BG_DEEP, 10);
   
   QG_CreateButton(BTN_CLOSE_LOSS, cardX + pad*2 + btnW, y + 30, btnW, btnH, 
                   "CLOSE LOSS", QG_DANGER, QG_BG_DEEP, 10);
   
   string toggleText = tradingEnabled ? "PAUSE TRADING" : "RESUME TRADING";
   color toggleColor = tradingEnabled ? QG_WARNING : QG_SUCCESS;
   QG_CreateButton(BTN_TOGGLE_TRADE, cardX + pad, y + 75, cardW - 2*pad, btnH, 
                   toggleText, toggleColor, QG_BG_DEEP, 10);
   
   QG_CreateText("CTRL_STATUS", cardX + cardW/2, y + 120, 
                 qDash.statusMessage, QG_TEXT_DIM, 7, "Segoe UI", ANCHOR_CENTER);
   
   qDash.currentY = y + qDash.ctrlHeight;
}

//+------------------------------------------------------------------+
//| UPDATE DASHBOARD                                                  |
//+------------------------------------------------------------------+
void UpdateQuantumDashboard()
{
   if(!InpShowDashboard) return;
   
   datetime now = TimeCurrent();
   
   // Check for chart resize
   int currentWidth = (int)ChartGetInteger(0, CHART_WIDTH_IN_PIXELS);
   int currentHeight = (int)ChartGetInteger(0, CHART_HEIGHT_IN_PIXELS);
   
   if(currentWidth != qDash.chartWidth || currentHeight != qDash.chartHeight || 
      now - qDash.lastResize > 1)
   {
      CalculateDashboardDimensions();
      qDash.lastResize = now;
   }
   
   if(now == qDash.lastUpdate) return;
   qDash.lastUpdate = now;
   
   qDash.currentY = qDash.y;
   
   DrawQuantumHeader();
   DrawSignalPanel();
   DrawMarketMetrics();
   DrawLiquidityPanel();
   DrawPositionSummary();
   DrawAccountStats();
   DrawControlPanel();
   
   ChartRedraw(0);
}

//+------------------------------------------------------------------+
//| BUTTON HANDLERS                                                   |
//+------------------------------------------------------------------+
void HandleQuantumButtons(string clickedObject)
{
   if(clickedObject == DASH_PREFIX + BTN_CLOSE_PROFIT)
   {
      ObjectSetInteger(0, clickedObject, OBJPROP_STATE, false);
      
      int closed = 0;
      for(int i = PositionsTotal() - 1; i >= 0; i--)
      {
         ulong ticket = PositionGetTicket(i);
         if(ticket > 0 && PositionSelectByTicket(ticket))
         {
            if(PositionGetString(POSITION_SYMBOL) == _Symbol && 
               PositionGetInteger(POSITION_MAGIC) == magic)
            {
               double pl = PositionGetDouble(POSITION_PROFIT) + 
                          PositionGetDouble(POSITION_SWAP) + 
                          PositionGetDouble(POSITION_COMMISSION);
               
               if(pl > 0 && trade.PositionClose(ticket))
                  closed++;
            }
         }
      }
      
      qDash.statusMessage = "Closed " + IntegerToString(closed) + " profitable position(s)";
      Print("✅ CLOSE PROFIT: ", closed, " positions closed");
   }
   else if(clickedObject == DASH_PREFIX + BTN_CLOSE_LOSS)
   {
      ObjectSetInteger(0, clickedObject, OBJPROP_STATE, false);
      
      int closed = 0;
      for(int i = PositionsTotal() - 1; i >= 0; i--)
      {
         ulong ticket = PositionGetTicket(i);
         if(ticket > 0 && PositionSelectByTicket(ticket))
         {
            if(PositionGetString(POSITION_SYMBOL) == _Symbol && 
               PositionGetInteger(POSITION_MAGIC) == magic)
            {
               double pl = PositionGetDouble(POSITION_PROFIT) + 
                          PositionGetDouble(POSITION_SWAP) + 
                          PositionGetDouble(POSITION_COMMISSION);
               
               if(pl < 0 && trade.PositionClose(ticket))
                  closed++;
            }
         }
      }
      
      qDash.statusMessage = "Closed " + IntegerToString(closed) + " losing position(s)";
      Print("✅ CLOSE LOSS: ", closed, " positions closed");
   }
   else if(clickedObject == DASH_PREFIX + BTN_TOGGLE_TRADE)
   {
      ObjectSetInteger(0, clickedObject, OBJPROP_STATE, false);
      
      tradingEnabled = !tradingEnabled;
      qDash.statusMessage = tradingEnabled ? "Trading RESUMED" : "Trading PAUSED";
      Print(tradingEnabled ? "▶ Trading resumed" : "⏸ Trading paused");
   }
}

//+------------------------------------------------------------------+
//| LIQUIDITY INTELLIGENCE FUNCTIONS                                  |
//+------------------------------------------------------------------+
double CalculateAverageVolume(int lookback)
{
   long volumeArray[];
   ArraySetAsSeries(volumeArray, true);
   int copied = CopyTickVolume(_Symbol, InpAnalysisTF, 0, lookback, volumeArray);
   if(copied <= 0) return 0;
   
   double sum = 0;
   for(int i = 0; i < copied; i++)
      sum += (double)volumeArray[i];
   
   return sum / copied;
}

double CalculateMomentum(int period)
{
   double closeArray[];
   ArraySetAsSeries(closeArray, true);
   int copied = CopyClose(_Symbol, InpAnalysisTF, 0, period + 1, closeArray);
   if(copied <= period) return 0;
   
   return (closeArray[0] - closeArray[period]) / closeArray[period] * 100.0;
}

double CalculateAverageATR(int lookback)
{
   double atrArray[];
   ArraySetAsSeries(atrArray, true);
   if(CopyBuffer(handleATR, 0, 0, lookback, atrArray) <= 0)
      return GetCurrentATR();
   
   double sum = 0;
   for(int i = 0; i < lookback; i++)
      sum += atrArray[i];
   
   return sum / lookback;
}

VolatilityRegime ClassifyVolatilityRegime(double currentATR, double avgATR)
{
   if(avgATR <= 0) return VOL_NORMAL;
   double ratio = currentATR / avgATR;
   
   if(ratio < 0.3)       return VOL_DORMANT;
   else if(ratio < 0.7)  return VOL_LOW;
   else if(ratio < 1.3)  return VOL_NORMAL;
   else if(ratio < 2.0)  return VOL_HIGH;
   else                  return VOL_EXTREME;
}

MarketMomentum ClassifyMomentum(double momentum)
{
   if(momentum > 0.15)        return MOM_STRONG_BULL;
   else if(momentum > 0.05)   return MOM_WEAK_BULL;
   else if(momentum < -0.15)  return MOM_STRONG_BEAR;
   else if(momentum < -0.05)  return MOM_WEAK_BEAR;
   else                       return MOM_NEUTRAL;
}

double CalculateLiquidityScore()
{
   double score = 50.0;
   
   if(LiqIntel.volumeRatio > 1.5)       score += 30;
   else if(LiqIntel.volumeRatio > 1.2)  score += 20;
   else if(LiqIntel.volumeRatio > 0.9)  score += 10;
   else if(LiqIntel.volumeRatio < 0.5)  score -= 20;
   else if(LiqIntel.volumeRatio < 0.7)  score -= 10;
   
   if(LiqIntel.volRegime == VOL_NORMAL || LiqIntel.volRegime == VOL_HIGH)
      score += 20;
   else if(LiqIntel.volRegime == VOL_DORMANT || LiqIntel.volRegime == VOL_EXTREME)
      score -= 20;
   
   return MathMax(0, MathMin(100, score));
}

LiquidityState ClassifyLiquidity(double score)
{
   if(score >= 80)      return LIQ_VERY_HIGH;
   else if(score >= 60) return LIQ_HIGH;
   else if(score >= 40) return LIQ_NORMAL;
   else if(score >= 20) return LIQ_LOW;
   else                 return LIQ_VERY_LOW;
}

string LiquidityStateToString(LiquidityState state)
{
   switch(state)
   {
      case LIQ_VERY_LOW:   return "VERY LOW";
      case LIQ_LOW:        return "LOW";
      case LIQ_NORMAL:     return "NORMAL";
      case LIQ_HIGH:       return "HIGH";
      case LIQ_VERY_HIGH:  return "VERY HIGH";
      default:             return "UNKNOWN";
   }
}

color LiquidityStateColor(LiquidityState state)
{
   switch(state)
   {
      case LIQ_VERY_LOW:   return QG_DANGER;
      case LIQ_LOW:        return QG_WARNING;
      case LIQ_NORMAL:     return QG_TEXT_PRIMARY;
      case LIQ_HIGH:       return QG_SUCCESS;
      case LIQ_VERY_HIGH:  return QG_INFO;
      default:             return QG_TEXT_DIM;
   }
}

string MomentumToString(MarketMomentum momentum)
{
   switch(momentum)
   {
      case MOM_STRONG_BEAR: return "STRONG BEAR";
      case MOM_WEAK_BEAR:   return "WEAK BEAR";
      case MOM_NEUTRAL:     return "NEUTRAL";
      case MOM_WEAK_BULL:   return "WEAK BULL";
      case MOM_STRONG_BULL: return "STRONG BULL";
      default:              return "UNKNOWN";
   }
}

void UpdateLiquidityIntelligence()
{
   datetime now = TimeCurrent();
   if(now == LiqIntel.lastUpdate) return;
   
   LiqIntel.avgVolume = CalculateAverageVolume(InpVolumeLookback);
   long currentVol[];
   ArraySetAsSeries(currentVol, true);
   if(CopyTickVolume(_Symbol, InpAnalysisTF, 0, 1, currentVol) > 0)
      LiqIntel.currentVolume = (double)currentVol[0];
   else
      LiqIntel.currentVolume = LiqIntel.avgVolume;
   
   LiqIntel.volumeRatio = (LiqIntel.avgVolume > 0) ? LiqIntel.currentVolume / LiqIntel.avgVolume : 1.0;
   
   LiqIntel.momentum = CalculateMomentum(InpMomentumPeriod);
   LiqIntel.momentumState = ClassifyMomentum(LiqIntel.momentum);
   
   LiqIntel.currentATR = GetCurrentATR();
   LiqIntel.avgATR = CalculateAverageATR(InpATRPeriod * 2);
   LiqIntel.atrRatio = (LiqIntel.avgATR > 0) ? LiqIntel.currentATR / LiqIntel.avgATR : 1.0;
   LiqIntel.volRegime = ClassifyVolatilityRegime(LiqIntel.currentATR, LiqIntel.avgATR);
   
   LiqIntel.liquidityScore = CalculateLiquidityScore();
   LiqIntel.liquidityState = ClassifyLiquidity(LiqIntel.liquidityScore);
   
   LiqIntel.dynamicTPMultiplier = InpTPATRMult;
   LiqIntel.dynamicSLMultiplier = InpSLATRMult;
   
   switch(LiqIntel.volRegime)
   {
      case VOL_DORMANT:
         LiqIntel.dynamicTPMultiplier *= 0.6;
         break;
      case VOL_LOW:
         LiqIntel.dynamicTPMultiplier *= 0.8;
         break;
      case VOL_HIGH:
         LiqIntel.dynamicTPMultiplier *= 1.3;
         break;
      case VOL_EXTREME:
         LiqIntel.dynamicTPMultiplier *= 1.5;
         LiqIntel.dynamicSLMultiplier *= 1.2;
         break;
   }
   
   if(LiqIntel.momentumState == MOM_STRONG_BULL || LiqIntel.momentumState == MOM_STRONG_BEAR)
      LiqIntel.dynamicTPMultiplier *= 1.2;
   
   LiqIntel.recommendedRR = LiqIntel.dynamicTPMultiplier / LiqIntel.dynamicSLMultiplier;
   
   if(LiqIntel.recommendedRR < InpMinRiskRewardRatio)
   {
      LiqIntel.dynamicTPMultiplier = InpMinRiskRewardRatio * LiqIntel.dynamicSLMultiplier;
      LiqIntel.recommendedRR = InpMinRiskRewardRatio;
   }
   
   LiqIntel.allowLongEntry = true;
   LiqIntel.allowShortEntry = true;
   
   if(InpUseMomentumFilter && InpTradeWithTrend)
   {
      if(LiqIntel.momentumState == MOM_STRONG_BEAR || LiqIntel.momentumState == MOM_WEAK_BEAR)
         LiqIntel.allowLongEntry = false;
      
      if(LiqIntel.momentumState == MOM_STRONG_BULL || LiqIntel.momentumState == MOM_WEAK_BULL)
         LiqIntel.allowShortEntry = false;
   }
   
   LiqIntel.lotSizeMultiplier = 1.0;
   switch(LiqIntel.liquidityState)
   {
      case LIQ_VERY_LOW:   LiqIntel.lotSizeMultiplier = 0.3; break;
      case LIQ_LOW:        LiqIntel.lotSizeMultiplier = 0.6; break;
      case LIQ_NORMAL:     LiqIntel.lotSizeMultiplier = 1.0; break;
      case LIQ_HIGH:       LiqIntel.lotSizeMultiplier = 1.2; break;
      case LIQ_VERY_HIGH:  LiqIntel.lotSizeMultiplier = 1.4; break;
   }
   
   if(LiqIntel.volRegime == VOL_EXTREME)
      LiqIntel.lotSizeMultiplier *= 0.7;
   
   LiqIntel.lastUpdate = now;
}

//+------------------------------------------------------------------+
//| SESSION FILTER                                                    |
//+------------------------------------------------------------------+
bool IsSessionActive(int startH, int endH)
{
   MqlDateTime tm;
   TimeToStruct(TimeCurrent(), tm);
   int h = tm.hour;

   if(startH == endH) return true;
   if(startH < endH)
      return (h >= startH && h < endH);
   else
      return (h >= startH || h < endH);
}

bool IsTradingSessionAllowed()
{
   if(InpTradeAllSessions) return true;

   bool sydneyOK  = InpTradeSydneySession  && IsSessionActive(InpSydneyStartHour, InpSydneyEndHour);
   bool tokyoOK   = InpTradeTokyoSession   && IsSessionActive(InpTokyoStartHour, InpTokyoEndHour);
   bool londonOK  = InpTradeLondonSession  && IsSessionActive(InpLondonStartHour, InpLondonEndHour);
   bool newyorkOK = InpTradeNewYorkSession && IsSessionActive(InpNewYorkStartHour, InpNewYorkEndHour);

   return (sydneyOK || tokyoOK || londonOK || newyorkOK);
}

//+------------------------------------------------------------------+
//| CORE FUNCTIONS                                                    |
//+------------------------------------------------------------------+
double GetCurrentATR()
{
   datetime now = TimeCurrent();
   if(now == atrCacheTime && cachedATR > 0)
      return cachedATR;
   
   double atrBuffer[];
   ArraySetAsSeries(atrBuffer, true);
   
   if(CopyBuffer(handleATR, 0, 0, 1, atrBuffer) > 0)
   {
      cachedATR = atrBuffer[0];
      atrCacheTime = now;
      return cachedATR;
   }
   
   return cachedATR > 0 ? cachedATR : 0.0001;
}

double GetCurrentEMA()
{
   datetime now = TimeCurrent();
   if(now == emaCacheTime && cachedEMA > 0)
      return cachedEMA;

   double emaBuffer[];
   ArraySetAsSeries(emaBuffer, true);

   if(CopyBuffer(handleEMA, 0, 0, 1, emaBuffer) > 0)
   {
      cachedEMA = emaBuffer[0];
      emaCacheTime = now;
      return cachedEMA;
   }

   return cachedEMA;
}

double NormalizeVolume(double vol)
{
   double stepV = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   double minV = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxV = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);

   if(stepV <= 0) stepV = 0.01;
   double normalized = MathRound(vol / stepV) * stepV;
   normalized = MathMax(minV, MathMin(maxV, normalized));
   return NormalizeDouble(normalized, 2);
}

double CalculateLotSize(double slDistance)
{
   if(InpRiskPercent <= 0) 
      return NormalizeVolume(InpBaseLot);
   
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   double riskAmount = equity * InpRiskPercent / 100.0;
   riskAmount *= recentProfitFactor;
   
   double contractSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_CONTRACT_SIZE);
   double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   
   if(contractSize <= 0 || tickValue <= 0 || tickSize <= 0)
      return NormalizeVolume(InpBaseLot);
   
   double slInTicks = slDistance / tickSize;
   double riskPerLot = slInTicks * tickValue;
   
   if(riskPerLot <= 0)
      return NormalizeVolume(InpBaseLot);
   
   double lotSize = riskAmount / riskPerLot;
   
   double modeMult = (InpMode == Aggressive) ? 1.3 : (InpMode == Stealth) ? 0.7 : 1.0;
   lotSize *= modeMult;
   
   if(InpUseLiquidityFilter)
      lotSize *= LiqIntel.lotSizeMultiplier;
   
   return NormalizeVolume(lotSize);
}

double GetTotalExposure()
{
   double total = 0.0;
   
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket)) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol || PositionGetInteger(POSITION_MAGIC) != magic) continue;
      total += PositionGetDouble(POSITION_VOLUME);
   }
   
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      ulong ticket = OrderGetTicket(i);
      if(ticket == 0 || !OrderSelect(ticket)) continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol || OrderGetInteger(ORDER_MAGIC) != magic) continue;
      total += OrderGetDouble(ORDER_VOLUME_CURRENT);
   }
   
   return total;
}

bool IsOrderGenuinelyPending(ulong ticket)
{
   if(!OrderSelect(ticket)) return false;
   ENUM_ORDER_STATE state = (ENUM_ORDER_STATE)OrderGetInteger(ORDER_STATE);
   return (state == ORDER_STATE_PLACED || state == ORDER_STATE_STARTED);
}

int DeleteStaleOrders()
{
   if(!InpAutoRecycleStaleOrders) return 0;
   if(TimeCurrent() - lastFillTime < 2) return 0;

   datetime now = TimeCurrent();
   int deleted = 0;

   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      ulong ticket = OrderGetTicket(i);
      if(ticket == 0 || !OrderSelect(ticket)) continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol || OrderGetInteger(ORDER_MAGIC) != magic) continue;
      if(!IsOrderGenuinelyPending(ticket)) continue;

      datetime orderTime = (datetime)OrderGetInteger(ORDER_TIME_SETUP);
      int orderAge = (int)(now - orderTime);

      if(orderAge >= InpMaxOrderLifetimeSeconds)
      {
         if(trade.OrderDelete(ticket))
            deleted++;
      }
   }

   return deleted;
}

void DeployBidirectionalGrid()
{
   if(OrdersTotal() > 0)
   {
      DeleteStaleOrders();
      return;
   }
   
   if(!IsTradingSessionAllowed()) return;
   if(TimeCurrent() - lastGridDeployTime < 5) return;
   
   if(InpUseLiquidityFilter && LiqIntel.liquidityState == LIQ_VERY_LOW) return;
   if(InpUseLiquidityFilter && LiqIntel.volumeRatio < InpMinVolumeRatio) return;
   if(InpUseVolatilityAdaptation && LiqIntel.volRegime == VOL_DORMANT) return;
   
   double currentExposure = GetTotalExposure();
   if(currentExposure >= InpMaxTotalLots) return;
   
   MqlTick tick;
   if(!SymbolInfoTick(_Symbol, tick)) return;
   
   double atr = GetCurrentATR();
   if(atr <= 0) return;
   
   double currentPrice = (tick.bid + tick.ask) / 2.0;
   int digits = symbolDigits;
   
   long stopLevel = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   double minStopDist = stopLevel * symbolPoint;
   
   double slDist = MathMax(atr * LiqIntel.dynamicSLMultiplier, minStopDist * 1.5);
   double tpDist = atr * LiqIntel.dynamicTPMultiplier;
   
   double actualRR = tpDist / slDist;
   if(actualRR < InpMinRiskRewardRatio) return;
   
   double gridSpacing = atr * InpGridStepATR;
   double lot = CalculateLotSize(slDist);
   
   if(lot < SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN)) return;
   
   int buyOrdersPlaced = 0, sellOrdersPlaced = 0;
   
   if(!InpUseMomentumFilter || LiqIntel.allowLongEntry)
   {
      double firstBuyOffset = atr * InpMinOrderDistanceATR;
      
      for(int i = 0; i < InpOrdersPerSide; i++)
      {
         double entryPrice = currentPrice + firstBuyOffset + (i * gridSpacing);
         entryPrice = NormalizeDouble(entryPrice, digits);
         
         if(entryPrice <= tick.ask) continue;
         
         double sl = NormalizeDouble(entryPrice - slDist, digits);
         double tp = NormalizeDouble(entryPrice + tpDist, digits);
         
         if((entryPrice - sl) < minStopDist || (tp - entryPrice) < minStopDist) continue;
         
         string comment = StringFormat("QG_BUY_%d_RR%.1f", i+1, actualRR);
         
         if(trade.BuyStop(lot, entryPrice, _Symbol, sl, tp, ORDER_TIME_GTC, 0, comment))
            buyOrdersPlaced++;
      }
   }
   
   if(!InpUseMomentumFilter || LiqIntel.allowShortEntry)
   {
      double firstSellOffset = atr * InpMinOrderDistanceATR;
      
      for(int i = 0; i < InpOrdersPerSide; i++)
      {
         double entryPrice = currentPrice - firstSellOffset - (i * gridSpacing);
         entryPrice = NormalizeDouble(entryPrice, digits);
         
         if(entryPrice >= tick.bid) continue;
         
         double sl = NormalizeDouble(entryPrice + slDist, digits);
         double tp = NormalizeDouble(entryPrice - tpDist, digits);
         
         if((sl - entryPrice) < minStopDist || (entryPrice - tp) < minStopDist) continue;
         
         string comment = StringFormat("QG_SELL_%d_RR%.1f", i+1, actualRR);
         
         if(trade.SellStop(lot, entryPrice, _Symbol, sl, tp, ORDER_TIME_GTC, 0, comment))
            sellOrdersPlaced++;
      }
   }
   
   lastGridDeployTime = TimeCurrent();
   
   if(buyOrdersPlaced > 0 || sellOrdersPlaced > 0)
      Print("✅ GRID: ", buyOrdersPlaced, " BUY + ", sellOrdersPlaced, " SELL placed");
}

void ManageOCO()
{
   bool hasBuyPosition = false, hasSellPosition = false;
   
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket)) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol || PositionGetInteger(POSITION_MAGIC) != magic) continue;
      
      ENUM_POSITION_TYPE ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      if(ptype == POSITION_TYPE_BUY) 
         hasBuyPosition = true;
      else 
         hasSellPosition = true;
   }
   
   if(!hasBuyPosition && !hasSellPosition) return;
   
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      ulong ticket = OrderGetTicket(i);
      if(ticket == 0 || !OrderSelect(ticket)) continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol || OrderGetInteger(ORDER_MAGIC) != magic) continue;
      
      ENUM_ORDER_TYPE otype = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);

      bool isOppositeOfBuy  = hasBuyPosition  && (otype == ORDER_TYPE_SELL_STOP || otype == ORDER_TYPE_SELL_LIMIT);
      bool isOppositeOfSell = hasSellPosition && (otype == ORDER_TYPE_BUY_STOP  || otype == ORDER_TYPE_BUY_LIMIT);

      if((isOppositeOfBuy || isOppositeOfSell) && IsOrderGenuinelyPending(ticket))
         trade.OrderDelete(ticket);
   }
}

void ManageBalancedTargets()
{
   if(!InpUseDynamicTargets) return;
   
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket)) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol || PositionGetInteger(POSITION_MAGIC) != magic) continue;
      
      ENUM_POSITION_TYPE ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
      double curSL = PositionGetDouble(POSITION_SL);
      
      double slDistance = MathAbs(openPrice - curSL);
      if(slDistance <= 0) continue;
      
      double contractSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_CONTRACT_SIZE);
      double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
      double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
      double lot = PositionGetDouble(POSITION_VOLUME);
      
      double slInTicks = slDistance / tickSize;
      double slRiskDollars = slInTicks * tickValue * lot;
      
      double currentProfit = PositionGetDouble(POSITION_PROFIT) + 
                            PositionGetDouble(POSITION_SWAP) + 
                            PositionGetDouble(POSITION_COMMISSION);
      
      if(currentProfit >= (slRiskDollars * InpScalpTargetMultiplier))
      {
         if(trade.PositionClose(ticket))
         {
            scalpWins++;
            totalScalpProfit += currentProfit;
            Print("💰 BALANCED TARGET: +$", DoubleToString(currentProfit, 2), 
                  " (R:R 1:", DoubleToString(InpScalpTargetMultiplier, 1), ")");
         }
      }
   }
}

void ManagePositions()
{
   double atr = GetCurrentATR();
   if(atr <= 0) return;
   
   int digits = symbolDigits;
   long stopLvl = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   double minStopDist = stopLvl * symbolPoint;
   
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket)) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol || PositionGetInteger(POSITION_MAGIC) != magic) continue;
      
      ENUM_POSITION_TYPE ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
      double curSL = PositionGetDouble(POSITION_SL);
      double curTP = PositionGetDouble(POSITION_TP);
      
      double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      double curPrice = (ptype == POSITION_TYPE_BUY) ? bid : ask;
      double profitDist = (ptype == POSITION_TYPE_BUY) ? (curPrice - openPrice) : (openPrice - curPrice);
      
      double newSL = curSL;
      bool modify = false;
      
      if(InpUseBreakeven && profitDist >= InpBreakevenATR * atr)
      {
         double bePrice = (ptype == POSITION_TYPE_BUY) ? openPrice + InpBreakevenBufferPts * symbolPoint
                                                        : openPrice - InpBreakevenBufferPts * symbolPoint;
         if((ptype == POSITION_TYPE_BUY && (curSL == 0 || curSL < bePrice)) ||
            (ptype == POSITION_TYPE_SELL && (curSL == 0 || curSL > bePrice)))
         {
            newSL = bePrice;
            modify = true;
         }
      }
      
      if(InpUseTrailing && profitDist >= InpTrailStartATR * atr)
      {
         double trailPrice = (ptype == POSITION_TYPE_BUY) ? curPrice - InpTrailATR * atr
                                                           : curPrice + InpTrailATR * atr;
         if((ptype == POSITION_TYPE_BUY && trailPrice > newSL) ||
            (ptype == POSITION_TYPE_SELL && (newSL == 0 || trailPrice < newSL)))
         {
            newSL = trailPrice;
            modify = true;
         }
      }
      
      if(modify)
      {
         newSL = NormalizeDouble(newSL, digits);
         
         if(ptype == POSITION_TYPE_BUY && (bid - newSL) < minStopDist) continue;
         if(ptype == POSITION_TYPE_SELL && (newSL - ask) < minStopDist) continue;
         
         trade.PositionModify(ticket, newSL, curTP);
      }
   }
}

void CheckCircuitBreaker()
{
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   peakEquity = MathMax(peakEquity, equity);
   
   MqlDateTime tm;
   TimeToStruct(TimeCurrent(), tm);
   
   if(tm.day != lastDayChecked)
   {
      dayStartBalance = AccountInfoDouble(ACCOUNT_BALANCE);
      lastDayChecked = tm.day;
      tradingEnabled = true;
      
      grossProfit = 0.0;
      grossLoss = 0.0;
      totalWins = 0;
      totalLosses = 0;
      avgWinSize = 0.0;
      avgLossSize = 0.0;
      realizedRR = 0.0;
   }
   
   dailyProfit = equity - dayStartBalance;
   
   if(dailyProfit >= InpDailyProfitTarget)
      tradingEnabled = false;
   else if(dailyProfit <= -InpDailyLossLimit)
   {
      tradingEnabled = false;
      
      if(InpCloseAllOnLossLimit)
      {
         for(int i = PositionsTotal() - 1; i >= 0; i--)
         {
            ulong ticket = PositionGetTicket(i);
            if(ticket > 0 && PositionSelectByTicket(ticket))
               if(PositionGetString(POSITION_SYMBOL) == _Symbol && PositionGetInteger(POSITION_MAGIC) == magic)
                  trade.PositionClose(ticket);
         }
      }
   }
   
   if(grossLoss > 0)
      recentProfitFactor = grossProfit / grossLoss;
   else if(grossProfit > 0)
      recentProfitFactor = 1.5;
   else
      recentProfitFactor = 1.0;
   
   recentProfitFactor = MathMax(0.5, MathMin(recentProfitFactor, 2.0));
}

//+------------------------------------------------------------------+
//| EVENT HANDLERS                                                    |
//+------------------------------------------------------------------+
void OnTimer()
{
   UpdateLiquidityIntelligence();
   
   ManageOCO();
   ManageBalancedTargets();
   ManagePositions();
   CheckCircuitBreaker();
   
   if(tradingEnabled)
      DeployBidirectionalGrid();
   
   UpdateQuantumDashboard();
}

void OnTick()
{
   if(!InpUseTickDrivenMgmt) return;
   
   datetime now = TimeCurrent();
   if(now == lastTickManagement) return;
   lastTickManagement = now;
   
   ManageOCO();
   ManageBalancedTargets();
   ManagePositions();
}

void OnTradeTransaction(const MqlTradeTransaction &trans,
                         const MqlTradeRequest &request,
                         const MqlTradeResult &result)
{
   if(trans.type != TRADE_TRANSACTION_DEAL_ADD) return;
   
   ulong dealTicket = trans.deal;
   if(!HistoryDealSelect(dealTicket)) return;
   
   if(HistoryDealGetInteger(dealTicket, DEAL_MAGIC) != magic) return;
   if(HistoryDealGetString(dealTicket, DEAL_SYMBOL) != _Symbol) return;
   
   long entry = HistoryDealGetInteger(dealTicket, DEAL_ENTRY);
   
   if(entry == DEAL_ENTRY_IN)
   {
      lastFillTime = TimeCurrent();
      ManageOCO();
   }
   else if(entry == DEAL_ENTRY_OUT || entry == DEAL_ENTRY_OUT_BY)
   {
      double dealProfit = HistoryDealGetDouble(dealTicket, DEAL_PROFIT)
                         + HistoryDealGetDouble(dealTicket, DEAL_SWAP)
                         + HistoryDealGetDouble(dealTicket, DEAL_COMMISSION);
      
      if(dealProfit > 0)
      {
         totalWins++;
         grossProfit += dealProfit;
         avgWinSize = grossProfit / totalWins;
      }
      else if(dealProfit < 0)
      {
         totalLosses++;
         grossLoss += MathAbs(dealProfit);
         avgLossSize = grossLoss / totalLosses;
      }
      
      if(totalLosses > 0 && avgLossSize > 0)
         realizedRR = avgWinSize / avgLossSize;
      else if(totalWins > 0)
         realizedRR = 2.0;
   }
}

void OnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam)
{
   if(id == CHARTEVENT_CHART_CHANGE)
   {
      if(InpShowDashboard)
      {
         CalculateDashboardDimensions();
         UpdateQuantumDashboard();
      }
      return;
   }

   if(id == CHARTEVENT_OBJECT_CLICK)
   {
      HandleQuantumButtons(sparam);
      UpdateQuantumDashboard();
   }
}
//+------------------------------------------------------------------+