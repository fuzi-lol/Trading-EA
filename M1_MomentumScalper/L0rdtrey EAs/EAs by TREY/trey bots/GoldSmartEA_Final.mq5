//+------------------------------------------------------------------+
//|                                           GoldSmartEA_Final.mq5 |
//|                                         Erstellt für Dubai Trader|
//|                          XAUUSD - MT5 - Vollautomatisch - Final  |
//|                                                    Version 2.0   |
//+------------------------------------------------------------------+
#property copyright "GoldSmartEA Final"
#property version   "2.00"
#property strict

#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>

CTrade         trade;
CPositionInfo  posInfo;

//+------------------------------------------------------------------+
//| INPUT PARAMETER                                                  |
//+------------------------------------------------------------------+

input group "=== LOTS & PYRAMIDE ==="
input double   Lot_Entry        = 0.05;   // Entry Lot (3x geöffnet)
input double   Lot_Recovery1    = 0.10;   // Recovery 1 Lot (2x bei -70 Pips)
input double   Lot_Recovery2    = 0.20;   // Recovery 2 Lot (1x bei -100 Pips)
input double   TP1_Pips         = 40.0;   // Take Profit 1 (alle schließen hier)
input double   TP2_Pips         = 80.0;   // Take Profit 2 (falls alleine offen)
input double   TP3_Pips         = 200.0;  // Take Profit 3 (letzter Trade)
input double   Trailing_Start   = 30.0;   // Trailing ab X Pips
input double   Trailing_Step    = 10.0;   // Trailing Schritt

input group "=== RECOVERY EINSTELLUNGEN ==="
input int      Recovery1_Pips   = 70;     // Recovery 1 bei -X Pips
input int      Recovery2_Pips   = 100;    // Recovery 2 bei -X Pips
input int      MinConfirmations = 3;      // Mindest Bestätigungen (von 4)

input group "=== PARTIAL PROFIT LOCK ==="
input double   Partial1_Pips    = 30.0;   // Erste Teilschließung bei X Pips
input double   Partial1_Percent = 30.0;   // % der Position schließen
input double   Partial2_Pips    = 60.0;   // Zweite Teilschließung
input double   Partial2_Percent = 30.0;   // % der Position schließen

input group "=== RISK MANAGEMENT ==="
input double   DailyLossStop    = 10.0;   // Tagesverlust Stop %
input double   PartialCloseAt   = 5.0;    // Notfall Partial Close %
input double   SpreadMaxPips    = 5.0;    // Max Spread in Pips
input double   MinBodyRatio     = 0.3;    // Min Kerzenkörper Ratio

input group "=== SESSION FILTER (Dubai GMT+4) ==="
input int      Asia_Start       = 1;      // Asia Start (01:00)
input int      Asia_End         = 9;      // Asia Ende  (09:00)
input int      NY_Start         = 18;     // NY Start nach News (18:00)
input int      NY_End           = 23;     // NY Ende (23:00)
input int      News_Block_Start = 16;     // News Sperre Start
input int      News_Block_Mins  = 30;     // News Sperre Minuten
input bool     No_Friday_Eve    = true;   // Freitag Abend gesperrt
input int      Friday_Stop      = 20;     // Freitag Stop Uhrzeit
input bool     Close_Before_NY  = true;   // Asia Trades vor NY schließen
input bool     Close_Before_WE  = true;   // Trades vor Wochenende schließen

input group "=== INDIKATOREN ==="
input int      EMA_Fast         = 20;     // EMA Fast
input int      EMA_Slow         = 50;     // EMA Slow
input int      EMA_H4           = 200;    // H4 Trend EMA
input int      RSI_Period       = 14;     // RSI Periode
input double   RSI_OB           = 75.0;   // RSI Überkauft (für Recovery)
input double   RSI_OS           = 25.0;   // RSI Überverkauft (für Recovery)
input int      ATR_Period       = 14;     // ATR Periode
input double   ATR_SL_Multi     = 1.5;    // ATR Stop Loss Multiplikator
input double   ATR_TP_Multi     = 3.0;    // ATR Take Profit Multiplikator

//+------------------------------------------------------------------+
//| GLOBALE VARIABLEN                                                |
//+------------------------------------------------------------------+
double   PipSize            = 0.1;
double   DailyStartBalance  = 0;
bool     DailyStopReached   = false;
bool     EmergencyPartial   = false;
datetime LastBarTime        = 0;
int      LastDay            = -1;

// Indikatoren Handles
int      H_EMA_Fast, H_EMA_Slow, H_EMA_H4, H_RSI, H_ATR;
int      H_EMA_Fast_H4, H_RSI_H4;

// Asian Range
double   AsianHigh = 0;
double   AsianLow  = 0;
bool     AsianRangeSet = false;

// Trade Tracking
ulong    EntryTickets[3];   // 3 Entry Trades
ulong    R1Tickets[2];      // 2 Recovery 1 Trades
ulong    R1Ticket2;         // 1 Recovery 2 Trade
bool     R1Opened = false;
bool     R2Opened = false;
bool     TP1Hit   = false;

// Partial Close Tracking
bool     Partial1Done = false;
bool     Partial2Done = false;

//+------------------------------------------------------------------+
//| INITIALISIERUNG                                                  |
//+------------------------------------------------------------------+
int OnInit()
{
   PipSize = _Point * 10;

   // H1 Indikatoren
   H_EMA_Fast = iMA(_Symbol, PERIOD_H1, EMA_Fast, 0, MODE_EMA, PRICE_CLOSE);
   H_EMA_Slow = iMA(_Symbol, PERIOD_H1, EMA_Slow, 0, MODE_EMA, PRICE_CLOSE);
   H_RSI      = iRSI(_Symbol, PERIOD_H1, RSI_Period, PRICE_CLOSE);
   H_ATR      = iATR(_Symbol, PERIOD_H1, ATR_Period);

   // H4 Indikatoren
   H_EMA_Fast_H4 = iMA(_Symbol, PERIOD_H4, EMA_Fast, 0, MODE_EMA, PRICE_CLOSE);
   H_EMA_H4      = iMA(_Symbol, PERIOD_H4, EMA_H4, 0, MODE_EMA, PRICE_CLOSE);
   H_RSI_H4      = iRSI(_Symbol, PERIOD_H4, RSI_Period, PRICE_CLOSE);

   if(H_EMA_Fast == INVALID_HANDLE || H_EMA_Slow == INVALID_HANDLE ||
      H_RSI == INVALID_HANDLE || H_ATR == INVALID_HANDLE ||
      H_EMA_H4 == INVALID_HANDLE)
   {
      Print("❌ Fehler Indikatoren!");
      return INIT_FAILED;
   }

   DailyStartBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   trade.SetExpertMagicNumber(789456);
   ArrayInitialize(EntryTickets, 0);
   ArrayInitialize(R1Tickets, 0);
   R1Ticket2 = 0;

   Print("✅ GoldSmartEA Final gestartet | Balance: $", DailyStartBalance);
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| DEINIT                                                           |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   IndicatorRelease(H_EMA_Fast);
   IndicatorRelease(H_EMA_Slow);
   IndicatorRelease(H_RSI);
   IndicatorRelease(H_ATR);
   IndicatorRelease(H_EMA_Fast_H4);
   IndicatorRelease(H_EMA_H4);
   IndicatorRelease(H_RSI_H4);
}

//+------------------------------------------------------------------+
//| HAUPTFUNKTION                                                    |
//+------------------------------------------------------------------+
void OnTick()
{
   // Täglichen Reset checken
   CheckDailyReset();

   // Tagesverlust gecheckt
   if(DailyStopReached)
   {
      CloseAllTrades();
      return;
   }

   if(CheckDailyLoss())
   {
      Print("🚨 TAGESVERLUST LIMIT! EA stoppt heute.");
      DailyStopReached = true;
      CloseAllTrades();
      return;
   }

   // Session Ende Management
   ManageSessionClose();

   // Notfall Partial Close
   CheckEmergencyPartial();

   // Trailing Stop
   ManageTrailingStop();

   // Partial Profit Lock
   ManagePartialProfitLock();

   // TP1 Check → alle schließen
   CheckTP1Hit();

   // Recovery Trades
   CheckRecovery();

   // Neue H1 Kerze abwarten
   datetime currentBar = iTime(_Symbol, PERIOD_H1, 0);
   if(currentBar == LastBarTime) return;
   LastBarTime = currentBar;

   // Asian Range updaten
   UpdateAsianRange();

   // Session erlaubt?
   if(!IsSessionAllowed()) return;

   // Spread okay?
   if(!IsSpreadOkay()) return;

   // Schon Trades offen?
   if(CountMyTrades() >= 3) return;

   // Nur neue Trades wenn keine Entry Trades offen
   if(HasOpenEntryTrades()) return;

   // Signal holen
   int signal = GetSignal();

   if(signal == 1)
   {
      OpenEntryTrades(ORDER_TYPE_BUY);
   }
   else if(signal == -1)
   {
      OpenEntryTrades(ORDER_TYPE_SELL);
   }
}

//+------------------------------------------------------------------+
//| SIGNAL BERECHNUNG - Kombiniert H1 + H4                          |
//+------------------------------------------------------------------+
int GetSignal()
{
   // H1 Daten
   double emaFast[], emaSlow[], rsi[], atr[];
   ArraySetAsSeries(emaFast, true);
   ArraySetAsSeries(emaSlow, true);
   ArraySetAsSeries(rsi, true);
   ArraySetAsSeries(atr, true);

   if(CopyBuffer(H_EMA_Fast, 0, 0, 4, emaFast) < 4) return 0;
   if(CopyBuffer(H_EMA_Slow, 0, 0, 4, emaSlow) < 4) return 0;
   if(CopyBuffer(H_RSI, 0, 0, 4, rsi) < 4) return 0;
   if(CopyBuffer(H_ATR, 0, 0, 2, atr) < 2) return 0;

   // H4 Trend Filter
   double emaH4Fast[], emaH4[];
   ArraySetAsSeries(emaH4Fast, true);
   ArraySetAsSeries(emaH4, true);
   if(CopyBuffer(H_EMA_Fast_H4, 0, 0, 2, emaH4Fast) < 2) return 0;
   if(CopyBuffer(H_EMA_H4, 0, 0, 2, emaH4) < 2) return 0;

   // Kerzen H1
   double close[], open[], high[], low[];
   ArraySetAsSeries(close, true);
   ArraySetAsSeries(open, true);
   ArraySetAsSeries(high, true);
   ArraySetAsSeries(low, true);

   if(CopyClose(_Symbol, PERIOD_H1, 0, 4, close) < 4) return 0;
   if(CopyOpen(_Symbol, PERIOD_H1, 0, 4, open) < 4) return 0;
   if(CopyHigh(_Symbol, PERIOD_H1, 0, 4, high) < 4) return 0;
   if(CopyLow(_Symbol, PERIOD_H1, 0, 4, low) < 4) return 0;

   // H4 Trend Richtung
   bool h4Bullish = emaH4Fast[1] > emaH4[1];
   bool h4Bearish = emaH4Fast[1] < emaH4[1];

   // Letzte geschlossene Kerze
   double c0 = close[1], o0 = open[1], h0 = high[1], l0 = low[1];
   double c1 = close[2], o1 = open[2];
   double body0  = MathAbs(c0 - o0);
   double range0 = h0 - l0;
   double wick_down = (o0 > c0) ? (c0 - l0) : (o0 - l0); // Unterer Docht
   double wick_up   = (o0 > c0) ? (h0 - o0) : (h0 - c0); // Oberer Docht

   // Kerze stark genug?
   if(range0 < atr[1] * 0.3) return 0;

   // Asian Range Breakout Signal
   bool asianBreakoutBuy  = AsianRangeSet && close[1] > AsianHigh && close[2] <= AsianHigh;
   bool asianBreakoutSell = AsianRangeSet && close[1] < AsianLow  && close[2] >= AsianLow;

   // Runde Levels (Support/Resistance)
   double roundLevel = MathRound(close[1] / 50.0) * 50.0;
   bool nearRoundLevel = MathAbs(close[1] - roundLevel) < 5.0 * PipSize;

   // ===== BUY SIGNAL =====
   bool ema_bull        = emaFast[1] > emaSlow[1];                          // EMA Aufwärts
   bool rsi_bull        = rsi[2] < 45 && rsi[1] > 45;                      // RSI dreht hoch
   bool bull_engulf     = c0 > o0 && c0 > c1 && o0 < o1;                   // Bullisch Engulfing
   bool bull_doji       = wick_down > body0 * 2.0 && c0 > o0;              // Langer Docht unten
   bool liq_sweep_bull  = l0 < low[2] && c0 > open[2];                     // Liquidity Sweep

   int buyScore = 0;
   if(h4Bullish)      buyScore++;
   if(ema_bull)       buyScore++;
   if(rsi_bull)       buyScore++;
   if(bull_engulf || bull_doji || liq_sweep_bull) buyScore++;
   if(asianBreakoutBuy || nearRoundLevel)         buyScore++;

   // ===== SELL SIGNAL =====
   bool ema_bear        = emaFast[1] < emaSlow[1];                          // EMA Abwärts
   bool rsi_bear        = rsi[2] > 55 && rsi[1] < 55;                      // RSI dreht runter
   bool bear_engulf     = c0 < o0 && c0 < c1 && o0 > o1;                   // Bearisch Engulfing
   bool bear_doji       = wick_up > body0 * 2.0 && c0 < o0;               // Langer Docht oben
   bool liq_sweep_bear  = h0 > high[2] && c0 < open[2];                    // Liquidity Sweep

   int sellScore = 0;
   if(h4Bearish)      sellScore++;
   if(ema_bear)       sellScore++;
   if(rsi_bear)       sellScore++;
   if(bear_engulf || bear_doji || liq_sweep_bear) sellScore++;
   if(asianBreakoutSell || nearRoundLevel)        sellScore++;

   // Mindestens 3 von 5 Bestätigungen
   if(buyScore >= 3 && buyScore > sellScore)  return 1;
   if(sellScore >= 3 && sellScore > buyScore) return -1;

   return 0;
}

//+------------------------------------------------------------------+
//| RECOVERY BESTÄTIGUNGEN                                           |
//+------------------------------------------------------------------+
int GetRecoveryConfirmations(int direction)
{
   double rsi[], rsiH4[];
   ArraySetAsSeries(rsi, true);
   ArraySetAsSeries(rsiH4, true);

   if(CopyBuffer(H_RSI, 0, 0, 3, rsi) < 3)    return 0;
   if(CopyBuffer(H_RSI_H4, 0, 0, 3, rsiH4) < 3) return 0;

   double high[], low[], close[], open[];
   ArraySetAsSeries(high, true);
   ArraySetAsSeries(low, true);
   ArraySetAsSeries(close, true);
   ArraySetAsSeries(open, true);

   if(CopyHigh(_Symbol, PERIOD_H1, 0, 3, high) < 3)   return 0;
   if(CopyLow(_Symbol, PERIOD_H1, 0, 3, low) < 3)     return 0;
   if(CopyClose(_Symbol, PERIOD_H1, 0, 3, close) < 3) return 0;
   if(CopyOpen(_Symbol, PERIOD_H1, 0, 3, open) < 3)   return 0;

   double emaH4Fast[], emaH4[];
   ArraySetAsSeries(emaH4Fast, true);
   ArraySetAsSeries(emaH4, true);
   if(CopyBuffer(H_EMA_Fast_H4, 0, 0, 2, emaH4Fast) < 2) return 0;
   if(CopyBuffer(H_EMA_H4, 0, 0, 2, emaH4) < 2)          return 0;

   int confirmations = 0;
   double body  = MathAbs(close[1] - open[1]);
   double range = high[1] - low[1];
   double wick_down = MathMin(open[1], close[1]) - low[1];
   double wick_up   = high[1] - MathMax(open[1], close[1]);

   if(direction == 1) // BUY Recovery
   {
      if(rsi[1] < RSI_OS)                                confirmations++; // RSI extrem überverkauft
      if(wick_down > body * 2.0)                         confirmations++; // Langer Docht unten
      if(emaH4Fast[1] > emaH4[1])                        confirmations++; // H4 noch bullisch
      if(close[1] > open[1] && close[1] > close[2])     confirmations++; // Bullische Erholungskerze
   }
   else // SELL Recovery
   {
      if(rsi[1] > RSI_OB)                                confirmations++; // RSI extrem überkauft
      if(wick_up > body * 2.0)                           confirmations++; // Langer Docht oben
      if(emaH4Fast[1] < emaH4[1])                        confirmations++; // H4 noch bearisch
      if(close[1] < open[1] && close[1] < close[2])     confirmations++; // Bearische Erholungskerze
   }

   return confirmations;
}

//+------------------------------------------------------------------+
//| 3 ENTRY TRADES ÖFFNEN                                           |
//+------------------------------------------------------------------+
void OpenEntryTrades(ENUM_ORDER_TYPE type)
{
   double atr[];
   ArraySetAsSeries(atr, true);
   if(CopyBuffer(H_ATR, 0, 0, 2, atr) < 2) return;

   double ask  = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid  = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double atrVal = atr[1];

   // Dynamischer SL und TP basierend auf ATR
   double sl_distance = atrVal * ATR_SL_Multi;
   double tp1_dist    = TP1_Pips * PipSize;
   double tp2_dist    = TP2_Pips * PipSize;
   double tp3_dist    = TP3_Pips * PipSize;

   ArrayInitialize(EntryTickets, 0);
   R1Opened = false;
   R2Opened = false;
   TP1Hit   = false;
   Partial1Done = false;
   Partial2Done = false;

   for(int i = 0; i < 3; i++)
   {
      double tp_dist;
      if(i == 0)      tp_dist = tp1_dist;
      else if(i == 1) tp_dist = tp2_dist;
      else            tp_dist = tp3_dist;

      double sl, tp, price;

      if(type == ORDER_TYPE_BUY)
      {
         price = ask;
         sl    = NormalizeDouble(price - sl_distance, _Digits);
         tp    = NormalizeDouble(price + tp_dist, _Digits);
         if(trade.Buy(Lot_Entry, _Symbol, price, sl, tp, "GS_Entry_" + IntegerToString(i+1)))
         {
            EntryTickets[i] = trade.ResultOrder();
            Print("✅ BUY Entry ", i+1, " | TP: +", (int)(tp_dist/PipSize), " Pips");
         }
      }
      else
      {
         price = bid;
         sl    = NormalizeDouble(price + sl_distance, _Digits);
         tp    = NormalizeDouble(price - tp_dist, _Digits);
         if(trade.Sell(Lot_Entry, _Symbol, price, sl, tp, "GS_Entry_" + IntegerToString(i+1)))
         {
            EntryTickets[i] = trade.ResultOrder();
            Print("✅ SELL Entry ", i+1, " | TP: +", (int)(tp_dist/PipSize), " Pips");
         }
      }
   }
}

//+------------------------------------------------------------------+
//| TP1 CHECK → ALLE SCHLIESSEN                                     |
//+------------------------------------------------------------------+
void CheckTP1Hit()
{
   if(TP1Hit) return;
   if(EntryTickets[0] == 0) return;

   // Prüfe ob Trade 1 (TP1) geschlossen wurde durch Gewinn
   bool trade1Closed = !PositionSelectByTicket(EntryTickets[0]);

   if(trade1Closed && EntryTickets[0] != 0)
   {
      // Prüfe ob es durch TP geschlossen wurde (nicht SL)
      if(IsClosedByTP(EntryTickets[0]))
      {
         TP1Hit = true;
         Print("🎯 TP1 erreicht! Schließe alle Trades...");
         CloseAllMyTrades();
      }
   }
}

//+------------------------------------------------------------------+
//| Prüfen ob Trade durch TP geschlossen                            |
//+------------------------------------------------------------------+
bool IsClosedByTP(ulong ticket)
{
   if(HistoryDealSelect(ticket)) return false;

   HistorySelect(TimeCurrent() - 86400, TimeCurrent());
   int deals = HistoryDealsTotal();
   for(int i = deals - 1; i >= 0; i--)
   {
      ulong dealTicket = HistoryDealGetTicket(i);
      if(HistoryDealGetInteger(dealTicket, DEAL_POSITION_ID) == ticket)
      {
         double profit = HistoryDealGetDouble(dealTicket, DEAL_PROFIT);
         return profit > 0;
      }
   }
   return false;
}

//+------------------------------------------------------------------+
//| RECOVERY TRADES                                                  |
//+------------------------------------------------------------------+
void CheckRecovery()
{
   if(EntryTickets[0] == 0) return;

   // Richtung der Entry Trades bestimmen
   int direction = 0;
   for(int i = 0; i < 3; i++)
   {
      if(EntryTickets[i] != 0 && PositionSelectByTicket(EntryTickets[i]))
      {
         direction = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) ? 1 : -1;
         break;
      }
   }
   if(direction == 0) return;

   // Durchschnittlicher Verlust der Entry Trades in Pips
   double avgLossPips = GetAverageLossPips();

   // Recovery 1: Bei -70 Pips
   if(!R1Opened && avgLossPips >= Recovery1_Pips)
   {
      int confirmations = GetRecoveryConfirmations(direction);
      if(confirmations >= MinConfirmations)
      {
         Print("🔄 Recovery 1 öffnen | Verlust: ", avgLossPips, " Pips | Bestätigungen: ", confirmations);
         OpenRecoveryTrades(direction, 1);
         R1Opened = true;
      }
      else
      {
         Print("⏳ Recovery 1 warten | Nur ", confirmations, "/", MinConfirmations, " Bestätigungen");
      }
   }

   // Recovery 2: Bei -100 Pips
   if(R1Opened && !R2Opened && avgLossPips >= Recovery2_Pips)
   {
      int confirmations = GetRecoveryConfirmations(direction);
      if(confirmations >= MinConfirmations)
      {
         Print("🔄 Recovery 2 öffnen | Verlust: ", avgLossPips, " Pips | Bestätigungen: ", confirmations);
         OpenRecoveryTrades(direction, 2);
         R2Opened = true;
      }
   }
}

//+------------------------------------------------------------------+
//| Recovery Trades öffnen                                          |
//+------------------------------------------------------------------+
void OpenRecoveryTrades(int direction, int level)
{
   double atr[];
   ArraySetAsSeries(atr, true);
   if(CopyBuffer(H_ATR, 0, 0, 2, atr) < 2) return;

   double sl_dist = atr[1] * ATR_SL_Multi;
   double tp_dist = TP1_Pips * PipSize; // Alle Recovery bei TP1 schließen

   int numTrades = (level == 1) ? 2 : 1;
   double lot    = (level == 1) ? Lot_Recovery1 : Lot_Recovery2;

   for(int i = 0; i < numTrades; i++)
   {
      if(direction == 1)
      {
         double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
         double sl  = NormalizeDouble(ask - sl_dist, _Digits);
         double tp  = NormalizeDouble(ask + tp_dist, _Digits);
         trade.Buy(lot, _Symbol, ask, sl, tp, "GS_R" + IntegerToString(level));
      }
      else
      {
         double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
         double sl  = NormalizeDouble(bid + sl_dist, _Digits);
         double tp  = NormalizeDouble(bid - tp_dist, _Digits);
         trade.Sell(lot, _Symbol, bid, sl, tp, "GS_R" + IntegerToString(level));
      }
      Print("✅ Recovery ", level, " Trade ", i+1, " geöffnet | Lot: ", lot);
   }
}

//+------------------------------------------------------------------+
//| PARTIAL PROFIT LOCK                                             |
//+------------------------------------------------------------------+
void ManagePartialProfitLock()
{
   for(int i = 0; i < 3; i++)
   {
      if(EntryTickets[i] == 0) continue;
      if(!PositionSelectByTicket(EntryTickets[i])) continue;

      double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
      double curPrice;
      ENUM_POSITION_TYPE type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);

      if(type == POSITION_TYPE_BUY)
         curPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      else
         curPrice = SymbolInfoDouble(_Symbol, SYMBOL_ASK);

      double profitPips = (type == POSITION_TYPE_BUY) ?
                          (curPrice - openPrice) / PipSize :
                          (openPrice - curPrice) / PipSize;

      // Erste Teilschließung
      if(!Partial1Done && profitPips >= Partial1_Pips && i == 2) // Nur auf Trade 3
      {
         double vol     = PositionGetDouble(POSITION_VOLUME);
         double partial = NormalizeDouble(vol * Partial1_Percent / 100.0, 2);
         if(partial >= 0.01)
         {
            trade.PositionClosePartial(EntryTickets[i], partial);
            Print("💰 Partial 1: ", Partial1_Percent, "% bei +", profitPips, " Pips geschlossen");
            Partial1Done = true;
         }
      }

      // Zweite Teilschließung + Break Even auf Rest
      if(Partial1Done && !Partial2Done && profitPips >= Partial2_Pips && i == 2)
      {
         double vol     = PositionGetDouble(POSITION_VOLUME);
         double partial = NormalizeDouble(vol * Partial2_Percent / 100.0, 2);
         if(partial >= 0.01)
         {
            trade.PositionClosePartial(EntryTickets[i], partial);
            Print("💰 Partial 2: ", Partial2_Percent, "% bei +", profitPips, " Pips geschlossen");
            Partial2Done = true;

            // Break Even auf alle verbleibenden Trades
            SetBreakEvenAll();
         }
      }
   }
}

//+------------------------------------------------------------------+
//| BREAK EVEN AUF ALLE TRADES                                      |
//+------------------------------------------------------------------+
void SetBreakEvenAll()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(!posInfo.SelectByIndex(i)) continue;
      if(posInfo.Magic() != 789456) continue;

      double openPrice = posInfo.PriceOpen();
      double currentSL = posInfo.StopLoss();
      double spread    = (SymbolInfoDouble(_Symbol, SYMBOL_ASK) - SymbolInfoDouble(_Symbol, SYMBOL_BID));

      double newSL;
      if(posInfo.PositionType() == POSITION_TYPE_BUY)
      {
         newSL = NormalizeDouble(openPrice + spread, _Digits);
         if(newSL > currentSL)
         {
            trade.PositionModify(posInfo.Ticket(), newSL, posInfo.TakeProfit());
            Print("🔒 Break Even gesetzt auf ", newSL);
         }
      }
      else
      {
         newSL = NormalizeDouble(openPrice - spread, _Digits);
         if(newSL < currentSL || currentSL == 0)
         {
            trade.PositionModify(posInfo.Ticket(), newSL, posInfo.TakeProfit());
            Print("🔒 Break Even gesetzt auf ", newSL);
         }
      }
   }
}

//+------------------------------------------------------------------+
//| TRAILING STOP                                                    |
//+------------------------------------------------------------------+
void ManageTrailingStop()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(!posInfo.SelectByIndex(i)) continue;
      if(posInfo.Magic() != 789456) continue;

      double openPrice  = posInfo.PriceOpen();
      double currentSL  = posInfo.StopLoss();
      double currentTP  = posInfo.TakeProfit();

      if(posInfo.PositionType() == POSITION_TYPE_BUY)
      {
         double bid        = SymbolInfoDouble(_Symbol, SYMBOL_BID);
         double profitPips = (bid - openPrice) / PipSize;

         if(profitPips >= Trailing_Start)
         {
            double newSL = NormalizeDouble(bid - Trailing_Step * PipSize, _Digits);
            if(newSL > currentSL)
            {
               trade.PositionModify(posInfo.Ticket(), newSL, currentTP);
            }
         }
      }
      else
      {
         double ask        = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
         double profitPips = (openPrice - ask) / PipSize;

         if(profitPips >= Trailing_Start)
         {
            double newSL = NormalizeDouble(ask + Trailing_Step * PipSize, _Digits);
            if(newSL < currentSL || currentSL == 0)
            {
               trade.PositionModify(posInfo.Ticket(), newSL, currentTP);
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//| ASIAN RANGE BERECHNEN                                           |
//+------------------------------------------------------------------+
void UpdateAsianRange()
{
   MqlDateTime dt;
   TimeToStruct(TimeLocal(), dt);
   int hour = dt.hour;

   // Am Ende der Asia Session Range festhalten
   if(hour == Asia_End)
   {
      double hi[], lo[];
      ArraySetAsSeries(hi, true);
      ArraySetAsSeries(lo, true);

      int bars = Asia_End - Asia_Start;
      if(bars <= 0) bars = 8;

      if(CopyHigh(_Symbol, PERIOD_H1, 0, bars, hi) >= bars &&
         CopyLow(_Symbol, PERIOD_H1, 0, bars, lo) >= bars)
      {
         AsianHigh     = hi[ArrayMaximum(hi, 0, bars)];
         AsianLow      = lo[ArrayMinimum(lo, 0, bars)];
         AsianRangeSet = true;
         Print("📊 Asian Range: High=", AsianHigh, " Low=", AsianLow);
      }
   }

   // Reset für neuen Tag
   if(hour == Asia_Start) AsianRangeSet = false;
}

//+------------------------------------------------------------------+
//| SESSION CLOSE MANAGEMENT                                        |
//+------------------------------------------------------------------+
void ManageSessionClose()
{
   MqlDateTime dt;
   TimeToStruct(TimeLocal(), dt);
   int hour = dt.hour;
   int dow  = dt.day_of_week;

   // Freitag Abend → alle schließen
   if(No_Friday_Eve && dow == 5 && hour >= Friday_Stop)
   {
      if(CountMyTrades() > 0)
      {
         Print("📅 Freitag Abend → alle Trades schließen");
         CloseAllMyTrades();
      }
   }

   // Asia Trades vor NY schließen (profitable)
   if(Close_Before_NY && hour == NY_Start - 1)
   {
      CloseProfitableTrades();
   }
}

//+------------------------------------------------------------------+
//| NUR PROFITABLE TRADES SCHLIESSEN                               |
//+------------------------------------------------------------------+
void CloseProfitableTrades()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(!posInfo.SelectByIndex(i)) continue;
      if(posInfo.Magic() != 789456) continue;
      if(posInfo.Profit() > 0)
      {
         trade.PositionClose(posInfo.Ticket());
         Print("✅ Profitabler Trade geschlossen vor Session Ende");
      }
   }
}

//+------------------------------------------------------------------+
//| NOTFALL PARTIAL CLOSE                                           |
//+------------------------------------------------------------------+
void CheckEmergencyPartial()
{
   if(EmergencyPartial) return;

   double balance  = AccountInfoDouble(ACCOUNT_BALANCE);
   double equity   = AccountInfoDouble(ACCOUNT_EQUITY);
   double lossPerc = ((balance - equity) / balance) * 100.0;

   if(lossPerc >= PartialCloseAt)
   {
      Print("⚠️ NOTFALL Partial Close bei ", lossPerc, "% Verlust");
      for(int i = PositionsTotal() - 1; i >= 0; i--)
      {
         if(!posInfo.SelectByIndex(i)) continue;
         if(posInfo.Magic() != 789456) continue;
         double halfLot = NormalizeDouble(posInfo.Volume() / 2.0, 2);
         if(halfLot >= 0.01)
            trade.PositionClosePartial(posInfo.Ticket(), halfLot);
      }
      EmergencyPartial = true;
   }
}

//+------------------------------------------------------------------+
//| TAGESVERLUST PRÜFEN                                             |
//+------------------------------------------------------------------+
bool CheckDailyLoss()
{
   double equity   = AccountInfoDouble(ACCOUNT_EQUITY);
   double lossPerc = ((DailyStartBalance - equity) / DailyStartBalance) * 100.0;
   return lossPerc >= DailyLossStop;
}

//+------------------------------------------------------------------+
//| TÄGLICHEN RESET                                                 |
//+------------------------------------------------------------------+
void CheckDailyReset()
{
   MqlDateTime dt;
   TimeToStruct(TimeLocal(), dt);

   if(dt.day != LastDay)
   {
      LastDay           = dt.day;
      DailyStartBalance = AccountInfoDouble(ACCOUNT_BALANCE);
      DailyStopReached  = false;
      EmergencyPartial  = false;
      AsianRangeSet     = false;
      Print("📅 Neuer Tag Reset | Balance: $", DailyStartBalance);
   }
}

//+------------------------------------------------------------------+
//| SPREAD PRÜFEN                                                   |
//+------------------------------------------------------------------+
bool IsSpreadOkay()
{
   double spread    = (double)(SymbolInfoInteger(_Symbol, SYMBOL_SPREAD)) * _Point;
   double maxSpread = SpreadMaxPips * PipSize;
   return spread <= maxSpread;
}

//+------------------------------------------------------------------+
//| SESSION FILTER                                                  |
//+------------------------------------------------------------------+
bool IsSessionAllowed()
{
   MqlDateTime dt;
   TimeToStruct(TimeLocal(), dt);
   int hour = dt.hour;
   int min  = dt.min;
   int dow  = dt.day_of_week;

   if(dow == 0 || dow == 6) return false;
   if(No_Friday_Eve && dow == 5 && hour >= Friday_Stop) return false;
   if(hour == News_Block_Start && min < News_Block_Mins) return false;

   // Asia Session
   if(hour >= Asia_Start && hour < Asia_End) return true;

   // NY Session nach News
   if(hour >= NY_Start && hour <= NY_End) return true;

   return false;
}

//+------------------------------------------------------------------+
//| HILFSFUNKTIONEN                                                 |
//+------------------------------------------------------------------+
double GetAverageLossPips()
{
   double totalLoss = 0;
   int    count     = 0;

   for(int i = 0; i < 3; i++)
   {
      if(EntryTickets[i] == 0) continue;
      if(!PositionSelectByTicket(EntryTickets[i])) continue;

      double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
      ENUM_POSITION_TYPE type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      double curPrice;

      if(type == POSITION_TYPE_BUY)
         curPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      else
         curPrice = SymbolInfoDouble(_Symbol, SYMBOL_ASK);

      double lossPips = (type == POSITION_TYPE_BUY) ?
                        (openPrice - curPrice) / PipSize :
                        (curPrice - openPrice) / PipSize;

      if(lossPips > 0) { totalLoss += lossPips; count++; }
   }

   return count > 0 ? totalLoss / count : 0;
}

bool HasOpenEntryTrades()
{
   for(int i = 0; i < 3; i++)
   {
      if(EntryTickets[i] != 0 && PositionSelectByTicket(EntryTickets[i]))
         return true;
   }
   return false;
}

int CountMyTrades()
{
   int count = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(!posInfo.SelectByIndex(i)) continue;
      if(posInfo.Magic() == 789456) count++;
   }
   return count;
}

void CloseAllMyTrades()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(!posInfo.SelectByIndex(i)) continue;
      if(posInfo.Magic() != 789456) continue;
      trade.PositionClose(posInfo.Ticket());
   }
}

void CloseAllTrades()
{
   CloseAllMyTrades();
}
//+------------------------------------------------------------------+