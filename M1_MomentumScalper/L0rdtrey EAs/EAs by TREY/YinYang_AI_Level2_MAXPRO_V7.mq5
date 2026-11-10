//+------------------------------------------------------------------+
//|               YinYang_AI_Level2_MAXPRO_V7.mq5                   |
//|         Standalone AI Level 2 PRO EA - XAUUSD M1                |
//|   VERSION 7.00 - FULL UPGRADE: TP/SL + RSI + BB + SESSION +     |
//|   NEWS FILTER + IMPROVED RISK + BETTER DCA + ENHANCED UI        |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026"
#property link      "https://www.mql5.com"
#property version   "7.00"
#property strict

#include <Trade\Trade.mqh>

// ===== ENUMS =====
enum AI2_REGIME { REGIME_UNKNOWN=0, REGIME_TREND_UP, REGIME_TREND_DOWN, REGIME_SIDEWAY, REGIME_VOLATILE, REGIME_CHAOTIC };
enum AI2_MODE   { MODE_PAUSE=0, MODE_SCALP, MODE_TREND, MODE_SAFE, MODE_HEDGE_DEFENSE };
enum AI2_RISK   { RISK_SAFE=0, RISK_WARNING, RISK_DANGER, RISK_EMERGENCY };

// ===== INPUT PARAMETERS =====

// --- AI Level 2 Master ---
input string _hdr_1               = "=== AI LEVEL 2 MASTER ===";
input bool   Use_AI_Level2         = true;
input bool   Use_Regime_AI         = true;
input bool   Use_MTF_Confirm       = true;
input bool   Block_Entry_On_MTF_Conflict = true;
input bool   Use_M5_Filter         = true;
input bool   Use_M15_Filter        = true;
input string Trade_Symbol          = "XAUUSD";
input ulong  Magic_Number          = 888222111;

// --- Take Profit & Stop Loss (NEW in V7) ---
input string _hdr_tp               = "=== TAKE PROFIT & STOP LOSS ===";
input bool   Use_Fixed_TP_SL       = true;       // Enable fixed TP/SL on every order
input double TP_Points             = 300;         // Take Profit in points (300 = $3 per 0.01 lot Gold)
input double SL_Points             = 200;         // Stop Loss in points  (200 = $2 per 0.01 lot Gold)
input bool   Use_Basket_TP         = true;        // Also close all when basket profit target hit
input double Basket_TP_USD         = 5.0;         // Basket profit target in USD
input double Basket_SL_USD         = -20.0;       // Basket stop loss in USD (NEGATIVE) — hard protection
input bool   Use_Proportional_TP   = true;        // Scale basket TP by open volume
input double TP_Base_Offset_USD    = 0.9091;
input double TP_Multiplier_Per_Lot = 9.0909;

// --- RSI Filter (NEW in V7) ---
input string _hdr_rsi              = "=== RSI ENTRY FILTER ===";
input bool   Use_RSI_Filter        = true;
input int    RSI_Period            = 14;
input double RSI_Overbought        = 70.0;        // Block BUY if RSI above this
input double RSI_Oversold          = 30.0;        // Block SELL if RSI below this
input bool   RSI_Require_Extreme   = false;       // If true: only trade AT extremes (reversal mode)

// --- Bollinger Bands Filter (NEW in V7) ---
input string _hdr_bb               = "=== BOLLINGER BANDS FILTER ===";
input bool   Use_BB_Filter         = true;
input int    BB_Period             = 20;
input double BB_Deviation          = 2.0;
input bool   BB_Block_Outside      = true;        // Block entries outside BB (overextended)

// --- Session Time Filter (NEW in V7) ---
input string _hdr_session          = "=== SESSION TIME FILTER ===";
input bool   Use_Session_Filter    = true;
input bool   Allow_London          = true;        // 08:00-12:00 GMT
input bool   Allow_NewYork         = true;        // 13:00-17:00 GMT
input bool   Allow_Asian           = false;       // 00:00-07:00 GMT (low vol, off by default)
input int    Session_GMT_Offset    = 3;           // Your broker's GMT offset (e.g. +3 for EET)

// --- News / High-Impact Filter (NEW in V7) ---
input string _hdr_news             = "=== NEWS BLACKOUT FILTER ===";
input bool   Use_News_Filter       = true;
input int    News_Block_Min_Before = 30;          // Minutes to block before high-impact news
input int    News_Block_Min_After  = 30;          // Minutes to block after high-impact news
// Manually set upcoming news times (UTC). Up to 5 events.
// Format: hour * 100 + minute (e.g. 1430 = 14:30 UTC)
input int    News_Event_1          = 0;
input int    News_Event_2          = 0;
input int    News_Event_3          = 0;
input int    News_Event_4          = 0;
input int    News_Event_5          = 0;

// --- Microstructure & FVG ---
input string _hdr_fvg              = "=== MICROSTRUCTURE & FVG ===";
input bool   Use_FVG_Filter        = true;
input int    FVG_Min_Gap_Points    = 60;

// --- Multi-Mode Lot Matrix ---
input string _hdr_lot              = "=== MULTI-MODE LOT MATRIX ===";
input bool   Use_Multi_Mode_Lot    = true;
input double Base_Lot_Safe         = 0.01;
input double Base_Lot_Attack       = 0.02;
input double Base_Lot_Recovery     = 0.05;
input double Max_Risk_Per_Trade_Pct= 1.0;         // Max % of balance to risk per trade (0=disabled)
input double Martingale_Multiplier = 1.5;
input int    Max_DCA_Levels        = 4;           // Reduced from 6 to limit drawdown
input int    DCA_Spacing_Points    = 200;         // Increased spacing for better averaging

// --- Drawdown Protection (UPGRADED in V7) ---
input string _hdr_dd               = "=== DRAWDOWN PROTECTION ===";
input double Max_Daily_Loss_Pct    = 5.0;         // Stop trading if daily loss exceeds this %
input double Max_Total_DD_Pct      = 15.0;        // Hard stop if total drawdown exceeds this %
input bool   Use_Equity_Guard      = true;        // Monitor equity continuously

// --- Exit Engine ---
input string _hdr_exit             = "=== ADVANCED EXIT ENGINE ===";
input bool   Use_Exit_Engine       = true;
input double Exit_Trail_USD        = 2.0;
input double Exit_Lock_USD         = 5.0;
input double Exit_BE_USD           = -0.50;
input int    Exit_Max_Time_Min     = 90;          // Reduced from 120 min

// --- Defense & Hedging ---
input string _hdr_hedge            = "=== DEFENSE & HEDGING ===";
input bool   Use_Smart_Hedge       = true;
input double Hedge_Trigger_DD_Pct  = 15.0;
input bool   Use_Smart_Unwind      = true;

// ===== GLOBAL VARIABLES =====
string          g_symbol;
AI2_REGIME      g_regime          = REGIME_UNKNOWN;
AI2_MODE        g_mode            = MODE_SCALP;
double          g_highest_profit  = 0.0;
double          g_lowest_profit   = 0.0;
double          g_start_day_equity= 0.0;
bool            g_exit_allow      = true;
bool            g_trading_halted  = false;        // V7: daily loss halt flag
datetime        g_last_tick_time  = 0;
int             g_tick_counter    = 0;
double          g_tick_velocity   = 0;

// Indicator Handles
int g_ma_fast_m1=INVALID_HANDLE, g_ma_slow_m1=INVALID_HANDLE;
int g_ma_fast_m5=INVALID_HANDLE, g_ma_slow_m5=INVALID_HANDLE;
int g_ma_fast_m15=INVALID_HANDLE, g_ma_slow_m15=INVALID_HANDLE;
int g_atr_m1_handle=INVALID_HANDLE;
int g_rsi_m1_handle=INVALID_HANDLE;              // V7: RSI
int g_bb_m1_handle=INVALID_HANDLE;               // V7: Bollinger Bands

CTrade trade;

//+------------------------------------------------------------------+
//| OnInit                                                           |
//+------------------------------------------------------------------+
int OnInit()
{
   g_symbol = (Trade_Symbol == "" ? _Symbol : Trade_Symbol);
   g_start_day_equity = AccountInfoDouble(ACCOUNT_EQUITY);
   trade.SetExpertMagicNumber(Magic_Number);

   g_ma_fast_m1  = iMA(g_symbol, PERIOD_M1,  13, 0, MODE_EMA, PRICE_CLOSE);
   g_ma_slow_m1  = iMA(g_symbol, PERIOD_M1,  48, 0, MODE_EMA, PRICE_CLOSE);
   g_ma_fast_m5  = iMA(g_symbol, PERIOD_M5,  13, 0, MODE_EMA, PRICE_CLOSE);
   g_ma_slow_m5  = iMA(g_symbol, PERIOD_M5,  48, 0, MODE_EMA, PRICE_CLOSE);
   g_ma_fast_m15 = iMA(g_symbol, PERIOD_M15, 13, 0, MODE_EMA, PRICE_CLOSE);
   g_ma_slow_m15 = iMA(g_symbol, PERIOD_M15, 48, 0, MODE_EMA, PRICE_CLOSE);
   g_atr_m1_handle = iATR(g_symbol, PERIOD_M1, 14);
   g_rsi_m1_handle = iRSI(g_symbol, PERIOD_M1, RSI_Period, PRICE_CLOSE);    // V7
   g_bb_m1_handle  = iBands(g_symbol, PERIOD_M1, BB_Period, 0, BB_Deviation, PRICE_CLOSE); // V7

   if(g_ma_fast_m1==INVALID_HANDLE || g_rsi_m1_handle==INVALID_HANDLE || g_bb_m1_handle==INVALID_HANDLE)
   {
      Print("[V7 ERROR] Indicator handle allocation failed. Check symbol/timeframe.");
      return INIT_FAILED;
   }

   Print("[AI2 V7.00 INIT] All handles allocated for: ", g_symbol);
   EventSetTimer(60); // Daily equity reset timer
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| OnDeinit                                                         |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   IndicatorRelease(g_ma_fast_m1);  IndicatorRelease(g_ma_slow_m1);
   IndicatorRelease(g_ma_fast_m5);  IndicatorRelease(g_ma_slow_m5);
   IndicatorRelease(g_ma_fast_m15); IndicatorRelease(g_ma_slow_m15);
   IndicatorRelease(g_atr_m1_handle);
   IndicatorRelease(g_rsi_m1_handle);
   IndicatorRelease(g_bb_m1_handle);
   ObjectsDeleteAll(0, "YY_Dash_");
   EventKillTimer();
}

//+------------------------------------------------------------------+
//| OnTimer — reset daily equity at midnight                         |
//+------------------------------------------------------------------+
void OnTimer()
{
   MqlDateTime tm;
   TimeToStruct(TimeCurrent(), tm);
   if(tm.hour == 0 && tm.min < 2)
   {
      g_start_day_equity = AccountInfoDouble(ACCOUNT_EQUITY);
      g_trading_halted   = false;
      Print("[V7 TIMER] Daily equity reset. Halt lifted.");
   }
}

//+------------------------------------------------------------------+
//| OnTick                                                           |
//+------------------------------------------------------------------+
void OnTick()
{
   if(!Use_AI_Level2) return;

   TrackTickVelocity();
   CheckEquityGuard();         // V7: Hard equity / daily loss protection
   if(g_trading_halted) { AI2_MaxProDashboard(); return; } // Halt all trading

   UpdateMarketRegime();
   UpdateStrategyMode();

   TryExit();
   TryExitEngine();
   if(Use_Smart_Unwind) TrySmartUnwind();

   TryEntry();
   TryDCA();

   if(Use_Smart_Hedge) TryHedge();
   AI2_MaxProDashboard();
}

//+------------------------------------------------------------------+
//| V7: Equity Guard — Daily Loss + Total DD Protection             |
//+------------------------------------------------------------------+
void CheckEquityGuard()
{
   if(!Use_Equity_Guard) return;

   double equity  = AccountInfoDouble(ACCOUNT_EQUITY);
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);

   // Hard basket stop loss
   if(Use_Basket_TP && BasketProfit() <= Basket_SL_USD)
   {
      Print("[V7 EQUITY GUARD] Basket SL hit at ", Basket_SL_USD, " USD. Closing all.");
      CloseAll();
      return;
   }

   // Daily loss limit
   if(Max_Daily_Loss_Pct > 0 && g_start_day_equity > 0)
   {
      double daily_loss_pct = ((g_start_day_equity - equity) / g_start_day_equity) * 100.0;
      if(daily_loss_pct >= Max_Daily_Loss_Pct)
      {
         if(!g_trading_halted)
         {
            Print("[V7 DAILY HALT] Daily loss limit reached: ", DoubleToString(daily_loss_pct,2), "%. Trading halted until reset.");
            CloseAll();
            g_trading_halted = true;
         }
         return;
      }
   }

   // Total drawdown protection
   if(Max_Total_DD_Pct > 0 && balance > 0)
   {
      double total_dd = ((balance - equity) / balance) * 100.0;
      if(total_dd >= Max_Total_DD_Pct)
      {
         Print("[V7 TOTAL DD HALT] Total drawdown ", DoubleToString(total_dd,2), "% exceeded limit. Emergency close.");
         CloseAll();
         g_trading_halted = true;
      }
   }
}

//+------------------------------------------------------------------+
//| V7: Session Time Filter                                          |
//+------------------------------------------------------------------+
bool IsSessionAllowed()
{
   if(!Use_Session_Filter) return true;

   datetime now = TimeCurrent();
   MqlDateTime tm;
   TimeToStruct(now, tm);

   // Convert broker time to GMT
   int gmt_hour = tm.hour - Session_GMT_Offset;
   if(gmt_hour < 0)  gmt_hour += 24;
   if(gmt_hour > 23) gmt_hour -= 24;

   // Asian session: 00:00 - 07:59 GMT
   if(Allow_Asian && gmt_hour >= 0 && gmt_hour < 8)   return true;
   // London session: 08:00 - 12:59 GMT
   if(Allow_London && gmt_hour >= 8 && gmt_hour < 13)  return true;
   // New York session: 13:00 - 17:59 GMT
   if(Allow_NewYork && gmt_hour >= 13 && gmt_hour < 18) return true;

   return false; // Outside all allowed sessions
}

//+------------------------------------------------------------------+
//| V7: News Blackout Filter                                         |
//+------------------------------------------------------------------+
bool IsNewsBlackout()
{
   if(!Use_News_Filter) return false;

   datetime now = TimeCurrent();
   MqlDateTime tm;
   TimeToStruct(now, tm);
   int current_hhmm = tm.hour * 100 + tm.min;

   int events[5];
   events[0] = News_Event_1;
   events[1] = News_Event_2;
   events[2] = News_Event_3;
   events[3] = News_Event_4;
   events[4] = News_Event_5;

   for(int i = 0; i < 5; i++)
   {
      if(events[i] <= 0) continue;

      int news_hour = events[i] / 100;
      int news_min  = events[i] % 100;

      MqlDateTime news_tm = tm;
      news_tm.hour = news_hour;
      news_tm.min  = news_min;
      news_tm.sec  = 0;
      datetime news_time = StructToTime(news_tm);

      int diff_min = (int)((news_time - now) / 60);

      // Before news
      if(diff_min >= 0 && diff_min <= News_Block_Min_Before) return true;
      // After news
      if(diff_min < 0 && MathAbs(diff_min) <= News_Block_Min_After) return true;
   }
   return false;
}

//+------------------------------------------------------------------+
//| V7: RSI Filter                                                   |
//+------------------------------------------------------------------+
bool CheckRSI(int required_dir)
{
   if(!Use_RSI_Filter) return true;
   if(g_rsi_m1_handle == INVALID_HANDLE) return true;

   double rsi[];
   ArraySetAsSeries(rsi, true);
   if(CopyBuffer(g_rsi_m1_handle, 0, 1, 1, rsi) <= 0) return true;

   double v = rsi[0];

   if(RSI_Require_Extreme)
   {
      // Reversal mode: only trade at extremes
      if(required_dir == 1  && v > RSI_Oversold)   return false; // BUY only below oversold
      if(required_dir == -1 && v < RSI_Overbought) return false; // SELL only above overbought
   }
   else
   {
      // Normal mode: block overbought buys and oversold sells
      if(required_dir == 1  && v >= RSI_Overbought) return false;
      if(required_dir == -1 && v <= RSI_Oversold)   return false;
   }
   return true;
}

//+------------------------------------------------------------------+
//| V7: Bollinger Bands Filter                                       |
//+------------------------------------------------------------------+
bool CheckBollingerBands(int required_dir)
{
   if(!Use_BB_Filter) return true;
   if(g_bb_m1_handle == INVALID_HANDLE) return true;

   double upper[], lower[], mid[];
   ArraySetAsSeries(upper, true);
   ArraySetAsSeries(lower, true);
   ArraySetAsSeries(mid,   true);

   if(CopyBuffer(g_bb_m1_handle, 1, 1, 1, upper) <= 0) return true;
   if(CopyBuffer(g_bb_m1_handle, 2, 1, 1, lower) <= 0) return true;

   double ask = SymbolInfoDouble(g_symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(g_symbol, SYMBOL_BID);

   if(BB_Block_Outside)
   {
      // Block BUY if price is above upper band (overextended up)
      if(required_dir == 1  && ask > upper[0]) return false;
      // Block SELL if price is below lower band (overextended down)
      if(required_dir == -1 && bid < lower[0]) return false;
   }
   return true;
}

//+------------------------------------------------------------------+
//| V7: Calculate TP/SL prices with fixed points                     |
//+------------------------------------------------------------------+
double CalcTP(double entry_price, int dir)
{
   if(!Use_Fixed_TP_SL || TP_Points <= 0) return 0;
   double pt = SymbolInfoDouble(g_symbol, SYMBOL_POINT);
   return (dir == 1) ? entry_price + TP_Points * pt : entry_price - TP_Points * pt;
}

double CalcSL(double entry_price, int dir)
{
   if(!Use_Fixed_TP_SL || SL_Points <= 0) return 0;
   double pt = SymbolInfoDouble(g_symbol, SYMBOL_POINT);
   return (dir == 1) ? entry_price - SL_Points * pt : entry_price + SL_Points * pt;
}

//+------------------------------------------------------------------+
//| V7: Risk-based lot sizing                                        |
//+------------------------------------------------------------------+
double RiskBasedLot(double base_lot)
{
   if(Max_Risk_Per_Trade_Pct <= 0 || SL_Points <= 0) return base_lot;

   double balance   = AccountInfoDouble(ACCOUNT_BALANCE);
   double tick_val  = SymbolInfoDouble(g_symbol, SYMBOL_TRADE_TICK_VALUE);
   double tick_size = SymbolInfoDouble(g_symbol, SYMBOL_TRADE_TICK_SIZE);
   double pt        = SymbolInfoDouble(g_symbol, SYMBOL_POINT);

   if(tick_val <= 0 || tick_size <= 0 || pt <= 0) return base_lot;

   double risk_usd   = balance * (Max_Risk_Per_Trade_Pct / 100.0);
   double sl_value_per_lot = (SL_Points * pt / tick_size) * tick_val;
   if(sl_value_per_lot <= 0) return base_lot;

   double lot = risk_usd / sl_value_per_lot;
   double min_lot  = SymbolInfoDouble(g_symbol, SYMBOL_VOLUME_MIN);
   double max_lot  = SymbolInfoDouble(g_symbol, SYMBOL_VOLUME_MAX);
   double lot_step = SymbolInfoDouble(g_symbol, SYMBOL_VOLUME_STEP);

   lot = MathFloor(lot / lot_step) * lot_step;
   lot = MathMax(min_lot, MathMin(max_lot, lot));
   return NormalizeDouble(lot, 2);
}

//+------------------------------------------------------------------+
//| Tick Velocity Tracker                                            |
//+------------------------------------------------------------------+
void TrackTickVelocity()
{
   datetime now = TimeCurrent();
   g_tick_counter++;
   if(now != g_last_tick_time)
   {
      g_tick_velocity = g_tick_counter;
      g_tick_counter  = 0;
      g_last_tick_time = now;
   }
}

//+------------------------------------------------------------------+
//| FVG Microstructure Filter                                        |
//+------------------------------------------------------------------+
bool CheckFVGMicrostructure(int &fvg_direction)
{
   if(!Use_FVG_Filter) return true;

   double high3 = iHigh(g_symbol, PERIOD_M1, 3);
   double low1  = iLow(g_symbol,  PERIOD_M1, 1);
   double low3  = iLow(g_symbol,  PERIOD_M1, 3);
   double high1 = iHigh(g_symbol, PERIOD_M1, 1);
   double pt    = SymbolInfoDouble(g_symbol, SYMBOL_POINT);
   if(pt <= 0) return false;

   if((low1 - high3) / pt >= FVG_Min_Gap_Points) { fvg_direction =  1; return true; }
   if((low3 - high1) / pt >= FVG_Min_Gap_Points) { fvg_direction = -1; return true; }
   return false;
}

//+------------------------------------------------------------------+
//| MTF Trend Direction                                              |
//+------------------------------------------------------------------+
int TrendDir(ENUM_TIMEFRAMES tf)
{
   int hFast = INVALID_HANDLE, hSlow = INVALID_HANDLE;
   if(tf == PERIOD_M1)       { hFast = g_ma_fast_m1;  hSlow = g_ma_slow_m1; }
   else if(tf == PERIOD_M5)  { hFast = g_ma_fast_m5;  hSlow = g_ma_slow_m5; }
   else if(tf == PERIOD_M15) { hFast = g_ma_fast_m15; hSlow = g_ma_slow_m15; }
   else return 0;
   if(hFast == INVALID_HANDLE || hSlow == INVALID_HANDLE) return 0;

   double fast[], slow[];
   ArraySetAsSeries(fast, true); ArraySetAsSeries(slow, true);
   if(CopyBuffer(hFast, 0, 1, 1, fast) <= 0) return 0;
   if(CopyBuffer(hSlow, 0, 1, 1, slow) <= 0) return 0;
   if(fast[0] > slow[0]) return  1;
   if(fast[0] < slow[0]) return -1;
   return 0;
}

//+------------------------------------------------------------------+
//| ATR Points                                                       |
//+------------------------------------------------------------------+
double ATRPoints(ENUM_TIMEFRAMES tf)
{
   int handle = (tf == PERIOD_M1) ? g_atr_m1_handle : iATR(g_symbol, tf, 14);
   if(handle == INVALID_HANDLE) return 0.0;
   double buf[];
   ArraySetAsSeries(buf, true);
   int copied = CopyBuffer(handle, 0, 1, 1, buf);
   if(tf != PERIOD_M1) IndicatorRelease(handle);
   if(copied > 0) return buf[0] / SymbolInfoDouble(g_symbol, SYMBOL_POINT);
   return 0.0;
}

//+------------------------------------------------------------------+
//| Market Regime Engine                                             |
//+------------------------------------------------------------------+
void UpdateMarketRegime()
{
   if(!Use_Regime_AI) { g_regime = REGIME_SIDEWAY; return; }
   double atr = ATRPoints(PERIOD_M1);
   int m1dir  = TrendDir(PERIOD_M1);
   if(atr > 400)       g_regime = REGIME_CHAOTIC;
   else if(atr > 250)  g_regime = REGIME_VOLATILE;
   else if(m1dir == 1) g_regime = REGIME_TREND_UP;
   else if(m1dir ==-1) g_regime = REGIME_TREND_DOWN;
   else                g_regime = REGIME_SIDEWAY;
}

//+------------------------------------------------------------------+
//| Strategy Mode                                                    |
//+------------------------------------------------------------------+
void UpdateStrategyMode()
{
   double bal = AccountInfoDouble(ACCOUNT_BALANCE);
   double eq  = AccountInfoDouble(ACCOUNT_EQUITY);
   if(bal <= 0) return;
   double dd = ((bal - eq) / bal) * 100.0;
   if(dd >= Hedge_Trigger_DD_Pct) g_mode = MODE_HEDGE_DEFENSE;
   else if(dd >= 8.0)             g_mode = MODE_SAFE;
   else if(dd >= 3.0)             g_mode = MODE_TREND;
   else                           g_mode = MODE_SCALP;
}

//+------------------------------------------------------------------+
//| Entry Direction Builder (V7: includes RSI, BB, Session, News)   |
//+------------------------------------------------------------------+
int BuildDirection()
{
   // Session & News gate
   if(!IsSessionAllowed()) return 0;
   if(IsNewsBlackout())    return 0;

   // Block in chaotic/volatile regimes
   if(g_regime == REGIME_CHAOTIC)  return 0;

   int m1  = TrendDir(PERIOD_M1);
   int m5  = TrendDir(PERIOD_M5);
   int m15 = TrendDir(PERIOD_M15);

   int dir = 0;
   if(g_regime == REGIME_TREND_UP)   dir =  1;
   else if(g_regime == REGIME_TREND_DOWN) dir = -1;
   else
   {
      if(Use_FVG_Filter)
      {
         int fvg_dir = 0;
         if(!CheckFVGMicrostructure(fvg_dir)) return 0;
         if(fvg_dir != m1) return 0;
      }
      if(Use_MTF_Confirm && Block_Entry_On_MTF_Conflict)
      {
         if(Use_M5_Filter  && m5  != 0 && m1 != 0 && m5  != m1) return 0;
         if(Use_M15_Filter && m15 != 0 && m1 != 0 && m15 != m1) return 0;
      }
      dir = m1;
   }
   if(dir == 0) return 0;

   // V7 Filters
   if(!CheckRSI(dir))            return 0;
   if(!CheckBollingerBands(dir)) return 0;

   return dir;
}

//+------------------------------------------------------------------+
//| Proportional Target TP                                           |
//+------------------------------------------------------------------+
double AI2_CurrentTargetTP()
{
   if(Use_Proportional_TP)
   {
      double lots = TotalLots();
      if(lots <= 0) return Basket_TP_USD;
      return NormalizeDouble(TP_Base_Offset_USD + lots * TP_Multiplier_Per_Lot, 2);
   }
   return Basket_TP_USD;
}

//+------------------------------------------------------------------+
//| Basket Exit Monitor                                              |
//+------------------------------------------------------------------+
void TryExit()
{
   if(!g_exit_allow || !Use_Basket_TP) return;
   double target = AI2_CurrentTargetTP();
   if(BasketProfit() >= target)
   {
      Print("[V7 BASKET EXIT] Target hit: ", target, " USD");
      CloseAll();
   }
}

//+------------------------------------------------------------------+
//| Volatility Adaptive Trailing Exit                               |
//+------------------------------------------------------------------+
void TryExitEngine()
{
   if(!Use_Exit_Engine) return;
   if(CountPos() == 0) { g_highest_profit = 0.0; g_lowest_profit = 0.0; return; }

   double profit = BasketProfit();
   if(profit > g_highest_profit) g_highest_profit = profit;
   if(profit < g_lowest_profit)  g_lowest_profit  = profit;

   double atr_m1 = ATRPoints(PERIOD_M1);
   double vol_scale = (atr_m1 > 0) ? MathMax(0.4, MathMin(2.5, atr_m1 / 200.0)) : 1.0;
   double dyn_trail = Exit_Trail_USD * vol_scale;
   double dyn_lock  = Exit_Lock_USD  * vol_scale;

   if(Exit_BE_USD != 0 && profit <= Exit_BE_USD && g_highest_profit > dyn_lock * 0.5)
   {
      Print("[EXIT ENGINE] Soft BE intercept | P: ", profit);
      CloseAll(); return;
   }

   if(dyn_lock > 0 && g_highest_profit >= dyn_lock && profit <= g_highest_profit - dyn_trail)
   {
      Print("[EXIT ENGINE] Vol-scaled trail hit | Max: ", g_highest_profit, " Current: ", profit);
      CloseAll(); return;
   }

   if(Exit_Max_Time_Min > 0)
   {
      datetime oldest = 0;
      for(int i = PositionsTotal()-1; i >= 0; i--)
      {
         if(PositionGetSymbol(i)==g_symbol && PositionGetInteger(POSITION_MAGIC)==Magic_Number)
         {
            datetime ot = (datetime)PositionGetInteger(POSITION_TIME);
            if(oldest == 0 || ot < oldest) oldest = ot;
         }
      }
      if(oldest > 0 && (TimeCurrent()-oldest)/60 >= Exit_Max_Time_Min)
      {
         Print("[EXIT ENGINE] Duration cap. Force exit.");
         CloseAll();
      }
   }
}

//+------------------------------------------------------------------+
//| Entry Engine (V7: Fixed TP/SL + Risk Sizing)                    |
//+------------------------------------------------------------------+
void TryEntry()
{
   if(CountPos() > 0) return;
   int dir = BuildDirection();
   if(dir == 0) return;

   double lot = Base_Lot_Safe;
   if(Use_Multi_Mode_Lot)
   {
      if(g_mode == MODE_SCALP)      lot = Base_Lot_Safe;
      else if(g_mode == MODE_TREND) lot = Base_Lot_Attack;
      else if(g_mode == MODE_SAFE)  lot = Base_Lot_Safe;
   }
   // Risk-based sizing overrides if enabled
   lot = RiskBasedLot(lot);

   double ask = SymbolInfoDouble(g_symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(g_symbol, SYMBOL_BID);

   if(dir == 1)
   {
      double tp = CalcTP(ask, 1);
      double sl = CalcSL(ask, 1);
      trade.Buy(lot, g_symbol, ask, sl, tp, "YY V7 Buy");
   }
   else if(dir == -1)
   {
      double tp = CalcTP(bid, -1);
      double sl = CalcSL(bid, -1);
      trade.Sell(lot, g_symbol, bid, sl, tp, "YY V7 Sell");
   }
}

//+------------------------------------------------------------------+
//| DCA Engine (V7: with TP/SL on DCA orders)                       |
//+------------------------------------------------------------------+
void TryDCA()
{
   int levels = CountPos();
   if(levels <= 0 || levels >= Max_DCA_Levels) return;

   // V7: Block DCA in chaotic market
   if(g_regime == REGIME_CHAOTIC || g_regime == REGIME_VOLATILE) return;

   double last_price = 0, total_vol = 0;
   int    type = -1;

   for(int i = PositionsTotal()-1; i >= 0; i--)
   {
      if(PositionGetSymbol(i)==g_symbol && PositionGetInteger(POSITION_MAGIC)==Magic_Number)
      {
         last_price = PositionGetDouble(POSITION_PRICE_OPEN);
         type       = (int)PositionGetInteger(POSITION_TYPE);
         total_vol += PositionGetDouble(POSITION_VOLUME);
      }
   }

   double cur_price = (type==POSITION_TYPE_BUY) ? SymbolInfoDouble(g_symbol,SYMBOL_BID) : SymbolInfoDouble(g_symbol,SYMBOL_ASK);
   double pt        = SymbolInfoDouble(g_symbol, SYMBOL_POINT);
   if(pt <= 0) return;

   if(MathAbs(cur_price - last_price)/pt < DCA_Spacing_Points) return;

   double next_lot = NormalizeDouble(MathMin(total_vol * Martingale_Multiplier, 5.0), 2);

   if(type==POSITION_TYPE_BUY && cur_price < last_price)
   {
      double ask = SymbolInfoDouble(g_symbol, SYMBOL_ASK);
      trade.Buy(next_lot,  g_symbol, ask, CalcSL(ask, 1),  CalcTP(ask, 1),  "YY V7 DCA Buy");
   }
   else if(type==POSITION_TYPE_SELL && cur_price > last_price)
   {
      double bid = SymbolInfoDouble(g_symbol, SYMBOL_BID);
      trade.Sell(next_lot, g_symbol, bid, CalcSL(bid,-1), CalcTP(bid,-1), "YY V7 DCA Sell");
   }
}

//+------------------------------------------------------------------+
//| Smart Unwind                                                     |
//+------------------------------------------------------------------+
void TrySmartUnwind()
{
   if(CountPos() < 4) return;
   if(BasketProfit() > 2.0)
   {
      ulong worst = 0; double wloss = 0;
      for(int i = PositionsTotal()-1; i >= 0; i--)
      {
         if(PositionGetSymbol(i)==g_symbol && PositionGetInteger(POSITION_MAGIC)==Magic_Number)
         {
            double pft = PositionGetDouble(POSITION_PROFIT);
            if(pft < wloss) { wloss = pft; worst = PositionGetInteger(POSITION_TICKET); }
         }
      }
      if(worst > 0) { Print("[SMART UNWIND] Trimming worst outlier."); trade.PositionClose(worst); }
   }
}

//+------------------------------------------------------------------+
//| Hedge Module                                                     |
//+------------------------------------------------------------------+
void TryHedge()
{
   if(g_mode != MODE_HEDGE_DEFENSE) return;
   double buy_lots=0, sell_lots=0; int buy_c=0, sell_c=0;
   for(int i = PositionsTotal()-1; i >= 0; i--)
   {
      if(PositionGetSymbol(i)==g_symbol && PositionGetInteger(POSITION_MAGIC)==Magic_Number)
      {
         int t = (int)PositionGetInteger(POSITION_TYPE);
         if(t==POSITION_TYPE_BUY)  { buy_c++;  buy_lots  += PositionGetDouble(POSITION_VOLUME); }
         if(t==POSITION_TYPE_SELL) { sell_c++; sell_lots += PositionGetDouble(POSITION_VOLUME); }
      }
   }
   if(buy_lots > sell_lots && sell_c==0)
      trade.Sell(NormalizeDouble(buy_lots-sell_lots,2), g_symbol, SymbolInfoDouble(g_symbol,SYMBOL_BID), 0, 0, "YY V7 Hedge Sell");
   else if(sell_lots > buy_lots && buy_c==0)
      trade.Buy(NormalizeDouble(sell_lots-buy_lots,2),  g_symbol, SymbolInfoDouble(g_symbol,SYMBOL_ASK), 0, 0, "YY V7 Hedge Buy");
}

//+------------------------------------------------------------------+
//| Accounting Helpers                                               |
//+------------------------------------------------------------------+
double BasketProfit()
{
   double tot = 0;
   for(int i = PositionsTotal()-1; i >= 0; i--)
      if(PositionGetSymbol(i)==g_symbol && PositionGetInteger(POSITION_MAGIC)==Magic_Number)
         tot += PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);
   return tot;
}
double TotalLots()
{
   double tot = 0;
   for(int i = PositionsTotal()-1; i >= 0; i--)
      if(PositionGetSymbol(i)==g_symbol && PositionGetInteger(POSITION_MAGIC)==Magic_Number)
         tot += PositionGetDouble(POSITION_VOLUME);
   return tot;
}
int CountPos()
{
   int c = 0;
   for(int i = PositionsTotal()-1; i >= 0; i--)
      if(PositionGetSymbol(i)==g_symbol && PositionGetInteger(POSITION_MAGIC)==Magic_Number) c++;
   return c;
}
void CloseAll()
{
   for(int i = PositionsTotal()-1; i >= 0; i--)
      if(PositionGetSymbol(i)==g_symbol && PositionGetInteger(POSITION_MAGIC)==Magic_Number)
         trade.PositionClose(PositionGetInteger(POSITION_TICKET));
   g_highest_profit = 0.0;
   g_lowest_profit  = 0.0;
}

//+------------------------------------------------------------------+
//| UI Helpers                                                       |
//+------------------------------------------------------------------+
void UI_CreateLabel(string name, string text, int x, int y, color clr, int fs=10, string font="Trebuchet MS")
{
   if(ObjectFind(0,name)<0)
   {
      ObjectCreate(0,name,OBJ_LABEL,0,0,0);
      ObjectSetInteger(0,name,OBJPROP_XDISTANCE,x);
      ObjectSetInteger(0,name,OBJPROP_YDISTANCE,y);
      ObjectSetInteger(0,name,OBJPROP_CORNER,CORNER_LEFT_UPPER);
      ObjectSetInteger(0,name,OBJPROP_ANCHOR,ANCHOR_LEFT_UPPER);
      ObjectSetString(0,name,OBJPROP_FONT,font);
      ObjectSetInteger(0,name,OBJPROP_FONTSIZE,fs);
      ObjectSetInteger(0,name,OBJPROP_BACK,false);
      ObjectSetInteger(0,name,OBJPROP_SELECTABLE,false);
      ObjectSetInteger(0,name,OBJPROP_HIDDEN,true);
   }
   ObjectSetString(0,name,OBJPROP_TEXT,text);
   ObjectSetInteger(0,name,OBJPROP_COLOR,clr);
}
void UI_CreatePanel(string name, int x, int y, int w, int h, color bg, color border)
{
   if(ObjectFind(0,name)<0)
   {
      ObjectCreate(0,name,OBJ_RECTANGLE_LABEL,0,0,0);
      ObjectSetInteger(0,name,OBJPROP_XDISTANCE,x);
      ObjectSetInteger(0,name,OBJPROP_YDISTANCE,y);
      ObjectSetInteger(0,name,OBJPROP_CORNER,CORNER_LEFT_UPPER);
      ObjectSetInteger(0,name,OBJPROP_BGCOLOR,bg);
      ObjectSetInteger(0,name,OBJPROP_COLOR,border);
      ObjectSetInteger(0,name,OBJPROP_BORDER_TYPE,BORDER_FLAT);
      ObjectSetInteger(0,name,OBJPROP_BACK,true);
      ObjectSetInteger(0,name,OBJPROP_SELECTABLE,false);
      ObjectSetInteger(0,name,OBJPROP_HIDDEN,true);
   }
   ObjectSetInteger(0,name,OBJPROP_XSIZE,w);
   ObjectSetInteger(0,name,OBJPROP_YSIZE,h);
}

//+------------------------------------------------------------------+
//| Dashboard (V7: Expanded with all new info rows)                  |
//+------------------------------------------------------------------+
void AI2_MaxProDashboard()
{
   string regimeText = "UNKNOWN";
   if(g_regime==REGIME_TREND_UP)   regimeText = "TREND UP";
   if(g_regime==REGIME_TREND_DOWN) regimeText = "TREND DOWN";
   if(g_regime==REGIME_SIDEWAY)    regimeText = "SIDEWAY BALANCE";
   if(g_regime==REGIME_VOLATILE)   regimeText = "HIGH VOLATILITY";
   if(g_regime==REGIME_CHAOTIC)    regimeText = "CHAOTIC - BLOCKED";

   string modeText = "SCALP ENGINE";
   if(g_mode==MODE_TREND)         modeText = "TREND ENGAGED";
   if(g_mode==MODE_SAFE)          modeText = "PRESERVATION SAFE";
   if(g_mode==MODE_HEDGE_DEFENSE) modeText = "INSULATION HEDGE";

   double pnl     = BasketProfit();
   color  pnlClr  = (pnl>0) ? clrLimeGreen : (pnl<0) ? clrRed : clrGray;

   // RSI value
   double rsi_val = 0;
   if(g_rsi_m1_handle != INVALID_HANDLE)
   {
      double rsi_buf[]; ArraySetAsSeries(rsi_buf,true);
      if(CopyBuffer(g_rsi_m1_handle,0,1,1,rsi_buf)>0) rsi_val = rsi_buf[0];
   }
   color rsiClr = (rsi_val>=RSI_Overbought) ? clrRed : (rsi_val<=RSI_Oversold) ? clrLimeGreen : clrWhite;

   string sessionStr = IsSessionAllowed() ? "ACTIVE" : "CLOSED";
   color  sessionClr = IsSessionAllowed() ? clrLimeGreen : clrOrangeRed;
   string newsStr    = IsNewsBlackout()   ? "BLACKOUT" : "CLEAR";
   color  newsClr    = IsNewsBlackout()   ? clrRed : clrLimeGreen;
   string haltStr    = g_trading_halted   ? "HALTED - DAILY LIMIT" : "RUNNING";
   color  haltClr    = g_trading_halted   ? clrRed : clrLimeGreen;

   // Layout
   int startX=20, startY=20, pW=360, pH=330;
   int textX=startX+12, valX=startX+235, Y=startY+15;

   UI_CreatePanel("YY_Dash_BG", startX, startY, pW, pH, clrBlack, clrDimGray);

   UI_CreateLabel("YY_Dash_Title","YY AI L2 MAXPRO V7  |  XAUUSD M1", textX, Y, clrCyan, 11, "Arial Bold"); Y+=28;
   UI_CreateLabel("YY_Dash_Status_L","EA Status:", textX, Y, clrLightGray); UI_CreateLabel("YY_Dash_Status_V", haltStr, valX, Y, haltClr); Y+=20;
   UI_CreateLabel("YY_Dash_L1","Market Regime:", textX, Y, clrLightGray); UI_CreateLabel("YY_Dash_V1", regimeText, valX, Y, clrGold); Y+=20;
   UI_CreateLabel("YY_Dash_L2","Logic Mode:", textX, Y, clrLightGray); UI_CreateLabel("YY_Dash_V2", modeText, valX, Y, clrGold); Y+=20;
   UI_CreateLabel("YY_Dash_Session_L","Session:", textX, Y, clrLightGray); UI_CreateLabel("YY_Dash_Session_V", sessionStr, valX, Y, sessionClr); Y+=20;
   UI_CreateLabel("YY_Dash_News_L","News Filter:", textX, Y, clrLightGray); UI_CreateLabel("YY_Dash_News_V", newsStr, valX, Y, newsClr); Y+=20;
   UI_CreateLabel("YY_Dash_RSI_L","RSI (M1):", textX, Y, clrLightGray); UI_CreateLabel("YY_Dash_RSI_V", DoubleToString(rsi_val,1), valX, Y, rsiClr); Y+=20;
   UI_CreateLabel("YY_Dash_L3","Tick Velocity:", textX, Y, clrLightGray); UI_CreateLabel("YY_Dash_V3", DoubleToString(g_tick_velocity,0)+" t/s", valX, Y, clrWhite); Y+=20;
   UI_CreateLabel("YY_Dash_L4","Open Levels:", textX, Y, clrLightGray); UI_CreateLabel("YY_Dash_V4", IntegerToString(CountPos())+"/"+IntegerToString(Max_DCA_Levels), valX, Y, clrWhite); Y+=20;
   UI_CreateLabel("YY_Dash_L5","Total Lots:", textX, Y, clrLightGray); UI_CreateLabel("YY_Dash_V5", DoubleToString(TotalLots(),2), valX, Y, clrWhite); Y+=20;
   UI_CreateLabel("YY_Dash_L6","Basket PnL:", textX, Y, clrLightGray); UI_CreateLabel("YY_Dash_V6", DoubleToString(pnl,2)+" USD", valX, Y, pnlClr); Y+=20;
   UI_CreateLabel("YY_Dash_L7","Basket TP Target:", textX, Y, clrLightGray); UI_CreateLabel("YY_Dash_V7", DoubleToString(AI2_CurrentTargetTP(),2)+" USD", valX, Y, clrDeepSkyBlue); Y+=20;
   UI_CreateLabel("YY_Dash_L7b","Basket SL:", textX, Y, clrLightGray); UI_CreateLabel("YY_Dash_V7b", DoubleToString(Basket_SL_USD,2)+" USD", valX, Y, clrOrangeRed); Y+=20;
   UI_CreateLabel("YY_Dash_L8","Trail Peak:", textX, Y, clrLightGray); UI_CreateLabel("YY_Dash_V8", DoubleToString(g_highest_profit,2)+" USD", valX, Y, clrMediumAquamarine); Y+=20;
   UI_CreateLabel("YY_Dash_TP_L","Fixed TP pts:", textX, Y, clrLightGray); UI_CreateLabel("YY_Dash_TP_V", DoubleToString(TP_Points,0)+" pts", valX, Y, clrDeepSkyBlue); Y+=20;
   UI_CreateLabel("YY_Dash_SL_L","Fixed SL pts:", textX, Y, clrLightGray); UI_CreateLabel("YY_Dash_SL_V", DoubleToString(SL_Points,0)+" pts", valX, Y, clrOrangeRed);

   ChartRedraw(0);
}
//+------------------------------------------------------------------+
