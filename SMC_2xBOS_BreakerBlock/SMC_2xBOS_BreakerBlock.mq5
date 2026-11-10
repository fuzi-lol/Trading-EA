//+------------------------------------------------------------------+
//| SMC_2xBOS_BreakerBlock.mq5                                       |
//| Strategy 2: HTF 2x BOS Supply/Demand + LTF Breaker Block         |
//| HTF: H1 for structure, LTF: M5 for entry                        |
//+------------------------------------------------------------------+
#property copyright   "Trading EAs"
#property version     "1.00"
#property description "HTF 2x BOS trend + Supply/Demand retrace + LTF Breaker Block entry"

#include <Trade\Trade.mqh>

//--- Inputs
input group "=== Timeframes ==="
input ENUM_TIMEFRAMES HTF            = PERIOD_H1;    // Higher Timeframe (structure)
input ENUM_TIMEFRAMES LTF            = PERIOD_M5;    // Lower Timeframe (entry)

input group "=== Structure Detection ==="
input int     SwingBars              = 5;            // Bars each side for swing detection
input int     HTF_Lookback           = 120;          // HTF bars to scan
input int     LTF_Lookback           = 60;           // LTF bars to scan

input group "=== Supply/Demand Zone ==="
input int     SD_ZoneBuffer          = 100;          // Zone buffer (points)

input group "=== Risk Management ==="
input bool    UseFixedLot            = true;         // Use fixed lot
input double  FixedLot               = 0.10;         // Fixed lot size
input double  RiskPercent            = 1.0;          // Risk %
input int     MaxSLPoints            = 600;          // Max SL (points)
input int     MinSLPoints            = 50;           // Min SL (points)
input double  MinRR                  = 2.0;          // Minimum Risk:Reward
input bool    UseTrailing            = true;         // Use trailing stop
input int     TrailPoints            = 200;          // Trail distance (points)

input group "=== Session Filter ==="
input int     StartHour              = 8;            // Trading start
input int     EndHour                = 20;           // Trading end

input group "=== General ==="
input int     MaxTradesPerDay        = 3;
input int     CooldownBars           = 5;
input int     MagicNumber            = 100200;

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
   int    direction; // 1=demand, -1=supply
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

   if(HasPosition()) { if(UseTrailing) ManageTrailing(); return; }

   if(g_dailyTrades >= MaxTradesPerDay) return;
   if(dt.hour < StartHour || dt.hour >= EndHour) return;
   if(g_barsSinceTrade < CooldownBars) return;

   // === STRATEGY ===
   // Step 1: Detect HTF 2x BOS (strong trend)
   int trendDir = Detect2xBOS();
   if(trendDir == 0) return;

   // Step 2: Find HTF Supply/Demand zone at origin of BOS
   SDZone zone;
   if(!FindSDZone(trendDir, zone)) return;

   // Step 3: Check if price is in the zone
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(!IsPriceInZone(bid, zone)) return;

   // Step 4: LTF confirmation - MSS/ChoCh
   if(!DetectLTF_MSS(trendDir)) return;

   // Step 5: Find LTF Breaker Block
   BreakerBlock bb;
   if(!FindBreakerBlock(trendDir, bb)) return;

   // Step 6: Execute trade
   ExecuteTrade(trendDir, zone, bb);
}

//+------------------------------------------------------------------+
// Detect 2 consecutive BOS in same direction on HTF
//+------------------------------------------------------------------+
int Detect2xBOS()
{
   MqlRates htf[];
   ArraySetAsSeries(htf, true);
   if(CopyRates(_Symbol, HTF, 0, HTF_Lookback, htf) < HTF_Lookback) return 0;

   // Find swing highs and lows
   SwingPoint highs[], lows[];
   ArrayResize(highs, 0); ArrayResize(lows, 0);

   for(int i = SwingBars; i < HTF_Lookback - SwingBars; i++) {
      bool isHigh = true, isLow = true;
      for(int j = 1; j <= SwingBars; j++) {
         if(htf[i].high <= htf[i-j].high || htf[i].high <= htf[i+j].high) isHigh = false;
         if(htf[i].low >= htf[i-j].low || htf[i].low >= htf[i+j].low) isLow = false;
      }
      if(isHigh) {
         SwingPoint sp; sp.price = htf[i].high; sp.barIndex = i;
         int sz = ArraySize(highs); ArrayResize(highs, sz+1); highs[sz] = sp;
      }
      if(isLow) {
         SwingPoint sp; sp.price = htf[i].low; sp.barIndex = i;
         int sz = ArraySize(lows); ArrayResize(lows, sz+1); lows[sz] = sp;
      }
      if(ArraySize(highs) >= 4 && ArraySize(lows) >= 4) break;
   }

   if(ArraySize(highs) < 3 || ArraySize(lows) < 3) return 0;

   // Bullish 2x BOS: two consecutive higher highs broken by closes
   int bullishBOS = 0;
   for(int i = 0; i < ArraySize(highs) - 1; i++) {
      // Check if a candle closed above this swing high (BOS)
      for(int j = 1; j < highs[i].barIndex; j++) {
         if(htf[j].close > highs[i].price) { bullishBOS++; break; }
      }
      if(bullishBOS >= 2) return 1;
   }

   // Bearish 2x BOS: two consecutive lower lows broken by closes
   int bearishBOS = 0;
   for(int i = 0; i < ArraySize(lows) - 1; i++) {
      for(int j = 1; j < lows[i].barIndex; j++) {
         if(htf[j].close < lows[i].price) { bearishBOS++; break; }
      }
      if(bearishBOS >= 2) return -1;
   }

   return 0;
}

//+------------------------------------------------------------------+
// Find Supply/Demand zone at the origin of BOS expansion
//+------------------------------------------------------------------+
bool FindSDZone(int direction, SDZone &zone)
{
   MqlRates htf[];
   ArraySetAsSeries(htf, true);
   if(CopyRates(_Symbol, HTF, 0, 30, htf) < 20) return false;

   zone.valid = false;

   if(direction == 1) {
      // Find demand zone: the base of the most recent bullish expansion
      // Look for consolidation/pullback before strong bullish move
      for(int i = 3; i < 25; i++) {
         // Find a bearish/small candle followed by strong bullish expansion
         double bodyI = htf[i].close - htf[i].open;
         double bodyNext = htf[i-1].close - htf[i-1].open;
         if(bodyI < 0 && bodyNext > 0 && MathAbs(bodyNext) > MathAbs(bodyI) * 1.5) {
            zone.high = htf[i].open;
            zone.low = htf[i].low;
            zone.direction = 1;
            zone.valid = true;
            return true;
         }
      }
   }
   else {
      // Find supply zone: the top of the most recent bearish expansion
      for(int i = 3; i < 25; i++) {
         double bodyI = htf[i].close - htf[i].open;
         double bodyNext = htf[i-1].close - htf[i-1].open;
         if(bodyI > 0 && bodyNext < 0 && MathAbs(bodyNext) > MathAbs(bodyI) * 1.5) {
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
// Detect LTF Market Structure Shift (MSS/ChoCh)
//+------------------------------------------------------------------+
bool DetectLTF_MSS(int direction)
{
   MqlRates ltf[];
   ArraySetAsSeries(ltf, true);
   if(CopyRates(_Symbol, LTF, 0, LTF_Lookback, ltf) < LTF_Lookback) return false;

   if(direction == 1) {
      // Bullish MSS: was making lower lows, now broke above a recent swing high
      // Find recent swing high on LTF
      for(int i = SwingBars; i < 30; i++) {
         bool isHigh = true;
         for(int j = 1; j <= SwingBars; j++) {
            if(ltf[i].high <= ltf[i-j].high || ltf[i].high <= ltf[i+j].high) { isHigh = false; break; }
         }
         if(isHigh) {
            // Check if recent candle closed above this swing high
            if(ltf[1].close > ltf[i].high || ltf[2].close > ltf[i].high)
               return true;
         }
      }
   }
   else {
      // Bearish MSS
      for(int i = SwingBars; i < 30; i++) {
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
// Find Breaker Block on LTF
// Bullish Breaker: Swing Low → Swing High → Lower Low → Expansion up
// The upclose candle(s) between first swing low and swing high = Breaker
//+------------------------------------------------------------------+
bool FindBreakerBlock(int direction, BreakerBlock &bb)
{
   MqlRates ltf[];
   ArraySetAsSeries(ltf, true);
   if(CopyRates(_Symbol, LTF, 0, LTF_Lookback, ltf) < LTF_Lookback) return false;

   bb.valid = false;

   if(direction == 1) {
      // Find pattern: swing low → swing high → lower low → break up
      for(int i = 5; i < LTF_Lookback - 10; i++) {
         // Find swing low
         if(!IsSwingLowSimple(ltf, i, 3)) continue;
         double swLow1 = ltf[i].low;

         // Find swing high after it (closer to current)
         for(int j = i - 3; j > 3; j--) {
            if(!IsSwingHighSimple(ltf, j, 3)) continue;
            double swHigh = ltf[j].high;

            // Find lower low after swing high
            for(int k = j - 2; k > 1; k--) {
               if(ltf[k].low < swLow1) {
                  // Now check if price broke above swing high (expansion)
                  if(ltf[1].close > swHigh || ltf[2].close > swHigh) {
                     // Breaker block = bullish candles between swing low and swing high
                     bb.high = swHigh;
                     bb.low = swLow1;
                     // Narrow to the actual up-close candle
                     for(int m = i; m > j; m--) {
                        if(ltf[m].close > ltf[m].open) {
                           bb.high = ltf[m].high;
                           bb.low = ltf[m].low;
                           break;
                        }
                     }
                     bb.direction = 1;
                     bb.valid = true;
                     return true;
                  }
               }
            }
            break;
         }
      }
   }
   else {
      // Bearish breaker: swing high → swing low → higher high → break down
      for(int i = 5; i < LTF_Lookback - 10; i++) {
         if(!IsSwingHighSimple(ltf, i, 3)) continue;
         double swHigh1 = ltf[i].high;

         for(int j = i - 3; j > 3; j--) {
            if(!IsSwingLowSimple(ltf, j, 3)) continue;
            double swLow = ltf[j].low;

            for(int k = j - 2; k > 1; k--) {
               if(ltf[k].high > swHigh1) {
                  if(ltf[1].close < swLow || ltf[2].close < swLow) {
                     bb.high = swHigh1;
                     bb.low = swLow;
                     for(int m = i; m > j; m--) {
                        if(ltf[m].close < ltf[m].open) {
                           bb.high = ltf[m].high;
                           bb.low = ltf[m].low;
                           break;
                        }
                     }
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
bool IsSwingHighSimple(const MqlRates &r[], int idx, int bars)
{
   for(int i = 1; i <= bars; i++) {
      if(r[idx].high <= r[idx-i].high || r[idx].high <= r[idx+i].high) return false;
   }
   return true;
}

bool IsSwingLowSimple(const MqlRates &r[], int idx, int bars)
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
      sl = MathMin(zone.low, bb.low) - 30 * _Point;
      slDist = entry - sl;
      if(slDist < MinSLPoints * _Point || slDist > MaxSLPoints * _Point) return;
      tp = entry + slDist * MinRR;
   } else {
      entry = bid;
      sl = MathMax(zone.high, bb.high) + 30 * _Point;
      slDist = sl - entry;
      if(slDist < MinSLPoints * _Point || slDist > MaxSLPoints * _Point) return;
      tp = entry - slDist * MinRR;
   }

   double lot = CalcLot(slDist);
   if(lot <= 0) return;

   bool result = (direction == 1) ?
      trade.Buy(lot, _Symbol, ask, sl, tp, "2xBOS+BB Buy") :
      trade.Sell(lot, _Symbol, bid, sl, tp, "2xBOS+BB Sell");

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
         double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
         if(bid - op >= slDist) {
            double newSL = bid - TrailPoints * _Point;
            if(newSL > sl && newSL > op) trade.PositionModify(PositionGetTicket(i), newSL, tp);
         }
      } else {
         double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
         if(op - ask >= slDist) {
            double newSL = ask + TrailPoints * _Point;
            if(newSL < sl && newSL < op) trade.PositionModify(PositionGetTicket(i), newSL, tp);
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
