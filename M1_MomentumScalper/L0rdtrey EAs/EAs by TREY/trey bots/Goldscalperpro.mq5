//+------------------------------------------------------------------+
//|                        GOLD SCALPER PRO v1.0                    |
//|                        XAU/USD   |   MT5 Expert Advisor          |
//|                                                                  |
//|  STRATEGY ENGINE (4-layer confluence):                          |
//|   1. EMA Cross     - EMA8 vs EMA21 crossover (entry trigger)    |
//|   2. Trend Filter  - EMA50 direction (bias guard)               |
//|   3. RSI           - Momentum confirmation (no overbought/sold) |
//|   4. MACD          - Histogram direction (momentum boost)       |
//|                                                                  |
//|  SL/TP: ATR-based (dynamic, adapts to volatility)              |
//|  TRAILING STOP: ATR-based, runs every tick                      |
//|  SESSION FILTER: Asian / London / New York (all enabled)        |
//|  SPREAD FILTER: Skips entries when spread is too high           |
//|                                                                  |
//|  Timeframe: M5 (recommended)                                    |
//|  Symbol:    XAUUSD / GOLD                                       |
//+------------------------------------------------------------------+
#property copyright   "Gold Scalper Pro"
#property version     "1.00"
#property description "4-strategy scalping EA for XAU/USD"
#property strict

#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>

//+------------------------------------------------------------------+
//|  INPUT PARAMETERS                                                |
//+------------------------------------------------------------------+

input group "════ TRADE SETTINGS ════"
input double   InpLotSize        = 0.01;   // Fixed Lot Size
input int      InpMagicNumber    = 20250;  // Magic Number (unique ID)
input int      InpMaxSpread      = 35;     // Max Spread in points (skip if higher)
input int      InpSlippage       = 10;     // Max Slippage in points
input int      InpMaxOpenTrades  = 1;      // Max simultaneous open trades

input group "════ INDICATOR SETTINGS ════"
input int      InpFastEMA        = 8;      // Fast EMA Period
input int      InpSlowEMA        = 21;     // Slow EMA Period
input int      InpTrendEMA       = 50;     // Trend EMA Period (direction bias)
input int      InpRSIPeriod      = 14;     // RSI Period
input int      InpMACDFast       = 12;     // MACD Fast EMA
input int      InpMACDSlow       = 26;     // MACD Slow EMA
input int      InpMACDSignal     = 9;      // MACD Signal Period
input int      InpATRPeriod      = 14;     // ATR Period (volatility measure)

input group "════ SL / TP / TRAILING ════"
input double   InpSLMultiplier   = 1.5;    // Stop Loss  = ATR × multiplier
input double   InpTPMultiplier   = 2.5;    // Take Profit = ATR × multiplier
input bool     InpUseTrail       = true;   // Enable Trailing Stop
input double   InpTrailMult      = 1.0;    // Trail Distance = ATR × multiplier

input group "════ SESSION FILTER (GMT) ════"
input bool     InpAsianSession   = true;   // Trade Asian Session
input bool     InpLondonSession  = true;   // Trade London Session
input bool     InpNYSession      = true;   // Trade New York Session
input int      InpAsianStart     = 0;      // Asian  Start Hour (GMT)
input int      InpAsianEnd       = 9;      // Asian  End   Hour (GMT)
input int      InpLondonStart    = 8;      // London Start Hour (GMT)
input int      InpLondonEnd      = 17;     // London End   Hour (GMT)
input int      InpNYStart        = 13;     // NY     Start Hour (GMT)
input int      InpNYEnd          = 22;     // NY     End   Hour (GMT)

input group "════ MARKET QUALITY FILTER ════"
input double   InpMinATRPoints   = 80;     // Min ATR in points (skip dead market)

//+------------------------------------------------------------------+
//|  GLOBAL VARIABLES                                                |
//+------------------------------------------------------------------+
CTrade    trade;

// Indicator handles
int       hEMAFast, hEMASlow, hEMATrend;
int       hRSI, hMACD, hATR;

// Indicator buffers
double    bEMAFast[],  bEMASlow[],  bEMATrend[];
double    bRSI[];
double    bMACDMain[], bMACDSig[];
double    bATR[];

// Bar tracking (entry fires once per bar)
datetime  g_lastBarTime = 0;

//+------------------------------------------------------------------+
//|  INIT                                                            |
//+------------------------------------------------------------------+
int OnInit()
{
   // Configure trade object
   trade.SetExpertMagicNumber(InpMagicNumber);
   trade.SetDeviationInPoints(InpSlippage);
   trade.SetTypeFilling(ORDER_FILLING_IOC);
   trade.LogLevel(LOG_LEVEL_ERRORS);

   // Create indicator handles on M5
   hEMAFast  = iMA    (_Symbol, PERIOD_M5, InpFastEMA,   0, MODE_EMA, PRICE_CLOSE);
   hEMASlow  = iMA    (_Symbol, PERIOD_M5, InpSlowEMA,   0, MODE_EMA, PRICE_CLOSE);
   hEMATrend = iMA    (_Symbol, PERIOD_M5, InpTrendEMA,  0, MODE_EMA, PRICE_CLOSE);
   hRSI      = iRSI   (_Symbol, PERIOD_M5, InpRSIPeriod, PRICE_CLOSE);
   hMACD     = iMACD  (_Symbol, PERIOD_M5, InpMACDFast, InpMACDSlow, InpMACDSignal, PRICE_CLOSE);
   hATR      = iATR   (_Symbol, PERIOD_M5, InpATRPeriod);

   // Validate handles
   if(hEMAFast  == INVALID_HANDLE ||
      hEMASlow  == INVALID_HANDLE ||
      hEMATrend == INVALID_HANDLE ||
      hRSI      == INVALID_HANDLE ||
      hMACD     == INVALID_HANDLE ||
      hATR      == INVALID_HANDLE)
   {
      Alert("GOLD SCALPER PRO: Failed to create indicator handles. Check symbol/broker.");
      return INIT_FAILED;
   }

   // Set all buffers to series mode (index 0 = newest bar)
   ArraySetAsSeries(bEMAFast,  true);
   ArraySetAsSeries(bEMASlow,  true);
   ArraySetAsSeries(bEMATrend, true);
   ArraySetAsSeries(bRSI,      true);
   ArraySetAsSeries(bMACDMain, true);
   ArraySetAsSeries(bMACDSig,  true);
   ArraySetAsSeries(bATR,      true);

   Print("====================================");
   Print("  GOLD SCALPER PRO v1.0 - STARTED  ");
   Print("  Symbol  : ", _Symbol);
   Print("  Lot     : ", InpLotSize);
   Print("  Magic   : ", InpMagicNumber);
   Print("  SL Mult : ", InpSLMultiplier, "x ATR");
   Print("  TP Mult : ", InpTPMultiplier, "x ATR");
   Print("====================================");

   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//|  DEINIT                                                          |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   IndicatorRelease(hEMAFast);
   IndicatorRelease(hEMASlow);
   IndicatorRelease(hEMATrend);
   IndicatorRelease(hRSI);
   IndicatorRelease(hMACD);
   IndicatorRelease(hATR);
   Print("Gold Scalper Pro deinitialized.");
}

//+------------------------------------------------------------------+
//|  MAIN TICK FUNCTION                                              |
//+------------------------------------------------------------------+
void OnTick()
{
   //--- TRAILING STOP runs every tick (not bar-locked)
   if(InpUseTrail)
      RunTrailingStop();

   //--- Entry logic: only once per completed M5 bar
   datetime barTime = iTime(_Symbol, PERIOD_M5, 0);
   if(barTime == g_lastBarTime)
      return;
   g_lastBarTime = barTime;

   //--- SPREAD FILTER
   long currentSpread = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   if(currentSpread > InpMaxSpread)
   {
      PrintFormat("Spread filter: %d pts > max %d. Skipping.", currentSpread, InpMaxSpread);
      return;
   }

   //--- SESSION FILTER
   if(!IsSessionActive())
      return;

   //--- MAX TRADES FILTER
   if(CountMyTrades() >= InpMaxOpenTrades)
      return;

   //--- LOAD INDICATORS
   if(!LoadIndicators())
      return;

   //--- ATR FILTER (dead market guard)
   double atr = bATR[1];
   if(atr / _Point < InpMinATRPoints)
   {
      PrintFormat("ATR filter: %.2f pts < min %d. Market too quiet.", atr / _Point, InpMinATRPoints);
      return;
   }

   //--- GET SIGNAL
   int sig = GetSignal();

   //--- EXECUTE
   if(sig ==  1) ExecuteBuy(atr);
   if(sig == -1) ExecuteSell(atr);
}

//+------------------------------------------------------------------+
//|  LOAD INDICATOR BUFFERS                                          |
//|  Uses bar[1] = last confirmed closed bar (safe, no repainting)  |
//+------------------------------------------------------------------+
bool LoadIndicators()
{
   if(CopyBuffer(hEMAFast,  0, 0, 3, bEMAFast)  < 3) { Print("EMA Fast buffer error");  return false; }
   if(CopyBuffer(hEMASlow,  0, 0, 3, bEMASlow)  < 3) { Print("EMA Slow buffer error");  return false; }
   if(CopyBuffer(hEMATrend, 0, 0, 3, bEMATrend) < 3) { Print("EMA Trend buffer error"); return false; }
   if(CopyBuffer(hRSI,      0, 0, 3, bRSI)      < 3) { Print("RSI buffer error");       return false; }
   if(CopyBuffer(hMACD,     0, 0, 3, bMACDMain) < 3) { Print("MACD main buffer error"); return false; }
   if(CopyBuffer(hMACD,     1, 0, 3, bMACDSig)  < 3) { Print("MACD sig buffer error");  return false; }
   if(CopyBuffer(hATR,      0, 0, 3, bATR)      < 3) { Print("ATR buffer error");       return false; }
   return true;
}

//+------------------------------------------------------------------+
//|  SIGNAL ENGINE — 4-STRATEGY CONFLUENCE                          |
//|                                                                  |
//|  Uses last CLOSED bar [1] to avoid live-bar noise               |
//|                                                                  |
//|  BUY  conditions:                                               |
//|   [2pts] EMA8 crossed ABOVE EMA21                               |
//|   [1pt]  Price above EMA50 (bullish trend)                      |
//|   [1pt]  RSI between 50–70 (bullish, not overbought)            |
//|   [1pt]  MACD line above Signal line                            |
//|   Needs: cross confirmed + total score >= 4                     |
//|                                                                  |
//|  SELL conditions (mirror logic)                                 |
//+------------------------------------------------------------------+
int GetSignal()
{
   // Read confirmed values from last closed bar
   double emaFast_c  = bEMAFast[1];
   double emaFast_p  = bEMAFast[2];   // previous bar
   double emaSlow_c  = bEMASlow[1];
   double emaSlow_p  = bEMASlow[2];
   double emaTrend   = bEMATrend[1];
   double rsi        = bRSI[1];
   double macdMain   = bMACDMain[1];
   double macdSig    = bMACDSig[1];
   double closePrice = iClose(_Symbol, PERIOD_M5, 1);

   //--- Strategy 1: EMA Cross (the trigger — worth 2 points)
   bool emaCrossBuy  = (emaFast_p < emaSlow_p) && (emaFast_c > emaSlow_c);
   bool emaCrossSell = (emaFast_p > emaSlow_p) && (emaFast_c < emaSlow_c);

   //--- Strategy 2: EMA50 Trend Filter
   bool trendBull = closePrice > emaTrend;
   bool trendBear = closePrice < emaTrend;

   //--- Strategy 3: RSI Momentum (mid-zone only — avoid extremes)
   bool rsiBull = (rsi > 50.0 && rsi < 72.0);
   bool rsiBear = (rsi < 50.0 && rsi > 28.0);

   //--- Strategy 4: MACD Direction
   bool macdBull = (macdMain > macdSig);
   bool macdBear = (macdMain < macdSig);

   //--- Confluence Score
   int buyScore  = (emaCrossBuy  ? 2 : 0) + (trendBull ? 1 : 0) + (rsiBull ? 1 : 0) + (macdBull ? 1 : 0);
   int sellScore = (emaCrossSell ? 2 : 0) + (trendBear ? 1 : 0) + (rsiBear ? 1 : 0) + (macdBear ? 1 : 0);

   // Require EMA cross + at least 2 confirmations (score >= 4 out of 5 max)
   if(emaCrossBuy  && buyScore  >= 4)
   {
      PrintFormat("BUY SIGNAL | EMA cross + Score:%d | RSI:%.1f | MACD:%.5f | Trend:%s",
                  buyScore, rsi, macdMain - macdSig, trendBull ? "BULL" : "WEAK");
      return 1;
   }
   if(emaCrossSell && sellScore >= 4)
   {
      PrintFormat("SELL SIGNAL | EMA cross + Score:%d | RSI:%.1f | MACD:%.5f | Trend:%s",
                  sellScore, rsi, macdMain - macdSig, trendBear ? "BEAR" : "WEAK");
      return -1;
   }

   return 0;
}

//+------------------------------------------------------------------+
//|  EXECUTE BUY                                                     |
//+------------------------------------------------------------------+
void ExecuteBuy(double atr)
{
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double sl  = NormalizeDouble(ask - (atr * InpSLMultiplier), _Digits);
   double tp  = NormalizeDouble(ask + (atr * InpTPMultiplier), _Digits);

   bool result = trade.Buy(InpLotSize, _Symbol, ask, sl, tp, "GSP-BUY");

   if(result)
      PrintFormat("✅ BUY OPENED | Price:%.2f | SL:%.2f | TP:%.2f | ATR:%.2f", ask, sl, tp, atr);
   else
      PrintFormat("❌ BUY FAILED | %s", trade.ResultRetcodeDescription());
}

//+------------------------------------------------------------------+
//|  EXECUTE SELL                                                    |
//+------------------------------------------------------------------+
void ExecuteSell(double atr)
{
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double sl  = NormalizeDouble(bid + (atr * InpSLMultiplier), _Digits);
   double tp  = NormalizeDouble(bid - (atr * InpTPMultiplier), _Digits);

   bool result = trade.Sell(InpLotSize, _Symbol, bid, sl, tp, "GSP-SELL");

   if(result)
      PrintFormat("✅ SELL OPENED | Price:%.2f | SL:%.2f | TP:%.2f | ATR:%.2f", bid, sl, tp, atr);
   else
      PrintFormat("❌ SELL FAILED | %s", trade.ResultRetcodeDescription());
}

//+------------------------------------------------------------------+
//|  TRAILING STOP — runs every tick                                 |
//|  Moves SL behind price as trade profits                         |
//+------------------------------------------------------------------+
void RunTrailingStop()
{
   // Need fresh ATR on every tick
   double tmpATR[2];
   ArraySetAsSeries(tmpATR, true);
   if(CopyBuffer(hATR, 0, 0, 2, tmpATR) < 2) return;

   double trailDist = tmpATR[1] * InpTrailMult;

   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))           continue;
      if(PositionGetString(POSITION_SYMBOL)  != _Symbol)         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != InpMagicNumber) continue;

      double currentSL = PositionGetDouble(POSITION_SL);
      double currentTP = PositionGetDouble(POSITION_TP);
      ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);

      if(posType == POSITION_TYPE_BUY)
      {
         double bid   = SymbolInfoDouble(_Symbol, SYMBOL_BID);
         double newSL = NormalizeDouble(bid - trailDist, _Digits);
         // Only move SL upward (never backward)
         if(newSL > currentSL + _Point)
            trade.PositionModify(ticket, newSL, currentTP);
      }
      else if(posType == POSITION_TYPE_SELL)
      {
         double ask   = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
         double newSL = NormalizeDouble(ask + trailDist, _Digits);
         // Only move SL downward (never backward)
         if(currentSL == 0 || newSL < currentSL - _Point)
            trade.PositionModify(ticket, newSL, currentTP);
      }
   }
}

//+------------------------------------------------------------------+
//|  COUNT OPEN TRADES for this EA on this symbol                   |
//+------------------------------------------------------------------+
int CountMyTrades()
{
   int count = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket)) continue;
      if(PositionGetString(POSITION_SYMBOL) == _Symbol &&
         (int)PositionGetInteger(POSITION_MAGIC) == InpMagicNumber)
         count++;
   }
   return count;
}

//+------------------------------------------------------------------+
//|  SESSION FILTER — checks current GMT hour                       |
//+------------------------------------------------------------------+
bool IsSessionActive()
{
   MqlDateTime dt;
   TimeGMT(dt);
   int h = dt.hour;

   bool asian  = InpAsianSession  && (h >= InpAsianStart  && h < InpAsianEnd);
   bool london = InpLondonSession && (h >= InpLondonStart && h < InpLondonEnd);
   bool ny     = InpNYSession     && (h >= InpNYStart     && h < InpNYEnd);

   if(asian || london || ny)
      return true;

   return false;
}
//+------------------------------------------------------------------+
//|  END OF FILE                                                     |
//+------------------------------------------------------------------+