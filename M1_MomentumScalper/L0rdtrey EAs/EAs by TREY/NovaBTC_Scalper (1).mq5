//+------------------------------------------------------------------+
//|                                            NOVA BTC ScalperAI.mq5 |
//|                                  Copyright 2026, FXBotHub Systems |
//|                                             https://fxbothub.com  |
//+------------------------------------------------------------------+
//  BTCUSD-DEDICATED SCALPING ENGINE  -  v1.00
//  Built from scratch for crypto market structure:
//    - 24/7 trading, no forex session gaps, but volatility-regime aware
//    - Percentage-based spread filter (crypto spreads scale with price)
//    - Volatility regime classifier (ATR percentile over rolling window)
//    - Multi-timeframe trend alignment (entry TF + higher TF filter)
//    - Volume surge detection (crypto often telegraphs moves with volume)
//    - Momentum exhaustion filter (avoids buying tops / selling bottoms)
//    - Every exit (breakeven, trailing, partial, peak-lock) is R-multiple
//      based from the ground up - tied to the ACTUAL dollar risk of each
//      trade, never to flat point counts
//    - Equity-curve adaptive position sizing (drawdown-aware, not just
//      loss-streak based)
//    - Weekend / low-liquidity awareness
//    - Full NEURA-style rich dashboard
//+------------------------------------------------------------------+
#property copyright   "Copyright 2026, NOVA BTC Scalper Systems"
#property version     "1.00"
#property description "BTCUSD Dedicated Scalping Engine - Full Confluence + Regime Awareness"
#property strict

#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>

#define DASH_PREFIX  "NOVA_BTC_"
#define EA_VERSION   "v1.00"

//+------------------------------------------------------------------+
//| ENGINE STATE MACHINE                                             |
//+------------------------------------------------------------------+
enum ENUM_ENGINE_STATE
{
   STATE_SCANNING,
   STATE_ANALYZING,
   STATE_COOLDOWN,
   STATE_DAILY_LIMIT,
   STATE_VOL_HALT,       // halted due to extreme volatility regime
   STATE_NEWS_PAUSE
};

enum ENUM_SIGNAL
{
   SIGNAL_BUY  =  1,
   SIGNAL_SELL = -1,
   SIGNAL_NONE =  0
};

enum ENUM_VOL_REGIME
{
   VOL_LOW,
   VOL_NORMAL,
   VOL_HIGH,
   VOL_EXTREME
};

//+------------------------------------------------------------------+
//| INPUT PARAMETERS                                                 |
//+------------------------------------------------------------------+
input group "=== CORE IDENTITY ==="
input ulong   InpMagicNumber       = 778211;     // Unique magic number
input string  InpTradeComment      = "NovaBTC_v1";

input group "=== RISK MANAGEMENT (primary controls) ==="
input double  InpRiskPercent       = 1.0;        // Risk % of balance per trade
input double  InpMaxDailyLossPct   = 5.0;        // Daily loss limit % (kill-switch)
input double  InpMaxDailyProfitPct = 10.0;       // Daily profit ceiling % (stop trading)
input int     InpMaxDailyTrades    = 12;         // Max trades per day
input double  InpMaxDrawdownPct    = 15.0;       // Equity drawdown from peak balance - halts EA

input group "=== ATR-BASED STOP LOSS & TAKE PROFIT ==="
input int     InpATRPeriod         = 14;         // ATR period
input double  InpSLMultiplier      = 1.4;        // SL = ATR x multiplier
input double  InpTP1R              = 1.0;        // Partial close trigger, in R (x actual risk)
input double  InpTP2Multiplier     = 3.0;        // Hard server TP = ATR x multiplier (ceiling)
input double  InpMinSLPercent      = 0.20;       // Minimum SL distance as % of price (floor)
input double  InpMaxSLPercent      = 1.50;       // Maximum SL distance as % of price (ceiling)

input group "=== SMART EXIT SYSTEM (all R-multiple based) ==="
input double  InpBreakevenR        = 0.5;        // Move SL to breakeven after profit >= this x R
input double  InpBEBufferPercent   = 0.02;       // Buffer beyond entry at BE, as % of price
input bool    InpUsePeakLock       = true;       // Peak-profit lock enabled
input double  InpPeakLockActivateR = 0.8;        // Arms once profit >= this x R
input double  InpPeakLockRetrace   = 25.0;       // Close if profit retraces this % from peak
input double  InpMinRewardRiskR    = 1.0;        // Never close below this x R once peak-lock armed
input bool    InpUseTrailing       = true;       // ATR trailing stop enabled
input double  InpTrailStartR       = 0.6;        // Trailing activates once profit >= this x R
input double  InpTrailATRMult      = 0.7;        // Trail distance = ATR x this multiplier
input bool    InpUsePartialClose   = true;       // Partial close at TP1 enabled
input double  InpPartialClosePct   = 50.0;       // % of position closed at TP1
input double  InpMinLockProfitR    = 0.5;        // After partial close, lock min this x R on remainder

input group "=== PRE-TRADE ANALYSIS ENGINE ==="
input int     InpAnalysisMaxSec    = 90;         // Max analysis window (seconds)
input int     InpAnalysisMinSec    = 8;          // Minimum observation time
input int     InpAnalysisMinTicks  = 25;         // Min tick volume to confirm

input group "=== SIGNAL CONFLUENCE ENGINE ==="
input int     InpFastEMAPeriod     = 8;          // Fast EMA period
input int     InpSlowEMAPeriod     = 21;         // Slow EMA period
input int     InpTrendEMAPeriod    = 55;         // Macro trend EMA (bias filter)
input int     InpRSIPeriod         = 14;         // RSI period
input double  InpRSIOverbought     = 72.0;       // RSI overbought level (crypto runs hotter)
input double  InpRSIOversold       = 28.0;       // RSI oversold level
input int     InpADXPeriod         = 14;         // ADX period
input double  InpADXMinStrength    = 18.0;       // Minimum ADX for trend trade
input int     InpMACDFast          = 12;         // MACD fast EMA
input int     InpMACDSlow          = 26;         // MACD slow EMA
input int     InpMACDSignal        = 9;          // MACD signal period
input int     InpBBPeriod          = 20;         // Bollinger Bands period
input double  InpBBDeviation       = 2.0;        // Bollinger Bands deviation
input double  InpBBSqueezeRatio    = 0.012;      // BB width/price squeeze threshold (crypto wider)
input int     InpStructureBars     = 6;          // Market structure swing high/low bars

input group "=== MULTI-TIMEFRAME TREND FILTER ==="
input bool    InpUseHTFFilter      = true;       // Require higher-TF trend alignment
input ENUM_TIMEFRAMES InpHTFPeriod = PERIOD_M15;  // Higher timeframe for trend confirmation
input int     InpHTFEMAPeriod      = 50;         // EMA period on higher timeframe

input group "=== VOLATILITY REGIME ENGINE ==="
input int     InpVolLookback       = 100;        // Bars to build ATR percentile baseline
input double  InpVolHighPercentile = 80.0;       // Above this percentile = HIGH vol regime
input double  InpVolExtremePctile  = 95.0;       // Above this percentile = EXTREME (halt new entries)
input double  InpVolLowPercentile  = 20.0;       // Below this percentile = LOW vol regime (tighter filters)

input group "=== VOLUME SURGE FILTER ==="
input bool    InpUseVolumeFilter   = true;       // Require volume confirmation on entry
input int     InpVolumeAvgPeriod   = 20;         // Bars to average tick volume
input double  InpVolumeSurgeMult   = 1.3;        // Current volume must exceed avg x this

input group "=== SPREAD FILTER (percentage based) ==="
input double  InpMaxSpreadPercent  = 0.06;       // Max spread as % of price (e.g. 0.06% of $60k = $36)
input double  InpSpreadAvgMultiple = 2.5;        // Reject if spread > rolling avg x this

input group "=== WEEKEND / LIQUIDITY AWARENESS ==="
input bool    InpAvoidWeekendOpen  = true;       // Skip new entries near weekend open (thin liquidity)
input int     InpWeekendPauseMin   = 30;         // Minutes to pause after weekly market reopen

input group "=== STREAK & DRAWDOWN PROTECTION ==="
input int     InpMaxLossStreak     = 3;          // Tighten signal threshold after N losses
input int     InpWinStreakBoost    = 5;          // Allow modest size boost after N wins

input group "=== DASHBOARD ==="
input int     InpDashX             = 15;
input int     InpDashY             = 15;

//+------------------------------------------------------------------+
//| COLOUR PALETTE - NOVA cyan/violet crypto theme                   |
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
int g_hMACD      = INVALID_HANDLE;
int g_hBB        = INVALID_HANDLE;
int g_hHTFEMA    = INVALID_HANDLE;   // higher timeframe trend EMA

//--- State machine
ENUM_ENGINE_STATE g_State        = STATE_SCANNING;
datetime          g_StateTimer   = 0;

//--- Analysis phase
ENUM_SIGNAL  g_PendingSignal     = SIGNAL_NONE;
int          g_AnalysisTicks     = 0;
datetime     g_AnalysisStart     = 0;

//--- Trade lifecycle state (cached at entry, reset at close)
double g_PeakProfit         = 0.0;
double g_PartialClosePrice  = 0.0;
bool   g_BESet              = false;
bool   g_PartialClosed      = false;
double g_EntryATR           = 0.0;
double g_EntryPrice         = 0.0;
double g_EntrySLPrice       = 0.0;
double g_EntryRiskUSD       = 0.0;   // actual dollar value of 1R for this trade
int    g_TradeDirection     = 0;

//--- Session / daily metrics
datetime g_SessionDay       = 0;
int      g_DailyTrades      = 0;
double   g_DailyProfit      = 0.0;
int      g_DailyWins        = 0;
int      g_DailyLosses      = 0;
int      g_ConsecLosses     = 0;
int      g_ConsecWins       = 0;
double   g_SessionOpenBal   = 0.0;
double   g_EquityPeak       = 0.0;   // all-time equity peak for drawdown calc

//--- Rolling signal / result tracking
int    g_LastConfluenceScore = 0;
double g_WinRate7            = 0.0;
int    g_Last7Results[7];

//--- Spread tracking
double g_AvgSpread          = 0.0;
int    g_SpreadSamples       = 0;

//--- Volatility regime tracking
double g_ATRHistory[];              // rolling ATR buffer for percentile calc
ENUM_VOL_REGIME g_VolRegime  = VOL_NORMAL;
double g_VolPercentile       = 50.0;

//--- Volume tracking
double g_AvgVolume           = 0.0;
int    g_VolumeSamples       = 0;

//--- Dashboard strings
string g_StatusText         = "BOOTING";
color  g_StatusColor        = C_GOLD;
string g_HeartbeatStr       = "0 0 0 0";

//+------------------------------------------------------------------+
//| FORWARD DECLARATIONS                                             |
//+------------------------------------------------------------------+
bool         InitIndicators();
void         ReleaseIndicators();
void         SyncDailyStats();
void         UpdateVolatilityRegime();
void         UpdateVolumeAverage();
ENUM_SIGNAL  EvaluateConfluence(bool detectionMode = true);
bool         CheckEMAStack(double &fast, double &slow, double &trend);
bool         CheckRSI(ENUM_SIGNAL sig, double &rsiVal);
bool         CheckADX(double &adxVal);
bool         CheckMACD(ENUM_SIGNAL sig);
bool         CheckBollingerBands(ENUM_SIGNAL sig, bool &inSqueeze);
bool         CheckMarketStructure(ENUM_SIGNAL sig, bool proximityMode = false);
bool         CheckHTFTrend(ENUM_SIGNAL sig);
bool         CheckVolumeSurge();
bool         CheckMomentumExhaustion(ENUM_SIGNAL sig);
double       GetATR();
double       CalculateLotSize(double slDistancePrice);
void         ExecuteEntry(ENUM_SIGNAL sig);
void         ManageOpenTrade();
void         CheckBreakeven();
void         CheckATRTrailing();
void         CheckPeakProfitLock(double pnl);
void         CheckPartialClose(double pnl);
void         EvaluateFloatingPnL(double pnl);
void         CacheTradeEntry();
void         ResetTradeState();
bool         IsPositionOpen();
double       GetFloatingPnL();
void         CloseAllPositions(string reason);
bool         IsMarketOpen();
bool         IsSpreadOk();
void         UpdateSpreadAverage();
bool         IsDailyLossLimitHit();
bool         IsDailyProfitTargetHit();
bool         IsDrawdownLimitHit();
bool         IsWeekendPauseActive();
double       GetRiskAdjustedPercent();
datetime     GetDayStart(datetime t);
void         ProcessAnalysisPhase();
void         RenderDashboard();
void         UpdateDashboard();
void         PurgeDashboard();
void         DrawRect(string id, int x, int y, int w, int h, color bg, color border, int bw);
void         DrawLabel(string id, int x, int y, string txt, color clr, int sz, string fnt);
void         SetLabel(string id, string txt, color clr = clrNONE);
string       TimeframeToString(ENUM_TIMEFRAMES tf);
string       VolRegimeToString(ENUM_VOL_REGIME r);

//+------------------------------------------------------------------+
//| INIT                                                              |
//+------------------------------------------------------------------+
int OnInit()
{
   //--- Symbol sanity check
   if(StringFind(_Symbol, "BTC") < 0)
      Print("[NovaBTC] WARNING: This EA is built for BTCUSD. Current symbol: ", _Symbol);

   //--- M1 warning - same lesson as the GOLD EA: ultra-low timeframes
   //    produce SL distances that are structurally hard to recover quickly
   if(_Period == PERIOD_M1)
   {
      Print("[NovaBTC] WARNING: M1 detected. BTCUSD spreads/noise on M1 often "
           +"force SL distances that are large relative to typical M1 moves. M5 or M15 recommended.");
      Alert("NovaBTC: M1 timeframe detected. M5/M15 recommended for BTCUSD scalping.");
   }

   g_Trade.SetExpertMagicNumber(InpMagicNumber);
   g_Trade.SetDeviationInPoints(50);   // crypto needs wider slippage tolerance
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

   g_State = STATE_SCANNING;
   EventSetTimer(1);
   RenderDashboard();

   Print("[NovaBTC] Initialised. Symbol=", _Symbol, " Magic=", InpMagicNumber, " TF=", EnumToString(_Period));
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
   UpdateVolatilityRegime();
   UpdateVolumeAverage();

   // Track all-time equity peak for drawdown calculation
   double eq = AccountInfoDouble(ACCOUNT_EQUITY);
   if(eq > g_EquityPeak) g_EquityPeak = eq;

   UpdateDashboard();
}

//+------------------------------------------------------------------+
//| TICK - main engine                                                |
//+------------------------------------------------------------------+
void OnTick()
{
   UpdateSpreadAverage();

   //--- Market tradeable?
   if(!IsMarketOpen())
   { g_StatusText = "MARKET CLOSED"; g_StatusColor = C_RED; return; }

   //--- Manage any open trade first
   if(IsPositionOpen())
   { ManageOpenTrade(); return; }

   //--- Equity drawdown circuit breaker (all-time, not just daily)
   if(IsDrawdownLimitHit())
   {
      g_State = STATE_DAILY_LIMIT;
      g_StatusText = "MAX DRAWDOWN HIT - HALTED";
      g_StatusColor = C_RED;
      return;
   }

   //--- Daily loss kill-switch
   if(IsDailyLossLimitHit())
   {
      g_State = STATE_DAILY_LIMIT;
      g_StatusText = "DAILY LOSS LIMIT - HALTED";
      g_StatusColor = C_RED;
      return;
   }

   //--- Daily profit ceiling
   if(IsDailyProfitTargetHit())
   {
      g_State = STATE_DAILY_LIMIT;
      g_StatusText = "DAILY TARGET MET - HALTED";
      g_StatusColor = C_GREEN;
      return;
   }

   //--- Max daily trades
   if(g_DailyTrades >= InpMaxDailyTrades)
   {
      g_StatusText = "MAX DAILY TRADES REACHED";
      g_StatusColor = C_GOLD;
      return;
   }

   //--- Weekend / thin-liquidity pause
   if(InpAvoidWeekendOpen && IsWeekendPauseActive())
   {
      g_StatusText = "WEEKEND OPEN PAUSE";
      g_StatusColor = C_MUTED;
      return;
   }

   //--- Extreme volatility halt - new entries blocked, existing trades still managed
   if(g_VolRegime == VOL_EXTREME)
   {
      g_StatusText = "EXTREME VOLATILITY - ENTRIES PAUSED";
      g_StatusColor = C_RED;
      return;
   }

   //--- Spread guard (percentage based)
   if(!IsSpreadOk())
   {
      double sp = SymbolInfoDouble(_Symbol, SYMBOL_ASK) - SymbolInfoDouble(_Symbol, SYMBOL_BID);
      g_StatusText = "SPREAD TOO WIDE ($"+DoubleToString(sp,2)+")";
      g_StatusColor = C_RED;
      return;
   }

   //--- Cooldown state
   if(g_State == STATE_COOLDOWN)
   {
      int left = (int)(g_StateTimer - TimeCurrent());
      if(left > 0)
      {
         g_StatusText = "COOLDOWN (" + IntegerToString(left) + "s)";
         g_StatusColor = C_GOLD;
         return;
      }
      g_State = STATE_SCANNING;
   }

   //--- SCANNING: evaluate confluence signal
   if(g_State == STATE_SCANNING)
   {
      ENUM_SIGNAL sig = EvaluateConfluence(true);
      if(sig == SIGNAL_NONE)
      {
         g_StatusText  = "SCANNING - BUILDING CONFLUENCE";
         g_StatusColor = C_MUTED;
         return;
      }
      g_State          = STATE_ANALYZING;
      g_PendingSignal  = sig;
      g_AnalysisStart  = TimeCurrent();
      g_AnalysisTicks  = 0;
      g_StatusText     = "SIGNAL DETECTED - ANALYSING";
      g_StatusColor    = C_VIOLET;
      Print("[NovaBTC] Signal=", (sig==SIGNAL_BUY?"BUY":"SELL"), " Score=", g_LastConfluenceScore, "/8 - Entering analysis phase");
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
   g_hMACD     = iMACD(_Symbol, _Period, InpMACDFast, InpMACDSlow, InpMACDSignal, PRICE_CLOSE);
   g_hBB       = iBands(_Symbol, _Period, InpBBPeriod, 0, InpBBDeviation, PRICE_CLOSE);
   g_hHTFEMA   = iMA(_Symbol, InpHTFPeriod, InpHTFEMAPeriod, 0, MODE_EMA, PRICE_CLOSE);

   if(g_hFastEMA==INVALID_HANDLE || g_hSlowEMA==INVALID_HANDLE || g_hTrendEMA==INVALID_HANDLE ||
      g_hRSI==INVALID_HANDLE     || g_hATR==INVALID_HANDLE     || g_hADX==INVALID_HANDLE ||
      g_hMACD==INVALID_HANDLE    || g_hBB==INVALID_HANDLE      || g_hHTFEMA==INVALID_HANDLE)
   {
      Print("[NovaBTC] FAILED: one or more indicator handles invalid.");
      return false;
   }
   return true;
}

void ReleaseIndicators()
{
   int handles[] = {g_hFastEMA, g_hSlowEMA, g_hTrendEMA, g_hRSI, g_hATR, g_hADX, g_hMACD, g_hBB, g_hHTFEMA};
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
//| CONFLUENCE SIGNAL ENGINE  -  7 filters, 9-point max score        |
//|                                                                    |
//| Filters (each worth points toward the total score):              |
//|  1. EMA stack (fast/slow/trend aligned)         - 2 points        |
//|  2. RSI momentum confirmation                    - 1 point        |
//|  3. ADX trend strength                           - 1 point        |
//|  4. MACD histogram direction + growth            - 1 point        |
//|  5. Bollinger Bands expansion + side              - 1 point        |
//|  6. Market structure breakout/proximity          - 1 point        |
//|  7. Higher-timeframe trend alignment             - 1 point        |
//|  8. Volume surge confirmation                    - 1 point        |
//|                                                                    |
//| Max score = 9. Dynamic threshold tightens after loss streaks.    |
//| Momentum exhaustion (RSI extreme + reversal candle) is a HARD    |
//| BLOCK regardless of score - avoids buying tops / selling bottoms.|
//+------------------------------------------------------------------+
ENUM_SIGNAL EvaluateConfluence(bool detectionMode = true)
{
   double fastEMA, slowEMA, trendEMA, rsiVal, adxVal;
   bool   inSqueeze = false;

   //--- EMA stack is the directional anchor - if not aligned, no signal at all
   if(!CheckEMAStack(fastEMA, slowEMA, trendEMA))
   {
      g_LastConfluenceScore = 0;
      return SIGNAL_NONE;
   }
   ENUM_SIGNAL emaSig = (fastEMA > slowEMA && slowEMA > trendEMA) ? SIGNAL_BUY : SIGNAL_SELL;

   //--- Hard block: momentum exhaustion (avoid chasing blow-off tops/bottoms)
   if(CheckMomentumExhaustion(emaSig))
   {
      g_LastConfluenceScore = 0;
      return SIGNAL_NONE;
   }

   int score = 2; // EMA stack = 2 points

   bool rsiPass    = CheckRSI(emaSig, rsiVal);
   bool adxPass    = CheckADX(adxVal);
   bool macdPass   = CheckMACD(emaSig);
   bool bbPass     = CheckBollingerBands(emaSig, inSqueeze);
   bool structPass = CheckMarketStructure(emaSig, !detectionMode);
   bool htfPass    = InpUseHTFFilter    ? CheckHTFTrend(emaSig)   : true;
   bool volPass    = InpUseVolumeFilter ? CheckVolumeSurge()      : true;

   if(rsiPass)    score++;
   if(adxPass)    score++;
   if(macdPass)   score++;
   if(bbPass)     score++;
   if(structPass) score++;
   if(htfPass)    score++;
   if(volPass)    score++;

   // BB squeeze is a hard block regardless of score - ranging markets are skipped
   if(inSqueeze)
   {
      g_LastConfluenceScore = score;
      return SIGNAL_NONE;
   }

   g_LastConfluenceScore = score;

   // Dynamic threshold: tighten after consecutive losses
   int required = 6;                          // out of max 9
   if(g_ConsecLosses >= 2) required = 7;
   if(g_ConsecLosses >= 3) required = 8;

   // In LOW volatility regime, require slightly higher score (less room to run)
   if(g_VolRegime == VOL_LOW) required = MathMin(9, required + 1);

   if(score >= required) return emaSig;
   return SIGNAL_NONE;
}

//--- EMA Stack: fast > slow > trend = bullish; fast < slow < trend = bearish
bool CheckEMAStack(double &fast, double &slow, double &trend)
{
   double f[1], s[1], t[1];
   if(CopyBuffer(g_hFastEMA,  0, 0, 1, f) <= 0) return false;
   if(CopyBuffer(g_hSlowEMA,  0, 0, 1, s) <= 0) return false;
   if(CopyBuffer(g_hTrendEMA, 0, 0, 1, t) <= 0) return false;
   fast = f[0]; slow = s[0]; trend = t[0];
   bool bull = (fast > slow && slow > trend);
   bool bear = (fast < slow && slow < trend);
   return (bull || bear);
}

//--- RSI momentum confirmation
bool CheckRSI(ENUM_SIGNAL sig, double &rsiVal)
{
   double r[1];
   if(CopyBuffer(g_hRSI, 0, 0, 1, r) <= 0) return false;
   rsiVal = r[0];
   if(sig == SIGNAL_BUY)  return (rsiVal > 50.0 && rsiVal < InpRSIOverbought);
   if(sig == SIGNAL_SELL) return (rsiVal < 50.0 && rsiVal > InpRSIOversold);
   return false;
}

//--- ADX trend strength
bool CheckADX(double &adxVal)
{
   double adx[1];
   if(CopyBuffer(g_hADX, 0, 0, 1, adx) <= 0) return false;
   adxVal = adx[0];
   return (adxVal >= InpADXMinStrength);
}

//--- MACD histogram: direction + growth
bool CheckMACD(ENUM_SIGNAL sig)
{
   double hist[2];
   if(CopyBuffer(g_hMACD, 2, 0, 2, hist) < 2) return false;
   double current  = hist[0];
   double previous = hist[1];
   bool rising  = (current > previous);
   bool falling = (current < previous);
   if(sig == SIGNAL_BUY)  return (current > 0.0 && rising);
   if(sig == SIGNAL_SELL) return (current < 0.0 && falling);
   return false;
}

//--- Bollinger Bands: hard-block squeeze, confirm direction on expansion
bool CheckBollingerBands(ENUM_SIGNAL sig, bool &inSqueeze)
{
   double upper[1], lower[1], mid[1];
   if(CopyBuffer(g_hBB, 1, 0, 1, upper) <= 0) return false;
   if(CopyBuffer(g_hBB, 2, 0, 1, lower) <= 0) return false;
   if(CopyBuffer(g_hBB, 0, 0, 1, mid)   <= 0) return false;

   double width = upper[0] - lower[0];
   double price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double squeezeThresh = price * InpBBSqueezeRatio;

   if(width < squeezeThresh) { inSqueeze = true; return false; }
   inSqueeze = false;

   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(sig == SIGNAL_BUY)  return (bid > mid[0]);
   if(sig == SIGNAL_SELL) return (bid < mid[0]);
   return false;
}

//--- Market structure: breakout (strict) or proximity (relaxed, used during analysis)
bool CheckMarketStructure(ENUM_SIGNAL sig, bool proximityMode = false)
{
   int highBar = iHighest(_Symbol, _Period, MODE_HIGH, InpStructureBars, 1);
   int lowBar  = iLowest(_Symbol,  _Period, MODE_LOW,  InpStructureBars, 1);
   if(highBar < 0 || lowBar < 0) return false;

   double swingHigh = iHigh(_Symbol, _Period, highBar);
   double swingLow  = iLow(_Symbol,  _Period, lowBar);
   double bid       = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask       = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double atr       = GetATR();
   double buffer    = atr * 0.5;

   if(proximityMode)
   {
      if(sig == SIGNAL_BUY)  return (ask >= swingHigh - buffer);
      if(sig == SIGNAL_SELL) return (bid <= swingLow  + buffer);
   }
   else
   {
      if(sig == SIGNAL_BUY)  return (ask > swingHigh);
      if(sig == SIGNAL_SELL) return (bid < swingLow);
   }
   return false;
}

//--- Higher timeframe trend alignment - entry signal must agree with the
//    higher-TF EMA direction, filters out counter-trend scalps
bool CheckHTFTrend(ENUM_SIGNAL sig)
{
   double htf[1];
   if(CopyBuffer(g_hHTFEMA, 0, 0, 1, htf) <= 0) return false;
   double price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(sig == SIGNAL_BUY)  return (price > htf[0]);
   if(sig == SIGNAL_SELL) return (price < htf[0]);
   return false;
}

//--- Volume surge: current bar's tick volume must exceed the rolling average
//    by the configured multiple - crypto moves are often volume-led
bool CheckVolumeSurge()
{
   if(g_AvgVolume <= 0.0) return true; // not enough data yet, don't block
   long vol[1];
   if(CopyTickVolume(_Symbol, _Period, 0, 1, vol) <= 0) return true;
   return ((double)vol[0] >= g_AvgVolume * InpVolumeSurgeMult);
}

//--- Momentum exhaustion: blocks entries when RSI is at an extreme AND the
//    most recent candle shows a reversal wick - avoids buying blow-off tops
//    or selling capitulation bottoms, a common crypto-scalper trap
bool CheckMomentumExhaustion(ENUM_SIGNAL sig)
{
   double rsi[1];
   if(CopyBuffer(g_hRSI, 0, 0, 1, rsi) <= 0) return false;

   double openP  = iOpen(_Symbol, _Period, 1);
   double closeP = iClose(_Symbol, _Period, 1);
   double highP  = iHigh(_Symbol, _Period, 1);
   double lowP   = iLow(_Symbol, _Period, 1);
   double range  = highP - lowP;
   if(range <= 0.0) return false;

   if(sig == SIGNAL_BUY && rsi[0] > 78.0)
   {
      // Bearish reversal wick: upper wick > 40% of candle range = exhaustion
      double upperWick = highP - MathMax(openP, closeP);
      if(upperWick > range * 0.40) return true;
   }
   if(sig == SIGNAL_SELL && rsi[0] < 22.0)
   {
      double lowerWick = MathMin(openP, closeP) - lowP;
      if(lowerWick > range * 0.40) return true;
   }
   return false;
}

//+------------------------------------------------------------------+
//| VOLATILITY REGIME CLASSIFIER                                      |
//| Builds a rolling buffer of ATR values and classifies the CURRENT |
//| ATR by its percentile rank within that buffer. This adapts to    |
//| BTC's regime shifts far better than a fixed ATR threshold would, |
//| since "high volatility" for BTC means something different in    |
//| a calm month versus a violent one.                               |
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| VOLATILITY REGIME CLASSIFIER                                      |
//| FIX: sampled once per CLOSED BAR, not once per second. ATR on a   |
//| given timeframe only changes meaningfully at bar close - sampling |
//| every second filled the rolling buffer with near-duplicate values |
//| of the same 1-2 bars, making any genuine new bar look like a     |
//| 100th-percentile "EXTREME" reading purely from lack of variety   |
//| in the historical sample. New-bar gating fixes this at the root. |
//+------------------------------------------------------------------+
void UpdateVolatilityRegime()
{
   // New-bar gate: only sample once per closed bar on the entry timeframe
   static datetime lastBarTime = 0;
   datetime curBarTime = (datetime)SeriesInfoInteger(_Symbol, _Period, SERIES_LASTBAR_DATE);
   if(curBarTime == lastBarTime) return; // same bar as last sample - skip
   lastBarTime = curBarTime;

   double curATR = GetATR();
   if(curATR <= 0.0) return;

   // Shift buffer and insert newest value at the front
   int n = ArraySize(g_ATRHistory);
   for(int i = n-1; i > 0; i--) g_ATRHistory[i] = g_ATRHistory[i-1];
   g_ATRHistory[0] = curATR;

   // Count how many HISTORICAL samples (excluding the one we just inserted)
   // are below current ATR -> percentile. Starting the loop at i=1 avoids
   // the self-comparison bug where curATR was always counted against itself.
   int validCount = 0, belowCount = 0;
   for(int i = 1; i < n; i++)
   {
      if(g_ATRHistory[i] <= 0.0) continue;
      validCount++;
      if(g_ATRHistory[i] <= curATR) belowCount++;
   }
   if(validCount < 10) { g_VolPercentile = 50.0; g_VolRegime = VOL_NORMAL; return; }

   g_VolPercentile = ((double)belowCount / validCount) * 100.0;

   if(g_VolPercentile >= InpVolExtremePctile)      g_VolRegime = VOL_EXTREME;
   else if(g_VolPercentile >= InpVolHighPercentile) g_VolRegime = VOL_HIGH;
   else if(g_VolPercentile <= InpVolLowPercentile)  g_VolRegime = VOL_LOW;
   else                                              g_VolRegime = VOL_NORMAL;
}

string VolRegimeToString(ENUM_VOL_REGIME r)
{
   switch(r)
   {
      case VOL_LOW:     return "LOW";
      case VOL_NORMAL:  return "NORMAL";
      case VOL_HIGH:    return "HIGH";
      case VOL_EXTREME: return "EXTREME";
      default:          return "?";
   }
}

//+------------------------------------------------------------------+
//| VOLUME AVERAGE TRACKING                                           |
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| VOLUME AVERAGE TRACKING                                           |
//| FIX: same new-bar gating issue as the volatility regime - without |
//| it, the same closed bar's volume got re-added to the rolling      |
//| average up to ~300 times per bar (once per second), drowning out  |
//| genuine bar-to-bar variety and making the average nearly equal to |
//| whatever the most recent single bar happened to be.              |
//+------------------------------------------------------------------+
void UpdateVolumeAverage()
{
   static datetime lastVolBarTime = 0;
   datetime curBarTime = (datetime)SeriesInfoInteger(_Symbol, _Period, SERIES_LASTBAR_DATE);
   if(curBarTime == lastVolBarTime) return; // same bar as last sample - skip
   lastVolBarTime = curBarTime;

   long vol[1];
   if(CopyTickVolume(_Symbol, _Period, 1, 1, vol) <= 0) return; // closed bar only

   int cap = InpVolumeAvgPeriod * 20; // smoothing cap
   g_AvgVolume = (g_AvgVolume * g_VolumeSamples + (double)vol[0]) / (double)(g_VolumeSamples + 1);
   g_VolumeSamples = MathMin(g_VolumeSamples + 1, cap);
}

//+------------------------------------------------------------------+
//| DYNAMIC LOT SIZING  (broker-agnostic, % risk based)              |
//| slDistancePrice = SL distance expressed as an absolute PRICE     |
//| difference (e.g. $350 for a BTC trade), not points - this avoids |
//| any point/pip ambiguity across different broker BTC contracts.   |
//+------------------------------------------------------------------+
double CalculateLotSize(double slDistancePrice)
{
   double balance    = AccountInfoDouble(ACCOUNT_BALANCE);
   double riskPct     = GetRiskAdjustedPercent();
   double riskAmount  = balance * (riskPct / 100.0);

   double tickVal  = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   if(tickSize <= 0.0) return SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);

   // Dollar cost of holding 1.0 lot across the SL distance
   double slCostPerLot = (slDistancePrice / tickSize) * tickVal;
   if(slCostPerLot <= 0.0) return SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);

   double lot  = riskAmount / slCostPerLot;
   double minV = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxV = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);

   lot = MathMax(minV, MathMin(maxV, MathFloor(lot / step) * step));
   return lot;
}

//--- Adjust risk % using BOTH loss-streak AND equity-curve drawdown
//    This is broader than the GOLD EA's streak-only approach - it reacts
//    to drawdown from the all-time equity peak, not just recent trades.
double GetRiskAdjustedPercent()
{
   double pct = InpRiskPercent;

   if(g_ConsecLosses >= InpMaxLossStreak)
      pct = InpRiskPercent * 0.5;
   else if(g_ConsecWins >= InpWinStreakBoost)
      pct = MathMin(InpRiskPercent * 1.25, 2.0);

   // Equity-curve drawdown scaling: the deeper the drawdown from peak,
   // the smaller the next trade - this compounds with loss-streak sizing
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   if(g_EquityPeak > 0.0)
   {
      double ddPct = ((g_EquityPeak - equity) / g_EquityPeak) * 100.0;
      if(ddPct > 8.0)       pct *= 0.5;   // deep drawdown - half size
      else if(ddPct > 4.0)  pct *= 0.75;  // moderate drawdown - reduce
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

   ENUM_SIGNAL current = EvaluateConfluence(false); // validation mode - relaxed structure check
   if(current != g_PendingSignal)
   {
      Print("[NovaBTC] Signal reversed during analysis - invalidated. Was=",
            (g_PendingSignal==SIGNAL_BUY?"BUY":"SELL"), " Now=",
            (current==SIGNAL_BUY?"BUY":(current==SIGNAL_SELL?"SELL":"NONE")));
      g_State = STATE_SCANNING;
      return;
   }

   if(elapsed >= InpAnalysisMinSec && g_AnalysisTicks >= InpAnalysisMinTicks)
   {
      // Final-moment re-validation before committing capital
      ENUM_SIGNAL finalCheck = EvaluateConfluence(false);
      if(finalCheck != g_PendingSignal)
      {
         Print("[NovaBTC] Final-moment confluence check failed. Aborting.");
         g_StateTimer = TimeCurrent() + 10;
         g_State      = STATE_COOLDOWN;
         return;
      }
      if(g_LastConfluenceScore < 6)
      {
         Print("[NovaBTC] Score too low at execution (", g_LastConfluenceScore, "/9). Aborting.");
         g_StateTimer = TimeCurrent() + 10;
         g_State      = STATE_COOLDOWN;
         return;
      }
      PrintFormat("[NovaBTC] Analysis complete. Score=%d/9 Elapsed=%ds Ticks=%d. Firing.",
                  g_LastConfluenceScore, elapsed, g_AnalysisTicks);
      ExecuteEntry(g_PendingSignal);
      g_StateTimer = TimeCurrent() + 10;
      g_State      = STATE_COOLDOWN;
   }
}

//+------------------------------------------------------------------+
//| TRADE EXECUTION                                                    |
//+------------------------------------------------------------------+
void ExecuteEntry(ENUM_SIGNAL sig)
{
   if(!IsSpreadOk()) { Print("[NovaBTC] Spread too wide at execution - aborted."); return; }

   int    digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   double atr    = GetATR();
   double price  = (sig == SIGNAL_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                       : SymbolInfoDouble(_Symbol, SYMBOL_BID);

   //--- SL distance: ATR-based but bounded by % of price (floor and ceiling)
   //    This is more robust than point-based bounds for an asset whose
   //    price level (and therefore point value) can vary by broker/contract.
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

   double lot = CalculateLotSize(slDistance);

   PrintFormat("[NovaBTC] ENTRY %s | Lot=%.2f Price=%.2f SL=%.2f TP=%.2f SLdist=$%.2f ATR=%.2f VolRegime=%s",
               (sig==SIGNAL_BUY?"BUY":"SELL"), lot, price, sl, tp, slDistance, atr, VolRegimeToString(g_VolRegime));

   bool ok = (sig == SIGNAL_BUY) ? g_Trade.Buy(lot, _Symbol, price, sl, tp, InpTradeComment)
                                 : g_Trade.Sell(lot, _Symbol, price, sl, tp, InpTradeComment);
   if(ok)
   {
      g_DailyTrades++;
      ResetTradeState();
      Sleep(100);
      CacheTradeEntry();
      g_StatusText  = (sig==SIGNAL_BUY) ? "IN TRADE - LONG" : "IN TRADE - SHORT";
      g_StatusColor = C_GREEN;
   }
   else
   {
      Print("[NovaBTC] Order FAILED. RetCode=", g_Trade.ResultRetcode(), " ", g_Trade.ResultRetcodeDescription());
   }
}

//+------------------------------------------------------------------+
//| SMART EXIT SYSTEM  -  fully R-multiple based                      |
//|                                                                    |
//| Every threshold below (breakeven, trailing, peak-lock, partial)  |
//| is expressed as a fraction of g_EntryRiskUSD - the ACTUAL dollar  |
//| risk taken on THIS specific trade. This guarantees consistent    |
//| behaviour whether the SL distance is $50 or $800 on a given      |
//| BTC trade, rather than firing at an arbitrary fixed point count. |
//+------------------------------------------------------------------+

//--- Cache entry state when a new position is opened
void CacheTradeEntry()
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

      // Real dollar value of 1R for THIS trade, from the actual SL distance and lot size
      double slDistPrice = MathAbs(g_EntryPrice - g_EntrySLPrice);
      double tickVal      = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
      double tickSize     = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
      if(tickSize > 0.0)
         g_EntryRiskUSD = (slDistPrice / tickSize) * tickVal * g_Pos.Volume();
      else
         g_EntryRiskUSD = 0.01;

      if(g_EntryRiskUSD <= 0.0) g_EntryRiskUSD = 0.01; // safety floor against div/0

      PrintFormat("[CacheEntry] Entry=%.2f SL=%.2f SLdist=$%.2f Risk(1R)=$%.2f",
                  g_EntryPrice, g_EntrySLPrice, slDistPrice, g_EntryRiskUSD);
      break;
   }
}

//--- Reset all trade state after a position closes
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
}

//+------------------------------------------------------------------+
//| MASTER TRADE MANAGER - called every tick while position is open  |
//+------------------------------------------------------------------+
void ManageOpenTrade()
{
   if(!IsPositionOpen()) { ResetTradeState(); return; }

   double pnl = GetFloatingPnL();
   if(pnl > g_PeakProfit) g_PeakProfit = pnl;

   string rStr = (g_EntryRiskUSD > 0) ? " ("+DoubleToString(pnl/g_EntryRiskUSD,2)+"R)" : "";
   string pnlStr = (pnl>=0?"+$":"-$") + DoubleToString(MathAbs(pnl),2) + rStr
                   + "  Peak:+$" + DoubleToString(g_PeakProfit,2);
   g_StatusText  = "TRADE RUNNING " + pnlStr;
   g_StatusColor = (pnl >= 0) ? C_GREEN : C_RED;

   //--- Priority 1: Peak-profit lock
   if(InpUsePeakLock) CheckPeakProfitLock(pnl);
   if(!IsPositionOpen()) return;

   //--- Priority 2: Partial close at TP1
   if(InpUsePartialClose && !g_PartialClosed) CheckPartialClose(pnl);
   if(!IsPositionOpen()) return;

   //--- Priority 3: Breakeven
   CheckBreakeven();
   if(!IsPositionOpen()) return;

   //--- Priority 4: ATR trailing SL
   if(InpUseTrailing) CheckATRTrailing();

   //--- Priority 5: Daily profit target via floating PnL
   EvaluateFloatingPnL(pnl);
}

//+------------------------------------------------------------------+
//| PEAK-PROFIT LOCK  (R-multiple based)                              |
//+------------------------------------------------------------------+
void CheckPeakProfitLock(double pnl)
{
   double oneR = g_EntryRiskUSD;
   if(oneR <= 0.0) return;

   double activateLevel = oneR * InpPeakLockActivateR;
   if(g_PeakProfit < activateLevel) return; // not armed yet

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

//+------------------------------------------------------------------+
//| PARTIAL CLOSE AT TP1  (R-multiple based)                          |
//+------------------------------------------------------------------+
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

//+------------------------------------------------------------------+
//| BREAKEVEN  (R-multiple based)                                     |
//+------------------------------------------------------------------+
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

//+------------------------------------------------------------------+
//| ATR TRAILING STOP  (R-multiple activation, floor at breakeven)   |
//+------------------------------------------------------------------+
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

      // Floor: once breakeven is set, trailing can never move SL below it
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

//+------------------------------------------------------------------+
//| DAILY PNL TARGET CHECK                                            |
//+------------------------------------------------------------------+
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
//| DAILY STATS SYNCHRONISATION                                       |
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

   datetime scanFrom = dayStart - 7*86400; // 7 days back for multi-day streak tracking
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
   for(int i = PositionsTotal()-1; i >= 0; i--)
      if(g_Pos.SelectByIndex(i) && g_Pos.Magic()==InpMagicNumber && g_Pos.Symbol()==_Symbol)
         g_Trade.PositionClose(g_Pos.Ticket());
   g_StateTimer = TimeCurrent() + 30; // BTC cooldown slightly longer - avoid immediate re-entry into noise
   g_State      = STATE_COOLDOWN;
   ResetTradeState();
}

bool IsMarketOpen()
{
   ENUM_SYMBOL_TRADE_MODE m = (ENUM_SYMBOL_TRADE_MODE)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_MODE);
   return (m == SYMBOL_TRADE_MODE_FULL || m == SYMBOL_TRADE_MODE_LONGONLY || m == SYMBOL_TRADE_MODE_SHORTONLY);
}

//--- Percentage-based spread filter: crypto spreads scale with price level,
//    so a fixed-point ceiling makes no sense (a $20 spread is tight at
//    $90,000 BTC but enormous at $9,000 BTC)
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

//--- All-time equity drawdown from peak - broader safety net than the
//    daily-only check, catches slow multi-day bleed
bool IsDrawdownLimitHit()
{
   if(g_EquityPeak <= 0.0) return false;
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   double ddPct  = ((g_EquityPeak - equity) / g_EquityPeak) * 100.0;
   return (ddPct >= InpMaxDrawdownPct);
}

//--- Weekend / low-liquidity pause: many brokers show a weekly reopen
//    candle with abnormal spread and gap risk - skip new entries briefly
bool IsWeekendPauseActive()
{
   MqlDateTime dt; TimeToStruct(TimeGMT(), dt);
   // Weekly reopen is typically Sunday late evening / Monday early UTC for
   // brokers that DO impose a weekly schedule on crypto CFDs
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

//====================================================================
// NOVA BTC RICH DASHBOARD ENGINE
//
// Layout (top to bottom, width=330px):
//   [HEADER]            - EA name, symbol, timeframe, version
//   [MARKET INFO]       - Bid/Ask, Spread%, ATR, Volatility regime
//   [SIGNAL ENGINE]     - EMA stack, RSI, ADX, MACD, BB, HTF, Volume
//   [AI DECISION]       - Status, confidence bar, score display
//   [FINAL DECISION]    - Large coloured BUY/SELL/HOLD block
//   [OPEN POSITION]     - Live R-multiple, peak profit, SL/TP
//   [ACCOUNT INFO]      - Balance, equity, drawdown, win rates, streak
//   [RISK REGIME BAR]   - Low/Normal/High/Extreme volatility pills
//====================================================================

//====================================================================
// NOVA BTC COMPACT DASHBOARD ENGINE
//
// Redesigned for screen-fit: total height ~470px (was 695px).
// Compression techniques used vs the original:
//   - Row pitch reduced from 16-18px to 13px
//   - Section header bars reduced from 16px to 13px
//   - Signal engine merged HTF/Volume/Score into 2 rows instead of 3
//   - Open Position panel condensed to 3 rows instead of 5
//   - Account Info condensed to 4 rows instead of 5
//   - Volatility regime pills row removed (regime already shown in
//     Market Info as a pill - no need to duplicate it as a 4-way bar)
//====================================================================

#define DW  330
#define COL 130

void RenderDashboard()
{
   int X = InpDashX;
   int Y = InpDashY;
   int W = DW;
   int y = Y;

   DrawRect("SHELL", X, Y, W, 478, C_BG, C_BORDER, 2);

   //----------------------------------------------------------------
   // HEADER (28px)
   //----------------------------------------------------------------
   DrawRect("HDR_BG", X+2, y+2, W-4, 26, C_HEADER, C_BORDER, 1);
   DrawLabel("HDR_IC",  X+6,     y+4,  "NOVA BTC SCALPER AI",      C_CYAN,  8, "Arial Black");
   DrawLabel("HDR_SYM", X+W-95,  y+4,  _Symbol,                     C_GOLD,  9, "Impact");
   DrawLabel("HDR_TF",  X+W-50,  y+15, TimeframeToString(_Period),  C_MUTED, 7, "Arial");
   DrawLabel("HDR_VER", X+6,     y+15, EA_VERSION+" CRYPTO ENGINE", C_MUTED, 7, "Arial");
   y += 29;

   //----------------------------------------------------------------
   // MARKET INFO (13 hdr + 56 body = 69px)
   //----------------------------------------------------------------
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
   DrawLabel("L_VOLR", X+6,      y+29, "VOL",       C_MUTED, 7, "Arial");
   DrawRect("VR_PILL", X+28,     y+28, 62, 12, C_PANEL2, C_BORDER2, 1);
   DrawLabel("V_VOLR", X+31,     y+29, "NORMAL",    C_BLUE,  7, "Arial Bold");
   DrawLabel("L_VPCT", X+W/2+2,  y+29, "Pctl",      C_MUTED, 7, "Arial");
   DrawLabel("V_VPCT", X+W/2+30, y+29, "50%",       C_WHITE, 7, "Arial Bold");
   DrawLabel("L_DRD",  X+6,      y+42, "DD",        C_MUTED, 7, "Arial");
   DrawLabel("V_DRD",  X+26,     y+42, "0.00%",     C_WHITE, 7, "Arial Bold");
   DrawLabel("L_VOL2", X+W/2+2,  y+42, "VOL.SURGE", C_MUTED, 7, "Arial");
   DrawLabel("V_VOL2", X+W/2+58, y+42, "-",         C_GREEN, 7, "Arial Bold");
   y += 58;

   //----------------------------------------------------------------
   // CONFLUENCE SIGNAL ENGINE (13 hdr + 90 body = 103px)
   //----------------------------------------------------------------
   DrawRect("SE_HDR", X+2, y, W-4, 13, C_SECTION_HDR, C_BORDER2, 1);
   DrawLabel("SE_TIT", X+6, y+2, "SIGNAL ENGINE (9pt)", C_ORANGE, 7, "Arial Black");
   y += 14;

   DrawRect("SE_BG", X+2, y, W-4, 90, C_PANEL, C_BORDER2, 1);
   DrawLabel("L_EF",   X+6,      y+3,  "EMA"+IntegerToString(InpFastEMAPeriod), C_MUTED, 7, "Arial");
   DrawLabel("V_EF",   X+38,     y+3,  "0.00",       C_CYAN,  8, "Arial Bold");
   DrawLabel("L_ES",   X+W/2+2,  y+3,  "EMA"+IntegerToString(InpSlowEMAPeriod), C_MUTED, 7, "Arial");
   DrawLabel("V_ES",   X+W/2+30, y+3,  "0.00",       C_CYAN,  8, "Arial Bold");
   DrawLabel("L_RSI",  X+6,      y+16, "RSI",        C_MUTED, 7, "Arial");
   DrawLabel("V_RSI",  X+30,     y+16, "0.0",        C_WHITE, 8, "Arial Bold");
   DrawRect("BB_PILL", X+W/2+2,  y+15, 66, 12, C_HOLD_BG, C_BORDER2, 1);
   DrawLabel("V_BBP",  X+W/2+6,  y+16, "RANGE",      C_GOLD,  7, "Arial Bold");
   DrawLabel("L_ET",   X+6,      y+29, "EMA"+IntegerToString(InpTrendEMAPeriod), C_MUTED, 7, "Arial");
   DrawLabel("V_ET",   X+38,     y+29, "0.00",       C_WHITE, 8, "Arial Bold");
   DrawLabel("L_ADX",  X+W/2+2,  y+29, "ADX",        C_MUTED, 7, "Arial");
   DrawLabel("V_ADX",  X+W/2+26, y+29, "0.0",        C_WHITE, 8, "Arial Bold");
   DrawLabel("L_MCD",  X+6,      y+42, "MACD",       C_MUTED, 7, "Arial");
   DrawLabel("V_MCD",  X+38,     y+42, "0.00",       C_WHITE, 8, "Arial Bold");
   DrawLabel("L_STR",  X+W/2+2,  y+42, "Struct",     C_MUTED, 7, "Arial");
   DrawLabel("V_STR",  X+W/2+42, y+42, "-",          C_WHITE, 7, "Arial Bold");
   DrawLabel("L_HTF",  X+6,      y+55, "HTF",        C_MUTED, 7, "Arial");
   DrawLabel("V_HTF",  X+30,     y+55, "-",          C_WHITE, 7, "Arial Bold");
   DrawLabel("L_VSG",  X+W/2+2,  y+55, "VolSrg",     C_MUTED, 7, "Arial");
   DrawLabel("V_VSG",  X+W/2+42, y+55, "-",          C_WHITE, 7, "Arial Bold");
   DrawLabel("L_SCR",  X+6,      y+68, "SCORE",      C_MUTED, 7, "Arial");
   DrawLabel("V_SCR",  X+40,     y+68, "0/9",        C_CYAN,  8, "Arial Bold");
   DrawRect("DEC_BAR", X+2, y+78, W-4, 12, C_HOLD_BG, C_BORDER2, 1);
   DrawLabel("V_DEC",  X+W/2-36, y+79, "Decision: HOLD", C_GOLD, 7, "Arial Black");
   y += 92;

   //----------------------------------------------------------------
   // AI DECISION ENGINE (13 hdr + 44 body = 57px)
   //----------------------------------------------------------------
   DrawRect("AI_HDR", X+2, y, W-4, 13, C_SECTION_HDR, C_BORDER2, 1);
   DrawLabel("AI_TIT", X+6, y+2, "AI DECISION ENGINE", C_ORANGE, 7, "Arial Black");
   y += 14;

   DrawRect("AI_BG", X+2, y, W-4, 44, C_PANEL, C_BORDER2, 1);
   DrawLabel("L_AIST",  X+6,  y+3,  "STATUS",  C_MUTED, 7, "Arial");
   DrawLabel("V_AIST",  X+50, y+3,  "BOOTING", C_CYAN,  7, "Arial Black");
   DrawLabel("AI_DOT",  X+W-14, y+3, "*",       C_GOLD,  10, "Arial Black");
   DrawLabel("L_AILD",  X+6,  y+16, "LAST",    C_MUTED, 7, "Arial");
   DrawLabel("V_AILD",  X+W-40,y+16, "HOLD",    C_GOLD,  7, "Arial Bold");
   DrawLabel("L_AISC",  X+6,  y+29, "CONF",    C_MUTED, 7, "Arial");
   DrawRect("CONF_BG",  X+60, y+30, 150, 10, C_PANEL2,  C_BORDER2, 1);
   DrawRect("CONF_FG",  X+60, y+30, 30,  10, C_GOLD,    clrNONE,   0);
   DrawLabel("V_AISC",  X+216,y+29, "LOW",     C_GOLD,  7, "Arial Bold");
   y += 46;

   //----------------------------------------------------------------
   // FINAL DECISION (13 hdr + 26 block + 12 sub = 51px)
   //----------------------------------------------------------------
   DrawRect("FD_HDR", X+2, y, W-4, 13, C_SECTION_HDR, C_BORDER2, 1);
   DrawLabel("FD_TIT", X+6, y+2, "FINAL DECISION", C_ORANGE, 7, "Arial Black");
   y += 14;

   DrawRect("FD_BG",  X+2, y, W-4, 26, C_HOLD_BG, C_BORDER, 2);
   DrawLabel("V_FD",  X+W/2-20, y+5, "HOLD", C_GOLD, 12, "Arial Black");
   y += 28;

   DrawRect("FD_SUB", X+2, y, W-4, 12, C_PANEL2, C_BORDER2, 1);
   DrawLabel("L_FDS1", X+6,      y+1, "SIG:",    C_MUTED, 7, "Arial");
   DrawLabel("V_FDS1", X+34,     y+1, "HOLD",    C_GOLD,  7, "Arial Bold");
   DrawLabel("L_FDS2", X+W/2+2,  y+1, "ENG:",    C_MUTED, 7, "Arial");
   DrawLabel("V_FDS2", X+W/2+30, y+1, "SCANNING", C_GOLD, 7, "Arial Bold");
   y += 14;

   //----------------------------------------------------------------
   // OPEN POSITION (13 hdr + 42 body = 55px) - condensed to 3 rows
   //----------------------------------------------------------------
   DrawRect("OP_HDR", X+2, y, W-4, 13, C_SECTION_HDR, C_BORDER2, 1);
   DrawLabel("OP_TIT", X+6,    y+2, "OPEN POSITION", C_ORANGE, 7, "Arial Black");
   DrawLabel("OP_CNT", X+W-44, y+2, "0 open",         C_MUTED,  7, "Arial");
   y += 14;

   DrawRect("OP_BG", X+2, y, W-4, 42, C_PANEL, C_BORDER2, 1);
   DrawLabel("L_OTYP", X+6,      y+3,  "TYPE",  C_MUTED, 7, "Arial");
   DrawLabel("V_OTYP", X+32,     y+3,  "---",   C_MUTED, 8, "Arial Bold");
   DrawLabel("L_OLOT", X+W/2-10, y+3,  "LOT",   C_MUTED, 7, "Arial");
   DrawLabel("V_OLOT", X+W/2+14, y+3,  "---",   C_MUTED, 8, "Arial Bold");
   DrawLabel("L_OOPN", X+6,      y+16, "OPEN",  C_MUTED, 7, "Arial");
   DrawLabel("V_OOPN", X+34,     y+16, "---",   C_WHITE, 7, "Arial Bold");
   DrawLabel("L_OSLT", X+W/2-10, y+16, "SL/TP", C_MUTED, 7, "Arial");
   DrawLabel("V_OSLT", X+W/2+24, y+16, "--- / ---", C_WHITE, 7, "Arial Bold");
   DrawLabel("L_OPNL", X+6,      y+29, "P&L",   C_MUTED, 7, "Arial");
   DrawLabel("V_OPNL", X+30,     y+29, "+$0.00 (0.0R)", C_GREEN, 7, "Arial Bold");
   DrawLabel("L_OPK",  X+W/2+30, y+29, "PK",    C_MUTED, 7, "Arial");
   DrawLabel("V_OPK",  X+W/2+48, y+29, "+$0.00", C_CYAN, 7, "Arial Bold");
   y += 44;

   //----------------------------------------------------------------
   // ACCOUNT INFO (13 hdr + 56 body = 69px) - condensed to 4 rows
   //----------------------------------------------------------------
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
   DrawLabel("V_CONF", X+W/2+2,  y+42, "Score:0/9", C_CYAN, 7, "Consolas");
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

   // Volatility regime pill
   string volStr = VolRegimeToString(g_VolRegime);
   color volClr = (g_VolRegime==VOL_EXTREME) ? C_RED : (g_VolRegime==VOL_HIGH) ? C_ORANGE
                  : (g_VolRegime==VOL_LOW) ? C_BLUE : C_GREEN;
   SetLabel("V_VOLR", volStr, volClr);
   string vrPillN = DASH_PREFIX+"VR_PILL";
   if(ObjectFind(0,vrPillN)>=0) ObjectSetInteger(0,vrPillN,OBJPROP_BGCOLOR,
      (g_VolRegime==VOL_EXTREME)?C_SELL_BG:(g_VolRegime==VOL_HIGH)?C_HOLD_BG:C_PANEL2);
   SetLabel("V_VPCT", DoubleToString(g_VolPercentile,0)+"%", C_WHITE);

   bool volOk = InpUseVolumeFilter ? CheckVolumeSurge() : true;
   SetLabel("V_VOL2", IsMarketOpen() ? (volOk?"SURGE":"NORMAL") : "HALT",
            IsMarketOpen() ? (volOk?C_GREEN:C_MUTED) : C_RED);
   // Note: market is 24/7 for crypto - no separate session label in compact layout

   double eqDD = 0.0;
   if(g_EquityPeak > 0.0)
      eqDD = ((g_EquityPeak - AccountInfoDouble(ACCOUNT_EQUITY)) / g_EquityPeak) * 100.0;
   color cDD = (eqDD > InpMaxDrawdownPct*0.66) ? C_RED : (eqDD > InpMaxDrawdownPct*0.33) ? C_GOLD : C_WHITE;
   SetLabel("V_DRD", DoubleToString(eqDD,2)+"%", cDD);

   //--- Signal Engine indicators
   double fast[1], slow[1], trend[1], rsi[1], adx[1], hist[2], htf[1];
   if(CopyBuffer(g_hFastEMA,  0, 0, 1, fast)  > 0) SetLabel("V_EF",  DoubleToString(fast[0],  2), C_CYAN);
   if(CopyBuffer(g_hSlowEMA,  0, 0, 1, slow)  > 0) SetLabel("V_ES",  DoubleToString(slow[0],  2), C_CYAN);
   if(CopyBuffer(g_hTrendEMA, 0, 0, 1, trend) > 0) SetLabel("V_ET",  DoubleToString(trend[0], 2), C_WHITE);
   if(CopyBuffer(g_hRSI,      0, 0, 1, rsi)   > 0)
   {
      color cR = (rsi[0]>InpRSIOverbought||rsi[0]<InpRSIOversold) ? C_RED : C_WHITE;
      SetLabel("V_RSI", DoubleToString(rsi[0], 1), cR);
   }
   if(CopyBuffer(g_hADX, 0, 0, 1, adx) > 0)
   {
      color cA = (adx[0] >= InpADXMinStrength) ? C_GREEN : C_GOLD;
      SetLabel("V_ADX", DoubleToString(adx[0], 1), cA);
   }
   if(CopyBuffer(g_hMACD, 2, 0, 2, hist) >= 2)
   {
      color cM = (hist[0] > 0) ? C_GREEN : C_RED;
      SetLabel("V_MCD", DoubleToString(hist[0], 2), cM);
   }

   double upper[1], lower[1], mid[1];
   if(CopyBuffer(g_hBB,1,0,1,upper)>0 && CopyBuffer(g_hBB,2,0,1,lower)>0 && CopyBuffer(g_hBB,0,0,1,mid)>0)
   {
      bool squeeze = (upper[0]-lower[0]) < bid * InpBBSqueezeRatio;
      SetLabel("V_BBP", squeeze ? "SQUEEZE" : "EXPAND", squeeze ? C_RED : C_GREEN);
      string pillN = DASH_PREFIX+"BB_PILL";
      if(ObjectFind(0,pillN)>=0) ObjectSetInteger(0,pillN,OBJPROP_BGCOLOR, squeeze ? C_SELL_BG : C_BUY_BG);
   }

   ENUM_SIGNAL sig = EvaluateConfluence(true);
   bool structOk = CheckMarketStructure(sig, false);
   SetLabel("V_STR", structOk ? "BREAK" : "HOLD", structOk ? C_GREEN : C_MUTED);

   if(InpUseHTFFilter && CopyBuffer(g_hHTFEMA,0,0,1,htf) > 0)
   {
      bool htfBull = (bid > htf[0]);
      SetLabel("V_HTF", htfBull ? "BULLISH" : "BEARISH", htfBull ? C_GREEN : C_RED);
   }
   else SetLabel("V_HTF", "OFF", C_MUTED);

   bool vSurge = InpUseVolumeFilter ? CheckVolumeSurge() : true;
   SetLabel("V_VSG", vSurge ? "YES" : "NO", vSurge ? C_GREEN : C_MUTED);

   SetLabel("V_SCR", IntegerToString(g_LastConfluenceScore)+"/9", C_CYAN);

   //--- Decision bar + Final Decision
   string decTxt; color decClr; color decBg; string aiTxt;

   if(g_State == STATE_ANALYZING)
   {
      int elapsed = (int)(TimeCurrent() - g_AnalysisStart);
      decTxt = "Decision: ANALYSING ("+IntegerToString(elapsed)+"s)";
      decClr = C_VIOLET; decBg = C_PANEL2; aiTxt = "ANALYSING";
   }
   else if(sig == SIGNAL_BUY)
   {
      decTxt = "Decision: BUY"; decClr = C_GREEN; decBg = C_BUY_BG; aiTxt = "BUY";
   }
   else if(sig == SIGNAL_SELL)
   {
      decTxt = "Decision: SELL"; decClr = C_RED; decBg = C_SELL_BG; aiTxt = "SELL";
   }
   else
   {
      decTxt = "Decision: HOLD"; decClr = C_GOLD; decBg = C_HOLD_BG; aiTxt = "HOLD";
   }

   SetLabel("V_DEC", decTxt, decClr);
   string decBarN = DASH_PREFIX+"DEC_BAR";
   if(ObjectFind(0,decBarN)>=0) ObjectSetInteger(0,decBarN,OBJPROP_BGCOLOR,decBg);

   string fdN = DASH_PREFIX+"FD_BG";
   if(ObjectFind(0,fdN)>=0) ObjectSetInteger(0,fdN,OBJPROP_BGCOLOR,decBg);
   if(g_State == STATE_ANALYZING) SetLabel("V_FD", "ANALYSING", C_VIOLET);
   else SetLabel("V_FD", aiTxt, decClr);

   SetLabel("V_FDS1", aiTxt, decClr);
   SetLabel("V_FDS2", g_StatusText, g_StatusColor);

   //--- AI Engine status
   SetLabel("V_AIST", g_StatusText, g_StatusColor);
   string dotN = DASH_PREFIX+"AI_DOT";
   if(ObjectFind(0,dotN)>=0) ObjectSetInteger(0,dotN,OBJPROP_COLOR,g_StatusColor);

   string lastDec = (sig==SIGNAL_BUY) ? "BUY" : (sig==SIGNAL_SELL) ? "SELL" : "HOLD";
   SetLabel("V_AILD", lastDec, decClr);

   int confPct = (int)MathRound((g_LastConfluenceScore / 9.0) * 100.0);
   string confTxt = (confPct >= 75) ? "HIGH" : (confPct >= 55) ? "MEDIUM" : "LOW";
   color  confClr = (confPct >= 75) ? C_GREEN : (confPct >= 55) ? C_GOLD : C_RED;
   SetLabel("V_AISC", confTxt, confClr);
   string confFgN = DASH_PREFIX+"CONF_FG";
   if(ObjectFind(0,confFgN)>=0)
      ObjectSetInteger(0,confFgN,OBJPROP_XSIZE, MathMax(4,(int)MathRound(150*(confPct/100.0))));
   if(ObjectFind(0,confFgN)>=0) ObjectSetInteger(0,confFgN,OBJPROP_BGCOLOR,confClr);

   //--- Open Position panel (single-position display with R-multiples)
   bool hasPos = false;
   double rowPnl = 0.0;
   for(int i = 0; i < PositionsTotal(); i++)
   {
      if(g_Pos.SelectByIndex(i) && g_Pos.Magic()==InpMagicNumber && g_Pos.Symbol()==_Symbol)
      {
         hasPos = true;
         string typStr = (g_Pos.PositionType()==POSITION_TYPE_BUY) ? "BUY" : "SELL";
         color  typClr = (g_Pos.PositionType()==POSITION_TYPE_BUY) ? C_GREEN : C_RED;
         rowPnl = g_Pos.Profit()+g_Pos.Swap()+g_Pos.Commission();

         SetLabel("V_OTYP", typStr, typClr);
         SetLabel("V_OLOT", DoubleToString(g_Pos.Volume(),2), C_WHITE);
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
      SetLabel("V_OLOT", "---", C_MUTED);
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
   SetLabel("V_RSK", DoubleToString(GetRiskAdjustedPercent(),2)+"%", C_GOLD);
   // Note: magic number display dropped from compact layout (visible in EA inputs panel)

   if(g_ConsecLosses >= 2)
   {
      int required = 6; if(g_ConsecLosses>=2) required=7; if(g_ConsecLosses>=3) required=8;
      SetLabel("V_STK", "!! LOSS x"+IntegerToString(g_ConsecLosses)+" Need "+IntegerToString(required)+"/9", C_RED);
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
   SetLabel("V_CONF", "Score:"+IntegerToString(g_LastConfluenceScore)+"/9  "+strip, C_CYAN);

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
