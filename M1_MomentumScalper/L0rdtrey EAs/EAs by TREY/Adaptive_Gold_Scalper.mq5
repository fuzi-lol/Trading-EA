//+------------------------------------------------------------------+
//|                                       Adaptive_Gold_Scalper.mq5   |
//|   Fully autonomous, regime-adaptive XAUUSD scalping EA            |
//|                                                                    |
//|   ARCHITECTURE                                                     |
//|   1. Regime Detector  -> classifies Trend/Range/Breakout-Vol/      |
//|                          Session, using ADX, ATR percentile,       |
//|                          tick-volume vs average, server hour.      |
//|   2. Strategy Library -> 4 independent scalping strategies, each   |
//|                          with its own indicator set so signals     |
//|                          never get mixed/contradicted internally.  |
//|   3. Adaptive Selector-> scores each strategy's fit for the        |
//|                          current regime x a learned weight,        |
//|                          picks the best, requires confluence if    |
//|                          two strategies are close in score.        |
//|   4. Self-Learning    -> tracks rolling win-rate per                |
//|                          (strategy,regime) pair, updates weights    |
//|                          after every closed trade, persists to a   |
//|                          file so learning survives restarts.       |
//|   5. Risk Engine      -> % risk per trade, lot size derived from   |
//|                          ATR-based stop distance + equity, daily   |
//|                          loss breaker, max trades/day.             |
//|   6. Filters          -> spread cap, session/news blackout         |
//|                          windows, slippage cap.                    |
//|                                                                    |
//|   NOTE ON "ML": MQL5 cannot train a neural network live inside    |
//|   the terminal. The "self-learning" here is a real, working       |
//|   reinforcement-style weight-adaptation system (rolling win-rate  |
//|   feedback), not a deep-learning model. It genuinely improves     |
//|   strategy selection over time and persists between restarts.     |
//+------------------------------------------------------------------+
#property copyright "Adaptive Gold Scalper"
#property version   "1.00"
#property strict

#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>
#include <Trade\HistoryOrderInfo.mqh>
#include <Trade\DealInfo.mqh>

CTrade        trade;
CPositionInfo posInfo;
CDealInfo     dealInfo;

//==================================================================
// INPUTS
//==================================================================
input string   InpComment            = "AdaptGoldScalper";
input long     InpMagic              = 773311;

//--- Risk
input double   InpRiskPercent        = 0.5;     // % equity risked per trade
input double   InpATR_SL_Mult        = 1.5;     // SL = ATR * mult
input double   InpATR_TP_Mult        = 2.2;     // TP = ATR * mult
input double   InpMaxDailyLossPct    = 3.0;      // stop trading for the day past this loss
input int      InpMaxTradesPerDay    = 20;
input double   InpMaxSpreadPoints    = 350;      // gold spread filter (points)
input int      InpSlippagePoints     = 30;

//--- Trailing
input bool     InpUseTrailing        = true;
input double   InpTrailATRMult       = 1.0;
input double   InpTrailStartATRMult  = 0.8;

//--- Regime detection
input int      InpATRPeriod          = 14;
input int      InpATRLookback        = 200;      // bars used to build ATR percentile
input int      InpADXPeriod          = 14;
input double   InpADXTrendLevel      = 25.0;
input int      InpVolAvgPeriod       = 50;       // tick-volume average period

//--- Strategy indicator params
input int      InpEMAFast            = 8;
input int      InpEMASlow            = 21;
input int      InpMACDFast           = 12;
input int      InpMACDSlow           = 26;
input int      InpMACDSignal         = 9;
input int      InpBBPeriod           = 20;
input double   InpBBDeviation        = 2.0;
input int      InpRSIPeriod          = 7;
input double   InpRSIOversold        = 30;
input double   InpRSIOverbought      = 70;
input int      InpDonchianPeriod     = 20;

//--- Adaptive learning
input double   InpLearningRate       = 0.15;     // 0..1, how fast weights move
input double   InpMinWeight          = 0.15;
input double   InpMaxWeight          = 3.0;
input string   InpWeightFile         = "AdaptGoldScalper_weights.bin";

//--- Session blackout (server time, "HH:MM-HH:MM,HH:MM-HH:MM" or "" for none)
input string   InpBlackoutWindows    = "";

//--- Liquidity / Smart-Money (SMC) engine
input int      InpSwingLookback      = 3;     // bars each side to confirm a fractal swing
input int      InpSwingDepth         = 80;    // bars scanned back for swings/structure
input double   InpSweepWickMinPts    = 80;    // min wick beyond level (points) to count as a sweep
input int      InpSweepValidBars     = 5;     // sweep signal stays valid this many bars
input double   InpImpulseATRMult     = 1.5;   // move size (xATR) that defines an "impulse" for OB tagging
input double   InpFVGMinPts          = 60;    // min gap size (points) to register a Fair Value Gap
input double   InpEqualLevelTolPts   = 50;    // points tolerance to cluster swings into one liquidity pool

//--- New strategy params (Phase 3)
input double   InpVWAPDevATRMult     = 1.8;   // VWAP reversion trigger distance (xATR)
input double   InpPullbackATRMult    = 0.4;   // pullback proximity to fast EMA (xATR)
input double   InpCompressionPctile  = 0.25;  // ATR percentile ceiling for "compression" regime
input int      InpVolCompPeriod      = 20;    // range period for compression breakout

//--- Session Intelligence (Phase 4)
input double   InpFridayRiskReduce   = 0.5;   // Friday lot multiplier (0.5 = half size)
input int      InpFridayFlatHour     = 20;    // server-time hour after which no NEW trades open on Friday
input double   InpLondonNYBonusScore = 10.0;  // additional quality score during overlap
input bool     InpUseCorrelationFilt = false; // enable DXY-based correlation filter
input string   InpDXYSymbol          = "EURUSD"; // proxy for DXY inverse (or use GOLD:DXY if available)

//--- Consecutive Loss Protection (Phase 4)
input int      InpConsecLossThreshold = 3;    // reduce lot size after this many losses
input double   InpConsecLossMultiplier = 0.6; // new lot size = normal * this multiplier
input int      InpConsecLossResetBars  = 20;  // reset counter after this many bars of no new losses

//--- Trade Quality Scoring Engine
input double   InpMinQualityScore    = 65.0;  // 0-100, trades below this are rejected
input double   InpWeightTrend        = 0.25;
input double   InpWeightLiquidity    = 0.25;
input double   InpWeightVolume       = 0.15;
input double   InpWeightSession      = 0.15;
input double   InpWeightVolatility   = 0.20;

//==================================================================
// CONSTANTS / ENUMS
//==================================================================
#define NUM_STRATEGIES 10
#define NUM_REGIMES    8   // 4 vol/trend states * 2 (session weight folded separately)

enum StrategyId
  {
   STRAT_TREND        = 0,  // EMA cross + MACD confirm
   STRAT_MEANREV      = 1,  // Bollinger + RSI
   STRAT_BREAKOUT     = 2,  // Donchian/ATR expansion
   STRAT_SESSION      = 3,  // session-open momentum
   STRAT_LIQSWEEP     = 4,  // liquidity sweep reversal (SMC engine)
   STRAT_VWAP_REV     = 5,  // VWAP institutional reversion
   STRAT_PULLBACK     = 6,  // trend pullback scalper
   STRAT_OB_CONT      = 7,  // order block continuation
   STRAT_FVG_REBAL    = 8,  // fair value gap rebalancing
   STRAT_VOLCOMP_BO   = 9   // volatility compression breakout
  };

enum RegimeId
  {
   REGIME_TREND_HIGHVOL   = 0,
   REGIME_TREND_LOWVOL    = 1,
   REGIME_RANGE_HIGHVOL   = 2,
   REGIME_RANGE_LOWVOL    = 3,
   REGIME_BREAKOUT        = 4,
   REGIME_ASIAN           = 5,
   REGIME_LONDON          = 6,
   REGIME_NEWYORK         = 7
  };

enum SignalDir { SIG_NONE=0, SIG_BUY=1, SIG_SELL=-1 };

//==================================================================
// GLOBAL STATE
//==================================================================
int hATR, hADX, hEMAFast, hEMASlow, hMACD, hBB, hRSI;

double g_weights[NUM_STRATEGIES][NUM_REGIMES];   // learned weights
// base affinity: how naturally suited each strategy is to each regime (designed prior)
double g_affinity[NUM_STRATEGIES][NUM_REGIMES];

datetime g_dayStart = 0;
double   g_dayStartEquity = 0;
int      g_tradesToday = 0;
bool     g_dailyLossHit = false;

// per-position bookkeeping (single position at a time, but array-ready for hedging accounts)
struct OpenTradeInfo
  {
   ulong     ticket;
   int       strategy;
   int       regime;
   double    entryATR;
  };
OpenTradeInfo g_openTrades[];

//==================================================================
// LIQUIDITY / SMC ENGINE STATE  (Phase 1)
//==================================================================
struct SwingPoint { datetime time; double price; int barShift; };
SwingPoint g_swingHighs[];
SwingPoint g_swingLows[];

enum StructureBias { STRUCT_BULL, STRUCT_BEAR, STRUCT_UNCLEAR };
StructureBias g_structure     = STRUCT_UNCLEAR;
StructureBias g_prevStructure = STRUCT_UNCLEAR;
bool          g_lastWasBOS    = false;   // true = continuation, false = CHOCH (flip)

enum SweepDir { SWEEP_NONE, SWEEP_BUYSIDE, SWEEP_SELLSIDE };
// BUYSIDE = price swept above a prior high (took out buy-side liquidity) then closed back below -> bearish bias
// SELLSIDE = price swept below a prior low (took out sell-side liquidity) then closed back above -> bullish bias
SweepDir g_lastSweep     = SWEEP_NONE;
int      g_lastSweepBar  = -999;
double   g_lastSweepLevel = 0;

struct SmcZone { double top; double bottom; datetime time; bool bullish; bool mitigated; };
SmcZone g_orderBlocks[];   // last opposite-colour candle before an impulse
SmcZone g_fvgZones[];      // 3-candle imbalance gaps

// Phase 5: equal-highs/equal-lows liquidity pools (clustered swing levels)
struct LiquidityPool { double level; int touches; bool isHigh; bool swept; };
LiquidityPool g_liqPools[];

// last computed regime metrics, reused by the trade quality scoring engine
double g_lastATRPercentile = 0.5;
double g_lastVolumeRatio   = 1.0;
double g_lastADX           = 0.0;

// consecutive loss protection (Phase 4)
int    g_consecutiveLosses = 0;
int    g_lastLossBar       = -999;
bool   g_inLondonNYOverlap = false;

//==================================================================
// INIT
//==================================================================
int OnInit()
  {
   trade.SetExpertMagicNumber(InpMagic);
   trade.SetDeviationInPoints(InpSlippagePoints);
   trade.SetTypeFillingBySymbol(_Symbol);

   hATR     = iATR(_Symbol, PERIOD_CURRENT, InpATRPeriod);
   hADX     = iADX(_Symbol, PERIOD_CURRENT, InpADXPeriod);
   hEMAFast = iMA(_Symbol, PERIOD_CURRENT, InpEMAFast, 0, MODE_EMA, PRICE_CLOSE);
   hEMASlow = iMA(_Symbol, PERIOD_CURRENT, InpEMASlow, 0, MODE_EMA, PRICE_CLOSE);
   hMACD    = iMACD(_Symbol, PERIOD_CURRENT, InpMACDFast, InpMACDSlow, InpMACDSignal, PRICE_CLOSE);
   hBB      = iBands(_Symbol, PERIOD_CURRENT, InpBBPeriod, 0, InpBBDeviation, PRICE_CLOSE);
   hRSI     = iRSI(_Symbol, PERIOD_CURRENT, InpRSIPeriod, PRICE_CLOSE);

   if(hATR==INVALID_HANDLE || hADX==INVALID_HANDLE || hEMAFast==INVALID_HANDLE ||
      hEMASlow==INVALID_HANDLE || hMACD==INVALID_HANDLE || hBB==INVALID_HANDLE || hRSI==INVALID_HANDLE)
     {
      Print("Indicator init failed");
      return(INIT_FAILED);
     }

   InitAffinityMatrix();
   LoadWeights();   // falls back to affinity-based defaults if no file yet

   g_dayStart = TimeCurrent() - (TimeCurrent() % 86400);
   g_dayStartEquity = AccountInfoDouble(ACCOUNT_EQUITY);

   return(INIT_SUCCEEDED);
  }

void OnDeinit(const int reason)
  {
   SaveWeights();
  }

//==================================================================
// AFFINITY MATRIX (the design prior: which strategy suits which regime)
// Values are starting biases; learning multiplies on top of these.
//==================================================================
void InitAffinityMatrix()
  {
   ArrayInitialize(g_affinity, 0.3); // baseline floor so nothing is fully dead

   g_affinity[STRAT_TREND][REGIME_TREND_HIGHVOL] = 1.6;
   g_affinity[STRAT_TREND][REGIME_TREND_LOWVOL]  = 1.2;
   g_affinity[STRAT_TREND][REGIME_LONDON]        = 1.1;
   g_affinity[STRAT_TREND][REGIME_NEWYORK]       = 1.1;

   g_affinity[STRAT_MEANREV][REGIME_RANGE_LOWVOL]  = 1.7;
   g_affinity[STRAT_MEANREV][REGIME_RANGE_HIGHVOL] = 1.0;
   g_affinity[STRAT_MEANREV][REGIME_ASIAN]         = 1.3;

   g_affinity[STRAT_BREAKOUT][REGIME_BREAKOUT]      = 1.8;
   g_affinity[STRAT_BREAKOUT][REGIME_TREND_HIGHVOL] = 1.2;
   g_affinity[STRAT_BREAKOUT][REGIME_RANGE_HIGHVOL] = 1.0;

   g_affinity[STRAT_SESSION][REGIME_LONDON]   = 1.6;
   g_affinity[STRAT_SESSION][REGIME_NEWYORK]  = 1.6;
   g_affinity[STRAT_SESSION][REGIME_BREAKOUT] = 1.1;

   g_affinity[STRAT_LIQSWEEP][REGIME_RANGE_HIGHVOL]   = 1.5;
   g_affinity[STRAT_LIQSWEEP][REGIME_RANGE_LOWVOL]    = 1.2;
   g_affinity[STRAT_LIQSWEEP][REGIME_BREAKOUT]        = 1.4;
   g_affinity[STRAT_LIQSWEEP][REGIME_ASIAN]           = 1.3;
   g_affinity[STRAT_LIQSWEEP][REGIME_LONDON]          = 1.2;

   g_affinity[STRAT_VWAP_REV][REGIME_RANGE_LOWVOL]    = 1.5;
   g_affinity[STRAT_VWAP_REV][REGIME_RANGE_HIGHVOL]   = 1.2;
   g_affinity[STRAT_VWAP_REV][REGIME_ASIAN]           = 1.4;

   g_affinity[STRAT_PULLBACK][REGIME_TREND_HIGHVOL]   = 1.7;
   g_affinity[STRAT_PULLBACK][REGIME_TREND_LOWVOL]    = 1.5;
   g_affinity[STRAT_PULLBACK][REGIME_LONDON]          = 1.2;
   g_affinity[STRAT_PULLBACK][REGIME_NEWYORK]         = 1.2;

   g_affinity[STRAT_OB_CONT][REGIME_TREND_HIGHVOL]    = 1.6;
   g_affinity[STRAT_OB_CONT][REGIME_TREND_LOWVOL]     = 1.3;
   g_affinity[STRAT_OB_CONT][REGIME_BREAKOUT]         = 1.2;

   g_affinity[STRAT_FVG_REBAL][REGIME_TREND_HIGHVOL]  = 1.4;
   g_affinity[STRAT_FVG_REBAL][REGIME_BREAKOUT]       = 1.5;
   g_affinity[STRAT_FVG_REBAL][REGIME_NEWYORK]        = 1.2;

   g_affinity[STRAT_VOLCOMP_BO][REGIME_RANGE_LOWVOL]  = 1.6;
   g_affinity[STRAT_VOLCOMP_BO][REGIME_ASIAN]         = 1.4;
   g_affinity[STRAT_VOLCOMP_BO][REGIME_LONDON]        = 1.3;
  }

//==================================================================
// WEIGHT PERSISTENCE
//==================================================================
void LoadWeights()
  {
   ArrayCopy(g_weights, g_affinity); // default = affinity prior
   int h = FileOpen(InpWeightFile, FILE_READ|FILE_BIN|FILE_COMMON);
   if(h==INVALID_HANDLE) return;
   for(int s=0; s<NUM_STRATEGIES; s++)
      for(int r=0; r<NUM_REGIMES; r++)
         if(!FileIsEnding(h))
            g_weights[s][r] = FileReadDouble(h);
   FileClose(h);
  }

void SaveWeights()
  {
   int h = FileOpen(InpWeightFile, FILE_WRITE|FILE_BIN|FILE_COMMON);
   if(h==INVALID_HANDLE) return;
   for(int s=0; s<NUM_STRATEGIES; s++)
      for(int r=0; r<NUM_REGIMES; r++)
         FileWriteDouble(h, g_weights[s][r]);
   FileClose(h);
  }

//==================================================================
// REGIME DETECTION
//==================================================================
RegimeId DetectRegime()
  {
   double atr[]; ArraySetAsSeries(atr, true);
   if(CopyBuffer(hATR, 0, 0, InpATRLookback, atr) < InpATRLookback) return REGIME_RANGE_LOWVOL;

   double adxArr[]; ArraySetAsSeries(adxArr, true);
   CopyBuffer(hADX, 0, 0, 3, adxArr);
   double adx = adxArr[0];

   // ATR percentile rank of the current value vs lookback window
   double curATR = atr[0];
   int higher = 0;
   for(int i=0; i<InpATRLookback; i++) if(atr[i] < curATR) higher++;
   double atrPercentile = (double)higher / InpATRLookback; // 0..1

   // liquidity proxy: current tick volume vs recent average
   long vol[]; ArraySetAsSeries(vol, true);
   CopyTickVolume(_Symbol, PERIOD_CURRENT, 0, InpVolAvgPeriod, vol);
   double avgVol=0; for(int i=0;i<InpVolAvgPeriod;i++) avgVol += (double)vol[i];
   avgVol /= InpVolAvgPeriod;
   double curVol = (double)vol[0];
   bool highLiquidity = (avgVol>0 && curVol >= avgVol*0.9);

   g_lastATRPercentile = atrPercentile;
   g_lastVolumeRatio   = (avgVol>0) ? curVol/avgVol : 1.0;
   g_lastADX           = adx;

   MqlDateTime tm; TimeToStruct(TimeCurrent(), tm);
   int hour = tm.hour;
   bool asian   = (hour>=0  && hour<7);
   bool london  = (hour>=7  && hour<12);
   bool overlap = (hour>=12 && hour<16);
   bool newyork = (hour>=16 && hour<21);

   // breakout regime: volatility expanding fast (top decile) regardless of trend strength
   if(atrPercentile > 0.9 && highLiquidity)
      return REGIME_BREAKOUT;

   if(overlap) return (london ? REGIME_LONDON : REGIME_NEWYORK); // overlap counted as NY/London blend below
   if(london)  return REGIME_LONDON;
   if(newyork) return REGIME_NEWYORK;
   if(asian)   return REGIME_ASIAN;

   if(adx >= InpADXTrendLevel)
      return (atrPercentile > 0.5) ? REGIME_TREND_HIGHVOL : REGIME_TREND_LOWVOL;
   else
      return (atrPercentile > 0.5) ? REGIME_RANGE_HIGHVOL : REGIME_RANGE_LOWVOL;
  }

//==================================================================
// LIQUIDITY / SMC ENGINE  (Phase 1)
// Builds: swing highs/lows -> market structure (BOS/CHOCH) ->
//         liquidity sweep detection -> order blocks -> fair value gaps
// Call DetectLiquidityStructure() once per new bar before strategy
// signals / trade quality scoring use its outputs.
//==================================================================

//--- find fractal swing highs/lows over the lookback window
void BuildSwings()
  {
   ArrayResize(g_swingHighs, 0);
   ArrayResize(g_swingLows, 0);

   int lb = InpSwingLookback;
   int depth = InpSwingDepth;

   double highs[], lows[]; datetime times[];
   ArraySetAsSeries(highs,true); ArraySetAsSeries(lows,true); ArraySetAsSeries(times,true);
   int need = depth + lb*2 + 2;
   if(CopyHigh(_Symbol, PERIOD_CURRENT, 0, need, highs) < need) return;
   if(CopyLow(_Symbol, PERIOD_CURRENT, 0, need, lows)  < need) return;
   CopyTime(_Symbol, PERIOD_CURRENT, 0, need, times);

   for(int i=lb+1; i<depth+lb; i++)
     {
      bool isHigh=true, isLow=true;
      for(int j=1; j<=lb; j++)
        {
         if(highs[i] < highs[i-j] || highs[i] < highs[i+j]) isHigh=false;
         if(lows[i]  > lows[i-j]  || lows[i]  > lows[i+j])  isLow=false;
        }
      if(isHigh)
        {
         int n=ArraySize(g_swingHighs); ArrayResize(g_swingHighs,n+1);
         g_swingHighs[n].time=times[i]; g_swingHighs[n].price=highs[i]; g_swingHighs[n].barShift=i;
        }
      if(isLow)
        {
         int n=ArraySize(g_swingLows); ArrayResize(g_swingLows,n+1);
         g_swingLows[n].time=times[i]; g_swingLows[n].price=lows[i]; g_swingLows[n].barShift=i;
        }
     }
  }

//--- market structure: compare the last two swing highs and last two swing lows
void UpdateStructure()
  {
   g_prevStructure = g_structure;
   int nH = ArraySize(g_swingHighs), nL = ArraySize(g_swingLows);
   if(nH<2 || nL<2) { g_structure = STRUCT_UNCLEAR; return; }

   // arrays are ordered oldest->most-recent shift descending (barShift decreasing = more recent)
   // sort isn't strictly required since BuildSwings appends in chronological scan order already
   double hPrev = g_swingHighs[nH-2].price, hLast = g_swingHighs[nH-1].price;
   double lPrev = g_swingLows[nL-2].price,  lLast = g_swingLows[nL-1].price;

   bool higherHigh = hLast > hPrev;
   bool higherLow  = lLast > lPrev;
   bool lowerHigh  = hLast < hPrev;
   bool lowerLow   = lLast < lPrev;

   StructureBias newBias = STRUCT_UNCLEAR;
   if(higherHigh && higherLow) newBias = STRUCT_BULL;
   else if(lowerHigh && lowerLow) newBias = STRUCT_BEAR;
   else newBias = g_structure; // ambiguous bar -> hold previous bias

   // BOS = bias continued in the same direction; CHOCH = bias flipped
   if(g_prevStructure!=STRUCT_UNCLEAR && newBias!=STRUCT_UNCLEAR && newBias!=g_prevStructure)
      g_lastWasBOS = false; // flip = CHOCH
   else
      g_lastWasBOS = true;

   g_structure = newBias;
  }

//--- liquidity sweep: last closed bar wicks beyond a recent swing level then closes back inside
void DetectSweep()
  {
   double high1[1], low1[1], close1[1], open1[1];
   if(CopyHigh(_Symbol,PERIOD_CURRENT,1,1,high1)<1) return;
   if(CopyLow(_Symbol,PERIOD_CURRENT,1,1,low1)<1) return;
   if(CopyClose(_Symbol,PERIOD_CURRENT,1,1,close1)<1) return;

   double pt = _Point;
   double minWick = InpSweepWickMinPts*pt;

   // Phase 5: prefer a multi-touch liquidity pool (equal highs/lows) over a lone swing --
   // a level price has tagged 2+ times is a more credible liquidity magnet for a real sweep.
   double bestHighLevel=0, bestLowLevel=0;
   int bestHighTouches=0, bestLowTouches=0;
   for(int i=0; i<ArraySize(g_liqPools); i++)
     {
      if(g_liqPools[i].swept) continue;
      if(g_liqPools[i].isHigh && g_liqPools[i].touches>bestHighTouches)
        { bestHighTouches=g_liqPools[i].touches; bestHighLevel=g_liqPools[i].level; }
      if(!g_liqPools[i].isHigh && g_liqPools[i].touches>bestLowTouches)
        { bestLowTouches=g_liqPools[i].touches; bestLowLevel=g_liqPools[i].level; }
     }

   int nH = ArraySize(g_swingHighs), nL = ArraySize(g_swingLows);
   double highLevel = (bestHighTouches>=2) ? bestHighLevel : ((nH>0) ? g_swingHighs[nH-1].price : 0);
   double lowLevel  = (bestLowTouches>=2)  ? bestLowLevel  : ((nL>0) ? g_swingLows[nL-1].price  : 0);

   if(highLevel>0 && high1[0] > highLevel + minWick && close1[0] < highLevel)
     {
      g_lastSweep = SWEEP_BUYSIDE;
      g_lastSweepBar = 1;
      g_lastSweepLevel = highLevel;
      for(int i=0;i<ArraySize(g_liqPools);i++)
         if(g_liqPools[i].isHigh && MathAbs(g_liqPools[i].level-highLevel)<=InpEqualLevelTolPts*pt) g_liqPools[i].swept=true;
      return;
     }
   if(lowLevel>0 && low1[0] < lowLevel - minWick && close1[0] > lowLevel)
     {
      g_lastSweep = SWEEP_SELLSIDE;
      g_lastSweepBar = 1;
      g_lastSweepLevel = lowLevel;
      for(int i=0;i<ArraySize(g_liqPools);i++)
         if(!g_liqPools[i].isHigh && MathAbs(g_liqPools[i].level-lowLevel)<=InpEqualLevelTolPts*pt) g_liqPools[i].swept=true;
      return;
     }

   // age out an old sweep
   if(g_lastSweep!=SWEEP_NONE) g_lastSweepBar++;
   if(g_lastSweepBar > InpSweepValidBars) g_lastSweep = SWEEP_NONE;
  }

//--- order blocks: last opposite-colour candle immediately before an ATR-impulse move
void DetectOrderBlocks()
  {
   double atrArr[1]; if(CopyBuffer(hATR,0,1,1,atrArr)<1) return;
   double atr = atrArr[0];
   if(atr<=0) return;

   double opens[], closes[], highs[], lows[]; datetime times[];
   ArraySetAsSeries(opens,true); ArraySetAsSeries(closes,true);
   ArraySetAsSeries(highs,true); ArraySetAsSeries(lows,true); ArraySetAsSeries(times,true);
   int need = 6;
   if(CopyOpen(_Symbol,PERIOD_CURRENT,0,need,opens)<need) return;
   if(CopyClose(_Symbol,PERIOD_CURRENT,0,need,closes)<need) return;
   if(CopyHigh(_Symbol,PERIOD_CURRENT,0,need,highs)<need) return;
   if(CopyLow(_Symbol,PERIOD_CURRENT,0,need,lows)<need) return;
   CopyTime(_Symbol,PERIOD_CURRENT,0,need,times);

   // bars[1] = last closed bar, bars[2] = candle before it (candidate OB)
   double moveUp = closes[1] - opens[2];
   double moveDown = opens[2] - closes[1];

   if(moveUp > atr*InpImpulseATRMult && closes[2] < opens[2]) // bearish candle[2] before bullish impulse -> bullish OB
     {
      int n=ArraySize(g_orderBlocks); ArrayResize(g_orderBlocks,n+1);
      g_orderBlocks[n].top=opens[2]; g_orderBlocks[n].bottom=closes[2];
      g_orderBlocks[n].time=times[2]; g_orderBlocks[n].bullish=true; g_orderBlocks[n].mitigated=false;
     }
   if(moveDown > atr*InpImpulseATRMult && closes[2] > opens[2]) // bullish candle[2] before bearish impulse -> bearish OB
     {
      int n=ArraySize(g_orderBlocks); ArrayResize(g_orderBlocks,n+1);
      g_orderBlocks[n].top=closes[2]; g_orderBlocks[n].bottom=opens[2];
      g_orderBlocks[n].time=times[2]; g_orderBlocks[n].bullish=false; g_orderBlocks[n].mitigated=false;
     }
   // keep the zone list bounded
   int n=ArraySize(g_orderBlocks);
   if(n>30) ArrayRemove(g_orderBlocks,0,n-30);
  }

//--- fair value gaps: 3-candle imbalance, candle1 high/low doesn't overlap candle3 low/high
void DetectFVG()
  {
   double highs[3], lows[3];
   ArraySetAsSeries(highs,true); ArraySetAsSeries(lows,true);
   if(CopyHigh(_Symbol,PERIOD_CURRENT,1,3,highs)<3) return;
   if(CopyLow(_Symbol,PERIOD_CURRENT,1,3,lows)<3) return;

   double pt=_Point;
   // highs[2]/lows[2] = oldest of the 3, highs[0]/lows[0] = most recent (since series, index 0 = bar shift 1)
   double gapUp   = lows[0] - highs[2];   // bullish FVG
   double gapDown = lows[2] - highs[0];   // bearish FVG

   datetime t; 
   if(gapUp > InpFVGMinPts*pt)
     {
      int n=ArraySize(g_fvgZones); ArrayResize(g_fvgZones,n+1);
      g_fvgZones[n].top=lows[0]; g_fvgZones[n].bottom=highs[2];
      g_fvgZones[n].time=TimeCurrent(); g_fvgZones[n].bullish=true; g_fvgZones[n].mitigated=false;
     }
   if(gapDown > InpFVGMinPts*pt)
     {
      int n=ArraySize(g_fvgZones); ArrayResize(g_fvgZones,n+1);
      g_fvgZones[n].top=lows[2]; g_fvgZones[n].bottom=highs[0];
      g_fvgZones[n].time=TimeCurrent(); g_fvgZones[n].bullish=false; g_fvgZones[n].mitigated=false;
     }
   int n=ArraySize(g_fvgZones);
   if(n>30) ArrayRemove(g_fvgZones,0,n-30);
  }

//--- Phase 5: mark zones mitigated once price closes fully through them.
// A bullish zone is invalidated when price closes below its bottom (it's been
// "used up"); a bearish zone is invalidated when price closes above its top.
void UpdateZoneMitigation()
  {
   double close1[1];
   if(CopyClose(_Symbol, PERIOD_CURRENT, 1, 1, close1) < 1) return;
   double c = close1[0];

   for(int i=0; i<ArraySize(g_orderBlocks); i++)
     {
      if(g_orderBlocks[i].mitigated) continue;
      if(g_orderBlocks[i].bullish && c < g_orderBlocks[i].bottom) g_orderBlocks[i].mitigated = true;
      if(!g_orderBlocks[i].bullish && c > g_orderBlocks[i].top)   g_orderBlocks[i].mitigated = true;
     }
   for(int i=0; i<ArraySize(g_fvgZones); i++)
     {
      if(g_fvgZones[i].mitigated) continue;
      if(g_fvgZones[i].bullish && c < g_fvgZones[i].bottom) g_fvgZones[i].mitigated = true;
      if(!g_fvgZones[i].bullish && c > g_fvgZones[i].top)   g_fvgZones[i].mitigated = true;
     }

   // prune fully mitigated zones so stale entries don't pile up or get matched by mistake
   for(int i=ArraySize(g_orderBlocks)-1; i>=0; i--)
      if(g_orderBlocks[i].mitigated) ArrayRemove(g_orderBlocks,i,1);
   for(int i=ArraySize(g_fvgZones)-1; i>=0; i--)
      if(g_fvgZones[i].mitigated) ArrayRemove(g_fvgZones,i,1);
  }

//--- Phase 5: cluster swing highs/lows into liquidity pools (equal highs / equal lows).
// A pool with >=2 touches represents a stronger, more "obvious" liquidity target
// than an isolated single swing -- exactly the kind of level price tends to run.
void BuildLiquidityPools()
  {
   ArrayResize(g_liqPools, 0);
   double tol = InpEqualLevelTolPts * _Point;

   for(int src=0; src<2; src++) // 0 = highs, 1 = lows
     {
      int n = (src==0) ? ArraySize(g_swingHighs) : ArraySize(g_swingLows);
      for(int i=0; i<n; i++)
        {
         double lvl = (src==0) ? g_swingHighs[i].price : g_swingLows[i].price;
         int found=-1;
         for(int p=0; p<ArraySize(g_liqPools); p++)
           {
            if(g_liqPools[p].isHigh != (src==0)) continue;
            if(MathAbs(g_liqPools[p].level - lvl) <= tol) { found=p; break; }
           }
         if(found>=0)
           {
            // running average of the cluster level, plus a touch count
            g_liqPools[found].level = (g_liqPools[found].level*g_liqPools[found].touches + lvl) / (g_liqPools[found].touches+1);
            g_liqPools[found].touches++;
           }
         else
           {
            int n2=ArraySize(g_liqPools); ArrayResize(g_liqPools,n2+1);
            g_liqPools[n2].level=lvl; g_liqPools[n2].touches=1; g_liqPools[n2].isHigh=(src==0); g_liqPools[n2].swept=false;
           }
        }
     }
  }

//--- master refresh, call once per new bar
void DetectLiquidityStructure()
  {
   BuildSwings();
   BuildLiquidityPools();   // Phase 5
   UpdateStructure();
   DetectSweep();
   DetectOrderBlocks();
   DetectFVG();
   UpdateZoneMitigation();  // Phase 5
  }

//--- simple institutional filter: don't trade when structure is ambiguous AND no sweep context exists
bool StructureClearEnough()
  {
   if(g_structure != STRUCT_UNCLEAR) return true;
   if(g_lastSweep != SWEEP_NONE) return true; // a sweep is itself a valid, structure-independent context
   return false;
  }

//==================================================================
// STRATEGY SIGNAL FUNCTIONS  (each self-contained, own indicator set)
//==================================================================
SignalDir Signal_Trend()
  {
   double emaF[2], emaS[2], macdMain[2], macdSig[2];
   if(CopyBuffer(hEMAFast,0,0,2,emaF)<2) return SIG_NONE;
   if(CopyBuffer(hEMASlow,0,0,2,emaS)<2) return SIG_NONE;
   if(CopyBuffer(hMACD,0,0,2,macdMain)<2) return SIG_NONE;
   if(CopyBuffer(hMACD,1,0,2,macdSig)<2) return SIG_NONE;

   bool crossUp   = emaF[1]<=emaS[1] && emaF[0]>emaS[0];
   bool crossDown = emaF[1]>=emaS[1] && emaF[0]<emaS[0];
   bool macdBull  = macdMain[0] > macdSig[0];
   bool macdBear  = macdMain[0] < macdSig[0];

   if(crossUp && macdBull)   return SIG_BUY;
   if(crossDown && macdBear) return SIG_SELL;
   return SIG_NONE;
  }

SignalDir Signal_MeanReversion()
  {
   double upper[2], lower[2], mid[2], rsi[2];
   if(CopyBuffer(hBB,1,0,2,upper)<2) return SIG_NONE; // upper band buffer index 1
   if(CopyBuffer(hBB,2,0,2,lower)<2) return SIG_NONE; // lower band buffer index 2
   if(CopyBuffer(hRSI,0,0,2,rsi)<2) return SIG_NONE;

   double price = SymbolInfoDouble(_Symbol, SYMBOL_BID);

   if(price <= lower[0] && rsi[0] <= InpRSIOversold)   return SIG_BUY;
   if(price >= upper[0] && rsi[0] >= InpRSIOverbought) return SIG_SELL;
   return SIG_NONE;
  }

SignalDir Signal_Breakout()
  {
   double highs[], lows[];
   ArraySetAsSeries(highs,true); ArraySetAsSeries(lows,true);
   if(CopyHigh(_Symbol, PERIOD_CURRENT, 1, InpDonchianPeriod, highs) < InpDonchianPeriod) return SIG_NONE;
   if(CopyLow(_Symbol, PERIOD_CURRENT, 1, InpDonchianPeriod, lows)  < InpDonchianPeriod) return SIG_NONE;

   double highest = highs[ArrayMaximum(highs)];
   double lowest  = lows[ArrayMinimum(lows)];

   double price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(price > highest) return SIG_BUY;
   if(price < lowest)  return SIG_SELL;
   return SIG_NONE;
  }

SignalDir Signal_Session()
  {
   // session-open momentum: compare close vs close N bars ago at session boundary
   double closeNow[2];
   if(CopyClose(_Symbol, PERIOD_CURRENT, 0, 2, closeNow) < 2) return SIG_NONE;
   double pastArr[]; ArraySetAsSeries(pastArr,true);
   if(CopyClose(_Symbol, PERIOD_CURRENT, 0, 6, pastArr) < 6) return SIG_NONE;

   double momentum = closeNow[1] - pastArr[5];
   double atrArr[]; ArraySetAsSeries(atrArr,true);
   CopyBuffer(hATR,0,0,1,atrArr);
   double threshold = atrArr[0]*0.3;

   if(momentum > threshold)  return SIG_BUY;
   if(momentum < -threshold) return SIG_SELL;
   return SIG_NONE;
  }

// liquidity sweep reversal: fires only while a recent sweep is still "valid"
// (set by DetectSweep in the SMC engine). Buyside sweep (liquidity above taken)
// -> fade short. Sellside sweep (liquidity below taken) -> fade long.
SignalDir Signal_LiquiditySweep()
  {
   if(g_lastSweep == SWEEP_BUYSIDE)  return SIG_SELL;
   if(g_lastSweep == SWEEP_SELLSIDE) return SIG_BUY;
   return SIG_NONE;
  }

// VWAP institutional reversion: price overextended from session VWAP -> fade back to it
double CalcSessionVWAP()
  {
   datetime dayStart = TimeCurrent() - (TimeCurrent()%86400);
   int bars = iBarShift(_Symbol, PERIOD_CURRENT, dayStart, false);
   if(bars<=0) bars=1;
   bars = MathMin(bars+1, 1440);

   double highs[], lows[], closes[]; long vols[];
   ArraySetAsSeries(highs,true); ArraySetAsSeries(lows,true);
   ArraySetAsSeries(closes,true); ArraySetAsSeries(vols,true);
   if(CopyHigh(_Symbol,PERIOD_CURRENT,0,bars,highs)<bars) return 0;
   if(CopyLow(_Symbol,PERIOD_CURRENT,0,bars,lows)<bars) return 0;
   if(CopyClose(_Symbol,PERIOD_CURRENT,0,bars,closes)<bars) return 0;
   if(CopyTickVolume(_Symbol,PERIOD_CURRENT,0,bars,vols)<bars) return 0;

   double sumPV=0, sumV=0;
   for(int i=0;i<bars;i++)
     {
      double typical=(highs[i]+lows[i]+closes[i])/3.0;
      sumPV += typical*(double)vols[i];
      sumV  += (double)vols[i];
     }
   if(sumV<=0) return closes[0];
   return sumPV/sumV;
  }

SignalDir Signal_VWAPReversion()
  {
   double vwap = CalcSessionVWAP();
   if(vwap<=0) return SIG_NONE;
   double price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double atrArr[1]; if(CopyBuffer(hATR,0,0,1,atrArr)<1) return SIG_NONE;
   double thresh = atrArr[0]*InpVWAPDevATRMult;
   double dist = price - vwap;

   if(dist > thresh)  return SIG_SELL; // overextended above VWAP -> fade short
   if(dist < -thresh) return SIG_BUY;  // overextended below VWAP -> fade long
   return SIG_NONE;
  }

// trend pullback scalper: trade continuation when price pulls back near the fast EMA in an active trend
SignalDir Signal_Pullback()
  {
   double emaF[1], emaS[1], adxArr[1], atrArr[1];
   if(CopyBuffer(hEMAFast,0,0,1,emaF)<1) return SIG_NONE;
   if(CopyBuffer(hEMASlow,0,0,1,emaS)<1) return SIG_NONE;
   if(CopyBuffer(hADX,0,0,1,adxArr)<1) return SIG_NONE;
   if(CopyBuffer(hATR,0,0,1,atrArr)<1) return SIG_NONE;

   if(adxArr[0] < InpADXTrendLevel) return SIG_NONE; // need a real trend present

   bool bullTrend = emaF[0] > emaS[0];
   bool bearTrend = emaF[0] < emaS[0];
   double price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double distToFast = MathAbs(price - emaF[0]);

   if(distToFast > atrArr[0]*InpPullbackATRMult) return SIG_NONE; // not pulled back close enough

   if(bullTrend) return SIG_BUY;
   if(bearTrend) return SIG_SELL;
   return SIG_NONE;
  }

// order block continuation: price returns into a structure-aligned order block zone
SignalDir Signal_OBContinuation()
  {
   if(g_structure==STRUCT_UNCLEAR) return SIG_NONE;
   double price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   bool wantBull = (g_structure==STRUCT_BULL);

   for(int i=ArraySize(g_orderBlocks)-1; i>=0 && i>ArraySize(g_orderBlocks)-10; i--)
     {
      if(g_orderBlocks[i].bullish!=wantBull) continue;
      if(price<=g_orderBlocks[i].top && price>=g_orderBlocks[i].bottom)
         return wantBull ? SIG_BUY : SIG_SELL;
     }
   return SIG_NONE;
  }

// fair value gap rebalancing: price retraces into a structure-aligned FVG, continuation entry
SignalDir Signal_FVGRebalance()
  {
   if(g_structure==STRUCT_UNCLEAR) return SIG_NONE;
   double price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   bool wantBull = (g_structure==STRUCT_BULL);

   for(int i=ArraySize(g_fvgZones)-1; i>=0 && i>ArraySize(g_fvgZones)-10; i--)
     {
      if(g_fvgZones[i].bullish!=wantBull) continue;
      if(price<=g_fvgZones[i].top && price>=g_fvgZones[i].bottom)
         return wantBull ? SIG_BUY : SIG_SELL;
     }
   return SIG_NONE;
  }

// volatility compression breakout: only fires when ATR percentile is in the compression zone
// and price breaks the recent range -> first move out of a squeeze
SignalDir Signal_VolCompressionBreakout()
  {
   if(g_lastATRPercentile > InpCompressionPctile) return SIG_NONE; // not compressed enough

   double highs[], lows[];
   ArraySetAsSeries(highs,true); ArraySetAsSeries(lows,true);
   if(CopyHigh(_Symbol, PERIOD_CURRENT, 1, InpVolCompPeriod, highs) < InpVolCompPeriod) return SIG_NONE;
   if(CopyLow(_Symbol, PERIOD_CURRENT, 1, InpVolCompPeriod, lows)  < InpVolCompPeriod) return SIG_NONE;

   double highest = highs[ArrayMaximum(highs)];
   double lowest  = lows[ArrayMinimum(lows)];
   double price = SymbolInfoDouble(_Symbol, SYMBOL_BID);

   if(price > highest) return SIG_BUY;
   if(price < lowest)  return SIG_SELL;
   return SIG_NONE;
  }

SignalDir GetStrategySignal(int strat)
  {
   switch(strat)
     {
      case STRAT_TREND:      return Signal_Trend();
      case STRAT_MEANREV:    return Signal_MeanReversion();
      case STRAT_BREAKOUT:   return Signal_Breakout();
      case STRAT_SESSION:    return Signal_Session();
      case STRAT_LIQSWEEP:   return Signal_LiquiditySweep();
      case STRAT_VWAP_REV:   return Signal_VWAPReversion();
      case STRAT_PULLBACK:   return Signal_Pullback();
      case STRAT_OB_CONT:    return Signal_OBContinuation();
      case STRAT_FVG_REBAL:  return Signal_FVGRebalance();
      case STRAT_VOLCOMP_BO: return Signal_VolCompressionBreakout();
     }
   return SIG_NONE;
  }

//==================================================================
// SELECTOR: scores strategies for current regime, requires confluence
//==================================================================
bool SelectTrade(RegimeId regime, SignalDir &outDir, int &outStrategy)
  {
   double scores[NUM_STRATEGIES];
   SignalDir sigs[NUM_STRATEGIES];

   for(int s=0; s<NUM_STRATEGIES; s++)
     {
      sigs[s]   = GetStrategySignal(s);
      scores[s] = g_weights[s][regime];
      if(sigs[s]==SIG_NONE) scores[s] = 0; // can't be picked if it has no signal right now
     }

   int best = -1; double bestScore=0;
   int second = -1; double secondScore=0;
   for(int s=0; s<NUM_STRATEGIES; s++)
     {
      if(scores[s] > bestScore) { second=best; secondScore=bestScore; best=s; bestScore=scores[s]; }
      else if(scores[s] > secondScore) { second=s; secondScore=scores[s]; }
     }

   if(best==-1 || bestScore<=0) return false; // nothing fired

   outDir = sigs[best];
   outStrategy = best;

   // confluence check: if a close second strategy disagrees in direction, skip (avoid contradiction)
   if(second!=-1 && secondScore > bestScore*0.85 && sigs[second]!=SIG_NONE && sigs[second]!=outDir)
      return false;

   return true;
  }

//==================================================================
// TRADE QUALITY SCORING ENGINE  (Phase 2)
// Scores a candidate setup 0-100 across five components, each itself
// gated/shaped by a pass-fail style check before contributing weight:
//   Layer 1 - Trend strength & structure alignment
//   Layer 2 - Liquidity confirmation (sweep / order block / FVG)
//   Layer 3 - Volume confirmation
//   Layer 4 - Session quality
//   Layer 5 - Volatility sweet-spot (not dead, not unstable)
// Final score gates execution against InpMinQualityScore.
//==================================================================
double ScoreTrendStructure(SignalDir dir)
  {
   double score = MathMin(100.0, (g_lastADX/40.0)*100.0); // ADX 40+ => saturates at 100

   bool aligned = (dir==SIG_BUY  && g_structure==STRUCT_BULL) ||
                  (dir==SIG_SELL && g_structure==STRUCT_BEAR);
   bool opposed = (dir==SIG_BUY  && g_structure==STRUCT_BEAR) ||
                  (dir==SIG_SELL && g_structure==STRUCT_BULL);

   if(aligned) score = MathMin(100.0, score*1.25 + (g_lastWasBOS?10:0)); // BOS continuation bonus
   else if(opposed) score *= 0.5;                                       // trading against structure
   return MathMax(0.0, MathMin(100.0, score));
  }

double ScoreLiquidity(SignalDir dir)
  {
   double score = 35.0; // baseline: no special liquidity context

   bool sweepAligned = (dir==SIG_BUY  && g_lastSweep==SWEEP_SELLSIDE) ||
                       (dir==SIG_SELL && g_lastSweep==SWEEP_BUYSIDE);
   bool sweepOpposed  = (dir==SIG_BUY  && g_lastSweep==SWEEP_BUYSIDE) ||
                       (dir==SIG_SELL && g_lastSweep==SWEEP_SELLSIDE);
   if(sweepAligned) score = 90.0;
   else if(sweepOpposed) score = 15.0;

   // proximity to an aligned order block or FVG zone adds confirmation
   double price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   bool wantBullZone = (dir==SIG_BUY);

   for(int i=ArraySize(g_orderBlocks)-1; i>=0 && i>ArraySize(g_orderBlocks)-8; i--)
     {
      if(g_orderBlocks[i].bullish!=wantBullZone) continue;
      if(price<=g_orderBlocks[i].top && price>=g_orderBlocks[i].bottom)
        { score = MathMin(100.0, score+20.0); break; }
     }
   for(int i=ArraySize(g_fvgZones)-1; i>=0 && i>ArraySize(g_fvgZones)-8; i--)
     {
      if(g_fvgZones[i].bullish!=wantBullZone) continue;
      if(price<=g_fvgZones[i].top && price>=g_fvgZones[i].bottom)
        { score = MathMin(100.0, score+10.0); break; }
     }
   return MathMax(0.0, MathMin(100.0, score));
  }

double ScoreVolume()
  {
   // g_lastVolumeRatio: current tick volume vs recent average (set in DetectRegime)
   double score = MathMin(100.0, g_lastVolumeRatio*60.0);
   return MathMax(0.0, MathMin(100.0, score));
  }

double ScoreSession(RegimeId regime)
  {
   switch(regime)
     {
      case REGIME_LONDON:        return 85.0;
      case REGIME_NEWYORK:       return 85.0;
      case REGIME_BREAKOUT:      return 78.0;
      case REGIME_TREND_HIGHVOL: return 72.0;
      case REGIME_TREND_LOWVOL:  return 62.0;
      case REGIME_RANGE_HIGHVOL: return 58.0;
      case REGIME_RANGE_LOWVOL:  return 52.0;
      case REGIME_ASIAN:         return 48.0;
     }
   return 50.0;
  }

double ScoreVolatility()
  {
   // sweet spot around the 0.45-0.75 ATR percentile band: too low = dead/no follow-through,
   // too high = unstable/spread risk. Triangular score peaking at 0.6.
   double p = g_lastATRPercentile;
   double dist = MathAbs(p-0.6);
   double score = 100.0 - dist*180.0; // falls off fast outside the sweet spot
   return MathMax(0.0, MathMin(100.0, score));
  }

double CalcTradeQualityScore(SignalDir dir, RegimeId regime)
  {
   double sTrend = ScoreTrendStructure(dir);
   double sLiq   = ScoreLiquidity(dir);
   double sVol   = ScoreVolume();
   double sSess  = ScoreSession(regime);
   double sVola  = ScoreVolatility();

   double total = sTrend*InpWeightTrend + sLiq*InpWeightLiquidity +
                  sVol*InpWeightVolume + sSess*InpWeightSession +
                  sVola*InpWeightVolatility;

   // Phase 4: apply overlap and correlation multipliers
   if(g_inLondonNYOverlap)
      total += InpLondonNYBonusScore;  // additive bonus during overlap, not multiplicative

   double dxyMult = GetDXYInfluence();
   total *= dxyMult;

   return MathMax(0.0, MathMin(100.0, total));
  }

//==================================================================
// RISK / SIZING
//==================================================================
double CalcLotSize(double slDistancePrice)
  {
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   double riskMoney = equity * InpRiskPercent / 100.0;

   double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double tickSize  = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   if(tickSize<=0) tickSize = _Point;

   double valuePerPriceUnit = tickValue / tickSize; // money per 1.0 price move per 1 lot
   if(valuePerPriceUnit<=0) return 0;

   double lots = riskMoney / (slDistancePrice * valuePerPriceUnit);

   double minLot  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxLot  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);

   lots = MathFloor(lots/lotStep)*lotStep;
   lots = MathMax(minLot, MathMin(maxLot, lots));

   // --- Phase 4: apply session & loss streak multipliers
   // Friday risk reduction
   if(InpFridayRiskReduce > 0)
     {
      MqlDateTime dt; TimeToStruct(TimeCurrent(), dt);
      if(dt.day_of_week == 5) // Friday
         lots *= InpFridayRiskReduce;
     }

   // consecutive loss streak reduction
   if(g_consecutiveLosses >= InpConsecLossThreshold)
      lots *= InpConsecLossMultiplier;

   lots = MathMax(minLot, MathMin(maxLot, lots));
   return lots;
  }

//==================================================================
// FILTERS
//==================================================================
bool SpreadOK()
  {
   double spreadPts = (double)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   return spreadPts <= InpMaxSpreadPoints;
  }

// Phase 4: Friday risk-reduction bias -- no NEW trades after the cutoff hour on Fridays.
// Existing positions are left to trailing/SL/TP management, not force-closed, since
// forcing an exit can itself realize a worse price than just managing risk normally.
bool InFridayFlatWindow()
  {
   MqlDateTime dt; TimeToStruct(TimeCurrent(), dt);
   return (dt.day_of_week==5 && dt.hour >= InpFridayFlatHour);
  }

bool InBlackout()
  {
   if(StringLen(InpBlackoutWindows)==0) return false;
   MqlDateTime tm; TimeToStruct(TimeCurrent(), tm);
   int nowMin = tm.hour*60+tm.min;

   string windows[];
   int n = StringSplit(InpBlackoutWindows, ',', windows);
   for(int i=0;i<n;i++)
     {
      string parts[];
      if(StringSplit(windows[i], '-', parts)!=2) continue;
      int h1,m1,h2,m2;
      string t1[], t2[];
      StringSplit(parts[0], ':', t1);
      StringSplit(parts[1], ':', t2);
      if(ArraySize(t1)!=2 || ArraySize(t2)!=2) continue;
      h1=(int)StringToInteger(t1[0]); m1=(int)StringToInteger(t1[1]);
      h2=(int)StringToInteger(t2[0]); m2=(int)StringToInteger(t2[1]);
      int start=h1*60+m1, end=h2*60+m2;
      if(nowMin>=start && nowMin<=end) return true;
     }
   return false;
  }

void CheckNewDay()
  {
   datetime today = TimeCurrent() - (TimeCurrent()%86400);
   if(today != g_dayStart)
     {
      g_dayStart = today;
      g_dayStartEquity = AccountInfoDouble(ACCOUNT_EQUITY);
      g_tradesToday = 0;
      g_dailyLossHit = false;
      g_consecutiveLosses = 0;  // reset loss streak on a new day
     }
  }

bool DailyLossOK()
  {
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   double lossPct = (g_dayStartEquity>0) ? (g_dayStartEquity-equity)/g_dayStartEquity*100.0 : 0;
   if(lossPct >= InpMaxDailyLossPct) g_dailyLossHit = true;
   return !g_dailyLossHit;
  }

bool HasOpenPosition()
  {
   for(int i=PositionsTotal()-1; i>=0; i--)
      if(posInfo.SelectByIndex(i))
         if(posInfo.Magic()==InpMagic && posInfo.Symbol()==_Symbol)
            return true;
   return false;
  }

//--- Phase 4: detect London-NY overlap window (12:00-16:00 server time)
void UpdateSessionOverlap()
  {
   MqlDateTime tm; TimeToStruct(TimeCurrent(), tm);
   int hour = tm.hour;
   g_inLondonNYOverlap = (hour >= 12 && hour < 16);
  }

//--- Phase 4: optional DXY correlation filter
// When DXY is rising strongly (proxy: EURUSD falling), gold momentum can weaken.
// This applies a quality score penalty if enabled.
double GetDXYInfluence()
  {
   if(!InpUseCorrelationFilt) return 1.0; // no penalty if disabled

   double close1[2], close2[2];
   if(CopyClose(InpDXYSymbol, PERIOD_CURRENT, 0, 2, close1) < 2) return 1.0; // can't fetch, no penalty
   if(CopyClose(_Symbol, PERIOD_CURRENT, 0, 2, close2) < 2) return 1.0;

   double eurMove = close1[1] - close1[0];  // positive = EURUSD up (DXY weakening)
   double goldMove = close2[1] - close2[0]; // positive = gold up

   // if EURUSD is falling (DXY rising) and gold is also falling, that's contrarian to gold strength
   // -> apply penalty
   if(eurMove < 0 && goldMove < 0)
      return 0.85; // 15% quality score penalty

   if(eurMove < 0)  // DXY rising, regardless of gold direction
      return 0.92; // mild 8% penalty to dampen buys in a DXY-up environment

   return 1.0; // EURUSD stable or rising: no penalty
  }

//==================================================================
// TRADE EXECUTION
//==================================================================
void OpenTrade(SignalDir dir, int strategy, int regime, double qualityScore)
  {
   double atrArr[]; ArraySetAsSeries(atrArr,true);
   if(CopyBuffer(hATR,0,0,1,atrArr)<1) return;
   double atr = atrArr[0];
   if(atr<=0) return;

   double slDist = atr*InpATR_SL_Mult;
   double tpDist = atr*InpATR_TP_Mult;
   double lots = CalcLotSize(slDist);
   if(lots<=0) return;

   double price = (dir==SIG_BUY) ? SymbolInfoDouble(_Symbol,SYMBOL_ASK) : SymbolInfoDouble(_Symbol,SYMBOL_BID);
   double sl = (dir==SIG_BUY) ? price-slDist : price+slDist;
   double tp = (dir==SIG_BUY) ? price+tpDist : price-tpDist;

   string cmt = InpComment + " Q" + IntegerToString((int)qualityScore) + " S" + IntegerToString(strategy);

   bool ok = (dir==SIG_BUY) ? trade.Buy(lots,_Symbol,price,sl,tp,cmt)
                             : trade.Sell(lots,_Symbol,price,sl,tp,cmt);

   if(ok)
     {
      ulong ticket = trade.ResultOrder();
      int n = ArraySize(g_openTrades);
      ArrayResize(g_openTrades, n+1);
      g_openTrades[n].ticket = ticket;
      g_openTrades[n].strategy = strategy;
      g_openTrades[n].regime = regime;
      g_openTrades[n].entryATR = atr;
      g_tradesToday++;
     }
  }

void ManageTrailing()
  {
   if(!InpUseTrailing) return;
   double atrArr[]; ArraySetAsSeries(atrArr,true);
   if(CopyBuffer(hATR,0,0,1,atrArr)<1) return;
   double atr = atrArr[0];

   for(int i=PositionsTotal()-1; i>=0; i--)
     {
      if(!posInfo.SelectByIndex(i)) continue;
      if(posInfo.Magic()!=InpMagic || posInfo.Symbol()!=_Symbol) continue;

      double openPrice = posInfo.PriceOpen();
      double curPrice  = posInfo.PriceCurrent();
      double curSL     = posInfo.StopLoss();
      double tp        = posInfo.TakeProfit();
      long type        = posInfo.PositionType();

      if(type==POSITION_TYPE_BUY)
        {
         if(curPrice - openPrice > atr*InpTrailStartATRMult)
           {
            double newSL = curPrice - atr*InpTrailATRMult;
            if(newSL > curSL) trade.PositionModify(posInfo.Ticket(), newSL, tp);
           }
        }
      else
        {
         if(openPrice - curPrice > atr*InpTrailStartATRMult)
           {
            double newSL = curPrice + atr*InpTrailATRMult;
            if(newSL < curSL || curSL==0) trade.PositionModify(posInfo.Ticket(), newSL, tp);
           }
        }
     }
  }

//==================================================================
// LEARNING UPDATE: called when a tracked position closes
//==================================================================
void UpdateWeightsOnClose(int strategy, int regime, bool win)
  {
   double w = g_weights[strategy][regime];
   double target = win ? InpMaxWeight : InpMinWeight;
   w = w + InpLearningRate*(target-w);
   w = MathMax(InpMinWeight, MathMin(InpMaxWeight, w));
   g_weights[strategy][regime] = w;
   SaveWeights();

   // --- Phase 4: consecutive loss protection
   if(win)
      g_consecutiveLosses = 0;  // reset on win
   else
     {
      g_consecutiveLosses++;    // increment on loss
      g_lastLossBar = 0;        // mark "0 bars ago" -- will age in OnTick
     }
  }

void CheckClosedTrades()
  {
   for(int i=ArraySize(g_openTrades)-1; i>=0; i--)
     {
      ulong ticket = g_openTrades[i].ticket;
      if(!PositionSelectByTicket(ticket)) // position no longer open -> closed
        {
         // find matching deal in history to determine profit
         if(HistorySelectByPosition(ticket))
           {
            double profit=0;
            int deals = HistoryDealsTotal();
            for(int d=0; d<deals; d++)
              {
               ulong dticket = HistoryDealGetTicket(d);
               if(dticket>0) profit += HistoryDealGetDouble(dticket, DEAL_PROFIT);
              }
            UpdateWeightsOnClose(g_openTrades[i].strategy, g_openTrades[i].regime, profit>0);
           }
         // remove from tracking array
         ArrayRemove(g_openTrades, i, 1);
        }
     }
  }

//==================================================================
// MAIN TICK
//==================================================================
void OnTick()
  {
   CheckNewDay();
   CheckClosedTrades();
   ManageTrailing();
   UpdateSessionOverlap(); // Phase 4: refresh London-NY overlap state every tick

   if(!DailyLossOK()) return;
   if(g_tradesToday >= InpMaxTradesPerDay) return;
   if(!SpreadOK()) return;
   if(InBlackout()) return;
   if(InFridayFlatWindow()) return; // Phase 4: no new trades late Friday
   if(HasOpenPosition()) return; // one position at a time; remove this line to allow scaling

   static datetime lastBar = 0;
   datetime curBar = iTime(_Symbol, PERIOD_CURRENT, 0);
   if(curBar==lastBar) return; // act once per bar to avoid overtrading on every tick
   lastBar = curBar;

   // Phase 4: age out the consecutive-loss streak if enough clean bars have passed
   if(g_lastLossBar >= 0)
     {
      g_lastLossBar++;
      if(g_lastLossBar >= InpConsecLossResetBars)
        {
         g_consecutiveLosses = 0;
         g_lastLossBar = -999;
        }
     }

   DetectLiquidityStructure(); // refresh swings/structure/sweep/OB/FVG once per bar
   if(!StructureClearEnough()) return; // institutional filter: skip ambiguous, sweepless context

   RegimeId regime = DetectRegime();
   SignalDir dir; int strategy;
   if(SelectTrade(regime, dir, strategy))
     {
      double score = CalcTradeQualityScore(dir, regime);
      if(score >= InpMinQualityScore)
         OpenTrade(dir, strategy, regime, score);
     }
  }
//+------------------------------------------------------------------+
