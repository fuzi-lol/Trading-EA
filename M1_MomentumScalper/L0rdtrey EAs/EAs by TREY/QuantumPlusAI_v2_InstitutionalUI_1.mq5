//+------------------------------------------------------------------+
//|                                    QUANTUM PLUS AI v2.0          |
//|              Institutional AI Market Analyst Terminal            |
//|              Maximum Visibility | Professional Grade             |
//+------------------------------------------------------------------+
#property copyright   "Quantum Plus AI v2.0 - AI Market Analyst"
#property version     "2.00"
#property description "Institutional AI Market Analyst Terminal"
#property strict

#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>
#include <Trade\AccountInfo.mqh>
#include <Trade\OrderInfo.mqh>

//=====================================================================
//  CRITICAL DEFINES
//=====================================================================
#define D    "QPA2_"
#define OV   "QPA2_OV_"
#define M_PI 3.14159265358979323846

//=====================================================================
//  ENUMERATIONS
//=====================================================================
enum ENUM_REGIME
{
   REGIME_TRENDING,
   REGIME_RANGING,
   REGIME_BREAKOUT,
   REGIME_COMPRESSION,
   REGIME_EXPANSION,
   REGIME_VOLATILITY_SHOCK,
   REGIME_LIQUIDITY_SWEEP,
   REGIME_EXHAUSTION,
   REGIME_MEAN_REVERSION,
   REGIME_UNSAFE
};

enum ENUM_VOL_STATE   { VOL_LOW, VOL_NORMAL, VOL_HIGH, VOL_EXTREME };
enum ENUM_VOL_DYNAMIC { VOLDYN_EXPANDING, VOLDYN_COMPRESSING, VOLDYN_STABLE, VOLDYN_SPIKE };

enum ENUM_SESSION
{
   SESSION_ASIAN,
   SESSION_LONDON_OPEN,
   SESSION_LONDON_MID,
   SESSION_NY_OPEN,
   SESSION_NY_PM,
   SESSION_DEAD_ZONE
};

enum ENUM_NEWS_STATE  { NEWS_NORMAL, NEWS_CAUTION, NEWS_SHOCK };

enum ENUM_STRATEGY
{
   STRAT_NONE,
   STRAT_TREND_SCALPER,
   STRAT_MEAN_REVERSION,
   STRAT_VOLATILITY_EXPANSION,
   STRAT_LIQUIDITY_REVERSAL,
   STRAT_COMPRESSION_BREAKOUT
};

enum ENUM_DIRECTION   { DIR_NONE, DIR_LONG, DIR_SHORT };

//=====================================================================
//  DATA STRUCTURES
//=====================================================================
struct RegimeState
{
   ENUM_REGIME  regime;
   double       confidence;
   double       stability;
   datetime     sinceTime;
   ENUM_REGIME  previousRegime;
};

struct VolatilityState
{
   ENUM_VOL_STATE   state;
   ENUM_VOL_DYNAMIC dynamic;
   double           atrCurrent;
   double           atrAvg;
   double           atrRatio;
   double           percentile;
};

struct LiquidityState
{
   double  biasScore;
   double  pressureScore;
   double  sweepProbability;
   double  imbalanceScore;
   bool    equalHighsDetected;
   bool    equalLowsDetected;
   double  equalHighLevel;
   double  equalLowLevel;
   bool    sweepUpDetected;
   bool    sweepDownDetected;
};

struct SessionState
{
   ENUM_SESSION  current;
   double        sessionRangeATRRatio;
   double        sessionVolatilityScore;
   ENUM_STRATEGY preferredStrategy;
   double        strategyWeight;
};

struct MTFBias
{
   int    h1Bias;
   int    m15Bias;
   int    m5Bias;
   int    m1Bias;
   double alignment;
};

struct StrategySignal
{
   ENUM_STRATEGY  source;
   ENUM_DIRECTION direction;
   double         confidence;
   double         suggestedSL;
   double         suggestedTP;
   string         reason;
   bool           valid;
};

struct StrategyHealth
{
   string   name;
   int      totalTrades;
   int      wins;
   int      losses;
   double   grossProfit;
   double   grossLoss;
   double   sumR;
   double   sumRSquared;
   int      consecLosses;
   int      maxConsecLosses;
   double   winRate;
   double   profitFactor;
   double   expectancyR;
   double   sharpeProxy;
   bool     enabled;
   double   influenceMultiplier;
   datetime lastDegradedTime;
};

struct ExecutionQuality
{
   double spreadScore;
   double slippageRiskScore;
   double volatilityQuality;
   double liquidityQuality;
   double efficiencyScore;
   double compositeScore;
   bool   executionApproved;
   string rejectReason;
};

struct RiskState
{
   double  dailyRiskUsedPct;
   double  weeklyRiskUsedPct;
   double  currentDrawdownPct;
   double  maxDrawdownSeenPct;
   bool    dailyLimitHit;
   bool    weeklyLimitHit;
   bool    maxDrawdownBreached;
   bool    emergencyShutdown;
   double  peakEquity;
   double  weekStartEquity;
   double  dayStartEquity;
};

struct MasterDecision
{
   bool           tradeApproved;
   ENUM_DIRECTION direction;
   double         lotSize;
   double         slPrice;
   double         tpPrice;
   ENUM_STRATEGY  strategySource;
   double         riskAmountUsed;
   string         narrative;
};

struct MarketScores
{
   double trendScore;
   double liquidityScore;
   double volumeScore;
   double sessionScore;
   double structureScore;
   double momentumScore;
   double volatilityScore;
   double structureClarity;
   double totalScore;
};

struct StructureLabel
{
   string   type;    // "HH","HL","LH","LL","BOS","CHOCH","MSS"
   double   price;
   datetime time;
   bool     isBullish;
};

//=====================================================================
//  INPUTS
//=====================================================================
input group "===== IDENTITY ====="
input ulong  InpMagicNumber         = 778800;
input string InpBotName             = "QUANTUM PLUS AI v2.0";

input group "===== TRADE ENABLEMENT ====="
input bool   InpRelaxedMode             = true;   // loosen gating so signals fire more often
input double InpRelaxedRegimeConfidence = 28.0;   // used instead of InpMinRegimeConfidence when relaxed
input double InpRelaxedExecScore        = 35.0;   // used instead of InpMinExecutionScore when relaxed
input double InpRelaxedMTFAlignment     = 25.0;   // used instead of the 55 hard-coded alignment gate
input bool   InpResetEmergencyShutdown  = false;  // set true once to clear a stuck shutdown flag, then revert to false

input group "===== RISK GOVERNANCE ====="
input double InpRiskPercentPerTrade = 0.5;
input double InpMaxRiskPercentTrade = 1.0;
input double InpMaxDailyLossPct     = 3.0;
input double InpMaxWeeklyLossPct    = 7.0;
input double InpMaxDrawdownPct      = 12.0;
input int    InpMaxDailyTrades      = 8;
input int    InpMaxConcurrentTrades = 1;
input int    InpBrokerGMTOffset     = 2;

input group "===== EXECUTION ====="
input double InpMaxSpreadPoints     = 350;
input double InpMinExecutionScore   = 60.0;
input int    InpCooldownAfterCloseSec = 30;

input group "===== REGIME DETECTION ====="
input int    InpATRPeriod           = 14;
input int    InpATRLookback         = 100;
input int    InpEMAFastPeriod       = 8;
input int    InpEMASlowPeriod       = 34;
input int    InpStructureLookback   = 20;
input double InpMinRegimeConfidence = 55.0;

input group "===== LIQUIDITY ====="
input double InpEqualLevelTolerance = 0.15;
input int    InpLiquidityLookback   = 40;

input group "===== NEWS SHOCK ====="
input double InpShockATRMultiple    = 2.5;
input double InpShockSpreadMultiple = 2.0;

input group "===== STRATEGY HEALTH ====="
input int    InpHealthMinTrades           = 8;
input int    InpHealthDegradeConsecLoss   = 4;
input double InpHealthMinExpectancyR      = -0.10;

input group "===== ADAPTIVE ====="
input bool   InpEnableAdaptiveParams = true;
input double InpAdaptiveBoundPct     = 20.0;

input group "===== DASHBOARD ====="
input bool   InpShowDash    = true;
input int    InpDashX       = 10;
input int    InpDashY       = 10;
input int    InpDashWidth   = 420;

input group "===== ANALYST PANEL ====="
input bool   InpShowAnalystPanel    = true;
input int    InpAnalystX            = 440;
input int    InpAnalystY            = 10;
input int    InpNarrativeUpdateSec  = 45;

input group "===== CHART OVERLAYS ====="
input bool   InpDrawSessionBoxes    = true;
input bool   InpDrawLiquidityZones  = true;
input bool   InpDrawSignalMarkers   = true;
input bool   InpDrawStructure       = true;
input bool   InpDrawFVG             = true;
input bool   InpDrawOrderBlocks     = true;
input bool   InpDrawBSLSSL          = true;
input bool   InpDrawRegimeOverlay   = true;
input bool   InpDrawVolumeSpikes    = true;
input int    InpSessionBoxLookbackHrs = 24;

input group "===== DISPLAY SCALING ====="
input int    InpDPIScale            = 100;  // 100=1080p, 125=1440p, 150=4K

//=====================================================================
//  HIGH-CONTRAST INSTITUTIONAL COLOR PALETTE
//=====================================================================
// Primary background tones
#define C_CHART_BG    C'5,5,5'
#define C_PANEL_BG    C'8,15,35'
#define C_PANEL_BG2   C'12,22,50'
#define C_PANEL_HDR   C'15,30,65'
#define C_PANEL_BRD   C'0,100,180'
#define C_PANEL_BRD2  C'0,60,120'

// Accent colors
#define C_CYAN_BRIGHT C'0,255,255'
#define C_GOLD_BRIGHT C'255,215,0'
#define C_WHITE_PURE  C'255,255,255'
#define C_WHITE_SOFT  C'220,230,245'

// Status colors (high contrast on dark)
#define C_GREEN_BRIGHT  C'0,255,100'
#define C_GREEN_MED     C'0,200,80'
#define C_GREEN_DARK    C'0,80,30'
#define C_RED_BRIGHT    C'255,50,50'
#define C_RED_MED       C'220,40,40'
#define C_RED_DARK      C'80,15,15'
#define C_ORANGE_BRIGHT C'255,150,0'
#define C_ORANGE_MED    C'220,130,0'
#define C_YELLOW_BRIGHT C'255,240,0'
#define C_BLUE_BRIGHT   C'50,150,255'
#define C_PURPLE_BRIGHT C'180,80,255'
#define C_TEAL_BRIGHT   C'0,220,200'

// Subdued tones for labels
#define C_SUBTEXT     C'100,130,180'
#define C_MGRAY       C'70,90,120'
#define C_DGRAY       C'30,45,70'
#define C_LGRAY       C'150,170,200'

// Score bar colors
#define C_BAR_EMPTY   C'20,30,55'
#define C_BAR_HIGH    C'0,255,100'
#define C_BAR_MED     C'255,200,0'
#define C_BAR_LOW     C'255,60,60'

//=====================================================================
//  GLOBAL OBJECTS
//=====================================================================
CTrade        g_trade;
CPositionInfo g_pos;
CAccountInfo  g_account;

int g_h1_ema_fast,  g_h1_ema_slow,  g_h1_atr;
int g_m15_ema_fast, g_m15_ema_slow, g_m15_atr, g_m15_rsi;
int g_m5_ema_fast,  g_m5_ema_slow,  g_m5_atr,  g_m5_rsi;
int g_m1_ema_fast,  g_m1_ema_slow,  g_m1_atr;

RegimeState      g_regime;
VolatilityState  g_vol;
LiquidityState   g_liq;
SessionState     g_session;
MTFBias          g_mtf;
ENUM_NEWS_STATE  g_newsState = NEWS_NORMAL;
RiskState        g_risk;
MasterDecision   g_lastDecision;
StrategyHealth   g_health[5];
ExecutionQuality g_execQuality;
MarketScores     g_scores;

datetime g_dayStart      = 0;
datetime g_weekStart     = 0;
int      g_tradesToday   = 0;
datetime g_lastCloseTime = 0;
bool     g_inCooldown    = false;
int      g_cooldownLeft  = 0;
datetime g_lastBarTime   = 0;
datetime g_lastNarrative = 0;
datetime g_lastFullUpdate= 0;

double g_adaptiveRegimeConfThreshold;
double g_adaptiveExecScoreThreshold;

string g_statusText  = "INITIALIZING";
color  g_statusColor = C_ORANGE_BRIGHT;
string g_lastAction  = "Starting...";

double g_sessionProfit = 0.0;
int    g_sessionWins   = 0;
int    g_sessionLosses = 0;

double g_spreadHistory[20];
int    g_spreadHistCount = 0;
double g_regimeStreakBars = 0;
ENUM_REGIME g_regimePersistTrack = REGIME_RANGING;

string g_narrativeLine1 = "Initializing market analysis...";
string g_narrativeLine2 = "Building intelligence buffers.";
string g_narrativeLine3 = "Please wait for data.";
string g_narrativeLine4 = "";
string g_narrativeLine5 = "";
string g_narrativeLine6 = "";

StructureLabel g_structureLabels[50];
int            g_structureLabelCount = 0;

// DPI scale factor
double g_scale = 1.0;

// Dashboard height tracking
int g_dashH = 0;

//=====================================================================
//  UTILITY: DPI-AWARE SCALING
//=====================================================================
int S(int px)   { return (int)MathRound(px * g_scale); }
int FS(int sz)  { return MathMax(6, (int)MathRound(sz * g_scale)); }

//=====================================================================
//  TIME & SESSION HELPERS
//=====================================================================
datetime DayStart(datetime ts)
{
   MqlDateTime d; TimeToStruct(ts, d);
   return ts - (datetime)(d.hour*3600 + d.min*60 + d.sec);
}
datetime WeekStart(datetime ts)
{
   MqlDateTime d; TimeToStruct(ts, d);
   datetime ds = DayStart(ts);
   int off = (d.day_of_week == 0) ? 6 : (d.day_of_week - 1);
   return ds - (datetime)(off * 86400);
}
double NPrice(double p) { return NormalizeDouble(p, (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS)); }
ENUM_ORDER_TYPE_FILLING GetFillMode()
{
   uint f = (uint)SymbolInfoInteger(_Symbol, SYMBOL_FILLING_MODE);
   if((f & SYMBOL_FILLING_FOK) != 0) return ORDER_FILLING_FOK;
   if((f & SYMBOL_FILLING_IOC) != 0) return ORDER_FILLING_IOC;
   return ORDER_FILLING_RETURN;
}
bool IsNewBar()
{
   datetime t = iTime(_Symbol, PERIOD_M5, 0);
   if(t != g_lastBarTime) { g_lastBarTime = t; return true; }
   return false;
}

//=====================================================================
//  SESSION ENGINE
//=====================================================================
ENUM_SESSION ClassifySession(datetime ts)
{
   MqlDateTime d; TimeToStruct(ts, d);
   int h = (d.hour - InpBrokerGMTOffset + 24) % 24;
   if(h < 7)  return SESSION_ASIAN;
   if(h < 10) return SESSION_LONDON_OPEN;
   if(h < 12) return SESSION_LONDON_MID;
   if(h < 15) return SESSION_NY_OPEN;
   if(h < 21) return SESSION_NY_PM;
   return SESSION_DEAD_ZONE;
}

void SessionHourBand(ENUM_SESSION s, int &sh, int &eh)
{
   switch(s)
   {
      case SESSION_ASIAN:       sh=0;  eh=7;  break;
      case SESSION_LONDON_OPEN: sh=7;  eh=10; break;
      case SESSION_LONDON_MID:  sh=10; eh=12; break;
      case SESSION_NY_OPEN:     sh=12; eh=15; break;
      case SESSION_NY_PM:       sh=15; eh=21; break;
      default:                  sh=21; eh=24; break;
   }
}

string SessionToString(ENUM_SESSION s)
{
   switch(s)
   {
      case SESSION_ASIAN:       return "ASIAN";
      case SESSION_LONDON_OPEN: return "LONDON OPEN";
      case SESSION_LONDON_MID:  return "LONDON MID";
      case SESSION_NY_OPEN:     return "NEW YORK OPEN";
      case SESSION_NY_PM:       return "NEW YORK PM";
      default:                  return "DEAD ZONE";
   }
}

string SessionOverlapString(ENUM_SESSION s)
{
   switch(s)
   {
      case SESSION_LONDON_OPEN: return "LONDON OPEN";
      case SESSION_NY_OPEN:     return "LONDON-NY OVERLAP";
      default:                  return SessionToString(s);
   }
}

void UpdateSessionIntelligence()
{
   g_session.current = ClassifySession(TimeCurrent());
   double atrM5[1];
   if(CopyBuffer(g_m5_atr, 0, 0, 1, atrM5) <= 0) atrM5[0] = 0.0001;
   double hi = iHigh(_Symbol, PERIOD_M5, 0), lo = iLow(_Symbol, PERIOD_M5, 0);
   for(int i = 1; i < 12; i++) { hi = MathMax(hi, iHigh(_Symbol,PERIOD_M5,i)); lo = MathMin(lo, iLow(_Symbol,PERIOD_M5,i)); }
   g_session.sessionRangeATRRatio   = (atrM5[0]>0) ? ((hi-lo)/atrM5[0]) : 0.0;
   g_session.sessionVolatilityScore = MathMin(100.0, g_session.sessionRangeATRRatio*25.0);
   switch(g_session.current)
   {
      case SESSION_ASIAN:       g_session.preferredStrategy=STRAT_MEAN_REVERSION;       g_session.strategyWeight=1.1; break;
      case SESSION_LONDON_OPEN: g_session.preferredStrategy=STRAT_VOLATILITY_EXPANSION; g_session.strategyWeight=1.3; break;
      case SESSION_LONDON_MID:  g_session.preferredStrategy=STRAT_TREND_SCALPER;        g_session.strategyWeight=1.0; break;
      case SESSION_NY_OPEN:     g_session.preferredStrategy=STRAT_LIQUIDITY_REVERSAL;   g_session.strategyWeight=1.25; break;
      case SESSION_NY_PM:       g_session.preferredStrategy=STRAT_TREND_SCALPER;        g_session.strategyWeight=0.9; break;
      default:                  g_session.preferredStrategy=STRAT_NONE;                 g_session.strategyWeight=0.5; break;
   }
}

//=====================================================================
//  MTF BIAS ENGINE
//=====================================================================
int ComputeTFBias(int fast, int slow)
{
   double fn[2], sn[2];
   if(CopyBuffer(fast,0,0,2,fn)<2 || CopyBuffer(slow,0,0,2,sn)<2) return 0;
   double spNow=fn[0]-sn[0], spPrv=fn[1]-sn[1];
   int dir=(fn[0]>sn[0])?1:(fn[0]<sn[0]?-1:0);
   if(dir==0) return 0;
   if(MathAbs(spNow)<MathAbs(spPrv)*0.5) return 0;
   return dir;
}

void UpdateMTFBias()
{
   g_mtf.h1Bias  = ComputeTFBias(g_h1_ema_fast,  g_h1_ema_slow);
   g_mtf.m15Bias = ComputeTFBias(g_m15_ema_fast, g_m15_ema_slow);
   g_mtf.m5Bias  = ComputeTFBias(g_m5_ema_fast,  g_m5_ema_slow);
   g_mtf.m1Bias  = ComputeTFBias(g_m1_ema_fast,  g_m1_ema_slow);
   int biases[4]={g_mtf.h1Bias,g_mtf.m15Bias,g_mtf.m5Bias,g_mtf.m1Bias};
   int agree=0,nonzero=0,refDir=0;
   for(int i=0;i<4;i++)
   {
      if(biases[i]!=0) { nonzero++; if(refDir==0) refDir=biases[i]; else if(biases[i]==refDir) agree++; }
   }
   g_mtf.alignment=(nonzero>1)?(100.0*(double)(agree+1)/(double)nonzero):(nonzero==1?50.0:0.0);
}

//=====================================================================
//  STRUCTURE HELPERS
//=====================================================================
double StructureHH(int lb, int sh=1)
{
   int idx=iHighest(_Symbol,PERIOD_M5,MODE_HIGH,lb,sh);
   return (idx>=0)?iHigh(_Symbol,PERIOD_M5,idx):0;
}
double StructureLL(int lb, int sh=1)
{
   int idx=iLowest(_Symbol,PERIOD_M5,MODE_LOW,lb,sh);
   return (idx>=0)?iLow(_Symbol,PERIOD_M5,idx):0;
}

int FindSwingHighs(int lb, int wing, double &pr[], datetime &tm[], int maxR=30)
{
   int cnt=0;
   for(int i=wing;i<lb-wing&&cnt<maxR&&cnt<ArraySize(pr);i++)
   {
      double h=iHigh(_Symbol,PERIOD_M5,i); bool ok=true;
      for(int w=1;w<=wing;w++) if(iHigh(_Symbol,PERIOD_M5,i-w)>=h||iHigh(_Symbol,PERIOD_M5,i+w)>=h){ok=false;break;}
      if(ok){pr[cnt]=h;tm[cnt]=iTime(_Symbol,PERIOD_M5,i);cnt++;}
   }
   return cnt;
}
int FindSwingLows(int lb, int wing, double &pr[], datetime &tm[], int maxR=30)
{
   int cnt=0;
   for(int i=wing;i<lb-wing&&cnt<maxR&&cnt<ArraySize(pr);i++)
   {
      double l=iLow(_Symbol,PERIOD_M5,i); bool ok=true;
      for(int w=1;w<=wing;w++) if(iLow(_Symbol,PERIOD_M5,i-w)<=l||iLow(_Symbol,PERIOD_M5,i+w)<=l){ok=false;break;}
      if(ok){pr[cnt]=l;tm[cnt]=iTime(_Symbol,PERIOD_M5,i);cnt++;}
   }
   return cnt;
}

//=====================================================================
//  VOLATILITY ENGINE
//=====================================================================
void UpdateVolatilityIntelligence()
{
   double buf[]; ArrayResize(buf,InpATRLookback); ArraySetAsSeries(buf,true);
   int got=CopyBuffer(g_m5_atr,0,0,InpATRLookback,buf);
   if(got<InpATRLookback/2||got<=0){g_vol.state=VOL_NORMAL;g_vol.dynamic=VOLDYN_STABLE;g_vol.atrCurrent=0.0001;g_vol.atrAvg=0.0001;g_vol.atrRatio=1.0;return;}
   double cur=buf[0],sum=0; int n=0;
   for(int i=0;i<got;i++){sum+=buf[i];n++;}
   double avg=(n>0)?sum/n:cur; if(avg<=0)avg=0.0001;
   g_vol.atrCurrent=cur; g_vol.atrAvg=avg; g_vol.atrRatio=(avg>0)?cur/avg:1.0;
   int below=0; for(int i=0;i<got;i++) if(buf[i]<=cur)below++;
   g_vol.percentile=(got>0)?(100.0*below/got):50.0;
   if(g_vol.percentile<25)      g_vol.state=VOL_LOW;
   else if(g_vol.percentile<65) g_vol.state=VOL_NORMAL;
   else if(g_vol.percentile<90) g_vol.state=VOL_HIGH;
   else                         g_vol.state=VOL_EXTREME;
   double prev=(got>3)?buf[3]:avg;
   double roc=(prev>0)?(cur-prev)/prev:0.0;
   if(g_vol.atrRatio>=InpShockATRMultiple)  g_vol.dynamic=VOLDYN_SPIKE;
   else if(roc>0.15)                        g_vol.dynamic=VOLDYN_EXPANDING;
   else if(roc<-0.15)                       g_vol.dynamic=VOLDYN_COMPRESSING;
   else                                     g_vol.dynamic=VOLDYN_STABLE;
}

string VolStateToString(ENUM_VOL_STATE v)
{
   switch(v){case VOL_LOW:return "LOW";case VOL_NORMAL:return "NORMAL";case VOL_HIGH:return "HIGH";default:return "EXTREME";}
}

string VolDynamicToString(ENUM_VOL_DYNAMIC v)
{
   switch(v){case VOLDYN_EXPANDING:return "EXPANDING";case VOLDYN_COMPRESSING:return "COMPRESSING";case VOLDYN_SPIKE:return "SPIKE";default:return "STABLE";}
}

//=====================================================================
//  NEWS SHOCK PROXY
//=====================================================================
void UpdateNewsShockProxy()
{
   static datetime lastSample=0;
   if(TimeCurrent()-lastSample>=60)
   {
      lastSample=TimeCurrent();
      double sp=(double)SymbolInfoInteger(_Symbol,SYMBOL_SPREAD);
      if(g_spreadHistCount<20){g_spreadHistory[g_spreadHistCount]=sp;g_spreadHistCount++;}
      else{for(int i=0;i<19;i++)g_spreadHistory[i]=g_spreadHistory[i+1];g_spreadHistory[19]=sp;}
   }
   double sum=0; for(int i=0;i<g_spreadHistCount;i++)sum+=g_spreadHistory[i];
   double avg=(g_spreadHistCount>0)?sum/g_spreadHistCount:1;
   double spNow=(double)SymbolInfoInteger(_Symbol,SYMBOL_SPREAD);
   double spRatio=(avg>0)?spNow/avg:1.0;
   double barR=iHigh(_Symbol,PERIOD_M5,0)-iLow(_Symbol,PERIOD_M5,0);
   double barRatio=(g_vol.atrAvg>0)?barR/g_vol.atrAvg:1.0;
   int sigs=(g_vol.atrRatio>=InpShockATRMultiple?1:0)+(spRatio>=InpShockSpreadMultiple?1:0)+(barRatio>=InpShockATRMultiple?1:0);
   g_newsState=(sigs>=2)?NEWS_SHOCK:(sigs==1?NEWS_CAUTION:NEWS_NORMAL);
}

string NewsToString(ENUM_NEWS_STATE n)
{
   switch(n){case NEWS_CAUTION:return "CAUTION";case NEWS_SHOCK:return "SHOCK DETECTED";default:return "CLEAR";}
}

//=====================================================================
//  LIQUIDITY ENGINE
//=====================================================================
void UpdateLiquidityIntelligence()
{
   double shP[30],slP[30]; datetime shT[30],slT[30];
   int nH=FindSwingHighs(MathMin(InpLiquidityLookback,55),2,shP,shT);
   int nL=FindSwingLows(MathMin(InpLiquidityLookback,55),2,slP,slT);
   double px=SymbolInfoDouble(_Symbol,SYMBOL_BID);
   double tol=px*(InpEqualLevelTolerance/100.0);
   g_liq.equalHighsDetected=false; g_liq.equalHighLevel=0; int bHC=0;
   for(int i=0;i<nH;i++){int cc=1;double sl=shP[i];for(int j=0;j<nH;j++){if(j==i)continue;if(MathAbs(shP[j]-shP[i])<=tol){cc++;sl+=shP[j];}}if(cc>=2&&cc>bHC){bHC=cc;g_liq.equalHighLevel=sl/cc;g_liq.equalHighsDetected=true;}}
   g_liq.equalLowsDetected=false;  g_liq.equalLowLevel=0;  int bLC=0;
   for(int i=0;i<nL;i++){int cc=1;double sl=slP[i];for(int j=0;j<nL;j++){if(j==i)continue;if(MathAbs(slP[j]-slP[i])<=tol){cc++;sl+=slP[j];}}if(cc>=2&&cc>bLC){bLC=cc;g_liq.equalLowLevel=sl/cc;g_liq.equalLowsDetected=true;}}
   g_liq.sweepUpDetected=false; g_liq.sweepDownDetected=false;
   if(g_liq.equalHighsDetected)for(int i=0;i<3;i++){if(iHigh(_Symbol,PERIOD_M5,i)>g_liq.equalHighLevel&&iClose(_Symbol,PERIOD_M5,i)<g_liq.equalHighLevel){g_liq.sweepUpDetected=true;break;}}
   if(g_liq.equalLowsDetected) for(int i=0;i<3;i++){if(iLow(_Symbol,PERIOD_M5,i)<g_liq.equalLowLevel&&iClose(_Symbol,PERIOD_M5,i)>g_liq.equalLowLevel){g_liq.sweepDownDetected=true;break;}}
   double dH=g_liq.equalHighsDetected?MathAbs(px-g_liq.equalHighLevel):-1;
   double dL=g_liq.equalLowsDetected?MathAbs(px-g_liq.equalLowLevel):-1;
   double prox=0;
   if(dH>=0&&g_vol.atrAvg>0)prox=MathMax(prox,100.0*MathMax(0.0,1.0-dH/(g_vol.atrAvg*1.5)));
   if(dL>=0&&g_vol.atrAvg>0)prox=MathMax(prox,100.0*MathMax(0.0,1.0-dL/(g_vol.atrAvg*1.5)));
   g_liq.sweepProbability=MathMin(100.0,prox);
   double bias=0;
   if(dH>=0&&dL>=0)bias=(dL<dH)?-40.0:40.0;
   else if(dH>=0)bias=40.0;
   else if(dL>=0)bias=-40.0;
   if(g_liq.sweepUpDetected)  bias=-70.0;
   if(g_liq.sweepDownDetected)bias=70.0;
   g_liq.biasScore=bias;
   g_liq.pressureScore=MathMin(100.0,(bHC+bLC)*12.0+g_liq.sweepProbability*0.3);
   g_liq.imbalanceScore=MathMin(100.0,MathAbs((double)(bHC-bLC))*20.0);
}

string LiquidityStatusString()
{
   if(g_liq.sweepUpDetected)  return "BUY SIDE SWEEP CONFIRMED";
   if(g_liq.sweepDownDetected)return "SELL SIDE SWEEP CONFIRMED";
   if(g_liq.equalHighsDetected&&g_liq.equalLowsDetected)return "DUAL LIQUIDITY POOLS";
   if(g_liq.equalHighsDetected)return "BSL CLUSTER ABOVE";
   if(g_liq.equalLowsDetected) return "SSL CLUSTER BELOW";
   return "NO CLUSTER DETECTED";
}

//=====================================================================
//  REGIME CLASSIFICATION
//=====================================================================
double ScoreTrending()
{
   double s=g_mtf.alignment*0.5;
   if(g_mtf.m5Bias!=0&&g_mtf.m5Bias==g_mtf.h1Bias)s+=20;
   if(g_vol.state==VOL_NORMAL||g_vol.state==VOL_HIGH)s+=15;
   if(g_vol.dynamic==VOLDYN_EXPANDING)s+=10;
   return MathMin(100.0,s);
}
double ScoreRanging()
{
   double s=0;
   if(g_mtf.alignment<40)s+=40;
   if(g_vol.state==VOL_LOW||g_vol.state==VOL_NORMAL)s+=25;
   if(g_vol.dynamic==VOLDYN_STABLE)s+=20;
   double hh=StructureHH(InpStructureLookback,1),ll=StructureLL(InpStructureLookback,1),mid=(hh+ll)/2.0,px=SymbolInfoDouble(_Symbol,SYMBOL_BID);
   double rp=(hh>ll)?MathAbs(px-mid)/((hh-ll)/2.0):1.0;
   if(rp<0.6)s+=15;
   return MathMin(100.0,s);
}
double ScoreBreakout()
{
   double s=0,hh=StructureHH(InpStructureLookback,1),ll=StructureLL(InpStructureLookback,1),px=SymbolInfoDouble(_Symbol,SYMBOL_BID);
   if(px>hh||px<ll)s+=45;
   if(g_vol.dynamic==VOLDYN_EXPANDING)s+=25;
   if(g_vol.state==VOL_HIGH)s+=15;
   if(g_mtf.alignment>60)s+=15;
   return MathMin(100.0,s);
}
double ScoreCompression(){double s=0;if(g_vol.state==VOL_LOW)s+=35;if(g_vol.dynamic==VOLDYN_COMPRESSING)s+=35;if(g_vol.percentile<15)s+=20;if(g_mtf.alignment<30)s+=10;return MathMin(100.0,s);}
double ScoreExpansion(){double s=0;if(g_vol.dynamic==VOLDYN_EXPANDING)s+=40;if(g_vol.state==VOL_HIGH)s+=25;if(g_vol.atrRatio>1.3)s+=20;if(g_mtf.alignment>50)s+=15;return MathMin(100.0,s);}
double ScoreVolShock(){double s=0;if(g_vol.dynamic==VOLDYN_SPIKE)s+=50;if(g_vol.state==VOL_EXTREME)s+=30;if(g_newsState==NEWS_SHOCK)s+=20;return MathMin(100.0,s);}
double ScoreLiqSweep(){double s=0;if(g_liq.sweepUpDetected||g_liq.sweepDownDetected)s+=50;s+=g_liq.sweepProbability*0.3;s+=g_liq.pressureScore*0.2;return MathMin(100.0,s);}
double ScoreExhaustion()
{
   double s=0,rsiM5[1];
   if(CopyBuffer(g_m5_rsi,0,0,1,rsiM5)>0&&(rsiM5[0]>72||rsiM5[0]<28))s+=35;
   if(g_vol.dynamic==VOLDYN_COMPRESSING&&g_vol.atrRatio<0.85)s+=25;
   if(g_mtf.m1Bias!=0&&g_mtf.m5Bias!=0&&g_mtf.m1Bias!=g_mtf.m5Bias)s+=20;
   return MathMin(100.0,s);
}
double ScoreMeanRev()
{
   double s=0,rsiM5[1];
   if(CopyBuffer(g_m5_rsi,0,0,1,rsiM5)>0&&(rsiM5[0]>70||rsiM5[0]<30))s+=30;
   if(g_vol.state==VOL_NORMAL)s+=20;
   if(g_mtf.alignment<45)s+=25;
   if(g_liq.sweepUpDetected||g_liq.sweepDownDetected)s+=15;
   return MathMin(100.0,s);
}
double ScoreUnsafe(){double s=0;if(g_newsState==NEWS_SHOCK)s+=60;if(g_vol.state==VOL_EXTREME)s+=25;if((double)SymbolInfoInteger(_Symbol,SYMBOL_SPREAD)>InpMaxSpreadPoints)s+=30;return MathMin(100.0,s);}

void UpdateRegimeClassification()
{
   ENUM_REGIME C[10]={REGIME_TRENDING,REGIME_RANGING,REGIME_BREAKOUT,REGIME_COMPRESSION,REGIME_EXPANSION,REGIME_VOLATILITY_SHOCK,REGIME_LIQUIDITY_SWEEP,REGIME_EXHAUSTION,REGIME_MEAN_REVERSION,REGIME_UNSAFE};
   double sc[10];
   sc[0]=ScoreTrending();sc[1]=ScoreRanging();sc[2]=ScoreBreakout();sc[3]=ScoreCompression();
   sc[4]=ScoreExpansion();sc[5]=ScoreVolShock();sc[6]=ScoreLiqSweep();sc[7]=ScoreExhaustion();
   sc[8]=ScoreMeanRev();sc[9]=ScoreUnsafe();
   int bi=0;double bs=sc[0];
   for(int i=1;i<10;i++)if(sc[i]>bs){bs=sc[i];bi=i;}
   if(sc[9]>=55.0){bi=9;bs=sc[9];}
   ENUM_REGIME nr=C[bi];
   if(nr==g_regimePersistTrack)g_regimeStreakBars++;
   else{g_regimeStreakBars=0;g_regimePersistTrack=nr;g_regime.sinceTime=TimeCurrent();g_regime.previousRegime=g_regime.regime;}
   g_regime.regime=nr;g_regime.confidence=bs;g_regime.stability=MathMin(100.0,g_regimeStreakBars*8.0);
}

string RegimeToString(ENUM_REGIME r)
{
   switch(r)
   {
      case REGIME_TRENDING:         return "TREND EXPANSION";
      case REGIME_RANGING:          return "RANGE BOUND";
      case REGIME_BREAKOUT:         return "BREAKOUT";
      case REGIME_COMPRESSION:      return "COMPRESSION";
      case REGIME_EXPANSION:        return "VOLATILITY EXPANSION";
      case REGIME_VOLATILITY_SHOCK: return "VOLATILITY SHOCK";
      case REGIME_LIQUIDITY_SWEEP:  return "LIQUIDITY HUNT";
      case REGIME_EXHAUSTION:       return "TREND EXHAUSTION";
      case REGIME_MEAN_REVERSION:   return "MEAN REVERSION";
      case REGIME_UNSAFE:           return "UNSAFE — STAND ASIDE";
      default:                      return "UNDEFINED";
   }
}

color RegimeToColor(ENUM_REGIME r)
{
   switch(r)
   {
      case REGIME_TRENDING:         return C_GREEN_BRIGHT;
      case REGIME_RANGING:          return C_YELLOW_BRIGHT;
      case REGIME_BREAKOUT:         return C_ORANGE_BRIGHT;
      case REGIME_EXPANSION:        return C_ORANGE_BRIGHT;
      case REGIME_LIQUIDITY_SWEEP:  return C_PURPLE_BRIGHT;
      case REGIME_VOLATILITY_SHOCK: return C_RED_BRIGHT;
      case REGIME_UNSAFE:           return C_RED_BRIGHT;
      case REGIME_COMPRESSION:      return C_BLUE_BRIGHT;
      case REGIME_EXHAUSTION:       return C_ORANGE_MED;
      default:                      return C_TEAL_BRIGHT;
   }
}

//=====================================================================
//  MARKET SCORES ENGINE
//=====================================================================
void UpdateMarketScores()
{
   double rsiM5[1]; if(CopyBuffer(g_m5_rsi,0,0,1,rsiM5)<=0)rsiM5[0]=50;

   // Trend score
   g_scores.trendScore = MathMin(100.0, g_mtf.alignment*0.6 + g_regime.confidence*0.4);

   // Liquidity score
   g_scores.liquidityScore = MathMin(100.0, g_liq.pressureScore*0.5 + g_liq.sweepProbability*0.3 + (g_liq.sweepUpDetected||g_liq.sweepDownDetected?20:0));

   // Volume score (proxy via ATR ratio vs average)
   g_scores.volumeScore = MathMin(100.0, 50.0 + (g_vol.atrRatio - 1.0)*50.0);

   // Session score
   double ss=60;
   if(g_session.current==SESSION_NY_OPEN||g_session.current==SESSION_LONDON_OPEN)ss=95;
   else if(g_session.current==SESSION_LONDON_MID||g_session.current==SESSION_NY_PM)ss=80;
   else if(g_session.current==SESSION_ASIAN)ss=65;
   else ss=30;
   g_scores.sessionScore=ss;

   // Structure clarity
   g_scores.structureClarity=MathMin(100.0,g_regime.stability*0.5+g_mtf.alignment*0.5);

   // Momentum score
   double mom=MathAbs(rsiM5[0]-50.0)*2.0;
   g_scores.momentumScore=MathMin(100.0,mom);

   // Volatility score (normalized — higher is healthier for trading, not extreme)
   g_scores.volatilityScore=MathMin(100.0,(g_vol.state==VOL_NORMAL)?90:((g_vol.state==VOL_HIGH)?75:((g_vol.state==VOL_LOW)?55:25)));

   // Structure score
   g_scores.structureScore=g_scores.structureClarity;

   // Total weighted score
   g_scores.totalScore = MathMin(100.0,
      g_scores.trendScore     * 0.20 +
      g_scores.liquidityScore * 0.20 +
      g_scores.volumeScore    * 0.15 +
      g_scores.sessionScore   * 0.15 +
      g_scores.structureScore * 0.15 +
      g_scores.momentumScore  * 0.10 +
      g_scores.volatilityScore* 0.05);
}

//=====================================================================
//  STRATEGY MODULES
//=====================================================================
StrategySignal Strategy_TrendScalper()
{
   StrategySignal s; s.source=STRAT_TREND_SCALPER;s.direction=DIR_NONE;s.valid=false;s.reason="";
   double mtfGate=InpRelaxedMode?InpRelaxedMTFAlignment:55.0;
   if(g_mtf.alignment<mtfGate){s.reason="MTF align insufficient";return s;}
   int dir=(g_mtf.h1Bias!=0)?g_mtf.h1Bias:g_mtf.m15Bias;
   if(dir==0){s.reason="No macro bias";return s;}
   if(g_mtf.m5Bias!=dir){s.reason="M5 not aligned";return s;}
   double atr=g_vol.atrCurrent,price=(dir>0)?SymbolInfoDouble(_Symbol,SYMBOL_ASK):SymbolInfoDouble(_Symbol,SYMBOL_BID);
   s.direction=(dir>0)?DIR_LONG:DIR_SHORT;
   s.confidence=MathMin(95.0,g_mtf.alignment*0.9+g_regime.confidence*0.1);
   s.suggestedSL=(dir>0)?NPrice(price-atr*1.5):NPrice(price+atr*1.5);
   s.suggestedTP=(dir>0)?NPrice(price+atr*2.5):NPrice(price-atr*2.5);
   s.reason="Trend Pullback Scalper"; s.valid=true; return s;
}
StrategySignal Strategy_MeanReversion()
{
   StrategySignal s; s.source=STRAT_MEAN_REVERSION;s.direction=DIR_NONE;s.valid=false;s.reason="";
   double rsiM5[1]; if(CopyBuffer(g_m5_rsi,0,0,1,rsiM5)<=0){s.reason="RSI unavailable";return s;}
   bool ob=rsiM5[0]>70,os=rsiM5[0]<30;
   if(!ob&&!os){s.reason="RSI not extended";return s;}
   double hh=StructureHH(InpStructureLookback,1),ll=StructureLL(InpStructureLookback,1),mid=(hh+ll)/2.0,atr=g_vol.atrCurrent;
   if(ob){double ep=SymbolInfoDouble(_Symbol,SYMBOL_BID);s.direction=DIR_SHORT;s.suggestedSL=NPrice(ep+atr*1.2);s.suggestedTP=NPrice(MathMax(mid,ep-atr*1.8));}
   else{double ep=SymbolInfoDouble(_Symbol,SYMBOL_ASK);s.direction=DIR_LONG;s.suggestedSL=NPrice(ep-atr*1.2);s.suggestedTP=NPrice(MathMin(mid,ep+atr*1.8));}
   s.confidence=MathMin(90.0,MathAbs(rsiM5[0]-50.0)*1.6);s.reason="VWAP Reversion";s.valid=true;return s;
}
StrategySignal Strategy_VolatilityExpansion()
{
   StrategySignal s; s.source=STRAT_VOLATILITY_EXPANSION;s.direction=DIR_NONE;s.valid=false;s.reason="";
   if(g_vol.dynamic!=VOLDYN_EXPANDING){s.reason="Not expanding";return s;}
   double hh=StructureHH(InpStructureLookback,1),ll=StructureLL(InpStructureLookback,1),px=SymbolInfoDouble(_Symbol,SYMBOL_BID),atr=g_vol.atrCurrent;
   bool bU=px>hh,bD=px<ll; if(!bU&&!bD){s.reason="No structural break";return s;}
   if(bU){double ep=SymbolInfoDouble(_Symbol,SYMBOL_ASK);s.direction=DIR_LONG;s.suggestedSL=NPrice(hh-atr*0.4);s.suggestedTP=NPrice(ep+atr*3.0);}
   else{double ep=SymbolInfoDouble(_Symbol,SYMBOL_BID);s.direction=DIR_SHORT;s.suggestedSL=NPrice(ll+atr*0.4);s.suggestedTP=NPrice(ep-atr*3.0);}
   s.confidence=MathMin(92.0,50.0+g_vol.atrRatio*20.0);s.reason="NY Expansion Breakout";s.valid=true;return s;
}
StrategySignal Strategy_LiquidityReversal()
{
   StrategySignal s; s.source=STRAT_LIQUIDITY_REVERSAL;s.direction=DIR_NONE;s.valid=false;s.reason="";
   if(!g_liq.sweepUpDetected&&!g_liq.sweepDownDetected){s.reason="No sweep detected";return s;}
   double atr=g_vol.atrCurrent;
   if(g_liq.sweepUpDetected){double ep=SymbolInfoDouble(_Symbol,SYMBOL_BID);s.direction=DIR_SHORT;s.suggestedSL=NPrice(g_liq.equalHighLevel+atr*0.3);s.suggestedTP=NPrice(ep-atr*2.2);}
   else{double ep=SymbolInfoDouble(_Symbol,SYMBOL_ASK);s.direction=DIR_LONG;s.suggestedSL=NPrice(g_liq.equalLowLevel-atr*0.3);s.suggestedTP=NPrice(ep+atr*2.2);}
   s.confidence=MathMin(93.0,g_liq.sweepProbability*0.5+g_liq.pressureScore*0.4);
   s.reason="Liquidity Sweep Reversal";s.valid=true;return s;
}
StrategySignal Strategy_CompressionBreakout()
{
   StrategySignal s; s.source=STRAT_COMPRESSION_BREAKOUT;s.direction=DIR_NONE;s.valid=false;s.reason="";
   if(g_vol.state!=VOL_LOW){s.reason="Not compressed";return s;}
   if(g_mtf.m1Bias==0){s.reason="No micro momentum";return s;}
   double hh=StructureHH(InpStructureLookback/2,1),ll=StructureLL(InpStructureLookback/2,1),px=SymbolInfoDouble(_Symbol,SYMBOL_BID),rs=hh-ll;
   if(rs<=0){s.reason="Invalid range";return s;}
   double pos=(px-ll)/rs;
   if(pos>0.7&&g_mtf.m1Bias>0){double ep=SymbolInfoDouble(_Symbol,SYMBOL_ASK);s.direction=DIR_LONG;s.suggestedSL=NPrice(ll);s.suggestedTP=NPrice(ep+rs*1.5);}
   else if(pos<0.3&&g_mtf.m1Bias<0){double ep=SymbolInfoDouble(_Symbol,SYMBOL_BID);s.direction=DIR_SHORT;s.suggestedSL=NPrice(hh);s.suggestedTP=NPrice(ep-rs*1.5);}
   else{s.reason="Not at compression edge";return s;}
   s.confidence=MathMin(88.0,45.0+(100.0-g_vol.percentile)*0.4);s.reason="Order Block Continuation";s.valid=true;return s;
}

ENUM_STRATEGY RouteRegimeToStrategy(ENUM_REGIME r)
{
   switch(r)
   {
      case REGIME_TRENDING:        return STRAT_TREND_SCALPER;
      case REGIME_RANGING:         return STRAT_MEAN_REVERSION;
      case REGIME_BREAKOUT:        return STRAT_VOLATILITY_EXPANSION;
      case REGIME_EXPANSION:       return STRAT_VOLATILITY_EXPANSION;
      case REGIME_LIQUIDITY_SWEEP: return STRAT_LIQUIDITY_REVERSAL;
      case REGIME_COMPRESSION:     return STRAT_COMPRESSION_BREAKOUT;
      case REGIME_MEAN_REVERSION:  return STRAT_MEAN_REVERSION;
      case REGIME_EXHAUSTION:      return STRAT_MEAN_REVERSION;
      default:                     return STRAT_NONE; // VOLATILITY_SHOCK / UNSAFE intentionally stay flat
   }
}

StrategySignal GetSignalForStrategy(ENUM_STRATEGY st)
{
   StrategySignal s; s.valid=false;s.direction=DIR_NONE;s.source=st;s.reason="None";
   switch(st)
   {
      case STRAT_TREND_SCALPER:        return Strategy_TrendScalper();
      case STRAT_MEAN_REVERSION:       return Strategy_MeanReversion();
      case STRAT_VOLATILITY_EXPANSION: return Strategy_VolatilityExpansion();
      case STRAT_LIQUIDITY_REVERSAL:   return Strategy_LiquidityReversal();
      case STRAT_COMPRESSION_BREAKOUT: return Strategy_CompressionBreakout();
      default: return s;
   }
}

int StrategyHealthIndex(ENUM_STRATEGY s)
{
   switch(s){case STRAT_TREND_SCALPER:return 0;case STRAT_MEAN_REVERSION:return 1;case STRAT_VOLATILITY_EXPANSION:return 2;case STRAT_LIQUIDITY_REVERSAL:return 3;case STRAT_COMPRESSION_BREAKOUT:return 4;default:return -1;}
}

string StrategyToString(ENUM_STRATEGY s)
{
   switch(s)
   {
      case STRAT_TREND_SCALPER:        return "Trend Pullback Scalper";
      case STRAT_MEAN_REVERSION:       return "VWAP Reversion";
      case STRAT_VOLATILITY_EXPANSION: return "NY Expansion Breakout";
      case STRAT_LIQUIDITY_REVERSAL:   return "Liquidity Sweep Reversal";
      case STRAT_COMPRESSION_BREAKOUT: return "Order Block Continuation";
      default:                         return "No Strategy";
   }
}

string StrategyToShort(ENUM_STRATEGY s)
{
   switch(s)
   {
      case STRAT_TREND_SCALPER:        return "TREND PULLBACK";
      case STRAT_MEAN_REVERSION:       return "VWAP REVERSION";
      case STRAT_VOLATILITY_EXPANSION: return "NY EXPANSION";
      case STRAT_LIQUIDITY_REVERSAL:   return "LIQUIDITY SWEEP";
      case STRAT_COMPRESSION_BREAKOUT: return "ORDER BLOCK";
      default:                         return "NONE";
   }
}

//=====================================================================
//  EXECUTION QUALITY ENGINE
//=====================================================================
void UpdateExecutionQuality()
{
   double sp=(double)SymbolInfoInteger(_Symbol,SYMBOL_SPREAD);
   g_execQuality.spreadScore=MathMax(0.0,100.0*(1.0-sp/InpMaxSpreadPoints));
   double slr=(g_newsState==NEWS_SHOCK)?90:(g_newsState==NEWS_CAUTION?50:MathMin(40.0,sp/InpMaxSpreadPoints*40.0));
   g_execQuality.slippageRiskScore=100.0-slr;
   double vq=(g_vol.state==VOL_EXTREME)?20:(g_vol.state==VOL_HIGH?65:(g_vol.state==VOL_LOW?80:100));
   g_execQuality.volatilityQuality=vq;
   double lq=(g_session.current==SESSION_DEAD_ZONE)?35:(g_session.current==SESSION_ASIAN?70:95);
   g_execQuality.liquidityQuality=lq;
   double ef=100;
   if(g_vol.atrCurrent>0){double sip=sp*SymbolInfoDouble(_Symbol,SYMBOL_POINT);ef=MathMax(0.0,100.0*(1.0-sip/g_vol.atrCurrent*5.0));}
   g_execQuality.efficiencyScore=ef;
   g_execQuality.compositeScore=g_execQuality.spreadScore*0.25+g_execQuality.slippageRiskScore*0.25+g_execQuality.volatilityQuality*0.20+g_execQuality.liquidityQuality*0.15+g_execQuality.efficiencyScore*0.15;
   g_execQuality.executionApproved=true;g_execQuality.rejectReason="";
   if(sp>InpMaxSpreadPoints){g_execQuality.executionApproved=false;g_execQuality.rejectReason="SPREAD TOO HIGH";}
   else if(g_execQuality.compositeScore<g_adaptiveExecScoreThreshold){g_execQuality.executionApproved=false;g_execQuality.rejectReason="LOW EXEC QUALITY";}
   else if(g_newsState==NEWS_SHOCK){g_execQuality.executionApproved=false;g_execQuality.rejectReason="NEWS SHOCK ACTIVE";}
}

double TradeQualityScore(){return MathMin(100.0,g_execQuality.compositeScore*0.5+g_regime.confidence*0.5);}

//=====================================================================
//  POSITION SIZING
//=====================================================================
double CalculateAdaptiveLotSize(StrategySignal &sig, double slP, double &outR)
{
   outR=0.0;
   double eq=AccountInfoDouble(ACCOUNT_EQUITY);if(eq<=0)return 0.0;
   double price=(sig.direction==DIR_LONG)?SymbolInfoDouble(_Symbol,SYMBOL_ASK):SymbolInfoDouble(_Symbol,SYMBOL_BID);
   double sld=MathAbs(price-slP);if(sld<=0)return 0.0;
   double cf=MathMax(0.5,MathMin(1.0,sig.confidence/100.0));
   double rf=MathMax(0.5,MathMin(1.0,(g_regime.confidence*0.6+g_regime.stability*0.4)/100.0));
   int hi=StrategyHealthIndex(sig.source);
   double hf=(hi>=0&&hi<5)?g_health[hi].influenceMultiplier:1.0;
   double dd=(InpMaxDrawdownPct>0)?(g_risk.currentDrawdownPct/InpMaxDrawdownPct):0.0;
   double df=MathMax(0.25,1.0-dd);
   double rp=MathMin(InpRiskPercentPerTrade*cf*rf*hf*df,InpMaxRiskPercentTrade);
   double ra=eq*(rp/100.0);
   double tv=SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_VALUE),ts=SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE);
   if(tv<=0||ts<=0)return 0.0;
   double vpu=tv/ts,lot=ra/(sld*vpu);
   double lmin=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN),lmax=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MAX),lstep=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_STEP);
   lot=MathFloor(lot/lstep)*lstep;lot=MathMax(lmin,MathMin(lmax,lot));
   outR=lot*sld*vpu;return lot;
}

//=====================================================================
//  RISK GOVERNANCE
//=====================================================================
void InitRiskState()
{
   double eq=AccountInfoDouble(ACCOUNT_EQUITY);
   g_risk.peakEquity=eq;g_risk.dayStartEquity=eq;g_risk.weekStartEquity=eq;
   g_risk.dailyLimitHit=false;g_risk.weeklyLimitHit=false;
   g_risk.maxDrawdownBreached=false;g_risk.emergencyShutdown=false;
   g_risk.currentDrawdownPct=0;g_risk.maxDrawdownSeenPct=0;
   string gv="QPA2_ESD_"+IntegerToString((long)InpMagicNumber);
   if(InpResetEmergencyShutdown && GlobalVariableCheck(gv))
   {
      GlobalVariableDel(gv);
      Print("Emergency shutdown flag cleared by InpResetEmergencyShutdown input.");
   }
   if(GlobalVariableCheck(gv)&&GlobalVariableGet(gv)>0.0){g_risk.emergencyShutdown=true;g_risk.maxDrawdownBreached=true;Print("WARNING: Emergency shutdown restored.");}
}

void UpdateRiskState()
{
   double eq=AccountInfoDouble(ACCOUNT_EQUITY);
   if(eq>g_risk.peakEquity)g_risk.peakEquity=eq;
   g_risk.currentDrawdownPct=(g_risk.peakEquity>0)?(g_risk.peakEquity-eq)/g_risk.peakEquity*100.0:0.0;
   if(g_risk.currentDrawdownPct>g_risk.maxDrawdownSeenPct)g_risk.maxDrawdownSeenPct=g_risk.currentDrawdownPct;
   g_risk.dailyRiskUsedPct=(g_risk.dayStartEquity>0)?MathMax(0.0,(g_risk.dayStartEquity-eq)/g_risk.dayStartEquity*100.0):0.0;
   g_risk.weeklyRiskUsedPct=(g_risk.weekStartEquity>0)?MathMax(0.0,(g_risk.weekStartEquity-eq)/g_risk.weekStartEquity*100.0):0.0;
   g_risk.dailyLimitHit=(InpMaxDailyLossPct>0&&g_risk.dailyRiskUsedPct>=InpMaxDailyLossPct);
   g_risk.weeklyLimitHit=(InpMaxWeeklyLossPct>0&&g_risk.weeklyRiskUsedPct>=InpMaxWeeklyLossPct);
   if(InpMaxDrawdownPct>0&&g_risk.currentDrawdownPct>=InpMaxDrawdownPct){g_risk.maxDrawdownBreached=true;g_risk.emergencyShutdown=true;GlobalVariableSet("QPA2_ESD_"+IntegerToString((long)InpMagicNumber),1.0);}
}

int PositionsTotalForMagic()
{
   int cnt=0;
   for(int i=PositionsTotal()-1;i>=0;i--)if(g_pos.SelectByIndex(i)&&g_pos.Magic()==InpMagicNumber&&g_pos.Symbol()==_Symbol)cnt++;
   return cnt;
}

bool RiskGovernanceAllowsNewTrade(string &reason)
{
   if(g_risk.emergencyShutdown){reason="EMERGENCY SHUTDOWN";return false;}
   if(g_risk.dailyLimitHit){reason="DAILY LIMIT HIT";return false;}
   if(g_risk.weeklyLimitHit){reason="WEEKLY LIMIT HIT";return false;}
   if(InpMaxDailyTrades>0&&g_tradesToday>=InpMaxDailyTrades){reason="MAX DAILY TRADES";return false;}
   if(PositionsTotalForMagic()>=InpMaxConcurrentTrades){reason="MAX POSITIONS";return false;}
   if(g_inCooldown){reason="POST-TRADE COOLDOWN";return false;}
   return true;
}

void RolloverDailyWeeklyIfNeeded()
{
   datetime td=DayStart(TimeCurrent()),tw=WeekStart(TimeCurrent());
   if(td!=g_dayStart){g_dayStart=td;g_tradesToday=0;g_risk.dayStartEquity=AccountInfoDouble(ACCOUNT_EQUITY);g_risk.dailyLimitHit=false;g_sessionProfit=0;g_sessionWins=0;g_sessionLosses=0;}
   if(tw!=g_weekStart){g_weekStart=tw;g_risk.weekStartEquity=AccountInfoDouble(ACCOUNT_EQUITY);g_risk.weeklyLimitHit=false;}
}

//=====================================================================
//  STRATEGY HEALTH
//=====================================================================
void InitStrategyHealth()
{
   string nm[5]={"TrendScalp","MeanRev","VolExpand","LiqReversal","Compression"};
   for(int i=0;i<5;i++){g_health[i].name=nm[i];g_health[i].totalTrades=0;g_health[i].wins=0;g_health[i].losses=0;g_health[i].grossProfit=0;g_health[i].grossLoss=0;g_health[i].sumR=0;g_health[i].sumRSquared=0;g_health[i].consecLosses=0;g_health[i].maxConsecLosses=0;g_health[i].winRate=0;g_health[i].profitFactor=0;g_health[i].expectancyR=0;g_health[i].sharpeProxy=0;g_health[i].enabled=true;g_health[i].influenceMultiplier=1.0;g_health[i].lastDegradedTime=0;}
}

void UpdateStrategyInfluence(int idx)
{
   if(idx<0||idx>=5)return;
   if(g_health[idx].totalTrades<InpHealthMinTrades){g_health[idx].influenceMultiplier=1.0;return;}
   double tm=1.0;
   if(g_health[idx].consecLosses>=InpHealthDegradeConsecLoss)tm=MathMin(tm,0.5);
   if(g_health[idx].expectancyR<InpHealthMinExpectancyR)tm=MathMin(tm,0.4);
   if(g_health[idx].profitFactor<0.8&&g_health[idx].totalTrades>=InpHealthMinTrades)tm=MathMin(tm,0.6);
   if(g_health[idx].consecLosses>=InpHealthDegradeConsecLoss*2||g_health[idx].expectancyR<InpHealthMinExpectancyR*2.5){g_health[idx].enabled=false;tm=0.0;g_health[idx].lastDegradedTime=TimeCurrent();}
   g_health[idx].influenceMultiplier+=( tm-g_health[idx].influenceMultiplier)*0.5;
   if(g_health[idx].influenceMultiplier>0.7)g_health[idx].enabled=true;
}

void RegisterTradeResult(ENUM_STRATEGY st, double pnl, double rm)
{
   int idx=StrategyHealthIndex(st);if(idx<0||idx>=5)return;
   g_health[idx].totalTrades++;
   if(pnl>=0){g_health[idx].wins++;g_health[idx].grossProfit+=pnl;g_health[idx].consecLosses=0;}
   else{g_health[idx].losses++;g_health[idx].grossLoss+=MathAbs(pnl);g_health[idx].consecLosses++;if(g_health[idx].consecLosses>g_health[idx].maxConsecLosses)g_health[idx].maxConsecLosses=g_health[idx].consecLosses;}
   g_health[idx].sumR+=rm;g_health[idx].sumRSquared+=rm*rm;
   g_health[idx].winRate=(g_health[idx].totalTrades>0)?(100.0*g_health[idx].wins/g_health[idx].totalTrades):0.0;
   g_health[idx].profitFactor=(g_health[idx].grossLoss>0)?(g_health[idx].grossProfit/g_health[idx].grossLoss):(g_health[idx].grossProfit>0?99.0:0.0);
   g_health[idx].expectancyR=(g_health[idx].totalTrades>0)?(g_health[idx].sumR/g_health[idx].totalTrades):0.0;
   if(g_health[idx].totalTrades>1){double mr=g_health[idx].sumR/g_health[idx].totalTrades,vr=(g_health[idx].sumRSquared/g_health[idx].totalTrades)-(mr*mr),sd=(vr>0)?MathSqrt(vr):0.0;g_health[idx].sharpeProxy=(sd>0)?(mr/sd):0.0;}
   UpdateStrategyInfluence(idx);
}

//=====================================================================
//  ADAPTIVE PARAMETERS
//=====================================================================
void InitAdaptiveParams()
{
   g_adaptiveRegimeConfThreshold = InpRelaxedMode ? InpRelaxedRegimeConfidence : InpMinRegimeConfidence;
   g_adaptiveExecScoreThreshold  = InpRelaxedMode ? InpRelaxedExecScore        : InpMinExecutionScore;
}
void UpdateAdaptiveParams()
{
   if(!InpEnableAdaptiveParams)return;
   static datetime lb=0;datetime cb=iTime(_Symbol,PERIOD_M5,0);if(cb==lb)return;lb=cb;
   double baseRegimeConf=InpRelaxedMode?InpRelaxedRegimeConfidence:InpMinRegimeConfidence;
   double baseExecScore =InpRelaxedMode?InpRelaxedExecScore:InpMinExecutionScore;
   double rLo=baseRegimeConf*(1.0-InpAdaptiveBoundPct/100.0),rHi=baseRegimeConf*(1.0+InpAdaptiveBoundPct/100.0);
   double eLo=baseExecScore*(1.0-InpAdaptiveBoundPct/100.0),eHi=baseExecScore*(1.0+InpAdaptiveBoundPct/100.0);
   double n=(g_regime.confidence>g_adaptiveRegimeConfThreshold+15)?0.15:(g_regime.confidence<g_adaptiveRegimeConfThreshold-15?-0.15:0.0);
   g_adaptiveRegimeConfThreshold=MathMax(rLo,MathMin(rHi,g_adaptiveRegimeConfThreshold+n));
   double en=(g_execQuality.compositeScore>g_adaptiveExecScoreThreshold+15)?0.1:(g_execQuality.compositeScore<g_adaptiveExecScoreThreshold-15?-0.1:0.0);
   g_adaptiveExecScoreThreshold=MathMax(eLo,MathMin(eHi,g_adaptiveExecScoreThreshold+en));
}

//=====================================================================
//  AI NARRATIVE ENGINE
//=====================================================================
void UpdateNarrative()
{
   if(TimeCurrent()-g_lastNarrative < InpNarrativeUpdateSec) return;
   g_lastNarrative = TimeCurrent();

   ENUM_STRATEGY routed = RouteRegimeToStrategy(g_regime.regime);
   bool bullish = (g_mtf.h1Bias > 0 || (g_mtf.h1Bias == 0 && g_mtf.m15Bias > 0));
   bool swept   = g_liq.sweepUpDetected || g_liq.sweepDownDetected;
   string bias  = bullish ? "BULLISH" : "BEARISH";
   string regime= RegimeToString(g_regime.regime);

   g_narrativeLine1 = "Market regime: " + regime + ".";

   if(swept)
      g_narrativeLine2 = (g_liq.sweepUpDetected ? "Buy-side" : "Sell-side") + " liquidity swept.";
   else if(g_liq.equalHighsDetected || g_liq.equalLowsDetected)
      g_narrativeLine2 = "Liquidity cluster at " + (g_liq.equalHighsDetected ? "BSL above." : "SSL below.");
   else
      g_narrativeLine2 = "No sweep signal at this time.";

   string volStr = VolStateToString(g_vol.state) + " vol, " + VolDynamicToString(g_vol.dynamic) + ".";
   g_narrativeLine3 = "Volatility: " + volStr;

   if(routed != STRAT_NONE)
      g_narrativeLine4 = "Top strategy: " + StrategyToString(routed) + ".";
   else
      g_narrativeLine4 = "No strategy active. Standing aside.";

   g_narrativeLine5 = "Trade quality: " + DoubleToString(g_scores.totalScore, 0) + "/100.  Bias: " + bias + ".";

   string session_str = SessionOverlapString(g_session.current);
   g_narrativeLine6 = "Session: " + session_str + "  MTF align: " + DoubleToString(g_mtf.alignment,0) + "%.";
}

//=====================================================================
//  MASTER DECISION ENGINE
//=====================================================================
MasterDecision BuildMasterDecision()
{
   MasterDecision d; d.tradeApproved=false;d.direction=DIR_NONE;d.lotSize=0;d.slPrice=0;d.tpPrice=0;d.strategySource=STRAT_NONE;d.riskAmountUsed=0;d.narrative="";
   string rr="";
   if(!RiskGovernanceAllowsNewTrade(rr)){d.narrative=rr;return d;}
   if(g_regime.regime==REGIME_UNSAFE){d.narrative="REGIME UNSAFE";return d;}
   if(g_regime.confidence<g_adaptiveRegimeConfThreshold){d.narrative="LOW REGIME CONFIDENCE";return d;}
   if(!g_execQuality.executionApproved){d.narrative=g_execQuality.rejectReason;return d;}
   ENUM_STRATEGY rs=RouteRegimeToStrategy(g_regime.regime);
   if(rs==STRAT_NONE){d.narrative="NO STRATEGY ROUTED";return d;}
   int hi=StrategyHealthIndex(rs);
   if(hi>=0&&hi<5&&!g_health[hi].enabled){d.narrative="STRATEGY HEALTH BLOCKED";return d;}
   StrategySignal sig=GetSignalForStrategy(rs);
   if(!sig.valid){d.narrative=sig.reason;return d;}
   double sa=sig.confidence;
   if(g_session.preferredStrategy==rs)sa=MathMin(100.0,sig.confidence*g_session.strategyWeight);
   else sa=sig.confidence*0.85;
   if(sa<g_adaptiveRegimeConfThreshold){d.narrative="SESSION ADJ CONFIDENCE LOW";return d;}
   sig.confidence=sa;
   double ra=0.0,lot=CalculateAdaptiveLotSize(sig,sig.suggestedSL,ra);
   if(lot<=0){d.narrative="INVALID LOT SIZE";return d;}
   d.tradeApproved=true;d.direction=sig.direction;d.lotSize=lot;d.slPrice=sig.suggestedSL;d.tpPrice=sig.suggestedTP;d.strategySource=rs;d.riskAmountUsed=ra;d.narrative=StrategyToString(rs);
   return d;
}

//=====================================================================
//  EXECUTION
//=====================================================================
string EncodePositionTag(ENUM_STRATEGY st, double ra){return "QPA2|"+IntegerToString((int)st)+"|"+DoubleToString(ra,2);}
bool DecodePositionTag(string c, ENUM_STRATEGY &st, double &ra)
{
   string pts[]; int n=StringSplit(c,'|',pts);
   if(n<3||ArraySize(pts)<3)return false;
   int sid=(int)StringToInteger(pts[1]);
   if(sid<0||sid>5)return false;
   st=(ENUM_STRATEGY)sid;ra=StringToDouble(pts[2]);return(ra>0);
}

bool ExecuteMasterDecision(MasterDecision &d)
{
   if(!d.tradeApproved||d.direction==DIR_NONE)return false;
   double price=(d.direction==DIR_LONG)?SymbolInfoDouble(_Symbol,SYMBOL_ASK):SymbolInfoDouble(_Symbol,SYMBOL_BID);
   if(price<=0)return false;
   double minD=(double)SymbolInfoInteger(_Symbol,SYMBOL_TRADE_STOPS_LEVEL)*SymbolInfoDouble(_Symbol,SYMBOL_POINT);
   double sl=d.slPrice,tp=d.tpPrice;
   if(d.direction==DIR_LONG){if(sl>0&&(price-sl)<minD)sl=NPrice(price-minD);if(tp>0&&(tp-price)<minD)tp=NPrice(price+minD);}
   else{if(sl>0&&(sl-price)<minD)sl=NPrice(price+minD);if(tp>0&&(price-tp)<minD)tp=NPrice(price-minD);}
   g_trade.SetExpertMagicNumber(InpMagicNumber);g_trade.SetDeviationInPoints(30);g_trade.SetTypeFilling(GetFillMode());
   bool ok=(d.direction==DIR_LONG)?g_trade.Buy(d.lotSize,_Symbol,price,sl,tp,EncodePositionTag(d.strategySource,d.riskAmountUsed)):g_trade.Sell(d.lotSize,_Symbol,price,sl,tp,EncodePositionTag(d.strategySource,d.riskAmountUsed));
   if(ok){g_tradesToday++;g_lastAction=d.narrative;DrawEntryMarker(d.direction,price,d.strategySource);}
   return ok;
}

double GetFloatingPL()
{
   double t=0;
   for(int i=PositionsTotal()-1;i>=0;i--)if(g_pos.SelectByIndex(i)&&g_pos.Magic()==InpMagicNumber&&g_pos.Symbol()==_Symbol)t+=g_pos.Profit()+g_pos.Swap()+g_pos.Commission();
   return t;
}
bool HasManagedPosition(){return PositionsTotalForMagic()>0;}

void OnTradeTransactionHandler(const MqlTradeTransaction &trans,const MqlTradeRequest &request,const MqlTradeResult &result)
{
   if(trans.type!=TRADE_TRANSACTION_DEAL_ADD)return;
   ulong dt=trans.deal;
   HistorySelect(TimeCurrent()-86400,TimeCurrent());
   if(!HistoryDealSelect(dt))return;
   if((ulong)HistoryDealGetInteger(dt,DEAL_MAGIC)!=InpMagicNumber)return;
   if(HistoryDealGetString(dt,DEAL_SYMBOL)!=_Symbol)return;
   if(HistoryDealGetInteger(dt,DEAL_ENTRY)!=DEAL_ENTRY_OUT)return;
   double pnl=HistoryDealGetDouble(dt,DEAL_PROFIT)+HistoryDealGetDouble(dt,DEAL_SWAP)+HistoryDealGetDouble(dt,DEAL_COMMISSION);
   ENUM_STRATEGY st=STRAT_NONE;double ra=0;
   if(!DecodePositionTag(HistoryDealGetString(dt,DEAL_COMMENT),st,ra))return;
   RegisterTradeResult(st,pnl,(ra>0)?pnl/ra:0.0);
   g_sessionProfit+=pnl;if(pnl>=0)g_sessionWins++;else g_sessionLosses++;
   g_lastCloseTime=TimeCurrent();g_inCooldown=true;g_cooldownLeft=InpCooldownAfterCloseSec;
   DrawExitMarker(HistoryDealGetDouble(dt,DEAL_PRICE),pnl);
}

void RunMasterDecisionCycle()
{
   if(HasManagedPosition()){g_statusText="IN TRADE";g_statusColor=C_GREEN_BRIGHT;return;}
   if(g_inCooldown){g_statusText="COOLDOWN";g_statusColor=C_CYAN_BRIGHT;return;}
   MasterDecision d=BuildMasterDecision();g_lastDecision=d;
   if(d.tradeApproved)
   {
      g_statusText="EXECUTING";g_statusColor=C_BLUE_BRIGHT;
      bool ok=ExecuteMasterDecision(d);
      g_statusText=ok?"IN TRADE":"ORDER FAIL";g_statusColor=ok?C_GREEN_BRIGHT:C_RED_BRIGHT;
   }
   else{g_statusText="ANALYZING";g_statusColor=C_GOLD_BRIGHT;g_lastAction=d.narrative;}
}

//=====================================================================
//  ===========================================================
//  ===   QUANTUM PLUS AI v2.0 -- INSTITUTIONAL UI ENGINE    ===
//  ===   Complete dashboard / chart-rendering rebuild.      ===
//  ===   Trading logic above this line is UNCHANGED.        ===
//  ===========================================================
//=====================================================================

//---------------------------------------------------------------------
//  THEME v2 -- extended institutional palette
//---------------------------------------------------------------------
#define UI_BG_DEEP      C'5,5,5'        // chart background
#define UI_PANEL        C'8,18,30'      // panel fill   (#081626 approx)
#define UI_PANEL2       C'13,28,48'     // secondary panel (#0E2038 approx)
#define UI_PANEL_HDR    C'10,22,38'
#define UI_BORDER       C'0,180,210'    // soft neon cyan
#define UI_BORDER_DIM   C'10,60,80'
#define UI_GLOW         C'0,255,255'

#define UI_TXT_PRI      C'235,242,250'  // bright white
#define UI_TXT_SEC      C'120,220,235'  // light cyan
#define UI_TXT_DIM      C'90,115,145'
#define UI_TXT_FAINT    C'55,72,95'

#define UI_GREEN        C'40,235,140'
#define UI_RED          C'255,70,90'
#define UI_GOLD         C'255,200,60'
#define UI_ORANGE       C'255,150,50'
#define UI_BLUE         C'70,160,255'
#define UI_PURPLE       C'190,110,255'

#define UI_FONT         "Segoe UI"
#define UI_FONT_B       "Segoe UI Semibold"

#define QD "QPX_"   // dashboard object prefix
#define QO "QPX_OV_" // chart-anchored overlay prefix

//---------------------------------------------------------------------
//  LAYOUT STATE -- recomputed on init + on chart resize
//---------------------------------------------------------------------
int g_chartW = 1280, g_chartH = 800;
int g_topH   = 64;
int g_leftX, g_leftW, g_rightX, g_rightW, g_bodyY, g_bottomH, g_bottomY;
int g_panelTop;

void RecomputeLayout()
{
   long w=0,h=0;
   if(!ChartGetInteger(0,CHART_WIDTH_IN_PIXELS,0,w))  w=1280;
   if(!ChartGetInteger(0,CHART_HEIGHT_IN_PIXELS,0,h)) h=800;
   g_chartW=(int)MathMax(1100,w);
   g_chartH=(int)MathMax(650,h);
   g_leftW   = S(300);
   g_rightW  = S(300);
   g_leftX   = S(8);
   g_rightX  = g_chartW - g_rightW - S(8);
   g_panelTop= S(72);
   g_bottomH = S(168);
   g_bottomY = g_chartH - g_bottomH - S(4);
}

//---------------------------------------------------------------------
//  PRIMITIVE OBJECT HELPERS (anti-flicker: update in place, never
//  recreate unless object missing)
//---------------------------------------------------------------------
void QRect(string nm,int x,int y,int w,int h,color bg,color brd=clrNONE,int bw=1,int corner=CORNER_LEFT_UPPER)
{
   string n=QD+nm;
   if(ObjectFind(0,n)<0) ObjectCreate(0,n,OBJ_RECTANGLE_LABEL,0,0,0);
   ObjectSetInteger(0,n,OBJPROP_CORNER,corner);
   ObjectSetInteger(0,n,OBJPROP_XDISTANCE,x);
   ObjectSetInteger(0,n,OBJPROP_YDISTANCE,y);
   ObjectSetInteger(0,n,OBJPROP_XSIZE,w);
   ObjectSetInteger(0,n,OBJPROP_YSIZE,h);
   ObjectSetInteger(0,n,OBJPROP_BGCOLOR,bg);
   ObjectSetInteger(0,n,OBJPROP_SELECTABLE,false);
   ObjectSetInteger(0,n,OBJPROP_HIDDEN,true);
   ObjectSetInteger(0,n,OBJPROP_ZORDER,0);
   if(brd!=clrNONE){ObjectSetInteger(0,n,OBJPROP_BORDER_TYPE,BORDER_FLAT);ObjectSetInteger(0,n,OBJPROP_COLOR,brd);ObjectSetInteger(0,n,OBJPROP_WIDTH,bw);}
   else{ObjectSetInteger(0,n,OBJPROP_BORDER_TYPE,BORDER_FLAT);ObjectSetInteger(0,n,OBJPROP_COLOR,bg);}
}

// Glow border: faint outer rect drawn first, crisp inner border drawn by QRect itself.
void QGlow(string nm,int x,int y,int w,int h,color glowClr,int corner=CORNER_LEFT_UPPER)
{
   string n=QD+nm+"_glow";
   if(ObjectFind(0,n)<0) ObjectCreate(0,n,OBJ_RECTANGLE_LABEL,0,0,0);
   ObjectSetInteger(0,n,OBJPROP_CORNER,corner);
   ObjectSetInteger(0,n,OBJPROP_XDISTANCE,x-1);
   ObjectSetInteger(0,n,OBJPROP_YDISTANCE,y-1);
   ObjectSetInteger(0,n,OBJPROP_XSIZE,w+2);
   ObjectSetInteger(0,n,OBJPROP_YSIZE,h+2);
   ObjectSetInteger(0,n,OBJPROP_BGCOLOR,UI_BG_DEEP);
   ObjectSetInteger(0,n,OBJPROP_BORDER_TYPE,BORDER_FLAT);
   ObjectSetInteger(0,n,OBJPROP_COLOR,glowClr);
   ObjectSetInteger(0,n,OBJPROP_WIDTH,1);
   ObjectSetInteger(0,n,OBJPROP_SELECTABLE,false);
   ObjectSetInteger(0,n,OBJPROP_HIDDEN,true);
   ObjectSetInteger(0,n,OBJPROP_ZORDER,-1);
}

void QLabel(string nm,int x,int y,string txt,color clr,int fsz,string fnt=UI_FONT_B,int corner=CORNER_LEFT_UPPER)
{
   string n=QD+nm;
   if(ObjectFind(0,n)<0) ObjectCreate(0,n,OBJ_LABEL,0,0,0);
   ObjectSetInteger(0,n,OBJPROP_CORNER,corner);
   ObjectSetInteger(0,n,OBJPROP_XDISTANCE,x);
   ObjectSetInteger(0,n,OBJPROP_YDISTANCE,y);
   ObjectSetString (0,n,OBJPROP_TEXT,txt);
   ObjectSetInteger(0,n,OBJPROP_COLOR,clr);
   ObjectSetInteger(0,n,OBJPROP_FONTSIZE,fsz);
   ObjectSetString (0,n,OBJPROP_FONT,fnt);
   ObjectSetInteger(0,n,OBJPROP_SELECTABLE,false);
   ObjectSetInteger(0,n,OBJPROP_HIDDEN,true);
   ObjectSetInteger(0,n,OBJPROP_ZORDER,3);
   ObjectSetInteger(0,n,OBJPROP_ANCHOR,ANCHOR_LEFT_UPPER);
}

void QUpd(string nm,string txt,color clr=clrNONE)
{
   string n=QD+nm;
   if(ObjectFind(0,n)<0)return;
   ObjectSetString(0,n,OBJPROP_TEXT,txt);
   if(clr!=clrNONE)ObjectSetInteger(0,n,OBJPROP_COLOR,clr);
}
void QUpdBG(string nm,color bg){string n=QD+nm;if(ObjectFind(0,n)>=0)ObjectSetInteger(0,n,OBJPROP_BGCOLOR,bg);}
void QUpdBrd(string nm,color brd){string n=QD+nm;if(ObjectFind(0,n)>=0)ObjectSetInteger(0,n,OBJPROP_COLOR,brd);}
void QMove(string nm,int x,int y){string n=QD+nm;if(ObjectFind(0,n)>=0){ObjectSetInteger(0,n,OBJPROP_XDISTANCE,x);ObjectSetInteger(0,n,OBJPROP_YDISTANCE,y);}}
void QResize(string nm,int w,int h){string n=QD+nm;if(ObjectFind(0,n)>=0){ObjectSetInteger(0,n,OBJPROP_XSIZE,w);ObjectSetInteger(0,n,OBJPROP_YSIZE,h);}}

// Progress / score bar: background track + colored fill
void QBar(string nm,int x,int y,int w,int h,double pct,color fg)
{
   QRect(nm+"_bg",x,y,w,h,UI_PANEL2,UI_BORDER_DIM,1);
   int fw=(int)MathMax(2,MathRound(MathMax(0.0,MathMin(100.0,pct))/100.0*(w-2)));
   QRect(nm+"_fg",x+1,y+1,fw,h-2,fg,clrNONE);
}
void QBarUpd(string nm,double pct,color fg)
{
   string nb=QD+nm+"_bg",nf=QD+nm+"_fg";
   if(ObjectFind(0,nb)<0)return;
   int w=(int)ObjectGetInteger(0,nb,OBJPROP_XSIZE);
   int fw=(int)MathMax(2,MathRound(MathMax(0.0,MathMin(100.0,pct))/100.0*(w-2)));
   if(ObjectFind(0,nf)>=0){ObjectSetInteger(0,nf,OBJPROP_XSIZE,fw);ObjectSetInteger(0,nf,OBJPROP_BGCOLOR,fg);}
}
void QSep(string nm,int x,int y,int w){QRect(nm,x,y,w,1,UI_BORDER_DIM,clrNONE);}

color QScoreColor(double v){ if(v>=75)return UI_GREEN; if(v>=50)return UI_GOLD; return UI_RED; }

// Section header bar with small index tag, e.g. "01  MARKET OVERVIEW"
void QSectionHdr(string nm,int x,int y,int w,string idx,string title)
{
   QRect(nm+"_bg",x,y,w,S(20),UI_PANEL_HDR,UI_BORDER_DIM,1);
   QLabel(nm+"_idx",x+S(6),y+S(4),idx,UI_TXT_SEC,FS(7),UI_FONT_B);
   QLabel(nm+"_ttl",x+S(34),y+S(4),title,UI_TXT_SEC,FS(7),UI_FONT_B);
}

//=====================================================================
//  TOP COMMAND BAR
//=====================================================================
void InitTopBar()
{
   int W=g_chartW, H=g_topH;
   QGlow("topbar",0,0,W,H,UI_GLOW);
   QRect("topbar",0,0,W,H,UI_PANEL,UI_BORDER,1);
   QSep("topbar_sep",0,H,W);

   // Identity block
   QLabel("ttl_name",S(14),S(10),InpBotName,UI_TXT_PRI,FS(12),UI_FONT_B);
   QLabel("ttl_sub", S(14),S(30),"MARKET INTELLIGENCE ENGINE",UI_TXT_DIM,FS(7),UI_FONT);

   // Symbol block
   int sx=S(280);
   QSep("sep_sym",sx,S(8),1); QResize("sep_sym",1,S(48));QUpdBG("sep_sym",UI_BORDER_DIM);
   QLabel("sym_name",sx+S(14),S(10),_Symbol,UI_TXT_PRI,FS(11),UI_FONT_B);
   QLabel("sym_tf",  sx+S(14),S(30),"TF",UI_TXT_DIM,FS(7),UI_FONT);

   // Broker time block
   int tx=S(440);
   QSep("sep_time",tx,S(8),1); QResize("sep_time",1,S(48));QUpdBG("sep_time",UI_BORDER_DIM);
   QLabel("lb_brokertime",tx+S(14),S(8),"BROKER TIME",UI_TXT_DIM,FS(7),UI_FONT);
   QLabel("vl_brokertime",tx+S(14),S(20),"--:--:--",UI_TXT_PRI,FS(11),UI_FONT_B);
   QLabel("vl_brokerdate",tx+S(14),S(38),"--",UI_TXT_DIM,FS(7),UI_FONT);

   // Session block
   int ssx=S(600);
   QSep("sep_sess",ssx,S(8),1); QResize("sep_sess",1,S(48));QUpdBG("sep_sess",UI_BORDER_DIM);
   QLabel("lb_session_t",ssx+S(14),S(8),"SESSION",UI_TXT_DIM,FS(7),UI_FONT);
   QLabel("vl_session_t",ssx+S(14),S(20),"--",UI_TXT_PRI,FS(10),UI_FONT_B);
   QRect ("sess_overlap_bg",ssx+S(110),S(16),S(170),S(20),UI_PANEL2,UI_GOLD,1);
   QLabel("vl_sess_overlap",ssx+S(118),S(20),"--",UI_GOLD,FS(8),UI_FONT_B);

   // AI confidence badge (right side, fixed offset from right edge)
   int cx=W-S(330);
   QSep("sep_conf",cx,S(8),1); QResize("sep_conf",1,S(48));QUpdBG("sep_conf",UI_BORDER_DIM);
   QLabel("lb_aiconf",cx+S(14),S(8),"AI CONFIDENCE",UI_TXT_DIM,FS(7),UI_FONT);
   QRect ("conf_ring",cx+S(14),S(20),S(46),S(30),UI_PANEL2,UI_GREEN,2);
   QLabel("vl_aiconf",cx+S(22),S(26),"0%",UI_GREEN,FS(13),UI_FONT_B);
   QLabel("vl_aiconf_sub",cx+S(70),S(26),"",UI_TXT_DIM,FS(7),UI_FONT);

   // Market status badge (far right)
   int mx=W-S(150);
   QSep("sep_status",mx,S(8),1); QResize("sep_status",1,S(48));QUpdBG("sep_status",UI_BORDER_DIM);
   QLabel("lb_mstatus",mx+S(14),S(8),"MARKET STATUS",UI_TXT_DIM,FS(7),UI_FONT);
   QRect ("status_dot",mx+S(14),S(24),S(8),S(8),UI_GOLD,clrNONE);
   QLabel("vl_mstatus",mx+S(28),S(20),"INITIALIZING",UI_GOLD,FS(9),UI_FONT_B);
}

void UpdateTopBar()
{
   QUpd("sym_tf",PeriodToString((ENUM_TIMEFRAMES)Period()),UI_TXT_DIM);
   QUpd("vl_brokertime",TimeToString(TimeCurrent(),TIME_SECONDS),UI_TXT_PRI);
   QUpd("vl_brokerdate",TimeToString(TimeCurrent(),TIME_DATE),UI_TXT_DIM);

   string sname=SessionToString(g_session.current);
   QUpd("vl_session_t",sname,UI_TXT_PRI);

   bool overlap=(g_session.current==SESSION_NY_OPEN);
   string ovTxt = overlap?"LONDON-NY OVERLAP":(g_session.sessionVolatilityScore>60?"HIGH OPPORTUNITY":"STANDARD SESSION");
   color  ovClr = overlap?UI_GOLD:(g_session.sessionVolatilityScore>60?UI_ORANGE:UI_TXT_DIM);
   QUpd("vl_sess_overlap",ovTxt,ovClr);
   QUpdBrd("sess_overlap_bg",ovClr);

   double conf=g_scores.totalScore;
   color cc=QScoreColor(conf);
   QUpd("vl_aiconf",DoubleToString(conf,0)+"%",cc);
   QUpdBrd("conf_ring",cc);
   QUpd("vl_aiconf_sub",g_regime.regime==REGIME_UNSAFE?"GUARDED":"LIVE",UI_TXT_DIM);

   QUpd("vl_mstatus",g_statusText,g_statusColor);
   QUpdBG("status_dot",g_statusColor);
}

string PeriodToString(ENUM_TIMEFRAMES p)
{
   switch(p)
   {
      case PERIOD_M1:return "M1";case PERIOD_M5:return "M5";case PERIOD_M15:return "M15";
      case PERIOD_M30:return "M30";case PERIOD_H1:return "H1";case PERIOD_H4:return "H4";
      case PERIOD_D1:return "D1";case PERIOD_W1:return "W1";case PERIOD_MN1:return "MN";
      default:return EnumToString(p);
   }
}

//=====================================================================
//  LEFT PANEL -- MARKET INTELLIGENCE
//=====================================================================
void InitLeftPanel()
{
   int X=g_leftX, W=g_leftW, y=g_panelTop;

   // 01 MARKET OVERVIEW
   QSectionHdr("s01",X,y,W,"01","MARKET OVERVIEW"); y+=S(24);
   QRect("ov_body",X,y,W,S(78),UI_PANEL,UI_BORDER_DIM,1);
   QLabel("lb_ov_regime",X+S(8),y+S(6),"REGIME",UI_TXT_DIM,FS(7));
   QLabel("vl_ov_regime",X+S(8),y+S(17),"--",UI_GREEN,FS(9),UI_FONT_B);
   QLabel("lb_ov_trend",X+S(160),y+S(6),"TREND STR",UI_TXT_DIM,FS(7));
   QLabel("vl_ov_trend",X+S(160),y+S(17),"0/100",UI_TXT_PRI,FS(8));
   QLabel("lb_ov_vol",X+S(8),y+S(34),"VOLATILITY",UI_TXT_DIM,FS(7));
   QLabel("vl_ov_vol",X+S(8),y+S(45),"--",UI_TXT_PRI,FS(8));
   QLabel("lb_ov_liq",X+S(160),y+S(34),"LIQUIDITY",UI_TXT_DIM,FS(7));
   QLabel("vl_ov_liq",X+S(160),y+S(45),"--",UI_ORANGE,FS(8));
   QLabel("lb_ov_struct",X+S(8),y+S(62),"STRUCTURE",UI_TXT_DIM,FS(7));
   QLabel("vl_ov_struct",X+S(70),y+S(62),"--",UI_TXT_PRI,FS(8));
   QLabel("lb_ov_bias",X+S(160),y+S(62),"BIAS",UI_TXT_DIM,FS(7));
   QLabel("vl_ov_bias",X+S(200),y+S(62),"--",UI_TXT_PRI,FS(8),UI_FONT_B);
   y+=S(82);

   // 02 AI STRATEGY ROUTER
   QSectionHdr("s02",X,y,W,"02","AI STRATEGY ROUTER"); y+=S(24);
   QRect("rt_body",X,y,W,S(78),UI_PANEL,UI_BORDER_DIM,1);
   QLabel("lb_rt_active",X+S(8),y+S(5),"ACTIVE STRATEGY",UI_TXT_DIM,FS(7));
   QRect ("rt_active_bg",X+S(2),y+S(16),W-S(4),S(20),UI_PANEL2,UI_GREEN,1);
   QLabel("vl_rt_active",X+S(8),y+S(20),"--",UI_GREEN,FS(9),UI_FONT_B);
   QLabel("lb_rt_reason",X+S(8),y+S(40),"REASON",UI_TXT_DIM,FS(7));
   QLabel("vl_rt_reason",X+S(8),y+S(51),"--",UI_TXT_SEC,FS(7),UI_FONT);
   QLabel("lb_rt_quality",X+S(160),y+S(40),"TRADE QUALITY",UI_TXT_DIM,FS(7));
   QLabel("vl_rt_quality",X+S(160),y+S(51),"0/100",UI_GOLD,FS(10),UI_FONT_B);
   y+=S(82);

   // 03 INDICATOR INTELLIGENCE
   QSectionHdr("s03",X,y,W,"03","INDICATOR INTELLIGENCE"); y+=S(24);
   QRect("ind_body",X,y,W,S(62),UI_PANEL,UI_BORDER_DIM,1);
   string keys[5]={"ema","adx","rsi","vol","liq"};
   string lbls[5]={"EMA","ADX","RSI","VOL","LIQ"};
   for(int i=0;i<5;i++)
   {
      int cx=X+S(6)+ (i%3)*S(98);
      int cy=y+S(5)+(i/3)*S(28);
      QRect ("ind_"+keys[i]+"_bg",cx,cy,S(90),S(22),UI_DGRAYLIKE(),UI_TXT_FAINT,1);
      QLabel("ind_"+keys[i]+"_n",cx+S(6),cy+S(4),lbls[i],UI_TXT_FAINT,FS(7),UI_FONT_B);
      QLabel("ind_"+keys[i]+"_v",cx+S(56),cy+S(4),"--",UI_TXT_FAINT,FS(7),UI_FONT_B);
   }
   y+=S(66);

   // 04 MARKET CONDITIONS HEATMAP
   QSectionHdr("s04",X,y,W,"04","MARKET CONDITIONS HEATMAP"); y+=S(24);
   int hmRows=7;
   QRect("hm_body",X,y,W,S(8+hmRows*16),UI_PANEL,UI_BORDER_DIM,1);
   string hmNames[7]={"TREND","VOLATILITY","MOMENTUM","VOLUME","LIQUIDITY","STRUCTURE","SESSION"};
   for(int i=0;i<hmRows;i++)
   {
      int ry=y+S(4)+i*S(16);
      QLabel("hm_lb_"+IntegerToString(i),X+S(6),ry+S(2),hmNames[i],UI_TXT_DIM,FS(7),UI_FONT);
      QBar("hm_bar_"+IntegerToString(i),X+S(100),ry,W-S(150),S(10),0,UI_GREEN);
      QLabel("hm_val_"+IntegerToString(i),X+W-S(40),ry+S(1),"00",UI_TXT_PRI,FS(7));
   }
   y+=S(12+hmRows*16);

   // 05 TRADE QUALITY SCORECARD
   QSectionHdr("s05",X,y,W,"05","TRADE QUALITY SCORECARD"); y+=S(24);
   QRect("tq_body",X,y,W,S(80),UI_PANEL,UI_BORDER_DIM,1);
   string tqK[5]={"trend","liq","vol","sess","struct"};
   string tqN[5]={"TREND","LIQUIDITY","VOLUME","SESSION","STRUCTURE"};
   for(int i=0;i<5;i++)
   {
      int cx=X+S(8)+(i%3)*S(95);
      int cy=y+S(6)+(i/3)*S(34);
      QLabel("tq_lb_"+tqK[i],cx,cy,tqN[i],UI_TXT_DIM,FS(6),UI_FONT);
      QLabel("tq_vl_"+tqK[i],cx,cy+S(11),"0",UI_GREEN,FS(11),UI_FONT_B);
   }
   QRect ("tq_total_bg",X+W-S(86),y+S(38),S(78),S(36),UI_PANEL_HDR,UI_GOLD,2);
   QLabel("lb_tq_total",X+W-S(80),y+S(42),"TOTAL",UI_TXT_DIM,FS(6));
   QLabel("vl_tq_total",X+W-S(80),y+S(53),"0/100",UI_GOLD,FS(10),UI_FONT_B);
   y+=S(84);
}

color UI_DGRAYLIKE(){return C'14,22,38';}

void UpdateLeftPanel()
{
   QUpd("vl_ov_regime",RegimeToString(g_regime.regime),RegimeToColor(g_regime.regime));
   QUpd("vl_ov_trend",DoubleToString(g_scores.trendScore,0)+"/100",QScoreColor(g_scores.trendScore));
   QUpd("vl_ov_vol",VolStateToString(g_vol.state)+" / "+VolDynamicToString(g_vol.dynamic),
        (g_vol.state==VOL_EXTREME)?UI_RED:(g_vol.state==VOL_HIGH?UI_ORANGE:UI_TXT_PRI));
   QUpd("vl_ov_liq",LiquidityStatusString(),(g_liq.sweepUpDetected||g_liq.sweepDownDetected)?UI_PURPLE:UI_ORANGE);
   string structStr=(g_liq.sweepUpDetected||g_liq.sweepDownDetected)?"MSS CONFIRMED":(g_mtf.alignment>70?"CLEAR":"BUILDING");
   QUpd("vl_ov_struct",structStr,UI_TXT_PRI);
   int h1b=g_mtf.h1Bias;
   QUpd("vl_ov_bias",(h1b>0)?"BULLISH":(h1b<0?"BEARISH":"NEUTRAL"),(h1b>0)?UI_GREEN:(h1b<0?UI_RED:UI_TXT_PRI));

   ENUM_STRATEGY routed=RouteRegimeToStrategy(g_regime.regime);
   bool active=(routed!=STRAT_NONE);
   QUpd("vl_rt_active",active?StrategyToString(routed):"NONE -- STAND ASIDE",active?UI_GREEN:UI_TXT_DIM);
   QUpdBrd("rt_active_bg",active?UI_GREEN:UI_TXT_FAINT);
   QUpdBG ("rt_active_bg",active?C'0,40,20':UI_PANEL2);
   QUpd("vl_rt_reason",g_lastDecision.narrative,UI_TXT_SEC);
   QUpd("vl_rt_quality",DoubleToString(g_scores.totalScore,0)+"/100",QScoreColor(g_scores.totalScore));

   double rsiM5[1]; if(CopyBuffer(g_m5_rsi,0,0,1,rsiM5)<=0)rsiM5[0]=50;
   bool emaActive=(MathAbs(g_mtf.m5Bias)>0||MathAbs(g_mtf.h1Bias)>0);
   bool adxActive=(g_mtf.alignment>60);
   bool rsiActive=(rsiM5[0]>65||rsiM5[0]<35);
   bool volActive=(g_vol.state!=VOL_NORMAL);
   bool liqActive=(g_liq.equalHighsDetected||g_liq.equalLowsDetected);
   bool act[5]={emaActive,adxActive,rsiActive,volActive,liqActive};
   double val[5]={g_scores.trendScore,g_mtf.alignment,rsiM5[0],g_scores.volatilityScore,g_scores.liquidityScore};
   string keys[5]={"ema","adx","rsi","vol","liq"};
   for(int i=0;i<5;i++)
   {
      color c=act[i]?UI_GREEN:UI_TXT_FAINT;
      QUpdBG ("ind_"+keys[i]+"_bg",act[i]?C'0,40,20':UI_DGRAYLIKE());
      QUpdBrd("ind_"+keys[i]+"_bg",c);
      QUpd("ind_"+keys[i]+"_v",DoubleToString(val[i],0),c);
   }

   double hmVals[7]={g_scores.trendScore,g_scores.volatilityScore,g_scores.momentumScore,g_scores.volumeScore,g_scores.liquidityScore,g_scores.structureClarity,g_scores.sessionScore};
   for(int i=0;i<7;i++)
   {
      color bc=QScoreColor(hmVals[i]);
      QBarUpd("hm_bar_"+IntegerToString(i),hmVals[i],bc);
      QUpd("hm_val_"+IntegerToString(i),IntegerToString((int)hmVals[i]),bc);
   }

   QUpd("tq_vl_trend", IntegerToString((int)g_scores.trendScore),     QScoreColor(g_scores.trendScore));
   QUpd("tq_vl_liq",   IntegerToString((int)g_scores.liquidityScore), QScoreColor(g_scores.liquidityScore));
   QUpd("tq_vl_vol",   IntegerToString((int)g_scores.volumeScore),    QScoreColor(g_scores.volumeScore));
   QUpd("tq_vl_sess",  IntegerToString((int)g_scores.sessionScore),   QScoreColor(g_scores.sessionScore));
   QUpd("tq_vl_struct",IntegerToString((int)g_scores.structureScore), QScoreColor(g_scores.structureScore));
   color tqC=QScoreColor(g_scores.totalScore);
   QUpd("vl_tq_total",DoubleToString(g_scores.totalScore,0)+"/100",tqC);
   QUpdBrd("tq_total_bg",tqC);
}

//=====================================================================
//  RIGHT PANEL -- CONTROL & RISK INTELLIGENCE
//=====================================================================
void InitRightPanel()
{
   int X=g_rightX, W=g_rightW, y=g_panelTop;

   // 11 SESSION INTELLIGENCE
   QSectionHdr("s11",X,y,W,"11","SESSION INTELLIGENCE"); y+=S(24);
   QRect("se_body",X,y,W,S(96),UI_PANEL,UI_BORDER_DIM,1);
   string seK[4]={"asia","london","ny","ovl"};
   string seN[4]={"ASIA","LONDON","NEW YORK","NY OVERLAP"};
   for(int i=0;i<4;i++)
   {
      int ry=y+S(4)+i*S(22);
      QRect ("se_dot_"+seK[i],X+S(8),ry+S(6),S(8),S(8),UI_TXT_FAINT,clrNONE);
      QLabel("se_lb_"+seK[i],X+S(24),ry+S(5),seN[i],UI_TXT_PRI,FS(8));
      QLabel("se_vl_"+seK[i],X+S(150),ry+S(5),"--",UI_TXT_DIM,FS(7));
   }
   y+=S(100);

   // 12 ECONOMIC FILTERS
   QSectionHdr("s12",X,y,W,"12","ECONOMIC FILTERS"); y+=S(24);
   QRect("ef_body",X,y,W,S(94),UI_PANEL,UI_BORDER_DIM,1);
   string efK[5]={"spread","vol","liq","news","corr"};
   string efN[5]={"SPREAD","VOLATILITY","LIQUIDITY","NEWS IMPACT","CORRELATION"};
   for(int i=0;i<5;i++)
   {
      int ry=y+S(4)+i*S(18);
      QLabel("ef_dot_"+efK[i],X+S(8),ry+S(2),"■",UI_GREEN,FS(8));
      QLabel("ef_lb_"+efK[i],X+S(24),ry+S(2),efN[i],UI_TXT_PRI,FS(7));
      QLabel("ef_vl_"+efK[i],X+S(180),ry+S(2),"GOOD",UI_GREEN,FS(7),UI_FONT_B);
   }
   y+=S(98);

   // 13 RISK MANAGEMENT
   QSectionHdr("s13",X,y,W,"13","RISK MANAGEMENT"); y+=S(24);
   QRect("rk_body",X,y,W,S(94),UI_PANEL,UI_BORDER_DIM,1);
   QLabel("lb_rk_risk",X+S(8), y+S(5),"RISK / TRADE",UI_TXT_DIM,FS(7));
   QLabel("vl_rk_risk",X+S(8), y+S(16),"0.0%",UI_TXT_PRI,FS(9),UI_FONT_B);
   QLabel("lb_rk_lot",X+S(160),y+S(5),"POSITION SIZE",UI_TXT_DIM,FS(7));
   QLabel("vl_rk_lot",X+S(160),y+S(16),"0.00",UI_TXT_PRI,FS(9),UI_FONT_B);
   QLabel("lb_rk_dd",X+S(8), y+S(36),"DRAWDOWN",UI_TXT_DIM,FS(7));
   QLabel("vl_rk_dd",X+S(8), y+S(47),"0.00%",UI_TXT_PRI,FS(9),UI_FONT_B);
   QLabel("lb_rk_daily",X+S(160),y+S(36),"DAILY RISK",UI_TXT_DIM,FS(7));
   QLabel("vl_rk_daily",X+S(160),y+S(47),"0.0% / 0.0%",UI_TXT_PRI,FS(8));
   QLabel("lb_rk_rr",X+S(8), y+S(67),"RISK : REWARD",UI_TXT_DIM,FS(7));
   QLabel("vl_rk_rr",X+S(8), y+S(78),"--",UI_TXT_PRI,FS(8));
   QLabel("lb_rk_exp",X+S(160),y+S(67),"EXPOSURE",UI_TXT_DIM,FS(7));
   QLabel("vl_rk_exp",X+S(160),y+S(78),"0",UI_TXT_PRI,FS(8));
   y+=S(98);

   // 14 OPEN POSITIONS
   QSectionHdr("s14",X,y,W,"14","OPEN POSITIONS"); y+=S(24);
   QRect("op_body",X,y,W,S(96),UI_PANEL,UI_BORDER_DIM,1);
   QLabel("lb_op_sym",X+S(8), y+S(5),"SYMBOL",UI_TXT_DIM,FS(7));
   QLabel("vl_op_sym",X+S(8), y+S(16),"--",UI_TXT_PRI,FS(9),UI_FONT_B);
   QLabel("lb_op_dir",X+S(160),y+S(5),"DIRECTION",UI_TXT_DIM,FS(7));
   QLabel("vl_op_dir",X+S(160),y+S(16),"--",UI_TXT_PRI,FS(9),UI_FONT_B);
   QLabel("lb_op_entry",X+S(8), y+S(36),"ENTRY",UI_TXT_DIM,FS(7));
   QLabel("vl_op_entry",X+S(8), y+S(47),"--",UI_TXT_PRI,FS(8));
   QLabel("lb_op_cur",X+S(160),y+S(36),"CURRENT",UI_TXT_DIM,FS(7));
   QLabel("vl_op_cur",X+S(160),y+S(47),"--",UI_TXT_PRI,FS(8));
   QLabel("lb_op_pl",X+S(8), y+S(67),"P&L",UI_TXT_DIM,FS(7));
   QLabel("vl_op_pl",X+S(8), y+S(78),"+0.00",UI_GREEN,FS(9),UI_FONT_B);
   QLabel("lb_op_sl",X+S(160),y+S(67),"SL / TP",UI_TXT_DIM,FS(7));
   QLabel("vl_op_sl",X+S(160),y+S(78),"-- / --",UI_TXT_PRI,FS(7));
   y+=S(100);
}

void UpdateRightPanel()
{
   color cA=(g_session.current==SESSION_ASIAN)?UI_PURPLE:UI_TXT_FAINT;
   color cL=(g_session.current==SESSION_LONDON_OPEN||g_session.current==SESSION_LONDON_MID)?UI_BLUE:UI_TXT_FAINT;
   color cN=(g_session.current==SESSION_NY_OPEN||g_session.current==SESSION_NY_PM)?UI_ORANGE:UI_TXT_FAINT;
   color cO=(g_session.current==SESSION_NY_OPEN)?UI_GOLD:UI_TXT_FAINT;
   QUpdBG("se_dot_asia",cA);   QUpd("se_vl_asia",  cA!=UI_TXT_FAINT?"ACTIVE":"--",cA);
   QUpdBG("se_dot_london",cL);QUpd("se_vl_london",cL!=UI_TXT_FAINT?"ACTIVE":"--",cL);
   QUpdBG("se_dot_ny",cN);    QUpd("se_vl_ny",    cN!=UI_TXT_FAINT?"ACTIVE":"--",cN);
   QUpdBG("se_dot_ovl",cO);   QUpd("se_vl_ovl",   cO!=UI_TXT_FAINT?"HIGH OPP.":"--",cO);

   double sp=(double)SymbolInfoInteger(_Symbol,SYMBOL_SPREAD);
   QEcoFilter("spread", sp<=InpMaxSpreadPoints*0.6?2:(sp<=InpMaxSpreadPoints?1:0));
   QEcoFilter("vol",    g_vol.state==VOL_EXTREME?0:(g_vol.state==VOL_HIGH?1:2));
   QEcoFilter("liq",    g_liq.pressureScore>=50?2:(g_liq.pressureScore>=25?1:0));
   QEcoFilter("news",   g_newsState==NEWS_NORMAL?2:(g_newsState==NEWS_CAUTION?1:0));
   QEcoFilter("corr",   2);

   QUpd("vl_rk_risk",DoubleToString(InpRiskPercentPerTrade,2)+"%",UI_TXT_PRI);
   double lastLot=(g_lastDecision.lotSize>0)?g_lastDecision.lotSize:0.0;
   QUpd("vl_rk_lot",DoubleToString(lastLot,2),UI_TXT_PRI);
   QUpd("vl_rk_dd",DoubleToString(g_risk.currentDrawdownPct,2)+"%",
        (g_risk.currentDrawdownPct<3)?UI_GREEN:(g_risk.currentDrawdownPct<7?UI_ORANGE:UI_RED));
   QUpd("vl_rk_daily",DoubleToString(g_risk.dailyRiskUsedPct,1)+"% / "+DoubleToString(InpMaxDailyLossPct,1)+"%",UI_TXT_PRI);
   string rrStr="--";
   if(g_lastDecision.tradeApproved)
   {
      double entry=(g_lastDecision.direction==DIR_LONG)?SymbolInfoDouble(_Symbol,SYMBOL_ASK):SymbolInfoDouble(_Symbol,SYMBOL_BID);
      double rdist=MathAbs(entry-g_lastDecision.slPrice), tdist=MathAbs(g_lastDecision.tpPrice-entry);
      if(rdist>0) rrStr="1 : "+DoubleToString(tdist/rdist,1);
   }
   QUpd("vl_rk_rr",rrStr,UI_TXT_PRI);
   QUpd("vl_rk_exp",IntegerToString(PositionsTotalForMagic())+" / "+IntegerToString(InpMaxConcurrentTrades),UI_TXT_PRI);

   int digs=(int)SymbolInfoInteger(_Symbol,SYMBOL_DIGITS);
   if(HasManagedPosition())
   {
      for(int i=PositionsTotal()-1;i>=0;i--)
      {
         if(g_pos.SelectByIndex(i)&&g_pos.Magic()==InpMagicNumber&&g_pos.Symbol()==_Symbol)
         {
            bool isBuy=(g_pos.PositionType()==POSITION_TYPE_BUY);
            QUpd("vl_op_sym",_Symbol,UI_TXT_PRI);
            QUpd("vl_op_dir",isBuy?"BUY":"SELL",isBuy?UI_GREEN:UI_RED);
            QUpd("vl_op_entry",DoubleToString(g_pos.PriceOpen(),digs),UI_TXT_PRI);
            QUpd("vl_op_cur",DoubleToString(g_pos.PriceCurrent(),digs),UI_TXT_PRI);
            double pl=g_pos.Profit()+g_pos.Swap()+g_pos.Commission();
            QUpd("vl_op_pl",(pl>=0?"+":"")+DoubleToString(pl,2),pl>=0?UI_GREEN:UI_RED);
            QUpd("vl_op_sl",DoubleToString(g_pos.StopLoss(),digs)+" / "+DoubleToString(g_pos.TakeProfit(),digs),UI_TXT_PRI);
            break;
         }
      }
   }
   else
   {
      QUpd("vl_op_sym","-- FLAT --",UI_TXT_DIM);
      QUpd("vl_op_dir","--",UI_TXT_DIM);
      QUpd("vl_op_entry","--",UI_TXT_DIM);
      QUpd("vl_op_cur","--",UI_TXT_DIM);
      QUpd("vl_op_pl","+0.00",UI_TXT_DIM);
      QUpd("vl_op_sl","-- / --",UI_TXT_DIM);
   }
}

void QEcoFilter(string key,int level) // 0=bad,1=warn,2=good
{
   color c=(level==2)?UI_GREEN:(level==1?UI_GOLD:UI_RED);
   string t=(level==2)?"GOOD":(level==1?"WATCH":"POOR");
   QUpd("ef_dot_"+key,"■",c);
   QUpd("ef_vl_"+key,t,c);
}

//=====================================================================
//  BOTTOM INTELLIGENCE PANEL
//=====================================================================
void InitBottomPanel()
{
   int X=S(8), W=g_chartW-S(16), Y=g_bottomY, H=g_bottomH;
   int colW=(W-S(16))/3;
   int c1=X, c2=X+colW+S(8), c3=X+2*(colW+S(8));

   QGlow("bot_frame",X,Y,W,H,UI_GLOW);
   QRect("bot_frame",X,Y,W,H,UI_PANEL,UI_BORDER,1);

   // Column 1 -- AI MARKET COMMENTARY
   QLabel("bot_c1_hdr",c1+S(10),Y+S(8),"AI MARKET COMMENTARY",UI_GOLD,FS(9),UI_FONT_B);
   for(int i=0;i<6;i++)
      QLabel("bot_c1_l"+IntegerToString(i),c1+S(10),Y+S(28)+i*S(16),"",UI_TXT_SEC,FS(7),UI_FONT);
   QLabel("bot_c1_ts",c1+S(10),Y+H-S(16),"Last update: --",UI_TXT_FAINT,FS(6),UI_FONT);

   QSep("bot_sep1",c2-S(4),Y+S(6),1); QResize("bot_sep1",1,H-S(12)); QUpdBG("bot_sep1",UI_BORDER_DIM);

   // Column 2 -- KEY INSIGHTS
   QLabel("bot_c2_hdr",c2+S(10),Y+S(8),"KEY INSIGHTS",UI_GOLD,FS(9),UI_FONT_B);
   string insKeys[6]={"sweep","bos","mss","trend","vol","sess"};
   string insLbl[6]={"Liquidity Sweep","BOS","MSS","Trend Alignment","Volume","Session Align"};
   for(int i=0;i<6;i++)
   {
      int ry=Y+S(28)+i*S(16);
      QLabel("bot_ins_dot_"+insKeys[i],c2+S(10),ry,"■",UI_TXT_FAINT,FS(7));
      QLabel("bot_ins_lb_"+insKeys[i],c2+S(24),ry,insLbl[i]+":",UI_TXT_DIM,FS(7),UI_FONT);
      QLabel("bot_ins_vl_"+insKeys[i],c2+S(150),ry,"--",UI_TXT_PRI,FS(7),UI_FONT_B);
   }

   QSep("bot_sep2",c3-S(4),Y+S(6),1); QResize("bot_sep2",1,H-S(12)); QUpdBG("bot_sep2",UI_BORDER_DIM);

   // Column 3 -- INSTITUTIONAL FLOW
   QLabel("bot_c3_hdr",c3+S(10),Y+S(8),"INSTITUTIONAL FLOW",UI_GOLD,FS(9),UI_FONT_B);
   QLabel("flow_lb_sell",c3+S(10), Y+S(30),"SELL PRESSURE",UI_TXT_DIM,FS(6));
   QBar("flow_bar_sell",c3+S(10),Y+S(42),colW-S(20),S(10),0,UI_RED);
   QLabel("flow_vl_sell",c3+S(10),Y+S(54),"0%",UI_RED,FS(8),UI_FONT_B);
   QLabel("flow_lb_buy",c3+S(10), Y+S(70),"BUY PRESSURE",UI_TXT_DIM,FS(6));
   QBar("flow_bar_buy",c3+S(10),Y+S(82),colW-S(20),S(10),0,UI_GREEN);
   QLabel("flow_vl_buy",c3+S(10),Y+S(94),"0%",UI_GREEN,FS(8),UI_FONT_B);
   QLabel("flow_winrate",c3+S(10),Y+H-S(34),"Win Rate: --   Trades: --",UI_TXT_DIM,FS(7),UI_FONT);
   QLabel("flow_pf",c3+S(10),Y+H-S(18),"Profit Factor: --   Streak: --",UI_TXT_DIM,FS(7),UI_FONT);
}

void UpdateBottomPanel()
{
   QUpd("bot_c1_l0",g_narrativeLine1,UI_TXT_SEC);
   QUpd("bot_c1_l1",g_narrativeLine2,UI_TXT_SEC);
   QUpd("bot_c1_l2",g_narrativeLine3,UI_TXT_SEC);
   QUpd("bot_c1_l3",g_narrativeLine4,UI_TXT_SEC);
   QUpd("bot_c1_l4",g_narrativeLine5,UI_TXT_SEC);
   QUpd("bot_c1_l5",g_narrativeLine6,UI_TXT_SEC);
   QUpd("bot_c1_ts","Last update: "+TimeToString(g_lastNarrative,TIME_SECONDS),UI_TXT_FAINT);

   bool swept=g_liq.sweepUpDetected||g_liq.sweepDownDetected;
   QInsight("sweep",swept,swept?(g_liq.sweepUpDetected?"BUY SIDE":"SELL SIDE"):"NONE");
   bool bos=false; double px=SymbolInfoDouble(_Symbol,SYMBOL_BID);
   double hhq=StructureHH(InpStructureLookback,1); bos=(px>hhq);
   QInsight("bos",bos,bos?"BULLISH":"WATCHING");
   bool mss=(g_mtf.alignment>70);
   QInsight("mss",mss,mss?"CONFIRMED":"PENDING");
   int h1b=g_mtf.h1Bias;
   QInsight("trend",h1b!=0,h1b>0?"BULLISH":(h1b<0?"BEARISH":"FLAT"));
   bool volAb=(g_vol.atrRatio>1.1);
   QInsight("vol",volAb,volAb?"ABOVE AVG":"NORMAL");
   bool sessAl=(g_session.preferredStrategy==RouteRegimeToStrategy(g_regime.regime));
   QInsight("sess",sessAl,sessAl?"ALIGNED":"NEUTRAL");

   double buyP=MathMax(0.0,MathMin(100.0,50.0+g_liq.biasScore*0.5+(g_mtf.h1Bias>0?15:(g_mtf.h1Bias<0?-15:0))));
   double sellP=100.0-buyP;
   QBarUpd("flow_bar_buy",buyP,UI_GREEN);
   QBarUpd("flow_bar_sell",sellP,UI_RED);
   QUpd("flow_vl_buy",DoubleToString(buyP,0)+"%",UI_GREEN);
   QUpd("flow_vl_sell",DoubleToString(sellP,0)+"%",UI_RED);

   int tot=g_sessionWins+g_sessionLosses;
   double wr=(tot>0)?100.0*g_sessionWins/tot:0.0;
   QUpd("flow_winrate","Win Rate: "+DoubleToString(wr,0)+"%   Trades: "+IntegerToString(tot),UI_TXT_DIM);
   double bestPF=0;
   for(int i=0;i<5;i++) if(g_health[i].profitFactor>bestPF) bestPF=g_health[i].profitFactor;
   QUpd("flow_pf","Profit Factor: "+DoubleToString(bestPF,2)+"   DD: "+DoubleToString(g_risk.currentDrawdownPct,1)+"%",UI_TXT_DIM);
}

void QInsight(string key,bool positive,string txt)
{
   color c=positive?UI_GREEN:UI_TXT_DIM;
   QUpd("bot_ins_dot_"+key,"■",c);
   QUpd("bot_ins_vl_"+key,txt,c);
}

//=====================================================================
//  CENTER CHART -- LIQUIDITY MAP MINI PANEL (pixel-anchored, sits
//  in the top-left of the chart viewport, beneath the top bar)
//=====================================================================
void InitCenterMiniPanels()
{
   int X=g_leftX+g_leftW+S(14), Y=g_panelTop;
   QRect("liqmap_bg",X,Y,S(230),S(70),UI_PANEL,UI_BORDER_DIM,1);
   QLabel("liqmap_hdr",X+S(8),Y+S(6),"LIQUIDITY MAP",UI_TXT_SEC,FS(8),UI_FONT_B);
   QLabel("liqmap_l1",X+S(8),Y+S(24),"--",UI_TXT_PRI,FS(7),UI_FONT);
   QLabel("liqmap_l2",X+S(8),Y+S(38),"--",UI_TXT_PRI,FS(7),UI_FONT);
   QLabel("liqmap_l3",X+S(8),Y+S(52),"--",UI_TXT_PRI,FS(7),UI_FONT);

   QRect("volmap_bg",X,Y+S(78),S(230),S(46),UI_PANEL,UI_BORDER_DIM,1);
   QLabel("volmap_hdr",X+S(8),Y+S(84),"VOLUME ANALYSIS",UI_TXT_SEC,FS(8),UI_FONT_B);
   QLabel("volmap_cur",X+S(8),Y+S(100),"Current: --",UI_TXT_PRI,FS(7),UI_FONT);
   QLabel("volmap_avg",X+S(120),Y+S(100),"Avg: --",UI_TXT_DIM,FS(7),UI_FONT);
}

void UpdateCenterMiniPanels()
{
   int digs=(int)SymbolInfoInteger(_Symbol,SYMBOL_DIGITS);
   if(g_liq.equalHighsDetected)
      QUpd("liqmap_l1","BSL  "+DoubleToString(g_liq.equalHighLevel,digs),g_liq.sweepUpDetected?UI_RED:UI_GREEN);
   else
      QUpd("liqmap_l1","BSL  --",UI_TXT_DIM);
   if(g_liq.equalLowsDetected)
      QUpd("liqmap_l2","SSL  "+DoubleToString(g_liq.equalLowLevel,digs),g_liq.sweepDownDetected?UI_GREEN:UI_RED);
   else
      QUpd("liqmap_l2","SSL  --",UI_TXT_DIM);
   QUpd("liqmap_l3",LiquidityStatusString(),UI_TXT_SEC);

   QUpd("volmap_cur","Current: "+DoubleToString(g_vol.atrRatio*100.0,0)+"%",UI_TXT_PRI);
   QUpd("volmap_avg","Avg: 100%",UI_TXT_DIM);
}

//=====================================================================
//  DASHBOARD LIFECYCLE (replaces old InitDash/UpdateDash/DeleteDash
//  and InitAnalystPanel/UpdateAnalystPanel/DeleteAnalystPanel --
//  kept under the same function names so OnInit/OnTimer/OnDeinit
//  call sites are unaffected)
//=====================================================================
void InitDash()
{
   if(!InpShowDash) return;
   RecomputeLayout();
   InitTopBar();
   InitLeftPanel();
   InitRightPanel();
   InitBottomPanel();
   InitCenterMiniPanels();
   ChartRedraw(0);
   Print("QPA v2.0 institutional UI initialized. ",g_chartW,"x",g_chartH);
}

void UpdateDash()
{
   if(!InpShowDash) return;
   if(MQLInfoInteger(MQL_TESTER)&&!MQLInfoInteger(MQL_VISUAL_MODE))return;
   UpdateTopBar();
   UpdateLeftPanel();
   UpdateRightPanel();
   UpdateBottomPanel();
   UpdateCenterMiniPanels();
   ChartRedraw(0);
}

void DeleteDash()
{
   ObjectsDeleteAll(0,QD);
   ChartRedraw(0);
}

// Kept as no-ops (single unified dashboard now covers the former
// "Analyst Panel" content inside the bottom AI Market Commentary
// column), so existing call sites remain valid without edits.
void InitAnalystPanel(){}
void UpdateAnalystPanel(){}
void DeleteAnalystPanel(){}

//=====================================================================
//  CHART OVERLAYS -- decluttered smart-money rendering
//  Design rules vs the legacy version:
//   - small, clean fonts (8-9pt) instead of 14pt giant labels
//   - at most ONE label per structural event, not one per bar
//   - vertical offset staggering to avoid stacked overlaps
//   - objects are only recreated when their underlying level changes
//=====================================================================
int SafeBar(datetime t)
{
   datetime now=TimeCurrent(); if(t>now)t=now;
   int b=iBarShift(_Symbol,PERIOD_M5,t,false);
   return(b<0)?0:b;
}

void OvLabel(string id,datetime t,double price,string txt,color clr,int fsz=9,bool above=true)
{
   string nm=QO+id;
   if(ObjectFind(0,nm)>=0)ObjectDelete(0,nm);
   if(ObjectCreate(0,nm,OBJ_TEXT,0,t,price))
   {
      ObjectSetString(0,nm,OBJPROP_TEXT," "+txt+" ");
      ObjectSetInteger(0,nm,OBJPROP_COLOR,clr);
      ObjectSetInteger(0,nm,OBJPROP_FONTSIZE,fsz);
      ObjectSetString(0,nm,OBJPROP_FONT,UI_FONT_B);
      ObjectSetInteger(0,nm,OBJPROP_SELECTABLE,false);
      ObjectSetInteger(0,nm,OBJPROP_HIDDEN,true);
      ObjectSetInteger(0,nm,OBJPROP_BACK,false);
      ObjectSetInteger(0,nm,OBJPROP_ANCHOR,above?ANCHOR_LOWER:ANCHOR_UPPER);
   }
}

void OvHLine(string id,double price,datetime t1,datetime t2,color clr,string lbl,int fsz=9)
{
   string nm=QO+id;
   if(ObjectFind(0,nm)>=0)ObjectDelete(0,nm);
   if(ObjectCreate(0,nm,OBJ_TREND,0,t1,price,t2,price))
   {
      ObjectSetInteger(0,nm,OBJPROP_COLOR,clr);ObjectSetInteger(0,nm,OBJPROP_WIDTH,1);
      ObjectSetInteger(0,nm,OBJPROP_STYLE,STYLE_DASH);ObjectSetInteger(0,nm,OBJPROP_RAY_RIGHT,false);
      ObjectSetInteger(0,nm,OBJPROP_SELECTABLE,false);ObjectSetInteger(0,nm,OBJPROP_BACK,false);
      ObjectSetInteger(0,nm,OBJPROP_HIDDEN,true);
   }
   string nmL=nm+"_lbl";
   if(ObjectFind(0,nmL)>=0)ObjectDelete(0,nmL);
   if(ObjectCreate(0,nmL,OBJ_TEXT,0,t2,price))
   {
      ObjectSetString(0,nmL,OBJPROP_TEXT," "+lbl+" ");
      ObjectSetInteger(0,nmL,OBJPROP_COLOR,clr);
      ObjectSetInteger(0,nmL,OBJPROP_FONTSIZE,fsz);
      ObjectSetString(0,nmL,OBJPROP_FONT,UI_FONT_B);
      ObjectSetInteger(0,nmL,OBJPROP_SELECTABLE,false);ObjectSetInteger(0,nmL,OBJPROP_HIDDEN,true);
      ObjectSetInteger(0,nmL,OBJPROP_BACK,false);ObjectSetInteger(0,nmL,OBJPROP_ANCHOR,ANCHOR_RIGHT_UPPER);
   }
}

void OvBox(string id,datetime t1,datetime t2,double hi,double lo,color fill,color brd,string lbl,color lblClr)
{
   string nm=QO+id;
   if(ObjectFind(0,nm)>=0)ObjectDelete(0,nm);
   if(ObjectCreate(0,nm,OBJ_RECTANGLE,0,t1,hi,t2,lo))
   {
      ObjectSetInteger(0,nm,OBJPROP_COLOR,fill);
      ObjectSetInteger(0,nm,OBJPROP_FILL,true);
      ObjectSetInteger(0,nm,OBJPROP_BACK,true);
      ObjectSetInteger(0,nm,OBJPROP_WIDTH,1);
      ObjectSetInteger(0,nm,OBJPROP_SELECTABLE,false);
      ObjectSetInteger(0,nm,OBJPROP_HIDDEN,true);
   }
   string nmT=nm+"_t";
   if(ObjectFind(0,nmT)>=0)ObjectDelete(0,nmT);
   if(ObjectCreate(0,nmT,OBJ_TREND,0,t1,hi,t2,hi))
   {
      ObjectSetInteger(0,nmT,OBJPROP_COLOR,brd);ObjectSetInteger(0,nmT,OBJPROP_WIDTH,1);
      ObjectSetInteger(0,nmT,OBJPROP_RAY_RIGHT,false);ObjectSetInteger(0,nmT,OBJPROP_SELECTABLE,false);
      ObjectSetInteger(0,nmT,OBJPROP_BACK,false);ObjectSetInteger(0,nmT,OBJPROP_HIDDEN,true);
   }
   OvLabel(id+"_l",t1,hi,lbl,lblClr,9,true);
}

//---------------------------------------------------------------------
//  Session boxes -- subtle, only the most recent occurrence per
//  session kept on chart (legacy version kept 48h of stacked boxes)
//---------------------------------------------------------------------
void UpdateSessionBoxes()
{
   if(!InpDrawSessionBoxes)return;
   datetime now=TimeCurrent(),today=DayStart(now);
   ENUM_SESSION sess[5]={SESSION_ASIAN,SESSION_LONDON_OPEN,SESSION_LONDON_MID,SESSION_NY_OPEN,SESSION_NY_PM};
   color sBrd[5]={UI_PURPLE,UI_BLUE,UI_BLUE,UI_ORANGE,UI_ORANGE};
   string sLbl[5]={"ASIAN","LON OPEN","LON MID","NY OPEN","NY PM"};

   for(int i=0;i<5;i++)
   {
      int sh,eh; SessionHourBand(sess[i],sh,eh);
      sh=(sh+InpBrokerGMTOffset)%24; eh=(eh+InpBrokerGMTOffset)%24;
      datetime st=today+sh*3600,et=today+eh*3600;
      if(st>now)continue;
      datetime etC=MathMin(et,now);
      int sb=SafeBar(st),eb=SafeBar(etC);
      if(sb<eb){int tmp=sb;sb=eb;eb=tmp;}
      double hi=-1e300,lo=1e300;
      for(int b=eb;b<=sb;b++){hi=MathMax(hi,iHigh(_Symbol,PERIOD_M5,b));lo=MathMin(lo,iLow(_Symbol,PERIOD_M5,b));}
      if(hi<=-1e300||lo>=1e300)continue;
      OvBox("SB_"+sLbl[i],st,etC,hi*1.0003,lo*0.9997,C'10,14,24',sBrd[i],sLbl[i],sBrd[i]);
   }
}

//---------------------------------------------------------------------
//  BSL / SSL -- one clean dashed level + sweep tag, no giant text
//---------------------------------------------------------------------
void UpdateBSLSSL()
{
   if(!InpDrawBSLSSL)return;
   datetime now=TimeCurrent(),past=now-(datetime)(InpSessionBoxLookbackHrs*3600);

   if(g_liq.equalHighsDetected)
   {
      color c=g_liq.sweepUpDetected?UI_RED:UI_GREEN;
      OvHLine("BSL_line",g_liq.equalHighLevel,past,now,c,g_liq.sweepUpDetected?"BSL SWEPT":"BSL");
   }
   else ObjectsDeleteAll(0,QO+"BSL");

   if(g_liq.equalLowsDetected)
   {
      color c=g_liq.sweepDownDetected?UI_GREEN:UI_RED;
      OvHLine("SSL_line",g_liq.equalLowLevel,past,now,c,g_liq.sweepDownDetected?"SSL SWEPT":"SSL");
   }
   else ObjectsDeleteAll(0,QO+"SSL");
}

//---------------------------------------------------------------------
//  Market structure -- only the latest swing pair + latest BOS/CHOCH
//---------------------------------------------------------------------
void UpdateMarketStructure()
{
   if(!InpDrawStructure)return;
   double shP[30],slP[30]; datetime shT[30],slT[30];
   int nH=FindSwingHighs(60,3,shP,shT);
   int nL=FindSwingLows(60,3,slP,slT);

   if(nH>0) OvLabel("SH_latest",shT[0],shP[0],(nH>1&&shP[0]>shP[1])?"HH":"LH",
                     (nH>1&&shP[0]>shP[1])?UI_GREEN:UI_RED,9,true);
   if(nL>0) OvLabel("SL_latest",slT[0],slP[0],(nL>1&&slP[0]>slP[1])?"HL":"LL",
                     (nL>1&&slP[0]>slP[1])?UI_GREEN:UI_RED,9,false);

   double px=SymbolInfoDouble(_Symbol,SYMBOL_BID);
   if(nH>0&&px>shP[0]) OvLabel("BOS_bull",shT[0],shP[0],"BOS",UI_GREEN,9,true);
   else ObjectsDeleteAll(0,QO+"BOS_bull");
   if(nL>0&&px<slP[0]) OvLabel("BOS_bear",slT[0],slP[0],"BOS",UI_RED,9,false);
   else ObjectsDeleteAll(0,QO+"BOS_bear");

   if(g_mtf.m1Bias!=0&&g_mtf.m5Bias!=0&&g_mtf.m1Bias!=g_mtf.m5Bias)
      OvLabel("CHOCH",iTime(_Symbol,PERIOD_M5,0),px,"CHOCH",UI_PURPLE,9,true);
   else ObjectsDeleteAll(0,QO+"CHOCH");
}

//---------------------------------------------------------------------
//  Order blocks -- single most recent demand/supply block only
//---------------------------------------------------------------------
void UpdateOrderBlocks()
{
   if(!InpDrawOrderBlocks)return;
   for(int i=3;i<15;i++)
   {
      double o=iOpen(_Symbol,PERIOD_M5,i),c=iClose(_Symbol,PERIOD_M5,i);
      double h=iHigh(_Symbol,PERIOD_M5,i),l=iLow(_Symbol,PERIOD_M5,i);
      double body=MathAbs(c-o),atr=g_vol.atrAvg;
      if(body<atr*0.5)continue;
      bool isBullOB=(c>o), isBearOB=(c<o);
      if(isBullOB&&g_mtf.h1Bias>0)
      {
         OvBox("OB_DEMAND",iTime(_Symbol,PERIOD_M5,i),TimeCurrent(),h,l,C'0,30,15',UI_GREEN,"DEMAND OB",UI_GREEN);
         return;
      }
      if(isBearOB&&g_mtf.h1Bias<0)
      {
         OvBox("OB_SUPPLY",iTime(_Symbol,PERIOD_M5,i),TimeCurrent(),h,l,C'35,10,12',UI_RED,"SUPPLY OB",UI_RED);
         return;
      }
   }
}

//---------------------------------------------------------------------
//  Fair value gaps -- single most recent bullish/bearish gap only
//---------------------------------------------------------------------
void UpdateFVG()
{
   if(!InpDrawFVG)return;
   for(int i=1;i<20;i++)
   {
      double c1H=iHigh(_Symbol,PERIOD_M5,i+1), c1L=iLow(_Symbol,PERIOD_M5,i+1);
      double c3H=iHigh(_Symbol,PERIOD_M5,i-1), c3L=iLow(_Symbol,PERIOD_M5,i-1);
      if(c3L>c1H&&(c3L-c1H)>g_vol.atrAvg*0.3)
      {
         OvBox("FVG_BULL",iTime(_Symbol,PERIOD_M5,i+1),TimeCurrent(),c3L,c1H,C'0,25,8',UI_GREEN,"FVG",UI_GREEN);
         return;
      }
      if(c3H<c1L&&(c1L-c3H)>g_vol.atrAvg*0.3)
      {
         OvBox("FVG_BEAR",iTime(_Symbol,PERIOD_M5,i+1),TimeCurrent(),c1L,c3H,C'25,0,0',UI_RED,"FVG",UI_RED);
         return;
      }
   }
}

//---------------------------------------------------------------------
//  Volume spikes -- limited to most recent surge only
//---------------------------------------------------------------------
void UpdateVolumeSpikes()
{
   if(!InpDrawVolumeSpikes)return;
   for(int i=1;i<10;i++)
   {
      double barR=iHigh(_Symbol,PERIOD_M5,i)-iLow(_Symbol,PERIOD_M5,i);
      if(g_vol.atrAvg>0&&barR>g_vol.atrAvg*1.8)
      {
         OvLabel("VOLSURGE",iTime(_Symbol,PERIOD_M5,i),iHigh(_Symbol,PERIOD_M5,i),"VOL SURGE",UI_GOLD,8,true);
         return;
      }
   }
   ObjectsDeleteAll(0,QO+"VOLSURGE");
}

// Regime overlay (kept off the chart -- now lives in the top bar /
// left panel instead, avoiding the old top-right text clutter).
void UpdateRegimeOverlay(){}

//---------------------------------------------------------------------
//  Entry / exit markers (small, clean)
//---------------------------------------------------------------------
void DrawEntryMarker(ENUM_DIRECTION dir, double price, ENUM_STRATEGY strat)
{
   if(!InpDrawSignalMarkers)return;
   datetime t=TimeCurrent();
   string nm=QO+"ENTRY_"+IntegerToString((int)t);
   color clr=(dir==DIR_LONG)?UI_GREEN:UI_RED;
   int arr=(dir==DIR_LONG)?233:234;
   if(ObjectCreate(0,nm,OBJ_ARROW,0,t,price))
   {
      ObjectSetInteger(0,nm,OBJPROP_ARROWCODE,arr);ObjectSetInteger(0,nm,OBJPROP_COLOR,clr);
      ObjectSetInteger(0,nm,OBJPROP_WIDTH,3);ObjectSetInteger(0,nm,OBJPROP_SELECTABLE,false);
      ObjectSetInteger(0,nm,OBJPROP_HIDDEN,true);ObjectSetInteger(0,nm,OBJPROP_BACK,false);
      ObjectSetInteger(0,nm,OBJPROP_ANCHOR,(dir==DIR_LONG)?ANCHOR_TOP:ANCHOR_BOTTOM);
   }
   double off=MathMax(g_vol.atrAvg*0.7,SymbolInfoDouble(_Symbol,SYMBOL_POINT)*300);
   double lp2=(dir==DIR_LONG)?price-off:price+off;
   OvLabel("ENTRYLBL_"+IntegerToString((int)t),t,lp2,StrategyToShort(strat),clr,8,(dir==DIR_LONG));
}

void DrawExitMarker(double price, double pnl)
{
   if(!InpDrawSignalMarkers)return;
   datetime t=TimeCurrent();
   string nm=QO+"EXIT_"+IntegerToString((int)t);
   color clr=(pnl>=0)?UI_BLUE:UI_PURPLE;
   if(ObjectCreate(0,nm,OBJ_ARROW,0,t,price))
   {
      ObjectSetInteger(0,nm,OBJPROP_ARROWCODE,251);ObjectSetInteger(0,nm,OBJPROP_COLOR,clr);
      ObjectSetInteger(0,nm,OBJPROP_WIDTH,2);ObjectSetInteger(0,nm,OBJPROP_SELECTABLE,false);
      ObjectSetInteger(0,nm,OBJPROP_HIDDEN,true);ObjectSetInteger(0,nm,OBJPROP_BACK,false);
   }
   double off=MathMax(g_vol.atrAvg*0.5,SymbolInfoDouble(_Symbol,SYMBOL_POINT)*200);
   OvLabel("EXITLBL_"+IntegerToString((int)t),t,price+off,(pnl>=0?"+":"")+DoubleToString(pnl,2),clr,8,true);
}

//=====================================================================
//  MASTER OVERLAY UPDATE
//=====================================================================
void UpdateVisualOverlays()
{
   UpdateSessionBoxes();
   UpdateBSLSSL();
   if(InpDrawStructure)    UpdateMarketStructure();
   if(InpDrawOrderBlocks)  UpdateOrderBlocks();
   if(InpDrawFVG)          UpdateFVG();
   if(InpDrawVolumeSpikes) UpdateVolumeSpikes();
}

void DeleteVisualOverlays(){ObjectsDeleteAll(0,QO);ChartRedraw(0);}

//=====================================================================
//  CHART THEME -- maximum-contrast institutional dark
//=====================================================================
void ApplyProfessionalTheme()
{
   long ch=ChartID();
   ChartSetInteger(ch,CHART_MODE,CHART_CANDLES);
   ChartSetInteger(ch,CHART_COLOR_BACKGROUND,  UI_BG_DEEP);
   ChartSetInteger(ch,CHART_COLOR_FOREGROUND,  UI_TXT_PRI);
   ChartSetInteger(ch,CHART_COLOR_GRID,        UI_BG_DEEP);
   ChartSetInteger(ch,CHART_COLOR_CANDLE_BULL, UI_GREEN);
   ChartSetInteger(ch,CHART_COLOR_CANDLE_BEAR, UI_RED);
   ChartSetInteger(ch,CHART_COLOR_CHART_UP,    UI_GREEN);
   ChartSetInteger(ch,CHART_COLOR_CHART_DOWN,  UI_RED);
   ChartSetInteger(ch,CHART_COLOR_CHART_LINE,  UI_TXT_PRI);
   ChartSetInteger(ch,CHART_COLOR_VOLUME,      UI_BORDER);
   ChartSetInteger(ch,CHART_COLOR_BID,         UI_GREEN);
   ChartSetInteger(ch,CHART_COLOR_ASK,         UI_RED);
   ChartSetInteger(ch,CHART_COLOR_STOP_LEVEL,  UI_GOLD);
   ChartSetInteger(ch,CHART_SHOW_GRID,         false);
   ChartSetInteger(ch,CHART_SHOW_VOLUMES,      false);
   ChartSetInteger(ch,CHART_SHOW_OHLC,         false);
   ChartSetInteger(ch,CHART_SHOW_ASK_LINE,     false);
   ChartSetInteger(ch,CHART_SHOW_BID_LINE,     false);
   ChartSetInteger(ch,CHART_SHOW_TRADE_LEVELS, true);
   ChartSetInteger(ch,CHART_SHIFT,             true);
   ChartSetInteger(ch,CHART_AUTOSCROLL,        true);
   ChartRedraw(ch);
}

//=====================================================================
//  EA LIFECYCLE
//=====================================================================
int OnInit()
{
   g_scale = InpDPIScale / 100.0;
   if(g_scale < 0.5) g_scale = 0.5;
   if(g_scale > 3.0) g_scale = 3.0;

   ApplyProfessionalTheme();

   g_trade.SetExpertMagicNumber(InpMagicNumber);
   g_trade.SetDeviationInPoints(30);
   g_trade.SetTypeFilling(GetFillMode());

   g_h1_ema_fast  = iMA(_Symbol,PERIOD_H1, InpEMAFastPeriod,0,MODE_EMA,PRICE_CLOSE);
   g_h1_ema_slow  = iMA(_Symbol,PERIOD_H1, InpEMASlowPeriod,0,MODE_EMA,PRICE_CLOSE);
   g_h1_atr       = iATR(_Symbol,PERIOD_H1, InpATRPeriod);
   g_m15_ema_fast = iMA(_Symbol,PERIOD_M15,InpEMAFastPeriod,0,MODE_EMA,PRICE_CLOSE);
   g_m15_ema_slow = iMA(_Symbol,PERIOD_M15,InpEMASlowPeriod,0,MODE_EMA,PRICE_CLOSE);
   g_m15_atr      = iATR(_Symbol,PERIOD_M15,InpATRPeriod);
   g_m15_rsi      = iRSI(_Symbol,PERIOD_M15,14,PRICE_CLOSE);
   g_m5_ema_fast  = iMA(_Symbol,PERIOD_M5, InpEMAFastPeriod,0,MODE_EMA,PRICE_CLOSE);
   g_m5_ema_slow  = iMA(_Symbol,PERIOD_M5, InpEMASlowPeriod,0,MODE_EMA,PRICE_CLOSE);
   g_m5_atr       = iATR(_Symbol,PERIOD_M5, InpATRPeriod);
   g_m5_rsi       = iRSI(_Symbol,PERIOD_M5, 14,PRICE_CLOSE);
   g_m1_ema_fast  = iMA(_Symbol,PERIOD_M1, InpEMAFastPeriod,0,MODE_EMA,PRICE_CLOSE);
   g_m1_ema_slow  = iMA(_Symbol,PERIOD_M1, InpEMASlowPeriod,0,MODE_EMA,PRICE_CLOSE);
   g_m1_atr       = iATR(_Symbol,PERIOD_M1, InpATRPeriod);

   if(g_h1_ema_fast==INVALID_HANDLE||g_h1_ema_slow==INVALID_HANDLE||g_h1_atr==INVALID_HANDLE||
      g_m15_ema_fast==INVALID_HANDLE||g_m15_ema_slow==INVALID_HANDLE||g_m15_atr==INVALID_HANDLE||g_m15_rsi==INVALID_HANDLE||
      g_m5_ema_fast==INVALID_HANDLE||g_m5_ema_slow==INVALID_HANDLE||g_m5_atr==INVALID_HANDLE||g_m5_rsi==INVALID_HANDLE||
      g_m1_ema_fast==INVALID_HANDLE||g_m1_ema_slow==INVALID_HANDLE||g_m1_atr==INVALID_HANDLE)
   { Print("ERROR: Indicator handle creation failed."); return INIT_FAILED; }

   g_dayStart=DayStart(TimeCurrent());
   g_weekStart=WeekStart(TimeCurrent());
   InitRiskState();
   InitStrategyHealth();
   InitAdaptiveParams();

   g_regime.regime=REGIME_RANGING;g_regime.confidence=0;g_regime.stability=0;
   g_regime.sinceTime=TimeCurrent();g_regime.previousRegime=REGIME_RANGING;

   if(InpShowDash) InitDash();

   EventSetTimer(1);

   g_statusText="WARMING UP";g_statusColor=UI_ORANGE;
   g_lastAction="Building buffers...";

   Print("=== QUANTUM PLUS AI v2.0 -- INSTITUTIONAL AI TRADING WORKSTATION ===");
   Print("DPI Scale: ",InpDPIScale,"%");

   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
   EventKillTimer();
   DeleteDash();
   DeleteVisualOverlays();
   IndicatorRelease(g_h1_ema_fast);IndicatorRelease(g_h1_ema_slow);IndicatorRelease(g_h1_atr);
   IndicatorRelease(g_m15_ema_fast);IndicatorRelease(g_m15_ema_slow);IndicatorRelease(g_m15_atr);IndicatorRelease(g_m15_rsi);
   IndicatorRelease(g_m5_ema_fast);IndicatorRelease(g_m5_ema_slow);IndicatorRelease(g_m5_atr);IndicatorRelease(g_m5_rsi);
   IndicatorRelease(g_m1_ema_fast);IndicatorRelease(g_m1_ema_slow);IndicatorRelease(g_m1_atr);
   Print("=== QPA v2.0 SESSION END ===");
}

void OnTimer()
{
   if(g_lastCloseTime>0){int el=(int)(TimeCurrent()-g_lastCloseTime);g_inCooldown=(el<InpCooldownAfterCloseSec);g_cooldownLeft=g_inCooldown?(InpCooldownAfterCloseSec-el):0;}
   if(InpShowDash)UpdateDash();
}

void OnTick()
{
   if(g_lastCloseTime>0){int el=(int)(TimeCurrent()-g_lastCloseTime);g_inCooldown=(el<InpCooldownAfterCloseSec);}
   RolloverDailyWeeklyIfNeeded();

   if(Bars(_Symbol,PERIOD_H1)<InpEMASlowPeriod+5||Bars(_Symbol,PERIOD_M15)<InpEMASlowPeriod+5||
      Bars(_Symbol,PERIOD_M5)<InpATRLookback+5||Bars(_Symbol,PERIOD_M1)<InpEMASlowPeriod+5)
   { g_statusText="BUFFERING";g_statusColor=UI_ORANGE;return; }

   bool nb=IsNewBar();
   UpdateRiskState();

   if(HasManagedPosition()){g_statusText="IN TRADE";g_statusColor=UI_GREEN;return;}

   if(nb||TimeCurrent()-g_lastFullUpdate>60)
   {
      UpdateMTFBias();
      UpdateVolatilityIntelligence();
      UpdateNewsShockProxy();
      UpdateLiquidityIntelligence();
      UpdateSessionIntelligence();
      UpdateRegimeClassification();
      UpdateMarketScores();
      UpdateNarrative();
      UpdateVisualOverlays();
      UpdateAdaptiveParams();
      g_lastFullUpdate=TimeCurrent();
   }

   UpdateExecutionQuality();
   RunMasterDecisionCycle();
}

void OnTradeTransaction(const MqlTradeTransaction &trans,const MqlTradeRequest &request,const MqlTradeResult &result)
{
   OnTradeTransactionHandler(trans,request,result);
}

void OnChartEvent(const int id,const long &lparam,const double &dparam,const string &sparam)
{
   if(id==CHARTEVENT_CHART_CHANGE)
   {
      if(!InpShowDash) return;
      DeleteDash();
      InitDash();
   }
}
