//+------------------------------------------------------------------+
//|                                              VORTEX_APEX_v5.mq5  |
//|                                  Copyright 2026, VORTEX_APEX AI  |
//|                                       https://www.vortex-apex.ai |
//+------------------------------------------------------------------+
#property copyright   "Copyright 2026, VORTEX_APEX AI"
#property link        "https://www.vortex-apex.ai"
#property version     "5.07"
#property description "Elite XAUUSD Straddle Lot-Increment Algorithmic System"
#property strict

// Include standard trade libraries
#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>
#include <Trade\OrderInfo.mqh>

//--- Input Parameters
input group "=== CORE STRADDLE CONFIGURATION ==="
input int            InpStraddleDistancePips = 120;       // Base Straddle Distance from Spot (Pips)
input int            InpMinStraddleDistance  = 60;        // Minimum Allowed Straddle Distance (Pips)
input int            InpMaxStraddleDistance  = 350;       // Maximum Allowed Straddle Distance (Pips)
input int            InpExpirationMinutes    = 15;        // Pending Order Expiration (Minutes)

input group "=== QUANTITATIVE RISK & COMPOUNDING ==="
input double         InpBaseRiskPercent      = 2.0;       // Initial Risk Percent Per Trade Setup
input double         InpLotIncrementMultiplier= 1.5;      // Compounding Scale Factor for Pyramiding (Alpha)
input int            InpMaxPyramidLegs       = 4;         // Maximum Scaling Legs Per Direction
input double         InpMinLotSize           = 0.01;      // Hard Floor Lot Size
input double         InpMaxLotSize           = 50.0;      // Absolute Ceiling Lot Size

input group "=== TRAILING & RISK PROTECTION ==="
input int            InpBreakEvenTriggerPips = 100;       // Pips in profit to trigger Break-Even
input int            InpBreakEvenBufferPips  = 15;        // Pips to lock in past entry price
input int            InpTrailingStartPips    = 150;       // Pips in profit to activate Trailing Stop
input int            InpTrailingStepPips     = 10;        // Trailing Stop Step Resolution (Pips)
input int            InpMaxSpreadPips        = 40;        // Maximum Allowed Execution Spread (Pips)
input int            InpATRPeriod            = 14;        // ATR Calculation Period

input group "=== SYSTEM IDENTIFICATION ==="
input ulong          InpMagicNumber          = 99912388;  // Unique Bot Identity Allocation
input int            InpSlippagePips         = 30;        // Max Execution Slippage Allowed (Pips)

//--- Global Objects and Variables
CTrade           TradeEngine;
CPositionInfo    PosInfo;
COrderInfo       OrderInfo;

int              atrHandle;
double           pipFactor;
datetime         lastOrderPlacementTime = 0;

// --- Pure integer storage avoids missing compiler macro definitions entirely
int GlobalFillingModeInt = 0; 

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   // Initialize pip factor calculation based on digits
   if(_Digits == 3 || _Digits == 5)
      pipFactor = 10.0 * _Point;
   else
      pipFactor = _Point;

   // Set up the TradeEngine execution parameters
   TradeEngine.SetExpertMagicNumber(InpMagicNumber);
   TradeEngine.SetDeviationInPoints(InpSlippagePips * (int)(pipFactor/_Point));

   // --- MANUAL BITMASK ROUTING: Pure integers used to bypass missing enums ---
   uint fillingMode = (uint)SymbolInfoInteger(_Symbol, SYMBOL_FILLING_MODE);
   
   if((fillingMode & SYMBOL_FILLING_FOK) != 0) 
   {
      GlobalFillingModeInt = 0; // Raw integer equivalent to TYPE_FILLING_FOK / ORDER_FILL_FOK
   }
   else if((fillingMode & SYMBOL_FILLING_IOC) != 0) 
   {
      GlobalFillingModeInt = 1; // Raw integer equivalent to TYPE_FILLING_IOC / ORDER_FILL_IOC
   }
   else 
   {
      GlobalFillingModeInt = 2; // Raw integer equivalent to TYPE_FILLING_RETURN / ORDER_FILL_RETURN
   }

   // Initialize Indicator Handle for ATR Volatility Tracking
   atrHandle = iATR(_Symbol, PERIOD_M1, InpATRPeriod);
   if(atrHandle == INVALID_HANDLE)
   {
      Print("[VORTEX_APEX] CRITICAL: Failed to initialize iATR Handle. Core aborting.");
      return(INIT_FAILED);
   }

   Print("[VORTEX_APEX] Core Architecture initialized successfully. Target Lock: XAUUSD.");
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   IndicatorRelease(atrHandle);
   Print("[VORTEX_APEX] System deactivated. Reason Code: ", reason);
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   // Check structural conditions and spread rules
   double currentSpread = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD) * _Point / pipFactor;
   if(currentSpread > InpMaxSpreadPips)
   {
      // High liquidity extraction risk detected. Suppress entry execution loops.
      return;
   }

   // Count positions and orders belonging to this bot setup
   int activeBuyPositions = 0;
   int activeSellPositions = 0;
   int totalPendingOrders = 0;

   ScanMarketState(activeBuyPositions, activeSellPositions, totalPendingOrders);

   // Manage active trade cycles if positions exist
   if(activeBuyPositions > 0 || activeSellPositions > 0)
   {
      ManageActiveBasket(activeBuyPositions, activeSellPositions);
   }
   
   // Handle the pending straddle generation if no positions or existing orders are present
   if(activeBuyPositions == 0 && activeSellPositions == 0)
   {
      ManageStraddleGrid(totalPendingOrders);
   }
}

//+------------------------------------------------------------------+
//| Scans system state for active positions and pending orders       |
//+------------------------------------------------------------------+
void ScanMarketState(int &buyCount, int &sellCount, int &orderCount)
{
   buyCount = 0;
   sellCount = 0;
   orderCount = 0;

   // Loop over open positions
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(PosInfo.SelectByIndex(i))
      {
         if(PosInfo.Symbol() == _Symbol && PosInfo.Magic() == InpMagicNumber)
         {
            if(PosInfo.PositionType() == POSITION_TYPE_BUY)  buyCount++;
            if(PosInfo.PositionType() == POSITION_TYPE_SELL) sellCount++;
         }
      }
   }

   // Loop over outstanding orders
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(OrderInfo.SelectByIndex(i))
      {
         if(OrderInfo.Symbol() == _Symbol && OrderInfo.Magic() == InpMagicNumber)
         {
            orderCount++;
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Places and modifies the core straddle pending orders             |
//+------------------------------------------------------------------+
void ManageStraddleGrid(int orderCount)
{
   // If orders are already active in market, skip initialization
   if(orderCount > 0)
   {
      // Check for stale orders needing replacement due to structural drift
      if(TimeCurrent() - lastOrderPlacementTime > InpExpirationMinutes * 60)
      {
         CancelAllPendingOrders();
      }
      return;
   }

   // Request dynamic variance mapping from ATR Engine
   double atrValues[];
   ArraySetAsSeries(atrValues, true);
   if(CopyBuffer(atrHandle, 0, 0, 1, atrValues) < 1) return;

   // Mathematical spacing logic
   double dynamicDistance = InpStraddleDistancePips * (atrValues[0] / _Point / 100.0);
   if(dynamicDistance < InpMinStraddleDistance) dynamicDistance = InpMinStraddleDistance;
   if(dynamicDistance > InpMaxStraddleDistance) dynamicDistance = InpMaxStraddleDistance;

   double offsetPrice = dynamicDistance * pipFactor;
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);

   double buyStopPrice  = ask + offsetPrice;
   double sellStopPrice = bid - offsetPrice;

   // Lot calculation anchored directly to Free Equity Compounding Model
   double initialLot = NormalizeDouble((AccountInfoDouble(ACCOUNT_EQUITY) * (InpBaseRiskPercent / 100.0)) / 1000.0, 2);
   if(initialLot < InpMinLotSize) initialLot = InpMinLotSize;
   if(initialLot > InpMaxLotSize) initialLot = InpMaxLotSize;

   datetime expiration = TimeCurrent() + (InpExpirationMinutes * 60);
   
   // --- FIXED: Removed {0} to completely resolve enum type-conversion warning ---
   MqlTradeRequest request={};
   MqlTradeResult  result={};
   
   // --- BUY STOP PLACEMENT ENTRY BLOCK ---
   request.action       = TRADE_ACTION_PENDING;
   request.symbol       = _Symbol;
   request.volume       = initialLot;
   request.price        = NormalizeDouble(buyStopPrice, _Digits);
   request.type         = ORDER_TYPE_BUY_STOP;
   request.type_filling = (ENUM_ORDER_TYPE_FILLING)GlobalFillingModeInt; 
   request.type_time    = ORDER_TIME_SPECIFIED;
   request.expiration   = expiration;
   request.magic        = InpMagicNumber;
   request.deviation    = InpSlippagePips * (int)(pipFactor/_Point);
   
   if(OrderSend(request, result))
   {
      // --- SELL STOP PLACEMENT ENTRY BLOCK ---
      ZeroMemory(request);
      ZeroMemory(result);
      
      request.action       = TRADE_ACTION_PENDING;
      request.symbol       = _Symbol;
      request.volume       = initialLot;
      request.price        = NormalizeDouble(sellStopPrice, _Digits);
      request.type         = ORDER_TYPE_SELL_STOP;
      request.type_filling = (ENUM_ORDER_TYPE_FILLING)GlobalFillingModeInt; 
      request.type_time    = ORDER_TIME_SPECIFIED;
      request.expiration   = expiration;
      request.magic        = InpMagicNumber;
      request.deviation    = InpSlippagePips * (int)(pipFactor/_Point);
      
      if(OrderSend(request, result))
      {
         lastOrderPlacementTime = TimeCurrent();
      }
      else
      {
         CancelAllPendingOrders();
      }
   }
}

//+------------------------------------------------------------------+
//| Manages tracking, break-even updates, trailing, and compounding  |
//+------------------------------------------------------------------+
void ManageActiveBasket(int buyCount, int sellCount)
{
   // Wipe out oppositional pending lines to lock focus onto the running breakout vector
   CancelAllPendingOrders();

   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);

   // Manage Active Buy Basket
   if(buyCount > 0)
   {
      double highestOpenPrice = 0;
      double lowestEntryPrice = 999999;
      double totalVolume = 0;
      double runningPriceSum = 0;

      for(int i = PositionsTotal() - 1; i >= 0; i--)
      {
         if(PosInfo.SelectByIndex(i))
         {
            if(PosInfo.Symbol() == _Symbol && PosInfo.Magic() == InpMagicNumber && PosInfo.PositionType() == POSITION_TYPE_BUY)
            {
               double openPrice = PosInfo.PriceOpen();
               double vol = PosInfo.Volume();
               
               if(openPrice > highestOpenPrice) highestOpenPrice = openPrice;
               if(openPrice < lowestEntryPrice)  lowestEntryPrice  = openPrice;
               
               totalVolume += vol;
               runningPriceSum += (openPrice * vol);
               
               // Apply individual trailing or break-even updates
               double profitPips = (bid - openPrice) / pipFactor;
               double currentStop = PosInfo.StopLoss();
               
               // Break-even enforcement
               if(profitPips >= InpBreakEvenTriggerPips && (currentStop < openPrice + (InpBreakEvenBufferPips * pipFactor)))
               {
                  double targetSL = openPrice + (InpBreakEvenBufferPips * pipFactor);
                  TradeEngine.PositionModify(PosInfo.Ticket(), NormalizeDouble(targetSL, _Digits), PosInfo.TakeProfit());
               }
               
               // Dynamic high-velocity tracking execution
               if(profitPips >= InpTrailingStartPips)
               {
                  double calculatedSL = bid - (InpTrailingStartPips * pipFactor);
                  if(calculatedSL > currentStop + (InpTrailingStepPips * pipFactor) || currentStop == 0)
                  {
                     TradeEngine.PositionModify(PosInfo.Ticket(), NormalizeDouble(calculatedSL, _Digits), PosInfo.TakeProfit());
                  }
               }
            }
         }
      }

      // Check for Kinetic Velocity Pyramiding Trigger
      double targetDistanceThreshold = InpStraddleDistancePips * pipFactor;
      
      if(buyCount < InpMaxPyramidLegs && (bid - highestOpenPrice) >= targetDistanceThreshold)
      {
         double nextLotSize = NormalizeDouble(totalVolume * InpLotIncrementMultiplier, 2);
         if(nextLotSize <= InpMaxLotSize)
         {
            // --- FIXED: Added brace block empty matching initialization ---
            MqlTradeRequest pyReq={}; 
            MqlTradeResult pyRes={};
            pyReq.action       = TRADE_ACTION_DEAL;
            pyReq.symbol       = _Symbol;
            pyReq.volume       = nextLotSize;
            pyReq.price        = ask;
            pyReq.type         = ORDER_TYPE_BUY;
            pyReq.type_filling = (ENUM_ORDER_TYPE_FILLING)GlobalFillingModeInt;
            pyReq.magic        = InpMagicNumber;
            pyReq.deviation    = InpSlippagePips * (int)(pipFactor/_Point);
            
            // --- FIXED: Checked the execution result state to squash return validation warnings ---
            if(!OrderSend(pyReq, pyRes))
            {
               Print("[VORTEX_APEX] Pyramid Buy Execution Failed. Code: ", GetLastError());
            }
         }
      }
   }

   // Manage Active Sell Basket
   if(sellCount > 0)
   {
      double lowestOpenPrice = 999999;
      double highestEntryPrice = 0;
      double totalVolume = 0;
      double runningPriceSum = 0;

      for(int i = PositionsTotal() - 1; i >= 0; i--)
      {
         if(PosInfo.SelectByIndex(i))
         {
            if(PosInfo.Symbol() == _Symbol && PosInfo.Magic() == InpMagicNumber && PosInfo.PositionType() == POSITION_TYPE_SELL)
            {
               double openPrice = PosInfo.PriceOpen();
               double vol = PosInfo.Volume();
               
               if(openPrice < lowestOpenPrice) lowestOpenPrice = openPrice;
               if(openPrice > highestEntryPrice) highestEntryPrice = openPrice;
               
               totalVolume += vol;
               runningPriceSum += (openPrice * vol);
               
               // Apply individual trailing or break-even updates
               double profitPips = (openPrice - ask) / pipFactor;
               double currentStop = PosInfo.StopLoss();
               
               // Break-even enforcement
               if(profitPips >= InpBreakEvenTriggerPips && (currentStop > openPrice - (InpBreakEvenBufferPips * pipFactor) || currentStop == 0))
               {
                  double targetSL = openPrice - (InpBreakEvenBufferPips * pipFactor);
                  TradeEngine.PositionModify(PosInfo.Ticket(), NormalizeDouble(targetSL, _Digits), PosInfo.TakeProfit());
               }
               
               // Dynamic high-velocity tracking execution
               if(profitPips >= InpTrailingStartPips)
               {
                  double calculatedSL = ask + (InpTrailingStartPips * pipFactor);
                  if(calculatedSL < currentStop - (InpTrailingStepPips * pipFactor) || currentStop == 0)
                  {
                     TradeEngine.PositionModify(PosInfo.Ticket(), NormalizeDouble(calculatedSL, _Digits), PosInfo.TakeProfit());
                  }
               }
            }
         }
      }

      // Check for Kinetic Velocity Pyramiding Trigger
      double targetDistanceThreshold = InpStraddleDistancePips * pipFactor;
      
      if(sellCount < InpMaxPyramidLegs && (lowestOpenPrice - ask) >= targetDistanceThreshold)
      {
         double nextLotSize = NormalizeDouble(totalVolume * InpLotIncrementMultiplier, 2);
         if(nextLotSize <= InpMaxLotSize)
         {
            // --- FIXED: Added brace block empty matching initialization ---
            MqlTradeRequest pyReq={}; 
            MqlTradeResult pyRes={};
            pyReq.action       = TRADE_ACTION_DEAL;
            pyReq.symbol       = _Symbol;
            pyReq.volume       = nextLotSize;
            pyReq.price        = bid;
            pyReq.type         = ORDER_TYPE_SELL;
            pyReq.type_filling = (ENUM_ORDER_TYPE_FILLING)GlobalFillingModeInt;
            pyReq.magic        = InpMagicNumber;
            pyReq.deviation    = InpSlippagePips * (int)(pipFactor/_Point);
            
            // --- FIXED: Checked the execution result state to squash return validation warnings ---
            if(!OrderSend(pyReq, pyRes))
            {
               Print("[VORTEX_APEX] Pyramid Sell Execution Failed. Code: ", GetLastError());
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Clears all pending positions when structure signals invalidation |
//+------------------------------------------------------------------+
void CancelAllPendingOrders()
{
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(OrderInfo.SelectByIndex(i))
      {
         if(OrderInfo.Symbol() == _Symbol && OrderInfo.Magic() == InpMagicNumber)
         {
            TradeEngine.OrderDelete(OrderInfo.Ticket());
         }
      }
   }
}