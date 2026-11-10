//+------------------------------------------------------------------+
//|         PHANTOM FLUX ADAPTIVE CORE v9.00 - SCALPING GRID           |
//|          Aggressive Bidirectional Execution Engine                 |
//|          Probability-Weighted / Microstructure-Driven Edition      |
//+------------------------------------------------------------------+
//| UPGRADE FROM v8.00 - eight subsystems added:                      |
//|  1. Probability-Based Bidirectional Attack                        |
//|  2. Dynamic Grid Intelligence (tick velocity/accel, ATR accel,    |
//|     spread expansion, session liquidity)                          |
//|  3. Market Microstructure Engine (tick imbalance, exhaustion,     |
//|     compression/expansion)                                        |
//|  4+8. Adaptive Pending Order Engine + Order Synchronization        |
//|     Engine - implemented as ONE unified SynchronizeGrid() that    |
//|     runs on a tick cadence AND fires immediately on every fill,   |
//|     rather than two systems duplicating the same job.             |
//|  5. Execution Quality Engine (slippage + order-placement latency  |
//|     are directly measurable from the terminal; true broker-side   |
//|     network latency is NOT observable here and is not faked -     |
//|     see comments on ExecQuality below)                            |
//|  6. Adaptive Aggression Engine (win/loss streak driven)           |
//|  7. Intelligent Exit System (3 exit clusters per side)            |
//+------------------------------------------------------------------+
#property copyright "Phantom Technologies (c) 2024 - Adaptive Upgrade"
#property version   "9.00"
#property description "Probability-Weighted Adaptive Bidirectional Grid"
#property strict

#include <Trade\Trade.mqh>

#define DASH_PREFIX "PFA_"

//+------------------------------------------------------------------+
//| COLOR PALETTE                                                     |
//+------------------------------------------------------------------+
#define C_BG_ROOT          C'10,13,22'
#define C_BG_HEADER        C'15,20,35'
#define C_BG_SECTION       C'18,24,40'
#define C_BG_ROW_ALT       C'22,30,48'
#define C_BG_BADGE         C'28,36,58'
#define C_BORDER_OUTER     C'40,55,90'
#define C_BORDER_SECTION   C'30,42,68'
#define C_BORDER_ACCENT    C'50,110,220'
#define C_TEXT_BRIGHT      C'230,238,255'
#define C_TEXT_NORMAL      C'175,188,215'
#define C_TEXT_DIM         C'100,118,155'
#define C_TEXT_MUTED       C'65,80,112'
#define C_BRAND_BLUE       C'45,125,255'
#define C_BRAND_CYAN       C'0,200,195'
#define C_BRAND_PURPLE     C'130,90,255'
#define C_GREEN_BRIGHT     C'45,210,110'
#define C_GREEN_DIM        C'25,130,68'
#define C_RED_BRIGHT       C'255,65,78'
#define C_RED_DIM          C'148,35,45'
#define C_YELLOW_BRIGHT    C'255,205,45'
#define C_ORANGE_BRIGHT    C'255,138,45'
#define C_TEAL_BRIGHT      C'35,195,175'
#define C_PILL_LIVE        C'18,148,72'
#define C_PILL_PAUSED      C'148,35,42'
#define C_PILL_TEXT        C'225,242,232'
#define C_PBAR_TRACK       C'20,28,48'
#define C_PBAR_GREEN       C'40,180,98'
#define C_PBAR_RED         C'210,55,65'
#define C_PBAR_YELLOW      C'210,172,35'

enum ExecutionMode { Stealth=1, Adaptive=2, Aggressive=3 };

//+------------------------------------------------------------------+
//| INPUTS                                                            |
//+------------------------------------------------------------------+
input group "=== BIDIRECTIONAL GRID CORE ==="
input ExecutionMode InpMode                = Aggressive;
input int           InpOrdersPoolTotal     = 20;    // total pending orders split by probability across both sides
input bool          InpAutoRecycleStale    = true;

input group "=== ADAPTIVE ENGINE - CORE SIGNALS ==="
input int    InpATRPeriod           = 14;
input int    InpATRSlowPeriod       = 50;
input int    InpVolWindowBars       = 200;
input int    InpMomentumLookback    = 10;
input int    InpMicroCandleLookback = 8;
input int    InpVolumeZWindow       = 50;
input double InpAdaptExtremeVolGate = 0.95;

input group "=== MICROSTRUCTURE ENGINE ==="
input int InpTickBufferSize      = 200;   // rolling tick samples kept for velocity/imbalance
input int InpTickVelocityWindow  = 20;    // ticks used for velocity/acceleration calc
input int InpSpreadAvgWindow     = 50;    // ticks used for spread-expansion baseline
input int InpCompressionBars     = 10;    // bars used for compression/expansion range check

input group "=== PROBABILITY-BASED ATTACK ==="
input double InpProbFloorPct = 8.0;   // never let one side's probability collapse below this
input double InpProbCeilPct  = 92.0;  // never let one side's probability exceed this

input group "=== ADAPTIVE SPACING (ATR multiples, bounds) ==="
input double InpAdaptSpacingMinATR  = 0.020;
input double InpAdaptSpacingMaxATR  = 0.090;

input group "=== ADAPTIVE SL/TP (ATR multiples, bounds) ==="
input double InpAdaptSLMinATR = 0.6;
input double InpAdaptSLMaxATR = 1.6;
input double InpAdaptTPMinATR = 1.2;
input double InpAdaptTPMaxATR = 3.2;

input group "=== ADAPTIVE ORDER COUNT (per side, bounds) ==="
input int InpAdaptOrdersMin = 3;
input int InpAdaptOrdersMax = 18;

input group "=== ADAPTIVE STALE-ORDER LIFETIME (seconds, bounds) ==="
input int InpAdaptLifetimeMinSec = 20;
input int InpAdaptLifetimeMaxSec = 90;

input group "=== ADAPTIVE SCALPING TARGET ($ bounds) ==="
input double InpScalpProfitTargetBase = 0.6;
input double InpAdaptScalpMin = 0.30;
input double InpAdaptScalpMax = 2.00;
input bool   InpUseScalpTarget     = true;
input bool   InpCloseAtScalpTarget = true;

input group "=== INTELLIGENT EXIT CLUSTERS ==="
input double InpCluster1Fraction = 0.30;  // nearest orders: quick-scalp exit
input double InpCluster2Fraction = 0.50;  // mid orders: main impulse target
// remaining fraction = Cluster 3: wide dynamic trail
input double InpCluster1TPFactor = 0.55;  // multiplies dynTPATRMult
input double InpCluster3TPFactor = 1.60;
input double InpCluster3TrailStartFactor = 1.4;
input double InpCluster3TrailFactor      = 0.8;

input group "=== ADAPTIVE AGGRESSION ENGINE ==="
input int    InpAggroWinStreakTrigger  = 3;
input int    InpAggroLossStreakTrigger = 2;
input double InpAggroStep              = 0.06;
input double InpAggroMin               = 0.50;
input double InpAggroMax               = 1.40;
input double InpAggroDecayPerBar       = 0.01; // pulls multiplier back toward 1.0 over time

input group "=== EXECUTION QUALITY ENGINE ==="
input int    InpExecQualitySample   = 20;    // rolling sample size for slippage/latency
input double InpExecQualityFloor    = 0.45;  // below this score, aggression is capped
input double InpExecQualityAggroCap = 0.70;

input group "=== ORDER SYNCHRONIZATION / PENDING ORDER ENGINE ==="
input int InpSyncEveryNTicks   = 15;    // periodic sync cadence
input double InpSyncDriftATR   = 2.5;   // if grid center drifts this many dyn-steps, trim far side

input group "=== RISK MANAGEMENT ==="
input double InpBaseLot      = 0.15;
input double InpRiskPercent  = 0.5;
input double InpMaxTotalLots = 3.0;

input group "=== EXECUTION ENGINE ==="
input bool InpUseTickDrivenMgmt = true;
input int  InpTradeDeviationPts = 5;
input int  InpTimerMs           = 100;

input group "=== POSITION MANAGEMENT (base multiples, scaled live) ==="
input int    InpMaxHoldMinutes      = 60;
input bool   InpForceCloseAtMaxHold = false;
input bool   InpUseBreakeven        = true;
input double InpBreakevenATRBase    = 0.6;
input double InpBreakevenBufferPts  = 10;
input bool   InpUseTrailing         = true;
input double InpTrailStartATRBase   = 1.0;
input double InpTrailATRBase        = 0.5;

input group "=== CIRCUIT BREAKER ==="
input double InpDailyProfitTarget   = 50.0;
input double InpDailyLossLimit      = 30.0;
input bool   InpCloseAllOnLossLimit = true;
input double InpMaxDrawdownPct      = 8.0;

input group "=== ANALYSIS ==="
input ENUM_TIMEFRAMES InpAnalysisTF   = PERIOD_M1;
input int             InpMaxSpreadPts = 80;

input group "=== ADAPTIVE DASHBOARD ==="
input bool InpShowDashboard = true;
input int  InpDashX         = 8;
input int  InpDashY         = 8;

//+------------------------------------------------------------------+
//| GLOBALS                                                           |
//+------------------------------------------------------------------+
CTrade trade;
int    handleATR, handleATRSlow;
int    magic = 990014;

double   dayStartBalance=0.0; int lastDayChecked=-1; double dailyProfit=0.0;
double   peakEquity=0.0; double grossProfit=0.0, grossLoss=0.0;
int      totalWins=0, totalLosses=0; bool tradingEnabled=true;
double   recentProfitFactor=1.0;
double   totalScalpProfit=0.0; int scalpWins=0;

datetime lastTickManagement=0, lastGridDeployTime=0, eaStartTime=0, lastAdaptBarTime=0;
int      tickCounterForSync=0;

int    symbolDigits=0; double symbolPoint=0.0, pipSize=0.0; bool isJPYPair=false;
double   cachedATR=0.0; datetime atrCacheTime=0; double cachedATRSlow=0.0;
double   prevBarATR=0.0; datetime prevBarATRTime=0;

double sparkData[8]; int sparkHead=0;

//+------------------------------------------------------------------+
//| TICK BUFFER (microstructure engine feeds off this)                |
//+------------------------------------------------------------------+
struct TickSample { datetime tsec; long tmsc; double bid; double ask; long vol; };
TickSample tickBuf[];
int tickBufHead=0, tickBufCount=0;

void PushTick()
{
   int n = InpTickBufferSize;
   if(ArraySize(tickBuf) != n) ArrayResize(tickBuf, n);
   MqlTick t;
   if(!SymbolInfoTick(_Symbol, t)) return;
   TickSample s;
   s.tsec = t.time; s.tmsc = (long)t.time_msc; s.bid = t.bid; s.ask = t.ask; s.vol = (long)t.volume;
   tickBuf[tickBufHead % n] = s;
   tickBufHead++;
   if(tickBufCount < n) tickBufCount++;
}

//+------------------------------------------------------------------+
//| EXECUTION QUALITY TRACKING                                       |
//| NOTE ON WHAT'S REAL VS APPROXIMATED:                              |
//|  - Slippage (fill price vs pending order's set price) is a REAL, |
//|    directly computable value from HistoryOrder/HistoryDeal.      |
//|  - "Placement latency" here measures how long trade.BuyStop/      |
//|    SellStop take to return control (terminal<->trade-server round|
//|    trip for placing the order), via GetTickCount(). This is a    |
//|    genuine, measurable proxy for broker responsiveness - it is   |
//|    NOT the same as fill latency (time from price touching the    |
//|    level to the deal executing), which MT5 does not expose       |
//|    directly. Labeled accordingly on the dashboard.                |
//+------------------------------------------------------------------+
struct ExecQuality
{
   double slippageSamples[];
   double latencySamples[];
   int    sampleHead;
   int    sampleCount;
   double avgSlippagePts;
   double avgLatencyMs;
   double qualityScore; // 0..1
};
ExecQuality eq;

void ExecQuality_Init()
{
   ArrayResize(eq.slippageSamples, InpExecQualitySample);
   ArrayResize(eq.latencySamples, InpExecQualitySample);
   ArrayInitialize(eq.slippageSamples, 0.0);
   ArrayInitialize(eq.latencySamples, 0.0);
   eq.sampleHead=0; eq.sampleCount=0; eq.avgSlippagePts=0; eq.avgLatencyMs=0; eq.qualityScore=1.0;
}

void ExecQuality_RecordLatency(double ms)
{
   int n = InpExecQualitySample;
   eq.latencySamples[eq.sampleHead % n] = ms;
   eq.sampleHead++;
   if(eq.sampleCount < n) eq.sampleCount++;
   ExecQuality_Recompute();
}

void ExecQuality_RecordSlippage(double pts)
{
   int n = InpExecQualitySample;
   int idx = (eq.sampleHead>0 ? (eq.sampleHead-1) : 0) % n;
   eq.slippageSamples[idx] = pts;
   ExecQuality_Recompute();
}

void ExecQuality_Recompute()
{
   if(eq.sampleCount <= 0) { eq.qualityScore=1.0; return; }
   double sSum=0, lSum=0;
   int n = MathMin(eq.sampleCount, InpExecQualitySample);
   for(int i=0;i<n;i++) { sSum += MathAbs(eq.slippageSamples[i]); lSum += eq.latencySamples[i]; }
   eq.avgSlippagePts = sSum / n;
   eq.avgLatencyMs = lSum / n;
   double slipPenalty = ClampD(eq.avgSlippagePts / 8.0, 0.0, 1.0);
   double latPenalty  = ClampD((eq.avgLatencyMs - 50.0) / 300.0, 0.0, 1.0);
   eq.qualityScore = ClampD(1.0 - 0.6*slipPenalty - 0.4*latPenalty, 0.0, 1.0);
}

//+------------------------------------------------------------------+
//| AGGRESSION ENGINE STATE                                          |
//+------------------------------------------------------------------+
int    winStreak=0, lossStreak=0;
double aggressionMultiplier=1.0;

void Aggression_OnTradeClosed(double dealProfit)
{
   if(dealProfit > 0) { winStreak++; lossStreak=0; }
   else                { lossStreak++; winStreak=0; }

   if(winStreak >= InpAggroWinStreakTrigger)
      aggressionMultiplier = ClampD(aggressionMultiplier + InpAggroStep, InpAggroMin, InpAggroMax);
   if(lossStreak >= InpAggroLossStreakTrigger)
      aggressionMultiplier = ClampD(aggressionMultiplier - InpAggroStep*1.6, InpAggroMin, InpAggroMax);
}

void Aggression_DecayTick()
{
   if(aggressionMultiplier > 1.0) aggressionMultiplier = MathMax(1.0, aggressionMultiplier - InpAggroDecayPerBar);
   else if(aggressionMultiplier < 1.0) aggressionMultiplier = MathMin(1.0, aggressionMultiplier + InpAggroDecayPerBar);
}

//+------------------------------------------------------------------+
//| Math helpers                                                      |
//+------------------------------------------------------------------+
double TanhApprox(double x) { double e2x=MathExp(2.0*x); return (e2x-1.0)/(e2x+1.0); }
double ClampD(double v,double lo,double hi){ return MathMax(lo,MathMin(hi,v)); }
int    ClampI(int v,int lo,int hi){ return (int)MathMax(lo,MathMin(hi,v)); }

//+------------------------------------------------------------------+
//| ADAPTIVE ENGINE STATE                                            |
//+------------------------------------------------------------------+
struct AdaptiveState
{
   double volRegime, momentumScore, microBias, volumeSurge;

   double tickVelocity;
   double tickAcceleration;
   double atrAcceleration;
   double spreadExpansion;
   double sessionLiquidity;
   double tickImbalance;
   double compressionScore;
   double exhaustionScore;

   double combinedBias;
   double combinedEnergy;

   double bullProbability;
   double bearProbability;
   double buyRiskAlloc;
   double sellRiskAlloc;

   double dynGridStepATR;
   double dynSLATRMult;
   double dynTPATRMult;
   double dynScalpTarget;
   int    dynBuyOrders;
   int    dynSellOrders;
   int    dynLifetimeSec;
   double dynBreakevenATRMult;
   double dynTrailStartATRMult;
   double dynTrailATRMult;

   bool   extremeVolGateActive;
   bool   ready;
};
AdaptiveState ad;

double volHistory[]; int volHistCount=0, volHistHead=0;
double prevVelocity=0.0;
double spreadHistory[]; int spreadHistCount=0, spreadHistHead=0;

// ── Dashboard layout ──────────────────────────────────────────────
struct DashLayout
{
   int px,py,pw,ph,innerW,padX,padY;
   int rowH,sectionGap,headerH,coreH,cardH,adaptH,probH,scalpH,gridH,riskH,perfH,cbH,footerH,secHdrH;
   int fontSmall,fontNormal,fontMed,fontLarge,fontHdr;
   int yHeader,yCore,yCards,yAdapt,yProb,yScalp,yGrid,yRisk,yPerf,yCB,yFooter;
   double spinAngle,pulsePhase; int objCount; bool needRebuild;
};
DashLayout dl;

//+------------------------------------------------------------------+
//| OBJECT WRAPPERS                                                   |
//+------------------------------------------------------------------+
void DRect(string id,int x,int y,int w,int h,color bg,color border=clrNONE,int bw=1,bool back=true)
{
   string n=DASH_PREFIX+id;
   if(ObjectFind(0,n)<0){ObjectCreate(0,n,OBJ_RECTANGLE_LABEL,0,0,0);dl.objCount++;}
   ObjectSetInteger(0,n,OBJPROP_XDISTANCE,x); ObjectSetInteger(0,n,OBJPROP_YDISTANCE,y);
   ObjectSetInteger(0,n,OBJPROP_XSIZE,w); ObjectSetInteger(0,n,OBJPROP_YSIZE,h);
   ObjectSetInteger(0,n,OBJPROP_BGCOLOR,bg); ObjectSetInteger(0,n,OBJPROP_BORDER_TYPE,BORDER_FLAT);
   ObjectSetInteger(0,n,OBJPROP_COLOR,border==clrNONE?bg:border); ObjectSetInteger(0,n,OBJPROP_WIDTH,bw);
   ObjectSetInteger(0,n,OBJPROP_BACK,back); ObjectSetInteger(0,n,OBJPROP_SELECTABLE,false);
   ObjectSetInteger(0,n,OBJPROP_HIDDEN,true);
}
void DText(string id,int x,int y,string txt,color clr,int fsz=8,string font="Arial",ENUM_ANCHOR_POINT anc=ANCHOR_LEFT_UPPER)
{
   string n=DASH_PREFIX+id;
   if(ObjectFind(0,n)<0){ObjectCreate(0,n,OBJ_LABEL,0,0,0);dl.objCount++;}
   ObjectSetInteger(0,n,OBJPROP_XDISTANCE,x); ObjectSetInteger(0,n,OBJPROP_YDISTANCE,y);
   ObjectSetString(0,n,OBJPROP_TEXT,txt); ObjectSetInteger(0,n,OBJPROP_COLOR,clr);
   ObjectSetInteger(0,n,OBJPROP_FONTSIZE,fsz); ObjectSetString(0,n,OBJPROP_FONT,font);
   ObjectSetInteger(0,n,OBJPROP_ANCHOR,anc); ObjectSetInteger(0,n,OBJPROP_SELECTABLE,false);
   ObjectSetInteger(0,n,OBJPROP_HIDDEN,true);
}
void DSetText(string id,string v){string n=DASH_PREFIX+id;if(ObjectFind(0,n)>=0)ObjectSetString(0,n,OBJPROP_TEXT,v);}
void DSetColor(string id,color c){string n=DASH_PREFIX+id;if(ObjectFind(0,n)>=0)ObjectSetInteger(0,n,OBJPROP_COLOR,c);}
void DSetBG(string id,color c){string n=DASH_PREFIX+id;if(ObjectFind(0,n)>=0)ObjectSetInteger(0,n,OBJPROP_BGCOLOR,c);}
void DSetX(string id,int v){string n=DASH_PREFIX+id;if(ObjectFind(0,n)>=0)ObjectSetInteger(0,n,OBJPROP_XDISTANCE,v);}
void DSetY(string id,int v){string n=DASH_PREFIX+id;if(ObjectFind(0,n)>=0)ObjectSetInteger(0,n,OBJPROP_YDISTANCE,v);}
void DSetW(string id,int v){string n=DASH_PREFIX+id;if(ObjectFind(0,n)>=0)ObjectSetInteger(0,n,OBJPROP_XSIZE,v);}
void DSetH(string id,int v){string n=DASH_PREFIX+id;if(ObjectFind(0,n)>=0)ObjectSetInteger(0,n,OBJPROP_YSIZE,v);}

void DrawSecHdr(string id,int y,string icon,string title,color accent)
{
   DRect(id+"_B",dl.px,y,3,dl.secHdrH,accent,accent,0,false);
   DRect(id+"_BG",dl.px+3,y,dl.pw-3,dl.secHdrH,C_BG_HEADER,C_BG_HEADER,0,true);
   DRect(id+"_HL",dl.px+3,y,dl.pw-3,1,accent,accent,0,false);
   DText(id+"_I",dl.px+7,y+2,icon,accent,dl.fontNormal,"Arial Black");
   DText(id+"_T",dl.px+20,y+2,title,C_TEXT_BRIGHT,dl.fontNormal,"Arial Black");
}
void DrawKV(string id,int y,string lbl,string val,color vc,bool alt=false,int rh=-1)
{
   if(rh<0) rh=dl.rowH;
   if(alt) DRect(id+"_BG",dl.px,y,dl.pw,rh,C_BG_ROW_ALT,C_BG_ROW_ALT,0);
   DText(id+"_L",dl.px+dl.padX,y+1,lbl,C_TEXT_DIM,dl.fontNormal,"Arial");
   DText(id+"_V",dl.px+dl.pw-dl.padX,y+1,val,vc,dl.fontNormal,"Consolas",ANCHOR_RIGHT_UPPER);
}
void KVVal(string id,string v,color c=clrNONE){ DSetText(id+"_V",v); if(c!=clrNONE) DSetColor(id+"_V",c); }
void DrawBadge(string id,int x,int y,int w,int h,string txt,color bg,color tc,int fsz=-1)
{
   if(fsz<0) fsz=dl.fontNormal;
   DRect(id+"_BG",x,y,w,h,bg,bg,0,false);
   DText(id+"_T",x+w/2,y+2,txt,tc,fsz,"Arial Black",ANCHOR_CENTER);
}
void BadgeUpd(string id,string txt,color bg,color tc){ DSetText(id+"_T",txt); DSetBG(id+"_BG",bg); DSetColor(id+"_T",tc); }
void DrawPBar(string id,int x,int y,int w,int h,double pct,color fill)
{
   pct=MathMax(0,MathMin(100,pct)); int fw=MathMax(0,(int)MathRound((w-2)*pct/100.0));
   DRect(id+"_T",x,y,w,h,C_PBAR_TRACK,C_BORDER_SECTION,1);
   DRect(id+"_F",x+1,y+1,fw,h-2,fill,fill,0);
}
void PBarUpd(string id,int x,int w,double pct,color fill)
{
   pct=MathMax(0,MathMin(100,pct)); int fw=MathMax(0,(int)MathRound((w-2)*pct/100.0));
   DSetW(id+"_F",fw); DSetBG(id+"_F",fill); DSetX(id+"_F",x+1);
}
void DrawCard(string id,int x,int y,int w,int h,string lbl,string val,string sub,color accent,color vc)
{
   DRect(id+"_BG",x,y,w,h,C_BG_SECTION,C_BORDER_SECTION,1,false);
   DRect(id+"_TOP",x,y,w,2,accent,accent,0,false);
   DText(id+"_L",x+w/2,y+4,lbl,C_TEXT_DIM,dl.fontSmall,"Arial",ANCHOR_CENTER);
   DText(id+"_V",x+w/2,y+h/2-2,val,vc,dl.fontMed,"Arial Black",ANCHOR_CENTER);
   DText(id+"_S",x+w/2,y+h-8,sub,C_TEXT_MUTED,dl.fontSmall,"Arial",ANCHOR_CENTER);
}
void CardUpd(string id,string val,string sub,color vc,color accent=clrNONE)
{
   DSetText(id+"_V",val); DSetColor(id+"_V",vc); DSetText(id+"_S",sub);
   if(accent!=clrNONE) DSetBG(id+"_TOP",accent);
}
void DrawCore(int cx,int cy,int outerR)
{
   DRect("CORE_OR",cx-outerR,cy-outerR,outerR*2,outerR*2,C_BG_BADGE,C_BRAND_BLUE,1,false);
   int ri=outerR-6; color cc=tradingEnabled?C_GREEN_DIM:C_RED_DIM;
   DRect("CORE_IN",cx-ri,cy-ri,ri*2,ri*2,cc,cc,0,false);
   int satR=outerR+8;
   for(int i=0;i<4;i++)
   {
      double a=dl.spinAngle+i*M_PI/2.0;
      int sx=cx+(int)(satR*MathCos(a))-2, sy=cy+(int)(satR*MathSin(a))-2;
      color sc=(i%2==0)?C_BRAND_CYAN:C_BRAND_PURPLE;
      DRect("CORE_S"+IntegerToString(i),sx,sy,5,5,sc,sc,0,false);
   }
   DRect("CORE_CT",cx-2,cy-2,5,5,tradingEnabled?C_GREEN_BRIGHT:C_RED_BRIGHT,tradingEnabled?C_GREEN_BRIGHT:C_RED_BRIGHT,0,false);
}
void UpdateCore(int cx,int cy,int outerR)
{
   dl.spinAngle+=0.07; if(dl.spinAngle>2*M_PI) dl.spinAngle=0;
   dl.pulsePhase+=0.13; if(dl.pulsePhase>2*M_PI) dl.pulsePhase=0;
   double pulse=0.5+0.5*MathSin(dl.pulsePhase);
   int ri=(int)MathRound((outerR-8)+(4*pulse));
   color cc=tradingEnabled?C_GREEN_DIM:C_RED_DIM;
   DSetX("CORE_IN",cx-ri); DSetY("CORE_IN",cy-ri); DSetW("CORE_IN",ri*2); DSetH("CORE_IN",ri*2); DSetBG("CORE_IN",cc);
   int satR=outerR+8;
   for(int i=0;i<4;i++)
   {
      double a=dl.spinAngle+i*M_PI/2.0;
      int sx=cx+(int)(satR*MathCos(a))-2, sy=cy+(int)(satR*MathSin(a))-2;
      DSetX("CORE_S"+IntegerToString(i),sx); DSetY("CORE_S"+IntegerToString(i),sy);
   }
   DSetBG("CORE_CT",tradingEnabled?C_GREEN_BRIGHT:C_RED_BRIGHT);
}
void DrawSparkline(string id,int x,int y,int w,int h)
{
   DRect(id+"_BG",x,y,w,h,C_BG_SECTION,C_BORDER_SECTION,1);
   double mn=1e9,mx=-1e9;
   for(int i=0;i<8;i++){if(sparkData[i]<mn)mn=sparkData[i];if(sparkData[i]>mx)mx=sparkData[i];}
   double rng=mx-mn; if(rng<=0)rng=1;
   int bw=MathMax(1,(w-2)/8);
   for(int i=0;i<8;i++)
   {
      double norm=(sparkData[i]-mn)/rng; int bh=MathMax(1,(int)MathRound(norm*(h-3)));
      int bx=x+1+i*bw, by=y+h-1-bh; color bc=sparkData[i]>=0?C_GREEN_DIM:C_RED_DIM;
      DRect(id+"_B"+IntegerToString(i),bx,by,bw-1,bh,bc,bc,0);
   }
}
void UpdateSparkline(string id,int x,int y,int w,int h)
{
   double mn=1e9,mx=-1e9;
   for(int i=0;i<8;i++){if(sparkData[i]<mn)mn=sparkData[i];if(sparkData[i]>mx)mx=sparkData[i];}
   double rng=mx-mn; if(rng<=0)rng=1;
   int bw=MathMax(1,(w-2)/8);
   for(int i=0;i<8;i++)
   {
      double norm=(sparkData[i]-mn)/rng; int bh=MathMax(1,(int)MathRound(norm*(h-3)));
      int bx=x+1+i*bw, by=y+h-1-bh; color bc=sparkData[i]>=0?C_GREEN_DIM:C_RED_DIM;
      DSetX(id+"_B"+IntegerToString(i),bx); DSetY(id+"_B"+IntegerToString(i),by);
      DSetH(id+"_B"+IntegerToString(i),bh); DSetBG(id+"_B"+IntegerToString(i),bc);
   }
}

//+------------------------------------------------------------------+
//| FIT LAYOUT                                                        |
//+------------------------------------------------------------------+
void FitLayout()
{
   int cw=(int)ChartGetInteger(0,CHART_WIDTH_IN_PIXELS);
   int ch=(int)ChartGetInteger(0,CHART_HEIGHT_IN_PIXELS);
   dl.pw=(int)MathMax(230,MathMin(320,cw*0.27));
   dl.px=InpDashX; dl.py=InpDashY; dl.padX=6; dl.padY=4; dl.innerW=dl.pw-dl.padX*2;
   int avail=ch-dl.py-2; dl.secHdrH=17;
   double scale=(double)avail/860.0; scale=MathMax(0.55,MathMin(1.35,scale));

   dl.headerH=(int)MathRound(54*scale); dl.coreH=(int)MathRound(50*scale); dl.cardH=(int)MathRound(44*scale);
   dl.adaptH=(int)MathRound(126*scale); dl.probH=(int)MathRound(110*scale); dl.scalpH=(int)MathRound(68*scale);
   dl.gridH=(int)MathRound(92*scale); dl.riskH=(int)MathRound(64*scale); dl.perfH=(int)MathRound(88*scale);
   dl.cbH=(int)MathRound(52*scale); dl.footerH=(int)MathRound(34*scale); dl.sectionGap=(int)MathRound(3*scale);

   int totalH = dl.headerH+dl.coreH+dl.cardH
      +(dl.secHdrH+dl.adaptH+dl.sectionGap)+(dl.secHdrH+dl.probH+dl.sectionGap)
      +(dl.secHdrH+dl.scalpH+dl.sectionGap)+(dl.secHdrH+dl.gridH+dl.sectionGap)
      +(dl.secHdrH+dl.riskH+dl.sectionGap)+(dl.secHdrH+dl.perfH+dl.sectionGap)
      +(dl.secHdrH+dl.cbH+dl.sectionGap)+dl.footerH+4;

   if(totalH>avail)
   {
      double shrink=(double)avail/(double)totalH;
      dl.headerH=(int)MathFloor(dl.headerH*shrink); dl.coreH=(int)MathFloor(dl.coreH*shrink);
      dl.cardH=(int)MathFloor(dl.cardH*shrink); dl.adaptH=(int)MathFloor(dl.adaptH*shrink);
      dl.probH=(int)MathFloor(dl.probH*shrink); dl.scalpH=(int)MathFloor(dl.scalpH*shrink);
      dl.gridH=(int)MathFloor(dl.gridH*shrink); dl.riskH=(int)MathFloor(dl.riskH*shrink);
      dl.perfH=(int)MathFloor(dl.perfH*shrink); dl.cbH=(int)MathFloor(dl.cbH*shrink);
      dl.footerH=(int)MathFloor(dl.footerH*shrink); dl.sectionGap=1;
   }

   dl.rowH=MathMax(12,(int)MathRound(15*scale)); dl.rowH=MathMin(dl.rowH,17);
   dl.fontSmall=(scale<0.75)?6:7; dl.fontNormal=(scale<0.75)?7:8;
   dl.fontMed=(scale<0.75)?8:9; dl.fontLarge=(scale<0.75)?9:10; dl.fontHdr=(scale<0.75)?9:11;

   int y=dl.py;
   dl.yHeader=y; y+=dl.headerH;
   dl.yCore=y; y+=dl.coreH;
   dl.yCards=y; y+=dl.cardH+dl.sectionGap;
   dl.yAdapt=y; y+=dl.secHdrH+dl.adaptH+dl.sectionGap;
   dl.yProb=y; y+=dl.secHdrH+dl.probH+dl.sectionGap;
   dl.yScalp=y; y+=dl.secHdrH+dl.scalpH+dl.sectionGap;
   dl.yGrid=y; y+=dl.secHdrH+dl.gridH+dl.sectionGap;
   dl.yRisk=y; y+=dl.secHdrH+dl.riskH+dl.sectionGap;
   dl.yPerf=y; y+=dl.secHdrH+dl.perfH+dl.sectionGap;
   dl.yCB=y; y+=dl.secHdrH+dl.cbH+dl.sectionGap;
   dl.yFooter=y; y+=dl.footerH;
   dl.ph=y-dl.py;
}

//+------------------------------------------------------------------+
//| CORE ATR / VOL HISTORY                                            |
//+------------------------------------------------------------------+
double GetCurrentATR()
{
   datetime now=TimeCurrent();
   if(now==atrCacheTime && cachedATR>0) return cachedATR;
   double buf[]; ArraySetAsSeries(buf,true);
   if(CopyBuffer(handleATR,0,0,1,buf)>0){cachedATR=buf[0];atrCacheTime=now;return cachedATR;}
   return cachedATR>0?cachedATR:0.0001;
}
double GetSlowATR()
{
   double buf[]; ArraySetAsSeries(buf,true);
   if(CopyBuffer(handleATRSlow,0,0,1,buf)>0) cachedATRSlow=buf[0];
   return cachedATRSlow>0?cachedATRSlow:GetCurrentATR();
}
void PushVolHistory(double atrVal)
{
   int n=InpVolWindowBars; if(ArraySize(volHistory)!=n) ArrayResize(volHistory,n);
   volHistory[volHistHead%n]=atrVal; volHistHead++; if(volHistCount<n) volHistCount++;
}
double ComputeVolPercentile(double atrVal)
{
   if(volHistCount<20) return 0.5;
   int below=0; for(int i=0;i<volHistCount;i++) if(volHistory[i]<=atrVal) below++;
   return (double)below/(double)volHistCount;
}

//+------------------------------------------------------------------+
//| MICROSTRUCTURE ENGINE                                            |
//+------------------------------------------------------------------+
double ComputeTickVelocity()
{
   int win = MathMin(InpTickVelocityWindow, tickBufCount);
   if(win < 4) return 0.0;
   int n = ArraySize(tickBuf);
   int idxNow  = (tickBufHead - 1 + n) % n;
   int idxThen = (tickBufHead - win + n) % n;
   double priceNow  = (tickBuf[idxNow].bid + tickBuf[idxNow].ask) / 2.0;
   double priceThen = (tickBuf[idxThen].bid + tickBuf[idxThen].ask) / 2.0;
   double dtMs = (double)(tickBuf[idxNow].tmsc - tickBuf[idxThen].tmsc);
   if(dtMs <= 0) return 0.0;
   double dtSec = dtMs / 1000.0;
   return (priceNow - priceThen) / dtSec;
}

double ComputeTickImbalance()
{
   int win = MathMin(InpTickVelocityWindow, tickBufCount);
   if(win < 4) return 0.0;
   int n = ArraySize(tickBuf);
   int up=0, down=0;
   for(int k=1;k<win;k++)
   {
      int i1 = (tickBufHead - k + n) % n;
      int i0 = (tickBufHead - k - 1 + n) % n;
      double p1 = (tickBuf[i1].bid + tickBuf[i1].ask)/2.0;
      double p0 = (tickBuf[i0].bid + tickBuf[i0].ask)/2.0;
      if(p1 > p0) up++; else if(p1 < p0) down++;
   }
   int total = up + down;
   if(total == 0) return 0.0;
   return (double)(up - down) / (double)total;
}

double ComputeSpreadExpansion()
{
   int n = ArraySize(tickBuf);
   if(tickBufCount < 5) return 1.0;
   int idxNow = (tickBufHead - 1 + n) % n;
   double curSpread = tickBuf[idxNow].ask - tickBuf[idxNow].bid;

   int win = MathMin(InpSpreadAvgWindow, tickBufCount);
   double sum=0; int cnt=0;
   for(int k=0;k<win;k++)
   {
      int idx = (tickBufHead - 1 - k + n) % n;
      sum += (tickBuf[idx].ask - tickBuf[idx].bid); cnt++;
   }
   double avg = (cnt>0) ? sum/cnt : curSpread;
   if(avg <= 0) return 1.0;
   return curSpread / avg;
}

double ComputeSessionLiquidity()
{
   MqlDateTime tm; TimeToStruct(TimeGMT(), tm);
   int h = tm.hour;
   if(h>=12 && h<16) return 1.30;
   if(h>=7  && h<12) return 1.05;
   if(h>=16 && h<20) return 0.95;
   if(h>=0  && h<7)  return 0.55;
   return 0.60;
}

double ComputeCompressionScore(double atr)
{
   int n = InpCompressionBars;
   double hh=-1e10, ll=1e10;
   for(int i=1;i<=n;i++)
   {
      double h=iHigh(_Symbol,InpAnalysisTF,i), l=iLow(_Symbol,InpAnalysisTF,i);
      if(h>hh) hh=h; if(l<ll) ll=l;
   }
   double range = hh-ll;
   double expected = atr * n;
   if(expected<=0) return 0.5;
   double rangeRatio = ClampD(range/expected, 0.0, 1.5);
   return ClampD(1.0 - rangeRatio, 0.0, 1.0);
}

double ComputeExhaustionScore(int lookback)
{
   double lastBody = MathAbs(iClose(_Symbol,InpAnalysisTF,1) - iOpen(_Symbol,InpAnalysisTF,1));
   double lastRange = iHigh(_Symbol,InpAnalysisTF,1) - iLow(_Symbol,InpAnalysisTF,1);
   if(lastRange <= 0) return 0.0;
   double wickFrac = 1.0 - (lastBody/lastRange);

   long vols[]; ArraySetAsSeries(vols,true);
   int n = MathMin(lookback, (int)iBars(_Symbol,InpAnalysisTF)-2);
   if(n<5 || CopyTickVolume(_Symbol,InpAnalysisTF,1,n,vols) < n) return 0.0;
   double mean=0; for(int i=0;i<n;i++) mean+=(double)vols[i]; mean/=n;
   double volRatio = (mean>0) ? (double)vols[0]/mean : 1.0;

   double lastMoveDir = (iClose(_Symbol,InpAnalysisTF,1) > iOpen(_Symbol,InpAnalysisTF,1)) ? 1.0 : -1.0;
   double magnitude = ClampD(wickFrac * MathMin(volRatio/2.0, 1.5), 0.0, 1.0);
   return -lastMoveDir * magnitude;
}

//+------------------------------------------------------------------+
//| MOMENTUM / MICRO-CANDLE BIAS                                      |
//+------------------------------------------------------------------+
double ComputeMomentumScore(int lookback,double atr)
{
   if(atr<=0) return 0.0;
   double c0=iClose(_Symbol,InpAnalysisTF,1), cN=iClose(_Symbol,InpAnalysisTF,lookback+1);
   if(c0==0||cN==0) return 0.0;
   return TanhApprox(((c0-cN)/atr)/3.0);
}
double ComputeMicroBias(int lookback)
{
   double upWick=0, downWick=0;
   for(int i=1;i<=lookback;i++)
   {
      double o=iOpen(_Symbol,InpAnalysisTF,i), c=iClose(_Symbol,InpAnalysisTF,i);
      double h=iHigh(_Symbol,InpAnalysisTF,i), l=iLow(_Symbol,InpAnalysisTF,i);
      double top=MathMax(o,c), bot=MathMin(o,c);
      upWick+=(h-top); downWick+=(bot-l);
   }
   double totalWick=upWick+downWick;
   if(totalWick<=0) return 0.0;
   return ClampD((downWick-upWick)/totalWick,-1.0,1.0);
}
double ComputeVolumeSurge(int window)
{
   int n=MathMin(window,(int)iBars(_Symbol,InpAnalysisTF)-2);
   if(n<10) return 0.0;
   long vols[]; ArraySetAsSeries(vols,true);
   if(CopyTickVolume(_Symbol,InpAnalysisTF,1,n,vols)<n) return 0.0;
   double sum=0; for(int i=0;i<n;i++) sum+=(double)vols[i];
   double mean=sum/n; double sumSq=0;
   for(int i=0;i<n;i++){double d=(double)vols[i]-mean; sumSq+=d*d;}
   double std=MathSqrt(sumSq/n);
   if(std<=0) return 0.0;
   return ((double)vols[0]-mean)/std;
}

//+------------------------------------------------------------------+
//| MASTER ADAPTIVE STATE UPDATE                                      |
//+------------------------------------------------------------------+
void UpdateAdaptiveState()
{
   datetime barTime = iTime(_Symbol, InpAnalysisTF, 0);
   bool newBar = (barTime != lastAdaptBarTime);

   double atr = GetCurrentATR();
   if(atr<=0){ ad.ready=false; return; }

   if(newBar)
   {
      if(prevBarATRTime != 0 && prevBarATR > 0)
         ad.atrAcceleration = (atr - prevBarATR) / prevBarATR;
      prevBarATR = atr; prevBarATRTime = barTime;

      lastAdaptBarTime = barTime;
      PushVolHistory(atr);

      ad.momentumScore = ComputeMomentumScore(InpMomentumLookback, atr);
      ad.microBias      = ComputeMicroBias(InpMicroCandleLookback);
      ad.volumeSurge     = ComputeVolumeSurge(InpVolumeZWindow);
      ad.compressionScore = ComputeCompressionScore(atr);
      ad.exhaustionScore   = ComputeExhaustionScore(InpVolumeZWindow);

      Aggression_DecayTick();
   }

   ad.volRegime = ComputeVolPercentile(atr);
   double vel = ComputeTickVelocity();
   ad.tickAcceleration = vel - prevVelocity;
   prevVelocity = vel;
   ad.tickVelocity = vel;
   ad.tickImbalance = ComputeTickImbalance();
   ad.spreadExpansion = ComputeSpreadExpansion();
   ad.sessionLiquidity = ComputeSessionLiquidity();

   double modeScalar = (InpMode==Aggressive)?1.15:(InpMode==Stealth)?0.80:1.0;

   double atrPerSec = atr / 60.0;
   double velNorm = (atrPerSec>0) ? ClampD(MathAbs(vel)/(atrPerSec*3.0), 0.0, 1.0) : 0.0;
   double accNorm = (atrPerSec>0) ? ClampD(MathAbs(ad.tickAcceleration)/(atrPerSec*3.0), 0.0, 1.0) : 0.0;

   ad.combinedEnergy = 0.28*ad.volRegime
                      + 0.14*velNorm
                      + 0.14*accNorm
                      + 0.14*ClampD(MathAbs(ad.atrAcceleration), 0.0, 1.0)
                      + 0.15*ClampD(MathMax(0.0, ad.spreadExpansion-1.0), 0.0, 1.0)
                      + 0.15*ClampD(1.0 - ad.sessionLiquidity, 0.0, 1.0);
   ad.combinedEnergy = ClampD(ad.combinedEnergy * modeScalar, 0.0, 1.0);

   ad.combinedBias = 0.32*ad.momentumScore
                    + 0.23*ad.microBias
                    + 0.25*ad.tickImbalance
                    + 0.20*ad.exhaustionScore;
   ad.combinedBias = ClampD(ad.combinedBias, -1.0, 1.0);

   ad.bullProbability = ClampD(50.0*(1.0+ad.combinedBias), InpProbFloorPct, InpProbCeilPct);
   ad.bearProbability = 100.0 - ad.bullProbability;
   ad.buyRiskAlloc  = ad.bullProbability/100.0;
   ad.sellRiskAlloc = ad.bearProbability/100.0;

   int poolTotal = ClampI((int)MathRound(InpOrdersPoolTotal * aggressionMultiplier), InpAdaptOrdersMin*2, InpAdaptOrdersMax*2);
   ad.dynBuyOrders  = ClampI((int)MathRound(poolTotal * ad.bullProbability/100.0), InpAdaptOrdersMin, InpAdaptOrdersMax);
   ad.dynSellOrders = ClampI((int)MathRound(poolTotal * ad.bearProbability/100.0), InpAdaptOrdersMin, InpAdaptOrdersMax);

   double compressionAdj = (ad.compressionScore - 0.5) * -0.02;
   ad.dynGridStepATR = ClampD(
      (InpAdaptSpacingMinATR + (InpAdaptSpacingMaxATR-InpAdaptSpacingMinATR)*ad.combinedEnergy + compressionAdj)
      / MathMax(0.5, aggressionMultiplier),
      InpAdaptSpacingMinATR*0.5, InpAdaptSpacingMaxATR*1.5);

   ad.dynSLATRMult = InpAdaptSLMinATR + (InpAdaptSLMaxATR-InpAdaptSLMinATR)*ad.combinedEnergy;
   ad.dynTPATRMult = InpAdaptTPMinATR + (InpAdaptTPMaxATR-InpAdaptTPMinATR)*ad.combinedEnergy;
   if(MathAbs(ad.combinedBias) > 0.4) ad.dynTPATRMult *= (1.0 + 0.5*MathAbs(ad.combinedBias));

   ad.dynLifetimeSec = (int)MathRound(InpAdaptLifetimeMaxSec - (InpAdaptLifetimeMaxSec-InpAdaptLifetimeMinSec)*ad.combinedEnergy);

   double slowAtr = GetSlowATR();
   double atrRatio = (slowAtr>0) ? atr/slowAtr : 1.0;
   ad.dynScalpTarget = ClampD(InpScalpProfitTargetBase*atrRatio, InpAdaptScalpMin, InpAdaptScalpMax);

   double energyStretch = 0.75 + 0.5*ad.combinedEnergy;
   ad.dynBreakevenATRMult  = InpBreakevenATRBase * energyStretch;
   ad.dynTrailStartATRMult = InpTrailStartATRBase * energyStretch;
   ad.dynTrailATRMult      = InpTrailATRBase * energyStretch;

   ad.extremeVolGateActive = (ad.volRegime >= InpAdaptExtremeVolGate);
   ad.ready = (volHistCount >= 20 && tickBufCount >= 20);

   if(eq.qualityScore < InpExecQualityFloor)
      aggressionMultiplier = MathMin(aggressionMultiplier, InpAggroMin);
   else if(eq.qualityScore < InpExecQualityAggroCap)
      aggressionMultiplier = MathMin(aggressionMultiplier, 1.0);
}

//+------------------------------------------------------------------+
//| LOT SIZING - risk-allocation aware                                |
//+------------------------------------------------------------------+
double CalculateLotSizeForSide(double slDistance, double riskAllocFraction)
{
   if(InpRiskPercent<=0) return NormalizeVolume(InpBaseLot);
   double eq2=AccountInfoDouble(ACCOUNT_EQUITY);
   double ra=eq2*InpRiskPercent/100.0*recentProfitFactor*aggressionMultiplier*ClampD(riskAllocFraction*2.0,0.2,1.8);
   double tv=SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_VALUE), ts=SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE);
   if(tv<=0||ts<=0) return NormalizeVolume(InpBaseLot);
   double rpl=(slDistance/ts)*tv;
   if(rpl<=0) return NormalizeVolume(InpBaseLot);
   double energyDamp = (ad.combinedEnergy > 0.85) ? 0.7 : 1.0;
   return NormalizeVolume(ra/rpl*energyDamp);
}
double NormalizeVolume(double vol)
{
   double st=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_STEP), mn=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN), mx=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MAX);
   if(st<=0) st=0.01;
   return NormalizeDouble(MathMax(mn,MathMin(mx,MathRound(vol/st)*st)),2);
}

//+------------------------------------------------------------------+
//| ORDER LIFECYCLE HELPERS                                          |
//+------------------------------------------------------------------+
int DeleteAllPendingOrders()
{
   int d=0;
   for(int i=OrdersTotal()-1;i>=0;i--)
   {
      ulong t=OrderGetTicket(i); if(t==0||!OrderSelect(t)) continue;
      if(OrderGetString(ORDER_SYMBOL)!=_Symbol||OrderGetInteger(ORDER_MAGIC)!=magic) continue;
      if(trade.OrderDelete(t)) d++;
   }
   return d;
}
int DeleteStaleOrders()
{
   if(!InpAutoRecycleStale) return 0;
   datetime now=TimeCurrent(); int d=0;
   for(int i=OrdersTotal()-1;i>=0;i--)
   {
      ulong t=OrderGetTicket(i); if(t==0||!OrderSelect(t)) continue;
      if(OrderGetString(ORDER_SYMBOL)!=_Symbol||OrderGetInteger(ORDER_MAGIC)!=magic) continue;
      int age=(int)(now-(datetime)OrderGetInteger(ORDER_TIME_SETUP));
      if(age>=ad.dynLifetimeSec && trade.OrderDelete(t)) d++;
   }
   return d;
}

string ClusterTag(int index, int count)
{
   int c1n = (int)MathCeil(count * InpCluster1Fraction);
   int c2n = (int)MathCeil(count * InpCluster2Fraction);
   if(index < c1n) return "C1";
   if(index < c1n + c2n) return "C2";
   return "C3";
}

//+------------------------------------------------------------------+
//| DEPLOY BIDIRECTIONAL GRID - probability-weighted, clustered       |
//+------------------------------------------------------------------+
void DeployBidirectionalGrid()
{
   if(!ad.ready) return;
   if(ad.extremeVolGateActive) return;
   if(OrdersTotal()>0){ int d=DeleteStaleOrders(); if(d>0){ lastGridDeployTime=TimeCurrent(); return; } return; }
   if(TimeCurrent()-lastGridDeployTime<5) return;
   if(GetTotalExposure()>=InpMaxTotalLots) return;

   MqlTick tick; if(!SymbolInfoTick(_Symbol,tick)) return;
   double atr=GetCurrentATR(); if(atr<=0) return;
   double mid=(tick.bid+tick.ask)/2.0;
   int digs=symbolDigits;
   long sl=SymbolInfoInteger(_Symbol,SYMBOL_TRADE_STOPS_LEVEL);
   double msd=sl*symbolPoint;
   double sld=MathMax(atr*ad.dynSLATRMult, msd*1.5);
   double tpdBase=atr*ad.dynTPATRMult;
   double gap=atr*ad.dynGridStepATR;
   double fo=gap*2.0;

   double lotBuy  = CalculateLotSizeForSide(sld, ad.buyRiskAlloc);
   double lotSell = CalculateLotSizeForSide(sld, ad.sellRiskAlloc);
   if(lotBuy<SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN) && lotSell<SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN)) return;

   int bc=0, sc=0;
   for(int i=0;i<ad.dynBuyOrders;i++)
   {
      double ep=NormalizeDouble(mid+fo+i*gap,digs);
      if(ep<=tick.ask) continue;
      string tag = ClusterTag(i, ad.dynBuyOrders);
      double tpd = tpdBase;
      if(tag=="C1") tpd *= InpCluster1TPFactor;
      else if(tag=="C3") tpd *= InpCluster3TPFactor;
      double slp=NormalizeDouble(ep-sld,digs), tpp=NormalizeDouble(ep+tpd,digs);
      if((ep-slp)<msd||(tpp-ep)<msd) continue;
      if(lotBuy<SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN)) continue;
      if(PlaceBuyStopTimed(lotBuy,ep,slp,tpp,tag+"_BUY_"+IntegerToString(i+1))) bc++;
   }
   for(int i=0;i<ad.dynSellOrders;i++)
   {
      double ep=NormalizeDouble(mid-fo-i*gap,digs);
      if(ep>=tick.bid) continue;
      string tag = ClusterTag(i, ad.dynSellOrders);
      double tpd = tpdBase;
      if(tag=="C1") tpd *= InpCluster1TPFactor;
      else if(tag=="C3") tpd *= InpCluster3TPFactor;
      double slp=NormalizeDouble(ep+sld,digs), tpp=NormalizeDouble(ep-tpd,digs);
      if((slp-ep)<msd||(ep-tpp)<msd) continue;
      if(lotSell<SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN)) continue;
      if(PlaceSellStopTimed(lotSell,ep,slp,tpp,tag+"_SELL_"+IntegerToString(i+1))) sc++;
   }
   lastGridDeployTime=TimeCurrent();
   Print("GRID deployed: BUY ",bc,"/",ad.dynBuyOrders," (",DoubleToString(ad.bullProbability,0),
         "%) | SELL ",sc,"/",ad.dynSellOrders," (",DoubleToString(ad.bearProbability,0),
         "%) | energy=",DoubleToString(ad.combinedEnergy,2));
}

//+------------------------------------------------------------------+
//| ORDER SYNCHRONIZATION / ADAPTIVE PENDING ORDER ENGINE (unified)   |
//+------------------------------------------------------------------+
void SynchronizeGrid()
{
   if(!ad.ready) return;
   MqlTick tick; if(!SymbolInfoTick(_Symbol,tick)) return;
   double mid=(tick.bid+tick.ask)/2.0;
   double atr=GetCurrentATR(); if(atr<=0) return;
   double gap=atr*ad.dynGridStepATR;
   double driftLimit = gap * InpSyncDriftATR * MathMax(ad.dynBuyOrders, ad.dynSellOrders);

   int buyCount=0, sellCount=0;
   ulong buyTickets[]; ulong sellTickets[];
   double buyDist[]; double sellDist[];

   for(int i=0;i<OrdersTotal();i++)
   {
      ulong t=OrderGetTicket(i); if(t==0||!OrderSelect(t)) continue;
      if(OrderGetString(ORDER_SYMBOL)!=_Symbol||OrderGetInteger(ORDER_MAGIC)!=magic) continue;
      ENUM_ORDER_TYPE ot=(ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
      double ep=OrderGetDouble(ORDER_PRICE_OPEN);
      if(ot==ORDER_TYPE_BUY_STOP)
      {
         ArrayResize(buyTickets,buyCount+1); ArrayResize(buyDist,buyCount+1);
         buyTickets[buyCount]=t; buyDist[buyCount]=MathAbs(ep-mid); buyCount++;
      }
      else if(ot==ORDER_TYPE_SELL_STOP)
      {
         ArrayResize(sellTickets,sellCount+1); ArrayResize(sellDist,sellCount+1);
         sellTickets[sellCount]=t; sellDist[sellCount]=MathAbs(ep-mid); sellCount++;
      }
   }

   if(buyCount > ad.dynBuyOrders)
   {
      int excess = buyCount - ad.dynBuyOrders;
      for(int pass=0; pass<excess; pass++)
      {
         int farIdx=-1; double farDist=-1;
         for(int i=0;i<buyCount;i++) if(buyTickets[i]!=0 && buyDist[i]>farDist){farDist=buyDist[i]; farIdx=i;}
         if(farIdx>=0){ trade.OrderDelete(buyTickets[farIdx]); buyTickets[farIdx]=0; }
      }
   }
   if(sellCount > ad.dynSellOrders)
   {
      int excess = sellCount - ad.dynSellOrders;
      for(int pass=0; pass<excess; pass++)
      {
         int farIdx=-1; double farDist=-1;
         for(int i=0;i<sellCount;i++) if(sellTickets[i]!=0 && sellDist[i]>farDist){farDist=sellDist[i]; farIdx=i;}
         if(farIdx>=0){ trade.OrderDelete(sellTickets[farIdx]); sellTickets[farIdx]=0; }
      }
   }

   double nearestBuy=1e18, nearestSell=1e18;
   for(int i=0;i<buyCount;i++) if(buyTickets[i]!=0 && buyDist[i]<nearestBuy) nearestBuy=buyDist[i];
   for(int i=0;i<sellCount;i++) if(sellTickets[i]!=0 && sellDist[i]<nearestSell) nearestSell=sellDist[i];

   if(nearestBuy < 1e17 && nearestBuy > driftLimit)
      for(int i=0;i<buyCount;i++) if(buyTickets[i]!=0) trade.OrderDelete(buyTickets[i]);
   if(nearestSell < 1e17 && nearestSell > driftLimit)
      for(int i=0;i<sellCount;i++) if(sellTickets[i]!=0) trade.OrderDelete(sellTickets[i]);
}

//+------------------------------------------------------------------+
//| POSITION / EXIT MANAGEMENT - cluster aware                        |
//+------------------------------------------------------------------+
void ManageOCO()
{
   bool hb=false,hs=false;
   for(int i=PositionsTotal()-1;i>=0;i--)
   {
      ulong t=PositionGetTicket(i); if(t==0||!PositionSelectByTicket(t)) continue;
      if(PositionGetString(POSITION_SYMBOL)!=_Symbol||PositionGetInteger(POSITION_MAGIC)!=magic) continue;
      if(PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_BUY) hb=true; else hs=true;
   }
   if(!hb&&!hs) return;
   for(int i=OrdersTotal()-1;i>=0;i--)
   {
      ulong t=OrderGetTicket(i); if(t==0||!OrderSelect(t)) continue;
      if(OrderGetString(ORDER_SYMBOL)!=_Symbol||OrderGetInteger(ORDER_MAGIC)!=magic) continue;
      ENUM_ORDER_TYPE ot=(ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
      if(hb&&(ot==ORDER_TYPE_SELL_STOP||ot==ORDER_TYPE_SELL_LIMIT)) trade.OrderDelete(t);
      else if(hs&&(ot==ORDER_TYPE_BUY_STOP||ot==ORDER_TYPE_BUY_LIMIT)) trade.OrderDelete(t);
   }
}

void ManageScalpTarget()
{
   if(!InpUseScalpTarget||!InpCloseAtScalpTarget) return;
   for(int i=PositionsTotal()-1;i>=0;i--)
   {
      ulong t=PositionGetTicket(i); if(t==0||!PositionSelectByTicket(t)) continue;
      if(PositionGetString(POSITION_SYMBOL)!=_Symbol||PositionGetInteger(POSITION_MAGIC)!=magic) continue;
      string cmt = PositionGetString(POSITION_COMMENT);
      bool isC1 = (StringFind(cmt,"C1_")==0);
      if(!isC1) continue;
      double pr=PositionGetDouble(POSITION_PROFIT)+PositionGetDouble(POSITION_SWAP)+PositionGetDouble(POSITION_COMMISSION);
      if(pr>=ad.dynScalpTarget && trade.PositionClose(t))
      { scalpWins++; totalScalpProfit+=pr; SparklineAdd(pr); }
   }
}

void ManagePositions()
{
   double atr=GetCurrentATR(); if(atr<=0) return;
   int digs=symbolDigits;
   double msd=SymbolInfoInteger(_Symbol,SYMBOL_TRADE_STOPS_LEVEL)*symbolPoint;
   for(int i=PositionsTotal()-1;i>=0;i--)
   {
      ulong t=PositionGetTicket(i); if(t==0||!PositionSelectByTicket(t)) continue;
      if(PositionGetString(POSITION_SYMBOL)!=_Symbol||PositionGetInteger(POSITION_MAGIC)!=magic) continue;
      string cmt = PositionGetString(POSITION_COMMENT);
      bool isC3 = (StringFind(cmt,"C3_")==0);

      ENUM_POSITION_TYPE pt=(ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      double op=PositionGetDouble(POSITION_PRICE_OPEN);
      double csl=PositionGetDouble(POSITION_SL), ctp=PositionGetDouble(POSITION_TP);
      double bid=SymbolInfoDouble(_Symbol,SYMBOL_BID), ask=SymbolInfoDouble(_Symbol,SYMBOL_ASK);
      double cur=(pt==POSITION_TYPE_BUY)?bid:ask;
      double pd=(pt==POSITION_TYPE_BUY)?(cur-op):(op-cur);
      double nsl=csl; bool mod=false;

      double beMult = ad.dynBreakevenATRMult;
      double trailStartMult = isC3 ? ad.dynTrailStartATRMult*InpCluster3TrailStartFactor : ad.dynTrailStartATRMult;
      double trailMult = isC3 ? ad.dynTrailATRMult*InpCluster3TrailFactor : ad.dynTrailATRMult;

      if(InpUseBreakeven && pd>=beMult*atr)
      {
         double be=(pt==POSITION_TYPE_BUY)?op+InpBreakevenBufferPts*symbolPoint:op-InpBreakevenBufferPts*symbolPoint;
         if((pt==POSITION_TYPE_BUY&&(csl==0||csl<be))||(pt==POSITION_TYPE_SELL&&(csl==0||csl>be))){nsl=be;mod=true;}
      }
      if(InpUseTrailing && pd>=trailStartMult*atr)
      {
         double tp2=(pt==POSITION_TYPE_BUY)?cur-trailMult*atr:cur+trailMult*atr;
         if((pt==POSITION_TYPE_BUY&&tp2>nsl)||(pt==POSITION_TYPE_SELL&&(nsl==0||tp2<nsl))){nsl=tp2;mod=true;}
      }
      if(mod)
      {
         nsl=NormalizeDouble(nsl,digs);
         if(pt==POSITION_TYPE_BUY&&(bid-nsl)<msd) continue;
         if(pt==POSITION_TYPE_SELL&&(nsl-ask)<msd) continue;
         trade.PositionModify(t,nsl,ctp);
      }
   }
}

void ManageMaxHoldTime()
{
   if(InpMaxHoldMinutes<=0) return;
   datetime now=TimeCurrent();
   for(int i=PositionsTotal()-1;i>=0;i--)
   {
      ulong t=PositionGetTicket(i); if(t==0||!PositionSelectByTicket(t)) continue;
      if(PositionGetString(POSITION_SYMBOL)!=_Symbol||PositionGetInteger(POSITION_MAGIC)!=magic) continue;
      double held=(now-(datetime)PositionGetInteger(POSITION_TIME))/60.0;
      if(held>=InpMaxHoldMinutes)
      {
         if(InpForceCloseAtMaxHold) trade.PositionClose(t);
         else if(PositionGetDouble(POSITION_PROFIT)<=0) trade.PositionClose(t);
      }
   }
}

double GetTotalExposure()
{
   double tot=0;
   for(int i=PositionsTotal()-1;i>=0;i--)
   {
      ulong t=PositionGetTicket(i);
      if(t>0&&PositionSelectByTicket(t)&&PositionGetString(POSITION_SYMBOL)==_Symbol&&PositionGetInteger(POSITION_MAGIC)==magic)
         tot+=PositionGetDouble(POSITION_VOLUME);
   }
   for(int i=OrdersTotal()-1;i>=0;i--)
   {
      ulong t=OrderGetTicket(i);
      if(t>0&&OrderSelect(t)&&OrderGetString(ORDER_SYMBOL)==_Symbol&&OrderGetInteger(ORDER_MAGIC)==magic)
         tot+=OrderGetDouble(ORDER_VOLUME_CURRENT);
   }
   return tot;
}

void CheckCircuitBreaker()
{
   double eqNow=AccountInfoDouble(ACCOUNT_EQUITY);
   peakEquity=MathMax(peakEquity,eqNow);
   MqlDateTime tm; TimeToStruct(TimeCurrent(),tm);
   if(tm.day!=lastDayChecked)
   {
      dayStartBalance=AccountInfoDouble(ACCOUNT_BALANCE);
      lastDayChecked=tm.day; tradingEnabled=true;
      grossProfit=grossLoss=0; totalWins=totalLosses=0;
   }
   dailyProfit=eqNow-dayStartBalance;
   if(dailyProfit>=InpDailyProfitTarget) tradingEnabled=false;
   else if(dailyProfit<=-InpDailyLossLimit)
   {
      tradingEnabled=false;
      if(InpCloseAllOnLossLimit)
      {
         for(int i=PositionsTotal()-1;i>=0;i--)
         { ulong t=PositionGetTicket(i);
           if(t>0&&PositionSelectByTicket(t)&&PositionGetString(POSITION_SYMBOL)==_Symbol&&PositionGetInteger(POSITION_MAGIC)==magic) trade.PositionClose(t); }
         DeleteAllPendingOrders();
      }
   }
   if(eqNow<peakEquity*(1-InpMaxDrawdownPct/100.0)) recentProfitFactor=0.6;
}

void UpdateProfitFactor()
{
   if(grossLoss>0) recentProfitFactor=grossProfit/grossLoss;
   else if(grossProfit>0) recentProfitFactor=1.5;
   else recentProfitFactor=1.0;
   recentProfitFactor=MathMax(0.5,MathMin(recentProfitFactor,2.0));
}
void SparklineAdd(double v){ sparkData[sparkHead%8]=v; sparkHead++; }

//+------------------------------------------------------------------+
//| DASHBOARD BUILD                                                   |
//+------------------------------------------------------------------+
void BuildDashboard()
{
   ObjectsDeleteAll(0,DASH_PREFIX); dl.objCount=0; FitLayout();
   int px=dl.px, pw=dl.pw;

   DRect("ROOT",px,dl.py,pw,dl.ph,C_BG_ROOT,C_BORDER_OUTER,2);
   DRect("ROOT_TL",px+2,dl.py+2,pw-4,2,C_BORDER_ACCENT,C_BORDER_ACCENT,0);

   { int y=dl.yHeader,h=dl.headerH;
     DRect("HDR_BG",px,y,pw,h,C_BG_HEADER,C_BG_HEADER,0);
     DRect("HDR_A1",px,y,pw,2,C_BRAND_BLUE,C_BRAND_BLUE,0,false);
     DRect("HDR_A2",px,y+2,pw,1,C_BRAND_CYAN,C_BRAND_CYAN,0,false);
     DText("HDR_PH",px+dl.padX,y+4,"PHANTOM FLUX",C_BRAND_BLUE,dl.fontHdr,"Arial Black");
     DText("HDR_CO",px+dl.padX,y+4+dl.fontHdr+3,"ADAPTIVE v9.00",C_BRAND_CYAN,dl.fontMed,"Arial Black");
     DText("HDR_SUB",px+dl.padX,y+h-10,"Probability-Weighted / Microstructure",C_TEXT_DIM,dl.fontSmall,"Arial");
     int bdW=64,bdH=MathMin(16,h/3);
     DrawBadge("HDR_ST",px+pw-bdW-dl.padX,y+5,bdW,bdH,tradingEnabled?"LIVE":"PAUSE",tradingEnabled?C_PILL_LIVE:C_PILL_PAUSED,C_PILL_TEXT,dl.fontSmall);
     string tfS=EnumToString(InpAnalysisTF); StringReplace(tfS,"PERIOD_","");
     DrawBadge("HDR_SYMTF",px+pw-bdW-dl.padX,y+bdH+8,bdW,bdH,_Symbol+" "+tfS,C_BG_BADGE,C_BRAND_CYAN,dl.fontSmall);
   }

   { int y=dl.yCore,h=dl.coreH;
     DRect("ENG_BG",px,y,pw,h,C_BG_SECTION,C_BORDER_SECTION,1);
     int outerR=MathMax(10,h/2-4); int cx=px+outerR+14, cy=y+h/2;
     DrawCore(cx,cy,outerR);
     int tx=cx+outerR+12;
     string modeStr=(InpMode==Aggressive)?"AGGRESSIVE":(InpMode==Stealth)?"STEALTH":"ADAPTIVE";
     color modeClr=(InpMode==Aggressive)?C_RED_BRIGHT:(InpMode==Stealth)?C_BRAND_CYAN:C_YELLOW_BRIGHT;
     DText("ENG_ML",tx,y+3,"MODE",C_TEXT_DIM,dl.fontSmall,"Arial");
     DText("ENG_MV",tx,y+3+dl.fontSmall+2,modeStr,modeClr,dl.fontNormal,"Arial Black");
     DText("ENG_AL",tx+70,y+3,"ATR",C_TEXT_DIM,dl.fontSmall,"Arial");
     DText("ENG_AV",tx+70,y+3+dl.fontSmall+2,"---",C_YELLOW_BRIGHT,dl.fontNormal,"Consolas");
     DText("ENG_SL",tx,y+h-dl.fontSmall-7,"SPD",C_TEXT_DIM,dl.fontSmall,"Arial");
     DText("ENG_SV",tx+20,y+h-dl.fontSmall-7,"---",C_TEXT_NORMAL,dl.fontSmall,"Consolas");
     DText("ENG_MAL",tx+70,y+h-dl.fontSmall-7,"AGX",C_TEXT_DIM,dl.fontSmall,"Arial");
     DText("ENG_MAV",tx+90,y+h-dl.fontSmall-7,"1.00",C_TEXT_MUTED,dl.fontSmall,"Consolas");
   }

   { int y=dl.yCards,h=dl.cardH; int gap=2,cw=(dl.innerW-gap*2)/3; int x0=px+dl.padX;
     DrawCard("CB",x0,y,cw,h,"BALANCE","$"+DoubleToString(AccountInfoDouble(ACCOUNT_BALANCE),2),"Account",C_BRAND_BLUE,C_TEXT_BRIGHT);
     DrawCard("CE",x0+cw+gap,y,cw,h,"EQUITY","$"+DoubleToString(AccountInfoDouble(ACCOUNT_EQUITY),2),"Current",C_BRAND_CYAN,C_TEAL_BRIGHT);
     DrawCard("CP",x0+(cw+gap)*2,y,cw,h,"DAILY P/L","$0.00","Today",C_GREEN_BRIGHT,C_GREEN_BRIGHT);
   }

   { int sy=dl.yAdapt; DrawSecHdr("SH_AE",sy,"A","ADAPTIVE ENGINE",C_BRAND_PURPLE);
     int y=sy+dl.secHdrH,h=dl.adaptH; DRect("AE_BG",px,y,pw,h,C_BG_SECTION,C_BORDER_SECTION,1);
     int kvH=dl.rowH; int ky=y;
     DrawKV("AE_VR",ky,"Vol Regime","--%",C_YELLOW_BRIGHT,false,kvH); ky+=kvH;
     DrawKV("AE_MO",ky,"Momentum","0.00",C_TEXT_NORMAL,true,kvH); ky+=kvH;
     DrawKV("AE_MB",ky,"Micro Bias","0.00",C_TEXT_NORMAL,false,kvH); ky+=kvH;
     DrawKV("AE_TV",ky,"Tick Velocity","0.00",C_TEAL_BRIGHT,true,kvH); ky+=kvH;
     DrawKV("AE_TI",ky,"Tick Imbalance","0.00",C_TEAL_BRIGHT,false,kvH); ky+=kvH;
     DrawKV("AE_CX",ky,"Compress/Exhaust","0.00 / 0.00",C_TEXT_NORMAL,true,kvH); ky+=kvH;
     DrawKV("AE_EN",ky,"Energy","0.00",C_ORANGE_BRIGHT,false,kvH); ky+=kvH;
     if(h-(ky-y)>=kvH){ DrawKV("AE_GATE",ky,"Vol Gate","OFF",C_GREEN_BRIGHT,true,kvH); ky+=kvH; }
   }

   { int sy=dl.yProb; DrawSecHdr("SH_PR",sy,"%","PROBABILITY & EXECUTION",C_BRAND_BLUE);
     int y=sy+dl.secHdrH,h=dl.probH; DRect("PR_BG",px,y,pw,h,C_BG_SECTION,C_BORDER_SECTION,1);
     int kvH=dl.rowH; int ky=y;
     DrawKV("PR_BU",ky,"Bull / Bear","--% / --%",C_GREEN_BRIGHT,false,kvH); ky+=kvH;
     DrawKV("PR_RA",ky,"Risk Alloc B/S","--% / --%",C_YELLOW_BRIGHT,true,kvH); ky+=kvH;
     DrawKV("PR_AG",ky,"Aggression","1.00x",C_BRAND_PURPLE,false,kvH); ky+=kvH;
     DrawKV("PR_ST",ky,"Streak W/L","0 / 0",C_TEXT_NORMAL,true,kvH); ky+=kvH;
     DrawKV("PR_EQ",ky,"Exec Quality","100%",C_GREEN_BRIGHT,false,kvH); ky+=kvH;
     if(h-(ky-y)>=kvH){ DrawKV("PR_SL",ky,"Avg Slip/Lat","0.0p / 0ms",C_TEXT_NORMAL,true,kvH); ky+=kvH; }
   }

   { int sy=dl.yScalp; DrawSecHdr("SH_SC",sy,"$","SCALPING TARGET (adaptive)",C_GREEN_BRIGHT);
     int y=sy+dl.secHdrH,h=dl.scalpH; DRect("SC_BG",px,y,pw,h,C_BG_SECTION,C_BORDER_SECTION,1);
     int usedH=0; int kvH=dl.rowH;
     DrawKV("SC_TGT",y+usedH,"C1 Target","$"+DoubleToString(ad.dynScalpTarget,2),C_YELLOW_BRIGHT,false,kvH); usedH+=kvH;
     DrawKV("SC_WIN",y+usedH,"Scalp Wins",IntegerToString(scalpWins),C_GREEN_BRIGHT,true,kvH); usedH+=kvH;
     DrawKV("SC_PRF",y+usedH,"Scalp Profit","$0.00",C_GREEN_BRIGHT,false,kvH); usedH+=kvH;
     int pbH=6,pbM=3;
     if(h-usedH>=pbH+pbM+dl.fontSmall+2)
     { int pbY=y+usedH+pbM;
       DText("SC_PBL",px+dl.padX,pbY,"-> Daily Target Progress",C_TEXT_MUTED,dl.fontSmall,"Arial");
       DrawPBar("SC_PB",px+dl.padX,pbY+dl.fontSmall+1,dl.innerW,pbH,0.0,C_PBAR_GREEN); }
   }

   { int sy=dl.yGrid; DrawSecHdr("SH_GR",sy,"#","GRID STATUS (adaptive)",C_YELLOW_BRIGHT);
     int y=sy+dl.secHdrH,h=dl.gridH; DRect("GR_BG",px,y,pw,h,C_BG_SECTION,C_BORDER_SECTION,1);
     int boxH=MathMin(26,h/3),boxW=(dl.innerW-4)/2; int bx0=px+dl.padX, bx1=px+dl.padX+boxW+4;
     DRect("GR_BBX",bx0,y+2,boxW,boxH,C_BG_BADGE,C_GREEN_DIM,1,false);
     DRect("GR_SBX",bx1,y+2,boxW,boxH,C_BG_BADGE,C_RED_DIM,1,false);
     DText("GR_BL",bx0+boxW/2,y+3,"BUY",C_GREEN_BRIGHT,dl.fontSmall,"Arial",ANCHOR_CENTER);
     DText("GR_BV",bx0+boxW/2,y+3+dl.fontSmall+1,"0",C_GREEN_BRIGHT,dl.fontMed,"Arial Black",ANCHOR_CENTER);
     DText("GR_SL",bx1+boxW/2,y+3,"SELL",C_RED_BRIGHT,dl.fontSmall,"Arial",ANCHOR_CENTER);
     DText("GR_SV",bx1+boxW/2,y+3+dl.fontSmall+1,"0",C_RED_BRIGHT,dl.fontMed,"Arial Black",ANCHOR_CENTER);
     int ky=y+boxH+4; int kvH=dl.rowH;
     DrawKV("GR_BP",ky,"Buy Positions","0",C_GREEN_BRIGHT,false,kvH); ky+=kvH;
     DrawKV("GR_SP",ky,"Sell Positions","0",C_RED_BRIGHT,true,kvH); ky+=kvH;
     DrawKV("GR_AG",ky,"Order Age","0s / ---s",C_TEXT_NORMAL,false,kvH); ky+=kvH;
     DrawKV("GR_EX",ky,"Exposure","0.00/"+DoubleToString(InpMaxTotalLots,2)+"L",C_ORANGE_BRIGHT,true,kvH);
   }

   { int sy=dl.yRisk; DrawSecHdr("SH_RI",sy,"R","RISK ENGINE (adaptive)",C_BRAND_BLUE);
     int y=sy+dl.secHdrH,h=dl.riskH; DRect("RI_BG",px,y,pw,h,C_BG_SECTION,C_BORDER_SECTION,1);
     int kvH=dl.rowH; int ky=y;
     DrawKV("RI_SL",ky,"SL"," --- ",C_RED_BRIGHT,false,kvH); ky+=kvH;
     DrawKV("RI_TP",ky,"TP"," --- ",C_GREEN_BRIGHT,true,kvH); ky+=kvH;
     DrawKV("RI_LT",ky,"Lot B/S"," --- ",C_BRAND_CYAN,false,kvH); ky+=kvH;
     int pbH=6;
     if(h-(ky-y)>=pbH+dl.fontSmall+4)
     { DText("RI_DDL",px+dl.padX,ky+1,"Drawdown",C_TEXT_DIM,dl.fontSmall,"Arial");
       DText("RI_DDV",px+pw-dl.padX,ky+1,"0.00%",C_TEXT_NORMAL,dl.fontSmall,"Consolas",ANCHOR_RIGHT_UPPER);
       ky+=dl.fontSmall+2; DrawPBar("RI_DD",px+dl.padX,ky,dl.innerW,pbH,0.0,C_PBAR_GREEN); }
   }

   { int sy=dl.yPerf; DrawSecHdr("SH_PF",sy,"P","PERFORMANCE",C_BRAND_PURPLE);
     int y=sy+dl.secHdrH,h=dl.perfH; DRect("PF_BG",px,y,pw,h,C_BG_SECTION,C_BORDER_SECTION,1);
     int kvH=dl.rowH; int ky=y;
     DrawKV("PF_WL",ky,"W/L","0/0",C_TEXT_BRIGHT,false,kvH); ky+=kvH;
     DrawKV("PF_WR",ky,"Win Rate","0.0%",C_GREEN_BRIGHT,true,kvH); ky+=kvH;
     DrawKV("PF_PF",ky,"P.Factor","1.00",C_YELLOW_BRIGHT,false,kvH); ky+=kvH;
     DrawKV("PF_GP",ky,"Gross Win","+$0.00",C_GREEN_BRIGHT,true,kvH); ky+=kvH;
     DrawKV("PF_GL",ky,"Gross Loss","-$0.00",C_RED_BRIGHT,false,kvH); ky+=kvH;
     int spH=MathMin(16,h-(ky-y)-4);
     if(spH>=6){ DText("PF_SPL",px+dl.padX,ky+1,"Sparkline",C_TEXT_MUTED,dl.fontSmall,"Arial");
       DrawSparkline("PF_SP",px+dl.padX,ky+dl.fontSmall+2,dl.innerW,spH); }
   }

   { int sy=dl.yCB; DrawSecHdr("SH_CB",sy,"!","CIRCUIT BREAKER",C_ORANGE_BRIGHT);
     int y=sy+dl.secHdrH,h=dl.cbH; DRect("CB_BG",px,y,pw,h,C_BG_SECTION,C_BORDER_SECTION,1);
     int kvH=dl.rowH;
     DrawKV("CB_DP",y,"Profit Target","+$"+DoubleToString(InpDailyProfitTarget,2),C_GREEN_BRIGHT,false,kvH);
     DrawKV("CB_DL",y+kvH,"Loss Limit","-$"+DoubleToString(InpDailyLossLimit,2),C_RED_BRIGHT,true,kvH);
     if(h>=kvH*3) DrawKV("CB_MD",y+kvH*2,"Max DD",DoubleToString(InpMaxDrawdownPct,1)+"%",C_ORANGE_BRIGHT,false,kvH);
   }

   { int y=dl.yFooter,h=dl.footerH;
     DRect("FT_BG",px,y,pw,h,C_BG_HEADER,C_BORDER_SECTION,1);
     DRect("FT_TOP",px,y,pw,1,C_BORDER_ACCENT,C_BORDER_ACCENT,0);
     DText("FT_BRK",px+dl.padX,y+2,AccountInfoString(ACCOUNT_COMPANY),C_TEXT_MUTED,dl.fontSmall,"Arial");
     DText("FT_RT",px+dl.padX,y+h/2+1,"Runtime: 0h 0m",C_BRAND_CYAN,dl.fontSmall,"Consolas");
     DText("FT_CR",px+pw-dl.padX,y+h/2+1,"PhantomTech",C_TEXT_MUTED,dl.fontSmall,"Arial",ANCHOR_RIGHT_UPPER);
   }

   dl.needRebuild=false; ChartRedraw();
}

//+------------------------------------------------------------------+
//| DASHBOARD UPDATE                                                  |
//+------------------------------------------------------------------+
void UpdateDashboard()
{
   if(!InpShowDashboard) return;
   if(dl.needRebuild){ BuildDashboard(); return; }
   int px=dl.px, pw=dl.pw;

   int outerR=MathMax(10,dl.coreH/2-4); int cx=px+outerR+14, cy=dl.yCore+dl.coreH/2;
   UpdateCore(cx,cy,outerR);
   BadgeUpd("HDR_ST",tradingEnabled?"LIVE":"PAUSE",tradingEnabled?C_PILL_LIVE:C_PILL_PAUSED,C_PILL_TEXT);

   double atr=GetCurrentATR(); double atrP=(pipSize>0)?atr/pipSize:0;
   long sprd=SymbolInfoInteger(_Symbol,SYMBOL_SPREAD);
   DSetText("ENG_AV",DoubleToString(atrP,1));
   DSetText("ENG_SV",IntegerToString((int)sprd)+"pt");
   DSetColor("ENG_SV",sprd>InpMaxSpreadPts?C_RED_BRIGHT:C_GREEN_BRIGHT);
   DSetText("ENG_MAV",DoubleToString(aggressionMultiplier,2)+"x");

   double bal=AccountInfoDouble(ACCOUNT_BALANCE), equ=AccountInfoDouble(ACCOUNT_EQUITY);
   CardUpd("CB","$"+DoubleToString(bal,2),"Account",C_TEXT_BRIGHT);
   CardUpd("CE","$"+DoubleToString(equ,2),"Current",C_TEAL_BRIGHT);
   color dpClr=dailyProfit>=0?C_GREEN_BRIGHT:C_RED_BRIGHT;
   CardUpd("CP",(dailyProfit>=0?"+$":"-$")+DoubleToString(MathAbs(dailyProfit),2),"Today",dpClr,dpClr);

   color vrClr=ad.volRegime>0.8?C_RED_BRIGHT:ad.volRegime>0.5?C_ORANGE_BRIGHT:C_GREEN_BRIGHT;
   KVVal("AE_VR",DoubleToString(ad.volRegime*100,0)+"%",vrClr);
   KVVal("AE_MO",DoubleToString(ad.momentumScore,2),ad.momentumScore>0?C_GREEN_BRIGHT:C_RED_BRIGHT);
   KVVal("AE_MB",DoubleToString(ad.microBias,2),ad.microBias>0?C_GREEN_BRIGHT:C_RED_BRIGHT);
   KVVal("AE_TV",DoubleToString(ad.tickVelocity,4),C_TEAL_BRIGHT);
   KVVal("AE_TI",DoubleToString(ad.tickImbalance,2),ad.tickImbalance>0?C_GREEN_BRIGHT:C_RED_BRIGHT);
   KVVal("AE_CX",DoubleToString(ad.compressionScore,2)+" / "+DoubleToString(ad.exhaustionScore,2),C_TEXT_NORMAL);
   color enClr=ad.combinedEnergy>0.7?C_RED_BRIGHT:ad.combinedEnergy>0.4?C_ORANGE_BRIGHT:C_TEAL_BRIGHT;
   KVVal("AE_EN",DoubleToString(ad.combinedEnergy,2),enClr);
   KVVal("AE_GATE",ad.extremeVolGateActive?"ACTIVE-PAUSED":"off",ad.extremeVolGateActive?C_RED_BRIGHT:C_GREEN_BRIGHT);

   KVVal("PR_BU",DoubleToString(ad.bullProbability,0)+"% / "+DoubleToString(ad.bearProbability,0)+"%",
         ad.bullProbability>ad.bearProbability?C_GREEN_BRIGHT:C_RED_BRIGHT);
   KVVal("PR_RA",DoubleToString(ad.buyRiskAlloc*100,0)+"% / "+DoubleToString(ad.sellRiskAlloc*100,0)+"%",C_YELLOW_BRIGHT);
   color agClr = aggressionMultiplier>1.05?C_GREEN_BRIGHT:aggressionMultiplier<0.95?C_RED_BRIGHT:C_TEXT_NORMAL;
   KVVal("PR_AG",DoubleToString(aggressionMultiplier,2)+"x",agClr);
   KVVal("PR_ST",IntegerToString(winStreak)+" / "+IntegerToString(lossStreak),C_TEXT_NORMAL);
   color eqClr = eq.qualityScore>0.7?C_GREEN_BRIGHT:eq.qualityScore>InpExecQualityFloor?C_ORANGE_BRIGHT:C_RED_BRIGHT;
   KVVal("PR_EQ",DoubleToString(eq.qualityScore*100,0)+"%",eqClr);
   KVVal("PR_SL",DoubleToString(eq.avgSlippagePts,1)+"p / "+DoubleToString(eq.avgLatencyMs,0)+"ms",C_TEXT_NORMAL);

   KVVal("SC_TGT","$"+DoubleToString(ad.dynScalpTarget,2),C_YELLOW_BRIGHT);
   KVVal("SC_WIN",IntegerToString(scalpWins),C_GREEN_BRIGHT);
   color spClr=totalScalpProfit>=0?C_GREEN_BRIGHT:C_RED_BRIGHT;
   KVVal("SC_PRF",(totalScalpProfit>=0?"+$":"-$")+DoubleToString(MathAbs(totalScalpProfit),2),spClr);
   double scPct=(InpDailyProfitTarget>0)?MathMin(100,totalScalpProfit/InpDailyProfitTarget*100):0;
   PBarUpd("SC_PB",px+dl.padX,dl.innerW,scPct,scPct<50?C_PBAR_YELLOW:C_PBAR_GREEN);

   int bo=0,so=0,bp=0,sp=0; datetime oldT=TimeCurrent(); bool hasO=false;
   for(int i=0;i<OrdersTotal();i++)
   {
      ulong t=OrderGetTicket(i);
      if(t>0&&OrderSelect(t)&&OrderGetString(ORDER_SYMBOL)==_Symbol&&OrderGetInteger(ORDER_MAGIC)==magic)
      {
         ENUM_ORDER_TYPE ot=(ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
         if(ot==ORDER_TYPE_BUY_STOP) bo++; if(ot==ORDER_TYPE_SELL_STOP) so++;
         datetime ot2=(datetime)OrderGetInteger(ORDER_TIME_SETUP);
         if(!hasO||ot2<oldT){oldT=ot2;hasO=true;}
      }
   }
   for(int i=0;i<PositionsTotal();i++)
   {
      ulong t=PositionGetTicket(i);
      if(t>0&&PositionSelectByTicket(t)&&PositionGetString(POSITION_SYMBOL)==_Symbol&&PositionGetInteger(POSITION_MAGIC)==magic)
      { if(PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_BUY) bp++; else sp++; }
   }
   int age=hasO?(int)(TimeCurrent()-oldT):0;
   color ageClr=age>ad.dynLifetimeSec*0.8?C_ORANGE_BRIGHT:C_TEXT_NORMAL;
   DSetText("GR_BV",IntegerToString(bo)); DSetText("GR_SV",IntegerToString(so));
   KVVal("GR_BP",IntegerToString(bp),C_GREEN_BRIGHT); KVVal("GR_SP",IntegerToString(sp),C_RED_BRIGHT);
   KVVal("GR_AG",IntegerToString(age)+"s / "+IntegerToString(ad.dynLifetimeSec)+"s",ageClr);
   double expo=GetTotalExposure();
   KVVal("GR_EX",DoubleToString(expo,2)+"/"+DoubleToString(InpMaxTotalLots,2)+"L",expo>InpMaxTotalLots*0.75?C_RED_BRIGHT:C_ORANGE_BRIGHT);

   if(atr>0)
   {
      KVVal("RI_SL",DoubleToString(ad.dynSLATRMult,2)+"xATR",C_RED_BRIGHT);
      KVVal("RI_TP",DoubleToString(ad.dynTPATRMult,2)+"xATR",C_GREEN_BRIGHT);
   }
   double sldPreview=MathMax(atr*ad.dynSLATRMult,1.0);
   KVVal("RI_LT",DoubleToString(CalculateLotSizeForSide(sldPreview,ad.buyRiskAlloc),2)+"/"+
                 DoubleToString(CalculateLotSizeForSide(sldPreview,ad.sellRiskAlloc),2),C_BRAND_CYAN);

   double ddP=(peakEquity>0)?(peakEquity-AccountInfoDouble(ACCOUNT_EQUITY))/peakEquity*100.0:0;
   color ddC=ddP>InpMaxDrawdownPct*0.7?C_RED_BRIGHT:ddP>InpMaxDrawdownPct*0.4?C_ORANGE_BRIGHT:C_GREEN_BRIGHT;
   DSetText("RI_DDV",DoubleToString(ddP,2)+"%"); DSetColor("RI_DDV",ddC);
   PBarUpd("RI_DD",px+dl.padX,dl.innerW,MathMin(100,ddP/InpMaxDrawdownPct*100),ddC);

   int wl=totalWins+totalLosses; double wr=wl>0?totalWins*100.0/wl:0;
   KVVal("PF_WL",IntegerToString(totalWins)+"/"+IntegerToString(totalLosses),C_TEXT_BRIGHT);
   KVVal("PF_WR",DoubleToString(wr,1)+"%",wr>=55?C_GREEN_BRIGHT:wr>=45?C_YELLOW_BRIGHT:C_RED_BRIGHT);
   KVVal("PF_PF",DoubleToString(recentProfitFactor,2),recentProfitFactor>=1.5?C_GREEN_BRIGHT:recentProfitFactor>=1.0?C_YELLOW_BRIGHT:C_RED_BRIGHT);
   KVVal("PF_GP","+$"+DoubleToString(grossProfit,2),C_GREEN_BRIGHT);
   KVVal("PF_GL","-$"+DoubleToString(grossLoss,2),C_RED_BRIGHT);
   int spH=MathMin(16,dl.perfH-(dl.rowH*5)-dl.fontSmall-6);
   if(spH>=6){ int spY=dl.yPerf+dl.secHdrH+(dl.rowH*5)+dl.fontSmall+2; UpdateSparkline("PF_SP",px+dl.padX,spY,dl.innerW,spH); }

   int rm=(int)((TimeCurrent()-eaStartTime)/60);
   DSetText("FT_RT","Runtime: "+IntegerToString(rm/60)+"h "+IntegerToString(rm%60)+"m");
   ChartRedraw();
}

//+------------------------------------------------------------------+
//| EVENT HANDLERS                                                    |
//+------------------------------------------------------------------+
int OnInit()
{
   if(InpRiskPercent>10.0){Print("Risk>10%");return INIT_PARAMETERS_INCORRECT;}
   if(InpAdaptOrdersMin<1||InpAdaptOrdersMax>60||InpAdaptOrdersMin>InpAdaptOrdersMax)
   {Print("Adaptive order bounds invalid");return INIT_PARAMETERS_INCORRECT;}

   symbolDigits=(int)SymbolInfoInteger(_Symbol,SYMBOL_DIGITS);
   symbolPoint=SymbolInfoDouble(_Symbol,SYMBOL_POINT);
   isJPYPair=StringFind(_Symbol,"JPY")>=0;
   pipSize=(isJPYPair||symbolDigits==3||symbolDigits==2)?0.01:0.0001;

   trade.SetExpertMagicNumber(magic);
   trade.SetDeviationInPoints(InpTradeDeviationPts);
   trade.SetTypeFillingBySymbol(_Symbol);

   handleATR=iATR(_Symbol,InpAnalysisTF,InpATRPeriod);
   handleATRSlow=iATR(_Symbol,InpAnalysisTF,InpATRSlowPeriod);
   if(handleATR==INVALID_HANDLE||handleATRSlow==INVALID_HANDLE){Print("ATR init failed");return INIT_FAILED;}

   ArrayResize(volHistory,InpVolWindowBars); ArrayInitialize(volHistory,0.0);
   volHistCount=0; volHistHead=0;
   ArrayResize(tickBuf,InpTickBufferSize); tickBufHead=0; tickBufCount=0;
   ExecQuality_Init();
   winStreak=0; lossStreak=0; aggressionMultiplier=1.0;

   ZeroMemory(ad);
   ad.dynBuyOrders=InpOrdersPoolTotal/2; ad.dynSellOrders=InpOrdersPoolTotal/2;
   ad.dynLifetimeSec=InpAdaptLifetimeMaxSec; ad.dynScalpTarget=InpScalpProfitTargetBase;
   ad.bullProbability=50; ad.bearProbability=50; ad.buyRiskAlloc=0.5; ad.sellRiskAlloc=0.5;
   ad.sessionLiquidity=1.0; ad.ready=false;

   EventSetMillisecondTimer(InpTimerMs);
   peakEquity=AccountInfoDouble(ACCOUNT_EQUITY);
   dayStartBalance=AccountInfoDouble(ACCOUNT_BALANCE);
   MqlDateTime tm; TimeToStruct(TimeCurrent(),tm); lastDayChecked=tm.day;
   eaStartTime=TimeCurrent();

   ArrayInitialize(sparkData,0.0);
   dl.spinAngle=0; dl.pulsePhase=0; dl.objCount=0; dl.needRebuild=true;
   if(InpShowDashboard) BuildDashboard();

   Print("=========================================");
   Print("PHANTOM FLUX ADAPTIVE CORE v9.00 | ",_Symbol);
   Print("Probability-weighted bidirectional attack | 8 subsystems active");
   Print("Building volatility + tick history before first deploy...");
   Print("=========================================");
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
   EventKillTimer();
   IndicatorRelease(handleATR); IndicatorRelease(handleATRSlow);
   if(InpShowDashboard) ObjectsDeleteAll(0,DASH_PREFIX);
   Print("SHUTDOWN | ",totalWins,"W/",totalLosses,"L | $",DoubleToString(totalScalpProfit,2));
}

void OnTimer()
{
   UpdateAdaptiveState();
   ManageOCO();
   ManageScalpTarget();
   ManagePositions();
   ManageMaxHoldTime();
   CheckCircuitBreaker();
   if(tradingEnabled) DeployBidirectionalGrid();
   if(InpShowDashboard) UpdateDashboard();
}

void OnTick()
{
   PushTick();

   tickCounterForSync++;
   if(tickCounterForSync >= InpSyncEveryNTicks)
   {
      tickCounterForSync = 0;
      SynchronizeGrid();
   }

   if(!InpUseTickDrivenMgmt) return;
   datetime now=TimeCurrent();
   if(now==lastTickManagement) return;
   lastTickManagement=now;
   ManageOCO(); ManageScalpTarget(); ManagePositions();
}

bool PlaceBuyStopTimed(double lot,double price,double sl,double tp,string comment)
{
   uint t0=GetTickCount();
   bool ok = trade.BuyStop(lot,price,_Symbol,sl,tp,ORDER_TIME_GTC,0,comment);
   uint t1=GetTickCount();
   ExecQuality_RecordLatency((double)(t1-t0));
   return ok;
}
bool PlaceSellStopTimed(double lot,double price,double sl,double tp,string comment)
{
   uint t0=GetTickCount();
   bool ok = trade.SellStop(lot,price,_Symbol,sl,tp,ORDER_TIME_GTC,0,comment);
   uint t1=GetTickCount();
   ExecQuality_RecordLatency((double)(t1-t0));
   return ok;
}

void OnTradeTransaction(const MqlTradeTransaction &trans,
                        const MqlTradeRequest &request,
                        const MqlTradeResult &result)
{
   if(trans.type!=TRADE_TRANSACTION_DEAL_ADD) return;
   ulong dk=trans.deal;
   if(!HistoryDealSelect(dk)) return;
   if(HistoryDealGetInteger(dk,DEAL_MAGIC)!=magic) return;
   if(HistoryDealGetString(dk,DEAL_SYMBOL)!=_Symbol) return;
   long entry=HistoryDealGetInteger(dk,DEAL_ENTRY);

   if(entry==DEAL_ENTRY_IN)
   {
      ulong orderTicket = HistoryDealGetInteger(dk,DEAL_ORDER);
      double fillPrice = HistoryDealGetDouble(dk,DEAL_PRICE);
      if(HistoryOrderSelect(orderTicket))
      {
         double setPrice = HistoryOrderGetDouble(orderTicket,ORDER_PRICE_OPEN);
         double slipPts = (fillPrice - setPrice) / symbolPoint;
         ExecQuality_RecordSlippage(slipPts);
      }
      ManageOCO();
      SynchronizeGrid();
   }
   else if(entry==DEAL_ENTRY_OUT||entry==DEAL_ENTRY_OUT_BY)
   {
      double dp=HistoryDealGetDouble(dk,DEAL_PROFIT)+HistoryDealGetDouble(dk,DEAL_SWAP)+HistoryDealGetDouble(dk,DEAL_COMMISSION);
      if(dp>0){totalWins++; grossProfit+=dp;} else {totalLosses++; grossLoss+=MathAbs(dp);}
      SparklineAdd(dp);
      UpdateProfitFactor();
      Aggression_OnTradeClosed(dp);
   }
}

void OnChartEvent(const int id,const long &lp,const double &dp,const string &sp)
{
   if(id==CHARTEVENT_CHART_CHANGE&&InpShowDashboard)
   { ObjectsDeleteAll(0,DASH_PREFIX); dl.objCount=0; dl.needRebuild=true; }
}
//+------------------------------------------------------------------+
