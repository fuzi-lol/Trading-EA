//+------------------------------------------------------------------+
//|                                     ForexSniperPro_V3_Matrix.mq5 |
//|        FOREX SNIPER PRO V3 — Institutional & Macro Engine        |
//|  Market Profile | MTF Matrix | DXY/Yields | News Intelligence    |
//+------------------------------------------------------------------+
#property copyright   "ForexSniperPro V3 — Macro & Institutional"
#property version     "3.00"
#property description "MTF Matrix, Market Profile, DXY/Yields, News, SMC"
#property indicator_chart_window
#property indicator_buffers 9
#property indicator_plots   5

//--- Signal arrows
#property indicator_label1  "BUY Signal"
#property indicator_type1   DRAW_ARROW
#property indicator_color1  clrDodgerBlue
#property indicator_width1  3
#property indicator_label2  "SELL Signal"
#property indicator_type2   DRAW_ARROW
#property indicator_color2  clrMagenta
#property indicator_width2  3
#property indicator_label3  "STRONG BUY"
#property indicator_type3   DRAW_ARROW
#property indicator_color3  clrCyan
#property indicator_width3  4
#property indicator_label4  "STRONG SELL"
#property indicator_type4   DRAW_ARROW
#property indicator_color4  clrOrangeRed
#property indicator_width4  4

//--- POC (Point of Control)
#property indicator_label5  "Volume POC"
#property indicator_type5   DRAW_LINE
#property indicator_color5  clrGold
#property indicator_style5  STYLE_SOLID
#property indicator_width5  2

//+------------------------------------------------------------------+
//| INPUT GROUPS                                                     |
//+------------------------------------------------------------------+
input group           "=== Signal Engine ==="
input int             InpATRPeriod         = 14;
input double          InpATRSLMult         = 1.5;

input group           "=== Macro & Yield Intelligence ==="
input bool            InpUseMacro          = true;      // Enable DXY/Yield Correlation
input string          InpDXYSymbol         = "DXY";     // US Dollar Index Symbol (Broker specific)
input string          InpYieldSymbol       = "US10Y";   // US 10Y Yield Symbol (Broker specific)

input group           "=== News Intelligence ==="
input bool            InpUseNews           = true;      // Enable Economic Calendar filtering
input int             InpNewsBufferMins    = 30;        // Block signals X mins before/after High Impact News

input group           "=== Market Profile ==="
input bool            InpShowPOC           = true;      // Show Point of Control (Volume Profile)
input int             InpProfileLookback   = 100;       // Bars to calculate Market Profile

input group           "=== Market Structure & Liquidity ==="
input int             InpStructLookback    = 5;
input int             InpLiqLookback       = 50;

input group           "=== Dashboard V3 (MTF Matrix) ==="
input bool            InpShowDashboard     = true;
input ENUM_BASE_CORNER InpDashCorner       = CORNER_LEFT_UPPER;
input int             InpDashX             = 10;
input int             InpDashY             = 20;

//+------------------------------------------------------------------+
//| BUFFERS & GLOBALS                                                |
//+------------------------------------------------------------------+
double BuyBuffer[], SellBuffer[], StrongBuyBuffer[], StrongSellBuffer[];
double POCBuffer[], SuperTrendBuf[], ATRBuf[], RSIBuf[], ADXBuf[];

int hATR, hRSI, hADX, hEMA50, hEMA200;
double g_finalScore = 0;
string g_signalClass = "IGNORE";
int g_overallDirGlobal = 0;

// Macro variables
int g_macroBias = 0; // 1 = Bullish for pair, -1 = Bearish for pair, 0 = Neutral
string g_macroReason = "NO MACRO DATA";

// News variables
bool g_isNewsEmbargo = false;
string g_nextNewsEvent = "NONE";

// MTF Matrix State
struct MTFData {
   ENUM_TIMEFRAMES tf;
   string name;
   int trendBias;    // 1 Bull, -1 Bear
   int rsiBias;      // 1 Bull, -1 Bear
   string signal;    // "BUY", "SELL", "WAIT"
   color col;
};
MTFData mtfMatrix[4];

//+------------------------------------------------------------------+
//| OnInit                                                           |
//+------------------------------------------------------------------+
int OnInit()
  {
   SetIndexBuffer(0, BuyBuffer, INDICATOR_DATA);
   SetIndexBuffer(1, SellBuffer, INDICATOR_DATA);
   SetIndexBuffer(2, StrongBuyBuffer, INDICATOR_DATA);
   SetIndexBuffer(3, StrongSellBuffer, INDICATOR_DATA);
   SetIndexBuffer(4, POCBuffer, INDICATOR_DATA);
   SetIndexBuffer(5, SuperTrendBuf, INDICATOR_CALCULATIONS);
   SetIndexBuffer(6, ATRBuf, INDICATOR_CALCULATIONS);
   SetIndexBuffer(7, RSIBuf, INDICATOR_CALCULATIONS);
   SetIndexBuffer(8, ADXBuf, INDICATOR_CALCULATIONS);

   PlotIndexSetInteger(0, PLOT_ARROW, 233);
   PlotIndexSetInteger(1, PLOT_ARROW, 234);
   PlotIndexSetInteger(2, PLOT_ARROW, 233);
   PlotIndexSetInteger(3, PLOT_ARROW, 234);

   hATR = iATR(_Symbol, PERIOD_CURRENT, InpATRPeriod);
   hRSI = iRSI(_Symbol, PERIOD_CURRENT, 14, PRICE_CLOSE);
   hADX = iADX(_Symbol, PERIOD_CURRENT, 14);
   hEMA50 = iMA(_Symbol, PERIOD_CURRENT, 50, 0, MODE_EMA, PRICE_CLOSE);
   hEMA200 = iMA(_Symbol, PERIOD_CURRENT, 200, 0, MODE_EMA, PRICE_CLOSE);

   mtfMatrix[0].tf = PERIOD_M15; mtfMatrix[0].name = "M15";
   mtfMatrix[1].tf = PERIOD_H1;  mtfMatrix[1].name = "H1 ";
   mtfMatrix[2].tf = PERIOD_H4;  mtfMatrix[2].name = "H4 ";
   mtfMatrix[3].tf = PERIOD_D1;  mtfMatrix[3].name = "D1 ";

   return(INIT_SUCCEEDED);
  }

void OnDeinit(const int reason) { ObjectsDeleteAll(0, "FSP_"); }

//+------------------------------------------------------------------+
//| MACRO ENGINE (DXY & US10Y Correlation)                           |
//+------------------------------------------------------------------+
void UpdateMacroEngine()
  {
   if(!InpUseMacro) return;
   
   // Check if pair has USD as quote (EURUSD) or base (USDJPY)
   bool isUSDQuote = (StringFind(_Symbol, "USD") == 3);
   bool isUSDBase  = (StringFind(_Symbol, "USD") == 0);
   
   if(!isUSDQuote && !isUSDBase) {
      g_macroBias = 0; g_macroReason = "NON-USD PAIR"; return;
   }

   double dxyClose[1], dxyEMA[1];
   double yldClose[1], yldEMA[1];
   
   int hDXY_EMA = iMA(InpDXYSymbol, PERIOD_D1, 50, 0, MODE_EMA, PRICE_CLOSE);
   int hYLD_EMA = iMA(InpYieldSymbol, PERIOD_D1, 50, 0, MODE_EMA, PRICE_CLOSE);
   
   if(hDXY_EMA != INVALID_HANDLE && hYLD_EMA != INVALID_HANDLE)
     {
      CopyClose(InpDXYSymbol, PERIOD_D1, 0, 1, dxyClose);
      CopyBuffer(hDXY_EMA, 0, 0, 1, dxyEMA);
      CopyClose(InpYieldSymbol, PERIOD_D1, 0, 1, yldClose);
      CopyBuffer(hYLD_EMA, 0, 0, 1, yldEMA);
      
      bool dxyBullish = dxyClose[0] > dxyEMA[0];
      bool yldBullish = yldClose[0] > yldEMA[0];
      
      int dxyStrength = (dxyBullish ? 1 : -1) + (yldBullish ? 1 : -1);
      
      if(isUSDQuote) {
         // If DXY is strong, EURUSD goes down
         g_macroBias = -dxyStrength; 
      } else if(isUSDBase) {
         // If DXY is strong, USDJPY goes up
         g_macroBias = dxyStrength;
      }
      
      if(g_macroBias > 0) g_macroReason = "MACRO TAILWIND (BULL)";
      else if(g_macroBias < 0) g_macroReason = "MACRO HEADWIND (BEAR)";
      else g_macroReason = "MACRO NEUTRAL";
     }
   else g_macroReason = "MACRO SYMBOLS N/A";
  }

//+------------------------------------------------------------------+
//| NEWS INTELLIGENCE ENGINE                                         |
//+------------------------------------------------------------------+
void UpdateNewsEngine(datetime currentTime)
  {
   if(!InpUseNews) return;
   g_isNewsEmbargo = false;
   
   MqlCalendarEvent event;
   MqlCalendarValue values[];
   
   // Check news from 2 hours ago to 2 hours ahead
   datetime from = currentTime - 7200;
   datetime to = currentTime + 7200;
   
   // Filter for US events as a proxy using correct MQL5 function
   int count = CalendarValueHistory(values, from, to, "US");
   
   if(count > 0)
     {
      for(int i=0; i<count; i++)
        {
         if(CalendarEventById(values[i].event_id, event))
           {
            if(event.importance == CALENDAR_IMPORTANCE_HIGH)
              {
               datetime eventTime = values[i].time;
               long diff = (long)MathAbs((double)(currentTime - eventTime));
               
               if(diff <= InpNewsBufferMins * 60) {
                  g_isNewsEmbargo = true;
                  g_nextNewsEvent = event.name;
                  return; // Embargo active, stop checking
               } else if (eventTime > currentTime && eventTime - currentTime < 14400) {
                  g_nextNewsEvent = event.name; // Next upcoming
               }
              }
           }
        }
     }
  }

//+------------------------------------------------------------------+
//| MARKET PROFILE (VOLUME POC) ENGINE                               |
//+------------------------------------------------------------------+
double CalculatePOC(int startIdx, const double &high[], const double &low[], const long &tickVol[])
  {
   if(!InpShowPOC) return 0.0;
   
   double highestPrice = 0;
   double lowestPrice = DBL_MAX;
   int endIdx = startIdx + InpProfileLookback;
   
   // Find high/low range
   for(int i = startIdx; i < endIdx; i++) {
      if(high[i] > highestPrice) highestPrice = high[i];
      if(low[i] < lowestPrice) lowestPrice = low[i];
   }
   
   if(highestPrice <= lowestPrice) return 0.0;
   
   // Create 50 bins
   int numBins = 50;
   double binSize = (highestPrice - lowestPrice) / numBins;
   double volumeProfile[];
   ArrayResize(volumeProfile, numBins);
   ArrayInitialize(volumeProfile, 0);
   
   // Accumulate volume
   for(int i = startIdx; i < endIdx; i++) {
      double avgPrice = (high[i] + low[i]) / 2.0;
      int binIdx = (int)((avgPrice - lowestPrice) / binSize);
      if(binIdx >= numBins) binIdx = numBins - 1;
      if(binIdx < 0) binIdx = 0;
      
      // Fixed data loss warning here: explicit cast to double
      volumeProfile[binIdx] += (double)tickVol[i];
   }
   
   // Find Point of Control
   double maxVol = 0;
   int pocBin = 0;
   for(int b = 0; b < numBins; b++) {
      if(volumeProfile[b] > maxVol) {
         maxVol = volumeProfile[b];
         pocBin = b;
      }
   }
   
   return lowestPrice + (pocBin * binSize) + (binSize / 2.0);
  }

//+------------------------------------------------------------------+
//| MTF SCANNER MATRIX                                               |
//+------------------------------------------------------------------+
void UpdateMTFMatrix()
  {
   for(int i=0; i<4; i++)
     {
      double ema50[1], ema200[1], rsi[1], closeArr[1];
      
      int hE50 = iMA(_Symbol, mtfMatrix[i].tf, 50, 0, MODE_EMA, PRICE_CLOSE);
      int hE200= iMA(_Symbol, mtfMatrix[i].tf, 200, 0, MODE_EMA, PRICE_CLOSE);
      int hR = iRSI(_Symbol, mtfMatrix[i].tf, 14, PRICE_CLOSE);
      
      if (CopyBuffer(hE50, 0, 0, 1, ema50) <= 0) continue;
      if (CopyBuffer(hE200, 0, 0, 1, ema200) <= 0) continue;
      if (CopyBuffer(hR, 0, 0, 1, rsi) <= 0) continue;
      if (CopyClose(_Symbol, mtfMatrix[i].tf, 0, 1, closeArr) <= 0) continue;
      
      // Trend Logic
      if(closeArr[0] > ema50[0] && ema50[0] > ema200[0]) mtfMatrix[i].trendBias = 1;
      else if(closeArr[0] < ema50[0] && ema50[0] < ema200[0]) mtfMatrix[i].trendBias = -1;
      else mtfMatrix[i].trendBias = 0;
      
      // RSI Logic
      if(rsi[0] > 55) mtfMatrix[i].rsiBias = 1;
      else if(rsi[0] < 45) mtfMatrix[i].rsiBias = -1;
      else mtfMatrix[i].rsiBias = 0;
      
      // Combine into Matrix Signal
      int sum = mtfMatrix[i].trendBias + mtfMatrix[i].rsiBias;
      if(sum == 2) { mtfMatrix[i].signal = "BUY"; mtfMatrix[i].col = clrLime; }
      else if(sum == -2) { mtfMatrix[i].signal = "SELL"; mtfMatrix[i].col = clrRed; }
      else { mtfMatrix[i].signal = "WAIT"; mtfMatrix[i].col = clrGray; }
     }
  }

//+------------------------------------------------------------------+
//| DASHBOARD MATRIX V3                                              |
//+------------------------------------------------------------------+
void DrawLabel(string name, string text, int x, int y, color clr, int size, string font="Consolas")
  {
   if(ObjectFind(0,name)<0) ObjectCreate(0,name,OBJ_LABEL,0,0,0);
   ObjectSetInteger(0,name,OBJPROP_CORNER,InpDashCorner);
   ObjectSetInteger(0,name,OBJPROP_XDISTANCE,x);
   ObjectSetInteger(0,name,OBJPROP_YDISTANCE,y);
   ObjectSetInteger(0,name,OBJPROP_COLOR,clr);
   ObjectSetInteger(0,name,OBJPROP_FONTSIZE,size);
   ObjectSetString(0,name,OBJPROP_FONT,font);
   ObjectSetString(0,name,OBJPROP_TEXT,text);
   ObjectSetInteger(0,name,OBJPROP_HIDDEN,true);
  }

void UpdateDashboardV3(double currentPOC)
  {
   if(!InpShowDashboard) return;
   int x = InpDashX, y = InpDashY;
   
   // Background
   if(ObjectFind(0,"FSP_BG")<0) ObjectCreate(0,"FSP_BG",OBJ_RECTANGLE_LABEL,0,0,0);
   ObjectSetInteger(0,"FSP_BG",OBJPROP_XDISTANCE,x);
   ObjectSetInteger(0,"FSP_BG",OBJPROP_YDISTANCE,y);
   ObjectSetInteger(0,"FSP_BG",OBJPROP_XSIZE, 400);
   ObjectSetInteger(0,"FSP_BG",OBJPROP_YSIZE, 320);
   ObjectSetInteger(0,"FSP_BG",OBJPROP_BGCOLOR, clrBlack);
   ObjectSetInteger(0,"FSP_BG",OBJPROP_COLOR, clrAqua);
   ObjectSetInteger(0,"FSP_BG",OBJPROP_HIDDEN, true);

   // Title
   DrawLabel("L_T1", "FOREX SNIPER PRO V3 MATRIX", x+20, y+10, clrGold, 12, "Arial Bold");
   DrawLabel("L_T2", _Symbol + " | " + EnumToString((ENUM_TIMEFRAMES)Period()), x+20, y+30, clrWhite, 10);

   // News & Macro Section
   int my = y + 60;
   DrawLabel("L_M1", "--- MACRO & NEWS INTELLIGENCE ---", x+20, my, clrAqua, 10);
   DrawLabel("L_M2", "MACRO BIAS: " + g_macroReason, x+20, my+20, (g_macroBias>0?clrLime:(g_macroBias<0?clrRed:clrGray)), 10);
   
   string newsTxt = g_isNewsEmbargo ? "EMBARGO ACTIVE (NO TRADE)" : "CLEAR";
   color newsCol = g_isNewsEmbargo ? clrOrangeRed : clrLime;
   DrawLabel("L_M3", "NEWS STATE: " + newsTxt, x+20, my+40, newsCol, 10);
   DrawLabel("L_M4", "NEXT EVENT: " + g_nextNewsEvent, x+20, my+60, clrWhite, 9);
   
   DrawLabel("L_POC", "VOL POC: " + DoubleToString(currentPOC, _Digits), x+240, my+20, clrGold, 10);

   // MTF Matrix Table
   int ty = my + 100;
   DrawLabel("L_MTF_T", "--- MTF SIGNAL MATRIX ---", x+20, ty, clrAqua, 10);
   DrawLabel("L_MTF_H", "TF    | TREND | RSI  | SIGNAL", x+20, ty+20, clrGray, 10);
   
   for(int i=0; i<4; i++) {
      int ry = ty + 40 + (i*20);
      string tTxt = mtfMatrix[i].trendBias > 0 ? "BULL " : (mtfMatrix[i].trendBias < 0 ? "BEAR " : "NEUT ");
      string rTxt = mtfMatrix[i].rsiBias > 0 ? "BULL " : (mtfMatrix[i].rsiBias < 0 ? "BEAR " : "NEUT ");
      string rowStr = mtfMatrix[i].name + "   | " + tTxt + "| " + rTxt + "| " + mtfMatrix[i].signal;
      DrawLabel("L_MTF_R"+IntegerToString(i), rowStr, x+20, ry, mtfMatrix[i].col, 10);
   }
  }

//+------------------------------------------------------------------+
//| OnCalculate - MAIN LOOP                                          |
//+------------------------------------------------------------------+
int OnCalculate(const int rates_total, const int prev_calculated,
                const datetime &time[], const double &open[],
                const double &high[], const double &low[], const double &close[],
                const long &tick_volume[], const long &volume[], const int &spread[])
  {
   if(rates_total < InpProfileLookback + 50) return(0);

   ArraySetAsSeries(time, true);
   ArraySetAsSeries(open, true);
   ArraySetAsSeries(high, true);
   ArraySetAsSeries(low, true);
   ArraySetAsSeries(close, true);
   ArraySetAsSeries(tick_volume, true);

   // Update Engines (throttled to new bars or specific intervals)
   static datetime lastUpdate = 0;
   if(time[0] != lastUpdate)
     {
      UpdateMacroEngine();
      UpdateNewsEngine(time[0]);
      UpdateMTFMatrix();
      lastUpdate = time[0];
     }

   // Incremental calculations
   int start = (prev_calculated > 0) ? rates_total - prev_calculated : rates_total - InpProfileLookback;
   if(start > rates_total - 1) start = rates_total - 1;

   for(int i = start; i >= 0; i--)
     {
      BuyBuffer[i]=0; SellBuffer[i]=0; StrongBuyBuffer[i]=0; StrongSellBuffer[i]=0;
      
      // Calculate Point of Control (Market Profile)
      if(i < rates_total - InpProfileLookback) {
         POCBuffer[i] = CalculatePOC(i, high, low, tick_volume);
      } else {
         POCBuffer[i] = 0;
      }
      
      // Example Signal Generation Logic (Simplified SMC/Structure proxy for demo)
      if(i == 1 && !g_isNewsEmbargo) // Check on closed bar
        {
         // Matrix Alignment Check
         int mtfScore = 0;
         for(int m=0; m<4; m++) {
            if(mtfMatrix[m].signal == "BUY") mtfScore++;
            else if(mtfMatrix[m].signal == "SELL") mtfScore--;
         }
         
         // Only signal if Macro aligns and MTF confirms
         if(mtfScore >= 2 && g_macroBias >= 0) {
            StrongBuyBuffer[i] = low[i] - (high[i]-low[i]);
         }
         else if(mtfScore <= -2 && g_macroBias <= 0) {
            StrongSellBuffer[i] = high[i] + (high[i]-low[i]);
         }
        }
     }

   UpdateDashboardV3(POCBuffer[0]);
   return(rates_total);
  }
//+------------------------------------------------------------------+