//+------------------------------------------------------------------+
//|              MASTER_WINNERFX_GOLD_MT5.mq5                        |
//+------------------------------------------------------------------+
#property copyright "Muhammad Asim"
#property link      "https://www.mql5.com"
#property version   "3.10"
#property strict

#include <Trade\Trade.mqh>

input double  LotPer1000    = 0.01;
input double  Multiplier    = 1.2;
input int     GridStep      = 1500;
input double  TargetProfit  = 3.0;
input double  MaxRisk       = 1000.0;
input int     MagicNumber   = 506780;

input int     EMAPeriod     = 50;
input ENUM_TIMEFRAMES TrendTF = PERIOD_M15;
input int     RSIPeriod     = 14;
input int     RSILower      = 55;
input int     RSIUpper      = 45;

input bool    PauseDuringNews = true;
input int     NewsHoursUTC  = 13;
input int     MarketCloseHour = 22;

CTrade trade;
int rsiHandle;
int emaHandle;

//+------------------------------------------------------------------+
bool CanOpenTrade(double lot)
{
   double margin;
   if(!OrderCalcMargin(ORDER_TYPE_BUY,_Symbol,lot,
                       SymbolInfoDouble(_Symbol,SYMBOL_ASK),margin))
      return false;

   if(AccountInfoDouble(ACCOUNT_MARGIN_FREE) < margin)
      return false;

   return true;
}
//+------------------------------------------------------------------+
double GetSafeLot(double baseLot)
{
   double minLot  = SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN);
   double maxLot  = SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MAX);
   double lotStep = SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_STEP);

   if(baseLot < minLot)
      baseLot = minLot;

   baseLot = MathFloor(baseLot/lotStep)*lotStep;
   baseLot = NormalizeDouble(baseLot,2);

   if(baseLot > maxLot)
      baseLot = maxLot;

   return baseLot;
}
//+------------------------------------------------------------------+
int OnInit()
{
   trade.SetExpertMagicNumber(MagicNumber);
   trade.SetTypeFillingBySymbol(_Symbol); // FIX unsupported filling mode

   rsiHandle = iRSI(_Symbol,_Period,RSIPeriod,PRICE_CLOSE);
   emaHandle = iMA(_Symbol,TrendTF,EMAPeriod,0,MODE_EMA,PRICE_CLOSE);

   if(rsiHandle==INVALID_HANDLE || emaHandle==INVALID_HANDLE)
      return(INIT_FAILED);

   return(INIT_SUCCEEDED);
}
//+------------------------------------------------------------------+
void OnTick()
{
   double totalPL=0;
   int buys=0,sells=0;
   double minBuy=999999,maxSell=0;
   double lastBuyVolume=0,lastSellVolume=0;

   for(int i=PositionsTotal()-1;i>=0;i--)
   {
      if(PositionGetSymbol(i)==_Symbol &&
         PositionGetInteger(POSITION_MAGIC)==MagicNumber)
      {
         totalPL+=PositionGetDouble(POSITION_PROFIT);

         double openPrice=PositionGetDouble(POSITION_PRICE_OPEN);
         double vol=PositionGetDouble(POSITION_VOLUME);

         if(PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_BUY)
         {
            buys++;
            if(openPrice<minBuy)
            {
               minBuy=openPrice;
               lastBuyVolume=vol;
            }
         }
         else
         {
            sells++;
            if(openPrice>maxSell)
            {
               maxSell=openPrice;
               lastSellVolume=vol;
            }
         }
      }
   }

   if(totalPL>=TargetProfit && (buys>0 || sells>0))
   {
      CloseAll();
      return;
   }

   if(totalPL<=-MaxRisk)
   {
      CloseAll();
      return;
   }

   MqlDateTime dt;
   TimeTradeServer(dt);
   if(dt.hour==MarketCloseHour) return;
   if(PauseDuringNews && dt.hour==NewsHoursUTC) return;

   double balance=AccountInfoDouble(ACCOUNT_BALANCE);
   double dynamicLot = (balance/1000.0)*LotPer1000;
   dynamicLot = GetSafeLot(dynamicLot);

   double Ask=SymbolInfoDouble(_Symbol,SYMBOL_ASK);
   double Bid=SymbolInfoDouble(_Symbol,SYMBOL_BID);

   // INITIAL ENTRY
   if(buys==0 && sells==0)
   {
      double emaVal[1],rsiVal[1];
      if(CopyBuffer(emaHandle,0,0,1,emaVal)<=0) return;
      if(CopyBuffer(rsiHandle,0,0,1,rsiVal)<=0) return;

      if(Bid>emaVal[0] && rsiVal[0]>RSILower)
      {
         if(CanOpenTrade(dynamicLot))
            trade.Buy(dynamicLot,_Symbol,0,0,0);
      }
      else if(Bid<emaVal[0] && rsiVal[0]<RSIUpper)
      {
         if(CanOpenTrade(dynamicLot))
            trade.Sell(dynamicLot,_Symbol,0,0,0);
      }
      return;
   }

   double gap=GridStep*SymbolInfoDouble(_Symbol,SYMBOL_POINT);

   // BUY GRID
   if(buys>0 && (minBuy-Ask)>gap)
   {
      double nextLot = GetSafeLot(lastBuyVolume*Multiplier);

      if(buys<3 && CanOpenTrade(nextLot))
         trade.Buy(nextLot,_Symbol,0,0,0);
   }

   // SELL GRID
   if(sells>0 && (Bid-maxSell)>gap)
   {
      double nextLot = GetSafeLot(lastSellVolume*Multiplier);

      if(sells<3 && CanOpenTrade(nextLot))
         trade.Sell(nextLot,_Symbol,0,0,0);
   }
}
//+------------------------------------------------------------------+
void CloseAll()
{
   for(int i=PositionsTotal()-1;i>=0;i--)
   {
      if(PositionGetSymbol(i)==_Symbol &&
         PositionGetInteger(POSITION_MAGIC)==MagicNumber)
      {
         trade.PositionClose(PositionGetInteger(POSITION_TICKET));
      }
   }
}
//+------------------------------------------------------------------+