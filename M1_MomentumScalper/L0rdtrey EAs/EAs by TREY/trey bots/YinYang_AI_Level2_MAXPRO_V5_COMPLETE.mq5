//+------------------------------------------------------------------+
//| YinYang_AI_Level2_MAXPRO_V5_COMPLETE.mq5                        |
//| Standalone AI Level 2 PRO EA - XAUUSD M1                        |
//| Version: 5.00 - COMPLETE WITH EXIT ENGINE + MULTI-MODE          |
//+------------------------------------------------------------------+
#property strict
#property version "5.00"

enum AI2_REGIME { REGIME_UNKNOWN=0, REGIME_TREND_UP, REGIME_TREND_DOWN, REGIME_SIDEWAY, REGIME_VOLATILE, REGIME_CHAOTIC };
enum AI2_MODE   { MODE_PAUSE=0, MODE_SCALP, MODE_TREND, MODE_SAFE, MODE_HEDGE_DEFENSE };
enum AI2_RISK   { RISK_SAFE=0, RISK_WARNING, RISK_DANGER, RISK_EMERGENCY };
enum AI2_ATTACK_MODE { ATTACK_SAFE=0, ATTACK_ACTIVE, ATTACK_RECOVERY };

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
input int  Dashboard_Width            = 430;
input int  Dashboard_FontSize         = 9;
input bool Show_ReHedge_Status_Dashboard = true;
input bool Dashboard_Show_ReHedge_Separate = true;
input bool Dashboard_AutoHide_ReHedge_Panel = true;
input int  Dashboard_ReHedge_Panel_X  = 455;
input int  Dashboard_ReHedge_Panel_Y  = 18;

// ===== DASHBOARD COLORS =====
color clrGood  = clrLime;
color clrWarn  = clrYellow;
color clrBad   = clrRed;
color clrTitle = clrGold;
color clrText  = clrWhite;
color clrInfo  = clrAqua;
color clrPanel = clrBlack;
color clrPanel2 = C'48,48,48';

// ===== CORE =====
input string Trade_Symbol             = "";
input long   Magic_Number             = 26042822;
input bool   One_Order_Per_Bar        = true;
input int    Min_Seconds_Between_Orders = 30;
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

// ===== LOT CONTROL (BASE) =====
input double Base_Lot                 = 0.03;
input double Min_Lot                  = 0.01;
input double Max_Lot                  = 0.30;
input double DD_Reduce_Lot_At_Percent = 3.0;
input double Lot_Reduce_Factor        = 0.50;
input double Volatility_Lot_Reduce    = 0.50;

// ===== MULTI-MODE LOT CONTROL (NEW) =====
input bool   Use_Multi_Mode_Lot       = true;  // Bật/tắt multi-mode lot
// SAFE MODE
input double Safe_Base_Lot            = 0.02;
input int    Safe_Max_DCA             = 5;
input double Safe_Multiplier          = 1.25;
input double Safe_Hedge_Ratio         = 0.5;
// ATTACK MODE
input double Attack_Base_Lot          = 0.03;
input int    Attack_Max_DCA           = 4;
input double Attack_Multiplier        = 1.35;
input double Attack_Hedge_Ratio       = 0.3;
// RECOVERY MODE
input double Recovery_Base_Lot        = 0.015;
input int    Recovery_Max_DCA         = 6;
input double Recovery_Multiplier      = 1.2;
input double Recovery_Hedge_Ratio     = 0.7;

// ===== MODE SWITCH CONDITIONS (NEW) =====
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

// ===== EXIT ENGINE (NEW) =====
input bool   Use_Exit_Engine          = true;   // Bật/tắt exit engine
input double Exit_BE_USD              = -1.0;   // Breakeven threshold
input double Exit_Lock_USD            = 8.0;    // Lock profit
input double Exit_Trail_USD           = 4.0;    // Trailing stop
input int    Exit_Max_Time_Min        = 45;     // Max holding time

// ===== RISK ENGINE =====
input double Max_Equity_DD_Stop_Percent = 12.0;
input double Daily_Loss_Limit_Percent   = 5.0;
input double Emergency_Close_DD_Percent = 15.0;
input int    Cooldown_After_Cycle_Sec   = 60;
input int    Max_Total_Orders           = 12;
input double Max_Total_Lot              = 1.20;

// ===== SESSION / NEWS TIME BLOCK =====
input bool Use_Time_Filter             = false;
input int  Trade_Start_Hour            = 7;
input int  Trade_End_Hour              = 23;
input bool Use_News_Time_Block         = true;
input int  News_Block_Start_Hour       = 19;
input int  News_Block_End_Hour         = 21;

// ===== GLOBAL VARIABLES =====
string g_symbol;
AI2_REGIME g_regime = REGIME_UNKNOWN;
AI2_MODE   g_mode = MODE_PAUSE;
AI2_RISK   g_risk = RISK_SAFE;
AI2_ATTACK_MODE g_attack_mode = ATTACK_SAFE;

bool g_entry_allow=false, g_dca_allow=false, g_hedge_allow=false, g_exit_allow=false;
int g_direction=0;
datetime g_last_order_time=0, g_last_bar_time=0, g_last_cycle_close_time=0, g_last_rehedge_time=0;
bool g_tp1_done=false;
ulong g_tp1_first_ticket=0;
datetime g_tp1_cycle_start_time=0;
double g_start_day_equity=0;
int g_day_of_year=-1;
datetime g_last_unwind_time = 0;

// Exit Engine variables
datetime g_last_exit_check_time = 0;
double g_highest_profit = 0;
double g_lowest_profit = 0;

//+------------------------------------------------------------------+
//| 1. HELPER FUNCTIONS (Text, Indicator, Math)                      |
//+------------------------------------------------------------------+
string RegimeText(){ if(g_regime==REGIME_TREND_UP) return "TREND_UP"; if(g_regime==REGIME_TREND_DOWN) return "TREND_DOWN"; if(g_regime==REGIME_SIDEWAY) return "SIDEWAY"; if(g_regime==REGIME_VOLATILE) return "VOLATILE"; if(g_regime==REGIME_CHAOTIC) return "CHAOTIC"; return "UNKNOWN"; }
string ModeText(){ if(g_mode==MODE_SCALP) return "SCALP"; if(g_mode==MODE_TREND) return "TREND"; if(g_mode==MODE_SAFE) return "SAFE"; if(g_mode==MODE_HEDGE_DEFENSE) return "HEDGE_DEFENSE"; return "PAUSE"; }
string RiskText(){ if(g_risk==RISK_WARNING) return "WARNING"; if(g_risk==RISK_DANGER) return "DANGER"; if(g_risk==RISK_EMERGENCY) return "EMERGENCY"; return "SAFE"; }
string AttackModeText(){ if(g_attack_mode==ATTACK_ACTIVE) return "ATTACK"; if(g_attack_mode==ATTACK_RECOVERY) return "RECOVERY"; return "SAFE"; }

double IndVal(int h,int b,int s){ double a[]; ArraySetAsSeries(a,true); if(CopyBuffer(h,b,s,1,a)<=0) return 0; return a[0]; }
double ATRPoints(ENUM_TIMEFRAMES tf){ int h=iATR(g_symbol,tf,ATR_Period); if(h==INVALID_HANDLE) return 0; double v=IndVal(h,0,0); IndicatorRelease(h); double p=SymbolInfoDouble(g_symbol,SYMBOL_POINT); return (p>0 ? v/p : 0); }
double EMA(ENUM_TIMEFRAMES tf,int period){ int h=iMA(g_symbol,tf,period,0,MODE_EMA,PRICE_CLOSE); if(h==INVALID_HANDLE) return 0; double v=IndVal(h,0,0); IndicatorRelease(h); return v; }
int TrendDir(ENUM_TIMEFRAMES tf){ double f=EMA(tf,EMA_Fast_Period), s=EMA(tf,EMA_Slow_Period); double p=SymbolInfoDouble(g_symbol,SYMBOL_POINT); if(f<=0||s<=0||p<=0) return 0; if(MathAbs(f-s)/p<50) return 0; return (f>s?1:-1); }

int SpreadPoints(){ double p=SymbolInfoDouble(g_symbol,SYMBOL_POINT); if(p<=0) return 999999; return (int)MathRound((SymbolInfoDouble(g_symbol,SYMBOL_ASK)-SymbolInfoDouble(g_symbol,SYMBOL_BID))/p); }
double DDPercent(){ double b=AccountInfoDouble(ACCOUNT_BALANCE), e=AccountInfoDouble(ACCOUNT_EQUITY); if(b<=0) return 0; return MathMax(0,(b-e)/b*100); }
double DailyLossPercent(){ MqlDateTime t; TimeToStruct(TimeCurrent(),t); if(g_day_of_year!=t.day_of_year || g_start_day_equity<=0){ g_day_of_year=t.day_of_year; g_start_day_equity=AccountInfoDouble(ACCOUNT_EQUITY);} double e=AccountInfoDouble(ACCOUNT_EQUITY); return (g_start_day_equity>0 ? MathMax(0,(g_start_day_equity-e)/g_start_day_equity*100) : 0); }

bool TradingHour(){ if(!Use_Time_Filter) return true; MqlDateTime t; TimeToStruct(TimeCurrent(),t); if(Trade_Start_Hour<=Trade_End_Hour) return (t.hour>=Trade_Start_Hour && t.hour<Trade_End_Hour); return (t.hour>=Trade_Start_Hour || t.hour<Trade_End_Hour); }
bool NewsBlocked(){ if(!Use_News_Time_Block) return false; MqlDateTime t; TimeToStruct(TimeCurrent(),t); if(News_Block_Start_Hour<=News_Block_End_Hour) return (t.hour>=News_Block_Start_Hour && t.hour<News_Block_End_Hour); return (t.hour>=News_Block_Start_Hour || t.hour<News_Block_End_Hour); }

bool IsOurPos(){ return PositionGetString(POSITION_SYMBOL)==g_symbol && (long)PositionGetInteger(POSITION_MAGIC)==Magic_Number; }
int CountPos(int dir=0){ int c=0; for(int i=PositionsTotal()-1;i>=0;i--){ ulong tk=PositionGetTicket(i); if(tk==0||!PositionSelectByTicket(tk)||!IsOurPos()) continue; long type=PositionGetInteger(POSITION_TYPE); if(dir==1&&type!=POSITION_TYPE_BUY) continue; if(dir==-1&&type!=POSITION_TYPE_SELL) continue; c++; } return c; }
double TotalLots(int dir=0){ double l=0; for(int i=PositionsTotal()-1;i>=0;i--){ ulong tk=PositionGetTicket(i); if(tk==0||!PositionSelectByTicket(tk)||!IsOurPos()) continue; long type=PositionGetInteger(POSITION_TYPE); if(dir==1&&type!=POSITION_TYPE_BUY) continue; if(dir==-1&&type!=POSITION_TYPE_SELL) continue; l+=PositionGetDouble(POSITION_VOLUME);} return l; }
double BasketProfit(){ double p=0; for(int i=PositionsTotal()-1;i>=0;i--){ ulong tk=PositionGetTicket(i); if(tk==0||!PositionSelectByTicket(tk)||!IsOurPos()) continue; p+=PositionGetDouble(POSITION_PROFIT)+PositionGetDouble(POSITION_SWAP);} return p; }
double LastPrice(int dir){ datetime lt=0; double pr=0; for(int i=PositionsTotal()-1;i>=0;i--){ ulong tk=PositionGetTicket(i); if(tk==0||!PositionSelectByTicket(tk)||!IsOurPos()) continue; long type=PositionGetInteger(POSITION_TYPE); if(dir==1&&type!=POSITION_TYPE_BUY) continue; if(dir==-1&&type!=POSITION_TYPE_SELL) continue; datetime ot=(datetime)PositionGetInteger(POSITION_TIME); if(ot>=lt){ lt=ot; pr=PositionGetDouble(POSITION_PRICE_OPEN); }} return pr; }

bool HasHedge() { return (TotalLots(1)>0.0 && TotalLots(-1)>0.0); }

//+------------------------------------------------------------------+
//| 2. TRADE EXECUTION FUNCTIONS                                     |
//+------------------------------------------------------------------+
double NormLot(double lot){ double minv=SymbolInfoDouble(g_symbol,SYMBOL_VOLUME_MIN), maxv=SymbolInfoDouble(g_symbol,SYMBOL_VOLUME_MAX), step=SymbolInfoDouble(g_symbol,SYMBOL_VOLUME_STEP); if(step<=0) step=0.01; lot=MathMax(lot,MathMax(minv,Min_Lot)); lot=MathMin(lot,MathMin(maxv,Max_Lot)); lot=MathFloor(lot/step)*step; return NormalizeDouble(lot,2); }
bool CanSend(){ if(SpreadPoints()>Max_Spread_Points || !TradingHour() || NewsBlocked()) return false; if(TimeCurrent()-g_last_order_time<Min_Seconds_Between_Orders) return false; if(One_Order_Per_Bar){ datetime b=iTime(g_symbol,PERIOD_M1,0); if(b==g_last_bar_time) return false; } if(TimeCurrent()-g_last_cycle_close_time<Cooldown_After_Cycle_Sec) return false; return true; }

bool SendOrder(int dir,double lot,string cmt){
   if(!CanSend()) return false;
   if(CountPos()>=Max_Total_Orders) return false;
   if(TotalLots()+lot>Max_Total_Lot) return false;
   MqlTradeRequest r; MqlTradeResult res; ZeroMemory(r); ZeroMemory(res);
   r.action=TRADE_ACTION_DEAL; r.symbol=g_symbol; r.magic=Magic_Number; r.volume=NormLot(lot); r.deviation=Slippage_Points; r.comment=cmt;
   if(dir==1){ r.type=ORDER_TYPE_BUY; r.price=SymbolInfoDouble(g_symbol,SYMBOL_ASK); }
   else if(dir==-1){ r.type=ORDER_TYPE_SELL; r.price=SymbolInfoDouble(g_symbol,SYMBOL_BID); }
   else return false;
   bool ok=OrderSend(r,res);
   if(ok && (res.retcode==TRADE_RETCODE_DONE || res.retcode==TRADE_RETCODE_PLACED)){ g_last_order_time=TimeCurrent(); g_last_bar_time=iTime(g_symbol,PERIOD_M1,0); Print("[AI2 ORDER] ",cmt," lot=",r.volume); return true; }
   Print("[AI2 ORDER FAIL] ",cmt," ret=",res.retcode," err=",GetLastError()); return false;
}

bool CloseTicket(ulong tk){
   if(!PositionSelectByTicket(tk)) return false;
   long type=PositionGetInteger(POSITION_TYPE); double vol=PositionGetDouble(POSITION_VOLUME);
   MqlTradeRequest r; MqlTradeResult res; ZeroMemory(r); ZeroMemory(res);
   r.action=TRADE_ACTION_DEAL; r.symbol=g_symbol; r.magic=Magic_Number; r.position=tk; r.volume=vol; r.deviation=Slippage_Points; r.comment="AI2_CLOSE";
   if(type==POSITION_TYPE_BUY){ r.type=ORDER_TYPE_SELL; r.price=SymbolInfoDouble(g_symbol,SYMBOL_BID); } else { r.type=ORDER_TYPE_BUY; r.price=SymbolInfoDouble(g_symbol,SYMBOL_ASK); }
   bool ok=OrderSend(r,res); return (ok && res.retcode==TRADE_RETCODE_DONE);
}
void CloseAll(){ for(int i=PositionsTotal()-1;i>=0;i--){ ulong tk=PositionGetTicket(i); if(tk==0||!PositionSelectByTicket(tk)||!IsOurPos()) continue; CloseTicket(tk);} g_last_cycle_close_time=TimeCurrent(); g_tp1_done=false; g_tp1_first_ticket=0; g_tp1_cycle_start_time=0; }

//+------------------------------------------------------------------+
//| 3. TP1 PRO AI MODULE                                             |
//+------------------------------------------------------------------+
ulong TP1_GetFirstTicket()
{
   ulong firstTicket=0;
   datetime firstTime=0;
   for(int i=PositionsTotal()-1;i>=0;i--)
   {
      ulong tk=PositionGetTicket(i);
      if(tk==0) continue;
      if(!PositionSelectByTicket(tk)) continue;
      if(!IsOurPos()) continue;
      datetime ot=(datetime)PositionGetInteger(POSITION_TIME);
      if(firstTicket==0 || ot<firstTime)
      {
         firstTicket=tk;
         firstTime=ot;
      }
   }
   return firstTicket;
}

bool TP1_ClosePartialByTicket(ulong tk,double percent)
{
   if(!PositionSelectByTicket(tk)) return false;
   string psym=PositionGetString(POSITION_SYMBOL);
   long pmagic=(long)PositionGetInteger(POSITION_MAGIC);
   if(psym!=g_symbol || pmagic!=Magic_Number) return false;
   double vol=PositionGetDouble(POSITION_VOLUME);
   double closeVol=vol*percent/100.0;
   double minv=SymbolInfoDouble(g_symbol,SYMBOL_VOLUME_MIN);
   double step=SymbolInfoDouble(g_symbol,SYMBOL_VOLUME_STEP);
   if(step<=0.0) step=0.01;
   closeVol=MathFloor(closeVol/step)*step;
   closeVol=NormalizeDouble(closeVol,2);
   if(closeVol<minv) return false;
   if(closeVol>=vol) closeVol=vol;
   long type=PositionGetInteger(POSITION_TYPE);
   MqlTradeRequest r;
   MqlTradeResult res;
   ZeroMemory(r);
   ZeroMemory(res);
   r.action=TRADE_ACTION_DEAL;
   r.symbol=g_symbol;
   r.magic=Magic_Number;
   r.position=tk;
   r.volume=closeVol;
   r.deviation=Slippage_Points;
   r.comment="AI2_TP1_PRO";
   if(type==POSITION_TYPE_BUY)
   {
      r.type=ORDER_TYPE_SELL;
      r.price=SymbolInfoDouble(g_symbol,SYMBOL_BID);
   }
   else
   {
      r.type=ORDER_TYPE_BUY;
      r.price=SymbolInfoDouble(g_symbol,SYMBOL_ASK);
   }
   bool ok=OrderSend(r,res);
   if(ok && res.retcode==TRADE_RETCODE_DONE)
   {
      Print("[TP1 PRO AI] Partial close first order. ticket=",tk," volume=",DoubleToString(closeVol,2));
      return true;
   }
   Print("[TP1 PRO AI FAIL] ticket=",tk," ret=",res.retcode," err=",GetLastError());
   return false;
}

void TP1_ResetIfNewCycle()
{
   if(CountPos()==0)
   {
      g_tp1_done=false;
      g_tp1_first_ticket=0;
      g_tp1_cycle_start_time=0;
      return;
   }
   ulong first=TP1_GetFirstTicket();
   if(first==0) return;
   if(g_tp1_first_ticket==0)
   {
      g_tp1_first_ticket=first;
      if(PositionSelectByTicket(first))
         g_tp1_cycle_start_time=(datetime)PositionGetInteger(POSITION_TIME);
      g_tp1_done=false;
      return;
   }
   if(first!=g_tp1_first_ticket)
   {
      g_tp1_first_ticket=first;
      if(PositionSelectByTicket(first))
         g_tp1_cycle_start_time=(datetime)PositionGetInteger(POSITION_TIME);
      g_tp1_done=false;
   }
}

void TryTP1ProAI()
{
   if(!Use_TP1_PRO_AI) return;
   TP1_ResetIfNewCycle();
   if(CountPos()==0) return;
   if(TP1_Only_Once_Per_Cycle && g_tp1_done) return;
   if(TP1_Disable_When_Hedged)
   {
      if(TotalLots(1)>0.0 && TotalLots(-1)>0.0) return;
      if(g_mode==MODE_HEDGE_DEFENSE) return;
   }
   ulong tk=TP1_GetFirstTicket();
   if(tk==0) return;
   if(!PositionSelectByTicket(tk)) return;
   datetime ot=(datetime)PositionGetInteger(POSITION_TIME);
   if(TimeCurrent()-ot<TP1_Min_Seconds_After_Entry) return;
   double p=PositionGetDouble(POSITION_PROFIT)+PositionGetDouble(POSITION_SWAP);
   if(p<TP1_Profit_USD) return;
   bool ok=TP1_ClosePartialByTicket(tk,TP1_Close_Percent);
   if(ok) g_tp1_done=true;
}

//+------------------------------------------------------------------+
//| 4. SMART UNWIND PRO V4 MODULE                                    |
//+------------------------------------------------------------------+
ulong GetWorstTicket()
{
   double worstProfit = 999999;
   ulong worstTicket = 0;
   for(int i=PositionsTotal()-1;i>=0;i--)
   {
      ulong tk=PositionGetTicket(i);
      if(tk==0) continue;
      if(!PositionSelectByTicket(tk)) continue;
      if(!IsOurPos()) continue;
      double p = PositionGetDouble(POSITION_PROFIT);
      if(p < worstProfit)
      {
         worstProfit = p;
         worstTicket = tk;
      }
   }
   return worstTicket;
}

void TrySmartUnwind()
{
   if(!Use_Smart_Unwind_PRO) return;
   if(TimeCurrent() - g_last_unwind_time < Unwind_Cooldown_Sec) return;
   
   int total = CountPos();
   if(total < Unwind_Min_Orders) return;
   
   if(!HasHedge()) return;
   
   double profit = BasketProfit();
   // V4: cho unwind cả khi gần hòa
   if(profit < -2.0 && profit < Unwind_Min_Profit_USD) return;
   
   ulong tk = GetWorstTicket();
   if(tk == 0) return;
   
   if(!PositionSelectByTicket(tk)) return;
   
   double vol = PositionGetDouble(POSITION_VOLUME);
   double closeVol = vol * Unwind_Close_Percent / 100.0;
   
   double step = SymbolInfoDouble(g_symbol, SYMBOL_VOLUME_STEP);
   closeVol = MathFloor(closeVol / step) * step;
   closeVol = NormalizeDouble(closeVol, 2);
   
   if(closeVol <= 0) return;
   
   long type = PositionGetInteger(POSITION_TYPE);
   
   MqlTradeRequest r;
   MqlTradeResult res;
   ZeroMemory(r);
   ZeroMemory(res);
   
   r.action   = TRADE_ACTION_DEAL;
   r.symbol   = g_symbol;
   r.magic    = Magic_Number;
   r.position = tk;
   r.volume   = closeVol;
   r.deviation= Slippage_Points;
   r.comment  = "SMART_UNWIND_V4";
   
   if(type == POSITION_TYPE_BUY)
   {
      r.type  = ORDER_TYPE_SELL;
      r.price = SymbolInfoDouble(g_symbol, SYMBOL_BID);
   }
   else
   {
      r.type  = ORDER_TYPE_BUY;
      r.price = SymbolInfoDouble(g_symbol, SYMBOL_ASK);
   }
   
   if(OrderSend(r, res) && res.retcode == TRADE_RETCODE_DONE)
   {
      Print("[SMART UNWIND V4] Reduced worst position");
      g_last_unwind_time = TimeCurrent();
   }
}

//+------------------------------------------------------------------+
//| 5. REGIME DETECTION ENGINE                                       |
//+------------------------------------------------------------------+
void DetectRegime(){
   double atr=ATRPoints(Regime_TF_Main); int d=TrendDir(Regime_TF_Main), c=TrendDir(Regime_TF_Confirm);
   if(!Use_Regime_AI){ g_regime=(d>0?REGIME_TREND_UP:(d<0?REGIME_TREND_DOWN:REGIME_SIDEWAY)); return; }
   if(atr>=Chaotic_ATR_Min_Points) g_regime=REGIME_CHAOTIC;
   else if(atr>=Volatile_ATR_Min_Points) g_regime=REGIME_VOLATILE;
   else if(atr<=Sideway_ATR_Max_Points || d==0) g_regime=REGIME_SIDEWAY;
   else if(d>0 && c>=0) g_regime=REGIME_TREND_UP;
   else if(d<0 && c<=0) g_regime=REGIME_TREND_DOWN;
   else g_regime=REGIME_SIDEWAY;
}

//+------------------------------------------------------------------+
//| 5b. ATTACK MODE SWITCH (NEW)                                     |
//+------------------------------------------------------------------+
void UpdateAttackMode()
{
   if(!Use_Multi_Mode_Lot) return;
   
   double dd = DDPercent();
   double profit = BasketProfit();
   double atr = ATRPoints(PERIOD_M1);
   int trendStrength = MathAbs(TrendDir(PERIOD_M5));
   
   // Check recovery conditions first (highest priority)
   if(dd >= Switch_To_Recovery_DD_Percent || profit <= -Switch_To_Recovery_Loss_USD)
   {
      if(g_attack_mode != ATTACK_RECOVERY)
      {
         g_attack_mode = ATTACK_RECOVERY;
         Print("[AI2] Switch to RECOVERY mode | DD=",dd,"% | Profit=",profit);
      }
      return;
   }
   
   // Check attack conditions
   if(atr >= Switch_To_Attack_ATR && trendStrength >= Switch_To_Attack_Trend_Strength)
   {
      if(g_attack_mode != ATTACK_ACTIVE)
      {
         g_attack_mode = ATTACK_ACTIVE;
         Print("[AI2] Switch to ATTACK mode | ATR=",atr," | Strength=",trendStrength);
      }
      return;
   }
   
   // Check back to safe
   if(dd <= Switch_Back_To_Safe_DD_Percent && profit > 0)
   {
      if(g_attack_mode != ATTACK_SAFE)
      {
         g_attack_mode = ATTACK_SAFE;
         Print("[AI2] Switch to SAFE mode | DD=",dd,"% | Profit=",profit);
      }
      return;
   }
}

//+------------------------------------------------------------------+
//| 5c. MULTI-MODE LOT GETTER (NEW)                                  |
//+------------------------------------------------------------------+
double GetModeBaseLot()
{
   if(!Use_Multi_Mode_Lot)
      return Base_Lot;
   
   switch(g_attack_mode)
   {
      case ATTACK_ACTIVE:
         return Attack_Base_Lot;
      case ATTACK_RECOVERY:
         return Recovery_Base_Lot;
      default:
         return Safe_Base_Lot;
   }
}

int GetModeMaxDCA()
{
   if(!Use_Multi_Mode_Lot)
      return Max_DCA_Levels;
   
   switch(g_attack_mode)
   {
      case ATTACK_ACTIVE:
         return Attack_Max_DCA;
      case ATTACK_RECOVERY:
         return Recovery_Max_DCA;
      default:
         return Safe_Max_DCA;
   }
}

double GetModeMultiplier()
{
   if(!Use_Multi_Mode_Lot)
      return Lot_Multiplier;
   
   switch(g_attack_mode)
   {
      case ATTACK_ACTIVE:
         return Attack_Multiplier;
      case ATTACK_RECOVERY:
         return Recovery_Multiplier;
      default:
         return Safe_Multiplier;
   }
}

double GetModeHedgeRatio()
{
   if(!Use_Multi_Mode_Lot)
      return Hedge_Ratio;
   
   switch(g_attack_mode)
   {
      case ATTACK_ACTIVE:
         return Attack_Hedge_Ratio;
      case ATTACK_RECOVERY:
         return Recovery_Hedge_Ratio;
      default:
         return Safe_Hedge_Ratio;
   }
}

//+------------------------------------------------------------------+
//| 6. RISK MANAGEMENT ENGINE                                        |
//+------------------------------------------------------------------+
void UpdateRisk(){
   double dd=DDPercent(), dl=DailyLossPercent();
   if(dd>=Emergency_Close_DD_Percent || dl>=Daily_Loss_Limit_Percent) g_risk=RISK_EMERGENCY;
   else if(dd>=Max_Equity_DD_Stop_Percent) g_risk=RISK_DANGER;
   else if(dd>=DD_Reduce_Lot_At_Percent) g_risk=RISK_WARNING;
   else g_risk=RISK_SAFE;
   if(Use_Risk_Engine_PRO && g_risk==RISK_EMERGENCY){ Print("[AI2 RISK] Emergency close"); CloseAll(); }
}

//+------------------------------------------------------------------+
//| 7. AUTO MODE SWITCH V4                                           |
//+------------------------------------------------------------------+
void AI_AutoModeSwitch()
{
   if(!Use_Auto_Strategy_Switch) return;

   double dd = DDPercent();

   if(dd >= Emergency_Close_DD_Percent)
   {
      g_mode = MODE_PAUSE;
      return;
   }

   if(g_regime == REGIME_CHAOTIC)
   {
      g_mode = MODE_PAUSE;
      return;
   }

   if(g_regime == REGIME_VOLATILE)
   {
      g_mode = MODE_SAFE;
      return;
   }

   if(g_regime == REGIME_SIDEWAY)
   {
      g_mode = MODE_SCALP;
      return;
   }

   if(g_regime == REGIME_TREND_UP || g_regime == REGIME_TREND_DOWN)
   {
      g_mode = MODE_TREND;
      return;
   }

   if(dd > 4.5)
   {
      g_mode = MODE_HEDGE_DEFENSE;
      return;
   }
}

//+------------------------------------------------------------------+
//| 8. MODE SELECTOR ENGINE                                          |
//+------------------------------------------------------------------+
void SelectMode(){
   if(g_risk==RISK_EMERGENCY || g_risk==RISK_DANGER){ g_mode=MODE_PAUSE; return; }
   if(!Use_Auto_Strategy_Switch){ g_mode=MODE_SCALP; return; }
   if(CountPos()>0 && TotalLots(1)>0 && TotalLots(-1)>0){ g_mode=MODE_HEDGE_DEFENSE; return; }
   if(g_regime==REGIME_CHAOTIC) g_mode=MODE_PAUSE;
   else if(g_regime==REGIME_VOLATILE) g_mode=MODE_SAFE;
   else if(g_regime==REGIME_SIDEWAY) g_mode=MODE_SCALP;
   else g_mode=MODE_TREND;
}

//+------------------------------------------------------------------+
//| 9. DIRECTION BUILDER ENGINE                                      |
//+------------------------------------------------------------------+
int BuildDirection(){
   int m1=TrendDir(PERIOD_M1), m5=TrendDir(PERIOD_M5), m15=TrendDir(PERIOD_M15);
   if(g_regime==REGIME_TREND_UP) return 1;
   if(g_regime==REGIME_TREND_DOWN) return -1;
   if(Use_MTF_Confirm && Block_Entry_On_MTF_Conflict){
      if(Use_M5_Filter && m5!=0 && m1!=0 && m5!=m1) return 0;
      if(Use_M15_Filter && m15!=0 && m1!=0 && m15!=m1) return 0;
   }
   return m1;
}

//+------------------------------------------------------------------+
//| 10. SMART PAUSE PRO MODULE                                       |
//+------------------------------------------------------------------+
bool SmartPause_IsActive()
{
   if(!Use_Smart_Pause_PRO) return false;
   if(g_mode==MODE_PAUSE) return true;
   if(g_regime==REGIME_CHAOTIC) return true;
   if(g_risk==RISK_DANGER || g_risk==RISK_EMERGENCY) return true;
   return false;
}

bool SmartPause_CanRescueHedge()
{
   if(!Use_Smart_Pause_PRO) return false;
   if(!SmartPause_Allow_Hedge) return false;
   if(!Use_Hedge || !Use_Smart_Hedge) return false;
   if(CountPos()==0) return false;
   double profit=BasketProfit();
   double dd=DDPercent();
   if(profit<=Hedge_Trigger_DD_USD) return true;
   if(dd>=Hedge_Trigger_DD_Percent) return true;
   if(dd>=SmartPause_Min_DD_For_Hedge_Percent && SmartPause_IsActive()) return true;
   return false;
}

bool SmartPause_CanRescueReHedge()
{
   if(!Use_Smart_Pause_PRO) return false;
   if(!SmartPause_Allow_ReHedge) return false;
   if(!Use_ReHedge_AI || !Use_ReHedge) return false;
   if(CountPos(1)==0 || CountPos(-1)==0) return false;
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
//| 11. DECISION BUILDING ENGINE                                     |
//+------------------------------------------------------------------+
void BuildDecision(){
   g_entry_allow=false;
   g_dca_allow=false;
   g_hedge_allow=false;
   g_exit_allow=false;
   g_direction=0;
   if(!Use_AI_Level2) return;
   if(SpreadPoints()>Max_Spread_Points) return;
   if(!TradingHour()) return;
   if(NewsBlocked()) return;
   bool smartPause=SmartPause_IsActive();
   if(CountPos()>0) g_exit_allow=true;
   if(smartPause)
   {
      if(CountPos()>0)
      {
         if(SmartPause_Allow_Hedge && SmartPause_CanRescueHedge()) g_hedge_allow=true;
         if(SmartPause_Allow_ReHedge && SmartPause_CanRescueReHedge()) g_hedge_allow=true;
      }
      return;
   }
   g_direction=BuildDirection();
   if(CountPos()==0 && g_direction!=0) g_entry_allow=true;
   if(CountPos()>0)
   {
      g_dca_allow=true;
      g_hedge_allow=Use_Hedge && Use_Smart_Hedge;
      if(g_mode==MODE_HEDGE_DEFENSE && Stop_DCA_When_Hedged) g_dca_allow=false;
      if(g_regime==REGIME_CHAOTIC && Block_DCA_In_Chaotic) g_dca_allow=false;
      if(g_risk==RISK_WARNING && Stop_DCA_When_Trend_Against) g_dca_allow=false;
   }
}

//+------------------------------------------------------------------+
//| 12. LOT & STEP CALCULATORS (UPDATED WITH MULTI-MODE)             |
//+------------------------------------------------------------------+
double EntryLot(){ 
   double l = GetModeBaseLot();
   if(Use_Adaptive_Lot){ 
      if(g_risk==RISK_WARNING) l*=Lot_Reduce_Factor; 
      if(g_regime==REGIME_VOLATILE) l*=Volatility_Lot_Reduce; 
   } 
   return NormLot(l); 
}

double DCALot(int level){ 
   double l = GetModeBaseLot() * MathPow(GetModeMultiplier(), level); 
   if(Use_Adaptive_Lot && g_risk==RISK_WARNING) l*=Lot_Reduce_Factor; 
   return NormLot(l); 
}

int DCAStep(){ 
   if(!Use_Adaptive_DCA) return Min_DCA_Step_Points; 
   int s=(int)MathRound(ATRPoints(PERIOD_M1)*ATR_DCA_Multiplier); 
   return MathMin(MathMax(s,Min_DCA_Step_Points),Max_DCA_Step_Points); 
}

//+------------------------------------------------------------------+
//| 13. EXIT ENGINE (NEW)                                            |
//+------------------------------------------------------------------+
void UpdateTrailingValues()
{
   double profit = BasketProfit();
   
   if(profit > g_highest_profit)
      g_highest_profit = profit;
   
   if(profit < g_lowest_profit)
      g_lowest_profit = profit;
}

void TryExitEngine()
{
   if(!Use_Exit_Engine) return;
   if(CountPos() == 0) 
   {
      g_highest_profit = 0;
      g_lowest_profit = 0;
      return;
   }
   
   UpdateTrailingValues();
   double profit = BasketProfit();
   
   // 1. Breakeven: khi profit giảm xuống dưới ngưỡng BE
   if(Exit_BE_USD < 0 && profit <= Exit_BE_USD)
   {
      if(profit <= Exit_BE_USD && g_highest_profit > 0)
      {
         Print("[EXIT ENGINE] Breakeven triggered | Profit=",profit);
         CloseAll();
         return;
      }
   }
   
   // 2. Lock profit: khi profit đạt lock và bắt đầu giảm
   if(Exit_Lock_USD > 0 && g_highest_profit >= Exit_Lock_USD)
   {
      if(profit <= g_highest_profit - Exit_Trail_USD)
      {
         Print("[EXIT ENGINE] Lock profit triggered | Max=",g_highest_profit," Current=",profit);
         CloseAll();
         return;
      }
   }
   
   // 3. Time-based exit: giữ lệnh quá lâu
   if(Exit_Max_Time_Min > 0 && CountPos() > 0)
   {
      datetime firstOrderTime = 0;
      for(int i=PositionsTotal()-1;i>=0;i--)
      {
         ulong tk=PositionGetTicket(i);
         if(tk==0) continue;
         if(!PositionSelectByTicket(tk)) continue;
         if(!IsOurPos()) continue;
         datetime ot=(datetime)PositionGetInteger(POSITION_TIME);
         if(firstOrderTime == 0 || ot < firstOrderTime)
            firstOrderTime = ot;
      }
      
      if(firstOrderTime > 0)
      {
         int minutesHeld = (int)((TimeCurrent() - firstOrderTime) / 60);
         if(minutesHeld >= Exit_Max_Time_Min)
         {
            Print("[EXIT ENGINE] Time limit reached | Minutes=",minutesHeld,"/",Exit_Max_Time_Min);
            CloseAll();
            return;
         }
      }
   }
}

//+------------------------------------------------------------------+
//| 14. EXIT & ENTRY ENGINES                                         |
//+------------------------------------------------------------------+
void TryExit(){ 
   if(!g_exit_allow) return; 
   double target=(Use_Dynamic_BasketTP && g_mode==MODE_HEDGE_DEFENSE ? Basket_TP_Hedge_Mode_USD : Basket_TP_Normal_USD); 
   if(BasketProfit()>=target){ Print("[AI2 EXIT] Basket target"); CloseAll(); } 
}

void TryEntry(){ if(g_entry_allow) SendOrder(g_direction,EntryLot(),"AI2_ENTRY"); }

void TryDCA(){
   if(!g_dca_allow) return;
   
   int maxDCA = GetModeMaxDCA();
   int b=CountPos(1), s=CountPos(-1), dir=0; 
   if(b>s) dir=1; 
   else if(s>b) dir=-1; 
   else return;
   
   int level=MathMax(b,s); 
   if(level>=maxDCA) return;
   
   if(Stop_DCA_When_Trend_Against && ((dir==1&&g_regime==REGIME_TREND_DOWN)||(dir==-1&&g_regime==REGIME_TREND_UP))) return;
   double lp=LastPrice(dir), pt=SymbolInfoDouble(g_symbol,SYMBOL_POINT); 
   if(lp<=0||pt<=0) return;
   int step=DCAStep(); 
   bool ok=false;
   if(dir==1 && SymbolInfoDouble(g_symbol,SYMBOL_BID)<=lp-step*pt) ok=true;
   if(dir==-1 && SymbolInfoDouble(g_symbol,SYMBOL_ASK)>=lp+step*pt) ok=true;
   if(ok) SendOrder(dir,DCALot(level),"AI2_DCA_L"+IntegerToString(level+1));
}

//+------------------------------------------------------------------+
//| 15. HEDGE SPACING PRO MODULE                                     |
//+------------------------------------------------------------------+
datetime Hedge_LastMainOrderTime(int dir)
{
   datetime latest=0;
   for(int i=PositionsTotal()-1;i>=0;i--)
   {
      ulong tk=PositionGetTicket(i);
      if(tk==0) continue;
      if(!PositionSelectByTicket(tk)) continue;
      if(!IsOurPos()) continue;
      long type=PositionGetInteger(POSITION_TYPE);
      if(dir==1 && type!=POSITION_TYPE_BUY) continue;
      if(dir==-1 && type!=POSITION_TYPE_SELL) continue;
      datetime ot=(datetime)PositionGetInteger(POSITION_TIME);
      if(ot>latest) latest=ot;
   }
   return latest;
}

bool Hedge_DistanceOK(int mainDir)
{
   if(!Use_Hedge_Spacing_PRO) return true;
   double last=LastPrice(mainDir);
   double pt=SymbolInfoDouble(g_symbol,SYMBOL_POINT);
   if(last<=0.0 || pt<=0.0) return false;
   double bid=SymbolInfoDouble(g_symbol,SYMBOL_BID);
   double ask=SymbolInfoDouble(g_symbol,SYMBOL_ASK);
   double dist=0.0;
   if(mainDir==1) dist=(last-bid)/pt;
   else if(mainDir==-1) dist=(ask-last)/pt;
   if(dist>=Hedge_Min_Distance_From_Last_DCA) return true;
   return false;
}

bool Hedge_DelayOK(int mainDir)
{
   if(!Use_Hedge_Spacing_PRO) return true;
   datetime lastTime=Hedge_LastMainOrderTime(mainDir);
   if(lastTime<=0) return false;
   if(TimeCurrent()-lastTime>=Hedge_Delay_After_Last_Order_Sec) return true;
   return false;
}

bool Hedge_MomentumOK(int mainDir)
{
   if(!Use_Hedge_Spacing_PRO) return true;
   if(!Hedge_Require_Momentum) return true;
   double atr=ATRPoints(PERIOD_M1);
   double pt=SymbolInfoDouble(g_symbol,SYMBOL_POINT);
   if(atr<=0.0 || pt<=0.0) return false;
   double o=iOpen(g_symbol,PERIOD_M1,1);
   double c=iClose(g_symbol,PERIOD_M1,1);
   if(o<=0.0 || c<=0.0) return false;
   double candlePts=MathAbs(c-o)/pt;
   if(candlePts < atr*Hedge_Momentum_Candle_ATR_Ratio) return false;
   if(mainDir==1 && c<o) return true;
   if(mainDir==-1 && c>o) return true;
   return false;
}

bool HedgeSpacingPRO_OK(int mainDir,double dd)
{
   if(!Use_Hedge_Spacing_PRO) return true;
   if(Hedge_Allow_If_DD_Emergency && dd>=Hedge_Trigger_DD_Percent*1.5) return true;
   if(Use_Smart_Pause_PRO && SmartPause_Bypass_HedgeSpacing_On_Danger)
   {
      if(SmartPause_IsActive() && dd>=SmartPause_Min_DD_For_Hedge_Percent) return true;
   }
   if(!Hedge_DelayOK(mainDir)) return false;
   if(!Hedge_DistanceOK(mainDir)) return false;
   if(!Hedge_MomentumOK(mainDir)) return false;
   return true;
}

//+------------------------------------------------------------------+
//| 16. HEDGE & REHEDGE ENGINES (UPDATED WITH MULTI-MODE)            |
//+------------------------------------------------------------------+
void TryHedge(){
   if(!g_hedge_allow) return;
   
   // V4: tránh hedge sai hướng khi reversal nhẹ
   if(g_regime == REGIME_SIDEWAY && DDPercent() < 3.0)
      return;
      
   double profit=BasketProfit();
   double dd=DDPercent();
   if(profit>Hedge_Trigger_DD_USD && dd<Hedge_Trigger_DD_Percent) return;
   int b=CountPos(1), s=CountPos(-1), main=0;
   if(b>s) main=1;
   else if(s>b) main=-1;
   else return;
   int level=MathMax(b,s);
   if(level<Hedge_Start_Level) return;
   if(!HedgeSpacingPRO_OK(main,dd)) return;
   int hedge=-main;
   if(Only_One_Hedge_Per_Direction && CountPos(hedge)>0) return;
   
   double ratio = GetModeHedgeRatio();
   double need=TotalLots(main)*ratio-TotalLots(hedge);
   need=NormLot(need);
   if(need>0) SendOrder(hedge,need,"AI2_SMART_HEDGE");
}

void TryReHedge(){
   if(!Use_ReHedge_AI || !Use_ReHedge) return;
   bool allowReHedge=false;
   if(g_mode==MODE_HEDGE_DEFENSE) allowReHedge=true;
   if(SmartPause_CanRescueReHedge()) allowReHedge=true;
   if(!allowReHedge) return;
   if(TimeCurrent()-g_last_rehedge_time<ReHedge_Cooldown_Min*60) return;
   if(BasketProfit()>Hedge_Trigger_DD_USD*1.5) return;
   if(CountPos(1)==0 || CountPos(-1)==0) return;
   int main=(TotalLots(1)>=TotalLots(-1)?1:-1);
   int hedge=-main;
   double lot=NormLot(TotalLots(main)*ReHedge_Ratio);
   if(lot>0 && SendOrder(hedge,lot,"AI2_REHEDGE"))
      g_last_rehedge_time=TimeCurrent();
}

//+------------------------------------------------------------------+
//| 17. DASHBOARD HELPERS                                            |
//+------------------------------------------------------------------+
string AI2_BoolText(bool v,string yesText,string noText)
{
   if(v) return yesText;
   return noText;
}

color AI2_RiskColor()
{
   if(g_risk==RISK_SAFE) return clrGood;
   if(g_risk==RISK_WARNING) return clrWarn;
   return clrBad;
}

color AI2_ActionColor()
{
   if(g_regime==REGIME_CHAOTIC) return C'160,0,255';
   if(g_mode==MODE_PAUSE) return clrBad;
   if(g_direction==1) return clrGood;
   if(g_direction==-1) return clrBad;
   if(g_dca_allow) return clrWarn;
   if(g_hedge_allow) return clrWarn;
   return clrInfo;
}

string AI2_DirText()
{
   if(g_direction==1) return "BUY";
   if(g_direction==-1) return "SELL";
   return "NONE";
}

string AI2_BigSignalText()
{
   if(SmartPause_IsActive() && g_hedge_allow) return "SMART PAUSE";
   if(g_mode==MODE_PAUSE) return "AI PAUSE";
   if(g_direction==1) return "BUY ONLY";
   if(g_direction==-1) return "SELL ONLY";
   return "WAIT";
}

string AI2_TradePermissionText()
{
   if(g_entry_allow) return "ENTRY READY";
   if(g_dca_allow) return "DCA READY";
   if(g_hedge_allow && SmartPause_IsActive()) return "RESCUE HEDGE";
   if(g_hedge_allow) return "HEDGE CHECK";
   if(g_mode==MODE_PAUSE) return "NO ENTRY";
   return "WAIT";
}

int AI2_DCALevel()
{
   int b=CountPos(1);
   int s=CountPos(-1);
   if(b>s) return b;
   return s;
}

string AI2_CycleStatusText()
{
   if(CountPos()==0) return "IDLE";
   if(TotalLots(1)>0.0 && TotalLots(-1)>0.0) return "HEDGE DEFENSE";
   return "RUNNING";
}

string AI2_HedgeStatusText()
{
   if(TotalLots(1)>0.0 && TotalLots(-1)>0.0) return "DEFENSE ACTIVE";
   if(g_hedge_allow) return "READY";
   return "WAIT";
}

string AI2_MTFSyncText()
{
   if(g_regime==REGIME_CHAOTIC) return "IGNORED";
   if(g_mode==MODE_PAUSE) return "IGNORED";

   int m1=TrendDir(PERIOD_M1);
   int m5=TrendDir(PERIOD_M5);
   int m15=TrendDir(PERIOD_M15);

   if(m1==0 || m5==0 || m15==0) return "MIXED";
   if(m1==m5 && m5==m15) return "ALIGN";
   return "CONFLICT";
}

int AI2_ConfidenceScore()
{
   int score=50;
   string mtf=AI2_MTFSyncText();

   if(g_regime==REGIME_TREND_UP || g_regime==REGIME_TREND_DOWN) score+=20;
   if(mtf=="ALIGN") score+=20;
   if(SpreadPoints()<=Max_Spread_Points) score+=10;

   if(g_risk==RISK_WARNING) score-=15;
   if(g_risk==RISK_DANGER || g_risk==RISK_EMERGENCY) score-=35;
   if(g_regime==REGIME_CHAOTIC) score-=35;
   if(NewsBlocked()) score-=25;

   if(score<0) score=0;
   if(score>100) score=100;
   return score;
}

string AI2_AIReasonText()
{
   if(SmartPause_IsActive() && g_hedge_allow) return "Smart Pause: entry/DCA blocked, rescue hedge allowed.";
   if(g_regime==REGIME_CHAOTIC) return "Chaotic market -> entry/DCA paused, rescue logic monitored.";
   if(g_risk==RISK_EMERGENCY) return "Emergency DD -> close/protect immediately.";
   if(g_risk==RISK_DANGER) return "Danger DD -> pause new entries.";
   if(g_mode==MODE_HEDGE_DEFENSE) return "Hedge defense -> manage exit, reduce DCA.";
   if(g_entry_allow && g_direction==1) return "Trend/filter aligned -> BUY priority.";
   if(g_entry_allow && g_direction==-1) return "Trend/filter aligned -> SELL priority.";
   if(g_dca_allow) return "Active cycle -> wait correct DCA distance.";
   if(NewsBlocked()) return "News time block -> no new order.";
   if(SpreadPoints()>Max_Spread_Points) return "Spread too high -> wait.";
   return "AI waiting for cleaner setup.";
}

double AI2_CurrentTargetTP()
{
   if(Use_Dynamic_BasketTP && g_mode==MODE_HEDGE_DEFENSE) return Basket_TP_Hedge_Mode_USD;
   return Basket_TP_Normal_USD;
}

double AI2_NextDCAPrice()
{
   int dir=0;
   int b=CountPos(1);
   int s=CountPos(-1);
   if(b>s) dir=1;
   else if(s>b) dir=-1;
   else return 0.0;

   double last=LastPrice(dir);
   double pt=SymbolInfoDouble(g_symbol,SYMBOL_POINT);
   if(last<=0.0 || pt<=0.0) return 0.0;

   int step=DCAStep();
   if(dir==1) return last-step*pt;
   if(dir==-1) return last+step*pt;
   return 0.0;
}

string AI2_PriceText(double price)
{
   if(price<=0.0) return "N/A";
   int digits=(int)SymbolInfoInteger(g_symbol,SYMBOL_DIGITS);
   return DoubleToString(price,digits);
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
//| 19. REHEDGE SEPARATE PANEL MODULE                                |
//+------------------------------------------------------------------+
int AI2_ReHedgeCooldownLeftSec()
{
   if(!Use_ReHedge_AI || !Use_ReHedge) return 0;
   int cd=ReHedge_Cooldown_Min*60;
   int passed=(int)(TimeCurrent()-g_last_rehedge_time);
   if(g_last_rehedge_time<=0) return 0;
   if(passed>=cd) return 0;
   return cd-passed;
}

string AI2_SecondsToMMSS(int sec)
{
   if(sec<0) sec=0;
   int m=sec/60;
   int s=sec%60;
   return IntegerToString(m)+"m"+IntegerToString(s)+"s";
}

double AI2_NextReHedgeLot()
{
   if(!Use_ReHedge_AI || !Use_ReHedge) return 0.0;
   if(CountPos(1)==0 || CountPos(-1)==0) return 0.0;

   int main=1;
   if(TotalLots(-1)>TotalLots(1)) main=-1;

   return NormLot(TotalLots(main)*ReHedge_Ratio);
}

string AI2_ReHedgeStatusText()
{
   if(!Use_ReHedge_AI || !Use_ReHedge) return "OFF";
   if(CountPos(1)==0 || CountPos(-1)==0) return "WAIT HEDGE";

   int left=AI2_ReHedgeCooldownLeftSec();
   if(left>0) return "COOLDOWN";

   if(BasketProfit()>Hedge_Trigger_DD_USD*1.5) return "WAIT LOSS";

   if(SmartPause_CanRescueReHedge()) return "RESCUE READY";
   if(g_mode==MODE_HEDGE_DEFENSE) return "READY";

   return "WAIT";
}

string AI2_ReHedgeReasonText()
{
   if(!Use_ReHedge_AI || !Use_ReHedge) return "ReHedge off";
   if(CountPos(1)==0 || CountPos(-1)==0) return "Need hedge defense";

   int left=AI2_ReHedgeCooldownLeftSec();
   if(left>0) return "Wait cooldown "+AI2_SecondsToMMSS(left);

   if(BasketProfit()>Hedge_Trigger_DD_USD*1.5) return "Loss not deep enough";

   if(SmartPause_CanRescueReHedge()) return "Smart Pause rescue ready";
   if(g_mode==MODE_HEDGE_DEFENSE) return "Hedge defense ready";

   return "Waiting conditions";
}

color AI2_ReHedgeStatusColor()
{
   string st=AI2_ReHedgeStatusText();
   if(st=="READY" || st=="RESCUE READY") return clrGood;
   if(st=="COOLDOWN") return clrWarn;
   if(st=="OFF") return clrText;
   return clrInfo;
}

void AI2_ReHedgeSeparatePanel()
{
   if(!Show_ReHedge_Status_Dashboard) return;
   if(!Dashboard_Show_ReHedge_Separate) return;

   bool hasHedge=(TotalLots(1)>0.0 && TotalLots(-1)>0.0);

   if(Dashboard_AutoHide_ReHedge_Panel && !hasHedge)
   {
      ObjectDelete(0,"yy_rh2_bg");
      ObjectDelete(0,"yy_rh2_title");
      ObjectDelete(0,"yy_rh2_state");
      ObjectDelete(0,"yy_rh2_next");
      ObjectDelete(0,"yy_rh2_lot");
      ObjectDelete(0,"yy_rh2_count");
      ObjectDelete(0,"yy_rh2_why");
      return;
   }

   int x=Dashboard_ReHedge_Panel_X;
   int y=Dashboard_ReHedge_Panel_Y;
   int w=285;
   int h=145;

   color rhColor=AI2_ReHedgeStatusColor();

   AI2_DrawPanel("yy_rh2_bg",x,y,w,h,clrBlack,rhColor);
   AI2_DrawLabel("yy_rh2_title","REHEDGE PANEL",x+12,y+10,clrInfo,10);
   AI2_DrawLabel("yy_rh2_state","STATUS : "+AI2_ReHedgeStatusText(),x+12,y+34,rhColor,Dashboard_FontSize);
   AI2_DrawLabel("yy_rh2_next","NEXT   : "+AI2_SecondsToMMSS(AI2_ReHedgeCooldownLeftSec()),x+12,y+56,clrText,Dashboard_FontSize);
   AI2_DrawLabel("yy_rh2_lot","LOT    : "+DoubleToString(AI2_NextReHedgeLot(),2),x+12,y+78,clrText,Dashboard_FontSize);

   int rhCount=0;
   if(hasHedge)
   {
      int b=CountPos(1);
      int s=CountPos(-1);
      rhCount=MathMax(0,MathMin(b,s)-1);
   }

   AI2_DrawLabel("yy_rh2_count","COUNT  : "+IntegerToString(rhCount),x+12,y+100,clrText,Dashboard_FontSize);
   AI2_DrawLabel("yy_rh2_why","WHY    : "+AI2_ReHedgeReasonText(),x+12,y+122,clrText,Dashboard_FontSize);
}

//+------------------------------------------------------------------+
//| 20. MAIN DASHBOARD (7 PANELS)                                    |
//+------------------------------------------------------------------+
void AI2_MaxProDashboard()
{
   if(!Use_Dashboard_AI) return;
   if(!Use_FinalElite_Dashboard) return;

   int x=Dashboard_X;
   int y=Dashboard_Y;
   int w=Dashboard_Width;
   int h=520;
   if(!Use_FitScreen_Dashboard) h=575;

   color riskClr=AI2_RiskColor();
   color actionClr=AI2_ActionColor();

   color profitClr=clrBad;
   if(BasketProfit()>=0.0) profitClr=clrGood;

   color spreadClr=clrBad;
   if(SpreadPoints()<=Max_Spread_Points) spreadClr=clrGood;

   color bigBg=clrPanel2;
   if(Use_BigSignal_Color) bigBg=actionClr;

   int conf=AI2_ConfidenceScore();
   color confClr=clrBad;
   if(conf>=75) confClr=clrGood;
   else if(conf>=50) confClr=clrWarn;

   string mtf=AI2_MTFSyncText();
   color mtfClr=clrWarn;
   if(mtf=="ALIGN") mtfClr=clrGood;
   else if(mtf=="CONFLICT") mtfClr=clrBad;
   else if(mtf=="IGNORED") mtfClr=clrInfo;

   string newsText=AI2_BoolText(NewsBlocked(),"ON","OFF");
   color newsColor=clrGood;
   if(NewsBlocked()) newsColor=clrBad;

   color entryColor=clrWarn;
   if(g_entry_allow) entryColor=clrGood;

   color dcaColor=clrWarn;
   if(g_dca_allow) dcaColor=clrGood;

   color hedgeColor=clrText;
   if(g_hedge_allow) hedgeColor=clrWarn;

   color rehedgeColor=clrWarn;
   if(Use_ReHedge) rehedgeColor=clrGood;

   // PANEL 1: BACKGROUND + HEADER
   AI2_DrawPanel("yy_bg",x,y,w,h,clrBlack,clrInfo);
   AI2_DrawPanel("yy_header",x+4,y+4,w-8,46,clrPanel2,clrTitle);

   AI2_DrawLabel("yy_title","YINYANG AI LEVEL 2 - V5 COMPLETE",x+14,y+11,clrTitle,12);
   AI2_DrawLabel("yy_sub",g_symbol+" | M1 | Magic:"+IntegerToString((int)Magic_Number)+" | "+AttackModeText(),x+14,y+31,clrText,8);

   // PANEL 2: BIG SIGNAL
   AI2_DrawPanel("yy_decision",x+10,y+58,w-20,68,bigBg,actionClr);
   AI2_DrawLabel("yy_big_signal",AI2_BigSignalText(),x+24,y+68,clrWhite,16);
   AI2_DrawLabel("yy_next","NEXT ACTION : "+(g_entry_allow?(g_direction==1?"ENTRY BUY":"ENTRY SELL"):(g_dca_allow?"DCA CHECK":(g_hedge_allow?"HEDGE CHECK":(g_mode==MODE_PAUSE?"WAIT":"WAIT")))),x+24,y+96,clrWhite,9);
   AI2_DrawStatusBox("yy_trade_perm",AI2_TradePermissionText(),x+w-158,y+72,134,28,clrBlack,actionClr,9);
   AI2_DrawLabel("yy_conf","CONFIDENCE  : "+IntegerToString(conf)+"%",x+w-158,y+106,confClr,9);

   // PANEL 3: AI STATE
   AI2_DrawPanel("yy_ai_state",x+10,y+136,w-20,100,clrBlack,clrInfo);
   AI2_DrawLabel("yy_ai_title","AI STATE",x+22,y+144,clrInfo,10);
   AI2_DrawLabel("yy_regime","REGIME      : "+RegimeText(),x+22,y+164,clrText,9);
   AI2_DrawLabel("yy_mode","MODE        : "+ModeText(),x+22,y+182,clrText,9);
   AI2_DrawLabel("yy_dir","DIRECTION   : "+AI2_DirText(),x+22,y+200,actionClr,9);
   AI2_DrawLabel("yy_cycle","CYCLE       : "+AI2_CycleStatusText(),x+22,y+218,clrText,9);

   AI2_DrawLabel("yy_mtf","MTF SYNC    : "+mtf,x+235,y+164,mtfClr,9);
   AI2_DrawLabel("yy_spread","SPREAD      : "+IntegerToString(SpreadPoints())+" / "+IntegerToString(Max_Spread_Points),x+235,y+182,spreadClr,9);
   AI2_DrawLabel("yy_atr","ATR M1/M5   : "+DoubleToString(ATRPoints(PERIOD_M1),0)+" / "+DoubleToString(ATRPoints(PERIOD_M5),0),x+235,y+200,clrText,9);
   AI2_DrawLabel("yy_news","NEWS BLOCK  : "+newsText,x+235,y+218,newsColor,9);

   // PANEL 4: ENGINE STATUS
   int by=y+248;
   AI2_DrawPanel("yy_engine",x+10,by,w-20,100,clrBlack,clrInfo);
   AI2_DrawLabel("yy_engine_title","ENGINE STATUS",x+22,by+8,clrInfo,10);

   AI2_DrawLabel("yy_entry","ENTRY  : "+AI2_BoolText(g_entry_allow,"ALLOW","BLOCK"),x+22,by+32,entryColor,9);
   AI2_DrawLabel("yy_dca","DCA    : "+AI2_BoolText(g_dca_allow,"READY","WAIT/BLOCK"),x+22,by+52,dcaColor,9);
   AI2_DrawLabel("yy_hedge","HEDGE  : "+AI2_HedgeStatusText(),x+22,by+72,hedgeColor,9);
   AI2_DrawLabel("yy_smart","S-PAUSE: "+SmartPauseStatusText(),x+22,by+82,rehedgeColor,9);

   double ndp=AI2_NextDCAPrice();
   AI2_DrawLabel("yy_dca_lv","DCA LEVEL     : "+IntegerToString(AI2_DCALevel())+" / "+IntegerToString(GetModeMaxDCA()),x+235,by+32,clrText,9);
   AI2_DrawLabel("yy_dca_step","NEXT DCA STEP : "+IntegerToString(DCAStep())+" pts",x+235,by+52,clrText,9);
   AI2_DrawLabel("yy_next_dca","NEXT DCA PRICE: "+AI2_PriceText(ndp),x+235,by+72,clrText,9);
   AI2_DrawLabel("yy_tp1","TP1 STATUS    : "+AI2_BoolText(g_tp1_done,"DONE","WAIT"),x+235,by+82,(g_tp1_done?clrGood:clrText),9);

   // PANEL 5: CYCLE / RISK
   int ry=y+358;
   AI2_DrawPanel("yy_risk_panel",x+10,ry,w-20,100,clrBlack,riskClr);
   AI2_DrawLabel("yy_risk_title","CYCLE / RISK",x+22,ry+8,clrInfo,10);

   AI2_DrawLabel("yy_orders","ORDERS      : "+IntegerToString(CountPos())+" / "+IntegerToString(Max_Total_Orders),x+22,ry+32,clrText,9);
   AI2_DrawLabel("yy_lots","TOTAL LOT   : "+DoubleToString(TotalLots(),2)+" / "+DoubleToString(Max_Total_Lot,2),x+22,ry+52,clrText,9);
   AI2_DrawLabel("yy_profit","BASKET P/L  : "+DoubleToString(BasketProfit(),2)+" USD",x+22,ry+72,profitClr,9);
   AI2_DrawLabel("yy_tp","TARGET TP   : "+DoubleToString(AI2_CurrentTargetTP(),2)+" USD",x+22,ry+82,clrText,9);

   AI2_DrawLabel("yy_risk","RISK STATE  : "+RiskText(),x+235,ry+32,riskClr,9);
   AI2_DrawLabel("yy_dd","EQUITY DD   : "+DoubleToString(DDPercent(),2)+"%",x+235,ry+52,riskClr,9);
   AI2_DrawLabel("yy_daily","DAILY LOSS  : "+DoubleToString(DailyLossPercent(),2)+"%",x+235,ry+72,clrText,9);
   AI2_DrawLabel("yy_margin","FREE MARGIN : "+DoubleToString(AccountInfoDouble(ACCOUNT_MARGIN_FREE),2),x+235,ry+82,clrText,9);

   // PANEL 6 & 7: AI MESSAGE
   int msgY=y+466;
   if(!Use_FitScreen_Dashboard) msgY=y+525;
   AI2_DrawPanel("yy_msg_panel",x+10,msgY,w-20,42,clrPanel2,clrInfo);
   AI2_DrawLabel("yy_msg","AI MESSAGE:",x+20,msgY+7,clrInfo,9);
   AI2_DrawLabel("yy_msg2",AI2_AIReasonText(),x+20,msgY+23,clrText,8);

   // ReHedge Panel riêng
   AI2_ReHedgeSeparatePanel();
}

//+------------------------------------------------------------------+
//| 21. AI2_OnTick() - MAIN PIPELINE (UPDATED)                       |
//+------------------------------------------------------------------+
void AI2_OnTick()
{
   if(!Use_AI_Level2)
   {
      if(Use_Dashboard_AI) Comment("AI LEVEL 2 OFF");
      return;
   }

   // ===== CORE AI PIPELINE =====
   DetectRegime();           // 1. MARKET ANALYSIS
   UpdateRisk();             // 2. RISK ASSESSMENT
   UpdateAttackMode();       // 3. ATTACK MODE SWITCH (NEW)
   AI_AutoModeSwitch();      // 4. AUTO MODE
   SelectMode();             // 5. MODE SELECTION
   BuildDecision();          // 6. DECISION BUILDING

   // ===== HARD PROTECTION =====
   if(g_risk == RISK_EMERGENCY)
   {
      Print("[AI2] EMERGENCY STOP");
      return;
   }

   // ===== EXIT FIRST =====
   TryExit();                // 7. BASKET TP EXIT
   TryExitEngine();          // 8. ADVANCED EXIT ENGINE (NEW)

   // ===== RECOVERY ENGINE =====
   TrySmartUnwind();         // 9. UNWIND PRESSURE
   TryTP1ProAI();            // 10. EARLY PROFIT

   // ===== ENTRY ENGINE =====
   TryEntry();               // 11. NEW ENTRY
   TryDCA();                 // 12. DCA AVERAGING

   // ===== DEFENSE ENGINE =====
   TryHedge();               // 13. HEDGE PROTECTION
   TryReHedge();             // 14. REHEDGE

   // ===== VISUALIZATION =====
   AI2_MaxProDashboard();    // 15. DASHBOARD
}

//+------------------------------------------------------------------+
//| 22. INIT, TICK, DEINIT                                           |
//+------------------------------------------------------------------+
int AI2_OnInit(){
   g_symbol=(Trade_Symbol==""?_Symbol:Trade_Symbol);
   g_start_day_equity=AccountInfoDouble(ACCOUNT_EQUITY);
   MqlDateTime n; TimeToStruct(TimeCurrent(),n); g_day_of_year=n.day_of_year;
   Print("[AI2 INIT V5.00] ",g_symbol);
   Print("[AI2] Multi-Mode Lot: ",Use_Multi_Mode_Lot?"ON":"OFF");
   Print("[AI2] Exit Engine: ",Use_Exit_Engine?"ON":"OFF");
   return INIT_SUCCEEDED;
}

int OnInit(){ return AI2_OnInit(); }
void OnTick(){ AI2_OnTick(); }
void OnDeinit(const int reason){ AI2_DeleteDashboardObjects(); Comment(""); Print("[AI2 DEINIT V5.00] reason=",reason); }
//+------------------------------------------------------------------+