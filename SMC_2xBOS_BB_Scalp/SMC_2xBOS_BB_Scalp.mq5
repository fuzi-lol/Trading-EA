//+------------------------------------------------------------------+
//| SMC_2xBOS_BB_Scalp.mq5                                          |
//| Strategy 2 Scalp: 2x BOS + Breaker Block on M5→M1               |
//| Adapted for 1-minute scalping with tighter params                |
//+------------------------------------------------------------------+
#property copyright   "Trading EAs"
#property version     "1.00"
#property description "M5 2x BOS trend + Supply/Demand retrace + M1 Breaker Block scalp entry"

#include <Trade\Trade.mqh>

//--- Inputs
input group "=== Timeframes ==="
input ENUM_TIMEFRAMES HTF            = PERIOD_M5;    // Higher TF (structure)
input ENUM_TIMEFRAMES LTF            = PERIOD_M1;    // Lower TF (entry)

input group "=== Structure Detection ==="
input int     SwingBars              = 3;            // Swing bars (tighter for scalp)
input int     HTF_Lookback           = 80;           // M5 bars to scan
input int     LTF_Lookback           = 40;           // M1 bars to scan

input group "=== Supply/Demand Zone ==="
input int     SD_ZoneBuffer          = 50;           // Zone buffer (points)

input group "=== Risk Management ==="
input bool    UseFixedLot            = true;         // Use fixed lot
input double  FixedLot               = 0.10;         // Fixed lot size
input double  RiskPercent            = 1.0;          // Risk %
input int     MaxSLPoints            = 300;          // Max SL (tighter for scalp)
input int     MinSLPoints            = 30;           // Min SL
input double  MinRR                  = 1.5;          // Min RR (lower for scalp frequency)
input bool    UseTrailing            = true;         // Trailing stop
input int     TrailPoints            = 80;           // Trail distance (tighter)
input bool    UseBreakeven           = true;         // Move SL to BE after 1R
input int     BE_Buffer              = 10;           // BE buffer (points above entry)

input group "=== Session Filter ==="
input int     StartHour              = 8;            // Trading start
input int     EndHour                = 20;           // Trading end
input bool    SkipAsianSession       = true;         // Skip Asian (low vol)

input group "=== General ==="
input int     MaxTradesPerDay        = 8;            // More trades for scalping
input int     CooldownBars           = 3;            // Shorter cooldown
input int     MaxSpreadPoints        = 40;           // Max spread filter
input int     MagicNumber            = 100250;

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

struct SDZone {
   double high;
   double low;
   bool   valid;
   int    direction;
};

struct BreakerBlock {
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

   // Manage existing position
   if(HasPosition()) {
      ManagePosition();
      return;
   }

   // Filters
   if(g_dailyTrades >= MaxTradesPerDay) return;
   if(dt.hour < StartHour || dt.hour >= EndHour) return;
   if(SkipAsianSession && dt.hour >= 0 && dt.hour < 7) return;
   if(g_barsSinceTrade < CooldownBars) return;

   // Spread filter
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if((ask - bid) > MaxSpreadPoints * _Point) return;

   // === STRATEGY ===
   // Step 1: M5 2x BOS (trend direction)
   int trendDir = Detect2xBOS();
   if(trendDir == 0) return;

   // Step 2: M5 Supply/Demand zone
   SDZone zone;
   if(!FindSDZone(trendDir, zone)) return;

   // Step 3: Price in zone?
   if(!IsPriceInZone(bid, zone)) return;

   // Step 4: M1 MSS confirmation
   if(!DetectLTF_MSS(trendDir)) return;

   // Step 5: M1 Breaker Block
   BreakerBlock bb;
   if(!FindBreakerBlock(trendDir, bb)) return;

   // Step 6: Execute
   ExecuteTrade(trendDir, zone, bb);
}

//+------------------------------------------------------------------+
int Detect2xBOS()
{
   MqlRates htf[];
   ArraySetAsSeries(htf, true);
   if(CopyRates(_Symbol, HTF, 0, HTF_Lookback, htf) < HTF_Lookback) return 0;

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
      if(ArraySize(highs) >= 4 && ArraySize(lows) >= 4) break;
   }

   if(ArraySize(highs) < 3 || ArraySize(lows) < 3) return 0;

   // Bullish 2x BOS
   int bullBOS = 0;
   for(int i = 0; i < ArraySize(highs) - 1 && i < 4; i++) {
      for(int j = 1; j < highs[i].barIndex; j++) {
         if(htf[j].close > highs[i].price) { bullBOS++; break; }
      }
      if(bullBOS >= 2) return 1;
   }

   // Bearish 2x BOS
   int bearBOS = 0;
   for(int i = 0; i < ArraySize(lows) - 1 && i < 4; i++) {
      for(int j = 1; j < lows[i].barIndex; j++) {
         if(htf[j].close < lows[i].price) { bearBOS++; break; }
      }
      if(bearBOS >= 2) return -1;
   }

   return 0;
}

//+------------------------------------------------------------------+
bool FindSDZone(int direction, SDZone &zone)
{
   MqlRates htf[];
   ArraySetAsSeries(htf, true);
   if(CopyRates(_Symbol, HTF, 0, 25, htf) < 20) return false;

   zone.valid = false;

   if(direction == 1) {
      // Demand zone: bearish candle before bullish expansion
      for(int i = 2; i < 20; i++) {
         double bodyI = htf[i].close - htf[i].open;
         double bodyNext = htf[i-1].close - htf[i-1].open;
         if(bodyI < 0 && bodyNext > 0 && MathAbs(bodyNext) > MathAbs(bodyI) * 1.2) {
            zone.high = htf[i].open;
            zone.low = htf[i].low;
            zone.direction = 1;
            zone.valid = true;
            return true;
         }
      }
   } else {
      // Supply zone: bullish candle before bearish expansion
      for(int i = 2; i < 20; i++) {
         double bodyI = htf[i].close - htf[i].open;
         double bodyNext = htf[i-1].close - htf[i-1].open;
         if(bodyI > 0 && bodyNext < 0 && MathAbs(bodyNext) > MathAbs(bodyI) * 1.2) {
            zone.high = htf[i].high;
            zone.low = htf[i].open;
            zone.direction = -1;
            zone.valid = true;
            return true;
         }
      }
   }
   return false;
}

//+------------------------------------------------------------------+
bool IsPriceInZone(double price, const SDZone &zone)
{
   double buffer = SD_ZoneBuffer * _Point;
   return (price >= zone.low - buffer && price <= zone.high + buffer);
}

//+------------------------------------------------------------------+
bool DetectLTF_MSS(int direction)
{
   MqlRates ltf[];
   ArraySetAsSeries(ltf, true);
   if(CopyRates(_Symbol, LTF, 0, LTF_Lookback, ltf) < LTF_Lookback) return false;

   if(direction == 1) {
      for(int i = SwingBars; i < 25; i++) {
         bool isHigh = true;
         for(int j = 1; j <= SwingBars; j++) {
            if(ltf[i].high <= ltf[i-j].high || ltf[i].high <= ltf[i+j].high) { isHigh = false; break; }
         }
         if(isHigh) {
            if(ltf[1].close > ltf[i].high || ltf[2].close > ltf[i].high)
               return true;
         }
      }
   } else {
      for(int i = SwingBars; i < 25; i++) {
         bool isLow = true;
         for(int j = 1; j <= SwingBars; j++) {
            if(ltf[i].low >= ltf[i-j].low || ltf[i].low >= ltf[i+j].low) { isLow = false; break; }
         }
         if(isLow) {
            if(ltf[1].close < ltf[i].low || ltf[2].close < ltf[i].low)
               return true;
         }
      }
   }
   return false;
}

//+------------------------------------------------------------------+
bool FindBreakerBlock(int direction, BreakerBlock &bb)
{
   MqlRates ltf[];
   ArraySetAsSeries(ltf, true);
   if(CopyRates(_Symbol, LTF, 0, LTF_Lookback, ltf) < LTF_Lookback) return false;

   bb.valid = false;

   if(direction == 1) {
      // Bullish breaker: swing low → swing high → lower low → break up
      for(int i = 4; i < LTF_Lookback - 8; i++) {
         if(!IsSwingLow(ltf, i, 2)) continue;
         double swLow1 = ltf[i].low;

         for(int j = i - 2; j > 2; j--) {
            if(!IsSwingHigh(ltf, j, 2)) continue;
            double swHigh = ltf[j].high;

            for(int k = j - 1; k > 1; k--) {
               if(ltf[k].low < swLow1) {
                  if(ltf[1].close > swHigh || ltf[2].close > swHigh) {
                     // Find the up-close candle in the pattern
                     for(int m = i; m > j; m--) {
                        if(ltf[m].close > ltf[m].open) {
                           bb.high = ltf[m].high;
                           bb.low = ltf[m].low;
                           break;
                        }
                     }
                     if(bb.high == 0) { bb.high = swHigh; bb.low = swLow1; }
                     bb.direction = 1;
                     bb.valid = true;
                     return true;
                  }
               }
            }
            break;
         }
      }
   } else {
      // Bearish breaker: swing high → swing low → higher high → break down
      for(int i = 4; i < LTF_Lookback - 8; i++) {
         if(!IsSwingHigh(ltf, i, 2)) continue;
         double swHigh1 = ltf[i].high;

         for(int j = i - 2; j > 2; j--) {
            if(!IsSwingLow(ltf, j, 2)) continue;
            double swLow = ltf[j].low;

            for(int k = j - 1; k > 1; k--) {
               if(ltf[k].high > swHigh1) {
                  if(ltf[1].close < swLow || ltf[2].close < swLow) {
                     for(int m = i; m > j; m--) {
                        if(ltf[m].close < ltf[m].open) {
                           bb.high = ltf[m].high;
                           bb.low = ltf[m].low;
                           break;
                        }
                     }
                     if(bb.low == 0) { bb.high = swHigh1; bb.low = swLow; }
                     bb.direction = -1;
                     bb.valid = true;
                     return true;
                  }
               }
            }
            break;
         }
      }
   }
   return false;
}

//+------------------------------------------------------------------+
bool IsSwingHigh(const MqlRates &r[], int idx, int bars)
{
   for(int i = 1; i <= bars; i++) {
      if(r[idx].high <= r[idx-i].high || r[idx].high <= r[idx+i].high) return false;
   }
   return true;
}

bool IsSwingLow(const MqlRates &r[], int idx, int bars)
{
   for(int i = 1; i <= bars; i++) {
      if(r[idx].low >= r[idx-i].low || r[idx].low >= r[idx+i].low) return false;
   }
   return true;
}

//+------------------------------------------------------------------+
void ExecuteTrade(int direction, const SDZone &zone, const BreakerBlock &bb)
{
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double sl, tp, entry, slDist;

   if(direction == 1) {
      entry = ask;
      sl = MathMin(zone.low, bb.low) - 20 * _Point;
      slDist = entry - sl;
      if(slDist < MinSLPoints * _Point || slDist > MaxSLPoints * _Point) return;
      tp = entry + slDist * MinRR;
   } else {
      entry = bid;
      sl = MathMax(zone.high, bb.high) + 20 * _Point;
      slDist = sl - entry;
      if(slDist < MinSLPoints * _Point || slDist > MaxSLPoints * _Point) return;
      tp = entry - slDist * MinRR;
   }

   double lot = CalcLot(slDist);
   if(lot <= 0) return;

   bool result = (direction == 1) ?
      trade.Buy(lot, _Symbol, ask, sl, tp, "2xBOS+BB Scalp Buy") :
      trade.Sell(lot, _Symbol, bid, sl, tp, "2xBOS+BB Scalp Sell");

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
void ManagePosition()
{
   for(int i = PositionsTotal()-1; i >= 0; i--) {
      if(!PositionSelectByTicket(PositionGetTicket(i))) continue;
      if(PositionGetInteger(POSITION_MAGIC) != MagicNumber) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;

      double op = PositionGetDouble(POSITION_PRICE_OPEN);
      double sl = PositionGetDouble(POSITION_SL);
      double tp = PositionGetDouble(POSITION_TP);
      double slDist = MathAbs(op - sl);
      ulong ticket = PositionGetTicket(i);

      if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) {
         double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
         double profit = bid - op;

         // Breakeven after 1R
         if(UseBreakeven && profit >= slDist && sl < op) {
            double beSL = op + BE_Buffer * _Point;
            trade.PositionModify(ticket, beSL, tp);
            sl = beSL;
         }

         // Trailing after 1R
         if(UseTrailing && profit >= slDist) {
            double newSL = bid - TrailPoints * _Point;
            if(newSL > sl && newSL > op)
               trade.PositionModify(ticket, newSL, tp);
         }
      } else {
         double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
         double profit = op - ask;

         if(UseBreakeven && profit >= slDist && sl > op) {
            double beSL = op - BE_Buffer * _Point;
            trade.PositionModify(ticket, beSL, tp);
            sl = beSL;
         }

         if(UseTrailing && profit >= slDist) {
            double newSL = ask + TrailPoints * _Point;
            if(newSL < sl && newSL < op)
               trade.PositionModify(ticket, newSL, tp);
         }
      }
   }
}

//+------------------------------------------------------------------+
bool HasPosition()
{
   for(int i = PositionsTotal()-1; i >= 0; i--) {
      if(!PositionSelectByTicket(PositionGetTicket(i))) continue;
      if(PositionGetInteger(POSITION_MAGIC) == MagicNumber && PositionGetString(POSITION_SYMBOL) == _Symbol)
         return true;
   }
   return false;
}
