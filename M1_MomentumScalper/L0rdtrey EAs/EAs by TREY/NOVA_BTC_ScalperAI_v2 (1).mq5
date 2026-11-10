//+------------------------------------------------------------------+
//|                                   NOVA BTC ScalperAI v2.mq5       |
//|                  Upgraded Institutional BTCUSD Scalping Engine   |
//+------------------------------------------------------------------+
#property copyright "2026, NOVA BTC Scalper Systems"
#property version   "2.00"
#property strict

#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>

#define DASH_PREFIX "NOVA_BTC2_"
#define EA_VERSION  "v2.00"

//==================================================================
// ENUMS
//==================================================================
enum ENUM_ENGINE_STATE { STATE_SCANNING, STATE_ANALYZING, STATE_COOLDOWN, STATE_DAILY_LIMIT, STATE_VOL_HALT };
enum ENUM_SIGNAL       { SIGNAL_BUY = 1, SIGNAL_SELL = -1, SIGNAL_NONE = 0 };
enum ENUM_REGIME       { REGIME_STRONG_TREND, REGIME_WEAK_TREND, REGIME_RANGE, REGIME_BREAKOUT,
                          REGIME_HIGH_VOL, REGIME_EXTREME_VOL };

//==================================================================
// INPUTS
//==================================================================
input group "=== CORE IDENTITY ==="
input ulong   InpMagicNumber       = 778212;
input string  InpTradeComment      = "NovaBTC_v2";

input group "=== RISK MANAGEMENT ==="
input double  InpMinRiskPercent    = 0.50;
input double  InpMaxRiskPercent    = 2.00;
input double  InpMaxDailyLossPct   = 5.0;
input double  InpMaxDailyProfitPct = 10.0;
input int     InpMaxDailyTrades    = 12;
input double  InpMaxDrawdownPct    = 15.0;

input group "=== ATR SL/TP ==="
input int     InpATRPeriod      = 14;
input double  InpSLMultiplier   = 1.4;
input double  InpTP1R           = 1.0;
input double  InpTP2Multiplier  = 3.0;
input double  InpMinSLPercent   = 0.20;
input double  InpMaxSLPercent   = 1.50;

input group "=== SMART EXIT SYSTEM ==="
input double  InpBreakevenR      = 0.5;
input double  InpBEBufferPercent = 0.02;
input bool    InpUsePeakLock     = true;
input double  InpPeakLockActR    = 0.8;
input double  InpPeakLockRetr    = 25.0;
input double  InpMinRewardRiskR  = 1.0;
input bool    InpUseTrailing     = true;
input double  InpTrailStartR     = 0.6;
input double  InpTrailATRMult    = 0.7;
input bool    InpUseStructTrail  = true;
input int     InpStructTrailBars = 5;
input bool    InpUsePartialClose = true;
input double  InpPartialClosePct = 50.0;
input double  InpMinLockProfitR  = 0.5;
input int     InpMaxBarsInTrade  = 90;
input double  InpVolCollapseRatio= 0.45;  // exit if ATR shrinks below this fraction of entry ATR

input group "=== PRE-TRADE ANALYSIS ==="
input int     InpAnalysisMaxSec   = 90;
input int     InpAnalysisMinSec   = 8;
input int     InpAnalysisMinTicks = 25;

input group "=== SIGNAL CONFLUENCE ==="
input int     InpFastEMAPeriod  = 8;
input int     InpSlowEMAPeriod  = 21;
input int     InpTrendEMAPeriod = 55;
input int     InpRSIPeriod      = 14;
input double  InpRSIOverbought  = 72.0;
input double  InpRSIOversold    = 28.0;
input int     InpADXPeriod      = 14;
input double  InpADXMinStrength = 18.0;
input int     InpMACDFast       = 12;
input int     InpMACDSlow       = 26;
input int     InpMACDSignal     = 9;
input int     InpBBPeriod       = 20;
input double  InpBBDeviation    = 2.0;
input double  InpBBSqueezeRatio = 0.012;
input int     InpStructureBars  = 6;

input group "=== MTF FILTER ==="
input bool    InpUseHTFFilter = true;
input ENUM_TIMEFRAMES InpHTFPeriod = PERIOD_M15;
input int     InpHTFEMAPeriod = 50;

input group "=== VOLATILITY REGIME ==="
input int     InpVolLookback      = 100;
input double  InpVolHighPercentile= 80.0;
input double  InpVolExtremePctile = 95.0;
input double  InpVolLowPercentile = 20.0;

input group "=== VOLUME FILTER ==="
input bool    InpUseVolumeFilter = true;
input int     InpVolumeAvgPeriod = 20;
input double  InpVolumeSurgeMult = 1.3;

input group "=== SPREAD FILTER ==="
input double  InpMaxSpreadPercent  = 0.06;
input double  InpSpreadAvgMultiple = 2.5;

input group "=== WEEKEND / LIQUIDITY ==="
input bool    InpAvoidWeekendOpen = true;
input int     InpWeekendPauseMin  = 30;

input group "=== STREAK PROTECTION ==="
input int     InpMaxLossStreak  = 3;
input int     InpWinStreakBoost = 5;

input group "=== SMART MONEY FILTER ==="
input bool    InpUseSMCFilter     = true;
input int     InpSMCSwingBars     = 10;
input int     InpFVGMinATRFrac    = 30;    // FVG gap must be >= this % of ATR to count

input group "=== BTC-SPECIFIC GUARDS ==="
input bool    InpBlockAfterLiqCandle = true;
input double  InpLiqCandleATRMult    = 2.5;
input int     InpLiqCooldownBars     = 3;
input bool    InpBlockExhaustion     = true;

input group "=== SIGNAL QUALITY ==="
input int     InpMinScoreToTrade  = 6;  // out of 9 confluence points

input group "=== LOGGING ==="
input bool    InpEnableCSVLog = true;
input string  InpLogFileName  = "NovaBTC_v2_TradeLog.csv";

input group "=== DASHBOARD ==="
input int     InpDashX = 15;
input int     InpDashY = 15;

//==================================================================
// COLOR PALETTE
//==================================================================
const color C_BG=C'4,8,18', C_PANEL=C'7,14,30', C_PANEL2=C'9,19,40', C_HEADER=C'10,18,42';
const color C_BORDER=C'80,60,220', C_BORDER2=C'55,40,150', C_CYAN=C'0,225,210', C_VIOLET=C'150,110,255';
const color C_BLUE=C'40,150,255', C_GREEN=C'0,220,140', C_RED=C'235,55,75', C_GOLD=C'255,190,30';
const color C_ORANGE=C'255,140,30', C_WHITE=C'225,235,255', C_MUTED=C'95,110,150';
const color C_HOLD_BG=C'55,40,0', C_BUY_BG=C'0,50,28', C_SELL_BG=C'55,5,12', C_SECTION_HDR=C'12,20,48';

//==================================================================
// GLOBAL OBJECTS
//==================================================================
CTrade        g_Trade;
CPositionInfo g_Pos;

int g_hFastEMA=INVALID_HANDLE, g_hSlowEMA=INVALID_HANDLE, g_hTrendEMA=INVALID_HANDLE;
int g_hRSI=INVALID_HANDLE, g_hATR=INVALID_HANDLE, g_hADX=INVALID_HANDLE;
int g_hMACD=INVALID_HANDLE, g_hBB=INVALID_HANDLE, g_hHTFEMA=INVALID_HANDLE;

ENUM_ENGINE_STATE g_State = STATE_SCANNING;
datetime          g_StateTimer = 0;

ENUM_SIGNAL  g_PendingSignal = SIGNAL_NONE;
int          g_AnalysisTicks = 0;
datetime     g_AnalysisStart = 0;

double g_PeakProfit=0, g_PartialClosePrice=0;
bool   g_BESet=false, g_PartialClosed=false;
double g_EntryATR=0, g_EntryPrice=0, g_EntrySLPrice=0, g_EntryRiskUSD=0;
int    g_TradeDirection=0;
datetime g_EntryBarTime=0;
double g_EntryMaxDD=0; // tracks worst excursion since entry, for logging
ulong  g_EntryTicket=0;
string g_EntryRegimeStr="", g_EntrySignalScoreStr="";
double g_EntrySpread=0, g_EntryRSI=0, g_EntryADX=0;

datetime g_SessionDay=0;
int      g_DailyTrades=0;
double   g_DailyProfit=0;
int      g_DailyWins=0, g_DailyLosses=0;
int      g_ConsecLosses=0, g_ConsecWins=0;
double   g_SessionOpenBal=0, g_EquityPeak=0;

int    g_LastConfluenceScore=0;
double g_WinRate7=0;
int    g_Last7Results[7];

double g_AvgSpread=0; int g_SpreadSamples=0;
double g_ATRHistory[];
ENUM_REGIME g_Regime = REGIME_RANGE;
double g_VolPercentile = 50.0;

double g_AvgVolume=0; int g_VolumeSamples=0;

int g_LiqCandleCooldown = 0; // bars remaining blocked after a liquidation candle

string g_StatusText="BOOTING"; color g_StatusColor=C_GOLD;
string g_HeartbeatStr="0 0 0 0";

double g_SpreadQualityScore=100, g_ExecQualityScore=100;
double g_ExecAttempts=0, g_ExecFails=0;

//==================================================================
// FORWARD DECLARATIONS
//==================================================================
bool InitIndicators(); void ReleaseIndicators();
void SyncDailyStats(); void UpdateVolatilityRegime(); void UpdateVolumeAverage();
ENUM_SIGNAL EvaluateConfluence(bool detectionMode=true);
bool CheckEMAStack(double &fast,double &slow,double &trend);
bool CheckRSI(ENUM_SIGNAL sig,double &rsiVal);
bool CheckADX(double &adxVal);
bool CheckMACD(ENUM_SIGNAL sig);
bool CheckBollingerBands(ENUM_SIGNAL sig,bool &inSqueeze);
bool CheckMarketStructure(ENUM_SIGNAL sig,bool proximityMode=false);
bool CheckHTFTrend(ENUM_SIGNAL sig);
bool CheckVolumeSurge();
bool CheckMomentumExhaustion(ENUM_SIGNAL sig);
double GetATR();
void  ClassifyRegime();
bool  CheckSMCConfirmation(ENUM_SIGNAL sig);
bool  DetectBOS(ENUM_SIGNAL sig);
bool  DetectCHoCH(ENUM_SIGNAL sig);
bool  DetectLiquiditySweep(ENUM_SIGNAL sig);
bool  DetectFVG(ENUM_SIGNAL sig);
bool  IsLiquidationCandle();
bool  IsExhaustionCandle(ENUM_SIGNAL sig);
double CalculateLotSize(double slDistancePrice);
void  ExecuteEntry(ENUM_SIGNAL sig);
void  ManageOpenTrade();
void  CheckBreakeven(); void CheckATRTrailing(); void CheckStructureTrailing();
void  CheckPeakProfitLock(double pnl); void CheckPartialClose(double pnl);
void  CheckTimeExit(); void CheckVolatilityCollapseExit(); void CheckEmergencyExit();
void  EvaluateFloatingPnL(double pnl);
void  CacheTradeEntry(); void ResetTradeState();
bool  IsPositionOpen(); double GetFloatingPnL();
void  CloseAllPositions(string reason);
bool  IsMarketOpen(); bool IsSpreadOk(); void UpdateSpreadAverage();
void  UpdateExecutionQuality(bool success);
bool  IsDailyLossLimitHit(); bool IsDailyProfitTargetHit(); bool IsDrawdownLimitHit();
bool  IsWeekendPauseActive();
double GetRiskAdjustedPercent();
datetime GetDayStart(datetime t);
void  ProcessAnalysisPhase();
void  LogTradeOpen(ENUM_SIGNAL sig,double score);
void  LogTradeClose(double pnl,string reason);
void  RenderDashboard(); void UpdateDashboard(); void PurgeDashboard();
void  DrawRect(string id,int x,int y,int w,int h,color bg,color border,int bw);
void  DrawLabel(string id,int x,int y,string txt,color clr,int sz,string fnt);
void  SetLabel(string id,string txt,color clr=clrNONE);
string TimeframeToString(ENUM_TIMEFRAMES tf);
string RegimeToString(ENUM_REGIME r);

//==================================================================
// INIT
//==================================================================
int OnInit()
{
   if(StringFind(_Symbol,"BTC")<0)
      Print("[NovaBTC v2] WARNING: built for BTCUSD. Current symbol: ",_Symbol);

   if(_Period==PERIOD_M1)
   {
      Print("[NovaBTC v2] WARNING: M1 detected. M5/M15 recommended for BTCUSD.");
      Alert("NovaBTC v2: M1 timeframe detected. M5/M15 recommended.");
   }

   g_Trade.SetExpertMagicNumber(InpMagicNumber);
   g_Trade.SetDeviationInPoints(50);
   g_Trade.SetTypeFilling(ORDER_FILLING_FOK);

   if(InpMinRiskPercent<=0.0 || InpMaxRiskPercent>10.0 || InpMinRiskPercent>InpMaxRiskPercent)
   { Alert("Risk% range invalid."); return INIT_PARAMETERS_INCORRECT; }

   if(!InitIndicators()) return INIT_FAILED;

   ArrayResize(g_ATRHistory, InpVolLookback);
   ArrayInitialize(g_ATRHistory, 0.0);
   ArrayInitialize(g_Last7Results, -1);

   g_SessionDay     = GetDayStart(TimeCurrent());
   g_SessionOpenBal = AccountInfoDouble(ACCOUNT_BALANCE);
   g_EquityPeak     = AccountInfoDouble(ACCOUNT_EQUITY);
   SyncDailyStats();

   if(InpEnableCSVLog)
   {
      int h = FileOpen(InpLogFileName, FILE_WRITE|FILE_CSV|FILE_ANSI|FILE_COMMON);
      if(h!=INVALID_HANDLE)
      {
         FileWrite(h,"Date","Time","Direction","ATR","RSI","ADX","Spread","Regime","SignalScore",
                   "EntryPrice","Lot","RiskUSD");
         FileClose(h);
      }
   }

   g_State = STATE_SCANNING;
   EventSetTimer(1);
   RenderDashboard();

   Print("[NovaBTC v2] Initialised. Symbol=",_Symbol," Magic=",InpMagicNumber," TF=",EnumToString(_Period));
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
   EventKillTimer();
   PurgeDashboard();
   ReleaseIndicators();
}

void OnTimer()
{
   static uint beat=0; beat++;
   string p[4]={"1 0 1 1  0 1 0 0","0 1 0 0  1 0 1 1","1 1 0 1  0 0 1 0","0 0 1 0  1 1 0 1"};
   g_HeartbeatStr=p[beat%4];

   SyncDailyStats();
   UpdateVolatilityRegime();
   UpdateVolumeAverage();
   ClassifyRegime();

   double eq=AccountInfoDouble(ACCOUNT_EQUITY);
   if(eq>g_EquityPeak) g_EquityPeak=eq;

   if(g_LiqCandleCooldown>0)
   {
      static datetime lastBar=0;
      datetime cur=(datetime)SeriesInfoInteger(_Symbol,_Period,SERIES_LASTBAR_DATE);
      if(cur!=lastBar){ lastBar=cur; g_LiqCandleCooldown--; }
   }

   UpdateDashboard();
}

//==================================================================
// MAIN TICK
//==================================================================
void OnTick()
{
   UpdateSpreadAverage();

   if(!IsMarketOpen())
   { g_StatusText="MARKET CLOSED"; g_StatusColor=C_RED; return; }

   if(IsPositionOpen())
   { ManageOpenTrade(); return; }

   if(IsDrawdownLimitHit())
   { g_State=STATE_DAILY_LIMIT; g_StatusText="MAX DRAWDOWN HIT - HALTED"; g_StatusColor=C_RED; return; }

   if(IsDailyLossLimitHit())
   { g_State=STATE_DAILY_LIMIT; g_StatusText="DAILY LOSS LIMIT - HALTED"; g_StatusColor=C_RED; return; }

   if(IsDailyProfitTargetHit())
   { g_State=STATE_DAILY_LIMIT; g_StatusText="DAILY TARGET MET - HALTED"; g_StatusColor=C_GREEN; return; }

   if(g_DailyTrades>=InpMaxDailyTrades)
   { g_StatusText="MAX DAILY TRADES REACHED"; g_StatusColor=C_GOLD; return; }

   if(InpAvoidWeekendOpen && IsWeekendPauseActive())
   { g_StatusText="WEEKEND OPEN PAUSE"; g_StatusColor=C_MUTED; return; }

   if(g_Regime==REGIME_EXTREME_VOL)
   { g_StatusText="EXTREME VOLATILITY - ENTRIES PAUSED"; g_StatusColor=C_RED; return; }

   if(g_LiqCandleCooldown>0)
   { g_StatusText="LIQUIDATION COOLDOWN ("+IntegerToString(g_LiqCandleCooldown)+" bars)"; g_StatusColor=C_RED; return; }

   if(!IsSpreadOk())
   {
      double sp=SymbolInfoDouble(_Symbol,SYMBOL_ASK)-SymbolInfoDouble(_Symbol,SYMBOL_BID);
      g_StatusText="SPREAD TOO WIDE ($"+DoubleToString(sp,2)+")"; g_StatusColor=C_RED; return;
   }

   if(InpBlockAfterLiqCandle && IsLiquidationCandle())
   {
      g_LiqCandleCooldown=InpLiqCooldownBars;
      g_StatusText="LIQUIDATION CANDLE DETECTED - COOLDOWN"; g_StatusColor=C_RED;
      return;
   }

   if(g_State==STATE_COOLDOWN)
   {
      int left=(int)(g_StateTimer-TimeCurrent());
      if(left>0){ g_StatusText="COOLDOWN ("+IntegerToString(left)+"s)"; g_StatusColor=C_GOLD; return; }
      g_State=STATE_SCANNING;
   }

   if(g_State==STATE_SCANNING)
   {
      ENUM_SIGNAL sig=EvaluateConfluence(true);
      if(sig==SIGNAL_NONE)
      { g_StatusText="SCANNING ["+RegimeToString(g_Regime)+"] BUILDING CONFLUENCE"; g_StatusColor=C_MUTED; return; }

      if(InpBlockExhaustion && IsExhaustionCandle(sig))
      { g_StatusText="EXHAUSTION CANDLE BLOCK"; g_StatusColor=C_RED; return; }

      if(InpUseSMCFilter && !CheckSMCConfirmation(sig))
      { g_StatusText="SMC FILTER REJECTED SIGNAL"; g_StatusColor=C_GOLD; return; }

      g_State=STATE_ANALYZING; g_PendingSignal=sig;
      g_AnalysisStart=TimeCurrent(); g_AnalysisTicks=0;
      g_StatusText="SIGNAL DETECTED - ANALYSING"; g_StatusColor=C_VIOLET;
      Print("[NovaBTC v2] Signal=",(sig==SIGNAL_BUY?"BUY":"SELL")," Score=",g_LastConfluenceScore,
            "/9 Regime=",RegimeToString(g_Regime));
   }
   else if(g_State==STATE_ANALYZING)
   {
      ProcessAnalysisPhase();
   }
}

//==================================================================
// INDICATORS
//==================================================================
bool InitIndicators()
{
   g_hFastEMA  = iMA(_Symbol,_Period,InpFastEMAPeriod,0,MODE_EMA,PRICE_CLOSE);
   g_hSlowEMA  = iMA(_Symbol,_Period,InpSlowEMAPeriod,0,MODE_EMA,PRICE_CLOSE);
   g_hTrendEMA = iMA(_Symbol,_Period,InpTrendEMAPeriod,0,MODE_EMA,PRICE_CLOSE);
   g_hRSI      = iRSI(_Symbol,_Period,InpRSIPeriod,PRICE_CLOSE);
   g_hATR      = iATR(_Symbol,_Period,InpATRPeriod);
   g_hADX      = iADX(_Symbol,_Period,InpADXPeriod);
   g_hMACD     = iMACD(_Symbol,_Period,InpMACDFast,InpMACDSlow,InpMACDSignal,PRICE_CLOSE);
   g_hBB       = iBands(_Symbol,_Period,InpBBPeriod,0,InpBBDeviation,PRICE_CLOSE);
   g_hHTFEMA   = iMA(_Symbol,InpHTFPeriod,InpHTFEMAPeriod,0,MODE_EMA,PRICE_CLOSE);

   if(g_hFastEMA==INVALID_HANDLE||g_hSlowEMA==INVALID_HANDLE||g_hTrendEMA==INVALID_HANDLE||
      g_hRSI==INVALID_HANDLE||g_hATR==INVALID_HANDLE||g_hADX==INVALID_HANDLE||
      g_hMACD==INVALID_HANDLE||g_hBB==INVALID_HANDLE||g_hHTFEMA==INVALID_HANDLE)
   { Print("[NovaBTC v2] FAILED: indicator handle invalid."); return false; }
   return true;
}
void ReleaseIndicators()
{
   int hs[]={g_hFastEMA,g_hSlowEMA,g_hTrendEMA,g_hRSI,g_hATR,g_hADX,g_hMACD,g_hBB,g_hHTFEMA};
   for(int i=0;i<ArraySize(hs);i++) if(hs[i]!=INVALID_HANDLE) IndicatorRelease(hs[i]);
}
double GetATR(){ double a[1]; if(CopyBuffer(g_hATR,0,0,1,a)<=0) return 0.0; return a[0]; }

//==================================================================
// ADVANCED REGIME CLASSIFIER
//==================================================================
void ClassifyRegime()
{
   double adx[1]; if(CopyBuffer(g_hADX,0,0,1,adx)<=0) return;
   double f0[1],f5[1]; CopyBuffer(g_hFastEMA,0,0,1,f0); CopyBuffer(g_hFastEMA,0,5,1,f5);
   double slope = (f5[0]!=0)? (f0[0]-f5[0])/f5[0]*100.0 : 0;
   double up[1],lo[1],mid[1];
   bool bbOk = (CopyBuffer(g_hBB,1,0,1,up)>0 && CopyBuffer(g_hBB,2,0,1,lo)>0 && CopyBuffer(g_hBB,0,0,1,mid)>0);
   double bbWidthPct = (bbOk && mid[0]>0)? (up[0]-lo[0])/mid[0]*100.0 : 1.0;

   double pctile = g_VolPercentile;

   int hb=iHighest(_Symbol,_Period,MODE_HIGH,InpStructureBars,1);
   int lb=iLowest(_Symbol,_Period,MODE_LOW,InpStructureBars,1);
   double swHigh=iHigh(_Symbol,_Period,hb), swLow=iLow(_Symbol,_Period,lb);
   double price=SymbolInfoDouble(_Symbol,SYMBOL_BID);
   bool brokeStructure = (price>swHigh || price<swLow);

   if(pctile>=InpVolExtremePctile)       { g_Regime=REGIME_EXTREME_VOL; return; }
   if(pctile>=InpVolHighPercentile)      { g_Regime=REGIME_HIGH_VOL; return; }
   if(brokeStructure && pctile>=50)      { g_Regime=REGIME_BREAKOUT; return; }
   if(adx[0]>=InpADXMinStrength && MathAbs(slope)>0.05) { g_Regime=REGIME_STRONG_TREND; return; }
   if(adx[0]>=InpADXMinStrength*0.6)     { g_Regime=REGIME_WEAK_TREND; return; }
   g_Regime=REGIME_RANGE;
}

string RegimeToString(ENUM_REGIME r)
{
   switch(r){
      case REGIME_STRONG_TREND: return "STRONG-TREND"; case REGIME_WEAK_TREND: return "WEAK-TREND";
      case REGIME_RANGE: return "RANGE"; case REGIME_BREAKOUT: return "BREAKOUT";
      case REGIME_HIGH_VOL: return "HIGH-VOL"; case REGIME_EXTREME_VOL: return "EXTREME-VOL";
      default: return "?";
   }
}

//==================================================================
// CONFLUENCE SIGNAL ENGINE (kept + regime weighting)
//==================================================================
ENUM_SIGNAL EvaluateConfluence(bool detectionMode=true)
{
   double fastEMA,slowEMA,trendEMA,rsiVal,adxVal; bool inSqueeze=false;

   if(!CheckEMAStack(fastEMA,slowEMA,trendEMA)){ g_LastConfluenceScore=0; return SIGNAL_NONE; }
   ENUM_SIGNAL emaSig=(fastEMA>slowEMA && slowEMA>trendEMA)?SIGNAL_BUY:SIGNAL_SELL;

   if(CheckMomentumExhaustion(emaSig)){ g_LastConfluenceScore=0; return SIGNAL_NONE; }

   int score=2; // EMA stack

   bool rsiPass=CheckRSI(emaSig,rsiVal);
   bool adxPass=CheckADX(adxVal);
   bool macdPass=CheckMACD(emaSig);
   bool bbPass=CheckBollingerBands(emaSig,inSqueeze);
   bool structPass=CheckMarketStructure(emaSig,!detectionMode);
   bool htfPass=InpUseHTFFilter?CheckHTFTrend(emaSig):true;
   bool volPass=InpUseVolumeFilter?CheckVolumeSurge():true;

   if(rsiPass) score++; if(adxPass) score++; if(macdPass) score++;
   if(bbPass) score++; if(structPass) score++; if(htfPass) score++; if(volPass) score++;

   if(inSqueeze && g_Regime!=REGIME_BREAKOUT){ g_LastConfluenceScore=score; return SIGNAL_NONE; }

   g_LastConfluenceScore=score;

   // Signal quality requirement: trend + momentum + structure + volatility must each align;
   // no single indicator can trigger alone.
   bool trendAligned = (emaSig==SIGNAL_BUY) ? (fastEMA>slowEMA) : (fastEMA<slowEMA);
   bool momentumAligned = rsiPass || macdPass;
   bool structureAligned = structPass || htfPass;
   bool volatilityAligned = (g_Regime!=REGIME_EXTREME_VOL) && !inSqueeze;
   if(!(trendAligned && momentumAligned && structureAligned && volatilityAligned))
      return SIGNAL_NONE;

   int required = InpMinScoreToTrade;
   if(g_ConsecLosses>=2) required++;
   if(g_ConsecLosses>=3) required++;
   if(g_Regime==REGIME_RANGE) required=MathMin(9,required+1);

   if(score>=required) return emaSig;
   return SIGNAL_NONE;
}

bool CheckEMAStack(double &fast,double &slow,double &trend)
{
   double f[1],s[1],t[1];
   if(CopyBuffer(g_hFastEMA,0,0,1,f)<=0) return false;
   if(CopyBuffer(g_hSlowEMA,0,0,1,s)<=0) return false;
   if(CopyBuffer(g_hTrendEMA,0,0,1,t)<=0) return false;
   fast=f[0]; slow=s[0]; trend=t[0];
   bool bull=(fast>slow && slow>trend), bear=(fast<slow && slow<trend);
   return (bull||bear);
}
bool CheckRSI(ENUM_SIGNAL sig,double &rsiVal)
{
   double r[1]; if(CopyBuffer(g_hRSI,0,0,1,r)<=0) return false;
   rsiVal=r[0];
   if(sig==SIGNAL_BUY)  return (rsiVal>50.0 && rsiVal<InpRSIOverbought);
   if(sig==SIGNAL_SELL) return (rsiVal<50.0 && rsiVal>InpRSIOversold);
   return false;
}
bool CheckADX(double &adxVal)
{
   double a[1]; if(CopyBuffer(g_hADX,0,0,1,a)<=0) return false;
   adxVal=a[0]; return (adxVal>=InpADXMinStrength);
}
bool CheckMACD(ENUM_SIGNAL sig)
{
   double hist[2]; if(CopyBuffer(g_hMACD,2,0,2,hist)<2) return false;
   bool rising=(hist[0]>hist[1]), falling=(hist[0]<hist[1]);
   if(sig==SIGNAL_BUY)  return (hist[0]>0.0 && rising);
   if(sig==SIGNAL_SELL) return (hist[0]<0.0 && falling);
   return false;
}
bool CheckBollingerBands(ENUM_SIGNAL sig,bool &inSqueeze)
{
   double up[1],lo[1],mid[1];
   if(CopyBuffer(g_hBB,1,0,1,up)<=0||CopyBuffer(g_hBB,2,0,1,lo)<=0||CopyBuffer(g_hBB,0,0,1,mid)<=0) return false;
   double width=up[0]-lo[0]; double price=SymbolInfoDouble(_Symbol,SYMBOL_BID);
   double squeezeThresh=price*InpBBSqueezeRatio;
   if(width<squeezeThresh){ inSqueeze=true; return false; }
   inSqueeze=false;
   double bid=SymbolInfoDouble(_Symbol,SYMBOL_BID);
   if(sig==SIGNAL_BUY)  return (bid>mid[0]);
   if(sig==SIGNAL_SELL) return (bid<mid[0]);
   return false;
}
bool CheckMarketStructure(ENUM_SIGNAL sig,bool proximityMode=false)
{
   int hb=iHighest(_Symbol,_Period,MODE_HIGH,InpStructureBars,1);
   int lb=iLowest(_Symbol,_Period,MODE_LOW,InpStructureBars,1);
   if(hb<0||lb<0) return false;
   double swHigh=iHigh(_Symbol,_Period,hb), swLow=iLow(_Symbol,_Period,lb);
   double bid=SymbolInfoDouble(_Symbol,SYMBOL_BID), ask=SymbolInfoDouble(_Symbol,SYMBOL_ASK);
   double atr=GetATR(), buffer=atr*0.5;
   if(proximityMode)
   {
      if(sig==SIGNAL_BUY)  return (ask>=swHigh-buffer);
      if(sig==SIGNAL_SELL) return (bid<=swLow+buffer);
   }
   else
   {
      if(sig==SIGNAL_BUY)  return (ask>swHigh);
      if(sig==SIGNAL_SELL) return (bid<swLow);
   }
   return false;
}
bool CheckHTFTrend(ENUM_SIGNAL sig)
{
   double htf[1]; if(CopyBuffer(g_hHTFEMA,0,0,1,htf)<=0) return false;
   double price=SymbolInfoDouble(_Symbol,SYMBOL_BID);
   if(sig==SIGNAL_BUY)  return (price>htf[0]);
   if(sig==SIGNAL_SELL) return (price<htf[0]);
   return false;
}
bool CheckVolumeSurge()
{
   if(g_AvgVolume<=0.0) return true;
   long vol[1]; if(CopyTickVolume(_Symbol,_Period,0,1,vol)<=0) return true;
   return ((double)vol[0]>=g_AvgVolume*InpVolumeSurgeMult);
}
bool CheckMomentumExhaustion(ENUM_SIGNAL sig)
{
   double rsi[1]; if(CopyBuffer(g_hRSI,0,0,1,rsi)<=0) return false;
   double openP=iOpen(_Symbol,_Period,1), closeP=iClose(_Symbol,_Period,1);
   double highP=iHigh(_Symbol,_Period,1), lowP=iLow(_Symbol,_Period,1);
   double range=highP-lowP; if(range<=0.0) return false;
   if(sig==SIGNAL_BUY && rsi[0]>78.0)
   { double upperWick=highP-MathMax(openP,closeP); if(upperWick>range*0.40) return true; }
   if(sig==SIGNAL_SELL && rsi[0]<22.0)
   { double lowerWick=MathMin(openP,closeP)-lowP; if(lowerWick>range*0.40) return true; }
   return false;
}

//==================================================================
// SMART MONEY CONCEPTS (lightweight)
//==================================================================
bool CheckSMCConfirmation(ENUM_SIGNAL sig)
{
   // require at least one SMC confirmation: BOS, CHoCH, liquidity sweep reversal, or supportive FVG
   bool bos=DetectBOS(sig), choch=DetectCHoCH(sig), sweep=DetectLiquiditySweep(sig), fvg=DetectFVG(sig);
   return (bos||choch||sweep||fvg);
}

bool DetectBOS(ENUM_SIGNAL sig)
{
   int hb=iHighest(_Symbol,_Period,MODE_HIGH,InpSMCSwingBars,1);
   int lb=iLowest(_Symbol,_Period,MODE_LOW,InpSMCSwingBars,1);
   double swHigh=iHigh(_Symbol,_Period,hb), swLow=iLow(_Symbol,_Period,lb);
   double bid=SymbolInfoDouble(_Symbol,SYMBOL_BID), ask=SymbolInfoDouble(_Symbol,SYMBOL_ASK);
   if(sig==SIGNAL_BUY)  return (ask>swHigh);
   if(sig==SIGNAL_SELL) return (bid<swLow);
   return false;
}

bool DetectCHoCH(ENUM_SIGNAL sig)
{
   // simplified CHoCH: prior leg made a HL/LH sequence opposite to current EMA flip
   double f0[1],f1[1],s0[1],s1[1];
   CopyBuffer(g_hFastEMA,0,0,1,f0); CopyBuffer(g_hFastEMA,0,2,1,f1);
   CopyBuffer(g_hSlowEMA,0,0,1,s0); CopyBuffer(g_hSlowEMA,0,2,1,s1);
   bool crossUp   = (f1[0]<=s1[0] && f0[0]>s0[0]);
   bool crossDown = (f1[0]>=s1[0] && f0[0]<s0[0]);
   if(sig==SIGNAL_BUY)  return crossUp;
   if(sig==SIGNAL_SELL) return crossDown;
   return false;
}

bool DetectLiquiditySweep(ENUM_SIGNAL sig)
{
   int hb=iHighest(_Symbol,_Period,MODE_HIGH,InpSMCSwingBars,1);
   int lb=iLowest(_Symbol,_Period,MODE_LOW,InpSMCSwingBars,1);
   double swHigh=iHigh(_Symbol,_Period,hb), swLow=iLow(_Symbol,_Period,lb);
   double curHigh=iHigh(_Symbol,_Period,1), curLow=iLow(_Symbol,_Period,1);
   double price=SymbolInfoDouble(_Symbol,SYMBOL_BID);
   bool sweptHighReversedDown=(curHigh>swHigh && price<swHigh);
   bool sweptLowReversedUp=(curLow<swLow && price>swLow);
   if(sig==SIGNAL_BUY)  return sweptLowReversedUp;
   if(sig==SIGNAL_SELL) return sweptHighReversedDown;
   return false;
}

bool DetectFVG(ENUM_SIGNAL sig)
{
   // 3-candle fair value gap: gap between candle[3] and candle[1] not covered by candle[2]
   double h3=iHigh(_Symbol,_Period,3), l3=iLow(_Symbol,_Period,3);
   double h1=iHigh(_Symbol,_Period,1), l1=iLow(_Symbol,_Period,1);
   double atr=GetATR(); if(atr<=0) return false;
   double minGap = atr*(InpFVGMinATRFrac/100.0);

   if(sig==SIGNAL_BUY)
   {
      double gap=l1-h3;
      return (gap>=minGap);
   }
   if(sig==SIGNAL_SELL)
   {
      double gap=l3-h1;
      return (gap>=minGap);
   }
   return false;
}

//==================================================================
// BTC-SPECIFIC GUARDS
//==================================================================
bool IsLiquidationCandle()
{
   double atr=GetATR(); if(atr<=0) return false;
   double o=iOpen(_Symbol,_Period,1), c=iClose(_Symbol,_Period,1);
   double h=iHigh(_Symbol,_Period,1), l=iLow(_Symbol,_Period,1);
   double body=MathAbs(c-o), range=h-l;
   return (range>=atr*InpLiqCandleATRMult && body>=range*0.6);
}

bool IsExhaustionCandle(ENUM_SIGNAL sig)
{
   double atr=GetATR(); if(atr<=0) return false;
   double o=iOpen(_Symbol,_Period,1), c=iClose(_Symbol,_Period,1);
   double h=iHigh(_Symbol,_Period,1), l=iLow(_Symbol,_Period,1);
   double range=h-l; if(range<=0) return false;
   if(sig==SIGNAL_BUY)
   {
      double upperWick=h-MathMax(o,c);
      return (range>=atr*1.5 && upperWick>=range*0.45);
   }
   if(sig==SIGNAL_SELL)
   {
      double lowerWick=MathMin(o,c)-l;
      return (range>=atr*1.5 && lowerWick>=range*0.45);
   }
   return false;
}

//==================================================================
// VOLATILITY REGIME (kept logic) + VOLUME AVERAGE
//==================================================================
void UpdateVolatilityRegime()
{
   static datetime lastBarTime=0;
   datetime curBarTime=(datetime)SeriesInfoInteger(_Symbol,_Period,SERIES_LASTBAR_DATE);
   if(curBarTime==lastBarTime) return; lastBarTime=curBarTime;

   double curATR=GetATR(); if(curATR<=0.0) return;
   int n=ArraySize(g_ATRHistory);
   for(int i=n-1;i>0;i--) g_ATRHistory[i]=g_ATRHistory[i-1];
   g_ATRHistory[0]=curATR;

   int validCount=0, belowCount=0;
   for(int i=1;i<n;i++)
   { if(g_ATRHistory[i]<=0.0) continue; validCount++; if(g_ATRHistory[i]<=curATR) belowCount++; }
   if(validCount<10){ g_VolPercentile=50.0; return; }
   g_VolPercentile=((double)belowCount/validCount)*100.0;
}

void UpdateVolumeAverage()
{
   static datetime lastVolBarTime=0;
   datetime curBarTime=(datetime)SeriesInfoInteger(_Symbol,_Period,SERIES_LASTBAR_DATE);
   if(curBarTime==lastVolBarTime) return; lastVolBarTime=curBarTime;
   long vol[1]; if(CopyTickVolume(_Symbol,_Period,1,1,vol)<=0) return;
   int cap=InpVolumeAvgPeriod*20;
   g_AvgVolume=(g_AvgVolume*g_VolumeSamples+(double)vol[0])/(double)(g_VolumeSamples+1);
   g_VolumeSamples=MathMin(g_VolumeSamples+1,cap);
}

//==================================================================
// DYNAMIC LOT SIZING (0.50%-2.00% adaptive risk)
//==================================================================
double CalculateLotSize(double slDistancePrice)
{
   double balance=AccountInfoDouble(ACCOUNT_BALANCE);
   double riskPct=GetRiskAdjustedPercent();
   double riskAmount=balance*(riskPct/100.0);

   double tickVal=SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_VALUE);
   double tickSize=SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE);
   if(tickSize<=0.0) return SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN);

   double slCostPerLot=(slDistancePrice/tickSize)*tickVal;
   if(slCostPerLot<=0.0) return SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN);

   double lot=riskAmount/slCostPerLot;
   double minV=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN), maxV=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MAX);
   double step=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_STEP);
   lot=MathMax(minV, MathMin(maxV, MathFloor(lot/step)*step));
   return lot;
}

double GetRiskAdjustedPercent()
{
   double pct=(InpMinRiskPercent+InpMaxRiskPercent)/2.0; // base midpoint

   if(g_ConsecLosses>=InpMaxLossStreak) pct=InpMinRiskPercent;
   else if(g_ConsecWins>=InpWinStreakBoost) pct=InpMaxRiskPercent;

   double equity=AccountInfoDouble(ACCOUNT_EQUITY);
   if(g_EquityPeak>0.0)
   {
      double ddPct=((g_EquityPeak-equity)/g_EquityPeak)*100.0;
      if(ddPct>8.0) pct=InpMinRiskPercent;
      else if(ddPct>4.0) pct=MathMin(pct, (InpMinRiskPercent+InpMaxRiskPercent)*0.4);
   }

   if(g_Regime==REGIME_HIGH_VOL) pct*=0.8;
   if(g_Regime==REGIME_EXTREME_VOL) pct=InpMinRiskPercent*0.5;

   // signal quality scaling: higher confluence score -> allow closer to max risk
   double qualityFactor = MathMin(1.0, (double)g_LastConfluenceScore/9.0);
   pct = InpMinRiskPercent + (pct-InpMinRiskPercent)*qualityFactor;

   return MathMax(InpMinRiskPercent, MathMin(InpMaxRiskPercent, pct));
}

//==================================================================
// PRE-TRADE ANALYSIS PHASE (kept)
//==================================================================
void ProcessAnalysisPhase()
{
   g_AnalysisTicks++;
   int elapsed=(int)(TimeCurrent()-g_AnalysisStart);
   g_StatusText="ANALYSING: "+IntegerToString(elapsed)+"s | Ticks: "+IntegerToString(g_AnalysisTicks);
   g_StatusColor=C_VIOLET;

   if(elapsed>InpAnalysisMaxSec)
   { Print("[NovaBTC v2] Analysis timeout."); g_State=STATE_SCANNING; return; }

   ENUM_SIGNAL current=EvaluateConfluence(false);
   if(current!=g_PendingSignal)
   { Print("[NovaBTC v2] Signal reversed - invalidated."); g_State=STATE_SCANNING; return; }

   if(elapsed>=InpAnalysisMinSec && g_AnalysisTicks>=InpAnalysisMinTicks)
   {
      ENUM_SIGNAL finalCheck=EvaluateConfluence(false);
      if(finalCheck!=g_PendingSignal)
      { Print("[NovaBTC v2] Final check failed."); g_StateTimer=TimeCurrent()+10; g_State=STATE_COOLDOWN; return; }
      if(g_LastConfluenceScore<InpMinScoreToTrade)
      { Print("[NovaBTC v2] Score too low at execution."); g_StateTimer=TimeCurrent()+10; g_State=STATE_COOLDOWN; return; }

      if(InpUseSMCFilter && !CheckSMCConfirmation(g_PendingSignal))
      { Print("[NovaBTC v2] SMC re-check failed at execution."); g_StateTimer=TimeCurrent()+10; g_State=STATE_COOLDOWN; return; }

      PrintFormat("[NovaBTC v2] Analysis complete. Score=%d/9 Regime=%s. Firing.",
                  g_LastConfluenceScore, RegimeToString(g_Regime));
      ExecuteEntry(g_PendingSignal);
      g_StateTimer=TimeCurrent()+10; g_State=STATE_COOLDOWN;
   }
}

//==================================================================
// EXECUTION
//==================================================================
void ExecuteEntry(ENUM_SIGNAL sig)
{
   if(!IsSpreadOk()){ Print("[NovaBTC v2] Spread too wide at execution - aborted."); return; }

   int digits=(int)SymbolInfoInteger(_Symbol,SYMBOL_DIGITS);
   double atr=GetATR();
   double price=(sig==SIGNAL_BUY)?SymbolInfoDouble(_Symbol,SYMBOL_ASK):SymbolInfoDouble(_Symbol,SYMBOL_BID);

   double slDistATR=atr*InpSLMultiplier;
   double minSLDist=price*(InpMinSLPercent/100.0), maxSLDist=price*(InpMaxSLPercent/100.0);
   double slDistance=MathMax(minSLDist, MathMin(maxSLDist, slDistATR));
   double tp2Distance=atr*InpTP2Multiplier;

   double sl,tp;
   if(sig==SIGNAL_BUY){ sl=NormalizeDouble(price-slDistance,digits); tp=NormalizeDouble(price+tp2Distance,digits); }
   else               { sl=NormalizeDouble(price+slDistance,digits); tp=NormalizeDouble(price-tp2Distance,digits); }

   double lot=CalculateLotSize(slDistance);

   double rsi[1]={0}; CopyBuffer(g_hRSI,0,0,1,rsi);
   double adx[1]={0}; CopyBuffer(g_hADX,0,0,1,adx);
   double bidNow=SymbolInfoDouble(_Symbol,SYMBOL_BID), askNow=SymbolInfoDouble(_Symbol,SYMBOL_ASK);

   g_ExecAttempts++;
   bool ok=(sig==SIGNAL_BUY)? g_Trade.Buy(lot,_Symbol,price,sl,tp,InpTradeComment)
                             : g_Trade.Sell(lot,_Symbol,price,sl,tp,InpTradeComment);
   UpdateExecutionQuality(ok);

   if(ok)
   {
      g_DailyTrades++;
      ResetTradeState();
      Sleep(100);
      CacheTradeEntry();
      g_EntrySpread=askNow-bidNow; g_EntryRSI=rsi[0]; g_EntryADX=adx[0];
      LogTradeOpen(sig, g_LastConfluenceScore);
      g_StatusText=(sig==SIGNAL_BUY)?"IN TRADE - LONG":"IN TRADE - SHORT";
      g_StatusColor=C_GREEN;
      PrintFormat("[NovaBTC v2] ENTRY %s | Lot=%.2f Price=%.2f SL=%.2f TP=%.2f Regime=%s",
                  (sig==SIGNAL_BUY?"BUY":"SELL"),lot,price,sl,tp,RegimeToString(g_Regime));
   }
   else
      Print("[NovaBTC v2] Order FAILED. RetCode=",g_Trade.ResultRetcode()," ",g_Trade.ResultRetcodeDescription());
}

void UpdateExecutionQuality(bool success)
{
   if(!success) g_ExecFails++;
   g_ExecQualityScore = (g_ExecAttempts>0)? (1.0-(g_ExecFails/g_ExecAttempts))*100.0 : 100.0;

   double bid=SymbolInfoDouble(_Symbol,SYMBOL_BID), ask=SymbolInfoDouble(_Symbol,SYMBOL_ASK);
   double spPct=(bid>0)?(ask-bid)/bid*100.0:99;
   g_SpreadQualityScore = MathMax(0.0, 100.0 - (spPct/InpMaxSpreadPercent)*100.0);
}

//==================================================================
// TRADE ENTRY CACHING
//==================================================================
void CacheTradeEntry()
{
   for(int i=PositionsTotal()-1;i>=0;i--)
   {
      if(!g_Pos.SelectByIndex(i)) continue;
      if(g_Pos.Magic()!=InpMagicNumber||g_Pos.Symbol()!=_Symbol) continue;

      g_EntryPrice=g_Pos.PriceOpen(); g_EntrySLPrice=g_Pos.StopLoss();
      g_EntryATR=GetATR();
      g_TradeDirection=(g_Pos.PositionType()==POSITION_TYPE_BUY)?1:-1;
      g_PeakProfit=0; g_BESet=false; g_PartialClosed=false;
      g_EntryMaxDD=0; g_EntryTicket=g_Pos.Ticket();
      g_EntryBarTime=(datetime)SeriesInfoInteger(_Symbol,_Period,SERIES_LASTBAR_DATE);
      g_EntryRegimeStr=RegimeToString(g_Regime);
      g_EntrySignalScoreStr=IntegerToString(g_LastConfluenceScore);

      double slDistPrice=MathAbs(g_EntryPrice-g_EntrySLPrice);
      double tickVal=SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_VALUE);
      double tickSize=SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE);
      g_EntryRiskUSD=(tickSize>0.0)? (slDistPrice/tickSize)*tickVal*g_Pos.Volume() : 0.01;
      if(g_EntryRiskUSD<=0.0) g_EntryRiskUSD=0.01;
      break;
   }
}
void ResetTradeState()
{
   g_PeakProfit=0; g_PartialClosePrice=0; g_BESet=false; g_PartialClosed=false;
   g_EntryATR=0; g_EntryPrice=0; g_EntrySLPrice=0; g_EntryRiskUSD=0; g_TradeDirection=0;
   g_EntryMaxDD=0; g_EntryTicket=0; g_EntryBarTime=0;
}

//==================================================================
// TRADE MANAGEMENT (upgraded)
//==================================================================
void ManageOpenTrade()
{
   if(!IsPositionOpen()){ ResetTradeState(); return; }

   double pnl=GetFloatingPnL();
   if(pnl>g_PeakProfit) g_PeakProfit=pnl;
   if(pnl<g_EntryMaxDD) g_EntryMaxDD=pnl; // most negative excursion

   string rStr=(g_EntryRiskUSD>0)? " ("+DoubleToString(pnl/g_EntryRiskUSD,2)+"R)":"";
   string pnlStr=(pnl>=0?"+$":"-$")+DoubleToString(MathAbs(pnl),2)+rStr+"  Peak:+$"+DoubleToString(g_PeakProfit,2);
   g_StatusText="TRADE RUNNING "+pnlStr;
   g_StatusColor=(pnl>=0)?C_GREEN:C_RED;

   CheckEmergencyExit(); if(!IsPositionOpen()) return;
   if(InpUsePeakLock) CheckPeakProfitLock(pnl); if(!IsPositionOpen()) return;
   if(InpUsePartialClose && !g_PartialClosed) CheckPartialClose(pnl); if(!IsPositionOpen()) return;
   CheckBreakeven(); if(!IsPositionOpen()) return;
   if(InpUseTrailing) CheckATRTrailing();
   if(InpUseStructTrail) CheckStructureTrailing();
   CheckTimeExit(); if(!IsPositionOpen()) return;
   CheckVolatilityCollapseExit(); if(!IsPositionOpen()) return;
   EvaluateFloatingPnL(pnl);
}

void CheckEmergencyExit()
{
   // close immediately on extreme volatility spike mid-trade
   if(g_Regime==REGIME_EXTREME_VOL)
   {
      double pnl=GetFloatingPnL();
      CloseAllPositions("Emergency exit - extreme volatility");
      LogTradeClose(pnl,"EmergencyExit");
      ResetTradeState();
   }
}

void CheckPeakProfitLock(double pnl)
{
   double oneR=g_EntryRiskUSD; if(oneR<=0.0) return;
   double activateLevel=oneR*InpPeakLockActR;
   if(g_PeakProfit<activateLevel) return;
   double retraceLevel=g_PeakProfit*(1.0-InpPeakLockRetr/100.0);
   double minRFloor=oneR*InpMinRewardRiskR;
   double lockLevel=MathMax(retraceLevel,minRFloor);
   if(g_PartialClosed) lockLevel=MathMax(lockLevel,oneR*InpMinLockProfitR);

   if(pnl<=lockLevel && pnl<g_PeakProfit)
   {
      CloseAllPositions("Peak-profit lock triggered");
      LogTradeClose(pnl,"PeakLock");
      g_StatusText="PEAK LOCK EXIT  Peak:+$"+DoubleToString(g_PeakProfit,2)+
                   " ("+DoubleToString(g_PeakProfit/oneR,2)+"R)";
      g_StatusColor=C_CYAN;
      ResetTradeState();
   }
}

void CheckPartialClose(double pnl)
{
   double oneR=g_EntryRiskUSD; if(oneR<=0.0) return;
   double tp1Level=oneR*InpTP1R; if(pnl<tp1Level) return;

   for(int i=PositionsTotal()-1;i>=0;i--)
   {
      if(!g_Pos.SelectByIndex(i)) continue;
      if(g_Pos.Magic()!=InpMagicNumber||g_Pos.Symbol()!=_Symbol) continue;
      bool isBuy=(g_Pos.PositionType()==POSITION_TYPE_BUY);
      double bid=SymbolInfoDouble(_Symbol,SYMBOL_BID), ask=SymbolInfoDouble(_Symbol,SYMBOL_ASK);
      double volStep=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_STEP);
      double closeLot=MathFloor((g_Pos.Volume()*(InpPartialClosePct/100.0))/volStep)*volStep;
      closeLot=NormalizeDouble(closeLot,2);
      double minLot=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN);

      if(closeLot<minLot)
      {
         CloseAllPositions("TP1 full close (lot too small to partial)");
         LogTradeClose(pnl,"TP1_FullClose");
         ResetTradeState(); return;
      }

      if(g_Trade.PositionClosePartial(g_Pos.Ticket(),closeLot))
      {
         g_PartialClosed=true;
         g_PartialClosePrice=isBuy?bid:ask;
         PrintFormat("[PartialClose] %.2f lots closed at %.2f. 1R=$%.2f Profit=$%.2f (%.2fR)",
                     closeLot,g_PartialClosePrice,oneR,pnl,pnl/oneR);
      }
   }
}

void CheckBreakeven()
{
   if(g_BESet) return;
   double oneR=g_EntryRiskUSD; if(oneR<=0.0) return;
   double pnl=GetFloatingPnL();
   double activateLevel=oneR*InpBreakevenR;
   if(pnl<activateLevel) return;

   for(int i=PositionsTotal()-1;i>=0;i--)
   {
      if(!g_Pos.SelectByIndex(i)) continue;
      if(g_Pos.Magic()!=InpMagicNumber||g_Pos.Symbol()!=_Symbol) continue;
      double open=g_Pos.PriceOpen(), sl=g_Pos.StopLoss();
      int digits=(int)SymbolInfoInteger(_Symbol,SYMBOL_DIGITS);
      bool isBuy=(g_Pos.PositionType()==POSITION_TYPE_BUY);
      double buffer=open*(InpBEBufferPercent/100.0);
      double beSL=isBuy? NormalizeDouble(open+buffer,digits) : NormalizeDouble(open-buffer,digits);
      bool needsMove=isBuy? (sl<beSL) : (sl>beSL||sl==0.0);
      if(needsMove && g_Trade.PositionModify(g_Pos.Ticket(),beSL,g_Pos.TakeProfit())) g_BESet=true;
   }
}

void CheckATRTrailing()
{
   double oneR=g_EntryRiskUSD; if(oneR<=0.0) return;
   double pnl=GetFloatingPnL();
   double activateLevel=oneR*InpTrailStartR;
   if(pnl<activateLevel) return;

   double atr=(g_EntryATR>0)?g_EntryATR:GetATR(); if(atr<=0) return;
   // trail tightens in stronger-trend regimes, loosens in choppier regimes
   double aggressiveness=1.0;
   if(g_Regime==REGIME_STRONG_TREND) aggressiveness=0.85;
   if(g_Regime==REGIME_RANGE)        aggressiveness=1.2;
   if(g_Regime==REGIME_HIGH_VOL)     aggressiveness=1.1;
   double trailDist=atr*InpTrailATRMult*aggressiveness;

   for(int i=PositionsTotal()-1;i>=0;i--)
   {
      if(!g_Pos.SelectByIndex(i)) continue;
      if(g_Pos.Magic()!=InpMagicNumber||g_Pos.Symbol()!=_Symbol) continue;
      double open=g_Pos.PriceOpen(), sl=g_Pos.StopLoss();
      double bid=SymbolInfoDouble(_Symbol,SYMBOL_BID), ask=SymbolInfoDouble(_Symbol,SYMBOL_ASK);
      int digits=(int)SymbolInfoInteger(_Symbol,SYMBOL_DIGITS);
      bool isBuy=(g_Pos.PositionType()==POSITION_TYPE_BUY);
      double newSL=isBuy? NormalizeDouble(bid-trailDist,digits) : NormalizeDouble(ask+trailDist,digits);

      if(g_BESet)
      {
         double buffer=open*(InpBEBufferPercent/100.0);
         double beFloor=isBuy? NormalizeDouble(open+buffer,digits) : NormalizeDouble(open-buffer,digits);
         newSL = isBuy? MathMax(newSL,beFloor) : MathMin(newSL,beFloor);
      }

      bool improves;
      if(isBuy) improves=(newSL>sl && newSL<bid);
      else      improves=(sl==0.0)? (newSL>ask) : (newSL<sl && newSL>ask);

      if(improves) g_Trade.PositionModify(g_Pos.Ticket(),newSL,g_Pos.TakeProfit());
   }
}

void CheckStructureTrailing()
{
   for(int i=PositionsTotal()-1;i>=0;i--)
   {
      if(!g_Pos.SelectByIndex(i)) continue;
      if(g_Pos.Magic()!=InpMagicNumber||g_Pos.Symbol()!=_Symbol) continue;
      bool isBuy=(g_Pos.PositionType()==POSITION_TYPE_BUY);
      int digits=(int)SymbolInfoInteger(_Symbol,SYMBOL_DIGITS);
      double sl=g_Pos.StopLoss();
      double bid=SymbolInfoDouble(_Symbol,SYMBOL_BID), ask=SymbolInfoDouble(_Symbol,SYMBOL_ASK);

      if(isBuy)
      {
         int lb=iLowest(_Symbol,_Period,MODE_LOW,InpStructTrailBars,1);
         double swLow=iLow(_Symbol,_Period,lb);
         double candidate=NormalizeDouble(swLow,digits);
         if(candidate>sl && candidate<bid) g_Trade.PositionModify(g_Pos.Ticket(),candidate,g_Pos.TakeProfit());
      }
      else
      {
         int hb=iHighest(_Symbol,_Period,MODE_HIGH,InpStructTrailBars,1);
         double swHigh=iHigh(_Symbol,_Period,hb);
         double candidate=NormalizeDouble(swHigh,digits);
         if((sl==0.0 || candidate<sl) && candidate>ask) g_Trade.PositionModify(g_Pos.Ticket(),candidate,g_Pos.TakeProfit());
      }
   }
}

void CheckTimeExit()
{
   if(g_EntryBarTime==0) return;
   datetime cur=(datetime)SeriesInfoInteger(_Symbol,_Period,SERIES_LASTBAR_DATE);
   int barsHeld=(int)((cur-g_EntryBarTime)/PeriodSeconds());
   if(barsHeld>=InpMaxBarsInTrade)
   {
      double pnl=GetFloatingPnL();
      CloseAllPositions("Time-based exit (stagnation)");
      LogTradeClose(pnl,"TimeExit");
      ResetTradeState();
   }
}

void CheckVolatilityCollapseExit()
{
   if(g_EntryATR<=0) return;
   double curATR=GetATR();
   if(curATR <= g_EntryATR*InpVolCollapseRatio)
   {
      double pnl=GetFloatingPnL();
      CloseAllPositions("Volatility collapse exit");
      LogTradeClose(pnl,"VolCollapseExit");
      ResetTradeState();
   }
}

void EvaluateFloatingPnL(double pnl)
{
   double balance=AccountInfoDouble(ACCOUNT_BALANCE);
   double dailyGoal=balance*(InpMaxDailyProfitPct/100.0);
   double remaining=dailyGoal-g_DailyProfit;
   if(remaining>0.0 && pnl>=remaining)
   {
      CloseAllPositions("Daily profit target reached");
      LogTradeClose(pnl,"DailyTargetExit");
      g_State=STATE_DAILY_LIMIT;
      ResetTradeState();
   }
}

//==================================================================
// CSV LOGGING (ML-research suitable)
//==================================================================
void LogTradeOpen(ENUM_SIGNAL sig,double score)
{
   if(!InpEnableCSVLog) return;
   int h=FileOpen(InpLogFileName, FILE_READ|FILE_WRITE|FILE_CSV|FILE_ANSI|FILE_COMMON);
   if(h==INVALID_HANDLE) return;
   FileSeek(h,0,SEEK_END);
   MqlDateTime dt; TimeToStruct(TimeCurrent(),dt);
   string dateStr=StringFormat("%04d.%02d.%02d",dt.year,dt.mon,dt.day);
   string timeStr=StringFormat("%02d:%02d:%02d",dt.hour,dt.min,dt.sec);
   FileWrite(h,dateStr,timeStr,(sig==SIGNAL_BUY?"BUY":"SELL"),
             DoubleToString(GetATR(),2), DoubleToString(g_EntryRSI,2), DoubleToString(g_EntryADX,2),
             DoubleToString(g_EntrySpread,2), g_EntryRegimeStr, g_EntrySignalScoreStr,
             DoubleToString(g_EntryPrice,2), "PENDING", DoubleToString(g_EntryRiskUSD,2));
   FileClose(h);
}

void LogTradeClose(double pnl,string reason)
{
   if(!InpEnableCSVLog) return;
   int h=FileOpen(InpLogFileName, FILE_READ|FILE_WRITE|FILE_CSV|FILE_ANSI|FILE_COMMON);
   if(h==INVALID_HANDLE) return;
   FileSeek(h,0,SEEK_END);
   MqlDateTime dt; TimeToStruct(TimeCurrent(),dt);
   string dateStr=StringFormat("%04d.%02d.%02d",dt.year,dt.mon,dt.day);
   string timeStr=StringFormat("%02d:%02d:%02d",dt.hour,dt.min,dt.sec);
   double rMultiple=(g_EntryRiskUSD>0)? pnl/g_EntryRiskUSD : 0;
   int durationSec=(g_EntryBarTime>0)?(int)(TimeCurrent()-g_EntryBarTime):0;
   FileWrite(h,dateStr,timeStr,"CLOSE_"+reason,
             DoubleToString(pnl,2), DoubleToString(MathMin(0,g_EntryMaxDD),2),
             IntegerToString(durationSec), DoubleToString(rMultiple,3));
   FileClose(h);
}

//==================================================================
// STATS SYNC
//==================================================================
void SyncDailyStats()
{
   datetime now=TimeCurrent(); datetime dayStart=GetDayStart(now);
   if(dayStart>g_SessionDay)
   {
      g_SessionDay=dayStart; g_DailyTrades=0; g_DailyProfit=0.0; g_DailyWins=0; g_DailyLosses=0;
      g_SessionOpenBal=AccountInfoDouble(ACCOUNT_BALANCE);
      if(g_State==STATE_DAILY_LIMIT) g_State=STATE_SCANNING;
   }
   g_DailyProfit=0.0; g_DailyWins=0; g_DailyLosses=0;
   datetime scanFrom=dayStart-7*86400;
   if(!HistorySelect(scanFrom,now)) return;

   int ringBuf[7]; ArrayInitialize(ringBuf,-1);
   int ringIdx=0; bool lastWasWin=false; int curStreak=0; int totalDeals=0;

   for(int i=0;i<HistoryDealsTotal();i++)
   {
      ulong tkt=HistoryDealGetTicket(i); if(tkt==0) continue;
      if(HistoryDealGetInteger(tkt,DEAL_MAGIC)!=(long)InpMagicNumber) continue;
      if(HistoryDealGetString(tkt,DEAL_SYMBOL)!=_Symbol) continue;
      if(HistoryDealGetInteger(tkt,DEAL_ENTRY)!=DEAL_ENTRY_OUT) continue;
      double pnl=HistoryDealGetDouble(tkt,DEAL_PROFIT)+HistoryDealGetDouble(tkt,DEAL_COMMISSION)+HistoryDealGetDouble(tkt,DEAL_SWAP);
      bool win=(pnl>=0.0); totalDeals++;
      datetime dealTime=(datetime)HistoryDealGetInteger(tkt,DEAL_TIME);
      if(dealTime>=dayStart){ g_DailyProfit+=pnl; if(win) g_DailyWins++; else g_DailyLosses++; }
      ringBuf[ringIdx%7]=win?1:0; ringIdx++;
      if(win==lastWasWin) curStreak++; else curStreak=1;
      lastWasWin=win;
   }
   if(totalDeals>0){ if(lastWasWin){g_ConsecWins=curStreak; g_ConsecLosses=0;} else {g_ConsecLosses=curStreak; g_ConsecWins=0;} }
   else { g_ConsecWins=0; g_ConsecLosses=0; }

   int wins7=0, total7=0;
   for(int j=0;j<7;j++){ if(ringBuf[j]<0) continue; total7++; if(ringBuf[j]==1) wins7++; }
   g_WinRate7=(total7>0)?((double)wins7/total7)*100.0:0.0;
   for(int j=0;j<7;j++) g_Last7Results[j]=ringBuf[j];
}

//==================================================================
// UTILITY
//==================================================================
bool IsPositionOpen(){ for(int i=PositionsTotal()-1;i>=0;i--) if(g_Pos.SelectByIndex(i)&&g_Pos.Magic()==InpMagicNumber&&g_Pos.Symbol()==_Symbol) return true; return false; }
double GetFloatingPnL(){ double t=0.0; for(int i=PositionsTotal()-1;i>=0;i--) if(g_Pos.SelectByIndex(i)&&g_Pos.Magic()==InpMagicNumber&&g_Pos.Symbol()==_Symbol) t+=g_Pos.Profit()+g_Pos.Swap()+g_Pos.Commission(); return t; }
void CloseAllPositions(string reason)
{
   PrintFormat("[NovaBTC v2] CloseAll: %s | Peak was $%.2f",reason,g_PeakProfit);
   for(int i=PositionsTotal()-1;i>=0;i--)
      if(g_Pos.SelectByIndex(i)&&g_Pos.Magic()==InpMagicNumber&&g_Pos.Symbol()==_Symbol)
         g_Trade.PositionClose(g_Pos.Ticket());
   g_StateTimer=TimeCurrent()+30;
   g_State=STATE_COOLDOWN;
}
bool IsMarketOpen(){ ENUM_SYMBOL_TRADE_MODE m=(ENUM_SYMBOL_TRADE_MODE)SymbolInfoInteger(_Symbol,SYMBOL_TRADE_MODE); return (m==SYMBOL_TRADE_MODE_FULL||m==SYMBOL_TRADE_MODE_LONGONLY||m==SYMBOL_TRADE_MODE_SHORTONLY); }
bool IsSpreadOk()
{
   double bid=SymbolInfoDouble(_Symbol,SYMBOL_BID), ask=SymbolInfoDouble(_Symbol,SYMBOL_ASK);
   if(bid<=0.0) return false;
   double spread=ask-bid, spreadPct=(spread/bid)*100.0;
   if(spreadPct>InpMaxSpreadPercent) return false;
   if(g_SpreadSamples>50 && spread>g_AvgSpread*InpSpreadAvgMultiple) return false;
   return true;
}
void UpdateSpreadAverage()
{
   double bid=SymbolInfoDouble(_Symbol,SYMBOL_BID), ask=SymbolInfoDouble(_Symbol,SYMBOL_ASK);
   double spread=ask-bid; int cap=2000;
   g_AvgSpread=(g_AvgSpread*g_SpreadSamples+spread)/(double)(g_SpreadSamples+1);
   g_SpreadSamples=MathMin(g_SpreadSamples+1,cap);
}
bool IsDailyLossLimitHit(){ double balance=AccountInfoDouble(ACCOUNT_BALANCE); double limit=balance*(InpMaxDailyLossPct/100.0); return (g_DailyProfit<=-MathAbs(limit)); }
bool IsDailyProfitTargetHit(){ double balance=AccountInfoDouble(ACCOUNT_BALANCE); double target=balance*(InpMaxDailyProfitPct/100.0); return (g_DailyProfit>=target); }
bool IsDrawdownLimitHit()
{
   if(g_EquityPeak<=0.0) return false;
   double equity=AccountInfoDouble(ACCOUNT_EQUITY);
   double ddPct=((g_EquityPeak-equity)/g_EquityPeak)*100.0;
   return (ddPct>=InpMaxDrawdownPct);
}
bool IsWeekendPauseActive()
{
   MqlDateTime dt; TimeToStruct(TimeGMT(),dt);
   if(dt.day_of_week==1 && dt.hour==0 && dt.min<InpWeekendPauseMin) return true;
   return false;
}
datetime GetDayStart(datetime t){ MqlDateTime d; TimeToStruct(t,d); return t-(datetime)(d.hour*3600+d.min*60+d.sec); }
string TimeframeToString(ENUM_TIMEFRAMES tf)
{
   switch(tf){ case PERIOD_M1:return "1"; case PERIOD_M5:return "5"; case PERIOD_M15:return "15";
      case PERIOD_M30:return "30"; case PERIOD_H1:return "H1"; case PERIOD_H4:return "H4"; case PERIOD_D1:return "D1"; default:return "?"; }
}

//==================================================================
// DASHBOARD
//==================================================================
#define DW  340
void RenderDashboard()
{
   int X=InpDashX, Y=InpDashY, W=DW, y=Y;
   DrawRect("SHELL",X,Y,W,500,C_BG,C_BORDER,2);

   DrawRect("HDR_BG",X+2,y+2,W-4,26,C_HEADER,C_BORDER,1);
   DrawLabel("HDR_IC",X+6,y+4,"NOVA BTC SCALPER AI v2",C_CYAN,8,"Arial Black");
   DrawLabel("HDR_SYM",X+W-95,y+4,_Symbol,C_GOLD,9,"Impact");
   DrawLabel("HDR_TF",X+W-50,y+15,TimeframeToString(_Period),C_MUTED,7,"Arial");
   DrawLabel("HDR_VER",X+6,y+15,EA_VERSION+" UPGRADED",C_MUTED,7,"Arial");
   y+=29;

   DrawRect("RG_HDR",X+2,y,W-4,13,C_SECTION_HDR,C_BORDER2,1);
   DrawLabel("RG_TIT",X+6,y+2,"REGIME & QUALITY",C_ORANGE,7,"Arial Black");
   y+=14;
   DrawRect("RG_BG",X+2,y,W-4,56,C_PANEL,C_BORDER2,1);
   DrawLabel("L_RG",X+6,y+3,"Regime",C_MUTED,7,"Arial"); DrawLabel("V_RG",X+60,y+3,"-",C_GOLD,8,"Arial Bold");
   DrawLabel("L_SIG",X+W/2+2,y+3,"Signal Score",C_MUTED,7,"Arial"); DrawLabel("V_SIG",X+W/2+70,y+3,"0/9",C_CYAN,8,"Arial Bold");
   DrawLabel("L_SPQ",X+6,y+16,"Spread Qual",C_MUTED,7,"Arial"); DrawLabel("V_SPQ",X+70,y+16,"100%",C_GREEN,7,"Arial Bold");
   DrawLabel("L_EXQ",X+W/2+2,y+16,"Exec Qual",C_MUTED,7,"Arial"); DrawLabel("V_EXQ",X+W/2+70,y+16,"100%",C_GREEN,7,"Arial Bold");
   DrawLabel("L_VOLP",X+6,y+29,"Vol Pctl",C_MUTED,7,"Arial"); DrawLabel("V_VOLP",X+70,y+29,"50%",C_WHITE,7,"Arial Bold");
   DrawLabel("L_RISK",X+W/2+2,y+29,"Risk %",C_MUTED,7,"Arial"); DrawLabel("V_RISK",X+W/2+70,y+29,"-",C_GOLD,7,"Arial Bold");
   DrawLabel("L_LIQC",X+6,y+42,"Liq Cooldown",C_MUTED,7,"Arial"); DrawLabel("V_LIQC",X+90,y+42,"0",C_WHITE,7,"Arial Bold");
   y+=60;

   DrawRect("SE_HDR",X+2,y,W-4,13,C_SECTION_HDR,C_BORDER2,1);
   DrawLabel("SE_TIT",X+6,y+2,"AI DECISION ENGINE",C_ORANGE,7,"Arial Black");
   y+=14;
   DrawRect("AI_BG",X+2,y,W-4,44,C_PANEL,C_BORDER2,1);
   DrawLabel("L_AIST",X+6,y+3,"STATUS",C_MUTED,7,"Arial"); DrawLabel("V_AIST",X+50,y+3,"BOOTING",C_CYAN,7,"Arial Black");
   DrawLabel("L_AILD",X+6,y+16,"LAST",C_MUTED,7,"Arial"); DrawLabel("V_AILD",X+W-40,y+16,"HOLD",C_GOLD,7,"Arial Bold");
   DrawLabel("L_RM",X+6,y+29,"RISK MODE",C_MUTED,7,"Arial"); DrawLabel("V_RM",X+70,y+29,"NORMAL",C_GOLD,7,"Arial Bold");
   y+=46;

   DrawRect("OP_HDR",X+2,y,W-4,13,C_SECTION_HDR,C_BORDER2,1);
   DrawLabel("OP_TIT",X+6,y+2,"OPEN POSITION",C_ORANGE,7,"Arial Black");
   y+=14;
   DrawRect("OP_BG",X+2,y,W-4,42,C_PANEL,C_BORDER2,1);
   DrawLabel("L_OTYP",X+6,y+3,"TYPE",C_MUTED,7,"Arial"); DrawLabel("V_OTYP",X+32,y+3,"---",C_MUTED,8,"Arial Bold");
   DrawLabel("L_OLOT",X+W/2-10,y+3,"LOT",C_MUTED,7,"Arial"); DrawLabel("V_OLOT",X+W/2+14,y+3,"---",C_MUTED,8,"Arial Bold");
   DrawLabel("L_OOPN",X+6,y+16,"OPEN",C_MUTED,7,"Arial"); DrawLabel("V_OOPN",X+34,y+16,"---",C_WHITE,7,"Arial Bold");
   DrawLabel("L_OSLT",X+W/2-10,y+16,"SL/TP",C_MUTED,7,"Arial"); DrawLabel("V_OSLT",X+W/2+24,y+16,"--- / ---",C_WHITE,7,"Arial Bold");
   DrawLabel("L_OPNL",X+6,y+29,"P&L",C_MUTED,7,"Arial"); DrawLabel("V_OPNL",X+30,y+29,"+$0.00 (0.0R)",C_GREEN,7,"Arial Bold");
   DrawLabel("L_OPK",X+W/2+30,y+29,"PK",C_MUTED,7,"Arial"); DrawLabel("V_OPK",X+W/2+48,y+29,"+$0.00",C_CYAN,7,"Arial Bold");
   y+=44;

   DrawRect("AC_HDR",X+2,y,W-4,13,C_SECTION_HDR,C_BORDER2,1);
   DrawLabel("AC_TIT",X+6,y+2,"ACCOUNT INFO",C_ORANGE,7,"Arial Black");
   y+=14;
   DrawRect("AC_BG",X+2,y,W-4,56,C_PANEL,C_BORDER2,1);
   DrawLabel("L_BAL",X+6,y+3,"BAL",C_MUTED,7,"Arial"); DrawLabel("V_BAL",X+30,y+3,"$0.00",C_GREEN,8,"Arial Bold");
   DrawLabel("L_EQ",X+W/2+2,y+3,"EQ",C_MUTED,7,"Arial"); DrawLabel("V_EQ",X+W/2+20,y+3,"$0.00",C_WHITE,8,"Arial Bold");
   DrawLabel("L_DP",X+6,y+16,"DAY",C_MUTED,7,"Arial"); DrawLabel("V_DP",X+30,y+16,"+0.00",C_GREEN,7,"Arial Bold");
   DrawLabel("L_DD",X+W/2+2,y+16,"DD",C_MUTED,7,"Arial"); DrawLabel("V_DD",X+W/2+24,y+16,"0.00%",C_WHITE,7,"Arial Bold");
   DrawLabel("L_WR",X+6,y+29,"WR",C_MUTED,7,"Arial"); DrawLabel("V_WR",X+26,y+29,"0% | 7T:0%",C_CYAN,7,"Arial Bold");
   DrawLabel("L_TR",X+W/2+2,y+29,"TRADES",C_MUTED,7,"Arial"); DrawLabel("V_TR",X+W/2+45,y+29,"0/12",C_WHITE,7,"Arial Bold");
   DrawLabel("L_STKR",X+6,y+42,"STRK",C_MUTED,7,"Arial"); DrawLabel("V_STK",X+32,y+42,"---",C_MUTED,7,"Arial Bold");
   DrawLabel("V_CONF",X+W/2+2,y+42,"",C_CYAN,7,"Consolas");
   y+=60;

   DrawRect("FT",X+2,y,W-4,30,C_PANEL2,C_BORDER2,1);
   DrawLabel("F1",X+6,y+4,"Status:",C_MUTED,7,"Arial");
   DrawLabel("V_FST",X+50,y+4,"-",C_VIOLET,7,"Arial");

   ChartRedraw(0);
}

void UpdateDashboard()
{
   SetLabel("V_RG",RegimeToString(g_Regime),C_GOLD);
   SetLabel("V_SIG",IntegerToString(g_LastConfluenceScore)+"/9",C_CYAN);
   SetLabel("V_SPQ",DoubleToString(g_SpreadQualityScore,0)+"%", g_SpreadQualityScore>70?C_GREEN:C_RED);
   SetLabel("V_EXQ",DoubleToString(g_ExecQualityScore,0)+"%", g_ExecQualityScore>90?C_GREEN:C_GOLD);
   SetLabel("V_VOLP",DoubleToString(g_VolPercentile,0)+"%",C_WHITE);
   SetLabel("V_RISK",DoubleToString(GetRiskAdjustedPercent(),2)+"%",C_GOLD);
   SetLabel("V_LIQC",IntegerToString(g_LiqCandleCooldown), g_LiqCandleCooldown>0?C_RED:C_WHITE);

   SetLabel("V_AIST",g_StatusText,g_StatusColor);
   ENUM_SIGNAL curSig=(g_PendingSignal!=SIGNAL_NONE)?g_PendingSignal:SIGNAL_NONE;
   SetLabel("V_AILD", curSig==SIGNAL_BUY?"BUY":(curSig==SIGNAL_SELL?"SELL":"HOLD"),
            curSig==SIGNAL_BUY?C_GREEN:(curSig==SIGNAL_SELL?C_RED:C_GOLD));
   string riskMode = (g_ConsecLosses>=InpMaxLossStreak)?"REDUCED":(g_ConsecWins>=InpWinStreakBoost?"BOOSTED":"NORMAL");
   SetLabel("V_RM",riskMode, riskMode=="REDUCED"?C_RED:(riskMode=="BOOSTED"?C_GREEN:C_GOLD));

   bool hasPos=false; double rowPnl=0.0;
   for(int i=0;i<PositionsTotal();i++)
   {
      if(g_Pos.SelectByIndex(i)&&g_Pos.Magic()==InpMagicNumber&&g_Pos.Symbol()==_Symbol)
      {
         hasPos=true;
         string typStr=(g_Pos.PositionType()==POSITION_TYPE_BUY)?"BUY":"SELL";
         color typClr=(g_Pos.PositionType()==POSITION_TYPE_BUY)?C_GREEN:C_RED;
         rowPnl=g_Pos.Profit()+g_Pos.Swap()+g_Pos.Commission();
         SetLabel("V_OTYP",typStr,typClr);
         SetLabel("V_OLOT",DoubleToString(g_Pos.Volume(),2),C_WHITE);
         SetLabel("V_OOPN",DoubleToString(g_Pos.PriceOpen(),2),C_WHITE);
         SetLabel("V_OSLT",DoubleToString(g_Pos.StopLoss(),2)+" / "+DoubleToString(g_Pos.TakeProfit(),2),C_WHITE);
         string rTxt=(g_EntryRiskUSD>0)? " ("+DoubleToString(rowPnl/g_EntryRiskUSD,2)+"R)":"";
         color pnlClr=(rowPnl>=0)?C_GREEN:C_RED;
         SetLabel("V_OPNL",(rowPnl>=0?"+$":"-$")+DoubleToString(MathAbs(rowPnl),2)+rTxt,pnlClr);
         SetLabel("V_OPK","+$"+DoubleToString(g_PeakProfit,2),C_CYAN);
         break;
      }
   }
   if(!hasPos)
   {
      SetLabel("V_OTYP","---",C_MUTED); SetLabel("V_OLOT","---",C_MUTED); SetLabel("V_OOPN","---",C_MUTED);
      SetLabel("V_OSLT","--- / ---",C_MUTED); SetLabel("V_OPNL","+$0.00",C_MUTED); SetLabel("V_OPK","+$0.00",C_MUTED);
   }

   double bal=AccountInfoDouble(ACCOUNT_BALANCE), eq=AccountInfoDouble(ACCOUNT_EQUITY);
   SetLabel("V_BAL","$"+DoubleToString(bal,2),C_GREEN);
   SetLabel("V_EQ","$"+DoubleToString(eq,2),C_WHITE);
   color cDp=(g_DailyProfit>=0)?C_GREEN:C_RED;
   SetLabel("V_DP",(g_DailyProfit>=0?"+$":"-$")+DoubleToString(MathAbs(g_DailyProfit),2),cDp);
   double dd=(g_EquityPeak>0)?((g_EquityPeak-eq)/g_EquityPeak*100.0):0;
   SetLabel("V_DD",DoubleToString(dd,2)+"%", dd>InpMaxDrawdownPct*0.5?C_RED:C_WHITE);
   int tot=g_DailyWins+g_DailyLosses; double wr=(tot>0)?((double)g_DailyWins/tot)*100.0:0.0;
   color cWR=(g_WinRate7>=60)?C_GREEN:(g_WinRate7>=40?C_GOLD:C_RED);
   SetLabel("V_WR",IntegerToString((int)wr)+"% | 7T:"+IntegerToString((int)g_WinRate7)+"%",cWR);
   SetLabel("V_TR",IntegerToString(g_DailyTrades)+"/"+IntegerToString(InpMaxDailyTrades),C_WHITE);

   if(g_ConsecLosses>=2) SetLabel("V_STK","LOSS x"+IntegerToString(g_ConsecLosses),C_RED);
   else if(g_ConsecWins>=2) SetLabel("V_STK","WIN x"+IntegerToString(g_ConsecWins),C_GREEN);
   else SetLabel("V_STK","---",C_MUTED);

   string strip="";
   for(int j=0;j<7;j++)
   { if(g_Last7Results[j]<0) strip+=". "; else if(g_Last7Results[j]==1) strip+="W "; else strip+="L "; }
   SetLabel("V_CONF",strip,C_CYAN);
   SetLabel("V_FST",g_StatusText,g_StatusColor);

   ChartRedraw(0);
}

void PurgeDashboard(){ ObjectsDeleteAll(0,DASH_PREFIX); ChartRedraw(0); }

void DrawRect(string id,int x,int y,int w,int h,color bg,color border,int bw)
{
   string n=DASH_PREFIX+id;
   if(ObjectFind(0,n)<0) ObjectCreate(0,n,OBJ_RECTANGLE_LABEL,0,0,0);
   ObjectSetInteger(0,n,OBJPROP_CORNER,CORNER_LEFT_UPPER);
   ObjectSetInteger(0,n,OBJPROP_XDISTANCE,x); ObjectSetInteger(0,n,OBJPROP_YDISTANCE,y);
   ObjectSetInteger(0,n,OBJPROP_XSIZE,w); ObjectSetInteger(0,n,OBJPROP_YSIZE,h);
   ObjectSetInteger(0,n,OBJPROP_BGCOLOR,bg);
   if(border!=clrNONE){ ObjectSetInteger(0,n,OBJPROP_BORDER_TYPE,BORDER_FLAT); ObjectSetInteger(0,n,OBJPROP_COLOR,border); ObjectSetInteger(0,n,OBJPROP_WIDTH,bw); }
   else ObjectSetInteger(0,n,OBJPROP_BORDER_TYPE,BORDER_RAISED);
   ObjectSetInteger(0,n,OBJPROP_SELECTABLE,false); ObjectSetInteger(0,n,OBJPROP_HIDDEN,true); ObjectSetInteger(0,n,OBJPROP_ZORDER,0);
}
void DrawLabel(string id,int x,int y,string txt,color clr,int sz,string fnt)
{
   string n=DASH_PREFIX+id;
   if(ObjectFind(0,n)<0) ObjectCreate(0,n,OBJ_LABEL,0,0,0);
   ObjectSetInteger(0,n,OBJPROP_CORNER,CORNER_LEFT_UPPER);
   ObjectSetInteger(0,n,OBJPROP_XDISTANCE,x); ObjectSetInteger(0,n,OBJPROP_YDISTANCE,y);
   ObjectSetString(0,n,OBJPROP_TEXT,txt); ObjectSetInteger(0,n,OBJPROP_COLOR,clr);
   ObjectSetInteger(0,n,OBJPROP_FONTSIZE,sz); ObjectSetString(0,n,OBJPROP_FONT,fnt);
   ObjectSetInteger(0,n,OBJPROP_SELECTABLE,false); ObjectSetInteger(0,n,OBJPROP_HIDDEN,true); ObjectSetInteger(0,n,OBJPROP_ZORDER,1);
}
void SetLabel(string id,string txt,color clr=clrNONE)
{
   string n=DASH_PREFIX+id;
   if(ObjectFind(0,n)>=0){ ObjectSetString(0,n,OBJPROP_TEXT,txt); if(clr!=clrNONE) ObjectSetInteger(0,n,OBJPROP_COLOR,clr); }
}
//+------------------------------------------------------------------+
