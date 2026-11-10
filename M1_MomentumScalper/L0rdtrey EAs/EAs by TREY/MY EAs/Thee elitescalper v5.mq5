//+------------------------------------------------------------------+
//|                                      THEE EliteScalper v5.0.mq5  |
//|                                  Copyright 2026, FXBotHub Systems|
//|                                             https://fxbothub.com |
//+------------------------------------------------------------------+
#property copyright   "Copyright 2026, FXBotHub Systems"
#property version     "5.00"
#property description "Institutional XAUUSD Scalper | $5 Micro Account Edition"
#property description "7-Layer Confluence | ATR Risk Engine | Smart $5 Protection"
#property strict

#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>

#define DASH_PREFIX   "FXBH_V5_"
#define EA_VERSION    "v5.00"
#define EA_NAME       "THEE ELITE SCALPER"

//--- State Machine
enum ENUM_ENGINE_STATE { STATE_SCANNING, STATE_ANALYZING, STATE_COOLDOWN };

//+------------------------------------------------------------------+
//| INPUT PARAMETERS                                                 |
//+------------------------------------------------------------------+
input group "=== CORE SETTINGS ==="
input ulong  InpMagicNumber      = 999555;      // Magic Number
input int    InpMaxDailyTrades   = 15;          // Max Daily Trades

input group "=== $5 MICRO ACCOUNT RISK ENGINE ==="
input double InpRiskPercent      = 1.5;         // Risk % Per Trade (1.0-2.5 recommended)
input double InpMaxDailyDrawPct  = 20.0;        // Max Daily Drawdown % (hard stop)
input double InpMinMarginLevel   = 200.0;       // Min Margin Level % before blocking trades
input int    InpMaxOpenTrades    = 1;           // Max concurrent trades (ALWAYS 1 for $5)

input group "=== ATR-BASED SL/TP (VOLATILITY ADAPTIVE) ==="
input int    InpATRPeriod        = 14;          // ATR Period
input double InpATRMultiplierSL  = 1.2;         // SL = ATR x Multiplier
input double InpATRMultiplierTP  = 2.0;         // TP = ATR x Multiplier (2:1 RR minimum)
input int    InpMinSLPoints      = 80;          // Minimum SL (safety floor, points)
input int    InpMaxSLPoints      = 500;         // Maximum SL (broker margin cap, points)

input group "=== SMART 5-MINUTE ANALYSIS ENGINE ==="
input int    InpAnalysisSeconds  = 300;         // Max Analysis Window (seconds) -> 5 mins
input int    InpMinAnalysisSecs  = 30;          // Min observation before firing (seconds)
input int    InpMinConfluence    = 4;           // Min confluence score to execute (4-6)

input group "=== SESSION & SPREAD FILTER ==="
input bool   InpUseLondonSession = true;        // Trade London Session (07:00-12:00 GMT)
input bool   InpUseNYSession     = true;        // Trade New York Session (13:00-18:00 GMT)
input bool   InpUseAsianSession  = false;       // Trade Asian Session (00:00-05:00 GMT)
input int    InpMaxSpreadPoints  = 30;          // Max Spread (points) — 30 = 3.0 pips XAU
input int    InpCooldownSeconds  = 45;          // Cooldown after trade close (seconds)

input group "=== 7-LAYER SIGNAL ENGINE ==="
input int    InpFastEMA          = 9;           // Fast EMA (momentum)
input int    InpSlowEMA          = 21;          // Slow EMA (structure)
input int    InpTrendEMA         = 50;          // Trend EMA (H1 bias filter)
input int    InpRSIPeriod        = 14;          // RSI Period
input int    InpRSIOverbought    = 68;          // RSI Overbought threshold
input int    InpRSIOversold      = 32;          // RSI Oversold threshold
input int    InpBBPeriod         = 20;          // Bollinger Bands Period
input double InpBBDeviation      = 2.0;         // BB Deviation
input int    InpStochKPeriod     = 5;           // Stochastic %K
input int    InpStochDPeriod     = 3;           // Stochastic %D
input int    InpStochSlowing     = 3;           // Stochastic Slowing
input int    InpStructureBars    = 8;           // Structure high/low breakout bars

input group "=== PROFIT MANAGEMENT ==="
input double InpTargetProfitUSD  = 0.80;        // Daily profit target (USD) to pause trading
input bool   InpUseBreakEven     = true;        // Move SL to break-even after 50% TP hit
input double InpBreakEvenTrigger = 0.50;        // Move BE when this fraction of TP is hit

input group "=== DASHBOARD ==="
input int    InpDashX            = 12;          // Dashboard X position
input int    InpDashY            = 12;          // Dashboard Y position

//+------------------------------------------------------------------+
//| COLOR PALETTE                                                    |
//+------------------------------------------------------------------+
const color C_BG         = C'5,7,12';
const color C_PANEL      = C'10,16,28';
const color C_HEADER     = C'12,28,60';
const color C_BORDER     = C'0,80,200';
const color C_BLUE       = C'0,140,255';
const color C_GREEN      = C'0,210,110';
const color C_RED        = C'230,45,65';
const color C_GOLD       = C'255,190,30';
const color C_PURPLE     = C'160,0,240';
const color C_WHITE      = C'230,238,255';
const color C_MUTED      = C'110,130,160';
const color C_CYAN       = C'0,200,200';
const color C_ORANGE     = C'255,140,0';

//+------------------------------------------------------------------+
//| GLOBAL OBJECTS & STATE                                           |
//+------------------------------------------------------------------+
CTrade        g_Trade;
CPositionInfo g_Pos;

int  g_FastEMAHandle    = INVALID_HANDLE;
int  g_SlowEMAHandle    = INVALID_HANDLE;
int  g_TrendEMAHandle   = INVALID_HANDLE;
int  g_RSIHandle        = INVALID_HANDLE;
int  g_BBHandle         = INVALID_HANDLE;
int  g_StochHandle      = INVALID_HANDLE;
int  g_ATRHandle        = INVALID_HANDLE;

ENUM_ENGINE_STATE g_State        = STATE_SCANNING;
datetime          g_StateTimer   = 0;
ENUM_ORDER_TYPE   g_PendingDir   = ORDER_TYPE_BUY;
int               g_AnalysisTicks= 0;
datetime          g_AnalysisStart= 0;
int               g_PendingScore = 0;

datetime g_SessionDay     = 0;
int      g_DailyTrades    = 0;
double   g_DailyProfit    = 0.0;
int      g_DailyWins      = 0;
int      g_DailyLosses    = 0;
double   g_DayStartBalance= 0.0;
bool     g_DailyTargetHit = false;
bool     g_DDStopActive   = false;

string g_StatusText   = "BOOTING";
color  g_StatusColor  = C_GOLD;
string g_Heartbeat    = "0 1 0 1";
int    g_LastSignalScore = 0;
string g_LastSignalDir   = "---";
string g_BlockReason     = "---";

//+------------------------------------------------------------------+
//| INIT                                                             |
//+------------------------------------------------------------------+
int OnInit()
{
   g_Trade.SetExpertMagicNumber(InpMagicNumber);
   g_Trade.SetDeviationInPoints(20);
   g_Trade.SetTypeFilling(ORDER_FILLING_IOC);

   g_FastEMAHandle  = iMA(_Symbol, _Period, InpFastEMA,   0, MODE_EMA, PRICE_CLOSE);
   g_SlowEMAHandle  = iMA(_Symbol, _Period, InpSlowEMA,   0, MODE_EMA, PRICE_CLOSE);
   g_TrendEMAHandle = iMA(_Symbol, _Period, InpTrendEMA,  0, MODE_EMA, PRICE_CLOSE);
   g_RSIHandle      = iRSI(_Symbol, _Period, InpRSIPeriod, PRICE_CLOSE);
   g_BBHandle       = iBands(_Symbol, _Period, InpBBPeriod, 0, InpBBDeviation, PRICE_CLOSE);
   g_StochHandle    = iStochastic(_Symbol, _Period, InpStochKPeriod, InpStochDPeriod, InpStochSlowing, MODE_SMA, STO_LOWHIGH);
   g_ATRHandle      = iATR(_Symbol, _Period, InpATRPeriod);

   if(g_FastEMAHandle  == INVALID_HANDLE || g_SlowEMAHandle == INVALID_HANDLE ||
      g_TrendEMAHandle == INVALID_HANDLE || g_RSIHandle     == INVALID_HANDLE ||
      g_BBHandle       == INVALID_HANDLE || g_StochHandle   == INVALID_HANDLE ||
      g_ATRHandle      == INVALID_HANDLE)
   {
      Alert("[EliteScalper v5] Indicator init failed. Check symbol/period.");
      return INIT_FAILED;
   }

   g_SessionDay      = GetMidnightTS(TimeCurrent());
   g_DayStartBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   SyncLedger();
   RenderDashboard();
   EventSetTimer(1);
   g_State = STATE_SCANNING;
   Print("[EliteScalper v5] Initialized. Risk: ", InpRiskPercent, "% | Min confluence: ", InpMinConfluence, "/7");
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
   EventKillTimer();
   PurgeDash();
   int handles[] = { g_FastEMAHandle, g_SlowEMAHandle, g_TrendEMAHandle,
                     g_RSIHandle, g_BBHandle, g_StochHandle, g_ATRHandle };
   for(int i = 0; i < 7; i++) if(handles[i] != INVALID_HANDLE) IndicatorRelease(handles[i]);
}

//+------------------------------------------------------------------+
//| TIMER — heartbeat + ledger sync                                  |
//+------------------------------------------------------------------+
void OnTimer()
{
   static uint pulse = 0; pulse++;
   string hb[4] = { "1 0 1 1  0 1 0 0", "0 1 0 0  1 0 1 1", "1 1 0 1  0 0 1 0", "0 0 1 0  1 1 0 1" };
   g_Heartbeat = hb[pulse % 4];
   SyncLedger();
   RefreshDash();
}

//+------------------------------------------------------------------+
//| MAIN TICK                                                        |
//+------------------------------------------------------------------+
void OnTick()
{
   // ── 1. Market tradeable? ──────────────────────────────────────────
   if(!IsMarketOpen())
   {
      g_StatusText = "MARKET CLOSED"; g_StatusColor = C_MUTED;
      g_BlockReason = "Market offline / weekend";
      return;
   }

   // ── 2. Manage open position (break-even) ─────────────────────────
   if(IsPositionOpen())
   {
      if(InpUseBreakEven) ManageBreakEven();
      g_StatusText = "TRADE RUNNING ► P&L: " + DoubleToString(FloatingPnL(), 2);
      g_StatusColor = (FloatingPnL() >= 0.0) ? C_GREEN : C_RED;
      return;
   }

   // ── 3. Daily drawdown hard stop ───────────────────────────────────
   double ddPct = DailyDrawdownPct();
   if(ddPct >= InpMaxDailyDrawPct)
   {
      g_DDStopActive = true;
      g_StatusText  = "DD STOP ACTIVE (" + DoubleToString(ddPct, 1) + "%)";
      g_StatusColor = C_RED;
      g_BlockReason = "Daily DD limit hit — restart tomorrow";
      return;
   }
   if(g_DDStopActive) { g_StatusText = "DD STOP ACTIVE"; g_StatusColor = C_RED; return; }

   // ── 4. Daily profit target ────────────────────────────────────────
   if(g_DailyProfit >= InpTargetProfitUSD)
   {
      g_DailyTargetHit = true;
      g_StatusText  = "DAILY TARGET HIT  ✓ $" + DoubleToString(g_DailyProfit, 2);
      g_StatusColor = C_GREEN;
      g_BlockReason = "Target reached — trading paused";
      return;
   }

   // ── 5. Allocation cap ────────────────────────────────────────────
   if(g_DailyTrades >= InpMaxDailyTrades)
   {
      g_StatusText  = "TRADE LIMIT REACHED";
      g_StatusColor = C_GOLD;
      g_BlockReason = IntegerToString(InpMaxDailyTrades) + " trades done today";
      return;
   }

   // ── 6. Margin level guard ─────────────────────────────────────────
   double marginLevel = AccountInfoDouble(ACCOUNT_MARGIN_LEVEL);
   if(marginLevel > 0.0 && marginLevel < InpMinMarginLevel)
   {
      g_StatusText  = "LOW MARGIN (" + DoubleToString(marginLevel, 0) + "%)";
      g_StatusColor = C_RED;
      g_BlockReason = "Margin < " + DoubleToString(InpMinMarginLevel, 0) + "%";
      return;
   }

   // ── 7. Cooldown ───────────────────────────────────────────────────
   if(g_State == STATE_COOLDOWN)
   {
      int left = (int)(g_StateTimer - TimeCurrent());
      if(left > 0)
      {
         g_StatusText  = "COOLDOWN (" + IntegerToString(left) + "s) — SCANNING";
         g_StatusColor = C_GOLD;
         return;
      }
      g_State = STATE_SCANNING;
   }

   // ── 8. Session filter ─────────────────────────────────────────────
   if(!IsSessionActive())
   {
      g_StatusText  = "OFF-SESSION — WAITING";
      g_StatusColor = C_MUTED;
      g_BlockReason = "Outside trading hours";
      return;
   }

   // ── 9. Spread check ───────────────────────────────────────────────
   int spread = (int)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   if(spread > InpMaxSpreadPoints)
   {
      g_StatusText  = "SPREAD ALERT (" + IntegerToString(spread) + "pts)";
      g_StatusColor = C_RED;
      g_BlockReason = "Spread too wide";
      return;
   }

   // ── 10. State machine ─────────────────────────────────────────────
   if(g_State == STATE_SCANNING)
   {
      RunConfluenceEngine();
   }
   else if(g_State == STATE_ANALYZING)
   {
      ProcessAnalysis();
   }
}

//+------------------------------------------------------------------+
//| 7-LAYER CONFLUENCE ENGINE — returns score 0-7 + direction        |
//+------------------------------------------------------------------+
int GetConfluenceScore(ENUM_ORDER_TYPE &dir)
{
   // --- Fetch indicator buffers ---
   double fast[2], slow[2], trend[2];
   double rsi[2], bbU[2], bbM[2], bbL[2];
   double stochK[2], stochD[2];
   double atr[1];

   if(CopyBuffer(g_FastEMAHandle,  0, 0, 2, fast)  <= 0) return 0;
   if(CopyBuffer(g_SlowEMAHandle,  0, 0, 2, slow)  <= 0) return 0;
   if(CopyBuffer(g_TrendEMAHandle, 0, 0, 2, trend) <= 0) return 0;
   if(CopyBuffer(g_RSIHandle,      0, 0, 2, rsi)   <= 0) return 0;
   if(CopyBuffer(g_BBHandle, 1,    0, 2, bbU)      <= 0) return 0;
   if(CopyBuffer(g_BBHandle, 0,    0, 2, bbM)      <= 0) return 0;
   if(CopyBuffer(g_BBHandle, 2,    0, 2, bbL)      <= 0) return 0;
   if(CopyBuffer(g_StochHandle, 0, 0, 2, stochK)   <= 0) return 0;
   if(CopyBuffer(g_StochHandle, 1, 0, 2, stochD)   <= 0) return 0;
   if(CopyBuffer(g_ATRHandle,   0, 0, 1, atr)      <= 0) return 0;

   double price   = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   int    hBar    = iHighest(_Symbol, _Period, MODE_HIGH, InpStructureBars, 1);
   int    lBar    = iLowest (_Symbol, _Period, MODE_LOW,  InpStructureBars, 1);
   double structH = iHigh(_Symbol, _Period, hBar);
   double structL = iLow (_Symbol, _Period, lBar);

   // ATR sanity — if market is dead flat, don't trade
   if(atr[0] < SymbolInfoDouble(_Symbol, SYMBOL_POINT) * 5) { dir = ORDER_TYPE_BUY; return 0; }

   int buyScore  = 0;
   int sellScore = 0;

   // Layer 1: Fast/Slow EMA crossover
   if(fast[0] > slow[0]) buyScore++;  else sellScore++;

   // Layer 2: Price vs Trend EMA (50)
   if(price > trend[0]) buyScore++; else sellScore++;

   // Layer 3: RSI momentum (not overbought for buy, not oversold for sell)
   if(rsi[0] > 50.0 && rsi[0] < InpRSIOverbought) buyScore++;
   if(rsi[0] < 50.0 && rsi[0] > InpRSIOversold)   sellScore++;

   // Layer 4: RSI direction (rising vs falling)
   if(rsi[0] > rsi[1]) buyScore++; else sellScore++;

   // Layer 5: Bollinger Band position
   if(price > bbM[0] && price < bbU[0]) buyScore++;
   if(price < bbM[0] && price > bbL[0]) sellScore++;

   // Layer 6: Stochastic — signal line cross + not extreme
   if(stochK[0] > stochD[0] && stochK[1] <= stochD[1] && stochK[0] < 80.0) buyScore++;
   if(stochK[0] < stochD[0] && stochK[1] >= stochD[1] && stochK[0] > 20.0) sellScore++;

   // Layer 7: Market structure breakout
   if(price > structH) buyScore++;
   if(price < structL) sellScore++;

   if(buyScore > sellScore) { dir = ORDER_TYPE_BUY;  return buyScore; }
   if(sellScore > buyScore) { dir = ORDER_TYPE_SELL; return sellScore; }

   dir = ORDER_TYPE_BUY;
   return 0;
}

//+------------------------------------------------------------------+
//| SCANNING STATE — check for signal, start analysis if found       |
//+------------------------------------------------------------------+
void RunConfluenceEngine()
{
   ENUM_ORDER_TYPE dir = ORDER_TYPE_BUY;
   int score = GetConfluenceScore(dir);

   g_LastSignalScore = score;
   g_LastSignalDir   = (dir == ORDER_TYPE_BUY) ? "BUY" : "SELL";

   if(score >= InpMinConfluence)
   {
      g_State          = STATE_ANALYZING;
      g_PendingDir     = dir;
      g_PendingScore   = score;
      g_AnalysisStart  = TimeCurrent();
      g_AnalysisTicks  = 0;
      g_StatusText     = "SIGNAL LOCKED | SCORE: " + IntegerToString(score) + "/7 | CONFIRMING...";
      g_StatusColor    = C_PURPLE;
      Print("[EliteScalper v5] Signal: ", EnumToString(dir), " Score: ", score, "/7. Confirming...");
   }
   else
   {
      g_StatusText  = "SCANNING... SCORE: " + IntegerToString(score) + "/7 (need " + IntegerToString(InpMinConfluence) + ")";
      g_StatusColor = C_BLUE;
      g_BlockReason = "Low confluence";
   }
}

//+------------------------------------------------------------------+
//| ANALYSIS STATE — confirm signal holds, then fire                 |
//+------------------------------------------------------------------+
void ProcessAnalysis()
{
   g_AnalysisTicks++;
   int elapsed = (int)(TimeCurrent() - g_AnalysisStart);

   g_StatusText  = "CONFIRMING " + g_LastSignalDir + " | " + IntegerToString(elapsed) + "s / " + IntegerToString(InpAnalysisSeconds) + "s max";
   g_StatusColor = C_PURPLE;

   // Timeout: reset if signal didn't confirm within window
   if(elapsed > InpAnalysisSeconds)
   {
      g_StatusText  = "TIMEOUT — RESCANNING";
      g_StatusColor = C_GOLD;
      g_State       = STATE_SCANNING;
      Print("[EliteScalper v5] Analysis timeout. Rescanning.");
      return;
   }

   // Re-check confluence — still valid?
   ENUM_ORDER_TYPE currentDir = ORDER_TYPE_BUY;
   int currentScore = GetConfluenceScore(currentDir);

   if(currentDir != g_PendingDir || currentScore < InpMinConfluence)
   {
      g_StatusText  = "SIGNAL INVALIDATED — RESCANNING";
      g_StatusColor = C_GOLD;
      g_State       = STATE_SCANNING;
      Print("[EliteScalper v5] Signal flip/decay detected during confirmation.");
      return;
   }

   // Update pending score with latest
   g_PendingScore = currentScore;

   // Minimum 30s observation, then fire as soon as score is confirmed
   if(elapsed >= InpMinAnalysisSecs && currentScore >= InpMinConfluence)
   {
      Print("[EliteScalper v5] Confirmed! Score: ", currentScore, "/7 after ", elapsed, "s. Firing.");
      ExecuteTrade(g_PendingDir, currentScore);
      g_State = STATE_SCANNING;
   }
}

//+------------------------------------------------------------------+
//| EXECUTE TRADE — ATR-based lot sizing + SL/TP                     |
//+------------------------------------------------------------------+
void ExecuteTrade(ENUM_ORDER_TYPE dir, int score)
{
   double atrBuf[1];
   if(CopyBuffer(g_ATRHandle, 0, 0, 1, atrBuf) <= 0) { Print("[v5] ATR read fail"); return; }
   double atr    = atrBuf[0];
   double point  = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   int    digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   double price  = (dir == ORDER_TYPE_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);

   // ATR-based SL (clamped to min/max)
   double rawSL    = atr * InpATRMultiplierSL;
   double slPoints = MathMax(InpMinSLPoints * point, MathMin(InpMaxSLPoints * point, rawSL));

   // TP at minimum 2:1 RR
   double tpPoints = slPoints * (InpATRMultiplierTP / InpATRMultiplierSL);

   // Risk-based lot sizing: risk% of balance / (slPoints / tickValue)
   double balance   = AccountInfoDouble(ACCOUNT_BALANCE);
   double riskAmt   = balance * (InpRiskPercent / 100.0);
   double tickVal   = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double tickSz    = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   double lotStep   = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   double minLot    = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxLot    = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);

   double lot = 0.01; // safe default
   if(tickVal > 0.0 && tickSz > 0.0 && slPoints > 0.0)
   {
      double slTicks = slPoints / tickSz;
      double rawLot  = riskAmt / (slTicks * tickVal);
      lot = MathFloor(rawLot / lotStep) * lotStep;
      lot = MathMax(minLot, MathMin(maxLot, lot));
   }

   double sl = NormalizeDouble((dir == ORDER_TYPE_BUY) ? price - slPoints : price + slPoints, digits);
   double tp = NormalizeDouble((dir == ORDER_TYPE_BUY) ? price + tpPoints : price - tpPoints, digits);

   // Margin check before sending
   double marginRequired = 0.0;
   ENUM_ORDER_TYPE checkType = (dir == ORDER_TYPE_BUY) ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
   if(OrderCalcMargin(checkType, _Symbol, lot, price, marginRequired))
   {
      double freeMargin = AccountInfoDouble(ACCOUNT_MARGIN_FREE);
      if(marginRequired > freeMargin * 0.8)
      {
         Print("[v5] Not enough free margin. Required: ", marginRequired, " Free: ", freeMargin);
         g_StatusText  = "MARGIN INSUFFICIENT";
         g_StatusColor = C_RED;
         return;
      }
   }

   bool ok = (dir == ORDER_TYPE_BUY)
             ? g_Trade.Buy (lot, _Symbol, price, sl, tp, "THEE v5 | Score:" + IntegerToString(score))
             : g_Trade.Sell(lot, _Symbol, price, sl, tp, "THEE v5 | Score:" + IntegerToString(score));

   if(ok)
   {
      g_DailyTrades++;
      g_StatusText  = "TRADE OPEN ► " + ((dir == ORDER_TYPE_BUY) ? "BUY" : "SELL") + " | Lot: " + DoubleToString(lot, 2);
      g_StatusColor = C_GREEN;
      Print("[v5 ENTRY] ", EnumToString(dir), " Lot:", lot, " SL:", slPoints/point, "pts TP:", tpPoints/point, "pts Score:", score);
   }
   else
   {
      Print("[v5 ENTRY FAIL] ", g_Trade.ResultRetcodeDescription());
      g_StatusText  = "ENTRY FAILED — " + g_Trade.ResultRetcodeDescription();
      g_StatusColor = C_RED;
   }
}

//+------------------------------------------------------------------+
//| BREAK-EVEN MANAGEMENT                                            |
//+------------------------------------------------------------------+
void ManageBreakEven()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(!g_Pos.SelectByIndex(i)) continue;
      if(g_Pos.Magic() != InpMagicNumber || g_Pos.Symbol() != _Symbol) continue;

      double openPrice = g_Pos.PriceOpen();
      double tp        = g_Pos.TakeProfit();
      double sl        = g_Pos.StopLoss();
      double curSL     = sl;
      int    digits    = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);

      if(tp == 0.0) continue;

      double tpDist = MathAbs(tp - openPrice);
      double beTriggerDist = tpDist * InpBreakEvenTrigger;

      if(g_Pos.PositionType() == POSITION_TYPE_BUY)
      {
         double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
         double newSL = NormalizeDouble(openPrice + SymbolInfoDouble(_Symbol, SYMBOL_POINT) * 5, digits);
         if(bid >= openPrice + beTriggerDist && curSL < openPrice)
         {
            g_Trade.PositionModify(g_Pos.Ticket(), newSL, tp);
            Print("[v5 BE] Buy BE set at ", newSL);
         }
      }
      else
      {
         double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
         double newSL = NormalizeDouble(openPrice - SymbolInfoDouble(_Symbol, SYMBOL_POINT) * 5, digits);
         if(ask <= openPrice - beTriggerDist && curSL > openPrice)
         {
            g_Trade.PositionModify(g_Pos.Ticket(), newSL, tp);
            Print("[v5 BE] Sell BE set at ", newSL);
         }
      }
   }
}

//+------------------------------------------------------------------+
//| HELPERS                                                          |
//+------------------------------------------------------------------+
bool IsPositionOpen()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
      if(g_Pos.SelectByIndex(i) && g_Pos.Magic() == InpMagicNumber && g_Pos.Symbol() == _Symbol) return true;
   return false;
}

double FloatingPnL()
{
   double t = 0.0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
      if(g_Pos.SelectByIndex(i) && g_Pos.Magic() == InpMagicNumber && g_Pos.Symbol() == _Symbol)
         t += g_Pos.Profit() + g_Pos.Swap() + g_Pos.Commission();
   return t;
}

bool IsMarketOpen()
{
   ENUM_SYMBOL_TRADE_MODE m = (ENUM_SYMBOL_TRADE_MODE)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_MODE);
   return (m == SYMBOL_TRADE_MODE_FULL || m == SYMBOL_TRADE_MODE_LONGONLY || m == SYMBOL_TRADE_MODE_SHORTONLY);
}

bool IsSessionActive()
{
   MqlDateTime dt; TimeToStruct(TimeCurrent(), dt);
   int h = dt.hour;
   if(InpUseLondonSession && h >= 7  && h < 12) return true;
   if(InpUseNYSession     && h >= 13 && h < 18) return true;
   if(InpUseAsianSession  && h >= 0  && h < 5)  return true;
   return false;
}

double DailyDrawdownPct()
{
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   if(g_DayStartBalance <= 0.0) return 0.0;
   double loss = g_DayStartBalance - balance;
   if(loss <= 0.0) return 0.0;
   return (loss / g_DayStartBalance) * 100.0;
}

datetime GetMidnightTS(datetime t)
{
   MqlDateTime d; TimeToStruct(t, d);
   return t - (datetime)(d.hour * 3600 + d.min * 60 + d.sec);
}

void SyncLedger()
{
   datetime now = TimeCurrent();
   datetime mid = GetMidnightTS(now);
   if(mid > g_SessionDay)
   {
      g_DayStartBalance = AccountInfoDouble(ACCOUNT_BALANCE);
      g_DailyTrades = 0; g_DailyProfit = 0.0; g_DailyWins = 0; g_DailyLosses = 0;
      g_DailyTargetHit = false; g_DDStopActive = false;
      g_SessionDay = mid;
   }
   g_DailyProfit = 0.0; g_DailyWins = 0; g_DailyLosses = 0;
   if(HistorySelect(g_SessionDay, now))
   {
      for(int i = 0; i < HistoryDealsTotal(); i++)
      {
         ulong t = HistoryDealGetTicket(i);
         if(t > 0 && HistoryDealGetInteger(t, DEAL_MAGIC) == InpMagicNumber &&
            HistoryDealGetString(t, DEAL_SYMBOL) == _Symbol &&
            HistoryDealGetInteger(t, DEAL_ENTRY) == DEAL_ENTRY_OUT)
         {
            double pnl = HistoryDealGetDouble(t, DEAL_PROFIT) + HistoryDealGetDouble(t, DEAL_COMMISSION) + HistoryDealGetDouble(t, DEAL_SWAP);
            g_DailyProfit += pnl;
            if(pnl >= 0.0) g_DailyWins++; else g_DailyLosses++;
         }
      }
   }
}

//+------------------------------------------------------------------+
//| DASHBOARD                                                        |
//+------------------------------------------------------------------+
void DC(string n, int x, int y, int w, int h, color bg, color br, int bw)
{
   string q = DASH_PREFIX + n;
   if(ObjectFind(0, q) >= 0) ObjectDelete(0, q);
   ObjectCreate(0, q, OBJ_RECTANGLE_LABEL, 0, 0, 0);
   ObjectSetInteger(0, q, OBJPROP_CORNER,     CORNER_LEFT_UPPER);
   ObjectSetInteger(0, q, OBJPROP_XDISTANCE,  x);
   ObjectSetInteger(0, q, OBJPROP_YDISTANCE,  y);
   ObjectSetInteger(0, q, OBJPROP_XSIZE,      w);
   ObjectSetInteger(0, q, OBJPROP_YSIZE,      h);
   ObjectSetInteger(0, q, OBJPROP_BGCOLOR,    bg);
   if(br != clrNONE) { ObjectSetInteger(0, q, OBJPROP_BORDER_TYPE, BORDER_FLAT); ObjectSetInteger(0, q, OBJPROP_COLOR, br); ObjectSetInteger(0, q, OBJPROP_WIDTH, bw); }
   else ObjectSetInteger(0, q, OBJPROP_BORDER_TYPE, BORDER_RAISED);
   ObjectSetInteger(0, q, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, q, OBJPROP_HIDDEN,     true);
   ObjectSetInteger(0, q, OBJPROP_ZORDER,     0);
}

void DT(string n, int x, int y, string txt, color clr, int fsz, string fnt)
{
   string q = DASH_PREFIX + n;
   if(ObjectFind(0, q) >= 0) ObjectDelete(0, q);
   ObjectCreate(0, q, OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, q, OBJPROP_CORNER,    CORNER_LEFT_UPPER);
   ObjectSetInteger(0, q, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, q, OBJPROP_YDISTANCE, y);
   ObjectSetString (0, q, OBJPROP_TEXT,      txt);
   ObjectSetInteger(0, q, OBJPROP_COLOR,     clr);
   ObjectSetInteger(0, q, OBJPROP_FONTSIZE,  fsz);
   ObjectSetString (0, q, OBJPROP_FONT,      fnt);
   ObjectSetInteger(0, q, OBJPROP_SELECTABLE,false);
   ObjectSetInteger(0, q, OBJPROP_HIDDEN,    true);
   ObjectSetInteger(0, q, OBJPROP_ZORDER,    1);
}

void DU(string n, string txt, color clr = clrNONE)
{
   string q = DASH_PREFIX + n;
   if(ObjectFind(0, q) >= 0)
   {
      ObjectSetString(0, q, OBJPROP_TEXT, txt);
      if(clr != clrNONE) ObjectSetInteger(0, q, OBJPROP_COLOR, clr);
   }
}

void PurgeDash() { ObjectsDeleteAll(0, DASH_PREFIX); ChartRedraw(0); }

void RenderDashboard()
{
   int aX = InpDashX, aY = InpDashY;
   int dW = 460, dH = 620;

   // Outer shell
   DC("Shell",  aX,    aY,    dW,    dH,    C_BG,     C_BORDER, 2);
   DC("Hdr",    aX+2,  aY+2,  dW-4,  90,    C_HEADER, C_BORDER, 1);

   DT("T1",     aX+14, aY+10, EA_NAME,                           C_WHITE,  17, "Algerian");
   DT("T2",     aX+14, aY+38, "XAUUSD MICRO ACCOUNT SCALPER  |  " + EA_VERSION, C_BLUE, 8, "Arial Black");
   DT("T3",     aX+14, aY+56, "7-Layer Confluence Engine  |  ATR Risk Engine  |  $5 Protection Suite", C_MUTED, 7, "Arial");
   DT("Sym",    aX+dW-115, aY+14, _Symbol, C_GOLD, 14, "Impact");
   DT("Tf",     aX+dW-115, aY+38, PeriodToString(), C_CYAN, 9, "Arial Bold");

   // Heartbeat bar
   DC("HBBg",   aX+2,  aY+94, dW-4, 26, C_PANEL, clrNONE, 0);
   DT("HBLbl",  aX+14, aY+101, "[ SUBSYSTEM MATRIX ]:", C_MUTED, 7, "Consolas");
   DT("HBVal",  aX+140,aY+101, "0 1 0 1",              C_BLUE, 8, "Consolas");

   // ── Panel 1: Account Overview ─────────────────────────────────────
   int p1Y = aY + 124;
   DC("P1",     aX+2,  p1Y,   dW-4,  152, C_PANEL, C_BORDER, 1);
   DT("P1H",    aX+14, p1Y+8, "LIVE ACCOUNT OVERVIEW", C_WHITE, 10, "Arial Black");

   DT("LBal",   aX+14, p1Y+34, "Balance:",          C_MUTED, 9, "Arial");
   DT("VBal",   aX+220,p1Y+34, "$0.00",              C_WHITE, 10, "Arial Bold");
   DT("LEq",    aX+14, p1Y+54, "Equity:",            C_MUTED, 9, "Arial");
   DT("VEq",    aX+220,p1Y+54, "$0.00",              C_WHITE, 10, "Arial Bold");
   DT("LMg",    aX+14, p1Y+74, "Margin Level:",      C_MUTED, 9, "Arial");
   DT("VMg",    aX+220,p1Y+74, "---",                C_GREEN, 10, "Arial Bold");
   DT("LDD",    aX+14, p1Y+94, "Daily Drawdown:",    C_MUTED, 9, "Arial");
   DT("VDD",    aX+220,p1Y+94, "0.0 %",              C_GREEN, 10, "Arial Bold");
   DT("LFP",    aX+14, p1Y+114,"Floating P&L:",      C_MUTED, 9, "Arial");
   DT("VFP",    aX+220,p1Y+114,"$0.00",              C_GREEN, 10, "Arial Bold");

   // ── Panel 2: Signal Engine ────────────────────────────────────────
   int p2Y = p1Y + 158;
   DC("P2",     aX+2,  p2Y,   dW-4,  175, C_PANEL, C_BORDER, 1);
   DT("P2H",    aX+14, p2Y+8, "7-LAYER CONFLUENCE ENGINE", C_WHITE, 10, "Arial Black");

   DT("LSc",    aX+14, p2Y+34, "Signal Score:",      C_MUTED, 9, "Arial");
   DT("VSc",    aX+220,p2Y+34, "0 / 7",              C_BLUE,  10, "Arial Bold");
   DT("LDir",   aX+14, p2Y+54, "Direction:",         C_MUTED, 9, "Arial");
   DT("VDir",   aX+220,p2Y+54, "---",                C_WHITE, 10, "Arial Bold");
   DT("LSt",    aX+14, p2Y+74, "Engine State:",      C_MUTED, 9, "Arial");
   DT("VSt",    aX+14, p2Y+90, "INITIALIZING",       C_BLUE,  9, "Arial Black");
   DT("LBk",    aX+14, p2Y+112,"Block Reason:",      C_MUTED, 8, "Arial");
   DT("VBk",    aX+14, p2Y+126,"---",                C_MUTED, 8, "Arial");
   DT("LAT",    aX+14, p2Y+148,"Analysis Time:",     C_MUTED, 8, "Arial");
   DT("VAT",    aX+220,p2Y+148,"-- / --",            C_WHITE, 8, "Arial Bold");

   // ── Panel 3: Trade Statistics ─────────────────────────────────────
   int p3Y = p2Y + 181;
   DC("P3",     aX+2,  p3Y,   dW-4,  145, C_PANEL, C_BORDER, 1);
   DT("P3H",    aX+14, p3Y+8, "SESSION EXECUTION LOG", C_WHITE, 10, "Arial Black");

   DT("LTr",    aX+14, p3Y+34, "Trades Today:",      C_MUTED, 9, "Arial");
   DT("VTr",    aX+220,p3Y+34, "0 / " + IntegerToString(InpMaxDailyTrades), C_WHITE, 9, "Arial Bold");
   DT("LDP",    aX+14, p3Y+54, "Daily P&L:",         C_MUTED, 9, "Arial");
   DT("VDP",    aX+220,p3Y+54, "$0.00",              C_GREEN, 9, "Arial Bold");
   DT("LWR",    aX+14, p3Y+74, "Win Rate:",          C_MUTED, 9, "Arial");
   DT("VWR",    aX+220,p3Y+74, "0.0 %",             C_WHITE, 9, "Arial Bold");
   DT("LTg",    aX+14, p3Y+94, "Daily Target:",      C_MUTED, 9, "Arial");
   DT("VTg",    aX+220,p3Y+94, "$" + DoubleToString(InpTargetProfitUSD,2), C_CYAN, 9, "Arial Bold");
   DT("LDDpct", aX+14, p3Y+114,"DD Limit:",          C_MUTED, 9, "Arial");
   DT("VDDpct", aX+220,p3Y+114,DoubleToString(InpMaxDailyDrawPct,0) + "% / Margin Floor: " + DoubleToString(InpMinMarginLevel,0) + "%", C_MUTED, 8, "Arial");

   // Footer
   int fY = aY + dH - 32;
   DC("Ft",     aX+2,  fY,    dW-4,  28, C_PANEL, clrNONE, 0);
   DT("F1",     aX+14, fY+10, "Risk Engine: ATR x " + DoubleToString(InpATRMultiplierSL,1) + " SL | " + DoubleToString(InpRiskPercent,1) + "% Balance Risk", C_MUTED, 7, "Arial");
   DT("F2",     aX+dW-90, fY+10, "FXBOTHUB.COM", C_MUTED, 7, "Arial Black");

   ChartRedraw(0);
}

string PeriodToString()
{
   switch(_Period)
   {
      case PERIOD_M1:  return "M1";
      case PERIOD_M5:  return "M5";
      case PERIOD_M15: return "M15";
      case PERIOD_M30: return "M30";
      case PERIOD_H1:  return "H1";
      case PERIOD_H4:  return "H4";
      default: return "?";
   }
}

void RefreshDash()
{
   // Heartbeat
   DU("HBVal", g_Heartbeat, C_BLUE);

   // Account
   double bal = AccountInfoDouble(ACCOUNT_BALANCE);
   double eq  = AccountInfoDouble(ACCOUNT_EQUITY);
   double ml  = AccountInfoDouble(ACCOUNT_MARGIN_LEVEL);
   double dd  = DailyDrawdownPct();
   double fpl = FloatingPnL();

   DU("VBal", "$" + DoubleToString(bal, 2));
   DU("VEq",  "$" + DoubleToString(eq,  2));
   DU("VMg",  (ml > 0.0 ? DoubleToString(ml, 0) + "%" : "N/A"), (ml > 300.0 ? C_GREEN : (ml > InpMinMarginLevel ? C_GOLD : C_RED)));
   DU("VDD",  DoubleToString(dd, 1) + "% (max " + DoubleToString(InpMaxDailyDrawPct,0) + "%)", (dd < InpMaxDailyDrawPct * 0.5 ? C_GREEN : (dd < InpMaxDailyDrawPct * 0.8 ? C_GOLD : C_RED)));
   DU("VFP",  (fpl >= 0.0 ? "+$" : "-$") + DoubleToString(MathAbs(fpl), 2), (fpl >= 0.0 ? C_GREEN : C_RED));

   // Signal engine
   DU("VSc",  IntegerToString(g_LastSignalScore) + " / 7  (need " + IntegerToString(InpMinConfluence) + ")", (g_LastSignalScore >= InpMinConfluence ? C_GREEN : C_BLUE));
   DU("VDir", g_LastSignalDir, (g_LastSignalDir == "BUY" ? C_GREEN : (g_LastSignalDir == "SELL" ? C_RED : C_MUTED)));
   DU("VSt",  g_StatusText,   g_StatusColor);
   DU("VBk",  g_BlockReason,  C_MUTED);

   // Analysis timer
   if(g_State == STATE_ANALYZING)
   {
      int elapsed = (int)(TimeCurrent() - g_AnalysisStart);
      DU("VAT", IntegerToString(elapsed) + "s / " + IntegerToString(InpAnalysisSeconds) + "s max", C_PURPLE);
   }
   else
      DU("VAT", g_State == STATE_SCANNING ? "-- / --" : "waiting", C_MUTED);

   // Trade stats
   DU("VTr", IntegerToString(g_DailyTrades) + " / " + IntegerToString(InpMaxDailyTrades));
   double dp = g_DailyProfit;
   DU("VDP", (dp >= 0.0 ? "+$" : "-$") + DoubleToString(MathAbs(dp), 2), (dp >= 0.0 ? C_GREEN : C_RED));
   int tot = g_DailyWins + g_DailyLosses;
   double wr = (tot > 0) ? ((double)g_DailyWins / tot) * 100.0 : 0.0;
   DU("VWR", DoubleToString(wr, 1) + "%  (" + IntegerToString(g_DailyWins) + "W / " + IntegerToString(g_DailyLosses) + "L)",
      (wr >= 55.0 ? C_GREEN : (wr >= 40.0 ? C_GOLD : C_RED)));
   DU("VTg", (g_DailyTargetHit ? "HIT ✓ " : "") + "$" + DoubleToString(InpTargetProfitUSD,2), (g_DailyTargetHit ? C_GREEN : C_CYAN));

   ChartRedraw(0);
}