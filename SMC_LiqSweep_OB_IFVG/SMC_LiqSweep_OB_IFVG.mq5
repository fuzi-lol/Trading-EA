//+------------------------------------------------------------------+
//| SMC_LiqSweep_OB_IFVG.mq5                                        |
//| Strategy 1: HTF Liquidity Sweep + Order Block + LTF Inverse FVG  |
//| HTF: M15/M30 for structure, LTF: M5/M1 for entry                |
//+------------------------------------------------------------------+
#property copyright   "Trading EAs"
#property version     "1.00"
#property description "HTF Liquidity Sweep + OB retrace + LTF IFVG confirmation"

#include <Trade\Trade.mqh>

//--- Inputs
input group "=== Timeframes ==="
input ENUM_TIMEFRAMES HTF           = PERIOD_M15;   // Higher Timeframe (structure)
input ENUM_TIMEFRAMES LTF           = PERIOD_M5;    // Lower Timeframe (entry)

input group "=== Structure Detection ==="
input int     SwingBars              = 5;            // Bars each side for swing detection
input int     HTF_Lookback           = 100;          // HTF bars to scan for structure
input int     LTF_Lookback           = 50;           // LTF bars to scan for confirmation

input group "=== Order Block ==="
input int     OB_MaxBars             = 10;           // Max bars back to find OB after BOS
input int     OB_ZonePoints          = 300;          // OB zone thickness (points)

input group "=== FVG / IFVG ==="
input int     FVG_MinPoints          = 50;           // Minimum FVG gap size (points)
input int     IFVG_MaxAge            = 20;           // Max bars old for IFVG

input group "=== Risk Management ==="
input bool    UseFixedLot            = true;         // Use fixed lot
input double  FixedLot               = 0.10;         // Fixed lot size
input double  RiskPercent            = 1.0;          // Risk % (if not fixed lot)
input int     MaxSLPoints            = 500;          // Max SL (points)
input int     MinSLPoints            = 50;           // Min SL (points)
input double  MinRR                  = 2.0;          // Minimum Risk:Reward ratio
input bool    UseTrailing            = true;         // Trailing stop after 1R
input int     TrailPoints            = 150;          // Trail distance (points)

input group "=== Session Filter ==="
input int     StartHour              = 8;            // Trading start (server hour)
input int     EndHour                = 20;           // Trading end (server hour)

input group "=== General ==="
input int     MaxTradesPerDay        = 3;            // Max trades per day
input int     CooldownBars           = 5;            // Bars cooldown after trade
input int     MagicNumber            = 100100;       // Magic number

//--- Globals
CTrade        trade;
datetime      g_lastBarTime = 0;
int           g_dailyTrades = 0;
datetime      g_lastTradeDay = 0;
int           g_barsSinceTrade = 999;
bool          g_inTrade = false;
double        g_tradeEntry = 0;
double        g_tradeSL = 0;
bool          g_trailingActive = false;

// Structure tracking
struct SwingPoint {
   double price;
   datetime time;
   int    barIndex;
};

struct OrderBlock {
   double high;
   double low;
   datetime time;
   bool   valid;
   int    direction; // 1=bullish OB (demand), -1=bearish OB (supply)
};

struct FVGZone {
   double high;
   double low;
   datetime time;
   bool   valid;
   bool   violated;  // true = became IFVG
   int    direction;  // 1=bullish, -1=bearish
};

//+------------------------------------------------------------------+
int OnInit()
{
   trade.SetExpertMagicNumber(MagicNumber);
   trade.SetDeviationInPoints(10);
   trade.SetTypeFilling(ORDER_FILLING_IOC);
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
void OnDeinit(const int reason) {}

//+------------------------------------------------------------------+
void OnTick()
{
   datetime curBar = iTime(_Symbol, LTF, 0);
   if(curBar == g_lastBarTime) return;
   g_lastBarTime = curBar;

   // Reset daily counter
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   datetime today = StringToTime(StringFormat("%04d.%02d.%02d", dt.year, dt.mon, dt.day));
   if(today != g_lastTradeDay) {
      g_dailyTrades = 0;
      g_lastTradeDay = today;
   }

   g_barsSinceTrade++;

   // Manage existing position
   if(HasPosition()) {
      if(UseTrailing) ManageTrailing();
      return;
   }
   g_inTrade = false;

   // Filters
   if(g_dailyTrades >= MaxTradesPerDay) return;
   if(dt.hour < StartHour || dt.hour >= EndHour) return;
   if(g_barsSinceTrade < CooldownBars) return;

   // === STRATEGY LOGIC ===
   // Step 1: Detect HTF liquidity sweep + BOS
   int htfSignal = DetectHTFLiquiditySweepBOS();
   if(htfSignal == 0) return;

   // Step 2: Find HTF Order Block
   OrderBlock ob;
   if(!FindOrderBlock(htfSignal, ob)) return;

   // Step 3: Check if price is at/in OB zone
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(!IsPriceInOB(bid, ob)) return;

   // Step 4: LTF confirmation - MSS/ChoCh + IFVG
   FVGZone ifvg;
   if(!DetectLTF_IFVG(htfSignal, ifvg)) return;

   // Step 5: Execute trade
   ExecuteTrade(htfSignal, ob, ifvg);
}

//+------------------------------------------------------------------+
// Detect HTF Liquidity Sweep followed by BOS
//+------------------------------------------------------------------+
int DetectHTFLiquiditySweepBOS()
{
   MqlRates htf[];
   ArraySetAsSeries(htf, true);
   if(CopyRates(_Symbol, HTF, 0, HTF_Lookback, htf) < HTF_Lookback) return 0;

   // Find swing highs and lows
   SwingPoint swingHighs[], swingLows[];
   ArrayResize(swingHighs, 0);
   ArrayResize(swingLows, 0);

   for(int i = SwingBars; i < HTF_Lookback - SwingBars; i++) {
      if(IsSwingHigh(htf, i, SwingBars)) {
         SwingPoint sp;
         sp.price = htf[i].high;
         sp.time = htf[i].time;
         sp.barIndex = i;
         int sz = ArraySize(swingHighs);
         ArrayResize(swingHighs, sz + 1);
         swingHighs[sz] = sp;
         if(ArraySize(swingHighs) >= 5) break;
      }
   }

   for(int i = SwingBars; i < HTF_Lookback - SwingBars; i++) {
      if(IsSwingLow(htf, i, SwingBars)) {
         SwingPoint sp;
         sp.price = htf[i].low;
         sp.time = htf[i].time;
         sp.barIndex = i;
         int sz = ArraySize(swingLows);
         ArrayResize(swingLows, sz + 1);
         swingLows[sz] = sp;
         if(ArraySize(swingLows) >= 5) break;
      }
   }

   if(ArraySize(swingHighs) < 2 || ArraySize(swingLows) < 2) return 0;

   // Bullish: sweep below swing low → rejection → BOS above swing high
   // Check if recent price went below a prior swing low (sweep) then recovered
   for(int i = 0; i < MathMin(3, ArraySize(swingLows)); i++) {
      double sweepLevel = swingLows[i].price;
      // Check if any recent bar wicked below this level
      for(int j = 1; j < swingLows[i].barIndex && j < 15; j++) {
         if(htf[j].low < sweepLevel && htf[j].close > sweepLevel) {
            // Sweep detected! Now check for bullish BOS
            // Look for a close above the nearest swing high that formed after the sweep
            for(int k = 0; k < ArraySize(swingHighs); k++) {
               if(swingHighs[k].barIndex > j) continue; // must be before sweep
               if(htf[1].close > swingHighs[k].price || htf[2].close > swingHighs[k].price) {
                  return 1; // Bullish signal
               }
            }
         }
      }
   }

   // Bearish: sweep above swing high → rejection → BOS below swing low
   for(int i = 0; i < MathMin(3, ArraySize(swingHighs)); i++) {
      double sweepLevel = swingHighs[i].price;
      for(int j = 1; j < swingHighs[i].barIndex && j < 15; j++) {
         if(htf[j].high > sweepLevel && htf[j].close < sweepLevel) {
            for(int k = 0; k < ArraySize(swingLows); k++) {
               if(swingLows[k].barIndex > j) continue;
               if(htf[1].close < swingLows[k].price || htf[2].close < swingLows[k].price) {
                  return -1; // Bearish signal
               }
            }
         }
      }
   }

   return 0;
}

//+------------------------------------------------------------------+
bool IsSwingHigh(const MqlRates &rates[], int idx, int bars)
{
   for(int i = 1; i <= bars; i++) {
      if(rates[idx].high <= rates[idx - i].high) return false;
      if(rates[idx].high <= rates[idx + i].high) return false;
   }
   return true;
}

//+------------------------------------------------------------------+
bool IsSwingLow(const MqlRates &rates[], int idx, int bars)
{
   for(int i = 1; i <= bars; i++) {
      if(rates[idx].low >= rates[idx - i].low) return false;
      if(rates[idx].low >= rates[idx + i].low) return false;
   }
   return true;
}

//+------------------------------------------------------------------+
// Find the Order Block (last opposing candle before BOS expansion)
//+------------------------------------------------------------------+
bool FindOrderBlock(int direction, OrderBlock &ob)
{
   MqlRates htf[];
   ArraySetAsSeries(htf, true);
   if(CopyRates(_Symbol, HTF, 0, OB_MaxBars + 10, htf) < OB_MaxBars + 5) return false;

   ob.valid = false;

   if(direction == 1) {
      // Bullish OB = last bearish candle before bullish expansion
      for(int i = 2; i < OB_MaxBars; i++) {
         if(htf[i].close < htf[i].open) { // bearish candle
            // Check if next candle(s) are strongly bullish
            if(htf[i-1].close > htf[i-1].open && (htf[i-1].close - htf[i-1].open) > (htf[i].open - htf[i].close)) {
               ob.high = htf[i].open;  // top of bearish candle body
               ob.low = htf[i].close;  // bottom of bearish candle body
               ob.time = htf[i].time;
               ob.direction = 1;
               ob.valid = true;
               return true;
            }
         }
      }
   }
   else if(direction == -1) {
      // Bearish OB = last bullish candle before bearish expansion
      for(int i = 2; i < OB_MaxBars; i++) {
         if(htf[i].close > htf[i].open) { // bullish candle
            if(htf[i-1].close < htf[i-1].open && (htf[i-1].open - htf[i-1].close) > (htf[i].close - htf[i].open)) {
               ob.high = htf[i].close; // top of bullish candle body
               ob.low = htf[i].open;   // bottom of bullish candle body
               ob.time = htf[i].time;
               ob.direction = -1;
               ob.valid = true;
               return true;
            }
         }
      }
   }

   return false;
}

//+------------------------------------------------------------------+
bool IsPriceInOB(double price, const OrderBlock &ob)
{
   if(!ob.valid) return false;
   double buffer = OB_ZonePoints * _Point;
   return (price >= ob.low - buffer && price <= ob.high + buffer);
}

//+------------------------------------------------------------------+
// Detect LTF Inverse FVG (violated FVG that flips)
//+------------------------------------------------------------------+
bool DetectLTF_IFVG(int direction, FVGZone &ifvg)
{
   MqlRates ltf[];
   ArraySetAsSeries(ltf, true);
   if(CopyRates(_Symbol, LTF, 0, LTF_Lookback, ltf) < LTF_Lookback) return false;

   ifvg.valid = false;

   // Find FVGs and check if they've been violated (becoming IFVGs)
   for(int i = 3; i < LTF_Lookback - 2 && i < IFVG_MaxAge; i++) {
      if(direction == 1) {
         // Look for bearish FVG that got violated (becomes bullish IFVG = support)
         // Bearish FVG: bar[i+1].low > bar[i-1].high (gap down)
         double gapHigh = ltf[i+1].low;
         double gapLow = ltf[i-1].high;
         if(gapHigh - gapLow > FVG_MinPoints * _Point) {
            // Check if this FVG was violated (price closed through it)
            bool violated = false;
            for(int j = i - 2; j >= 1; j--) {
               if(ltf[j].close > gapHigh) {
                  violated = true;
                  break;
               }
            }
            if(violated) {
               // This is now an IFVG acting as support
               // Check for MSS/ChoCh - price should be making higher lows
               if(ltf[1].low > ltf[3].low && ltf[1].close > ltf[2].close) {
                  ifvg.high = gapHigh;
                  ifvg.low = gapLow;
                  ifvg.time = ltf[i].time;
                  ifvg.direction = 1;
                  ifvg.violated = true;
                  ifvg.valid = true;
                  return true;
               }
            }
         }
      }
      else if(direction == -1) {
         // Look for bullish FVG that got violated (becomes bearish IFVG = resistance)
         // Bullish FVG: bar[i-1].low > bar[i+1].high (gap up)
         double gapHigh = ltf[i-1].low;
         double gapLow = ltf[i+1].high;
         if(gapHigh - gapLow > FVG_MinPoints * _Point) {
            bool violated = false;
            for(int j = i - 2; j >= 1; j--) {
               if(ltf[j].close < gapLow) {
                  violated = true;
                  break;
               }
            }
            if(violated) {
               if(ltf[1].high < ltf[3].high && ltf[1].close < ltf[2].close) {
                  ifvg.high = gapHigh;
                  ifvg.low = gapLow;
                  ifvg.time = ltf[i].time;
                  ifvg.direction = -1;
                  ifvg.violated = true;
                  ifvg.valid = true;
                  return true;
               }
            }
         }
      }
   }

   return false;
}

//+------------------------------------------------------------------+
void ExecuteTrade(int direction, const OrderBlock &ob, const FVGZone &ifvg)
{
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double spread = ask - bid;

   double sl, tp, entry;
   double slDist;

   if(direction == 1) {
      entry = ask;
      sl = MathMin(ob.low, ifvg.low) - 50 * _Point;
      slDist = entry - sl;
      if(slDist < MinSLPoints * _Point || slDist > MaxSLPoints * _Point) return;
      tp = entry + slDist * MinRR;
   }
   else {
      entry = bid;
      sl = MathMax(ob.high, ifvg.high) + 50 * _Point;
      slDist = sl - entry;
      if(slDist < MinSLPoints * _Point || slDist > MaxSLPoints * _Point) return;
      tp = entry - slDist * MinRR;
   }

   double lot = CalcLot(slDist);
   if(lot <= 0) return;

   bool result = false;
   if(direction == 1)
      result = trade.Buy(lot, _Symbol, ask, sl, tp, "LSweep+OB+IFVG Buy");
   else
      result = trade.Sell(lot, _Symbol, bid, sl, tp, "LSweep+OB+IFVG Sell");

   if(result) {
      g_inTrade = true;
      g_tradeEntry = entry;
      g_tradeSL = sl;
      g_trailingActive = false;
      g_dailyTrades++;
      g_barsSinceTrade = 0;
   }
}

//+------------------------------------------------------------------+
double CalcLot(double slDistance)
{
   if(slDistance <= 0) return 0;
   double lot;
   if(UseFixedLot) {
      lot = FixedLot;
   } else {
      double balance = AccountInfoDouble(ACCOUNT_BALANCE);
      double riskAmt = balance * RiskPercent / 100.0;
      double tickVal = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
      double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
      if(tickVal > 0 && tickSize > 0)
         lot = riskAmt / ((slDistance / tickSize) * tickVal);
      else
         lot = FixedLot;
      if(lot <= 0) lot = FixedLot;
   }
   double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   lot = MathFloor(lot / lotStep) * lotStep;
   lot = NormalizeDouble(lot, 2);
   if(lot < minLot) lot = minLot;
   if(lot > maxLot) lot = maxLot;
   return lot;
}

//+------------------------------------------------------------------+
void ManageTrailing()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--) {
      if(!PositionSelectByTicket(PositionGetTicket(i))) continue;
      if(PositionGetInteger(POSITION_MAGIC) != MagicNumber) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;

      double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
      double curSL = PositionGetDouble(POSITION_SL);
      double curTP = PositionGetDouble(POSITION_TP);
      long type = PositionGetInteger(POSITION_TYPE);
      double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      double slDist = MathAbs(openPrice - curSL);

      if(type == POSITION_TYPE_BUY) {
         // Activate trailing after 1R profit
         if(bid - openPrice >= slDist) {
            double newSL = bid - TrailPoints * _Point;
            if(newSL > curSL && newSL > openPrice)
               trade.PositionModify(PositionGetTicket(i), newSL, curTP);
         }
      }
      else {
         if(openPrice - ask >= slDist) {
            double newSL = ask + TrailPoints * _Point;
            if(newSL < curSL && newSL < openPrice)
               trade.PositionModify(PositionGetTicket(i), newSL, curTP);
         }
      }
   }
}

//+------------------------------------------------------------------+
bool HasPosition()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--) {
      if(!PositionSelectByTicket(PositionGetTicket(i))) continue;
      if(PositionGetInteger(POSITION_MAGIC) == MagicNumber && PositionGetString(POSITION_SYMBOL) == _Symbol)
         return true;
   }
   return false;
}
