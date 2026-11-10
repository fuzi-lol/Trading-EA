//+------------------------------------------------------------------+
//|                                       MultiTF_Scalper.mq5        |
//|   Multi-Timeframe EMA Ribbon Scalper with 3 Targets              |
//|   Bias: D1 > H4 > H1 > M15 | Entry: M5 EMA retest              |
//|   Oscillators: RSI + Stochastic + MACD confluence                |
//|   3 partial TPs + trailing stop                                  |
//+------------------------------------------------------------------+

#property version   "1.00"
#property strict

#include <Trade\Trade.mqh>

//=== INPUTS =========================================================
//--- EMA Ribbon (Entry TF = M5)
input int      EMA_Fast         = 8;        // Fast EMA (ribbon top)
input int      EMA_Mid          = 21;       // Mid EMA (signal)
input int      EMA_Slow         = 50;       // Slow EMA (trend)

//--- Higher TF Trend EMAs
input int      HTF_EMA_Fast     = 21;       // H1/H4 fast EMA
input int      HTF_EMA_Slow     = 50;       // H1/H4 slow EMA
input int      D1_EMA           = 200;      // D1 trend EMA (institutional line)

//--- RSI
input int      RSI_Period       = 9;        // RSI period (shorter for scalping)
input int      RSI_BuyZone      = 45;       // RSI above this for buys
input int      RSI_SellZone     = 55;       // RSI below this for sells

//--- Stochastic
input int      Stoch_K          = 8;        // Stochastic %K
input int      Stoch_D          = 3;        // Stochastic %D
input int      Stoch_Slowing    = 3;        // Stochastic slowing
input int      Stoch_BuyZone    = 30;       // Stoch below this = oversold (buy zone)
input int      Stoch_SellZone   = 70;       // Stoch above this = overbought (sell zone)

//--- MACD
input int      MACD_Fast        = 12;       // MACD fast
input int      MACD_Slow        = 26;       // MACD slow
input int      MACD_Signal      = 9;        // MACD signal

//--- ATR & Risk
input int      ATR_Period       = 14;       // ATR period
input double   ATR_SL_Multi     = 1.2;      // SL = ATR * this
input double   MinSL_Pts        = 150;      // Min SL points
input double   MaxSL_Pts        = 800;      // Max SL points

//--- Triple Take Profit
input double   TP1_RR           = 1.0;      // TP1 Risk:Reward
input double   TP2_RR           = 2.0;      // TP2 Risk:Reward
input double   TP3_RR           = 3.5;      // TP3 Risk:Reward
input double   TP1_Pct          = 40;       // % of lot to close at TP1
input double   TP2_Pct          = 30;       // % of lot to close at TP2

//--- Trailing Stop (after TP1)
input double   Trail_Start_RR   = 1.0;      // Start trailing after this R
input double   Trail_Step_Pts   = 60;       // Trail step in points

//--- Session Filter (only trade profitable hours)
input int      LDN_Start        = 11;       // London window start
input int      LDN_End          = 12;       // London window end
input int      NY_Start         = 15;       // NY window start
input int      NY_End           = 17;       // NY window end
input bool     SkipTuesday      = true;     // Skip Tuesdays

//--- Trade Management
input double   LotSize          = 0.10;     // Base lot size
input int      MaxTradesPerDay  = 3;        // Max trades per day
input int      MagicNumber      = 890001;   // Magic number
input int      MaxSpreadPts     = 50;       // Max spread
input int      CooldownBars     = 6;        // Cooldown after trade

//=== GLOBALS ========================================================
CTrade   trade;

// Indicator handles - M5 (entry TF)
int      hEMA8, hEMA21, hEMA50;
int      hRSI, hStoch, hMACD, hATR;

// Higher TF handles
int      hH1_EMA21, hH1_EMA50;
int      hH4_EMA21, hH4_EMA50;
int      hD1_EMA200;
int      hM15_EMA21, hM15_EMA50;
int      hH1_RSI;

// State
datetime gDay;
int      gTradesToday;
datetime gLastTradeTime;

// Position tracking for partial closes
struct TradeInfo
{
   ulong    ticket;
   double   entryPrice;
   double   slDistance;
   bool     tp1Hit;
   bool     tp2Hit;
   int      direction;   // +1 buy, -1 sell
};

TradeInfo gTrades[10];
int       gTradeCount;

//+------------------------------------------------------------------+
int OnInit()
{
   trade.SetExpertMagicNumber(MagicNumber);
   trade.SetDeviationInPoints(30);

   // Entry indicators on M15 (less noise than M5 for gold)
   hEMA8    = iMA(_Symbol, PERIOD_M15, EMA_Fast, 0, MODE_EMA, PRICE_CLOSE);
   hEMA21   = iMA(_Symbol, PERIOD_M15, EMA_Mid, 0, MODE_EMA, PRICE_CLOSE);
   hEMA50   = iMA(_Symbol, PERIOD_M15, EMA_Slow, 0, MODE_EMA, PRICE_CLOSE);
   hRSI     = iRSI(_Symbol, PERIOD_M15, RSI_Period, PRICE_CLOSE);
   hStoch   = iStochastic(_Symbol, PERIOD_M15, Stoch_K, Stoch_D, Stoch_Slowing, MODE_SMA, STO_LOWHIGH);
   hMACD    = iMACD(_Symbol, PERIOD_M15, MACD_Fast, MACD_Slow, MACD_Signal, PRICE_CLOSE);
   hATR     = iATR(_Symbol, PERIOD_M15, ATR_Period);

   // M15
   hM15_EMA21 = iMA(_Symbol, PERIOD_M15, HTF_EMA_Fast, 0, MODE_EMA, PRICE_CLOSE);
   hM15_EMA50 = iMA(_Symbol, PERIOD_M15, HTF_EMA_Slow, 0, MODE_EMA, PRICE_CLOSE);

   // H1
   hH1_EMA21 = iMA(_Symbol, PERIOD_H1, HTF_EMA_Fast, 0, MODE_EMA, PRICE_CLOSE);
   hH1_EMA50 = iMA(_Symbol, PERIOD_H1, HTF_EMA_Slow, 0, MODE_EMA, PRICE_CLOSE);
   hH1_RSI   = iRSI(_Symbol, PERIOD_H1, 14, PRICE_CLOSE);

   // H4
   hH4_EMA21 = iMA(_Symbol, PERIOD_H4, HTF_EMA_Fast, 0, MODE_EMA, PRICE_CLOSE);
   hH4_EMA50 = iMA(_Symbol, PERIOD_H4, HTF_EMA_Slow, 0, MODE_EMA, PRICE_CLOSE);

   // D1
   hD1_EMA200 = iMA(_Symbol, PERIOD_D1, D1_EMA, 0, MODE_EMA, PRICE_CLOSE);

   // Validate all handles
   if(hEMA8 == INVALID_HANDLE || hEMA21 == INVALID_HANDLE || hEMA50 == INVALID_HANDLE ||
      hRSI == INVALID_HANDLE || hStoch == INVALID_HANDLE || hMACD == INVALID_HANDLE ||
      hATR == INVALID_HANDLE || hM15_EMA21 == INVALID_HANDLE || hM15_EMA50 == INVALID_HANDLE ||
      hH1_EMA21 == INVALID_HANDLE || hH1_EMA50 == INVALID_HANDLE || hH1_RSI == INVALID_HANDLE ||
      hH4_EMA21 == INVALID_HANDLE || hH4_EMA50 == INVALID_HANDLE || hD1_EMA200 == INVALID_HANDLE)
   {
      Print("Failed to create indicator handles");
      return INIT_FAILED;
   }

   gDay = 0;
   gTradesToday = 0;
   gLastTradeTime = 0;
   gTradeCount = 0;

   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   int handles[] = {};
   // Release all handles
   if(hEMA8 != INVALID_HANDLE) IndicatorRelease(hEMA8);
   if(hEMA21 != INVALID_HANDLE) IndicatorRelease(hEMA21);
   if(hEMA50 != INVALID_HANDLE) IndicatorRelease(hEMA50);
   if(hRSI != INVALID_HANDLE) IndicatorRelease(hRSI);
   if(hStoch != INVALID_HANDLE) IndicatorRelease(hStoch);
   if(hMACD != INVALID_HANDLE) IndicatorRelease(hMACD);
   if(hATR != INVALID_HANDLE) IndicatorRelease(hATR);
   if(hM15_EMA21 != INVALID_HANDLE) IndicatorRelease(hM15_EMA21);
   if(hM15_EMA50 != INVALID_HANDLE) IndicatorRelease(hM15_EMA50);
   if(hH1_EMA21 != INVALID_HANDLE) IndicatorRelease(hH1_EMA21);
   if(hH1_EMA50 != INVALID_HANDLE) IndicatorRelease(hH1_EMA50);
   if(hH1_RSI != INVALID_HANDLE) IndicatorRelease(hH1_RSI);
   if(hH4_EMA21 != INVALID_HANDLE) IndicatorRelease(hH4_EMA21);
   if(hH4_EMA50 != INVALID_HANDLE) IndicatorRelease(hH4_EMA50);
   if(hD1_EMA200 != INVALID_HANDLE) IndicatorRelease(hD1_EMA200);
}

//+------------------------------------------------------------------+
void OnTick()
{
   // New day reset
   datetime today = iTime(_Symbol, PERIOD_D1, 0);
   if(today != gDay)
   {
      gDay = today;
      gTradesToday = 0;
   }

   // Manage existing positions (partial closes + trailing)
   ManagePositions();

   // Guards for new entries
   if(gTradesToday >= MaxTradesPerDay) return;
   if(!IsNewBar()) return;
   if(!InSession()) return;
   if((int)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD) > MaxSpreadPts) return;
   if(CountOpenPositions() >= 1) return;
   if(HasOpenPosition()) return;

   // Cooldown
   if(gLastTradeTime > 0)
   {
      datetime barTime = iTime(_Symbol, PERIOD_M5, 0);
      if(barTime < gLastTradeTime + CooldownBars * PeriodSeconds(PERIOD_M5))
         return;
   }

   //=================================================================
   // STEP 1: Get Multi-TF Bias
   //=================================================================
   int bias = GetMultiTFBias();
   if(bias == 0) return;  // No clear bias = no trade

   //=================================================================
   // STEP 2: Check M5 EMA Ribbon alignment + Retest
   //=================================================================
   int ribbonSignal = CheckEMARibbonRetest(bias);
   if(ribbonSignal == 0) return;

   //=================================================================
   // STEP 3: Oscillator Confluence (need 2 of 3)
   //=================================================================
   int oscScore = CheckOscillators(bias);
   if(oscScore < 2) return;  // Need at least 2 of 3 oscillators confirming

   //=================================================================
   // STEP 4: Execute Trade with 3 TPs
   //=================================================================
   ExecuteTrade(bias);
}

//+------------------------------------------------------------------+
//| MULTI-TIMEFRAME BIAS SCORING                                      |
//| D1 = 3 pts, H4 = 2 pts, H1 = 2 pts, M15 = 1 pt                |
//| Need score >= 5 for strong bias                                   |
//+------------------------------------------------------------------+
int GetMultiTFBias()
{
   int bullScore = 0;
   int bearScore = 0;

   //--- D1: Price vs 200 EMA (weight = 3, institutional line)
   double d1Ema[2];
   if(CopyBuffer(hD1_EMA200, 0, 1, 2, d1Ema) < 2) return 0;
   double price = SymbolInfoDouble(_Symbol, SYMBOL_BID);

   if(price > d1Ema[1]) bullScore += 3;
   else bearScore += 3;

   //--- H4: EMA21 vs EMA50 (weight = 2)
   double h4Fast[2], h4Slow[2];
   if(CopyBuffer(hH4_EMA21, 0, 1, 2, h4Fast) < 2) return 0;
   if(CopyBuffer(hH4_EMA50, 0, 1, 2, h4Slow) < 2) return 0;

   if(h4Fast[1] > h4Slow[1] && price > h4Fast[1]) bullScore += 2;
   else if(h4Fast[1] < h4Slow[1] && price < h4Fast[1]) bearScore += 2;

   //--- H1: EMA21 vs EMA50 + RSI (weight = 2)
   double h1Fast[2], h1Slow[2], h1Rsi[2];
   if(CopyBuffer(hH1_EMA21, 0, 1, 2, h1Fast) < 2) return 0;
   if(CopyBuffer(hH1_EMA50, 0, 1, 2, h1Slow) < 2) return 0;
   if(CopyBuffer(hH1_RSI, 0, 1, 2, h1Rsi) < 2) return 0;

   if(h1Fast[1] > h1Slow[1] && h1Rsi[1] > 50) bullScore += 2;
   else if(h1Fast[1] < h1Slow[1] && h1Rsi[1] < 50) bearScore += 2;

   //--- M15: EMA21 vs EMA50 (weight = 1)
   double m15Fast[2], m15Slow[2];
   if(CopyBuffer(hM15_EMA21, 0, 1, 2, m15Fast) < 2) return 0;
   if(CopyBuffer(hM15_EMA50, 0, 1, 2, m15Slow) < 2) return 0;

   if(m15Fast[1] > m15Slow[1]) bullScore += 1;
   else if(m15Fast[1] < m15Slow[1]) bearScore += 1;

   //--- Need very strong consensus (>= 6 out of 8 possible)
   if(bullScore >= 6) return 1;
   if(bearScore >= 6) return -1;

   return 0;
}

//+------------------------------------------------------------------+
//| EMA RIBBON RETEST on M5                                           |
//| Buy: Price pulls back to EMA21 zone, bounces, EMA8 > EMA21 > 50 |
//| Sell: Price rallies to EMA21 zone, rejects, EMA8 < EMA21 < 50   |
//+------------------------------------------------------------------+
int CheckEMARibbonRetest(int bias)
{
   double ema8[4], ema21[4], ema50[4];
   if(CopyBuffer(hEMA8, 0, 1, 4, ema8) < 4) return 0;
   if(CopyBuffer(hEMA21, 0, 1, 4, ema21) < 4) return 0;
   if(CopyBuffer(hEMA50, 0, 1, 4, ema50) < 4) return 0;

   // Index: [0]=oldest(bar4), [3]=newest(bar1)
   MqlRates rates[];
   int copied = CopyRates(_Symbol, PERIOD_M5, 1, 4, rates);
   if(copied < 4) return 0;

   if(bias == 1)  // Bullish bias - look for pullback buy
   {
      // EMA ribbon must be bullish: 8 > 21 > 50
      if(!(ema8[3] > ema21[3] && ema21[3] > ema50[3])) return 0;

      // Price must have pulled back and actually touched EMA21 zone
      bool pullback = false;
      for(int i = 1; i <= 2; i++)
         if(rates[i].low <= ema21[i]) pullback = true;

      if(!pullback) return 0;

      // Bounce: latest bar must close above EMA8 with bullish body
      if(rates[3].close > ema8[3] && rates[3].close > rates[3].open &&
         rates[3].low > ema50[3])  // Must stay above EMA50
         return 1;
   }
   else if(bias == -1)  // Bearish bias - look for rally sell
   {
      // EMA ribbon must be bearish: 8 < 21 < 50
      if(!(ema8[3] < ema21[3] && ema21[3] < ema50[3])) return 0;

      bool pullback = false;
      for(int i = 1; i <= 2; i++)
         if(rates[i].high >= ema21[i]) pullback = true;

      if(!pullback) return 0;

      if(rates[3].close < ema8[3] && rates[3].close < rates[3].open &&
         rates[3].high < ema50[3])  // Must stay below EMA50
         return -1;
   }

   return 0;
}

//+------------------------------------------------------------------+
//| OSCILLATOR CONFLUENCE (score 0-3)                                 |
//| RSI + Stochastic + MACD must agree                               |
//+------------------------------------------------------------------+
int CheckOscillators(int bias)
{
   int score = 0;

   //--- RSI
   double rsi[2];
   if(CopyBuffer(hRSI, 0, 1, 2, rsi) >= 2)
   {
      if(bias == 1 && rsi[1] > RSI_BuyZone && rsi[1] < 80) score++;
      if(bias == -1 && rsi[1] < RSI_SellZone && rsi[1] > 20) score++;
   }

   //--- Stochastic: %K crossing above %D in buy zone, or below in sell zone
   double stochK[3], stochD[3];
   if(CopyBuffer(hStoch, 0, 1, 3, stochK) >= 3 &&
      CopyBuffer(hStoch, 1, 1, 3, stochD) >= 3)
   {
      if(bias == 1)
      {
         // Stoch coming up from oversold, or %K > %D and not overbought
         bool crossUp = (stochK[1] < stochD[1]) && (stochK[2] > stochD[2]);
         bool momentum = stochK[2] > stochD[2] && stochK[2] < Stoch_SellZone;
         if(crossUp || momentum) score++;
      }
      if(bias == -1)
      {
         bool crossDown = (stochK[1] > stochD[1]) && (stochK[2] < stochD[2]);
         bool momentum = stochK[2] < stochD[2] && stochK[2] > Stoch_BuyZone;
         if(crossDown || momentum) score++;
      }
   }

   //--- MACD: histogram positive and growing for buys, negative for sells
   double macdMain[3], macdSignal[3];
   if(CopyBuffer(hMACD, 0, 1, 3, macdMain) >= 3 &&
      CopyBuffer(hMACD, 1, 1, 3, macdSignal) >= 3)
   {
      double hist2 = macdMain[2] - macdSignal[2];
      double hist1 = macdMain[1] - macdSignal[1];

      if(bias == 1)
      {
         // MACD histogram positive or crossing up
         bool macdBull = (hist2 > 0) || (hist2 > hist1 && macdMain[2] > macdSignal[2]);
         if(macdBull) score++;
      }
      if(bias == -1)
      {
         bool macdBear = (hist2 < 0) || (hist2 < hist1 && macdMain[2] < macdSignal[2]);
         if(macdBear) score++;
      }
   }

   return score;
}

//+------------------------------------------------------------------+
//| EXECUTE TRADE with ATR-based SL and 3 TPs                        |
//+------------------------------------------------------------------+
void ExecuteTrade(int bias)
{
   double atr[2];
   if(CopyBuffer(hATR, 0, 1, 2, atr) < 2) return;

   double slDist = atr[1] * ATR_SL_Multi;
   if(slDist < MinSL_Pts * _Point) slDist = MinSL_Pts * _Point;
   if(slDist > MaxSL_Pts * _Point) slDist = MaxSL_Pts * _Point;

   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);

   // Single position: TP at TP2_RR (2.0), trail from TP1 level to capture TP3
   if(bias == 1)
   {
      double entry = ask;
      double sl = NormalizeDouble(entry - slDist, _Digits);
      double tp = NormalizeDouble(entry + slDist * TP2_RR, _Digits);

      Print("BUY SCALP: Entry=", entry, " SL=", sl, " TP=", tp,
            " SLdist=", DoubleToString(slDist/_Point, 0), "pts");

      if(trade.Buy(LotSize, _Symbol, entry, sl, tp, "MTF_Scalp"))
      {
         gTradesToday++;
         gLastTradeTime = TimeCurrent();
      }
   }
   else
   {
      double entry = bid;
      double sl = NormalizeDouble(entry + slDist, _Digits);
      double tp = NormalizeDouble(entry - slDist * TP2_RR, _Digits);

      Print("SELL SCALP: Entry=", entry, " SL=", sl, " TP=", tp,
            " SLdist=", DoubleToString(slDist/_Point, 0), "pts");

      if(trade.Sell(LotSize, _Symbol, entry, sl, tp, "MTF_Scalp"))
      {
         gTradesToday++;
         gLastTradeTime = TimeCurrent();
      }
   }
}

//+------------------------------------------------------------------+
//| POSITION MANAGEMENT: Trail SL on remaining positions              |
//| After TP1 hits, move SL to breakeven on TP2/TP3 positions        |
//| After TP2 hits, trail aggressively on TP3 position                |
//+------------------------------------------------------------------+
void ManagePositions()
{
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);

   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      if(PositionGetInteger(POSITION_MAGIC) != MagicNumber) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;

      double posOpen = PositionGetDouble(POSITION_PRICE_OPEN);
      double posSL   = PositionGetDouble(POSITION_SL);
      double posTP   = PositionGetDouble(POSITION_TP);
      long   posType = PositionGetInteger(POSITION_TYPE);
      double slDist  = 0;

      if(posType == POSITION_TYPE_BUY)
         slDist = posOpen - posSL;
      else
         slDist = posSL - posOpen;

      if(slDist <= 0) continue;

      if(posType == POSITION_TYPE_BUY)
      {
         double profit = bid - posOpen;
         double profitRR = profit / slDist;

         // At 1R: move SL to breakeven
         if(profitRR >= Trail_Start_RR && posSL < posOpen)
         {
            double newSL = NormalizeDouble(posOpen + 10 * _Point, _Digits);
            if(newSL > posSL)
               trade.PositionModify(ticket, newSL, posTP);
         }
         // After 1.5R: start trailing
         else if(profitRR >= 1.5)
         {
            double trailSL = NormalizeDouble(bid - Trail_Step_Pts * _Point, _Digits);
            if(trailSL > posSL && trailSL > posOpen)
               trade.PositionModify(ticket, trailSL, posTP);
         }
      }
      else // SELL
      {
         double profit = posOpen - ask;
         double profitRR = profit / slDist;

         if(profitRR >= Trail_Start_RR && posSL > posOpen)
         {
            double newSL = NormalizeDouble(posOpen - 10 * _Point, _Digits);
            if(newSL < posSL)
               trade.PositionModify(ticket, newSL, posTP);
         }
         else if(profitRR >= 1.5)
         {
            double trailSL = NormalizeDouble(ask + Trail_Step_Pts * _Point, _Digits);
            if(trailSL < posSL && trailSL < posOpen)
               trade.PositionModify(ticket, trailSL, posTP);
         }
      }
   }
}

//+------------------------------------------------------------------+
bool IsNewBar()
{
   static datetime lastBar = 0;
   datetime curBar = iTime(_Symbol, PERIOD_M5, 0);
   if(curBar == lastBar) return false;
   lastBar = curBar;
   return true;
}

//+------------------------------------------------------------------+
bool InSession()
{
   MqlDateTime dt;
   TimeCurrent(dt);
   if(SkipTuesday && dt.day_of_week == 2) return false;
   if(dt.hour >= LDN_Start && dt.hour < LDN_End) return true;
   if(dt.hour >= NY_Start && dt.hour < NY_End) return true;
   return false;
}

//+------------------------------------------------------------------+
bool HasOpenPosition()
{
   return (CountOpenPositions() > 0);
}

//+------------------------------------------------------------------+
int CountOpenPositions()
{
   int count = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      if(PositionGetInteger(POSITION_MAGIC) == MagicNumber &&
         PositionGetString(POSITION_SYMBOL) == _Symbol)
         count++;
   }
   return count;
}
//+------------------------------------------------------------------+
