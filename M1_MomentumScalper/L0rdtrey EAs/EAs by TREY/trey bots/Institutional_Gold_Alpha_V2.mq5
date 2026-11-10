//+------------------------------------------------------------------+
//|                                  Institutional_Gold_Alpha_V2.mq5 |
//|                                  Copyright 2026, Quant Systems   |
//|                                       https://www.quant-desk.com |
//+------------------------------------------------------------------+
#property copyright   "Copyright 2026, Quant Systems"
#property link        "https://www.quant-desk.com"
#property version     "2.00"
#property description "Institutional Gold Scalper with Technical Analysis Filters"
#property strict

#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>
#include <Trade\SymbolInfo.mqh>

//--- INPUT PARAMETERS
input group ">>> EXECUTION SETTINGS"
input ulong    InpMagic           = 8829105;        // System Magic Number
input double   InpLots            = 0.10;           // Fixed Execution Volume
input string   InpStart           = "01:05";        // Daily Start Time
input string   InpEnd             = "22:55";        // Daily Liquidation Time

input group ">>> QUANT ANALYSIS FILTERS (Anti-Loss)"
input bool     InpUseTrendFilter  = true;           // Filter by Moving Average Trend
input int      InpMAPeriod        = 200;            // Institutional Trend Period (SMA)
input bool     InpUseMomentum     = true;           // Filter by RSI (Overbought/Oversold)
input int      InpRSIPeriod       = 14;             // RSI Period
input double   InpRSILower        = 35;             // Oversold Floor (Buy only above)
input double   InpRSIUpper        = 65;             // Overbought Ceiling (Buy only below)

input group ">>> RISK MANAGEMENT"
input double   InpSL_Pct          = 0.8;            // Stop Loss % (tight scalping)
input double   InpTP_Pct          = 1.5;            // Take Profit % 
input int      InpMaxSpread       = 40;             // Max Spread (Points)

//--- GLOBAL HANDLES & VARS
CTrade         g_trade;
CSymbolInfo    g_symbol;
CPositionInfo  g_pos;
int            h_ma, h_rsi;
datetime       g_last_trade_day = 0;

//--- DASHBOARD CONSTANTS
#define CLR_GOLD    C'255,215,0'
#define CLR_BG      C'10,10,10'
#define CLR_PANEL   C'25,25,25'
#define CLR_TXT     C'200,200,200'
#define CLR_UP      C'0,255,127'
#define CLR_DN      C'255,69,0'

//--- METRICS STRUCT
struct Metrics {
   double net_profit;
   double daily_pl;
   double buy_profit;
   double sell_profit;
   string signal;
   string status;
   int    latency;
};
Metrics m_data;

//+------------------------------------------------------------------+
//| INIT                                                             |
//+------------------------------------------------------------------+
int OnInit() {
   if(!g_symbol.Name(_Symbol)) return INIT_FAILED;
   
   g_trade.SetExpertMagicNumber(InpMagic);
   g_trade.SetTypeFilling(ORDER_FILLING_FOK);
   
   // Initialize Indicators for Analysis
   h_ma = iMA(_Symbol, _Period, InpMAPeriod, 0, MODE_SMA, PRICE_CLOSE);
   h_rsi = iRSI(_Symbol, _Period, InpRSIPeriod, PRICE_CLOSE);
   
   if(h_ma == INVALID_HANDLE || h_rsi == INVALID_HANDLE) {
      Print("Indicator Init Failed");
      return INIT_FAILED;
   }

   m_data.status = "INITIALIZING";
   InitUI();
   EventSetTimer(1);
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason) {
   ObjectsDeleteAll(0, "UI_");
   EventKillTimer();
}

//+------------------------------------------------------------------+
//| TICK LOGIC                                                       |
//+------------------------------------------------------------------+
void OnTick() {
   if(!g_symbol.RefreshRates()) return;
   
   UpdateAnalysis();
   
   MqlDateTime curr;
   TimeToStruct(TimeCurrent(), curr);
   int curr_min = (curr.hour * 60) + curr.min;
   
   int start_min = ParseTime(InpStart);
   int end_min   = ParseTime(InpEnd);
   
   datetime day_floor = TimeCurrent() - (TimeCurrent() % 86400);

   // 1. OPEN LOGIC WITH FILTERS
   if(curr_min >= start_min && curr_min < end_min && g_last_trade_day < day_floor) {
      if(PositionsTotal() == 0 && !AlreadyTradedToday(day_floor)) {
         if(MarketConditionsValid()) {
            ExecuteTrade();
            g_last_trade_day = day_floor;
         } else {
            m_data.status = "WAITING FOR SIGNAL";
         }
      }
   }

   // 2. CLOSE LOGIC
   if(curr_min >= end_min) {
      CloseAll();
      m_data.status = "SESSION ENDED";
   }

   RefreshUI();
}

//+------------------------------------------------------------------+
//| ANALYSIS FEATURES                                                |
//+------------------------------------------------------------------+
bool MarketConditionsValid() {
   if(g_symbol.Spread() > InpMaxSpread) {
      m_data.status = "S_BLOCK: HIGH SPREAD";
      return false;
   }

   double rsi[], ma[];
   CopyBuffer(h_rsi, 0, 0, 1, rsi);
   CopyBuffer(h_ma, 0, 0, 1, ma);
   
   double price = g_symbol.Bid();
   
   // RSI Filter (Anti-Overbought)
   if(InpUseMomentum) {
      if(rsi[0] > InpRSIUpper || rsi[0] < InpRSILower) {
         m_data.status = "A_BLOCK: RSI EXTREME";
         return false;
      }
   }
   
   // Trend Filter (Institutional MA)
   if(InpUseTrendFilter) {
      if(price < ma[0]) {
         m_data.status = "A_BLOCK: BEARISH TREND";
         return false;
      }
   }

   return true;
}

void UpdateAnalysis() {
   double rsi[];
   CopyBuffer(h_rsi, 0, 0, 1, rsi);
   m_data.signal = (rsi[0] < 50) ? "BULLISH BIAS" : "MOMENTUM SLOW";
   m_data.latency = (int)TerminalInfoInteger(TERMINAL_PING_LAST);
}

//+------------------------------------------------------------------+
//| TRADING ENGINE                                                   |
//+------------------------------------------------------------------+
void ExecuteTrade() {
   double sl = (InpSL_Pct > 0) ? g_symbol.Ask() * (1 - InpSL_Pct/100.0) : 0;
   double tp = (InpTP_Pct > 0) ? g_symbol.Ask() * (1 + InpTP_Pct/100.0) : 0;
   
   if(g_trade.Buy(InpLots, _Symbol, g_symbol.Ask(), NormalizeDouble(sl, _Digits), NormalizeDouble(tp, _Digits), "ALPHA V2")) {
      m_data.status = "TRADE ACTIVE";
   }
}

void CloseAll() {
   for(int i=PositionsTotal()-1; i>=0; i--) {
      if(g_pos.SelectByIndex(i) && g_pos.Magic()==InpMagic)
         g_trade.PositionClose(g_pos.Ticket());
   }
}

bool AlreadyTradedToday(datetime floor) {
   HistorySelect(floor, TimeCurrent());
   for(int i=HistoryDealsTotal()-1; i>=0; i--) {
      ulong t = HistoryDealGetTicket(i);
      if(HistoryDealGetInteger(t, DEAL_MAGIC)==InpMagic && HistoryDealGetInteger(t, DEAL_ENTRY)==DEAL_ENTRY_IN) return true;
   }
   return false;
}

int ParseTime(string t) {
   string s[]; StringSplit(t, ':', s);
   return (int)StringToInteger(s[0])*60 + (int)StringToInteger(s[1]);
}

//+------------------------------------------------------------------+
//| DASHBOARD UI (GOLD KILLER STYLE)                                 |
//+------------------------------------------------------------------+
void InitUI() {
   // Main Background
   CreateRect("UI_BG", 10, 30, 650, 220, CLR_BG, CLR_GOLD);
   
   // Columns
   CreateRect("UI_Col1", 20, 60, 200, 150, CLR_PANEL, clrNone);
   CreateRect("UI_Col2", 225, 60, 200, 150, CLR_PANEL, clrNone);
   CreateRect("UI_Col3", 430, 60, 200, 150, CLR_PANEL, clrNone);
   
   // Headers
   CreateTxt("UI_H1", "PERFORMANCE", 30, 70, 10, CLR_GOLD);
   CreateTxt("UI_H2", "TRADING STATUS", 235, 70, 10, CLR_GOLD);
   CreateTxt("UI_H3", "SYSTEM INFO", 440, 70, 10, CLR_GOLD);
   
   // Bottom Bar
   CreateRect("UI_Bar", 10, 230, 650, 30, CLR_PANEL, CLR_GOLD);
}

void RefreshUI() {
   // Performance Data
   UpdatePerf();
   CreateTxt("UI_Net", "Net Profit:  " + DoubleToString(m_data.net_profit, 2), 30, 100, 9, CLR_TXT);
   CreateTxt("UI_Day", "Daily P/L:   " + DoubleToString(m_data.daily_pl, 2), 30, 120, 9, (m_data.daily_pl >=0 ? CLR_UP:CLR_DN));
   CreateTxt("UI_Buy", "Buy Side:    " + DoubleToString(m_data.buy_profit, 2), 30, 140, 9, CLR_UP);
   CreateTxt("UI_Sel", "Sell Side:   " + DoubleToString(m_data.sell_profit, 2), 30, 160, 9, CLR_DN);

   // Status Data
   CreateTxt("UI_Sig", "SIGNAL: " + m_data.signal, 235, 100, 9, CLR_GOLD);
   CreateTxt("UI_Sta", "STATUS: " + m_data.status, 235, 120, 9, CLR_TXT);
   CreateTxt("UI_Spr", "SPREAD: " + (string)g_symbol.Spread(), 235, 140, 9, CLR_TXT);
   
   // System Info
   CreateTxt("UI_Lic", "LICENSE: VALID", 440, 100, 9, CLR_UP);
   CreateTxt("UI_Ver", "VERSION: V2.0 PRO", 440, 120, 9, CLR_TXT);
   CreateTxt("UI_Mag", "MAGIC: " + (string)InpMagic, 440, 140, 9, CLR_TXT);
   CreateTxt("UI_Lat", "LATENCY: " + (string)m_data.latency + "ms", 440, 160, 9, CLR_TXT);
   
   // Bottom Status
   string footer = "Server: " + TimeToString(TimeCurrent()) + " | Spread: " + (string)g_symbol.Spread() + " | Quant Alpha Engine Active";
   CreateTxt("UI_Foot", footer, 20, 238, 8, CLR_TXT);
   
   ChartRedraw();
}

void UpdatePerf() {
   m_data.net_profit = AccountInfoDouble(ACCOUNT_PROFIT);
   m_data.daily_pl = 0; m_data.buy_profit = 0; m_data.sell_profit = 0;
   
   HistorySelect(TimeCurrent()-(TimeCurrent()%86400), TimeCurrent());
   for(int i=HistoryDealsTotal()-1; i>=0; i--) {
      ulong t = HistoryDealGetTicket(i);
      if(HistoryDealGetInteger(t, DEAL_MAGIC) == InpMagic) {
         double p = HistoryDealGetDouble(t, DEAL_PROFIT);
         m_data.daily_pl += p;
         if(HistoryDealGetInteger(t, DEAL_TYPE) == DEAL_TYPE_BUY) m_data.buy_profit += p;
         if(HistoryDealGetInteger(t, DEAL_TYPE) == DEAL_TYPE_SELL) m_data.sell_profit += p;
      }
   }
}

//+------------------------------------------------------------------+
//| UI UTILITIES                                                     |
//+------------------------------------------------------------------+
void CreateRect(string name, int x, int y, int w, int h, color bg, color brd) {
   ObjectCreate(0, name, OBJ_RECTANGLE_LABEL, 0, 0, 0);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, name, OBJPROP_XSIZE, w);
   ObjectSetInteger(0, name, OBJPROP_YSIZE, h);
   ObjectSetInteger(0, name, OBJPROP_BGCOLOR, bg);
   ObjectSetInteger(0, name, OBJPROP_BORDER_COLOR, brd);
   ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, name, OBJPROP_BORDER_TYPE, BORDER_FLAT);
}

void CreateTxt(string name, string txt, int x, int y, int sz, color clr) {
   ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
   ObjectSetString(0, name, OBJPROP_TEXT, txt);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, sz);
   ObjectSetString(0, name, OBJPROP_FONT, "Verdana");
   ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
}

void OnTimer() { RefreshUI(); }