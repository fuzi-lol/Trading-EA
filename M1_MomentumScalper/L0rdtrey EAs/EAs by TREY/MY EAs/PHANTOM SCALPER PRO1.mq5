//+------------------------------------------------------------------+
//| PHANTOM SCALPER PRO - Institutional AI Edition                   |
//| v4.00 XAUUSD M5 strategic scalping engine                        |
//| No martingale, no DCA, no hedge recovery, no loss-based sizing    |
//+------------------------------------------------------------------+
#property strict
#property copyright "PHANTOM SCALPER PRO AI"
#property version   "4.00"
#property description "Institutional XAUUSD M5 scalper with MTF structure, SMC, ML fallback, ONNX hooks, and dynamic exits."
#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>
#include <Trade\AccountInfo.mqh>
#define PSP_PREFIX "PSP4_"
//====================================================================
//  Constants
//====================================================================
const int MAX_BURST_SLOTS   = 7;
const int MAX_TRACKED_POS   = 32;
const int MIN_BARS_REQUIRED = 120;
// Dashboard palette: dark institutional, not a single-hue theme.
#define C_BG       C'5,8,18'
#define C_PANEL    C'11,15,28'
#define C_PANEL2   C'16,23,38'
#define C_EDGE     C'42,72,105'
#define C_ACCENT   C'0,168,180'
#define C_GOLD     C'245,188,54'
#define C_TEXT     C'226,232,240'
#define C_MUTED    C'145,158,180'
#define C_GREEN    C'42,214,124'
#define C_RED      C'235,76,92'
#define C_ORANGE   C'245,144,45'
#define C_BLUE     C'89,166,255'
#define C_PURPLE   C'168,116,255'
#define C_GRAY     C'54,64,82'
//====================================================================
//  Engine model
//====================================================================
enum MarketRegime
{
   REGIME_UNKNOWN = 0,
   REGIME_TRENDING_UP,
   REGIME_TRENDING_DOWN,
   REGIME_RANGING,
   REGIME_COMPRESSION,
   REGIME_VOL_EXPANSION,
   REGIME_LOW_LIQUIDITY,
   REGIME_REVERSAL,
   REGIME_BREAKOUT,
   REGIME_NEWS_ABNORMAL
};
enum SessionState
{
   SESSION_OFF = 0,
   SESSION_ASIA,
   SESSION_LONDON,
   SESSION_NEWYORK,
   SESSION_OVERLAP,
   SESSION_ROLLOVER
};
enum StructureBias
{
   BIAS_BEARISH = -1,
   BIAS_NEUTRAL = 0,
   BIAS_BULLISH = 1,
   BIAS_CONFLICT = 2
};
enum MicroPressure
{
   MICRO_BEARISH = -1,
   MICRO_NEUTRAL = 0,
   MICRO_BULLISH = 1
};
enum RiskState
{
   RISK_CLEAR = 0,
   RISK_CAUTION,
   RISK_BLOCKED,
   RISK_DAILY_STOP,
   RISK_LOSS_COOLDOWN,
   RISK_KILL_SWITCH
};
enum TradeGrade
{
   GRADE_NONE = 0,
   GRADE_B,
   GRADE_A,
   GRADE_A_PLUS
};
enum ExitAction
{
   EXIT_HOLD = 0,
   EXIT_PARTIAL,
   EXIT_BREAKEVEN,
   EXIT_TRAIL,
   EXIT_CLOSE
};
struct StructureSnapshot
{
   ENUM_TIMEFRAMES tf;
   StructureBias   bias;
   bool            bosBull;
   bool            bosBear;
   bool            mssBull;
   bool            mssBear;
   bool            higherHigh;
   bool            higherLow;
   bool            lowerHigh;
   bool            lowerLow;
   bool            displacementBull;
   bool            displacementBear;
   bool            weakness;
   double          swingHigh;
   double          swingLow;
   double          scoreBull;
   double          scoreBear;
};
struct SMCState
{
   bool   bullFvg;
   bool   bearFvg;
   bool   bullFvgRetest;
   bool   bearFvgRetest;
   double bullFvgLow;
   double bullFvgHigh;
   double bearFvgLow;
   double bearFvgHigh;
   bool   liquiditySweepBull;
   bool   liquiditySweepBear;
   bool   stopHuntBull;
   bool   stopHuntBear;
   bool   equalHighs;
   bool   equalLows;
   bool   orderBlockBull;
   bool   orderBlockBear;
   bool   imbalanceBull;
   bool   imbalanceBear;
   bool   breakerBull;
   bool   breakerBear;
   bool   inDiscount;
   bool   inPremium;
   bool   sessionLowRaid;
   bool   sessionHighRaid;
   double rangeMid;
   double scoreBull;
   double scoreBear;
};
struct MicroState
{
   MicroPressure pressure;
   double        scoreBull;
   double        scoreBear;
   double        tickVelocity;
   double        acceleration;
   double        bidAskProxy;
   double        spreadScore;
   double        candleAggression;
   double        rejectionVelocity;
   double        breakoutStrength;
   string        text;
};
struct AIScore
{
   double     buyConfidence;
   double     sellConfidence;
   double     noTradeConfidence;
   double     trendStrength;
   double     priceActionStrength;
   double     volatilityState;
   double     structureQuality;
   double     smcQuality;
   double     microQuality;
   double     sessionQuality;
   TradeGrade grade;
   string     reason;
};
struct MLPrediction
{
   double buyProbability;
   double sellProbability;
   double qualityProbability;
   double exitExhaustion;
   bool   onnxLoaded;
   bool   onnxUsed;
   string text;
};
struct TradePlan
{
   bool       valid;
   int        direction;
   int        slots;
   double     lotPerSlot;
   double     totalLot;
   double     entry;
   double     stopLoss;
   double     takeProfit;
   double     stopDistancePts;
   double     expectedMovePts;
   double     targetUsdPerSlot;
   double     confidence;
   double     quality;
   TradeGrade grade;
   string     reason;
};
struct ExitDecision
{
   ExitAction action;
   double     newStop;
   double     partialVolume;
   string     reason;
};
struct SlotRuntime
{
   ulong    ticket;
   double   peakProfit;
   bool     partialTaken;
   datetime openTime;
};
//====================================================================
//  Inputs
//====================================================================
input group "Core"
input ulong  InpMagicNumber          = 99999;
input string InpTradeSymbol          = "";
input string InpBotName              = "PHANTOM SCALPER PRO AI";
input int    InpDeviationPoints      = 35;
input bool   InpWarnNonXAU           = true;
input group "Analysis Timeframes"
input ENUM_TIMEFRAMES InpMacroTF     = PERIOD_H1;
input ENUM_TIMEFRAMES InpBiasTF      = PERIOD_M15;
input ENUM_TIMEFRAMES InpExecutionTF = PERIOD_M5;
input ENUM_TIMEFRAMES InpTimingTF    = PERIOD_M1;
input bool   InpAnalyzeNewM5Only     = true;
input group "Session Intelligence"
input bool   InpUseSessionFilter     = true;
input int    InpAsiaStartHour        = 0;
input int    InpAsiaEndHour          = 7;
input int    InpLondonStartHour      = 8;
input int    InpLondonEndHour        = 12;
input int    InpNYStartHour          = 13;
input int    InpNYEndHour            = 20;
input int    InpRolloverStartHour    = 22;
input int    InpRolloverEndHour      = 1;
input group "News Filter"
input bool   InpUseCalendarNews      = true;
input int    InpNewsPauseBeforeMin   = 30;
input int    InpNewsPauseAfterMin    = 20;
input string InpNewsKeywords         = "CPI;FOMC;NFP;Nonfarm;Payroll;Fed;Powell;PCE;Unemployment;GDP;ISM;Retail Sales";
input group "Regime And Structure"
input int    InpATRPeriod            = 14;
input int    InpADXPeriod            = 14;
input int    InpFastEMA              = 9;
input int    InpSlowEMA              = 21;
input int    InpSwingLookback        = 18;
input double InpDisplacementATR      = 0.85;
input double InpCompressionRatio     = 0.72;
input double InpVolExpansionRatio    = 1.45;
input group "Smart Money Concepts"
input int    InpFVGLookback          = 28;
input double InpMinFVGPoints         = 35.0;
input double InpMaxFVGPoints         = 500.0;
input int    InpSMCLookback          = 36;
input double InpEqualLevelTolerancePts = 45.0;
input bool   InpRequireFVGRetest     = true;
input group "AI And ML"
input double InpMinConfidence        = 80.0;
input double InpMinMLQuality         = 0.72;
input int    InpTickBufferSize       = 360;
input bool   InpUseONNX              = false;
input bool   InpOnnxCommonFolder     = true;
input bool   InpOnnxCpuOnly          = true;
input string InpOnnxDirectionModel   = "";
input string InpOnnxQualityModel     = "";
input string InpOnnxExitModel        = "";
input group "Execution"
input int    InpBurstSlots           = 3;
input double InpBaseLotSize          = 0.01;
input double InpMinLot               = 0.01;
input double InpMaxLot               = 0.10;
input double InpMaxTotalLot          = 0.20;
input double InpRiskPerSignalPct     = 0.60;
input int    InpMaxDailyTrades       = 12;
input int    InpCooldownSec          = 180;
input int    InpMaxSpreadPoints      = 160;
input int    InpMaxSlippagePoints    = 50;
input group "Risk Protection"
input double InpMaxDailyDrawdownPct  = 5.0;
input double InpEquityKillSwitchPct  = 8.0;
input int    InpMaxConsecutiveLosses = 3;
input int    InpLossCooldownMinutes  = 45;
input double InpAbnormalATRRatio     = 2.20;
input double InpLowATRRatio          = 0.52;
input bool   InpBlockLowLiquidity    = true;
input group "Dynamic Exit"
input double InpProfitPer001LotUSD   = 1.00;
input double InpPartialAtTargetPct   = 55.0;
input double InpPartialClosePct      = 50.0;
input double InpBreakEvenAtTargetPct = 42.0;
input double InpTrailStartTargetPct  = 80.0;
input double InpTrailGivebackPct     = 35.0;
input double InpEmergencyLossPer001USD = 3.50;
input double InpStopATRMultiplier    = 1.25;
input double InpTargetATRMultiplier  = 0.95;
input group "Dashboard"
input bool   InpShowDashboard        = true;
input int    InpDashX                = 12;
input int    InpDashY                = 18;
input int    InpDashWidth            = 470;
input int    InpDashFontSize         = 8;
//====================================================================
//  Globals
//====================================================================
CTrade        g_trade;
CPositionInfo g_position;
CAccountInfo  g_account;
string   g_symbol = "";
datetime g_lastM5Bar = 0;
datetime g_dayStart = 0;
datetime g_cooldownUntil = 0;
datetime g_lossCooldownUntil = 0;
double   g_dayStartEquity = 0.0;
double   g_dayPeakEquity = 0.0;
double   g_dailyProfit = 0.0;
double   g_dailyDrawdown = 0.0;
int      g_tradesToday = 0;
int      g_winsToday = 0;
int      g_lossesToday = 0;
int      g_consecutiveLosses = 0;
MarketRegime      g_regime = REGIME_UNKNOWN;
SessionState      g_session = SESSION_OFF;
RiskState         g_risk = RISK_CLEAR;
StructureSnapshot g_h1;
StructureSnapshot g_m15;
StructureSnapshot g_m5;
StructureSnapshot g_m1;
SMCState          g_smc;
MicroState        g_micro;
AIScore           g_ai;
MLPrediction      g_ml;
TradePlan         g_plan;
string g_statusText = "WARMING UP";
string g_blockReason = "Initializing";
string g_newsReason = "Clear";
bool   g_newsBlocked = false;
double g_currentATRPoints = 0.0;
double g_atrRatio = 1.0;
double g_expectedMovePts = 0.0;
MqlTick g_tickBuffer[];
int     g_tickSize = 0;
int     g_tickWrite = 0;
int     g_tickFilled = 0;
long    g_lastTickMsc = 0;
SlotRuntime g_slots;
long g_onnxDirection = INVALID_HANDLE;
long g_onnxQuality   = INVALID_HANDLE;
long g_onnxExit      = INVALID_HANDLE;
datetime g_newsCacheUntil = 0;
bool     g_newsCacheBlocked = false;
string   g_newsCacheReason = "Clear";
// Indicator handles.
int hATR_M1 = INVALID_HANDLE;
int hATR_M5 = INVALID_HANDLE;
int hATR_M15 = INVALID_HANDLE;
int hATR_H1 = INVALID_HANDLE;
int hADX_M5 = INVALID_HANDLE;
int hEMA_F_M1 = INVALID_HANDLE;
int hEMA_S_M1 = INVALID_HANDLE;
int hEMA_F_M5 = INVALID_HANDLE;
int hEMA_S_M5 = INVALID_HANDLE;
int hEMA_F_M15 = INVALID_HANDLE;
int hEMA_S_M15 = INVALID_HANDLE;
int hEMA_F_H1 = INVALID_HANDLE;
int hEMA_S_H1 = INVALID_HANDLE;
//====================================================================
//  Forward declarations
//====================================================================
void ResetDailyState();
void RestoreDailyStats();
void UpdateTickBuffer();
void SyncTrackedSlots();
void ManageOpenPositions();
void AnalyzeMarket();
void BuildTradePlan(TradePlan &plan);
bool ExecuteTradePlan(const TradePlan &plan);
bool OpenMarketOrder(const int direction, const double lot, const double sl, const double tp, const string comment);
bool CloseTicket(const ulong ticket, const string reason);
bool ClosePartialTicket(const ulong ticket, const double volume, const string reason);
bool ModifyStopLoss(const ulong ticket, const double sl, const double tp);
MarketRegime DetectMarketRegime();
SessionState DetectSession();
bool IsNewsBlocked(string &reason);
StructureSnapshot AnalyzeStructure(const ENUM_TIMEFRAMES tf);
SMCState AnalyzeSMC();
MicroState AnalyzeMicrostructure();
AIScore ScoreAI();
MLPrediction PredictML(const AIScore &ai);
ExitDecision EvaluateExit(const ulong ticket);
RiskState EvaluateRisk(string &reason);
double ATRPoints(const ENUM_TIMEFRAMES tf);
double ATRRatioM5();
double BufferValue(const int handle, const int buffer, const int shift);
bool GetRates(const ENUM_TIMEFRAMES tf, const int count, MqlRates &rates[]);
double HighestHigh(const MqlRates &rates[], const int from, const int count);
double LowestLow(const MqlRates &rates[], const int from, const int count);
double EMAValue(const ENUM_TIMEFRAMES tf, const bool fast, const int shift);
int EMADirection(const ENUM_TIMEFRAMES tf);
double ADXMain();
double SpreadPoints();
double NormalizePrice(const double p);
double NormalizeLot(const double lot);
double TargetUSDForLot(const double lot);
double StopLossUSDForLot(const double lot);
double DailyPnL();
int CountPositions();
double TotalOpenLots();
double FloatingProfit();
int CountConsecutiveLosses();
datetime DayStart(const datetime ts);
bool InHourRange(const int hour, const int startHour, const int endHour);
bool CanTradeSymbol();
bool IsMarketOpen();
ENUM_ORDER_TYPE_FILLING GetFillMode();
color StateColor(const double score, const bool inverse=false);
string RegimeText();
string SessionText();
string BiasText(const StructureBias bias);
string PressureText(const MicroPressure pressure);
string GradeText(const TradeGrade grade);
string RiskText();
string Lower(string s);
bool ContainsKeyword(const string text, const string keywords);
double Clamp(const double v, const double lo, const double hi);
double Sigmoid(const double x);
void InitDashboard();
void UpdateDashboard();
void DeleteDashboard();
void DashRect(const string id, const int x, const int y, const int w, const int h, const color bg, const color brd=clrNONE, const int bw=1);
void DashLabel(const string id, const int x, const int y, const string txt, const color clr, const int fsz, const string font="Arial");
void DashUpdate(const string id, const string txt, const color clr);
void DashBar(const string id, const int x, const int y, const int w, const int h, const double pct, const color fg, const color bg);
void DashBarUpdate(const string id, const double pct, const color fg);
//====================================================================
//  Initialization
//====================================================================
int OnInit()
{
   g_symbol = (InpTradeSymbol == "" ? _Symbol : InpTradeSymbol);
   if(InpWarnNonXAU && StringFind(Lower(g_symbol), "xau") < 0)
      Print("PHANTOM warning: this EA is tuned for XAUUSD. Current symbol: ", g_symbol);
   g_tickSize = (int)MathMax(60, MathMin(InpTickBufferSize, 2000));
   ArrayResize(g_tickBuffer, g_tickSize);
   g_tickWrite = 0;
   g_tickFilled = 0;
   g_lastTickMsc = 0;
   g_trade.SetExpertMagicNumber(InpMagicNumber);
   g_trade.SetDeviationInPoints(InpDeviationPoints);
   g_trade.SetTypeFilling(GetFillMode());
   hATR_M1   = iATR(g_symbol, PERIOD_M1,  InpATRPeriod);
   hATR_M5   = iATR(g_symbol, PERIOD_M5,  InpATRPeriod);
   hATR_M15  = iATR(g_symbol, PERIOD_M15, InpATRPeriod);
   hATR_H1   = iATR(g_symbol, PERIOD_H1,  InpATRPeriod);
   hADX_M5   = iADX(g_symbol, PERIOD_M5,  InpADXPeriod);
   hEMA_F_M1 = iMA(g_symbol, PERIOD_M1,  InpFastEMA, 0, MODE_EMA, PRICE_CLOSE);
   hEMA_S_M1 = iMA(g_symbol, PERIOD_M1,  InpSlowEMA, 0, MODE_EMA, PRICE_CLOSE);
   hEMA_F_M5 = iMA(g_symbol, PERIOD_M5,  InpFastEMA, 0, MODE_EMA, PRICE_CLOSE);
   hEMA_S_M5 = iMA(g_symbol, PERIOD_M5,  InpSlowEMA, 0, MODE_EMA, PRICE_CLOSE);
   hEMA_F_M15= iMA(g_symbol, PERIOD_M15, InpFastEMA, 0, MODE_EMA, PRICE_CLOSE);
   hEMA_S_M15= iMA(g_symbol, PERIOD_M15, InpSlowEMA, 0, MODE_EMA, PRICE_CLOSE);
   hEMA_F_H1 = iMA(g_symbol, PERIOD_H1,  InpFastEMA, 0, MODE_EMA, PRICE_CLOSE);
   hEMA_S_H1 = iMA(g_symbol, PERIOD_H1,  InpSlowEMA, 0, MODE_EMA, PRICE_CLOSE);
   if(hATR_M5 == INVALID_HANDLE || hADX_M5 == INVALID_HANDLE ||
      hEMA_F_M5 == INVALID_HANDLE || hEMA_S_M5 == INVALID_HANDLE)
   {
      Print("PHANTOM init failed: unable to create core indicator handles for ", g_symbol);
      return INIT_FAILED;
   }
   if(InpUseONNX)
   {
      uint flags = 0;
      if(InpOnnxCommonFolder) flags |= ONNX_COMMON_FOLDER;
      if(InpOnnxCpuOnly)      flags |= ONNX_USE_CPU_ONLY;
      if(InpOnnxDirectionModel != "")
         g_onnxDirection = OnnxCreate(InpOnnxDirectionModel, flags);
      if(InpOnnxQualityModel != "")
         g_onnxQuality = OnnxCreate(InpOnnxQualityModel, flags);
      if(InpOnnxExitModel != "")
         g_onnxExit = OnnxCreate(InpOnnxExitModel, flags);
      Print("PHANTOM ONNX hooks: direction=", g_onnxDirection,
            " quality=", g_onnxQuality, " exit=", g_onnxExit);
   }
   ArrayInitialize(g_slots, 0);
   g_dayStart = DayStart(TimeCurrent());
   g_dayStartEquity = AccountInfoDouble(ACCOUNT_EQUITY);
   g_dayPeakEquity = g_dayStartEquity;
   RestoreDailyStats();
   AnalyzeMarket();
   if(InpShowDashboard) InitDashboard();
   EventSetTimer(1);
   g_statusText = "SCANNING";
   g_blockReason = "Waiting for M5 institutional setup";
   Print("PHANTOM v4 initialized on ", g_symbol, " | confidence threshold=", InpMinConfidence, "%");
   return INIT_SUCCEEDED;
}
void OnDeinit(const int reason)
{
   EventKillTimer();
   DeleteDashboard();
   int handles[] =
   {
      hATR_M1,hATR_M5,hATR_M15,hATR_H1,hADX_M5,
      hEMA_F_M1,hEMA_S_M1,hEMA_F_M5,hEMA_S_M5,
      hEMA_F_M15,hEMA_S_M15,hEMA_F_H1,hEMA_S_H1
   };
   for(int i = 0; i < ArraySize(handles); i++)
      if(handles[i] != INVALID_HANDLE)
         IndicatorRelease(handles[i]);
   if(g_onnxDirection != INVALID_HANDLE) OnnxRelease(g_onnxDirection);
   if(g_onnxQuality   != INVALID_HANDLE) OnnxRelease(g_onnxQuality);
   if(g_onnxExit      != INVALID_HANDLE) OnnxRelease(g_onnxExit);
   Comment("");
   Print("PHANTOM deinitialized. reason=", reason);
}
void OnTimer()
{
   if(g_dayStart != DayStart(TimeCurrent()))
      ResetDailyState();
   double eq = AccountInfoDouble(ACCOUNT_EQUITY);
   if(eq > g_dayPeakEquity) g_dayPeakEquity = eq;
   if(g_dayPeakEquity > 0.0)
      g_dailyDrawdown = (g_dayPeakEquity - eq) / g_dayPeakEquity * 100.0;
   g_dailyProfit = DailyPnL();
   g_consecutiveLosses = CountConsecutiveLosses();
   if(InpShowDashboard)
      UpdateDashboard();
}
//====================================================================
//  Tick loop
//====================================================================
void OnTick()
{
   if(g_dayStart != DayStart(TimeCurrent()))
      ResetDailyState();
   UpdateTickBuffer();
   SyncTrackedSlots();
   ManageOpenPositions();
   if(CountPositions() > 0)
   {
      g_statusText = "MANAGING";
      return;
   }
   datetime currentM5 = iTime(g_symbol, PERIOD_M5, 0);
   bool newM5 = (currentM5 > 0 && currentM5 != g_lastM5Bar);
   if(InpAnalyzeNewM5Only && !newM5)
      return;
   if(newM5)
      g_lastM5Bar = currentM5;
   AnalyzeMarket();
   if(!g_plan.valid)
   {
      g_statusText = "WAIT";
      g_blockReason = g_plan.reason;
      return;
   }
   if(ExecuteTradePlan(g_plan))
   {
      g_statusText = "BURST LIVE";
      g_blockReason = "A+ signal slots opened";
      g_cooldownUntil = TimeCurrent() + InpCooldownSec;
   }
   else
   {
      g_statusText = "OPEN FAIL";
      g_blockReason = "Execution failed or broker rejected order";
   }
}
//====================================================================
//  Daily and history state
//====================================================================
void ResetDailyState()
{
   g_dayStart = DayStart(TimeCurrent());
   g_dayStartEquity = AccountInfoDouble(ACCOUNT_EQUITY);
   g_dayPeakEquity = g_dayStartEquity;
   g_dailyProfit = 0.0;
   g_dailyDrawdown = 0.0;
   g_tradesToday = 0;
   g_winsToday = 0;
   g_lossesToday = 0;
   g_consecutiveLosses = 0;
   g_lossCooldownUntil = 0;
   RestoreDailyStats();
}
void RestoreDailyStats()
{
   g_dailyProfit = 0.0;
   g_tradesToday = 0;
   g_winsToday = 0;
   g_lossesToday = 0;
   if(!HistorySelect(g_dayStart, TimeCurrent()))
      return;
   int total = HistoryDealsTotal();
   for(int i = 0; i < total; i++)
   {
      ulong ticket = HistoryDealGetTicket(i);
      if(ticket == 0) continue;
      if((ulong)HistoryDealGetInteger(ticket, DEAL_MAGIC) != InpMagicNumber) continue;
      if(HistoryDealGetString(ticket, DEAL_SYMBOL) != g_symbol) continue;
      long entry = HistoryDealGetInteger(ticket, DEAL_ENTRY);
      if(entry == DEAL_ENTRY_IN)
         g_tradesToday++;
      if(entry == DEAL_ENTRY_OUT)
      {
         double pnl = HistoryDealGetDouble(ticket, DEAL_PROFIT) +
                      HistoryDealGetDouble(ticket, DEAL_SWAP) +
                      HistoryDealGetDouble(ticket, DEAL_COMMISSION);
         g_dailyProfit += pnl;
         if(pnl >= 0.0) g_winsToday++;
         else           g_lossesToday++;
      }
   }
   g_consecutiveLosses = CountConsecutiveLosses();
}
//====================================================================
//  Market analysis orchestration
//====================================================================
void AnalyzeMarket()
{
   g_session = DetectSession();
   g_newsBlocked = IsNewsBlocked(g_newsReason);
   g_regime = DetectMarketRegime();
   g_h1  = AnalyzeStructure(InpMacroTF);
   g_m15 = AnalyzeStructure(InpBiasTF);
   g_m5  = AnalyzeStructure(InpExecutionTF);
   g_m1  = AnalyzeStructure(InpTimingTF);
   g_smc = AnalyzeSMC();
   g_micro = AnalyzeMicrostructure();
   g_ai = ScoreAI();
   g_ml = PredictML(g_ai);
   g_risk = EvaluateRisk(g_blockReason);
   BuildTradePlan(g_plan);
}
MarketRegime DetectMarketRegime()
{
   double atr = ATRPoints(PERIOD_M5);
   double ratio = ATRRatioM5();
   double adx = ADXMain();
   int d5 = EMADirection(PERIOD_M5);
   int d15 = EMADirection(PERIOD_M15);
   double spread = SpreadPoints();
   g_currentATRPoints = atr;
   g_atrRatio = ratio;
   if(g_newsBlocked)
      return REGIME_NEWS_ABNORMAL;
   if(InpBlockLowLiquidity && (g_session == SESSION_ROLLOVER || spread > InpMaxSpreadPoints * 0.85))
      return REGIME_LOW_LIQUIDITY;
   if(ratio >= InpAbnormalATRRatio)
      return REGIME_VOL_EXPANSION;
   if(ratio <= InpLowATRRatio || ratio <= InpCompressionRatio)
      return REGIME_COMPRESSION;
   if(adx >= 23.0 && d5 > 0 && d15 >= 0)
      return REGIME_TRENDING_UP;
   if(adx >= 23.0 && d5 < 0 && d15 <= 0)
      return REGIME_TRENDING_DOWN;
   if(adx <= 17.0)
      return REGIME_RANGING;
   if(MathAbs(g_micro.acceleration) > 0.60 && ratio > 1.25)
      return REGIME_BREAKOUT;
   return REGIME_RANGING;
}
SessionState DetectSession()
{
   MqlDateTime t;
   TimeToStruct(TimeCurrent(), t);
   if(InHourRange(t.hour, InpRolloverStartHour, InpRolloverEndHour))
      return SESSION_ROLLOVER;
   bool london = InHourRange(t.hour, InpLondonStartHour, InpLondonEndHour);
   bool ny = InHourRange(t.hour, InpNYStartHour, InpNYEndHour);
   bool asia = InHourRange(t.hour, InpAsiaStartHour, InpAsiaEndHour);
   if(london && ny) return SESSION_OVERLAP;
   if(london)       return SESSION_LONDON;
   if(ny)           return SESSION_NEWYORK;
   if(asia)         return SESSION_ASIA;
   return SESSION_OFF;
}
bool IsNewsBlocked(string &reason)
{
   reason = "Clear";
   if(!InpUseCalendarNews)
      return false;
   datetime now = TimeCurrent();
   if(now < g_newsCacheUntil)
   {
      reason = g_newsCacheReason;
      return g_newsCacheBlocked;
   }
   g_newsCacheUntil = now + 60;
   g_newsCacheBlocked = false;
   g_newsCacheReason = "Clear";
   MqlCalendarValue values[];
   datetime from = now - InpNewsPauseAfterMin * 60;
   datetime to   = now + InpNewsPauseBeforeMin * 60;
   int count = CalendarValueHistory(values, from, to, NULL, "USD");
   if(count <= 0)
   {
      reason = "Calendar clear/unavailable";
      g_newsCacheReason = reason;
      return false;
   }
   for(int i = 0; i < count; i++)
   {
      MqlCalendarEvent ev;
      if(!CalendarEventById(values[i].event_id, ev))
         continue;
      string name = ev.name;
      bool highImportance = (ev.importance == CALENDAR_IMPORTANCE_HIGH);
      bool keyword = ContainsKeyword(name, InpNewsKeywords);
      bool inBlock = (now >= values[i].time - InpNewsPauseBeforeMin * 60 &&
                      now <= values[i].time + InpNewsPauseAfterMin * 60);
      if(inBlock && (highImportance || keyword))
      {
         g_newsCacheBlocked = true;
         g_newsCacheReason = "USD news: " + name;
         reason = g_newsCacheReason;
         return true;
      }
   }
   reason = "Calendar clear";
   g_newsCacheReason = reason;
   return false;
}
StructureSnapshot AnalyzeStructure(const ENUM_TIMEFRAMES tf)
{
   StructureSnapshot s;
   s.tf = tf;
   s.bias = BIAS_NEUTRAL;
   s.bosBull = false;
   s.bosBear = false;
   s.mssBull = false;
   s.mssBear = false;
   s.higherHigh = false;
   s.higherLow = false;
   s.lowerHigh = false;
   s.lowerLow = false;
   s.displacementBull = false;
   s.displacementBear = false;
   s.weakness = false;
   s.swingHigh = 0.0;
   s.swingLow = 0.0;
   s.scoreBull = 0.0;
   s.scoreBear = 0.0;
   MqlRates rates[];
   int need = MathMax(MIN_BARS_REQUIRED, InpSwingLookback + 30);
   if(!GetRates(tf, need, rates))
      return s;
   double atrPts = ATRPoints(tf);
   double point = SymbolInfoDouble(g_symbol, SYMBOL_POINT);
   double close1 = rates[1].close;
   double open1 = rates[1].open;
   double bodyPts = MathAbs(close1 - open1) / point;
   double rangePts = (rates[1].high - rates[1].low) / point;
   double priorHigh = HighestHigh(rates, 2, InpSwingLookback);
   double priorLow  = LowestLow(rates, 2, InpSwingLookback);
   s.swingHigh = priorHigh;
   s.swingLow = priorLow;
   s.bosBull = (close1 > priorHigh && priorHigh > 0.0);
   s.bosBear = (close1 < priorLow && priorLow > 0.0);
   double highA = HighestHigh(rates, 2, 8);
   double highB = HighestHigh(rates, 10, 8);
   double lowA  = LowestLow(rates, 2, 8);
   double lowB  = LowestLow(rates, 10, 8);
   s.higherHigh = (highA > highB);
   s.higherLow  = (lowA > lowB);
   s.lowerHigh  = (highA < highB);
   s.lowerLow   = (lowA < lowB);
   int emaDir = EMADirection(tf);
   if((s.higherHigh && s.higherLow) || emaDir > 0)
      s.bias = BIAS_BULLISH;
   if((s.lowerHigh && s.lowerLow) || emaDir < 0)
      s.bias = BIAS_BEARISH;
   if((s.higherHigh && s.lowerLow) || (s.lowerHigh && s.higherLow))
      s.bias = BIAS_CONFLICT;
   s.mssBull = (rates[1].close > highA && rates[2].close < rates[2].open);
   s.mssBear = (rates[1].close < lowA && rates[2].close > rates[2].open);
   s.displacementBull = (close1 > open1 && bodyPts > atrPts * InpDisplacementATR && rangePts > atrPts * 0.85);
   s.displacementBear = (close1 < open1 && bodyPts > atrPts * InpDisplacementATR && rangePts > atrPts * 0.85);
   s.weakness = (rangePts > 0.0 && bodyPts / rangePts < 0.28);
   if(s.bias == BIAS_BULLISH) s.scoreBull += 28.0;
   if(s.bias == BIAS_BEARISH) s.scoreBear += 28.0;
   if(s.bosBull) s.scoreBull += 26.0;
   if(s.bosBear) s.scoreBear += 26.0;
   if(s.mssBull) s.scoreBull += 20.0;
   if(s.mssBear) s.scoreBear += 20.0;
   if(s.displacementBull) s.scoreBull += 18.0;
   if(s.displacementBear) s.scoreBear += 18.0;
   if(s.higherLow) s.scoreBull += 8.0;
   if(s.lowerHigh) s.scoreBear += 8.0;
   s.scoreBull = Clamp(s.scoreBull, 0.0, 100.0);
   s.scoreBear = Clamp(s.scoreBear, 0.0, 100.0);
   return s;
}
SMCState AnalyzeSMC()
{
   SMCState smc;
   ZeroMemory(smc);
   MqlRates rates[];
   if(!GetRates(PERIOD_M5, MathMax(90, InpSMCLookback + InpFVGLookback + 8), rates))
      return smc;
   double point = SymbolInfoDouble(g_symbol, SYMBOL_POINT);
   double bid = SymbolInfoDouble(g_symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(g_symbol, SYMBOL_ASK);
   double mid = (bid + ask) * 0.5;
   for(int i = 1; i <= InpFVGLookback; i++)
   {
      int newer = i;
      int older = i + 2;
      if(older >= ArraySize(rates)) break;
      double bullLow = rates[older].high;
      double bullHigh = rates[newer].low;
      double bullSizePts = (bullHigh - bullLow) / point;
      if(!smc.bullFvg && bullLow < bullHigh &&
         bullSizePts >= InpMinFVGPoints && bullSizePts <= InpMaxFVGPoints)
      {
         smc.bullFvg = true;
         smc.bullFvgLow = bullLow;
         smc.bullFvgHigh = bullHigh;
         smc.bullFvgRetest = (mid >= bullLow && mid <= bullHigh) ||
                             (rates[1].low <= bullHigh && rates[1].close > bullLow);
      }
      double bearLow = rates[newer].high;
      double bearHigh = rates[older].low;
      double bearSizePts = (bearHigh - bearLow) / point;
      if(!smc.bearFvg && bearLow < bearHigh &&
         bearSizePts >= InpMinFVGPoints && bearSizePts <= InpMaxFVGPoints)
      {
         smc.bearFvg = true;
         smc.bearFvgLow = bearLow;
         smc.bearFvgHigh = bearHigh;
         smc.bearFvgRetest = (mid >= bearLow && mid <= bearHigh) ||
                             (rates[1].high >= bearLow && rates[1].close < bearHigh);
      }
      if(smc.bullFvg && smc.bearFvg) break;
   }
   double recentHigh = HighestHigh(rates, 2, InpSMCLookback);
   double recentLow = LowestLow(rates, 2, InpSMCLookback);
   smc.rangeMid = (recentHigh + recentLow) * 0.5;
   smc.inDiscount = (mid < smc.rangeMid);
   smc.inPremium = (mid > smc.rangeMid);
   smc.liquiditySweepBull = (rates[1].low < recentLow && rates[1].close > recentLow);
   smc.liquiditySweepBear = (rates[1].high > recentHigh && rates[1].close < recentHigh);
   smc.stopHuntBull = smc.liquiditySweepBull && (rates[1].close > rates[1].open);
   smc.stopHuntBear = smc.liquiditySweepBear && (rates[1].close < rates[1].open);
   for(int i = 2; i < MathMin(InpSMCLookback, ArraySize(rates) - 2); i++)
   {
      for(int j = i + 1; j < MathMin(i + 8, ArraySize(rates) - 1); j++)
      {
         if(MathAbs(rates[i].high - rates[j].high) / point <= InpEqualLevelTolerancePts)
            smc.equalHighs = true;
         if(MathAbs(rates[i].low - rates[j].low) / point <= InpEqualLevelTolerancePts)
            smc.equalLows = true;
      }
   }
   double atrPts = ATRPoints(PERIOD_M5);
   for(int i = 2; i < 12 && i < ArraySize(rates) - 1; i++)
   {
      double bodyPts = MathAbs(rates[i].close - rates[i].open) / point;
      if(rates[i].close < rates[i].open && rates[i-1].close > rates[i-1].open &&
         bodyPts > atrPts * 0.35 && rates[i-1].close > rates[i].high)
         smc.orderBlockBull = true;
      if(rates[i].close > rates[i].open && rates[i-1].close < rates[i-1].open &&
         bodyPts > atrPts * 0.35 && rates[i-1].close < rates[i].low)
         smc.orderBlockBear = true;
   }
   smc.imbalanceBull = smc.bullFvg || (rates[1].close > rates[1].open &&
                       (rates[1].close - rates[1].open) / point > atrPts * 0.70);
   smc.imbalanceBear = smc.bearFvg || (rates[1].open > rates[1].close &&
                       (rates[1].open - rates[1].close) / point > atrPts * 0.70);
   smc.breakerBull = smc.stopHuntBull && smc.imbalanceBull;
   smc.breakerBear = smc.stopHuntBear && smc.imbalanceBear;
   double asiaHigh = 0.0;
   double asiaLow = 0.0;
   if(GetSessionRange(InpAsiaStartHour, InpAsiaEndHour, asiaHigh, asiaLow))
   {
      smc.sessionLowRaid = (rates[1].low < asiaLow && rates[1].close > asiaLow);
      smc.sessionHighRaid = (rates[1].high > asiaHigh && rates[1].close < asiaHigh);
   }
   if(smc.bullFvg) smc.scoreBull += 14.0;
   if(smc.bullFvgRetest || !InpRequireFVGRetest) smc.scoreBull += 24.0;
   if(smc.liquiditySweepBull) smc.scoreBull += 22.0;
   if(smc.stopHuntBull) smc.scoreBull += 10.0;
   if(smc.orderBlockBull) smc.scoreBull += 8.0;
   if(smc.inDiscount) smc.scoreBull += 10.0;
   if(smc.sessionLowRaid) smc.scoreBull += 12.0;
   if(smc.bearFvg) smc.scoreBear += 14.0;
   if(smc.bearFvgRetest || !InpRequireFVGRetest) smc.scoreBear += 24.0;
   if(smc.liquiditySweepBear) smc.scoreBear += 22.0;
   if(smc.stopHuntBear) smc.scoreBear += 10.0;
   if(smc.orderBlockBear) smc.scoreBear += 8.0;
   if(smc.inPremium) smc.scoreBear += 10.0;
   if(smc.sessionHighRaid) smc.scoreBear += 12.0;
   smc.scoreBull = Clamp(smc.scoreBull, 0.0, 100.0);
   smc.scoreBear = Clamp(smc.scoreBear, 0.0, 100.0);
   return smc;
}
MicroState AnalyzeMicrostructure()
{
   MicroState m;
   ZeroMemory(m);
   m.pressure = MICRO_NEUTRAL;
   m.text = "NEUTRAL";
   if(g_tickFilled < MathMin(80, g_tickSize / 2))
      return m;
   double point = SymbolInfoDouble(g_symbol, SYMBOL_POINT);
   double up = 0.0, down = 0.0;
   double spreadSum = 0.0, spreadMax = 0.0;
   double askChange = 0.0, bidChange = 0.0;
   double firstPrice = 0.0, midPrice = 0.0, lastPrice = 0.0;
   long firstTime = 0, midTime = 0, lastTime = 0;
   int n = g_tickFilled;
   for(int i = 1; i < n; i++)
   {
      MqlTick prev = TickAt(i - 1);
      MqlTick cur = TickAt(i);
      double prevMid = (prev.bid + prev.ask) * 0.5;
      double curMid = (cur.bid + cur.ask) * 0.5;
      if(i == 1)
      {
         firstPrice = prevMid;
         firstTime = prev.time_msc;
      }
      if(i == n / 2)
      {
         midPrice = curMid;
         midTime = cur.time_msc;
      }
      if(i == n - 1)
      {
         lastPrice = curMid;
         lastTime = cur.time_msc;
      }
      if(curMid > prevMid) up += 1.0;
      if(curMid < prevMid) down += 1.0;
      if(cur.ask > prev.ask) askChange += 1.0;
      if(cur.bid < prev.bid) bidChange += 1.0;
      double sp = (cur.ask - cur.bid) / point;
      spreadSum += sp;
      if(sp > spreadMax) spreadMax = sp;
   }
   double totalMoves = up + down;
   double directional = (totalMoves > 0.0 ? (up - down) / totalMoves : 0.0);
   double bidAskProxy = ((askChange + bidChange) > 0.0 ? (askChange - bidChange) / (askChange + bidChange) : 0.0);
   double durationSec = MathMax(1.0, (double)(lastTime - firstTime) / 1000.0);
   double halfDuration = MathMax(1.0, (double)(lastTime - midTime) / 1000.0);
   double totalVelocity = ((lastPrice - firstPrice) / point) / durationSec;
   double lateVelocity = ((lastPrice - midPrice) / point) / halfDuration;
   double accel = Clamp((lateVelocity - totalVelocity) / 8.0, -1.0, 1.0);
   MqlRates m1[];
   double candleAgg = 0.0;
   double rejection = 0.0;
   double breakout = 0.0;
   if(GetRates(PERIOD_M1, 30, m1))
   {
      double atr = MathMax(1.0, ATRPoints(PERIOD_M1));
      double body = (m1[1].close - m1[1].open) / point;
      double range = MathMax(point, m1[1].high - m1[1].low) / point;
      candleAgg = Clamp(body / atr, -1.0, 1.0);
      double lowerWick = (MathMin(m1[1].open, m1[1].close) - m1[1].low) / point;
      double upperWick = (m1[1].high - MathMax(m1[1].open, m1[1].close)) / point;
      rejection = Clamp((lowerWick - upperWick) / MathMax(1.0, range), -1.0, 1.0);
      double hi = HighestHigh(m1, 2, 12);
      double lo = LowestLow(m1, 2, 12);
      if(m1[1].close > hi) breakout = Clamp((m1[1].close - hi) / (atr * point), 0.0, 1.0);
      if(m1[1].close < lo) breakout = -Clamp((lo - m1[1].close) / (atr * point), 0.0, 1.0);
   }
   double avgSpread = spreadSum / MathMax(1, n - 1);
   double spreadQuality = 1.0 - Clamp(avgSpread / MathMax(1.0, InpMaxSpreadPoints), 0.0, 1.0);
   double composite = directional * 0.25 +
                      Clamp(totalVelocity / 12.0, -1.0, 1.0) * 0.18 +
                      accel * 0.15 +
                      bidAskProxy * 0.15 +
                      candleAgg * 0.13 +
                      rejection * 0.08 +
                      breakout * 0.06;
   m.tickVelocity = Clamp(totalVelocity / 12.0, -1.0, 1.0);
   m.acceleration = accel;
   m.bidAskProxy = bidAskProxy;
   m.spreadScore = spreadQuality;
   m.candleAggression = candleAgg;
   m.rejectionVelocity = rejection;
   m.breakoutStrength = breakout;
   double bull = Clamp((composite + 1.0) * 50.0, 0.0, 100.0);
   double bear = Clamp((1.0 - composite) * 50.0, 0.0, 100.0);
   bull = bull * 0.85 + spreadQuality * 15.0;
   bear = bear * 0.85 + spreadQuality * 15.0;
   m.scoreBull = Clamp(bull, 0.0, 100.0);
   m.scoreBear = Clamp(bear, 0.0, 100.0);
   if(m.scoreBull >= 62.0 && m.scoreBull > m.scoreBear + 8.0)
   {
      m.pressure = MICRO_BULLISH;
      m.text = "BULLISH PRESSURE";
   }
   else if(m.scoreBear >= 62.0 && m.scoreBear > m.scoreBull + 8.0)
   {
      m.pressure = MICRO_BEARISH;
      m.text = "BEARISH PRESSURE";
   }
   return m;
}
AIScore ScoreAI()
{
   AIScore ai;
   ZeroMemory(ai);
   ai.grade = GRADE_NONE;
   ai.reason = "No trade";
   double adx = ADXMain();
   double trendBull = 0.0;
   double trendBear = 0.0;
   if(g_h1.bias == BIAS_BULLISH) trendBull += 18.0;
   if(g_h1.bias == BIAS_BEARISH) trendBear += 18.0;
   if(g_m15.bias == BIAS_BULLISH) trendBull += 18.0;
   if(g_m15.bias == BIAS_BEARISH) trendBear += 18.0;
   if(g_m5.bias == BIAS_BULLISH) trendBull += 12.0;
   if(g_m5.bias == BIAS_BEARISH) trendBear += 12.0;
   trendBull += (EMADirection(PERIOD_M5) > 0 ? 10.0 : 0.0);
   trendBear += (EMADirection(PERIOD_M5) < 0 ? 10.0 : 0.0);
   trendBull += Clamp(adx, 0.0, 35.0) * 0.55;
   trendBear += Clamp(adx, 0.0, 35.0) * 0.55;
   MqlRates r[];
   double paBull = 0.0;
   double paBear = 0.0;
   if(GetRates(PERIOD_M5, 10, r))
   {
      double point = SymbolInfoDouble(g_symbol, SYMBOL_POINT);
      double atr = MathMax(1.0, ATRPoints(PERIOD_M5));
      double body = (r[1].close - r[1].open) / point;
      double range = MathMax(1.0, (r[1].high - r[1].low) / point);
      double bodyQuality = Clamp(MathAbs(body) / MathMax(1.0, atr), 0.0, 1.0);
      double closeLoc = (r[1].close - r[1].low) / MathMax(point, r[1].high - r[1].low);
      if(body > 0.0) paBull += 18.0 * bodyQuality;
      if(body < 0.0) paBear += 18.0 * bodyQuality;
      if(closeLoc >= 0.68) paBull += 12.0;
      if(closeLoc <= 0.32) paBear += 12.0;
      if(r[1].close > r[2].open && r[1].open < r[2].close && r[2].close < r[2].open)
         paBull += 12.0;
      if(r[1].close < r[2].open && r[1].open > r[2].close && r[2].close > r[2].open)
         paBear += 12.0;
      if(range > atr * 0.8 && body > 0.0) paBull += 7.0;
      if(range > atr * 0.8 && body < 0.0) paBear += 7.0;
   }
   double volQuality = 50.0;
   if(g_atrRatio >= 0.75 && g_atrRatio <= 1.65) volQuality = 82.0;
   else if(g_atrRatio < 0.75) volQuality = 58.0;
   else if(g_atrRatio < InpAbnormalATRRatio) volQuality = 64.0;
   else volQuality = 25.0;
   double sessionQuality = 45.0;
   if(g_session == SESSION_LONDON || g_session == SESSION_NEWYORK || g_session == SESSION_OVERLAP)
      sessionQuality = 85.0;
   else if(g_session == SESSION_ASIA)
      sessionQuality = 65.0;
   else if(g_session == SESSION_ROLLOVER)
      sessionQuality = 10.0;
   ai.trendStrength = Clamp(MathMax(trendBull, trendBear), 0.0, 100.0);
   ai.priceActionStrength = Clamp(MathMax(paBull, paBear), 0.0, 100.0);
   ai.volatilityState = volQuality;
   ai.structureQuality = MathMax((g_h1.scoreBull + g_m15.scoreBull + g_m5.scoreBull) / 3.0,
                                 (g_h1.scoreBear + g_m15.scoreBear + g_m5.scoreBear) / 3.0);
   ai.smcQuality = MathMax(g_smc.scoreBull, g_smc.scoreBear);
   ai.microQuality = MathMax(g_micro.scoreBull, g_micro.scoreBear);
   ai.sessionQuality = sessionQuality;
   double buy = trendBull * 0.18 +
                paBull * 0.11 +
                volQuality * 0.10 +
                ((g_h1.scoreBull + g_m15.scoreBull + g_m5.scoreBull + g_m1.scoreBull) / 4.0) * 0.20 +
                g_smc.scoreBull * 0.19 +
                g_micro.scoreBull * 0.14 +
                sessionQuality * 0.08;
   double sell = trendBear * 0.18 +
                 paBear * 0.11 +
                 volQuality * 0.10 +
                 ((g_h1.scoreBear + g_m15.scoreBear + g_m5.scoreBear + g_m1.scoreBear) / 4.0) * 0.20 +
                 g_smc.scoreBear * 0.19 +
                 g_micro.scoreBear * 0.14 +
                 sessionQuality * 0.08;
   if(g_newsBlocked || g_regime == REGIME_LOW_LIQUIDITY || g_regime == REGIME_NEWS_ABNORMAL)
   {
      buy *= 0.35;
      sell *= 0.35;
   }
   if(g_regime == REGIME_COMPRESSION)
   {
      buy *= 0.82;
      sell *= 0.82;
   }
   ai.buyConfidence = Clamp(buy, 0.0, 100.0);
   ai.sellConfidence = Clamp(sell, 0.0, 100.0);
   ai.noTradeConfidence = Clamp(100.0 - MathMax(ai.buyConfidence, ai.sellConfidence), 0.0, 100.0);
   double best = MathMax(ai.buyConfidence, ai.sellConfidence);
   if(best >= 90.0) ai.grade = GRADE_A_PLUS;
   else if(best >= 84.0) ai.grade = GRADE_A;
   else if(best >= InpMinConfidence) ai.grade = GRADE_B;
   ai.reason = (ai.buyConfidence > ai.sellConfidence ? "BUY confluence" :
                (ai.sellConfidence > ai.buyConfidence ? "SELL confluence" : "Neutral"));
   return ai;
}
MLPrediction PredictML(const AIScore &ai)
{
   MLPrediction ml;
   ZeroMemory(ml);
   ml.onnxLoaded = (g_onnxDirection != INVALID_HANDLE || g_onnxQuality != INVALID_HANDLE || g_onnxExit != INVALID_HANDLE);
   ml.onnxUsed = false;
   double directionLogit =
      ((ai.buyConfidence - ai.sellConfidence) / 100.0) * 1.40 +
      ((g_micro.scoreBull - g_micro.scoreBear) / 100.0) * 0.70 +
      ((g_smc.scoreBull - g_smc.scoreBear) / 100.0) * 0.90 +
      ((g_m5.scoreBull - g_m5.scoreBear) / 100.0) * 0.55;
   ml.buyProbability = Sigmoid(directionLogit);
   ml.sellProbability = 1.0 - ml.buyProbability;
   double quality = MathMax(ai.buyConfidence, ai.sellConfidence) / 100.0;
   quality = quality * 0.58 +
             (ai.structureQuality / 100.0) * 0.16 +
             (ai.smcQuality / 100.0) * 0.12 +
             (ai.microQuality / 100.0) * 0.09 +
             (ai.volatilityState / 100.0) * 0.05;
   if(SpreadPoints() > InpMaxSpreadPoints * 0.65)
      quality *= 0.82;
   if(g_regime == REGIME_VOL_EXPANSION || g_regime == REGIME_LOW_LIQUIDITY)
      quality *= 0.72;
   ml.qualityProbability = Clamp(quality, 0.0, 1.0);
   double exhaustion = 0.0;
   if(g_micro.pressure == MICRO_NEUTRAL)
      exhaustion += 0.25;
   if(g_m5.weakness)
      exhaustion += 0.25;
   if(g_atrRatio > 1.8)
      exhaustion += 0.20;
   if(g_regime == REGIME_REVERSAL)
      exhaustion += 0.20;
   ml.exitExhaustion = Clamp(exhaustion, 0.0, 1.0);
   ml.text = StringFormat("Dir %.0f/%.0f | Q %.0f%%",
                          ml.buyProbability * 100.0,
                          ml.sellProbability * 100.0,
                          ml.qualityProbability * 100.0);
   if(ml.onnxLoaded)
      ml.text += " | ONNX ready";
   return ml;
}
void BuildTradePlan(TradePlan &plan)
{
   ZeroMemory(plan);
   plan.valid = false;
   plan.reason = "No setup";
   plan.grade = GRADE_NONE;
   if(!CanTradeSymbol())
   {
      plan.reason = "Symbol not tradable";
      return;
   }
   if(!IsMarketOpen())
   {
      plan.reason = "Market closed";
      return;
   }
   string riskReason = "";
   if(EvaluateRisk(riskReason) != RISK_CLEAR && EvaluateRisk(riskReason) != RISK_CAUTION)
   {
      plan.reason = riskReason;
      return;
   }
   if(TimeCurrent() < g_cooldownUntil)
   {
      plan.reason = "Post-trade cooldown";
      return;
   }
   if(SpreadPoints() > InpMaxSpreadPoints)
   {
      plan.reason = "Spread filter";
      return;
   }
   if(g_newsBlocked)
   {
      plan.reason = g_newsReason;
      return;
   }
   if(InpUseSessionFilter && (g_session == SESSION_ROLLOVER || g_session == SESSION_OFF))
   {
      plan.reason = "Low-liquidity session";
      return;
   }
   if(g_regime == REGIME_LOW_LIQUIDITY || g_regime == REGIME_NEWS_ABNORMAL)
   {
      plan.reason = "Blocked regime";
      return;
   }
   if(g_regime == REGIME_VOL_EXPANSION && MathMax(g_ai.buyConfidence, g_ai.sellConfidence) < 88.0)
   {
      plan.reason = "Volatility expansion needs A+ confirmation";
      return;
   }
   bool buyBias = (g_h1.bias == BIAS_BULLISH &&
                   g_m15.bias == BIAS_BULLISH &&
                   (g_m5.bosBull || g_m5.mssBull || g_m5.bias == BIAS_BULLISH) &&
                   (g_m1.bias == BIAS_BULLISH || g_m1.mssBull));
   bool sellBias = (g_h1.bias == BIAS_BEARISH &&
                    g_m15.bias == BIAS_BEARISH &&
                    (g_m5.bosBear || g_m5.mssBear || g_m5.bias == BIAS_BEARISH) &&
                    (g_m1.bias == BIAS_BEARISH || g_m1.mssBear));
   bool buySMC = (g_smc.liquiditySweepBull || g_smc.stopHuntBull || g_smc.sessionLowRaid) &&
                 (g_smc.bullFvgRetest || !InpRequireFVGRetest) &&
                 (g_smc.inDiscount || g_regime == REGIME_TRENDING_UP);
   bool sellSMC = (g_smc.liquiditySweepBear || g_smc.stopHuntBear || g_smc.sessionHighRaid) &&
                  (g_smc.bearFvgRetest || !InpRequireFVGRetest) &&
                  (g_smc.inPremium || g_regime == REGIME_TRENDING_DOWN);
   if(g_session == SESSION_ASIA && g_regime == REGIME_RANGING)
   {
      buyBias = buyBias || (g_smc.liquiditySweepBull && g_m1.mssBull);
      sellBias = sellBias || (g_smc.liquiditySweepBear && g_m1.mssBear);
   }
   bool buyML = (g_ml.buyProbability >= 0.58 && g_ml.qualityProbability >= InpMinMLQuality);
   bool sellML = (g_ml.sellProbability >= 0.58 && g_ml.qualityProbability >= InpMinMLQuality);
   bool buyMicro = (g_micro.pressure == MICRO_BULLISH && g_micro.scoreBull >= 61.0);
   bool sellMicro = (g_micro.pressure == MICRO_BEARISH && g_micro.scoreBear >= 61.0);
   int direction = 0;
   double conf = 0.0;
   if(buyBias && buySMC && buyML && buyMicro && g_ai.buyConfidence >= InpMinConfidence &&
      g_ai.buyConfidence > g_ai.sellConfidence + 7.0)
   {
      direction = 1;
      conf = g_ai.buyConfidence;
   }
   else if(sellBias && sellSMC && sellML && sellMicro && g_ai.sellConfidence >= InpMinConfidence &&
           g_ai.sellConfidence > g_ai.buyConfidence + 7.0)
   {
      direction = -1;
      conf = g_ai.sellConfidence;
   }
   else
   {
      plan.reason = "Confluence incomplete";
      return;
   }
   double point = SymbolInfoDouble(g_symbol, SYMBOL_POINT);
   double ask = SymbolInfoDouble(g_symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(g_symbol, SYMBOL_BID);
   double price = (direction > 0 ? ask : bid);
   double atrPts = MathMax(ATRPoints(PERIOD_M5), 50.0);
   double structureStopPts = atrPts * InpStopATRMultiplier;
   if(direction > 0 && g_m5.swingLow > 0.0)
      structureStopPts = MathMax(structureStopPts, (price - g_m5.swingLow) / point + 25.0);
   if(direction < 0 && g_m5.swingHigh > 0.0)
      structureStopPts = MathMax(structureStopPts, (g_m5.swingHigh - price) / point + 25.0);
   structureStopPts = Clamp(structureStopPts, atrPts * 0.85, atrPts * 2.4);
   double expectedMove = MathMax(atrPts * InpTargetATRMultiplier,
                                 SpreadPoints() * 3.0 + 25.0);
   if(direction > 0 && g_smc.bullFvgHigh > 0.0)
      expectedMove = MathMax(expectedMove, (g_smc.bullFvgHigh - price) / point + atrPts * 0.7);
   if(direction < 0 && g_smc.bearFvgLow > 0.0)
      expectedMove = MathMax(expectedMove, (price - g_smc.bearFvgLow) / point + atrPts * 0.7);
   if(expectedMove < SpreadPoints() * 3.0)
   {
      plan.reason = "Expected move too small for trade cost";
      return;
   }
   int slots = (int)MathMax(1, MathMin(InpBurstSlots, MAX_BURST_SLOTS));
   slots = MathMin(slots, MathMax(1, InpMaxDailyTrades - g_tradesToday));
   double lot = CalculateSignalLot(conf, structureStopPts, slots);
   if(lot < InpMinLot)
   {
      plan.reason = "Risk sizing below broker minimum";
      return;
   }
   double totalLot = lot * slots;
   if(totalLot > InpMaxTotalLot)
   {
      lot = NormalizeLot(InpMaxTotalLot / slots);
      totalLot = lot * slots;
   }
   if(lot < InpMinLot || totalLot <= 0.0)
   {
      plan.reason = "Total exposure cap blocked order";
      return;
   }
   plan.valid = true;
   plan.direction = direction;
   plan.slots = slots;
   plan.lotPerSlot = lot;
   plan.totalLot = totalLot;
   plan.entry = price;
   plan.stopDistancePts = structureStopPts;
   plan.expectedMovePts = expectedMove;
   plan.stopLoss = NormalizePrice(direction > 0 ? price - structureStopPts * point : price + structureStopPts * point);
   plan.takeProfit = NormalizePrice(direction > 0 ? price + expectedMove * point : price - expectedMove * point);
   plan.targetUsdPerSlot = TargetUSDForLot(lot) * Clamp(g_atrRatio, 0.85, 1.35);
   plan.confidence = conf;
   plan.quality = g_ml.qualityProbability;
   plan.grade = g_ai.grade;
   plan.reason = StringFormat("%s %s %.1f%% Q %.0f%%",
                              (direction > 0 ? "BUY" : "SELL"),
                              GradeText(plan.grade),
                              plan.confidence,
                              plan.quality * 100.0);
}
RiskState EvaluateRisk(string &reason)
{
   reason = "Risk clear";
   if(!TerminalInfoInteger(TERMINAL_TRADE_ALLOWED) || !MQLInfoInteger(MQL_TRADE_ALLOWED))
   {
      reason = "Algo trading disabled";
      return RISK_BLOCKED;
   }
   if(g_dayStartEquity <= 0.0)
      g_dayStartEquity = AccountInfoDouble(ACCOUNT_EQUITY);
   double eq = AccountInfoDouble(ACCOUNT_EQUITY);
   double dayLossPct = (g_dayStartEquity > 0.0 ? (g_dayStartEquity - eq) / g_dayStartEquity * 100.0 : 0.0);
   if(dayLossPct >= InpEquityKillSwitchPct)
   {
      reason = "Equity kill switch";
      return RISK_KILL_SWITCH;
   }
   if(g_dailyDrawdown >= InpMaxDailyDrawdownPct || dayLossPct >= InpMaxDailyDrawdownPct)
   {
      reason = "Daily drawdown stop";
      return RISK_DAILY_STOP;
   }
   if(g_consecutiveLosses >= InpMaxConsecutiveLosses)
   {
      if(g_lossCooldownUntil == 0)
         g_lossCooldownUntil = TimeCurrent() + InpLossCooldownMinutes * 60;
      if(TimeCurrent() < g_lossCooldownUntil)
      {
         reason = "Loss-streak cooldown";
         return RISK_LOSS_COOLDOWN;
      }
   }
   if(g_tradesToday >= InpMaxDailyTrades)
   {
      reason = "Max daily trades reached";
      return RISK_BLOCKED;
   }
   if(SpreadPoints() > InpMaxSpreadPoints)
   {
      reason = "Spread above cap";
      return RISK_BLOCKED;
   }
   if(g_atrRatio >= InpAbnormalATRRatio)
   {
      reason = "Abnormal volatility";
      return RISK_CAUTION;
   }
   if(InpBlockLowLiquidity && g_session == SESSION_ROLLOVER)
   {
      reason = "Low liquidity";
      return RISK_BLOCKED;
   }
   return RISK_CLEAR;
}
//====================================================================
//  Execution
//====================================================================
bool ExecuteTradePlan(const TradePlan &plan)
{
   if(!plan.valid || plan.direction == 0)
      return false;
   bool allOk = true;
   string side = (plan.direction > 0 ? "BUY" : "SELL");
   for(int i = 0; i < plan.slots; i++)
   {
      if(CountPositions() >= MAX_TRACKED_POS)
      {
         allOk = false;
         break;
      }
      string cmt = StringFormat("%s %s %s slot %d/%d",
                                InpBotName, side, GradeText(plan.grade), i + 1, plan.slots);
      bool ok = OpenMarketOrder(plan.direction, plan.lotPerSlot, plan.stopLoss, plan.takeProfit, cmt);
      if(!ok)
         allOk = false;
   }
   RestoreDailyStats();
   return allOk;
}
bool OpenMarketOrder(const int direction, const double lot, const double sl, const double tp, const string comment)
{
   MqlTradeRequest req;
   MqlTradeResult  res;
   ZeroMemory(req);
   ZeroMemory(res);
   double ask = SymbolInfoDouble(g_symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(g_symbol, SYMBOL_BID);
   double price = (direction > 0 ? ask : bid);
   req.action = TRADE_ACTION_DEAL;
   req.symbol = g_symbol;
   req.magic = InpMagicNumber;
   req.volume = NormalizeLot(lot);
   req.type = (direction > 0 ? ORDER_TYPE_BUY : ORDER_TYPE_SELL);
   req.price = NormalizePrice(price);
   req.sl = sl;
   req.tp = tp;
   req.deviation = InpDeviationPoints;
   req.type_filling = GetFillMode();
   req.comment = comment;
   bool ok = OrderSend(req, res);
   if(!ok || (res.retcode != TRADE_RETCODE_DONE && res.retcode != TRADE_RETCODE_PLACED))
   {
      Print("PHANTOM order failed retcode=", res.retcode, " err=", GetLastError(), " comment=", res.comment);
      return false;
   }
   return true;
}
bool CloseTicket(const ulong ticket, const string reason)
{
   if(!PositionSelectByTicket(ticket))
      return false;
   long type = PositionGetInteger(POSITION_TYPE);
   double volume = PositionGetDouble(POSITION_VOLUME);
   double price = (type == POSITION_TYPE_BUY ?
                   SymbolInfoDouble(g_symbol, SYMBOL_BID) :
                   SymbolInfoDouble(g_symbol, SYMBOL_ASK));
   MqlTradeRequest req;
   MqlTradeResult  res;
   ZeroMemory(req);
   ZeroMemory(res);
   req.action = TRADE_ACTION_DEAL;
   req.position = ticket;
   req.symbol = g_symbol;
   req.magic = InpMagicNumber;
   req.volume = volume;
   req.type = (type == POSITION_TYPE_BUY ? ORDER_TYPE_SELL : ORDER_TYPE_BUY);
   req.price = NormalizePrice(price);
   req.deviation = InpDeviationPoints;
   req.type_filling = GetFillMode();
   req.comment = "PSP close: " + reason;
   bool ok = OrderSend(req, res);
   if(!ok || (res.retcode != TRADE_RETCODE_DONE && res.retcode != TRADE_RETCODE_PLACED))
   {
      Print("PHANTOM close failed ticket=", ticket, " retcode=", res.retcode, " err=", GetLastError());
      return false;
   }
   g_cooldownUntil = TimeCurrent() + InpCooldownSec;
   RestoreDailyStats();
   return true;
}
bool ClosePartialTicket(const ulong ticket, const double volume, const string reason)
{
   if(!PositionSelectByTicket(ticket))
      return false;
   double currentVol = PositionGetDouble(POSITION_VOLUME);
   double closeVol = NormalizeLot(MathMin(volume, currentVol));
   double minVol = SymbolInfoDouble(g_symbol, SYMBOL_VOLUME_MIN);
   if(closeVol < minVol || closeVol >= currentVol)
      return false;
   long type = PositionGetInteger(POSITION_TYPE);
   double price = (type == POSITION_TYPE_BUY ?
                   SymbolInfoDouble(g_symbol, SYMBOL_BID) :
                   SymbolInfoDouble(g_symbol, SYMBOL_ASK));
   MqlTradeRequest req;
   MqlTradeResult  res;
   ZeroMemory(req);
   ZeroMemory(res);
   req.action = TRADE_ACTION_DEAL;
   req.position = ticket;
   req.symbol = g_symbol;
   req.magic = InpMagicNumber;
   req.volume = closeVol;
   req.type = (type == POSITION_TYPE_BUY ? ORDER_TYPE_SELL : ORDER_TYPE_BUY);
   req.price = NormalizePrice(price);
   req.deviation = InpDeviationPoints;
   req.type_filling = GetFillMode();
   req.comment = "PSP partial: " + reason;
   bool ok = OrderSend(req, res);
   if(!ok || (res.retcode != TRADE_RETCODE_DONE && res.retcode != TRADE_RETCODE_PLACED))
   {
      Print("PHANTOM partial close failed ticket=", ticket, " retcode=", res.retcode, " err=", GetLastError());
      return false;
   }
   return true;
}
bool ModifyStopLoss(const ulong ticket, const double sl, const double tp)
{
   if(!PositionSelectByTicket(ticket))
      return false;
   MqlTradeRequest req;
   MqlTradeResult  res;
   ZeroMemory(req);
   ZeroMemory(res);
   req.action = TRADE_ACTION_SLTP;
   req.position = ticket;
   req.symbol = g_symbol;
   req.magic = InpMagicNumber;
   req.sl = NormalizePrice(sl);
   req.tp = NormalizePrice(tp);
   bool ok = OrderSend(req, res);
   return (ok && (res.retcode == TRADE_RETCODE_DONE || res.retcode == TRADE_RETCODE_PLACED));
}
void ManageOpenPositions()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket)) continue;
      if((ulong)PositionGetInteger(POSITION_MAGIC) != InpMagicNumber) continue;
      if(PositionGetString(POSITION_SYMBOL) != g_symbol) continue;
      ExitDecision decision = EvaluateExit(ticket);
      if(decision.action == EXIT_PARTIAL)
      {
         int idx = SlotIndex(ticket, true);
         if(idx >= 0 && !g_slots[idx].partialTaken &&
            ClosePartialTicket(ticket, decision.partialVolume, decision.reason))
         {
            g_slots[idx].partialTaken = true;
         }
      }
      else if(decision.action == EXIT_BREAKEVEN || decision.action == EXIT_TRAIL)
      {
         double tp = PositionGetDouble(POSITION_TP);
         ModifyStopLoss(ticket, decision.newStop, tp);
      }
      else if(decision.action == EXIT_CLOSE)
      {
         CloseTicket(ticket, decision.reason);
      }
   }
}
ExitDecision EvaluateExit(const ulong ticket)
{
   ExitDecision d;
   ZeroMemory(d);
   d.action = EXIT_HOLD;
   d.reason = "Hold";
   if(!PositionSelectByTicket(ticket))
      return d;
   int idx = SlotIndex(ticket, true);
   double profit = PositionGetDouble(POSITION_PROFIT) +
                   PositionGetDouble(POSITION_SWAP) +
                   PositionGetDouble(POSITION_COMMISSION);
   double volume = PositionGetDouble(POSITION_VOLUME);
   double target = TargetUSDForLot(volume);
   double emergencyLoss = StopLossUSDForLot(volume);
   long type = PositionGetInteger(POSITION_TYPE);
   double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
   double sl = PositionGetDouble(POSITION_SL);
   double tp = PositionGetDouble(POSITION_TP);
   double point = SymbolInfoDouble(g_symbol, SYMBOL_POINT);
   double bid = SymbolInfoDouble(g_symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(g_symbol, SYMBOL_ASK);
   double current = (type == POSITION_TYPE_BUY ? bid : ask);
   double movedPts = (type == POSITION_TYPE_BUY ? (current - openPrice) : (openPrice - current)) / point;
   if(idx >= 0 && profit > g_slots[idx].peakProfit)
      g_slots[idx].peakProfit = profit;
   if(profit <= -emergencyLoss)
   {
      d.action = EXIT_CLOSE;
      d.reason = "Emergency per-slot loss";
      return d;
   }
   if(idx >= 0 && !g_slots[idx].partialTaken &&
      profit >= target * InpPartialAtTargetPct / 100.0)
   {
      double closeVol = volume * InpPartialClosePct / 100.0;
      d.action = EXIT_PARTIAL;
      d.partialVolume = closeVol;
      d.reason = "Target partial";
      return d;
   }
   if(profit >= target * InpBreakEvenAtTargetPct / 100.0)
   {
      double beBufferPts = MathMax(SpreadPoints() + 8.0, ATRPoints(PERIOD_M1) * 0.12);
      double be = (type == POSITION_TYPE_BUY ?
                   openPrice + beBufferPts * point :
                   openPrice - beBufferPts * point);
      bool improve = (type == POSITION_TYPE_BUY ? (sl == 0.0 || be > sl) : (sl == 0.0 || be < sl));
      if(improve)
      {
         d.action = EXIT_BREAKEVEN;
         d.newStop = NormalizePrice(be);
         d.reason = "Breakeven lock";
         return d;
      }
   }
   if(profit >= target * InpTrailStartTargetPct / 100.0)
   {
      double trailPts = MathMax(ATRPoints(PERIOD_M1) * 0.75, SpreadPoints() * 2.2);
      double trailed = (type == POSITION_TYPE_BUY ?
                        current - trailPts * point :
                        current + trailPts * point);
      bool improveTrail = (type == POSITION_TYPE_BUY ? (sl == 0.0 || trailed > sl) : (sl == 0.0 || trailed < sl));
      if(improveTrail)
      {
         d.action = EXIT_TRAIL;
         d.newStop = NormalizePrice(trailed);
         d.reason = "ATR smart trail";
         return d;
      }
   }
   if(idx >= 0 && g_slots[idx].peakProfit > target)
   {
      double giveback = g_slots[idx].peakProfit - profit;
      double maxGiveback = MathMax(0.15, target * InpTrailGivebackPct / 100.0);
      if(giveback >= maxGiveback)
      {
         d.action = EXIT_CLOSE;
         d.reason = "Profit lock giveback";
         return d;
      }
   }
   MLPrediction ml = PredictML(g_ai);
   bool oppositeMicro = (type == POSITION_TYPE_BUY && g_micro.pressure == MICRO_BEARISH) ||
                        (type == POSITION_TYPE_SELL && g_micro.pressure == MICRO_BULLISH);
   bool structureWeak = (type == POSITION_TYPE_BUY && (g_m1.mssBear || g_m5.weakness)) ||
                        (type == POSITION_TYPE_SELL && (g_m1.mssBull || g_m5.weakness));
   if(profit > 0.0 && (ml.exitExhaustion >= 0.62 || (oppositeMicro && structureWeak)))
   {
      d.action = EXIT_CLOSE;
      d.reason = "Momentum exhaustion";
      return d;
   }
   if(movedPts > g_currentATRPoints * 1.2 && profit <= 0.0)
   {
      d.action = EXIT_CLOSE;
      d.reason = "Failed continuation";
      return d;
   }
   return d;
}
//====================================================================
//  Utility calculations
//====================================================================
void UpdateTickBuffer()
{
   MqlTick tick;
   if(!SymbolInfoTick(g_symbol, tick))
      return;
   if(tick.time_msc == g_lastTickMsc)
      return;
   g_lastTickMsc = tick.time_msc;
   g_tickBuffer[g_tickWrite] = tick;
   g_tickWrite = (g_tickWrite + 1) % g_tickSize;
   if(g_tickFilled < g_tickSize)
      g_tickFilled++;
}
MqlTick TickAt(const int chronologicalIndex)
{
   int start = (g_tickWrite - g_tickFilled + g_tickSize) % g_tickSize;
   int idx = (start + chronologicalIndex) % g_tickSize;
   return g_tickBuffer[idx];
}
void SyncTrackedSlots()
{
   for(int i = 0; i < MAX_TRACKED_POS; i++)
   {
      if(g_slots[i].ticket == 0) continue;
      if(!PositionSelectByTicket(g_slots[i].ticket))
      {
         g_slots[i].ticket = 0;
         g_slots[i].peakProfit = 0.0;
         g_slots[i].partialTaken = false;
         g_slots[i].openTime = 0;
      }
   }
   for(int p = PositionsTotal() - 1; p >= 0; p--)
   {
      ulong ticket = PositionGetTicket(p);
      if(ticket == 0 || !PositionSelectByTicket(ticket)) continue;
      if((ulong)PositionGetInteger(POSITION_MAGIC) != InpMagicNumber) continue;
      if(PositionGetString(POSITION_SYMBOL) != g_symbol) continue;
      SlotIndex(ticket, true);
   }
}
int SlotIndex(const ulong ticket, const bool create)
{
   for(int i = 0; i < MAX_TRACKED_POS; i++)
      if(g_slots[i].ticket == ticket)
         return i;
   if(!create)
      return -1;
   for(int j = 0; j < MAX_TRACKED_POS; j++)
   {
      if(g_slots[j].ticket == 0)
      {
         g_slots[j].ticket = ticket;
         g_slots[j].peakProfit = 0.0;
         g_slots[j].partialTaken = false;
         g_slots[j].openTime = (datetime)PositionGetInteger(POSITION_TIME);
         return j;
      }
   }
   return -1;
}
double ATRPoints(const ENUM_TIMEFRAMES tf)
{
   int h = hATR_M5;
   if(tf == PERIOD_M1) h = hATR_M1;
   else if(tf == PERIOD_M15) h = hATR_M15;
   else if(tf == PERIOD_H1) h = hATR_H1;
   double value = BufferValue(h, 0, 1);
   double point = SymbolInfoDouble(g_symbol, SYMBOL_POINT);
   if(value == EMPTY_VALUE || point <= 0.0)
      return 0.0;
   return value / point;
}
double ATRRatioM5()
{
   double atr[];
   ArraySetAsSeries(atr, true);
   int copied = CopyBuffer(hATR_M5, 0, 1, 80, atr);
   if(copied < 20)
      return 1.0;
   double sum = 0.0;
   for(int i = 0; i < copied; i++)
      sum += atr[i];
   double avg = sum / copied;
   if(avg <= 0.0)
      return 1.0;
   return atr[0] / avg;
}
double BufferValue(const int handle, const int buffer, const int shift)
{
   if(handle == INVALID_HANDLE)
      return EMPTY_VALUE;
   double data[];
   ArraySetAsSeries(data, true);
   if(CopyBuffer(handle, buffer, shift, 1, data) != 1)
      return EMPTY_VALUE;
   return data[0];
}
bool GetRates(const ENUM_TIMEFRAMES tf, const int count, MqlRates &rates[])
{
   ArraySetAsSeries(rates, true);
   int copied = CopyRates(g_symbol, tf, 0, count, rates);
   return copied >= count;
}
double HighestHigh(const MqlRates &rates[], const int from, const int count)
{
   double v = 0.0;
   int maxI = MathMin(ArraySize(rates) - 1, from + count - 1);
   for(int i = from; i <= maxI; i++)
      if(rates[i].high > v || v == 0.0)
         v = rates[i].high;
   return v;
}
double LowestLow(const MqlRates &rates[], const int from, const int count)
{
   double v = 0.0;
   int maxI = MathMin(ArraySize(rates) - 1, from + count - 1);
   for(int i = from; i <= maxI; i++)
      if(rates[i].low < v || v == 0.0)
         v = rates[i].low;
   return v;
}
double EMAValue(const ENUM_TIMEFRAMES tf, const bool fast, const int shift)
{
   int h = INVALID_HANDLE;
   if(tf == PERIOD_M1)  h = fast ? hEMA_F_M1  : hEMA_S_M1;
   if(tf == PERIOD_M5)  h = fast ? hEMA_F_M5  : hEMA_S_M5;
   if(tf == PERIOD_M15) h = fast ? hEMA_F_M15 : hEMA_S_M15;
   if(tf == PERIOD_H1)  h = fast ? hEMA_F_H1  : hEMA_S_H1;
   return BufferValue(h, 0, shift);
}
int EMADirection(const ENUM_TIMEFRAMES tf)
{
   double f1 = EMAValue(tf, true, 1);
   double s1 = EMAValue(tf, false, 1);
   double f4 = EMAValue(tf, true, 4);
   if(f1 == EMPTY_VALUE || s1 == EMPTY_VALUE || f4 == EMPTY_VALUE)
      return 0;
   double slope = f1 - f4;
   if(f1 > s1 && slope > 0.0) return 1;
   if(f1 < s1 && slope < 0.0) return -1;
   return 0;
}
double ADXMain()
{
   double v = BufferValue(hADX_M5, 0, 1);
   return (v == EMPTY_VALUE ? 0.0 : v);
}
double SpreadPoints()
{
   double ask = SymbolInfoDouble(g_symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(g_symbol, SYMBOL_BID);
   double point = SymbolInfoDouble(g_symbol, SYMBOL_POINT);
   if(point <= 0.0) return 999999.0;
   return (ask - bid) / point;
}
double NormalizePrice(const double p)
{
   return NormalizeDouble(p, (int)SymbolInfoInteger(g_symbol, SYMBOL_DIGITS));
}
double NormalizeLot(const double lot)
{
   double minv = MathMax(SymbolInfoDouble(g_symbol, SYMBOL_VOLUME_MIN), InpMinLot);
   double maxv = MathMin(SymbolInfoDouble(g_symbol, SYMBOL_VOLUME_MAX), InpMaxLot);
   double step = SymbolInfoDouble(g_symbol, SYMBOL_VOLUME_STEP);
   if(step <= 0.0) step = 0.01;
   double v = MathMax(minv, MathMin(maxv, lot));
   v = MathFloor(v / step) * step;
   return NormalizeDouble(v, 2);
}
double CalculateSignalLot(const double confidence, const double stopPts, const int slots)
{
   double lot = InpBaseLotSize;
   if(confidence >= 90.0) lot *= 1.25;
   else if(confidence < 84.0) lot *= 0.80;
   if(g_risk == RISK_CAUTION) lot *= 0.70;
   if(g_dailyDrawdown >= InpMaxDailyDrawdownPct * 0.50) lot *= 0.55;
   if(g_regime == REGIME_VOL_EXPANSION) lot *= 0.65;
   if(g_session == SESSION_ASIA) lot *= 0.75;
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   double riskMoney = equity * InpRiskPerSignalPct / 100.0;
   double tickValue = SymbolInfoDouble(g_symbol, SYMBOL_TRADE_TICK_VALUE);
   double tickSize = SymbolInfoDouble(g_symbol, SYMBOL_TRADE_TICK_SIZE);
   double point = SymbolInfoDouble(g_symbol, SYMBOL_POINT);
   if(tickValue > 0.0 && tickSize > 0.0 && point > 0.0 && stopPts > 0.0)
   {
      double lossPerLot = (stopPts * point / tickSize) * tickValue;
      if(lossPerLot > 0.0)
      {
         double riskLot = riskMoney / (lossPerLot * MathMax(1, slots));
         lot = MathMin(lot, riskLot);
      }
   }
   lot = MathMin(lot, InpMaxTotalLot / MathMax(1, slots));
   return NormalizeLot(lot);
}
double TargetUSDForLot(const double lot)
{
   return MathMax(0.10, (lot / 0.01) * InpProfitPer001LotUSD);
}
double StopLossUSDForLot(const double lot)
{
   return MathMax(0.20, (lot / 0.01) * InpEmergencyLossPer001USD);
}
double DailyPnL()
{
   double pnl = 0.0;
   if(!HistorySelect(g_dayStart, TimeCurrent()))
      return pnl;
   int total = HistoryDealsTotal();
   for(int i = 0; i < total; i++)
   {
      ulong ticket = HistoryDealGetTicket(i);
      if(ticket == 0) continue;
      if((ulong)HistoryDealGetInteger(ticket, DEAL_MAGIC) != InpMagicNumber) continue;
      if(HistoryDealGetString(ticket, DEAL_SYMBOL) != g_symbol) continue;
      if(HistoryDealGetInteger(ticket, DEAL_ENTRY) == DEAL_ENTRY_OUT)
      {
         pnl += HistoryDealGetDouble(ticket, DEAL_PROFIT) +
                HistoryDealGetDouble(ticket, DEAL_SWAP) +
                HistoryDealGetDouble(ticket, DEAL_COMMISSION);
      }
   }
   return pnl;
}
int CountPositions()
{
   int c = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket)) continue;
      if((ulong)PositionGetInteger(POSITION_MAGIC) == InpMagicNumber &&
         PositionGetString(POSITION_SYMBOL) == g_symbol)
         c++;
   }
   return c;
}
double TotalOpenLots()
{
   double lots = 0.0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket)) continue;
      if((ulong)PositionGetInteger(POSITION_MAGIC) == InpMagicNumber &&
         PositionGetString(POSITION_SYMBOL) == g_symbol)
         lots += PositionGetDouble(POSITION_VOLUME);
   }
   return lots;
}
double FloatingProfit()
{
   double profit = 0.0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket)) continue;
      if((ulong)PositionGetInteger(POSITION_MAGIC) == InpMagicNumber &&
         PositionGetString(POSITION_SYMBOL) == g_symbol)
      {
         profit += PositionGetDouble(POSITION_PROFIT) +
                   PositionGetDouble(POSITION_SWAP) +
                   PositionGetDouble(POSITION_COMMISSION);
      }
   }
   return profit;
}
int CountConsecutiveLosses()
{
   int losses = 0;
   if(!HistorySelect(0, TimeCurrent()))
      return 0;
   for(int i = HistoryDealsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = HistoryDealGetTicket(i);
      if(ticket == 0) continue;
      if((ulong)HistoryDealGetInteger(ticket, DEAL_MAGIC) != InpMagicNumber) continue;
      if(HistoryDealGetString(ticket, DEAL_SYMBOL) != g_symbol) continue;
      if(HistoryDealGetInteger(ticket, DEAL_ENTRY) != DEAL_ENTRY_OUT) continue;
      double pnl = HistoryDealGetDouble(ticket, DEAL_PROFIT) +
                   HistoryDealGetDouble(ticket, DEAL_SWAP) +
                   HistoryDealGetDouble(ticket, DEAL_COMMISSION);
      if(pnl < 0.0) losses++;
      else break;
   }
   return losses;
}
datetime DayStart(const datetime ts)
{
   MqlDateTime d;
   TimeToStruct(ts, d);
   d.hour = 0;
   d.min = 0;
   d.sec = 0;
   return StructToTime(d);
}
bool InHourRange(const int hour, const int startHour, const int endHour)
{
   if(startHour == endHour)
      return true;
   if(startHour < endHour)
      return (hour >= startHour && hour < endHour);
   return (hour >= startHour || hour < endHour);
}
bool GetSessionRange(const int startHour, const int endHour, double &hi, double &lo)
{
   hi = 0.0;
   lo = 0.0;
   MqlRates rates[];
   if(!GetRates(PERIOD_M15, 120, rates))
      return false;
   for(int i = 1; i < ArraySize(rates); i++)
   {
      MqlDateTime t;
      TimeToStruct(rates[i].time, t);
      if(rates[i].time < g_dayStart)
         break;
      if(!InHourRange(t.hour, startHour, endHour))
         continue;
      if(hi == 0.0 || rates[i].high > hi) hi = rates[i].high;
      if(lo == 0.0 || rates[i].low < lo) lo = rates[i].low;
   }
   return (hi > 0.0 && lo > 0.0);
}
bool CanTradeSymbol()
{
   return SymbolSelect(g_symbol, true);
}
bool IsMarketOpen()
{
   ENUM_SYMBOL_TRADE_MODE mode = (ENUM_SYMBOL_TRADE_MODE)SymbolInfoInteger(g_symbol, SYMBOL_TRADE_MODE);
   return (mode == SYMBOL_TRADE_MODE_FULL ||
           mode == SYMBOL_TRADE_MODE_LONGONLY ||
           mode == SYMBOL_TRADE_MODE_SHORTONLY);
}
ENUM_ORDER_TYPE_FILLING GetFillMode()
{
   uint f = (uint)SymbolInfoInteger(g_symbol, SYMBOL_FILLING_MODE);
   if((f & SYMBOL_FILLING_FOK) != 0) return ORDER_FILLING_FOK;
   if((f & SYMBOL_FILLING_IOC) != 0) return ORDER_FILLING_IOC;
   return ORDER_FILLING_RETURN;
}
double Clamp(const double v, const double lo, const double hi)
{
   return MathMax(lo, MathMin(hi, v));
}
double Sigmoid(const double x)
{
   return 1.0 / (1.0 + MathExp(-x));
}
string Lower(string s)
{
   StringToLower(s);
   return s;
}
bool ContainsKeyword(const string text, const string keywords)
{
   string lowerText = Lower(text);
   string parts[];
   int n = StringSplit(keywords, ';', parts);
   for(int i = 0; i < n; i++)
   {
      string k = Lower(parts[i]);
      StringTrimLeft(k);
      StringTrimRight(k);
      if(k != "" && StringFind(lowerText, k) >= 0)
         return true;
   }
   return false;
}
string RegimeText()
{
   if(g_regime == REGIME_TRENDING_UP) return "TREND UP";
   if(g_regime == REGIME_TRENDING_DOWN) return "TREND DOWN";
   if(g_regime == REGIME_RANGING) return "RANGING";
   if(g_regime == REGIME_COMPRESSION) return "COMPRESSION";
   if(g_regime == REGIME_VOL_EXPANSION) return "VOL EXPANSION";
   if(g_regime == REGIME_LOW_LIQUIDITY) return "LOW LIQ";
   if(g_regime == REGIME_REVERSAL) return "REVERSAL";
   if(g_regime == REGIME_BREAKOUT) return "BREAKOUT";
   if(g_regime == REGIME_NEWS_ABNORMAL) return "NEWS BLOCK";
   return "UNKNOWN";
}
string SessionText()
{
   if(g_session == SESSION_ASIA) return "ASIA";
   if(g_session == SESSION_LONDON) return "LONDON";
   if(g_session == SESSION_NEWYORK) return "NEW YORK";
   if(g_session == SESSION_OVERLAP) return "OVERLAP";
   if(g_session == SESSION_ROLLOVER) return "ROLLOVER";
   return "OFF";
}
string BiasText(const StructureBias bias)
{
   if(bias == BIAS_BULLISH) return "BULLISH";
   if(bias == BIAS_BEARISH) return "BEARISH";
   if(bias == BIAS_CONFLICT) return "CONFLICT";
   return "NEUTRAL";
}
string PressureText(const MicroPressure pressure)
{
   if(pressure == MICRO_BULLISH) return "BULLISH";
   if(pressure == MICRO_BEARISH) return "BEARISH";
   return "NEUTRAL";
}
string GradeText(const TradeGrade grade)
{
   if(grade == GRADE_A_PLUS) return "A+";
   if(grade == GRADE_A) return "A";
   if(grade == GRADE_B) return "B";
   return "--";
}
string RiskText()
{
   if(g_risk == RISK_CAUTION) return "CAUTION";
   if(g_risk == RISK_BLOCKED) return "BLOCKED";
   if(g_risk == RISK_DAILY_STOP) return "DAILY STOP";
   if(g_risk == RISK_LOSS_COOLDOWN) return "LOSS CD";
   if(g_risk == RISK_KILL_SWITCH) return "KILL";
   return "CLEAR";
}
color StateColor(const double score, const bool inverse=false)
{
   double s = inverse ? 100.0 - score : score;
   if(s >= 75.0) return C_GREEN;
   if(s >= 50.0) return C_GOLD;
   if(s >= 30.0) return C_ORANGE;
   return C_RED;
}
//====================================================================
//  Dashboard
//====================================================================
void InitDashboard()
{
   int x = InpDashX;
   int y = InpDashY;
   int w = InpDashWidth;
   int f = InpDashFontSize;
   DashRect("frame", x, y, w, 542, C_BG, C_ACCENT, 2);
   DashRect("head", x + 2, y + 2, w - 4, 58, C_PANEL2, C_EDGE, 1);
   DashLabel("title", x + 12, y + 9, InpBotName, C_GOLD, f + 4, "Arial Black");
   DashLabel("sub", x + 12, y + 32, "Institutional XAUUSD M5 | M1/M15/H1 confirmation", C_ACCENT, f, "Arial");
   DashLabel("live", x + w - 78, y + 14, "LIVE", C_GREEN, f + 1, "Arial Bold");
   int yy = y + 70;
   DashRect("statusBox", x + 8, yy, w - 16, 38, C_PANEL, C_EDGE, 1);
   DashLabel("statusLbl", x + 16, yy + 9, "STATUS", C_MUTED, f, "Arial");
   DashLabel("status", x + 86, yy + 8, "WARMING UP", C_ORANGE, f + 1, "Arial Bold");
   DashLabel("reason", x + 210, yy + 8, "Initializing", C_TEXT, f, "Arial");
   yy += 48;
   DashRect("market", x + 8, yy, w - 16, 118, C_PANEL, C_EDGE, 1);
   DashLabel("mktHdr", x + 16, yy + 8, "MARKET INTELLIGENCE", C_GOLD, f + 1, "Arial Bold");
   DashLabel("regimeLbl", x + 16, yy + 32, "Regime", C_MUTED, f, "Arial");
   DashLabel("regime", x + 160, yy + 32, "--", C_TEXT, f, "Arial Bold");
   DashLabel("sessionLbl", x + 16, yy + 50, "Session", C_MUTED, f, "Arial");
   DashLabel("session", x + 160, yy + 50, "--", C_TEXT, f, "Arial Bold");
   DashLabel("biasLbl", x + 16, yy + 68, "H1/M15/M5 Bias", C_MUTED, f, "Arial");
   DashLabel("bias", x + 160, yy + 68, "--", C_TEXT, f, "Arial Bold");
   DashLabel("newsLbl", x + 16, yy + 86, "News", C_MUTED, f, "Arial");
   DashLabel("news", x + 160, yy + 86, "--", C_TEXT, f, "Arial");
   yy += 128;
   DashRect("signal", x + 8, yy, w - 16, 142, C_PANEL, C_EDGE, 1);
   DashLabel("sigHdr", x + 16, yy + 8, "AI / ML TRADE QUALITY", C_GOLD, f + 1, "Arial Bold");
   DashLabel("buyLbl", x + 16, yy + 32, "Buy Confidence", C_MUTED, f, "Arial");
   DashLabel("buy", x + 160, yy + 32, "0%", C_TEXT, f, "Arial Bold");
   DashBar("buyBar", x + 265, yy + 34, w - 290, 10, 0.0, C_GREEN, C_GRAY);
   DashLabel("sellLbl", x + 16, yy + 50, "Sell Confidence", C_MUTED, f, "Arial");
   DashLabel("sell", x + 160, yy + 50, "0%", C_TEXT, f, "Arial Bold");
   DashBar("sellBar", x + 265, yy + 52, w - 290, 10, 0.0, C_RED, C_GRAY);
   DashLabel("mlLbl", x + 16, yy + 68, "ML Prediction", C_MUTED, f, "Arial");
   DashLabel("ml", x + 160, yy + 68, "--", C_TEXT, f, "Arial");
   DashLabel("gradeLbl", x + 16, yy + 86, "Trade Grade", C_MUTED, f, "Arial");
   DashLabel("grade", x + 160, yy + 86, "--", C_GOLD, f + 1, "Arial Bold");
   DashLabel("planLbl", x + 16, yy + 106, "Trade Plan", C_MUTED, f, "Arial");
   DashLabel("plan", x + 160, yy + 106, "--", C_TEXT, f, "Arial");
   yy += 152;
   DashRect("smc", x + 8, yy, w - 16, 116, C_PANEL, C_EDGE, 1);
   DashLabel("smcHdr", x + 16, yy + 8, "SMC / MICROSTRUCTURE", C_GOLD, f + 1, "Arial Bold");
   DashLabel("fvgLbl", x + 16, yy + 32, "FVG Retest", C_MUTED, f, "Arial");
   DashLabel("fvg", x + 160, yy + 32, "--", C_TEXT, f, "Arial Bold");
   DashLabel("liqLbl", x + 16, yy + 50, "Liquidity Sweep", C_MUTED, f, "Arial");
   DashLabel("liq", x + 160, yy + 50, "--", C_TEXT, f, "Arial Bold");
   DashLabel("microLbl", x + 16, yy + 68, "Micro Pressure", C_MUTED, f, "Arial");
   DashLabel("micro", x + 160, yy + 68, "--", C_TEXT, f, "Arial Bold");
   DashLabel("volLbl", x + 16, yy + 86, "Volatility", C_MUTED, f, "Arial");
   DashLabel("vol", x + 160, yy + 86, "--", C_TEXT, f, "Arial");
   yy += 126;
   DashRect("risk", x + 8, yy, w - 16, 92, C_PANEL, C_EDGE, 1);
   DashLabel("riskHdr", x + 16, yy + 8, "RISK / EXIT", C_GOLD, f + 1, "Arial Bold");
   DashLabel("riskLbl", x + 16, yy + 32, "Risk State", C_MUTED, f, "Arial");
   DashLabel("riskState", x + 160, yy + 32, "--", C_TEXT, f, "Arial Bold");
   DashLabel("pnlLbl", x + 16, yy + 50, "Day / Floating PnL", C_MUTED, f, "Arial");
   DashLabel("pnl", x + 160, yy + 50, "--", C_TEXT, f, "Arial");
   DashLabel("lockLbl", x + 16, yy + 68, "Profit Lock", C_MUTED, f, "Arial");
   DashLabel("lock", x + 160, yy + 68, "--", C_TEXT, f, "Arial");
   ChartRedraw(0);
}
void UpdateDashboard()
{
   if(!InpShowDashboard)
      return;
   DashUpdate("status", g_statusText, (g_statusText == "WAIT" ? C_GOLD : (g_statusText == "BURST LIVE" || g_statusText == "MANAGING" ? C_GREEN : C_ORANGE)));
   DashUpdate("reason", g_blockReason, C_TEXT);
   DashUpdate("regime", RegimeText(), StateColor(g_atrRatio * 45.0));
   DashUpdate("session", SessionText(), (g_session == SESSION_ROLLOVER || g_session == SESSION_OFF ? C_RED : C_BLUE));
   DashUpdate("bias", BiasText(g_h1.bias) + " / " + BiasText(g_m15.bias) + " / " + BiasText(g_m5.bias), C_TEXT);
   DashUpdate("news", g_newsBlocked ? g_newsReason : g_newsReason, g_newsBlocked ? C_RED : C_GREEN);
   DashUpdate("buy", DoubleToString(g_ai.buyConfidence, 1) + "%", StateColor(g_ai.buyConfidence));
   DashUpdate("sell", DoubleToString(g_ai.sellConfidence, 1) + "%", StateColor(g_ai.sellConfidence));
   DashBarUpdate("buyBar", g_ai.buyConfidence, C_GREEN);
   DashBarUpdate("sellBar", g_ai.sellConfidence, C_RED);
   DashUpdate("ml", g_ml.text, StateColor(g_ml.qualityProbability * 100.0));
   DashUpdate("grade", GradeText(g_ai.grade), StateColor(MathMax(g_ai.buyConfidence, g_ai.sellConfidence)));
   string plan = g_plan.valid ?
      StringFormat("%s x%d %.2f lot | TP $%.2f", (g_plan.direction > 0 ? "BUY" : "SELL"), g_plan.slots, g_plan.lotPerSlot, g_plan.targetUsdPerSlot) :
      g_plan.reason;
   DashUpdate("plan", plan, g_plan.valid ? C_GREEN : C_MUTED);
   string fvg = (g_smc.bullFvgRetest ? "BULL RETEST" : (g_smc.bearFvgRetest ? "BEAR RETEST" : "WAIT"));
   DashUpdate("fvg", fvg, (g_smc.bullFvgRetest ? C_GREEN : (g_smc.bearFvgRetest ? C_RED : C_MUTED)));
   string liq = (g_smc.liquiditySweepBull ? "LOW SWEEP" : (g_smc.liquiditySweepBear ? "HIGH SWEEP" : "NONE"));
   DashUpdate("liq", liq, (g_smc.liquiditySweepBull ? C_GREEN : (g_smc.liquiditySweepBear ? C_RED : C_MUTED)));
   DashUpdate("micro", PressureText(g_micro.pressure), (g_micro.pressure == MICRO_BULLISH ? C_GREEN : (g_micro.pressure == MICRO_BEARISH ? C_RED : C_MUTED)));
   DashUpdate("vol", StringFormat("ATR %.0f pts | ratio %.2f | spread %.0f", g_currentATRPoints, g_atrRatio, SpreadPoints()), C_TEXT);
   DashUpdate("riskState", RiskText(), (g_risk == RISK_CLEAR ? C_GREEN : (g_risk == RISK_CAUTION ? C_ORANGE : C_RED)));
   DashUpdate("pnl", StringFormat("$%.2f / $%.2f | DD %.2f%%", g_dailyProfit, FloatingProfit(), g_dailyDrawdown),
              (g_dailyProfit + FloatingProfit() >= 0.0 ? C_GREEN : C_RED));
   DashUpdate("lock", StringFormat("%d positions | %.2f lots", CountPositions(), TotalOpenLots()), C_TEXT);
   ChartRedraw(0);
}
void DeleteDashboard()
{
   ObjectsDeleteAll(0, PSP_PREFIX);
   ChartRedraw(0);
}
void DashRect(const string id, const int x, const int y, const int w, const int h, const color bg, const color brd=clrNONE, const int bw=1)
{
   string name = PSP_PREFIX + id;
   if(ObjectFind(0, name) >= 0) ObjectDelete(0, name);
   ObjectCreate(0, name, OBJ_RECTANGLE_LABEL, 0, 0, 0);
   ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, name, OBJPROP_XSIZE, w);
   ObjectSetInteger(0, name, OBJPROP_YSIZE, h);
   ObjectSetInteger(0, name, OBJPROP_BGCOLOR, bg);
   ObjectSetInteger(0, name, OBJPROP_BORDER_TYPE, BORDER_FLAT);
   ObjectSetInteger(0, name, OBJPROP_COLOR, brd == clrNONE ? bg : brd);
   ObjectSetInteger(0, name, OBJPROP_WIDTH, bw);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
}
void DashLabel(const string id, const int x, const int y, const string txt, const color clr, const int fsz, const string font="Arial")
{
   string name = PSP_PREFIX + id;
   if(ObjectFind(0, name) >= 0) ObjectDelete(0, name);
   ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetString(0, name, OBJPROP_TEXT, txt);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, fsz);
   ObjectSetString(0, name, OBJPROP_FONT, font);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
}
void DashUpdate(const string id, const string txt, const color clr)
{
   string name = PSP_PREFIX + id;
   if(ObjectFind(0, name) >= 0)
   {
      ObjectSetString(0, name, OBJPROP_TEXT, txt);
      ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   }
}
void DashBar(const string id, const int x, const int y, const int w, const int h, const double pct, const color fg, const color bg)
{
   DashRect(id + "_bg", x, y, w, h, bg, C_EDGE, 1);
   DashRect(id + "_fg", x + 1, y + 1, (int)MathMax(2.0, MathRound((w - 2) * Clamp(pct, 0.0, 100.0) / 100.0)), h - 2, fg, fg, 1);
}
void DashBarUpdate(const string id, const double pct, const color fg)
{
   string bgName = PSP_PREFIX + id + "_bg";
   string fgName = PSP_PREFIX + id + "_fg";
   if(ObjectFind(0, bgName) < 0 || ObjectFind(0, fgName) < 0)
      return;
   int w = (int)ObjectGetInteger(0, bgName, OBJPROP_XSIZE);
   int fw = (int)MathMax(2.0, MathRound((w - 2) * Clamp(pct, 0.0, 100.0) / 100.0));
   ObjectSetInteger(0, fgName, OBJPROP_XSIZE, fw);
   ObjectSetInteger(0, fgName, OBJPROP_BGCOLOR, fg);
   ObjectSetInteger(0, fgName, OBJPROP_COLOR, fg);
}
//+------------------------------------------------------------------+

