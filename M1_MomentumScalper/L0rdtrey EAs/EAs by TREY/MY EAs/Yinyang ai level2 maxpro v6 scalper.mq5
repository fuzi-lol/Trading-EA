 //+------------------------------------------------------------------+
//| YinYang_AI_Level2_MAXPRO_V6_SCALPER.mq5                         |
//| Enhanced: FVG Microstructure + Dynamic Exit + 7-Trade Scalper   |
//| Version: 6.00 - BULK SCALPER + FVG FILTER + DYNAMIC EXIT        |
//| Based on V5_COMPLETE by original author                         |
//| Enhancements: Microstructure (FVG/OB), Dynamic Exit Engine,     |
//|               Bulk 7-Trade Scalper with lot-scaled profit locks  |
//+------------------------------------------------------------------+
#property strict
#property version "6.00"

//+------------------------------------------------------------------+
//| ENUMS                                                            |
//+------------------------------------------------------------------+
enum AI2_REGIME { REGIME_UNKNOWN=0, REGIME_TREND_UP, REGIME_TREND_DOWN, REGIME_SIDEWAY, REGIME_VOLATILE, REGIME_CHAOTIC };
enum AI2_MODE   { MODE_PAUSE=0, MODE_SCALP, MODE_TREND, MODE_SAFE, MODE_HEDGE_DEFENSE };
enum AI2_RISK   { RISK_SAFE=0, RISK_WARNING, RISK_DANGER, RISK_EMERGENCY };
enum AI2_ATTACK_MODE { ATTACK_SAFE=0, ATTACK_ACTIVE, ATTACK_RECOVERY };

//+------------------------------------------------------------------+
//| INPUT GROUPS                                                     |
//+------------------------------------------------------------------+

// ===== AI LEVEL 2 MASTER =====
input bool Use_AI_Level2              = true;
input bool Use_Regime_AI              = true;
input bool Use_MTF_Confirm            = true;
input bool Use_Auto_Strategy_Switch   = true;
input bool Use_Adaptive_Lot           = true;
input bool Use_Adaptive_DCA           = true;
input bool Use_Smart_Hedge            = true;
input bool Use_ReHedge_AI             = true;
input bool Use_Dynamic_BasketTP       = true;
input bool Use_Risk_Engine_PRO        = true;
input bool Use_Smart_Pause_PRO        = true;
input bool SmartPause_Block_Entry     = true;
input bool SmartPause_Block_DCA       = true;
input bool SmartPause_Allow_Hedge     = true;
input bool SmartPause_Allow_ReHedge   = true;
input bool SmartPause_Bypass_HedgeSpacing_On_Danger = true;
input double SmartPause_Min_DD_For_Hedge_Percent = 1.5;

// ===== DASHBOARD =====
input bool Use_Dashboard_AI           = true;
input bool Use_FinalElite_Dashboard   = true;
input bool Use_FitScreen_Dashboard    = true;
input bool Use_BigSignal_Color        = true;
input int  Dashboard_X                = 12;
input int  Dashboard_Y                = 18;
input int  Dashboard_Width            = 460;
input int  Dashboard_FontSize         = 9;
input bool Show_ReHedge_Status_Dashboard = true;
input bool Dashboard_Show_ReHedge_Separate = true;
input bool Dashboard_AutoHide_ReHedge_Panel = true;
input int  Dashboard_ReHedge_Panel_X  = 485;
input int  Dashboard_ReHedge_Panel_Y  = 18;

// ===== DASHBOARD COLORS =====
color clrGood   = clrLime;
color clrWarn   = clrYellow;
color clrBad    = clrRed;
color clrTitle  = clrGold;
color clrText   = clrWhite;
color clrInfo   = clrAqua;
color clrPanel  = clrBlack;
color clrPanel2 = C'48,48,48';
color clrScalper= C'0,180,255';

// ===== CORE =====
input string Trade_Symbol             = "";
input long   Magic_Number             = 26042822;
input bool   One_Order_Per_Bar        = false;   // Disabled for scalper
input int    Min_Seconds_Between_Orders = 5;     // Faster for scalper
input int    Slippage_Points          = 50;
input int    Max_Spread_Points        = 350;

// ===== REGIME AI =====
input ENUM_TIMEFRAMES Regime_TF_Main   = PERIOD_M5;
input ENUM_TIMEFRAMES Regime_TF_Confirm= PERIOD_M15;
input int    ATR_Period               = 14;
input int    EMA_Fast_Period          = 20;
input int    EMA_Slow_Period          = 50;
input double Sideway_ATR_Max_Points   = 180;
input double Volatile_ATR_Min_Points  = 450;
input double Chaotic_ATR_Min_Points   = 700;

// ===== MTF CONFIRM =====
input bool Use_M1_Signal              = true;
input bool Use_M5_Filter              = true;
input bool Use_M15_Filter             = true;
input bool Block_Entry_On_MTF_Conflict = true;

// ===== FVG MICROSTRUCTURE FILTER (NEW V6) =====
input bool   Use_FVG_Filter           = true;   // Fair Value Gap filter
input bool   Use_OB_Filter            = false;  // Order Block filter (optional)
input int    FVG_Lookback_Bars        = 20;     // Bars to scan for FVG
input double FVG_Min_Size_Points      = 30;     // Min FVG size in points
input double FVG_Max_Size_Points      = 300;    // Max FVG size (avoid noise)
input bool   FVG_Require_Retest       = true;   // Price must revisit FVG edge
input bool   FVG_Entry_On_Mitigation  = true;   // Enter when price fills FVG
input int    OB_Lookback_Bars         = 30;     // Bars to scan for Order Blocks
input double OB_Min_Body_Points       = 50;     // Min candle body for valid OB

// ===== BULK SCALPER ENGINE (NEW V6) =====
input bool   Use_Bulk_Scalper         = true;   // Enable 7-trade bulk scalper
input int    Scalper_Max_Trades       = 7;      // Number of simultaneous scalp trades
input double Scalper_Base_Lot         = 0.01;   // Starting lot for scalper
input double Scalper_Lot_Multiplier   = 1.5;    // Lot growth per scalper tier
input bool   Scalper_Use_Tiered_TP    = true;   // Lot-scaled profit targets
// Tiered profit targets: profit threshold scales with lot size
// Rule: TP_USD = Scalper_TP_Per_01_Lot * (lot / 0.01)
// e.g. lot=0.01 -> TP=$1, lot=0.10 -> TP=$10, lot=1.00 -> TP=$100
input double Scalper_TP_Per_01_Lot    = 1.0;    // $1 per 0.01 lot (scales proportionally)
input double Scalper_Max_Loss_USD     = -5.0;   // Emergency close per scalp trade
input int    Scalper_Reopen_Delay_Sec = 3;      // Seconds before reopening after close
input bool   Scalper_Trail_After_TP   = true;   // Trail instead of hard close at TP
input double Scalper_Trail_Buffer_USD = 0.30;   // Trail pullback before close
input bool   Scalper_Use_FVG_Entry    = true;   // Scalper uses FVG for entry
input int    Scalper_Magic_Base       = 26042900; // Base magic for scalper (each trade +i)

// ===== LOT CONTROL (BASE / MAIN EA) =====
input double Base_Lot                 = 0.03;
input double Min_Lot                  = 0.01;
input double Max_Lot                  = 0.30;
input double DD_Reduce_Lot_At_Percent = 3.0;
input double Lot_Reduce_Factor        = 0.50;
input double Volatility_Lot_Reduce    = 0.50;

// ===== MULTI-MODE LOT CONTROL =====
input bool   Use_Multi_Mode_Lot       = true;
input double Safe_Base_Lot            = 0.02;
input int    Safe_Max_DCA             = 5;
input double Safe_Multiplier          = 1.25;
input double Safe_Hedge_Ratio         = 0.5;
input double Attack_Base_Lot          = 0.03;
input int    Attack_Max_DCA           = 4;
input double Attack_Multiplier        = 1.35;
input double Attack_Hedge_Ratio       = 0.3;
input double Recovery_Base_Lot        = 0.015;
input int    Recovery_Max_DCA         = 6;
input double Recovery_Multiplier      = 1.2;
input double Recovery_Hedge_Ratio     = 0.7;

// ===== MODE SWITCH CONDITIONS =====
input double Switch_To_Attack_ATR              = 1.2;
input double Switch_To_Attack_Trend_Strength   = 0.7;
input double Switch_To_Recovery_DD_Percent     = 3.0;
input double Switch_To_Recovery_Loss_USD       = 100.0;
input double Switch_Back_To_Safe_DD_Percent    = 1.0;

// ===== DCA SYSTEM =====
input int    Max_DCA_Levels           = 6;
input double Lot_Multiplier           = 1.35;
input int    Min_DCA_Step_Points      = 180;
input int    Max_DCA_Step_Points      = 650;
input double ATR_DCA_Multiplier       = 1.20;
input bool   Stop_DCA_When_Hedged     = true;
input bool   Stop_DCA_When_Trend_Against = true;
input bool   Block_DCA_In_Chaotic     = true;

// ===== HEDGE SYSTEM =====
input bool   Use_Hedge                = true;
input double Hedge_Trigger_DD_USD     = -25.0;
input double Hedge_Trigger_DD_Percent = 2.5;
input int    Hedge_Start_Level        = 2;
input double Hedge_Ratio              = 0.80;
input double Hedge_Ratio_Max          = 1.00;
input bool   Only_One_Hedge_Per_Direction = true;
input bool   Close_Hedge_First        = true;
input bool   Use_Hedge_Spacing_PRO    = true;
input int    Hedge_Min_Distance_From_Last_DCA = 150;
input int    Hedge_Delay_After_Last_Order_Sec = 30;
input bool   Hedge_Require_Momentum   = true;
input int    Hedge_Momentum_ATR_Period = 14;
input double Hedge_Momentum_Candle_ATR_Ratio = 0.60;
input bool   Hedge_Allow_If_DD_Emergency = true;

// ===== REHEDGE SYSTEM =====
input bool   Use_ReHedge              = true;
input int    ReHedge_Step_Points      = 150;
input int    ReHedge_Cooldown_Min     = 10;
input double ReHedge_Ratio            = 0.35;

// ===== SMART UNWIND =====
input bool   Use_Smart_Unwind_PRO     = true;
input double Unwind_Min_Profit_USD    = 3.0;
input double Unwind_Close_Percent     = 30.0;
input int    Unwind_Min_Orders        = 4;
input int    Unwind_Cooldown_Sec      = 20;

// ===== TP SYSTEM =====
input double Basket_TP_Normal_USD     = 25.0;
input double Basket_TP_Hedge_Mode_USD = 8.0;
input double Partial_Close_Profit_USD = 15.0;
input bool   Use_Partial_Close        = true;
input bool   Use_TP1_PRO_AI           = true;
input double TP1_Profit_USD           = 6.0;
input double TP1_Close_Percent        = 50.0;
input bool   TP1_Only_First_Order     = true;
input bool   TP1_Disable_When_Hedged  = true;
input bool   TP1_Only_Once_Per_Cycle  = true;
input int    TP1_Min_Seconds_After_Entry = 30;

// ===== DYNAMIC EXIT ENGINE V6 (Replaces static V5) =====
input bool   Use_Exit_Engine          = true;
// --- Volatility-adaptive breakeven ---
input bool   Exit_Use_ATR_BE          = true;   // Scale BE threshold by ATR
input double Exit_BE_ATR_Multiplier   = 0.5;    // BE = ATR * multiplier (negative)
input double Exit_BE_USD_Min          = -1.0;   // Minimum BE threshold (floor)
input double Exit_BE_USD_Max          = -8.0;   // Maximum BE threshold (cap, negative)
// --- Dynamic lock profit ---
input bool   Exit_Use_ATR_Lock        = true;   // Scale lock by ATR
input double Exit_Lock_ATR_Multiplier = 2.0;    // Lock = ATR * mult
input double Exit_Lock_USD_Min        = 5.0;    // Minimum lock threshold
input double Exit_Lock_USD_Max        = 40.0;   // Maximum lock threshold
// --- Dynamic trail ---
input bool   Exit_Use_ATR_Trail       = true;   // Scale trail by ATR
input double Exit_Trail_ATR_Multiplier= 0.8;    // Trail = ATR * mult
input double Exit_Trail_USD_Min       = 2.0;
input double Exit_Trail_USD_Max       = 15.0;
// --- Volatility burst exit ---
input bool   Exit_Close_On_ATR_Spike  = true;   // Close if ATR spikes (chaos)
input double Exit_ATR_Spike_Ratio     = 2.5;    // Spike = current ATR > avg ATR * ratio
input int    Exit_ATR_Avg_Period      = 20;     // Bars for ATR average
// --- Time-based (adaptive) ---
input bool   Exit_Use_Time_Limit      = true;
input int    Exit_Max_Time_Min_Trend  = 60;     // Longer hold in trend
input int    Exit_Max_Time_Min_Scalp  = 25;     // Shorter hold in scalp/sideway
input int    Exit_Max_Time_Min_Hedge  = 120;    // Much longer allowed in hedge defense

// ===== RISK ENGINE =====
input double Max_Equity_DD_Stop_Percent = 12.0;
input double Daily_Loss_Limit_Percent   = 5.0;
input double Emergency_Close_DD_Percent = 15.0;
input int    Cooldown_After_Cycle_Sec   = 60;
input int    Max_Total_Orders           = 20;   // Increased for scalper (12 main + 8 scalper)
input double Max_Total_Lot              = 2.00; // Increased for scalper

// ===== SESSION / NEWS TIME BLOCK =====
input bool Use_Time_Filter             = false;
input int  Trade_Start_Hour            = 7;
input int  Trade_End_Hour              = 23;
input bool Use_News_Time_Block         = true;
input int  News_Block_Start_Hour       = 19;
input int  News_Block_End_Hour         = 21;

//+------------------------------------------------------------------+
//| GLOBAL VARIABLES                                                 |
//+------------------------------------------------------------------+
string g_symbol;
AI2_REGIME    g_regime      = REGIME_UNKNOWN;
AI2_MODE      g_mode        = MODE_PAUSE;
AI2_RISK      g_risk        = RISK_SAFE;
AI2_ATTACK_MODE g_attack_mode = ATTACK_SAFE;

bool g_entry_allow=false, g_dca_allow=false, g_hedge_allow=false, g_exit_allow=false;
int  g_direction=0;
datetime g_last_order_time=0, g_last_bar_time=0, g_last_cycle_close_time=0, g_last_rehedge_time=0;
bool g_tp1_done=false;
ulong g_tp1_first_ticket=0;
datetime g_tp1_cycle_start_time=0;
double g_start_day_equity=0;
int    g_day_of_year=-1;
datetime g_last_unwind_time = 0;

// Exit engine state
double g_highest_profit  = 0;
double g_lowest_profit   = 0;
double g_atr_avg_cache   = 0;
datetime g_atr_avg_last_calc = 0;

// FVG state (refreshed per tick)
double g_fvg_bull_lo = 0;   // Bullish FVG lower edge
double g_fvg_bull_hi = 0;   // Bullish FVG upper edge
double g_fvg_bear_lo = 0;   // Bearish FVG lower edge
double g_fvg_bear_hi = 0;   // Bearish FVG upper edge
bool   g_fvg_bull_valid = false;
bool   g_fvg_bear_valid = false;
bool   g_ob_bull_valid  = false;
bool   g_ob_bear_valid  = false;
double g_ob_bull_lo = 0, g_ob_bull_hi = 0;
double g_ob_bear_lo = 0, g_ob_bear_hi = 0;

// Scalper state — tracks each of the 7 scalper slots
struct ScalperSlot
{
   ulong  ticket;         // Active ticket (0 = empty slot)
   double lot;            // Lot size for this slot
   double tp_usd;         // Profit target for this slot
   double peak_profit;    // Highest profit seen for trailing
   bool   trailing_armed; // True once profit >= tp_usd once
   datetime last_close;   // Time of last close on this slot
   int    direction;      // 1=buy, -1=sell
};
ScalperSlot g_scalper[7];

// Indicator handles (cached at init — fixes V5 per-tick handle bug)
int h_atr_m1 = INVALID_HANDLE;
int h_atr_m5 = INVALID_HANDLE;
int h_ema_fast_m5 = INVALID_HANDLE;
int h_ema_slow_m5 = INVALID_HANDLE;
int h_ema_fast_m15= INVALID_HANDLE;
int h_ema_slow_m15= INVALID_HANDLE;
int h_ema_fast_m1 = INVALID_HANDLE;
int h_ema_slow_m1 = INVALID_HANDLE;
int h_atr_m1_long = INVALID_HANDLE; // For ATR average (exit spike detection)

//+------------------------------------------------------------------+
//| 1. HELPER FUNCTIONS                                              |
//+------------------------------------------------------------------+
string RegimeText(){ if(g_regime==REGIME_TREND_UP) return "TREND_UP"; if(g_regime==REGIME_TREND_DOWN) return "TREND_DOWN"; if(g_regime==REGIME_SIDEWAY) return "SIDEWAY"; if(g_regime==REGIME_VOLATILE) return "VOLATILE"; if(g_regime==REGIME_CHAOTIC) return "CHAOTIC"; return "UNKNOWN"; }
string ModeText(){ if(g_mode==MODE_SCALP) return "SCALP"; if(g_mode==MODE_TREND) return "TREND"; if(g_mode==MODE_SAFE) return "SAFE"; if(g_mode==MODE_HEDGE_DEFENSE) return "HEDGE_DEFENSE"; return "PAUSE"; }
string RiskText(){ if(g_risk==RISK_WARNING) return "WARNING"; if(g_risk==RISK_DANGER) return "DANGER"; if(g_risk==RISK_EMERGENCY) return "EMERGENCY"; return "SAFE"; }
string AttackModeText(){ if(g_attack_mode==ATTACK_ACTIVE) return "ATTACK"; if(g_attack_mode==ATTACK_RECOVERY) return "RECOVERY"; return "SAFE"; }

// --- Indicator value from cached handle ---
double IndValH(int h, int buf, int shift)
{
   if(h==INVALID_HANDLE) return 0;
   double a[];
   ArraySetAsSeries(a,true);
   if(CopyBuffer(h,buf,shift,1,a)<=0) return 0;
   return a[0];
}

double ATRPoints(ENUM_TIMEFRAMES tf)
{
   int h = (tf==PERIOD_M1 ? h_atr_m1 : h_atr_m5);
   double v = IndValH(h,0,0);
   double p = SymbolInfoDouble(g_symbol,SYMBOL_POINT);
   return (p>0 ? v/p : 0);
}

double ATRValue(ENUM_TIMEFRAMES tf)
{
   int h = (tf==PERIOD_M1 ? h_atr_m1 : h_atr_m5);
   return IndValH(h,0,0);
}

double EMAVal(ENUM_TIMEFRAMES tf, bool fast)
{
   int h;
   if(tf==PERIOD_M5)  h = (fast ? h_ema_fast_m5  : h_ema_slow_m5);
   else if(tf==PERIOD_M15) h = (fast ? h_ema_fast_m15 : h_ema_slow_m15);
   else                h = (fast ? h_ema_fast_m1  : h_ema_slow_m1);
   return IndValH(h,0,0);
}

int TrendDir(ENUM_TIMEFRAMES tf)
{
   double f=EMAVal(tf,true), s=EMAVal(tf,false);
   double p=SymbolInfoDouble(g_symbol,SYMBOL_POINT);
   if(f<=0||s<=0||p<=0) return 0;
   if(MathAbs(f-s)/p<50) return 0;
   return (f>s?1:-1);
}

int SpreadPoints(){ double p=SymbolInfoDouble(g_symbol,SYMBOL_POINT); if(p<=0) return 999999; return (int)MathRound((SymbolInfoDouble(g_symbol,SYMBOL_ASK)-SymbolInfoDouble(g_symbol,SYMBOL_BID))/p); }
double DDPercent(){ double b=AccountInfoDouble(ACCOUNT_BALANCE), e=AccountInfoDouble(ACCOUNT_EQUITY); if(b<=0) return 0; return MathMax(0,(b-e)/b*100); }
double DailyLossPercent(){ MqlDateTime t; TimeToStruct(TimeCurrent(),t); if(g_day_of_year!=t.day_of_year || g_start_day_equity<=0){ g_day_of_year=t.day_of_year; g_start_day_equity=AccountInfoDouble(ACCOUNT_EQUITY);} double e=AccountInfoDouble(ACCOUNT_EQUITY); return (g_start_day_equity>0 ? MathMax(0,(g_start_day_equity-e)/g_start_day_equity*100) : 0); }
bool TradingHour(){ if(!Use_Time_Filter) return true; MqlDateTime t; TimeToStruct(TimeCurrent(),t); if(Trade_Start_Hour<=Trade_End_Hour) return (t.hour>=Trade_Start_Hour && t.hour<Trade_End_Hour); return (t.hour>=Trade_Start_Hour || t.hour<Trade_End_Hour); }
bool NewsBlocked(){ if(!Use_News_Time_Block) return false; MqlDateTime t; TimeToStruct(TimeCurrent(),t); if(News_Block_Start_Hour<=News_Block_End_Hour) return (t.hour>=News_Block_Start_Hour && t.hour<News_Block_End_Hour); return (t.hour>=News_Block_Start_Hour || t.hour<News_Block_End_Hour); }
bool IsOurPos(long magic=-1){ long m=(magic<0?Magic_Number:magic); return PositionGetString(POSITION_SYMBOL)==g_symbol && (long)PositionGetInteger(POSITION_MAGIC)==m; }

int CountPos(int dir=0, long magic=-1)
{
   long m=(magic<0?Magic_Number:magic);
   int c=0;
   for(int i=PositionsTotal()-1;i>=0;i--)
   {
      ulong tk=PositionGetTicket(i);
      if(tk==0||!PositionSelectByTicket(tk)) continue;
      if(PositionGetString(POSITION_SYMBOL)!=g_symbol || (long)PositionGetInteger(POSITION_MAGIC)!=m) continue;
      long type=PositionGetInteger(POSITION_TYPE);
      if(dir==1&&type!=POSITION_TYPE_BUY) continue;
      if(dir==-1&&type!=POSITION_TYPE_SELL) continue;
      c++;
   }
   return c;
}

double TotalLots(int dir=0, long magic=-1)
{
   long m=(magic<0?Magic_Number:magic);
   double l=0;
   for(int i=PositionsTotal()-1;i>=0;i--)
   {
      ulong tk=PositionGetTicket(i);
      if(tk==0||!PositionSelectByTicket(tk)) continue;
      if(PositionGetString(POSITION_SYMBOL)!=g_symbol || (long)PositionGetInteger(POSITION_MAGIC)!=m) continue;
      long type=PositionGetInteger(POSITION_TYPE);
      if(dir==1&&type!=POSITION_TYPE_BUY) continue;
      if(dir==-1&&type!=POSITION_TYPE_SELL) continue;
      l+=PositionGetDouble(POSITION_VOLUME);
   }
   return l;
}

double BasketProfit(long magic=-1)
{
   long m=(magic<0?Magic_Number:magic);
   double p=0;
   for(int i=PositionsTotal()-1;i>=0;i--)
   {
      ulong tk=PositionGetTicket(i);
      if(tk==0||!PositionSelectByTicket(tk)) continue;
      if(PositionGetString(POSITION_SYMBOL)!=g_symbol || (long)PositionGetInteger(POSITION_MAGIC)!=m) continue;
      p+=PositionGetDouble(POSITION_PROFIT)+PositionGetDouble(POSITION_SWAP);
   }
   return p;
}

double LastPrice(int dir)
{
   datetime lt=0; double pr=0;
   for(int i=PositionsTotal()-1;i>=0;i--)
   {
      ulong tk=PositionGetTicket(i);
      if(tk==0||!PositionSelectByTicket(tk)||!IsOurPos()) continue;
      long type=PositionGetInteger(POSITION_TYPE);
      if(dir==1&&type!=POSITION_TYPE_BUY) continue;
      if(dir==-1&&type!=POSITION_TYPE_SELL) continue;
      datetime ot=(datetime)PositionGetInteger(POSITION_TIME);
      if(ot>=lt){ lt=ot; pr=PositionGetDouble(POSITION_PRICE_OPEN); }
   }
   return pr;
}

bool HasHedge() { return (TotalLots(1)>0.0 && TotalLots(-1)>0.0); }

//+------------------------------------------------------------------+
//| 2. TRADE EXECUTION FUNCTIONS                                     |
//+------------------------------------------------------------------+
double NormLot(double lot)
{
   double minv=SymbolInfoDouble(g_symbol,SYMBOL_VOLUME_MIN);
   double maxv=SymbolInfoDouble(g_symbol,SYMBOL_VOLUME_MAX);
   double step=SymbolInfoDouble(g_symbol,SYMBOL_VOLUME_STEP);
   if(step<=0) step=0.01;
   lot=MathMax(lot,MathMax(minv,Min_Lot));
   lot=MathMin(lot,MathMin(maxv,Max_Lot));
   lot=MathFloor(lot/step)*step;
   return NormalizeDouble(lot,2);
}

double NormLotRaw(double lot)
{
   // Like NormLot but respects broker min/max without our Max_Lot cap (for scalper)
   double minv=SymbolInfoDouble(g_symbol,SYMBOL_VOLUME_MIN);
   double maxv=SymbolInfoDouble(g_symbol,SYMBOL_VOLUME_MAX);
   double step=SymbolInfoDouble(g_symbol,SYMBOL_VOLUME_STEP);
   if(step<=0) step=0.01;
   lot=MathMax(lot,minv);
   lot=MathMin(lot,maxv);
   lot=MathFloor(lot/step)*step;
   return NormalizeDouble(lot,2);
}

bool CanSend()
{
   if(SpreadPoints()>Max_Spread_Points || !TradingHour() || NewsBlocked()) return false;
   if(TimeCurrent()-g_last_order_time<Min_Seconds_Between_Orders) return false;
   if(One_Order_Per_Bar){ datetime b=iTime(g_symbol,PERIOD_M1,0); if(b==g_last_bar_time) return false; }
   if(TimeCurrent()-g_last_cycle_close_time<Cooldown_After_Cycle_Sec) return false;
   return true;
}

bool SendOrder(int dir, double lot, string cmt, long magic=-1)
{
   if(!CanSend()) return false;
   if(CountPos()>=Max_Total_Orders) return false;
   if(TotalLots()+lot>Max_Total_Lot) return false;
   long m=(magic<0?Magic_Number:magic);
   MqlTradeRequest r; MqlTradeResult res; ZeroMemory(r); ZeroMemory(res);
   r.action=TRADE_ACTION_DEAL; r.symbol=g_symbol; r.magic=m; r.volume=lot; r.deviation=Slippage_Points; r.comment=cmt;
   if(dir==1){ r.type=ORDER_TYPE_BUY; r.price=SymbolInfoDouble(g_symbol,SYMBOL_ASK); }
   else if(dir==-1){ r.type=ORDER_TYPE_SELL; r.price=SymbolInfoDouble(g_symbol,SYMBOL_BID); }
   else return false;
   bool ok=OrderSend(r,res);
   if(ok && (res.retcode==TRADE_RETCODE_DONE || res.retcode==TRADE_RETCODE_PLACED))
   {
      if(magic<0 || magic==Magic_Number){ g_last_order_time=TimeCurrent(); g_last_bar_time=iTime(g_symbol,PERIOD_M1,0); }
      Print("[AI2 ORDER] ",cmt," lot=",lot," magic=",m);
      return true;
   }
   Print("[AI2 ORDER FAIL] ",cmt," ret=",res.retcode," err=",GetLastError());
   return false;
}

bool CloseTicket(ulong tk, long magic=-1)
{
   if(!PositionSelectByTicket(tk)) return false;
   long pmagic=(long)PositionGetInteger(POSITION_MAGIC);
   long m=(magic<0?Magic_Number:magic);
   if(pmagic!=m) return false;
   long type=PositionGetInteger(POSITION_TYPE);
   double vol=PositionGetDouble(POSITION_VOLUME);
   MqlTradeRequest r; MqlTradeResult res; ZeroMemory(r); ZeroMemory(res);
   r.action=TRADE_ACTION_DEAL; r.symbol=g_symbol; r.magic=m; r.position=tk; r.volume=vol; r.deviation=Slippage_Points; r.comment="AI2_CLOSE";
   if(type==POSITION_TYPE_BUY){ r.type=ORDER_TYPE_SELL; r.price=SymbolInfoDouble(g_symbol,SYMBOL_BID); }
   else { r.type=ORDER_TYPE_BUY; r.price=SymbolInfoDouble(g_symbol,SYMBOL_ASK); }
   bool ok=OrderSend(r,res);
   return (ok && res.retcode==TRADE_RETCODE_DONE);
}

void CloseAll()
{
   for(int i=PositionsTotal()-1;i>=0;i--)
   {
      ulong tk=PositionGetTicket(i);
      if(tk==0||!PositionSelectByTicket(tk)||!IsOurPos()) continue;
      CloseTicket(tk);
   }
   g_last_cycle_close_time=TimeCurrent();
   g_tp1_done=false; g_tp1_first_ticket=0; g_tp1_cycle_start_time=0;
}

//+------------------------------------------------------------------+
//| 3. FVG MICROSTRUCTURE ENGINE (NEW V6)                           |
//+------------------------------------------------------------------+
// Fair Value Gap: a 3-candle pattern where candle[1] moves so strongly
// that a gap opens between candle[2].high and candle[0].low (bullish FVG)
// or candle[2].low and candle[0].high (bearish FVG).
// Entry trigger: price retraces into the FVG zone (mitigation).

void ScanFVG()
{
   g_fvg_bull_valid = false;
   g_fvg_bear_valid = false;
   if(!Use_FVG_Filter) return;

   double pt = SymbolInfoDouble(g_symbol, SYMBOL_POINT);
   if(pt <= 0) return;

   // Scan recent bars for the most recent valid FVG
   for(int i=1; i<=FVG_Lookback_Bars; i++)
   {
      // Bars: candle[i+1] = left, candle[i] = impulse, candle[i-1] = right
      double hi0 = iHigh(g_symbol, PERIOD_M1, i-1);   // Right candle high
      double lo0 = iLow(g_symbol, PERIOD_M1, i-1);    // Right candle low
      double hi1 = iHigh(g_symbol, PERIOD_M1, i);     // Impulse high
      double lo1 = iLow(g_symbol, PERIOD_M1, i);      // Impulse low (unused but available)
      double hi2 = iHigh(g_symbol, PERIOD_M1, i+1);   // Left candle high
      double lo2 = iLow(g_symbol, PERIOD_M1, i+1);    // Left candle low

      // Bullish FVG: gap between left candle high (hi2) and right candle low (lo0)
      if(!g_fvg_bull_valid && lo0 > hi2)
      {
         double gapSize = (lo0 - hi2) / pt;
         if(gapSize >= FVG_Min_Size_Points && gapSize <= FVG_Max_Size_Points)
         {
            g_fvg_bull_lo = hi2;   // FVG lower boundary
            g_fvg_bull_hi = lo0;   // FVG upper boundary
            // Check if price has retested (is currently inside or at the FVG)
            double bid = SymbolInfoDouble(g_symbol, SYMBOL_BID);
            if(!FVG_Require_Retest || (bid >= g_fvg_bull_lo && bid <= g_fvg_bull_hi + (g_fvg_bull_hi - g_fvg_bull_lo)*0.5))
               g_fvg_bull_valid = true;
         }
      }

      // Bearish FVG: gap between left candle low (lo2) and right candle high (hi0)
      if(!g_fvg_bear_valid && hi0 < lo2)
      {
         double gapSize = (lo2 - hi0) / pt;
         if(gapSize >= FVG_Min_Size_Points && gapSize <= FVG_Max_Size_Points)
         {
            g_fvg_bear_lo = hi0;   // FVG lower boundary
            g_fvg_bear_hi = lo2;   // FVG upper boundary
            double ask = SymbolInfoDouble(g_symbol, SYMBOL_ASK);
            if(!FVG_Require_Retest || (ask >= g_fvg_bear_lo - (g_fvg_bear_hi - g_fvg_bear_lo)*0.5 && ask <= g_fvg_bear_hi))
               g_fvg_bear_valid = true;
         }
      }

      if(g_fvg_bull_valid && g_fvg_bear_valid) break;
   }
}

void ScanOrderBlocks()
{
   g_ob_bull_valid = false;
   g_ob_bear_valid = false;
   if(!Use_OB_Filter) return;

   double pt = SymbolInfoDouble(g_symbol, SYMBOL_POINT);
   if(pt <= 0) return;

   // Order Block: last strong bearish candle before a bullish impulse (bull OB)
   // or last strong bullish candle before a bearish impulse (bear OB)
   for(int i=2; i<=OB_Lookback_Bars; i++)
   {
      double o1 = iOpen(g_symbol, PERIOD_M1, i);
      double c1 = iClose(g_symbol, PERIOD_M1, i);
      double h1 = iHigh(g_symbol, PERIOD_M1, i);
      double l1 = iLow(g_symbol, PERIOD_M1, i);
      double bodySize = MathAbs(c1 - o1) / pt;
      if(bodySize < OB_Min_Body_Points) continue;

      double c0 = iClose(g_symbol, PERIOD_M1, i-1);

      // Bull OB: bearish candle (c1 < o1) followed by strong up close
      if(!g_ob_bull_valid && c1 < o1 && c0 > h1)
      {
         g_ob_bull_lo = l1;
         g_ob_bull_hi = o1; // Top of bearish candle body = OB zone
         double bid = SymbolInfoDouble(g_symbol, SYMBOL_BID);
         if(bid >= g_ob_bull_lo && bid <= g_ob_bull_hi)
            g_ob_bull_valid = true;
      }

      // Bear OB: bullish candle (c1 > o1) followed by strong down close
      if(!g_ob_bear_valid && c1 > o1 && c0 < l1)
      {
         g_ob_bear_lo = o1; // Bottom of bullish candle body = OB zone
         g_ob_bear_hi = h1;
         double ask = SymbolInfoDouble(g_symbol, SYMBOL_ASK);
         if(ask >= g_ob_bear_lo && ask <= g_ob_bear_hi)
            g_ob_bear_valid = true;
      }

      if(g_ob_bull_valid && g_ob_bear_valid) break;
   }
}

// Returns true if microstructure supports entry in `dir`
bool MicrostructureAllow(int dir)
{
   if(!Use_FVG_Filter && !Use_OB_Filter) return true;

   bool fvgOk = false;
   bool obOk  = !Use_OB_Filter; // If OB filter disabled, treat as OK

   if(Use_FVG_Filter)
   {
      if(dir==1 && g_fvg_bull_valid) fvgOk = true;   // Buy into bullish FVG
      if(dir==-1 && g_fvg_bear_valid) fvgOk = true;  // Sell into bearish FVG
      // If no FVG found at all, allow entry (don't over-filter)
      if(!g_fvg_bull_valid && !g_fvg_bear_valid) fvgOk = true;
   }
   else fvgOk = true;

   if(Use_OB_Filter)
   {
      if(dir==1 && g_ob_bull_valid) obOk = true;
      if(dir==-1 && g_ob_bear_valid) obOk = true;
      if(!g_ob_bull_valid && !g_ob_bear_valid) obOk = true;
   }

   return (fvgOk && obOk);
}

string FVGStatusText()
{
   if(!Use_FVG_Filter) return "OFF";
   if(g_fvg_bull_valid && g_fvg_bear_valid) return "BULL+BEAR";
   if(g_fvg_bull_valid) return "BULL FVG";
   if(g_fvg_bear_valid) return "BEAR FVG";
   return "NONE";
}

//+------------------------------------------------------------------+
//| 4. DYNAMIC EXIT ENGINE V6                                        |
//+------------------------------------------------------------------+
// Computes ATR-adaptive thresholds instead of static USD values

double CalcATRAvg()
{
   // Cache for 30 seconds to avoid recalculation spam
   if(TimeCurrent() - g_atr_avg_last_calc < 30 && g_atr_avg_cache > 0)
      return g_atr_avg_cache;

   double atrVal = ATRValue(PERIOD_M1);
   // Simple approximation: use current ATR as proxy (no separate long handle needed)
   // For better accuracy the h_atr_m1_long handle tracks longer ATR
   double longATR = IndValH(h_atr_m1_long, 0, 0);
   if(longATR <= 0) longATR = atrVal;

   g_atr_avg_cache = longATR;
   g_atr_avg_last_calc = TimeCurrent();
   return g_atr_avg_cache;
}

double DynBEThreshold()
{
   if(!Exit_Use_ATR_BE) return Exit_BE_USD_Min;
   double atrPts = ATRPoints(PERIOD_M1);
   // Convert ATR points to approximate USD for XAUUSD (1 pt ≈ $0.01 per 0.01 lot)
   // We express threshold in USD relative to basket size
   double atrFactor = atrPts * Exit_BE_ATR_Multiplier * 0.1;
   double thresh = -MathAbs(atrFactor);
   thresh = MathMax(thresh, Exit_BE_USD_Max);   // Cap (more negative = not too tight)
   thresh = MathMin(thresh, Exit_BE_USD_Min);   // Floor (less negative = not too loose)
   return thresh;
}

double DynLockThreshold()
{
   if(!Exit_Use_ATR_Lock) return Exit_Lock_USD_Min;
   double atrPts = ATRPoints(PERIOD_M1);
   double val = atrPts * Exit_Lock_ATR_Multiplier * 0.1;
   val = MathMax(val, Exit_Lock_USD_Min);
   val = MathMin(val, Exit_Lock_USD_Max);
   return val;
}

double DynTrailAmount()
{
   if(!Exit_Use_ATR_Trail) return Exit_Trail_USD_Min;
   double atrPts = ATRPoints(PERIOD_M1);
   double val = atrPts * Exit_Trail_ATR_Multiplier * 0.1;
   val = MathMax(val, Exit_Trail_USD_Min);
   val = MathMin(val, Exit_Trail_USD_Max);
   return val;
}

int DynMaxTimeMin()
{
   if(!Exit_Use_Time_Limit) return 99999;
   if(g_mode==MODE_HEDGE_DEFENSE) return Exit_Max_Time_Min_Hedge;
   if(g_mode==MODE_TREND) return Exit_Max_Time_Min_Trend;
   return Exit_Max_Time_Min_Scalp;
}

bool IsATRSpike()
{
   if(!Exit_Close_On_ATR_Spike) return false;
   double cur = ATRValue(PERIOD_M1);
   double avg = CalcATRAvg();
   if(avg <= 0) return false;
   return (cur >= avg * Exit_ATR_Spike_Ratio);
}

void UpdateTrailingValues()
{
   double profit = BasketProfit();
   if(profit > g_highest_profit) g_highest_profit = profit;
   if(profit < g_lowest_profit)  g_lowest_profit  = profit;
}

void TryExitEngine()
{
   if(!Use_Exit_Engine) return;
   if(CountPos()==0){ g_highest_profit=0; g_lowest_profit=0; return; }

   UpdateTrailingValues();
   double profit = BasketProfit();
   double beThresh   = DynBEThreshold();
   double lockThresh = DynLockThreshold();
   double trailAmt   = DynTrailAmount();

   // 1. ATR Spike — chaotic volatility, close immediately
   if(IsATRSpike() && profit < 0)
   {
      Print("[DYN EXIT] ATR spike detected, closing at loss=",profit);
      CloseAll();
      return;
   }

   // 2. Breakeven guard — closed after previously being positive
   if(beThresh < 0 && profit <= beThresh && g_highest_profit > MathAbs(beThresh))
   {
      Print("[DYN EXIT] Breakeven triggered | BE=",beThresh," Profit=",profit," PeakWas=",g_highest_profit);
      CloseAll();
      return;
   }

   // 3. Lock profit + trailing
   if(lockThresh > 0 && g_highest_profit >= lockThresh)
   {
      if(profit <= g_highest_profit - trailAmt)
      {
         Print("[DYN EXIT] Lock profit trail | Lock=",lockThresh," Trail=",trailAmt," Max=",g_highest_profit," Now=",profit);
         CloseAll();
         return;
      }
   }

   // 4. Time-based exit (mode-adaptive)
   int maxMin = DynMaxTimeMin();
   if(maxMin < 99999 && CountPos()>0)
   {
      datetime firstTime=0;
      for(int i=PositionsTotal()-1;i>=0;i--)
      {
         ulong tk=PositionGetTicket(i);
         if(tk==0||!PositionSelectByTicket(tk)||!IsOurPos()) continue;
         datetime ot=(datetime)PositionGetInteger(POSITION_TIME);
         if(firstTime==0 || ot<firstTime) firstTime=ot;
      }
      if(firstTime>0)
      {
         int minsHeld=(int)((TimeCurrent()-firstTime)/60);
         if(minsHeld>=maxMin)
         {
            Print("[DYN EXIT] Time limit ",maxMin,"min reached | Profit=",profit);
            CloseAll();
            return;
         }
      }
   }
}

//+------------------------------------------------------------------+
//| 5. BULK SCALPER ENGINE (NEW V6)                                  |
//+------------------------------------------------------------------+
// 7 independent scalper slots. Each slot:
//   - Opens a trade with its assigned lot size
//   - Monitors profit independently
//   - Closes when profit >= tiered TP (scaled by lot)
//   - Re-opens immediately in the same direction after close
//   - Has trailing option: once TP hit, trail by Scalper_Trail_Buffer_USD

double ScalperTPForLot(double lot)
{
   // TP scales proportionally: $1 per 0.01 lot
   // lot=0.01 -> $1, lot=0.05 -> $5, lot=0.10 -> $10, lot=1.00 -> $100
   if(!Scalper_Use_Tiered_TP) return Scalper_TP_Per_01_Lot;
   double ratio = lot / 0.01;
   return NormalizeDouble(Scalper_TP_Per_01_Lot * ratio, 2);
}

double ScalperLotForSlot(int slot)
{
   // Each slot grows lot by multiplier: slot 0 = base, slot 1 = base*mult, etc.
   double lot = Scalper_Base_Lot * MathPow(Scalper_Lot_Multiplier, slot);
   return NormLotRaw(lot);
}

void InitScalperSlots()
{
   for(int i=0; i<7; i++)
   {
      g_scalper[i].ticket        = 0;
      g_scalper[i].lot           = ScalperLotForSlot(i);
      g_scalper[i].tp_usd        = ScalperTPForLot(g_scalper[i].lot);
      g_scalper[i].peak_profit   = 0;
      g_scalper[i].trailing_armed= false;
      g_scalper[i].last_close    = 0;
      g_scalper[i].direction     = 0;
   }
}

bool ScalperTicketAlive(int slot)
{
   ulong tk = g_scalper[slot].ticket;
   if(tk==0) return false;
   if(!PositionSelectByTicket(tk)) { g_scalper[slot].ticket=0; return false; }
   long m=(long)PositionGetInteger(POSITION_MAGIC);
   long expected=(long)(Scalper_Magic_Base+slot);
   if(m!=expected || PositionGetString(POSITION_SYMBOL)!=g_symbol){ g_scalper[slot].ticket=0; return false; }
   return true;
}

double ScalperTicketProfit(int slot)
{
   if(!ScalperTicketAlive(slot)) return 0;
   if(!PositionSelectByTicket(g_scalper[slot].ticket)) return 0;
   return PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);
}

bool ScalperOpenTrade(int slot, int dir)
{
   if(SpreadPoints()>Max_Spread_Points || !TradingHour() || NewsBlocked()) return false;
   if(g_risk==RISK_DANGER || g_risk==RISK_EMERGENCY) return false;

   // Cooldown check per slot
   if(TimeCurrent() - g_scalper[slot].last_close < Scalper_Reopen_Delay_Sec) return false;

   double lot = g_scalper[slot].lot;
   long   mg  = (long)(Scalper_Magic_Base + slot);
   string cmt = "SCALP_S"+IntegerToString(slot+1)+"_L"+DoubleToString(lot,2);

   MqlTradeRequest r; MqlTradeResult res; ZeroMemory(r); ZeroMemory(res);
   r.action=TRADE_ACTION_DEAL; r.symbol=g_symbol; r.magic=mg; r.volume=lot; r.deviation=Slippage_Points; r.comment=cmt;
   if(dir==1){ r.type=ORDER_TYPE_BUY; r.price=SymbolInfoDouble(g_symbol,SYMBOL_ASK); }
   else      { r.type=ORDER_TYPE_SELL; r.price=SymbolInfoDouble(g_symbol,SYMBOL_BID); }

   bool ok=OrderSend(r,res);
   if(ok && (res.retcode==TRADE_RETCODE_DONE||res.retcode==TRADE_RETCODE_PLACED))
   {
      g_scalper[slot].ticket        = res.deal;
      g_scalper[slot].direction     = dir;
      g_scalper[slot].peak_profit   = 0;
      g_scalper[slot].trailing_armed= false;
      // Re-fetch real ticket from positions
      for(int i=PositionsTotal()-1;i>=0;i--)
      {
         ulong tk=PositionGetTicket(i);
         if(tk==0||!PositionSelectByTicket(tk)) continue;
         if(PositionGetString(POSITION_SYMBOL)==g_symbol && (long)PositionGetInteger(POSITION_MAGIC)==mg)
         {
            g_scalper[slot].ticket = tk;
            break;
         }
      }
      Print("[SCALPER S",slot+1,"] OPEN dir=",dir," lot=",lot," TP=$",g_scalper[slot].tp_usd);
      return true;
   }
   Print("[SCALPER S",slot+1,"] OPEN FAIL ret=",res.retcode," err=",GetLastError());
   return false;
}

bool ScalperCloseTrade(int slot)
{
   if(!ScalperTicketAlive(slot)) return false;
   ulong tk=g_scalper[slot].ticket;
   long mg=(long)(Scalper_Magic_Base+slot);

   if(!PositionSelectByTicket(tk)) return false;
   long type=PositionGetInteger(POSITION_TYPE);
   double vol=PositionGetDouble(POSITION_VOLUME);

   MqlTradeRequest r; MqlTradeResult res; ZeroMemory(r); ZeroMemory(res);
   r.action=TRADE_ACTION_DEAL; r.symbol=g_symbol; r.magic=mg; r.position=tk; r.volume=vol; r.deviation=Slippage_Points; r.comment="SCALP_CLOSE";
   if(type==POSITION_TYPE_BUY){ r.type=ORDER_TYPE_SELL; r.price=SymbolInfoDouble(g_symbol,SYMBOL_BID); }
   else                       { r.type=ORDER_TYPE_BUY;  r.price=SymbolInfoDouble(g_symbol,SYMBOL_ASK); }

   bool ok=OrderSend(r,res);
   if(ok && res.retcode==TRADE_RETCODE_DONE)
   {
      double p = ScalperTicketProfit(slot); // May be 0 now, captured before close
      Print("[SCALPER S",slot+1,"] CLOSE | Profit~$",DoubleToString(p,2));
      g_scalper[slot].ticket        = 0;
      g_scalper[slot].peak_profit   = 0;
      g_scalper[slot].trailing_armed= false;
      g_scalper[slot].last_close    = TimeCurrent();
      return true;
   }
   return false;
}

void ManageScalperSlot(int slot)
{
   // Step 1: Sync ticket — check if still alive
   bool alive = ScalperTicketAlive(slot);

   // Step 2: If dead → try reopen
   if(!alive)
   {
      if(g_direction==0) return; // No direction signal
      if(g_risk==RISK_DANGER || g_risk==RISK_EMERGENCY) return;

      // FVG check for scalper entries
      if(Scalper_Use_FVG_Entry && !MicrostructureAllow(g_direction)) return;

      ScalperOpenTrade(slot, g_direction);
      return;
   }

   // Step 3: Get current profit
   double profit = ScalperTicketProfit(slot);

   // Update peak
   if(profit > g_scalper[slot].peak_profit)
      g_scalper[slot].peak_profit = profit;

   // Step 4: Emergency loss stop per slot
   if(profit <= Scalper_Max_Loss_USD)
   {
      Print("[SCALPER S",slot+1,"] Emergency stop | loss=",profit);
      ScalperCloseTrade(slot);
      return;
   }

   double tp = g_scalper[slot].tp_usd;

   // Step 5: Trailing mode
   if(Scalper_Trail_After_TP && g_scalper[slot].trailing_armed)
   {
      // Trail: close if profit drops Scalper_Trail_Buffer_USD from peak
      if(profit <= g_scalper[slot].peak_profit - Scalper_Trail_Buffer_USD)
      {
         Print("[SCALPER S",slot+1,"] Trail close | peak=",g_scalper[slot].peak_profit," now=",profit);
         ScalperCloseTrade(slot);
      }
      return;
   }

   // Step 6: TP hit → arm trailing OR hard close
   if(profit >= tp)
   {
      if(Scalper_Trail_After_TP)
      {
         g_scalper[slot].trailing_armed = true;
         Print("[SCALPER S",slot+1,"] TP hit $",tp," — trailing armed");
      }
      else
      {
         Print("[SCALPER S",slot+1,"] TP hit $",tp," — hard close");
         ScalperCloseTrade(slot);
      }
   }
}

void RunBulkScalper()
{
   if(!Use_Bulk_Scalper) return;
   if(g_risk==RISK_EMERGENCY) return;
   if(NewsBlocked() || !TradingHour()) return;

   int activeSlots = MathMin(Scalper_Max_Trades, 7);
   for(int i=0; i<activeSlots; i++)
      ManageScalperSlot(i);
}

string ScalperSummaryText()
{
   if(!Use_Bulk_Scalper) return "OFF";
   int active=0;
   double totalP=0;
   for(int i=0;i<MathMin(Scalper_Max_Trades,7);i++)
   {
      if(ScalperTicketAlive(i)){ active++; totalP+=ScalperTicketProfit(i); }
   }
   return "SLOTS:"+IntegerToString(active)+"/"+IntegerToString(MathMin(Scalper_Max_Trades,7))+" P=$"+DoubleToString(totalP,2);
}

//+------------------------------------------------------------------+
//| 6. TP1 PRO AI MODULE (unchanged from V5)                        |
//+------------------------------------------------------------------+
ulong TP1_GetFirstTicket()
{
   ulong firstTicket=0; datetime firstTime=0;
   for(int i=PositionsTotal()-1;i>=0;i--)
   {
      ulong tk=PositionGetTicket(i);
      if(tk==0||!PositionSelectByTicket(tk)||!IsOurPos()) continue;
      datetime ot=(datetime)PositionGetInteger(POSITION_TIME);
      if(firstTicket==0||ot<firstTime){ firstTicket=tk; firstTime=ot; }
   }
   return firstTicket;
}

bool TP1_ClosePartialByTicket(ulong tk, double percent)
{
   if(!PositionSelectByTicket(tk)) return false;
   if(PositionGetString(POSITION_SYMBOL)!=g_symbol||(long)PositionGetInteger(POSITION_MAGIC)!=Magic_Number) return false;
   double vol=PositionGetDouble(POSITION_VOLUME);
   double closeVol=vol*percent/100.0;
   double minv=SymbolInfoDouble(g_symbol,SYMBOL_VOLUME_MIN);
   double step=SymbolInfoDouble(g_symbol,SYMBOL_VOLUME_STEP);
   if(step<=0) step=0.01;
   closeVol=MathFloor(closeVol/step)*step;
   closeVol=NormalizeDouble(closeVol,2);
   if(closeVol<minv) return false;
   if(closeVol>=vol) closeVol=vol;
   long type=PositionGetInteger(POSITION_TYPE);
   MqlTradeRequest r; MqlTradeResult res; ZeroMemory(r); ZeroMemory(res);
   r.action=TRADE_ACTION_DEAL; r.symbol=g_symbol; r.magic=Magic_Number; r.position=tk;
   r.volume=closeVol; r.deviation=Slippage_Points; r.comment="AI2_TP1_PRO";
   if(type==POSITION_TYPE_BUY){ r.type=ORDER_TYPE_SELL; r.price=SymbolInfoDouble(g_symbol,SYMBOL_BID); }
   else{ r.type=ORDER_TYPE_BUY; r.price=SymbolInfoDouble(g_symbol,SYMBOL_ASK); }
   bool ok=OrderSend(r,res);
   if(ok&&res.retcode==TRADE_RETCODE_DONE){ Print("[TP1 PRO] Partial close ticket=",tk); return true; }
   return false;
}

void TP1_ResetIfNewCycle()
{
   if(CountPos()==0){ g_tp1_done=false; g_tp1_first_ticket=0; g_tp1_cycle_start_time=0; return; }
   ulong first=TP1_GetFirstTicket();
   if(first==0) return;
   if(g_tp1_first_ticket==0){ g_tp1_first_ticket=first; if(PositionSelectByTicket(first)) g_tp1_cycle_start_time=(datetime)PositionGetInteger(POSITION_TIME); g_tp1_done=false; return; }
   if(first!=g_tp1_first_ticket){ g_tp1_first_ticket=first; if(PositionSelectByTicket(first)) g_tp1_cycle_start_time=(datetime)PositionGetInteger(POSITION_TIME); g_tp1_done=false; }
}

void TryTP1ProAI()
{
   if(!Use_TP1_PRO_AI) return;
   TP1_ResetIfNewCycle();
   if(CountPos()==0) return;
   if(TP1_Only_Once_Per_Cycle&&g_tp1_done) return;
   if(TP1_Disable_When_Hedged&&(TotalLots(1)>0.0&&TotalLots(-1)>0.0)) return;
   if(TP1_Disable_When_Hedged&&g_mode==MODE_HEDGE_DEFENSE) return;
   ulong tk=TP1_GetFirstTicket();
   if(tk==0||!PositionSelectByTicket(tk)) return;
   datetime ot=(datetime)PositionGetInteger(POSITION_TIME);
   if(TimeCurrent()-ot<TP1_Min_Seconds_After_Entry) return;
   double p=PositionGetDouble(POSITION_PROFIT)+PositionGetDouble(POSITION_SWAP);
   if(p<TP1_Profit_USD) return;
   if(TP1_ClosePartialByTicket(tk,TP1_Close_Percent)) g_tp1_done=true;
}

//+------------------------------------------------------------------+
//| 7. SMART UNWIND PRO V4                                          |
//+------------------------------------------------------------------+
ulong GetWorstTicket()
{
   double worstProfit=999999; ulong worstTicket=0;
   for(int i=PositionsTotal()-1;i>=0;i--)
   {
      ulong tk=PositionGetTicket(i);
      if(tk==0||!PositionSelectByTicket(tk)||!IsOurPos()) continue;
      double p=PositionGetDouble(POSITION_PROFIT);
      if(p<worstProfit){ worstProfit=p; worstTicket=tk; }
   }
   return worstTicket;
}

void TrySmartUnwind()
{
   if(!Use_Smart_Unwind_PRO) return;
   if(TimeCurrent()-g_last_unwind_time<Unwind_Cooldown_Sec) return;
   if(CountPos()<Unwind_Min_Orders) return;
   if(!HasHedge()) return;
   double profit=BasketProfit();
   if(profit<0 && profit<Unwind_Min_Profit_USD) return; // Fixed: require profit > 0 to unwind
   ulong tk=GetWorstTicket();
   if(tk==0||!PositionSelectByTicket(tk)) return;
   double vol=PositionGetDouble(POSITION_VOLUME);
   double closeVol=vol*Unwind_Close_Percent/100.0;
   double step=SymbolInfoDouble(g_symbol,SYMBOL_VOLUME_STEP);
   closeVol=MathFloor(closeVol/step)*step;
   closeVol=NormalizeDouble(closeVol,2);
   if(closeVol<=0) return;
   long type=PositionGetInteger(POSITION_TYPE);
   MqlTradeRequest r; MqlTradeResult res; ZeroMemory(r); ZeroMemory(res);
   r.action=TRADE_ACTION_DEAL; r.symbol=g_symbol; r.magic=Magic_Number; r.position=tk;
   r.volume=closeVol; r.deviation=Slippage_Points; r.comment="SMART_UNWIND_V6";
   if(type==POSITION_TYPE_BUY){ r.type=ORDER_TYPE_SELL; r.price=SymbolInfoDouble(g_symbol,SYMBOL_BID); }
   else{ r.type=ORDER_TYPE_BUY; r.price=SymbolInfoDouble(g_symbol,SYMBOL_ASK); }
   if(OrderSend(r,res)&&res.retcode==TRADE_RETCODE_DONE){ Print("[SMART UNWIND V6] Reduced worst pos"); g_last_unwind_time=TimeCurrent(); }
}

//+------------------------------------------------------------------+
//| 8. REGIME DETECTION ENGINE                                       |
//+------------------------------------------------------------------+
void DetectRegime()
{
   double atr=ATRPoints(Regime_TF_Main);
   int d=TrendDir(Regime_TF_Main), c=TrendDir(Regime_TF_Confirm);
   if(!Use_Regime_AI){ g_regime=(d>0?REGIME_TREND_UP:(d<0?REGIME_TREND_DOWN:REGIME_SIDEWAY)); return; }
   if(atr>=Chaotic_ATR_Min_Points) g_regime=REGIME_CHAOTIC;
   else if(atr>=Volatile_ATR_Min_Points) g_regime=REGIME_VOLATILE;
   else if(atr<=Sideway_ATR_Max_Points||d==0) g_regime=REGIME_SIDEWAY;
   else if(d>0&&c>=0) g_regime=REGIME_TREND_UP;
   else if(d<0&&c<=0) g_regime=REGIME_TREND_DOWN;
   else g_regime=REGIME_SIDEWAY;
}

//+------------------------------------------------------------------+
//| 9. ATTACK MODE SWITCH                                            |
//+------------------------------------------------------------------+
void UpdateAttackMode()
{
   if(!Use_Multi_Mode_Lot) return;
   double dd=DDPercent(), profit=BasketProfit(), atr=ATRPoints(PERIOD_M1);
   int trendStr=MathAbs(TrendDir(PERIOD_M5));
   if(dd>=Switch_To_Recovery_DD_Percent||profit<=-Switch_To_Recovery_Loss_USD)
   {
      if(g_attack_mode!=ATTACK_RECOVERY){ g_attack_mode=ATTACK_RECOVERY; Print("[AI2] RECOVERY mode"); }
      return;
   }
   if(atr>=Switch_To_Attack_ATR&&trendStr>=1)
   {
      if(g_attack_mode!=ATTACK_ACTIVE){ g_attack_mode=ATTACK_ACTIVE; Print("[AI2] ATTACK mode"); }
      return;
   }
   if(dd<=Switch_Back_To_Safe_DD_Percent&&profit>0)
   {
      if(g_attack_mode!=ATTACK_SAFE){ g_attack_mode=ATTACK_SAFE; Print("[AI2] SAFE mode"); }
      return;
   }
}

double GetModeBaseLot(){ if(!Use_Multi_Mode_Lot) return Base_Lot; if(g_attack_mode==ATTACK_ACTIVE) return Attack_Base_Lot; if(g_attack_mode==ATTACK_RECOVERY) return Recovery_Base_Lot; return Safe_Base_Lot; }
int    GetModeMaxDCA() { if(!Use_Multi_Mode_Lot) return Max_DCA_Levels; if(g_attack_mode==ATTACK_ACTIVE) return Attack_Max_DCA; if(g_attack_mode==ATTACK_RECOVERY) return Recovery_Max_DCA; return Safe_Max_DCA; }
double GetModeMultiplier(){ if(!Use_Multi_Mode_Lot) return Lot_Multiplier; if(g_attack_mode==ATTACK_ACTIVE) return Attack_Multiplier; if(g_attack_mode==ATTACK_RECOVERY) return Recovery_Multiplier; return Safe_Multiplier; }
double GetModeHedgeRatio(){ if(!Use_Multi_Mode_Lot) return Hedge_Ratio; if(g_attack_mode==ATTACK_ACTIVE) return Attack_Hedge_Ratio; if(g_attack_mode==ATTACK_RECOVERY) return Recovery_Hedge_Ratio; return Safe_Hedge_Ratio; }

//+------------------------------------------------------------------+
//| 10. RISK MANAGEMENT ENGINE                                       |
//+------------------------------------------------------------------+
void UpdateRisk()
{
   double dd=DDPercent(), dl=DailyLossPercent();
   if(dd>=Emergency_Close_DD_Percent||dl>=Daily_Loss_Limit_Percent) g_risk=RISK_EMERGENCY;
   else if(dd>=Max_Equity_DD_Stop_Percent) g_risk=RISK_DANGER;
   else if(dd>=DD_Reduce_Lot_At_Percent) g_risk=RISK_WARNING;
   else g_risk=RISK_SAFE;
   if(Use_Risk_Engine_PRO&&g_risk==RISK_EMERGENCY){ Print("[AI2 RISK] Emergency close all"); CloseAll(); }
}

//+------------------------------------------------------------------+
//| 11. AUTO MODE SWITCH + SELECT MODE                              |
//+------------------------------------------------------------------+
void SelectMode()
{
   // Single authoritative mode selector (removes V5 duplication bug)
   if(g_risk==RISK_EMERGENCY||g_risk==RISK_DANGER){ g_mode=MODE_PAUSE; return; }
   if(CountPos()>0&&TotalLots(1)>0&&TotalLots(-1)>0){ g_mode=MODE_HEDGE_DEFENSE; return; }
   if(!Use_Auto_Strategy_Switch){ g_mode=MODE_SCALP; return; }
   if(g_regime==REGIME_CHAOTIC){ g_mode=MODE_PAUSE; return; }
   if(g_regime==REGIME_VOLATILE){ g_mode=MODE_SAFE; return; }
   if(g_regime==REGIME_SIDEWAY){ g_mode=MODE_SCALP; return; }
   if(g_regime==REGIME_TREND_UP||g_regime==REGIME_TREND_DOWN){ g_mode=MODE_TREND; return; }
   if(DDPercent()>4.5){ g_mode=MODE_HEDGE_DEFENSE; return; }
   g_mode=MODE_SCALP;
}

//+------------------------------------------------------------------+
//| 12. DIRECTION BUILDER (WITH FVG CONFIRMATION)                   |
//+------------------------------------------------------------------+
int BuildDirection()
{
   int m1=TrendDir(PERIOD_M1), m5=TrendDir(PERIOD_M5), m15=TrendDir(PERIOD_M15);
   if(g_regime==REGIME_TREND_UP) return 1;
   if(g_regime==REGIME_TREND_DOWN) return -1;
   if(Use_MTF_Confirm&&Block_Entry_On_MTF_Conflict)
   {
      if(Use_M5_Filter&&m5!=0&&m1!=0&&m5!=m1) return 0;
      if(Use_M15_Filter&&m15!=0&&m1!=0&&m15!=m1) return 0;
   }
   return m1;
}

//+------------------------------------------------------------------+
//| 13. SMART PAUSE PRO                                             |
//+------------------------------------------------------------------+
bool SmartPause_IsActive()
{
   if(!Use_Smart_Pause_PRO) return false;
   if(g_mode==MODE_PAUSE) return true;
   if(g_regime==REGIME_CHAOTIC) return true;
   if(g_risk==RISK_DANGER||g_risk==RISK_EMERGENCY) return true;
   return false;
}

bool SmartPause_CanRescueHedge()
{
   if(!Use_Smart_Pause_PRO||!SmartPause_Allow_Hedge||!Use_Hedge||!Use_Smart_Hedge) return false;
   if(CountPos()==0) return false;
   double profit=BasketProfit(), dd=DDPercent();
   if(profit<=Hedge_Trigger_DD_USD) return true;
   if(dd>=Hedge_Trigger_DD_Percent) return true;
   if(dd>=SmartPause_Min_DD_For_Hedge_Percent&&SmartPause_IsActive()) return true;
   return false;
}

bool SmartPause_CanRescueReHedge()
{
   if(!Use_Smart_Pause_PRO||!SmartPause_Allow_ReHedge||!Use_ReHedge_AI||!Use_ReHedge) return false;
   if(CountPos(1)==0||CountPos(-1)==0) return false;
   if(SmartPause_IsActive()) return true;
   if(g_mode==MODE_HEDGE_DEFENSE) return true;
   return false;
}

string SmartPauseStatusText()
{
   if(!Use_Smart_Pause_PRO) return "OFF";
   if(!SmartPause_IsActive()) return "STANDBY";
   if(SmartPause_CanRescueHedge()) return "RESCUE HEDGE";
   if(SmartPause_CanRescueReHedge()) return "RESCUE REHEDGE";
   return "ENTRY/DCA BLOCK";
}

//+------------------------------------------------------------------+
//| 14. DECISION BUILDING ENGINE (FVG-AWARE)                        |
//+------------------------------------------------------------------+
void BuildDecision()
{
   g_entry_allow=false; g_dca_allow=false; g_hedge_allow=false; g_exit_allow=false; g_direction=0;
   if(!Use_AI_Level2) return;
   if(SpreadPoints()>Max_Spread_Points||!TradingHour()||NewsBlocked()) return;
   bool smartPause=SmartPause_IsActive();
   if(CountPos()>0) g_exit_allow=true;
   if(smartPause)
   {
      if(CountPos()>0){ if(SmartPause_Allow_Hedge&&SmartPause_CanRescueHedge()) g_hedge_allow=true; if(SmartPause_Allow_ReHedge&&SmartPause_CanRescueReHedge()) g_hedge_allow=true; }
      return;
   }
   g_direction=BuildDirection();
   // FVG precision filter on main entry
   if(g_direction!=0 && Use_FVG_Filter && !MicrostructureAllow(g_direction)) g_direction=0;

   if(CountPos()==0&&g_direction!=0) g_entry_allow=true;
   if(CountPos()>0)
   {
      g_dca_allow=true;
      g_hedge_allow=Use_Hedge&&Use_Smart_Hedge;
      if(g_mode==MODE_HEDGE_DEFENSE&&Stop_DCA_When_Hedged) g_dca_allow=false;
      if(g_regime==REGIME_CHAOTIC&&Block_DCA_In_Chaotic) g_dca_allow=false;
      if(g_risk==RISK_WARNING&&Stop_DCA_When_Trend_Against) g_dca_allow=false;
   }
}

//+------------------------------------------------------------------+
//| 15. LOT & STEP CALCULATORS                                      |
//+------------------------------------------------------------------+
double EntryLot()
{
   double l=GetModeBaseLot();
   if(Use_Adaptive_Lot){ if(g_risk==RISK_WARNING) l*=Lot_Reduce_Factor; if(g_regime==REGIME_VOLATILE) l*=Volatility_Lot_Reduce; }
   return NormLot(l);
}

double DCALot(int level)
{
   double l=GetModeBaseLot()*MathPow(GetModeMultiplier(),level);
   if(Use_Adaptive_Lot&&g_risk==RISK_WARNING) l*=Lot_Reduce_Factor;
   return NormLot(l);
}

int DCAStep()
{
   if(!Use_Adaptive_DCA) return Min_DCA_Step_Points;
   int s=(int)MathRound(ATRPoints(PERIOD_M1)*ATR_DCA_Multiplier);
   return MathMin(MathMax(s,Min_DCA_Step_Points),Max_DCA_Step_Points);
}

//+------------------------------------------------------------------+
//| 16. MAIN EXIT & ENTRY ENGINES                                   |
//+------------------------------------------------------------------+
void TryExit()
{
   if(!g_exit_allow) return;
   double target=(Use_Dynamic_BasketTP&&g_mode==MODE_HEDGE_DEFENSE ? Basket_TP_Hedge_Mode_USD : Basket_TP_Normal_USD);
   if(BasketProfit()>=target){ Print("[AI2 EXIT] Basket target $",target); CloseAll(); }
}

void TryEntry()
{
   if(!g_entry_allow) return;
   SendOrder(g_direction,EntryLot(),"AI2_ENTRY");
}

void TryDCA()
{
   if(!g_dca_allow) return;
   int maxDCA=GetModeMaxDCA();
   int b=CountPos(1), s=CountPos(-1), dir=0;
   if(b>s) dir=1; else if(s>b) dir=-1; else return;
   int level=MathMax(b,s);
   if(level>=maxDCA) return;
   if(Stop_DCA_When_Trend_Against&&((dir==1&&g_regime==REGIME_TREND_DOWN)||(dir==-1&&g_regime==REGIME_TREND_UP))) return;
   double lp=LastPrice(dir), pt=SymbolInfoDouble(g_symbol,SYMBOL_POINT);
   if(lp<=0||pt<=0) return;
   int step=DCAStep(); bool ok=false;
   if(dir==1&&SymbolInfoDouble(g_symbol,SYMBOL_BID)<=lp-step*pt) ok=true;
   if(dir==-1&&SymbolInfoDouble(g_symbol,SYMBOL_ASK)>=lp+step*pt) ok=true;
   if(ok) SendOrder(dir,DCALot(level),"AI2_DCA_L"+IntegerToString(level+1));
}

//+------------------------------------------------------------------+
//| 17. HEDGE SPACING PRO                                           |
//+------------------------------------------------------------------+
datetime Hedge_LastMainOrderTime(int dir)
{
   datetime latest=0;
   for(int i=PositionsTotal()-1;i>=0;i--)
   {
      ulong tk=PositionGetTicket(i);
      if(tk==0||!PositionSelectByTicket(tk)||!IsOurPos()) continue;
      long type=PositionGetInteger(POSITION_TYPE);
      if(dir==1&&type!=POSITION_TYPE_BUY) continue;
      if(dir==-1&&type!=POSITION_TYPE_SELL) continue;
      datetime ot=(datetime)PositionGetInteger(POSITION_TIME);
      if(ot>latest) latest=ot;
   }
   return latest;
}

bool Hedge_DistanceOK(int mainDir)
{
   if(!Use_Hedge_Spacing_PRO) return true;
   double last=LastPrice(mainDir), pt=SymbolInfoDouble(g_symbol,SYMBOL_POINT);
   if(last<=0.0||pt<=0.0) return false;
   double bid=SymbolInfoDouble(g_symbol,SYMBOL_BID), ask=SymbolInfoDouble(g_symbol,SYMBOL_ASK);
   double dist=(mainDir==1?(last-bid)/pt:(ask-last)/pt);
   return (dist>=Hedge_Min_Distance_From_Last_DCA);
}

bool Hedge_DelayOK(int mainDir)
{
   if(!Use_Hedge_Spacing_PRO) return true;
   datetime lastTime=Hedge_LastMainOrderTime(mainDir);
   if(lastTime<=0) return false;
   return (TimeCurrent()-lastTime>=Hedge_Delay_After_Last_Order_Sec);
}

bool Hedge_MomentumOK(int mainDir)
{
   if(!Use_Hedge_Spacing_PRO||!Hedge_Require_Momentum) return true;
   double atr=ATRPoints(PERIOD_M1), pt=SymbolInfoDouble(g_symbol,SYMBOL_POINT);
   if(atr<=0.0||pt<=0.0) return false;
   double o=iOpen(g_symbol,PERIOD_M1,1), c=iClose(g_symbol,PERIOD_M1,1);
   if(o<=0.0||c<=0.0) return false;
   double candlePts=MathAbs(c-o)/pt;
   if(candlePts<atr*Hedge_Momentum_Candle_ATR_Ratio) return false;
   if(mainDir==1&&c<o) return true;
   if(mainDir==-1&&c>o) return true;
   return false;
}

bool HedgeSpacingPRO_OK(int mainDir, double dd)
{
   if(!Use_Hedge_Spacing_PRO) return true;
   if(Hedge_Allow_If_DD_Emergency&&dd>=Hedge_Trigger_DD_Percent*1.5) return true;
   if(Use_Smart_Pause_PRO&&SmartPause_Bypass_HedgeSpacing_On_Danger&&SmartPause_IsActive()&&dd>=SmartPause_Min_DD_For_Hedge_Percent) return true;
   if(!Hedge_DelayOK(mainDir)) return false;
   if(!Hedge_DistanceOK(mainDir)) return false;
   if(!Hedge_MomentumOK(mainDir)) return false;
   return true;
}

void TryHedge()
{
   if(!g_hedge_allow) return;
   if(g_regime==REGIME_SIDEWAY&&DDPercent()<3.0) return;
   double profit=BasketProfit(), dd=DDPercent();
   if(profit>Hedge_Trigger_DD_USD&&dd<Hedge_Trigger_DD_Percent) return;
   int b=CountPos(1), s=CountPos(-1), main=0;
   if(b>s) main=1; else if(s>b) main=-1; else return;
   int level=MathMax(b,s);
   if(level<Hedge_Start_Level) return;
   if(!HedgeSpacingPRO_OK(main,dd)) return;
   int hedge=-main;
   if(Only_One_Hedge_Per_Direction&&CountPos(hedge)>0) return;
   double ratio=GetModeHedgeRatio();
   double need=NormLot(TotalLots(main)*ratio-TotalLots(hedge));
   if(need>0) SendOrder(hedge,need,"AI2_SMART_HEDGE");
}

void TryReHedge()
{
   if(!Use_ReHedge_AI||!Use_ReHedge) return;
   bool allowReHedge=(g_mode==MODE_HEDGE_DEFENSE||SmartPause_CanRescueReHedge());
   if(!allowReHedge) return;
   if(TimeCurrent()-g_last_rehedge_time<ReHedge_Cooldown_Min*60) return;
   if(BasketProfit()>Hedge_Trigger_DD_USD*1.5) return;
   if(CountPos(1)==0||CountPos(-1)==0) return;
   int main=(TotalLots(1)>=TotalLots(-1)?1:-1);
   double lot=NormLot(TotalLots(main)*ReHedge_Ratio);
   if(lot>0&&SendOrder(-main,lot,"AI2_REHEDGE")) g_last_rehedge_time=TimeCurrent();
}

//+------------------------------------------------------------------+
//| 18. DASHBOARD DRAWING FUNCTIONS                                  |
//+------------------------------------------------------------------+
void AI2_DrawPanel(string name,int x,int y,int w,int h,color bg,color border)
{
   if(ObjectFind(0,name)<0) ObjectCreate(0,name,OBJ_RECTANGLE_LABEL,0,0,0);
   ObjectSetInteger(0,name,OBJPROP_CORNER,CORNER_LEFT_UPPER);
   ObjectSetInteger(0,name,OBJPROP_XDISTANCE,x);
   ObjectSetInteger(0,name,OBJPROP_YDISTANCE,y);
   ObjectSetInteger(0,name,OBJPROP_XSIZE,w);
   ObjectSetInteger(0,name,OBJPROP_YSIZE,h);
   ObjectSetInteger(0,name,OBJPROP_BGCOLOR,bg);
   ObjectSetInteger(0,name,OBJPROP_BORDER_TYPE,BORDER_FLAT);
   ObjectSetInteger(0,name,OBJPROP_COLOR,border);
   ObjectSetInteger(0,name,OBJPROP_BACK,false);
   ObjectSetInteger(0,name,OBJPROP_SELECTABLE,false);
   ObjectSetInteger(0,name,OBJPROP_SELECTED,false);
   ObjectSetInteger(0,name,OBJPROP_HIDDEN,true);
}

void AI2_DrawLabel(string name,string text,int x,int y,color clr,int size)
{
   if(ObjectFind(0,name)<0) ObjectCreate(0,name,OBJ_LABEL,0,0,0);
   ObjectSetInteger(0,name,OBJPROP_CORNER,CORNER_LEFT_UPPER);
   ObjectSetInteger(0,name,OBJPROP_XDISTANCE,x);
   ObjectSetInteger(0,name,OBJPROP_YDISTANCE,y);
   ObjectSetInteger(0,name,OBJPROP_COLOR,clr);
   ObjectSetInteger(0,name,OBJPROP_FONTSIZE,size);
   ObjectSetInteger(0,name,OBJPROP_SELECTABLE,false);
   ObjectSetInteger(0,name,OBJPROP_SELECTED,false);
   ObjectSetInteger(0,name,OBJPROP_HIDDEN,true);
   ObjectSetString(0,name,OBJPROP_FONT,"Consolas");
   ObjectSetString(0,name,OBJPROP_TEXT,text);
}

void AI2_DrawStatusBox(string name,string text,int x,int y,int w,int h,color bg,color txtclr,int size)
{
   AI2_DrawPanel(name+"_box",x,y,w,h,bg,bg);
   AI2_DrawLabel(name+"_txt",text,x+8,y+5,txtclr,size);
}

void AI2_DeleteDashboardObjects()
{
   int total=ObjectsTotal(0);
   for(int i=total-1;i>=0;i--)
   {
      string name=ObjectName(0,i);
      if(StringFind(name,"yy_")==0) ObjectDelete(0,name);
   }
}

//+------------------------------------------------------------------+
//| 19. DASHBOARD HELPER FUNCTIONS                                   |
//+------------------------------------------------------------------+
string AI2_BoolText(bool v,string y,string n){ return (v?y:n); }
color AI2_RiskColor(){ if(g_risk==RISK_SAFE) return clrGood; if(g_risk==RISK_WARNING) return clrWarn; return clrBad; }
color AI2_ActionColor(){ if(g_regime==REGIME_CHAOTIC) return C'160,0,255'; if(g_mode==MODE_PAUSE) return clrBad; if(g_direction==1) return clrGood; if(g_direction==-1) return clrBad; if(g_dca_allow) return clrWarn; return clrInfo; }
string AI2_DirText(){ if(g_direction==1) return "BUY"; if(g_direction==-1) return "SELL"; return "NONE"; }
string AI2_BigSignalText(){ if(SmartPause_IsActive()&&g_hedge_allow) return "SMART PAUSE"; if(g_mode==MODE_PAUSE) return "AI PAUSE"; if(g_direction==1) return "BUY ONLY"; if(g_direction==-1) return "SELL ONLY"; return "WAIT"; }
string AI2_TradePermissionText(){ if(g_entry_allow) return "ENTRY READY"; if(g_dca_allow) return "DCA READY"; if(g_hedge_allow&&SmartPause_IsActive()) return "RESCUE HEDGE"; if(g_hedge_allow) return "HEDGE CHECK"; if(g_mode==MODE_PAUSE) return "NO ENTRY"; return "WAIT"; }
string AI2_MTFSyncText(){ if(g_regime==REGIME_CHAOTIC||g_mode==MODE_PAUSE) return "IGNORED"; int m1=TrendDir(PERIOD_M1),m5=TrendDir(PERIOD_M5),m15=TrendDir(PERIOD_M15); if(m1==0||m5==0||m15==0) return "MIXED"; if(m1==m5&&m5==m15) return "ALIGN"; return "CONFLICT"; }

int AI2_ConfidenceScore()
{
   int score=50;
   string mtf=AI2_MTFSyncText();
   if(g_regime==REGIME_TREND_UP||g_regime==REGIME_TREND_DOWN) score+=20;
   if(mtf=="ALIGN") score+=20;
   if(SpreadPoints()<=Max_Spread_Points) score+=10;
   if(g_fvg_bull_valid||g_fvg_bear_valid) score+=10; // FVG bonus
   if(g_ob_bull_valid||g_ob_bear_valid) score+=5;    // OB bonus
   if(g_risk==RISK_WARNING) score-=15;
   if(g_risk==RISK_DANGER||g_risk==RISK_EMERGENCY) score-=35;
   if(g_regime==REGIME_CHAOTIC) score-=35;
   if(NewsBlocked()) score-=25;
   return MathMax(0,MathMin(100,score));
}

int    AI2_DCALevel(){ int b=CountPos(1), s=CountPos(-1); return MathMax(b,s); }
string AI2_CycleStatusText(){ if(CountPos()==0) return "IDLE"; if(HasHedge()) return "HEDGE DEFENSE"; return "RUNNING"; }
string AI2_HedgeStatusText(){ if(HasHedge()) return "DEFENSE ACTIVE"; if(g_hedge_allow) return "READY"; return "WAIT"; }

double AI2_NextDCAPrice()
{
   int b=CountPos(1), s=CountPos(-1), dir=0;
   if(b>s) dir=1; else if(s>b) dir=-1; else return 0;
   double last=LastPrice(dir), pt=SymbolInfoDouble(g_symbol,SYMBOL_POINT);
   if(last<=0||pt<=0) return 0;
   int step=DCAStep();
   return (dir==1 ? last-step*pt : last+step*pt);
}

string AI2_PriceText(double p){ if(p<=0) return "N/A"; return DoubleToString(p,(int)SymbolInfoInteger(g_symbol,SYMBOL_DIGITS)); }

double AI2_CurrentTargetTP(){ return (Use_Dynamic_BasketTP&&g_mode==MODE_HEDGE_DEFENSE ? Basket_TP_Hedge_Mode_USD : Basket_TP_Normal_USD); }

string AI2_AIReasonText()
{
   if(SmartPause_IsActive()&&g_hedge_allow) return "Smart Pause: entry/DCA blocked, rescue hedge allowed.";
   if(g_regime==REGIME_CHAOTIC) return "Chaotic market - entry/DCA paused.";
   if(g_risk==RISK_EMERGENCY) return "Emergency DD - closing all.";
   if(g_risk==RISK_DANGER) return "Danger DD - no new entries.";
   if(Use_FVG_Filter&&g_direction!=0&&!MicrostructureAllow(g_direction)) return "FVG filter: no valid gap at current price.";
   if(g_entry_allow&&g_direction==1) return "Regime+FVG+MTF aligned - BUY priority.";
   if(g_entry_allow&&g_direction==-1) return "Regime+FVG+MTF aligned - SELL priority.";
   if(g_dca_allow) return "Cycle active - watching DCA distance.";
   if(NewsBlocked()) return "News block active - no orders.";
   if(SpreadPoints()>Max_Spread_Points) return "Spread too high - waiting.";
   return "Waiting for FVG + regime alignment.";
}

// Dynamic exit status
string DynExitStatusText()
{
   if(!Use_Exit_Engine) return "OFF";
   double lock=DynLockThreshold(), trail=DynTrailAmount(), be=DynBEThreshold();
   return "BE:"+DoubleToString(be,1)+" LK:"+DoubleToString(lock,1)+" TR:"+DoubleToString(trail,1);
}

//+------------------------------------------------------------------+
//| 20. REHEDGE PANEL MODULE                                         |
//+------------------------------------------------------------------+
int AI2_ReHedgeCooldownLeftSec(){ int cd=ReHedge_Cooldown_Min*60; int passed=(int)(TimeCurrent()-g_last_rehedge_time); if(g_last_rehedge_time<=0) return 0; return MathMax(0,cd-passed); }
string AI2_SecondsToMMSS(int sec){ if(sec<0) sec=0; return IntegerToString(sec/60)+"m"+IntegerToString(sec%60)+"s"; }
double AI2_NextReHedgeLot(){ if(!Use_ReHedge_AI||!Use_ReHedge||CountPos(1)==0||CountPos(-1)==0) return 0; int main=(TotalLots(-1)>TotalLots(1)?-1:1); return NormLot(TotalLots(main)*ReHedge_Ratio); }

string AI2_ReHedgeStatusText()
{
   if(!Use_ReHedge_AI||!Use_ReHedge) return "OFF";
   if(CountPos(1)==0||CountPos(-1)==0) return "WAIT HEDGE";
   int left=AI2_ReHedgeCooldownLeftSec();
   if(left>0) return "COOLDOWN";
   if(BasketProfit()>Hedge_Trigger_DD_USD*1.5) return "WAIT LOSS";
   if(SmartPause_CanRescueReHedge()) return "RESCUE READY";
   if(g_mode==MODE_HEDGE_DEFENSE) return "READY";
   return "WAIT";
}

color AI2_ReHedgeStatusColor(){ string st=AI2_ReHedgeStatusText(); if(st=="READY"||st=="RESCUE READY") return clrGood; if(st=="COOLDOWN") return clrWarn; if(st=="OFF") return clrText; return clrInfo; }

void AI2_ReHedgeSeparatePanel()
{
   if(!Show_ReHedge_Status_Dashboard||!Dashboard_Show_ReHedge_Separate) return;
   bool hasHedge=HasHedge();
   if(Dashboard_AutoHide_ReHedge_Panel&&!hasHedge)
   {
      string names[]={"yy_rh2_bg","yy_rh2_title","yy_rh2_state","yy_rh2_next","yy_rh2_lot","yy_rh2_count","yy_rh2_why"};
      for(int i=0;i<7;i++) ObjectDelete(0,names[i]);
      return;
   }
   int x=Dashboard_ReHedge_Panel_X, y=Dashboard_ReHedge_Panel_Y;
   color rhColor=AI2_ReHedgeStatusColor();
   AI2_DrawPanel("yy_rh2_bg",x,y,290,160,clrBlack,rhColor);
   AI2_DrawLabel("yy_rh2_title","REHEDGE PANEL",x+12,y+10,clrInfo,10);
   AI2_DrawLabel("yy_rh2_state","STATUS : "+AI2_ReHedgeStatusText(),x+12,y+34,rhColor,Dashboard_FontSize);
   AI2_DrawLabel("yy_rh2_next","NEXT   : "+AI2_SecondsToMMSS(AI2_ReHedgeCooldownLeftSec()),x+12,y+56,clrText,Dashboard_FontSize);
   AI2_DrawLabel("yy_rh2_lot","LOT    : "+DoubleToString(AI2_NextReHedgeLot(),2),x+12,y+78,clrText,Dashboard_FontSize);
   int rhCount=(hasHedge?MathMax(0,MathMin(CountPos(1),CountPos(-1))-1):0);
   AI2_DrawLabel("yy_rh2_count","COUNT  : "+IntegerToString(rhCount),x+12,y+100,clrText,Dashboard_FontSize);
   AI2_DrawLabel("yy_rh2_why","FVG    : "+FVGStatusText(),x+12,y+122,clrInfo,Dashboard_FontSize);
   AI2_DrawLabel("yy_rh2_dyn","DYN-EXIT: "+DynExitStatusText(),x+12,y+144,clrWarn,Dashboard_FontSize);
}

//+------------------------------------------------------------------+
//| 21. SCALPER STATUS PANEL (NEW V6)                               |
//+------------------------------------------------------------------+
void AI2_ScalperPanel()
{
   if(!Use_Bulk_Scalper||!Use_Dashboard_AI) return;
   int x=Dashboard_ReHedge_Panel_X;
   int y=Dashboard_ReHedge_Panel_Y + 175;
   int w=290;
   int activeSlots=MathMin(Scalper_Max_Trades,7);
   int h=40+activeSlots*22;

   AI2_DrawPanel("yy_sc_bg",x,y,w,h,clrBlack,clrScalper);
   AI2_DrawLabel("yy_sc_title","BULK SCALPER  ["+IntegerToString(activeSlots)+"/7 SLOTS]",x+12,y+10,clrScalper,10);

   double totalScalperP=0;
   for(int i=0;i<activeSlots;i++)
   {
      string alive=ScalperTicketAlive(i)?"[ON]":"[--]";
      double p=ScalperTicketProfit(i);
      totalScalperP+=p;
      color sc=(p>=0?clrGood:clrBad);
      if(ScalperTicketAlive(i)&&g_scalper[i].trailing_armed) sc=clrWarn;
      string trail=(g_scalper[i].trailing_armed?" TRL":"");
      string slotText=alive+" S"+IntegerToString(i+1)+" L"+DoubleToString(g_scalper[i].lot,2)+" TP$"+DoubleToString(g_scalper[i].tp_usd,1)+" P$"+DoubleToString(p,2)+trail;
      AI2_DrawLabel("yy_sc_s"+IntegerToString(i),slotText,x+12,y+32+i*22,sc,8);
   }
   AI2_DrawLabel("yy_sc_total","TOTAL P/L: $"+DoubleToString(totalScalperP,2),x+12,y+h-14,totalScalperP>=0?clrGood:clrBad,9);
}

//+------------------------------------------------------------------+
//| 22. MAIN DASHBOARD                                               |
//+------------------------------------------------------------------+
void AI2_MaxProDashboard()
{
   if(!Use_Dashboard_AI||!Use_FinalElite_Dashboard) return;

   int x=Dashboard_X, y=Dashboard_Y, w=Dashboard_Width;
   int h=590;

   color riskClr=AI2_RiskColor();
   color actionClr=AI2_ActionColor();
   color profitClr=(BasketProfit()>=0?clrGood:clrBad);
   color spreadClr=(SpreadPoints()<=Max_Spread_Points?clrGood:clrBad);
   color bigBg=(Use_BigSignal_Color?actionClr:clrPanel2);

   int conf=AI2_ConfidenceScore();
   color confClr=(conf>=75?clrGood:(conf>=50?clrWarn:clrBad));

   string mtf=AI2_MTFSyncText();
   color mtfClr=(mtf=="ALIGN"?clrGood:(mtf=="CONFLICT"?clrBad:clrWarn));
   color newsColor=(NewsBlocked()?clrBad:clrGood);
   color entryColor=(g_entry_allow?clrGood:clrWarn);
   color dcaColor=(g_dca_allow?clrGood:clrWarn);
   color rehedgeColor=(Use_ReHedge?clrGood:clrWarn);

   // PANEL 1: HEADER
   AI2_DrawPanel("yy_bg",x,y,w,h,clrBlack,clrInfo);
   AI2_DrawPanel("yy_header",x+4,y+4,w-8,46,clrPanel2,clrTitle);
   AI2_DrawLabel("yy_title","YINYANG AI V6 - FVG SCALPER MAXPRO",x+14,y+11,clrTitle,12);
   AI2_DrawLabel("yy_sub",g_symbol+" | M1 | Magic:"+IntegerToString((int)Magic_Number)+" | "+AttackModeText(),x+14,y+31,clrText,8);

   // PANEL 2: BIG SIGNAL
   AI2_DrawPanel("yy_decision",x+10,y+58,w-20,68,bigBg,actionClr);
   AI2_DrawLabel("yy_big_signal",AI2_BigSignalText(),x+24,y+68,clrWhite,16);
   string nextAct=(g_entry_allow?(g_direction==1?"ENTRY BUY":"ENTRY SELL"):(g_dca_allow?"DCA CHECK":(g_hedge_allow?"HEDGE CHECK":"WAIT")));
   AI2_DrawLabel("yy_next","NEXT: "+nextAct+" | FVG: "+FVGStatusText(),x+24,y+96,clrWhite,9);
   AI2_DrawStatusBox("yy_trade_perm",AI2_TradePermissionText(),x+w-162,y+72,138,28,clrBlack,actionClr,9);
   AI2_DrawLabel("yy_conf","CONFIDENCE: "+IntegerToString(conf)+"%",x+w-162,y+106,confClr,9);

   // PANEL 3: AI STATE
   int p3y=y+136;
   AI2_DrawPanel("yy_ai_state",x+10,p3y,w-20,100,clrBlack,clrInfo);
   AI2_DrawLabel("yy_ai_title","AI STATE",x+22,p3y+8,clrInfo,10);
   AI2_DrawLabel("yy_regime","REGIME     : "+RegimeText(),x+22,p3y+28,clrText,9);
   AI2_DrawLabel("yy_mode","MODE       : "+ModeText(),x+22,p3y+46,clrText,9);
   AI2_DrawLabel("yy_dir","DIRECTION  : "+AI2_DirText(),x+22,p3y+64,actionClr,9);
   AI2_DrawLabel("yy_fvg","FVG FILTER : "+FVGStatusText(),x+22,p3y+82,clrInfo,9);
   AI2_DrawLabel("yy_mtf","MTF SYNC   : "+mtf,x+240,p3y+28,mtfClr,9);
   AI2_DrawLabel("yy_spread","SPREAD     : "+IntegerToString(SpreadPoints())+" / "+IntegerToString(Max_Spread_Points),x+240,p3y+46,spreadClr,9);
   AI2_DrawLabel("yy_atr","ATR M1/M5  : "+DoubleToString(ATRPoints(PERIOD_M1),0)+" / "+DoubleToString(ATRPoints(PERIOD_M5),0),x+240,p3y+64,clrText,9);
   AI2_DrawLabel("yy_news","NEWS BLOCK : "+AI2_BoolText(NewsBlocked(),"ON","OFF"),x+240,p3y+82,newsColor,9);

   // PANEL 4: ENGINE STATUS
   int p4y=p3y+110;
   AI2_DrawPanel("yy_engine",x+10,p4y,w-20,100,clrBlack,clrInfo);
   AI2_DrawLabel("yy_engine_title","ENGINE STATUS",x+22,p4y+8,clrInfo,10);
   AI2_DrawLabel("yy_entry","ENTRY  : "+AI2_BoolText(g_entry_allow,"ALLOW","BLOCK"),x+22,p4y+32,entryColor,9);
   AI2_DrawLabel("yy_dca","DCA    : "+AI2_BoolText(g_dca_allow,"READY","WAIT/BLOCK"),x+22,p4y+52,dcaColor,9);
   AI2_DrawLabel("yy_hedge","HEDGE  : "+AI2_HedgeStatusText(),x+22,p4y+72,clrText,9);
   AI2_DrawLabel("yy_smart","PAUSE  : "+SmartPauseStatusText(),x+22,p4y+82,rehedgeColor,9);
   double ndp=AI2_NextDCAPrice();
   AI2_DrawLabel("yy_dca_lv","DCA LEVEL     : "+IntegerToString(AI2_DCALevel())+" / "+IntegerToString(GetModeMaxDCA()),x+240,p4y+32,clrText,9);
   AI2_DrawLabel("yy_dca_step","NEXT DCA STEP : "+IntegerToString(DCAStep())+" pts",x+240,p4y+52,clrText,9);
   AI2_DrawLabel("yy_next_dca","NEXT DCA PRICE: "+AI2_PriceText(ndp),x+240,p4y+72,clrText,9);
   AI2_DrawLabel("yy_tp1","TP1 STATUS    : "+AI2_BoolText(g_tp1_done,"DONE","WAIT"),x+240,p4y+82,(g_tp1_done?clrGood:clrText),9);

   // PANEL 5: DYNAMIC EXIT
   int p5y=p4y+110;
   AI2_DrawPanel("yy_dynex",x+10,p5y,w-20,52,clrBlack,clrWarn);
   AI2_DrawLabel("yy_dynex_title","DYNAMIC EXIT ENGINE",x+22,p5y+6,clrWarn,10);
   AI2_DrawLabel("yy_dynex_vals",DynExitStatusText()+"  |  ATR-SPIKE: "+AI2_BoolText(IsATRSpike(),"YES","NO")+"  |  PEAK: $"+DoubleToString(g_highest_profit,2),x+22,p5y+28,clrText,9);

   // PANEL 6: CYCLE / RISK
   int p6y=p5y+62;
   AI2_DrawPanel("yy_risk_panel",x+10,p6y,w-20,100,clrBlack,riskClr);
   AI2_DrawLabel("yy_risk_title","CYCLE / RISK",x+22,p6y+8,clrInfo,10);
   AI2_DrawLabel("yy_orders","ORDERS    : "+IntegerToString(CountPos())+" / "+IntegerToString(Max_Total_Orders),x+22,p6y+32,clrText,9);
   AI2_DrawLabel("yy_lots","TOTAL LOT : "+DoubleToString(TotalLots(),2)+" / "+DoubleToString(Max_Total_Lot,2),x+22,p6y+52,clrText,9);
   AI2_DrawLabel("yy_profit","BASKET P/L: $"+DoubleToString(BasketProfit(),2),x+22,p6y+72,profitClr,9);
   AI2_DrawLabel("yy_tp","TARGET TP : $"+DoubleToString(AI2_CurrentTargetTP(),2),x+22,p6y+82,clrText,9);
   AI2_DrawLabel("yy_risk","RISK STATE: "+RiskText(),x+240,p6y+32,riskClr,9);
   AI2_DrawLabel("yy_dd","EQUITY DD : "+DoubleToString(DDPercent(),2)+"%",x+240,p6y+52,riskClr,9);
   AI2_DrawLabel("yy_daily","DAILY LOSS: "+DoubleToString(DailyLossPercent(),2)+"%",x+240,p6y+72,clrText,9);
   AI2_DrawLabel("yy_margin","FREE MARGIN: "+DoubleToString(AccountInfoDouble(ACCOUNT_MARGIN_FREE),0),x+240,p6y+82,clrText,9);

   // PANEL 7: SCALPER SUMMARY
   int p7y=p6y+110;
   AI2_DrawPanel("yy_sc_sum",x+10,p7y,w-20,52,clrBlack,clrScalper);
   AI2_DrawLabel("yy_sc_sum_title","BULK SCALPER",x+22,p7y+6,clrScalper,10);
   AI2_DrawLabel("yy_sc_sum_val",ScalperSummaryText(),x+22,p7y+26,clrText,9);

   // PANEL 8: AI MESSAGE
   int p8y=p7y+62;
   AI2_DrawPanel("yy_msg_panel",x+10,p8y,w-20,42,clrPanel2,clrInfo);
   AI2_DrawLabel("yy_msg","AI MESSAGE:",x+20,p8y+7,clrInfo,9);
   AI2_DrawLabel("yy_msg2",AI2_AIReasonText(),x+20,p8y+23,clrText,8);

   // Side panels
   AI2_ReHedgeSeparatePanel();
   AI2_ScalperPanel();
}

//+------------------------------------------------------------------+
//| 23. MAIN PIPELINE OnTick                                        |
//+------------------------------------------------------------------+
void AI2_OnTick()
{
   if(!Use_AI_Level2){ if(Use_Dashboard_AI) Comment("AI LEVEL 2 OFF"); return; }

   // 1-6: ANALYSIS
   DetectRegime();
   UpdateRisk();
   UpdateAttackMode();
   SelectMode();           // Single mode selector (fixed V5 duplication)
   ScanFVG();              // NEW: microstructure scan
   ScanOrderBlocks();      // NEW: order block scan
   BuildDecision();

   // HARD STOP
   if(g_risk==RISK_EMERGENCY){ Print("[AI2] EMERGENCY STOP"); return; }

   // 7-8: EXIT FIRST
   TryExit();
   TryExitEngine();        // Dynamic ATR-adaptive exit

   // 9-10: RECOVERY
   TrySmartUnwind();
   TryTP1ProAI();

   // 11-12: ENTRY
   TryEntry();
   TryDCA();

   // 13-14: DEFENSE
   TryHedge();
   TryReHedge();

   // 15: BULK SCALPER (runs independently)
   RunBulkScalper();

   // 16: DASHBOARD
   AI2_MaxProDashboard();
}

//+------------------------------------------------------------------+
//| 24. INIT / DEINIT                                               |
//+------------------------------------------------------------------+
int OnInit()
{
   g_symbol = (Trade_Symbol=="" ? _Symbol : Trade_Symbol);
   g_start_day_equity = AccountInfoDouble(ACCOUNT_EQUITY);
   MqlDateTime n; TimeToStruct(TimeCurrent(),n); g_day_of_year=n.day_of_year;

   // Create all indicator handles once (fixes V5 per-tick allocation bug)
   h_atr_m1      = iATR(g_symbol, PERIOD_M1, ATR_Period);
   h_atr_m5      = iATR(g_symbol, PERIOD_M5, ATR_Period);
   h_ema_fast_m1 = iMA(g_symbol, PERIOD_M1, EMA_Fast_Period, 0, MODE_EMA, PRICE_CLOSE);
   h_ema_slow_m1 = iMA(g_symbol, PERIOD_M1, EMA_Slow_Period, 0, MODE_EMA, PRICE_CLOSE);
   h_ema_fast_m5 = iMA(g_symbol, PERIOD_M5, EMA_Fast_Period, 0, MODE_EMA, PRICE_CLOSE);
   h_ema_slow_m5 = iMA(g_symbol, PERIOD_M5, EMA_Slow_Period, 0, MODE_EMA, PRICE_CLOSE);
   h_ema_fast_m15= iMA(g_symbol, PERIOD_M15, EMA_Fast_Period, 0, MODE_EMA, PRICE_CLOSE);
   h_ema_slow_m15= iMA(g_symbol, PERIOD_M15, EMA_Slow_Period, 0, MODE_EMA, PRICE_CLOSE);
   h_atr_m1_long = iATR(g_symbol, PERIOD_M1, Exit_ATR_Avg_Period); // Longer ATR for spike detection

   if(h_atr_m1==INVALID_HANDLE||h_ema_fast_m1==INVALID_HANDLE)
   {
      Print("[AI2 INIT FAIL] Cannot create indicator handles. Check symbol/terminal.");
      return INIT_FAILED;
   }

   InitScalperSlots();

   Print("[AI2 INIT V6.00] ",g_symbol," | FVG:",Use_FVG_Filter," | Scalper:",Use_Bulk_Scalper," | DynExit:",Use_Exit_Engine);
   for(int i=0; i<MathMin(Scalper_Max_Trades,7); i++)
      Print("[SCALPER SLOT ",i+1,"] Lot=",g_scalper[i].lot," TP=$",g_scalper[i].tp_usd);

   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
   // Release all indicator handles
   int handles[] = {h_atr_m1,h_atr_m5,h_ema_fast_m1,h_ema_slow_m1,h_ema_fast_m5,h_ema_slow_m5,h_ema_fast_m15,h_ema_slow_m15,h_atr_m1_long};
   for(int i=0;i<9;i++) if(handles[i]!=INVALID_HANDLE) IndicatorRelease(handles[i]);
   AI2_DeleteDashboardObjects();
   Comment("");
   Print("[AI2 DEINIT V6.00] reason=",reason);
}

void OnTick(){ AI2_OnTick(); }
//+------------------------------------------------------------------+