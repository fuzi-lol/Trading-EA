//+------------------------------------------------------------------+
//|                                        GoldSurgeon_Elite_v1.mq5 |
//|              Institutional-Grade XAUUSD Multi-Confluence EA      |
//|         Smart Money Concepts | 6-Layer Signal Engine | MTF       |
//|                                                                  |
//|  ARCHITECTURE:                                                   |
//|   - 6-layer confluence scoring system (max 100 pts)              |
//|   - Smart Money: Order Blocks, FVG, Liquidity Sweeps             |
//|   - Multi-timeframe: M1, M5, M15, H1                             |
//|   - Dynamic risk sizing + partial close + break-even engine      |
//|   - Full circuit breaker suite (DD, losses, cooldown, news)      |
//+------------------------------------------------------------------+
#property copyright "AlgoQuant Institutional 2026"
#property version   "1.00"
#property strict

#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>

CTrade        m_trade;
CPositionInfo m_position;

//============================================================
//  ENUMERATIONS
//============================================================
enum ENUM_BIAS    { BIAS_BULL, BIAS_BEAR, BIAS_NEUTRAL };
enum ENUM_SESSION { SESSION_OVERLAP, SESSION_LONDON, SESSION_NY, SESSION_TOKYO, SESSION_OFF };

//============================================================
//  INPUT PARAMETERS
//============================================================

input group "=== [1] IDENTITY ==="
input string   EA_Name          = "GoldSurgeon_Elite";
input int      Magic_Number     = 20260601;

input group "=== [2] RISK MANAGEMENT ==="
input double   Risk_Pct         = 1.5;    // % account equity risked per trade
input double   Max_Daily_DD_Pct = 3.0;   // Daily drawdown kill switch (%)
input int      Max_Daily_Trades = 10;    // Max trades allowed per day
input int      Max_Cons_Losses  = 3;     // Consecutive loss circuit breaker
input int      Cooldown_Minutes = 15;    // Forced cooldown between trades (mins)

input group "=== [3] STOP LOSS & TARGETS ==="
input int      SL_Pips          = 8;     // Stop Loss distance in pips
input int      TP1_Pips         = 10;    // Take Profit 1 - partial exit
input int      TP2_Pips         = 20;    // Take Profit 2 - runner (full exit)
input double   TP1_ClosePct     = 50.0;  // % of position to close at TP1
input int      BE_Buffer_Pips   = 2;     // Pips above entry for break-even SL

input group "=== [4] CONFLUENCE SCORING ==="
input int      Min_Score        = 80;    // Minimum score to trigger a trade (0-100)
input int      W_Session        = 15;    // Weight: Session timing
input int      W_Trend          = 25;    // Weight: Trend (EMA stack + ADX)
input int      W_Momentum       = 20;    // Weight: Momentum (RSI/MACD/Stoch/CCI)
input int      W_Structure      = 25;    // Weight: Smart Money (OB/FVG/Sweeps)
input int      W_Volatility     = 15;    // Weight: Volatility (ATR/BB)

input group "=== [5] EXECUTION PROTECTION ==="
input int      Max_Spread_Pts   = 25;    // Max allowed spread in points
input int      Slippage_Pts     = 3;     // Max execution slippage in points

input group "=== [6] EMA SETTINGS ==="
input int      EMA_Fast         = 8;
input int      EMA_Mid          = 21;
input int      EMA_Slow         = 50;
input int      EMA_Trend        = 200;

input group "=== [7] INDICATOR PERIODS ==="
input int      RSI_Period       = 14;
input int      ATR_Period       = 14;
input int      ADX_Period       = 14;
input int      CCI_Period       = 14;
input int      Stoch_K          = 5;
input int      Stoch_D          = 3;
input int      Stoch_Slowing    = 3;
input int      BB_Period        = 20;
input double   BB_Deviation     = 2.0;

input group "=== [8] NEWS / TIME FILTERS ==="
input bool     UseNewsFilter    = true;
input string   NewsWindow_1     = "08:25-08:35"; // Set to server time (GMT)
input string   NewsWindow_2     = "12:55-13:05";
input string   NewsWindow_3     = "15:25-15:35";
input int      NewsBuffer_Mins  = 30;            // Buffer before/after news (mins)

//============================================================
//  INDICATOR HANDLES
//============================================================

// M1 timeframe
int h_RSI_M1;

// M5 timeframe
int h_MACD_M5, h_Stoch_M5, h_CCI_M5, h_BB_M5;
int h_EMA8_M5, h_EMA21_M5, h_EMA50_M5;

// M15 timeframe
int h_ATR_M15, h_EMA200_M15;

// H1 timeframe
int h_ADX_H1;
int h_EMA8_H1, h_EMA21_H1, h_EMA50_H1, h_EMA200_H1;

//============================================================
//  GLOBAL STATE VARIABLES
//============================================================
double   g_DailyStartEquity  = 0.0;
datetime g_CurrentDay        = 0;
int      g_DailyTradeCount   = 0;
int      g_ConsLosses        = 0;
datetime g_LastTradeTime     = 0;

//+------------------------------------------------------------------+
//| Expert Initialization                                            |
//+------------------------------------------------------------------+
int OnInit()
{
   m_trade.SetExpertMagicNumber(Magic_Number);
   m_trade.SetDeviationInPoints(Slippage_Pts);
   m_trade.SetTypeFilling(ORDER_FILLING_IOC);

   g_DailyStartEquity = AccountInfoDouble(ACCOUNT_EQUITY);
   g_CurrentDay       = iTime(_Symbol, PERIOD_D1, 0);

   //--- Initialize all indicator handles
   h_RSI_M1     = iRSI    (_Symbol, PERIOD_M1,  RSI_Period,                     PRICE_CLOSE);

   h_MACD_M5    = iMACD   (_Symbol, PERIOD_M5,  12, 26, 9,                      PRICE_CLOSE);
   h_Stoch_M5   = iStochastic(_Symbol, PERIOD_M5, Stoch_K, Stoch_D, Stoch_Slowing, MODE_SMA, STO_LOWHIGH);
   h_CCI_M5     = iCCI    (_Symbol, PERIOD_M5,  CCI_Period,                     PRICE_TYPICAL);
   h_BB_M5      = iBands  (_Symbol, PERIOD_M5,  BB_Period, 0, BB_Deviation,     PRICE_CLOSE);
   h_EMA8_M5    = iMA     (_Symbol, PERIOD_M5,  EMA_Fast,  0, MODE_EMA,         PRICE_CLOSE);
   h_EMA21_M5   = iMA     (_Symbol, PERIOD_M5,  EMA_Mid,   0, MODE_EMA,         PRICE_CLOSE);
   h_EMA50_M5   = iMA     (_Symbol, PERIOD_M5,  EMA_Slow,  0, MODE_EMA,         PRICE_CLOSE);

   h_ATR_M15    = iATR    (_Symbol, PERIOD_M15, ATR_Period);
   h_EMA200_M15 = iMA     (_Symbol, PERIOD_M15, EMA_Trend, 0, MODE_EMA,         PRICE_CLOSE);

   h_ADX_H1     = iADX    (_Symbol, PERIOD_H1,  ADX_Period);
   h_EMA8_H1    = iMA     (_Symbol, PERIOD_H1,  EMA_Fast,  0, MODE_EMA,         PRICE_CLOSE);
   h_EMA21_H1   = iMA     (_Symbol, PERIOD_H1,  EMA_Mid,   0, MODE_EMA,         PRICE_CLOSE);
   h_EMA50_H1   = iMA     (_Symbol, PERIOD_H1,  EMA_Slow,  0, MODE_EMA,         PRICE_CLOSE);
   h_EMA200_H1  = iMA     (_Symbol, PERIOD_H1,  EMA_Trend, 0, MODE_EMA,         PRICE_CLOSE);

   //--- Validate all handles
   int handles[15] = {
      h_RSI_M1, h_MACD_M5, h_Stoch_M5, h_CCI_M5, h_BB_M5,
      h_EMA8_M5, h_EMA21_M5, h_EMA50_M5,
      h_ATR_M15, h_EMA200_M15,
      h_ADX_H1, h_EMA8_H1, h_EMA21_H1, h_EMA50_H1, h_EMA200_H1
   };
   for(int i = 0; i < 15; i++)
   {
      if(handles[i] == INVALID_HANDLE)
      {
         Print("[CRITICAL] Handle #", i, " failed to initialize. EA will not run.");
         return INIT_FAILED;
      }
   }

   Print("==========================================================");
   Print("[", EA_Name, "] Initialized. Magic: ", Magic_Number);
   Print("[", EA_Name, "] Min Score: ", Min_Score, "/100 | Risk: ", Risk_Pct, "%");
   Print("[", EA_Name, "] SL: ", SL_Pips, " pips | TP1: ", TP1_Pips, " | TP2: ", TP2_Pips);
   Print("==========================================================");
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert Deinitialization - Release all indicator handles          |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   int handles[15] = {
      h_RSI_M1, h_MACD_M5, h_Stoch_M5, h_CCI_M5, h_BB_M5,
      h_EMA8_M5, h_EMA21_M5, h_EMA50_M5,
      h_ATR_M15, h_EMA200_M15,
      h_ADX_H1, h_EMA8_H1, h_EMA21_H1, h_EMA50_H1, h_EMA200_H1
   };
   for(int i = 0; i < 15; i++)
      if(handles[i] != INVALID_HANDLE) IndicatorRelease(handles[i]);

   Print("[", EA_Name, "] Deinitialized. Code: ", reason);
}

//+------------------------------------------------------------------+
//| Main Tick Function                                               |
//+------------------------------------------------------------------+
void OnTick()
{
   //--- Step 1: Daily state reset
   RefreshDailyState();

   //--- Step 2: Manage active positions first (partial close / break-even)
   ManageOpenPositions();

   //--- Step 3: Risk circuit breakers - stop before wasting CPU on analysis
   if(!CheckRiskGates()) return;

   //--- Step 4: Spread protection
   double spread = (SymbolInfoDouble(_Symbol, SYMBOL_ASK) - SymbolInfoDouble(_Symbol, SYMBOL_BID)) / _Point;
   if(spread > Max_Spread_Pts) return;

   //--- Step 5: News time blackout
   if(UseNewsFilter && IsNewsTime()) return;

   //--- Step 6: No entry if position already open
   if(CountMyPositions() > 0) return;

   //--- Step 7: Build 6-layer confluence score
   ENUM_BIAS bias = BIAS_NEUTRAL;
   int s_Session   = Score_Session();
   int s_Trend     = Score_Trend(bias);
   int s_Momentum  = Score_Momentum(bias);
   int s_Structure = Score_Structure(bias);
   int s_Volatility= Score_Volatility();
   int totalScore  = s_Session + s_Trend + s_Momentum + s_Structure + s_Volatility;

   //--- Debug print (remove for live trading if needed)
   static datetime lastDebug = 0;
   if(TimeCurrent() - lastDebug > 60)
   {
      PrintFormat("[SCORE] Total:%d | Session:%d | Trend:%d | Mom:%d | Struct:%d | Vol:%d | Bias:%s",
                  totalScore, s_Session, s_Trend, s_Momentum, s_Structure, s_Volatility,
                  (bias==BIAS_BULL)?"BULL":(bias==BIAS_BEAR)?"BEAR":"NEUTRAL");
      lastDebug = TimeCurrent();
   }

   //--- Step 8: Execute if score threshold met and bias is directional
   if(totalScore >= Min_Score && bias != BIAS_NEUTRAL)
   {
      ExecuteTrade(bias, totalScore);
   }
}

//+------------------------------------------------------------------+
//| LAYER 1 - Session Regime Scoring                                 |
//+------------------------------------------------------------------+
int Score_Session()
{
   MqlDateTime t;
   TimeToStruct(TimeCurrent(), t);
   int h = t.hour;

   // London/NY Overlap (13:00-17:00 GMT) - Peak liquidity window
   if(h >= 13 && h <= 16) return W_Session;

   // London Open (08:00-12:59 GMT) - High institutional activity
   if(h >= 8  && h <= 12) return (int)(W_Session * 0.85);

   // NY Afternoon (17:00-20:59 GMT) - Residual momentum window
   if(h >= 17 && h <= 20) return (int)(W_Session * 0.65);

   // Tokyo Session (00:00-07:59 GMT) - Range-bound, reduced weight
   if(h >= 0  && h <= 7)  return (int)(W_Session * 0.25);

   // Market transition / dead zones
   return (int)(W_Session * 0.10);
}

//+------------------------------------------------------------------+
//| LAYER 2 - Trend Alignment (H1 EMA Stack + ADX Strength)         |
//+------------------------------------------------------------------+
int Score_Trend(ENUM_BIAS &bias)
{
   double ema8[], ema21[], ema50[], ema200[], adx[];
   ArraySetAsSeries(ema8,   true); ArraySetAsSeries(ema21,  true);
   ArraySetAsSeries(ema50,  true); ArraySetAsSeries(ema200, true);
   ArraySetAsSeries(adx,    true);

   if(CopyBuffer(h_EMA8_H1,   0, 0, 3, ema8)   < 3) return 0;
   if(CopyBuffer(h_EMA21_H1,  0, 0, 3, ema21)  < 3) return 0;
   if(CopyBuffer(h_EMA50_H1,  0, 0, 3, ema50)  < 3) return 0;
   if(CopyBuffer(h_EMA200_H1, 0, 0, 3, ema200) < 3) return 0;
   if(CopyBuffer(h_ADX_H1,    0, 0, 3, adx)    < 3) return 0;

   double price      = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   bool   strongTrend = (adx[0] > 25.0);

   // Perfect bull stack: EMA8 > EMA21 > EMA50 > EMA200 & price above all
   bool fullBullStack = (ema8[0] > ema21[0] && ema21[0] > ema50[0] &&
                         ema50[0] > ema200[0] && price > ema200[0]);

   // Perfect bear stack: EMA8 < EMA21 < EMA50 < EMA200 & price below all
   bool fullBearStack = (ema8[0] < ema21[0] && ema21[0] < ema50[0] &&
                         ema50[0] < ema200[0] && price < ema200[0]);

   // Partial alignment: at least above/below 200 EMA with fast > mid
   bool partialBull = (!fullBullStack && price > ema200[0] && ema8[0] > ema21[0]);
   bool partialBear = (!fullBearStack && price < ema200[0] && ema8[0] < ema21[0]);

   if(fullBullStack)
   {
      bias = BIAS_BULL;
      return strongTrend ? W_Trend : (int)(W_Trend * 0.75);
   }
   if(fullBearStack)
   {
      bias = BIAS_BEAR;
      return strongTrend ? W_Trend : (int)(W_Trend * 0.75);
   }
   if(partialBull)
   {
      bias = BIAS_BULL;
      return strongTrend ? (int)(W_Trend * 0.55) : (int)(W_Trend * 0.35);
   }
   if(partialBear)
   {
      bias = BIAS_BEAR;
      return strongTrend ? (int)(W_Trend * 0.55) : (int)(W_Trend * 0.35);
   }

   return 0;
}

//+------------------------------------------------------------------+
//| LAYER 3 - Momentum Confirmation (RSI + MACD + Stochastic + CCI) |
//+------------------------------------------------------------------+
int Score_Momentum(ENUM_BIAS &bias)
{
   double rsi[], macdMain[], macdSig[], stochK[], stochD[], cci[];
   ArraySetAsSeries(rsi,      true); ArraySetAsSeries(macdMain, true);
   ArraySetAsSeries(macdSig,  true); ArraySetAsSeries(stochK,   true);
   ArraySetAsSeries(stochD,   true); ArraySetAsSeries(cci,      true);

   if(CopyBuffer(h_RSI_M1,   0, 0, 3, rsi)      < 3) return 0;
   if(CopyBuffer(h_MACD_M5,  0, 0, 3, macdMain) < 3) return 0;
   if(CopyBuffer(h_MACD_M5,  1, 0, 3, macdSig)  < 3) return 0;
   if(CopyBuffer(h_Stoch_M5, 0, 0, 3, stochK)   < 3) return 0;
   if(CopyBuffer(h_Stoch_M5, 1, 0, 3, stochD)   < 3) return 0;
   if(CopyBuffer(h_CCI_M5,   0, 0, 3, cci)      < 3) return 0;

   int bullPts = 0, bearPts = 0;
   int unit = W_Momentum / 4; // Each of 4 indicators worth 1 unit

   //--- RSI: Midline cross + momentum direction
   if(rsi[0] > 50 && rsi[1] <= 50)                              bullPts += unit;      // Crossed above 50
   else if(rsi[0] > 55 && rsi[0] > rsi[1] && rsi[0] < 72)      bullPts += (unit/2); // Rising momentum, not overbought
   if(rsi[0] < 50 && rsi[1] >= 50)                              bearPts += unit;
   else if(rsi[0] < 45 && rsi[0] < rsi[1] && rsi[0] > 28)      bearPts += (unit/2);

   //--- MACD: Crossover signal + histogram direction
   if(macdMain[0] > macdSig[0] && macdMain[1] <= macdSig[1])    bullPts += unit;      // Fresh bullish cross
   if(macdMain[0] > 0 && macdMain[0] > macdMain[1])             bullPts += (unit/2); // Above zero + accelerating
   if(macdMain[0] < macdSig[0] && macdMain[1] >= macdSig[1])    bearPts += unit;
   if(macdMain[0] < 0 && macdMain[0] < macdMain[1])             bearPts += (unit/2);

   //--- Stochastic: Exiting oversold/overbought zones
   if(stochK[0] > stochD[0] && stochK[1] <= stochD[1] && stochK[0] < 80) bullPts += unit;
   if(stochK[0] < stochD[0] && stochK[1] >= stochD[1] && stochK[0] > 20) bearPts += unit;

   //--- CCI: Momentum burst breakout
   if(cci[0] > 100  && cci[1] <= 100)                           bullPts += unit;
   if(cci[0] < -100 && cci[1] >= -100)                          bearPts += unit;

   // Cap scores at W_Momentum
   bullPts = MathMin(bullPts, W_Momentum);
   bearPts = MathMin(bearPts, W_Momentum);

   // Apply to bias direction - only score in the direction of the trend bias
   if(bias == BIAS_BULL) return bullPts;
   if(bias == BIAS_BEAR) return bearPts;

   // Bias not set by trend yet - let momentum guide
   if(bullPts > bearPts && bullPts >= (W_Momentum / 2)) { bias = BIAS_BULL; return bullPts; }
   if(bearPts > bullPts && bearPts >= (W_Momentum / 2)) { bias = BIAS_BEAR; return bearPts; }

   return 0;
}

//+------------------------------------------------------------------+
//| LAYER 4 - Smart Money Structure (OB + FVG + Liquidity Sweeps)    |
//+------------------------------------------------------------------+
int Score_Structure(ENUM_BIAS &bias)
{
   MqlRates rM5[], rM1[];
   ArraySetAsSeries(rM5, true);
   ArraySetAsSeries(rM1, true);

   if(CopyRates(_Symbol, PERIOD_M5, 0, 22, rM5) < 22) return 0;
   if(CopyRates(_Symbol, PERIOD_M1, 0, 5,  rM1) < 5)  return 0;

   int score   = 0;
   int unit    = W_Structure / 4;
   double price = SymbolInfoDouble(_Symbol, SYMBOL_BID);

   //------------------------------------------------------------------
   // CHECK 1: Liquidity Sweep (Stop Hunt + Rejection)
   // A professional setup: price sweeps a prior high/low, then
   // immediately rejects and closes in the opposite direction
   //------------------------------------------------------------------
   if(bias == BIAS_BULL || bias == BIAS_NEUTRAL)
   {
      // Bullish sweep: wick below prior low, closes bullish (rejection)
      bool sweptLow    = (rM1[1].low < rM1[2].low);
      bool closedBull  = (rM1[1].close > rM1[1].open);
      if(sweptLow && closedBull)
      {
         double wick = rM1[1].open - rM1[1].low;
         double body = rM1[1].close - rM1[1].open;
         if(body > 0 && wick > body * 1.5) // Strong rejection wick
         {
            score += unit;
            if(bias == BIAS_NEUTRAL) bias = BIAS_BULL;
         }
      }
   }
   if(bias == BIAS_BEAR || bias == BIAS_NEUTRAL)
   {
      // Bearish sweep: wick above prior high, closes bearish (rejection)
      bool sweptHigh   = (rM1[1].high > rM1[2].high);
      bool closedBear  = (rM1[1].close < rM1[1].open);
      if(sweptHigh && closedBear)
      {
         double wick = rM1[1].high - rM1[1].open;
         double body = rM1[1].open - rM1[1].close;
         if(body > 0 && wick > body * 1.5)
         {
            score += unit;
            if(bias == BIAS_NEUTRAL) bias = BIAS_BEAR;
         }
      }
   }

   //------------------------------------------------------------------
   // CHECK 2: Order Block Detection (M5)
   // Bullish OB = last bearish candle before a strong bullish impulse
   // Bearish OB = last bullish candle before a strong bearish impulse
   // Price must be retesting the OB zone now
   //------------------------------------------------------------------
   for(int i = 3; i < 18; i++)
   {
      if(bias == BIAS_BULL)
      {
         bool isBearOB     = (rM5[i].close < rM5[i].open);
         bool nextImpulse  = (rM5[i-1].close > rM5[i-1].open &&
                             (rM5[i-1].close - rM5[i-1].open) > (rM5[i].open - rM5[i].close) * 1.5);
         bool priceInOB    = (price >= rM5[i].close && price <= rM5[i].open);
         if(isBearOB && nextImpulse && priceInOB) { score += unit; break; }
      }
      else if(bias == BIAS_BEAR)
      {
         bool isBullOB     = (rM5[i].close > rM5[i].open);
         bool nextImpulse  = (rM5[i-1].close < rM5[i-1].open &&
                             (rM5[i-1].open - rM5[i-1].close) > (rM5[i].close - rM5[i].open) * 1.5);
         bool priceInOB    = (price <= rM5[i].close && price >= rM5[i].open);
         if(isBullOB && nextImpulse && priceInOB) { score += unit; break; }
      }
   }

   //------------------------------------------------------------------
   // CHECK 3: Fair Value Gap (FVG) Detection (M5)
   // 3-candle pattern: gap between candle[i+1] and candle[i-1]
   // Price retracing into the gap = institutional magnet zone
   //------------------------------------------------------------------
   for(int i = 1; i < 12; i++)
   {
      if(bias == BIAS_BULL)
      {
         // Bullish FVG: gap above candle[i+1].high, below candle[i-1].low
         if(rM5[i+1].high < rM5[i-1].low) // Gap exists
         {
            if(price >= rM5[i+1].high && price <= rM5[i-1].low) // Price in gap
            {
               score += unit;
               break;
            }
         }
      }
      else if(bias == BIAS_BEAR)
      {
         // Bearish FVG: gap below candle[i+1].low, above candle[i-1].high
         if(rM5[i+1].low > rM5[i-1].high)
         {
            if(price >= rM5[i-1].high && price <= rM5[i+1].low)
            {
               score += unit;
               break;
            }
         }
      }
   }

   //------------------------------------------------------------------
   // CHECK 4: Round Number / Key Psychological Level Proximity
   // Institutional orders cluster around round numbers on gold
   // ($2000, $2050, $2100 etc. - every $50)
   //------------------------------------------------------------------
   double roundLevel = MathRound(price / 50.0) * 50.0;
   double dist       = MathAbs(price - roundLevel);
   double tolerance  = SL_Pips * _Point * 10 * 2.5; // Within 2.5x SL distance

   if(dist < tolerance) score += (int)(unit * 0.75);

   return MathMin(score, W_Structure);
}

//+------------------------------------------------------------------+
//| LAYER 5 - Volatility Filter (ATR + Bollinger Band Expansion)     |
//+------------------------------------------------------------------+
int Score_Volatility()
{
   double atr[], bbU[], bbM[], bbL[];
   ArraySetAsSeries(atr, true); ArraySetAsSeries(bbU, true);
   ArraySetAsSeries(bbM, true); ArraySetAsSeries(bbL, true);

   if(CopyBuffer(h_ATR_M15, 0, 0, 5, atr) < 5) return 0;
   if(CopyBuffer(h_BB_M5,   1, 0, 5, bbU) < 5) return 0;
   if(CopyBuffer(h_BB_M5,   0, 0, 5, bbM) < 5) return 0;
   if(CopyBuffer(h_BB_M5,   2, 0, 5, bbL) < 5) return 0;

   double atrAvg = (atr[0] + atr[1] + atr[2]) / 3.0;

   // ATR guard: not dead market, not news spike
   // For gold: normal range 0.5-4.0 ATR on M15
   if(atrAvg < 0.4) return 0;  // Dead/flat market - skip
   if(atrAvg > 6.0) return 0;  // News spike / wild volatility - skip

   // Bollinger Band width expansion (volatility awakening)
   double bbWidth     = bbU[0] - bbL[0];
   double bbWidthPrev = bbU[1] - bbL[1];
   bool   expanding   = (bbWidth > bbWidthPrev * 1.08); // 8% expansion

   if(expanding && atrAvg >= 0.8) return W_Volatility;           // Ideal conditions
   if(atrAvg >= 0.6)              return (int)(W_Volatility * 0.65); // Acceptable
   return (int)(W_Volatility * 0.30);                             // Low but passing
}

//+------------------------------------------------------------------+
//| News Time Blackout Filter                                        |
//+------------------------------------------------------------------+
bool IsNewsTime()
{
   string windows[3];
   windows[0] = NewsWindow_1;
   windows[1] = NewsWindow_2;
   windows[2] = NewsWindow_3;

   MqlDateTime now;
   TimeToStruct(TimeCurrent(), now);
   int curMin = now.hour * 60 + now.min;

   for(int i = 0; i < 3; i++)
   {
      if(StringLen(windows[i]) < 11) continue;

      string parts[];
      if(StringSplit(windows[i], '-', parts) < 2) continue;

      string sTime[], eTime[];
      if(StringSplit(parts[0], ':', sTime) < 2) continue;
      if(StringSplit(parts[1], ':', eTime) < 2) continue;

      int startMin = (int)StringToInteger(sTime[0]) * 60 + (int)StringToInteger(sTime[1]);
      int endMin   = (int)StringToInteger(eTime[0]) * 60 + (int)StringToInteger(eTime[1]);

      // Apply buffer window around news time
      if(curMin >= (startMin - NewsBuffer_Mins) && curMin <= (endMin + NewsBuffer_Mins))
         return true;
   }
   return false;
}

//+------------------------------------------------------------------+
//| Risk Circuit Breaker Suite                                       |
//+------------------------------------------------------------------+
bool CheckRiskGates()
{
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);

   // Gate 1: Daily drawdown percentage kill switch
   double ddPct = ((g_DailyStartEquity - equity) / g_DailyStartEquity) * 100.0;
   if(ddPct >= Max_Daily_DD_Pct)
   {
      static datetime dd_msg = 0;
      if(TimeCurrent() - dd_msg > 3600)
      {
         PrintFormat("[CIRCUIT BREAKER] Daily DD %.2f%% >= limit %.2f%%. Halted.", ddPct, Max_Daily_DD_Pct);
         dd_msg = TimeCurrent();
      }
      return false;
   }

   // Gate 2: Daily trade count cap
   if(g_DailyTradeCount >= Max_Daily_Trades) return false;

   // Gate 3: Consecutive losses stop
   if(g_ConsLosses >= Max_Cons_Losses)
   {
      static datetime cl_msg = 0;
      if(TimeCurrent() - cl_msg > 3600)
      {
         Print("[CIRCUIT BREAKER] ", g_ConsLosses, " consecutive losses. Halted for today.");
         cl_msg = TimeCurrent();
      }
      return false;
   }

   // Gate 4: Cooldown timer between trades
   if(TimeCurrent() - g_LastTradeTime < (Cooldown_Minutes * 60)) return false;

   return true;
}

//+------------------------------------------------------------------+
//| Daily State Reset                                                |
//+------------------------------------------------------------------+
void RefreshDailyState()
{
   datetime today = iTime(_Symbol, PERIOD_D1, 0);
   if(today != g_CurrentDay)
   {
      g_CurrentDay       = today;
      g_DailyStartEquity = AccountInfoDouble(ACCOUNT_EQUITY);
      g_DailyTradeCount  = 0;
      g_ConsLosses       = 0;
      Print("[", EA_Name, "] New trading day. Starting equity: ", DoubleToString(g_DailyStartEquity, 2));
   }
}

//+------------------------------------------------------------------+
//| Dynamic Lot Size Calculator                                      |
//+------------------------------------------------------------------+
double CalculateLot()
{
   double equity    = AccountInfoDouble(ACCOUNT_EQUITY);
   double riskAmt   = equity * (Risk_Pct / 100.0);
   double tickVal   = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double tickSize  = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   double slDist    = SL_Pips * _Point * 10; // SL in price units

   if(tickVal == 0 || tickSize == 0 || slDist == 0) return SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);

   double lot      = riskAmt / ((slDist / tickSize) * tickVal);
   double minLot   = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxLot   = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double lotStep  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);

   lot = MathFloor(lot / lotStep) * lotStep;
   return MathMax(minLot, MathMin(maxLot, lot));
}

//+------------------------------------------------------------------+
//| Trade Execution                                                  |
//+------------------------------------------------------------------+
void ExecuteTrade(ENUM_BIAS bias, int score)
{
   double lot = CalculateLot();
   string comment = StringFormat("%s | Score:%d", EA_Name, score);

   if(bias == BIAS_BULL)
   {
      double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      double sl  = ask - (SL_Pips  * _Point * 10);
      double tp  = ask + (TP2_Pips * _Point * 10); // Full TP (TP1 handled via partial close)

      if(m_trade.Buy(lot, _Symbol, ask, sl, tp, comment))
      {
         g_LastTradeTime = TimeCurrent();
         g_DailyTradeCount++;
         PrintFormat("[TRADE OPENED] BUY | Lot: %.2f | Entry: %.5f | SL: %.5f | TP2: %.5f | Score: %d",
                     lot, ask, sl, tp, score);
         SendNotification(StringFormat("GoldSurgeon BUY opened | Score: %d | Lot: %.2f", score, lot));
      }
   }
   else if(bias == BIAS_BEAR)
   {
      double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      double sl  = bid + (SL_Pips  * _Point * 10);
      double tp  = bid - (TP2_Pips * _Point * 10);

      if(m_trade.Sell(lot, _Symbol, bid, sl, tp, comment))
      {
         g_LastTradeTime = TimeCurrent();
         g_DailyTradeCount++;
         PrintFormat("[TRADE OPENED] SELL | Lot: %.2f | Entry: %.5f | SL: %.5f | TP2: %.5f | Score: %d",
                     lot, bid, sl, tp, score);
         SendNotification(StringFormat("GoldSurgeon SELL opened | Score: %d | Lot: %.2f", score, lot));
      }
   }
}

//+------------------------------------------------------------------+
//| Active Position Management (Partial Close + Break-Even Engine)   |
//+------------------------------------------------------------------+
void ManageOpenPositions()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(!m_position.SelectByIndex(i))                   continue;
      if(m_position.Symbol() != _Symbol)                 continue;
      if(m_position.Magic()  != (long)Magic_Number)      continue;

      ulong  ticket   = m_position.Ticket();
      double entry    = m_position.PriceOpen();
      double curSL    = m_position.StopLoss();
      double curTP    = m_position.TakeProfit();
      double bid      = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      double ask      = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      double minLot   = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
      double lotStep  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);

      //--- BUY position management
      if(m_position.PositionType() == POSITION_TYPE_BUY)
      {
         double tp1    = entry + (TP1_Pips * _Point * 10);
         double beStop = entry + (BE_Buffer_Pips * _Point * 10);

         // TP1 hit: partial close + move SL to break-even
         if(bid >= tp1 && curSL < entry)
         {
            double closeLot = MathFloor((m_position.Volume() * TP1_ClosePct / 100.0) / lotStep) * lotStep;
            closeLot = MathMax(minLot, closeLot);

            // Only partial close if remaining volume stays above min lot
            double remaining = m_position.Volume() - closeLot;
            if(remaining >= minLot)
            {
               if(m_trade.PositionClosePartial(ticket, closeLot))
               {
                  m_trade.PositionModify(ticket, beStop, curTP);
                  PrintFormat("[MGMT] BUY TP1 hit. Partial close %.2f lots. BE set at: %.5f", closeLot, beStop);
               }
            }
            else
            {
               // Volume too small to split - just move to break-even
               if(curSL < beStop) m_trade.PositionModify(ticket, beStop, curTP);
            }
         }
      }

      //--- SELL position management
      else if(m_position.PositionType() == POSITION_TYPE_SELL)
      {
         double tp1    = entry - (TP1_Pips * _Point * 10);
         double beStop = entry - (BE_Buffer_Pips * _Point * 10);

         // TP1 hit: partial close + move SL to break-even
         if(ask <= tp1 && (curSL > entry || curSL == 0))
         {
            double closeLot = MathFloor((m_position.Volume() * TP1_ClosePct / 100.0) / lotStep) * lotStep;
            closeLot = MathMax(minLot, closeLot);

            double remaining = m_position.Volume() - closeLot;
            if(remaining >= minLot)
            {
               if(m_trade.PositionClosePartial(ticket, closeLot))
               {
                  m_trade.PositionModify(ticket, beStop, curTP);
                  PrintFormat("[MGMT] SELL TP1 hit. Partial close %.2f lots. BE set at: %.5f", closeLot, beStop);
               }
            }
            else
            {
               if(curSL == 0 || curSL > beStop) m_trade.PositionModify(ticket, beStop, curTP);
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Count EA's Own Open Positions                                    |
//+------------------------------------------------------------------+
int CountMyPositions()
{
   int count = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
      if(m_position.SelectByIndex(i) &&
         m_position.Symbol() == _Symbol &&
         m_position.Magic()  == (long)Magic_Number)
         count++;
   return count;
}

//+------------------------------------------------------------------+
//| Trade Transaction Handler - Track Wins / Losses for Circuit      |
//+------------------------------------------------------------------+
void OnTradeTransaction(const MqlTradeTransaction &trans,
                        const MqlTradeRequest     &request,
                        const MqlTradeResult      &result)
{
   if(trans.type != TRADE_TRANSACTION_DEAL_ADD) return;
   if(trans.deal  == 0) return;

   if(!HistoryDealSelect(trans.deal)) return;

   long   magic  = HistoryDealGetInteger(trans.deal, DEAL_MAGIC);
   long   entry  = HistoryDealGetInteger(trans.deal, DEAL_ENTRY);
   double profit = HistoryDealGetDouble (trans.deal, DEAL_PROFIT);

   if(magic != (long)Magic_Number) return;
   if(entry != DEAL_ENTRY_OUT) return; // Only process closing deals

   if(profit < 0.0)
   {
      g_ConsLosses++;
      PrintFormat("[RESULT] LOSS | P&L: %.2f | Consecutive losses: %d", profit, g_ConsLosses);
      SendNotification(StringFormat("GoldSurgeon LOSS: %.2f | Streak: %d", profit, g_ConsLosses));
   }
   else
   {
      g_ConsLosses = 0;
      PrintFormat("[RESULT] WIN  | P&L: +%.2f | Loss streak reset.", profit);
      if(profit > 0) SendNotification(StringFormat("GoldSurgeon WIN: +%.2f", profit));
   }
}

//+------------------------------------------------------------------+
//| END OF GoldSurgeon_Elite_v1.mq5                                  |
//+------------------------------------------------------------------+
