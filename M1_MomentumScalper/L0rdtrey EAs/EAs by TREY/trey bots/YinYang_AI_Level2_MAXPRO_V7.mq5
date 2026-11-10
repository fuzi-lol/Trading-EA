//+------------------------------------------------------------------+
//|                               YinYang_AI_Level2_MAXPRO_V6.mq5    |
//|                        Standalone AI Level 2 PRO EA - XAUUSD M1  |
//|                     VERSION 6.00 - COMPLETE WITH PRECISION CORES  |
//|                           (MODERN UI DASHBOARD EDITION)          |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026"
#property link      "https://www.mql5.com"
#property version   "6.00"
#property strict

#include <Trade\Trade.mqh>

// ===== ENUMS =====
enum AI2_REGIME { REGIME_UNKNOWN=0, REGIME_TREND_UP, REGIME_TREND_DOWN, REGIME_SIDEWAY, REGIME_VOLATILE, REGIME_CHAOTIC };
enum AI2_MODE   { MODE_PAUSE=0, MODE_SCALP, MODE_TREND, MODE_SAFE, MODE_HEDGE_DEFENSE };
enum AI2_RISK   { RISK_SAFE=0, RISK_WARNING, RISK_DANGER, RISK_EMERGENCY };
enum AI2_ATTACK_MODE { ATTACK_SAFE=0, ATTACK_ACTIVE, ATTACK_RECOVERY };

// ===== INPUT PARAMETERS =====
// --- AI Level 2 Master ---
input string _ui_header_1          = "=== AI LEVEL 2 MASTER ===";
input bool   Use_AI_Level2         = true;
input bool   Use_Regime_AI         = true;
input bool   Use_MTF_Confirm       = true;
input bool   Block_Entry_On_MTF_Conflict = true;
input bool   Use_M5_Filter         = true;
input bool   Use_M15_Filter        = true;
input string Trade_Symbol          = "XAUUSD";
input ulong  Magic_Number          = 888222111;

// --- Advanced Microstructure & Proportional Targets ---
input string _ui_header_fvg        = "=== MICROSTRUCTURE & TARGETS ===";
input bool   Use_FVG_Filter        = true;     // Filter entries using Fair Value Gaps (Imbalances)
input int    FVG_Min_Gap_Points    = 60;       // Minimum gap distance in points for Gold
input bool   Use_Proportional_TP   = true;     // Scale TP dynamically based on open volume
input double TP_Base_Offset_USD    = 0.9091;   // Linear offset intercept
input double TP_Multiplier_Per_Lot = 9.0909;   // Linear slope factor (0.01->1$, 1.0->10$)
input double Basket_TP_Normal_USD  = 5.0;      // Fallback normal basket profit target

// --- Multi-Mode Lot Matrix & Recovery ---
input string _ui_header_2          = "=== MULTI-MODE LOT MATRIX ===";
input bool   Use_Multi_Mode_Lot    = true;
input double Base_Lot_Safe         = 0.01;
input double Base_Lot_Attack       = 0.02;
input double Base_Lot_Recovery     = 0.05;
input double Martingale_Multiplier = 1.5;
input int    Max_DCA_Levels        = 6;
input int    DCA_Spacing_Points    = 150;

// --- Exit Engine ---
input string _ui_header_3          = "=== ADVANCED EXIT ENGINE ===";
input bool   Use_Exit_Engine       = true;
input double Exit_Trail_USD        = 2.0;      // Base dollar trail distance
input double Exit_Lock_USD         = 5.0;      // Base dollar threshold to activate trailing
input double Exit_BE_USD           = -0.50;    // Absolute dollar target to execute soft break-even
input int    Exit_Max_Time_Min     = 120;      // Max position duration holding cap

// --- Defense & Hedging Systems ---
input string _ui_header_4          = "=== DEFENSE & HEDGING ===";
input bool   Use_Smart_Hedge       = true;
input double Hedge_Trigger_DD_Pct  = 15.0;     // Drawdown % to activate hedge allocation
input bool   Use_Smart_Unwind      = true;

// ===== GLOBAL VARIABLES =====
string          g_symbol;
AI2_REGIME      g_regime = REGIME_UNKNOWN;
AI2_MODE        g_mode   = MODE_SCALP;
double          g_highest_profit = 0.0;
double          g_lowest_profit  = 0.0;
double          g_start_day_equity = 0.0;
bool            g_exit_allow = true;
datetime        g_last_tick_time = 0;
int             g_tick_counter = 0;
double          g_tick_velocity = 0;

// Institutional Handle Cache 
int             g_ma_fast_m1   = INVALID_HANDLE;
int             g_ma_slow_m1   = INVALID_HANDLE;
int             g_ma_fast_m5   = INVALID_HANDLE;
int             g_ma_slow_m5   = INVALID_HANDLE;
int             g_ma_fast_m15  = INVALID_HANDLE;
int             g_ma_slow_m15  = INVALID_HANDLE;
int             g_atr_m1_handle = INVALID_HANDLE;

CTrade          trade;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   g_symbol = (Trade_Symbol == "" ? _Symbol : Trade_Symbol);
   g_start_day_equity = AccountInfoDouble(ACCOUNT_EQUITY);
   trade.SetExpertMagicNumber(Magic_Number);
   
   // Allocate and cache background multi-timeframe structural handles
   g_ma_fast_m1   = iMA(g_symbol, PERIOD_M1, 13, 0, MODE_EMA, PRICE_CLOSE);
   g_ma_slow_m1   = iMA(g_symbol, PERIOD_M1, 48, 0, MODE_EMA, PRICE_CLOSE);
   g_ma_fast_m5   = iMA(g_symbol, PERIOD_M5, 13, 0, MODE_EMA, PRICE_CLOSE);
   g_ma_slow_m5   = iMA(g_symbol, PERIOD_M5, 48, 0, MODE_EMA, PRICE_CLOSE);
   g_ma_fast_m15  = iMA(g_symbol, PERIOD_M15, 13, 0, MODE_EMA, PRICE_CLOSE);
   g_ma_slow_m15  = iMA(g_symbol, PERIOD_M15, 48, 0, MODE_EMA, PRICE_CLOSE);
   g_atr_m1_handle = iATR(g_symbol, PERIOD_M1, 14);
   
   Print("[AI2 INIT V6.00] Handle cache sequence completed for: ", g_symbol);
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   // Safe Release allocation structures
   IndicatorRelease(g_ma_fast_m1);
   IndicatorRelease(g_ma_slow_m1);
   IndicatorRelease(g_ma_fast_m5);
   IndicatorRelease(g_ma_slow_m5);
   IndicatorRelease(g_ma_fast_m15);
   IndicatorRelease(g_ma_slow_m15);
   IndicatorRelease(g_atr_m1_handle);
   
   // Clean up the UI Dashboard Objects
   ObjectsDeleteAll(0, "YY_Dash_");
   
   EventKillTimer();
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   if(!Use_AI_Level2) return;
   
   // 1. Monitor Execution Infrastructure & Flows
   TrackTickVelocity();
   UpdateMarketRegime();
   UpdateStrategyMode();
   
   // 2. Advanced Dynamic Exit Protocols
   TryExit();                // Basket Linear Target Monitor
   TryExitEngine();          // Volatility-Scaled Trailing Monitor

   // 3. Recovery Engine Optimization
   if(Use_Smart_Unwind) TrySmartUnwind();

   // 4. Entry Routing Engine
   TryEntry();               
   TryDCA();                 

   // 5. Institutional Risk Allocation
   if(Use_Smart_Hedge) TryHedge();
   
   // 6. Interface Rendering (New Object-Based Dashboard)
   AI2_MaxProDashboard();
}

//+------------------------------------------------------------------+
//| Tick Velocity Infrastructure Tracker                             |
//+------------------------------------------------------------------+
void TrackTickVelocity()
{
   datetime now = TimeCurrent();
   g_tick_counter++;
   if(now != g_last_tick_time)
   {
      g_tick_velocity = g_tick_counter;
      g_tick_counter = 0;
      g_last_tick_time = now;
   }
}

//+------------------------------------------------------------------+
//| Microstructure Fair Value Gap (FVG) Imbalance Detection Filter   |
//+------------------------------------------------------------------+
bool CheckFVGMicrostructure(int &fvg_direction)
{
   if(!Use_FVG_Filter) return true;
   
   double high3 = iHigh(g_symbol, PERIOD_M1, 3);
   double low1  = iLow(g_symbol, PERIOD_M1, 1);
   double low3  = iLow(g_symbol, PERIOD_M1, 3);
   double high1 = iHigh(g_symbol, PERIOD_M1, 1);
   
   double pt = SymbolInfoDouble(g_symbol, SYMBOL_POINT);
   if(pt <= 0) return false;
   
   if((low1 - high3) / pt >= FVG_Min_Gap_Points)
   {
      fvg_direction = 1; 
      return true;
   }
   
   if((low3 - high1) / pt >= FVG_Min_Gap_Points)
   {
      fvg_direction = -1; 
      return true;
   }
   
   return false; 
}

//+------------------------------------------------------------------+
//| Corrected MQL5 Handle Copy Multi-Timeframe Trend Engine          |
//+------------------------------------------------------------------+
int TrendDir(ENUM_TIMEFRAMES tf)
{
   int hFast = INVALID_HANDLE;
   int hSlow = INVALID_HANDLE;
   
   if(tf == PERIOD_M1)        { hFast = g_ma_fast_m1;   hSlow = g_ma_slow_m1; }
   else if(tf == PERIOD_M5)   { hFast = g_ma_fast_m5;   hSlow = g_ma_slow_m5; }
   else if(tf == PERIOD_M15)  { hFast = g_ma_fast_m15;  hSlow = g_ma_slow_m15; }
   else return 0;
   
   if(hFast == INVALID_HANDLE || hSlow == INVALID_HANDLE) return 0;
   
   double fastBuffer[];
   double slowBuffer[];
   ArraySetAsSeries(fastBuffer, true);
   ArraySetAsSeries(slowBuffer, true);
   
   if(CopyBuffer(hFast, 0, 1, 1, fastBuffer) <= 0) return 0;
   if(CopyBuffer(hSlow, 0, 1, 1, slowBuffer) <= 0) return 0;
   
   if(fastBuffer[0] > slowBuffer[0]) return 1;
   if(fastBuffer[0] < slowBuffer[0]) return -1;
   return 0;
}

//+------------------------------------------------------------------+
//| Corrected MQL5 Volatility ATR Points Evaluator                 |
//+------------------------------------------------------------------+
double ATRPoints(ENUM_TIMEFRAMES tf)
{
   int handle = (tf == PERIOD_M1) ? g_atr_m1_handle : iATR(g_symbol, tf, 14);
   if(handle == INVALID_HANDLE) return 0.0;
   
   double atrBuffer[];
   ArraySetAsSeries(atrBuffer, true);
   int copied = CopyBuffer(handle, 0, 1, 1, atrBuffer);
   
   if(tf != PERIOD_M1) IndicatorRelease(handle);
   
   if(copied > 0)
   {
      return atrBuffer[0] / SymbolInfoDouble(g_symbol, SYMBOL_POINT);
   }
   return 0.0;
}

//+------------------------------------------------------------------+
//| Dynamic Regime Engine Core Classification                       |
//+------------------------------------------------------------------+
void UpdateMarketRegime()
{
   if(!Use_Regime_AI) { g_regime = REGIME_SIDEWAY; return; }
   
   double atr = ATRPoints(PERIOD_M1);
   int m1_trend = TrendDir(PERIOD_M1);
   
   if(atr > 400) g_regime = REGIME_CHAOTIC;
   else if(atr > 250) g_regime = REGIME_VOLATILE;
   else if(m1_trend == 1) g_regime = REGIME_TREND_UP;
   else if(m1_trend == -1) g_regime = REGIME_TREND_DOWN;
   else g_regime = REGIME_SIDEWAY;
}

//+------------------------------------------------------------------+
//| Dynamic Account Sizing Strategy Matrix                           |
//+------------------------------------------------------------------+
void UpdateStrategyMode()
{
   double bal = AccountInfoDouble(ACCOUNT_BALANCE);
   double eq  = AccountInfoDouble(ACCOUNT_EQUITY);
   if(bal <= 0) return;
   
   double dd = ((bal - eq) / bal) * 100.0;
   
   if(dd >= Hedge_Trigger_DD_Pct) g_mode = MODE_HEDGE_DEFENSE;
   else if(dd >= 8.0)  g_mode = MODE_SAFE;
   else if(dd >= 3.0)  g_mode = MODE_TREND;
   else g_mode = MODE_SCALP;
}

//+------------------------------------------------------------------+
//| Integrated Logic Router Configuration                            |
//+------------------------------------------------------------------+
int BuildDirection()
{
   int m1  = TrendDir(PERIOD_M1);
   int m5  = TrendDir(PERIOD_M5);
   int m15 = TrendDir(PERIOD_M15);
   
   if(g_regime == REGIME_TREND_UP)   return 1;
   if(g_regime == REGIME_TREND_DOWN) return -1;
   
   if(Use_FVG_Filter)
   {
      int fvg_dir = 0;
      if(!CheckFVGMicrostructure(fvg_dir)) return 0; 
      if(fvg_dir != m1) return 0;                    
   }

   if(Use_MTF_Confirm && Block_Entry_On_MTF_Conflict)
   {
      if(Use_M5_Filter && m5 != 0 && m1 != 0 && m5 != m1) return 0;
      if(Use_M15_Filter && m15 != 0 && m1 != 0 && m15 != m1) return 0;
   }
   return m1;
}

//+------------------------------------------------------------------+
//| Math Engine: Proportional Multi-Tier Lot Sized Targets           |
//+------------------------------------------------------------------+
double AI2_CurrentTargetTP()
{
   if(Use_Proportional_TP)
   {
      double totalLots = TotalLots();
      if(totalLots <= 0) return Basket_TP_Normal_USD;
      
      double calculated_tp = TP_Base_Offset_USD + (totalLots * TP_Multiplier_Per_Lot);
      return NormalizeDouble(calculated_tp, 2);
   }

   return Basket_TP_Normal_USD;
}

//+------------------------------------------------------------------+
//| Operational Profit Matrix Monitors                              |
//+------------------------------------------------------------------+
void TryExit()
{ 
   if(!g_exit_allow) return; 
   double target = AI2_CurrentTargetTP(); 
   
   if(BasketProfit() >= target)
   { 
      Print("[AI2 PROPORTIONAL EXIT] Scalp target hit at: ", target, " USD. Processing sequence recycle."); 
      CloseAll(); 
   } 
}

//+------------------------------------------------------------------+
//| Volatility Adaptive Dynamic Tracking Exit Module                 |
//+------------------------------------------------------------------+
void TryExitEngine()
{
   if(!Use_Exit_Engine) return;
   if(CountPos() == 0) 
   {
      g_highest_profit = 0.0;
      g_lowest_profit  = 0.0;
      return;
   }
   
   double profit = BasketProfit();
   if(profit > g_highest_profit) g_highest_profit = profit;
   if(profit < g_lowest_profit)  g_lowest_profit  = profit;
   
   double atr_m1 = ATRPoints(PERIOD_M1);
   double volatility_scaler = (atr_m1 > 0) ? (atr_m1 / 200.0) : 1.0;
   if(volatility_scaler < 0.4) volatility_scaler = 0.4; 
   if(volatility_scaler > 2.5) volatility_scaler = 2.5; 

   double dynamic_trail = Exit_Trail_USD * volatility_scaler;
   double dynamic_lock  = Exit_Lock_USD * volatility_scaler;
   
   if(Exit_BE_USD != 0 && profit <= Exit_BE_USD)
   {
      if(g_highest_profit > (dynamic_lock * 0.5))
      {
         Print("[EXIT ENGINE] Soft Breakeven Intercept active | Profit: ", profit);
         CloseAll();
         return;
     }
   }
   
   if(dynamic_lock > 0 && g_highest_profit >= dynamic_lock)
   {
      if(profit <= g_highest_profit - dynamic_trail)
      {
         Print("[EXIT ENGINE] Volatility-Scaled Trailing Stop triggered | Max: ", g_highest_profit, " Current: ", profit, " Trail Gap: ", dynamic_trail);
         CloseAll();
         return;
      }
   }
   
   if(Exit_Max_Time_Min > 0)
   {
      datetime oldestOrderTime = 0;
      for(int i = PositionsTotal() - 1; i >= 0; i--)
      {
         if(PositionGetSymbol(i) == g_symbol && PositionGetInteger(POSITION_MAGIC) == Magic_Number)
         {
            datetime ot = (datetime)PositionGetInteger(POSITION_TIME);
            if(oldestOrderTime == 0 || ot < oldestOrderTime) oldestOrderTime = ot;
         }
      }
      
      if(oldestOrderTime > 0 && (TimeCurrent() - oldestOrderTime) / 60 >= Exit_Max_Time_Min)
      {
         Print("[EXIT ENGINE] Position Duration Cap reached. Forcing systematic exit matrix clear.");
         CloseAll();
      }
   }
}

//+------------------------------------------------------------------+
//| Base Order Routing Operations Engine                             |
//+------------------------------------------------------------------+
void TryEntry()
{
   if(CountPos() > 0) return; 
   
   int dir = BuildDirection();
   if(dir == 0) return;
   
   double calculated_lot = Base_Lot_Safe;
   if(Use_Multi_Mode_Lot)
   {
      if(g_mode == MODE_SCALP)       calculated_lot = Base_Lot_Safe;
      else if(g_mode == MODE_TREND)  calculated_lot = Base_Lot_Attack;
      else if(g_mode == MODE_SAFE)   calculated_lot = Base_Lot_Safe;
   }
   
   if(dir == 1)
   {
      trade.Buy(calculated_lot, g_symbol, SymbolInfoDouble(g_symbol, SYMBOL_ASK), 0, 0, "YinYang V6 Base Buy");
   }
   else if(dir == -1)
   {
      trade.Sell(calculated_lot, g_symbol, SymbolInfoDouble(g_symbol, SYMBOL_BID), 0, 0, "YinYang V6 Base Sell");
   }
}

//+------------------------------------------------------------------+
//| Advanced DCA Averaging Execution Infrastructure                  |
//+------------------------------------------------------------------+
void TryDCA()
{
   int current_levels = CountPos();
   if(current_levels <= 0 || current_levels >= Max_DCA_Levels) return;
   
   double last_open_price = 0;
   int type = -1;
   double total_volume = 0;
   
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(PositionGetSymbol(i) == g_symbol && PositionGetInteger(POSITION_MAGIC) == Magic_Number)
      {
         last_open_price = PositionGetDouble(POSITION_PRICE_OPEN);
         type = (int)PositionGetInteger(POSITION_TYPE);
         total_volume += PositionGetDouble(POSITION_VOLUME);
      }
   }
   
   double current_price = (type == POSITION_TYPE_BUY) ? SymbolInfoDouble(g_symbol, SYMBOL_BID) : SymbolInfoDouble(g_symbol, SYMBOL_ASK);
   double point = SymbolInfoDouble(g_symbol, SYMBOL_POINT);
   if(point <= 0) return;
   
   double gap = MathAbs(current_price - last_open_price) / point;
   if(gap < DCA_Spacing_Points) return; 
   
   double next_lot = NormalizeDouble(total_volume * Martingale_Multiplier, 2);
   if(next_lot > 5.0) next_lot = 5.0; 
   
   if(type == POSITION_TYPE_BUY && current_price < last_open_price)
   {
      trade.Buy(next_lot, g_symbol, SymbolInfoDouble(g_symbol, SYMBOL_ASK), 0, 0, "YinYang V6 DCA Buy");
   }
   else if(type == POSITION_TYPE_SELL && current_price > last_open_price)
   {
      trade.Sell(next_lot, g_symbol, SymbolInfoDouble(g_symbol, SYMBOL_BID), 0, 0, "YinYang V6 DCA Sell");
   }
}

//+------------------------------------------------------------------+
//| Smart Unwind Vector Accounting Engine                           |
//+------------------------------------------------------------------+
void TrySmartUnwind()
{
   if(CountPos() < 4) return;
   
   if(BasketProfit() > 2.0)
   {
      ulong worst_ticket = 0;
      double worst_loss = 0.0;
      
      for(int i = PositionsTotal() - 1; i >= 0; i--)
      {
         if(PositionGetSymbol(i) == g_symbol && PositionGetInteger(POSITION_MAGIC) == Magic_Number)
         {
            double pft = PositionGetDouble(POSITION_PROFIT);
            if(pft < worst_loss)
            {
               worst_loss = pft;
               worst_ticket = PositionGetInteger(POSITION_TICKET);
            }
         }
      }
      
      if(worst_ticket > 0)
      {
         Print("[SMART UNWIND PRO] Trimming worst outlier under global profit alignment.");
         trade.PositionClose(worst_ticket);
      }
   }
}

//+------------------------------------------------------------------+
//| Institutional Direct Allocation Protection Hedge Module          |
//+------------------------------------------------------------------+
void TryHedge()
{
   if(g_mode != MODE_HEDGE_DEFENSE) return;
   
   int buy_count = 0, sell_count = 0;
   double buy_lots = 0, sell_lots = 0;
   
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(PositionGetSymbol(i) == g_symbol && PositionGetInteger(POSITION_MAGIC) == Magic_Number)
      {
         int type = (int)PositionGetInteger(POSITION_TYPE);
         if(type == POSITION_TYPE_BUY)  { buy_count++;  buy_lots += PositionGetDouble(POSITION_VOLUME); }
         if(type == POSITION_TYPE_SELL) { sell_count++; sell_lots += PositionGetDouble(POSITION_VOLUME); }
      }
   }
   
   if(buy_lots > sell_lots && sell_count == 0)
   {
      double hedge_diff = NormalizeDouble(buy_lots - sell_lots, 2);
      trade.Sell(hedge_diff, g_symbol, SymbolInfoDouble(g_symbol, SYMBOL_BID), 0, 0, "YinYang V6 Insulation Hedge Sell");
   }
   else if(sell_lots > buy_lots && buy_count == 0)
   {
      double hedge_diff = NormalizeDouble(sell_lots - buy_lots, 2);
      trade.Buy(hedge_diff, g_symbol, SymbolInfoDouble(g_symbol, SYMBOL_ASK), 0, 0, "YinYang V6 Insulation Hedge Buy");
   }
}

//+------------------------------------------------------------------+
//| Structural Accounting Helper Abstractions                        |
//+------------------------------------------------------------------+
double BasketProfit()
{
   double total_profit = 0.0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(PositionGetSymbol(i) == g_symbol && PositionGetInteger(POSITION_MAGIC) == Magic_Number)
      {
         total_profit += PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);
      }
   }
   return total_profit;
}

double TotalLots()
{
   double total_lots = 0.0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(PositionGetSymbol(i) == g_symbol && PositionGetInteger(POSITION_MAGIC) == Magic_Number)
      {
         total_lots += PositionGetDouble(POSITION_VOLUME);
      }
   }
   return total_lots;
}

int CountPos()
{
   int count = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(PositionGetSymbol(i) == g_symbol && PositionGetInteger(POSITION_MAGIC) == Magic_Number)
      {
         count++;
      }
   }
   return count;
}

void CloseAll()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(PositionGetSymbol(i) == g_symbol && PositionGetInteger(POSITION_MAGIC) == Magic_Number)
      {
         trade.PositionClose(PositionGetInteger(POSITION_TICKET));
      }
   }
   g_highest_profit = 0.0;
   g_lowest_profit  = 0.0;
}

//+------------------------------------------------------------------+
//| UI Helper Functions for Object Creation                          |
//+------------------------------------------------------------------+
void UI_CreateLabel(string name, string text, int x, int y, color clr, int fontSize=10, string font="Trebuchet MS")
{
   if(ObjectFind(0, name) < 0)
   {
      ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
      ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
      ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
      ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(0, name, OBJPROP_ANCHOR, ANCHOR_LEFT_UPPER);
      ObjectSetString(0, name, OBJPROP_FONT, font);
      ObjectSetInteger(0, name, OBJPROP_FONTSIZE, fontSize);
      ObjectSetInteger(0, name, OBJPROP_BACK, false);
      ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
   }
   ObjectSetString(0, name, OBJPROP_TEXT, text);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
}

void UI_CreatePanel(string name, int x, int y, int w, int h, color bgClr, color borderClr)
{
   if(ObjectFind(0, name) < 0)
   {
      ObjectCreate(0, name, OBJ_RECTANGLE_LABEL, 0, 0, 0);
      ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
      ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
      ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(0, name, OBJPROP_BGCOLOR, bgClr);
      ObjectSetInteger(0, name, OBJPROP_COLOR, borderClr);
      ObjectSetInteger(0, name, OBJPROP_BORDER_TYPE, BORDER_FLAT);
      ObjectSetInteger(0, name, OBJPROP_BACK, true);
      ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
   }
   ObjectSetInteger(0, name, OBJPROP_XSIZE, w);
   ObjectSetInteger(0, name, OBJPROP_YSIZE, h);
}

//+------------------------------------------------------------------+
//| Institutional Graphical Dashboard Render Panel                   |
//+------------------------------------------------------------------+
void AI2_MaxProDashboard()
{
   // Text Logic Evaluation
   string regimeText = "UNKNOWN";
   if(g_regime == REGIME_TREND_UP)   regimeText = "TREND UP";
   if(g_regime == REGIME_TREND_DOWN) regimeText = "TREND DOWN";
   if(g_regime == REGIME_SIDEWAY)    regimeText = "SIDEWAY BALANCE";
   if(g_regime == REGIME_VOLATILE)   regimeText = "HIGH VOLATILITY";
   if(g_regime == REGIME_CHAOTIC)    regimeText = "CHAOTIC BREAKOUT";

   string modeText = "SCALP ENGINE";
   if(g_mode == MODE_TREND)         modeText = "TREND ENGAGED";
   if(g_mode == MODE_SAFE)          modeText = "PRESERVATION SAFE";
   if(g_mode == MODE_HEDGE_DEFENSE) modeText = "INSULATION HEDGE DEFENSE";

   double pnl = BasketProfit();
   color pnlColor = (pnl > 0) ? clrLimeGreen : (pnl < 0) ? clrRed : clrGray;

   // UI Layout Parameters
   int startX = 20;
   int startY = 20;
   int panelWidth = 340;
   int panelHeight = 240;
   
   // 1. Render Background Glass Panel
   UI_CreatePanel("YY_Dash_BG", startX, startY, panelWidth, panelHeight, clrBlack, clrDimGray);
   
   // 2. Render Text Elements (Row by Row)
   int currentY = startY + 15;
   int textX = startX + 15;
   int valX  = startX + 220; // Column for values
   
   // Title
   UI_CreateLabel("YY_Dash_Title", "YINYANG AI LEVEL 2 MAXPRO", textX, currentY, clrCyan, 11, "Arial Bold");
   currentY += 30;

   // Row 1: Regime
   UI_CreateLabel("YY_Dash_L1", "Market Structural Regime:", textX, currentY, clrLightGray);
   UI_CreateLabel("YY_Dash_V1", regimeText, valX, currentY, clrGold);
   currentY += 20;

   // Row 2: Mode
   UI_CreateLabel("YY_Dash_L2", "Operational Logic Mode:", textX, currentY, clrLightGray);
   UI_CreateLabel("YY_Dash_V2", modeText, valX, currentY, clrGold);
   currentY += 20;

   // Row 3: Tick Velocity
   UI_CreateLabel("YY_Dash_L3", "Active Tick Velocity:", textX, currentY, clrLightGray);
   UI_CreateLabel("YY_Dash_V3", DoubleToString(g_tick_velocity, 0) + " t/s", valX, currentY, clrWhite);
   currentY += 20;

   // Row 4: Layers
   UI_CreateLabel("YY_Dash_L4", "Open Allocation Multi-Levels:", textX, currentY, clrLightGray);
   UI_CreateLabel("YY_Dash_V4", IntegerToString(CountPos()), valX, currentY, clrWhite);
   currentY += 20;

   // Row 5: Total Lots
   UI_CreateLabel("YY_Dash_L5", "Total Lot Sized Allocation:", textX, currentY, clrLightGray);
   UI_CreateLabel("YY_Dash_V5", DoubleToString(TotalLots(), 2), valX, currentY, clrWhite);
   currentY += 20;

   // Row 6: Active PNL (Color Coded)
   UI_CreateLabel("YY_Dash_L6", "Current Active Basket Return:", textX, currentY, clrLightGray);
   UI_CreateLabel("YY_Dash_V6", DoubleToString(pnl, 2) + " USD", valX, currentY, pnlColor);
   currentY += 20;

   // Row 7: Target TP
   UI_CreateLabel("YY_Dash_L7", "Dynamic Linear Target TP:", textX, currentY, clrLightGray);
   UI_CreateLabel("YY_Dash_V7", DoubleToString(AI2_CurrentTargetTP(), 2) + " USD", valX, currentY, clrDeepSkyBlue);
   currentY += 20;

   // Row 8: Peak Trail
   UI_CreateLabel("YY_Dash_L8", "Trailing Target Peak Profit:", textX, currentY, clrLightGray);
   UI_CreateLabel("YY_Dash_V8", DoubleToString(g_highest_profit, 2) + " USD", valX, currentY, clrMediumAquamarine);
}