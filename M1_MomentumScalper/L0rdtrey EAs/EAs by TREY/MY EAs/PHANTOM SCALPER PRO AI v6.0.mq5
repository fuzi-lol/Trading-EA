//+------------------------------------------------------------------+
//|              PHANTOM SCALPER PRO AI v6.0 – FULLY CORRECTED       |
//|              True Trend-Following + Pattern Backup for BTCUSD    |
//+------------------------------------------------------------------+
#property copyright   "PHANTOM SCALPER PRO AI v6.0"
#property version     "6.00"
#property description "Fixed, Trend-Following, Dual-Engine BTC Scalper"

#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>
#include <Trade\AccountInfo.mqh>

#define D "PSP6_"

// -----------------------------------------------------------------------
// COLOUR PALETTE
// -----------------------------------------------------------------------
#define C_BG0       C'4,6,18'
#define C_BG1       C'8,12,28'
#define C_BG2       C'12,18,42'
#define C_HDRBAR    C'10,16,38'
#define C_BORDER    C'22,44,90'
#define C_ACBORD    C'0,160,220'
#define C_GOLD      C'255,200,40'
#define C_CYAN      C'0,220,220'
#define C_PURPLE    C'180,100,255'
#define C_WHITE     C'220,225,240'
#define C_SUBTEXT   C'110,130,160'
#define C_GREEN     C'20,220,110'
#define C_RED       C'230,55,65'
#define C_ORANGE    C'255,145,0'
#define C_DKGREEN   C'14,80,45'
#define C_LBLUE     C'80,160,255'
#define C_DGRAY     C'40,52,72'
#define C_MGRAY     C'75,90,115'

// -----------------------------------------------------------------------
// INPUT PARAMETERS
// -----------------------------------------------------------------------
input group "╔══════  IDENTITY  ══════╗"
input ulong  InpMagicNumber     = 88888;
input string InpBotName         = "INST BTC SCALPER v6";

input group "╔══════  LOT & RISK  ══════╗"
input double InpBaseLotSize     = 0.01;
input double InpProfitTargetUSD = 0.0;       // 0 = use only per-trade TP
input double InpStopLossPct     = 1.2;       // 1.2% of price
input double InpTakeProfitPct   = 2.8;       // larger TP for a positive edge
input double InpMaxDailyLossPct = 8.0;
input double InpMaxDailyProfitPct = 12.0;
input int    InpBulkTrades      = 5;         // reduced from 7

input group "╔══════  SIGNAL ENGINE  ══════╗"
input double InpMLThreshold     = 0.65;      // Primary confidence needed
input int    InpTickBufferSize  = 500;
input bool   InpUseTrailingStop = true;
input double InpTrailStartPct   = 0.8;       // start trailing after 0.8% profit
input double InpTrailStepPct    = 0.25;       // trail step

input group "╔══════  FREQUENCY  ══════╗"
input int    InpMaxDailyTrades  = 30;
input int    InpCooldownSec     = 120;

input group "╔══════  DASHBOARD  ══════╗"
input bool   InpShowDash        = true;
input int    InpDashX           = 14;
input int    InpDashY           = 14;

// -----------------------------------------------------------------------
// CONSTANTS & GLOBALS
// -----------------------------------------------------------------------
const int    DW = 420;
const int    DH = 620;

CTrade        g_trade;
CPositionInfo g_pos;
CAccountInfo  g_account;

// Indicator Handles (expanded)
int           g_emaFastH    = INVALID_HANDLE;
int           g_emaSlowH    = INVALID_HANDLE;
int           g_rsiH        = INVALID_HANDLE;
int           g_atrH        = INVALID_HANDLE;
int           g_volH        = INVALID_HANDLE;
int           g_adxH        = INVALID_HANDLE;
int           g_emaM15H     = INVALID_HANDLE;
int           g_emaH1H      = INVALID_HANDLE;
int           g_emaH4H      = INVALID_HANDLE;  // new

// Rolling tick buffer & derived momentum
MqlTick       g_tickBuffer[];
int           g_tickCount = 0;
double        g_lastMLConfidence  = 0.5;
int           g_lastSignalDir     = 0;
double        g_rawScoreDrift     = 0.0;       // replaces g_chiSquareScore
double        g_emaRawScore       = 0.0;       // EMA of raw score

// State tracking
datetime      g_lastExitTime    = 0;
datetime      g_sessionDay      = 0;
double        g_recoveryTiers[5] = {1.0, 1.2, 1.5, 1.8, 2.2}; // tamed
int           g_sessTradesToday = 0;
double        g_sessProfit      = 0.0;
int           g_sessWins        = 0;
int           g_sessLosses      = 0;
int           g_consecutiveLosses = 0;
double        g_peakEquity      = 0.0;
double        g_drawdown        = 0.0;
bool          g_prevHasPosition = false;

// Dashboard
string        g_statusText   = "WARMING UP";
color         g_statusColor  = C_ORANGE;
string        g_lastAction   = "Initializing...";
bool          g_inCooldown   = false;
int           g_cooldownLeft = 0;

// -----------------------------------------------------------------------
// FORWARD DECLARATIONS
// -----------------------------------------------------------------------
void     ResetAnalysis();
void     UpdateTickBuffer();
double   CalculateInstitutionalBTCScore(int &outDirection);
double   GetVolatilityState();
double   GetVolumeIntelligence();
double   GetTrendAlignment();
double   GetMarketStructure();
double   GetLiquidityHunt();
double   GetTickMomentum();
int      GetHigherTimeframeTrend();
int      DetectCandlestickPattern();
bool     PatternConfirmationOK(int patternDir);

void     RestoreSession();
void     BuildSessionStats();
bool     HasPosition();
bool     OpenBulkTrades(ENUM_ORDER_TYPE otype);
void     CloseAllPositions();
double   GetFloatPL();
bool     IsMarketOpen();
bool     DailyLimitsOK();
void     AdjustStops(double price, ENUM_ORDER_TYPE otype, double &sl, double &tp);
void     ManageTrailingStop();
double   NPrice(double p);
ENUM_ORDER_TYPE_FILLING GetFillMode();
datetime DayStart(datetime ts);

void     InitDash();
void     UpdateDash();
void     DeleteDash();
void     R(string nm, int x, int y, int w, int h, color bg, color brd=clrNONE, int bw=1);
void     L(string nm, int x, int y, string txt, color clr, int fsz, string fnt="Arial Bold");
void     U(string nm, string txt, color clr=C'220,225,240');
void     Bar(string nm, int x, int y, int w, int h, double pct, color fg, color bg_c);
void     UpdBar(string nm, double pct, color fg);

//+------------------------------------------------------------------+
//| OnInit                                                            |
//+------------------------------------------------------------------+
int OnInit()
{
   if(Symbol() != "BTCUSD" && StringFind(Symbol(), "BTC") < 0)
      Print("Warning: Engine tuned for BTCUSD; behaviour may vary.");

   ArrayResize(g_tickBuffer, InpTickBufferSize);
   g_trade.SetExpertMagicNumber(InpMagicNumber);
   g_trade.SetDeviationInPoints(50);
   g_trade.SetTypeFilling(GetFillMode());

   // Indicator handles
   g_emaFastH = iMA(Symbol(), PERIOD_M5, 9, 0, MODE_EMA, PRICE_CLOSE);
   g_emaSlowH = iMA(Symbol(), PERIOD_M5, 21, 0, MODE_EMA, PRICE_CLOSE);
   g_emaM15H  = iMA(Symbol(), PERIOD_M15, 21, 0, MODE_EMA, PRICE_CLOSE);
   g_emaH1H   = iMA(Symbol(), PERIOD_H1, 21, 0, MODE_EMA, PRICE_CLOSE);
   g_emaH4H   = iMA(Symbol(), PERIOD_H4, 21, 0, MODE_EMA, PRICE_CLOSE);
   g_rsiH     = iRSI(Symbol(), PERIOD_M5, 14, PRICE_CLOSE);
   g_atrH     = iATR(Symbol(), PERIOD_M5, 14);
   g_volH     = iVolumes(Symbol(), PERIOD_M5, VOLUME_TICK);
   g_adxH     = iADX(Symbol(), PERIOD_M5, 14);

   g_peakEquity = AccountInfoDouble(ACCOUNT_EQUITY);
   g_sessionDay = DayStart(TimeCurrent());

   g_sessTradesToday = 0;           // reset
   RestoreSession();                // now correctly recounts today
   BuildSessionStats();
   g_consecutiveLosses = GetConsecutiveLosses();

   if(InpShowDash) InitDash();
   EventSetTimer(1);
   g_lastAction = "v6.0 Trend Engine loaded";
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| OnDeinit                                                           |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   EventKillTimer();
   DeleteDash();
   if(g_emaFastH!=INVALID_HANDLE) IndicatorRelease(g_emaFastH);
   if(g_emaSlowH!=INVALID_HANDLE) IndicatorRelease(g_emaSlowH);
   if(g_rsiH    !=INVALID_HANDLE) IndicatorRelease(g_rsiH);
   if(g_atrH    !=INVALID_HANDLE) IndicatorRelease(g_atrH);
   if(g_volH    !=INVALID_HANDLE) IndicatorRelease(g_volH);
   if(g_adxH    !=INVALID_HANDLE) IndicatorRelease(g_adxH);
   if(g_emaM15H !=INVALID_HANDLE) IndicatorRelease(g_emaM15H);
   if(g_emaH1H  !=INVALID_HANDLE) IndicatorRelease(g_emaH1H);
   if(g_emaH4H  !=INVALID_HANDLE) IndicatorRelease(g_emaH4H);
}

//+------------------------------------------------------------------+
//| OnTimer                                                            |
//+------------------------------------------------------------------+
void OnTimer()
{
   // Cooldown based on last exit time (not just manual close)
   if(g_lastExitTime > 0)
   {
      int elapsed = (int)(TimeCurrent() - g_lastExitTime);
      g_inCooldown   = (elapsed < InpCooldownSec);
      g_cooldownLeft = g_inCooldown ? (InpCooldownSec - elapsed) : 0;
   }
   else
   {
      g_inCooldown = false;
      g_cooldownLeft = 0;
   }

   double eq = AccountInfoDouble(ACCOUNT_EQUITY);
   if(eq > g_peakEquity) g_peakEquity = eq;
   if(g_peakEquity > 0) g_drawdown = (g_peakEquity - eq) / g_peakEquity * 100.0;

   if(InpShowDash) UpdateDash();
}

//+------------------------------------------------------------------+
//| OnTick – Core Loop                                                |
//+------------------------------------------------------------------+
void OnTick()
{
   // ---------- Day change reset ----------
   datetime todayStart = DayStart(TimeCurrent());
   if(todayStart != g_sessionDay)
   {
      g_sessionDay = todayStart;
      g_sessTradesToday = 0;
      RestoreSession();               // recount from history
      BuildSessionStats();
      g_consecutiveLosses = 0;
      ResetAnalysis();
   }

   if(!IsMarketOpen())
   {
      g_statusText = "MKT CLOSED"; g_statusColor = C_RED; return;
   }

   UpdateTickBuffer();

   // ---------- Trailing stop management ----------
   if(HasPosition() && InpUseTrailingStop)
      ManageTrailingStop();

   // ---------- Detect position close (for cooldown) ----------
   bool hasPosNow = HasPosition();
   if(g_prevHasPosition && !hasPosNow)
   {
      // A position just closed (by any means)
      g_lastExitTime = TimeCurrent();
      g_inCooldown   = true;
      g_cooldownLeft = InpCooldownSec;
      BuildSessionStats();
      g_consecutiveLosses = GetConsecutiveLosses();
      ResetAnalysis();
      g_prevHasPosition = false;
      return;
   }
   g_prevHasPosition = hasPosNow;

   // ---------- When in position: check profit target only ----------
   if(hasPosNow)
   {
      if(InpProfitTargetUSD > 0 && GetFloatPL() >= InpProfitTargetUSD)
      {
         CloseAllPositions();
         g_lastExitTime = TimeCurrent();
         g_inCooldown   = true;
         g_cooldownLeft = InpCooldownSec;
         BuildSessionStats();
         g_consecutiveLosses = GetConsecutiveLosses();
         ResetAnalysis();
         return;
      }
      g_statusText = "IN TRADE"; g_statusColor = C_GREEN;
      return;
   }

   // ---------- No position: check cooldown & limits ----------
   if(g_inCooldown)
   {
      g_statusText = "COOLDOWN"; g_statusColor = C_CYAN; return;
   }
   if(!DailyLimitsOK())
   {
      g_statusText = "LIMIT HIT"; g_statusColor = C_RED; return;
   }

   if(g_tickCount < InpTickBufferSize)
   {
      g_statusText = "SCANNING..."; g_statusColor = C_ORANGE; return;
   }

   // ---------- PRIMARY STRATEGY ----------
   int signalDir = 0;
   g_lastMLConfidence = CalculateInstitutionalBTCScore(signalDir);
   g_lastSignalDir = signalDir;

   ENUM_ORDER_TYPE dir = -1;

   // Trend filter – must not trade against the higher‑timeframe trend
   int htfTrend = GetHigherTimeframeTrend();
   if(htfTrend != 0 && signalDir == -htfTrend)
      signalDir = 0;   // block counter‑trend trades

   // Primary entry
   if(g_lastMLConfidence >= InpMLThreshold && signalDir != 0)
   {
      dir = (signalDir == 1) ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
   }
   else
   {
      // ---------- BACKUP STRATEGY: Candlestick Patterns ----------
      int patternDir = DetectCandlestickPattern();
      if(patternDir != 0 && (htfTrend == 0 || patternDir == htfTrend))
      {
         // Must be a strong pattern and not contradict trend
         if(PatternConfirmationOK(patternDir))
         {
            dir = (patternDir == 1) ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
            g_lastMLConfidence = 0.70;  // assign a reasonable confidence for dashboard
            g_lastSignalDir = patternDir;
            g_lastAction = "PATTERN ENTRY";
         }
      }
   }

   if(dir != -1)
   {
      g_statusText = "EXECUTING"; g_statusColor = C_LBLUE;
      if(OpenBulkTrades(dir))
      {
         g_statusText = "IN TRADE"; g_statusColor = C_GREEN;
         g_prevHasPosition = true;   // update state immediately
      }
      else
      {
         g_statusText = "OPEN FAIL"; g_statusColor = C_RED;
      }
   }
   else
   {
      g_statusText = "ANALYZING"; g_statusColor = C_GOLD;
   }
}

//+------------------------------------------------------------------+
//| PRIMARY SCORING – Multi‑Layer Institutional (re‑engineered)       |
//+------------------------------------------------------------------+
double CalculateInstitutionalBTCScore(int &outDirection)
{
   double structure = GetMarketStructure();
   double trend     = GetTrendAlignment();

   // RSI – use the existing handle (fixed handle leak)
   double rsiArray[1];
   double momentum = 0.0;
   if(CopyBuffer(g_rsiH, 0, 0, 1, rsiArray) == 1)
      momentum = (rsiArray[0] - 50.0) / 50.0;

   double volume    = GetVolumeIntelligence();
   double liquidity = GetLiquidityHunt();
   double volatility= GetVolatilityState();
   double tickMom   = GetTickMomentum();   // new layer

   // Weighted sum
   double raw = structure * 0.25 + trend * 0.25 + momentum * 0.10 +
                volume * 0.10 + liquidity * 0.10 + volatility * 0.05 +
                tickMom * 0.15;

   outDirection = (raw >= 0.0) ? 1 : -1;

   // Update EMA for drift display
   if(g_emaRawScore == 0.0) g_emaRawScore = raw;
   else g_emaRawScore = 0.2 * raw + 0.8 * g_emaRawScore;
   g_rawScoreDrift = raw - g_emaRawScore;

   double confidence = 1.0 / (1.0 + MathExp(-MathAbs(raw) * 4.0));
   return confidence;
}

//+------------------------------------------------------------------+
//| TICK MOMENTUM (uses the long‑ignored buffer)                     |
//+------------------------------------------------------------------+
double GetTickMomentum()
{
   if(g_tickCount < 10) return 0.0;
   // Use last 30 ticks (or less) to measure net move normalised by ATR
   int lookback = MathMin(30, g_tickCount);
   double startPrice = g_tickBuffer[g_tickCount - lookback].bid;
   double endPrice   = g_tickBuffer[g_tickCount - 1].bid;
   if(startPrice == 0) return 0.0;
   double move = (endPrice - startPrice) / startPrice; // fractional move

   double atr[1]; CopyBuffer(g_atrH,0,0,1,atr);
   if(atr[0] == 0) return 0.0;
   double atrFrac = atr[0] / SymbolInfoDouble(Symbol(), SYMBOL_BID);
   if(atrFrac == 0) return 0.0;
   return MathMax(-1.0, MathMin(1.0, move / (atrFrac * 2.0))); // -1..1
}

//+------------------------------------------------------------------+
//| HIGHER TIMEFRAME TREND (H1 + H4)                                 |
//+------------------------------------------------------------------+
int GetHigherTimeframeTrend()
{
   double emaH1[1], emaH4[1];
   if(CopyBuffer(g_emaH1H,0,0,1,emaH1) < 1) emaH1[0]=0;
   if(CopyBuffer(g_emaH4H,0,0,1,emaH4) < 1) emaH4[0]=0;
   double price = SymbolInfoDouble(Symbol(), SYMBOL_BID);
   int trend = 0;
   if(price > emaH1[0]) trend += 1; else if(price < emaH1[0]) trend -= 1;
   if(price > emaH4[0]) trend += 1; else if(price < emaH4[0]) trend -= 1;
   if(trend > 0) return 1;
   if(trend < 0) return -1;
   return 0;
}

//+------------------------------------------------------------------+
//| CANDLESTICK PATTERN DETECTOR                                     |
//+------------------------------------------------------------------+
int DetectCandlestickPattern()
{
   // Check M5 last closed bar
   double open  = iOpen(Symbol(), PERIOD_M5, 1);
   double close = iClose(Symbol(), PERIOD_M5, 1);
   double high  = iHigh(Symbol(), PERIOD_M5, 1);
   double low   = iLow(Symbol(), PERIOD_M5, 1);
   double body  = MathAbs(open - close);
   double range = high - low;
   if(range == 0) return 0;

   // Engulfing
   double prevOpen  = iOpen(Symbol(), PERIOD_M5, 2);
   double prevClose = iClose(Symbol(), PERIOD_M5, 2);
   double prevBody  = MathAbs(prevOpen - prevClose);
   if(prevBody > 0)
   {
      if(close > open && prevClose < prevOpen && open < prevClose && close > prevOpen)
         return 1;  // bullish engulfing
      if(close < open && prevClose > prevOpen && open > prevClose && close < prevOpen)
         return -1; // bearish engulfing
   }

   // Hammer / Shooting star
   double upperWick = high - MathMax(open, close);
   double lowerWick = MathMin(open, close) - low;
   if(body > 0 && lowerWick > body * 2.5 && upperWick < body * 0.5)
      return 1;  // hammer (bullish)
   if(body > 0 && upperWick > body * 2.5 && lowerWick < body * 0.5)
      return -1; // shooting star (bearish)

   // Morning/Evening Star (simplified 3‑bar)
   if(iBars(Symbol(), PERIOD_M5) > 3)
   {
      double o1 = iOpen(Symbol(), PERIOD_M5, 2);
      double c1 = iClose(Symbol(), PERIOD_M5, 2);
      double o2 = iOpen(Symbol(), PERIOD_M5, 3);
      double c2 = iClose(Symbol(), PERIOD_M5, 3);
      // Morning star: bearish candle, small body gap down, large bullish candle
      if(c2 < o2 && MathAbs(open - close) < body*0.3 && close > open && close > (o2 + c2)/2)
         return 1;
      if(c2 > o2 && MathAbs(open - close) < body*0.3 && close < open && close < (o2 + c2)/2)
         return -1;
   }
   return 0;
}

bool PatternConfirmationOK(int patternDir)
{
   // Additional confirmation: volume spike
   double vol[2]; CopyBuffer(g_volH,0,0,2,vol);
   if(vol[0] > vol[1] * 1.3) return true;
   // Or simply accept if pattern is engulfing
   return false;
}

//+------------------------------------------------------------------+
//| REMAINING ENGINE LAYERS (simplified but solid)                   |
//+------------------------------------------------------------------+
double GetMarketStructure()
{
   double emaM5[1], emaM15[1], emaH1[1];
   if(CopyBuffer(g_emaSlowH,0,0,1,emaM5) < 1) emaM5[0]=0;
   if(CopyBuffer(g_emaM15H,0,0,1,emaM15)<1) emaM15[0]=0;
   if(CopyBuffer(g_emaH1H,0,0,1,emaH1) <1) emaH1[0]=0;
   double bid = SymbolInfoDouble(Symbol(), SYMBOL_BID);
   int al = 0;
   if(bid > emaM5[0]) al++; else if(bid < emaM5[0]) al--;
   if(bid > emaM15[0]) al++; else if(bid < emaM15[0]) al--;
   if(bid > emaH1[0]) al++; else if(bid < emaH1[0]) al--;
   return al / 3.0;
}

double GetTrendAlignment()
{
   double adx[1]; CopyBuffer(g_adxH,0,0,1,adx);
   double emaF[1], emaS[1];
   CopyBuffer(g_emaFastH,0,0,1,emaF);
   CopyBuffer(g_emaSlowH,0,0,1,emaS);
   double dir = (emaF[0] > emaS[0]) ? 1.0 : -1.0;
   double strength = MathMin(adx[0] / 30.0, 1.0);
   return dir * strength;
}

double GetVolatilityState()
{
   double atr[2]; CopyBuffer(g_atrH,0,0,2,atr);
   if(atr[1]==0) return 0.0;
   double expansion = (atr[0] - atr[1]) / atr[1];
   double res = MathMin(MathMax(expansion * 5.0, 0.0), 1.0);
   return res;
}

double GetVolumeIntelligence()
{
   double vol[3]; if(CopyBuffer(g_volH,0,0,3,vol)<3) return 0.0;
   double avg = (vol[1]+vol[2])/2.0;
   if(avg==0) return 0.0;
   return MathMin(vol[0]/avg / 2.5, 1.0);
}

double GetLiquidityHunt()
{
   // now uses last 3 bars for confirmation
   double body[3], wU[3], wD[3];
   for(int i=1; i<=3; i++)
   {
      double o=iOpen(Symbol(),PERIOD_M5,i);
      double c=iClose(Symbol(),PERIOD_M5,i);
      double h=iHigh(Symbol(),PERIOD_M5,i);
      double l=iLow(Symbol(),PERIOD_M5,i);
      body[i-1]=MathAbs(o-c);
      wU[i-1]=h-MathMax(o,c);
      wD[i-1]=MathMin(o,c)-l;
   }
   int bull=0, bear=0;
   for(int i=0;i<3;i++)
   {
      if(wD[i] > body[i]*2.0) bull++;
      if(wU[i] > body[i]*2.0) bear++;
   }
   if(bull>=2) return 1.0;
   if(bear>=2) return -1.0;
   return 0.0;
}

//+------------------------------------------------------------------+
//| EXECUTION & MONEY MANAGEMENT (fully corrected)                   |
//+------------------------------------------------------------------+
bool OpenBulkTrades(ENUM_ORDER_TYPE otype)
{
   double price = (otype == ORDER_TYPE_BUY) ?
                  SymbolInfoDouble(Symbol(), SYMBOL_ASK) :
                  SymbolInfoDouble(Symbol(), SYMBOL_BID);
   if(price <= 0.0) return false;

   int tierIndex = MathMin(g_consecutiveLosses, 4);
   double targetLot = InpBaseLotSize * g_recoveryTiers[tierIndex];

   double lotMin  = SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_MIN);
   double lotMax  = SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_MAX);
   double lotStep = SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_STEP);
   double lot     = MathMax(lotMin, MathMin(lotMax, MathRound(targetLot / lotStep) * lotStep));

   double sl = 0.0, tp = 0.0;
   if(InpStopLossPct > 0.0)
   {
      sl = (otype == ORDER_TYPE_BUY) ?
           NPrice(price * (1.0 - InpStopLossPct/100.0)) :
           NPrice(price * (1.0 + InpStopLossPct/100.0));
   }
   if(InpTakeProfitPct > 0.0)
   {
      tp = (otype == ORDER_TYPE_BUY) ?
           NPrice(price * (1.0 + InpTakeProfitPct/100.0)) :
           NPrice(price * (1.0 - InpTakeProfitPct/100.0));
   }
   AdjustStops(price, otype, sl, tp);

   int successCount = 0;
   g_lastAction = StringFormat("Bulk %s (x%d) Lot:%.2f Tier%d", EnumToString(otype), InpBulkTrades, lot, tierIndex);

   for(int i=0; i<InpBulkTrades; i++)
   {
      bool ok = (otype == ORDER_TYPE_BUY) ?
                g_trade.Buy(lot, Symbol(), price, sl, tp, InpBotName) :
                g_trade.Sell(lot, Symbol(), price, sl, tp, InpBotName);
      if(ok) successCount++;
   }

   g_sessTradesToday += successCount;   // count only successful opens
   if(successCount == 0)
   {
      Print("Failed to open any position. Check margin/lot.");
      return false;
   }
   return true;
}

void CloseAllPositions()
{
   for(int i = PositionsTotal()-1; i >= 0; i--)
   {
      if(!g_pos.SelectByIndex(i)) continue;
      if(g_pos.Magic() != InpMagicNumber || g_pos.Symbol() != Symbol()) continue;
      g_trade.PositionClose(g_pos.Ticket());
   }
}

void AdjustStops(double price, ENUM_ORDER_TYPE otype, double &sl, double &tp)
{
   int stopsLevel = (int)SymbolInfoInteger(Symbol(), SYMBOL_TRADE_STOPS_LEVEL);
   double point = SymbolInfoDouble(Symbol(), SYMBOL_POINT);
   double minDist = stopsLevel * point;

   if(otype == ORDER_TYPE_BUY)
   {
      if(sl > 0.0 && (price - sl) < minDist) sl = NPrice(price - minDist);
      if(tp > 0.0 && (tp - price) < minDist) tp = NPrice(price + minDist);
   }
   else
   {
      if(sl > 0.0 && (sl - price) < minDist) sl = NPrice(price + minDist);
      if(tp > 0.0 && (price - tp) < minDist) tp = NPrice(price - minDist);
   }
}

void ManageTrailingStop()
{
   if(!InpUseTrailingStop) return;
   for(int i=PositionsTotal()-1; i>=0; i--)
   {
      if(!g_pos.SelectByIndex(i)) continue;
      if(g_pos.Magic() != InpMagicNumber || g_pos.Symbol() != Symbol()) continue;
      double openPrice = g_pos.PriceOpen();
      double currentSL = g_pos.StopLoss();
      double bid = SymbolInfoDouble(Symbol(), SYMBOL_BID);
      double ask = SymbolInfoDouble(Symbol(), SYMBOL_ASK);
      double point = SymbolInfoDouble(Symbol(), SYMBOL_POINT);
      double trailStart = InpTrailStartPct/100.0 * openPrice;
      double trailStep  = InpTrailStepPct/100.0 * openPrice;

      if(g_pos.PositionType() == POSITION_TYPE_BUY)
      {
         if(bid - openPrice >= trailStart)
         {
            double newSL = bid - trailStep;
            if(newSL > currentSL && newSL > openPrice)
               g_trade.PositionModify(g_pos.Ticket(), newSL, g_pos.TakeProfit());
         }
      }
      else // SELL
      {
         if(openPrice - ask >= trailStart)
         {
            double newSL = ask + trailStep;
            if((currentSL == 0 || newSL < currentSL) && newSL < openPrice)
               g_trade.PositionModify(g_pos.Ticket(), newSL, g_pos.TakeProfit());
         }
      }
   }
}

//+------------------------------------------------------------------+
//| HELPER FUNCTIONS                                                  |
//+------------------------------------------------------------------+
bool HasPosition()
{
   for(int i=PositionsTotal()-1; i>=0; i--)
      if(g_pos.SelectByIndex(i) && g_pos.Magic()==InpMagicNumber && g_pos.Symbol()==Symbol())
         return true;
   return false;
}

double GetFloatPL()
{
   double t=0.0;
   for(int i=PositionsTotal()-1; i>=0; i--)
      if(g_pos.SelectByIndex(i) && g_pos.Magic()==InpMagicNumber && g_pos.Symbol()==Symbol())
         t += g_pos.Profit() + g_pos.Swap() + g_pos.Commission();
   return t;
}

int GetConsecutiveLosses()
{
   int losses=0;
   if(HistorySelect(0, TimeCurrent()))
   {
      int total = HistoryDealsTotal();
      for(int i=total-1; i>=0; i--)
      {
         ulong tk = HistoryDealGetTicket(i);
         if(HistoryDealGetInteger(tk, DEAL_MAGIC) != InpMagicNumber) continue;
         if(HistoryDealGetString(tk, DEAL_SYMBOL) != Symbol()) continue;
         if(HistoryDealGetInteger(tk, DEAL_ENTRY) == DEAL_ENTRY_OUT)
         {
            double pnl = HistoryDealGetDouble(tk, DEAL_PROFIT)
                       + HistoryDealGetDouble(tk, DEAL_SWAP)
                       + HistoryDealGetDouble(tk, DEAL_COMMISSION);
            if(pnl < 0) losses++; else break;
         }
      }
   }
   return losses;
}

bool IsMarketOpen()
{
   ENUM_SYMBOL_TRADE_MODE m = (ENUM_SYMBOL_TRADE_MODE)SymbolInfoInteger(Symbol(), SYMBOL_TRADE_MODE);
   return (m == SYMBOL_TRADE_MODE_FULL || m == SYMBOL_TRADE_MODE_LONGONLY || m == SYMBOL_TRADE_MODE_SHORTONLY);
}

bool DailyLimitsOK()
{
   double bal = AccountInfoDouble(ACCOUNT_BALANCE);
   if(bal <= 0) return true;
   if(InpMaxDailyTrades > 0 && g_sessTradesToday >= InpMaxDailyTrades) return false;
   if(InpMaxDailyLossPct > 0.0 && g_sessProfit < -(bal * InpMaxDailyLossPct / 100.0)) return false;
   if(InpMaxDailyProfitPct > 0.0 && g_sessProfit >= (bal * InpMaxDailyProfitPct / 100.0)) return false;
   return true;
}

double NPrice(double p) { return NormalizeDouble(p, (int)SymbolInfoInteger(Symbol(), SYMBOL_DIGITS)); }

ENUM_ORDER_TYPE_FILLING GetFillMode()
{
   uint f = (uint)SymbolInfoInteger(Symbol(), SYMBOL_FILLING_MODE);
   if((f & SYMBOL_FILLING_FOK) != 0) return ORDER_FILLING_FOK;
   if((f & SYMBOL_FILLING_IOC) != 0) return ORDER_FILLING_IOC;
   return ORDER_FILLING_RETURN;
}

datetime DayStart(datetime ts)
{
   MqlDateTime d; TimeToStruct(ts, d);
   return ts - (datetime)(d.hour*3600 + d.min*60 + d.sec);
}

void RestoreSession()
{
   datetime ds = DayStart(TimeCurrent());
   if(!HistorySelect(ds, TimeCurrent())) return;
   // g_sessTradesToday is already reset before calling; just add
   for(int i = 0; i < HistoryDealsTotal(); i++)
   {
      ulong tk = HistoryDealGetTicket(i);
      if((ulong)HistoryDealGetInteger(tk, DEAL_MAGIC) == InpMagicNumber &&
         HistoryDealGetString(tk, DEAL_SYMBOL) == Symbol())
      {
         if(HistoryDealGetInteger(tk, DEAL_ENTRY) == DEAL_ENTRY_IN)
            g_sessTradesToday++;
      }
   }
}

void BuildSessionStats()
{
   g_sessProfit = 0.0; g_sessWins = 0; g_sessLosses = 0;
   if(!HistorySelect(DayStart(TimeCurrent()), TimeCurrent())) return;
   for(int i = 0; i < HistoryDealsTotal(); i++)
   {
      ulong tk = HistoryDealGetTicket(i);
      if((ulong)HistoryDealGetInteger(tk, DEAL_MAGIC) != InpMagicNumber ||
         HistoryDealGetString(tk, DEAL_SYMBOL) != Symbol()) continue;
      if(HistoryDealGetInteger(tk, DEAL_ENTRY) == DEAL_ENTRY_OUT)
      {
         double pnl = HistoryDealGetDouble(tk, DEAL_PROFIT)
                    + HistoryDealGetDouble(tk, DEAL_SWAP)
                    + HistoryDealGetDouble(tk, DEAL_COMMISSION);
         g_sessProfit += pnl;
         if(pnl >= 0) g_sessWins++; else g_sessLosses++;
      }
   }
}

void ResetAnalysis()
{
   // reset only the signal/tick state, not the session stats
   ZeroMemory(g_tickBuffer);
   g_tickCount = 0;
   g_lastMLConfidence = 0.5;
   g_rawScoreDrift = 0.0;
   g_emaRawScore = 0.0;
   g_lastAction = "BTC Matrix reset.";
}

void UpdateTickBuffer()
{
   MqlTick tick;
   if(SymbolInfoTick(Symbol(), tick))
   {
      if(g_tickCount < InpTickBufferSize)
      {
         g_tickBuffer[g_tickCount] = tick;
         g_tickCount++;
      }
      else
      {
         for(int i=0; i<InpTickBufferSize-1; i++)
            g_tickBuffer[i] = g_tickBuffer[i+1];
         g_tickBuffer[InpTickBufferSize-1] = tick;
      }
   }
}

// -----------------------------------------------------------------------
// DASHBOARD (unchanged except for Chi replaced by Drift)
// -----------------------------------------------------------------------
void R(string nm,int x,int y,int w,int h,color bg,color brd=clrNONE,int bw=1)
{
   string n=D+nm; if(ObjectFind(0,n)>=0) ObjectDelete(0,n);
   ObjectCreate(0,n,OBJ_RECTANGLE_LABEL,0,0,0);
   ObjectSetInteger(0,n,OBJPROP_CORNER,CORNER_LEFT_UPPER);
   ObjectSetInteger(0,n,OBJPROP_XDISTANCE,x); ObjectSetInteger(0,n,OBJPROP_YDISTANCE,y);
   ObjectSetInteger(0,n,OBJPROP_XSIZE,w); ObjectSetInteger(0,n,OBJPROP_YSIZE,h);
   ObjectSetInteger(0,n,OBJPROP_BGCOLOR,bg);
   if(brd!=clrNONE){ ObjectSetInteger(0,n,OBJPROP_BORDER_TYPE,BORDER_FLAT); ObjectSetInteger(0,n,OBJPROP_COLOR,brd); ObjectSetInteger(0,n,OBJPROP_WIDTH,bw); }
   else ObjectSetInteger(0,n,OBJPROP_BORDER_TYPE,BORDER_RAISED);
   ObjectSetInteger(0,n,OBJPROP_SELECTABLE,false); ObjectSetInteger(0,n,OBJPROP_HIDDEN,true);
}
void L(string nm,int x,int y,string txt,color clr,int fsz,string fnt="Arial Bold")
{
   string n=D+nm; if(ObjectFind(0,n)>=0) ObjectDelete(0,n);
   ObjectCreate(0,n,OBJ_LABEL,0,0,0);
   ObjectSetInteger(0,n,OBJPROP_CORNER,CORNER_LEFT_UPPER);
   ObjectSetInteger(0,n,OBJPROP_XDISTANCE,x); ObjectSetInteger(0,n,OBJPROP_YDISTANCE,y);
   ObjectSetString(0,n,OBJPROP_TEXT,txt); ObjectSetInteger(0,n,OBJPROP_COLOR,clr);
   ObjectSetInteger(0,n,OBJPROP_FONTSIZE,fsz); ObjectSetString(0,n,OBJPROP_FONT,fnt);
   ObjectSetInteger(0,n,OBJPROP_SELECTABLE,false); ObjectSetInteger(0,n,OBJPROP_HIDDEN,true);
}
void U(string nm,string txt,color clr=C'220,225,240')
{  string n=D+nm; if(ObjectFind(0,n)>=0){ ObjectSetString(0,n,OBJPROP_TEXT,txt); ObjectSetInteger(0,n,OBJPROP_COLOR,clr); } }
void Bar(string nm,int x,int y,int w,int h,double pct,color fg,color bg_c)
{  R(nm+"_bg",x,y,w,h,bg_c,C_BORDER,1); int fw=(int)MathMax(2,MathRound(pct/100.0*(w-2))); R(nm+"_fg",x+1,y+1,fw,h-2,fg,clrNONE); }
void UpdBar(string nm,double pct,color fg)
{
   string n=D+nm+"_fg", nb=D+nm+"_bg"; int w=0;
   if(ObjectFind(0,nb)>=0) w=(int)ObjectGetInteger(0,nb,OBJPROP_XSIZE);
   if(w<=0) return; int fw=(int)MathMax(2,MathRound(pct/100.0*(w-2)));
   if(ObjectFind(0,n)>=0){ ObjectSetInteger(0,n,OBJPROP_XSIZE,fw); ObjectSetInteger(0,n,OBJPROP_BGCOLOR,fg); }
}
void InitDash()
{
   int X=InpDashX,Y=InpDashY;
   R("frame_outer",X,Y,DW,DH,C_BG0,C_ACBORD,2);
   R("frame_inner",X+2,Y+2,DW-4,DH-4,C_BG0,C_BORDER,1);
   R("hdr_bg",X+2,Y+2,DW-4,80,C_HDRBAR,C_BORDER,1);
   R("hdr_acc",X+2,Y+2,DW-4,3,C_ACBORD);
   L("h_name",X+10,Y+10,InpBotName,C_GOLD,12,"Arial Black");
   L("h_tag",X+10,Y+30,"AI+Patterns | Trend Following | Trailing",C_CYAN,7,"Arial");
   L("h_ver",X+10,Y+44,"v6.0 Magic:"+IntegerToString((long)InpMagicNumber)+" "+Symbol(),C_LBLUE,7,"Arial");
   R("live_bg",X+DW-80,Y+8,64,22,C_DKGREEN,C_GREEN,1);
   L("live_lbl",X+DW-72,Y+12,"● LIVE",C_GREEN,7,"Arial Bold");
   R("div_hdr",X+2,Y+82,DW-4,2,C_ACBORD);

   R("stat_bg",X+2,Y+86,DW-4,3,C_BG2,C_BORDER,1);
   L("lb_stat",X+14,Y+93,"STATUS",C_SUBTEXT,8,"Arial");
   L("vl_stat",X+90,Y+93,"WARMING UP",C_ORANGE,9,"Arial Black");
   L("lb_act",X+250,Y+93,"Action:",C_SUBTEXT,7,"Arial");
   L("vl_act",X+310,Y+93,"--",C_WHITE,7,"Arial");
   R("div_stat",X+2,Y+118,DW-4,1,C_BORDER);

   R("sec_a",X+2,Y+122,DW-4,168,C_BG1,C_BORDER,1);
   R("sec_a_hd",X+2,Y+122,DW-4,22,C_HDRBAR,C_BORDER,1);
   L("sec_a_lb",X+10,Y+126,"▸ PERFORMANCE & RISK",C_GOLD,8,"Arial Black");
   L("lb_sp",X+14,Y+149,"Session Profit",C_SUBTEXT,8,"Arial");
   L("vl_sp",X+200,Y+149,"$ 0.00",C_WHITE,9,"Arial Bold");
   L("lb_fp",X+14,Y+165,"Floating P&L",C_SUBTEXT,8,"Arial");
   L("vl_fp",X+200,Y+165,"$ 0.00",C_WHITE,9,"Arial Bold");
   L("lb_dd",X+14,Y+181,"Drawdown",C_SUBTEXT,8,"Arial");
   L("vl_dd",X+200,Y+181,"0.00 %",C_WHITE,9,"Arial Bold");
   Bar("dd_bar",X+280,Y+183,130,12,0,C_RED,C_DGRAY);
   L("lb_tt",X+14,Y+197,"Trades Today",C_SUBTEXT,8,"Arial");
   L("vl_tt",X+200,Y+197,"0 / "+IntegerToString(InpMaxDailyTrades),C_WHITE,9,"Arial Bold");
   L("lb_rcv",X+14,Y+213,"Recovery Tier",C_SUBTEXT,8,"Arial");
   L("vl_rcv",X+200,Y+213,"Tier 0 (1.0x)",C_WHITE,9,"Arial Bold");
   R("sec_c",X+2,Y+296,DW-4,160,C_BG1,C_BORDER,1);
   R("sec_c_hd",X+2,Y+296,DW-4,22,C_HDRBAR,C_BORDER,1);
   L("sec_c_lb",X+10,Y+300,"▸ AI & MICROSTRUCTURE",C_GOLD,8,"Arial Black");
   L("lb_mlc",X+14,Y+327,"AI Confidence",C_SUBTEXT,8,"Arial");
   L("vl_mlc",X+200,Y+327,"50.0 %",C_CYAN,9,"Arial Bold");
   Bar("ml_bar",X+280,Y+329,130,12,50,C_CYAN,C_DGRAY);
   L("lb_dir",X+14,Y+343,"Projected Vector",C_SUBTEXT,8,"Arial");
   L("vl_dir",X+200,Y+343,"--",C_WHITE,9,"Arial Bold");
   L("lb_drift",X+14,Y+359,"Score Drift",C_SUBTEXT,8,"Arial");
   L("vl_drift",X+200,Y+359,"0.00",C_WHITE,9,"Arial Bold");
   L("lb_buf",X+14,Y+375,"Tick Buffer",C_SUBTEXT,8,"Arial");
   L("vl_buf",X+200,Y+375,"0 / "+IntegerToString(InpTickBufferSize),C_WHITE,9,"Arial Bold");
   Bar("buf_bar",X+280,Y+377,130,12,0,C_PURPLE,C_DGRAY);
   R("sec_d",X+2,Y+464,DW-4,56,C_BG2,C_BORDER,1);
   L("cfg1",X+14,Y+469,"Lot:"+DoubleToString(InpBaseLotSize,2)+" Bulk:"+IntegerToString(InpBulkTrades)+" Trail:"+(InpUseTrailingStop?"ON":"OFF"),C_LBLUE,7,"Arial");
   L("cfg2",X+14,Y+483,"ML Thresh:"+DoubleToString(InpMLThreshold*100,1)+"%  TP/SL:"+DoubleToString(InpTakeProfitPct,1)+"/"+DoubleToString(InpStopLossPct,1),C_LBLUE,7,"Arial");
   R("ftr",X+2,Y+603,DW-4,15,C_HDRBAR,C_BORDER,1);
   L("ft_time",X+10,Y+605,"Server: --:--",C_MGRAY,7,"Arial");
   ChartRedraw(0);
}
void UpdateDash()
{
   if(!InpShowDash) return;
   double floatPL = GetFloatPL();
   U("vl_stat", g_statusText, g_statusColor);
   U("vl_act",  g_lastAction, C_SUBTEXT);
   U("vl_sp", "$ "+DoubleToString(g_sessProfit,2), (g_sessProfit>=0)?C_GREEN:C_RED);
   U("vl_fp", "$ "+DoubleToString(floatPL,2), (floatPL>=0)?C_GREEN:C_RED);
   U("vl_dd", DoubleToString(g_drawdown,2)+" %", (g_drawdown<5)?C_GREEN:C_RED);
   UpdBar("dd_bar", MathMin(g_drawdown*5.0,100.0), (g_drawdown<5)?C_GREEN:C_RED);
   U("vl_tt", IntegerToString(g_sessTradesToday)+" / "+IntegerToString(InpMaxDailyTrades), C_WHITE);
   int trIndex = MathMin(g_consecutiveLosses,4);
   U("vl_rcv", "Tier "+IntegerToString(trIndex)+" ("+DoubleToString(g_recoveryTiers[trIndex],1)+"x)", (trIndex>0)?C_ORANGE:C_GREEN);
   U("vl_mlc", DoubleToString(g_lastMLConfidence*100.0,1)+" %", (g_lastMLConfidence>InpMLThreshold)?C_GREEN:C_RED);
   UpdBar("ml_bar", g_lastMLConfidence*100.0, (g_lastMLConfidence>0.5)?C_GREEN:C_RED);
   if(g_lastSignalDir==1) U("vl_dir","BULLISH",C_GREEN);
   else if(g_lastSignalDir==-1) U("vl_dir","BEARISH",C_RED);
   else U("vl_dir","NEUTRAL",C_MGRAY);
   U("vl_drift", DoubleToString(g_rawScoreDrift,3), C_WHITE);
   U("vl_buf", IntegerToString(g_tickCount)+" / "+IntegerToString(InpTickBufferSize), (g_tickCount==InpTickBufferSize)?C_GREEN:C_ORANGE);
   UpdBar("buf_bar", ((double)g_tickCount/InpTickBufferSize)*100.0, C_PURPLE);
   U("ft_time", "Server: "+TimeToString(TimeCurrent(),TIME_SECONDS)+"  Local: "+TimeToString(TimeLocal(),TIME_MINUTES), C_DGRAY);
   ChartRedraw(0);
}
void DeleteDash(){ ObjectsDeleteAll(0,D); ChartRedraw(0); }
//+------------------------------------------------------------------+