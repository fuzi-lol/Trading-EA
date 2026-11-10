//+------------------------------------------------------------------+
//|                EliteScalper Institutional AI Engine              |
//|                Full Autonomous Institutional Scalper             |
//+------------------------------------------------------------------+
#property strict
#property version   "5.00"
#property description "Institutional AI Scalper"

#include <Trade/Trade.mqh>
#include <Trade/PositionInfo.mqh>

//======================== BRAND COLORS =============================//
#define DASH_PRE "ELITEAI_"

#define C_BG      C'4,6,10'
#define C_PANEL   C'10,14,24'
#define C_BLUE    C'0,120,255'
#define C_GREEN   C'0,230,120'
#define C_RED     C'240,60,60'
#define C_GOLD    C'255,200,50'
#define C_WHITE   C'240,245,255'
#define C_TEXT    C'170,185,210'
#define C_GRAY    C'90,100,120'

//======================== INPUTS ===================================//
input ulong InpMagicNumber=88888;
input double InpBaseLot=0.01;
input bool InpUseDynamicRisk=true;
input double InpRiskPercent=1.0;

input int InpFastEMA=9;
input int InpSlowEMA=21;
input int InpATRPeriod=14;

input double InpATR_SL_Mult=1.5;
input double InpATR_TP_Mult=2.5;

input double InpTargetProfitUSD=2.0;
input int InpMaxDailyTrades=20;

input bool InpUseSessionFilter=true;
input bool InpUseAI=true;
input bool InpUseTrailing=true;
input bool InpUseLiquiditySweep=true;
input bool InpUseFVG=true;
input bool InpUseOrderBlock=true;

input ENUM_TIMEFRAMES InpHTF=PERIOD_M15;

//======================== GLOBALS ==================================//
CTrade trade;
CPositionInfo pos;

int hFastEMA;
int hSlowEMA;
int hATR;

int g_tradesToday=0;
double g_profitToday=0;
double g_aiScore=0;

datetime g_lastTrade=0;
datetime g_lastReset=0;

datetime g_nextEntry=0;

string g_status="BOOTING AI ENGINE";
string g_lastAction="NONE";
string g_tradeReason="WAITING";
string g_tradeDirection="NONE";

//======================== DASHBOARD SIZE ===========================//
const int DW=520;
const int DH=720;

//+------------------------------------------------------------------+
//| INIT                                                             |
//+------------------------------------------------------------------+
int OnInit()
{
   trade.SetExpertMagicNumber(InpMagicNumber);
   trade.SetDeviationInPoints(10);

   hFastEMA=iMA(Symbol(),PERIOD_CURRENT,InpFastEMA,0,MODE_EMA,PRICE_CLOSE);
   hSlowEMA=iMA(Symbol(),PERIOD_CURRENT,InpSlowEMA,0,MODE_EMA,PRICE_CLOSE);
   hATR=iATR(Symbol(),PERIOD_CURRENT,InpATRPeriod);

   if(hFastEMA==INVALID_HANDLE || hSlowEMA==INVALID_HANDLE || hATR==INVALID_HANDLE)
      return INIT_FAILED;

   CreateDashboard();

   EventSetTimer(1);

   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   EventKillTimer();

   if(hFastEMA!=INVALID_HANDLE)
      IndicatorRelease(hFastEMA);

   if(hSlowEMA!=INVALID_HANDLE)
      IndicatorRelease(hSlowEMA);

   if(hATR!=INVALID_HANDLE)
      IndicatorRelease(hATR);

   DeleteDashboard();
}

//+------------------------------------------------------------------+
void OnTimer()
{
   BuildStats();
   UpdateDashboard();
}

//+------------------------------------------------------------------+
void OnTick()
{
   if(!IsMarketOpen())
   {
      g_status="MARKET CLOSED";
      return;
   }

   ManageTrailing();

   if(HasOpenPosition())
   {
      CheckTargetProfit();
      return;
   }

   if(g_tradesToday>=InpMaxDailyTrades)
   {
      g_status="DAILY LIMIT REACHED";
      return;
   }

   if(TimeCurrent()<g_nextEntry)
   {
      g_status="RE-ENTRY COOLDOWN";
      return;
   }

   if(!SessionAllowed())
   {
      g_status="SESSION FILTER ACTIVE";
      return;
   }

   if(!SpreadAllowed())
   {
      g_status="SPREAD TOO HIGH";
      return;
   }

   ExecuteInstitutionalTrade();
}

//+------------------------------------------------------------------+
void ExecuteInstitutionalTrade()
{
   if(TimeCurrent()==g_lastTrade)
      return;

   ENUM_ORDER_TYPE dir=GetTrend();

   if(InpUseAI)
   {
      int score=CalculateAIScore(dir);
      g_aiScore=score;

      if(score<70)
      {
         g_status="AI BLOCKED TRADE";
         g_tradeReason="Low AI Confidence";
         return;
      }
   }

   if(InpUseLiquiditySweep)
   {
      if(!LiquiditySweepConfirmed(dir))
      {
         g_status="NO LIQUIDITY SWEEP";
         g_tradeReason="Liquidity Sweep Filter";
         return;
      }
   }

   if(InpUseOrderBlock)
   {
      if(!OrderBlockConfirmed(dir))
      {
         g_status="ORDER BLOCK FILTER";
         g_tradeReason="Weak Institutional Zone";
         return;
      }
   }

   if(InpUseFVG)
   {
      if(!FairValueGapConfirmed())
      {
         g_status="NO FAIR VALUE GAP";
         g_tradeReason="No Imbalance Detected";
         return;
      }
   }

   double atr=GetATR();
   if(atr<=0)
      return;

   double point=SymbolInfoDouble(Symbol(),SYMBOL_POINT);

   double slPoints=(atr*InpATR_SL_Mult)/point;
   double tpPoints=(atr*InpATR_TP_Mult)/point;

   double lot=CalculateLot(slPoints);

   double ask=SymbolInfoDouble(Symbol(),SYMBOL_ASK);
   double bid=SymbolInfoDouble(Symbol(),SYMBOL_BID);

   double sl=0;
   double tp=0;

   if(dir==ORDER_TYPE_BUY)
   {
      sl=ask-(slPoints*point);
      tp=ask+(tpPoints*point);
   }
   else
   {
      sl=bid+(slPoints*point);
      tp=bid-(tpPoints*point);
   }

   bool ok=false;

   if(dir==ORDER_TYPE_BUY)
      ok=trade.Buy(lot,Symbol(),ask,sl,tp,"Elite AI Buy");
   else
      ok=trade.Sell(lot,Symbol(),bid,sl,tp,"Elite AI Sell");

   if(ok)
   {
      g_lastTrade=TimeCurrent();
      g_tradesToday++;

      g_tradeDirection=(dir==ORDER_TYPE_BUY)?"BUY":"SELL";

      g_tradeReason="AI + MTF + OB + FVG + Liquidity";

      g_lastAction="TRADE EXECUTED";

      g_status="INSTITUTIONAL ENTRY EXECUTED";
   }
   else
   {
      g_status="EXECUTION FAILED";
      g_lastAction=trade.ResultRetcodeDescription();
   }
}

//+------------------------------------------------------------------+
ENUM_ORDER_TYPE GetTrend()
{
   double fast[];
   double slow[];

   ArraySetAsSeries(fast,true);
   ArraySetAsSeries(slow,true);

   CopyBuffer(hFastEMA,0,0,2,fast);
   CopyBuffer(hSlowEMA,0,0,2,slow);

   if(fast[0]>slow[0])
      return ORDER_TYPE_BUY;

   return ORDER_TYPE_SELL;
}

//+------------------------------------------------------------------+
double GetATR()
{
   double atr[];

   ArraySetAsSeries(atr,true);

   if(CopyBuffer(hATR,0,0,1,atr)<1)
      return 0;

   return atr[0];
}

//+------------------------------------------------------------------+
int CalculateAIScore(ENUM_ORDER_TYPE dir)
{
   int score=0;

   if(MomentumStrong())
      score+=25;

   if(ConfirmHTF(dir))
      score+=30;

   if(SpreadAllowed())
      score+=15;

   if(LiquiditySweepConfirmed(dir))
      score+=15;

   if(OrderBlockConfirmed(dir))
      score+=15;

   return score;
}

//+------------------------------------------------------------------+
bool MomentumStrong()
{
   double fast[];
   double slow[];

   ArraySetAsSeries(fast,true);
   ArraySetAsSeries(slow,true);

   CopyBuffer(hFastEMA,0,0,1,fast);
   CopyBuffer(hSlowEMA,0,0,1,slow);

   double point=SymbolInfoDouble(Symbol(),SYMBOL_POINT);

   return MathAbs(fast[0]-slow[0])>(point*50);
}

//+------------------------------------------------------------------+
bool ConfirmHTF(ENUM_ORDER_TYPE dir)
{
   int h1=iMA(Symbol(),InpHTF,InpFastEMA,0,MODE_EMA,PRICE_CLOSE);
   int h2=iMA(Symbol(),InpHTF,InpSlowEMA,0,MODE_EMA,PRICE_CLOSE);

   double f[];
   double s[];

   ArraySetAsSeries(f,true);
   ArraySetAsSeries(s,true);

   CopyBuffer(h1,0,0,1,f);
   CopyBuffer(h2,0,0,1,s);

   IndicatorRelease(h1);
   IndicatorRelease(h2);

   if(dir==ORDER_TYPE_BUY && f[0]>s[0])
      return true;

   if(dir==ORDER_TYPE_SELL && f[0]<s[0])
      return true;

   return false;
}

//+------------------------------------------------------------------+
bool LiquiditySweepConfirmed(ENUM_ORDER_TYPE dir)
{
   double high1=iHigh(Symbol(),PERIOD_CURRENT,1);
   double high2=iHigh(Symbol(),PERIOD_CURRENT,2);

   double low1=iLow(Symbol(),PERIOD_CURRENT,1);
   double low2=iLow(Symbol(),PERIOD_CURRENT,2);

   if(dir==ORDER_TYPE_BUY)
      return low1<low2;

   return high1>high2;
}

//+------------------------------------------------------------------+
bool FairValueGapConfirmed()
{
   double high2=iHigh(Symbol(),PERIOD_CURRENT,2);
   double low0=iLow(Symbol(),PERIOD_CURRENT,0);

   return MathAbs(high2-low0)>GetATR()*0.2;
}

//+------------------------------------------------------------------+
bool OrderBlockConfirmed(ENUM_ORDER_TYPE dir)
{
   double open1=iOpen(Symbol(),PERIOD_CURRENT,1);
   double close1=iClose(Symbol(),PERIOD_CURRENT,1);

   if(dir==ORDER_TYPE_BUY)
      return close1>open1;

   return close1<open1;
}

//+------------------------------------------------------------------+
double CalculateLot(double slPoints)
{
   if(!InpUseDynamicRisk)
      return InpBaseLot;

   double balance=AccountInfoDouble(ACCOUNT_BALANCE);

   double risk=balance*(InpRiskPercent/100.0);

   double tickValue=SymbolInfoDouble(Symbol(),SYMBOL_TRADE_TICK_VALUE);
   double tickSize=SymbolInfoDouble(Symbol(),SYMBOL_TRADE_TICK_SIZE);

   double valuePerPoint=tickValue/tickSize;

   double lot=risk/(slPoints*valuePerPoint);

   double minLot=SymbolInfoDouble(Symbol(),SYMBOL_VOLUME_MIN);
   double maxLot=SymbolInfoDouble(Symbol(),SYMBOL_VOLUME_MAX);

   lot=MathMax(minLot,MathMin(maxLot,lot));

   return NormalizeDouble(lot,2);
}

//+------------------------------------------------------------------+
void ManageTrailing()
{
   if(!InpUseTrailing)
      return;

   for(int i=PositionsTotal()-1;i>=0;i--)
   {
      ulong ticket=PositionGetTicket(i);

      if(ticket<=0)
         continue;

      if(!pos.SelectByTicket(ticket))
         continue;

      if(pos.Magic()!=InpMagicNumber)
         continue;

      double point=SymbolInfoDouble(Symbol(),SYMBOL_POINT);

      ENUM_POSITION_TYPE type=(ENUM_POSITION_TYPE)pos.PositionType();

      double price=(type==POSITION_TYPE_BUY)
      ? SymbolInfoDouble(Symbol(),SYMBOL_BID)
      : SymbolInfoDouble(Symbol(),SYMBOL_ASK);

      double move=MathAbs(price-pos.PriceOpen())/point;

      if(move>200)
      {
         double sl=(type==POSITION_TYPE_BUY)
         ? price-(80*point)
         : price+(80*point);

         trade.PositionModify(ticket,sl,pos.TakeProfit());
      }
   }
}

//+------------------------------------------------------------------+
void CheckTargetProfit()
{
   double total=FloatingProfit();

   if(total>=InpTargetProfitUSD)
   {
      CloseAllPositions();

      g_status="TARGET PROFIT LOCKED";
      g_lastAction="CLOSED ALL POSITIONS";

      g_nextEntry=TimeCurrent()+10;
   }
}

//+------------------------------------------------------------------+
double FloatingProfit()
{
   double total=0;

   for(int i=PositionsTotal()-1;i>=0;i--)
   {
      ulong ticket=PositionGetTicket(i);

      if(ticket<=0)
         continue;

      if(!pos.SelectByTicket(ticket))
         continue;

      if(pos.Magic()!=InpMagicNumber)
         continue;

      total+=pos.Profit();
   }

   return total;
}

//+------------------------------------------------------------------+
void CloseAllPositions()
{
   for(int i=PositionsTotal()-1;i>=0;i--)
   {
      ulong ticket=PositionGetTicket(i);

      if(ticket<=0)
         continue;

      if(!pos.SelectByTicket(ticket))
         continue;

      if(pos.Magic()!=InpMagicNumber)
         continue;

      trade.PositionClose(ticket);
   }
}

//+------------------------------------------------------------------+
bool HasOpenPosition()
{
   for(int i=PositionsTotal()-1;i>=0;i--)
   {
      ulong ticket=PositionGetTicket(i);

      if(ticket<=0)
         continue;

      if(!pos.SelectByTicket(ticket))
         continue;

      if(pos.Magic()==InpMagicNumber)
         return true;
   }

   return false;
}

//+------------------------------------------------------------------+
bool SessionAllowed()
{
   if(!InpUseSessionFilter)
      return true;

   MqlDateTime tm;
   TimeToStruct(TimeCurrent(),tm);

   int h=tm.hour;

   bool london=(h>=7 && h<=16);
   bool ny=(h>=13 && h<=22);

   return london || ny;
}

//+------------------------------------------------------------------+
bool SpreadAllowed()
{
   double point=SymbolInfoDouble(Symbol(),SYMBOL_POINT);

   int spread=(int)((SymbolInfoDouble(Symbol(),SYMBOL_ASK)-
                     SymbolInfoDouble(Symbol(),SYMBOL_BID))/point);

   return spread<=40;
}

//+------------------------------------------------------------------+
bool IsMarketOpen()
{
   ENUM_SYMBOL_TRADE_MODE mode=(ENUM_SYMBOL_TRADE_MODE)
   SymbolInfoInteger(Symbol(),SYMBOL_TRADE_MODE);

   return mode==SYMBOL_TRADE_MODE_FULL ||
          mode==SYMBOL_TRADE_MODE_LONGONLY ||
          mode==SYMBOL_TRADE_MODE_SHORTONLY;
}

//+------------------------------------------------------------------+
void BuildStats()
{
   datetime now=TimeCurrent();

   MqlDateTime tm;
   TimeToStruct(now,tm);

   datetime midnight=now-(tm.hour*3600+tm.min*60+tm.sec);

   if(midnight>g_lastReset)
   {
      g_tradesToday=0;
      g_profitToday=0;
      g_lastReset=midnight;
   }

   g_profitToday=0;

   if(HistorySelect(midnight,now))
   {
      for(int i=0;i<HistoryDealsTotal();i++)
      {
         ulong ticket=HistoryDealGetTicket(i);

         if(HistoryDealGetInteger(ticket,DEAL_MAGIC)==InpMagicNumber)
         {
            g_profitToday+=HistoryDealGetDouble(ticket,DEAL_PROFIT);
         }
      }
   }
}

//==================== ADVANCED INSTITUTIONAL DASHBOARD =============//
void CreateDashboard()
{
   int X=8;
   int Y=8;

   Rect("bg",X,Y,520,620,C_BG,C_BLUE);

   //================ HEADER =================//
   Rect("header",X+5,Y+5,510,75,C_PANEL,C_BLUE);

   Label("brand",X+18,Y+18,"ELITESCALPER INSTITUTIONAL AI",C_WHITE,16);
   Label("subtitle",X+18,Y+42,"Advanced Autonomous Scalping System",C_BLUE,9);
   Label("subtitle2",X+18,Y+58,"AI Logic | Smart Money |strategic Scalping",C_TEXT,8);

   //================ SYSTEM STATUS BAR =================//
   Rect("statusbar",X+5,Y+88,510,35,C_PANEL,C_BLUE);

   Label("sys_title",X+10,Y+99,"SYSTEM STATUS:",C_TEXT,8);
   Label("sys_value",X+110,Y+99,"LIVE",C_GREEN,8);

   Label("market_title",X+170,Y+99,"MARKET:",C_TEXT,8);
   Label("market_value",X+235,Y+99,Symbol(),C_WHITE,8);

   Label("session_title",X+340,Y+99,"SESSION:",C_TEXT,10);
   Label("session_value",X+410,Y+99,"LONDON/NY",C_BLUE,11);

   //================ LEFT ANALYTICS PANEL =================//
   Rect("analytics",X+5,Y+132,248,245,C_PANEL,C_GREEN);

   Label("analytics_hd",X+18,Y+145,"ACCOUNT ANALYTICS",C_WHITE,14);

   Label("bal_t",X+20,Y+180,"BALANCE",C_TEXT,10);
   Label("bal_v",X+145,Y+180,"0.00",C_WHITE,12);

   Label("eq_t",X+20,Y+215,"EQUITY",C_TEXT,10);
   Label("eq_v",X+145,Y+215,"0.00",C_WHITE,12);

   Label("fp_t",X+20,Y+245,"FLOATING P/L",C_TEXT,10);
   Label("fp_v",X+145,Y+245,"0.00",C_GREEN,12);

   Label("dp_t",X+20,Y+275,"DAILY P/L",C_TEXT,10);
   Label("dp_v",X+145,Y+275,"0.00",C_GREEN,12);

   Label("ai_t",X+20,Y+305,"AI CONFIDENCE",C_TEXT,10);
   Label("ai_v",X+145,Y+305,"0%",C_GOLD,12);

   Label("spread_t",X+20,Y+335,"SPREAD STATE",C_TEXT,10);
   Label("spread_v",X+145,Y+335,"NORMAL",C_GREEN,12);

   //================ RIGHT EXECUTION PANEL =================//
   Rect("execution",X+262,Y+132,253,245,C_PANEL,C_BLUE);

   Label("exec_hd",X+275,Y+145,"LIVE EXECUTION TERMINAL",C_WHITE,13);

   Label("status_t",X+275,Y+185,"ENGINE STATUS",C_TEXT,9);
   Label("status_v",X+385,Y+185,"WAITING",C_BLUE,9);

   Label("action_t",X+275,Y+215,"LAST ACTION",C_TEXT,9);
   Label("action_v",X+390,Y+215,"NONE",C_WHITE,9);

   Label("direction_t",X+275,Y+245,"TRADE DIRECTION",C_TEXT,10);
   Label("direction_v",X+410,Y+245,"NONE",C_WHITE,11);

   Label("reason_t",X+275,Y+275,"TRADE REASON",C_TEXT,9);
   Label("reason_v",X+370,Y+275,"WAITING",C_GOLD,9);

   Label("tradecount_t",X+275,Y+305,"DAILY TRADES",C_TEXT,10);
   Label("tradecount_v",X+390,Y+305,"0",C_WHITE,11);

   Label("target_t",X+275,Y+335,"TARGET STATUS",C_TEXT,10);
   Label("target_v",X+390,Y+335,"ACTIVE",C_GREEN,11);

   //================ AI DECISION MATRIX =================//
   Rect("matrix",X+5,Y+387,510,145,C_PANEL,C_GOLD);

   Label("matrix_hd",X+18,Y+400,"AI DECISION MATRIX",C_WHITE,11);

   Label("m1",X+20,Y+432,"• Liquidity Sweep Analysis",C_TEXT,10);
   Label("m1v",X+365,Y+432,"ACTIVE",C_GREEN,10);

   Label("m2",X+20,Y+457,"• Fair Value Gap Detection",C_TEXT,10);
   Label("m2v",X+365,Y+457,"ACTIVE",C_GREEN,10);

   Label("m3",X+20,Y+482,"• Order Block Confirmation",C_TEXT,10);
   Label("m3v",X+365,Y+482,"ACTIVE",C_GREEN,10);

   Label("m4",X+20,Y+507,"• Multi-Timeframe Alignment",C_TEXT,10);
   Label("m4v",X+365,Y+507,"ACTIVE",C_GREEN,10);

   //================ FOOTER =================//
   Rect("footer",X+5,Y+542,510,65,C_PANEL,C_BLUE);

   Label("ft1",X+18,Y+545,"EliteScalper Institutional Infrastructure",C_GRAY,9);
   Label("ft2",X+18,Y+580,"24/5 Autonomous AI Execution Environment",C_GRAY,9);
   Label("ft3",X+18,Y+600,"Quant Engine | Institutional Risk Logic | Autonomous Market Analysis",C_GRAY,9);
}

//+------------------------------------------------------------------+
void UpdateDashboard()
{
   SetLabel("bal_v", "$ "+DoubleToString(AccountInfoDouble(ACCOUNT_BALANCE),2));
   SetLabel("eq_v", "$ "+DoubleToString(AccountInfoDouble(ACCOUNT_EQUITY),2));

   double fp=FloatingProfit();

   SetLabel("fp_v", DoubleToString(fp,2));
   SetLabel("dp_v", DoubleToString(g_profitToday,2));

   SetLabel("ai_v", IntegerToString((int)g_aiScore)+"%");

   SetLabel("status_v", g_status);
   SetLabel("action_v", g_lastAction);
   SetLabel("direction_v", g_tradeDirection);
   SetLabel("reason_v", g_tradeReason);

   SetLabel("tradecount_v", IntegerToString(g_tradesToday));

   if(SpreadAllowed())
      SetLabel("spread_v", "NORMAL");
   else
      SetLabel("spread_v", "HIGH SPREAD");

   ChartRedraw(0);
}

//+------------------------------------------------------------------+
void DeleteDashboard()
{
   int total=ObjectsTotal(0);

   for(int i=total-1;i>=0;i--)
   {
      string name=ObjectName(0,i);

      if(StringFind(name,DASH_PRE)==0)
         ObjectDelete(0,name);
   }
}

//+------------------------------------------------------------------+
void Rect(string name,int x,int y,int w,int h,color bg,color border)
{
   string n=DASH_PRE+name;

   ObjectCreate(0,n,OBJ_RECTANGLE_LABEL,0,0,0);

   ObjectSetInteger(0,n,OBJPROP_XDISTANCE,x);
   ObjectSetInteger(0,n,OBJPROP_YDISTANCE,y);
   ObjectSetInteger(0,n,OBJPROP_XSIZE,w);
   ObjectSetInteger(0,n,OBJPROP_YSIZE,h);
   ObjectSetInteger(0,n,OBJPROP_BGCOLOR,bg);
   ObjectSetInteger(0,n,OBJPROP_COLOR,border);
   ObjectSetInteger(0,n,OBJPROP_BORDER_TYPE,BORDER_FLAT);
   ObjectSetInteger(0,n,OBJPROP_CORNER,CORNER_LEFT_UPPER);
}

//+------------------------------------------------------------------+
void Label(string name,int x,int y,string txt,color clr,int size)
{
   string n=DASH_PRE+name;

   ObjectCreate(0,n,OBJ_LABEL,0,0,0);

   ObjectSetInteger(0,n,OBJPROP_XDISTANCE,x);
   ObjectSetInteger(0,n,OBJPROP_YDISTANCE,y);
   ObjectSetInteger(0,n,OBJPROP_CORNER,CORNER_LEFT_UPPER);
   ObjectSetString(0,n,OBJPROP_TEXT,txt);
   ObjectSetInteger(0,n,OBJPROP_COLOR,clr);
   ObjectSetInteger(0,n,OBJPROP_FONTSIZE,size);
   ObjectSetString(0,n,OBJPROP_FONT,"Arial Bold");
}

//+------------------------------------------------------------------+
void SetLabel(string name,string txt)
{
   string n=DASH_PRE+name;

   if(ObjectFind(0,n)>=0)
      ObjectSetString(0,n,OBJPROP_TEXT,txt);
}
//+------------------------------------------------------------------+
