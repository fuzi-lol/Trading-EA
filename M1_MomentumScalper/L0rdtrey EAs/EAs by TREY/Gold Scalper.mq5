//+------------------------------------------------------------------+
//|                                      Gold Scalper Enhanced v2.mq5 |
//|                                   Copyright 2024, Fraser Lofstrom |
//|                                                                    |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, Fraser Lofstrom"
#property link      ""
#property version   "2.00"

//--- Input parameters
input group "=== Trading Parameters ==="
input double   tp_dollars = 2.0;                // Take Profit ($)
input double   sl_dollars = 1.5;                // Stop Loss ($)
input double   trail_start = 1.5;               // Trailing Start ($)
input double   trail_offset = 1.5;              // Trailing Distance ($)
input double   proximity = 1.0;                 // Proximity to EMA50 ($)

input group "=== Time Filter ==="
input int      startHour = 7;                   // Start Hour (UTC)
input int      endHour = 18;                    // End Hour (UTC)

input group "=== Risk Management ==="
input double   lotSize = 0.1;                   // Lot Size
input int      magicNumber = 12345;             // Magic Number

//--- Global variables
int ema50_handle, ema200_handle;
double ema50_buffer[], ema200_buffer[];
bool last_trade_won = true;
bool pullback_after_loss = false;
double trail_price_long = 0;
double trail_price_short = 0;
bool trailing_active_long = false;
bool trailing_active_short = false;

//--- Constants
const double gold_tick_value = 0.1;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
    // Create EMA indicators
    ema50_handle = iMA(_Symbol, PERIOD_CURRENT, 50, 0, MODE_EMA, PRICE_CLOSE);
    ema200_handle = iMA(_Symbol, PERIOD_CURRENT, 200, 0, MODE_EMA, PRICE_CLOSE);
    
    if(ema50_handle == INVALID_HANDLE || ema200_handle == INVALID_HANDLE)
    {
        Print("Error creating EMA indicators");
        return INIT_FAILED;
    }
    
    // Resize arrays
    ArraySetAsSeries(ema50_buffer, true);
    ArraySetAsSeries(ema200_buffer, true);
    
    Print("Gold Scalper Enhanced v2 EA initialized successfully");
    return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    // Release indicator handles
    if(ema50_handle != INVALID_HANDLE)
        IndicatorRelease(ema50_handle);
    if(ema200_handle != INVALID_HANDLE)
        IndicatorRelease(ema200_handle);
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
    // Check if new bar
    static datetime lastBarTime = 0;
    datetime currentBarTime = iTime(_Symbol, PERIOD_CURRENT, 0);
    
    if(currentBarTime == lastBarTime)
        return;
    lastBarTime = currentBarTime;
    
    // Get EMA values
    if(!GetEMAValues())
        return;
    
    // Update trade history tracking
    UpdateTradeHistory();
    
    // Check time filter
    if(!IsInSession())
        return;
    
    // Get current prices
    double close = iClose(_Symbol, PERIOD_CURRENT, 0);
    double open = iOpen(_Symbol, PERIOD_CURRENT, 0);
    double high = iHigh(_Symbol, PERIOD_CURRENT, 0);
    double low = iLow(_Symbol, PERIOD_CURRENT, 0);
    
    // Calculate conditions
    bool bull_trend = close > ema50_buffer[0] && close > ema200_buffer[0];
    bool bear_trend = close < ema50_buffer[0] && close < ema200_buffer[0];
    bool bullish_candle = close > open;
    bool bearish_candle = close < open;
    bool near_ema50 = MathAbs(close - ema50_buffer[0]) <= proximity;
    
    // Re-entry logic
    bool pullback_complete = pullback_after_loss && near_ema50 && 
                           ((bull_trend && bullish_candle) || (bear_trend && bearish_candle));
    
    if(pullback_complete)
        pullback_after_loss = false;
    
    bool can_enter = last_trade_won || (!last_trade_won && !pullback_after_loss);
    
    // Entry conditions
    bool long_condition = bull_trend && bullish_candle && near_ema50 && 
                         can_enter && !HasPosition();
    bool short_condition = bear_trend && bearish_candle && near_ema50 && 
                          can_enter && !HasPosition();
    
    // Execute trades
    if(long_condition)
    {
        OpenLongTrade();
    }
    else if(short_condition)
    {
        OpenShortTrade();
    }
    
    // Handle trailing stops
    HandleTrailingStops();
}

//+------------------------------------------------------------------+
//| Get EMA values                                                   |
//+------------------------------------------------------------------+
bool GetEMAValues()
{
    if(CopyBuffer(ema50_handle, 0, 0, 2, ema50_buffer) < 2)
    {
        Print("Error copying EMA50 buffer");
        return false;
    }
    
    if(CopyBuffer(ema200_handle, 0, 0, 2, ema200_buffer) < 2)
    {
        Print("Error copying EMA200 buffer");
        return false;
    }
    
    return true;
}

//+------------------------------------------------------------------+
//| Check if in trading session                                      |
//+------------------------------------------------------------------+
bool IsInSession()
{
    MqlDateTime time_struct;
    TimeCurrent(time_struct);
    int current_hour = time_struct.hour;
    
    return (current_hour >= startHour && current_hour < endHour);
}

//+------------------------------------------------------------------+
//| Check if position exists                                         |
//+------------------------------------------------------------------+
bool HasPosition()
{
    return PositionSelect(_Symbol);
}

//+------------------------------------------------------------------+
//| Open long trade                                                  |
//+------------------------------------------------------------------+
void OpenLongTrade()
{
    double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
    double sl = ask - (sl_dollars / gold_tick_value) * _Point;
    double tp = ask + (tp_dollars / gold_tick_value) * _Point;
    
    MqlTradeRequest request = {};
    MqlTradeResult result = {};
    
    request.action = TRADE_ACTION_DEAL;
    request.symbol = _Symbol;
    request.volume = lotSize;
    request.type = ORDER_TYPE_BUY;
    request.price = ask;
    request.sl = sl;
    request.tp = tp;
    request.magic = magicNumber;
    request.comment = "Gold Scalper Long";
    
    if(OrderSend(request, result))
    {
        Print("Long trade opened at ", ask);
        trail_price_long = 0;
        trailing_active_long = false;
    }
    else
    {
        Print("Error opening long trade: ", result.retcode);
    }
}

//+------------------------------------------------------------------+
//| Open short trade                                                 |
//+------------------------------------------------------------------+
void OpenShortTrade()
{
    double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    double sl = bid + (sl_dollars / gold_tick_value) * _Point;
    double tp = bid - (tp_dollars / gold_tick_value) * _Point;
    
    MqlTradeRequest request = {};
    MqlTradeResult result = {};
    
    request.action = TRADE_ACTION_DEAL;
    request.symbol = _Symbol;
    request.volume = lotSize;
    request.type = ORDER_TYPE_SELL;
    request.price = bid;
    request.sl = sl;
    request.tp = tp;
    request.magic = magicNumber;
    request.comment = "Gold Scalper Short";
    
    if(OrderSend(request, result))
    {
        Print("Short trade opened at ", bid);
        trail_price_short = 0;
        trailing_active_short = false;
    }
    else
    {
        Print("Error opening short trade: ", result.retcode);
    }
}

//+------------------------------------------------------------------+
//| Handle trailing stops                                            |
//+------------------------------------------------------------------+
void HandleTrailingStops()
{
    if(!PositionSelect(_Symbol))
        return;
    
    double position_open_price = PositionGetDouble(POSITION_PRICE_OPEN);
    ENUM_POSITION_TYPE position_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
    double current_price = (position_type == POSITION_TYPE_BUY) ? 
                          SymbolInfoDouble(_Symbol, SYMBOL_BID) : 
                          SymbolInfoDouble(_Symbol, SYMBOL_ASK);
    
    if(position_type == POSITION_TYPE_BUY)
    {
        double profit_points = (current_price - position_open_price) / _Point;
        double trail_start_points = trail_start / gold_tick_value;
        double trail_offset_points = trail_offset / gold_tick_value;
        
        if(profit_points > trail_start_points)
        {
            double new_trail_price = current_price - (trail_offset_points * _Point);
            
            if(!trailing_active_long)
            {
                trail_price_long = position_open_price + (trail_start_points * _Point);
                trailing_active_long = true;
            }
            
            if(new_trail_price > trail_price_long)
            {
                trail_price_long = new_trail_price;
                ModifyPosition(trail_price_long, 0);
            }
        }
    }
    else if(position_type == POSITION_TYPE_SELL)
    {
        double profit_points = (position_open_price - current_price) / _Point;
        double trail_start_points = trail_start / gold_tick_value;
        double trail_offset_points = trail_offset / gold_tick_value;
        
        if(profit_points > trail_start_points)
        {
            double new_trail_price = current_price + (trail_offset_points * _Point);
            
            if(!trailing_active_short)
            {
                trail_price_short = position_open_price - (trail_start_points * _Point);
                trailing_active_short = true;
            }
            
            if(new_trail_price < trail_price_short)
            {
                trail_price_short = new_trail_price;
                ModifyPosition(trail_price_short, 0);
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Modify position                                                  |
//+------------------------------------------------------------------+
void ModifyPosition(double sl, double tp)
{
    MqlTradeRequest request = {};
    MqlTradeResult result = {};
    
    request.action = TRADE_ACTION_SLTP;
    request.symbol = _Symbol;
    request.sl = sl;
    request.tp = tp;
    request.magic = magicNumber;
    
    if(!OrderSend(request, result))
    {
        Print("Error modifying position: ", result.retcode);
    }
}

//+------------------------------------------------------------------+
//| Update trade history                                             |
//+------------------------------------------------------------------+
void UpdateTradeHistory()
{
    static int last_deals_total = 0;
    int current_deals_total = HistoryDealsTotal();
    
    if(current_deals_total > last_deals_total)
    {
        // New deal occurred, check if it was a close
        if(HistorySelect(0, TimeCurrent()))
        {
            int total = HistoryDealsTotal();
            if(total > 0)
            {
                ulong ticket = HistoryDealGetTicket(total - 1);
                if(ticket > 0)
                {
                    if(HistoryDealGetInteger(ticket, DEAL_MAGIC) == magicNumber)
                    {
                        double profit = HistoryDealGetDouble(ticket, DEAL_PROFIT);
                        ENUM_DEAL_ENTRY deal_entry = (ENUM_DEAL_ENTRY)HistoryDealGetInteger(ticket, DEAL_ENTRY);
                        
                        if(deal_entry == DEAL_ENTRY_OUT)
                        {
                            last_trade_won = (profit > 0);
                            if(!last_trade_won)
                            {
                                pullback_after_loss = true;
                            }
                            
                            // Reset trailing variables
                            trail_price_long = 0;
                            trail_price_short = 0;
                            trailing_active_long = false;
                            trailing_active_short = false;
                        }
                    }
                }
            }
        }
        last_deals_total = current_deals_total;
    }
}