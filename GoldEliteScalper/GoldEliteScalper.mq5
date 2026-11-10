//+------------------------------------------------------------------+
//|                                       GoldEliteScalper.mq5       |
//|   Prop Firm Gold Scalper: ICT + VWAP + CVD + Price Action        |
//|   Multi-Confluence Entry System with Strict DD Protection        |
//+------------------------------------------------------------------+
//| DESIGNED FOR:                                                    |
//|   - $10K prop firm account, NO leverage                          |
//|   - 3% daily drawdown limit, 12% overall drawdown limit         |
//|   - Gold (XAUUSD) scalping on M1/M5                             |
//|                                                                  |
//| ENTRY CONFLUENCE (need MinConfluence of 6 signals):              |
//|   1. ICT: Liquidity sweep at S/R + structure break (BOS/CHoCH)  |
//|   2. FVG/Order Block: Price at valid imbalance zone              |
//|   3. VWAP: Buy below VWAP reclaim, Sell above VWAP reject       |
//|   4. CVD: Volume delta confirms direction                        |
//|   5. Price Action: Engulfing, pin bar, or hammer/shooting star  |
//|   6. EMA Trend: M5 EMA21 + M15 EMA50 alignment                 |
//|                                                                  |
//| EXIT:                                                            |
//|   - ATR-based SL (capped min/max)                               |
//|   - TP at 1.5-2.0 RR or next S/R level                         |
//|   - Breakeven at 1R, trailing at 1.5R                           |
//+------------------------------------------------------------------+
#property copyright "GoldEliteScalper"
#property version   "1.00"
#property strict

#include <Trade\Trade.mqh>

//=== INPUTS ============================================================

input group "=== Kill Zone Times (Server Time) ==="
input int      LDN_Start         = 10;       // London KZ start hour
input int      LDN_End           = 13;       // London KZ end hour
input int      NY_Start          = 15;       // NY AM KZ start hour
input int      NY_End            = 20;       // NY AM KZ end hour
input bool     UseLDN            = true;     // Trade London session
input bool     UseNY             = true;     // Trade NY session
input bool     SkipTuesday       = true;     // Skip Tuesdays (historically weak)
input string   SkipHours         = "11,16,17"; // Comma-separated hours to skip
input bool     SkipThursday      = false;    // Skip Thursdays
input bool     SkipFriday        = false;    // Skip Fridays

input group "=== EMA Trend Filter ==="
input int      FastEMA_Period    = 9;        // M1 Fast EMA
input int      SlowEMA_Period    = 21;       // M1 Slow EMA
input int      TrendEMA_M5      = 21;       // M5 trend EMA
input int      TrendEMA_M15     = 50;       // M15 trend EMA

input group "=== VWAP Settings ==="
input bool     UseVWAP           = true;     // Enable VWAP filter
input int      VWAP_BandPts     = 50;       // VWAP proximity zone (points)

input group "=== CVD (Volume Delta) ==="
input bool     UseCVD            = true;     // Enable CVD filter
input int      CVD_Period        = 14;       // CVD lookback period
input int      CVD_Smooth        = 5;        // CVD smoothing EMA

input group "=== ICT: S/R & Liquidity Sweep ==="
input int      SR_SwingBars      = 5;        // Swing high/low lookback (each side)
input int      SR_MaxLevels      = 8;        // Max S/R levels to track
input int      SR_MergePts       = 300;      // Merge S/R within this distance (points)
input int      SweepMinPts       = 15;       // Min sweep beyond S/R (points)
input int      SweepMaxPts       = 250;      // Max sweep beyond S/R (points)
input int      SweepValidBars    = 3;        // Bars a sweep signal stays valid

input group "=== ICT: FVG ==="
input int      FVG_Lookback      = 20;       // Bars to scan for FVG
input double   FVG_MinWidth_Pts  = 30;       // Min FVG width in points
input double   FVG_MaxDist_ATR   = 1.5;      // Max distance from price to FVG (ATR units)

input group "=== ICT: Order Block ==="
input int      OB_Lookback       = 20;       // Bars to scan for OB
input double   OB_Disp_Multi     = 1.5;      // Displacement candle body ratio
input double   OB_MaxDist_ATR    = 1.5;      // Max distance to OB (ATR units)

input group "=== ICT: BOS / CHoCH ==="
input int      Structure_Lookback = 30;      // Bars to track structure
input int      BOS_MinPts        = 50;       // Min points for valid BOS

input group "=== Price Action Patterns ==="
input double   Engulf_MinRatio   = 1.3;      // Engulfing body ratio (current/prev)
input double   PinBar_WickRatio  = 2.0;      // Pin bar wick-to-body ratio
input double   PinBar_MinWickPts = 30;       // Min pin bar wick in points

input group "=== ATR & Risk ==="
input int      ATR_Period        = 14;       // ATR period
input double   SL_ATR_Multi      = 1.2;      // SL = ATR x multiplier (tight for scalp)
input int      MinSL_Points      = 100;      // Min SL (points)
input int      MaxSL_Points      = 500;      // Max SL (points) - keeps risk small
input double   RiskReward        = 2.0;      // Risk:Reward ratio
input bool     UseNextSR_TP      = true;     // Use next S/R as TP (if better than RR)

input group "=== Breakeven & Trailing ==="
input double   BE_Trigger_RR     = 1.0;      // Move to BE at this R multiple
input double   BE_Lock_Points    = 15;       // Points to lock at BE
input double   Trail_Trigger_RR  = 1.5;      // Start trailing at this R multiple
input double   Trail_Step_Pts    = 80;       // Trailing step (points)

input group "=== Confluence Scoring ==="
input int      MinConfluence     = 4;        // Min signals needed to enter (out of 6)

input group "=== Prop Firm Safety ==="
input double   RiskPercent       = 0.5;      // Risk % per trade (0.5% = $50 on $10K)
input double   DailyLossLimit    = 2.5;      // Daily loss limit % (buffer before 3%)
input double   MaxDrawdownPct    = 10.0;     // Max account DD % (buffer before 12%)
input bool     UseEquityGuard    = true;     // Enable prop firm protection
input bool     CloseAtSessionEnd = true;     // Close trades at end of NY session

input group "=== General ==="
input int      MaxTradesPerDay   = 3;        // Max trades per day
input int      CooldownMins      = 15;       // Minutes cooldown between trades
input int      MaxSpreadPts      = 40;       // Max spread to trade (points)
input int      MagicNumber       = 999500;   // Magic number

//=== GLOBALS ===========================================================
CTrade trade;

// Indicator handles
int h_fastEMA, h_slowEMA;
int h_trendEMA_M5, h_trendEMA_M15;
int h_atr_M1, h_atr_M5;
int h_rsi;

// S/R tracking
struct SRLevel
{
   double   price;
   int      touches;
   bool     isSupport;
   datetime lastTouch;
   bool     swept;
};
SRLevel g_sr[];
int     g_srCount = 0;

// FVG tracking
struct FVGZone
{
   double   top;
   double   bottom;
   bool     bullish;
   int      barIndex;
   bool     filled;
};
FVGZone g_fvg[];
int     g_fvgCount = 0;

// Order Block tracking
struct OBZone
{
   double   high;
   double   low;
   bool     bullish;
   int      barIndex;
   bool     mitigated;
};
OBZone g_ob[];
int    g_obCount = 0;

// Structure tracking
struct SwingPoint
{
   double   price;
   datetime time;
   bool     isHigh;
};
SwingPoint g_swings[];
int        g_swingCount = 0;
double     g_lastHH = 0, g_lastHL = 0;  // bullish structure
double     g_lastLH = 0, g_lastLL = 0;  // bearish structure
int        g_structureBias = 0;          // 1=bullish, -1=bearish, 0=neutral

// Sweep detection
bool     g_sweepActive    = false;
int      g_sweepDir       = 0;          // 1=buy (sweep below support), -1=sell
double   g_sweepSR        = 0;
double   g_sweepWick      = 0;
int      g_sweepAge       = 0;

// VWAP
double   g_vwap           = 0;
double   g_cumPV          = 0;
double   g_cumVol         = 0;
datetime g_vwapDay        = 0;

// CVD
double   g_cvd            = 0;
double   g_cvdPrev        = 0;
double   g_cvdSmoothed    = 0;
double   g_cvdSmoothedPrev = 0;
double   g_cvdRaw[];

// Trade state
datetime g_lastDay         = 0;
int      g_dailyTrades     = 0;
double   g_dayStartBalance = 0;
double   g_initialBalance  = 0;
bool     g_dailyStopped    = false;
bool     g_ddStopped       = false;
datetime g_lastTradeTime   = 0;
bool     g_inTrade         = false;
double   g_tradeEntry      = 0;
double   g_tradeSL         = 0;
double   g_tradeTP         = 0;
double   g_slDistance       = 0;
bool     g_trailingActive  = false;
bool     g_beApplied       = false;

// Bar tracking
datetime g_lastM1Bar  = 0;
datetime g_lastM5Bar  = 0;
datetime g_lastM15Bar = 0;

// EMA cross tracking
double g_prevFastEMA  = 0;
double g_prevSlowEMA  = 0;

// Entry gate: only 1 entry attempt per M5 bar
datetime g_lastEntryAttemptM5 = 0;

// Skip hours array
int g_skipHours[];
int g_skipHourCount = 0;

//+------------------------------------------------------------------+
int OnInit()
{
   trade.SetExpertMagicNumber(MagicNumber);
   trade.SetDeviationInPoints(30);
   trade.SetTypeFillingBySymbol(_Symbol);

   // M1 indicators
   h_fastEMA  = iMA(_Symbol, PERIOD_M1, FastEMA_Period, 0, MODE_EMA, PRICE_CLOSE);
   h_slowEMA  = iMA(_Symbol, PERIOD_M1, SlowEMA_Period, 0, MODE_EMA, PRICE_CLOSE);
   h_atr_M1   = iATR(_Symbol, PERIOD_M1, ATR_Period);
   h_rsi      = iRSI(_Symbol, PERIOD_M1, 14, PRICE_CLOSE);

   // Higher TF EMAs
   h_trendEMA_M5  = iMA(_Symbol, PERIOD_M5, TrendEMA_M5, 0, MODE_EMA, PRICE_CLOSE);
   h_trendEMA_M15 = iMA(_Symbol, PERIOD_M15, TrendEMA_M15, 0, MODE_EMA, PRICE_CLOSE);
   h_atr_M5       = iATR(_Symbol, PERIOD_M5, ATR_Period);

   if(h_fastEMA == INVALID_HANDLE || h_slowEMA == INVALID_HANDLE ||
      h_atr_M1 == INVALID_HANDLE || h_rsi == INVALID_HANDLE ||
      h_trendEMA_M5 == INVALID_HANDLE || h_trendEMA_M15 == INVALID_HANDLE ||
      h_atr_M5 == INVALID_HANDLE)
   {
      Print("Failed to create indicator handles");
      return INIT_FAILED;
   }

   g_initialBalance  = AccountInfoDouble(ACCOUNT_BALANCE);
   g_dayStartBalance = g_initialBalance;

   ArrayResize(g_sr, 0);
   ArrayResize(g_fvg, 0);
   ArrayResize(g_ob, 0);
   ArrayResize(g_swings, 0);
   ArrayResize(g_cvdRaw, 0);

   // Parse skip hours
   g_skipHourCount = 0;
   if(StringLen(SkipHours) > 0)
   {
      string parts[];
      int count = StringSplit(SkipHours, ',', parts);
      ArrayResize(g_skipHours, count);
      for(int i = 0; i < count; i++)
      {
         StringTrimLeft(parts[i]);
         StringTrimRight(parts[i]);
         g_skipHours[i] = (int)StringToInteger(parts[i]);
         g_skipHourCount++;
      }
   }

   Print("GoldEliteScalper initialized | Balance: ", g_initialBalance,
         " | Daily DD limit: ", DailyLossLimit, "% | Max DD: ", MaxDrawdownPct, "%",
         " | Skip hours: ", SkipHours);

   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   IndicatorRelease(h_fastEMA);
   IndicatorRelease(h_slowEMA);
   IndicatorRelease(h_atr_M1);
   IndicatorRelease(h_rsi);
   IndicatorRelease(h_trendEMA_M5);
   IndicatorRelease(h_trendEMA_M15);
   IndicatorRelease(h_atr_M5);
}

//+------------------------------------------------------------------+
void OnTick()
{
   datetime currentTime = TimeCurrent();
   MqlDateTime dt;
   TimeToStruct(currentTime, dt);

   //--- New day reset
   datetime today = currentTime - (currentTime % 86400);
   if(today != g_lastDay)
   {
      g_lastDay         = today;
      g_dailyTrades     = 0;
      g_dayStartBalance = AccountInfoDouble(ACCOUNT_BALANCE);
      g_dailyStopped    = false;
      ResetVWAP();
      Print("New day | Balance: ", g_dayStartBalance);
   }

   //--- Prop firm safety checks
   if(UseEquityGuard)
   {
      if(CheckDailyDD() || CheckOverallDD())
         return;
   }

   //--- Manage existing positions (BE / trailing / session close)
   ManagePositions(dt);

   //--- New M1 bar check
   datetime m1Bar = iTime(_Symbol, PERIOD_M1, 0);
   if(m1Bar == g_lastM1Bar) return;
   g_lastM1Bar = m1Bar;

   //--- Update VWAP
   UpdateVWAP();

   //--- Update CVD
   UpdateCVD();

   //--- New M5 bar - update S/R, FVG, OB, structure
   datetime m5Bar = iTime(_Symbol, PERIOD_M5, 0);
   if(m5Bar != g_lastM5Bar)
   {
      g_lastM5Bar = m5Bar;
      UpdateSRLevels();
      DetectFVG();
      DetectOrderBlocks();
      UpdateStructure();
   }

   //--- Detect liquidity sweeps on M1
   DetectLiquiditySweep();

   //--- Age sweep signal
   if(g_sweepActive)
   {
      g_sweepAge++;
      if(g_sweepAge > SweepValidBars)
         g_sweepActive = false;
   }

   //--- Check if we should look for entries
   if(g_inTrade) return;
   if(g_dailyStopped || g_ddStopped) return;
   if(g_dailyTrades >= MaxTradesPerDay) return;

   // Cooldown check
   if(g_lastTradeTime > 0 && (currentTime - g_lastTradeTime) < CooldownMins * 60)
      return;

   // Session check
   if(!InKillZone(dt)) return;

   // Skip days
   if(SkipTuesday  && dt.day_of_week == 2) return;
   if(SkipThursday && dt.day_of_week == 4) return;
   if(SkipFriday   && dt.day_of_week == 5) return;

   // Skip specific hours
   for(int h = 0; h < g_skipHourCount; h++)
      if(dt.hour == g_skipHours[h]) return;

   // Spread check
   long spread = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   if(spread > MaxSpreadPts) return;

   // Only attempt 1 entry per M5 bar (prevents spamming)
   datetime currentM5 = iTime(_Symbol, PERIOD_M5, 0);
   if(currentM5 == g_lastEntryAttemptM5) return;
   g_lastEntryAttemptM5 = currentM5;

   //--- Evaluate confluence and enter
   EvaluateEntry();
}

//+------------------------------------------------------------------+
//| PROP FIRM SAFETY                                                  |
//+------------------------------------------------------------------+
bool CheckDailyDD()
{
   double equity  = AccountInfoDouble(ACCOUNT_EQUITY);
   double dailyDD = (g_dayStartBalance - equity) / g_dayStartBalance * 100.0;

   if(dailyDD >= DailyLossLimit)
   {
      if(!g_dailyStopped)
      {
         Print("DAILY DD LIMIT HIT: ", DoubleToString(dailyDD, 2), "% | Closing all & stopping");
         CloseAllPositions();
         g_dailyStopped = true;
      }
      return true;
   }
   return false;
}

//+------------------------------------------------------------------+
bool CheckOverallDD()
{
   double equity    = AccountInfoDouble(ACCOUNT_EQUITY);
   double overallDD = (g_initialBalance - equity) / g_initialBalance * 100.0;

   // Also track from peak balance
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   if(balance > g_initialBalance)
      g_initialBalance = balance;  // trailing DD from peak

   if(overallDD >= MaxDrawdownPct)
   {
      if(!g_ddStopped)
      {
         Print("MAX DRAWDOWN LIMIT HIT: ", DoubleToString(overallDD, 2), "% | STOPPING ALL TRADING");
         CloseAllPositions();
         g_ddStopped = true;
      }
      return true;
   }
   return false;
}

//+------------------------------------------------------------------+
void CloseAllPositions()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      if(PositionGetInteger(POSITION_MAGIC) != MagicNumber) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      trade.PositionClose(ticket);
   }
   g_inTrade = false;
}

//+------------------------------------------------------------------+
//| KILL ZONE CHECK                                                   |
//+------------------------------------------------------------------+
bool InKillZone(MqlDateTime &dt)
{
   int hour = dt.hour;
   if(UseLDN && hour >= LDN_Start && hour < LDN_End) return true;
   if(UseNY  && hour >= NY_Start  && hour < NY_End)   return true;
   return false;
}

//+------------------------------------------------------------------+
//| VWAP CALCULATION (Session-based)                                  |
//+------------------------------------------------------------------+
void ResetVWAP()
{
   g_cumPV  = 0;
   g_cumVol = 0;
   g_vwap   = 0;
}

void UpdateVWAP()
{
   double close  = iClose(_Symbol, PERIOD_M1, 1);
   double high   = iHigh(_Symbol, PERIOD_M1, 1);
   double low    = iLow(_Symbol, PERIOD_M1, 1);
   double vol    = (double)iVolume(_Symbol, PERIOD_M1, 1);

   if(vol <= 0) vol = 1;

   double typicalPrice = (high + low + close) / 3.0;
   g_cumPV  += typicalPrice * vol;
   g_cumVol += vol;

   if(g_cumVol > 0)
      g_vwap = g_cumPV / g_cumVol;
}

//+------------------------------------------------------------------+
//| CVD (Cumulative Volume Delta) - Tick Volume Approximation        |
//+------------------------------------------------------------------+
void UpdateCVD()
{
   // Approximate delta: if close > open, delta = +volume, else -volume
   // Weighted by how much of the bar is bullish vs bearish
   double open  = iOpen(_Symbol, PERIOD_M1, 1);
   double close = iClose(_Symbol, PERIOD_M1, 1);
   double high  = iHigh(_Symbol, PERIOD_M1, 1);
   double low   = iLow(_Symbol, PERIOD_M1, 1);
   double vol   = (double)iVolume(_Symbol, PERIOD_M1, 1);

   if(vol <= 0) vol = 1;
   double range = high - low;
   if(range <= 0) range = _Point;

   // Buy pressure = (close - low) / range * volume
   // Sell pressure = (high - close) / range * volume
   double buyPressure  = (close - low) / range * vol;
   double sellPressure = (high - close) / range * vol;
   double delta = buyPressure - sellPressure;

   // Add to raw CVD array
   int size = ArraySize(g_cvdRaw);
   ArrayResize(g_cvdRaw, size + 1);
   g_cvdRaw[size] = delta;

   // Keep only last CVD_Period * 3 bars
   int maxSize = CVD_Period * 3;
   if(ArraySize(g_cvdRaw) > maxSize)
   {
      int excess = ArraySize(g_cvdRaw) - maxSize;
      for(int i = 0; i < maxSize; i++)
         g_cvdRaw[i] = g_cvdRaw[i + excess];
      ArrayResize(g_cvdRaw, maxSize);
   }

   // Calculate cumulative sum over CVD_Period
   g_cvdPrev = g_cvd;
   g_cvd = 0;
   int start = MathMax(0, ArraySize(g_cvdRaw) - CVD_Period);
   for(int i = start; i < ArraySize(g_cvdRaw); i++)
      g_cvd += g_cvdRaw[i];

   // Smooth with EMA
   if(g_cvdSmoothed == 0)
      g_cvdSmoothed = g_cvd;
   else
   {
      g_cvdSmoothedPrev = g_cvdSmoothed;
      double alpha = 2.0 / (CVD_Smooth + 1.0);
      g_cvdSmoothed = alpha * g_cvd + (1.0 - alpha) * g_cvdSmoothed;
   }
}

//+------------------------------------------------------------------+
//| S/R LEVEL DETECTION (M5 Swing Highs/Lows)                       |
//+------------------------------------------------------------------+
void UpdateSRLevels()
{
   int barsNeeded = SR_SwingBars * 2 + 1;
   double highs[], lows[];
   ArrayResize(highs, barsNeeded);
   ArrayResize(lows, barsNeeded);

   for(int i = 0; i < barsNeeded; i++)
   {
      highs[i] = iHigh(_Symbol, PERIOD_M5, i + 1);
      lows[i]  = iLow(_Symbol, PERIOD_M5, i + 1);
   }

   int mid = SR_SwingBars;

   // Check for swing high
   bool isSwingHigh = true;
   for(int i = 0; i < barsNeeded; i++)
   {
      if(i == mid) continue;
      if(highs[i] >= highs[mid]) { isSwingHigh = false; break; }
   }

   if(isSwingHigh)
      AddSRLevel(highs[mid], false);

   // Check for swing low
   bool isSwingLow = true;
   for(int i = 0; i < barsNeeded; i++)
   {
      if(i == mid) continue;
      if(lows[i] <= lows[mid]) { isSwingLow = false; break; }
   }

   if(isSwingLow)
      AddSRLevel(lows[mid], true);
}

//+------------------------------------------------------------------+
void AddSRLevel(double price, bool isSupport)
{
   // Check if near existing level
   for(int i = 0; i < g_srCount; i++)
   {
      if(MathAbs(g_sr[i].price - price) < SR_MergePts * _Point)
      {
         g_sr[i].price = (g_sr[i].price + price) / 2.0; // average
         g_sr[i].touches++;
         g_sr[i].lastTouch = TimeCurrent();
         g_sr[i].swept = false;
         return;
      }
   }

   // Add new level
   if(g_srCount >= SR_MaxLevels)
   {
      // Remove oldest/weakest
      int weakest = 0;
      for(int i = 1; i < g_srCount; i++)
         if(g_sr[i].touches < g_sr[weakest].touches)
            weakest = i;

      g_sr[weakest] = g_sr[g_srCount - 1];
      g_srCount--;
   }

   ArrayResize(g_sr, g_srCount + 1);
   g_sr[g_srCount].price     = price;
   g_sr[g_srCount].touches   = 1;
   g_sr[g_srCount].isSupport = isSupport;
   g_sr[g_srCount].lastTouch = TimeCurrent();
   g_sr[g_srCount].swept     = false;
   g_srCount++;
}

//+------------------------------------------------------------------+
//| LIQUIDITY SWEEP DETECTION (M1)                                   |
//+------------------------------------------------------------------+
void DetectLiquiditySweep()
{
   double close1 = iClose(_Symbol, PERIOD_M1, 1);
   double open1  = iOpen(_Symbol, PERIOD_M1, 1);
   double high1  = iHigh(_Symbol, PERIOD_M1, 1);
   double low1   = iLow(_Symbol, PERIOD_M1, 1);

   for(int i = 0; i < g_srCount; i++)
   {
      double sr = g_sr[i].price;

      // Sweep below support: wick goes below, body closes above
      if(g_sr[i].isSupport && !g_sr[i].swept)
      {
         double sweepDist = (sr - low1) / _Point;
         if(sweepDist >= SweepMinPts && sweepDist <= SweepMaxPts && close1 > sr)
         {
            g_sweepActive = true;
            g_sweepDir    = 1;  // buy signal
            g_sweepSR     = sr;
            g_sweepWick   = low1;
            g_sweepAge    = 0;
            g_sr[i].swept = true;
            Print("LIQUIDITY SWEEP detected BELOW support ", DoubleToString(sr, _Digits));
         }
      }

      // Sweep above resistance: wick goes above, body closes below
      if(!g_sr[i].isSupport && !g_sr[i].swept)
      {
         double sweepDist = (high1 - sr) / _Point;
         if(sweepDist >= SweepMinPts && sweepDist <= SweepMaxPts && close1 < sr)
         {
            g_sweepActive = true;
            g_sweepDir    = -1; // sell signal
            g_sweepSR     = sr;
            g_sweepWick   = high1;
            g_sweepAge    = 0;
            g_sr[i].swept = true;
            Print("LIQUIDITY SWEEP detected ABOVE resistance ", DoubleToString(sr, _Digits));
         }
      }
   }
}

//+------------------------------------------------------------------+
//| FVG DETECTION (M1)                                               |
//+------------------------------------------------------------------+
void DetectFVG()
{
   // Scan M1 bars for Fair Value Gaps
   // Bullish FVG: bar[3].high < bar[1].low (gap between bar 3 high and bar 1 low)
   // Bearish FVG: bar[1].high < bar[3].low

   for(int shift = 1; shift <= FVG_Lookback; shift++)
   {
      double high3 = iHigh(_Symbol, PERIOD_M1, shift + 2);
      double low1  = iLow(_Symbol, PERIOD_M1, shift);
      double low3  = iLow(_Symbol, PERIOD_M1, shift + 2);
      double high1 = iHigh(_Symbol, PERIOD_M1, shift);

      // Check middle bar is displacement (large body)
      double midOpen  = iOpen(_Symbol, PERIOD_M1, shift + 1);
      double midClose = iClose(_Symbol, PERIOD_M1, shift + 1);
      double midBody  = MathAbs(midClose - midOpen);

      // Bullish FVG
      if(low1 > high3)
      {
         double width = (low1 - high3) / _Point;
         if(width >= FVG_MinWidth_Pts && midClose > midOpen)
         {
            AddFVG(low1, high3, true, shift + 1);
         }
      }

      // Bearish FVG
      if(high1 < low3)
      {
         double width = (low3 - high1) / _Point;
         if(width >= FVG_MinWidth_Pts && midClose < midOpen)
         {
            AddFVG(low3, high1, false, shift + 1);
         }
      }
   }
}

void AddFVG(double top, double bottom, bool bullish, int barIdx)
{
   // Check for duplicate
   for(int i = 0; i < g_fvgCount; i++)
   {
      if(MathAbs(g_fvg[i].top - top) < 10 * _Point &&
         MathAbs(g_fvg[i].bottom - bottom) < 10 * _Point)
         return;
   }

   // Limit array size
   if(g_fvgCount >= 20)
   {
      // Remove oldest
      for(int i = 0; i < g_fvgCount - 1; i++)
         g_fvg[i] = g_fvg[i + 1];
      g_fvgCount--;
   }

   ArrayResize(g_fvg, g_fvgCount + 1);
   g_fvg[g_fvgCount].top      = top;
   g_fvg[g_fvgCount].bottom   = bottom;
   g_fvg[g_fvgCount].bullish  = bullish;
   g_fvg[g_fvgCount].barIndex = barIdx;
   g_fvg[g_fvgCount].filled   = false;
   g_fvgCount++;
}

//+------------------------------------------------------------------+
//| ORDER BLOCK DETECTION (M5)                                       |
//+------------------------------------------------------------------+
void DetectOrderBlocks()
{
   for(int shift = 2; shift <= OB_Lookback; shift++)
   {
      double obOpen  = iOpen(_Symbol, PERIOD_M5, shift);
      double obClose = iClose(_Symbol, PERIOD_M5, shift);
      double obHigh  = iHigh(_Symbol, PERIOD_M5, shift);
      double obLow   = iLow(_Symbol, PERIOD_M5, shift);
      double obBody  = MathAbs(obClose - obOpen);

      // Displacement candle (next bar)
      double dispOpen  = iOpen(_Symbol, PERIOD_M5, shift - 1);
      double dispClose = iClose(_Symbol, PERIOD_M5, shift - 1);
      double dispBody  = MathAbs(dispClose - dispOpen);

      if(obBody <= 0) continue;

      // Bullish OB: bearish candle followed by strong bullish displacement
      if(obClose < obOpen && dispClose > dispOpen && dispBody > obBody * OB_Disp_Multi)
      {
         AddOB(obHigh, obLow, true, shift);
      }

      // Bearish OB: bullish candle followed by strong bearish displacement
      if(obClose > obOpen && dispClose < dispOpen && dispBody > obBody * OB_Disp_Multi)
      {
         AddOB(obHigh, obLow, false, shift);
      }
   }
}

void AddOB(double high, double low, bool bullish, int barIdx)
{
   for(int i = 0; i < g_obCount; i++)
   {
      if(MathAbs(g_ob[i].high - high) < 20 * _Point &&
         MathAbs(g_ob[i].low - low) < 20 * _Point)
         return;
   }

   if(g_obCount >= 15)
   {
      for(int i = 0; i < g_obCount - 1; i++)
         g_ob[i] = g_ob[i + 1];
      g_obCount--;
   }

   ArrayResize(g_ob, g_obCount + 1);
   g_ob[g_obCount].high      = high;
   g_ob[g_obCount].low       = low;
   g_ob[g_obCount].bullish   = bullish;
   g_ob[g_obCount].barIndex  = barIdx;
   g_ob[g_obCount].mitigated = false;
   g_obCount++;
}

//+------------------------------------------------------------------+
//| STRUCTURE TRACKING (BOS / CHoCH on M5)                           |
//+------------------------------------------------------------------+
void UpdateStructure()
{
   // Find recent swing highs and lows on M5
   double highs[], lows[];
   int bars = Structure_Lookback;
   ArrayResize(highs, bars);
   ArrayResize(lows, bars);

   for(int i = 0; i < bars; i++)
   {
      highs[i] = iHigh(_Symbol, PERIOD_M5, i + 1);
      lows[i]  = iLow(_Symbol, PERIOD_M5, i + 1);
   }

   // Find the last 4 swing points
   ArrayResize(g_swings, 0);
   g_swingCount = 0;

   for(int i = 2; i < bars - 2; i++)
   {
      // Swing high
      if(highs[i] > highs[i-1] && highs[i] > highs[i-2] &&
         highs[i] > highs[i+1] && highs[i] > highs[i+2])
      {
         ArrayResize(g_swings, g_swingCount + 1);
         g_swings[g_swingCount].price  = highs[i];
         g_swings[g_swingCount].time   = iTime(_Symbol, PERIOD_M5, i + 1);
         g_swings[g_swingCount].isHigh = true;
         g_swingCount++;
      }
      // Swing low
      if(lows[i] < lows[i-1] && lows[i] < lows[i-2] &&
         lows[i] < lows[i+1] && lows[i] < lows[i+2])
      {
         ArrayResize(g_swings, g_swingCount + 1);
         g_swings[g_swingCount].price  = lows[i];
         g_swings[g_swingCount].time   = iTime(_Symbol, PERIOD_M5, i + 1);
         g_swings[g_swingCount].isHigh = false;
         g_swingCount++;
      }

      if(g_swingCount >= 6) break;
   }

   // Determine structure bias
   // BOS = break of structure in trend direction
   // CHoCH = change of character (first opposite break)
   double close = iClose(_Symbol, PERIOD_M5, 1);

   // Find last swing high and swing low
   double lastSwH = 0, lastSwL = 999999;
   for(int i = 0; i < g_swingCount; i++)
   {
      if(g_swings[i].isHigh && g_swings[i].price > lastSwH)
         lastSwH = g_swings[i].price;
      if(!g_swings[i].isHigh && g_swings[i].price < lastSwL)
         lastSwL = g_swings[i].price;
   }

   int prevBias = g_structureBias;

   // Bullish BOS: close breaks above last swing high
   if(close > lastSwH + BOS_MinPts * _Point && lastSwH > 0)
      g_structureBias = 1;

   // Bearish BOS: close breaks below last swing low
   if(close < lastSwL - BOS_MinPts * _Point && lastSwL < 999999)
      g_structureBias = -1;

   if(prevBias != g_structureBias && g_structureBias != 0)
      Print("Structure shift: ", g_structureBias > 0 ? "BULLISH" : "BEARISH",
            " | Last SwH: ", lastSwH, " | Last SwL: ", lastSwL);
}

//+------------------------------------------------------------------+
//| PRICE ACTION PATTERNS (M1)                                       |
//+------------------------------------------------------------------+
int DetectPattern()
{
   // Returns: 1 = bullish pattern, -1 = bearish pattern, 0 = none

   double open1  = iOpen(_Symbol, PERIOD_M1, 1);
   double close1 = iClose(_Symbol, PERIOD_M1, 1);
   double high1  = iHigh(_Symbol, PERIOD_M1, 1);
   double low1   = iLow(_Symbol, PERIOD_M1, 1);
   double body1  = MathAbs(close1 - open1);

   double open2  = iOpen(_Symbol, PERIOD_M1, 2);
   double close2 = iClose(_Symbol, PERIOD_M1, 2);
   double high2  = iHigh(_Symbol, PERIOD_M1, 2);
   double low2   = iLow(_Symbol, PERIOD_M1, 2);
   double body2  = MathAbs(close2 - open2);

   if(body1 <= 0) return 0;
   if(body2 <= 0) body2 = _Point;

   // Bullish Engulfing
   if(close2 < open2 && close1 > open1 &&           // prev bearish, curr bullish
      body1 > body2 * Engulf_MinRatio &&             // current body engulfs
      close1 > open2 && open1 < close2)              // body engulfs prev body
      return 1;

   // Bearish Engulfing
   if(close2 > open2 && close1 < open1 &&
      body1 > body2 * Engulf_MinRatio &&
      close1 < open2 && open1 > close2)
      return -1;

   // Bullish Pin Bar / Hammer
   double lowerWick1 = MathMin(open1, close1) - low1;
   double upperWick1 = high1 - MathMax(open1, close1);
   if(lowerWick1 > body1 * PinBar_WickRatio &&
      lowerWick1 > PinBar_MinWickPts * _Point &&
      upperWick1 < body1)
      return 1;

   // Bearish Pin Bar / Shooting Star
   if(upperWick1 > body1 * PinBar_WickRatio &&
      upperWick1 > PinBar_MinWickPts * _Point &&
      lowerWick1 < body1)
      return -1;

   // Morning Star (3-bar bullish reversal)
   double open3  = iOpen(_Symbol, PERIOD_M1, 3);
   double close3 = iClose(_Symbol, PERIOD_M1, 3);
   double body3  = MathAbs(close3 - open3);

   if(close3 < open3 && body3 > body2 * 2 &&        // bar 3: big bearish
      body2 < body3 * 0.3 &&                          // bar 2: small body (doji-like)
      close1 > open1 && close1 > (open3 + close3)/2)  // bar 1: bullish, closes above midpoint
      return 1;

   // Evening Star (3-bar bearish reversal)
   if(close3 > open3 && body3 > body2 * 2 &&
      body2 < body3 * 0.3 &&
      close1 < open1 && close1 < (open3 + close3)/2)
      return -1;

   return 0;
}

//+------------------------------------------------------------------+
//| CONFLUENCE EVALUATION & ENTRY                                     |
//+------------------------------------------------------------------+
void EvaluateEntry()
{
   int score = 0;
   int direction = 0;  // will be determined by majority of signals
   int buySignals = 0, sellSignals = 0;

   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double close1 = iClose(_Symbol, PERIOD_M1, 1);

   // Get indicator values
   double fastEMA[], slowEMA[], trendM5[], trendM15[], atr[];
   ArraySetAsSeries(fastEMA, true);
   ArraySetAsSeries(slowEMA, true);
   ArraySetAsSeries(trendM5, true);
   ArraySetAsSeries(trendM15, true);
   ArraySetAsSeries(atr, true);

   if(CopyBuffer(h_fastEMA, 0, 0, 3, fastEMA) < 3) return;
   if(CopyBuffer(h_slowEMA, 0, 0, 3, slowEMA) < 3) return;
   if(CopyBuffer(h_trendEMA_M5, 0, 0, 2, trendM5) < 2) return;
   if(CopyBuffer(h_trendEMA_M15, 0, 0, 2, trendM15) < 2) return;
   if(CopyBuffer(h_atr_M1, 0, 0, 2, atr) < 2) return;

   double currentATR = atr[0];
   if(currentATR <= 0) return;

   //=== SIGNAL 1: EMA Trend Alignment (require FRESH crossover within 5 bars) ===
   bool freshCrossBuy  = (g_prevFastEMA <= g_prevSlowEMA && fastEMA[1] > slowEMA[1]) ||
                          (fastEMA[1] > slowEMA[1] && fastEMA[2] <= slowEMA[2]);
   bool freshCrossSell = (g_prevFastEMA >= g_prevSlowEMA && fastEMA[1] < slowEMA[1]) ||
                          (fastEMA[1] < slowEMA[1] && fastEMA[2] >= slowEMA[2]);

   // Also accept if EMA cross happened within last 5 M1 bars and trend aligns
   if(!freshCrossBuy && fastEMA[1] > slowEMA[1])
   {
      for(int k = 2; k <= 5; k++)
      {
         double fk[], sk[];
         ArraySetAsSeries(fk, true); ArraySetAsSeries(sk, true);
         if(CopyBuffer(h_fastEMA, 0, k, 1, fk) >= 1 && CopyBuffer(h_slowEMA, 0, k, 1, sk) >= 1)
            if(fk[0] <= sk[0]) { freshCrossBuy = true; break; }
      }
   }
   if(!freshCrossSell && fastEMA[1] < slowEMA[1])
   {
      for(int k = 2; k <= 5; k++)
      {
         double fk[], sk[];
         ArraySetAsSeries(fk, true); ArraySetAsSeries(sk, true);
         if(CopyBuffer(h_fastEMA, 0, k, 1, fk) >= 1 && CopyBuffer(h_slowEMA, 0, k, 1, sk) >= 1)
            if(fk[0] >= sk[0]) { freshCrossSell = true; break; }
      }
   }

   bool emaBuy  = freshCrossBuy && close1 > trendM5[0] && close1 > trendM15[0];
   bool emaSell = freshCrossSell && close1 < trendM5[0] && close1 < trendM15[0];

   if(emaBuy)  { buySignals++;  score++; }
   if(emaSell) { sellSignals++; score++; }

   // Update previous EMA values for next bar
   g_prevFastEMA = fastEMA[1];
   g_prevSlowEMA = slowEMA[1];

   //=== SIGNAL 2: VWAP (stricter - require pullback to VWAP zone) ===
   if(UseVWAP && g_vwap > 0)
   {
      double vwapDist = (close1 - g_vwap) / _Point;

      // Buy: price just crossed above VWAP (pullback bounce) — within tight band
      if(close1 > g_vwap && vwapDist > 0 && vwapDist < VWAP_BandPts * 2)
      {
         // Confirm previous bar was below or near VWAP
         double prevClose = iClose(_Symbol, PERIOD_M1, 2);
         if(prevClose <= g_vwap + VWAP_BandPts * _Point)
            buySignals++;
      }
      // Sell: price just crossed below VWAP (rejection)
      if(close1 < g_vwap && MathAbs(vwapDist) > 0 && MathAbs(vwapDist) < VWAP_BandPts * 2)
      {
         double prevClose = iClose(_Symbol, PERIOD_M1, 2);
         if(prevClose >= g_vwap - VWAP_BandPts * _Point)
            sellSignals++;
      }

      if(buySignals > sellSignals || sellSignals > buySignals)
         score++;
   }

   //=== SIGNAL 3: CVD (Volume Delta) - require strong delta ===
   if(UseCVD && ArraySize(g_cvdRaw) >= CVD_Period)
   {
      // CVD rising = buying pressure, CVD falling = selling pressure
      // Require meaningful delta magnitude (not just barely positive/negative)
      double cvdMagnitude = MathAbs(g_cvdSmoothed);
      double cvdThreshold = 10.0;  // min CVD magnitude

      bool cvdBullish = g_cvdSmoothed > g_cvdSmoothedPrev && g_cvd > cvdThreshold;
      bool cvdBearish = g_cvdSmoothed < g_cvdSmoothedPrev && g_cvd < -cvdThreshold;

      if(cvdBullish)  buySignals++;
      if(cvdBearish)  sellSignals++;

      if(cvdBullish || cvdBearish) score++;
   }

   //=== SIGNAL 4: ICT - Liquidity Sweep + Structure ===
   if(g_sweepActive)
   {
      if(g_sweepDir == 1 && g_structureBias >= 0)    // sweep below support + bullish/neutral
         buySignals++;
      if(g_sweepDir == -1 && g_structureBias == -1)  // sweep above resistance + MUST be bearish
         sellSignals++;
      score++;
   }

   //=== SIGNAL 5: FVG or Order Block proximity ===
   bool inBullFVG = false, inBearFVG = false;
   bool inBullOB = false, inBearOB = false;

   // Check FVG
   for(int i = 0; i < g_fvgCount; i++)
   {
      if(g_fvg[i].filled) continue;
      double dist = 0;
      if(g_fvg[i].bullish)
      {
         dist = MathAbs(close1 - g_fvg[i].top) / currentATR;
         if(close1 >= g_fvg[i].bottom && close1 <= g_fvg[i].top + currentATR * 0.5)
         {
            if(dist <= FVG_MaxDist_ATR) inBullFVG = true;
         }
         // Mark as filled if price passed through
         if(close1 < g_fvg[i].bottom) g_fvg[i].filled = true;
      }
      else
      {
         dist = MathAbs(close1 - g_fvg[i].bottom) / currentATR;
         if(close1 <= g_fvg[i].top && close1 >= g_fvg[i].bottom - currentATR * 0.5)
         {
            if(dist <= FVG_MaxDist_ATR) inBearFVG = true;
         }
         if(close1 > g_fvg[i].top) g_fvg[i].filled = true;
      }
   }

   // Check Order Blocks
   for(int i = 0; i < g_obCount; i++)
   {
      if(g_ob[i].mitigated) continue;
      if(g_ob[i].bullish)
      {
         double dist = MathAbs(close1 - g_ob[i].high) / currentATR;
         if(close1 >= g_ob[i].low && close1 <= g_ob[i].high + currentATR * 0.3 && dist <= OB_MaxDist_ATR)
            inBullOB = true;
         if(close1 < g_ob[i].low - currentATR) g_ob[i].mitigated = true;
      }
      else
      {
         double dist = MathAbs(close1 - g_ob[i].low) / currentATR;
         if(close1 <= g_ob[i].high && close1 >= g_ob[i].low - currentATR * 0.3 && dist <= OB_MaxDist_ATR)
            inBearOB = true;
         if(close1 > g_ob[i].high + currentATR) g_ob[i].mitigated = true;
      }
   }

   if(inBullFVG || inBullOB)  buySignals++;
   if(inBearFVG || inBearOB)  sellSignals++;
   if(inBullFVG || inBearFVG || inBullOB || inBearOB) score++;

   //=== SIGNAL 6: Price Action Pattern ===
   int pattern = DetectPattern();
   if(pattern == 1)   buySignals++;
   if(pattern == -1)  sellSignals++;
   if(pattern != 0)   score++;

   //=== RSI EXTREME FILTER (don't chase) ===
   double rsiVal[];
   ArraySetAsSeries(rsiVal, true);
   if(CopyBuffer(h_rsi, 0, 0, 2, rsiVal) >= 2)
   {
      if(rsiVal[1] > 75) buySignals  = 0;  // overbought, kill buy signals
      if(rsiVal[1] < 25) sellSignals = 0;  // oversold, kill sell signals
      // RSI in favorable zone adds to score
      if(rsiVal[1] > 40 && rsiVal[1] < 60) score++;  // neutral zone = good for reversal entries
   }

   //=== DETERMINE DIRECTION ===
   if(buySignals > sellSignals && buySignals >= 3)
      direction = 1;
   else if(sellSignals > buySignals && sellSignals >= 3)
      direction = -1;
   else
      return;  // no clear direction

   //=== CHECK MINIMUM CONFLUENCE ===
   // Sells require +1 confluence (they underperform historically)
   int requiredConf = MinConfluence;
   if(direction == -1) requiredConf = MinConfluence + 1;
   if(score < requiredConf) return;

   //=== CALCULATE SL/TP ===
   double slDist = currentATR * SL_ATR_Multi;
   slDist = MathMax(slDist, MinSL_Points * _Point);
   slDist = MathMin(slDist, MaxSL_Points * _Point);

   double tp = slDist * RiskReward;

   double sl, takeProfit, entry;

   if(direction == 1) // BUY
   {
      entry      = ask;
      sl         = entry - slDist;
      takeProfit = entry + tp;

      // If sweep detected, place SL below sweep wick
      if(g_sweepActive && g_sweepDir == 1 && g_sweepWick > 0)
      {
         double sweepSL = g_sweepWick - 20 * _Point;
         double sweepDist = entry - sweepSL;
         if(sweepDist > MinSL_Points * _Point && sweepDist < MaxSL_Points * _Point)
         {
            sl = sweepSL;
            slDist = entry - sl;
            takeProfit = entry + slDist * RiskReward;
         }
      }

      // Use next resistance as TP if enabled and better
      if(UseNextSR_TP)
      {
         double nextRes = FindNextSR(entry, true);
         if(nextRes > 0 && nextRes > entry + slDist * 1.5)
            takeProfit = nextRes - 20 * _Point; // slightly below resistance
      }
   }
   else // SELL
   {
      entry      = bid;
      sl         = entry + slDist;
      takeProfit = entry - tp;

      if(g_sweepActive && g_sweepDir == -1 && g_sweepWick > 0)
      {
         double sweepSL = g_sweepWick + 20 * _Point;
         double sweepDist = sweepSL - entry;
         if(sweepDist > MinSL_Points * _Point && sweepDist < MaxSL_Points * _Point)
         {
            sl = sweepSL;
            slDist = sl - entry;
            takeProfit = entry - slDist * RiskReward;
         }
      }

      if(UseNextSR_TP)
      {
         double nextSup = FindNextSR(entry, false);
         if(nextSup > 0 && nextSup < entry - slDist * 1.5)
            takeProfit = nextSup + 20 * _Point;
      }
   }

   //=== POSITION SIZING ===
   double lots = CalculateLotSize(slDist);
   if(lots <= 0) return;

   //=== EXECUTE TRADE ===
   string comment = StringFormat("GES|C%d|B%d|S%d", score, buySignals, sellSignals);

   bool result = false;
   if(direction == 1)
      result = trade.Buy(lots, _Symbol, entry, sl, takeProfit, comment);
   else
      result = trade.Sell(lots, _Symbol, entry, sl, takeProfit, comment);

   if(result)
   {
      g_inTrade       = true;
      g_tradeEntry    = entry;
      g_tradeSL       = sl;
      g_tradeTP       = takeProfit;
      g_slDistance     = slDist;
      g_trailingActive = false;
      g_beApplied     = false;
      g_dailyTrades++;
      g_lastTradeTime = TimeCurrent();

      Print("ENTRY ", direction > 0 ? "BUY" : "SELL",
            " | Confluence: ", score, "/6",
            " | Lots: ", lots,
            " | SL: ", DoubleToString(sl, _Digits),
            " | TP: ", DoubleToString(takeProfit, _Digits),
            " | ATR: ", DoubleToString(currentATR/_Point, 0), "pts",
            " | VWAP: ", DoubleToString(g_vwap, _Digits),
            " | CVD: ", DoubleToString(g_cvdSmoothed, 1),
            " | Struct: ", g_structureBias > 0 ? "Bull" : (g_structureBias < 0 ? "Bear" : "Neutral"),
            " | Sweep: ", g_sweepActive ? "YES" : "NO",
            " | Pattern: ", pattern);
   }
   else
   {
      // Order failed - set cooldown to avoid spamming
      g_lastTradeTime = TimeCurrent();
   }
}

//+------------------------------------------------------------------+
//| FIND NEXT S/R LEVEL                                              |
//+------------------------------------------------------------------+
double FindNextSR(double fromPrice, bool lookAbove)
{
   double best = 0;
   double bestDist = 999999;

   for(int i = 0; i < g_srCount; i++)
   {
      if(lookAbove && g_sr[i].price > fromPrice)
      {
         double dist = g_sr[i].price - fromPrice;
         if(dist < bestDist) { bestDist = dist; best = g_sr[i].price; }
      }
      if(!lookAbove && g_sr[i].price < fromPrice)
      {
         double dist = fromPrice - g_sr[i].price;
         if(dist < bestDist) { bestDist = dist; best = g_sr[i].price; }
      }
   }
   return best;
}

//+------------------------------------------------------------------+
//| POSITION SIZING (Risk-based)                                     |
//+------------------------------------------------------------------+
double CalculateLotSize(double slDistance)
{
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double riskAmount = balance * RiskPercent / 100.0;

   // Also check: remaining daily risk budget
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   double dailyUsed = g_dayStartBalance - equity;
   double dailyBudget = g_dayStartBalance * DailyLossLimit / 100.0;
   double remaining = dailyBudget - dailyUsed;

   if(remaining < riskAmount)
      riskAmount = remaining * 0.8;  // only use 80% of remaining daily budget

   if(riskAmount <= 0) return 0;

   double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double tickSize  = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);

   if(tickValue <= 0 || tickSize <= 0) return 0;

   double lots = riskAmount / (slDistance / tickSize * tickValue);

   // Normalize
   double minLot  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxLot  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);

   lots = MathFloor(lots / lotStep) * lotStep;
   lots = MathMax(lots, minLot);
   lots = MathMin(lots, maxLot);

   // Final safety: for no-leverage gold account
   // 1 lot XAUUSD = 100 oz, at ~$2600/oz = $260K margin needed
   // 0.01 lot = $2,600 margin. On $10K max ~0.03-0.05 lots
   double maxAffordable = AccountInfoDouble(ACCOUNT_MARGIN_FREE) /
                          (SymbolInfoDouble(_Symbol, SYMBOL_TRADE_CONTRACT_SIZE) *
                           SymbolInfoDouble(_Symbol, SYMBOL_ASK));
   if(maxAffordable > 0)
   {
      maxAffordable = MathFloor(maxAffordable / lotStep) * lotStep;
      if(lots > maxAffordable * 0.8)  // use max 80% of free margin
         lots = MathFloor(maxAffordable * 0.8 / lotStep) * lotStep;
   }

   // Hard cap for safety (scales with account size)
   double lotCap = MathFloor(balance / 10000.0) * 0.05;  // 0.05 per $10K
   if(lotCap < 0.01) lotCap = 0.01;
   if(lotCap > 0.50) lotCap = 0.50;
   if(lots > lotCap) lots = lotCap;
   if(lots < minLot) return 0;

   return lots;
}

//+------------------------------------------------------------------+
//| POSITION MANAGEMENT (BE + Trail + Session Close)                  |
//+------------------------------------------------------------------+
void ManagePositions(MqlDateTime &dt)
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      if(PositionGetInteger(POSITION_MAGIC) != MagicNumber) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;

      g_inTrade = true;

      double posOpen = PositionGetDouble(POSITION_PRICE_OPEN);
      double posSL   = PositionGetDouble(POSITION_SL);
      double posTP   = PositionGetDouble(POSITION_TP);
      long   posType = PositionGetInteger(POSITION_TYPE);

      double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);

      double profit = PositionGetDouble(POSITION_PROFIT);
      double currentPrice = (posType == POSITION_TYPE_BUY) ? bid : ask;

      // Use stored SL distance for R calculations
      if(g_slDistance <= 0)
         g_slDistance = MathAbs(posOpen - posSL);

      if(g_slDistance <= 0) continue;

      double rMultiple = 0;
      if(posType == POSITION_TYPE_BUY)
         rMultiple = (bid - posOpen) / g_slDistance;
      else
         rMultiple = (posOpen - ask) / g_slDistance;

      //--- Breakeven
      if(!g_beApplied && rMultiple >= BE_Trigger_RR)
      {
         double newSL;
         if(posType == POSITION_TYPE_BUY)
            newSL = posOpen + BE_Lock_Points * _Point;
         else
            newSL = posOpen - BE_Lock_Points * _Point;

         if(trade.PositionModify(ticket, newSL, posTP))
         {
            g_beApplied = true;
            Print("BE applied at ", rMultiple, "R");
         }
      }

      //--- Trailing
      if(rMultiple >= Trail_Trigger_RR)
      {
         g_trailingActive = true;

         double trailSL;
         if(posType == POSITION_TYPE_BUY)
         {
            trailSL = bid - Trail_Step_Pts * _Point;
            if(trailSL > posSL + _Point)
               trade.PositionModify(ticket, trailSL, posTP);
         }
         else
         {
            trailSL = ask + Trail_Step_Pts * _Point;
            if(trailSL < posSL - _Point)
               trade.PositionModify(ticket, trailSL, posTP);
         }
      }

      //--- Close at session end
      if(CloseAtSessionEnd && dt.hour >= NY_End)
      {
         Print("Session end - closing position");
         trade.PositionClose(ticket);
         g_inTrade = false;
      }
   }

   // Check if we still have positions
   if(g_inTrade)
   {
      bool found = false;
      for(int i = 0; i < PositionsTotal(); i++)
      {
         ulong ticket = PositionGetTicket(i);
         if(ticket == 0) continue;
         if(PositionGetInteger(POSITION_MAGIC) == MagicNumber &&
            PositionGetString(POSITION_SYMBOL) == _Symbol)
         {
            found = true;
            break;
         }
      }
      if(!found)
      {
         g_inTrade = false;
         g_trailingActive = false;
         g_beApplied = false;
      }
   }
}

//+------------------------------------------------------------------+
