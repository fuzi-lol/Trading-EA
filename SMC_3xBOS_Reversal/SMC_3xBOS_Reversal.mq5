//+------------------------------------------------------------------+
//| SMC_3xBOS_Reversal.mq5                                          |
//| Strategy 3: HTF 3x BOS Reversal (ChoCh + FVG) + LTF IFVG       |
//| HTF: H1/H4 for reversal, LTF: M15/M5 for entry                 |
//+------------------------------------------------------------------+
#property copyright   "Trading EAs"
#property version     "1.00"
#property description "HTF 3x BOS exhaustion → ChoCh reversal → FVG + LTF IFVG entry"

#include <Trade\Trade.mqh>

//--- Inputs
input group "=== Timeframes ==="
input ENUM_TIMEFRAMES HTF            = PERIOD_H1;    // Higher Timeframe
input ENUM_TIMEFRAMES LTF            = PERIOD_M5;    // Lower Timeframe

input group "=== Structure Detection ==="
input int     SwingBars              = 5;            // Swing detection lookback
input int     HTF_Lookback           = 150;          // HTF bars to scan
input int     LTF_Lookback           = 50;           // LTF bars to scan
input int     RequiredBOS            = 3;            // Consecutive BOS needed (3 = reversal signal)

input group "=== FVG ==="
input int     FVG_MinPoints          = 50;           // Min FVG gap (points)
input int     IFVG_MaxAge            = 20;           // Max IFVG age (bars)

input group "=== Risk Management ==="
input bool    UseFixedLot            = true;
input double  FixedLot               = 0.10;
input double  RiskPercent            = 1.0;
input int     MaxSLPoints            = 800;          // Max SL (points) - wider for reversal
input int     MinSLPoints            = 80;           // Min SL (points)
input double  MinRR                  = 2.5;          // Min RR (higher for reversals)
input bool    UseTrailing            = true;
input int     TrailPoints            = 250;          // Trail distance

input group "=== Session Filter ==="
input int     StartHour              = 7;
input int     EndHour                = 21;

input group "=== General ==="
input int     MaxTradesPerDay        = 2;            // Max trades (reversals are rare)
input int     CooldownBars           = 10;
input int     MagicNumber            = 100300;

//--- Globals
CTrade        trade;
datetime      g_lastBarTime = 0;
int           g_dailyTrades = 0;
datetime      g_lastTradeDay = 0;
int           g_barsSinceTrade = 999;

struct SwingPoint {
   double price;
   int    barIndex;
};

struct FVGZone {
   double high;
   double low;
   bool   valid;
   int    direction;
};

//+------------------------------------------------------------------+
int OnInit()
{
   trade.SetExpertMagicNumber(MagicNumber);
   trade.SetDeviationInPoints(10);
   trade.SetTypeFilling(ORDER_FILLING_IOC);
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason) {}

//+------------------------------------------------------------------+
void OnTick()
{
   datetime curBar = iTime(_Symbol, LTF, 0);
   if(curBar == g_lastBarTime) return;
   g_lastBarTime = curBar;

   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   datetime today = StringToTime(StringFormat("%04d.%02d.%02d", dt.year, dt.mon, dt.day));
   if(today != g_lastTradeDay) { g_dailyTrades = 0; g_lastTradeDay = today; }
   g_barsSinceTrade++;

   if(HasPosition()) { if(UseTrailing) ManageTrailing(); return; }

   if(g_dailyTrades >= MaxTradesPerDay) return;
   if(dt.hour < StartHour || dt.hour >= EndHour) return;
   if(g_barsSinceTrade < CooldownBars) return;

   // === STRATEGY ===
   // Step 1: Detect 3x BOS in one direction (exhaustion)
   int exhaustionDir = Detect3xBOS();
   if(exhaustionDir == 0) return;

   // Reversal direction is OPPOSITE to exhaustion
   int reversalDir = -exhaustionDir;

   // Step 2: Detect HTF ChoCh (break of the trend)
   if(!DetectHTF_ChoCh(reversalDir)) return;

   // Step 3: Find HTF FVG within the ChoCh expansion
   FVGZone htfFVG;
   if(!FindHTF_FVG(reversalDir, htfFVG)) return;

   // Step 4: Check price is at/near HTF FVG
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(bid < htfFVG.low - 100 * _Point || bid > htfFVG.high + 100 * _Point) return;

   // Step 5: LTF IFVG confirmation
   FVGZone ltfIFVG;
   if(!DetectLTF_IFVG(reversalDir, ltfIFVG)) return;

   // Step 6: Execute reversal trade
   ExecuteTrade(reversalDir, htfFVG, ltfIFVG);
}

//+------------------------------------------------------------------+
// Detect N consecutive BOS in same direction
//+------------------------------------------------------------------+
int Detect3xBOS()
{
   MqlRates htf[];
   ArraySetAsSeries(htf, true);
   if(CopyRates(_Symbol, HTF, 0, HTF_Lookback, htf) < HTF_Lookback) return 0;

   // Collect swing points
   SwingPoint highs[], lows[];
   ArrayResize(highs, 0); ArrayResize(lows, 0);

   for(int i = SwingBars; i < HTF_Lookback - SwingBars; i++) {
      bool isH = true, isL = true;
      for(int j = 1; j <= SwingBars; j++) {
         if(htf[i].high <= htf[i-j].high || htf[i].high <= htf[i+j].high) isH = false;
         if(htf[i].low >= htf[i-j].low || htf[i].low >= htf[i+j].low) isL = false;
      }
      if(isH) { SwingPoint sp; sp.price=htf[i].high; sp.barIndex=i; int s=ArraySize(highs); ArrayResize(highs,s+1); highs[s]=sp; }
      if(isL) { SwingPoint sp; sp.price=htf[i].low; sp.barIndex=i; int s=ArraySize(lows); ArrayResize(lows,s+1); lows[s]=sp; }
      if(ArraySize(highs) >= 6 && ArraySize(lows) >= 6) break;
   }

   if(ArraySize(lows) < RequiredBOS + 1 || ArraySize(highs) < RequiredBOS + 1) return 0;

   // Bearish exhaustion: N consecutive lower lows broken by closes
   int bearishBOS = 0;
   for(int i = 0; i < ArraySize(lows) - 1 && i < 5; i++) {
      bool broken = false;
      for(int j = 1; j < lows[i].barIndex; j++) {
         if(htf[j].close < lows[i].price) { broken = true; break; }
      }
      if(broken) bearishBOS++;
      else break; // Must be consecutive
   }
   if(bearishBOS >= RequiredBOS) return -1; // Bearish exhaustion → expect bullish reversal

   // Bullish exhaustion: N consecutive higher highs broken
   int bullishBOS = 0;
   for(int i = 0; i < ArraySize(highs) - 1 && i < 5; i++) {
      bool broken = false;
      for(int j = 1; j < highs[i].barIndex; j++) {
         if(htf[j].close > highs[i].price) { broken = true; break; }
      }
      if(broken) bullishBOS++;
      else break;
   }
   if(bullishBOS >= RequiredBOS) return 1; // Bullish exhaustion → expect bearish reversal

   return 0;
}

//+------------------------------------------------------------------+
// Detect Change of Character on HTF
//+------------------------------------------------------------------+
bool DetectHTF_ChoCh(int reversalDir)
{
   MqlRates htf[];
   ArraySetAsSeries(htf, true);
   if(CopyRates(_Symbol, HTF, 0, 30, htf) < 20) return false;

   if(reversalDir == 1) {
      // Bullish ChoCh: price was bearish, now broke above recent swing high
      // Find most recent swing high
      for(int i = SwingBars; i < 25; i++) {
         bool isH = true;
         for(int j = 1; j <= SwingBars; j++) {
            if(htf[i].high <= htf[i-j].high || htf[i].high <= htf[i+j].high) { isH = false; break; }
         }
         if(isH) {
            // Check if recent bar closed above it
            if(htf[1].close > htf[i].high || htf[2].close > htf[i].high)
               return true;
         }
      }
   }
   else {
      // Bearish ChoCh
      for(int i = SwingBars; i < 25; i++) {
         bool isL = true;
         for(int j = 1; j <= SwingBars; j++) {
            if(htf[i].low >= htf[i-j].low || htf[i].low >= htf[i+j].low) { isL = false; break; }
         }
         if(isL) {
            if(htf[1].close < htf[i].low || htf[2].close < htf[i].low)
               return true;
         }
      }
   }
   return false;
}

//+------------------------------------------------------------------+
// Find FVG on HTF within the ChoCh expansion
//+------------------------------------------------------------------+
bool FindHTF_FVG(int direction, FVGZone &fvg)
{
   MqlRates htf[];
   ArraySetAsSeries(htf, true);
   if(CopyRates(_Symbol, HTF, 0, 20, htf) < 15) return false;

   fvg.valid = false;

   for(int i = 2; i < 15; i++) {
      if(direction == 1) {
         // Bullish FVG: bar[i-1].low > bar[i+1].high (gap up in bullish move)
         if(htf[i-1].low > htf[i+1].high) {
            double gap = htf[i-1].low - htf[i+1].high;
            if(gap > FVG_MinPoints * _Point) {
               fvg.high = htf[i-1].low;
               fvg.low = htf[i+1].high;
               fvg.direction = 1;
               fvg.valid = true;
               return true;
            }
         }
      }
      else {
         // Bearish FVG: bar[i+1].low > bar[i-1].high (gap down in bearish move)
         if(htf[i+1].low > htf[i-1].high) {
            double gap = htf[i+1].low - htf[i-1].high;
            if(gap > FVG_MinPoints * _Point) {
               fvg.high = htf[i+1].low;
               fvg.low = htf[i-1].high;
               fvg.direction = -1;
               fvg.valid = true;
               return true;
            }
         }
      }
   }
   return false;
}

//+------------------------------------------------------------------+
// LTF Inverse FVG confirmation
//+------------------------------------------------------------------+
bool DetectLTF_IFVG(int direction, FVGZone &ifvg)
{
   MqlRates ltf[];
   ArraySetAsSeries(ltf, true);
   if(CopyRates(_Symbol, LTF, 0, LTF_Lookback, ltf) < LTF_Lookback) return false;

   ifvg.valid = false;

   for(int i = 3; i < IFVG_MaxAge; i++) {
      if(direction == 1) {
         // Bearish FVG violated → bullish IFVG (support)
         double gapHigh = ltf[i+1].low;
         double gapLow = ltf[i-1].high;
         if(gapHigh - gapLow > FVG_MinPoints * _Point) {
            // Check violation
            for(int j = i-2; j >= 1; j--) {
               if(ltf[j].close > gapHigh) {
                  // Confirmed IFVG + check MSS (higher low)
                  if(ltf[1].low > ltf[3].low) {
                     ifvg.high = gapHigh; ifvg.low = gapLow;
                     ifvg.direction = 1; ifvg.valid = true;
                     return true;
                  }
                  break;
               }
            }
         }
      }
      else {
         // Bullish FVG violated → bearish IFVG (resistance)
         double gapHigh = ltf[i-1].low;
         double gapLow = ltf[i+1].high;
         if(gapHigh - gapLow > FVG_MinPoints * _Point) {
            for(int j = i-2; j >= 1; j--) {
               if(ltf[j].close < gapLow) {
                  if(ltf[1].high < ltf[3].high) {
                     ifvg.high = gapHigh; ifvg.low = gapLow;
                     ifvg.direction = -1; ifvg.valid = true;
                     return true;
                  }
                  break;
               }
            }
         }
      }
   }
   return false;
}

//+------------------------------------------------------------------+
void ExecuteTrade(int direction, const FVGZone &htfFVG, const FVGZone &ltfIFVG)
{
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double sl, tp, entry, slDist;

   if(direction == 1) {
      entry = ask;
      sl = MathMin(htfFVG.low, ltfIFVG.low) - 50 * _Point;
      slDist = entry - sl;
      if(slDist < MinSLPoints * _Point || slDist > MaxSLPoints * _Point) return;
      tp = entry + slDist * MinRR;
   } else {
      entry = bid;
      sl = MathMax(htfFVG.high, ltfIFVG.high) + 50 * _Point;
      slDist = sl - entry;
      if(slDist < MinSLPoints * _Point || slDist > MaxSLPoints * _Point) return;
      tp = entry - slDist * MinRR;
   }

   double lot = CalcLot(slDist);
   if(lot <= 0) return;

   bool result = (direction == 1) ?
      trade.Buy(lot, _Symbol, ask, sl, tp, "3xBOS Rev Buy") :
      trade.Sell(lot, _Symbol, bid, sl, tp, "3xBOS Rev Sell");

   if(result) { g_dailyTrades++; g_barsSinceTrade = 0; }
}

//+------------------------------------------------------------------+
double CalcLot(double slDist)
{
   if(slDist <= 0) return 0;
   double lot = FixedLot;
   if(!UseFixedLot) {
      double riskAmt = AccountInfoDouble(ACCOUNT_BALANCE) * RiskPercent / 100.0;
      double tv = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
      double ts = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
      if(tv > 0 && ts > 0) lot = riskAmt / ((slDist / ts) * tv);
      if(lot <= 0) lot = FixedLot;
   }
   double minL = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   lot = MathFloor(lot / step) * step;
   if(lot < minL) lot = minL;
   return NormalizeDouble(lot, 2);
}

//+------------------------------------------------------------------+
void ManageTrailing()
{
   for(int i = PositionsTotal()-1; i >= 0; i--) {
      if(!PositionSelectByTicket(PositionGetTicket(i))) continue;
      if(PositionGetInteger(POSITION_MAGIC) != MagicNumber) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      double op = PositionGetDouble(POSITION_PRICE_OPEN);
      double sl = PositionGetDouble(POSITION_SL);
      double tp = PositionGetDouble(POSITION_TP);
      double slDist = MathAbs(op - sl);
      if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) {
         double b = SymbolInfoDouble(_Symbol, SYMBOL_BID);
         if(b - op >= slDist) {
            double ns = b - TrailPoints * _Point;
            if(ns > sl && ns > op) trade.PositionModify(PositionGetTicket(i), ns, tp);
         }
      } else {
         double a = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
         if(op - a >= slDist) {
            double ns = a + TrailPoints * _Point;
            if(ns < sl && ns < op) trade.PositionModify(PositionGetTicket(i), ns, tp);
         }
      }
   }
}

bool HasPosition()
{
   for(int i = PositionsTotal()-1; i >= 0; i--) {
      if(!PositionSelectByTicket(PositionGetTicket(i))) continue;
      if(PositionGetInteger(POSITION_MAGIC) == MagicNumber && PositionGetString(POSITION_SYMBOL) == _Symbol)
         return true;
   }
   return false;
}
