//+------------------------------------------------------------------+
//|                                              GoldKillerV17Pro.mq5|
//|                Recreated & Enhanced by ChatGPT                   |
//|     Advanced XAUUSD Grid Recovery EA for MetaTrader 5            |
//+------------------------------------------------------------------+
#property strict
#property version   "17.0"
#property description "Advanced Grid + Basket Recovery EA"

#include <Trade/Trade.mqh>
CTrade trade;

//====================================================
// INPUTS
//====================================================
input group "=== General Settings ==="
input long   MagicNumber              = 5555;
input bool   EnableBuy                = true;
input bool   EnableSell               = true;
input bool   OneTradePerBar           = true;

input group "=== Lot Settings ==="
input double InitialLot               = 0.01;
input double LotMultiplier            = 1.8;
input int    LotIncreaseEvery         = 3;
input double MaxLot                   = 20.0;

input group "=== Grid Settings ==="
input int    BaseGridPoints           = 1000;
input bool   DynamicGrid              = true;
input double ATRMultiplier            = 1.5;
input int    ATRPeriod                = 14;
input int    MaxTradesPerSide         = 80;

input group "=== Basket Targets ==="
input double BuyBasketTP_USD          = 100;
input double SellBasketTP_USD         = 100;
input double EquityProtectionPercent  = 30;
input double MaxFloatingDrawdownUSD   = 3000;

input group "=== Trend Filter ==="
input bool   UseEMAFilter             = true;
input int    FastEMA                  = 20;
input int    SlowEMA                  = 50;
input ENUM_TIMEFRAMES TrendTF         = PERIOD_M15;

input group "=== RSI Filter ==="
input bool   UseRSIFilter             = false;
input int    RSIPeriod                = 14;
input double RSIOverbought            = 70;
input double RSIOversold              = 30;

input group "=== Trailing Basket ==="
input bool   EnableBasketTrailing     = true;
input double BasketTrailStart         = 30;
input double BasketTrailLock          = 15;

input group "=== Trading Session ==="
input bool   UseTradingHours          = false;
input int    StartHour                = 0;
input int    EndHour                  = 23;

input group "=== News Protection ==="
input bool   PauseOnHighSpread        = true;
input int    MaxSpreadPoints          = 500;

//====================================================
// GLOBALS
//====================================================
double BuyPeakProfit  = 0;
double SellPeakProfit = 0;
datetime LastBarTime  = 0;

//====================================================
// INITIALIZATION
//====================================================
int OnInit()
{
   Print("Gold Killer V17 Pro Initialized");
   return(INIT_SUCCEEDED);
}

//====================================================
// TICK FUNCTION
//====================================================
void OnTick()
{
   if(!TradingAllowed())
      return;

   ManageEquityProtection();
   ManageBasketTargets();
   ManageBasketTrailing();

   if(EnableBuy)
      ProcessBuyGrid();

   if(EnableSell)
      ProcessSellGrid();

   DrawDashboard();
}

//====================================================
// TRADING FILTERS
//====================================================
bool TradingAllowed()
{
   // Spread protection
   if(PauseOnHighSpread)
   {
      double spread = (SymbolInfoDouble(_Symbol,SYMBOL_ASK) -
                       SymbolInfoDouble(_Symbol,SYMBOL_BID))/_Point;

      if(spread > MaxSpreadPoints)
         return false;
   }

   // Session filter
   if(UseTradingHours)
   {
      MqlDateTime tm;
      TimeToStruct(TimeCurrent(),tm);

      if(tm.hour < StartHour || tm.hour > EndHour)
         return false;
   }

   return true;
}

//====================================================
// BUY GRID
//====================================================
void ProcessBuyGrid()
{
   int buys = CountPositions(POSITION_TYPE_BUY);

   if(buys >= MaxTradesPerSide)
      return;

   if(!BuySignal())
      return;

   double lot = CalculateLot(buys);

   if(buys == 0)
   {
      OpenBuy(lot);
      return;
   }

   double lastPrice = LastPositionPrice(POSITION_TYPE_BUY);
   double grid      = CurrentGridDistance();

   if(SymbolInfoDouble(_Symbol,SYMBOL_BID) <= lastPrice - grid)
      OpenBuy(lot);
}

//====================================================
// SELL GRID
//====================================================
void ProcessSellGrid()
{
   int sells = CountPositions(POSITION_TYPE_SELL);

   if(sells >= MaxTradesPerSide)
      return;

   if(!SellSignal())
      return;

   double lot = CalculateLot(sells);

   if(sells == 0)
   {
      OpenSell(lot);
      return;
   }

   double lastPrice = LastPositionPrice(POSITION_TYPE_SELL);
   double grid      = CurrentGridDistance();

   if(SymbolInfoDouble(_Symbol,SYMBOL_ASK) >= lastPrice + grid)
      OpenSell(lot);
}

//====================================================
// SIGNALS
//====================================================
bool BuySignal()
{
   // Instant startup trading when no positions exist
   if(CountPositions(POSITION_TYPE_BUY) == 0)
      return true;

   if(UseEMAFilter)
   {
      double fast = iMA(_Symbol,TrendTF,FastEMA,0,MODE_EMA,PRICE_CLOSE);
      double slow = iMA(_Symbol,TrendTF,SlowEMA,0,MODE_EMA,PRICE_CLOSE);

      if(fast < slow)
         return false;
   }

   if(UseRSIFilter)
   {
      double rsi = iRSI(_Symbol,_Period,RSIPeriod,PRICE_CLOSE);

      if(rsi > RSIOversold)
         return false;
   }

   return true;
}

bool SellSignal()
{
   // Instant startup trading when no positions exist
   if(CountPositions(POSITION_TYPE_SELL) == 0)
      return true;

   if(UseEMAFilter)
   {
      double fast = iMA(_Symbol,TrendTF,FastEMA,0,MODE_EMA,PRICE_CLOSE);
      double slow = iMA(_Symbol,TrendTF,SlowEMA,0,MODE_EMA,PRICE_CLOSE);

      if(fast > slow)
         return false;
   }

   if(UseRSIFilter)
   {
      double rsi = iRSI(_Symbol,_Period,RSIPeriod,PRICE_CLOSE);

      if(rsi < RSIOverbought)
         return false;
   }

   return true;
}

//====================================================
// OPEN ORDERS
//====================================================
void OpenBuy(double lot)
{
   trade.SetExpertMagicNumber(MagicNumber);
   trade.Buy(lot,_Symbol,0,0,0,"GK Buy");
}

void OpenSell(double lot)
{
   trade.SetExpertMagicNumber(MagicNumber);
   trade.Sell(lot,_Symbol,0,0,0,"GK Sell");
}

//====================================================
// LOT CALCULATION
//====================================================
double CalculateLot(int trades)
{
   int level = trades / LotIncreaseEvery;

   double lot = InitialLot * MathPow(LotMultiplier,level);

   if(lot > MaxLot)
      lot = MaxLot;

   return NormalizeDouble(lot,2);
}

//====================================================
// GRID DISTANCE
//====================================================
double CurrentGridDistance()
{
   double grid = BaseGridPoints * _Point;

   if(DynamicGrid)
   {
      double atr = iATR(_Symbol,_Period,ATRPeriod);
      grid = atr * ATRMultiplier;
   }

   return grid;
}

//====================================================
// POSITION HELPERS
//====================================================
int CountPositions(ENUM_POSITION_TYPE type)
{
   int count = 0;

   for(int i=PositionsTotal()-1;i>=0;i--)
   {
      ulong ticket = PositionGetTicket(i);

      if(PositionSelectByTicket(ticket))
      {
         if(PositionGetInteger(POSITION_MAGIC)==MagicNumber &&
            PositionGetString(POSITION_SYMBOL)==_Symbol &&
            PositionGetInteger(POSITION_TYPE)==type)
         {
            count++;
         }
      }
   }

   return count;
}

//====================================================
// LAST POSITION PRICE
//====================================================
double LastPositionPrice(ENUM_POSITION_TYPE type)
{
   double price = 0;

   for(int i=PositionsTotal()-1;i>=0;i--)
   {
      ulong ticket = PositionGetTicket(i);

      if(PositionSelectByTicket(ticket))
      {
         if(PositionGetInteger(POSITION_MAGIC)==MagicNumber &&
            PositionGetInteger(POSITION_TYPE)==type)
         {
            price = PositionGetDouble(POSITION_PRICE_OPEN);
            break;
         }
      }
   }

   return price;
}

//====================================================
// BASKET PROFITS
//====================================================
double BasketProfit(ENUM_POSITION_TYPE type)
{
   double profit = 0;

   for(int i=PositionsTotal()-1;i>=0;i--)
   {
      ulong ticket = PositionGetTicket(i);

      if(PositionSelectByTicket(ticket))
      {
         if(PositionGetInteger(POSITION_MAGIC)==MagicNumber &&
            PositionGetString(POSITION_SYMBOL)==_Symbol &&
            PositionGetInteger(POSITION_TYPE)==type)
         {
            profit += PositionGetDouble(POSITION_PROFIT);
         }
      }
   }

   return profit;
}

//====================================================
// CLOSE BASKET
//====================================================
void CloseBasket(ENUM_POSITION_TYPE type)
{
   for(int i=PositionsTotal()-1;i>=0;i--)
   {
      ulong ticket = PositionGetTicket(i);

      if(PositionSelectByTicket(ticket))
      {
         if(PositionGetInteger(POSITION_MAGIC)==MagicNumber &&
            PositionGetInteger(POSITION_TYPE)==type)
         {
            trade.PositionClose(ticket);
         }
      }
   }
}

//====================================================
// MANAGE BASKETS
//====================================================
void ManageBasketTargets()
{
   double buyProfit  = BasketProfit(POSITION_TYPE_BUY);
   double sellProfit = BasketProfit(POSITION_TYPE_SELL);

   if(buyProfit >= BuyBasketTP_USD)
      CloseBasket(POSITION_TYPE_BUY);

   if(sellProfit >= SellBasketTP_USD)
      CloseBasket(POSITION_TYPE_SELL);
}

//====================================================
// BASKET TRAILING
//====================================================
void ManageBasketTrailing()
{
   if(!EnableBasketTrailing)
      return;

   double buyProfit = BasketProfit(POSITION_TYPE_BUY);

   if(buyProfit > BuyPeakProfit)
      BuyPeakProfit = buyProfit;

   if(BuyPeakProfit >= BasketTrailStart)
   {
      if(buyProfit <= BuyPeakProfit - BasketTrailLock)
      {
         CloseBasket(POSITION_TYPE_BUY);
         BuyPeakProfit = 0;
      }
   }

   double sellProfit = BasketProfit(POSITION_TYPE_SELL);

   if(sellProfit > SellPeakProfit)
      SellPeakProfit = sellProfit;

   if(SellPeakProfit >= BasketTrailStart)
   {
      if(sellProfit <= SellPeakProfit - BasketTrailLock)
      {
         CloseBasket(POSITION_TYPE_SELL);
         SellPeakProfit = 0;
      }
   }
}

//====================================================
// EQUITY PROTECTION
//====================================================
void ManageEquityProtection()
{
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double equity  = AccountInfoDouble(ACCOUNT_EQUITY);

   double ddPercent = ((balance-equity)/balance)*100;

   if(ddPercent >= EquityProtectionPercent)
   {
      Print("Emergency equity protection triggered.");
      CloseAllPositions();
   }

   double floating = balance-equity;

   if(floating >= MaxFloatingDrawdownUSD)
   {
      Print("Floating drawdown protection triggered.");
      CloseAllPositions();
   }
}

//====================================================
// CLOSE EVERYTHING
//====================================================
void CloseAllPositions()
{
   for(int i=PositionsTotal()-1;i>=0;i--)
   {
      ulong ticket = PositionGetTicket(i);

      if(PositionSelectByTicket(ticket))
      {
         if(PositionGetInteger(POSITION_MAGIC)==MagicNumber)
            trade.PositionClose(ticket);
      }
   }
}

//====================================================
// DASHBOARD PANEL
//====================================================
void DrawDashboard()
{
   string panel = "";

   double buyProfit  = BasketProfit(POSITION_TYPE_BUY);
   double sellProfit = BasketProfit(POSITION_TYPE_SELL);

   double totalProfit = buyProfit + sellProfit;

   double spread = (SymbolInfoDouble(_Symbol,SYMBOL_ASK) -
                    SymbolInfoDouble(_Symbol,SYMBOL_BID))/_Point;

   panel += "═══════════════════════════════
";
   panel += "      GOLD KILLER V17 PRO      
";
   panel += " Institutional Grid Edition   
";
   panel += "═══════════════════════════════

";

   panel += "[ PERFORMANCE ]
";
   panel += "Net Profit : $" + DoubleToString(totalProfit,2) + "
";
   panel += "Buy Profit : $" + DoubleToString(buyProfit,2) + "
";
   panel += "Sell Profit: $" + DoubleToString(sellProfit,2) + "

";

   panel += "[ TRADING STATUS ]
";
   panel += "Symbol     : " + _Symbol + "
";
   panel += "Status     : ACTIVE
";
   panel += "Buy Trades : " + IntegerToString(CountPositions(POSITION_TYPE_BUY)) + "
";
   panel += "Sell Trades: " + IntegerToString(CountPositions(POSITION_TYPE_SELL)) + "
";

   double totalLots = 0;

   for(int i=PositionsTotal()-1;i>=0;i--)
   {
      ulong ticket = PositionGetTicket(i);

      if(PositionSelectByTicket(ticket))
      {
         if(PositionGetInteger(POSITION_MAGIC)==MagicNumber)
         {
            totalLots += PositionGetDouble(POSITION_VOLUME);
         }
      }
   }

   panel += "Total Lots : " + DoubleToString(totalLots,2) + "

";

   panel += "[ SYSTEM INFO ]
";
   panel += "Magic No   : " + IntegerToString(MagicNumber) + "
";
   panel += "Grid Mode  : BOTH
";
   panel += "Version    : v17.0
";
   panel += "Spread     : " + DoubleToString(spread,0) + " pts
";
   panel += "Balance    : $" + DoubleToString(AccountInfoDouble(ACCOUNT_BALANCE),2) + "
";
   panel += "Equity     : $" + DoubleToString(AccountInfoDouble(ACCOUNT_EQUITY),2) + "

";

   panel += "═══════════════════════════════
";
   panel += "Server Time: " + TimeToString(TimeCurrent(),TIME_SECONDS) + "
";
   panel += "═══════════════════════════════
";

   Comment(panel);
}
//+------------------------------------------------------------------+

