//+------------------------------------------------------------------+
//|                                              RSI_Divergence.mq5  |
//|                         RSI Divergence Reversion Strategy         |
//|                         XAUUSD M5 - Mean Reversion               |
//+------------------------------------------------------------------+
#property copyright "Trading EAs"
#property version   "2.00"
#property strict

#include <Trade\Trade.mqh>

//+------------------------------------------------------------------+
//| Input Parameters                                                  |
//+------------------------------------------------------------------+
// RSI Settings
input int    InpRSIPeriod       = 14;         // RSI Period
input double InpRSIOverbought   = 70.0;       // RSI Overbought Level
input double InpRSIOversold     = 30.0;       // RSI Oversold Level
input double InpRSITP1Level     = 50.0;       // RSI TP1 Level (close 50%)
input double InpRSITP2Buy       = 70.0;       // RSI TP2 Level for BUY
input double InpRSITP2Sell      = 30.0;       // RSI TP2 Level for SELL

// Divergence Detection
input int    InpSwingLookback   = 5;          // Swing Detection Lookback Bars
input int    InpDivergenceWindow= 50;         // Max Bars Between Divergence Swings
input int    InpMinDivBars      = 5;          // Min Bars Between Divergence Swings
input int    InpMaxDivAge       = 15;         // Max Bars Since Recent Divergence Swing
input bool   InpStrictZone      = true;       // Older Swing RSI Must Be Beyond OB/OS

// Trade Management
input double InpLotSize         = 0.10;       // Lot Size
input double InpMaxSLPoints     = 1500;       // Max SL in Points
input double InpMinSLPoints     = 200;        // Min SL in Points
input double InpMinSLPct        = 0.25;       // Min SL as % of Price (0 = off)
input double InpMaxSLPct        = 0;          // Max SL as % of Price (0 = off)
input int    InpPendingExpiry   = 5;          // Pending Order Expiry (bars)
input double InpTP1ClosePercent = 50.0;       // TP1 Close Percentage
input int    InpMaxSpread       = 50;         // Max Spread (points)
input double InpTP1RR           = 1.0;        // TP1 at R Multiple (price-based)
input double InpTP2RR           = 3.0;        // Hard TP2 at R Multiple (0 = off)

// H1 Trend Filter
input int    InpH1EMAPeriod     = 50;         // H1 EMA Period for Trend Filter
input bool   InpUseTrendFilter  = true;       // Use H1 Trend Filter
input double InpADXMax          = 0;          // Skip if H1 ADX Above (0 = off)
input bool   InpSkipTuesday     = false;      // Skip New Entries on Tuesday

// General
input int    InpMagicNumber     = 20261025;   // Magic Number
input int    InpMaxOpenTrades   = 2;          // Max Open Trades
input int    InpCooldownBars    = 3;          // Cooldown Bars After Trade

//+------------------------------------------------------------------+
//| Global Variables                                                  |
//+------------------------------------------------------------------+
CTrade         trade;
int            handleRSI;
int            handleRSI_H1;
int            handleEMA_H1;
int            handleADX_H1;
double         rsiBuffer[];
double         rsiH1Buffer[];
double         emaH1Buffer[];
datetime       lastTradeTime;
int            lastTradeBar;
bool           tp1Hit[];          // Track TP1 status per position

// Signal tracking
struct SignalInfo
{
   int       direction;      // 1=buy, -1=sell
   double    entryPrice;     // pending order price
   double    stopLoss;       // SL price
   datetime  signalTime;     // when signal was generated
   int       signalBar;      // bar index when signal was generated
   bool      active;         // is signal active
};

SignalInfo currentSignal;

//+------------------------------------------------------------------+
//| Expert initialization function                                     |
//+------------------------------------------------------------------+
int OnInit()
{
   trade.SetExpertMagicNumber(InpMagicNumber);
   trade.SetDeviationInPoints(20);
   trade.SetTypeFilling(ORDER_FILLING_IOC);

   // Create RSI handle for M5
   handleRSI = iRSI(_Symbol, PERIOD_M5, InpRSIPeriod, PRICE_CLOSE);
   if(handleRSI == INVALID_HANDLE)
   {
      Print("Failed to create RSI indicator");
      return INIT_FAILED;
   }

   // Create RSI handle for H1 (for potential multi-TF use)
   handleRSI_H1 = iRSI(_Symbol, PERIOD_H1, InpRSIPeriod, PRICE_CLOSE);

   // Create EMA handle for H1 trend filter
   handleEMA_H1 = iMA(_Symbol, PERIOD_H1, InpH1EMAPeriod, 0, MODE_EMA, PRICE_CLOSE);
   if(handleEMA_H1 == INVALID_HANDLE)
   {
      Print("Failed to create H1 EMA indicator");
      return INIT_FAILED;
   }

   handleADX_H1 = iADX(_Symbol, PERIOD_H1, 14);
   if(handleADX_H1 == INVALID_HANDLE)
   {
      Print("Failed to create H1 ADX indicator");
      return INIT_FAILED;
   }

   ArraySetAsSeries(rsiBuffer, true);
   ArraySetAsSeries(rsiH1Buffer, true);
   ArraySetAsSeries(emaH1Buffer, true);

   currentSignal.active = false;
   lastTradeBar = 0;

   Print("RSI Divergence Reversion EA initialized");
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                    |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   if(handleRSI != INVALID_HANDLE) IndicatorRelease(handleRSI);
   if(handleRSI_H1 != INVALID_HANDLE) IndicatorRelease(handleRSI_H1);
   if(handleEMA_H1 != INVALID_HANDLE) IndicatorRelease(handleEMA_H1);
   if(handleADX_H1 != INVALID_HANDLE) IndicatorRelease(handleADX_H1);
}

//+------------------------------------------------------------------+
//| Expert tick function                                               |
//+------------------------------------------------------------------+
void OnTick()
{
   // Price-based TP1 runs every tick
   ManageTP1();

   // Only process on new bar
   static datetime lastBarTime = 0;
   datetime currentBarTime = iTime(_Symbol, PERIOD_M5, 0);
   if(currentBarTime == lastBarTime) return;
   lastBarTime = currentBarTime;

   // Check spread
   double spread = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   if(spread > InpMaxSpread) return;

   // Copy indicator data
   if(CopyBuffer(handleRSI, 0, 0, InpDivergenceWindow + 20, rsiBuffer) <= 0) return;
   if(CopyBuffer(handleEMA_H1, 0, 0, 3, emaH1Buffer) <= 0) return;
   if(CopyBuffer(handleRSI_H1, 0, 0, 3, rsiH1Buffer) <= 0) return;

   // Manage existing positions (RSI-based TP)
   ManagePositions();

   // Check and manage pending orders
   ManagePendingOrders();

   // Check cooldown
   int currentBar = Bars(_Symbol, PERIOD_M5);
   if(currentBar - lastTradeBar < InpCooldownBars) return;

   // Count open positions
   int openPositions = CountPositions();
   if(openPositions >= InpMaxOpenTrades) return;

   // Count pending orders
   int pendingOrders = CountPendingOrders();
   if(pendingOrders > 0) return;  // Already have a pending

   // Day filter
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   if(InpSkipTuesday && dt.day_of_week == 2) return;

   // Strong-trend filter
   if(InpADXMax > 0)
   {
      double adx[];
      ArraySetAsSeries(adx, true);
      if(CopyBuffer(handleADX_H1, 0, 1, 1, adx) <= 0) return;
      if(adx[0] > InpADXMax) return;
   }

   // Look for new signals
   CheckForSignal();
}

//+------------------------------------------------------------------+
//| Find swing highs in price data                                     |
//+------------------------------------------------------------------+
bool FindSwingHigh(int startBar, int endBar, int lookback, int &swingBar)
{
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   int copied = CopyRates(_Symbol, PERIOD_M5, 0, endBar + lookback + 5, rates);
   if(copied <= 0) return false;

   for(int i = startBar; i <= endBar; i++)
   {
      if(i < lookback || i + lookback >= copied) continue;

      bool isSwing = true;
      double highVal = rates[i].high;

      for(int j = 1; j <= lookback; j++)
      {
         if(rates[i - j].high >= highVal || rates[i + j].high >= highVal)
         {
            isSwing = false;
            break;
         }
      }

      if(isSwing)
      {
         swingBar = i;
         return true;
      }
   }
   return false;
}

//+------------------------------------------------------------------+
//| Find swing lows in price data                                      |
//+------------------------------------------------------------------+
bool FindSwingLow(int startBar, int endBar, int lookback, int &swingBar)
{
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   int copied = CopyRates(_Symbol, PERIOD_M5, 0, endBar + lookback + 5, rates);
   if(copied <= 0) return false;

   for(int i = startBar; i <= endBar; i++)
   {
      if(i < lookback || i + lookback >= copied) continue;

      bool isSwing = true;
      double lowVal = rates[i].low;

      for(int j = 1; j <= lookback; j++)
      {
         if(rates[i - j].low <= lowVal || rates[i + j].low <= lowVal)
         {
            isSwing = false;
            break;
         }
      }

      if(isSwing)
      {
         swingBar = i;
         return true;
      }
   }
   return false;
}

//+------------------------------------------------------------------+
//| Find all swing highs within a range                                |
//+------------------------------------------------------------------+
int FindAllSwingHighs(int startBar, int endBar, int lookback, int &swingBars[], int maxSwings = 10)
{
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   int copied = CopyRates(_Symbol, PERIOD_M5, 0, endBar + lookback + 5, rates);
   if(copied <= 0) return 0;

   ArrayResize(swingBars, 0);
   int count = 0;

   for(int i = startBar; i <= endBar && count < maxSwings; i++)
   {
      if(i < lookback || i + lookback >= copied) continue;

      bool isSwing = true;
      double highVal = rates[i].high;

      for(int j = 1; j <= lookback; j++)
      {
         if(rates[i - j].high >= highVal || rates[i + j].high >= highVal)
         {
            isSwing = false;
            break;
         }
      }

      if(isSwing)
      {
         ArrayResize(swingBars, count + 1);
         swingBars[count] = i;
         count++;
      }
   }
   return count;
}

//+------------------------------------------------------------------+
//| Find all swing lows within a range                                 |
//+------------------------------------------------------------------+
int FindAllSwingLows(int startBar, int endBar, int lookback, int &swingBars[], int maxSwings = 10)
{
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   int copied = CopyRates(_Symbol, PERIOD_M5, 0, endBar + lookback + 5, rates);
   if(copied <= 0) return 0;

   ArrayResize(swingBars, 0);
   int count = 0;

   for(int i = startBar; i <= endBar && count < maxSwings; i++)
   {
      if(i < lookback || i + lookback >= copied) continue;

      bool isSwing = true;
      double lowVal = rates[i].low;

      for(int j = 1; j <= lookback; j++)
      {
         if(rates[i - j].low <= lowVal || rates[i + j].low <= lowVal)
         {
            isSwing = false;
            break;
         }
      }

      if(isSwing)
      {
         ArrayResize(swingBars, count + 1);
         swingBars[count] = i;
         count++;
      }
   }
   return count;
}

//+------------------------------------------------------------------+
//| Check for bearish engulfing pattern                                |
//+------------------------------------------------------------------+
bool IsBearishEngulfing(int barIndex)
{
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   if(CopyRates(_Symbol, PERIOD_M5, 0, barIndex + 2, rates) <= 0) return false;

   // Bar at barIndex is the engulfing candle (just closed)
   // Bar at barIndex+1 is the previous candle
   double currOpen  = rates[barIndex].open;
   double currClose = rates[barIndex].close;
   double prevOpen  = rates[barIndex + 1].open;
   double prevClose = rates[barIndex + 1].close;

   // Current candle must be bearish
   if(currClose >= currOpen) return false;

   // Previous candle must be bullish
   if(prevClose <= prevOpen) return false;

   // Current body engulfs previous body
   if(currOpen >= prevClose && currClose <= prevOpen)
      return true;

   return false;
}

//+------------------------------------------------------------------+
//| Check for bullish engulfing pattern                                |
//+------------------------------------------------------------------+
bool IsBullishEngulfing(int barIndex)
{
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   if(CopyRates(_Symbol, PERIOD_M5, 0, barIndex + 2, rates) <= 0) return false;

   double currOpen  = rates[barIndex].open;
   double currClose = rates[barIndex].close;
   double prevOpen  = rates[barIndex + 1].open;
   double prevClose = rates[barIndex + 1].close;

   // Current candle must be bullish
   if(currClose <= currOpen) return false;

   // Previous candle must be bearish
   if(prevClose >= prevOpen) return false;

   // Current body engulfs previous body
   if(currClose >= prevOpen && currOpen <= prevClose)
      return true;

   return false;
}

//+------------------------------------------------------------------+
//| Check H1 trend direction                                           |
//+------------------------------------------------------------------+
int GetH1Trend()
{
   if(!InpUseTrendFilter) return 0; // No filter = any direction

   double closeH1 = iClose(_Symbol, PERIOD_H1, 1);
   double emaVal   = emaH1Buffer[1];

   if(closeH1 > emaVal) return 1;   // Bullish
   if(closeH1 < emaVal) return -1;  // Bearish
   return 0;
}

//+------------------------------------------------------------------+
//| Detect bearish divergence (price HH, RSI LH)                      |
//+------------------------------------------------------------------+
bool DetectBearishDivergence()
{
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   int copied = CopyRates(_Symbol, PERIOD_M5, 0, InpDivergenceWindow + InpSwingLookback + 5, rates);
   if(copied <= 0) return false;

   // Find swing highs in price
   int swingHighBars[];
   int numSwings = FindAllSwingHighs(InpSwingLookback + 1, InpDivergenceWindow, InpSwingLookback, swingHighBars, 10);
   if(numSwings < 2) return false;

   // Check pairs of swing highs for divergence
   for(int i = 0; i < numSwings - 1; i++)
   {
      int recentBar = swingHighBars[i];    // More recent swing high
      int olderBar  = swingHighBars[i + 1]; // Older swing high

      // Recent swing must be fresh
      if(recentBar > InpMaxDivAge) break;

      // Must be at least MinDivBars apart
      if(olderBar - recentBar < InpMinDivBars) continue;

      double recentHigh = rates[recentBar].high;
      double olderHigh  = rates[olderBar].high;

      // Price makes HIGHER high (recent > older)
      if(recentHigh <= olderHigh) continue;

      // RSI makes LOWER high (recent RSI < older RSI)
      double recentRSI = rsiBuffer[recentBar];
      double olderRSI  = rsiBuffer[olderBar];

      if(recentRSI >= olderRSI) continue;

      // RSI should be in overbought zone (at least one of them)
      if(InpStrictZone && olderRSI < InpRSIOverbought) continue;
      if(!InpStrictZone && recentRSI < 60 && olderRSI < InpRSIOverbought) continue;

      Print("Bearish Divergence found: Bar ", recentBar, " Price=", recentHigh,
            " RSI=", recentRSI, " vs Bar ", olderBar, " Price=", olderHigh, " RSI=", olderRSI);
      return true;
   }
   return false;
}

//+------------------------------------------------------------------+
//| Detect bullish divergence (price LL, RSI HL)                       |
//+------------------------------------------------------------------+
bool DetectBullishDivergence()
{
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   int copied = CopyRates(_Symbol, PERIOD_M5, 0, InpDivergenceWindow + InpSwingLookback + 5, rates);
   if(copied <= 0) return false;

   // Find swing lows in price
   int swingLowBars[];
   int numSwings = FindAllSwingLows(InpSwingLookback + 1, InpDivergenceWindow, InpSwingLookback, swingLowBars, 10);
   if(numSwings < 2) return false;

   // Check pairs of swing lows for divergence
   for(int i = 0; i < numSwings - 1; i++)
   {
      int recentBar = swingLowBars[i];
      int olderBar  = swingLowBars[i + 1];

      if(recentBar > InpMaxDivAge) break;

      if(olderBar - recentBar < InpMinDivBars) continue;

      double recentLow = rates[recentBar].low;
      double olderLow  = rates[olderBar].low;

      // Price makes LOWER low (recent < older)
      if(recentLow >= olderLow) continue;

      // RSI makes HIGHER low (recent RSI > older RSI)
      double recentRSI = rsiBuffer[recentBar];
      double olderRSI  = rsiBuffer[olderBar];

      if(recentRSI <= olderRSI) continue;

      // RSI should be in oversold zone (at least one of them)
      if(InpStrictZone && olderRSI > InpRSIOversold) continue;
      if(!InpStrictZone && recentRSI > 40 && olderRSI > InpRSIOversold) continue;

      Print("Bullish Divergence found: Bar ", recentBar, " Price=", recentLow,
            " RSI=", recentRSI, " vs Bar ", olderBar, " Price=", olderLow, " RSI=", olderRSI);
      return true;
   }
   return false;
}

//+------------------------------------------------------------------+
//| Find recent swing high for SL (sell setup)                         |
//+------------------------------------------------------------------+
double FindRecentSwingHigh(int maxBars = 20)
{
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   if(CopyRates(_Symbol, PERIOD_M5, 0, maxBars + InpSwingLookback + 5, rates) <= 0) return 0;

   int swingBar;
   if(FindSwingHigh(1, maxBars, InpSwingLookback, swingBar))
      return rates[swingBar].high;

   // Fallback: highest high in lookback
   double highest = 0;
   for(int i = 1; i <= maxBars; i++)
   {
      if(rates[i].high > highest) highest = rates[i].high;
   }
   return highest;
}

//+------------------------------------------------------------------+
//| Find recent swing low for SL (buy setup)                           |
//+------------------------------------------------------------------+
double FindRecentSwingLow(int maxBars = 20)
{
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   if(CopyRates(_Symbol, PERIOD_M5, 0, maxBars + InpSwingLookback + 5, rates) <= 0) return 0;

   int swingBar;
   if(FindSwingLow(1, maxBars, InpSwingLookback, swingBar))
      return rates[swingBar].low;

   // Fallback: lowest low in lookback
   double lowest = DBL_MAX;
   for(int i = 1; i <= maxBars; i++)
   {
      if(rates[i].low < lowest) lowest = rates[i].low;
   }
   return lowest;
}

//+------------------------------------------------------------------+
//| SL distance as % of price - scales with the gold price level       |
//+------------------------------------------------------------------+
bool SLPctInRange(double slDist, double price)
{
   double pct = slDist / price * 100.0;
   if(InpMinSLPct > 0 && pct < InpMinSLPct) return false;
   if(InpMaxSLPct > 0 && pct > InpMaxSLPct) return false;
   return true;
}

//+------------------------------------------------------------------+
//| Check for trading signals                                          |
//+------------------------------------------------------------------+
void CheckForSignal()
{
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   if(CopyRates(_Symbol, PERIOD_M5, 0, 5, rates) <= 0) return;

   int h1Trend = GetH1Trend();

   // Check bar index 1 (last closed bar) for engulfing pattern
   // after divergence is detected

   // --- SELL SETUP ---
   if(h1Trend <= 0)  // Allow sell if trend is bearish or no filter
   {
      if(IsBearishEngulfing(1) && DetectBearishDivergence())
      {
         double entryPrice = rates[1].low;  // Entry below the low of engulfing
         double slPrice    = FindRecentSwingHigh(20);

         // Add buffer to SL
         double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
         slPrice += 50 * point;  // Small buffer above swing high

         // Validate SL distance
         double slDistance = (slPrice - entryPrice) / point;
         if(slDistance < InpMinSLPoints || slDistance > InpMaxSLPoints || !SLPctInRange(slPrice - entryPrice, entryPrice))
         {
            Print("SL distance out of range: ", slDistance, " points");
            return;
         }

         // Place sell stop order
         datetime expiry = rates[0].time + InpPendingExpiry * PeriodSeconds(PERIOD_M5);

         if(trade.SellStop(InpLotSize, entryPrice, _Symbol, slPrice, 0, ORDER_TIME_SPECIFIED, expiry,
                           "RSI_Div_Sell"))
         {
            Print("Sell Stop placed at ", entryPrice, " SL: ", slPrice);
            lastTradeBar = Bars(_Symbol, PERIOD_M5);
         }
         else
         {
            Print("Sell Stop failed: ", trade.ResultRetcode(), " ", trade.ResultRetcodeDescription());
         }
         return;
      }
   }

   // --- BUY SETUP ---
   if(h1Trend >= 0)  // Allow buy if trend is bullish or no filter
   {
      if(IsBullishEngulfing(1) && DetectBullishDivergence())
      {
         double entryPrice = rates[1].high;  // Entry above the high of engulfing
         double slPrice    = FindRecentSwingLow(20);

         double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
         slPrice -= 50 * point;  // Small buffer below swing low

         // Validate SL distance
         double slDistance = (entryPrice - slPrice) / point;
         if(slDistance < InpMinSLPoints || slDistance > InpMaxSLPoints || !SLPctInRange(entryPrice - slPrice, entryPrice))
         {
            Print("SL distance out of range: ", slDistance, " points");
            return;
         }

         datetime expiry = rates[0].time + InpPendingExpiry * PeriodSeconds(PERIOD_M5);

         if(trade.BuyStop(InpLotSize, entryPrice, _Symbol, slPrice, 0, ORDER_TIME_SPECIFIED, expiry,
                          "RSI_Div_Buy"))
         {
            Print("Buy Stop placed at ", entryPrice, " SL: ", slPrice);
            lastTradeBar = Bars(_Symbol, PERIOD_M5);
         }
         else
         {
            Print("Buy Stop failed: ", trade.ResultRetcode(), " ", trade.ResultRetcodeDescription());
         }
         return;
      }
   }
}

//+------------------------------------------------------------------+
//| Manage open positions - RSI-based TP and breakeven                 |
//+------------------------------------------------------------------+
void ManagePositions()
{
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   double currentRSI = rsiBuffer[1]; // Last closed bar RSI

   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      if(PositionGetInteger(POSITION_MAGIC) != InpMagicNumber) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;

      long posType    = PositionGetInteger(POSITION_TYPE);
      double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
      double currentSL = PositionGetDouble(POSITION_SL);
      double volume    = PositionGetDouble(POSITION_VOLUME);
      string comment   = PositionGetString(POSITION_COMMENT);

      // Determine if TP1 was already taken by checking volume
      // Full position = InpLotSize, after TP1 partial close = smaller volume
      double expectedTP1Vol = NormalizeVolume(InpLotSize * InpTP1ClosePercent / 100.0);
      double remainingAfterTP1 = NormalizeVolume(InpLotSize - expectedTP1Vol);
      bool isTP1Done = (volume <= remainingAfterTP1 + SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP) * 0.5);

      if(posType == POSITION_TYPE_BUY)
      {
         // TP2: RSI crosses above 70 - close remaining
         if(isTP1Done && currentRSI >= InpRSITP2Buy)
         {
            if(trade.PositionClose(ticket))
            {
               Print("BUY TP2 hit (RSI=", currentRSI, "), closed remaining position");
               lastTradeBar = Bars(_Symbol, PERIOD_M5);
            }
         }

         // Trailing: if TP1 done but RSI not at TP2, trail SL using price action
         if(isTP1Done)
         {
            double recentSwingLow = FindRecentSwingLow(10);
            if(recentSwingLow > currentSL && recentSwingLow > openPrice)
            {
               double newSL = recentSwingLow - 30 * point;
               if(newSL > currentSL)
               {
                  trade.PositionModify(ticket, newSL, PositionGetDouble(POSITION_TP));
               }
            }
         }
      }
      else if(posType == POSITION_TYPE_SELL)
      {
         // TP2: RSI crosses below 30 - close remaining
         if(isTP1Done && currentRSI <= InpRSITP2Sell)
         {
            if(trade.PositionClose(ticket))
            {
               Print("SELL TP2 hit (RSI=", currentRSI, "), closed remaining position");
               lastTradeBar = Bars(_Symbol, PERIOD_M5);
            }
         }

         // Trailing for sell
         if(isTP1Done)
         {
            double recentSwingHigh = FindRecentSwingHigh(10);
            if(recentSwingHigh < currentSL && recentSwingHigh < openPrice)
            {
               double newSL = recentSwingHigh + 30 * point;
               if(newSL < currentSL)
               {
                  trade.PositionModify(ticket, newSL, PositionGetDouble(POSITION_TP));
               }
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//| TP1 at fixed R multiple - close partial, move SL to breakeven      |
//+------------------------------------------------------------------+
void ManageTP1()
{
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   double expectedTP1Vol = NormalizeVolume(InpLotSize * InpTP1ClosePercent / 100.0);
   double remainingAfterTP1 = NormalizeVolume(InpLotSize - expectedTP1Vol);

   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      if(PositionGetInteger(POSITION_MAGIC) != InpMagicNumber) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;

      double volume = PositionGetDouble(POSITION_VOLUME);
      if(volume <= remainingAfterTP1 + SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP) * 0.5) continue;

      long   posType   = PositionGetInteger(POSITION_TYPE);
      double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
      double sl        = PositionGetDouble(POSITION_SL);
      if(sl == 0) continue;

      // SL is still the initial stop before TP1, so it defines 1R
      double risk = MathAbs(openPrice - sl);
      double closeVol = NormalizeVolume(volume * InpTP1ClosePercent / 100.0);

      if(posType == POSITION_TYPE_BUY)
      {
         double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
         if(bid < openPrice + InpTP1RR * risk) continue;
         if(trade.PositionClosePartial(ticket, closeVol))
         {
            double tp = InpTP2RR > 0 ? openPrice + InpTP2RR * risk : 0;
            trade.PositionModify(ticket, openPrice + 10 * point, tp);
         }
      }
      else
      {
         double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
         if(ask > openPrice - InpTP1RR * risk) continue;
         if(trade.PositionClosePartial(ticket, closeVol))
         {
            double tp = InpTP2RR > 0 ? openPrice - InpTP2RR * risk : 0;
            trade.PositionModify(ticket, openPrice - 10 * point, tp);
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Manage pending orders - remove expired ones                        |
//+------------------------------------------------------------------+
void ManagePendingOrders()
{
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      ulong ticket = OrderGetTicket(i);
      if(ticket == 0) continue;
      if(OrderGetInteger(ORDER_MAGIC) != InpMagicNumber) continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol) continue;

      // Orders with TIME_SPECIFIED expiry are auto-cancelled by MT5
      // But double-check stale orders
      datetime orderTime = (datetime)OrderGetInteger(ORDER_TIME_SETUP);
      datetime now = TimeCurrent();
      if(now - orderTime > InpPendingExpiry * PeriodSeconds(PERIOD_M5) * 2)
      {
         trade.OrderDelete(ticket);
         Print("Deleted stale pending order: ", ticket);
      }
   }
}

//+------------------------------------------------------------------+
//| Count open positions                                               |
//+------------------------------------------------------------------+
int CountPositions()
{
   int count = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      if(PositionGetInteger(POSITION_MAGIC) != InpMagicNumber) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      count++;
   }
   return count;
}

//+------------------------------------------------------------------+
//| Count pending orders                                               |
//+------------------------------------------------------------------+
int CountPendingOrders()
{
   int count = 0;
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      ulong ticket = OrderGetTicket(i);
      if(ticket == 0) continue;
      if(OrderGetInteger(ORDER_MAGIC) != InpMagicNumber) continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol) continue;
      count++;
   }
   return count;
}

//+------------------------------------------------------------------+
//| Normalize volume to valid lot step                                 |
//+------------------------------------------------------------------+
double NormalizeVolume(double volume)
{
   double minVol  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxVol  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double stepVol = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);

   if(stepVol <= 0) return 0;

   volume = MathFloor(volume / stepVol) * stepVol;
   volume = MathMax(volume, minVol);
   volume = MathMin(volume, maxVol);

   return NormalizeDouble(volume, 2);
}
//+------------------------------------------------------------------+
