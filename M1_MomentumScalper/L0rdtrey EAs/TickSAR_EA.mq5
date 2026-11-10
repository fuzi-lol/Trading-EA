//+------------------------------------------------------------------+
//|        AURUM X PRIME v5.1 - GOLD M1 QUANTUM EDITION              |
//|        Ultra-Fast Linear Regression Momentum Engine              |
//|        5-Second Adaptive Order Recycler for XAUUSD              |
//|        Micro-Account Compatible | Recovery Mode | No Pause       |
//+------------------------------------------------------------------+
#property copyright "Aurum Quantum Systems © 2024"
#property version   "5.1"
#property description "Ultra-Fast Gold M1 Momentum Grid with Linear Regression Intelligence"
#property strict

#include <Trade\Trade.mqh>

//+------------------------------------------------------------------+
//| AURUM X PRIME - MIDNIGHT GLASS PALETTE                           |
//+------------------------------------------------------------------+
#define AX_PREFIX "AXP_"

// Deep Void & Frosted Glass
#define AX_BG_VOID       C'4,6,14'
#define AX_BG_GLASS      C'14,20,38'
#define AX_BG_CARD       C'10,14,28'
#define AX_BG_INSET      C'6,8,18'
#define AX_BG_BUTTON     C'18,26,48'
#define AX_BG_HEADER     C'8,12,24'

// Borders & Glows
#define AX_BORDER_GLOW   C'50,70,120'
#define AX_BORDER_DIM    C'25,35,60'
#define AX_BORDER_HI     C'80,110,180'
#define AX_DIV           C'20,28,50'

// Text Tiers
#define AX_TEXT_PLATINUM C'235,240,255'
#define AX_TEXT_SILVER   C'155,165,195'
#define AX_TEXT_ASH      C'85,95,125'

// Accent Colors
#define AX_GOLD          C'255,200,80'
#define AX_GOLD_DIM      C'180,140,40'
#define AX_AMBER         C'255,160,40'
#define AX_TEAL          C'0,220,180'
#define AX_CORAL         C'255,80,110'
#define AX_EMERALD       C'0,230,120'
#define AX_LIME          C'160,255,80'
#define AX_ORANGE        C'255,140,50'
#define AX_VIOLET        C'160,120,255'
#define AX_ICE           C'120,200,255'

//+------------------------------------------------------------------+
//| ENUMS                                                            |
//+------------------------------------------------------------------+
enum ExecutionMode { Stealth = 1, Adaptive = 2, Aggressive = 3 };
enum VolatilityRegime { VOL_DORMANT = 0, VOL_LOW = 1, VOL_NORMAL = 2, VOL_HIGH = 3, VOL_EXTREME = 4 };
enum MarketMomentum { MOM_STRONG_BEAR = -2, MOM_WEAK_BEAR = -1, MOM_NEUTRAL = 0, MOM_WEAK_BULL = 1, MOM_STRONG_BULL = 2 };
enum EAState { STATE_ACTIVE = 0, STATE_RECOVERY = 1, STATE_TARGET_HIT = 2 };

//+------------------------------------------------------------------+
//| INPUTS                                                           |
//+------------------------------------------------------------------+
input group "═══ AURUM GOLD M1 QUANTUM ENGINE ═══"
input bool   InpUseUltraFastMomentum = true;
input int    InpMinQualityScore = 70;
input int    InpLinearRegPeriod = 14;
input int    InpRSIPeriod = 7;
input int    InpMicroMomentumBars = 3;
input double InpTickVelocityThreshold = 0.30;
input double InpMinSlopeATRRatio = 0.010;

input group "═══ GRID ENGINE & 5-SEC RECYCLER ═══"
input ExecutionMode InpMode = Aggressive;
input int    InpOrdersPerSide = 4;               // Reduced to 4 to minimize exposure
input int    InpMaxOrderLifetimeSeconds = 5;
input bool   InpAutoRecycleStaleOrders = true;
input double InpMinOrderDistanceATR = 0.35;      // Wider offset to avoid fakeouts
input double InpGridStepATR = 0.5;               // Wider grid step

input group "═══ DYNAMIC RISK:REWARD ═══"
input bool   InpUseDynamicTargets = true;
input double InpMinRiskRewardRatio = 2.0;
input double InpScalpTargetMultiplier = 2.0;

input group "═══ LIQUIDITY & VOLATILITY ═══"
input bool   InpUseLiquidityFilter = true;
input int    InpVolumeLookback = 20;
input double InpMinVolumeRatio = 0.8;
input bool   InpUseVolatilityAdaptation = true;

input group "═══ RISK MANAGEMENT (MICRO-COMPATIBLE) ═══"
input double InpBaseLot = 0.01;
input double InpRiskPercent = 0.5;
input double InpMaxTotalLots = 3.0;
input double InpSLATRMult = 1.5;                 // Widened SL for Gold noise
input double InpTPATRMult = 3.0;                 // Widened TP for 1:2 RR minimum

input group "═══ EXECUTION & TIMER ═══"
input bool   InpUseTickDrivenMgmt = true;
input int    InpTradeDeviationPts = 10;
input int    InpTimerMs = 50;

input group "═══ POSITION MANAGEMENT ═══"
input bool   InpUseBreakeven = true;
input double InpBreakevenATR = 1.0;              // Moved BE further to secure profit
input double InpBreakevenBufferPts = 20;
input bool   InpUseTrailing = true;
input double InpTrailStartATR = 1.5;
input double InpTrailATR = 0.5;

input group "═══ CIRCUIT BREAKER ═══"
input double InpDailyProfitTarget = 50.0;
input double InpDailyLossLimit = 30.0;
input double InpMaxDrawdownPct = 8.0;
input int    InpRecoveryTimeoutSeconds = 600;

input group "═══ ANALYSIS ═══"
input ENUM_TIMEFRAMES InpAnalysisTF = PERIOD_M1;
input int    InpATRPeriod = 14;
input int    InpMaxSpreadPoints = 50;
input int    InpEMAPeriod = 20;

input group "═══ AURUM DASHBOARD ═══"
input bool   InpShowDashboard = true;
input int    InpDashboardWidthPx = 360;
input bool   InpAutoStyleChart = true;

input group "═══ TRADING SESSIONS ═══"
input bool   InpTradeAllSessions = true;
input bool   InpTradeSydneySession = true;
input int    InpSydneyStartHour = 21;
input int    InpSydneyEndHour = 6;
input bool   InpTradeTokyoSession = true;
input int    InpTokyoStartHour = 0;
input int    InpTokyoEndHour = 9;
input bool   InpTradeLondonSession = true;
input int    InpLondonStartHour = 7;
input int    InpLondonEndHour = 16;
input bool   InpTradeNewYorkSession = true;
input int    InpNewYorkStartHour = 12;
input int    InpNewYorkEndHour = 21;

//+------------------------------------------------------------------+
//| GLOBAL VARIABLES                                                 |
//+------------------------------------------------------------------+
CTrade trade;
int handleATR, handleEMA, handleRSI;
int magic = 770015;

double dayStartBalance = 0.0;
int lastDayChecked = -1;
double dailyProfit = 0.0;
double peakEquity = 0.0;
double grossProfit = 0.0, grossLoss = 0.0;
int totalWins = 0, totalLosses = 0;
double recentProfitFactor = 1.0;

// EA State (No Pause - Recovery Instead)
EAState currentEAState = STATE_ACTIVE;
datetime recoveryStartTime = 0;
bool profitTargetHit = false;
bool recoveryMode = false;
int recoveryQualityBoost = 10;

datetime lastTickManagement = 0;
datetime lastGridDeployTime = 0;
datetime lastFillTime = 0;
datetime lastBarTime = 0;

int symbolDigits = 0;
double symbolPoint = 0.0, pipSize = 0.0;

double cachedATR = 0.0;
datetime atrCacheTime = 0;
double cachedEMA = 0.0;
datetime emaCacheTime = 0;
double cachedRSI = 0.0;
datetime rsiCacheTime = 0;

// Ultra-Fast State Tracking (Millisecond Precision)
double lastTickPrice = 0;
ulong lastTickMs = 0;
double tickVelocity = 0;
double tickVelocityDirection = 0;
int momentumDirection = 0;
int currentQualityScore = 0;

// Linear Regression State
double lrSlope = 0;
double lrRSquared = 0;
double lrIntercept = 0;
double lrSlopeATRRatio = 0;

// Animation State
int animationFrame = 0;

//+------------------------------------------------------------------+
//| ULTRA-FAST INTELLIGENCE STATE                                    |
//+------------------------------------------------------------------+
struct LiquidityIntelligence {
   double avgVolume, currentVolume, volumeRatio;
   double momentum;
   MarketMomentum momentumState;
   double currentATR, avgATR, atrRatio;
   VolatilityRegime volRegime;
   double bidAskSpread;
   double dynamicTPMultiplier, dynamicSLMultiplier, recommendedRR;
   bool allowLongEntry, allowShortEntry;
   double lotSizeMultiplier;
   double rsiValue;
   double lrSlopeNormalized;
   datetime lastUpdate;
} LiqIntel;

//+------------------------------------------------------------------+
//| AURUM DASHBOARD STATE                                            |
//+------------------------------------------------------------------+
struct AurumState {
   int x, y, width, height;
   int buyOrders, sellOrders;
   int buyPositions, sellPositions;
   double totalFloat;
   string activeSignal;
   color  signalColor;
   string statusText;
   color  statusColor;
   string notificationText;
   color  notificationColor;
   bool   showNotification;
} Aurum;

//+------------------------------------------------------------------+
//| AURUM GLASSMORPHISM UI HELPERS                                   |
//+------------------------------------------------------------------+
void AxRect(string name, int x, int y, int w, int h, color bg, color border = clrNONE, int bw = 1) {
   string obj = AX_PREFIX + name;
   if(ObjectFind(0, obj) < 0) ObjectCreate(0, obj, OBJ_RECTANGLE_LABEL, 0, 0, 0);
   ObjectSetInteger(0, obj, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, obj, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, obj, OBJPROP_XSIZE, w);
   ObjectSetInteger(0, obj, OBJPROP_YSIZE, h);
   ObjectSetInteger(0, obj, OBJPROP_BGCOLOR, bg);
   ObjectSetInteger(0, obj, OBJPROP_BORDER_TYPE, BORDER_FLAT);
   ObjectSetInteger(0, obj, OBJPROP_COLOR, border == clrNONE ? bg : border);
   ObjectSetInteger(0, obj, OBJPROP_WIDTH, bw);
   ObjectSetInteger(0, obj, OBJPROP_BACK, false);
   ObjectSetInteger(0, obj, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, obj, OBJPROP_HIDDEN, true);
}

void AxText(string name, int x, int y, string text, color clr, int size = 9, string font = "Segoe UI", int anchor = ANCHOR_LEFT_UPPER) {
   string obj = AX_PREFIX + name;
   if(ObjectFind(0, obj) < 0) ObjectCreate(0, obj, OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, obj, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, obj, OBJPROP_YDISTANCE, y);
   ObjectSetString(0, obj, OBJPROP_TEXT, text);
   ObjectSetInteger(0, obj, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, obj, OBJPROP_FONTSIZE, size);
   ObjectSetString(0, obj, OBJPROP_FONT, font);
   ObjectSetInteger(0, obj, OBJPROP_ANCHOR, anchor);
   ObjectSetInteger(0, obj, OBJPROP_BACK, false);
   ObjectSetInteger(0, obj, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, obj, OBJPROP_HIDDEN, true);
}

// Glassmorphism Panel - Frosted Glass with Soft Shadow & Top Highlight
void AxGlassPanel(string name, int x, int y, int w, int h, color accent = clrNONE) {
   AxRect(name + "_SH1", x + 2, y + 3, w, h, C'2,3,8', clrNONE, 0);
   AxRect(name + "_SH2", x + 1, y + 2, w, h, C'3,5,12', clrNONE, 0);
   AxRect(name + "_BG", x, y, w, h, AX_BG_GLASS, AX_BORDER_GLOW, 1);
   AxRect(name + "_HL", x + 1, y + 1, w - 2, 1, C'55,75,130', clrNONE, 0);
   AxRect(name + "_BM", x + 1, y + h - 2, w - 2, 1, C'4,6,14', clrNONE, 0);
   if(accent != clrNONE) {
      AxRect(name + "_AC", x, y + 1, 2, h - 2, accent, clrNONE, 0);
   }
}

// Neumorphic Button - Soft 3D Press Effect
void AxNeumorphButton(string name, int x, int y, int w, int h, string text, color bg, color txt, int size = 9) {
   string obj = AX_PREFIX + name;
   AxRect(name + "_SHD", x + 1, y + 2, w, h, C'2,3,8', clrNONE, 0);
   AxRect(name + "_HLT", x - 1, y - 1, w, h, C'30,42,75', clrNONE, 0);
   if(ObjectFind(0, obj) < 0) ObjectCreate(0, obj, OBJ_BUTTON, 0, 0, 0);
   ObjectSetInteger(0, obj, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, obj, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, obj, OBJPROP_XSIZE, w);
   ObjectSetInteger(0, obj, OBJPROP_YSIZE, h);
   ObjectSetString(0, obj, OBJPROP_TEXT, text);
   ObjectSetInteger(0, obj, OBJPROP_BGCOLOR, bg);
   ObjectSetInteger(0, obj, OBJPROP_COLOR, AX_BORDER_HI);
   ObjectSetInteger(0, obj, OBJPROP_FONTSIZE, size);
   ObjectSetString(0, obj, OBJPROP_FONT, "Segoe UI Semibold");
   ObjectSetInteger(0, obj, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, obj, OBJPROP_HIDDEN, true);
   ObjectSetInteger(0, obj, OBJPROP_STATE, false);
}

// Animated LED - Pulses on timer
void AxLED(string name, int x, int y, int sz, color baseColor, bool active) {
   bool pulse = active && (animationFrame % 4 < 2);
   color ledColor = pulse ? baseColor : AX_GOLD_DIM;
   if(!active) ledColor = C'40,45,60';
   AxRect(name + "_GLW", x - 2, y - 2, sz + 4, sz + 4, C'8,10,20', clrNONE, 0);
   AxRect(name, x, y, sz, sz, ledColor, ledColor, 0);
   if(active && pulse) {
      AxRect(name + "_IN", x + 1, y + 1, sz - 2, sz - 2, C'255,255,255', clrNONE, 0);
   }
}

//+------------------------------------------------------------------+
//| INDICATOR ACCESS (CACHED)                                        |
//+------------------------------------------------------------------+
double GetCurrentATR() {
   datetime now = TimeCurrent();
   if(now == atrCacheTime && cachedATR > 0) return cachedATR;
   double atrBuffer[];
   ArraySetAsSeries(atrBuffer, true);
   if(CopyBuffer(handleATR, 0, 0, 1, atrBuffer) > 0) {
      cachedATR = atrBuffer[0];
      atrCacheTime = now;
      return cachedATR;
   }
   return cachedATR > 0 ? cachedATR : 0.0001;
}

double GetCurrentEMA() {
   datetime now = TimeCurrent();
   if(now == emaCacheTime && cachedEMA > 0) return cachedEMA;
   double emaBuffer[];
   ArraySetAsSeries(emaBuffer, true);
   if(CopyBuffer(handleEMA, 0, 0, 1, emaBuffer) > 0) {
      cachedEMA = emaBuffer[0];
      emaCacheTime = now;
      return cachedEMA;
   }
   return cachedEMA;
}

double GetCurrentRSI() {
   datetime now = TimeCurrent();
   if(now == rsiCacheTime && cachedRSI > 0) return cachedRSI;
   double rsiBuffer[];
   ArraySetAsSeries(rsiBuffer, true);
   if(CopyBuffer(handleRSI, 0, 0, 1, rsiBuffer) > 0) {
      cachedRSI = rsiBuffer[0];
      rsiCacheTime = now;
      return cachedRSI;
   }
   return cachedRSI;
}

//+------------------------------------------------------------------+
//| LINEAR REGRESSION ANALYSIS                                       |
//+------------------------------------------------------------------+
void CalculateLinearRegression(int period) {
   double closeArray[];
   ArraySetAsSeries(closeArray, true);
   if(CopyClose(_Symbol, InpAnalysisTF, 0, period, closeArray) < period) {
      lrSlope = 0; lrRSquared = 0; lrIntercept = 0;
      return;
   }
   double n = (double)period;
   double sumX = 0, sumY = 0, sumXY = 0, sumX2 = 0, sumY2 = 0;
   for(int i = 0; i < period; i++) {
      double x = (double)i;
      double y = closeArray[i];
      sumX += x; sumY += y; sumXY += x * y; sumX2 += x * x; sumY2 += y * y;
   }
   double denom = n * sumX2 - sumX * sumX;
   if(denom == 0) { lrSlope = 0; lrRSquared = 0; lrIntercept = 0; return; }
   lrSlope = (n * sumXY - sumX * sumY) / denom;
   lrIntercept = (sumY - lrSlope * sumX) / n;
   double denomR = (n * sumX2 - sumX * sumX) * (n * sumY2 - sumY * sumY);
   if(denomR <= 0) { lrRSquared = 0; return; }
   double r = (n * sumXY - sumX * sumY) / MathSqrt(denomR);
   lrRSquared = r * r;
   
   double atr = GetCurrentATR();
   lrSlopeATRRatio = (atr > 0) ? MathAbs(lrSlope) / atr : 0;
   LiqIntel.lrSlopeNormalized = lrSlope / pipSize;
}

//+------------------------------------------------------------------+
//| ULTRA-FAST TICK VELOCITY                                         |
//+------------------------------------------------------------------+
void CalculateUltraFastTickVelocity() {
   MqlTick tick;
   if(!SymbolInfoTick(_Symbol, tick)) return;
   double currentPrice = tick.bid;
   ulong currentMs = GetTickCount64();
   if(lastTickPrice > 0 && lastTickMs > 0 && currentMs > lastTickMs) {
      double elapsed = (double)(currentMs - lastTickMs) / 1000.0;
      if(elapsed > 0) {
         double diff = (currentPrice - lastTickPrice) / pipSize;
         double instantVelocity = MathAbs(diff) / elapsed;
         // Heavy smoothing (0.7/0.3) to avoid single-tick spikes triggering entries
         tickVelocity = (tickVelocity * 0.7) + (instantVelocity * 0.3);
         tickVelocityDirection = diff / elapsed;
      }
   }
   lastTickPrice = currentPrice;
   lastTickMs = currentMs;
}

//+------------------------------------------------------------------+
//| MICRO MOMENTUM (Last N Candles)                                  |
//+------------------------------------------------------------------+
double CalculateMicroMomentum(int bars) {
   double closeArray[];
   ArraySetAsSeries(closeArray, true);
   if(CopyClose(_Symbol, InpAnalysisTF, 0, bars + 1, closeArray) <= bars) return 0;
   double change = (closeArray[0] - closeArray[bars]) / closeArray[bars] * 100.0;
   return change;
}

VolatilityRegime ClassifyVolatilityRegime(double currentATR, double avgATR) {
   if(avgATR <= 0) return VOL_NORMAL;
   double ratio = currentATR / avgATR;
   if(ratio < 0.3) return VOL_DORMANT;
   else if(ratio < 0.7) return VOL_LOW;
   else if(ratio < 1.3) return VOL_NORMAL;
   else if(ratio < 2.0) return VOL_HIGH;
   else return VOL_EXTREME;
}

MarketMomentum ClassifyMomentum(double momentum) {
   if(momentum > 0.15) return MOM_STRONG_BULL;
   else if(momentum > 0.05) return MOM_WEAK_BULL;
   else if(momentum < -0.15) return MOM_STRONG_BEAR;
   else if(momentum < -0.05) return MOM_WEAK_BEAR;
   else return MOM_NEUTRAL;
}

//+------------------------------------------------------------------+
//| ULTRA-FAST LIQUIDITY INTELLIGENCE UPDATE                         |
//+------------------------------------------------------------------+
void UpdateLiquidityIntelligence() {
   CalculateUltraFastTickVelocity();
   CalculateLinearRegression(InpLinearRegPeriod);
   
   LiqIntel.avgVolume = 0;
   long volArray[];
   ArraySetAsSeries(volArray, true);
   if(CopyTickVolume(_Symbol, InpAnalysisTF, 0, InpVolumeLookback + 1, volArray) > 0) {
      for(int i = 1; i <= InpVolumeLookback; i++) LiqIntel.avgVolume += (double)volArray[i];
      LiqIntel.avgVolume /= InpVolumeLookback;
      LiqIntel.currentVolume = (double)volArray[1];
   }
   LiqIntel.volumeRatio = (LiqIntel.avgVolume > 0) ? LiqIntel.currentVolume / LiqIntel.avgVolume : 1.0;
   
   LiqIntel.momentum = CalculateMicroMomentum(InpMicroMomentumBars);
   LiqIntel.momentumState = ClassifyMomentum(LiqIntel.momentum);
   LiqIntel.rsiValue = GetCurrentRSI();
   
   LiqIntel.currentATR = GetCurrentATR();
   double atrArray[];
   ArraySetAsSeries(atrArray, true);
   if(CopyBuffer(handleATR, 0, 0, InpATRPeriod * 2, atrArray) > 0) {
      double sum = 0;
      for(int i = 0; i < InpATRPeriod * 2; i++) sum += atrArray[i];
      LiqIntel.avgATR = sum / (InpATRPeriod * 2);
   }
   LiqIntel.atrRatio = (LiqIntel.avgATR > 0) ? LiqIntel.currentATR / LiqIntel.avgATR : 1.0;
   LiqIntel.volRegime = ClassifyVolatilityRegime(LiqIntel.currentATR, LiqIntel.avgATR);
   
   MqlTick tick;
   SymbolInfoTick(_Symbol, tick);
   LiqIntel.bidAskSpread = (tick.ask - tick.bid) / symbolPoint;
   
   LiqIntel.dynamicTPMultiplier = InpTPATRMult;
   LiqIntel.dynamicSLMultiplier = InpSLATRMult;
   if(InpUseVolatilityAdaptation) {
      switch(LiqIntel.volRegime) {
         case VOL_DORMANT:  LiqIntel.dynamicTPMultiplier *= 0.6; break;
         case VOL_LOW:      LiqIntel.dynamicTPMultiplier *= 0.8; break;
         case VOL_HIGH:     LiqIntel.dynamicTPMultiplier *= 1.3; break;
         case VOL_EXTREME:  LiqIntel.dynamicTPMultiplier *= 1.5; LiqIntel.dynamicSLMultiplier *= 1.2; break;
      }
   }
   if(LiqIntel.momentumState == MOM_STRONG_BULL || LiqIntel.momentumState == MOM_STRONG_BEAR)
      LiqIntel.dynamicTPMultiplier *= 1.2;
   
   LiqIntel.recommendedRR = LiqIntel.dynamicTPMultiplier / LiqIntel.dynamicSLMultiplier;
   if(LiqIntel.recommendedRR < InpMinRiskRewardRatio) {
      LiqIntel.dynamicTPMultiplier = InpMinRiskRewardRatio * LiqIntel.dynamicSLMultiplier;
      LiqIntel.recommendedRR = InpMinRiskRewardRatio;
   }
   
   currentQualityScore = 0;
   momentumDirection = 0;
   
   if(InpUseUltraFastMomentum) {
      double ema = GetCurrentEMA();
      MqlTick tk;
      SymbolInfoTick(_Symbol, tk);
      
      if(lrSlopeATRRatio >= InpMinSlopeATRRatio) {
         double slopeScore = MathMin(30.0, (lrSlopeATRRatio / (InpMinSlopeATRRatio * 3.0)) * 30.0);
         currentQualityScore += (int)slopeScore;
      }
      currentQualityScore += (int)(lrRSquared * 15.0);
      
      double absMom = MathAbs(LiqIntel.momentum);
      if(absMom > 0.01) currentQualityScore += 10;
      if(absMom > 0.03) currentQualityScore += 5;
      if(absMom > 0.05) currentQualityScore += 5;
      
      if(tickVelocity >= InpTickVelocityThreshold) currentQualityScore += 15;
      else if(tickVelocity > 0) currentQualityScore += (int)(15.0 * (tickVelocity / InpTickVelocityThreshold));
      
      if(LiqIntel.volumeRatio >= 1.0) currentQualityScore += 10;
      else if(LiqIntel.volumeRatio > 0.5) currentQualityScore += (int)(10.0 * LiqIntel.volumeRatio);
      
      if(LiqIntel.bidAskSpread <= InpMaxSpreadPoints * 0.5) currentQualityScore += 5;
      else if(LiqIntel.bidAskSpread <= InpMaxSpreadPoints) currentQualityScore += 3;
      
      if(lrSlope > 0 && LiqIntel.rsiValue > 50) currentQualityScore += 5;
      else if(lrSlope < 0 && LiqIntel.rsiValue < 50) currentQualityScore += 5;
      
      int bullVotes = 0, bearVotes = 0;
      if(lrSlope > 0) bullVotes += 3; else if(lrSlope < 0) bearVotes += 3;
      if(LiqIntel.momentum > 0) bullVotes += 2; else if(LiqIntel.momentum < 0) bearVotes += 2;
      if(LiqIntel.rsiValue > 50) bullVotes += 1; else if(LiqIntel.rsiValue < 50) bearVotes += 1;
      if(tickVelocityDirection > 0) bullVotes += 1; else if(tickVelocityDirection < 0) bearVotes += 1;
      if(tk.bid >= ema) bullVotes += 1; else bearVotes += 1;
      
      if(bullVotes > bearVotes + 1) momentumDirection = 1;
      else if(bearVotes > bullVotes + 1) momentumDirection = -1;
      else if(bullVotes > bearVotes) momentumDirection = 1;
      else if(bearVotes > bullVotes) momentumDirection = -1;
      else momentumDirection = 0; // Strict neutral if no consensus
   } else {
      currentQualityScore = 100;
      momentumDirection = 0;
   }
   
   LiqIntel.allowLongEntry = (momentumDirection >= 0);
   LiqIntel.allowShortEntry = (momentumDirection <= 0);
   LiqIntel.lotSizeMultiplier = (LiqIntel.volRegime == VOL_EXTREME) ? 0.7 : 1.0;
   LiqIntel.lastUpdate = TimeCurrent();
}

//+------------------------------------------------------------------+
//| SESSION FILTER                                                   |
//+------------------------------------------------------------------+
bool IsSessionActive(int startH, int endH) {
   MqlDateTime tm;
   TimeToStruct(TimeCurrent(), tm);
   int h = tm.hour;
   if(startH == endH) return true;
   if(startH < endH) return (h >= startH && h < endH);
   else return (h >= startH || h < endH);
}

bool IsTradingSessionAllowed() {
   if(InpTradeAllSessions) return true;
   bool sydneyOK = InpTradeSydneySession && IsSessionActive(InpSydneyStartHour, InpSydneyEndHour);
   bool tokyoOK = InpTradeTokyoSession && IsSessionActive(InpTokyoStartHour, InpTokyoEndHour);
   bool londonOK = InpTradeLondonSession && IsSessionActive(InpLondonStartHour, InpLondonEndHour);
   bool newyorkOK = InpTradeNewYorkSession && IsSessionActive(InpNewYorkStartHour, InpNewYorkEndHour);
   return (sydneyOK || tokyoOK || londonOK || newyorkOK);
}

//+------------------------------------------------------------------+
//| INITIALIZATION                                                   |
//+------------------------------------------------------------------+
int OnInit() {
   if(InpRiskPercent > 10.0 || InpOrdersPerSide < 1 || InpMinRiskRewardRatio < 1.0)
      return INIT_PARAMETERS_INCORRECT;
   
   symbolDigits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   symbolPoint = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   pipSize = (StringFind(_Symbol, "JPY") >= 0) ? 0.01 : (symbolDigits == 3 || symbolDigits == 2) ? 0.01 : 0.0001;
   
   trade.SetExpertMagicNumber(magic);
   trade.SetDeviationInPoints(InpTradeDeviationPts);
   trade.SetTypeFillingBySymbol(_Symbol);
   
   handleATR = iATR(_Symbol, InpAnalysisTF, InpATRPeriod);
   handleEMA = iMA(_Symbol, InpAnalysisTF, InpEMAPeriod, 0, MODE_EMA, PRICE_CLOSE);
   handleRSI = iRSI(_Symbol, InpAnalysisTF, InpRSIPeriod, PRICE_CLOSE);
   if(handleATR == INVALID_HANDLE || handleEMA == INVALID_HANDLE || handleRSI == INVALID_HANDLE)
      return INIT_FAILED;
   
   EventSetMillisecondTimer(InpTimerMs);
   peakEquity = AccountInfoDouble(ACCOUNT_EQUITY);
   dayStartBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   MqlDateTime tm;
   TimeToStruct(TimeCurrent(), tm);
   lastDayChecked = tm.day;
   
   ZeroMemory(LiqIntel);
   UpdateLiquidityIntelligence();
   
   if(InpAutoStyleChart) SetupChartAppearance();
   if(InpShowDashboard) InitDashboard();
   
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason) {
   EventKillTimer();
   IndicatorRelease(handleATR);
   IndicatorRelease(handleEMA);
   IndicatorRelease(handleRSI);
   if(InpShowDashboard) ObjectsDeleteAll(0, AX_PREFIX);
}

void SetupChartAppearance() {
   long chartId = ChartID();
   ChartSetInteger(chartId, CHART_COLOR_BACKGROUND, C'6,8,16');
   ChartSetInteger(chartId, CHART_COLOR_FOREGROUND, AX_TEXT_PLATINUM);
   ChartSetInteger(chartId, CHART_SHOW_GRID, false);
   ChartSetInteger(chartId, CHART_MODE, CHART_CANDLES);
   ChartSetInteger(chartId, CHART_COLOR_CANDLE_BULL, C'0,200,140');
   ChartSetInteger(chartId, CHART_COLOR_CANDLE_BEAR, C'220,60,90');
   ChartSetInteger(chartId, CHART_SHOW_BID_LINE, false);
   ChartSetInteger(chartId, CHART_SHOW_ASK_LINE, false);
   ChartRedraw(chartId);
}

//+------------------------------------------------------------------+
//| AURUM DASHBOARD - GLASSMORPHISM PREMIUM LAYOUT                   |
//+------------------------------------------------------------------+
void InitDashboard() {
   Aurum.x = 15;
   Aurum.y = 15;
   Aurum.width = InpDashboardWidthPx;
   Aurum.height = 600;
   Aurum.showNotification = false;
   Aurum.notificationText = "";
}

void AnalyzeLiveOrders() {
   Aurum.buyOrders = 0; Aurum.sellOrders = 0;
   Aurum.buyPositions = 0; Aurum.sellPositions = 0;
   Aurum.totalFloat = 0.0;
   
   for(int i = 0; i < OrdersTotal(); i++) {
      ulong ticket = OrderGetTicket(i);
      if(ticket == 0 || !OrderSelect(ticket)) continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol || OrderGetInteger(ORDER_MAGIC) != magic) continue;
      ENUM_ORDER_TYPE otype = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
      if(otype == ORDER_TYPE_BUY_STOP || otype == ORDER_TYPE_BUY_LIMIT) Aurum.buyOrders++;
      else if(otype == ORDER_TYPE_SELL_STOP || otype == ORDER_TYPE_SELL_LIMIT) Aurum.sellOrders++;
   }
   
   for(int i = 0; i < PositionsTotal(); i++) {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket)) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol || PositionGetInteger(POSITION_MAGIC) != magic) continue;
      ENUM_POSITION_TYPE ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      if(ptype == POSITION_TYPE_BUY) Aurum.buyPositions++;
      else Aurum.sellPositions++;
      Aurum.totalFloat += PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP) + PositionGetDouble(POSITION_COMMISSION);
   }
   
   if(profitTargetHit) {
      currentEAState = STATE_TARGET_HIT;
      Aurum.statusText = "TARGET HIT";
      Aurum.statusColor = AX_GOLD;
   } else if(recoveryMode) {
      currentEAState = STATE_RECOVERY;
      Aurum.statusText = "RECOVERY";
      Aurum.statusColor = AX_ORANGE;
   } else {
      currentEAState = STATE_ACTIVE;
      Aurum.statusText = "ACTIVE";
      Aurum.statusColor = AX_EMERALD;
   }
   
   if(profitTargetHit) {
      Aurum.activeSignal = "TRADING STOPPED";
      Aurum.signalColor = AX_GOLD;
      Aurum.notificationText = "◆ DAILY PROFIT TARGET ACHIEVED — TRADING STOPPED";
      Aurum.notificationColor = AX_GOLD;
      Aurum.showNotification = true;
   } else if(recoveryMode) {
      Aurum.activeSignal = "RECOVERY SCAN";
      Aurum.signalColor = AX_ORANGE;
      Aurum.notificationText = "◆ RECOVERY MODE — SCANNING FOR CLEAR TREND ENTRY";
      Aurum.notificationColor = AX_ORANGE;
      Aurum.showNotification = true;
   } else if(!IsTradingSessionAllowed()) {
      Aurum.activeSignal = "OUT OF SESSION";
      Aurum.signalColor = AX_TEXT_ASH;
      Aurum.showNotification = false;
   } else if(Aurum.buyPositions > 0 && Aurum.sellPositions > 0) {
      Aurum.activeSignal = "HEDGED POSITION";
      Aurum.signalColor = AX_VIOLET;
      Aurum.showNotification = false;
   } else if(Aurum.buyPositions > 0 && Aurum.sellPositions == 0) {
      Aurum.activeSignal = "LONG EXECUTED";
      Aurum.signalColor = AX_TEAL;
      Aurum.showNotification = false;
   } else if(Aurum.sellPositions > 0 && Aurum.buyPositions == 0) {
      Aurum.activeSignal = "SHORT EXECUTED";
      Aurum.signalColor = AX_CORAL;
      Aurum.showNotification = false;
   } else if(Aurum.buyOrders > 0 && Aurum.sellOrders > 0) {
      Aurum.activeSignal = "GRID DEPLOYED";
      Aurum.signalColor = AX_AMBER;
      Aurum.showNotification = false;
   } else if(Aurum.buyOrders > 0 && Aurum.sellOrders == 0) {
      Aurum.activeSignal = "BUY GRID ARMED";
      Aurum.signalColor = AX_TEAL;
      Aurum.showNotification = false;
   } else if(Aurum.sellOrders > 0 && Aurum.buyOrders == 0) {
      Aurum.activeSignal = "SELL GRID ARMED";
      Aurum.signalColor = AX_CORAL;
      Aurum.showNotification = false;
   } else if(currentQualityScore >= InpMinQualityScore) {
      Aurum.activeSignal = "READY TO DEPLOY";
      Aurum.signalColor = AX_EMERALD;
      Aurum.showNotification = false;
   } else {
      Aurum.activeSignal = "SCANNING MOMENTUM";
      Aurum.signalColor = AX_AMBER;
      Aurum.showNotification = false;
   }
}

void DrawDashboard() {
   if(!InpShowDashboard) return;
   AnalyzeLiveOrders();
   
   int x = Aurum.x, y = Aurum.y, w = Aurum.width;
   int pad = 10, innerW = w - 2 * pad;
   
   AxRect("BG_BASE", x - 2, y - 2, w + 4, Aurum.height + 4, C'2,3,8', clrNONE, 0);
   AxRect("BG_MAIN", x, y, w, Aurum.height, AX_BG_VOID, AX_BORDER_HI, 1);
   AxRect("BG_GOLD", x, y, 3, Aurum.height, AX_GOLD, clrNONE, 0);
   
   int hdrH = 46;
   AxGlassPanel("HDR", x + 4, y + 4, w - 8, hdrH, Aurum.statusColor);
   AxText("HDR_STA_LBL", x + 14, y + 10, "STATUS", AX_TEXT_ASH, 6, "Segoe UI");
   AxText("HDR_STA_VAL", x + 14, y + 20, Aurum.statusText, Aurum.statusColor, 10, "Segoe UI Semibold");
   AxLED("HDR_STA_LED", x + 14, y + 35, 6, Aurum.statusColor, true);
   
   AxText("HDR_TITLE", x + w/2, y + 10, "AURUM X PRIME", AX_GOLD, 13, "Segoe UI Semibold", ANCHOR_TOP);
   AxText("HDR_SUB", x + w/2, y + 28, "GOLD M1 QUANTUM ENGINE v5.1", AX_TEXT_SILVER, 6, "Segoe UI", ANCHOR_TOP);
   
   AxText("HDR_SIG_LBL", x + w - 60, y + 10, "SIGNAL", AX_TEXT_ASH, 6, "Segoe UI", ANCHOR_RIGHT);
   AxText("HDR_SIG_VAL", x + w - 14, y + 20, "LIVE", Aurum.signalColor, 10, "Segoe UI Semibold", ANCHOR_RIGHT);
   AxLED("HDR_SIG_LED", x + w - 20, y + 35, 6, Aurum.signalColor, (Aurum.buyOrders > 0 || Aurum.sellOrders > 0));
   y += hdrH + 10;
   
   AxText("CTRL_LBL", x + pad, y, "CONTROL PANEL", AX_TEXT_SILVER, 7, "Segoe UI Semibold");
   AxRect("CTRL_LN", x + pad + 95, y + 5, innerW - 95, 1, AX_DIV, clrNONE, 0);
   y += 12;
   
   int btnH = 32, btnGap = 5;
   int btnW = (innerW - btnGap * 2) / 3;
   
   AxNeumorphButton("BTN_PROFIT", x + pad, y, btnW, btnH, "✓ PROFIT", AX_EMERALD, AX_BG_VOID, 8);
   AxNeumorphButton("BTN_LOSS", x + pad + btnW + btnGap, y, btnW, btnH, "✗ LOSS", AX_CORAL, AX_BG_VOID, 8);
   AxNeumorphButton("BTN_RESET", x + pad + (btnW + btnGap) * 2, y, btnW, btnH, "↻ RESET", AX_LIME, AX_BG_VOID, 8);
   y += btnH + 10;
   
   AxText("MOM_LBL", x + pad, y, "MOMENTUM QUALITY", AX_TEXT_SILVER, 7, "Segoe UI Semibold");
   AxRect("MOM_LN", x + pad + 115, y + 5, innerW - 115, 1, AX_DIV, clrNONE, 0);
   y += 12;
   
   int momThreshold = recoveryMode ? InpMinQualityScore + recoveryQualityBoost : InpMinQualityScore;
   color momClr = (currentQualityScore >= momThreshold) ? AX_EMERALD : 
                  (currentQualityScore >= 50) ? AX_AMBER : AX_CORAL;
   
   AxGlassPanel("MOM", x + pad, y, innerW, 60, momClr);
   AxText("MOM_SCORE", x + pad + 12, y + 8, IntegerToString(currentQualityScore) + "/100", momClr, 16, "Segoe UI Semibold");
   AxText("MOM_THRESH", x + pad + 12, y + 30, "Min: " + IntegerToString(momThreshold), AX_TEXT_ASH, 7, "Segoe UI");
   
   string dirText = (momentumDirection == 1) ? "▲ BULLISH" : 
                    (momentumDirection == -1) ? "▼ BEARISH" : "◆ NEUTRAL";
   color dirClr = (momentumDirection == 1) ? AX_TEAL : 
                  (momentumDirection == -1) ? AX_CORAL : AX_TEXT_SILVER;
   AxText("MOM_DIR", x + pad + innerW - 12, y + 8, dirText, dirClr, 10, "Segoe UI Semibold", ANCHOR_RIGHT);
   AxText("MOM_VEL", x + pad + innerW - 12, y + 24, "VEL: " + DoubleToString(tickVelocity, 2) + " p/s", AX_TEXT_SILVER, 7, "Segoe UI", ANCHOR_RIGHT);
   AxText("MOM_LR", x + pad + innerW - 12, y + 36, "LR R²: " + DoubleToString(lrRSquared, 2), AX_TEXT_SILVER, 7, "Segoe UI", ANCHOR_RIGHT);
   
   int barMaxW = innerW - 24;
   int barW = (int)((double)barMaxW * currentQualityScore / 100.0);
   AxRect("MOM_BAR_BG", x + pad + 12, y + 50, barMaxW, 4, AX_BG_INSET, AX_BORDER_DIM, 0);
   AxRect("MOM_BAR", x + pad + 12, y + 50, barW, 4, momClr, momClr, 0);
   if(barW > 4) AxRect("MOM_BAR_TIP", x + pad + 12 + barW - 3, y + 49, 3, 6, C'255,255,255', clrNONE, 0);
   y += 72;
   
   AxText("EXE_LBL", x + pad, y, "LIVE EXECUTION", AX_TEXT_SILVER, 7, "Segoe UI Semibold");
   AxRect("EXE_LN", x + pad + 100, y + 5, innerW - 100, 1, AX_DIV, clrNONE, 0);
   y += 12;
   
   int exeH = 60;
   AxGlassPanel("EXE", x + pad, y, innerW, exeH, Aurum.signalColor);
   
   int col1X = x + pad + 14, col2X = x + pad + innerW/2 + 10;
   AxText("BUY_LBL", col1X, y + 8, "▲ BUY SIDE", AX_TEAL, 7, "Segoe UI Semibold");
   AxText("BUY_ORD", col1X + 90, y + 8, IntegerToString(Aurum.buyOrders) + " ord", AX_TEAL, 9, "Segoe UI Semibold");
   AxText("BUY_POS", col1X + 90, y + 24, IntegerToString(Aurum.buyPositions) + " pos", AX_TEAL, 9, "Segoe UI Semibold");
   AxText("BUY_ORD_LBL", col1X, y + 24, "Pending", AX_TEXT_ASH, 6, "Segoe UI");
   AxText("BUY_POS_LBL", col1X, y + 40, "Filled", AX_TEXT_ASH, 6, "Segoe UI");
   
   AxRect("EXE_DIV", x + pad + innerW/2, y + 8, 1, exeH - 16, AX_BORDER_HI, clrNONE, 0);
   
   AxText("SELL_LBL", col2X, y + 8, "▼ SELL SIDE", AX_CORAL, 7, "Segoe UI Semibold");
   AxText("SELL_ORD", col2X + 90, y + 8, IntegerToString(Aurum.sellOrders) + " ord", AX_CORAL, 9, "Segoe UI Semibold");
   AxText("SELL_POS", col2X + 90, y + 24, IntegerToString(Aurum.sellPositions) + " pos", AX_CORAL, 9, "Segoe UI Semibold");
   AxText("SELL_ORD_LBL", col2X, y + 24, "Pending", AX_TEXT_ASH, 6, "Segoe UI");
   AxText("SELL_POS_LBL", col2X, y + 40, "Filled", AX_TEXT_ASH, 6, "Segoe UI");
   y += exeH + 10;
   
   color floatClr = (Aurum.totalFloat >= 0) ? AX_EMERALD : AX_CORAL;
   string floatStr = (Aurum.totalFloat >= 0 ? "+" : "") + DoubleToString(Aurum.totalFloat, 2);
   AxGlassPanel("FLT", x + pad, y, innerW, 34, floatClr);
   AxText("FLT_LBL", x + pad + 14, y + 6, "FLOATING P&L", AX_TEXT_ASH, 6, "Segoe UI");
   AxText("FLT_VAL", x + pad + 14, y + 15, "$" + floatStr, floatClr, 13, "Segoe UI Semibold");
   
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   if(equity < 50.0) {
      AxText("FLT_MICRO", x + pad + innerW - 14, y + 10, "MICRO", AX_VIOLET, 7, "Segoe UI Semibold", ANCHOR_RIGHT);
      AxText("FLT_MICRO2", x + pad + innerW - 14, y + 22, "ACCOUNT", AX_TEXT_ASH, 6, "Segoe UI", ANCHOR_RIGHT);
   }
   y += 44;
   
   MqlTick tick; SymbolInfoTick(_Symbol, tick);
   int spread = (int)MathRound((tick.ask - tick.bid) / symbolPoint);
   color sprClr = (spread <= InpMaxSpreadPoints) ? AX_EMERALD : AX_CORAL;
   double atr = GetCurrentATR();
   
   AxText("MKT_LBL", x + pad, y, "MARKET INTELLIGENCE", AX_TEXT_SILVER, 7, "Segoe UI Semibold");
   AxRect("MKT_LN", x + pad + 135, y + 5, innerW - 135, 1, AX_DIV, clrNONE, 0);
   y += 12;
   
   int cellH = 38, gap = 5, cellW = (innerW - gap) / 2;
   
   AxGlassPanel("MKT_BID", x + pad, y, cellW, cellH, AX_TEAL);
   AxText("MKT_BID_L", x + pad + 12, y + 6, "BID", AX_TEXT_ASH, 6, "Segoe UI");
   AxText("MKT_BID_V", x + pad + 12, y + 16, DoubleToString(tick.bid, symbolDigits), AX_TEAL, 10, "Segoe UI Semibold");
   
   AxGlassPanel("MKT_ASK", x + pad + cellW + gap, y, cellW, cellH, AX_CORAL);
   AxText("MKT_ASK_L", x + pad + cellW + gap + 12, y + 6, "ASK", AX_TEXT_ASH, 6, "Segoe UI");
   AxText("MKT_ASK_V", x + pad + cellW + gap + 12, y + 16, DoubleToString(tick.ask, symbolDigits), AX_CORAL, 10, "Segoe UI Semibold");
   y += cellH + gap;
   
   AxGlassPanel("MKT_SPR", x + pad, y, cellW, cellH, sprClr);
   AxText("MKT_SPR_L", x + pad + 12, y + 6, "SPREAD", AX_TEXT_ASH, 6, "Segoe UI");
   AxText("MKT_SPR_V", x + pad + 12, y + 16, IntegerToString(spread) + " pts", sprClr, 10, "Segoe UI Semibold");
   
   AxGlassPanel("MKT_ATR", x + pad + cellW + gap, y, cellW, cellH, AX_AMBER);
   AxText("MKT_ATR_L", x + pad + cellW + gap + 12, y + 6, "ATR (M1)", AX_TEXT_ASH, 6, "Segoe UI");
   AxText("MKT_ATR_V", x + pad + cellW + gap + 12, y + 16, DoubleToString(atr / pipSize, 1) + " p", AX_AMBER, 10, "Segoe UI Semibold");
   y += cellH + 10;
   
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   color eqClr = (equity >= balance) ? AX_EMERALD : AX_CORAL;
   color dayClr = (dailyProfit >= 0) ? AX_EMERALD : AX_CORAL;
   string dayStr = (dailyProfit >= 0 ? "+" : "") + DoubleToString(dailyProfit, 2);
   double winRate = (totalWins + totalLosses > 0) ? totalWins * 100.0 / (totalWins + totalLosses) : 0.0;
   color wrClr = (winRate >= 50) ? AX_EMERALD : AX_AMBER;
   
   AxText("ACC_LBL", x + pad, y, "ACCOUNT STATISTICS", AX_TEXT_SILVER, 7, "Segoe UI Semibold");
   AxRect("ACC_LN", x + pad + 125, y + 5, innerW - 125, 1, AX_DIV, clrNONE, 0);
   y += 12;
   
   AxGlassPanel("ACC_BAL", x + pad, y, cellW, cellH, AX_ICE);
   AxText("ACC_BAL_L", x + pad + 12, y + 6, "BALANCE", AX_TEXT_ASH, 6, "Segoe UI");
   AxText("ACC_BAL_V", x + pad + 12, y + 16, "$" + DoubleToString(balance, 2), AX_TEXT_PLATINUM, 10, "Segoe UI Semibold");
   
   AxGlassPanel("ACC_EQ", x + pad + cellW + gap, y, cellW, cellH, eqClr);
   AxText("ACC_EQ_L", x + pad + cellW + gap + 12, y + 6, "EQUITY", AX_TEXT_ASH, 6, "Segoe UI");
   AxText("ACC_EQ_V", x + pad + cellW + gap + 12, y + 16, "$" + DoubleToString(equity, 2), eqClr, 10, "Segoe UI Semibold");
   y += cellH + gap;
   
   AxGlassPanel("ACC_DAY", x + pad, y, cellW, cellH, dayClr);
   AxText("ACC_DAY_L", x + pad + 12, y + 6, "DAY P&L", AX_TEXT_ASH, 6, "Segoe UI");
   AxText("ACC_DAY_V", x + pad + 12, y + 16, "$" + dayStr, dayClr, 10, "Segoe UI Semibold");
   
   AxGlassPanel("ACC_WR", x + pad + cellW + gap, y, cellW, cellH, wrClr);
   AxText("ACC_WR_L", x + pad + cellW + gap + 12, y + 6, "WIN RATE", AX_TEXT_ASH, 6, "Segoe UI");
   AxText("ACC_WR_V", x + pad + cellW + gap + 12, y + 16, DoubleToString(winRate, 0) + "% (" + IntegerToString(totalWins + totalLosses) + ")", wrClr, 9, "Segoe UI Semibold");
   y += cellH + 10;
   
   double slDist = LiqIntel.dynamicSLMultiplier * atr;
   double tpDist = LiqIntel.dynamicTPMultiplier * atr;
   double lot = CalculateLotSize(slDist);
   color rrClr = (LiqIntel.recommendedRR >= InpMinRiskRewardRatio) ? AX_EMERALD : AX_AMBER;
   
   AxText("RSK_LBL", x + pad, y, "RISK PARAMETERS", AX_TEXT_SILVER, 7, "Segoe UI Semibold");
   AxRect("RSK_LN", x + pad + 115, y + 5, innerW - 115, 1, AX_DIV, clrNONE, 0);
   y += 12;
   
   AxGlassPanel("RSK_SL", x + pad, y, cellW, cellH, AX_CORAL);
   AxText("RSK_SL_L", x + pad + 12, y + 6, "STOP LOSS", AX_TEXT_ASH, 6, "Segoe UI");
   AxText("RSK_SL_V", x + pad + 12, y + 16, DoubleToString(slDist / pipSize, 1) + " p", AX_CORAL, 10, "Segoe UI Semibold");
   
   AxGlassPanel("RSK_TP", x + pad + cellW + gap, y, cellW, cellH, AX_EMERALD);
   AxText("RSK_TP_L", x + pad + cellW + gap + 12, y + 6, "TAKE PROFIT", AX_TEXT_ASH, 6, "Segoe UI");
   AxText("RSK_TP_V", x + pad + cellW + gap + 12, y + 16, DoubleToString(tpDist / pipSize, 1) + " p", AX_EMERALD, 10, "Segoe UI Semibold");
   y += cellH + gap;
   
   AxGlassPanel("RSK_RR", x + pad, y, cellW, cellH, rrClr);
   AxText("RSK_RR_L", x + pad + 12, y + 6, "RISK:REWARD", AX_TEXT_ASH, 6, "Segoe UI");
   AxText("RSK_RR_V", x + pad + 12, y + 16, "1 : " + DoubleToString(LiqIntel.recommendedRR, 2), rrClr, 10, "Segoe UI Semibold");
   
   AxGlassPanel("RSK_LOT", x + pad + cellW + gap, y, cellW, cellH, AX_ICE);
   AxText("RSK_LOT_L", x + pad + cellW + gap + 12, y + 6, "LOT SIZE", AX_TEXT_ASH, 6, "Segoe UI");
   AxText("RSK_LOT_V", x + pad + cellW + gap + 12, y + 16, DoubleToString(lot, 2), AX_ICE, 10, "Segoe UI Semibold");
   y += cellH + 10;
   
   if(Aurum.showNotification) {
      AxGlassPanel("NOTIF", x + pad, y, innerW, 22, Aurum.notificationColor);
      AxText("NOTIF_TXT", x + pad + innerW/2, y + 5, Aurum.notificationText, Aurum.notificationColor, 7, "Segoe UI Semibold", ANCHOR_TOP);
      y += 28;
   }
   
   AxRect("FOOT_BG", x + pad, y, innerW, 18, AX_BG_HEADER, AX_BORDER_DIM, 1);
   AxRect("FOOT_HL", x + pad + 1, y + 1, innerW - 2, 1, C'30,42,75', clrNONE, 0);
   AxText("FOOT_TXT", x + w/2, y + 4, "AURUM QUANTUM SYSTEMS  ©  2024   •   GOLD M1 CORE", AX_TEXT_ASH, 6, "Segoe UI", ANCHOR_TOP);
   y += 26;
   
   Aurum.height = y - Aurum.y;
   AxRect("BG_BASE", x - 2, Aurum.y - 2, w + 4, Aurum.height + 4, C'2,3,8', clrNONE, 0);
   AxRect("BG_MAIN", x, Aurum.y, w, Aurum.height, AX_BG_VOID, AX_BORDER_HI, 1);
   AxRect("BG_GOLD", x, Aurum.y, 3, Aurum.height, AX_GOLD, clrNONE, 0);
   
   ChartRedraw(0);
}

void UpdateDashboard() {
   if(!InpShowDashboard) return;
   DrawDashboard();
}

//+------------------------------------------------------------------+
//| CORE EA LOGIC                                                    |
//+------------------------------------------------------------------+
double CalculateLotSize(double slDistance) {
   double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double stepLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   if(stepLot <= 0) stepLot = 0.01;
   
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   
   if(tickValue <= 0 || tickSize <= 0 || slDistance <= 0) return NormalizeVolume(minLot);
   
   double riskPercent = InpRiskPercent;
   if(equity < 100.0) riskPercent = MathMin(riskPercent, 1.0);
   if(equity < 50.0) riskPercent = MathMin(riskPercent, 0.8);
   if(equity < 20.0) riskPercent = MathMin(riskPercent, 0.5);
   
   double riskAmount = equity * riskPercent / 100.0 * recentProfitFactor;
   double slInTicks = slDistance / tickSize;
   double riskPerLot = slInTicks * tickValue;
   if(riskPerLot <= 0) return NormalizeVolume(minLot);
   
   double lotSize = riskAmount / riskPerLot;
   double modeMult = (InpMode == Aggressive) ? 1.2 : (InpMode == Stealth) ? 0.8 : 1.0;
   lotSize *= modeMult * LiqIntel.lotSizeMultiplier;
   
   if(lotSize < minLot) lotSize = minLot;
   return NormalizeVolume(lotSize);
}

double NormalizeVolume(double vol) {
   double stepV = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   double minV = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxV = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   if(stepV <= 0) stepV = 0.01;
   double normalized = MathRound(vol / stepV) * stepV;
   return NormalizeDouble(MathMax(minV, MathMin(maxV, normalized)), 2);
}

bool IsOrderGenuinelyPending(ulong ticket) {
   if(!OrderSelect(ticket)) return false;
   ENUM_ORDER_STATE state = (ENUM_ORDER_STATE)OrderGetInteger(ORDER_STATE);
   return (state == ORDER_STATE_PLACED || state == ORDER_STATE_STARTED);
}

//+------------------------------------------------------------------+
//| 5-SECOND STALE ORDER RECYCLER                                    |
//+------------------------------------------------------------------+
int DeleteStaleOrders() {
   if(!InpAutoRecycleStaleOrders) return 0;
   if(TimeCurrent() - lastFillTime < 2) return 0;
   datetime now = TimeCurrent();
   int deleted = 0;
   for(int i = OrdersTotal() - 1; i >= 0; i--) {
      ulong ticket = OrderGetTicket(i);
      if(ticket == 0 || !OrderSelect(ticket)) continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol || OrderGetInteger(ORDER_MAGIC) != magic) continue;
      if(!IsOrderGenuinelyPending(ticket)) continue;
      datetime orderTime = (datetime)OrderGetInteger(ORDER_TIME_SETUP);
      int orderAge = (int)(now - orderTime);
      if(orderAge >= InpMaxOrderLifetimeSeconds) {
         if(trade.OrderDelete(ticket)) deleted++;
      }
   }
   return deleted;
}

//+------------------------------------------------------------------+
//| BIDIRECTIONAL GRID DEPLOYMENT                                    |
//+------------------------------------------------------------------+
void DeployBidirectionalGrid() {
   int deletedCount = DeleteStaleOrders();
   if(deletedCount > 0) {
      // Enforce a 5-second cooldown after cancellation to prevent churning into a spike
      lastGridDeployTime = TimeCurrent(); 
      UpdateLiquidityIntelligence();
   }
   if(OrdersTotal() > 0) return;
   
   if(profitTargetHit) return;
   if(!IsTradingSessionAllowed()) return;
   
   // Cooldown: 5 seconds required between deployments
   if(TimeCurrent() - lastGridDeployTime < 5) return; 
   
   // Hard spread filter
   if(LiqIntel.bidAskSpread > InpMaxSpreadPoints) return;
   
   int requiredScore = InpMinQualityScore;
   if(recoveryMode) requiredScore += recoveryQualityBoost;
   
   if(InpUseUltraFastMomentum && currentQualityScore < requiredScore) return;
   
   // In recovery mode, require stronger trend confirmation
   if(recoveryMode && lrSlopeATRRatio < InpMinSlopeATRRatio * 1.5) return;
   if(recoveryMode && lrRSquared < 0.4) return;
   
   if(InpUseLiquidityFilter && LiqIntel.volumeRatio < InpMinVolumeRatio && currentQualityScore < 85) return;
   
   double currentExposure = GetTotalExposure();
   if(currentExposure >= InpMaxTotalLots) return;
   
   MqlTick tick;
   if(!SymbolInfoTick(_Symbol, tick)) return;
   double atr = GetCurrentATR();
   if(atr <= 0) return;
   
   double currentPrice = (tick.bid + tick.ask) / 2.0;
   long stopLevel = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   double minStopDist = stopLevel * symbolPoint;
   
   // CRITICAL FIX: Spread-scaled SL and TP to prevent instant SL hits from spread widening
   double spreadDist = LiqIntel.bidAskSpread * symbolPoint;
   double slDist = MathMax(atr * LiqIntel.dynamicSLMultiplier, spreadDist * 3.0);
   double tpDist = MathMax(atr * LiqIntel.dynamicTPMultiplier, spreadDist * 4.0);
   double gridSpacing = MathMax(atr * InpGridStepATR, spreadDist * 2.0);
   double firstOffset = MathMax(atr * InpMinOrderDistanceATR, spreadDist * 2.0);
   
   // Also ensure they meet broker stop level requirements
   slDist = MathMax(slDist, minStopDist * 1.5);
   tpDist = MathMax(tpDist, minStopDist * 1.5);
   gridSpacing = MathMax(gridSpacing, minStopDist * 1.2);
   firstOffset = MathMax(firstOffset, minStopDist * 1.2);
   
   double lot = CalculateLotSize(slDist);
   if(lot < SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN)) return;
   
   int buyOrdersPlaced = 0, sellOrdersPlaced = 0;
   
   if(momentumDirection == 1) {
      for(int i = 0; i < InpOrdersPerSide; i++) {
         double entryPrice = NormalizeDouble(currentPrice + firstOffset + (i * gridSpacing), symbolDigits);
         if(entryPrice <= tick.ask) continue; 
         double sl = NormalizeDouble(entryPrice - slDist, symbolDigits);
         double tp = NormalizeDouble(entryPrice + tpDist, symbolDigits);
         if(trade.BuyStop(lot, entryPrice, _Symbol, sl, tp, ORDER_TIME_GTC, 0, "AXP_BULL")) buyOrdersPlaced++;
      }
   } else if(momentumDirection == -1) {
      for(int i = 0; i < InpOrdersPerSide; i++) {
         double entryPrice = NormalizeDouble(currentPrice - firstOffset - (i * gridSpacing), symbolDigits);
         if(entryPrice >= tick.bid) continue; 
         double sl = NormalizeDouble(entryPrice + slDist, symbolDigits);
         double tp = NormalizeDouble(entryPrice - tpDist, symbolDigits);
         if(trade.SellStop(lot, entryPrice, _Symbol, sl, tp, ORDER_TIME_GTC, 0, "AXP_BEAR")) sellOrdersPlaced++;
      }
   }
   
   if(buyOrdersPlaced > 0 || sellOrdersPlaced > 0) {
      lastGridDeployTime = TimeCurrent();
   }
}

//+------------------------------------------------------------------+
//| OCO MANAGEMENT (One-Cancels-Other)                               |
//+------------------------------------------------------------------+
void ManageOCO() {
   bool hasBuyPosition = false, hasSellPosition = false;
   for(int i = 0; i < PositionsTotal(); i++) {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket)) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol || PositionGetInteger(POSITION_MAGIC) != magic) continue;
      if((ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) hasBuyPosition = true;
      else hasSellPosition = true;
   }
   if(!hasBuyPosition && !hasSellPosition) return;
   for(int i = OrdersTotal() - 1; i >= 0; i--) {
      ulong ticket = OrderGetTicket(i);
      if(ticket == 0 || !OrderSelect(ticket)) continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol || OrderGetInteger(ORDER_MAGIC) != magic) continue;
      ENUM_ORDER_TYPE otype = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
      bool isOppositeOfBuy = hasBuyPosition && (otype == ORDER_TYPE_SELL_STOP || otype == ORDER_TYPE_SELL_LIMIT);
      bool isOppositeOfSell = hasSellPosition && (otype == ORDER_TYPE_BUY_STOP || otype == ORDER_TYPE_BUY_LIMIT);
      if((!isOppositeOfBuy && !isOppositeOfSell) || !IsOrderGenuinelyPending(ticket)) continue;
      trade.OrderDelete(ticket);
   }
}

//+------------------------------------------------------------------+
//| BALANCED DYNAMIC TARGETS                                         |
//+------------------------------------------------------------------+
void ManageBalancedTargets() {
   if(!InpUseDynamicTargets) return;
   for(int i = PositionsTotal() - 1; i >= 0; i--) {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket)) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol || PositionGetInteger(POSITION_MAGIC) != magic) continue;
      double currentProfit = PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP) + PositionGetDouble(POSITION_COMMISSION);
      double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
      double slDistance = MathAbs(openPrice - PositionGetDouble(POSITION_SL));
      if(slDistance <= 0) continue;
      double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
      double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
      double slRiskDollars = (slDistance / tickSize) * tickValue * PositionGetDouble(POSITION_VOLUME);
      if(currentProfit >= (slRiskDollars * InpScalpTargetMultiplier)) trade.PositionClose(ticket);
   }
}

//+------------------------------------------------------------------+
//| POSITION MANAGEMENT (Breakeven + Trailing)                       |
//+------------------------------------------------------------------+
void ManagePositions() {
   double atr = GetCurrentATR();
   if(atr <= 0) return;
   long stopLvl = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   double minStopDist = stopLvl * symbolPoint;
   for(int i = PositionsTotal() - 1; i >= 0; i--) {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket)) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol || PositionGetInteger(POSITION_MAGIC) != magic) continue;
      ENUM_POSITION_TYPE ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
      double curSL = PositionGetDouble(POSITION_SL), curTP = PositionGetDouble(POSITION_TP);
      double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID), ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      double curPrice = (ptype == POSITION_TYPE_BUY) ? bid : ask;
      double profitDist = (ptype == POSITION_TYPE_BUY) ? (curPrice - openPrice) : (openPrice - curPrice);
      double newSL = curSL; bool modify = false;
      
      if(InpUseBreakeven && profitDist >= InpBreakevenATR * atr) {
         double bePrice = (ptype == POSITION_TYPE_BUY) ? openPrice + InpBreakevenBufferPts * symbolPoint : openPrice - InpBreakevenBufferPts * symbolPoint;
         if((ptype == POSITION_TYPE_BUY && (curSL == 0 || curSL < bePrice)) || (ptype == POSITION_TYPE_SELL && (curSL == 0 || curSL > bePrice))) {
            newSL = bePrice; modify = true;
         }
      }
      if(InpUseTrailing && profitDist >= InpTrailStartATR * atr) {
         double trailPrice = (ptype == POSITION_TYPE_BUY) ? curPrice - InpTrailATR * atr : curPrice + InpTrailATR * atr;
         if((ptype == POSITION_TYPE_BUY && trailPrice > newSL) || (ptype == POSITION_TYPE_SELL && (newSL == 0 || trailPrice < newSL))) {
            newSL = trailPrice; modify = true;
         }
      }
      if(modify) {
         newSL = NormalizeDouble(newSL, symbolDigits);
         if(ptype == POSITION_TYPE_BUY && (bid - newSL) >= minStopDist) trade.PositionModify(ticket, newSL, curTP);
         else if(ptype == POSITION_TYPE_SELL && (newSL - ask) >= minStopDist) trade.PositionModify(ticket, newSL, curTP);
      }
   }
}

double GetTotalExposure() {
   double total = 0.0;
   for(int i = 0; i < PositionsTotal(); i++) {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket)) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol || PositionGetInteger(POSITION_MAGIC) != magic) continue;
      total += PositionGetDouble(POSITION_VOLUME);
   }
   for(int i = 0; i < OrdersTotal(); i++) {
      ulong ticket = OrderGetTicket(i);
      if(ticket == 0 || !OrderSelect(ticket)) continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol || OrderGetInteger(ORDER_MAGIC) != magic) continue;
      total += OrderGetDouble(ORDER_VOLUME_CURRENT);
   }
   return total;
}

//+------------------------------------------------------------------+
//| CIRCUIT BREAKER (NO PAUSE - Recovery Mode Instead)               |
//+------------------------------------------------------------------+
void CheckCircuitBreaker() {
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   peakEquity = MathMax(peakEquity, equity);
   MqlDateTime tm; TimeToStruct(TimeCurrent(), tm);
   if(tm.day != lastDayChecked) {
      dayStartBalance = AccountInfoDouble(ACCOUNT_BALANCE);
      lastDayChecked = tm.day;
      grossProfit = 0.0; grossLoss = 0.0; totalWins = 0; totalLosses = 0;
      profitTargetHit = false;
      recoveryMode = false;
      recoveryStartTime = 0;
      recentProfitFactor = 1.0;
   }
   dailyProfit = equity - dayStartBalance;
   
   if(dailyProfit >= InpDailyProfitTarget && !profitTargetHit) {
      profitTargetHit = true;
   }
   
   if(dailyProfit <= -InpDailyLossLimit && !recoveryMode && !profitTargetHit) {
      recoveryMode = true;
      recoveryStartTime = TimeCurrent();
   }
   
   if(recoveryMode && (TimeCurrent() - recoveryStartTime) > InpRecoveryTimeoutSeconds) {
      recoveryMode = false;
      recoveryStartTime = 0;
   }
   
   if(equity < peakEquity * (1 - InpMaxDrawdownPct / 100.0)) {
      recentProfitFactor = MathMax(0.5, recentProfitFactor * 0.95);
   } else {
      recentProfitFactor = MathMin(1.0, recentProfitFactor * 1.02);
   }
}

//+------------------------------------------------------------------+
//| MANUAL CLOSE FUNCTIONS                                           |
//+------------------------------------------------------------------+
void CloseAllProfitableTrades() {
   for(int i = PositionsTotal() - 1; i >= 0; i--) {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket)) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol || PositionGetInteger(POSITION_MAGIC) != magic) continue;
      if(PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP) > 0) trade.PositionClose(ticket);
   }
}

void CloseAllLosingTrades() {
   for(int i = PositionsTotal() - 1; i >= 0; i--) {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket)) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol || PositionGetInteger(POSITION_MAGIC) != magic) continue;
      if(PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP) < 0) trade.PositionClose(ticket);
   }
}

//+------------------------------------------------------------------+
//| RESET AND RESTART                                                |
//+------------------------------------------------------------------+
void ResetAndRestart() {
   profitTargetHit = false;
   recoveryMode = false;
   recoveryStartTime = 0;
   dayStartBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   peakEquity = AccountInfoDouble(ACCOUNT_EQUITY);
   recentProfitFactor = 1.0;
   grossProfit = 0.0;
   grossLoss = 0.0;
   totalWins = 0;
   totalLosses = 0;
   MqlDateTime tm;
   TimeToStruct(TimeCurrent(), tm);
   lastDayChecked = tm.day;
   for(int i = OrdersTotal() - 1; i >= 0; i--) {
      ulong ticket = OrderGetTicket(i);
      if(ticket == 0 || !OrderSelect(ticket)) continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol || OrderGetInteger(ORDER_MAGIC) != magic) continue;
      if(IsOrderGenuinelyPending(ticket)) trade.OrderDelete(ticket);
   }
   lastGridDeployTime = 0;
   UpdateLiquidityIntelligence();
}

//+------------------------------------------------------------------+
//| EVENT HANDLERS                                                   |
//+------------------------------------------------------------------+
void OnTimer() {
   animationFrame++;
   UpdateLiquidityIntelligence();
   ManageOCO();
   ManageBalancedTargets();
   ManagePositions();
   CheckCircuitBreaker();
   
   if(!profitTargetHit) {
      DeployBidirectionalGrid();
   }
   
   UpdateDashboard();
}

void OnTick() {
   UpdateLiquidityIntelligence();
   if(!InpUseTickDrivenMgmt) return;
   datetime now = TimeCurrent();
   if(now == lastTickManagement) return;
   lastTickManagement = now;
   ManageOCO();
   ManageBalancedTargets();
   ManagePositions();
}

void OnTradeTransaction(const MqlTradeTransaction &trans, const MqlTradeRequest &request, const MqlTradeResult &result) {
   if(trans.type != TRADE_TRANSACTION_DEAL_ADD) return;
   ulong dealTicket = trans.deal;
   if(!HistoryDealSelect(dealTicket)) return;
   if(HistoryDealGetInteger(dealTicket, DEAL_MAGIC) != magic || HistoryDealGetString(dealTicket, DEAL_SYMBOL) != _Symbol) return;
   long entry = HistoryDealGetInteger(dealTicket, DEAL_ENTRY);
   if(entry == DEAL_ENTRY_IN) {
      lastFillTime = TimeCurrent();
      ManageOCO();
   } else if(entry == DEAL_ENTRY_OUT || entry == DEAL_ENTRY_OUT_BY) {
      double dealProfit = HistoryDealGetDouble(dealTicket, DEAL_PROFIT) + HistoryDealGetDouble(dealTicket, DEAL_SWAP) + HistoryDealGetDouble(dealTicket, DEAL_COMMISSION);
      if(dealProfit > 0) {
         totalWins++;
         grossProfit += dealProfit;
         if(recoveryMode) {
            recoveryMode = false;
            recoveryStartTime = 0;
         }
      } else if(dealProfit < 0) {
         totalLosses++;
         grossLoss += MathAbs(dealProfit);
         if(!profitTargetHit && !recoveryMode) {
            recoveryMode = true;
            recoveryStartTime = TimeCurrent();
         }
      }
      if(grossLoss > 0) recentProfitFactor = MathMax(0.5, MathMin(grossProfit / grossLoss, 2.0));
   }
}

void OnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam) {
   if(id == CHARTEVENT_OBJECT_CLICK) {
      if(sparam == AX_PREFIX + "BTN_PROFIT") {
         ObjectSetInteger(0, sparam, OBJPROP_STATE, false);
         CloseAllProfitableTrades();
         UpdateDashboard();
      }
      if(sparam == AX_PREFIX + "BTN_LOSS") {
         ObjectSetInteger(0, sparam, OBJPROP_STATE, false);
         CloseAllLosingTrades();
         UpdateDashboard();
      }
      if(sparam == AX_PREFIX + "BTN_RESET") {
         ObjectSetInteger(0, sparam, OBJPROP_STATE, false);
         ResetAndRestart();
         UpdateDashboard();
      }
   }
}
//+------------------------------------------------------------------+