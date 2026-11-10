//+------------------------------------------------------------------+
//|              ULTRA ADVANCED INTELLIGENT EA v2.0                   |
//|        Multi-Strategy | Multi-Symbol | Confluence-Driven         |
//|        Gold • Forex • Indices • Crypto                           |
//|        10-Strategy Intelligent Confluence Engine                 |
//|        Upgraded from BTC Quantum Scalper v1.0                     |
//+------------------------------------------------------------------+
#property copyright   "Ultra Advanced Intelligent EA v2.0"
#property version     "2.00"
#property description "10-strategy multi-symbol confluence engine for Gold/Forex/Indices"
#property strict

#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>
#include <Trade\AccountInfo.mqh>

#define D  "UAI_"
#define OV "UAI_OV_"

//=====================================================================
//  ENUMERATIONS
//=====================================================================
enum ENUM_REGIME {
   REGIME_TRENDING, REGIME_RANGING, REGIME_BREAKOUT, REGIME_COMPRESSION,
   REGIME_EXPANSION, REGIME_VOLATILITY_SHOCK, REGIME_LIQUIDITY_SWEEP,
   REGIME_EXHAUSTION, REGIME_MEAN_REVERSION, REGIME_UNSAFE
};
enum ENUM_VOL_STATE { VOL_LOW, VOL_NORMAL, VOL_HIGH, VOL_EXTREME };
enum ENUM_VOL_DYNAMIC { VOLDYN_EXPANDING, VOLDYN_COMPRESSING, VOLDYN_STABLE, VOLDYN_SPIKE };
enum ENUM_SESSION { SESSION_ASIAN, SESSION_LONDON_OPEN, SESSION_LONDON_MID, SESSION_NY_OPEN, SESSION_NY_PM, SESSION_DEAD_ZONE };
enum ENUM_NEWS_STATE { NEWS_NORMAL, NEWS_CAUTION, NEWS_SHOCK };

enum ENUM_STRATEGY {
   STRAT_NONE,
   STRAT_SMC,              // 1: Smart Money Concepts
   STRAT_MTF_MOMENTUM,     // 2: Multi-Timeframe Momentum Confluence
   STRAT_VOL_BREAKOUT,     // 3: Volatility Breakout (BB squeeze + ATR)
   STRAT_VSA,              // 4: Volume Spread Analysis
   STRAT_PATTERN,          // 5: AI-Style Pattern Recognition
   STRAT_FIB,              // 6: Auto-Fibonacci Confluence
   STRAT_TREND_RIBBON,     // 7: Adaptive Trend Ribbon
   STRAT_ZSCORE,           // 8: Statistical Z-Score Mean Reversion
   STRAT_SESSION_LIQUIDITY,// 9: Session & Liquidity Engine
   STRAT_NEWS_FILTER       // 10: News-Adaptive Filter (gate, not signal)
};
enum ENUM_DIRECTION { DIR_NONE, DIR_LONG, DIR_SHORT };

//=====================================================================
//  CORE DATA STRUCTURES
//=====================================================================
struct RegimeState { ENUM_REGIME regime; double confidence; double stability; datetime sinceTime; ENUM_REGIME previousRegime; };
struct VolatilityState { ENUM_VOL_STATE state; ENUM_VOL_DYNAMIC dynamic; double atrCurrent; double atrAvg; double atrRatio; double percentile; };
struct LiquidityState { double biasScore; double pressureScore; double sweepProbability; double imbalanceScore; bool equalHighsDetected; bool equalLowsDetected; double equalHighLevel; double equalLowLevel; bool sweepUpDetected; bool sweepDownDetected; };
struct SessionState { ENUM_SESSION current; double sessionRangeATRRatio; double sessionVolatilityScore; ENUM_STRATEGY preferredStrategy; double strategyWeight; };
struct MTFBias { int h1Bias; int m15Bias; int m5Bias; int m1Bias; double alignment; };
struct StrategySignal { ENUM_STRATEGY source; ENUM_DIRECTION direction; double confidence; double suggestedSL; double suggestedTP; string reason; bool valid; };
struct ExecutionQuality { double spreadScore; double slippageRiskScore; double volatilityQuality; double liquidityQuality; double efficiencyScore; double compositeScore; bool executionApproved; string rejectReason; };
struct TradeQualityScore { double trendScore; double liquidityScore; double structureScore; double volatilityScore; double sessionScore; double executionScore; double totalScore; bool approved; string rejectReason; };
struct RiskState { double dailyRiskUsedPct; double weeklyRiskUsedPct; double currentDrawdownPct; double maxDrawdownSeenPct; bool dailyLimitHit; bool weeklyLimitHit; bool maxDrawdownBreached; bool emergencyShutdown; double peakEquity; double weekStartEquity; double dayStartEquity; };

struct StrategyHealth {
   string name; int totalTrades; int wins; int losses;
   double grossProfit; double grossLoss; double sumR; double sumRSquared;
   int consecLosses; int maxConsecLosses; double winRate; double profitFactor;
   double expectancyR; double sharpeProxy; bool enabled; double influenceMultiplier;
};

struct MasterDecision {
   bool tradeApproved; ENUM_DIRECTION direction; double lotSize;
   double slPrice; double tpPrice; ENUM_STRATEGY strategySource;
   double riskAmountUsed; string narrative; double confluenceScore;
   string symbol; double entry;
};

struct OrderBlock { datetime time; double high; double low; bool isBullish; bool mitigated; int strength; };
struct FairValueGap { datetime startTime; double topPrice; double bottomPrice; bool isBullish; bool filled; };
struct MarketStructure { datetime time; double price; bool isHigh; bool isBOS; bool isCHoCH; bool isMSS; int strength; bool isMajor; bool isInternal; bool isProtected; bool swept; };
struct LiquidityPool { double price; string label; int priority; bool buySide; bool swept; datetime time; };

// --- PER-SYMBOL CONTEXT (the heart of multi-symbol support) ---
struct SymbolContext {
   string symbol;
   int digits;
   double point;
   
   // Indicator handles
   int h_h1emaF, h_h1emaS, h_h1atr;
   int h_m15emaF, h_m15emaS, h_m15atr, h_m15rsi, h_m15macd, h_m15bb;
   int h_m5emaF, h_m5emaS, h_m5atr, h_m5rsi, h_m5stoch;
   int h_m1emaF, h_m1emaS, h_m1atr;
   int h_ema8, h_ema21, h_ema50, h_ema100, h_ema200; // trend ribbon
   
   // State
   RegimeState regime;
   VolatilityState vol;
   LiquidityState liq;
   SessionState session;
   MTFBias mtf;
   ExecutionQuality exec;
   TradeQualityScore quality;
   
   // Structure
   OrderBlock obs[]; int obCount;
   FairValueGap fvgs[]; int fvgCount;
   MarketStructure struct[]; int structCount;
   LiquidityPool pools[]; int poolCount;
   
   // Session tracking
   double sessionHigh, sessionLow;
   datetime sessionHighTime, sessionLowTime;
   datetime currentSessionStart;
   int sessionAnchorBars;
   
   // Decision
   MasterDecision lastDecision;
   StrategySignal lastSignals[10];  // all 10 strategy results
   double confluenceScore;
   int confluenceDir;
   string confluenceReason;
   
   // Tracking
   int tradesToday;
   double sessionProfit;
   int sessionWins, sessionLosses;
   datetime lastCloseTime;
   bool inCooldown;
   bool initialized;
};

//=====================================================================
//  COLOR PALETTE
//=====================================================================
#define C_BG0    C'5,7,16'
#define C_BG1    C'9,13,26'
#define C_BG2    C'13,19,38'
#define C_HDRBAR C'11,17,34'
#define C_BORDER C'24,46,88'
#define C_ACBORD C'0,170,225'
#define C_GOLD   C'255,202,60'
#define C_CYAN   C'0,224,224'
#define C_PURPLE C'182,108,255'
#define C_WHITE  C'222,228,242'
#define C_SUBTEXT C'112,132,162'
#define C_GREEN  C'24,222,118'
#define C_RED    C'234,62,72'
#define C_ORANGE C'255,150,10'
#define C_DKGREEN C'15,82,48'
#define C_DKRED  C'82,22,28'
#define C_LBLUE  C'85,165,255'
#define C_DGRAY  C'42,54,74'
#define C_MGRAY  C'78,92,118'

//=====================================================================
//  INPUT PARAMETERS
//=====================================================================
input group "═══ IDENTITY ═══"
input ulong   InpMagic            = 881100;
input string  InpBotName           = "UltraAdvancedEA";

input group "═══ MULTI-SYMBOL CONFIG ═══"
input bool    InpTradeGold         = true;
input bool    InpTradeForex         = true;
input bool    InpTradeIndices       = true;
input bool    InpTradeCrypto        = false;
input string  InpGoldSymbols       = "XAUUSD";
input string  InpForexSymbols      = "EURUSD,GBPUSD,USDJPY,AUDUSD,USDCHF,USDCAD,NZDUSD";
input string  InpIndexSymbols      = "US30,NAS100,SPX500,GER40,UK100";
input string  InpCryptoSymbols     = "BTCUSD,ETHUSD";
input int     InpMaxSymbolsActive   = 12;

input group "═══ RISK GOVERNANCE ═══"
input double  InpRiskPercentPerTrade= 0.5;
input double  InpMaxRiskPercentTrade = 1.0;
input double  InpMaxDailyLossPct    = 6.0;
input double  InpMaxWeeklyLossPct   = 15.0;
input double  InpMaxDrawdownPct     = 18.0;
input int     InpMaxDailyTrades     = 50;
input int     InpMaxConcurrentTrades= 5;
input int     InpMaxPerSymbol       = 1;
input int     InpCooldownAfterCloseSec = 10;

input group "═══ CONFLUENCE ENGINE ═══"
input double  InpMinConfluenceScore = 68.0;  // Min weighted score to trade
input double  InpMinRR              = 1.8;   // Min risk:reward
input double  InpMinDirectionAdvantage = 15.0; // Min score gap between bull/bear

input group "═══ STRATEGY WEIGHTS ═══"
input double  InpWgtSMC             = 1.8;
input double  InpWgtMTFMom          = 1.3;
input double  InpWgtVolBreak        = 1.1;
input double  InpWgtVSA             = 1.0;
input double  InpWgtPattern         = 0.9;
input double  InpWgtFib             = 1.2;
input double  InpWgtTrendRibbon     = 1.1;
input double  InpWgtZScore          = 0.8;
input double  InpWgtSession         = 0.7;

input group "═══ REGIME DETECTION ═══"
input int     InpATRPeriod          = 14;
input int     InpATRLookback        = 100;
input int     InpEMAFastPeriod      = 5;
input int     InpEMASlowPeriod      = 21;
input int     InpStructureLookback   = 20;
input double  InpMinRegimeConfidence= 30.0;

input group "═══ LIQUIDITY ENGINE ═══"
input double  InpEqualLevelTolerance= 0.10;
input int     InpLiquidityLookback   = 40;

input group "═══ NEWS / VOLATILITY SHOCK ═══"
input double  InpShockATRMultiple    = 3.5;
input double  InpShockSpreadMultiple = 3.0;
input double  InpMaxSpreadPoints     = 50;

input group "═══ STRATEGY HEALTH ═══"
input int     InpHealthMinTrades     = 10;
input int     InpHealthDegradeConsecLoss = 5;
input double  InpHealthMinExpectancyR= -0.25;

input group "═══ ADAPTIVE PARAMETERS ═══"
input bool    InpEnableAdaptiveParams= true;
input double  InpAdaptiveBoundPct    = 20.0;

input group "═══ SESSION ═══"
input int     InpBrokerGMTOffset     = 2;

input group "═══ SL/TP ENGINE ═══"
input double  InpATR_SL_Mult        = 1.8;
input double  InpATR_TP_Mult        = 3.6;

input group "═══ DASHBOARD ═══"
input bool    InpShowDash           = true;
input int     InpDashX              = 10;
input int     InpDashY              = 10;
input bool    InpEnableBlackTheme   = true;

input group "═══ VISUAL OVERLAYS ═══"
input bool    InpDrawMarketStructure= true;
input bool    InpDrawOrderBlocks    = true;
input bool    InpDrawFVG            = true;
input bool    InpDrawLiquidityZones = true;
input bool    InpDrawSignalMarkers  = true;
input bool    InpDrawSessionBoxes   = true;
input bool    InpDrawPremiumDiscount= true;

input group "═══ TRADE MANAGEMENT ═══"
input bool    InpUseBreakEven       = true;
input double  InpBreakEvenATR       = 0.8;
input bool    InpUseTrailing        = true;
input double  InpTrailATR           = 1.0;
input bool    InpUsePartialClose    = true;
input double  InpPartialATR         = 1.5;

//=====================================================================
//  GLOBAL OBJECTS
//=====================================================================
CTrade        g_trade;
CPositionInfo g_pos;
CAccountInfo  g_account;

SymbolContext g_ctx[];    // Per-symbol context array
int           g_ctxCount = 0;
int           g_activeSymbol = 0;  // Index of symbol shown in detail on dashboard

RiskState     g_risk;
StrategyHealth g_health[10];
string        g_statusText = "INITIALIZING";
color         g_statusColor = C_ORANGE;
string        g_lastAction = "Starting up...";
string        g_dashLog[15];
datetime      g_dayStart = 0, g_weekStart = 0, g_lastBarTime = 0;
datetime      g_lastFullUpdate = 0;
double        g_adaptiveRegimeConfThreshold, g_adaptiveExecScoreThreshold;

const int DW = 620, DH = 660;

//=====================================================================
//  HELPER: DASHBOARD SHORTCUTS
//=====================================================================
void R(string nm, int x, int y, int w, int h, color bg, color brd=clrNONE, int bw=1) {
   string n = D + nm; ObjectDelete(0, n);
   if(ObjectCreate(0, n, OBJ_RECTANGLE_LABEL, 0, 0, 0)) {
      ObjectSetInteger(0,n,OBJPROP_CORNER,CORNER_LEFT_UPPER);
      ObjectSetInteger(0,n,OBJPROP_XDISTANCE,x); ObjectSetInteger(0,n,OBJPROP_YDISTANCE,y);
      ObjectSetInteger(0,n,OBJPROP_XSIZE,w); ObjectSetInteger(0,n,OBJPROP_YSIZE,h);
      ObjectSetInteger(0,n,OBJPROP_BGCOLOR,bg);
      if(brd!=clrNONE) { ObjectSetInteger(0,n,OBJPROP_BORDER_TYPE,BORDER_FLAT); ObjectSetInteger(0,n,OBJPROP_COLOR,brd); ObjectSetInteger(0,n,OBJPROP_WIDTH,bw); }
      else ObjectSetInteger(0,n,OBJPROP_BORDER_TYPE,BORDER_RAISED);
      ObjectSetInteger(0,n,OBJPROP_SELECTABLE,false); ObjectSetInteger(0,n,OBJPROP_HIDDEN,true);
   }
}
void L(string nm, int x, int y, string txt, color clr, int fsz, string fnt="Arial") {
   string n = D + nm; ObjectDelete(0, n);
   if(ObjectCreate(0, n, OBJ_LABEL, 0, 0, 0)) {
      ObjectSetInteger(0,n,OBJPROP_CORNER,CORNER_LEFT_UPPER);
      ObjectSetInteger(0,n,OBJPROP_XDISTANCE,x); ObjectSetInteger(0,n,OBJPROP_YDISTANCE,y);
      ObjectSetString(0,n,OBJPROP_TEXT,txt); ObjectSetInteger(0,n,OBJPROP_COLOR,clr);
      ObjectSetInteger(0,n,OBJPROP_FONTSIZE,fsz); ObjectSetString(0,n,OBJPROP_FONT,fnt);
      ObjectSetInteger(0,n,OBJPROP_SELECTABLE,false); ObjectSetInteger(0,n,OBJPROP_HIDDEN,true);
   }
}
void U(string nm, string txt, color clr=C'222,228,242') {
   string n = D + nm;
   if(ObjectFind(0,n)>=0) { ObjectSetString(0,n,OBJPROP_TEXT,txt); ObjectSetInteger(0,n,OBJPROP_COLOR,clr); }
}
void PushLog(string s) {
   string t = TimeToString(TimeCurrent(), TIME_SECONDS);
   for(int i=14;i>0;i--) g_dashLog[i]=g_dashLog[i-1];
   g_dashLog[0] = "["+t+"] "+s; Print(s);
}

double NPriceD(string sym, double p) { return NormalizeDouble(p, (int)SymbolInfoInteger(sym, SYMBOL_DIGITS)); }
double GetBuf(int handle, int buf, int shift) {
   if(handle==INVALID_HANDLE) return 0.0;
   double a[]; if(CopyBuffer(handle, buf, shift, 1, a)!=1) return 0.0; return a[0];
}
datetime DayStart(datetime ts) { MqlDateTime d; TimeToStruct(ts,d); return ts-(datetime)(d.hour*3600+d.min*60+d.sec); }
datetime WeekStart(datetime ts) { MqlDateTime d; TimeToStruct(ts,d); datetime ds=DayStart(ts); int off=(d.day_of_week==0)?6:(d.day_of_week-1); return ds-(datetime)(off*86400); }
ENUM_ORDER_TYPE_FILLING GetFillMode() { uint f=(uint)SymbolInfoInteger(_Symbol,SYMBOL_FILLING_MODE); if((f&SYMBOL_FILLING_FOK)!=0) return ORDER_FILLING_FOK; if((f&SYMBOL_FILLING_IOC)!=0) return ORDER_FILLING_IOC; return ORDER_FILLING_RETURN; }

int PositionsTotalForMagicSymbol(string sym) {
   int c=0; for(int i=PositionsTotal()-1;i>=0;i--) if(g_pos.SelectByIndex(i) && g_pos.Magic()==InpMagic && g_pos.Symbol()==sym) c++; return c;
}
int PositionsTotalForMagic() {
   int c=0; for(int i=PositionsTotal()-1;i>=0;i--) if(g_pos.SelectByIndex(i) && g_pos.Magic()==InpMagic) c++; return c;
}
double GetFloatingPLSymbol(string sym) {
   double t=0; for(int i=PositionsTotal()-1;i>=0;i--) if(g_pos.SelectByIndex(i) && g_pos.Magic()==InpMagic && g_pos.Symbol()==sym) t+=g_pos.Profit()+g_pos.Swap()+g_pos.Commission(); return t;
}

string RegimeToString(ENUM_REGIME r) {
   switch(r) { case REGIME_TRENDING: return "TREND"; case REGIME_RANGING: return "RANGE"; case REGIME_BREAKOUT: return "BREAK"; case REGIME_COMPRESSION: return "COMPRESS"; case REGIME_EXPANSION: return "EXPAND"; case REGIME_VOLATILITY_SHOCK: return "SHOCK"; case REGIME_LIQUIDITY_SWEEP: return "SWEEP"; case REGIME_EXHAUSTION: return "EXHAUST"; case REGIME_MEAN_REVERSION: return "REVERT"; case REGIME_UNSAFE: return "UNSAFE"; default: return "?"; }
}
string StrategyToString(ENUM_STRATEGY s) {
   switch(s) { case STRAT_SMC: return "SMC"; case STRAT_MTF_MOMENTUM: return "MTF"; case STRAT_VOL_BREAKOUT: return "VolBrk"; case STRAT_VSA: return "VSA"; case STRAT_PATTERN: return "Pattern"; case STRAT_FIB: return "Fib"; case STRAT_TREND_RIBBON: return "Ribbon"; case STRAT_ZSCORE: return "ZScore"; case STRAT_SESSION_LIQUIDITY: return "Session"; case STRAT_NEWS_FILTER: return "News"; default: return "None"; }
}
int StrategyHealthIndex(ENUM_STRATEGY s) { return (int)s - 1; }

//=====================================================================
//  SYMBOL MANAGEMENT
//=====================================================================
void BuildSymbolList() {
   string list = "";
   if(InpTradeGold)    list += InpGoldSymbols + ",";
   if(InpTradeForex)   list += InpForexSymbols + ",";
   if(InpTradeIndices) list += InpIndexSymbols + ",";
   if(InpTradeCrypto)  list += InpCryptoSymbols + ",";

   string parts[]; int n = StringSplit(list, ',', parts);
   for(int i=0; i<n; i++) {
      string s = parts[i]; StringTrimLeft(s); StringTrimRight(s);
      if(s=="") continue;
      if(g_ctxCount >= InpMaxSymbolsActive) break;
      if(!SymbolSelect(s, true)) continue;
      ArrayResize(g_ctx, g_ctxCount+1);
      g_ctx[g_ctxCount].symbol = s;
      g_ctx[g_ctxCount].digits = (int)SymbolInfoInteger(s, SYMBOL_DIGITS);
      g_ctx[g_ctxCount].point = SymbolInfoDouble(s, SYMBOL_POINT);
      g_ctx[g_ctxCount].initialized = false;
      g_ctx[g_ctxCount].tradesToday = 0;
      g_ctx[g_ctxCount].sessionProfit = 0;
      g_ctx[g_ctxCount].sessionWins = 0;
      g_ctx[g_ctxCount].sessionLosses = 0;
      g_ctx[g_ctxCount].inCooldown = false;
      g_ctx[g_ctxCount].lastCloseTime = 0;
      g_ctxCount++;
   }
}

bool InitSymbolContext(int idx) {
   string s = g_ctx[idx].symbol;
   SymbolSelect(s, true);

   g_ctx[idx].h_h1emaF = iMA(s, PERIOD_H1, InpEMAFastPeriod, 0, MODE_EMA, PRICE_CLOSE);
   g_ctx[idx].h_h1emaS = iMA(s, PERIOD_H1, InpEMASlowPeriod, 0, MODE_EMA, PRICE_CLOSE);
   g_ctx[idx].h_h1atr  = iATR(s, PERIOD_H1, InpATRPeriod);
   g_ctx[idx].h_m15emaF= iMA(s, PERIOD_M15, InpEMAFastPeriod, 0, MODE_EMA, PRICE_CLOSE);
   g_ctx[idx].h_m15emaS= iMA(s, PERIOD_M15, InpEMASlowPeriod, 0, MODE_EMA, PRICE_CLOSE);
   g_ctx[idx].h_m15atr = iATR(s, PERIOD_M15, InpATRPeriod);
   g_ctx[idx].h_m15rsi = iRSI(s, PERIOD_M15, 14, PRICE_CLOSE);
   g_ctx[idx].h_m15macd= iMACD(s, PERIOD_M15, 12, 26, 9, PRICE_CLOSE);
   g_ctx[idx].h_m15bb  = iBands(s, PERIOD_M15, 20, 0, 2.0, PRICE_CLOSE);
   g_ctx[idx].h_m5emaF = iMA(s, PERIOD_M5, InpEMAFastPeriod, 0, MODE_EMA, PRICE_CLOSE);
   g_ctx[idx].h_m5emaS = iMA(s, PERIOD_M5, InpEMASlowPeriod, 0, MODE_EMA, PRICE_CLOSE);
   g_ctx[idx].h_m5atr  = iATR(s, PERIOD_M5, InpATRPeriod);
   g_ctx[idx].h_m5rsi  = iRSI(s, PERIOD_M5, 14, PRICE_CLOSE);
   g_ctx[idx].h_m5stoch= iStochastic(s, PERIOD_M5, 14, 3, 3, MODE_SMA, STO_LOWHIGH);
   g_ctx[idx].h_m1emaF = iMA(s, PERIOD_M1, InpEMAFastPeriod, 0, MODE_EMA, PRICE_CLOSE);
   g_ctx[idx].h_m1emaS = iMA(s, PERIOD_M1, InpEMASlowPeriod, 0, MODE_EMA, PRICE_CLOSE);
   g_ctx[idx].h_m1atr  = iATR(s, PERIOD_M1, InpATRPeriod);
   g_ctx[idx].h_ema8   = iMA(s, PERIOD_M15, 8, 0, MODE_EMA, PRICE_CLOSE);
   g_ctx[idx].h_ema21  = iMA(s, PERIOD_M15, 21, 0, MODE_EMA, PRICE_CLOSE);
   g_ctx[idx].h_ema50  = iMA(s, PERIOD_M15, 50, 0, MODE_EMA, PRICE_CLOSE);
   g_ctx[idx].h_ema100 = iMA(s, PERIOD_M15, 100, 0, MODE_EMA, PRICE_CLOSE);
   g_ctx[idx].h_ema200 = iMA(s, PERIOD_M15, 200, 0, MODE_EMA, PRICE_CLOSE);

   if(g_ctx[idx].h_h1emaF==INVALID_HANDLE || g_ctx[idx].h_m5atr==INVALID_HANDLE) {
      Print("Indicator init failed for ", s); return false;
   }

   g_ctx[idx].regime.regime = REGIME_RANGING;
   g_ctx[idx].regime.confidence = 0;
   g_ctx[idx].regime.stability = 0;
   g_ctx[idx].regime.sinceTime = TimeCurrent();
   g_ctx[idx].initialized = true;
   return true;
}

//=====================================================================
//  SESSION INTELLIGENCE (per-symbol)
//=====================================================================
ENUM_SESSION ClassifySession(datetime ts) {
   MqlDateTime d; TimeToStruct(ts, d);
   int h = (d.hour - InpBrokerGMTOffset + 24) % 24;
   if(h>=0 && h<7) return SESSION_ASIAN;
   if(h>=7 && h<10) return SESSION_LONDON_OPEN;
   if(h>=10 && h<12) return SESSION_LONDON_MID;
   if(h>=12 && h<15) return SESSION_NY_OPEN;
   if(h>=15 && h<21) return SESSION_NY_PM;
   return SESSION_DEAD_ZONE;
}

void UpdateSessionIntelligence(int idx) {
   string s = g_ctx[idx].symbol;
   g_ctx[idx].session.current = ClassifySession(TimeCurrent());

   double atrM5 = GetBuf(g_ctx[idx].h_m5atr, 0, 0);
   if(atrM5<=0) atrM5 = g_ctx[idx].point*100;

   double sHi = iHigh(s, PERIOD_M5, 0), sLo = iLow(s, PERIOD_M5, 0);
   datetime sHiT = iTime(s, PERIOD_M5, 0), sLoT = iTime(s, PERIOD_M5, 0);
   int bars = MathMin(100, (int)Bars(s, PERIOD_M5)-1);
   for(int i=1;i<bars;i++) {
      double h=iHigh(s,PERIOD_M5,i), l=iLow(s,PERIOD_M5,i);
      if(h>sHi){sHi=h;sHiT=iTime(s,PERIOD_M5,i);}
      if(l<sLo){sLo=l;sLoT=iTime(s,PERIOD_M5,i);}
   }
   g_ctx[idx].sessionHigh=sHi; g_ctx[idx].sessionLow=sLo;
   g_ctx[idx].sessionHighTime=sHiT; g_ctx[idx].sessionLowTime=sLoT;

   double range=sHi-sLo;
   g_ctx[idx].session.sessionRangeATRRatio = (atrM5>0)?(range/atrM5):0.0;
   g_ctx[idx].session.sessionVolatilityScore = MathMin(100.0, g_ctx[idx].session.sessionRangeATRRatio*25.0);

   switch(g_ctx[idx].session.current) {
      case SESSION_ASIAN: g_ctx[idx].session.preferredStrategy=STRAT_ZSCORE; g_ctx[idx].session.strategyWeight=1.0; break;
      case SESSION_LONDON_OPEN: g_ctx[idx].session.preferredStrategy=STRAT_VOL_BREAKOUT; g_ctx[idx].session.strategyWeight=1.3; break;
      case SESSION_LONDON_MID: g_ctx[idx].session.preferredStrategy=STRAT_SMC; g_ctx[idx].session.strategyWeight=1.1; break;
      case SESSION_NY_OPEN: g_ctx[idx].session.preferredStrategy=STRAT_SMC; g_ctx[idx].session.strategyWeight=1.35; break;
      case SESSION_NY_PM: g_ctx[idx].session.preferredStrategy=STRAT_TREND_RIBBON; g_ctx[idx].session.strategyWeight=1.0; break;
      default: g_ctx[idx].session.preferredStrategy=STRAT_NONE; g_ctx[idx].session.strategyWeight=0.7; break;
   }
}

//=====================================================================
//  MTF BIAS ENGINE (per-symbol)
//=====================================================================
int ComputeTFBias(int emaFastH, int emaSlowH) {
   double f[2], sl[2];
   if(CopyBuffer(emaFastH,0,0,2,f)<2) return 0;
   if(CopyBuffer(emaSlowH,0,0,2,sl)<2) return 0;
   double spreadNow=f[0]-sl[0], spreadPrev=f[1]-sl[1];
   int dir = (f[0]>sl[0])?1:(f[0]<sl[0]?-1:0);
   if(dir==0) return 0;
   bool widening = MathAbs(spreadNow)>MathAbs(spreadPrev);
   if(!widening && MathAbs(spreadNow)<MathAbs(spreadPrev)*0.5) return 0;
   return dir;
}

void UpdateMTFBias(int idx) {
   g_ctx[idx].mtf.h1Bias  = ComputeTFBias(g_ctx[idx].h_h1emaF, g_ctx[idx].h_h1emaS);
   g_ctx[idx].mtf.m15Bias = ComputeTFBias(g_ctx[idx].h_m15emaF, g_ctx[idx].h_m15emaS);
   g_ctx[idx].mtf.m5Bias  = ComputeTFBias(g_ctx[idx].h_m5emaF, g_ctx[idx].h_m5emaS);
   g_ctx[idx].mtf.m1Bias  = ComputeTFBias(g_ctx[idx].h_m1emaF, g_ctx[idx].h_m1emaS);

   int b[4]={g_ctx[idx].mtf.h1Bias, g_ctx[idx].mtf.m15Bias, g_ctx[idx].mtf.m5Bias, g_ctx[idx].mtf.m1Bias};
   int agree=0, nonzero=0, refDir=0;
   for(int i=0;i<4;i++) { if(b[i]!=0){nonzero++; if(refDir==0)refDir=b[i]; else if(b[i]==refDir)agree++;} }
   g_ctx[idx].mtf.alignment = (nonzero>1)?(100.0*(double)(agree+1)/(double)nonzero):(nonzero==1?50.0:0.0);
}

//=====================================================================
//  VOLATILITY INTELLIGENCE (per-symbol)
//=====================================================================
void UpdateVolatilityIntelligence(int idx) {
   double atrBuf[]; ArrayResize(atrBuf, InpATRLookback); ArraySetAsSeries(atrBuf, true);
   int got = CopyBuffer(g_ctx[idx].h_m5atr, 0, 0, InpATRLookback, atrBuf);
   if(got<=0 || got<InpATRLookback/2) {
      g_ctx[idx].vol.state=VOL_NORMAL; g_ctx[idx].vol.dynamic=VOLDYN_STABLE;
      g_ctx[idx].vol.atrCurrent=g_ctx[idx].point*100; g_ctx[idx].vol.atrAvg=g_ctx[idx].point*100; g_ctx[idx].vol.atrRatio=1.0; return;
   }
   double cur=atrBuf[0], sum=0; int n=0;
   for(int i=0;i<got;i++){sum+=atrBuf[i];n++;}
   double avg=(n>0)?sum/n:cur; if(avg<=0) avg=g_ctx[idx].point*100;
   g_ctx[idx].vol.atrCurrent=cur; g_ctx[idx].vol.atrAvg=avg; g_ctx[idx].vol.atrRatio=(avg>0)?cur/avg:1.0;
   int below=0; for(int i=0;i<got;i++) if(atrBuf[i]<=cur) below++;
   g_ctx[idx].vol.percentile=(got>0)?(100.0*below/got):50.0;
   if(g_ctx[idx].vol.percentile<25) g_ctx[idx].vol.state=VOL_LOW;
   else if(g_ctx[idx].vol.percentile<65) g_ctx[idx].vol.state=VOL_NORMAL;
   else if(g_ctx[idx].vol.percentile<90) g_ctx[idx].vol.state=VOL_HIGH;
   else g_ctx[idx].vol.state=VOL_EXTREME;
   double atrPrev3=(got>3)?atrBuf[3]:avg;
   double roc=(atrPrev3>0)?(cur-atrPrev3)/atrPrev3:0.0;
   if(g_ctx[idx].vol.atrRatio>=InpShockATRMultiple) g_ctx[idx].vol.dynamic=VOLDYN_SPIKE;
   else if(roc>0.15) g_ctx[idx].vol.dynamic=VOLDYN_EXPANDING;
   else if(roc<-0.15) g_ctx[idx].vol.dynamic=VOLDYN_COMPRESSING;
   else g_ctx[idx].vol.dynamic=VOLDYN_STABLE;
}

//=====================================================================
//  NEWS SHOCK PROXY (per-symbol)
//=====================================================================
double g_spreadHist[20]; int g_spreadCount=0;
ENUM_NEWS_STATE g_newsState = NEWS_NORMAL;

void UpdateNewsShockProxy(int idx) {
   string s = g_ctx[idx].symbol;
   double spreadNow = (double)SymbolInfoInteger(s, SYMBOL_SPREAD);
   if(g_spreadCount<20) { g_spreadHist[g_spreadCount]=spreadNow; g_spreadCount++; }
   else { for(int i=0;i<19;i++) g_spreadHist[i]=g_spreadHist[i+1]; g_spreadHist[19]=spreadNow; }
   double sum=0; for(int i=0;i<g_spreadCount;i++) sum+=g_spreadHist[i];
   double avg=(g_spreadCount>0)?sum/g_spreadCount:spreadNow; if(avg<=0) avg=1;
   double ratio=(avg>0)?spreadNow/avg:1.0;
   double barRange=iHigh(s,PERIOD_M5,0)-iLow(s,PERIOD_M5,0);
   double barAtrRatio=(g_ctx[idx].vol.atrAvg>0)?barRange/g_ctx[idx].vol.atrAvg:1.0;
   bool atrShock=g_ctx[idx].vol.atrRatio>=InpShockATRMultiple;
   bool spreadShock=ratio>=InpShockSpreadMultiple;
   bool barShock=barAtrRatio>=InpShockATRMultiple;
   int signals=(atrShock?1:0)+(spreadShock?1:0)+(barShock?1:0);
   g_newsState = (signals>=2)?NEWS_SHOCK:(signals==1?NEWS_CAUTION:NEWS_NORMAL);
}

//=====================================================================
//  SWING DETECTION HELPERS (per-symbol)
//=====================================================================
bool IsSwingHighS(string s, int index, int lb, int rb) {
   double ch=iHigh(s,PERIOD_M5,index);
   for(int i=1;i<=lb;i++) if(iHigh(s,PERIOD_M5,index-i)>=ch) return false;
   for(int i=1;i<=rb;i++) if(iHigh(s,PERIOD_M5,index+i)>=ch) return false;
   return true;
}
bool IsSwingLowS(string s, int index, int lb, int rb) {
   double cl=iLow(s,PERIOD_M5,index);
   for(int i=1;i<=lb;i++) if(iLow(s,PERIOD_M5,index-i)<=cl) return false;
   for(int i=1;i<=rb;i++) if(iLow(s,PERIOD_M5,index+i)<=cl) return false;
   return true;
}
double StructHiS(string s, int lb, int shift=0) { int idx=iHighest(s,PERIOD_M5,MODE_HIGH,lb,shift); return (idx<0)?0:iHigh(s,PERIOD_M5,idx); }
double StructLoS(string s, int lb, int shift=0) { int idx=iLowest(s,PERIOD_M5,MODE_LOW,lb,shift); return (idx<0)?0:iLow(s,PERIOD_M5,idx); }

int FindSwingHighsS(string s, int lb, int wing, double &outP[], datetime &outT[]) {
   int c=0, mx=ArraySize(outP);
   for(int i=wing;i<lb-wing&&c<mx;i++) {
      double h=iHigh(s,PERIOD_M5,i); bool sw=true;
      for(int w=1;w<=wing;w++) if(iHigh(s,PERIOD_M5,i-w)>=h||iHigh(s,PERIOD_M5,i+w)>=h){sw=false;break;}
      if(sw){outP[c]=h;outT[c]=iTime(s,PERIOD_M5,i);c++;}
   }
   return c;
}
int FindSwingLowsS(string s, int lb, int wing, double &outP[], datetime &outT[]) {
   int c=0, mx=ArraySize(outP);
   for(int i=wing;i<lb-wing&&c<mx;i++) {
      double l=iLow(s,PERIOD_M5,i); bool sw=true;
      for(int w=1;w<=wing;w++) if(iLow(s,PERIOD_M5,i-w)<=l||iLow(s,PERIOD_M5,i+w)<=l){sw=false;break;}
      if(sw){outP[c]=l;outT[c]=iTime(s,PERIOD_M5,i);c++;}
   }
   return c;
}

//=====================================================================
//  LIQUIDITY INTELLIGENCE (per-symbol)
//=====================================================================
void UpdateLiquidityIntelligence(int idx) {
   string s = g_ctx[idx].symbol;
   double shP[30]; datetime shT[30]; double slP[30]; datetime slT[30];
   int nH = FindSwingHighsS(s, MathMin(InpLiquidityLookback,60), 2, shP, shT);
   int nL = FindSwingLowsS(s, MathMin(InpLiquidityLookback,60), 2, slP, slT);
   double price = SymbolInfoDouble(s, SYMBOL_BID);
   double tol = price * (InpEqualLevelTolerance/100.0);

   g_ctx[idx].liq.equalHighsDetected=false; g_ctx[idx].liq.equalHighLevel=0;
   int bestHC=0;
   for(int i=0;i<nH;i++) {
      int cc=1; double sum=shP[i];
      for(int j=0;j<nH;j++) { if(j==i) continue; if(MathAbs(shP[j]-shP[i])<=tol) { cc++; sum+=shP[j]; } }
      if(cc>=2 && cc>bestHC) { bestHC=cc; g_ctx[idx].liq.equalHighLevel=sum/cc; g_ctx[idx].liq.equalHighsDetected=true; }
   }
   g_ctx[idx].liq.equalLowsDetected=false; g_ctx[idx].liq.equalLowLevel=0;
   int bestLC=0;
   for(int i=0;i<nL;i++) {
      int cc=1; double sum=slP[i];
      for(int j=0;j<nL;j++) { if(j==i) continue; if(MathAbs(slP[j]-slP[i])<=tol) { cc++; sum+=slP[j]; } }
      if(cc>=2 && cc>bestLC) { bestLC=cc; g_ctx[idx].liq.equalLowLevel=sum/cc; g_ctx[idx].liq.equalLowsDetected=true; }
   }
   g_ctx[idx].liq.sweepUpDetected=false; g_ctx[idx].liq.sweepDownDetected=false;
   if(g_ctx[idx].liq.equalHighsDetected)
      for(int i=0;i<3;i++) { if(iHigh(s,PERIOD_M5,i)>g_ctx[idx].liq.equalHighLevel && iClose(s,PERIOD_M5,i)<g_ctx[idx].liq.equalHighLevel) { g_ctx[idx].liq.sweepUpDetected=true; break; } }
   if(g_ctx[idx].liq.equalLowsDetected)
      for(int i=0;i<3;i++) { if(iLow(s,PERIOD_M5,i)<g_ctx[idx].liq.equalLowLevel && iClose(s,PERIOD_M5,i)>g_ctx[idx].liq.equalLowLevel) { g_ctx[idx].liq.sweepDownDetected=true; break; } }

   double dH=g_ctx[idx].liq.equalHighsDetected?MathAbs(price-g_ctx[idx].liq.equalHighLevel):-1;
   double dL=g_ctx[idx].liq.equalLowsDetected?MathAbs(price-g_ctx[idx].liq.equalLowLevel):-1;
   double prox=0;
   if(dH>=0 && g_ctx[idx].vol.atrAvg>0) prox=MathMax(prox, 100.0*MathMax(0.0, 1.0-dH/(g_ctx[idx].vol.atrAvg*1.5)));
   if(dL>=0 && g_ctx[idx].vol.atrAvg>0) prox=MathMax(prox, 100.0*MathMax(0.0, 1.0-dL/(g_ctx[idx].vol.atrAvg*1.5)));
   g_ctx[idx].liq.sweepProbability=MathMin(100.0, prox);
   double bias=0;
   if(dH>=0 && dL>=0) bias=(dL<dH)?-40.0:40.0;
   else if(dH>=0) bias=40.0; else if(dL>=0) bias=-40.0;
   if(g_ctx[idx].liq.sweepUpDetected) bias=-70.0;
   if(g_ctx[idx].liq.sweepDownDetected) bias=70.0;
   g_ctx[idx].liq.biasScore=bias;
   g_ctx[idx].liq.pressureScore=MathMin(100.0, (bestHC+bestLC)*12.0 + prox*0.3);
   g_ctx[idx].liq.imbalanceScore=MathMin(100.0, MathAbs((double)bestHC-(double)bestLC)*20.0);
}

//=====================================================================
//  MARKET STRUCTURE DETECTION (per-symbol)
//=====================================================================
void DetectMarketStructure(int idx) {
   string s = g_ctx[idx].symbol;
   ArrayResize(g_ctx[idx].struct, 0); g_ctx[idx].structCount = 0;
   int lb = MathMin(InpStructureLookback, (int)Bars(s,PERIOD_M5)-10);
   for(int i=5;i<lb;i++) {
      bool isH = IsSwingHighS(s,i,3,3), isL = IsSwingLowS(s,i,3,3);
      if(!isH && !isL) continue;
      ArrayResize(g_ctx[idx].struct, g_ctx[idx].structCount+1);
      int c = g_ctx[idx].structCount;
      g_ctx[idx].struct[c].time = iTime(s,PERIOD_M5,i);
      g_ctx[idx].struct[c].price = isH ? iHigh(s,PERIOD_M5,i) : iLow(s,PERIOD_M5,i);
      g_ctx[idx].struct[c].isHigh = isH;
      g_ctx[idx].struct[c].isBOS=false; g_ctx[idx].struct[c].isCHoCH=false; g_ctx[idx].struct[c].isMSS=false;
      double range=iHigh(s,PERIOD_M5,i)-iLow(s,PERIOD_M5,i);
      double atrRef=g_ctx[idx].vol.atrCurrent>0?g_ctx[idx].vol.atrCurrent:g_ctx[idx].point*100;
      g_ctx[idx].struct[c].strength=(int)MathMin(5,MathMax(1, range/atrRef*3));
      g_ctx[idx].struct[c].isMajor=(g_ctx[idx].struct[c].strength>=4);
      g_ctx[idx].struct[c].isInternal=true; g_ctx[idx].struct[c].isProtected=false; g_ctx[idx].struct[c].swept=false;
      g_ctx[idx].structCount++;
   }
   // BOS/CHoCH detection
   if(g_ctx[idx].structCount>=3) {
      bool up=false;
      for(int i=g_ctx[idx].structCount-1;i>=2;i--) {
         if(g_ctx[idx].struct[i].isHigh) {
            for(int j=i-1;j>=0;j--) {
               if(g_ctx[idx].struct[j].isHigh) {
                  if(g_ctx[idx].struct[i].price>g_ctx[idx].struct[j].price) { g_ctx[idx].struct[i].isBOS=up; g_ctx[idx].struct[i].isCHoCH=!up; up=true; }
                  break;
               }
            }
         } else {
            for(int j=i-1;j>=0;j--) {
               if(!g_ctx[idx].struct[j].isHigh) {
                  if(g_ctx[idx].struct[i].price<g_ctx[idx].struct[j].price) { g_ctx[idx].struct[i].isBOS=!up; g_ctx[idx].struct[i].isCHoCH=up; up=false; }
                  break;
               }
            }
         }
      }
   }
   // MSS: CHoCH confirmed by follow-through BOS
   for(int i=0;i<g_ctx[idx].structCount;i++) {
      if(!g_ctx[idx].struct[i].isCHoCH) continue;
      for(int k=i+1;k<MathMin(g_ctx[idx].structCount,i+4);k++) {
         if(g_ctx[idx].struct[k].isBOS && g_ctx[idx].struct[k].isHigh==g_ctx[idx].struct[i].isHigh) { g_ctx[idx].struct[i].isMSS=true; break; }
      }
   }
}

//=====================================================================
//  ORDER BLOCK DETECTION (per-symbol)
//=====================================================================
void DetectOrderBlocks(int idx) {
   string s = g_ctx[idx].symbol;
   ArrayResize(g_ctx[idx].obs, 0); g_ctx[idx].obCount = 0;
   int lb = MathMin(InpStructureLookback, (int)Bars(s,PERIOD_M5)-5);
   for(int i=3;i<lb;i++) {
      double c1=iClose(s,PERIOD_M5,i), o1=iOpen(s,PERIOD_M5,i), h1=iHigh(s,PERIOD_M5,i), l1=iLow(s,PERIOD_M5,i);
      double c2=iClose(s,PERIOD_M5,i-1), o2=iOpen(s,PERIOD_M5,i-1), c3=iClose(s,PERIOD_M5,i-2);
      bool bullOB=(c1<o1)&&(c2>o2)&&(c3>c2);
      bool bearOB=(c1>o1)&&(c2<o2)&&(c3<c2);
      if(!bullOB && !bearOB) continue;
      bool mit = bullOB ? (iLow(s,PERIOD_M5,0)<l1) : (iHigh(s,PERIOD_M5,0)>h1);
      if(mit && i>=10) continue;
      ArrayResize(g_ctx[idx].obs, g_ctx[idx].obCount+1);
      int c=g_ctx[idx].obCount;
      g_ctx[idx].obs[c].time=iTime(s,PERIOD_M5,i); g_ctx[idx].obs[c].high=h1; g_ctx[idx].obs[c].low=l1;
      g_ctx[idx].obs[c].isBullish=bullOB; g_ctx[idx].obs[c].mitigated=mit;
      double move=bullOB?(c3-l1):(h1-c3);
      double atrRef=g_ctx[idx].vol.atrCurrent>0?g_ctx[idx].vol.atrCurrent:g_ctx[idx].point*100;
      g_ctx[idx].obs[c].strength=(int)MathMin(5,MathMax(1, move/atrRef*2));
      g_ctx[idx].obCount++;
   }
}

//=====================================================================
//  FVG DETECTION (per-symbol)
//=====================================================================
void DetectFairValueGaps(int idx) {
   string s = g_ctx[idx].symbol;
   ArrayResize(g_ctx[idx].fvgs, 0); g_ctx[idx].fvgCount = 0;
   int lb = MathMin(InpStructureLookback, (int)Bars(s,PERIOD_M5)-3);
   for(int i=2;i<lb;i++) {
      double h0=iHigh(s,PERIOD_M5,i-2), l0=iLow(s,PERIOD_M5,i-2);
      double h2=iHigh(s,PERIOD_M5,i), l2=iLow(s,PERIOD_M5,i);
      bool bullFVG=(l0>h2); bool bearFVG=(h0<l2);
      if(!bullFVG && !bearFVG) continue;
      double price=SymbolInfoDouble(s,SYMBOL_BID);
      bool filled = bullFVG ? (price<h2) : (price>l2);
      if(filled && i>=20) continue;
      ArrayResize(g_ctx[idx].fvgs, g_ctx[idx].fvgCount+1);
      int c=g_ctx[idx].fvgCount;
      g_ctx[idx].fvgs[c].startTime=iTime(s,PERIOD_M5,i);
      g_ctx[idx].fvgs[c].topPrice = bullFVG ? l0 : l2;
      g_ctx[idx].fvgs[c].bottomPrice = bullFVG ? h2 : h0;
      g_ctx[idx].fvgs[c].isBullish = bullFVG; g_ctx[idx].fvgs[c].filled = filled;
      g_ctx[idx].fvgCount++;
   }
}

//=====================================================================
//  REGIME CLASSIFICATION (per-symbol)
//=====================================================================
double ScoreTrending(int idx) {
   double sc=0;
   sc += g_ctx[idx].mtf.alignment*0.5;
   if(g_ctx[idx].mtf.m5Bias!=0 && g_ctx[idx].mtf.m5Bias==g_ctx[idx].mtf.h1Bias) sc+=20;
   if(g_ctx[idx].vol.state==VOL_NORMAL||g_ctx[idx].vol.state==VOL_HIGH) sc+=15;
   if(g_ctx[idx].vol.dynamic==VOLDYN_EXPANDING) sc+=10;
   return MathMin(100.0, sc);
}
double ScoreRanging(int idx) {
   double sc=0;
   if(g_ctx[idx].mtf.alignment<40) sc+=40;
   if(g_ctx[idx].vol.state==VOL_LOW||g_ctx[idx].vol.state==VOL_NORMAL) sc+=25;
   if(g_ctx[idx].vol.dynamic==VOLDYN_STABLE) sc+=20;
   double hh=StructHiS(g_ctx[idx].symbol,InpStructureLookback), ll=StructLoS(g_ctx[idx].symbol,InpStructureLookback);
   double mid=(hh+ll)/2.0; double price=SymbolInfoDouble(g_ctx[idx].symbol,SYMBOL_BID);
   double rp=(hh>ll)?MathAbs(price-mid)/((hh-ll)/2.0):1.0;
   if(rp<0.6) sc+=15;
   return MathMin(100.0, sc);
}
double ScoreBreakout(int idx) {
   string s=g_ctx[idx].symbol;
   double sc=0;
   double hh=StructHiS(s,InpStructureLookback,1), ll=StructLoS(s,InpStructureLookback,1);
   double price=SymbolInfoDouble(s,SYMBOL_BID);
   if(price>hh||price<ll) sc+=45;
   if(g_ctx[idx].vol.dynamic==VOLDYN_EXPANDING) sc+=25;
   if(g_ctx[idx].vol.state==VOL_HIGH) sc+=15;
   if(g_ctx[idx].mtf.alignment>60) sc+=15;
   return MathMin(100.0, sc);
}
double ScoreCompression(int idx) {
   double sc=0;
   if(g_ctx[idx].vol.state==VOL_LOW) sc+=35;
   if(g_ctx[idx].vol.dynamic==VOLDYN_COMPRESSING) sc+=35;
   if(g_ctx[idx].vol.percentile<15) sc+=20;
   if(g_ctx[idx].mtf.alignment<30) sc+=10;
   return MathMin(100.0, sc);
}
double ScoreExpansion(int idx) {
   double sc=0;
   if(g_ctx[idx].vol.dynamic==VOLDYN_EXPANDING) sc+=40;
   if(g_ctx[idx].vol.state==VOL_HIGH) sc+=25;
   if(g_ctx[idx].vol.atrRatio>1.3) sc+=20;
   if(g_ctx[idx].mtf.alignment>50) sc+=15;
   return MathMin(100.0, sc);
}
double ScoreLiquiditySweep(int idx) {
   double sc=0;
   if(g_ctx[idx].liq.sweepUpDetected||g_ctx[idx].liq.sweepDownDetected) sc+=50;
   sc += g_ctx[idx].liq.sweepProbability*0.3;
   sc += g_ctx[idx].liq.pressureScore*0.2;
   return MathMin(100.0, sc);
}
double ScoreExhaustion(int idx) {
   double sc=0;
   double rsi=GetBuf(g_ctx[idx].h_m5rsi,0,0);
   if(rsi>72||rsi<28) sc+=35;
   if(g_ctx[idx].vol.dynamic==VOLDYN_COMPRESSING && g_ctx[idx].vol.atrRatio<0.85) sc+=25;
   if(g_ctx[idx].mtf.m1Bias!=0 && g_ctx[idx].mtf.m5Bias!=0 && g_ctx[idx].mtf.m1Bias!=g_ctx[idx].mtf.m5Bias) sc+=20;
   return MathMin(100.0, sc);
}
double ScoreMeanReversion(int idx) {
   double sc=0;
   double rsi=GetBuf(g_ctx[idx].h_m5rsi,0,0);
   if(rsi>70||rsi<30) sc+=30;
   if(g_ctx[idx].vol.state==VOL_NORMAL) sc+=20;
   if(g_ctx[idx].mtf.alignment<45) sc+=25;
   if(g_ctx[idx].liq.sweepUpDetected||g_ctx[idx].liq.sweepDownDetected) sc+=15;
   return MathMin(100.0, sc);
}
double ScoreUnsafe(int idx) {
   string s=g_ctx[idx].symbol;
   double sc=0;
   if(g_newsState==NEWS_SHOCK) sc+=60;
   if(g_ctx[idx].vol.state==VOL_EXTREME) sc+=25;
   double spread=(double)SymbolInfoInteger(s,SYMBOL_SPREAD);
   if(spread>InpMaxSpreadPoints) sc+=30;
   return MathMin(100.0, sc);
}

void UpdateRegimeClassification(int idx) {
   ENUM_REGIME cands[10]={REGIME_TRENDING,REGIME_RANGING,REGIME_BREAKOUT,REGIME_COMPRESSION,REGIME_EXPANSION,REGIME_VOLATILITY_SHOCK,REGIME_LIQUIDITY_SWEEP,REGIME_EXHAUSTION,REGIME_MEAN_REVERSION,REGIME_UNSAFE};
   double scores[10];
   scores[0]=ScoreTrending(idx); scores[1]=ScoreRanging(idx); scores[2]=ScoreBreakout(idx);
   scores[3]=ScoreCompression(idx); scores[4]=ScoreExpansion(idx); scores[5]=ScoreVolatilityShock(idx);
   scores[6]=ScoreLiquiditySweep(idx); scores[7]=ScoreExhaustion(idx); scores[8]=ScoreMeanReversion(idx);
   scores[9]=ScoreUnsafe(idx);
   int best=0; double bestS=scores[0];
   for(int i=1;i<10;i++) if(scores[i]>bestS){bestS=scores[i];best=i;}
   if(scores[9]>=75.0){best=9;bestS=scores[9];}
   g_ctx[idx].regime.regime=cands[best]; g_ctx[idx].regime.confidence=bestS;
}

double ScoreVolatilityShock(int idx) {
   double sc=0;
   if(g_ctx[idx].vol.dynamic==VOLDYN_SPIKE) sc+=50;
   if(g_ctx[idx].vol.state==VOL_EXTREME) sc+=30;
   if(g_newsState==NEWS_SHOCK) sc+=20;
   return MathMin(100.0, sc);
}

//=====================================================================
//  EXECUTION QUALITY (per-symbol)
//=====================================================================
void UpdateExecutionQuality(int idx) {
   string s=g_ctx[idx].symbol;
   double spread=(double)SymbolInfoInteger(s,SYMBOL_SPREAD);
   g_ctx[idx].exec.spreadScore=MathMax(0.0, 100.0*(1.0-spread/InpMaxSpreadPoints));
   double slRisk=(g_newsState==NEWS_SHOCK)?90:((g_newsState==NEWS_CAUTION)?50:MathMin(40.0, spread/InpMaxSpreadPoints*40.0));
   g_ctx[idx].exec.slippageRiskScore=100.0-slRisk;
   double vq=100;
   if(g_ctx[idx].vol.state==VOL_EXTREME) vq=20; else if(g_ctx[idx].vol.state==VOL_HIGH) vq=65; else if(g_ctx[idx].vol.state==VOL_LOW) vq=80;
   g_ctx[idx].exec.volatilityQuality=vq;
   double lq=100;
   if(g_ctx[idx].session.current==SESSION_DEAD_ZONE) lq=35; else if(g_ctx[idx].session.current==SESSION_ASIAN) lq=70;
   g_ctx[idx].exec.liquidityQuality=lq;
   double eff=100;
   if(g_ctx[idx].vol.atrCurrent>0) {
      double spreadPrice=spread*g_ctx[idx].point;
      double costRatio=spreadPrice/g_ctx[idx].vol.atrCurrent;
      eff=MathMax(0.0, 100.0*(1.0-costRatio*5.0));
   }
   g_ctx[idx].exec.efficiencyScore=eff;
   g_ctx[idx].exec.compositeScore = g_ctx[idx].exec.spreadScore*0.25 + g_ctx[idx].exec.slippageRiskScore*0.25 + g_ctx[idx].exec.volatilityQuality*0.20 + g_ctx[idx].exec.liquidityQuality*0.15 + g_ctx[idx].exec.efficiencyScore*0.15;
   g_ctx[idx].exec.executionApproved = (spread<=InpMaxSpreadPoints && g_ctx[idx].exec.compositeScore>=g_adaptiveExecScoreThreshold && g_newsState!=NEWS_SHOCK);
}

//=====================================================================
//  ═══════════════════════════════════════════════════════════
//  STRATEGY 1: SMART MONEY CONCEPTS ENGINE
//  ═══════════════════════════════════════════════════════════
//=====================================================================
StrategySignal Strategy_SMC(int idx) {
   StrategySignal s; s.source=STRAT_SMC; s.direction=DIR_NONE; s.valid=false; s.reason="";
   string sym=g_ctx[idx].symbol;

   bool sweepUp=g_ctx[idx].liq.sweepUpDetected;
   bool sweepDn=g_ctx[idx].liq.sweepDownDetected;
   bool hasBOS=false, hasCHoCH=false, hasMSS=false;
   for(int i=0;i<g_ctx[idx].structCount;i++) {
      if(g_ctx[idx].struct[i].isBOS) hasBOS=true;
      if(g_ctx[idx].struct[i].isCHoCH) hasCHoCH=true;
      if(g_ctx[idx].struct[i].isMSS) hasMSS=true;
   }

   double atr=g_ctx[idx].vol.atrCurrent; if(atr<=0) atr=g_ctx[idx].point*100;
   double price=SymbolInfoDouble(sym,SYMBOL_BID);

   if(sweepDn && (hasMSS||hasCHoCH)) {
      s.direction=DIR_LONG; s.valid=true;
      s.confidence=MathMin(93.0, 60.0+g_ctx[idx].liq.sweepProbability*0.3);
      s.suggestedSL=NPriceD(sym, g_ctx[idx].liq.equalLowLevel-atr*0.3);
      s.suggestedTP=NPriceD(sym, price+atr*2.5);
      s.reason="SMC: Liq sweep down + CHoCH/MSS bullish";
   } else if(sweepUp && (hasMSS||hasCHoCH)) {
      s.direction=DIR_SHORT; s.valid=true;
      s.confidence=MathMin(93.0, 60.0+g_ctx[idx].liq.sweepProbability*0.3);
      s.suggestedSL=NPriceD(sym, g_ctx[idx].liq.equalHighLevel+atr*0.3);
      s.suggestedTP=NPriceD(sym, price-atr*2.5);
      s.reason="SMC: Liq sweep up + CHoCH/MSS bearish";
   } else if(hasBOS && g_ctx[idx].mtf.h1Bias>0) {
      s.direction=DIR_LONG; s.valid=true; s.confidence=70.0;
      s.suggestedSL=NPriceD(sym, price-atr*1.8); s.suggestedTP=NPriceD(sym, price+atr*3.6);
      s.reason="SMC: BOS up aligned with H1 trend";
   } else if(hasBOS && g_ctx[idx].mtf.h1Bias<0) {
      s.direction=DIR_SHORT; s.valid=true; s.confidence=70.0;
      s.suggestedSL=NPriceD(sym, price+atr*1.8); s.suggestedTP=NPriceD(sym, price-atr*3.6);
      s.reason="SMC: BOS down aligned with H1 trend";
   } else { s.reason="SMC: No confluence sweep+BOS"; }
   return s;
}

//=====================================================================
//  ═══════════════════════════════════════════════════════════
//  STRATEGY 2: MTF MOMENTUM CONFLUENCE  (NEW)
//  ═══════════════════════════════════════════════════════════
//=====================================================================
StrategySignal Strategy_MTFMomentum(int idx) {
   StrategySignal s; s.source=STRAT_MTF_MOMENTUM; s.direction=DIR_NONE; s.valid=false; s.reason="";
   string sym=g_ctx[idx].symbol;

   double rsi=GetBuf(g_ctx[idx].h_m5rsi,0,1);
   double macdM=GetBuf(g_ctx[idx].h_m15macd,0,1);
   double macdS=GetBuf(g_ctx[idx].h_m15macd,1,1);
   double emaF=GetBuf(g_ctx[idx].h_m5emaF,0,1);
   double price=iClose(sym,PERIOD_M5,1);

   bool bull = (price>emaF) && (g_ctx[idx].mtf.h1Bias>0) && (g_ctx[idx].mtf.m15Bias>0) && (rsi>50) && (macdM>macdS);
   bool bear = (price<emaF) && (g_ctx[idx].mtf.h1Bias<0) && (g_ctx[idx].mtf.m15Bias<0) && (rsi<50) && (macdM<macdS);

   double atr=g_ctx[idx].vol.atrCurrent; if(atr<=0) atr=g_ctx[idx].point*100;

   if(bull) {
      s.direction=DIR_LONG; s.valid=true;
      s.confidence=MathMin(90.0, g_ctx[idx].mtf.alignment*0.8+MathAbs(rsi-50)*0.4);
      double entry=SymbolInfoDouble(sym,SYMBOL_ASK);
      s.suggestedSL=NPriceD(sym, entry-atr*1.8); s.suggestedTP=NPriceD(sym, entry+atr*3.6);
      s.reason="MTF: 4-TF bull align "+DoubleToString(g_ctx[idx].mtf.alignment,0)+"% RSI="+DoubleToString(rsi,0);
   } else if(bear) {
      s.direction=DIR_SHORT; s.valid=true;
      s.confidence=MathMin(90.0, g_ctx[idx].mtf.alignment*0.8+MathAbs(rsi-50)*0.4);
      double entry=SymbolInfoDouble(sym,SYMBOL_BID);
      s.suggestedSL=NPriceD(sym, entry+atr*1.8); s.suggestedTP=NPriceD(sym, entry-atr*3.6);
      s.reason="MTF: 4-TF bear align "+DoubleToString(g_ctx[idx].mtf.alignment,0)+"% RSI="+DoubleToString(rsi,0);
   } else { s.reason="MTF: No alignment"; }
   return s;
}

//=====================================================================
//  ═══════════════════════════════════════════════════════════
//  STRATEGY 3: VOLATILITY BREAKOUT
//  ═══════════════════════════════════════════════════════════
//=====================================================================
StrategySignal Strategy_VolBreakout(int idx) {
   StrategySignal s; s.source=STRAT_VOL_BREAKOUT; s.direction=DIR_NONE; s.valid=false; s.reason="";
   string sym=g_ctx[idx].symbol;

   if(g_ctx[idx].vol.dynamic!=VOLDYN_EXPANDING) { s.reason="Vol: Not expanding"; return s; }
   double hh=StructHiS(sym,InpStructureLookback,1), ll=StructLoS(sym,InpStructureLookback,1);
   double price=SymbolInfoDouble(sym,SYMBOL_BID);
   double atr=g_ctx[idx].vol.atrCurrent; if(atr<=0) atr=g_ctx[idx].point*100;

   if(price>hh) {
      s.direction=DIR_LONG; s.valid=true;
      double entry=SymbolInfoDouble(sym,SYMBOL_ASK);
      s.suggestedSL=NPriceD(sym, hh-atr*0.4); s.suggestedTP=NPriceD(sym, entry+atr*3.0);
      s.confidence=MathMin(92.0, 50.0+g_ctx[idx].vol.atrRatio*20.0);
      s.reason="Vol: Breakout up ATRx"+DoubleToString(g_ctx[idx].vol.atrRatio,2);
   } else if(price<ll) {
      s.direction=DIR_SHORT; s.valid=true;
      double entry=SymbolInfoDouble(sym,SYMBOL_BID);
      s.suggestedSL=NPriceD(sym, ll+atr*0.4); s.suggestedTP=NPriceD(sym, entry-atr*3.0);
      s.confidence=MathMin(92.0, 50.0+g_ctx[idx].vol.atrRatio*20.0);
      s.reason="Vol: Breakout down ATRx"+DoubleToString(g_ctx[idx].vol.atrRatio,2);
   } else { s.reason="Vol: No break yet"; }
   return s;
}

//=====================================================================
//  ═══════════════════════════════════════════════════════════
//  STRATEGY 4: VOLUME SPREAD ANALYSIS  (NEW)
//  ═══════════════════════════════════════════════════════════
//=====================================================================
StrategySignal Strategy_VSA(int idx) {
   StrategySignal s; s.source=STRAT_VSA; s.direction=DIR_NONE; s.valid=false; s.reason="";
   string sym=g_ctx[idx].symbol;

   MqlRates r[];
   if(CopyRates(sym,PERIOD_M5,0,25,r)<25) { s.reason="VSA: No data"; return s; }
   long avgVol=0;
   for(int i=2;i<25;i++) avgVol+=(long)r[i].tick_volume;
   avgVol/=23; if(avgVol<=0) { s.reason="VSA: No volume"; return s; }

   double spread=r[1].high-r[1].low;
   double body=MathAbs(r[1].close-r[1].open);
   bool highVol=((long)r[1].tick_volume)>(avgVol*16/10);
   bool smallBody=body<spread*0.4;
   bool upClose=r[1].close>r[1].open;
   double atr=g_ctx[idx].vol.atrCurrent; if(atr<=0) atr=g_ctx[idx].point*100;

   if(highVol && smallBody && upClose) {
      s.direction=DIR_LONG; s.valid=true; s.confidence=65.0;
      double entry=SymbolInfoDouble(sym,SYMBOL_ASK);
      s.suggestedSL=NPriceD(sym, entry-atr*1.5); s.suggestedTP=NPriceD(sym, entry+atr*3.0);
      s.reason="VSA: Demand bar (high vol, no result, up close)";
   } else if(highVol && smallBody && !upClose) {
      s.direction=DIR_SHORT; s.valid=true; s.confidence=65.0;
      double entry=SymbolInfoDouble(sym,SYMBOL_BID);
      s.suggestedSL=NPriceD(sym, entry+atr*1.5); s.suggestedTP=NPriceD(sym, entry-atr*3.0);
      s.reason="VSA: Supply bar (high vol, no result, dn close)";
   } else { s.reason="VSA: No signal"; }
   return s;
}

//=====================================================================
//  ═══════════════════════════════════════════════════════════
//  STRATEGY 5: AI-STYLE PATTERN RECOGNITION  (NEW)
//  ═══════════════════════════════════════════════════════════
//=====================================================================
StrategySignal Strategy_Pattern(int idx) {
   StrategySignal s; s.source=STRAT_PATTERN; s.direction=DIR_NONE; s.valid=false; s.reason="";
   string sym=g_ctx[idx].symbol;
   MqlRates r[];
   if(CopyRates(sym,PERIOD_M5,0,5,r)<5) { s.reason="Pat: No data"; return s; }

   double atr=g_ctx[idx].vol.atrCurrent; if(atr<=0) atr=g_ctx[idx].point*100;
   bool bullEng=(r[1].close>r[1].open)&&(r[2].close<r[2].open)&&(r[1].close>r[2].open)&&(r[1].open<r[2].close);
   bool bearEng=(r[1].close<r[1].open)&&(r[2].close>r[2].open)&&(r[1].close<r[2].open)&&(r[1].open>r[2].close);
   double sp1=r[1].high-r[1].low, b1=MathAbs(r[1].close-r[1].open);
   bool bullPin=(r[1].low<r[2].low)&&(b1<sp1*0.3)&&((r[1].close-r[1].low)>sp1*0.6);
   bool bearPin=(r[1].high>r[2].high)&&(b1<sp1*0.3)&&((r[1].high-r[1].close)>sp1*0.6);

   if(bullEng) {
      s.direction=DIR_LONG; s.valid=true; s.confidence=62.0;
      double entry=SymbolInfoDouble(sym,SYMBOL_ASK);
      s.suggestedSL=NPriceD(sym, entry-atr*1.5); s.suggestedTP=NPriceD(sym, entry+atr*3.0);
      s.reason="Pat: Bullish engulfing";
   } else if(bearEng) {
      s.direction=DIR_SHORT; s.valid=true; s.confidence=62.0;
      double entry=SymbolInfoDouble(sym,SYMBOL_BID);
      s.suggestedSL=NPriceD(sym, entry+atr*1.5); s.suggestedTP=NPriceD(sym, entry-atr*3.0);
      s.reason="Pat: Bearish engulfing";
   } else if(bullPin) {
      s.direction=DIR_LONG; s.valid=true; s.confidence=58.0;
      double entry=SymbolInfoDouble(sym,SYMBOL_ASK);
      s.suggestedSL=NPriceD(sym, r[1].low-atr*0.2); s.suggestedTP=NPriceD(sym, entry+atr*2.5);
      s.reason="Pat: Bullish pinbar";
   } else if(bearPin) {
      s.direction=DIR_SHORT; s.valid=true; s.confidence=58.0;
      double entry=SymbolInfoDouble(sym,SYMBOL_BID);
      s.suggestedSL=NPriceD(sym, r[1].high+atr*0.2); s.suggestedTP=NPriceD(sym, entry-atr*2.5);
      s.reason="Pat: Bearish pinbar";
   } else { s.reason="Pat: No pattern"; }
   return s;
}

//=====================================================================
//  ═══════════════════════════════════════════════════════════
//  STRATEGY 6: AUTO-FIBONACCI CONFLUENCE  (NEW)
//  ═══════════════════════════════════════════════════════════
//=====================================================================
StrategySignal Strategy_Fib(int idx) {
   StrategySignal s; s.source=STRAT_FIB; s.direction=DIR_NONE; s.valid=false; s.reason="";
   string sym=g_ctx[idx].symbol;
   MqlRates r[];
   if(CopyRates(sym,PERIOD_M5,0,55,r)<55) { s.reason="Fib: No data"; return s; }
   double hi=-1e9, lo=1e9; int hiI=0, loI=0;
   for(int i=0;i<50;i++) { if(r[i].high>hi){hi=r[i].high;hiI=i;} if(r[i].low<lo){lo=r[i].low;loI=i;} }
   bool uptrend=(loI>hiI);
   double range=hi-lo; if(range<=0) { s.reason="Fib: No range"; return s; }
   double price=iClose(sym,PERIOD_M5,1);
   double retr = uptrend ? (hi-price)/range : (price-lo)/range;
   double atr=g_ctx[idx].vol.atrCurrent; if(atr<=0) atr=g_ctx[idx].point*100;

   if(uptrend && retr>0.61 && retr<0.66) {
      s.direction=DIR_LONG; s.valid=true; s.confidence=68.0;
      double entry=SymbolInfoDouble(sym,SYMBOL_ASK);
      s.suggestedSL=NPriceD(sym, lo-atr*0.3); s.suggestedTP=NPriceD(sym, entry+atr*3.0);
      s.reason="Fib: 61.8% retrace in uptrend";
   } else if(!uptrend && retr>0.61 && retr<0.66) {
      s.direction=DIR_SHORT; s.valid=true; s.confidence=68.0;
      double entry=SymbolInfoDouble(sym,SYMBOL_BID);
      s.suggestedSL=NPriceD(sym, hi+atr*0.3); s.suggestedTP=NPriceD(sym, entry-atr*3.0);
      s.reason="Fib: 61.8% retrace in downtrend";
   } else { s.reason="Fib: Not at 61.8%"; }
   return s;
}

//=====================================================================
//  ═══════════════════════════════════════════════════════════
//  STRATEGY 7: ADAPTIVE TREND RIBBON  (NEW)
//  ═══════════════════════════════════════════════════════════
//=====================================================================
StrategySignal Strategy_TrendRibbon(int idx) {
   StrategySignal s; s.source=STRAT_TREND_RIBBON; s.direction=DIR_NONE; s.valid=false; s.reason="";
   string sym=g_ctx[idx].symbol;
   double e8=GetBuf(g_ctx[idx].h_ema8,0,1), e21=GetBuf(g_ctx[idx].h_ema21,0,1);
   double e50=GetBuf(g_ctx[idx].h_ema50,0,1), e100=GetBuf(g_ctx[idx].h_ema100,0,1);
   double e200=GetBuf(g_ctx[idx].h_ema200,0,1);
   double e8p=GetBuf(g_ctx[idx].h_ema8,0,3);
   double price=iClose(sym,PERIOD_M5,1);
   double atr=g_ctx[idx].vol.atrCurrent; if(atr<=0) atr=g_ctx[idx].point*100;

   bool stackUp=(e8>e21)&&(e21>e50)&&(e50>e100)&&(e100>e200)&&(price>e8)&&(e8>e8p);
   bool stackDn=(e8<e21)&&(e21<e50)&&(e50<e100)&&(e100<e200)&&(price<e8)&&(e8<e8p);

   if(stackUp) {
      s.direction=DIR_LONG; s.valid=true; s.confidence=75.0;
      double entry=SymbolInfoDouble(sym,SYMBOL_ASK);
      s.suggestedSL=NPriceD(sym, entry-atr*2.0); s.suggestedTP=NPriceD(sym, entry+atr*4.0);
      s.reason="Ribbon: 5-EMA stacked bullish + slope";
   } else if(stackDn) {
      s.direction=DIR_SHORT; s.valid=true; s.confidence=75.0;
      double entry=SymbolInfoDouble(sym,SYMBOL_BID);
      s.suggestedSL=NPriceD(sym, entry+atr*2.0); s.suggestedTP=NPriceD(sym, entry-atr*4.0);
      s.reason="Ribbon: 5-EMA stacked bearish + slope";
   } else { s.reason="Ribbon: Not stacked"; }
   return s;
}

//=====================================================================
//  ═══════════════════════════════════════════════════════════
//  STRATEGY 8: STATISTICAL Z-SCORE MEAN REVERSION  (NEW)
//  ═══════════════════════════════════════════════════════════
//=====================================================================
StrategySignal Strategy_ZScore(int idx) {
   StrategySignal s; s.source=STRAT_ZSCORE; s.direction=DIR_NONE; s.valid=false; s.reason="";
   string sym=g_ctx[idx].symbol;
   double c[];
   if(CopyClose(sym,PERIOD_M5,1,50,c)<50) { s.reason="ZSc: No data"; return s; }
   double mean=0; for(int i=0;i<50;i++) mean+=c[i]; mean/=50.0;
   double sd=0; for(int i=0;i<50;i++) sd+=MathPow(c[i]-mean,2); sd=MathSqrt(sd/50.0);
   if(sd<=0) { s.reason="ZSc: No variance"; return s; }
   double z=(c[0]-mean)/sd;
   double atr=g_ctx[idx].vol.atrCurrent; if(atr<=0) atr=g_ctx[idx].point*100;

   if(z>2.2) {
      s.direction=DIR_SHORT; s.valid=true; s.confidence=MathMin(70.0, MathAbs(z)*25.0);
      double entry=SymbolInfoDouble(sym,SYMBOL_BID);
      s.suggestedSL=NPriceD(sym, entry+atr*1.5); s.suggestedTP=NPriceD(sym, mean);
      s.reason="ZSc: Z="+DoubleToString(z,2)+" extreme overbought";
   } else if(z<-2.2) {
      s.direction=DIR_LONG; s.valid=true; s.confidence=MathMin(70.0, MathAbs(z)*25.0);
      double entry=SymbolInfoDouble(sym,SYMBOL_ASK);
      s.suggestedSL=NPriceD(sym, entry-atr*1.5); s.suggestedTP=NPriceD(sym, mean);
      s.reason="ZSc: Z="+DoubleToString(z,2)+" extreme oversold";
   } else { s.reason="ZSc: Z="+DoubleToString(z,2)+" within range"; }
   return s;
}

//=====================================================================
//  ═══════════════════════════════════════════════════════════
//  STRATEGY 9: SESSION & LIQUIDITY ENGINE
//  ═══════════════════════════════════════════════════════════
//=====================================================================
StrategySignal Strategy_SessionLiquidity(int idx) {
   StrategySignal s; s.source=STRAT_SESSION_LIQUIDITY; s.direction=DIR_NONE; s.valid=false; s.reason="";
   string sym=g_ctx[idx].symbol;
   double atr=g_ctx[idx].vol.atrCurrent; if(atr<=0) atr=g_ctx[idx].point*100;
   double price=SymbolInfoDouble(sym,SYMBOL_BID);

   // Session boundary reversal: price at session extreme → reversal
   bool atSessionHigh = g_ctx[idx].sessionHigh>0 && MathAbs(price-g_ctx[idx].sessionHigh)<atr*0.3;
   bool atSessionLow  = g_ctx[idx].sessionLow>0 && MathAbs(price-g_ctx[idx].sessionLow)<atr*0.3;

   if(atSessionHigh && g_ctx[idx].liq.sweepUpDetected) {
      s.direction=DIR_SHORT; s.valid=true; s.confidence=60.0;
      double entry=SymbolInfoDouble(sym,SYMBOL_BID);
      s.suggestedSL=NPriceD(sym, g_ctx[idx].sessionHigh+atr*0.3); s.suggestedTP=NPriceD(sym, entry-atr*2.0);
      s.reason="Sess: Sweep of session high";
   } else if(atSessionLow && g_ctx[idx].liq.sweepDownDetected) {
      s.direction=DIR_LONG; s.valid=true; s.confidence=60.0;
      double entry=SymbolInfoDouble(sym,SYMBOL_ASK);
      s.suggestedSL=NPriceD(sym, g_ctx[idx].sessionLow-atr*0.3); s.suggestedTP=NPriceD(sym, entry+atr*2.0);
      s.reason="Sess: Sweep of session low";
   } else { s.reason="Sess: "+RegimeToString(g_ctx[idx].regime.regime)+" w="+DoubleToString(g_ctx[idx].session.strategyWeight,2); }
   return s;
}

//=====================================================================
//  ═══════════════════════════════════════════════════════════
//  STRATEGY 10: NEWS-ADAPTIVE FILTER  (GATE, NOT SIGNAL)
//  ═══════════════════════════════════════════════════════════
//=====================================================================
bool Strategy_NewsBlocked(int idx) {
   if(g_newsState==NEWS_SHOCK) return true;
   return false;
}

//=====================================================================
//  ═══════════════════════════════════════════════════════════
//  CONFLUENCE ENGINE — THE BRAIN
//  Runs ALL 9 signal strategies simultaneously, weighted vote
//  ═══════════════════════════════════════════════════════════
//=====================================================================
MasterDecision BuildConfluenceDecision(int idx) {
   MasterDecision d;
   d.tradeApproved=false; d.direction=DIR_NONE; d.lotSize=0;
   d.slPrice=0; d.tpPrice=0; d.strategySource=STRAT_NONE;
   d.riskAmountUsed=0; d.narrative=""; d.confluenceScore=0;
   d.symbol=g_ctx[idx].symbol; d.entry=0;
   string sym=g_ctx[idx].symbol;

   // Run all 9 signal strategies
   g_ctx[idx].lastSignals[0] = Strategy_SMC(idx);
   g_ctx[idx].lastSignals[1] = Strategy_MTFMomentum(idx);
   g_ctx[idx].lastSignals[2] = Strategy_VolBreakout(idx);
   g_ctx[idx].lastSignals[3] = Strategy_VSA(idx);
   g_ctx[idx].lastSignals[4] = Strategy_Pattern(idx);
   g_ctx[idx].lastSignals[5] = Strategy_Fib(idx);
   g_ctx[idx].lastSignals[6] = Strategy_TrendRibbon(idx);
   g_ctx[idx].lastSignals[7] = Strategy_ZScore(idx);
   g_ctx[idx].lastSignals[8] = Strategy_SessionLiquidity(idx);

   double weights[9] = {InpWgtSMC, InpWgtMTFMom, InpWgtVolBreak, InpWgtVSA, InpWgtPattern, InpWgtFib, InpWgtTrendRibbon, InpWgtZScore, InpWgtSession};
   double bullScore=0, bearScore=0, totalW=0;
   string reasons="";

   for(int i=0;i<9;i++) {
      if(!g_ctx[idx].lastSignals[i].valid) { reasons+=StrategyToString((ENUM_STRATEGY)(i+1))+"(skip); "; continue; }
      totalW += weights[i];
      if(g_ctx[idx].lastSignals[i].direction==DIR_LONG) {
         bullScore += g_ctx[idx].lastSignals[i].confidence * weights[i];
         reasons += StrategyToString((ENUM_STRATEGY)(i+1))+"(BULL "+DoubleToString(g_ctx[idx].lastSignals[i].confidence,0)+"%); ";
      } else if(g_ctx[idx].lastSignals[i].direction==DIR_SHORT) {
         bearScore += g_ctx[idx].lastSignals[i].confidence * weights[i];
         reasons += StrategyToString((ENUM_STRATEGY)(i+1))+"(BEAR "+DoubleToString(g_ctx[idx].lastSignals[i].confidence,0)+"%); ";
      } else { reasons += StrategyToString((ENUM_STRATEGY)(i+1))+"(neutral); "; }
   }

   double netDir = bullScore - bearScore;
   int direction = (MathAbs(netDir)<5.0) ? DIR_NONE : (netDir>0?DIR_LONG:DIR_SHORT);
   double advantage = MathAbs(bullScore-bearScore);
   double confluenceScore = (totalW>0) ? (advantage/totalW*100.0) : 0.0;

   // Also factor in how many strategies agree
   int bullCount=0, bearCount=0;
   for(int i=0;i<9;i++) {
      if(!g_ctx[idx].lastSignals[i].valid) continue;
      if(g_ctx[idx].lastSignals[i].direction==DIR_LONG) bullCount++;
      else if(g_ctx[idx].lastSignals[i].direction==DIR_SHORT) bearCount++;
   }
   int agreeCount = (direction==DIR_LONG)?bullCount:(direction==DIR_SHORT?bearCount:0);
   double agreementBonus = (agreeCount>=5)?15.0:(agreeCount>=4)?10.0:(agreeCount>=3)?5.0:0.0;
   confluenceScore = MathMin(100.0, confluenceScore + agreementBonus);

   g_ctx[idx].confluenceScore = confluenceScore;
   g_ctx[idx].confluenceDir = (int)direction;
   g_ctx[idx].confluenceReason = reasons;

   // === GATES ===
   if(Strategy_NewsBlocked(idx)) { d.narrative="News blocked"; return d; }
   if(g_risk.emergencyShutdown) { d.narrative="Emergency shutdown"; return d; }
   if(g_risk.dailyLimitHit) { d.narrative="Daily limit"; return d; }
   if(g_risk.weeklyLimitHit) { d.narrative="Weekly limit"; return d; }
   if(g_ctx[idx].regime.regime==REGIME_UNSAFE) { d.narrative="Unsafe regime"; return d; }
   if(!g_ctx[idx].exec.executionApproved) { d.narrative="Exec: "+g_ctx[idx].exec.rejectReason; return d; }
   if(g_ctx[idx].inCooldown) { d.narrative="Cooldown"; return d; }
   if(PositionsTotalForMagicSymbol(sym)>=InpMaxPerSymbol) { d.narrative="Max per symbol"; return d; }
   if(PositionsTotalForMagic()>=InpMaxConcurrentTrades) { d.narrative="Max concurrent"; return d; }
   if(direction==DIR_NONE) { d.narrative="No direction ("+DoubleToString(confluenceScore,1)+"% net)"; return d; }
   if(confluenceScore < InpMinConfluenceScore) { d.narrative="Low score "+DoubleToString(confluenceScore,1)+"<"+DoubleToString(InpMinConfluenceScore,0); return d; }
   if(advantage < InpMinDirectionAdvantage) { d.narrative="Low advantage "+DoubleToString(advantage,1); return d; }

   // === BUILD TRADE ===
   double atr=g_ctx[idx].vol.atrCurrent; if(atr<=0) atr=g_ctx[idx].point*100;
   double entry = (direction==DIR_LONG) ? SymbolInfoDouble(sym,SYMBOL_ASK) : SymbolInfoDouble(sym,SYMBOL_BID);
   double sl = entry - (direction==DIR_LONG?1:-1)*InpATR_SL_Mult*atr;
   double tp = entry + (direction==DIR_LONG?1:-1)*InpATR_TP_Mult*atr;

   // Stops level check
   long stopsLevel = SymbolInfoInteger(sym, SYMBOL_TRADE_STOPS_LEVEL);
   double minDist = g_ctx[idx].point * stopsLevel * 2;
   if(MathAbs(entry-sl)<minDist) sl = entry - (direction==DIR_LONG?1:-1)*minDist;
   if(MathAbs(tp-entry)<minDist) tp = entry + (direction==DIR_LONG?1:-1)*minDist;

   double rr = MathAbs(tp-entry)/MathAbs(entry-sl);
   if(rr < InpMinRR) { d.narrative="Low RR "+DoubleToString(rr,2); return d; }

   // === LOT SIZING (risk-based) ===
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   double confFactor = MathMax(0.5, MathMin(1.0, confluenceScore/100.0));
   double riskPct = InpRiskPercentPerTrade * confFactor;
   riskPct = MathMin(riskPct, InpMaxRiskPercentTrade);
   double riskAmount = equity * riskPct/100.0;
   double tickVal = SymbolInfoDouble(sym, SYMBOL_TRADE_TICK_VALUE);
   double tickSize = SymbolInfoDouble(sym, SYMBOL_TRADE_TICK_SIZE);
   if(tickVal<=0 || tickSize<=0) { d.narrative="No tick info"; return d; }
   double slDist = MathAbs(entry-sl);
   double lossPerLot = (slDist/tickSize)*tickVal;
   if(lossPerLot<=0) { d.narrative="Invalid loss calc"; return d; }
   double lot = riskAmount/lossPerLot;
   double lotMin=SymbolInfoDouble(sym,SYMBOL_VOLUME_MIN), lotMax=SymbolInfoDouble(sym,SYMBOL_VOLUME_MAX), lotStep=SymbolInfoDouble(sym,SYMBOL_VOLUME_STEP);
   if(lotStep<=0) lotStep=0.01;
   lot = MathFloor(lot/lotStep)*lotStep;
   lot = MathMax(lotMin, MathMin(lotMax, lot));

   d.tradeApproved=true; d.direction=direction; d.lotSize=lot;
   d.slPrice=sl; d.tpPrice=tp; d.entry=entry;
   d.strategySource=STRAT_SMC; // primary strategy attribution
   d.riskAmountUsed=riskAmount; d.confluenceScore=confluenceScore;
   d.narrative = (direction==DIR_LONG?"BUY":"SELL")+" "+sym+" score="+DoubleToString(confluenceScore,1)+"% agree="+IntegerToString(agreeCount)+"/9 RR="+DoubleToString(rr,2);
   return d;
}

//=====================================================================
//  EXECUTION
//=====================================================================
bool ExecuteDecision(MasterDecision &d) {
   if(!d.tradeApproved || d.direction==DIR_NONE) return false;
   string sym=d.symbol;
   g_trade.SetExpertMagicNumber(InpMagic);
   g_trade.SetDeviationInPoints(30);
   g_trade.SetTypeFilling(GetFillMode());
   string tag = InpBotName+"|"+sym+"|"+DoubleToString(d.riskAmountUsed,2);
   bool ok = (d.direction==DIR_LONG)
      ? g_trade.Buy(d.lotSize, sym, d.entry, d.slPrice, d.tpPrice, tag)
      : g_trade.Sell(d.lotSize, sym, d.entry, d.slPrice, d.tpPrice, tag);
   if(ok) PushLog("TRADE "+(d.direction==DIR_LONG?"BUY":"SELL")+" "+sym+" lot="+DoubleToString(d.lotSize,2)+" score="+DoubleToString(d.confluenceScore,1)+"%");
   else   PushLog("TRADE FAIL "+sym+" err="+IntegerToString(GetLastError()));
   return ok;
}

//=====================================================================
//  TRADE MANAGEMENT (per-symbol)
//=====================================================================
void ManageOpenPositions() {
   for(int i=PositionsTotal()-1;i>=0;i--) {
      if(!g_pos.SelectByIndex(i)) continue;
      if(g_pos.Magic()!=InpMagic) continue;
      string sym=g_pos.Symbol();
      bool isLong=(g_pos.PositionType()==POSITION_TYPE_BUY);
      double openPrice=g_pos.PriceOpen(), curSL=g_pos.StopLoss(), curTP=g_pos.TakeProfit();
      double curPrice = isLong ? SymbolInfoDouble(sym,SYMBOL_BID) : SymbolInfoDouble(sym,SYMBOL_ASK);
      
      // Find context for this symbol
      int ctxIdx=-1;
      for(int j=0;j<g_ctxCount;j++) if(g_ctx[j].symbol==sym) { ctxIdx=j; break; }
      if(ctxIdx<0) continue;
      double atr=g_ctx[ctxIdx].vol.atrCurrent; if(atr<=0) continue;
      double profitDist = isLong ? (curPrice-openPrice) : (openPrice-curPrice);
      double profitATR = profitDist/atr;
      double newSL=curSL; bool needUpd=false;

      if(InpUseBreakEven && profitATR>=InpBreakEvenATR) {
         double bePrice = openPrice + (isLong?atr*0.2:-atr*0.2);
         if(isLong && curSL<bePrice) { newSL=NPriceD(sym,bePrice); needUpd=true; }
         if(!isLong && (curSL>bePrice||curSL==0)) { newSL=NPriceD(sym,bePrice); needUpd=true; }
      }
      if(InpUseTrailing && profitATR>=1.2) {
         double trail = isLong ? (curPrice-atr*InpTrailATR) : (curPrice+atr*InpTrailATR);
         if(isLong && trail>newSL) { newSL=NPriceD(sym,trail); needUpd=true; }
         if(!isLong && (trail<newSL||newSL==0)) { newSL=NPriceD(sym,trail); needUpd=true; }
      }
      if(InpUsePartialClose && profitATR>=InpPartialATR) {
         string cmt=g_pos.Comment();
         if(StringFind(cmt,"|P")==StringFind(cmt,"|")) { // not yet partial-closed
            double curLot=g_pos.Volume(), lotMin=SymbolInfoDouble(sym,SYMBOL_VOLUME_MIN);
            double closeLot=MathFloor(curLot*0.5/lotMin)*lotMin;
            if(closeLot>=lotMin) { g_trade.PositionClosePartial(g_pos.Ticket(), closeLot); PushLog("Partial 50% "+sym); }
         }
      }
      if(needUpd && newSL>0) g_trade.PositionModify(g_pos.Ticket(), newSL, curTP);
   }
}

//=====================================================================
//  RISK GOVERNANCE
//=====================================================================
void InitRiskState() {
   double eq=AccountInfoDouble(ACCOUNT_EQUITY);
   g_risk.peakEquity=eq; g_risk.dayStartEquity=eq; g_risk.weekStartEquity=eq;
   g_risk.dailyLimitHit=false; g_risk.weeklyLimitHit=false; g_risk.maxDrawdownBreached=false; g_risk.emergencyShutdown=false;
}
void UpdateRiskState() {
   double eq=AccountInfoDouble(ACCOUNT_EQUITY);
   if(eq>g_risk.peakEquity) g_risk.peakEquity=eq;
   g_risk.currentDrawdownPct=(g_risk.peakEquity>0)?(g_risk.peakEquity-eq)/g_risk.peakEquity*100.0:0.0;
   if(g_risk.currentDrawdownPct>g_risk.maxDrawdownSeenPct) g_risk.maxDrawdownSeenPct=g_risk.currentDrawdownPct;
   g_risk.dailyRiskUsedPct=(g_risk.dayStartEquity>0)?MathMax(0.0,(g_risk.dayStartEquity-eq)/g_risk.dayStartEquity*100.0):0.0;
   g_risk.weeklyRiskUsedPct=(g_risk.weekStartEquity>0)?MathMax(0.0,(g_risk.weekStartEquity-eq)/g_risk.weekStartEquity*100.0):0.0;
   g_risk.dailyLimitHit=(InpMaxDailyLossPct>0&&g_risk.dailyRiskUsedPct>=InpMaxDailyLossPct);
   g_risk.weeklyLimitHit=(InpMaxWeeklyLossPct>0&&g_risk.weeklyRiskUsedPct>=InpMaxWeeklyLossPct);
   if(InpMaxDrawdownPct>0&&g_risk.currentDrawdownPct>=InpMaxDrawdownPct) { g_risk.maxDrawdownBreached=true; g_risk.emergencyShutdown=true; }
}
void RolloverDailyWeekly() {
   datetime today=DayStart(TimeCurrent()), thisWeek=WeekStart(TimeCurrent());
   if(today!=g_dayStart) { g_dayStart=today; g_risk.dayStartEquity=AccountInfoDouble(ACCOUNT_EQUITY); g_risk.dailyLimitHit=false;
      for(int i=0;i<g_ctxCount;i++){g_ctx[i].tradesToday=0;g_ctx[i].sessionProfit=0;g_ctx[i].sessionWins=0;g_ctx[i].sessionLosses=0;} }
   if(thisWeek!=g_weekStart) { g_weekStart=thisWeek; g_risk.weekStartEquity=AccountInfoDouble(ACCOUNT_EQUITY); g_risk.weeklyLimitHit=false; }
}

//=====================================================================
//  STRATEGY HEALTH
//=====================================================================
void InitStrategyHealth() {
   string names[10]={"SMC","MTF","VolBrk","VSA","Pattern","Fib","Ribbon","ZScore","Session","News"};
   for(int i=0;i<10;i++) {
      g_health[i].name=names[i]; g_health[i].totalTrades=0; g_health[i].wins=0; g_health[i].losses=0;
      g_health[i].grossProfit=0; g_health[i].grossLoss=0; g_health[i].sumR=0; g_health[i].sumRSquared=0;
      g_health[i].consecLosses=0; g_health[i].maxConsecLosses=0; g_health[i].winRate=0; g_health[i].profitFactor=0;
      g_health[i].expectancyR=0; g_health[i].sharpeProxy=0; g_health[i].enabled=true; g_health[i].influenceMultiplier=1.0;
   }
}

//=====================================================================
//  ON TRADE TRANSACTION
//=====================================================================
void OnTradeTransactionHandler(const MqlTradeTransaction &trans, const MqlTradeRequest &request, const MqlTradeResult &result) {
   if(trans.type!=TRADE_TRANSACTION_DEAL_ADD) return;
   ulong dealTicket=trans.deal; if(!HistoryDealSelect(dealTicket)) return;
   if((ulong)HistoryDealGetInteger(dealTicket,DEAL_MAGIC)!=InpMagic) return;
   string sym=HistoryDealGetString(dealTicket,DEAL_SYMBOL);
   if(HistoryDealGetInteger(dealTicket,DEAL_ENTRY)!=DEAL_ENTRY_OUT) return;
   double pnl=HistoryDealGetDouble(dealTicket,DEAL_PROFIT)+HistoryDealGetDouble(dealTicket,DEAL_SWAP)+HistoryDealGetDouble(dealTicket,DEAL_COMMISSION);
   string cmt=HistoryDealGetString(dealTicket,DEAL_COMMENT);
   string parts[]; int n=StringSplit(cmt,'|',parts);
   double riskAmt = (n>=3) ? StringToDouble(parts[2]) : 0.0;
   double rMult = (riskAmt>0) ? (pnl/riskAmt) : 0.0;

   // Find symbol context
   for(int i=0;i<g_ctxCount;i++) {
      if(g_ctx[i].symbol==sym) {
         g_ctx[i].sessionProfit+=pnl;
         if(pnl>=0) g_ctx[i].sessionWins++; else g_ctx[i].sessionLosses++;
         g_ctx[i].lastCloseTime=TimeCurrent();
         g_ctx[i].inCooldown=true;
         break;
      }
   }
   PushLog("CLOSE "+sym+" P&L="+DoubleToString(pnl,2)+" R="+DoubleToString(rMult,2));
}

//=====================================================================
//  ═══════════════════════════════════════════════════════════
//  MULTI-SYMBOL DASHBOARD
//  ═══════════════════════════════════════════════════════════
//=====================================================================
void InitDash() {
   int X=InpDashX, Y=InpDashY;
   R("frame", X, Y, DW, DH, C_BG0, C_ACBORD, 2);
   R("inner", X+2, Y+2, DW-4, DH-4, C_BG0, C_BORDER, 1);
   // Title
   R("title", X+2, Y+2, DW-4, 20, C_HDRBAR, C_ACBORD, 1);
   L("title_lbl", X+8, Y+6, "ULTRA ADVANCED INTELLIGENT EA v2.0", C_CYAN, 8, "Arial Black");
   L("title_time", X+DW-90, Y+6, "--:--", C_SUBTEXT, 7);
   // Symbol Table Header
   int yT = Y+22;
   R("sym_hd", X+2, yT, DW-4, 14, C_ORANGE, C_BORDER, 1);
   L("sym_hd_lbl", X+8, tT+2, "SYMBOL  DIR  SCORE  REGIME  CONF  BID/ASK  ACTION", C_BG0, 6, "Arial Black");
   // Symbol rows
   for(int i=0;i<12;i++) L("sym_r"+IntegerToString(i), X+8, yT+18+i*12, "", C_SUBTEXT, 6);
   // Detail panel header
   int yD = yT+18+12*12+4;
   R("det_hd", X+2, yD, DW-4, 14, C_GOLD, C_BORDER, 1);
   L("det_lbl", X+8, yD+2, "STRATEGY BREAKDOWN (active symbol)", C_BG0, 6, "Arial Black");
   // Strategy rows
   for(int i=0;i<9;i++) L("strat_r"+IntegerToString(i), X+8, yD+18+i*12, "", C_SUBTEXT, 6);
   // Decision
   int yDec = yD+18+9*12+4;
   R("dec_hd", X+2, yDec, DW-4, 14, C_ORANGE, C_BORDER, 1);
   L("dec_lbl", X+8, yDec+2, "DECISION", C_BG0, 6, "Arial Black");
   R("dec_body", X+2, yDec+14, DW-4, 22, C_DGRAY, C_GOLD, 2);
   L("dec_text", X+DW/2-30, yDec+19, "HOLD", C_WHITE, 10, "Arial Black");
   // Risk panel
   int yR2 = yDec+36;
   R("risk_hd", X+2, yR2, DW-4, 14, C_DKGREEN, C_GREEN, 1);
   L("risk_lbl", X+8, yR2+2, "RISK & ACCOUNT", C_WHITE, 6, "Arial Black");
   R("risk_body", X+2, yR2+14, DW-4, 40, C_BG2, C_BORDER, 1);
   L("risk_r1", X+8, yR2+18, "", C_WHITE, 6);
   L("risk_r2", X+8, yR2+30, "", C_WHITE, 6);
   L("risk_r3", X+8, yR2+42, "", C_WHITE, 6);
   // Log
   int yL2 = yR2+54;
   R("log_hd", X+2, yL2, DW-4, 14, C_HDRBAR, C_BORDER, 1);
   L("log_lbl", X+8, yL2+2, "EA ACTION LOG", C_GOLD, 6, "Arial Black");
   R("log_body", X+2, yL2+14, DW-4, 80, C_BG2, C_BORDER, 1);
   for(int i=0;i<10;i++) L("log_r"+IntegerToString(i), X+8, yL2+18+i*9, "", C_SUBTEXT, 6);
   // Footer
   R("ftr", X+2, Y+DH-14, DW-4, 12, C_HDRBAR, C_BORDER, 1);
   L("ft", X+8, Y+DH-12, "Server: --:--", C_MGRAY, 6);
   L("ft2", X+DW-100, Y+DH-12, "UAI v2.0", C_MGRAY, 6);
   ChartRedraw(0);
}

void UpdateDash() {
   if(!InpShowDash) return;
   U("title_time", TimeToString(TimeCurrent(), TIME_MINUTES), C_SUBTEXT);

   // Symbol table
   int maxShow = MathMin(g_ctxCount, 12);
   for(int i=0;i<12;i++) {
      if(i>=maxShow) { U("sym_r"+IntegerToString(i), "", C_SUBTEXT); continue; }
      string sym=g_ctx[i].symbol;
      int dir=g_ctx[i].confluenceDir;
      double score=g_ctx[i].confluenceScore;
      string dirStr = (dir==1)?"BUY":(dir==-1)?"SELL":"--";
      color c = (dir==1)?C_GREEN:(dir==-1)?C_RED:C_SUBTEXT;
      double bid=SymbolInfoDouble(sym,SYMBOL_BID), ask=SymbolInfoDouble(sym,SYMBOL_ASK);
      string action = g_ctx[i].lastDecision.tradeApproved ? "EXEC" : (g_ctx[i].lastDecision.narrative!=""?"HOLD":"--");
      string row = StringFormat("%-8s %-4s %5.1f%% %-7s %3.0f%% %.5f %s",
         sym, dirStr, score, RegimeToString(g_ctx[i].regime.regime), g_ctx[i].regime.confidence, bid, action);
      U("sym_r"+IntegerToString(i), row, c);
   }

   // Strategy breakdown for active symbol
   int aIdx = MathMin(g_activeSymbol, MathMax(0, g_ctxCount-1));
   if(g_ctxCount>0) {
      for(int i=0;i<9;i++) {
         StrategySignal sig = g_ctx[aIdx].lastSignals[i];
         string dirStr = (sig.direction==DIR_LONG)?"BULL":(sig.direction==DIR_SHORT)?"BEAR":"--";
         color c = (sig.direction==DIR_LONG)?C_GREEN:(sig.direction==DIR_SHORT)?C_RED:C_SUBTEXT;
         string conf = sig.valid ? DoubleToString(sig.confidence,0)+"%" : "skip";
         string row = StringFormat("%-8s %-5s %5s  %s", StrategyToString((ENUM_STRATEGY)(i+1)), dirStr, conf, sig.reason);
         if(StringLen(row)>90) row = StringSubstr(row,0,90);
         U("strat_r"+IntegerToString(i), row, c);
      }
   }

   // Decision
   bool tradeNow = (g_ctxCount>0) ? g_ctx[aIdx].lastDecision.tradeApproved : false;
   string decText = tradeNow ? (g_ctx[aIdx].lastDecision.direction==DIR_LONG?"BUY ":"SELL ")+g_ctx[aIdx].symbol : "HOLD";
   color decColor = tradeNow ? (g_ctx[aIdx].lastDecision.direction==DIR_LONG?C_GREEN:C_RED) : C_ORANGE;
   U("dec_text", decText, decColor);
   ObjectSetInteger(0, D+"dec_body", OBJPROP_BGCOLOR, tradeNow ? (g_ctx[aIdx].lastDecision.direction==DIR_LONG?C_DKGREEN:C_DKRED) : C_DGRAY);

   // Risk
   double eq=AccountInfoDouble(ACCOUNT_EQUITY), bal=AccountInfoDouble(ACCOUNT_BALANCE);
   double dayPL=eq-g_risk.dayStartEquity;
   U("risk_r1", StringFormat("Bal:$%.2f  Eq:$%.2f  Day:%s%.2f  DD:%.1f%%", bal, eq, (dayPL>=0?"+":""), dayPL, g_risk.currentDrawdownPct),
     (dayPL>=0)?C_GREEN:C_RED);
   int totalTrades=0, totalWins=0;
   for(int i=0;i<g_ctxCount;i++){totalTrades+=g_ctx[i].sessionWins+g_ctx[i].sessionLosses; totalWins+=g_ctx[i].sessionWins;}
   double wr = (totalTrades>0)?(100.0*totalWins/totalTrades):0.0;
   U("risk_r2", StringFormat("Open:%d  WR:%.0f%%  Trades today:%d  MaxDD:%.1f%%", PositionsTotalForMagic(), wr, totalTrades, g_risk.maxDrawdownSeenPct), C_WHITE);
   U("risk_r3", StringFormat("Risk/trade:%.2f%%  MinScore:%.0f%%  MinRR:%.1f  Symbols:%d", InpRiskPercentPerTrade, InpMinConfluenceScore, InpMinRR, g_ctxCount), C_SUBTEXT);

   // Log
   for(int i=0;i<10;i++) U("log_r"+IntegerToString(i), (g_dashLog[i]==""?" ":g_dashLog[i]), C_SUBTEXT);

   U("ft", "Server: "+TimeToString(TimeCurrent(), TIME_MINUTES), C_DGRAY);
}

//=====================================================================
//  CHART THEME
//=====================================================================
void ApplyBlackTheme() {
   if(!InpEnableBlackTheme) return;
   long ch=ChartID();
   ChartSetInteger(ch,CHART_COLOR_BACKGROUND,clrBlack);
   ChartSetInteger(ch,CHART_COLOR_FOREGROUND,C'220,220,220');
   ChartSetInteger(ch,CHART_COLOR_GRID,C'20,20,20');
   ChartSetInteger(ch,CHART_COLOR_CANDLE_BULL,C'24,222,118');
   ChartSetInteger(ch,CHART_COLOR_CANDLE_BEAR,C'234,62,72');
   ChartSetInteger(ch,CHART_SHOW_GRID,false);
   ChartSetInteger(ch,CHART_MODE,CHART_CANDLES);
   ChartRedraw(ch);
}

//=====================================================================
//  ═══════════════════════════════════════════════════════════
//  EA LIFECYCLE
//  ═══════════════════════════════════════════════════════════
//=====================================================================
int OnInit() {
   ApplyBlackTheme();
   BuildSymbolList();
   if(g_ctxCount==0) { Print("No symbols configured!"); return INIT_FAILED; }

   for(int i=0;i<g_ctxCount;i++) {
      if(!InitSymbolContext(i)) { Print("Init failed for ", g_ctx[i].symbol); return INIT_FAILED; }
   }

   g_trade.SetExpertMagicNumber(InpMagic);
   g_dayStart=DayStart(TimeCurrent()); g_weekStart=WeekStart(TimeCurrent());
   InitRiskState(); InitStrategyHealth();
   g_adaptiveRegimeConfThreshold=InpMinRegimeConfidence;
   g_adaptiveExecScoreThreshold=35.0;

   if(InpShowDash) InitDash();
   EventSetTimer(1);
   PushLog("EA initialized with "+IntegerToString(g_ctxCount)+" symbols");
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason) {
   EventKillTimer();
   ObjectsDeleteAll(0, D); ObjectsDeleteAll(0, OV);
   ChartRedraw(0);
   for(int i=0;i<g_ctxCount;i++) {
      IndicatorRelease(g_ctx[i].h_h1emaF); IndicatorRelease(g_ctx[i].h_h1emaS); IndicatorRelease(g_ctx[i].h_h1atr);
      IndicatorRelease(g_ctx[i].h_m15emaF); IndicatorRelease(g_ctx[i].h_m15emaS); IndicatorRelease(g_ctx[i].h_m15atr);
      IndicatorRelease(g_ctx[i].h_m15rsi); IndicatorRelease(g_ctx[i].h_m15macd); IndicatorRelease(g_ctx[i].h_m15bb);
      IndicatorRelease(g_ctx[i].h_m5emaF); IndicatorRelease(g_ctx[i].h_m5emaS); IndicatorRelease(g_ctx[i].h_m5atr);
      IndicatorRelease(g_ctx[i].h_m5rsi); IndicatorRelease(g_ctx[i].h_m5stoch);
      IndicatorRelease(g_ctx[i].h_m1emaF); IndicatorRelease(g_ctx[i].h_m1emaS); IndicatorRelease(g_ctx[i].h_m1atr);
      IndicatorRelease(g_ctx[i].h_ema8); IndicatorRelease(g_ctx[i].h_ema21); IndicatorRelease(g_ctx[i].h_ema50);
      IndicatorRelease(g_ctx[i].h_ema100); IndicatorRelease(g_ctx[i].h_ema200);
   }
}

void OnTimer() {
   // Update cooldowns
   for(int i=0;i<g_ctxCount;i++) {
      if(g_ctx[i].lastCloseTime>0) {
         int elapsed=(int)(TimeCurrent()-g_ctx[i].lastCloseTime);
         g_ctx[i].inCooldown = (elapsed<InpCooldownAfterCloseSec);
      }
   }
   if(InpShowDash) UpdateDash();
}

void OnTick() {
   RolloverDailyWeekly();
   UpdateRiskState();

   // Check buffer readiness
   for(int i=0;i<g_ctxCount;i++) {
      if(Bars(g_ctx[i].symbol,PERIOD_H1)<InpEMASlowPeriod+5 || Bars(g_ctx[i].symbol,PERIOD_M5)<InpATRLookback+5) {
         g_statusText="BUFFERING"; g_statusColor=C_ORANGE; return;
      }
   }

   // === FULL ANALYSIS UPDATE (every 60s or new bar) ===
   datetime now=TimeCurrent();
   bool fullUpdate = (now-g_lastFullUpdate>60);
   if(fullUpdate) g_lastFullUpdate=now;

   for(int i=0;i<g_ctxCount;i++) {
      if(fullUpdate) {
         UpdateMTFBias(i);
         UpdateVolatilityIntelligence(i);
         UpdateNewsShockProxy(i);
         UpdateLiquidityIntelligence(i);
         UpdateSessionIntelligence(i);
         UpdateRegimeClassification(i);
         DetectMarketStructure(i);
         DetectOrderBlocks(i);
         DetectFairValueGaps(i);
      }
      UpdateExecutionQuality(i);

      // Check cooldown
      if(g_ctx[i].lastCloseTime>0) {
         int elapsed=(int)(now-g_ctx[i].lastCloseTime);
         g_ctx[i].inCooldown=(elapsed<InpCooldownAfterCloseSec);
      }

      // Check if already in trade for this symbol
      if(PositionsTotalForMagicSymbol(g_ctx[i].symbol)>0) continue;

      // Build confluence decision
      g_ctx[i].lastDecision = BuildConfluenceDecision(i);

      // Execute
      if(g_ctx[i].lastDecision.tradeApproved) {
         ExecuteDecision(g_ctx[i].lastDecision);
      }
   }

   // Manage open positions
   ManageOpenPositions();

   g_statusText = (PositionsTotalForMagic()>0) ? "IN TRADE" : "ANALYZING";
   g_statusColor = (PositionsTotalForMagic()>0) ? C_GREEN : C_GOLD;
}

void OnTradeTransaction(const MqlTradeTransaction &trans, const MqlTradeRequest &request, const MqlTradeResult &result) {
   OnTradeTransactionHandler(trans, request, result);
}
//+------------------------------------------------------------------+