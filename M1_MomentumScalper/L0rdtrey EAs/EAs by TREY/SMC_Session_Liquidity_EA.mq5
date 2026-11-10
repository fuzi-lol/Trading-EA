//+------------------------------------------------------------------+
//| SMC_Session_Liquidity_EA.mq5                    (v2 - adaptive)  |
//| Adaptive Session Liquidity Sweep + Structure Shift (SLS-SS)      |
//|                                                                    |
//| Core signal (mandatory):  liquidity sweep -> CHoCH                |
//| Everything else is SOFT confluence that scales confidence/risk,   |
//| not a hard gate -- this keeps trade frequency healthy.            |
//|                                                                    |
//| Mode auto-selection per signal:                                   |
//|   SCALP -> reward potential to nearest pool is small -> single    |
//|            fast target, full size, quick exit                    |
//|   SWING -> reward potential to a further pool is large -> take    |
//|            partial profit at the scalp target, move to breakeven, |
//|            trail the remainder with ATR toward the far target     |
//|                                                                    |
//| Risk is computed fresh per signal: ATR-based SL, liquidity-based   |
//| TP1/TP2, and lot size scaled by a 0-100 confluence score -- same   |
//| engine whether it ends up scalping or swinging.                   |
//+------------------------------------------------------------------+
#property copyright "Educational template"
#property version   "2.00"
#property strict

#include <Trade/Trade.mqh>
CTrade trade;

//====================== INPUTS =======================================

//--- Trading windows (server time) -- both sessions on by default for more opportunities
input bool   InpTradeLondon      = true;
input string InpLondonStart      = "07:00";
input string InpLondonEnd        = "11:00";
input bool   InpTradeNY          = true;
input string InpNYStart          = "12:00";
input string InpNYEnd            = "16:00";
input string InpAsianStart       = "00:00";
input string InpAsianEnd         = "07:00";

//--- Structure detection
input int    InpFractalLeftRight   = 2;
input int    InpLookbackBars       = 300;
input double InpSweepBufferPips    = 1.5;    // wick clearance to count as a genuine sweep

//--- Confluence scoring (SOFT by default -- scales risk, doesn't block trades)
input bool   InpRequireH1Align     = false;  // true = hard-block against H1 bias (strict mode)
input int    InpH1EmaPeriod        = 50;
input int    InpMinConfluenceScore = 35;     // 0-100 floor to take ANY trade; lower = more trades

//--- ATR-based dynamic risk
input int    InpATRPeriod          = 14;
input double InpSLAtrMult          = 1.2;    // SL buffer beyond the sweep wick, in ATR multiples
input double InpScalpRR            = 1.4;    // scalp / TP1 target, reward:risk
input double InpSwingMinRR         = 2.2;    // potential RR to the far pool needed to call it "swing"

//--- Position & risk management
input double InpBaseRiskPercent    = 0.4;    // risk % at minimum acceptable confluence score
input double InpMaxRiskPercent     = 1.5;    // risk % at maximum (100) confluence score
input bool   InpUsePartialOnSwing  = true;   // take partial profit at TP1 when a setup runs as SWING
input double InpPartialClosePct    = 50.0;   // % of position closed at TP1 for swing trades
input bool   InpTrailAfterPartial  = true;
input double InpTrailAtrMult       = 1.5;

input int    InpMaxTradesPerDay    = 4;      // loosened -- was effectively 1
input int    InpMagicNumber        = 990211;
input bool   InpDrawObjects        = true;

//====================== GLOBALS =======================================
double   g_asianHigh = 0, g_asianLow = 0;
bool     g_asianRangeLocked = false;
int      g_tradesToday   = 0;
double   g_lastSweptLevel = 0;
int      g_atrHandle     = INVALID_HANDLE;
int      g_h1EmaHandle   = INVALID_HANDLE;
string   g_objPrefix     = "SLSSS_";

enum TradeMode { MODE_SCALP = 0, MODE_SWING = 1 };

struct LiquidityPool
  {
   double level;
   bool   isHigh;
   string label;
  };

//+------------------------------------------------------------------+
int OnInit()
  {
   g_atrHandle   = iATR(_Symbol, PERIOD_M5, InpATRPeriod);
   g_h1EmaHandle = iMA(_Symbol, PERIOD_H1, InpH1EmaPeriod, 0, MODE_EMA, PRICE_CLOSE);
   if(g_atrHandle == INVALID_HANDLE || g_h1EmaHandle == INVALID_HANDLE)
      Print("Warning: one or more indicator handles failed to initialize");
   trade.SetExpertMagicNumber(InpMagicNumber);
   return(INIT_SUCCEEDED);
  }

void OnDeinit(const int reason)
  {
   if(g_atrHandle != INVALID_HANDLE)   IndicatorRelease(g_atrHandle);
   if(g_h1EmaHandle != INVALID_HANDLE) IndicatorRelease(g_h1EmaHandle);
   if(InpDrawObjects) ObjectsDeleteAll(0, g_objPrefix);
  }

//+------------------------------------------------------------------+
void OnTick()
  {
   ResetDailyStateIfNewDay();
   UpdateAsianRange();

   if(PositionSelect(_Symbol))
     {
      ManageOpenPosition();
      return;
     }

   if(g_tradesToday >= InpMaxTradesPerDay)
      return;

   if(!IsInAnyTradingWindow())
      return;

   LiquidityPool pools[];
   int n = GetLiquidityPools(pools);
   if(n == 0)
      return;

   for(int p = 0; p < n; p++)
     {
      if(pools[p].level == 0) continue;
      if(pools[p].level == g_lastSweptLevel) continue; // avoid re-triggering the same level

      int sweepDir = CheckSweepOfLevel(pools[p].level, pools[p].isHigh);
      if(sweepDir == 0) continue;

      int chochDir = DetectCHoCH(sweepDir);
      if(chochDir == 0) continue;

      if(InpRequireH1Align)
        {
         int bias = GetH1Bias();
         if(bias != 0 && bias != chochDir) continue;
        }

      TryOpenTrade(chochDir, pools[p]);
      break; // one signal handled per tick
     }
  }

//+------------------------------------------------------------------+
//| Build the candidate liquidity pools to watch for a sweep          |
//+------------------------------------------------------------------+
int GetLiquidityPools(LiquidityPool &pools[])
  {
   ArrayResize(pools, 4);
   pools[0].level = g_asianHigh; pools[0].isHigh = true;  pools[0].label = "AsianHigh";
   pools[1].level = g_asianLow;  pools[1].isHigh = false; pools[1].label = "AsianLow";
   pools[2].level = iHigh(_Symbol, PERIOD_D1, 1); pools[2].isHigh = true;  pools[2].label = "PrevDayHigh";
   pools[3].level = iLow(_Symbol, PERIOD_D1, 1);  pools[3].isHigh = false; pools[3].label = "PrevDayLow";
   return 4;
  }

//+------------------------------------------------------------------+
//| Sweep check against one specific level                           |
//| Returns  1 = swept a high (bearish bias) , -1 = swept a low       |
//| (bullish bias), 0 = no sweep                                      |
//+------------------------------------------------------------------+
int CheckSweepOfLevel(double level, bool isHigh)
  {
   double buffer = InpSweepBufferPips * SymbolInfoDouble(_Symbol, SYMBOL_POINT) * 10;
   double hiWick = iHigh(_Symbol, PERIOD_M5, 1);
   double loWick = iLow(_Symbol, PERIOD_M5, 1);
   double close1 = iClose(_Symbol, PERIOD_M5, 1);

   if(isHigh && hiWick > level + buffer && close1 < level)
      return 1;
   if(!isHigh && loWick < level - buffer && close1 > level)
      return -1;
   return 0;
  }

//+------------------------------------------------------------------+
//| Fractal-based CHoCH detection (unchanged core logic)              |
//+------------------------------------------------------------------+
int DetectCHoCH(int sweepDir)
  {
   double lastSwingHigh = 0, lastSwingLow = 0;
   int lr = InpFractalLeftRight;

   for(int i = lr; i < InpLookbackBars - lr; i++)
     {
      if(lastSwingHigh == 0 && IsFractalHigh(i, lr))
         lastSwingHigh = iHigh(_Symbol, PERIOD_M5, i);
      if(lastSwingLow == 0 && IsFractalLow(i, lr))
         lastSwingLow = iLow(_Symbol, PERIOD_M5, i);
      if(lastSwingHigh != 0 && lastSwingLow != 0)
         break;
     }

   double closeNow = iClose(_Symbol, PERIOD_M5, 0);

   if(sweepDir == 1 && lastSwingLow != 0 && closeNow < lastSwingLow)
      return -1; // bearish CHoCH after sweeping a high
   if(sweepDir == -1 && lastSwingHigh != 0 && closeNow > lastSwingHigh)
      return 1;  // bullish CHoCH after sweeping a low
   return 0;
  }

bool IsFractalHigh(int shift, int lr)
  {
   double h = iHigh(_Symbol, PERIOD_M5, shift);
   for(int j = 1; j <= lr; j++)
     {
      if(iHigh(_Symbol, PERIOD_M5, shift - j) >= h) return false;
      if(iHigh(_Symbol, PERIOD_M5, shift + j) >= h) return false;
     }
   return true;
  }

bool IsFractalLow(int shift, int lr)
  {
   double l = iLow(_Symbol, PERIOD_M5, shift);
   for(int j = 1; j <= lr; j++)
     {
      if(iLow(_Symbol, PERIOD_M5, shift - j) <= l) return false;
      if(iLow(_Symbol, PERIOD_M5, shift + j) <= l) return false;
     }
   return true;
  }

//+------------------------------------------------------------------+
//| Order block finder (last opposite candle before the impulse)      |
//+------------------------------------------------------------------+
int FindOrderBlock(int dir)
  {
   for(int i = 1; i < 50; i++)
     {
      bool bull = iClose(_Symbol, PERIOD_M5, i) > iOpen(_Symbol, PERIOD_M5, i);
      bool bear = iClose(_Symbol, PERIOD_M5, i) < iOpen(_Symbol, PERIOD_M5, i);
      if(dir == 1 && bear) return i;
      if(dir == -1 && bull) return i;
     }
   return -1;
  }

//+------------------------------------------------------------------+
//| 3-candle Fair Value Gap detector (confluence only, not a gate)    |
//+------------------------------------------------------------------+
bool DetectFVG(int dir, int obShift, double &fvgTop, double &fvgBottom)
  {
   for(int s = 1; s <= obShift - 2; s++)
     {
      double highOlder = iHigh(_Symbol, PERIOD_M5, s + 2);
      double lowOlder   = iLow(_Symbol, PERIOD_M5, s + 2);
      double highNewer = iHigh(_Symbol, PERIOD_M5, s);
      double lowNewer   = iLow(_Symbol, PERIOD_M5, s);
      if(dir == 1 && lowNewer > highOlder) { fvgBottom = highOlder; fvgTop = lowNewer; return true; }
      if(dir == -1 && highNewer < lowOlder) { fvgTop = lowOlder; fvgBottom = highNewer; return true; }
     }
   return false;
  }

//+------------------------------------------------------------------+
//| Displacement strength: does the impulse candle stand out vs ATR? |
//+------------------------------------------------------------------+
bool IsDisplacementStrong(double atr)
  {
   double body = MathAbs(iClose(_Symbol, PERIOD_M5, 1) - iOpen(_Symbol, PERIOD_M5, 1));
   return (body > atr * 0.8);
  }

//+------------------------------------------------------------------+
//| H1 trend bias via EMA: 1 = bullish, -1 = bearish, 0 = flat        |
//+------------------------------------------------------------------+
int GetH1Bias()
  {
   if(g_h1EmaHandle == INVALID_HANDLE) return 0;
   double buf[];
   ArraySetAsSeries(buf, true);
   if(CopyBuffer(g_h1EmaHandle, 0, 0, 1, buf) <= 0) return 0;
   double closeH1 = iClose(_Symbol, PERIOD_H1, 0);
   if(closeH1 > buf[0]) return 1;
   if(closeH1 < buf[0]) return -1;
   return 0;
  }

//+------------------------------------------------------------------+
//| Soft confluence score, 0-100. 40 base (sweep+CHoCH already true), |
//| remaining 60 distributed across H1 alignment, FVG, displacement  |
//+------------------------------------------------------------------+
int ComputeConfluenceScore(int dir, bool hasFVG, bool dispStrong)
  {
   int score = 40;
   int bias = GetH1Bias();
   if(bias == dir) score += 25;
   else if(bias == 0) score += 10;
   if(hasFVG) score += 20;
   if(dispStrong) score += 15;
   return (int)MathMin(score, 100);
  }

//+------------------------------------------------------------------+
//| Far liquidity target used to decide SCALP vs SWING and for TP2    |
//+------------------------------------------------------------------+
double GetFarTarget(int dir, string sweptLabel)
  {
   double prevDayHigh = iHigh(_Symbol, PERIOD_D1, 1);
   double prevDayLow  = iLow(_Symbol, PERIOD_D1, 1);
   double target = (dir == 1) ? prevDayHigh : prevDayLow;

   // If we just swept that very pool, reach one day further back for a fresh target
   if((dir == 1 && sweptLabel == "PrevDayHigh") || (dir == -1 && sweptLabel == "PrevDayLow"))
      target = (dir == 1) ? iHigh(_Symbol, PERIOD_D1, 2) : iLow(_Symbol, PERIOD_D1, 2);

   return target;
  }

//+------------------------------------------------------------------+
//| Core: evaluate a confirmed signal and open a trade if it passes   |
//+------------------------------------------------------------------+
void TryOpenTrade(int dir, LiquidityPool &sweptPool)
  {
   double atr = GetATR();
   if(atr <= 0) return;

   int obShift = FindOrderBlock(dir);
   if(obShift == -1) return;

   double obHigh = iHigh(_Symbol, PERIOD_M5, obShift);
   double obLow  = iLow(_Symbol, PERIOD_M5, obShift);
   double entry  = (dir == 1) ? obHigh : obLow;

   double fvgTop = 0, fvgBottom = 0;
   bool hasFVG = DetectFVG(dir, obShift, fvgTop, fvgBottom);
   if(hasFVG)
      entry = (dir == 1) ? MathMin(entry, fvgTop) : MathMax(entry, fvgBottom);

   double curBid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double curAsk = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(dir == 1 && entry >= curAsk) return;
   if(dir == -1 && entry <= curBid) return;

   double sweepWick = (dir == -1) ? iHigh(_Symbol, PERIOD_M5, 1) : iLow(_Symbol, PERIOD_M5, 1);
   double sl = ComputeDynamicSL(dir, sweepWick, atr);
   double riskDistance = MathAbs(entry - sl);
   if(riskDistance <= 0) return;

   double tp1 = (dir == 1) ? entry + riskDistance * InpScalpRR : entry - riskDistance * InpScalpRR;
   double farTarget = GetFarTarget(dir, sweptPool.label);
   double farDistance = MathAbs(farTarget - entry);
   double potentialRR = farDistance / riskDistance;

   TradeMode mode = (potentialRR >= InpSwingMinRR) ? MODE_SWING : MODE_SCALP;
   double tp2 = (mode == MODE_SWING) ? farTarget : tp1;

   bool dispStrong = IsDisplacementStrong(atr);
   int score = ComputeConfluenceScore(dir, hasFVG, dispStrong);
   if(score < InpMinConfluenceScore) return;

   double riskPercent = InpBaseRiskPercent +
                         (InpMaxRiskPercent - InpBaseRiskPercent) *
                         ((score - InpMinConfluenceScore) / (double)MathMax(1, 100 - InpMinConfluenceScore));
   riskPercent = MathMax(InpBaseRiskPercent, MathMin(InpMaxRiskPercent, riskPercent));

   double lots = CalcLotSize(riskDistance, riskPercent);
   if(lots <= 0) return;

   // Broker-side TP is set to TP1: scalp mode exits fully there,
   // swing mode partial-closes there and then extends TP to tp2 in ManageOpenPosition.
   string comment = StringFormat("SLSSS|%s|TP2:%.5f", (mode == MODE_SWING ? "SWING" : "SCALP"), tp2);

   bool ok;
   if(dir == 1)
      ok = trade.BuyLimit(lots, NormalizeDouble(entry, _Digits), _Symbol,
                           NormalizeDouble(sl, _Digits), NormalizeDouble(tp1, _Digits),
                           ORDER_TIME_DAY, 0, comment);
   else
      ok = trade.SellLimit(lots, NormalizeDouble(entry, _Digits), _Symbol,
                            NormalizeDouble(sl, _Digits), NormalizeDouble(tp1, _Digits),
                            ORDER_TIME_DAY, 0, comment);

   if(ok)
     {
      g_tradesToday++;
      g_lastSweptLevel = sweptPool.level;
      if(InpDrawObjects)
        {
         DrawAsianRange();
         DrawOrderBlock(obShift, obHigh, obLow, dir);
         if(hasFVG) DrawFVG(fvgTop, fvgBottom, dir);
         DrawTradeLevels(entry, sl, tp1, tp2, mode);
        }
     }
  }

//+------------------------------------------------------------------+
//| ATR-based SL: structural sweep wick +/- volatility buffer         |
//+------------------------------------------------------------------+
double ComputeDynamicSL(int dir, double sweepWick, double atr)
  {
   double minPipBuffer = InpSweepBufferPips * SymbolInfoDouble(_Symbol, SYMBOL_POINT) * 10 * 1.5;
   double buffer = MathMax(atr * InpSLAtrMult, minPipBuffer);
   return (dir == 1) ? sweepWick - buffer : sweepWick + buffer;
  }

double GetATR()
  {
   double buf[];
   ArraySetAsSeries(buf, true);
   if(g_atrHandle == INVALID_HANDLE) return 0;
   if(CopyBuffer(g_atrHandle, 0, 0, 1, buf) <= 0) return 0;
   return buf[0];
  }

//+------------------------------------------------------------------+
//| Derive decimal precision for lot sizes from the symbol's volume   |
//| step (e.g. step 0.01 -> 2 digits). SYMBOL_VOLUME_DIGITS doesn't   |
//| exist as an MQL5 constant, so this is computed manually.          |
//+------------------------------------------------------------------+
int GetVolumeDigits()
  {
   double step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   int digits = 0;
   while(step < 0.999999 && digits < 8)
     {
      step *= 10;
      digits++;
     }
   return digits;
  }

//+------------------------------------------------------------------+
//| Confidence-scaled, risk-based lot sizing                         |
//+------------------------------------------------------------------+
double CalcLotSize(double slDistance, double riskPercent)
  {
   double riskMoney = AccountInfoDouble(ACCOUNT_EQUITY) * riskPercent / 100.0;
   double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double tickSize  = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   if(tickValue <= 0 || tickSize <= 0 || slDistance <= 0) return 0;

   double lossPerLot = (slDistance / tickSize) * tickValue;
   double lots = riskMoney / lossPerLot;

   double minLot  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxLot  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);

   lots = MathFloor(lots / lotStep) * lotStep;
   lots = MathMax(minLot, MathMin(maxLot, lots));
   return lots;
  }

//+------------------------------------------------------------------+
//| Manage an already-open position: partial close at TP1 for swing   |
//| trades, breakeven, then ATR trail toward TP2                     |
//+------------------------------------------------------------------+
void ManageOpenPosition()
  {
   if(!PositionSelect(_Symbol)) return;
   if(PositionGetInteger(POSITION_MAGIC) != InpMagicNumber) return;

   string comment = PositionGetString(POSITION_COMMENT);
   if(StringFind(comment, "SLSSS") != 0) return;

   bool isSwing = (StringFind(comment, "SWING") >= 0);
   if(!isSwing) return; // scalp trades are left to their single broker TP/SL, nothing to manage

   double tp2 = ParseTP2(comment);
   if(tp2 == 0) return;

   long   type   = PositionGetInteger(POSITION_TYPE);
   double vol    = PositionGetDouble(POSITION_VOLUME);
   double entry  = PositionGetDouble(POSITION_PRICE_OPEN);
   double sl     = PositionGetDouble(POSITION_SL);
   double tp1    = PositionGetDouble(POSITION_TP);
   double price  = (type == POSITION_TYPE_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_BID)
                                                : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   int dir = (type == POSITION_TYPE_BUY) ? 1 : -1;
   ulong ticket = PositionGetInteger(POSITION_TICKET);

   bool tp1Reached = (dir == 1) ? (price >= tp1) : (price <= tp1);

   // "Already partial-closed?" is tracked implicitly: once we move SL to entry below,
   // sl sitting at/through entry on a later tick tells us the partial step already ran
   // (MQL5 doesn't let us rewrite a position's comment after it's opened, so this
   // SL-vs-entry check stands in for that flag).
   bool pastBreakeven = (dir == 1) ? (sl >= entry - Point() * 2) : (sl <= entry + Point() * 2);

   if(InpUsePartialOnSwing && !pastBreakeven && tp1Reached)
     {
      double closeVol = NormalizeDouble(vol * InpPartialClosePct / 100.0, GetVolumeDigits());
      double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
      if(closeVol >= minLot && closeVol < vol)
         trade.PositionClosePartial(ticket, closeVol);

      trade.PositionModify(ticket, NormalizeDouble(entry, _Digits), NormalizeDouble(tp2, _Digits));
      return; // let the next tick pick up trailing from here
     }
   if(InpTrailAfterPartial && pastBreakeven)
     {
      double atr = GetATR();
      if(atr <= 0) return;
      double newSL = (dir == 1) ? price - atr * InpTrailAtrMult : price + atr * InpTrailAtrMult;
      bool improves = (dir == 1) ? (newSL > sl) : (newSL < sl);
      if(improves)
         trade.PositionModify(ticket, NormalizeDouble(newSL, _Digits), NormalizeDouble(tp2, _Digits));
     }
  }

double ParseTP2(string comment)
  {
   string parts[];
   int n = StringSplit(comment, '|', parts);
   for(int i = 0; i < n; i++)
      if(StringFind(parts[i], "TP2:") == 0)
         return StringToDouble(StringSubstr(parts[i], 4));
   return 0;
  }

//+------------------------------------------------------------------+
//| Session helpers                                                  |
//+------------------------------------------------------------------+
void UpdateAsianRange()
  {
   if(g_asianRangeLocked) return;
   if(IsWithinSession(InpAsianStart, InpAsianEnd)) return; // still forming
   if(!HasSessionPassedToday(InpAsianEnd)) return;

   datetime startT = SessionTimeToday(InpAsianStart);
   datetime endT   = SessionTimeToday(InpAsianEnd);
   double hi = -DBL_MAX, lo = DBL_MAX;
   int total = Bars(_Symbol, PERIOD_M15);
   for(int i = 0; i < total; i++)
     {
      datetime t = iTime(_Symbol, PERIOD_M15, i);
      if(t < startT) break;
      if(t > endT) continue;
      double h = iHigh(_Symbol, PERIOD_M15, i);
      double l = iLow(_Symbol, PERIOD_M15, i);
      if(h > hi) hi = h;
      if(l < lo) lo = l;
     }
   if(hi > -DBL_MAX && lo < DBL_MAX)
     {
      g_asianHigh = hi;
      g_asianLow  = lo;
      g_asianRangeLocked = true;
     }
  }

bool IsInAnyTradingWindow()
  {
   if(InpTradeLondon && IsWithinSession(InpLondonStart, InpLondonEnd)) return true;
   if(InpTradeNY && IsWithinSession(InpNYStart, InpNYEnd)) return true;
   return false;
  }

datetime SessionTimeToday(string hhmm)
  {
   MqlDateTime tm;
   TimeToStruct(TimeCurrent(), tm);
   int hh = (int)StringToInteger(StringSubstr(hhmm, 0, 2));
   int mm = (int)StringToInteger(StringSubstr(hhmm, 3, 2));
   return StringToTime(StringFormat("%04d.%02d.%02d %02d:%02d", tm.year, tm.mon, tm.day, hh, mm));
  }

bool IsWithinSession(string startHHMM, string endHHMM)
  {
   datetime startT = SessionTimeToday(startHHMM);
   datetime endT   = SessionTimeToday(endHHMM);
   datetime now    = TimeCurrent();
   return (now >= startT && now <= endT);
  }

bool HasSessionPassedToday(string endHHMM)
  {
   return (TimeCurrent() > SessionTimeToday(endHHMM));
  }

void ResetDailyStateIfNewDay()
  {
   MqlDateTime tm;
   TimeToStruct(TimeCurrent(), tm);
   static int lastDay = -1;
   if(tm.day != lastDay)
     {
      lastDay = tm.day;
      g_tradesToday = 0;
      g_asianHigh = 0;
      g_asianLow  = 0;
      g_asianRangeLocked = false;
      g_lastSweptLevel = 0;
      if(InpDrawObjects) ObjectsDeleteAll(0, g_objPrefix);
     }
  }

//+------------------------------------------------------------------+
//| Chart drawing helpers                                            |
//+------------------------------------------------------------------+
void DrawAsianRange()
  {
   string name = g_objPrefix + "AsianRange";
   datetime t1 = SessionTimeToday(InpAsianStart);
   datetime t2 = SessionTimeToday(InpAsianEnd);
   ObjectDelete(0, name);
   ObjectCreate(0, name, OBJ_RECTANGLE, 0, t1, g_asianHigh, t2, g_asianLow);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clrDodgerBlue);
   ObjectSetInteger(0, name, OBJPROP_FILL, true);
   ObjectSetInteger(0, name, OBJPROP_BACK, true);
  }

void DrawOrderBlock(int obShift, double obHigh, double obLow, int dir)
  {
   string name = g_objPrefix + "OB_" + IntegerToString((int)TimeCurrent());
   datetime t1 = iTime(_Symbol, PERIOD_M5, obShift);
   datetime t2 = iTime(_Symbol, PERIOD_M5, 0) + PeriodSeconds(PERIOD_M5) * 20;
   ObjectCreate(0, name, OBJ_RECTANGLE, 0, t1, obHigh, t2, obLow);
   ObjectSetInteger(0, name, OBJPROP_COLOR, (dir == 1) ? clrLime : clrRed);
   ObjectSetInteger(0, name, OBJPROP_FILL, true);
   ObjectSetInteger(0, name, OBJPROP_BACK, true);
   ObjectSetInteger(0, name, OBJPROP_STYLE, STYLE_DASH);
  }

void DrawFVG(double top, double bottom, int dir)
  {
   string name = g_objPrefix + "FVG_" + IntegerToString((int)TimeCurrent());
   datetime t1 = iTime(_Symbol, PERIOD_M5, 3);
   datetime t2 = iTime(_Symbol, PERIOD_M5, 0) + PeriodSeconds(PERIOD_M5) * 20;
   ObjectCreate(0, name, OBJ_RECTANGLE, 0, t1, top, t2, bottom);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clrOrange);
   ObjectSetInteger(0, name, OBJPROP_FILL, true);
   ObjectSetInteger(0, name, OBJPROP_BACK, true);
   ObjectSetInteger(0, name, OBJPROP_STYLE, STYLE_DOT);
  }

void DrawTradeLevels(double entry, double sl, double tp1, double tp2, TradeMode mode)
  {
   string base = g_objPrefix + "Trade_" + IntegerToString((int)TimeCurrent());
   datetime t = TimeCurrent();
   ObjectCreate(0, base + "_Entry", OBJ_HLINE, 0, t, entry);
   ObjectSetInteger(0, base + "_Entry", OBJPROP_COLOR, clrWhite);
   ObjectCreate(0, base + "_SL", OBJ_HLINE, 0, t, sl);
   ObjectSetInteger(0, base + "_SL", OBJPROP_COLOR, clrRed);
   ObjectCreate(0, base + "_TP1", OBJ_HLINE, 0, t, tp1);
   ObjectSetInteger(0, base + "_TP1", OBJPROP_COLOR, clrLime);
   if(mode == MODE_SWING && tp2 != tp1)
     {
      ObjectCreate(0, base + "_TP2", OBJ_HLINE, 0, t, tp2);
      ObjectSetInteger(0, base + "_TP2", OBJPROP_COLOR, clrAqua);
      ObjectSetInteger(0, base + "_TP2", OBJPROP_STYLE, STYLE_DASH);
     }
  }
//+------------------------------------------------------------------+
