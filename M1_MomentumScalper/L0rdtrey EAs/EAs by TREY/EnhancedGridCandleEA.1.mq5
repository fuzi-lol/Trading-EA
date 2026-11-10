//+------------------------------------------------------------------+
//| EnhancedGridCandleEA.mq5                                        |
//| Copyright 2024, MetaQuotes Software Corp.                       |
//| https://www.mql5.com                                            |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, MetaQuotes Software Corp."
#property link      "https://www.mql5.com"
#property version   "2.10"

//--- Input parameters - Core
input int      MagicNumber    = 12345;     // Magic Number
input double   Lots           = 0.1;       // Base trade volume
input int      TakeProfit     = 500;       // Take Profit in pips
input int      BreakevenPips  = 50;        // Breakeven level in pips
input int      TrailingStop   = 50;        // Trailing Stop in pips
input int      MaxTrades      = 10;        // Maximum trades per direction
input bool     UseATR         = false;     // Use ATR for TP/SL
input int      ATR_Period     = 14;        // ATR Period

//--- Input parameters - Dynamic Lot Sizing
input bool     UseMartingale    = false;    // Use martingale lot sizing
input double   Multiplier       = 1.5;      // Lot multiplier for grid (reduced from 2.0)
input double   MaxLotSize       = 1.0;      // Maximum lot size
input double   RiskPerTrade     = 1.0;      // Risk % per trade

//--- Input parameters - Smart Grid
input int      GridSpacing      = 50;       // Pips between grid levels
input bool     UseSmartGrid     = true;     // Use dynamic grid spacing
input bool     UseRiskBasedLots = true;     // Calculate lots based on risk

//--- Input parameters - Risk Management
input double   MaxDrawdownPercent = 10.0;   // Max daily drawdown %
input bool     UseVolatilityFilter = true;  // Filter high volatility
input bool     UseEquityProtection = true;  // Use equity protection
input double   EmergencySL      = 200;      // Emergency SL in pips
input double   MaxSpreadPips    = 3.0;      // Maximum spread in pips
input bool     UseIndividualSL  = true;     // Use SL on each position

//--- Input parameters - Advanced Trailing
input bool     UseDynamicTrailing = true;   // Use dynamic trailing
input int      TrailingStart     = 20;      // Pips profit to start trailing
input int      TrailingStep      = 10;      // Pips step for trailing

//--- Input parameters - Time & Session Filters
input bool     UseTradingHours  = false;    // Enable trading hours
input string   StartTime        = "00:00";  // Trading start time
input string   EndTime          = "23:59";  // Trading end time

//--- Input parameters - Multi-Timeframe
input bool     UseMTFConfirmation = false;  // Use higher timeframe confirmation
input ENUM_TIMEFRAMES ConfirmTF = PERIOD_H1; // Confirmation timeframe

//--- Input parameters - Correlation Protection
input bool     CheckCorrelation = false;    // Check correlated pairs

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
datetime lastDayReset = 0;
string correlatedPairs[3] = {"EURUSD", "GBPUSD", "USDCHF"};

// Historical tracking
struct TradeHistory
{
   int totalTrades;
   int winningTrades;
   int losingTrades;
   double totalProfit;
   double totalLoss;
};
TradeHistory history;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   // Initialize pip size correctly
   int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   pipSize = (digits == 3 || digits == 5) ? 
             SymbolInfoDouble(_Symbol, SYMBOL_POINT) * 10 : 
             SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   
   // Validate inputs
   if(Lots < SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN))
   {
      Print("Error: Base lot size too small. Minimum: ", SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN));
      return(INIT_PARAMETERS_INCORRECT);
   }
   
   if(MaxTrades < 1 || MaxTrades > 100)
   {
      Print("Error: MaxTrades must be between 1 and 100");
      return(INIT_PARAMETERS_INCORRECT);
   }
   
   // Initialize ATR handle
   if(UseATR)
   {
      atrHandle = iATR(_Symbol, PERIOD_CURRENT, ATR_Period);
      if(atrHandle == INVALID_HANDLE)
      {
         Print("Error: Failed to create ATR indicator handle");
         return(INIT_FAILED);
      }
   }
   
   // Initialize variables
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
   
   // Initialize history
   history.totalTrades = 0;
   history.winningTrades = 0;
   history.losingTrades = 0;
   history.totalProfit = 0;
   history.totalLoss = 0;
   
   EventSetTimer(60); // Check every minute
   Print("Enhanced Grid Candle EA v2.10 Started Successfully");
   Print("Symbol: ", _Symbol, " | Magic: ", MagicNumber, " | Pip Size: ", pipSize);
   
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
   Comment("");
   
   Print("Enhanced Grid Candle EA Stopped. Reason: ", reason);
   Print("Total Trades: ", history.totalTrades, 
         " | Wins: ", history.winningTrades, 
         " | Losses: ", history.losingTrades);
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
   // Check for day reset
   datetime current = TimeCurrent();
   MqlDateTime timeStruct;
   TimeToStruct(current, timeStruct);
   
   if(timeStruct.day != lastDayReset)
   {
      tradeCountToday = 0;
      dailyMaxBalance = AccountInfoDouble(ACCOUNT_BALANCE);
      dailyMinBalance = AccountInfoDouble(ACCOUNT_EQUITY);
      lastDayReset = timeStruct.day;
      Print("Daily statistics reset - New trading day");
   }
   
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
      if(UseMTFConfirmation && !HasMTFConfirmation(isBullish ? -1 : 1)) {
         Print("No MTF confirmation - skipping trade");
         return;
      }
      
      breakevenReached = false;
      gridLevel = 0;
      
      if(isBullish && currentDirection <= 0)
      {
         double lotSize = CalculateDynamicLot(1);
         if(OpenTrade(ORDER_TYPE_SELL, lotSize, tpPoints, "Initial Sell"))
         {
            currentDirection = -1;
            sellTrailingLevel = 0;
            gridLevel = 1;
         }
      }
      else if(isBearish && currentDirection >= 0)
      {
         double lotSize = CalculateDynamicLot(1);
         if(OpenTrade(ORDER_TYPE_BUY, lotSize, tpPoints, "Initial Buy"))
         {
            currentDirection = 1;
            buyTrailingLevel = 0;
            gridLevel = 1;
         }
      }
   }
   // Grid trades - only if spacing condition met
   else if(currentTrades < MaxTrades && !breakevenReached)
   {
      if(!ShouldOpenGridTrade()) {
         return;
      }
      
      if(currentDirection == 1) // BUY direction
      {
         double lotSize = CalculateDynamicLot(gridLevel + 1);
         if(OpenTrade(ORDER_TYPE_BUY, lotSize, tpPoints, "Grid Buy " + IntegerToString(currentTrades + 1)))
         {
            gridLevel++;
         }
      }
      else if(currentDirection == -1) // SELL direction
      {
         double lotSize = CalculateDynamicLot(gridLevel + 1);
         if(OpenTrade(ORDER_TYPE_SELL, lotSize, tpPoints, "Grid Sell " + IntegerToString(currentTrades + 1)))
         {
            gridLevel++;
         }
      }
   }
   // Reset if all trades closed
   else if(currentTrades == 0 && breakevenReached)
   {
      ResetTradingState();
   }
}

//+------------------------------------------------------------------+
//| Reset trading state                                             |
//+------------------------------------------------------------------+
void ResetTradingState()
{
   currentDirection = 0;
   buyTrailingLevel = 0;
   sellTrailingLevel = 0;
   breakevenReached = false;
   gridLevel = 0;
   Print("Trading state reset - Ready for new sequence");
}

//+------------------------------------------------------------------+
//| Dynamic Lot Sizing with Normalization                           |
//+------------------------------------------------------------------+
double CalculateDynamicLot(int currentGridLevel)
{
   double dynamicLot = Lots;
   
   // Calculate based on risk if enabled
   if(UseRiskBasedLots)
   {
      dynamicLot = CalculateRiskBasedLot();
   }
   
   // Apply martingale if enabled
   if(UseMartingale && currentGridLevel > 1)
   {
      dynamicLot = dynamicLot * MathPow(Multiplier, currentGridLevel - 1);
   }
   
   // Normalize lot size
   return NormalizeLot(dynamicLot);
}

//+------------------------------------------------------------------+
//| Calculate risk-based lot size                                   |
//+------------------------------------------------------------------+
double CalculateRiskBasedLot()
{
   double accountEquity = AccountInfoDouble(ACCOUNT_EQUITY);
   double riskAmount = accountEquity * (RiskPerTrade / 100.0);
   double slPoints = EmergencySL * pipSize;
   
   if(slPoints <= 0) return Lots;
   
   double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   
   if(tickValue == 0 || tickSize == 0) return Lots;
   
   double lotSize = riskAmount / (slPoints / tickSize * tickValue);
   
   return lotSize;
}

//+------------------------------------------------------------------+
//| Normalize lot size                                              |
//+------------------------------------------------------------------+
double NormalizeLot(double lotSize)
{
   double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   
   // Apply maximum limit
   lotSize = MathMin(lotSize, MaxLotSize);
   
   // Apply broker limits
   lotSize = MathMax(lotSize, minLot);
   lotSize = MathMin(lotSize, maxLot);
   
   // Round to lot step
   lotSize = MathFloor(lotSize / lotStep) * lotStep;
   
   // Final validation
   if(lotSize < minLot) lotSize = minLot;
   
   return lotSize;
}

//+------------------------------------------------------------------+
//| Smart Grid Spacing - Fixed Logic                                |
//+------------------------------------------------------------------+
bool ShouldOpenGridTrade()
{
   if(!UseSmartGrid) return true;
   
   double lastPrice = GetLastTradePrice();
   if(lastPrice == 0) return false;
   
   double currentPrice = (currentDirection == 1) ? 
                         SymbolInfoDouble(_Symbol, SYMBOL_BID) : 
                         SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   
   double spacingPoints = GridSpacing * pipSize;
   double priceDifference = MathAbs(currentPrice - lastPrice);
   
   // For BUY direction, price should move DOWN (against us)
   if(currentDirection == 1)
   {
      return (lastPrice - currentPrice) >= spacingPoints;
   }
   // For SELL direction, price should move UP (against us)
   else if(currentDirection == -1)
   {
      return (currentPrice - lastPrice) >= spacingPoints;
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| Get last trade opening price                                    |
//+------------------------------------------------------------------+
double GetLastTradePrice()
{
   datetime latestTime = 0;
   double latestPrice = 0;
   
   for(int i = 0; i < PositionsTotal(); i++)
   {
      if(PositionGetSymbol(i) == _Symbol && 
         PositionGetInteger(POSITION_MAGIC) == MagicNumber)
      {
         datetime openTime = (datetime)PositionGetInteger(POSITION_TIME);
         if(openTime > latestTime)
         {
            latestTime = openTime;
            latestPrice = PositionGetDouble(POSITION_PRICE_OPEN);
         }
      }
   }
   
   return latestPrice;
}

//+------------------------------------------------------------------+
//| Check if spread is acceptable                                   |
//+------------------------------------------------------------------+
bool IsSpreadAcceptable()
{
   long spreadPoints = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   double spreadPips = spreadPoints * _Point / pipSize;
   
   if(spreadPips > MaxSpreadPips)
   {
      Print("Spread too high: ", DoubleToString(spreadPips, 1), " pips (Max: ", MaxSpreadPips, ")");
      return false;
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| Comprehensive safety check                                      |
//+------------------------------------------------------------------+
bool IsSafeToTrade()
{
   // Check spread
   if(!IsSpreadAcceptable())
      return false;
   
   // Check trading hours
   if(UseTradingHours && !IsTradingTime())
      return false;
   
   // Check daily drawdown
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   
   if(balance > 0)
   {
      double drawdownPercent = ((balance - equity) / balance) * 100;
      if(drawdownPercent >= MaxDrawdownPercent)
      {
         Print("Max drawdown reached: ", DoubleToString(drawdownPercent, 2), "%");
         return false;
      }
   }
   
   // Check volatility
   if(UseVolatilityFilter)
   {
      double atr = GetATRValue();
      if(atr > 0)
      {
         double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
         double atrPercent = (atr / currentPrice) * 100;
         if(atrPercent > 2.0)
         {
            Print("High volatility detected: ", DoubleToString(atrPercent, 2), "%");
            return false;
         }
      }
   }
   
   // Check correlation risk
   if(CheckCorrelation && HasCorrelatedRisk())
   {
      Print("Correlated risk detected");
      return false;
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| Get ATR value safely                                            |
//+------------------------------------------------------------------+
double GetATRValue()
{
   if(!UseATR || atrHandle == INVALID_HANDLE) return 0;
   
   double atrBuffer[];
   ArraySetAsSeries(atrBuffer, true);
   
   if(CopyBuffer(atrHandle, 0, 0, 1, atrBuffer) > 0)
      return atrBuffer[0];
   
   return 0;
}

//+------------------------------------------------------------------+
//| Check trading time                                              |
//+------------------------------------------------------------------+
bool IsTradingTime()
{
   if(!UseTradingHours) return true;
   
   MqlDateTime timeStruct;
   TimeToStruct(TimeCurrent(), timeStruct);
   
   int currentMinutes = timeStruct.hour * 60 + timeStruct.min;
   
   // Parse start and end times
   string startParts[];
   string endParts[];
   StringSplit(StartTime, ':', startParts);
   StringSplit(EndTime, ':', endParts);
   
   if(ArraySize(startParts) != 2 || ArraySize(endParts) != 2)
      return true; // Invalid format, allow trading
   
   int startMinutes = (int)StringToInteger(startParts[0]) * 60 + 
                      (int)StringToInteger(startParts[1]);
   int endMinutes = (int)StringToInteger(endParts[0]) * 60 + 
                    (int)StringToInteger(endParts[1]);
   
   return (currentMinutes >= startMinutes && currentMinutes <= endMinutes);
}

//+------------------------------------------------------------------+
//| Multi-timeframe confirmation                                    |
//+------------------------------------------------------------------+
bool HasMTFConfirmation(int direction)
{
   if(!UseMTFConfirmation) return true;
   
   double mtfOpen = iOpen(_Symbol, ConfirmTF, 1);
   double mtfClose = iClose(_Symbol, ConfirmTF, 1);
   
   if(mtfOpen == 0 || mtfClose == 0) return true; // Data error, allow trade
   
   bool mtfBullish = (mtfClose > mtfOpen);
   
   // For counter-trend: we want opposite confirmation
   // If direction = 1 (BUY), we want bearish HTF
   // If direction = -1 (SELL), we want bullish HTF
   if(direction == 1) return !mtfBullish; // BUY on bearish HTF
   if(direction == -1) return mtfBullish;  // SELL on bullish HTF
   
   return true;
}

//+------------------------------------------------------------------+
//| Check correlated risk                                           |
//+------------------------------------------------------------------+
bool HasCorrelatedRisk()
{
   if(!CheckCorrelation) return false;
   
   int totalExposure = 0;
   for(int i = 0; i < ArraySize(correlatedPairs); i++)
   {
      totalExposure += CountTradesForSymbol(correlatedPairs[i]);
   }
   
   // Risk if we have too many trades across correlated pairs
   return (totalExposure >= MaxTrades * 2);
}

//+------------------------------------------------------------------+
//| Count trades for specific symbol                                |
//+------------------------------------------------------------------+
int CountTradesForSymbol(string symbol)
{
   int count = 0;
   for(int i = 0; i < PositionsTotal(); i++)
   {
      if(PositionGetSymbol(i) == symbol && 
         PositionGetInteger(POSITION_MAGIC) == MagicNumber)
         count++;
   }
   return count;
}

//+------------------------------------------------------------------+
//| Emergency close with proper shutdown                            |
//+------------------------------------------------------------------+
void CheckEmergencyClose()
{
   if(!UseEquityProtection) return;
   
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   
   if(balance > 0)
   {
      double equityPercent = equity / balance;
      
      if(equityPercent < 0.90) // 10% drawdown
      {
         Print("=== EMERGENCY CLOSE ACTIVATED ===");
         Print("Equity: ", equity, " | Balance: ", balance);
         Print("Drawdown: ", DoubleToString((1 - equityPercent) * 100, 2), "%");
         
         CloseAllTrades();
         ResetTradingState();
         
         // Disable further trading until manual restart
         ExpertRemove();
      }
   }
}

//+------------------------------------------------------------------+
//| Advanced trailing stop logic - FIXED                            |
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
      double avgOpenPrice = GetAverageBuyPrice();
      
      // Check for breakeven
      if(!breakevenReached && currentPrice >= avgOpenPrice + breakevenPoints)
      {
         breakevenReached = true;
         buyTrailingLevel = avgOpenPrice + breakevenPoints;
         Print("BUY Breakeven +", BreakevenPips, " pips reached at ", 
               DoubleToString(buyTrailingLevel, _Digits));
      }
      
      // Update trailing stop
      if(breakevenReached)
      {
         double newTrailingLevel = currentPrice - trailingPoints;
         if(newTrailingLevel > buyTrailingLevel)
         {
            buyTrailingLevel = newTrailingLevel;
         }
      }
   }
   
   // Update SELL trailing level
   if(currentDirection == -1 && CountSellTrades() > 0)
   {
      currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      double avgOpenPrice = GetAverageSellPrice();
      
      // Check for breakeven
      if(!breakevenReached && currentPrice <= avgOpenPrice - breakevenPoints)
      {
         breakevenReached = true;
         sellTrailingLevel = avgOpenPrice - breakevenPoints;
         Print("SELL Breakeven +", BreakevenPips, " pips reached at ", 
               DoubleToString(sellTrailingLevel, _Digits));
      }
      
      // Update trailing stop
      if(breakevenReached)
      {
         double newTrailingLevel = currentPrice + trailingPoints;
         if(newTrailingLevel < sellTrailingLevel)
         {
            sellTrailingLevel = newTrailingLevel;
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Dynamic trailing distance                                       |
//+------------------------------------------------------------------+
double GetDynamicTrailingDistance()
{
   if(!UseDynamicTrailing) return TrailingStop;
   
   double profitPips = CalculateProfitInPips();
   
   if(profitPips > 300) return 10;
   if(profitPips > 200) return 20;
   if(profitPips > 100) return 30;
   if(profitPips > 50) return 40;
   
   return TrailingStop;
}

//+------------------------------------------------------------------+
//| Calculate profit in pips                                        |
//+------------------------------------------------------------------+
double CalculateProfitInPips()
{
   double totalProfit = CalculateCurrentPL();
   double totalVolume = GetTotalVolume();
   
   if(totalVolume == 0 || pipSize == 0) return 0;
   
   double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   if(tickValue == 0) return 0;
   
   double pips = totalProfit / (totalVolume * tickValue * 10);
   
   return MathAbs(pips);
}

//+------------------------------------------------------------------+
//| Get total volume of open positions                              |
//+------------------------------------------------------------------+
double GetTotalVolume()
{
   double volume = 0;
   for(int i = 0; i < PositionsTotal(); i++)
   {
      if(PositionGetSymbol(i) == _Symbol && 
         PositionGetInteger(POSITION_MAGIC) == MagicNumber)
      {
         volume += PositionGetDouble(POSITION_VOLUME);
      }
   }
   return volume;
}

//+------------------------------------------------------------------+
//| Check trailing stop hit                                         |
//+------------------------------------------------------------------+
void CheckTrailingStopHit()
{
   double currentPrice;
   
   // Check BUY trailing
   if(currentDirection == 1 && buyTrailingLevel > 0)
   {
      currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      
      if(currentPrice <= buyTrailingLevel)
      {
         double finalPL = CalculateCurrentPL();
         Print("=== BUY Trailing Stop Hit ===");
         Print("Close Price: ", DoubleToString(currentPrice, _Digits));
         Print("Trailing Level: ", DoubleToString(buyTrailingLevel, _Digits));
         Print("Final P/L: ", DoubleToString(finalPL, 2));
         
         CloseAllBuyTrades();
         ResetTradingState();
      }
   }
   
   // Check SELL trailing
   if(currentDirection == -1 && sellTrailingLevel > 0)
   {
      currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      
      if(currentPrice >= sellTrailingLevel)
      {
         double finalPL = CalculateCurrentPL();
         Print("=== SELL Trailing Stop Hit ===");
         Print("Close Price: ", DoubleToString(currentPrice, _Digits));
         Print("Trailing Level: ", DoubleToString(sellTrailingLevel, _Digits));
         Print("Final P/L: ", DoubleToString(finalPL, 2));
         
         CloseAllSellTrades();
         ResetTradingState();
      }
   }
}

//+------------------------------------------------------------------+
//| Calculate TP points                                             |
//+------------------------------------------------------------------+
void CalculateTP(double &tpPoints)
{
   if(UseATR)
   {
      double atrValue = GetATRValue();
      if(atrValue > 0)
      {
         tpPoints = atrValue * 3;
         return;
      }
   }
   
   tpPoints = TakeProfit * pipSize;
}

//+------------------------------------------------------------------+
//| Open trade with full error handling                             |
//+------------------------------------------------------------------+
bool OpenTrade(ENUM_ORDER_TYPE orderType, double volume, double tpPoints, string comment)
{
   // Final lot validation
   volume = NormalizeLot(volume);
   
   double price = 0;
   double tp = 0;
   double sl = 0;
   
   MqlTradeRequest request;
   MqlTradeResult result;
   ZeroMemory(request);
   ZeroMemory(result);
   
   // Set price and TP/SL
   if(orderType == ORDER_TYPE_BUY)
   {
      price = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(tpPoints > 0) tp = price + tpPoints;
      if(UseIndividualSL && EmergencySL > 0) 
         sl = price - (EmergencySL * pipSize);
   }
   else if(orderType == ORDER_TYPE_SELL)
   {
      price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      if(tpPoints > 0) tp = price - tpPoints;
      if(UseIndividualSL && EmergencySL > 0) 
         sl = price + (EmergencySL * pipSize);
   }
   
   // Prepare request
   request.action = TRADE_ACTION_DEAL;
   request.symbol = _Symbol;
   request.volume = volume;
   request.type = orderType;
   request.price = price;
   request.sl = sl;
   request.tp = tp;
   request.deviation = 10;
   request.magic = MagicNumber;
   request.comment = comment;
   request.type_filling = ORDER_FILLING_FOK;
   
   // Try to send order with retries
   int maxRetries = 3;
   for(int retry = 0; retry < maxRetries; retry++)
   {
      if(OrderSend(request, result))
      {
         if(result.retcode == TRADE_RETCODE_DONE || 
            result.retcode == TRADE_RETCODE_PLACED)
         {
            Print("✓ Trade Opened: ", comment);
            Print("  Volume: ", volume, " | Price: ", DoubleToString(price, _Digits));
            if(sl > 0) Print("  SL: ", DoubleToString(sl, _Digits));
            if(tp > 0) Print("  TP: ", DoubleToString(tp, _Digits));
            
            tradeCountToday++;
            return true;
         }
      }
      
      Print("✗ Trade failed (", retry + 1, "/", maxRetries, "): ", 
            result.retcode, " - ", GetTradeErrorDescription(result.retcode));
      
      if(result.retcode == TRADE_RETCODE_INVALID_STOPS ||
         result.retcode == TRADE_RETCODE_INVALID_PRICE)
         break; // Don't retry on these errors
      
      Sleep(1000);
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| Get trade error description                                     |
//+------------------------------------------------------------------+
string GetTradeErrorDescription(uint retcode)
{
   switch(retcode)
   {
      case TRADE_RETCODE_DONE: return "Done";
      case TRADE_RETCODE_INVALID: return "Invalid request";
      case TRADE_RETCODE_REJECT: return "Request rejected";
      case TRADE_RETCODE_NO_MONEY: return "Not enough money";
      case TRADE_RETCODE_PRICE_OFF: return "Invalid price";
      case TRADE_RETCODE_INVALID_STOPS: return "Invalid stops";
      case TRADE_RETCODE_TRADE_DISABLED: return "Trading disabled";
      case TRADE_RETCODE_MARKET_CLOSED: return "Market closed";
      case TRADE_RETCODE_INVALID_VOLUME: return "Invalid volume";
      default: return "Error " + IntegerToString(retcode);
   }
}

//+------------------------------------------------------------------+
//| Position counting and management                                |
//+------------------------------------------------------------------+
void DetermineCurrentDirection()
{
   int buyCount = 0;
   int sellCount = 0;
   
   for(int i = 0; i < PositionsTotal(); i++)
   {
      if(PositionGetSymbol(i) == _Symbol && 
         PositionGetInteger(POSITION_MAGIC) == MagicNumber)
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

//+------------------------------------------------------------------+
//| Count all trades                                                |
//+------------------------------------------------------------------+
int CountTrades()
{
   int count = 0;
   for(int i = 0; i < PositionsTotal(); i++)
   {
      if(PositionGetSymbol(i) == _Symbol && 
         PositionGetInteger(POSITION_MAGIC) == MagicNumber)
         count++;
   }
   return count;
}

//+------------------------------------------------------------------+
//| Count BUY trades                                                |
//+------------------------------------------------------------------+
int CountBuyTrades()
{
   int count = 0;
   for(int i = 0; i < PositionsTotal(); i++)
   {
      if(PositionGetSymbol(i) == _Symbol && 
         PositionGetInteger(POSITION_MAGIC) == MagicNumber &&
         PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
         count++;
   }
   return count;
}

//+------------------------------------------------------------------+
//| Count SELL trades                                               |
//+------------------------------------------------------------------+
int CountSellTrades()
{
   int count = 0;
   for(int i = 0; i < PositionsTotal(); i++)
   {
      if(PositionGetSymbol(i) == _Symbol && 
         PositionGetInteger(POSITION_MAGIC) == MagicNumber &&
         PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL)
         count++;
   }
   return count;
}

//+------------------------------------------------------------------+
//| Calculate current P/L                                           |
//+------------------------------------------------------------------+
double CalculateCurrentPL()
{
   double pl = 0;
   for(int i = 0; i < PositionsTotal(); i++)
   {
      if(PositionGetSymbol(i) == _Symbol && 
         PositionGetInteger(POSITION_MAGIC) == MagicNumber)
      {
         pl += PositionGetDouble(POSITION_PROFIT) + 
               PositionGetDouble(POSITION_SWAP);
      }
   }
   return pl;
}

//+------------------------------------------------------------------+
//| Get average BUY price                                           |
//+------------------------------------------------------------------+
double GetAverageBuyPrice()
{
   double totalVolume = 0;
   double totalValue = 0;
   
   for(int i = 0; i < PositionsTotal(); i++)
   {
      if(PositionGetSymbol(i) == _Symbol && 
         PositionGetInteger(POSITION_MAGIC) == MagicNumber &&
         PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
      {
         double volume = PositionGetDouble(POSITION_VOLUME);
         double price = PositionGetDouble(POSITION_PRICE_OPEN);
         totalValue += volume * price;
         totalVolume += volume;
      }
   }
   
   return (totalVolume > 0) ? totalValue / totalVolume : 0;
}

//+------------------------------------------------------------------+
//| Get average SELL price                                          |
//+------------------------------------------------------------------+
double GetAverageSellPrice()
{
   double totalVolume = 0;
   double totalValue = 0;
   
   for(int i = 0; i < PositionsTotal(); i++)
   {
      if(PositionGetSymbol(i) == _Symbol && 
         PositionGetInteger(POSITION_MAGIC) == MagicNumber &&
         PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL)
      {
         double volume = PositionGetDouble(POSITION_VOLUME);
         double price = PositionGetDouble(POSITION_PRICE_OPEN);
         totalValue += volume * price;
         totalVolume += volume;
      }
   }
   
   return (totalVolume > 0) ? totalValue / totalVolume : 0;
}

//+------------------------------------------------------------------+
//| Close all BUY trades                                            |
//+------------------------------------------------------------------+
void CloseAllBuyTrades()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(PositionGetSymbol(i) == _Symbol && 
         PositionGetInteger(POSITION_MAGIC) == MagicNumber &&
         PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
      {
         ClosePosition(i);
      }
   }
}

//+------------------------------------------------------------------+
//| Close all SELL trades                                           |
//+------------------------------------------------------------------+
void CloseAllSellTrades()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(PositionGetSymbol(i) == _Symbol && 
         PositionGetInteger(POSITION_MAGIC) == MagicNumber &&
         PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL)
      {
         ClosePosition(i);
      }
   }
}

//+------------------------------------------------------------------+
//| Close all trades                                                |
//+------------------------------------------------------------------+
void CloseAllTrades()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(PositionGetSymbol(i) == _Symbol && 
         PositionGetInteger(POSITION_MAGIC) == MagicNumber)
      {
         ClosePosition(i);
      }
   }
}

//+------------------------------------------------------------------+
//| Close single position                                           |
//+------------------------------------------------------------------+
void ClosePosition(int positionIndex)
{
   if(PositionGetSymbol(positionIndex) != _Symbol) return;
   
   ulong ticket = PositionGetInteger(POSITION_TICKET);
   double volume = PositionGetDouble(POSITION_VOLUME);
   ENUM_POSITION_TYPE type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
   double profit = PositionGetDouble(POSITION_PROFIT);
   
   MqlTradeRequest request;
   MqlTradeResult result;
   ZeroMemory(request);
   ZeroMemory(result);
   
   request.action = TRADE_ACTION_DEAL;
   request.position = ticket;
   request.symbol = _Symbol;
   request.volume = volume;
   request.deviation = 10;
   request.magic = MagicNumber;
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
   
   if(OrderSend(request, result))
   {
      if(result.retcode == TRADE_RETCODE_DONE)
      {
         Print("Position #", ticket, " closed. Profit: ", DoubleToString(profit, 2));
         
         // Update statistics
         history.totalTrades++;
         if(profit > 0)
         {
            history.winningTrades++;
            history.totalProfit += profit;
         }
         else
         {
            history.losingTrades++;
            history.totalLoss += MathAbs(profit);
         }
      }
   }
   else
   {
      Print("Error closing position #", ticket, ": ", result.retcode);
   }
}

//+------------------------------------------------------------------+
//| Update daily metrics                                            |
//+------------------------------------------------------------------+
void UpdateDailyMetrics()
{
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   
   if(balance > dailyMaxBalance) dailyMaxBalance = balance;
   if(equity < dailyMinBalance) dailyMinBalance = equity;
}

//+------------------------------------------------------------------+
//| Calculate real statistics                                       |
//+------------------------------------------------------------------+
double CalculateWinRate()
{
   if(history.totalTrades == 0) return 0;
   return (history.winningTrades * 100.0) / history.totalTrades;
}

//+------------------------------------------------------------------+
//| Calculate profit factor                                         |
//+------------------------------------------------------------------+
double CalculateProfitFactor()
{
   if(history.totalLoss == 0) return (history.totalProfit > 0) ? 999.99 : 0;
   return history.totalProfit / history.totalLoss;
}

//+------------------------------------------------------------------+
//| Calculate drawdown percentage                                   |
//+------------------------------------------------------------------+
double CalculateDrawdownPercent()
{
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   
   if(balance <= 0) return 0;
   return ((balance - equity) / balance) * 100;
}

//+------------------------------------------------------------------+
//| Enhanced dashboard                                              |
//+------------------------------------------------------------------+
void UpdateDashboard()
{
   double currentPL = CalculateCurrentPL();
   int totalTrades = CountTrades();
   
   string directionText = "None";
   if(currentDirection == 1) directionText = "BUY";
   else if(currentDirection == -1) directionText = "SELL";
   
   string breakevenStatus = breakevenReached ? 
                           "✓ ACTIVE" : 
                           "Waiting +" + IntegerToString(BreakevenPips) + " pips";
   
   double winRate = CalculateWinRate();
   double profitFactor = CalculateProfitFactor();
   double drawdownPercent = CalculateDrawdownPercent();
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   
   string dashboard = "";
   dashboard += "╔════════════════════════════════════════╗\n";
   dashboard += "║   ENHANCED GRID CANDLE EA v2.10       ║\n";
   dashboard += "╠════════════════════════════════════════╣\n";
   dashboard += "║ Symbol: " + _Symbol + StringFill(' ', 30 - StringLen(_Symbol)) + "║\n";
   dashboard += "║ Direction: " + directionText + StringFill(' ', 27 - StringLen(directionText)) + "║\n";
   dashboard += "║ Grid: " + IntegerToString(gridLevel) + "/" + IntegerToString(MaxTrades) + 
                StringFill(' ', 31 - StringLen(IntegerToString(gridLevel) + "/" + IntegerToString(MaxTrades))) + "║\n";
   dashboard += "║ Breakeven: " + breakevenStatus + StringFill(' ', 27 - StringLen(breakevenStatus)) + "║\n";
   dashboard += "╠════════════════════════════════════════╣\n";
   dashboard += "║ ACCOUNT                                ║\n";
   dashboard += "║ Balance: " + DoubleToString(balance, 2) + " " + AccountInfoString(ACCOUNT_CURRENCY) + 
                StringFill(' ', 27 - StringLen(DoubleToString(balance, 2))) + "║\n";
   dashboard += "║ Equity:  " + DoubleToString(equity, 2) + " " + AccountInfoString(ACCOUNT_CURRENCY) + 
                StringFill(' ', 27 - StringLen(DoubleToString(equity, 2))) + "║\n";
   dashboard += "║ Current P/L: " + DoubleToString(currentPL, 2) + 
                StringFill(' ', 25 - StringLen(DoubleToString(currentPL, 2))) + "║\n";
   dashboard += "╠════════════════════════════════════════╣\n";
   dashboard += "║ STATISTICS                             ║\n";
   dashboard += "║ Trades Today: " + IntegerToString(tradeCountToday) + 
                StringFill(' ', 24 - StringLen(IntegerToString(tradeCountToday))) + "║\n";
   dashboard += "║ Active: " + IntegerToString(totalTrades) + 
                StringFill(' ', 30 - StringLen(IntegerToString(totalTrades))) + "║\n";
   dashboard += "║ Win Rate: " + DoubleToString(winRate, 1) + "%" + 
                StringFill(' ', 27 - StringLen(DoubleToString(winRate, 1) + "%")) + "║\n";
   dashboard += "║ Profit Factor: " + DoubleToString(profitFactor, 2) + 
                StringFill(' ', 23 - StringLen(DoubleToString(profitFactor, 2))) + "║\n";
   dashboard += "║ Drawdown: " + DoubleToString(drawdownPercent, 1) + "%" + 
                StringFill(' ', 27 - StringLen(DoubleToString(drawdownPercent, 1) + "%")) + "║\n";
   dashboard += "╠════════════════════════════════════════╣\n";
   dashboard += "║ TRAILING                               ║\n";
   
   if(buyTrailingLevel > 0)
      dashboard += "║ BUY: " + DoubleToString(buyTrailingLevel, _Digits) + 
                   StringFill(' ', 33 - StringLen(DoubleToString(buyTrailingLevel, _Digits))) + "║\n";
   else
      dashboard += "║ BUY: Not Active" + StringFill(' ', 23) + "║\n";
   
   if(sellTrailingLevel > 0)
      dashboard += "║ SELL: " + DoubleToString(sellTrailingLevel, _Digits) + 
                   StringFill(' ', 32 - StringLen(DoubleToString(sellTrailingLevel, _Digits))) + "║\n";
   else
      dashboard += "║ SELL: Not Active" + StringFill(' ', 22) + "║\n";
   
   dashboard += "╚════════════════════════════════════════╝";
   
   Comment(dashboard);
}

//+------------------------------------------------------------------+
//| String fill helper                                              |
//+------------------------------------------------------------------+
string StringFill(char fillChar, int count)
{
   string result = "";
   for(int i = 0; i < count; i++)
      result += CharToString(fillChar);
   return result;
}

//+------------------------------------------------------------------+
//| OnTrade event                                                   |
//+------------------------------------------------------------------+
void OnTrade()
{
   UpdateDashboard();
}

//+------------------------------------------------------------------+