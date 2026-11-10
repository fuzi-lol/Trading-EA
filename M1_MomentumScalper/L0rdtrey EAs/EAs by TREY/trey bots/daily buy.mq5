//+------------------------------------------------------------------+
//|                                        DailyBuyScheduler.mq5    |
//|                                                                  |
//|  Opens a BUY position daily at a configured time and optionally |
//|  closes it at a configured time.                                 |
//|  SL and TP are set as a percentage of the position open price.  |
//|  Restores state after MT5 restart. Isolated by magic number.    |
//+------------------------------------------------------------------+
#property copyright   ""
#property link        ""
#property version     "1.00"
#property description "Daily Buy Scheduler: opens a BUY at a set time, closes at a set time."

#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>

//+------------------------------------------------------------------+
//|  Input Parameters                                                |
//+------------------------------------------------------------------+

input group "=== General ==="
input ulong  InpMagicNumber      = 123456;   // Magic Number
input double InpLotSize          = 0.01;     // Lot Size

input group "=== Schedule ==="
input int    InpOpenHour         = 1;        // Open Hour  (0–23)
input int    InpOpenMinute       = 5;        // Open Minute (0–59)
input int    InpCloseHour        = 22;       // Close Hour  (0–23)
input int    InpCloseMinute      = 55;       // Close Minute (0–59)
input bool   InpUseTimeClose     = true;     // Close Position at Close Time

input group "=== Risk Management ==="
input double InpStopLossPct      = 1.0;      // Stop Loss %   (0 = disabled)
input double InpTakeProfitPct    = 2.0;      // Take Profit % (0 = disabled)

//+------------------------------------------------------------------+
//|  Global objects & state                                          |
//+------------------------------------------------------------------+
CTrade        g_trade;
CPositionInfo g_pos;

// Tracks the calendar date on which we already opened a position.
// Stored as midnight (00:00:00) of that day in server time.
// Persisted across ticks; re-derived from history/open positions on restart.
datetime      g_lastOpenDay = 0;

//+------------------------------------------------------------------+
//|  OnInit                                                          |
//+------------------------------------------------------------------+
int OnInit()
{
   //--- Basic input validation
   if(InpOpenHour < 0 || InpOpenHour > 23)
      { Alert("DailyBuyScheduler: Invalid Open Hour.");   return INIT_PARAMETERS_INCORRECT; }
   if(InpOpenMinute < 0 || InpOpenMinute > 59)
      { Alert("DailyBuyScheduler: Invalid Open Minute."); return INIT_PARAMETERS_INCORRECT; }
   if(InpCloseHour < 0 || InpCloseHour > 23)
      { Alert("DailyBuyScheduler: Invalid Close Hour.");  return INIT_PARAMETERS_INCORRECT; }
   if(InpCloseMinute < 0 || InpCloseMinute > 59)
      { Alert("DailyBuyScheduler: Invalid Close Minute.");return INIT_PARAMETERS_INCORRECT; }
   if(InpLotSize <= 0)
      { Alert("DailyBuyScheduler: Lot size must be > 0."); return INIT_PARAMETERS_INCORRECT; }

   //--- Configure the trade object
   g_trade.SetExpertMagicNumber(InpMagicNumber);
   g_trade.SetDeviationInPoints(20);
   g_trade.SetTypeFilling(GetFillMode());
   g_trade.LogLevel(LOG_LEVEL_ERRORS);

   //--- Restore EA state after a restart
   RestoreState();

   Print("DailyBuyScheduler initialized | Magic: ", InpMagicNumber,
         " | Symbol: ", Symbol(),
         " | Open: ",  InpOpenHour,  ":", IntToTwoDigits(InpOpenMinute),
         " | Close: ", InpCloseHour, ":", IntToTwoDigits(InpCloseMinute),
         " | TimeClose: ", InpUseTimeClose);

   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//|  OnDeinit                                                        |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   Print("DailyBuyScheduler deinitialized | Reason: ", reason);
}

//+------------------------------------------------------------------+
//|  OnTick – main logic                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   datetime now      = TimeCurrent();
   datetime todayMid = DayMidnight(now);   // midnight of today (server time)

   MqlDateTime dt;
   TimeToStruct(now, dt);
   int currentMOD = dt.hour * 60 + dt.min; // minutes-of-day (current)
   int openMOD    = InpOpenHour  * 60 + InpOpenMinute;
   int closeMOD   = InpCloseHour * 60 + InpCloseMinute;

   bool positionOpen = HasOpenPosition();

   //------------------------------------------------------------------
   // 1. CLOSE LOGIC
   //    If time-close is enabled and we are at or past the close time,
   //    close any open position managed by this EA on this symbol.
   //------------------------------------------------------------------
   if(InpUseTimeClose && positionOpen && currentMOD >= closeMOD)
   {
      CloseAllPositions();
      return; // nothing more to do this tick
   }

   //------------------------------------------------------------------
   // 2. OPEN LOGIC
   //    Conditions to open a new BUY:
   //      a) We have NOT already opened a trade today.
   //      b) No position is currently open (previous one was closed by
   //         SL/TP or time-close, and we don't re-open within same day).
   //      c) Current time is at or after the open time.
   //      d) Current time is before the close time  – OR –  time-close
   //         is disabled (no point opening just to close immediately).
   //------------------------------------------------------------------
   if(g_lastOpenDay < todayMid          // not yet opened today
      && !positionOpen                  // no open position
      && currentMOD >= openMOD          // at or past open time
      && (!InpUseTimeClose || currentMOD < closeMOD)) // before close time
   {
      OpenBuy();
   }
}

//+------------------------------------------------------------------+
//|  Restore EA state after an MT5 restart                           |
//|                                                                  |
//|  Strategy:                                                       |
//|  1. If there is currently an open position with our magic on     |
//|     this symbol, mark today as already-opened.                   |
//|  2. Otherwise scan today's deal history for an ENTRY_IN deal     |
//|     with our magic on this symbol.                               |
//+------------------------------------------------------------------+
void RestoreState()
{
   datetime now      = TimeCurrent();
   datetime todayMid = DayMidnight(now);

   // --- Check open positions first (fast path) ---
   if(HasOpenPosition())
   {
      g_lastOpenDay = todayMid;
      Print("RestoreState: open position found – marking today as opened.");
      return;
   }

   // --- Scan today's deal history ---
   if(!HistorySelect(todayMid, now))
   {
      Print("RestoreState: HistorySelect failed.");
      return;
   }

   int total = HistoryDealsTotal();
   for(int i = 0; i < total; i++)
   {
      ulong ticket = HistoryDealGetTicket(i);
      if(ticket == 0) continue;

      if((ulong)HistoryDealGetInteger(ticket, DEAL_MAGIC)  == InpMagicNumber
         && HistoryDealGetString(ticket, DEAL_SYMBOL)      == Symbol()
         && HistoryDealGetInteger(ticket, DEAL_ENTRY)      == DEAL_ENTRY_IN)
      {
         g_lastOpenDay = todayMid;
         Print("RestoreState: entry deal found in history – marking today as opened.");
         return;
      }
   }

   Print("RestoreState: no trade found for today.");
}

//+------------------------------------------------------------------+
//|  Open a BUY position                                             |
//+------------------------------------------------------------------+
void OpenBuy()
{
   double ask = SymbolInfoDouble(Symbol(), SYMBOL_ASK);
   if(ask <= 0.0)
   {
      Print("OpenBuy: could not obtain ASK price.");
      return;
   }

   double sl = 0.0, tp = 0.0;

   if(InpStopLossPct > 0.0)
      sl = NormalizePrice(ask * (1.0 - InpStopLossPct / 100.0));

   if(InpTakeProfitPct > 0.0)
      tp = NormalizePrice(ask * (1.0 + InpTakeProfitPct / 100.0));

   //--- Enforce broker minimum stop distance
   AdjustStops(ask, sl, tp);

   bool ok = g_trade.Buy(InpLotSize, Symbol(), ask, sl, tp, "DailyBuyScheduler");

   if(ok)
   {
      g_lastOpenDay = DayMidnight(TimeCurrent());
      Print("OpenBuy: order sent | Ticket: ", g_trade.ResultOrder(),
            " | Ask: ", ask,
            " | SL: ",  sl,
            " | TP: ",  tp);
   }
   else
   {
      Print("OpenBuy: failed | Retcode: ", g_trade.ResultRetcode(),
            " | ", g_trade.ResultRetcodeDescription());
   }
}

//+------------------------------------------------------------------+
//|  Close every open position with our magic on this symbol         |
//+------------------------------------------------------------------+
void CloseAllPositions()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(!g_pos.SelectByIndex(i)) continue;

      if(g_pos.Magic() == InpMagicNumber && g_pos.Symbol() == Symbol())
      {
         bool ok = g_trade.PositionClose(g_pos.Ticket());
         if(ok)
            Print("CloseAllPositions: closed ticket ", g_pos.Ticket());
         else
            Print("CloseAllPositions: failed ticket ", g_pos.Ticket(),
                  " | Retcode: ", g_trade.ResultRetcode(),
                  " | ", g_trade.ResultRetcodeDescription());
      }
   }
}

//+------------------------------------------------------------------+
//|  Return true if there is an open position with our magic number  |
//|  on the current symbol                                           |
//+------------------------------------------------------------------+
bool HasOpenPosition()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(!g_pos.SelectByIndex(i)) continue;
      if(g_pos.Magic() == InpMagicNumber && g_pos.Symbol() == Symbol())
         return true;
   }
   return false;
}

//+------------------------------------------------------------------+
//|  Adjust SL / TP to the broker's minimum stop-level distance      |
//+------------------------------------------------------------------+
void AdjustStops(double price, double &sl, double &tp)
{
   int    stopLevel = (int)SymbolInfoInteger(Symbol(), SYMBOL_TRADE_STOPS_LEVEL);
   double point     = SymbolInfoDouble(Symbol(), SYMBOL_POINT);
   double minDist   = stopLevel * point;

   if(sl > 0.0 && (price - sl) < minDist)
   {
      sl = NormalizePrice(price - minDist);
      Print("AdjustStops: SL adjusted to meet minimum stop level → ", sl);
   }

   if(tp > 0.0 && (tp - price) < minDist)
   {
      tp = NormalizePrice(price + minDist);
      Print("AdjustStops: TP adjusted to meet minimum stop level → ", tp);
   }
}

//+------------------------------------------------------------------+
//|  Detect the order-filling mode supported by the symbol           |
//+------------------------------------------------------------------+
ENUM_ORDER_TYPE_FILLING GetFillMode()
{
   uint filling = (uint)SymbolInfoInteger(Symbol(), SYMBOL_FILLING_MODE);

   if((filling & SYMBOL_FILLING_FOK) != 0)    return ORDER_FILLING_FOK;
   if((filling & SYMBOL_FILLING_IOC) != 0)    return ORDER_FILLING_IOC;
   return ORDER_FILLING_RETURN;
}

//+------------------------------------------------------------------+
//|  Return the Unix timestamp of 00:00:00 for the day that          |
//|  contains 'ts' (server time)                                     |
//+------------------------------------------------------------------+
datetime DayMidnight(datetime ts)
{
   MqlDateTime dt;
   TimeToStruct(ts, dt);
   return ts - (dt.hour * 3600 + dt.min * 60 + dt.sec);
}

//+------------------------------------------------------------------+
//|  Format an integer as a zero-padded two-digit string             |
//+------------------------------------------------------------------+
string IntToTwoDigits(int value)
{
   return (value < 10 ? "0" : "") + IntegerToString(value);
}

//+------------------------------------------------------------------+