//+------------------------------------------------------------------+
//| EnhancedGridCandleEA.mq5                                        |
//| Copyright 2024, MetaQuotes Software Corp.                       |
//| https://www.mql5.com                                            |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, MetaQuotes Software Corp."
#property link      "https://www.mql5.com"
#property version   "2.01"

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
input double   RiskPerTrade     = 0.0;      // Risk % per trade (0=disabled)

//--- Input parameters - Smart Grid
input int      GridSpacing      = 50;       // Pips between grid levels
input bool     UseSmartGrid     = true;     // Use dynamic grid spacing

//--- Input parameters - Risk Management
input double   MaxDrawdownPercent = 10.0;   // Max daily drawdown %
input bool     UseVolatilityFilter = true;  // Filter high volatility
input bool     UseEquityProtection = true;  // Use equity protection
input double   EmergencySL      = 200;      // Emergency SL in pips
input double   MaxVolatilityPercent = 2.0;  // Max ATR % for trading

//--- Input parameters - Advanced Trailing
input bool     UseDynamicTrailing = true;   // Use dynamic trailing
input int      TrailingStart     = 20;      // Pips profit to start trailing
input int      TrailingStep      = 10;      // Pips step for trailing

//--- Input parameters - Time & Session Filters
input bool     UseTradingHours  = true;     // Enable trading hours
input string   StartTime        = "00:00";  // Trading start time
input string   EndTime          = "23:59";  // Trading end time
input bool     AvoidNews        = false;    // Avoid high impact news
input int      NewsAvoidMinutes = 60;       // Minutes before/after news

//--- Input parameters - Multi-Timeframe
input bool     UseMTFConfirmation = true;   // Use higher timeframe confirmation
input ENUM_TIMEFRAMES ConfirmTF = PERIOD_H1; // Confirmation timeframe

//--- Input parameters - Correlation Protection
input bool     CheckCorrelation = true;     // Check correlated pairs

//--- Input parameters - Magic Number
input int      MagicNumber      = 12345;    // Magic number for trades

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
datetime lastResetDate = 0;
string correlatedPairs[3] = {"EURUSD", "GBPUSD", "USDCHF"};

// Trade history tracking
struct TradeStats {
   int totalTrades;
   int winningTrades;
   int losingTrades;
   double totalProfit;
   double totalLoss;
};
TradeStats dailyStats;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   // Calculate pip size
   int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   if(digits == 3 || digits == 5)
      pipSize = SymbolInfoDouble(_Symbol, SYMBOL_POINT) * 10;
   else
      pipSize = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   
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
   lastResetDate = GetCurrentDate();
   
   // Initialize stats
   ZeroMemory(dailyStats);
   
   // Initialize ATR indicator
   atrHandle = INVALID_HANDLE;
   if(UseATR)
   {
      atrHandle = iATR(_Symbol, PERIOD_CURRENT, ATR_Period);
      if(atrHandle == INVALID_HANDLE)
      {
         Print("ERROR: Failed to create ATR indicator handle! Error: ", GetLastError());
         Print("ATR features will be disabled.");
      }
      else
      {
         Print("ATR indicator initialized successfully");
      }
   }
   
   // Validate lot size
   double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   if(Lots < minLot || Lots > maxLot)
   {
      Print("ERROR: Invalid lot size. Min: ", minLot, " Max: ", maxLot);
      return(INIT_PARAMETERS_INCORRECT);
   }
   
   EventSetTimer(60); // Timer every 60 seconds
   Print("╔════════════════════════════════════════╗");
   Print("║  Enhanced Grid Candle EA v2.01        ║");
   Print("║  Status: ACTIVE                        ║");
   Print("╚════════════════════════════════════════╝");
   Print("Symbol: ", _Symbol);
   Print("Pip Size: ", DoubleToString(pipSize, _Digits));
   Print("Base Lot: ", Lots);
   Print("Max Trades: ", MaxTrades);
   Print("Breakeven: ", BreakevenPips, " pips");
   Print("Trailing: ", TrailingStop, " pips");
   
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
   
   Print("╔════════════════════════════════════════╗");
   Print("║  Enhanced Grid Candle EA Stopped      ║");
   Print("╚════════════════════════════════════════╝");
   Print("Reason: ", reason);
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
}

//+------------------------------------------------------------------+
//| Timer function                                                   |
//+------------------------------------------------------------------+
void OnTimer()
{
   // Check for daily reset
   datetime currentDate = GetCurrentDate();
   if(currentDate != lastResetDate)
   {
      ResetDailyMetrics();
      lastResetDate = currentDate;
   }
   
   UpdateDailyMetrics();
   UpdateDashboard();
}

//+------------------------------------------------------------------+
//| Get current date                                                 |
//+------------------------------------------------------------------+
datetime GetCurrentDate()
{
   MqlDateTime timeStruct;
   TimeToStruct(TimeCurrent(), timeStruct);
   timeStruct.hour = 0;
   timeStruct.min = 0;
   timeStruct.sec = 0;
   return StructToTime(timeStruct);
}

//+------------------------------------------------------------------+
//| Reset daily metrics                                             |
//+------------------------------------------------------------------+
void ResetDailyMetrics()
{
   tradeCountToday = 0;
   dailyMaxBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   dailyMinBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   ZeroMemory(dailyStats);
   Print("═══ Daily Metrics Reset ═══");
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
   
   if(prevOpen == 0 || prevClose == 0) return;
   
   // Determine candle type
   bool isBullish = (prevClose > prevOpen);
   bool isBearish = (prevClose < prevOpen);
   
   // Calculate TP level
   double tpPoints = CalculateTP();
   
   // Check current positions to determine direction
   DetermineCurrentDirection();
   
   // Update grid level
   int currentTrades = CountTrades();
   gridLevel = currentTrades;
   
   // If no positions, follow candle direction with confirmation
   if(currentTrades == 0)
   {
      if(!HasMTFConfirmation(isBullish, isBearish)) {
         Print("No MTF confirmation - skipping trade");
         return;
      }
      
      breakevenReached = false;
      
      if(isBullish && currentDirection <= 0)
      {
         double lotSize = CalculateDynamicLot(1);
         if(OpenTrade(ORDER_TYPE_SELL, lotSize, tpPoints, "Initial Sell"))
         {
            currentDirection = -1;
            sellTrailingLevel = 0;
         }
      }
      else if(isBearish && currentDirection >= 0)
      {
         double lotSize = CalculateDynamicLot(1);
         if(OpenTrade(ORDER_TYPE_BUY, lotSize, tpPoints, "Initial Buy"))
         {
            currentDirection = 1;
            buyTrailingLevel = 0;
         }
      }
   }
   // If we have positions and haven't reached max trades, add to same direction
   else if(currentTrades < MaxTrades && !breakevenReached)
   {
      if(!ShouldOpenGridTrade()) {
         return;
      }
      
      if(currentDirection == 1) // BUY direction
      {
         double lotSize = CalculateDynamicLot(currentTrades + 1);
         OpenTrade(ORDER_TYPE_BUY, lotSize, tpPoints, "Grid Buy " + IntegerToString(currentTrades + 1));
      }
      else if(currentDirection == -1) // SELL direction
      {
         double lotSize = CalculateDynamicLot(currentTrades + 1);
         OpenTrade(ORDER_TYPE_SELL, lotSize, tpPoints, "Grid Sell " + IntegerToString(currentTrades + 1));
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
//| 1. CORRECTED: Dynamic Lot Sizing with Risk Management           |
//+------------------------------------------------------------------+
double CalculateDynamicLot(int currentGridLevel)
{
   double baseLot = Lots;
   
   // Use risk-based calculation if enabled
   if(RiskPerTrade > 0 && EmergencySL > 0)
   {
      double balance = AccountInfoDouble(ACCOUNT_BALANCE);
      double riskAmount = balance * (RiskPerTrade / 100.0);
      double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
      double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
      
      if(tickValue > 0 && tickSize > 0)
      {
         double slPoints = EmergencySL * pipSize;
         double slTicks = slPoints / tickSize;
         baseLot = riskAmount / (slTicks * tickValue);
         
         // Normalize lot size
         double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
         baseLot = MathFloor(baseLot / lotStep) * lotStep;
      }
   }
   
   // Apply martingale if enabled
   if(UseMartingale && currentGridLevel > 1)
   {
      double dynamicLot = baseLot * MathPow(Multiplier, currentGridLevel - 1);
      dynamicLot = NormalizeLot(dynamicLot);
      return MathMin(dynamicLot, MaxLotSize);
   }
   
   return NormalizeLot(baseLot);
}

//+------------------------------------------------------------------+
//| Normalize lot size                                              |
//+------------------------------------------------------------------+
double NormalizeLot(double lot)
{
   double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   
   if(lot < minLot) lot = minLot;
   if(lot > maxLot) lot = maxLot;
   
   lot = MathFloor(lot / lotStep) * lotStep;
   
   return lot;
}

//+------------------------------------------------------------------+
//| 2. CORRECTED: Smart Grid Spacing                                |
//+------------------------------------------------------------------+
bool ShouldOpenGridTrade()
{
   if(!UseSmartGrid) return true;
   
   double lastPrice = GetLastTradePrice();
   if(lastPrice == 0) return true;
   
   double currentPrice = (currentDirection == 1) ? SymbolInfoDouble(_Symbol, SYMBOL_BID) : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double spacingPoints = GridSpacing * pipSize;
   
   if(currentDirection == 1) // BUY - price should be lower for averaging down
   {
      return (lastPrice - currentPrice) >= spacingPoints;
   }
   else if(currentDirection == -1) // SELL - price should be higher for averaging down
   {
      return (currentPrice - lastPrice) >= spacingPoints;
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| Get last trade price                                            |
//+------------------------------------------------------------------+
double GetLastTradePrice()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(PositionGetSymbol(i) == _Symbol && PositionGetInteger(POSITION_MAGIC) == MagicNumber)
      {
         return PositionGetDouble(POSITION_PRICE_OPEN);
      }
   }
   return 0;
}

//+------------------------------------------------------------------+
//| 3. CORRECTED: Volatility-Based Protection                       |
//+------------------------------------------------------------------+
bool IsSafeToTrade()
{
   // Check trading hours
   if(!IsTradingTime()) {
      return false;
   }
   
   // Check news avoidance
   if(AvoidNews && IsNewsTime()) {
      return false;
   }
   
   // Check daily drawdown
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   
   if(balance > 0)
   {
      double drawdownPercent = (balance - equity) / balance * 100;
      if(drawdownPercent >= MaxDrawdownPercent) {
         Print("⚠ Max drawdown reached: ", DoubleToString(drawdownPercent, 2), "%");
         return false;
      }
   }
   
   // Check volatility
   if(UseVolatilityFilter && atrHandle != INVALID_HANDLE)
   {
      double atr = GetATRValue();
      double price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      if(atr > 0 && price > 0)
      {
         double atrPercent = (atr / price) * 100;
         if(atrPercent > MaxVolatilityPercent) {
            Print("⚠ High volatility detected: ", DoubleToString(atrPercent, 2), "%");
            return false;
         }
      }
   }
   
   // Check correlation risk
   if(CheckCorrelation && HasCorrelatedRisk()) {
      Print("⚠ Correlated risk detected");
      return false;
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| CORRECTED: Get ATR Value with proper error handling             |
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
//| 4. CORRECTED: Time-Based Filters                                |
//+------------------------------------------------------------------+
bool IsTradingTime()
{
   if(!UseTradingHours) return true;
   
   MqlDateTime timeStruct;
   TimeToStruct(TimeCurrent(), timeStruct);
   
   int currentMinutes = timeStruct.hour * 60 + timeStruct.min;
   
   // Parse start time
   string startParts[];
   StringSplit(StartTime, ':', startParts);
   int startMinutes = (int)StringToInteger(startParts[0]) * 60 + (int)StringToInteger(startParts[1]);
   
   // Parse end time
   string endParts[];
   StringSplit(EndTime, ':', endParts);
   int endMinutes = (int)StringToInteger(endParts[0]) * 60 + (int)StringToInteger(endParts[1]);
   
   return (currentMinutes >= startMinutes && currentMinutes <= endMinutes);
}

//+------------------------------------------------------------------+
//| IMPROVED: News avoidance (simple time-based)                    |
//+------------------------------------------------------------------+
bool IsNewsTime()
{
   if(!AvoidNews) return false;
   
   // Simple implementation: avoid trading during common news hours
   // For full implementation, integrate with economic calendar API
   MqlDateTime timeStruct;
   TimeToStruct(TimeCurrent(), timeStruct);
   
   // Avoid major news times (example: 8:30, 10:00, 14:00 GMT)
   int hour = timeStruct.hour;
   int minute = timeStruct.min;
   
   // Example: Avoid 8:00-9:00, 9:30-10:30, 13:30-14:30 GMT
   if((hour == 8 || hour == 9 || hour == 10 || hour == 13 || hour == 14) &&
      minute >= 0 && minute <= NewsAvoidMinutes)
   {
      return true;
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| 5. CORRECTED: Multi-Timeframe Confirmation                      |
//+------------------------------------------------------------------+
bool HasMTFConfirmation(bool currentBullish, bool currentBearish)
{
   if(!UseMTFConfirmation) return true;
   
   double mtfOpen = iOpen(_Symbol, ConfirmTF, 1);
   double mtfClose = iClose(_Symbol, ConfirmTF, 1);
   
   if(mtfOpen == 0 || mtfClose == 0) return true; // Skip if data unavailable
   
   bool mtfBullish = (mtfClose > mtfOpen);
   bool mtfBearish = (mtfClose < mtfOpen);
   
   // For initial trades (no direction)
   if(currentDirection == 0)
   {
      // If current is bullish, we want to SELL (contrarian), so check if it's safe
      if(currentBullish && mtfBullish) return true; // MTF supports the move
      // If current is bearish, we want to BUY (contrarian), so check if it's safe
      if(currentBearish && mtfBearish) return true; // MTF supports the move
      
      return false; // No confirmation
   }
   
   // For existing positions
   if(currentDirection == 1) return mtfBearish || !mtfBullish; // BUY direction prefers bearish MTF
   if(currentDirection == -1) return mtfBullish || !mtfBearish; // SELL direction prefers bullish MTF
   
   return true;
}

//+------------------------------------------------------------------+
//| 6. CORRECTED: Advanced Risk Management                          |
//+------------------------------------------------------------------+
void CheckEmergencyClose()
{
   if(!UseEquityProtection) return;
   
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   
   // Check equity-based emergency (10% drawdown)
   if(balance > 0 && (equity / balance) < 0.9)
   {
      CloseAllTrades();
      Print("🚨 EMERGENCY: Equity protection activated - 10% drawdown");
      return;
   }
   
   // Check Emergency SL in pips for each position
   if(EmergencySL > 0)
   {
      double emergencyPoints = EmergencySL * pipSize;
      
      for(int i = PositionsTotal() - 1; i >= 0; i--)
      {
         if(PositionGetSymbol(i) == _Symbol && PositionGetInteger(POSITION_MAGIC) == MagicNumber)
         {
            double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
            ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
            double currentPrice;
            
            if(posType == POSITION_TYPE_BUY)
            {
               currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
               if((openPrice - currentPrice) >= emergencyPoints)
               {
                  Print("🚨 EMERGENCY SL hit for BUY - Loss: ", DoubleToString((openPrice - currentPrice) / pipSize, 1), " pips");
                  CloseAllTrades();
                  return;
               }
            }
            else if(posType == POSITION_TYPE_SELL)
            {
               currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
               if((currentPrice - openPrice) >= emergencyPoints)
               {
                  Print("🚨 EMERGENCY SL hit for SELL - Loss: ", DoubleToString((currentPrice - openPrice) / pipSize, 1), " pips");
                  CloseAllTrades();
                  return;
               }
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//| 7. CORRECTED: Improved Trailing Stop Logic                      |
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
      
      if(avgOpenPrice == 0) return;
      
      // Check if we reached breakeven + configured pips
      if(!breakevenReached && currentPrice >= avgOpenPrice + breakevenPoints)
      {
         breakevenReached = true;
         buyTrailingLevel = avgOpenPrice + breakevenPoints;
         Print("✓ Breakeven +", IntegerToString(BreakevenPips), " pips reached for BUY. Grid Level: ", gridLevel);
         Print("  Current Price: ", DoubleToString(currentPrice, _Digits));
         Print("  Trailing Level: ", DoubleToString(buyTrailingLevel, _Digits));
      }
      
      // Update trailing stop if breakeven reached
      if(breakevenReached && buyTrailingLevel > 0)
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
      
      if(avgOpenPrice == 0) return;
      
      // Check if we reached breakeven + configured pips
      if(!breakevenReached && currentPrice <= avgOpenPrice - breakevenPoints)
      {
         breakevenReached = true;
         sellTrailingLevel = avgOpenPrice - breakevenPoints;
         Print("✓ Breakeven +", IntegerToString(BreakevenPips), " pips reached for SELL. Grid Level: ", gridLevel);
         Print("  Current Price: ", DoubleToString(currentPrice, _Digits));
         Print("  Trailing Level: ", DoubleToString(sellTrailingLevel, _Digits));
      }
      
      // Update trailing stop if breakeven reached
      if(breakevenReached && sellTrailingLevel > 0)
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
//| CORRECTED: Dynamic trailing distance                            |
//+------------------------------------------------------------------+
double GetDynamicTrailingDistance()
{
   if(!UseDynamicTrailing) return TrailingStop;
   
   double profitPips = CalculateProfitInPips();
   
   // Dynamic trailing based on profit
   if(profitPips > 300) return 10;
   if(profitPips > 200) return 20;
   if(profitPips > 100) return 30;
   if(profitPips > TrailingStart) return TrailingStop;
   
   return TrailingStop;
}

//+------------------------------------------------------------------+
//| Calculate profit in pips                                        |
//+------------------------------------------------------------------+
double CalculateProfitInPips()
{
   double totalProfit = 0;
   double totalVolume = 0;
   
   for(int i = 0; i < PositionsTotal(); i++)
   {
      if(PositionGetSymbol(i) == _Symbol && PositionGetInteger(POSITION_MAGIC) == MagicNumber)
      {
         double profit = PositionGetDouble(POSITION_PROFIT);
         double volume = PositionGetDouble(POSITION_VOLUME);
         totalProfit += profit;
         totalVolume += volume;
      }
   }
   
   if(totalVolume == 0) return 0;
   
   double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   if(tickValue > 0 && pipSize > 0)
   {
      return totalProfit / (totalVolume * tickValue * (pipSize / SymbolInfoDouble(_Symbol, SYMBOL_POINT)));
   }
   
   return 0;
}

//+------------------------------------------------------------------+
//| 8. CORRECTED: Correlation Protection                            |
//+------------------------------------------------------------------+
bool HasCorrelatedRisk()
{
   if(!CheckCorrelation) return false;
   
   int totalExposure = 0;
   for(int i = 0; i < ArraySize(correlatedPairs); i++)
   {
      totalExposure += CountTradesForSymbol(correlatedPairs[i]);
   }
   
   // Allow some exposure but not excessive
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
      if(PositionGetSymbol(i) == symbol)
         count++;
   }
   return count;
}

//+------------------------------------------------------------------+
//| 9. CORRECTED: Performance Analytics & Dashboard                 |
//+------------------------------------------------------------------+
void UpdateDailyMetrics()
{
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   
   if(balance > dailyMaxBalance) dailyMaxBalance = balance;
   if(equity < dailyMinBalance) dailyMinBalance = equity;
}

//+------------------------------------------------------------------+
//| CORRECTED: Calculate real win rate from history                 |
//+------------------------------------------------------------------+
double CalculateWinRate()
{
   if(dailyStats.totalTrades == 0) return 0;
   return (dailyStats.winningTrades * 100.0 / dailyStats.totalTrades);
}

//+------------------------------------------------------------------+
//| CORRECTED: Calculate real profit factor from history            |
//+------------------------------------------------------------------+
double CalculateProfitFactor()
{
   if(dailyStats.totalLoss == 0) return dailyStats.totalProfit > 0 ? 999 : 0;
   if(dailyStats.totalProfit == 0) return 0;
   
   return MathAbs(dailyStats.totalProfit / dailyStats.totalLoss);
}

//+------------------------------------------------------------------+
//| Calculate drawdown percent                                      |
//+------------------------------------------------------------------+
double CalculateDrawdownPercent()
{
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   
   if(balance > 0)
      return (balance - equity) / balance * 100;
   
   return 0;
}

//+------------------------------------------------------------------+
//| IMPROVED: Dashboard with better formatting                      |
//+------------------------------------------------------------------+
void UpdateDashboard()
{
   double currentPL = CalculateCurrentPL();
   int totalTrades = CountTrades();
   string directionText = "None";
   color directionColor = clrGray;
   
   if(currentDirection == 1)
   {
      directionText = "BUY";
      directionColor = clrLime;
   }
   else if(currentDirection == -1)
   {
      directionText = "SELL";
      directionColor = clrRed;
   }
   
   string breakevenStatus = breakevenReached ? "✓ ACTIVE" : "⧗ +" + IntegerToString(BreakevenPips) + " pips";
   
   double winRate = CalculateWinRate();
   double profitFactor = CalculateProfitFactor();
   double drawdownPercent = CalculateDrawdownPercent();
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   
   string dashboard = "";
   dashboard += "╔══════════════════════════════════════════════╗\n";
   dashboard += "║   ENHANCED GRID CANDLE EA v2.01             ║\n";
   dashboard += "╠══════════════════════════════════════════════╣\n";
   dashboard += "║ Symbol: " + _Symbol + " | Direction: " + directionText + StringFormat("%*s", 20 - StringLen(_Symbol) - StringLen(directionText), "") + "║\n";
   dashboard += "║ Grid Level: " + IntegerToString(gridLevel) + "/" + IntegerToString(MaxTrades) + StringFormat("%*s", 33 - StringLen(IntegerToString(gridLevel)) - StringLen(IntegerToString(MaxTrades)), "") + "║\n";
   dashboard += "║ Breakeven: " + breakevenStatus + StringFormat("%*s", 32 - StringLen(breakevenStatus), "") + "║\n";
   dashboard += "║ Price: " + DoubleToString(SymbolInfoDouble(_Symbol, SYMBOL_BID), _Digits) + StringFormat("%*s", 37 - StringLen(DoubleToString(SymbolInfoDouble(_Symbol, SYMBOL_BID), _Digits)), "") + "║\n";
   dashboard += "╠══════════════════════════════════════════════╣\n";
   dashboard += "║ PERFORMANCE                                  ║\n";
   dashboard += "╠══════════════════════════════════════════════╣\n";
   dashboard += "║ Balance: " + DoubleToString(balance, 2) + " " + AccountInfoString(ACCOUNT_CURRENCY) + StringFormat("%*s", 32 - StringLen(DoubleToString(balance, 2)) - StringLen(AccountInfoString(ACCOUNT_CURRENCY)), "") + "║\n";
   dashboard += "║ Equity: " + DoubleToString(equity, 2) + " " + AccountInfoString(ACCOUNT_CURRENCY) + StringFormat("%*s", 33 - StringLen(DoubleToString(equity, 2)) - StringLen(AccountInfoString(ACCOUNT_CURRENCY)), "") + "║\n";
   dashboard += "║ Daily P/L: " + DoubleToString(currentPL, 2) + " " + AccountInfoString(ACCOUNT_CURRENCY) + StringFormat("%*s", 30 - StringLen(DoubleToString(currentPL, 2)) - StringLen(AccountInfoString(ACCOUNT_CURRENCY)), "") + "║\n";
   dashboard += "║ Drawdown: " + DoubleToString(drawdownPercent, 1) + "%" + StringFormat("%*s", 32 - StringLen(DoubleToString(drawdownPercent, 1)), "") + "║\n";
   dashboard += "║ Active Trades: " + IntegerToString(totalTrades) + StringFormat("%*s", 29 - StringLen(IntegerToString(totalTrades)), "") + "║\n";
   dashboard += "║ Trades Today: " + IntegerToString(dailyStats.totalTrades) + StringFormat("%*s", 30 - StringLen(IntegerToString(dailyStats.totalTrades)), "") + "║\n";
   dashboard += "╠══════════════════════════════════════════════╣\n";
   dashboard += "║ ANALYTICS                                    ║\n";
   dashboard += "╠══════════════════════════════════════════════╣\n";
   dashboard += "║ Win Rate: " + DoubleToString(winRate, 1) + "%" + StringFormat("%*s", 32 - StringLen(DoubleToString(winRate, 1)), "") + "║\n";
   dashboard += "║ Profit Factor: " + DoubleToString(profitFactor, 2) + StringFormat("%*s", 29 - StringLen(DoubleToString(profitFactor, 2)), "") + "║\n";
   dashboard += "║ Winners: " + IntegerToString(dailyStats.winningTrades) + " | Losers: " + IntegerToString(dailyStats.losingTrades) + StringFormat("%*s", 25 - StringLen(IntegerToString(dailyStats.winningTrades)) - StringLen(IntegerToString(dailyStats.losingTrades)), "") + "║\n";
   dashboard += "╠══════════════════════════════════════════════╣\n";
   dashboard += "║ PROTECTION STATUS                            ║\n";
   dashboard += "╠══════════════════════════════════════════════╣\n";
   dashboard += "║ Volatility Filter: " + string(UseVolatilityFilter ? "✓ ON " : "✗ OFF") + StringFormat("%*s", 23, "") + "║\n";
   dashboard += "║ Equity Protection: " + string(UseEquityProtection ? "✓ ON " : "✗ OFF") + StringFormat("%*s", 23, "") + "║\n";
   dashboard += "║ MTF Confirmation: " + string(UseMTFConfirmation ? "✓ ON " : "✗ OFF") + StringFormat("%*s", 24, "") + "║\n";
   dashboard += "║ Smart Grid: " + string(UseSmartGrid ? "✓ ON " : "✗ OFF") + StringFormat("%*s", 30, "") + "║\n";
   dashboard += "╠══════════════════════════════════════════════╣\n";
   dashboard += "║ TRAILING STOPS                               ║\n";
   dashboard += "╠══════════════════════════════════════════════╣\n";
   
   if(buyTrailingLevel > 0)
      dashboard += "║ BUY: " + DoubleToString(buyTrailingLevel, _Digits) + StringFormat("%*s", 39 - StringLen(DoubleToString(buyTrailingLevel, _Digits)), "") + "║\n";
   else
      dashboard += "║ BUY: Not Active" + StringFormat("%*s", 29, "") + "║\n";
   
   if(sellTrailingLevel > 0)
      dashboard += "║ SELL: " + DoubleToString(sellTrailingLevel, _Digits) + StringFormat("%*s", 38 - StringLen(DoubleToString(sellTrailingLevel, _Digits)), "") + "║\n";
   else
      dashboard += "║ SELL: Not Active" + StringFormat("%*s", 28, "") + "║\n";
   
   dashboard += "╚══════════════════════════════════════════════╝";
   
   Comment(dashboard);
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
      if(PositionGetSymbol(i) == _Symbol && PositionGetInteger(POSITION_MAGIC) == MagicNumber)
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
//| CORRECTED: Calculate TP                                         |
//+------------------------------------------------------------------+
double CalculateTP()
{
   if(UseATR && atrHandle != INVALID_HANDLE)
   {
      double atrValue = GetATRValue();
      if(atrValue > 0)
      {
         // ATR is already in price units, multiply by 3 for TP distance
         return atrValue * 3;
      }
   }
   
   // Default: use fixed TP in pips
   return TakeProfit * pipSize;
}

//+------------------------------------------------------------------+
//| IMPROVED: Open trade with better error handling                 |
//+------------------------------------------------------------------+
bool OpenTrade(ENUM_ORDER_TYPE orderType, double volume, double tpPoints, string comment)
{
   double price = 0;
   double tp = 0;
   double sl = 0;
   
   // Normalize volume
   volume = NormalizeLot(volume);
   
   MqlTradeRequest request;
   MqlTradeResult result;
   ZeroMemory(request);
   ZeroMemory(result);
   
   if(orderType == ORDER_TYPE_BUY)
   {
      price = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      tp = (tpPoints > 0) ? NormalizeDouble(price + tpPoints, _Digits) : 0;
      sl = (EmergencySL > 0) ? NormalizeDouble(price - (EmergencySL * pipSize), _Digits) : 0;
   }
   else if(orderType == ORDER_TYPE_SELL)
   {
      price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      tp = (tpPoints > 0) ? NormalizeDouble(price - tpPoints, _Digits) : 0;
      sl = (EmergencySL > 0) ? NormalizeDouble(price + (EmergencySL * pipSize), _Digits) : 0;
   }
   
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
   
   // Try alternative filling if FOK fails
   if(!OrderSend(request, result))
   {
      request.type_filling = ORDER_FILLING_IOC;
      if(!OrderSend(request, result))
      {
         request.type_filling = ORDER_FILLING_RETURN;
         OrderSend(request, result);
      }
   }
   
   if(result.retcode == TRADE_RETCODE_DONE || result.retcode == TRADE_RETCODE_PLACED)
   {
      Print("✓ Trade opened: ", comment);
      Print("  Type: ", EnumToString(orderType));
      Print("  Lot: ", DoubleToString(volume, 2));
      Print("  Price: ", DoubleToString(price, _Digits));
      Print("  TP: ", DoubleToString(tp, _Digits));
      if(sl > 0) Print("  SL: ", DoubleToString(sl, _Digits));
      Print("  Ticket: ", result.order);
      
      tradeCountToday++;
      dailyStats.totalTrades++;
      
      return true;
   }
   else
   {
      Print("✗ Error opening trade: ", result.retcode, " - ", comment);
      Print("  Error description: ", GetRetcodeDescription(result.retcode));
      return false;
   }
}

//+------------------------------------------------------------------+
//| Get retcode description                                         |
//+------------------------------------------------------------------+
string GetRetcodeDescription(uint retcode)
{
   switch(retcode)
   {
      case TRADE_RETCODE_REQUOTE: return "Requote";
      case TRADE_RETCODE_REJECT: return "Request rejected";
      case TRADE_RETCODE_CANCEL: return "Request canceled";
      case TRADE_RETCODE_PLACED: return "Order placed";
      case TRADE_RETCODE_DONE: return "Done";
      case TRADE_RETCODE_DONE_PARTIAL: return "Done partially";
      case TRADE_RETCODE_ERROR: return "Common error";
      case TRADE_RETCODE_TIMEOUT: return "Timeout";
      case TRADE_RETCODE_INVALID: return "Invalid request";
      case TRADE_RETCODE_INVALID_VOLUME: return "Invalid volume";
      case TRADE_RETCODE_INVALID_PRICE: return "Invalid price";
      case TRADE_RETCODE_INVALID_STOPS: return "Invalid stops";
      case TRADE_RETCODE_TRADE_DISABLED: return "Trade disabled";
      case TRADE_RETCODE_MARKET_CLOSED: return "Market closed";
      case TRADE_RETCODE_NO_MONEY: return "No money";
      case TRADE_RETCODE_PRICE_CHANGED: return "Price changed";
      case TRADE_RETCODE_PRICE_OFF: return "Price off";
      case TRADE_RETCODE_INVALID_EXPIRATION: return "Invalid expiration";
      case TRADE_RETCODE_ORDER_CHANGED: return "Order changed";
      case TRADE_RETCODE_TOO_MANY_REQUESTS: return "Too many requests";
      case TRADE_RETCODE_NO_CHANGES: return "No changes";
      case TRADE_RETCODE_SERVER_DISABLES_AT: return "Autotrading disabled by server";
      case TRADE_RETCODE_CLIENT_DISABLES_AT: return "Autotrading disabled by client";
      case TRADE_RETCODE_LOCKED: return "Locked";
      case TRADE_RETCODE_FROZEN: return "Frozen";
      case TRADE_RETCODE_INVALID_FILL: return "Invalid fill";
      default: return "Unknown error";
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
      if(PositionGetSymbol(i) == _Symbol && PositionGetInteger(POSITION_MAGIC) == MagicNumber)
         count++;
   }
   return count;
}

//+------------------------------------------------------------------+
//| Count buy trades                                                |
//+------------------------------------------------------------------+
int CountBuyTrades()
{
   int count = 0;
   for(int i = 0; i < PositionsTotal(); i++)
   {
      if(PositionGetSymbol(i) == _Symbol && PositionGetInteger(POSITION_MAGIC) == MagicNumber)
      {
         if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
            count++;
      }
   }
   return count;
}

//+------------------------------------------------------------------+
//| Count sell trades                                               |
//+------------------------------------------------------------------+
int CountSellTrades()
{
   int count = 0;
   for(int i = 0; i < PositionsTotal(); i++)
   {
      if(PositionGetSymbol(i) == _Symbol && PositionGetInteger(POSITION_MAGIC) == MagicNumber)
      {
         if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL)
            count++;
      }
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
      if(PositionGetSymbol(i) == _Symbol && PositionGetInteger(POSITION_MAGIC) == MagicNumber)
         pl += PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);
   }
   return pl;
}

//+------------------------------------------------------------------+
//| CORRECTED: Get average buy price                                |
//+------------------------------------------------------------------+
double GetAverageBuyPrice()
{
   double totalVolume = 0;
   double totalValue = 0;
   
   for(int i = 0; i < PositionsTotal(); i++)
   {
      if(PositionGetSymbol(i) == _Symbol && PositionGetInteger(POSITION_MAGIC) == MagicNumber)
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

//+------------------------------------------------------------------+
//| CORRECTED: Get average sell price                               |
//+------------------------------------------------------------------+
double GetAverageSellPrice()
{
   double totalVolume = 0;
   double totalValue = 0;
   
   for(int i = 0; i < PositionsTotal(); i++)
   {
      if(PositionGetSymbol(i) == _Symbol && PositionGetInteger(POSITION_MAGIC) == MagicNumber)
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
         double profit = CalculateCurrentPL();
         Print("═══════════════════════════════════════");
         Print("✓ BUY Trailing Stop Hit");
         Print("  Current Price: ", DoubleToString(currentPrice, _Digits));
         Print("  Trailing Level: ", DoubleToString(buyTrailingLevel, _Digits));
         Print("  Profit: ", DoubleToString(profit, 2), " ", AccountInfoString(ACCOUNT_CURRENCY));
         Print("═══════════════════════════════════════");
         
         CloseAllBuyTrades();
         
         // Update stats
         if(profit > 0)
         {
            dailyStats.winningTrades++;
            dailyStats.totalProfit += profit;
         }
         else
         {
            dailyStats.losingTrades++;
            dailyStats.totalLoss += MathAbs(profit);
         }
         
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
         double profit = CalculateCurrentPL();
         Print("═══════════════════════════════════════");
         Print("✓ SELL Trailing Stop Hit");
         Print("  Current Price: ", DoubleToString(currentPrice, _Digits));
         Print("  Trailing Level: ", DoubleToString(sellTrailingLevel, _Digits));
         Print("  Profit: ", DoubleToString(profit, 2), " ", AccountInfoString(ACCOUNT_CURRENCY));
         Print("═══════════════════════════════════════");
         
         CloseAllSellTrades();
         
         // Update stats
         if(profit > 0)
         {
            dailyStats.winningTrades++;
            dailyStats.totalProfit += profit;
         }
         else
         {
            dailyStats.losingTrades++;
            dailyStats.totalLoss += MathAbs(profit);
         }
         
         sellTrailingLevel = 0;
         currentDirection = 0;
         breakevenReached = false;
         gridLevel = 0;
      }
   }
}

//+------------------------------------------------------------------+
//| Close all buy trades                                            |
//+------------------------------------------------------------------+
void CloseAllBuyTrades()
{
   int closed = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(PositionGetSymbol(i) == _Symbol && PositionGetInteger(POSITION_MAGIC) == MagicNumber)
      {
         if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
         {
            if(ClosePosition(i))
               closed++;
         }
      }
   }
   Print("Closed ", closed, " BUY position(s)");
}

//+------------------------------------------------------------------+
//| Close all sell trades                                           |
//+------------------------------------------------------------------+
void CloseAllSellTrades()
{
   int closed = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(PositionGetSymbol(i) == _Symbol && PositionGetInteger(POSITION_MAGIC) == MagicNumber)
      {
         if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL)
         {
            if(ClosePosition(i))
               closed++;
         }
      }
   }
   Print("Closed ", closed, " SELL position(s)");
}

//+------------------------------------------------------------------+
//| Close all trades                                                |
//+------------------------------------------------------------------+
void CloseAllTrades()
{
   int closed = 0;
   double totalProfit = CalculateCurrentPL();
   
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(PositionGetSymbol(i) == _Symbol && PositionGetInteger(POSITION_MAGIC) == MagicNumber)
      {
         if(ClosePosition(i))
            closed++;
      }
   }
   
   Print("Emergency close: ", closed, " position(s) closed. P/L: ", DoubleToString(totalProfit, 2));
   
   // Update stats
   if(totalProfit > 0)
   {
      dailyStats.winningTrades++;
      dailyStats.totalProfit += totalProfit;
   }
   else if(totalProfit < 0)
   {
      dailyStats.losingTrades++;
      dailyStats.totalLoss += MathAbs(totalProfit);
   }
}

//+------------------------------------------------------------------+
//| IMPROVED: Close position with better error handling             |
//+------------------------------------------------------------------+
bool ClosePosition(int positionIndex)
{
   if(PositionGetSymbol(positionIndex) != _Symbol) return false;
   
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
   
   // Try alternative filling if FOK fails
   if(!OrderSend(request, result))
   {
      request.type_filling = ORDER_FILLING_IOC;
      if(!OrderSend(request, result))
      {
         request.type_filling = ORDER_FILLING_RETURN;
         OrderSend(request, result);
      }
   }
   
   if(result.retcode == TRADE_RETCODE_DONE)
   {
      return true;
   }
   else
   {
      Print("Error closing position ", ticket, ": ", result.retcode, " - ", GetRetcodeDescription(result.retcode));
      return false;
   }
}

//+------------------------------------------------------------------+
//| OnTrade event - Track closed positions                          |
//+------------------------------------------------------------------+
void OnTrade()
{
   UpdateDashboard();
}

//+------------------------------------------------------------------+
//| OnTradeTransaction - Enhanced trade tracking                    |
//+------------------------------------------------------------------+
void OnTradeTransaction(const MqlTradeTransaction& trans,
                        const MqlTradeRequest& request,
                        const MqlTradeResult& result)
{
   // Track when positions are closed
   if(trans.type == TRADE_TRANSACTION_DEAL_ADD)
   {
      if(HistoryDealSelect(trans.deal))
      {
         if(HistoryDealGetInteger(trans.deal, DEAL_MAGIC) == MagicNumber)
         {
            ENUM_DEAL_ENTRY entry = (ENUM_DEAL_ENTRY)HistoryDealGetInteger(trans.deal, DEAL_ENTRY);
            if(entry == DEAL_ENTRY_OUT)
            {
               double profit = HistoryDealGetDouble(trans.deal, DEAL_PROFIT);
               double swap = HistoryDealGetDouble(trans.deal, DEAL_SWAP);
               double commission = HistoryDealGetDouble(trans.deal, DEAL_COMMISSION);
               double totalProfit = profit + swap + commission;
               
               // This is a position close - stats already updated in close functions
               // Just update dashboard
               UpdateDashboard();
            }
         }
      }
   }
}
//+------------------------------------------------------------------+