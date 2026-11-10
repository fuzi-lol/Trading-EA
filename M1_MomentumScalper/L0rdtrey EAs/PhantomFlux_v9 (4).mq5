//+------------------------------------------------------------------+
//|            PHANTOM FLUX ADAPTIVE CORE v9.0 - SCALPING GRID          |
//|          Aggressive Bidirectional Execution Engine                 |
//|          Fully Adaptive Edition - nothing fixed                    |
//+------------------------------------------------------------------+
//| UPGRADE FROM v8.00 - 8 new engines, all heuristic/statistical,    |
//| NONE of this is a trained model or real order-book feed. Read the |
//| comment block above each engine for exactly what it does and what |
//| it approximates, so nothing here is mislabeled as more than it is:|
//|                                                                    |
//| 1. PROBABILISTIC BIDIRECTIONAL ENGINE - replaces the fixed 50/50   |
//|    buy/sell split with a live directional-confidence score that   |
//|    weights order count AND per-side risk allocation. It is a      |
//|    hand-weighted logistic squash of existing signals (momentum,   |
//|    micro bias, tick imbalance, bid/ask pressure) - not a          |
//|    calibrated probability from a trained classifier.              |
//| 2. DYNAMIC GRID INTELLIGENCE - grid spacing now also reacts to    |
//|    tick velocity/acceleration, ATR acceleration, spread expansion |
//|    and a session-liquidity heuristic, on top of the v8 volatility |
//|    regime/energy calc.                                            |
//| 3. MARKET MICROSTRUCTURE ENGINE - tick imbalance, bid/ask pressure|
//|    proxy, compression/expansion, liquidity-grab & exhaustion      |
//|    heuristics. MT5's standard API gives no L2 order book, so      |
//|    "bid/ask pressure" and "liquidity grab" are tick/candle-based  |
//|    proxies, not real depth-of-market reads.                       |
//| 4. ADAPTIVE PENDING ORDER ENGINE - the grid is rebalanced every    |
//|    few ticks (not just recycled when stale): deficits are topped  |
//|    up, and the whole ladder is torn down and rebuilt when grid    |
//|    spacing has drifted materially from what's currently resting.  |
//| 5. EXECUTION QUALITY ENGINE - tracks slippage (expected stop price |
//|    vs actual fill price) and a placement-to-fill delay. NOTE: that|
//|    delay is time-from-order-setup-to-fill, dominated by market    |
//|    movement, NOT a broker round-trip latency measurement - MT5    |
//|    doesn't expose true tick-to-ack latency for pending stops.     |
//|    When the rolling quality score drops, aggression is damped.    |
//| 6. ADAPTIVE AGGRESSION ENGINE - win/loss streak tracked and fed    |
//|    into the same energy scalar that drives spacing/orders/lot.    |
//| 7. INTELLIGENT EXIT SYSTEM - each grid deploy tags orders into 3   |
//|    clusters (comment suffix _CL1/_CL2/_CL3): CL1 exits fast on a  |
//|    smaller scalp target, CL2 uses the normal adaptive target, CL3 |
//|    skips the fixed target and trails tighter/sooner instead.      |
//| 8. ORDER SYNCHRONIZATION ENGINE - on every fill, the remaining     |
//|    ladder is re-evaluated against the fresh probability read, and |
//|    the furthest (lowest-priority) contrarian-side pending orders  |
//|    are thinned instead of being left on a stale snapshot.         |
//+------------------------------------------------------------------+
#property copyright "Phantom Technologies (c) 2024 - Adaptive Upgrade"
#property version   "9.20"
#property description "Fully Adaptive Bidirectional Grid - Nothing Fixed"
#property strict

#include <Trade\Trade.mqh>

//+------------------------------------------------------------------+
//| DASHBOARD PREFIX                                                  |
//+------------------------------------------------------------------+
#define DASH_PREFIX "PFA_"

//+------------------------------------------------------------------+
//| PREMIUM COLOR PALETTE - obsidian + gold/champagne, jewel-tone     |
//| status accents. All colors carry a deliberate hue (no neutral     |
//| grayscale) for a deep, non-flat luxury look.                      |
//+------------------------------------------------------------------+
#define C_BG_ROOT          C'8,7,14'
#define C_BG_HEADER        C'16,13,24'
#define C_BG_SECTION       C'20,17,30'
#define C_BG_ROW_ALT       C'26,22,38'
#define C_BG_BADGE         C'34,28,48'

#define C_BORDER_OUTER     C'120,98,55'
#define C_BORDER_SECTION   C'52,44,34'
#define C_BORDER_ACCENT    C'201,162,77'

#define C_TEXT_BRIGHT      C'245,238,222'
#define C_TEXT_NORMAL      C'196,182,155'
#define C_TEXT_DIM         C'126,112,92'
#define C_TEXT_MUTED       C'80,70,58'

#define C_BRAND_BLUE       C'92,142,232'
#define C_BRAND_CYAN       C'216,178,106'
#define C_BRAND_PURPLE     C'156,112,198'

#define C_GREEN_BRIGHT     C'72,196,120'
#define C_GREEN_DIM        C'34,110,66'
#define C_RED_BRIGHT       C'224,84,84'
#define C_RED_DIM          C'126,42,46'
#define C_YELLOW_BRIGHT    C'230,188,90'
#define C_ORANGE_BRIGHT    C'224,140,70'
#define C_TEAL_BRIGHT      C'92,196,186'

#define C_PILL_LIVE        C'22,120,72'
#define C_PILL_PAUSED       C'132,38,44'
#define C_PILL_TEXT        C'250,245,232'

#define C_PBAR_TRACK       C'22,19,30'
#define C_PBAR_GREEN       C'54,168,96'
#define C_PBAR_RED         C'196,64,64'
#define C_PBAR_YELLOW      C'214,170,80'

// Orb-specific gold ramp (deep -> mid -> bright) for the rotating globe
#define C_GOLD_DEEP        C'110,86,42'
#define C_GOLD_MID         C'196,156,80'
#define C_GOLD_BRIGHT      C'250,224,150'
#define C_GOLD_HALO        C'70,58,34'

//+------------------------------------------------------------------+
//| EXECUTION MODE - an aggressiveness scalar on the adaptive engine's|
//| energy sensitivity, not a fixed behavior mode                    |
//+------------------------------------------------------------------+
enum ExecutionMode { Stealth=1, Adaptive=2, Aggressive=3 };

//+------------------------------------------------------------------+
//| INPUTS                                                            |
//+------------------------------------------------------------------+
input group "=== BIDIRECTIONAL GRID CORE ==="
input ExecutionMode InpMode                = Aggressive;
input int           InpOrdersPerSideBase   = 10;     // total pool = 2x this, split by probability
input bool           InpAutoRecycleStale    = true;

input group "=== ADAPTIVE ENGINE ==="
input int    InpATRPeriod           = 14;    // fast ATR (regime + spacing basis)
input int    InpATRSlowPeriod       = 50;    // slow ATR (reference for scalp-target scaling)
input int    InpVolWindowBars       = 200;   // rolling history depth for volatility percentile
input int    InpMomentumLookback    = 10;    // bars for vol-adjusted ROC
input int    InpMicroCandleLookback = 8;     // bars for wick/body bias
input int    InpVolumeZWindow       = 50;    // bars for tick-volume z-score
input double InpAdaptExtremeVolGate = 0.95;  // pause new grid deploys above this vol percentile (0..1)

input group "=== PROBABILISTIC BIDIRECTIONAL ENGINE ==="
input bool   InpUseProbabilisticSplit = true;  // false = legacy fixed 50/50 split
input double InpProbNeutralBand       = 0.08;  // +/- around 0.5 treated as low-conviction (stays near 50/50)

input group "=== MARKET MICROSTRUCTURE ENGINE ==="
input int    InpTickBufferSize        = 30;    // rolling raw-tick buffer for velocity/accel/imbalance
input int    InpSpreadAvgWindow       = 100;   // bars for rolling spread baseline
input int    InpCompressionLookbackBars = 20;  // bars per side for range compression/expansion check

input group "=== CHOPPINESS / OVERTRADE GUARD ==="
input bool   InpUseChopGuard          = true;  // shrink the order pool in a ranging, no-edge market
input double InpChopVolMax            = 0.35;  // vol regime percentile below this = "too quiet"
input double InpChopProbBand          = 0.10;  // bullish probability within 0.5+/-this = "no conviction"
input double InpChopCompressionMax    = 0.65;  // compression ratio below this = "range is contracting"
input double InpChopPoolReduction     = 0.35;  // fraction of the normal pool kept while chop is detected

input group "=== TRADE FREQUENCY THROTTLE ==="
input bool   InpUseTradeThrottle      = true;  // cap new fills per rolling window (anti-overtrade)
input int    InpMaxTradesPerWindow    = 6;     // max fills allowed inside the window below
input int    InpTradeWindowMinutes    = 5;     // rolling window length, minutes

input group "=== CONSECUTIVE LOSS COOLDOWN ==="
input bool   InpUseLossCooldown       = true;  // hard-pause new deploys after a losing streak
input int    InpLossCooldownTrigger   = 3;     // consecutive losses that trigger the cooldown
input int    InpLossCooldownMinutes   = 10;    // how long new deploys stay paused

input group "=== ADAPTIVE PENDING ORDER ENGINE ==="
input int    InpRebalanceEveryTicks       = 15;   // re-check/top-up the ladder every N ticks
input double InpGridRebuildDriftPct       = 25.0; // % drift in grid step vs last deploy that forces a full rebuild
input int    InpMinSecondsBetweenDeploys  = 3;    // floor between deploy/rebalance actions

input group "=== ADAPTIVE SPACING (ATR multiples, bounds not fixed values) ==="
input double InpAdaptSpacingMinATR  = 0.020; // tightest grid step (calm/choppy market)
input double InpAdaptSpacingMaxATR  = 0.090; // widest grid step (volatile/spiking market)

input group "=== ADAPTIVE SL/TP (ATR multiples, bounds not fixed values) ==="
input double InpAdaptSLMinATR = 0.6;
input double InpAdaptSLMaxATR = 1.6;
input double InpAdaptTPMinATR = 1.2;
input double InpAdaptTPMaxATR = 3.2;

input group "=== ADAPTIVE ORDER COUNT (per side, bounds not fixed) ==="
input int InpAdaptOrdersMin = 4;
input int InpAdaptOrdersMax = 14;

input group "=== ADAPTIVE STALE-ORDER LIFETIME (seconds, bounds not fixed) ==="
input int InpAdaptLifetimeMinSec = 20;   // fast market: recycle stale orders quickly
input int InpAdaptLifetimeMaxSec = 90;   // calm market: give orders longer to fill

input group "=== ADAPTIVE SCALPING TARGET ($ bounds, not a fixed value) ==="
input double InpScalpProfitTargetBase = 0.6;  // scaled by current ATR vs slow-ATR reference
input double InpAdaptScalpMin = 0.30;
input double InpAdaptScalpMax = 2.00;
input bool   InpUseScalpTarget     = true;
input bool   InpCloseAtScalpTarget = true;

input group "=== HARD TAKE PROFIT OVERRIDE ==="
input bool   InpUseHardTP   = true;  // true = ignore the adaptive scalp target below, use a fixed $ value
input double InpHardTPValue = 1.0;   // fixed $ profit target per trade when InpUseHardTP is true

input group "=== TIERED EXIT CLUSTERS (intelligent exit system) ==="
input bool   InpUseTieredExits         = true;
input double InpCluster1ScalpMult      = 0.5;  // CL1 quick-exit: fraction of the normal adaptive scalp target
input double InpCluster3TrailTightMult = 0.6;  // CL3 trailing cluster: tighten trail distance multiplier
input double InpCluster3TrailStartMult = 0.7;  // CL3: engage breakeven/trail sooner (multiplies ATR trigger)

input group "=== EXECUTION QUALITY ENGINE ==="
input bool   InpUseExecutionQualityGovernor = true;
input double InpMaxAcceptableSlippagePts    = 15.0; // points of adverse slippage treated as "poor" fill
input double InpQualityDampThreshold        = 0.55; // below this rolling quality score, damp aggression
input double InpQualityDampFactor           = 0.6;  // multiplier applied to energy/lot when quality is poor

input group "=== ADAPTIVE AGGRESSION (win/loss streak) ==="
input bool   InpUseStreakAggression = true;
input int    InpStreakCap           = 6;     // streak length beyond which extra streak has no further effect
input double InpStreakWinBoost      = 0.05;  // aggression += per consecutive win (capped)
input double InpStreakLossPenalty   = 0.08;  // aggression -= per consecutive loss (capped)

input group "=== RISK MANAGEMENT ==="
input double InpBaseLot      = 0.15;
input double InpRiskPercent  = 0.5;
input double InpMaxTotalLots = 3.0;

input group "=== EXECUTION ENGINE ==="
input bool InpUseTickDrivenMgmt = true;
input int  InpTradeDeviationPts = 5;
input int  InpTimerMs           = 100;

input group "=== POSITION MANAGEMENT (base multiples, scaled live by energy) ==="
input int    InpMaxHoldMinutes      = 60;
input bool   InpForceCloseAtMaxHold = false;
input bool   InpUseBreakeven        = true;
input double InpBreakevenATRBase    = 0.6;
input double InpBreakevenBufferPts  = 10;
input bool   InpUseTrailing         = true;
input double InpTrailStartATRBase   = 1.0;
input double InpTrailATRBase        = 0.5;

input group "=== CIRCUIT BREAKER ==="
input double InpDailyProfitTarget   = 50.0;
input double InpDailyLossLimit      = 30.0;
input bool   InpCloseAllOnLossLimit = true;
input double InpMaxDrawdownPct      = 8.0;

input group "=== ANALYSIS ==="
input ENUM_TIMEFRAMES InpAnalysisTF   = PERIOD_M1;
input int             InpMaxSpreadPts = 80;

input group "=== ADAPTIVE DASHBOARD ==="
input bool InpShowDashboard = true;
input int  InpDashX         = 8;
input int  InpDashY         = 8;

//+------------------------------------------------------------------+
//| GLOBAL VARIABLES                                                  |
//+------------------------------------------------------------------+
CTrade trade;
int    handleATR;
int    handleATRSlow;
int    magic = 990013;

double   dayStartBalance    = 0.0;
int      lastDayChecked     = -1;
double   dailyProfit        = 0.0;
double   peakEquity         = 0.0;
double   grossProfit        = 0.0;
double   grossLoss          = 0.0;
int      totalWins          = 0;
int      totalLosses        = 0;
bool     tradingEnabled     = true;
double   recentProfitFactor = 1.0;

double   totalScalpProfit = 0.0;
int      scalpWins        = 0;

datetime lastTickManagement = 0;
datetime lastGridDeployTime = 0;
datetime eaStartTime        = 0;
datetime lastAdaptBarTime   = 0;

int    symbolDigits = 0;
double symbolPoint  = 0.0;
double pipSize      = 0.0;
bool   isJPYPair    = false;

double   cachedATR    = 0.0;
datetime atrCacheTime = 0;
double   cachedATRSlow = 0.0;

double sparkData[8];
int    sparkHead = 0;

double lastDeployedGridStepATR = 0.0;
int    rebalanceTickCounter    = 0;

//+------------------------------------------------------------------+
//| ADAPTIVE ENGINE STATE                                             |
//+------------------------------------------------------------------+
struct AdaptiveState
{
   double volRegime;
   double momentumScore;
   double microBias;
   double volumeSurge;
   double combinedBias;
   double combinedEnergy;

   double bullishProbability;   // heuristic directional confidence, 0..1 (see header note)
   double bearishProbability;   // = 1 - bullishProbability
   double buyRiskAlloc;         // 0..1 fraction of per-side risk budget
   double sellRiskAlloc;

   double dynGridStepATR;
   double dynSLATRMult;
   double dynTPATRMult;
   double dynScalpTarget;
   int    dynBuyOrders;
   int    dynSellOrders;
   int    dynLifetimeSec;
   double dynBreakevenATRMult;
   double dynTrailStartATRMult;
   double dynTrailATRMult;

   bool   extremeVolGateActive;
   bool   chopDetected;
   bool   ready;
};
AdaptiveState ad;

// Rolling ATR history for percentile computation
double volHistory[];
int    volHistCount = 0;
int    volHistHead  = 0;

// Rolling spread history for spread-expansion computation
double spreadHistory[];
int    spreadHistCount = 0;
int    spreadHistHead  = 0;

//+------------------------------------------------------------------+
//| MARKET MICROSTRUCTURE ENGINE STATE                                |
//| Tick-buffer and candle-based proxies. MT5's standard tick/rates   |
//| feed has no L2 depth, so "pressure" and "liquidity grab" here are |
//| approximations built from price/spread behaviour, not real book  |
//| data.                                                             |
//+------------------------------------------------------------------+
struct MicroState
{
   double tickVelocity;         // approx price units/sec from the raw tick buffer
   double tickAcceleration;     // change in tickVelocity between consecutive samples
   double atrAcceleration;      // (ATRnow - recentAvgATR)/recentAvgATR
   double spreadExpansion;      // current spread / rolling average spread
   double sessionLiquidity;     // 0..1 heuristic, server-time based - recalibrate per broker
   double tickImbalance;        // -1..1, upticks vs downticks in the buffer
   double bidAskPressure;       // -1..1 proxy from price position within bid/ask across the buffer
   double compressionRatio;     // recent-range / prior-range; <1 compression, >1 expansion
   bool   liquidityGrabDetected;
   bool   exhaustionDetected;
};
MicroState micro;

double tbPrice[];
long   tbTimeMsc[];
double tbBid[];
double tbAsk[];
int    tbHead  = 0;
int    tbCount = 0;

//+------------------------------------------------------------------+
//| EXECUTION QUALITY ENGINE STATE                                    |
//+------------------------------------------------------------------+
struct ExecState
{
   double avgSlippagePts;
   double posSlippageSum; int posSlippageCount;
   double negSlippageSum; int negSlippageCount;
   double avgLatencyMs;     // placement-to-fill delay proxy, see header note
   int    fillCount;
   double qualityScore;     // 0..1 rolling, 1 = clean fills
};
ExecState exq;

//+------------------------------------------------------------------+
//| ADAPTIVE AGGRESSION (WIN/LOSS STREAK) STATE                       |
//+------------------------------------------------------------------+
struct StreakState
{
   int    winStreak;
   int    lossStreak;
   double aggressionMult; // applied into the same energy scalar as InpMode
};
StreakState streak;
datetime lossCooldownUntil = 0; // new deploys paused until this time when InpUseLossCooldown trips

// Rolling recent-fill timestamps for the trade-frequency throttle
#define FILL_TS_BUF 64
datetime fillTimes[FILL_TS_BUF];
int      fillTimesHead  = 0;
int      fillTimesCount = 0;

void PushFillTime(datetime t)
{
   fillTimes[fillTimesHead % FILL_TS_BUF] = t;
   fillTimesHead++;
   if(fillTimesCount < FILL_TS_BUF) fillTimesCount++;
}
int CountRecentFills(int windowMinutes)
{
   datetime cutoff = TimeCurrent() - windowMinutes*60;
   int lim = MathMin(fillTimesCount, FILL_TS_BUF);
   int cnt = 0;
   for(int i=0;i<lim;i++)
   {
      int idx = (fillTimesHead-1-i+FILL_TS_BUF) % FILL_TS_BUF;
      if(fillTimes[idx] >= cutoff) cnt++;
      else break; // pushed chronologically, so the first older entry ends the count
   }
   return cnt;
}

//+------------------------------------------------------------------+
//| Small math helpers                                                |
//+------------------------------------------------------------------+
double TanhApprox(double x)
{
   double e2x = MathExp(2.0 * x);
   return (e2x - 1.0) / (e2x + 1.0);
}
double ClampD(double v, double lo, double hi) { return MathMax(lo, MathMin(hi, v)); }
int    ClampI(int v, int lo, int hi) { return (int)MathMax(lo, MathMin(hi, v)); }

// Interpolates along the deep-gold -> bright-champagne ramp used by the orb
color ColorBlendGold(double t)
{
   t = ClampD(t, 0.0, 1.0);
   int r1=110,g1=86,b1=42;    // C_GOLD_DEEP
   int r2=250,g2=224,b2=150;  // C_GOLD_BRIGHT
   int r=(int)MathRound(r1+(r2-r1)*t);
   int g=(int)MathRound(g1+(g2-g1)*t);
   int b=(int)MathRound(b1+(b2-b1)*t);
   return (color)(r + (g<<8) + (b<<16));
}

// ── Dashboard layout state ────────────────────────────────────────
struct DashLayout
{
   int  px, py;
   int  pw, ph;
   int  innerW;
   int  padX, padY;

   int  rowH;
   int  sectionGap;
   int  headerH;
   int  coreH;
   int  cardH;
   int  adaptH;
   int  sigH;       // NEW: probability/quality/streak readout block
   int  scalpH;
   int  gridH;
   int  riskH;
   int  perfH;
   int  cbH;
   int  footerH;
   int  secHdrH;

   int  fontSmall;
   int  fontNormal;
   int  fontMed;
   int  fontLarge;
   int  fontHdr;

   int  yHeader, yCore, yCards, yAdapt, ySig;
   int  yScalp, yGrid, yRisk, yPerf, yCB, yFooter;

   double spinAngle, pulsePhase;
   int    objCount;
   bool   needRebuild;
};
DashLayout dl;

//+------------------------------------------------------------------+
//| OBJECT WRAPPERS (unchanged from v8.00)                             |
//+------------------------------------------------------------------+
void DRect(string id,int x,int y,int w,int h,
           color bg,color border=clrNONE,int bw=1,bool back=false)
{
   string n=DASH_PREFIX+id;
   if(ObjectFind(0,n)<0){ObjectCreate(0,n,OBJ_RECTANGLE_LABEL,0,0,0);dl.objCount++;}
   ObjectSetInteger(0,n,OBJPROP_XDISTANCE,   x);
   ObjectSetInteger(0,n,OBJPROP_YDISTANCE,   y);
   ObjectSetInteger(0,n,OBJPROP_XSIZE,       w);
   ObjectSetInteger(0,n,OBJPROP_YSIZE,       h);
   ObjectSetInteger(0,n,OBJPROP_BGCOLOR,     bg);
   ObjectSetInteger(0,n,OBJPROP_BORDER_TYPE, BORDER_FLAT);
   ObjectSetInteger(0,n,OBJPROP_COLOR,       border==clrNONE?bg:border);
   ObjectSetInteger(0,n,OBJPROP_WIDTH,       bw);
   ObjectSetInteger(0,n,OBJPROP_BACK,        back);
   ObjectSetInteger(0,n,OBJPROP_SELECTABLE,  false);
   ObjectSetInteger(0,n,OBJPROP_HIDDEN,      true);
}
void DText(string id,int x,int y,string txt,color clr,
           int fsz=8,string font="Arial",
           ENUM_ANCHOR_POINT anc=ANCHOR_LEFT_UPPER)
{
   string n=DASH_PREFIX+id;
   if(ObjectFind(0,n)<0){ObjectCreate(0,n,OBJ_LABEL,0,0,0);dl.objCount++;}
   ObjectSetInteger(0,n,OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0,n,OBJPROP_YDISTANCE, y);
   ObjectSetString( 0,n,OBJPROP_TEXT,      txt);
   ObjectSetInteger(0,n,OBJPROP_COLOR,     clr);
   ObjectSetInteger(0,n,OBJPROP_FONTSIZE,  fsz);
   ObjectSetString( 0,n,OBJPROP_FONT,      font);
   ObjectSetInteger(0,n,OBJPROP_ANCHOR,    anc);
   ObjectSetInteger(0,n,OBJPROP_SELECTABLE,false);
   ObjectSetInteger(0,n,OBJPROP_HIDDEN,    true);
}
void DSetText (string id,string  v){string n=DASH_PREFIX+id;if(ObjectFind(0,n)>=0)ObjectSetString (0,n,OBJPROP_TEXT,   v);}
void DSetColor(string id,color   c){string n=DASH_PREFIX+id;if(ObjectFind(0,n)>=0)ObjectSetInteger(0,n,OBJPROP_COLOR,  c);}
void DSetBG   (string id,color   c){string n=DASH_PREFIX+id;if(ObjectFind(0,n)>=0)ObjectSetInteger(0,n,OBJPROP_BGCOLOR,c);}
void DSetX    (string id,int     v){string n=DASH_PREFIX+id;if(ObjectFind(0,n)>=0)ObjectSetInteger(0,n,OBJPROP_XDISTANCE,v);}
void DSetY    (string id,int     v){string n=DASH_PREFIX+id;if(ObjectFind(0,n)>=0)ObjectSetInteger(0,n,OBJPROP_YDISTANCE,v);}
void DSetW    (string id,int     v){string n=DASH_PREFIX+id;if(ObjectFind(0,n)>=0)ObjectSetInteger(0,n,OBJPROP_XSIZE,v);}
void DSetH    (string id,int     v){string n=DASH_PREFIX+id;if(ObjectFind(0,n)>=0)ObjectSetInteger(0,n,OBJPROP_YSIZE,v);}

//+------------------------------------------------------------------+
//| FIT LAYOUT - now also budgets space for the SIGNAL/QUALITY block  |
//+------------------------------------------------------------------+
void FitLayout()
{
   int cw = (int)ChartGetInteger(0,CHART_WIDTH_IN_PIXELS);
   int ch = (int)ChartGetInteger(0,CHART_HEIGHT_IN_PIXELS);

   dl.pw   = (int)MathMax(220, MathMin(310, cw * 0.26));
   dl.px   = InpDashX;
   dl.py   = InpDashY;
   dl.padX = 6;
   dl.padY = 4;
   dl.innerW = dl.pw - dl.padX*2;

   int avail = ch - dl.py - 2;
   dl.secHdrH = 17;

   double scale = (double)avail / 700.0;
   scale = MathMax(0.60, MathMin(1.35, scale));

   dl.headerH = (int)MathRound(54  * scale);
   dl.coreH   = (int)MathRound(50  * scale);
   dl.cardH   = (int)MathRound(44  * scale);
   dl.adaptH  = (int)MathRound(96  * scale);
   dl.sigH    = (int)MathRound(84  * scale);   // grew by one row for the Guard status line
   dl.scalpH  = (int)MathRound(68  * scale);
   dl.gridH   = (int)MathRound(92  * scale);
   dl.riskH   = (int)MathRound(64  * scale);
   dl.perfH   = (int)MathRound(88  * scale);
   dl.cbH     = (int)MathRound(52  * scale);
   dl.footerH = (int)MathRound(34  * scale);
   dl.sectionGap = (int)MathRound(3 * scale);

   int totalH = dl.headerH + dl.coreH + dl.cardH
              + (dl.secHdrH + dl.adaptH + dl.sectionGap)
              + (dl.secHdrH + dl.sigH   + dl.sectionGap)
              + (dl.secHdrH + dl.scalpH + dl.sectionGap)
              + (dl.secHdrH + dl.gridH  + dl.sectionGap)
              + (dl.secHdrH + dl.riskH  + dl.sectionGap)
              + (dl.secHdrH + dl.perfH  + dl.sectionGap)
              + (dl.secHdrH + dl.cbH    + dl.sectionGap)
              + dl.footerH + 4;

   if(totalH > avail)
   {
      double shrink = (double)avail / (double)totalH;
      dl.headerH = (int)MathFloor(dl.headerH * shrink);
      dl.coreH   = (int)MathFloor(dl.coreH   * shrink);
      dl.cardH   = (int)MathFloor(dl.cardH   * shrink);
      dl.adaptH  = (int)MathFloor(dl.adaptH  * shrink);
      dl.sigH    = (int)MathFloor(dl.sigH    * shrink);
      dl.scalpH  = (int)MathFloor(dl.scalpH  * shrink);
      dl.gridH   = (int)MathFloor(dl.gridH   * shrink);
      dl.riskH   = (int)MathFloor(dl.riskH   * shrink);
      dl.perfH   = (int)MathFloor(dl.perfH   * shrink);
      dl.cbH     = (int)MathFloor(dl.cbH     * shrink);
      dl.footerH = (int)MathFloor(dl.footerH * shrink);
      dl.sectionGap = 1;
   }

   dl.rowH = MathMax(13, (int)MathRound(16 * scale));
   dl.rowH = MathMin(dl.rowH, 18);

   dl.fontSmall  = (scale < 0.78) ? 6 : 7;
   dl.fontNormal = (scale < 0.78) ? 7 : 8;
   dl.fontMed    = (scale < 0.78) ? 8 : 9;
   dl.fontLarge  = (scale < 0.78) ? 9 : 10;
   dl.fontHdr    = (scale < 0.78) ? 9 : 11;

   int y = dl.py;
   dl.yHeader = y; y += dl.headerH;
   dl.yCore   = y; y += dl.coreH;
   dl.yCards  = y; y += dl.cardH + dl.sectionGap;
   dl.yAdapt  = y; y += dl.secHdrH + dl.adaptH + dl.sectionGap;
   dl.ySig    = y; y += dl.secHdrH + dl.sigH   + dl.sectionGap;
   dl.yScalp  = y; y += dl.secHdrH + dl.scalpH + dl.sectionGap;
   dl.yGrid   = y; y += dl.secHdrH + dl.gridH  + dl.sectionGap;
   dl.yRisk   = y; y += dl.secHdrH + dl.riskH  + dl.sectionGap;
   dl.yPerf   = y; y += dl.secHdrH + dl.perfH  + dl.sectionGap;
   dl.yCB     = y; y += dl.secHdrH + dl.cbH    + dl.sectionGap;
   dl.yFooter = y; y += dl.footerH;

   dl.ph = y - dl.py;
}

//+------------------------------------------------------------------+
//| SECTION HEADER / KV / BADGE / PBAR / CARD helpers (unchanged)     |
//+------------------------------------------------------------------+
void DrawSecHdr(string id,int y,string icon,string title,color accent)
{
   DRect(id+"_B",  dl.px,        y, 3,          dl.secHdrH, accent,      accent,      0, false);
   DRect(id+"_BG", dl.px+3,      y, dl.pw-3,    dl.secHdrH, C_BG_HEADER, C_BG_HEADER, 0, true);
   DRect(id+"_HL", dl.px+3,      y, dl.pw-3,    1,          accent,      accent,      0, false);
   DRect(id+"_UL", dl.px+3,      y+dl.secHdrH-1, dl.pw-3,  1, C_BORDER_SECTION, C_BORDER_SECTION, 0, false);
   DText(id+"_I",  dl.px+7,      y+2, icon,  accent,         dl.fontNormal,"Arial Black");
   DText(id+"_DOT",dl.px+18,     y+2, "♦", accent,      dl.fontSmall, "Arial");
   DText(id+"_T",  dl.px+27,     y+2, title, C_TEXT_BRIGHT,  dl.fontNormal,"Arial Black");
}
void DrawKV(string id,int y,string lbl,string val,
            color vc,bool alt=false,int rh=-1)
{
   if(rh<0) rh=dl.rowH;
   if(alt) DRect(id+"_BG",dl.px,y,dl.pw,rh,C_BG_ROW_ALT,C_BG_ROW_ALT,0);
   DText(id+"_L",dl.px+dl.padX,    y+1, lbl, C_TEXT_DIM,    dl.fontNormal,"Arial");
   DText(id+"_V",dl.px+dl.pw-dl.padX, y+1, val, vc,         dl.fontNormal,"Consolas",ANCHOR_RIGHT_UPPER);
}
void KVVal(string id,string v,color c=clrNONE)
{
   DSetText(id+"_V",v);
   if(c!=clrNONE) DSetColor(id+"_V",c);
}
void DrawBadge(string id,int x,int y,int w,int h,
               string txt,color bg,color tc,int fsz=-1)
{
   if(fsz<0) fsz=dl.fontNormal;
   DRect(id+"_BG",x,y,w,h,bg,bg,0,false);
   DText(id+"_T", x+w/2,y+2,txt,tc,fsz,"Arial Black",ANCHOR_CENTER);
}
void BadgeUpd(string id,string txt,color bg,color tc)
{ DSetText(id+"_T",txt); DSetBG(id+"_BG",bg); DSetColor(id+"_T",tc); }
void DrawPBar(string id,int x,int y,int w,int h,double pct,color fill)
{
   pct=MathMax(0,MathMin(100,pct));
   int fw=MathMax(0,(int)MathRound((w-2)*pct/100.0));
   DRect(id+"_T",x,  y,  w,  h,  C_PBAR_TRACK,C_BORDER_SECTION,1);
   DRect(id+"_F",x+1,y+1,fw,h-2, fill,fill,0);
}
void PBarUpd(string id,int x,int w,double pct,color fill)
{
   pct=MathMax(0,MathMin(100,pct));
   int fw=MathMax(0,(int)MathRound((w-2)*pct/100.0));
   DSetW(id+"_F",fw); DSetBG(id+"_F",fill); DSetX(id+"_F",x+1);
}
void DrawCard(string id,int x,int y,int w,int h,
              string lbl,string val,string sub,color accent,color vc)
{
   DRect(id+"_BG",  x,   y,   w,   h, C_BG_SECTION,C_BORDER_SECTION,1,false);
   DRect(id+"_TOP", x,   y,   w,   2, accent,accent,0,false);
   DRect(id+"_GLOW",x+w-4,y+2,2,2,  accent,accent,0,false);
   DText(id+"_L",   x+w/2, y+4,      lbl, C_TEXT_DIM,   dl.fontSmall, "Arial",      ANCHOR_CENTER);
   DText(id+"_V",   x+w/2, y+h/2-2,  val, vc,           dl.fontMed,   "Arial Black",ANCHOR_CENTER);
   DText(id+"_S",   x+w/2, y+h-8,    sub, C_TEXT_MUTED, dl.fontSmall, "Arial",      ANCHOR_CENTER);
}
void CardUpd(string id,string val,string sub,color vc,color accent=clrNONE)
{
   DSetText(id+"_V",val); DSetColor(id+"_V",vc);
   DSetText(id+"_S",sub);
   if(accent!=clrNONE){DSetBG(id+"_TOP",accent);}
}
//+------------------------------------------------------------------+
//| ROTATING GLOBE ORB                                                 |
//| Built from real circular glyphs (Unicode "filled circle" chars    |
//| rendered as text) layered dark->bright to fake sphere shading,    |
//| plus thin vertical bars whose height follows the circle equation  |
//| (x^2+y^2=R^2) so they curve with the disc instead of looking like |
//| flat rectangles - that curvature + their left-right sweep is what |
//| reads as a rotating meridian line across a spinning globe. Two    |
//| motes orbit the whole sphere on a flattened ellipse for a subtle  |
//| 3D "ring" look. This is the EA's live/paused status indicator -   |
//| the small dot above it, not the globe itself, encodes that state. |
//+------------------------------------------------------------------+
void DrawGlobeOrb(int cx,int cy,int R)
{
   // Faint static halo ring - decorative "orbit frame", not re-drawn per tick
   int ringN=14;
   double ringR=R+7;
   for(int i=0;i<ringN;i++)
   {
      double a=(2.0*M_PI*i)/ringN;
      int hx=cx+(int)MathRound(ringR*MathCos(a))-1;
      int hy=cy+(int)MathRound(ringR*MathSin(a)*0.55)-1;
      DRect("ORB_HALO"+IntegerToString(i),hx,hy,2,2,C_GOLD_HALO,C_GOLD_HALO,0,false);
   }

   // Sphere body: three layered round glyphs, dark base -> mid tone ->
   // bright specular highlight offset toward an upper-left "light source"
   int fBase=(int)MathRound(R*1.60);
   int fMid =(int)MathRound(R*1.15);
   int fHi  =(int)MathRound(R*0.55);
   DText("ORB_BASE",cx,cy,                                     "●",C_GOLD_DEEP,  MathMax(6,fBase),"Arial Black",ANCHOR_CENTER);
   DText("ORB_MID", cx-(int)(R*0.14),cy-(int)(R*0.14),          "●",C_GOLD_MID,   MathMax(6,fMid), "Arial Black",ANCHOR_CENTER);
   DText("ORB_HL",  cx-(int)(R*0.32),cy-(int)(R*0.32),          "●",C_GOLD_BRIGHT,MathMax(4,fHi),  "Arial Black",ANCHOR_CENTER);

   // Rotating meridian bars (placeholders sized/positioned in UpdateGlobeOrb)
   for(int i=0;i<3;i++)
      DRect("ORB_M"+IntegerToString(i),cx,cy,2,2,C_GOLD_MID,C_GOLD_MID,0,false);

   // Orbiting motes
   for(int i=0;i<2;i++)
      DRect("ORB_SAT"+IntegerToString(i),cx,cy,4,4,C_GOLD_BRIGHT,C_GOLD_BRIGHT,0,false);

   // Live/paused status dot, parked just above the globe
   DRect("ORB_STAT",cx-2,cy-R-6,4,4,
         tradingEnabled?C_GREEN_BRIGHT:C_RED_BRIGHT,
         tradingEnabled?C_GREEN_BRIGHT:C_RED_BRIGHT,0,false);
}
void UpdateGlobeOrb(int cx,int cy,int R)
{
   dl.spinAngle  +=0.07; if(dl.spinAngle >2*M_PI) dl.spinAngle =0;
   dl.pulsePhase +=0.13; if(dl.pulsePhase>2*M_PI) dl.pulsePhase=0;

   for(int i=0;i<3;i++)
   {
      double a  = dl.spinAngle + i*(2.0*M_PI/3.0);
      double xr = MathCos(a);
      double bright = MathAbs(MathSin(a));            // brightest/widest through the front-center
      double xOff = xr * R * 0.78;
      double halfH = MathSqrt(MathMax(0.0, (double)R*R - xOff*xOff)) * 0.92;
      int rx = cx + (int)MathRound(xOff) - 1;
      int ry = cy - (int)MathRound(halfH);
      int rh = MathMax(1,(int)MathRound(halfH*2));
      color mc = ColorBlendGold(bright);
      string id="ORB_M"+IntegerToString(i);
      DSetX(id,rx); DSetY(id,ry); DSetW(id,2); DSetH(id,rh); DSetBG(id,mc);
   }

   for(int i=0;i<2;i++)
   {
      double a = dl.spinAngle*1.4 + i*M_PI;
      double satR = R+9;
      int sx=cx+(int)MathRound(satR*MathCos(a))-2;
      int sy=cy+(int)MathRound(satR*MathSin(a)*0.55)-2; // flattened orbit
      string id="ORB_SAT"+IntegerToString(i);
      DSetX(id,sx); DSetY(id,sy);
   }

   double pulse=0.5+0.5*MathSin(dl.pulsePhase);
   int hiF=(int)MathRound(R*(0.45+0.15*pulse));
   ObjectSetInteger(0,DASH_PREFIX+"ORB_HL",OBJPROP_FONTSIZE,MathMax(4,hiF));

   color statC=tradingEnabled?C_GREEN_BRIGHT:C_RED_BRIGHT;
   DSetBG("ORB_STAT",statC);
}
void DrawSparkline(string id,int x,int y,int w,int h)
{
   DRect(id+"_BG",x,y,w,h,C_BG_SECTION,C_BORDER_SECTION,1);
   double mn=1e9,mx=-1e9;
   for(int i=0;i<8;i++){if(sparkData[i]<mn)mn=sparkData[i];if(sparkData[i]>mx)mx=sparkData[i];}
   double rng=mx-mn; if(rng<=0)rng=1;
   int bw=MathMax(1,(w-2)/8);
   for(int i=0;i<8;i++)
   {
      double norm=(sparkData[i]-mn)/rng;
      int bh=MathMax(1,(int)MathRound(norm*(h-3)));
      int bx=x+1+i*bw;
      int by=y+h-1-bh;
      color bc=sparkData[i]>=0?C_GREEN_DIM:C_RED_DIM;
      DRect(id+"_B"+IntegerToString(i),bx,by,bw-1,bh,bc,bc,0);
   }
}
void UpdateSparkline(string id,int x,int y,int w,int h)
{
   double mn=1e9,mx=-1e9;
   for(int i=0;i<8;i++){if(sparkData[i]<mn)mn=sparkData[i];if(sparkData[i]>mx)mx=sparkData[i];}
   double rng=mx-mn; if(rng<=0)rng=1;
   int bw=MathMax(1,(w-2)/8);
   for(int i=0;i<8;i++)
   {
      double norm=(sparkData[i]-mn)/rng;
      int bh=MathMax(1,(int)MathRound(norm*(h-3)));
      int bx=x+1+i*bw;
      int by=y+h-1-bh;
      color bc=sparkData[i]>=0?C_GREEN_DIM:C_RED_DIM;
      DSetX(id+"_B"+IntegerToString(i),bx);
      DSetY(id+"_B"+IntegerToString(i),by);
      DSetH(id+"_B"+IntegerToString(i),bh);
      DSetBG(id+"_B"+IntegerToString(i),bc);
   }
}

//+------------------------------------------------------------------+
//| ADAPTIVE ENGINE CORE (v8 baseline)                                |
//+------------------------------------------------------------------+
void PushVolHistory(double atrVal)
{
   int n = InpVolWindowBars;
   if(ArraySize(volHistory) != n) ArrayResize(volHistory, n);
   volHistory[volHistHead % n] = atrVal;
   volHistHead++;
   if(volHistCount < n) volHistCount++;
}

double ComputeVolPercentile(double atrVal)
{
   if(volHistCount < 20) return 0.5;
   int below = 0;
   for(int i = 0; i < volHistCount; i++)
      if(volHistory[i] <= atrVal) below++;
   return (double)below / (double)volHistCount;
}

double ComputeATRAcceleration(double atrNow)
{
   // Heuristic rate-of-change of volatility: current ATR vs the average of
   // the few bars just before it in the same rolling history buffer.
   if(volHistCount < 6) return 0.0;
   int n = InpVolWindowBars;
   int cntRecent = MathMin(5, volHistCount-1);
   if(cntRecent<=0) return 0.0;
   double sum=0;
   for(int i=1;i<=cntRecent;i++)
      sum += volHistory[(volHistHead - i - 1 + n) % n];
   double avgRecent = sum / cntRecent;
   if(avgRecent<=0) return 0.0;
   return (atrNow - avgRecent) / avgRecent;
}

double ComputeMomentumScore(int lookback, double atr)
{
   if(atr <= 0) return 0.0;
   double c0 = iClose(_Symbol, InpAnalysisTF, 1);
   double cN = iClose(_Symbol, InpAnalysisTF, lookback + 1);
   if(c0 == 0 || cN == 0) return 0.0;
   double roc = (c0 - cN) / atr;
   return TanhApprox(roc / 3.0);
}

double ComputeMicroBias(int lookback)
{
   double upWick = 0, downWick = 0;
   for(int i = 1; i <= lookback; i++)
   {
      double o = iOpen(_Symbol, InpAnalysisTF, i);
      double c = iClose(_Symbol, InpAnalysisTF, i);
      double h = iHigh(_Symbol, InpAnalysisTF, i);
      double l = iLow(_Symbol, InpAnalysisTF, i);
      double top = MathMax(o, c), bot = MathMin(o, c);
      upWick   += (h - top);
      downWick += (bot - l);
   }
   double totalWick = upWick + downWick;
   if(totalWick <= 0) return 0.0;
   double imbalance = (downWick - upWick) / totalWick;
   return ClampD(imbalance, -1.0, 1.0);
}

double ComputeVolumeSurge(int window)
{
   double sum = 0, sumSq = 0;
   int n = MathMin(window, (int)iBars(_Symbol, InpAnalysisTF) - 2);
   if(n < 10) return 0.0;
   long vols[]; ArraySetAsSeries(vols, true);
   if(CopyTickVolume(_Symbol, InpAnalysisTF, 1, n, vols) < n) return 0.0;
   for(int i = 0; i < n; i++) sum += (double)vols[i];
   double mean = sum / n;
   for(int i = 0; i < n; i++) { double d = (double)vols[i] - mean; sumSq += d*d; }
   double std = MathSqrt(sumSq / n);
   if(std <= 0) return 0.0;
   return ((double)vols[0] - mean) / std;
}

double GetCurrentATR()
{
   datetime now = TimeCurrent();
   if(now == atrCacheTime && cachedATR > 0) return cachedATR;
   double buf[]; ArraySetAsSeries(buf, true);
   if(CopyBuffer(handleATR, 0, 0, 1, buf) > 0) { cachedATR = buf[0]; atrCacheTime = now; return cachedATR; }
   return cachedATR > 0 ? cachedATR : 0.0001;
}

double GetSlowATR()
{
   double buf[]; ArraySetAsSeries(buf, true);
   if(CopyBuffer(handleATRSlow, 0, 0, 1, buf) > 0) { cachedATRSlow = buf[0]; }
   return cachedATRSlow > 0 ? cachedATRSlow : GetCurrentATR();
}

//+------------------------------------------------------------------+
//| MARKET MICROSTRUCTURE ENGINE                                     |
//+------------------------------------------------------------------+
void PushTick(const MqlTick &tick)
{
   int n = InpTickBufferSize;
   if(ArraySize(tbPrice) != n)
   {
      ArrayResize(tbPrice,n); ArrayResize(tbTimeMsc,n);
      ArrayResize(tbBid,n);   ArrayResize(tbAsk,n);
   }
   int idx = tbHead % n;
   tbPrice[idx]   = (tick.bid + tick.ask) / 2.0;
   tbTimeMsc[idx] = (long)tick.time_msc;
   tbBid[idx]     = tick.bid;
   tbAsk[idx]     = tick.ask;
   tbHead++;
   if(tbCount < n) tbCount++;
}

void UpdateMicrostructureFast()
{
   int n = InpTickBufferSize;
   if(tbCount < 5) return;

   int latest = (tbHead-1+n) % n;
   int prev   = (tbHead-2+n) % n;
   int prev2  = (tbHead-3+n) % n;

   double dt1 = (double)(tbTimeMsc[latest]-tbTimeMsc[prev]) / 1000.0;
   double dt2 = (double)(tbTimeMsc[prev]-tbTimeMsc[prev2]) / 1000.0;
   if(dt1 <= 0) dt1 = 0.05;
   if(dt2 <= 0) dt2 = 0.05;

   double v1 = (tbPrice[latest]-tbPrice[prev]) / dt1;
   double v2 = (tbPrice[prev]-tbPrice[prev2]) / dt2;
   micro.tickVelocity     = v1;
   micro.tickAcceleration = v1 - v2;

   int ups=0, downs=0;
   int cnt = MathMin(tbCount, n);
   for(int i=1;i<cnt;i++)
   {
      int a=(tbHead-i+n)%n;
      int b=(tbHead-i-1+n)%n;
      if(tbPrice[a] > tbPrice[b]) ups++;
      else if(tbPrice[a] < tbPrice[b]) downs++;
   }
   int tot = ups+downs;
   micro.tickImbalance = (tot>0) ? (double)(ups-downs)/tot : 0.0;

   // Bid/ask "pressure" proxy - NOT real order-book depth. Approximated from
   // where the midpoint tick sat within its own bid/ask spread, averaged
   // across the buffer.
   double sumPos=0; int cnt2=0;
   for(int i=0;i<cnt;i++)
   {
      double range = tbAsk[i]-tbBid[i];
      if(range>0){ sumPos += ((tbPrice[i]-tbBid[i])/range - 0.5)*2.0; cnt2++; }
   }
   micro.bidAskPressure = (cnt2>0) ? ClampD(sumPos/cnt2,-1.0,1.0) : 0.0;
}

double ComputeSpreadAvg()
{
   if(spreadHistCount < 5) return (double)SymbolInfoInteger(_Symbol,SYMBOL_SPREAD);
   double sum=0;
   for(int i=0;i<spreadHistCount;i++) sum += spreadHistory[i];
   return sum / spreadHistCount;
}
void PushSpreadHistory(double s)
{
   int n = InpSpreadAvgWindow;
   if(ArraySize(spreadHistory) != n) ArrayResize(spreadHistory,n);
   spreadHistory[spreadHistHead % n] = s;
   spreadHistHead++;
   if(spreadHistCount < n) spreadHistCount++;
}

double ComputeSessionLiquidity()
{
   // Heuristic session-liquidity curve keyed on SERVER time - recalibrate
   // the hour bands to your broker's actual server-time offset. This is a
   // fixed table, not a live liquidity feed.
   MqlDateTime tmv; TimeToStruct(TimeCurrent(), tmv);
   int h = tmv.hour;
   if(h>=12 && h<=16) return 1.00;
   if(h>=7  && h<12)  return 0.85;
   if(h>=16 && h<20)  return 0.75;
   if(h>=20 || h<2)   return 0.45;
   return 0.60;
}

double ComputeCompressionRatio(int lookback)
{
   double hiR=-1e9, loR=1e9, hiP=-1e9, loP=1e9;
   for(int i=1;i<=lookback;i++)
   {
      double h=iHigh(_Symbol,InpAnalysisTF,i), l=iLow(_Symbol,InpAnalysisTF,i);
      if(h>hiR) hiR=h; if(l<loR) loR=l;
   }
   for(int i=lookback+1;i<=lookback*2;i++)
   {
      double h=iHigh(_Symbol,InpAnalysisTF,i), l=iLow(_Symbol,InpAnalysisTF,i);
      if(h>hiP) hiP=h; if(l<loP) loP=l;
   }
   double rR=hiR-loR, rP=hiP-loP;
   if(rP<=0) return 1.0;
   return rR/rP; // <1 compression, >1 expansion
}

void DetectLiquidityEvents(double atr)
{
   double h=iHigh(_Symbol,InpAnalysisTF,1), l=iLow(_Symbol,InpAnalysisTF,1);
   double o=iOpen(_Symbol,InpAnalysisTF,1), c=iClose(_Symbol,InpAnalysisTF,1);
   double upWick=h-MathMax(o,c), downWick=MathMin(o,c)-l;
   double body=MathAbs(c-o);

   // Liquidity-grab heuristic: a wick spiking beyond 1.2x ATR on a small
   // body approximates a stop-run/fakeout candle - it is not a confirmed
   // order-book liquidity read (no L2 data available via standard MT5 API).
   micro.liquidityGrabDetected = (MathMax(upWick,downWick) > atr*1.2) && (body < atr*0.4);

   double b1=MathAbs(iClose(_Symbol,InpAnalysisTF,1)-iOpen(_Symbol,InpAnalysisTF,1));
   double b2=MathAbs(iClose(_Symbol,InpAnalysisTF,2)-iOpen(_Symbol,InpAnalysisTF,2));
   double b3=MathAbs(iClose(_Symbol,InpAnalysisTF,3)-iOpen(_Symbol,InpAnalysisTF,3));
   micro.exhaustionDetected = (b1<b2 && b2<b3 && (upWick+downWick) > body*1.5);
}

//+------------------------------------------------------------------+
//| PROBABILISTIC BIDIRECTIONAL ENGINE                                |
//| A hand-weighted logistic squash of existing signals - explicitly  |
//| NOT a trained classifier or calibrated statistical probability.   |
//+------------------------------------------------------------------+
double ComputeBullishProbability()
{
   double raw = 0.35*ad.momentumScore
              + 0.20*ad.microBias
              + 0.20*micro.tickImbalance
              + 0.15*micro.bidAskPressure
              + 0.10*(micro.liquidityGrabDetected ? (micro.bidAskPressure>0 ? -0.5 : 0.5) : 0.0);
   double p = 0.5 + 0.5*TanhApprox(raw*1.4);
   if(MathAbs(p-0.5) < InpProbNeutralBand)
      p = 0.5 + (p-0.5)*0.3; // dampen low-conviction reads so the EA stays genuinely bidirectional
   return ClampD(p,0.05,0.95); // never fully commit one-sided
}

//+------------------------------------------------------------------+
//| EXECUTION QUALITY ENGINE                                          |
//+------------------------------------------------------------------+
void UpdateExecutionQualityFromDeal(ulong dealTicket, ulong orderTicket)
{
   if(!HistoryOrderSelect(orderTicket)) return;
   double expected   = HistoryOrderGetDouble(orderTicket, ORDER_PRICE_OPEN);
   datetime setupT   = (datetime)HistoryOrderGetInteger(orderTicket, ORDER_TIME_SETUP);
   ENUM_ORDER_TYPE ot=(ENUM_ORDER_TYPE)HistoryOrderGetInteger(orderTicket, ORDER_TYPE);
   double actual     = HistoryDealGetDouble(dealTicket, DEAL_PRICE);
   datetime dealT    = (datetime)HistoryDealGetInteger(dealTicket, DEAL_TIME);

   double slipPts = 0;
   if(ot==ORDER_TYPE_BUY_STOP)       slipPts = (actual-expected)/symbolPoint;
   else if(ot==ORDER_TYPE_SELL_STOP) slipPts = (expected-actual)/symbolPoint;

   exq.fillCount++;
   exq.avgSlippagePts = ((exq.avgSlippagePts*(exq.fillCount-1)) + slipPts) / exq.fillCount;
   if(slipPts>=0) { exq.posSlippageSum += slipPts;          exq.posSlippageCount++; }
   else           { exq.negSlippageSum += MathAbs(slipPts); exq.negSlippageCount++; }

   // Placement-to-fill delay proxy - see header note: this is dominated by
   // how long the market took to reach the stop price, NOT a broker
   // round-trip latency measurement.
   double delayMs = (double)(dealT - setupT) * 1000.0;
   exq.avgLatencyMs = ((exq.avgLatencyMs*(exq.fillCount-1)) + delayMs) / exq.fillCount;

   double slipScore = ClampD(1.0 - MathAbs(slipPts)/MathMax(1.0,InpMaxAcceptableSlippagePts), 0.0, 1.0);
   exq.qualityScore  = (exq.fillCount<=1) ? slipScore : (0.85*exq.qualityScore + 0.15*slipScore);
}

//+------------------------------------------------------------------+
//| ADAPTIVE AGGRESSION (WIN/LOSS STREAK) ENGINE                     |
//+------------------------------------------------------------------+
void UpdateStreakAggression(bool isWin)
{
   if(isWin) { streak.winStreak++;  streak.lossStreak=0; lossCooldownUntil=0; }
   else      { streak.lossStreak++; streak.winStreak=0;  }
   int wCap = MathMin(streak.winStreak,  InpStreakCap);
   int lCap = MathMin(streak.lossStreak, InpStreakCap);
   streak.aggressionMult = ClampD(1.0 + InpStreakWinBoost*wCap - InpStreakLossPenalty*lCap, 0.5, 1.4);

   if(!isWin && InpUseLossCooldown && streak.lossStreak>=InpLossCooldownTrigger)
   {
      lossCooldownUntil = TimeCurrent() + InpLossCooldownMinutes*60;
      Print("LOSS COOLDOWN engaged: ",streak.lossStreak," consecutive losses -> new deploys paused for ",
            InpLossCooldownMinutes," min (existing positions still managed)");
   }
}

//+------------------------------------------------------------------+
//| Recompute the full adaptive state. Heavy per-bar features are     |
//| gated to once per closed bar; probability/microstructure fast     |
//| reads and grid/risk mapping happen every call.                    |
//+------------------------------------------------------------------+
void UpdateAdaptiveState()
{
   datetime barTime = iTime(_Symbol, InpAnalysisTF, 0);
   bool newBar = (barTime != lastAdaptBarTime);

   double atr = GetCurrentATR();
   if(atr <= 0) { ad.ready = false; return; }

   if(newBar)
   {
      lastAdaptBarTime = barTime;
      PushVolHistory(atr);

      ad.momentumScore = ComputeMomentumScore(InpMomentumLookback, atr);
      ad.microBias      = ComputeMicroBias(InpMicroCandleLookback);
      ad.volumeSurge     = ComputeVolumeSurge(InpVolumeZWindow);

      PushSpreadHistory((double)SymbolInfoInteger(_Symbol,SYMBOL_SPREAD));
      double avgSpread = ComputeSpreadAvg();
      micro.spreadExpansion  = (avgSpread>0) ? (double)SymbolInfoInteger(_Symbol,SYMBOL_SPREAD)/avgSpread : 1.0;
      micro.sessionLiquidity = ComputeSessionLiquidity();
      micro.compressionRatio = ComputeCompressionRatio(InpCompressionLookbackBars);
      micro.atrAcceleration  = ComputeATRAcceleration(atr);
      DetectLiquidityEvents(atr);
   }

   UpdateMicrostructureFast();

   ad.volRegime = ComputeVolPercentile(atr);

   double modeScalar = (InpMode == Aggressive) ? 1.15 : (InpMode == Stealth) ? 0.80 : 1.0;
   if(InpUseStreakAggression) modeScalar *= streak.aggressionMult;
   if(InpUseExecutionQualityGovernor && exq.qualityScore < InpQualityDampThreshold)
      modeScalar *= InpQualityDampFactor;

   ad.combinedBias   = ClampD(0.55 * ad.momentumScore + 0.45 * ad.microBias, -1.0, 1.0);
   ad.combinedEnergy = ClampD(0.65 * ad.volRegime + 0.35 * MathMin(1.0, MathAbs(ad.volumeSurge) / 3.0), 0.0, 1.0);
   ad.combinedEnergy = ClampD(ad.combinedEnergy * modeScalar, 0.0, 1.0);

   // ── Probability engine: directional confidence drives BOTH order count
   //    and per-side risk allocation instead of a fixed 50/50 split ──
   ad.bullishProbability = InpUseProbabilisticSplit ? ComputeBullishProbability() : 0.5;
   ad.bearishProbability = 1.0 - ad.bullishProbability;
   ad.buyRiskAlloc        = ad.bullishProbability;
   ad.sellRiskAlloc       = ad.bearishProbability;

   // ── Choppiness / no-edge guard: a compressed range with low volatility
   //    AND no directional conviction is exactly the condition that produces
   //    rapid alternating buy/sell fills (both sides of the ladder sit close
   //    to price and get whipsawed). Detected here, the pool is shrunk hard
   //    instead of turned off outright - the EA stays bidirectional, just far
   //    lighter, until either volatility, compression, or conviction changes.
   bool chopDetected = InpUseChopGuard
      && (ad.volRegime < InpChopVolMax)
      && (MathAbs(ad.bullishProbability-0.5) < InpChopProbBand)
      && (micro.compressionRatio < InpChopCompressionMax);
   ad.chopDetected = chopDetected;

   int totalPool = ClampI(InpOrdersPerSideBase*2, InpAdaptOrdersMin*2, InpAdaptOrdersMax*2);
   if(chopDetected)
      totalPool = ClampI((int)MathRound(totalPool*InpChopPoolReduction), InpAdaptOrdersMin*2, InpAdaptOrdersMax*2);
   ad.dynBuyOrders  = ClampI((int)MathRound(totalPool*ad.bullishProbability), InpAdaptOrdersMin, InpAdaptOrdersMax);
   ad.dynSellOrders = ClampI(totalPool - ad.dynBuyOrders,                     InpAdaptOrdersMin, InpAdaptOrdersMax);

   // ── Dynamic grid intelligence: base ATR-scaled spacing further modulated
   //    by tick velocity/acceleration, ATR acceleration, spread expansion and
   //    session liquidity - all bounded so it never runs away. ──
   ad.dynGridStepATR = InpAdaptSpacingMinATR + (InpAdaptSpacingMaxATR - InpAdaptSpacingMinATR) * ad.combinedEnergy;
   double microMult = 1.0
      + 0.20*ClampD(MathAbs(micro.tickAcceleration)*5.0, 0.0, 1.0)
      + 0.15*ClampD(micro.spreadExpansion-1.0, -0.5, 1.0)
      + 0.20*ClampD(micro.atrAcceleration, -0.5, 1.0)
      + 0.15*(1.0-micro.sessionLiquidity)
      + 0.25*ClampD(1.0-micro.compressionRatio, 0.0, 0.6); // FIXED: a compressed range must WIDEN
                                                             // spacing (require a bigger move to
                                                             // trigger), not tighten it - tightening
                                                             // here was the bug feeding the
                                                             // rapid-fire buy/sell whipsaw pattern.
   microMult = ClampD(microMult, 0.6, 2.2);
   ad.dynGridStepATR = ClampD(ad.dynGridStepATR*microMult, InpAdaptSpacingMinATR*0.5, InpAdaptSpacingMaxATR*2.2);


   ad.dynSLATRMult = InpAdaptSLMinATR + (InpAdaptSLMaxATR - InpAdaptSLMinATR) * ad.combinedEnergy;
   ad.dynTPATRMult = InpAdaptTPMinATR + (InpAdaptTPMaxATR - InpAdaptTPMinATR) * ad.combinedEnergy;
   if(MathAbs(ad.combinedBias) > 0.4)
      ad.dynTPATRMult *= (1.0 + 0.5 * MathAbs(ad.combinedBias));

   ad.dynLifetimeSec = (int)MathRound(InpAdaptLifetimeMaxSec - (InpAdaptLifetimeMaxSec - InpAdaptLifetimeMinSec) * ad.combinedEnergy);

   double slowAtr = GetSlowATR();
   double atrRatio = (slowAtr > 0) ? atr / slowAtr : 1.0;
   ad.dynScalpTarget = InpUseHardTP
      ? InpHardTPValue
      : ClampD(InpScalpProfitTargetBase * atrRatio, InpAdaptScalpMin, InpAdaptScalpMax);

   double energyStretch = 0.75 + 0.5 * ad.combinedEnergy;
   ad.dynBreakevenATRMult  = InpBreakevenATRBase  * energyStretch;
   ad.dynTrailStartATRMult = InpTrailStartATRBase * energyStretch;
   ad.dynTrailATRMult      = InpTrailATRBase      * energyStretch;

   ad.extremeVolGateActive = (ad.volRegime >= InpAdaptExtremeVolGate);
   ad.ready = (volHistCount >= 20);
}

//+------------------------------------------------------------------+
//| EA CORE FUNCTIONS                                                  |
//+------------------------------------------------------------------+
double CalculateLotSize(double slDistance, double sideRiskAlloc=1.0)
{
   if(InpRiskPercent<=0) return NormalizeVolume(InpBaseLot);
   double eq=AccountInfoDouble(ACCOUNT_EQUITY);
   // sideRiskAlloc is 0..1 with 0.5 = neutral; *2.0 keeps the neutral case
   // equivalent to the legacy symmetric-risk behaviour, while a dominant
   // side can flex up to ~1.8x and a weak side is damped, never zeroed.
   double riskMult = ClampD(sideRiskAlloc*2.0, 0.3, 1.8);
   double ra=eq*InpRiskPercent/100.0*recentProfitFactor*riskMult;
   double tv=SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_VALUE);
   double ts=SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE);
   if(tv<=0||ts<=0) return NormalizeVolume(InpBaseLot);
   double rpl=(slDistance/ts)*tv;
   if(rpl<=0) return NormalizeVolume(InpBaseLot);
   double energyDamp = (ad.combinedEnergy > 0.85) ? 0.7 : 1.0;
   double qualityDamp = (InpUseExecutionQualityGovernor && exq.qualityScore < InpQualityDampThreshold) ? InpQualityDampFactor : 1.0;
   return NormalizeVolume(ra/rpl*energyDamp*qualityDamp);
}

double NormalizeVolume(double vol)
{
   double st=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_STEP);
   double mn=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN);
   double mx=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MAX);
   if(st<=0)st=0.01;
   return NormalizeDouble(MathMax(mn,MathMin(mx,MathRound(vol/st)*st)),2);
}

int DeleteAllPendingOrders()
{
   int d=0;
   for(int i=OrdersTotal()-1;i>=0;i--)
   {
      ulong t=OrderGetTicket(i);
      if(t==0||!OrderSelect(t)) continue;
      if(OrderGetString(ORDER_SYMBOL)!=_Symbol||OrderGetInteger(ORDER_MAGIC)!=magic) continue;
      if(trade.OrderDelete(t)) d++;
   }
   return d;
}

int DeleteStaleOrders()
{
   if(!InpAutoRecycleStale) return 0;
   datetime now=TimeCurrent(); int d=0;
   for(int i=OrdersTotal()-1;i>=0;i--)
   {
      ulong t=OrderGetTicket(i);
      if(t==0||!OrderSelect(t)) continue;
      if(OrderGetString(ORDER_SYMBOL)!=_Symbol||OrderGetInteger(ORDER_MAGIC)!=magic) continue;
      int age=(int)(now-(datetime)OrderGetInteger(ORDER_TIME_SETUP));
      if(age>=ad.dynLifetimeSec&&trade.OrderDelete(t))
      {d++;Print("recycle STALE #",t," (",age,"s >= dyn lifetime ",ad.dynLifetimeSec,"s)");}
   }
   return d;
}

void CountPendingBySide(int &buyCnt,int &sellCnt)
{
   buyCnt=0; sellCnt=0;
   for(int i=0;i<OrdersTotal();i++)
   {
      ulong t=OrderGetTicket(i);
      if(t==0||!OrderSelect(t)) continue;
      if(OrderGetString(ORDER_SYMBOL)!=_Symbol||OrderGetInteger(ORDER_MAGIC)!=magic) continue;
      ENUM_ORDER_TYPE ot=(ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
      if(ot==ORDER_TYPE_BUY_STOP) buyCnt++;
      else if(ot==ORDER_TYPE_SELL_STOP) sellCnt++;
   }
}

int ClusterForIndex(int idx,int total)
{
   if(total<=0) return 2;
   if(idx < total/3) return 1;
   if(idx < (2*total)/3) return 2;
   return 3;
}

int GetClusterFromComment(string cmt)
{
   if(StringFind(cmt,"_CL1")>=0) return 1;
   if(StringFind(cmt,"_CL3")>=0) return 3;
   return 2;
}

//+------------------------------------------------------------------+
//| ADAPTIVE PENDING ORDER ENGINE                                     |
//| Tops up deficits every rebalance pass instead of only redeploying |
//| from a clean slate, and forces a full rebuild when live spacing   |
//| has drifted materially from what's currently resting on the book. |
//+------------------------------------------------------------------+
void DeployOrRebalanceGrid()
{
   if(!ad.ready) return;
   if(ad.extremeVolGateActive)
   {
      DeleteStaleOrders();
      return;
   }
   if(GetTotalExposure()>=InpMaxTotalLots) return;

   // Spread gate - previously InpMaxSpreadPts only recolored a dashboard
   // label and never actually stopped a trade. Widened spread eats a
   // disproportionate share of a small scalp target, so it now blocks new
   // deploys/rebalances outright (existing positions are still managed).
   long liveSpread=SymbolInfoInteger(_Symbol,SYMBOL_SPREAD);
   if(liveSpread>InpMaxSpreadPts) { DeleteStaleOrders(); return; }

   // Trade-frequency throttle - caps how many fills can land in a rolling
   // window, so a choppy burst can't keep re-triggering the ladder faster
   // than the streak/chop guards can react.
   if(InpUseTradeThrottle && CountRecentFills(InpTradeWindowMinutes)>=InpMaxTradesPerWindow)
      return;

   // Consecutive-loss cooldown - a hard pause on NEW deploys (not just an
   // aggression multiplier) once losses stack up, so the EA sits out rather
   // than keep feeding a losing regime.
   if(InpUseLossCooldown && lossCooldownUntil>0 && TimeCurrent()<lossCooldownUntil)
      return;

   MqlTick tick; if(!SymbolInfoTick(_Symbol,tick)) return;
   double atr=GetCurrentATR(); if(atr<=0) return;
   double mid=(tick.bid+tick.ask)/2.0;
   int    digs=symbolDigits;
   long   sl=SymbolInfoInteger(_Symbol,SYMBOL_TRADE_STOPS_LEVEL);
   double msd=sl*symbolPoint;
   double sld=MathMax(atr*ad.dynSLATRMult,msd*1.5);
   double tpd=atr*ad.dynTPATRMult;
   double gap=atr*ad.dynGridStepATR;

   bool forceRebuild=false;
   if(lastDeployedGridStepATR>0)
   {
      double drift = MathAbs(gap-lastDeployedGridStepATR)/lastDeployedGridStepATR*100.0;
      if(drift>=InpGridRebuildDriftPct) forceRebuild=true;
   }

   int existBuy=0, existSell=0;
   if(forceRebuild)
   {
      DeleteAllPendingOrders();
      existBuy=0; existSell=0;
   }
   else
   {
      DeleteStaleOrders();
      CountPendingBySide(existBuy,existSell);
   }

   bool haveEnough = (!forceRebuild && existBuy>=ad.dynBuyOrders && existSell>=ad.dynSellOrders);
   if(TimeCurrent()-lastGridDeployTime<InpMinSecondsBetweenDeploys && haveEnough) return;
   if(haveEnough) return;

   int needBuy  = MathMax(0, ad.dynBuyOrders  - existBuy);
   int needSell = MathMax(0, ad.dynSellOrders - existSell);
   if(needBuy==0 && needSell==0) { lastDeployedGridStepATR=gap; return; }

   double lotBuy  = CalculateLotSize(sld, ad.buyRiskAlloc);
   double lotSell = CalculateLotSize(sld, ad.sellRiskAlloc);
   double fo=gap*2.0;

   int bc=0,sc=0;
   for(int i=0;i<needBuy;i++)
   {
      int gi=existBuy+i;
      double ep=NormalizeDouble(mid+fo+gi*gap,digs);
      if(ep<=tick.ask) continue;
      double slp=NormalizeDouble(ep-sld,digs),tpp=NormalizeDouble(ep+tpd,digs);
      if((ep-slp)<msd||(tpp-ep)<msd) continue;
      if(lotBuy<SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN)) continue;
      int cl=ClusterForIndex(gi,ad.dynBuyOrders);
      string cmt="ADAPT_BUY_"+IntegerToString(gi+1)+"_CL"+IntegerToString(cl);
      if(trade.BuyStop(lotBuy,ep,_Symbol,slp,tpp,ORDER_TIME_GTC,0,cmt)) bc++;
   }
   for(int i=0;i<needSell;i++)
   {
      int gi=existSell+i;
      double ep=NormalizeDouble(mid-fo-gi*gap,digs);
      if(ep>=tick.bid) continue;
      double slp=NormalizeDouble(ep+sld,digs),tpp=NormalizeDouble(ep-tpd,digs);
      if((slp-ep)<msd||(ep-tpp)<msd) continue;
      if(lotSell<SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN)) continue;
      int cl=ClusterForIndex(gi,ad.dynSellOrders);
      string cmt="ADAPT_SELL_"+IntegerToString(gi+1)+"_CL"+IntegerToString(cl);
      if(trade.SellStop(lotSell,ep,_Symbol,slp,tpp,ORDER_TIME_GTC,0,cmt)) sc++;
   }
   lastGridDeployTime=TimeCurrent();
   lastDeployedGridStepATR=gap;
   Print("GRID sync: +",bc," BUY / +",sc," SELL | P(bull)=",DoubleToString(ad.bullishProbability,2),
         " energy=",DoubleToString(ad.combinedEnergy,2)," step=",DoubleToString(gap,2),
         forceRebuild?" [REBUILD]":" [TOP-UP]");
}

//+------------------------------------------------------------------+
//| ORDER SYNCHRONIZATION ENGINE                                      |
//| Fires immediately after any fill: re-reads directional confidence |
//| and thins the furthest (lowest-priority) contrarian pending       |
//| orders instead of leaving the rest of the ladder on a stale read. |
//+------------------------------------------------------------------+
void SynchronizeOrdersAfterFill(bool filledWasBuy)
{
   double p = InpUseProbabilisticSplit ? ComputeBullishProbability() : 0.5;
   bool contrarian = filledWasBuy ? (p < 0.40) : (p > 0.60);
   if(!contrarian) return;

   MqlTick tick; if(!SymbolInfoTick(_Symbol,tick)) return;
   double mid=(tick.bid+tick.ask)/2.0;
   ENUM_ORDER_TYPE wantType = filledWasBuy ? ORDER_TYPE_BUY_STOP : ORDER_TYPE_SELL_STOP;

   ulong  farTickets[]; double farDist[]; int cnt=0;
   for(int i=0;i<OrdersTotal();i++)
   {
      ulong t=OrderGetTicket(i);
      if(t==0||!OrderSelect(t)) continue;
      if(OrderGetString(ORDER_SYMBOL)!=_Symbol||OrderGetInteger(ORDER_MAGIC)!=magic) continue;
      if((ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE)!=wantType) continue;
      ArrayResize(farTickets,cnt+1); ArrayResize(farDist,cnt+1);
      farTickets[cnt]=t;
      farDist[cnt]=MathAbs(OrderGetDouble(ORDER_PRICE_OPEN)-mid);
      cnt++;
   }
   if(cnt<2) return;

   for(int i=0;i<cnt-1;i++)
      for(int j=i+1;j<cnt;j++)
         if(farDist[j]>farDist[i])
         {
            double td=farDist[i]; farDist[i]=farDist[j]; farDist[j]=td;
            ulong  tt=farTickets[i]; farTickets[i]=farTickets[j]; farTickets[j]=tt;
         }

   int toCancel=cnt/2;
   for(int i=0;i<toCancel;i++) trade.OrderDelete(farTickets[i]);
   if(toCancel>0) Print("SYNC: thinned ",toCancel," far ",(filledWasBuy?"BUY":"SELL")," stop(s) after contrarian fill, P(bull)=",DoubleToString(p,2));
}

void ManageOCO()
{
   bool hb=false,hs=false;
   for(int i=PositionsTotal()-1;i>=0;i--)
   {
      ulong t=PositionGetTicket(i);
      if(t==0||!PositionSelectByTicket(t)) continue;
      if(PositionGetString(POSITION_SYMBOL)!=_Symbol||PositionGetInteger(POSITION_MAGIC)!=magic) continue;
      if(PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_BUY) hb=true; else hs=true;
   }
   if(!hb&&!hs) return;
   for(int i=OrdersTotal()-1;i>=0;i--)
   {
      ulong t=OrderGetTicket(i);
      if(t==0||!OrderSelect(t)) continue;
      if(OrderGetString(ORDER_SYMBOL)!=_Symbol||OrderGetInteger(ORDER_MAGIC)!=magic) continue;
      ENUM_ORDER_TYPE ot=(ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
      if(hb&&(ot==ORDER_TYPE_SELL_STOP||ot==ORDER_TYPE_SELL_LIMIT)) trade.OrderDelete(t);
      else if(hs&&(ot==ORDER_TYPE_BUY_STOP||ot==ORDER_TYPE_BUY_LIMIT)) trade.OrderDelete(t);
   }
}

//+------------------------------------------------------------------+
//| INTELLIGENT EXIT SYSTEM - tiered scalp target by cluster           |
//+------------------------------------------------------------------+
void ManageScalpTarget()
{
   if(!InpUseScalpTarget||!InpCloseAtScalpTarget) return;
   for(int i=PositionsTotal()-1;i>=0;i--)
   {
      ulong t=PositionGetTicket(i);
      if(t==0||!PositionSelectByTicket(t)) continue;
      if(PositionGetString(POSITION_SYMBOL)!=_Symbol||PositionGetInteger(POSITION_MAGIC)!=magic) continue;
      double pr=PositionGetDouble(POSITION_PROFIT)+PositionGetDouble(POSITION_SWAP)+PositionGetDouble(POSITION_COMMISSION);

      double target=ad.dynScalpTarget;
      int cluster=2;
      if(InpUseTieredExits)
      {
         cluster=GetClusterFromComment(PositionGetString(POSITION_COMMENT));
         if(cluster==1) target=ad.dynScalpTarget*InpCluster1ScalpMult; // quick-exit cluster: smaller/faster lock-in
         else if(cluster==3) continue; // trailing cluster: handled by ManagePositions() instead of a fixed $ target
      }

      if(pr>=target&&trade.PositionClose(t))
      {scalpWins++;totalScalpProfit+=pr;SparklineAdd(pr);
       Print("SCALP +$",DoubleToString(pr,2)," CL",cluster," (target was $",DoubleToString(target,2),")");}
   }
}

//+------------------------------------------------------------------+
//| POSITION MANAGEMENT - tiered breakeven/trailing by cluster        |
//+------------------------------------------------------------------+
void ManagePositions()
{
   double atr=GetCurrentATR(); if(atr<=0) return;
   int digs=symbolDigits;
   double msd=SymbolInfoInteger(_Symbol,SYMBOL_TRADE_STOPS_LEVEL)*symbolPoint;
   for(int i=PositionsTotal()-1;i>=0;i--)
   {
      ulong t=PositionGetTicket(i);
      if(t==0||!PositionSelectByTicket(t)) continue;
      if(PositionGetString(POSITION_SYMBOL)!=_Symbol||PositionGetInteger(POSITION_MAGIC)!=magic) continue;
      ENUM_POSITION_TYPE pt=(ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      double op=PositionGetDouble(POSITION_PRICE_OPEN);
      double csl=PositionGetDouble(POSITION_SL),ctp=PositionGetDouble(POSITION_TP);
      double bid=SymbolInfoDouble(_Symbol,SYMBOL_BID),ask=SymbolInfoDouble(_Symbol,SYMBOL_ASK);
      double cur=(pt==POSITION_TYPE_BUY)?bid:ask;
      double pd=(pt==POSITION_TYPE_BUY)?(cur-op):(op-cur);

      int cluster = InpUseTieredExits ? GetClusterFromComment(PositionGetString(POSITION_COMMENT)) : 2;
      double trailStartMult = ad.dynTrailStartATRMult;
      double trailMult      = ad.dynTrailATRMult;
      double beMult         = ad.dynBreakevenATRMult;
      if(cluster==3 && InpUseTieredExits)
      {
         // Trailing cluster: engage sooner and follow tighter to ride the
         // impulse instead of waiting for the full ATR-scaled distance.
         trailStartMult *= InpCluster3TrailStartMult;
         trailMult      *= InpCluster3TrailTightMult;
         beMult         *= InpCluster3TrailStartMult;
      }

      double nsl=csl; bool mod=false;
      if(InpUseBreakeven&&pd>=beMult*atr)
      {
         double be=(pt==POSITION_TYPE_BUY)?op+InpBreakevenBufferPts*symbolPoint:op-InpBreakevenBufferPts*symbolPoint;
         if((pt==POSITION_TYPE_BUY&&(csl==0||csl<be))||(pt==POSITION_TYPE_SELL&&(csl==0||csl>be))){nsl=be;mod=true;}
      }
      if(InpUseTrailing&&pd>=trailStartMult*atr)
      {
         double tp2=(pt==POSITION_TYPE_BUY)?cur-trailMult*atr:cur+trailMult*atr;
         if((pt==POSITION_TYPE_BUY&&tp2>nsl)||(pt==POSITION_TYPE_SELL&&(nsl==0||tp2<nsl))){nsl=tp2;mod=true;}
      }
      if(mod)
      {
         nsl=NormalizeDouble(nsl,digs);
         if(pt==POSITION_TYPE_BUY&&(bid-nsl)<msd) continue;
         if(pt==POSITION_TYPE_SELL&&(nsl-ask)<msd) continue;
         trade.PositionModify(t,nsl,ctp);
      }
   }
}

void ManageMaxHoldTime()
{
   if(InpMaxHoldMinutes<=0) return;
   datetime now=TimeCurrent();
   for(int i=PositionsTotal()-1;i>=0;i--)
   {
      ulong t=PositionGetTicket(i);
      if(t==0||!PositionSelectByTicket(t)) continue;
      if(PositionGetString(POSITION_SYMBOL)!=_Symbol||PositionGetInteger(POSITION_MAGIC)!=magic) continue;
      double held=(now-(datetime)PositionGetInteger(POSITION_TIME))/60.0;
      if(held>=InpMaxHoldMinutes)
      {
         if(InpForceCloseAtMaxHold) trade.PositionClose(t);
         else if(PositionGetDouble(POSITION_PROFIT)<=0) trade.PositionClose(t);
      }
   }
}

double GetTotalExposure()
{
   double tot=0;
   for(int i=PositionsTotal()-1;i>=0;i--)
   {
      ulong t=PositionGetTicket(i);
      if(t>0&&PositionSelectByTicket(t)&&
         PositionGetString(POSITION_SYMBOL)==_Symbol&&PositionGetInteger(POSITION_MAGIC)==magic)
         tot+=PositionGetDouble(POSITION_VOLUME);
   }
   for(int i=OrdersTotal()-1;i>=0;i--)
   {
      ulong t=OrderGetTicket(i);
      if(t>0&&OrderSelect(t)&&
         OrderGetString(ORDER_SYMBOL)==_Symbol&&OrderGetInteger(ORDER_MAGIC)==magic)
         tot+=OrderGetDouble(ORDER_VOLUME_CURRENT);
   }
   return tot;
}

void CheckCircuitBreaker()
{
   double eq=AccountInfoDouble(ACCOUNT_EQUITY);
   peakEquity=MathMax(peakEquity,eq);
   MqlDateTime tm; TimeToStruct(TimeCurrent(),tm);
   if(tm.day!=lastDayChecked)
   {
      dayStartBalance=AccountInfoDouble(ACCOUNT_BALANCE);
      lastDayChecked=tm.day; tradingEnabled=true;
      grossProfit=grossLoss=0; totalWins=totalLosses=0;
      Print("NEW DAY $",DoubleToString(dayStartBalance,2));
   }
   dailyProfit=eq-dayStartBalance;
   if(dailyProfit>=InpDailyProfitTarget) tradingEnabled=false;
   else if(dailyProfit<=-InpDailyLossLimit)
   {
      tradingEnabled=false;
      if(InpCloseAllOnLossLimit)
      {
         for(int i=PositionsTotal()-1;i>=0;i--)
         {ulong t=PositionGetTicket(i);
          if(t>0&&PositionSelectByTicket(t)&&
             PositionGetString(POSITION_SYMBOL)==_Symbol&&
             PositionGetInteger(POSITION_MAGIC)==magic) trade.PositionClose(t);}
         DeleteAllPendingOrders();
      }
   }
   if(eq<peakEquity*(1-InpMaxDrawdownPct/100.0)) recentProfitFactor=0.6;
}

void UpdateProfitFactor()
{
   if(grossLoss>0)        recentProfitFactor=grossProfit/grossLoss;
   else if(grossProfit>0) recentProfitFactor=1.5;
   else                   recentProfitFactor=1.0;
   recentProfitFactor=MathMax(0.5,MathMin(recentProfitFactor,2.0));
}

void SparklineAdd(double v){ sparkData[sparkHead%8]=v; sparkHead++; }

//+------------------------------------------------------------------+
//| BUILD ENTIRE DASHBOARD (adds SIGNAL & QUALITY ENGINE section)     |
//+------------------------------------------------------------------+
void BuildDashboard()
{
   ObjectsDeleteAll(0,DASH_PREFIX);
   dl.objCount=0;
   FitLayout();

   int px=dl.px, pw=dl.pw;

   // Drop shadow behind the panel - a plain dark rect offset a few pixels
   // down-right, drawn first so a shadow sliver reads along the bottom/right
   // edge once the main panel is drawn on top of it.
   DRect("ROOT_SHADOW",px+4,dl.py+4,pw,dl.ph,C'0,0,0',C'0,0,0',0,false);

   DRect("ROOT",px,dl.py,pw,dl.ph,C_BG_ROOT,C_BORDER_OUTER,2);
   DRect("ROOT_TL",px+2,dl.py+2,pw-4,2,C_BORDER_ACCENT,C_BORDER_ACCENT,0);

   // Engraved-frame corner brackets (top-left / bottom-right)
   DRect("CNR_TL_H",px,dl.py,14,2,C_BORDER_ACCENT,C_BORDER_ACCENT,0,false);
   DRect("CNR_TL_V",px,dl.py,2,14,C_BORDER_ACCENT,C_BORDER_ACCENT,0,false);
   DRect("CNR_BR_H",px+pw-14,dl.py+dl.ph-2,14,2,C_BORDER_ACCENT,C_BORDER_ACCENT,0,false);
   DRect("CNR_BR_V",px+pw-2,dl.py+dl.ph-14,2,14,C_BORDER_ACCENT,C_BORDER_ACCENT,0,false);

   // [1] HEADER
   {
      int y=dl.yHeader, h=dl.headerH;
      DRect("HDR_BG",px,y,pw,h,C_BG_HEADER,C_BG_HEADER,0);
      DRect("HDR_A1",px,y,pw,2,C_BORDER_ACCENT,C_BORDER_ACCENT,0,false);
      DRect("HDR_A2",px,y+2,pw,1,C_BRAND_PURPLE,C_BRAND_PURPLE,0,false);
      // Embossed brand title: a dark 1px offset shadow copy behind the gold
      // text gives it a subtle engraved/luxury look with no real 3D needed.
      DText("HDR_PH_SH",px+dl.padX+1, y+5, "PHANTOM FLUX",
            C'0,0,0', dl.fontHdr, "Arial Black");
      DText("HDR_PH",  px+dl.padX, y+4,           "PHANTOM FLUX",
            C_BORDER_ACCENT,  dl.fontHdr,  "Arial Black");
      DText("HDR_CO",  px+dl.padX, y+4+dl.fontHdr+3, "ADAPTIVE v9.20",
            C_BRAND_PURPLE,  dl.fontMed,  "Georgia");
      DText("HDR_SUB", px+dl.padX, y+h-10,
            "Nothing Fixed", C_TEXT_DIM, dl.fontSmall,"Georgia");
      int bdW=60, bdH=MathMin(16,h/3);
      DrawBadge("HDR_ST",px+pw-bdW-dl.padX,y+5,bdW,bdH,
                tradingEnabled?"LIVE":"PAUSE",
                tradingEnabled?C_PILL_LIVE:C_PILL_PAUSED,C_PILL_TEXT,dl.fontSmall);
      string tfS=EnumToString(InpAnalysisTF); StringReplace(tfS,"PERIOD_","");
      DrawBadge("HDR_SYMTF",px+pw-bdW-dl.padX,y+bdH+8,bdW,bdH,
                _Symbol+" "+tfS,C_BG_BADGE,C_BRAND_CYAN,dl.fontSmall);
   }

   // [2] ENGINE CORE
   {
      int y=dl.yCore, h=dl.coreH;
      DRect("ENG_BG",px,y,pw,h,C_BG_SECTION,C_BORDER_SECTION,1);
      int outerR = MathMax(10, h/2-4);
      int cx = px + outerR + 14;
      int cy = y + h/2;
      DrawGlobeOrb(cx,cy,outerR);
      int tx=cx + outerR + 12;
      string modeStr=(InpMode==Aggressive)?"AGGRESSIVE":(InpMode==Stealth)?"STEALTH":"ADAPTIVE";
      color  modeClr=(InpMode==Aggressive)?C_RED_BRIGHT:(InpMode==Stealth)?C_BRAND_CYAN:C_YELLOW_BRIGHT;
      DText("ENG_ML",tx, y+3,  "MODE",    C_TEXT_DIM,   dl.fontSmall, "Arial");
      DText("ENG_MV",tx, y+3+dl.fontSmall+2, modeStr, modeClr, dl.fontNormal,"Arial Black");
      DText("ENG_AL",tx+70, y+3, "ATR",    C_TEXT_DIM,   dl.fontSmall,"Arial");
      DText("ENG_AV",tx+70, y+3+dl.fontSmall+2,"---",C_YELLOW_BRIGHT,dl.fontNormal,"Consolas");
      DText("ENG_SL",tx,    y+h-dl.fontSmall-7, "SPD",C_TEXT_DIM,    dl.fontSmall,"Arial");
      DText("ENG_SV",tx+20, y+h-dl.fontSmall-7, "---",C_TEXT_NORMAL, dl.fontSmall,"Consolas");
      DText("ENG_MAL",tx+70,y+h-dl.fontSmall-7, "MGC",C_TEXT_DIM,   dl.fontSmall,"Arial");
      DText("ENG_MAV",tx+90,y+h-dl.fontSmall-7,
            IntegerToString(magic),C_TEXT_MUTED,dl.fontSmall,"Consolas");
   }

   // [3] STAT CARDS
   {
      int y=dl.yCards, h=dl.cardH;
      int gap=2, cw=(dl.innerW-gap*2)/3;
      int x0=px+dl.padX;
      DrawCard("CB", x0,          y,cw,h,"BALANCE",
               "$"+DoubleToString(AccountInfoDouble(ACCOUNT_BALANCE),2),"Account",
               C_BRAND_BLUE,C_TEXT_BRIGHT);
      DrawCard("CE", x0+cw+gap,   y,cw,h,"EQUITY",
               "$"+DoubleToString(AccountInfoDouble(ACCOUNT_EQUITY),2),"Current",
               C_BRAND_CYAN,C_TEAL_BRIGHT);
      DrawCard("CP", x0+(cw+gap)*2,y,cw,h,"DAILY P/L",
               "$0.00","Today",
               C_GREEN_BRIGHT,C_GREEN_BRIGHT);
   }

   // [4] ADAPTIVE ENGINE
   {
      int sy=dl.yAdapt;
      DrawSecHdr("SH_AE",sy,"A","ADAPTIVE ENGINE",C_BRAND_PURPLE);
      int y=sy+dl.secHdrH, h=dl.adaptH;
      DRect("AE_BG",px,y,pw,h,C_BG_SECTION,C_BORDER_SECTION,1);
      int kvH=dl.rowH; int ky=y;
      DrawKV("AE_VR",ky,"Vol Regime","--%",C_YELLOW_BRIGHT,false,kvH); ky+=kvH;
      DrawKV("AE_MO",ky,"Momentum","0.00",C_TEXT_NORMAL,true,kvH); ky+=kvH;
      DrawKV("AE_MB",ky,"Micro Bias","0.00",C_TEXT_NORMAL,false,kvH); ky+=kvH;
      DrawKV("AE_EN",ky,"Energy","0.00",C_ORANGE_BRIGHT,true,kvH); ky+=kvH;
      DrawKV("AE_ST",ky,"Grid Step","--- ",C_TEAL_BRIGHT,false,kvH); ky+=kvH;
      if(h - (ky-y) >= kvH)
      { DrawKV("AE_GATE",ky,"Vol Gate","OFF",C_GREEN_BRIGHT,true,kvH); ky+=kvH; }
   }

   // [5] SIGNAL & QUALITY ENGINE (NEW)
   {
      int sy=dl.ySig;
      DrawSecHdr("SH_SG",sy,"S","SIGNAL & QUALITY",C_BRAND_CYAN);
      int y=sy+dl.secHdrH, h=dl.sigH;
      DRect("SG_BG",px,y,pw,h,C_BG_SECTION,C_BORDER_SECTION,1);
      int kvH=dl.rowH; int ky=y;
      DrawKV("SG_BU",ky,"Bull Prob","--%",C_GREEN_BRIGHT,false,kvH); ky+=kvH;
      DrawKV("SG_BR",ky,"Buy/Sell Risk","--% / --%",C_TEAL_BRIGHT,true,kvH); ky+=kvH;
      DrawKV("SG_EQ",ky,"Exec Quality","--",C_YELLOW_BRIGHT,false,kvH); ky+=kvH;
      DrawKV("SG_ST",ky,"Streak Mult","1.00x",C_ORANGE_BRIGHT,true,kvH); ky+=kvH;
      if(h - (ky-y) >= kvH)
      { DrawKV("SG_GD",ky,"Guard","OK",C_GREEN_BRIGHT,false,kvH); ky+=kvH; }
   }

   // [6] SCALPING SECTION
   {
      int sy=dl.yScalp;
      DrawSecHdr("SH_SC",sy,"$","SCALPING TARGET (adaptive)",C_GREEN_BRIGHT);
      int y=sy+dl.secHdrH, h=dl.scalpH;
      DRect("SC_BG",px,y,pw,h,C_BG_SECTION,C_BORDER_SECTION,1);
      int usedH=0; int kvH=dl.rowH;
      DrawKV("SC_TGT",y+usedH,"Target/Trade","$"+DoubleToString(ad.dynScalpTarget,2),C_YELLOW_BRIGHT,false,kvH); usedH+=kvH;
      DrawKV("SC_WIN",y+usedH,"Scalp Wins",IntegerToString(scalpWins),C_GREEN_BRIGHT,true,kvH); usedH+=kvH;
      DrawKV("SC_PRF",y+usedH,"Scalp Profit","$0.00",C_GREEN_BRIGHT,false,kvH); usedH+=kvH;
      int pbH=6; int pbM=3;
      if(h - usedH >= pbH+pbM+dl.fontSmall+2)
      {
         int pbY=y+usedH+pbM;
         DText("SC_PBL",px+dl.padX,pbY,"-> Daily Target Progress",C_TEXT_MUTED,dl.fontSmall,"Arial");
         DrawPBar("SC_PB",px+dl.padX,pbY+dl.fontSmall+1,dl.innerW,pbH,0.0,C_PBAR_GREEN);
      }
   }

   // [7] GRID STATUS
   {
      int sy=dl.yGrid;
      DrawSecHdr("SH_GR",sy,"#","GRID STATUS (adaptive)",C_YELLOW_BRIGHT);
      int y=sy+dl.secHdrH, h=dl.gridH;
      DRect("GR_BG",px,y,pw,h,C_BG_SECTION,C_BORDER_SECTION,1);
      int boxH=MathMin(26,h/3); int boxW=(dl.innerW-4)/2;
      int bx0=px+dl.padX, bx1=px+dl.padX+boxW+4;
      DRect("GR_BBX",bx0,y+2,boxW,boxH,C_BG_BADGE,C_GREEN_DIM,1,false);
      DRect("GR_SBX",bx1,y+2,boxW,boxH,C_BG_BADGE,C_RED_DIM,  1,false);
      DText("GR_BL",bx0+boxW/2,y+3, "BUY",  C_GREEN_BRIGHT,dl.fontSmall,"Arial",     ANCHOR_CENTER);
      DText("GR_BV",bx0+boxW/2,y+3+dl.fontSmall+1,"0",C_GREEN_BRIGHT,dl.fontMed,"Arial Black",ANCHOR_CENTER);
      DText("GR_SL",bx1+boxW/2,y+3, "SELL", C_RED_BRIGHT,  dl.fontSmall,"Arial",     ANCHOR_CENTER);
      DText("GR_SV",bx1+boxW/2,y+3+dl.fontSmall+1,"0",C_RED_BRIGHT,  dl.fontMed,"Arial Black",ANCHOR_CENTER);
      int ky=y+boxH+4; int kvH=dl.rowH;
      DrawKV("GR_BP",ky,"Buy Positions","0",C_GREEN_BRIGHT,false,kvH); ky+=kvH;
      DrawKV("GR_SP",ky,"Sell Positions","0",C_RED_BRIGHT,  true, kvH); ky+=kvH;
      DrawKV("GR_AG",ky,"Order Age","0s / ---s",C_TEXT_NORMAL,false,kvH); ky+=kvH;
      DrawKV("GR_EX",ky,"Exposure","0.00/"+DoubleToString(InpMaxTotalLots,2)+"L",C_ORANGE_BRIGHT,true,kvH);
   }

   // [8] RISK ENGINE
   {
      int sy=dl.yRisk;
      DrawSecHdr("SH_RI",sy,"R","RISK ENGINE (adaptive)",C_BRAND_BLUE);
      int y=sy+dl.secHdrH, h=dl.riskH;
      DRect("RI_BG",px,y,pw,h,C_BG_SECTION,C_BORDER_SECTION,1);
      int kvH=dl.rowH; int ky=y;
      DrawKV("RI_SL",ky,"SL"," --- ",C_RED_BRIGHT,  false, kvH); ky+=kvH;
      DrawKV("RI_TP",ky,"TP"," --- ",C_GREEN_BRIGHT, true,kvH); ky+=kvH;
      DrawKV("RI_LT",ky,"Lot"," --- ",C_BRAND_CYAN,false,kvH); ky+=kvH;
      int pbH=6;
      if(h - (ky-y) >= pbH + dl.fontSmall + 4)
      {
         DText("RI_DDL",px+dl.padX, ky+1,"Drawdown",C_TEXT_DIM,dl.fontSmall,"Arial");
         DText("RI_DDV",px+pw-dl.padX,ky+1,"0.00%",C_TEXT_NORMAL,dl.fontSmall,"Consolas",ANCHOR_RIGHT_UPPER);
         ky+=dl.fontSmall+2;
         DrawPBar("RI_DD",px+dl.padX,ky,dl.innerW,pbH,0.0,C_PBAR_GREEN);
      }
   }

   // [9] PERFORMANCE
   {
      int sy=dl.yPerf;
      DrawSecHdr("SH_PF",sy,"P","PERFORMANCE",C_BRAND_PURPLE);
      int y=sy+dl.secHdrH, h=dl.perfH;
      DRect("PF_BG",px,y,pw,h,C_BG_SECTION,C_BORDER_SECTION,1);
      int kvH=dl.rowH; int ky=y;
      DrawKV("PF_WL",ky,"W/L","0/0",         C_TEXT_BRIGHT, false,kvH); ky+=kvH;
      DrawKV("PF_WR",ky,"Win Rate","0.0%",   C_GREEN_BRIGHT,true, kvH); ky+=kvH;
      DrawKV("PF_PF",ky,"P.Factor","1.00",   C_YELLOW_BRIGHT,false,kvH); ky+=kvH;
      DrawKV("PF_GP",ky,"Gross Win","+$0.00",C_GREEN_BRIGHT,true, kvH); ky+=kvH;
      DrawKV("PF_GL",ky,"Gross Loss","-$0.00",C_RED_BRIGHT, false,kvH); ky+=kvH;
      int spH=MathMin(16,h-(ky-y)-4);
      if(spH>=6)
      {
         DText("PF_SPL",px+dl.padX,ky+1,"Sparkline",C_TEXT_MUTED,dl.fontSmall,"Arial");
         DrawSparkline("PF_SP",px+dl.padX,ky+dl.fontSmall+2,dl.innerW,spH);
      }
   }

   // [10] CIRCUIT BREAKER
   {
      int sy=dl.yCB;
      DrawSecHdr("SH_CB",sy,"!","CIRCUIT BREAKER",C_ORANGE_BRIGHT);
      int y=sy+dl.secHdrH, h=dl.cbH;
      DRect("CB_BG",px,y,pw,h,C_BG_SECTION,C_BORDER_SECTION,1);
      int kvH=dl.rowH;
      DrawKV("CB_DP",y,      "Profit Target","+$"+DoubleToString(InpDailyProfitTarget,2),C_GREEN_BRIGHT,false,kvH);
      DrawKV("CB_DL",y+kvH,  "Loss Limit","-$"+DoubleToString(InpDailyLossLimit,2),  C_RED_BRIGHT,  true, kvH);
      if(h>=kvH*3)
         DrawKV("CB_MD",y+kvH*2,"Max DD",DoubleToString(InpMaxDrawdownPct,1)+"%",C_ORANGE_BRIGHT,false,kvH);
   }

   // [11] FOOTER
   {
      int y=dl.yFooter, h=dl.footerH;
      DRect("FT_BG",  px,y,pw,h,C_BG_HEADER,C_BORDER_SECTION,1);
      DRect("FT_TOP", px,y,pw,1,C_BORDER_ACCENT,C_BORDER_ACCENT,0);
      DText("FT_BRK", px+dl.padX,y+2,
            AccountInfoString(ACCOUNT_COMPANY),C_TEXT_MUTED,dl.fontSmall,"Arial");
      DText("FT_RT",  px+dl.padX,y+h/2+1,
            "Runtime: 0h 0m",C_BRAND_CYAN,dl.fontSmall,"Consolas");
      DText("FT_CR",  px+pw-dl.padX,y+h/2+1,
            "PhantomTech",C_TEXT_MUTED,dl.fontSmall,"Arial",ANCHOR_RIGHT_UPPER);
   }

   dl.needRebuild=false;
   ChartRedraw();
}

//+------------------------------------------------------------------+
//| LIGHTWEIGHT UPDATE                                                |
//+------------------------------------------------------------------+
void UpdateDashboard()
{
   if(!InpShowDashboard) return;
   if(dl.needRebuild){ BuildDashboard(); return; }

   int px=dl.px, pw=dl.pw;

   int outerR=MathMax(10,dl.coreH/2-4);
   int cx=px+outerR+14, cy=dl.yCore+dl.coreH/2;
   UpdateGlobeOrb(cx,cy,outerR);

   BadgeUpd("HDR_ST",
            tradingEnabled?"LIVE":"PAUSE",
            tradingEnabled?C_PILL_LIVE:C_PILL_PAUSED,C_PILL_TEXT);

   double atr=GetCurrentATR();
   double atrP=(pipSize>0)?atr/pipSize:0;
   long   sprd=SymbolInfoInteger(_Symbol,SYMBOL_SPREAD);
   DSetText("ENG_AV",DoubleToString(atrP,1));
   DSetText("ENG_SV",IntegerToString((int)sprd)+"pt");
   DSetColor("ENG_SV",sprd>InpMaxSpreadPts?C_RED_BRIGHT:C_GREEN_BRIGHT);

   double bal=AccountInfoDouble(ACCOUNT_BALANCE);
   double equ=AccountInfoDouble(ACCOUNT_EQUITY);
   CardUpd("CB","$"+DoubleToString(bal,2),"Account",C_TEXT_BRIGHT);
   CardUpd("CE","$"+DoubleToString(equ,2),"Current",C_TEAL_BRIGHT);
   color dpClr=dailyProfit>=0?C_GREEN_BRIGHT:C_RED_BRIGHT;
   string dpTxt=(dailyProfit>=0?"+$":"-$")+DoubleToString(MathAbs(dailyProfit),2);
   CardUpd("CP",dpTxt,"Today",dpClr,dpClr);

   // Adaptive Engine readouts
   color vrClr = ad.volRegime>0.8?C_RED_BRIGHT:ad.volRegime>0.5?C_ORANGE_BRIGHT:C_GREEN_BRIGHT;
   KVVal("AE_VR",DoubleToString(ad.volRegime*100,0)+"%",vrClr);
   color moClr = ad.momentumScore>0?C_GREEN_BRIGHT:C_RED_BRIGHT;
   KVVal("AE_MO",DoubleToString(ad.momentumScore,2),moClr);
   color mbClr = ad.microBias>0?C_GREEN_BRIGHT:C_RED_BRIGHT;
   KVVal("AE_MB",DoubleToString(ad.microBias,2),mbClr);
   color enClr = ad.combinedEnergy>0.7?C_RED_BRIGHT:ad.combinedEnergy>0.4?C_ORANGE_BRIGHT:C_TEAL_BRIGHT;
   KVVal("AE_EN",DoubleToString(ad.combinedEnergy,2),enClr);
   KVVal("AE_ST",DoubleToString(ad.dynGridStepATR,3)+" xATR",C_TEAL_BRIGHT);
   KVVal("AE_GATE",ad.extremeVolGateActive?"ACTIVE - PAUSED":"off",
         ad.extremeVolGateActive?C_RED_BRIGHT:C_GREEN_BRIGHT);

   // Signal & Quality readouts (NEW)
   KVVal("SG_BU",DoubleToString(ad.bullishProbability*100,0)+"%",
         ad.bullishProbability>=0.5?C_GREEN_BRIGHT:C_RED_BRIGHT);
   KVVal("SG_BR",DoubleToString(ad.buyRiskAlloc*100,0)+"% / "+DoubleToString(ad.sellRiskAlloc*100,0)+"%",C_TEAL_BRIGHT);
   color eqClr = exq.qualityScore>=InpQualityDampThreshold ? C_GREEN_BRIGHT : C_RED_BRIGHT;
   KVVal("SG_EQ",DoubleToString(exq.qualityScore,2)+" ("+DoubleToString(exq.avgSlippagePts,1)+"p slip)",eqClr);
   KVVal("SG_ST",DoubleToString(streak.aggressionMult,2)+"x",
         streak.aggressionMult>=1.0?C_GREEN_BRIGHT:C_RED_BRIGHT);

   string guardTxt="OK"; color guardClr=C_GREEN_BRIGHT;
   if(InpUseLossCooldown && lossCooldownUntil>0 && TimeCurrent()<lossCooldownUntil)
   { guardTxt="COOLDOWN "+IntegerToString((int)((lossCooldownUntil-TimeCurrent())/60))+"m"; guardClr=C_RED_BRIGHT; }
   else if(SymbolInfoInteger(_Symbol,SYMBOL_SPREAD)>InpMaxSpreadPts)
   { guardTxt="SPREAD WIDE"; guardClr=C_RED_BRIGHT; }
   else if(InpUseTradeThrottle && CountRecentFills(InpTradeWindowMinutes)>=InpMaxTradesPerWindow)
   { guardTxt="THROTTLED"; guardClr=C_ORANGE_BRIGHT; }
   else if(ad.chopDetected)
   { guardTxt="CHOP - LIGHT"; guardClr=C_YELLOW_BRIGHT; }
   KVVal("SG_GD",guardTxt,guardClr);

   KVVal("SC_TGT","$"+DoubleToString(ad.dynScalpTarget,2)+(InpUseHardTP?" (HARD)":""),C_YELLOW_BRIGHT);
   KVVal("SC_WIN",IntegerToString(scalpWins),C_GREEN_BRIGHT);
   color spClr=totalScalpProfit>=0?C_GREEN_BRIGHT:C_RED_BRIGHT;
   KVVal("SC_PRF",(totalScalpProfit>=0?"+$":"-$")+DoubleToString(MathAbs(totalScalpProfit),2),spClr);
   double scPct=(InpDailyProfitTarget>0)?MathMin(100,totalScalpProfit/InpDailyProfitTarget*100):0;
   PBarUpd("SC_PB",px+dl.padX,dl.innerW,scPct,scPct<50?C_PBAR_YELLOW:C_PBAR_GREEN);

   int bo=0,so=0,bp=0,sp=0;
   datetime oldT=TimeCurrent(); bool hasO=false;
   for(int i=0;i<OrdersTotal();i++)
   {
      ulong t=OrderGetTicket(i);
      if(t>0&&OrderSelect(t)&&
         OrderGetString(ORDER_SYMBOL)==_Symbol&&OrderGetInteger(ORDER_MAGIC)==magic)
      {
         ENUM_ORDER_TYPE ot=(ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
         if(ot==ORDER_TYPE_BUY_STOP)  bo++;
         if(ot==ORDER_TYPE_SELL_STOP) so++;
         datetime ot2=(datetime)OrderGetInteger(ORDER_TIME_SETUP);
         if(!hasO||ot2<oldT){oldT=ot2;hasO=true;}
      }
   }
   for(int i=0;i<PositionsTotal();i++)
   {
      ulong t=PositionGetTicket(i);
      if(t>0&&PositionSelectByTicket(t)&&
         PositionGetString(POSITION_SYMBOL)==_Symbol&&PositionGetInteger(POSITION_MAGIC)==magic)
      {
         if(PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_BUY) bp++;
         else sp++;
      }
   }
   int age=hasO?(int)(TimeCurrent()-oldT):0;
   color ageClr=age>ad.dynLifetimeSec*0.8?C_ORANGE_BRIGHT:C_TEXT_NORMAL;
   DSetText("GR_BV",IntegerToString(bo));
   DSetText("GR_SV",IntegerToString(so));
   KVVal("GR_BP",IntegerToString(bp),C_GREEN_BRIGHT);
   KVVal("GR_SP",IntegerToString(sp),C_RED_BRIGHT);
   KVVal("GR_AG",IntegerToString(age)+"s / "+IntegerToString(ad.dynLifetimeSec)+"s",ageClr);
   double expo=GetTotalExposure();
   color exClr=expo>InpMaxTotalLots*0.75?C_RED_BRIGHT:C_ORANGE_BRIGHT;
   KVVal("GR_EX",DoubleToString(expo,2)+"/"+DoubleToString(InpMaxTotalLots,2)+"L",exClr);

   if(atr>0)
   {
      KVVal("RI_SL",DoubleToString(ad.dynSLATRMult,2)+"xATR ("+DoubleToString(ad.dynSLATRMult*atr/pipSize,1)+"p)",C_RED_BRIGHT);
      KVVal("RI_TP",DoubleToString(ad.dynTPATRMult,2)+"xATR ("+DoubleToString(ad.dynTPATRMult*atr/pipSize,1)+"p)",C_GREEN_BRIGHT);
   }
   double sldPreview = MathMax(atr*ad.dynSLATRMult, 1.0);
   KVVal("RI_LT",DoubleToString(CalculateLotSize(sldPreview,1.0),2)+" lot",C_BRAND_CYAN);

   double ddP=(peakEquity>0)?(peakEquity-AccountInfoDouble(ACCOUNT_EQUITY))/peakEquity*100.0:0;
   color ddC=ddP>InpMaxDrawdownPct*0.7?C_RED_BRIGHT:ddP>InpMaxDrawdownPct*0.4?C_ORANGE_BRIGHT:C_GREEN_BRIGHT;
   DSetText("RI_DDV",DoubleToString(ddP,2)+"%"); DSetColor("RI_DDV",ddC);
   PBarUpd("RI_DD",px+dl.padX,dl.innerW,MathMin(100,ddP/InpMaxDrawdownPct*100),ddC);

   int wl=totalWins+totalLosses;
   double wr=wl>0?totalWins*100.0/wl:0;
   color wrC=wr>=55?C_GREEN_BRIGHT:wr>=45?C_YELLOW_BRIGHT:C_RED_BRIGHT;
   color pfC=recentProfitFactor>=1.5?C_GREEN_BRIGHT:recentProfitFactor>=1.0?C_YELLOW_BRIGHT:C_RED_BRIGHT;
   KVVal("PF_WL",IntegerToString(totalWins)+"/"+IntegerToString(totalLosses),C_TEXT_BRIGHT);
   KVVal("PF_WR",DoubleToString(wr,1)+"%",wrC);
   KVVal("PF_PF",DoubleToString(recentProfitFactor,2),pfC);
   KVVal("PF_GP","+$"+DoubleToString(grossProfit,2),C_GREEN_BRIGHT);
   KVVal("PF_GL","-$"+DoubleToString(grossLoss,2),C_RED_BRIGHT);

   int spH=MathMin(16,dl.perfH-(dl.rowH*5)-dl.fontSmall-6);
   if(spH>=6)
   {
      int spY=dl.yPerf+dl.secHdrH+(dl.rowH*5)+dl.fontSmall+2;
      UpdateSparkline("PF_SP",px+dl.padX,spY,dl.innerW,spH);
   }

   int rm=(int)((TimeCurrent()-eaStartTime)/60);
   DSetText("FT_RT","Runtime: "+IntegerToString(rm/60)+"h "+IntegerToString(rm%60)+"m");

   ChartRedraw();
}

//+------------------------------------------------------------------+
//| EVENT HANDLERS                                                    |
//+------------------------------------------------------------------+
int OnInit()
{
   if(InpRiskPercent>10.0){Print("Risk>10%");return INIT_PARAMETERS_INCORRECT;}
   if(InpAdaptOrdersMin<1||InpAdaptOrdersMax>50||InpAdaptOrdersMin>InpAdaptOrdersMax)
   {Print("Adaptive order bounds invalid");return INIT_PARAMETERS_INCORRECT;}
   if(InpTickBufferSize<8){Print("Tick buffer too small, minimum 8");return INIT_PARAMETERS_INCORRECT;}

   symbolDigits=(int)SymbolInfoInteger(_Symbol,SYMBOL_DIGITS);
   symbolPoint =SymbolInfoDouble(_Symbol,SYMBOL_POINT);
   isJPYPair   =StringFind(_Symbol,"JPY")>=0;
   pipSize     =(isJPYPair||symbolDigits==3||symbolDigits==2)?0.01:0.0001;

   trade.SetExpertMagicNumber(magic);
   trade.SetDeviationInPoints(InpTradeDeviationPts);
   trade.SetTypeFillingBySymbol(_Symbol);

   handleATR=iATR(_Symbol,InpAnalysisTF,InpATRPeriod);
   handleATRSlow=iATR(_Symbol,InpAnalysisTF,InpATRSlowPeriod);
   if(handleATR==INVALID_HANDLE||handleATRSlow==INVALID_HANDLE){Print("ATR init failed");return INIT_FAILED;}

   ArrayResize(volHistory, InpVolWindowBars);
   ArrayInitialize(volHistory, 0.0);
   volHistCount=0; volHistHead=0;

   ArrayResize(spreadHistory, InpSpreadAvgWindow);
   ArrayInitialize(spreadHistory, 0.0);
   spreadHistCount=0; spreadHistHead=0;

   ArrayResize(tbPrice, InpTickBufferSize);
   ArrayResize(tbTimeMsc, InpTickBufferSize);
   ArrayResize(tbBid, InpTickBufferSize);
   ArrayResize(tbAsk, InpTickBufferSize);
   ArrayInitialize(tbPrice,0.0); ArrayInitialize(tbBid,0.0); ArrayInitialize(tbAsk,0.0);
   for(int i=0;i<InpTickBufferSize;i++) tbTimeMsc[i]=0;
   tbHead=0; tbCount=0;

   ZeroMemory(ad);
   ad.dynBuyOrders  = InpOrdersPerSideBase;
   ad.dynSellOrders = InpOrdersPerSideBase;
   ad.dynLifetimeSec = InpAdaptLifetimeMaxSec;
   ad.dynScalpTarget = InpUseHardTP ? InpHardTPValue : InpScalpProfitTargetBase;
   ad.bullishProbability = 0.5; ad.bearishProbability = 0.5;
   ad.buyRiskAlloc = 0.5; ad.sellRiskAlloc = 0.5;
   ad.ready = false;

   ZeroMemory(micro);
   micro.sessionLiquidity = 1.0;
   micro.spreadExpansion  = 1.0;
   micro.compressionRatio = 1.0;

   ZeroMemory(exq);
   exq.qualityScore = 1.0; // assume clean until proven otherwise

   ZeroMemory(streak);
   streak.aggressionMult = 1.0;
   lossCooldownUntil = 0;
   fillTimesHead = 0; fillTimesCount = 0;

   lastDeployedGridStepATR = 0.0;
   rebalanceTickCounter = 0;

   EventSetMillisecondTimer(InpTimerMs);
   peakEquity=AccountInfoDouble(ACCOUNT_EQUITY);
   dayStartBalance=AccountInfoDouble(ACCOUNT_BALANCE);
   MqlDateTime tm; TimeToStruct(TimeCurrent(),tm);
   lastDayChecked=tm.day;
   eaStartTime=TimeCurrent();

   ArrayInitialize(sparkData,0.0);
   dl.spinAngle=0; dl.pulsePhase=0;
   dl.objCount=0;  dl.needRebuild=true;

   if(InpShowDashboard) BuildDashboard();

   Print("=========================================");
   Print("PHANTOM FLUX ADAPTIVE CORE v9.20 | ",_Symbol);
   Print("Order pool: ",InpOrdersPerSideBase*2," total, split by live probability | bounds [",InpAdaptOrdersMin,"-",InpAdaptOrdersMax,"] per side");
   Print("Building volatility history (",InpVolWindowBars," bars) before first deploy...");
   Print("=========================================");
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
   EventKillTimer();
   IndicatorRelease(handleATR);
   IndicatorRelease(handleATRSlow);
   if(InpShowDashboard) ObjectsDeleteAll(0,DASH_PREFIX);
   Print("SHUTDOWN | ",totalWins,"W/",totalLosses,"L | $",DoubleToString(totalScalpProfit,2),
         " | avg slip ",DoubleToString(exq.avgSlippagePts,2),"p | quality ",DoubleToString(exq.qualityScore,2));
}

void OnTimer()
{
   UpdateAdaptiveState();
   ManageOCO();
   ManageScalpTarget();
   ManagePositions();
   ManageMaxHoldTime();
   CheckCircuitBreaker();
   if(tradingEnabled) DeployOrRebalanceGrid();
   if(InpShowDashboard) UpdateDashboard();
}

void OnTick()
{
   MqlTick tick;
   if(SymbolInfoTick(_Symbol,tick)) PushTick(tick);
   UpdateMicrostructureFast();

   rebalanceTickCounter++;
   if(rebalanceTickCounter>=InpRebalanceEveryTicks)
   {
      rebalanceTickCounter=0;
      if(tradingEnabled) DeployOrRebalanceGrid();
   }

   if(!InpUseTickDrivenMgmt) return;
   datetime now=TimeCurrent();
   if(now==lastTickManagement) return;
   lastTickManagement=now;
   ManageOCO(); ManageScalpTarget(); ManagePositions();
}

void OnTradeTransaction(const MqlTradeTransaction &trans,
                        const MqlTradeRequest     &request,
                        const MqlTradeResult      &result)
{
   if(trans.type!=TRADE_TRANSACTION_DEAL_ADD) return;
   ulong dk=trans.deal;
   if(!HistoryDealSelect(dk)) return;
   if(HistoryDealGetInteger(dk,DEAL_MAGIC)!=magic) return;
   if(HistoryDealGetString(dk,DEAL_SYMBOL)!=_Symbol) return;
   long entry=HistoryDealGetInteger(dk,DEAL_ENTRY);
   if(entry==DEAL_ENTRY_IN)
   {
      Print("FILLED");
      ENUM_DEAL_TYPE dt=(ENUM_DEAL_TYPE)HistoryDealGetInteger(dk,DEAL_TYPE);
      bool wasBuy=(dt==DEAL_TYPE_BUY);
      PushFillTime(TimeCurrent());
      UpdateExecutionQualityFromDeal(dk, trans.order);
      ManageOCO();
      SynchronizeOrdersAfterFill(wasBuy);
   }
   else if(entry==DEAL_ENTRY_OUT||entry==DEAL_ENTRY_OUT_BY)
   {
      double dp=HistoryDealGetDouble(dk,DEAL_PROFIT)
               +HistoryDealGetDouble(dk,DEAL_SWAP)
               +HistoryDealGetDouble(dk,DEAL_COMMISSION);
      bool isWin=(dp>0);
      if(isWin){totalWins++; grossProfit+=dp;         Print("WIN +$", DoubleToString(dp,2));}
      else     {totalLosses++;grossLoss +=MathAbs(dp); Print("LOSS -$",DoubleToString(MathAbs(dp),2));}
      SparklineAdd(dp);
      UpdateProfitFactor();
      if(InpUseStreakAggression) UpdateStreakAggression(isWin);
   }
}

void OnChartEvent(const int id,const long &lp,const double &dp,const string &sp)
{
   if(id==CHARTEVENT_CHART_CHANGE&&InpShowDashboard)
   {
      ObjectsDeleteAll(0,DASH_PREFIX);
      dl.objCount=0; dl.needRebuild=true;
   }
}
//+------------------------------------------------------------------+
