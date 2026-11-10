//+------------------------------------------------------------------+
//|                                       Gold Breakout Master EA.mq5 |
//|                                  Converted from Pine Script by AI |
//|                                        [https://www.google.com](https://www.google.com) |


//+------------------------------------------------------------------+
#property copyright "Converted from Pine Script by AI"
#property link      "[https://www.google.com](https://www.google.com)"
#property version   "1.01" // Version updated
#property description "Breakout strategy for Gold on M15 based on support/resistance zones."
//--- Include the Standard Library for Trade Functions
#include <Trade\Trade.mqh>
// === INPUTS ===
// --- Zone and Breakout ---
input group           "Zone & Breakout Settings"
input int             InpLookback = 150;                          // Zone Lookback (bars)
input double          InpZoneBufferPoints = 300;                  // Zone Buffer (in Points)
input bool            InpConfirmBreakout = true;                  // Require 2-bar Breakout Confirmation
input bool            InpRetestEnabled = true;                    // Enable Retest Entry after Breakout
// --- Risk Management ---
input group           "Risk Management"
input double          InpTakeProfitPoints = 4000;                 // Take Profit (in Points)
input double          InpStopLossPoints = 2000;                   // Stop Loss (in Points)
input bool            InpUseTrailingStop = true;                  // Enable Trailing Stop
input double          InpTrailTriggerPoints = 2000;               // Trail Start (in Points)
input double          InpTrailOffsetPoints = 1500;                // Trail Offset (in Points)
input double          InpRiskPercent = 1.0;                       // Lot Size Risk (% of Equity)
// --- Filters ---
input group           "Trade Filters"
input bool            InpUseVolumeFilter = true;                  // Enable Volume Spike Filter
input double          InpVolumeMultiplier = 1.5;                  // Volume Spike Threshold (x Avg Vol)
input int             InpMaxTradesPerDay = 3;                     // Max Trades per Day
input bool            InpTradeOnlyNyLondon = true;                // Trade Only NY + London Sessions
input int             InpSessionStartHour = 7;                    // Session Start Hour (Server Time)
input int             InpSessionEndHour = 18;                     // Session End Hour (Server Time)
// --- EA Settings ---
input group           "EA Settings"
input ulong           InpMagicNumber = 13579;                     // EA Magic Number
// === GLOBAL VARIABLES ===
CTrade        trade;                                    // Trading object
int           h_avg_vol;                                // Volume MA handle
double        resistance_val, support_val, avg_vol_val; // Indicator values
// --- State Management Variables ---
bool          long_zone_broken = false;
bool          short_zone_broken = false;
int           trades_today = 0;
datetime      current_day_start = 0;
//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   //--- Initialize trading object
   trade.SetExpertMagicNumber(InpMagicNumber);
   trade.SetDeviationInPoints(10); // Set allowable slippage in points
   trade.SetTypeFillingBySymbol(_Symbol);
   //--- Create Indicator Handles
   // Simple Moving Average of Volume (use iCustom or calculate manually)
   h_avg_vol = iMA(_Symbol, _Period, 20, 0, MODE_SMA, PRICE_CLOSE);
   if(h_avg_vol == INVALID_HANDLE)
   {
      printf("Error creating Volume MA indicator handle");
      return(INIT_FAILED);
   }
   //--- Set the start of the current day
   current_day_start = iTime(_Symbol, PERIOD_D1, 0);
   return(INIT_SUCCEEDED);
}
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   //--- Release indicator handles
   IndicatorRelease(h_avg_vol);
}
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   //--- Check for a new bar to run trading logic
   static datetime last_bar_time = 0;
   datetime current_bar_time = (datetime)SeriesInfoInteger(_Symbol, _Period, SERIES_LASTBAR_DATE);
   if(current_bar_time > last_bar_time)
   {
      // --- This is a new bar, run the entry logic ---
      last_bar_time = current_bar_time;
      CheckForNewTrade();
   }
   //--- Manage trailing stop on every tick for precision
   if(InpUseTrailingStop)
   {
      ManageTrailingStop();
   }
}
//+------------------------------------------------------------------+
//| Main function to check for new trade opportunities               |
//+------------------------------------------------------------------+
void CheckForNewTrade()
{
   //--- Do not open a new trade if one already exists
   if(PositionSelect(_Symbol))
   {
      return;
   }
   //--- Calculate resistance and support from highest/lowest bars
   int highest_bar = iHighest(_Symbol, _Period, MODE_HIGH, InpLookback, 1);
   int lowest_bar = iLowest(_Symbol, _Period, MODE_LOW, InpLookback, 1);
   if(highest_bar < 0 || lowest_bar < 0)
   {
      printf("Error finding highest/lowest bars");
      return;
   }
   resistance_val = iHigh(_Symbol, _Period, highest_bar);
   support_val = iLow(_Symbol, _Period, lowest_bar);
   //--- Calculate average volume manually (20-bar average of tick_volume)
   long vol_sum = 0;
   MqlRates vol_rates[];
   if(CopyRates(_Symbol, _Period, 1, 20, vol_rates) < 20)
   {
      printf("Error copying volume data");
      return;
   }
   for(int i = 0; i < 20; i++)
      vol_sum += vol_rates[i].tick_volume;
   avg_vol_val = (double)vol_sum / 20.0;
   //--- Get latest price and volume data
   MqlRates rates[3];
   if(CopyRates(_Symbol, _Period, 0, 3, rates) < 3)
   {
      printf("Error copying rates");
      return;
   }
   // rates[2] is the most recent completed bar (bar [1] in Pine)
   // rates[1] is the bar before that (bar [2] in Pine)
   // rates[0] is the current, forming bar
   double close1 = rates[2].close;
   double close2 = rates[1].close;
   double open1 = rates[2].open;
   MqlTick last_tick;
   SymbolInfoTick(_Symbol, last_tick);
   long current_volume = (long)rates[2].tick_volume;
   // === ZONE CALCULATION ===
   double res_top = resistance_val;
   double res_bot = resistance_val - (InpZoneBufferPoints * _Point);
   double sup_top = support_val + (InpZoneBufferPoints * _Point);
   double sup_bot = support_val;
   // === DAILY TRADE LIMIT ===
   // Check if a new day has started
   if(iTime(_Symbol, PERIOD_D1, 0) > current_day_start)
   {
      current_day_start = iTime(_Symbol, PERIOD_D1, 0);
      trades_today = 0;
      // Reset retest state machine for the new day
      long_zone_broken = false;
      short_zone_broken = false;
   }
   bool can_trade_daily_limit = (trades_today < InpMaxTradesPerDay);
   // === TIME FILTER ===
   MqlDateTime time_struct;
   TimeCurrent(time_struct);
   bool in_session = !InpTradeOnlyNyLondon || (time_struct.hour >= InpSessionStartHour && time_struct.hour <= InpSessionEndHour);
   // === VOLUME FILTER ===
   bool vol_spike = current_volume > avg_vol_val * InpVolumeMultiplier;
   bool volume_filter_passed = !InpUseVolumeFilter || vol_spike;
   // === BREAKOUT & CONFIRMATION LOGIC ===
   bool long_breakout_initial = (close1 > res_top && close2 <= res_top);
   bool short_breakout_initial = (close1 < sup_bot && close2 >= sup_bot);
   bool long_confirm = InpConfirmBreakout ? (close1 > res_top && close2 > res_top) : long_breakout_initial;
   bool short_confirm = InpConfirmBreakout ? (close1 < sup_bot && close2 < sup_bot) : short_breakout_initial;
   // === RETEST STATE MACHINE ===
   if(long_confirm) long_zone_broken = true;
   if(short_confirm) short_zone_broken = true;
   bool long_retest = long_zone_broken && InpRetestEnabled && close1 < res_top && close1 > res_bot && close1 > open1;
   bool short_retest = short_zone_broken && InpRetestEnabled && close1 > sup_bot && close1 < sup_top && close1 < open1;
   // === FINAL ENTRY CONDITIONS ===
   bool enter_long = in_session && can_trade_daily_limit && (long_confirm || long_retest) && volume_filter_passed;
   bool enter_short = in_session && can_trade_daily_limit && (short_confirm || short_retest) && volume_filter_passed;
   // === EXECUTE TRADE ===
   if(enter_long)
   {
      double stop_loss_price = last_tick.ask - (InpStopLossPoints * _Point);
      double take_profit_price = last_tick.ask + (InpTakeProfitPoints * _Point);
      double lot_size = CalculateLotSize(InpStopLossPoints);
      if(trade.Buy(lot_size, _Symbol, last_tick.ask, stop_loss_price, take_profit_price, "Long Breakout"))
      {
         trades_today++;
      }
   }
   else if(enter_short)
   {
      double stop_loss_price = last_tick.bid + (InpStopLossPoints * _Point);
      double take_profit_price = last_tick.bid - (InpTakeProfitPoints * _Point);
      double lot_size = CalculateLotSize(InpStopLossPoints);
      if(trade.Sell(lot_size, _Symbol, last_tick.bid, stop_loss_price, take_profit_price, "Short Breakout"))
      {
         trades_today++;
      }
   }
}
//+------------------------------------------------------------------+
//| Manages the trailing stop for an open position                   |
//+------------------------------------------------------------------+
void ManageTrailingStop()
{
   //--- Check if there is an open position for this symbol and magic number
   if(!PositionSelect(_Symbol)) return;
   if(PositionGetInteger(POSITION_MAGIC) != InpMagicNumber) return;
   //--- Get position details
   long position_type = PositionGetInteger(POSITION_TYPE);
   double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
   double current_sl = PositionGetDouble(POSITION_SL);
   double current_price = PositionGetDouble(POSITION_PRICE_CURRENT);
   if(position_type == POSITION_TYPE_BUY)
   {
      //--- Trailing stop for a BUY position
      double profit_points = (current_price - open_price) / _Point;
      if(profit_points > InpTrailTriggerPoints)
      {
         double new_stop_loss = current_price - (InpTrailOffsetPoints * _Point);
         //--- We only move the stop loss up
         if(new_stop_loss > current_sl || current_sl == 0)
         {
            trade.PositionModify(_Symbol, new_stop_loss, PositionGetDouble(POSITION_TP));
         }
      }
   }
   else if(position_type == POSITION_TYPE_SELL)
   {
      //--- Trailing stop for a SELL position
      double profit_points = (open_price - current_price) / _Point;
      if(profit_points > InpTrailTriggerPoints)
      {
         double new_stop_loss = current_price + (InpTrailOffsetPoints * _Point);
         //--- We only move the stop loss down
         if(new_stop_loss < current_sl || current_sl == 0)
         {
            trade.PositionModify(_Symbol, new_stop_loss, PositionGetDouble(POSITION_TP));
         }
      }
   }
}
//+------------------------------------------------------------------+
//| Calculates lot size based on risk percentage and stop loss       |
//+------------------------------------------------------------------+
double CalculateLotSize(double sl_points)
{
   if(sl_points <= 0 || InpRiskPercent <= 0) return 0.01; // Return minimum lot if inputs are invalid
   double account_equity = AccountInfoDouble(ACCOUNT_EQUITY);
   double risk_amount = account_equity * (InpRiskPercent / 100.0);
   //--- Get symbol properties
   double tick_value = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double tick_size = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   double lot_size_step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   double min_lot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double max_lot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   if(tick_size == 0 || point == 0) return min_lot;
   //--- Calculate the value of 1 point for 1 lot
   double value_per_point = tick_value / (tick_size / point);
   //--- Calculate the loss for 1 lot
   double loss_per_lot = sl_points * value_per_point;
   if(loss_per_lot <= 0) return min_lot;
   //--- Calculate desired lot size
   double lot_size = risk_amount / loss_per_lot;
   //--- Normalize the lot size to broker's requirements
   lot_size = floor(lot_size / lot_size_step) * lot_size_step;
   //--- Clamp the lot size between min and max allowed
   lot_size = fmax(min_lot, fmin(max_lot, lot_size));
   return lot_size;
}
//+------------------------------------------------------------------+