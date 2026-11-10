//+------------------------------------------------------------------+
//|  THEE EliteScalper — MicroGrid Edition                           |
//|  Symbol   : XAUUSD                                               |
//|  Timeframe: M1 primary / M5 trend filter                        |
//|  Min Acct : $10 micro                                            |
//+------------------------------------------------------------------+
#property copyright "THEE EliteScalper"
#property version   "1.00"
#property strict

#include <Trade\Trade.mqh>
#include <Trade\OrderInfo.mqh>
#include <Trade\PositionInfo.mqh>

//+------------------------------------------------------------------+
//| INPUT PARAMETERS                                                 |
//+------------------------------------------------------------------+

// === CORE ===
input int    MagicNumber           = 20250609;
input double BaseLotSize           = 0.01;
input double BaseTPUSD             = 0.15;
input bool   AllowLotScaling       = true;
input bool   AllowTPScaling        = true;
input bool   AllowTradeCountScale  = true;

// === RISK ===
input double MaxDailyLossPct       = 20.0;
input double MaxAccountDrawdownPct = 40.0;
input double MaxSpreadPips         = 3.0;
input double MinATRPips            = 0.5;
input double MaxATRPips            = 8.0;

// === SESSIONS ===
input bool   TradeLondon           = true;
input bool   TradeNewYork          = true;

// === SIGNAL ===
input int    EMA_Period            = 21;
input int    RSI_Period            = 7;
input int    ATR_Period            = 14;

// === SYSTEM ===
input bool   ResetCumulativeProfit = false;
input bool   ShowDashboard         = true;

//+------------------------------------------------------------------+
//| GLOBAL VARIABLES                                                 |
//+------------------------------------------------------------------+

CTrade  trade;

// Global variable keys
string GV_DAILY_PROFIT;
string GV_CUMULATIVE   = "ELITE_CUMULATIVE_PROFIT";
string GV_EA_DISABLED  = "ELITE_EA_DISABLED";

// State flags
bool   TradingHaltedToday = false;
int    LastDay            = -1;

// Dashboard object names
string PANEL_BG      = "ES_PanelBG";
string LBL_HEADER    = "ES_Header";
string LBL_MODE      = "ES_Mode";
string LBL_TRADES    = "ES_Trades";
string LBL_LOT       = "ES_Lot";
string LBL_TP        = "ES_TP";
string LBL_DAILY     = "ES_Daily";
string LBL_CUMUL     = "ES_Cumul";
string LBL_SPREAD    = "ES_Spread";
string LBL_SESSION   = "ES_Session";
string LBL_STATUS    = "ES_Status";

//+------------------------------------------------------------------+
//| HELPER: Pip value for XAUUSD                                     |
//+------------------------------------------------------------------+
double GetPipValue()
{
   double tickVal  = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   double point    = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   // 1 pip for XAUUSD = 0.10 (2 decimal symbol, point=0.01, pip=10*point)
   double pipSize  = point * 10.0;
   if(tickSize == 0) return 0;
   return (pipSize / tickSize) * tickVal;
}

//+------------------------------------------------------------------+
//| HELPER: Calculate TP in price distance for given USD target      |
//+------------------------------------------------------------------+
double CalcTPPrice(double tpUSD, double lotSize)
{
   double pipVal = GetPipValue(); // value of 1 pip per 1 lot
   if(pipVal == 0 || lotSize == 0) return 0;
   double pips = tpUSD / (lotSize * pipVal);
   return pips * SymbolInfoDouble(_Symbol, SYMBOL_POINT) * 10.0;
}

//+------------------------------------------------------------------+
//| HELPER: Calculate SL in price distance                           |
//+------------------------------------------------------------------+
double CalcSLPrice()
{
   int    atrHandle = iATR(_Symbol, PERIOD_M1, ATR_Period);
   double atrBuf[1];
   if(CopyBuffer(atrHandle, 0, 0, 1, atrBuf) <= 0) return 0;
   IndicatorRelease(atrHandle);
   
   double atrPips  = atrBuf[0] / (SymbolInfoDouble(_Symbol, SYMBOL_POINT) * 10.0);
   double slPips   = atrPips * 1.5;
   // Clamp between 5 and 15 pips
   if(slPips < 5.0)  slPips = 5.0;
   if(slPips > 15.0) slPips = 15.0;
   return slPips * SymbolInfoDouble(_Symbol, SYMBOL_POINT) * 10.0;
}

//+------------------------------------------------------------------+
//| HELPER: Get daily profit from global variable                    |
//+------------------------------------------------------------------+
double GetDailyProfit()
{
   if(!GlobalVariableCheck(GV_DAILY_PROFIT)) return 0.0;
   return GlobalVariableGet(GV_DAILY_PROFIT);
}

//+------------------------------------------------------------------+
//| HELPER: Get cumulative profit from global variable               |
//+------------------------------------------------------------------+
double GetCumulativeProfit()
{
   if(!GlobalVariableCheck(GV_CUMULATIVE)) return 0.0;
   return GlobalVariableGet(GV_CUMULATIVE);
}

//+------------------------------------------------------------------+
//| HELPER: Add to daily and cumulative profit                       |
//+------------------------------------------------------------------+
void AddProfit(double amount)
{
   double daily = GetDailyProfit() + amount;
   GlobalVariableSet(GV_DAILY_PROFIT, daily);
   
   double cumul = GetCumulativeProfit() + amount;
   GlobalVariableSet(GV_CUMULATIVE, cumul);
}

//+------------------------------------------------------------------+
//| TIER FUNCTIONS                                                   |
//+------------------------------------------------------------------+

// Returns tier 1-4 based on daily profit
int GetCurrentTier()
{
   double dp = GetDailyProfit();
   if(dp <= 2.00)  return 1;
   if(dp <= 10.00) return 2;
   if(dp <= 30.00) return 3;
   return 4;
}

string GetTierName(int tier)
{
   switch(tier)
   {
      case 1: return "SEED MODE";
      case 2: return "GROWTH MODE";
      case 3: return "SCALE MODE";
      case 4: return "ELITE MODE";
   }
   return "UNKNOWN";
}

// Max simultaneous trades for tier
int GetMaxTrades(int tier)
{
   if(!AllowTradeCountScale) return 2;
   switch(tier)
   {
      case 1: return 2;
      case 2: return 4;
      case 3: return 6;
      case 4: return 10;
   }
   return 2;
}

// TP in USD for tier
double GetTierTP(int tier)
{
   if(!AllowTPScaling) return BaseTPUSD;
   switch(tier)
   {
      case 1: return 0.15;
      case 2: return 0.22;
      case 3: return 0.35;
      case 4: return 0.50;
   }
   return BaseTPUSD;
}

// Lot size based on cumulative profit
double GetCurrentLot()
{
   if(!AllowLotScaling) return BaseLotSize;
   double cumul = GetCumulativeProfit();
   if(cumul < 100.0)   return 0.01;
   if(cumul < 300.0)   return 0.02;
   if(cumul < 600.0)   return 0.03;
   if(cumul < 1000.0)  return 0.05;
   return 0.10;
}

//+------------------------------------------------------------------+
//| COUNT EA's OPEN POSITIONS                                        |
//+------------------------------------------------------------------+
int CountOpenPositions()
{
   int count = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      if(PositionGetString(POSITION_SYMBOL)  != _Symbol)    continue;
      if(PositionGetInteger(POSITION_MAGIC)  != MagicNumber) continue;
      count++;
   }
   return count;
}

//+------------------------------------------------------------------+
//| SIGNAL FUNCTIONS                                                 |
//+------------------------------------------------------------------+

// Returns 1 for BUY, -1 for SELL, 0 for no signal
int GetSignal()
{
   // --- Layer 3: Volatility Gate (M1 ATR) ---
   int    atrHandle = iATR(_Symbol, PERIOD_M1, ATR_Period);
   double atrBuf[1];
   if(CopyBuffer(atrHandle, 0, 0, 1, atrBuf) <= 0) { IndicatorRelease(atrHandle); return 0; }
   IndicatorRelease(atrHandle);
   double atrPips = atrBuf[0] / (SymbolInfoDouble(_Symbol, SYMBOL_POINT) * 10.0);
   if(atrPips < MinATRPips || atrPips > MaxATRPips) return 0;

   // --- Layer 4: Spread Filter ---
   double spread = (SymbolInfoDouble(_Symbol, SYMBOL_ASK) - SymbolInfoDouble(_Symbol, SYMBOL_BID))
                   / (SymbolInfoDouble(_Symbol, SYMBOL_POINT) * 10.0);
   if(spread > MaxSpreadPips) return 0;

   // --- Layer 5: Session Filter ---
   if(!IsInTradingSession()) return 0;

   // --- Layer 1: Trend Filter (M5 EMA21) ---
   int    emaHandle = iMA(_Symbol, PERIOD_M5, EMA_Period, 0, MODE_EMA, PRICE_CLOSE);
   double emaBuf[1];
   if(CopyBuffer(emaHandle, 0, 0, 1, emaBuf) <= 0) { IndicatorRelease(emaHandle); return 0; }
   IndicatorRelease(emaHandle);
   double closeM5 = iClose(_Symbol, PERIOD_M5, 0);
   bool   trendBull = (closeM5 > emaBuf[0]);
   bool   trendBear = (closeM5 < emaBuf[0]);

   // --- Layer 2: RSI Momentum (M1 RSI7) ---
   int    rsiHandle = iRSI(_Symbol, PERIOD_M1, RSI_Period, PRICE_CLOSE);
   double rsiBuf[3];
   if(CopyBuffer(rsiHandle, 0, 0, 3, rsiBuf) <= 0) { IndicatorRelease(rsiHandle); return 0; }
   IndicatorRelease(rsiHandle);
   // rsiBuf[0] = current, rsiBuf[1] = 1 bar ago, rsiBuf[2] = 2 bars ago
   bool rsiBullCross = (rsiBuf[1] < 35.0 && rsiBuf[0] >= 35.0); // crossed above 35
   bool rsiBearCross = (rsiBuf[1] > 65.0 && rsiBuf[0] <= 65.0); // crossed below 65

   if(trendBull && rsiBullCross) return  1;
   if(trendBear && rsiBearCross) return -1;
   return 0;
}

// Returns true if current GMT time is in London or NY session
bool IsInTradingSession()
{
   datetime utcTime = TimeGMT();
   MqlDateTime t;
   TimeToStruct(utcTime, t);
   int hhmm = t.hour * 100 + t.min;

   if(TradeLondon   && hhmm >= 800  && hhmm < 1200) return true;
   if(TradeNewYork  && hhmm >= 1300 && hhmm < 1700) return true;
   return false;
}

string GetSessionName()
{
   datetime utcTime = TimeGMT();
   MqlDateTime t;
   TimeToStruct(utcTime, t);
   int hhmm = t.hour * 100 + t.min;
   if(TradeLondon  && hhmm >= 800  && hhmm < 1200) return "LONDON";
   if(TradeNewYork && hhmm >= 1300 && hhmm < 1700) return "NEW YORK";
   return "CLOSED";
}

//+------------------------------------------------------------------+
//| OPEN A NEW TRADE                                                 |
//+------------------------------------------------------------------+
void OpenTrade(int direction)
{
   double lot    = GetCurrentLot();
   int    tier   = GetCurrentTier();
   double tpUSD  = GetTierTP(tier);
   double tpDist = CalcTPPrice(tpUSD, lot);
   double slDist = CalcSLPrice();
   
   if(tpDist <= 0 || slDist <= 0) return;

   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);

   trade.SetExpertMagicNumber(MagicNumber);
   trade.SetDeviationInPoints(30);

   if(direction == 1) // BUY
   {
      double sl = NormalizeDouble(ask - slDist, (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS));
      double tp = NormalizeDouble(ask + tpDist, (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS));
      trade.Buy(lot, _Symbol, ask, sl, tp, "ELITE_BUY_T"+IntegerToString(tier));
   }
   else if(direction == -1) // SELL
   {
      double sl = NormalizeDouble(bid + slDist, (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS));
      double tp = NormalizeDouble(bid - tpDist, (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS));
      trade.Sell(lot, _Symbol, bid, sl, tp, "ELITE_SELL_T"+IntegerToString(tier));
   }
}

//+------------------------------------------------------------------+
//| CLOSE ALL EA POSITIONS                                           |
//+------------------------------------------------------------------+
void CloseAllPositions(string reason)
{
   Print("THEE EliteScalper: Closing all positions — ", reason);
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      if(PositionGetString(POSITION_SYMBOL)  != _Symbol)     continue;
      if(PositionGetInteger(POSITION_MAGIC)  != MagicNumber)  continue;
      trade.PositionClose(ticket, 50);
   }
}

//+------------------------------------------------------------------+
//| CHECK INDIVIDUAL TRADE TP (soft close on profit target)          |
//+------------------------------------------------------------------+
void CheckAndCloseProfitablePositions()
{
   int   tier  = GetCurrentTier();
   double tpUSD = GetTierTP(tier);

   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      if(PositionGetString(POSITION_SYMBOL)  != _Symbol)     continue;
      if(PositionGetInteger(POSITION_MAGIC)  != MagicNumber)  continue;

      double profit = PositionGetDouble(POSITION_PROFIT);
      if(profit >= tpUSD)
      {
         AddProfit(profit);
         trade.PositionClose(ticket, 50);
         Print("ELITE: Closed trade #", ticket, " profit=", profit, " target=", tpUSD);
      }
   }
}

//+------------------------------------------------------------------+
//| SAFETY CHECKS                                                    |
//+------------------------------------------------------------------+
bool IsSafeToTrade()
{
   // EA globally disabled
   if(GlobalVariableCheck(GV_EA_DISABLED) && GlobalVariableGet(GV_EA_DISABLED) == 1)
      return false;

   // Halted today
   if(TradingHaltedToday) return false;

   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double equity  = AccountInfoDouble(ACCOUNT_EQUITY);

   // Daily loss halt
   double startBalance = balance - GetDailyProfit(); // approximate start
   double dailyLoss = startBalance - equity;
   if(dailyLoss > 0 && balance > 0)
   {
      double dailyLossPct = (dailyLoss / balance) * 100.0;
      if(dailyLossPct >= MaxDailyLossPct)
      {
         CloseAllPositions("Daily Loss Halt triggered");
         TradingHaltedToday = true;
         Print("ELITE: DAILY LOSS HALT — ", dailyLossPct, "% loss");
         return false;
      }
   }

   // Max drawdown circuit breaker
   if(balance > 0)
   {
      double ddPct = ((balance - equity) / balance) * 100.0;
      if(ddPct >= MaxAccountDrawdownPct)
      {
         CloseAllPositions("Circuit Breaker triggered");
         GlobalVariableSet(GV_EA_DISABLED, 1);
         Print("ELITE: CIRCUIT BREAKER TRIGGERED — drawdown=", ddPct, "%");
         Alert("THEE EliteScalper CIRCUIT BREAKER TRIGGERED on ", _Symbol);
         return false;
      }
   }

   // Emergency spread close
   double spread = (SymbolInfoDouble(_Symbol, SYMBOL_ASK) - SymbolInfoDouble(_Symbol, SYMBOL_BID))
                   / (SymbolInfoDouble(_Symbol, SYMBOL_POINT) * 10.0);
   if(spread > MaxSpreadPips * 2.0)
   {
      CloseAllPositions("Emergency spread close — spread=" + DoubleToString(spread, 1));
      return false;
   }

   return true;
}

//+------------------------------------------------------------------+
//| DAY CHANGE CHECK                                                 |
//+------------------------------------------------------------------+
void CheckDayChange()
{
   MqlDateTime t;
   TimeToStruct(TimeCurrent(), t);
   int today = t.day;

   if(today != LastDay)
   {
      LastDay = today;
      GV_DAILY_PROFIT = "ELITE_DAILY_PROFIT_" + IntegerToString(today);
      GlobalVariableSet(GV_DAILY_PROFIT, 0.0);
      TradingHaltedToday = false;
      Print("ELITE: New trading day — daily profit reset");
   }
}

//+------------------------------------------------------------------+
//| DASHBOARD FUNCTIONS                                              |
//+------------------------------------------------------------------+

void CreateDashboard()
{
   if(!ShowDashboard) return;

   int x = 10, y = 30;
   int w = 240, h = 220;

   // Background panel
   ObjectCreate(0, PANEL_BG, OBJ_RECTANGLE_LABEL, 0, 0, 0);
   ObjectSetInteger(0, PANEL_BG, OBJPROP_XDISTANCE,  x);
   ObjectSetInteger(0, PANEL_BG, OBJPROP_YDISTANCE,  y);
   ObjectSetInteger(0, PANEL_BG, OBJPROP_XSIZE,      w);
   ObjectSetInteger(0, PANEL_BG, OBJPROP_YSIZE,      h);
   ObjectSetInteger(0, PANEL_BG, OBJPROP_BGCOLOR,    C'15,15,30');
   ObjectSetInteger(0, PANEL_BG, OBJPROP_BORDER_TYPE, BORDER_FLAT);
   ObjectSetInteger(0, PANEL_BG, OBJPROP_COLOR,      C'80,80,180');
   ObjectSetInteger(0, PANEL_BG, OBJPROP_WIDTH,      1);
   ObjectSetInteger(0, PANEL_BG, OBJPROP_BACK,       true);
   ObjectSetInteger(0, PANEL_BG, OBJPROP_CORNER,     CORNER_LEFT_UPPER);

   CreateLabel(LBL_HEADER,  x+8,  y+8,  "═ THEE EliteScalper ═",   C'180,180,255', 8);
   CreateLabel(LBL_MODE,    x+8,  y+28, "Mode    : —",              clrWhite,       8);
   CreateLabel(LBL_TRADES,  x+8,  y+48, "Trades  : — / —",         clrWhite,       8);
   CreateLabel(LBL_LOT,     x+8,  y+68, "Lot     : —",             clrWhite,       8);
   CreateLabel(LBL_TP,      x+8,  y+88, "TP/trade: $—",            clrWhite,       8);
   CreateLabel(LBL_DAILY,   x+8,  y+108,"Daily   : $—",            clrWhite,       8);
   CreateLabel(LBL_CUMUL,   x+8,  y+128,"Cumul   : $—",            clrWhite,       8);
   CreateLabel(LBL_SPREAD,  x+8,  y+148,"Spread  : — pips",        clrWhite,       8);
   CreateLabel(LBL_SESSION, x+8,  y+168,"Session : —",             clrWhite,       8);
   CreateLabel(LBL_STATUS,  x+8,  y+188,"Status  : INITIALIZING",  clrYellow,      8);

   ChartRedraw(0);
}

void CreateLabel(string name, int x, int y, string text, color clr, int fontSize)
{
   ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE,  x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE,  y);
   ObjectSetString(0,  name, OBJPROP_TEXT,        text);
   ObjectSetInteger(0, name, OBJPROP_COLOR,       clr);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE,    fontSize);
   ObjectSetString(0,  name, OBJPROP_FONT,        "Courier New");
   ObjectSetInteger(0, name, OBJPROP_CORNER,      CORNER_LEFT_UPPER);
   ObjectSetInteger(0, name, OBJPROP_BACK,        false);
}

void UpdateDashboard()
{
   if(!ShowDashboard) return;

   int    tier      = GetCurrentTier();
   int    openCount = CountOpenPositions();
   int    maxTrades = GetMaxTrades(tier);
   double lot       = GetCurrentLot();
   double tpUSD     = GetTierTP(tier);
   double dailyP    = GetDailyProfit();
   double cumulP    = GetCumulativeProfit();
   double spread    = (SymbolInfoDouble(_Symbol, SYMBOL_ASK) - SymbolInfoDouble(_Symbol, SYMBOL_BID))
                      / (SymbolInfoDouble(_Symbol, SYMBOL_POINT) * 10.0);
   string session   = GetSessionName();

   color  dailyClr  = (dailyP >= 0) ? C'0,230,120' : C'255,80,80';
   color  cumulClr  = (cumulP >= 0) ? C'0,230,120' : C'255,80,80';
   color  statusClr = TradingHaltedToday ? C'255,80,80' : C'0,230,120';
   string statusTxt = TradingHaltedToday ? "HALTED" : "ACTIVE";

   if(GlobalVariableCheck(GV_EA_DISABLED) && GlobalVariableGet(GV_EA_DISABLED) == 1)
   {
      statusTxt = "CIRCUIT BREAK";
      statusClr = C'255,40,40';
   }

   ObjectSetString(0,  LBL_MODE,    OBJPROP_TEXT, "Mode    : " + GetTierName(tier));
   ObjectSetString(0,  LBL_TRADES,  OBJPROP_TEXT, "Trades  : " + IntegerToString(openCount) + " / " + IntegerToString(maxTrades));
   ObjectSetString(0,  LBL_LOT,     OBJPROP_TEXT, "Lot     : " + DoubleToString(lot, 2));
   ObjectSetString(0,  LBL_TP,      OBJPROP_TEXT, "TP/trade: $" + DoubleToString(tpUSD, 2));
   ObjectSetString(0,  LBL_DAILY,   OBJPROP_TEXT, "Daily   : $" + DoubleToString(dailyP, 2));
   ObjectSetString(0,  LBL_CUMUL,   OBJPROP_TEXT, "Cumul   : $" + DoubleToString(cumulP, 2));
   ObjectSetString(0,  LBL_SPREAD,  OBJPROP_TEXT, "Spread  : " + DoubleToString(spread, 1) + " pips");
   ObjectSetString(0,  LBL_SESSION, OBJPROP_TEXT, "Session : " + session);
   ObjectSetString(0,  LBL_STATUS,  OBJPROP_TEXT, "Status  : " + statusTxt);

   ObjectSetInteger(0, LBL_DAILY,  OBJPROP_COLOR, dailyClr);
   ObjectSetInteger(0, LBL_CUMUL,  OBJPROP_COLOR, cumulClr);
   ObjectSetInteger(0, LBL_STATUS, OBJPROP_COLOR, statusClr);

   ChartRedraw(0);
}

void DeleteDashboard()
{
   string labels[] = {PANEL_BG, LBL_HEADER, LBL_MODE, LBL_TRADES, LBL_LOT,
                      LBL_TP, LBL_DAILY, LBL_CUMUL, LBL_SPREAD, LBL_SESSION, LBL_STATUS};
   for(int i = 0; i < ArraySize(labels); i++)
      ObjectDelete(0, labels[i]);
   ChartRedraw(0);
}

//+------------------------------------------------------------------+
//| OnInit                                                           |
//+------------------------------------------------------------------+
int OnInit()
{
   Print("THEE EliteScalper MicroGrid Edition — Initializing...");

   // Reset cumulative if requested
   if(ResetCumulativeProfit)
   {
      GlobalVariableSet(GV_CUMULATIVE, 0.0);
      Print("ELITE: Cumulative profit reset to 0");
   }

   // Clear circuit breaker if present
   if(GlobalVariableCheck(GV_EA_DISABLED))
      GlobalVariableSet(GV_EA_DISABLED, 0);

   // Initialize day tracking
   MqlDateTime t;
   TimeToStruct(TimeCurrent(), t);
   LastDay = t.day;
   GV_DAILY_PROFIT = "ELITE_DAILY_PROFIT_" + IntegerToString(LastDay);
   if(!GlobalVariableCheck(GV_DAILY_PROFIT))
      GlobalVariableSet(GV_DAILY_PROFIT, 0.0);
   if(!GlobalVariableCheck(GV_CUMULATIVE))
      GlobalVariableSet(GV_CUMULATIVE, 0.0);

   trade.SetExpertMagicNumber(MagicNumber);

   // Build dashboard
   DeleteDashboard();
   CreateDashboard();
   UpdateDashboard();

   Print("ELITE: Init complete. Magic=", MagicNumber, " BaseLot=", BaseLotSize, " BaseTP=$", BaseTPUSD);
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| OnTick — Main handler                                            |
//+------------------------------------------------------------------+
void OnTick()
{
   // Step 1: Day change check
   CheckDayChange();

   // Step 2: Close profitable trades (soft TP monitor)
   CheckAndCloseProfitablePositions();

   // Step 3: Safety checks
   if(!IsSafeToTrade()) { UpdateDashboard(); return; }

   // Step 4: Tier & trade count evaluation
   int tier      = GetCurrentTier();
   int openCount = CountOpenPositions();
   int maxTrades = GetMaxTrades(tier);

   // Step 5: Signal check & open new trades if capacity allows
   if(openCount < maxTrades)
   {
      // Only check signal on new bar to avoid spam
      static datetime lastBarTime = 0;
      datetime curBarTime = iTime(_Symbol, PERIOD_M1, 0);

      if(curBarTime != lastBarTime)
      {
         lastBarTime = curBarTime;
         int signal = GetSignal();
         if(signal != 0)
         {
            // Open as many trades as allowed (up to tier max, fill the slots)
            int toOpen = maxTrades - openCount;
            // Open one per tick check to avoid simultaneous flooding
            OpenTrade(signal);
            Print("ELITE: Opened trade dir=", signal, " tier=", tier,
                  " open=", openCount+1, "/", maxTrades);
         }
      }
   }

   // Step 6: Update dashboard
   UpdateDashboard();
}

//+------------------------------------------------------------------+
//| OnDeinit — Cleanup                                               |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   DeleteDashboard();
   Print("THEE EliteScalper: Deinitialized. Reason=", reason);
}
//+------------------------------------------------------------------+
