//+------------------------------------------------------------------+
//|          APEX BTC SCALPER  –  Institutional AI Edition           |
//|          v1.0  |  BTCUSD Multi-Layer Intelligence Engine         |
//|          10-Layer Signal Framework + Bulk Execution System       |
//+------------------------------------------------------------------+
//  ARCHITECTURE NOTE:
//  ─────────────────────────────────────────────────────────────────
//  Signal Generation : FULLY REPLACED  (10-Layer Institutional BTC)
//  Execution Engine  : PRESERVED 100%  (from PHANTOM SCALPER PRO)
//  Trade Management  : PRESERVED 100%
//  Risk Controls     : PRESERVED 100%
//  Dashboard         : UPGRADED for BTC / 10-Layer display
//+------------------------------------------------------------------+
#property copyright   "APEX BTC SCALPER  v1.0"
#property version     "1.00"
#property description "Institutional BTCUSD Scalper | 10-Layer AI Signal Engine | Bulk Execution"

#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>
#include <Trade\AccountInfo.mqh>

//--- Dashboard namespace prefix
#define D "APEX_"

//=======================================================================
//  COLOUR PALETTE
//=======================================================================
#define C_BG0       C'4,6,18'
#define C_BG1       C'8,12,28'
#define C_BG2       C'12,18,42'
#define C_HDRBAR    C'10,16,38'
#define C_BORDER    C'22,44,90'
#define C_ACBORD    C'255,145,0'      // Bitcoin orange accent
#define C_GOLD      C'255,180,30'
#define C_CYAN      C'0,220,220'
#define C_PURPLE    C'180,100,255'
#define C_WHITE     C'220,225,240'
#define C_SUBTEXT   C'110,130,160'
#define C_GREEN     C'20,220,110'
#define C_RED       C'230,55,65'
#define C_ORANGE    C'255,145,0'
#define C_DKGREEN   C'14,80,45'
#define C_LBLUE     C'80,160,255'
#define C_DGRAY     C'40,52,72'
#define C_MGRAY     C'75,90,115'
#define C_BTCORG    C'255,153,0'

//=======================================================================
//  DASHBOARD DIMENSIONS
//=======================================================================
const int DW = 460;
const int DH = 880;

//=======================================================================
//  INPUT PARAMETERS
//=======================================================================
input group "╔══════  IDENTITY  ══════╗"
input ulong  InpMagicNumber        = 88888;
input string InpBotName            = "APEX BTC SCALPER";

input group "╔══════  LOT & RECOVERY  ══════╗"
input double InpBaseLotSize        = 0.01;
input double InpProfitTargetUSD    = 5.00;
input double InpStopLossPct        = 1.5;
input double InpTakeProfitPct      = 3.0;
input double InpMaxDailyLossPct    = 5.0;
input double InpMaxDailyProfitPct  = 10.0;
input int    InpBulkTrades         = 7;

input group "╔══════  SIGNAL ENGINE THRESHOLDS  ══════╗"
input double InpMinBuyScore        = 72.0;   // Min composite BUY score (0–100) to trade
input double InpMinSellScore       = 72.0;   // Min composite SELL score (0–100) to trade
input double InpMinGradeForEntry   = 3;      // Min signal grade: 1=Weak 2=Avg 3=Strong 4=Institutional 5=Elite

input group "╔══════  LAYER WEIGHTS (must sum ≈100)  ══════╗"
input double InpW_Structure        = 20.0;   // L1  Market Structure weight
input double InpW_SmartMoney       = 20.0;   // L2  Smart Money weight
input double InpW_Volatility       = 10.0;   // L3  Volatility weight
input double InpW_Volume           = 15.0;   // L4  Volume weight
input double InpW_Momentum         = 15.0;   // L5  Momentum weight
input double InpW_Trend            = 10.0;   // L6  Trend Strength weight
input double InpW_Liquidity        = 10.0;   // L7  Liquidity Hunt weight

input group "╔══════  BTC SESSION FILTER  ══════╗"
input bool   InpUseSessionFilter   = true;
input bool   InpAllowAsian         = false;   // Asian (00:00–08:00 UTC) – low vol
input bool   InpAllowLondon        = true;    // London (08:00–13:00 UTC)
input bool   InpAllowNY            = true;    // New York (13:00–22:00 UTC)
input bool   InpAllowOverlap       = true;    // London/NY overlap (13:00–17:00 UTC)

input group "╔══════  VOLATILITY GUARD  ══════╗"
input double InpMinATRMultiple     = 0.5;     // Min ATR expansion factor (vs 20-period avg)
input double InpMaxATRMultiple     = 4.0;     // Max ATR multiple (shock filter)

input group "╔══════  TRADE FREQUENCY  ══════╗"
input int    InpMaxDailyTrades     = 21;
input int    InpCooldownSec        = 60;

input group "╔══════  MICROSTRUCTURE  ══════╗"
input int    InpTickBufferSize     = 500;

input group "╔══════  DASHBOARD  ══════╗"
input bool   InpShowDash           = true;
input int    InpDashX              = 14;
input int    InpDashY              = 14;

//=======================================================================
//  GLOBALS – EXECUTION ENGINE (PRESERVED)
//=======================================================================
CTrade        g_trade;
CPositionInfo g_pos;
CAccountInfo  g_account;

MqlTick       g_tickBuffer[];
int           g_tickCount         = 0;

datetime      g_lastCloseTime     = 0;
datetime      g_sessionDay        = 0;

double        g_recoveryTiers[5]  = {1.0, 1.5, 2.0, 2.5, 3.5};

int           g_sessTradesTotal   = 0;
int           g_sessTradesToday   = 0;
double        g_sessProfit        = 0.0;
int           g_sessWins          = 0;
int           g_sessLosses        = 0;
int           g_consecutiveLosses = 0;
double        g_peakEquity        = 0.0;
double        g_drawdown          = 0.0;

bool          g_inCooldown        = false;
int           g_cooldownLeft      = 0;

string        g_statusText        = "WARMING UP";
color         g_statusColor       = C_ORANGE;
string        g_lastAction        = "Initializing...";

//=======================================================================
//  GLOBALS – 10-LAYER SIGNAL ENGINE (NEW)
//=======================================================================

// Indicator handles — multi-timeframe
int g_ema9_M1=INVALID_HANDLE,  g_ema21_M1=INVALID_HANDLE,  g_ema50_M1=INVALID_HANDLE;
int g_ema9_M5=INVALID_HANDLE,  g_ema21_M5=INVALID_HANDLE,  g_ema50_M5=INVALID_HANDLE,  g_ema200_M5=INVALID_HANDLE;
int g_ema9_M15=INVALID_HANDLE, g_ema21_M15=INVALID_HANDLE, g_ema200_M15=INVALID_HANDLE;
int g_ema50_H1=INVALID_HANDLE, g_ema200_H1=INVALID_HANDLE;

int g_rsi_M1=INVALID_HANDLE,   g_rsi_M5=INVALID_HANDLE,  g_rsi_M15=INVALID_HANDLE;
int g_atr_M5=INVALID_HANDLE,   g_atr_M15=INVALID_HANDLE;
int g_sto_M5=INVALID_HANDLE;
int g_cci_M5=INVALID_HANDLE;
int g_adx_M5=INVALID_HANDLE,   g_adx_M15=INVALID_HANDLE;
int g_macd_M5=INVALID_HANDLE;
int g_bb_M5=INVALID_HANDLE;

// Layer scores (0..100, with direction sign: positive = bullish, negative = bearish)
double g_scoreStructure   = 0.0;
double g_scoreSmartMoney  = 0.0;
double g_scoreVolatility  = 0.0;
double g_scoreVolume      = 0.0;
double g_scoreMomentum    = 0.0;
double g_scoreTrend       = 0.0;
double g_scoreLiquidity   = 0.0;

// Composite
double g_buyScore         = 0.0;
double g_sellScore        = 0.0;
int    g_signalGrade      = 0;   // 0=None 1=Weak 2=Average 3=Strong 4=Institutional 5=Elite
string g_signalGradeTxt   = "NONE";
color  g_signalGradeColor = C_MGRAY;

// Regime
string g_regimeTxt        = "UNKNOWN";
color  g_regimeColor      = C_MGRAY;

// Market readiness
double g_readinessScore   = 0.0;

// Session
string g_sessionTxt       = "---";
color  g_sessionColor     = C_MGRAY;

// Market memory / adaptive stats
int    g_memWins          = 0;
int    g_memLosses        = 0;
double g_memBestScore     = 0.0;

// ATR reference
double g_atrCurrent       = 0.0;
double g_atrAvg           = 0.0;

// Warm-up flag
bool   g_indicatorsReady  = false;

//=======================================================================
//  FORWARD DECLARATIONS
//=======================================================================
// Signal engine
void   RunSignalEngine();
double LayerStructure();
double LayerSmartMoney();
double LayerVolatility();
double LayerVolume();
double LayerMomentum();
double LayerTrend();
double LayerLiquidity();
void   ClassifyRegime();
void   ClassifySession();
double ComputeReadiness();
int    GradeSignal(double score);
string GradeText(int grade);
color  GradeColor(int grade);
bool   SessionAllowed();
bool   VolatilityAllowed();
bool   IndicatorsWarmedUp();

// Execution engine (PRESERVED)
void   ResetAnalysis();
void   UpdateTickBuffer();
void   RestoreSession();
void   BuildSessionStats();
bool   HasPosition();
bool   OpenBulkTrades(ENUM_ORDER_TYPE otype);
void   CloseAllPositions();
double GetFloatPL();
int    GetConsecutiveLosses();
bool   IsMarketOpen();
bool   DailyLimitsOK();
void   AdjustStops(double price, ENUM_ORDER_TYPE otype, double &sl, double &tp);
double NPrice(double p);
ENUM_ORDER_TYPE_FILLING GetFillMode();
datetime DayStart(datetime ts);

// Dashboard
void InitDash();
void UpdateDash();
void DeleteDash();
void R(string nm,int x,int y,int w,int h,color bg,color brd=clrNONE,int bw=1);
void L(string nm,int x,int y,string txt,color clr,int fsz,string fnt="Arial Bold");
void U(string nm,string txt,color clr);
void Bar(string nm,int x,int y,int w,int h,double pct,color fg,color bg_c);
void UpdBar(string nm,double pct,color fg);

//=======================================================================
//  OnInit
//=======================================================================
int OnInit()
{
   if(StringFind(Symbol(), "BTC") < 0 && StringFind(Symbol(), "XBT") < 0)
      Print("Warning: APEX BTC SCALPER is tuned for BTCUSD. Current symbol: ", Symbol());

   ArrayResize(g_tickBuffer, InpTickBufferSize);

   g_trade.SetExpertMagicNumber(InpMagicNumber);
   g_trade.SetDeviationInPoints(50);   // BTC needs wider slippage tolerance
   g_trade.SetTypeFilling(GetFillMode());

   // ── Multi-timeframe indicator initialisation ──────────────────────
   // EMA stack
   g_ema9_M1    = iMA(Symbol(), PERIOD_M1,  9,   0, MODE_EMA, PRICE_CLOSE);
   g_ema21_M1   = iMA(Symbol(), PERIOD_M1,  21,  0, MODE_EMA, PRICE_CLOSE);
   g_ema50_M1   = iMA(Symbol(), PERIOD_M1,  50,  0, MODE_EMA, PRICE_CLOSE);
   g_ema9_M5    = iMA(Symbol(), PERIOD_M5,  9,   0, MODE_EMA, PRICE_CLOSE);
   g_ema21_M5   = iMA(Symbol(), PERIOD_M5,  21,  0, MODE_EMA, PRICE_CLOSE);
   g_ema50_M5   = iMA(Symbol(), PERIOD_M5,  50,  0, MODE_EMA, PRICE_CLOSE);
   g_ema200_M5  = iMA(Symbol(), PERIOD_M5,  200, 0, MODE_EMA, PRICE_CLOSE);
   g_ema9_M15   = iMA(Symbol(), PERIOD_M15, 9,   0, MODE_EMA, PRICE_CLOSE);
   g_ema21_M15  = iMA(Symbol(), PERIOD_M15, 21,  0, MODE_EMA, PRICE_CLOSE);
   g_ema200_M15 = iMA(Symbol(), PERIOD_M15, 200, 0, MODE_EMA, PRICE_CLOSE);
   g_ema50_H1   = iMA(Symbol(), PERIOD_H1,  50,  0, MODE_EMA, PRICE_CLOSE);
   g_ema200_H1  = iMA(Symbol(), PERIOD_H1,  200, 0, MODE_EMA, PRICE_CLOSE);

   // Oscillators
   g_rsi_M1  = iRSI(Symbol(), PERIOD_M1,  14, PRICE_CLOSE);
   g_rsi_M5  = iRSI(Symbol(), PERIOD_M5,  14, PRICE_CLOSE);
   g_rsi_M15 = iRSI(Symbol(), PERIOD_M15, 14, PRICE_CLOSE);
   g_sto_M5  = iStochastic(Symbol(), PERIOD_M5, 5, 3, 3, MODE_SMA, STO_LOWHIGH);
   g_cci_M5  = iCCI(Symbol(), PERIOD_M5,  20, PRICE_CLOSE);
   g_adx_M5  = iADX(Symbol(), PERIOD_M5,  14);
   g_adx_M15 = iADX(Symbol(), PERIOD_M15, 14);
   g_macd_M5 = iMACD(Symbol(), PERIOD_M5, 12, 26, 9, PRICE_CLOSE);
   g_bb_M5   = iBands(Symbol(), PERIOD_M5, 20, 0, 2.0, PRICE_CLOSE);
   g_atr_M5  = iATR(Symbol(), PERIOD_M5,  14);
   g_atr_M15 = iATR(Symbol(), PERIOD_M15, 14);

   g_peakEquity = AccountInfoDouble(ACCOUNT_EQUITY);
   g_sessionDay = DayStart(TimeCurrent());

   RestoreSession();
   BuildSessionStats();
   g_consecutiveLosses = GetConsecutiveLosses();

   if(InpShowDash) InitDash();
   EventSetTimer(1);

   g_lastAction = "Building indicator buffers...";
   return INIT_SUCCEEDED;
}

//=======================================================================
//  OnDeinit
//=======================================================================
void OnDeinit(const int reason)
{
   EventKillTimer();
   DeleteDash();
   // Release all handles
   int handles[] = {
      g_ema9_M1, g_ema21_M1, g_ema50_M1,
      g_ema9_M5, g_ema21_M5, g_ema50_M5, g_ema200_M5,
      g_ema9_M15, g_ema21_M15, g_ema200_M15,
      g_ema50_H1, g_ema200_H1,
      g_rsi_M1, g_rsi_M5, g_rsi_M15,
      g_sto_M5, g_cci_M5, g_adx_M5, g_adx_M15,
      g_macd_M5, g_bb_M5, g_atr_M5, g_atr_M15
   };
   for(int i = 0; i < ArraySize(handles); i++)
      if(handles[i] != INVALID_HANDLE) IndicatorRelease(handles[i]);
}

//=======================================================================
//  OnTimer  (PRESERVED execution engine timer)
//=======================================================================
void OnTimer()
{
   if(g_lastCloseTime > 0) {
      int elapsed    = (int)(TimeCurrent() - g_lastCloseTime);
      g_inCooldown   = (elapsed < InpCooldownSec);
      g_cooldownLeft = g_inCooldown ? (InpCooldownSec - elapsed) : 0;
   } else {
      g_inCooldown   = false;
      g_cooldownLeft = 0;
   }

   double eq = AccountInfoDouble(ACCOUNT_EQUITY);
   if(eq > g_peakEquity) g_peakEquity = eq;
   if(g_peakEquity > 0)  g_drawdown   = (g_peakEquity - eq) / g_peakEquity * 100.0;

   if(InpShowDash) UpdateDash();
}

//=======================================================================
//  OnTick  (PRESERVED execution skeleton; signal call replaced)
//=======================================================================
void OnTick()
{
   // ── Daily session reset ──────────────────────────────────────────
   datetime todayStart = DayStart(TimeCurrent());
   if(todayStart != g_sessionDay) {
      g_sessionDay        = todayStart;
      BuildSessionStats();
      g_consecutiveLosses = 0;
      ResetAnalysis();
   }

   if(!IsMarketOpen()) {
      g_statusText = "MKT CLOSED"; g_statusColor = C_RED; return;
   }

   UpdateTickBuffer();

   // ── Open position management (PRESERVED) ────────────────────────
   if(HasPosition()) {
      double floatPL = GetFloatPL();
      if(floatPL >= InpProfitTargetUSD) {
         CloseAllPositions();
         g_lastCloseTime     = TimeCurrent();
         g_inCooldown        = true;
         g_cooldownLeft      = InpCooldownSec;
         BuildSessionStats();
         g_consecutiveLosses = GetConsecutiveLosses();
         ResetAnalysis();
         return;
      }
      g_statusText = "IN TRADE"; g_statusColor = C_GREEN;
      return;
   }

   if(g_inCooldown)    { g_statusText = "COOLDOWN";  g_statusColor = C_CYAN; return; }
   if(!DailyLimitsOK()) { g_statusText = "LIMIT HIT"; g_statusColor = C_RED;  return; }

   // ── Tick buffer warm-up ──────────────────────────────────────────
   if(g_tickCount < InpTickBufferSize) {
      g_statusText = "BUFFERING"; g_statusColor = C_ORANGE; return;
   }

   // ── Indicator warm-up ───────────────────────────────────────────
   if(!IndicatorsWarmedUp()) {
      g_statusText = "WARMING UP"; g_statusColor = C_ORANGE; return;
   }

   // ═══════════════════════════════════════════════════════════════
   //  10-LAYER INSTITUTIONAL SIGNAL ENGINE  (NEW)
   // ═══════════════════════════════════════════════════════════════
   RunSignalEngine();

   // ── Session filter ───────────────────────────────────────────────
   if(InpUseSessionFilter && !SessionAllowed()) {
      g_statusText = "SESSION WAIT"; g_statusColor = C_MGRAY; return;
   }

   // ── Volatility guard ────────────────────────────────────────────
   if(!VolatilityAllowed()) {
      g_statusText = "VOL GUARD"; g_statusColor = C_ORANGE; return;
   }

   // ── Market readiness ────────────────────────────────────────────
   if(g_readinessScore < 40.0) {
      g_statusText = "SCANNING"; g_statusColor = C_GOLD; return;
   }

   // ── Signal grade filter ─────────────────────────────────────────
   if(g_signalGrade < InpMinGradeForEntry) {
      g_statusText = "ANALYZING"; g_statusColor = C_GOLD; return;
   }

   // ═══════════════════════════════════════════════════════════════
   //  EXECUTION ENGINE  (PRESERVED FROM PHANTOM SCALPER PRO)
   // ═══════════════════════════════════════════════════════════════
   ENUM_ORDER_TYPE dir = (ENUM_ORDER_TYPE)-1;
   if(g_buyScore  >= InpMinBuyScore)  dir = ORDER_TYPE_BUY;
   if(g_sellScore >= InpMinSellScore && g_sellScore > g_buyScore) dir = ORDER_TYPE_SELL;

   if(dir != (ENUM_ORDER_TYPE)-1) {
      g_statusText = "EXECUTING"; g_statusColor = C_LBLUE;
      if(OpenBulkTrades(dir)) {
         g_statusText  = "IN TRADE";
         g_statusColor = C_GREEN;
         g_lastAction  = StringFormat("%s SIGNAL | Score: %.1f | Grade: %s",
                           (dir == ORDER_TYPE_BUY ? "BUY" : "SELL"),
                           (dir == ORDER_TYPE_BUY ? g_buyScore : g_sellScore),
                           g_signalGradeTxt);
      } else {
         g_statusText  = "OPEN FAIL"; g_statusColor = C_RED;
      }
   } else {
      g_statusText = "ANALYZING"; g_statusColor = C_GOLD;
   }
}

//=======================================================================
//  ════════════════════════════════════════════════════════════════════
//  10-LAYER INSTITUTIONAL BTC SIGNAL ENGINE
//  ════════════════════════════════════════════════════════════════════
//=======================================================================

//-----------------------------------------------------------------------
//  RunSignalEngine  – Orchestrates all 10 layers
//-----------------------------------------------------------------------
void RunSignalEngine()
{
   // Run all layers (each returns a signed score -100..+100)
   double raw_structure  = LayerStructure();
   double raw_smartmoney = LayerSmartMoney();
   double raw_volatility = LayerVolatility();
   double raw_volume     = LayerVolume();
   double raw_momentum   = LayerMomentum();
   double raw_trend      = LayerTrend();
   double raw_liquidity  = LayerLiquidity();

   // Store for dashboard
   g_scoreStructure  = raw_structure;
   g_scoreSmartMoney = raw_smartmoney;
   g_scoreVolatility = raw_volatility;
   g_scoreVolume     = raw_volume;
   g_scoreMomentum   = raw_momentum;
   g_scoreTrend      = raw_trend;
   g_scoreLiquidity  = raw_liquidity;

   // Weighted composite  (each layer contributes to both buy & sell)
   double wSum = InpW_Structure + InpW_SmartMoney + InpW_Volatility +
                 InpW_Volume    + InpW_Momentum   + InpW_Trend + InpW_Liquidity;
   if(wSum <= 0) wSum = 100.0;

   // Positive component → buy contribution; negative → sell contribution
   auto contrib = [&](double raw, double w) -> double { return raw * w / wSum; };

   double net = contrib(raw_structure,  InpW_Structure)
              + contrib(raw_smartmoney, InpW_SmartMoney)
              + contrib(raw_volatility, InpW_Volatility)
              + contrib(raw_volume,     InpW_Volume)
              + contrib(raw_momentum,   InpW_Momentum)
              + contrib(raw_trend,      InpW_Trend)
              + contrib(raw_liquidity,  InpW_Liquidity);

   // Convert to 0–100 buy / sell scores
   g_buyScore  = MathMax(0.0, MathMin(100.0,  net + 50.0));
   g_sellScore = MathMax(0.0, MathMin(100.0, -net + 50.0));

   // Grade the stronger signal
   double topScore = MathMax(g_buyScore, g_sellScore);
   g_signalGrade     = GradeSignal(topScore);
   g_signalGradeTxt  = GradeText(g_signalGrade);
   g_signalGradeColor= GradeColor(g_signalGrade);

   // Market regime & session classification
   ClassifyRegime();
   ClassifySession();

   // Market readiness score (0–100)
   g_readinessScore = ComputeReadiness();
}

//-----------------------------------------------------------------------
//  L1 – Multi-Timeframe Market Structure Analysis
//  Returns signed score -100..+100 (positive = bullish bias)
//-----------------------------------------------------------------------
double LayerStructure()
{
   double score = 0.0;
   int    votes = 0;

   // Helper lambda: EMA bias from a handle pair
   #define EMA_BIAS(fast, slow) \
   { \
      double f[1], s[1]; \
      if(CopyBuffer(fast, 0, 0, 1, f) == 1 && CopyBuffer(slow, 0, 0, 1, s) == 1) { \
         score += (f[0] > s[0]) ? 1.0 : -1.0; votes++; \
      } \
   }

   EMA_BIAS(g_ema9_M1,  g_ema21_M1)
   EMA_BIAS(g_ema9_M5,  g_ema21_M5)
   EMA_BIAS(g_ema9_M5,  g_ema50_M5)
   EMA_BIAS(g_ema21_M5, g_ema50_M5)
   EMA_BIAS(g_ema9_M15, g_ema21_M15)
   EMA_BIAS(g_ema50_H1, g_ema200_H1)

   // BOS/CHOCH detection via close vs recent swing
   double h[5], l[5], c[1];
   if(CopyHigh(Symbol(), PERIOD_M5, 1, 5, h) == 5 &&
      CopyLow(Symbol(),  PERIOD_M5, 1, 5, l) == 5 &&
      CopyClose(Symbol(),PERIOD_M5, 0, 1, c) == 1) {
      double swingHigh = h[ArrayMaximum(h)];
      double swingLow  = l[ArrayMinimum(l)];
      if(c[0] > swingHigh) { score += 2.0; votes++; }   // Break of Structure up
      if(c[0] < swingLow)  { score -= 2.0; votes++; }   // Break of Structure down
   }

   // M15 close vs EMA200 (macro bias)
   double c15[1], e200[1];
   if(CopyClose(Symbol(), PERIOD_M15, 0, 1, c15) == 1 &&
      CopyBuffer(g_ema200_M15, 0, 0, 1, e200) == 1) {
      score += (c15[0] > e200[0]) ? 1.5 : -1.5;
      votes++;
   }

   if(votes == 0) return 0;
   return MathMax(-100.0, MathMin(100.0, (score / votes) * 50.0));
}

//-----------------------------------------------------------------------
//  L2 – Smart Money Concepts Engine
//  Returns signed score -100..+100
//-----------------------------------------------------------------------
double LayerSmartMoney()
{
   double score = 0.0;

   // ── Fair Value Gap detection (imbalance between candle i+1 and i-1) ──
   double hi[3], lo[3], cl[3];
   if(CopyHigh(Symbol(),  PERIOD_M5, 1, 3, hi) == 3 &&
      CopyLow(Symbol(),   PERIOD_M5, 1, 3, lo) == 3 &&
      CopyClose(Symbol(), PERIOD_M5, 1, 3, cl) == 3) {
      // Bullish FVG: low[0] > high[2]
      if(lo[0] > hi[2]) score += 25.0;
      // Bearish FVG: high[0] < low[2]
      if(hi[0] < lo[2]) score -= 25.0;
   }

   // ── Order Block (OB) detection ────────────────────────────────────
   // Bullish OB: last down candle before a strong up move
   double op[5], cls[5];
   if(CopyOpen(Symbol(),  PERIOD_M5, 1, 5, op)  == 5 &&
      CopyClose(Symbol(), PERIOD_M5, 1, 5, cls) == 5) {
      // Detect: candle[4] bearish, then consecutive bullish momentum
      if(cls[4] < op[4] && cls[3] > op[3] && cls[2] > op[2]) score += 20.0;
      // Detect: candle[4] bullish, then consecutive bearish momentum
      if(cls[4] > op[4] && cls[3] < op[3] && cls[2] < op[2]) score -= 20.0;
   }

   // ── Premium / Discount Zone ───────────────────────────────────────
   double h20[20], l20[20];
   if(CopyHigh(Symbol(), PERIOD_M15, 1, 20, h20) == 20 &&
      CopyLow(Symbol(),  PERIOD_M15, 1, 20, l20) == 20) {
      double rngH = h20[ArrayMaximum(h20)];
      double rngL = l20[ArrayMinimum(l20)];
      double rng  = rngH - rngL;
      double cur  = SymbolInfoDouble(Symbol(), SYMBOL_BID);
      if(rng > 0) {
         double pct = (cur - rngL) / rng;
         // Discount zone (<0.5) → bullish premium; Premium zone (>0.5) → bearish
         if(pct < 0.35)  score += 20.0;   // Deep discount – long bias
         if(pct > 0.65)  score -= 20.0;   // Deep premium  – short bias
      }
   }

   // ── Equal highs / lows (liquidity pools) ─────────────────────────
   double h10[10], l10[10];
   if(CopyHigh(Symbol(), PERIOD_M5, 1, 10, h10) == 10 &&
      CopyLow(Symbol(),  PERIOD_M5, 1, 10, l10) == 10) {
      double hMax1 = h10[ArrayMaximum(h10)];
      double lMin1 = l10[ArrayMinimum(l10)];
      // Count near-equal highs (within 0.05%)
      int eqH = 0, eqL = 0;
      for(int i = 0; i < 10; i++) {
         if(MathAbs(h10[i] - hMax1) / hMax1 < 0.0005) eqH++;
         if(MathAbs(l10[i] - lMin1) / lMin1 < 0.0005) eqL++;
      }
      if(eqH >= 2) score -= 10.0;   // Equal highs = liquidity above = potential short target
      if(eqL >= 2) score += 10.0;   // Equal lows  = liquidity below = potential long target
   }

   return MathMax(-100.0, MathMin(100.0, score));
}

//-----------------------------------------------------------------------
//  L3 – BTC Volatility Analysis Engine
//  Returns signed score -100..+100 (magnitude matters, direction from momentum)
//-----------------------------------------------------------------------
double LayerVolatility()
{
   double atrBuf[20];
   if(CopyBuffer(g_atr_M5, 0, 0, 20, atrBuf) < 20) return 0.0;

   g_atrCurrent = atrBuf[0];
   double atrSum = 0;
   for(int i = 1; i < 20; i++) atrSum += atrBuf[i];
   g_atrAvg = atrSum / 19.0;

   if(g_atrAvg <= 0) return 0.0;
   double expansion = g_atrCurrent / g_atrAvg;

   // Dead market or shock → penalise
   if(expansion < InpMinATRMultiple) return -30.0;
   if(expansion > InpMaxATRMultiple) return -50.0;

   // Bollinger band squeeze detection
   double bbU[2], bbL[2], bbM[2];
   if(CopyBuffer(g_bb_M5, 1, 0, 2, bbU) == 2 &&
      CopyBuffer(g_bb_M5, 2, 0, 2, bbL) == 2 &&
      CopyBuffer(g_bb_M5, 0, 0, 2, bbM) == 2) {
      double bandWidth  = (bbU[0] - bbL[0]) / bbM[0];
      double bandWidthP = (bbU[1] - bbL[1]) / bbM[1];
      // Expanding bands (breakout) → positive
      if(bandWidth > bandWidthP * 1.15) return 60.0;
      // Contracting bands (compression) → neutral/slightly positive (pre-breakout)
      if(bandWidth < bandWidthP * 0.85) return 20.0;
   }

   // Normal expansion
   return MathMin(100.0, (expansion - 1.0) * 40.0 + 30.0);
}

//-----------------------------------------------------------------------
//  L4 – Volume Intelligence Engine
//  Returns signed score -100..+100
//-----------------------------------------------------------------------
double LayerVolume()
{
   double score = 0.0;

   // Relative tick volume: current vs 20-bar average
   long vol[21];
   if(CopyTickVolume(Symbol(), PERIOD_M5, 0, 21, vol) < 21) return 0.0;

   long volNow = vol[0];
   long volSum = 0;
   for(int i = 1; i <= 20; i++) volSum += vol[i];
   double volAvg = (double)volSum / 20.0;

   if(volAvg > 0) {
      double relVol = volNow / volAvg;
      if(relVol > 1.5) score += 40.0;   // High institutional participation
      if(relVol > 2.5) score += 20.0;   // Volume spike
      if(relVol < 0.5) score -= 30.0;   // Dead volume
   }

   // Volume expansion on latest 3 candles
   if(vol[0] > vol[1] && vol[1] > vol[2]) score += 20.0;  // Expanding
   if(vol[0] < vol[1] && vol[1] < vol[2]) score -= 15.0;  // Contracting

   // Volume divergence: price up but volume down → bearish signal
   double c3[3];
   if(CopyClose(Symbol(), PERIOD_M5, 0, 3, c3) == 3) {
      bool priceUp   = c3[0] > c3[2];
      bool volDown   = vol[0] < vol[2];
      if(priceUp  && volDown)  score -= 25.0;   // Bearish divergence
      if(!priceUp && !volDown) score += 25.0;   // Bullish divergence (drop on low vol)
   }

   return MathMax(-100.0, MathMin(100.0, score));
}

//-----------------------------------------------------------------------
//  L5 – Momentum Analysis Engine
//  Returns signed score -100..+100
//-----------------------------------------------------------------------
double LayerMomentum()
{
   double score = 0.0;
   int    votes = 0;

   // RSI across timeframes
   double rsiM1[1], rsiM5[1], rsiM15[1];
   if(CopyBuffer(g_rsi_M1,  0, 0, 1, rsiM1)  == 1) { score += (rsiM1[0]  - 50.0) * 0.8; votes++; }
   if(CopyBuffer(g_rsi_M5,  0, 0, 1, rsiM5)  == 1) { score += (rsiM5[0]  - 50.0) * 1.0; votes++; }
   if(CopyBuffer(g_rsi_M15, 0, 0, 1, rsiM15) == 1) { score += (rsiM15[0] - 50.0) * 1.2; votes++; }

   // Stochastic
   double stoK[1], stoD[1];
   if(CopyBuffer(g_sto_M5, 0, 0, 1, stoK) == 1 &&
      CopyBuffer(g_sto_M5, 1, 0, 1, stoD) == 1) {
      score += (stoK[0] - stoD[0]) * 0.6;
      if(stoK[0] > 80) score -= 15.0;   // Overbought
      if(stoK[0] < 20) score += 15.0;   // Oversold
      votes++;
   }

   // CCI
   double cci[1];
   if(CopyBuffer(g_cci_M5, 0, 0, 1, cci) == 1) {
      score += MathMax(-30.0, MathMin(30.0, cci[0] * 0.15));
      votes++;
   }

   // MACD histogram
   double macdH[1];
   if(CopyBuffer(g_macd_M5, 2, 0, 1, macdH) == 1) {
      score += MathMax(-25.0, MathMin(25.0, macdH[0] * 500.0));
      votes++;
   }

   if(votes == 0) return 0;
   return MathMax(-100.0, MathMin(100.0, score / votes * 2.0));
}

//-----------------------------------------------------------------------
//  L6 – Trend Strength Engine
//  Returns signed score -100..+100
//-----------------------------------------------------------------------
double LayerTrend()
{
   double score = 0.0;

   // ADX strength (non-directional, but direction from EMA)
   double adxM5[1], adxM15[1];
   bool   strongTrend = false;
   if(CopyBuffer(g_adx_M5, 0, 0, 1, adxM5) == 1) {
      if(adxM5[0] > 25) { score += 20.0; strongTrend = true; }
      if(adxM5[0] > 40) score += 15.0;   // Very strong
   }
   if(CopyBuffer(g_adx_M15, 0, 0, 1, adxM15) == 1) {
      if(adxM15[0] > 25) score += 15.0;
   }

   // EMA alignment – full stack bullish/bearish
   double e9[1], e21[1], e50[1], e200[1];
   if(CopyBuffer(g_ema9_M5,  0, 0, 1, e9)   == 1 &&
      CopyBuffer(g_ema21_M5, 0, 0, 1, e21)  == 1 &&
      CopyBuffer(g_ema50_M5, 0, 0, 1, e50)  == 1 &&
      CopyBuffer(g_ema200_M5,0, 0, 1, e200) == 1) {
      bool bullStack = (e9[0] > e21[0] && e21[0] > e50[0] && e50[0] > e200[0]);
      bool bearStack = (e9[0] < e21[0] && e21[0] < e50[0] && e50[0] < e200[0]);
      if(bullStack) score += 30.0;
      if(bearStack) score -= 30.0;
   }

   // H1 macro trend
   double e50H1[1], e200H1[1];
   if(CopyBuffer(g_ema50_H1,  0, 0, 1, e50H1)  == 1 &&
      CopyBuffer(g_ema200_H1, 0, 0, 1, e200H1) == 1) {
      score += (e50H1[0] > e200H1[0]) ? 20.0 : -20.0;
   }

   return MathMax(-100.0, MathMin(100.0, score));
}

//-----------------------------------------------------------------------
//  L7 – Liquidity Hunt Detection
//  Returns signed score -100..+100
//-----------------------------------------------------------------------
double LayerLiquidity()
{
   double score = 0.0;

   // Stop hunt detection: wick past swing then reversal
   double hi[6], lo[6], op[6], cl[6];
   if(CopyHigh(Symbol(),  PERIOD_M5, 0, 6, hi) == 6 &&
      CopyLow(Symbol(),   PERIOD_M5, 0, 6, lo) == 6 &&
      CopyOpen(Symbol(),  PERIOD_M5, 0, 6, op) == 6 &&
      CopyClose(Symbol(), PERIOD_M5, 0, 6, cl) == 6) {

      // Swing high/low from candles 2–5
      double swHigh = hi[ArrayMaximum(hi, 2, 4)];
      double swLow  = lo[ArrayMinimum(lo, 2, 4)];

      // Current candle (index 0)
      bool wickAbove = (hi[0] > swHigh) && (cl[0] < swHigh);   // Wick above then closed back
      bool wickBelow = (lo[0] < swLow)  && (cl[0] > swLow);    // Wick below then closed back

      if(wickBelow) score += 50.0;   // Liquidity grab below → long opportunity
      if(wickAbove) score -= 50.0;   // Liquidity grab above → short opportunity

      // Fake breakout: previous candle broke out, current candle reversed strongly
      bool prevBroke = hi[1] > swHigh;
      bool curReversed = cl[0] < op[0] && cl[0] < swHigh;
      if(prevBroke && curReversed) score -= 30.0;   // Bearish sweep-and-reverse

      prevBroke    = lo[1] < swLow;
      curReversed  = cl[0] > op[0] && cl[0] > swLow;
      if(prevBroke && curReversed) score += 30.0;   // Bullish sweep-and-reverse
   }

   return MathMax(-100.0, MathMin(100.0, score));
}

//-----------------------------------------------------------------------
//  L8/L9 helper: Classify BTC Session
//-----------------------------------------------------------------------
void ClassifySession()
{
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   int h = dt.hour;

   if(h >= 13 && h < 17) { g_sessionTxt = "NY/LON OVERLAP"; g_sessionColor = C_GREEN;  }
   else if(h >= 8  && h < 13) { g_sessionTxt = "LONDON";        g_sessionColor = C_CYAN;  }
   else if(h >= 13 && h < 22) { g_sessionTxt = "NEW YORK";      g_sessionColor = C_LBLUE; }
   else                        { g_sessionTxt = "ASIAN";         g_sessionColor = C_MGRAY; }
}

bool SessionAllowed()
{
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   int h = dt.hour;

   bool overlap = (h >= 13 && h < 17);
   bool london  = (h >= 8  && h < 13);
   bool ny      = (h >= 13 && h < 22);
   bool asian   = (h < 8   || h >= 22);

   if(overlap && InpAllowOverlap) return true;
   if(london  && InpAllowLondon)  return true;
   if(ny      && InpAllowNY)      return true;
   if(asian   && InpAllowAsian)   return true;
   return false;
}

//-----------------------------------------------------------------------
//  L9: Classify Market Regime
//-----------------------------------------------------------------------
void ClassifyRegime()
{
   double adx[1];
   if(CopyBuffer(g_adx_M5, 0, 0, 1, adx) < 1) { g_regimeTxt = "UNKNOWN"; g_regimeColor = C_MGRAY; return; }

   double atrRatio = (g_atrAvg > 0) ? g_atrCurrent / g_atrAvg : 1.0;

   if(adx[0] > 40 && atrRatio > 1.5)       { g_regimeTxt = "EXPANSION";   g_regimeColor = C_BTCORG; }
   else if(adx[0] > 25)                     { g_regimeTxt = "TRENDING";    g_regimeColor = C_GREEN;  }
   else if(atrRatio < 0.7)                  { g_regimeTxt = "COMPRESSION"; g_regimeColor = C_PURPLE; }
   else if(atrRatio > 2.5)                  { g_regimeTxt = "VOL SHOCK";   g_regimeColor = C_RED;    }
   else                                     { g_regimeTxt = "RANGING";     g_regimeColor = C_CYAN;   }
}

//-----------------------------------------------------------------------
//  L10: Grade Signal Quality
//-----------------------------------------------------------------------
int GradeSignal(double score)
{
   if(score >= 90) return 5;   // Elite
   if(score >= 82) return 4;   // Institutional
   if(score >= 72) return 3;   // Strong
   if(score >= 60) return 2;   // Average
   if(score >= 50) return 1;   // Weak
   return 0;
}
string GradeText(int g)
{
   switch(g) {
      case 5: return "ELITE";
      case 4: return "INSTITUTIONAL";
      case 3: return "STRONG";
      case 2: return "AVERAGE";
      case 1: return "WEAK";
      default: return "NONE";
   }
}
color GradeColor(int g)
{
   switch(g) {
      case 5: return C_BTCORG;
      case 4: return C_GREEN;
      case 3: return C_CYAN;
      case 2: return C_GOLD;
      case 1: return C_MGRAY;
      default: return C_RED;
   }
}

//-----------------------------------------------------------------------
//  Market Readiness Score (0–100 composite)
//-----------------------------------------------------------------------
double ComputeReadiness()
{
   // Readiness = how many layers are aligned (positive or negative strongly)
   double r = 0.0;
   double layers[] = {g_scoreStructure, g_scoreSmartMoney, g_scoreVolatility,
                      g_scoreVolume, g_scoreMomentum, g_scoreTrend, g_scoreLiquidity};
   for(int i = 0; i < 7; i++)
      r += MathAbs(layers[i]);
   r /= 7.0;
   return MathMin(100.0, r);
}

//-----------------------------------------------------------------------
//  Volatility Guard
//-----------------------------------------------------------------------
bool VolatilityAllowed()
{
   if(g_atrAvg <= 0) return true;   // Not yet measured – allow
   double ratio = g_atrCurrent / g_atrAvg;
   return (ratio >= InpMinATRMultiple && ratio <= InpMaxATRMultiple);
}

//-----------------------------------------------------------------------
//  Indicator Warm-up Guard
//-----------------------------------------------------------------------
bool IndicatorsWarmedUp()
{
   double tmp[1];
   // Check the slowest indicator (EMA200 M5 needs 200+ bars)
   if(CopyBuffer(g_ema200_M5,  0, 0, 1, tmp) < 1) return false;
   if(CopyBuffer(g_ema200_M15, 0, 0, 1, tmp) < 1) return false;
   if(CopyBuffer(g_ema200_H1,  0, 0, 1, tmp) < 1) return false;
   if(CopyBuffer(g_atr_M5,     0, 0, 1, tmp) < 1) return false;
   g_indicatorsReady = true;
   return true;
}

//=======================================================================
//  EXECUTION ENGINE  (PRESERVED FROM PHANTOM SCALPER PRO — UNCHANGED)
//=======================================================================
void ResetAnalysis()
{
   ZeroMemory(g_tickBuffer);
   g_tickCount      = 0;
   g_lastAction     = "Analysis reset.";
}

void UpdateTickBuffer()
{
   MqlTick tick;
   if(SymbolInfoTick(Symbol(), tick)) {
      if(g_tickCount < InpTickBufferSize) {
         g_tickBuffer[g_tickCount] = tick;
         g_tickCount++;
      } else {
         for(int i = 0; i < InpTickBufferSize-1; i++)
            g_tickBuffer[i] = g_tickBuffer[i+1];
         g_tickBuffer[InpTickBufferSize-1] = tick;
      }
   }
}

bool OpenBulkTrades(ENUM_ORDER_TYPE otype)
{
   double price = (otype == ORDER_TYPE_BUY) ?
      SymbolInfoDouble(Symbol(), SYMBOL_ASK) :
      SymbolInfoDouble(Symbol(), SYMBOL_BID);
   if(price <= 0.0) return false;

   int    tierIndex = MathMin(g_consecutiveLosses, 4);
   double targetLot = InpBaseLotSize * g_recoveryTiers[tierIndex];

   double lotMin  = SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_MIN);
   double lotMax  = SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_MAX);
   double lotStep = SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_STEP);
   double lot     = MathMax(lotMin, MathMin(lotMax, MathRound(targetLot / lotStep) * lotStep));

   double sl = 0.0, tp = 0.0;
   if(InpStopLossPct > 0.0)
      sl = (otype == ORDER_TYPE_BUY) ?
         NPrice(price * (1.0 - InpStopLossPct / 100.0)) :
         NPrice(price * (1.0 + InpStopLossPct / 100.0));
   AdjustStops(price, otype, sl, tp);

   bool allSuccess = true;
   g_lastAction = StringFormat("Bulk %s x%d | Lot:%.3f | Tier%d | Grade:%s",
                    EnumToString(otype), InpBulkTrades, lot, tierIndex, g_signalGradeTxt);

   for(int i = 0; i < InpBulkTrades; i++) {
      bool ok = (otype == ORDER_TYPE_BUY) ?
         g_trade.Buy(lot,  Symbol(), price, sl, tp, InpBotName) :
         g_trade.Sell(lot, Symbol(), price, sl, tp, InpBotName);
      if(!ok) allSuccess = false;
   }

   if(allSuccess) g_sessTradesToday += InpBulkTrades;
   return allSuccess;
}

void CloseAllPositions()
{
   for(int i = PositionsTotal()-1; i >= 0; i--) {
      if(!g_pos.SelectByIndex(i)) continue;
      if(g_pos.Magic() != InpMagicNumber || g_pos.Symbol() != Symbol()) continue;
      g_trade.PositionClose(g_pos.Ticket());
   }
}

bool HasPosition()
{
   for(int i = PositionsTotal()-1; i >= 0; i--)
      if(g_pos.SelectByIndex(i) && g_pos.Magic() == InpMagicNumber && g_pos.Symbol() == Symbol())
         return true;
   return false;
}

double GetFloatPL()
{
   double t = 0;
   for(int i = PositionsTotal()-1; i >= 0; i--)
      if(g_pos.SelectByIndex(i) && g_pos.Magic() == InpMagicNumber && g_pos.Symbol() == Symbol())
         t += g_pos.Profit() + g_pos.Swap() + g_pos.Commission();
   return t;
}

int GetConsecutiveLosses()
{
   int losses = 0;
   if(!HistorySelect(0, TimeCurrent())) return 0;
   for(int i = HistoryDealsTotal()-1; i >= 0; i--) {
      ulong tk = HistoryDealGetTicket(i);
      if(HistoryDealGetInteger(tk, DEAL_MAGIC) != (long)InpMagicNumber) continue;
      if(HistoryDealGetString(tk,  DEAL_SYMBOL) != Symbol()) continue;
      if(HistoryDealGetInteger(tk, DEAL_ENTRY) == DEAL_ENTRY_OUT) {
         double pnl = HistoryDealGetDouble(tk, DEAL_PROFIT) +
                      HistoryDealGetDouble(tk, DEAL_SWAP)   +
                      HistoryDealGetDouble(tk, DEAL_COMMISSION);
         if(pnl < 0) losses++; else break;
      }
   }
   return losses;
}

bool IsMarketOpen()
{
   ENUM_SYMBOL_TRADE_MODE m = (ENUM_SYMBOL_TRADE_MODE)SymbolInfoInteger(Symbol(), SYMBOL_TRADE_MODE);
   return (m == SYMBOL_TRADE_MODE_FULL ||
           m == SYMBOL_TRADE_MODE_LONGONLY ||
           m == SYMBOL_TRADE_MODE_SHORTONLY);
}

bool DailyLimitsOK()
{
   double bal = AccountInfoDouble(ACCOUNT_BALANCE);
   if(bal <= 0) return true;
   if(InpMaxDailyTrades > 0 && g_sessTradesToday >= InpMaxDailyTrades) return false;
   if(InpMaxDailyLossPct   > 0.0 && g_sessProfit < -(bal * InpMaxDailyLossPct   / 100.0)) return false;
   if(InpMaxDailyProfitPct > 0.0 && g_sessProfit >= (bal * InpMaxDailyProfitPct / 100.0)) return false;
   return true;
}

void AdjustStops(double price, ENUM_ORDER_TYPE otype, double &sl, double &tp)
{
   int    stopsLevel = (int)SymbolInfoInteger(Symbol(), SYMBOL_TRADE_STOPS_LEVEL);
   double point      = SymbolInfoDouble(Symbol(), SYMBOL_POINT);
   double minDist    = stopsLevel * point;
   if(otype == ORDER_TYPE_BUY) {
      if(sl > 0.0 && (price - sl) < minDist) sl = NPrice(price - minDist);
      if(tp > 0.0 && (tp - price) < minDist) tp = NPrice(price + minDist);
   } else {
      if(sl > 0.0 && (sl - price) < minDist) sl = NPrice(price + minDist);
      if(tp > 0.0 && (price - tp) < minDist) tp = NPrice(price - minDist);
   }
}

double NPrice(double p) { return NormalizeDouble(p, (int)SymbolInfoInteger(Symbol(), SYMBOL_DIGITS)); }

ENUM_ORDER_TYPE_FILLING GetFillMode()
{
   uint f = (uint)SymbolInfoInteger(Symbol(), SYMBOL_FILLING_MODE);
   if((f & SYMBOL_FILLING_FOK) != 0) return ORDER_FILLING_FOK;
   if((f & SYMBOL_FILLING_IOC) != 0) return ORDER_FILLING_IOC;
   return ORDER_FILLING_RETURN;
}

datetime DayStart(datetime ts)
{
   MqlDateTime d; TimeToStruct(ts, d);
   return ts - (datetime)(d.hour*3600 + d.min*60 + d.sec);
}

void RestoreSession()
{
   datetime ds = DayStart(TimeCurrent());
   if(!HistorySelect(ds, TimeCurrent())) return;
   for(int i = 0; i < HistoryDealsTotal(); i++) {
      ulong tk = HistoryDealGetTicket(i);
      if((ulong)HistoryDealGetInteger(tk, DEAL_MAGIC) == InpMagicNumber &&
          HistoryDealGetString(tk, DEAL_SYMBOL) == Symbol() &&
          HistoryDealGetInteger(tk, DEAL_ENTRY) == DEAL_ENTRY_IN)
         g_sessTradesToday++;
   }
}

void BuildSessionStats()
{
   g_sessProfit = 0.0; g_sessWins = 0; g_sessLosses = 0;
   if(!HistorySelect(DayStart(TimeCurrent()), TimeCurrent())) return;
   for(int i = 0; i < HistoryDealsTotal(); i++) {
      ulong tk = HistoryDealGetTicket(i);
      if((ulong)HistoryDealGetInteger(tk, DEAL_MAGIC) != InpMagicNumber ||
          HistoryDealGetString(tk, DEAL_SYMBOL) != Symbol()) continue;
      if(HistoryDealGetInteger(tk, DEAL_ENTRY) == DEAL_ENTRY_OUT) {
         double pnl = HistoryDealGetDouble(tk, DEAL_PROFIT) +
                      HistoryDealGetDouble(tk, DEAL_SWAP)   +
                      HistoryDealGetDouble(tk, DEAL_COMMISSION);
         g_sessProfit += pnl;
         if(pnl >= 0) g_sessWins++; else g_sessLosses++;
      }
   }
}

//=======================================================================
//  DASHBOARD GUI  (UPGRADED FOR APEX BTC SCALPER 10-LAYER ENGINE)
//=======================================================================
void R(string nm,int x,int y,int w,int h,color bg,color brd=clrNONE,int bw=1)
{
   string n = D + nm;
   if(ObjectFind(0,n)>=0) ObjectDelete(0,n);
   ObjectCreate(0,n,OBJ_RECTANGLE_LABEL,0,0,0);
   ObjectSetInteger(0,n,OBJPROP_CORNER,CORNER_LEFT_UPPER);
   ObjectSetInteger(0,n,OBJPROP_XDISTANCE,x);
   ObjectSetInteger(0,n,OBJPROP_YDISTANCE,y);
   ObjectSetInteger(0,n,OBJPROP_XSIZE,w);
   ObjectSetInteger(0,n,OBJPROP_YSIZE,h);
   ObjectSetInteger(0,n,OBJPROP_BGCOLOR,bg);
   if(brd!=clrNONE){ObjectSetInteger(0,n,OBJPROP_BORDER_TYPE,BORDER_FLAT);ObjectSetInteger(0,n,OBJPROP_COLOR,brd);ObjectSetInteger(0,n,OBJPROP_WIDTH,bw);}
   else ObjectSetInteger(0,n,OBJPROP_BORDER_TYPE,BORDER_RAISED);
   ObjectSetInteger(0,n,OBJPROP_SELECTABLE,false);
   ObjectSetInteger(0,n,OBJPROP_HIDDEN,true);
}

void L(string nm,int x,int y,string txt,color clr,int fsz,string fnt="Arial Bold")
{
   string n = D + nm;
   if(ObjectFind(0,n)>=0) ObjectDelete(0,n);
   ObjectCreate(0,n,OBJ_LABEL,0,0,0);
   ObjectSetInteger(0,n,OBJPROP_CORNER,CORNER_LEFT_UPPER);
   ObjectSetInteger(0,n,OBJPROP_XDISTANCE,x);
   ObjectSetInteger(0,n,OBJPROP_YDISTANCE,y);
   ObjectSetString (0,n,OBJPROP_TEXT,txt);
   ObjectSetInteger(0,n,OBJPROP_COLOR,clr);
   ObjectSetInteger(0,n,OBJPROP_FONTSIZE,fsz);
   ObjectSetString (0,n,OBJPROP_FONT,fnt);
   ObjectSetInteger(0,n,OBJPROP_SELECTABLE,false);
   ObjectSetInteger(0,n,OBJPROP_HIDDEN,true);
}

void U(string nm,string txt,color clr=C'220,225,240')
{
   string n = D + nm;
   if(ObjectFind(0,n)>=0){ObjectSetString(0,n,OBJPROP_TEXT,txt);ObjectSetInteger(0,n,OBJPROP_COLOR,clr);}
}

void Bar(string nm,int x,int y,int w,int h,double pct,color fg,color bg_c)
{
   R(nm+"_bg",x,y,w,h,bg_c,C_BORDER,1);
   int fw=(int)MathMax(2,MathRound(pct/100.0*(w-2)));
   R(nm+"_fg",x+1,y+1,fw,h-2,fg,clrNONE);
}

void UpdBar(string nm,double pct,color fg)
{
   string n=D+nm+"_fg"; string nb=D+nm+"_bg";
   int w=0;
   if(ObjectFind(0,nb)>=0) w=(int)ObjectGetInteger(0,nb,OBJPROP_XSIZE);
   if(w<=0) return;
   int fw=(int)MathMax(2,MathRound(pct/100.0*(w-2)));
   if(ObjectFind(0,n)>=0){ObjectSetInteger(0,n,OBJPROP_XSIZE,fw);ObjectSetInteger(0,n,OBJPROP_BGCOLOR,fg);}
}

void InitDash()
{
   int X=InpDashX, Y=InpDashY;

   // ── Outer frame ──────────────────────────────────────────────────
   R("frame_outer",X,  Y,  DW,  DH,  C_BG0, C_ACBORD, 2);
   R("frame_inner",X+2,Y+2,DW-4,DH-4,C_BG0, C_BORDER, 1);

   // ── Header ───────────────────────────────────────────────────────
   R("hdr_bg",  X+2,  Y+2,  DW-4,80, C_HDRBAR,C_BORDER,1);
   R("hdr_acc", X+2,  Y+2,  DW-4, 3, C_ACBORD);
   L("h_name",  X+10, Y+10, InpBotName,                    C_BTCORG,13,"Arial Black");
   L("h_tag",   X+10, Y+32, "10-Layer Institutional BTC Signal Engine",C_CYAN,7,"Arial");
   L("h_ver",   X+10, Y+46, "v1.0  +  Magic:" + IntegerToString((long)InpMagicNumber) + "  +  " + Symbol(),C_LBLUE,7,"Arial");
   R("live_bg", X+DW-82,Y+8,66,22,C_DKGREEN,C_GREEN,1);
   L("live_lbl",X+DW-74,Y+12,"● LIVE",C_GREEN,7,"Arial Bold");
   R("div_hdr", X+2,Y+82,DW-4,2,C_ACBORD);

   // ── Status row ───────────────────────────────────────────────────
   R("stat_bg", X+2, Y+86,DW-4,30,C_BG2,C_BORDER,1);
   L("lb_stat", X+14,Y+93,"STATUS",    C_SUBTEXT,8,"Arial");
   L("vl_stat", X+90,Y+93,"WARMING UP",C_ORANGE, 9,"Arial Black");
   L("lb_act",  X+240,Y+93,"Action:",  C_SUBTEXT,7,"Arial");
   L("vl_act",  X+285,Y+93,"--",       C_WHITE,  7,"Arial");
   R("div_stat",X+2,Y+118,DW-4,1,C_BORDER);

   // ── Section A: Performance ────────────────────────────────────────
   int ay = Y+122;
   R("sec_a",   X+2, ay,   DW-4,148,C_BG1,C_BORDER,1);
   R("sec_a_hd",X+2, ay,   DW-4, 22,C_HDRBAR,C_BORDER,1);
   L("sec_a_lb",X+10,ay+4, "▸  PERFORMANCE & RISK",C_GOLD,8,"Arial Black");

   L("lb_sp",X+14,ay+26,"Session Profit",       C_SUBTEXT,8,"Arial"); L("vl_sp",X+210,ay+26,"$ 0.00",C_WHITE,9,"Arial Bold");
   L("lb_fp",X+14,ay+42,"Floating P&L",         C_SUBTEXT,8,"Arial"); L("vl_fp",X+210,ay+42,"$ 0.00",C_WHITE,9,"Arial Bold");
   L("lb_dd",X+14,ay+58,"Drawdown",             C_SUBTEXT,8,"Arial"); L("vl_dd",X+210,ay+58,"0.00 %",C_WHITE,9,"Arial Bold");
   Bar("dd_bar",X+310,ay+60,130,12,0,C_RED,C_DGRAY);
   L("lb_tt",X+14,ay+74,"Trades Today",         C_SUBTEXT,8,"Arial"); L("vl_tt",X+210,ay+74,"0 / "+IntegerToString(InpMaxDailyTrades),C_WHITE,9,"Arial Bold");
   L("lb_rcv",X+14,ay+90,"Recovery Tier",       C_SUBTEXT,8,"Arial"); L("vl_rcv",X+210,ay+90,"Tier 0 (1.0x)",C_WHITE,9,"Arial Bold");
   L("lb_wr",X+14,ay+106,"Win / Loss",          C_SUBTEXT,8,"Arial"); L("vl_wr",X+210,ay+106,"0 / 0",C_WHITE,9,"Arial Bold");

   // ── Section B: Signal Intelligence ───────────────────────────────
   int by = ay + 152;
   R("sec_b",   X+2, by,   DW-4,128,C_BG1,C_BORDER,1);
   R("sec_b_hd",X+2, by,   DW-4, 22,C_HDRBAR,C_BORDER,1);
   L("sec_b_lb",X+10,by+4, "▸  SIGNAL INTELLIGENCE",C_GOLD,8,"Arial Black");

   L("lb_buy",X+14,by+26,"Buy Score",    C_SUBTEXT,8,"Arial"); L("vl_buy",X+150,by+26,"0.0",C_GREEN,10,"Arial Bold");
   Bar("buy_bar",X+220,by+28,210,13,0,C_GREEN,C_DGRAY);
   L("lb_sell",X+14,by+44,"Sell Score",  C_SUBTEXT,8,"Arial"); L("vl_sell",X+150,by+44,"0.0",C_RED,10,"Arial Bold");
   Bar("sell_bar",X+220,by+46,210,13,0,C_RED,C_DGRAY);
   L("lb_grade",X+14,by+62,"Signal Grade",C_SUBTEXT,8,"Arial"); L("vl_grade",X+150,by+62,"NONE",C_MGRAY,9,"Arial Black");
   L("lb_ready",X+14,by+80,"Readiness",  C_SUBTEXT,8,"Arial"); L("vl_ready",X+150,by+80,"0.0 %",C_WHITE,9,"Arial Bold");
   Bar("rdy_bar",X+220,by+82,210,13,0,C_PURPLE,C_DGRAY);
   L("lb_regime",X+14,by+98,"BTC Regime",C_SUBTEXT,8,"Arial"); L("vl_regime",X+150,by+98,"UNKNOWN",C_MGRAY,9,"Arial Bold");
   L("lb_sess",X+270,by+98,"Session:",   C_SUBTEXT,7,"Arial"); L("vl_sess",X+320,by+98,"---",C_MGRAY,8,"Arial Bold");

   // ── Section C: 7-Layer Score Matrix ──────────────────────────────
   int cy = by + 132;
   R("sec_c",   X+2, cy,   DW-4,210,C_BG2,C_BORDER,1);
   R("sec_c_hd",X+2, cy,   DW-4, 22,C_HDRBAR,C_BORDER,1);
   L("sec_c_lb",X+10,cy+4, "▸  10-LAYER SCORE MATRIX",C_GOLD,8,"Arial Black");

   string lnames[] = {"L1 Structure","L2 SmartMoney","L3 Volatility","L4 Volume","L5 Momentum","L6 Trend","L7 Liquidity"};
   string lids[]   = {"str","smc","vol","vlm","mom","trd","liq"};
   for(int i=0;i<7;i++) {
      int ry = cy+26+i*26;
      L("lbl_"+lids[i],X+14,ry,lnames[i],C_SUBTEXT,7,"Arial");
      L("val_"+lids[i],X+150,ry,"0.0",C_WHITE,8,"Arial Bold");
      Bar("bar_"+lids[i],X+210,ry+2,220,14,50,C_CYAN,C_DGRAY);
   }

   // ── Section D: Config strip ───────────────────────────────────────
   int dy = cy + 214;
   R("sec_d",X+2,dy,DW-4,60,C_BG2,C_BORDER,1);
   L("cfg1",X+14,dy+6, "Lot:"+DoubleToString(InpBaseLotSize,2)+"  Bulk:"+IntegerToString(InpBulkTrades)+"  MinScore:B"+DoubleToString(InpMinBuyScore,0)+"/S"+DoubleToString(InpMinSellScore,0), C_LBLUE,7,"Arial");
   L("cfg2",X+14,dy+22,"ATR: "+DoubleToString(InpMinATRMultiple,1)+"x–"+DoubleToString(InpMaxATRMultiple,1)+"x  Grade≥"+GradeText(InpMinGradeForEntry), C_LBLUE,7,"Arial");
   L("cfg3",X+14,dy+38,"Sessions: "+
      (string)(InpAllowLondon?"LON ":"")+(string)(InpAllowNY?"NY ":"")+(string)(InpAllowOverlap?"OVL ":"")+(string)(InpAllowAsian?"ASN":""),
      C_LBLUE,7,"Arial");

   // ── Footer ────────────────────────────────────────────────────────
   int fy = dy + 64;
   R("ftr",X+2,fy,DW-4,16,C_HDRBAR,C_BORDER,1);
   L("ft_time",X+10,fy+3,"Server: --:--",C_MGRAY,7,"Arial");
   L("ft_atr", X+240,fy+3,"ATR: --",     C_MGRAY,7,"Arial");

   ChartRedraw(0);
}

void UpdateDash()
{
   if(!InpShowDash) return;
   int X=InpDashX;

   double floatPL = GetFloatPL();

   // Status
   U("vl_stat",g_statusText,g_statusColor);
   U("vl_act", g_lastAction, C_SUBTEXT);

   // Performance
   U("vl_sp",  "$ "+DoubleToString(g_sessProfit,2), (g_sessProfit>=0)?C_GREEN:C_RED);
   U("vl_fp",  "$ "+DoubleToString(floatPL,2),      (floatPL>=0)?C_GREEN:C_RED);
   U("vl_dd",  DoubleToString(g_drawdown,2)+" %",   (g_drawdown<5)?C_GREEN:C_RED);
   UpdBar("dd_bar",MathMin(g_drawdown*5.0,100.0),(g_drawdown<5)?C_GREEN:C_RED);
   U("vl_tt",  IntegerToString(g_sessTradesToday)+" / "+IntegerToString(InpMaxDailyTrades),C_WHITE);
   int ti=MathMin(g_consecutiveLosses,4);
   U("vl_rcv", "Tier "+IntegerToString(ti)+" ("+DoubleToString(g_recoveryTiers[ti],1)+"x)",(ti>0)?C_ORANGE:C_GREEN);
   U("vl_wr",  IntegerToString(g_sessWins)+" W  /  "+IntegerToString(g_sessLosses)+" L",
               (g_sessWins>=g_sessLosses)?C_GREEN:C_RED);

   // Signal Intelligence
   U("vl_buy",  DoubleToString(g_buyScore,1),  (g_buyScore  >= InpMinBuyScore) ?C_GREEN:C_WHITE);
   U("vl_sell", DoubleToString(g_sellScore,1), (g_sellScore >= InpMinSellScore)?C_RED:C_WHITE);
   UpdBar("buy_bar",  g_buyScore,  (g_buyScore  >= InpMinBuyScore)?C_GREEN:C_MGRAY);
   UpdBar("sell_bar", g_sellScore, (g_sellScore >= InpMinSellScore)?C_RED:C_MGRAY);
   U("vl_grade", g_signalGradeTxt,  g_signalGradeColor);
   U("vl_ready", DoubleToString(g_readinessScore,1)+" %", (g_readinessScore>=70)?C_GREEN:(g_readinessScore>=40)?C_GOLD:C_RED);
   UpdBar("rdy_bar",g_readinessScore,C_PURPLE);
   U("vl_regime",g_regimeTxt,  g_regimeColor);
   U("vl_sess",  g_sessionTxt, g_sessionColor);

   // 7-Layer matrix
   double scores[]  = {g_scoreStructure,g_scoreSmartMoney,g_scoreVolatility,
                        g_scoreVolume,g_scoreMomentum,g_scoreTrend,g_scoreLiquidity};
   string lids[]    = {"str","smc","vol","vlm","mom","trd","liq"};
   for(int i=0;i<7;i++) {
      double s = scores[i];
      double barPct = (s + 100.0) / 2.0;   // Map -100..+100 → 0..100
      color c = (s >  15)?C_GREEN:(s < -15)?C_RED:C_GOLD;
      U("val_"+lids[i], (s>=0?"+":"")+DoubleToString(s,1), c);
      UpdBar("bar_"+lids[i], barPct, c);
   }

   // Footer
   U("ft_time","Server: "+TimeToString(TimeCurrent(),TIME_SECONDS)+"  |  Local: "+TimeToString(TimeLocal(),TIME_MINUTES),C_DGRAY);
   U("ft_atr", "ATR: "+DoubleToString(g_atrCurrent,1)+"  Avg: "+DoubleToString(g_atrAvg,1), C_DGRAY);

   ChartRedraw(0);
}

void DeleteDash() { ObjectsDeleteAll(0,D); ChartRedraw(0); }
//+------------------------------------------------------------------+