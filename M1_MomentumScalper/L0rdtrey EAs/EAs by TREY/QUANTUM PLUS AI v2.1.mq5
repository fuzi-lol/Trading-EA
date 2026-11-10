//+------------------------------------------------------------------+
//|                                    QUANTUM PLUS AI v2.0          |
//|                          Institutional AI Market Analyst         |
//|                          Optimized & Debugged Version            |
//+------------------------------------------------------------------+
#property copyright   "Quantum Plus AI v2.0 - Professional Edition"
#property version     "2.01"
#property description "Institutional AI Market Analyst - Fixed & Optimized"
#property strict

#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>
#include <Trade\AccountInfo.mqh>

//=====================================================================
//  CORE DEFINITIONS
//=====================================================================
#define PREFIX "QPA2_"

//=====================================================================
//  ENUMERATIONS
//=====================================================================
enum ENUM_REGIME
{
   REGIME_TRENDING,
   REGIME_RANGING,
   REGIME_BREAKOUT,
   REGIME_COMPRESSION,
   REGIME_EXPANSION,
   REGIME_LIQUIDITY_SWEEP,
   REGIME_UNSAFE
};

enum ENUM_STRATEGY
{
   STRAT_NONE,
   STRAT_TREND_FOLLOW,
   STRAT_MEAN_REVERSION,
   STRAT_BREAKOUT,
   STRAT_LIQUIDITY_GRAB
};

//=====================================================================
//  STRUCTURES
//=====================================================================
struct SRegime
{
   ENUM_REGIME  type;
   double       confidence;
   double       stability;
};

struct SVolatility
{
   double atrCurrent;
   double atrAverage;
   double atrRatio;
   bool   isHigh;
   bool   isExpanding;
};

struct SLiquidity
{
   bool   equalHighsDetected;
   bool   equalLowsDetected;
   double equalHighLevel;
   double equalLowLevel;
   bool   sweepUpDetected;
   bool   sweepDownDetected;
};

struct SBias
{
   int h1;
   int m15;
   int m5;
   double alignment;
};

struct SRisk
{
   double dailyLoss;
   double maxDD;
   bool   limitHit;
   double peakEquity;
};

//=====================================================================
//  INPUTS
//=====================================================================
input group "===== IDENTITY ====="
input ulong  InpMagic = 778800;

input group "===== RISK MANAGEMENT ====="
input double InpRiskPercent = 0.5;           // Risk per trade (%)
input double InpMaxDailyLoss = 3.0;          // Max daily loss (%)
input double InpMaxDrawdown = 12.0;          // Max drawdown (%)
input int    InpMaxDailyTrades = 8;          // Max trades per day
input int    InpMaxPositions = 1;            // Max concurrent positions

input group "===== FILTERS ====="
input double InpMaxSpread = 30;              // Max spread (points)
input int    InpCooldownSec = 60;            // Cooldown after trade (sec)

input group "===== INDICATORS ====="
input int    InpATRPeriod = 14;              // ATR Period
input int    InpEMAFast = 8;                 // EMA Fast
input int    InpEMASlow = 21;                // EMA Slow
input int    InpRSIPeriod = 14;              // RSI Period

input group "===== DISPLAY ====="
input bool   InpShowPanel = true;            // Show info panel
input int    InpPanelX = 20;                 // Panel X position
input int    InpPanelY = 20;                 // Panel Y position

//=====================================================================
//  GLOBALS
//=====================================================================
CTrade         g_trade;
CPositionInfo  g_position;
CAccountInfo   g_account;

// Indicator handles
int g_h1_ema_fast, g_h1_ema_slow, g_h1_atr;
int g_m15_ema_fast, g_m15_ema_slow, g_m15_rsi;
int g_m5_ema_fast, g_m5_ema_slow, g_m5_atr, g_m5_rsi;

// State variables
SRegime      g_regime;
SVolatility  g_vol;
SLiquidity   g_liq;
SBias        g_bias;
SRisk        g_risk;

int          g_tradesT<br/>oday = 0;
datetime     g_dayStart = 0;
datetime     g_lastTrade = 0;
bool         g_initialized = false;

//=====================================================================
//  UTILITY FUNCTIONS
//=====================================================================
double NormalizePrice(double price)
{
   return NormalizeDouble(price, (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS));
}

datetime GetDayStart(datetime time)
{
   MqlDateTime dt;
   TimeToStruct(time, dt);
   dt.hour = 0; dt.min = 0; dt.sec = 0;
   return StructToTime(dt);
}

ENUM_ORDER_TYPE_FILLING GetFillingMode()
{
   uint filling = (uint)SymbolInfoInteger(_Symbol, SYMBOL_FILLING_MODE);
   if((filling & SYMBOL_FILLING_FOK) != 0) return ORDER_FILLING_FOK;
   if((filling & SYMBOL_FILLING_IOC) != 0) return ORDER_FILLING_IOC;
   return ORDER_FILLING_RETURN;
}

int CountPositions()
{
   int count = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(g_position.SelectByIndex(i))
         if(g_position.Magic() == InpMagic && g_position.Symbol() == _Symbol)
            count++;
   }
   return count;
}

//=====================================================================
//  MULTI-TIMEFRAME BIAS
//=====================================================================
int CalculateBias(int handleFast, int handleSlow)
{
   double fast[2], slow[2];
   if(CopyBuffer(handleFast, 0, 0, 2, fast) < 2) return 0;
   if(CopyBuffer(handleSlow, 0, 0, 2, slow) < 2) return 0;
   
   if(fast[0] > slow[0] && fast[1] > slow[1]) return 1;   // Bullish
   if(fast[0] < slow[0] && fast[1] < slow[1]) return -1;  // Bearish
   return 0;
}

void UpdateBias()
{
   g_bias.h1 = CalculateBias(g_h1_ema_fast, g_h1_ema_slow);
   g_bias.m15 = CalculateBias(g_m15_ema_fast, g_m15_ema_slow);
   g_bias.m5 = CalculateBias(g_m5_ema_fast, g_m5_ema_slow);
   
   // Calculate alignment
   int sum = 0;
   int count = 0;
   if(g_bias.h1 != 0) { sum += g_bias.h1; count++; }
   if(g_bias.m15 != 0) { sum += g_bias.m15; count++; }
   if(g_bias.m5 != 0) { sum += g_bias.m5; count++; }
   
   if(count == 0)
      g_bias.alignment = 0;
   else if(MathAbs(sum) == count)
      g_bias.alignment = 100.0;
   else
      g_bias.alignment = 100.0 * MathAbs(sum) / count;
}

//=====================================================================
//  VOLATILITY ENGINE
//=====================================================================
void UpdateVolatility()
{
   double atr[];
   ArraySetAsSeries(atr, true);
   
   if(CopyBuffer(g_m5_atr, 0, 0, 100, atr) < 100)
   {
      g_vol.atrCurrent = 0;
      g_vol.atrAverage = 0;
      g_vol.atrRatio = 1.0;
      return;
   }
   
   g_vol.atrCurrent = atr[0];
   
   double sum = 0;
   for(int i = 0; i < 100; i++)
      sum += atr[i];
   g_vol.atrAverage = sum / 100.0;
   
   if(g_vol.atrAverage > 0)
      g_vol.atrRatio = g_vol.atrCurrent / g_vol.atrAverage;
   else
      g_vol.atrRatio = 1.0;
   
   g_vol.isHigh = (g_vol.atrRatio > 1.3);
   g_vol.isExpanding = (g_vol.atrRatio > 1.1 && atr[0] > atr[1]);
}

//=====================================================================
//  LIQUIDITY DETECTION
//=====================================================================
void UpdateLiquidity()
{
   g_liq.equalHighsDetected = false;
   g_liq.equalLowsDetected = false;
   g_liq.sweepUpDetected = false;
   g_liq.sweepDownDetected = false;
   
   double tolerance = SymbolInfoDouble(_Symbol, SYMBOL_POINT) * 20;
   
   // Find equal highs
   double high1 = iHigh(_Symbol, PERIOD_M5, 1);
   double high2 = iHigh(_Symbol, PERIOD_M5, 2);
   for(int i = 3; i < 20; i++)
   {
      double h = iHigh(_Symbol, PERIOD_M5, i);
      if(MathAbs(high1 - h) < tolerance || MathAbs(high2 - h) < tolerance)
      {
         g_liq.equalHighsDetected = true;
         g_liq.equalHighLevel = (high1 + high2 + h) / 3.0;
         
         // Check for sweep
         if(iHigh(_Symbol, PERIOD_M5, 0) > g_liq.equalHighLevel &&
            iClose(_Symbol, PERIOD_M5, 0) < g_liq.equalHighLevel)
            g_liq.sweepUpDetected = true;
         break;
      }
   }
   
   // Find equal lows
   double low1 = iLow(_Symbol, PERIOD_M5, 1);
   double low2 = iLow(_Symbol, PERIOD_M5, 2);
   for(int i = 3; i < 20; i++)
   {
      double l = iLow(_Symbol, PERIOD_M5, i);
      if(MathAbs(low1 - l) < tolerance || MathAbs(low2 - l) < tolerance)
      {
         g_liq.equalLowsDetected = true;
         g_liq.equalLowLevel = (low1 + low2 + l) / 3.0;
         
         // Check for sweep
         if(iLow(_Symbol, PERIOD_M5, 0) < g_liq.equalLowLevel &&
            iClose(_Symbol, PERIOD_M5, 0) > g_liq.equalLowLevel)
            g_liq.sweepDownDetected = true;
         break;
      }
   }
}

//=====================================================================
//  REGIME CLASSIFICATION
//=====================================================================
void UpdateRegime()
{
   double trendScore = g_bias.alignment;
   double volScore = (g_vol.isHigh ? 80.0 : 40.0);
   
   // Trending
   if(g_bias.alignment > 70 && !g_vol.isHigh)
   {
      g_regime.type = REGIME_TRENDING;
      g_regime.confidence = g_bias.alignment;
   }
   // Ranging
   else if(g_bias.alignment < 40 && !g_vol.isExpanding)
   {
      g_regime.type = REGIME_RANGING;
      g_regime.confidence = 100 - g_bias.alignment;
   }
   // Breakout
   else if(g_vol.isExpanding && g_bias.alignment > 60)
   {
      g_regime.type = REGIME_BREAKOUT;
      g_regime.confidence = MathMin(volScore + trendScore / 2, 100);
   }
   // Liquidity Sweep
   else if(g_liq.sweepUpDetected || g_liq.sweepDownDetected)
   {
      g_regime.type = REGIME_LIQUIDITY_SWEEP;
      g_regime.confidence = 85;
   }
   // Compression
   else if(!g_vol.isHigh && g_vol.atrRatio < 0.8)
   {
      g_regime.type = REGIME_COMPRESSION;
      g_regime.confidence = 70;
   }
   // Expansion
   else if(g_vol.isExpanding)
   {
      g_regime.type = REGIME_EXPANSION;
      g_regime.confidence = volScore;
   }
   // Unsafe
   else if(g_vol.atrRatio > 2.0 || SymbolInfoInteger(_Symbol, SYMBOL_SPREAD) > InpMaxSpread * 2)
   {
      g_regime.type = REGIME_UNSAFE;
      g_regime.confidence = 95;
   }
   else
   {
      g_regime.type = REGIME_RANGING;
      g_regime.confidence = 50;
   }
}

//=====================================================================
//  STRATEGY LOGIC
//=====================================================================
ENUM_STRATEGY GetActiveStrategy()
{
   switch(g_regime.type)
   {
      case REGIME_TRENDING:
         return STRAT_TREND_FOLLOW;
      case REGIME_RANGING:
         return STRAT_MEAN_REVERSION;
      case REGIME_BREAKOUT:
      case REGIME_EXPANSION:
         return STRAT_BREAKOUT;
      case REGIME_LIQUIDITY_SWEEP:
         return STRAT_LIQUIDITY_GRAB;
      default:
         return STRAT_NONE;
   }
}

bool CheckTrendFollowSignal(int &direction, double &sl, double &tp)
{
   if(g_bias.h1 == 0 || g_bias.m15 == 0) return false;
   if(g_bias.h1 != g_bias.m15) return false;
   
   double atr = g_vol.atrCurrent;
   if(atr <= 0) return false;
   
   direction = g_bias.h1;
   
   if(direction > 0)
   {
      double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      sl = NormalizePrice(ask - atr * 2.0);
      tp = NormalizePrice(ask + atr * 3.0);
   }
   else
   {
      double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      sl = NormalizePrice(bid + atr * 2.0);
      tp = NormalizePrice(bid - atr * 3.0);
   }
   
   return true;
}

bool CheckMeanReversionSignal(int &direction, double &sl, double &tp)
{
   double rsi[];
   if(CopyBuffer(g_m5_rsi, 0, 0, 1, rsi) < 1) return false;
   
   double atr = g_vol.atrCurrent;
   if(atr <= 0) return false;
   
   if(rsi[0] > 70)
   {
      direction = -1;
      double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      sl = NormalizePrice(bid + atr * 1.5);
      tp = NormalizePrice(bid - atr * 2.0);
      return true;
   }
   else if(rsi[0] < 30)
   {
      direction = 1;
      double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      sl = NormalizePrice(ask - atr * 1.5);
      tp = NormalizePrice(ask + atr * 2.0);
      return true;
   }
   
   return false;
}

bool CheckBreakoutSignal(int &direction, double &sl, double &tp)
{
   if(!g_vol.isExpanding) return false;
   if(g_bias.m5 == 0) return false;
   
   direction = g_bias.m5;
   double atr = g_vol.atrCurrent;
   
   if(direction > 0)
   {
      double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      double support = iLow(_Symbol, PERIOD_M5, iLowest(_Symbol, PERIOD_M5, MODE_LOW, 10, 1));
      sl = NormalizePrice(support - atr * 0.5);
      tp = NormalizePrice(ask + atr * 4.0);
   }
   else
   {
      double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      double resistance = iHigh(_Symbol, PERIOD_M5, iHighest(_Symbol, PERIOD_M5, MODE_HIGH, 10, 1));
      sl = NormalizePrice(resistance + atr * 0.5);
      tp = NormalizePrice(bid - atr * 4.0);
   }
   
   return true;
}

bool CheckLiquiditySignal(int &direction, double &sl, double &tp)
{
   double atr = g_vol.atrCurrent;
   
   if(g_liq.sweepUpDetected)
   {
      direction = -1;
      double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      sl = NormalizePrice(g_liq.equalHighLevel + atr * 0.5);
      tp = NormalizePrice(bid - atr * 2.5);
      return true;
   }
   else if(g_liq.sweepDownDetected)
   {
      direction = 1;
      double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      sl = NormalizePrice(g_liq.equalLowLevel - atr * 0.5);
      tp = NormalizePrice(ask + atr * 2.5);
      return true;
   }
   
   return false;
}

bool GenerateSignal(int &direction, double &sl, double &tp)
{
   ENUM_STRATEGY strategy = GetActiveStrategy();
   
   switch(strategy)
   {
      case STRAT_TREND_FOLLOW:
         return CheckTrendFollowSignal(direction, sl, tp);
      case STRAT_MEAN_REVERSION:
         return CheckMeanReversionSignal(direction, sl, tp);
      case STRAT_BREAKOUT:
         return CheckBreakoutSignal(direction, sl, tp);
      case STRAT_LIQUIDITY_GRAB:
         return CheckLiquiditySignal(direction, sl, tp);
      default:
         return false;
   }
}

//=====================================================================
//  RISK MANAGEMENT
//=====================================================================
void UpdateRisk()
{
   double equity = g_account.Equity();
   
   if(equity > g_risk.peakEquity)
      g_risk.peakEquity = equity;
   
   double drawdown = 0;
   if(g_risk.peakEquity > 0)
      drawdown = (g_risk.peakEquity - equity) / g_risk.peakEquity * 100.0;
   
   g_risk.maxDD = MathMax(g_risk.maxDD, drawdown);
   g_risk.limitHit = (g_risk.maxDD >= InpMaxDrawdown);
}

bool CheckRiskLimits()
{
   if(g_risk.limitHit)
   {
      Print("Max drawdown limit hit: ", g_risk.maxDD, "%");
      return false;
   }
   
   if(g_tradesToday >= InpMaxDailyTrades)
   {
      Print("Daily trade limit reached");
      return false;
   }
   
   if(CountPositions() >= InpMaxPositions)
   {
      Print("Max positions limit reached");
      return false;
   }
   
   int spread = (int)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   if(spread > InpMaxSpread)
   {
      Print("Spread too high: ", spread);
      return false;
   }
   
   if(TimeCurrent() - g_lastTrade < InpCooldownSec)
   {
      return false;
   }
   
   return true;
}

double CalculateLotSize(double slDistance)
{
   if(slDistance <= 0) return 0;
   
   double equity = g_account.Equity();
   double riskAmount = equity * InpRiskPercent / 100.0;
   
   double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   
   if(tickValue == 0 || tickSize == 0) return 0;
   
   double lots = riskAmount / (slDistance / tickSize * tickValue);
   
   double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double stepLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   
   lots = MathFloor(lots / stepLot) * stepLot;
   lots = MathMax(minLot, MathMin(maxLot, lots));
   
   return lots;
}

//=====================================================================
//  TRADE EXECUTION
//=====================================================================
bool ExecuteTrade(int direction, double sl, double tp)
{
   if(!CheckRiskLimits()) return false;
   
   double price = (direction > 0) ? 
      SymbolInfoDouble(_Symbol, SYMBOL_ASK) : 
      SymbolInfoDouble(_Symbol, SYMBOL_BID);
   
   double slDistance = MathAbs(price - sl);
   double lots = CalculateLotSize(slDistance);
   
   if(lots <= 0)
   {
      Print("Invalid lot size calculated");
      return false;
   }
   
   g_trade.SetExpertMagicNumber(InpMagic);
   g_trade.SetDeviationInPoints(30);
   g_trade.SetTypeFilling(GetFillingMode());
   
   bool result = false;
   
   if(direction > 0)
      result = g_trade.Buy(lots, _Symbol, price, sl, tp, "QPA2");
   else
      result = g_trade.Sell(lots, _Symbol, price, sl, tp, "QPA2");
   
   if(result)
   {
      g_tradesToday++;
      g_lastTrade = TimeCurrent();
      Print("Trade executed: ", (direction > 0 ? "BUY" : "SELL"), 
            " Lots:", lots, " SL:", sl, " TP:", tp);
   }
   else
   {
      Print("Trade failed: ", g_trade.ResultRetcode(), " - ", g_trade.ResultRetcodeDescription());
   }
   
   return result;
}

//=====================================================================
//  INFO PANEL
//=====================================================================
void CreateLabel(string name, int x, int y, string text, color clr, int size = 9)
{
   string objName = PREFIX + name;
   if(ObjectFind(0, objName) < 0)
      ObjectCreate(0, objName, OBJ_LABEL, 0, 0, 0);
   
   ObjectSetInteger(0, objName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, objName, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, objName, OBJPROP_YDISTANCE, y);
   ObjectSetString(0, objName, OBJPROP_TEXT, text);
   ObjectSetInteger(0, objName, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, objName, OBJPROP_FONTSIZE, size);
   ObjectSetString(0, objName, OBJPROP_FONT, "Arial Bold");
}

void UpdatePanel()
{
   if(!InpShowPanel) return;
   
   int x = InpPanelX;
   int y = InpPanelY;
   int line = 0;
   
   // Title
   CreateLabel("Title", x, y + line++ * 20, "=== QUANTUM PLUS AI v2.0 ===", clrCyan, 10);
   line++;
   
   // Account
   CreateLabel("Equity", x, y + line++ * 20, 
      "Equity: $" + DoubleToString(g_account.Equity(), 2), clrWhite);
   CreateLabel("DD", x, y + line++ * 20, 
      "Drawdown: " + DoubleToString(g_risk.maxDD, 2) + "%", 
      g_risk.maxDD > InpMaxDrawdown * 0.8 ? clrRed : clrLime);
   line++;
   
   // Regime
   string regimeStr = "";
   color regimeColor = clrWhite;
   
   switch(g_regime.type)
   {
      case REGIME_TRENDING: regimeStr = "TRENDING"; regimeColor = clrLime; break;
      case REGIME_RANGING: regimeStr = "RANGING"; regimeColor = clrYellow; break;
      case REGIME_BREAKOUT: regimeStr = "BREAKOUT"; regimeColor = clrOrange; break;
      case REGIME_LIQUIDITY_SWEEP: regimeStr = "LIQUIDITY SWEEP"; regimeColor = clrMagenta; break;
      case REGIME_UNSAFE: regimeStr = "UNSAFE"; regimeColor = clrRed; break;
      default: regimeStr = "NEUTRAL"; break;
   }
   
   CreateLabel("Regime", x, y + line++ * 20, 
      "Regime: " + regimeStr + " (" + DoubleToString(g_regime.confidence, 0) + "%)", 
      regimeColor);
   
   // Bias
   string biasStr = g_bias.h1 > 0 ? "BULLISH" : (g_bias.h1 < 0 ? "BEARISH" : "NEUTRAL");
   CreateLabel("Bias", x, y + line++ * 20, 
      "Bias: " + biasStr + " | Align: " + DoubleToString(g_bias.alignment, 0) + "%",
      g_bias.h1 > 0 ? clrLime : (g_bias.h1 < 0 ? clrRed : clrGray));
   
   // Volatility
   CreateLabel("Vol", x, y + line++ * 20,
      "ATR Ratio: " + DoubleToString(g_vol.atrRatio, 2) + " | " + 
      (g_vol.isExpanding ? "EXPANDING" : "STABLE"),
      g_vol.isHigh ? clrOrange : clrWhite);
   line++;
   
   // Liquidity
   if(g_liq.sweepUpDetected)
      CreateLabel("Liq", x, y + line++ * 20, "BSL SWEPT!", clrRed);
   else if(g_liq.sweepDownDetected)
      CreateLabel("Liq", x, y + line++ * 20, "SSL SWEPT!", clrLime);
   else if(g_liq.equalHighsDetected || g_liq.equalLowsDetected)
      CreateLabel("Liq", x, y + line++ * 20, "Liquidity Zones Detected", clrYellow);
   else
      CreateLabel("Liq", x, y + line++ * 20, "No Liquidity Signal", clrGray);
   
   line++;
   
   // Strategy
   ENUM_STRATEGY strat = GetActiveStrategy();
   string stratStr = "";
   switch(strat)
   {
      case STRAT_TREND_FOLLOW: stratStr = "TREND FOLLOW"; break;
      case STRAT_MEAN_REVERSION: stratStr = "MEAN REVERSION"; break;
      case STRAT_BREAKOUT: stratStr = "BREAKOUT"; break;
      case STRAT_LIQUIDITY_GRAB: stratStr = "LIQUIDITY GRAB"; break;
      default: stratStr = "NONE"; break;
   }
   CreateLabel("Strategy", x, y + line++ * 20, "Strategy: " + stratStr, clrCyan);
   
   // Status
   CreateLabel("Positions", x, y + line++ * 20,
      "Positions: " + IntegerToString(CountPositions()) + "/" + IntegerToString(InpMaxPositions),
      clrWhite);
   CreateLabel("Trades", x, y + line++ * 20,
      "Trades Today: " + IntegerToString(g_tradesToday) + "/" + IntegerToString(InpMaxDailyTrades),
      clrWhite);
   
   ChartRedraw();
}

void DeletePanel()
{
   ObjectsDeleteAll(0, PREFIX);
}

//=====================================================================
//  INITIALIZATION
//=====================================================================
int OnInit()
{
   // Initialize objects
   g_trade.SetExpertMagicNumber(InpMagic);
   g_dayStart = GetDayStart(TimeCurrent());
   g_risk.peakEquity = g_account.Equity();
   
   // Create indicators
   g_h1_ema_fast = iMA(_Symbol, PERIOD_H1, InpEMAFast, 0, MODE_EMA, PRICE_CLOSE);
   g_h1_ema_slow = iMA(_Symbol, PERIOD_H1, InpEMASlow, 0, MODE_EMA, PRICE_CLOSE);
   g_h1_atr = iATR(_Symbol, PERIOD_H1, InpATRPeriod);
   
   g_m15_ema_fast = iMA(_Symbol, PERIOD_M15, InpEMAFast, 0, MODE_EMA, PRICE_CLOSE);
   g_m15_ema_slow = iMA(_Symbol, PERIOD_M15, InpEMASlow, 0, MODE_EMA, PRICE_CLOSE);
   g_m15_rsi = iRSI(_Symbol, PERIOD_M15, InpRSIPeriod, PRICE_CLOSE);
   
   g_m5_ema_fast = iMA(_Symbol, PERIOD_M5, InpEMAFast, 0, MODE_EMA, PRICE_CLOSE);
   g_m5_ema_slow = iMA(_Symbol, PERIOD_M5, InpEMASlow, 0, MODE_EMA, PRICE_CLOSE);
   g_m5_atr = iATR(_Symbol, PERIOD_M5, InpATRPeriod);
   g_m5_rsi = iRSI(_Symbol, PERIOD_M5, InpRSIPeriod, PRICE_CLOSE);
   
   // Validate handles
   if(g_h1_ema_fast == INVALID_HANDLE || g_h1_ema_slow == INVALID_HANDLE || g_h1_atr == INVALID_HANDLE ||
      g_m15_ema_fast == INVALID_HANDLE || g_m15_ema_slow == INVALID_HANDLE || g_m15_rsi == INVALID_HANDLE ||
      g_m5_ema_fast == INVALID_HANDLE || g_m5_ema_slow == INVALID_HANDLE || g_m5_atr == INVALID_HANDLE || g_m5_rsi == INVALID_HANDLE)
   {
      Print("Failed to create indicator handles");
      return INIT_FAILED;
   }
   
   g_initialized = true;
   EventSetTimer(1);
   
   Print("=== QUANTUM PLUS AI v2.0 Initialized ===");
   return INIT_SUCCEEDED;
}

//=====================================================================
//  DEINITIALIZATION
//=====================================================================
void OnDeinit(const int reason)
{
   EventKillTimer();
   DeletePanel();
   
   IndicatorRelease(g_h1_ema_fast);
   IndicatorRelease(g_h1_ema_slow);
   IndicatorRelease(g_h1_atr);
   IndicatorRelease(g_m15_ema_fast);
   IndicatorRelease(g_m15_ema_slow);
   IndicatorRelease(g_m15_rsi);
   IndicatorRelease(g_m5_ema_fast);
   IndicatorRelease(g_m5_ema_slow);
   IndicatorRelease(g_m5_atr);
   IndicatorRelease(g_m5_rsi);
   
   Print("=== QUANTUM PLUS AI v2.0 Stopped ===");
}

//=====================================================================
//  TIMER
//=====================================================================
void OnTimer()
{
   UpdatePanel();
}

//=====================================================================
//  TICK HANDLER
//=====================================================================
void OnTick()
{
   if(!g_initialized) return;
   
   // Daily reset
   datetime currentDay = GetDayStart(TimeCurrent());
   if(currentDay != g_dayStart)
   {
      g_dayStart = currentDay;
      g_tradesToday = 0;
      Print("New trading day started");
   }
   
   // Update analysis
   UpdateBias();
   UpdateVolatility();
   UpdateLiquidity();
   UpdateRegime();
   UpdateRisk();
   
   // Check if we can trade
   if(CountPositions() > 0) return;  // Already in trade
   
   // Generate and execute signal
   int direction = 0;
   double sl = 0, tp = 0;
   
   if(GenerateSignal(direction, sl, tp))
   {
      ExecuteTrade(direction, sl, tp);
   }
}
//+------------------------------------------------------------------+