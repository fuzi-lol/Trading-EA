//+------------------------------------------------------------------+
//|                                         EMA_VWAP_Scalper.mq5     |
//|          EMA Crossover + VWAP + ATR + ADX Scalping Strategy      |
//+------------------------------------------------------------------+
//| ENTRY:                                                           |
//|   BUY:  EMA fast > slow crossover + Price > VWAP + ADX > thresh  |
//|   SELL: EMA fast < slow crossover + Price < VWAP + ADX > thresh  |
//| FILTERS:                                                         |
//|   - ATR must be above its MA (volatility expanding)              |
//|   - ADX > 20 (trending market)                                   |
//|   - BB width above threshold (not squeezing/consolidating)       |
//|   - RSI not extreme (avoid chasing)                              |
//| EXIT:                                                            |
//|   - SL: ATR-based, TP: RR-based, Trailing after 1R              |
//+------------------------------------------------------------------+
#property copyright "EMA VWAP Scalper"
#property version   "1.00"
#property strict

#include <Trade\Trade.mqh>

//--- Inputs
input group "=== EMA Settings ==="
input int     FastEMA          = 9;         // Fast EMA period
input int     SlowEMA          = 21;        // Slow EMA period
input int     TrendEMA         = 50;        // Trend EMA (higher TF filter)
input ENUM_TIMEFRAMES TrendTF  = PERIOD_M5; // Trend EMA timeframe

input group "=== VWAP ==="
input bool    UseVWAP          = true;      // Use VWAP filter
input bool    VWAPAsEntry      = false;     // Use VWAP crossback as entry (stricter)

input group "=== Consolidation Filters ==="
input int     ADX_Period       = 14;        // ADX period
input int     ADX_Threshold    = 20;        // Min ADX for trend (below = consolidation)
input int     ATR_Period       = 14;        // ATR period
input int     ATR_MA_Period    = 50;        // ATR moving average period
input double  ATR_MinRatio     = 1.0;       // Min ATR/ATR_MA ratio (1.0 = ATR above its MA)
input int     BB_Period        = 20;        // Bollinger Band period
input double  BB_MinWidth      = 0.0015;    // Min BB width as % of price
input int     RSI_Period       = 14;        // RSI period
input int     RSI_OB           = 75;        // RSI overbought (skip buy above)
input int     RSI_OS           = 25;        // RSI oversold (skip sell below)

input group "=== Risk Management ==="
input bool    UseFixedLot      = false;     // Use fixed lot size
input double  FixedLot         = 0.10;      // Fixed lot size
input double  RiskPercent      = 0.5;       // Risk % per trade
input double  SL_ATR_Multi     = 1.5;       // SL = ATR x multiplier
input double  RiskReward       = 2.0;       // Risk:Reward ratio
input bool    UseTrailing      = true;      // Trail after 1R profit
input int     TrailPoints      = 100;       // Trailing distance (points)

input group "=== Session Filter ==="
input int     StartHour        = 9;         // Trading start (server)
input int     EndHour          = 19;        // Trading end (server)

input group "=== General ==="
input int     MaxTradesPerDay  = 4;         // Max trades per day
input int     CooldownBars     = 5;         // Min bars between trades
input int     MagicNumber      = 888200;    // Magic number

CTrade trade;

//--- Indicator handles
int h_fastEMA, h_slowEMA, h_trendEMA;
int h_adx, h_atr, h_bb, h_rsi;

//--- State
datetime g_lastDay        = 0;
int      g_dailyTrades    = 0;
datetime g_lastM1Bar      = 0;
int      g_barsSinceTrade = 999;
bool     g_inTrade        = false;
double   g_tradeEntry     = 0;
double   g_tradeSL        = 0;
bool     g_trailingActive = false;

//--- VWAP
double   g_vwap           = 0;
double   g_cumPV          = 0;  // cumulative price*volume
double   g_cumVol         = 0;  // cumulative volume
datetime g_vwapDay        = 0;

//--- EMA cross tracking
double   g_prevFast       = 0;
double   g_prevSlow       = 0;

//+------------------------------------------------------------------+
int OnInit()
{
   trade.SetExpertMagicNumber(MagicNumber);
   trade.SetTypeFillingBySymbol(_Symbol);

   h_fastEMA  = iMA(_Symbol, PERIOD_M1, FastEMA, 0, MODE_EMA, PRICE_CLOSE);
   h_slowEMA  = iMA(_Symbol, PERIOD_M1, SlowEMA, 0, MODE_EMA, PRICE_CLOSE);
   h_trendEMA = iMA(_Symbol, TrendTF, TrendEMA, 0, MODE_EMA, PRICE_CLOSE);
   h_adx      = iADX(_Symbol, PERIOD_M1, ADX_Period);
   h_atr      = iATR(_Symbol, PERIOD_M1, ATR_Period);
   h_bb       = iBands(_Symbol, PERIOD_M1, BB_Period, 0, 2.0, PRICE_CLOSE);
   h_rsi      = iRSI(_Symbol, PERIOD_M1, RSI_Period, PRICE_CLOSE);

   if(h_fastEMA == INVALID_HANDLE || h_slowEMA == INVALID_HANDLE ||
      h_trendEMA == INVALID_HANDLE || h_adx == INVALID_HANDLE ||
      h_atr == INVALID_HANDLE || h_bb == INVALID_HANDLE ||
      h_rsi == INVALID_HANDLE)
   {
      Print("Failed to create indicator handles!");
      return(INIT_FAILED);
   }

   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   IndicatorRelease(h_fastEMA);
   IndicatorRelease(h_slowEMA);
   IndicatorRelease(h_trendEMA);
   IndicatorRelease(h_adx);
   IndicatorRelease(h_atr);
   IndicatorRelease(h_bb);
   IndicatorRelease(h_rsi);
}

//+------------------------------------------------------------------+
void OnTick()
{
   MqlDateTime dt;
   TimeCurrent(dt);
   datetime today = TimeCurrent() - dt.hour*3600 - dt.min*60 - dt.sec;

   if(today != g_lastDay)
   {
      g_lastDay = today;
      g_dailyTrades = 0;
   }

   //--- Manage position
   if(g_inTrade)
   {
      if(!HasPosition())
      {
         g_inTrade = false;
         g_trailingActive = false;
         g_barsSinceTrade = 0;
      }
      else if(UseTrailing)
      {
         ManageTrailing();
      }
      return;
   }

   //--- Process on new M1 bar only
   datetime curM1 = iTime(_Symbol, PERIOD_M1, 0);
   if(curM1 == g_lastM1Bar) return;
   g_lastM1Bar = curM1;
   g_barsSinceTrade++;

   //--- Basic filters
   if(g_dailyTrades >= MaxTradesPerDay) return;
   if(dt.hour < StartHour || dt.hour >= EndHour) return;
   if(g_barsSinceTrade < CooldownBars) return;

   //--- Calculate VWAP
   if(UseVWAP)
      CalcVWAP(today);

   //--- Check for entry signal
   CheckEntry();
}

//+------------------------------------------------------------------+
void CalcVWAP(datetime today)
{
   // Reset VWAP at start of new day
   if(today != g_vwapDay)
   {
      g_vwapDay = today;
      g_cumPV  = 0;
      g_cumVol = 0;
      g_vwap   = 0;
   }

   // Calculate VWAP from today's M1 bars
   // Only recalc on new bar (efficient)
   double close1 = iClose(_Symbol, PERIOD_M1, 1);
   double high1  = iHigh(_Symbol, PERIOD_M1, 1);
   double low1   = iLow(_Symbol, PERIOD_M1, 1);
   long   vol1   = iVolume(_Symbol, PERIOD_M1, 1);

   if(vol1 <= 0) vol1 = 1;  // avoid division by zero

   double typicalPrice = (high1 + low1 + close1) / 3.0;
   g_cumPV  += typicalPrice * (double)vol1;
   g_cumVol += (double)vol1;

   if(g_cumVol > 0)
      g_vwap = g_cumPV / g_cumVol;
}

//+------------------------------------------------------------------+
void CheckEntry()
{
   //--- Get indicator values
   double fast[2], slow[2], trend[1], adx[1], atr[1], rsi[1];
   double bbUpper[1], bbLower[1], bbMid[1];

   if(CopyBuffer(h_fastEMA, 0, 1, 2, fast) < 2) return;
   if(CopyBuffer(h_slowEMA, 0, 1, 2, slow) < 2) return;
   if(CopyBuffer(h_trendEMA, 0, 1, 1, trend) < 1) return;
   if(CopyBuffer(h_adx, 0, 1, 1, adx) < 1) return;
   if(CopyBuffer(h_atr, 0, 1, 1, atr) < 1) return;
   if(CopyBuffer(h_rsi, 0, 1, 1, rsi) < 1) return;
   if(CopyBuffer(h_bb, 1, 1, 1, bbUpper) < 1) return;  // upper band
   if(CopyBuffer(h_bb, 2, 1, 1, bbLower) < 1) return;  // lower band

   double close1 = iClose(_Symbol, PERIOD_M1, 1);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);

   // Current and previous EMA values (for crossover detection)
   double curFast  = fast[1];   // bar 1 (last closed)
   double curSlow  = slow[1];
   double prevFast = fast[0];   // bar 2
   double prevSlow = slow[0];

   //=== CONSOLIDATION FILTERS ===

   // Filter 1: ADX must be above threshold (trending)
   if(adx[0] < ADX_Threshold)
      return;

   // Filter 2: ATR must be above its MA (volatility expanding)
   double atrValues[50];
   if(CopyBuffer(h_atr, 0, 1, ATR_MA_Period, atrValues) < ATR_MA_Period) return;
   double atrMA = 0;
   for(int i = 0; i < ATR_MA_Period; i++) atrMA += atrValues[i];
   atrMA /= ATR_MA_Period;

   if(atr[0] < atrMA * ATR_MinRatio)
      return;

   // Filter 3: Bollinger Band width (not squeezing)
   double bbWidth = (bbUpper[0] - bbLower[0]) / bid;
   if(bbWidth < BB_MinWidth)
      return;

   // Filter 4: RSI not at extremes
   bool rsiOK_buy  = rsi[0] < RSI_OB;
   bool rsiOK_sell = rsi[0] > RSI_OS;

   //=== CROSSOVER DETECTION ===
   bool bullCross = (prevFast <= prevSlow) && (curFast > curSlow);
   bool bearCross = (prevFast >= prevSlow) && (curFast < curSlow);

   //=== TREND FILTER (M5 EMA 50) ===
   bool upTrend   = bid > trend[0];
   bool downTrend = bid < trend[0];

   //=== VWAP FILTER ===
   bool vwapBullish = true;
   bool vwapBearish = true;
   if(UseVWAP && g_vwap > 0)
   {
      vwapBullish = bid > g_vwap;
      vwapBearish = bid < g_vwap;
   }

   //=== ENTRY SIGNALS ===

   // BUY: bullish cross + above VWAP + uptrend + RSI not overbought
   if(bullCross && upTrend && vwapBullish && rsiOK_buy)
   {
      double sl = atr[0] * SL_ATR_Multi;
      ExecuteBuy(sl);
   }

   // SELL: bearish cross + below VWAP + downtrend + RSI not oversold
   if(bearCross && downTrend && vwapBearish && rsiOK_sell)
   {
      double sl = atr[0] * SL_ATR_Multi;
      ExecuteSell(sl);
   }
}

//+------------------------------------------------------------------+
void ExecuteBuy(double atrSL)
{
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double sl  = ask - atrSL;
   double tp  = ask + atrSL * RiskReward;
   double slDist = atrSL;

   double lot = CalcLotSize(slDist);
   if(lot <= 0) return;

   if(trade.Buy(lot, _Symbol, ask, sl, tp, "EVS Buy"))
   {
      g_inTrade = true;
      g_tradeEntry = ask;
      g_tradeSL = sl;
      g_trailingActive = false;
      g_dailyTrades++;
      g_barsSinceTrade = 0;
      Print("BUY! Lot=", lot, " Entry=", ask, " SL=", sl, " TP=", tp,
            " ATR_SL=", NormalizeDouble(atrSL/_Point, 0), "pts",
            " VWAP=", NormalizeDouble(g_vwap, _Digits));
   }
}

//+------------------------------------------------------------------+
void ExecuteSell(double atrSL)
{
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double sl  = bid + atrSL;
   double tp  = bid - atrSL * RiskReward;
   double slDist = atrSL;

   double lot = CalcLotSize(slDist);
   if(lot <= 0) return;

   if(trade.Sell(lot, _Symbol, bid, sl, tp, "EVS Sell"))
   {
      g_inTrade = true;
      g_tradeEntry = bid;
      g_tradeSL = sl;
      g_trailingActive = false;
      g_dailyTrades++;
      g_barsSinceTrade = 0;
      Print("SELL! Lot=", lot, " Entry=", bid, " SL=", sl, " TP=", tp,
            " ATR_SL=", NormalizeDouble(atrSL/_Point, 0), "pts",
            " VWAP=", NormalizeDouble(g_vwap, _Digits));
   }
}

//+------------------------------------------------------------------+
void ManageTrailing()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(PositionGetSymbol(i) != _Symbol) continue;
      if(PositionGetInteger(POSITION_MAGIC) != MagicNumber) continue;

      ulong  ticket = PositionGetInteger(POSITION_TICKET);
      double openP  = PositionGetDouble(POSITION_PRICE_OPEN);
      long   pType  = PositionGetInteger(POSITION_TYPE);
      double curSL  = PositionGetDouble(POSITION_SL);
      double curTP  = PositionGetDouble(POSITION_TP);
      double slDist = MathAbs(openP - g_tradeSL);
      double trail  = TrailPoints * _Point;

      double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);

      if(pType == POSITION_TYPE_BUY)
      {
         if(bid >= openP + slDist && !g_trailingActive)
         {
            g_trailingActive = true;
            double newSL = bid - trail;
            if(newSL > curSL)
               trade.PositionModify(ticket, newSL, curTP);
         }
         else if(g_trailingActive)
         {
            double newSL = bid - trail;
            if(newSL > curSL)
               trade.PositionModify(ticket, newSL, curTP);
         }
      }
      else
      {
         if(ask <= openP - slDist && !g_trailingActive)
         {
            g_trailingActive = true;
            double newSL = ask + trail;
            if(newSL < curSL)
               trade.PositionModify(ticket, newSL, curTP);
         }
         else if(g_trailingActive)
         {
            double newSL = ask + trail;
            if(newSL < curSL)
               trade.PositionModify(ticket, newSL, curTP);
         }
      }
   }
}

//+------------------------------------------------------------------+
double CalcLotSize(double slDistance)
{
   if(slDistance <= 0) return 0;

   double lot;
   if(UseFixedLot)
   {
      lot = FixedLot;
   }
   else
   {
      double balance  = AccountInfoDouble(ACCOUNT_BALANCE);
      double riskAmt  = balance * RiskPercent / 100.0;
      double tickVal  = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
      double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
      if(tickVal <= 0 || tickSize <= 0) return 0;
      lot = riskAmt / ((slDistance / tickSize) * tickVal);
   }

   double minLot  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxLot  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   lot = MathFloor(lot / lotStep) * lotStep;
   lot = NormalizeDouble(lot, 2);
   if(lot < minLot) lot = minLot;
   if(lot > maxLot) lot = maxLot;
   return lot;
}

//+------------------------------------------------------------------+
bool HasPosition()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(PositionGetSymbol(i) != _Symbol) continue;
      if(PositionGetInteger(POSITION_MAGIC) != MagicNumber) continue;
      return true;
   }
   return false;
}
//+------------------------------------------------------------------+
