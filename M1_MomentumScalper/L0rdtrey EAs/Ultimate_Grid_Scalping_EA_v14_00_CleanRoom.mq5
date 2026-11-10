//+------------------------------------------------------------------+
//| Ultimate Grid Scalping EA v14.00 - Clean-Room Institutional Core |
//| Independent architecture: command bus, ownership registry,      |
//| execution authority, lifecycle state machine and telemetry.      |
//+------------------------------------------------------------------+
#property strict
#property version   "14.00"
#property description "Clean-room grid scalping architecture with 21 strategy profiles."

#include <Trade/Trade.mqh>

CTrade Trade;

#define UGS_VERSION "14.00"
#define UGS_PREFIX  "UGS14_"
#define MAX_LEVELS  32
#define PROFILE_COUNT 21
#define JOURNAL_CAP 128

//------------------------- ENUMERATIONS ------------------------------
enum UGS_CONTROL_MODE { UGS_MANUAL=0, UGS_ASSIST=1, UGS_AUTONOMOUS=2 };
enum UGS_GRID_PROFILE
{
   UGS_BASIC=0, UGS_HEDGE, UGS_TREND, UGS_VOLATILITY, UGS_AI,
   UGS_GEOMETRIC, UGS_FIBONACCI, UGS_ATR_ADAPTIVE, UGS_MEAN_REVERSION,
   UGS_BREAKOUT, UGS_MOMENTUM, UGS_HYBRID, UGS_BULLISH, UGS_BEARISH,
   UGS_BIDIRECTIONAL, UGS_LADDER, UGS_ANTI_MARTINGALE, UGS_RANGE_SCALING,
   UGS_VOLATILITY_BREAKOUT, UGS_SESSION, UGS_SMART_REGIME
};
enum UGS_GRID_STATE { STATE_IDLE=0, STATE_AUTHORIZED, STATE_BUILDING, STATE_ACTIVE,
                      STATE_REBALANCING, STATE_EXITING, STATE_RECOVERY, STATE_HALTED };
enum UGS_REQUEST_KIND { REQ_NONE=0, REQ_START, REQ_STOP, REQ_REBUILD, REQ_CLOSE_OWNED,
                        REQ_CANCEL_OWNED, REQ_EMERGENCY };
enum UGS_SPACING_MODE { SPACE_FIXED=0, SPACE_ATR=1, SPACE_ADAPTIVE=2 };
enum UGS_BASKET_MODE { BASKET_OFF=0, BASKET_PROFIT=1, BASKET_TRAIL=2 };
enum UGS_DECISION_REASON { DECISION_OK=0, DECISION_DISABLED, DECISION_SPREAD,
                           DECISION_SESSION, DECISION_RISK, DECISION_MARGIN,
                           DECISION_LIMIT, DECISION_VOLATILITY, DECISION_REGIME,
                           DECISION_COOLDOWN, DECISION_ALREADY_ACTIVE };

struct UGS_Config
{
   UGS_CONTROL_MODE control;
   UGS_GRID_PROFILE profile;
   UGS_SPACING_MODE spacingMode;
   int levels;
   double stepPips;
   double atrMultiplier;
   double minStepPips;
   double maxStepPips;
   double lotSize;
   double lotMultiplier;
   double maxLots;
   int maxPositions;
   int maxPending;
   double scalpTPPips;
   double individualSLPips;
   double basketTargetMoney;
   double basketStopMoney;
   double basketTrailMoney;
   UGS_BASKET_MODE basketMode;
   bool useIndividualTP;
   bool useIndividualSL;
   bool useRecenter;
   double recenterDistancePips;
   bool useReplenishment;
   bool useAdaptiveLevels;
   bool useAdaptiveLots;
   bool useSpreadGate;
   double maxSpreadPips;
   bool useSessionGate;
   int sessionStartHour;
   int sessionEndHour;
   bool autonomousEntryGate;
   double autonomousScoreThreshold;
   int cooldownSeconds;
   double maxEquityDrawdownPct;
   double maxMarginPct;
   bool emergencyFlatten;
   bool preserveExternalTrades;
   bool showDashboard;
   int dashboardWidthPct;
};

struct UGS_Runtime
{
   UGS_GRID_STATE state;
   long instanceId;
   long cycleId;
   long sequence;
   double anchor;
   double activeStep;
   double effectiveLot;
   double equityPeak;
   double dayStartEquity;
   double basketPeak;
   datetime cycleStart;
   datetime lastAction;
   datetime cooldownUntil;
   datetime lastTick;
   int ownedPositions;
   int ownedPending;
   double ownedProfit;
   double ownedLots;
   double spreadPips;
   double atrPips;
   double volatilityScore;
   double trendScore;
   double autonomyScore;
   string lastAction;
   string lastReason;
   string emergencyReason;
   bool emergency;
};

struct UGS_Request
{
   UGS_REQUEST_KIND kind;
   long requestId;
   datetime created;
   string actor;
   string reason;
};

struct UGS_Audit
{
   long id;
   datetime when;
   string actor;
   string event;
   string detail;
};

struct UGS_Level
{
   int index;
   ENUM_ORDER_TYPE type;
   double price;
   double volume;
   bool intended;
   bool placed;
   ulong ticket;
};

//------------------------- INPUTS ------------------------------------
input group "01 | Core Control"
input UGS_CONTROL_MODE InpControlMode = UGS_MANUAL;
input UGS_GRID_PROFILE InpGridProfile = UGS_BASIC;
input bool InpStartOnAttach = false;
input long InpInstanceSeed = 140024;

input group "02 | Grid Construction"
input int InpLevels = 8;
input UGS_SPACING_MODE InpSpacingMode = SPACE_ATR;
input double InpStepPips = 12.0;
input double InpATRMultiplier = 0.18;
input double InpMinStepPips = 5.0;
input double InpMaxStepPips = 80.0;
input bool InpAdaptiveLevels = false;
input bool InpAdaptiveLots = false;
input double InpLotSize = 0.01;
input double InpLotMultiplier = 1.0;
input double InpMaxLots = 1.00;

input group "03 | Scalping"
input bool InpUseIndividualTP = true;
input double InpScalpTPPips = 10.0;
input bool InpUseIndividualSL = false;
input double InpIndividualSLPips = 50.0;
input UGS_BASKET_MODE InpBasketMode = BASKET_PROFIT;
input double InpBasketTargetMoney = 5.0;
input double InpBasketStopMoney = 0.0;
input double InpBasketTrailMoney = 0.0;
input bool InpReplenishment = true;
input int InpCooldownSeconds = 2;

input group "04 | Risk Authority"
input int InpMaxPositions = 16;
input int InpMaxPending = 32;
input double InpMaxEquityDrawdownPct = 20.0;
input double InpMaxMarginPct = 65.0;
input bool InpEmergencyFlatten = false;
input bool InpPreserveExternalTrades = true;

input group "05 | Market Gates"
input bool InpUseSpreadGate = true;
input double InpMaxSpreadPips = 5.0;
input bool InpUseSessionGate = false;
input int InpSessionStartHour = 0;
input int InpSessionEndHour = 23;

input group "06 | Autonomous Intelligence"
input bool InpAutonomousEntryGate = true;
input double InpAutonomousScoreThreshold = 55.0;
input bool InpUseRecenter = true;
input double InpRecenterDistancePips = 45.0;

input group "07 | Dashboard"
input bool InpShowDashboard = true;
input int InpDashboardWidthPct = 50;

//------------------------- GLOBALS -----------------------------------
UGS_Config Cfg;
UGS_Runtime Rt;
UGS_Request PendingReq;
UGS_Audit Journal[JOURNAL_CAP];
UGS_Level Levels[MAX_LEVELS];

int JournalCount=0;
int atrHandle=INVALID_HANDLE;
int maHandle=INVALID_HANDLE;
int rsiHandle=INVALID_HANDLE;
string Root;
string DashboardName;
bool ObjectsReady=false;

//------------------------- UTILITY -----------------------------------
string ProfileName(UGS_GRID_PROFILE p)
{
   string a[PROFILE_COUNT]={
      "Basic Grid","Hedge Grid","Trend Grid","Volatility Grid","AI Grid",
      "Geometric Grid","Fibonacci Grid","ATR Adaptive Grid","Mean-Reversion Grid",
      "Breakout Grid","Momentum Grid","Hybrid Smart Grid","Bullish Grid",
      "Bearish Grid","Bidirectional Grid","Ladder Grid","Anti-Martingale Grid",
      "Range-Scaling Grid","Volatility-Breakout Grid","Session Grid","Smart-Regime Grid"};
   if((int)p<0 || (int)p>=PROFILE_COUNT) return "Unknown";
   return a[(int)p];
}
string StateName(UGS_GRID_STATE s)
{
   switch(s)
   {
      case STATE_IDLE:return "IDLE"; case STATE_AUTHORIZED:return "AUTHORIZED";
      case STATE_BUILDING:return "BUILDING"; case STATE_ACTIVE:return "ACTIVE";
      case STATE_REBALANCING:return "REBALANCING"; case STATE_EXITING:return "EXITING";
      case STATE_RECOVERY:return "RECOVERY"; case STATE_HALTED:return "HALTED";
   }
   return "UNKNOWN";
}
string RequestName(UGS_REQUEST_KIND k)
{
   switch(k)
   {
      case REQ_START:return "START"; case REQ_STOP:return "STOP"; case REQ_REBUILD:return "REBUILD";
      case REQ_CLOSE_OWNED:return "CLOSE OWNED"; case REQ_CANCEL_OWNED:return "CANCEL OWNED";
      case REQ_EMERGENCY:return "EMERGENCY";
   }
   return "NONE";
}
double PipSize()
{
   double pt=SymbolInfoDouble(_Symbol,SYMBOL_POINT);
   int d=(int)SymbolInfoInteger(_Symbol,SYMBOL_DIGITS);
   return (d==3 || d==5) ? pt*10.0 : pt;
}
double PipsToPrice(double p){ return p*PipSize(); }
double PriceToPips(double d){ double p=PipSize(); return p>0 ? d/p : 0; }
double NormalizePrice(double p){ return NormalizeDouble(p,(int)SymbolInfoInteger(_Symbol,SYMBOL_DIGITS)); }
double NormalizeVolume(double v)
{
   double mn=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN);
   double mx=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MAX);
   double st=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_STEP);
   if(mn<=0) mn=0.01; if(mx<=0) mx=100.0; if(st<=0) st=mn;
   v=MathMax(mn,MathMin(mx,v));
   v=MathFloor(v/st+1e-9)*st;
   return NormalizeDouble(v,2);
}
double Bid(){return SymbolInfoDouble(_Symbol,SYMBOL_BID);}
double Ask(){return SymbolInfoDouble(_Symbol,SYMBOL_ASK);}
double Mid(){return (Bid()+Ask())*0.5;}
double SpreadPips(){return PriceToPips(Ask()-Bid());}
string Obj(string suffix){return Root+suffix;}
bool IsOwnedMagic(long magic){return magic==(long)Rt.instanceId;}
bool IsOurComment(string c){return StringFind(c,Root)==0;}
bool IsOwnedPosition(ulong ticket)
{
   if(ticket==0 || !PositionSelectByTicket(ticket)) return false;
   if(PositionGetString(POSITION_SYMBOL)!=_Symbol) return false;
   long m=PositionGetInteger(POSITION_MAGIC);
   string c=PositionGetString(POSITION_COMMENT);
   return IsOwnedMagic(m) && IsOurComment(c);
}
bool IsOwnedOrder(ulong ticket)
{
   if(ticket==0 || !OrderSelect(ticket)) return false;
   if(OrderGetString(ORDER_SYMBOL)!=_Symbol) return false;
   long m=OrderGetInteger(ORDER_MAGIC);
   string c=OrderGetString(ORDER_COMMENT);
   return IsOwnedMagic(m) && IsOurComment(c);
}
int OwnedPositionCount()
{
   int n=0;
   for(int i=0;i<PositionsTotal();i++) if(IsOwnedPosition(PositionGetTicket(i))) n++;
   return n;
}
int OwnedPendingCount()
{
   int n=0;
   for(int i=0;i<OrdersTotal();i++) if(IsOwnedOrder(OrderGetTicket(i))) n++;
   return n;
}
double OwnedProfit()
{
   double x=0;
   for(int i=0;i<PositionsTotal();i++)
   {
      ulong t=PositionGetTicket(i);
      if(IsOwnedPosition(t)) x+=PositionGetDouble(POSITION_PROFIT)+PositionGetDouble(POSITION_SWAP);
   }
   return x;
}
double OwnedLots()
{
   double x=0;
   for(int i=0;i<PositionsTotal();i++)
   {
      ulong t=PositionGetTicket(i);
      if(IsOwnedPosition(t)) x+=PositionGetDouble(POSITION_VOLUME);
   }
   return x;
}
void RefreshOwnership()
{
   Rt.ownedPositions=OwnedPositionCount();
   Rt.ownedPending=OwnedPendingCount();
   Rt.ownedProfit=OwnedProfit();
   Rt.ownedLots=OwnedLots();
   Rt.spreadPips=SpreadPips();
}
void Audit(string actor,string eventName,string detail)
{
   if(JournalCount<JOURNAL_CAP)
   {
      Journal[JournalCount].id=++Rt.sequence;
      Journal[JournalCount].when=TimeCurrent();
      Journal[JournalCount].actor=actor;
      Journal[JournalCount].event=eventName;
      Journal[JournalCount].detail=detail;
      JournalCount++;
   }
   else
   {
      for(int i=1;i<JOURNAL_CAP;i++) Journal[i-1]=Journal[i];
      Journal[JOURNAL_CAP-1].id=++Rt.sequence;
      Journal[JOURNAL_CAP-1].when=TimeCurrent();
      Journal[JOURNAL_CAP-1].actor=actor;
      Journal[JOURNAL_CAP-1].event=eventName;
      Journal[JOURNAL_CAP-1].detail=detail;
   }
}
void SetState(UGS_GRID_STATE s,string reason)
{
   if(Rt.state!=s)
   {
      Audit("LIFECYCLE","STATE",StateName(Rt.state)+" -> "+StateName(s)+" | "+reason);
      Rt.state=s;
   }
   Rt.lastAction=StateName(s);
   Rt.lastReason=reason;
}
void LoadConfig()
{
   Cfg.control=InpControlMode; Cfg.profile=InpGridProfile;
   Cfg.spacingMode=InpSpacingMode; Cfg.levels=MathMax(1,MathMin(MAX_LEVELS,InpLevels));
   Cfg.stepPips=MathMax(0.1,InpStepPips); Cfg.atrMultiplier=MathMax(0.01,InpATRMultiplier);
   Cfg.minStepPips=MathMax(0.1,InpMinStepPips); Cfg.maxStepPips=MathMax(Cfg.minStepPips,InpMaxStepPips);
   Cfg.lotSize=NormalizeVolume(InpLotSize); Cfg.lotMultiplier=MathMax(0.1,InpLotMultiplier);
   Cfg.maxLots=MathMax(Cfg.lotSize,InpMaxLots); Cfg.maxPositions=MathMax(1,InpMaxPositions);
   Cfg.maxPending=MathMax(1,InpMaxPending); Cfg.scalpTPPips=MathMax(0.1,InpScalpTPPips);
   Cfg.individualSLPips=MathMax(0.0,InpIndividualSLPips); Cfg.basketMode=InpBasketMode;
   Cfg.basketTargetMoney=MathMax(0.0,InpBasketTargetMoney); Cfg.basketStopMoney=MathMax(0.0,InpBasketStopMoney);
   Cfg.basketTrailMoney=MathMax(0.0,InpBasketTrailMoney); Cfg.useIndividualTP=InpUseIndividualTP;
   Cfg.useIndividualSL=InpUseIndividualSL; Cfg.useReplenishment=InpReplenishment;
   Cfg.useRecenter=InpUseRecenter; Cfg.recenterDistancePips=MathMax(1.0,InpRecenterDistancePips);
   Cfg.useAdaptiveLevels=InpAdaptiveLevels; Cfg.useAdaptiveLots=InpAdaptiveLots;
   Cfg.useSpreadGate=InpUseSpreadGate; Cfg.maxSpreadPips=MathMax(0.1,InpMaxSpreadPips);
   Cfg.useSessionGate=InpUseSessionGate; Cfg.sessionStartHour=MathMax(0,MathMin(23,InpSessionStartHour));
   Cfg.sessionEndHour=MathMax(0,MathMin(23,InpSessionEndHour)); Cfg.autonomousEntryGate=InpAutonomousEntryGate;
   Cfg.autonomousScoreThreshold=MathMax(0,MathMin(100,InpAutonomousScoreThreshold));
   Cfg.cooldownSeconds=MathMax(0,InpCooldownSeconds); Cfg.maxEquityDrawdownPct=MathMax(0.1,InpMaxEquityDrawdownPct);
   Cfg.maxMarginPct=MathMax(1.0,MathMin(99.0,InpMaxMarginPct)); Cfg.emergencyFlatten=InpEmergencyFlatten;
   Cfg.preserveExternalTrades=InpPreserveExternalTrades; Cfg.showDashboard=InpShowDashboard;
   Cfg.dashboardWidthPct=MathMax(35,MathMin(65,InpDashboardWidthPct));
}
double CurrentATRPrice()
{
   if(atrHandle==INVALID_HANDLE) return 0;
   double b[]; ArraySetAsSeries(b,true);
   if(CopyBuffer(atrHandle,0,0,1,b)!=1) return 0;
   return b[0];
}
double TrendScore()
{
   if(maHandle==INVALID_HANDLE) return 50;
   double b[]; ArraySetAsSeries(b,true);
   if(CopyBuffer(maHandle,0,0,3,b)<3) return 50;
   double px=Mid(), atr=CurrentATRPrice();
   if(atr<=0) return 50;
   double slope=(b[0]-b[2])/atr;
   return MathMax(0,MathMin(100,50+slope*30));
}
double VolatilityScore()
{
   double atr=CurrentATRPrice(), px=Mid();
   if(atr<=0 || px<=0) return 50;
   return MathMax(0,MathMin(100,(atr/px)*10000));
}
double RSIValue()
{
   if(rsiHandle==INVALID_HANDLE) return 50;
   double b[]; ArraySetAsSeries(b,true);
   if(CopyBuffer(rsiHandle,0,0,1,b)!=1) return 50;
   return b[0];
}
bool SessionAllowed()
{
   if(!Cfg.useSessionGate) return true;
   MqlDateTime tm; TimeToStruct(TimeCurrent(),tm);
   if(Cfg.sessionStartHour<=Cfg.sessionEndHour)
      return tm.hour>=Cfg.sessionStartHour && tm.hour<=Cfg.sessionEndHour;
   return tm.hour>=Cfg.sessionStartHour || tm.hour<=Cfg.sessionEndHour;
}
double AutonomousScore(string &why)
{
   why="";
   if(!SessionAllowed()){why="session gate";return 0;}
   if(Cfg.useSpreadGate && Rt.spreadPips>Cfg.maxSpreadPips){why="spread gate";return 0;}
   double trend=TrendScore(), vol=VolatilityScore(), rsi=RSIValue();
   double score=50.0;
   if(Cfg.profile==UGS_TREND || Cfg.profile==UGS_MOMENTUM || Cfg.profile==UGS_BULLISH || Cfg.profile==UGS_BEARISH)
      score += MathAbs(trend-50)*0.8;
   else if(Cfg.profile==UGS_MEAN_REVERSION || Cfg.profile==UGS_RANGE_SCALING)
      score += MathAbs(rsi-50)*0.8;
   else score += MathMin(20,MathAbs(vol-50)*0.4);
   score=MathMax(0,MathMin(100,score));
   if(score<Cfg.autonomousScoreThreshold) why="score below threshold";
   return score;
}
bool RiskAllows(string &why)
{
   double eq=AccountInfoDouble(ACCOUNT_EQUITY);
   if(Rt.equityPeak>0)
   {
      double dd=(Rt.equityPeak-eq)/Rt.equityPeak*100.0;
      if(dd>=Cfg.maxEquityDrawdownPct){why="equity drawdown";return false;}
   }
   if(OwnedPositionCount()>=Cfg.maxPositions){why="position limit";return false;}
   if(OwnedPendingCount()>=Cfg.maxPending){why="pending limit";return false;}
   double margin=AccountInfoDouble(ACCOUNT_MARGIN);
   double equity=MathMax(eq,0.01);
   if(margin/equity*100.0>=Cfg.maxMarginPct){why="margin limit";return false;}
   return true;
}
bool BrokerDistanceOK(double price,ENUM_ORDER_TYPE type)
{
   double pt=SymbolInfoDouble(_Symbol,SYMBOL_POINT);
   int stops=(int)SymbolInfoInteger(_Symbol,SYMBOL_TRADE_STOPS_LEVEL);
   double minDist=stops*pt;
   if(type==ORDER_TYPE_BUY_STOP || type==ORDER_TYPE_BUY_LIMIT)
      return MathAbs(price-Ask())>=minDist;
   return MathAbs(price-Bid())>=minDist;
}
double EffectiveStep()
{
   double s=Cfg.stepPips;
   if(Cfg.spacingMode==SPACE_ATR)
   {
      double a=CurrentATRPrice();
      if(a>0) s=PriceToPips(a)*Cfg.atrMultiplier;
   }
   else if(Cfg.spacingMode==SPACE_ADAPTIVE)
   {
      double a=CurrentATRPrice();
      if(a>0) s=PriceToPips(a)*Cfg.atrMultiplier;
      double spread=Rt.spreadPips;
      s*=1.0+MathMin(0.5,spread/MathMax(Cfg.maxSpreadPips,0.1)*0.15);
   }
   s=MathMax(Cfg.minStepPips,MathMin(Cfg.maxStepPips,s));
   return s;
}
double LevelVolume(int i)
{
   double v=Cfg.lotSize;
   if(Cfg.useAdaptiveLots)
   {
      double factor=1.0;
      if(Cfg.profile==UGS_ANTI_MARTINGALE) factor=1.0+0.10*i;
      if(Cfg.profile==UGS_GEOMETRIC) factor=MathPow(1.10,i);
      v*=factor;
   }
   else v*=MathPow(Cfg.lotMultiplier,i);
   return MathMin(Cfg.maxLots,NormalizeVolume(v));
}
bool PriceWithinSafetyRadius(double price)
{
   double radius=Cfg.maxStepPips*Cfg.levels*1.5;
   if(radius<Cfg.minStepPips*Cfg.levels) radius=Cfg.minStepPips*Cfg.levels;
   return PriceToPips(MathAbs(price-Rt.anchor))<=radius+0.01;
}
void ClearIntendedLevels()
{
   for(int i=0;i<MAX_LEVELS;i++)
   {
      Levels[i].index=i; Levels[i].price=0; Levels[i].volume=0;
      Levels[i].intended=false; Levels[i].placed=false; Levels[i].ticket=0;
   }
}
void BuildLevels()
{
   ClearIntendedLevels();
   Rt.activeStep=EffectiveStep();
   int n=Cfg.levels;
   if(Cfg.useAdaptiveLevels)
   {
      double v=VolatilityScore();
      if(v>75) n=MathMin(MAX_LEVELS,n+2);
      if(v<25) n=MathMax(2,n-2);
   }
   n=MathMax(1,MathMin(MAX_LEVELS,n));
   bool buyOnly=false,sellOnly=false;
   switch(Cfg.profile)
   {
      case UGS_BULLISH: buyOnly=true; break;
      case UGS_BEARISH: sellOnly=true; break;
      case UGS_TREND:
      case UGS_MOMENTUM:
         { double t=TrendScore(); if(t>=55) buyOnly=true; else if(t<=45) sellOnly=true; else {buyOnly=true;sellOnly=true;} }
         break;
      case UGS_BREAKOUT:
      case UGS_VOLATILITY_BREAKOUT:
         buyOnly=true; sellOnly=true; break;
      default: break;
   }
   int k=0;
   for(int i=1;i<=n && k<MAX_LEVELS;i++)
   {
      double d=PipsToPrice(Rt.activeStep*i);
      double vol=LevelVolume(i-1);
      if(!sellOnly && k<MAX_LEVELS)
      {
         Levels[k].index=i; Levels[k].type=ORDER_TYPE_BUY_STOP;
         Levels[k].price=NormalizePrice(Rt.anchor+d); Levels[k].volume=vol; Levels[k].intended=true; k++;
      }
      if(!buyOnly && k<MAX_LEVELS)
      {
         Levels[k].index=i; Levels[k].type=ORDER_TYPE_SELL_STOP;
         Levels[k].price=NormalizePrice(Rt.anchor-d); Levels[k].volume=vol; Levels[k].intended=true; k++;
      }
   }
}
string OrderComment(int level){return Root+"C"+(string)Rt.cycleId+"L"+(string)level;}
bool SubmitPending(UGS_Level &lv)
{
   if(!lv.intended || lv.price<=0 || lv.volume<=0) return false;
   if(OwnedPendingCount()>=Cfg.maxPending) return false;
   if(!PriceWithinSafetyRadius(lv.price)) {Audit("EXEC","REJECT","radius");return false;}
   if(!BrokerDistanceOK(lv.price,lv.type)) {Audit("EXEC","REJECT","broker distance");return false;}
   string why="";
   if(!RiskAllows(why)){Audit("RISK","BLOCK",why);return false;}
   double sl=0,tp=0;
   if(lv.type==ORDER_TYPE_BUY_STOP)
   {
      if(Cfg.useIndividualTP) tp=NormalizePrice(lv.price+PipsToPrice(Cfg.scalpTPPips));
      if(Cfg.useIndividualSL) sl=NormalizePrice(lv.price-PipsToPrice(Cfg.individualSLPips));
   }
   else
   {
      if(Cfg.useIndividualTP) tp=NormalizePrice(lv.price-PipsToPrice(Cfg.scalpTPPips));
      if(Cfg.useIndividualSL) sl=NormalizePrice(lv.price+PipsToPrice(Cfg.individualSLPips));
   }
   bool ok=false;
   string c=OrderComment(lv.index);
   if(lv.type==ORDER_TYPE_BUY_STOP) ok=Trade.BuyStop(lv.volume,lv.price,_Symbol,sl,tp,ORDER_TIME_GTC,0,c);
   else if(lv.type==ORDER_TYPE_SELL_STOP) ok=Trade.SellStop(lv.volume,lv.price,_Symbol,sl,tp,ORDER_TIME_GTC,0,c);
   if(ok)
   {
      lv.placed=true; lv.ticket=Trade.ResultOrder();
      Audit("EXEC","PLACED",c+" @ "+DoubleToString(lv.price,_Digits));
      return true;
   }
   Audit("EXEC","FAILED",c+" | "+Trade.ResultRetcodeDescription());
   return false;
}
bool OpenMarket(bool buy,double volume,string reason)
{
   string why="";
   if(!RiskAllows(why)){Audit("RISK","BLOCK",why);return false;}
   double sl=0,tp=0,px=buy?Ask():Bid();
   if(Cfg.useIndividualTP) tp=NormalizePrice(buy?px+PipsToPrice(Cfg.scalpTPPips):px-PipsToPrice(Cfg.scalpTPPips));
   if(Cfg.useIndividualSL) sl=NormalizePrice(buy?px-PipsToPrice(Cfg.individualSLPips):px+PipsToPrice(Cfg.individualSLPips));
   string c=Root+"C"+(string)Rt.cycleId+"M";
   bool ok=buy?Trade.Buy(volume,_Symbol,0,sl,tp,c):Trade.Sell(volume,_Symbol,0,sl,tp,c);
   if(ok){Audit("EXEC","MARKET",reason+" "+c);return true;}
   Audit("EXEC","FAILED",Trade.ResultRetcodeDescription()); return false;
}
void CancelOwnedPending()
{
   for(int i=OrdersTotal()-1;i>=0;i--)
   {
      ulong t=OrderGetTicket(i);
      if(IsOwnedOrder(t))
      {
         if(Trade.OrderDelete(t)) Audit("EXEC","DELETE",(string)t);
         else Audit("EXEC","DELETE_FAIL",(string)t+" | "+Trade.ResultRetcodeDescription());
      }
   }
}
void CloseOwnedPositions()
{
   for(int i=PositionsTotal()-1;i>=0;i--)
   {
      ulong t=PositionGetTicket(i);
      if(IsOwnedPosition(t))
      {
         if(Trade.PositionClose(t)) Audit("EXEC","CLOSE",(string)t);
         else Audit("EXEC","CLOSE_FAIL",(string)t+" | "+Trade.ResultRetcodeDescription());
      }
   }
}
void Reconcile()
{
   RefreshOwnership();
   if(Rt.state==STATE_ACTIVE && Rt.ownedPositions==0 && Rt.ownedPending==0)
      SetState(STATE_IDLE,"inventory empty");
}
bool BasketProtection()
{
   RefreshOwnership();
   if(Rt.ownedPositions<=0) return false;
   if(Cfg.basketMode==BASKET_PROFIT && Cfg.basketTargetMoney>0 && Rt.ownedProfit>=Cfg.basketTargetMoney)
   {
      SetState(STATE_EXITING,"basket target");
      CloseOwnedPositions(); CancelOwnedPending(); SetState(STATE_IDLE,"basket closed"); return true;
   }
   if(Cfg.basketStopMoney>0 && Rt.ownedProfit<=-Cfg.basketStopMoney)
   {
      SetState(STATE_EXITING,"basket stop");
      CloseOwnedPositions(); CancelOwnedPending(); SetState(STATE_IDLE,"basket stopped"); return true;
   }
   return false;
}
void Replenish()
{
   if(!Cfg.useReplenishment || Rt.state!=STATE_ACTIVE) return;
   if(TimeCurrent()<Rt.cooldownUntil) return;
   int pending=OwnedPendingCount();
   if(pending>=Cfg.maxPending) return;
   BuildLevels();
   for(int i=0;i<MAX_LEVELS;i++)
      if(Levels[i].intended && !Levels[i].placed) SubmitPending(Levels[i]);
}
void RecenterIfNeeded()
{
   if(!Cfg.useRecenter || Rt.state!=STATE_ACTIVE) return;
   if(Rt.anchor<=0) return;
   double dist=PriceToPips(MathAbs(Mid()-Rt.anchor));
   if(dist<Cfg.recenterDistancePips) return;
   SetState(STATE_REBALANCING,"anchor displacement");
   CancelOwnedPending();
   Rt.anchor=Mid();
   BuildLevels();
   for(int i=0;i<MAX_LEVELS;i++) if(Levels[i].intended) SubmitPending(Levels[i]);
   SetState(STATE_ACTIVE,"recentered");
}
bool StartCycle(string actor)
{
   if(Rt.emergency){Audit(actor,"START_BLOCK","emergency");return false;}
   if(Rt.state!=STATE_IDLE && Rt.state!=STATE_HALTED){Audit(actor,"START_BLOCK","cycle already active");return false;}
   string why="";
   if(Cfg.control==UGS_AUTONOMOUS && Cfg.autonomousEntryGate)
   {
      Rt.autonomyScore=AutonomousScore(why);
      if(Rt.autonomyScore<Cfg.autonomousScoreThreshold){Audit(actor,"AUTO_BLOCK",why);return false;}
   }
   if(Cfg.useSpreadGate && SpreadPips()>Cfg.maxSpreadPips){Audit(actor,"START_BLOCK","spread");return false;}
   if(!SessionAllowed()){Audit(actor,"START_BLOCK","session");return false;}
   if(!RiskAllows(why)){Audit(actor,"START_BLOCK",why);return false;}
   Rt.cycleId=(long)TimeLocal();
   if(Rt.cycleId<=0) Rt.cycleId=1;
   Rt.cycleStart=TimeCurrent(); Rt.anchor=Mid(); Rt.cooldownUntil=0;
   SetState(STATE_AUTHORIZED,"explicit command accepted");
   BuildLevels();
   SetState(STATE_BUILDING,"levels generated");
   int placed=0;
   // Hedge profile intentionally opens the two market legs, then uses pending levels.
   if(Cfg.profile==UGS_HEDGE || Cfg.profile==UGS_BIDIRECTIONAL)
   {
      if(OpenMarket(true,Cfg.lotSize,"hedge anchor buy")) placed++;
      if(OpenMarket(false,Cfg.lotSize,"hedge anchor sell")) placed++;
   }
   for(int i=0;i<MAX_LEVELS;i++) if(Levels[i].intended && SubmitPending(Levels[i])) placed++;
   RefreshOwnership();
   Rt.cooldownUntil=TimeCurrent()+Cfg.cooldownSeconds;
   if(placed>0) {SetState(STATE_ACTIVE,"cycle deployed");Audit(actor,"CYCLE_START","placed="+(string)placed);}
   else {SetState(STATE_IDLE,"nothing executable");Audit(actor,"CYCLE_EMPTY","no valid orders");}
   return placed>0;
}
void ProcessRequest()
{
   if(PendingReq.kind==REQ_NONE) return;
   UGS_REQUEST_KIND k=PendingReq.kind;
   string actor=PendingReq.actor,reason=PendingReq.reason;
   PendingReq.kind=REQ_NONE;
   switch(k)
   {
      case REQ_START: StartCycle(actor); break;
      case REQ_STOP:
         CancelOwnedPending(); SetState(STATE_IDLE,reason); Audit(actor,"STOP",reason); break;
      case REQ_REBUILD:
         CancelOwnedPending(); SetState(STATE_IDLE,"rebuild requested"); StartCycle(actor); break;
      case REQ_CLOSE_OWNED:
         SetState(STATE_EXITING,reason); CloseOwnedPositions(); CancelOwnedPending(); SetState(STATE_IDLE,"owned inventory closed"); break;
      case REQ_CANCEL_OWNED:
         CancelOwnedPending(); Audit(actor,"CANCEL_OWNED",reason); Reconcile(); break;
      case REQ_EMERGENCY:
         Rt.emergency=true; Rt.emergencyReason=reason; SetState(STATE_HALTED,"emergency");
         CancelOwnedPending(); if(Cfg.emergencyFlatten) CloseOwnedPositions();
         Audit(actor,"EMERGENCY",reason); break;
      default: break;
   }
}
void QueueRequest(UGS_REQUEST_KIND k,string actor,string reason)
{
   PendingReq.kind=k; PendingReq.requestId=++Rt.sequence; PendingReq.created=TimeCurrent();
   PendingReq.actor=actor; PendingReq.reason=reason;
   Audit(actor,"COMMAND",RequestName(k)+" | "+reason);
}
void SafetySupervisor()
{
   RefreshOwnership();
   double eq=AccountInfoDouble(ACCOUNT_EQUITY);
   if(eq>Rt.equityPeak) Rt.equityPeak=eq;
   if(Rt.emergency) return;
   if(Rt.equityPeak>0)
   {
      double dd=(Rt.equityPeak-eq)/Rt.equityPeak*100;
      if(dd>=Cfg.maxEquityDrawdownPct)
      {
         Rt.emergency=true; Rt.emergencyReason="drawdown threshold";
         QueueRequest(REQ_EMERGENCY,"SUPERVISOR","drawdown threshold");
      }
   }
}
void ManageAutonomous()
{
   if(Cfg.control!=UGS_AUTONOMOUS) return;
   if(Rt.state==STATE_IDLE && !Rt.emergency)
   {
      string why=""; double s=AutonomousScore(why); Rt.autonomyScore=s;
      if(!Cfg.autonomousEntryGate || s>=Cfg.autonomousScoreThreshold)
         QueueRequest(REQ_START,"AUTONOMOUS","score="+DoubleToString(s,1));
   }
}
void DrawBox(string name,int x,int y,int w,int h,color bg,color border)
{
   if(ObjectFind(0,name)<0) ObjectCreate(0,name,OBJ_RECTANGLE_LABEL,0,0,0);
   ObjectSetInteger(0,name,OBJPROP_XDISTANCE,x); ObjectSetInteger(0,name,OBJPROP_YDISTANCE,y);
   ObjectSetInteger(0,name,OBJPROP_XSIZE,w); ObjectSetInteger(0,name,OBJPROP_YSIZE,h);
   ObjectSetInteger(0,name,OBJPROP_BGCOLOR,bg); ObjectSetInteger(0,name,OBJPROP_BORDER_COLOR,border);
   ObjectSetInteger(0,name,OBJPROP_CORNER,CORNER_LEFT_UPPER);
}
void DrawText(string name,string text,int x,int y,int size,color col)
{
   if(ObjectFind(0,name)<0) ObjectCreate(0,name,OBJ_LABEL,0,0,0);
   ObjectSetInteger(0,name,OBJPROP_XDISTANCE,x); ObjectSetInteger(0,name,OBJPROP_YDISTANCE,y);
   ObjectSetInteger(0,name,OBJPROP_FONTSIZE,size); ObjectSetInteger(0,name,OBJPROP_COLOR,col);
   ObjectSetString(0,name,OBJPROP_TEXT,text); ObjectSetString(0,name,OBJPROP_FONT,"Segoe UI");
   ObjectSetInteger(0,name,OBJPROP_CORNER,CORNER_LEFT_UPPER);
}
void DrawButton(string name,string text,int x,int y,int w,int h)
{
   DrawBox(name,x,y,w,h,clrBlack,clrDimGray);
   DrawText(name+"_T",text,x+8,y+6,9,clrWhite);
}
void DeleteDashboard()
{
   int total=ObjectsTotal(0,-1,-1);
   for(int i=total-1;i>=0;i--)
   {
      string n=ObjectName(0,i,-1,-1);
      if(StringFind(n,DashboardName)==0) ObjectDelete(0,n);
   }
}
void Dashboard()
{
   if(!Cfg.showDashboard){DeleteDashboard();return;}
   int cw=(int)ChartGetInteger(0,CHART_WIDTH_IN_PIXELS,0);
   int w=MathMax(430,(int)(cw*Cfg.dashboardWidthPct/100.0));
   int h=520;
   int x=8,y=18;
   color bg=C'12,13,20', panel=C'21,22,32', accent=C'170,90,255';
   DrawBox(DashboardName+"_ROOT",x,y,w,h,bg,C'55,48,72');
   DrawText(DashboardName+"_TITLE","ULTIMATE GRID SCALPING | v"+UGS_VERSION,x+18,y+14,12,clrWhite);
   DrawText(DashboardName+"_STATE","● "+StateName(Rt.state)+"   |   "+ProfileName(Cfg.profile),x+18,y+38,9,accent);
   DrawText(DashboardName+"_PRICE","PRICE  "+DoubleToString(Mid(),_Digits)+"   ANCHOR  "+DoubleToString(Rt.anchor,_Digits),x+18,y+64,9,clrSilver);
   DrawText(DashboardName+"_MET","STEP "+DoubleToString(Rt.activeStep,1)+" pips   SPREAD "+DoubleToString(Rt.spreadPips,1)+" pips   ATR "+DoubleToString(PriceToPips(CurrentATRPrice()),1),x+18,y+84,9,clrSilver);
   DrawBox(DashboardName+"_CARD1",x+16,y+112,w-32,92,panel,C'45,45,60');
   DrawText(DashboardName+"_C1","GRID CONTROL",x+28,y+124,9,accent);
   DrawText(DashboardName+"_C1A","Owned positions: "+(string)Rt.ownedPositions,x+28,y+146,9,clrWhite);
   DrawText(DashboardName+"_C1B","Owned pending:  "+(string)Rt.ownedPending,x+190,y+146,9,clrWhite);
   DrawText(DashboardName+"_C1C","Basket P/L: "+DoubleToString(Rt.ownedProfit,2),x+28,y+168,9,clrWhite);
   DrawText(DashboardName+"_C1D","Autonomy score: "+DoubleToString(Rt.autonomyScore,1),x+190,y+168,9,clrWhite);
   DrawButton(DashboardName+"_START","DEPLOY GRID",x+18,y+220,120,30);
   DrawButton(DashboardName+"_CANCEL","CANCEL PENDING",x+148,y+220,120,30);
   DrawButton(DashboardName+"_CLOSE","CLOSE OWNED",x+278,y+220,110,30);
   DrawButton(DashboardName+"_REBUILD","REBUILD",x+398,y+220,90,30);
   DrawBox(DashboardName+"_CARD2",x+16,y+264,w-32,112,panel,C'45,45,60');
   DrawText(DashboardName+"_R","RISK / SUPERVISOR",x+28,y+276,9,accent);
   double dd=0,eq=AccountInfoDouble(ACCOUNT_EQUITY); if(Rt.equityPeak>0) dd=(Rt.equityPeak-eq)/Rt.equityPeak*100;
   DrawText(DashboardName+"_RA","Drawdown: "+DoubleToString(dd,2)+"% / "+DoubleToString(Cfg.maxEquityDrawdownPct,1)+"%",x+28,y+300,9,clrWhite);
   DrawText(DashboardName+"_RB","Margin: "+DoubleToString(AccountInfoDouble(ACCOUNT_MARGIN),2),x+28,y+322,9,clrWhite);
   DrawText(DashboardName+"_RC","Last: "+Rt.lastAction+" | "+Rt.lastReason,x+28,y+344,9,clrWhite);
   DrawText(DashboardName+"_RD","Ownership: "+(string)Rt.ownedPositions+" positions / "+(string)Rt.ownedPending+" orders",x+28,y+366,9,clrWhite);
   DrawText(DashboardName+"_FOOT","Manual commands affect EA-owned inventory only. External/manual trades are preserved.",x+18,y+488,8,clrSilver);
}
void OnChartEvent(const int id,const long &lparam,const double &dparam,const string &sparam)
{
   if(id!=CHARTEVENT_OBJECT_CLICK) return;
   if(sparam==DashboardName+"_START") QueueRequest(REQ_START,"USER","explicit deploy");
   else if(sparam==DashboardName+"_CANCEL") QueueRequest(REQ_CANCEL_OWNED,"USER","explicit cancel pending");
   else if(sparam==DashboardName+"_CLOSE") QueueRequest(REQ_CLOSE_OWNED,"USER","explicit close owned");
   else if(sparam==DashboardName+"_REBUILD") QueueRequest(REQ_REBUILD,"USER","explicit rebuild");
}
void InitializeIndicators()
{
   atrHandle=iATR(_Symbol,PERIOD_CURRENT,14);
   maHandle=iMA(_Symbol,PERIOD_CURRENT,34,0,MODE_EMA,PRICE_CLOSE);
   rsiHandle=iRSI(_Symbol,PERIOD_CURRENT,14,PRICE_CLOSE);
}
void ReleaseIndicators()
{
   if(atrHandle!=INVALID_HANDLE) IndicatorRelease(atrHandle);
   if(maHandle!=INVALID_HANDLE) IndicatorRelease(maHandle);
   if(rsiHandle!=INVALID_HANDLE) IndicatorRelease(rsiHandle);
   atrHandle=INVALID_HANDLE;maHandle=INVALID_HANDLE;rsiHandle=INVALID_HANDLE;
}
void RecoverOwnedInventory()
{
   RefreshOwnership();
   if(Rt.ownedPositions>0 || Rt.ownedPending>0)
   {
      Rt.state=STATE_RECOVERY;
      Rt.anchor=Mid();
      Audit("RECOVERY","ATTACH","owned inventory detected; no destructive action");
      Rt.state=STATE_ACTIVE;
   }
   else Rt.state=STATE_IDLE;
}
int OnInit()
{
   LoadConfig();
   Root=UGS_PREFIX+(string)ChartID()+"_";
   DashboardName=Root+"DASH_";
   Rt.instanceId=(long)InpInstanceSeed;
   if(Rt.instanceId<=0) Rt.instanceId=140024;
   // Instance-specific magic prevents generic account-wide ownership operations.
   Rt.instanceId += (long)(ChartID()%100000);
   Rt.sequence=0; Rt.state=STATE_IDLE; Rt.anchor=0; Rt.activeStep=0;
   Rt.equityPeak=AccountInfoDouble(ACCOUNT_EQUITY); Rt.dayStartEquity=Rt.equityPeak;
   Rt.lastAction="INITIALIZED"; Rt.lastReason="non-destructive attach";
   Trade.SetExpertMagicNumber((ulong)Rt.instanceId);
   Trade.SetDeviationInPoints(20);
   InitializeIndicators();
   RecoverOwnedInventory();
   Audit("SYSTEM","INIT","clean-room v"+UGS_VERSION);
   if(InpStartOnAttach && Rt.ownedPositions==0 && Rt.ownedPending==0)
      QueueRequest(REQ_START,"CONFIG","start-on-attach");
   EventSetTimer(1);
   ObjectsReady=true;
   Dashboard();
   return INIT_SUCCEEDED;
}
void OnDeinit(const int reason)
{
   EventKillTimer();
   DeleteDashboard();
   ReleaseIndicators();
}
void OnTick()
{
   Rt.lastTick=TimeCurrent();
   RefreshOwnership();
   double a=CurrentATRPrice(); Rt.atrPips=PriceToPips(a); Rt.spreadPips=SpreadPips();
   Rt.volatilityScore=VolatilityScore(); Rt.trendScore=TrendScore();
   SafetySupervisor();
   ProcessRequest();
   if(BasketProtection()) return;
   RecenterIfNeeded();
   Replenish();
   ManageAutonomous();
}
void OnTimer()
{
   RefreshOwnership();
   SafetySupervisor();
   ProcessRequest();
   Reconcile();
   Dashboard();
}
void OnTradeTransaction(const MqlTradeTransaction &trans,const MqlTradeRequest &request,const MqlTradeResult &result)
{
   if(trans.type==TRADE_TRANSACTION_DEAL_ADD || trans.type==TRADE_TRANSACTION_ORDER_ADD ||
      trans.type==TRADE_TRANSACTION_ORDER_DELETE || trans.type==TRADE_TRANSACTION_POSITION)
   {
      Audit("BROKER","TRANSACTION","type="+(string)trans.type+" order="+(string)trans.order+" deal="+(string)trans.deal);
      RefreshOwnership();
   }
}
