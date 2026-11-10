//+------------------------------------------------------------------+
//|                    PULSE MATRIX X1 - PRECISION SCALPING          |
//|          Intelligent Bidirectional Grid Engine                   |
//|          Real-Time Market Intelligence + Balanced R:R            |
//+------------------------------------------------------------------+
#property copyright "PulseTech Labs © 2025"
#property version   "1.0"
#property description "Professional Grid Trading with Market Intelligence"
#property strict

#include <Trade\Trade.mqh>

//+------------------------------------------------------------------+
//| PULSE MATRIX DASHBOARD - OBSIDIAN / NEON VIOLET THEME            |
//+------------------------------------------------------------------+
#define DASH_PREFIX "PULSEMX_"

// Obsidian Black + Neon Violet/Teal Theme (completely new palette)
#define CLR_BG_MAIN       C'8,8,14'          // Near-black obsidian
#define CLR_BG_PANEL      C'16,16,26'        // Panel background
#define CLR_BG_TILE       C'22,20,34'        // Tile / card background
#define CLR_BORDER        C'46,40,66'        // Subtle violet-tinted border
#define CLR_DIVIDER       C'34,30,50'        // Divider lines

#define CLR_TEXT_HI       C'245,240,255'     // Bright text
#define CLR_TEXT_MID      C'170,162,196'     // Secondary text
#define CLR_TEXT_LOW      C'104,98,128'      // Faint / label text

#define CLR_NEON_VIOLET   C'170,90,255'      // Primary accent - violet
#define CLR_NEON_TEAL     C'40,235,210'      // Secondary accent - teal (bullish/buy)
#define CLR_NEON_ROSE     C'255,70,120'      // Bearish/sell accent
#define CLR_NEON_AMBER    C'255,176,60'      // Caution / neutral accent
#define CLR_NEON_LIME     C'150,255,110'     // Success / profit accent
#define CLR_NEON_ICE      C'110,190,255'     // Info accent

// Chart theme
#define CHART_BG          C'6,6,10'
#define CHART_BULL        C'40,235,210'
#define CHART_BEAR        C'255,70,120'
#define CHART_GRID        C'12,12,18'

//+------------------------------------------------------------------+
//| EXECUTION & LIQUIDITY ENUMS                                      |
//+------------------------------------------------------------------+
enum ExecutionMode { Stealth = 1, Adaptive = 2, Aggressive = 3 };
enum LiquidityState { LIQ_VERY_LOW = 0, LIQ_LOW = 1, LIQ_NORMAL = 2, LIQ_HIGH = 3, LIQ_VERY_HIGH = 4 };
enum VolatilityRegime { VOL_DORMANT = 0, VOL_LOW = 1, VOL_NORMAL = 2, VOL_HIGH = 3, VOL_EXTREME = 4 };
enum MarketMomentum { MOM_STRONG_BEAR = -2, MOM_WEAK_BEAR = -1, MOM_NEUTRAL = 0, MOM_WEAK_BULL = 1, MOM_STRONG_BULL = 2 };

//+------------------------------------------------------------------+
//| INPUTS                                                            |
//+------------------------------------------------------------------+
input group "═══ GRID ENGINE ═══"
input ExecutionMode InpMode = Aggressive;
input int InpOrdersPerSide = 10;
input int InpMaxOrderLifetimeSeconds = 60;
input bool InpAutoRecycleStaleOrders = true;

input group "═══ BALANCED RISK:REWARD ═══"
input bool InpUseDynamicTargets = true;
input double InpMinRiskRewardRatio = 1.8;
input double InpScalpTargetMultiplier = 2.2;
input bool InpAllowEarlyExit = true;

input group "═══ LIQUIDITY INTELLIGENCE ═══"
input bool InpUseLiquidityFilter = true;
input int InpVolumeLookback = 20;
input double InpMinVolumeRatio = 0.7;
input bool InpUseMomentumFilter = true;
input int InpMomentumPeriod = 14;
input bool InpTradeWithTrend = true;
input bool InpUseVolatilityAdaptation = true;

input group "═══ GRID SPACING (ATR) ═══"
input double InpMinOrderDistanceATR = 0.15;
input double InpMaxOrderDistanceATR = 0.5;
input double InpGridStepATR = 0.035;

input group "═══ RISK MANAGEMENT ═══"
input double InpBaseLot = 0.15;
input double InpRiskPercent = 0.5;
input double InpMaxTotalLots = 3.0;
input double InpSLATRMult = 1.0;
input double InpTPATRMult = 2.2;

input group "═══ EXECUTION ═══"
input bool InpUseTickDrivenMgmt = true;
input int InpTradeDeviationPts = 5;
input int InpTimerMs = 100;

input group "═══ POSITION MANAGEMENT ═══"
input int InpMaxHoldMinutes = 60;
input bool InpForceCloseAtMaxHold = false;
input bool InpUseBreakeven = true;
input double InpBreakevenATR = 0.6;
input double InpBreakevenBufferPts = 10;
input bool InpUseTrailing = true;
input double InpTrailStartATR = 1.2;
input double InpTrailATR = 0.4;

input group "═══ CIRCUIT BREAKER ═══"
input double InpDailyProfitTarget = 50.0;
input double InpDailyLossLimit = 30.0;
input bool InpCloseAllOnLossLimit = true;
input double InpMaxDrawdownPct = 8.0;

input group "═══ ANALYSIS ═══"
input ENUM_TIMEFRAMES InpAnalysisTF = PERIOD_M1;
input int InpATRPeriod = 14;
input int InpMaxSpreadPoints = 80;
input int InpEMAPeriod = 20;

input group "═══ PULSE MATRIX DASHBOARD ═══"
input bool InpShowDashboard = true;
input int InpDashboardWidthPx = 340;
input bool InpAutoStyleChart = true;

input group "═══ TRADING SESSIONS ═══"
input bool InpTradeAllSessions = true;
input bool InpTradeSydneySession = true;
input int  InpSydneyStartHour = 21;
input int  InpSydneyEndHour = 6;
input bool InpTradeTokyoSession = true;
input int  InpTokyoStartHour = 0;
input int  InpTokyoEndHour = 9;
input bool InpTradeLondonSession = true;
input int  InpLondonStartHour = 7;
input int  InpLondonEndHour = 16;
input bool InpTradeNewYorkSession = true;
input int  InpNewYorkStartHour = 12;
input int  InpNewYorkEndHour = 21;

//+------------------------------------------------------------------+
//| GLOBAL VARIABLES                                                  |
//+------------------------------------------------------------------+
CTrade trade;
int handleATR, handleEMA;
datetime lastBarTime = 0;
int magic = 771144;

double dayStartBalance = 0.0;
int lastDayChecked = -1;
double dailyProfit = 0.0;
double peakEquity = 0.0;
double grossProfit = 0.0, grossLoss = 0.0;
int totalWins = 0, totalLosses = 0;
bool tradingEnabled = true;
double recentProfitFactor = 1.0;

double totalScalpProfit = 0.0;
int scalpWins = 0;
double avgWinSize = 0.0, avgLossSize = 0.0, realizedRR = 0.0;

datetime lastTickManagement = 0;
datetime lastGridDeployTime = 0;
datetime lastFillTime = 0;
ulong lastFilledOrderTicket = 0;
#define FILL_SETTLE_SECONDS 2

int symbolDigits = 0;
double symbolPoint = 0.0, pipSize = 0.0;
bool isJPYPair = false;

double cachedATR = 0.0;
datetime atrCacheTime = 0;
double cachedEMA = 0.0;
datetime emaCacheTime = 0;

datetime eaStartTime = 0;

//+------------------------------------------------------------------+
//| LIQUIDITY INTELLIGENCE STATE                                      |
//+------------------------------------------------------------------+
struct LiquidityIntelligence {
   double avgVolume, currentVolume, volumeRatio, volumeStdDev;
   double momentum, acceleration;
   MarketMomentum momentumState;
   double currentATR, avgATR, atrRatio;
   VolatilityRegime volRegime;
   LiquidityState liquidityState;
   double liquidityScore;
   double bidAskSpread, spreadRatio;
   double dynamicTPMultiplier, dynamicSLMultiplier, recommendedRR;
   bool allowLongEntry, allowShortEntry;
   double lotSizeMultiplier;
   datetime lastUpdate;
} LiqIntel;

//+------------------------------------------------------------------+
//| DASHBOARD STATE                                                   |
//+------------------------------------------------------------------+
struct DashboardState {
   int x, y, width, height, currentY;
   datetime lastUpdate;
   bool needsRedraw;

   // Live trade metrics — driven strictly by actual book state
   int buyOrders, sellOrders;
   int buyPositions, sellPositions;
   double totalFloat;
   string activeSignal;
   color signalColor;

} Dash;

//+------------------------------------------------------------------+
//| HELPER FUNCTIONS                                                  |
//+------------------------------------------------------------------+
void CreateRect(string name, int x, int y, int w, int h, color bg, color border = clrNONE, int borderW = 1) {
   string obj = DASH_PREFIX + name;
   if(ObjectFind(0, obj) < 0) ObjectCreate(0, obj, OBJ_RECTANGLE_LABEL, 0, 0, 0);
   ObjectSetInteger(0, obj, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, obj, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, obj, OBJPROP_XSIZE, w);
   ObjectSetInteger(0, obj, OBJPROP_YSIZE, h);
   ObjectSetInteger(0, obj, OBJPROP_BGCOLOR, bg);
   ObjectSetInteger(0, obj, OBJPROP_BORDER_TYPE, BORDER_FLAT);
   ObjectSetInteger(0, obj, OBJPROP_COLOR, border == clrNONE ? bg : border);
   ObjectSetInteger(0, obj, OBJPROP_WIDTH, borderW);
   ObjectSetInteger(0, obj, OBJPROP_BACK, false);
   ObjectSetInteger(0, obj, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, obj, OBJPROP_HIDDEN, false);
}

void CreateText(string name, int x, int y, string text, color clr, int size = 9, string font = "Consolas", int anchor = ANCHOR_LEFT_UPPER) {
   string obj = DASH_PREFIX + name;
   if(ObjectFind(0, obj) < 0) ObjectCreate(0, obj, OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, obj, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, obj, OBJPROP_YDISTANCE, y);
   ObjectSetString(0, obj, OBJPROP_TEXT, text);
   ObjectSetInteger(0, obj, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, obj, OBJPROP_FONTSIZE, size);
   ObjectSetString(0, obj, OBJPROP_FONT, font);
   ObjectSetInteger(0, obj, OBJPROP_ANCHOR, anchor);
   ObjectSetInteger(0, obj, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, obj, OBJPROP_HIDDEN, false);
}

void UpdateText(string name, string text) {
   string obj = DASH_PREFIX + name;
   if(ObjectFind(0, obj) >= 0) ObjectSetString(0, obj, OBJPROP_TEXT, text);
}

void UpdateTextColor(string name, color clr) {
   string obj = DASH_PREFIX + name;
   if(ObjectFind(0, obj) >= 0) ObjectSetInteger(0, obj, OBJPROP_COLOR, clr);
}

void CreateButton(string name, int x, int y, int w, int h, string text, color bg, color txt, int size = 9) {
   string obj = DASH_PREFIX + name;
   if(ObjectFind(0, obj) < 0) ObjectCreate(0, obj, OBJ_BUTTON, 0, 0, 0);
   ObjectSetInteger(0, obj, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, obj, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, obj, OBJPROP_XSIZE, w);
   ObjectSetInteger(0, obj, OBJPROP_YSIZE, h);
   ObjectSetString(0, obj, OBJPROP_TEXT, text);
   ObjectSetInteger(0, obj, OBJPROP_BGCOLOR, bg);
   ObjectSetInteger(0, obj, OBJPROP_COLOR, txt);
   ObjectSetInteger(0, obj, OBJPROP_FONTSIZE, size);
   ObjectSetString(0, obj, OBJPROP_FONT, "Segoe UI Semibold");
   ObjectSetInteger(0, obj, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, obj, OBJPROP_HIDDEN, false);
   if(ObjectFind(0, obj) >= 0) ObjectSetInteger(0, obj, OBJPROP_STATE, false);
}

//+------------------------------------------------------------------+
//| LIQUIDITY INTELLIGENCE FUNCTIONS                                  |
//+------------------------------------------------------------------+
double CalculateAverageVolume(int lookback) {
   long volumeArray[];
   ArraySetAsSeries(volumeArray, true);
   int copied = CopyTickVolume(_Symbol, InpAnalysisTF, 0, lookback, volumeArray);
   if(copied <= 0) return 0;
   double sum = 0;
   for(int i = 0; i < copied; i++) sum += (double)volumeArray[i];
   return sum / copied;
}

double CalculateMomentum(int period) {
   double closeArray[];
   ArraySetAsSeries(closeArray, true);
   int copied = CopyClose(_Symbol, InpAnalysisTF, 0, period + 1, closeArray);
   if(copied <= period) return 0;
   return (closeArray[0] - closeArray[period]) / closeArray[period] * 100.0;
}

double CalculateAverageATR(int lookback) {
   double atrArray[];
   ArraySetAsSeries(atrArray, true);
   if(CopyBuffer(handleATR, 0, 0, lookback, atrArray) <= 0) return GetCurrentATR();
   double sum = 0;
   for(int i = 0; i < lookback; i++) sum += atrArray[i];
   return sum / lookback;
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

void UpdateLiquidityIntelligence() {
   datetime now = TimeCurrent();
   if(now == LiqIntel.lastUpdate) return;

   LiqIntel.avgVolume = CalculateAverageVolume(InpVolumeLookback);
   long currentVol[];
   ArraySetAsSeries(currentVol, true);
   if(CopyTickVolume(_Symbol, InpAnalysisTF, 0, 1, currentVol) > 0)
      LiqIntel.currentVolume = (double)currentVol[0];
   else
      LiqIntel.currentVolume = LiqIntel.avgVolume;

   LiqIntel.volumeRatio = (LiqIntel.avgVolume > 0) ? LiqIntel.currentVolume / LiqIntel.avgVolume : 1.0;
   LiqIntel.momentum = CalculateMomentum(InpMomentumPeriod);
   LiqIntel.momentumState = ClassifyMomentum(LiqIntel.momentum);
   LiqIntel.currentATR = GetCurrentATR();
   LiqIntel.avgATR = CalculateAverageATR(InpATRPeriod * 2);
   LiqIntel.atrRatio = (LiqIntel.avgATR > 0) ? LiqIntel.currentATR / LiqIntel.avgATR : 1.0;
   LiqIntel.volRegime = ClassifyVolatilityRegime(LiqIntel.currentATR, LiqIntel.avgATR);

   MqlTick tick;
   SymbolInfoTick(_Symbol, tick);
   LiqIntel.bidAskSpread = (tick.ask - tick.bid) / symbolPoint;

   LiqIntel.dynamicTPMultiplier = InpTPATRMult;
   LiqIntel.dynamicSLMultiplier = InpSLATRMult;

   switch(LiqIntel.volRegime) {
      case VOL_DORMANT: LiqIntel.dynamicTPMultiplier *= 0.6; break;
      case VOL_LOW: LiqIntel.dynamicTPMultiplier *= 0.8; break;
      case VOL_HIGH: LiqIntel.dynamicTPMultiplier *= 1.3; break;
      case VOL_EXTREME:
         LiqIntel.dynamicTPMultiplier *= 1.5;
         LiqIntel.dynamicSLMultiplier *= 1.2;
         break;
   }

   if(LiqIntel.momentumState == MOM_STRONG_BULL || LiqIntel.momentumState == MOM_STRONG_BEAR)
      LiqIntel.dynamicTPMultiplier *= 1.2;

   LiqIntel.recommendedRR = LiqIntel.dynamicTPMultiplier / LiqIntel.dynamicSLMultiplier;
   if(LiqIntel.recommendedRR < InpMinRiskRewardRatio) {
      LiqIntel.dynamicTPMultiplier = InpMinRiskRewardRatio * LiqIntel.dynamicSLMultiplier;
      LiqIntel.recommendedRR = InpMinRiskRewardRatio;
   }

   LiqIntel.allowLongEntry = true;
   LiqIntel.allowShortEntry = true;

   if(InpUseMomentumFilter && InpTradeWithTrend) {
      if(LiqIntel.momentumState == MOM_STRONG_BEAR || LiqIntel.momentumState == MOM_WEAK_BEAR)
         LiqIntel.allowLongEntry = false;
      if(LiqIntel.momentumState == MOM_STRONG_BULL || LiqIntel.momentumState == MOM_WEAK_BULL)
         LiqIntel.allowShortEntry = false;
   }

   LiqIntel.lotSizeMultiplier = 1.0;
   if(LiqIntel.volRegime == VOL_EXTREME) LiqIntel.lotSizeMultiplier *= 0.7;

   LiqIntel.lastUpdate = now;
}

//+------------------------------------------------------------------+
//| SESSION FILTER                                                    |
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
//| CHART THEMING                                                     |
//+------------------------------------------------------------------+
void SetupChartAppearance() {
   if(!InpAutoStyleChart) return;
   long chartId = ChartID();
   ChartSetInteger(chartId, CHART_COLOR_BACKGROUND, CHART_BG);
   ChartSetInteger(chartId, CHART_COLOR_FOREGROUND, CLR_TEXT_HI);
   ChartSetInteger(chartId, CHART_SHOW_GRID, false);
   ChartSetInteger(chartId, CHART_MODE, CHART_CANDLES);
   ChartSetInteger(chartId, CHART_COLOR_CANDLE_BULL, CHART_BULL);
   ChartSetInteger(chartId, CHART_COLOR_CANDLE_BEAR, CHART_BEAR);
   ChartSetInteger(chartId, CHART_COLOR_CHART_UP, CHART_BULL);
   ChartSetInteger(chartId, CHART_COLOR_CHART_DOWN, CHART_BEAR);
   ChartSetInteger(chartId, CHART_SHOW_BID_LINE, false);
   ChartSetInteger(chartId, CHART_SHOW_ASK_LINE, false);
   ChartRedraw(chartId);
}

//+------------------------------------------------------------------+
//| INITIALIZATION                                                    |
//+------------------------------------------------------------------+
int OnInit() {
   if(InpRiskPercent > 10.0 || InpOrdersPerSide < 1 || InpOrdersPerSide > 50 || InpMinRiskRewardRatio < 1.0) {
      Print("⚠ ERROR: Invalid parameters");
      return INIT_PARAMETERS_INCORRECT;
   }

   symbolDigits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   symbolPoint = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   isJPYPair = (StringFind(_Symbol, "JPY") >= 0);
   pipSize = isJPYPair ? 0.01 : (symbolDigits == 3 || symbolDigits == 2) ? 0.01 : 0.0001;

   trade.SetExpertMagicNumber(magic);
   trade.SetDeviationInPoints(InpTradeDeviationPts);
   trade.SetTypeFillingBySymbol(_Symbol);

   handleATR = iATR(_Symbol, InpAnalysisTF, InpATRPeriod);
   handleEMA = iMA(_Symbol, InpAnalysisTF, InpEMAPeriod, 0, MODE_EMA, PRICE_CLOSE);
   if(handleATR == INVALID_HANDLE || handleEMA == INVALID_HANDLE) {
      Print("⚠ ERROR: Indicator initialization failed");
      return INIT_FAILED;
   }

   EventSetMillisecondTimer(InpTimerMs);
   peakEquity = AccountInfoDouble(ACCOUNT_EQUITY);
   dayStartBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   MqlDateTime tm;
   TimeToStruct(TimeCurrent(), tm);
   lastDayChecked = tm.day;
   eaStartTime = TimeCurrent();

   ZeroMemory(LiqIntel);
   UpdateLiquidityIntelligence();
   SetupChartAppearance();

   if(InpShowDashboard) InitDashboard();

   Print("═══════════════════════════════════════════════════════════");
   Print("◆ PULSE MATRIX X1 INITIALIZED");
   Print("Symbol: ", _Symbol, " | Grid: ", InpOrdersPerSide, " × 2 | Min R:R: 1:", DoubleToString(InpMinRiskRewardRatio, 1));
   Print("═══════════════════════════════════════════════════════════");

   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| DEINITIALIZATION                                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason) {
   EventKillTimer();
   IndicatorRelease(handleATR);
   IndicatorRelease(handleEMA);
   if(InpShowDashboard) ObjectsDeleteAll(0, DASH_PREFIX);
   Print("═══════════════════════════════════════════════════════════");
   Print("◆ PULSE MATRIX X1 SHUTDOWN | ", totalWins, "W / ", totalLosses, "L");
   Print("═══════════════════════════════════════════════════════════");
}

//+------------------------------------------------------------------+
//| DASHBOARD — BRAND NEW LAYOUT                                     |
//| Control panel (status / LED / CLOSE PROFIT / CLOSE LOSS) is the  |
//| very first block under the header, per spec.                    |
//+------------------------------------------------------------------+
void InitDashboard() {
   Dash.x = 10;
   Dash.y = 10;
   Dash.width = InpDashboardWidthPx;
   Dash.height = 620;
   Dash.needsRedraw = true;
}

// Pulls the ACTUAL order/position book and derives a signal label that can
// never disagree with what has really been executed. Filled positions
// always outrank pending orders, and a position in one direction only can
// never be reported as the opposite direction.
void AnalyzeLiveOrders() {
   Dash.buyOrders = 0;
   Dash.sellOrders = 0;
   Dash.buyPositions = 0;
   Dash.sellPositions = 0;
   Dash.totalFloat = 0.0;

   for(int i = 0; i < OrdersTotal(); i++) {
      ulong ticket = OrderGetTicket(i);
      if(ticket == 0 || !OrderSelect(ticket)) continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol || OrderGetInteger(ORDER_MAGIC) != magic) continue;

      ENUM_ORDER_TYPE otype = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
      if(otype == ORDER_TYPE_BUY_STOP || otype == ORDER_TYPE_BUY_LIMIT) Dash.buyOrders++;
      else if(otype == ORDER_TYPE_SELL_STOP || otype == ORDER_TYPE_SELL_LIMIT) Dash.sellOrders++;
   }

   for(int i = 0; i < PositionsTotal(); i++) {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket)) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol || PositionGetInteger(POSITION_MAGIC) != magic) continue;

      ENUM_POSITION_TYPE ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      if(ptype == POSITION_TYPE_BUY) Dash.buyPositions++;
      else Dash.sellPositions++;

      Dash.totalFloat += PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP) + PositionGetDouble(POSITION_COMMISSION);
   }

   // Priority order: EA paused > out of session > FILLED positions (ground truth)
   // > pending grid orders > standby. This guarantees the dashboard can never
   // show a bullish/buy state while the book only holds sell exposure or vice versa.
   if(!tradingEnabled) {
      Dash.activeSignal = "PAUSED";
      Dash.signalColor = CLR_TEXT_LOW;
   }
   else if(!IsTradingSessionAllowed()) {
      Dash.activeSignal = "OFF SESSION";
      Dash.signalColor = CLR_TEXT_LOW;
   }
   else if(Dash.buyPositions > 0 && Dash.sellPositions > 0) {
      Dash.activeSignal = "HEDGED BOOK";
      Dash.signalColor = CLR_NEON_VIOLET;
   }
   else if(Dash.buyPositions > 0) {
      Dash.activeSignal = "LONG FILLED";
      Dash.signalColor = CLR_NEON_TEAL;
   }
   else if(Dash.sellPositions > 0) {
      Dash.activeSignal = "SHORT FILLED";
      Dash.signalColor = CLR_NEON_ROSE;
   }
   else if(Dash.buyOrders > 0 && Dash.sellOrders > 0) {
      Dash.activeSignal = "GRID ARMED";
      Dash.signalColor = CLR_NEON_AMBER;
   }
   else if(Dash.buyOrders > 0) {
      Dash.activeSignal = "BUY GRID PENDING";
      Dash.signalColor = CLR_NEON_TEAL;
   }
   else if(Dash.sellOrders > 0) {
      Dash.activeSignal = "SELL GRID PENDING";
      Dash.signalColor = CLR_NEON_ROSE;
   }
   else {
      Dash.activeSignal = "STANDBY";
      Dash.signalColor = CLR_TEXT_MID;
   }
}

void DrawDashboard() {
   if(!InpShowDashboard) return;

   AnalyzeLiveOrders();

   int y = Dash.y;
   int pad = 10;
   int w = Dash.width - 2 * pad;

   // Main panel background + violet accent strip
   CreateRect("BG_MAIN", Dash.x, Dash.y, Dash.width, Dash.height, CLR_BG_MAIN, CLR_BORDER, 2);
   CreateRect("ACCENT_STRIP", Dash.x, Dash.y, 3, Dash.height, CLR_NEON_VIOLET, CLR_NEON_VIOLET, 0);

   y += 10;

   //--- HEADER ---
   CreateText("HDR_TITLE", Dash.x + pad, y, "PULSE MATRIX X1", CLR_NEON_VIOLET, 12, "Segoe UI Black");
   y += 16;
   CreateText("HDR_SUB", Dash.x + pad, y, "Bidirectional Grid Engine", CLR_TEXT_LOW, 7, "Consolas");
   y += 16;

   CreateRect("DIV_HDR", Dash.x + pad, y, w, 1, CLR_DIVIDER, CLR_DIVIDER, 0);
   y += 8;

   //=====================================================================
   // CONTROL PANEL — always the first functional block under the header:
   // status pill + LED, then CLOSE PROFIT / CLOSE LOSS buttons.
   //=====================================================================
   int ctrlH = 28;
   string status = tradingEnabled ? "ACTIVE" : "PAUSED";
   color statusClr = tradingEnabled ? CLR_NEON_LIME : CLR_NEON_ROSE;

   CreateRect("CTRL_STATUS_BG", Dash.x + pad, y, w, ctrlH, CLR_BG_PANEL, statusClr, 1);
   CreateRect("CTRL_LED", Dash.x + pad + 10, y + ctrlH/2 - 4, 8, 8, statusClr, statusClr, 0);
   CreateText("CTRL_STATUS_LBL", Dash.x + pad + 26, y + 6, "ENGINE STATUS", CLR_TEXT_LOW, 7, "Consolas");
   CreateText("CTRL_STATUS_VAL", Dash.x + pad + 26, y + 15, status, statusClr, 9, "Segoe UI Black");
   CreateText("CTRL_SIGNAL_VAL", Dash.x + Dash.width - pad - 8, y + 10, Dash.activeSignal, Dash.signalColor, 9, "Segoe UI Semibold", ANCHOR_RIGHT_UPPER);

   y += ctrlH + 8;

   int btnH = 30;
   int btnGap = 8;
   int btnW = (w - btnGap) / 2;
   CreateButton("BTN_PROFIT", Dash.x + pad, y, btnW, btnH, "CLOSE PROFIT", CLR_NEON_LIME, C'6,6,10', 9);
   CreateButton("BTN_LOSS", Dash.x + pad + btnW + btnGap, y, btnW, btnH, "CLOSE LOSS", CLR_NEON_ROSE, C'6,6,10', 9);
   y += btnH + 10;

   CreateRect("DIV_CTRL", Dash.x + pad, y, w, 1, CLR_DIVIDER, CLR_DIVIDER, 0);
   y += 8;

   //=====================================================================
   // LIVE BOOK — buy/sell orders & positions, driven strictly by
   // AnalyzeLiveOrders() so it can never contradict the signal above.
   //=====================================================================
   CreateText("BOOK_HDR", Dash.x + pad, y, "LIVE BOOK", CLR_TEXT_HI, 9, "Segoe UI Semibold");
   y += 16;

   CreateRect("CARD_BOOK", Dash.x + pad, y, w, 62, CLR_BG_TILE, CLR_BORDER, 1);

   CreateText("BOOK_BUY_LBL", Dash.x + pad + 8, y + 6, "BUY", CLR_NEON_TEAL, 7, "Consolas");
   CreateText("BOOK_BUY_ORD", Dash.x + pad + 8, y + 17, IntegerToString(Dash.buyOrders) + " pending", CLR_TEXT_MID, 8, "Consolas");
   CreateText("BOOK_BUY_POS", Dash.x + pad + 8, y + 30, IntegerToString(Dash.buyPositions) + " filled", CLR_NEON_TEAL, 11, "Segoe UI Black");

   CreateRect("BOOK_DIV", Dash.x + pad + w/2, y + 6, 1, 50, CLR_DIVIDER, CLR_DIVIDER, 0);

   CreateText("BOOK_SELL_LBL", Dash.x + pad + w/2 + 8, y + 6, "SELL", CLR_NEON_ROSE, 7, "Consolas");
   CreateText("BOOK_SELL_ORD", Dash.x + pad + w/2 + 8, y + 17, IntegerToString(Dash.sellOrders) + " pending", CLR_TEXT_MID, 8, "Consolas");
   CreateText("BOOK_SELL_POS", Dash.x + pad + w/2 + 8, y + 30, IntegerToString(Dash.sellPositions) + " filled", CLR_NEON_ROSE, 11, "Segoe UI Black");

   y += 70;

   //=====================================================================
   // MARKET DATA
   //=====================================================================
   MqlTick tick;
   SymbolInfoTick(_Symbol, tick);

   int col1 = Dash.x + pad;
   int col2 = Dash.x + pad + w/2 + 4;
   int cardW = w/2 - 4;
   int cardH = 32;

   CreateRect("CARD_BID", col1, y, cardW, cardH, CLR_BG_TILE, CLR_BORDER, 1);
   CreateText("BID_LBL", col1 + 8, y + 5, "BID", CLR_TEXT_LOW, 7, "Consolas");
   CreateText("BID_VAL", col1 + 8, y + 15, DoubleToString(tick.bid, symbolDigits), CLR_NEON_TEAL, 10, "Consolas");

   CreateRect("CARD_ASK", col2, y, cardW, cardH, CLR_BG_TILE, CLR_BORDER, 1);
   CreateText("ASK_LBL", col2 + 8, y + 5, "ASK", CLR_TEXT_LOW, 7, "Consolas");
   CreateText("ASK_VAL", col2 + 8, y + 15, DoubleToString(tick.ask, symbolDigits), CLR_NEON_ROSE, 10, "Consolas");

   y += cardH + 6;

   int spread = (int)MathRound((tick.ask - tick.bid) / symbolPoint);
   color sprClr = spread <= InpMaxSpreadPoints ? CLR_NEON_LIME : CLR_NEON_ROSE;

   CreateRect("CARD_SPR", col1, y, cardW, cardH, CLR_BG_TILE, CLR_BORDER, 1);
   CreateText("SPR_LBL", col1 + 8, y + 5, "SPREAD", CLR_TEXT_LOW, 7, "Consolas");
   CreateText("SPR_VAL", col1 + 8, y + 15, IntegerToString(spread) + "p", sprClr, 10, "Consolas");

   double atr = GetCurrentATR();
   CreateRect("CARD_ATR", col2, y, cardW, cardH, CLR_BG_TILE, CLR_BORDER, 1);
   CreateText("ATR_LBL", col2 + 8, y + 5, "ATR", CLR_TEXT_LOW, 7, "Consolas");
   CreateText("ATR_VAL", col2 + 8, y + 15, DoubleToString(atr/pipSize, 1) + "p", CLR_NEON_ICE, 10, "Consolas");

   y += cardH + 10;

   //=====================================================================
   // FLOATING P&L
   //=====================================================================
   color floatClr = Dash.totalFloat >= 0 ? CLR_NEON_LIME : CLR_NEON_ROSE;
   string floatStr = (Dash.totalFloat >= 0 ? "+" : "") + DoubleToString(Dash.totalFloat, 2);

   CreateRect("CARD_FLOAT", Dash.x + pad, y, w, 36, CLR_BG_TILE, floatClr, 1);
   CreateText("FLOAT_LBL", Dash.x + pad + 8, y + 6, "FLOATING P&L", CLR_TEXT_LOW, 7, "Consolas");
   CreateText("FLOAT_VAL", Dash.x + pad + 8, y + 16, "$" + floatStr, floatClr, 12, "Consolas");

   y += 44;

   //=====================================================================
   // ACCOUNT
   //=====================================================================
   CreateText("ACC_HDR", Dash.x + pad, y, "ACCOUNT", CLR_TEXT_HI, 9, "Segoe UI Semibold");
   y += 16;

   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);

   CreateRect("CARD_BAL", col1, y, cardW, cardH, CLR_BG_TILE, CLR_BORDER, 1);
   CreateText("BAL_LBL", col1 + 8, y + 5, "BALANCE", CLR_TEXT_LOW, 7, "Consolas");
   CreateText("BAL_VAL", col1 + 8, y + 15, "$" + DoubleToString(balance, 0), CLR_TEXT_HI, 10, "Consolas");

   color eqClr = equity >= balance ? CLR_NEON_LIME : CLR_NEON_ROSE;
   CreateRect("CARD_EQ", col2, y, cardW, cardH, CLR_BG_TILE, CLR_BORDER, 1);
   CreateText("EQ_LBL", col2 + 8, y + 5, "EQUITY", CLR_TEXT_LOW, 7, "Consolas");
   CreateText("EQ_VAL", col2 + 8, y + 15, "$" + DoubleToString(equity, 0), eqClr, 10, "Consolas");

   y += cardH + 6;

   color dayPLClr = dailyProfit >= 0 ? CLR_NEON_LIME : CLR_NEON_ROSE;
   string dayPLStr = (dailyProfit >= 0 ? "+" : "") + DoubleToString(dailyProfit, 2);

   CreateRect("CARD_DAYPL", col1, y, cardW, cardH, CLR_BG_TILE, CLR_BORDER, 1);
   CreateText("DAYPL_LBL", col1 + 8, y + 5, "DAY P&L", CLR_TEXT_LOW, 7, "Consolas");
   CreateText("DAYPL_VAL", col1 + 8, y + 15, "$" + dayPLStr, dayPLClr, 10, "Consolas");

   double winRate = (totalWins + totalLosses > 0) ? totalWins * 100.0 / (totalWins + totalLosses) : 0.0;
   color wrClr = winRate >= 50 ? CLR_NEON_LIME : CLR_NEON_AMBER;

   CreateRect("CARD_WR", col2, y, cardW, cardH, CLR_BG_TILE, CLR_BORDER, 1);
   CreateText("WR_LBL", col2 + 8, y + 5, "WIN RATE", CLR_TEXT_LOW, 7, "Consolas");
   CreateText("WR_VAL", col2 + 8, y + 15, DoubleToString(winRate, 0) + "%", wrClr, 10, "Consolas");

   y += cardH + 10;

   //=====================================================================
   // RISK & TARGETS
   //=====================================================================
   CreateText("RISK_HDR", Dash.x + pad, y, "RISK & TARGETS", CLR_TEXT_HI, 9, "Segoe UI Semibold");
   y += 16;

   double slDist = LiqIntel.dynamicSLMultiplier * atr;
   double tpDist = LiqIntel.dynamicTPMultiplier * atr;

   CreateRect("CARD_SL", col1, y, cardW, cardH, CLR_BG_TILE, CLR_BORDER, 1);
   CreateText("SL_LBL", col1 + 8, y + 5, "STOP LOSS", CLR_TEXT_LOW, 7, "Consolas");
   CreateText("SL_VAL", col1 + 8, y + 15, DoubleToString(slDist/pipSize, 1) + "p", CLR_NEON_ROSE, 10, "Consolas");

   CreateRect("CARD_TP", col2, y, cardW, cardH, CLR_BG_TILE, CLR_BORDER, 1);
   CreateText("TP_LBL", col2 + 8, y + 5, "TAKE PROFIT", CLR_TEXT_LOW, 7, "Consolas");
   CreateText("TP_VAL", col2 + 8, y + 15, DoubleToString(tpDist/pipSize, 1) + "p", CLR_NEON_LIME, 10, "Consolas");

   y += cardH + 6;

   color rrClr = LiqIntel.recommendedRR >= InpMinRiskRewardRatio ? CLR_NEON_LIME : CLR_NEON_AMBER;

   CreateRect("CARD_RR", col1, y, cardW, cardH, CLR_BG_TILE, CLR_BORDER, 1);
   CreateText("RR_LBL", col1 + 8, y + 5, "RISK:REWARD", CLR_TEXT_LOW, 7, "Consolas");
   CreateText("RR_VAL", col1 + 8, y + 15, "1:" + DoubleToString(LiqIntel.recommendedRR, 2), rrClr, 10, "Consolas");

   double lot = CalculateLotSize(slDist);
   CreateRect("CARD_LOT", col2, y, cardW, cardH, CLR_BG_TILE, CLR_BORDER, 1);
   CreateText("LOT_LBL", col2 + 8, y + 5, "LOT SIZE", CLR_TEXT_LOW, 7, "Consolas");
   CreateText("LOT_VAL", col2 + 8, y + 15, DoubleToString(lot, 2), CLR_NEON_ICE, 10, "Consolas");

   y += cardH + 10;

   //--- FOOTER ---
   CreateRect("DIV_FOOT", Dash.x + pad, y, w, 1, CLR_DIVIDER, CLR_DIVIDER, 0);
   y += 6;
   CreateText("FOOTER", Dash.x + Dash.width/2, y, "PULSE MATRIX © 2025", CLR_TEXT_LOW, 7, "Consolas", ANCHOR_TOP);
   y += 16;

   Dash.height = y - Dash.y + 6;
   CreateRect("BG_MAIN", Dash.x, Dash.y, Dash.width, Dash.height, CLR_BG_MAIN, CLR_BORDER, 2);
   CreateRect("ACCENT_STRIP", Dash.x, Dash.y, 3, Dash.height, CLR_NEON_VIOLET, CLR_NEON_VIOLET, 0);

   ChartRedraw(0);
}

void UpdateDashboard() {
   if(!InpShowDashboard) return;
   DrawDashboard();
}

//+------------------------------------------------------------------+
//| CORE EA FUNCTIONS                                                 |
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

double CalculateLotSize(double slDistance) {
   if(InpRiskPercent <= 0) return NormalizeVolume(InpBaseLot);
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   double riskAmount = equity * InpRiskPercent / 100.0 * recentProfitFactor;
   double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   if(tickValue <= 0 || tickSize <= 0) return NormalizeVolume(InpBaseLot);
   double slInTicks = slDistance / tickSize;
   double riskPerLot = slInTicks * tickValue;
   if(riskPerLot <= 0) return NormalizeVolume(InpBaseLot);
   double lotSize = riskAmount / riskPerLot;
   double modeMult = (InpMode == Aggressive) ? 1.3 : (InpMode == Stealth) ? 0.7 : 1.0;
   lotSize *= modeMult;
   if(InpUseLiquidityFilter) lotSize *= LiqIntel.lotSizeMultiplier;
   return NormalizeVolume(lotSize);
}

double NormalizeVolume(double vol) {
   double stepV = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   double minV = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxV = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   if(stepV <= 0) stepV = 0.01;
   double normalized = MathRound(vol / stepV) * stepV;
   normalized = MathMax(minV, MathMin(maxV, normalized));
   return NormalizeDouble(normalized, 2);
}

bool IsOrderGenuinelyPending(ulong ticket) {
   if(!OrderSelect(ticket)) return false;
   ENUM_ORDER_STATE state = (ENUM_ORDER_STATE)OrderGetInteger(ORDER_STATE);
   return (state == ORDER_STATE_PLACED || state == ORDER_STATE_STARTED);
}

int DeleteStaleOrders() {
   if(!InpAutoRecycleStaleOrders) return 0;
   if(TimeCurrent() - lastFillTime < FILL_SETTLE_SECONDS) return 0;

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
         if(trade.OrderDelete(ticket)) {
            deleted++;
            Print("⌫ STALE: Order #", ticket, " deleted (", orderAge, "s)");
         }
      }
   }
   return deleted;
}

void DeployBidirectionalGrid() {
   if(OrdersTotal() > 0) {
      int deletedCount = DeleteStaleOrders();
      if(deletedCount > 0) {
         lastGridDeployTime = TimeCurrent();
         return;
      }
      return;
   }

   if(!IsTradingSessionAllowed() || TimeCurrent() - lastGridDeployTime < 5) return;

   if(InpUseLiquidityFilter && LiqIntel.volumeRatio < InpMinVolumeRatio) return;

   double currentExposure = GetTotalExposure();
   if(currentExposure >= InpMaxTotalLots) return;

   MqlTick tick;
   if(!SymbolInfoTick(_Symbol, tick)) return;

   double atr = GetCurrentATR();
   if(atr <= 0) return;

   double currentPrice = (tick.bid + tick.ask) / 2.0;
   long stopLevel = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   double minStopDist = stopLevel * symbolPoint;

   double slDist = MathMax(atr * LiqIntel.dynamicSLMultiplier, minStopDist * 1.5);
   double tpDist = atr * LiqIntel.dynamicTPMultiplier;
   double gridSpacing = atr * InpGridStepATR;
   double lot = CalculateLotSize(slDist);

   if(lot < SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN)) return;

   int buyOrdersPlaced = 0, sellOrdersPlaced = 0;

   if(!InpUseMomentumFilter || LiqIntel.allowLongEntry) {
      double firstBuyOffset = atr * InpMinOrderDistanceATR;
      for(int i = 0; i < InpOrdersPerSide; i++) {
         double entryPrice = NormalizeDouble(currentPrice + firstBuyOffset + (i * gridSpacing), symbolDigits);
         if(entryPrice <= tick.ask) continue;
         double sl = NormalizeDouble(entryPrice - slDist, symbolDigits);
         double tp = NormalizeDouble(entryPrice + tpDist, symbolDigits);
         if((entryPrice - sl) < minStopDist || (tp - entryPrice) < minStopDist) continue;
         if(trade.BuyStop(lot, entryPrice, _Symbol, sl, tp, ORDER_TIME_GTC, 0, "PULSEMX_BUY")) buyOrdersPlaced++;
      }
   }

   if(!InpUseMomentumFilter || LiqIntel.allowShortEntry) {
      double firstSellOffset = atr * InpMinOrderDistanceATR;
      for(int i = 0; i < InpOrdersPerSide; i++) {
         double entryPrice = NormalizeDouble(currentPrice - firstSellOffset - (i * gridSpacing), symbolDigits);
         if(entryPrice >= tick.bid) continue;
         double sl = NormalizeDouble(entryPrice + slDist, symbolDigits);
         double tp = NormalizeDouble(entryPrice - tpDist, symbolDigits);
         if((sl - entryPrice) < minStopDist || (entryPrice - tp) < minStopDist) continue;
         if(trade.SellStop(lot, entryPrice, _Symbol, sl, tp, ORDER_TIME_GTC, 0, "PULSEMX_SELL")) sellOrdersPlaced++;
      }
   }

   lastGridDeployTime = TimeCurrent();
   Print("✔ GRID: ", buyOrdersPlaced, " BUY + ", sellOrdersPlaced, " SELL");
}

void ManageOCO() {
   bool hasBuyPosition = false, hasSellPosition = false;
   for(int i = 0; i < PositionsTotal(); i++) {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket)) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol || PositionGetInteger(POSITION_MAGIC) != magic) continue;
      ENUM_POSITION_TYPE ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      if(ptype == POSITION_TYPE_BUY) hasBuyPosition = true;
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
      if(!isOppositeOfBuy && !isOppositeOfSell) continue;
      if(!IsOrderGenuinelyPending(ticket)) continue;
      trade.OrderDelete(ticket);
   }
}

void ManageBalancedTargets() {
   if(!InpUseDynamicTargets) return;
   for(int i = PositionsTotal() - 1; i >= 0; i--) {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket)) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol || PositionGetInteger(POSITION_MAGIC) != magic) continue;

      double currentProfit = PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP) + PositionGetDouble(POSITION_COMMISSION);
      double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
      double curSL = PositionGetDouble(POSITION_SL);
      double slDistance = MathAbs(openPrice - curSL);
      if(slDistance <= 0) continue;

      double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
      double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
      double lot = PositionGetDouble(POSITION_VOLUME);
      double slRiskDollars = (slDistance / tickSize) * tickValue * lot;

      if(currentProfit >= (slRiskDollars * InpScalpTargetMultiplier)) {
         if(trade.PositionClose(ticket)) {
            scalpWins++;
            totalScalpProfit += currentProfit;
            Print("● TARGET HIT: +$", DoubleToString(currentProfit, 2));
         }
      }
   }
}

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
      double curSL = PositionGetDouble(POSITION_SL);
      double curTP = PositionGetDouble(POSITION_TP);
      double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      double curPrice = (ptype == POSITION_TYPE_BUY) ? bid : ask;
      double profitDist = (ptype == POSITION_TYPE_BUY) ? (curPrice - openPrice) : (openPrice - curPrice);

      double newSL = curSL;
      bool modify = false;

      if(InpUseBreakeven && profitDist >= InpBreakevenATR * atr) {
         double bePrice = (ptype == POSITION_TYPE_BUY) ? openPrice + InpBreakevenBufferPts * symbolPoint : openPrice - InpBreakevenBufferPts * symbolPoint;
         if((ptype == POSITION_TYPE_BUY && (curSL == 0 || curSL < bePrice)) || (ptype == POSITION_TYPE_SELL && (curSL == 0 || curSL > bePrice))) {
            newSL = bePrice;
            modify = true;
         }
      }

      if(InpUseTrailing && profitDist >= InpTrailStartATR * atr) {
         double trailPrice = (ptype == POSITION_TYPE_BUY) ? curPrice - InpTrailATR * atr : curPrice + InpTrailATR * atr;
         if((ptype == POSITION_TYPE_BUY && trailPrice > newSL) || (ptype == POSITION_TYPE_SELL && (newSL == 0 || trailPrice < newSL))) {
            newSL = trailPrice;
            modify = true;
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

void CheckCircuitBreaker() {
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   peakEquity = MathMax(peakEquity, equity);
   MqlDateTime tm;
   TimeToStruct(TimeCurrent(), tm);
   if(tm.day != lastDayChecked) {
      dayStartBalance = AccountInfoDouble(ACCOUNT_BALANCE);
      lastDayChecked = tm.day;
      tradingEnabled = true;
      grossProfit = 0.0; grossLoss = 0.0;
      totalWins = 0; totalLosses = 0;
   }
   dailyProfit = equity - dayStartBalance;
   if(dailyProfit >= InpDailyProfitTarget || dailyProfit <= -InpDailyLossLimit) tradingEnabled = false;
   if(equity < peakEquity * (1 - InpMaxDrawdownPct/100.0)) recentProfitFactor = 0.6;
}

void UpdateProfitFactor() {
   if(grossLoss > 0) recentProfitFactor = grossProfit / grossLoss;
   else if(grossProfit > 0) recentProfitFactor = 1.5;
   else recentProfitFactor = 1.0;
   recentProfitFactor = MathMax(0.5, MathMin(recentProfitFactor, 2.0));
}

void CloseAllProfitableTrades() {
   int closed = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--) {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket)) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol || PositionGetInteger(POSITION_MAGIC) != magic) continue;
      double pl = PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP) + PositionGetDouble(POSITION_COMMISSION);
      if(pl > 0 && trade.PositionClose(ticket)) closed++;
   }
   Print("● MANUAL: ", closed, " profitable trades closed");
}

void CloseAllLosingTrades() {
   int closed = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--) {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket)) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol || PositionGetInteger(POSITION_MAGIC) != magic) continue;
      double pl = PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP) + PositionGetDouble(POSITION_COMMISSION);
      if(pl < 0 && trade.PositionClose(ticket)) closed++;
   }
   Print("● MANUAL: ", closed, " losing trades closed");
}

//+------------------------------------------------------------------+
//| EVENT HANDLERS                                                    |
//+------------------------------------------------------------------+
void OnTimer() {
   UpdateLiquidityIntelligence();
   ManageOCO();
   ManageBalancedTargets();
   ManagePositions();
   CheckCircuitBreaker();
   if(tradingEnabled) DeployBidirectionalGrid();
   UpdateDashboard();
}

void OnTick() {
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
   if(HistoryDealGetInteger(dealTicket, DEAL_MAGIC) != magic) return;
   if(HistoryDealGetString(dealTicket, DEAL_SYMBOL) != _Symbol) return;

   long entry = HistoryDealGetInteger(dealTicket, DEAL_ENTRY);
   if(entry == DEAL_ENTRY_IN) {
      lastFillTime = TimeCurrent();
      lastFilledOrderTicket = HistoryDealGetInteger(dealTicket, DEAL_ORDER);
      ManageOCO();
   }
   else if(entry == DEAL_ENTRY_OUT || entry == DEAL_ENTRY_OUT_BY) {
      double dealProfit = HistoryDealGetDouble(dealTicket, DEAL_PROFIT) + HistoryDealGetDouble(dealTicket, DEAL_SWAP) + HistoryDealGetDouble(dealTicket, DEAL_COMMISSION);
      if(dealProfit > 0) {
         totalWins++;
         grossProfit += dealProfit;
         avgWinSize = grossProfit / totalWins;
      }
      else if(dealProfit < 0) {
         totalLosses++;
         grossLoss += MathAbs(dealProfit);
         avgLossSize = grossLoss / totalLosses;
      }
      if(totalLosses > 0 && avgLossSize > 0) realizedRR = avgWinSize / avgLossSize;
      UpdateProfitFactor();
   }
}

void OnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam) {
   if(id == CHARTEVENT_OBJECT_CLICK) {
      if(sparam == DASH_PREFIX + "BTN_PROFIT") {
         ObjectSetInteger(0, sparam, OBJPROP_STATE, false);
         CloseAllProfitableTrades();
         UpdateDashboard();
      }
      if(sparam == DASH_PREFIX + "BTN_LOSS") {
         ObjectSetInteger(0, sparam, OBJPROP_STATE, false);
         CloseAllLosingTrades();
         UpdateDashboard();
      }
   }
}
//+------------------------------------------------------------------+
