//+------------------------------------------------------------------+
//|                                               candle scalper.mq5 |
//|                                  Copyright 2026, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.00"

#include <Trade/Trade.mqh>
CTrade trade;

input double Lot = 0.1;
input double RRR = 2;
datetime last_time =0;
double stop_l:
double take_p:
//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
//---
   
//---
   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
//---
   
  }
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
//---
   double open = iOpen(_Symbol,_Period,1)
   double close = iClose(_Symbol,_Period,1)
   double High = iHigh(_Symbol,_Period,1)
   double low = iLow(_Symbol,_Period,1)
   
   datetime Current_time = iTime(_Symbol,PERIOD_CURRENT,0);
   double ask_price = SymbolInfoDouble(_Symbol,SYMBOL_ASK,0);
   
   if(close > open && Current_time !=last_time)
   (
   stop_l = low;
   take_p = ask_price + ((ask_price - stop_l) * RRR);
   
   trade.sell(Lot,_Symbol,ask_price,stop_l,take_p);
   last_time = Current_time;
   
   
   
   
  }
//+------------------------------------------------------------------+
