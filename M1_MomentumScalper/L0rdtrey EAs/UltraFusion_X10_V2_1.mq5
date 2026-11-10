//+------------------------------------------------------------------+
//|                                         ULTRAFUSION X10 v2.0     |
//| Multi-Asset Adaptive Fusion Engine for MetaTrader 5              |
//| Upgrade of BTC Quantum Scalper v1.0                               |
//|                                                                  |
//| Architecture:                                                    |
//| 10 parallel strategy engines -> regime intelligence ->            |
//| cross-asset confirmation -> adaptive fusion -> risk/execution ->  |
//| automatic trade deployment -> live analytics dashboard            |
//+------------------------------------------------------------------+
#property strict
#property version   "2.00"
#property description "UltraFusion X10: 10-engine multi-symbol adaptive trading system for Gold, FX and Index CFDs."

#include <Trade/Trade.mqh>

//=====================================================================
// ENUMERATIONS
//=====================================================================
enum ENUM_UF_DIRECTION
{
   UF_NONE = 0,
   UF_LONG = 1,
   UF_SHORT = -1
};

enum ENUM_UF_REGIME
{
   UF_REGIME_TREND = 0,
   UF_REGIME_RANGE,
   UF_REGIME_BREAKOUT,
   UF_REGIME_COMPRESSION,
   UF_REGIME_EXPANSION,
   UF_REGIME_EXHAUSTION,
   UF_REGIME_SHOCK,
   UF_REGIME_UNSAFE
};

enum ENUM_UF_STRATEGY
{
   UF_TREND_CONTINUATION = 0,
   UF_PULLBACK_MOMENTUM,
   UF_STRUCTURE_BOS_CHoCH,
   UF_LIQUIDITY_SWEEP,
   UF_FVG_ORDERBLOCK,
   UF_VOLATILITY_BREAKOUT,
   UF_MEAN_REVERSION,
   UF_SESSION_ORB,
   UF_VWAP_VALUE,
   UF_INTERMARKET,
   UF_STRATEGY_COUNT
};

enum ENUM_UF_NEWS
{
   UF_NEWS_NORMAL = 0,
   UF_NEWS_CAUTION,
   UF_NEWS_BLOCK
};

enum ENUM_UF_EXECUTION_MODE
{
   UF_EXEC_FUSED_QUALIFIED = 0,
   UF_EXEC_ANY_VALID_ENGINE = 1
};

//=====================================================================
// INPUTS
//=====================================================================
input group "===== ENGINE IDENTITY ====="
input ulong  InpMagicNumber              = 88111010;
input string InpBotName                  = "ULTRAFUSION X10";
input string InpSymbols                  = "XAUUSD,EURUSD,GBPUSD,USDJPY,USDCHF,AUDUSD,USDCAD,NZDUSD,US500,NAS100,GER40,UK100";
input string InpFocusSymbol              = "";
input bool   InpAutoSelectSymbols        = true;

input group "===== 10-ENGINE FUSION ====="
input bool   InpEnableStrategy1          = true;
input bool   InpEnableStrategy2          = true;
input bool   InpEnableStrategy3          = true;
input bool   InpEnableStrategy4          = true;
input bool   InpEnableStrategy5          = true;
input bool   InpEnableStrategy6          = true;
input bool   InpEnableStrategy7          = true;
input bool   InpEnableStrategy8          = true;
input bool   InpEnableStrategy9          = true;
input bool   InpEnableStrategy10         = true;
input double InpMinFusionScore           = 72.0;
input double InpStrongFusionScore        = 84.0;
input int    InpMinEngineAgreement       = 3;
input double InpMinDirectionalEdge       = 18.0;
input ENUM_UF_EXECUTION_MODE InpExecutionMode = UF_EXEC_FUSED_QUALIFIED;
input bool   InpAutoTradeQualified       = true;

input group "===== RISK GOVERNANCE ====="
input double InpRiskPercent              = 0.35;
input double InpMaxRiskPercentTrade     = 0.80;
input double InpMaxPortfolioRiskPct      = 2.50;
input double InpMaxDailyDrawdownPct      = 5.0;
input double InpMaxWeeklyDrawdownPct     = 10.0;
input double InpMaxAccountDrawdownPct    = 15.0;
input int    InpMaxPositions             = 6;
input int    InpMaxDailyTrades            = 80;
input bool   InpOnePositionPerSymbol     = true;
input bool   InpAllowOppositeHedges      = false;
input double InpMinRR                    = 1.50;
input double InpTargetRR                 = 2.20;
input double InpMaxRR                    = 4.00;
input bool   InpUseConfidenceRiskScale   = true;

input group "===== VOLATILITY / STOPS ====="
input int    InpATRPeriod                = 14;
input int    InpATRLookback              = 100;
input double InpSL_ATR_Mult              = 1.60;
input double InpTP_ATR_Mult              = 2.80;
input double InpBreakEvenR               = 1.00;
input double InpBreakEvenOffsetATR       = 0.08;
input double InpTrailStartR              = 1.40;
input double InpTrailATRMult             = 1.15;
input int    InpMaxHoldMinutes           = 360;
input bool   InpUsePartialAtR            = true;
input double InpPartialCloseR            = 1.60;
input double InpPartialCloseFraction     = 0.50;

input group "===== EXECUTION QUALITY ====="
input double InpMaxSpreadPoints          = 250.0;
input double InpMinExecutionScore        = 62.0;
input int    InpDeviationPoints          = 30;
input int    InpCooldownSeconds          = 10;
input double InpMaxATRShockRatio         = 3.50;
input bool   InpBlockExtremeSpread       = true;

input group "===== NEWS / MACRO ====="
input bool   InpUseEconomicCalendar      = true;
input string InpNewsCurrencies           = "USD,EUR,GBP,JPY,CHF,AUD,CAD,NZD";
input int    InpNewsBlockBeforeMin       = 15;
input int    InpNewsBlockAfterMin        = 10;
input int    InpNewsCautionBeforeMin     = 45;
input int    InpNewsCacheSeconds         = 15;

input group "===== INDICATOR PARAMETERS ====="
input int    InpEMA20                    = 20;
input int    InpEMA50                    = 50;
input int    InpEMA200                   = 200;
input int    InpADXPeriod                 = 14;
input int    InpRSIPeriod                 = 14;
input int    InpMACDFast                 = 12;
input int    InpMACDSlow                 = 26;
input int    InpMACDSignal               = 9;
input int    InpBandsPeriod               = 20;
input double InpBandsDeviation            = 2.0;
input int    InpStochK                    = 14;
input int    InpStochD                    = 3;
input int    InpStochSlowing              = 3;
input int    InpDonchianLookback          = 20;
input int    InpStructureLookback         = 60;
input int    InpSessionOpeningMinutes     = 60;
input int    InpVWAPLookbackBars          = 288;

input group "===== INTERMARKET PROXIES ====="
input string InpDXYSymbol                 = "DXY";
input string InpUS500Symbol               = "US500";
input string InpNAS100Symbol              = "NAS100";
input string InpUS10YSymbol               = "US10Y";
input int    InpIntermarketBars            = 48;
input double InpIntermarketMinScore       = 55.0;

input group "===== CORRELATION / PORTFOLIO INTELLIGENCE ====="
input bool   InpUseCorrelationGate        = true;
input double InpCorrelationThreshold      = 0.80;
input double InpSameDirectionCorrPenalty  = 20.0;
input double InpOppositeDirectionCorrPenalty = 8.0;
input int    InpCorrelationBars           = 40;

input group "===== ADAPTIVE HEALTH ====="
input bool   InpUseAdaptiveWeights        = true;
input int    InpHealthMinTrades           = 12;
input int    InpHealthDegradeLossStreak   = 5;
input double InpHealthMinExpectancyR      = -0.20;
input double InpHealthWeightFloor         = 0.55;
input double InpHealthWeightCeiling       = 1.35;

input group "===== DASHBOARD ====="
input bool   InpShowDashboard             = true;
input int    InpDashX                     = 8;
input int    InpDashY                     = 8;
input int    InpDashWidth                 = 1180;
input int    InpDashHeight                = 690;
input int    InpDashRefreshMs             = 500;
input bool   InpBlackTheme                = true;
input bool   InpShowEngineReasons         = true;
input int    InpReasonChars               = 62;
input bool   InpShowChartLevels            = true;

input group "===== LOGGING ====="
input bool   InpVerboseLog                = true;
input bool   InpWriteCSVLog               = true;

//=====================================================================
// CONSTANTS / STYLE
//=====================================================================
#define UF_DASH "UF10_D_"
#define UF_OV   "UF10_OV_"
#define UF_MAX_SYMBOLS 24
#define UF_MAX_LOG 14
#define UF_MAX_LEVELS 12

color UF_BG       = C'6,9,18';
color UF_PANEL    = C'10,15,28';
color UF_PANEL2   = C'14,20,38';
color UF_BORDER   = C'32,55,94';
color UF_CYAN     = C'52,211,235';
color UF_GOLD     = C'255,202,60';
color UF_GREEN    = C'46,220,130';
color UF_RED      = C'239,83,96';
color UF_ORANGE   = C'255,159,67';
color UF_PURPLE   = C'185,118,255';
color UF_WHITE    = C'229,235,248';
color UF_MUTED    = C'132,148,175';
color UF_BLUE     = C'91,154,255';

//=====================================================================
// DATA STRUCTURES
//=====================================================================
struct UFSignal
{
   ENUM_UF_STRATEGY strategy;
   ENUM_UF_DIRECTION direction;
   bool valid;
   double score;
   double entry;
   double sl;
   double tp;
   double weight;
   string reason;
};

struct UFHealth
{
   int trades;
   int wins;
   int losses;
   int lossStreak;
   int maxLossStreak;
   double sumR;
   double sumR2;
   double grossProfit;
   double grossLoss;
   double winRate;
   double profitFactor;
   double expectancyR;
   double weight;
   bool enabled;
};

struct UFContext
{
   string symbol;
   bool enabled;
   bool initialized;
   datetime lastM5Bar;
   datetime lastM1Bar;
   datetime lastScan;
   ENUM_UF_REGIME regime;
   ENUM_UF_NEWS news;
   double regimeScore;
   double atr;
   double atrAvg;
   double atrRatio;
   double spreadPoints;
   double vwap;
   double prevDayHigh;
   double prevDayLow;
   double dayHigh;
   double dayLow;
   double sessionHigh;
   double sessionLow;
   double fusionScore;
   ENUM_UF_DIRECTION fusionDirection;
   double fusionEntry;
   double fusionSL;
   double fusionTP;
   double fusionRR;
   int longVotes;
   int shortVotes;
   int validVotes;
   string fusionReason;
   string action;
   UFSignal signals[UF_STRATEGY_COUNT];
   int hEma20M1;
   int hEma20M5;
   int hEma50M5;
   int hEma200H1;
   int hEma50H1;
   int hATR_M5;
   int hATR_M15;
   int hADX_M5;
   int hRSI_M5;
   int hRSI_M1;
   int hMACD_M5;
   int hBands_M5;
   int hStoch_M5;
   int hADX_M15;
};

struct UFDecision
{
   bool approved;
   string symbol;
   ENUM_UF_DIRECTION direction;
   ENUM_UF_STRATEGY source;
   double score;
   double entry;
   double sl;
   double tp;
   double rr;
   double riskPct;
   double riskMoney;
   double lots;
   string reason;
};

//=====================================================================
// GLOBAL STATE
//=====================================================================
CTrade g_trade;
UFContext g_ctx[UF_MAX_SYMBOLS];
UFHealth g_health[UF_STRATEGY_COUNT];
int g_symbolCount = 0;
int g_focusIndex = 0;
datetime g_dayStart = 0;
datetime g_weekStart = 0;
double g_peakEquity = 0;
double g_dayStartEquity = 0;
double g_weekStartEquity = 0;
bool g_emergency = false;
datetime g_lastTradeClose = 0;
datetime g_lastNewsScan = 0;
ENUM_UF_NEWS g_globalNews = UF_NEWS_NORMAL;
string g_newsReason = "No high-impact event in configured window";
UFDecision g_lastDecision;
string g_actionLog[UF_MAX_LOG];
datetime g_actionTime[UF_MAX_LOG];
int g_actionCount = 0;
int g_totalCandidates = 0;
int g_totalExecuted = 0;
int g_totalBlocked = 0;
int g_totalOrdersFailed = 0;
int g_dayTrades = 0;
int g_sessionWins = 0;
int g_sessionLosses = 0;
double g_sessionProfit = 0;
ulong g_partialTickets[128];
int g_partialCount=0;

bool WasPartial(ulong ticket)
{
   for(int i=0;i<g_partialCount;i++) if(g_partialTickets[i]==ticket) return true;
   return false;
}

void MarkPartial(ulong ticket)
{
   if(WasPartial(ticket) || g_partialCount>=ArraySize(g_partialTickets)) return;
   g_partialTickets[g_partialCount++]=ticket;
}
ulong g_calendarChangeId = 0;

//=====================================================================
// GENERAL HELPERS
//=====================================================================
string TrimStr(string s)
{
   StringTrimLeft(s);
   StringTrimRight(s);
   return s;
}

string Shorten(string s, int maxChars)
{
   if(maxChars <= 3 || StringLen(s) <= maxChars) return s;
   return StringSubstr(s,0,maxChars-3) + "...";
}

string DirStr(ENUM_UF_DIRECTION d)
{
   if(d==UF_LONG) return "BUY";
   if(d==UF_SHORT) return "SELL";
   return "WAIT";
}

string RegimeStr(ENUM_UF_REGIME r)
{
   switch(r)
   {
      case UF_REGIME_TREND:       return "TREND";
      case UF_REGIME_RANGE:       return "RANGE";
      case UF_REGIME_BREAKOUT:    return "BREAKOUT";
      case UF_REGIME_COMPRESSION: return "COMPRESSION";
      case UF_REGIME_EXPANSION:   return "EXPANSION";
      case UF_REGIME_EXHAUSTION:  return "EXHAUSTION";
      case UF_REGIME_SHOCK:       return "SHOCK";
      default:                    return "UNSAFE";
   }
}

string StrategyStr(ENUM_UF_STRATEGY s)
{
   switch(s)
   {
      case UF_TREND_CONTINUATION: return "01 Trend Continuation";
      case UF_PULLBACK_MOMENTUM:  return "02 Pullback Momentum";
      case UF_STRUCTURE_BOS_CHoCH:return "03 BOS / CHoCH";
      case UF_LIQUIDITY_SWEEP:    return "04 Liquidity Sweep";
      case UF_FVG_ORDERBLOCK:     return "05 FVG + Order Block";
      case UF_VOLATILITY_BREAKOUT:return "06 Volatility Breakout";
      case UF_MEAN_REVERSION:     return "07 Mean Reversion";
      case UF_SESSION_ORB:        return "08 Session ORB";
      case UF_VWAP_VALUE:         return "09 VWAP Value";
      case UF_INTERMARKET:        return "10 Intermarket";
      default:                    return "Unknown";
   }
}

bool StrategyEnabled(ENUM_UF_STRATEGY s)
{
   switch(s)
   {
      case UF_TREND_CONTINUATION: return InpEnableStrategy1;
      case UF_PULLBACK_MOMENTUM:  return InpEnableStrategy2;
      case UF_STRUCTURE_BOS_CHoCH:return InpEnableStrategy3;
      case UF_LIQUIDITY_SWEEP:    return InpEnableStrategy4;
      case UF_FVG_ORDERBLOCK:     return InpEnableStrategy5;
      case UF_VOLATILITY_BREAKOUT:return InpEnableStrategy6;
      case UF_MEAN_REVERSION:     return InpEnableStrategy7;
      case UF_SESSION_ORB:        return InpEnableStrategy8;
      case UF_VWAP_VALUE:         return InpEnableStrategy9;
      case UF_INTERMARKET:        return InpEnableStrategy10;
      default: return false;
   }
}

void WriteJournal(string eventType,string message)
{
   if(!InpWriteCSVLog) return;
   int h=FileOpen("UltraFusion_X10_Journal.csv",FILE_CSV|FILE_READ|FILE_WRITE|FILE_SHARE_READ|FILE_SHARE_WRITE|FILE_COMMON,';');
   if(h==INVALID_HANDLE) return;
   FileSeek(h,0,SEEK_END);
   FileWrite(h,TimeToString(TimeTradeServer(),TIME_DATE|TIME_SECONDS),eventType,message);
   FileClose(h);
}

void LogAction(string msg)
{
   string line = TimeToString(TimeCurrent(),TIME_SECONDS) + " | " + msg;
   for(int i=UF_MAX_LOG-1; i>0; i--)
   {
      g_actionLog[i] = g_actionLog[i-1];
      g_actionTime[i] = g_actionTime[i-1];
   }
   g_actionLog[0] = line;
   g_actionTime[0] = TimeCurrent();
   if(g_actionCount < UF_MAX_LOG) g_actionCount++;
   if(InpVerboseLog) Print("[UF10] ",msg);
   WriteJournal("ACTION",msg);
}

void ResetSignal(UFSignal &s, ENUM_UF_STRATEGY strategy)
{
   s.strategy = strategy;
   s.direction = UF_NONE;
   s.valid = false;
   s.score = 0;
   s.entry = 0;
   s.sl = 0;
   s.tp = 0;
   s.weight = 1;
   s.reason = "No setup";
}

int FocusIndex()
{
   if(InpFocusSymbol!="")
   {
      for(int i=0;i<g_symbolCount;i++)
         if(g_ctx[i].symbol==InpFocusSymbol) return i;
   }
   int chart=0;
   for(int i=0;i<g_symbolCount;i++)
      if(g_ctx[i].symbol==_Symbol) { chart=i; break; }
   return chart;
}

int SymbolDigits(string symbol)
{
   return (int)SymbolInfoInteger(symbol,SYMBOL_DIGITS);
}

double NormalizePrice(string symbol, double p)
{
   return NormalizeDouble(p,SymbolDigits(symbol));
}

double PointValue(string symbol)
{
   double p=SymbolInfoDouble(symbol,SYMBOL_POINT);
   return (p>0 ? p : 0.00001);
}

double TickDistanceToPoints(string symbol,double priceDist)
{
   double p=PointValue(symbol);
   return (p>0 ? priceDist/p : 0);
}

bool GetTick(string symbol,MqlTick &tick)
{
   return SymbolInfoTick(symbol,tick);
}

bool CopyValue(int handle,int buffer,int shift,double &value)
{
   value=0;
   if(handle==INVALID_HANDLE) return false;
   double a[1];
   if(CopyBuffer(handle,buffer,shift,1,a)!=1) return false;
   value=a[0];
   return true;
}

double Close(string symbol, ENUM_TIMEFRAMES tf,int shift)
{
   return iClose(symbol,tf,shift);
}

double High(string symbol, ENUM_TIMEFRAMES tf,int shift)
{
   return iHigh(symbol,tf,shift);
}

double Low(string symbol, ENUM_TIMEFRAMES tf,int shift)
{
   return iLow(symbol,tf,shift);
}

double Open(string symbol, ENUM_TIMEFRAMES tf,int shift)
{
   return iOpen(symbol,tf,shift);
}
long Vol(string symbol, ENUM_TIMEFRAMES tf,int shift)
{
   return (long)iVolume(symbol,tf,shift);
}

int BarsCount(string symbol,ENUM_TIMEFRAMES tf)
{
   return Bars(symbol,tf);
}

bool IsNewBarForContext(UFContext &c)
{
   datetime t=iTime(c.symbol,PERIOD_M5,0);
   if(t<=0) return false;
   if(c.lastM5Bar!=t)
   {
      c.lastM5Bar=t;
      return true;
   }
   return false;
}

//=====================================================================
// SYMBOL / CATEGORY HELPERS
//=====================================================================
string Upper(string value)
{
   StringToUpper(value);
   return value;
}

bool ContainsAny(string text,string a,string b="",string c="",string d="")
{
   if(a!="" && StringFind(text,a)>=0) return true;
   if(b!="" && StringFind(text,b)>=0) return true;
   if(c!="" && StringFind(text,c)>=0) return true;
   if(d!="" && StringFind(text,d)>=0) return true;
   return false;
}

bool IsGoldSymbol(string symbol)
{
   string s=symbol; StringToUpper(s);
   return ContainsAny(s,"XAU","GOLD","XAG");
}

bool IsIndexSymbol(string symbol)
{
   string s=symbol; StringToUpper(s);
   return ContainsAny(s,"US500","SPX","SP500","NAS100") ||
          ContainsAny(s,"USTEC","NDX","US30","DJI") ||
          ContainsAny(s,"GER40","DAX","UK100","FTSE") ||
          ContainsAny(s,"FRA40","CAC");
}

string BaseCurrencyGuess(string symbol)
{
   string s=symbol; StringToUpper(s);
   if(IsGoldSymbol(s) || IsIndexSymbol(s) || StringFind(s,"BTC")>=0) return "USD";
   // Handle suffix/prefix broker naming by finding a known six-character FX core.
   string cur[8]={"EUR","GBP","USD","JPY","CHF","AUD","CAD","NZD"};
   for(int i=0;i<8;i++)
   {
      for(int j=0;j<8;j++)
      {
         if(i==j) continue;
         string pair=cur[i]+cur[j];
         if(StringFind(s,pair)>=0) return cur[i];
      }
   }
   return "USD";
}

string QuoteCurrencyGuess(string symbol)
{
   string s=symbol; StringToUpper(s);
   if(IsGoldSymbol(s) || IsIndexSymbol(s) || StringFind(s,"BTC")>=0) return "USD";
   string cur[8]={"EUR","GBP","USD","JPY","CHF","AUD","CAD","NZD"};
   for(int i=0;i<8;i++)
   {
      for(int j=0;j<8;j++)
      {
         if(i==j) continue;
         string pair=cur[i]+cur[j];
         if(StringFind(s,pair)>=0) return cur[j];
      }
   }
   return "USD";
}

bool EnsureSymbol(string symbol)
{
   if(SymbolInfoInteger(symbol,SYMBOL_EXIST)==0) return false;
   if(InpAutoSelectSymbols && !SymbolInfoInteger(symbol,SYMBOL_SELECT))
      SymbolSelect(symbol,true);
   return (SymbolInfoInteger(symbol,SYMBOL_SELECT)!=0);
}

//=====================================================================
// TIME / SESSION
//=====================================================================
int HourOf(datetime t)
{
   MqlDateTime d; TimeToStruct(t,d); return d.hour;
}

datetime DayStart(datetime t)
{
   MqlDateTime d; TimeToStruct(t,d);
   d.hour=0; d.min=0; d.sec=0;
   return StructToTime(d);
}

datetime WeekStart(datetime t)
{
   datetime ds=DayStart(t);
   MqlDateTime d; TimeToStruct(t,d);
   int days=(d.day_of_week==0 ? 6 : d.day_of_week-1);
   return ds-(datetime)days*86400;
}

int SessionBucket(datetime t)
{
   int h=HourOf(t);
   if(h>=0 && h<7) return 0;      // Asia
   if(h<12) return 1;             // London
   if(h<16) return 2;             // NY open overlap
   if(h<21) return 3;             // NY PM
   return 4;                       // dead zone
}

string SessionName(datetime t)
{
   int b=SessionBucket(t);
   if(b==0) return "ASIA";
   if(b==1) return "LONDON";
   if(b==2) return "NY OPEN";
   if(b==3) return "NY PM";
   return "DEAD";
}

double SessionQuality(datetime t)
{
   int b=SessionBucket(t);
   if(b==1) return 92;
   if(b==2) return 96;
   if(b==3) return 78;
   if(b==0) return 58;
   return 32;
}

//=====================================================================
// NEWS ENGINE
//=====================================================================
void UpdateGlobalNews()
{
   if(!InpUseEconomicCalendar)
   {
      g_globalNews=UF_NEWS_NORMAL;
      g_newsReason="Calendar disabled";
      return;
   }
   if(g_lastNewsScan>0 && (TimeTradeServer()-g_lastNewsScan)<InpNewsCacheSeconds) return;
   g_lastNewsScan=TimeTradeServer();
   g_globalNews=UF_NEWS_NORMAL;
   g_newsReason="No high-impact event in configured window";

   string parts[];
   ushort sep=(ushort)StringGetCharacter(",",0);
   int n=StringSplit(InpNewsCurrencies,sep,parts);
   if(n<=0) return;
   datetime now=TimeTradeServer();

   for(int p=0;p<n;p++)
   {
      string cur=TrimStr(parts[p]);
      if(cur=="") continue;
      datetime from=now-InpNewsBlockAfterMin*60-60;
      datetime to=now+InpNewsCautionBeforeMin*60+60;
      MqlCalendarValue vals[];
      int got=CalendarValueHistory(vals,from,to,"",cur);
      if(got<0) continue;
      for(int i=0;i<got;i++)
      {
         MqlCalendarEvent ev;
         if(!CalendarEventById(vals[i].event_id,ev)) continue;
         if(ev.importance!=CALENDAR_IMPORTANCE_HIGH) continue;
         long delta=(long)(vals[i].time-now);
         if(delta>=-InpNewsBlockAfterMin*60 && delta<=InpNewsBlockBeforeMin*60)
         {
            g_globalNews=UF_NEWS_BLOCK;
            g_newsReason=cur+" HIGH: "+ev.name;
            return;
         }
         if(MathAbs((double)delta)<=InpNewsCautionBeforeMin*60)
         {
            g_globalNews=UF_NEWS_CAUTION;
            g_newsReason=cur+" HIGH near: "+ev.name;
         }
      }
   }
}

ENUM_UF_NEWS ContextNews(string symbol)
{
   string base=BaseCurrencyGuess(symbol);
   string quote=QuoteCurrencyGuess(symbol);
   // Global scan covers all configured currencies. Individual context is simply
   // blocked/cautioned when the symbol's own currency is the event currency.
   if(g_globalNews==UF_NEWS_NORMAL) return UF_NEWS_NORMAL;
   if(StringFind(InpNewsCurrencies,base)>=0 || StringFind(InpNewsCurrencies,quote)>=0)
      return g_globalNews;
   return UF_NEWS_NORMAL;
}

//=====================================================================
// INDICATOR / MARKET STATE
//=====================================================================
void UpdateVolatility(UFContext &c)
{
   double atr=0;
   if(!CopyValue(c.hATR_M5,0,1,atr) || atr<=0) atr=PointValue(c.symbol)*100;
   c.atr=atr;
   double sum=0; int n=0;
   for(int i=1;i<=InpATRLookback;i++)
   {
      double v=0;
      if(CopyValue(c.hATR_M5,0,i,v) && v>0) {sum+=v;n++;}
   }
   c.atrAvg=(n>0?sum/n:atr);
   c.atrRatio=(c.atrAvg>0?c.atr/c.atrAvg:1.0);
   c.spreadPoints=(double)SymbolInfoInteger(c.symbol,SYMBOL_SPREAD);
}

double BollingerWidth(UFContext &c,int shift)
{
   double up=0,lo=0;
   if(!CopyValue(c.hBands_M5,1,shift,up)) return 0;
   if(!CopyValue(c.hBands_M5,2,shift,lo)) return 0;
   double mid=0; CopyValue(c.hBands_M5,0,shift,mid);
   if(mid<=0) mid=(up+lo)/2.0;
   return MathAbs(up-lo)/(mid>0?mid:1.0);
}

void UpdateDailyLevels(UFContext &c)
{
   c.prevDayHigh=iHigh(c.symbol,PERIOD_D1,1);
   c.prevDayLow=iLow(c.symbol,PERIOD_D1,1);
   c.dayHigh=iHigh(c.symbol,PERIOD_D1,0);
   c.dayLow=iLow(c.symbol,PERIOD_D1,0);
}

double CalculateVWAP(UFContext &c)
{
   datetime ds=DayStart(TimeTradeServer());
   int start=iBarShift(c.symbol,PERIOD_M5,ds,false);
   if(start<1) start=InpVWAPLookbackBars;
   start=MathMin(start,InpVWAPLookbackBars);
   double pv=0, vv=0;
   for(int i=0;i<=start;i++)
   {
      double h=High(c.symbol,PERIOD_M5,i);
      double l=Low(c.symbol,PERIOD_M5,i);
      double cl=Close(c.symbol,PERIOD_M5,i);
      long v=Vol(c.symbol,PERIOD_M5,i);
      double vol=(v>0?(double)v:1.0);
      if(h<=0 || l<=0 || cl<=0) continue;
      pv=((h+l+cl)/3.0)*vol + pv;
      vv+=vol;
   }
   return (vv>0?pv/vv:Close(c.symbol,PERIOD_M5,0));
}

void SessionRange(UFContext &c)
{
   datetime now=TimeTradeServer();
   int sess=SessionBucket(now);
   int startHour=(sess==0?0:(sess==1?7:(sess==2?12:(sess==3?16:21))));
   MqlDateTime d; TimeToStruct(now,d);
   d.hour=startHour; d.min=0; d.sec=0;
   datetime start=StructToTime(d);
   if(start>now) start-=86400;
   int bars=iBarShift(c.symbol,PERIOD_M5,start,false);
   if(bars<1) bars=24;
   bars=MathMin(bars,180);
   double hi=-DBL_MAX,lo=DBL_MAX;
   for(int i=0;i<=bars;i++)
   {
      hi=MathMax(hi,High(c.symbol,PERIOD_M5,i));
      lo=MathMin(lo,Low(c.symbol,PERIOD_M5,i));
   }
   c.sessionHigh=hi; c.sessionLow=lo;
}

void DetectRegime(UFContext &c)
{
   double ema50H1=0, ema200H1=0, adx=0, rsi=50;
   CopyValue(c.hEma50H1,0,1,ema50H1);
   CopyValue(c.hEma200H1,0,1,ema200H1);
   CopyValue(c.hADX_M5,0,1,adx);
   CopyValue(c.hRSI_M5,0,1,rsi);

   double px=Close(c.symbol,PERIOD_M5,1);
   double priorHi=HighestHigh(c.symbol,InpDonchianLookback,2);
   double priorLo=LowestLow(c.symbol,InpDonchianLookback,2);
   double bw=BollingerWidth(c,1);

   if(px<=0 || c.atr<=0 || c.spreadPoints>InpMaxSpreadPoints*1.8)
   {
      c.regime=UF_REGIME_UNSAFE; c.regimeScore=10; return;
   }
   if(c.news==UF_NEWS_BLOCK && InpBlockExtremeSpread)
   {
      // News block remains a safety gate; regime still describes price action.
      c.regime=UF_REGIME_SHOCK; c.regimeScore=95; return;
   }
   if(c.atrRatio>=InpMaxATRShockRatio)
   {
      c.regime=UF_REGIME_SHOCK; c.regimeScore=90; return;
   }
   if(c.atrRatio<0.72 && bw>0 && bw<0.008)
   {
      c.regime=UF_REGIME_COMPRESSION; c.regimeScore=MathMin(95.0,70.0+(0.72-c.atrRatio)*80.0); return;
   }
   if(px>priorHi || px<priorLo)
   {
      c.regime=UF_REGIME_BREAKOUT; c.regimeScore=MathMin(97.0,76.0+c.atrRatio*12.0); return;
   }
   if(c.atrRatio>1.30)
   {
      c.regime=UF_REGIME_EXPANSION; c.regimeScore=MathMin(95.0,68.0+c.atrRatio*15.0); return;
   }
   if(adx>=22 && MathAbs(ema50H1-ema200H1)>c.atr*0.30)
   {
      c.regime=UF_REGIME_TREND; c.regimeScore=MathMin(96.0,60.0+adx*1.1); return;
   }
   if((rsi>68 || rsi<32) && adx<20)
   {
      c.regime=UF_REGIME_EXHAUSTION; c.regimeScore=72; return;
   }
   c.regime=UF_REGIME_RANGE; c.regimeScore=MathMin(88.0,55.0+(22.0-MathMin(22.0,adx))*1.3);
}

double HighestHigh(string symbol,int lookback,int startShift=1)
{
   int idx=iHighest(symbol,PERIOD_M5,MODE_HIGH,lookback,startShift);
   if(idx<0) return 0;
   return iHigh(symbol,PERIOD_M5,idx);
}

double LowestLow(string symbol,int lookback,int startShift=1)
{
   int idx=iLowest(symbol,PERIOD_M5,MODE_LOW,lookback,startShift);
   if(idx<0) return 0;
   return iLow(symbol,PERIOD_M5,idx);
}

bool RecentBullImpulse(string symbol,int shift)
{
   double o=Open(symbol,PERIOD_M5,shift), c=Close(symbol,PERIOD_M5,shift);
   double h=High(symbol,PERIOD_M5,shift), l=Low(symbol,PERIOD_M5,shift);
   double r=h-l; if(r<=0) return false;
   return c>o && (c-o)/r>=0.60;
}

bool RecentBearImpulse(string symbol,int shift)
{
   double o=Open(symbol,PERIOD_M5,shift), c=Close(symbol,PERIOD_M5,shift);
   double h=High(symbol,PERIOD_M5,shift), l=Low(symbol,PERIOD_M5,shift);
   double r=h-l; if(r<=0) return false;
   return o>c && (o-c)/r>=0.60;
}

void UpdateState(UFContext &c)
{
   UpdateVolatility(c);
   c.news=ContextNews(c.symbol);
   UpdateDailyLevels(c);
   c.vwap=CalculateVWAP(c);
   SessionRange(c);
   DetectRegime(c);
}

//=====================================================================
// ENGINE #1 - TREND CONTINUATION
//=====================================================================
UFSignal EngineTrend(UFContext &c)
{
   UFSignal s; ResetSignal(s,UF_TREND_CONTINUATION);
   double e20m5=0,e50m5=0,e50h1=0,e200h1=0,adx=0;
   CopyValue(c.hEma20M5,0,1,e20m5); CopyValue(c.hEma50M5,0,1,e50m5);
   CopyValue(c.hEma50H1,0,1,e50h1); CopyValue(c.hEma200H1,0,1,e200h1);
   CopyValue(c.hADX_M5,0,1,adx);
   double px=Close(c.symbol,PERIOD_M5,1);
   int dir=(e50h1>e200h1 && e20m5>e50m5 && px>e20m5)?1:(e50h1<e200h1 && e20m5<e50m5 && px<e20m5)?-1:0;
   if(dir==0 || adx<20)
   {
      s.reason="Trend stack incomplete"; return s;
   }
   double pullback=MathAbs(px-e20m5)/c.atr;
   if(pullback>1.15)
   {
      s.reason="Price too extended from fast EMA"; return s;
   }
   s.valid=true; s.direction=(dir>0?UF_LONG:UF_SHORT); s.entry=(dir>0?SymbolInfoDouble(c.symbol,SYMBOL_ASK):SymbolInfoDouble(c.symbol,SYMBOL_BID));
   s.sl=(dir>0?px-c.atr*InpSL_ATR_Mult:px+c.atr*InpSL_ATR_Mult);
   s.tp=(dir>0?s.entry+c.atr*InpTP_ATR_Mult:s.entry-c.atr*InpTP_ATR_Mult);
   s.score=MathMin(96.0,58.0+adx*1.2+(pullback<0.6?10:0));
   s.reason="H1/M5 trend stack + ADX="+DoubleToString(adx,1);
   s.weight=1.15;
   return s;
}

//=====================================================================
// ENGINE #2 - PULLBACK MOMENTUM
//=====================================================================
UFSignal EnginePullback(UFContext &c)
{
   UFSignal s; ResetSignal(s,UF_PULLBACK_MOMENTUM);
   double e20=0,e50=0,rsi=50,macd=0,sig=0;
   CopyValue(c.hEma20M5,0,1,e20); CopyValue(c.hEma50M5,0,1,e50);
   CopyValue(c.hRSI_M5,0,1,rsi); CopyValue(c.hMACD_M5,0,1,macd); CopyValue(c.hMACD_M5,1,1,sig);
   double rsiPrev=50; CopyValue(c.hRSI_M5,0,2,rsiPrev);
   int dir=(e20>e50 && rsi>50 && rsi>rsiPrev && macd>sig)?1:(e20<e50 && rsi<50 && rsi<rsiPrev && macd<sig)?-1:0;
   if(dir==0)
   {
      s.reason="Momentum pullback not confirmed"; return s;
   }
   double px=Close(c.symbol,PERIOD_M5,1);
   double dist=MathAbs(px-e20)/c.atr;
   if(dist>1.3)
   {
      s.reason="No controlled pullback"; return s;
   }
   s.valid=true; s.direction=(dir>0?UF_LONG:UF_SHORT); s.entry=(dir>0?SymbolInfoDouble(c.symbol,SYMBOL_ASK):SymbolInfoDouble(c.symbol,SYMBOL_BID));
   s.sl=(dir>0?MathMin(e50,px-c.atr):MathMax(e50,px+c.atr));
   s.tp=(dir>0?s.entry+c.atr*2.5:s.entry-c.atr*2.5);
   s.score=MathMin(94.0,60.0+MathAbs(rsi-50)*0.9+(MathAbs(macd-sig)/(c.atr>0?c.atr:1))*20.0);
   s.reason="EMA pullback + RSI slope + MACD alignment";
   s.weight=1.10;
   return s;
}

//=====================================================================
// ENGINE #3 - MARKET STRUCTURE BOS / CHoCH
//=====================================================================
UFSignal EngineStructure(UFContext &c)
{
   UFSignal s; ResetSignal(s,UF_STRUCTURE_BOS_CHoCH);
   double hi=HighestHigh(c.symbol,InpStructureLookback,3);
   double lo=LowestLow(c.symbol,InpStructureLookback,3);
   double close1=Close(c.symbol,PERIOD_M5,1);
   double atr=c.atr;
   bool bosUp=close1>hi && RecentBullImpulse(c.symbol,1);
   bool bosDn=close1<lo && RecentBearImpulse(c.symbol,1);
   double c2=Close(c.symbol,PERIOD_M5,2);
   bool chochUp=close1>HighestHigh(c.symbol,20,4) && c2<HighestHigh(c.symbol,20,4);
   bool chochDn=close1<LowestLow(c.symbol,20,4) && c2>LowestLow(c.symbol,20,4);
   if(!bosUp && !bosDn && !chochUp && !chochDn)
   {
      s.reason="No confirmed BOS/CHoCH impulse"; return s;
   }
   int dir=(bosUp||chochUp)?1:-1;
   s.valid=true; s.direction=(dir>0?UF_LONG:UF_SHORT); s.entry=(dir>0?SymbolInfoDouble(c.symbol,SYMBOL_ASK):SymbolInfoDouble(c.symbol,SYMBOL_BID));
   s.sl=(dir>0?MathMin(lo,close1-atr*1.35):MathMax(hi,close1+atr*1.35));
   s.tp=(dir>0?s.entry+MathAbs(s.entry-s.sl)*2.1:s.entry-MathAbs(s.entry-s.sl)*2.1);
   s.score=bosUp||bosDn?91:83;
   s.reason=(bosUp||bosDn?"Structure BOS with displacement":"CHoCH / character shift");
   s.weight=1.20;
   return s;
}

//=====================================================================
// ENGINE #4 - LIQUIDITY SWEEP REVERSAL
//=====================================================================
UFSignal EngineLiquidity(UFContext &c)
{
   UFSignal s; ResetSignal(s,UF_LIQUIDITY_SWEEP);
   double pdh=c.prevDayHigh,pdl=c.prevDayLow;
   double hi=High(c.symbol,PERIOD_M5,1), lo=Low(c.symbol,PERIOD_M5,1), cl=Close(c.symbol,PERIOD_M5,1);
   bool sweepHigh=(hi>pdh && cl<pdh);
   bool sweepLow=(lo<pdl && cl>pdl);
   double rangeHi=HighestHigh(c.symbol,InpStructureLookback,3);
   double rangeLo=LowestLow(c.symbol,InpStructureLookback,3);
   if(!sweepHigh && hi>rangeHi*0.99999 && cl<rangeHi) sweepHigh=true;
   if(!sweepLow && lo<rangeLo*1.00001 && cl>rangeLo) sweepLow=true;
   if(!sweepHigh && !sweepLow)
   {
      s.reason="No stop-run / liquidity reclaim"; return s;
   }
   int dir=sweepHigh?-1:1;
   s.valid=true; s.direction=(dir>0?UF_LONG:UF_SHORT); s.entry=(dir>0?SymbolInfoDouble(c.symbol,SYMBOL_ASK):SymbolInfoDouble(c.symbol,SYMBOL_BID));
   s.sl=(dir>0?lo-c.atr*0.30:hi+c.atr*0.30);
   double target=(dir>0?MathMin(c.vwap,c.prevDayHigh):MathMax(c.vwap,c.prevDayLow));
   if((dir>0 && target<=s.entry) || (dir<0 && target>=s.entry)) target=(dir>0?s.entry+c.atr*2.2:s.entry-c.atr*2.2);
   s.tp=target;
   s.score=88.0+(c.news==UF_NEWS_NORMAL?7.0:0.0);
   s.reason=(sweepHigh?"Buy-side liquidity swept then rejected":"Sell-side liquidity swept then reclaimed");
   s.weight=1.25;
   return s;
}

//=====================================================================
// ENGINE #5 - FVG + ORDER BLOCK
//=====================================================================
UFSignal EngineFVGOB(UFContext &c)
{
   UFSignal s; ResetSignal(s,UF_FVG_ORDERBLOCK);
   for(int i=3;i<=8;i++)
   {
      double h2=High(c.symbol,PERIOD_M5,i+1), l2=Low(c.symbol,PERIOD_M5,i+1);
      double h0=High(c.symbol,PERIOD_M5,i-1), l0=Low(c.symbol,PERIOD_M5,i-1);
      double o=Open(c.symbol,PERIOD_M5,i), cl=Close(c.symbol,PERIOD_M5,i);
      double body=MathAbs(cl-o);
      bool bullFVG=l0>h2 && cl>o && body>=c.atr*0.55;
      bool bearFVG=h0<l2 && cl<o && body>=c.atr*0.55;
      if(!bullFVG && !bearFVG) continue;
      int dir=bullFVG?1:-1;
      double top=bullFVG?l0:h0;
      double bottom=bullFVG?h2:l2;
      double px=Close(c.symbol,PERIOD_M5,1);
      bool inZone=(px>=bottom-c.atr*0.20 && px<=top+c.atr*0.20);
      if(!inZone) continue;
      s.valid=true; s.direction=(dir>0?UF_LONG:UF_SHORT); s.entry=(dir>0?SymbolInfoDouble(c.symbol,SYMBOL_ASK):SymbolInfoDouble(c.symbol,SYMBOL_BID));
      s.sl=(dir>0?bottom-c.atr*0.45:top+c.atr*0.45);
      s.tp=(dir>0?s.entry+c.atr*3.0:s.entry-c.atr*3.0);
      s.score=86.0+(body/c.atr>0.9?7:0);
      s.reason=(dir>0?"Bullish displacement FVG retest":"Bearish displacement FVG retest");
      s.weight=1.15;
      return s;
   }
   s.reason="No active FVG/imbalance retest";
   return s;
}

//=====================================================================
// ENGINE #6 - VOLATILITY BREAKOUT
//=====================================================================
UFSignal EngineVolBreakout(UFContext &c)
{
   UFSignal s; ResetSignal(s,UF_VOLATILITY_BREAKOUT);
   double hh=HighestHigh(c.symbol,InpDonchianLookback,2);
   double ll=LowestLow(c.symbol,InpDonchianLookback,2);
   double px=Close(c.symbol,PERIOD_M5,1);
   long v1=Vol(c.symbol,PERIOD_M5,1), v2=Vol(c.symbol,PERIOD_M5,2), v3=Vol(c.symbol,PERIOD_M5,3);
   double vavg=(double)(v2+v3)/2.0;
   bool volConfirm=(vavg>0 && (double)v1>vavg*1.15);
   if(px<=hh && px>=ll)
   {
      s.reason="Donchian range intact"; return s;
   }
   int dir=px>hh?1:-1;
   if(!volConfirm && c.atrRatio<1.10)
   {
      s.reason="Breakout lacks expansion/volume confirmation"; return s;
   }
   s.valid=true; s.direction=(dir>0?UF_LONG:UF_SHORT); s.entry=(dir>0?SymbolInfoDouble(c.symbol,SYMBOL_ASK):SymbolInfoDouble(c.symbol,SYMBOL_BID));
   s.sl=(dir>0?hh-c.atr*0.65:ll+c.atr*0.65);
   s.tp=(dir>0?s.entry+c.atr*3.2:s.entry-c.atr*3.2);
   s.score=MathMin(97.0,69.0+c.atrRatio*16.0+(volConfirm?8:0));
   s.reason="Donchian breakout + ATR/volume expansion";
   s.weight=1.15;
   return s;
}

//=====================================================================
// ENGINE #7 - MEAN REVERSION
//=====================================================================
UFSignal EngineMeanRev(UFContext &c)
{
   UFSignal s; ResetSignal(s,UF_MEAN_REVERSION);
   double upper=0,lower=0,mid=0,rsi=50,adx=0,stochK=50,stochD=50;
   CopyValue(c.hBands_M5,1,1,upper); CopyValue(c.hBands_M5,2,1,lower); CopyValue(c.hBands_M5,0,1,mid);
   CopyValue(c.hRSI_M5,0,1,rsi); CopyValue(c.hADX_M5,0,1,adx);
   CopyValue(c.hStoch_M5,0,1,stochK); CopyValue(c.hStoch_M5,1,1,stochD);
   double px=Close(c.symbol,PERIOD_M5,1);
   bool shortSetup=(px>=upper && rsi>=67 && stochK<stochD && adx<24);
   bool longSetup=(px<=lower && rsi<=33 && stochK>stochD && adx<24);
   if(!shortSetup && !longSetup)
   {
      s.reason="No mean-reversion extreme"; return s;
   }
   int dir=shortSetup?-1:1;
   s.valid=true; s.direction=(dir>0?UF_LONG:UF_SHORT); s.entry=(dir>0?SymbolInfoDouble(c.symbol,SYMBOL_ASK):SymbolInfoDouble(c.symbol,SYMBOL_BID));
   s.sl=(dir>0?px-c.atr*1.35:px+c.atr*1.35);
   s.tp=(dir>0?mid:s.entry>mid?mid:s.entry-c.atr*1.8);
   if(dir>0) s.tp=mid;
   else s.tp=mid;
   if((dir>0 && s.tp<=s.entry) || (dir<0 && s.tp>=s.entry)) s.tp=(dir>0?s.entry+c.atr*1.8:s.entry-c.atr*1.8);
   s.score=MathMin(94.0,67.0+MathAbs(rsi-50)*0.8+(24-adx)*0.8);
   s.reason="Bollinger extreme + RSI/Stoch + low ADX";
   s.weight=0.95;
   return s;
}

//=====================================================================
// ENGINE #8 - SESSION OPENING RANGE BREAKOUT
//=====================================================================
UFSignal EngineORB(UFContext &c)
{
   UFSignal s; ResetSignal(s,UF_SESSION_ORB);
   datetime now=TimeTradeServer();
   int h=HourOf(now);
   int startHour=(h>=12 && h<21)?12:7;
   MqlDateTime d; TimeToStruct(now,d); d.hour=startHour; d.min=0; d.sec=0;
   datetime start=StructToTime(d);
   if(start>now) start-=86400;
   datetime orEnd=start+InpSessionOpeningMinutes*60;
   if(now<orEnd)
   {
      s.reason="Opening range still forming"; return s;
   }
   int startShift=iBarShift(c.symbol,PERIOD_M5,start,false);
   int endShift=iBarShift(c.symbol,PERIOD_M5,orEnd,false);
   if(startShift<0 || endShift<0) {s.reason="ORB data unavailable";return s;}
   double hi=-DBL_MAX,lo=DBL_MAX;
   int loShift=MathMin(startShift,MathMax(0,endShift));
   int hiShift=MathMax(startShift,MathMax(0,endShift));
   for(int i=loShift;i<=hiShift;i++)
   {
      hi=MathMax(hi,High(c.symbol,PERIOD_M5,i));
      lo=MathMin(lo,Low(c.symbol,PERIOD_M5,i));
   }
   double px=Close(c.symbol,PERIOD_M5,1);
   bool up=px>hi && RecentBullImpulse(c.symbol,1);
   bool dn=px<lo && RecentBearImpulse(c.symbol,1);
   if(!up && !dn) {s.reason="No ORB breakout";return s;}
   int dir=up?1:-1;
   s.valid=true;s.direction=(dir>0?UF_LONG:UF_SHORT);s.entry=(dir>0?SymbolInfoDouble(c.symbol,SYMBOL_ASK):SymbolInfoDouble(c.symbol,SYMBOL_BID));
   s.sl=(dir>0?hi-c.atr*0.80:lo+c.atr*0.80);
   s.tp=(dir>0?s.entry+c.atr*2.8:s.entry-c.atr*2.8);
   s.score=84.0+(SessionQuality(now)>80?7:0);
   s.reason="Session opening-range displacement breakout";
   s.weight=1.05;
   return s;
}

//=====================================================================
// ENGINE #9 - VWAP VALUE
//=====================================================================
UFSignal EngineVWAP(UFContext &c)
{
   UFSignal s; ResetSignal(s,UF_VWAP_VALUE);
   if(c.vwap<=0) {s.reason="VWAP unavailable";return s;}
   double px=Close(c.symbol,PERIOD_M5,1), rsi=50;
   CopyValue(c.hRSI_M5,0,1,rsi);
   double dist=(px-c.vwap)/c.atr;
   bool longSetup=dist<-1.05 && rsi<40;
   bool shortSetup=dist>1.05 && rsi>60;
   if(!longSetup && !shortSetup)
   {
      s.reason="Price inside value band"; return s;
   }
   int dir=longSetup?1:-1;
   s.valid=true;s.direction=(dir>0?UF_LONG:UF_SHORT);s.entry=(dir>0?SymbolInfoDouble(c.symbol,SYMBOL_ASK):SymbolInfoDouble(c.symbol,SYMBOL_BID));
   s.sl=(dir>0?px-c.atr*1.5:px+c.atr*1.5);
   s.tp=(dir>0?c.vwap:s.entry-c.atr*2.0);
   if(dir<0) s.tp=c.vwap;
   if((dir>0 && s.tp<=s.entry)||(dir<0 && s.tp>=s.entry)) s.tp=(dir>0?s.entry+c.atr*2.0:s.entry-c.atr*2.0);
   s.score=MathMin(93.0,70.0+MathMin(18.0,MathAbs(dist)*8.0));
   s.reason="VWAP dislocation + RSI value reversion";
   s.weight=1.00;
   return s;
}

//=====================================================================
// INTERMARKET HELPERS
//=====================================================================
double RateMomentum(string symbol,int bars)
{
   if(symbol=="" || !EnsureSymbol(symbol)) return 0;
   double a=Close(symbol,PERIOD_M15,1), b=Close(symbol,PERIOD_M15,bars+1);
   if(a<=0 || b<=0) return 0;
   return (a-b)/b*100.0;
}

double PearsonCorrelation(string a,string b,int bars)
{
   if(a=="" || b=="" || !EnsureSymbol(a) || !EnsureSymbol(b)) return 0;
   int n=0; double sx=0,sy=0,sxx=0,syy=0,sxy=0;
   for(int i=1;i<=bars;i++)
   {
      double ax=Close(a,PERIOD_M15,i), ax1=Close(a,PERIOD_M15,i+1);
      double by=Close(b,PERIOD_M15,i), by1=Close(b,PERIOD_M15,i+1);
      if(ax<=0||ax1<=0||by<=0||by1<=0) continue;
      double x=ax/ax1-1.0, y=by/by1-1.0;
      sx+=x; sy+=y; sxx+=x*x; syy+=y*y; sxy+=x*y; n++;
   }
   if(n<10) return 0;
   double num=n*sxy-sx*sy;
   double den=MathSqrt(MathMax(0.0,(n*sxx-sx*sx)*(n*syy-sy*sy)));
   return den>0?num/den:0;
}

//=====================================================================
// ENGINE #10 - INTERMARKET CONFIRMATION
//=====================================================================
UFSignal EngineIntermarket(UFContext &c)
{
   UFSignal s; ResetSignal(s,UF_INTERMARKET);
   double local=RateMomentum(c.symbol,InpIntermarketBars);
   if(local==0) {s.reason="Local momentum unavailable";return s;}
   double dxy=RateMomentum(InpDXYSymbol,InpIntermarketBars);
   double spx=RateMomentum(InpUS500Symbol,InpIntermarketBars);
   double ndx=RateMomentum(InpNAS100Symbol,InpIntermarketBars);
   double us10=RateMomentum(InpUS10YSymbol,InpIntermarketBars);
   bool isRiskAsset=IsGoldSymbol(c.symbol)||IsIndexSymbol(c.symbol)||StringFind(Upper(c.symbol),"BTC")>=0;
   double scoreLong=0,scoreShort=0;
   if(isRiskAsset)
   {
      if(spx>0) scoreLong+=25; else if(spx<0) scoreShort+=25;
      if(ndx>0) scoreLong+=20; else if(ndx<0) scoreShort+=20;
      if(dxy<0) scoreLong+=25; else if(dxy>0) scoreShort+=25;
      if(us10<0) scoreLong+=10; else if(us10>0) scoreShort+=10;
   }
   else
   {
      string base=BaseCurrencyGuess(c.symbol), quote=QuoteCurrencyGuess(c.symbol);
      // USD strength is represented by DXY. Non-USD major pairs therefore invert DXY.
      if(base=="USD") {if(dxy>0) scoreLong+=35; else if(dxy<0) scoreShort+=35;}
      else if(quote=="USD") {if(dxy<0) scoreLong+=35; else if(dxy>0) scoreShort+=35;}
      if(spx>0) scoreLong+=12; else if(spx<0) scoreShort+=12;
      if(ndx>0) scoreLong+=12; else if(ndx<0) scoreShort+=12;
   }
   double localSign=local>0?1:-1;
   double best=MathMax(scoreLong,scoreShort);
   if(best<InpIntermarketMinScore || (localSign>0 && scoreLong<scoreShort) || (localSign<0 && scoreShort<scoreLong))
   {
      s.reason="Cross-asset confirmation weak or conflicting"; return s;
   }
   int dir=scoreLong>scoreShort?1:-1;
   s.valid=true;s.direction=(dir>0?UF_LONG:UF_SHORT);s.entry=(dir>0?SymbolInfoDouble(c.symbol,SYMBOL_ASK):SymbolInfoDouble(c.symbol,SYMBOL_BID));
   s.sl=(dir>0?s.entry-c.atr*1.6:s.entry+c.atr*1.6);
   s.tp=(dir>0?s.entry+c.atr*3.2:s.entry-c.atr*3.2);
   s.score=MathMin(95.0,50.0+best*0.55+(localSign==dir?12:0));
   s.reason="DXY/US500/NAS100/US10Y cross-confirmation";
   s.weight=1.10;
   return s;
}

//=====================================================================
// ADAPTIVE HEALTH
//=====================================================================
void InitHealth()
{
   for(int i=0;i<UF_STRATEGY_COUNT;i++)
   {
      g_health[i].trades=0; g_health[i].wins=0; g_health[i].losses=0;
      g_health[i].lossStreak=0; g_health[i].maxLossStreak=0;
      g_health[i].sumR=0; g_health[i].sumR2=0;
      g_health[i].grossProfit=0; g_health[i].grossLoss=0;
      g_health[i].winRate=0; g_health[i].profitFactor=0;
      g_health[i].expectancyR=0; g_health[i].weight=1.0; g_health[i].enabled=true;
   }
   for(int i=0;i<UF_STRATEGY_COUNT;i++)
      g_health[i].enabled=StrategyEnabled((ENUM_UF_STRATEGY)i);
}

double AdaptiveStrategyWeight(ENUM_UF_STRATEGY s)
{
   if(!InpUseAdaptiveWeights) return 1.0;
   UFHealth h=g_health[(int)s];
   if(h.trades<InpHealthMinTrades) return h.weight;
   double w=1.0;
   if(h.expectancyR>0.35) w=1.15;
   else if(h.expectancyR>0.15) w=1.08;
   else if(h.expectancyR<InpHealthMinExpectancyR) w=0.72;
   else if(h.expectancyR<0) w=0.88;
   if(h.lossStreak>=InpHealthDegradeLossStreak) w*=0.72;
   return MathMax(InpHealthWeightFloor,MathMin(InpHealthWeightCeiling,w));
}

void RegisterResult(ENUM_UF_STRATEGY strategy,double pnl,double r)
{
   int idx=(int)strategy;
   if(idx<0 || idx>=UF_STRATEGY_COUNT) return;

   g_health[idx].trades++;
   g_health[idx].sumR+=r;
   g_health[idx].sumR2+=r*r;

   if(pnl>=0)
   {
      g_health[idx].wins++;
      g_health[idx].grossProfit+=pnl;
      g_health[idx].lossStreak=0;
   }
   else
   {
      g_health[idx].losses++;
      g_health[idx].grossLoss+=MathAbs(pnl);
      g_health[idx].lossStreak++;
      g_health[idx].maxLossStreak=MathMax(g_health[idx].maxLossStreak,g_health[idx].lossStreak);
   }

   g_health[idx].winRate=100.0*(double)g_health[idx].wins/(double)MathMax(1,g_health[idx].trades);
   g_health[idx].profitFactor=(g_health[idx].grossLoss>0 ? g_health[idx].grossProfit/g_health[idx].grossLoss : 0.0);
   g_health[idx].expectancyR=g_health[idx].sumR/(double)MathMax(1,g_health[idx].trades);

   // Recompute adaptive weight without storing a reference alias to an array element.
   double w=1.0;
   if(g_health[idx].trades<InpHealthMinTrades)
      w=1.0;
   else if(g_health[idx].expectancyR>0.35)
      w=1.15;
   else if(g_health[idx].expectancyR>0.15)
      w=1.08;
   else if(g_health[idx].expectancyR<InpHealthMinExpectancyR)
      w=0.72;
   else if(g_health[idx].expectancyR<0)
      w=0.88;
   if(g_health[idx].lossStreak>=InpHealthDegradeLossStreak) w*=0.72;

   g_health[idx].weight=MathMax(InpHealthWeightFloor,MathMin(InpHealthWeightCeiling,w));

   if(g_health[idx].lossStreak>=InpHealthDegradeLossStreak ||
      (g_health[idx].trades>=InpHealthMinTrades && g_health[idx].expectancyR<InpHealthMinExpectancyR))
      g_health[idx].enabled=false;
   else if(g_health[idx].trades>=InpHealthMinTrades && g_health[idx].expectancyR>0)
      g_health[idx].enabled=StrategyEnabled(strategy);
}


//=====================================================================
// PORTFOLIO / RISK HELPERS
//=====================================================================
double EstimatePositionRiskMoney(string symbol)
{
   double vol=PositionGetDouble(POSITION_VOLUME);
   double open=PositionGetDouble(POSITION_PRICE_OPEN);
   double sl=PositionGetDouble(POSITION_SL);
   long type=PositionGetInteger(POSITION_TYPE);
   if(vol<=0 || open<=0 || sl<=0) return 0;
   double pnl=0;
   ENUM_ORDER_TYPE ot=(type==POSITION_TYPE_BUY?ORDER_TYPE_BUY:ORDER_TYPE_SELL);
   if(!OrderCalcProfit(ot,symbol,vol,open,sl,pnl)) return 0;
   return MathAbs(pnl);
}

double OpenPortfolioRiskPct()
{
   double eq=AccountInfoDouble(ACCOUNT_EQUITY); if(eq<=0) return 0;
   double money=0;
   for(int i=0;i<PositionsTotal();i++)
   {
      ulong ticket=PositionGetTicket(i); if(ticket==0) continue;
      if(!PositionSelectByTicket(ticket)) continue;
      if((ulong)PositionGetInteger(POSITION_MAGIC)!=InpMagicNumber) continue;
      money+=EstimatePositionRiskMoney(PositionGetString(POSITION_SYMBOL));
   }
   return 100.0*money/eq;
}

int OpenManagedPositions()
{
   int n=0;
   for(int i=0;i<PositionsTotal();i++)
   {
      ulong t=PositionGetTicket(i); if(t==0) continue;
      if(!PositionSelectByTicket(t)) continue;
      if((ulong)PositionGetInteger(POSITION_MAGIC)==InpMagicNumber) n++;
   }
   return n;
}

bool HasManagedPosition(string symbol,ENUM_UF_DIRECTION wanted=UF_NONE)
{
   for(int i=0;i<PositionsTotal();i++)
   {
      ulong t=PositionGetTicket(i); if(t==0) continue;
      if(!PositionSelectByTicket(t)) continue;
      if((ulong)PositionGetInteger(POSITION_MAGIC)!=InpMagicNumber) continue;
      if(PositionGetString(POSITION_SYMBOL)!=symbol) continue;
      long type=PositionGetInteger(POSITION_TYPE);
      if(wanted==UF_NONE) return true;
      if((wanted==UF_LONG && type==POSITION_TYPE_BUY) || (wanted==UF_SHORT && type==POSITION_TYPE_SELL)) return true;
      if(!InpAllowOppositeHedges) return true;
   }
   return false;
}

bool RiskGate(string reason)
{
   reason="";
   double eq=AccountInfoDouble(ACCOUNT_EQUITY);
   if(eq<=0){reason="No equity";return false;}
   double dayDD=100.0*(g_dayStartEquity-eq)/g_dayStartEquity;
   double weekDD=100.0*(g_weekStartEquity-eq)/g_weekStartEquity;
   double maxDD=100.0*(g_peakEquity-eq)/g_peakEquity;
   if(dayDD>=InpMaxDailyDrawdownPct){reason="Daily DD limit";return false;}
   if(weekDD>=InpMaxWeeklyDrawdownPct){reason="Weekly DD limit";return false;}
   if(maxDD>=InpMaxAccountDrawdownPct){reason="Max account DD limit";return false;}
   if(OpenManagedPositions()>=InpMaxPositions){reason="Max portfolio positions";return false;}
   if(InpMaxDailyTrades>0 && g_dayTrades>=InpMaxDailyTrades){reason="Daily trade limit";return false;}
   if(InpUseEconomicCalendar && g_globalNews==UF_NEWS_BLOCK){reason=g_newsReason;return false;}
   return true;
}

double CorrelationPenalty(string symbol,ENUM_UF_DIRECTION dir)
{
   if(!InpUseCorrelationGate) return 0;
   double penalty=0;
   for(int i=0;i<PositionsTotal();i++)
   {
      ulong t=PositionGetTicket(i); if(t==0) continue;
      if(!PositionSelectByTicket(t)) continue;
      if((ulong)PositionGetInteger(POSITION_MAGIC)!=InpMagicNumber) continue;
      string other=PositionGetString(POSITION_SYMBOL);
      if(other==symbol) continue;
      double corr=PearsonCorrelation(symbol,other,InpCorrelationBars);
      if(MathAbs(corr)<InpCorrelationThreshold) continue;
      long type=PositionGetInteger(POSITION_TYPE);
      ENUM_UF_DIRECTION od=(type==POSITION_TYPE_BUY?UF_LONG:UF_SHORT);
      if(od==dir) penalty+=InpSameDirectionCorrPenalty*MathAbs(corr);
      else penalty+=InpOppositeDirectionCorrPenalty*MathAbs(corr);
   }
   return MathMin(45.0,penalty);
}

bool RiskForStops(string symbol,double entry,double sl,double &lots,double &riskMoney,double riskPct)
{
   lots=0; riskMoney=0;
   double eq=AccountInfoDouble(ACCOUNT_EQUITY); if(eq<=0) return false;
   riskPct=MathMin(InpMaxRiskPercentTrade,MathMax(0.01,riskPct));
   riskMoney=eq*riskPct/100.0;
   long type=(entry>sl?ORDER_TYPE_BUY:ORDER_TYPE_SELL);
   double loss1=0;
   if(!OrderCalcProfit((ENUM_ORDER_TYPE)type,symbol,1.0,entry,sl,loss1)) return false;
   loss1=MathAbs(loss1);
   if(loss1<=0) return false;
   double raw=riskMoney/loss1;
   double minLot=SymbolInfoDouble(symbol,SYMBOL_VOLUME_MIN);
   double maxLot=SymbolInfoDouble(symbol,SYMBOL_VOLUME_MAX);
   double step=SymbolInfoDouble(symbol,SYMBOL_VOLUME_STEP);
   if(step<=0) step=minLot;
   if(raw<minLot)
   {
      // Never round upward into an oversized risk position.
      return false;
   }
   raw=MathMin(maxLot,raw);
   lots=MathFloor(raw/step)*step;
   lots=NormalizeDouble(lots,2);
   return lots>=minLot;
}

bool EnforceStopGeometry(string symbol,ENUM_UF_DIRECTION dir,double entry,double &sl,double &tp)
{
   double point=PointValue(symbol);
   double minStop=(double)SymbolInfoInteger(symbol,SYMBOL_TRADE_STOPS_LEVEL)*point;
   double freeze=(double)SymbolInfoInteger(symbol,SYMBOL_TRADE_FREEZE_LEVEL)*point;
   double minDist=MathMax(minStop,freeze)+point*2;
   if(dir==UF_LONG)
   {
      if(sl>=entry) sl=entry-MathMax(minDist,MathAbs(entry-sl));
      if(tp<=entry) tp=entry+MathMax(minDist,MathAbs(tp-entry));
      if(entry-sl<minDist) sl=entry-minDist;
      if(tp-entry<minDist) tp=entry+minDist;
   }
   else if(dir==UF_SHORT)
   {
      if(sl<=entry) sl=entry+MathMax(minDist,MathAbs(entry-sl));
      if(tp>=entry) tp=entry-MathMax(minDist,MathAbs(tp-entry));
      if(sl-entry<minDist) sl=entry+minDist;
      if(entry-tp<minDist) tp=entry-minDist;
   }
   sl=NormalizePrice(symbol,sl); tp=NormalizePrice(symbol,tp);
   return true;
}

//=====================================================================
// FUSION ENGINE
//=====================================================================
void RunAllEngines(UFContext &c)
{
   for(int i=0;i<UF_STRATEGY_COUNT;i++) ResetSignal(c.signals[i],(ENUM_UF_STRATEGY)i);
   c.validVotes=0; c.longVotes=0; c.shortVotes=0;

   c.signals[UF_TREND_CONTINUATION]=EngineTrend(c);
   c.signals[UF_PULLBACK_MOMENTUM]=EnginePullback(c);
   c.signals[UF_STRUCTURE_BOS_CHoCH]=EngineStructure(c);
   c.signals[UF_LIQUIDITY_SWEEP]=EngineLiquidity(c);
   c.signals[UF_FVG_ORDERBLOCK]=EngineFVGOB(c);
   c.signals[UF_VOLATILITY_BREAKOUT]=EngineVolBreakout(c);
   c.signals[UF_MEAN_REVERSION]=EngineMeanRev(c);
   c.signals[UF_SESSION_ORB]=EngineORB(c);
   c.signals[UF_VWAP_VALUE]=EngineVWAP(c);
   c.signals[UF_INTERMARKET]=EngineIntermarket(c);

   double longScore=0,shortScore=0,totalWeight=0;
   double slLong=0,tpLong=0,slWLong=0,tpWLong=0;
   double slShort=0,tpShort=0,slWShort=0,tpWShort=0;

   for(int i=0;i<UF_STRATEGY_COUNT;i++)
   {
      ENUM_UF_STRATEGY st=(ENUM_UF_STRATEGY)i;
      if(!StrategyEnabled(st)) continue;
      if(!c.signals[i].valid) continue;
      double adaptive=AdaptiveStrategyWeight(st);
      c.signals[i].weight*=adaptive;
      double w=(c.signals[i].score/100.0)*c.signals[i].weight;
      totalWeight+=w; c.validVotes++;
      if(c.signals[i].direction==UF_LONG)
      {
         c.longVotes++;
         longScore+=w;
         slLong+=c.signals[i].sl*w; tpLong+=c.signals[i].tp*w; slWLong+=w; tpWLong+=w;
      }
      else if(c.signals[i].direction==UF_SHORT)
      {
         c.shortVotes++;
         shortScore+=w;
         slShort+=c.signals[i].sl*w; tpShort+=c.signals[i].tp*w; slWShort+=w; tpWShort+=w;
      }
   }

   double directionalTotal=longScore+shortScore;
   double edge=directionalTotal>0?100.0*MathAbs(longScore-shortScore)/directionalTotal:0;
   ENUM_UF_DIRECTION dir=(longScore>shortScore?UF_LONG:(shortScore>longScore?UF_SHORT:UF_NONE));
   double baseScore=directionalTotal>0?MathMin(100.0,100.0*MathMax(longScore,shortScore)/directionalTotal):0;
   double agreement=100.0*(double)MathMax(c.longVotes,c.shortVotes)/(double)MathMax(1,c.validVotes);
   double regimeBoost=MathMin(10.0,c.regimeScore*0.08);
   double session=SessionQuality(TimeTradeServer());
   double sessionBoost=(session-50.0)*0.08;
   double newsPenalty=(c.news==UF_NEWS_CAUTION?8.0:0.0);
   double corrPenalty=CorrelationPenalty(c.symbol,dir);
   double score=baseScore*0.72+agreement*0.13+edge*0.15+regimeBoost+sessionBoost-newsPenalty-corrPenalty;
   score=MathMax(0.0,MathMin(100.0,score));

   c.fusionDirection=dir;
   c.fusionScore=score;
   c.fusionEntry=(dir==UF_LONG?SymbolInfoDouble(c.symbol,SYMBOL_ASK):(dir==UF_SHORT?SymbolInfoDouble(c.symbol,SYMBOL_BID):0));
   c.fusionSL=0;c.fusionTP=0;
   if(dir==UF_LONG && slWLong>0)
   {
      c.fusionSL=slLong/slWLong; c.fusionTP=tpLong/tpWLong;
   }
   else if(dir==UF_SHORT && slWShort>0)
   {
      c.fusionSL=slShort/slWShort; c.fusionTP=tpShort/tpWShort;
   }
   if(dir!=UF_NONE)
   {
      EnforceStopGeometry(c.symbol,dir,c.fusionEntry,c.fusionSL,c.fusionTP);
      double risk=MathAbs(c.fusionEntry-c.fusionSL);
      if(risk>0)
      {
         double rr=MathAbs(c.fusionTP-c.fusionEntry)/risk;
         if(rr<InpMinRR)
            c.fusionTP=(dir==UF_LONG?c.fusionEntry+risk*InpTargetRR:c.fusionEntry-risk*InpTargetRR);
         rr=MathAbs(c.fusionTP-c.fusionEntry)/risk;
         if(rr>InpMaxRR)
            c.fusionTP=(dir==UF_LONG?c.fusionEntry+risk*InpMaxRR:c.fusionEntry-risk*InpMaxRR);
         c.fusionRR=MathAbs(c.fusionTP-c.fusionEntry)/risk;
      }
   }
   else c.fusionRR=0;

   if(dir==UF_LONG) c.fusionReason="LONG fusion: "+IntegerToString(c.longVotes)+" engines vs "+IntegerToString(c.shortVotes)+" | edge "+DoubleToString(edge,0)+"%";
   else if(dir==UF_SHORT) c.fusionReason="SHORT fusion: "+IntegerToString(c.shortVotes)+" engines vs "+IntegerToString(c.longVotes)+" | edge "+DoubleToString(edge,0)+"%";
   else c.fusionReason="No directional consensus";

   if(c.regime==UF_REGIME_UNSAFE || c.news==UF_NEWS_BLOCK)
      c.action="BLOCK: safety regime/news";
   else if(c.validVotes<InpMinEngineAgreement)
      c.action="WAIT: agreement < "+IntegerToString(InpMinEngineAgreement);
   else if(edge<InpMinDirectionalEdge)
      c.action="WAIT: directional edge weak";
   else if(score<InpMinFusionScore)
      c.action="WAIT: fusion score "+DoubleToString(score,1);
   else if(InpUseCorrelationGate && corrPenalty>=35)
      c.action="BLOCK: correlation concentration";
   else
      c.action="QUALIFIED "+DirStr(dir)+" score="+DoubleToString(score,1);
}

//=====================================================================
// DECISION BUILD
//=====================================================================
UFDecision BuildDecision(UFContext &c)
{
   UFDecision d; d.approved=false; d.symbol=c.symbol; d.direction=c.fusionDirection; d.source=UF_INTERMARKET;
   double bestEngineScore=-1;
   for(int bi=0;bi<UF_STRATEGY_COUNT;bi++)
   {
      if(c.signals[bi].valid && c.signals[bi].direction==c.fusionDirection && c.signals[bi].score>bestEngineScore)
      {
         bestEngineScore=c.signals[bi].score;
         d.source=(ENUM_UF_STRATEGY)bi;
      }
   }
   d.score=c.fusionScore; d.entry=c.fusionEntry; d.sl=c.fusionSL; d.tp=c.fusionTP; d.rr=c.fusionRR; d.riskPct=0; d.riskMoney=0; d.lots=0; d.reason=c.fusionReason;

   if(!InpAutoTradeQualified){d.reason="Auto-trade disabled";return d;}
   string rg=""; if(!RiskGate(rg)){d.reason=rg;return d;}
   if(c.enabled==false){d.reason="Symbol disabled";return d;}
   if(InpOnePositionPerSymbol && HasManagedPosition(c.symbol,UF_NONE))
   {
      d.reason="Existing managed position on symbol"; return d;
   }
   if(c.fusionDirection==UF_NONE){d.reason=c.fusionReason;return d;}
   if(c.validVotes<InpMinEngineAgreement){d.reason="Not enough engine agreement";return d;}
   if(c.fusionScore<InpMinFusionScore){d.reason="Fusion score below threshold";return d;}
   if(c.news==UF_NEWS_BLOCK){d.reason=g_newsReason;return d;}
   if(c.spreadPoints>InpMaxSpreadPoints){d.reason="Spread gate";return d;}
   if((TimeCurrent()-g_lastTradeClose)<InpCooldownSeconds){d.reason="Global close cooldown";return d;}

   double riskPct=InpRiskPercent;
   if(c.fusionScore>=InpStrongFusionScore) riskPct*=1.10;
   else if(c.fusionScore<InpMinFusionScore+5) riskPct*=0.85;
   if(InpUseConfidenceRiskScale) riskPct*=MathMax(0.60,MathMin(1.0,c.fusionScore/100.0));
   double currentPortfolio=OpenPortfolioRiskPct();
   if(currentPortfolio>=InpMaxPortfolioRiskPct){d.reason="Portfolio risk ceiling";return d;}
   if(currentPortfolio+riskPct>InpMaxPortfolioRiskPct)
      riskPct=MathMax(0.01,InpMaxPortfolioRiskPct-currentPortfolio);

   d.riskPct=MathMin(InpMaxRiskPercentTrade,riskPct);
   if(!RiskForStops(c.symbol,d.entry,d.sl,d.lots,d.riskMoney,d.riskPct))
   {
      d.reason="Position sizing rejected (minimum lot would over-risk)"; return d;
   }
   d.approved=true;
   d.reason=c.fusionReason+" | RR="+DoubleToString(d.rr,2)+" | Risk="+DoubleToString(d.riskPct,2)+"%";
   return d;
}

//=====================================================================
// EXECUTION
//=====================================================================
string MakeTradeComment(ENUM_UF_STRATEGY source,double riskMoney)
{
   return "UF10|"+IntegerToString((int)source)+"|"+DoubleToString(riskMoney,2);
}

bool ExecuteDecision(UFDecision &d)
{
   if(!d.approved) return false;
   g_trade.SetExpertMagicNumber(InpMagicNumber);
   g_trade.SetDeviationInPoints(InpDeviationPoints);
   g_trade.SetTypeFillingBySymbol(d.symbol);
   bool ok=false;
   string comment=MakeTradeComment(d.source,d.riskMoney);
   if(d.direction==UF_LONG)
      ok=g_trade.Buy(d.lots,d.symbol,0,d.sl,d.tp,comment);
   else if(d.direction==UF_SHORT)
      ok=g_trade.Sell(d.lots,d.symbol,0,d.sl,d.tp,comment);

   ulong rc=g_trade.ResultRetcode();
   if(!ok || (rc!=TRADE_RETCODE_DONE && rc!=TRADE_RETCODE_PLACED && rc!=TRADE_RETCODE_DONE_PARTIAL))
   {
      g_totalOrdersFailed++;
      LogAction("ORDER FAIL "+d.symbol+" "+DirStr(d.direction)+" rc="+IntegerToString((int)rc)+" "+g_trade.ResultRetcodeDescription());
      return false;
   }
   g_totalExecuted++;
   g_dayTrades++;
   LogAction("TRADE "+d.symbol+" "+DirStr(d.direction)+" lots="+DoubleToString(d.lots,2)+" SL="+DoubleToString(d.sl,SymbolDigits(d.symbol))+" TP="+DoubleToString(d.tp,SymbolDigits(d.symbol))+" | "+d.reason);
   return true;
}

//=====================================================================
// POSITION MANAGEMENT
//=====================================================================
void ManagePositions()
{
   for(int i=PositionsTotal()-1;i>=0;i--)
   {
      ulong ticket=PositionGetTicket(i); if(ticket==0) continue;
      if(!PositionSelectByTicket(ticket)) continue;
      if((ulong)PositionGetInteger(POSITION_MAGIC)!=InpMagicNumber) continue;
      string symbol=PositionGetString(POSITION_SYMBOL);
      int ci=-1; for(int c=0;c<g_symbolCount;c++) if(g_ctx[c].symbol==symbol){ci=c;break;}
      if(ci<0) continue;
      UFContext ctx=g_ctx[ci];
      long type=PositionGetInteger(POSITION_TYPE);
      ENUM_UF_DIRECTION dir=(type==POSITION_TYPE_BUY?UF_LONG:UF_SHORT);
      double open=PositionGetDouble(POSITION_PRICE_OPEN);
      double sl=PositionGetDouble(POSITION_SL);
      double tp=PositionGetDouble(POSITION_TP);
      double px=(dir==UF_LONG?SymbolInfoDouble(symbol,SYMBOL_BID):SymbolInfoDouble(symbol,SYMBOL_ASK));
      double atr=ctx.atr; if(atr<=0) atr=PointValue(symbol)*100;
      double riskDist=MathAbs(open-sl);
      double profitDist=(dir==UF_LONG?px-open:open-px);
      double R=(riskDist>0?profitDist/riskDist:0);

      if(R>=InpBreakEvenR)
      {
         double newSL=(dir==UF_LONG?open+atr*InpBreakEvenOffsetATR:open-atr*InpBreakEvenOffsetATR);
         if((dir==UF_LONG && newSL>sl && newSL<px) || (dir==UF_SHORT && (sl==0 || newSL<sl) && newSL>px))
         {
            if(g_trade.PositionModify(ticket,NormalizePrice(symbol,newSL),tp))
               LogAction("BE+ applied "+symbol+" ticket="+IntegerToString((long)ticket));
         }
      }

      if(R>=InpTrailStartR)
      {
         double trail=(dir==UF_LONG?px-atr*InpTrailATRMult:px+atr*InpTrailATRMult);
         if((dir==UF_LONG && trail>sl && trail<px) || (dir==UF_SHORT && (sl==0 || trail<sl) && trail>px))
            g_trade.PositionModify(ticket,NormalizePrice(symbol,trail),tp);
      }

      datetime opened=(datetime)PositionGetInteger(POSITION_TIME);
      if(InpMaxHoldMinutes>0 && opened>0)
      {
         int held=(int)((TimeCurrent()-opened)/60);
         if(held>=InpMaxHoldMinutes && R<0.20)
         {
            if(g_trade.PositionClose(ticket))
               LogAction("TIME STOP "+symbol+" ticket="+IntegerToString((long)ticket));
         }
      }

      if(InpUsePartialAtR && R>=InpPartialCloseR)
      {
         // Safe on hedging accounts; on netting accounts we leave the position whole.
         ENUM_ACCOUNT_MARGIN_MODE mm=(ENUM_ACCOUNT_MARGIN_MODE)AccountInfoInteger(ACCOUNT_MARGIN_MODE);
         if(mm==ACCOUNT_MARGIN_MODE_RETAIL_HEDGING)
         {
            if(!WasPartial(ticket))
            {
               double vol=PositionGetDouble(POSITION_VOLUME);
               double minLot=SymbolInfoDouble(symbol,SYMBOL_VOLUME_MIN);
               double step=SymbolInfoDouble(symbol,SYMBOL_VOLUME_STEP); if(step<=0) step=minLot;
               double closeVol=MathFloor(vol*InpPartialCloseFraction/step)*step;
               if(closeVol>=minLot && closeVol<vol)
               {
                  if(g_trade.PositionClosePartial(ticket,closeVol))
                  {
                     MarkPartial(ticket);
                     LogAction("PARTIAL "+symbol+" ticket="+IntegerToString((long)ticket)+" at "+DoubleToString(R,2)+"R");
                  }
               }
            }
         }
      }
   }
}

//=====================================================================
// TRADE RESULT / TAG PARSER
//=====================================================================
bool ParseTradeComment(string comment,int &strategy,double &riskMoney)
{
   strategy=-1; riskMoney=0;
   if(StringFind(comment,"UF10|")!=0) return false;
   string p=StringSubstr(comment,5);
   string a[]; ushort sep=(ushort)StringGetCharacter("|",0);
   int n=StringSplit(p,sep,a);
   if(n<2) return false;
   strategy=(int)StringToInteger(a[0]);
   riskMoney=StringToDouble(a[1]);
   return strategy>=0 && strategy<UF_STRATEGY_COUNT;
}

void OnClosedDeal(const MqlTradeTransaction &trans)
{
   if(trans.type!=TRADE_TRANSACTION_DEAL_ADD) return;
   ulong deal=trans.deal; if(deal==0) return;
   if(!HistoryDealSelect(deal)) return;
   if((ulong)HistoryDealGetInteger(deal,DEAL_MAGIC)!=InpMagicNumber) return;
   long entry=HistoryDealGetInteger(deal,DEAL_ENTRY);
   if(entry!=DEAL_ENTRY_OUT && entry!=DEAL_ENTRY_OUT_BY) return;
   if(trans.position>0 && PositionSelectByTicket(trans.position)) return; // partial close: do not register as a completed trade

   double pnl=HistoryDealGetDouble(deal,DEAL_PROFIT)+HistoryDealGetDouble(deal,DEAL_SWAP)+HistoryDealGetDouble(deal,DEAL_COMMISSION);
   string comment=HistoryDealGetString(deal,DEAL_COMMENT);
   int strategy=-1; double riskMoney=0;
   if(!ParseTradeComment(comment,strategy,riskMoney)) return;
   string sym=HistoryDealGetString(deal,DEAL_SYMBOL);
   double R=(riskMoney>0?pnl/riskMoney:0);
   RegisterResult((ENUM_UF_STRATEGY)strategy,pnl,R);
   g_sessionProfit+=pnl;
   if(pnl>=0) g_sessionWins++; else g_sessionLosses++;
   g_lastTradeClose=TimeCurrent();
   LogAction("CLOSE "+sym+" PnL="+DoubleToString(pnl,2)+" R="+DoubleToString(R,2)+" | "+StrategyStr((ENUM_UF_STRATEGY)strategy));
}

//=====================================================================
// ACCOUNT GOVERNANCE
//=====================================================================
void UpdateRiskState()
{
   datetime now=TimeCurrent();
   if(g_dayStart==0 || DayStart(now)!=g_dayStart)
   {
      g_dayStart=DayStart(now); g_dayStartEquity=AccountInfoDouble(ACCOUNT_EQUITY); g_sessionProfit=0; g_sessionWins=0; g_sessionLosses=0; g_dayTrades=0;
      LogAction("DAY RESET equity="+DoubleToString(g_dayStartEquity,2));
   }
   if(g_weekStart==0 || WeekStart(now)!=g_weekStart)
   {
      g_weekStart=WeekStart(now); g_weekStartEquity=AccountInfoDouble(ACCOUNT_EQUITY);
      LogAction("WEEK RESET equity="+DoubleToString(g_weekStartEquity,2));
   }
   double eq=AccountInfoDouble(ACCOUNT_EQUITY);
   if(eq>g_peakEquity) g_peakEquity=eq;
   double dayDD=100.0*(g_dayStartEquity-eq)/MathMax(0.01,g_dayStartEquity);
   double weekDD=100.0*(g_weekStartEquity-eq)/MathMax(0.01,g_weekStartEquity);
   double maxDD=100.0*(g_peakEquity-eq)/MathMax(0.01,g_peakEquity);
   if(dayDD>=InpMaxDailyDrawdownPct || weekDD>=InpMaxWeeklyDrawdownPct || maxDD>=InpMaxAccountDrawdownPct)
      g_emergency=true;
}

void EmergencyFlatten()
{
   if(!g_emergency) return;
   for(int i=PositionsTotal()-1;i>=0;i--)
   {
      ulong t=PositionGetTicket(i); if(t==0) continue;
      if(!PositionSelectByTicket(t)) continue;
      if((ulong)PositionGetInteger(POSITION_MAGIC)!=InpMagicNumber) continue;
      g_trade.PositionClose(t);
   }
   LogAction("EMERGENCY FLATTEN ACTIVE - risk governance tripped");
}

//=====================================================================
// CONTEXT INITIALIZATION
//=====================================================================
bool InitContext(UFContext &c,string symbol)
{
   c.symbol=symbol; c.enabled=false; c.initialized=false;
   if(!EnsureSymbol(symbol)) return false;
   if(BarsCount(symbol,PERIOD_M5)<InpATRLookback+20 || BarsCount(symbol,PERIOD_H1)<InpEMA200+10) return false;

   c.enabled=true; c.initialized=true; c.lastM5Bar=0;c.lastM1Bar=0;c.lastScan=0;
   c.regime=UF_REGIME_RANGE;c.news=UF_NEWS_NORMAL;c.regimeScore=0;c.atr=0;c.atrAvg=0;c.atrRatio=1;c.spreadPoints=0;
   c.vwap=0;c.prevDayHigh=0;c.prevDayLow=0;c.dayHigh=0;c.dayLow=0;c.sessionHigh=0;c.sessionLow=0;
   c.fusionScore=0;c.fusionDirection=UF_NONE;c.fusionEntry=0;c.fusionSL=0;c.fusionTP=0;c.fusionRR=0;c.longVotes=0;c.shortVotes=0;c.validVotes=0;c.fusionReason="";c.action="STARTING";

   c.hEma20M1=iMA(symbol,PERIOD_M1,InpEMA20,0,MODE_EMA,PRICE_CLOSE);
   c.hEma20M5=iMA(symbol,PERIOD_M5,InpEMA20,0,MODE_EMA,PRICE_CLOSE);
   c.hEma50M5=iMA(symbol,PERIOD_M5,InpEMA50,0,MODE_EMA,PRICE_CLOSE);
   c.hEma200H1=iMA(symbol,PERIOD_H1,InpEMA200,0,MODE_EMA,PRICE_CLOSE);
   c.hEma50H1=iMA(symbol,PERIOD_H1,InpEMA50,0,MODE_EMA,PRICE_CLOSE);
   c.hATR_M5=iATR(symbol,PERIOD_M5,InpATRPeriod);
   c.hATR_M15=iATR(symbol,PERIOD_M15,InpATRPeriod);
   c.hADX_M5=iADX(symbol,PERIOD_M5,InpADXPeriod);
   c.hRSI_M5=iRSI(symbol,PERIOD_M5,InpRSIPeriod,PRICE_CLOSE);
   c.hRSI_M1=iRSI(symbol,PERIOD_M1,InpRSIPeriod,PRICE_CLOSE);
   c.hMACD_M5=iMACD(symbol,PERIOD_M5,InpMACDFast,InpMACDSlow,InpMACDSignal,PRICE_CLOSE);
   c.hBands_M5=iBands(symbol,PERIOD_M5,InpBandsPeriod,0,InpBandsDeviation,PRICE_CLOSE);
   c.hStoch_M5=iStochastic(symbol,PERIOD_M5,InpStochK,InpStochD,InpStochSlowing,MODE_SMA,STO_LOWHIGH);
   c.hADX_M15=iADX(symbol,PERIOD_M15,InpADXPeriod);

   int h[14]={c.hEma20M1,c.hEma20M5,c.hEma50M5,c.hEma200H1,c.hEma50H1,c.hATR_M5,c.hATR_M15,c.hADX_M5,c.hRSI_M5,c.hRSI_M1,c.hMACD_M5,c.hBands_M5,c.hStoch_M5,c.hADX_M15};
   for(int i=0;i<14;i++) if(h[i]==INVALID_HANDLE) return false;
   return true;
}

void ReleaseContext(UFContext &c)
{
   if(c.hEma20M1!=INVALID_HANDLE) IndicatorRelease(c.hEma20M1);
   if(c.hEma20M5!=INVALID_HANDLE) IndicatorRelease(c.hEma20M5);
   if(c.hEma50M5!=INVALID_HANDLE) IndicatorRelease(c.hEma50M5);
   if(c.hEma200H1!=INVALID_HANDLE) IndicatorRelease(c.hEma200H1);
   if(c.hEma50H1!=INVALID_HANDLE) IndicatorRelease(c.hEma50H1);
   if(c.hATR_M5!=INVALID_HANDLE) IndicatorRelease(c.hATR_M5);
   if(c.hATR_M15!=INVALID_HANDLE) IndicatorRelease(c.hATR_M15);
   if(c.hADX_M5!=INVALID_HANDLE) IndicatorRelease(c.hADX_M5);
   if(c.hRSI_M5!=INVALID_HANDLE) IndicatorRelease(c.hRSI_M5);
   if(c.hRSI_M1!=INVALID_HANDLE) IndicatorRelease(c.hRSI_M1);
   if(c.hMACD_M5!=INVALID_HANDLE) IndicatorRelease(c.hMACD_M5);
   if(c.hBands_M5!=INVALID_HANDLE) IndicatorRelease(c.hBands_M5);
   if(c.hStoch_M5!=INVALID_HANDLE) IndicatorRelease(c.hStoch_M5);
   if(c.hADX_M15!=INVALID_HANDLE) IndicatorRelease(c.hADX_M15);
   c.initialized=false;
}

void ParseSymbols()
{
   string parts[];
   ushort sep=(ushort)StringGetCharacter(",",0);
   int n=StringSplit(InpSymbols,sep,parts);
   g_symbolCount=0;
   for(int i=0;i<n && g_symbolCount<UF_MAX_SYMBOLS;i++)
   {
      string sym=TrimStr(parts[i]); if(sym=="") continue;
      bool duplicate=false;
      for(int j=0;j<g_symbolCount;j++) if(g_ctx[j].symbol==sym) duplicate=true;
      if(duplicate) continue;
      if(InitContext(g_ctx[g_symbolCount],sym))
      {
         LogAction("SYMBOL READY "+sym);
         g_symbolCount++;
      }
      else
      {
         LogAction("SYMBOL SKIP "+sym+" (select/data/indicator unavailable)");
      }
   }
   g_focusIndex=FocusIndex();
}

//=====================================================================
// DASHBOARD
//=====================================================================
void DashRect(string name,int x,int y,int w,int h,color bg)
{
   string n=UF_DASH+name;
   if(ObjectFind(0,n)<0) ObjectCreate(0,n,OBJ_RECTANGLE_LABEL,0,0,0);
   ObjectSetInteger(0,n,OBJPROP_CORNER,CORNER_LEFT_UPPER);
   ObjectSetInteger(0,n,OBJPROP_XDISTANCE,x); ObjectSetInteger(0,n,OBJPROP_YDISTANCE,y);
   ObjectSetInteger(0,n,OBJPROP_XSIZE,w); ObjectSetInteger(0,n,OBJPROP_YSIZE,h);
   ObjectSetInteger(0,n,OBJPROP_BGCOLOR,bg); ObjectSetInteger(0,n,OBJPROP_BORDER_COLOR,UF_BORDER);
   ObjectSetInteger(0,n,OBJPROP_SELECTABLE,false); ObjectSetInteger(0,n,OBJPROP_HIDDEN,true);
}

void DashText(string name,string text,int x,int y,int size,color col,bool bold=false)
{
   string n=UF_DASH+name;
   if(ObjectFind(0,n)<0) ObjectCreate(0,n,OBJ_LABEL,0,0,0);
   ObjectSetInteger(0,n,OBJPROP_CORNER,CORNER_LEFT_UPPER);
   ObjectSetInteger(0,n,OBJPROP_XDISTANCE,x); ObjectSetInteger(0,n,OBJPROP_YDISTANCE,y);
   ObjectSetInteger(0,n,OBJPROP_FONTSIZE,size); ObjectSetInteger(0,n,OBJPROP_COLOR,col);
   ObjectSetInteger(0,n,OBJPROP_SELECTABLE,false); ObjectSetInteger(0,n,OBJPROP_HIDDEN,true);
   ObjectSetString(0,n,OBJPROP_FONT,bold?"Arial Bold":"Arial");
   ObjectSetString(0,n,OBJPROP_TEXT,text);
}

void InitDashboard()
{
   if(!InpShowDashboard) return;
   DashRect("BG",InpDashX,InpDashY,InpDashWidth,InpDashHeight,UF_BG);
   DashRect("HEAD",InpDashX+8,InpDashY+8,InpDashWidth-16,48,UF_PANEL2);
   DashRect("MASTER",InpDashX+8,InpDashY+64,InpDashWidth-16,82,UF_PANEL);
   DashRect("SYMS",InpDashX+8,InpDashY+154,355,525,UF_PANEL);
   DashRect("ENG",InpDashX+372,InpDashY+154,484,525,UF_PANEL);
   DashRect("LOG",InpDashX+864,InpDashY+154,308,525,UF_PANEL);
   DashText("title",InpBotName+"  |  10-ENGINE ADAPTIVE FUSION",InpDashX+20,InpDashY+18,15,UF_WHITE,true);
   DashText("subtitle","Gold + FX + Indices | Multi-symbol | Auto execution | regime-aware",InpDashX+20,InpDashY+39,9,UF_MUTED,false);
   ChartRedraw(0);
}

void UpdateDashboard()
{
   if(!InpShowDashboard) return;
   g_focusIndex=FocusIndex();
   int fx=g_focusIndex;
   if(fx<0 || fx>=g_symbolCount) fx=0;
   UFContext c=g_ctx[fx];
   double eq=AccountInfoDouble(ACCOUNT_EQUITY), bal=AccountInfoDouble(ACCOUNT_BALANCE);
   double dayDD=100.0*(g_dayStartEquity-eq)/MathMax(0.01,g_dayStartEquity);
   double weekDD=100.0*(g_weekStartEquity-eq)/MathMax(0.01,g_weekStartEquity);
   double maxDD=100.0*(g_peakEquity-eq)/MathMax(0.01,g_peakEquity);
   int opens=OpenManagedPositions();

   DashText("acct",StringFormat("BAL %.2f   EQ %.2f   DAY %.2f%%   WEEK %.2f%%   MAXDD %.2f%%   POS %d/%d",bal,eq,dayDD,weekDD,maxDD,opens,InpMaxPositions),InpDashX+20,InpDashY+68,10,UF_WHITE,true);
   DashText("news","NEWS: "+(g_globalNews==UF_NEWS_BLOCK?"BLOCK":(g_globalNews==UF_NEWS_CAUTION?"CAUTION":"NORMAL"))+" | "+Shorten(g_newsReason,95),InpDashX+20,InpDashY+88,9,(g_globalNews==UF_NEWS_BLOCK?UF_RED:(g_globalNews==UF_NEWS_CAUTION?UF_ORANGE:UF_GREEN)),false);
   DashText("master","FOCUS "+c.symbol+"   "+DirStr(c.fusionDirection)+"   SCORE "+DoubleToString(c.fusionScore,1)+"   RR "+DoubleToString(c.fusionRR,2)+"   REGIME "+RegimeStr(c.regime)+" "+DoubleToString(c.regimeScore,0)+"%",InpDashX+20,InpDashY+112,11,c.fusionScore>=InpMinFusionScore?UF_GREEN:UF_GOLD,true);

   // SYMBOL MATRIX
   DashText("syh","SYMBOL MATRIX",InpDashX+22,InpDashY+166,11,UF_CYAN,true);
   DashText("sycols","SYMBOL        DIR   SCORE   REGIME        SPR   VOTES    ACTION",InpDashX+18,InpDashY+188,8,UF_MUTED,true);
   for(int i=0;i<MathMin(g_symbolCount,16);i++)
   {
      UFContext x=g_ctx[i];
      color cc=x.fusionDirection==UF_LONG?UF_GREEN:(x.fusionDirection==UF_SHORT?UF_RED:UF_MUTED);
      if(i==fx) cc=UF_GOLD;
      string act=Shorten(x.action,25);
      string row=StringFormat("%-11s %-4s %5.1f  %-12s %5.0f  %d/%d    %s",x.symbol,DirStr(x.fusionDirection),x.fusionScore,RegimeStr(x.regime),x.spreadPoints,x.longVotes,x.shortVotes,act);
      DashText("s"+IntegerToString(i),row,InpDashX+18,InpDashY+206+i*24,8,cc,i==fx);
   }

   // ENGINE PANEL
   DashText("eh","FOCUS ENGINE COUNCIL: "+c.symbol,InpDashX+386,InpDashY+166,11,UF_CYAN,true);
   DashText("ecols","ENGINE                       DIR     SCORE     STATUS",InpDashX+380,InpDashY+188,8,UF_MUTED,true);
   int ey=206;
   for(int i=0;i<UF_STRATEGY_COUNT;i++)
   {
      UFSignal s=c.signals[i];
      bool good=s.valid;
      color cc=s.direction==UF_LONG?UF_GREEN:(s.direction==UF_SHORT?UF_RED:UF_MUTED);
      string st=good?"SIGNAL":"NO SETUP";
      string row=StringFormat("%-28s %-5s %6.1f  %-9s",StrategyStr((ENUM_UF_STRATEGY)i),DirStr(s.direction),s.score,st);
      DashText("e"+IntegerToString(i),row,InpDashX+380,InpDashY+ey,8,cc,false);
      if(InpShowEngineReasons)
         DashText("er"+IntegerToString(i),Shorten(s.reason,InpReasonChars),InpDashX+524,InpDashY+ey,7,UF_MUTED,false);
      ey+=32;
   }
   DashText("fuse","FUSION: "+c.fusionReason,InpDashX+380,InpDashY+ey+4,9,UF_GOLD,true);
   DashText("stops","ENTRY "+DoubleToString(c.fusionEntry,SymbolDigits(c.symbol))+" | SL "+DoubleToString(c.fusionSL,SymbolDigits(c.symbol))+" | TP "+DoubleToString(c.fusionTP,SymbolDigits(c.symbol)),InpDashX+380,InpDashY+ey+24,8,UF_WHITE,false);
   DashText("action","ACTION: "+Shorten(c.action,85),InpDashX+380,InpDashY+ey+44,8,c.action!="" && StringFind(c.action,"QUALIFIED")>=0?UF_GREEN:UF_ORANGE,true);

   // LOG PANEL
   DashText("lh","LIVE ACTION / EVENT LOG",InpDashX+878,InpDashY+166,11,UF_CYAN,true);
   for(int i=0;i<UF_MAX_LOG;i++)
   {
      string txt=(i<g_actionCount?Shorten(g_actionLog[i],48):"");
      DashText("l"+IntegerToString(i),txt,InpDashX+872,InpDashY+190+i*26,7,(i==0?UF_WHITE:UF_MUTED),i==0);
   }
   double wr=(g_sessionWins+g_sessionLosses>0?100.0*g_sessionWins/(g_sessionWins+g_sessionLosses):0);
   DashText("perf","SESSION WR "+DoubleToString(wr,1)+"%  P&L "+DoubleToString(g_sessionProfit,2),InpDashX+872,InpDashY+566,9,wr>=55?UF_GREEN:UF_GOLD,true);
   DashText("stats","DAYTRADES "+IntegerToString(g_dayTrades)+"/"+IntegerToString(InpMaxDailyTrades)+" | CAND "+IntegerToString(g_totalCandidates)+" | EXEC "+IntegerToString(g_totalExecuted)+" | FAIL "+IntegerToString(g_totalOrdersFailed)+" | NEWS "+(g_globalNews==UF_NEWS_BLOCK?"BLOCK":"OK"),InpDashX+872,InpDashY+588,8,UF_MUTED,false);

   // HEALTH FOOTER
   for(int i=0;i<UF_STRATEGY_COUNT;i++)
   {
      UFHealth h=g_health[i];
      string label=Shorten(StrategyStr((ENUM_UF_STRATEGY)i),14)+" "+DoubleToString(h.winRate,0)+"%/"+DoubleToString(h.expectancyR,2)+"R";
      color hc=h.enabled?UF_GREEN:UF_RED;
      DashText("h"+IntegerToString(i),label,InpDashX+20+(i%5)*165,InpDashY+650+(i/5)*18,7,hc,false);
   }
   ChartRedraw(0);
}

void DeleteDashboard()
{
   ObjectsDeleteAll(0,UF_DASH);
}

//=====================================================================
// CHART INTELLIGENCE OVERLAYS
//=====================================================================
void TrendLine(string name,double price,color col,ENUM_LINE_STYLE style=STYLE_SOLID,int width=1)
{
   string n=UF_OV+name;
   ObjectDelete(0,n);
   if(ObjectCreate(0,n,OBJ_HLINE,0,0,price))
   {
      ObjectSetInteger(0,n,OBJPROP_COLOR,col);
      ObjectSetInteger(0,n,OBJPROP_STYLE,style);
      ObjectSetInteger(0,n,OBJPROP_WIDTH,width);
      ObjectSetInteger(0,n,OBJPROP_SELECTABLE,false);
      ObjectSetInteger(0,n,OBJPROP_HIDDEN,true);
   }
}

void UpdateChartLevels()
{
   if(!InpShowChartLevels) return;
   int fx=FocusIndex(); if(fx<0 || fx>=g_symbolCount) return;
   UFContext c=g_ctx[fx];
   if(c.symbol!=_Symbol) return;
   TrendLine("VWAP",c.vwap,UF_CYAN,STYLE_DASHDOT,1);
   TrendLine("PDH",c.prevDayHigh,UF_RED,STYLE_DASH,1);
   TrendLine("PDL",c.prevDayLow,UF_GREEN,STYLE_DASH,1);
   TrendLine("SESH",c.sessionHigh,UF_ORANGE,STYLE_DOT,1);
   TrendLine("SESL",c.sessionLow,UF_ORANGE,STYLE_DOT,1);
   if(c.fusionDirection!=UF_NONE && c.fusionEntry>0)
   {
      TrendLine("ENTRY",c.fusionEntry,UF_GOLD,STYLE_SOLID,2);
      TrendLine("SL",c.fusionSL,UF_RED,STYLE_SOLID,2);
      TrendLine("TP",c.fusionTP,UF_GREEN,STYLE_SOLID,2);
   }
}

void DeleteChartLevels()
{
   ObjectsDeleteAll(0,UF_OV);
}

//=====================================================================
// PER-SYMBOL SCAN
//=====================================================================
void ScanContext(UFContext &c,bool force)
{
   if(!c.initialized || !c.enabled) return;
   bool newbar=IsNewBarForContext(c);
   if(!force && !newbar) return;
   UpdateState(c);
   RunAllEngines(c);
   c.lastScan=TimeCurrent();

   UFDecision d;
   d.approved=false; d.symbol=c.symbol; d.direction=UF_NONE; d.source=UF_TREND_CONTINUATION;
   d.score=0;d.entry=0;d.sl=0;d.tp=0;d.rr=0;d.riskPct=0;d.riskMoney=0;d.lots=0;d.reason="";

   if(InpExecutionMode==UF_EXEC_FUSED_QUALIFIED)
   {
      if(c.fusionScore>=InpMinFusionScore && c.validVotes>=InpMinEngineAgreement && c.fusionDirection!=UF_NONE)
         d=BuildDecision(c);
      else
      {
         d.symbol=c.symbol; d.direction=c.fusionDirection; d.score=c.fusionScore; d.reason=c.action;
      }
   }
   else
   {
      // Direct-engine mode: every valid engine setup is immediately converted to a trade
      // only after the common risk/execution gate. The strongest same-bar engine is used
      // to prevent ten simultaneous entries on the same symbol from one market event.
      int best=-1; double bestScore=-1;
      for(int i=0;i<UF_STRATEGY_COUNT;i++)
      {
         if(!StrategyEnabled((ENUM_UF_STRATEGY)i)) continue;
         if(!c.signals[i].valid) continue;
         if(c.signals[i].score>bestScore){best=i;bestScore=c.signals[i].score;}
      }
      if(best>=0)
      {
         UFSignal s=c.signals[best];
         d.symbol=c.symbol; d.direction=s.direction; d.source=s.strategy; d.score=s.score;
         d.entry=s.entry; d.sl=s.sl; d.tp=s.tp;
         EnforceStopGeometry(c.symbol,d.direction,d.entry,d.sl,d.tp);
         d.rr=MathAbs(d.tp-d.entry)/MathMax(PointValue(c.symbol),MathAbs(d.entry-d.sl));
         d.riskPct=InpRiskPercent;
         d.reason="DIRECT "+StrategyStr(s.strategy)+" | "+s.reason;
         string rg="";
         if(RiskGate(rg) && d.score>=InpMinFusionScore && !HasManagedPosition(c.symbol,UF_NONE) && c.news!=UF_NEWS_BLOCK && c.spreadPoints<=InpMaxSpreadPoints)
         {
            d.riskPct=MathMin(InpMaxRiskPercentTrade,d.riskPct);
            if(RiskForStops(c.symbol,d.entry,d.sl,d.lots,d.riskMoney,d.riskPct)) d.approved=true;
            else d.reason="Direct setup rejected by position sizing";
         }
         else
            d.reason=(rg!=""?rg:"Direct engine execution gate blocked");
      }
      else
         d.reason="No valid engine setup";
   }

   if(d.approved)
   {
      g_totalCandidates++;
      if(ExecuteDecision(d))
      {
         c.action="EXECUTED "+DirStr(d.direction)+" @ "+DoubleToString(d.entry,SymbolDigits(c.symbol));
         c.fusionDirection=d.direction;c.fusionScore=d.score;c.fusionEntry=d.entry;c.fusionSL=d.sl;c.fusionTP=d.tp;c.fusionRR=d.rr;
         c.fusionReason=d.reason;
         g_lastDecision=d;
      }
      else
      {
         c.action="ORDER FAILURE";
      }
   }
   else
   {
      if((c.fusionScore>=InpMinFusionScore && c.fusionDirection!=UF_NONE) || InpExecutionMode==UF_EXEC_ANY_VALID_ENGINE)
      {
         g_totalBlocked++;
         c.action="BLOCKED: "+Shorten(d.reason,70);
         LogAction("BLOCK "+c.symbol+" | "+d.reason);
      }
      else
         c.action=(c.action==""?d.reason:c.action);
   }
}

//=====================================================================
// MASTER TIMER / EVENTS
//=====================================================================
void ApplyBlackTheme()
{
   if(!InpBlackTheme) return;
   ChartSetInteger(0,CHART_COLOR_BACKGROUND,clrBlack);
   ChartSetInteger(0,CHART_COLOR_FOREGROUND,UF_WHITE);
   ChartSetInteger(0,CHART_COLOR_GRID,clrBlack);
   ChartSetInteger(0,CHART_SHOW_GRID,false);
}

int OnInit()
{
   g_trade.SetExpertMagicNumber(InpMagicNumber);
   g_trade.SetDeviationInPoints(InpDeviationPoints);
   g_trade.SetAsyncMode(false);
   ApplyBlackTheme();
   InitHealth();
   g_dayStart=DayStart(TimeCurrent());
   g_weekStart=WeekStart(TimeCurrent());
   g_dayStartEquity=AccountInfoDouble(ACCOUNT_EQUITY);
   g_weekStartEquity=g_dayStartEquity;
   g_peakEquity=g_dayStartEquity;
   g_lastDecision.approved=false;
   g_lastDecision.symbol="";g_lastDecision.direction=UF_NONE;g_lastDecision.source=UF_TREND_CONTINUATION;g_lastDecision.score=0;g_lastDecision.entry=0;g_lastDecision.sl=0;g_lastDecision.tp=0;g_lastDecision.rr=0;g_lastDecision.riskPct=0;g_lastDecision.riskMoney=0;g_lastDecision.lots=0;g_lastDecision.reason="Starting";

   ParseSymbols();
   if(g_symbolCount<=0)
   {
      Print("[UF10] No usable symbols. Check InpSymbols and broker symbol names.");
      return INIT_FAILED;
   }
   if(InpShowDashboard) InitDashboard();
   EventSetMillisecondTimer(MathMax(250,InpDashRefreshMs));
   LogAction("ULTRAFUSION X10 v2.0 INITIALIZED | symbols="+IntegerToString(g_symbolCount));
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
   EventKillTimer();
   for(int i=0;i<g_symbolCount;i++) ReleaseContext(g_ctx[i]);
   DeleteDashboard();
   DeleteChartLevels();
}

void OnTimer()
{
   UpdateRiskState();
   UpdateGlobalNews();
   EmergencyFlatten();
   ManagePositions();

   if(!g_emergency)
   {
      for(int i=0;i<g_symbolCount;i++)
      {
         bool force=(g_ctx[i].lastScan==0);
         ScanContext(g_ctx[i],force);
      }
   }
   UpdateChartLevels();
   UpdateDashboard();
}

void OnTick()
{
   // Multi-symbol work happens on the timer so one chart can supervise the full universe.
   // Tick remains lightweight and updates risk/equity state without duplicating scans.
   UpdateRiskState();
   if(g_emergency) EmergencyFlatten();
}

void OnTradeTransaction(const MqlTradeTransaction &trans,
                        const MqlTradeRequest &request,
                        const MqlTradeResult &result)
{
   OnClosedDeal(trans);
}
//+------------------------------------------------------------------+
