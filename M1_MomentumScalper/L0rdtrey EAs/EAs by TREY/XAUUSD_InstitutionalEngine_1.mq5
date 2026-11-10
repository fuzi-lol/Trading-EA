//+------------------------------------------------------------------+
//|          XAUUSD Institutional Engine v1.0                        |
//|          Hedge-Fund Grade GOLD Scalper / Swing Hybrid            |
//|          Designed for $100 Account | FBS MT5 | XAUUSD            |
//|                                                                  |
//|  Architecture:                                                   |
//|    Layer 1  - Market Regime Detection                            |
//|    Layer 2  - Market Structure (BOS/CHoCH/MSS)                   |
//|    Layer 3  - Liquidity Engine (Sweeps/Pools/Inducement)         |
//|    Layer 4  - Displacement Engine (Impulse/Imbalance)            |
//|    Layer 5  - Fair Value Gap Engine                              |
//|    Layer 6  - Order Block Engine                                 |
//|    Layer 7  - Volume Confirmation                                |
//|    Layer 8  - Multi-Timeframe Alignment (H1/M15/M5/M1)          |
//|    Layer 9  - News/Session Filter                                |
//|                                                                  |
//|  Risk Model:                                                     |
//|    Dynamic lot from equity + SL distance                         |
//|    Max 1% risk per trade, 3% daily DD, 8% weekly DD             |
//|    Structure-based SL, liquidity-pool TP                         |
//|    Partial closes: 30% TP1, 30% TP2, 40% TP3 trail              |
//|    Scale-in only after profit confirmation                        |
//|    ZERO martingale / ZERO grid / ZERO averaging down             |
//+------------------------------------------------------------------+
#property copyright   "Institutional Systems"
#property version     "1.00"
#property description "XAUUSD Institutional Engine - Liquidity + Structure + Dynamic Risk"
#property strict

#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>
#include <Trade\OrderInfo.mqh>

//--- Dashboard prefix
#define PREFIX        "XIE_"
#define EA_VERSION    "XIE v1.0"
#define MAX_SWINGS    50
#define MAX_OB        20
#define MAX_FVG       20
#define MAX_LIQ       20
#define SCALE_MAGIC   999777UL

//+------------------------------------------------------------------+
//| ENUMERATIONS                                                     |
//+------------------------------------------------------------------+
enum ENUM_MARKET_REGIME
{
   REGIME_TRENDING_BULL  = 0,
   REGIME_TRENDING_BEAR  = 1,
   REGIME_RANGING        = 2,
   REGIME_VOLATILE       = 3,
   REGIME_LOW_LIQUIDITY  = 4,
   REGIME_NEWS           = 5
};

enum ENUM_STRUCTURE_TYPE
{
   STRUCT_NONE   = 0,
   STRUCT_BOS    = 1,   // Break of Structure
   STRUCT_CHOCH  = 2,   // Change of Character
   STRUCT_MSS    = 3    // Market Structure Shift
};

enum ENUM_BIAS
{
   BIAS_BULL    = 1,
   BIAS_BEAR    = -1,
   BIAS_NEUTRAL = 0
};

enum ENUM_SETUP_QUALITY
{
   QUALITY_NONE    = 0,
   QUALITY_STANDARD= 1,   // 75-84
   QUALITY_STRONG  = 2,   // 85-89
   QUALITY_ELITE   = 3    // 90-100
};

enum ENUM_TRADE_STAGE
{
   STAGE_NONE  = 0,
   STAGE_ONE   = 1,   // Initial entry
   STAGE_TWO   = 2,   // Add after profit confirmation
   STAGE_THREE = 3    // Final add after structure
};

enum ENUM_SESSION
{
   SESSION_ASIAN     = 0,
   SESSION_LONDON    = 1,
   SESSION_NEW_YORK  = 2,
   SESSION_OVERLAP   = 3,
   SESSION_DEAD      = 4
};

enum ENUM_TP_MODE
{
   TP_STRUCTURE   = 0,
   TP_LIQUIDITY   = 1,
   TP_ATR         = 2,
   TP_SESSION     = 3
};

enum ENUM_TRAIL_MODE
{
   TRAIL_ATR       = 0,
   TRAIL_STRUCTURE = 1,
   TRAIL_SWING     = 2
};

//+------------------------------------------------------------------+
//| INPUT PARAMETERS                                                 |
//+------------------------------------------------------------------+
input group "=== IDENTITY ==="
input ulong   InpMagic            = 999777;
input string  InpComment          = "XIE_GOLD";

input group "=== RISK ENGINE ==="
input double  InpRiskPctDefault   = 0.5;      // Default risk per trade (% equity)
input double  InpRiskPctMax       = 1.0;      // Maximum risk per trade (% equity)
input double  InpRiskPctElite     = 1.5;      // Elite setup risk (% equity)
input double  InpDailyDDLimit     = 3.0;      // Daily drawdown halt (% equity)
input double  InpWeeklyDDLimit    = 8.0;      // Weekly drawdown halt (% equity)
input int     InpConsecLossReduce = 3;        // Consecutive losses to halve risk
input int     InpConsecLossHalt   = 5;        // Consecutive losses to halt

input group "=== ENTRY QUALITY FILTER ==="
input int     InpMinScore         = 75;       // Minimum score to trade (0-100)
input int     InpStrongScore      = 85;       // Strong setup score
input int     InpEliteScore       = 90;       // Elite setup score

input group "=== SIGNAL ENGINE WEIGHTS ==="
input int     InpWtRegime         = 15;       // Market regime weight
input int     InpWtStructure      = 20;       // Market structure weight
input int     InpWtLiquidity      = 18;       // Liquidity engine weight
input int     InpWtDisplacement   = 12;       // Displacement weight
input int     InpWtFVG            = 12;       // Fair Value Gap weight
input int     InpWtOB             = 13;       // Order Block weight
input int     InpWtVolume         = 10;       // Volume confirmation weight

input group "=== STRUCTURE PARAMETERS ==="
input int     InpSwingLookback    = 10;       // Bars to identify swing highs/lows
input int     InpStructureBars    = 50;       // Lookback for structure analysis
input double  InpBOSMinMove       = 0.5;      // Min ATR multiple for valid BOS

input group "=== FAIR VALUE GAP ==="
input int     InpFVGMinBars       = 1;        // Minimum bars to confirm FVG
input double  InpFVGMinSize       = 0.3;      // Min FVG size as ATR multiple

input group "=== ORDER BLOCK ==="
input int     InpOBLookback       = 30;       // Bars to scan for order blocks
input double  InpOBMinBody        = 0.6;      // Min body ratio for OB candle

input group "=== TAKE PROFIT ==="
input double  InpMinRR            = 1.5;      // Minimum Risk:Reward ratio
input double  InpPreferredRR      = 2.0;      // Preferred RR
input double  InpStrongRR         = 3.0;      // Strong setup RR
input double  InpEliteRR          = 4.0;      // Elite setup RR
input double  InpTP1Pct           = 30.0;     // % position closed at TP1
input double  InpTP2Pct           = 30.0;     // % position closed at TP2
input double  InpTP3Pct           = 40.0;     // % remaining rides with trail

input group "=== STOP LOSS ==="
input int     InpSLBufferPoints   = 50;       // Extra SL buffer beyond structure (points)
input double  InpSLATRMult        = 0.3;      // Additional ATR buffer for SL
input double  InpMaxSLPoints      = 500;      // Maximum SL in points (risk guard)

input group "=== SCALE-IN ==="
input bool    InpAllowScaleIn     = false;    // OFF by default in bulk-3 mode (legs already cover TP1/TP2/TP3)
input double  InpScaleInProfit    = 0.5;      // Min floating profit (ATR) before scale-in
input int     InpMaxStagePositions= 2;        // Max scale-in additions

input group "=== TRAILING STOP ==="
input double  InpTrailATRMult     = 1.5;      // ATR multiplier for ATR trail
input int     InpTrailSwingBars   = 5;        // Swing bars for structure trail

input group "=== MULTI-TIMEFRAME ==="
input ENUM_TIMEFRAMES InpHTF_Bias    = PERIOD_H1;   // Bias timeframe
input ENUM_TIMEFRAMES InpMTF_Struct  = PERIOD_M15;  // Structure timeframe
input ENUM_TIMEFRAMES InpMTF_Confirm = PERIOD_M5;   // Confirmation timeframe
// Entry: current chart (M1 recommended)

input group "=== SESSION FILTER ==="
input bool    InpUseSessionFilter = true;
input bool    InpTradeAsian       = false;
input bool    InpTradeLondon      = true;
input bool    InpTradeNY          = true;
input bool    InpTradeOverlap     = true;
input int     InpLondonOpen       = 7;        // UTC hour
input int     InpLondonClose      = 16;
input int     InpNYOpen           = 13;
input int     InpNYClose          = 22;
input int     InpAsianOpen        = 0;
input int     InpAsianClose       = 8;

input group "=== NEWS FILTER ==="
input bool    InpUseNewsFilter    = true;
input int     InpNewsPreMinutes   = 30;       // Pause before high-impact news
input int     InpNewsPostMinutes  = 30;       // Pause after high-impact news

input group "=== VOLATILITY FILTER ==="
input int     InpATRPeriod        = 14;
input double  InpMinATRPips       = 3.0;      // Min ATR in pips to trade GOLD
input double  InpMaxATRMult       = 4.0;      // Max ATR spike multiplier
input int     InpMaxSpreadPoints  = 30;       // Max spread to allow entry

input group "=== PERFORMANCE ADAPTATION ==="
input bool    InpUseAdaptation    = true;
input int     InpAdaptLookback    = 20;       // Trades to evaluate for adaptation
input double  InpAdaptMinWR       = 0.35;     // Minimum win rate before reducing risk
input double  InpAdaptGoodWR      = 0.60;     // Win rate considered good

input group "=== DASHBOARD ==="
input int     InpDashX            = 12;
input int     InpDashY            = 12;

//+------------------------------------------------------------------+
//| DATA STRUCTURES                                                  |
//+------------------------------------------------------------------+
struct SwingPoint
{
   double   price;
   datetime time;
   int      bar;
   bool     isHigh;
   bool     valid;
};

struct OrderBlock
{
   double   high;
   double   low;
   double   mid;
   datetime time;
   bool     isBull;       // true = demand OB, false = supply OB
   bool     mitigated;
   double   strengthScore;
   bool     valid;
};

struct FairValueGap
{
   double   high;         // Upper boundary
   double   low;          // Lower boundary
   datetime time;
   bool     isBull;       // true = bullish FVG (buy into it), false = bearish
   bool     mitigated;
   double   sizeATR;      // FVG size in ATR multiples
   bool     valid;
};

struct LiquidityLevel
{
   double   price;
   datetime time;
   bool     isBuySide;    // true = equal highs (buy side liq), false = equal lows
   bool     swept;
   int      touchCount;
   bool     valid;
};

struct TradeRecord
{
   double   pnl;
   bool     win;
   datetime closeTime;
   int      score;
   ENUM_SESSION session;
};

struct ScalePosition
{
   ulong    ticket;
   ENUM_TRADE_STAGE stage;
   double   entryPrice;
   double   sl;
   double   tp1;
   double   tp2;
   double   tp3;
   bool     tp1Hit;
   bool     tp2Hit;
   bool     beSet;
   ENUM_TRAIL_MODE trailMode;
   double   trailLevel;
   double   lotSize;
   ENUM_ORDER_TYPE direction;
};

//+------------------------------------------------------------------+
//| GLOBAL STATE                                                     |
//+------------------------------------------------------------------+
CTrade          g_Trade;
CPositionInfo   g_Pos;
COrderInfo      g_Ord;

//--- Indicator handles (current TF)
int   g_hATR       = INVALID_HANDLE;
int   g_hATR_M15   = INVALID_HANDLE;
int   g_hATR_H1    = INVALID_HANDLE;

//--- EMA for regime detection
int   g_hEMA20     = INVALID_HANDLE;
int   g_hEMA50     = INVALID_HANDLE;
int   g_hEMA200    = INVALID_HANDLE;
int   g_hEMA20_H1  = INVALID_HANDLE;
int   g_hEMA50_H1  = INVALID_HANDLE;
int   g_hEMA200_H1 = INVALID_HANDLE;
int   g_hEMA20_M15 = INVALID_HANDLE;
int   g_hEMA50_M15 = INVALID_HANDLE;

//--- Swing arrays
SwingPoint  g_SwingsM1[MAX_SWINGS];
SwingPoint  g_SwingsM15[MAX_SWINGS];
SwingPoint  g_SwingsH1[MAX_SWINGS];
int         g_SwingCountM1  = 0;
int         g_SwingCountM15 = 0;
int         g_SwingCountH1  = 0;

//--- Structure arrays
OrderBlock   g_OBArray[MAX_OB];
int          g_OBCount    = 0;
FairValueGap g_FVGArray[MAX_FVG];
int          g_FVGCount   = 0;
LiquidityLevel g_LiqArray[MAX_LIQ];
int          g_LiqCount   = 0;

//--- Active positions tracking
ScalePosition g_Positions[10];
int           g_PosCount = 0;

//--- Trade history for adaptation
TradeRecord  g_History[100];
int          g_HistoryCount = 0;

//--- Session / regime state
ENUM_SESSION         g_Session       = SESSION_DEAD;
ENUM_MARKET_REGIME   g_Regime        = REGIME_LOW_LIQUIDITY;
ENUM_BIAS            g_HTF_Bias      = BIAS_NEUTRAL;
ENUM_BIAS            g_MTF_Bias      = BIAS_NEUTRAL;
ENUM_STRUCTURE_TYPE  g_LastStructure = STRUCT_NONE;
ENUM_BIAS            g_StructureBias = BIAS_NEUTRAL;

//--- Risk state
double  g_DayStartEquity   = 0.0;
double  g_WeekStartEquity  = 0.0;
double  g_DailyPnL         = 0.0;
double  g_WeeklyPnL        = 0.0;
bool    g_DailyHalt        = false;
bool    g_WeeklyHalt       = false;
bool    g_TradingHalt      = false;
int     g_ConsecLosses     = 0;
int     g_ConsecWins       = 0;
double  g_CurrentRiskPct   = 0.0;
datetime g_LastDayReset    = 0;
datetime g_LastWeekReset   = 0;

//--- Score / signal state
int     g_LastScore        = 0;
ENUM_SETUP_QUALITY g_LastQuality = QUALITY_NONE;
ENUM_ORDER_TYPE    g_LastDir    = ORDER_TYPE_BUY;
string  g_StatusText       = "INITIALISING";
color   g_StatusColor      = clrGray;
string  g_RegimeLabel      = "UNKNOWN";
string  g_SessionLabel     = "DEAD";

//--- News filter (manual high-impact event schedule kept by user)
bool    g_NewsActive       = false;
datetime g_NewsWindowEnd   = 0;

//--- Adaptation state
double  g_AdaptRiskMult    = 1.0;   // 0.5 when underperforming, up to 1.0 normal
bool    g_AdaptReduced     = false;

//--- Cached ATR values
double  g_ATR_M1           = 0.0;
double  g_ATR_M15          = 0.0;
double  g_ATR_H1           = 0.0;

//--- Dashboard heartbeat
uint    g_Heartbeat        = 0;

//--- Scan throttle - only full scan once per bar
datetime g_LastBarTime     = 0;
datetime g_LastM15Bar      = 0;
datetime g_LastH1Bar       = 0;

//--- Performance metrics
double  g_TotalProfit      = 0.0;
int     g_TotalTrades      = 0;
int     g_TotalWins        = 0;
double  g_ProfitFactor     = 0.0;

//+------------------------------------------------------------------+
//| FORWARD DECLARATIONS                                             |
//+------------------------------------------------------------------+
// Initialization
bool   InitIndicators();
void   ResetDayTracking();
void   ResetWeekTracking();

// Market analysis
void   UpdateATR();
void   UpdateSwings(ENUM_TIMEFRAMES tf, SwingPoint &arr[], int &cnt);
ENUM_MARKET_REGIME DetectRegime();
ENUM_BIAS  GetHTFBias();
ENUM_BIAS  GetMTFBias();
void   ScanOrderBlocks();
void   ScanFairValueGaps();
void   ScanLiquidityLevels();
ENUM_STRUCTURE_TYPE DetectStructure(ENUM_BIAS &structBias);
bool   DetectDisplacement(ENUM_ORDER_TYPE dir);
bool   DetectLiquiditySweep(ENUM_ORDER_TYPE dir, double &sweepPrice);
bool   IsNearFVG(ENUM_ORDER_TYPE dir, double &fvgHigh, double &fvgLow);
bool   IsNearOrderBlock(ENUM_ORDER_TYPE dir, double &obHigh, double &obLow, double &obScore);
double GetRelativeVolume(int barsBack);

// Signal engine
int    ComputeSignalScore(ENUM_ORDER_TYPE &outDir);
int    ScoreRegimeLayer(ENUM_ORDER_TYPE dir);
int    ScoreStructureLayer(ENUM_ORDER_TYPE dir);
int    ScoreLiquidityLayer(ENUM_ORDER_TYPE dir);
int    ScoreDisplacementLayer(ENUM_ORDER_TYPE dir);
int    ScoreFVGLayer(ENUM_ORDER_TYPE dir);
int    ScoreOBLayer(ENUM_ORDER_TYPE dir);
int    ScoreVolumeLayer(ENUM_ORDER_TYPE dir);

// Trade management
double CalcLotSize(double riskPct, double slPoints);
double CalcStructureSL(ENUM_ORDER_TYPE dir, double entryPrice);
double CalcDynamicTP(ENUM_ORDER_TYPE dir, double entryPrice, double slDist, int score);
ENUM_TP_MODE SelectTPMode(ENUM_ORDER_TYPE dir, double slDist);
double FindLiquidityTarget(ENUM_ORDER_TYPE dir, double entryPrice);
double FindStructureTarget(ENUM_ORDER_TYPE dir, double entryPrice);
void   OpenBulkSignalTrade(ENUM_ORDER_TYPE dir, int score);
void   CheckScaleIn();
void   ManagePositions();
void   UpdateTrailingStop(ScalePosition &pos);
void   HandlePartialClose(ScalePosition &pos);
bool   PositionExists(ulong ticket);
void   SyncPositionArray();
void   RecordTrade(double pnl, bool win, int score);

// Risk & session
bool   CheckRisk();
bool   CheckSession();
bool   CheckSpread();
bool   CheckNews();
double GetDailyDD();
double GetWeeklyDD();
void   UpdateRiskState();
void   AdaptRisk();
ENUM_SESSION DetectSession();

// Dashboard
void   RenderDashboard();
void   RefreshDashboard();
void   PurgeDashboard();
void   DLabel(string id, int x, int y, string txt, color clr, int sz, string font="Arial");
void   DRect(string id, int x, int y, int w, int h, color bg, color brd, int bw=1);
void   DUpdate(string id, string txt, color clr=clrNONE);

// Utility
double   GetSwingHigh(ENUM_TIMEFRAMES tf, int lookback);
double   GetSwingLow(ENUM_TIMEFRAMES tf, int lookback);
datetime GetWeekStart(datetime t);
datetime GetDayStart(datetime t);
double   Pip() { return SymbolInfoDouble(_Symbol, SYMBOL_POINT) * 10; }
double   Pt()  { return SymbolInfoDouble(_Symbol, SYMBOL_POINT); }
int      Dgs() { return (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS); }
double   Normalize(double v) { return NormalizeDouble(v, Dgs()); }

//+------------------------------------------------------------------+
//| ON INIT                                                          |
//+------------------------------------------------------------------+
int OnInit()
{
   g_Trade.SetExpertMagicNumber(InpMagic);
   g_Trade.SetDeviationInPoints(20);
   g_Trade.SetTypeFilling(ORDER_FILLING_IOC);

   if(!InitIndicators())
   {
      Print("[XIE] CRITICAL: Indicator init failed.");
      return INIT_FAILED;
   }

   ResetDayTracking();
   ResetWeekTracking();

   g_CurrentRiskPct = InpRiskPctDefault;
   g_AdaptRiskMult  = 1.0;

   for(int i=0; i<MAX_SWINGS; i++)
   {
      g_SwingsM1[i].valid  = false;
      g_SwingsM15[i].valid = false;
      g_SwingsH1[i].valid  = false;
   }

   for(int i=0; i<MAX_OB;  i++) g_OBArray[i].valid  = false;
   for(int i=0; i<MAX_FVG; i++) g_FVGArray[i].valid = false;
   for(int i=0; i<MAX_LIQ; i++) g_LiqArray[i].valid = false;
   for(int i=0; i<10;      i++) g_Positions[i].ticket = 0;

   EventSetTimer(1);
   RenderDashboard();

   Print("[XIE] Initialised. Magic=", InpMagic, " Risk=", InpRiskPctDefault, "%");
   return INIT_SUCCEEDED;
}

bool InitIndicators()
{
   g_hATR      = iATR(_Symbol, _Period,     InpATRPeriod);
   g_hATR_M15  = iATR(_Symbol, PERIOD_M15,  InpATRPeriod);
   g_hATR_H1   = iATR(_Symbol, PERIOD_H1,   InpATRPeriod);

   g_hEMA20    = iMA(_Symbol, _Period,     20,  0, MODE_EMA, PRICE_CLOSE);
   g_hEMA50    = iMA(_Symbol, _Period,     50,  0, MODE_EMA, PRICE_CLOSE);
   g_hEMA200   = iMA(_Symbol, _Period,     200, 0, MODE_EMA, PRICE_CLOSE);
   g_hEMA20_H1 = iMA(_Symbol, PERIOD_H1,  20,  0, MODE_EMA, PRICE_CLOSE);
   g_hEMA50_H1 = iMA(_Symbol, PERIOD_H1,  50,  0, MODE_EMA, PRICE_CLOSE);
   g_hEMA200_H1= iMA(_Symbol, PERIOD_H1,  200, 0, MODE_EMA, PRICE_CLOSE);
   g_hEMA20_M15= iMA(_Symbol, PERIOD_M15, 20,  0, MODE_EMA, PRICE_CLOSE);
   g_hEMA50_M15= iMA(_Symbol, PERIOD_M15, 50,  0, MODE_EMA, PRICE_CLOSE);

   int handles[] = {g_hATR, g_hATR_M15, g_hATR_H1,
                    g_hEMA20, g_hEMA50, g_hEMA200,
                    g_hEMA20_H1, g_hEMA50_H1, g_hEMA200_H1,
                    g_hEMA20_M15, g_hEMA50_M15};
   for(int i=0; i<ArraySize(handles); i++)
      if(handles[i] == INVALID_HANDLE) return false;
   return true;
}

void ResetDayTracking()
{
   g_DayStartEquity = AccountInfoDouble(ACCOUNT_EQUITY);
   g_DailyPnL       = 0.0;
   g_DailyHalt      = false;
   g_LastDayReset   = GetDayStart(TimeCurrent());
}

void ResetWeekTracking()
{
   g_WeekStartEquity = AccountInfoDouble(ACCOUNT_EQUITY);
   g_WeeklyPnL       = 0.0;
   g_WeeklyHalt      = false;
   g_LastWeekReset   = GetWeekStart(TimeCurrent());
}

//+------------------------------------------------------------------+
//| ON DEINIT                                                        |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   EventKillTimer();
   PurgeDashboard();
   int handles[] = {g_hATR, g_hATR_M15, g_hATR_H1,
                    g_hEMA20, g_hEMA50, g_hEMA200,
                    g_hEMA20_H1, g_hEMA50_H1, g_hEMA200_H1,
                    g_hEMA20_M15, g_hEMA50_M15};
   for(int i=0; i<ArraySize(handles); i++)
      if(handles[i] != INVALID_HANDLE) IndicatorRelease(handles[i]);
}

//+------------------------------------------------------------------+
//| ON TIMER - 1 second heartbeat                                   |
//+------------------------------------------------------------------+
void OnTimer()
{
   g_Heartbeat++;
   g_Session = DetectSession();
   UpdateRiskState();
   if(InpUseAdaptation) AdaptRisk();
   RefreshDashboard();
}

//+------------------------------------------------------------------+
//| ON TICK - MAIN EXECUTION LOOP                                   |
//+------------------------------------------------------------------+
void OnTick()
{
   //--- Day/week reset check
   datetime now = TimeCurrent();
   if(GetDayStart(now)  > g_LastDayReset)  ResetDayTracking();
   if(GetWeekStart(now) > g_LastWeekReset) ResetWeekTracking();

   //--- Always manage open positions first (SL/TP/Trail/Partial)
   SyncPositionArray();
   ManagePositions();

   //--- Gate checks - do not look for new entries if halted
   if(g_DailyHalt || g_WeeklyHalt || g_TradingHalt) return;
   if(!CheckRisk())    return;
   if(!CheckSpread())  return;
   if(!CheckNews())    return;
   if(InpUseSessionFilter && !CheckSession()) return;

   //--- Only run full analysis on new bar to save CPU
   datetime barTime = iTime(_Symbol, _Period, 0);
   bool newBar = (barTime != g_LastBarTime);
   if(newBar) g_LastBarTime = barTime;

   datetime m15Bar = iTime(_Symbol, PERIOD_M15, 0);
   bool newM15 = (m15Bar != g_LastM15Bar);
   if(newM15) g_LastM15Bar = m15Bar;

   datetime h1Bar = iTime(_Symbol, PERIOD_H1, 0);
   bool newH1 = (h1Bar != g_LastH1Bar);
   if(newH1) g_LastH1Bar = h1Bar;

   //--- Update ATR on every tick (fast)
   UpdateATR();

   //--- Heavy analysis only on new bars
   if(newH1)
   {
      UpdateSwings(PERIOD_H1, g_SwingsH1, g_SwingCountH1);
      g_HTF_Bias = GetHTFBias();
   }

   if(newM15)
   {
      UpdateSwings(PERIOD_M15, g_SwingsM15, g_SwingCountM15);
      g_MTF_Bias = GetMTFBias();
      g_LastStructure = DetectStructure(g_StructureBias);
      ScanOrderBlocks();
      ScanFairValueGaps();
      ScanLiquidityLevels();
   }

   if(newBar)
   {
      UpdateSwings(_Period, g_SwingsM1, g_SwingCountM1);
      g_Regime = DetectRegime();
   }

   //--- Scale-in check on every tick (needs to react quickly to price)
   //--- NOTE: Scale-in is bypassed in bulk-3 mode. Each bulk leg already
   //--- represents one tier (TP1/TP2/TP3) of the total risk allocation,
   //--- so adding a scale-in position on top would exceed the intended
   //--- "3 legs = 1 normal trade" risk budget. Re-enable only if you
   //--- return to single-entry Stage 1/2/3 mode.
   if(InpAllowScaleIn) CheckScaleIn();

   //--- New entry logic - only on new M1 bar for clean execution
   if(!newBar) return;

   //--- Regime gate - only trade in favorable regimes
   if(g_Regime == REGIME_NEWS || g_Regime == REGIME_LOW_LIQUIDITY) return;

   //--- Need HTF and MTF agreement before computing full score
   if(g_HTF_Bias == BIAS_NEUTRAL) return;

   //--- Count existing positions from this EA
   //--- Since one signal now opens a full 3-leg bulk group, block any new
   //--- bulk entry while a group is still active - prevents stacking
   //--- multiple bulk groups on top of each other.
   int existingCount = 0;
   for(int i=0; i<g_PosCount; i++)
      if(g_Positions[i].ticket > 0) existingCount++;
   if(existingCount > 0) return;

   //--- Run full signal engine
   ENUM_ORDER_TYPE signalDir = ORDER_TYPE_BUY;
   int score = ComputeSignalScore(signalDir);
   g_LastScore = score;

   if(score < InpMinScore) return;

   //--- HTF bias must align with signal
   if(g_HTF_Bias == BIAS_BULL  && signalDir == ORDER_TYPE_SELL) return;
   if(g_HTF_Bias == BIAS_BEAR  && signalDir == ORDER_TYPE_BUY)  return;

   //--- Open Stage 1 position
   OpenBulkSignalTrade(signalDir, score);
}

//+------------------------------------------------------------------+
//| ATR UPDATE                                                       |
//+------------------------------------------------------------------+
void UpdateATR()
{
   double buf[1];
   if(CopyBuffer(g_hATR,     0, 1, 1, buf) > 0) g_ATR_M1  = buf[0];
   if(CopyBuffer(g_hATR_M15, 0, 1, 1, buf) > 0) g_ATR_M15 = buf[0];
   if(CopyBuffer(g_hATR_H1,  0, 1, 1, buf) > 0) g_ATR_H1  = buf[0];
}

//+------------------------------------------------------------------+
//| SWING DETECTION - identifies HH, HL, LH, LL                    |
//+------------------------------------------------------------------+
void UpdateSwings(ENUM_TIMEFRAMES tf, SwingPoint &arr[], int &cnt)
{
   int lookback = InpSwingLookback;
   int maxBars  = InpStructureBars + lookback;
   cnt = 0;

   double high[], low[];
   datetime times[];
   ArraySetAsSeries(high,  true);
   ArraySetAsSeries(low,   true);
   ArraySetAsSeries(times, true);

   if(CopyHigh (_Symbol, tf, 0, maxBars, high)  <= 0) return;
   if(CopyLow  (_Symbol, tf, 0, maxBars, low)   <= 0) return;
   if(CopyTime (_Symbol, tf, 0, maxBars, times) <= 0) return;

   for(int i = lookback; i < maxBars - lookback && cnt < MAX_SWINGS - 1; i++)
   {
      //--- Swing high: higher than all bars within lookback on both sides
      bool isSwingHigh = true;
      bool isSwingLow  = true;
      for(int j = 1; j <= lookback; j++)
      {
         if(high[i] <= high[i-j] || high[i] <= high[i+j]) isSwingHigh = false;
         if(low[i]  >= low[i-j]  || low[i]  >= low[i+j])  isSwingLow  = false;
      }
      if(isSwingHigh)
      {
         arr[cnt].price  = high[i];
         arr[cnt].time   = times[i];
         arr[cnt].bar    = i;
         arr[cnt].isHigh = true;
         arr[cnt].valid  = true;
         cnt++;
      }
      else if(isSwingLow && cnt < MAX_SWINGS - 1)
      {
         arr[cnt].price  = low[i];
         arr[cnt].time   = times[i];
         arr[cnt].bar    = i;
         arr[cnt].isHigh = false;
         arr[cnt].valid  = true;
         cnt++;
      }
   }
}

//+------------------------------------------------------------------+
//| LAYER 1 - MARKET REGIME DETECTION                               |
//+------------------------------------------------------------------+
ENUM_MARKET_REGIME DetectRegime()
{
   if(g_ATR_M1 <= 0) return REGIME_LOW_LIQUIDITY;

   //--- Check spread as proxy for liquidity
   int spread = (int)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   if(spread > InpMaxSpreadPoints * 2) return REGIME_LOW_LIQUIDITY;

   //--- ATR spike = volatile / possible news
   if(g_ATR_M15 > 0 && g_ATR_M1 > g_ATR_M15 * InpMaxATRMult)
      return REGIME_VOLATILE;

   //--- Minimum volatility for GOLD
   double minATRValue = InpMinATRPips * Pip();
   if(g_ATR_M15 < minATRValue) return REGIME_LOW_LIQUIDITY;

   //--- Get EMAs for trend detection
   double ema20[1], ema50[1], ema200[1];
   if(CopyBuffer(g_hEMA20,  0, 1, 1, ema20)  <= 0) return REGIME_RANGING;
   if(CopyBuffer(g_hEMA50,  0, 1, 1, ema50)  <= 0) return REGIME_RANGING;
   if(CopyBuffer(g_hEMA200, 0, 1, 1, ema200) <= 0) return REGIME_RANGING;

   double price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double spread200 = MathAbs(ema20[0] - ema200[0]);
   double spreadPct = (ema200[0] > 0) ? spread200 / ema200[0] : 0;

   //--- Clear trend: EMAs fanned and price above/below all
   bool bullTrend = (ema20[0] > ema50[0] && ema50[0] > ema200[0] && price > ema200[0]);
   bool bearTrend = (ema20[0] < ema50[0] && ema50[0] < ema200[0] && price < ema200[0]);

   if(bullTrend && spreadPct > 0.001) { g_RegimeLabel = "BULL TREND"; return REGIME_TRENDING_BULL; }
   if(bearTrend && spreadPct > 0.001) { g_RegimeLabel = "BEAR TREND"; return REGIME_TRENDING_BEAR; }

   //--- Ranging: EMAs clustered
   if(spreadPct < 0.0005) { g_RegimeLabel = "RANGING"; return REGIME_RANGING; }

   g_RegimeLabel = "RANGING";
   return REGIME_RANGING;
}

//+------------------------------------------------------------------+
//| HTF BIAS - H1 trend direction                                   |
//+------------------------------------------------------------------+
ENUM_BIAS GetHTFBias()
{
   double ema20[1], ema50[1], ema200[1];
   if(CopyBuffer(g_hEMA20_H1,  0, 1, 1, ema20)  <= 0) return BIAS_NEUTRAL;
   if(CopyBuffer(g_hEMA50_H1,  0, 1, 1, ema50)  <= 0) return BIAS_NEUTRAL;
   if(CopyBuffer(g_hEMA200_H1, 0, 1, 1, ema200) <= 0) return BIAS_NEUTRAL;

   double price = SymbolInfoDouble(_Symbol, SYMBOL_BID);

   //--- Strong bull: all EMAs stacked and price above 200
   if(ema20[0] > ema50[0] && price > ema200[0]) return BIAS_BULL;
   if(ema20[0] < ema50[0] && price < ema200[0]) return BIAS_BEAR;

   //--- Weak signals
   if(price > ema50[0] && ema20[0] > ema50[0]) return BIAS_BULL;
   if(price < ema50[0] && ema20[0] < ema50[0]) return BIAS_BEAR;

   return BIAS_NEUTRAL;
}

//+------------------------------------------------------------------+
//| MTF BIAS - M15 structure direction                              |
//+------------------------------------------------------------------+
ENUM_BIAS GetMTFBias()
{
   double ema20[1], ema50[1];
   if(CopyBuffer(g_hEMA20_M15, 0, 1, 1, ema20) <= 0) return BIAS_NEUTRAL;
   if(CopyBuffer(g_hEMA50_M15, 0, 1, 1, ema50) <= 0) return BIAS_NEUTRAL;

   double price = SymbolInfoDouble(_Symbol, SYMBOL_BID);

   //--- Use swing structure for MTF bias
   if(g_SwingCountM15 >= 4)
   {
      //--- Find most recent HH/HL = bullish structure, LH/LL = bearish
      double lastHigh1 = 0, lastHigh2 = 0;
      double lastLow1  = 0, lastLow2  = 0;
      int hc = 0, lc = 0;
      for(int i=0; i<g_SwingCountM15 && (hc<2 || lc<2); i++)
      {
         if(g_SwingsM15[i].isHigh && hc < 2) { if(hc==0) lastHigh1=g_SwingsM15[i].price; else lastHigh2=g_SwingsM15[i].price; hc++; }
         if(!g_SwingsM15[i].isHigh && lc < 2) { if(lc==0) lastLow1=g_SwingsM15[i].price; else lastLow2=g_SwingsM15[i].price; lc++; }
      }
      if(hc >= 2 && lc >= 2)
      {
         bool hhPattern = (lastHigh1 > lastHigh2);   // newer high > older high
         bool hlPattern = (lastLow1  > lastLow2);    // newer low  > older low
         bool lhPattern = (lastHigh1 < lastHigh2);
         bool llPattern = (lastLow1  < lastLow2);
         if(hhPattern && hlPattern) return BIAS_BULL;
         if(lhPattern && llPattern) return BIAS_BEAR;
      }
   }

   //--- Fallback to EMA
   if(ema20[0] > ema50[0] && price > ema20[0]) return BIAS_BULL;
   if(ema20[0] < ema50[0] && price < ema20[0]) return BIAS_BEAR;

   return BIAS_NEUTRAL;
}

//+------------------------------------------------------------------+
//| LAYER 2 - MARKET STRUCTURE: BOS / CHoCH / MSS                  |
//+------------------------------------------------------------------+
ENUM_STRUCTURE_TYPE DetectStructure(ENUM_BIAS &structBias)
{
   if(g_SwingCountM15 < 4) return STRUCT_NONE;

   //--- Build ordered swing highs and lows
   double highs[10]; int hc = 0;
   double lows[10];  int lc = 0;

   for(int i=0; i<g_SwingCountM15 && (hc<10 || lc<10); i++)
   {
      if(g_SwingsM15[i].isHigh  && hc < 10) highs[hc++] = g_SwingsM15[i].price;
      if(!g_SwingsM15[i].isHigh && lc < 10) lows[lc++]  = g_SwingsM15[i].price;
   }

   if(hc < 2 || lc < 2) return STRUCT_NONE;

   double price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double atrMult = g_ATR_M15 * InpBOSMinMove;

   //--- BOS Bull: price breaks above most recent swing high by meaningful amount
   if(price > highs[0] + atrMult)
   {
      structBias = BIAS_BULL;
      //--- CHoCH: previous structure was bearish (lower highs) but now broken up
      if(hc >= 2 && highs[0] < highs[1]) { return STRUCT_CHOCH; }
      return STRUCT_BOS;
   }

   //--- BOS Bear: price breaks below most recent swing low
   if(price < lows[0] - atrMult)
   {
      structBias = BIAS_BEAR;
      if(lc >= 2 && lows[0] > lows[1]) { return STRUCT_CHOCH; }
      return STRUCT_BOS;
   }

   //--- MSS: Market structure shift - swing sequence changed character
   if(hc >= 3 && lc >= 3)
   {
      bool wasBearer = (highs[1] < highs[2] && lows[1] < lows[2]);
      bool nowBull   = (highs[0] > highs[1] && lows[0] > lows[1]);
      if(wasBearer && nowBull) { structBias = BIAS_BULL; return STRUCT_MSS; }

      bool wasBull   = (highs[1] > highs[2] && lows[1] > lows[2]);
      bool nowBear   = (highs[0] < highs[1] && lows[0] < lows[1]);
      if(wasBull && nowBear) { structBias = BIAS_BEAR; return STRUCT_MSS; }
   }

   return STRUCT_NONE;
}

//+------------------------------------------------------------------+
//| LAYER 3 - LIQUIDITY SCANNING                                    |
//+------------------------------------------------------------------+
void ScanLiquidityLevels()
{
   int cnt = 0;
   for(int i=0; i<MAX_LIQ; i++) g_LiqArray[i].valid = false;

   double high[], low[];
   datetime times[];
   int bars = 100;
   ArraySetAsSeries(high,  true);
   ArraySetAsSeries(low,   true);
   ArraySetAsSeries(times, true);
   if(CopyHigh (_Symbol, PERIOD_M15, 0, bars, high)  <= 0) return;
   if(CopyLow  (_Symbol, PERIOD_M15, 0, bars, low)   <= 0) return;
   if(CopyTime (_Symbol, PERIOD_M15, 0, bars, times) <= 0) return;

   double tolerance = g_ATR_M15 * 0.15;

   for(int i = 5; i < bars - 5 && cnt < MAX_LIQ - 1; i++)
   {
      //--- Look for equal highs (buy side liquidity)
      int touches = 0;
      for(int j = 1; j < bars && j != i; j++)
         if(MathAbs(high[i] - high[j]) < tolerance) touches++;

      if(touches >= 1)  // at least 2 touches total
      {
         g_LiqArray[cnt].price      = high[i];
         g_LiqArray[cnt].time       = times[i];
         g_LiqArray[cnt].isBuySide  = true;
         g_LiqArray[cnt].swept      = false;
         g_LiqArray[cnt].touchCount = touches + 1;
         g_LiqArray[cnt].valid      = true;
         cnt++;
      }
   }

   for(int i = 5; i < bars - 5 && cnt < MAX_LIQ - 1; i++)
   {
      //--- Look for equal lows (sell side liquidity)
      int touches = 0;
      for(int j = 1; j < bars && j != i; j++)
         if(MathAbs(low[i] - low[j]) < tolerance) touches++;

      if(touches >= 1)
      {
         g_LiqArray[cnt].price      = low[i];
         g_LiqArray[cnt].time       = times[i];
         g_LiqArray[cnt].isBuySide  = false;
         g_LiqArray[cnt].swept      = false;
         g_LiqArray[cnt].touchCount = touches + 1;
         g_LiqArray[cnt].valid      = true;
         cnt++;
      }
   }
   g_LiqCount = cnt;
}

bool DetectLiquiditySweep(ENUM_ORDER_TYPE dir, double &sweepPrice)
{
   double price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   sweepPrice   = 0.0;

   //--- A sweep: price went through a liquidity level and came back
   double open1[1], close1[1], high1[1], low1[1];
   if(CopyOpen (_Symbol, _Period, 1, 1, open1)  <= 0) return false;
   if(CopyClose(_Symbol, _Period, 1, 1, close1) <= 0) return false;
   if(CopyHigh (_Symbol, _Period, 1, 1, high1)  <= 0) return false;
   if(CopyLow  (_Symbol, _Period, 1, 1, low1)   <= 0) return false;

   for(int i=0; i<g_LiqCount; i++)
   {
      if(!g_LiqArray[i].valid || g_LiqArray[i].swept) continue;

      if(dir == ORDER_TYPE_BUY && !g_LiqArray[i].isBuySide)
      {
         //--- Sell-side liq swept = price spiked below equal lows then closed above
         bool spikedBelow = (low1[0] < g_LiqArray[i].price);
         bool closedAbove = (close1[0] > g_LiqArray[i].price);
         if(spikedBelow && closedAbove)
         {
            g_LiqArray[i].swept = true;
            sweepPrice = g_LiqArray[i].price;
            return true;
         }
      }

      if(dir == ORDER_TYPE_SELL && g_LiqArray[i].isBuySide)
      {
         //--- Buy-side liq swept = price spiked above equal highs then closed below
         bool spikedAbove = (high1[0] > g_LiqArray[i].price);
         bool closedBelow = (close1[0] < g_LiqArray[i].price);
         if(spikedAbove && closedBelow)
         {
            g_LiqArray[i].swept = true;
            sweepPrice = g_LiqArray[i].price;
            return true;
         }
      }
   }
   return false;
}

//+------------------------------------------------------------------+
//| LAYER 4 - DISPLACEMENT ENGINE                                   |
//+------------------------------------------------------------------+
bool DetectDisplacement(ENUM_ORDER_TYPE dir)
{
   //--- Institutional displacement: strong impulse candle (large body, expanding range)
   double open[], close[], high[], low[];
   int barsNeeded = 4;
   ArraySetAsSeries(open,  true);
   ArraySetAsSeries(close, true);
   ArraySetAsSeries(high,  true);
   ArraySetAsSeries(low,   true);
   if(CopyOpen (_Symbol, _Period, 1, barsNeeded, open)  <= 0) return false;
   if(CopyClose(_Symbol, _Period, 1, barsNeeded, close) <= 0) return false;
   if(CopyHigh (_Symbol, _Period, 1, barsNeeded, high)  <= 0) return false;
   if(CopyLow  (_Symbol, _Period, 1, barsNeeded, low)   <= 0) return false;

   if(g_ATR_M1 <= 0) return false;

   double body    = MathAbs(close[0] - open[0]);
   double range   = high[0] - low[0];
   double avgBody = 0;
   for(int i=1; i<barsNeeded; i++) avgBody += MathAbs(close[i]-open[i]);
   avgBody /= (barsNeeded - 1);

   //--- Displacement: body > 1.5x average body AND > 70% of range
   bool largeBody      = (body > avgBody * 1.5);
   bool dominantBody   = (range > 0 && body / range > 0.70);
   bool minSize        = (body > g_ATR_M1 * 0.5);

   if(!largeBody || !dominantBody || !minSize) return false;

   //--- Direction check
   bool bullCandle = (close[0] > open[0]);
   if(dir == ORDER_TYPE_BUY  && !bullCandle) return false;
   if(dir == ORDER_TYPE_SELL && bullCandle)  return false;

   return true;
}

//+------------------------------------------------------------------+
//| LAYER 5 - FAIR VALUE GAP ENGINE                                 |
//+------------------------------------------------------------------+
void ScanFairValueGaps()
{
   int cnt = 0;
   for(int i=0; i<MAX_FVG; i++) g_FVGArray[i].valid = false;

   int bars = 60;
   double high[], low[], open[], close[];
   ArraySetAsSeries(high,  true);
   ArraySetAsSeries(low,   true);
   ArraySetAsSeries(open,  true);
   ArraySetAsSeries(close, true);
   if(CopyHigh (_Symbol, PERIOD_M15, 0, bars, high)  <= 0) return;
   if(CopyLow  (_Symbol, PERIOD_M15, 0, bars, low)   <= 0) return;
   if(CopyOpen (_Symbol, PERIOD_M15, 0, bars, open)  <= 0) return;
   if(CopyClose(_Symbol, PERIOD_M15, 0, bars, close) <= 0) return;
   if(g_ATR_M15 <= 0) return;

   datetime times[];
   ArraySetAsSeries(times, true);
   if(CopyTime(_Symbol, PERIOD_M15, 0, bars, times) <= 0) return;

   double minGap = g_ATR_M15 * InpFVGMinSize;

   for(int i = 1; i < bars - 1 && cnt < MAX_FVG - 1; i++)
   {
      //--- Bullish FVG: low[i-1] (candle before) > high[i+1] (candle after) - gap between them
      //--- Array is series, so [0]=current, [1]=prev, [i-1]=newer, [i+1]=older
      double gapHigh = low[i-1];   // bottom of newer candle
      double gapLow  = high[i+1];  // top of older candle

      if(gapHigh > gapLow && gapHigh - gapLow >= minGap)
      {
         //--- Middle candle should be bullish (displacement)
         bool bullDisp = (close[i] > open[i] && MathAbs(close[i]-open[i]) > g_ATR_M15 * 0.3);
         if(bullDisp)
         {
            g_FVGArray[cnt].high     = gapHigh;
            g_FVGArray[cnt].low      = gapLow;
            g_FVGArray[cnt].time     = times[i];
            g_FVGArray[cnt].isBull   = true;
            g_FVGArray[cnt].mitigated= false;
            g_FVGArray[cnt].sizeATR  = (gapHigh - gapLow) / g_ATR_M15;
            g_FVGArray[cnt].valid    = true;
            cnt++;
         }
      }

      //--- Bearish FVG: high[i-1] < low[i+1]
      gapLow  = high[i-1];
      gapHigh = low[i+1];
      if(gapHigh > gapLow && gapHigh - gapLow >= minGap)
      {
         bool bearDisp = (close[i] < open[i] && MathAbs(close[i]-open[i]) > g_ATR_M15 * 0.3);
         if(bearDisp)
         {
            g_FVGArray[cnt].high     = gapHigh;
            g_FVGArray[cnt].low      = gapLow;
            g_FVGArray[cnt].time     = times[i];
            g_FVGArray[cnt].isBull   = false;
            g_FVGArray[cnt].mitigated= false;
            g_FVGArray[cnt].sizeATR  = (gapHigh - gapLow) / g_ATR_M15;
            g_FVGArray[cnt].valid    = true;
            cnt++;
         }
      }
   }
   g_FVGCount = cnt;

   //--- Mark mitigated FVGs (price has returned into them)
   double currentBid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   for(int i=0; i<g_FVGCount; i++)
   {
      if(!g_FVGArray[i].valid) continue;
      if(currentBid >= g_FVGArray[i].low && currentBid <= g_FVGArray[i].high)
         g_FVGArray[i].mitigated = true;
   }
}

bool IsNearFVG(ENUM_ORDER_TYPE dir, double &fvgHigh, double &fvgLow)
{
   double price     = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double proximity = g_ATR_M15 * 0.5;

   for(int i=0; i<g_FVGCount; i++)
   {
      if(!g_FVGArray[i].valid || g_FVGArray[i].mitigated) continue;

      if(dir == ORDER_TYPE_BUY && g_FVGArray[i].isBull)
      {
         //--- Price should be near or inside bullish FVG
         if(price <= g_FVGArray[i].high + proximity && price >= g_FVGArray[i].low - proximity)
         {
            fvgHigh = g_FVGArray[i].high;
            fvgLow  = g_FVGArray[i].low;
            return true;
         }
      }
      if(dir == ORDER_TYPE_SELL && !g_FVGArray[i].isBull)
      {
         if(price <= g_FVGArray[i].high + proximity && price >= g_FVGArray[i].low - proximity)
         {
            fvgHigh = g_FVGArray[i].high;
            fvgLow  = g_FVGArray[i].low;
            return true;
         }
      }
   }
   fvgHigh = 0; fvgLow = 0;
   return false;
}

//+------------------------------------------------------------------+
//| LAYER 6 - ORDER BLOCK ENGINE                                    |
//+------------------------------------------------------------------+
void ScanOrderBlocks()
{
   int cnt = 0;
   for(int i=0; i<MAX_OB; i++) g_OBArray[i].valid = false;

   int bars = InpOBLookback + 5;
   double open[], close[], high[], low[];
   datetime times[];
   ArraySetAsSeries(open,  true);
   ArraySetAsSeries(close, true);
   ArraySetAsSeries(high,  true);
   ArraySetAsSeries(low,   true);
   ArraySetAsSeries(times, true);
   if(CopyOpen (_Symbol, PERIOD_M15, 0, bars, open)  <= 0) return;
   if(CopyClose(_Symbol, PERIOD_M15, 0, bars, close) <= 0) return;
   if(CopyHigh (_Symbol, PERIOD_M15, 0, bars, high)  <= 0) return;
   if(CopyLow  (_Symbol, PERIOD_M15, 0, bars, low)   <= 0) return;
   if(CopyTime (_Symbol, PERIOD_M15, 0, bars, times) <= 0) return;
   if(g_ATR_M15 <= 0) return;

   for(int i = 2; i < bars - 1 && cnt < MAX_OB - 1; i++)
   {
      double body  = MathAbs(close[i] - open[i]);
      double range = high[i] - low[i];
      if(range <= 0) continue;
      double bodyRatio = body / range;
      if(bodyRatio < InpOBMinBody) continue;

      //--- Bullish OB: bearish candle followed immediately by a strong bullish impulse
      bool isBearCandle = (close[i] < open[i]);
      bool nextIsBull   = (i >= 1 && close[i-1] > open[i-1]);
      bool impulse      = (i >= 1 && MathAbs(close[i-1]-open[i-1]) > g_ATR_M15 * 0.5);

      if(isBearCandle && nextIsBull && impulse)
      {
         g_OBArray[cnt].high          = high[i];
         g_OBArray[cnt].low           = low[i];
         g_OBArray[cnt].mid           = (high[i] + low[i]) / 2.0;
         g_OBArray[cnt].time          = times[i];
         g_OBArray[cnt].isBull        = true;
         g_OBArray[cnt].mitigated     = false;
         g_OBArray[cnt].strengthScore = bodyRatio * 100.0;
         g_OBArray[cnt].valid         = true;
         cnt++;
         continue;
      }

      //--- Bearish OB: bullish candle followed by strong bearish impulse
      bool isBullCandle = (close[i] > open[i]);
      bool nextIsBear   = (i >= 1 && close[i-1] < open[i-1]);
      bool bearImpulse  = (i >= 1 && MathAbs(close[i-1]-open[i-1]) > g_ATR_M15 * 0.5);

      if(isBullCandle && nextIsBear && bearImpulse && cnt < MAX_OB - 1)
      {
         g_OBArray[cnt].high          = high[i];
         g_OBArray[cnt].low           = low[i];
         g_OBArray[cnt].mid           = (high[i] + low[i]) / 2.0;
         g_OBArray[cnt].time          = times[i];
         g_OBArray[cnt].isBull        = false;
         g_OBArray[cnt].mitigated     = false;
         g_OBArray[cnt].strengthScore = bodyRatio * 100.0;
         g_OBArray[cnt].valid         = true;
         cnt++;
      }
   }
   g_OBCount = cnt;

   //--- Mark mitigated OBs
   double currentBid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   for(int i=0; i<g_OBCount; i++)
   {
      if(!g_OBArray[i].valid) continue;
      if(currentBid >= g_OBArray[i].low && currentBid <= g_OBArray[i].high)
         g_OBArray[i].mitigated = true;
   }
}

bool IsNearOrderBlock(ENUM_ORDER_TYPE dir, double &obHigh, double &obLow, double &obScore)
{
   double price     = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double proximity = g_ATR_M15 * 0.6;
   obScore = 0; obHigh = 0; obLow = 0;

   for(int i=0; i<g_OBCount; i++)
   {
      if(!g_OBArray[i].valid || g_OBArray[i].mitigated) continue;

      if(dir == ORDER_TYPE_BUY && g_OBArray[i].isBull)
      {
         if(price <= g_OBArray[i].high + proximity && price >= g_OBArray[i].low - proximity)
         {
            if(g_OBArray[i].strengthScore > obScore)
            {
               obScore = g_OBArray[i].strengthScore;
               obHigh  = g_OBArray[i].high;
               obLow   = g_OBArray[i].low;
            }
         }
      }
      if(dir == ORDER_TYPE_SELL && !g_OBArray[i].isBull)
      {
         if(price <= g_OBArray[i].high + proximity && price >= g_OBArray[i].low - proximity)
         {
            if(g_OBArray[i].strengthScore > obScore)
            {
               obScore = g_OBArray[i].strengthScore;
               obHigh  = g_OBArray[i].high;
               obLow   = g_OBArray[i].low;
            }
         }
      }
   }
   return (obScore > 0);
}

//+------------------------------------------------------------------+
//| LAYER 7 - VOLUME CONFIRMATION                                   |
//+------------------------------------------------------------------+
double GetRelativeVolume(int barsBack)
{
   long vol[];
   ArraySetAsSeries(vol, true);
   if(CopyTickVolume(_Symbol, _Period, 0, barsBack + 20, vol) < barsBack + 10) return 1.0;

   long recent = vol[1];  // last completed bar
   double avgVol = 0;
   for(int i=2; i<barsBack+2; i++) avgVol += (double)vol[i];
   avgVol /= barsBack;

   if(avgVol <= 0) return 1.0;
   return (double)recent / avgVol;
}

//+------------------------------------------------------------------+
//| SIGNAL ENGINE - MASTER SCORE (0-100)                            |
//+------------------------------------------------------------------+
int ComputeSignalScore(ENUM_ORDER_TYPE &outDir)
{
   //--- Determine candidate direction from structure bias first
   ENUM_ORDER_TYPE dir = (g_StructureBias == BIAS_BEAR) ? ORDER_TYPE_SELL : ORDER_TYPE_BUY;
   if(g_StructureBias == BIAS_NEUTRAL)
      dir = (g_HTF_Bias == BIAS_BEAR) ? ORDER_TYPE_SELL : ORDER_TYPE_BUY;

   int sRegime       = ScoreRegimeLayer(dir);
   int sStructure    = ScoreStructureLayer(dir);
   int sLiquidity    = ScoreLiquidityLayer(dir);
   int sDisplacement = ScoreDisplacementLayer(dir);
   int sFVG          = ScoreFVGLayer(dir);
   int sOB           = ScoreOBLayer(dir);
   int sVolume       = ScoreVolumeLayer(dir);

   double weightSum = InpWtRegime + InpWtStructure + InpWtLiquidity + InpWtDisplacement +
                      InpWtFVG + InpWtOB + InpWtVolume;
   if(weightSum <= 0) weightSum = 100;

   double total = (sRegime*InpWtRegime + sStructure*InpWtStructure + sLiquidity*InpWtLiquidity +
                   sDisplacement*InpWtDisplacement + sFVG*InpWtFVG + sOB*InpWtOB +
                   sVolume*InpWtVolume) / weightSum;

   //--- Hard gate: no displacement = no trade (per spec)
   if(sDisplacement == 0) total = MathMin(total, 50.0);

   //--- Hard gate: structure must support direction
   if(sStructure == 0) total = total * 0.5;

   int finalScore = (int)MathMax(0, MathMin(100, total));
   outDir = dir;

   if(finalScore >= InpEliteScore)       g_LastQuality = QUALITY_ELITE;
   else if(finalScore >= InpStrongScore) g_LastQuality = QUALITY_STRONG;
   else if(finalScore >= InpMinScore)    g_LastQuality = QUALITY_STANDARD;
   else                                  g_LastQuality = QUALITY_NONE;

   return finalScore;
}

//+------------------------------------------------------------------+
//| Layer 1 Score - Market Regime                                   |
//+------------------------------------------------------------------+
int ScoreRegimeLayer(ENUM_ORDER_TYPE dir)
{
   if(g_Regime == REGIME_TRENDING_BULL && dir == ORDER_TYPE_BUY)  return 100;
   if(g_Regime == REGIME_TRENDING_BEAR && dir == ORDER_TYPE_SELL) return 100;
   if(g_Regime == REGIME_RANGING) return 55;          // ranging = lower conviction, still tradable on reversals
   if(g_Regime == REGIME_VOLATILE) return 20;          // volatile = risky, heavily penalized
   if(g_Regime == REGIME_LOW_LIQUIDITY) return 0;
   //--- Trending against direction
   return 10;
}

//+------------------------------------------------------------------+
//| Layer 2 Score - Market Structure (BOS/CHoCH/MSS)                |
//+------------------------------------------------------------------+
int ScoreStructureLayer(ENUM_ORDER_TYPE dir)
{
   bool aligned = (dir == ORDER_TYPE_BUY && g_StructureBias == BIAS_BULL) ||
                  (dir == ORDER_TYPE_SELL && g_StructureBias == BIAS_BEAR);
   if(!aligned) return 0;

   if(g_LastStructure == STRUCT_MSS)   return 100;  // Full reversal shift = highest conviction
   if(g_LastStructure == STRUCT_CHOCH) return 90;   // Character change = strong signal
   if(g_LastStructure == STRUCT_BOS)   return 75;   // Continuation = solid but lower
   return 0;
}

//+------------------------------------------------------------------+
//| Layer 3 Score - Liquidity (sweeps, pools)                       |
//+------------------------------------------------------------------+
int ScoreLiquidityLayer(ENUM_ORDER_TYPE dir)
{
   double sweepPrice = 0.0;
   bool swept = DetectLiquiditySweep(dir, sweepPrice);
   if(swept) return 100;   // Liquidity sweep immediately preceding = ideal SMC entry

   //--- Check if there's an unswept opposing pool nearby (inducement still loading)
   double price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   for(int i=0; i<g_LiqCount; i++)
   {
      if(!g_LiqArray[i].valid || g_LiqArray[i].swept) continue;
      double dist = MathAbs(price - g_LiqArray[i].price);
      if(dist < g_ATR_M15 * 1.5) return 45;  // liquidity nearby but not yet swept
   }
   return 25;  // no liquidity context found
}

//+------------------------------------------------------------------+
//| Layer 4 Score - Displacement                                    |
//+------------------------------------------------------------------+
int ScoreDisplacementLayer(ENUM_ORDER_TYPE dir)
{
   if(DetectDisplacement(dir)) return 100;
   return 0;   // No displacement = no edge, scored zero (hard gate applied upstream)
}

//+------------------------------------------------------------------+
//| Layer 5 Score - Fair Value Gap                                  |
//+------------------------------------------------------------------+
int ScoreFVGLayer(ENUM_ORDER_TYPE dir)
{
   double fvgHigh=0, fvgLow=0;
   if(IsNearFVG(dir, fvgHigh, fvgLow))
   {
      double size = fvgHigh - fvgLow;
      double sizeATR = (g_ATR_M15 > 0) ? size / g_ATR_M15 : 0;
      if(sizeATR > 1.0) return 95;
      if(sizeATR > 0.5) return 80;
      return 60;
   }
   return 30;  // No FVG confluence - not a hard requirement, just reduces score
}

//+------------------------------------------------------------------+
//| Layer 6 Score - Order Block                                     |
//+------------------------------------------------------------------+
int ScoreOBLayer(ENUM_ORDER_TYPE dir)
{
   double obHigh=0, obLow=0, obScore=0;
   if(IsNearOrderBlock(dir, obHigh, obLow, obScore))
      return (int)MathMin(100, obScore);
   return 25;
}

//+------------------------------------------------------------------+
//| Layer 7 Score - Volume Confirmation                              |
//+------------------------------------------------------------------+
int ScoreVolumeLayer(ENUM_ORDER_TYPE dir)
{
   double relVol = GetRelativeVolume(20);
   if(relVol >= 1.8) return 100;  // Strong volume expansion
   if(relVol >= 1.3) return 80;
   if(relVol >= 1.0) return 60;
   if(relVol >= 0.7) return 40;
   return 20;  // Below average volume = weak conviction
}

//+------------------------------------------------------------------+
//| DYNAMIC LOT SIZING - risk % -> lot size from SL distance        |
//+------------------------------------------------------------------+
double CalcLotSize(double riskPct, double slPoints)
{
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   double riskUSD = equity * (riskPct / 100.0) * g_AdaptRiskMult;

   double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double tickSize  = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   double point     = Pt();
   if(tickSize <= 0 || tickValue <= 0) { tickValue = 1.0; tickSize = point; }

   double pointValue = tickValue * (point / tickSize);  // USD value of 1 point per 1.0 lot
   if(pointValue <= 0 || slPoints <= 0) return SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);

   double rawLot = riskUSD / (slPoints * pointValue);

   double minV = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxV = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   if(step <= 0) step = 0.01;

   double lot = MathFloor(rawLot / step) * step;   // round DOWN - never risk more than intended
   lot = MathMax(minV, MathMin(maxV, lot));

   //--- Safety check: verify margin is available
   double marginReq = 0.0;
   if(OrderCalcMargin(ORDER_TYPE_BUY, _Symbol, lot, SymbolInfoDouble(_Symbol,SYMBOL_ASK), marginReq))
   {
      double freeMargin = AccountInfoDouble(ACCOUNT_MARGIN_FREE);
      if(marginReq > freeMargin * 0.8)
      {
         //--- Reduce lot to fit available margin safely
         double scale = (freeMargin * 0.8) / MathMax(marginReq, 0.0001);
         lot = MathFloor((lot * scale) / step) * step;
         lot = MathMax(minV, lot);
      }
   }

   return lot;
}

//+------------------------------------------------------------------+
//| STRUCTURE-BASED STOP LOSS                                       |
//+------------------------------------------------------------------+
double CalcStructureSL(ENUM_ORDER_TYPE dir, double entryPrice)
{
   double point  = Pt();
   double buffer = InpSLBufferPoints * point + g_ATR_M1 * InpSLATRMult;
   double sl = 0.0;

   if(dir == ORDER_TYPE_BUY)
   {
      //--- SL below: nearest order block low, swing low, or liquidity sweep low
      double candidates[5];
      int cc = 0;
      double obHigh=0, obLow=0, obScore=0;
      if(IsNearOrderBlock(ORDER_TYPE_BUY, obHigh, obLow, obScore)) candidates[cc++] = obLow;

      double swingLow = GetSwingLow(PERIOD_M15, InpTrailSwingBars);
      if(swingLow > 0) candidates[cc++] = swingLow;

      double fvgHigh=0, fvgLow=0;
      if(IsNearFVG(ORDER_TYPE_BUY, fvgHigh, fvgLow)) candidates[cc++] = fvgLow;

      //--- Pick the closest valid candidate below entry (tightest reasonable stop)
      double best = 0;
      for(int i=0; i<cc; i++)
      {
         if(candidates[i] > 0 && candidates[i] < entryPrice)
         {
            if(best == 0 || candidates[i] > best) best = candidates[i];
         }
      }
      if(best > 0) sl = best - buffer;
      else         sl = entryPrice - (g_ATR_M1 * 2.0);  // fallback: 2x ATR

      //--- Enforce max SL distance (risk guard)
      double maxDist = InpMaxSLPoints * point;
      if(entryPrice - sl > maxDist) sl = entryPrice - maxDist;
      //--- Enforce min SL (avoid stops too tight to survive spread)
      double minDist = (InpSLBufferPoints + 30) * point;
      if(entryPrice - sl < minDist) sl = entryPrice - minDist;
   }
   else // SELL
   {
      double candidates[5];
      int cc = 0;
      double obHigh=0, obLow=0, obScore=0;
      if(IsNearOrderBlock(ORDER_TYPE_SELL, obHigh, obLow, obScore)) candidates[cc++] = obHigh;

      double swingHigh = GetSwingHigh(PERIOD_M15, InpTrailSwingBars);
      if(swingHigh > 0) candidates[cc++] = swingHigh;

      double fvgHigh=0, fvgLow=0;
      if(IsNearFVG(ORDER_TYPE_SELL, fvgHigh, fvgLow)) candidates[cc++] = fvgHigh;

      double best = 0;
      for(int i=0; i<cc; i++)
      {
         if(candidates[i] > 0 && candidates[i] > entryPrice)
         {
            if(best == 0 || candidates[i] < best) best = candidates[i];
         }
      }
      if(best > 0) sl = best + buffer;
      else         sl = entryPrice + (g_ATR_M1 * 2.0);

      double maxDist = InpMaxSLPoints * point;
      if(sl - entryPrice > maxDist) sl = entryPrice + maxDist;
      double minDist = (InpSLBufferPoints + 30) * point;
      if(sl - entryPrice < minDist) sl = entryPrice + minDist;
   }

   return Normalize(sl);
}

//+------------------------------------------------------------------+
//| DYNAMIC TAKE PROFIT - liquidity / structure / ATR based         |
//+------------------------------------------------------------------+
double CalcDynamicTP(ENUM_ORDER_TYPE dir, double entryPrice, double slDist, int score)
{
   //--- Determine target RR based on setup quality
   double targetRR = InpMinRR;
   if(score >= InpEliteScore)       targetRR = InpEliteRR;
   else if(score >= InpStrongScore) targetRR = InpStrongRR;
   else                              targetRR = InpPreferredRR;

   double rrBasedTP = (dir == ORDER_TYPE_BUY) ? entryPrice + slDist * targetRR
                                               : entryPrice - slDist * targetRR;

   //--- Compare against structural/liquidity target; use whichever is more conservative
   //--- but never below minimum acceptable RR
   double structTarget = FindStructureTarget(dir, entryPrice);
   double liqTarget     = FindLiquidityTarget(dir, entryPrice);

   double minAcceptableTP = (dir == ORDER_TYPE_BUY) ? entryPrice + slDist * InpMinRR
                                                     : entryPrice - slDist * InpMinRR;

   double chosen = rrBasedTP;

   if(dir == ORDER_TYPE_BUY)
   {
      //--- Prefer liquidity target if it's between min-acceptable and rr-based*1.5 (realistic)
      if(liqTarget > minAcceptableTP && liqTarget < rrBasedTP * 1.3 && liqTarget > entryPrice)
         chosen = liqTarget;
      else if(structTarget > minAcceptableTP && structTarget > entryPrice)
         chosen = MathMax(structTarget, minAcceptableTP);
      else
         chosen = rrBasedTP;

      if(chosen < minAcceptableTP) chosen = minAcceptableTP;
   }
   else
   {
      if(liqTarget > 0 && liqTarget < minAcceptableTP && liqTarget > rrBasedTP * 0.7 && liqTarget < entryPrice)
         chosen = liqTarget;
      else if(structTarget > 0 && structTarget < minAcceptableTP && structTarget < entryPrice)
         chosen = MathMin(structTarget, minAcceptableTP);
      else
         chosen = rrBasedTP;

      if(chosen > minAcceptableTP) chosen = minAcceptableTP;
   }

   return Normalize(chosen);
}

double FindStructureTarget(ENUM_ORDER_TYPE dir, double entryPrice)
{
   if(dir == ORDER_TYPE_BUY)
   {
      double sh = GetSwingHigh(PERIOD_M15, InpStructureBars);
      return (sh > entryPrice) ? sh : 0;
   }
   else
   {
      double sl = GetSwingLow(PERIOD_M15, InpStructureBars);
      return (sl > 0 && sl < entryPrice) ? sl : 0;
   }
}

double FindLiquidityTarget(ENUM_ORDER_TYPE dir, double entryPrice)
{
   double best = 0;
   for(int i=0; i<g_LiqCount; i++)
   {
      if(!g_LiqArray[i].valid || g_LiqArray[i].swept) continue;

      if(dir == ORDER_TYPE_BUY && g_LiqArray[i].isBuySide && g_LiqArray[i].price > entryPrice)
      {
         if(best == 0 || g_LiqArray[i].price < best) best = g_LiqArray[i].price;
      }
      if(dir == ORDER_TYPE_SELL && !g_LiqArray[i].isBuySide && g_LiqArray[i].price < entryPrice)
      {
         if(best == 0 || g_LiqArray[i].price > best) best = g_LiqArray[i].price;
      }
   }
   return best;
}

//+------------------------------------------------------------------+
//| SWING HIGH / LOW UTILITIES                                      |
//+------------------------------------------------------------------+
double GetSwingHigh(ENUM_TIMEFRAMES tf, int lookback)
{
   int idx = iHighest(_Symbol, tf, MODE_HIGH, lookback, 1);
   if(idx < 0) return 0;
   return iHigh(_Symbol, tf, idx);
}

double GetSwingLow(ENUM_TIMEFRAMES tf, int lookback)
{
   int idx = iLowest(_Symbol, tf, MODE_LOW, lookback, 1);
   if(idx < 0) return 0;
   return iLow(_Symbol, tf, idx);
}

//+------------------------------------------------------------------+
//| OPEN BULK SIGNAL TRADE - 3 positions on confirmed signal         |
//| Risk per leg = InpBulkRiskSplit of normal risk, so total risk    |
//| across all 3 legs equals exactly ONE normal Stage-1 trade.       |
//| Each leg gets a different TP tier (TP1/TP2/TP3) so the group     |
//| behaves like a single position with a built-in partial ladder    |
//| instead of 3 identical, uncorrelated bets.                       |
//+------------------------------------------------------------------+
void OpenBulkSignalTrade(ENUM_ORDER_TYPE dir, int score)
{
   double entryPrice = (dir == ORDER_TYPE_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                                : SymbolInfoDouble(_Symbol, SYMBOL_BID);

   double sl = CalcStructureSL(dir, entryPrice);
   double slDist = MathAbs(entryPrice - sl);
   if(slDist <= 0) { Print("[XIE] Invalid SL distance, aborting bulk entry."); return; }

   //--- Determine total risk % based on setup quality (same tiering as before)
   double totalRiskPct = InpRiskPctDefault;
   if(score >= InpEliteScore)       totalRiskPct = InpRiskPctElite;
   else if(score >= InpStrongScore) totalRiskPct = InpRiskPctMax;

   //--- Split risk evenly across 3 legs - sum of all 3 legs = totalRiskPct
   //--- i.e. total account risk for the bulk group equals ONE normal trade
   double legRiskPct = totalRiskPct / 3.0;
   double slPoints   = slDist / Pt();
   double legLot     = CalcLotSize(legRiskPct, slPoints);

   if(legLot <= 0)
   {
      Print("[XIE] Bulk lot size calculation returned 0. Skipping entry.");
      return;
   }

   //--- Three TP tiers, mirroring the TP1/TP2/TP3 structure used for partials
   double tpArr[3];
   tpArr[0] = (dir==ORDER_TYPE_BUY) ? entryPrice + slDist*InpMinRR      : entryPrice - slDist*InpMinRR;
   tpArr[1] = (dir==ORDER_TYPE_BUY) ? entryPrice + slDist*InpPreferredRR: entryPrice - slDist*InpPreferredRR;
   tpArr[2] = CalcDynamicTP(dir, entryPrice, slDist, score);  // full structural/liquidity target

   int opened = 0;
   for(int leg=0; leg<3; leg++)
   {
      double legEntryPrice = (dir == ORDER_TYPE_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                                       : SymbolInfoDouble(_Symbol, SYMBOL_BID);
      string comment = InpComment + " BULK" + IntegerToString(leg+1) + " Q:" + IntegerToString(score);
      bool ok = (dir == ORDER_TYPE_BUY) ? g_Trade.Buy(legLot, _Symbol, legEntryPrice, sl, tpArr[leg], comment)
                                          : g_Trade.Sell(legLot, _Symbol, legEntryPrice, sl, tpArr[leg], comment);
      if(ok)
      {
         ulong ticket = g_Trade.ResultOrder();
         opened++;
         Print("[XIE] BULK LEG ", leg+1, "/3 opened. Dir=", EnumToString(dir), " Lot=", legLot,
               " SL=", sl, " TP=", tpArr[leg], " Score=", score);

         for(int i=0; i<10; i++)
         {
            if(g_Positions[i].ticket == 0)
            {
               g_Positions[i].ticket      = ticket;
               g_Positions[i].stage       = STAGE_ONE;
               g_Positions[i].entryPrice  = legEntryPrice;
               g_Positions[i].sl          = sl;
               g_Positions[i].tp1         = tpArr[0];
               g_Positions[i].tp2         = tpArr[1];
               g_Positions[i].tp3         = tpArr[2];
               //--- Each leg's own TP is its only target - mark earlier tiers
               //--- as already "hit" so ManagePositions doesn't try to partial-close
               //--- a position that is itself sized as a single tier.
               g_Positions[i].tp1Hit      = (leg >= 1);
               g_Positions[i].tp2Hit      = (leg >= 2);
               g_Positions[i].beSet       = false;
               g_Positions[i].trailMode   = TRAIL_STRUCTURE;
               g_Positions[i].trailLevel  = sl;
               g_Positions[i].lotSize     = legLot;
               g_Positions[i].direction   = dir;
               g_PosCount = MathMax(g_PosCount, i+1);
               break;
            }
         }
      }
      else
      {
         Print("[XIE] Bulk leg ", leg+1, " failed. Retcode=", g_Trade.ResultRetcode(),
               " ", g_Trade.ResultRetcodeDescription());
      }
   }

   if(opened > 0)
   {
      g_LastDir = dir;
      Print("[XIE] Bulk signal trade complete: ", opened, "/3 legs opened. Combined risk = ",
            DoubleToString(totalRiskPct,2), "% (same as 1 normal trade).");
   }
}

//+------------------------------------------------------------------+
//| SCALE-IN - Institutional model: add ONLY after profit + confirm |
//| Never adds to a loser. Never martingales. Never grids.           |
//+------------------------------------------------------------------+
void CheckScaleIn()
{
   for(int i=0; i<10; i++)
   {
      if(g_Positions[i].ticket == 0) continue;
      if(!PositionExists(g_Positions[i].ticket)) continue;
      if(g_Positions[i].stage >= STAGE_THREE) continue;  // already maxed

      //--- Count how many stages already exist for this "trade family"
      int stageCount = 0;
      for(int j=0; j<10; j++)
         if(g_Positions[j].ticket != 0 && PositionExists(g_Positions[j].ticket)) stageCount++;
      if(stageCount > InpMaxStagePositions) continue;

      if(!g_Pos.SelectByTicket(g_Positions[i].ticket)) continue;
      double currentProfit = g_Pos.Profit() + g_Pos.Swap() + g_Pos.Commission();
      double openPrice     = g_Pos.PriceOpen();
      ENUM_ORDER_TYPE dir  = g_Positions[i].direction;
      double price = (dir==ORDER_TYPE_BUY) ? SymbolInfoDouble(_Symbol,SYMBOL_BID) : SymbolInfoDouble(_Symbol,SYMBOL_ASK);
      double moveInFavor = (dir==ORDER_TYPE_BUY) ? (price - openPrice) : (openPrice - price);

      //--- HARD RULE: position must be in profit by at least InpScaleInProfit x ATR
      double requiredMove = g_ATR_M1 * InpScaleInProfit;
      if(moveInFavor < requiredMove) continue;     // not profitable enough yet
      if(currentProfit <= 0) continue;              // double safety - never add to a loser

      //--- Require fresh confirmation: a new displacement candle in the same direction
      if(!DetectDisplacement(dir)) continue;

      //--- Require structure still aligned (no CHoCH against us)
      bool stillAligned = (dir==ORDER_TYPE_BUY && g_StructureBias != BIAS_BEAR) ||
                          (dir==ORDER_TYPE_SELL && g_StructureBias != BIAS_BULL);
      if(!stillAligned) continue;

      //--- All conditions met - add Stage 2/3 position with SAME or reduced risk (never increased)
      ENUM_TRADE_STAGE nextStage = (g_Positions[i].stage == STAGE_ONE) ? STAGE_TWO : STAGE_THREE;

      double entryPrice = (dir==ORDER_TYPE_BUY) ? SymbolInfoDouble(_Symbol,SYMBOL_ASK) : SymbolInfoDouble(_Symbol,SYMBOL_BID);
      double sl = CalcStructureSL(dir, entryPrice);
      double slDist = MathAbs(entryPrice - sl);
      if(slDist <= 0) continue;

      //--- Scale-in risk is HALF of the original entry's risk (de-risking the add)
      double riskPct = InpRiskPctDefault * 0.5;
      double slPoints = slDist / Pt();
      double lot = CalcLotSize(riskPct, slPoints);
      if(lot <= 0) continue;

      double tp = CalcDynamicTP(dir, entryPrice, slDist, g_LastScore);
      string comment = InpComment + " S" + IntegerToString((int)nextStage) + " ADD";

      bool ok = (dir==ORDER_TYPE_BUY) ? g_Trade.Buy(lot,_Symbol,entryPrice,sl,tp,comment)
                                       : g_Trade.Sell(lot,_Symbol,entryPrice,sl,tp,comment);
      if(ok)
      {
         ulong newTicket = g_Trade.ResultOrder();
         Print("[XIE] SCALE-IN ", EnumToString(nextStage), " added. Lot=", lot, " (profit-confirmed, never martingale)");
         for(int k=0; k<10; k++)
         {
            if(g_Positions[k].ticket == 0)
            {
               g_Positions[k].ticket     = newTicket;
               g_Positions[k].stage      = nextStage;
               g_Positions[k].entryPrice = entryPrice;
               g_Positions[k].sl         = sl;
               g_Positions[k].tp1        = (dir==ORDER_TYPE_BUY) ? entryPrice+slDist*InpMinRR : entryPrice-slDist*InpMinRR;
               g_Positions[k].tp2        = (dir==ORDER_TYPE_BUY) ? entryPrice+slDist*InpPreferredRR : entryPrice-slDist*InpPreferredRR;
               g_Positions[k].tp3        = tp;
               g_Positions[k].lotSize    = lot;
               g_Positions[k].direction  = dir;
               g_Positions[k].trailMode  = TRAIL_STRUCTURE;
               g_Positions[k].trailLevel = sl;
               g_PosCount = MathMax(g_PosCount, k+1);
               break;
            }
         }
      }
      break; // one scale-in action per tick
   }
}

//+------------------------------------------------------------------+
//| SYNC POSITION ARRAY - remove closed tickets, record outcomes    |
//+------------------------------------------------------------------+
void SyncPositionArray()
{
   for(int i=0; i<10; i++)
   {
      if(g_Positions[i].ticket == 0) continue;
      if(!PositionExists(g_Positions[i].ticket))
      {
         //--- Position closed - pull final PnL from history
         if(HistorySelectByPosition(g_Positions[i].ticket))
         {
            double pnl = 0;
            int deals = HistoryDealsTotal();
            for(int d=0; d<deals; d++)
            {
               ulong dealTicket = HistoryDealGetTicket(d);
               if(dealTicket > 0)
                  pnl += HistoryDealGetDouble(dealTicket, DEAL_PROFIT) +
                         HistoryDealGetDouble(dealTicket, DEAL_SWAP) +
                         HistoryDealGetDouble(dealTicket, DEAL_COMMISSION);
            }
            RecordTrade(pnl, pnl >= 0, g_LastScore);
         }
         g_Positions[i].ticket = 0;
      }
   }
}

bool PositionExists(ulong ticket)
{
   if(ticket == 0) return false;
   return g_Pos.SelectByTicket(ticket);
}

//+------------------------------------------------------------------+
//| MANAGE POSITIONS - partials, BE, trailing                       |
//+------------------------------------------------------------------+
void ManagePositions()
{
   for(int i=0; i<10; i++)
   {
      if(g_Positions[i].ticket == 0) continue;
      if(!PositionExists(g_Positions[i].ticket)) continue;

      HandlePartialClose(g_Positions[i]);
      UpdateTrailingStop(g_Positions[i]);
   }
}

//+------------------------------------------------------------------+
//| PARTIAL CLOSE SYSTEM - TP1 30%, TP2 30%, TP3 40% (trail)       |
//+------------------------------------------------------------------+
void HandlePartialClose(ScalePosition &pos)
{
   if(!g_Pos.SelectByTicket(pos.ticket)) return;
   double price = (pos.direction==ORDER_TYPE_BUY) ? SymbolInfoDouble(_Symbol,SYMBOL_BID)
                                                    : SymbolInfoDouble(_Symbol,SYMBOL_ASK);
   double currentVolume = g_Pos.Volume();
   double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double step   = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);

   //--- TP1 hit: close 30%, move SL to breakeven
   if(!pos.tp1Hit)
   {
      bool hit = (pos.direction==ORDER_TYPE_BUY) ? (price >= pos.tp1) : (price <= pos.tp1);
      if(hit)
      {
         double closeVol = MathFloor((pos.lotSize * (InpTP1Pct/100.0)) / step) * step;
         closeVol = MathMax(closeVol, minLot);
         if(closeVol < currentVolume)
         {
            if(g_Trade.PositionClosePartial(pos.ticket, closeVol))
            {
               pos.tp1Hit = true;
               Print("[XIE] TP1 hit. Closed ", closeVol, " lots. Moving SL to breakeven.");
               //--- Move SL to breakeven
               double newSL = pos.entryPrice;
               g_Trade.PositionModify(pos.ticket, Normalize(newSL), pos.tp3);
               pos.sl = newSL;
               pos.beSet = true;
            }
         }
         else
         {
            //--- Remaining volume too small to split further - just move to BE
            pos.tp1Hit = true;
            double newSL = pos.entryPrice;
            g_Trade.PositionModify(pos.ticket, Normalize(newSL), pos.tp3);
            pos.sl = newSL;
            pos.beSet = true;
         }
      }
      return;
   }

   //--- TP2 hit: close another 30%, start trailing the rest
   if(pos.tp1Hit && !pos.tp2Hit)
   {
      bool hit = (pos.direction==ORDER_TYPE_BUY) ? (price >= pos.tp2) : (price <= pos.tp2);
      if(hit)
      {
         double remaining = g_Pos.Volume();
         double closeVol = MathFloor((pos.lotSize * (InpTP2Pct/100.0)) / step) * step;
         closeVol = MathMax(closeVol, minLot);
         if(closeVol < remaining)
         {
            if(g_Trade.PositionClosePartial(pos.ticket, closeVol))
            {
               pos.tp2Hit = true;
               Print("[XIE] TP2 hit. Closed ", closeVol, " lots. Activating trail for remainder.");
            }
         }
         else
         {
            pos.tp2Hit = true; // let it ride and trail with whatever's left
         }
      }
   }
}

//+------------------------------------------------------------------+
//| SMART TRAILING ENGINE - auto-selects ATR / structure / swing    |
//+------------------------------------------------------------------+
void UpdateTrailingStop(ScalePosition &pos)
{
   //--- Only trail aggressively after TP2 (riding the final 40%)
   if(!pos.tp2Hit) return;
   if(!g_Pos.SelectByTicket(pos.ticket)) return;

   double price = (pos.direction==ORDER_TYPE_BUY) ? SymbolInfoDouble(_Symbol,SYMBOL_BID)
                                                     : SymbolInfoDouble(_Symbol,SYMBOL_ASK);
   double currentSL = g_Pos.StopLoss();
   double newSL = currentSL;

   //--- Choose trail mode based on regime: trending = structure trail, volatile = ATR trail
   ENUM_TRAIL_MODE mode = (g_Regime == REGIME_VOLATILE) ? TRAIL_ATR : TRAIL_STRUCTURE;
   pos.trailMode = mode;

   if(mode == TRAIL_ATR)
   {
      double trailDist = g_ATR_M1 * InpTrailATRMult;
      if(pos.direction == ORDER_TYPE_BUY)
      {
         double candidate = price - trailDist;
         if(candidate > currentSL) newSL = candidate;
      }
      else
      {
         double candidate = price + trailDist;
         if(candidate < currentSL || currentSL == 0) newSL = candidate;
      }
   }
   else // TRAIL_STRUCTURE - trail behind recent swing points
   {
      if(pos.direction == ORDER_TYPE_BUY)
      {
         double swingLow = GetSwingLow(_Period, InpTrailSwingBars);
         double buffer = g_ATR_M1 * 0.3;
         double candidate = swingLow - buffer;
         if(swingLow > 0 && candidate > currentSL) newSL = candidate;
      }
      else
      {
         double swingHigh = GetSwingHigh(_Period, InpTrailSwingBars);
         double buffer = g_ATR_M1 * 0.3;
         double candidate = swingHigh + buffer;
         if(swingHigh > 0 && (candidate < currentSL || currentSL == 0)) newSL = candidate;
      }
   }

   //--- Only modify if the new SL is meaningfully better (avoid spamming broker)
   double minImprovement = Pt() * 20;
   bool improved = (pos.direction==ORDER_TYPE_BUY) ? (newSL > currentSL + minImprovement)
                                                     : (newSL < currentSL - minImprovement || currentSL==0);
   if(improved)
   {
      g_Trade.PositionModify(pos.ticket, Normalize(newSL), g_Pos.TakeProfit());
      pos.sl = newSL;
      pos.trailLevel = newSL;
   }
}

//+------------------------------------------------------------------+
//| RECORD TRADE OUTCOME - feeds adaptation engine                  |
//+------------------------------------------------------------------+
void RecordTrade(double pnl, bool win, int score)
{
   //--- Shift history array
   for(int i=MathMin(g_HistoryCount,99); i>0; i--) g_History[i] = g_History[i-1];
   g_History[0].pnl       = pnl;
   g_History[0].win       = win;
   g_History[0].closeTime = TimeCurrent();
   g_History[0].score     = score;
   g_History[0].session   = g_Session;
   if(g_HistoryCount < 100) g_HistoryCount++;

   if(win) { g_ConsecWins++; g_ConsecLosses = 0; }
   else    { g_ConsecLosses++; g_ConsecWins = 0; }

   g_TotalTrades++;
   if(win) g_TotalWins++;
   g_TotalProfit += pnl;
   g_DailyPnL    += pnl;
   g_WeeklyPnL   += pnl;

   //--- Profit factor
   double grossWin = 0, grossLoss = 0;
   for(int i=0; i<g_HistoryCount; i++)
   {
      if(g_History[i].pnl >= 0) grossWin  += g_History[i].pnl;
      else                       grossLoss += MathAbs(g_History[i].pnl);
   }
   g_ProfitFactor = (grossLoss > 0) ? grossWin/grossLoss : grossWin;

   Print("[XIE] Trade closed. PnL=", DoubleToString(pnl,2), " Win=", win,
         " ConsecLosses=", g_ConsecLosses, " PF=", DoubleToString(g_ProfitFactor,2));
}

//+------------------------------------------------------------------+
//| RISK GATE - daily/weekly DD, consecutive loss halt              |
//+------------------------------------------------------------------+
bool CheckRisk()
{
   double dailyDD  = GetDailyDD();
   double weeklyDD = GetWeeklyDD();

   if(dailyDD >= InpDailyDDLimit)
   {
      g_DailyHalt   = true;
      g_StatusText  = "DAILY DD LIMIT HIT (-" + DoubleToString(dailyDD,2) + "%) - HALTED";
      g_StatusColor = clrRed;
      return false;
   }

   if(weeklyDD >= InpWeeklyDDLimit)
   {
      g_WeeklyHalt  = true;
      g_StatusText  = "WEEKLY DD LIMIT HIT (-" + DoubleToString(weeklyDD,2) + "%) - HALTED";
      g_StatusColor = clrRed;
      return false;
   }

   if(g_ConsecLosses >= InpConsecLossHalt)
   {
      g_TradingHalt = true;
      g_StatusText  = "5 CONSECUTIVE LOSSES - REASSESSMENT MODE";
      g_StatusColor = clrRed;
      return false;
   }

   g_TradingHalt = false;
   return true;
}

double GetDailyDD()
{
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   if(g_DayStartEquity <= 0) return 0;
   double dd = (g_DayStartEquity - equity) / g_DayStartEquity * 100.0;
   return MathMax(0, dd);
}

double GetWeeklyDD()
{
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   if(g_WeekStartEquity <= 0) return 0;
   double dd = (g_WeekStartEquity - equity) / g_WeekStartEquity * 100.0;
   return MathMax(0, dd);
}

void UpdateRiskState()
{
   //--- Consecutive loss risk reduction (per spec: 3 losses = halve risk)
   if(g_ConsecLosses >= InpConsecLossReduce && g_ConsecLosses < InpConsecLossHalt)
   {
      g_CurrentRiskPct = InpRiskPctDefault * 0.5;
   }
   else if(g_ConsecLosses == 0 && g_ConsecWins >= 2)
   {
      g_CurrentRiskPct = InpRiskPctDefault;  // restore to normal after wins
   }
}

//+------------------------------------------------------------------+
//| SESSION FILTER - Gold kill-zones                                |
//+------------------------------------------------------------------+
ENUM_SESSION DetectSession()
{
   MqlDateTime t;
   TimeToStruct(TimeGMT(), t);
   int h = t.hour;

   bool inLondon = (h >= InpLondonOpen && h < InpLondonClose);
   bool inNY     = (h >= InpNYOpen     && h < InpNYClose);
   bool inAsian  = (h >= InpAsianOpen  && h < InpAsianClose);

   if(inLondon && inNY) { g_SessionLabel = "LONDON-NY OVERLAP"; return SESSION_OVERLAP;  }
   if(inLondon)         { g_SessionLabel = "LONDON";            return SESSION_LONDON;   }
   if(inNY)              { g_SessionLabel = "NEW YORK";          return SESSION_NEW_YORK; }
   if(inAsian)           { g_SessionLabel = "ASIAN";             return SESSION_ASIAN;    }
   g_SessionLabel = "DEAD ZONE";
   return SESSION_DEAD;
}

bool CheckSession()
{
   switch(g_Session)
   {
      case SESSION_ASIAN:    return InpTradeAsian;
      case SESSION_LONDON:   return InpTradeLondon;
      case SESSION_NEW_YORK: return InpTradeNY;
      case SESSION_OVERLAP:  return InpTradeOverlap;
      default: return false;
   }
}

bool CheckSpread()
{
   int spread = (int)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   if(spread > InpMaxSpreadPoints)
   {
      g_StatusText  = "SPREAD TOO WIDE (" + IntegerToString(spread) + "pts)";
      g_StatusColor = clrOrange;
      return false;
   }
   return true;
}

//+------------------------------------------------------------------+
//| NEWS FILTER                                                     |
//| NOTE: This EA does not have a live news feed connection.        |
//| InpUseNewsFilter relies on the MT5 built-in Calendar if         |
//| available on this broker/server; if the Calendar is empty       |
//| (common on some brokers), this filter will silently allow all   |
//| times through. For full safety, manually avoid running through  |
//| NFP/CPI/FOMC by checking an economic calendar and pausing the   |
//| EA, or use MQL5's Calendar API by enabling MQL5 Calendar in      |
//| terminal settings.                                               |
//+------------------------------------------------------------------+
bool CheckNews()
{
   if(!InpUseNewsFilter) return true;

   MqlCalendarValue values[];
   datetime from = TimeCurrent() - InpNewsPreMinutes*60;
   datetime to   = TimeCurrent() + InpNewsPostMinutes*60;

   //--- Query USD high-impact events (affects Gold directly)
   int count = CalendarValueHistory(values, from, to, "US");
   if(count > 0)
   {
      for(int i=0; i<count; i++)
      {
         MqlCalendarEvent event;
         if(CalendarEventById(values[i].event_id, event))
         {
            if(event.importance == CALENDAR_IMPORTANCE_HIGH)
            {
               g_NewsActive  = true;
               g_StatusText  = "NEWS WINDOW ACTIVE - PAUSED";
               g_StatusColor = clrOrange;
               return false;
            }
         }
      }
   }
   g_NewsActive = false;
   return true;
}

//+------------------------------------------------------------------+
//| PERFORMANCE ADAPTATION ENGINE                                   |
//+------------------------------------------------------------------+
void AdaptRisk()
{
   if(g_HistoryCount < InpAdaptLookback) return;

   int wins = 0;
   int n = MathMin(g_HistoryCount, InpAdaptLookback);
   for(int i=0; i<n; i++) if(g_History[i].win) wins++;
   double wr = (double)wins / n;

   if(wr < InpAdaptMinWR)
   {
      g_AdaptRiskMult = 0.5;   // underperforming - cut size in half
      g_AdaptReduced  = true;
   }
   else if(wr >= InpAdaptGoodWR)
   {
      g_AdaptRiskMult = 1.0;   // performing well - full size
      g_AdaptReduced  = false;
   }
   else
   {
      g_AdaptRiskMult = 0.75;  // middling - moderate caution
      g_AdaptReduced  = false;
   }
}

//+------------------------------------------------------------------+
//| DATE UTILITIES                                                  |
//+------------------------------------------------------------------+
datetime GetDayStart(datetime t)
{
   MqlDateTime d;
   TimeToStruct(t, d);
   d.hour = 0; d.min = 0; d.sec = 0;
   return StructToTime(d);
}

datetime GetWeekStart(datetime t)
{
   MqlDateTime d;
   TimeToStruct(t, d);
   int dow = d.day_of_week;          // 0=Sunday
   datetime dayStart = GetDayStart(t);
   return dayStart - (datetime)(dow * 86400);
}

//+------------------------------------------------------------------+
//| DASHBOARD - Institutional layout                                |
//+------------------------------------------------------------------+
void RenderDashboard()
{
   int aX = InpDashX, aY = InpDashY, w = 430, h = 600;
   color bg     = C'8,10,16';
   color panel  = C'14,18,26';
   color border = C'40,70,110';
   color gold   = C'255,200,60';
   color txt    = C'225,230,240';
   color muted  = C'120,130,150';

   DRect("Bg", aX, aY, w, h, bg, border, 2);
   DRect("Hdr", aX+2, aY+2, w-4, 56, C'18,24,38', gold, 1);
   DLabel("T1", aX+14, aY+8,  "XAUUSD INSTITUTIONAL ENGINE", gold, 13, "Arial Black");
   DLabel("T2", aX+14, aY+30, EA_VERSION + "  |  Structure + Liquidity + Risk", muted, 8, "Arial");

   int p1Y = aY+64;
   DRect("P1", aX+2, p1Y, w-4, 110, panel, border, 1);
   DLabel("P1H", aX+12, p1Y+6, "ACCOUNT & RISK", txt, 9, "Arial Black");
   DLabel("L_Eq", aX+12, p1Y+26, "Equity:", muted, 8);          DLabel("V_Eq", aX+140, p1Y+26, "$0.00", txt, 8, "Arial Bold");
   DLabel("L_DD", aX+12, p1Y+44, "Daily DD:", muted, 8);        DLabel("V_DD", aX+140, p1Y+44, "0.0%", txt, 8, "Arial Bold");
   DLabel("L_WD", aX+12, p1Y+62, "Weekly DD:", muted, 8);       DLabel("V_WD", aX+140, p1Y+62, "0.0%", txt, 8, "Arial Bold");
   DLabel("L_Rk", aX+12, p1Y+80, "Risk/Trade:", muted, 8);      DLabel("V_Rk", aX+140, p1Y+80, "0.0%", txt, 8, "Arial Bold");
   DLabel("L_PF", aX+230, p1Y+26, "Profit Factor:", muted, 8);  DLabel("V_PF", aX+340, p1Y+26, "0.00", txt, 8, "Arial Bold");
   DLabel("L_WR", aX+230, p1Y+44, "Win Rate:", muted, 8);       DLabel("V_WR", aX+340, p1Y+44, "0.0%", txt, 8, "Arial Bold");
   DLabel("L_CL", aX+230, p1Y+62, "Consec Loss:", muted, 8);    DLabel("V_CL", aX+340, p1Y+62, "0", txt, 8, "Arial Bold");
   DLabel("L_Ad", aX+230, p1Y+80, "Adapt Mult:", muted, 8);     DLabel("V_Ad", aX+340, p1Y+80, "1.0x", txt, 8, "Arial Bold");

   int p2Y = p1Y+118;
   DRect("P2", aX+2, p2Y, w-4, 150, panel, gold, 1);
   DLabel("P2H", aX+12, p2Y+6, "SIGNAL ENGINE - 7 LAYER SCORE", gold, 9, "Arial Black");
   DLabel("L_Sc", aX+12, p2Y+26, "Score:", muted, 8);     DLabel("V_Sc", aX+140, p2Y+26, "0/100", C'255,185,25', 11, "Arial Black");
   DLabel("L_Ql", aX+12, p2Y+46, "Quality:", muted, 8);   DLabel("V_Ql", aX+140, p2Y+46, "NONE", muted, 9, "Arial Bold");
   DLabel("L_Dr", aX+12, p2Y+64, "Direction:", muted, 8); DLabel("V_Dr", aX+140, p2Y+64, "-", txt, 9, "Arial Bold");
   DLabel("V_L1", aX+12,  p2Y+86, "REG:--", muted, 8, "Consolas");
   DLabel("V_L2", aX+90,  p2Y+86, "STR:--", muted, 8, "Consolas");
   DLabel("V_L3", aX+168, p2Y+86, "LIQ:--", muted, 8, "Consolas");
   DLabel("V_L4", aX+246, p2Y+86, "DIS:--", muted, 8, "Consolas");
   DLabel("V_L5", aX+324, p2Y+86, "FVG:--", muted, 8, "Consolas");
   DLabel("V_L6", aX+12,  p2Y+106,"OB:--",  muted, 8, "Consolas");
   DLabel("V_L7", aX+90,  p2Y+106,"VOL:--", muted, 8, "Consolas");
   DLabel("L_Hb", aX+12, p2Y+126, "HTF Bias:", muted, 8); DLabel("V_Hb", aX+90, p2Y+126, "NEUTRAL", muted, 8, "Arial Bold");
   DLabel("L_St", aX+220, p2Y+126,"Structure:", muted, 8);DLabel("V_St", aX+300, p2Y+126,"NONE", muted, 8, "Arial Bold");

   int p3Y = p2Y+158;
   DRect("P3", aX+2, p3Y, w-4, 110, panel, border, 1);
   DLabel("P3H", aX+12, p3Y+6, "POSITION MANAGEMENT", txt, 9, "Arial Black");
   DLabel("L_Pc", aX+12, p3Y+26, "Open Positions:", muted, 8); DLabel("V_Pc", aX+150, p3Y+26, "0", txt, 8, "Arial Bold");
   DLabel("L_Fp", aX+12, p3Y+44, "Floating P/L:", muted, 8);   DLabel("V_Fp", aX+150, p3Y+44, "$0.00", txt, 8, "Arial Bold");
   DLabel("L_Dp", aX+12, p3Y+62, "Daily P/L:", muted, 8);      DLabel("V_Dp", aX+150, p3Y+62, "$0.00", txt, 8, "Arial Bold");
   DLabel("L_Tt", aX+12, p3Y+80, "Total Trades:", muted, 8);   DLabel("V_Tt", aX+150, p3Y+80, "0", txt, 8, "Arial Bold");

   int p4Y = p3Y+118;
   DRect("P4", aX+2, p4Y, w-4, 80, panel, C'255,120,0', 1);
   DLabel("P4H", aX+12, p4Y+6, "SESSION + STATUS", C'255,120,0', 9, "Arial Black");
   DLabel("L_Se", aX+12, p4Y+26, "Session:", muted, 8);  DLabel("V_Se", aX+90, p4Y+26, "DETECTING", muted, 8, "Arial Bold");
   DLabel("L_Sp", aX+220, p4Y+26, "Spread:", muted, 8);  DLabel("V_Sp", aX+290, p4Y+26, "0 pts", txt, 8, "Arial Bold");
   DLabel("V_Stat", aX+12, p4Y+48, "BOOTING...", C'0,200,255', 9, "Arial Bold");

   DLabel("F1", aX+10, aY+h-16, "Survival > Consistency > Scalability > Profitability", muted, 7, "Arial Italic");
   ChartRedraw(0);
}

void RefreshDashboard()
{
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   DUpdate("V_Eq", "$ " + DoubleToString(equity,2));
   DUpdate("V_DD", DoubleToString(GetDailyDD(),2) + "%", GetDailyDD() > InpDailyDDLimit*0.7 ? clrRed : C'225,230,240');
   DUpdate("V_WD", DoubleToString(GetWeeklyDD(),2) + "%", GetWeeklyDD() > InpWeeklyDDLimit*0.7 ? clrRed : C'225,230,240');
   DUpdate("V_Rk", DoubleToString(InpRiskPctDefault * g_AdaptRiskMult,2) + "%");
   DUpdate("V_PF", DoubleToString(g_ProfitFactor,2), g_ProfitFactor >= 1.8 ? C'0,225,120' : (g_ProfitFactor>=1.0?C'255,185,25':C'235,45,65'));
   double wr = (g_TotalTrades>0) ? (double)g_TotalWins/g_TotalTrades*100.0 : 0.0;
   DUpdate("V_WR", DoubleToString(wr,1) + "%");
   DUpdate("V_CL", IntegerToString(g_ConsecLosses), g_ConsecLosses>=InpConsecLossReduce?C'255,120,0':C'225,230,240');
   DUpdate("V_Ad", DoubleToString(g_AdaptRiskMult,2) + "x", g_AdaptReduced?C'235,45,65':C'0,225,120');

   color scC = (g_LastScore>=InpEliteScore)?C'255,215,80':(g_LastScore>=InpStrongScore)?C'0,225,120':(g_LastScore>=InpMinScore)?C'255,185,25':C'120,130,150';
   DUpdate("V_Sc", IntegerToString(g_LastScore) + "/100", scC);
   string qLabel = (g_LastQuality==QUALITY_ELITE)?"ELITE":(g_LastQuality==QUALITY_STRONG)?"STRONG":(g_LastQuality==QUALITY_STANDARD)?"STANDARD":"NONE";
   DUpdate("V_Ql", qLabel, scC);
   DUpdate("V_Dr", (g_LastDir==ORDER_TYPE_BUY)?"BUY":"SELL", (g_LastDir==ORDER_TYPE_BUY)?C'0,225,120':C'235,45,65');

   DUpdate("V_Hb", (g_HTF_Bias==BIAS_BULL)?"BULLISH":(g_HTF_Bias==BIAS_BEAR)?"BEARISH":"NEUTRAL",
           (g_HTF_Bias==BIAS_BULL)?C'0,225,120':(g_HTF_Bias==BIAS_BEAR)?C'235,45,65':C'120,130,150');
   string stLabel = (g_LastStructure==STRUCT_MSS)?"MSS":(g_LastStructure==STRUCT_CHOCH)?"CHoCH":(g_LastStructure==STRUCT_BOS)?"BOS":"NONE";
   DUpdate("V_St", stLabel, g_LastStructure!=STRUCT_NONE?C'255,215,80':C'120,130,150');

   int openCount = 0; double floatPnL = 0;
   for(int i=0; i<10; i++)
   {
      if(g_Positions[i].ticket==0) continue;
      if(g_Pos.SelectByTicket(g_Positions[i].ticket))
      {
         openCount++;
         floatPnL += g_Pos.Profit() + g_Pos.Swap() + g_Pos.Commission();
      }
   }
   DUpdate("V_Pc", IntegerToString(openCount));
   DUpdate("V_Fp", "$ " + DoubleToString(floatPnL,2), floatPnL>=0?C'0,225,120':C'235,45,65');
   DUpdate("V_Dp", "$ " + DoubleToString(g_DailyPnL,2), g_DailyPnL>=0?C'0,225,120':C'235,45,65');
   DUpdate("V_Tt", IntegerToString(g_TotalTrades));

   DUpdate("V_Se", g_SessionLabel);
   DUpdate("V_Sp", IntegerToString((int)SymbolInfoInteger(_Symbol,SYMBOL_SPREAD)) + " pts");
   DUpdate("V_Stat", g_StatusText, g_StatusColor);

   ChartRedraw(0);
}

void PurgeDashboard() { ObjectsDeleteAll(0, PREFIX); ChartRedraw(0); }

void DRect(string id, int x, int y, int w, int h, color bg, color brd, int bw=1)
{
   string nm = PREFIX+id;
   ObjectCreate(0, nm, OBJ_RECTANGLE_LABEL, 0, 0, 0);
   ObjectSetInteger(0, nm, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, nm, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, nm, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, nm, OBJPROP_XSIZE, w);
   ObjectSetInteger(0, nm, OBJPROP_YSIZE, h);
   ObjectSetInteger(0, nm, OBJPROP_BGCOLOR, bg);
   ObjectSetInteger(0, nm, OBJPROP_BORDER_TYPE, BORDER_FLAT);
   ObjectSetInteger(0, nm, OBJPROP_COLOR, brd);
   ObjectSetInteger(0, nm, OBJPROP_WIDTH, bw);
   ObjectSetInteger(0, nm, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, nm, OBJPROP_HIDDEN, true);
   ObjectSetInteger(0, nm, OBJPROP_ZORDER, 0);
}

void DLabel(string id, int x, int y, string txt, color clr, int sz, string font="Arial")
{
   string nm = PREFIX+id;
   ObjectCreate(0, nm, OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, nm, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, nm, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, nm, OBJPROP_YDISTANCE, y);
   ObjectSetString(0, nm, OBJPROP_TEXT, txt);
   ObjectSetInteger(0, nm, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, nm, OBJPROP_FONTSIZE, sz);
   ObjectSetString(0, nm, OBJPROP_FONT, font);
   ObjectSetInteger(0, nm, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, nm, OBJPROP_HIDDEN, true);
   ObjectSetInteger(0, nm, OBJPROP_ZORDER, 1);
}

void DUpdate(string id, string txt, color clr=clrNONE)
{
   string nm = PREFIX+id;
   if(ObjectFind(0, nm) >= 0)
   {
      ObjectSetString(0, nm, OBJPROP_TEXT, txt);
      if(clr != clrNONE) ObjectSetInteger(0, nm, OBJPROP_COLOR, clr);
   }
}
//+------------------------------------------------------------------+
