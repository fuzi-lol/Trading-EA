//+------------------------------------------------------------------+
//|                                          EliteScalper_v4.mq5     |
//|                                                                  |
//|  XAUUSD Institutional Scalper — Rebuilt from Ground Up          |
//|  Multi-Confirmation Signal | HTF Bias | ATR Risk | Session Guard |
//+------------------------------------------------------------------+
#property copyright   "EliteScalper Systems"
#property link        ""
#property version     "4.00"
#property description "Rebuilt scalper: EMA cross + RSI confirm + HTF bias + ATR risk."

#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>

//+------------------------------------------------------------------+
//|  DASHBOARD CONSTANTS                                             |
//+------------------------------------------------------------------+
#define DASH_PRE  "ES4_"

#define C_BG      C'4,6,10'
#define C_PANEL   C'8,12,20'
#define C_HDRBAR  C'0,35,90'
#define C_BORDER  C'0,60,150'
#define C_BRAND   C'0,120,255'
#define C_WHITE   C'240,245,255'
#define C_GREEN   C'0,230,115'
#define C_RED     C'240,50,60'
#define C_GOLD    C'255,200,50'
#define C_DGRAY   C'80,90,110'
#define C_TEXT    C'170,185,210'

const int DW = 440;
const int DH = 600;

//+------------------------------------------------------------------+
//|  INPUT PARAMETERS                                                |
//+------------------------------------------------------------------+
input group "=== Core Identity ==="
input ulong  InpMagicNumber     = 99999;       // Magic Number

input group "=== Risk Management ==="
input double InpRiskPercent     = 1.0;         // Risk Per Trade (% of Balance)
input double InpMinLot          = 0.01;        // Minimum Lot Size
input double InpMaxLot          = 0.10;        // Maximum Lot Size (safety cap)
input double InpMaxDailyLossUSD = 2.50;        // Max Daily Loss ($) — hard stop
input int    InpMaxDailyTrades  = 6;           // Max Trades Per Day

input group "=== ATR-Based SL/TP ==="
input int    InpATRPeriod       = 14;          // ATR Period
input double InpSLMultiplier    = 1.5;         // SL = N × ATR
input double InpTPMultiplier    = 2.5;         // TP = N × ATR  (R:R = 1:1.67)
input double InpBEMultiplier    = 1.0;         // Move to breakeven at N × ATR profit

input group "=== Signal Engine (M5) ==="
input int    InpFastEMA         = 9;           // Fast EMA (M5)
input int    InpSlowEMA         = 21;          // Slow EMA (M5)
input int    InpRSIPeriod       = 14;          // RSI Period (M5)
input int    InpRSIOverbought   = 65;          // RSI Overbought threshold
input int    InpRSIOversold     = 35;          // RSI Oversold threshold

input group "=== HTF Trend Bias (M15) ==="
input int    InpHTF_EMA         = 50;          // HTF EMA Period (M15)

input group "=== Execution Filters ==="
input int    InpMaxSpread       = 40;          // Max Allowed Spread (Points)
input int    InpCooldownSeconds = 120;         // Cooldown Between Trades (Seconds)

input group "=== Session Filter (Server Time GMT) ==="
input bool   InpUseSessionFilter = true;       // Enable Session Filter
input int    InpLondonOpen      = 7;           // London Open Hour (GMT)
input int    InpLondonClose     = 17;          // London Close Hour (GMT)
input int    InpNYOpen          = 13;          // NY Open Hour (GMT)
input int    InpNYClose         = 21;          // NY Close Hour (GMT)

input group "=== Interface ==="
input int    InpDashX           = 20;
input int    InpDashY           = 30;

//+------------------------------------------------------------------+
//|  GLOBALS                                                         |
//+------------------------------------------------------------------+
CTrade        g_trade;
CPositionInfo g_pos;

// Indicator handles — M5 (execution TF)
int  g_emaFastH  = INVALID_HANDLE;
int  g_emaSlowH  = INVALID_HANDLE;
int  g_rsiH      = INVALID_HANDLE;
int  g_atrH      = INVALID_HANDLE;

// Indicator handle — M15 (bias TF)
int  g_htfEmaH   = INVALID_HANDLE;

// State
datetime g_nextEntryTime = 0;
datetime g_lastResetDay  = 0;
datetime g_lastBarTime   = 0;      // Candle-close gate
bool     g_beMovedThisTrade = false;

// Stats
int     g_tradesToday    = 0;
double  g_dailyLossToday = 0.0;
double  g_profitToday    = 0.0;

// Dashboard strings
string  g_statusMsg = "INITIALIZING";
color   g_statusClr = C_BRAND;
string  g_signalMsg = "---";
color   g_signalClr = C_TEXT;

//+------------------------------------------------------------------+
//|  FORWARD DECLARATIONS                                            |
//+------------------------------------------------------------------+
void   LoadDailyStats();
bool   IsNewBar();
bool   IsSessionOpen();
bool   IsDailyLimitHit();
double CalcLotSize(double slPoints);
double GetATR();
bool   GetSignal(ENUM_ORDER_TYPE &dir);
bool   GetHTFBias(ENUM_ORDER_TYPE &bias);
void   ManageOpenTrade();
void   ExecuteEntry();
void   CloseAllPositions(string reason);
bool   HasOpenPosition();
double GetFloatingProfit();
bool   IsMarketOpen();
datetime DayMidnight(datetime ts);
// Dashboard
void InitDashboard(); void UpdateDashboard(); void DeleteDashboard();
void MakeRect(string nm,int x,int y,int w,int h,color bg,color brd,int bw);
void MakeLbl(string nm,int x,int y,string txt,color clr,int fsz,string font);
void UpdLbl(string nm,string txt,color clr=clrNONE);

//+------------------------------------------------------------------+
//|  OnInit                                                          |
//+------------------------------------------------------------------+
int OnInit()
  {
   g_trade.SetExpertMagicNumber(InpMagicNumber);
   g_trade.SetDeviationInPoints(15);
   g_trade.SetTypeFilling(ORDER_FILLING_IOC);

   // --- M5 Indicators ---
   g_emaFastH = iMA(_Symbol, PERIOD_M5, InpFastEMA, 0, MODE_EMA, PRICE_CLOSE);
   g_emaSlowH = iMA(_Symbol, PERIOD_M5, InpSlowEMA, 0, MODE_EMA, PRICE_CLOSE);
   g_rsiH     = iRSI(_Symbol, PERIOD_M5, InpRSIPeriod, PRICE_CLOSE);
   g_atrH     = iATR(_Symbol, PERIOD_M5, InpATRPeriod);

   // --- M15 HTF EMA ---
   g_htfEmaH  = iMA(_Symbol, PERIOD_M15, InpHTF_EMA, 0, MODE_EMA, PRICE_CLOSE);

   if(g_emaFastH == INVALID_HANDLE || g_emaSlowH == INVALID_HANDLE ||
      g_rsiH == INVALID_HANDLE || g_atrH == INVALID_HANDLE || g_htfEmaH == INVALID_HANDLE)
     {
      Print("[EliteScalper v4] FATAL: Failed to initialise indicator handles.");
      return INIT_FAILED;
     }

   // Load today's trade history so daily caps survive EA restart
   LoadDailyStats();

   g_nextEntryTime = TimeCurrent();
   InitDashboard();
   EventSetTimer(2);

   Print("[EliteScalper v4] Initialised. Risk: ", InpRiskPercent, "% | Max loss/day: $", InpMaxDailyLossUSD);
   return INIT_SUCCEEDED;
  }

//+------------------------------------------------------------------+
//|  OnDeinit                                                        |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   EventKillTimer();
   DeleteDashboard();
   IndicatorRelease(g_emaFastH);
   IndicatorRelease(g_emaSlowH);
   IndicatorRelease(g_rsiH);
   IndicatorRelease(g_atrH);
   IndicatorRelease(g_htfEmaH);
  }

//+------------------------------------------------------------------+
//|  OnTimer — UI refresh only, no trading logic                     |
//+------------------------------------------------------------------+
void OnTimer()
  {
   UpdateDashboard();
  }

//+------------------------------------------------------------------+
//|  OnTick — Execution Loop                                         |
//+------------------------------------------------------------------+
void OnTick()
  {
   // --- Market open check ---
   if(!IsMarketOpen())
     {
      g_statusMsg = "MARKET CLOSED";
      g_statusClr = C_RED;
      return;
     }

   // --- Manage any existing position (breakeven, etc.) ---
   if(HasOpenPosition())
     {
      ManageOpenTrade();
      g_statusMsg = "IN TRADE — MANAGING";
      g_statusClr = C_BRAND;
      return;
     }

   g_beMovedThisTrade = false; // Reset BE flag when no position open

   // --- Daily hard stop ---
   if(IsDailyLimitHit())
     {
      g_statusMsg = "DAILY LIMIT — STOPPED";
      g_statusClr = C_RED;
      return;
     }

   // --- Trade count cap ---
   if(g_tradesToday >= InpMaxDailyTrades)
     {
      g_statusMsg = "DAILY TRADE CAP HIT";
      g_statusClr = C_GOLD;
      return;
     }

   // --- Cooldown ---
   if(TimeCurrent() < g_nextEntryTime)
     {
      int secs = (int)(g_nextEntryTime - TimeCurrent());
      g_statusMsg = "COOLDOWN: " + IntegerToString(secs) + "s";
      g_statusClr = C_GOLD;
      return;
     }

   // --- Session filter ---
   if(InpUseSessionFilter && !IsSessionOpen())
     {
      g_statusMsg = "OUT OF SESSION";
      g_statusClr = C_DGRAY;
      return;
     }

   // --- Spread filter ---
   int spread = (int)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   if(spread > InpMaxSpread)
     {
      g_statusMsg = "SPREAD WIDE: " + IntegerToString(spread) + " pts";
      g_statusClr = C_RED;
      return;
     }

   // --- CANDLE-CLOSE GATE: Only evaluate signals on new M5 bar ---
   if(!IsNewBar())
     {
      g_statusMsg = "SCANNING — AWAITING BAR CLOSE";
      g_statusClr = C_BRAND;
      return;
     }

   // --- Execute entry if signal fires ---
   g_statusMsg = "SCANNING MARKET...";
   g_statusClr = C_BRAND;
   ExecuteEntry();
  }

//+------------------------------------------------------------------+
//|  ExecuteEntry — Signal check + order placement                   |
//+------------------------------------------------------------------+
void ExecuteEntry()
  {
   // Step 1: Get HTF Bias
   ENUM_ORDER_TYPE htfBias;
   if(!GetHTFBias(htfBias))
     {
      g_statusMsg = "HTF NEUTRAL — NO TRADE";
      g_statusClr = C_GOLD;
      g_signalMsg = "HTF: NEUTRAL";
      g_signalClr = C_GOLD;
      return;
     }

   // Step 2: Get M5 signal (must match HTF bias)
   ENUM_ORDER_TYPE sigDir;
   if(!GetSignal(sigDir))
     {
      g_statusMsg = "NO SIGNAL";
      g_statusClr = C_DGRAY;
      g_signalMsg = "M5: NO SIGNAL";
      g_signalClr = C_DGRAY;
      return;
     }

   // Step 3: Signal must align with HTF bias
   if(sigDir != htfBias)
     {
      g_statusMsg = "SIGNAL AGAINST HTF — SKIP";
      g_statusClr = C_GOLD;
      g_signalMsg = (sigDir == ORDER_TYPE_BUY ? "BUY vs SELL HTF" : "SELL vs BUY HTF");
      g_signalClr = C_GOLD;
      return;
     }

   // Step 4: ATR for SL/TP
   double atr = GetATR();
   if(atr <= 0.0)
     {
      Print("[v4] ATR returned 0 — skipping entry.");
      return;
     }

   double point  = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   int    digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);

   // For XAUUSD: ATR is in price terms (e.g. 0.50 = $0.50 move)
   // Convert to points for SL/TP distances
   double slDist = InpSLMultiplier * atr;
   double tpDist = InpTPMultiplier * atr;

   double price, sl, tp;
   if(sigDir == ORDER_TYPE_BUY)
     {
      price = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      sl    = price - slDist;
      tp    = price + tpDist;
     }
   else
     {
      price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      sl    = price + slDist;
      tp    = price - tpDist;
     }

   sl = NormalizeDouble(sl, digits);
   tp = NormalizeDouble(tp, digits);

   // Step 5: Position size from risk %
   double slPoints = slDist / point;
   double lots     = CalcLotSize(slPoints);
   if(lots < InpMinLot)
     {
      Print("[v4] Calculated lot too small (", lots, "). Using min lot: ", InpMinLot);
      lots = InpMinLot;
     }

   // Step 6: Fire order
   bool ok = false;
   if(sigDir == ORDER_TYPE_BUY)
      ok = g_trade.Buy(lots, _Symbol, price, sl, tp, "EliteScalper v4");
   else
      ok = g_trade.Sell(lots, _Symbol, price, sl, tp, "EliteScalper v4");

   if(ok)
     {
      g_tradesToday++;
      g_nextEntryTime = TimeCurrent() + InpCooldownSeconds;
      g_signalMsg     = (sigDir == ORDER_TYPE_BUY ? "▲ BUY FIRED" : "▼ SELL FIRED");
      g_signalClr     = (sigDir == ORDER_TYPE_BUY ? C_GREEN : C_RED);
      g_statusMsg     = "ORDER PLACED";
      g_statusClr     = C_GREEN;
      Print("[v4] ", EnumToString(sigDir), " | Lots: ", lots,
            " | SL: ", sl, " | TP: ", tp,
            " | ATR: ", atr, " | R:R=1:", DoubleToString(InpTPMultiplier/InpSLMultiplier,2));
     }
   else
     {
      Print("[v4] Order failed. Error: ", g_trade.ResultRetcode(), " — ", g_trade.ResultRetcodeDescription());
      g_statusMsg = "ORDER FAILED: " + IntegerToString(g_trade.ResultRetcode());
      g_statusClr = C_RED;
     }
  }

//+------------------------------------------------------------------+
//|  GetSignal — EMA Cross + RSI Confirmation on M5                  |
//|  Reads bars [1] and [2] for CONFIRMED crossover (no repainting)  |
//+------------------------------------------------------------------+
bool GetSignal(ENUM_ORDER_TYPE &dir)
  {
   double fast[3], slow[3], rsi[2];

   // Read bars 0,1,2 (0=forming, 1=last closed, 2=before that)
   if(CopyBuffer(g_emaFastH, 0, 0, 3, fast) < 3) return false;
   if(CopyBuffer(g_emaSlowH, 0, 0, 3, slow) < 3) return false;
   if(CopyBuffer(g_rsiH,     0, 0, 2, rsi)  < 2) return false;

   // Crossover: fast crossed ABOVE slow between bar[2] and bar[1]
   bool bullCross = (fast[2] <= slow[2]) && (fast[1] > slow[1]);
   // Crossover: fast crossed BELOW slow between bar[2] and bar[1]
   bool bearCross = (fast[2] >= slow[2]) && (fast[1] < slow[1]);

   // RSI confirmation on the closed bar [1]
   double rsiVal = rsi[1];
   bool rsiOK_Buy  = (rsiVal < InpRSIOverbought);  // Not overbought on buy
   bool rsiOK_Sell = (rsiVal > InpRSIOversold);    // Not oversold on sell

   if(bullCross && rsiOK_Buy)
     { dir = ORDER_TYPE_BUY;  return true; }
   if(bearCross && rsiOK_Sell)
     { dir = ORDER_TYPE_SELL; return true; }

   return false;
  }

//+------------------------------------------------------------------+
//|  GetHTFBias — M15 EMA50 price position bias                      |
//+------------------------------------------------------------------+
bool GetHTFBias(ENUM_ORDER_TYPE &bias)
  {
   double htfEma[1];
   double closeM15[1];

   if(CopyBuffer(g_htfEmaH, 0, 1, 1, htfEma) < 1)  return false;
   if(CopyClose(_Symbol, PERIOD_M15, 1, 1, closeM15) < 1) return false;

   double midM15 = closeM15[0];

   // Require price to be meaningfully above/below EMA (0.1× ATR buffer)
   double atr     = GetATR();
   double buffer  = 0.10 * atr;

   if(midM15 > htfEma[0] + buffer)   { bias = ORDER_TYPE_BUY;  return true; }
   if(midM15 < htfEma[0] - buffer)   { bias = ORDER_TYPE_SELL; return true; }

   return false; // Price straddling EMA = no clear bias = no trade
  }

//+------------------------------------------------------------------+
//|  ManageOpenTrade — Breakeven logic                               |
//+------------------------------------------------------------------+
void ManageOpenTrade()
  {
   if(g_beMovedThisTrade) return; // Already moved to BE

   double atr = GetATR();
   if(atr <= 0.0) return;

   double beThreshold = InpBEMultiplier * atr; // Profit in price terms to trigger BE

   for(int i = PositionsTotal()-1; i >= 0; i--)
     {
      if(!g_pos.SelectByIndex(i)) continue;
      if(g_pos.Magic() != InpMagicNumber) continue;
      if(g_pos.Symbol() != _Symbol)  continue;

      double openPrice  = g_pos.PriceOpen();
      double currentSL  = g_pos.StopLoss();
      double currentBid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      double currentAsk = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      int    digits     = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);

      if(g_pos.PositionType() == POSITION_TYPE_BUY)
        {
         double profitInPrice = currentBid - openPrice;
         if(profitInPrice >= beThreshold && currentSL < openPrice)
           {
            double newSL = NormalizeDouble(openPrice + SymbolInfoDouble(_Symbol,SYMBOL_POINT), digits);
            g_trade.PositionModify(g_pos.Ticket(), newSL, g_pos.TakeProfit());
            g_beMovedThisTrade = true;
            Print("[v4] Breakeven set for BUY ticket #", g_pos.Ticket());
           }
        }
      else if(g_pos.PositionType() == POSITION_TYPE_SELL)
        {
         double profitInPrice = openPrice - currentAsk;
         if(profitInPrice >= beThreshold && (currentSL > openPrice || currentSL == 0))
           {
            double newSL = NormalizeDouble(openPrice - SymbolInfoDouble(_Symbol,SYMBOL_POINT), digits);
            g_trade.PositionModify(g_pos.Ticket(), newSL, g_pos.TakeProfit());
            g_beMovedThisTrade = true;
            Print("[v4] Breakeven set for SELL ticket #", g_pos.Ticket());
           }
        }
     }
  }

//+------------------------------------------------------------------+
//|  CalcLotSize — Risk-based position sizing                        |
//+------------------------------------------------------------------+
double CalcLotSize(double slPoints)
  {
   if(slPoints <= 0.0) return InpMinLot;

   double balance   = AccountInfoDouble(ACCOUNT_BALANCE);
   double riskUSD   = balance * (InpRiskPercent / 100.0);

   double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double tickSize  = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   double point     = SymbolInfoDouble(_Symbol, SYMBOL_POINT);

   if(tickValue <= 0.0 || tickSize <= 0.0) return InpMinLot;

   // Value per point per lot
   double pointValue = tickValue * (point / tickSize);
   if(pointValue <= 0.0) return InpMinLot;

   double lots = riskUSD / (slPoints * pointValue);

   // Normalize to broker lot step
   double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   lots = MathFloor(lots / lotStep) * lotStep;

   lots = MathMax(lots, InpMinLot);
   lots = MathMin(lots, InpMaxLot);

   return NormalizeDouble(lots, 2);
  }

//+------------------------------------------------------------------+
//|  GetATR — Returns ATR value from closed bar [1]                  |
//+------------------------------------------------------------------+
double GetATR()
  {
   double atr[1];
   if(CopyBuffer(g_atrH, 0, 1, 1, atr) < 1) return 0.0;
   return atr[0];
  }

//+------------------------------------------------------------------+
//|  IsNewBar — True only on the first tick of a new M5 candle       |
//+------------------------------------------------------------------+
bool IsNewBar()
  {
   datetime barTimes[1];
   if(CopyTime(_Symbol, PERIOD_M5, 0, 1, barTimes) < 1) return false;
   if(barTimes[0] != g_lastBarTime)
     {
      g_lastBarTime = barTimes[0];
      return true;
     }
   return false;
  }

//+------------------------------------------------------------------+
//|  IsSessionOpen — London or NY session                            |
//+------------------------------------------------------------------+
bool IsSessionOpen()
  {
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   int h = dt.hour;

   bool london = (h >= InpLondonOpen && h < InpLondonClose);
   bool ny     = (h >= InpNYOpen     && h < InpNYClose);

   return (london || ny);
  }

//+------------------------------------------------------------------+
//|  IsDailyLimitHit — Check if max daily loss has been reached      |
//+------------------------------------------------------------------+
bool IsDailyLimitHit()
  {
   // Recalculate from history on every check
   datetime todayMid = DayMidnight(TimeCurrent());
   double loss = 0.0;

   if(HistorySelect(todayMid, TimeCurrent()))
     {
      for(int i = 0; i < HistoryDealsTotal(); i++)
        {
         ulong ticket = HistoryDealGetTicket(i);
         if(HistoryDealGetInteger(ticket, DEAL_MAGIC) != InpMagicNumber) continue;
         if(HistoryDealGetString(ticket, DEAL_SYMBOL) != _Symbol)        continue;
         if(HistoryDealGetInteger(ticket, DEAL_ENTRY) != DEAL_ENTRY_OUT) continue;

         double dealProfit = HistoryDealGetDouble(ticket, DEAL_PROFIT)
                           + HistoryDealGetDouble(ticket, DEAL_COMMISSION)
                           + HistoryDealGetDouble(ticket, DEAL_SWAP);
         if(dealProfit < 0.0) loss += MathAbs(dealProfit);
        }
     }

   return (loss >= InpMaxDailyLossUSD);
  }

//+------------------------------------------------------------------+
//|  LoadDailyStats — Reconciles g_tradesToday from history on init  |
//+------------------------------------------------------------------+
void LoadDailyStats()
  {
   datetime todayMid = DayMidnight(TimeCurrent());
   g_tradesToday    = 0;
   g_profitToday    = 0.0;
   g_lastResetDay   = todayMid;

   if(HistorySelect(todayMid, TimeCurrent()))
     {
      for(int i = 0; i < HistoryDealsTotal(); i++)
        {
         ulong ticket = HistoryDealGetTicket(i);
         if(HistoryDealGetInteger(ticket, DEAL_MAGIC) != InpMagicNumber) continue;
         if(HistoryDealGetString(ticket, DEAL_SYMBOL) != _Symbol)        continue;
         if(HistoryDealGetInteger(ticket, DEAL_ENTRY) != DEAL_ENTRY_OUT) continue;

         g_tradesToday++;
         g_profitToday += HistoryDealGetDouble(ticket, DEAL_PROFIT)
                        + HistoryDealGetDouble(ticket, DEAL_COMMISSION)
                        + HistoryDealGetDouble(ticket, DEAL_SWAP);
        }
     }

   Print("[v4] Today's loaded stats — Trades: ", g_tradesToday, " | P&L: $", DoubleToString(g_profitToday, 2));
  }

//+------------------------------------------------------------------+
//|  Utility                                                         |
//+------------------------------------------------------------------+
void CloseAllPositions(string reason)
  {
   for(int i = PositionsTotal()-1; i >= 0; i--)
     {
      if(g_pos.SelectByIndex(i) &&
         g_pos.Magic() == InpMagicNumber &&
         g_pos.Symbol() == _Symbol)
        {
         g_trade.PositionClose(g_pos.Ticket());
         Print("[v4] Closed #", g_pos.Ticket(), " — Reason: ", reason);
        }
     }
  }

bool HasOpenPosition()
  {
   for(int i = PositionsTotal()-1; i >= 0; i--)
     {
      if(g_pos.SelectByIndex(i) &&
         g_pos.Magic() == InpMagicNumber &&
         g_pos.Symbol() == _Symbol)
         return true;
     }
   return false;
  }

double GetFloatingProfit()
  {
   double total = 0.0;
   for(int i = PositionsTotal()-1; i >= 0; i--)
     {
      if(g_pos.SelectByIndex(i) &&
         g_pos.Magic() == InpMagicNumber &&
         g_pos.Symbol() == _Symbol)
         total += g_pos.Profit() + g_pos.Swap() + g_pos.Commission();
     }
   return total;
  }

bool IsMarketOpen()
  {
   ENUM_SYMBOL_TRADE_MODE mode = (ENUM_SYMBOL_TRADE_MODE)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_MODE);
   return (mode == SYMBOL_TRADE_MODE_FULL ||
           mode == SYMBOL_TRADE_MODE_LONGONLY ||
           mode == SYMBOL_TRADE_MODE_SHORTONLY);
  }

datetime DayMidnight(datetime ts)
  {
   MqlDateTime d;
   TimeToStruct(ts, d);
   return ts - (datetime)(d.hour*3600 + d.min*60 + d.sec);
  }

//==========================================================================//
//  DASHBOARD                                                                //
//==========================================================================//
void InitDashboard()
  {
   int X = InpDashX, Y = InpDashY;

   MakeRect("bg",      X,   Y,   DW,   DH,   C_BG,    C_BORDER, 2);
   MakeRect("hdr",     X+2, Y+2, DW-4, 80,   C_HDRBAR,C_BORDER, 1);
   MakeLbl("htitle",   X+15,Y+10,"EliteScalper",       C_WHITE, 16,"Arial Black");
   MakeLbl("hversion", X+15,Y+36,"v4.00 — REBUILT ENGINE", C_BRAND, 9,"Arial Black");
   MakeLbl("hsub",     X+15,Y+54,"XAUUSD Institutional Scalper | Multi-Confirm", C_TEXT, 8,"Arial");

   // Account panel
   MakeRect("pnl1",    X+2, Y+88, DW-4, 145, C_PANEL, C_BORDER, 1);
   MakeLbl("hd1",      X+15,Y+96, "ACCOUNT DYNAMICS",  C_WHITE, 10,"Arial Black");
   MakeLbl("lb_bal",   X+20,Y+122,"Balance:",           C_TEXT,   9,"Arial");
   MakeLbl("vl_bal",   X+220,Y+122,"$ ---",             C_WHITE,  10,"Arial Bold");
   MakeLbl("lb_eq",    X+20,Y+147,"Equity:",            C_TEXT,   9,"Arial");
   MakeLbl("vl_eq",    X+220,Y+147,"$ ---",             C_WHITE,  10,"Arial Bold");
   MakeLbl("lb_dp",    X+20,Y+172,"Today P&L:",         C_TEXT,   9,"Arial");
   MakeLbl("vl_dp",    X+220,Y+172,"$ ---",             C_GREEN,  10,"Arial Bold");
   MakeLbl("lb_fp",    X+20,Y+197,"Floating P&L:",      C_TEXT,   9,"Arial");
   MakeLbl("vl_fp",    X+220,Y+197,"$ ---",             C_GREEN,  10,"Arial Bold");

   // Execution panel
   MakeRect("pnl2",    X+2, Y+240, DW-4, 210, C_PANEL, C_BORDER, 1);
   MakeLbl("hd2",      X+15,Y+248,"EXECUTION STATUS",   C_WHITE, 10,"Arial Black");
   MakeLbl("lb_sta",   X+20,Y+276,"Engine:",            C_TEXT,  9, "Arial");
   MakeLbl("vl_sta",   X+220,Y+276,"---",               C_BRAND, 9, "Arial Bold");
   MakeLbl("lb_sig",   X+20,Y+301,"Last Signal:",       C_TEXT,  9, "Arial");
   MakeLbl("vl_sig",   X+220,Y+301,"---",               C_TEXT,  9, "Arial Bold");
   MakeLbl("lb_htf",   X+20,Y+326,"HTF Bias (M15):",    C_TEXT,  9, "Arial");
   MakeLbl("vl_htf",   X+220,Y+326,"---",               C_TEXT,  9, "Arial Bold");
   MakeLbl("lb_trd",   X+20,Y+351,"Daily Trades:",      C_TEXT,  9, "Arial");
   MakeLbl("vl_trd",   X+220,Y+351,"0 / 6",             C_WHITE, 9, "Arial Bold");
   MakeLbl("lb_risk",  X+20,Y+376,"Risk/Trade:",        C_TEXT,  9, "Arial");
   MakeLbl("vl_risk",  X+220,Y+376,DoubleToString(InpRiskPercent,1)+"% balance",C_GOLD, 9,"Arial Bold");
   MakeLbl("lb_rr",    X+20,Y+401,"Min R:R:",           C_TEXT,  9, "Arial");
   MakeLbl("vl_rr",    X+220,Y+401,"1:" + DoubleToString(InpTPMultiplier/InpSLMultiplier,2), C_GREEN, 9,"Arial Bold");
   MakeLbl("lb_sess",  X+20,Y+426,"Session:",           C_TEXT,  9, "Arial");
   MakeLbl("vl_sess",  X+220,Y+426,"---",               C_TEXT,  9, "Arial Bold");

   // Footer
   MakeRect("ftr",     X+2, Y+458, DW-4, 140, C_BG, clrNONE, 0);
   MakeLbl("ft1",      X+15,Y+468,"Fixes Applied:",          C_DGRAY, 8,"Arial Black");
   MakeLbl("ft2",      X+15,Y+484,"✓ ATR-based SL/TP   ✓ EMA Cross confirmed",C_DGRAY,8,"Arial");
   MakeLbl("ft3",      X+15,Y+500,"✓ HTF M15 bias filter  ✓ RSI confirm",     C_DGRAY,8,"Arial");
   MakeLbl("ft4",      X+15,Y+516,"✓ Risk % sizing  ✓ Session filter",         C_DGRAY,8,"Arial");
   MakeLbl("ft5",      X+15,Y+532,"✓ Candle-close gate  ✓ Daily loss cap",     C_DGRAY,8,"Arial");
   MakeLbl("ft6",      X+15,Y+552,"Symbol: "+_Symbol+" | Magic: "+IntegerToString((long)InpMagicNumber),C_DGRAY,8,"Arial");

   ChartRedraw(0);
  }

void UpdateDashboard()
  {
   double bal = AccountInfoDouble(ACCOUNT_BALANCE);
   double eq  = AccountInfoDouble(ACCOUNT_EQUITY);
   double fpl = GetFloatingProfit();

   UpdLbl("vl_bal", "$ " + DoubleToString(bal, 2));
   UpdLbl("vl_eq",  "$ " + DoubleToString(eq,  2));

   string dpStr = (g_profitToday >= 0 ? "+$ " : "-$ ") + DoubleToString(MathAbs(g_profitToday), 2);
   UpdLbl("vl_dp", dpStr, (g_profitToday >= 0 ? C_GREEN : C_RED));

   string fpStr = (fpl >= 0 ? "+$ " : "-$ ") + DoubleToString(MathAbs(fpl), 2);
   UpdLbl("vl_fp", fpStr, (fpl >= 0 ? C_GREEN : C_RED));

   UpdLbl("vl_sta", g_statusMsg, g_statusClr);
   UpdLbl("vl_sig", g_signalMsg, g_signalClr);

   // HTF bias display
   ENUM_ORDER_TYPE bias;
   if(GetHTFBias(bias))
      UpdLbl("vl_htf", (bias == ORDER_TYPE_BUY ? "BULLISH" : "BEARISH"), (bias == ORDER_TYPE_BUY ? C_GREEN : C_RED));
   else
      UpdLbl("vl_htf", "NEUTRAL", C_GOLD);

   UpdLbl("vl_trd", IntegerToString(g_tradesToday) + " / " + IntegerToString(InpMaxDailyTrades));
   UpdLbl("vl_sess", IsSessionOpen() ? "ACTIVE" : "CLOSED", IsSessionOpen() ? C_GREEN : C_DGRAY);

   ChartRedraw(0);
  }

void DeleteDashboard() { ObjectsDeleteAll(0, DASH_PRE); ChartRedraw(0); }

void MakeRect(string nm,int x,int y,int w,int h,color bg,color brd,int bw)
  {
   string n = DASH_PRE + nm;
   ObjectCreate(0,n,OBJ_RECTANGLE_LABEL,0,0,0);
   ObjectSetInteger(0,n,OBJPROP_CORNER,CORNER_LEFT_UPPER);
   ObjectSetInteger(0,n,OBJPROP_XDISTANCE,x);
   ObjectSetInteger(0,n,OBJPROP_YDISTANCE,y);
   ObjectSetInteger(0,n,OBJPROP_XSIZE,w);
   ObjectSetInteger(0,n,OBJPROP_YSIZE,h);
   ObjectSetInteger(0,n,OBJPROP_BGCOLOR,bg);
   if(brd!=clrNONE)
     { ObjectSetInteger(0,n,OBJPROP_BORDER_TYPE,BORDER_FLAT);
       ObjectSetInteger(0,n,OBJPROP_COLOR,brd);
       ObjectSetInteger(0,n,OBJPROP_WIDTH,bw); }
   else
      ObjectSetInteger(0,n,OBJPROP_BORDER_TYPE,BORDER_RAISED);
   ObjectSetInteger(0,n,OBJPROP_SELECTABLE,false);
   ObjectSetInteger(0,n,OBJPROP_HIDDEN,true);
   ObjectSetInteger(0,n,OBJPROP_ZORDER,0);
  }

void MakeLbl(string nm,int x,int y,string txt,color clr,int fsz,string font)
  {
   string n = DASH_PRE + nm;
   ObjectCreate(0,n,OBJ_LABEL,0,0,0);
   ObjectSetInteger(0,n,OBJPROP_CORNER,CORNER_LEFT_UPPER);
   ObjectSetInteger(0,n,OBJPROP_XDISTANCE,x);
   ObjectSetInteger(0,n,OBJPROP_YDISTANCE,y);
   ObjectSetString(0,n,OBJPROP_TEXT,txt);
   ObjectSetInteger(0,n,OBJPROP_COLOR,clr);
   ObjectSetInteger(0,n,OBJPROP_FONTSIZE,fsz);
   ObjectSetString(0,n,OBJPROP_FONT,font);
   ObjectSetInteger(0,n,OBJPROP_SELECTABLE,false);
   ObjectSetInteger(0,n,OBJPROP_HIDDEN,true);
   ObjectSetInteger(0,n,OBJPROP_ZORDER,1);
  }

void UpdLbl(string nm,string txt,color clr=clrNONE)
  {
   string n = DASH_PRE + nm;
   if(ObjectFind(0,n) >= 0)
     {
      ObjectSetString(0,n,OBJPROP_TEXT,txt);
      if(clr!=clrNONE) ObjectSetInteger(0,n,OBJPROP_COLOR,clr);
     }
  }
//+------------------------------------------------------------------+
