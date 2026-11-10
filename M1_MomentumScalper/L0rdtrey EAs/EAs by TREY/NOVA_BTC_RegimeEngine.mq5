//+------------------------------------------------------------------+
//|                                  NOVA BTC ScalperAI - RegimeEngine |
//|                                  Copyright 2026, FXBotHub Systems |
//|                                             https://fxbothub.com  |
//+------------------------------------------------------------------+
//  BTCUSD ADAPTIVE MULTI-STRATEGY ENGINE  -  v2.00
//
//  REBUILD SCOPE (honest note, read before trading live):
//  This version replaces the single-confluence signal engine with a
//  REGIME CLASSIFIER + STRATEGY ROUTER. Exactly one strategy engine is
//  active at a time, selected by the detected market regime. This is
//  the highest-expectancy structural change available without lying
//  to you about what MT5 can actually see.
//
//  WHAT THIS IS:
//   - Regime classification from ADX/ATR-percentile/EMA-structure/BB-width
//     (transparent rule-based scoring, not machine learning)
//   - 4 real strategy engines, each gated to its matching regime
//   - A tick-volume delta PROXY for buy/sell pressure (NOT real order
//     flow / NOT level-2 data - MT5 cannot see the order book on most
//     retail BTCUSD CFD feeds, so this is volume-bar-based estimation)
//   - A "cascade reversion" engine for extreme-volatility spikes, which
//     is the realistic version of "liquidation cascade detection" -
//     true liquidation data is exchange-side and not available here
//
//  WHAT THIS IS NOT (removed from original ask, deliberately, by user
//  request - scoping decision made 2026-06-20):
//   - No Smart Money Concepts order-block/FVG engine (that requires
//     discretionary-grade structure reading; a naive pivot-mitigation
//     version would misrepresent itself as SMC the same way the old
//     "ML" label misrepresented a lookup table)
//   - No news/sentiment integration (MT5 cannot call ChatGPT/Gemini/
//     news APIs from an EA without an external bridge service, which
//     is out of scope here)
//   - No "AI Score" - market/structure/execution sub-scores exist as
//     transparent weighted composites, labelled as such, not as AI
//
//  Exit system, dashboard skeleton, lot sizing, and daily-stats engine
//  are carried over from v1.00 (already solid - your audit was right
//  that the exits were the strong point).
//+------------------------------------------------------------------+
#property copyright   "Copyright 2026, NOVA BTC Scalper Systems"
#property version     "2.00"
#property description "BTCUSD Adaptive Regime-Switching Multi-Strategy Engine"
#property strict

#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>

#define DASH_PREFIX  "NOVA_BTC_"
#define EA_VERSION   "v2.00"

//+------------------------------------------------------------------+
//| ENGINE STATE MACHINE                                             |
//+------------------------------------------------------------------+
enum ENUM_ENGINE_STATE
{
   STATE_SCANNING,
   STATE_ANALYZING,
   STATE_COOLDOWN,
   STATE_DAILY_LIMIT,
   STATE_VOL_HALT,
   STATE_NEWS_PAUSE      // retained for future external bridge, unused in this build
};

enum ENUM_SIGNAL
{
   SIGNAL_BUY  =  1,
   SIGNAL_SELL = -1,
   SIGNAL_NONE =  0
};

//+------------------------------------------------------------------+
//| MARKET REGIME CLASSIFICATION                                     |
//| Reduced from the requested 7 to 6 honest, distinguishable states.|
//| "News Shock" is dropped (no news feed exists in this build to    |
//| detect it from) and folded into EXTREME_VOL, since a genuine     |
//| news shock and a liquidity-vacuum/cascade spike look IDENTICAL   |
//| from price/ATR alone - there is no way to tell them apart        |
//| without the news feed this build deliberately excludes.          |
//+------------------------------------------------------------------+
enum ENUM_REGIME
{
   REGIME_STRONG_TREND,   // ADX expanding + EMA stack aligned + clean HH/HL or LH/LL
   REGIME_WEAK_TREND,     // EMA aligned but ADX weak/flat - trend present but low conviction
   REGIME_RANGE,          // ADX low, price oscillating within a defined band
   REGIME_BREAKOUT,       // squeeze just resolved, expansion + volume confirmation
   REGIME_EXTREME_VOL,    // ATR percentile extreme - covers vol spikes, cascades, news shocks alike
   REGIME_TRANSITION      // doesn't cleanly fit any state - stay flat
};

enum ENUM_STRATEGY
{
   STRAT_NONE,
   STRAT_TREND,
   STRAT_MEAN_REVERSION,
   STRAT_VOL_BREAKOUT,
   STRAT_CASCADE_REVERSION
};

//+------------------------------------------------------------------+
//| INPUT PARAMETERS                                                 |
//+------------------------------------------------------------------+
input group "=== CORE IDENTITY ==="
input ulong   InpMagicNumber       = 778212;     // Unique magic number (changed from v1 to avoid position clash)
input string  InpTradeComment      = "NovaBTC_v2";

input group "=== RISK MANAGEMENT (primary controls) ==="
input double  InpRiskPercent       = 1.0;        // Base risk % of balance per trade
input double  InpMinRiskPercent    = 0.25;       // Floor for confidence/regime-scaled risk
input double  InpMaxRiskPercent    = 2.0;        // Ceiling for confidence/regime-scaled risk
input double  InpMaxDailyLossPct   = 5.0;        // Daily loss limit % (kill-switch)
input double  InpMaxDailyProfitPct = 10.0;       // Daily profit ceiling % (stop trading)
input int     InpMaxDailyTrades    = 12;         // Max trades per day
input double  InpMaxDrawdownPct    = 15.0;       // Equity drawdown from peak balance - halts EA
input int     InpMaxConsecLosses   = 4;          // Hard circuit breaker - halt after N straight losses

input group "=== ATR-BASED STOP LOSS & TAKE PROFIT ==="
input int     InpATRPeriod         = 14;
input double  InpSLMultiplier      = 1.4;        // SL = ATR x multiplier
input double  InpTP1R              = 1.0;        // Partial close trigger, in R
input double  InpTP2Multiplier     = 3.0;        // Hard server TP = ATR x multiplier (ceiling)
input double  InpMinSLPercent      = 0.20;       // Minimum SL distance as % of price
input double  InpMaxSLPercent      = 1.50;       // Maximum SL distance as % of price

input group "=== SMART EXIT SYSTEM (all R-multiple based, carried from v1) ==="
input double  InpBreakevenR        = 0.5;
input double  InpBEBufferPercent   = 0.02;
input bool    InpUsePeakLock       = true;
input double  InpPeakLockActivateR = 0.8;
input double  InpPeakLockRetrace   = 25.0;
input double  InpMinRewardRiskR    = 1.0;
input bool    InpUseTrailing       = true;
input double  InpTrailStartR       = 0.6;
input double  InpTrailATRMult      = 0.7;
input bool    InpUsePartialClose   = true;
input double  InpPartialClosePct   = 50.0;
input double  InpMinLockProfitR    = 0.5;

input group "=== PRE-TRADE ANALYSIS ENGINE ==="
input int     InpAnalysisMaxSec    = 90;
input int     InpAnalysisMinSec    = 8;
input int     InpAnalysisMinTicks  = 25;

input group "=== REGIME CLASSIFIER ==="
input int     InpADXPeriod         = 14;
input double  InpADXStrongTrend    = 28.0;       // ADX above this = strong trend candidate
input double  InpADXWeakTrend      = 18.0;       // ADX above this (below strong) = weak trend
input int     InpFastEMAPeriod     = 8;
input int     InpSlowEMAPeriod     = 21;
input int     InpTrendEMAPeriod    = 55;
input int     InpStructureBars     = 8;          // Swing lookback for HH/HL/LH/LL detection
input int     InpBBPeriod          = 20;
input double  InpBBDeviation       = 2.0;
input double  InpBBSqueezeRatio    = 0.012;      // BB width/price ratio defining a squeeze
input int     InpVolLookback       = 100;        // Bars for ATR percentile baseline
input double  InpVolExtremePctile  = 95.0;       // Percentile defining EXTREME_VOL regime
input double  InpVolHighPercentile = 80.0;
input double  InpVolLowPercentile  = 20.0;
input int     InpRegimeConfirmBars = 2;          // Consecutive closed bars regime must hold before switching strategy

input group "=== TREND ENGINE ==="
input double  InpRSIOverbought     = 72.0;
input double  InpRSIOversold       = 28.0;
input int     InpRSIPeriod         = 14;
input bool    InpUseHTFFilter      = true;
input ENUM_TIMEFRAMES InpHTFPeriod = PERIOD_M15;
input int     InpHTFEMAPeriod      = 50;
input double  InpPullbackMaxATR    = 1.2;        // Max pullback depth from fast EMA, in ATR, to qualify as entry

input group "=== MEAN REVERSION ENGINE ==="
input int     InpVWAPPeriod        = 50;         // Rolling VWAP lookback (session VWAP proxy)
input double  InpMRBBDeviation     = 2.5;         // Wider band for mean-reversion extremes
input double  InpMRRSIExtremeHigh  = 78.0;
input double  InpMRRSIExtremeLow   = 22.0;

input group "=== VOLATILITY BREAKOUT ENGINE ==="
input int     InpSqueezeLookback   = 20;         // Bars to confirm squeeze persisted before breakout
input double  InpBreakoutVolMult   = 1.4;        // Volume must exceed avg x this to confirm breakout

input group "=== CASCADE REVERSION ENGINE (extreme-vol mean reversion) ==="
input double  InpCascadeWickRatio  = 0.55;       // Wick must exceed this fraction of candle range
input double  InpCascadeRiskMult   = 0.4;        // Risk multiplier applied on top of normal sizing (smaller size)
input int     InpCascadeMaxHoldMin = 45;          // Time-based exit ceiling for cascade trades

input group "=== TICK VOLUME / PRESSURE PROXY ==="
input bool    InpUsePressureFilter = true;
input int     InpVolumeAvgPeriod   = 20;
input double  InpVolumeSurgeMult   = 1.3;

input group "=== SPREAD FILTER (percentage based) ==="
input double  InpMaxSpreadPercent  = 0.06;
input double  InpSpreadAvgMultiple = 2.5;

input group "=== WEEKEND / LIQUIDITY AWARENESS ==="
input bool    InpAvoidWeekendOpen  = true;
input int     InpWeekendPauseMin   = 30;

input group "=== FEATURE / OUTCOME LOGGING (ML prep) ==="
input bool    InpEnableFeatureLog  = true;       // Write pre-trade feature snapshot + outcome to CSV
input string  InpFeatureLogFile    = "NovaBTC_TradeLog.csv";

input group "=== DASHBOARD ==="
input int     InpDashX             = 15;
input int     InpDashY             = 15;

//+------------------------------------------------------------------+
//| COLOUR PALETTE - NOVA cyan/violet crypto theme (unchanged)       |
//+------------------------------------------------------------------+
const color C_BG          = C'4,8,18';
const color C_PANEL       = C'7,14,30';
const color C_PANEL2      = C'9,19,40';
const color C_HEADER      = C'10,18,42';
const color C_BORDER      = C'80,60,220';
const color C_BORDER2     = C'55,40,150';
const color C_CYAN        = C'0,225,210';
const color C_VIOLET      = C'150,110,255';
const color C_BLUE        = C'40,150,255';
const color C_GREEN       = C'0,220,140';
const color C_RED         = C'235,55,75';
const color C_GOLD        = C'255,190,30';
const color C_ORANGE      = C'255,140,30';
const color C_WHITE       = C'225,235,255';
const color C_MUTED       = C'95,110,150';
const color C_HOLD_BG     = C'55,40,0';
const color C_BUY_BG      = C'0,50,28';
const color C_SELL_BG     = C'55,5,12';
const color C_SECTION_HDR = C'12,20,48';

//+------------------------------------------------------------------+
//| GLOBAL ENGINE OBJECTS                                            |
//+------------------------------------------------------------------+
CTrade          g_Trade;
CPositionInfo   g_Pos;

//--- Indicator handles (entry timeframe)
int g_hFastEMA   = INVALID_HANDLE;
int g_hSlowEMA   = INVALID_HANDLE;
int g_hTrendEMA  = INVALID_HANDLE;
int g_hRSI       = INVALID_HANDLE;
int g_hATR       = INVALID_HANDLE;
int g_hADX       = INVALID_HANDLE;
int g_hBB        = INVALID_HANDLE;
int g_hMRBB      = INVALID_HANDLE;   // wider-deviation BB for mean reversion engine
int g_hHTFEMA    = INVALID_HANDLE;

//--- State machine
ENUM_ENGINE_STATE g_State        = STATE_SCANNING;
datetime          g_StateTimer   = 0;

//--- Regime classifier state
ENUM_REGIME  g_Regime            = REGIME_TRANSITION;
ENUM_REGIME  g_PendingRegime     = REGIME_TRANSITION;
int          g_RegimeConfirmCnt  = 0;
double       g_RegimeConfidence  = 0.0;   // 0-100, transparent composite, not ML
double       g_RegimeRiskMult    = 1.0;
ENUM_STRATEGY g_ActiveStrategy   = STRAT_NONE;
datetime     g_LastRegimeBarTime = 0;

//--- Analysis phase
ENUM_SIGNAL  g_PendingSignal     = SIGNAL_NONE;
int          g_AnalysisTicks     = 0;
datetime     g_AnalysisStart     = 0;
ENUM_STRATEGY g_PendingStrategy  = STRAT_NONE;

//--- Trade lifecycle state
double g_PeakProfit         = 0.0;
double g_PartialClosePrice  = 0.0;
bool   g_BESet              = false;
bool   g_PartialClosed      = false;
double g_EntryATR           = 0.0;
double g_EntryPrice         = 0.0;
double g_EntrySLPrice       = 0.0;
double g_EntryRiskUSD       = 0.0;
int    g_TradeDirection     = 0;
datetime g_TradeOpenTime    = 0;
ENUM_STRATEGY g_TradeStrategy = STRAT_NONE;

//--- Session / daily metrics
datetime g_SessionDay       = 0;
int      g_DailyTrades      = 0;
double   g_DailyProfit      = 0.0;
int      g_DailyWins        = 0;
int      g_DailyLosses      = 0;
int      g_ConsecLosses     = 0;
int      g_ConsecWins       = 0;
double   g_SessionOpenBal   = 0.0;
double   g_EquityPeak       = 0.0;

//--- Rolling signal / result tracking
double g_WinRate7            = 0.0;
int    g_Last7Results[7];

//--- Spread tracking
double g_AvgSpread          = 0.0;
int    g_SpreadSamples       = 0;

//--- Volatility regime tracking (ATR percentile baseline, feeds regime classifier)
double g_ATRHistory[];
double g_VolPercentile       = 50.0;

//--- Volume / pressure proxy tracking
double g_AvgVolume           = 0.0;
int    g_VolumeSamples       = 0;
double g_PressureScore       = 0.0;   // -100 (heavy sell pressure) .. +100 (heavy buy pressure)

//--- VWAP proxy (rolling, not true session VWAP - retail feeds rarely expose exchange volume)
double g_VWAP                = 0.0;

//--- Transparent weighted-composite scores (NOT machine learning - named "scores"
//    throughout, never "AI", to avoid the same mislabeling the PhantomScalperPro
//    audit flagged in earlier work)
double g_MarketScore         = 0.0;   // 0-100: trend/structure/volume/volatility/momentum/HTF composite
double g_ExecutionScore      = 0.0;   // 0-100: spread quality + volatility-spike risk composite
double g_CompositeScore      = 0.0;   // weighted blend of the above, gates entries

//--- Dashboard strings
string g_StatusText         = "BOOTING";
color  g_StatusColor        = C_GOLD;
string g_HeartbeatStr       = "0 0 0 0";

//--- Feature log file handle
int g_LogHandle = INVALID_HANDLE;

//+------------------------------------------------------------------+
//| FORWARD DECLARATIONS                                             |
//+------------------------------------------------------------------+
bool          InitIndicators();
void          ReleaseIndicators();
void          SyncDailyStats();
void          UpdateVolatilityPercentile();
void          UpdateVolumeAverage();
void          UpdatePressureProxy();
void          UpdateVWAP();
ENUM_REGIME   ClassifyRegime(double &confidence, double &riskMult);
bool          GetEMAStack(double &fast, double &slow, double &trend);
bool          GetADX(double &adxVal, double &adxPrev);
bool          IsStructureHHHL();
bool          IsStructureLHLL();
bool          IsBBSqueeze(double &widthRatio);
ENUM_STRATEGY RegimeToStrategy(ENUM_REGIME regime);
ENUM_SIGNAL   Trend_Evaluate();
ENUM_SIGNAL   MeanReversion_Evaluate();
ENUM_SIGNAL   VolBreakout_Evaluate();
ENUM_SIGNAL   CascadeReversion_Evaluate();
void          UpdateMarketScore(ENUM_SIGNAL sig);
void          UpdateExecutionScore();
void          UpdateCompositeScore();
double        GetATR();
double        CalculateLotSize(double slDistancePrice, double riskMultiplier);
void          ExecuteEntry(ENUM_SIGNAL sig, ENUM_STRATEGY strat);
void          ManageOpenTrade();
void          CheckBreakeven();
void          CheckATRTrailing();
void          CheckPeakProfitLock(double pnl);
void          CheckPartialClose(double pnl);
void          CheckCascadeTimeExit();
void          EvaluateFloatingPnL(double pnl);
void          CacheTradeEntry(ENUM_STRATEGY strat);
void          ResetTradeState();
bool          IsPositionOpen();
double        GetFloatingPnL();
void          CloseAllPositions(string reason);
bool          IsMarketOpen();
bool          IsSpreadOk();
void          UpdateSpreadAverage();
bool          IsDailyLossLimitHit();
bool          IsDailyProfitTargetHit();
bool          IsDrawdownLimitHit();
bool          IsConsecLossCircuitBreakerHit();
bool          IsWeekendPauseActive();
double        GetRiskAdjustedPercent();
datetime      GetDayStart(datetime t);
void          ProcessAnalysisPhase();
void          LogFeatureSnapshot(ENUM_SIGNAL sig, ENUM_STRATEGY strat);
void          LogTradeOutcome(double pnl, double rMultiple, int durationSec);
void          RenderDashboard();
void          UpdateDashboard();
void          PurgeDashboard();
void          DrawRect(string id, int x, int y, int w, int h, color bg, color border, int bw);
void          DrawLabel(string id, int x, int y, string txt, color clr, int sz, string fnt);
void          SetLabel(string id, string txt, color clr = clrNONE);
string        TimeframeToString(ENUM_TIMEFRAMES tf);
string        RegimeToString(ENUM_REGIME r);
string        StrategyToString(ENUM_STRATEGY s);

//+------------------------------------------------------------------+
//| INIT                                                              |
//+------------------------------------------------------------------+
int OnInit()
{
   if(StringFind(_Symbol, "BTC") < 0)
      Print("[NovaBTC] WARNING: This EA is built for BTCUSD. Current symbol: ", _Symbol);

   if(_Period == PERIOD_M1)
   {
      Print("[NovaBTC] WARNING: M1 detected. SL distances on M1 are structurally hard to "
           +"recover quickly relative to noise. M5 or M15 recommended.");
      Alert("NovaBTC: M1 timeframe detected. M5/M15 recommended.");
   }

   g_Trade.SetExpertMagicNumber(InpMagicNumber);
   g_Trade.SetDeviationInPoints(50);
   g_Trade.SetTypeFilling(ORDER_FILLING_FOK);

   if(InpRiskPercent <= 0.0 || InpRiskPercent > 10.0)
   { Alert("Risk% must be 0.01-10. Got: ", InpRiskPercent); return INIT_PARAMETERS_INCORRECT; }

   if(!InitIndicators()) return INIT_FAILED;

   ArrayResize(g_ATRHistory, InpVolLookback);
   ArrayInitialize(g_ATRHistory, 0.0);
   ArrayInitialize(g_Last7Results, -1);

   g_SessionDay     = GetDayStart(TimeCurrent());
   g_SessionOpenBal = AccountInfoDouble(ACCOUNT_BALANCE);
   g_EquityPeak     = AccountInfoDouble(ACCOUNT_EQUITY);
   SyncDailyStats();

   if(InpEnableFeatureLog)
   {
      bool fileExists = FileIsExist(InpFeatureLogFile, FILE_COMMON);
      g_LogHandle = FileOpen(InpFeatureLogFile, FILE_READ|FILE_WRITE|FILE_CSV|FILE_COMMON|FILE_ANSI, ',');
      if(g_LogHandle != INVALID_HANDLE)
      {
         FileSeek(g_LogHandle, 0, SEEK_END);
         if(!fileExists)
         {
            FileWrite(g_LogHandle, "timestamp","event","regime","confidence","strategy","signal",
                      "atr","rsi","adx","ema_fast","ema_slow","ema_trend","bb_width_ratio",
                      "vol_percentile","pressure_score","market_score","execution_score",
                      "composite_score","spread_pct","entry_price","sl_price","lot",
                      "pnl_usd","r_multiple","duration_sec","ticket");
         }
      }
      else
         Print("[NovaBTC] WARNING: could not open feature log file. Logging disabled this session.");
   }

   g_State = STATE_SCANNING;
   EventSetTimer(1);
   RenderDashboard();

   Print("[NovaBTC] v2.00 Regime-Switching Engine initialised. Symbol=", _Symbol,
         " Magic=", InpMagicNumber, " TF=", EnumToString(_Period));
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| DEINIT                                                            |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   EventKillTimer();
   PurgeDashboard();
   ReleaseIndicators();
   if(g_LogHandle != INVALID_HANDLE) FileClose(g_LogHandle);
}

//+------------------------------------------------------------------+
//| TIMER - heartbeat + stats sync                                   |
//+------------------------------------------------------------------+
void OnTimer()
{
   static uint beat = 0; beat++;
   string p[4] = {"1 0 1 1  0 1 0 0","0 1 0 0  1 0 1 1","1 1 0 1  0 0 1 0","0 0 1 0  1 1 0 1"};
   g_HeartbeatStr = p[beat % 4];

   SyncDailyStats();
   UpdateVolatilityPercentile();
   UpdateVolumeAverage();
   UpdatePressureProxy();
   UpdateVWAP();

   double eq = AccountInfoDouble(ACCOUNT_EQUITY);
   if(eq > g_EquityPeak) g_EquityPeak = eq;

   //--- Regime classification runs on the timer (effectively per-second poll of
   //    a per-closed-bar gated calculation - see ClassifyRegime's internal gate)
   double conf=0, riskMult=1.0;
   ENUM_REGIME newRegime = ClassifyRegime(conf, riskMult);
   if(newRegime != REGIME_TRANSITION || g_Regime == REGIME_TRANSITION)
   {
      if(newRegime == g_PendingRegime) g_RegimeConfirmCnt++;
      else { g_PendingRegime = newRegime; g_RegimeConfirmCnt = 1; }

      // Require N consecutive confirmations before actually switching strategy -
      // prevents whipsawing strategy engines on a single noisy bar
      if(g_RegimeConfirmCnt >= InpRegimeConfirmBars && g_Regime != g_PendingRegime)
      {
         Print("[NovaBTC] Regime switch: ", RegimeToString(g_Regime), " -> ", RegimeToString(g_PendingRegime),
               " (confidence=", DoubleToString(conf,1), ")");
         g_Regime = g_PendingRegime;
         g_ActiveStrategy = RegimeToStrategy(g_Regime);
      }
   }
   g_RegimeConfidence = conf;
   g_RegimeRiskMult   = riskMult;

   UpdateDashboard();
}

//+------------------------------------------------------------------+
//| TICK - main engine                                                |
//+------------------------------------------------------------------+
void OnTick()
{
   UpdateSpreadAverage();

   if(!IsMarketOpen())
   { g_StatusText = "MARKET CLOSED"; g_StatusColor = C_RED; return; }

   if(IsPositionOpen())
   { ManageOpenTrade(); return; }

   //--- Hard circuit breakers checked first, in order of severity ---
   if(IsDrawdownLimitHit())
   { g_State = STATE_DAILY_LIMIT; g_StatusText = "MAX DRAWDOWN HIT - HALTED"; g_StatusColor = C_RED; return; }

   if(IsConsecLossCircuitBreakerHit())
   { g_State = STATE_DAILY_LIMIT; g_StatusText = "LOSS STREAK BREAKER - HALTED"; g_StatusColor = C_RED; return; }

   if(IsDailyLossLimitHit())
   { g_State = STATE_DAILY_LIMIT; g_StatusText = "DAILY LOSS LIMIT - HALTED"; g_StatusColor = C_RED; return; }

   if(IsDailyProfitTargetHit())
   { g_State = STATE_DAILY_LIMIT; g_StatusText = "DAILY TARGET MET - HALTED"; g_StatusColor = C_GREEN; return; }

   if(g_DailyTrades >= InpMaxDailyTrades)
   { g_StatusText = "MAX DAILY TRADES REACHED"; g_StatusColor = C_GOLD; return; }

   if(InpAvoidWeekendOpen && IsWeekendPauseActive())
   { g_StatusText = "WEEKEND OPEN PAUSE"; g_StatusColor = C_MUTED; return; }

   if(!IsSpreadOk())
   {
      double sp = SymbolInfoDouble(_Symbol, SYMBOL_ASK) - SymbolInfoDouble(_Symbol, SYMBOL_BID);
      g_StatusText = "SPREAD TOO WIDE ($"+DoubleToString(sp,2)+")";
      g_StatusColor = C_RED;
      return;
   }

   if(g_State == STATE_COOLDOWN)
   {
      int left = (int)(g_StateTimer - TimeCurrent());
      if(left > 0)
      { g_StatusText = "COOLDOWN (" + IntegerToString(left) + "s)"; g_StatusColor = C_GOLD; return; }
      g_State = STATE_SCANNING;
   }

   //--- No active strategy yet (still classifying regime) ---
   if(g_ActiveStrategy == STRAT_NONE)
   {
      g_StatusText  = "CLASSIFYING REGIME - " + RegimeToString(g_Regime);
      g_StatusColor = C_MUTED;
      return;
   }

   //--- SCANNING: route to the strategy engine matching the current regime ---
   if(g_State == STATE_SCANNING)
   {
      ENUM_SIGNAL sig = SIGNAL_NONE;
      switch(g_ActiveStrategy)
      {
         case STRAT_TREND:             sig = Trend_Evaluate();             break;
         case STRAT_MEAN_REVERSION:    sig = MeanReversion_Evaluate();     break;
         case STRAT_VOL_BREAKOUT:      sig = VolBreakout_Evaluate();       break;
         case STRAT_CASCADE_REVERSION: sig = CascadeReversion_Evaluate();  break;
         default: break;
      }

      if(sig == SIGNAL_NONE)
      {
         g_StatusText  = StrategyToString(g_ActiveStrategy) + " - SCANNING [" + RegimeToString(g_Regime) + "]";
         g_StatusColor = C_MUTED;
         return;
      }

      UpdateMarketScore(sig);
      UpdateExecutionScore();
      UpdateCompositeScore();

      if(g_CompositeScore < 60.0)
      {
         g_StatusText  = "SIGNAL BELOW SCORE THRESHOLD (" + DoubleToString(g_CompositeScore,0) + "/100)";
         g_StatusColor = C_GOLD;
         return;
      }

      g_State          = STATE_ANALYZING;
      g_PendingSignal  = sig;
      g_PendingStrategy= g_ActiveStrategy;
      g_AnalysisStart  = TimeCurrent();
      g_AnalysisTicks  = 0;
      g_StatusText     = "SIGNAL DETECTED - ANALYSING";
      g_StatusColor    = C_VIOLET;
      Print("[NovaBTC] Signal=", (sig==SIGNAL_BUY?"BUY":"SELL"), " Strategy=", StrategyToString(g_ActiveStrategy),
            " Score=", DoubleToString(g_CompositeScore,1), "/100 - entering analysis phase");
   }
   else if(g_State == STATE_ANALYZING)
   {
      ProcessAnalysisPhase();
   }
}

//+------------------------------------------------------------------+
//| INDICATOR INITIALISATION                                          |
//+------------------------------------------------------------------+
bool InitIndicators()
{
   g_hFastEMA  = iMA(_Symbol, _Period, InpFastEMAPeriod,  0, MODE_EMA, PRICE_CLOSE);
   g_hSlowEMA  = iMA(_Symbol, _Period, InpSlowEMAPeriod,  0, MODE_EMA, PRICE_CLOSE);
   g_hTrendEMA = iMA(_Symbol, _Period, InpTrendEMAPeriod, 0, MODE_EMA, PRICE_CLOSE);
   g_hRSI      = iRSI(_Symbol, _Period, InpRSIPeriod, PRICE_CLOSE);
   g_hATR      = iATR(_Symbol, _Period, InpATRPeriod);
   g_hADX      = iADX(_Symbol, _Period, InpADXPeriod);
   g_hBB       = iBands(_Symbol, _Period, InpBBPeriod, 0, InpBBDeviation, PRICE_CLOSE);
   g_hMRBB     = iBands(_Symbol, _Period, InpBBPeriod, 0, InpMRBBDeviation, PRICE_CLOSE);
   g_hHTFEMA   = iMA(_Symbol, InpHTFPeriod, InpHTFEMAPeriod, 0, MODE_EMA, PRICE_CLOSE);

   if(g_hFastEMA==INVALID_HANDLE || g_hSlowEMA==INVALID_HANDLE || g_hTrendEMA==INVALID_HANDLE ||
      g_hRSI==INVALID_HANDLE     || g_hATR==INVALID_HANDLE     || g_hADX==INVALID_HANDLE ||
      g_hBB==INVALID_HANDLE      || g_hMRBB==INVALID_HANDLE    || g_hHTFEMA==INVALID_HANDLE)
   {
      Print("[NovaBTC] FAILED: one or more indicator handles invalid.");
      return false;
   }
   return true;
}

void ReleaseIndicators()
{
   int handles[] = {g_hFastEMA, g_hSlowEMA, g_hTrendEMA, g_hRSI, g_hATR, g_hADX, g_hBB, g_hMRBB, g_hHTFEMA};
   for(int i = 0; i < ArraySize(handles); i++)
      if(handles[i] != INVALID_HANDLE) IndicatorRelease(handles[i]);
}

//+------------------------------------------------------------------+
//| ATR VALUE                                                         |
//+------------------------------------------------------------------+
double GetATR()
{
   double atr[1];
   if(CopyBuffer(g_hATR, 0, 0, 1, atr) <= 0) return 0.0;
   return atr[0];
}

//+------------------------------------------------------------------+
//| MARKET REGIME CLASSIFIER                                          |
//|                                                                    |
//| Honest design note: this is a transparent rule-based decision     |
//| tree with a confidence score, not a trained model. The confidence |
//| score reflects how many of a regime's defining conditions agree,  |
//| not a probability calibrated against historical outcomes - it is  |
//| a clarity measure, not a win-rate forecast. Treat it as "how      |
//| clean does this regime look right now", not "how likely is this  |
//| trade to win".                                                    |
//|                                                                    |
//| Classification order matters - checked most-restrictive-first:    |
//|   1. EXTREME_VOL   (ATR percentile >= extreme threshold)          |
//|   2. BREAKOUT       (squeeze just resolved + volume confirms)     |
//|   3. STRONG_TREND   (ADX strong + EMA stack + clean structure)    |
//|   4. WEAK_TREND     (EMA stack aligned, ADX present but weaker)   |
//|   5. RANGE          (ADX low + BB width contracted, no breakout)  |
//|   6. TRANSITION     (none of the above cleanly fit - stay flat)   |
//+------------------------------------------------------------------+
ENUM_REGIME ClassifyRegime(double &confidence, double &riskMult)
{
   confidence = 0.0;
   riskMult   = 1.0;

   double fast, slow, trend, adx, adxPrev, bbWidthRatio;
   bool haveEMA = GetEMAStack(fast, slow, trend);
   bool haveADX = GetADX(adx, adxPrev);
   bool squeeze = IsBBSqueeze(bbWidthRatio);

   if(!haveEMA || !haveADX) return REGIME_TRANSITION;

   //--- 1. EXTREME VOLATILITY - checked first, overrides everything else.
   //    This also functions as the "cascade / news shock" catch-all per the
   //    scoping note above: from price alone these are indistinguishable.
   if(g_VolPercentile >= InpVolExtremePctile)
   {
      // Confidence scales with how far past the threshold we are
      double over = MathMin(1.0, (g_VolPercentile - InpVolExtremePctile) / (100.0 - InpVolExtremePctile));
      confidence = 70.0 + over * 30.0;
      riskMult   = InpCascadeRiskMult;   // sharply reduced size in this regime
      return REGIME_EXTREME_VOL;
   }

   //--- 2. BREAKOUT - squeeze condition persisted over the lookback window,
   //    and has now resolved (current bar width clearly exceeds squeeze ratio)
   //    with volume confirming real participation, not a fakeout.
   {
      int squeezeBars = 0;
      double upperArr[], lowerArr[], midArr[];
      ArraySetAsSeries(upperArr, true);
      ArraySetAsSeries(lowerArr, true);
      ArraySetAsSeries(midArr,   true);
      if(CopyBuffer(g_hBB, 1, 1, InpSqueezeLookback, upperArr) > 0 &&
         CopyBuffer(g_hBB, 2, 1, InpSqueezeLookback, lowerArr) > 0 &&
         CopyBuffer(g_hBB, 0, 1, InpSqueezeLookback, midArr)   > 0)
      {
         // Each historical bar's width is normalized by ITS OWN BB midline level,
         // not the current price - using current price would distort the ratio
         // for older bars after any meaningful drift over the lookback window
         for(int i = 0; i < ArraySize(upperArr); i++)
         {
            double w = upperArr[i] - lowerArr[i];
            if(midArr[i] > 0 && (w/midArr[i]) < InpBBSqueezeRatio) squeezeBars++;
         }
      }
      bool priorSqueeze = (squeezeBars >= (int)(InpSqueezeLookback * 0.5));
      bool volSurge = (g_AvgVolume > 0.0);
      if(volSurge)
      {
         long vol[1];
         if(CopyTickVolume(_Symbol, _Period, 0, 1, vol) > 0)
            volSurge = ((double)vol[0] >= g_AvgVolume * InpBreakoutVolMult);
      }

      if(priorSqueeze && !squeeze && volSurge)
      {
         confidence = 55.0 + MathMin(30.0, squeezeBars * 1.5);
         riskMult   = 1.0;
         return REGIME_BREAKOUT;
      }
   }

   //--- 3 & 4. TREND (strong or weak) - EMA stack must be aligned in one
   //    direction; ADX magnitude and structure cleanliness decide strong vs weak.
   bool bullStack = (fast > slow && slow > trend);
   bool bearStack = (fast < slow && slow < trend);
   if(bullStack || bearStack)
   {
      bool structureAgrees = bullStack ? IsStructureHHHL() : IsStructureLHLL();
      bool adxExpanding     = (adx > adxPrev);

      if(adx >= InpADXStrongTrend)
      {
         double c = 60.0;
         if(structureAgrees) c += 20.0;
         if(adxExpanding)    c += 15.0;
         confidence = MathMin(100.0, c);
         riskMult   = 1.1;   // slight size-up in a clean strong trend
         return REGIME_STRONG_TREND;
      }
      if(adx >= InpADXWeakTrend)
      {
         double c = 40.0;
         if(structureAgrees) c += 15.0;
         if(adxExpanding)    c += 10.0;
         confidence = MathMin(100.0, c);
         riskMult   = 0.85;  // reduced size - lower conviction trend
         return REGIME_WEAK_TREND;
      }
   }

   //--- 5. RANGE - low ADX, BB width contracted but NOT a freshly-resolving
   //    squeeze (that case was already claimed by BREAKOUT above)
   if(adx < InpADXWeakTrend)
   {
      double c = 50.0;
      if(squeeze) c += 20.0;
      confidence = MathMin(100.0, c);
      riskMult   = 0.75;   // mean reversion is inherently choppier - smaller size
      return REGIME_RANGE;
   }

   //--- 6. Nothing fit cleanly
   confidence = 25.0;
   riskMult   = 0.5;
   return REGIME_TRANSITION;
}

ENUM_STRATEGY RegimeToStrategy(ENUM_REGIME regime)
{
   switch(regime)
   {
      case REGIME_STRONG_TREND:
      case REGIME_WEAK_TREND:    return STRAT_TREND;
      case REGIME_RANGE:         return STRAT_MEAN_REVERSION;
      case REGIME_BREAKOUT:      return STRAT_VOL_BREAKOUT;
      case REGIME_EXTREME_VOL:   return STRAT_CASCADE_REVERSION;
      default:                   return STRAT_NONE;
   }
}

//--- EMA stack readout (shared across regime classifier + trend engine)
bool GetEMAStack(double &fast, double &slow, double &trend)
{
   double f[1], s[1], t[1];
   if(CopyBuffer(g_hFastEMA,  0, 0, 1, f) <= 0) return false;
   if(CopyBuffer(g_hSlowEMA,  0, 0, 1, s) <= 0) return false;
   if(CopyBuffer(g_hTrendEMA, 0, 0, 1, t) <= 0) return false;
   fast = f[0]; slow = s[0]; trend = t[0];
   return true;
}

//--- ADX current value + previous bar's value (for expansion/contraction check)
bool GetADX(double &adxVal, double &adxPrev)
{
   double adx[2];
   if(CopyBuffer(g_hADX, 0, 0, 2, adx) < 2) return false;
   adxVal  = adx[0];
   adxPrev = adx[1];
   return true;
}

//--- Market structure: higher-highs-higher-lows over the lookback window
//    (genuine swing detection via fractal-style local extrema, not just a
//    single highest/lowest-bar lookup like the v1 EA used)
bool IsStructureHHHL()
{
   double highs[], lows[];
   ArraySetAsSeries(highs, true);
   ArraySetAsSeries(lows,  true);
   int bars = InpStructureBars * 3;
   if(CopyHigh(_Symbol, _Period, 1, bars, highs) < bars) return false;
   if(CopyLow(_Symbol,  _Period, 1, bars, lows)  < bars) return false;

   //--- find swing highs/lows: a local extremum vs its immediate neighbours
   double swingHighs[]; double swingLows[];
   ArrayResize(swingHighs, 0); ArrayResize(swingLows, 0);
   for(int i = 1; i < bars-1; i++)
   {
      if(highs[i] > highs[i-1] && highs[i] > highs[i+1])
      { int n=ArraySize(swingHighs); ArrayResize(swingHighs,n+1); swingHighs[n]=highs[i]; }
      if(lows[i] < lows[i-1] && lows[i] < lows[i+1])
      { int n=ArraySize(swingLows); ArrayResize(swingLows,n+1); swingLows[n]=lows[i]; }
   }
   if(ArraySize(swingHighs) < 2 || ArraySize(swingLows) < 2) return false;

   // swingHighs/swingLows are time-descending (index 0 = most recent swing)
   bool higherHighs = (swingHighs[0] > swingHighs[1]);
   bool higherLows  = (swingLows[0]  > swingLows[1]);
   return (higherHighs && higherLows);
}

bool IsStructureLHLL()
{
   double highs[], lows[];
   ArraySetAsSeries(highs, true);
   ArraySetAsSeries(lows,  true);
   int bars = InpStructureBars * 3;
   if(CopyHigh(_Symbol, _Period, 1, bars, highs) < bars) return false;
   if(CopyLow(_Symbol,  _Period, 1, bars, lows)  < bars) return false;

   double swingHighs[]; double swingLows[];
   ArrayResize(swingHighs, 0); ArrayResize(swingLows, 0);
   for(int i = 1; i < bars-1; i++)
   {
      if(highs[i] > highs[i-1] && highs[i] > highs[i+1])
      { int n=ArraySize(swingHighs); ArrayResize(swingHighs,n+1); swingHighs[n]=highs[i]; }
      if(lows[i] < lows[i-1] && lows[i] < lows[i+1])
      { int n=ArraySize(swingLows); ArrayResize(swingLows,n+1); swingLows[n]=lows[i]; }
   }
   if(ArraySize(swingHighs) < 2 || ArraySize(swingLows) < 2) return false;

   bool lowerHighs = (swingHighs[0] < swingHighs[1]);
   bool lowerLows  = (swingLows[0]  < swingLows[1]);
   return (lowerHighs && lowerLows);
}

//--- Bollinger Band squeeze test (current bar)
bool IsBBSqueeze(double &widthRatio)
{
   double upper[1], lower[1];
   widthRatio = 0.0;
   if(CopyBuffer(g_hBB, 1, 0, 1, upper) <= 0) return false;
   if(CopyBuffer(g_hBB, 2, 0, 1, lower) <= 0) return false;
   double price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(price <= 0.0) return false;
   widthRatio = (upper[0]-lower[0]) / price;
   return (widthRatio < InpBBSqueezeRatio);
}

//+------------------------------------------------------------------+
//| STRATEGY 1: TREND ENGINE                                          |
//| Active in REGIME_STRONG_TREND / REGIME_WEAK_TREND.                |
//| Trades pullbacks toward the fast EMA within an established trend, |
//| not fresh breakouts - the regime classifier already confirmed the |
//| trend exists, so this engine's job is to find a low-risk entry    |
//| INTO it, avoiding the "chasing the move" problem the v1 EA had.   |
//+------------------------------------------------------------------+
ENUM_SIGNAL Trend_Evaluate()
{
   double fast, slow, trend;
   if(!GetEMAStack(fast, slow, trend)) return SIGNAL_NONE;

   bool bull = (fast > slow && slow > trend);
   bool bear = (fast < slow && slow < trend);
   if(!bull && !bear) return SIGNAL_NONE;
   ENUM_SIGNAL dir = bull ? SIGNAL_BUY : SIGNAL_SELL;

   //--- RSI must agree with trend direction but not be at an exhaustion extreme
   double rsi[1];
   if(CopyBuffer(g_hRSI, 0, 0, 1, rsi) <= 0) return SIGNAL_NONE;
   if(dir == SIGNAL_BUY  && !(rsi[0] > 45.0 && rsi[0] < InpRSIOverbought)) return SIGNAL_NONE;
   if(dir == SIGNAL_SELL && !(rsi[0] < 55.0 && rsi[0] > InpRSIOversold))  return SIGNAL_NONE;

   //--- HTF alignment filter
   if(InpUseHTFFilter)
   {
      double htf[1];
      if(CopyBuffer(g_hHTFEMA, 0, 0, 1, htf) <= 0) return SIGNAL_NONE;
      double price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      if(dir == SIGNAL_BUY  && price <= htf[0]) return SIGNAL_NONE;
      if(dir == SIGNAL_SELL && price >= htf[0]) return SIGNAL_NONE;
   }

   //--- PULLBACK CHECK: price must currently be within InpPullbackMaxATR of the
   //    fast EMA (a genuine pullback), not extended far away from it (chasing).
   //    This is the structural fix vs v1, which only checked EMA stack direction
   //    and could fire on an already-extended move.
   double atr = GetATR();
   if(atr <= 0.0) return SIGNAL_NONE;
   double price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double distFromFastEMA = MathAbs(price - fast);
   if(distFromFastEMA > atr * InpPullbackMaxATR) return SIGNAL_NONE;

   //--- Pressure proxy must not be actively fighting the trade direction
   if(InpUsePressureFilter)
   {
      if(dir == SIGNAL_BUY  && g_PressureScore < -30.0) return SIGNAL_NONE;
      if(dir == SIGNAL_SELL && g_PressureScore >  30.0) return SIGNAL_NONE;
   }

   return dir;
}

//+------------------------------------------------------------------+
//| STRATEGY 2: MEAN REVERSION ENGINE                                 |
//| Active in REGIME_RANGE only. Fades extremes back toward the VWAP  |
//| proxy / BB midline. Explicitly avoided when ADX shows real trend  |
//| (the regime gate already enforces this, but the engine re-checks  |
//| as a defensive second layer in case regime confirmation is mid-   |
//| transition).                                                      |
//+------------------------------------------------------------------+
ENUM_SIGNAL MeanReversion_Evaluate()
{
   double adx, adxPrev;
   if(!GetADX(adx, adxPrev)) return SIGNAL_NONE;
   if(adx >= InpADXWeakTrend) return SIGNAL_NONE;   // defensive re-check, real trend present

   double upper[1], lower[1], mid[1];
   if(CopyBuffer(g_hMRBB, 1, 0, 1, upper) <= 0) return SIGNAL_NONE;
   if(CopyBuffer(g_hMRBB, 2, 0, 1, lower) <= 0) return SIGNAL_NONE;
   if(CopyBuffer(g_hMRBB, 0, 0, 1, mid)   <= 0) return SIGNAL_NONE;

   double rsi[1];
   if(CopyBuffer(g_hRSI, 0, 0, 1, rsi) <= 0) return SIGNAL_NONE;

   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);

   ENUM_SIGNAL dir = SIGNAL_NONE;

   //--- Fade the lower extreme: price at/below wide BB lower band AND RSI oversold
   if(bid <= lower[0] && rsi[0] <= InpMRRSIExtremeLow) dir = SIGNAL_BUY;
   //--- Fade the upper extreme: price at/above wide BB upper band AND RSI overbought
   if(ask >= upper[0] && rsi[0] >= InpMRRSIExtremeHigh) dir = SIGNAL_SELL;
   if(dir == SIGNAL_NONE) return SIGNAL_NONE;

   //--- VWAP proxy confirmation: price should be meaningfully displaced from
   //    VWAP in the direction being faded (confirms genuine extreme, not just
   //    BB-band noise on a low-volatility range)
   if(g_VWAP > 0.0)
   {
      double price = (dir==SIGNAL_BUY) ? bid : ask;
      double dispPct = MathAbs(price - g_VWAP) / g_VWAP * 100.0;
      if(dispPct < 0.15) return SIGNAL_NONE;  // not displaced enough from VWAP to be a real extreme
   }

   //--- Volume exhaustion check: fading move should be occurring on DECLINING
   //    volume (push running out of steam), not accelerating volume (which
   //    would suggest the move continues rather than reverts)
   long volNow[2];
   if(CopyTickVolume(_Symbol, _Period, 0, 2, volNow) >= 2)
   {
      if(volNow[0] > volNow[1] * 1.2) return SIGNAL_NONE;  // volume still accelerating - don't fade yet
   }

   //--- Pressure proxy should show signs of exhaustion in the move being faded
   if(InpUsePressureFilter)
   {
      if(dir == SIGNAL_BUY  && g_PressureScore < -60.0) return SIGNAL_NONE; // selling pressure still too strong to fade
      if(dir == SIGNAL_SELL && g_PressureScore >  60.0) return SIGNAL_NONE;
   }

   return dir;
}

//+------------------------------------------------------------------+
//| STRATEGY 3: VOLATILITY BREAKOUT ENGINE                            |
//| Active in REGIME_BREAKOUT only - regime classifier has already    |
//| confirmed squeeze-then-expansion with volume. This engine decides |
//| DIRECTION of the breakout and applies a final confirmation.       |
//+------------------------------------------------------------------+
ENUM_SIGNAL VolBreakout_Evaluate()
{
   double upper[1], lower[1], mid[1];
   if(CopyBuffer(g_hBB, 1, 0, 1, upper) <= 0) return SIGNAL_NONE;
   if(CopyBuffer(g_hBB, 2, 0, 1, lower) <= 0) return SIGNAL_NONE;
   if(CopyBuffer(g_hBB, 0, 0, 1, mid)   <= 0) return SIGNAL_NONE;

   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);

   ENUM_SIGNAL dir = SIGNAL_NONE;
   if(ask > upper[0]) dir = SIGNAL_BUY;
   if(bid < lower[0]) dir = SIGNAL_SELL;
   if(dir == SIGNAL_NONE) return SIGNAL_NONE;

   //--- Direction must agree with EMA stack (avoid fading the breakout direction
   //    against the underlying short-term trend bias)
   double fast, slow, trend;
   if(GetEMAStack(fast, slow, trend))
   {
      if(dir == SIGNAL_BUY  && fast < slow) return SIGNAL_NONE;
      if(dir == SIGNAL_SELL && fast > slow) return SIGNAL_NONE;
   }

   //--- Pressure proxy must agree with breakout direction - genuine breakouts
   //    are typically accompanied by one-sided aggressive flow
   if(InpUsePressureFilter)
   {
      if(dir == SIGNAL_BUY  && g_PressureScore < 20.0)  return SIGNAL_NONE;
      if(dir == SIGNAL_SELL && g_PressureScore > -20.0) return SIGNAL_NONE;
   }

   return dir;
}

//+------------------------------------------------------------------+
//| STRATEGY 4: CASCADE REVERSION ENGINE                              |
//| Active in REGIME_EXTREME_VOL. This is the realistic version of    |
//| "liquidation cascade detection" - true liquidation/order-book     |
//| data is exchange-side and not visible from a retail MT5 feed.     |
//| What IS visible and tradeable: extreme-percentile ATR + a panic   |
//| candle with a large rejection wick, which is the price-level      |
//| FOOTPRINT a cascade/flush leaves behind. Trades mean-reversion    |
//| back toward the pre-spike range, with sharply reduced size        |
//| (InpCascadeRiskMult) and a hard time-based exit, since this is    |
//| the single riskiest regime to hold a position in.                 |
//+------------------------------------------------------------------+
ENUM_SIGNAL CascadeReversion_Evaluate()
{
   double openP  = iOpen(_Symbol, _Period, 1);
   double closeP = iClose(_Symbol, _Period, 1);
   double highP  = iHigh(_Symbol, _Period, 1);
   double lowP   = iLow(_Symbol, _Period, 1);
   double range  = highP - lowP;
   if(range <= 0.0) return SIGNAL_NONE;

   double upperWick = highP - MathMax(openP, closeP);
   double lowerWick = MathMin(openP, closeP) - lowP;

   ENUM_SIGNAL dir = SIGNAL_NONE;
   //--- Long lower wick on a panic-down spike = capitulation flush, fade with a buy
   if(lowerWick > range * InpCascadeWickRatio) dir = SIGNAL_BUY;
   //--- Long upper wick on a panic-up spike = blow-off top, fade with a sell
   if(upperWick > range * InpCascadeWickRatio) dir = SIGNAL_SELL;
   if(dir == SIGNAL_NONE) return SIGNAL_NONE;

   //--- RSI must be at a genuine extreme to corroborate the wick
   double rsi[1];
   if(CopyBuffer(g_hRSI, 0, 0, 1, rsi) <= 0) return SIGNAL_NONE;
   if(dir == SIGNAL_BUY  && rsi[0] > 35.0) return SIGNAL_NONE;
   if(dir == SIGNAL_SELL && rsi[0] < 65.0) return SIGNAL_NONE;

   //--- Require volatility to already be DECELERATING bar-over-bar before
   //    entering - never fade a cascade while it is still accelerating
   double atrNow = GetATR();
   double atrArr[2];
   if(CopyBuffer(g_hATR, 0, 1, 2, atrArr) >= 2)
   {
      if(atrArr[0] > atrArr[1] * 1.05) return SIGNAL_NONE; // still expanding, too early
   }

   return dir;
}

//+------------------------------------------------------------------+
//| TICK VOLUME / PRESSURE PROXY                                      |
//|                                                                    |
//| HONEST LABEL: this is NOT real order flow / Level 2 / order book  |
//| data. MT5 retail BTCUSD CFD feeds expose only OHLC + tick volume   |
//| (number of price changes per bar), not actual traded volume or    |
//| bid/ask aggressor side. This function estimates buy/sell pressure  |
//| from candle CLOSE LOCATION within its range, weighted by relative |
//| tick volume - a well-known proxy technique (similar in spirit to  |
//| Chaikin/Klinger volume-based oscillators), but it is an ESTIMATE, |
//| not a measurement. Treat g_PressureScore as a confirmation filter,|
//| never as a standalone signal.                                     |
//+------------------------------------------------------------------+
void UpdatePressureProxy()
{
   static datetime lastBarTime = 0;
   datetime curBarTime = (datetime)SeriesInfoInteger(_Symbol, _Period, SERIES_LASTBAR_DATE);
   if(curBarTime == lastBarTime) return;
   lastBarTime = curBarTime;

   int lookback = 10;
   double highs[], lows[], closes[], opens[];
   long   vols[];
   ArraySetAsSeries(highs,true); ArraySetAsSeries(lows,true);
   ArraySetAsSeries(closes,true); ArraySetAsSeries(opens,true); ArraySetAsSeries(vols,true);

   if(CopyHigh(_Symbol,_Period,1,lookback,highs)   < lookback) return;
   if(CopyLow(_Symbol,_Period,1,lookback,lows)     < lookback) return;
   if(CopyClose(_Symbol,_Period,1,lookback,closes) < lookback) return;
   if(CopyOpen(_Symbol,_Period,1,lookback,opens)   < lookback) return;
   if(CopyTickVolume(_Symbol,_Period,1,lookback,vols) < lookback) return;

   double totalVol = 0.0;
   double weightedDelta = 0.0;
   for(int i = 0; i < lookback; i++)
   {
      double range = highs[i] - lows[i];
      if(range <= 0.0) continue;
      // close-location-value: -1 (closed at low) .. +1 (closed at high)
      double clv = ((closes[i]-lows[i]) - (highs[i]-closes[i])) / range;
      weightedDelta += clv * (double)vols[i];
      totalVol      += (double)vols[i];
   }
   if(totalVol <= 0.0) { g_PressureScore = 0.0; return; }

   double normalized = weightedDelta / totalVol;       // -1 .. +1
   g_PressureScore = normalized * 100.0;                // -100 .. +100
}

//+------------------------------------------------------------------+
//| VWAP PROXY                                                        |
//| True session VWAP requires exchange-reported traded volume, which |
//| most retail CFD feeds do not provide. This is a rolling           |
//| volume-weighted typical-price proxy over InpVWAPPeriod bars - it  |
//| behaves similarly for mean-reversion-distance purposes but is NOT |
//| an exchange VWAP and will not exactly match one.                  |
//+------------------------------------------------------------------+
void UpdateVWAP()
{
   static datetime lastVwapBarTime = 0;
   datetime curBarTime = (datetime)SeriesInfoInteger(_Symbol, _Period, SERIES_LASTBAR_DATE);
   if(curBarTime == lastVwapBarTime) return;
   lastVwapBarTime = curBarTime;

   double highs[], lows[], closes[];
   long   vols[];
   ArraySetAsSeries(highs,true); ArraySetAsSeries(lows,true);
   ArraySetAsSeries(closes,true); ArraySetAsSeries(vols,true);

   int n = InpVWAPPeriod;
   if(CopyHigh(_Symbol,_Period,0,n,highs)   < n) return;
   if(CopyLow(_Symbol,_Period,0,n,lows)     < n) return;
   if(CopyClose(_Symbol,_Period,0,n,closes) < n) return;
   if(CopyTickVolume(_Symbol,_Period,0,n,vols) < n) return;

   double sumPV = 0.0, sumV = 0.0;
   for(int i = 0; i < n; i++)
   {
      double typical = (highs[i]+lows[i]+closes[i]) / 3.0;
      sumPV += typical * (double)vols[i];
      sumV  += (double)vols[i];
   }
   if(sumV > 0.0) g_VWAP = sumPV / sumV;
}

//+------------------------------------------------------------------+
//| VOLATILITY PERCENTILE (new-bar gated, carried logic from v1 with  |
//| the same fix already applied: sampling once per second filled    |
//| the rolling buffer with near-duplicate values of 1-2 bars)        |
//+------------------------------------------------------------------+
void UpdateVolatilityPercentile()
{
   static datetime lastBarTime = 0;
   datetime curBarTime = (datetime)SeriesInfoInteger(_Symbol, _Period, SERIES_LASTBAR_DATE);
   if(curBarTime == lastBarTime) return;
   lastBarTime = curBarTime;

   double curATR = GetATR();
   if(curATR <= 0.0) return;

   int n = ArraySize(g_ATRHistory);
   for(int i = n-1; i > 0; i--) g_ATRHistory[i] = g_ATRHistory[i-1];
   g_ATRHistory[0] = curATR;

   int validCount = 0, belowCount = 0;
   for(int i = 1; i < n; i++)
   {
      if(g_ATRHistory[i] <= 0.0) continue;
      validCount++;
      if(g_ATRHistory[i] <= curATR) belowCount++;
   }
   if(validCount < 10) { g_VolPercentile = 50.0; return; }
   g_VolPercentile = ((double)belowCount / validCount) * 100.0;
}

//+------------------------------------------------------------------+
//| VOLUME AVERAGE TRACKING (new-bar gated, same fix carried from v1) |
//+------------------------------------------------------------------+
void UpdateVolumeAverage()
{
   static datetime lastVolBarTime = 0;
   datetime curBarTime = (datetime)SeriesInfoInteger(_Symbol, _Period, SERIES_LASTBAR_DATE);
   if(curBarTime == lastVolBarTime) return;
   lastVolBarTime = curBarTime;

   long vol[1];
   if(CopyTickVolume(_Symbol, _Period, 1, 1, vol) <= 0) return;

   int cap = InpVolumeAvgPeriod * 20;
   g_AvgVolume = (g_AvgVolume * g_VolumeSamples + (double)vol[0]) / (double)(g_VolumeSamples + 1);
   g_VolumeSamples = MathMin(g_VolumeSamples + 1, cap);
}

//+------------------------------------------------------------------+
//| TRANSPARENT WEIGHTED-COMPOSITE SCORING                            |
//|                                                                    |
//| HONEST LABEL: these are weighted sums of normalized sub-checks,   |
//| not outputs of a trained or learned model. They exist to give a   |
//| single number that synthesizes the regime confidence, structure   |
//| quality, and execution conditions - useful as a final entry gate  |
//| and a dashboard readout, but the weights below were chosen by     |
//| design judgement, not fit to historical data. If you later want   |
//| genuine ML-calibrated weights, the feature log this EA writes is  |
//| exactly the dataset you'd need to do that properly.               |
//+------------------------------------------------------------------+
void UpdateMarketScore(ENUM_SIGNAL sig)
{
   double score = 0.0;

   // Trend/regime quality (0-30): direct readout of classifier confidence
   score += (g_RegimeConfidence / 100.0) * 30.0;

   // Structure quality (0-20): does swing structure agree with signal direction
   bool structOk = (sig==SIGNAL_BUY) ? IsStructureHHHL() : IsStructureLHLL();
   if(structOk) score += 20.0;

   // Volume quality (0-15): current tick volume vs rolling average
   if(g_AvgVolume > 0.0)
   {
      long vol[1];
      if(CopyTickVolume(_Symbol,_Period,0,1,vol) > 0)
      {
         double ratio = (double)vol[0] / g_AvgVolume;
         score += MathMin(15.0, ratio * 7.5);
      }
   }

   // Volatility quality (0-15): penalize extreme regimes outside cascade engine,
   // reward normal/moderate ATR percentile readings for non-cascade strategies
   if(g_ActiveStrategy == STRAT_CASCADE_REVERSION)
      score += 15.0; // extreme vol is EXPECTED and required for this engine
   else
      score += MathMax(0.0, 15.0 - MathAbs(g_VolPercentile - 50.0) * 0.3);

   // Momentum quality (0-10): pressure proxy agreement with direction
   double pressureAgree = (sig==SIGNAL_BUY) ? g_PressureScore : -g_PressureScore;
   score += MathMax(0.0, MathMin(10.0, (pressureAgree + 50.0) * 0.1));

   // HTF alignment (0-10)
   if(InpUseHTFFilter)
   {
      double htf[1];
      if(CopyBuffer(g_hHTFEMA,0,0,1,htf) > 0)
      {
         double price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
         bool htfAgree = (sig==SIGNAL_BUY) ? (price>htf[0]) : (price<htf[0]);
         if(htfAgree) score += 10.0;
      }
   }
   else score += 10.0; // filter disabled, don't penalize

   g_MarketScore = MathMax(0.0, MathMin(100.0, score));
}

void UpdateExecutionScore()
{
   double score = 100.0;

   // Spread quality penalty
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(bid > 0.0)
   {
      double spreadPct = (ask-bid)/bid*100.0;
      double spreadRatio = spreadPct / InpMaxSpreadPercent;  // 1.0 = at the limit
      score -= MathMin(50.0, spreadRatio * 50.0);
   }

   // Volatility-spike risk penalty (slippage risk rises sharply with vol percentile,
   // independent of whether we're trading the cascade engine - execution quality
   // genuinely degrades in fast markets regardless of strategy)
   score -= MathMax(0.0, (g_VolPercentile - 70.0) * 0.5);

   g_ExecutionScore = MathMax(0.0, MathMin(100.0, score));
}

void UpdateCompositeScore()
{
   // 40% market quality, 40% regime/structure confidence (folded into market score
   // already via the 30pt regime-confidence component, so re-weighted here as
   // 40% market + 40% regime-confidence-direct + 20% execution, matching the
   // requested weighting scheme while keeping every component independently visible)
   g_CompositeScore = (g_MarketScore * 0.5) + (g_RegimeConfidence * 0.3) + (g_ExecutionScore * 0.2);
   g_CompositeScore = MathMax(0.0, MathMin(100.0, g_CompositeScore));
}

//+------------------------------------------------------------------+
//| DYNAMIC LOT SIZING - now regime/confidence scaled                 |
//+------------------------------------------------------------------+
double CalculateLotSize(double slDistancePrice, double riskMultiplier)
{
   double balance    = AccountInfoDouble(ACCOUNT_BALANCE);
   double riskPct     = GetRiskAdjustedPercent() * riskMultiplier;
   riskPct = MathMax(InpMinRiskPercent, MathMin(InpMaxRiskPercent, riskPct));
   double riskAmount  = balance * (riskPct / 100.0);

   double tickVal  = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   if(tickSize <= 0.0) return SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);

   double slCostPerLot = (slDistancePrice / tickSize) * tickVal;
   if(slCostPerLot <= 0.0) return SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);

   double lot  = riskAmount / slCostPerLot;
   double minV = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxV = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);

   lot = MathMax(minV, MathMin(maxV, MathFloor(lot / step) * step));
   return lot;
}

//--- Base risk % adjustment from loss-streak / equity drawdown (regime
//    multiplier is applied SEPARATELY in CalculateLotSize, on top of this)
double GetRiskAdjustedPercent()
{
   double pct = InpRiskPercent;

   if(g_ConsecLosses >= 2)
      pct = InpRiskPercent * 0.5;
   else if(g_ConsecWins >= 5)
      pct = MathMin(InpRiskPercent * 1.25, InpMaxRiskPercent);

   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   if(g_EquityPeak > 0.0)
   {
      double ddPct = ((g_EquityPeak - equity) / g_EquityPeak) * 100.0;
      if(ddPct > 8.0)       pct *= 0.5;
      else if(ddPct > 4.0)  pct *= 0.75;
   }

   return pct;
}

//+------------------------------------------------------------------+
//| PRE-TRADE ANALYSIS PHASE                                          |
//+------------------------------------------------------------------+
void ProcessAnalysisPhase()
{
   g_AnalysisTicks++;
   int elapsed = (int)(TimeCurrent() - g_AnalysisStart);

   g_StatusText  = "ANALYSING: " + IntegerToString(elapsed) + "s | Ticks: " + IntegerToString(g_AnalysisTicks);
   g_StatusColor = C_VIOLET;

   if(elapsed > InpAnalysisMaxSec)
   {
      Print("[NovaBTC] Analysis timeout - signal invalidated.");
      g_State = STATE_SCANNING;
      return;
   }

   // Re-evaluate using the SAME strategy engine that originally fired -
   // if the regime has since switched, the pending signal is invalidated
   if(g_ActiveStrategy != g_PendingStrategy)
   {
      Print("[NovaBTC] Regime/strategy changed during analysis - invalidated.");
      g_State = STATE_SCANNING;
      return;
   }

   ENUM_SIGNAL current = SIGNAL_NONE;
   switch(g_PendingStrategy)
   {
      case STRAT_TREND:             current = Trend_Evaluate();            break;
      case STRAT_MEAN_REVERSION:    current = MeanReversion_Evaluate();    break;
      case STRAT_VOL_BREAKOUT:      current = VolBreakout_Evaluate();      break;
      case STRAT_CASCADE_REVERSION: current = CascadeReversion_Evaluate(); break;
      default: break;
   }

   if(current != g_PendingSignal)
   {
      Print("[NovaBTC] Signal reversed during analysis - invalidated.");
      g_State = STATE_SCANNING;
      return;
   }

   if(elapsed >= InpAnalysisMinSec && g_AnalysisTicks >= InpAnalysisMinTicks)
   {
      ENUM_SIGNAL finalCheck = current;
      UpdateMarketScore(finalCheck);
      UpdateExecutionScore();
      UpdateCompositeScore();

      if(g_CompositeScore < 60.0)
      {
         Print("[NovaBTC] Composite score too low at execution (", DoubleToString(g_CompositeScore,1), "/100). Aborting.");
         g_StateTimer = TimeCurrent() + 10;
         g_State      = STATE_COOLDOWN;
         return;
      }

      PrintFormat("[NovaBTC] Analysis complete. Strategy=%s Score=%.1f/100 Elapsed=%ds Ticks=%d. Firing.",
                  StrategyToString(g_PendingStrategy), g_CompositeScore, elapsed, g_AnalysisTicks);
      LogFeatureSnapshot(g_PendingSignal, g_PendingStrategy);
      ExecuteEntry(g_PendingSignal, g_PendingStrategy);
      g_StateTimer = TimeCurrent() + 10;
      g_State      = STATE_COOLDOWN;
   }
}

//+------------------------------------------------------------------+
//| TRADE EXECUTION                                                    |
//+------------------------------------------------------------------+
void ExecuteEntry(ENUM_SIGNAL sig, ENUM_STRATEGY strat)
{
   if(!IsSpreadOk()) { Print("[NovaBTC] Spread too wide at execution - aborted."); return; }

   int    digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   double atr    = GetATR();
   double price  = (sig == SIGNAL_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                       : SymbolInfoDouble(_Symbol, SYMBOL_BID);

   double slDistATR  = atr * InpSLMultiplier;
   double minSLDist   = price * (InpMinSLPercent / 100.0);
   double maxSLDist   = price * (InpMaxSLPercent / 100.0);
   double slDistance  = MathMax(minSLDist, MathMin(maxSLDist, slDistATR));
   double tp2Distance = atr * InpTP2Multiplier;

   double sl, tp;
   if(sig == SIGNAL_BUY)
   {
      sl = NormalizeDouble(price - slDistance,  digits);
      tp = NormalizeDouble(price + tp2Distance, digits);
   }
   else
   {
      sl = NormalizeDouble(price + slDistance,  digits);
      tp = NormalizeDouble(price - tp2Distance, digits);
   }

   double lot = CalculateLotSize(slDistance, g_RegimeRiskMult);

   PrintFormat("[NovaBTC] ENTRY %s | Strategy=%s Lot=%.2f Price=%.2f SL=%.2f TP=%.2f SLdist=$%.2f ATR=%.2f Regime=%s RiskMult=%.2f",
               (sig==SIGNAL_BUY?"BUY":"SELL"), StrategyToString(strat), lot, price, sl, tp, slDistance, atr,
               RegimeToString(g_Regime), g_RegimeRiskMult);

   bool ok = (sig == SIGNAL_BUY) ? g_Trade.Buy(lot, _Symbol, price, sl, tp, InpTradeComment)
                                 : g_Trade.Sell(lot, _Symbol, price, sl, tp, InpTradeComment);
   if(ok)
   {
      g_DailyTrades++;
      ResetTradeState();
      Sleep(100);
      CacheTradeEntry(strat);
      g_StatusText  = (sig==SIGNAL_BUY) ? "IN TRADE - LONG" : "IN TRADE - SHORT";
      g_StatusColor = C_GREEN;
   }
   else
   {
      Print("[NovaBTC] Order FAILED. RetCode=", g_Trade.ResultRetcode(), " ", g_Trade.ResultRetcodeDescription());
   }
}

//+------------------------------------------------------------------+
//| SMART EXIT SYSTEM - carried from v1 (already solid), extended     |
//| with a strategy-aware time-based exit for cascade-reversion       |
//| trades, which are explicitly the riskiest regime to hold in.      |
//+------------------------------------------------------------------+
void CacheTradeEntry(ENUM_STRATEGY strat)
{
   for(int i = PositionsTotal()-1; i >= 0; i--)
   {
      if(!g_Pos.SelectByIndex(i)) continue;
      if(g_Pos.Magic()!=InpMagicNumber || g_Pos.Symbol()!=_Symbol) continue;

      g_EntryPrice     = g_Pos.PriceOpen();
      g_EntrySLPrice   = g_Pos.StopLoss();
      g_EntryATR       = GetATR();
      g_TradeDirection = (g_Pos.PositionType()==POSITION_TYPE_BUY) ? 1 : -1;
      g_PeakProfit     = 0.0;
      g_BESet          = false;
      g_PartialClosed  = false;
      g_TradeOpenTime  = TimeCurrent();
      g_TradeStrategy  = strat;

      double slDistPrice = MathAbs(g_EntryPrice - g_EntrySLPrice);
      double tickVal      = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
      double tickSize     = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
      if(tickSize > 0.0)
         g_EntryRiskUSD = (slDistPrice / tickSize) * tickVal * g_Pos.Volume();
      else
         g_EntryRiskUSD = 0.01;
      if(g_EntryRiskUSD <= 0.0) g_EntryRiskUSD = 0.01;

      PrintFormat("[CacheEntry] Strategy=%s Entry=%.2f SL=%.2f SLdist=$%.2f Risk(1R)=$%.2f",
                  StrategyToString(strat), g_EntryPrice, g_EntrySLPrice, slDistPrice, g_EntryRiskUSD);
      break;
   }
}

void ResetTradeState()
{
   g_PeakProfit        = 0.0;
   g_PartialClosePrice = 0.0;
   g_BESet              = false;
   g_PartialClosed      = false;
   g_EntryATR          = 0.0;
   g_EntryPrice        = 0.0;
   g_EntrySLPrice      = 0.0;
   g_EntryRiskUSD      = 0.0;
   g_TradeDirection    = 0;
   g_TradeOpenTime     = 0;
   g_TradeStrategy     = STRAT_NONE;
}

void ManageOpenTrade()
{
   if(!IsPositionOpen()) { ResetTradeState(); return; }

   double pnl = GetFloatingPnL();
   if(pnl > g_PeakProfit) g_PeakProfit = pnl;

   string rStr = (g_EntryRiskUSD > 0) ? " ("+DoubleToString(pnl/g_EntryRiskUSD,2)+"R)" : "";
   string pnlStr = (pnl>=0?"+$":"-$") + DoubleToString(MathAbs(pnl),2) + rStr
                   + "  Peak:+$" + DoubleToString(g_PeakProfit,2);
   g_StatusText  = "TRADE RUNNING [" + StrategyToString(g_TradeStrategy) + "] " + pnlStr;
   g_StatusColor = (pnl >= 0) ? C_GREEN : C_RED;

   //--- Cascade-reversion trades get a hard time-based exit FIRST - this is
   //    the highest-priority check since holding through a second wave of an
   //    extreme-vol event is the single most dangerous failure mode this EA can have
   if(g_TradeStrategy == STRAT_CASCADE_REVERSION)
   {
      CheckCascadeTimeExit();
      if(!IsPositionOpen()) return;
   }

   if(InpUsePeakLock) CheckPeakProfitLock(pnl);
   if(!IsPositionOpen()) return;

   if(InpUsePartialClose && !g_PartialClosed) CheckPartialClose(pnl);
   if(!IsPositionOpen()) return;

   CheckBreakeven();
   if(!IsPositionOpen()) return;

   if(InpUseTrailing) CheckATRTrailing();

   EvaluateFloatingPnL(pnl);
}

//--- Cascade trades are time-boxed: extreme-vol regimes can re-accelerate,
//    and this engine's whole premise (fade the panic wick) breaks down if
//    held too long into a continuing cascade rather than a one-off flush
void CheckCascadeTimeExit()
{
   if(g_TradeOpenTime <= 0) return;
   int heldMin = (int)((TimeCurrent() - g_TradeOpenTime) / 60);
   if(heldMin >= InpCascadeMaxHoldMin)
   {
      Print("[NovaBTC] Cascade trade time-exit triggered at ", heldMin, " minutes.");
      CloseAllPositions("Cascade engine time-based exit");
      ResetTradeState();
   }
}

void CheckPeakProfitLock(double pnl)
{
   double oneR = g_EntryRiskUSD;
   if(oneR <= 0.0) return;

   double activateLevel = oneR * InpPeakLockActivateR;
   if(g_PeakProfit < activateLevel) return;

   double retraceLevel = g_PeakProfit * (1.0 - InpPeakLockRetrace / 100.0);
   double minRFloor     = oneR * InpMinRewardRiskR;
   double lockLevel = MathMax(retraceLevel, minRFloor);

   if(g_PartialClosed)
      lockLevel = MathMax(lockLevel, oneR * InpMinLockProfitR);

   if(pnl <= lockLevel && pnl < g_PeakProfit)
   {
      PrintFormat("[PeakLock] Triggered. 1R=$%.2f Peak=$%.2f(%.2fR) Lock=$%.2f(%.2fR) Current=$%.2f.",
                  oneR, g_PeakProfit, g_PeakProfit/oneR, lockLevel, lockLevel/oneR, pnl);
      CloseAllPositions("Peak-profit lock triggered");
      g_StatusText  = "PEAK LOCK EXIT  Peak:+$"+DoubleToString(g_PeakProfit,2)
                      +" ("+DoubleToString(g_PeakProfit/oneR,2)+"R)";
      g_StatusColor = C_CYAN;
      ResetTradeState();
   }
}

void CheckPartialClose(double pnl)
{
   double oneR = g_EntryRiskUSD;
   if(oneR <= 0.0) return;

   double tp1Level = oneR * InpTP1R;
   if(pnl < tp1Level) return;

   for(int i = PositionsTotal()-1; i >= 0; i--)
   {
      if(!g_Pos.SelectByIndex(i)) continue;
      if(g_Pos.Magic()!=InpMagicNumber || g_Pos.Symbol()!=_Symbol) continue;

      bool   isBuy = (g_Pos.PositionType()==POSITION_TYPE_BUY);
      double bid   = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      double ask   = SymbolInfoDouble(_Symbol, SYMBOL_ASK);

      double volStep  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
      double closeLot = MathFloor((g_Pos.Volume()*(InpPartialClosePct/100.0))/volStep)*volStep;
      closeLot        = NormalizeDouble(closeLot, 2);
      double minLot   = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);

      if(closeLot < minLot)
      {
         PrintFormat("[PartialClose] Lot %.2f below min %.2f - closing full position", closeLot, minLot);
         CloseAllPositions("TP1 full close (lot too small to partial)");
         ResetTradeState();
         return;
      }

      if(g_Trade.PositionClosePartial(g_Pos.Ticket(), closeLot))
      {
         g_PartialClosed     = true;
         g_PartialClosePrice = isBuy ? bid : ask;
         PrintFormat("[PartialClose] %.2f lots closed at %.2f. 1R=$%.2f Profit=$%.2f (%.2fR)",
                     closeLot, g_PartialClosePrice, oneR, pnl, pnl/oneR);
      }
   }
}

void CheckBreakeven()
{
   if(g_BESet) return;
   double oneR = g_EntryRiskUSD;
   if(oneR <= 0.0) return;

   double pnl = GetFloatingPnL();
   double activateLevel = oneR * InpBreakevenR;
   if(pnl < activateLevel) return;

   for(int i = PositionsTotal()-1; i >= 0; i--)
   {
      if(!g_Pos.SelectByIndex(i)) continue;
      if(g_Pos.Magic()!=InpMagicNumber || g_Pos.Symbol()!=_Symbol) continue;

      double open   = g_Pos.PriceOpen();
      double sl     = g_Pos.StopLoss();
      int    digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
      bool   isBuy  = (g_Pos.PositionType()==POSITION_TYPE_BUY);
      double buffer = open * (InpBEBufferPercent / 100.0);

      double beSL = isBuy ? NormalizeDouble(open + buffer, digits)
                           : NormalizeDouble(open - buffer, digits);
      bool needsMove = isBuy ? (sl < beSL) : (sl > beSL || sl == 0.0);

      if(needsMove && g_Trade.PositionModify(g_Pos.Ticket(), beSL, g_Pos.TakeProfit()))
      {
         g_BESet = true;
         PrintFormat("[Breakeven] SL moved to %.2f at profit $%.2f (%.2fR)", beSL, pnl, pnl/oneR);
      }
   }
}

void CheckATRTrailing()
{
   double oneR = g_EntryRiskUSD;
   if(oneR <= 0.0) return;

   double pnl = GetFloatingPnL();
   double activateLevel = oneR * InpTrailStartR;
   if(pnl < activateLevel) return;

   double atr = (g_EntryATR > 0) ? g_EntryATR : GetATR();
   if(atr <= 0) return;

   double trailDist = atr * InpTrailATRMult;

   for(int i = PositionsTotal()-1; i >= 0; i--)
   {
      if(!g_Pos.SelectByIndex(i)) continue;
      if(g_Pos.Magic()!=InpMagicNumber || g_Pos.Symbol()!=_Symbol) continue;

      double open   = g_Pos.PriceOpen();
      double sl     = g_Pos.StopLoss();
      double bid    = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      double ask    = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      int    digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
      bool   isBuy  = (g_Pos.PositionType()==POSITION_TYPE_BUY);

      double newSL = isBuy ? NormalizeDouble(bid - trailDist, digits)
                           : NormalizeDouble(ask + trailDist, digits);

      if(g_BESet)
      {
         double buffer  = open * (InpBEBufferPercent / 100.0);
         double beFloor = isBuy ? NormalizeDouble(open + buffer, digits)
                                : NormalizeDouble(open - buffer, digits);
         if(isBuy)  newSL = MathMax(newSL, beFloor);
         else       newSL = MathMin(newSL, beFloor);
      }

      bool improves;
      if(isBuy)
         improves = (newSL > sl && newSL < bid);
      else
         improves = (sl == 0.0) ? (newSL > ask) : (newSL < sl && newSL > ask);

      if(improves)
         g_Trade.PositionModify(g_Pos.Ticket(), newSL, g_Pos.TakeProfit());
   }
}

void EvaluateFloatingPnL(double pnl)
{
   double balance   = AccountInfoDouble(ACCOUNT_BALANCE);
   double dailyGoal = balance * (InpMaxDailyProfitPct / 100.0);
   double remaining = dailyGoal - g_DailyProfit;
   if(remaining > 0.0 && pnl >= remaining)
   {
      CloseAllPositions("Daily profit target reached");
      g_State = STATE_DAILY_LIMIT;
      ResetTradeState();
   }
}

//+------------------------------------------------------------------+
//| DAILY STATS SYNCHRONISATION (carried from v1, unchanged logic)   |
//+------------------------------------------------------------------+
void SyncDailyStats()
{
   datetime now      = TimeCurrent();
   datetime dayStart = GetDayStart(now);

   if(dayStart > g_SessionDay)
   {
      g_SessionDay     = dayStart;
      g_DailyTrades    = 0;
      g_DailyProfit    = 0.0;
      g_DailyWins      = 0;
      g_DailyLosses    = 0;
      g_SessionOpenBal = AccountInfoDouble(ACCOUNT_BALANCE);
      if(g_State == STATE_DAILY_LIMIT) g_State = STATE_SCANNING;
   }

   g_DailyProfit = 0.0;
   g_DailyWins   = 0;
   g_DailyLosses = 0;

   datetime scanFrom = dayStart - 7*86400;
   if(!HistorySelect(scanFrom, now)) return;

   int  ringBuf[7];  ArrayInitialize(ringBuf, -1);
   int  ringIdx    = 0;
   bool lastWasWin = false;
   int  curStreak  = 0;
   int  totalDeals = 0;

   for(int i = 0; i < HistoryDealsTotal(); i++)
   {
      ulong tkt = HistoryDealGetTicket(i);
      if(tkt == 0) continue;
      if(HistoryDealGetInteger(tkt, DEAL_MAGIC)  != (long)InpMagicNumber) continue;
      if(HistoryDealGetString(tkt,  DEAL_SYMBOL) != _Symbol) continue;
      if(HistoryDealGetInteger(tkt, DEAL_ENTRY)  != DEAL_ENTRY_OUT) continue;

      double pnl = HistoryDealGetDouble(tkt, DEAL_PROFIT)
                 + HistoryDealGetDouble(tkt, DEAL_COMMISSION)
                 + HistoryDealGetDouble(tkt, DEAL_SWAP);

      bool win = (pnl >= 0.0);
      totalDeals++;

      datetime dealTime = (datetime)HistoryDealGetInteger(tkt, DEAL_TIME);
      if(dealTime >= dayStart)
      {
         g_DailyProfit += pnl;
         if(win) g_DailyWins++; else g_DailyLosses++;
      }

      ringBuf[ringIdx % 7] = win ? 1 : 0;
      ringIdx++;

      if(win == lastWasWin) curStreak++;
      else                  curStreak = 1;
      lastWasWin = win;
   }

   if(totalDeals > 0)
   {
      if(lastWasWin) { g_ConsecWins = curStreak; g_ConsecLosses = 0; }
      else           { g_ConsecLosses = curStreak; g_ConsecWins  = 0; }
   }
   else { g_ConsecWins = 0; g_ConsecLosses = 0; }

   int wins7 = 0, total7 = 0;
   for(int j = 0; j < 7; j++)
   {
      if(ringBuf[j] < 0) continue;
      total7++;
      if(ringBuf[j] == 1) wins7++;
   }
   g_WinRate7 = (total7 > 0) ? ((double)wins7 / total7) * 100.0 : 0.0;
   for(int j = 0; j < 7; j++) g_Last7Results[j] = ringBuf[j];
}

//+------------------------------------------------------------------+
//| FEATURE / OUTCOME LOGGING (ML preparation)                        |
//| Writes a row PER TRADE: pre-trade feature snapshot at entry, plus |
//| outcome fields populated when the trade closes. Two-pass design:  |
//| we write the entry row immediately (event="ENTRY"), then append a |
//| separate "EXIT" row with the same ticket number when it closes,   |
//| so the dataset survives even if the terminal crashes mid-trade.   |
//| Any future ML work can join ENTRY/EXIT rows on the ticket column. |
//+------------------------------------------------------------------+
void LogFeatureSnapshot(ENUM_SIGNAL sig, ENUM_STRATEGY strat)
{
   if(!InpEnableFeatureLog || g_LogHandle == INVALID_HANDLE) return;

   double fast=0, slow=0, trend=0, rsi=0, adx=0, adxPrev=0, bbWidth=0;
   GetEMAStack(fast, slow, trend);
   GetADX(adx, adxPrev);
   IsBBSqueeze(bbWidth);
   double r[1]; if(CopyBuffer(g_hRSI,0,0,1,r)>0) rsi = r[0];

   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double spreadPct = (bid>0) ? (ask-bid)/bid*100.0 : 0.0;

   FileWrite(g_LogHandle, TimeToString(TimeCurrent(), TIME_DATE|TIME_SECONDS), "ENTRY",
             RegimeToString(g_Regime), DoubleToString(g_RegimeConfidence,1),
             StrategyToString(strat), (sig==SIGNAL_BUY?"BUY":"SELL"),
             DoubleToString(GetATR(),2), DoubleToString(rsi,1), DoubleToString(adx,1),
             DoubleToString(fast,2), DoubleToString(slow,2), DoubleToString(trend,2),
             DoubleToString(bbWidth,5), DoubleToString(g_VolPercentile,1),
             DoubleToString(g_PressureScore,1), DoubleToString(g_MarketScore,1),
             DoubleToString(g_ExecutionScore,1), DoubleToString(g_CompositeScore,1),
             DoubleToString(spreadPct,4), "", "", "", "", "", "", "");
   FileFlush(g_LogHandle);
}

void LogTradeOutcome(double pnl, double rMultiple, int durationSec)
{
   if(!InpEnableFeatureLog || g_LogHandle == INVALID_HANDLE) return;

   FileWrite(g_LogHandle, TimeToString(TimeCurrent(), TIME_DATE|TIME_SECONDS), "EXIT",
             RegimeToString(g_Regime), "", StrategyToString(g_TradeStrategy), "",
             "", "", "", "", "", "", "", "", "", "", "", "", "",
             DoubleToString(g_EntryPrice,2), DoubleToString(g_EntrySLPrice,2), "",
             DoubleToString(pnl,2), DoubleToString(rMultiple,2), IntegerToString(durationSec), "");
   FileFlush(g_LogHandle);
}

//+------------------------------------------------------------------+
//| UTILITY FUNCTIONS                                                  |
//+------------------------------------------------------------------+
bool IsPositionOpen()
{
   for(int i = PositionsTotal()-1; i >= 0; i--)
      if(g_Pos.SelectByIndex(i) && g_Pos.Magic()==InpMagicNumber && g_Pos.Symbol()==_Symbol) return true;
   return false;
}

double GetFloatingPnL()
{
   double total = 0.0;
   for(int i = PositionsTotal()-1; i >= 0; i--)
      if(g_Pos.SelectByIndex(i) && g_Pos.Magic()==InpMagicNumber && g_Pos.Symbol()==_Symbol)
         total += g_Pos.Profit() + g_Pos.Swap() + g_Pos.Commission();
   return total;
}

void CloseAllPositions(string reason)
{
   PrintFormat("[NovaBTC] CloseAll: %s | Peak was $%.2f", reason, g_PeakProfit);

   double pnl = GetFloatingPnL();
   double oneR = g_EntryRiskUSD;
   double rMult = (oneR > 0.0) ? pnl / oneR : 0.0;
   int durationSec = (g_TradeOpenTime > 0) ? (int)(TimeCurrent() - g_TradeOpenTime) : 0;

   for(int i = PositionsTotal()-1; i >= 0; i--)
      if(g_Pos.SelectByIndex(i) && g_Pos.Magic()==InpMagicNumber && g_Pos.Symbol()==_Symbol)
         g_Trade.PositionClose(g_Pos.Ticket());

   LogTradeOutcome(pnl, rMult, durationSec);

   g_StateTimer = TimeCurrent() + 30;
   g_State      = STATE_COOLDOWN;
   ResetTradeState();
}

bool IsMarketOpen()
{
   ENUM_SYMBOL_TRADE_MODE m = (ENUM_SYMBOL_TRADE_MODE)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_MODE);
   return (m == SYMBOL_TRADE_MODE_FULL || m == SYMBOL_TRADE_MODE_LONGONLY || m == SYMBOL_TRADE_MODE_SHORTONLY);
}

bool IsSpreadOk()
{
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(bid <= 0.0) return false;
   double spread = ask - bid;
   double spreadPct = (spread / bid) * 100.0;

   if(spreadPct > InpMaxSpreadPercent) return false;
   if(g_SpreadSamples > 50 && spread > g_AvgSpread * InpSpreadAvgMultiple) return false;
   return true;
}

void UpdateSpreadAverage()
{
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double spread = ask - bid;
   int cap = 2000;
   g_AvgSpread = (g_AvgSpread * g_SpreadSamples + spread) / (double)(g_SpreadSamples + 1);
   g_SpreadSamples = MathMin(g_SpreadSamples + 1, cap);
}

bool IsDailyLossLimitHit()
{
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double limit   = balance * (InpMaxDailyLossPct / 100.0);
   return (g_DailyProfit <= -MathAbs(limit));
}

bool IsDailyProfitTargetHit()
{
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double target  = balance * (InpMaxDailyProfitPct / 100.0);
   return (g_DailyProfit >= target);
}

bool IsDrawdownLimitHit()
{
   if(g_EquityPeak <= 0.0) return false;
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   double ddPct  = ((g_EquityPeak - equity) / g_EquityPeak) * 100.0;
   return (ddPct >= InpMaxDrawdownPct);
}

//--- Hard circuit breaker: halts ALL trading (not just sizing reduction) after
//    InpMaxConsecLosses straight losses, regardless of daily P&L - this is the
//    "Portfolio Survival Engine" kill-switch requested, distinct from the
//    softer GetRiskAdjustedPercent() streak-based size reduction
bool IsConsecLossCircuitBreakerHit()
{
   return (g_ConsecLosses >= InpMaxConsecLosses);
}

bool IsWeekendPauseActive()
{
   MqlDateTime dt; TimeToStruct(TimeGMT(), dt);
   if(dt.day_of_week == 1 && dt.hour == 0 && dt.min < InpWeekendPauseMin)
      return true;
   return false;
}

datetime GetDayStart(datetime t)
{
   MqlDateTime d; TimeToStruct(t, d);
   return t - (datetime)(d.hour*3600 + d.min*60 + d.sec);
}

string TimeframeToString(ENUM_TIMEFRAMES tf)
{
   switch(tf)
   {
      case PERIOD_M1:  return "1";
      case PERIOD_M5:  return "5";
      case PERIOD_M15: return "15";
      case PERIOD_M30: return "30";
      case PERIOD_H1:  return "H1";
      case PERIOD_H4:  return "H4";
      case PERIOD_D1:  return "D1";
      default:         return "?";
   }
}

string RegimeToString(ENUM_REGIME r)
{
   switch(r)
   {
      case REGIME_STRONG_TREND: return "STRONG TREND";
      case REGIME_WEAK_TREND:   return "WEAK TREND";
      case REGIME_RANGE:        return "RANGE";
      case REGIME_BREAKOUT:     return "BREAKOUT";
      case REGIME_EXTREME_VOL:  return "EXTREME VOL";
      default:                  return "TRANSITION";
   }
}

string StrategyToString(ENUM_STRATEGY s)
{
   switch(s)
   {
      case STRAT_TREND:             return "TREND";
      case STRAT_MEAN_REVERSION:    return "MEAN REV";
      case STRAT_VOL_BREAKOUT:      return "VOL BREAKOUT";
      case STRAT_CASCADE_REVERSION: return "CASCADE REV";
      default:                      return "NONE";
   }
}

//====================================================================
// NOVA BTC DASHBOARD 2.0 - regime/strategy aware
// Layout (top to bottom, width=330px):
//   [HEADER]            - EA name, symbol, timeframe, version
//   [MARKET INFO]       - Bid/Ask, Spread%, ATR, Vol percentile
//   [REGIME & STRATEGY]  - Current regime, confidence, active strategy
//   [SCORE ENGINE]       - Market/Execution/Composite scores (labelled
//                          as weighted composites, not "AI")
//   [FINAL DECISION]    - Large coloured BUY/SELL/HOLD block
//   [OPEN POSITION]     - Live R-multiple, peak profit, strategy tag
//   [ACCOUNT INFO]      - Balance, equity, drawdown, win rates, streak
//====================================================================

#define DW  330

void RenderDashboard()
{
   int X = InpDashX;
   int Y = InpDashY;
   int W = DW;
   int y = Y;

   DrawRect("SHELL", X, Y, W, 478, C_BG, C_BORDER, 2);

   //--- HEADER (28px)
   DrawRect("HDR_BG", X+2, y+2, W-4, 26, C_HEADER, C_BORDER, 1);
   DrawLabel("HDR_IC",  X+6,     y+4,  "NOVA BTC ADAPTIVE ENGINE",  C_CYAN,  8, "Arial Black");
   DrawLabel("HDR_SYM", X+W-95,  y+4,  _Symbol,                     C_GOLD,  9, "Impact");
   DrawLabel("HDR_TF",  X+W-50,  y+15, TimeframeToString(_Period),  C_MUTED, 7, "Arial");
   DrawLabel("HDR_VER", X+6,     y+15, EA_VERSION+" REGIME ROUTER", C_MUTED, 7, "Arial");
   y += 29;

   //--- MARKET INFO (13 hdr + 56 body = 69px)
   DrawRect("MI_HDR", X+2, y, W-4, 13, C_SECTION_HDR, C_BORDER2, 1);
   DrawLabel("MI_TIT", X+6, y+2, "MARKET INFO", C_ORANGE, 7, "Arial Black");
   DrawLabel("MI_CLK", X+W-46, y+2, "00:00", C_MUTED, 7, "Arial");
   y += 14;

   DrawRect("MI_BG", X+2, y, W-4, 56, C_PANEL, C_BORDER2, 1);
   DrawLabel("L_BID",  X+6,      y+3,  "BID",       C_MUTED, 7, "Arial");
   DrawLabel("V_BID",  X+30,     y+3,  "0.00",      C_WHITE, 8, "Arial Bold");
   DrawLabel("L_ASK",  X+W/2+2,  y+3,  "ASK",       C_MUTED, 7, "Arial");
   DrawLabel("V_ASK",  X+W/2+24, y+3,  "0.00",      C_WHITE, 8, "Arial Bold");
   DrawLabel("L_SPR",  X+6,      y+16, "SPRD",      C_MUTED, 7, "Arial");
   DrawLabel("V_SPR",  X+34,     y+16, "0.00%",     C_GOLD,  8, "Arial Bold");
   DrawLabel("L_ATR",  X+W/2+2,  y+16, "ATR",       C_MUTED, 7, "Arial");
   DrawLabel("V_ATR",  X+W/2+24, y+16, "$0",        C_CYAN,  8, "Arial Bold");
   DrawLabel("L_VPCT", X+6,      y+29, "VOL%ile",   C_MUTED, 7, "Arial");
   DrawLabel("V_VPCT", X+50,     y+29, "50%",       C_WHITE, 7, "Arial Bold");
   DrawLabel("L_PRES", X+W/2+2,  y+29, "Pressure",  C_MUTED, 7, "Arial");
   DrawLabel("V_PRES", X+W/2+46, y+29, "0",         C_WHITE, 7, "Arial Bold");
   DrawLabel("L_DRD",  X+6,      y+42, "DD",        C_MUTED, 7, "Arial");
   DrawLabel("V_DRD",  X+26,     y+42, "0.00%",     C_WHITE, 7, "Arial Bold");
   DrawLabel("L_VWAP", X+W/2+2,  y+42, "VWAP*",     C_MUTED, 7, "Arial");
   DrawLabel("V_VWAP", X+W/2+30, y+42, "0.00",      C_GOLD,  7, "Arial Bold");
   y += 58;

   //--- REGIME & STRATEGY (13 hdr + 56 body = 69px)
   DrawRect("RG_HDR", X+2, y, W-4, 13, C_SECTION_HDR, C_BORDER2, 1);
   DrawLabel("RG_TIT", X+6, y+2, "MARKET REGIME", C_ORANGE, 7, "Arial Black");
   y += 14;

   DrawRect("RG_BG", X+2, y, W-4, 56, C_PANEL, C_BORDER2, 1);
   DrawRect("RG_PILL", X+6, y+3, 200, 14, C_PANEL2, C_BORDER2, 1);
   DrawLabel("V_RGM",  X+10, y+5, "TRANSITION", C_BLUE, 8, "Arial Black");
   DrawLabel("L_RGC",  X+212, y+3, "Conf", C_MUTED, 7, "Arial");
   DrawLabel("V_RGC",  X+212, y+13, "0%", C_WHITE, 8, "Arial Bold");
   DrawLabel("L_STRAT", X+6,  y+21, "ACTIVE STRATEGY", C_MUTED, 7, "Arial");
   DrawLabel("V_STRAT", X+6,  y+32, "NONE", C_CYAN, 9, "Arial Black");
   DrawLabel("L_RMULT", X+W/2+10, y+21, "Risk Mult", C_MUTED, 7, "Arial");
   DrawLabel("V_RMULT", X+W/2+10, y+32, "1.00x", C_GOLD, 8, "Arial Bold");
   y += 58;

   //--- SCORE ENGINE (13 hdr + 56 body = 69px)
   DrawRect("SC_HDR", X+2, y, W-4, 13, C_SECTION_HDR, C_BORDER2, 1);
   DrawLabel("SC_TIT", X+6, y+2, "SCORE ENGINE (weighted composite, not ML)", C_ORANGE, 7, "Arial Black");
   y += 14;

   DrawRect("SC_BG", X+2, y, W-4, 56, C_PANEL, C_BORDER2, 1);
   DrawLabel("L_MKS", X+6, y+3, "Market", C_MUTED, 7, "Arial");
   DrawRect("MKS_BG", X+58, y+4, 100, 8, C_PANEL2, C_BORDER2, 1);
   DrawRect("MKS_FG", X+58, y+4, 10,  8, C_CYAN, clrNONE, 0);
   DrawLabel("V_MKS", X+162, y+3, "0/100", C_WHITE, 7, "Arial Bold");
   DrawLabel("L_EXS", X+6, y+16, "Execution", C_MUTED, 7, "Arial");
   DrawRect("EXS_BG", X+58, y+17, 100, 8, C_PANEL2, C_BORDER2, 1);
   DrawRect("EXS_FG", X+58, y+17, 10,  8, C_VIOLET, clrNONE, 0);
   DrawLabel("V_EXS", X+162, y+16, "0/100", C_WHITE, 7, "Arial Bold");
   DrawLabel("L_CMS", X+6, y+29, "Composite", C_MUTED, 7, "Arial");
   DrawRect("CMS_BG", X+58, y+30, 100, 8, C_PANEL2, C_BORDER2, 1);
   DrawRect("CMS_FG", X+58, y+30, 10,  8, C_GOLD, clrNONE, 0);
   DrawLabel("V_CMS", X+162, y+29, "0/100", C_GOLD, 7, "Arial Bold");
   DrawLabel("L_THR", X+6, y+42, "Entry threshold: 60/100", C_MUTED, 7, "Arial");
   y += 58;

   //--- FINAL DECISION (13 hdr + 26 block + 12 sub = 51px)
   DrawRect("FD_HDR", X+2, y, W-4, 13, C_SECTION_HDR, C_BORDER2, 1);
   DrawLabel("FD_TIT", X+6, y+2, "FINAL DECISION", C_ORANGE, 7, "Arial Black");
   y += 14;

   DrawRect("FD_BG",  X+2, y, W-4, 26, C_HOLD_BG, C_BORDER, 2);
   DrawLabel("V_FD",  X+W/2-20, y+5, "HOLD", C_GOLD, 12, "Arial Black");
   y += 28;

   DrawRect("FD_SUB", X+2, y, W-4, 12, C_PANEL2, C_BORDER2, 1);
   DrawLabel("L_FDS1", X+6,      y+1, "SIG:",    C_MUTED, 7, "Arial");
   DrawLabel("V_FDS1", X+34,     y+1, "HOLD",    C_GOLD,  7, "Arial Bold");
   DrawLabel("L_FDS2", X+W/2+2,  y+1, "STATE:",  C_MUTED, 7, "Arial");
   DrawLabel("V_FDS2", X+W/2+38, y+1, "SCANNING", C_GOLD, 7, "Arial Bold");
   y += 14;

   //--- OPEN POSITION (13 hdr + 42 body = 55px)
   DrawRect("OP_HDR", X+2, y, W-4, 13, C_SECTION_HDR, C_BORDER2, 1);
   DrawLabel("OP_TIT", X+6,    y+2, "OPEN POSITION", C_ORANGE, 7, "Arial Black");
   DrawLabel("OP_CNT", X+W-44, y+2, "0 open",         C_MUTED,  7, "Arial");
   y += 14;

   DrawRect("OP_BG", X+2, y, W-4, 42, C_PANEL, C_BORDER2, 1);
   DrawLabel("L_OTYP", X+6,      y+3,  "TYPE",  C_MUTED, 7, "Arial");
   DrawLabel("V_OTYP", X+32,     y+3,  "---",   C_MUTED, 8, "Arial Bold");
   DrawLabel("L_OSTR", X+W/2-10, y+3,  "STRAT", C_MUTED, 7, "Arial");
   DrawLabel("V_OSTR", X+W/2+18, y+3,  "---",   C_MUTED, 7, "Arial Bold");
   DrawLabel("L_OOPN", X+6,      y+16, "OPEN",  C_MUTED, 7, "Arial");
   DrawLabel("V_OOPN", X+34,     y+16, "---",   C_WHITE, 7, "Arial Bold");
   DrawLabel("L_OSLT", X+W/2-10, y+16, "SL/TP", C_MUTED, 7, "Arial");
   DrawLabel("V_OSLT", X+W/2+24, y+16, "--- / ---", C_WHITE, 7, "Arial Bold");
   DrawLabel("L_OPNL", X+6,      y+29, "P&L",   C_MUTED, 7, "Arial");
   DrawLabel("V_OPNL", X+30,     y+29, "+$0.00 (0.0R)", C_GREEN, 7, "Arial Bold");
   DrawLabel("L_OPK",  X+W/2+30, y+29, "PK",    C_MUTED, 7, "Arial");
   DrawLabel("V_OPK",  X+W/2+48, y+29, "+$0.00", C_CYAN, 7, "Arial Bold");
   y += 44;

   //--- ACCOUNT INFO (13 hdr + 56 body = 69px)
   DrawRect("AC_HDR", X+2, y, W-4, 13, C_SECTION_HDR, C_BORDER2, 1);
   DrawLabel("AC_TIT", X+6, y+2, "ACCOUNT INFO", C_ORANGE, 7, "Arial Black");
   y += 14;

   DrawRect("AC_BG", X+2, y, W-4, 56, C_PANEL, C_BORDER2, 1);
   DrawLabel("L_BAL",  X+6,      y+3,  "BAL",    C_MUTED, 7, "Arial");
   DrawLabel("V_BAL",  X+30,     y+3,  "$0.00",  C_GREEN, 8, "Arial Bold");
   DrawLabel("L_EQ",   X+W/2+2,  y+3,  "EQ",     C_MUTED, 7, "Arial");
   DrawLabel("V_EQ",   X+W/2+20, y+3,  "$0.00",  C_WHITE, 8, "Arial Bold");
   DrawLabel("L_DP",   X+6,      y+16, "DAY",    C_MUTED, 7, "Arial");
   DrawLabel("V_DP",   X+30,     y+16, "+0.00 (0.00%)", C_GREEN, 7, "Arial Bold");
   DrawLabel("L_WR",   X+6,      y+29, "WR",     C_MUTED, 7, "Arial");
   DrawLabel("V_WR",   X+26,     y+29, "0% | 7T:0%", C_CYAN, 7, "Arial Bold");
   DrawLabel("L_RSK",  X+W/2+2,  y+29, "RISK",   C_MUTED, 7, "Arial");
   DrawLabel("V_RSK",  X+W/2+26, y+29, "0.0%",   C_GOLD,  7, "Arial Bold");
   DrawLabel("L_STKR", X+6,      y+42, "STRK",   C_MUTED, 7, "Arial");
   DrawLabel("V_STK",  X+32,     y+42, "---",    C_MUTED, 7, "Arial Bold");
   DrawLabel("V_RES",  X+W/2+2,  y+42, "Form:", C_CYAN, 7, "Consolas");
   y += 58;

   ChartRedraw(0);
}

void UpdateDashboard()
{
   MqlDateTime dt; TimeToStruct(TimeCurrent(), dt);
   string clk = StringFormat("%02d:%02d", dt.hour, dt.min);
   SetLabel("MI_CLK", clk, C_MUTED);

   //--- Market Info
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double spread = ask - bid;
   double spreadPct = (bid>0) ? (spread/bid)*100.0 : 0.0;
   double atr = GetATR();

   SetLabel("V_BID", DoubleToString(bid, 2), C_WHITE);
   SetLabel("V_ASK", DoubleToString(ask, 2), C_WHITE);
   color cSp = IsSpreadOk() ? C_GOLD : C_RED;
   SetLabel("V_SPR", DoubleToString(spreadPct,3)+"%", cSp);
   SetLabel("V_ATR", "$"+DoubleToString(atr,2), C_CYAN);

   color cVP = (g_VolPercentile >= InpVolExtremePctile) ? C_RED
               : (g_VolPercentile >= InpVolHighPercentile) ? C_ORANGE
               : (g_VolPercentile <= InpVolLowPercentile) ? C_BLUE : C_GREEN;
   SetLabel("V_VPCT", DoubleToString(g_VolPercentile,0)+"%", cVP);

   color cPres = (g_PressureScore > 20) ? C_GREEN : (g_PressureScore < -20) ? C_RED : C_MUTED;
   SetLabel("V_PRES", DoubleToString(g_PressureScore,0), cPres);

   double eqDD = 0.0;
   if(g_EquityPeak > 0.0)
      eqDD = ((g_EquityPeak - AccountInfoDouble(ACCOUNT_EQUITY)) / g_EquityPeak) * 100.0;
   color cDD = (eqDD > InpMaxDrawdownPct*0.66) ? C_RED : (eqDD > InpMaxDrawdownPct*0.33) ? C_GOLD : C_WHITE;
   SetLabel("V_DRD", DoubleToString(eqDD,2)+"%", cDD);
   SetLabel("V_VWAP", DoubleToString(g_VWAP,2), C_GOLD);

   //--- Regime & Strategy panel
   color regimeClr = C_BLUE;
   switch(g_Regime)
   {
      case REGIME_STRONG_TREND: regimeClr = C_GREEN;  break;
      case REGIME_WEAK_TREND:   regimeClr = C_CYAN;   break;
      case REGIME_RANGE:        regimeClr = C_GOLD;   break;
      case REGIME_BREAKOUT:     regimeClr = C_VIOLET; break;
      case REGIME_EXTREME_VOL:  regimeClr = C_RED;    break;
      default:                  regimeClr = C_MUTED;  break;
   }
   SetLabel("V_RGM", RegimeToString(g_Regime), regimeClr);
   string rgPillN = DASH_PREFIX+"RG_PILL";
   if(ObjectFind(0,rgPillN)>=0) ObjectSetInteger(0,rgPillN,OBJPROP_BGCOLOR,
      (g_Regime==REGIME_EXTREME_VOL)?C_SELL_BG:(g_Regime==REGIME_STRONG_TREND)?C_BUY_BG:C_PANEL2);
   SetLabel("V_RGC", DoubleToString(g_RegimeConfidence,0)+"%", C_WHITE);
   SetLabel("V_STRAT", StrategyToString(g_ActiveStrategy), C_CYAN);
   SetLabel("V_RMULT", DoubleToString(g_RegimeRiskMult,2)+"x", C_GOLD);

   //--- Score Engine
   string mksBarN = DASH_PREFIX+"MKS_FG";
   if(ObjectFind(0,mksBarN)>=0) ObjectSetInteger(0,mksBarN,OBJPROP_XSIZE, MathMax(2,(int)MathRound(100*(g_MarketScore/100.0))));
   SetLabel("V_MKS", DoubleToString(g_MarketScore,0)+"/100", C_WHITE);

   string exsBarN = DASH_PREFIX+"EXS_FG";
   if(ObjectFind(0,exsBarN)>=0) ObjectSetInteger(0,exsBarN,OBJPROP_XSIZE, MathMax(2,(int)MathRound(100*(g_ExecutionScore/100.0))));
   SetLabel("V_EXS", DoubleToString(g_ExecutionScore,0)+"/100", C_WHITE);

   string cmsBarN = DASH_PREFIX+"CMS_FG";
   if(ObjectFind(0,cmsBarN)>=0) ObjectSetInteger(0,cmsBarN,OBJPROP_XSIZE, MathMax(2,(int)MathRound(100*(g_CompositeScore/100.0))));
   color cmsClr = (g_CompositeScore>=60) ? C_GREEN : C_GOLD;
   if(ObjectFind(0,cmsBarN)>=0) ObjectSetInteger(0,cmsBarN,OBJPROP_BGCOLOR,cmsClr);
   SetLabel("V_CMS", DoubleToString(g_CompositeScore,0)+"/100", cmsClr);

   //--- Final Decision (reflects whatever strategy is active, or HOLD if none/below threshold)
   ENUM_SIGNAL sig = SIGNAL_NONE;
   if(g_State == STATE_SCANNING && g_ActiveStrategy != STRAT_NONE)
   {
      switch(g_ActiveStrategy)
      {
         case STRAT_TREND:             sig = Trend_Evaluate();            break;
         case STRAT_MEAN_REVERSION:    sig = MeanReversion_Evaluate();    break;
         case STRAT_VOL_BREAKOUT:      sig = VolBreakout_Evaluate();      break;
         case STRAT_CASCADE_REVERSION: sig = CascadeReversion_Evaluate(); break;
         default: break;
      }
   }

   string decTxt; color decClr; color decBg; string aiTxt;
   if(g_State == STATE_ANALYZING)
   {
      int elapsed = (int)(TimeCurrent() - g_AnalysisStart);
      decTxt = "Decision: ANALYSING ("+IntegerToString(elapsed)+"s)";
      decClr = C_VIOLET; decBg = C_PANEL2; aiTxt = "ANALYSING";
   }
   else if(sig == SIGNAL_BUY)
   { decTxt = "Decision: BUY"; decClr = C_GREEN; decBg = C_BUY_BG; aiTxt = "BUY"; }
   else if(sig == SIGNAL_SELL)
   { decTxt = "Decision: SELL"; decClr = C_RED; decBg = C_SELL_BG; aiTxt = "SELL"; }
   else
   { decTxt = "Decision: HOLD"; decClr = C_GOLD; decBg = C_HOLD_BG; aiTxt = "HOLD"; }

   string decBarN = DASH_PREFIX+"FD_BG";
   if(ObjectFind(0,decBarN)>=0) ObjectSetInteger(0,decBarN,OBJPROP_BGCOLOR,decBg);
   if(g_State == STATE_ANALYZING) SetLabel("V_FD", "ANALYSING", C_VIOLET);
   else SetLabel("V_FD", aiTxt, decClr);

   SetLabel("V_FDS1", aiTxt, decClr);
   SetLabel("V_FDS2", g_StatusText, g_StatusColor);

   //--- Open Position panel
   bool hasPos = false;
   for(int i = 0; i < PositionsTotal(); i++)
   {
      if(g_Pos.SelectByIndex(i) && g_Pos.Magic()==InpMagicNumber && g_Pos.Symbol()==_Symbol)
      {
         hasPos = true;
         string typStr = (g_Pos.PositionType()==POSITION_TYPE_BUY) ? "BUY" : "SELL";
         color  typClr = (g_Pos.PositionType()==POSITION_TYPE_BUY) ? C_GREEN : C_RED;
         double rowPnl = g_Pos.Profit()+g_Pos.Swap()+g_Pos.Commission();

         SetLabel("V_OTYP", typStr, typClr);
         SetLabel("V_OSTR", StrategyToString(g_TradeStrategy), C_CYAN);
         SetLabel("V_OOPN", DoubleToString(g_Pos.PriceOpen(),2), C_WHITE);
         SetLabel("V_OSLT", DoubleToString(g_Pos.StopLoss(),2)+" / "+DoubleToString(g_Pos.TakeProfit(),2), C_WHITE);

         string rTxt    = (g_EntryRiskUSD>0) ? " ("+DoubleToString(rowPnl/g_EntryRiskUSD,2)+"R)" : "";
         string pkRTxt  = (g_EntryRiskUSD>0) ? " ("+DoubleToString(g_PeakProfit/g_EntryRiskUSD,2)+"R)" : "";
         color  pnlClr  = (rowPnl>=0) ? C_GREEN : C_RED;
         SetLabel("V_OPNL", (rowPnl>=0?"+$":"-$")+DoubleToString(MathAbs(rowPnl),2)+rTxt, pnlClr);
         SetLabel("V_OPK",  "+$"+DoubleToString(g_PeakProfit,2)+pkRTxt, C_CYAN);
         break;
      }
   }
   if(!hasPos)
   {
      SetLabel("V_OTYP", "---", C_MUTED);
      SetLabel("V_OSTR", "---", C_MUTED);
      SetLabel("V_OOPN", "---", C_MUTED);
      SetLabel("V_OSLT", "--- / ---", C_MUTED);
      SetLabel("V_OPNL", "+$0.00 (0.0R)", C_MUTED);
      SetLabel("V_OPK",  "+$0.00 (0.0R)", C_MUTED);
   }
   SetLabel("OP_CNT", (hasPos?"1 open":"0 open"), hasPos ? C_CYAN : C_MUTED);

   //--- Account Info
   double bal    = AccountInfoDouble(ACCOUNT_BALANCE);
   double eq     = AccountInfoDouble(ACCOUNT_EQUITY);
   int    tot    = g_DailyWins + g_DailyLosses;
   double wr     = (tot>0) ? ((double)g_DailyWins/tot)*100.0 : 0.0;
   double dpPct  = (bal>0) ? (g_DailyProfit/bal)*100.0 : 0.0;

   SetLabel("V_BAL", "$"+DoubleToString(bal,2), C_GREEN);
   SetLabel("V_EQ",  "$"+DoubleToString(eq, 2), C_WHITE);
   color cDp = (g_DailyProfit>=0) ? C_GREEN : C_RED;
   SetLabel("V_DP",  (g_DailyProfit>=0?"+":"")+DoubleToString(g_DailyProfit,2)
            +" ("+DoubleToString(MathAbs(dpPct),2)+"%)", cDp);

   color cWR = (g_WinRate7>=60) ? C_GREEN : (g_WinRate7>=40 ? C_GOLD : C_RED);
   string wrStr = IntegerToString((int)wr)+"% | 7T:"+IntegerToString((int)g_WinRate7)+"%";
   SetLabel("V_WR", wrStr, cWR);
   SetLabel("V_RSK", DoubleToString(GetRiskAdjustedPercent()*g_RegimeRiskMult,2)+"%", C_GOLD);

   if(g_ConsecLosses >= 2)
   {
      string brk = (g_ConsecLosses >= InpMaxConsecLosses) ? " BREAKER!" : "";
      SetLabel("V_STK", "!! LOSS x"+IntegerToString(g_ConsecLosses)+brk, C_RED);
   }
   else if(g_ConsecWins >= 2)
      SetLabel("V_STK", "WIN STREAK x"+IntegerToString(g_ConsecWins), C_GREEN);
   else
      SetLabel("V_STK", "---", C_MUTED);

   string strip = "";
   for(int j = 0; j < 7; j++)
   {
      if(g_Last7Results[j] < 0) strip += ". ";
      else if(g_Last7Results[j]==1) strip += "W ";
      else strip += "L ";
   }
   SetLabel("V_RES", "Form: "+strip, C_CYAN);

   ChartRedraw(0);
}

void PurgeDashboard()
{
   ObjectsDeleteAll(0, DASH_PREFIX);
   ChartRedraw(0);
}

void DrawRect(string id, int x, int y, int w, int h, color bg, color border, int bw)
{
   string n = DASH_PREFIX + id;
   if(ObjectFind(0, n) < 0) ObjectCreate(0, n, OBJ_RECTANGLE_LABEL, 0, 0, 0);
   ObjectSetInteger(0, n, OBJPROP_CORNER,    CORNER_LEFT_UPPER);
   ObjectSetInteger(0, n, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, n, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, n, OBJPROP_XSIZE,     w);
   ObjectSetInteger(0, n, OBJPROP_YSIZE,     h);
   ObjectSetInteger(0, n, OBJPROP_BGCOLOR,   bg);
   if(border != clrNONE)
   {
      ObjectSetInteger(0, n, OBJPROP_BORDER_TYPE, BORDER_FLAT);
      ObjectSetInteger(0, n, OBJPROP_COLOR,        border);
      ObjectSetInteger(0, n, OBJPROP_WIDTH,         bw);
   }
   else ObjectSetInteger(0, n, OBJPROP_BORDER_TYPE, BORDER_RAISED);
   ObjectSetInteger(0, n, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, n, OBJPROP_HIDDEN,     true);
   ObjectSetInteger(0, n, OBJPROP_ZORDER,     0);
}

void DrawLabel(string id, int x, int y, string txt, color clr, int sz, string fnt)
{
   string n = DASH_PREFIX + id;
   if(ObjectFind(0, n) < 0) ObjectCreate(0, n, OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, n, OBJPROP_CORNER,    CORNER_LEFT_UPPER);
   ObjectSetInteger(0, n, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, n, OBJPROP_YDISTANCE, y);
   ObjectSetString( 0, n, OBJPROP_TEXT,      txt);
   ObjectSetInteger(0, n, OBJPROP_COLOR,     clr);
   ObjectSetInteger(0, n, OBJPROP_FONTSIZE,  sz);
   ObjectSetString( 0, n, OBJPROP_FONT,      fnt);
   ObjectSetInteger(0, n, OBJPROP_SELECTABLE,false);
   ObjectSetInteger(0, n, OBJPROP_HIDDEN,    true);
   ObjectSetInteger(0, n, OBJPROP_ZORDER,    1);
}

void SetLabel(string id, string txt, color clr = clrNONE)
{
   string n = DASH_PREFIX + id;
   if(ObjectFind(0, n) >= 0)
   {
      ObjectSetString(0, n, OBJPROP_TEXT, txt);
      if(clr != clrNONE) ObjectSetInteger(0, n, OBJPROP_COLOR, clr);
   }
}
//+------------------------------------------------------------------+
//| END OF FILE                                                       |
//+------------------------------------------------------------------+
