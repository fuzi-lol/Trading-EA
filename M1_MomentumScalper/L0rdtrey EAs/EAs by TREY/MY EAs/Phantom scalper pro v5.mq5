//+------------------------------------------------------------------+
//|         PHANTOM SCALPER PRO  –  Institutional AI Edition v5.0    |
//|         Multi-Layer Confluence | SMC | ML | Microstructure        |
//|         24/5 Autonomous XAUUSD Strategic Scalping System          |
//+------------------------------------------------------------------+
#property copyright   "PHANTOM SCALPER PRO AI v5.0"
#property version     "5.00"
#property description "Institutional XAUUSD Scalper | SMC | Regime | ML | Dynamic Exit"

#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>
#include <Trade\AccountInfo.mqh>

//=======================================================================
//  DASHBOARD PREFIX
//=======================================================================
#define D "PSP5_"

//=======================================================================
//  COLOUR PALETTE
//=======================================================================
#define C_BG0       C'4,6,18'
#define C_BG1       C'8,12,28'
#define C_BG2       C'12,18,42'
#define C_HDRBAR    C'10,16,38'
#define C_BORDER    C'22,44,90'
#define C_ACBORD    C'0,160,220'
#define C_GOLD      C'255,200,40'
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
#define C_PINK      C'255,80,160'

//=======================================================================
//  ENUMERATIONS
//=======================================================================
enum ENUM_MARKET_REGIME {
   REGIME_TRENDING_BULL,
   REGIME_TRENDING_BEAR,
   REGIME_RANGING,
   REGIME_VOLATILITY_EXPANSION,
   REGIME_COMPRESSION,
   REGIME_LOW_LIQUIDITY,
   REGIME_BREAKOUT,
   REGIME_REVERSAL,
   REGIME_UNDEFINED
};

enum ENUM_SESSION {
   SESSION_ASIA,
   SESSION_LONDON,
   SESSION_NY,
   SESSION_OVERLAP_LDN_NY,
   SESSION_OFF
};

enum ENUM_TRADE_GRADE {
   GRADE_A_PLUS,
   GRADE_A,
   GRADE_B,
   GRADE_NO_TRADE
};

//=======================================================================
//  INPUT PARAMETERS
//=======================================================================
input group "╔══════  IDENTITY  ══════╗"
input ulong  InpMagicNumber         = 99999;
input string InpBotName             = "PHANTOM SCALPER AI v5.0";

input group "╔══════  RISK & POSITION SIZING  ══════╗"
input double InpRiskPctPerTrade     = 0.5;       // Risk % per trade of balance
input double InpMaxDailyLossPct     = 4.0;       // Max daily loss %
input double InpMaxDailyProfitPct   = 8.0;       // Max daily profit %
input int    InpMaxDailyTrades      = 10;        // Max trades per day
input double InpMinLot              = 0.01;      // Minimum lot size
input double InpMaxLot              = 1.00;      // Maximum lot size

input group "╔══════  TRADE FILTERS  ══════╗"
input double InpMinAIConfidence     = 0.78;      // Min AI confidence [0.0-1.0]
input double InpMinMLConfidence     = 0.72;      // Min ML direction confidence
input int    InpMinConfluenceLayers = 4;         // Min layers agreeing (max 7)
input double InpMaxSpreadPoints     = 40.0;      // Max allowed spread (points)
input int    InpCooldownSec         = 90;        // Cooldown after close (seconds)

input group "╔══════  DYNAMIC EXIT  ══════╗"
input double InpBaseProfitUSDPer01  = 1.20;      // $ target per 0.01 lot
input double InpStopLossPct         = 1.2;       // SL % from entry
input bool   InpUseTrailingStop     = true;
input double InpTrailActivatePct    = 0.6;       // Trail activates after X% profit
input double InpTrailDistancePct    = 0.35;      // Trail distance from peak
input bool   InpUsePartialClose     = true;
input double InpPartialClosePct     = 50.0;      // % of position to close at 50% TP

input group "╔══════  MICROSTRUCTURE  ══════╗"
input int    InpTickBufferSize      = 600;       // Rolling tick buffer size

input group "╔══════  SESSION FILTERS  ══════╗"
input bool   InpTradeAsia           = false;     // Allow Asia session trades
input bool   InpTradeLondon         = true;
input bool   InpTradeNewYork        = true;
input bool   InpTradeOverlap        = true;

input group "╔══════  NEWS FILTER  ══════╗"
input bool   InpNewsFilterEnabled   = true;
input int    InpNewsPauseBefore     = 30;        // Minutes before news
input int    InpNewsPauseAfter      = 20;        // Minutes after news

input group "╔══════  CONSECUTIVE LOSS GUARD  ══════╗"
input int    InpMaxConsecLosses     = 3;
input int    InpLossStreakCooldownMin= 45;        // Minutes

input group "╔══════  DASHBOARD  ══════╗"
input bool   InpShowDash            = true;
input int    InpDashX               = 14;
input int    InpDashY               = 14;

//=======================================================================
//  CONSTANTS
//=======================================================================
const int    DW = 440;
const int    DH = 760;

//=======================================================================
//  OBJECTS
//=======================================================================
CTrade        g_trade;
CPositionInfo g_pos;
CAccountInfo  g_account;

//=======================================================================
//  INDICATOR HANDLES
//=======================================================================
// M5 Handles
int  g_h_ema9_M5      = INVALID_HANDLE;
int  g_h_ema21_M5     = INVALID_HANDLE;
int  g_h_ema50_M5     = INVALID_HANDLE;
int  g_h_rsi_M5       = INVALID_HANDLE;
int  g_h_atr_M5       = INVALID_HANDLE;
int  g_h_adx_M5       = INVALID_HANDLE;
// M15 Handles
int  g_h_ema21_M15    = INVALID_HANDLE;
int  g_h_ema50_M15    = INVALID_HANDLE;
int  g_h_atr_M15      = INVALID_HANDLE;
// H1 Handles
int  g_h_ema50_H1     = INVALID_HANDLE;
int  g_h_ema200_H1    = INVALID_HANDLE;
int  g_h_atr_H1       = INVALID_HANDLE;
// M1 Handle
int  g_h_ema9_M1      = INVALID_HANDLE;
int  g_h_rsi_M1       = INVALID_HANDLE;

//=======================================================================
//  TICK BUFFER
//=======================================================================
MqlTick  g_tickBuffer[];
int      g_tickCount = 0;

//=======================================================================
//  ANALYSIS STATE (refreshed every M5 bar)
//=======================================================================
struct AnalysisResult {
   // Regime
   ENUM_MARKET_REGIME regime;
   string             regimeStr;
   // Bias
   int                h1Bias;        // +1 bull, -1 bear, 0 neutral
   int                m15Bias;
   int                m5Bias;
   // SMC
   bool               fvgBullish;
   bool               fvgBearish;
   bool               liquiditySweepBull;
   bool               liquiditySweepBear;
   bool               orderBlockBull;
   bool               orderBlockBear;
   bool               bosConfirmed;
   // AI Score
   double             aiConfidenceBuy;
   double             aiConfidenceSell;
   // ML
   double             mlDirectionBuy;
   double             mlDirectionSell;
   // Microstructure
   double             microPressure;   // +1 buy pressure, -1 sell
   double             chiSquareScore;
   // Trade grade
   ENUM_TRADE_GRADE   grade;
   int                confluenceLayers;
   // Session
   ENUM_SESSION       session;
   // ATR
   double             atrM5;
   double             atrH1;
   double             volatilityPct;   // ATR as % of price
};

AnalysisResult g_analysis;
datetime       g_lastBarTime   = 0;
datetime       g_lastCloseTime = 0;
datetime       g_sessionDay    = 0;
datetime       g_lossCooldownUntil = 0;

//=======================================================================
//  SESSION STATS
//=======================================================================
int    g_sessTradesToday   = 0;
double g_sessProfit        = 0.0;
int    g_sessWins          = 0;
int    g_sessLosses        = 0;
int    g_consecutiveLosses = 0;
double g_peakEquity        = 0.0;
double g_drawdown          = 0.0;
bool   g_partialClosed     = false;

//=======================================================================
//  DASHBOARD STATUS
//=======================================================================
string g_statusText  = "WARMING UP";
color  g_statusColor = C_ORANGE;
string g_lastAction  = "Initializing...";
bool   g_inCooldown  = false;
int    g_cooldownLeft= 0;

//=======================================================================
//  FORWARD DECLARATIONS
//=======================================================================
// Analysis
void            RunFullAnalysis();
ENUM_MARKET_REGIME DetectRegime();
void            AnalyzeMultiTFBias();
void            AnalyzeSMC();
double          ScoreAI(int direction);
double          ScoreML(int direction);
double          GetMicrostructurePressure();
double          GetChiSquareDrift();
double          GetLiquidityDelta();
ENUM_TRADE_GRADE GradeSetup(int direction);
ENUM_SESSION    GetCurrentSession();
bool            IsSessionAllowed();
bool            IsNewsTime();
// Execution
bool            ExecuteTrade(int direction);
void            ManageOpenPositions();
void            AttemptPartialClose(double profitTarget);
void            ApplyTrailingStop();
void            CloseAllPositions();
// Helpers
bool            HasPosition();
double          GetFloatPL();
double          CalculateLotSize(double confidenceScore);
bool            IsMarketOpen();
bool            DailyLimitsOK();
bool            SpreadOK();
int             GetConsecutiveLosses();
void            BuildSessionStats();
void            RestoreSession();
void            AdjustStops(double price, ENUM_ORDER_TYPE otype, double &sl, double &tp);
double          NPrice(double p);
ENUM_ORDER_TYPE_FILLING GetFillMode();
datetime        DayStart(datetime ts);
// Indicator reading
double          GetVal(int handle, int shift=0, int buf=0);
// Dashboard
void            InitDash();
void            UpdateDash();
void            DeleteDash();
void            R(string nm,int x,int y,int w,int h,color bg,color brd=clrNONE,int bw=1);
void            L(string nm,int x,int y,string txt,color clr,int fsz,string fnt="Arial Bold");
void            U(string nm,string txt,color clr);
void            Bar(string nm,int x,int y,int w,int h,double pct,color fg,color bg_c);
void            UpdBar(string nm,double pct,color fg);

//=======================================================================
//  OnInit
//=======================================================================
int OnInit()
{
   if(StringFind(Symbol(), "XAU") < 0)
      Print("WARNING: EA tuned for XAUUSD. Current symbol: ", Symbol());

   ArrayResize(g_tickBuffer, InpTickBufferSize);
   ZeroMemory(g_analysis);
   g_analysis.regime = REGIME_UNDEFINED;

   g_trade.SetExpertMagicNumber(InpMagicNumber);
   g_trade.SetDeviationInPoints(30);
   g_trade.SetTypeFilling(GetFillMode());

   // M5
   g_h_ema9_M5   = iMA(Symbol(), PERIOD_M5,  9,  0, MODE_EMA, PRICE_CLOSE);
   g_h_ema21_M5  = iMA(Symbol(), PERIOD_M5,  21, 0, MODE_EMA, PRICE_CLOSE);
   g_h_ema50_M5  = iMA(Symbol(), PERIOD_M5,  50, 0, MODE_EMA, PRICE_CLOSE);
   g_h_rsi_M5    = iRSI(Symbol(), PERIOD_M5, 14, PRICE_CLOSE);
   g_h_atr_M5    = iATR(Symbol(), PERIOD_M5, 14);
   g_h_adx_M5    = iADX(Symbol(), PERIOD_M5, 14);
   // M15
   g_h_ema21_M15 = iMA(Symbol(), PERIOD_M15, 21, 0, MODE_EMA, PRICE_CLOSE);
   g_h_ema50_M15 = iMA(Symbol(), PERIOD_M15, 50, 0, MODE_EMA, PRICE_CLOSE);
   g_h_atr_M15   = iATR(Symbol(), PERIOD_M15,14);
   // H1
   g_h_ema50_H1  = iMA(Symbol(), PERIOD_H1,  50, 0, MODE_EMA, PRICE_CLOSE);
   g_h_ema200_H1 = iMA(Symbol(), PERIOD_H1, 200, 0, MODE_EMA, PRICE_CLOSE);
   g_h_atr_H1    = iATR(Symbol(), PERIOD_H1, 14);
   // M1
   g_h_ema9_M1   = iMA(Symbol(), PERIOD_M1,  9,  0, MODE_EMA, PRICE_CLOSE);
   g_h_rsi_M1    = iRSI(Symbol(), PERIOD_M1, 14, PRICE_CLOSE);

   g_peakEquity  = AccountInfoDouble(ACCOUNT_EQUITY);
   g_sessionDay  = DayStart(TimeCurrent());

   RestoreSession();
   BuildSessionStats();
   g_consecutiveLosses = GetConsecutiveLosses();

   if(InpShowDash) InitDash();
   EventSetTimer(1);

   g_lastAction = "System initialized. Building analysis...";
   return INIT_SUCCEEDED;
}

//=======================================================================
//  OnDeinit
//=======================================================================
void OnDeinit(const int reason)
{
   EventKillTimer();
   DeleteDash();
   int handles[] = {g_h_ema9_M5, g_h_ema21_M5, g_h_ema50_M5, g_h_rsi_M5,
                    g_h_atr_M5, g_h_adx_M5, g_h_ema21_M15, g_h_ema50_M15,
                    g_h_atr_M15, g_h_ema50_H1, g_h_ema200_H1, g_h_atr_H1,
                    g_h_ema9_M1, g_h_rsi_M1};
   for(int i=0; i<ArraySize(handles); i++)
      if(handles[i] != INVALID_HANDLE) IndicatorRelease(handles[i]);
}

//=======================================================================
//  OnTimer  – heartbeat for dashboard, cooldowns, equity tracking
//=======================================================================
void OnTimer()
{
   double eq = AccountInfoDouble(ACCOUNT_EQUITY);
   if(eq > g_peakEquity) g_peakEquity = eq;
   if(g_peakEquity > 0) g_drawdown = (g_peakEquity - eq) / g_peakEquity * 100.0;

   if(g_lastCloseTime > 0) {
      int elapsed = (int)(TimeCurrent() - g_lastCloseTime);
      g_inCooldown   = (elapsed < InpCooldownSec);
      g_cooldownLeft = g_inCooldown ? (InpCooldownSec - elapsed) : 0;
   } else { g_inCooldown = false; g_cooldownLeft = 0; }

   if(InpShowDash) UpdateDash();
}

//=======================================================================
//  OnTick  – Main engine
//=======================================================================
void OnTick()
{
   // Day rollover
   datetime today = DayStart(TimeCurrent());
   if(today != g_sessionDay) {
      g_sessionDay = today;
      g_sessTradesToday = 0;
      g_consecutiveLosses = 0;
      BuildSessionStats();
      g_lastAction = "New trading day.";
   }

   // Market state checks
   if(!IsMarketOpen()) { g_statusText = "MKT CLOSED"; g_statusColor = C_RED; return; }
   if(!SpreadOK())     { g_statusText = "WIDE SPREAD"; g_statusColor = C_ORANGE; return; }

   // Update tick microstructure (every tick)
   UpdateTickBuffer();

   // Open position management (every tick)
   if(HasPosition()) {
      g_statusText = "IN TRADE"; g_statusColor = C_GREEN;
      ManageOpenPositions();
      return;
   }

   // Cooldowns
   if(g_inCooldown) { g_statusText = "COOLDOWN"; g_statusColor = C_CYAN; return; }
   if(TimeCurrent() < g_lossCooldownUntil) {
      g_statusText = "LOSS GUARD"; g_statusColor = C_RED; return;
   }
   if(!DailyLimitsOK()) { g_statusText = "LIMIT HIT"; g_statusColor = C_RED; return; }
   if(!IsSessionAllowed()) { g_statusText = "OFF SESSION"; g_statusColor = C_MGRAY; return; }
   if(InpNewsFilterEnabled && IsNewsTime()) { g_statusText = "NEWS PAUSE"; g_statusColor = C_ORANGE; return; }

   // Re-run full analysis on each new M5 bar
   datetime barTime = iTime(Symbol(), PERIOD_M5, 0);
   if(barTime != g_lastBarTime) {
      g_lastBarTime = barTime;
      RunFullAnalysis();
   }

   // Buffer warmup
   if(g_tickCount < InpTickBufferSize / 2) {
      g_statusText = "BUFFERING"; g_statusColor = C_ORANGE; return;
   }

   // === DECISION ENGINE ===
   int direction = 0;

   // Check buy conditions
   if(g_analysis.grade == GRADE_A_PLUS || g_analysis.grade == GRADE_A) {
      if(g_analysis.aiConfidenceBuy >= InpMinAIConfidence &&
         g_analysis.mlDirectionBuy  >= InpMinMLConfidence)
         direction = 1; // BUY
      else if(g_analysis.aiConfidenceSell >= InpMinAIConfidence &&
              g_analysis.mlDirectionSell  >= InpMinMLConfidence)
         direction = -1; // SELL
   }

   if(direction != 0 && g_analysis.confluenceLayers >= InpMinConfluenceLayers) {
      g_statusText = "EXECUTING"; g_statusColor = C_LBLUE;
      if(ExecuteTrade(direction)) {
         g_sessTradesToday++;
         g_partialClosed = false;
         g_statusText = "IN TRADE"; g_statusColor = C_GREEN;
         g_lastAction  = StringFormat("%s executed | Grade:%s | Conf:%.1f%% | Layers:%d",
            direction==1?"BUY":"SELL",
            g_analysis.grade==GRADE_A_PLUS?"A+":(g_analysis.grade==GRADE_A?"A":"B"),
            (direction==1?g_analysis.aiConfidenceBuy:g_analysis.aiConfidenceSell)*100,
            g_analysis.confluenceLayers);
      } else {
         g_statusText = "OPEN FAIL"; g_statusColor = C_RED;
      }
   } else {
      g_statusText = "ANALYZING"; g_statusColor = C_GOLD;
   }
}

//=======================================================================
//  LAYER 1: MARKET REGIME DETECTION
//=======================================================================
ENUM_MARKET_REGIME DetectRegime()
{
   double atrM5_cur  = GetVal(g_h_atr_M5, 0);
   double atrM5_prev = GetVal(g_h_atr_M5, 5);
   double atrH1_cur  = GetVal(g_h_atr_H1, 0);
   double adxMain    = GetVal(g_h_adx_M5, 0, 0);
   double adxPlus    = GetVal(g_h_adx_M5, 0, 1);
   double adxMinus   = GetVal(g_h_adx_M5, 0, 2);
   double price      = SymbolInfoDouble(Symbol(), SYMBOL_BID);
   double ema50h1    = GetVal(g_h_ema50_H1,  0);
   double ema200h1   = GetVal(g_h_ema200_H1, 0);

   if(price <= 0 || atrM5_cur <= 0) return REGIME_UNDEFINED;

   // Spread proxy for liquidity
   double spread = SymbolInfoInteger(Symbol(), SYMBOL_SPREAD) * SymbolInfoDouble(Symbol(), SYMBOL_POINT);
   if(spread > atrM5_cur * 0.5) return REGIME_LOW_LIQUIDITY;

   // Volatility expansion
   double atrRatio = (atrM5_prev > 0) ? atrM5_cur / atrM5_prev : 1.0;
   if(atrRatio > 1.8) return REGIME_VOLATILITY_EXPANSION;

   // Compression
   if(atrRatio < 0.55 && adxMain < 18) return REGIME_COMPRESSION;

   // Trending
   if(adxMain > 28) {
      if(adxPlus > adxMinus && ema50h1 > ema200h1) return REGIME_TRENDING_BULL;
      if(adxMinus > adxPlus && ema50h1 < ema200h1) return REGIME_TRENDING_BEAR;
   }

   // Ranging
   if(adxMain < 22) return REGIME_RANGING;

   // Breakout from compression
   if(atrRatio > 1.3 && adxMain > 20) return REGIME_BREAKOUT;

   return REGIME_RANGING;
}

string RegimeToStr(ENUM_MARKET_REGIME r)
{
   switch(r) {
      case REGIME_TRENDING_BULL:       return "BULL TREND";
      case REGIME_TRENDING_BEAR:       return "BEAR TREND";
      case REGIME_RANGING:             return "RANGING";
      case REGIME_VOLATILITY_EXPANSION:return "VOL SPIKE";
      case REGIME_COMPRESSION:         return "COMPRESSED";
      case REGIME_LOW_LIQUIDITY:       return "LOW LIQ";
      case REGIME_BREAKOUT:            return "BREAKOUT";
      case REGIME_REVERSAL:            return "REVERSAL";
      default:                         return "UNDEFINED";
   }
}

//=======================================================================
//  LAYER 2: MULTI-TIMEFRAME BIAS
//=======================================================================
void AnalyzeMultiTFBias()
{
   // H1 Bias: EMA50 vs EMA200
   double e50h1  = GetVal(g_h_ema50_H1,  0);
   double e200h1 = GetVal(g_h_ema200_H1, 0);
   double pxH1   = iClose(Symbol(), PERIOD_H1, 0);
   g_analysis.h1Bias = (e50h1 > e200h1 && pxH1 > e50h1) ? 1 : (e50h1 < e200h1 && pxH1 < e50h1) ? -1 : 0;

   // M15 Bias: EMA21 vs EMA50 + BOS check
   double e21m15 = GetVal(g_h_ema21_M15, 0);
   double e50m15 = GetVal(g_h_ema50_M15, 0);
   double hiM15_1 = iHigh(Symbol(), PERIOD_M15, 1);
   double hiM15_5 = iHigh(Symbol(), PERIOD_M15, 5);
   double loM15_1 = iLow(Symbol(), PERIOD_M15, 1);
   double loM15_5 = iLow(Symbol(), PERIOD_M15, 5);
   bool m15BOS_bull = (hiM15_1 > hiM15_5);
   bool m15BOS_bear = (loM15_1 < loM15_5);
   g_analysis.m15Bias = (e21m15 > e50m15 && m15BOS_bull) ? 1 : (e21m15 < e50m15 && m15BOS_bear) ? -1 : 0;

   // M5 Bias: Triple EMA + BOS
   double e9m5  = GetVal(g_h_ema9_M5,  0);
   double e21m5 = GetVal(g_h_ema21_M5, 0);
   double e50m5 = GetVal(g_h_ema50_M5, 0);
   double hiM5_1 = iHigh(Symbol(), PERIOD_M5, 1);
   double hiM5_5 = iHigh(Symbol(), PERIOD_M5, 5);
   double loM5_1 = iLow(Symbol(), PERIOD_M5, 1);
   double loM5_5 = iLow(Symbol(), PERIOD_M5, 5);
   bool m5BOS_bull = (hiM5_1 > hiM5_5);
   bool m5BOS_bear = (loM5_1 < loM5_5);
   g_analysis.bosConfirmed = m5BOS_bull || m5BOS_bear;
   g_analysis.m5Bias = (e9m5 > e21m5 && e21m5 > e50m5 && m5BOS_bull) ? 1 :
                       (e9m5 < e21m5 && e21m5 < e50m5 && m5BOS_bear) ? -1 : 0;
}

//=======================================================================
//  LAYER 3: SMART MONEY CONCEPTS ENGINE
//=======================================================================
void AnalyzeSMC()
{
   // ── Fair Value Gap (3-candle) ──
   // Bullish FVG: candle[-3].high < candle[-1].low  (gap up)
   double hi3 = iHigh(Symbol(), PERIOD_M5, 3);
   double lo1 = iLow(Symbol(), PERIOD_M5, 1);
   g_analysis.fvgBullish = (hi3 < lo1);

   // Bearish FVG: candle[-3].low > candle[-1].high  (gap down)
   double lo3 = iLow(Symbol(), PERIOD_M5, 3);
   double hi1 = iHigh(Symbol(), PERIOD_M5, 1);
   g_analysis.fvgBearish = (lo3 > hi1);

   // ── Liquidity Sweep Detection ──
   // Look for price that swept a recent swing and quickly reversed
   // Bullish sweep: price wicked below prior 10-bar low then closed above
   double lo10 = 999999, hi10 = 0;
   for(int i=2; i<=11; i++) {
      double lo = iLow(Symbol(), PERIOD_M5, i);
      double hi = iHigh(Symbol(), PERIOD_M5, i);
      if(lo < lo10) lo10 = lo;
      if(hi > hi10) hi10 = hi;
   }
   double curLow   = iLow(Symbol(),  PERIOD_M5, 1);
   double curHigh  = iHigh(Symbol(), PERIOD_M5, 1);
   double curClose = iClose(Symbol(), PERIOD_M5, 1);
   double curOpen  = iOpen(Symbol(),  PERIOD_M5, 1);

   // Bullish sweep: wick below 10-bar low, closes bullish
   g_analysis.liquiditySweepBull = (curLow < lo10 && curClose > curOpen && curClose > lo10);
   // Bearish sweep: wick above 10-bar high, closes bearish
   g_analysis.liquiditySweepBear = (curHigh > hi10 && curClose < curOpen && curClose < hi10);

   // ── Order Block Detection (simplified) ──
   // Bullish OB: last strong bearish candle before impulsive bull move
   double ob_close2 = iClose(Symbol(), PERIOD_M5, 2);
   double ob_open2  = iOpen(Symbol(),  PERIOD_M5, 2);
   double ob_close1 = iClose(Symbol(), PERIOD_M5, 1);
   double ob_open1  = iOpen(Symbol(),  PERIOD_M5, 1);
   double ob_body1  = MathAbs(ob_close1 - ob_open1);
   double ob_body2  = MathAbs(ob_close2 - ob_open2);

   // Bearish candle at [2] followed by strong bullish at [1] = bullish OB
   g_analysis.orderBlockBull = (ob_close2 < ob_open2 && ob_close1 > ob_open1 && ob_body1 > ob_body2 * 1.5);
   // Bullish candle at [2] followed by strong bearish at [1] = bearish OB
   g_analysis.orderBlockBear = (ob_close2 > ob_open2 && ob_close1 < ob_open1 && ob_body1 > ob_body2 * 1.5);
}

//=======================================================================
//  LAYER 4 & 5: AI SIGNAL SCORING ENGINE
//=======================================================================
double ScoreAI(int direction) // direction: +1 buy, -1 sell
{
   double score = 0.5; // Neutral prior

   // --- TREND FEATURES (weight: 0.30) ---
   double e9  = GetVal(g_h_ema9_M5,  0);
   double e21 = GetVal(g_h_ema21_M5, 0);
   double e50 = GetVal(g_h_ema50_M5, 0);
   double px  = SymbolInfoDouble(Symbol(), SYMBOL_BID);
   double emaFactor = 0.0;
   if(direction == 1)  emaFactor = (e9 > e21 && e21 > e50 && px > e9) ? 1.0 :
                                    (e9 > e21) ? 0.5 : -0.3;
   if(direction == -1) emaFactor = (e9 < e21 && e21 < e50 && px < e9) ? 1.0 :
                                    (e9 < e21) ? 0.5 : -0.3;
   score += emaFactor * 0.30;

   // --- PRICE ACTION (weight: 0.20) ---
   double cl1 = iClose(Symbol(), PERIOD_M5, 1);
   double op1 = iOpen(Symbol(),  PERIOD_M5, 1);
   double hi1 = iHigh(Symbol(),  PERIOD_M5, 1);
   double lo1 = iLow(Symbol(),   PERIOD_M5, 1);
   double body = MathAbs(cl1 - op1);
   double range = hi1 - lo1;
   double bodyRatio = (range > 0) ? body / range : 0.5;
   double wickBottom = (direction == 1) ? (MathMin(cl1,op1) - lo1) / (range > 0 ? range : 1) : 0;
   double wickTop    = (direction == -1) ? (hi1 - MathMax(cl1,op1)) / (range > 0 ? range : 1) : 0;
   double paBull = bodyRatio * 0.6 + wickBottom * 0.4;
   double paBear = bodyRatio * 0.6 + wickTop * 0.4;
   score += ((direction == 1) ? paBull : paBear) * 0.20;

   // --- VOLATILITY (weight: 0.15) ---
   double atr = GetVal(g_h_atr_M5, 0);
   double atrPrev10 = 0;
   for(int k=1; k<=10; k++) atrPrev10 += GetVal(g_h_atr_M5, k);
   atrPrev10 /= 10.0;
   double volFactor = (atrPrev10 > 0) ? MathMin(atr / atrPrev10, 2.0) / 2.0 : 0.5;
   score += (volFactor - 0.5) * 0.15; // above-avg vol = positive contribution

   // --- RSI MOMENTUM (weight: 0.15) ---
   double rsiM5 = GetVal(g_h_rsi_M5, 0);
   double rsiFactor = 0.0;
   if(direction == 1)  rsiFactor = (rsiM5 > 50 && rsiM5 < 70) ? (rsiM5 - 50) / 20.0 : (rsiM5 >= 70) ? -0.2 : -0.3;
   if(direction == -1) rsiFactor = (rsiM5 < 50 && rsiM5 > 30) ? (50 - rsiM5) / 20.0 : (rsiM5 <= 30) ? -0.2 : -0.3;
   score += rsiFactor * 0.15;

   // --- MULTI-TF BIAS ALIGNMENT (weight: 0.20) ---
   int biasAlign = 0;
   if(direction == 1)  biasAlign = (g_analysis.h1Bias==1?1:0) + (g_analysis.m15Bias==1?1:0) + (g_analysis.m5Bias==1?1:0);
   if(direction == -1) biasAlign = (g_analysis.h1Bias==-1?1:0) + (g_analysis.m15Bias==-1?1:0) + (g_analysis.m5Bias==-1?1:0);
   score += (biasAlign / 3.0) * 0.20;

   return MathMax(0.0, MathMin(1.0, score));
}

//=======================================================================
//  LAYER 6: ML DIRECTION PREDICTION
//  Logistic Regression ensemble with Chi-Square + Liquidity + RSI delta
//=======================================================================
double ScoreML(int direction)
{
   double f1 = GetChiSquareDrift();      // -1 to +1
   double f2 = GetLiquidityDelta();      // -1 to +1
   double f3 = g_analysis.microPressure; // -1 to +1

   // RSI delta M5 vs M15 as momentum divergence
   double rsiM5  = GetVal(g_h_rsi_M5, 0);
   double rsiM5_5 = GetVal(g_h_rsi_M5, 5);
   double f4 = (rsiM5 - rsiM5_5) / 20.0; // normalize

   // ADX directional
   double adxP = GetVal(g_h_adx_M5, 0, 1);
   double adxM = GetVal(g_h_adx_M5, 0, 2);
   double f5 = (adxP - adxM) / 30.0;

   // Weights (tuned for XAUUSD M5)
   double w1=0.25, w2=0.20, w3=0.20, w4=0.20, w5=0.15;
   double raw = f1*w1 + f2*w2 + f3*w3 + f4*w4 + f5*w5;

   // Sigmoid
   double prob = 1.0 / (1.0 + MathExp(-raw * 4.0));

   return (direction == 1) ? prob : (1.0 - prob);
}

//=======================================================================
//  MICROSTRUCTURE ENGINE
//=======================================================================
void UpdateTickBuffer()
{
   MqlTick tick;
   if(!SymbolInfoTick(Symbol(), tick)) return;
   if(g_tickCount < InpTickBufferSize) {
      g_tickBuffer[g_tickCount++] = tick;
   } else {
      for(int i=0; i<InpTickBufferSize-1; i++) g_tickBuffer[i] = g_tickBuffer[i+1];
      g_tickBuffer[InpTickBufferSize-1] = tick;
   }
}

double GetChiSquareDrift()
{
   if(g_tickCount < 20) return 0;
   int up=0, dn=0;
   int n = MathMin(g_tickCount, 200); // Use last 200 ticks for speed
   int start = g_tickCount - n;
   for(int i=start+1; i<g_tickCount; i++) {
      if(g_tickBuffer[i].last > g_tickBuffer[i-1].last) up++;
      else if(g_tickBuffer[i].last < g_tickBuffer[i-1].last) dn++;
   }
   int total = up + dn;
   if(total == 0) return 0;
   double exp = total / 2.0;
   double chi = (MathPow(up-exp,2)/exp) + (MathPow(dn-exp,2)/exp);
   g_analysis.chiSquareScore = chi;
   double norm = MathMin(chi / 50.0, 1.0);
   return (up > dn) ? norm : -norm;
}

double GetLiquidityDelta()
{
   double ask=0, bid=0;
   int n = MathMin(g_tickCount, 200);
   int start = g_tickCount - n;
   for(int i=start; i<g_tickCount; i++) {
      if((g_tickBuffer[i].flags & TICK_FLAG_ASK) != 0) ask += g_tickBuffer[i].volume_real;
      if((g_tickBuffer[i].flags & TICK_FLAG_BID) != 0) bid += g_tickBuffer[i].volume_real;
   }
   double tot = ask + bid;
   return (tot > 0) ? (ask - bid) / tot : 0;
}

double GetMicrostructurePressure()
{
   double chi = GetChiSquareDrift();
   double liq = GetLiquidityDelta();

   // Tick acceleration: compare recent 50 vs prior 50
   int n = g_tickCount;
   if(n < 100) return 0;
   double recentUp=0, recentDn=0, priorUp=0, priorDn=0;
   for(int i=n-50; i<n; i++) {
      if(i > 0 && g_tickBuffer[i].last > g_tickBuffer[i-1].last) recentUp++;
      else if(i > 0 && g_tickBuffer[i].last < g_tickBuffer[i-1].last) recentDn++;
   }
   for(int i=n-100; i<n-50; i++) {
      if(i > 0 && g_tickBuffer[i].last > g_tickBuffer[i-1].last) priorUp++;
      else if(i > 0 && g_tickBuffer[i].last < g_tickBuffer[i-1].last) priorDn++;
   }
   double accelBull = (priorUp > 0) ? (recentUp - priorUp) / 50.0 : 0;
   double accelBear = (priorDn > 0) ? (recentDn - priorDn) / 50.0 : 0;
   double accel = accelBull - accelBear;

   // Composite
   double pressure = chi * 0.40 + liq * 0.35 + accel * 0.25;
   return MathMax(-1.0, MathMin(1.0, pressure));
}

//=======================================================================
//  SESSION INTELLIGENCE
//=======================================================================
ENUM_SESSION GetCurrentSession()
{
   MqlDateTime t;
   TimeToStruct(TimeGMT(), t);
   int h = t.hour;
   // Approximate UTC session hours
   bool asia    = (h >= 0  && h <  8);
   bool london  = (h >= 7  && h < 16);
   bool ny      = (h >= 13 && h < 21);
   bool overlap = (h >= 13 && h < 16);
   if(overlap) return SESSION_OVERLAP_LDN_NY;
   if(london)  return SESSION_LONDON;
   if(ny)      return SESSION_NY;
   if(asia)    return SESSION_ASIA;
   return SESSION_OFF;
}

bool IsSessionAllowed()
{
   g_analysis.session = GetCurrentSession();
   switch(g_analysis.session) {
      case SESSION_ASIA:           return InpTradeAsia;
      case SESSION_LONDON:         return InpTradeLondon;
      case SESSION_NY:             return InpTradeNewYork;
      case SESSION_OVERLAP_LDN_NY: return InpTradeOverlap;
      default:                     return false;
   }
}

string SessionToStr(ENUM_SESSION s)
{
   switch(s) {
      case SESSION_ASIA:           return "ASIA";
      case SESSION_LONDON:         return "LONDON";
      case SESSION_NY:             return "NEW YORK";
      case SESSION_OVERLAP_LDN_NY: return "LDN/NY";
      case SESSION_OFF:            return "OFF HOURS";
      default:                     return "--";
   }
}

//=======================================================================
//  NEWS FILTER  (manual high-impact schedule - extend as needed)
//  In a live deployment, connect to an economic calendar API.
//=======================================================================
bool IsNewsTime()
{
   if(!InpNewsFilterEnabled) return false;
   MqlDateTime t;
   TimeToStruct(TimeGMT(), t);
   int hm = t.hour * 60 + t.min;

   // High-impact recurring times (UTC): NFP/CPI typically 12:30, FOMC 19:00
   int newsSlots[] = {
      12*60 + 30,   // NFP/CPI/Data releases
      13*60 + 30,   // US opens
      19*60 + 0,    // FOMC
      14*60 + 0     // Powell / Fed speeches common slot
   };
   for(int i=0; i<ArraySize(newsSlots); i++) {
      int diff = hm - newsSlots[i];
      if(diff >= -InpNewsPauseBefore && diff <= InpNewsPauseAfter) return true;
   }
   return false;
}

//=======================================================================
//  TRADE QUALITY GRADING
//=======================================================================
ENUM_TRADE_GRADE GradeSetup(int direction)
{
   int layers = 0;

   // L1: H1 Bias
   if((direction == 1 && g_analysis.h1Bias == 1) || (direction == -1 && g_analysis.h1Bias == -1)) layers++;
   // L2: M15 Bias
   if((direction == 1 && g_analysis.m15Bias == 1) || (direction == -1 && g_analysis.m15Bias == -1)) layers++;
   // L3: M5 Bias + BOS
   if((direction == 1 && g_analysis.m5Bias == 1) || (direction == -1 && g_analysis.m5Bias == -1)) layers++;
   // L4: SMC FVG
   if((direction == 1 && g_analysis.fvgBullish) || (direction == -1 && g_analysis.fvgBearish)) layers++;
   // L5: Liquidity Sweep
   if((direction == 1 && g_analysis.liquiditySweepBull) || (direction == -1 && g_analysis.liquiditySweepBear)) layers++;
   // L6: Order Block
   if((direction == 1 && g_analysis.orderBlockBull) || (direction == -1 && g_analysis.orderBlockBear)) layers++;
   // L7: Microstructure agrees
   if((direction == 1 && g_analysis.microPressure > 0.2) || (direction == -1 && g_analysis.microPressure < -0.2)) layers++;

   g_analysis.confluenceLayers = layers;

   double buyConf  = g_analysis.aiConfidenceBuy  * 0.6 + g_analysis.mlDirectionBuy  * 0.4;
   double sellConf = g_analysis.aiConfidenceSell * 0.6 + g_analysis.mlDirectionSell * 0.4;
   double conf = (direction == 1) ? buyConf : sellConf;

   if(layers >= 6 && conf >= 0.82) return GRADE_A_PLUS;
   if(layers >= 4 && conf >= 0.75) return GRADE_A;
   if(layers >= 3 && conf >= 0.68) return GRADE_B;
   return GRADE_NO_TRADE;
}

//=======================================================================
//  FULL ANALYSIS ORCHESTRATOR (called on each new M5 bar)
//=======================================================================
void RunFullAnalysis()
{
   g_analysis.regime    = DetectRegime();
   g_analysis.regimeStr = RegimeToStr(g_analysis.regime);
   g_analysis.session   = GetCurrentSession();

   AnalyzeMultiTFBias();
   AnalyzeSMC();

   g_analysis.atrM5    = GetVal(g_h_atr_M5, 0);
   g_analysis.atrH1    = GetVal(g_h_atr_H1, 0);
   double px = SymbolInfoDouble(Symbol(), SYMBOL_BID);
   g_analysis.volatilityPct = (px > 0) ? g_analysis.atrM5 / px * 100.0 : 0;

   g_analysis.microPressure = GetMicrostructurePressure();

   g_analysis.aiConfidenceBuy  = ScoreAI(1);
   g_analysis.aiConfidenceSell = ScoreAI(-1);
   g_analysis.mlDirectionBuy   = ScoreML(1);
   g_analysis.mlDirectionSell  = ScoreML(-1);

   // Grade both directions, pick the better one
   ENUM_TRADE_GRADE gb = GradeSetup(1);
   int layersB = g_analysis.confluenceLayers;
   ENUM_TRADE_GRADE gs = GradeSetup(-1);
   int layersS = g_analysis.confluenceLayers;

   // Keep best grade
   if((int)gb <= (int)gs) { // lower enum = better grade
      g_analysis.grade = gb;
      g_analysis.confluenceLayers = layersB;
   } else {
      g_analysis.grade = gs;
      g_analysis.confluenceLayers = layersS;
   }

   g_lastAction = StringFormat("Analysis: %s | %s | Layers: %d | AIC:%.0f%%",
      g_analysis.regimeStr, SessionToStr(g_analysis.session),
      g_analysis.confluenceLayers,
      MathMax(g_analysis.aiConfidenceBuy, g_analysis.aiConfidenceSell)*100);
}

//=======================================================================
//  DYNAMIC LOT SIZING
//=======================================================================
double CalculateLotSize(double confidenceScore)
{
   double balance  = AccountInfoDouble(ACCOUNT_BALANCE);
   double price    = SymbolInfoDouble(Symbol(), SYMBOL_ASK);
   double atr      = GetVal(g_h_atr_M5, 0);
   double point    = SymbolInfoDouble(Symbol(), SYMBOL_POINT);
   double tickVal  = SymbolInfoDouble(Symbol(), SYMBOL_TRADE_TICK_VALUE);
   double tickSize = SymbolInfoDouble(Symbol(), SYMBOL_TRADE_TICK_SIZE);

   // Risk amount adjusted for confidence: higher confidence = full risk
   double riskMult = 0.5 + confidenceScore * 0.5; // 0.5 to 1.0
   double riskUSD  = balance * InpRiskPctPerTrade / 100.0 * riskMult;

   // SL in price units
   double slDist = price * InpStopLossPct / 100.0;
   if(slDist <= 0 || tickVal <= 0 || tickSize <= 0) return InpMinLot;

   double slPips = slDist / point;
   double lotRaw = riskUSD / (slPips * tickVal * tickSize / point);

   double lotStep = SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_STEP);
   double lot = MathRound(lotRaw / lotStep) * lotStep;
   return MathMax(InpMinLot, MathMin(InpMaxLot, lot));
}

//=======================================================================
//  EXECUTION
//=======================================================================
bool ExecuteTrade(int direction)
{
   // Regime filter: avoid vol spikes and low liquidity
   if(g_analysis.regime == REGIME_VOLATILITY_EXPANSION ||
      g_analysis.regime == REGIME_LOW_LIQUIDITY) {
      g_lastAction = "Regime block: " + g_analysis.regimeStr;
      return false;
   }

   ENUM_ORDER_TYPE otype = (direction == 1) ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
   double price = (otype == ORDER_TYPE_BUY) ?
      SymbolInfoDouble(Symbol(), SYMBOL_ASK) :
      SymbolInfoDouble(Symbol(), SYMBOL_BID);
   if(price <= 0) return false;

   double conf = (direction == 1) ? g_analysis.aiConfidenceBuy : g_analysis.aiConfidenceSell;
   double lot  = CalculateLotSize(conf);

   double sl=0, tp=0;
   double slDist = price * InpStopLossPct / 100.0;
   // Dynamic TP: ATR-based, scaled by base profit target
   double tpDist = g_analysis.atrM5 * 2.5;
   // Also ensure minimum TP = base target
   double baseTpUSD = InpBaseProfitUSDPer01 * (lot / 0.01);
   double tickV = SymbolInfoDouble(Symbol(), SYMBOL_TRADE_TICK_VALUE);
   double tickS = SymbolInfoDouble(Symbol(), SYMBOL_TRADE_TICK_SIZE);
   double ptVal = (tickS > 0) ? tickV / tickS : 1.0;
   double minTpDist = (ptVal * lot > 0) ? baseTpUSD / (ptVal * lot) : tpDist;
   tpDist = MathMax(tpDist, minTpDist);

   if(otype == ORDER_TYPE_BUY) {
      sl = NPrice(price - slDist);
      tp = NPrice(price + tpDist);
   } else {
      sl = NPrice(price + slDist);
      tp = NPrice(price - tpDist);
   }
   AdjustStops(price, otype, sl, tp);

   bool ok = (otype == ORDER_TYPE_BUY) ?
      g_trade.Buy(lot,  Symbol(), price, sl, tp, InpBotName) :
      g_trade.Sell(lot, Symbol(), price, sl, tp, InpBotName);
   return ok;
}

//=======================================================================
//  POSITION MANAGEMENT (Trailing Stop + Partial Close + Breakeven)
//=======================================================================
void ManageOpenPositions()
{
   for(int i = PositionsTotal()-1; i >= 0; i--) {
      if(!g_pos.SelectByIndex(i)) continue;
      if(g_pos.Magic() != InpMagicNumber || g_pos.Symbol() != Symbol()) continue;

      double entryPrice = g_pos.PriceOpen();
      double curPrice   = (g_pos.PositionType() == POSITION_TYPE_BUY) ?
                           SymbolInfoDouble(Symbol(), SYMBOL_BID) :
                           SymbolInfoDouble(Symbol(), SYMBOL_ASK);
      double curSL      = g_pos.StopLoss();
      double curTP      = g_pos.TakeProfit();
      double lot        = g_pos.Volume();
      double profitDist = (g_pos.PositionType() == POSITION_TYPE_BUY) ?
                           curPrice - entryPrice : entryPrice - curPrice;
      double slDist     = MathAbs(entryPrice - curSL);

      // Breakeven: move SL to entry+spread once price moves 1x SL dist
      if(profitDist > slDist && curSL != entryPrice) {
         double newSL = NPrice(entryPrice + (g_pos.PositionType()==POSITION_TYPE_BUY ? 1 : -1) *
                        SymbolInfoInteger(Symbol(), SYMBOL_TRADE_STOPS_LEVEL) *
                        SymbolInfoDouble(Symbol(), SYMBOL_POINT));
         if(g_pos.PositionType() == POSITION_TYPE_BUY && newSL > curSL)
            g_trade.PositionModify(g_pos.Ticket(), newSL, curTP);
         if(g_pos.PositionType() == POSITION_TYPE_SELL && newSL < curSL)
            g_trade.PositionModify(g_pos.Ticket(), newSL, curTP);
      }

      // Trailing Stop
      if(InpUseTrailingStop && slDist > 0) {
         double trailActivate = slDist * (InpTrailActivatePct / 0.60);
         if(profitDist >= trailActivate) {
            double trailDist = slDist * (InpTrailDistancePct / 0.35);
            double newTrailSL;
            if(g_pos.PositionType() == POSITION_TYPE_BUY) {
               newTrailSL = NPrice(curPrice - trailDist);
               if(newTrailSL > curSL) g_trade.PositionModify(g_pos.Ticket(), newTrailSL, curTP);
            } else {
               newTrailSL = NPrice(curPrice + trailDist);
               if(newTrailSL < curSL) g_trade.PositionModify(g_pos.Ticket(), newTrailSL, curTP);
            }
         }
      }

      // Partial Close at 50% TP
      if(InpUsePartialClose && !g_partialClosed && curTP > 0) {
         double tpDist = MathAbs(curTP - entryPrice);
         if(profitDist >= tpDist * 0.50) {
            double partialLot = NormalizeDouble(lot * InpPartialClosePct / 100.0,
                                   (int)(MathLog10(1.0/SymbolInfoDouble(Symbol(),SYMBOL_VOLUME_STEP))));
            double lotStep = SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_STEP);
            double minLot  = SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_MIN);
            partialLot = MathMax(minLot, MathRound(partialLot/lotStep)*lotStep);
            if(partialLot < lot) {
               g_trade.PositionClosePartial(g_pos.Ticket(), partialLot);
               g_partialClosed = true;
               g_lastAction = "Partial close: " + DoubleToString(partialLot, 2) + " lots";
            }
         }
      }

      // Dynamic close: if momentum decays and profit is positive, close early
      double momentum = g_analysis.microPressure;
      double floatPnl = g_pos.Profit();
      bool momentumDecay = (g_pos.PositionType() == POSITION_TYPE_BUY  && momentum < -0.5 && floatPnl > 0) ||
                           (g_pos.PositionType() == POSITION_TYPE_SELL && momentum >  0.5 && floatPnl > 0);
      if(momentumDecay) {
         g_trade.PositionClose(g_pos.Ticket());
         g_lastAction = "Dynamic close: momentum reversed";
         g_lastCloseTime = TimeCurrent();
         BuildSessionStats();
         g_consecutiveLosses = GetConsecutiveLosses();
         if(g_consecutiveLosses >= InpMaxConsecLosses)
            g_lossCooldownUntil = TimeCurrent() + (datetime)(InpLossStreakCooldownMin * 60);
         return;
      }
   }
}

void CloseAllPositions()
{
   for(int i = PositionsTotal()-1; i >= 0; i--) {
      if(!g_pos.SelectByIndex(i)) continue;
      if(g_pos.Magic() != InpMagicNumber || g_pos.Symbol() != Symbol()) continue;
      g_trade.PositionClose(g_pos.Ticket());
   }
   g_lastCloseTime = TimeCurrent();
   BuildSessionStats();
   g_consecutiveLosses = GetConsecutiveLosses();
   if(g_consecutiveLosses >= InpMaxConsecLosses)
      g_lossCooldownUntil = TimeCurrent() + (datetime)(InpLossStreakCooldownMin * 60);
}

//=======================================================================
//  HELPERS
//=======================================================================
bool HasPosition()
{
   for(int i=PositionsTotal()-1; i>=0; i--)
      if(g_pos.SelectByIndex(i) && g_pos.Magic()==InpMagicNumber && g_pos.Symbol()==Symbol()) return true;
   return false;
}

double GetFloatPL()
{
   double t = 0;
   for(int i=PositionsTotal()-1; i>=0; i--)
      if(g_pos.SelectByIndex(i) && g_pos.Magic()==InpMagicNumber && g_pos.Symbol()==Symbol())
         t += g_pos.Profit() + g_pos.Swap() + g_pos.Commission();
   return t;
}

bool IsMarketOpen()
{
   ENUM_SYMBOL_TRADE_MODE m = (ENUM_SYMBOL_TRADE_MODE)SymbolInfoInteger(Symbol(), SYMBOL_TRADE_MODE);
   return (m==SYMBOL_TRADE_MODE_FULL || m==SYMBOL_TRADE_MODE_LONGONLY || m==SYMBOL_TRADE_MODE_SHORTONLY);
}

bool SpreadOK()
{
   double spread = SymbolInfoInteger(Symbol(), SYMBOL_SPREAD) * SymbolInfoDouble(Symbol(), SYMBOL_POINT);
   double atr    = GetVal(g_h_atr_M5, 0);
   // Also check absolute points limit
   long spreadPts = SymbolInfoInteger(Symbol(), SYMBOL_SPREAD);
   return (spreadPts <= InpMaxSpreadPoints && (atr <= 0 || spread < atr * 0.3));
}

bool DailyLimitsOK()
{
   double bal = AccountInfoDouble(ACCOUNT_BALANCE);
   if(bal <= 0) return true;
   if(InpMaxDailyTrades > 0 && g_sessTradesToday >= InpMaxDailyTrades) return false;
   if(InpMaxDailyLossPct > 0 && g_sessProfit < -(bal * InpMaxDailyLossPct / 100.0)) return false;
   if(InpMaxDailyProfitPct > 0 && g_sessProfit >= (bal * InpMaxDailyProfitPct / 100.0)) return false;
   return true;
}

int GetConsecutiveLosses()
{
   int losses = 0;
   if(!HistorySelect(0, TimeCurrent())) return 0;
   int total = HistoryDealsTotal();
   for(int i=total-1; i>=0; i--) {
      ulong tk = HistoryDealGetTicket(i);
      if(HistoryDealGetInteger(tk, DEAL_MAGIC) != (long)InpMagicNumber) continue;
      if(HistoryDealGetString(tk, DEAL_SYMBOL) != Symbol()) continue;
      if(HistoryDealGetInteger(tk, DEAL_ENTRY) == DEAL_ENTRY_OUT) {
         double pnl = HistoryDealGetDouble(tk, DEAL_PROFIT) +
                      HistoryDealGetDouble(tk, DEAL_SWAP) +
                      HistoryDealGetDouble(tk, DEAL_COMMISSION);
         if(pnl < 0) losses++;
         else break;
      }
   }
   return losses;
}

void BuildSessionStats()
{
   g_sessProfit = 0; g_sessWins = 0; g_sessLosses = 0;
   if(!HistorySelect(DayStart(TimeCurrent()), TimeCurrent())) return;
   for(int i=0; i<HistoryDealsTotal(); i++) {
      ulong tk = HistoryDealGetTicket(i);
      if((ulong)HistoryDealGetInteger(tk, DEAL_MAGIC) != InpMagicNumber) continue;
      if(HistoryDealGetString(tk, DEAL_SYMBOL) != Symbol()) continue;
      if(HistoryDealGetInteger(tk, DEAL_ENTRY) == DEAL_ENTRY_OUT) {
         double pnl = HistoryDealGetDouble(tk, DEAL_PROFIT) +
                      HistoryDealGetDouble(tk, DEAL_SWAP) +
                      HistoryDealGetDouble(tk, DEAL_COMMISSION);
         g_sessProfit += pnl;
         if(pnl >= 0) g_sessWins++; else g_sessLosses++;
      }
   }
}

void RestoreSession()
{
   g_sessTradesToday = 0;
   if(!HistorySelect(DayStart(TimeCurrent()), TimeCurrent())) return;
   for(int i=0; i<HistoryDealsTotal(); i++) {
      ulong tk = HistoryDealGetTicket(i);
      if((ulong)HistoryDealGetInteger(tk, DEAL_MAGIC) == InpMagicNumber &&
          HistoryDealGetString(tk, DEAL_SYMBOL) == Symbol() &&
          HistoryDealGetInteger(tk, DEAL_ENTRY) == DEAL_ENTRY_IN)
         g_sessTradesToday++;
   }
}

void AdjustStops(double price, ENUM_ORDER_TYPE otype, double &sl, double &tp)
{
   int stopsLv  = (int)SymbolInfoInteger(Symbol(), SYMBOL_TRADE_STOPS_LEVEL);
   double point = SymbolInfoDouble(Symbol(), SYMBOL_POINT);
   double minD  = stopsLv * point;
   if(otype == ORDER_TYPE_BUY) {
      if(sl > 0 && (price - sl) < minD) sl = NPrice(price - minD);
      if(tp > 0 && (tp - price) < minD) tp = NPrice(price + minD);
   } else {
      if(sl > 0 && (sl - price) < minD) sl = NPrice(price + minD);
      if(tp > 0 && (price - tp) < minD) tp = NPrice(price - minD);
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

double GetVal(int handle, int shift=0, int buf=0)
{
   if(handle == INVALID_HANDLE) return 0;
   double arr[1];
   if(CopyBuffer(handle, buf, shift, 1, arr) <= 0) return 0;
   return arr[0];
}

//=======================================================================
//  INSTITUTIONAL DASHBOARD
//=======================================================================
void R(string nm, int x, int y, int w, int h, color bg, color brd=clrNONE, int bw=1)
{
   string n=D+nm;
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

void L(string nm, int x, int y, string txt, color clr, int fsz, string fnt="Arial Bold")
{
   string n=D+nm;
   if(ObjectFind(0,n)>=0) ObjectDelete(0,n);
   ObjectCreate(0,n,OBJ_LABEL,0,0,0);
   ObjectSetInteger(0,n,OBJPROP_CORNER,CORNER_LEFT_UPPER);
   ObjectSetInteger(0,n,OBJPROP_XDISTANCE,x);
   ObjectSetInteger(0,n,OBJPROP_YDISTANCE,y);
   ObjectSetString(0,n,OBJPROP_TEXT,txt);
   ObjectSetInteger(0,n,OBJPROP_COLOR,clr);
   ObjectSetInteger(0,n,OBJPROP_FONTSIZE,fsz);
   ObjectSetString(0,n,OBJPROP_FONT,fnt);
   ObjectSetInteger(0,n,OBJPROP_SELECTABLE,false);
   ObjectSetInteger(0,n,OBJPROP_HIDDEN,true);
}

void U(string nm, string txt, color clr=C'220,225,240')
{
   string n=D+nm;
   if(ObjectFind(0,n)>=0){ObjectSetString(0,n,OBJPROP_TEXT,txt);ObjectSetInteger(0,n,OBJPROP_COLOR,clr);}
}

void Bar(string nm, int x, int y, int w, int h, double pct, color fg, color bg_c)
{
   R(nm+"_bg",x,y,w,h,bg_c,C_BORDER,1);
   int fw=(int)MathMax(2,MathRound(pct/100.0*(w-2)));
   R(nm+"_fg",x+1,y+1,fw,h-2,fg,clrNONE);
}

void UpdBar(string nm, double pct, color fg)
{
   string n=D+nm+"_fg", nb=D+nm+"_bg";
   int w=0;
   if(ObjectFind(0,nb)>=0) w=(int)ObjectGetInteger(0,nb,OBJPROP_XSIZE);
   if(w<=0) return;
   int fw=(int)MathMax(2,MathRound(pct/100.0*(w-2)));
   if(ObjectFind(0,n)>=0){ObjectSetInteger(0,n,OBJPROP_XSIZE,fw);ObjectSetInteger(0,n,OBJPROP_BGCOLOR,fg);}
}

void InitDash()
{
   int X=InpDashX, Y=InpDashY;
   // Outer frame
   R("outer",   X,   Y,   DW,   DH,   C_BG0,  C_ACBORD, 2);
   R("inner",   X+2, Y+2, DW-4, DH-4, C_BG0,  C_BORDER, 1);
   // Header
   R("hdr",     X+2, Y+2, DW-4, 82,   C_HDRBAR,C_BORDER,1);
   R("hdr_top", X+2, Y+2, DW-4,  3,   C_ACBORD);
   L("h_name",  X+10,Y+10, InpBotName,                     C_GOLD,  12,"Arial Black");
   L("h_sub",   X+10,Y+30, "Institutional XAUUSD AI Scalper  |  v5.0", C_CYAN,  7,"Arial");
   L("h_info",  X+10,Y+44, "Magic: "+IntegerToString((long)InpMagicNumber)+"  |  "+Symbol()+"  |  M5", C_LBLUE, 7,"Arial");
   R("live_bg", X+DW-82,Y+8,66,22,C_DKGREEN,C_GREEN,1);
   L("live",    X+DW-74,Y+12,"● LIVE",C_GREEN,7,"Arial Bold");
   R("hdiv",    X+2, Y+84, DW-4, 2, C_ACBORD);

   // Status bar
   R("stat_bg", X+2, Y+88, DW-4, 28, C_BG2, C_BORDER, 1);
   L("lb_stat", X+14,Y+95, "STATUS", C_SUBTEXT,8,"Arial");
   L("vl_stat", X+90,Y+95, "WARMING UP", C_ORANGE, 9,"Arial Black");
   L("lb_act",  X+220,Y+95,"Last:", C_SUBTEXT,7,"Arial");
   L("vl_act",  X+255,Y+95,"--",C_SUBTEXT,7,"Arial");
   R("sdiv",    X+2, Y+118, DW-4, 1, C_BORDER);

   // Section A: Market Context
   R("sa",      X+2, Y+121, DW-4,130, C_BG1, C_BORDER,1);
   R("sa_hd",   X+2, Y+121, DW-4, 20, C_HDRBAR,C_BORDER,1);
   L("sa_lb",   X+10,Y+124, "▸  MARKET CONTEXT", C_GOLD, 8,"Arial Black");

   L("lb_reg",  X+14,Y+146,"Regime",    C_SUBTEXT,8,"Arial");
   L("vl_reg",  X+180,Y+146,"--",       C_WHITE,  9,"Arial Bold");
   L("lb_ses",  X+14,Y+162,"Session",   C_SUBTEXT,8,"Arial");
   L("vl_ses",  X+180,Y+162,"--",       C_WHITE,  9,"Arial Bold");
   L("lb_vol",  X+14,Y+178,"Volatility",C_SUBTEXT,8,"Arial");
   L("vl_vol",  X+180,Y+178,"-- %",     C_WHITE,  9,"Arial Bold");
   Bar("vol_bar",X+295,Y+180,130,10,0,C_PURPLE,C_DGRAY);
   L("lb_spr",  X+14,Y+194,"Spread",    C_SUBTEXT,8,"Arial");
   L("vl_spr",  X+180,Y+194,"-- pts",   C_WHITE,  9,"Arial Bold");
   R("adiv",    X+2, Y+253, DW-4, 1, C_BORDER);

   // Section B: Bias alignment
   R("sb",      X+2, Y+254, DW-4, 90, C_BG1, C_BORDER,1);
   R("sb_hd",   X+2, Y+254, DW-4, 20, C_HDRBAR,C_BORDER,1);
   L("sb_lb",   X+10,Y+257,"▸  MULTI-TF BIAS  +  SMC", C_GOLD,8,"Arial Black");

   L("lb_h1",   X+14,Y+279,"H1 Bias",   C_SUBTEXT,8,"Arial");  L("vl_h1",  X+180,Y+279,"--",C_WHITE,9,"Arial Bold");
   L("lb_m15",  X+14,Y+295,"M15 Bias",  C_SUBTEXT,8,"Arial");  L("vl_m15", X+180,Y+295,"--",C_WHITE,9,"Arial Bold");
   L("lb_m5",   X+14,Y+311,"M5 Bias",   C_SUBTEXT,8,"Arial");  L("vl_m5",  X+180,Y+311,"--",C_WHITE,9,"Arial Bold");
   L("lb_smc",  X+260,Y+279,"FVG",       C_SUBTEXT,8,"Arial");  L("vl_fvg",X+310,Y+279,"--",C_WHITE,8,"Arial Bold");
   L("lb_liq",  X+260,Y+295,"Sweep",    C_SUBTEXT,8,"Arial");  L("vl_liq", X+310,Y+295,"--",C_WHITE,8,"Arial Bold");
   L("lb_ob",   X+260,Y+311,"OB",        C_SUBTEXT,8,"Arial");  L("vl_ob",  X+310,Y+311,"--",C_WHITE,8,"Arial Bold");
   R("bdiv",    X+2, Y+346, DW-4, 1, C_BORDER);

   // Section C: AI / ML
   R("sc",      X+2, Y+347, DW-4,130, C_BG1, C_BORDER,1);
   R("sc_hd",   X+2, Y+347, DW-4, 20, C_HDRBAR,C_BORDER,1);
   L("sc_lb",   X+10,Y+350,"▸  AI · ML · MICROSTRUCTURE", C_GOLD,8,"Arial Black");

   L("lb_aic",  X+14,Y+372,"AI Buy Conf",  C_SUBTEXT,8,"Arial"); L("vl_aic",X+180,Y+372,"50.0%",C_CYAN,9,"Arial Bold");
   Bar("aic_bar",X+295,Y+374,130,10,50,C_CYAN,C_DGRAY);
   L("lb_ais",  X+14,Y+388,"AI Sell Conf", C_SUBTEXT,8,"Arial"); L("vl_ais",X+180,Y+388,"50.0%",C_PINK,9,"Arial Bold");
   Bar("ais_bar",X+295,Y+390,130,10,50,C_PINK,C_DGRAY);
   L("lb_ml",   X+14,Y+404,"ML Direction", C_SUBTEXT,8,"Arial"); L("vl_ml", X+180,Y+404,"--",C_WHITE,9,"Arial Bold");
   L("lb_mic",  X+14,Y+420,"Micropress",   C_SUBTEXT,8,"Arial"); L("vl_mic",X+180,Y+420,"--",C_WHITE,9,"Arial Bold");
   Bar("mic_bar",X+295,Y+422,130,10,50,C_LBLUE,C_DGRAY);
   L("lb_chi",  X+14,Y+436,"Chi-Square",   C_SUBTEXT,8,"Arial"); L("vl_chi",X+180,Y+436,"0.00",C_WHITE,9,"Arial Bold");
   R("cdiv",    X+2, Y+479, DW-4, 1, C_BORDER);

   // Section D: Trade Grade & Performance
   R("sd",      X+2, Y+480, DW-4,130, C_BG1, C_BORDER,1);
   R("sd_hd",   X+2, Y+480, DW-4, 20, C_HDRBAR,C_BORDER,1);
   L("sd_lb",   X+10,Y+483,"▸  TRADE QUALITY  +  PERFORMANCE", C_GOLD,8,"Arial Black");

   L("lb_grd",  X+14,Y+505,"Trade Grade",    C_SUBTEXT,8,"Arial"); L("vl_grd", X+180,Y+505,"--",C_WHITE,10,"Arial Black");
   L("lb_lay",  X+14,Y+521,"Confluence",     C_SUBTEXT,8,"Arial"); L("vl_lay", X+180,Y+521,"0/7",C_WHITE,9,"Arial Bold");
   Bar("lay_bar",X+295,Y+523,130,10,0,C_GOLD,C_DGRAY);
   L("lb_sp",   X+14,Y+537,"Sess Profit",    C_SUBTEXT,8,"Arial"); L("vl_sp",  X+180,Y+537,"$0.00",C_WHITE,9,"Arial Bold");
   L("lb_dd",   X+14,Y+553,"Drawdown",       C_SUBTEXT,8,"Arial"); L("vl_dd",  X+180,Y+553,"0.00%",C_WHITE,9,"Arial Bold");
   Bar("dd_bar", X+295,Y+555,130,10,0,C_RED,C_DGRAY);
   L("lb_wr",   X+14,Y+569,"Win Rate",       C_SUBTEXT,8,"Arial"); L("vl_wr",  X+180,Y+569,"--",C_WHITE,9,"Arial Bold");
   L("lb_tc",   X+260,Y+537,"Trades",C_SUBTEXT,7,"Arial");         L("vl_tc",  X+310,Y+537,"0",C_WHITE,9,"Arial Bold");
   L("lb_cl",   X+260,Y+553,"Cons.L",C_SUBTEXT,7,"Arial");         L("vl_cl",  X+310,Y+553,"0",C_WHITE,9,"Arial Bold");

   // Footer
   R("ftr",     X+2, Y+DH-18, DW-4,16, C_HDRBAR,C_BORDER,1);
   L("ft_t",    X+10,Y+DH-15,"Server: --",C_MGRAY,7,"Arial");

   ChartRedraw(0);
}

void UpdateDash()
{
   if(!InpShowDash) return;
   int X=InpDashX;

   U("vl_stat", g_statusText, g_statusColor);
   U("vl_act",  g_lastAction, C_SUBTEXT);

   // Market Context
   color regColor = (g_analysis.regime==REGIME_TRENDING_BULL)?C_GREEN:(g_analysis.regime==REGIME_TRENDING_BEAR)?C_RED:C_WHITE;
   U("vl_reg", g_analysis.regimeStr, regColor);
   U("vl_ses", SessionToStr(g_analysis.session), C_CYAN);
   U("vl_vol", DoubleToString(g_analysis.volatilityPct,3)+" %", (g_analysis.volatilityPct>0.3)?C_ORANGE:C_WHITE);
   UpdBar("vol_bar", MathMin(g_analysis.volatilityPct*200,100), C_PURPLE);
   long spreadPts = SymbolInfoInteger(Symbol(), SYMBOL_SPREAD);
   U("vl_spr", IntegerToString((int)spreadPts)+" pts", (spreadPts>InpMaxSpreadPoints)?C_RED:C_GREEN);

   // Bias
   string biasStr(int b){return b==1?"BULL":b==-1?"BEAR":"NEUTRAL";}
   color biasClr(int b){return b==1?C_GREEN:b==-1?C_RED:C_MGRAY;}
   U("vl_h1",  biasStr(g_analysis.h1Bias),  biasClr(g_analysis.h1Bias));
   U("vl_m15", biasStr(g_analysis.m15Bias), biasClr(g_analysis.m15Bias));
   U("vl_m5",  biasStr(g_analysis.m5Bias),  biasClr(g_analysis.m5Bias));
   U("vl_fvg", (g_analysis.fvgBullish?"▲ BULL":(g_analysis.fvgBearish?"▼ BEAR":"none")),
               (g_analysis.fvgBullish?C_GREEN:(g_analysis.fvgBearish?C_RED:C_MGRAY)));
   U("vl_liq", (g_analysis.liquiditySweepBull?"▲ BULL":(g_analysis.liquiditySweepBear?"▼ BEAR":"none")),
               (g_analysis.liquiditySweepBull?C_GREEN:(g_analysis.liquiditySweepBear?C_RED:C_MGRAY)));
   U("vl_ob",  (g_analysis.orderBlockBull?"▲ BULL":(g_analysis.orderBlockBear?"▼ BEAR":"none")),
               (g_analysis.orderBlockBull?C_GREEN:(g_analysis.orderBlockBear?C_RED:C_MGRAY)));

   // AI/ML
   U("vl_aic", DoubleToString(g_analysis.aiConfidenceBuy*100,1)+"%", (g_analysis.aiConfidenceBuy>=InpMinAIConfidence)?C_GREEN:C_CYAN);
   UpdBar("aic_bar", g_analysis.aiConfidenceBuy*100, (g_analysis.aiConfidenceBuy>=InpMinAIConfidence)?C_GREEN:C_CYAN);
   U("vl_ais", DoubleToString(g_analysis.aiConfidenceSell*100,1)+"%",(g_analysis.aiConfidenceSell>=InpMinAIConfidence)?C_RED:C_PINK);
   UpdBar("ais_bar", g_analysis.aiConfidenceSell*100,(g_analysis.aiConfidenceSell>=InpMinAIConfidence)?C_RED:C_PINK);

   double mlBest = MathMax(g_analysis.mlDirectionBuy, g_analysis.mlDirectionSell);
   bool mlBuy = g_analysis.mlDirectionBuy > g_analysis.mlDirectionSell;
   U("vl_ml", (mlBuy?"BULL ":"BEAR ")+DoubleToString(mlBest*100,1)+"%", mlBuy?C_GREEN:C_RED);

   double mic = g_analysis.microPressure;
   U("vl_mic", (mic>0.2?"BUY PRESS":mic<-0.2?"SELL PRESS":"NEUTRAL")+"  "+DoubleToString(mic,2),
              mic>0.2?C_GREEN:mic<-0.2?C_RED:C_MGRAY);
   UpdBar("mic_bar", (mic+1.0)*50.0, mic>0?C_GREEN:C_RED);
   U("vl_chi", DoubleToString(g_analysis.chiSquareScore,2), C_WHITE);

   // Grade
   string gradeStr = (g_analysis.grade==GRADE_A_PLUS?"A+":(g_analysis.grade==GRADE_A?"A":(g_analysis.grade==GRADE_B?"B":"NO TRADE")));
   color gradeClr = (g_analysis.grade==GRADE_A_PLUS)?C_GOLD:(g_analysis.grade==GRADE_A)?C_GREEN:(g_analysis.grade==GRADE_B)?C_ORANGE:C_MGRAY;
   U("vl_grd", gradeStr, gradeClr);
   U("vl_lay", IntegerToString(g_analysis.confluenceLayers)+"/7", (g_analysis.confluenceLayers>=InpMinConfluenceLayers)?C_GREEN:C_MGRAY);
   UpdBar("lay_bar", g_analysis.confluenceLayers/7.0*100, C_GOLD);

   U("vl_sp", "$"+DoubleToString(g_sessProfit,2), g_sessProfit>=0?C_GREEN:C_RED);
   U("vl_dd", DoubleToString(g_drawdown,2)+"%", g_drawdown<3?C_GREEN:g_drawdown<5?C_ORANGE:C_RED);
   UpdBar("dd_bar", MathMin(g_drawdown*5,100), g_drawdown<3?C_GREEN:C_RED);

   int total = g_sessWins + g_sessLosses;
   string wr = total > 0 ? DoubleToString((double)g_sessWins/total*100,1)+"%" : "--";
   U("vl_wr", wr, (total>0&&(double)g_sessWins/total>0.5)?C_GREEN:C_ORANGE);
   U("vl_tc", IntegerToString(g_sessTradesToday), C_WHITE);
   U("vl_cl", IntegerToString(g_consecutiveLosses), g_consecutiveLosses>=InpMaxConsecLosses?C_RED:C_WHITE);

   U("ft_t", "Server: "+TimeToString(TimeCurrent(),TIME_SECONDS)+"  |  "+Symbol()+"  |  v5.0", C_MGRAY);
   ChartRedraw(0);
}

void DeleteDash() { ObjectsDeleteAll(0,D); ChartRedraw(0); }
//+------------------------------------------------------------------+
// END OF PHANTOM SCALPER PRO v5.0
//+------------------------------------------------------------------+