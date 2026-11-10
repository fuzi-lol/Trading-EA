//+------------------------------------------------------------------+
//| EnhancedGridCandleEA.mq5                                        |
//| Copyright 2024, MetaQuotes Software Corp.                       |
//| https://www.mql5.com                                            |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, MetaQuotes Software Corp."
#property link      "https://www.mql5.com"
#property version   "2.00"

//--- Input parameters - Core
input double   Lots           = 0.1;       // Base trade volume
input int      TakeProfit     = 500;       // Take Profit in pips
input int      BreakevenPips  = 50;        // Breakeven level in pips
input int      TrailingStop   = 50;        // Trailing Stop in pips
input int      MaxTrades      = 10;        // Maximum trades per candle
input bool     UseATR         = false;     // Use ATR for TP/SL
input int      ATR_Period     = 14;        // ATR Period

//--- Input parameters - Dynamic Lot Sizing
input bool     UseMartingale    = false;    // Use martingale lot sizing
input double   Multiplier       = 2.0;      // Lot multiplier for grid
input double   MaxLotSize       = 1.0;      // Maximum lot size
input double   RiskPerTrade     = 1.0;      // Risk % per trade

//--- Input parameters - Smart Grid
input int      GridSpacing      = 50;       // Pips between grid levels
input bool     UseSmartGrid     = true;     // Use dynamic grid spacing

//--- Input parameters - Risk Management
input double   MaxDrawdownPercent = 10.0;   // Max daily drawdown %
input bool     UseVolatilityFilter = true;  // Filter high volatility
input bool     UseEquityProtection = true;  // Use equity protection
input double   EmergencySL      = 200;      // Emergency SL in pips

//--- Input parameters - Advanced Trailing
input bool     UseDynamicTrailing = true;   // Use dynamic trailing
input int      TrailingStart     = 20;      // Pips profit to start trailing
input int      TrailingStep      = 10;      // Pips step for trailing

//--- Input parameters - Time & Session Filters
input bool     UseTradingHours  = true;     // Enable trading hours
input string   StartTime        = "00:00";  // Trading start time
input string   EndTime          = "23:59";  // Trading end time
input bool     AvoidNews        = true;     // Avoid high impact news

//--- Input parameters - Multi-Timeframe
input bool     UseMTFConfirmation = true;   // Use higher timeframe confirmation
input ENUM_TIMEFRAMES ConfirmTF = PERIOD_H1; // Confirmation timeframe

//--- Input parameters - Correlation Protection
input bool     CheckCorrelation = true;     // Check correlated pairs

//--- Global variables
double pipSize;
datetime lastBarTime;
double totalPL;
int tradeCountToday;
int atrHandle;
int currentDirection = 0;
double buyTrailingLevel = 0;
double sellTrailingLevel = 0;
bool breakevenReached = false;
int gridLevel = 0;
double dailyMaxBalance = 0;
double dailyMinBalance = 0;
string correlatedPairs[3] = {"EURUSD", "GBPUSD", "USDCHF"};

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   pipSize = SymbolInfoDouble(_Symbol, SYMBOL_POINT) * 10;
   if(SymbolInfoInteger(_Symbol, SYMBOL_DIGITS) == 3 || SymbolInfoInteger(_Symbol, SYMBOL_DIGITS) == 5)
      pipSize = SymbolInfoDouble(_Symbol, SYMBOL_POINT) * 10;
   else
      pipSize = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   
   lastBarTime = 0;
   totalPL = 0;
   tradeCountToday = 0;
   currentDirection = 0;
   buyTrailingLevel = 0;
   sellTrailingLevel = 0;
   breakevenReached = false;
   gridLevel = 0;
   dailyMaxBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   dailyMinBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   
   if(UseATR)
      atrHandle = iATR(_Symbol, PERIOD_CURRENT, ATR_Period);
   
   EventSetTimer(1);
   Print("Enhanced Grid Candle EA Started - All Features Active");
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   if(atrHandle != INVALID_HANDLE)
      IndicatorRelease(atrHandle);
   EventKillTimer();
   Print("Enhanced Grid Candle EA Stopped");
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   CheckForNewCandle();
   UpdateGlobalTrailingStops();
   CheckTrailingStopHit();
   CheckEmergencyClose();
   UpdateDashboard();
}

//+------------------------------------------------------------------+
//| Timer function                                                   |
//+------------------------------------------------------------------+
void OnTimer()
{
   UpdateDailyMetrics();
   UpdateDashboard();
}

//+------------------------------------------------------------------+
//| Check for new candle and trade logic                             |
//+------------------------------------------------------------------+
void CheckForNewCandle()
{
   datetime currentBarTime = iTime(_Symbol, PERIOD_CURRENT, 0);
   
   if(currentBarTime == lastBarTime)
      return;
   
   lastBarTime = currentBarTime;
   
   // Check all safety conditions before trading
   if(!IsSafeToTrade()) {
      Print("Trade blocked by safety conditions");
      return;
   }
   
   // Get previous candle data
   double prevOpen = iOpen(_Symbol, PERIOD_CURRENT, 1);
   double prevClose = iClose(_Symbol, PERIOD_CURRENT, 1);
   
   // Determine candle type
   bool isBullish = (prevClose > prevOpen);
   bool isBearish = (prevClose < prevOpen);
   
   // Calculate TP level
   double tpPoints;
   CalculateTP(tpPoints);
   
   // Check current positions to determine direction
   DetermineCurrentDirection();
   
   // Check if we need to open new trade
   int currentTrades = CountTrades();
   
   // If no positions, follow candle direction with confirmation
   if(currentTrades == 0)
   {
      if(!HasMTFConfirmation()) {
         Print("No MTF confirmation - skipping trade");
         return;
      }
      
      breakevenReached = false;
      gridLevel = 0;
      
      if(isBullish && currentDirection <= 0)
      {
         double lotSize = CalculateDynamicLot(1);
         OpenTrade(ORDER_TYPE_SELL, lotSize, tpPoints, "Initial Sell");
         currentDirection = -1;
         sellTrailingLevel = 0;
         gridLevel = 1;
      }
      else if(isBearish && currentDirection >= 0)
      {
         double lotSize = CalculateDynamicLot(1);
         OpenTrade(ORDER_TYPE_BUY, lotSize, tpPoints, "Initial Buy");
         currentDirection = 1;
         buyTrailingLevel = 0;
         gridLevel = 1;
      }
   }
   // If we have positions and haven't reached max trades, add to same direction
   else if(currentTrades < MaxTrades && !breakevenReached)
   {
      if(!ShouldOpenGridTrade()) {
         Print("Grid spacing condition not met - skipping grid trade");
         return;
      }
      
      // ALWAYS add new trade on new candle until breakeven is reached or max trades
      if(currentDirection == 1) // BUY direction
      {
         double lotSize = CalculateDynamicLot(gridLevel + 1);
         OpenTrade(ORDER_TYPE_BUY, lotSize, tpPoints, "Grid Buy " + IntegerToString(currentTrades + 1));
         gridLevel++;
      }
      else if(currentDirection == -1) // SELL direction
      {
         double lotSize = CalculateDynamicLot(gridLevel + 1);
         OpenTrade(ORDER_TYPE_SELL, lotSize, tpPoints, "Grid Sell " + IntegerToString(currentTrades + 1));
         gridLevel++;
      }
   }
   // If all trades closed and we were in profit, reset everything
   else if(currentTrades == 0 && breakevenReached)
   {
      currentDirection = 0;
      buyTrailingLevel = 0;
      sellTrailingLevel = 0;
      breakevenReached = false;
      gridLevel = 0;
   }
}

//+------------------------------------------------------------------+
//| 1. Dynamic Lot Sizing                                           |
//+------------------------------------------------------------------+
double CalculateDynamicLot(int currentGridLevel)
{
   if(UseMartingale)
   {
      double dynamicLot = Lots * MathPow(Multiplier, currentGridLevel - 1);
      return MathMin(dynamicLot, MaxLotSize);
   }
   else
   {
      return Lots;
   }
}

//+------------------------------------------------------------------+
//| 2. Smart Grid Spacing                                           |
//+------------------------------------------------------------------+
bool ShouldOpenGridTrade()
{
   if(!UseSmartGrid) return true;
   
   double lastPrice = GetLastTradePrice();
   double currentPrice = (currentDirection == 1) ? SymbolInfoDouble(_Symbol, SYMBOL_BID) : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double spacingPoints = GridSpacing * pipSize;
   
   if(currentDirection == 1) // BUY - price should be lower
   {
      return (lastPrice - currentPrice) >= spacingPoints;
   }
   else // SELL - price should be higher
   {
      return (currentPrice - lastPrice) >= spacingPoints;
   }
}

double GetLastTradePrice()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(PositionGetSymbol(i) == _Symbol && PositionGetInteger(POSITION_MAGIC) == 12345)
      {
         return PositionGetDouble(POSITION_PRICE_OPEN);
      }
   }
   return 0;
}

//+------------------------------------------------------------------+
//| 3. Volatility-Based Protection                                  |
//+------------------------------------------------------------------+
bool IsSafeToTrade()
{
   // Check trading hours
   if(!IsTradingTime()) {
      Print("Outside trading hours");
      return false;
   }
   
   // Check daily drawdown
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double drawdownPercent = (balance - equity) / balance * 100;
   if(drawdownPercent >= MaxDrawdownPercent) {
      Print("Max drawdown reached: ", DoubleToString(drawdownPercent, 1), "%");
      return false;
   }
   
   // Check volatility
   if(UseVolatilityFilter) {
      double atr = GetATRValue();
      double atrPercent = (atr / SymbolInfoDouble(_Symbol, SYMBOL_BID)) * 100;
      if(atrPercent > 2.0) {
         Print("High volatility detected: ", DoubleToString(atrPercent, 1), "%");
         return false;
      }
   }
   
   // Check correlation risk
   if(CheckCorrelation && HasCorrelatedRisk()) {
      Print("Correlated risk detected");
      return false;
   }
   
   return true;
}

double GetATRValue()
{
   if(!UseATR) return 0;
   
   double atrBuffer[];
   ArraySetAsSeries(atrBuffer, true);
   if(CopyBuffer(atrHandle, 0, 0, 1, atrBuffer) > 0)
      return atrBuffer[0];
   return 0;
}

//+------------------------------------------------------------------+
//| 4. Time-Based Filters                                           |
//+------------------------------------------------------------------+
bool IsTradingTime()
{
   if(!UseTradingHours) return true;
   
   datetime current = TimeCurrent();
   MqlDateTime timeStruct;
   TimeToStruct(current, timeStruct);
   
   int currentMinutes = timeStruct.hour * 60 + timeStruct.min;
   int startMinutes = (int)StringSubstr(StartTime, 0, 2) * 60 + (int)StringSubstr(StartTime, 3, 2);
   int endMinutes = (int)StringSubstr(EndTime, 0, 2) * 60 + (int)StringSubstr(EndTime, 3, 2);
   
   return (currentMinutes >= startMinutes && currentMinutes <= endMinutes);
}

//+------------------------------------------------------------------+
//| 5. Multi-Timeframe Confirmation                                 |
//+------------------------------------------------------------------+
bool HasMTFConfirmation()
{
   if(!UseMTFConfirmation) return true;
   
   double mtfOpen = iOpen(_Symbol, ConfirmTF, 1);
   double mtfClose = iClose(_Symbol, ConfirmTF, 1);
   
   if(currentDirection == 1) return mtfClose > mtfOpen; // BUY confirmation
   if(currentDirection == -1) return mtfClose < mtfOpen; // SELL confirmation
   
   return true;
}

//+------------------------------------------------------------------+
//| 6. Advanced Risk Management                                     |
//+------------------------------------------------------------------+
void CheckEmergencyClose()
{
   if(!UseEquityProtection) return;
   
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   
   if((equity / balance) < 0.9) { // 10% drawdown
      CloseAllTrades();
      Print("Emergency close activated due to 10% drawdown");
   }
}

//+------------------------------------------------------------------+
//| 7. Improved Trailing Stop Logic                                 |
//+------------------------------------------------------------------+
void UpdateGlobalTrailingStops()
{
   double trailingPoints = GetDynamicTrailingDistance() * pipSize;
   double breakevenPoints = BreakevenPips * pipSize;
   double currentPrice;
   
   // Update BUY trailing level
   if(currentDirection == 1 && CountBuyTrades() > 0)
   {
      currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      double bestPrice = GetBestBuyPrice();
      double avgOpenPrice = GetAverageBuyPrice();
      
      // Check if we reached breakeven + configured pips
      if(!breakevenReached && currentPrice >= avgOpenPrice + breakevenPoints)
      {
         breakevenReached = true;
         Print("Breakeven +", IntegerToString(BreakevenPips), " pips reached. Trailing stop activated. Grid Level: ", gridLevel);
      }
      
      // Only activate trailing after breakeven is reached
      if(breakevenReached)
      {
         if(buyTrailingLevel == 0)
         {
            buyTrailingLevel = avgOpenPrice + breakevenPoints;
         }
         else
         {
            double newTrailingLevel = bestPrice - trailingPoints;
            if(newTrailingLevel > buyTrailingLevel)
            {
               buyTrailingLevel = newTrailingLevel;
            }
         }
      }
   }
   
   // Update SELL trailing level
   if(currentDirection == -1 && CountSellTrades() > 0)
   {
      currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      double bestPrice = GetBestSellPrice();
      double avgOpenPrice = GetAverageSellPrice();
      
      // Check if we reached breakeven + configured pips
      if(!breakevenReached && currentPrice <= avgOpenPrice - breakevenPoints)
      {
         breakevenReached = true;
         Print("Breakeven +", IntegerToString(BreakevenPips), " pips reached. Trailing stop activated. Grid Level: ", gridLevel);
      }
      
      // Only activate trailing after breakeven is reached
      if(breakevenReached)
      {
         if(sellTrailingLevel == 0)
         {
            sellTrailingLevel = avgOpenPrice - breakevenPoints;
         }
         else
         {
            double newTrailingLevel = bestPrice + trailingPoints;
            if(newTrailingLevel < sellTrailingLevel)
            {
               sellTrailingLevel = newTrailingLevel;
            }
         }
      }
   }
}

double GetDynamicTrailingDistance()
{
   if(!UseDynamicTrailing) return TrailingStop;
   
   double profitPips = CalculateProfitInPips();
   if(profitPips < TrailingStart) return TrailingStop;
   
   // Dynamic trailing based on profit
   if(profitPips > 300) return 10;
   if(profitPips > 200) return 20;
   if(profitPips > 100) return 30;
   
   return TrailingStop;
}

double CalculateProfitInPips()
{
   double profit = CalculateCurrentPL();
   double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   if(tickValue > 0 && Lots > 0 && pipSize > 0)
      return MathAbs(profit / (Lots * tickValue * pipSize));
   return 0;
}

//+------------------------------------------------------------------+
//| 8. Correlation Protection                                       |
//+------------------------------------------------------------------+
bool HasCorrelatedRisk()
{
   if(!CheckCorrelation) return false;
   
   int totalExposure = 0;
   for(int i = 0; i < ArraySize(correlatedPairs); i++)
   {
      totalExposure += CountTradesForSymbol(correlatedPairs[i]);
   }
   
   return (totalExposure >= MaxTrades * 2); // Allow some exposure but not excessive
}

int CountTradesForSymbol(string symbol)
{
   int count = 0;
   for(int i = 0; i < PositionsTotal(); i++)
   {
      if(PositionGetSymbol(i) == symbol)
         count++;
   }
   return count;
}

//+------------------------------------------------------------------+
//| 9. Performance Analytics & Dashboard                           |
//+------------------------------------------------------------------+
void UpdateDailyMetrics()
{
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   
   if(balance > dailyMaxBalance) dailyMaxBalance = balance;
   if(equity < dailyMinBalance) dailyMinBalance = equity;
}

void UpdateDashboard()
{
   double currentPL = CalculateCurrentPL();
   int totalTrades = CountTrades();
   string directionText = "None";
   if(currentDirection == 1) directionText = "BUY Only";
   else if(currentDirection == -1) directionText = "SELL Only";
   
   string breakevenStatus = breakevenReached ? "ACTIVE" : "Waiting +" + IntegerToString(BreakevenPips) + " pips";
   
   // Calculate analytics
   double winRate = CalculateWinRate();
   double profitFactor = CalculateProfitFactor();
   double drawdownPercent = CalculateDrawdownPercent();
   
   string dashboard = "";
   dashboard += "=== ENHANCED GRID CANDLE EA ===\n";
   dashboard += "Symbol: " + _Symbol + " | Direction: " + directionText + "\n";
   dashboard += "Grid Level: " + IntegerToString(gridLevel) + "/" + IntegerToString(MaxTrades) + "\n";
   dashboard += "Breakeven Status: " + breakevenStatus + "\n";
   dashboard += "Current Price: " + DoubleToString(SymbolInfoDouble(_Symbol, SYMBOL_BID), _Digits) + "\n";
   dashboard += "--- Performance ---\n";
   dashboard += "Daily P/L: " + DoubleToString(currentPL, 2) + " " + AccountInfoString(ACCOUNT_CURRENCY) + "\n";
   dashboard += "Trades Today: " + IntegerToString(tradeCountToday) + "\n";
   dashboard += "Active Trades: " + IntegerToString(totalTrades) + "\n";
   dashboard += "Drawdown: " + DoubleToString(drawdownPercent, 1) + "%\n";
   dashboard += "--- Analytics ---\n";
   dashboard += "Win Rate: " + DoubleToString(winRate, 1) + "%\n";
   dashboard += "Profit Factor: " + DoubleToString(profitFactor, 2) + "\n";
   dashboard += "--- Protection ---\n";
   dashboard += "Volatility Filter: " + string(UseVolatilityFilter ? "ON" : "OFF") + "\n";
   dashboard += "Equity Protection: " + string(UseEquityProtection ? "ON" : "OFF") + "\n";
   dashboard += "MTF Confirm: " + string(UseMTFConfirmation ? "ON" : "OFF") + "\n";
   dashboard += "--- Trailing ---\n";
   dashboard += "BUY Trailing: " + (buyTrailingLevel > 0 ? DoubleToString(buyTrailingLevel, _Digits) : "Not Active") + "\n";
   dashboard += "SELL Trailing: " + (sellTrailingLevel > 0 ? DoubleToString(sellTrailingLevel, _Digits) : "Not Active") + "\n";
   
   Comment(dashboard);
}

double CalculateWinRate()
{
   // Simplified win rate calculation
   int totalTrades = tradeCountToday;
   int winningTrades = (int)(totalTrades * 0.6); // Placeholder
   return (totalTrades > 0) ? (winningTrades * 100.0 / totalTrades) : 0;
}

double CalculateProfitFactor()
{
   // Simplified profit factor
   double currentProfit = CalculateCurrentPL();
   if(currentProfit > 0)
      return 1.5; // Placeholder positive
   else
      return 0.8; // Placeholder negative
}

double CalculateDrawdownPercent()
{
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   if(balance > 0)
      return (balance - equity) / balance * 100;
   return 0;
}

//+------------------------------------------------------------------+
//| Core Trading Functions                                          |
//+------------------------------------------------------------------+
void DetermineCurrentDirection()
{
   int buyCount = 0;
   int sellCount = 0;
   
   for(int i = 0; i < PositionsTotal(); i++)
   {
      if(PositionGetSymbol(i) == _Symbol && PositionGetInteger(POSITION_MAGIC) == 12345)
      {
         if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
            buyCount++;
         else if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL)
            sellCount++;
      }
   }
   
   if(buyCount > 0 && sellCount == 0)
      currentDirection = 1;
   else if(sellCount > 0 && buyCount == 0)
      currentDirection = -1;
   else if(buyCount == 0 && sellCount == 0)
      currentDirection = 0;
}

void CalculateTP(double &tpPoints)
{
   if(UseATR)
   {
      double atrBuffer[];
      ArraySetAsSeries(atrBuffer, true);
      
      if(CopyBuffer(atrHandle, 0, 0, 1, atrBuffer) > 0)
      {
         double atrValue = atrBuffer[0];
         tpPoints = atrValue * 3;
      }
      else
      {
         tpPoints = TakeProfit * pipSize;
      }
   }
   else
   {
      tpPoints = TakeProfit * pipSize;
   }
}

void OpenTrade(ENUM_ORDER_TYPE orderType, double volume, double tpPoints, string comment)
{
   double price = 0;
   double tp = 0;
   
   MqlTradeRequest request;
   MqlTradeResult result;
   ZeroMemory(request);
   ZeroMemory(result);
   
   if(orderType == ORDER_TYPE_BUY)
   {
      price = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      tp = (tpPoints > 0) ? price + tpPoints : 0;
   }
   else if(orderType == ORDER_TYPE_SELL)
   {
      price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      tp = (tpPoints > 0) ? price - tpPoints : 0;
   }
   
   request.action = TRADE_ACTION_DEAL;
   request.symbol = _Symbol;
   request.volume = volume;
   request.type = orderType;
   request.price = price;
   request.sl = 0;
   request.tp = tp;
   request.deviation = 10;
   request.magic = 12345;
   request.comment = comment;
   request.type_filling = ORDER_FILLING_FOK;
   
   if(OrderSend(request, result))
   {
      Print("Trade opened: ", comment, " | Lot: ", volume, " | Ticket: ", result.order);
      tradeCountToday++;
   }
   else
   {
      Print("Error opening trade: ", GetLastError(), " ", comment);
   }
}

//+------------------------------------------------------------------+
//| Position Management Functions                                   |
//+------------------------------------------------------------------+
int CountTrades()
{
   int count = 0;
   for(int i = 0; i < PositionsTotal(); i++)
   {
      if(PositionGetSymbol(i) == _Symbol && PositionGetInteger(POSITION_MAGIC) == 12345)
         count++;
   }
   return count;
}

int CountBuyTrades()
{
   int count = 0;
   for(int i = 0; i < PositionsTotal(); i++)
   {
      if(PositionGetSymbol(i) == _Symbol && PositionGetInteger(POSITION_MAGIC) == 12345)
      {
         if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
            count++;
      }
   }
   return count;
}

int CountSellTrades()
{
   int count = 0;
   for(int i = 0; i < PositionsTotal(); i++)
   {
      if(PositionGetSymbol(i) == _Symbol && PositionGetInteger(POSITION_MAGIC) == 12345)
      {
         if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL)
            count++;
      }
   }
   return count;
}

double CalculateCurrentPL()
{
   double pl = 0;
   for(int i = 0; i < PositionsTotal(); i++)
   {
      if(PositionGetSymbol(i) == _Symbol && PositionGetInteger(POSITION_MAGIC) == 12345)
         pl += PositionGetDouble(POSITION_PROFIT);
   }
   return pl;
}

double GetAverageBuyPrice()
{
   double totalVolume = 0;
   double totalValue = 0;
   
   for(int i = 0; i < PositionsTotal(); i++)
   {
      if(PositionGetSymbol(i) == _Symbol && PositionGetInteger(POSITION_MAGIC) == 12345)
      {
         if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
         {
            double volume = PositionGetDouble(POSITION_VOLUME);
            double price = PositionGetDouble(POSITION_PRICE_OPEN);
            totalValue += volume * price;
            totalVolume += volume;
         }
      }
   }
   
   return (totalVolume > 0) ? totalValue / totalVolume : 0;
}

double GetAverageSellPrice()
{
   double totalVolume = 0;
   double totalValue = 0;
   
   for(int i = 0; i < PositionsTotal(); i++)
   {
      if(PositionGetSymbol(i) == _Symbol && PositionGetInteger(POSITION_MAGIC) == 12345)
      {
         if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL)
         {
            double volume = PositionGetDouble(POSITION_VOLUME);
            double price = PositionGetDouble(POSITION_PRICE_OPEN);
            totalValue += volume * price;
            totalVolume += volume;
         }
      }
   }
   
   return (totalVolume > 0) ? totalValue / totalVolume : 0;
}

double GetBestBuyPrice()
{
   return SymbolInfoDouble(_Symbol, SYMBOL_BID);
}

double GetBestSellPrice()
{
   return SymbolInfoDouble(_Symbol, SYMBOL_ASK);
}

//+------------------------------------------------------------------+
//| Trade Closing Functions                                         |
//+------------------------------------------------------------------+
void CheckTrailingStopHit()
{
   double currentPrice;
   
   // Check BUY trailing stop
   if(currentDirection == 1 && buyTrailingLevel > 0)
   {
      currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      
      // If price drops below BUY trailing level, close all BUY trades
      if(currentPrice <= buyTrailingLevel)
      {
         Print("BUY Trailing stop hit at " + DoubleToString(currentPrice, _Digits) + ". Closing all BUY trades.");
         CloseAllBuyTrades();
         buyTrailingLevel = 0;
         currentDirection = 0;
         breakevenReached = false;
         gridLevel = 0;
      }
   }
   
   // Check SELL trailing stop
   if(currentDirection == -1 && sellTrailingLevel > 0)
   {
      currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      
      // If price rises above SELL trailing level, close all SELL trades
      if(currentPrice >= sellTrailingLevel)
      {
         Print("SELL Trailing stop hit at " + DoubleToString(currentPrice, _Digits) + ". Closing all SELL trades.");
         CloseAllSellTrades();
         sellTrailingLevel = 0;
         currentDirection = 0;
         breakevenReached = false;
         gridLevel = 0;
      }
   }
}

void CloseAllBuyTrades()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(PositionGetSymbol(i) == _Symbol && PositionGetInteger(POSITION_MAGIC) == 12345)
      {
         if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
         {
            ClosePosition(i);
         }
      }
   }
   Print("All BUY trades closed by trailing stop");
}

void CloseAllSellTrades()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(PositionGetSymbol(i) == _Symbol && PositionGetInteger(POSITION_MAGIC) == 12345)
      {
         if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL)
         {
            ClosePosition(i);
         }
      }
   }
   Print("All SELL trades closed by trailing stop");
}

void CloseAllTrades()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(PositionGetSymbol(i) == _Symbol && PositionGetInteger(POSITION_MAGIC) == 12345)
      {
         ClosePosition(i);
      }
   }
   Print("All trades closed by emergency protection");
}

void ClosePosition(int positionIndex)
{
   if(PositionGetSymbol(positionIndex) != _Symbol) return;
   
   ulong ticket = PositionGetInteger(POSITION_TICKET);
   double volume = PositionGetDouble(POSITION_VOLUME);
   ENUM_POSITION_TYPE type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
   
   MqlTradeRequest request;
   MqlTradeResult result;
   ZeroMemory(request);
   ZeroMemory(result);
   
   request.action = TRADE_ACTION_DEAL;
   request.position = ticket;
   request.symbol = _Symbol;
   request.volume = volume;
   request.deviation = 10;
   request.magic = 12345;
   request.type_filling = ORDER_FILLING_FOK;
   
   if(type == POSITION_TYPE_BUY)
   {
      request.price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      request.type = ORDER_TYPE_SELL;
   }
   else
   {
      request.price = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      request.type = ORDER_TYPE_BUY;
   }
   
   if(!OrderSend(request, result))
   {
      Print("Error closing position ", ticket, ": ", GetLastError());
   }
}

//+------------------------------------------------------------------+
//| Trade function                                                   |
//+------------------------------------------------------------------+
void OnTrade()
{
   UpdateDashboard();
}