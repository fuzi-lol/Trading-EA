//+------------------------------------------------------------------+
//|                                  QuantumGoldScalper_v2.mq5       |
//|                    Institutional Gold Trading Intelligence        |
//|                                Complete Single-File Edition       |
//+------------------------------------------------------------------+
#property copyright   "Quantum Gold Scalper AI v2.0"
#property link        "https://institutional-trading.ai"
#property version     "2.00"
#property description "Complete Institutional-Grade Gold Trading System"
#property strict

#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>
#include <Trade\AccountInfo.mqh>
#include <Trade\SymbolInfo.mqh>

//+------------------------------------------------------------------+
//| ENUMERATIONS                                                      |
//+------------------------------------------------------------------+
enum ENUM_TRADE_DIRECTION
{
   TRADE_NONE = 0,
   TRADE_BUY  = 1,
   TRADE_SELL = -1
};

enum ENUM_MARKET_REGIME
{
   REGIME_UNKNOWN,
   REGIME_STRONG_BULL,
   REGIME_WEAK_BULL,
   REGIME_STRONG_BEAR,
   REGIME_WEAK_BEAR,
   REGIME_RANGING,
   REGIME_VOLATILE_EXPANSION,
   REGIME_VOLATILE_CONTRACTION,
   REGIME_BREAKOUT
};

enum ENUM_SESSION
{
   SESSION_UNKNOWN,
   SESSION_ASIAN,
   SESSION_LONDON,
   SESSION_NY,
   SESSION_OVERLAP
};

enum ENUM_STRATEGY_TYPE
{
   STRATEGY_NONE,
   STRATEGY_TREND_CONTINUATION,
   STRATEGY_LIQUIDITY_REVERSAL,
   STRATEGY_FVG_REENTRY,
   STRATEGY_ORDER_BLOCK,
   STRATEGY_BREAKOUT,
   STRATEGY_MEAN_REVERSION
};

//+------------------------------------------------------------------+
//| INPUT PARAMETERS                                                  |
//+------------------------------------------------------------------+
input group "═══════════════════════════════════════════════════"
input group "        QUANTUM GOLD SCALPER AI v2.0               "
input group "═══════════════════════════════════════════════════"

input group "╔══════ CORE SETTINGS ══════╗"
input ulong             InpMagicNumber          = 999888;
input string            InpTradeComment         = "QGS_AI";
input bool              InpAllowAutoTrading     = true;

input group "╔══════ RISK MANAGEMENT ══════╗"
input double            InpRiskPercent          = 1.0;        // Risk Per Trade (%)
input double            InpMaxDailyRisk         = 3.0;        // Max Daily Risk (%)
input double            InpMaxDrawdown          = 8.0;        // Max Drawdown (%)
input int               InpMaxPositions         = 1;          // Max Concurrent Positions
input int               InpMaxDailyTrades       = 10;         // Max Daily Trades

input group "╔══════ TRADE MANAGEMENT ══════╗"
input bool              InpUsePartialTP         = true;       // Use Partial TP
input double            InpPartialTPPercent     = 50.0;       // Partial TP %
input bool              InpUseTrailingStop      = true;       // Use Trailing Stop
input double            InpTrailingStartRR      = 1.5;        // Start Trailing at RR
input double            InpTrailingStepATR      = 0.5;        // Trail Step (ATR)

input group "╔══════ SMART MONEY ══════╗"
input int               InpSwingPeriod          = 10;         // Swing Detection Period
input double            InpFVGMinSize           = 5.0;        // Min FVG Size (points)
input int               InpOrderBlockLookback   = 50;         // Order Block Lookback

input group "╔══════ MARKET INTELLIGENCE ══════╗"
input int               InpATRPeriod            = 14;         // ATR Period
input double            InpMinConfidence        = 65.0;       // Min Trade Confidence (%)

input group "╔══════ SESSION MANAGEMENT ══════╗"
input bool              InpTradeAsian           = false;      // Trade Asian Session
input bool              InpTradeLondon          = true;       // Trade London Session
input bool              InpTradeNY              = true;       // Trade NY Session
input int               InpBrokerGMTOffset      = 2;          // Broker GMT Offset

input group "╔══════ FILTERS ══════╗"
input double            InpMaxSpreadPoints      = 30.0;       // Max Spread (points)
input double            InpMinATRValue          = 50.0;       // Min ATR Value (points)

input group "╔══════ VISUALIZATION ══════╗"
input bool              InpShowDashboard        = true;       // Show Dashboard

//+------------------------------------------------------------------+
//| DATA STRUCTURES                                                   |
//+------------------------------------------------------------------+
struct STradeSignal
{
   bool                    valid;
   ENUM_TRADE_DIRECTION    direction;
   ENUM_STRATEGY_TYPE      strategy;
   string                  strategyName;
   double                  entryPrice;
   double                  stopLoss;
   double                  takeProfit;
   double                  confidence;
   double                  riskReward;
   string                  reason;
   
   void Reset()
   {
      valid = false;
      direction = TRADE_NONE;
      strategy = STRATEGY_NONE;
      strategyName = "";
      entryPrice = 0;
      stopLoss = 0;
      takeProfit = 0;
      confidence = 0;
      riskReward = 0;
      reason = "";
   }
};

struct SMarketData
{
   ENUM_MARKET_REGIME   regime;
   double               regimeConfidence;
   ENUM_SESSION         session;
   double               atr;
   int                  trendBias;
   bool                 isHighVolatility;
   
   void Reset()
   {
      regime = REGIME_UNKNOWN;
      regimeConfidence = 0;
      session = SESSION_UNKNOWN;
      atr = 0;
      trendBias = 0;
      isHighVolatility = false;
   }
};

struct SRiskData
{
   double   dayStartEquity;
   double   peakEquity;
   int      tradesThisDay;
   double   dailyPnL;
   double   currentDrawdown;
   bool     emergencyStop;
   
   void Reset()
   {
      dayStartEquity = AccountInfoDouble(ACCOUNT_EQUITY);
      peakEquity = dayStartEquity;
      tradesThisDay = 0;
      dailyPnL = 0;
      currentDrawdown = 0;
      emergencyStop = false;
   }
};

//+------------------------------------------------------------------+
//| GLOBAL VARIABLES                                                  |
//+------------------------------------------------------------------+
CTrade            g_trade;
CPositionInfo     g_position;
CAccountInfo      g_account;

// Indicator handles
int               g_hATR_M5;
int               g_hEMA_Fast_M5;
int               g_hEMA_Slow_M5;
int               g_hEMA_Fast_H1;
int               g_hEMA_Slow_H1;
int               g_hRSI_M5;
int               g_hADX_M5;

// State variables
SMarketData       g_market;
SRiskData         g_risk;
STradeSignal      g_lastSignal;

datetime          g_currentDay;
datetime          g_lastBarTime;
string            g_status = "INITIALIZING";
color             g_statusColor = clrOrange;

// Dashboard
string            g_dashPrefix = "QGS_";

//+------------------------------------------------------------------+
//| COLOR SCHEME                                                      |
//+------------------------------------------------------------------+
#define CLR_BG_DARK        C'15,17,21'
#define CLR_BG_PANEL       C'24,28,36'
#define CLR_BORDER         C'45,52,68'
#define CLR_ACCENT         C'0,150,255'
#define CLR_SUCCESS        C'0,200,100'
#define CLR_WARNING        C'255,180,0'
#define CLR_DANGER         C'255,60,80'
#define CLR_TEXT_PRIMARY   C'220,225,235'
#define CLR_TEXT_SECONDARY C'140,150,170'
#define CLR_GOLD           C'255,215,0'

//+------------------------------------------------------------------+
//| HELPER FUNCTIONS                                                  |
//+------------------------------------------------------------------+
int iBarShift_(string symbol, ENUM_TIMEFRAMES timeframe, datetime time, bool exact=false)
{
   if(time < 0) return -1;
   datetime arr[];
   ArraySetAsSeries(arr, true);
   int copied = CopyTime(symbol, timeframe, 0, Bars(symbol, timeframe), arr);
   if(copied <= 0) return -1;
   
   for(int i = 0; i < copied; i++)
   {
      if(arr[i] <= time)
      {
         if(exact && arr[i] < time) return -1;
         return i;
      }
   }
   return -1;
}

double NormalizePrice(double price)
{
   return NormalizeDouble(price, (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS));
}

double NormalizeLot(double lots)
{
   double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   
   lots = MathFloor(lots / lotStep) * lotStep;
   lots = MathMax(minLot, MathMin(maxLot, lots));
   
   return NormalizeDouble(lots, 2);
}

datetime GetDayStart(datetime time)
{
   MqlDateTime dt;
   TimeToStruct(time, dt);
   dt.hour = 0;
   dt.min = 0;
   dt.sec = 0;
   return StructToTime(dt);
}

ENUM_ORDER_TYPE_FILLING GetFillMode()
{
   uint filling = (uint)SymbolInfoInteger(_Symbol, SYMBOL_FILLING_MODE);
   
   if((filling & SYMBOL_FILLING_FOK) != 0)
      return ORDER_FILLING_FOK;
   else if((filling & SYMBOL_FILLING_IOC) != 0)
      return ORDER_FILLING_IOC;
   else
      return ORDER_FILLING_RETURN;
}

bool IsNewBar()
{
   datetime currentBarTime = iTime(_Symbol, PERIOD_M5, 0);
   if(currentBarTime != g_lastBarTime)
   {
      g_lastBarTime = currentBarTime;
      return true;
   }
   return false;
}

//+------------------------------------------------------------------+
//| SESSION MANAGEMENT                                                |
//+------------------------------------------------------------------+
ENUM_SESSION DetermineSession()
{
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   
   int hour = dt.hour - InpBrokerGMTOffset;
   if(hour < 0) hour += 24;
   if(hour >= 24) hour -= 24;
   
   if(hour >= 22 || hour < 8) return SESSION_ASIAN;
   if(hour >= 8 && hour < 13) return SESSION_LONDON;
   if(hour >= 13 && hour < 16) return SESSION_OVERLAP;
   if(hour >= 13 && hour < 22) return SESSION_NY;
   
   return SESSION_UNKNOWN;
}

bool IsValidSession()
{
   ENUM_SESSION session = g_market.session;
   
   switch(session)
   {
      case SESSION_ASIAN:  return InpTradeAsian;
      case SESSION_LONDON: return InpTradeLondon;
      case SESSION_NY:     return InpTradeNY;
      case SESSION_OVERLAP: return InpTradeLondon && InpTradeNY;
      default:             return false;
   }
}

//+------------------------------------------------------------------+
//| MARKET INTELLIGENCE                                               |
//+------------------------------------------------------------------+
void UpdateMarketIntelligence()
{
   // Update session
   g_market.session = DetermineSession();
   
   // Get ATR
   double atr[];
   ArraySetAsSeries(atr, true);
   if(CopyBuffer(g_hATR_M5, 0, 0, 1, atr) > 0)
   {
      g_market.atr = atr[0];
   }
   
   // Determine volatility
   double atrPoints = g_market.atr / SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   g_market.isHighVolatility = atrPoints > InpMinATRValue * 1.5;
   
   // Calculate trend bias
   double emaFastM5[], emaSlowM5[], emaFastH1[], emaSlowH1[];
   ArraySetAsSeries(emaFastM5, true);
   ArraySetAsSeries(emaSlowM5, true);
   ArraySetAsSeries(emaFastH1, true);
   ArraySetAsSeries(emaSlowH1, true);
   
   if(CopyBuffer(g_hEMA_Fast_M5, 0, 0, 1, emaFastM5) > 0 &&
      CopyBuffer(g_hEMA_Slow_M5, 0, 0, 1, emaSlowM5) > 0 &&
      CopyBuffer(g_hEMA_Fast_H1, 0, 0, 1, emaFastH1) > 0 &&
      CopyBuffer(g_hEMA_Slow_H1, 0, 0, 1, emaSlowH1) > 0)
   {
      int m5Bias = emaFastM5[0] > emaSlowM5[0] ? 1 : -1;
      int h1Bias = emaFastH1[0] > emaSlowH1[0] ? 1 : -1;
      
      g_market.trendBias = (m5Bias == h1Bias) ? h1Bias : 0;
   }
   
   // Classify regime
   double adx[];
   ArraySetAsSeries(adx, true);
   
   if(CopyBuffer(g_hADX_M5, 0, 0, 1, adx) > 0)
   {
      double adxValue = adx[0];
      
      if(adxValue > 25 && g_market.trendBias == 1)
      {
         g_market.regime = REGIME_STRONG_BULL;
         g_market.regimeConfidence = MathMin(95.0, 60.0 + adxValue * 0.5);
      }
      else if(adxValue > 25 && g_market.trendBias == -1)
      {
         g_market.regime = REGIME_STRONG_BEAR;
         g_market.regimeConfidence = MathMin(95.0, 60.0 + adxValue * 0.5);
      }
      else if(adxValue < 20)
      {
         g_market.regime = REGIME_RANGING;
         g_market.regimeConfidence = 60.0;
      }
      else
      {
         g_market.regime = g_market.trendBias == 1 ? REGIME_WEAK_BULL : REGIME_WEAK_BEAR;
         g_market.regimeConfidence = 50.0 + adxValue;
      }
   }
}

//+------------------------------------------------------------------+
//| RISK MANAGEMENT                                                   |
//+------------------------------------------------------------------+
void UpdateRiskManagement()
{
   datetime currentDayStart = GetDayStart(TimeCurrent());
   
   // New day reset
   if(currentDayStart != g_currentDay)
   {
      g_currentDay = currentDayStart;
      g_risk.dayStartEquity = AccountInfoDouble(ACCOUNT_EQUITY);
      g_risk.tradesThisDay = 0;
      g_risk.dailyPnL = 0;
      
      Print("📅 New trading day | Equity: $", DoubleToString(g_risk.dayStartEquity, 2));
   }
   
   // Update daily P&L
   double currentEquity = AccountInfoDouble(ACCOUNT_EQUITY);
   g_risk.dailyPnL = currentEquity - g_risk.dayStartEquity;
   
   // Update peak and drawdown
   if(currentEquity > g_risk.peakEquity)
      g_risk.peakEquity = currentEquity;
   
   if(g_risk.peakEquity > 0)
      g_risk.currentDrawdown = (g_risk.peakEquity - currentEquity) / g_risk.peakEquity * 100.0;
   
   // Check limits
   double dailyLossPercent = 0;
   if(g_risk.dayStartEquity > 0)
      dailyLossPercent = -g_risk.dailyPnL / g_risk.dayStartEquity * 100.0;
   
   if(dailyLossPercent >= InpMaxDailyRisk)
   {
      g_risk.emergencyStop = true;
      g_status = "DAILY LIMIT HIT";
      g_statusColor = CLR_DANGER;
   }
   
   if(g_risk.currentDrawdown >= InpMaxDrawdown)
   {
      g_risk.emergencyStop = true;
      g_status = "MAX DRAWDOWN";
      g_statusColor = CLR_DANGER;
   }
}

bool CanTrade()
{
   if(!InpAllowAutoTrading) return false;
   if(!TerminalInfoInteger(TERMINAL_TRADE_ALLOWED)) return false;
   if(!MQLInfoInteger(MQL_TRADE_ALLOWED)) return false;
   if(g_risk.emergencyStop) return false;
   if(g_risk.tradesThisDay >= InpMaxDailyTrades) return false;
   if(!IsValidSession()) return false;
   
   long spread = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   if(spread > InpMaxSpreadPoints) return false;
   
   double atrPoints = g_market.atr / SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(atrPoints < InpMinATRValue) return false;
   
   return true;
}

double CalculateLotSize(STradeSignal &signal)
{
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   double riskAmount = equity * (InpRiskPercent / 100.0);
   
   // Adjust by confidence
   riskAmount *= (signal.confidence / 100.0);
   
   // Adjust by drawdown
   if(g_risk.currentDrawdown > InpMaxDrawdown * 0.5)
      riskAmount *= (1.0 - g_risk.currentDrawdown / InpMaxDrawdown);
   
   double slDistance = MathAbs(signal.entryPrice - signal.stopLoss);
   if(slDistance <= 0) return 0;
   
   double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   
   if(tickValue <= 0 || tickSize <= 0) return 0;
   
   double lotSize = riskAmount / (slDistance / tickSize * tickValue);
   return NormalizeLot(lotSize);
}

//+------------------------------------------------------------------+
//| STRATEGY ENGINE                                                   |
//+------------------------------------------------------------------+
STradeSignal GenerateSignal_TrendContinuation()
{
   STradeSignal signal;
   signal.Reset();
   signal.strategy = STRATEGY_TREND_CONTINUATION;
   signal.strategyName = "Trend Continuation";
   
   if(g_market.regime != REGIME_STRONG_BULL && g_market.regime != REGIME_STRONG_BEAR)
      return signal;
   
   if(g_market.trendBias == 0)
      return signal;
   
   double price = iClose(_Symbol, PERIOD_M5, 0);
   double ema21 = iMA(_Symbol, PERIOD_M5, 21, 0, MODE_EMA, PRICE_CLOSE);
   double tolerance = g_market.atr * 0.3;
   
   bool bullishPullback = (g_market.trendBias == 1) && (price > ema21) && (price < ema21 + tolerance);
   bool bearishPullback = (g_market.trendBias == -1) && (price < ema21) && (price > ema21 - tolerance);
   
   if(!bullishPullback && !bearishPullback)
      return signal;
   
   signal.direction = g_market.trendBias == 1 ? TRADE_BUY : TRADE_SELL;
   signal.entryPrice = signal.direction == TRADE_BUY ? 
                       SymbolInfoDouble(_Symbol, SYMBOL_ASK) : 
                       SymbolInfoDouble(_Symbol, SYMBOL_BID);
   
   double slDistance = g_market.atr * 1.5;
   signal.stopLoss = signal.direction == TRADE_BUY ? 
                     NormalizePrice(signal.entryPrice - slDistance) :
                     NormalizePrice(signal.entryPrice + slDistance);
   
   double tpDistance = slDistance * 2.5;
   signal.takeProfit = signal.direction == TRADE_BUY ? 
                       NormalizePrice(signal.entryPrice + tpDistance) :
                       NormalizePrice(signal.entryPrice - tpDistance);
   
   signal.confidence = g_market.regimeConfidence;
   signal.riskReward = 2.5;
   signal.reason = "Pullback in strong trend";
   signal.valid = true;
   
   return signal;
}

STradeSignal GenerateSignal_MeanReversion()
{
   STradeSignal signal;
   signal.Reset();
   signal.strategy = STRATEGY_MEAN_REVERSION;
   signal.strategyName = "Mean Reversion";
   
   if(g_market.regime != REGIME_RANGING)
      return signal;
   
   double rsi[];
   ArraySetAsSeries(rsi, true);
   
   if(CopyBuffer(g_hRSI_M5, 0, 0, 1, rsi) < 1)
      return signal;
   
   bool oversold = rsi[0] < 30;
   bool overbought = rsi[0] > 70;
   
   if(!oversold && !overbought)
      return signal;
   
   signal.direction = oversold ? TRADE_BUY : TRADE_SELL;
   signal.entryPrice = oversold ? 
                       SymbolInfoDouble(_Symbol, SYMBOL_ASK) : 
                       SymbolInfoDouble(_Symbol, SYMBOL_BID);
   
   double slDistance = g_market.atr * 1.2;
   signal.stopLoss = signal.direction == TRADE_BUY ? 
                     NormalizePrice(signal.entryPrice - slDistance) :
                     NormalizePrice(signal.entryPrice + slDistance);
   
   double tpDistance = slDistance * 2.0;
   signal.takeProfit = signal.direction == TRADE_BUY ? 
                       NormalizePrice(signal.entryPrice + tpDistance) :
                       NormalizePrice(signal.entryPrice - tpDistance);
   
   signal.confidence = MathMin(85.0, MathAbs(rsi[0] - 50.0) * 1.5);
   signal.riskReward = 2.0;
   signal.reason = oversold ? "RSI Oversold" : "RSI Overbought";
   signal.valid = true;
   
   return signal;
}

STradeSignal GetTradeSignal()
{
   STradeSignal signal;
   signal.Reset();
   
   // Select strategy based on regime
   if(g_market.regime == REGIME_STRONG_BULL || g_market.regime == REGIME_STRONG_BEAR)
   {
      signal = GenerateSignal_TrendContinuation();
   }
   else if(g_market.regime == REGIME_RANGING)
   {
      signal = GenerateSignal_MeanReversion();
   }
   
   // Validate signal
   if(signal.valid)
   {
      if(signal.confidence < InpMinConfidence)
         signal.valid = false;
      
      if(signal.riskReward < 1.5)
         signal.valid = false;
   }
   
   return signal;
}

//+------------------------------------------------------------------+
//| TRADE EXECUTION                                                   |
//+------------------------------------------------------------------+
bool ExecuteTrade(STradeSignal &signal)
{
   double lotSize = CalculateLotSize(signal);
   
   if(lotSize < SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN))
   {
      Print("❌ Lot size too small: ", lotSize);
      return false;
   }
   
   // Validate stop level
   int stopsLevel = (int)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   double minDistance = stopsLevel * point;
   
   double entryPrice = signal.entryPrice;
   double sl = signal.stopLoss;
   double tp = signal.takeProfit;
   
   if(signal.direction == TRADE_BUY)
   {
      entryPrice = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(sl > 0 && (entryPrice - sl) < minDistance)
         sl = NormalizePrice(entryPrice - minDistance);
      if(tp > 0 && (tp - entryPrice) < minDistance)
         tp = NormalizePrice(entryPrice + minDistance);
   }
   else
   {
      entryPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      if(sl > 0 && (sl - entryPrice) < minDistance)
         sl = NormalizePrice(entryPrice + minDistance);
      if(tp > 0 && (entryPrice - tp) < minDistance)
         tp = NormalizePrice(entryPrice - minDistance);
   }
   
   string comment = InpTradeComment + "|" + DoubleToString(signal.confidence, 1);
   
   bool result = false;
   
   if(signal.direction == TRADE_BUY)
      result = g_trade.Buy(lotSize, _Symbol, entryPrice, sl, tp, comment);
   else
      result = g_trade.Sell(lotSize, _Symbol, entryPrice, sl, tp, comment);
   
   if(result)
   {
      g_risk.tradesThisDay++;
      g_status = "TRADE EXECUTED";
      g_statusColor = CLR_SUCCESS;
      
      Print("✅ ", signal.direction == TRADE_BUY ? "BUY" : "SELL",
            " | Lots: ", lotSize,
            " | Entry: ", entryPrice,
            " | SL: ", sl,
            " | TP: ", tp,
            " | Confidence: ", DoubleToString(signal.confidence, 1), "%");
      
      return true;
   }
   else
   {
      Print("❌ Order failed: ", g_trade.ResultRetcode());
      return false;
   }
}

//+------------------------------------------------------------------+
//| POSITION MANAGEMENT                                               |
//+------------------------------------------------------------------+
void ManageOpenPositions()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(!g_position.SelectByIndex(i)) continue;
      if(g_position.Magic() != InpMagicNumber) continue;
      if(g_position.Symbol() != _Symbol) continue;
      
      ulong ticket = g_position.Ticket();
      double openPrice = g_position.PriceOpen();
      double sl = g_position.StopLoss();
      double tp = g_position.TakeProfit();
      double currentPrice = g_position.Type() == POSITION_TYPE_BUY ? 
                            SymbolInfoDouble(_Symbol, SYMBOL_BID) : 
                            SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      
      // Breakeven
      double profitDistance = MathAbs(currentPrice - openPrice);
      double targetDistance = MathAbs(tp - openPrice);
      
      if(profitDistance >= targetDistance * 0.4)
      {
         bool atBreakeven = false;
         if(g_position.Type() == POSITION_TYPE_BUY)
            atBreakeven = sl >= openPrice;
         else
            atBreakeven = sl <= openPrice && sl > 0;
         
         if(!atBreakeven)
         {
            double newSL = g_position.Type() == POSITION_TYPE_BUY ? 
                          NormalizePrice(openPrice + SymbolInfoDouble(_Symbol, SYMBOL_POINT) * 10) :
                          NormalizePrice(openPrice - SymbolInfoDouble(_Symbol, SYMBOL_POINT) * 10);
            
            if(g_trade.PositionModify(ticket, newSL, tp))
            {
               Print("✅ Breakeven set: #", ticket);
            }
         }
      }
      
      // Trailing stop
      if(InpUseTrailingStop && profitDistance >= targetDistance * InpTrailingStartRR)
      {
         double trailDistance = g_market.atr * InpTrailingStepATR;
         double newSL;
         bool shouldModify = false;
         
         if(g_position.Type() == POSITION_TYPE_BUY)
         {
            newSL = NormalizePrice(currentPrice - trailDistance);
            shouldModify = newSL > sl + SymbolInfoDouble(_Symbol, SYMBOL_POINT) * 10;
         }
         else
         {
            newSL = NormalizePrice(currentPrice + trailDistance);
            shouldModify = newSL < sl - SymbolInfoDouble(_Symbol, SYMBOL_POINT) * 10;
         }
         
         if(shouldModify)
         {
            if(g_trade.PositionModify(ticket, newSL, tp))
            {
               Print("✅ Trailing stop: #", ticket, " | New SL: ", newSL);
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//| DASHBOARD                                                         |
//+------------------------------------------------------------------+
void CreateLabel(string name, int x, int y, string text, color clr, int size)
{
   string objName = g_dashPrefix + name;
   ObjectCreate(0, objName, OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, objName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, objName, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, objName, OBJPROP_YDISTANCE, y);
   ObjectSetString(0, objName, OBJPROP_TEXT, text);
   ObjectSetString(0, objName, OBJPROP_FONT, "Segoe UI");
   ObjectSetInteger(0, objName, OBJPROP_FONTSIZE, size);
   ObjectSetInteger(0, objName, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, objName, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, objName, OBJPROP_HIDDEN, true);
}

void CreateRect(string name, int x, int y, int w, int h, color bg, color border = clrNONE)
{
   string objName = g_dashPrefix + name;
   ObjectCreate(0, objName, OBJ_RECTANGLE_LABEL, 0, 0, 0);
   ObjectSetInteger(0, objName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, objName, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, objName, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, objName, OBJPROP_XSIZE, w);
   ObjectSetInteger(0, objName, OBJPROP_YSIZE, h);
   ObjectSetInteger(0, objName, OBJPROP_BGCOLOR, bg);
   if(border != clrNONE)
   {
      ObjectSetInteger(0, objName, OBJPROP_BORDER_TYPE, BORDER_FLAT);
      ObjectSetInteger(0, objName, OBJPROP_COLOR, border);
   }
   ObjectSetInteger(0, objName, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, objName, OBJPROP_HIDDEN, true);
}

void UpdateLabel(string name, string text, color clr)
{
   string objName = g_dashPrefix + name;
   if(ObjectFind(0, objName) >= 0)
   {
      ObjectSetString(0, objName, OBJPROP_TEXT, text);
      ObjectSetInteger(0, objName, OBJPROP_COLOR, clr);
   }
}

void InitializeDashboard()
{
   if(!InpShowDashboard) return;
   if(MQLInfoInteger(MQL_TESTER)) return;
   
   int x = 15, y = 25;
   
   // Background
   CreateRect("bg", x, y, 400, 400, CLR_BG_DARK, CLR_BORDER);
   
   // Header
   CreateLabel("title", x + 10, y + 10, "QUANTUM GOLD SCALPER AI v2.0", CLR_GOLD, 10);
   CreateLabel("subtitle", x + 10, y + 30, "Institutional Trading Intelligence", CLR_TEXT_SECONDARY, 7);
   
   // Status
   CreateLabel("status_lbl", x + 10, y + 60, "STATUS:", CLR_TEXT_SECONDARY, 7);
   CreateLabel("status_val", x + 80, y + 60, g_status, g_statusColor, 9);
   
   // Market
   CreateLabel("price_lbl", x + 10, y + 90, "Price:", CLR_TEXT_SECONDARY, 7);
   CreateLabel("price_val", x + 80, y + 90, "0.00", CLR_TEXT_PRIMARY, 8);
   
   CreateLabel("spread_lbl", x + 10, y + 110, "Spread:", CLR_TEXT_SECONDARY, 7);
   CreateLabel("spread_val", x + 80, y + 110, "0", CLR_TEXT_PRIMARY, 8);
   
   CreateLabel("regime_lbl", x + 10, y + 130, "Regime:", CLR_TEXT_SECONDARY, 7);
   CreateLabel("regime_val", x + 80, y + 130, "UNKNOWN", CLR_TEXT_PRIMARY, 8);
   
   // Risk
   CreateLabel("daily_lbl", x + 10, y + 160, "Daily P&L:", CLR_TEXT_SECONDARY, 7);
   CreateLabel("daily_val", x + 80, y + 160, "$0.00", CLR_TEXT_PRIMARY, 8);
   
   CreateLabel("dd_lbl", x + 10, y + 180, "Drawdown:", CLR_TEXT_SECONDARY, 7);
   CreateLabel("dd_val", x + 80, y + 180, "0%", CLR_TEXT_PRIMARY, 8);
   
   CreateLabel("trades_lbl", x + 10, y + 200, "Trades Today:", CLR_TEXT_SECONDARY, 7);
   CreateLabel("trades_val", x + 80, y + 200, "0", CLR_TEXT_PRIMARY, 8);
   
   // Positions
   CreateLabel("pos_lbl", x + 10, y + 230, "Open Positions:", CLR_TEXT_SECONDARY, 7);
   CreateLabel("pos_val", x + 130, y + 230, "0", CLR_TEXT_PRIMARY, 8);
   
   CreateLabel("pos_detail", x + 10, y + 250, "", CLR_TEXT_PRIMARY, 7);
   
   ChartRedraw();
}

void UpdateDashboard()
{
   if(!InpShowDashboard) return;
   if(MQLInfoInteger(MQL_TESTER)) return;
   
   // Status
   UpdateLabel("status_val", g_status, g_statusColor);
   
   // Market
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   UpdateLabel("price_val", DoubleToString(bid, 2), CLR_TEXT_PRIMARY);
   
   long spread = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   color spreadColor = spread <= InpMaxSpreadPoints ? CLR_SUCCESS : CLR_DANGER;
   UpdateLabel("spread_val", IntegerToString(spread), spreadColor);
   
   string regimeName = "";
   switch(g_market.regime)
   {
      case REGIME_STRONG_BULL: regimeName = "STRONG BULL"; break;
      case REGIME_STRONG_BEAR: regimeName = "STRONG BEAR"; break;
      case REGIME_RANGING: regimeName = "RANGING"; break;
      default: regimeName = "ANALYZING";
   }
   UpdateLabel("regime_val", regimeName, CLR_ACCENT);
   
   // Risk
   color pnlColor = g_risk.dailyPnL >= 0 ? CLR_SUCCESS : CLR_DANGER;
   UpdateLabel("daily_val", "$" + DoubleToString(g_risk.dailyPnL, 2), pnlColor);
   UpdateLabel("dd_val", DoubleToString(g_risk.currentDrawdown, 2) + "%", 
               g_risk.currentDrawdown > InpMaxDrawdown * 0.5 ? CLR_WARNING : CLR_TEXT_PRIMARY);
   UpdateLabel("trades_val", IntegerToString(g_risk.tradesThisDay), CLR_TEXT_PRIMARY);
   
   // Positions
   int openPos = 0;
   for(int i = 0; i < PositionsTotal(); i++)
   {
      if(g_position.SelectByIndex(i) && g_position.Magic() == InpMagicNumber && g_position.Symbol() == _Symbol)
         openPos++;
   }
   
   UpdateLabel("pos_val", IntegerToString(openPos), openPos > 0 ? CLR_SUCCESS : CLR_TEXT_PRIMARY);
   
   if(openPos > 0 && g_position.SelectByIndex(0) && g_position.Magic() == InpMagicNumber)
   {
      string detail = StringFormat("%s %.2f lots | P&L: $%.2f",
                                   g_position.Type() == POSITION_TYPE_BUY ? "BUY" : "SELL",
                                   g_position.Volume(),
                                   g_position.Profit());
      UpdateLabel("pos_detail", detail, g_position.Profit() >= 0 ? CLR_SUCCESS : CLR_DANGER);
   }
   else
   {
      UpdateLabel("pos_detail", "", CLR_TEXT_PRIMARY);
   }
}

//+------------------------------------------------------------------+
//| Expert initialization function                                    |
//+------------------------------------------------------------------+
int OnInit()
{
   // Validate symbol
   if(_Symbol != "XAUUSD" && StringFind(_Symbol, "GOLD") < 0 && StringFind(_Symbol, "XAU") < 0)
   {
      Alert("⚠️ This EA is optimized for GOLD (XAUUSD). Current: ", _Symbol);
   }
   
   // Setup trade
   g_trade.SetExpertMagicNumber(InpMagicNumber);
   g_trade.SetDeviationInPoints(30);
   g_trade.SetTypeFilling(GetFillMode());
   g_trade.SetAsyncMode(false);
   
   // Create indicators
   g_hATR_M5 = iATR(_Symbol, PERIOD_M5, InpATRPeriod);
   g_hEMA_Fast_M5 = iMA(_Symbol, PERIOD_M5, 8, 0, MODE_EMA, PRICE_CLOSE);
   g_hEMA_Slow_M5 = iMA(_Symbol, PERIOD_M5, 21, 0, MODE_EMA, PRICE_CLOSE);
   g_hEMA_Fast_H1 = iMA(_Symbol, PERIOD_H1, 8, 0, MODE_EMA, PRICE_CLOSE);
   g_hEMA_Slow_H1 = iMA(_Symbol, PERIOD_H1, 21, 0, MODE_EMA, PRICE_CLOSE);
   g_hRSI_M5 = iRSI(_Symbol, PERIOD_M5, 14, PRICE_CLOSE);
   g_hADX_M5 = iADX(_Symbol, PERIOD_M5, 14);
   
   // Validate handles
   if(g_hATR_M5 == INVALID_HANDLE || g_hEMA_Fast_M5 == INVALID_HANDLE || 
      g_hEMA_Slow_M5 == INVALID_HANDLE || g_hEMA_Fast_H1 == INVALID_HANDLE ||
      g_hEMA_Slow_H1 == INVALID_HANDLE || g_hRSI_M5 == INVALID_HANDLE || 
      g_hADX_M5 == INVALID_HANDLE)
   {
      Print("❌ Failed to create indicators");
      return INIT_FAILED;
   }
   
   // Initialize state
   g_market.Reset();
   g_risk.Reset();
   g_currentDay = GetDayStart(TimeCurrent());
   g_lastBarTime = 0;
   
   // Create dashboard
   InitializeDashboard();
   
   // Set timer
   EventSetTimer(1);
   
   Print("═══════════════════════════════════════════════════════════");
   Print("     QUANTUM GOLD SCALPER AI v2.0 - INITIALIZED");
   Print("═══════════════════════════════════════════════════════════");
   Print("Symbol: ", _Symbol);
   Print("Magic: ", InpMagicNumber);
   Print("Risk: ", InpRiskPercent, "%");
   Print("Max DD: ", InpMaxDrawdown, "%");
   Print("═══════════════════════════════════════════════════════════");
   
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                  |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   EventKillTimer();
   
   // Release indicators
   if(g_hATR_M5 != INVALID_HANDLE) IndicatorRelease(g_hATR_M5);
   if(g_hEMA_Fast_M5 != INVALID_HANDLE) IndicatorRelease(g_hEMA_Fast_M5);
   if(g_hEMA_Slow_M5 != INVALID_HANDLE) IndicatorRelease(g_hEMA_Slow_M5);
   if(g_hEMA_Fast_H1 != INVALID_HANDLE) IndicatorRelease(g_hEMA_Fast_H1);
   if(g_hEMA_Slow_H1 != INVALID_HANDLE) IndicatorRelease(g_hEMA_Slow_H1);
   if(g_hRSI_M5 != INVALID_HANDLE) IndicatorRelease(g_hRSI_M5);
   if(g_hADX_M5 != INVALID_HANDLE) IndicatorRelease(g_hADX_M5);
   
   // Clean dashboard
   ObjectsDeleteAll(0, g_dashPrefix);
   ChartRedraw();
   
   Print("═══════════════════════════════════════════════════════════");
   Print("     SESSION SUMMARY");
   Print("═══════════════════════════════════════════════════════════");
   Print("Daily Trades: ", g_risk.tradesThisDay);
   Print("Daily P&L: $", DoubleToString(g_risk.dailyPnL, 2));
   Print("Drawdown: ", DoubleToString(g_risk.currentDrawdown, 2), "%");
   Print("═══════════════════════════════════════════════════════════");
}

//+------------------------------------------------------------------+
//| Expert tick function                                              |
//+------------------------------------------------------------------+
void OnTick()
{
   // Update risk management
   UpdateRiskManagement();
   
   // Check if we can trade
   if(!CanTrade())
   {
      g_status = "BLOCKED";
      g_statusColor = CLR_WARNING;
      return;
   }
   
   // Manage existing positions
   ManageOpenPositions();
   
   // Check for new signals on new bar
   if(IsNewBar())
   {
      // Update market intelligence
      UpdateMarketIntelligence();
      
      // Don't open new position if we already have one
      int openPositions = 0;
      for(int i = 0; i < PositionsTotal(); i++)
      {
         if(g_position.SelectByIndex(i) && g_position.Magic() == InpMagicNumber && g_position.Symbol() == _Symbol)
            openPositions++;
      }
      
      if(openPositions >= InpMaxPositions)
      {
         g_status = "IN TRADE";
         g_statusColor = CLR_SUCCESS;
         return;
      }
      
      // Get signal
      STradeSignal signal = GetTradeSignal();
      
      if(signal.valid)
      {
         g_lastSignal = signal;
         ExecuteTrade(signal);
      }
      else
      {
         g_status = "ANALYZING";
         g_statusColor = CLR_ACCENT;
      }
   }
}

//+------------------------------------------------------------------+
//| Timer function                                                    |
//+------------------------------------------------------------------+
void OnTimer()
{
   UpdateDashboard();
}
//+------------------------------------------------------------------+