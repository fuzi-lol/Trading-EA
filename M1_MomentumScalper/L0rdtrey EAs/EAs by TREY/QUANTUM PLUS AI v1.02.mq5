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
   if(g_mtf.alignment<55){s.reason="MTF align insufficient";return s;}
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
      default:                     return STRAT_NONE;
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
void InitAdaptiveParams(){g_adaptiveRegimeConfThreshold=InpMinRegimeConfidence;g_adaptiveExecScoreThreshold=InpMinExecutionScore;}
void UpdateAdaptiveParams()
{
   if(!InpEnableAdaptiveParams)return;
   static datetime lb=0;datetime cb=iTime(_Symbol,PERIOD_M5,0);if(cb==lb)return;lb=cb;
   double rLo=InpMinRegimeConfidence*(1.0-InpAdaptiveBoundPct/100.0),rHi=InpMinRegimeConfidence*(1.0+InpAdaptiveBoundPct/100.0);
   double eLo=InpMinExecutionScore*(1.0-InpAdaptiveBoundPct/100.0),eHi=InpMinExecutionScore*(1.0+InpAdaptiveBoundPct/100.0);
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
//  ===  DASHBOARD RENDERING SYSTEM  ===
//  High-contrast, DPI-aware, flicker-reduced
//=====================================================================

// Object prefix + name builder
void DelObj(string nm){if(ObjectFind(0,D+nm)>=0)ObjectDelete(0,D+nm);}

// Create/update rectangle label (background panel)
void DRect(string nm, int x, int y, int w, int h, color bg, color brd=clrNONE, int bw=1)
{
   string n=D+nm;
   if(ObjectFind(0,n)<0) ObjectCreate(0,n,OBJ_RECTANGLE_LABEL,0,0,0);
   ObjectSetInteger(0,n,OBJPROP_CORNER,   CORNER_LEFT_UPPER);
   ObjectSetInteger(0,n,OBJPROP_XDISTANCE,x);
   ObjectSetInteger(0,n,OBJPROP_YDISTANCE,y);
   ObjectSetInteger(0,n,OBJPROP_XSIZE,   w);
   ObjectSetInteger(0,n,OBJPROP_YSIZE,   h);
   ObjectSetInteger(0,n,OBJPROP_BGCOLOR, bg);
   ObjectSetInteger(0,n,OBJPROP_SELECTABLE,false);
   ObjectSetInteger(0,n,OBJPROP_HIDDEN,  false);
   ObjectSetInteger(0,n,OBJPROP_ZORDER,  0);
   if(brd!=clrNONE){ObjectSetInteger(0,n,OBJPROP_BORDER_TYPE,BORDER_FLAT);ObjectSetInteger(0,n,OBJPROP_COLOR,brd);ObjectSetInteger(0,n,OBJPROP_WIDTH,bw);}
   else{ObjectSetInteger(0,n,OBJPROP_BORDER_TYPE,BORDER_RAISED);ObjectSetInteger(0,n,OBJPROP_COLOR,bg);}
}

// Create/update text label — always on top (zorder=2)
void DLabel(string nm, int x, int y, string txt, color clr, int fsz, string fnt="Segoe UI Bold")
{
   string n=D+nm;
   if(ObjectFind(0,n)<0) ObjectCreate(0,n,OBJ_LABEL,0,0,0);
   ObjectSetInteger(0,n,OBJPROP_CORNER,   CORNER_LEFT_UPPER);
   ObjectSetInteger(0,n,OBJPROP_XDISTANCE,x);
   ObjectSetInteger(0,n,OBJPROP_YDISTANCE,y);
   ObjectSetString (0,n,OBJPROP_TEXT,     txt);
   ObjectSetInteger(0,n,OBJPROP_COLOR,    clr);
   ObjectSetInteger(0,n,OBJPROP_FONTSIZE, fsz);
   ObjectSetString (0,n,OBJPROP_FONT,     fnt);
   ObjectSetInteger(0,n,OBJPROP_SELECTABLE,false);
   ObjectSetInteger(0,n,OBJPROP_HIDDEN,   false);
   ObjectSetInteger(0,n,OBJPROP_ZORDER,   2);
}

// Update existing label text + color only (no re-creation = anti-flicker)
void DUpdate(string nm, string txt, color clr=C_WHITE_PURE)
{
   string n=D+nm;
   if(ObjectFind(0,n)>=0){ObjectSetString(0,n,OBJPROP_TEXT,txt);ObjectSetInteger(0,n,OBJPROP_COLOR,clr);}
}

void DUpdateBG(string nm, color bg)
{
   string n=D+nm;
   if(ObjectFind(0,n)>=0) ObjectSetInteger(0,n,OBJPROP_BGCOLOR,bg);
}

// Score bar: draws background + foreground fill
void DScoreBar(string nm, int x, int y, int w, int h, double pct, color fg)
{
   DRect(nm+"_bg",x,y,w,h,C_BAR_EMPTY,C_PANEL_BRD2,1);
   int fw=(int)MathMax(2,MathRound(MathMax(0.0,MathMin(100.0,pct))/100.0*(w-2)));
   DRect(nm+"_fg",x+1,y+1,fw,h-2,fg,clrNONE);
}
void DScoreBarUpdate(string nm, double pct, color fg)
{
   string nb=D+nm+"_bg",nf=D+nm+"_fg";
   if(ObjectFind(0,nb)<0)return;
   int w=(int)ObjectGetInteger(0,nb,OBJPROP_XSIZE);
   int fw=(int)MathMax(2,MathRound(MathMax(0.0,MathMin(100.0,pct))/100.0*(w-2)));
   if(ObjectFind(0,nf)>=0){ObjectSetInteger(0,nf,OBJPROP_XSIZE,fw);ObjectSetInteger(0,nf,OBJPROP_BGCOLOR,fg);}
}

color ScoreColor(double v)
{
   if(v>=80)return C_GREEN_BRIGHT;
   if(v>=60)return C_ORANGE_BRIGHT;
   return C_RED_BRIGHT;
}

// Separator line
void DSep(string nm, int x, int y, int w){ DRect(nm,x,y,w,1,C_PANEL_BRD2,clrNONE); }

//=====================================================================
//  DASHBOARD LAYOUT BUILDER
//=====================================================================
// We accumulate Y positions as we go so sections stack cleanly.
// All coordinates DPI-scaled via S().

void InitDash()
{
   if(!InpShowDash) return;

   int X  = S(InpDashX);
   int Y  = S(InpDashY);
   int W  = S(InpDashWidth);
   int y  = Y;
   int lp = S(10);       // left pad
   int rp = W - S(10);   // right-pad x
   int IW = W - S(4);    // inner width

   // == OUTER FRAME ==
   DRect("fr_outer",X,Y,W,S(900),C_PANEL_BG,C_CYAN_BRIGHT,2);
   y += S(2);

   // == HEADER BAR ==
   DRect("hdr",X+S(2),y,IW,S(28),C_PANEL_HDR,C_CYAN_BRIGHT,1);
   DLabel("hdr_title",X+lp,y+S(6),"QUANTUM PLUS AI  v2.0  |  MARKET INTELLIGENCE ENGINE",C_CYAN_BRIGHT,FS(9));
   y += S(30);

   // == STATUS ROW ==
   DRect("status_bar",X+S(2),y,IW,S(22),C_PANEL_BG2,C_PANEL_BRD,1);
   DLabel("lb_status",X+lp,y+S(4),"STATUS",C_SUBTEXT,FS(7));
   DLabel("vl_status",X+S(70),y+S(4),"INITIALIZING",C_ORANGE_BRIGHT,FS(8));
   DLabel("lb_time",X+W-S(140),y+S(4),"SERVER:",C_SUBTEXT,FS(7));
   DLabel("vl_time",X+W-S(95),y+S(4),"--:--:--",C_WHITE_SOFT,FS(7));
   y += S(24);

   DSep("sep0",X+S(2),y,IW); y += S(3);

   // == MARKET REGIME ==
   DRect("regime_hdr",X+S(2),y,IW,S(18),C_PANEL_HDR,C_PANEL_BRD,1);
   DLabel("hdr_regime",X+lp,y+S(3),"■  MARKET REGIME",C_CYAN_BRIGHT,FS(8));
   y += S(20);
   DRect("regime_body",X+S(2),y,IW,S(58),C_PANEL_BG2,C_PANEL_BRD2,1);
   DLabel("lb_regime",X+lp,y+S(4),"REGIME",C_SUBTEXT,FS(7));
   DLabel("vl_regime",X+S(80),y+S(4),"TREND EXPANSION",RegimeToColor(REGIME_TRENDING),FS(9));
   DLabel("lb_regconf",X+lp,y+S(18),"CONFIDENCE",C_SUBTEXT,FS(7));
   DLabel("vl_regconf",X+S(90),y+S(18),"0%",C_WHITE_PURE,FS(8));
   DScoreBar("regime_bar",X+S(160),y+S(20),W-S(175),S(9),0,C_GREEN_BRIGHT);
   DLabel("lb_regstab",X+lp,y+S(32),"STABILITY",C_SUBTEXT,FS(7));
   DLabel("vl_regstab",X+S(90),y+S(32),"0%",C_WHITE_PURE,FS(8));
   DLabel("lb_prevregime",X+S(190),y+S(32),"PREV:",C_SUBTEXT,FS(7));
   DLabel("vl_prevregime",X+S(230),y+S(32),"--",C_MGRAY,FS(7));
   DLabel("lb_mtfalign",X+lp,y+S(46),"MTF ALIGNMENT",C_SUBTEXT,FS(7));
   DLabel("vl_mtfalign",X+S(110),y+S(46),"0%",C_WHITE_PURE,FS(8));
   y += S(62);

   DSep("sep1",X+S(2),y,IW); y += S(3);

   // == AI MARKET ANALYSIS ==
   DRect("analysis_hdr",X+S(2),y,IW,S(18),C_PANEL_HDR,C_PANEL_BRD,1);
   DLabel("hdr_analysis",X+lp,y+S(3),"■  AI MARKET ANALYSIS",C_CYAN_BRIGHT,FS(8));
   y += S(20);
   DRect("analysis_body",X+S(2),y,IW,S(88),C_PANEL_BG2,C_PANEL_BRD2,1);

   // Left column
   DLabel("lb_sess",  X+lp,    y+S(4), "SESSION",    C_SUBTEXT,FS(7));
   DLabel("vl_sess",  X+S(90), y+S(4), "--",         C_CYAN_BRIGHT,FS(8));
   DLabel("lb_vol",   X+lp,    y+S(18),"VOLATILITY", C_SUBTEXT,FS(7));
   DLabel("vl_vol",   X+S(90), y+S(18),"--",         C_WHITE_PURE,FS(8));
   DLabel("lb_news",  X+lp,    y+S(32),"NEWS/SHOCK", C_SUBTEXT,FS(7));
   DLabel("vl_news",  X+S(90), y+S(32),"CLEAR",      C_GREEN_BRIGHT,FS(8));
   DLabel("lb_liq",   X+lp,    y+S(46),"LIQUIDITY",  C_SUBTEXT,FS(7));
   DLabel("vl_liq",   X+lp,    y+S(58),"--",         C_ORANGE_BRIGHT,FS(8));
   DLabel("lb_trend", X+lp,    y+S(72),"TREND STR",  C_SUBTEXT,FS(7));
   DLabel("vl_trend", X+S(90), y+S(72),"0/100",      C_WHITE_PURE,FS(8));

   // Right column
   DLabel("lb_spread",X+S(230),y+S(4), "SPREAD",     C_SUBTEXT,FS(7));
   DLabel("vl_spread",X+S(295),y+S(4), "0 pts",      C_GREEN_BRIGHT,FS(8));
   DLabel("lb_atr",   X+S(230),y+S(18),"ATR",        C_SUBTEXT,FS(7));
   DLabel("vl_atr",   X+S(295),y+S(18),"0",          C_WHITE_PURE,FS(8));
   DLabel("lb_bias",  X+S(230),y+S(32),"BIAS H1",    C_SUBTEXT,FS(7));
   DLabel("vl_bias",  X+S(295),y+S(32),"NEUTRAL",    C_WHITE_PURE,FS(8));
   DLabel("lb_struct",X+S(230),y+S(46),"STRUCTURE",  C_SUBTEXT,FS(7));
   DLabel("vl_struct",X+S(295),y+S(46),"--",         C_WHITE_PURE,FS(8));
   DLabel("lb_volstat",X+S(230),y+S(72),"VOL STATUS", C_SUBTEXT,FS(7));
   DLabel("vl_volstat",X+S(310),y+S(72),"--",        C_WHITE_PURE,FS(7));
   y += S(92);

   DSep("sep2",X+S(2),y,IW); y += S(3);

   // == STRATEGY ROUTER ==
   DRect("strat_hdr",X+S(2),y,IW,S(18),C_PANEL_HDR,C_PANEL_BRD,1);
   DLabel("hdr_strat",X+lp,y+S(3),"■  STRATEGY ROUTER",C_CYAN_BRIGHT,FS(8));
   y += S(20);
   DRect("strat_body",X+S(2),y,IW,S(72),C_PANEL_BG2,C_PANEL_BRD2,1);
   DLabel("lb_active_strat",X+lp,y+S(4),"ACTIVE STRATEGY",C_SUBTEXT,FS(7));
   DRect("active_strat_bg",X+S(2),y+S(16),IW,S(20),C_GREEN_DARK,C_GREEN_BRIGHT,1);
   DLabel("vl_active_strat",X+lp,y+S(19),"--",C_GREEN_BRIGHT,FS(9));
   DLabel("lb_strat_reason",X+lp,y+S(40),"SIGNAL",C_SUBTEXT,FS(7));
   DLabel("vl_strat_reason",X+S(60),y+S(40),"--",C_WHITE_SOFT,FS(7),"Segoe UI");
   DLabel("lb_health",X+lp,y+S(54),"HEALTH",C_SUBTEXT,FS(7));
   DLabel("vl_health",X+S(60),y+S(54),"OK",C_GREEN_BRIGHT,FS(8));
   DLabel("lb_execq",X+S(200),y+S(54),"EXEC SCORE",C_SUBTEXT,FS(7));
   DLabel("vl_execq",X+S(290),y+S(54),"0",C_WHITE_PURE,FS(8));
   y += S(76);

   DSep("sep3",X+S(2),y,IW); y += S(3);

   // == ACTIVE INDICATORS ==
   DRect("ind_hdr",X+S(2),y,IW,S(18),C_PANEL_HDR,C_PANEL_BRD,1);
   DLabel("hdr_ind",X+lp,y+S(3),"■  ACTIVE INDICATORS",C_CYAN_BRIGHT,FS(8));
   y += S(20);
   DRect("ind_body",X+S(2),y,IW,S(58),C_PANEL_BG2,C_PANEL_BRD2,1);
   // EMA row
   DRect("ind_ema_bg",X+S(4),y+S(3),S(60),S(14),C_GREEN_DARK,C_GREEN_BRIGHT,1);
   DLabel("ind_ema",X+S(8),y+S(5),"EMA",C_GREEN_BRIGHT,FS(7));
   DLabel("ind_ema_v",X+S(68),y+S(5),"94",C_GREEN_BRIGHT,FS(8));
   // ADX row (proxy via MTF alignment)
   DRect("ind_adx_bg",X+S(100),y+S(3),S(60),S(14),C_GREEN_DARK,C_GREEN_BRIGHT,1);
   DLabel("ind_adx",X+S(104),y+S(5),"ADX",C_GREEN_BRIGHT,FS(7));
   DLabel("ind_adx_v",X+S(168),y+S(5),"88",C_GREEN_BRIGHT,FS(8));
   // ATR (always active)
   DRect("ind_atr_bg",X+S(198),y+S(3),S(60),S(14),C_GREEN_DARK,C_GREEN_BRIGHT,1);
   DLabel("ind_atr_i",X+S(202),y+S(5),"ATR",C_GREEN_BRIGHT,FS(7));
   DLabel("ind_atr_v",X+S(268),y+S(5),"96",C_GREEN_BRIGHT,FS(8));
   // RSI row (conditional)
   DRect("ind_rsi_bg",X+S(4),y+S(22),S(60),S(14),C_DGRAY,C_MGRAY,1);
   DLabel("ind_rsi",X+S(8),y+S(24),"RSI",C_MGRAY,FS(7));
   DLabel("ind_rsi_v",X+S(68),y+S(24),"--",C_MGRAY,FS(8));
   // Vol state
   DRect("ind_vol_bg",X+S(100),y+S(22),S(60),S(14),C_DGRAY,C_MGRAY,1);
   DLabel("ind_vol_i",X+S(104),y+S(24),"VOL",C_MGRAY,FS(7));
   DLabel("ind_vol_v",X+S(168),y+S(24),"--",C_MGRAY,FS(8));
   // Liq
   DRect("ind_liq_bg",X+S(198),y+S(22),S(60),S(14),C_DGRAY,C_MGRAY,1);
   DLabel("ind_liq_i",X+S(202),y+S(24),"LIQ",C_MGRAY,FS(7));
   DLabel("ind_liq_v",X+S(268),y+S(24),"--",C_MGRAY,FS(8));
   // Status text
   DLabel("ind_status",X+lp,y+S(43),"Active: EMA · ADX · ATR   Monitoring: RSI · VOL · LIQ",C_SUBTEXT,FS(7),"Segoe UI");
   y += S(62);

   DSep("sep4",X+S(2),y,IW); y += S(3);

   // == HEATMAP: MARKET CONDITIONS ==
   DRect("hmap_hdr",X+S(2),y,IW,S(18),C_PANEL_HDR,C_PANEL_BRD,1);
   DLabel("hdr_hmap",X+lp,y+S(3),"■  MARKET CONDITIONS HEATMAP",C_CYAN_BRIGHT,FS(8));
   y += S(20);
   DRect("hmap_body",X+S(2),y,IW,S(108),C_PANEL_BG2,C_PANEL_BRD2,1);

   string hmNames[7]={"TREND STRENGTH","LIQUIDITY QUAL","MOMENTUM","VOLATILITY","STRUCTURE","VOLUME","SESSION"};
   for(int i=0;i<7;i++)
   {
      int ry=y+S(3)+i*S(14);
      DLabel("hm_lb_"+IntegerToString(i),X+lp,ry+S(2),hmNames[i],C_SUBTEXT,FS(7),"Segoe UI");
      DScoreBar("hm_bar_"+IntegerToString(i),X+S(130),ry,S(220),S(10),0,C_GREEN_BRIGHT);
      DLabel("hm_val_"+IntegerToString(i),X+S(358),ry+S(1),"00",C_WHITE_PURE,FS(7));
   }
   y += S(112);

   DSep("sep5",X+S(2),y,IW); y += S(3);

   // == TRADE QUALITY SCORECARD ==
   DRect("tq_hdr",X+S(2),y,IW,S(18),C_PANEL_HDR,C_PANEL_BRD,1);
   DLabel("hdr_tq",X+lp,y+S(3),"■  TRADE QUALITY SCORECARD",C_CYAN_BRIGHT,FS(8));
   y += S(20);
   DRect("tq_body",X+S(2),y,IW,S(88),C_PANEL_BG2,C_PANEL_BRD2,1);
   string tqNames[5]={"TREND","LIQUIDITY","VOLUME","SESSION","STRUCTURE"};
   string tqIDs[5]={"tq_trend","tq_liq","tq_vol","tq_sess","tq_struct"};
   for(int i=0;i<5;i++)
   {
      int tx= X+lp + (i%2==0?0:S(170));
      int ty= y+S(4)+((int)(i/2))*S(28);
      if(i==4){tx=X+lp;ty=y+S(60);}
      DLabel("lb_"+tqIDs[i],tx,ty,tqNames[i],C_SUBTEXT,FS(7));
      DLabel("vl_"+tqIDs[i],tx,ty+S(13),"0/100",C_WHITE_PURE,FS(9));
   }
   // Total score — big centered box
   DRect("tq_total_bg",X+S(240),y+S(50),S(130),S(36),C_PANEL_HDR,C_GOLD_BRIGHT,2);
   DLabel("lb_tq_total",X+S(255),y+S(55),"TOTAL SCORE",C_SUBTEXT,FS(7));
   DLabel("vl_tq_total",X+S(265),y+S(66),"0 / 100",C_GOLD_BRIGHT,FS(10));
   y += S(92);

   DSep("sep6",X+S(2),y,IW); y += S(3);

   // == FINAL DECISION BANNER ==
   DRect("fd_hdr",X+S(2),y,IW,S(18),C_PANEL_HDR,C_PANEL_BRD,1);
   DLabel("hdr_fd",X+lp,y+S(3),"■  FINAL DECISION",C_CYAN_BRIGHT,FS(8));
   y += S(20);
   DRect("fd_body",X+S(2),y,IW,S(48),C_GREEN_DARK,C_GREEN_BRIGHT,2);
   DLabel("fd_decision",X+S(W/2-S(30)),y+S(14),"HOLD",C_WHITE_PURE,FS(18));
   y += S(52);

   DSep("sep7",X+S(2),y,IW); y += S(3);

   // == OPEN POSITIONS ==
   DRect("pos_hdr",X+S(2),y,IW,S(18),C_PANEL_HDR,C_PANEL_BRD,1);
   DLabel("hdr_pos",X+lp,y+S(3),"■  OPEN POSITIONS",C_CYAN_BRIGHT,FS(8));
   DLabel("vl_opcount",X+W-S(80),y+S(3),"0 OPEN",C_ORANGE_BRIGHT,FS(7));
   y += S(20);
   DRect("pos_body",X+S(2),y,IW,S(46),C_PANEL_BG2,C_PANEL_BRD2,1);
   DLabel("lb_pos_type",X+lp,   y+S(4),"TYPE",  C_SUBTEXT,FS(7));
   DLabel("lb_pos_lot", X+S(70),y+S(4),"LOT",   C_SUBTEXT,FS(7));
   DLabel("lb_pos_pnl", X+S(280),y+S(4),"P&L",  C_SUBTEXT,FS(7));
   DLabel("vl_pos_row", X+lp,   y+S(18),"-- No open positions --",C_SUBTEXT,FS(7),"Segoe UI");
   DLabel("lb_float",   X+lp,   y+S(32),"FLOAT",C_SUBTEXT,FS(7));
   DLabel("vl_float",   X+S(60),y+S(32),"+0.00",C_GREEN_BRIGHT,FS(8));
   DLabel("lb_equity",  X+S(200),y+S(32),"EQUITY",C_SUBTEXT,FS(7));
   DLabel("vl_equity",  X+S(260),y+S(32),"0.00", C_WHITE_PURE,FS(8));
   y += S(50);

   DSep("sep8",X+S(2),y,IW); y += S(3);

   // == ACCOUNT INFO ==
   DRect("acc_hdr",X+S(2),y,IW,S(18),C_GREEN_DARK,C_GREEN_BRIGHT,1);
   DLabel("hdr_acc",X+lp,y+S(3),"■  ACCOUNT",C_GREEN_BRIGHT,FS(8));
   y += S(20);
   DRect("acc_body",X+S(2),y,IW,S(46),C_PANEL_BG2,C_PANEL_BRD2,1);
   DLabel("lb_bal",   X+lp,    y+S(4), "BALANCE", C_SUBTEXT,FS(7));
   DLabel("vl_bal",   X+S(80), y+S(4), "0.00",    C_GREEN_BRIGHT,FS(8));
   DLabel("lb_eq",    X+S(220),y+S(4), "EQUITY",  C_SUBTEXT,FS(7));
   DLabel("vl_eq",    X+S(290),y+S(4), "0.00",    C_GREEN_BRIGHT,FS(8));
   DLabel("lb_daypl", X+lp,    y+S(18),"DAY P&L", C_SUBTEXT,FS(7));
   DLabel("vl_daypl", X+S(80), y+S(18),"+0.00 (0%)",C_GREEN_BRIGHT,FS(8));
   DLabel("lb_dd",    X+S(220),y+S(18),"DRAWDOWN", C_SUBTEXT,FS(7));
   DLabel("vl_dd",    X+S(302),y+S(18),"0.00%",   C_WHITE_PURE,FS(8));
   DLabel("lb_wr",    X+lp,    y+S(32),"WIN RATE", C_SUBTEXT,FS(7));
   DLabel("vl_wr",    X+S(80), y+S(32),"0%",       C_WHITE_PURE,FS(8));
   DLabel("lb_risk",  X+S(220),y+S(32),"RISK/TRADE",C_SUBTEXT,FS(7));
   DLabel("vl_risk",  X+S(310),y+S(32),"0%",       C_WHITE_PURE,FS(8));
   y += S(50);

   DSep("sep9",X+S(2),y,IW); y += S(3);

   // == SESSION STRIP ==
   DRect("sess_hdr",X+S(2),y,IW,S(18),C_PANEL_HDR,C_PANEL_BRD,1);
   DLabel("hdr_sess",X+lp,y+S(3),"■  SESSION INTELLIGENCE",C_CYAN_BRIGHT,FS(8));
   y += S(20);
   int sw=(IW-S(6))/3;
   DRect("tab_asia",  X+S(2),    y,sw,S(22),C_DGRAY,C_MGRAY,1);
   DRect("tab_london",X+S(2)+sw, y,sw,S(22),C_DGRAY,C_MGRAY,1);
   DRect("tab_ny",    X+S(2)+sw*2,y,IW-sw*2,S(22),C_DGRAY,C_MGRAY,1);
   DLabel("tab_asia_lbl",  X+S(2)+sw/2-S(14),    y+S(7),"ASIA",   C_SUBTEXT,FS(7));
   DLabel("tab_london_lbl",X+S(2)+sw+sw/2-S(22),  y+S(7),"LONDON", C_SUBTEXT,FS(7));
   DLabel("tab_ny_lbl",    X+S(2)+sw*2+sw/2-S(10),y+S(7),"NY",     C_SUBTEXT,FS(7));
   y += S(26);

   // == FOOTER ==
   DRect("footer",X+S(2),y,IW,S(14),C_PANEL_HDR,C_PANEL_BRD2,1);
   DLabel("ft_left",X+lp,y+S(2),"MN: "+IntegerToString((long)InpMagicNumber)+"  |  Risk: "+DoubleToString(InpRiskPercentPerTrade,1)+"%",C_MGRAY,FS(6),"Segoe UI");
   DLabel("ft_right",X+W-S(120),y+S(2),"QPA v2.0  LIVE",C_MGRAY,FS(6),"Segoe UI");
   y += S(16);

   // Store total height
   g_dashH = y - Y;

   // Resize outer frame to actual content height
   if(ObjectFind(0,D+"fr_outer")>=0)
      ObjectSetInteger(0,D+"fr_outer",OBJPROP_YSIZE,g_dashH);

   ChartRedraw(0);
   Print("QPA v2.0 Dashboard initialized. Width=",S(InpDashWidth)," Height=",g_dashH);
}

//=====================================================================
//  DASHBOARD UPDATE (anti-flicker: only update text/colors, no re-create)
//=====================================================================
void UpdateDash()
{
   if(!InpShowDash) return;
   if(MQLInfoInteger(MQL_TESTER)&&!MQLInfoInteger(MQL_VISUAL_MODE))return;

   int digs=(int)SymbolInfoInteger(_Symbol,SYMBOL_DIGITS);
   double bid=SymbolInfoDouble(_Symbol,SYMBOL_BID);
   double ask=SymbolInfoDouble(_Symbol,SYMBOL_ASK);
   double sp=(double)SymbolInfoInteger(_Symbol,SYMBOL_SPREAD);
   bool   spOk=(sp<=InpMaxSpreadPoints);

   // Status + time
   DUpdate("vl_status", g_statusText, g_statusColor);
   DUpdate("vl_time",   TimeToString(TimeCurrent(),TIME_SECONDS), C_WHITE_SOFT);

   // Regime
   DUpdate("vl_regime", RegimeToString(g_regime.regime), RegimeToColor(g_regime.regime));
   DUpdate("vl_regconf",DoubleToString(g_regime.confidence,0)+"%", ScoreColor(g_regime.confidence));
   DUpdate("vl_regstab",DoubleToString(g_regime.stability,0)+"%",  ScoreColor(g_regime.stability));
   DUpdate("vl_prevregime",RegimeToString(g_regime.previousRegime),C_MGRAY);
   DUpdate("vl_mtfalign",DoubleToString(g_mtf.alignment,0)+"%",    ScoreColor(g_mtf.alignment));
   DScoreBarUpdate("regime_bar",g_regime.confidence,RegimeToColor(g_regime.regime));

   // Analysis block
   DUpdate("vl_sess",   SessionOverlapString(g_session.current),   C_CYAN_BRIGHT);
   DUpdate("vl_vol",    VolStateToString(g_vol.state)+" / "+VolDynamicToString(g_vol.dynamic),
           (g_vol.state==VOL_EXTREME)?C_RED_BRIGHT:(g_vol.state==VOL_HIGH?C_ORANGE_BRIGHT:C_WHITE_PURE));
   DUpdate("vl_news",   NewsToString(g_newsState),(g_newsState==NEWS_NORMAL)?C_GREEN_BRIGHT:(g_newsState==NEWS_CAUTION?C_ORANGE_BRIGHT:C_RED_BRIGHT));
   DUpdate("vl_liq",    LiquidityStatusString(),(g_liq.sweepUpDetected||g_liq.sweepDownDetected)?C_PURPLE_BRIGHT:C_ORANGE_BRIGHT);
   DUpdate("vl_trend",  DoubleToString(g_scores.trendScore,0)+"/100",ScoreColor(g_scores.trendScore));
   DUpdate("vl_spread", DoubleToString(sp,0)+" pts",spOk?C_GREEN_BRIGHT:C_RED_BRIGHT);
   DUpdate("vl_atr",    DoubleToString(g_vol.atrCurrent/SymbolInfoDouble(_Symbol,SYMBOL_POINT),0),C_WHITE_PURE);
   int h1b=g_mtf.h1Bias;
   DUpdate("vl_bias",   (h1b>0)?"BULLISH":(h1b<0?"BEARISH":"NEUTRAL"),(h1b>0)?C_GREEN_BRIGHT:(h1b<0?C_RED_BRIGHT:C_WHITE_PURE));

   // Structure status
   double rsiM5[1]; if(CopyBuffer(g_m5_rsi,0,0,1,rsiM5)<=0)rsiM5[0]=50;
   string structStr="";
   if(g_liq.sweepUpDetected||g_liq.sweepDownDetected)
      structStr=(g_liq.sweepUpDetected)?"BULLISH BOS DETECTED":"BEARISH BOS DETECTED";
   else if(g_mtf.alignment>70)structStr=(g_mtf.h1Bias>0)?"BULLISH MSS":"BEARISH MSS";
   else structStr="STRUCTURE BUILDING";
   DUpdate("vl_struct",structStr,(g_mtf.h1Bias>0)?C_GREEN_BRIGHT:(g_mtf.h1Bias<0?C_RED_BRIGHT:C_WHITE_PURE));
   DUpdate("vl_volstat",VolDynamicToString(g_vol.dynamic),(g_vol.dynamic==VOLDYN_EXPANDING)?C_ORANGE_BRIGHT:(g_vol.dynamic==VOLDYN_SPIKE?C_RED_BRIGHT:C_WHITE_SOFT));

   // Strategy router
   ENUM_STRATEGY routed=RouteRegimeToStrategy(g_regime.regime);
   string stratStr=(routed==STRAT_NONE)?"NO STRATEGY — STAND ASIDE":StrategyToString(routed);
   color  stratClr=(routed==STRAT_NONE)?C_MGRAY:C_GREEN_BRIGHT;
   DUpdate("vl_active_strat",stratStr,stratClr);
   DUpdateBG("active_strat_bg",(routed==STRAT_NONE)?C_DGRAY:C_GREEN_DARK);
   // Strategy reason from last decision
   DUpdate("vl_strat_reason",g_lastDecision.narrative,C_WHITE_SOFT);
   int hi2=StrategyHealthIndex(routed);
   bool hOk=(hi2<0||hi2>=5)?true:g_health[hi2].enabled;
   DUpdate("vl_health",hOk?"OK":"BLOCKED",hOk?C_GREEN_BRIGHT:C_RED_BRIGHT);
   DUpdate("vl_execq",DoubleToString(g_execQuality.compositeScore,0),ScoreColor(g_execQuality.compositeScore));

   // Active indicators (highlight those with strong signal)
   bool emaActive=(MathAbs(g_mtf.m5Bias)>0||MathAbs(g_mtf.h1Bias)>0);
   bool adxActive=(g_mtf.alignment>60);
   bool rsiActive=(rsiM5[0]>65||rsiM5[0]<35);
   bool volActive=(g_vol.state!=VOL_NORMAL);
   bool liqActive=(g_liq.equalHighsDetected||g_liq.equalLowsDetected);

   DUpdateBG("ind_ema_bg",emaActive?C_GREEN_DARK:C_DGRAY);
   DUpdateBG("ind_adx_bg",adxActive?C_GREEN_DARK:C_DGRAY);
   DUpdateBG("ind_rsi_bg",rsiActive?C_GREEN_DARK:C_DGRAY);
   DUpdateBG("ind_vol_bg",volActive?C_GREEN_DARK:C_DGRAY);
   DUpdateBG("ind_liq_bg",liqActive?C_GREEN_DARK:C_DGRAY);

   DUpdate("ind_ema",  "EMA",  emaActive?C_GREEN_BRIGHT:C_MGRAY);
   DUpdate("ind_adx",  "ADX",  adxActive?C_GREEN_BRIGHT:C_MGRAY);
   DUpdate("ind_rsi",  "RSI",  rsiActive?C_GREEN_BRIGHT:C_MGRAY);
   DUpdate("ind_vol_i","VOL",  volActive?C_GREEN_BRIGHT:C_MGRAY);
   DUpdate("ind_liq_i","LIQ",  liqActive?C_GREEN_BRIGHT:C_MGRAY);

   DUpdate("ind_ema_v", DoubleToString(g_scores.trendScore,0),    emaActive?C_GREEN_BRIGHT:C_MGRAY);
   DUpdate("ind_adx_v", DoubleToString(g_mtf.alignment,0),        adxActive?C_GREEN_BRIGHT:C_MGRAY);
   DUpdate("ind_rsi_v", DoubleToString(rsiM5[0],0),               rsiActive?C_GREEN_BRIGHT:C_MGRAY);
   DUpdate("ind_vol_v", DoubleToString(g_scores.volatilityScore,0),volActive?C_GREEN_BRIGHT:C_MGRAY);
   DUpdate("ind_liq_v", DoubleToString(g_scores.liquidityScore,0), liqActive?C_GREEN_BRIGHT:C_MGRAY);

   // Heatmap
   double hmVals[7]={g_scores.trendScore,g_scores.liquidityScore,g_scores.momentumScore,g_scores.volatilityScore,g_scores.structureClarity,g_scores.volumeScore,g_scores.sessionScore};
   for(int i=0;i<7;i++)
   {
      color bc=ScoreColor(hmVals[i]);
      DScoreBarUpdate("hm_bar_"+IntegerToString(i),hmVals[i],bc);
      DUpdate("hm_val_"+IntegerToString(i),IntegerToString((int)hmVals[i]),bc);
   }

   // Trade quality scorecard
   DUpdate("vl_tq_trend",  IntegerToString((int)g_scores.trendScore)+"/100",    ScoreColor(g_scores.trendScore));
   DUpdate("vl_tq_liq",    IntegerToString((int)g_scores.liquidityScore)+"/100", ScoreColor(g_scores.liquidityScore));
   DUpdate("vl_tq_vol",    IntegerToString((int)g_scores.volumeScore)+"/100",    ScoreColor(g_scores.volumeScore));
   DUpdate("vl_tq_sess",   IntegerToString((int)g_scores.sessionScore)+"/100",   ScoreColor(g_scores.sessionScore));
   DUpdate("vl_tq_struct", IntegerToString((int)g_scores.structureScore)+"/100", ScoreColor(g_scores.structureScore));
   color tqC=ScoreColor(g_scores.totalScore);
   DUpdate("vl_tq_total",  DoubleToString(g_scores.totalScore,0)+" / 100",       tqC);

   // Final decision banner
   bool tradeNow=g_lastDecision.tradeApproved;
   string decWord=tradeNow?(g_lastDecision.direction==DIR_LONG?"◆  BUY":"◆  SELL"):"HOLD";
   color  decClr=tradeNow?(g_lastDecision.direction==DIR_LONG?C_GREEN_BRIGHT:C_RED_BRIGHT):C_GOLD_BRIGHT;
   color  fdBg=tradeNow?(g_lastDecision.direction==DIR_LONG?C_GREEN_DARK:C_RED_DARK):C_DGRAY;
   DUpdate("fd_decision",decWord,decClr);
   DUpdateBG("fd_body",fdBg);

   // Positions
   int oc=PositionsTotalForMagic();
   DUpdate("vl_opcount",IntegerToString(oc)+(oc==1?" OPEN":" OPEN"),(oc>0)?C_GREEN_BRIGHT:C_ORANGE_BRIGHT);
   string posRow="-- No open positions --";
   if(oc>0)for(int i=PositionsTotal()-1;i>=0;i--)
   {
      if(g_pos.SelectByIndex(i)&&g_pos.Magic()==InpMagicNumber&&g_pos.Symbol()==_Symbol)
      {
         string tp2=(g_pos.PositionType()==POSITION_TYPE_BUY)?"BUY":"SELL";
         posRow=tp2+"  "+DoubleToString(g_pos.Volume(),2)+"  @"+DoubleToString(g_pos.PriceOpen(),digs)+"  PL: "+DoubleToString(g_pos.Profit(),2);
         break;
      }
   }
   DUpdate("vl_pos_row",posRow,(oc>0)?C_WHITE_PURE:C_SUBTEXT);
   double fl=GetFloatingPL();
   DUpdate("vl_float",(fl>=0?"+":"")+DoubleToString(fl,2),(fl>=0)?C_GREEN_BRIGHT:C_RED_BRIGHT);
   DUpdate("vl_equity",DoubleToString(AccountInfoDouble(ACCOUNT_EQUITY),2),C_WHITE_PURE);

   // Account
   double bal=AccountInfoDouble(ACCOUNT_BALANCE),eq=AccountInfoDouble(ACCOUNT_EQUITY);
   DUpdate("vl_bal",DoubleToString(bal,2),C_GREEN_BRIGHT);
   DUpdate("vl_eq", DoubleToString(eq, 2),C_GREEN_BRIGHT);
   double dayPL=eq-g_risk.dayStartEquity,dayPct=(g_risk.dayStartEquity>0)?dayPL/g_risk.dayStartEquity*100.0:0.0;
   DUpdate("vl_daypl",(dayPL>=0?"+":"")+DoubleToString(dayPL,2)+" ("+DoubleToString(dayPct,2)+"%)",(dayPL>=0)?C_GREEN_BRIGHT:C_RED_BRIGHT);
   DUpdate("vl_dd",DoubleToString(g_risk.currentDrawdownPct,2)+"%",(g_risk.currentDrawdownPct<3)?C_GREEN_BRIGHT:(g_risk.currentDrawdownPct<7?C_ORANGE_BRIGHT:C_RED_BRIGHT));
   int tot=g_sessionWins+g_sessionLosses;
   DUpdate("vl_wr",(tot>0?DoubleToString(100.0*g_sessionWins/tot,0):"0")+"%",(tot==0||g_sessionWins*2>=tot)?C_GREEN_BRIGHT:C_ORANGE_BRIGHT);
   DUpdate("vl_risk",DoubleToString(InpRiskPercentPerTrade,1)+"%",C_WHITE_PURE);

   // Session tabs
   int X=S(InpDashX); int W=S(InpDashWidth); int sw=(W-S(6))/3;
   color cA=(g_session.current==SESSION_ASIAN)?C_PURPLE_BRIGHT:C_DGRAY;
   color cL=(g_session.current==SESSION_LONDON_OPEN||g_session.current==SESSION_LONDON_MID)?C_BLUE_BRIGHT:C_DGRAY;
   color cN=(g_session.current==SESSION_NY_OPEN||g_session.current==SESSION_NY_PM)?C_ORANGE_BRIGHT:C_DGRAY;
   DUpdateBG("tab_asia",  cA); DUpdateBG("tab_london",cL); DUpdateBG("tab_ny",cN);
   DUpdate("tab_asia_lbl",  "ASIA",  (cA!=C_DGRAY)?C_WHITE_PURE:C_SUBTEXT);
   DUpdate("tab_london_lbl","LONDON",(cL!=C_DGRAY)?C_WHITE_PURE:C_SUBTEXT);
   DUpdate("tab_ny_lbl",    "NY",    (cN!=C_DGRAY)?C_WHITE_PURE:C_SUBTEXT);

   ChartRedraw(0);
}

void DeleteDash()
{
   ObjectsDeleteAll(0,D);
   ChartRedraw(0);
}

//=====================================================================
//  ANALYST PANEL (right-side narrative panel)
//=====================================================================
#define AP "QPA2_AP_"

void APRect(string nm,int x,int y,int w,int h,color bg,color brd=clrNONE,int bw=1)
{
   string n=AP+nm;
   if(ObjectFind(0,n)<0)ObjectCreate(0,n,OBJ_RECTANGLE_LABEL,0,0,0);
   ObjectSetInteger(0,n,OBJPROP_CORNER,CORNER_LEFT_UPPER);
   ObjectSetInteger(0,n,OBJPROP_XDISTANCE,x);ObjectSetInteger(0,n,OBJPROP_YDISTANCE,y);
   ObjectSetInteger(0,n,OBJPROP_XSIZE,w);ObjectSetInteger(0,n,OBJPROP_YSIZE,h);
   ObjectSetInteger(0,n,OBJPROP_BGCOLOR,bg);ObjectSetInteger(0,n,OBJPROP_SELECTABLE,false);
   ObjectSetInteger(0,n,OBJPROP_HIDDEN,false);ObjectSetInteger(0,n,OBJPROP_ZORDER,0);
   if(brd!=clrNONE){ObjectSetInteger(0,n,OBJPROP_BORDER_TYPE,BORDER_FLAT);ObjectSetInteger(0,n,OBJPROP_COLOR,brd);ObjectSetInteger(0,n,OBJPROP_WIDTH,bw);}
   else{ObjectSetInteger(0,n,OBJPROP_BORDER_TYPE,BORDER_RAISED);ObjectSetInteger(0,n,OBJPROP_COLOR,bg);}
}
void APLabel(string nm,int x,int y,string txt,color clr,int fsz,string fnt="Segoe UI Bold")
{
   string n=AP+nm;
   if(ObjectFind(0,n)<0)ObjectCreate(0,n,OBJ_LABEL,0,0,0);
   ObjectSetInteger(0,n,OBJPROP_CORNER,CORNER_LEFT_UPPER);
   ObjectSetInteger(0,n,OBJPROP_XDISTANCE,x);ObjectSetInteger(0,n,OBJPROP_YDISTANCE,y);
   ObjectSetString(0,n,OBJPROP_TEXT,txt);ObjectSetInteger(0,n,OBJPROP_COLOR,clr);
   ObjectSetInteger(0,n,OBJPROP_FONTSIZE,fsz);ObjectSetString(0,n,OBJPROP_FONT,fnt);
   ObjectSetInteger(0,n,OBJPROP_SELECTABLE,false);ObjectSetInteger(0,n,OBJPROP_HIDDEN,false);ObjectSetInteger(0,n,OBJPROP_ZORDER,2);
}
void APUpdate(string nm,string txt,color clr=C_WHITE_PURE)
{
   string n=AP+nm;
   if(ObjectFind(0,n)>=0){ObjectSetString(0,n,OBJPROP_TEXT,txt);ObjectSetInteger(0,n,OBJPROP_COLOR,clr);}
}

void InitAnalystPanel()
{
   if(!InpShowAnalystPanel)return;
   int X=S(InpAnalystX),Y=S(InpAnalystY),W=S(340),lp=S(10);

   APRect("frame",X,Y,W,S(480),C_PANEL_BG,C_GOLD_BRIGHT,2);
   APRect("hdr",X+S(2),Y+S(2),W-S(4),S(26),C_PANEL_HDR,C_GOLD_BRIGHT,1);
   APLabel("hdr_t",X+lp,Y+S(8),"AI  MARKET  COMMENTARY",C_GOLD_BRIGHT,FS(10));
   int y=Y+S(30);

   // Narrative label rows
   string keys[8]={"regime_row","session_row","trend_row","liq_row","vol_row","struct_row","strat_row","score_row"};
   string keysLb[8]={"MARKET REGIME:","SESSION:","TREND STRENGTH:","LIQUIDITY:","VOLUME:","STRUCTURE:","ACTIVE STRATEGY:","TRADE QUALITY:"};
   for(int i=0;i<8;i++)
   {
      APRect("bg_"+keys[i],X+S(2),y,W-S(4),S(32),C_PANEL_BG2,C_PANEL_BRD2,1);
      APLabel("lb_"+keys[i],X+lp,y+S(2),keysLb[i],C_SUBTEXT,FS(7),"Segoe UI");
      APLabel("vl_"+keys[i],X+lp,y+S(14),"--",C_WHITE_PURE,FS(9));
      y+=S(36);
   }

   // Separator
   APRect("sep",X+S(2),y,W-S(4),S(1),C_PANEL_BRD2,clrNONE);
   y+=S(4);

   // Narrative prose
   APRect("narr_bg",X+S(2),y,W-S(4),S(130),C_PANEL_BG2,C_PANEL_BRD2,1);
   APLabel("narr_hdr",X+lp,y+S(4),"AI NARRATIVE",C_CYAN_BRIGHT,FS(8));
   APLabel("narr_l1",X+lp,y+S(20),"",C_WHITE_SOFT,FS(8),"Segoe UI");
   APLabel("narr_l2",X+lp,y+S(34),"",C_WHITE_SOFT,FS(8),"Segoe UI");
   APLabel("narr_l3",X+lp,y+S(48),"",C_WHITE_SOFT,FS(8),"Segoe UI");
   APLabel("narr_l4",X+lp,y+S(62),"",C_WHITE_SOFT,FS(8),"Segoe UI");
   APLabel("narr_l5",X+lp,y+S(76),"",C_WHITE_SOFT,FS(8),"Segoe UI");
   APLabel("narr_l6",X+lp,y+S(90),"",C_WHITE_SOFT,FS(8),"Segoe UI");
   APLabel("narr_ts",X+lp,y+S(112),"Last update: --",C_MGRAY,FS(6),"Segoe UI");

   ChartRedraw(0);
}

void UpdateAnalystPanel()
{
   if(!InpShowAnalystPanel)return;

   ENUM_STRATEGY routed=RouteRegimeToStrategy(g_regime.regime);
   int h1b=g_mtf.h1Bias;

   APUpdate("vl_regime_row",RegimeToString(g_regime.regime)+" | Conf: "+DoubleToString(g_regime.confidence,0)+"%",RegimeToColor(g_regime.regime));
   APUpdate("vl_session_row",SessionOverlapString(g_session.current),C_CYAN_BRIGHT);
   APUpdate("vl_trend_row",DoubleToString(g_scores.trendScore,0)+"/100  "+((h1b>0)?"BULLISH":"BEARISH"),ScoreColor(g_scores.trendScore));
   APUpdate("vl_liq_row",LiquidityStatusString(),(g_liq.sweepUpDetected||g_liq.sweepDownDetected)?C_PURPLE_BRIGHT:C_ORANGE_BRIGHT);

   string volStr2=VolStateToString(g_vol.state)+" — "+VolDynamicToString(g_vol.dynamic);
   bool aboveAvg=(g_vol.atrRatio>1.1);
   APUpdate("vl_vol_row",volStr2+(aboveAvg?" (ABOVE AVERAGE)":" (NORMAL)"),aboveAvg?C_ORANGE_BRIGHT:C_WHITE_PURE);

   string structStr2=(g_liq.sweepUpDetected)?"BULLISH BOS DETECTED":(g_liq.sweepDownDetected?"BEARISH BOS DETECTED":(g_mtf.alignment>70?"MSS CONFIRMED":"BUILDING"));
   APUpdate("vl_struct_row",structStr2,(g_mtf.h1Bias>0)?C_GREEN_BRIGHT:(g_mtf.h1Bias<0?C_RED_BRIGHT:C_WHITE_PURE));

   APUpdate("vl_strat_row",(routed==STRAT_NONE)?"NONE — STAND ASIDE":StrategyToString(routed),(routed==STRAT_NONE)?C_MGRAY:C_GREEN_BRIGHT);

   double tq=g_scores.totalScore;
   APUpdate("vl_score_row",DoubleToString(tq,0)+"/100",ScoreColor(tq));

   // Narrative prose
   APUpdate("narr_l1",g_narrativeLine1,C_WHITE_SOFT);
   APUpdate("narr_l2",g_narrativeLine2,C_WHITE_SOFT);
   APUpdate("narr_l3",g_narrativeLine3,C_WHITE_SOFT);
   APUpdate("narr_l4",g_narrativeLine4,C_WHITE_SOFT);
   APUpdate("narr_l5",g_narrativeLine5,C_WHITE_SOFT);
   APUpdate("narr_l6",g_narrativeLine6,C_WHITE_SOFT);
   APUpdate("narr_ts","Last update: "+TimeToString(g_lastNarrative,TIME_SECONDS),C_MGRAY);
}

void DeleteAnalystPanel(){ObjectsDeleteAll(0,AP);ChartRedraw(0);}

//=====================================================================
//  CHART OVERLAYS — HIGH VISIBILITY VERSION
//=====================================================================

// Safe bar-from-time
int SafeBar(datetime t)
{
   datetime now=TimeCurrent(); if(t>now)t=now;
   int b=iBarShift(_Symbol,PERIOD_M5,t,false);
   return(b<0)?0:b;
}

// Draw a labeled chart box with visible borders and bright label
void DrawChartBox(string id, datetime t1, datetime t2, double hi, double lo, color clr, string lbl)
{
   string nm=OV+id;
   if(ObjectFind(0,nm)>=0)ObjectDelete(0,nm);
   if(ObjectCreate(0,nm,OBJ_RECTANGLE,0,t1,hi,t2,lo))
   {
      ObjectSetInteger(0,nm,OBJPROP_COLOR,clr);
      ObjectSetInteger(0,nm,OBJPROP_FILL,true);
      ObjectSetInteger(0,nm,OBJPROP_BACK,true);
      ObjectSetInteger(0,nm,OBJPROP_WIDTH,1);
      ObjectSetInteger(0,nm,OBJPROP_SELECTABLE,false);
      ObjectSetInteger(0,nm,OBJPROP_HIDDEN,false);
   }
   // Top border (visible line)
   string nmT=OV+id+"_t";
   if(ObjectFind(0,nmT)>=0)ObjectDelete(0,nmT);
   if(ObjectCreate(0,nmT,OBJ_TREND,0,t1,hi,t2,hi))
   {
      ObjectSetInteger(0,nmT,OBJPROP_COLOR,clr);ObjectSetInteger(0,nmT,OBJPROP_WIDTH,2);
      ObjectSetInteger(0,nmT,OBJPROP_RAY_RIGHT,false);ObjectSetInteger(0,nmT,OBJPROP_SELECTABLE,false);
      ObjectSetInteger(0,nmT,OBJPROP_BACK,false);ObjectSetInteger(0,nmT,OBJPROP_HIDDEN,false);
   }
   // Label — bright background rectangle behind text for max visibility
   string nmL=OV+id+"_l";
   if(ObjectFind(0,nmL)>=0)ObjectDelete(0,nmL);
   if(ObjectCreate(0,nmL,OBJ_TEXT,0,t1,hi))
   {
      ObjectSetString(0,nmL,OBJPROP_TEXT," "+lbl+" ");
      ObjectSetInteger(0,nmL,OBJPROP_COLOR,C_WHITE_PURE);
      ObjectSetInteger(0,nmL,OBJPROP_FONTSIZE,14);
      ObjectSetString(0,nmL,OBJPROP_FONT,"Segoe UI Bold");
      ObjectSetInteger(0,nmL,OBJPROP_SELECTABLE,false);
      ObjectSetInteger(0,nmL,OBJPROP_HIDDEN,false);
      ObjectSetInteger(0,nmL,OBJPROP_BACK,false);
      ObjectSetInteger(0,nmL,OBJPROP_ANCHOR,ANCHOR_LEFT_LOWER);
   }
}

// Draw a horizontal level line with background-contrasted label
void DrawHLevel(string id, double price, datetime t1, datetime t2, color clr, string lbl, int fsz=14)
{
   string nm=OV+id;
   if(ObjectFind(0,nm)>=0)ObjectDelete(0,nm);
   if(ObjectCreate(0,nm,OBJ_TREND,0,t1,price,t2,price))
   {
      ObjectSetInteger(0,nm,OBJPROP_COLOR,clr);ObjectSetInteger(0,nm,OBJPROP_WIDTH,2);
      ObjectSetInteger(0,nm,OBJPROP_STYLE,STYLE_DASH);ObjectSetInteger(0,nm,OBJPROP_RAY_RIGHT,false);
      ObjectSetInteger(0,nm,OBJPROP_SELECTABLE,false);ObjectSetInteger(0,nm,OBJPROP_BACK,false);
      ObjectSetInteger(0,nm,OBJPROP_HIDDEN,false);
   }
   // Label — placed at right side of the line
   string nmL=OV+id+"_lbl";
   if(ObjectFind(0,nmL)>=0)ObjectDelete(0,nmL);
   if(ObjectCreate(0,nmL,OBJ_TEXT,0,t2,price))
   {
      ObjectSetString(0,nmL,OBJPROP_TEXT," "+lbl+" ");
      ObjectSetInteger(0,nmL,OBJPROP_COLOR,clr);
      ObjectSetInteger(0,nmL,OBJPROP_FONTSIZE,fsz);
      ObjectSetString(0,nmL,OBJPROP_FONT,"Segoe UI Bold");
      ObjectSetInteger(0,nmL,OBJPROP_SELECTABLE,false);ObjectSetInteger(0,nmL,OBJPROP_HIDDEN,false);
      ObjectSetInteger(0,nmL,OBJPROP_BACK,false);ObjectSetInteger(0,nmL,OBJPROP_ANCHOR,ANCHOR_RIGHT_UPPER);
   }
}

// Draw a text marker at a price level on the chart (for BOS, CHOCH, etc.)
void DrawPriceLabel(string id, datetime t, double price, string txt, color bg, color fg, int fsz=14, bool above=true)
{
   string nm=OV+id;
   if(ObjectFind(0,nm)>=0)ObjectDelete(0,nm);
   if(ObjectCreate(0,nm,OBJ_TEXT,0,t,price))
   {
      ObjectSetString(0,nm,OBJPROP_TEXT," "+txt+" ");
      ObjectSetInteger(0,nm,OBJPROP_COLOR,fg);
      ObjectSetInteger(0,nm,OBJPROP_FONTSIZE,fsz);
      ObjectSetString(0,nm,OBJPROP_FONT,"Segoe UI Bold");
      ObjectSetInteger(0,nm,OBJPROP_SELECTABLE,false);ObjectSetInteger(0,nm,OBJPROP_HIDDEN,false);
      ObjectSetInteger(0,nm,OBJPROP_BACK,false);
      ObjectSetInteger(0,nm,OBJPROP_ANCHOR,above?ANCHOR_LOWER:ANCHOR_UPPER);
   }
}

//=====================================================================
//  SESSION BOXES
//=====================================================================
void UpdateSessionBoxes()
{
   if(!InpDrawSessionBoxes)return;
   datetime now=TimeCurrent(),today=DayStart(now),yest=today-86400;
   ENUM_SESSION sess[5]={SESSION_ASIAN,SESSION_LONDON_OPEN,SESSION_LONDON_MID,SESSION_NY_OPEN,SESSION_NY_PM};
   color sCol[5]={C'15,20,50',C'20,15,55',C'20,15,55',C'50,25,5',C'50,25,5'};
   color sBrd[5]={C_PURPLE_BRIGHT,C_BLUE_BRIGHT,C_BLUE_BRIGHT,C_ORANGE_BRIGHT,C_ORANGE_BRIGHT};
   string sLbl[5]={"ASIAN","LON OPEN","LON MID","NY OPEN","NY PM"};

   for(int d=0;d<2;d++)
   {
      datetime db=(d==0)?today:yest;
      for(int i=0;i<5;i++)
      {
         int sh,eh; SessionHourBand(sess[i],sh,eh);
         sh=(sh+InpBrokerGMTOffset)%24; eh=(eh+InpBrokerGMTOffset)%24;
         datetime st=db+sh*3600,et=db+eh*3600;
         if(et<now-InpSessionBoxLookbackHrs*3600)continue;
         if(st>now)continue;
         datetime etC=MathMin(et,now);
         // Get actual price range for this session window
         int sb=SafeBar(st),eb=SafeBar(etC);
         if(sb<eb){int tmp=sb;sb=eb;eb=tmp;}
         double hi=-1e300,lo=1e300;
         for(int b=eb;b<=sb;b++){hi=MathMax(hi,iHigh(_Symbol,PERIOD_M5,b));lo=MathMin(lo,iLow(_Symbol,PERIOD_M5,b));}
         if(hi<=-1e300||lo>=1e300)continue;
         string bid2=sLbl[i]+"_"+IntegerToString((int)db);
         // Filled background box
         string nm=OV+"SB_"+bid2;
         if(ObjectFind(0,nm)>=0)ObjectDelete(0,nm);
         if(ObjectCreate(0,nm,OBJ_RECTANGLE,0,st,hi*(1+0.0003),etC,lo*(1-0.0003)))
         {
            ObjectSetInteger(0,nm,OBJPROP_COLOR,sCol[i]);ObjectSetInteger(0,nm,OBJPROP_FILL,true);
            ObjectSetInteger(0,nm,OBJPROP_BACK,true);ObjectSetInteger(0,nm,OBJPROP_SELECTABLE,false);ObjectSetInteger(0,nm,OBJPROP_HIDDEN,false);
         }
         // Top border line
         string nmT=OV+"SBT_"+bid2;
         if(ObjectFind(0,nmT)>=0)ObjectDelete(0,nmT);
         if(ObjectCreate(0,nmT,OBJ_TREND,0,st,hi*(1+0.0003),etC,hi*(1+0.0003)))
         {
            ObjectSetInteger(0,nmT,OBJPROP_COLOR,sBrd[i]);ObjectSetInteger(0,nmT,OBJPROP_WIDTH,2);
            ObjectSetInteger(0,nmT,OBJPROP_RAY_RIGHT,false);ObjectSetInteger(0,nmT,OBJPROP_SELECTABLE,false);
            ObjectSetInteger(0,nmT,OBJPROP_BACK,false);ObjectSetInteger(0,nmT,OBJPROP_HIDDEN,false);
         }
         // Label — always visible: bright text, positioned above the box
         string nmL=OV+"SBL_"+bid2;
         if(ObjectFind(0,nmL)>=0)ObjectDelete(0,nmL);
         if(ObjectCreate(0,nmL,OBJ_TEXT,0,st,hi*(1+0.0003)))
         {
            ObjectSetString(0,nmL,OBJPROP_TEXT," "+sLbl[i]+" ");
            ObjectSetInteger(0,nmL,OBJPROP_COLOR,sBrd[i]);
            ObjectSetInteger(0,nmL,OBJPROP_FONTSIZE,14);
            ObjectSetString(0,nmL,OBJPROP_FONT,"Segoe UI Bold");
            ObjectSetInteger(0,nmL,OBJPROP_SELECTABLE,false);ObjectSetInteger(0,nmL,OBJPROP_HIDDEN,false);
            ObjectSetInteger(0,nmL,OBJPROP_BACK,false);ObjectSetInteger(0,nmL,OBJPROP_ANCHOR,ANCHOR_LEFT_LOWER);
         }
      }
   }
}

//=====================================================================
//  BSL / SSL LABELS ON CHART
//=====================================================================
void UpdateBSLSSL()
{
   if(!InpDrawBSLSSL)return;
   datetime now=TimeCurrent(),past=now-(datetime)(InpSessionBoxLookbackHrs*3600);
   double point=SymbolInfoDouble(_Symbol,SYMBOL_POINT);
   double zw=MathMax(point*80,g_vol.atrAvg*0.05);

   // BSL — Buy Side Liquidity (equal highs)
   if(g_liq.equalHighsDetected)
   {
      double lvl=g_liq.equalHighLevel;
      color clr=g_liq.sweepUpDetected?C_RED_BRIGHT:C_GREEN_BRIGHT;
      string lbl=g_liq.sweepUpDetected?"BSL  ✓ SWEPT":"BSL";
      DrawHLevel("BSL_line",lvl,past,now,clr,lbl,14);
      // Zone fill
      string nz=OV+"BSL_zone";
      if(ObjectFind(0,nz)>=0)ObjectDelete(0,nz);
      if(ObjectCreate(0,nz,OBJ_RECTANGLE,0,past,lvl+zw,now,lvl-zw))
      {
         ObjectSetInteger(0,nz,OBJPROP_COLOR,g_liq.sweepUpDetected?C'40,0,0':C'0,40,10');
         ObjectSetInteger(0,nz,OBJPROP_FILL,true);ObjectSetInteger(0,nz,OBJPROP_BACK,true);
         ObjectSetInteger(0,nz,OBJPROP_SELECTABLE,false);ObjectSetInteger(0,nz,OBJPROP_HIDDEN,false);
      }
      // Sweep arrow
      if(g_liq.sweepUpDetected)
      {
         string na=OV+"BSL_sweep";
         if(ObjectFind(0,na)>=0)ObjectDelete(0,na);
         for(int i=0;i<4;i++)
         {
            double hi=iHigh(_Symbol,PERIOD_M5,i);
            if(hi>lvl){
               if(ObjectCreate(0,na,OBJ_ARROW,0,iTime(_Symbol,PERIOD_M5,i),hi+g_vol.atrAvg*0.3))
               {
                  ObjectSetInteger(0,na,OBJPROP_ARROWCODE,242);ObjectSetInteger(0,na,OBJPROP_COLOR,C_RED_BRIGHT);
                  ObjectSetInteger(0,na,OBJPROP_WIDTH,3);ObjectSetInteger(0,na,OBJPROP_SELECTABLE,false);
                  ObjectSetInteger(0,na,OBJPROP_HIDDEN,false);ObjectSetInteger(0,na,OBJPROP_BACK,false);
               }
               // Sweep label
               DrawPriceLabel("BSL_sweep_lbl",iTime(_Symbol,PERIOD_M5,i),hi+g_vol.atrAvg*0.6,"LIQUIDITY SWEEP",C_RED_BRIGHT,C_WHITE_PURE,14,true);
               break;
            }
         }
      }
   }
   else{ObjectsDeleteAll(0,OV+"BSL");}

   // SSL — Sell Side Liquidity (equal lows)
   if(g_liq.equalLowsDetected)
   {
      double lvl=g_liq.equalLowLevel;
      color clr=g_liq.sweepDownDetected?C_GREEN_BRIGHT:C_RED_BRIGHT;
      string lbl=g_liq.sweepDownDetected?"SSL  ✓ SWEPT":"SSL";
      DrawHLevel("SSL_line",lvl,past,now,clr,lbl,14);
      string nz=OV+"SSL_zone";
      if(ObjectFind(0,nz)>=0)ObjectDelete(0,nz);
      if(ObjectCreate(0,nz,OBJ_RECTANGLE,0,past,lvl+zw,now,lvl-zw))
      {
         ObjectSetInteger(0,nz,OBJPROP_COLOR,g_liq.sweepDownDetected?C'0,40,10':C'40,0,0');
         ObjectSetInteger(0,nz,OBJPROP_FILL,true);ObjectSetInteger(0,nz,OBJPROP_BACK,true);
         ObjectSetInteger(0,nz,OBJPROP_SELECTABLE,false);ObjectSetInteger(0,nz,OBJPROP_HIDDEN,false);
      }
      if(g_liq.sweepDownDetected)
      {
         string na=OV+"SSL_sweep";
         if(ObjectFind(0,na)>=0)ObjectDelete(0,na);
         for(int i=0;i<4;i++)
         {
            double lo=iLow(_Symbol,PERIOD_M5,i);
            if(lo<lvl){
               if(ObjectCreate(0,na,OBJ_ARROW,0,iTime(_Symbol,PERIOD_M5,i),lo-g_vol.atrAvg*0.3))
               {
                  ObjectSetInteger(0,na,OBJPROP_ARROWCODE,241);ObjectSetInteger(0,na,OBJPROP_COLOR,C_GREEN_BRIGHT);
                  ObjectSetInteger(0,na,OBJPROP_WIDTH,3);ObjectSetInteger(0,na,OBJPROP_SELECTABLE,false);
                  ObjectSetInteger(0,na,OBJPROP_HIDDEN,false);ObjectSetInteger(0,na,OBJPROP_BACK,false);
               }
               DrawPriceLabel("SSL_sweep_lbl",iTime(_Symbol,PERIOD_M5,i),lo-g_vol.atrAvg*0.6,"LIQUIDITY SWEEP",C_GREEN_BRIGHT,C_WHITE_PURE,14,false);
               break;
            }
         }
      }
   }
   else{ObjectsDeleteAll(0,OV+"SSL");}
}

//=====================================================================
//  MARKET STRUCTURE (HH/HL/LH/LL + BOS/CHOCH)
//=====================================================================
void UpdateMarketStructure()
{
   if(!InpDrawStructure)return;

   double shP[30],slP[30]; datetime shT[30],slT[30];
   int nH=FindSwingHighs(60,3,shP,shT);
   int nL=FindSwingLows(60,3,slP,slT);

   // Label swing highs
   for(int i=0;i<MathMin(nH,6);i++)
   {
      bool isHH=(i>0&&shP[i]>shP[i-1]);
      string lbl=isHH?"HH":"LH";
      color clr=isHH?C_GREEN_BRIGHT:C_RED_BRIGHT;
      DrawPriceLabel("SH_"+IntegerToString(i),shT[i],shP[i]+g_vol.atrAvg*0.25,lbl,clr,C_WHITE_PURE,14,true);
   }

   // Label swing lows
   for(int i=0;i<MathMin(nL,6);i++)
   {
      bool isHL=(i>0&&slP[i]>slP[i-1]);
      string lbl=isHL?"HL":"LL";
      color clr=isHL?C_GREEN_BRIGHT:C_RED_BRIGHT;
      DrawPriceLabel("SL_"+IntegerToString(i),slT[i],slP[i]-g_vol.atrAvg*0.25,lbl,clr,C_WHITE_PURE,14,false);
   }

   // BOS: price broke above most recent swing high or below most recent swing low
   double px=SymbolInfoDouble(_Symbol,SYMBOL_BID);
   if(nH>0&&px>shP[0])
      DrawPriceLabel("BOS_bull",shT[0],shP[0],"BOS",C_GREEN_BRIGHT,C_WHITE_PURE,14,true);
   if(nL>0&&px<slP[0])
      DrawPriceLabel("BOS_bear",slT[0],slP[0],"BOS",C_RED_BRIGHT,C_WHITE_PURE,14,false);

   // CHOCH: momentum divergence (M1 vs M5 opposite bias)
   if(g_mtf.m1Bias!=0&&g_mtf.m5Bias!=0&&g_mtf.m1Bias!=g_mtf.m5Bias)
      DrawPriceLabel("CHOCH",iTime(_Symbol,PERIOD_M5,0),px,"CHOCH",C_PURPLE_BRIGHT,C_WHITE_PURE,14,true);
}

//=====================================================================
//  ORDER BLOCKS
//=====================================================================
void UpdateOrderBlocks()
{
   if(!InpDrawOrderBlocks)return;

   // Identify the last bearish candle before a bullish impulse (demand OB)
   // and the last bullish candle before a bearish impulse (supply OB)
   // Simple proxy: look 3-10 bars back for strong directional candles
   for(int i=3;i<15;i++)
   {
      double o=iOpen(_Symbol,PERIOD_M5,i),c=iClose(_Symbol,PERIOD_M5,i);
      double h=iHigh(_Symbol,PERIOD_M5,i),l=iLow(_Symbol,PERIOD_M5,i);
      double body=MathAbs(c-o),atr=g_vol.atrAvg;
      if(body<atr*0.5)continue;

      bool isBullOB=(c>o);   // bullish candle = potential demand OB
      bool isBearOB=(c<o);   // bearish candle = potential supply OB

      if(isBullOB&&g_mtf.h1Bias>0)  // demand block in bull trend
      {
         datetime t=iTime(_Symbol,PERIOD_M5,i);
         datetime now=TimeCurrent();
         color clr=C'0,40,10';
         color brd=C_GREEN_BRIGHT;
         DrawChartBox("OB_D_"+IntegerToString(i),t,now,h,l,clr,"DEMAND OB");
         break;
      }
      if(isBearOB&&g_mtf.h1Bias<0)  // supply block in bear trend
      {
         datetime t=iTime(_Symbol,PERIOD_M5,i);
         datetime now=TimeCurrent();
         DrawChartBox("OB_S_"+IntegerToString(i),t,now,h,l,C'40,5,5',"SUPPLY OB");
         break;
      }
   }
}

//=====================================================================
//  FAIR VALUE GAPS (FVG)
//=====================================================================
void UpdateFVG()
{
   if(!InpDrawFVG)return;

   // FVG = gap between candle[i+1] high and candle[i-1] low (bullish)
   //       or between candle[i+1] low and candle[i-1] high (bearish)
   for(int i=1;i<20;i++)
   {
      double c1H=iHigh(_Symbol,PERIOD_M5,i+1);
      double c1L=iLow(_Symbol,PERIOD_M5,i+1);
      double c3H=iHigh(_Symbol,PERIOD_M5,i-1);
      double c3L=iLow(_Symbol,PERIOD_M5,i-1);

      // Bullish FVG: c3 low above c1 high
      if(c3L>c1H&&(c3L-c1H)>g_vol.atrAvg*0.3)
      {
         datetime t1=iTime(_Symbol,PERIOD_M5,i+1);
         datetime t2=TimeCurrent();
         string nm="FVG_B_"+IntegerToString(i);
         DrawChartBox(nm,t1,t2,c3L,c1H,C'0,35,5',"FVG  BULL");
         break;
      }
      // Bearish FVG: c3 high below c1 low
      if(c3H<c1L&&(c1L-c3H)>g_vol.atrAvg*0.3)
      {
         datetime t1=iTime(_Symbol,PERIOD_M5,i+1);
         datetime t2=TimeCurrent();
         DrawChartBox("FVG_S_"+IntegerToString(i),t1,t2,c1L,c3H,C'35,0,0',"FVG  BEAR");
         break;
      }
   }
}

//=====================================================================
//  REGIME OVERLAY ON CHART
//=====================================================================
void UpdateRegimeOverlay()
{
   if(!InpDrawRegimeOverlay)return;

   // Place a multi-line text block on the chart (top right via OBJ_LABEL)
   string lines[6];
   lines[0]="  CURRENT MARKET REGIME  ";
   lines[1]=(g_regime.regime==REGIME_TRENDING)?"  ✓ "+RegimeToString(g_regime.regime)+"  ":"  "+RegimeToString(g_regime.regime)+"  ";
   lines[2]="  Confidence: "+DoubleToString(g_regime.confidence,0)+"%  ";
   lines[3]="  Volatility: "+VolStateToString(g_vol.state)+"  ";
   lines[4]="  Liquidity: "+(g_liq.pressureScore>50?"Healthy":"Low")+"  ";
   lines[5]="  Inst. Activity: "+(g_vol.atrRatio>1.2?"Detected":"Normal")+"  ";

   color regC=RegimeToColor(g_regime.regime);
   int fsz=14;

   for(int i=0;i<6;i++)
   {
      string nm=OV+"REGIME_OVL_"+IntegerToString(i);
      if(ObjectFind(0,nm)<0)ObjectCreate(0,nm,OBJ_LABEL,0,0,0);
      ObjectSetInteger(0,nm,OBJPROP_CORNER,CORNER_RIGHT_UPPER);
      ObjectSetInteger(0,nm,OBJPROP_XDISTANCE,10);
      ObjectSetInteger(0,nm,OBJPROP_YDISTANCE,10+i*S(20));
      ObjectSetString(0,nm,OBJPROP_TEXT,lines[i]);
      ObjectSetInteger(0,nm,OBJPROP_COLOR,(i==0)?C_WHITE_PURE:(i==1?regC:C_WHITE_SOFT));
      ObjectSetInteger(0,nm,OBJPROP_FONTSIZE,fsz);
      ObjectSetString(0,nm,OBJPROP_FONT,"Segoe UI Bold");
      ObjectSetInteger(0,nm,OBJPROP_SELECTABLE,false);
      ObjectSetInteger(0,nm,OBJPROP_HIDDEN,false);
      ObjectSetInteger(0,nm,OBJPROP_BACK,false);
      ObjectSetInteger(0,nm,OBJPROP_ZORDER,3);
   }
}

//=====================================================================
//  VOLUME SPIKE MARKERS
//=====================================================================
void UpdateVolumeSpikes()
{
   if(!InpDrawVolumeSpikes)return;
   // Mark bars where ATR of that bar >> recent ATR average (volume proxy)
   for(int i=1;i<10;i++)
   {
      double barR=iHigh(_Symbol,PERIOD_M5,i)-iLow(_Symbol,PERIOD_M5,i);
      if(g_vol.atrAvg>0&&barR>g_vol.atrAvg*1.8)
      {
         string nm=OV+"VS_"+IntegerToString(i);
         if(ObjectFind(0,nm)>=0)continue;  // already drawn, skip (anti-flicker)
         double hi=iHigh(_Symbol,PERIOD_M5,i);
         datetime t=iTime(_Symbol,PERIOD_M5,i);
         if(ObjectCreate(0,nm,OBJ_TEXT,0,t,hi+g_vol.atrAvg*0.5))
         {
            ObjectSetString(0,nm,OBJPROP_TEXT,"  VOL SURGE  ");
            ObjectSetInteger(0,nm,OBJPROP_COLOR,C_YELLOW_BRIGHT);
            ObjectSetInteger(0,nm,OBJPROP_FONTSIZE,14);
            ObjectSetString(0,nm,OBJPROP_FONT,"Segoe UI Bold");
            ObjectSetInteger(0,nm,OBJPROP_SELECTABLE,false);
            ObjectSetInteger(0,nm,OBJPROP_HIDDEN,false);
            ObjectSetInteger(0,nm,OBJPROP_BACK,false);
            ObjectSetInteger(0,nm,OBJPROP_ANCHOR,ANCHOR_LOWER);
         }
      }
   }
}

//=====================================================================
//  ENTRY / EXIT MARKERS
//=====================================================================
void DrawEntryMarker(ENUM_DIRECTION dir, double price, ENUM_STRATEGY strat)
{
   if(!InpDrawSignalMarkers)return;
   datetime t=TimeCurrent();
   string nm=OV+"ENTRY_"+IntegerToString((int)t);
   color clr=(dir==DIR_LONG)?C_GREEN_BRIGHT:C_RED_BRIGHT;
   int arr=(dir==DIR_LONG)?233:234;
   if(ObjectCreate(0,nm,OBJ_ARROW,0,t,price))
   {
      ObjectSetInteger(0,nm,OBJPROP_ARROWCODE,arr);ObjectSetInteger(0,nm,OBJPROP_COLOR,clr);
      ObjectSetInteger(0,nm,OBJPROP_WIDTH,4);ObjectSetInteger(0,nm,OBJPROP_SELECTABLE,false);
      ObjectSetInteger(0,nm,OBJPROP_HIDDEN,false);ObjectSetInteger(0,nm,OBJPROP_BACK,false);
      ObjectSetInteger(0,nm,OBJPROP_ANCHOR,(dir==DIR_LONG)?ANCHOR_TOP:ANCHOR_BOTTOM);
   }
   // Strategy label above/below arrow — bright and large
   string nmL=nm+"_L";
   double off=MathMax(g_vol.atrAvg*0.7,SymbolInfoDouble(_Symbol,SYMBOL_POINT)*300);
   double lp2=(dir==DIR_LONG)?price-off:price+off;
   if(ObjectCreate(0,nmL,OBJ_TEXT,0,t,lp2))
   {
      ObjectSetString(0,nmL,OBJPROP_TEXT," "+StrategyToShort(strat)+" ");
      ObjectSetInteger(0,nmL,OBJPROP_COLOR,clr);ObjectSetInteger(0,nmL,OBJPROP_FONTSIZE,14);
      ObjectSetString(0,nmL,OBJPROP_FONT,"Segoe UI Bold");
      ObjectSetInteger(0,nmL,OBJPROP_SELECTABLE,false);ObjectSetInteger(0,nmL,OBJPROP_HIDDEN,false);
      ObjectSetInteger(0,nmL,OBJPROP_BACK,false);ObjectSetInteger(0,nmL,OBJPROP_ANCHOR,ANCHOR_CENTER);
   }
}

void DrawExitMarker(double price, double pnl)
{
   if(!InpDrawSignalMarkers)return;
   datetime t=TimeCurrent();
   string nm=OV+"EXIT_"+IntegerToString((int)t);
   color clr=(pnl>=0)?C_CYAN_BRIGHT:C_PURPLE_BRIGHT;
   if(ObjectCreate(0,nm,OBJ_ARROW,0,t,price))
   {
      ObjectSetInteger(0,nm,OBJPROP_ARROWCODE,251);ObjectSetInteger(0,nm,OBJPROP_COLOR,clr);
      ObjectSetInteger(0,nm,OBJPROP_WIDTH,3);ObjectSetInteger(0,nm,OBJPROP_SELECTABLE,false);
      ObjectSetInteger(0,nm,OBJPROP_HIDDEN,false);ObjectSetInteger(0,nm,OBJPROP_BACK,false);
   }
   string nmL=nm+"_L";
   double off=MathMax(g_vol.atrAvg*0.5,SymbolInfoDouble(_Symbol,SYMBOL_POINT)*200);
   if(ObjectCreate(0,nmL,OBJ_TEXT,0,t,price+off))
   {
      ObjectSetString(0,nmL,OBJPROP_TEXT," "+(pnl>=0?"+":"")+DoubleToString(pnl,2)+" ");
      ObjectSetInteger(0,nmL,OBJPROP_COLOR,clr);ObjectSetInteger(0,nmL,OBJPROP_FONTSIZE,14);
      ObjectSetString(0,nmL,OBJPROP_FONT,"Segoe UI Bold");
      ObjectSetInteger(0,nmL,OBJPROP_SELECTABLE,false);ObjectSetInteger(0,nmL,OBJPROP_HIDDEN,false);
      ObjectSetInteger(0,nmL,OBJPROP_BACK,false);ObjectSetInteger(0,nmL,OBJPROP_ANCHOR,ANCHOR_CENTER);
   }
}

//=====================================================================
//  MASTER OVERLAY UPDATE
//=====================================================================
void UpdateVisualOverlays()
{
   UpdateSessionBoxes();
   UpdateBSLSSL();
   if(InpDrawStructure) UpdateMarketStructure();
   if(InpDrawOrderBlocks) UpdateOrderBlocks();
   if(InpDrawFVG) UpdateFVG();
   if(InpDrawRegimeOverlay) UpdateRegimeOverlay();
   if(InpDrawVolumeSpikes) UpdateVolumeSpikes();
}

void DeleteVisualOverlays(){ObjectsDeleteAll(0,OV);ChartRedraw(0);}

//=====================================================================
//  CHART THEME — Maximum contrast dark
//=====================================================================
void ApplyProfessionalTheme()
{
   long ch=ChartID();
   ChartSetInteger(ch,CHART_MODE,CHART_CANDLES);
   ChartSetInteger(ch,CHART_COLOR_BACKGROUND,  C'5,5,5');
   ChartSetInteger(ch,CHART_COLOR_FOREGROUND,  C_WHITE_PURE);
   ChartSetInteger(ch,CHART_COLOR_GRID,        C'5,5,5');
   ChartSetInteger(ch,CHART_COLOR_CANDLE_BULL, C_GREEN_BRIGHT);
   ChartSetInteger(ch,CHART_COLOR_CANDLE_BEAR, C_RED_BRIGHT);
   ChartSetInteger(ch,CHART_COLOR_CHART_UP,    C_GREEN_BRIGHT);
   ChartSetInteger(ch,CHART_COLOR_CHART_DOWN,  C_RED_BRIGHT);
   ChartSetInteger(ch,CHART_COLOR_CHART_LINE,  C_WHITE_PURE);
   ChartSetInteger(ch,CHART_COLOR_VOLUME,      C_CYAN_BRIGHT);
   ChartSetInteger(ch,CHART_COLOR_BID,         C_GREEN_BRIGHT);
   ChartSetInteger(ch,CHART_COLOR_ASK,         C_RED_BRIGHT);
   ChartSetInteger(ch,CHART_COLOR_STOP_LEVEL,  C_YELLOW_BRIGHT);
   ChartSetInteger(ch,CHART_SHOW_GRID,         false);
   ChartSetInteger(ch,CHART_SHOW_VOLUMES,      true);
   ChartSetInteger(ch,CHART_SHOW_OHLC,         true);
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
   // DPI scale
   g_scale = InpDPIScale / 100.0;
   if(g_scale < 0.5) g_scale = 0.5;
   if(g_scale > 3.0) g_scale = 3.0;

   ApplyProfessionalTheme();

   g_trade.SetExpertMagicNumber(InpMagicNumber);
   g_trade.SetDeviationInPoints(30);
   g_trade.SetTypeFilling(GetFillMode());

   // Indicator handles
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
   if(InpShowAnalystPanel) InitAnalystPanel();

   EventSetTimer(1);

   g_statusText="WARMING UP";g_statusColor=C_ORANGE_BRIGHT;
   g_lastAction="Building buffers...";

   Print("=== QUANTUM PLUS AI v2.0 — AI MARKET ANALYST TERMINAL ===");
   Print("DPI Scale: ",InpDPIScale,"% | Dashboard: ",S(InpDashWidth),"px | Analyst Panel: ",InpShowAnalystPanel?"ON":"OFF");

   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
   EventKillTimer();
   DeleteDash();
   DeleteAnalystPanel();
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
   if(InpShowAnalystPanel)UpdateAnalystPanel();
}

void OnTick()
{
   if(g_lastCloseTime>0){int el=(int)(TimeCurrent()-g_lastCloseTime);g_inCooldown=(el<InpCooldownAfterCloseSec);}
   RolloverDailyWeeklyIfNeeded();

   if(Bars(_Symbol,PERIOD_H1)<InpEMASlowPeriod+5||Bars(_Symbol,PERIOD_M15)<InpEMASlowPeriod+5||
      Bars(_Symbol,PERIOD_M5)<InpATRLookback+5||Bars(_Symbol,PERIOD_M1)<InpEMASlowPeriod+5)
   { g_statusText="BUFFERING";g_statusColor=C_ORANGE_BRIGHT;return; }

   bool nb=IsNewBar();
   UpdateRiskState();

   if(HasManagedPosition()){g_statusText="IN TRADE";g_statusColor=C_GREEN_BRIGHT;return;}

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