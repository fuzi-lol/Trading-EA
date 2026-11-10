#property strict
#property version   "7.13"
#property description "Ultimate Grid EA 7.13 - Rebuilt Professional Readable Command Center"

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
input bool InpRiskManagedTrading = true;
input bool InpUseStopLossForNewOrders = true;
input bool InpUseTakeProfitForNewOrders = true;
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
   bool riskManagedTrading;
   bool useStopLossForNewOrders;
   bool useTakeProfitForNewOrders;
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
const int TAB_COUNT = 8;
const int GRID_TYPE_COUNT = 21;
const string TAB_NAMES[] = {"HOME","GRID","RISK","ANALYTICS","AI","EXEC","TRADES","SETTINGS"};

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
   PlaceManagedMarketOrder(true, initialLot, "Hedge Buy");
   PlaceManagedMarketOrder(false, initialLot, "Hedge Sell");
   
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
      PlaceManagedMarketOrder(true, lotSize, "Trend Buy");
      for(int i = 1; i <= g_state.gridLevels; i++)
      {
         double price = NormalizeDouble(basePrice + spacing * i, _Digits);
         PlaceGridOrder(ORDER_TYPE_BUY_STOP, price, lotSize);
      }
   }
   else if(trend < 0.4) // Bearish
   {
      PlaceManagedMarketOrder(false, lotSize, "Trend Sell");
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
   // Professional command-center palette: near-black background, deep slate panels,
   // cyan/teal interaction color, refined gold highlights, green/red state colors.
   if(InpDashboardTheme==THEME_GOLD)
   {
      COLOR_BG=C'5,10,14';
      COLOR_PANEL=C'10,20,24';
      COLOR_PANEL2=C'14,29,34';
      COLOR_TEXT=C'236,244,246';
      COLOR_MUTED=C'135,161,170';
      COLOR_ACCENT=C'0,184,199';
      COLOR_GOLD=C'218,170,58';
      COLOR_GREEN=C'63,214,116';
      COLOR_RED=C'242,86,93';
      COLOR_ORANGE=C'236,158,54';
      COLOR_TEAL=C'40,208,221';
   }
   else if(InpDashboardTheme==THEME_TEAL)
   {
      COLOR_BG=C'4,12,17';
      COLOR_PANEL=C'8,24,30';
      COLOR_PANEL2=C'10,38,44';
      COLOR_TEXT=C'236,247,249';
      COLOR_MUTED=C'133,172,181';
      COLOR_ACCENT=C'21,205,213';
      COLOR_GOLD=C'224,183,67';
      COLOR_GREEN=C'65,220,122';
      COLOR_RED=C'244,90,99';
      COLOR_ORANGE=C'238,163,58';
      COLOR_TEAL=C'58,225,230';
   }
   else
   {
      COLOR_BG=C'8,10,13';
      COLOR_PANEL=C'17,18,22';
      COLOR_PANEL2=C'28,29,34';
      COLOR_TEXT=C'238,240,243';
      COLOR_MUTED=C'146,150,158';
      COLOR_ACCENT=C'94,169,255';
      COLOR_GOLD=C'195,183,113';
      COLOR_GREEN=C'92,207,125';
      COLOR_RED=C'238,103,107';
      COLOR_ORANGE=C'230,163,71';
      COLOR_TEAL=C'117,199,210';
   }
}

void InitializeDashboard()
{
   g_dashboard.x=8;
   g_dashboard.y=7;
   g_dashboard.currentTab=0;
   g_dashboard.isVisible=InpShowDashboard;
   ApplyTheme();
}

void FitDashboard()
{
   int cw=(int)ChartGetInteger(0,CHART_WIDTH_IN_PIXELS);
   int ch=(int)ChartGetInteger(0,CHART_HEIGHT_IN_PIXELS);
   const int margin=8;
   const int minChartReserve=320;

   if(cw<420 || ch<320)
   {
      g_dashboard.x=4;
      g_dashboard.y=4;
      g_dashboard.width=MathMax(360,cw-8);
      g_dashboard.height=MathMax(280,ch-8);
      return;
   }

   // New dashboard architecture: compact left dock with a guaranteed visible
   // chart reserve on the right. All content uses fixed-height rows and
   // minimum readable fonts; no proportional text compression is used.
   double pct=MathMax(0.32,MathMin(0.38,InpDashboardWidthPct));
   int width=(int)MathRound(cw*pct);
   width=MathMax(390,width);
   width=MathMin(520,width);
   width=MathMin(width,MathMax(360,cw-minChartReserve-margin));
   width=MathMax(360,MathMin(width,cw-80));

   g_dashboard.x=margin;
   g_dashboard.y=margin;
   g_dashboard.width=width;
   g_dashboard.height=MathMax(300,ch-(margin*2));
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
   ObjectSetInteger(0,name,OBJPROP_XDISTANCE,x);
   ObjectSetInteger(0,name,OBJPROP_YDISTANCE,y);
   ObjectSetInteger(0,name,OBJPROP_FONTSIZE,MathMax(8,size));
   ObjectSetString(0,name,OBJPROP_FONT,font);
   ObjectSetString(0,name,OBJPROP_TEXT,text);
   ObjectSetInteger(0,name,OBJPROP_COLOR,clr);
   ObjectSetInteger(0,name,OBJPROP_CORNER,CORNER_LEFT_UPPER);
   ObjectSetInteger(0,name,OBJPROP_SELECTABLE,false);
   ObjectSetInteger(0,name,OBJPROP_HIDDEN,true);
   ObjectSetInteger(0,name,OBJPROP_ZORDER,20);
}

void CreateRect(string name,int x,int y,int w,int h,color bg,color border)
{
   if(w<1 || h<1) return;
   if(ObjectFind(0,name)<0) ObjectCreate(0,name,OBJ_RECTANGLE_LABEL,0,0,0);
   ObjectSetInteger(0,name,OBJPROP_XDISTANCE,x);
   ObjectSetInteger(0,name,OBJPROP_YDISTANCE,y);
   ObjectSetInteger(0,name,OBJPROP_XSIZE,w);
   ObjectSetInteger(0,name,OBJPROP_YSIZE,h);
   ObjectSetInteger(0,name,OBJPROP_BGCOLOR,bg);
   ObjectSetInteger(0,name,OBJPROP_BORDER_COLOR,border);
   ObjectSetInteger(0,name,OBJPROP_CORNER,CORNER_LEFT_UPPER);
   ObjectSetInteger(0,name,OBJPROP_SELECTABLE,false);
   ObjectSetInteger(0,name,OBJPROP_HIDDEN,true);
   ObjectSetInteger(0,name,OBJPROP_ZORDER,10);
}

void CreateBtn(string name,string text,int x,int y,int w,int h,color bg,bool state=false,int fs=8)
{
   if(w<12 || h<12) return;
   if(ObjectFind(0,name)<0) ObjectCreate(0,name,OBJ_BUTTON,0,0,0);
   ObjectSetInteger(0,name,OBJPROP_XDISTANCE,x);
   ObjectSetInteger(0,name,OBJPROP_YDISTANCE,y);
   ObjectSetInteger(0,name,OBJPROP_XSIZE,w);
   ObjectSetInteger(0,name,OBJPROP_YSIZE,h);
   ObjectSetInteger(0,name,OBJPROP_FONTSIZE,MathMax(8,fs));
   ObjectSetString(0,name,OBJPROP_FONT,"Arial Bold");
   ObjectSetString(0,name,OBJPROP_TEXT,text);
   ObjectSetInteger(0,name,OBJPROP_COLOR,COLOR_TEXT);
   ObjectSetInteger(0,name,OBJPROP_BGCOLOR,bg);
   ObjectSetInteger(0,name,OBJPROP_BORDER_COLOR,state?COLOR_GOLD:COLOR_ACCENT);
   ObjectSetInteger(0,name,OBJPROP_STATE,false);
   ObjectSetInteger(0,name,OBJPROP_CORNER,CORNER_LEFT_UPPER);
   ObjectSetInteger(0,name,OBJPROP_HIDDEN,true);
   ObjectSetInteger(0,name,OBJPROP_ZORDER,30);
}

void CreateInput(string name,string value,int x,int y,int w)
{
   string sv=GetEditValue(name,value); if(sv!="") value=sv;
   if(ObjectFind(0,name)<0) ObjectCreate(0,name,OBJ_EDIT,0,0,0);
   ObjectSetInteger(0,name,OBJPROP_XDISTANCE,x);
   ObjectSetInteger(0,name,OBJPROP_YDISTANCE,y);
   ObjectSetInteger(0,name,OBJPROP_XSIZE,w);
   ObjectSetInteger(0,name,OBJPROP_YSIZE,21);
   ObjectSetInteger(0,name,OBJPROP_FONTSIZE,8);
   ObjectSetString(0,name,OBJPROP_FONT,"Arial");
   ObjectSetString(0,name,OBJPROP_TEXT,value);
   ObjectSetInteger(0,name,OBJPROP_COLOR,COLOR_TEXT);
   ObjectSetInteger(0,name,OBJPROP_BGCOLOR,C'10,17,21');
   ObjectSetInteger(0,name,OBJPROP_BORDER_COLOR,COLOR_ACCENT);
   ObjectSetInteger(0,name,OBJPROP_CORNER,CORNER_LEFT_UPPER);
   ObjectSetInteger(0,name,OBJPROP_HIDDEN,true);
   ObjectSetInteger(0,name,OBJPROP_ZORDER,35);
}

void Section(string id,string title,int x,int y,int w,int h)
{
   CreateRect(ObjName(id+"_P"),x,y,w,h,COLOR_PANEL,COLOR_PANEL2);
   CreateText(ObjName(id+"_T"),title,x+10,y+7,9,COLOR_GOLD,"Arial Bold");
}

void KV(string id,string label,string value,int x,int y,int labelW=82,color valClr=clrWhite)
{
   CreateText(ObjName(id+"L"),label,x,y,8,COLOR_MUTED,"Arial");
   CreateText(ObjName(id+"V"),value,x+labelW,y,8,valClr,"Arial Bold");
}

void Meter(string id,string label,double pct,int x,int y,int w,color fill)
{
   pct=MathMax(0.0,MathMin(100.0,pct));
   CreateText(ObjName(id+"L"),label,x,y,8,COLOR_MUTED,"Arial Bold");
   CreateRect(ObjName(id+"TR"),x+70,y+2,w,7,C'25,33,38',C'25,33,38');
   int bw=(int)MathRound(w*pct/100.0);
   if(bw>0) CreateRect(ObjName(id+"BR"),x+70,y+2,bw,7,fill,fill);
   CreateText(ObjName(id+"P"),StringFormat("%.0f%%",pct),x+74+w,y-1,8,fill,"Arial Bold");
}

void DashboardHeader()
{
   int x=g_dashboard.x,y=g_dashboard.y,w=g_dashboard.width;
   CreateRect(ObjName("BG"),x,y,w,g_dashboard.height,COLOR_BG,COLOR_ACCENT);
   CreateRect(ObjName("HEAD"),x+1,y+1,w-2,54,C'8,19,24',COLOR_GOLD);
   CreateText(ObjName("TITLE"),"ULTIMATE GRID EA",x+14,y+7,14,COLOR_GOLD,"Arial Bold");
   CreateText(ObjName("SUB"),StringFormat("PRO COMMAND CENTER  |  %s  |  %s",_Symbol,EnumToString((ENUM_TIMEFRAMES)_Period)),x+14,y+30,8,COLOR_MUTED,"Arial");
   string stat=g_state.gridActive?"LIVE":"READY";
   CreateText(ObjName("STAT"),stat,x+w-58,y+11,9,g_state.gridActive?COLOR_GREEN:COLOR_MUTED,"Arial Bold");
   CreateText(ObjName("ACCT"),StringFormat("EQ %s  |  P/L %s",FormatNumber(AccountInfoDouble(ACCOUNT_EQUITY)),FormatNumber(g_state.currentProfit)),x+w-230,y+33,8,g_state.currentProfit>=0?COLOR_GREEN:COLOR_RED,"Arial Bold");
}

void DashboardTabs()
{
   int x=g_dashboard.x+8,y=g_dashboard.y+60,w=g_dashboard.width-16;
   int tw=(w-21)/TAB_COUNT;
   for(int i=0;i<TAB_COUNT;i++)
      CreateBtn(ObjName("TAB_"+IntegerToString(i)),TAB_NAMES[i],x+i*tw,y,tw-3,25,i==g_dashboard.currentTab?COLOR_ACCENT:COLOR_PANEL,i==g_dashboard.currentTab,8);
}

void FooterBar()
{
   int x=g_dashboard.x+8,y=g_dashboard.y+g_dashboard.height-24,w=g_dashboard.width-16;
   CreateRect(ObjName("FOOT"),x,y,w,17,C'7,15,19',COLOR_PANEL2);
   CreateText(ObjName("FOOTL"),StringFormat("MAGIC %I64u  |  SERVER %s  |  %s",InpMagicNumber,TimeToString(TimeCurrent(),TIME_SECONDS),g_state.executionStatus),x+8,y+3,8,COLOR_MUTED);
   CreateText(ObjName("FOOTR"),StringFormat("%dx%d",g_dashboard.width,g_dashboard.height),x+w-50,y+3,8,COLOR_MUTED);
}

void CreateCommandTab()
{
   int x=g_dashboard.x+10,y=g_dashboard.y+93,w=g_dashboard.width-20;
   int h=g_dashboard.height-124;
   int gap=8;
   int left=(w-2*gap)/3;
   int mid=left;
   int right=w-left-mid-2*gap;
   int topH=160;
   int bottomH=h-topH-gap;

   Section("HOME_CTRL","EA CONTROL",x,y,left,topH);
   int bw=(left-24)/2;
   CreateBtn(ObjName("BTN_START"),"START",x+8,y+32,bw,28,COLOR_GREEN,false,8);
   CreateBtn(ObjName("BTN_STOP"),"CLOSE GRID",x+16+bw,y+32,bw,28,COLOR_RED,false,8);
   CreateBtn(ObjName("BTN_REBAL"),"RECENTER",x+8,y+65,bw,26,COLOR_ACCENT,false,8);
   CreateBtn(ObjName("BTN_CLOSE_PROFIT"),"CLOSE PROFIT",x+16+bw,y+65,bw,26,COLOR_GREEN,false,8);
   CreateBtn(ObjName("BTN_CLOSE_LOSS"),"CLOSE LOSS",x+8,y+98,bw,26,COLOR_RED,false,8);
   CreateBtn(ObjName("BTN_CANCEL_ORDERS"),"CANCEL PENDING",x+16+bw,y+98,bw,26,COLOR_PANEL2,false,8);
   KV("HMS1","AUTO",g_state.autonomousMode?"ON":"OFF",x+8,y+134,65,g_state.autonomousMode?COLOR_GREEN:COLOR_MUTED);
   KV("HMS2","AI",g_state.aiEnabled?"ON":"OFF",x+left/2,y+134,45,g_state.aiEnabled?COLOR_GREEN:COLOR_MUTED);

   Section("HOME_GRID","GRID",x+left+gap,y,mid,topH);
   KV("HG1","TYPE",GridShortName(g_state.gridType),x+left+gap+8,y+32,52,COLOR_GOLD);
   KV("HG2","STEP",StringFormat("%.1f pips",g_state.gridStep),x+left+gap+8,y+56,52,COLOR_TEXT);
   KV("HG3","LEVELS",StringFormat("%d",g_state.gridLevels),x+left+gap+8,y+80,52,COLOR_TEXT);
   KV("HG4","PENDING",StringFormat("%d / %d",g_state.pendingCount,g_state.maxPendingOrders),x+left+gap+8,y+104,52,COLOR_GOLD);
   KV("HG5","ANCHOR",DoubleToString(g_state.anchorPrice,_Digits),x+left+gap+8,y+128,52,COLOR_TEXT);
   CreateText(ObjName("HG6"),g_state.gridActive?"GRID ACTIVE":"GRID IDLE",x+left+gap+mid-90,y+134,8,g_state.gridActive?COLOR_GREEN:COLOR_MUTED,"Arial Bold");

   Section("HOME_RISK","RISK",x+2*(left+gap),y,right,topH);
   CreateBtn(ObjName("BTN_RISK_MANAGED"),g_state.riskManagedTrading?"RISK ENGINE ON":"RISK ENGINE OFF",x+2*(left+gap)+8,y+32,right-16,g_state.riskManagedTrading?28:28,g_state.riskManagedTrading?COLOR_GREEN:COLOR_RED,g_state.riskManagedTrading,8);
   CreateBtn(ObjName("BTN_NEW_ORDER_SL"),g_state.useStopLossForNewOrders?"STOP LOSS ON":"STOP LOSS OFF",x+2*(left+gap)+8,y+65,(right-24)/2,28,g_state.useStopLossForNewOrders?COLOR_GREEN:COLOR_RED,g_state.useStopLossForNewOrders,8);
   CreateBtn(ObjName("BTN_NEW_ORDER_TP"),g_state.useTakeProfitForNewOrders?"TAKE PROFIT ON":"TAKE PROFIT OFF",x+2*(left+gap)+16+(right-24)/2,y+65,(right-24)/2,28,g_state.useTakeProfitForNewOrders?COLOR_GREEN:COLOR_RED,g_state.useTakeProfitForNewOrders,8);
   KV("HR1","PROFILE",g_state.riskMode==CONSERVATIVE?"CONSERVATIVE":g_state.riskMode==BALANCED?"BALANCED":g_state.riskMode==AGGRESSIVE?"AGGRESSIVE":"ADAPTIVE",x+2*(left+gap)+8,y+104,58,COLOR_GOLD);
   KV("HR2","RISK/GRID",StringFormat("%.2f%%",g_state.riskPerGridPct),x+2*(left+gap)+8,y+128,58,COLOR_TEXT);

   Section("HOME_KPI","LIVE METRICS",x,y+topH+gap,w,bottomH);
   int kY=y+topH+gap+30;
   int kW=(w-5*gap)/6;
   CreateKPI("K1","OPEN P/L",FormatNumber(g_state.currentProfit),x,kY,kW,56,g_state.currentProfit>=0?COLOR_GREEN:COLOR_RED);
   CreateKPI("K2","POSITIONS",IntegerToString(g_state.positionCount),x+kW+gap,kY,kW,56,COLOR_TEAL);
   CreateKPI("K3","PENDING",IntegerToString(g_state.pendingCount),x+(kW+gap)*2,kY,kW,56,COLOR_GOLD);
   CreateKPI("K4","WIN RATE",StringFormat("%.1f%%",g_state.winRate),x+(kW+gap)*3,kY,kW,56,COLOR_GREEN);
   CreateKPI("K5","MAX DD",StringFormat("%.2f%%",g_state.maxDrawdown),x+(kW+gap)*4,kY,kW,56,g_state.maxDrawdown>g_state.maxDrawdownPct*0.8?COLOR_RED:COLOR_TEXT);
   CreateKPI("K6","REJECTED",IntegerToString(g_state.rejectedOrders),x+(kW+gap)*5,kY,kW,56,g_state.rejectedOrders==0?COLOR_GREEN:COLOR_ORANGE);
   Meter("TM", "TREND",g_state.trendStrength*100,x+8,kY+74,140,g_state.trendStrength>=g_state.bullThreshold?COLOR_GREEN:COLOR_TEAL);
   Meter("VM", "VOLATILITY",g_state.volatilityIndex*100,x+8,kY+100,140,COLOR_ORANGE);
   Meter("SM", "SENTIMENT",g_state.sentimentScore*100,x+8,kY+126,140,COLOR_TEAL);
   KV("HS1","REGIME",g_state.regime,x+220,kY+75,60,COLOR_GOLD);
   KV("HS2","ATR",StringFormat("%.*f",_Digits,g_state.atrPrice),x+220,kY+101,60,COLOR_TEXT);
   KV("HS3","SPREAD",StringFormat("%.2f pips",g_state.currentSpreadPips),x+220,kY+127,60,g_state.currentSpreadPips<=g_state.maxSpreadPips?COLOR_GREEN:COLOR_RED);
   KV("HS4","BUY / SELL",StringFormat("%d / %d",g_state.buyPositions,g_state.sellPositions),x+210,kY+75,72,COLOR_TEXT);
   KV("HS5","B.P / S.P",StringFormat("%d / %d",g_state.buyPending,g_state.sellPending),x+210,kY+101,72,COLOR_TEXT);
   KV("HS6","EXEC",g_state.executionStatus,x+210,kY+127,72,COLOR_TEXT);
}

string CompactGridName(ENUM_GRID_TYPE type)
{
   switch(type)
   {
      case BASIC_GRID: return "BASIC";
      case HEDGE_GRID: return "HEDGE";
      case TREND_GRID: return "TREND";
      case VOLATILITY_GRID: return "VOLATILITY";
      case AI_GRID: return "AI GRID";
      case GEOMETRIC_GRID: return "GEOMETRIC";
      case FIBONACCI_GRID: return "FIBONACCI";
      case ATR_ADAPTIVE_GRID: return "ATR ADAPT";
      case MEAN_REVERSION_GRID: return "MEAN REV";
      case BREAKOUT_GRID: return "BREAKOUT";
      case MOMENTUM_GRID: return "MOMENTUM";
      case HYBRID_GRID: return "HYBRID";
      case BULLISH_GRID: return "BULLISH";
      case BEARISH_GRID: return "BEARISH";
      case BIDIRECTIONAL_GRID: return "BIDIR";
      case LADDER_GRID: return "LADDER";
      case ANTI_MARTINGALE_GRID: return "ANTI-MART";
      case RANGE_SCALING_GRID: return "RANGE SCALE";
      case VOLATILITY_BREAKOUT_GRID: return "VOL BREAK";
      case SESSION_GRID: return "SESSION";
      case SMART_REGIME_GRID: return "SMART REGIME";
   }
   return "GRID";
}

void CreateGridLabTab()
{
   int x=g_dashboard.x+10,y=g_dashboard.y+93,w=g_dashboard.width-20,h=g_dashboard.height-124;
   int gap=8;
   int topH=MathMin(155,MathMax(145,h/3));
   int gridY=y+topH+gap;
   int gridH=h-topH-gap;

   Section("GRIDA","GRID ENGINE",x,y,w/2-gap/2,topH);
   int leftW=w/2-gap/2;
   KV("GA1","TYPE",CompactGridName(g_state.gridType),x+10,y+34,55,COLOR_GOLD);
   KV("GA2","ENTRY",g_state.entryMode==MANUAL_ENTRY?"MANUAL":g_state.entryMode==AUTO_ENTRY?"AUTO":g_state.entryMode==AI_ENTRY?"AI":"TIME",x+10,y+59,55,COLOR_TEXT);
   KV("GA3","LOT",DoubleToString(g_state.lotSize,3),x+10,y+84,55,COLOR_TEXT);
   KV("GA4","MULT",DoubleToString(g_state.lotMultiplier,2),x+10,y+109,55,COLOR_TEXT);
   KV("GA5","STEP",DoubleToString(g_state.gridStep,1),x+leftW/2,y+34,55,COLOR_TEXT);
   KV("GA6","LEVELS",IntegerToString(g_state.gridLevels),x+leftW/2,y+59,55,COLOR_TEXT);
   KV("GA7","ATR SPACE",g_state.useATRSpacing?"ON":"OFF",x+leftW/2,y+84,55,g_state.useATRSpacing?COLOR_GREEN:COLOR_MUTED);
   KV("GA8","RECENTER",g_state.autoRecenter?"ON":"OFF",x+leftW/2,y+109,55,g_state.autoRecenter?COLOR_GREEN:COLOR_MUTED);

   int rx=x+leftW+gap;
   Section("GRIDR","CAPACITY & STATE",rx,y,w-leftW-gap,topH);
   KV("GR1","POSITIONS",StringFormat("%d / %d",g_state.positionCount,g_state.maxPositions),rx+10,y+34,70,COLOR_TEXT);
   KV("GR2","PENDING",StringFormat("%d / %d",g_state.pendingCount,g_state.maxPendingOrders),rx+10,y+59,70,COLOR_GOLD);
   KV("GR3","BUY / SELL",StringFormat("%d / %d",g_state.buyPositions,g_state.sellPositions),rx+10,y+84,70,COLOR_TEXT);
   KV("GR4","B.P / S.P",StringFormat("%d / %d",g_state.buyPending,g_state.sellPending),rx+10,y+109,70,COLOR_TEXT);

   Section("GRIDLIST","21 GRID MODES",x,gridY,w,gridH);
   int bx=x+9,by=gridY+32;
   int cols=3,bw=(w-26)/cols,bh=24;
   for(int i=0;i<GRID_TYPE_COUNT;i++)
   {
      int row=i/cols,c=i%cols;
      int py=by+row*27;
      CreateBtn(ObjName("GRID_SEL_"+IntegerToString(i)),StringFormat("%02d  %s",i+1,CompactGridName((ENUM_GRID_TYPE)i)),bx+c*(bw+4),py,bw,bh,i==(int)g_state.gridType?COLOR_ACCENT:COLOR_PANEL,false,8);
   }
   int sy=by+7*27+2;
   CreateBtn(ObjName("BTN_GRID_REBUILD"),"REBUILD GRID",x+9,sy, (w-22)/2,27,COLOR_GOLD,false,8);
   CreateText(ObjName("GRIDNOTE"),StringFormat("ANCHOR %.*f  |  ATR %.2f  |  REENTRY %d",_Digits,g_state.anchorPrice,g_state.atrPrice,(int)g_state.reentryMode),x+18+(w-22)/2,sy+7,8,COLOR_MUTED,"Arial");
}

void CreateRiskTab()
{
   int x=g_dashboard.x+10,y=g_dashboard.y+93,w=g_dashboard.width-20,h=g_dashboard.height-124;
   int gap=8,col=(w-gap)/2;
   Section("RKA","RISK ENGINE",x,y,col,132);
   CreateBtn(ObjName("BTN_RISK_MODE"),"PROFILE  "+(g_state.riskMode==CONSERVATIVE?"CONSERVATIVE":g_state.riskMode==BALANCED?"BALANCED":g_state.riskMode==AGGRESSIVE?"AGGRESSIVE":"ADAPTIVE"),x+9,y+32,col-18,28,COLOR_ACCENT,false,8);
   CreateBtn(ObjName("BTN_RISK_MANAGED"),g_state.riskManagedTrading?"RISK MANAGEMENT ON":"RISK MANAGEMENT OFF",x+9,y+65,col-18,28,g_state.riskManagedTrading?COLOR_GREEN:COLOR_RED,g_state.riskManagedTrading,8);
   KV("RKS1","DYNAMIC LOT",g_state.useDynamicRiskLot?"ON":"OFF",x+9,y+101,74,g_state.useDynamicRiskLot?COLOR_GREEN:COLOR_MUTED);
   KV("RKS2","GRID RISK",StringFormat("%.2f%%",g_state.riskPerGridPct),x+col/2,y+101,68,COLOR_TEXT);

   Section("RKB","PROTECTION FOR NEW ORDERS",x+col+gap,y,col,132);
   CreateBtn(ObjName("BTN_NEW_ORDER_SL"),g_state.useStopLossForNewOrders?"STOP LOSS  ON":"STOP LOSS  OFF",x+col+gap+9,y+32,col-18,28,g_state.useStopLossForNewOrders?COLOR_GREEN:COLOR_RED,g_state.useStopLossForNewOrders,8);
   CreateBtn(ObjName("BTN_NEW_ORDER_TP"),g_state.useTakeProfitForNewOrders?"TAKE PROFIT ON":"TAKE PROFIT OFF",x+col+gap+9,y+65,col-18,28,g_state.useTakeProfitForNewOrders?COLOR_GREEN:COLOR_RED,g_state.useTakeProfitForNewOrders,8);
   KV("RKP1","SL DIST",StringFormat("%.1f pips",g_state.stopLossPips),x+col+gap+9,y+101,55,COLOR_TEXT);
   KV("RKP2","TP DIST",StringFormat("%.1f pips",g_state.takeProfitPips),x+col+gap+col/2,y+101,55,COLOR_TEXT);

   int yy=y+140;
   Section("RKC","RISK LIMITS",x,yy,col,h-148);
   KV("RKL1","MAX GRID",StringFormat("%.2f%%",g_state.maxGridRiskPct),x+9,yy+34,70,COLOR_TEXT);
   KV("RKL2","MAX DD",StringFormat("%.2f%%",g_state.maxDrawdownPct),x+9,yy+59,70,COLOR_TEXT);
   KV("RKL3","DAILY LOSS",StringFormat("%.2f%%",g_state.dailyLossLimitPct),x+9,yy+84,70,COLOR_TEXT);
   KV("RKL4","PROFIT LOCK",StringFormat("%.2f%%",g_state.dailyProfitLockPct),x+9,yy+109,70,COLOR_TEXT);
   KV("RKL5","BASKET TP",FormatNumber(g_state.basketTakeProfitUSD),x+9,yy+134,70,COLOR_TEXT);
   KV("RKL6","BASKET SL",FormatNumber(g_state.basketStopLossUSD),x+9,yy+159,70,COLOR_TEXT);
   Meter("RKM1","DD USED",g_state.maxDrawdownPct>0?MathMin(100.0,MathMax(0.0,g_state.maxDrawdown/g_state.maxDrawdownPct*100.0)):0,x+9,yy+192,col-30,g_state.maxDrawdown>g_state.maxDrawdownPct*0.8?COLOR_RED:COLOR_GREEN);
   Meter("RKM2","DAILY LOSS",g_state.dailyLossLimitPct>0?MathMin(100.0,MathMax(0.0,-MathMin(0.0,g_state.todayProfit)/MathMax(1.0,AccountInfoDouble(ACCOUNT_BALANCE))*100.0/g_state.dailyLossLimitPct)):0,x+9,yy+220,col-30,COLOR_ORANGE);
   CreateBtn(ObjName("BTN_RISK_APPLY"),"APPLY RISK PROFILE",x+9,yy+h-181,col-18,28,COLOR_GOLD,false,8);

   Section("RKD","PROTECTION LOGIC",x+col+gap,yy,col,h-148);
   KV("RKT1","BREAK-EVEN",g_state.breakEven?"ON":"OFF",x+col+gap+9,yy+34,80,g_state.breakEven?COLOR_GREEN:COLOR_MUTED);
   KV("RKT2","TRAILING",g_state.trailingStop?"ON":"OFF",x+col+gap+9,yy+59,80,g_state.trailingStop?COLOR_GREEN:COLOR_MUTED);
   KV("RKT3","BE TRIGGER",StringFormat("%.1f pips",g_state.breakEvenTriggerPips),x+col+gap+9,yy+84,80,COLOR_TEXT);
   KV("RKT4","BE OFFSET",StringFormat("%.1f pips",g_state.breakEvenOffsetPips),x+col+gap+9,yy+109,80,COLOR_TEXT);
   KV("RKT5","TRAIL ATR",DoubleToString(g_state.trailingATRMultiple,2),x+col+gap+9,yy+134,80,COLOR_TEXT);
   KV("RKT6","MAX HOLD",StringFormat("%.0f min",g_state.maxHoldMinutes),x+col+gap+9,yy+159,80,COLOR_TEXT);
   KV("RKT7","OCO",g_state.oco?"ON":"OFF",x+col+gap+9,yy+184,80,g_state.oco?COLOR_GREEN:COLOR_MUTED);
   KV("RKT8","OPPOSITE",g_state.closeOppositeOnFill?"CLOSE":"KEEP",x+col+gap+col/2,yy+184,68,g_state.closeOppositeOnFill?COLOR_GREEN:COLOR_MUTED);
}

void CreateAnalyticsTab()
{
   int x=g_dashboard.x+10,y=g_dashboard.y+93,w=g_dashboard.width-20,h=g_dashboard.height-124;
   int gap=8,col=(w-gap)/2;
   Section("ANA","MARKET STATE",x,y,col,170);
   CreateText(ObjName("ANREG"),g_state.regime,x+10,y+34,12,COLOR_GOLD,"Arial Bold");
   Meter("ANT", "TREND",g_state.trendStrength*100,x+10,y+66,col-30,g_state.trendStrength>=0.6?COLOR_GREEN:COLOR_TEAL);
   Meter("ANV", "VOLATILITY",g_state.volatilityIndex*100,x+10,y+94,col-30,COLOR_ORANGE);
   Meter("ANS", "SENTIMENT",g_state.sentimentScore*100,x+10,y+122,col-30,COLOR_TEAL);
   KV("AN1","ATR",StringFormat("%.*f",_Digits,g_state.atrPrice),x+10,y+150,45,COLOR_TEXT);

   Section("ANB","PERFORMANCE",x+col+gap,y,col,170);
   KV("AP1","TOTAL TRADES",IntegerToString(g_state.totalTrades),x+col+gap+10,y+35,82,COLOR_TEXT);
   KV("AP2","WINS",IntegerToString(g_state.wins),x+col+gap+10,y+60,82,COLOR_GREEN);
   KV("AP3","LOSSES",IntegerToString(g_state.losses),x+col+gap+10,y+85,82,COLOR_RED);
   KV("AP4","WIN RATE",StringFormat("%.1f%%",g_state.winRate),x+col+gap+10,y+110,82,COLOR_GREEN);
   KV("AP5","TOTAL P/L",FormatNumber(g_state.totalProfit),x+col+gap+10,y+135,82,g_state.totalProfit>=0?COLOR_GREEN:COLOR_RED);
   KV("AP6","TODAY",FormatNumber(g_state.todayProfit),x+col+gap+col/2,y+35,55,g_state.todayProfit>=0?COLOR_GREEN:COLOR_RED);
   KV("AP7","DD",StringFormat("%.2f%%",g_state.maxDrawdown),x+col+gap+col/2,y+60,55,COLOR_TEXT);
   KV("AP8","REBALANCES",IntegerToString(g_state.rebalances),x+col+gap+col/2,y+85,55,COLOR_TEXT);
   KV("AP9","ACCEPTED",IntegerToString(g_state.acceptedOrders),x+col+gap+col/2,y+110,55,COLOR_GREEN);
   KV("AP10","REJECTED",IntegerToString(g_state.rejectedOrders),x+col+gap+col/2,y+135,55,g_state.rejectedOrders?COLOR_ORANGE:COLOR_GREEN);

   int yy=y+178;
   Section("ANC","LIVE MARKET TELEMETRY",x,yy,w,h-178);
   KV("AT1","SYMBOL",_Symbol,x+10,yy+34,70,COLOR_GOLD);
   KV("AT2","TIMEFRAME",EnumToString((ENUM_TIMEFRAMES)_Period),x+10,yy+59,70,COLOR_TEXT);
   KV("AT3","SPREAD",StringFormat("%.2f pips",g_state.currentSpreadPips),x+10,yy+84,70,COLOR_TEXT);
   KV("AT4","GRID P/L",FormatNumber(g_state.currentProfit),x+10,yy+109,70,g_state.currentProfit>=0?COLOR_GREEN:COLOR_RED);
   KV("AT5","EQUITY",FormatNumber(AccountInfoDouble(ACCOUNT_EQUITY)),x+10,yy+134,70,COLOR_TEXT);
   KV("AT6","BALANCE",FormatNumber(AccountInfoDouble(ACCOUNT_BALANCE)),x+10,yy+159,70,COLOR_TEXT);
   Meter("ATE","EQUITY DD",g_state.maxDrawdownPct>0?MathMin(100.0,g_state.maxDrawdown/g_state.maxDrawdownPct*100.0):0,x+260,yy+34,150,g_state.maxDrawdown>g_state.maxDrawdownPct*0.8?COLOR_RED:COLOR_GREEN);
   Meter("ATRISK","RISK LOAD",g_state.maxGridRiskPct>0?MathMin(100.0,g_state.riskPerGridPct/g_state.maxGridRiskPct*100.0):0,x+260,yy+64,150,COLOR_GOLD);
}

void CreateAITab()
{
   int x=g_dashboard.x+10,y=g_dashboard.y+93,w=g_dashboard.width-20,h=g_dashboard.height-124;
   int gap=8,col=(w-gap)/2;
   Section("AIA","AI ENGINE",x,y,col,155);
   CreateBtn(ObjName("BTN_AI_TOGGLE"),g_state.aiEnabled?"AI ENGINE ON":"AI ENGINE OFF",x+9,y+32,col-18,28,g_state.aiEnabled?COLOR_GREEN:COLOR_RED,g_state.aiEnabled,8);
   KV("AIA1","CONFIDENCE",StringFormat("%.0f%%",g_state.aiConfidence*100),x+9,y+72,78,COLOR_TEXT);
   KV("AIA2","LEARNING",IntegerToString(g_state.learningPeriod),x+9,y+97,78,COLOR_TEXT);
   KV("AIA3","NETWORK",g_state.neuralNetwork?"ON":"OFF",x+9,y+122,78,g_state.neuralNetwork?COLOR_GREEN:COLOR_MUTED);

   Section("AIB","AI SIGNAL",x+col+gap,y,col,155);
   KV("AIS1","TREND",StringFormat("%.0f%%",g_state.trendStrength*100),x+col+gap+9,y+34,65,COLOR_GREEN);
   KV("AIS2","SENTIMENT",StringFormat("%.0f%%",g_state.sentimentScore*100),x+col+gap+9,y+59,65,COLOR_TEAL);
   KV("AIS3","VOLATILITY",StringFormat("%.0f%%",g_state.volatilityIndex*100),x+col+gap+9,y+84,65,COLOR_ORANGE);
   KV("AIS4","PREDICTION",StringFormat("%.0f%%",g_state.predictionAccuracy*100),x+col+gap+9,y+109,65,COLOR_GOLD);
   KV("AIS5","REGIME",g_state.regime,x+col+gap+9,y+134,65,COLOR_GOLD);

   int yy=y+163;
   Section("AIC","REGIME THRESHOLDS",x,yy,col,h-163);
   KV("ART1","BULL",StringFormat("%.2f",g_state.bullThreshold),x+9,yy+34,60,COLOR_GREEN);
   KV("ART2","BEAR",StringFormat("%.2f",g_state.bearThreshold),x+9,yy+59,60,COLOR_RED);
   KV("ART3","HIGH VOL",StringFormat("%.2f",g_state.highVolThreshold),x+9,yy+84,60,COLOR_ORANGE);
   KV("ART4","LOW VOL",StringFormat("%.2f",g_state.lowVolThreshold),x+9,yy+109,60,COLOR_TEAL);
   CreateBtn(ObjName("BTN_AI_RESET"),"RESET AI METRICS",x+9,yy+h-211,col-18,28,COLOR_PANEL2,false,8);

   Section("AID","AI / FILTER STATUS",x+col+gap,yy,col,h-163);
   KV("ARF1","AI",g_state.aiEnabled?"ON":"OFF",x+col+gap+9,yy+34,55,g_state.aiEnabled?COLOR_GREEN:COLOR_MUTED);
   KV("ARF2","REGIME",g_state.regimeFilter?"ON":"OFF",x+col+gap+9,yy+59,55,g_state.regimeFilter?COLOR_GREEN:COLOR_MUTED);
   KV("ARF3","AUTO GRID",g_state.autonomousMode?"ON":"OFF",x+col+gap+9,yy+84,55,g_state.autonomousMode?COLOR_GREEN:COLOR_MUTED);
   KV("ARF4","RISK LOT",g_state.useDynamicRiskLot?"ON":"OFF",x+col+gap+9,yy+109,55,g_state.useDynamicRiskLot?COLOR_GREEN:COLOR_MUTED);
}

void CreateExecutionTab()
{
   int x=g_dashboard.x+10,y=g_dashboard.y+93,w=g_dashboard.width-20,h=g_dashboard.height-124;
   int gap=8,col=(w-gap)/2;
   Section("EXA","EXECUTION HEALTH",x,y,col,170);
   KV("EX1","STATUS",g_state.executionStatus,x+9,y+34,55,COLOR_GOLD);
   KV("EX2","SPREAD",StringFormat("%.2f / %.2f",g_state.currentSpreadPips,g_state.maxSpreadPips),x+9,y+59,55,g_state.currentSpreadPips<=g_state.maxSpreadPips?COLOR_GREEN:COLOR_RED);
   KV("EX3","SLIPPAGE",IntegerToString(g_state.slippage),x+9,y+84,55,COLOR_TEXT);
   KV("EX4","SMART",g_state.smartExecution?"ON":"OFF",x+9,y+109,55,g_state.smartExecution?COLOR_GREEN:COLOR_MUTED);
   KV("EX5","VALIDATE",g_state.validateStops?"ON":"OFF",x+col/2,y+34,65,g_state.validateStops?COLOR_GREEN:COLOR_MUTED);
   KV("EX6","RETRIES",IntegerToString(g_state.orderRetryCount),x+col/2,y+59,65,COLOR_TEXT);
   KV("EX7","EXPIRY",StringFormat("%d min",g_state.pendingExpiryMinutes),x+col/2,y+84,65,COLOR_TEXT);
   KV("EX8","ASYNC SAFE",InpUseAsyncSafety?"ON":"OFF",x+col/2,y+109,65,InpUseAsyncSafety?COLOR_GREEN:COLOR_MUTED);
   CreateBtn(ObjName("BTN_SMART"),g_state.smartExecution?"SMART EXECUTION ON":"SMART EXECUTION OFF",x+9,y+136,col-18,26,g_state.smartExecution?COLOR_GREEN:COLOR_PANEL,g_state.smartExecution,8);

   Section("EXB","MARKET FILTERS",x+col+gap,y,col,170);
   KV("MF1","SESSION",g_state.useSessionFilter?"FILTERED":"OPEN",x+col+gap+9,y+34,60,g_state.useSessionFilter?COLOR_ORANGE:COLOR_GREEN);
   KV("MF2","WEEKEND",g_state.avoidWeekend?"BLOCK":"OPEN",x+col+gap+9,y+59,60,g_state.avoidWeekend?COLOR_GREEN:COLOR_MUTED);
   KV("MF3","HIGH VOL",g_state.pauseHighVolatility?"PAUSE":"ALLOW",x+col+gap+9,y+84,60,g_state.pauseHighVolatility?COLOR_ORANGE:COLOR_GREEN);
   KV("MF4","REGIME",g_state.regimeFilter?"ON":"OFF",x+col+gap+9,y+109,60,g_state.regimeFilter?COLOR_GREEN:COLOR_MUTED);
   KV("MF5","SESSION",StringFormat("%02d-%02d",g_state.sessionStartHour,g_state.sessionEndHour),x+col+gap+9,y+134,60,COLOR_TEXT);

   int yy=y+178;
   Section("EXC","ORDER FLOW",x,yy,w,h-178);
   KV("OF1","ACCEPTED",IntegerToString(g_state.acceptedOrders),x+10,yy+34,72,COLOR_GREEN);
   KV("OF2","REJECTED",IntegerToString(g_state.rejectedOrders),x+10,yy+59,72,g_state.rejectedOrders?COLOR_RED:COLOR_GREEN);
   KV("OF3","OPEN POS",IntegerToString(g_state.positionCount),x+10,yy+84,72,COLOR_TEXT);
   KV("OF4","PENDING",IntegerToString(g_state.pendingCount),x+10,yy+109,72,COLOR_GOLD);
   KV("OF5","BUY / SELL",StringFormat("%d / %d",g_state.buyPositions,g_state.sellPositions),x+10,yy+134,72,COLOR_TEXT);
   KV("OF6","B.P / S.P",StringFormat("%d / %d",g_state.buyPending,g_state.sellPending),x+10,yy+159,72,COLOR_TEXT);
   Meter("OFR","PENDING LOAD",g_state.maxPendingOrders>0?g_state.pendingCount*100.0/g_state.maxPendingOrders:0,x+260,yy+40,150,COLOR_GOLD);
   Meter("OFP","POSITION LOAD",g_state.maxPositions>0?g_state.positionCount*100.0/g_state.maxPositions:0,x+260,yy+80,150,COLOR_TEAL);
}

void CreateMonitorTab()
{
   int x=g_dashboard.x+10,y=g_dashboard.y+93,w=g_dashboard.width-20,h=g_dashboard.height-124;
   int gap=8,col=(w-gap)/2;
   Section("TRA","TRADE SUMMARY",x,y,col,170);
   KV("TS1","POSITIONS",IntegerToString(g_state.positionCount),x+9,y+34,70,COLOR_TEXT);
   KV("TS2","PENDING",IntegerToString(g_state.pendingCount),x+9,y+59,70,COLOR_GOLD);
   KV("TS3","BUY POS",IntegerToString(g_state.buyPositions),x+9,y+84,70,COLOR_GREEN);
   KV("TS4","SELL POS",IntegerToString(g_state.sellPositions),x+9,y+109,70,COLOR_RED);
   KV("TS5","BUY PEND",IntegerToString(g_state.buyPending),x+col/2,y+34,70,COLOR_GREEN);
   KV("TS6","SELL PEND",IntegerToString(g_state.sellPending),x+col/2,y+59,70,COLOR_RED);
   KV("TS7","CURRENT P/L",FormatNumber(g_state.currentProfit),x+col/2,y+84,70,g_state.currentProfit>=0?COLOR_GREEN:COLOR_RED);
   KV("TS8","TODAY",FormatNumber(g_state.todayProfit),x+col/2,y+109,70,g_state.todayProfit>=0?COLOR_GREEN:COLOR_RED);

   Section("TRB","TRADE SAFETY",x+col+gap,y,col,170);
   KV("SA1","SL",g_state.useStopLossForNewOrders?"ON":"OFF",x+col+gap+9,y+34,70,g_state.useStopLossForNewOrders?COLOR_GREEN:COLOR_RED);
   KV("SA2","TP",g_state.useTakeProfitForNewOrders?"ON":"OFF",x+col+gap+9,y+59,70,g_state.useTakeProfitForNewOrders?COLOR_GREEN:COLOR_RED);
   KV("SA3","BE",g_state.breakEven?"ON":"OFF",x+col+gap+9,y+84,70,g_state.breakEven?COLOR_GREEN:COLOR_MUTED);
   KV("SA4","TRAIL",g_state.trailingStop?"ON":"OFF",x+col+gap+9,y+109,70,g_state.trailingStop?COLOR_GREEN:COLOR_MUTED);
   KV("SA5","OCO",g_state.oco?"ON":"OFF",x+col+gap+col/2,y+34,60,g_state.oco?COLOR_GREEN:COLOR_MUTED);
   KV("SA6","RISK",g_state.riskManagedTrading?"ON":"OFF",x+col+gap+col/2,y+59,60,g_state.riskManagedTrading?COLOR_GREEN:COLOR_RED);

   int yy=y+178;
   Section("TRC","ACCOUNT & SYSTEM",x,yy,w,h-178);
   KV("AC1","EQUITY",FormatNumber(AccountInfoDouble(ACCOUNT_EQUITY)),x+10,yy+34,68,COLOR_TEXT);
   KV("AC2","BALANCE",FormatNumber(AccountInfoDouble(ACCOUNT_BALANCE)),x+10,yy+59,68,COLOR_TEXT);
   KV("AC3","TODAY",FormatNumber(g_state.todayProfit),x+10,yy+84,68,g_state.todayProfit>=0?COLOR_GREEN:COLOR_RED);
   KV("AC4","DD",StringFormat("%.2f%%",g_state.maxDrawdown),x+10,yy+109,68,COLOR_TEXT);
   KV("AC5","TRADES",IntegerToString(g_state.totalTrades),x+10,yy+134,68,COLOR_TEXT);
   KV("AC6","WIN RATE",StringFormat("%.1f%%",g_state.winRate),x+10,yy+159,68,COLOR_GREEN);
   KV("AC7","REGIME",g_state.regime,x+260,yy+34,60,COLOR_GOLD);
   KV("AC8","ATR",StringFormat("%.*f",_Digits,g_state.atrPrice),x+260,yy+59,60,COLOR_TEXT);
   KV("AC9","SPREAD",StringFormat("%.2f",g_state.currentSpreadPips),x+260,yy+84,60,COLOR_TEXT);
   KV("AC10","EXEC",g_state.executionStatus,x+260,yy+109,60,COLOR_TEXT);
   KV("AC11","UPTIME",g_state.startTime>0?IntegerToString((int)((TimeCurrent()-g_state.startTime)/60))+"m":"--",x+260,yy+134,60,COLOR_TEXT);
   KV("AC12","RE-CENTERS",IntegerToString(g_state.rebalances),x+260,yy+159,60,COLOR_TEXT);
}

void SettingsField(string id,string label,string value,int x,int y)
{
   CreateText(ObjName(id+"_L"),label,x,y,8,COLOR_MUTED,"Arial");
   CreateInput(ObjName(id),value,x+86,y-4,62);
}

void CreateSettingsTab()
{
   int x=g_dashboard.x+10,y=g_dashboard.y+93,w=g_dashboard.width-20,h=g_dashboard.height-124;
   int gap=8,col=(w-gap)/2,boxH=(h-8)/2;
   int yy;

   Section("SETG","GRID ENGINE",x,y,col,boxH);
   yy=y+31;
   SettingsField("EDT_STEP","Grid step",DoubleToString(g_state.gridStep,1),x+9,yy); yy+=23;
   SettingsField("EDT_MINSTEP","Min step",DoubleToString(g_state.minGridStep,1),x+9,yy); yy+=23;
   SettingsField("EDT_MAXSTEP","Max step",DoubleToString(g_state.maxGridStep,1),x+9,yy); yy+=23;
   SettingsField("EDT_LEVELS","Levels",IntegerToString(g_state.gridLevels),x+9,yy); yy+=23;
   SettingsField("EDT_LOT","Base lot",DoubleToString(g_state.lotSize,3),x+9,yy); yy+=23;
   SettingsField("EDT_MULT","Lot mult",DoubleToString(g_state.lotMultiplier,2),x+9,yy); yy+=23;
   SettingsField("EDT_ATRM","ATR space",DoubleToString(g_state.atrSpacingMultiplier,2),x+9,yy);
   SettingsField("EDT_RECATR","Recenter ATR",DoubleToString(g_state.recenterATRMultiple,2),x+col/2,yy);
   SettingsField("EDT_MPOS","Max positions",IntegerToString(g_state.maxPositions),x+col/2,yy-23);
   SettingsField("EDT_MPEND","Max pending",IntegerToString(g_state.maxPendingOrders),x+col/2,yy);
   CreateText(ObjName("SETGI"),StringFormat("TYPE %s  |  ENTRY %d  |  MAGIC %I64u  |  RECENTER %s",CompactGridName(g_state.gridType),(int)g_state.entryMode,InpMagicNumber,g_state.autoRecenter?"ON":"OFF"),x+9,y+boxH-47,7,COLOR_MUTED,"Arial");
   CreateText(ObjName("SETGR"),StringFormat("REENTRY %d  |  ATR PERIOD %d  |  DELETE INVALID %s",(int)g_state.reentryMode,InpRecenterATRPeriod,InpDeleteInvalidLevels?"ON":"OFF"),x+9,y+boxH-25,7,COLOR_MUTED,"Arial");

   Section("SETR","RISK & PROTECTION",x+col+gap,y,col,boxH);
   yy=y+31;
   SettingsField("EDT_RISK","Risk/grid %",DoubleToString(g_state.riskPerGridPct,2),x+col+gap+9,yy); yy+=23;
   SettingsField("EDT_MAXGRIDR","Max grid %",DoubleToString(g_state.maxGridRiskPct,2),x+col+gap+9,yy); yy+=23;
   SettingsField("EDT_MAXDD","Max DD %",DoubleToString(g_state.maxDrawdownPct,2),x+col+gap+9,yy); yy+=23;
   SettingsField("EDT_DLOSS","Daily loss %",DoubleToString(g_state.dailyLossLimitPct,2),x+col+gap+9,yy); yy+=23;
   SettingsField("EDT_DPROF","Profit lock %",DoubleToString(g_state.dailyProfitLockPct,2),x+col+gap+9,yy); yy+=23;
   SettingsField("EDT_BTP","Basket TP $",DoubleToString(g_state.basketTakeProfitUSD,2),x+col+gap+9,yy); yy+=23;
   SettingsField("EDT_BSL","Basket SL $",DoubleToString(g_state.basketStopLossUSD,2),x+col+gap+9,yy);
   SettingsField("EDT_SL","SL pips",DoubleToString(g_state.stopLossPips,1),x+col+gap+col/2,yy-23);
   SettingsField("EDT_TP","TP pips",DoubleToString(g_state.takeProfitPips,1),x+col+gap+col/2,yy);
   SettingsField("EDT_MHOLD","Max hold",DoubleToString(g_state.maxHoldMinutes,0),x+col+gap+col/2,yy+23);
   SettingsField("EDT_BE","BE trigger",DoubleToString(g_state.breakEvenTriggerPips,1),x+col+gap+col/2,yy+46);
   SettingsField("EDT_BEOFF","BE offset",DoubleToString(g_state.breakEvenOffsetPips,1),x+col+gap+col/2,yy+69);
   CreateText(ObjName("SETRI"),StringFormat("RISK ENGINE %s  |  DYNAMIC LOT %s  |  SL %s  |  TP %s",g_state.riskManagedTrading?"ON":"OFF",g_state.useDynamicRiskLot?"ON":"OFF",g_state.useStopLossForNewOrders?"ON":"OFF",g_state.useTakeProfitForNewOrders?"ON":"OFF"),x+col+gap+9,y+boxH-25,7,COLOR_MUTED,"Arial");

   int y2=y+boxH+gap;
   Section("SETAI","AI / EXECUTION",x,y2,col,boxH);
   int bw3=(col-26)/3;
   CreateBtn(ObjName("BTN_APPLY"),"APPLY",x+9,y2+31,bw3,26,COLOR_GOLD,false,8);
   CreateBtn(ObjName("BTN_RESET"),"RESET",x+13+bw3,y2+31,bw3,26,COLOR_RED,false,8);
   CreateBtn(ObjName("BTN_SMART"),g_state.smartExecution?"SMART ON":"SMART OFF",x+17+2*bw3,y2+31,bw3,26,g_state.smartExecution?COLOR_GREEN:COLOR_PANEL,g_state.smartExecution,8);

   yy=y2+67;
   SettingsField("EDT_CONF","AI confidence",DoubleToString(g_state.aiConfidence,2),x+9,yy); yy+=23;
   SettingsField("EDT_LEARN","Learning",IntegerToString(g_state.learningPeriod),x+9,yy); yy+=23;
   SettingsField("EDT_BULL","Bull threshold",DoubleToString(g_state.bullThreshold,2),x+9,yy); yy+=23;
   SettingsField("EDT_BEAR","Bear threshold",DoubleToString(g_state.bearThreshold,2),x+9,yy); yy+=23;
   SettingsField("EDT_HIVOL","High vol",DoubleToString(g_state.highVolThreshold,2),x+9,yy); yy+=23;
   SettingsField("EDT_LOVOL","Low vol",DoubleToString(g_state.lowVolThreshold,2),x+9,yy);
   SettingsField("EDT_SLIP","Slippage",IntegerToString(g_state.slippage),x+col/2,yy-46);
   SettingsField("EDT_EXP","Expiry min",IntegerToString(g_state.pendingExpiryMinutes),x+col/2,yy-23);
   SettingsField("EDT_SPR","Max spread",DoubleToString(g_state.maxSpreadPips,1),x+col/2,yy);
   SettingsField("EDT_TRAIL","Trail ATR",DoubleToString(g_state.trailingATRMultiple,2),x+col/2,yy+23);
   CreateText(ObjName("SETNET"),StringFormat("AI %s  |  NETWORK %s  |  REGIME %s",g_state.aiEnabled?"ON":"OFF",g_state.neuralNetwork?"ON":"OFF",g_state.regimeFilter?"ON":"OFF"),x+col/2,yy+48,8,COLOR_MUTED,"Arial Bold");

   int fg=(col-34)/3;
   int ty=y2+boxH-55;
   CreateBtn(ObjName("FLG_AUTO"),g_state.autonomousMode?"AUTO ON":"AUTO OFF",x+9,ty,fg,22,g_state.autonomousMode?COLOR_GREEN:COLOR_PANEL,g_state.autonomousMode,8);
   CreateBtn(ObjName("FLG_ATR"),g_state.useATRSpacing?"ATR ON":"ATR OFF",x+17+fg,ty,fg,22,g_state.useATRSpacing?COLOR_GREEN:COLOR_PANEL,g_state.useATRSpacing,8);
   CreateBtn(ObjName("FLG_RISK"),g_state.useDynamicRiskLot?"RISK LOT ON":"RISK LOT OFF",x+25+fg*2,ty,fg,22,g_state.useDynamicRiskLot?COLOR_GREEN:COLOR_PANEL,g_state.useDynamicRiskLot,8);
   ty+=24;
   CreateBtn(ObjName("FLG_BE"),g_state.breakEven?"BE ON":"BE OFF",x+9,ty,fg,22,g_state.breakEven?COLOR_GREEN:COLOR_PANEL,g_state.breakEven,8);
   CreateBtn(ObjName("FLG_TRAIL"),g_state.trailingStop?"TRAIL ON":"TRAIL OFF",x+17+fg,ty,fg,22,g_state.trailingStop?COLOR_GREEN:COLOR_PANEL,g_state.trailingStop,8);
   CreateBtn(ObjName("FLG_VALIDATE"),g_state.validateStops?"CHECK ON":"CHECK OFF",x+25+fg*2,ty,fg,22,g_state.validateStops?COLOR_GREEN:COLOR_PANEL,g_state.validateStops,8);

   Section("SETF","FILTERS / CHART",x+col+gap,y2,col,boxH);
   yy=y2+31;
   SettingsField("EDT_SSTART","Session start",IntegerToString(g_state.sessionStartHour),x+col+gap+9,yy); yy+=23;
   SettingsField("EDT_SEND","Session end",IntegerToString(g_state.sessionEndHour),x+col+gap+9,yy); yy+=23;
   CreateText(ObjName("SETREC"),StringFormat("RECENTER ATR  %.2f  |  AUTO %s",g_state.recenterATRMultiple,g_state.autoRecenter?"ON":"OFF"),x+col+gap+9,yy,8,COLOR_MUTED,"Arial Bold"); yy+=23;
   CreateText(ObjName("SETCH1"),StringFormat("AUTO THEME %s",g_state.autoChartTheme?"ON":"OFF"),x+col+gap+9,yy,8,COLOR_MUTED,"Arial Bold");
   CreateText(ObjName("SETCH2"),StringFormat("GRID %s  |  TRADE LEVELS %s",InpChartShowGrid?"ON":"OFF",InpChartShowTradeLevels?"ON":"OFF"),x+col+gap+9,yy+22,8,COLOR_MUTED,"Arial Bold");
   CreateText(ObjName("SETCH3"),StringFormat("AUTO SCROLL %s  |  SHIFT %s  |  VOLUME %s",InpChartAutoScroll?"ON":"OFF",InpChartShift?"ON":"OFF",InpChartShowVolumes?"ON":"OFF"),x+col+gap+9,yy+44,8,COLOR_MUTED,"Arial Bold");
   CreateText(ObjName("SETCH4"),StringFormat("RETRY %d  |  ASYNC %s",g_state.orderRetryCount,InpUseAsyncSafety?"ON":"OFF"),x+col+gap+9,yy+66,8,COLOR_MUTED,"Arial Bold");
   int rg=(col-26)/2;
   int by=y2+boxH-115;
   CreateBtn(ObjName("FLG_OCO"),g_state.oco?"OCO ON":"OCO OFF",x+col+gap+9,by,rg,22,g_state.oco?COLOR_GREEN:COLOR_PANEL,g_state.oco,8);
   CreateBtn(ObjName("FLG_OPP"),g_state.closeOppositeOnFill?"OPPOSITE CLOSE":"OPPOSITE KEEP",x+col+gap+17+rg,by,rg,22,g_state.closeOppositeOnFill?COLOR_GREEN:COLOR_PANEL,g_state.closeOppositeOnFill,8);
   by+=24;
   CreateBtn(ObjName("FLG_REGIME"),g_state.regimeFilter?"REGIME ON":"REGIME OFF",x+col+gap+9,by,rg,22,g_state.regimeFilter?COLOR_GREEN:COLOR_PANEL,g_state.regimeFilter,8);
   CreateBtn(ObjName("FLG_WEEK"),g_state.avoidWeekend?"WEEKEND BLOCK":"WEEKEND OPEN",x+col+gap+17+rg,by,rg,22,g_state.avoidWeekend?COLOR_GREEN:COLOR_PANEL,g_state.avoidWeekend,8);
   by+=24;
   CreateBtn(ObjName("FLG_HIV"),g_state.pauseHighVolatility?"HIGH-VOL PAUSE":"HIGH-VOL ALLOW",x+col+gap+9,by,rg,22,g_state.pauseHighVolatility?COLOR_ORANGE:COLOR_PANEL,g_state.pauseHighVolatility,8);
   CreateBtn(ObjName("FLG_SESSION"),g_state.useSessionFilter?"SESSION ON":"SESSION OFF",x+col+gap+17+rg,by,rg,22,g_state.useSessionFilter?COLOR_GREEN:COLOR_PANEL,g_state.useSessionFilter,8);
   by+=24;
   CreateBtn(ObjName("FLG_CHART_AUTO"),g_state.autoChartTheme?"AUTO THEME ON":"AUTO THEME OFF",x+col+gap+9,by,rg,22,g_state.autoChartTheme?COLOR_GREEN:COLOR_PANEL,g_state.autoChartTheme,8);
   CreateBtn(ObjName("BTN_CHART_THEME"),"CHART THEME",x+col+gap+17+rg,by,rg,22,COLOR_ACCENT,false,8);
}

void CreateKPI(string id,string title,string value,int x,int y,int w,int h,color valClr)
{
   CreateRect(ObjName(id+"_P"),x,y,w,h,C'13,22,27',COLOR_PANEL2);
   CreateText(ObjName(id+"_T"),title,x+7,y+7,8,COLOR_MUTED,"Arial Bold");
   CreateText(ObjName(id+"_V"),value,x+7,y+27,12,valClr,"Arial Bold");
}

void CreateDashboard()
{
   if(!g_dashboard.isVisible) return;
   FitDashboard();
   DeleteDashboard();
   DashboardHeader();
   DashboardTabs();
   switch(g_dashboard.currentTab)
   {
      case 0: CreateCommandTab(); break;
      case 1: CreateGridLabTab(); break;
      case 2: CreateRiskTab(); break;
      case 3: CreateAnalyticsTab(); break;
      case 4: CreateAITab(); break;
      case 5: CreateExecutionTab(); break;
      case 6: CreateMonitorTab(); break;
      case 7: CreateSettingsTab(); break;
   }
   FooterBar();
   ChartRedraw();
}

void UpdateDashboard()
{
   static datetime last=0;
   if(TimeCurrent()-last<1) return;
   last=TimeCurrent();
   if(!g_dashboard.isVisible) return;
   // Rebuild on size change so every object always has enough room for its
   // text. This avoids the overlap/small-font behavior of the previous design.
   static int oldW=0,oldH=0;
   int cw=(int)ChartGetInteger(0,CHART_WIDTH_IN_PIXELS);
   int ch=(int)ChartGetInteger(0,CHART_HEIGHT_IN_PIXELS);
   if(cw!=oldW || ch!=oldH){oldW=cw;oldH=ch;CreateDashboard();return;}
   SetText(ObjName("STAT"),g_state.gridActive?"LIVE":"READY",g_state.gridActive?COLOR_GREEN:COLOR_MUTED);
   SetText(ObjName("ACCT"),StringFormat("EQ %s  |  P/L %s",FormatNumber(AccountInfoDouble(ACCOUNT_EQUITY)),FormatNumber(g_state.currentProfit)),g_state.currentProfit>=0?COLOR_GREEN:COLOR_RED);
   if(g_dashboard.currentTab==0)
   {
      SetText(ObjName("K1_V"),FormatNumber(g_state.currentProfit),g_state.currentProfit>=0?COLOR_GREEN:COLOR_RED);
      SetText(ObjName("K2_V"),IntegerToString(g_state.positionCount),COLOR_TEAL);
      SetText(ObjName("K3_V"),IntegerToString(g_state.pendingCount),COLOR_GOLD);
      SetText(ObjName("K4_V"),StringFormat("%.1f%%",g_state.winRate),COLOR_GREEN);
      SetText(ObjName("K5_V"),StringFormat("%.2f%%",g_state.maxDrawdown),g_state.maxDrawdown>g_state.maxDrawdownPct*0.8?COLOR_RED:COLOR_TEXT);
      SetText(ObjName("K6_V"),IntegerToString(g_state.rejectedOrders),g_state.rejectedOrders?COLOR_ORANGE:COLOR_GREEN);
      SetText(ObjName("OVLSTAT"),StringFormat("AUTO %s  |  AI %s",g_state.autonomousMode?"ON":"OFF",g_state.aiEnabled?"ON":"OFF"),COLOR_MUTED);
      SetText(ObjName("GLD2V"),StringFormat("%d / %d",g_state.pendingCount,g_state.maxPendingOrders),COLOR_GOLD);
      SetText(ObjName("HR1V"),g_state.riskMode==CONSERVATIVE?"CONSERVATIVE":g_state.riskMode==BALANCED?"BALANCED":g_state.riskMode==AGGRESSIVE?"AGGRESSIVE":"ADAPTIVE",COLOR_GOLD);
   }
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
   if(g_state.riskPerGridPct>100.0) g_state.riskPerGridPct=100.0;
   if(g_state.maxGridRiskPct<0) g_state.maxGridRiskPct=0;
   if(g_state.maxGridRiskPct>100.0) g_state.maxGridRiskPct=100.0;
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

bool PlaceManagedMarketOrder(bool isBuy,double requestedLots,string comment)
{
   MqlTick tk;
   if(!SymbolInfoTick(_Symbol,tk)) return false;

   double entry=isBuy?tk.ask:tk.bid;
   double stopD=g_state.useStopLossForNewOrders?GetStopDistancePrice():0.0;
   double takeD=g_state.useTakeProfitForNewOrders?GetTakeDistancePrice():0.0;

   double sl=0.0,tp=0.0;
   if(stopD>0.0)
      sl=NormalizeDouble(isBuy?entry-stopD:entry+stopD,_Digits);
   if(takeD>0.0)
      tp=NormalizeDouble(isBuy?entry+takeD:entry-takeD,_Digits);

   double riskDistance=(stopD>0.0?stopD:MathMax(PipSize(),g_state.gridStep*PipSize()));
   double lots=NormalizeLots(requestedLots);
   if(g_state.riskManagedTrading)
      lots=RiskAdjustedLot(lots,riskDistance);
   if(lots<=0.0) return false;

   trade.SetExpertMagicNumber(InpMagicNumber);
   trade.SetDeviationInPoints(g_state.slippage);

   bool result=isBuy
      ? trade.Buy(lots,_Symbol,0,sl,tp,comment)
      : trade.Sell(lots,_Symbol,0,sl,tp,comment);

   if(result) g_state.acceptedOrders++;
   else
   {
      g_state.rejectedOrders++;
      Print("UG7 market order rejected: ",comment," ",trade.ResultRetcodeDescription());
   }
   return result;
}

bool PlaceGridOrder(ENUM_ORDER_TYPE type,double price,double lots,double sl=0,double tp=0)
{
   if(GetPendingCount()>=g_state.maxPendingOrders) return false;
   if(!ValidatePendingPrice(type,price)) { g_state.rejectedOrders++; return false; }
   price=NormalizeDouble(price,_Digits);
   double stopD=g_state.useStopLossForNewOrders?GetStopDistancePrice():0.0;
   double takeD=g_state.useTakeProfitForNewOrders?GetTakeDistancePrice():0.0;
   if(g_state.useStopLossForNewOrders && sl==0 && stopD>0)
   {
      if(type==ORDER_TYPE_BUY_STOP || type==ORDER_TYPE_BUY_LIMIT) sl=price-stopD; else sl=price+stopD;
      sl=NormalizeDouble(sl,_Digits);
   }
   else if(!g_state.useStopLossForNewOrders)
      sl=0.0;

   if(g_state.useTakeProfitForNewOrders && tp==0 && takeD>0)
   {
      if(type==ORDER_TYPE_BUY_STOP || type==ORDER_TYPE_BUY_LIMIT) tp=price+takeD; else tp=price-takeD;
      tp=NormalizeDouble(tp,_Digits);
   }
   else if(!g_state.useTakeProfitForNewOrders)
      tp=0.0;

   double distance=(stopD>0?stopD:MathMax(PipSize(),MathAbs(price-SymbolInfoDouble(_Symbol,SYMBOL_BID))));
   lots=NormalizeLots(lots);
   if(g_state.riskManagedTrading)
      lots=RiskAdjustedLot(lots,distance);
   if(lots<=0) return false;
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
      if(g_state.useStopLossForNewOrders && g_state.breakEven && profit>=g_state.breakEvenTriggerPips)
      {
         double be=(ptype==POSITION_TYPE_BUY?open+g_state.breakEvenOffsetPips*pip:open-g_state.breakEvenOffsetPips*pip);
         if(ptype==POSITION_TYPE_BUY && (sl==0 || be>sl)) newSL=be;
         if(ptype==POSITION_TYPE_SELL && (sl==0 || be<sl)) newSL=be;
      }
      if(g_state.useStopLossForNewOrders && g_state.trailingStop && atr>0)
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
   g_state.useDynamicRiskLot=InpUseDynamicRiskLot; g_state.riskManagedTrading=InpRiskManagedTrading; g_state.useStopLossForNewOrders=InpUseStopLossForNewOrders; g_state.useTakeProfitForNewOrders=InpUseTakeProfitForNewOrders; g_state.riskPerGridPct=InpRiskPerGridPct; g_state.maxGridRiskPct=InpMaxGridRiskPct; g_state.maxDrawdownPct=InpMaxDrawdownPct; g_state.dailyLossLimitPct=InpDailyLossLimitPct; g_state.dailyProfitLockPct=InpDailyProfitLockPct; g_state.basketTakeProfitUSD=InpBasketTakeProfitUSD; g_state.basketStopLossUSD=InpBasketStopLossUSD; g_state.stopLossPips=InpStopLossPips; g_state.takeProfitPips=InpTakeProfitPips;
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
   else if(sparam==ObjName("BTN_AI_TOGGLE")){g_state.aiEnabled=!g_state.aiEnabled;CreateDashboard();}
   else if(sparam==ObjName("BTN_AI_RESET")){g_state.predictionAccuracy=0;g_state.totalTrades=0;g_state.wins=0;g_state.losses=0;CreateDashboard();}
   else if(sparam==ObjName("BTN_RISK_MODE")){g_state.riskMode=(ENUM_RISK_MODE)(((int)g_state.riskMode+1)%4);CreateDashboard();}
   else if(sparam==ObjName("BTN_RISK_MANAGED")){g_state.riskManagedTrading=!g_state.riskManagedTrading;CreateDashboard();}
   else if(sparam==ObjName("BTN_NEW_ORDER_SL")){g_state.useStopLossForNewOrders=!g_state.useStopLossForNewOrders;CreateDashboard();}
   else if(sparam==ObjName("BTN_NEW_ORDER_TP")){g_state.useTakeProfitForNewOrders=!g_state.useTakeProfitForNewOrders;CreateDashboard();}
   else if(sparam==ObjName("BTN_RISK_APPLY")){SyncFromDashboard();ValidateSettings();CreateDashboard();}
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
