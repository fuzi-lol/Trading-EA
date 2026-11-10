//+------------------------------------------------------------------+
//| EnhancedGridCandleEA_v3.mq5                                     |
//| Revised: real stop losses, structure/trend/momentum entry       |
//| filter, confirmed grid-adds, real performance stats.            |
//|                                                                   |
//| IMPORTANT: No EA can guarantee a positive P/L. This version      |
//| fixes concrete bugs (no stop loss, blind martingale adds, fake   |
//| stats) and replaces the noise-based entry with a confirmed,      |
//| structure-based one. Backtest and forward-test on a demo before  |
//| risking real funds, and treat every input below as something to  |
//| tune against your own data, not a guaranteed setting.            |
//+------------------------------------------------------------------+
#property copyright "Revised 2026"
#property version   "3.00"

//--- Core
input double   Lots              = 0.1;       // Base trade volume
input int      TakeProfit        = 300;       // Take Profit in pips (used if UseATR = false)
input int      BreakevenPips     = 50;        // Breakeven level in pips
input int      TrailingStop      = 50;        // Trailing Stop in pips
input int      MaxTrades         = 5;         // Maximum trades per basket (was 10 — lowered, no-SL martingale to 10 legs is how accounts blow up)
input bool     UseATR            = true;      // Use ATR for TP/SL sizing
input int      ATR_Period        = 14;

//--- NEW: Stop loss is now mandatory. No trade is ever sent with sl = 0.
input double   ATR_SL_Multiplier = 1.5;       // SL = ATR * this (used if UseATR = true)
input int      FixedStopLossPips = 150;       // SL in pips (used if UseATR = false)

//--- Dynamic Lot Sizing
input bool     UseMartingale     = false;     // Off by default — combine with no-SL history at your own risk
input double   Multiplier        = 1.5;       // Lower than before (was 2.0) to slow exposure growth
input double   MaxLotSize        = 0.5;
input double   RiskPerTrade      = 1.0;

//--- Smart Grid
input int      GridSpacing       = 50;        // Pips between grid levels
input bool     UseSmartGrid      = true;
input bool     RequireConfirmationOnGridAdd = true; // NEW: grid adds must pass GetSignal() again, not just "new candle"

//--- Risk Management
input double   MaxDrawdownPercent  = 5.0;     // Tightened from 10.0
input bool     UseVolatilityFilter = true;
input bool     UseEquityProtection = true;
input double   MaxSpreadPips       = 30;      // NEW: skip entries when spread is wide (common scalping account-killer on gold)

//--- Advanced Trailing
input bool     UseDynamicTrailing = true;
input int      TrailingStart      = 20;
input int      TrailingStep       = 10;

//--- Time & Session Filters
input bool     UseTradingHours  = true;
input string   StartTime        = "07:00";    // Narrowed toward higher-liquidity London/NY overlap by default for XAUUSD
input string   EndTime          = "17:00";
input bool     AvoidNews        = true;

//--- Entry Filter Stack (replaces "previous candle color" logic)
input bool     UseTrendFilter     = true;     // EMA trend alignment
input int      EMA_Period         = 50;
input bool     UseMomentumFilter  = true;     // RSI confirmation
input int      RSI_Period         = 14;
input double   RSI_Buy_Level      = 50;       // RSI must be above this for BUY
input double   RSI_Sell_Level     = 50;       // RSI must be below this for SELL
input bool     UseStructureBreak  = true;     // Entry only on break of recent swing high/low
input int      StructureLookback  = 20;       // Bars used to define the swing high/low

//--- Multi-Timeframe
input bool     UseMTFConfirmation = true;
input ENUM_TIMEFRAMES ConfirmTF   = PERIOD_H1;

//--- Correlation Protection
input bool     CheckCorrelation = true;

//--- Global variables
double pipSize;
datetime lastBarTime;
int tradeCountToday;
int atrHandle, emaHandle, rsiHandle;
int currentDirection = 0;
double buyTrailingLevel = 0;
double sellTrailingLevel = 0;
bool breakevenReached = false;
int gridLevel = 0;
double dailyMaxBalance = 0;
double dailyMinBalance = 0;
string correlatedPairs[3] = {"EURUSD", "GBPUSD", "USDCHF"};
ulong lastKnownDealTicket = 0;

//+------------------------------------------------------------------+
int OnInit()
{
   if(SymbolInfoInteger(_Symbol, SYMBOL_DIGITS) == 3 || SymbolInfoInteger(_Symbol, SYMBOL_DIGITS) == 5)
      pipSize = SymbolInfoDouble(_Symbol, SYMBOL_POINT) * 10;
   else
      pipSize = SymbolInfoDouble(_Symbol, SYMBOL_POINT);

   lastBarTime = 0;
   tradeCountToday = 0;
   currentDirection = 0;
   buyTrailingLevel = 0;
   sellTrailingLevel = 0;
   breakevenReached = false;
   gridLevel = 0;
   dailyMaxBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   dailyMinBalance = AccountInfoDouble(ACCOUNT_BALANCE);

   atrHandle = iATR(_Symbol, PERIOD_CURRENT, ATR_Period);
   emaHandle = iMA(_Symbol, PERIOD_CURRENT, EMA_Period, 0, MODE_EMA, PRICE_CLOSE);
   rsiHandle = iRSI(_Symbol, PERIOD_CURRENT, RSI_Period, PRICE_CLOSE);

   if(atrHandle == INVALID_HANDLE || emaHandle == INVALID_HANDLE || rsiHandle == INVALID_HANDLE)
   {
      Print("Failed to create indicator handle(s). EA will not trade.");
      return(INIT_FAILED);
   }

   EventSetTimer(1);
   Print("EnhancedGridCandleEA v3 started. Every trade will carry a real stop loss.");
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   if(atrHandle != INVALID_HANDLE) IndicatorRelease(atrHandle);
   if(emaHandle != INVALID_HANDLE) IndicatorRelease(emaHandle);
   if(rsiHandle != INVALID_HANDLE) IndicatorRelease(rsiHandle);
   EventKillTimer();
   Print("EnhancedGridCandleEA v3 stopped.");
}

//+------------------------------------------------------------------+
void OnTick()
{
   CheckForNewCandle();
   UpdateGlobalTrailingStops();
   CheckTrailingStopHit();
   CheckEmergencyClose();
   UpdateDashboard();
}

void OnTimer()
{
   UpdateDailyMetrics();
   UpdateDashboard();
}

//+------------------------------------------------------------------+
//| Entry signal: trend + momentum + structure break, all must      |
//| agree. This replaces "was last candle green/red" with a signal  |
//| that only fires when several independent conditions line up.    |
//+------------------------------------------------------------------+
bool GetSignal(int &direction)
{
   direction = 0;

   // Spread filter — wide spread quietly eats scalping edge
   double spreadPips = (SymbolInfoDouble(_Symbol, SYMBOL_ASK) - SymbolInfoDouble(_Symbol, SYMBOL_BID)) / pipSize;
   if(spreadPips > MaxSpreadPips)
   {
      Print("Spread too wide (", DoubleToString(spreadPips,1), " pips) - skipping");
      return false;
   }

   double emaBuf[], rsiBuf[];
   ArraySetAsSeries(emaBuf, true);
   ArraySetAsSeries(rsiBuf, true);
   if(CopyBuffer(emaHandle, 0, 1, 1, emaBuf) <= 0) return false;
   if(CopyBuffer(rsiHandle, 0, 1, 1, rsiBuf) <= 0) return false;

   double closedPrice = iClose(_Symbol, PERIOD_CURRENT, 1);
   double ema = emaBuf[0];
   double rsi = rsiBuf[0];

   bool trendBuy  = !UseTrendFilter || (closedPrice > ema);
   bool trendSell = !UseTrendFilter || (closedPrice < ema);

   bool momentumBuy  = !UseMomentumFilter || (rsi > RSI_Buy_Level && rsi < 75);
   bool momentumSell = !UseMomentumFilter || (rsi < RSI_Sell_Level && rsi > 25);

   bool structBuy = true, structSell = true;
   if(UseStructureBreak)
   {
      double recentHigh = -DBL_MAX, recentLow = DBL_MAX;
      for(int i = 2; i <= StructureLookback + 1; i++)
      {
         double h = iHigh(_Symbol, PERIOD_CURRENT, i);
         double l = iLow(_Symbol, PERIOD_CURRENT, i);
         if(h > recentHigh) recentHigh = h;
         if(l < recentLow)  recentLow  = l;
      }
      structBuy  = (closedPrice > recentHigh);
      structSell = (closedPrice < recentLow);
   }

   bool buySignal  = trendBuy  && momentumBuy  && structBuy;
   bool sellSignal = trendSell && momentumSell && structSell;

   if(buySignal && !sellSignal) { direction = 1; return true; }
   if(sellSignal && !buySignal) { direction = -1; return true; }
   return false;
}

//+------------------------------------------------------------------+
void CheckForNewCandle()
{
   datetime currentBarTime = iTime(_Symbol, PERIOD_CURRENT, 0);
   if(currentBarTime == lastBarTime) return;
   lastBarTime = currentBarTime;

   if(!IsSafeToTrade())
   {
      Print("Trade blocked by safety conditions");
      return;
   }

   int signalDirection;
   bool haveSignal = GetSignal(signalDirection);

   double tpPoints, slPoints;
   CalculateTP(tpPoints);
   CalculateSL(slPoints);

   DetermineCurrentDirection();
   int currentTrades = CountTrades();

   if(currentTrades == 0)
   {
      if(!haveSignal)
      {
         Print("No confirmed entry signal - waiting");
         return;
      }
      if(!HasMTFConfirmation(signalDirection))
      {
         Print("No MTF confirmation - skipping trade");
         return;
      }

      breakevenReached = false;
      gridLevel = 0;

      if(signalDirection == 1)
      {
         double lotSize = CalculateDynamicLot(1);
         OpenTrade(ORDER_TYPE_BUY, lotSize, tpPoints, slPoints, "Initial Buy");
         currentDirection = 1;
         buyTrailingLevel = 0;
         gridLevel = 1;
      }
      else if(signalDirection == -1)
      {
         double lotSize = CalculateDynamicLot(1);
         OpenTrade(ORDER_TYPE_SELL, lotSize, tpPoints, slPoints, "Initial Sell");
         currentDirection = -1;
         sellTrailingLevel = 0;
         gridLevel = 1;
      }
   }
   else if(currentTrades < MaxTrades && !breakevenReached)
   {
      if(!ShouldOpenGridTrade())
      {
         Print("Grid spacing condition not met - skipping grid trade");
         return;
      }

      // Grid adds now require the SAME fresh confirmation as a new trade,
      // instead of blindly averaging into the basket every candle.
      if(RequireConfirmationOnGridAdd)
      {
         if(!haveSignal || signalDirection != currentDirection)
         {
            Print("Grid add skipped - fresh signal no longer confirms current direction");
            return;
         }
      }

      if(currentDirection == 1)
      {
         double lotSize = CalculateDynamicLot(gridLevel + 1);
         OpenTrade(ORDER_TYPE_BUY, lotSize, tpPoints, slPoints, "Grid Buy " + IntegerToString(currentTrades + 1));
         gridLevel++;
      }
      else if(currentDirection == -1)
      {
         double lotSize = CalculateDynamicLot(gridLevel + 1);
         OpenTrade(ORDER_TYPE_SELL, lotSize, tpPoints, slPoints, "Grid Sell " + IntegerToString(currentTrades + 1));
         gridLevel++;
      }
   }
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
double CalculateDynamicLot(int currentGridLevel)
{
   if(UseMartingale)
   {
      double dynamicLot = Lots * MathPow(Multiplier, currentGridLevel - 1);
      return MathMin(dynamicLot, MaxLotSize);
   }
   return Lots;
}

//+------------------------------------------------------------------+
bool ShouldOpenGridTrade()
{
   if(!UseSmartGrid) return true;
   double lastPrice = GetLastTradePrice();
   double currentPrice = (currentDirection == 1) ? SymbolInfoDouble(_Symbol, SYMBOL_BID) : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double spacingPoints = GridSpacing * pipSize;

   if(currentDirection == 1)
      return (lastPrice - currentPrice) >= spacingPoints;
   else
      return (currentPrice - lastPrice) >= spacingPoints;
}

double GetLastTradePrice()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(PositionGetSymbol(i) == _Symbol && PositionGetInteger(POSITION_MAGIC) == 12345)
         return PositionGetDouble(POSITION_PRICE_OPEN);
   }
   return 0;
}

//+------------------------------------------------------------------+
bool IsSafeToTrade()
{
   if(!IsTradingTime())
   {
      Print("Outside trading hours");
      return false;
   }

   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double drawdownPercent = (balance - equity) / balance * 100;
   if(drawdownPercent >= MaxDrawdownPercent)
   {
      Print("Max drawdown reached: ", DoubleToString(drawdownPercent, 1), "%");
      return false;
   }

   if(UseVolatilityFilter)
   {
      double atr = GetATRValue();
      double atrPercent = (atr / SymbolInfoDouble(_Symbol, SYMBOL_BID)) * 100;
      if(atrPercent > 2.0)
      {
         Print("High volatility detected: ", DoubleToString(atrPercent, 1), "%");
         return false;
      }
   }

   if(CheckCorrelation && HasCorrelatedRisk())
   {
      Print("Correlated risk detected");
      return false;
   }

   return true;
}

double GetATRValue()
{
   double atrBuffer[];
   ArraySetAsSeries(atrBuffer, true);
   if(CopyBuffer(atrHandle, 0, 0, 1, atrBuffer) > 0)
      return atrBuffer[0];
   return 0;
}

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
bool HasMTFConfirmation(int direction)
{
   if(!UseMTFConfirmation) return true;
   double mtfOpen = iOpen(_Symbol, ConfirmTF, 1);
   double mtfClose = iClose(_Symbol, ConfirmTF, 1);
   if(direction == 1) return mtfClose > mtfOpen;
   if(direction == -1) return mtfClose < mtfOpen;
   return true;
}

//+------------------------------------------------------------------+
void CheckEmergencyClose()
{
   if(!UseEquityProtection) return;
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   if((equity / balance) < 0.9)
   {
      CloseAllTrades();
      Print("Emergency close activated due to 10% equity drawdown");
   }
}

//+------------------------------------------------------------------+
void UpdateGlobalTrailingStops()
{
   double trailingPoints = GetDynamicTrailingDistance() * pipSize;
   double breakevenPoints = BreakevenPips * pipSize;
   double currentPrice;

   if(currentDirection == 1 && CountBuyTrades() > 0)
   {
      currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      double bestPrice = GetBestBuyPrice();
      double avgOpenPrice = GetAverageBuyPrice();

      if(!breakevenReached && currentPrice >= avgOpenPrice + breakevenPoints)
      {
         breakevenReached = true;
         Print("Breakeven +", IntegerToString(BreakevenPips), " pips reached. Grid Level: ", gridLevel);
      }

      if(breakevenReached)
      {
         if(buyTrailingLevel == 0)
            buyTrailingLevel = avgOpenPrice + breakevenPoints;
         else
         {
            double newTrailingLevel = bestPrice - trailingPoints;
            if(newTrailingLevel > buyTrailingLevel) buyTrailingLevel = newTrailingLevel;
         }
      }
   }

   if(currentDirection == -1 && CountSellTrades() > 0)
   {
      currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      double bestPrice = GetBestSellPrice();
      double avgOpenPrice = GetAverageSellPrice();

      if(!breakevenReached && currentPrice <= avgOpenPrice - breakevenPoints)
      {
         breakevenReached = true;
         Print("Breakeven +", IntegerToString(BreakevenPips), " pips reached. Grid Level: ", gridLevel);
      }

      if(breakevenReached)
      {
         if(sellTrailingLevel == 0)
            sellTrailingLevel = avgOpenPrice - breakevenPoints;
         else
         {
            double newTrailingLevel = bestPrice + trailingPoints;
            if(newTrailingLevel < sellTrailingLevel) sellTrailingLevel = newTrailingLevel;
         }
      }
   }
}

double GetDynamicTrailingDistance()
{
   if(!UseDynamicTrailing) return TrailingStop;
   double profitPips = CalculateProfitInPips();
   if(profitPips < TrailingStart) return TrailingStop;
   if(profitPips > 300) return 10;
   if(profitPips > 200) return 20;
   if(profitPips > 100) return 30;
   return TrailingStop;
}

double CalculateProfitInPips()
{
   double profit = CalculateCurrentPL();
   double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double totalVolume = 0;
   for(int i = 0; i < PositionsTotal(); i++)
      if(PositionGetSymbol(i) == _Symbol && PositionGetInteger(POSITION_MAGIC) == 12345)
         totalVolume += PositionGetDouble(POSITION_VOLUME);
   if(tickValue > 0 && totalVolume > 0 && pipSize > 0)
      return MathAbs(profit / (totalVolume * tickValue * pipSize));
   return 0;
}

//+------------------------------------------------------------------+
bool HasCorrelatedRisk()
{
   if(!CheckCorrelation) return false;
   int totalExposure = 0;
   for(int i = 0; i < ArraySize(correlatedPairs); i++)
      totalExposure += CountTradesForSymbol(correlatedPairs[i]);
   return (totalExposure >= MaxTrades * 2);
}

int CountTradesForSymbol(string symbol)
{
   int count = 0;
   for(int i = 0; i < PositionsTotal(); i++)
      if(PositionGetSymbol(i) == symbol) count++;
   return count;
}

//+------------------------------------------------------------------+
//| Real performance stats, pulled from actual closed-deal history   |
//| instead of hardcoded placeholders.                                |
//+------------------------------------------------------------------+
void CalculateRealStats(double &winRate, double &profitFactor, int &totalClosedTrades)
{
   winRate = 0; profitFactor = 0; totalClosedTrades = 0;
   double grossProfit = 0, grossLoss = 0;
   int wins = 0;

   datetime dayStart = iTime(_Symbol, PERIOD_D1, 0);
   if(!HistorySelect(dayStart, TimeCurrent())) return;

   int total = HistoryDealsTotal();
   for(int i = 0; i < total; i++)
   {
      ulong ticket = HistoryDealGetTicket(i);
      if(ticket == 0) continue;
      if(HistoryDealGetInteger(ticket, DEAL_MAGIC) != 12345) continue;
      if(HistoryDealGetString(ticket, DEAL_SYMBOL) != _Symbol) continue;
      if(HistoryDealGetInteger(ticket, DEAL_ENTRY) != DEAL_ENTRY_OUT) continue;

      double dealProfit = HistoryDealGetDouble(ticket, DEAL_PROFIT) + HistoryDealGetDouble(ticket, DEAL_SWAP) + HistoryDealGetDouble(ticket, DEAL_COMMISSION);
      totalClosedTrades++;
      if(dealProfit >= 0) { wins++; grossProfit += dealProfit; }
      else grossLoss += MathAbs(dealProfit);
   }

   if(totalClosedTrades > 0) winRate = (wins * 100.0) / totalClosedTrades;
   profitFactor = (grossLoss > 0) ? (grossProfit / grossLoss) : (grossProfit > 0 ? 999 : 0);
}

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

   double winRate, profitFactor; int closedTrades;
   CalculateRealStats(winRate, profitFactor, closedTrades);
   double drawdownPercent = CalculateDrawdownPercent();

   string dashboard = "";
   dashboard += "=== ENHANCED GRID CANDLE EA v3 ===\n";
   dashboard += "Symbol: " + _Symbol + " | Direction: " + directionText + "\n";
   dashboard += "Grid Level: " + IntegerToString(gridLevel) + "/" + IntegerToString(MaxTrades) + "\n";
   dashboard += "Breakeven Status: " + breakevenStatus + "\n";
   dashboard += "Current Price: " + DoubleToString(SymbolInfoDouble(_Symbol, SYMBOL_BID), _Digits) + "\n";
   dashboard += "--- Performance (real, from closed deals today) ---\n";
   dashboard += "Daily P/L: " + DoubleToString(currentPL, 2) + " " + AccountInfoString(ACCOUNT_CURRENCY) + " (open positions)\n";
   dashboard += "Closed Trades Today: " + IntegerToString(closedTrades) + "\n";
   dashboard += "Win Rate: " + DoubleToString(winRate, 1) + "%\n";
   dashboard += "Profit Factor: " + DoubleToString(profitFactor, 2) + "\n";
   dashboard += "Active Trades: " + IntegerToString(totalTrades) + "\n";
   dashboard += "Drawdown: " + DoubleToString(drawdownPercent, 1) + "%\n";
   dashboard += "--- Protection ---\n";
   dashboard += "Volatility Filter: " + string(UseVolatilityFilter ? "ON" : "OFF") + "\n";
   dashboard += "Equity Protection: " + string(UseEquityProtection ? "ON" : "OFF") + "\n";
   dashboard += "MTF Confirm: " + string(UseMTFConfirmation ? "ON" : "OFF") + "\n";
   dashboard += "Grid Adds Require Fresh Signal: " + string(RequireConfirmationOnGridAdd ? "ON" : "OFF") + "\n";
   dashboard += "--- Trailing ---\n";
   dashboard += "BUY Trailing: " + (buyTrailingLevel > 0 ? DoubleToString(buyTrailingLevel, _Digits) : "Not Active") + "\n";
   dashboard += "SELL Trailing: " + (sellTrailingLevel > 0 ? DoubleToString(sellTrailingLevel, _Digits) : "Not Active") + "\n";

   Comment(dashboard);
}

double CalculateDrawdownPercent()
{
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   if(balance > 0) return (balance - equity) / balance * 100;
   return 0;
}

//+------------------------------------------------------------------+
void DetermineCurrentDirection()
{
   int buyCount = 0, sellCount = 0;
   for(int i = 0; i < PositionsTotal(); i++)
   {
      if(PositionGetSymbol(i) == _Symbol && PositionGetInteger(POSITION_MAGIC) == 12345)
      {
         if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) buyCount++;
         else if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL) sellCount++;
      }
   }
   if(buyCount > 0 && sellCount == 0) currentDirection = 1;
   else if(sellCount > 0 && buyCount == 0) currentDirection = -1;
   else if(buyCount == 0 && sellCount == 0) currentDirection = 0;
}

void CalculateTP(double &tpPoints)
{
   if(UseATR)
   {
      double atrBuffer[];
      ArraySetAsSeries(atrBuffer, true);
      if(CopyBuffer(atrHandle, 0, 0, 1, atrBuffer) > 0)
         tpPoints = atrBuffer[0] * 2.0;   // 2x ATR target — tighter than 3x for scalping
      else
         tpPoints = TakeProfit * pipSize;
   }
   else
      tpPoints = TakeProfit * pipSize;
}

// NEW: every trade gets a real stop loss, sized off ATR (adaptive to
// current volatility) or a fixed pip value.
void CalculateSL(double &slPoints)
{
   if(UseATR)
   {
      double atrBuffer[];
      ArraySetAsSeries(atrBuffer, true);
      if(CopyBuffer(atrHandle, 0, 0, 1, atrBuffer) > 0)
         slPoints = atrBuffer[0] * ATR_SL_Multiplier;
      else
         slPoints = FixedStopLossPips * pipSize;
   }
   else
      slPoints = FixedStopLossPips * pipSize;
}

void OpenTrade(ENUM_ORDER_TYPE orderType, double volume, double tpPoints, double slPoints, string comment)
{
   double price = 0, tp = 0, sl = 0;

   MqlTradeRequest request;
   MqlTradeResult result;
   ZeroMemory(request);
   ZeroMemory(result);

   if(orderType == ORDER_TYPE_BUY)
   {
      price = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      tp = (tpPoints > 0) ? price + tpPoints : 0;
      sl = (slPoints > 0) ? price - slPoints : 0;
   }
   else if(orderType == ORDER_TYPE_SELL)
   {
      price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      tp = (tpPoints > 0) ? price - tpPoints : 0;
      sl = (slPoints > 0) ? price + slPoints : 0;
   }

   request.action = TRADE_ACTION_DEAL;
   request.symbol = _Symbol;
   request.volume = volume;
   request.type = orderType;
   request.price = price;
   request.sl = sl;          // <-- previously always 0. This was the core bug.
   request.tp = tp;
   request.deviation = 10;
   request.magic = 12345;
   request.comment = comment;
   request.type_filling = ORDER_FILLING_FOK;

   if(OrderSend(request, result))
   {
      Print("Trade opened: ", comment, " | Lot: ", volume, " | SL: ", DoubleToString(sl,_Digits),
            " | TP: ", DoubleToString(tp,_Digits), " | Ticket: ", result.order);
      tradeCountToday++;
   }
   else
   {
      Print("Error opening trade: ", GetLastError(), " ", comment);
   }
}

//+------------------------------------------------------------------+
int CountTrades()
{
   int count = 0;
   for(int i = 0; i < PositionsTotal(); i++)
      if(PositionGetSymbol(i) == _Symbol && PositionGetInteger(POSITION_MAGIC) == 12345) count++;
   return count;
}

int CountBuyTrades()
{
   int count = 0;
   for(int i = 0; i < PositionsTotal(); i++)
      if(PositionGetSymbol(i) == _Symbol && PositionGetInteger(POSITION_MAGIC) == 12345 &&
         PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) count++;
   return count;
}

int CountSellTrades()
{
   int count = 0;
   for(int i = 0; i < PositionsTotal(); i++)
      if(PositionGetSymbol(i) == _Symbol && PositionGetInteger(POSITION_MAGIC) == 12345 &&
         PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL) count++;
   return count;
}

double CalculateCurrentPL()
{
   double pl = 0;
   for(int i = 0; i < PositionsTotal(); i++)
      if(PositionGetSymbol(i) == _Symbol && PositionGetInteger(POSITION_MAGIC) == 12345)
         pl += PositionGetDouble(POSITION_PROFIT);
   return pl;
}

double GetAverageBuyPrice()
{
   double totalVolume = 0, totalValue = 0;
   for(int i = 0; i < PositionsTotal(); i++)
      if(PositionGetSymbol(i) == _Symbol && PositionGetInteger(POSITION_MAGIC) == 12345 &&
         PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
      {
         double volume = PositionGetDouble(POSITION_VOLUME);
         double price = PositionGetDouble(POSITION_PRICE_OPEN);
         totalValue += volume * price;
         totalVolume += volume;
      }
   return (totalVolume > 0) ? totalValue / totalVolume : 0;
}

double GetAverageSellPrice()
{
   double totalVolume = 0, totalValue = 0;
   for(int i = 0; i < PositionsTotal(); i++)
      if(PositionGetSymbol(i) == _Symbol && PositionGetInteger(POSITION_MAGIC) == 12345 &&
         PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL)
      {
         double volume = PositionGetDouble(POSITION_VOLUME);
         double price = PositionGetDouble(POSITION_PRICE_OPEN);
         totalValue += volume * price;
         totalVolume += volume;
      }
   return (totalVolume > 0) ? totalValue / totalVolume : 0;
}

double GetBestBuyPrice()  { return SymbolInfoDouble(_Symbol, SYMBOL_BID); }
double GetBestSellPrice() { return SymbolInfoDouble(_Symbol, SYMBOL_ASK); }

//+------------------------------------------------------------------+
void CheckTrailingStopHit()
{
   double currentPrice;

   if(currentDirection == 1 && buyTrailingLevel > 0)
   {
      currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      if(currentPrice <= buyTrailingLevel)
      {
         Print("BUY Trailing stop hit at ", DoubleToString(currentPrice, _Digits), ". Closing all BUY trades.");
         CloseAllBuyTrades();
         buyTrailingLevel = 0;
         currentDirection = 0;
         breakevenReached = false;
         gridLevel = 0;
      }
   }

   if(currentDirection == -1 && sellTrailingLevel > 0)
   {
      currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(currentPrice >= sellTrailingLevel)
      {
         Print("SELL Trailing stop hit at ", DoubleToString(currentPrice, _Digits), ". Closing all SELL trades.");
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
      if(PositionGetSymbol(i) == _Symbol && PositionGetInteger(POSITION_MAGIC) == 12345 &&
         PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
         ClosePosition(i);
   Print("All BUY trades closed by trailing stop");
}

void CloseAllSellTrades()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
      if(PositionGetSymbol(i) == _Symbol && PositionGetInteger(POSITION_MAGIC) == 12345 &&
         PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL)
         ClosePosition(i);
   Print("All SELL trades closed by trailing stop");
}

void CloseAllTrades()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
      if(PositionGetSymbol(i) == _Symbol && PositionGetInteger(POSITION_MAGIC) == 12345)
         ClosePosition(i);
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
      Print("Error closing position ", ticket, ": ", GetLastError());
}

//+------------------------------------------------------------------+
void OnTrade()
{
   UpdateDashboard();
}
