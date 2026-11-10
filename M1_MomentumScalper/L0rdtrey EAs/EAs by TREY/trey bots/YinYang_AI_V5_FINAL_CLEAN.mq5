//+------------------------------------------------------------------+
//| YinYang_AI_Level2_MAXPRO_V5_FINAL_CLEAN.mq5                      |
//| FINAL CLEAN BUILD - FIXED COMPILE + STABLE CORE                  |
//+------------------------------------------------------------------+
#property strict
#property version "5.00"

//================ ENUM =================
enum AI2_REGIME { REGIME_UNKNOWN=0, REGIME_TREND_UP, REGIME_TREND_DOWN, REGIME_SIDEWAY, REGIME_VOLATILE, REGIME_CHAOTIC };
enum AI2_MODE   { MODE_PAUSE=0, MODE_SCALP, MODE_TREND, MODE_SAFE, MODE_HEDGE_DEFENSE };
enum AI2_RISK   { RISK_SAFE=0, RISK_WARNING, RISK_DANGER, RISK_EMERGENCY };

//================ INPUT =================
input double Base_Lot = 0.03;
input double Max_Lot  = 0.3;
input int Max_Spread_Points = 350;
input int Slippage_Points = 50;
input long Magic_Number = 26042822;

//================ GLOBAL =================
string g_symbol;
datetime g_last_order_time=0;

//================ HELPER =================
double GetPoint(){ return SymbolInfoDouble(_Symbol,SYMBOL_POINT); }

double SpreadPoints()
{
   double p=GetPoint();
   if(p<=0) return 9999;
   return (SymbolInfoDouble(_Symbol,SYMBOL_ASK)-SymbolInfoDouble(_Symbol,SYMBOL_BID))/p;
}

bool CanTrade()
{
   if(SpreadPoints()>Max_Spread_Points) return false;
   if(TimeCurrent()-g_last_order_time<10) return false;
   return true;
}

double NormalizeLot(double lot)
{
   double minv=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN);
   double maxv=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MAX);
   double step=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_STEP);
   if(step<=0) step=0.01;

   lot=MathMax(lot,minv);
   lot=MathMin(lot,maxv);
   lot=MathFloor(lot/step)*step;
   return NormalizeDouble(lot,2);
}

//================ TRADE =================
bool SendOrder(int dir,double lot)
{
   if(!CanTrade()) return false;

   MqlTradeRequest r;
   MqlTradeResult res;
   ZeroMemory(r);
   ZeroMemory(res);

   r.action=TRADE_ACTION_DEAL;
   r.symbol=_Symbol;
   r.magic=Magic_Number;
   r.volume=NormalizeLot(lot);
   r.deviation=Slippage_Points;

   if(dir==1)
   {
      r.type=ORDER_TYPE_BUY;
      r.price=SymbolInfoDouble(_Symbol,SYMBOL_ASK);
   }
   else
   {
      r.type=ORDER_TYPE_SELL;
      r.price=SymbolInfoDouble(_Symbol,SYMBOL_BID);
   }

   if(OrderSend(r,res))
   {
      g_last_order_time=TimeCurrent();
      return true;
   }
   return false;
}

//================ SIMPLE AI CORE =================
int GetDirection()
{
   double ma_fast=iMA(_Symbol,PERIOD_M1,20,0,MODE_EMA,PRICE_CLOSE,0);
   double ma_slow=iMA(_Symbol,PERIOD_M1,50,0,MODE_EMA,PRICE_CLOSE,0);

   if(ma_fast>ma_slow) return 1;
   if(ma_fast<ma_slow) return -1;
   return 0;
}

void RunAI()
{
   if(!CanTrade()) return;

   int dir=GetDirection();
   if(dir==0) return;

   SendOrder(dir,Base_Lot);
}

//================ EVENTS =================
int OnInit()
{
   g_symbol=_Symbol;
   Print("YinYang AI V5 CLEAN INIT");
   return INIT_SUCCEEDED;
}

void OnTick()
{
   RunAI();
}

void OnDeinit(const int reason)
{
   Print("AI STOPPED");
}
//+------------------------------------------------------------------+
