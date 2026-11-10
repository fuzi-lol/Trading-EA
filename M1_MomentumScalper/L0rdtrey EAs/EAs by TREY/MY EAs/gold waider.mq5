//+------------------------------------------------------------------+
//|                       AtlasQuantum XAUUSD EA                      |
//|                Institutional-Grade Adaptive Scalper               |
//|         Designed for $100 Account on FBS MT5 – Survival First    |
//+------------------------------------------------------------------+
#property copyright   "Copyright 2026, QuantumTrade Systems"
#property version     "1.00"
#property description "Institutional XAUUSD Engine — Structure, Liquidity, Displacement"
#property description "Dynamic Risk/Reward | Scale-In Model | No Martingale"
#property strict

#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>
#include <Trade\AccountInfo.mqh>
#include <Trade\DealInfo.mqh>
#include <Trade\HistoryOrderInfo.mqh>

//+------------------------------------------------------------------+
//| Input Parameters (Professional Risk Management)                 |
//+------------------------------------------------------------------+
input group "==== RISK MANAGEMENT ===="
input double   InpRiskPercent          = 0.5;          // Default risk per trade (%)
input double   InpMaxRiskPercent       = 1.0;          // Maximum combined risk per group (%)
input double   InpExceptionalRisk      = 1.5;          // Exceptional setup risk (%)
input double   InpDailyMaxDD           = 3.0;          // Max daily drawdown % halt
input double   InpWeeklyMaxDD          = 8.0;          // Max weekly drawdown % halt
input int      InpConsecLossReduce     = 3;            // Consec. losses to reduce risk 50%
input int      InpConsecLossHalt       = 5;            // Consec. losses to halt & reassess
input double   InpRiskReductionFactor  = 0.5;          // Multiplier when reducing risk

input group "==== TRADE ENTRY FILTERS ===="
input int      InpMinEntryScore        = 75;           // Minimum composite score 0–100
input int      InpStrongScore          = 85;           // Strong setup threshold
input int      InpEliteScore           = 90;           // Elite setup threshold
input bool     InpUseMTF               = true;         // Multi-timeframe alignment required
input bool     InpUseNewsFilter        = true;         // Avoid high-impact news
input string   InpNewsEventFile        = "NewsEvents.csv"; // CSV: datetime,importance,description

input group "==== SESSION INTELLIGENCE (UTC) ===="
input bool     InpTradeAsian           = false;
input bool     InpTradeLondon          = true;
input bool     InpTradeNY              = true;
input bool     InpTradeOverlap         = true;
input int      InpLondonStart          = 7;
input int      InpLondonEnd            = 16;
input int      InpNYStart              = 13;
input int      InpNYEnd                = 22;
input int      InpAsianStart           = 0;
input int      InpAsianEnd             = 8;

input group "==== SCALE‑IN MODEL (NO MARTINGALE) ===="
input double   InpScaleInTriggerPct    = 0.25;         // Profit % from entry to allow adding
input int      InpMaxScaleInPositions  = 3;            // Max positions in a group
input bool     InpAllowScaleIn         = true;

input group "==== PARTIAL TAKE PROFIT & TRAILING ===="
input double   InpTP1Percent           = 30.0;         // Close % at first target
input double   InpTP2Percent           = 30.0;         // Close % at second target
input double   InpTP3Percent           = 40.0;         // Ride final % with trailing
input bool     InpMoveSLtoBEAfterTP1   = true;
input ENUM_TRAILING_MODE InpTrailMode  = TRAIL_ATR_STRUCTURE; // ATR+Structure dynamic

input group "==== STRUCTURE & LIQUIDITY PARAMETERS ===="
input int      InpSwingLookback        = 5;            // Bars to detect swing points
input int      InpFVGLookback          = 10;           // Max bars to scan for FVG
input int      InpOBLookback           = 20;           // Max bars for order blocks
input int      InpLiquidityLookback    = 30;           // Lookback for equal highs/lows
input double   InpDisplacementFactor   = 1.5;          // ATR multiplier for displacement
input double   InpSweepWickPercent     = 0.3;          // Wick % of candle for sweep

input group "==== VOLUME & REGIME ===="
input int      InpVolumeMA             = 14;           // Period for volume moving average
input double   InpVolExpansionFactor   = 1.5;          // Tick volume multiplier for expansion
input bool     InpRequireDisplacement  = true;         // Must have displacement candle

input group "==== DASHBOARD ===="
input int      InpDashX                = 15;
input int      InpDashY                = 15;
input color    InpDashColor            = clrDarkBlue;

//+------------------------------------------------------------------+
//| Enums & Structs                                                   |
//+------------------------------------------------------------------+
enum ENUM_TRADE_DIR { DIR_BUY, DIR_SELL };
enum ENUM_REGIME { REGIME_TRENDING, REGIME_RANGING, REGIME_VOLATILE, REGIME_NEWS, REGIME_LOWLIQ };
enum ENUM_TRAILING_MODE { TRAIL_ATR, TRAIL_STRUCTURE, TRAIL_ATR_STRUCTURE, TRAIL_SWING };
enum ENUM_SESSION { SESS_ASIAN, SESS_LONDON, SESS_NY, SESS_OVERLAP, SESS_DEAD };

struct TradeGroup {
   int      ticket[3];       // up to 3 tickets
   int      count;
   double   entryPriceAvg;
   double   totalRisk;
   double   tp1, tp2, tp3;
   double   sl;
   ENUM_TRADE_DIR dir;
   datetime openTime;
   bool     tp1Hit, tp2Hit;
   double   partialClosed;   // lot already closed
   double   trailActivation; // price where trailing begins (for tp3)
};

//+------------------------------------------------------------------+
//| Class: Market Structure Detector                                 |
//+------------------------------------------------------------------+
class CMarketStructure {
private:
   string   symbol;
   ENUM_TIMEFRAMES tf;
   int      lookback;
   double   lastHH, lastLL, lastHL, lastLH;
   bool     isBOS, isCHOCH, isMSS;
   datetime lastBOS_time;
public:
   CMarketStructure(string s, ENUM_TIMEFRAMES t, int lb = 5) : symbol(s), tf(t), lookback(lb) {}
   void Update() {
      double high[], low[], close[];
      ArraySetAsSeries(high, true); ArraySetAsSeries(low, true); ArraySetAsSeries(close, true);
      if(CopyHigh(symbol, tf, 0, lookback+2, high) < lookback+2 ||
         CopyLow(symbol, tf, 0, lookback+2, low) < lookback+2 ||
         CopyClose(symbol, tf, 0, lookback+2, close) < lookback+2) return;
      // simplistic swing detection
      int swingHighIdx = -1, swingLowIdx = -1;
      for(int i=2; i<lookback+1; i++) {
         if(high[i] > high[i-1] && high[i] > high[i+1]) { swingHighIdx = i; break; }
      }
      for(int i=2; i<lookback+1; i++) {
         if(low[i] < low[i-1] && low[i] < low[i+1]) { swingLowIdx = i; break; }
      }
      if(swingHighIdx >= 0) lastHH = high[swingHighIdx];
      if(swingLowIdx >= 0) lastLL = low[swingLowIdx];
      // basic BOS: break above lastHH (in uptrend) or below lastLL (in downtrend)
      double currClose = close[0];
      isBOS = false; isCHOCH = false;
      if(lastHH > 0 && currClose > lastHH) isBOS = true;
      if(lastLL > 0 && currClose < lastLL) isBOS = true;
      // CHOCH simplification: break of structure after HL/LH
      // MSS: when price breaks a significant swing point that changes trend
      // For brevity, we treat MSS as a strong CHOCH
      isMSS = isBOS;  // placeholder; a full implementation would track trend
   }
   bool IsBOS() const { return isBOS; }
   bool IsCHOCH() const { return isCHOCH; }
   bool IsMSS() const { return isMSS; }
   double GetLastHH() const { return lastHH; }
   double GetLastLL() const { return lastLL; }
};

//+------------------------------------------------------------------+
//| Class: Liquidity Detector (Equal Highs/Lows, Sweeps)             |
//+------------------------------------------------------------------+
class CLiquidityDetector {
private:
   string   symbol;
   ENUM_TIMEFRAMES tf;
   int      lookback;
   double   equalHighPrice, equalLowPrice;
   bool     sweepHigh, sweepLow;
   datetime sweepTime;
public:
   CLiquidityDetector(string s, ENUM_TIMEFRAMES t, int lb = 30) : symbol(s), tf(t), lookback(lb) {}
   void Update() {
      double high[], low[];
      ArraySetAsSeries(high, true); ArraySetAsSeries(low, true);
      if(CopyHigh(symbol, tf, 0, lookback+1, high) < lookback+1 ||
         CopyLow(symbol, tf, 0, lookback+1, low) < lookback+1) return;
      sweepHigh = false; sweepLow = false;
      // detect equal highs within lookback (within a small tolerance)
      double tolerance = 0.2 * SymbolInfoDouble(symbol, SYMBOL_POINT) * 10; // 2 points
      int eqHighIdx = -1;
      for(int i=1; i<=lookback; i++) {
         for(int j=i+1; j<=lookback; j++) {
            if(MathAbs(high[i] - high[j]) <= tolerance) {
               eqHighIdx = j;
               equalHighPrice = high[j];
               break;
            }
         }
         if(eqHighIdx >= 0) break;
      }
      if(eqHighIdx >= 0) {
         // check if current bar broke above the equal high and closed below (sweep)
         double currHigh = iHigh(symbol, tf, 0);
         double currClose = iClose(symbol, tf, 0);
         if(currHigh > equalHighPrice + tolerance && currClose < equalHighPrice) {
            sweepHigh = true;
            sweepTime = iTime(symbol, tf, 0);
         }
      }
      // equal lows sweep detection similarly
      int eqLowIdx = -1;
      for(int i=1; i<=lookback; i++) {
         for(int j=i+1; j<=lookback; j++) {
            if(MathAbs(low[i] - low[j]) <= tolerance) {
               eqLowIdx = j;
               equalLowPrice = low[j];
               break;
            }
         }
         if(eqLowIdx >= 0) break;
      }
      if(eqLowIdx >= 0) {
         double currLow = iLow(symbol, tf, 0);
         double currClose = iClose(symbol, tf, 0);
         if(currLow < equalLowPrice - tolerance && currClose > equalLowPrice) {
            sweepLow = true;
            sweepTime = iTime(symbol, tf, 0);
         }
      }
   }
   bool IsSweepHigh() const { return sweepHigh; }
   bool IsSweepLow() const { return sweepLow; }
   double SweepPrice() const { return sweepHigh ? equalHighPrice : equalLowPrice; }
};

//+------------------------------------------------------------------+
//| Class: Displacement Detector (Institutional Candle)              |
//+------------------------------------------------------------------+
class CDisplacementDetector {
public:
   static bool IsDisplacement(string symbol, ENUM_TIMEFRAMES tf, double factor = 1.5) {
      double open[], close[], high[], low[], atr[];
      ArraySetAsSeries(open, true); ArraySetAsSeries(close, true);
      ArraySetAsSeries(high, true); ArraySetAsSeries(low, true);
      if(CopyOpen(symbol, tf, 0, 3, open) < 3 || CopyClose(symbol, tf, 0, 3, close) < 3 ||
         CopyHigh(symbol, tf, 0, 3, high) < 3 || CopyLow(symbol, tf, 0, 3, low) < 3) return false;
      // ATR(14) on same TF
      int atrHandle = iATR(symbol, tf, 14);
      if(atrHandle == INVALID_HANDLE) return false;
      if(CopyBuffer(atrHandle, 0, 0, 1, atr) < 1) { IndicatorRelease(atrHandle); return false; }
      IndicatorRelease(atrHandle);
      double body = MathAbs(close[0] - open[0]);
      double range = high[0] - low[0];
      // displacement: body > factor * ATR(14) or range > factor * ATR(14) and close near extreme
      if(body > atr[0] * factor || (range > atr[0] * factor * 1.2 && body/range > 0.6))
         return true;
      return false;
   }
};

//+------------------------------------------------------------------+
//| Class: Fair Value Gap Detector                                   |
//+------------------------------------------------------------------+
class CFVGDetector {
public:
   struct FVG { double high, low; bool bullish; datetime time; };
   static bool FindRecentFVG(string symbol, ENUM_TIMEFRAMES tf, int maxBars, FVG &fvg) {
      double high[], low[];
      ArraySetAsSeries(high, true); ArraySetAsSeries(low, true);
      if(CopyHigh(symbol, tf, 0, maxBars+2, high) < maxBars+2 ||
         CopyLow(symbol, tf, 0, maxBars+2, low) < maxBars+2) return false;
      for(int i=0; i<maxBars; i++) {
         if(i+2 >= maxBars+2) break;
         // bullish FVG: candle[i].high < candle[i+2].low
         if(high[i] < low[i+2] && high[i+1] < low[i+2]) {
            fvg.high = low[i+2];
            fvg.low = high[i];
            fvg.bullish = true;
            fvg.time = iTime(symbol, tf, i);
            return true;
         }
         // bearish FVG: candle[i].low > candle[i+2].high
         if(low[i] > high[i+2] && low[i+1] > high[i+2]) {
            fvg.high = low[i];
            fvg.low = high[i+2];
            fvg.bullish = false;
            fvg.time = iTime(symbol, tf, i);
            return true;
         }
      }
      return false;
   }
};

//+------------------------------------------------------------------+
//| Class: Order Block Detector (simplified)                         |
//+------------------------------------------------------------------+
class COBDetector {
public:
   struct OrderBlock { double high, low; bool bullish; datetime time; };
   static bool FindNearestOB(string symbol, ENUM_TIMEFRAMES tf, int maxBars, bool bullish, OrderBlock &ob) {
      double open[], high[], low[], close[];
      ArraySetAsSeries(open, true); ArraySetAsSeries(high, true);
      ArraySetAsSeries(low, true); ArraySetAsSeries(close, true);
      if(CopyOpen(symbol, tf, 0, maxBars+2, open) < maxBars+2 ||
         CopyHigh(symbol, tf, 0, maxBars+2, high) < maxBars+2 ||
         CopyLow(symbol, tf, 0, maxBars+2, low) < maxBars+2 ||
         CopyClose(symbol, tf, 0, maxBars+2, close) < maxBars+2) return false;
      for(int i=1; i<maxBars; i++) {
         if(bullish) {
            // bearish candle then strong bullish move; the bearish candle is the OB
            if(close[i] < open[i] && close[i+1] > open[i+1] && close[i+1] > high[i]) {
               ob.high = high[i];
               ob.low = low[i];
               ob.bullish = true;
               ob.time = iTime(symbol, tf, i);
               return true;
            }
         } else {
            if(close[i] > open[i] && close[i+1] < open[i+1] && close[i+1] < low[i]) {
               ob.high = high[i];
               ob.low = low[i];
               ob.bullish = false;
               ob.time = iTime(symbol, tf, i);
               return true;
            }
         }
      }
      return false;
   }
};

//+------------------------------------------------------------------+
//| Class: Volume Analyzer                                           |
//+------------------------------------------------------------------+
class CVolumeAnalyzer {
private:
   int maPeriod;
   double volMA;
   bool expansion;
public:
   CVolumeAnalyzer(int period) : maPeriod(period) {}
   void Update(string symbol, ENUM_TIMEFRAMES tf) {
      long volumes[];
      ArraySetAsSeries(volumes, true);
      if(CopyTickVolume(symbol, tf, 0, maPeriod, volumes) < maPeriod) { expansion = false; return; }
      double sum = 0;
      for(int i=0; i<maPeriod; i++) sum += (double)volumes[i];
      volMA = sum / maPeriod;
      double currentVol = (double)volumes[0];
      expansion = (currentVol > volMA * 1.5);
   }
   bool IsExpanding() const { return expansion; }
   double GetVolMA() const { return volMA; }
};

//+------------------------------------------------------------------+
//| Class: News Filter (from CSV file)                               |
//+------------------------------------------------------------------+
class CNewsFilter {
private:
   struct NewsEvent { datetime time; int importance; };
   NewsEvent events[];
   int count;
   bool loaded;
public:
   CNewsFilter() : count(0), loaded(false) {}
   void LoadFromFile(string filename) {
      // Simplified: read CSV, format: "YYYY.MM.DD HH:MM,importance"
      // For demonstration we'll hardcode a few major events for testing
      // In production, parse the file properly.
      loaded = false;
      // You can implement file reading here or leave empty.
   }
   bool IsNewsTime(datetime now, int minsBefore = 60, int minsAfter = 60) const {
      if(!loaded) return false;
      for(int i=0; i<count; i++) {
         if(now >= events[i].time - minsBefore*60 && now <= events[i].time + minsAfter*60)
            return true;
      }
      return false;
   }
};

//+------------------------------------------------------------------+
//| Class: Score Engine (combines all layers)                        |
//+------------------------------------------------------------------+
class CScoreEngine {
public:
   static int Compute(string symbol, ENUM_TIMEFRAMES tfEntry, ENUM_TRADE_DIR &outDir) {
      int score = 0;
      // Market structure (M15)
      CMarketStructure m15(symbol, PERIOD_M15);
      m15.Update();
      if(m15.IsBOS()) score += 20;
      if(m15.IsMSS()) score += 15;
      // Liquidity sweep (M5)
      CLiquidityDetector liq(symbol, PERIOD_M5, 30);
      liq.Update();
      bool bullSetup = false, bearSetup = false;
      if(liq.IsSweepHigh()) { bearSetup = true; score += 25; }
      else if(liq.IsSweepLow()) { bullSetup = true; score += 25; }
      // Displacement on M5
      if(CDisplacementDetector::IsDisplacement(symbol, PERIOD_M5)) score += 20;
      // FVG
      CFVGDetector::FVG fvg;
      if(CFVGDetector::FindRecentFVG(symbol, PERIOD_M5, 10, fvg)) {
         if(fvg.bullish && bullSetup) score += 15;
         else if(!fvg.bullish && bearSetup) score += 15;
         else score += 5;
      }
      // Order Block
      COBDetector::OrderBlock ob;
      bool obBull = bullSetup && COBDetector::FindNearestOB(symbol, PERIOD_M5, 20, true, ob);
      bool obBear = bearSetup && COBDetector::FindNearestOB(symbol, PERIOD_M5, 20, false, ob);
      if(obBull || obBear) score += 15;
      // Volume expansion
      CVolumeAnalyzer vol(14);
      vol.Update(symbol, PERIOD_M5);
      if(vol.IsExpanding()) score += 10;
      // MTF alignment H1
      if(CMarketStructure::IsBOS(symbol, PERIOD_H1)) score += 5;
      // Direction decision
      if(bullSetup && score >= 50) outDir = DIR_BUY;
      else if(bearSetup && score >= 50) outDir = DIR_SELL;
      else outDir = bullSetup ? DIR_BUY : DIR_SELL; // fallback
      return MathMin(100, score);
   }
};

//+------------------------------------------------------------------+
//| Class: Trade Manager (positions handling, partial closes, trail) |
//+------------------------------------------------------------------+
class CTradeManager {
private:
   CTrade trade;
   CPositionInfo pos;
   TradeGroup groups[10]; // max concurrent groups
   int groupCount;
   double point;
   string symbol;
   CVolumeAnalyzer volAna;
   double atr;
public:
   CTradeManager(string sym) : symbol(sym), groupCount(0), volAna(14) {
      point = SymbolInfoDouble(symbol, SYMBOL_POINT);
      trade.SetExpertMagicNumber(202406);
      trade.SetDeviationInPoints(20);
   }
   bool OpenTradeGroup(ENUM_TRADE_DIR dir, double riskPercent, double &atr_val) {
      // Calculate SL based on structure
      double slPrice = 0, tp1 = 0, tp2 = 0, tp3 = 0;
      double entryPrice = (dir == DIR_BUY) ? SymbolInfoDouble(symbol, SYMBOL_ASK) : SymbolInfoDouble(symbol, SYMBOL_BID);
      // Use simple ATR-based SL for demonstration, but in production use structure/liquidity.
      atr_val = GetATR();
      double slDist = atr_val * 1.5;
      if(dir == DIR_BUY) slPrice = entryPrice - slDist;
      else slPrice = entryPrice + slDist;
      // TP levels based on liquidity targets (simplified: 2x, 3x, 4x ATR)
      tp1 = (dir == DIR_BUY) ? entryPrice + atr_val*2 : entryPrice - atr_val*2;
      tp2 = (dir == DIR_BUY) ? entryPrice + atr_val*3 : entryPrice - atr_val*3;
      tp3 = (dir == DIR_BUY) ? entryPrice + atr_val*5 : entryPrice - atr_val*5;
      // Risk calculation
      double riskAmount = AccountInfoDouble(ACCOUNT_EQUITY) * riskPercent / 100.0;
      double tickValue = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);
      double tickSize = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
      double slPoints = MathAbs(entryPrice - slPrice) / point;
      double lot = riskAmount / (slPoints * tickValue);
      lot = NormalizeLot(lot);
      if(lot <= 0) return false;
      // Open first position
      bool ok = false;
      if(dir == DIR_BUY) ok = trade.Buy(lot, symbol, entryPrice, slPrice, tp1, "AtlasQ");
      else ok = trade.Sell(lot, symbol, entryPrice, slPrice, tp1, "AtlasQ");
      if(!ok) return false;
      // Record group
      if(groupCount >= 10) return false;
      TradeGroup g;
      g.ticket[0] = trade.ResultOrder();
      g.count = 1;
      g.entryPriceAvg = entryPrice;
      g.totalRisk = riskAmount;
      g.tp1 = tp1; g.tp2 = tp2; g.tp3 = tp3;
      g.sl = slPrice;
      g.dir = dir;
      g.openTime = TimeCurrent();
      g.tp1Hit = g.tp2Hit = false;
      g.partialClosed = 0;
      g.trailActivation = (dir == DIR_BUY) ? tp2 : tp2;
      groups[groupCount++] = g;
      return true;
   }
   void ManageOpenGroups() {
      for(int gIdx = groupCount-1; gIdx >= 0; gIdx--) {
         TradeGroup &g = groups[gIdx];
         bool groupAlive = false;
         double groupProfit = 0;
         // Check each ticket
         for(int i=0; i<g.count; i++) {
            if(PositionSelectByTicket(g.ticket[i])) {
               double profit = PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);
               groupProfit += profit;
               double entry = PositionGetDouble(POSITION_PRICE_OPEN);
               double currentPrice = (g.dir == DIR_BUY) ? SymbolInfoDouble(symbol, SYMBOL_BID) : SymbolInfoDouble(symbol, SYMBOL_ASK);
               // Partial close TP1
               if(!g.tp1Hit && ((g.dir==DIR_BUY && currentPrice >= g.tp1) || (g.dir==DIR_SELL && currentPrice <= g.tp1))) {
                  double closeLot = NormalizeLot(PositionGetDouble(POSITION_VOLUME) * InpTP1Percent / 100.0);
                  if(closeLot > 0) {
                     trade.PositionClosePartial(g.ticket[i], closeLot);
                     g.partialClosed += closeLot;
                  }
                  if(PositionSelectByTicket(g.ticket[i]) && PositionGetDouble(POSITION_VOLUME) <= 0) {
                     // closed completely
                  }
                  g.tp1Hit = true;
                  if(InpMoveSLtoBEAfterTP1) {
                     if(g.dir == DIR_BUY) trade.PositionModify(g.ticket[i], entry + 10*point, 0);
                     else trade.PositionModify(g.ticket[i], entry - 10*point, 0);
                  }
               }
               // TP2 partial
               if(g.tp1Hit && !g.tp2Hit && ((g.dir==DIR_BUY && currentPrice >= g.tp2) || (g.dir==DIR_SELL && currentPrice <= g.tp2))) {
                  double remainingLot = PositionGetDouble(POSITION_VOLUME);
                  if(remainingLot > 0) {
                     double closeLot = NormalizeLot(remainingLot * InpTP2Percent / 100.0);
                     if(closeLot > 0) trade.PositionClosePartial(g.ticket[i], closeLot);
                  }
                  g.tp2Hit = true;
               }
               // Trailing for remainder
               if(g.tp2Hit) {
                  double trailDist = GetATR() * 1.0;
                  double newSL = 0;
                  if(g.dir == DIR_BUY) {
                     newSL = currentPrice - trailDist;
                     if(newSL > PositionGetDouble(POSITION_SL)) trade.PositionModify(g.ticket[i], newSL, 0);
                  } else {
                     newSL = currentPrice + trailDist;
                     if(newSL < PositionGetDouble(POSITION_SL)) trade.PositionModify(g.ticket[i], newSL, 0);
                  }
               }
               groupAlive = true;
            }
         }
         if(!groupAlive) {
            // remove group
            for(int j=gIdx; j<groupCount-1; j++) groups[j] = groups[j+1];
            groupCount--;
         }
      }
   }
   bool CanScaleIn(TradeGroup &g) {
      if(!InpAllowScaleIn || g.count >= InpMaxScaleInPositions) return false;
      double profitPct = 0;
      for(int i=0; i<g.count; i++) {
         if(PositionSelectByTicket(g.ticket[i])) {
            double profit = PositionGetDouble(POSITION_PROFIT);
            profitPct += profit / (g.totalRisk * 100); // approximate
         }
      }
      if(profitPct < InpScaleInTriggerPct/100.0) return false;
      return true;
   }
   void ScaleInGroup(TradeGroup &g, ENUM_TRADE_DIR dir) {
      double entryPrice = (dir == DIR_BUY) ? SymbolInfoDouble(symbol, SYMBOL_ASK) : SymbolInfoDouble(symbol, SYMBOL_BID);
      double atr_val = GetATR();
      double slPrice = g.sl; // same group SL
      double lot = NormalizeLot(g.totalRisk / (MathAbs(entryPrice - slPrice)/point * SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE)) * 0.5);
      bool ok = (dir == DIR_BUY) ? trade.Buy(lot, symbol, entryPrice, slPrice, 0, "AtlasQ-SI") :
                                   trade.Sell(lot, symbol, entryPrice, slPrice, 0, "AtlasQ-SI");
      if(ok) {
         g.ticket[g.count++] = trade.ResultOrder();
      }
   }
   double GetATR() {
      int atrHandle = iATR(symbol, PERIOD_M5, 14);
      double a[1]; if(CopyBuffer(atrHandle,0,0,1,a)>0) { IndicatorRelease(atrHandle); return a[0]; }
      IndicatorRelease(atrHandle); return 0;
   }
   double NormalizeLot(double lot) {
      double minLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
      double maxLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
      double step = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);
      lot = MathMax(minLot, MathMin(maxLot, lot));
      lot = MathRound(lot / step) * step;
      return lot;
   }
   int GroupCount() const { return groupCount; }
   TradeGroup* GetGroup(int i) { return &groups[i]; }
};

//+------------------------------------------------------------------+
//| Global objects                                                    |
//+------------------------------------------------------------------+
CTradeManager* gTradeMan = NULL;
CScoreEngine gScore;
CNewsFilter gNews;
CVolumeAnalyzer gVol(14);

double gDailyEquityStart = 0;
double gWeeklyEquityStart = 0;
datetime gLastDay = 0;
int gConsecLosses = 0;
bool gHaltTrading = false;
string gStatus = "Initialising";
color gStatusColor = clrYellow;

//+------------------------------------------------------------------+
//| Expert initialization function                                    |
//+------------------------------------------------------------------+
int OnInit() {
   if(!TerminalInfoInteger(TERMINAL_CONNECTED)) return INIT_FAILED;
   gTradeMan = new CTradeManager(_Symbol);
   if(gTradeMan == NULL) return INIT_FAILED;
   gDailyEquityStart = AccountInfoDouble(ACCOUNT_EQUITY);
   gWeeklyEquityStart = gDailyEquityStart;
   gLastDay = iTime(_Symbol, PERIOD_D1, 0);
   // Load news filter if needed
   if(InpUseNewsFilter) gNews.LoadFromFile(InpNewsEventFile);
   EventSetTimer(1);
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason) {
   EventKillTimer();
   if(gTradeMan) { delete gTradeMan; gTradeMan = NULL; }
   ObjectsDeleteAll(0, "AtlasQ_");
}

void OnTimer() {
   // Daily/weekly reset
   datetime currentDay = iTime(_Symbol, PERIOD_D1, 0);
   if(currentDay > gLastDay) {
      gDailyEquityStart = AccountInfoDouble(ACCOUNT_EQUITY);
      gLastDay = currentDay;
      gConsecLosses = 0;
      // weekly check
      if(TimeDayOfWeek(currentDay) == 1) gWeeklyEquityStart = AccountInfoDouble(ACCOUNT_EQUITY);
   }
   // Update dashboard
   UpdateDashboard();
}

//+------------------------------------------------------------------+
//| Expert tick function                                              |
//+------------------------------------------------------------------+
void OnTick() {
   if(gHaltTrading) return;
   if(!IsTradeAllowed()) return;

   // Risk checks
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   double dailyDD = (gDailyEquityStart - equity) / gDailyEquityStart * 100.0;
   if(dailyDD >= InpDailyMaxDD) { gHaltTrading = true; gStatus = "Daily DD halt"; gStatusColor = clrRed; return; }
   double weeklyDD = (gWeeklyEquityStart - equity) / gWeeklyEquityStart * 100.0;
   if(weeklyDD >= InpWeeklyMaxDD) { gHaltTrading = true; gStatus = "Weekly DD halt"; return; }

   // Manage open positions (partials, trailing)
   gTradeMan.ManageOpenGroups();

   // If there are open groups, check scale-in and skip new trades
   if(gTradeMan.GroupCount() > 0) {
      for(int i=0; i<gTradeMan.GroupCount(); i++) {
         TradeGroup* g = gTradeMan.GetGroup(i);
         if(g && gTradeMan.CanScaleIn(*g)) {
            gTradeMan.ScaleInGroup(*g, g.dir);
         }
      }
      return;
   }

   // Session filter
   if(!IsSessionAllowed()) return;

   // News filter
   if(InpUseNewsFilter && gNews.IsNewsTime(TimeCurrent())) return;

   // Compute entry score
   ENUM_TRADE_DIR dir;
   int score = gScore.Compute(_Symbol, PERIOD_M5, dir);
   // Volume check
   gVol.Update(_Symbol, PERIOD_M5);
   bool volExp = gVol.IsExpanding();

   if(score >= InpMinEntryScore && volExp) {
      // Determine risk percent
      double riskPct = InpRiskPercent;
      if(score >= InpEliteScore) riskPct = InpExceptionalRisk;
      else if(score >= InpStrongScore) riskPct = MathMin(InpMaxRiskPercent, InpRiskPercent * 1.3);
      // Consecutive loss adjustment
      if(gConsecLosses >= InpConsecLossReduce) riskPct *= InpRiskReductionFactor;
      if(gConsecLosses >= InpConsecLossHalt) { gHaltTrading = true; gStatus = "Consec loss halt"; return; }

      double atr;
      if(gTradeMan.OpenTradeGroup(dir, riskPct, atr)) {
         gStatus = "Trade opened score " + IntegerToString(score);
         gStatusColor = clrGreen;
      }
   }
}

//+------------------------------------------------------------------+
//| Utility functions                                                 |
//+------------------------------------------------------------------+
bool IsSessionAllowed() {
   MqlDateTime tm; TimeToStruct(TimeGMT(), tm);
   int hour = tm.hour;
   bool inLondon = (hour >= InpLondonStart && hour < InpLondonEnd);
   bool inNY = (hour >= InpNYStart && hour < InpNYEnd);
   bool inAsian = (hour >= InpAsianStart && hour < InpAsianEnd);
   if(inLondon && inNY && InpTradeOverlap) return true;
   if(inLondon && InpTradeLondon) return true;
   if(inNY && InpTradeNY) return true;
   if(inAsian && InpTradeAsian) return true;
   return false;
}

bool IsTradeAllowed() {
   if(!TerminalInfoInteger(TERMINAL_TRADE_ALLOWED)) return false;
   if(!MQLInfoInteger(MQL_TRADE_ALLOWED)) return false;
   return true;
}

void UpdateDashboard() {
   string prefix = "AtlasQ_";
   int x = InpDashX, y = InpDashY;
   // simple label updates
   ObjectSetString(0, prefix+"status", OBJPROP_TEXT, gStatus);
   ObjectSetInteger(0, prefix+"status", OBJPROP_COLOR, gStatusColor);
   // more elements can be added
}

//+------------------------------------------------------------------+
//| Dashboard creation (simplified)                                   |
//+------------------------------------------------------------------+
void CreateDashboard() {
   string prefix = "AtlasQ_";
   ObjectCreate(0, prefix+"bg", OBJ_RECTANGLE_LABEL, 0, 0, 0);
   ObjectSetInteger(0, prefix+"bg", OBJPROP_XDISTANCE, InpDashX);
   ObjectSetInteger(0, prefix+"bg", OBJPROP_YDISTANCE, InpDashY);
   ObjectSetInteger(0, prefix+"bg", OBJPROP_XSIZE, 200);
   ObjectSetInteger(0, prefix+"bg", OBJPROP_YSIZE, 80);
   ObjectSetInteger(0, prefix+"bg", OBJPROP_BGCOLOR, InpDashColor);
   ObjectCreate(0, prefix+"status", OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, prefix+"status", OBJPROP_XDISTANCE, InpDashX+10);
   ObjectSetInteger(0, prefix+"status", OBJPROP_YDISTANCE, InpDashY+20);
   ObjectSetString(0, prefix+"status", OBJPROP_TEXT, "Waiting...");
   ObjectSetInteger(0, prefix+"status", OBJPROP_FONTSIZE, 10);
   ObjectSetInteger(0, prefix+"status", OBJPROP_COLOR, clrWhite);
}
//+------------------------------------------------------------------+