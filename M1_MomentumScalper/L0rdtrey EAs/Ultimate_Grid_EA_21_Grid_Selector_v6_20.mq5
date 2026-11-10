//+------------------------------------------------------------------+
//|  Ultimate Grid EA - Professional Edition                        |
//| Advanced Grid Trading System with Modern Dashboard              |
//+------------------------------------------------------------------+
#property strict
#property version   "6.20"
#property description "Professional Grid EA - 21 Selectable Grid Modes"

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

//--------------------------- INPUTS ----------------------------------
input group "=== GRID CONFIGURATION ==="
input ENUM_GRID_TYPE InpGridType = HEDGE_GRID;
input ENUM_ENTRY_MODE InpEntryMode = AUTO_ENTRY;
input double InpLotSize = 0.01;
input double InpGridStep = 20.0;
input int InpGridLevels = 5;
input double InpLotMultiplier = 1.5;
input bool InpAutonomousMode = true;
input ulong InpMagicNumber = 123456;

input group "=== AI SETTINGS ==="
input bool InpEnableAI = true;
input bool InpNeuralNetwork = false;
input double InpAIConfidence = 0.75;
input int InpLearningPeriod = 100;

input group "=== RISK MANAGEMENT ==="
input ENUM_RISK_MODE InpRiskMode = BALANCED;
input double InpMaxRisk = 5.0;
input double InpStopLoss = 100.0;
input double InpTakeProfit = 50.0;
input bool InpTrailingStop = true;

input group "=== EXECUTION ==="
input int InpSlippage = 3;
input double InpMinSpread = 2.0;
input bool InpSmartExecution = true;

//--------------------------- RUNTIME STATE ---------------------------
struct GridState
{
   ENUM_GRID_TYPE gridType;
   ENUM_ENTRY_MODE entryMode;
   ENUM_RISK_MODE riskMode;
   
   double lotSize;
   double gridStep;
   int gridLevels;
   double lotMultiplier;
   bool autonomousMode;
   
   bool aiEnabled;
   bool neuralNetwork;
   double aiConfidence;
   int learningPeriod;
   
   double maxRisk;
   double stopLoss;
   double takeProfit;
   bool trailingStop;
   
   int slippage;
   double minSpread;
   bool smartExecution;
   
   // Runtime
   bool gridActive;
   datetime startTime;
   double initialEquity;
   double currentProfit;
   int positionCount;
   int pendingCount;
   
   // AI Metrics
   double trendStrength;
   double volatilityIndex;
   double sentimentScore;
   double predictionAccuracy;
   
   // Performance
   double totalProfit;
   double winRate;
   int totalTrades;
   double maxDrawdown;
};

GridState g_state;

// Dashboard settings
struct DashboardConfig
{
   int x, y, width, height;
   int currentTab;
   bool isVisible;
   color bgColor;
   color panelColor;
   color textColor;
   color accentColor;
   color goldColor;
};

DashboardConfig g_dashboard;

// Edit field storage
struct EditField
{
   string name;
   string value;
   bool modified;
};

EditField g_editFields[50];
int g_editCount = 0;

//--------------------------- CONSTANTS -------------------------------
const string PREFIX = "UG_";
const int TAB_COUNT = 5;
const int GRID_TYPE_COUNT = 21;
const int GRID_SELECTOR_ROWS = 7;
const int GRID_SELECTOR_COLS = 3;
const string TAB_NAMES[] = {"Overview", "Grid", "AI", "Risk", "Settings"};

// Colors
const color COLOR_BG = clrBlack;
const color COLOR_PANEL = clrDarkSlateGray;
const color COLOR_TEXT = clrWhite;
const color COLOR_ACCENT = clrDodgerBlue;
const color COLOR_GOLD = clrGold;
const color COLOR_GREEN = clrLimeGreen;
const color COLOR_RED = clrTomato;

// Indicator handles
int g_atrHandle = INVALID_HANDLE;
int g_maHandle = INVALID_HANDLE;
int g_rsiHandle = INVALID_HANDLE;

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

bool ShouldStartGrid()
{
   if(!g_state.autonomousMode) return false;
   if(g_state.gridActive) return false;
   
   if(g_state.aiEnabled)
   {
      double trend = CalculateTrendStrength();
      double sentiment = CalculateSentiment();
      
      // AI decision logic
      if(trend > 0.6 && sentiment > 0.6) return true;
      if(trend < 0.4 && sentiment < 0.4) return true;
   }
   
   return false;
}

//--------------------------- GRID MANAGEMENT --------------------------
bool PlaceGridOrder(ENUM_ORDER_TYPE type, double price, double lots, double sl = 0, double tp = 0)
{
   trade.SetExpertMagicNumber(InpMagicNumber);
   trade.SetDeviationInPoints(g_state.slippage);

   bool result = false;
   string comment = "Grid Order";

   switch(type)
   {
      case ORDER_TYPE_BUY_STOP:
         comment = "Grid Buy Stop";
         result = trade.BuyStop(lots, price, _Symbol, sl, tp, ORDER_TIME_GTC, 0, comment);
         break;
      case ORDER_TYPE_SELL_STOP:
         comment = "Grid Sell Stop";
         result = trade.SellStop(lots, price, _Symbol, sl, tp, ORDER_TIME_GTC, 0, comment);
         break;
      case ORDER_TYPE_BUY_LIMIT:
         comment = "Grid Buy Limit";
         result = trade.BuyLimit(lots, price, _Symbol, sl, tp, ORDER_TIME_GTC, 0, comment);
         break;
      case ORDER_TYPE_SELL_LIMIT:
         comment = "Grid Sell Limit";
         result = trade.SellLimit(lots, price, _Symbol, sl, tp, ORDER_TIME_GTC, 0, comment);
         break;
   }

   if(!result)
      Print("Grid order failed. Type=", EnumToString(type),
            " Price=", DoubleToString(price, _Digits),
            " Lots=", DoubleToString(lots, 2),
            " Retcode=", trade.ResultRetcode(),
            " ", trade.ResultRetcodeDescription());

   return result;
}

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

void CloseGrid()
{
   // Close positions
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket > 0 && IsGridOrder(ticket, false))
         trade.PositionClose(ticket, g_state.slippage);
   }
   
   // Cancel orders
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      ulong ticket = OrderGetTicket(i);
      if(ticket > 0 && IsGridOrder(ticket, true))
         trade.OrderDelete(ticket);
   }
   
   g_state.gridActive = false;
   g_state.startTime = 0;
   
   Print("Grid closed");
}

//--------------------------- DASHBOARD CREATION -----------------------
void InitializeDashboard()
{
   g_dashboard.x = 20;
   g_dashboard.y = 50;
   g_dashboard.width = 350;
   g_dashboard.height = 600;
   g_dashboard.currentTab = 0;
   g_dashboard.isVisible = true;
   g_dashboard.bgColor = COLOR_BG;
   g_dashboard.panelColor = COLOR_PANEL;
   g_dashboard.textColor = COLOR_TEXT;
   g_dashboard.accentColor = COLOR_ACCENT;
   g_dashboard.goldColor = COLOR_GOLD;
}

void FitToChart()
{
   int chartW = (int)ChartGetInteger(0, CHART_WIDTH_IN_PIXELS);
   int chartH = (int)ChartGetInteger(0, CHART_HEIGHT_IN_PIXELS);
   
   g_dashboard.width = MathMin(350, chartW - 40);
   g_dashboard.height = MathMin(600, chartH - 100);
   
   if(g_dashboard.x + g_dashboard.width > chartW - 20)
      g_dashboard.x = chartW - g_dashboard.width - 20;
   
   g_dashboard.x = MathMax(20, g_dashboard.x);
   g_dashboard.y = MathMax(50, g_dashboard.y);
}

void CreateHeader()
{
   int x = g_dashboard.x;
   int y = g_dashboard.y;
   int w = g_dashboard.width;
   
   CreatePanel(ObjName("MAIN_BG"), x, y, w, g_dashboard.height, COLOR_BG, COLOR_ACCENT);
   CreatePanel(ObjName("HEADER"), x, y, w, 60, COLOR_PANEL, COLOR_GOLD);
   
   CreateLabel(ObjName("TITLE"), "ULTIMATE GRID EA", x + 15, y + 12, 200, 20, 12, COLOR_GOLD);
   CreateLabel(ObjName("SUBTITLE"), StringFormat("Grid %02d/21 • %s", (int)g_state.gridType + 1, GetGridTypeName(g_state.gridType)), x + 15, y + 32, 260, 16, 8, COLOR_TEXT);
   
   string status = g_state.gridActive ? "ACTIVE" : "STANDBY";
   color statusColor = g_state.gridActive ? COLOR_GREEN : COLOR_TEXT;
   CreateLabel(ObjName("STATUS"), status, x + w - 80, y + 25, 70, 16, 9, statusColor);
}

void CreateTabs()
{
   int x = g_dashboard.x;
   int y = g_dashboard.y + 65;
   int w = g_dashboard.width;
   int tabW = (w - 30) / TAB_COUNT;
   
   for(int i = 0; i < TAB_COUNT; i++)
   {
      bool active = (i == g_dashboard.currentTab);
      color tabColor = active ? COLOR_ACCENT : COLOR_PANEL;
      
      CreateButton(ObjName("TAB_" + IntegerToString(i)), TAB_NAMES[i],
                   x + 10 + i * tabW, y, tabW - 2, 25, tabColor, active);
   }
}

void CreateOverviewTab()
{
   int x = g_dashboard.x + 15;
   int y = g_dashboard.y + 100;
   int w = g_dashboard.width - 30;
   
   // Performance Panel
   CreatePanel(ObjName("PERF_PANEL"), x, y, w, 100, COLOR_PANEL, COLOR_ACCENT);
   CreateLabel(ObjName("PERF_TITLE"), "Performance Overview", x + 10, y + 10, 150, 16, 10, COLOR_GOLD);
   
   double profit = GetGridProfit();
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   int positions = GetPositionCount();
   int pending = GetPendingCount();
   
   color profitColor = profit >= 0 ? COLOR_GREEN : COLOR_RED;
   
   CreateLabel(ObjName("PROFIT_LBL"), "P/L:", x + 15, y + 35, 40, 14, 8, COLOR_TEXT);
   CreateLabel(ObjName("PROFIT_VAL"), FormatNumber(profit), x + 60, y + 35, 80, 14, 9, profitColor);
   
   CreateLabel(ObjName("EQUITY_LBL"), "Equity:", x + 150, y + 35, 50, 14, 8, COLOR_TEXT);
   CreateLabel(ObjName("EQUITY_VAL"), FormatNumber(equity), x + 205, y + 35, 80, 14, 9, COLOR_TEXT);
   
   CreateLabel(ObjName("POS_LBL"), "Positions:", x + 15, y + 55, 70, 14, 8, COLOR_TEXT);
   CreateLabel(ObjName("POS_VAL"), IntegerToString(positions), x + 90, y + 55, 30, 14, 9, COLOR_ACCENT);
   
   CreateLabel(ObjName("PEND_LBL"), "Pending:", x + 150, y + 55, 60, 14, 8, COLOR_TEXT);
   CreateLabel(ObjName("PEND_VAL"), IntegerToString(pending), x + 215, y + 55, 30, 14, 9, COLOR_ACCENT);
   
   CreateLabel(ObjName("WIN_LBL"), "Win Rate:", x + 15, y + 75, 70, 14, 8, COLOR_TEXT);
   CreateLabel(ObjName("WIN_VAL"), DoubleToString(g_state.winRate, 1) + "%", x + 90, y + 75, 60, 14, 9, COLOR_GREEN);
   
   y += 110;
   
   // Control Panel
   CreatePanel(ObjName("CTRL_PANEL"), x, y, w, 80, COLOR_PANEL, COLOR_ACCENT);
   CreateLabel(ObjName("CTRL_TITLE"), "Grid Control", x + 10, y + 10, 100, 16, 10, COLOR_GOLD);
   
   int btnW = (w - 40) / 2;
   CreateButton(ObjName("BTN_START"), "START GRID", x + 15, y + 35, btnW, 30, COLOR_GREEN);
   CreateButton(ObjName("BTN_STOP"), "STOP GRID", x + 25 + btnW, y + 35, btnW, 30, COLOR_RED);
   
   y += 90;
   
   // AI Status Panel
   CreatePanel(ObjName("AI_PANEL"), x, y, w, 120, COLOR_PANEL, COLOR_ACCENT);
   CreateLabel(ObjName("AI_TITLE"), "AI Analytics", x + 10, y + 10, 100, 16, 10, COLOR_GOLD);
   
   CreateLabel(ObjName("TREND_LBL"), "Trend:", x + 15, y + 35, 50, 14, 8, COLOR_TEXT);
   CreateLabel(ObjName("TREND_VAL"), DoubleToString(g_state.trendStrength * 100, 1) + "%", 
               x + 70, y + 35, 60, 14, 9, COLOR_ACCENT);
   
   CreateLabel(ObjName("VOL_LBL"), "Volatility:", x + 150, y + 35, 70, 14, 8, COLOR_TEXT);
   CreateLabel(ObjName("VOL_VAL"), DoubleToString(g_state.volatilityIndex * 100, 1) + "%", 
               x + 225, y + 35, 60, 14, 9, COLOR_RED);
   
   CreateLabel(ObjName("SENT_LBL"), "Sentiment:", x + 15, y + 55, 70, 14, 8, COLOR_TEXT);
   CreateLabel(ObjName("SENT_VAL"), DoubleToString(g_state.sentimentScore * 100, 1) + "%", 
               x + 90, y + 55, 60, 14, 9, COLOR_GREEN);
   
   CreateLabel(ObjName("ACC_LBL"), "Accuracy:", x + 150, y + 55, 60, 14, 8, COLOR_TEXT);
   CreateLabel(ObjName("ACC_VAL"), DoubleToString(g_state.predictionAccuracy * 100, 1) + "%", 
               x + 215, y + 55, 60, 14, 9, COLOR_GOLD);
   
   string aiStatus = g_state.aiEnabled ? "AI: ACTIVE" : "AI: INACTIVE";
   color aiColor = g_state.aiEnabled ? COLOR_GREEN : COLOR_RED;
   CreateButton(ObjName("BTN_AI_TOGGLE"), aiStatus, x + 15, y + 80, w - 30, 25, aiColor);
}

void CreateGridTab()
{
   int x = g_dashboard.x + 15;
   int y = g_dashboard.y + 100;
   int w = g_dashboard.width - 30;

   // ================================================================
   // 21-GRID MASTER SELECTOR
   // Every mode 1..21 is explicitly represented here.
   // ================================================================
   CreatePanel(ObjName("GRID_TYPE_PANEL"), x, y, w, 255, COLOR_PANEL, COLOR_ACCENT);
   CreateLabel(ObjName("GRID_TYPE_TITLE"), "GRID ENGINE — 21 SELECTABLE MODES", x + 10, y + 8, w - 20, 18, 10, COLOR_GOLD);
   CreateLabel(ObjName("GRID_CURRENT"),
               "ACTIVE SELECTION: [" + IntegerToString((int)g_state.gridType + 1) + "/21] " + GetGridTypeName(g_state.gridType),
               x + 10, y + 29, w - 20, 18, 9, COLOR_TEXT);

   int cols = GRID_SELECTOR_COLS;
   int rows = GRID_SELECTOR_ROWS;
   int gapX = 5;
   int gapY = 4;
   int btnW = (w - 20 - gapX * (cols - 1)) / cols;
   int btnH = 24;

   for(int i = 0; i < GRID_TYPE_COUNT; i++)
   {
      int row = i / cols;
      int col = i % cols;
      int bx = x + 7 + col * (btnW + gapX);
      int by = y + 50 + row * (btnH + gapY);
      bool active = (i == (int)g_state.gridType);
      string label = StringFormat("%02d  %s", i + 1, GetGridTypeName((ENUM_GRID_TYPE)i));
      CreateButton(ObjName("GRID_SEL_" + IntegerToString(i)), label,
                   bx, by, btnW, btnH,
                   active ? COLOR_ACCENT : COLOR_PANEL, active);
   }

   y += 265;

   // Selected-mode information panel
   CreatePanel(ObjName("GRID_SELECTED_PANEL"), x, y, w, 62, COLOR_PANEL, COLOR_GOLD);
   CreateLabel(ObjName("GRID_SELECTED_TITLE"), "SELECTED GRID", x + 10, y + 8, 110, 16, 8, COLOR_GOLD);
   CreateLabel(ObjName("GRID_SELECTED_NAME"),
               StringFormat("%02d — %s", (int)g_state.gridType + 1, GetGridTypeName(g_state.gridType)),
               x + 10, y + 27, w - 20, 18, 10, COLOR_TEXT);

   y += 72;

   // Parameters Panel
   CreatePanel(ObjName("PARAMS_PANEL"), x, y, w, 140, COLOR_PANEL, COLOR_ACCENT);
   CreateLabel(ObjName("PARAMS_TITLE"), "Selected Grid Parameters", x + 10, y + 10, 180, 16, 10, COLOR_GOLD);

   CreateLabel(ObjName("LOT_LBL"), "Lot Size:", x + 15, y + 35, 60, 14, 8, COLOR_TEXT);
   CreateEdit(ObjName("EDT_LOT"), DoubleToString(g_state.lotSize, 3), x + 80, y + 33, 60, 18);

   CreateLabel(ObjName("STEP_LBL"), "Grid Step:", x + 170, y + 35, 60, 14, 8, COLOR_TEXT);
   CreateEdit(ObjName("EDT_STEP"), DoubleToString(g_state.gridStep, 1), x + 240, y + 33, 60, 18);

   CreateLabel(ObjName("LEVELS_LBL"), "Levels:", x + 15, y + 60, 50, 14, 8, COLOR_TEXT);
   CreateEdit(ObjName("EDT_LEVELS"), IntegerToString(g_state.gridLevels), x + 70, y + 58, 50, 18);

   CreateLabel(ObjName("MULT_LBL"), "Multiplier:", x + 150, y + 60, 70, 14, 8, COLOR_TEXT);
   CreateEdit(ObjName("EDT_MULT"), DoubleToString(g_state.lotMultiplier, 2), x + 225, y + 58, 60, 18);

   string autoText = g_state.autonomousMode ? "AUTO: ON" : "AUTO: OFF";
   color autoColor = g_state.autonomousMode ? COLOR_GREEN : COLOR_RED;
   CreateButton(ObjName("BTN_AUTO"), autoText, x + 15, y + 85, w - 30, 25, autoColor);
   CreateButton(ObjName("BTN_APPLY"), "APPLY SELECTED GRID SETTINGS", x + 15, y + 115, w - 30, 20, COLOR_GOLD);
}

void CreateAITab()
{
   int x = g_dashboard.x + 15;
   int y = g_dashboard.y + 100;
   int w = g_dashboard.width - 30;
   
   // AI Settings Panel
   CreatePanel(ObjName("AI_SET_PANEL"), x, y, w, 120, COLOR_PANEL, COLOR_ACCENT);
   CreateLabel(ObjName("AI_SET_TITLE"), "AI Configuration", x + 10, y + 10, 150, 16, 10, COLOR_GOLD);
   
   CreateLabel(ObjName("CONF_LBL"), "Confidence:", x + 15, y + 35, 80, 14, 8, COLOR_TEXT);
   CreateEdit(ObjName("EDT_CONF"), DoubleToString(g_state.aiConfidence, 2), x + 100, y + 33, 60, 18);
   
   CreateLabel(ObjName("LEARN_LBL"), "Learning Period:", x + 15, y + 60, 100, 14, 8, COLOR_TEXT);
   CreateEdit(ObjName("EDT_LEARN"), IntegerToString(g_state.learningPeriod), x + 120, y + 58, 60, 18);
   
   string neuralText = g_state.neuralNetwork ? "NEURAL: ON" : "NEURAL: OFF";
   color neuralColor = g_state.neuralNetwork ? COLOR_GREEN : COLOR_ACCENT;
   CreateButton(ObjName("BTN_NEURAL"), neuralText, x + 15, y + 85, w - 30, 25, neuralColor);
   
   y += 130;
   
   // AI Metrics Panel
   CreatePanel(ObjName("AI_METRICS_PANEL"), x, y, w, 100, COLOR_PANEL, COLOR_ACCENT);
   CreateLabel(ObjName("AI_METRICS_TITLE"), "AI Performance", x + 10, y + 10, 120, 16, 10, COLOR_GOLD);
   
   CreateLabel(ObjName("PRED_LBL"), "Predictions:", x + 15, y + 35, 80, 14, 8, COLOR_TEXT);
   CreateLabel(ObjName("PRED_VAL"), IntegerToString(g_state.totalTrades), x + 100, y + 35, 50, 14, 9, COLOR_ACCENT);
   
   CreateLabel(ObjName("ACC_RATE_LBL"), "Accuracy:", x + 170, y + 35, 60, 14, 8, COLOR_TEXT);
   CreateLabel(ObjName("ACC_RATE_VAL"), DoubleToString(g_state.predictionAccuracy * 100, 1) + "%", 
               x + 235, y + 35, 60, 14, 9, COLOR_GREEN);
   
   CreateButton(ObjName("BTN_AI_RESET"), "RESET AI DATA", x + 15, y + 60, w - 30, 25, COLOR_RED);
}

void CreateRiskTab()
{
   int x = g_dashboard.x + 15;
   int y = g_dashboard.y + 100;
   int w = g_dashboard.width - 30;
   
   // Risk Settings Panel
   CreatePanel(ObjName("RISK_PANEL"), x, y, w, 160, COLOR_PANEL, COLOR_ACCENT);
   CreateLabel(ObjName("RISK_TITLE"), "Risk Management", x + 10, y + 10, 150, 16, 10, COLOR_GOLD);
   
   string riskModeText = "";
   switch(g_state.riskMode)
   {
      case CONSERVATIVE: riskModeText = "Conservative"; break;
      case BALANCED: riskModeText = "Balanced"; break;
      case AGGRESSIVE: riskModeText = "Aggressive"; break;
      case ADAPTIVE: riskModeText = "Adaptive"; break;
   }
   
   CreateButton(ObjName("BTN_RISK_MODE"), "Mode: " + riskModeText, x + 15, y + 30, w - 30, 25, COLOR_ACCENT);
   
   CreateLabel(ObjName("MAX_RISK_LBL"), "Max Risk %:", x + 15, y + 65, 80, 14, 8, COLOR_TEXT);
   CreateEdit(ObjName("EDT_MAX_RISK"), DoubleToString(g_state.maxRisk, 1), x + 100, y + 63, 60, 18);
   
   CreateLabel(ObjName("SL_LBL"), "Stop Loss:", x + 15, y + 90, 70, 14, 8, COLOR_TEXT);
   CreateEdit(ObjName("EDT_SL"), DoubleToString(g_state.stopLoss, 1), x + 90, y + 88, 60, 18);
   
   CreateLabel(ObjName("TP_LBL"), "Take Profit:", x + 170, y + 90, 80, 14, 8, COLOR_TEXT);
   CreateEdit(ObjName("EDT_TP"), DoubleToString(g_state.takeProfit, 1), x + 255, y + 88, 60, 18);
   
   string trailingText = g_state.trailingStop ? "TRAILING: ON" : "TRAILING: OFF";
   color trailingColor = g_state.trailingStop ? COLOR_GREEN : COLOR_ACCENT;
   CreateButton(ObjName("BTN_TRAILING"), trailingText, x + 15, y + 120, w - 30, 25, trailingColor);
   
   y += 170;
   
   // Account Info Panel
   CreatePanel(ObjName("ACCOUNT_PANEL"), x, y, w, 80, COLOR_PANEL, COLOR_ACCENT);
   CreateLabel(ObjName("ACCOUNT_TITLE"), "Account Information", x + 10, y + 10, 150, 16, 10, COLOR_GOLD);
   
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   double margin = AccountInfoDouble(ACCOUNT_MARGIN_LEVEL);
   
   CreateLabel(ObjName("BALANCE_LBL"), "Balance:", x + 15, y + 35, 60, 14, 8, COLOR_TEXT);
   CreateLabel(ObjName("BALANCE_VAL"), FormatNumber(balance), x + 80, y + 35, 80, 14, 9, COLOR_ACCENT);
   
   CreateLabel(ObjName("MARGIN_LBL"), "Margin:", x + 170, y + 35, 50, 14, 8, COLOR_TEXT);
   color marginColor = margin < 200 ? COLOR_RED : COLOR_GREEN;
   CreateLabel(ObjName("MARGIN_VAL"), DoubleToString(margin, 1) + "%", x + 225, y + 35, 60, 14, 9, marginColor);
   
   CreateLabel(ObjName("DD_LBL"), "Drawdown:", x + 15, y + 55, 70, 14, 8, COLOR_TEXT);
   CreateLabel(ObjName("DD_VAL"), DoubleToString(g_state.maxDrawdown, 1) + "%", x + 90, y + 55, 60, 14, 9, COLOR_RED);
}

void CreateSettingsTab()
{
   int x = g_dashboard.x + 15;
   int y = g_dashboard.y + 100;
   int w = g_dashboard.width - 30;
   
   // System Settings Panel
   CreatePanel(ObjName("SYS_PANEL"), x, y, w, 120, COLOR_PANEL, COLOR_ACCENT);
   CreateLabel(ObjName("SYS_TITLE"), "System Settings", x + 10, y + 10, 150, 16, 10, COLOR_GOLD);
   
   CreateLabel(ObjName("MAGIC_LBL"), "Magic Number:", x + 15, y + 35, 100, 14, 8, COLOR_TEXT);
   CreateEdit(ObjName("EDT_MAGIC"), IntegerToString((int)InpMagicNumber), x + 120, y + 33, 80, 18);
   
   CreateLabel(ObjName("SLIP_LBL"), "Slippage:", x + 15, y + 60, 60, 14, 8, COLOR_TEXT);
   CreateEdit(ObjName("EDT_SLIP"), IntegerToString(g_state.slippage), x + 80, y + 58, 50, 18);
   
   CreateLabel(ObjName("SPREAD_LBL"), "Min Spread:", x + 150, y + 60, 80, 14, 8, COLOR_TEXT);
   CreateEdit(ObjName("EDT_SPREAD"), DoubleToString(g_state.minSpread, 1), x + 235, y + 58, 60, 18);
   
   string smartText = g_state.smartExecution ? "SMART: ON" : "SMART: OFF";
   color smartColor = g_state.smartExecution ? COLOR_GREEN : COLOR_ACCENT;
   CreateButton(ObjName("BTN_SMART"), smartText, x + 15, y + 85, w - 30, 25, smartColor);
   
   y += 130;
   
   // Actions Panel
   CreatePanel(ObjName("ACTIONS_PANEL"), x, y, w, 100, COLOR_PANEL, COLOR_ACCENT);
   CreateLabel(ObjName("ACTIONS_TITLE"), "Actions", x + 10, y + 10, 100, 16, 10, COLOR_GOLD);
   
   CreateButton(ObjName("BTN_SAVE"), "SAVE SETTINGS", x + 15, y + 35, (w - 40) / 2, 25, COLOR_GREEN);
   CreateButton(ObjName("BTN_LOAD"), "LOAD SETTINGS", x + 25 + (w - 40) / 2, y + 35, (w - 40) / 2, 25, COLOR_ACCENT);
   
   CreateButton(ObjName("BTN_RESET"), "RESET TO DEFAULTS", x + 15, y + 65, w - 30, 25, COLOR_RED);
}

void CreateDashboard()
{
   if(!g_dashboard.isVisible) return;
   
   FitToChart();
   DeleteDashboard();
   
   CreateHeader();
   CreateTabs();
   
   switch(g_dashboard.currentTab)
   {
      case 0: CreateOverviewTab(); break;
      case 1: CreateGridTab(); break;
      case 2: CreateAITab(); break;
      case 3: CreateRiskTab(); break;
      case 4: CreateSettingsTab(); break;
   }
   
   ChartRedraw();
}

void UpdateDashboard()
{
   static datetime lastUpdate = 0;
   if(TimeCurrent() - lastUpdate < 1) return;
   lastUpdate = TimeCurrent();
   
   if(g_dashboard.currentTab == 0)
   {
      // Update dynamic values
      double profit = GetGridProfit();
      color profitColor = profit >= 0 ? COLOR_GREEN : COLOR_RED;
      ObjectSetString(0, ObjName("PROFIT_VAL"), OBJPROP_TEXT, FormatNumber(profit));
      ObjectSetInteger(0, ObjName("PROFIT_VAL"), OBJPROP_COLOR, profitColor);
      
      ObjectSetString(0, ObjName("EQUITY_VAL"), OBJPROP_TEXT, FormatNumber(AccountInfoDouble(ACCOUNT_EQUITY)));
      ObjectSetString(0, ObjName("POS_VAL"), OBJPROP_TEXT, IntegerToString(GetPositionCount()));
      ObjectSetString(0, ObjName("PEND_VAL"), OBJPROP_TEXT, IntegerToString(GetPendingCount()));
      
      // Update AI metrics
      ObjectSetString(0, ObjName("TREND_VAL"), OBJPROP_TEXT, DoubleToString(g_state.trendStrength * 100, 1) + "%");
      ObjectSetString(0, ObjName("VOL_VAL"), OBJPROP_TEXT, DoubleToString(g_state.volatilityIndex * 100, 1) + "%");
      ObjectSetString(0, ObjName("SENT_VAL"), OBJPROP_TEXT, DoubleToString(g_state.sentimentScore * 100, 1) + "%");
      ObjectSetString(0, ObjName("ACC_VAL"), OBJPROP_TEXT, DoubleToString(g_state.predictionAccuracy * 100, 1) + "%");
   }
   
   // Update status
   string status = g_state.gridActive ? "ACTIVE" : "STANDBY";
   color statusColor = g_state.gridActive ? COLOR_GREEN : COLOR_TEXT;
   ObjectSetString(0, ObjName("STATUS"), OBJPROP_TEXT, status);
   ObjectSetInteger(0, ObjName("STATUS"), OBJPROP_COLOR, statusColor);
   
   ChartRedraw();
}

void DeleteDashboard()
{
   for(int i = ObjectsTotal(0) - 1; i >= 0; i--)
   {
      string name = ObjectName(0, i);
      if(StringFind(name, PREFIX) == 0)
         ObjectDelete(0, name);
   }
}

//--------------------------- SETTINGS SYNC ---------------------------
void SyncFromDashboard()
{
   string value;
   
   value = ObjectGetString(0, ObjName("EDT_LOT"), OBJPROP_TEXT);
   if(value != "") g_state.lotSize = StringToDouble(value);
   
   value = ObjectGetString(0, ObjName("EDT_STEP"), OBJPROP_TEXT);
   if(value != "") g_state.gridStep = StringToDouble(value);
   
   value = ObjectGetString(0, ObjName("EDT_LEVELS"), OBJPROP_TEXT);
   if(value != "") g_state.gridLevels = (int)StringToInteger(value);
   
   value = ObjectGetString(0, ObjName("EDT_MULT"), OBJPROP_TEXT);
   if(value != "") g_state.lotMultiplier = StringToDouble(value);
   
   value = ObjectGetString(0, ObjName("EDT_CONF"), OBJPROP_TEXT);
   if(value != "") g_state.aiConfidence = StringToDouble(value);
   
   value = ObjectGetString(0, ObjName("EDT_LEARN"), OBJPROP_TEXT);
   if(value != "") g_state.learningPeriod = (int)StringToInteger(value);
   
   value = ObjectGetString(0, ObjName("EDT_MAX_RISK"), OBJPROP_TEXT);
   if(value != "") g_state.maxRisk = StringToDouble(value);
   
   value = ObjectGetString(0, ObjName("EDT_SL"), OBJPROP_TEXT);
   if(value != "") g_state.stopLoss = StringToDouble(value);
   
   value = ObjectGetString(0, ObjName("EDT_TP"), OBJPROP_TEXT);
   if(value != "") g_state.takeProfit = StringToDouble(value);
   
   value = ObjectGetString(0, ObjName("EDT_SLIP"), OBJPROP_TEXT);
   if(value != "") g_state.slippage = (int)StringToInteger(value);
   
   value = ObjectGetString(0, ObjName("EDT_SPREAD"), OBJPROP_TEXT);
   if(value != "") g_state.minSpread = StringToDouble(value);
}

void ApplySettings()
{
   SyncFromDashboard();
   trade.SetExpertMagicNumber(InpMagicNumber);
   trade.SetDeviationInPoints(g_state.slippage);
   Print("Settings applied successfully");
}

//--------------------------- INITIALIZATION ---------------------------
void InitializeState()
{
   g_state.gridType = InpGridType;
   g_state.entryMode = InpEntryMode;
   g_state.riskMode = InpRiskMode;
   
   g_state.lotSize = InpLotSize;
   g_state.gridStep = InpGridStep;
   g_state.gridLevels = InpGridLevels;
   g_state.lotMultiplier = InpLotMultiplier;
   g_state.autonomousMode = InpAutonomousMode;
   
   g_state.aiEnabled = InpEnableAI;
   g_state.neuralNetwork = InpNeuralNetwork;
   g_state.aiConfidence = InpAIConfidence;
   g_state.learningPeriod = InpLearningPeriod;
   
   g_state.maxRisk = InpMaxRisk;
   g_state.stopLoss = InpStopLoss;
   g_state.takeProfit = InpTakeProfit;
   g_state.trailingStop = InpTrailingStop;
   
   g_state.slippage = InpSlippage;
   g_state.minSpread = InpMinSpread;
   g_state.smartExecution = InpSmartExecution;
   
   // Runtime initialization
   g_state.gridActive = false;
   g_state.startTime = 0;
   g_state.initialEquity = AccountInfoDouble(ACCOUNT_EQUITY);
   g_state.currentProfit = 0;
   g_state.positionCount = 0;
   g_state.pendingCount = 0;
   
   // AI metrics initialization
   g_state.trendStrength = 0.5;
   g_state.volatilityIndex = 0.5;
   g_state.sentimentScore = 0.5;
   g_state.predictionAccuracy = 0.0;
   
   // Performance metrics
   g_state.totalProfit = 0.0;
   g_state.winRate = 0.0;
   g_state.totalTrades = 0;
   g_state.maxDrawdown = 0.0;
}

//--------------------------- EVENT HANDLERS ---------------------------
int OnInit()
{
   InitializeState();
   InitializeDashboard();
   
   trade.SetExpertMagicNumber(InpMagicNumber);
   trade.SetDeviationInPoints(InpSlippage);
   
   // Initialize indicators
   g_atrHandle = iATR(_Symbol, PERIOD_CURRENT, 14);
   g_maHandle = iMA(_Symbol, PERIOD_CURRENT, 20, 0, MODE_SMA, PRICE_CLOSE);
   g_rsiHandle = iRSI(_Symbol, PERIOD_CURRENT, 14, PRICE_CLOSE);
   
   // Check existing grid
   if(GetPositionCount() > 0 || GetPendingCount() > 0)
   {
      g_state.gridActive = true;
      Print("Existing grid detected");
   }
   
   CreateDashboard();
   
   Print("Ultimate Grid EA initialized successfully");
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
   if(g_atrHandle != INVALID_HANDLE) IndicatorRelease(g_atrHandle);
   if(g_maHandle != INVALID_HANDLE) IndicatorRelease(g_maHandle);
   if(g_rsiHandle != INVALID_HANDLE) IndicatorRelease(g_rsiHandle);
   
   DeleteDashboard();
   Comment("");
}

void OnTick()
{
   // Update AI metrics
   g_state.trendStrength = CalculateTrendStrength();
   g_state.volatilityIndex = CalculateVolatility();
   g_state.sentimentScore = CalculateSentiment();
   
   // Update counters
   g_state.positionCount = GetPositionCount();
   g_state.pendingCount = GetPendingCount();
   g_state.currentProfit = GetGridProfit();
   
   // Grid state management
   if(g_state.gridActive && g_state.positionCount == 0 && g_state.pendingCount == 0)
      g_state.gridActive = false;
   
   // Autonomous grid management
   if(g_state.autonomousMode && ShouldStartGrid())
      CreateGrid();
   
   // Risk management
   if(g_state.gridActive)
   {
      double equity = AccountInfoDouble(ACCOUNT_EQUITY);
      if(g_state.initialEquity > 0)
      {
         double drawdown = (g_state.initialEquity - equity) / g_state.initialEquity * 100.0;
         if(drawdown >= g_state.maxRisk)
         {
            CloseGrid();
            Print("Grid closed due to max drawdown");
         }
      }
   }
   
   UpdateDashboard();
}

void OnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam)
{
   if(id == CHARTEVENT_CHART_CHANGE)
   {
      CreateDashboard();
      return;
   }
   
   if(id == CHARTEVENT_OBJECT_ENDEDIT && StringFind(sparam, PREFIX) == 0)
   {
      string value = ObjectGetString(0, sparam, OBJPROP_TEXT);
      StoreEditValue(sparam, value);
      return;
   }
   
   if(id != CHARTEVENT_OBJECT_CLICK) return;
   if(StringFind(sparam, PREFIX) != 0) return;
   
   // Tab clicks
   for(int i = 0; i < TAB_COUNT; i++)
   {
      if(sparam == ObjName("TAB_" + IntegerToString(i)))
      {
         g_dashboard.currentTab = i;
         CreateDashboard();
         return;
      }
   }
   
   // Button clicks
   if(sparam == ObjName("BTN_START"))
   {
      if(!g_state.gridActive) CreateGrid();
   }
   else if(sparam == ObjName("BTN_STOP"))
   {
      if(g_state.gridActive) CloseGrid();
   }
   else if(StringFind(sparam, ObjName("GRID_SEL_")) == 0)
   {
      string idxText = StringSubstr(sparam, StringLen(ObjName("GRID_SEL_")));
      int idx = (int)StringToInteger(idxText);
      if(idx >= 0 && idx < GRID_TYPE_COUNT)
      {
         if(g_state.gridActive)
            Print("Grid selection changed while active. New type applies to the next grid.");
         g_state.gridType = (ENUM_GRID_TYPE)idx;
         Print("GRID SELECTED: [", idx + 1, "/", GRID_TYPE_COUNT, "] ", GetGridTypeName(g_state.gridType));
         CreateDashboard();
      }
   }
   else if(sparam == ObjName("BTN_GRID_TYPE"))
   {
      // Backward-compatible cycle control for layouts/buttons created by older templates.
      g_state.gridType = (ENUM_GRID_TYPE)(((int)g_state.gridType + 1) % GRID_TYPE_COUNT);
      CreateDashboard();
   }
   else if(sparam == ObjName("BTN_AUTO"))
   {
      g_state.autonomousMode = !g_state.autonomousMode;
      CreateDashboard();
   }
   else if(sparam == ObjName("BTN_AI_TOGGLE"))
   {
      g_state.aiEnabled = !g_state.aiEnabled;
      CreateDashboard();
   }
   else if(sparam == ObjName("BTN_NEURAL"))
   {
      g_state.neuralNetwork = !g_state.neuralNetwork;
      CreateDashboard();
   }
   else if(sparam == ObjName("BTN_RISK_MODE"))
   {
      g_state.riskMode = (ENUM_RISK_MODE)((int(g_state.riskMode) + 1) % 4);
      CreateDashboard();
   }
   else if(sparam == ObjName("BTN_TRAILING"))
   {
      g_state.trailingStop = !g_state.trailingStop;
      CreateDashboard();
   }
   else if(sparam == ObjName("BTN_SMART"))
   {
      g_state.smartExecution = !g_state.smartExecution;
      CreateDashboard();
   }
   else if(sparam == ObjName("BTN_APPLY"))
   {
      ApplySettings();
   }
   else if(sparam == ObjName("BTN_RESET"))
   {
      InitializeState();
      g_editCount = 0;
      CreateDashboard();
      Print("Settings reset to defaults");
   }
   else if(sparam == ObjName("BTN_AI_RESET"))
   {
      g_state.predictionAccuracy = 0.0;
      g_state.totalTrades = 0;
      Print("AI data reset");
   }
   
   ChartRedraw();
}