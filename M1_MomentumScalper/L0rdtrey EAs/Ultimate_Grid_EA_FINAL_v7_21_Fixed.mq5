#property strict
#property version   "7.00"
#property description "Ultimate Grid EA 7.00 - Institutional Multi-Grid Engine and Professional Command Center"

#include <Trade/Trade.mqh>
CTrade trade;

//--------------------------- ENUMS -----------------------------------
enum ENUM_GRID_TYPE
{
   BASIC_GRID = 0,
   HEDGE_GRID = 1,
   TREND_GRID = 2,
   VOLATILITY_GRID = 3,
   AI_GRID = 4,
   GEOMETRIC_GRID = 5,
   FIBONACCI_GRID = 6,
   ATR_ADAPTIVE_GRID = 7,
   MEAN_REVERSION_GRID = 8,
   BREAKOUT_GRID = 9,
   MOMENTUM_GRID = 10,
   HYBRID_GRID = 11,
   BULLISH_GRID = 12,
   BEARISH_GRID = 13,
   BIDIRECTIONAL_GRID = 14,
   LADDER_GRID = 15,
   ANTI_MARTINGALE_GRID = 16,
   RANGE_SCALING_GRID = 17,
   VOLATILITY_BREAKOUT_GRID = 18,
   SESSION_GRID = 19,
   SMART_REGIME_GRID = 20
};

enum ENUM_ENTRY_MODE
{
   MANUAL_ENTRY = 0,
   AUTO_ENTRY = 1,
   AI_ENTRY = 2,
   TIME_ENTRY = 3
};

enum ENUM_RISK_MODE
{
   CONSERVATIVE = 0,
   BALANCED = 1,
   AGGRESSIVE = 2,
   ADAPTIVE = 3
};

enum ENUM_REENTRY_MODE
{
   REENTRY_OFF = 0,
   REENTRY_ON_CLOSE = 1,
   REENTRY_ON_CENTER_SHIFT = 2,
   REENTRY_ON_REGIME_CHANGE = 3
};

enum ENUM_PANEL_THEME
{
   THEME_ONYX = 0,
   THEME_GOLD = 1,
   THEME_TEAL = 2
};

enum ENUM_CHART_THEME_MODE
{
   CHART_THEME_AUTO_REGIME = 0,
   CHART_THEME_DARK_LUXURY = 1,
   CHART_THEME_OCEAN = 2,
   CHART_THEME_EMERALD = 3,
   CHART_THEME_MONOCHROME = 4
};

//--------------------------- INPUTS ----------------------------------
input group "=== GRID ENGINE ==="
input ENUM_GRID_TYPE InpGridType = SMART_REGIME_GRID;
input ENUM_ENTRY_MODE InpEntryMode = AUTO_ENTRY;
input double InpLotSize = 0.01;
input double InpGridStep = 20.0;
input int InpGridLevels = 6;
input double InpLotMultiplier = 1.20;
input bool InpAutonomousMode = true;
input bool InpUseATRSpacing = true;
input double InpATRSpacingMultiplier = 0.80;
input double InpMinGridStepPips = 5.0;
input double InpMaxGridStepPips = 150.0;
input int InpRecenterATRPeriod = 14;
input double InpRecenterATRMultiple = 2.5;
input bool InpAutoRecenter = true;
input ENUM_REENTRY_MODE InpReentryMode = REENTRY_ON_CENTER_SHIFT;
input ulong InpMagicNumber = 123456;

input group "=== AI / REGIME ENGINE ==="
input bool InpEnableAI = true;
input bool InpNeuralNetwork = false;
input double InpAIConfidence = 0.75;
input int InpLearningPeriod = 100;
input bool InpRegimeFilter = true;
input double InpBullThreshold = 0.62;
input double InpBearThreshold = 0.38;
input double InpHighVolThreshold = 0.70;
input double InpLowVolThreshold = 0.30;

input group "=== RISK & BASKET MANAGEMENT ==="
input ENUM_RISK_MODE InpRiskMode = ADAPTIVE;
input bool InpUseDynamicRiskLot = true;
input double InpRiskPerGridPct = 0.50;
input double InpMaxGridRiskPct = 5.0;
input double InpMaxDrawdownPct = 5.0;
input double InpDailyLossLimitPct = 3.0;
input double InpDailyProfitLockPct = 5.0;
input double InpBasketTakeProfitUSD = 0.0;
input double InpBasketStopLossUSD = 0.0;
input double InpStopLossPips = 100.0;
input double InpTakeProfitPips = 50.0;
input bool InpUseBreakEven = true;
input double InpBreakEvenTriggerPips = 30.0;
input double InpBreakEvenOffsetPips = 2.0;
input bool InpTrailingStop = true;
input double InpTrailingATRMultiple = 1.5;
input double InpMaxHoldMinutes = 0.0;
input int InpMaxPositions = 20;
input int InpMaxPendingOrders = 30;
input bool InpOCO = true;
input bool InpCloseOppositePendingOnFill = true;

input group "=== EXECUTION ENGINE ==="
input int InpSlippage = 20;
input double InpMaxSpreadPips = 5.0;
input int InpPendingExpiryMinutes = 0;
input bool InpSmartExecution = true;
input bool InpValidateStops = true;
input bool InpDeleteInvalidLevels = true;
input int InpOrderRetryCount = 2;
input bool InpUseAsyncSafety = false;

input group "=== SESSION / MARKET FILTERS ==="
input bool InpUseSessionFilter = false;
input int InpSessionStartHour = 7;
input int InpSessionEndHour = 21;
input bool InpAvoidWeekend = true;
input bool InpPauseOnHighVolatility = false;

input group "=== DASHBOARD ==="
input bool InpShowDashboard = true;
input ENUM_PANEL_THEME InpDashboardTheme = THEME_GOLD;
input double InpDashboardWidthPct = 0.42;
input int InpDashboardMinWidth = 430;
input int InpDashboardMaxWidth = 640;
input int InpDashboardTopMargin = 25;

input group "=== AUTO CHART THEMING ==="
input bool InpAutoChartTheme = true;
input ENUM_CHART_THEME_MODE InpChartThemeMode = CHART_THEME_AUTO_REGIME;
input bool InpChartShowGrid = false;
input bool InpChartShowTradeLevels = true;
input bool InpChartAutoScroll = true;
input bool InpChartShift = true;
input bool InpChartShowVolumes = false;

//--------------------------- RUNTIME STATE ---------------------------
struct GridState
{
   ENUM_GRID_TYPE gridType;
   ENUM_ENTRY_MODE entryMode;
   ENUM_RISK_MODE riskMode;
   ENUM_REENTRY_MODE reentryMode;
   double lotSize;
   double gridStep;
   int gridLevels;
   double lotMultiplier;
   bool autonomousMode;
   bool useATRSpacing;
   double atrSpacingMultiplier;
   double minGridStep;
   double maxGridStep;
   double recenterATRMultiple;
   bool autoRecenter;
   bool aiEnabled;
   bool neuralNetwork;
   double aiConfidence;
   int learningPeriod;
   bool regimeFilter;
   double bullThreshold;
   double bearThreshold;
   double highVolThreshold;
   double lowVolThreshold;
   bool useDynamicRiskLot;
   double riskPerGridPct;
   double maxGridRiskPct;
   double maxDrawdownPct;
   double dailyLossLimitPct;
   double dailyProfitLockPct;
   double basketTakeProfitUSD;
   double basketStopLossUSD;
   double stopLossPips;
   double takeProfitPips;
   bool breakEven;
   double breakEvenTriggerPips;
   double breakEvenOffsetPips;
   bool trailingStop;
   double trailingATRMultiple;
   double maxHoldMinutes;
   int maxPositions;
   int maxPendingOrders;
   bool oco;
   bool closeOppositeOnFill;
   int slippage;
   double maxSpreadPips;
   int pendingExpiryMinutes;
   bool smartExecution;
   bool validateStops;
   int orderRetryCount;
   bool useSessionFilter;
   int sessionStartHour;
   int sessionEndHour;
   bool avoidWeekend;
   bool pauseHighVolatility;

   bool gridActive;
   datetime startTime;
   double initialEquity;
   double anchorPrice;
   double currentProfit;
   int positionCount;
   int pendingCount;
   int buyPositions;
   int sellPositions;
   int buyPending;
   int sellPending;
   int rejectedOrders;
   int acceptedOrders;
   int rebalances;
   int totalTrades;
   double winRate;
   int wins;
   int losses;
   double totalProfit;
   double maxDrawdown;
   double peakEquity;
   double todayProfit;
   double trendStrength;
   double volatilityIndex;
   double sentimentScore;
   double predictionAccuracy;
   double atrPrice;
   double currentSpreadPips;
   string regime;
   string executionStatus;
   datetime lastActionTime;
   datetime dayAnchor;
   int appliedChartTheme;
   bool autoChartTheme;
   ENUM_CHART_THEME_MODE chartThemeMode;
};
GridState g_state;

struct DashboardConfig
{
   int x,y,width,height;
   int currentTab;
   bool isVisible;
};
DashboardConfig g_dashboard;

struct EditField
{
   string name;
   string value;
   bool modified;
};
EditField g_editFields[100];
int g_editCount=0;

//--------------------------- CONSTANTS -------------------------------
const string PREFIX = "UG7_";
const int TAB_COUNT = 6;
const int GRID_TYPE_COUNT = 21;
const string TAB_NAMES[] = {"COMMAND","GRID LAB","ANALYTICS","RISK","EXECUTION","SETTINGS"};

color COLOR_BG;
color COLOR_PANEL;
color COLOR_PANEL2;
color COLOR_TEXT;
color COLOR_MUTED;
color COLOR_ACCENT;
color COLOR_GOLD;
color COLOR_GREEN;
color COLOR_RED;
color COLOR_ORANGE;
color COLOR_TEAL;

int g_atrHandle=INVALID_HANDLE;
int g_maHandle=INVALID_HANDLE;
int g_rsiHandle=INVALID_HANDLE;

//--------------------------- UTILITY FUNCTIONS -----------------------
double PipSize()
{
   int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   return (digits == 3 || digits == 5) ? point * 10.0 : point;
}

double NormalizeLots(double lots)
{
   double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   
   lots = MathMax(minLot, MathMin(maxLot, lots));
   if(step > 0) lots = MathRound(lots / step) * step;
   
   return NormalizeDouble(lots, 2);
}

bool IsGridOrder(ulong ticket, bool isPending = false)
{
   if(isPending)
   {
      if(!OrderSelect(ticket)) return false;
      return (OrderGetString(ORDER_SYMBOL) == _Symbol && 
              (ulong)OrderGetInteger(ORDER_MAGIC) == InpMagicNumber);
   }
   else
   {
      if(!PositionSelectByTicket(ticket)) return false;
      return (PositionGetString(POSITION_SYMBOL) == _Symbol && 
              (ulong)PositionGetInteger(POSITION_MAGIC) == InpMagicNumber);
   }
}

int GetPositionCount()
{
   int count = 0;
   for(int i = 0; i < PositionsTotal(); i++)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket > 0 && IsGridOrder(ticket, false)) count++;
   }
   return count;
}

int GetPendingCount()
{
   int count = 0;
   for(int i = 0; i < OrdersTotal(); i++)
   {
      ulong ticket = OrderGetTicket(i);
      if(ticket > 0 && IsGridOrder(ticket, true)) count++;
   }
   return count;
}

double GetGridProfit()
{
   double profit = 0.0;
   for(int i = 0; i < PositionsTotal(); i++)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket > 0 && IsGridOrder(ticket, false))
      {
         if(PositionSelectByTicket(ticket))
         {
            profit += PositionGetDouble(POSITION_PROFIT);
            profit += PositionGetDouble(POSITION_SWAP);
         }
      }
   }
   return profit;
}

string FormatNumber(double value)
{
   if(MathAbs(value) >= 1000000)
      return DoubleToString(value/1000000, 1) + "M";
   else if(MathAbs(value) >= 1000)
      return DoubleToString(value/1000, 1) + "K";
   return DoubleToString(value, 2);
}

//--------------------------- EDIT FIELD MANAGEMENT -------------------
void StoreEditValue(string name, string value)
{
   for(int i = 0; i < g_editCount; i++)
   {
      if(g_editFields[i].name == name)
      {
         g_editFields[i].value = value;
         g_editFields[i].modified = true;
         return;
      }
   }
   
   if(g_editCount < 50)
   {
      g_editFields[g_editCount].name = name;
      g_editFields[g_editCount].value = value;
      g_editFields[g_editCount].modified = true;
      g_editCount++;
   }
}

string GetEditValue(string name, string defaultValue = "")
{
   for(int i = 0; i < g_editCount; i++)
   {
      if(g_editFields[i].name == name)
         return g_editFields[i].value;
   }
   return defaultValue;
}

//--------------------------- UI FUNCTIONS -----------------------------
string ObjName(string suffix) 
{ 
   return PREFIX + suffix; 
}

void CreateLabel(string name, string text, int x, int y, int w = 200, int h = 20, 
                int fontSize = 9, color clr = clrWhite)
{
   if(ObjectFind(0, name) < 0)
      ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
   
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, fontSize);
   ObjectSetString(0, name, OBJPROP_FONT, "Arial");
   ObjectSetString(0, name, OBJPROP_TEXT, text);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
}

void CreatePanel(string name, int x, int y, int w, int h, color bg = clrNONE, color border = clrNONE)
{
   if(bg == clrNONE) bg = COLOR_PANEL;
   if(border == clrNONE) border = COLOR_ACCENT;
   
   if(ObjectFind(0, name) < 0)
      ObjectCreate(0, name, OBJ_RECTANGLE_LABEL, 0, 0, 0);
   
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, name, OBJPROP_XSIZE, w);
   ObjectSetInteger(0, name, OBJPROP_YSIZE, h);
   ObjectSetInteger(0, name, OBJPROP_BGCOLOR, bg);
   ObjectSetInteger(0, name, OBJPROP_BORDER_COLOR, border);
   ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
}

void CreateEdit(string name, string value, int x, int y, int w = 100, int h = 20)
{
   string storedValue = GetEditValue(name, value);
   if(storedValue != "") value = storedValue;
   
   if(ObjectFind(0, name) < 0)
      ObjectCreate(0, name, OBJ_EDIT, 0, 0, 0);
   
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, name, OBJPROP_XSIZE, w);
   ObjectSetInteger(0, name, OBJPROP_YSIZE, h);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, 8);
   ObjectSetString(0, name, OBJPROP_FONT, "Arial");
   ObjectSetString(0, name, OBJPROP_TEXT, value);
   ObjectSetInteger(0, name, OBJPROP_COLOR, COLOR_TEXT);
   ObjectSetInteger(0, name, OBJPROP_BGCOLOR, COLOR_BG);
   ObjectSetInteger(0, name, OBJPROP_BORDER_COLOR, COLOR_ACCENT);
   ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
   ObjectSetInteger(0, name, OBJPROP_READONLY, false);
}

void CreateButton(string name, string text, int x, int y, int w, int h, 
                 color bg = clrNONE, bool pressed = false)
{
   if(bg == clrNONE) bg = pressed ? COLOR_ACCENT : COLOR_PANEL;
   
   if(ObjectFind(0, name) < 0)
      ObjectCreate(0, name, OBJ_BUTTON, 0, 0, 0);
   
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, name, OBJPROP_XSIZE, w);
   ObjectSetInteger(0, name, OBJPROP_YSIZE, h);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, 8);
   ObjectSetString(0, name, OBJPROP_FONT, "Arial Bold");
   ObjectSetString(0, name, OBJPROP_TEXT, text);
   ObjectSetInteger(0, name, OBJPROP_COLOR, COLOR_TEXT);
   ObjectSetInteger(0, name, OBJPROP_BGCOLOR, bg);
   ObjectSetInteger(0, name, OBJPROP_BORDER_COLOR, COLOR_ACCENT);
   ObjectSetInteger(0, name, OBJPROP_STATE, false);
   ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
}

//--------------------------- AI & ANALYTICS ---------------------------
double CalculateTrendStrength()
{
   if(g_maHandle == INVALID_HANDLE) return 0.5;
   
   double ma[];
   ArraySetAsSeries(ma, true);
   if(CopyBuffer(g_maHandle, 0, 0, 10, ma) < 10) return 0.5;
   
   double trendScore = 0.0;
   for(int i = 1; i < 10; i++)
   {
      if(ma[i-1] > ma[i]) trendScore += 0.1;
      else trendScore -= 0.1;
   }
   
   return MathMax(0.0, MathMin(1.0, (trendScore + 1.0) / 2.0));
}

double CalculateVolatility()
{
   if(g_atrHandle == INVALID_HANDLE) return 0.5;
   
   double atr[];
   ArraySetAsSeries(atr, true);
   if(CopyBuffer(g_atrHandle, 0, 0, 5, atr) < 5) return 0.5;
   
   double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(currentPrice <= 0) return 0.5;
   
   double volatility = atr[0] / currentPrice * 1000.0;
   return MathMax(0.0, MathMin(1.0, volatility));
}

double CalculateSentiment()
{
   if(g_rsiHandle == INVALID_HANDLE) return 0.5;
   
   double rsi[];
   ArraySetAsSeries(rsi, true);
   if(CopyBuffer(g_rsiHandle, 0, 0, 1, rsi) < 1) return 0.5;
   
   return rsi[0] / 100.0;
}

//--------------------------- GRID MANAGEMENT --------------------------
string GetGridTypeName(ENUM_GRID_TYPE type)
{
   switch(type)
   {
      case BASIC_GRID: return "Basic Grid";
      case HEDGE_GRID: return "Hedge Grid";
      case TREND_GRID: return "Trend Grid";
      case VOLATILITY_GRID: return "Volatility Grid";
      case AI_GRID: return "AI Grid";
      case GEOMETRIC_GRID: return "Geometric Grid";
      case FIBONACCI_GRID: return "Fibonacci Grid";
      case ATR_ADAPTIVE_GRID: return "ATR Adaptive Grid";
      case MEAN_REVERSION_GRID: return "Mean-Reversion Grid";
      case BREAKOUT_GRID: return "Breakout Grid";
      case MOMENTUM_GRID: return "Momentum Grid";
      case HYBRID_GRID: return "Hybrid Smart Grid";
      case BULLISH_GRID: return "Bullish Grid";
      case BEARISH_GRID: return "Bearish Grid";
      case BIDIRECTIONAL_GRID: return "Bidirectional Grid";
      case LADDER_GRID: return "Ladder Grid";
      case ANTI_MARTINGALE_GRID: return "Anti-Martingale Grid";
      case RANGE_SCALING_GRID: return "Range-Scaling Grid";
      case VOLATILITY_BREAKOUT_GRID: return "Volatility-Breakout Grid";
      case SESSION_GRID: return "Session Grid";
      case SMART_REGIME_GRID: return "Smart-Regime Grid";
   }
   return "Unknown Grid";
}

void CreateGrid()
{
   if(g_state.gridActive) return;
   
   MqlTick tick;
   if(!SymbolInfoTick(_Symbol, tick)) return;
   
   double basePrice = (tick.ask + tick.bid) / 2.0;
   double spacing = g_state.gridStep * PipSize();
   if(g_state.useATRSpacing && g_state.atrPrice > 0.0)
      spacing = MathMax(g_state.minGridStep * PipSize(), MathMin(g_state.maxGridStep * PipSize(), g_state.atrPrice * g_state.atrSpacingMultiplier));
   
   trade.SetExpertMagicNumber(InpMagicNumber);
   
   switch(g_state.gridType)
   {
      case BASIC_GRID:
         CreateBasicGrid(basePrice, spacing);
         break;
      case HEDGE_GRID:
         CreateHedgeGrid(basePrice, spacing);
         break;
      case TREND_GRID:
         CreateTrendGrid(basePrice, spacing);
         break;
      case VOLATILITY_GRID:
         CreateVolatilityGrid(basePrice, spacing);
         break;
      case AI_GRID:
         CreateAIGrid(basePrice, spacing);
         break;
      case GEOMETRIC_GRID:
         CreateGeometricGrid(basePrice, spacing);
         break;
      case FIBONACCI_GRID:
         CreateFibonacciGrid(basePrice, spacing);
         break;
      case ATR_ADAPTIVE_GRID:
         CreateATRAdaptiveGrid(basePrice, spacing);
         break;
      case MEAN_REVERSION_GRID:
         CreateMeanReversionGrid(basePrice, spacing);
         break;
      case BREAKOUT_GRID:
         CreateBreakoutGrid(basePrice, spacing);
         break;
      case MOMENTUM_GRID:
         CreateMomentumGrid(basePrice, spacing);
         break;
      case HYBRID_GRID:
         CreateHybridGrid(basePrice, spacing);
         break;
      case BULLISH_GRID:
         CreateBullishGrid(basePrice, spacing);
         break;
      case BEARISH_GRID:
         CreateBearishGrid(basePrice, spacing);
         break;
      case BIDIRECTIONAL_GRID:
         CreateBidirectionalGrid(basePrice, spacing);
         break;
      case LADDER_GRID:
         CreateLadderGrid(basePrice, spacing);
         break;
      case ANTI_MARTINGALE_GRID:
         CreateAntiMartingaleGrid(basePrice, spacing);
         break;
      case RANGE_SCALING_GRID:
         CreateRangeScalingGrid(basePrice, spacing);
         break;
      case VOLATILITY_BREAKOUT_GRID:
         CreateVolatilityBreakoutGrid(basePrice, spacing);
         break;
      case SESSION_GRID:
         CreateSessionGrid(basePrice, spacing);
         break;
      case SMART_REGIME_GRID:
         CreateSmartRegimeGrid(basePrice, spacing);
         break;
   }
   
   // Only mark the grid active when at least one order/position was actually created.
   g_state.positionCount = GetPositionCount();
   g_state.pendingCount = GetPendingCount();
   if(g_state.positionCount == 0 && g_state.pendingCount == 0)
   {
      g_state.gridActive = false;
      Print("Grid creation produced no accepted orders: ", GetGridTypeName(g_state.gridType));
      return;
   }

   g_state.gridActive = true;
   g_state.startTime = TimeCurrent();
   g_state.initialEquity = AccountInfoDouble(ACCOUNT_EQUITY);
   g_state.anchorPrice = basePrice;
   g_state.executionStatus = "GRID ACTIVE";
   
   Print("Grid created: ", EnumToString(g_state.gridType));
}

void CreateBasicGrid(double basePrice, double spacing)
{
   for(int i = 1; i <= g_state.gridLevels; i++)
   {
      double buyPrice = NormalizeDouble(basePrice + spacing * i, _Digits);
      double sellPrice = NormalizeDouble(basePrice - spacing * i, _Digits);
      double lotSize = NormalizeLots(g_state.lotSize * MathPow(g_state.lotMultiplier, i-1));
      
      PlaceGridOrder(ORDER_TYPE_BUY_STOP, buyPrice, lotSize);
      PlaceGridOrder(ORDER_TYPE_SELL_STOP, sellPrice, lotSize);
   }
}

void CreateHedgeGrid(double basePrice, double spacing)
{
   // Initial hedge positions
   double initialLot = NormalizeLots(g_state.lotSize);
   trade.Buy(initialLot, _Symbol, 0, 0, 0, "Hedge Buy");
   trade.Sell(initialLot, _Symbol, 0, 0, 0, "Hedge Sell");
   
   // Grid orders
   for(int i = 1; i <= g_state.gridLevels; i++)
   {
      double buyPrice = NormalizeDouble(basePrice + spacing * i, _Digits);
      double sellPrice = NormalizeDouble(basePrice - spacing * i, _Digits);
      double lotSize = NormalizeLots(initialLot * MathPow(g_state.lotMultiplier, i));
      
      PlaceGridOrder(ORDER_TYPE_BUY_STOP, buyPrice, lotSize);
      PlaceGridOrder(ORDER_TYPE_SELL_STOP, sellPrice, lotSize);
   }
}

void CreateTrendGrid(double basePrice, double spacing)
{
   double trend = CalculateTrendStrength();
   double lotSize = NormalizeLots(g_state.lotSize);
   
   if(trend > 0.6) // Bullish
   {
      trade.Buy(lotSize, _Symbol, 0, 0, 0, "Trend Buy");
      for(int i = 1; i <= g_state.gridLevels; i++)
      {
         double price = NormalizeDouble(basePrice + spacing * i, _Digits);
         PlaceGridOrder(ORDER_TYPE_BUY_STOP, price, lotSize);
      }
   }
   else if(trend < 0.4) // Bearish
   {
      trade.Sell(lotSize, _Symbol, 0, 0, 0, "Trend Sell");
      for(int i = 1; i <= g_state.gridLevels; i++)
      {
         double price = NormalizeDouble(basePrice - spacing * i, _Digits);
         PlaceGridOrder(ORDER_TYPE_SELL_STOP, price, lotSize);
      }
   }
}

void CreateVolatilityGrid(double basePrice, double spacing)
{
   double volatility = CalculateVolatility();
   spacing *= (1.0 + volatility);
   
   for(int i = 1; i <= g_state.gridLevels; i++)
   {
      double buyPrice = NormalizeDouble(basePrice + spacing * i, _Digits);
      double sellPrice = NormalizeDouble(basePrice - spacing * i, _Digits);
      double lotSize = NormalizeLots(g_state.lotSize * (1.0 + volatility * 0.5));
      
      PlaceGridOrder(ORDER_TYPE_BUY_STOP, buyPrice, lotSize);
      PlaceGridOrder(ORDER_TYPE_SELL_STOP, sellPrice, lotSize);
   }
}

void CreateAIGrid(double basePrice, double spacing)
{
   if(!g_state.aiEnabled)
   {
      CreateBasicGrid(basePrice, spacing);
      return;
   }
   
   double trend = CalculateTrendStrength();
   double volatility = CalculateVolatility();
   double sentiment = CalculateSentiment();
   
   // AI-optimized spacing and lot sizing
   spacing *= (1.0 + volatility * 0.5);
   int levels = (int)(g_state.gridLevels * (1.0 + trend * 0.3));
   levels = MathMax(3, MathMin(10, levels));
   
   for(int i = 1; i <= levels; i++)
   {
      double buyPrice = NormalizeDouble(basePrice + spacing * i, _Digits);
      double sellPrice = NormalizeDouble(basePrice - spacing * i, _Digits);
      double lotSize = NormalizeLots(g_state.lotSize * (1.0 + sentiment * 0.2));
      
      PlaceGridOrder(ORDER_TYPE_BUY_STOP, buyPrice, lotSize);
      PlaceGridOrder(ORDER_TYPE_SELL_STOP, sellPrice, lotSize);
   }
}

double GetCurrentATRPrice()
{
   if(g_atrHandle == INVALID_HANDLE) return 0.0;
   double atr[];
   ArraySetAsSeries(atr, true);
   if(CopyBuffer(g_atrHandle, 0, 0, 1, atr) < 1) return 0.0;
   return MathMax(atr[0], SymbolInfoDouble(_Symbol, SYMBOL_POINT) * 2.0);
}

void CreateGeometricGrid(double basePrice, double spacing)
{
   double ratio = MathMax(1.05, g_state.lotMultiplier);
   for(int i=1; i<=g_state.gridLevels; i++)
   {
      double distance = spacing * MathPow(ratio, i-1);
      double lot = NormalizeLots(g_state.lotSize);
      PlaceGridOrder(ORDER_TYPE_BUY_STOP, NormalizeDouble(basePrice + distance, _Digits), lot);
      PlaceGridOrder(ORDER_TYPE_SELL_STOP, NormalizeDouble(basePrice - distance, _Digits), lot);
   }
}

void CreateFibonacciGrid(double basePrice, double spacing)
{
   double fib[] = {0.236,0.382,0.500,0.618,0.786,1.000,1.272,1.618};
   int count = MathMin(g_state.gridLevels, ArraySize(fib));
   for(int i=0; i<count; i++)
   {
      double distance = spacing * fib[i];
      double lot = NormalizeLots(g_state.lotSize * (1.0 + fib[i]*0.10));
      PlaceGridOrder(ORDER_TYPE_BUY_STOP, NormalizeDouble(basePrice + distance, _Digits), lot);
      PlaceGridOrder(ORDER_TYPE_SELL_STOP, NormalizeDouble(basePrice - distance, _Digits), lot);
   }
}

void CreateATRAdaptiveGrid(double basePrice, double spacing)
{
   double atrPrice = GetCurrentATRPrice();
   if(atrPrice <= 0.0) { CreateVolatilityGrid(basePrice, spacing); return; }
   double adaptiveSpacing = MathMax(spacing, atrPrice);
   double volatility = CalculateVolatility();
   for(int i=1; i<=g_state.gridLevels; i++)
   {
      double distance = adaptiveSpacing * i;
      double lot = NormalizeLots(g_state.lotSize * MathMax(0.50,1.0-volatility*0.40));
      PlaceGridOrder(ORDER_TYPE_BUY_STOP, NormalizeDouble(basePrice + distance, _Digits), lot);
      PlaceGridOrder(ORDER_TYPE_SELL_STOP, NormalizeDouble(basePrice - distance, _Digits), lot);
   }
}

void CreateMeanReversionGrid(double basePrice, double spacing)
{
   for(int i=1; i<=g_state.gridLevels; i++)
   {
      double distance = spacing*i;
      double lot = NormalizeLots(g_state.lotSize);
      PlaceGridOrder(ORDER_TYPE_BUY_LIMIT, NormalizeDouble(basePrice - distance, _Digits), lot);
      PlaceGridOrder(ORDER_TYPE_SELL_LIMIT, NormalizeDouble(basePrice + distance, _Digits), lot);
   }
}

void CreateBreakoutGrid(double basePrice, double spacing)
{
   double atrPrice = GetCurrentATRPrice();
   double d0 = MathMax(spacing, atrPrice > 0.0 ? atrPrice*0.75 : spacing);
   for(int i=1; i<=g_state.gridLevels; i++)
   {
      double distance=d0*i;
      double lot=NormalizeLots(g_state.lotSize*(1.0+0.05*(i-1)));
      PlaceGridOrder(ORDER_TYPE_BUY_STOP, NormalizeDouble(basePrice+distance,_Digits), lot);
      PlaceGridOrder(ORDER_TYPE_SELL_STOP, NormalizeDouble(basePrice-distance,_Digits), lot);
   }
}

void CreateMomentumGrid(double basePrice, double spacing)
{
   double trend=CalculateTrendStrength();
   double lot=NormalizeLots(g_state.lotSize);
   if(trend>=0.60)
   {
      for(int i=1;i<=g_state.gridLevels;i++)
         PlaceGridOrder(ORDER_TYPE_BUY_STOP, NormalizeDouble(basePrice+spacing*i,_Digits), lot);
   }
   else if(trend<=0.40)
   {
      for(int i=1;i<=g_state.gridLevels;i++)
         PlaceGridOrder(ORDER_TYPE_SELL_STOP, NormalizeDouble(basePrice-spacing*i,_Digits), lot);
   }
   else
      CreateBreakoutGrid(basePrice, spacing);
}

void CreateHybridGrid(double basePrice, double spacing)
{
   double trend=CalculateTrendStrength();
   double volatility=CalculateVolatility();
   double atr=GetCurrentATRPrice();
   double hybridSpacing=spacing;
   if(atr>0.0) hybridSpacing=MathMax(spacing,atr*(0.75+volatility*0.75));

   if(trend>0.65)
   {
      for(int i=1;i<=g_state.gridLevels;i++)
      {
         double lot=NormalizeLots(g_state.lotSize*MathMax(0.50,1.0-volatility*0.30));
         PlaceGridOrder(ORDER_TYPE_BUY_STOP, NormalizeDouble(basePrice+hybridSpacing*i,_Digits), lot);
      }
   }
   else if(trend<0.35)
   {
      for(int i=1;i<=g_state.gridLevels;i++)
      {
         double lot=NormalizeLots(g_state.lotSize*MathMax(0.50,1.0-volatility*0.30));
         PlaceGridOrder(ORDER_TYPE_SELL_STOP, NormalizeDouble(basePrice-hybridSpacing*i,_Digits), lot);
      }
   }
   else if(volatility<0.35)
      CreateMeanReversionGrid(basePrice, hybridSpacing);
   else
      CreateBreakoutGrid(basePrice, hybridSpacing);
}

void CreateBullishGrid(double basePrice, double spacing)
{
   double trend = CalculateTrendStrength();
   if(trend < 0.55) return;
   double atr = GetCurrentATRPrice();
   double step = MathMax(spacing, atr > 0.0 ? atr * 0.65 : spacing);
   double lot = NormalizeLots(g_state.lotSize * MathMax(0.50, 1.0 - CalculateVolatility() * 0.35));
   for(int i=1;i<=g_state.gridLevels;i++)
   {
      double buyStop = NormalizeDouble(basePrice + step*i, _Digits);
      PlaceGridOrder(ORDER_TYPE_BUY_STOP, buyStop, lot);
      if(i <= MathMax(1,g_state.gridLevels/2))
      {
         double buyLimit = NormalizeDouble(basePrice - step*(0.35*i), _Digits);
         PlaceGridOrder(ORDER_TYPE_BUY_LIMIT, buyLimit, lot);
      }
   }
}

void CreateBearishGrid(double basePrice, double spacing)
{
   double trend = CalculateTrendStrength();
   if(trend > 0.45) return;
   double atr = GetCurrentATRPrice();
   double step = MathMax(spacing, atr > 0.0 ? atr * 0.65 : spacing);
   double lot = NormalizeLots(g_state.lotSize * MathMax(0.50, 1.0 - CalculateVolatility() * 0.35));
   for(int i=1;i<=g_state.gridLevels;i++)
   {
      double sellStop = NormalizeDouble(basePrice - step*i, _Digits);
      PlaceGridOrder(ORDER_TYPE_SELL_STOP, sellStop, lot);
      if(i <= MathMax(1,g_state.gridLevels/2))
      {
         double sellLimit = NormalizeDouble(basePrice + step*(0.35*i), _Digits);
         PlaceGridOrder(ORDER_TYPE_SELL_LIMIT, sellLimit, lot);
      }
   }
}

void CreateBidirectionalGrid(double basePrice, double spacing)
{
   double atr = GetCurrentATRPrice();
   double step = MathMax(spacing, atr > 0.0 ? atr * 0.70 : spacing);
   double vol = CalculateVolatility();
   double lot = NormalizeLots(g_state.lotSize * MathMax(0.45, 1.0-vol*0.45));
   for(int i=1;i<=g_state.gridLevels;i++)
   {
      PlaceGridOrder(ORDER_TYPE_BUY_STOP, NormalizeDouble(basePrice+step*i,_Digits), lot);
      PlaceGridOrder(ORDER_TYPE_SELL_STOP, NormalizeDouble(basePrice-step*i,_Digits), lot);
   }
}

void CreateLadderGrid(double basePrice, double spacing)
{
   // Unequal but monotonic steps create a ladder that gets wider with depth.
   for(int i=1;i<=g_state.gridLevels;i++)
   {
      double distance = spacing * (i + 0.5*i*(i-1)/MathMax(1,g_state.gridLevels));
      double lot = NormalizeLots(g_state.lotSize * (1.0 - 0.25*(double)(i-1)/MathMax(1,g_state.gridLevels)));
      PlaceGridOrder(ORDER_TYPE_BUY_STOP, NormalizeDouble(basePrice+distance,_Digits), lot);
      PlaceGridOrder(ORDER_TYPE_SELL_STOP, NormalizeDouble(basePrice-distance,_Digits), lot);
   }
}

void CreateAntiMartingaleGrid(double basePrice, double spacing)
{
   double winBias = 1.0;
   if(g_state.predictionAccuracy > 0.60) winBias = 1.0 + MathMin(0.50, (g_state.predictionAccuracy-0.60)*1.5);
   double vol = CalculateVolatility();
   for(int i=1;i<=g_state.gridLevels;i++)
   {
      double progression = MathPow(1.0 + 0.08*winBias, i-1);
      double lot = NormalizeLots(g_state.lotSize * progression * MathMax(0.50,1.0-vol*0.35));
      PlaceGridOrder(ORDER_TYPE_BUY_STOP, NormalizeDouble(basePrice+spacing*i,_Digits), lot);
      PlaceGridOrder(ORDER_TYPE_SELL_STOP, NormalizeDouble(basePrice-spacing*i,_Digits), lot);
   }
}

void CreateRangeScalingGrid(double basePrice, double spacing)
{
   double trend = CalculateTrendStrength();
   if(trend > 0.58 || trend < 0.42)
   {
      CreateHybridGrid(basePrice, spacing);
      return;
   }
   double atr = GetCurrentATRPrice();
   double step = MathMax(spacing, atr>0 ? atr*0.50 : spacing);
   for(int i=1;i<=g_state.gridLevels;i++)
   {
      double scale = 1.0 + 0.20*(i-1);
      double distance = step*i*scale;
      double lot = NormalizeLots(g_state.lotSize * MathMax(0.50,1.0-0.08*(i-1)));
      PlaceGridOrder(ORDER_TYPE_BUY_LIMIT, NormalizeDouble(basePrice-distance,_Digits), lot);
      PlaceGridOrder(ORDER_TYPE_SELL_LIMIT, NormalizeDouble(basePrice+distance,_Digits), lot);
   }
}

void CreateVolatilityBreakoutGrid(double basePrice, double spacing)
{
   double atr = GetCurrentATRPrice();
   if(atr <= 0.0) { CreateBreakoutGrid(basePrice, spacing); return; }
   double step = MathMax(spacing, atr);
   double vol = CalculateVolatility();
   int levels = MathMax(2, g_state.gridLevels);
   for(int i=1;i<=levels;i++)
   {
      double distance = step * (0.75 + 0.35*(i-1));
      double lot = NormalizeLots(g_state.lotSize * MathMax(0.40,1.0-vol*0.50));
      PlaceGridOrder(ORDER_TYPE_BUY_STOP, NormalizeDouble(basePrice+distance,_Digits), lot);
      PlaceGridOrder(ORDER_TYPE_SELL_STOP, NormalizeDouble(basePrice-distance,_Digits), lot);
   }
}

int CurrentServerHour()
{
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(),dt);
   return dt.hour;
}

void CreateSessionGrid(double basePrice, double spacing)
{
   int h = CurrentServerHour();
   // Session intensity proxy: Asian = compact, London = medium, New York/overlap = wider.
   double factor = 0.75;
   if(h >= 7 && h < 13) factor = 1.00;
   else if(h >= 13 && h < 18) factor = 1.20;
   else if(h >= 18 && h < 22) factor = 1.05;
   double step = spacing * factor;
   CreateBidirectionalGrid(basePrice, step);
}

void CreateSmartRegimeGrid(double basePrice, double spacing)
{
   double trend = CalculateTrendStrength();
   double vol = CalculateVolatility();
   double sentiment = CalculateSentiment();
   if(trend >= 0.68 && sentiment >= 0.55)
      CreateBullishGrid(basePrice, spacing);
   else if(trend <= 0.32 && sentiment <= 0.45)
      CreateBearishGrid(basePrice, spacing);
   else if(vol >= 0.70)
      CreateVolatilityBreakoutGrid(basePrice, spacing);
   else if(trend >= 0.45 && trend <= 0.55)
      CreateRangeScalingGrid(basePrice, spacing);
   else
      CreateBidirectionalGrid(basePrice, spacing);
}


//--------------------------- AUTO CHART THEMING ------------------------
color ThemeBackground(int theme)
{
   if(theme==1) return C'10,12,16';
   if(theme==2) return C'8,18,28';
   if(theme==3) return C'8,24,20';
   if(theme==4) return C'18,18,18';
   return C'10,12,16';
}

color ThemeForeground(int theme)
{
   if(theme==4) return C'220,220,220';
   return C'225,230,235';
}

color ThemeGrid(int theme)
{
   if(theme==2) return C'25,55,70';
   if(theme==3) return C'25,65,55';
   if(theme==4) return C'45,45,45';
   return C'30,34,40';
}

color ThemeUp(int theme)
{
   if(theme==2) return C'85,210,235';
   if(theme==3) return C'70,220,150';
   if(theme==4) return C'225,225,225';
   return clrLimeGreen;
}

color ThemeDown(int theme)
{
   if(theme==2) return C'255,120,110';
   if(theme==3) return C'255,105,105';
   if(theme==4) return C'155,155,155';
   return clrTomato;
}

color ThemeVolume(int theme)
{
   if(theme==2) return C'75,150,180';
   if(theme==3) return C'70,160,125';
   if(theme==4) return C'120,120,120';
   return C'90,95,105';
}

color ThemeLine(int theme)
{
   if(theme==2) return C'80,180,220';
   if(theme==3) return C'80,210,160';
   if(theme==4) return C'200,200,200';
   return C'220,185,70';
}

int DetectAutomaticChartTheme()
{
   // Regime-aware mapping:
   // bullish -> emerald, bearish -> dark luxury, high-volatility -> ocean,
   // range -> monochrome, transitional -> dark luxury.
   if(g_state.volatilityIndex >= g_state.highVolThreshold)
      return 2;
   if(g_state.trendStrength >= g_state.bullThreshold && g_state.sentimentScore >= 0.55)
      return 3;
   if(g_state.trendStrength <= g_state.bearThreshold && g_state.sentimentScore <= 0.45)
      return 1;
   if(g_state.trendStrength >= 0.45 && g_state.trendStrength <= 0.55)
      return 4;
   return 1;
}

string ChartThemeName(int theme)
{
   switch(theme)
   {
      case 1: return "Dark Luxury";
      case 2: return "Ocean Momentum";
      case 3: return "Emerald Bull";
      case 4: return "Monochrome Range";
   }
   return "Dark Luxury";
}

void ApplyChartTheme(bool force=false)
{
   if(!g_state.autoChartTheme && !force) return;

   int targetTheme = (int)g_state.chartThemeMode;
   if(g_state.chartThemeMode==CHART_THEME_AUTO_REGIME)
      targetTheme = DetectAutomaticChartTheme();

   if(!force && g_state.appliedChartTheme==targetTheme)
   {
      ChartSetInteger(0,CHART_SHOW_GRID,InpChartShowGrid);
      ChartSetInteger(0,CHART_SHOW_TRADE_LEVELS,InpChartShowTradeLevels);
      ChartSetInteger(0,CHART_AUTOSCROLL,InpChartAutoScroll);
      ChartSetInteger(0,CHART_SHIFT,InpChartShift);
      ChartRedraw();
      return;
   }

   int chartTheme=targetTheme;
   ChartSetInteger(0,CHART_MODE,CHART_CANDLES);
   ChartSetInteger(0,CHART_COLOR_BACKGROUND,ThemeBackground(chartTheme));
   ChartSetInteger(0,CHART_COLOR_FOREGROUND,ThemeForeground(chartTheme));
   ChartSetInteger(0,CHART_COLOR_GRID,ThemeGrid(chartTheme));
   ChartSetInteger(0,CHART_COLOR_CHART_UP,ThemeUp(chartTheme));
   ChartSetInteger(0,CHART_COLOR_CHART_DOWN,ThemeDown(chartTheme));
   ChartSetInteger(0,CHART_COLOR_CANDLE_BULL,ThemeUp(chartTheme));
   ChartSetInteger(0,CHART_COLOR_CANDLE_BEAR,ThemeDown(chartTheme));
   ChartSetInteger(0,CHART_COLOR_VOLUME,ThemeVolume(chartTheme));
   ChartSetInteger(0,CHART_COLOR_BID,clrDeepSkyBlue);
   ChartSetInteger(0,CHART_COLOR_ASK,clrOrange);
   ChartSetInteger(0,CHART_COLOR_LAST,ThemeLine(chartTheme));
   ChartSetInteger(0,CHART_COLOR_STOP_LEVEL,clrTomato);
   ChartSetInteger(0,CHART_SHOW_GRID,InpChartShowGrid);
   ChartSetInteger(0,CHART_SHOW_TRADE_LEVELS,InpChartShowTradeLevels);
   ChartSetInteger(0,CHART_AUTOSCROLL,InpChartAutoScroll);
   ChartSetInteger(0,CHART_SHIFT,InpChartShift);
   ChartSetInteger(0,CHART_SHOW_VOLUMES,(InpChartShowVolumes ? CHART_VOLUME_TICK : CHART_VOLUME_HIDE));

   g_state.appliedChartTheme=chartTheme;
   g_state.executionStatus=StringFormat("CHART THEME: %s",ChartThemeName(chartTheme));
   ChartRedraw();
}

//--------------------------- ADVANCED DASHBOARD -----------------------
string GridShortName(ENUM_GRID_TYPE type)
{
   return StringFormat("%02d  %s",(int)type+1,GetGridTypeName(type));
}

void ApplyTheme()
{
   if(InpDashboardTheme==THEME_GOLD)
   {
      COLOR_BG=clrBlack; COLOR_PANEL=clrDarkSlateGray; COLOR_PANEL2=clrDimGray;
      COLOR_TEXT=clrWhite; COLOR_MUTED=clrSilver; COLOR_ACCENT=clrDeepSkyBlue;
      COLOR_GOLD=clrGold; COLOR_GREEN=clrLimeGreen; COLOR_RED=clrTomato; COLOR_ORANGE=clrOrange; COLOR_TEAL=clrAqua;
   }
   else if(InpDashboardTheme==THEME_TEAL)
   {
      COLOR_BG=clrBlack; COLOR_PANEL=clrDarkSlateGray; COLOR_PANEL2=clrTeal;
      COLOR_TEXT=clrWhite; COLOR_MUTED=clrSilver; COLOR_ACCENT=clrAqua;
      COLOR_GOLD=clrGold; COLOR_GREEN=clrLimeGreen; COLOR_RED=clrTomato; COLOR_ORANGE=clrOrange; COLOR_TEAL=clrAqua;
   }
   else
   {
      COLOR_BG=clrBlack; COLOR_PANEL=clrDarkSlateGray; COLOR_PANEL2=clrGray;
      COLOR_TEXT=clrWhite; COLOR_MUTED=clrSilver; COLOR_ACCENT=clrDodgerBlue;
      COLOR_GOLD=clrLightSteelBlue; COLOR_GREEN=clrLimeGreen; COLOR_RED=clrTomato; COLOR_ORANGE=clrOrange; COLOR_TEAL=clrAqua;
   }
}

void InitializeDashboard()
{
   g_dashboard.x=12; g_dashboard.y=InpDashboardTopMargin; g_dashboard.currentTab=0; g_dashboard.isVisible=InpShowDashboard;
   ApplyTheme();
}

void FitDashboard()
{
   int cw=(int)ChartGetInteger(0,CHART_WIDTH_IN_PIXELS);
   int ch=(int)ChartGetInteger(0,CHART_HEIGHT_IN_PIXELS);
   int target=(int)(cw*InpDashboardWidthPct);
   target=MathMax(InpDashboardMinWidth,target);
   target=MathMin(InpDashboardMaxWidth,target);
   target=MathMin(target,MathMax(320,cw-20));
   g_dashboard.width=target;
   g_dashboard.height=MathMax(500,ch-g_dashboard.y-20);
   g_dashboard.height=MathMin(g_dashboard.height,ch-35);
   if(g_dashboard.x+g_dashboard.width>cw-8) g_dashboard.x=MathMax(8,cw-g_dashboard.width-8);
   if(g_dashboard.y+g_dashboard.height>ch-8) g_dashboard.y=MathMax(8,ch-g_dashboard.height-8);
}

void SetText(string name,string text,color clr=clrWhite)
{
   if(ObjectFind(0,name)<0) return;
   ObjectSetString(0,name,OBJPROP_TEXT,text);
   ObjectSetInteger(0,name,OBJPROP_COLOR,clr);
}

void CreateText(string name,string text,int x,int y,int size,color clr=clrWhite,string font="Arial")
{
   if(ObjectFind(0,name)<0) ObjectCreate(0,name,OBJ_LABEL,0,0,0);
   ObjectSetInteger(0,name,OBJPROP_XDISTANCE,x); ObjectSetInteger(0,name,OBJPROP_YDISTANCE,y);
   ObjectSetInteger(0,name,OBJPROP_FONTSIZE,size); ObjectSetString(0,name,OBJPROP_FONT,font);
   ObjectSetString(0,name,OBJPROP_TEXT,text); ObjectSetInteger(0,name,OBJPROP_COLOR,clr);
   ObjectSetInteger(0,name,OBJPROP_CORNER,CORNER_LEFT_UPPER); ObjectSetInteger(0,name,OBJPROP_SELECTABLE,false); ObjectSetInteger(0,name,OBJPROP_HIDDEN,true);
}

void CreateRect(string name,int x,int y,int w,int h,color bg,color border)
{
   if(ObjectFind(0,name)<0) ObjectCreate(0,name,OBJ_RECTANGLE_LABEL,0,0,0);
   ObjectSetInteger(0,name,OBJPROP_XDISTANCE,x); ObjectSetInteger(0,name,OBJPROP_YDISTANCE,y);
   ObjectSetInteger(0,name,OBJPROP_XSIZE,w); ObjectSetInteger(0,name,OBJPROP_YSIZE,h);
   ObjectSetInteger(0,name,OBJPROP_BGCOLOR,bg); ObjectSetInteger(0,name,OBJPROP_BORDER_COLOR,border);
   ObjectSetInteger(0,name,OBJPROP_CORNER,CORNER_LEFT_UPPER); ObjectSetInteger(0,name,OBJPROP_SELECTABLE,false); ObjectSetInteger(0,name,OBJPROP_HIDDEN,true);
}

void CreateBtn(string name,string text,int x,int y,int w,int h,color bg,bool state=false,int fs=8)
{
   if(ObjectFind(0,name)<0) ObjectCreate(0,name,OBJ_BUTTON,0,0,0);
   ObjectSetInteger(0,name,OBJPROP_XDISTANCE,x); ObjectSetInteger(0,name,OBJPROP_YDISTANCE,y);
   ObjectSetInteger(0,name,OBJPROP_XSIZE,w); ObjectSetInteger(0,name,OBJPROP_YSIZE,h);
   ObjectSetInteger(0,name,OBJPROP_FONTSIZE,fs); ObjectSetString(0,name,OBJPROP_FONT,"Arial Bold");
   ObjectSetString(0,name,OBJPROP_TEXT,text); ObjectSetInteger(0,name,OBJPROP_COLOR,COLOR_TEXT);
   ObjectSetInteger(0,name,OBJPROP_BGCOLOR,bg); ObjectSetInteger(0,name,OBJPROP_BORDER_COLOR,state?COLOR_GOLD:COLOR_ACCENT);
   ObjectSetInteger(0,name,OBJPROP_STATE,state); ObjectSetInteger(0,name,OBJPROP_CORNER,CORNER_LEFT_UPPER); ObjectSetInteger(0,name,OBJPROP_HIDDEN,true);
}

void CreateInput(string name,string value,int x,int y,int w)
{
   string sv=GetEditValue(name,value); if(sv!="") value=sv;
   if(ObjectFind(0,name)<0) ObjectCreate(0,name,OBJ_EDIT,0,0,0);
   ObjectSetInteger(0,name,OBJPROP_XDISTANCE,x); ObjectSetInteger(0,name,OBJPROP_YDISTANCE,y);
   ObjectSetInteger(0,name,OBJPROP_XSIZE,w); ObjectSetInteger(0,name,OBJPROP_YSIZE,20);
   ObjectSetInteger(0,name,OBJPROP_FONTSIZE,8); ObjectSetString(0,name,OBJPROP_FONT,"Arial");
   ObjectSetString(0,name,OBJPROP_TEXT,value); ObjectSetInteger(0,name,OBJPROP_COLOR,COLOR_TEXT);
   ObjectSetInteger(0,name,OBJPROP_BGCOLOR,COLOR_BG); ObjectSetInteger(0,name,OBJPROP_BORDER_COLOR,COLOR_ACCENT);
   ObjectSetInteger(0,name,OBJPROP_CORNER,CORNER_LEFT_UPPER); ObjectSetInteger(0,name,OBJPROP_HIDDEN,true);
}

void DashboardHeader()
{
   int x=g_dashboard.x,y=g_dashboard.y,w=g_dashboard.width;
   CreateRect(ObjName("BG"),x,y,w,g_dashboard.height,COLOR_BG,COLOR_ACCENT);
   CreateRect(ObjName("HEAD"),x,y,w,62,COLOR_PANEL,COLOR_GOLD);
   CreateText(ObjName("TITLE"),"ULTIMATE GRID EA  •  COMMAND CENTER",x+16,y+9,13,COLOR_GOLD,"Arial Bold");
   CreateText(ObjName("SUB"),StringFormat("%s  |  Regime: %s  |  ATR %.2f",GridShortName(g_state.gridType),g_state.regime,g_state.atrPrice),x+16,y+32,8,COLOR_MUTED);
   string stat=g_state.gridActive?"● LIVE":"○ STANDBY"; color sc=g_state.gridActive?COLOR_GREEN:COLOR_MUTED;
   CreateText(ObjName("STAT"),stat,x+w-90,y+22,9,sc,"Arial Bold");
}

void DashboardTabs()
{
   int x=g_dashboard.x+8,y=g_dashboard.y+68,w=g_dashboard.width-16;
   int tw=MathMax(70,(w-25)/TAB_COUNT);
   for(int i=0;i<TAB_COUNT;i++) CreateBtn(ObjName("TAB_"+IntegerToString(i)),TAB_NAMES[i],x+i*tw,y,tw-3,26,i==g_dashboard.currentTab?COLOR_ACCENT:COLOR_PANEL,i==g_dashboard.currentTab,7);
}

void MetricCard(string id,string title,string value,int x,int y,int w,int h,color valueColor)
{
   CreateRect(ObjName(id+"_P"),x,y,w,h,COLOR_PANEL,COLOR_ACCENT);
   CreateText(ObjName(id+"_T"),title,x+9,y+7,7,COLOR_MUTED,"Arial Bold");
   CreateText(ObjName(id+"_V"),value,x+9,y+24,11,valueColor,"Arial Bold");
}

void CreateCommandTab()
{
   int x=g_dashboard.x+10,y=g_dashboard.y+102,w=g_dashboard.width-20;
   int gap=7,cw=(w-gap*3)/4;
   MetricCard("EQ","EQUITY",FormatNumber(AccountInfoDouble(ACCOUNT_EQUITY)),x,y,cw,52,COLOR_TEXT);
   MetricCard("PL","GRID P/L",FormatNumber(g_state.currentProfit),x+cw+gap,y,cw,52,g_state.currentProfit>=0?COLOR_GREEN:COLOR_RED);
   MetricCard("POS","POSITIONS",IntegerToString(g_state.positionCount),x+(cw+gap)*2,y,cw,52,COLOR_ACCENT);
   MetricCard("PEN","PENDING",IntegerToString(g_state.pendingCount),x+(cw+gap)*3,y,cw,52,COLOR_GOLD);
   y+=60;
   CreateRect(ObjName("MODE_P"),x,y,w,78,COLOR_PANEL,COLOR_GOLD);
   CreateText(ObjName("MODE_T"),"ACTIVE GRID ENGINE",x+10,y+8,7,COLOR_MUTED,"Arial Bold");
   CreateText(ObjName("MODE_V"),GridShortName(g_state.gridType),x+10,y+25,12,COLOR_GOLD,"Arial Bold");
   CreateText(ObjName("MODE_S"),StringFormat("Anchor %.*f   |   Step %.*f pips   |   Levels %d",_Digits,g_state.anchorPrice,1,g_state.gridStep,g_state.gridLevels),x+10,y+50,8,COLOR_TEXT);
   y+=86;
   // Primary grid controls
   int bw=(w-18)/3;
   CreateBtn(ObjName("BTN_START"),"▶ START GRID",x,y,bw,34,COLOR_GREEN,false,8);
   CreateBtn(ObjName("BTN_STOP"),"■ CLOSE GRID",x+bw+9,y,bw,34,COLOR_RED,false,8);
   CreateBtn(ObjName("BTN_REBAL"),"↻ RECENTER",x+(bw+9)*2,y,bw,34,COLOR_ACCENT,false,8);
   y+=42;

   // Dedicated trade/order management controls
   CreateRect(ObjName("MANAGE_P"),x,y,w,70,COLOR_PANEL,COLOR_GOLD);
   CreateText(ObjName("MANAGE_T"),"TRADE & ORDER MANAGEMENT",x+10,y+7,8,COLOR_GOLD,"Arial Bold");
   int mbw=(w-24)/3;
   CreateBtn(ObjName("BTN_CLOSE_PROFIT"),"✓ CLOSE PROFIT",x+8,y+27,mbw,32,COLOR_GREEN,false,8);
   CreateBtn(ObjName("BTN_CLOSE_LOSS"),"✕ CLOSE LOSS",x+16+mbw,y+27,mbw,32,COLOR_RED,false,8);
   CreateBtn(ObjName("BTN_CANCEL_ORDERS"),"■ CANCEL ORDERS",x+24+mbw*2,y+27,mbw,32,COLOR_GOLD,false,8);
   y+=78;
   CreateRect(ObjName("HEALTH_P"),x,y,w,118,COLOR_PANEL,COLOR_ACCENT);
   CreateText(ObjName("HEALTH_T"),"LIVE SYSTEM HEALTH",x+10,y+8,8,COLOR_GOLD,"Arial Bold");
   CreateText(ObjName("H1"),StringFormat("Spread  %.2f pips    •    Trend %.0f%%    •    Volatility %.0f%%",g_state.currentSpreadPips,g_state.trendStrength*100,g_state.volatilityIndex*100),x+10,y+30,8,COLOR_TEXT);
   CreateText(ObjName("H2"),StringFormat("Buy pos %d   Sell pos %d   Buy pend %d   Sell pend %d",g_state.buyPositions,g_state.sellPositions,g_state.buyPending,g_state.sellPending),x+10,y+50,8,COLOR_TEXT);
   CreateText(ObjName("H3"),StringFormat("Daily P/L %s   •   Max DD %.2f%%   •   Wins %d / Losses %d",FormatNumber(g_state.todayProfit),g_state.maxDrawdown,g_state.wins,g_state.losses),x+10,y+70,8,COLOR_TEXT);
   CreateText(ObjName("H4"),StringFormat("Execution: %s   •   Accepted %d   •   Rejected %d",g_state.executionStatus,g_state.acceptedOrders,g_state.rejectedOrders),x+10,y+90,8,COLOR_TEXT);
   CreateText(ObjName("H5"),StringFormat("Chart Theme: %s   •   Mode: %s",ChartThemeName(g_state.appliedChartTheme),g_state.autoChartTheme?"AUTO":"MANUAL"),x+10,y+110,8,COLOR_MUTED);
}

void CreateGridLabTab()
{
   int x=g_dashboard.x+10,y=g_dashboard.y+102,w=g_dashboard.width-20;
   CreateRect(ObjName("GLAB"),x,y,w,62,COLOR_PANEL,COLOR_GOLD);
   CreateText(ObjName("GLAB_T"),"21-MODE GRID LAB",x+10,y+8,8,COLOR_GOLD,"Arial Bold");
   CreateText(ObjName("GLAB_S"),"Choose the exact grid. The selected mode is used for the next grid build.",x+10,y+28,8,COLOR_MUTED);
   CreateText(ObjName("GLAB_A"),"ACTIVE: ["+IntegerToString((int)g_state.gridType+1)+"/21]  "+GetGridTypeName(g_state.gridType),x+10,y+45,9,COLOR_TEXT,"Arial Bold");
   y+=69;
   int cols=3,gap=6,bw=(w-gap*(cols-1))/cols,bh=31;
   for(int i=0;i<GRID_TYPE_COUNT;i++)
   {
      int row=i/cols,col=i%cols;
      int by=y+row*(bh+5);
      color bc=(i==(int)g_state.gridType)?COLOR_ACCENT:COLOR_PANEL;
      CreateBtn(ObjName("GRID_SEL_"+IntegerToString(i)),GridShortName((ENUM_GRID_TYPE)i),x+col*(bw+gap),by,bw,bh,bc,i==(int)g_state.gridType,7);
   }
   y+=7*(bh+5)+2;
   CreateBtn(ObjName("BTN_AUTO"),g_state.autonomousMode?"AUTONOMOUS: ON":"AUTONOMOUS: OFF",x,y,bw,27,g_state.autonomousMode?COLOR_GREEN:COLOR_PANEL,g_state.autonomousMode,7);
   CreateBtn(ObjName("BTN_AI_TOGGLE"),g_state.aiEnabled?"AI FILTER: ON":"AI FILTER: OFF",x+bw+gap,y,bw,27,g_state.aiEnabled?COLOR_GREEN:COLOR_PANEL,g_state.aiEnabled,7);
   CreateBtn(ObjName("BTN_GRID_REBUILD"),"REBUILD GRID",x+(bw+gap)*2,y,bw,27,COLOR_GOLD,false,7);
}

void CreateAnalyticsTab()
{
   int x=g_dashboard.x+10,y=g_dashboard.y+102,w=g_dashboard.width-20;
   CreateRect(ObjName("AN1"),x,y,w,120,COLOR_PANEL,COLOR_ACCENT);
   CreateText(ObjName("ANT"),"MARKET REGIME ENGINE",x+10,y+8,8,COLOR_GOLD,"Arial Bold");
   CreateText(ObjName("ANR"),"REGIME  "+g_state.regime,x+10,y+28,12,COLOR_GOLD,"Arial Bold");
   CreateText(ObjName("AN1T"),StringFormat("Trend %.1f%%    Volatility %.1f%%    RSI/Sentiment %.1f%%",g_state.trendStrength*100,g_state.volatilityIndex*100,g_state.sentimentScore*100),x+10,y+52,8,COLOR_TEXT);
   CreateText(ObjName("AN2T"),StringFormat("ATR %.*f    Spread %.2f pips    Prediction %.1f%%",_Digits,g_state.atrPrice,g_state.currentSpreadPips,g_state.predictionAccuracy*100),x+10,y+72,8,COLOR_TEXT);
   CreateText(ObjName("AN3T"),StringFormat("Grid age %s    Rebalances %d    Trades %d",g_state.startTime>0?IntegerToString((int)((TimeCurrent()-g_state.startTime)/60))+"m":"--",g_state.rebalances,g_state.totalTrades),x+10,y+92,8,COLOR_MUTED);
   y+=128;
   CreateRect(ObjName("AN2"),x,y,w,118,COLOR_PANEL,COLOR_ACCENT);
   CreateText(ObjName("ANT2"),"DIRECTIONAL PRESSURE",x+10,y+8,8,COLOR_GOLD,"Arial Bold");
   CreateText(ObjName("BUY"),StringFormat("BULLISH BIAS     %.0f%%",g_state.trendStrength*100),x+10,y+35,9,COLOR_GREEN,"Arial Bold");
   CreateText(ObjName("SELL"),StringFormat("BEARISH BIAS     %.0f%%",(1.0-g_state.trendStrength)*100),x+10,y+58,9,COLOR_RED,"Arial Bold");
   CreateText(ObjName("SENT"),StringFormat("Sentiment       %.0f%%",g_state.sentimentScore*100),x+10,y+81,8,COLOR_TEXT);
   y+=126;
   CreateBtn(ObjName("BTN_AI_RESET"),"RESET LEARNING METRICS",x,y,w,28,COLOR_RED,false,7);
}

void CreateRiskTab()
{
   int x=g_dashboard.x+10,y=g_dashboard.y+102,w=g_dashboard.width-20;
   CreateRect(ObjName("RK1"),x,y,w,145,COLOR_PANEL,COLOR_ACCENT);
   CreateText(ObjName("RKT"),"RISK COMMAND",x+10,y+8,8,COLOR_GOLD,"Arial Bold");
   string rm=(g_state.riskMode==CONSERVATIVE?"CONSERVATIVE":g_state.riskMode==BALANCED?"BALANCED":g_state.riskMode==AGGRESSIVE?"AGGRESSIVE":"ADAPTIVE");
   CreateBtn(ObjName("BTN_RISK_MODE"),"RISK PROFILE  •  "+rm,x+10,y+30,w-20,26,COLOR_ACCENT,false,7);
   CreateText(ObjName("RK2"),StringFormat("Grid risk %.2f%%    •    Max drawdown %.2f%%",g_state.riskPerGridPct,g_state.maxDrawdown),x+10,y+67,8,COLOR_TEXT);
   CreateText(ObjName("RK3"),StringFormat("Daily P/L %s    •    Limit %.2f%%    •    Lock %.2f%%",FormatNumber(g_state.todayProfit),g_state.dailyLossLimitPct,g_state.dailyProfitLockPct),x+10,y+88,8,COLOR_TEXT);
   CreateText(ObjName("RK4"),StringFormat("Basket TP %s    •    Basket SL %s",FormatNumber(g_state.basketTakeProfitUSD),FormatNumber(g_state.basketStopLossUSD)),x+10,y+109,8,COLOR_TEXT);
   string tr=g_state.trailingStop?"TRAILING ON":"TRAILING OFF";
   CreateBtn(ObjName("BTN_TRAILING"),tr,x+10,y+121,w-20,20,g_state.trailingStop?COLOR_GREEN:COLOR_PANEL,g_state.trailingStop,7);
   y+=153;
   CreateRect(ObjName("RK5"),x,y,w,100,COLOR_PANEL,COLOR_ACCENT);
   CreateText(ObjName("RK5T"),"PROTECTION STATUS",x+10,y+8,8,COLOR_GOLD,"Arial Bold");
   CreateText(ObjName("RK5A"),StringFormat("Break-even: %s  •  OCO: %s",g_state.breakEven?"ON":"OFF",g_state.oco?"ON":"OFF"),x+10,y+32,8,COLOR_TEXT);
   CreateText(ObjName("RK5B"),StringFormat("Max positions %d  •  Max pending %d",g_state.maxPositions,g_state.maxPendingOrders),x+10,y+53,8,COLOR_TEXT);
   CreateText(ObjName("RK5C"),StringFormat("Max hold %.0f min  •  Risk lot %s",g_state.maxHoldMinutes,g_state.useDynamicRiskLot?"ON":"OFF"),x+10,y+74,8,COLOR_TEXT);
}

void CreateExecutionTab()
{
   int x=g_dashboard.x+10,y=g_dashboard.y+102,w=g_dashboard.width-20;
   CreateRect(ObjName("EX1"),x,y,w,130,COLOR_PANEL,COLOR_ACCENT);
   CreateText(ObjName("EXT"),"EXECUTION & BROKER HEALTH",x+10,y+8,8,COLOR_GOLD,"Arial Bold");
   CreateText(ObjName("EXA"),StringFormat("Spread %.2f / max %.2f pips",g_state.currentSpreadPips,g_state.maxSpreadPips),x+10,y+32,8,g_state.currentSpreadPips<=g_state.maxSpreadPips?COLOR_GREEN:COLOR_RED);
   CreateText(ObjName("EXB"),StringFormat("Slippage %d pts    •    Smart execution %s",g_state.slippage,g_state.smartExecution?"ON":"OFF"),x+10,y+52,8,COLOR_TEXT);
   CreateText(ObjName("EXC"),StringFormat("Accepted %d    •    Rejected %d    •    Retries %d",g_state.acceptedOrders,g_state.rejectedOrders,g_state.orderRetryCount),x+10,y+72,8,COLOR_TEXT);
   CreateText(ObjName("EXD"),StringFormat("Validation %s    •    Pending expiry %d min",g_state.validateStops?"ON":"OFF",g_state.pendingExpiryMinutes),x+10,y+92,8,COLOR_TEXT);
   CreateText(ObjName("EXE"),StringFormat("Session %s    •    Weekend %s",g_state.useSessionFilter?"FILTERED":"OPEN",g_state.avoidWeekend?"PROTECTED":"ALLOWED"),x+10,y+112,8,COLOR_MUTED);
   y+=138;
   CreateRect(ObjName("EX2"),x,y,w,90,COLOR_PANEL,COLOR_ACCENT);
   CreateText(ObjName("EX2T"),"GRID STRUCTURE",x+10,y+8,8,COLOR_GOLD,"Arial Bold");
   CreateText(ObjName("EX2A"),StringFormat("Buy positions %d    Sell positions %d",g_state.buyPositions,g_state.sellPositions),x+10,y+30,8,COLOR_TEXT);
   CreateText(ObjName("EX2B"),StringFormat("Buy pending %d    Sell pending %d",g_state.buyPending,g_state.sellPending),x+10,y+50,8,COLOR_TEXT);
   CreateText(ObjName("EX2C"),StringFormat("Re-centers %d    Anchor %.*f",g_state.rebalances,_Digits,g_state.anchorPrice),x+10,y+70,8,COLOR_MUTED);
}

void CreateSettingsTab()
{
   int x=g_dashboard.x+8,y=g_dashboard.y+98,w=g_dashboard.width-16;
   int left=x+7, mid=x+w/2+4, col=(w/2)-20, row=20;
   CreateRect(ObjName("SETBG"),x,y,w,g_dashboard.height-108,COLOR_PANEL,COLOR_ACCENT);
   CreateText(ObjName("SETT"),"COMPLETE EA CONTROL MATRIX",x+9,y+7,8,COLOR_GOLD,"Arial Bold");
   CreateText(ObjName("SETS"),"Editable fields are applied live to the runtime grid engine.",x+9,y+22,7,COLOR_MUTED);
   int yy=y+39;
#define SROW(LID,LTXT,LVAL,RID,RTXT,RVAL) \
   CreateText(ObjName(LID+"_L"),LTXT,left,yy,7,COLOR_MUTED); CreateInput(ObjName(LID),LVAL,left+72,yy-4,62); \
   CreateText(ObjName(RID+"_L"),RTXT,mid,yy,7,COLOR_MUTED); CreateInput(ObjName(RID),RVAL,mid+72,yy-4,62); yy+=row;
   SROW("EDT_STEP","Grid step",DoubleToString(g_state.gridStep,1),"EDT_MINSTEP","Min step",DoubleToString(g_state.minGridStep,1));
   SROW("EDT_MAXSTEP","Max step",DoubleToString(g_state.maxGridStep,1),"EDT_LEVELS","Levels",IntegerToString(g_state.gridLevels));
   SROW("EDT_LOT","Base lot",DoubleToString(g_state.lotSize,3),"EDT_MULT","Multiplier",DoubleToString(g_state.lotMultiplier,2));
   SROW("EDT_ATRM","ATR spacing",DoubleToString(g_state.atrSpacingMultiplier,2),"EDT_RECATR","Recenter ATR",DoubleToString(g_state.recenterATRMultiple,2));
   SROW("EDT_RISK","Risk/grid %",DoubleToString(g_state.riskPerGridPct,2),"EDT_MAXGRIDR","Max grid risk",DoubleToString(g_state.maxGridRiskPct,2));
   SROW("EDT_MAXDD","Max DD %",DoubleToString(g_state.maxDrawdownPct,2),"EDT_DLOSS","Daily loss %",DoubleToString(g_state.dailyLossLimitPct,2));
   SROW("EDT_DPROF","Daily lock %",DoubleToString(g_state.dailyProfitLockPct,2),"EDT_BTP","Basket TP $",DoubleToString(g_state.basketTakeProfitUSD,2));
   SROW("EDT_BSL","Basket SL $",DoubleToString(g_state.basketStopLossUSD,2),"EDT_SL","SL pips",DoubleToString(g_state.stopLossPips,1));
   SROW("EDT_TP","TP pips",DoubleToString(g_state.takeProfitPips,1),"EDT_BE","BE trigger",DoubleToString(g_state.breakEvenTriggerPips,1));
   SROW("EDT_BEOFF","BE offset",DoubleToString(g_state.breakEvenOffsetPips,1),"EDT_TRAIL","Trail ATR",DoubleToString(g_state.trailingATRMultiple,2));
   SROW("EDT_MHOLD","Max hold min",DoubleToString(g_state.maxHoldMinutes,0),"EDT_MPOS","Max positions",IntegerToString(g_state.maxPositions));
   SROW("EDT_MPEND","Max pending",IntegerToString(g_state.maxPendingOrders),"EDT_SPR","Max spread",DoubleToString(g_state.maxSpreadPips,1));
   SROW("EDT_SLIP","Slippage",IntegerToString(g_state.slippage),"EDT_EXP","Pending expiry",IntegerToString(g_state.pendingExpiryMinutes));
   SROW("EDT_CONF","AI confidence",DoubleToString(g_state.aiConfidence,2),"EDT_LEARN","Learning period",IntegerToString(g_state.learningPeriod));
   SROW("EDT_BULL","Bull threshold",DoubleToString(g_state.bullThreshold,2),"EDT_BEAR","Bear threshold",DoubleToString(g_state.bearThreshold,2));
   SROW("EDT_HIVOL","High-vol threshold",DoubleToString(g_state.highVolThreshold,2),"EDT_LOVOL","Low-vol threshold",DoubleToString(g_state.lowVolThreshold,2));
   SROW("EDT_SSTART","Session start",IntegerToString(g_state.sessionStartHour),"EDT_SEND","Session end",IntegerToString(g_state.sessionEndHour));
#undef SROW
   yy+=2;
   int bw=(w-22)/3;
   CreateBtn(ObjName("BTN_APPLY"),"APPLY + VALIDATE",x+7,yy,bw,27,COLOR_GOLD,false,7);
   CreateBtn(ObjName("BTN_RESET"),"RESET VALUES",x+12+bw,yy,bw,27,COLOR_RED,false,7);
   CreateBtn(ObjName("BTN_SMART"),g_state.smartExecution?"SMART EXECUTION ON":"SMART EXECUTION OFF",x+17+(bw*2),yy,bw,27,g_state.smartExecution?COLOR_GREEN:COLOR_PANEL,g_state.smartExecution,7);
   yy+=34;
   CreateText(ObjName("TOGGLES"),"LIVE FLAGS",x+7,yy,7,COLOR_GOLD,"Arial Bold"); yy+=16;
   int tw=(w-20)/4;
   CreateBtn(ObjName("FLG_AUTO"),g_state.autonomousMode?"AUTO ON":"AUTO OFF",x+7,yy,tw,23,g_state.autonomousMode?COLOR_GREEN:COLOR_PANEL,g_state.autonomousMode,7);
   CreateBtn(ObjName("FLG_ATR"),g_state.useATRSpacing?"ATR SPACE":"FIXED SPACE",x+10+tw,yy,tw,23,g_state.useATRSpacing?COLOR_GREEN:COLOR_PANEL,g_state.useATRSpacing,7);
   CreateBtn(ObjName("FLG_RISK"),g_state.useDynamicRiskLot?"RISK LOT ON":"RISK LOT OFF",x+13+tw*2,yy,tw,23,g_state.useDynamicRiskLot?COLOR_GREEN:COLOR_PANEL,g_state.useDynamicRiskLot,7);
   CreateBtn(ObjName("FLG_BE"),g_state.breakEven?"BE ON":"BE OFF",x+16+tw*3,yy,tw,23,g_state.breakEven?COLOR_GREEN:COLOR_PANEL,g_state.breakEven,7);
   yy+=28;
   CreateBtn(ObjName("FLG_OCO"),g_state.oco?"OCO ON":"OCO OFF",x+7,yy,tw,23,g_state.oco?COLOR_GREEN:COLOR_PANEL,g_state.oco,7);
   CreateBtn(ObjName("FLG_OPP"),g_state.closeOppositeOnFill?"OPO CLOSE ON":"OPO CLOSE OFF",x+10+tw,yy,tw,23,g_state.closeOppositeOnFill?COLOR_GREEN:COLOR_PANEL,g_state.closeOppositeOnFill,7);
   CreateBtn(ObjName("FLG_SESSION"),g_state.useSessionFilter?"SESSION ON":"SESSION OFF",x+13+tw*2,yy,tw,23,g_state.useSessionFilter?COLOR_GREEN:COLOR_PANEL,g_state.useSessionFilter,7);
   CreateBtn(ObjName("FLG_REGIME"),g_state.regimeFilter?"REGIME ON":"REGIME OFF",x+16+tw*3,yy,tw,23,g_state.regimeFilter?COLOR_GREEN:COLOR_PANEL,g_state.regimeFilter,7);
   yy+=28;
   CreateBtn(ObjName("FLG_WEEK"),g_state.avoidWeekend?"WEEKEND BLOCK":"WEEKEND OPEN",x+7,yy,tw,23,g_state.avoidWeekend?COLOR_GREEN:COLOR_PANEL,g_state.avoidWeekend,7);
   CreateBtn(ObjName("FLG_HIV"),g_state.pauseHighVolatility?"HIGH-VOL PAUSE":"HIGH-VOL ALLOW",x+10+tw,yy,tw,23,g_state.pauseHighVolatility?COLOR_ORANGE:COLOR_PANEL,g_state.pauseHighVolatility,7);
   CreateBtn(ObjName("FLG_TRAIL"),g_state.trailingStop?"TRAIL ON":"TRAIL OFF",x+13+tw*2,yy,tw,23,g_state.trailingStop?COLOR_GREEN:COLOR_PANEL,g_state.trailingStop,7);
   CreateBtn(ObjName("FLG_VALIDATE"),g_state.validateStops?"STOP CHECK ON":"STOP CHECK OFF",x+16+tw*3,yy,tw,23,g_state.validateStops?COLOR_GREEN:COLOR_PANEL,g_state.validateStops,7);
   yy+=30;
   CreateBtn(ObjName("FLG_CHART_AUTO"),g_state.autoChartTheme?"AUTO CHART THEME ON":"AUTO CHART THEME OFF",x+7,yy,w-14,24,g_state.autoChartTheme?COLOR_GREEN:COLOR_PANEL,g_state.autoChartTheme,7);
   yy+=28;
   CreateBtn(ObjName("BTN_CHART_THEME"),StringFormat("CHART STYLE: %s",g_state.chartThemeMode==CHART_THEME_AUTO_REGIME?"AUTO-REGIME":ChartThemeName((int)g_state.chartThemeMode)),x+7,yy,w-14,24,COLOR_ACCENT,false,7);
}

void CreateDashboard()
{
   if(!g_dashboard.isVisible) return;
   FitDashboard(); DeleteDashboard(); DashboardHeader(); DashboardTabs();
   switch(g_dashboard.currentTab)
   {
      case 0: CreateCommandTab(); break;
      case 1: CreateGridLabTab(); break;
      case 2: CreateAnalyticsTab(); break;
      case 3: CreateRiskTab(); break;
      case 4: CreateExecutionTab(); break;
      case 5: CreateSettingsTab(); break;
   }
   ChartRedraw();
}

void UpdateDashboard()
{
   static datetime last=0; if(TimeCurrent()-last<1) return; last=TimeCurrent();
   if(!g_dashboard.isVisible) return;
   if(g_dashboard.currentTab==0)
   {
      SetText(ObjName("EQ_V"),FormatNumber(AccountInfoDouble(ACCOUNT_EQUITY)),COLOR_TEXT);
      SetText(ObjName("PL_V"),FormatNumber(g_state.currentProfit),g_state.currentProfit>=0?COLOR_GREEN:COLOR_RED);
      SetText(ObjName("POS_V"),IntegerToString(g_state.positionCount),COLOR_ACCENT);
      SetText(ObjName("PEN_V"),IntegerToString(g_state.pendingCount),COLOR_GOLD);
      SetText(ObjName("MODE_V"),GridShortName(g_state.gridType),COLOR_GOLD);
      SetText(ObjName("MODE_S"),StringFormat("Anchor %.*f   |   Step %.*f pips   |   Levels %d",_Digits,g_state.anchorPrice,1,g_state.gridStep,g_state.gridLevels),COLOR_TEXT);
      SetText(ObjName("H1"),StringFormat("Spread  %.2f pips    •    Trend %.0f%%    •    Volatility %.0f%%",g_state.currentSpreadPips,g_state.trendStrength*100,g_state.volatilityIndex*100),COLOR_TEXT);
      SetText(ObjName("H2"),StringFormat("Buy pos %d   Sell pos %d   Buy pend %d   Sell pend %d",g_state.buyPositions,g_state.sellPositions,g_state.buyPending,g_state.sellPending),COLOR_TEXT);
      SetText(ObjName("H3"),StringFormat("Daily P/L %s   •   Max DD %.2f%%   •   Wins %d / Losses %d",FormatNumber(g_state.todayProfit),g_state.maxDrawdown,g_state.wins,g_state.losses),COLOR_TEXT);
      SetText(ObjName("H4"),StringFormat("Execution: %s   •   Accepted %d   •   Rejected %d",g_state.executionStatus,g_state.acceptedOrders,g_state.rejectedOrders),COLOR_TEXT);
      SetText(ObjName("H5"),StringFormat("Chart Theme: %s   •   Mode: %s",ChartThemeName(g_state.appliedChartTheme),g_state.autoChartTheme?"AUTO":"MANUAL"),COLOR_MUTED);
   }
   SetText(ObjName("SUB"),StringFormat("%s  |  Regime: %s  |  ATR %.2f",GridShortName(g_state.gridType),g_state.regime,g_state.atrPrice),COLOR_MUTED);
   SetText(ObjName("STAT"),g_state.gridActive?"● LIVE":"○ STANDBY",g_state.gridActive?COLOR_GREEN:COLOR_MUTED);
   ChartRedraw();
}

void DeleteDashboard()
{
   for(int i=ObjectsTotal(0)-1;i>=0;i--)
   {
      string n=ObjectName(0,i);
      if(StringFind(n,PREFIX)==0) ObjectDelete(0,n);
   }
}

//--------------------------- SETTINGS / RISK --------------------------
void SyncFromDashboard()
{
   string v;
#define READ_D(ID,TARGET) v=ObjectGetString(0,ObjName(ID),OBJPROP_TEXT); if(v!="") TARGET=StringToDouble(v);
#define READ_I(ID,TARGET) v=ObjectGetString(0,ObjName(ID),OBJPROP_TEXT); if(v!="") TARGET=(int)StringToInteger(v);
   READ_D("EDT_STEP",g_state.gridStep); READ_D("EDT_MINSTEP",g_state.minGridStep); READ_D("EDT_MAXSTEP",g_state.maxGridStep); READ_I("EDT_LEVELS",g_state.gridLevels);
   READ_D("EDT_LOT",g_state.lotSize); READ_D("EDT_MULT",g_state.lotMultiplier); READ_D("EDT_ATRM",g_state.atrSpacingMultiplier); READ_D("EDT_RECATR",g_state.recenterATRMultiple);
   READ_D("EDT_RISK",g_state.riskPerGridPct); READ_D("EDT_MAXGRIDR",g_state.maxGridRiskPct); READ_D("EDT_MAXDD",g_state.maxDrawdownPct); READ_D("EDT_DLOSS",g_state.dailyLossLimitPct);
   READ_D("EDT_DPROF",g_state.dailyProfitLockPct); READ_D("EDT_BTP",g_state.basketTakeProfitUSD); READ_D("EDT_BSL",g_state.basketStopLossUSD); READ_D("EDT_SL",g_state.stopLossPips);
   READ_D("EDT_TP",g_state.takeProfitPips); READ_D("EDT_BE",g_state.breakEvenTriggerPips); READ_D("EDT_BEOFF",g_state.breakEvenOffsetPips); READ_D("EDT_TRAIL",g_state.trailingATRMultiple);
   READ_D("EDT_MHOLD",g_state.maxHoldMinutes); READ_I("EDT_MPOS",g_state.maxPositions); READ_I("EDT_MPEND",g_state.maxPendingOrders); READ_D("EDT_SPR",g_state.maxSpreadPips);
   READ_I("EDT_SLIP",g_state.slippage); READ_I("EDT_EXP",g_state.pendingExpiryMinutes); READ_D("EDT_CONF",g_state.aiConfidence); READ_I("EDT_LEARN",g_state.learningPeriod);
   READ_D("EDT_BULL",g_state.bullThreshold); READ_D("EDT_BEAR",g_state.bearThreshold); READ_D("EDT_HIVOL",g_state.highVolThreshold); READ_D("EDT_LOVOL",g_state.lowVolThreshold);
   READ_I("EDT_SSTART",g_state.sessionStartHour); READ_I("EDT_SEND",g_state.sessionEndHour);
#undef READ_D
#undef READ_I
}


bool ValidateSettings()
{
   if(g_state.gridStep<=0) g_state.gridStep=1;
   if(g_state.gridLevels<1) g_state.gridLevels=1;
   if(g_state.gridLevels>50) g_state.gridLevels=50;
   if(g_state.lotSize<=0) g_state.lotSize=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN);
   if(g_state.lotMultiplier<0.1) g_state.lotMultiplier=0.1;
   if(g_state.maxPositions<1) g_state.maxPositions=1;
   if(g_state.maxPendingOrders<1) g_state.maxPendingOrders=1;
   if(g_state.maxSpreadPips<0) g_state.maxSpreadPips=0;
   if(g_state.riskPerGridPct<0.01) g_state.riskPerGridPct=0.01;
   if(g_state.maxDrawdownPct<0.1) g_state.maxDrawdownPct=0.1;
   if(g_state.stopLossPips<0) g_state.stopLossPips=0;
   if(g_state.takeProfitPips<0) g_state.takeProfitPips=0;
   if(g_state.recenterATRMultiple<0.5) g_state.recenterATRMultiple=0.5;
   return true;
}

bool IsWeekend()
{
   MqlDateTime dt; TimeToStruct(TimeCurrent(),dt);
   return (dt.day_of_week==0 || dt.day_of_week==6);
}

bool IsSessionAllowed()
{
   if(g_state.avoidWeekend && IsWeekend()) return false;
   if(!g_state.useSessionFilter) return true;
   int h=CurrentServerHour();
   if(g_state.sessionStartHour==g_state.sessionEndHour) return true;
   if(g_state.sessionStartHour<g_state.sessionEndHour) return h>=g_state.sessionStartHour && h<g_state.sessionEndHour;
   return h>=g_state.sessionStartHour || h<g_state.sessionEndHour;
}

datetime DayStart()
{
   MqlDateTime dt; TimeToStruct(TimeCurrent(),dt); dt.hour=0; dt.min=0; dt.sec=0; return StructToTime(dt);
}

double CalculateTodayClosedProfit()
{
   datetime from=DayStart(),to=TimeCurrent(); if(!HistorySelect(from,to)) return 0;
   double p=0;
   int total=HistoryDealsTotal();
   for(int i=0;i<total;i++)
   {
      ulong t=HistoryDealGetTicket(i); if(t==0) continue;
      if(HistoryDealGetString(t,DEAL_SYMBOL)!=_Symbol) continue;
      if((ulong)HistoryDealGetInteger(t,DEAL_MAGIC)!=InpMagicNumber) continue;
      if((ENUM_DEAL_ENTRY)HistoryDealGetInteger(t,DEAL_ENTRY)!=DEAL_ENTRY_OUT) continue;
      p+=HistoryDealGetDouble(t,DEAL_PROFIT)+HistoryDealGetDouble(t,DEAL_SWAP)+HistoryDealGetDouble(t,DEAL_COMMISSION);
   }
   return p;
}

void UpdatePerformanceStats()
{
   g_state.todayProfit=CalculateTodayClosedProfit();
   g_state.totalTrades=0; g_state.wins=0; g_state.losses=0; g_state.totalProfit=0;
   datetime from=(datetime)(TimeCurrent()-86400*30); if(!HistorySelect(from,TimeCurrent())) return;
   int total=HistoryDealsTotal();
   for(int i=0;i<total;i++)
   {
      ulong t=HistoryDealGetTicket(i); if(t==0) continue;
      if(HistoryDealGetString(t,DEAL_SYMBOL)!=_Symbol || (ulong)HistoryDealGetInteger(t,DEAL_MAGIC)!=InpMagicNumber) continue;
      if((ENUM_DEAL_ENTRY)HistoryDealGetInteger(t,DEAL_ENTRY)!=DEAL_ENTRY_OUT) continue;
      double p=HistoryDealGetDouble(t,DEAL_PROFIT)+HistoryDealGetDouble(t,DEAL_SWAP)+HistoryDealGetDouble(t,DEAL_COMMISSION);
      g_state.totalProfit+=p; g_state.totalTrades++; if(p>=0) g_state.wins++; else g_state.losses++;
   }
   if(g_state.totalTrades>0) g_state.winRate=(double)g_state.wins/g_state.totalTrades*100.0;
   else g_state.winRate=0;
}

double EstimateGridRiskPct()
{
   double equity=AccountInfoDouble(ACCOUNT_EQUITY); if(equity<=0) return 0;
   double tickSize=SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE);
   double tickValue=SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_VALUE);
   double stopD=GetStopDistancePrice();
   if(tickSize<=0 || tickValue<=0 || stopD<=0) return 0;
   double riskMoneyPerLot=(stopD/tickSize)*tickValue;
   double totalLots=0;
   for(int i=0;i<PositionsTotal();i++)
   {
      ulong t=PositionGetTicket(i); if(t==0 || !IsGridOrder(t,false)) continue;
      totalLots+=PositionGetDouble(POSITION_VOLUME);
   }
   return (totalLots*riskMoneyPerLot)/equity*100.0;
}

void ExpirePendingOrders()
{
   if(g_state.pendingExpiryMinutes<=0) return;
   datetime now=TimeCurrent();
   for(int i=OrdersTotal()-1;i>=0;i--)
   {
      ulong t=OrderGetTicket(i); if(t==0 || !IsGridOrder(t,true)) continue;
      datetime setup=(datetime)OrderGetInteger(ORDER_TIME_SETUP);
      if(setup>0 && (now-setup)>=g_state.pendingExpiryMinutes*60) trade.OrderDelete(t);
   }
}

bool RiskGuardBlocksNewGrid()
{
   if(!IsSessionAllowed()) return true;
   if(g_state.currentSpreadPips>g_state.maxSpreadPips && g_state.maxSpreadPips>0) return true;
   double eq=AccountInfoDouble(ACCOUNT_EQUITY);
   if(g_state.peakEquity<=0) g_state.peakEquity=eq;
   if(eq>g_state.peakEquity) g_state.peakEquity=eq;
   if(g_state.peakEquity>0) g_state.maxDrawdown=MathMax(g_state.maxDrawdown,(g_state.peakEquity-eq)/g_state.peakEquity*100.0);
   double bal=AccountInfoDouble(ACCOUNT_BALANCE); double dayPct=(bal>0?g_state.todayProfit/bal*100.0:0);
   if(g_state.dailyLossLimitPct>0 && dayPct<=-g_state.dailyLossLimitPct) return true;
   if(g_state.dailyProfitLockPct>0 && dayPct>=g_state.dailyProfitLockPct) return true;
   if(g_state.maxDrawdownPct>0 && g_state.maxDrawdown>=g_state.maxDrawdownPct) return true;
   if(g_state.pauseHighVolatility && g_state.volatilityIndex>=g_state.highVolThreshold) return true;
   if(g_state.maxGridRiskPct>0 && EstimateGridRiskPct()>=g_state.maxGridRiskPct) return true;
   return false;
}

double GetStopDistancePrice()
{
   double p=PipSize(); long stops=(long)SymbolInfoInteger(_Symbol,SYMBOL_TRADE_STOPS_LEVEL); double minD=stops*SymbolInfoDouble(_Symbol,SYMBOL_POINT);
   return MathMax(minD, g_state.stopLossPips>0?g_state.stopLossPips*p:0);
}

double GetTakeDistancePrice()
{
   return g_state.takeProfitPips>0?g_state.takeProfitPips*PipSize():0;
}

double RiskAdjustedLot(double requested,double priceDistance)
{
   double lot=NormalizeLots(requested); if(!g_state.useDynamicRiskLot || priceDistance<=0) return lot;
   double equity=AccountInfoDouble(ACCOUNT_EQUITY); double riskMoney=equity*g_state.riskPerGridPct/100.0;
   double tickSize=SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE); double tickValue=SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_VALUE);
   if(tickSize<=0 || tickValue<=0) return lot;
   double moneyPerLot=(priceDistance/tickSize)*tickValue; if(moneyPerLot<=0) return lot;
   double riskLot=riskMoney/moneyPerLot;
   return NormalizeLots(MathMin(lot,riskLot));
}

bool ValidatePendingPrice(ENUM_ORDER_TYPE type,double price)
{
   if(!g_state.validateStops) return true;
   MqlTick tk; if(!SymbolInfoTick(_Symbol,tk)) return false;
   double pt=SymbolInfoDouble(_Symbol,SYMBOL_POINT); long stops=(long)SymbolInfoInteger(_Symbol,SYMBOL_TRADE_STOPS_LEVEL); double minD=stops*pt;
   if(type==ORDER_TYPE_BUY_STOP) return price-tk.ask>=minD;
   if(type==ORDER_TYPE_SELL_STOP) return tk.bid-price>=minD;
   if(type==ORDER_TYPE_BUY_LIMIT) return tk.ask-price>=minD;
   if(type==ORDER_TYPE_SELL_LIMIT) return price-tk.bid>=minD;
   return false;
}

bool PlaceGridOrder(ENUM_ORDER_TYPE type,double price,double lots,double sl=0,double tp=0)
{
   if(GetPendingCount()>=g_state.maxPendingOrders) return false;
   if(!ValidatePendingPrice(type,price)) { g_state.rejectedOrders++; return false; }
   price=NormalizeDouble(price,_Digits);
   double stopD=GetStopDistancePrice(), takeD=GetTakeDistancePrice();
   if(sl==0 && stopD>0)
   {
      if(type==ORDER_TYPE_BUY_STOP || type==ORDER_TYPE_BUY_LIMIT) sl=price-stopD; else sl=price+stopD;
      sl=NormalizeDouble(sl,_Digits);
   }
   if(tp==0 && takeD>0)
   {
      if(type==ORDER_TYPE_BUY_STOP || type==ORDER_TYPE_BUY_LIMIT) tp=price+takeD; else tp=price-takeD;
      tp=NormalizeDouble(tp,_Digits);
   }
   double distance=(stopD>0?stopD:MathMax(PipSize(),MathAbs(price-SymbolInfoDouble(_Symbol,SYMBOL_BID))));
   lots=RiskAdjustedLot(lots,distance); if(lots<=0) return false;
   trade.SetExpertMagicNumber(InpMagicNumber); trade.SetDeviationInPoints(g_state.slippage);
   bool result=false;
   for(int r=0;r<=g_state.orderRetryCount;r++)
   {
      if(type==ORDER_TYPE_BUY_STOP) result=trade.BuyStop(lots,price,_Symbol,sl,tp,ORDER_TIME_GTC,0,"UG7 BUY STOP");
      else if(type==ORDER_TYPE_SELL_STOP) result=trade.SellStop(lots,price,_Symbol,sl,tp,ORDER_TIME_GTC,0,"UG7 SELL STOP");
      else if(type==ORDER_TYPE_BUY_LIMIT) result=trade.BuyLimit(lots,price,_Symbol,sl,tp,ORDER_TIME_GTC,0,"UG7 BUY LIMIT");
      else if(type==ORDER_TYPE_SELL_LIMIT) result=trade.SellLimit(lots,price,_Symbol,sl,tp,ORDER_TIME_GTC,0,"UG7 SELL LIMIT");
      if(result) break;
   }
   if(result) g_state.acceptedOrders++; else {g_state.rejectedOrders++; Print("UG7 order rejected: ",EnumToString(type)," ",trade.ResultRetcodeDescription());}
   return result;
}

void DeletePendingType(ENUM_ORDER_TYPE type)
{
   for(int i=OrdersTotal()-1;i>=0;i--)
   {
      ulong t=OrderGetTicket(i); if(t==0 || !IsGridOrder(t,true)) continue;
      if((ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE)==type) trade.OrderDelete(t);
   }
}

void ApplyOCO()
{
   if(!g_state.oco) return;
   bool buy=false,sell=false;
   for(int i=0;i<PositionsTotal();i++)
   {
      ulong t=PositionGetTicket(i); if(t==0 || !IsGridOrder(t,false)) continue;
      ENUM_POSITION_TYPE pt=(ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE); if(pt==POSITION_TYPE_BUY) buy=true; if(pt==POSITION_TYPE_SELL) sell=true;
   }
   if(buy && g_state.closeOppositeOnFill) { DeletePendingType(ORDER_TYPE_SELL_STOP); DeletePendingType(ORDER_TYPE_SELL_LIMIT); }
   if(sell && g_state.closeOppositeOnFill) { DeletePendingType(ORDER_TYPE_BUY_STOP); DeletePendingType(ORDER_TYPE_BUY_LIMIT); }
}

void ManagePositions()
{
   MqlTick tk; if(!SymbolInfoTick(_Symbol,tk)) return;
   double pip=PipSize(); double atr=GetCurrentATRPrice();
   for(int i=PositionsTotal()-1;i>=0;i--)
   {
      ulong ticket=PositionGetTicket(i); if(ticket==0 || !IsGridOrder(ticket,false)) continue;
      if(!PositionSelectByTicket(ticket)) continue;
      long ptype=PositionGetInteger(POSITION_TYPE); double open=PositionGetDouble(POSITION_PRICE_OPEN); double sl=PositionGetDouble(POSITION_SL); double tp=PositionGetDouble(POSITION_TP); datetime pt=(datetime)PositionGetInteger(POSITION_TIME);
      double price=(ptype==POSITION_TYPE_BUY?tk.bid:tk.ask); double profit=(ptype==POSITION_TYPE_BUY?(price-open):(open-price))/pip;
      double newSL=sl;
      if(g_state.breakEven && profit>=g_state.breakEvenTriggerPips)
      {
         double be=(ptype==POSITION_TYPE_BUY?open+g_state.breakEvenOffsetPips*pip:open-g_state.breakEvenOffsetPips*pip);
         if(ptype==POSITION_TYPE_BUY && (sl==0 || be>sl)) newSL=be;
         if(ptype==POSITION_TYPE_SELL && (sl==0 || be<sl)) newSL=be;
      }
      if(g_state.trailingStop && atr>0)
      {
         double td=atr*g_state.trailingATRMultiple;
         double tr=(ptype==POSITION_TYPE_BUY?price-td:price+td);
         if(ptype==POSITION_TYPE_BUY && (newSL==0 || tr>newSL)) newSL=tr;
         if(ptype==POSITION_TYPE_SELL && (newSL==0 || tr<newSL)) newSL=tr;
      }
      if(newSL>0) trade.PositionModify(ticket,NormalizeDouble(newSL,_Digits),tp);
      if(g_state.maxHoldMinutes>0 && (TimeCurrent()-pt)>=g_state.maxHoldMinutes*60.0) trade.PositionClose(ticket,g_state.slippage);
   }
}

void ManageGridRisk()
{
   g_state.currentProfit=GetGridProfit();
   if(g_state.basketTakeProfitUSD>0 && g_state.currentProfit>=g_state.basketTakeProfitUSD) { CloseGrid(); return; }
   if(g_state.basketStopLossUSD>0 && g_state.currentProfit<=-MathAbs(g_state.basketStopLossUSD)) { CloseGrid(); return; }
   if(g_state.maxDrawdownPct>0 && g_state.initialEquity>0)
   {
      double eq=AccountInfoDouble(ACCOUNT_EQUITY); double dd=(g_state.initialEquity-eq)/g_state.initialEquity*100.0;
      if(dd>=g_state.maxDrawdownPct) { CloseGrid(); return; }
   }
   double bal=AccountInfoDouble(ACCOUNT_BALANCE); if(bal>0)
   {
      double dayPct=g_state.todayProfit/bal*100.0;
      if((g_state.dailyLossLimitPct>0 && dayPct<=-g_state.dailyLossLimitPct)||(g_state.dailyProfitLockPct>0 && dayPct>=g_state.dailyProfitLockPct)) { CloseGrid(); return; }
   }
}

void RecenterGrid()
{
   if(!g_state.autoRecenter || !g_state.gridActive) return;
   double atr=GetCurrentATRPrice(); if(atr<=0 || g_state.anchorPrice<=0) return;
   double mid=(SymbolInfoDouble(_Symbol,SYMBOL_ASK)+SymbolInfoDouble(_Symbol,SYMBOL_BID))/2.0;
   if(MathAbs(mid-g_state.anchorPrice)>=atr*g_state.recenterATRMultiple)
   {
      for(int i=OrdersTotal()-1;i>=0;i--) { ulong t=OrderGetTicket(i); if(t>0 && IsGridOrder(t,true)) trade.OrderDelete(t); }
      g_state.anchorPrice=mid; g_state.rebalances++;
      g_state.gridActive=false; CreateGrid();
   }
}

void CloseGrid()
{
   for(int i=PositionsTotal()-1;i>=0;i--) { ulong t=PositionGetTicket(i); if(t>0 && IsGridOrder(t,false)) trade.PositionClose(t,g_state.slippage); }
   for(int i=OrdersTotal()-1;i>=0;i--) { ulong t=OrderGetTicket(i); if(t>0 && IsGridOrder(t,true)) trade.OrderDelete(t); }
   g_state.gridActive=false; g_state.startTime=0; g_state.anchorPrice=0; g_state.executionStatus="GRID CLOSED";
}

// Close only EA-managed positions currently in profit. Pending orders are untouched.
void CloseProfitPositions()
{
   int closed=0, failed=0;
   for(int i=PositionsTotal()-1;i>=0;i--)
   {
      ulong ticket=PositionGetTicket(i);
      if(ticket==0 || !IsGridOrder(ticket,false)) continue;
      if(!PositionSelectByTicket(ticket)) continue;
      double netProfit=PositionGetDouble(POSITION_PROFIT)+PositionGetDouble(POSITION_SWAP);
      if(netProfit>0.0)
      {
         if(trade.PositionClose(ticket,g_state.slippage)) closed++;
         else failed++;
      }
   }
   g_state.executionStatus=StringFormat("CLOSE PROFIT: %d closed / %d failed",closed,failed);
}

// Close only EA-managed positions currently in loss. Profitable positions and pending orders are untouched.
void CloseLossPositions()
{
   int closed=0, failed=0;
   for(int i=PositionsTotal()-1;i>=0;i--)
   {
      ulong ticket=PositionGetTicket(i);
      if(ticket==0 || !IsGridOrder(ticket,false)) continue;
      if(!PositionSelectByTicket(ticket)) continue;
      double netProfit=PositionGetDouble(POSITION_PROFIT)+PositionGetDouble(POSITION_SWAP);
      if(netProfit<0.0)
      {
         if(trade.PositionClose(ticket,g_state.slippage)) closed++;
         else failed++;
      }
   }
   g_state.executionStatus=StringFormat("CLOSE LOSS: %d closed / %d failed",closed,failed);
}

// Cancel only EA-managed pending grid orders. Open positions are untouched.
void CancelPendingGridOrders()
{
   int cancelled=0, failed=0;
   for(int i=OrdersTotal()-1;i>=0;i--)
   {
      ulong ticket=OrderGetTicket(i);
      if(ticket==0 || !IsGridOrder(ticket,true)) continue;
      if(trade.OrderDelete(ticket)) cancelled++;
      else failed++;
   }
   if(GetPositionCount()==0 && GetPendingCount()==0) g_state.gridActive=false;
   g_state.executionStatus=StringFormat("CANCEL ORDERS: %d cancelled / %d failed",cancelled,failed);
}

void InitializeState()
{
   ZeroMemory(g_state);
   g_state.gridType=InpGridType; g_state.entryMode=InpEntryMode; g_state.riskMode=InpRiskMode; g_state.reentryMode=InpReentryMode;
   g_state.lotSize=InpLotSize; g_state.gridStep=InpGridStep; g_state.gridLevels=InpGridLevels; g_state.lotMultiplier=InpLotMultiplier; g_state.autonomousMode=InpAutonomousMode;
   g_state.useATRSpacing=InpUseATRSpacing; g_state.atrSpacingMultiplier=InpATRSpacingMultiplier; g_state.minGridStep=InpMinGridStepPips; g_state.maxGridStep=InpMaxGridStepPips; g_state.recenterATRMultiple=InpRecenterATRMultiple; g_state.autoRecenter=InpAutoRecenter;
   g_state.aiEnabled=InpEnableAI; g_state.neuralNetwork=InpNeuralNetwork; g_state.aiConfidence=InpAIConfidence; g_state.learningPeriod=InpLearningPeriod; g_state.regimeFilter=InpRegimeFilter; g_state.bullThreshold=InpBullThreshold; g_state.bearThreshold=InpBearThreshold; g_state.highVolThreshold=InpHighVolThreshold; g_state.lowVolThreshold=InpLowVolThreshold;
   g_state.useDynamicRiskLot=InpUseDynamicRiskLot; g_state.riskPerGridPct=InpRiskPerGridPct; g_state.maxGridRiskPct=InpMaxGridRiskPct; g_state.maxDrawdownPct=InpMaxDrawdownPct; g_state.dailyLossLimitPct=InpDailyLossLimitPct; g_state.dailyProfitLockPct=InpDailyProfitLockPct; g_state.basketTakeProfitUSD=InpBasketTakeProfitUSD; g_state.basketStopLossUSD=InpBasketStopLossUSD; g_state.stopLossPips=InpStopLossPips; g_state.takeProfitPips=InpTakeProfitPips;
   g_state.breakEven=InpUseBreakEven; g_state.breakEvenTriggerPips=InpBreakEvenTriggerPips; g_state.breakEvenOffsetPips=InpBreakEvenOffsetPips; g_state.trailingStop=InpTrailingStop; g_state.trailingATRMultiple=InpTrailingATRMultiple; g_state.maxHoldMinutes=InpMaxHoldMinutes; g_state.maxPositions=InpMaxPositions; g_state.maxPendingOrders=InpMaxPendingOrders; g_state.oco=InpOCO; g_state.closeOppositeOnFill=InpCloseOppositePendingOnFill;
   g_state.slippage=InpSlippage; g_state.maxSpreadPips=InpMaxSpreadPips; g_state.pendingExpiryMinutes=InpPendingExpiryMinutes; g_state.smartExecution=InpSmartExecution; g_state.validateStops=InpValidateStops; g_state.orderRetryCount=InpOrderRetryCount;
   g_state.useSessionFilter=InpUseSessionFilter; g_state.sessionStartHour=InpSessionStartHour; g_state.sessionEndHour=InpSessionEndHour; g_state.avoidWeekend=InpAvoidWeekend; g_state.pauseHighVolatility=InpPauseOnHighVolatility;
   g_state.gridActive=false; g_state.initialEquity=AccountInfoDouble(ACCOUNT_EQUITY); g_state.peakEquity=g_state.initialEquity; g_state.dayAnchor=DayStart(); g_state.regime="UNKNOWN"; g_state.executionStatus="READY";
   ValidateSettings();
}

void UpdateState()
{
   g_state.trendStrength=CalculateTrendStrength(); g_state.volatilityIndex=CalculateVolatility(); g_state.sentimentScore=CalculateSentiment(); g_state.atrPrice=GetCurrentATRPrice();
   MqlTick tk; if(SymbolInfoTick(_Symbol,tk)) g_state.currentSpreadPips=(tk.ask-tk.bid)/PipSize();
   if(g_state.trendStrength>=g_state.bullThreshold) g_state.regime=(g_state.volatilityIndex>=g_state.highVolThreshold?"BULL / HIGH VOL":"BULL TREND");
   else if(g_state.trendStrength<=g_state.bearThreshold) g_state.regime=(g_state.volatilityIndex>=g_state.highVolThreshold?"BEAR / HIGH VOL":"BEAR TREND");
   else if(g_state.volatilityIndex<=g_state.lowVolThreshold) g_state.regime="RANGE / MEAN REVERSION"; else if(g_state.volatilityIndex>=g_state.highVolThreshold) g_state.regime="BREAKOUT / HIGH VOL"; else g_state.regime="TRANSITION";
   g_state.positionCount=GetPositionCount(); g_state.pendingCount=GetPendingCount(); g_state.currentProfit=GetGridProfit();
   g_state.buyPositions=g_state.sellPositions=g_state.buyPending=g_state.sellPending=0;
   for(int i=0;i<PositionsTotal();i++){ ulong t=PositionGetTicket(i); if(t>0 && IsGridOrder(t,false)){ ENUM_POSITION_TYPE pt=(ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE); if(pt==POSITION_TYPE_BUY)g_state.buyPositions++;else g_state.sellPositions++; } }
   for(int i=0;i<OrdersTotal();i++){ ulong t=OrderGetTicket(i); if(t>0 && IsGridOrder(t,true)){ ENUM_ORDER_TYPE ot=(ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE); if(ot==ORDER_TYPE_BUY_STOP||ot==ORDER_TYPE_BUY_LIMIT)g_state.buyPending++;else g_state.sellPending++; } }
   UpdatePerformanceStats();
}

bool ShouldStartGrid()
{
   if(g_state.gridActive || RiskGuardBlocksNewGrid()) return false;
   if(g_state.entryMode==MANUAL_ENTRY) return false;
   if(g_state.entryMode==AI_ENTRY && (!g_state.aiEnabled || (g_state.predictionAccuracy>0 && g_state.predictionAccuracy<g_state.aiConfidence))) return false;
   if(g_state.gridType==BULLISH_GRID && g_state.trendStrength<g_state.bullThreshold) return false;
   if(g_state.gridType==BEARISH_GRID && g_state.trendStrength>g_state.bearThreshold) return false;
   return true;
}

// Event handlers
int OnInit()
{
   InitializeState(); InitializeDashboard();
   trade.SetExpertMagicNumber(InpMagicNumber); trade.SetDeviationInPoints(InpSlippage);
   g_atrHandle=iATR(_Symbol,PERIOD_CURRENT,InpRecenterATRPeriod);
   g_maHandle=iMA(_Symbol,PERIOD_CURRENT,20,0,MODE_SMA,PRICE_CLOSE);
   g_rsiHandle=iRSI(_Symbol,PERIOD_CURRENT,14,PRICE_CLOSE);
   UpdateState();
   ApplyChartTheme(true);
   if(g_state.positionCount>0 || g_state.pendingCount>0){ g_state.gridActive=true; g_state.startTime=TimeCurrent(); g_state.anchorPrice=(SymbolInfoDouble(_Symbol,SYMBOL_ASK)+SymbolInfoDouble(_Symbol,SYMBOL_BID))/2.0; }
   if(g_dashboard.isVisible) CreateDashboard();
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
   if(g_atrHandle!=INVALID_HANDLE) IndicatorRelease(g_atrHandle); if(g_maHandle!=INVALID_HANDLE) IndicatorRelease(g_maHandle); if(g_rsiHandle!=INVALID_HANDLE) IndicatorRelease(g_rsiHandle); DeleteDashboard(); Comment("");
}

void OnTick()
{
   UpdateState();
   if(g_state.autoChartTheme) ApplyChartTheme(false);
   ExpirePendingOrders();
   ManagePositions();
   ApplyOCO();
   ManageGridRisk();
   if(g_state.gridActive) RecenterGrid();
   if(g_state.autonomousMode && ShouldStartGrid()) CreateGrid();
   g_state.executionStatus=(g_state.currentSpreadPips<=g_state.maxSpreadPips || g_state.maxSpreadPips<=0)?"NORMAL":"SPREAD HIGH";
   UpdateDashboard();
}

void OnChartEvent(const int id,const long &lparam,const double &dparam,const string &sparam)
{
   if(id==CHARTEVENT_CHART_CHANGE){ ApplyChartTheme(true); if(g_dashboard.isVisible) CreateDashboard(); return; }
   if(id==CHARTEVENT_OBJECT_ENDEDIT && StringFind(sparam,PREFIX)==0){ StoreEditValue(sparam,ObjectGetString(0,sparam,OBJPROP_TEXT)); return; }
   if(id!=CHARTEVENT_OBJECT_CLICK || StringFind(sparam,PREFIX)!=0) return;
   for(int i=0;i<TAB_COUNT;i++) if(sparam==ObjName("TAB_"+IntegerToString(i))){g_dashboard.currentTab=i;CreateDashboard();return;}
   if(sparam==ObjName("BTN_START")){ if(!g_state.gridActive) CreateGrid(); }
   else if(sparam==ObjName("BTN_STOP")){ CloseGrid(); }
   else if(sparam==ObjName("BTN_REBAL")){ g_state.gridActive=false; for(int j=OrdersTotal()-1;j>=0;j--){ulong t=OrderGetTicket(j);if(t>0&&IsGridOrder(t,true))trade.OrderDelete(t);} CreateGrid(); }
   else if(sparam==ObjName("BTN_CLOSE_PROFIT")){ CloseProfitPositions(); UpdateState(); CreateDashboard(); }
   else if(sparam==ObjName("BTN_CLOSE_LOSS")){ CloseLossPositions(); UpdateState(); CreateDashboard(); }
   else if(sparam==ObjName("BTN_CANCEL_ORDERS")){ CancelPendingGridOrders(); UpdateState(); CreateDashboard(); }
   else if(sparam==ObjName("BTN_GRID_REBUILD")){ CloseGrid(); CreateGrid(); }
   else if(StringFind(sparam,ObjName("GRID_SEL_"))==0){ int idx=(int)StringToInteger(StringSubstr(sparam,StringLen(ObjName("GRID_SEL_")))); if(idx>=0&&idx<GRID_TYPE_COUNT){g_state.gridType=(ENUM_GRID_TYPE)idx;CreateDashboard();} }
   else if(sparam==ObjName("BTN_AUTO")){g_state.autonomousMode=!g_state.autonomousMode;CreateDashboard();}
   else if(sparam==ObjName("BTN_AI_TOGGLE")){g_state.aiEnabled=!g_state.aiEnabled;CreateDashboard();}
   else if(sparam==ObjName("BTN_AI_RESET")){g_state.predictionAccuracy=0;g_state.totalTrades=0;g_state.wins=0;g_state.losses=0;CreateDashboard();}
   else if(sparam==ObjName("BTN_RISK_MODE")){g_state.riskMode=(ENUM_RISK_MODE)(((int)g_state.riskMode+1)%4);CreateDashboard();}
   else if(sparam==ObjName("BTN_TRAILING")){g_state.trailingStop=!g_state.trailingStop;CreateDashboard();}
   else if(sparam==ObjName("BTN_SMART")){g_state.smartExecution=!g_state.smartExecution;CreateDashboard();}
   else if(sparam==ObjName("FLG_AUTO")){g_state.autonomousMode=!g_state.autonomousMode;CreateDashboard();}
   else if(sparam==ObjName("FLG_ATR")){g_state.useATRSpacing=!g_state.useATRSpacing;CreateDashboard();}
   else if(sparam==ObjName("FLG_RISK")){g_state.useDynamicRiskLot=!g_state.useDynamicRiskLot;CreateDashboard();}
   else if(sparam==ObjName("FLG_BE")){g_state.breakEven=!g_state.breakEven;CreateDashboard();}
   else if(sparam==ObjName("FLG_OCO")){g_state.oco=!g_state.oco;CreateDashboard();}
   else if(sparam==ObjName("FLG_OPP")){g_state.closeOppositeOnFill=!g_state.closeOppositeOnFill;CreateDashboard();}
   else if(sparam==ObjName("FLG_SESSION")){g_state.useSessionFilter=!g_state.useSessionFilter;CreateDashboard();}
   else if(sparam==ObjName("FLG_REGIME")){g_state.regimeFilter=!g_state.regimeFilter;CreateDashboard();}
   else if(sparam==ObjName("FLG_WEEK")){g_state.avoidWeekend=!g_state.avoidWeekend;CreateDashboard();}
   else if(sparam==ObjName("FLG_HIV")){g_state.pauseHighVolatility=!g_state.pauseHighVolatility;CreateDashboard();}
   else if(sparam==ObjName("FLG_TRAIL")){g_state.trailingStop=!g_state.trailingStop;CreateDashboard();}
   else if(sparam==ObjName("FLG_VALIDATE")){g_state.validateStops=!g_state.validateStops;CreateDashboard();}
   else if(sparam==ObjName("FLG_CHART_AUTO")){g_state.autoChartTheme=!g_state.autoChartTheme;ApplyChartTheme(true);CreateDashboard();}
   else if(sparam==ObjName("BTN_CHART_THEME")){g_state.chartThemeMode=(ENUM_CHART_THEME_MODE)(((int)g_state.chartThemeMode+1)%5);ApplyChartTheme(true);CreateDashboard();}
   else if(sparam==ObjName("BTN_APPLY")){SyncFromDashboard();ValidateSettings();ApplyChartTheme(true);CreateDashboard();}
   else if(sparam==ObjName("BTN_RESET")){InitializeState();CreateDashboard();}
   ChartRedraw();
}
