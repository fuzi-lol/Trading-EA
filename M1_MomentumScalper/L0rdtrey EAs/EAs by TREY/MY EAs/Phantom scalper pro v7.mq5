//+------------------------------------------------------------------+
//|              PHANTOM SCALPER PRO – Institutional AI Edition      |
//|              v5.0 (MTF Confluence | ATR Adaptive | Regime-Aware) |
//|              24/5 Autonomous HF Scalping System  —  XAUUSD       |
//+------------------------------------------------------------------+
#property copyright   "PHANTOM SCALPER PRO AI  v5.0"
#property version     "5.00"
#property description "MTF + ATR + Regime + OFI | Institutional XAUUSD Scalper"

#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>
#include <Trade\AccountInfo.mqh>

//--- Dashboard namespace prefix
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
#define C_TEAL      C'0,200,180'
#define C_PINK      C'255,100,180'

//=======================================================================
//  ENUMS
//=======================================================================
enum ENUM_SESSION_FILTER {
   SESSION_ALL    = 0,   // All Sessions
   SESSION_LONDON = 1,   // London Only
   SESSION_NY     = 2,   // New York Only
   SESSION_BOTH   = 3    // London + NY (Overlap preferred)
};

enum ENUM_VOL_REGIME {
   REGIME_LOW    = 0,
   REGIME_NORMAL = 1,
   REGIME_HIGH   = 2
};

//=======================================================================
//  INPUT PARAMETERS
//=======================================================================
input group "╔══════  IDENTITY  ══════╗"
input ulong  InpMagicNumber       = 99999;
input string InpBotName           = "PHANTOM SCALPER PRO v5";

input group "╔══════  LOT & RISK  ══════╗"
input double InpBaseLotSize       = 0.01;    // Base lot (Regime Normal)
input double InpProfitTargetUSD   = 8.00;    // Float P&L close threshold ($)
input double InpMaxDailyLossPct   = 4.0;     // Max daily loss % of balance
input double InpMaxDailyProfitPct = 12.0;    // Daily profit target % of balance
input double InpEquityTrailPct    = 3.0;     // Halt if equity drops X% from session peak
input int    InpMaxConsecLosses   = 5;       // Circuit breaker: consecutive losses
input int    InpBulkTrades        = 5;       // Simultaneous trade count per signal

input group "╔══════  ATR STOPS  ══════╗"
input int    InpATRPeriod         = 14;      // ATR period
input double InpSL_ATR_Mult       = 1.2;     // SL = ATR * multiplier
input double InpTP_ATR_Mult       = 2.4;     // TP = ATR * multiplier
input double InpSpreadATR_MaxPct  = 25.0;    // Block trade if spread > X% of ATR

input group "╔══════  MULTI-TIMEFRAME  ══════╗"
input bool   InpUseMTF            = true;    // Require MTF confluence
input ENUM_TIMEFRAMES InpTF_Fast  = PERIOD_M1;
input ENUM_TIMEFRAMES InpTF_Mid   = PERIOD_M5;
input ENUM_TIMEFRAMES InpTF_Slow  = PERIOD_M15;

input group "╔══════  ML & SIGNAL  ══════╗"
input double InpMLThreshold       = 0.72;    // ML confidence threshold [0.0-1.0]
input int    InpTickBufferSize    = 600;     // Rolling tick buffer
input int    InpADXPeriod         = 14;      // ADX period
input double InpADXMinLevel       = 20.0;    // Min ADX (trend strength filter)
input double InpRSI_OB            = 68.0;    // RSI overbought
input double InpRSI_OS            = 32.0;    // RSI oversold

input group "╔══════  VOLATILITY REGIME  ══════╗"
input double InpATR_LowMult       = 0.7;     // ATR < Normal*mult = LOW regime
input double InpATR_HighMult      = 1.5;     // ATR > Normal*mult = HIGH regime
input double InpLotMult_Low       = 0.5;     // Lot multiplier in LOW volatility
input double InpLotMult_High      = 1.5;     // Lot multiplier in HIGH volatility
input double InpML_Low            = 0.78;    // Higher threshold in LOW vol
input double InpML_High           = 0.68;    // Lower threshold in HIGH vol

input group "╔══════  SESSION FILTER  ══════╗"
input ENUM_SESSION_FILTER InpSessionFilter = SESSION_BOTH;
input int    InpLondonOpen        = 7;       // London open hour (server time)
input int    InpLondonClose       = 16;      // London close hour
input int    InpNYOpen            = 13;      // NY open hour (server time)
input int    InpNYClose           = 21;      // NY close hour
input int    InpNewsBlackoutMin   = 15;      // Minutes to block before/after XX:00 candle (news proxy)

input group "╔══════  TRADE FLOW  ══════╗"
input int    InpMaxDailyTrades    = 28;      // Max trades per day
input int    InpCooldownSec       = 45;      // Cooldown after close (seconds)

input group "╔══════  RECOVERY  ══════╗"
input double InpRecovery_T1       = 1.0;     // Tier 0 (no loss streak)
input double InpRecovery_T2       = 1.4;     // Tier 1 (1 consec loss)
input double InpRecovery_T3       = 1.8;     // Tier 2 (2 consec losses)
input double InpRecovery_T4       = 2.3;     // Tier 3 (3 consec losses)
input double InpRecovery_T5       = 3.0;     // Tier 4 (4+ consec losses)

input group "╔══════  DASHBOARD  ══════╗"
input bool   InpShowDash          = true;
input int    InpDashX             = 14;
input int    InpDashY             = 14;

//=======================================================================
//  CONSTANTS & GLOBALS
//=======================================================================
const int    DW = 440;
const int    DH = 720;

CTrade        g_trade;
CPositionInfo g_pos;
CAccountInfo  g_account;

//--- Indicator handles
int  g_emaFast_m5  = INVALID_HANDLE;
int  g_emaSlow_m5  = INVALID_HANDLE;
int  g_emaFast_m1  = INVALID_HANDLE;
int  g_emaSlow_m1  = INVALID_HANDLE;
int  g_emaFast_m15 = INVALID_HANDLE;
int  g_emaSlow_m15 = INVALID_HANDLE;
int  g_rsiH        = INVALID_HANDLE;
int  g_adxH        = INVALID_HANDLE;
int  g_atrH_m5     = INVALID_HANDLE;
int  g_atrH_m1     = INVALID_HANDLE;  // ATR M1 for spread check

//--- Rolling tick buffer
MqlTick       g_tickBuffer[];
int           g_tickCount        = 0;

//--- ML & signal state
double        g_lastMLConf       = 0.5;
double        g_chiSquare        = 0.0;
double        g_ofiScore         = 0.0;      // Order flow imbalance
double        g_atrValue         = 0.0;      // Current ATR (M5)
double        g_atrNormal        = 0.0;      // Baseline ATR (20-period rolling avg)
ENUM_VOL_REGIME g_volRegime      = REGIME_NORMAL;

//--- Session state
bool          g_inLondon         = false;
bool          g_inNY             = false;
bool          g_sessionOK        = false;

//--- MTF confluence
int           g_mtf_m1           = 0;        // +1 bull, -1 bear, 0 neutral
int           g_mtf_m5           = 0;
int           g_mtf_m15          = 0;
int           g_mtfScore         = 0;        // sum of above

//--- Trade state
datetime      g_lastCloseTime    = 0;
datetime      g_sessionDay       = 0;
bool          g_inCooldown       = false;
int           g_cooldownLeft     = 0;
bool          g_circuitBreaker   = false;
bool          g_equityHalt       = false;

//--- Session stats
int           g_sessTradesToday  = 0;
double        g_sessProfit       = 0.0;
int           g_sessWins         = 0;
int           g_sessLosses       = 0;
int           g_consecLosses     = 0;
double        g_peakEquity       = 0.0;
double        g_drawdown         = 0.0;
double        g_sessionPeakEq    = 0.0;      // Equity at session start for trailing stop

//--- Dashboard state
string        g_statusText       = "WARMING UP";
color         g_statusColor      = C_ORANGE;
string        g_lastAction       = "Initializing...";
string        g_regimeText       = "NORMAL";
color         g_regimeColor      = C_CYAN;
string        g_sessionText      = "--";

//--- Recovery tiers (dynamic from inputs)
double        g_recoveryTiers[5];

//=======================================================================
//  FORWARD DECLARATIONS
//=======================================================================
void     ResetAnalysis();
void     UpdateTickBuffer();
double   CalculatePosteriorProbability();
double   GetChiSquareDrift();
double   GetOFI();
void     UpdateVolatilityRegime();
void     UpdateSessionState();
void     UpdateMTF();
bool     MTFAligned(int requiredDir);
bool     CheckSpread();
bool     IsNewsWindow();

void     RestoreSession();
void     BuildSessionStats();
bool     HasPosition();
bool     OpenBulkTrades(ENUM_ORDER_TYPE otype);
void     CloseAllPositions();
double   GetFloatPL();
bool     IsMarketOpen();
bool     DailyLimitsOK();
void     ComputeATRStops(double price, ENUM_ORDER_TYPE otype, double &sl, double &tp);
double   NPrice(double p);
ENUM_ORDER_TYPE_FILLING GetFillMode();
datetime DayStart(datetime ts);
int      GetConsecutiveLosses();
void     BuildRecoveryTiers();

void     InitDash();
void     UpdateDash();
void     DeleteDash();
void     R(string nm, int x, int y, int w, int h, color bg, color brd=clrNONE, int bw=1);
void     L(string nm, int x, int y, string txt, color clr, int fsz, string fnt="Arial Bold");
void     U(string nm, string txt, color clr);
void     Bar(string nm, int x, int y, int w, int h, double pct, color fg, color bg);
void     UpdBar(string nm, double pct, color fg);

//=======================================================================
//  OnInit
//=======================================================================
int OnInit()
{
   if(StringFind(Symbol(), "XAU") < 0)
      Print("WARNING: PHANTOM v5 is tuned for XAUUSD. Performance on other symbols is untested.");

   ArrayResize(g_tickBuffer, InpTickBufferSize);
   BuildRecoveryTiers();

   g_trade.SetExpertMagicNumber(InpMagicNumber);
   g_trade.SetDeviationInPoints(30);
   g_trade.SetTypeFilling(GetFillMode());

   //--- M1 indicators
   g_emaFast_m1  = iMA(Symbol(), PERIOD_M1,  9,  0, MODE_EMA, PRICE_CLOSE);
   g_emaSlow_m1  = iMA(Symbol(), PERIOD_M1,  21, 0, MODE_EMA, PRICE_CLOSE);
   g_atrH_m1     = iATR(Symbol(), PERIOD_M1, InpATRPeriod);

   //--- M5 indicators (primary)
   g_emaFast_m5  = iMA(Symbol(), PERIOD_M5,  9,  0, MODE_EMA, PRICE_CLOSE);
   g_emaSlow_m5  = iMA(Symbol(), PERIOD_M5,  21, 0, MODE_EMA, PRICE_CLOSE);
   g_rsiH        = iRSI(Symbol(), PERIOD_M5, 14, PRICE_CLOSE);
   g_adxH        = iADX(Symbol(), PERIOD_M5, InpADXPeriod);
   g_atrH_m5     = iATR(Symbol(), PERIOD_M5, InpATRPeriod);

   //--- M15 indicators
   g_emaFast_m15 = iMA(Symbol(), PERIOD_M15, 9,  0, MODE_EMA, PRICE_CLOSE);
   g_emaSlow_m15 = iMA(Symbol(), PERIOD_M15, 21, 0, MODE_EMA, PRICE_CLOSE);

   if(g_emaFast_m5 == INVALID_HANDLE || g_rsiH == INVALID_HANDLE || g_adxH == INVALID_HANDLE || g_atrH_m5 == INVALID_HANDLE) {
      Print("CRITICAL: Failed to create indicator handles. Aborting.");
      return INIT_FAILED;
   }

   g_peakEquity     = AccountInfoDouble(ACCOUNT_EQUITY);
   g_sessionPeakEq  = g_peakEquity;
   g_sessionDay     = DayStart(TimeCurrent());

   RestoreSession();
   BuildSessionStats();
   g_consecLosses = GetConsecutiveLosses();

   if(InpShowDash) InitDash();
   EventSetTimer(1);

   g_lastAction = "Buffering ticks & loading ATR baseline...";
   Print(InpBotName, " v5.0 initialized. Magic=", InpMagicNumber);
   return INIT_SUCCEEDED;
}

//=======================================================================
//  OnDeinit
//=======================================================================
void OnDeinit(const int reason)
{
   EventKillTimer();
   DeleteDash();
   int handles[] = {g_emaFast_m1, g_emaSlow_m1, g_atrH_m1,
                    g_emaFast_m5, g_emaSlow_m5, g_rsiH, g_adxH, g_atrH_m5,
                    g_emaFast_m15, g_emaSlow_m15};
   for(int i=0; i<ArraySize(handles); i++)
      if(handles[i] != INVALID_HANDLE) IndicatorRelease(handles[i]);
}

//=======================================================================
//  OnTimer — 1 second pulse
//=======================================================================
void OnTimer()
{
   //--- Cooldown countdown
   if(g_lastCloseTime > 0) {
      int elapsed = (int)(TimeCurrent() - g_lastCloseTime);
      g_inCooldown   = (elapsed < InpCooldownSec);
      g_cooldownLeft = g_inCooldown ? (InpCooldownSec - elapsed) : 0;
   } else {
      g_inCooldown = false; g_cooldownLeft = 0;
   }

   //--- Equity tracking
   double eq = AccountInfoDouble(ACCOUNT_EQUITY);
   if(eq > g_peakEquity) g_peakEquity = eq;
   if(g_peakEquity > 0) g_drawdown = (g_peakEquity - eq) / g_peakEquity * 100.0;

   //--- Session peak equity trailing stop
   if(InpEquityTrailPct > 0.0) {
      double dropFromPeak = (g_sessionPeakEq - eq) / g_sessionPeakEq * 100.0;
      g_equityHalt = (dropFromPeak >= InpEquityTrailPct);
   }

   if(InpShowDash) UpdateDash();
}

//=======================================================================
//  OnTick — Core Execution Engine
//=======================================================================
void OnTick()
{
   //--- Daily session reset
   datetime todayStart = DayStart(TimeCurrent());
   if(todayStart != g_sessionDay) {
      g_sessionDay        = todayStart;
      g_sessTradesToday   = 0;
      g_circuitBreaker    = false;
      g_equityHalt        = false;
      g_sessionPeakEq     = AccountInfoDouble(ACCOUNT_EQUITY);
      BuildSessionStats();
      g_consecLosses      = 0;
      ResetAnalysis();
      g_atrNormal         = 0.0;
   }

   //--- Market open check
   if(!IsMarketOpen()) {
      g_statusText = "MKT CLOSED"; g_statusColor = C_RED; return;
   }

   //--- Update microstructure buffer
   UpdateTickBuffer();

   //--- Update session / regime / MTF state every tick
   UpdateSessionState();
   UpdateVolatilityRegime();
   if(InpUseMTF) UpdateMTF();

   //--- Handle open positions
   if(HasPosition()) {
      double floatPL = GetFloatPL();
      if(floatPL >= InpProfitTargetUSD) {
         CloseAllPositions();
         g_lastCloseTime = TimeCurrent();
         g_inCooldown    = true;
         g_cooldownLeft  = InpCooldownSec;
         BuildSessionStats();
         g_consecLosses = GetConsecutiveLosses();
         //--- Circuit breaker check
         if(g_consecLosses >= InpMaxConsecLosses) {
            g_circuitBreaker = true;
            g_lastAction = StringFormat("CIRCUIT BREAKER: %d consecutive losses", g_consecLosses);
            Print(g_lastAction);
         }
         ResetAnalysis();
         return;
      }
      g_statusText = "IN TRADE"; g_statusColor = C_GREEN;
      return;
   }

   //--- Guard rails
   if(g_inCooldown) {
      g_statusText = StringFormat("COOLDOWN %ds", g_cooldownLeft);
      g_statusColor = C_CYAN; return;
   }
   if(g_circuitBreaker) {
      g_statusText = "CIRCUIT BRK"; g_statusColor = C_RED; return;
   }
   if(g_equityHalt) {
      g_statusText = "EQ TRAIL HALT"; g_statusColor = C_RED; return;
   }
   if(!DailyLimitsOK()) {
      g_statusText = "LIMIT HIT"; g_statusColor = C_RED; return;
   }
   if(!g_sessionOK) {
      g_statusText = "OUT OF SESSION"; g_statusColor = C_MGRAY; return;
   }
   if(IsNewsWindow()) {
      g_statusText = "NEWS BLACKOUT"; g_statusColor = C_ORANGE; return;
   }
   if(!CheckSpread()) {
      g_statusText = "WIDE SPREAD"; g_statusColor = C_ORANGE; return;
   }

   //--- Buffer warmup guard
   if(g_tickCount < InpTickBufferSize) {
      g_statusText = StringFormat("BUFFERING %d%%", (int)(g_tickCount*100.0/InpTickBufferSize));
      g_statusColor = C_ORANGE; return;
   }

   //--- ADX trend filter
   double adxBuf[1];
   if(CopyBuffer(g_adxH, 0, 0, 1, adxBuf) > 0) {
      if(adxBuf[0] < InpADXMinLevel) {
         g_statusText = "CHOPPY MKT"; g_statusColor = C_MGRAY; return;
      }
   }

   //=== ML INFERENCE ===
   g_lastMLConf = CalculatePosteriorProbability();

   //--- Regime-adjusted threshold
   double threshold = InpMLThreshold;
   if(g_volRegime == REGIME_LOW)  threshold = InpML_Low;
   if(g_volRegime == REGIME_HIGH) threshold = InpML_High;

   ENUM_ORDER_TYPE dir = (ENUM_ORDER_TYPE)(-1);
   if(g_lastMLConf >= threshold)                dir = ORDER_TYPE_BUY;
   if((1.0 - g_lastMLConf) >= threshold)        dir = ORDER_TYPE_SELL;

   //--- MTF confirmation
   if(dir != (ENUM_ORDER_TYPE)(-1) && InpUseMTF) {
      int reqDir = (dir == ORDER_TYPE_BUY) ? 1 : -1;
      if(!MTFAligned(reqDir)) {
         g_statusText = "MTF MISMATCH"; g_statusColor = C_MGRAY; return;
      }
   }

   if(dir != (ENUM_ORDER_TYPE)(-1)) {
      g_statusText = "EXECUTING"; g_statusColor = C_LBLUE;
      if(OpenBulkTrades(dir)) {
         g_statusText = "IN TRADE"; g_statusColor = C_GREEN;
      } else {
         g_statusText = "OPEN FAIL"; g_statusColor = C_RED;
      }
   } else {
      g_statusText = "ANALYZING"; g_statusColor = C_GOLD;
   }
}

//=======================================================================
//  MICROSTRUCTURE & ANALYSIS
//=======================================================================
void ResetAnalysis()
{
   ZeroMemory(g_tickBuffer);
   g_tickCount   = 0;
   g_lastMLConf  = 0.5;
   g_chiSquare   = 0.0;
   g_ofiScore    = 0.0;
   g_lastAction  = "Analysis buffers cleared.";
}

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
   int up = 0, dn = 0;
   for(int i=1; i<g_tickCount; i++) {
      double delta = g_tickBuffer[i].bid - g_tickBuffer[i-1].bid;
      if(delta > 0) up++; else if(delta < 0) dn++;
   }
   int total = up + dn;
   if(total == 0) return 0;
   double exp = total / 2.0;
   double chi = (MathPow(up - exp, 2) / exp) + (MathPow(dn - exp, 2) / exp);
   g_chiSquare = chi;
   double norm = MathMin(chi / 60.0, 1.0);
   return (up > dn) ? norm : -norm;
}

double GetOFI()
{
   // Order Flow Imbalance: volume-weighted bid/ask pressure
   double askPressure = 0.0, bidPressure = 0.0;
   double totalVol = 0.0;
   for(int i=1; i<g_tickCount; i++) {
      double vol = g_tickBuffer[i].volume_real;
      if(vol <= 0) vol = 1.0;
      double priceChange = g_tickBuffer[i].ask - g_tickBuffer[i-1].ask;
      if(priceChange > 0)       askPressure += vol;
      else if(priceChange < 0)  bidPressure += vol;
      totalVol += vol;
   }
   if(totalVol == 0) return 0;
   g_ofiScore = (askPressure - bidPressure) / totalVol;
   return g_ofiScore;
}

void UpdateVolatilityRegime()
{
   double atrBuf[3];
   if(CopyBuffer(g_atrH_m5, 0, 0, 3, atrBuf) < 3) return;
   g_atrValue = atrBuf[0];

   //--- Build ATR baseline (running average with EMA-style smoothing)
   if(g_atrNormal == 0.0)
      g_atrNormal = g_atrValue;
   else
      g_atrNormal = g_atrNormal * 0.97 + g_atrValue * 0.03;

   if(g_atrNormal <= 0) return;

   double ratio = g_atrValue / g_atrNormal;
   if(ratio < InpATR_LowMult)       { g_volRegime = REGIME_LOW;    g_regimeText = "LOW VOL";    g_regimeColor = C_MGRAY;   }
   else if(ratio > InpATR_HighMult) { g_volRegime = REGIME_HIGH;   g_regimeText = "HIGH VOL";   g_regimeColor = C_ORANGE;  }
   else                              { g_volRegime = REGIME_NORMAL; g_regimeText = "NORMAL VOL"; g_regimeColor = C_CYAN;    }
}

void UpdateSessionState()
{
   MqlDateTime dt; TimeToStruct(TimeCurrent(), dt);
   int h = dt.hour;

   g_inLondon = (h >= InpLondonOpen && h < InpLondonClose);
   g_inNY     = (h >= InpNYOpen     && h < InpNYClose);

   switch(InpSessionFilter) {
      case SESSION_ALL:    g_sessionOK = true; break;
      case SESSION_LONDON: g_sessionOK = g_inLondon; break;
      case SESSION_NY:     g_sessionOK = g_inNY; break;
      case SESSION_BOTH:   g_sessionOK = (g_inLondon || g_inNY); break;
   }

   if(g_inLondon && g_inNY) g_sessionText = "LONDON+NY";
   else if(g_inLondon)       g_sessionText = "LONDON";
   else if(g_inNY)           g_sessionText = "NEW YORK";
   else                      g_sessionText = "ASIAN/OFF";
}

bool IsNewsWindow()
{
   if(InpNewsBlackoutMin <= 0) return false;
   MqlDateTime dt; TimeToStruct(TimeCurrent(), dt);
   int minuteOfHour = dt.min;
   // Block InpNewsBlackoutMin minutes before and after each hour boundary
   return (minuteOfHour >= (60 - InpNewsBlackoutMin) || minuteOfHour < InpNewsBlackoutMin);
}

bool CheckSpread()
{
   if(g_atrValue <= 0) return true; // Not yet calculated, pass
   double spread = SymbolInfoInteger(Symbol(), SYMBOL_SPREAD) * SymbolInfoDouble(Symbol(), SYMBOL_POINT);
   double maxSpread = g_atrValue * (InpSpreadATR_MaxPct / 100.0);
   return (spread <= maxSpread);
}

void UpdateMTF()
{
   double f[1], s[1];

   // M1
   if(CopyBuffer(g_emaFast_m1,  0, 0, 1, f) > 0 && CopyBuffer(g_emaSlow_m1, 0, 0, 1, s) > 0)
      g_mtf_m1 = (f[0] > s[0]) ? 1 : -1;

   // M5
   if(CopyBuffer(g_emaFast_m5,  0, 0, 1, f) > 0 && CopyBuffer(g_emaSlow_m5, 0, 0, 1, s) > 0)
      g_mtf_m5 = (f[0] > s[0]) ? 1 : -1;

   // M15
   if(CopyBuffer(g_emaFast_m15, 0, 0, 1, f) > 0 && CopyBuffer(g_emaSlow_m15, 0, 0, 1, s) > 0)
      g_mtf_m15 = (f[0] > s[0]) ? 1 : -1;

   g_mtfScore = g_mtf_m1 + g_mtf_m5 + g_mtf_m15;
}

bool MTFAligned(int requiredDir)
{
   // All 3 timeframes must agree, or at least 2 including M5
   if(requiredDir == 1)  return (g_mtfScore >= 2 && g_mtf_m5 == 1);
   if(requiredDir == -1) return (g_mtfScore <= -2 && g_mtf_m5 == -1);
   return false;
}

double CalculatePosteriorProbability()
{
   double f_ema[1], s_ema[1], rsi[1], adx[1];
   CopyBuffer(g_emaFast_m5, 0, 0, 1, f_ema);
   CopyBuffer(g_emaSlow_m5, 0, 0, 1, s_ema);
   CopyBuffer(g_rsiH,       0, 0, 1, rsi);
   CopyBuffer(g_adxH,       0, 0, 1, adx);

   // Feature 1: EMA trend bias [-1, +1]
   double f1_trend = (f_ema[0] > s_ema[0]) ? 1.0 : -1.0;

   // Feature 2: RSI momentum [-1, +1], capped at OB/OS extremes
   double rsiNorm = (rsi[0] - 50.0) / 50.0;
   if(rsi[0] >= InpRSI_OB) rsiNorm = MathMin(rsiNorm, 0.3); // Fade extreme OB
   if(rsi[0] <= InpRSI_OS) rsiNorm = MathMax(rsiNorm, -0.3); // Fade extreme OS
   double f2_mom = rsiNorm;

   // Feature 3: ADX strength amplifier [0, +1], direction-neutral
   double f3_adx = (adx[0] > 0) ? MathMin(adx[0] / 60.0, 1.0) : 0.0;

   // Feature 4: Chi-Square tick drift [-1, +1]
   double f4_drift = GetChiSquareDrift();

   // Feature 5: Order Flow Imbalance [-1, +1]
   double f5_ofi = GetOFI();

   // Feature 6: Volatility regime adjustment [-0.2, +0.2]
   double f6_regime = 0.0;
   if(g_volRegime == REGIME_HIGH)  f6_regime = (f1_trend * 0.15); // Amplify with-trend in HV
   if(g_volRegime == REGIME_LOW)   f6_regime = -(MathAbs(f1_trend) * 0.10); // Dampen in LV

   // Weights: sum = 1.0
   double w1=0.28, w2=0.18, w3=0.12, w4=0.20, w5=0.17, w6=0.05;

   double logit = (f1_trend * w1) + (f2_mom * w2) + (f3_adx * w3 * f1_trend) +
                  (f4_drift * w4) + (f5_ofi * w5) + f6_regime;

   // Sigmoid with slope factor 4.0 for institutional sharpness
   return 1.0 / (1.0 + MathExp(-logit * 4.0));
}

//=======================================================================
//  EXECUTION & POSITION LOGIC
//=======================================================================
bool OpenBulkTrades(ENUM_ORDER_TYPE otype)
{
   double price = (otype == ORDER_TYPE_BUY) ? SymbolInfoDouble(Symbol(), SYMBOL_ASK)
                                            : SymbolInfoDouble(Symbol(), SYMBOL_BID);
   if(price <= 0) return false;

   //--- Regime-adjusted lot sizing
   double lotMult = 1.0;
   if(g_volRegime == REGIME_LOW)  lotMult = InpLotMult_Low;
   if(g_volRegime == REGIME_HIGH) lotMult = InpLotMult_High;

   //--- Tiered recovery lot
   int tier = MathMin(g_consecLosses, 4);
   double rawLot = InpBaseLotSize * g_recoveryTiers[tier] * lotMult;

   double lotMin  = SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_MIN);
   double lotMax  = SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_MAX);
   double lotStep = SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_STEP);
   double lot     = MathMax(lotMin, MathMin(lotMax, MathRound(rawLot / lotStep) * lotStep));

   //--- ATR-based stops
   double sl = 0.0, tp = 0.0;
   ComputeATRStops(price, otype, sl, tp);

   g_lastAction = StringFormat("Bulk %s x%d | Lot %.2f | Tier %d | %s",
                                (otype==ORDER_TYPE_BUY?"BUY":"SELL"),
                                InpBulkTrades, lot, tier, g_regimeText);

   int opened = 0;
   for(int i=0; i<InpBulkTrades; i++) {
      bool ok = (otype == ORDER_TYPE_BUY)
               ? g_trade.Buy (lot, Symbol(), price, sl, tp, InpBotName)
               : g_trade.Sell(lot, Symbol(), price, sl, tp, InpBotName);
      if(ok) opened++;
      else   Print("Trade ", i+1, " failed: ", g_trade.ResultRetcodeDescription());
   }

   if(opened > 0) {
      g_sessTradesToday += opened;
      if(  g_sessionPeakEq) g_sessionPeakEq ;
      return true;
   }
   return false;
}

void CloseAllPositions()
{
   for(int i = PositionsTotal()-1; i >= 0; i--) {
      if(!g_pos.SelectByIndex(i)) continue;
      if(g_pos.Magic() != InpMagicNumber || g_pos.Symbol() != Symbol()) continue;
      g_trade.PositionClose(g_pos.Ticket());
   }
}

//=======================================================================
//  HELPERS
//=======================================================================
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

bool IsMarketOpen()
{
   ENUM_SYMBOL_TRADE_MODE m = (ENUM_SYMBOL_TRADE_MODE)SymbolInfoInteger(Symbol(), SYMBOL_TRADE_MODE);
   return (m == SYMBOL_TRADE_MODE_FULL || m == SYMBOL_TRADE_MODE_LONGONLY || m == SYMBOL_TRADE_MODE_SHORTONLY);
}

bool DailyLimitsOK()
{
   double bal = AccountInfoDouble(ACCOUNT_BALANCE);
   if(bal <= 0) return true;
   if(InpMaxDailyTrades > 0 && g_sessTradesToday >= InpMaxDailyTrades)              return false;
   if(InpMaxDailyLossPct   > 0 && g_sessProfit < -(bal * InpMaxDailyLossPct / 100)) return false;
   if(InpMaxDailyProfitPct > 0 && g_sessProfit >=  (bal * InpMaxDailyProfitPct / 100)) return false;
   return true;
}

void ComputeATRStops(double price, ENUM_ORDER_TYPE otype, double &sl, double &tp)
{
   double atr = g_atrValue;
   if(atr <= 0) {
      double buf[1];
      if(CopyBuffer(g_atrH_m5, 0, 0, 1, buf) > 0) atr = buf[0];
   }
   if(atr <= 0) { sl = 0; tp = 0; return; }

   double slDist = atr * InpSL_ATR_Mult;
   double tpDist = atr * InpTP_ATR_Mult;

   // Enforce minimum stop level
   int stopsLevel = (int)SymbolInfoInteger(Symbol(), SYMBOL_TRADE_STOPS_LEVEL);
   double minDist = stopsLevel * SymbolInfoDouble(Symbol(), SYMBOL_POINT);
   slDist = MathMax(slDist, minDist * 2.0);
   tpDist = MathMax(tpDist, minDist * 3.0);

   if(otype == ORDER_TYPE_BUY) {
      sl = NPrice(price - slDist);
      tp = NPrice(price + tpDist);
   } else {
      sl = NPrice(price + slDist);
      tp = NPrice(price - tpDist);
   }
}

int GetConsecutiveLosses()
{
   int losses = 0;
   if(!HistorySelect(0, TimeCurrent())) return 0;
   int total = HistoryDealsTotal();
   for(int i = total-1; i >= 0; i--) {
      ulong tk = HistoryDealGetTicket(i);
      if((ulong)HistoryDealGetInteger(tk, DEAL_MAGIC) != InpMagicNumber) continue;
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

void BuildRecoveryTiers()
{
   g_recoveryTiers[0] = InpRecovery_T1;
   g_recoveryTiers[1] = InpRecovery_T2;
   g_recoveryTiers[2] = InpRecovery_T3;
   g_recoveryTiers[3] = InpRecovery_T4;
   g_recoveryTiers[4] = InpRecovery_T5;
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

//=======================================================================
//  DASHBOARD GUI – v5 Layout
//=======================================================================
void R(string nm, int x, int y, int w, int h, color bg, color brd=clrNONE, int bw=1)
{
   string n = D+nm;
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
   string n = D+nm;
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
   string n = D+nm;
   if(ObjectFind(0,n)>=0){ ObjectSetString(0,n,OBJPROP_TEXT,txt); ObjectSetInteger(0,n,OBJPROP_COLOR,clr); }
}

void Bar(string nm, int x, int y, int w, int h, double pct, color fg, color bg_c)
{
   R(nm+"_bg",x,y,w,h,bg_c,C_BORDER,1);
   int fw=(int)MathMax(2,MathRound(pct/100.0*(w-2)));
   R(nm+"_fg",x+1,y+1,fw,h-2,fg,clrNONE);
}

void UpdBar(string nm, double pct, color fg)
{
   string nb=D+nm+"_bg"; string n=D+nm+"_fg";
   int w=0; if(ObjectFind(0,nb)>=0) w=(int)ObjectGetInteger(0,nb,OBJPROP_XSIZE);
   if(w<=0) return;
   int fw=(int)MathMax(2,MathRound(pct/100.0*(w-2)));
   if(ObjectFind(0,n)>=0){ObjectSetInteger(0,n,OBJPROP_XSIZE,fw);ObjectSetInteger(0,n,OBJPROP_BGCOLOR,fg);}
}

void InitDash()
{
   int X=InpDashX, Y=InpDashY;

   R("frame_outer", X,   Y,   DW,   DH,   C_BG0, C_ACBORD, 2);
   R("frame_inner", X+2, Y+2, DW-4, DH-4, C_BG0, C_BORDER, 1);
   R("hdr_bg",  X+2,  Y+2,  DW-4, 84,  C_HDRBAR, C_BORDER, 1);
   R("hdr_acc", X+2,  Y+2,  DW-4,  3,  C_ACBORD);
   L("h_name",  X+10, Y+10, InpBotName,                         C_GOLD,  12, "Arial Black");
   L("h_tag",   X+10, Y+30, "MTF + ATR + Regime + OFI | Institutional XAUUSD Scalper", C_CYAN, 7, "Arial");
   L("h_ver",   X+10, Y+44, "v5.0  |  Magic: "+(string)InpMagicNumber+"  |  "+Symbol(),  C_LBLUE, 7, "Arial");
   R("live_bg", X+DW-82, Y+8,  66, 22, C_DKGREEN, C_GREEN, 1);
   L("live_lbl",X+DW-74, Y+12, "● LIVE", C_GREEN, 7, "Arial Bold");
   R("div_hdr", X+2, Y+86, DW-4, 2, C_ACBORD);

   // Status row
   R("stat_bg",  X+2,  Y+90,  DW-4, 28,  C_BG2, C_BORDER, 1);
   L("lb_stat",  X+10, Y+97,  "STATUS",  C_SUBTEXT, 7, "Arial");
   L("vl_stat",  X+80, Y+96,  "WARMING UP", C_ORANGE, 9, "Arial Black");
   L("lb_sess",  X+250,Y+97,  "Session:", C_SUBTEXT, 7, "Arial");
   L("vl_sess",  X+300,Y+96,  "--",       C_TEAL,    8, "Arial Bold");
   R("div_s1",   X+2,  Y+120, DW-4, 1, C_BORDER);

   // Section A: Performance
   R("sec_a",   X+2,  Y+124, DW-4, 152, C_BG1, C_BORDER, 1);
   R("sec_a_hd",X+2,  Y+124, DW-4,  20, C_HDRBAR, C_BORDER, 1);
   L("sec_a_lb",X+10, Y+127, "▸  PERFORMANCE & RISK",   C_GOLD, 8, "Arial Black");
   L("lb_sp",  X+12, Y+149, "Session Profit",          C_SUBTEXT, 8, "Arial");
   L("vl_sp",  X+200,Y+149, "$ 0.00",                  C_WHITE,   9, "Arial Bold");
   L("lb_fp",  X+12, Y+165, "Floating P&L",            C_SUBTEXT, 8, "Arial");
   L("vl_fp",  X+200,Y+165, "$ 0.00",                  C_WHITE,   9, "Arial Bold");
   L("lb_dd",  X+12, Y+181, "Drawdown",                C_SUBTEXT, 8, "Arial");
   L("vl_dd",  X+200,Y+181, "0.00 %",                  C_WHITE,   9, "Arial Bold");
   Bar("dd_bar", X+292, Y+183, 140, 11, 0, C_RED, C_DGRAY);
   L("lb_eqh", X+12, Y+197, "Equity Trail Halt",       C_SUBTEXT, 8, "Arial");
   L("vl_eqh", X+200,Y+197, "ACTIVE",                  C_GREEN,   9, "Arial Bold");
   Bar("eq_bar", X+292, Y+199, 140, 11, 0, C_TEAL, C_DGRAY);
   L("lb_rcv", X+12, Y+213, "Recovery Tier",           C_SUBTEXT, 8, "Arial");
   L("vl_rcv", X+200,Y+213, "Tier 0 (1.0x)",           C_WHITE,   9, "Arial Bold");
   L("lb_tt",  X+12, Y+229, "Trades Today",            C_SUBTEXT, 8, "Arial");
   L("vl_tt",  X+200,Y+229, "0 / 0",                   C_WHITE,   9, "Arial Bold");
   L("lb_wr",  X+12, Y+245, "Win / Loss",              C_SUBTEXT, 8, "Arial");
   L("vl_wr",  X+200,Y+245, "0W  0L",                  C_WHITE,   9, "Arial Bold");
   R("div_s2", X+2, Y+278, DW-4, 1, C_BORDER);

   // Section B: MTF Confluence
   R("sec_b",   X+2,  Y+282, DW-4,  70, C_BG2, C_BORDER, 1);
   R("sec_b_hd",X+2,  Y+282, DW-4,  20, C_HDRBAR, C_BORDER, 1);
   L("sec_b_lb",X+10, Y+285, "▸  MTF CONFLUENCE",      C_GOLD, 8, "Arial Black");
   L("lb_m1",  X+12, Y+307, "M1 Trend",               C_SUBTEXT, 8, "Arial");
   L("vl_m1",  X+130,Y+307, "--",                      C_WHITE,   8, "Arial Bold");
   L("lb_m5",  X+190,Y+307, "M5 Trend",               C_SUBTEXT, 8, "Arial");
   L("vl_m5",  X+290,Y+307, "--",                      C_WHITE,   8, "Arial Bold");
   L("lb_m15", X+12, Y+323, "M15 Trend",              C_SUBTEXT, 8, "Arial");
   L("vl_m15", X+130,Y+323, "--",                      C_WHITE,   8, "Arial Bold");
   L("lb_mtf", X+190,Y+323, "Confluence",             C_SUBTEXT, 8, "Arial");
   L("vl_mtf", X+290,Y+323, "0 / 3",                  C_WHITE,   8, "Arial Bold");
   R("div_s3", X+2, Y+354, DW-4, 1, C_BORDER);

   // Section C: AI & Microstructure
   R("sec_c",   X+2,  Y+358, DW-4, 172, C_BG1, C_BORDER, 1);
   R("sec_c_hd",X+2,  Y+358, DW-4,  20, C_HDRBAR, C_BORDER, 1);
   L("sec_c_lb",X+10, Y+361, "▸  AI & MICROSTRUCTURE",  C_GOLD, 8, "Arial Black");
   L("lb_mlc",  X+12, Y+386, "ML Confidence",           C_SUBTEXT, 8, "Arial");
   L("vl_mlc",  X+200,Y+386, "50.0 %",                  C_CYAN,    9, "Arial Bold");
   Bar("ml_bar", X+292, Y+388, 140, 11, 50, C_CYAN, C_DGRAY);
   L("lb_dir",  X+12, Y+402, "Signal Vector",            C_SUBTEXT, 8, "Arial");
   L("vl_dir",  X+200,Y+402, "--",                       C_WHITE,   9, "Arial Bold");
   L("lb_chi",  X+12, Y+418, "Chi-Square Drift",         C_SUBTEXT, 8, "Arial");
   L("vl_chi",  X+200,Y+418, "0.00",                     C_WHITE,   8, "Arial");
   L("lb_ofi",  X+12, Y+434, "Order Flow Imbalance",     C_SUBTEXT, 8, "Arial");
   L("vl_ofi",  X+200,Y+434, "0.000",                    C_WHITE,   8, "Arial");
   L("lb_atr",  X+12, Y+450, "ATR (M5)",                 C_SUBTEXT, 8, "Arial");
   L("vl_atr",  X+200,Y+450, "0.00",                     C_WHITE,   8, "Arial");
   L("lb_reg",  X+12, Y+466, "Vol Regime",               C_SUBTEXT, 8, "Arial");
   L("vl_reg",  X+200,Y+466, "NORMAL",                   C_CYAN,    9, "Arial Bold");
   L("lb_adx",  X+12, Y+482, "ADX",                      C_SUBTEXT, 8, "Arial");
   L("vl_adx",  X+200,Y+482, "0.0",                      C_WHITE,   8, "Arial");
   L("lb_buf",  X+12, Y+498, "Tick Buffer",              C_SUBTEXT, 8, "Arial");
   L("vl_buf",  X+200,Y+498, "0 / 0",                   C_WHITE,   8, "Arial");
   Bar("buf_bar", X+292, Y+500, 140, 11, 0, C_PURPLE, C_DGRAY);
   R("div_s4",  X+2, Y+532, DW-4, 1, C_BORDER);

   // Config strip
   R("sec_d",  X+2, Y+536, DW-4, 50, C_BG2, C_BORDER, 1);
   L("cfg1",   X+10,Y+541, "Lot: "+DoubleToString(InpBaseLotSize,2)+
              "  |  Bulk: "+(string)InpBulkTrades+
              "  |  SL: "+DoubleToString(InpSL_ATR_Mult,1)+"×ATR"+
              "  |  TP: "+DoubleToString(InpTP_ATR_Mult,1)+"×ATR",   C_LBLUE, 7, "Arial");
   L("cfg2",   X+10,Y+556, "ML Threshold: "+DoubleToString(InpMLThreshold*100,1)+"%"+
              "  |  ADX Min: "+DoubleToString(InpADXMinLevel,0)+
              "  |  Target: $"+DoubleToString(InpProfitTargetUSD,2),  C_LBLUE, 7, "Arial");

   // Footer
   R("ftr",    X+2, Y+702, DW-4, 16, C_HDRBAR, C_BORDER, 1);
   L("ft_time",X+10,Y+704, "Server: --:--",              C_MGRAY, 7, "Arial");

   ChartRedraw(0);
}

void UpdateDash()
{
   if(!InpShowDash) return;
   double floatPL = GetFloatPL();

   U("vl_stat", g_statusText, g_statusColor);
   U("vl_sess", g_sessionText, g_inLondon && g_inNY ? C_GOLD : (g_inLondon ? C_CYAN : (g_inNY ? C_TEAL : C_MGRAY)));

   U("vl_sp",  "$ "+DoubleToString(g_sessProfit,2), g_sessProfit>=0 ? C_GREEN : C_RED);
   U("vl_fp",  "$ "+DoubleToString(floatPL,2),      floatPL>=0      ? C_GREEN : C_RED);
   U("vl_dd",  DoubleToString(g_drawdown,2)+" %",   g_drawdown<5    ? C_GREEN : C_RED);
   UpdBar("dd_bar", MathMin(g_drawdown*5.0,100.0), g_drawdown<5 ? C_GREEN : C_RED);

   double eq = AccountInfoDouble(ACCOUNT_EQUITY);
   double eqDropPct = (g_sessionPeakEq > 0) ? MathMax(0,(g_sessionPeakEq-eq)/g_sessionPeakEq*100.0) : 0;
   double eqBarPct  = MathMin(eqDropPct / InpEquityTrailPct * 100.0, 100.0);
   U("vl_eqh", g_equityHalt ? "HALTED" : StringFormat("%.1f%% / %.1f%%", eqDropPct, InpEquityTrailPct),
               g_equityHalt ? C_RED : (eqDropPct>InpEquityTrailPct*0.7 ? C_ORANGE : C_GREEN));
   UpdBar("eq_bar", eqBarPct, g_equityHalt ? C_RED : C_TEAL);

   int tier = MathMin(g_consecLosses,4);
   U("vl_rcv", "Tier "+IntegerToString(tier)+" ("+DoubleToString(g_recoveryTiers[tier],1)+"×)",
               tier>0 ? C_ORANGE : C_GREEN);
   U("vl_tt",  IntegerToString(g_sessTradesToday)+" / "+IntegerToString(InpMaxDailyTrades), C_WHITE);
   U("vl_wr",  IntegerToString(g_sessWins)+"W  "+IntegerToString(g_sessLosses)+"L",
               g_sessWins>g_sessLosses ? C_GREEN : (g_sessLosses>g_sessWins ? C_RED : C_WHITE));

   // MTF
   string trendStr[3]; color trendCol[3]; int trendArr[3]={g_mtf_m1,g_mtf_m5,g_mtf_m15};
   for(int i=0;i<3;i++){
      trendStr[i]=(trendArr[i]==1)?"BULL ▲":((trendArr[i]==-1)?"BEAR ▼":"--");
      trendCol[i]=(trendArr[i]==1)?C_GREEN:((trendArr[i]==-1)?C_RED:C_MGRAY);
   }
   U("vl_m1",  trendStr[0], trendCol[0]);
   U("vl_m5",  trendStr[1], trendCol[1]);
   U("vl_m15", trendStr[2], trendCol[2]);
   int aligned = (int)MathAbs(g_mtfScore);
   U("vl_mtf", IntegerToString(aligned)+" / 3", aligned>=2 ? C_GREEN : C_MGRAY);

   // ML & micro
   double mlPct = g_lastMLConf * 100.0;
   color mlCol  = (g_lastMLConf>InpMLThreshold)?C_GREEN:((1.0-g_lastMLConf>InpMLThreshold)?C_RED:C_CYAN);
   U("vl_mlc",  DoubleToString(mlPct,1)+" %", mlCol);
   UpdBar("ml_bar", mlPct, mlPct>50 ? C_GREEN : C_RED);

   if(g_lastMLConf>=InpMLThreshold)             U("vl_dir","BULLISH ▲",C_GREEN);
   else if((1.0-g_lastMLConf)>=InpMLThreshold)  U("vl_dir","BEARISH ▼",C_RED);
   else                                          U("vl_dir","NEUTRAL",  C_MGRAY);

   U("vl_chi", DoubleToString(g_chiSquare,2),       C_WHITE);
   U("vl_ofi", DoubleToString(g_ofiScore,3),        g_ofiScore>0?C_GREEN:(g_ofiScore<0?C_RED:C_WHITE));
   U("vl_atr", DoubleToString(g_atrValue,2),        C_WHITE);
   U("vl_reg", g_regimeText,                        g_regimeColor);

   double adxBuf[1];
   if(CopyBuffer(g_adxH,0,0,1,adxBuf)>0)
      U("vl_adx", DoubleToString(adxBuf[0],1), adxBuf[0]>=InpADXMinLevel?C_GREEN:C_MGRAY);

   U("vl_buf",
     IntegerToString(g_tickCount)+" / "+IntegerToString(InpTickBufferSize),
     g_tickCount==InpTickBufferSize ? C_GREEN : C_ORANGE);
   UpdBar("buf_bar", (double)g_tickCount/InpTickBufferSize*100.0, C_PURPLE);

   U("ft_time",
     "Server: "+TimeToString(TimeCurrent(),TIME_SECONDS)+"  |  Local: "+TimeToString(TimeLocal(),TIME_MINUTES)+"  |  "+g_sessionText,
     C_DGRAY);
   ChartRedraw(0);
}

void DeleteDash() { ObjectsDeleteAll(0, D); ChartRedraw(0); }
//+------------------------------------------------------------------+