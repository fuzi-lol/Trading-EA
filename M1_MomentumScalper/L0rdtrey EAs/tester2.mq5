//+------------------------------------------------------------------+
//|                                    AETHER_X_GOLD_V2.mq5         |
//|   Execution-first, tick-driven adaptive micro-grid EA            |
//|   Built for XAUUSD M1 microstructure scalping                   |
//+------------------------------------------------------------------+
#property copyright "AetherX"
#property version   "2.00"
#property strict

#include <Trade\Trade.mqh>

CTrade trade;

//====================================================================
// INPUTS
//====================================================================
input group "=== TICK ENGINE ==="
input int    InpTickBufferSize        = 64;

input group "=== MOMENTUM ==="
input int    InpMomWindowShort        = 3;
input int    InpMomWindowMed          = 10;
input int    InpMomWindowLong         = 20;
input double InpFlatThresholdPips     = 0.4;

input group "=== HARD SAFETY FILTERS ==="
input int    InpMaxSpreadPoints       = 350;
input bool   InpSpreadATRRelative     = true;
input double InpMaxSpreadATRFraction  = 0.35;
input double InpMinFreeMarginBuffer   = 1.5;
input double InpDailyProfitTarget     = 40.0;
input double InpDailyLossLimit        = 25.0;
input double InpMaxDrawdownPct        = 10.0;
input int    InpMaxOpenPositions      = 4;
input int    InpMaxPendingOrders      = 4;
input double InpMaxTotalLots          = 2.0;
input int    InpErrorLockoutSeconds   = 10;
input int    InpMaxConsecutiveErrors  = 3;

input group "=== GRID GEOMETRY ==="
input double InpChaseDistancePips     = 1.5;   // Distance ahead of price for chase orders
input double InpShadowDistancePips    = 3.0;   // Distance behind for shadow (opposite) pending
input double InpDistanceATRMult       = 0.12;
input double InpMicroVolMult          = 0.8;
input double InpSpreadBufferMult      = 0.6;
input double InpSLATRMult             = 0.9;
input double InpTPATRMult             = 1.4;
input double InpMinRepriceDistPips    = 0.5;   // Tighter for faster chasing
input int    InpMinModifyIntervalMs   = 200;   // Faster modify for chase logic
input int    InpMaxModsPerSecond      = 5;
input int    InpMaxModsPerMinute      = 60;
input int    InpMaxPendingAgeSeconds  = 3;     // Shorter age for faster reaction

input group "=== CONTEXT (SLOW PATH) ==="
input int    InpATRPeriod             = 14;
input ENUM_TIMEFRAMES InpContextTF    = PERIOD_M1;
input int    InpEMAFast               = 5;
input int    InpEMAMed                = 13;
input int    InpEMASlow               = 34;
input int    InpRSIPeriod             = 14;
input double InpRSIOverbought         = 75.0;
input double InpRSIOversold           = 25.0;
input int    InpRegressionBars        = 20;

input group "=== K-MEANS DEAD MARKET FILTER ==="
input int    InpKMeansWindow          = 40;    // Tick window for clustering
input int    InpKMeansIterations      = 8;     // Clustering iterations
input double InpDeadMarketThreshold   = 0.25;  // Max cluster spread (pips) to flag dead
input int    InpDeadMarketConfirm     = 5;     // Consecutive dead ticks before blocking
input double InpMinVelocityPips       = 0.3;   // Minimum velocity (pips/sec) to trade
input double InpMinTickRangePips      = 0.2;   // Minimum tick range to trade

input group "=== RISK ENGINE ==="
input bool   InpUseRiskPercent        = true;
input double InpRiskPercent           = 0.4;
input double InpFixedLot              = 0.01;
input double InpMaxAcceptableRiskPct  = 1.2;

input group "=== POSITION MANAGEMENT ==="
input bool   InpUseBreakeven          = true;
input double InpBreakevenATR          = 0.55;
input double InpBreakevenBufferPts    = 8;
input bool   InpUseTrailing           = true;
input double InpTrailStartATR         = 1.0;
input double InpTrailATR              = 0.35;

input group "=== SESSION (SOFT ONLY) ==="
input bool   InpTradeAllSessions      = true;
input int    InpLondonStartHour       = 7;
input int    InpLondonEndHour         = 16;
input int    InpNewYorkStartHour      = 12;
input int    InpNewYorkEndHour        = 21;

input group "=== DASHBOARD ==="
input bool   InpShowDashboard         = true;
input int    InpDashboardHz           = 7;
input int    InpDashboardX            = 15;
input int    InpDashboardY            = 15;

input group "=== TIMER ==="
input int    InpTimerMs               = 100;

//====================================================================
// CONSTANTS
//====================================================================
#define AX_PREFIX "AX_"
#define KMEANS_K  3        // Number of clusters for dead market detection
int magic = 774411;

//====================================================================
// TICK RING BUFFER
//====================================================================
struct TickPoint { double bid; double ask; double mid; ulong ms; };
TickPoint g_ticks[128];
int g_tickCap   = 64;
int g_tickCount = 0;
int g_tickHead  = 0;

void TickBufPush(double bid, double ask) {
   g_tickHead = (g_tickHead + 1) % g_tickCap;
   g_ticks[g_tickHead].bid = bid;
   g_ticks[g_tickHead].ask = ask;
   g_ticks[g_tickHead].mid = (bid + ask) / 2.0;
   g_ticks[g_tickHead].ms  = GetTickCount64();
   if(g_tickCount < g_tickCap) g_tickCount++;
}

bool TickBufGet(int i, TickPoint &out) {
   if(i >= g_tickCount) return false;
   int idx = g_tickHead - i;
   if(idx < 0) idx += g_tickCap;
   out = g_ticks[idx];
   return true;
}

//====================================================================
// K-MEANS CLUSTERING — Dead Market Detection
// We cluster the last N mid-prices into K=3 clusters.
// If all cluster centroids are within a tight band (< threshold),
// the market is "dead" (no meaningful structure separation).
// This is purely geometric — no prediction, just structure test.
//====================================================================
struct KMeansResult {
   double centroids[KMEANS_K];   // Cluster centers
   double spread;                 // Max centroid spread in pips
   int    counts[KMEANS_K];      // Points per cluster
   bool   isDead;                 // True = dead / ranging market
};
KMeansResult g_kmeans;
int          g_deadConfirmCount = 0;  // Consecutive dead readings
bool         g_isDeadMarket     = false;

// Lightweight online K-Means on the tick mid-price buffer
void RunKMeans() {
   int n = MathMin(g_tickCount, InpKMeansWindow);
   if(n < KMEANS_K * 2) { g_kmeans.isDead = false; return; }

   // Collect mid prices (newest first → reverse for clustering)
   double pts[]; ArrayResize(pts, n);
   for(int i = 0; i < n; i++) {
      TickPoint tp;
      if(!TickBufGet(i, tp)) { n = i; break; }
      pts[i] = tp.mid;
   }
   if(n < KMEANS_K) { g_kmeans.isDead = false; return; }

   // --- Initialise centroids via K-Means++ style spread ---
   // Pick min, max, and midpoint of the range for initial seeds
   double pMin = pts[0], pMax = pts[0];
   for(int i = 1; i < n; i++) {
      if(pts[i] < pMin) pMin = pts[i];
      if(pts[i] > pMax) pMax = pts[i];
   }
   double range = pMax - pMin;

   // Seed 3 centroids evenly across observed range
   g_kmeans.centroids[0] = pMin;
   g_kmeans.centroids[1] = pMin + range * 0.5;
   g_kmeans.centroids[2] = pMax;

   // --- Iterate ---
   int   labels[]; ArrayResize(labels, n); ArrayInitialize(labels, 0);
   double newCent[KMEANS_K]; int cntArr[KMEANS_K];

   for(int iter = 0; iter < InpKMeansIterations; iter++) {
      // Assignment step
      for(int i = 0; i < n; i++) {
         double best = 1e18; int bestK = 0;
         for(int k = 0; k < KMEANS_K; k++) {
            double d = MathAbs(pts[i] - g_kmeans.centroids[k]);
            if(d < best) { best = d; bestK = k; }
         }
         labels[i] = bestK;
      }
      // Update step
      ArrayInitialize(newCent, 0.0); ArrayInitialize(cntArr, 0);
      for(int i = 0; i < n; i++) {
         newCent[labels[i]] += pts[i];
         cntArr[labels[i]]++;
      }
      bool converged = true;
      for(int k = 0; k < KMEANS_K; k++) {
         double upd = (cntArr[k] > 0) ? newCent[k] / cntArr[k] : g_kmeans.centroids[k];
         if(MathAbs(upd - g_kmeans.centroids[k]) > symbolPoint * 0.5) converged = false;
         g_kmeans.centroids[k] = upd;
         g_kmeans.counts[k]    = cntArr[k];
      }
      if(converged) break;
   }

   // Evaluate: sort centroids and compute spread
   // Simple bubble sort on 3 elements
   for(int a = 0; a < KMEANS_K - 1; a++)
      for(int b = a + 1; b < KMEANS_K; b++)
         if(g_kmeans.centroids[a] > g_kmeans.centroids[b]) {
            double tmp = g_kmeans.centroids[a];
            g_kmeans.centroids[a] = g_kmeans.centroids[b];
            g_kmeans.centroids[b] = tmp;
         }

   // Spread = distance between outermost centroids (pips)
   g_kmeans.spread = (g_kmeans.centroids[KMEANS_K-1] - g_kmeans.centroids[0]) / pipSize;

   // Dead market: all centroids collapsed into tight band
   // AND we also check velocity and raw tick range as confirmatory filters
   TickPoint latest, oldest;
   TickBufGet(0, latest); TickBufGet(n - 1, oldest);
   double tickRangePips = (pMax - pMin) / pipSize;

   bool clusterDead   = (g_kmeans.spread < InpDeadMarketThreshold);
   bool velocityDead  = (MathAbs(Mom.velocity) < InpMinVelocityPips);
   bool rangeDead     = (tickRangePips < InpMinTickRangePips);

   // Require cluster AND (velocity OR range) confirmation
   g_kmeans.isDead = clusterDead && (velocityDead || rangeDead);

   // Hysteresis: require N consecutive dead readings
   if(g_kmeans.isDead) {
      g_deadConfirmCount++;
      if(g_deadConfirmCount >= InpDeadMarketConfirm) g_isDeadMarket = true;
   } else {
      g_deadConfirmCount = MathMax(0, g_deadConfirmCount - 2); // Decay faster on activity
      if(g_deadConfirmCount == 0) g_isDeadMarket = false;
   }
}

//====================================================================
// CHASE ENGINE STATE
// Core logic: price moves up → deploy buy stop AHEAD of price.
//             Simultaneously deploy a sell stop BEHIND price (shadow).
// On fill of buy: shadow sell becomes the "running" shadow order.
// When price turns → shadow sell fills, immediately deploy new buy shadow.
// This creates a continuous leapfrog: one side chases, one side shadows.
//====================================================================
enum ChaseDir { CHASE_NONE, CHASE_UP, CHASE_DOWN };
enum SlotRole { ROLE_NONE, ROLE_CHASE, ROLE_SHADOW };

struct OrderSlot {
   ulong    ticket;
   double   price;
   SlotRole role;
   datetime placedTime;
   ulong    lastModifyMs;
   int      modsThisSecond;
   datetime modSecondWindow;
   int      modsThisMinute;
   datetime modMinuteWindow;
};

OrderSlot BuySlot;    // Buy stop (chase when going up / shadow when going down)
OrderSlot SellSlot;   // Sell stop (chase when going down / shadow when going up)
ChaseDir  g_chaseDir = CHASE_NONE;

//====================================================================
// STATE STRUCTS (unchanged from V1)
//====================================================================
enum MomState { MOM_UP, MOM_DOWN, MOM_FLAT };
enum MomSpeed { SPD_ACCEL, SPD_STABLE, SPD_DECEL };
enum ExecState {
   ES_WAITING, ES_ANALYZING, ES_CHASING_UP, ES_CHASING_DOWN,
   ES_POSITION_BUY, ES_POSITION_SELL, ES_POSITION_HEDGED,
   ES_DEAD_MARKET, ES_PROFIT_STOPPED, ES_RISK_STOPPED,
   ES_MANUAL_STOPPED, ES_ERROR_LOCKOUT
};

struct MomentumState {
   MomState state;
   MomSpeed speed;
   double   dispShort, dispMed, dispLong;
   double   velocity;
   double   accelRatio;
   int      consecutiveDir;
   double   avgTickDelta;
   double   directionalRatio;
};
MomentumState Mom;

struct SlowContext {
   double   atr;
   double   emaFast, emaMed, emaSlow;
   double   emaSlopeFast;
   double   rsi;
   double   regressionSlope;
   int      volRegime;
   datetime lastRefresh;
};
SlowContext Ctx;

struct CurrentCandle {
   datetime startTime;
   double   open, high, low, close;
};
CurrentCandle Candle;

struct RiskState {
   double   dayStartBalance;
   double   dailyPL;
   double   peakEquity;
   int      lastDay;
   bool     tradingEnabled;
   string   stopReason;
   int      consecutiveErrors;
   datetime errorLockoutUntil;
};
RiskState Risk;

ExecState g_state      = ES_WAITING;
string    g_stateReason = "";

//====================================================================
// SYMBOL CACHE
//====================================================================
int    symbolDigits = 0;
double symbolPoint  = 0.0, pipSize = 0.0;
int atrHandle = INVALID_HANDLE, emaFastHandle = INVALID_HANDLE,
    emaMedHandle = INVALID_HANDLE, emaSlowHandle = INVALID_HANDLE,
    rsiHandle = INVALID_HANDLE;

//====================================================================
// DASHBOARD THROTTLE
//====================================================================
ulong g_lastDashboardMs = 0;

//+------------------------------------------------------------------+
//| INIT                                                              |
//+------------------------------------------------------------------+
int OnInit() {
   if(InpTickBufferSize < 32 || InpTickBufferSize > 128) return INIT_PARAMETERS_INCORRECT;
   if(InpDistanceATRMult <= 0 || InpSLATRMult <= 0 || InpTPATRMult <= 0) return INIT_PARAMETERS_INCORRECT;
   if(InpATRPeriod <= 0 || InpTimerMs <= 0 || InpFixedLot <= 0) return INIT_PARAMETERS_INCORRECT;
   if(InpUseRiskPercent && InpRiskPercent <= 0) return INIT_PARAMETERS_INCORRECT;
   if(InpChaseDistancePips <= 0 || InpShadowDistancePips <= 0) return INIT_PARAMETERS_INCORRECT;

   g_tickCap   = InpTickBufferSize;
   g_tickCount = 0;
   g_tickHead  = 0;

   symbolDigits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   symbolPoint  = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   pipSize = (symbolDigits == 3 || symbolDigits == 2) ? 0.01 : 0.0001;
   if(StringFind(_Symbol, "XAU") >= 0) pipSize = 0.1;

   trade.SetExpertMagicNumber(magic);
   trade.SetTypeFillingBySymbol(_Symbol);

   atrHandle     = iATR(_Symbol, InpContextTF, InpATRPeriod);
   emaFastHandle = iMA(_Symbol, InpContextTF, InpEMAFast, 0, MODE_EMA, PRICE_CLOSE);
   emaMedHandle  = iMA(_Symbol, InpContextTF, InpEMAMed,  0, MODE_EMA, PRICE_CLOSE);
   emaSlowHandle = iMA(_Symbol, InpContextTF, InpEMASlow, 0, MODE_EMA, PRICE_CLOSE);
   rsiHandle     = iRSI(_Symbol, InpContextTF, InpRSIPeriod, PRICE_CLOSE);

   if(atrHandle == INVALID_HANDLE || emaFastHandle == INVALID_HANDLE ||
      emaMedHandle == INVALID_HANDLE || emaSlowHandle == INVALID_HANDLE ||
      rsiHandle == INVALID_HANDLE) return INIT_FAILED;

   ZeroMemory(Mom); ZeroMemory(Ctx); ZeroMemory(Candle); ZeroMemory(Risk);
   ZeroMemory(BuySlot); ZeroMemory(SellSlot); ZeroMemory(g_kmeans);

   Risk.dayStartBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   Risk.peakEquity      = AccountInfoDouble(ACCOUNT_EQUITY);
   Risk.tradingEnabled  = true;
   MqlDateTime tm; TimeToStruct(TimeCurrent(), tm);
   Risk.lastDay = tm.day;
   g_chaseDir   = CHASE_NONE;

   RefreshSlowContext(true);
   EventSetMillisecondTimer(InpTimerMs);

   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason) {
   EventKillTimer();
   IndicatorRelease(atrHandle);
   IndicatorRelease(emaFastHandle);
   IndicatorRelease(emaMedHandle);
   IndicatorRelease(emaSlowHandle);
   IndicatorRelease(rsiHandle);
   if(InpShowDashboard) ObjectsDeleteAll(0, AX_PREFIX);
}

//+------------------------------------------------------------------+
//| SLOW PATH                                                          |
//+------------------------------------------------------------------+
void RefreshSlowContext(bool force) {
   double atrBuf[]; ArraySetAsSeries(atrBuf, true);
   if(CopyBuffer(atrHandle, 0, 0, 1, atrBuf) > 0) Ctx.atr = atrBuf[0];

   double emaBuf[]; ArraySetAsSeries(emaBuf, true);
   double prevFast = Ctx.emaFast;
   if(CopyBuffer(emaFastHandle, 0, 0, 2, emaBuf) > 0) {
      Ctx.emaFast = emaBuf[0];
      if(prevFast > 0) Ctx.emaSlopeFast = emaBuf[0] - emaBuf[1];
   }
   if(CopyBuffer(emaMedHandle,  0, 0, 1, emaBuf) > 0) Ctx.emaMed  = emaBuf[0];
   if(CopyBuffer(emaSlowHandle, 0, 0, 1, emaBuf) > 0) Ctx.emaSlow = emaBuf[0];

   double rsiBuf[]; ArraySetAsSeries(rsiBuf, true);
   if(CopyBuffer(rsiHandle, 0, 0, 1, rsiBuf) > 0) Ctx.rsi = rsiBuf[0];

   double closes[]; ArraySetAsSeries(closes, true);
   int got = CopyClose(_Symbol, InpContextTF, 0, InpRegressionBars, closes);
   if(got >= InpRegressionBars) {
      double sumX=0, sumY=0, sumXY=0, sumXX=0; int n = InpRegressionBars;
      for(int i = 0; i < n; i++) {
         double xv = (double)i, yv = closes[n-1-i];
         sumX += xv; sumY += yv; sumXY += xv*yv; sumXX += xv*xv;
      }
      double denom = (n * sumXX - sumX * sumX);
      Ctx.regressionSlope = (denom != 0) ? (n*sumXY - sumX*sumY)/denom : 0.0;
   }

   double atrHist[]; ArraySetAsSeries(atrHist, true);
   if(CopyBuffer(atrHandle, 0, 0, InpATRPeriod*2, atrHist) >= InpATRPeriod*2) {
      double sum = 0;
      for(int i = 0; i < InpATRPeriod*2; i++) sum += atrHist[i];
      double avgAtr = sum / (InpATRPeriod*2);
      double ratio  = (avgAtr > 0) ? Ctx.atr / avgAtr : 1.0;
      Ctx.volRegime = (ratio < 0.7) ? 0 : (ratio > 1.3 ? 2 : 1);
   }

   Ctx.lastRefresh = TimeCurrent();
   UpdateDevelopingCandle(force);
}

void UpdateDevelopingCandle(bool forceReset) {
   datetime barTime = iTime(_Symbol, PERIOD_M1, 0);
   MqlTick tick; if(!SymbolInfoTick(_Symbol, tick)) return;
   double mid = (tick.bid + tick.ask) / 2.0;
   if(forceReset || barTime != Candle.startTime) {
      Candle.startTime = barTime;
      Candle.open = mid; Candle.high = mid; Candle.low = mid; Candle.close = mid;
   } else {
      Candle.close = mid;
      if(mid > Candle.high) Candle.high = mid;
      if(mid < Candle.low)  Candle.low  = mid;
   }
}

//+------------------------------------------------------------------+
//| FAST PATH: momentum                                               |
//+------------------------------------------------------------------+
double Displacement(int window) {
   TickPoint latest, past;
   if(!TickBufGet(0, latest)) return 0;
   if(!TickBufGet(window, past)) { if(!TickBufGet(g_tickCount-1, past)) return 0; }
   return latest.mid - past.mid;
}

void UpdateMomentum() {
   Mom.dispShort = Displacement(InpMomWindowShort);
   Mom.dispMed   = Displacement(InpMomWindowMed);
   Mom.dispLong  = Displacement(InpMomWindowLong);

   int upCount=0, total=0, consec=0; double deltaSum=0; int dir=0, lastDir=0;
   TickPoint a, b;
   int n = MathMin(g_tickCount-1, InpMomWindowLong);
   for(int i = 0; i < n; i++) {
      if(!TickBufGet(i,a) || !TickBufGet(i+1,b)) break;
      double d = a.mid - b.mid;
      deltaSum += MathAbs(d);
      total++;
      dir = (d > 0) ? 1 : (d < 0 ? -1 : 0);
      if(dir != 0) {
         if(dir == lastDir || lastDir == 0) consec++;
         else break;
         lastDir = dir;
         if(dir > 0) upCount++;
      }
   }
   Mom.directionalRatio = (total > 0) ? (double)upCount / total : 0.5;
   Mom.consecutiveDir   = consec;
   Mom.avgTickDelta     = (total > 0) ? deltaSum / total : 0.0;

   TickPoint latest, past;
   Mom.velocity = 0;
   if(TickBufGet(0, latest) && TickBufGet(MathMin(InpMomWindowMed, g_tickCount-1), past)) {
      double elapsedSec = (double)(latest.ms - past.ms) / 1000.0;
      if(elapsedSec > 0.001) Mom.velocity = (Mom.dispMed / pipSize) / elapsedSec;
   }

   double vNear=0, vFar=0;
   TickPoint mid1, mid0, mid2;
   int half = MathMax(2, InpMomWindowMed/2);
   if(TickBufGet(0, mid0) && TickBufGet(half, mid1) && TickBufGet(half*2, mid2)) {
      double e1 = (double)(mid0.ms - mid1.ms) / 1000.0;
      double e2 = (double)(mid1.ms - mid2.ms) / 1000.0;
      if(e1 > 0.001) vNear = ((mid0.mid - mid1.mid) / pipSize) / e1;
      if(e2 > 0.001) vFar  = ((mid1.mid - mid2.mid) / pipSize) / e2;
   }
   Mom.accelRatio = (MathAbs(vFar) > 0.001) ? MathAbs(vNear) / MathAbs(vFar) : 1.0;
   if(Mom.accelRatio > 1.15)      Mom.speed = SPD_ACCEL;
   else if(Mom.accelRatio < 0.85) Mom.speed = SPD_DECEL;
   else                           Mom.speed = SPD_STABLE;

   double dispPips = MathAbs(Mom.dispMed) / pipSize;
   if(dispPips < InpFlatThresholdPips) Mom.state = MOM_FLAT;
   else Mom.state = (Mom.dispMed > 0) ? MOM_UP : MOM_DOWN;
}

//+------------------------------------------------------------------+
//| HARD SAFETY GATE                                                   |
//+------------------------------------------------------------------+
bool HardSafetyOK(string &reason) {
   if(!Risk.tradingEnabled) { reason = Risk.stopReason; return false; }
   if(TimeCurrent() < Risk.errorLockoutUntil) { reason = "ERROR LOCKOUT"; return false; }

   ENUM_SYMBOL_TRADE_MODE tmode = (ENUM_SYMBOL_TRADE_MODE)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_MODE);
   if(tmode == SYMBOL_TRADE_MODE_DISABLED || tmode == SYMBOL_TRADE_MODE_CLOSEONLY) {
      reason = "MARKET CLOSED/RESTRICTED"; return false;
   }
   if(!MQLInfoInteger(MQL_TRADE_ALLOWED) || !TerminalInfoInteger(TERMINAL_TRADE_ALLOWED) ||
      !AccountInfoInteger(ACCOUNT_TRADE_ALLOWED)) { reason = "TRADING NOT ALLOWED"; return false; }

   MqlTick tick;
   if(!SymbolInfoTick(_Symbol, tick)) { reason = "NO TICK"; return false; }
   int spreadPts = (int)MathRound((tick.ask - tick.bid) / symbolPoint);
   bool spreadHardOK = spreadPts <= InpMaxSpreadPoints;
   if(InpSpreadATRRelative && Ctx.atr > 0) {
      double atrPips        = Ctx.atr / pipSize;
      double maxAllowedPts  = (atrPips * InpMaxSpreadATRFraction * pipSize) / symbolPoint;
      spreadHardOK = spreadHardOK && (spreadPts <= maxAllowedPts);
   }
   if(!spreadHardOK) { reason = "SPREAD UNSAFE"; return false; }

   if(GetTotalExposureLots() >= InpMaxTotalLots)   { reason = "MAX EXPOSURE"; return false; }
   if(CountOpenPositions()  >= InpMaxOpenPositions) { reason = "MAX POSITIONS"; return false; }
   if(CountPendingOrders()  >= InpMaxPendingOrders) { reason = "MAX PENDING"; return false; }

   double freeMargin = AccountInfoDouble(ACCOUNT_MARGIN_FREE);
   double marginReq  = 0;
   double refLot = InpUseRiskPercent ? 0.01 : InpFixedLot;
   if(OrderCalcMargin(ORDER_TYPE_BUY, _Symbol, refLot, tick.ask, marginReq)) {
      if(marginReq * InpMinFreeMarginBuffer > freeMargin) { reason = "MARGIN UNSAFE"; return false; }
   }

   long stopLevel   = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   long freezeLevel = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_FREEZE_LEVEL);
   if(stopLevel < 0 || freezeLevel < 0) { reason = "INVALID BROKER DISTANCE"; return false; }

   return true;
}

//+------------------------------------------------------------------+
//| BIAS (kept lightweight — used for direction confirmation)          |
//+------------------------------------------------------------------+
int ComputeBias() {
   int tickBias = (Mom.state == MOM_UP) ? 1 : (Mom.state == MOM_DOWN ? -1 : 0);
   int emaBias  = (Ctx.emaFast > Ctx.emaMed && Ctx.emaMed >= Ctx.emaSlow) ? 1 :
                  (Ctx.emaFast < Ctx.emaMed && Ctx.emaMed <= Ctx.emaSlow) ? -1 : 0;
   int regBias  = (Ctx.regressionSlope > 0) ? 1 : (Ctx.regressionSlope < 0 ? -1 : 0);
   double score = tickBias * 3.0 + emaBias * 1.0 + regBias * 1.0;
   if(score > 0 && Ctx.rsi >= InpRSIOverbought) score *= 0.5;
   if(score < 0 && Ctx.rsi <= InpRSIOversold)   score *= 0.5;
   if(score > 0.5)  return  1;
   if(score < -0.5) return -1;
   return 0;
}

//+------------------------------------------------------------------+
//| DISTANCE / LOT HELPERS                                            |
//+------------------------------------------------------------------+
double BrokerMinDistance() {
   long stopLevel  = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   long freezeLevel= SymbolInfoInteger(_Symbol, SYMBOL_TRADE_FREEZE_LEVEL);
   MqlTick tick; SymbolInfoTick(_Symbol, tick);
   double spread = tick.ask - tick.bid;
   double d1 = stopLevel   * symbolPoint;
   double d2 = freezeLevel * symbolPoint;
   double d3 = spread * 1.2;
   double d4 = symbolPoint * 5;
   return MathMax(MathMax(d1,d2), MathMax(d3,d4));
}

// Chase distance: very tight, just enough to be above/below current price
double ChaseDistance() {
   double chasePips = InpChaseDistancePips;
   double raw = chasePips * pipSize + Mom.avgTickDelta * InpMicroVolMult;
   return MathMax(raw, BrokerMinDistance());
}

// Shadow distance: behind price, waiting for reversal
double ShadowDistance() {
   double raw = InpShadowDistancePips * pipSize;
   return MathMax(raw, BrokerMinDistance());
}

double NormalizeVolume(double vol) {
   double step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   double minV = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxV = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   if(step <= 0) step = 0.01;
   double n = MathRound(vol / step) * step;
   return NormalizeDouble(MathMax(minV, MathMin(maxV, n)), 2);
}

double CalculateLotSize(double slDistance) {
   double minV      = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double tickSize  = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   if(tickValue <= 0 || tickSize <= 0 || slDistance <= 0) return 0;
   double equity    = AccountInfoDouble(ACCOUNT_EQUITY);
   double riskPerLot = (slDistance / tickSize) * tickValue;
   if(riskPerLot <= 0) return 0;
   double lot;
   if(InpUseRiskPercent) {
      double riskAmount = equity * InpRiskPercent / 100.0;
      lot = riskAmount / riskPerLot;
   } else {
      lot = InpFixedLot;
   }
   lot = NormalizeVolume(lot);
   double minLotRiskDollars = minV * riskPerLot;
   double minLotRiskPct = (equity > 0) ? (minLotRiskDollars / equity) * 100.0 : 999;
   if(lot <= minV && minLotRiskPct > InpMaxAcceptableRiskPct) return 0;
   return lot;
}

//+------------------------------------------------------------------+
//| COUNTERS                                                           |
//+------------------------------------------------------------------+
int CountOpenPositions() {
   int c = 0;
   for(int i = 0; i < PositionsTotal(); i++) {
      ulong t = PositionGetTicket(i);
      if(t == 0 || !PositionSelectByTicket(t)) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol || PositionGetInteger(POSITION_MAGIC) != magic) continue;
      c++;
   }
   return c;
}

int CountPendingOrders() {
   int c = 0;
   for(int i = 0; i < OrdersTotal(); i++) {
      ulong t = OrderGetTicket(i);
      if(t == 0 || !OrderSelect(t)) continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol || OrderGetInteger(ORDER_MAGIC) != magic) continue;
      c++;
   }
   return c;
}

double GetTotalExposureLots() {
   double tot = 0;
   for(int i = 0; i < PositionsTotal(); i++) {
      ulong t = PositionGetTicket(i);
      if(t == 0 || !PositionSelectByTicket(t)) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol || PositionGetInteger(POSITION_MAGIC) != magic) continue;
      tot += PositionGetDouble(POSITION_VOLUME);
   }
   for(int i = 0; i < OrdersTotal(); i++) {
      ulong t = OrderGetTicket(i);
      if(t == 0 || !OrderSelect(t)) continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol || OrderGetInteger(ORDER_MAGIC) != magic) continue;
      tot += OrderGetDouble(ORDER_VOLUME_CURRENT);
   }
   return tot;
}

bool HasOpenPosition(ENUM_POSITION_TYPE ptype) {
   for(int i = 0; i < PositionsTotal(); i++) {
      ulong t = PositionGetTicket(i);
      if(t == 0 || !PositionSelectByTicket(t)) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol || PositionGetInteger(POSITION_MAGIC) != magic) continue;
      if((ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE) == ptype) return true;
   }
   return false;
}

//+------------------------------------------------------------------+
//| ORDER SLOT HELPERS                                                 |
//+------------------------------------------------------------------+
bool CanModifyNow(OrderSlot &slot) {
   ulong now = GetTickCount64();
   if(now - slot.lastModifyMs < (ulong)InpMinModifyIntervalMs) return false;
   datetime nowSec = TimeCurrent();
   if(nowSec != slot.modSecondWindow) { slot.modSecondWindow = nowSec; slot.modsThisSecond = 0; }
   if(slot.modsThisSecond >= InpMaxModsPerSecond) return false;
   datetime nowMin = nowSec - (nowSec % 60);
   if(nowMin != slot.modMinuteWindow) { slot.modMinuteWindow = nowMin; slot.modsThisMinute = 0; }
   if(slot.modsThisMinute >= InpMaxModsPerMinute) return false;
   return true;
}

void RegisterModify(OrderSlot &slot) {
   slot.lastModifyMs = GetTickCount64();
   slot.modsThisSecond++;
   slot.modsThisMinute++;
}

void RegisterTradeResult(bool ok) {
   if(ok) { Risk.consecutiveErrors = 0; return; }
   Risk.consecutiveErrors++;
   if(Risk.consecutiveErrors >= InpMaxConsecutiveErrors) {
      Risk.errorLockoutUntil = TimeCurrent() + InpErrorLockoutSeconds;
      Risk.consecutiveErrors = 0;
   }
}

void CancelSlot(OrderSlot &slot) {
   if(slot.ticket != 0) {
      if(OrderSelect(slot.ticket)) trade.OrderDelete(slot.ticket);
   }
   ZeroMemory(slot);
}

bool DeployOrder(OrderSlot &slot, bool isBuy, double price, double lot, double sl, double tp, SlotRole role) {
   bool ok;
   if(isBuy) ok = trade.BuyStop(lot, price, _Symbol, sl, tp, ORDER_TIME_GTC, 0, "AX_CHASE_BUY");
   else      ok = trade.SellStop(lot, price, _Symbol, sl, tp, ORDER_TIME_GTC, 0, "AX_CHASE_SELL");
   RegisterTradeResult(ok);
   if(ok) {
      slot.ticket      = trade.ResultOrder();
      slot.price       = price;
      slot.role        = role;
      slot.placedTime  = TimeCurrent();
      slot.lastModifyMs = GetTickCount64();
   }
   return ok;
}

void RepriceSlot(OrderSlot &slot, bool isBuy, double newPrice, double sl, double tp) {
   if(slot.ticket == 0 || !OrderSelect(slot.ticket)) { ZeroMemory(slot); return; }
   if(!CanModifyNow(slot)) return;
   double diffPips = MathAbs(newPrice - slot.price) / pipSize;
   if(diffPips < InpMinRepriceDistPips) return;
   bool ok = trade.OrderModify(slot.ticket, newPrice, sl, tp, ORDER_TIME_GTC, 0);
   if(ok) { slot.price = newPrice; RegisterModify(slot); }
   RegisterTradeResult(ok);
}

//+------------------------------------------------------------------+
//| CHASE ENGINE — The core leapfrog logic                            |
//+------------------------------------------------------------------+
//
//  GOING UP (g_chaseDir == CHASE_UP):
//    BuySlot  → CHASE order: buy stop just ABOVE ask (will fill as price rises)
//    SellSlot → SHADOW order: sell stop BEHIND current bid (will fill on reversal)
//
//  GOING DOWN (g_chaseDir == CHASE_DOWN):
//    SellSlot → CHASE order: sell stop just BELOW bid (will fill as price falls)
//    BuySlot  → SHADOW order: buy stop BEHIND current ask (will fill on reversal)
//
//  On position fill (handled in OnTradeTransaction):
//    Chase fills → position open. Shadow keeps tracking behind.
//    When price reverses, shadow fills. The old position hits SL/TP or
//    gets closed by position management. New chase deploys in new direction.
//+------------------------------------------------------------------+
void ManageChaseEngine() {
   string blockReason;
   bool safe = HardSafetyOK(blockReason);

   MqlTick tick; if(!SymbolInfoTick(_Symbol, tick)) return;
   double atr = Ctx.atr;
   if(atr <= 0) { g_state = ES_ANALYZING; g_stateReason = "WAITING FOR ATR"; return; }

   // Dead market block — pull all pending orders and pause
   if(g_isDeadMarket) {
      if(BuySlot.ticket != 0)  CancelSlot(BuySlot);
      if(SellSlot.ticket != 0) CancelSlot(SellSlot);
      g_chaseDir = CHASE_NONE;
      g_state = ES_DEAD_MARKET;
      g_stateReason = "DEAD MARKET — K-MEANS";
      return;
   }

   if(!safe) {
      if(BuySlot.ticket != 0)  CancelSlot(BuySlot);
      if(SellSlot.ticket != 0) CancelSlot(SellSlot);
      g_chaseDir  = CHASE_NONE;
      g_stateReason = blockReason;
      g_state = (blockReason == "PROFIT TARGET")    ? ES_PROFIT_STOPPED :
                (blockReason == "DAILY LOSS LIMIT" ||
                 blockReason == "MAX DRAWDOWN")     ? ES_RISK_STOPPED   :
                (blockReason == "ERROR LOCKOUT")    ? ES_ERROR_LOCKOUT  :
                (blockReason == "MANUAL STOP")      ? ES_MANUAL_STOPPED : ES_ANALYZING;
      return;
   }

   // Determine current dominant direction
   int bias      = ComputeBias();
   bool hasBuyPos  = HasOpenPosition(POSITION_TYPE_BUY);
   bool hasSellPos = HasOpenPosition(POSITION_TYPE_SELL);

   // Direction decision: prefer confirmed momentum over pure bias
   ChaseDir newDir = CHASE_NONE;
   if(Mom.state == MOM_UP   && (bias >= 0)) newDir = CHASE_UP;
   if(Mom.state == MOM_DOWN && (bias <= 0)) newDir = CHASE_DOWN;

   // Direction changed → cancel all pending, reset
   if(newDir != CHASE_NONE && newDir != g_chaseDir) {
      if(BuySlot.ticket != 0)  CancelSlot(BuySlot);
      if(SellSlot.ticket != 0) CancelSlot(SellSlot);
      g_chaseDir = newDir;
   }

   double chaseDist  = ChaseDistance();
   double shadowDist = ShadowDistance();
   double slDist     = MathMax(atr * InpSLATRMult, BrokerMinDistance());
   double tpDist     = MathMax(atr * InpTPATRMult,  BrokerMinDistance());

   if(g_chaseDir == CHASE_UP) {
      //------------------------------------------------------------
      // CHASE BUY: place/reprice buy stop just above ask
      //------------------------------------------------------------
      double buyChasePrice = NormalizeDouble(tick.ask + chaseDist, symbolDigits);
      double buyChaseSL    = NormalizeDouble(buyChasePrice - slDist, symbolDigits);
      double buyChaseTP    = NormalizeDouble(buyChasePrice + tpDist, symbolDigits);

      if(!hasBuyPos) {
         if(BuySlot.ticket == 0) {
            double lot = CalculateLotSize(slDist);
            if(lot > 0) DeployOrder(BuySlot, true, buyChasePrice, lot, buyChaseSL, buyChaseTP, ROLE_CHASE);
         } else {
            // Reprice to keep chasing
            int age = (int)(TimeCurrent() - BuySlot.placedTime);
            if(age >= InpMaxPendingAgeSeconds) {
               // Stale: re-evaluate, cancel if price ran away
               if(tick.ask > BuySlot.price + chaseDist * 3)
                  CancelSlot(BuySlot); // Price moved too far, order is stale
               else
                  RepriceSlot(BuySlot, true, buyChasePrice, buyChaseSL, buyChaseTP);
            } else {
               RepriceSlot(BuySlot, true, buyChasePrice, buyChaseSL, buyChaseTP);
            }
         }
      }

      //------------------------------------------------------------
      // SHADOW SELL: sell stop behind current price (below bid)
      // This is the "reversal catcher" — fills when price drops back
      //------------------------------------------------------------
      double sellShadowPrice = NormalizeDouble(tick.bid - shadowDist, symbolDigits);
      double sellShadowSL    = NormalizeDouble(sellShadowPrice + slDist, symbolDigits);
      double sellShadowTP    = NormalizeDouble(sellShadowPrice - tpDist, symbolDigits);

      if(!hasSellPos) {
         if(SellSlot.ticket == 0) {
            double lot = CalculateLotSize(slDist);
            if(lot > 0) DeployOrder(SellSlot, false, sellShadowPrice, lot, sellShadowSL, sellShadowTP, ROLE_SHADOW);
         } else {
            // Keep shadow trailing just below bid as price moves up
            RepriceSlot(SellSlot, false, sellShadowPrice, sellShadowSL, sellShadowTP);
         }
      }
      UpdateStateChase(hasBuyPos, hasSellPos, true);
   }
   else if(g_chaseDir == CHASE_DOWN) {
      //------------------------------------------------------------
      // CHASE SELL: place/reprice sell stop just below bid
      //------------------------------------------------------------
      double sellChasePrice = NormalizeDouble(tick.bid - chaseDist, symbolDigits);
      double sellChaseSL    = NormalizeDouble(sellChasePrice + slDist, symbolDigits);
      double sellChaseTP    = NormalizeDouble(sellChasePrice - tpDist, symbolDigits);

      if(!hasSellPos) {
         if(SellSlot.ticket == 0) {
            double lot = CalculateLotSize(slDist);
            if(lot > 0) DeployOrder(SellSlot, false, sellChasePrice, lot, sellChaseSL, sellChaseTP, ROLE_CHASE);
         } else {
            int age = (int)(TimeCurrent() - SellSlot.placedTime);
            if(age >= InpMaxPendingAgeSeconds) {
               if(tick.bid < SellSlot.price - chaseDist * 3)
                  CancelSlot(SellSlot);
               else
                  RepriceSlot(SellSlot, false, sellChasePrice, sellChaseSL, sellChaseTP);
            } else {
               RepriceSlot(SellSlot, false, sellChasePrice, sellChaseSL, sellChaseTP);
            }
         }
      }

      //------------------------------------------------------------
      // SHADOW BUY: buy stop behind current price (above ask)
      // Fills when price reverses upward
      //------------------------------------------------------------
      double buyShPrice = NormalizeDouble(tick.ask + shadowDist, symbolDigits);
      double buyShSL    = NormalizeDouble(buyShPrice - slDist, symbolDigits);
      double buyShTP    = NormalizeDouble(buyShPrice + tpDist, symbolDigits);

      if(!hasBuyPos) {
         if(BuySlot.ticket == 0) {
            double lot = CalculateLotSize(slDist);
            if(lot > 0) DeployOrder(BuySlot, true, buyShPrice, lot, buyShSL, buyShTP, ROLE_SHADOW);
         } else {
            // Keep shadow trailing just above ask as price falls
            RepriceSlot(BuySlot, true, buyShPrice, buyShSL, buyShTP);
         }
      }
      UpdateStateChase(hasBuyPos, hasSellPos, false);
   }
   else {
      // No clear direction: pull all pending, wait
      if(BuySlot.ticket != 0)  CancelSlot(BuySlot);
      if(SellSlot.ticket != 0) CancelSlot(SellSlot);
      g_state = ES_ANALYZING; g_stateReason = "NO DIRECTION";
   }
}

void UpdateStateChase(bool hasBuyPos, bool hasSellPos, bool chasingUp) {
   if(hasBuyPos && hasSellPos) { g_state = ES_POSITION_HEDGED; g_stateReason = "HEDGED"; }
   else if(hasBuyPos)  { g_state = ES_POSITION_BUY;  g_stateReason = "BUY ACTIVE"; }
   else if(hasSellPos) { g_state = ES_POSITION_SELL; g_stateReason = "SELL ACTIVE"; }
   else if(chasingUp)  { g_state = ES_CHASING_UP;   g_stateReason = "CHASING UP"; }
   else                { g_state = ES_CHASING_DOWN;  g_stateReason = "CHASING DOWN"; }
}

//+------------------------------------------------------------------+
//| POSITION MANAGEMENT: breakeven / trailing                         |
//+------------------------------------------------------------------+
void ManagePositions() {
   double atr = Ctx.atr; if(atr <= 0) return;
   long stopLvl   = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   double minStop = stopLvl * symbolPoint;

   for(int i = PositionsTotal()-1; i >= 0; i--) {
      ulong t = PositionGetTicket(i);
      if(t == 0 || !PositionSelectByTicket(t)) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol || PositionGetInteger(POSITION_MAGIC) != magic) continue;

      ENUM_POSITION_TYPE ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
      double curSL     = PositionGetDouble(POSITION_SL);
      double curTP     = PositionGetDouble(POSITION_TP);
      double bid       = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      double ask       = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      double curPrice  = (ptype == POSITION_TYPE_BUY) ? bid : ask;
      double profitDist= (ptype == POSITION_TYPE_BUY) ? (curPrice - openPrice) : (openPrice - curPrice);
      double newSL     = curSL;
      bool   modify    = false;

      if(InpUseBreakeven && profitDist >= InpBreakevenATR * atr) {
         double be = (ptype == POSITION_TYPE_BUY)
                   ? openPrice + InpBreakevenBufferPts * symbolPoint
                   : openPrice - InpBreakevenBufferPts * symbolPoint;
         if((ptype == POSITION_TYPE_BUY  && (curSL == 0 || curSL < be)) ||
            (ptype == POSITION_TYPE_SELL && (curSL == 0 || curSL > be)))
            { newSL = be; modify = true; }
      }

      if(InpUseTrailing && profitDist >= InpTrailStartATR * atr) {
         double trail = (ptype == POSITION_TYPE_BUY)
                       ? curPrice - InpTrailATR * atr
                       : curPrice + InpTrailATR * atr;
         if((ptype == POSITION_TYPE_BUY  && trail > newSL) ||
            (ptype == POSITION_TYPE_SELL && (newSL == 0 || trail < newSL)))
            { newSL = trail; modify = true; }
      }

      if(modify) {
         newSL = NormalizeDouble(newSL, symbolDigits);
         if(ptype == POSITION_TYPE_BUY  && (bid - newSL) >= minStop) trade.PositionModify(t, newSL, curTP);
         if(ptype == POSITION_TYPE_SELL && (newSL - ask) >= minStop) trade.PositionModify(t, newSL, curTP);
      }
   }
}

//+------------------------------------------------------------------+
//| RISK CHECK                                                         |
//+------------------------------------------------------------------+
void CheckRisk() {
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   Risk.peakEquity = MathMax(Risk.peakEquity, equity);
   MqlDateTime tm; TimeToStruct(TimeCurrent(), tm);
   if(tm.day != Risk.lastDay) {
      Risk.dayStartBalance = AccountInfoDouble(ACCOUNT_BALANCE);
      Risk.lastDay         = tm.day;
      Risk.tradingEnabled  = true;
      Risk.stopReason      = "";
   }
   Risk.dailyPL = equity - Risk.dayStartBalance;
   if(Risk.tradingEnabled) {
      if(Risk.dailyPL >= InpDailyProfitTarget)
         { Risk.tradingEnabled = false; Risk.stopReason = "PROFIT TARGET"; }
      else if(Risk.dailyPL <= -InpDailyLossLimit)
         { Risk.tradingEnabled = false; Risk.stopReason = "DAILY LOSS LIMIT"; }
      else if(equity < Risk.peakEquity * (1 - InpMaxDrawdownPct / 100.0))
         { Risk.tradingEnabled = false; Risk.stopReason = "MAX DRAWDOWN"; }
   }
}

//+------------------------------------------------------------------+
//| EVENTS                                                             |
//+------------------------------------------------------------------+
void OnTick() {
   MqlTick tick;
   if(!SymbolInfoTick(_Symbol, tick)) return;
   TickBufPush(tick.bid, tick.ask);
   if(g_tickCount < 8) return;  // need minimal history for K-Means + momentum

   UpdateDevelopingCandle(false);
   UpdateMomentum();
   RunKMeans();      // Fast dead-market detection on every tick
   CheckRisk();
   ManageChaseEngine();
   ManagePositions();
}

void OnTimer() {
   RefreshSlowContext(false);
   if(InpShowDashboard) {
      ulong now = GetTickCount64();
      ulong intervalMs = (InpDashboardHz > 0) ? (ulong)(1000 / InpDashboardHz) : 150;
      if(now - g_lastDashboardMs >= intervalMs) {
         g_lastDashboardMs = now;
         DrawDashboard();
      }
   }
}

void OnTradeTransaction(const MqlTradeTransaction &trans, const MqlTradeRequest &request, const MqlTradeResult &result) {
   if(trans.type != TRADE_TRANSACTION_DEAL_ADD) return;
   ulong dealTicket = trans.deal;
   if(!HistoryDealSelect(dealTicket)) return;
   if(HistoryDealGetInteger(dealTicket, DEAL_MAGIC) != magic ||
      HistoryDealGetString(dealTicket,  DEAL_SYMBOL) != _Symbol) return;

   long entry = HistoryDealGetInteger(dealTicket, DEAL_ENTRY);
   if(entry == DEAL_ENTRY_IN) {
      long dealType = HistoryDealGetInteger(dealTicket, DEAL_TYPE);
      // Chase order filled → clear slot so ManageChaseEngine re-deploys shadow correctly
      if(dealType == DEAL_TYPE_BUY  && BuySlot.role  == ROLE_CHASE) ZeroMemory(BuySlot);
      if(dealType == DEAL_TYPE_SELL && SellSlot.role == ROLE_CHASE) ZeroMemory(SellSlot);
      // Shadow filled → price reversed. Clear shadow slot.
      // ManageChaseEngine will detect the new direction on next tick
      // and deploy a new chase + shadow in the reversed direction.
      if(dealType == DEAL_TYPE_BUY  && BuySlot.role  == ROLE_SHADOW) {
         ZeroMemory(BuySlot);
         // Reverse chase direction on shadow fill
         g_chaseDir = CHASE_UP;
         if(SellSlot.ticket != 0) CancelSlot(SellSlot);
      }
      if(dealType == DEAL_TYPE_SELL && SellSlot.role == ROLE_SHADOW) {
         ZeroMemory(SellSlot);
         g_chaseDir = CHASE_DOWN;
         if(BuySlot.ticket != 0) CancelSlot(BuySlot);
      }
   }
   // On DEAL_ENTRY_OUT: position closed. Next tick ManageChaseEngine re-evaluates fresh.
}

void OnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam) {
   if(id != CHARTEVENT_OBJECT_CLICK) return;
   if(sparam == AX_PREFIX+"BTN_PROFIT") { ObjectSetInteger(0,sparam,OBJPROP_STATE,false); CloseAllProfitable(); }
   if(sparam == AX_PREFIX+"BTN_LOSS")   { ObjectSetInteger(0,sparam,OBJPROP_STATE,false); CloseAllLosing(); }
   if(sparam == AX_PREFIX+"BTN_RESET")  { ObjectSetInteger(0,sparam,OBJPROP_STATE,false); ResetStrategyState(); }
}

void CloseAllProfitable() {
   for(int i = PositionsTotal()-1; i >= 0; i--) {
      ulong t = PositionGetTicket(i);
      if(t == 0 || !PositionSelectByTicket(t)) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol || PositionGetInteger(POSITION_MAGIC) != magic) continue;
      if(PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP) > 0) trade.PositionClose(t);
   }
}

void CloseAllLosing() {
   for(int i = PositionsTotal()-1; i >= 0; i--) {
      ulong t = PositionGetTicket(i);
      if(t == 0 || !PositionSelectByTicket(t)) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol || PositionGetInteger(POSITION_MAGIC) != magic) continue;
      if(PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP) < 0) trade.PositionClose(t);
   }
}

void ResetStrategyState() {
   if(BuySlot.ticket  != 0) CancelSlot(BuySlot);
   if(SellSlot.ticket != 0) CancelSlot(SellSlot);
   ZeroMemory(Mom);
   g_chaseDir           = CHASE_NONE;
   g_deadConfirmCount   = 0;
   g_isDeadMarket       = false;
   Risk.tradingEnabled  = true;
   Risk.stopReason      = "";
   Risk.consecutiveErrors   = 0;
   Risk.errorLockoutUntil   = 0;
   g_state      = ES_ANALYZING;
   g_stateReason = "RESET";
}

//+------------------------------------------------------------------+
//| DASHBOARD                                                          |
//+------------------------------------------------------------------+
void AXRect(string name,int x,int y,int w,int h,color bg,color border=clrNONE,int bw=1){
   string o=AX_PREFIX+name;
   if(ObjectFind(0,o)<0) ObjectCreate(0,o,OBJ_RECTANGLE_LABEL,0,0,0);
   ObjectSetInteger(0,o,OBJPROP_XDISTANCE,x); ObjectSetInteger(0,o,OBJPROP_YDISTANCE,y);
   ObjectSetInteger(0,o,OBJPROP_XSIZE,w);     ObjectSetInteger(0,o,OBJPROP_YSIZE,h);
   ObjectSetInteger(0,o,OBJPROP_BGCOLOR,bg);
   ObjectSetInteger(0,o,OBJPROP_BORDER_TYPE,BORDER_FLAT);
   ObjectSetInteger(0,o,OBJPROP_COLOR,border==clrNONE?bg:border);
   ObjectSetInteger(0,o,OBJPROP_WIDTH,bw);
   ObjectSetInteger(0,o,OBJPROP_BACK,false);
   ObjectSetInteger(0,o,OBJPROP_SELECTABLE,false);
   ObjectSetInteger(0,o,OBJPROP_HIDDEN,true);
}
void AXText(string name,int x,int y,string text,color clr,int size=9,string font="Segoe UI"){
   string o=AX_PREFIX+name;
   if(ObjectFind(0,o)<0) ObjectCreate(0,o,OBJ_LABEL,0,0,0);
   ObjectSetInteger(0,o,OBJPROP_XDISTANCE,x); ObjectSetInteger(0,o,OBJPROP_YDISTANCE,y);
   ObjectSetString(0,o,OBJPROP_TEXT,text);
   ObjectSetInteger(0,o,OBJPROP_COLOR,clr);
   ObjectSetInteger(0,o,OBJPROP_FONTSIZE,size);
   ObjectSetString(0,o,OBJPROP_FONT,font);
   ObjectSetInteger(0,o,OBJPROP_BACK,false);
   ObjectSetInteger(0,o,OBJPROP_SELECTABLE,false);
   ObjectSetInteger(0,o,OBJPROP_HIDDEN,true);
}
void AXButton(string name,int x,int y,int w,int h,string text,color bg,color txt){
   string o=AX_PREFIX+name;
   if(ObjectFind(0,o)<0) ObjectCreate(0,o,OBJ_BUTTON,0,0,0);
   ObjectSetInteger(0,o,OBJPROP_XDISTANCE,x); ObjectSetInteger(0,o,OBJPROP_YDISTANCE,y);
   ObjectSetInteger(0,o,OBJPROP_XSIZE,w);     ObjectSetInteger(0,o,OBJPROP_YSIZE,h);
   ObjectSetString(0,o,OBJPROP_TEXT,text);
   ObjectSetInteger(0,o,OBJPROP_BGCOLOR,bg);  ObjectSetInteger(0,o,OBJPROP_COLOR,txt);
   ObjectSetInteger(0,o,OBJPROP_FONTSIZE,9);
   ObjectSetInteger(0,o,OBJPROP_SELECTABLE,false);
   ObjectSetInteger(0,o,OBJPROP_HIDDEN,true);
   ObjectSetInteger(0,o,OBJPROP_STATE,false);
}

string ExecStateText() {
   switch(g_state) {
      case ES_WAITING:        return "WAITING";
      case ES_ANALYZING:      return "ANALYZING";
      case ES_CHASING_UP:     return "CHASING UP ↑";
      case ES_CHASING_DOWN:   return "CHASING DOWN ↓";
      case ES_POSITION_BUY:   return "BUY ACTIVE";
      case ES_POSITION_SELL:  return "SELL ACTIVE";
      case ES_POSITION_HEDGED:return "HEDGED";
      case ES_DEAD_MARKET:    return "DEAD MARKET — PAUSED";
      case ES_PROFIT_STOPPED: return "PROFIT TARGET REACHED";
      case ES_RISK_STOPPED:   return "RISK LIMIT — STOPPED";
      case ES_MANUAL_STOPPED: return "MANUAL STOPPED";
      case ES_ERROR_LOCKOUT:  return "ERROR LOCKOUT";
   }
   return "-";
}
color ExecStateColor() {
   switch(g_state) {
      case ES_CHASING_UP:     return clrDeepSkyBlue;
      case ES_CHASING_DOWN:   return clrCrimson;
      case ES_POSITION_BUY:   return clrDodgerBlue;
      case ES_POSITION_SELL:  return clrIndianRed;
      case ES_POSITION_HEDGED:return clrOrchid;
      case ES_DEAD_MARKET:    return clrDimGray;
      case ES_PROFIT_STOPPED: return clrLimeGreen;
      case ES_RISK_STOPPED:   return clrOrangeRed;
      case ES_ERROR_LOCKOUT:  return clrOrange;
      default:                return clrSilver;
   }
}

void DrawDashboard() {
   int x=InpDashboardX, y=InpDashboardY, w=340;
   color bgDeep=C'10,10,14', bgCard=C'20,20,28', border=C'55,55,70';
   color txtHi=clrWhiteSmoke, txtLo=C'130,130,150';

   AXRect("BG",x,y,w,540,bgDeep,border,1);
   int hy=y;

   // Header
   AXRect("HDR",x,hy,w,34,C'16,16,22',border,1);
   AXText("TITLE",x+10,hy+8,"AETHER-X GOLD  v2  [CHASE ENGINE]",clrGold,10,"Segoe UI Semibold");
   AXButton("BTN_PROFIT",x+w-190,hy+4,60,26,"P/L +",clrSeaGreen,clrWhite);
   AXButton("BTN_LOSS",  x+w-125,hy+4,60,26,"P/L -",clrRed,clrWhite);
   AXButton("BTN_RESET", x+w-60, hy+4,50,26,"RESET",C'60,60,80',clrWhite);
   hy+=40;

   // State
   color stClr = ExecStateColor();
   AXRect("STATE_CARD",x+8,hy,w-16,30,bgCard,stClr,1);
   AXText("STATE_VAL",x+16,hy+8,ExecStateText(),stClr,10,"Segoe UI Semibold");
   hy+=38;

   // Live market
   MqlTick tick; SymbolInfoTick(_Symbol,tick);
   int spread=(int)MathRound((tick.ask-tick.bid)/symbolPoint);
   AXText("HDR_MKT",x+8,hy,"LIVE MARKET",txtLo,7); hy+=14;
   AXRect("CARD_MKT",x+8,hy,w-16,64,bgCard,border,1);
   AXText("BID_L",x+16,  hy+6,"Bid",txtLo,7);    AXText("BID_V",x+16,  hy+16,DoubleToString(tick.bid,symbolDigits),clrDeepSkyBlue,9);
   AXText("ASK_L",x+120, hy+6,"Ask",txtLo,7);    AXText("ASK_V",x+120, hy+16,DoubleToString(tick.ask,symbolDigits),clrIndianRed,9);
   AXText("SPR_L",x+230, hy+6,"Spread",txtLo,7); AXText("SPR_V",x+230, hy+16,IntegerToString(spread)+" pt",txtHi,9);
   string momTxt = (Mom.state==MOM_UP?"UP ↑":Mom.state==MOM_DOWN?"DOWN ↓":"FLAT —");
   string spdTxt = (Mom.speed==SPD_ACCEL?"ACCEL":Mom.speed==SPD_DECEL?"DECEL":"STABLE");
   color momClr  = (Mom.state==MOM_UP?clrDeepSkyBlue:Mom.state==MOM_DOWN?clrIndianRed:clrSilver);
   AXText("MOM_L",x+16, hy+34,"Momentum",txtLo,7); AXText("MOM_V",x+16, hy+44,momTxt+" / "+spdTxt,momClr,9);
   AXText("VEL_L",x+180,hy+34,"Velocity",txtLo,7); AXText("VEL_V",x+180,hy+44,DoubleToString(Mom.velocity,2)+" p/s",txtHi,9);
   hy+=72;

   // K-Means
   AXText("HDR_KM",x+8,hy,"K-MEANS DEAD MARKET",txtLo,7); hy+=14;
   AXRect("CARD_KM",x+8,hy,w-16,50,bgCard,border,1);
   color kmClr = g_isDeadMarket ? clrOrangeRed : clrLimeGreen;
   string kmStr = g_isDeadMarket ? "DEAD MARKET" : "MARKET ACTIVE";
   AXText("KM_STAT_L",x+16, hy+6,"Status",txtLo,7);  AXText("KM_STAT_V",x+16, hy+16,kmStr,kmClr,9);
   AXText("KM_SPR_L", x+180,hy+6,"Cluster Spread",txtLo,7); AXText("KM_SPR_V",x+180,hy+16,DoubleToString(g_kmeans.spread,2)+" p",txtHi,9);
   AXText("KM_CNF_L", x+16, hy+30,"Confirm Count",txtLo,7); AXText("KM_CNF_V",x+120,hy+30,IntegerToString(g_deadConfirmCount)+"/"+IntegerToString(InpDeadMarketConfirm),txtHi,9);
   hy+=58;

   // Chase grid
   AXText("HDR_GRID",x+8,hy,"CHASE ENGINE",txtLo,7); hy+=14;
   AXRect("CARD_GRID",x+8,hy,w-16,72,bgCard,border,1);
   string dirStr = (g_chaseDir==CHASE_UP?"UP ↑":g_chaseDir==CHASE_DOWN?"DOWN ↓":"NONE —");
   color  dirClr = (g_chaseDir==CHASE_UP?clrDeepSkyBlue:g_chaseDir==CHASE_DOWN?clrIndianRed:clrSilver);
   AXText("DIR_L",x+16,hy+6,"Direction",txtLo,7); AXText("DIR_V",x+16,hy+16,dirStr,dirClr,9);
   string buyRole  = (BuySlot.ticket!=0  ? (BuySlot.role==ROLE_CHASE  ? "CHASE":"SHADOW") : "-");
   string sellRole = (SellSlot.ticket!=0 ? (SellSlot.role==ROLE_CHASE ? "CHASE":"SHADOW") : "-");
   string buyAge   = (BuySlot.ticket!=0  ? IntegerToString((int)(TimeCurrent()-BuySlot.placedTime))+"s" : "");
   string sellAge  = (SellSlot.ticket!=0 ? IntegerToString((int)(TimeCurrent()-SellSlot.placedTime))+"s" : "");
   AXText("BS_L",x+16,hy+30,"Buy Stop",txtLo,7);
   AXText("BS_V",x+16,hy+40,(BuySlot.ticket!=0?DoubleToString(BuySlot.price,symbolDigits)+" ["+buyRole+"] "+buyAge:"-"),clrDeepSkyBlue,9);
   AXText("SS_L",x+16,hy+54,"Sell Stop",txtLo,7);
   AXText("SS_V",x+16,hy+64,(SellSlot.ticket!=0?DoubleToString(SellSlot.price,symbolDigits)+" ["+sellRole+"] "+sellAge:"-"),clrIndianRed,9);
   hy+=80;

   // Context
   AXText("HDR_CTX",x+8,hy,"MARKET CONTEXT",txtLo,7); hy+=14;
   AXRect("CARD_CTX",x+8,hy,w-16,50,bgCard,border,1);
   AXText("ATR_L",x+16, hy+6,"ATR",txtLo,7);       AXText("ATR_V",x+16, hy+16,DoubleToString(Ctx.atr/pipSize,1)+" p",clrGoldenrod,9);
   AXText("EMA_L",x+120,hy+6,"EMA Slope",txtLo,7); AXText("EMA_V",x+120,hy+16,(Ctx.emaSlopeFast>=0?"UP ↑":"DOWN ↓"),(Ctx.emaSlopeFast>=0?clrDeepSkyBlue:clrIndianRed),9);
   AXText("RSI_L",x+230,hy+6,"RSI",txtLo,7);       AXText("RSI_V",x+230,hy+16,DoubleToString(Ctx.rsi,1),txtHi,9);
   string regimeStr = (Ctx.volRegime==0?"LOW":Ctx.volRegime==2?"HIGH":"NORMAL");
   AXText("VOLR_L",x+16,hy+30,"Vol Regime",txtLo,7); AXText("VOLR_V",x+120,hy+30,regimeStr,txtHi,9);
   hy+=58;

   // Risk
   AXText("HDR_RISK",x+8,hy,"RISK",txtLo,7); hy+=14;
   AXRect("CARD_RISK",x+8,hy,w-16,64,bgCard,border,1);
   double equity=AccountInfoDouble(ACCOUNT_EQUITY), balance=AccountInfoDouble(ACCOUNT_BALANCE);
   AXText("EQ_L",x+16, hy+6,"Equity",txtLo,7);   AXText("EQ_V",x+16, hy+16,"$"+DoubleToString(equity,2),txtHi,9);
   AXText("BAL_L",x+120,hy+6,"Balance",txtLo,7); AXText("BAL_V",x+120,hy+16,"$"+DoubleToString(balance,2),txtHi,9);
   AXText("DAY_L",x+16,hy+34,"Day P/L",txtLo,7);
   AXText("DAY_V",x+16,hy+44,(Risk.dailyPL>=0?"+":"")+DoubleToString(Risk.dailyPL,2),(Risk.dailyPL>=0?clrLimeGreen:clrIndianRed),9);
   AXText("EXP_L",x+180,hy+34,"Exposure",txtLo,7); AXText("EXP_V",x+180,hy+44,DoubleToString(GetTotalExposureLots(),2)+" lots",txtHi,9);
   double floatPL=0;
   for(int i=0;i<PositionsTotal();i++){
      ulong t=PositionGetTicket(i); if(t==0||!PositionSelectByTicket(t)) continue;
      if(PositionGetString(POSITION_SYMBOL)!=_Symbol||PositionGetInteger(POSITION_MAGIC)!=magic) continue;
      floatPL+=PositionGetDouble(POSITION_PROFIT)+PositionGetDouble(POSITION_SWAP);
   }
   hy+=72;

   // Footer
   AXRect("FOOT",x+8,hy,w-16,16,C'8,8,12',border,1);
   AXText("FOOT_TXT",x+14,hy+3,"AETHER-X GOLD v2  |  chase-engine + k-means dead filter",txtLo,6);
   hy+=24;

   // Resize outer BG to actual content
   AXRect("BG",x,y,w,hy-y,bgDeep,border,1);
   ChartRedraw(0);
}
//+------------------------------------------------------------------+