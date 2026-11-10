//+------------------------------------------------------------------+
//|                    QUANTUM APEX EA v3.0                          |
//|          9-Layer Institutional Confluence Engine                  |
//|     Assets: XAUUSD + Major Forex Pairs | Platform: MT5           |
//+------------------------------------------------------------------+
#property copyright   "Quantum APEX Systems"
#property link        "https://quantumapex.ea"
#property version     "3.00"
#property strict

#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>
#include <Trade\OrderInfo.mqh>
#include <Indicators\Trend.mqh>

CTrade         trade;
CPositionInfo  posInfo;
COrderInfo     orderInfo;

//+------------------------------------------------------------------+
//|                    ENUMERATIONS                                   |
//+------------------------------------------------------------------+
enum ENUM_SIGNAL_GRADE
  {
   GRADE_NONE     = 0,
   GRADE_WEAK     = 1,
   GRADE_STANDARD = 2,
   GRADE_ELITE    = 3,
   GRADE_APEX     = 4
  };

enum ENUM_BIAS
  {
   BIAS_NONE    = 0,
   BIAS_BULLISH = 1,
   BIAS_BEARISH = -1
  };

//+------------------------------------------------------------------+
//|                    INPUT PARAMETERS                               |
//+------------------------------------------------------------------+

// ── GENERAL ───────────────────────────────────────────────────────
input group            "═══ GENERAL SETTINGS ═══"
input string           InpEAName           = "Quantum APEX v3.0";
input int              InpMagicNumber      = 20250101;
input bool             InpEnableTrading    = true;
input bool             InpEnableAlerts     = true;
input bool             InpEnableDashboard  = true;
input bool             InpEnableLogging    = true;

// ── LAYER 1: ICT/SMC ─────────────────────────────────────────────
input group            "═══ LAYER 1: ICT / SMC ENGINE ═══"
input bool             InpUseICT           = true;
input int              InpOBLookback       = 50;
input int              InpFVGLookback      = 30;
input bool             InpRequireLiqSweep  = true;
input ENUM_TIMEFRAMES  InpHTFBiasTF        = PERIOD_H4;

// ── LAYER 2: EMA ──────────────────────────────────────────────────
input group            "═══ LAYER 2: MULTI-EMA ENGINE ═══"
input bool             InpUseEMA           = true;
input int              InpEMAFast          = 9;
input int              InpEMAMid           = 21;
input int              InpEMASlow          = 50;
input int              InpEMAMaster        = 200;
input ENUM_TIMEFRAMES  InpEMATF            = PERIOD_H1;

// ── LAYER 3: MACD + RSI + ADX ────────────────────────────────────
input group            "═══ LAYER 3: MACD + RSI + ADX ═══"
input bool             InpUseMACD          = true;
input int              InpMACDFast         = 12;
input int              InpMACDSlow         = 26;
input int              InpMACDSignal       = 9;
input bool             InpUseRSI           = true;
input int              InpRSIPeriod        = 14;
input double           InpRSIBuyMin        = 45.0;
input double           InpRSIBuyMax        = 65.0;
input double           InpRSISellMin       = 35.0;
input double           InpRSISellMax       = 55.0;
input bool             InpUseADX           = true;
input int              InpADXPeriod        = 14;
input double           InpADXMinStrength   = 25.0;

// ── LAYER 4: VWAP + SESSION ───────────────────────────────────────
input group            "═══ LAYER 4: VWAP + SESSION FILTER ═══"
input bool             InpUseVWAP          = true;
input bool             InpUseSessionFilter = true;
input int              InpLondonStart      = 7;
input int              InpLondonEnd        = 10;
input int              InpNYStart          = 12;
input int              InpNYEnd            = 15;
input bool             InpAllowOverlap     = true;

// ── LAYER 5: SUPERTREND ───────────────────────────────────────────
input group            "═══ LAYER 5: ADAPTIVE SUPERTREND ═══"
input bool             InpUseSuperTrend    = true;
input int              InpSTPeriod         = 10;
input double           InpSTMultiplier     = 3.0;
input ENUM_TIMEFRAMES  InpSTTF             = PERIOD_H1;

// ── LAYER 6: FIBONACCI OTE ────────────────────────────────────────
input group            "═══ LAYER 6: FIBONACCI OTE ═══"
input bool             InpUseFibonacci     = true;
input double           InpFibOTELow        = 0.618;
input double           InpFibOTEHigh       = 0.786;
input int              InpFibSwingLookback = 40;

// ── LAYER 7: SPREAD + NEWS ────────────────────────────────────────
input group            "═══ LAYER 7: SPREAD + NEWS FILTER ═══"
input bool             InpUseSpreadFilter  = true;
input double           InpMaxSpreadGold    = 35.0;
input double           InpMaxSpreadForex   = 15.0;
input bool             InpUseNewsFilter    = true;
input int              InpNewsBufferBefore = 30;
input int              InpNewsBufferAfter  = 15;

// ── LAYER 8: ATR RISK ─────────────────────────────────────────────
input group            "═══ LAYER 8: ATR RISK ENGINE ═══"
input bool             InpUseATRRisk       = true;
input int              InpATRPeriod        = 14;
input double           InpATRSLMult        = 1.5;
input double           InpATRTP1Mult       = 1.5;
input double           InpATRTP2Mult       = 2.5;
input double           InpATRTrailMult     = 0.8;
input double           InpTrailActivation  = 1.0;

// ── LAYER 9: AI SCORING ───────────────────────────────────────────
input group            "═══ LAYER 9: AI CONFLUENCE SCORE ═══"
input int              InpMinScoreTrade    = 70;
input int              InpMinScoreFull     = 90;
input bool             InpDynamicLotSize   = true;

// ── MONEY MANAGEMENT ──────────────────────────────────────────────
input group            "═══ MONEY MANAGEMENT ═══"
input double           InpRiskPercent      = 1.0;
input double           InpMaxRiskPercent   = 2.0;
input double           InpMaxDailyDD       = 5.0;
input double           InpMaxTotalDD       = 10.0;
input int              InpMaxOpenTrades    = 2;
input bool             InpScaleOutPartials = true;
input bool             InpPropFirmMode     = false;

// ── DISPLAY ───────────────────────────────────────────────────────
input group            "═══ DISPLAY SETTINGS ═══"
input color            InpBullishColor     = clrDodgerBlue;
input color            InpBearishColor     = clrCrimson;
input color            InpNeutralColor     = clrGray;
input bool             InpShowOBZones      = true;
input bool             InpShowFVGZones     = true;
input bool             InpShowScorePanel   = true;

//+------------------------------------------------------------------+
//|                    GLOBAL VARIABLES                               |
//+------------------------------------------------------------------+

// Indicator handles
int g_handleEMAFast, g_handleEMAMid, g_handleEMASlow, g_handleEMAMaster;
int g_handleMACD, g_handleRSI, g_handleADX, g_handleATR;
int g_handleHTFEMAFast, g_handleHTFEMASlow, g_handleHTFEMAMaster;

// State variables
double   g_dailyStartBalance   = 0;
double   g_totalStartBalance   = 0;
int      g_consecutiveLosses   = 0;
datetime g_lastTradeTime       = 0;
datetime g_coolingPeriodEnd    = 0;
bool     g_dailyHaltActive     = false;
int      g_aiScore             = 0;
ENUM_BIAS g_currentBias        = BIAS_NONE;
double   g_currentATR          = 0;
double   g_vwapValue           = 0;
double   g_vwapCumVol          = 0;
double   g_vwapCumTP           = 0;
datetime g_vwapLastReset       = 0;

// Order Block structure
struct SOrderBlock
  {
   double   high;
   double   low;
   double   mid;
   bool     bullish;
   bool     active;
   datetime time;
  };

// FVG structure
struct SFVG
  {
   double   top;
   double   bottom;
   bool     bullish;
   bool     active;
   datetime time;
  };

// Scoring structure
struct SScoreCard
  {
   int ictScore;
   int emaScore;
   int momentumScore;
   int vwapScore;
   int superTrendScore;
   int fibScore;
   int newsSpreadScore;
   int atrRRScore;
   int totalScore;
   ENUM_SIGNAL_GRADE grade;
  };

SOrderBlock g_orderBlocks[];
SFVG        g_fvgZones[];
SScoreCard  g_scoreCard;

// TP tracking per ticket
struct STradeLevel
  {
   ulong    ticket;
   double   tp1Price;
   double   tp2Price;
   bool     tp1Hit;
   bool     tp2Hit;
   bool     beSet;
   double   entryPrice;
   double   atrAtEntry;
   bool     isBuy;
  };

STradeLevel g_tradeLevels[];

//+------------------------------------------------------------------+
//|                    EXPERT INITIALIZATION                          |
//+------------------------------------------------------------------+
int OnInit()
  {
   Print("=== QUANTUM APEX EA v3.0 INITIALIZING ===");

   // Initialize trade object
   trade.SetExpertMagicNumber(InpMagicNumber);
   trade.SetDeviationInPoints(20);
   trade.SetTypeFilling(ORDER_FILLING_IOC);

   // Create EMA handles (entry TF)
   g_handleEMAFast   = iMA(_Symbol, InpEMATF, InpEMAFast,   0, MODE_EMA, PRICE_CLOSE);
   g_handleEMAMid    = iMA(_Symbol, InpEMATF, InpEMAMid,    0, MODE_EMA, PRICE_CLOSE);
   g_handleEMASlow   = iMA(_Symbol, InpEMATF, InpEMASlow,   0, MODE_EMA, PRICE_CLOSE);
   g_handleEMAMaster = iMA(_Symbol, InpEMATF, InpEMAMaster, 0, MODE_EMA, PRICE_CLOSE);

   // HTF EMA handles for bias
   g_handleHTFEMAFast   = iMA(_Symbol, InpHTFBiasTF, InpEMAFast,   0, MODE_EMA, PRICE_CLOSE);
   g_handleHTFEMASlow   = iMA(_Symbol, InpHTFBiasTF, InpEMASlow,   0, MODE_EMA, PRICE_CLOSE);
   g_handleHTFEMAMaster = iMA(_Symbol, InpHTFBiasTF, InpEMAMaster, 0, MODE_EMA, PRICE_CLOSE);

   // Momentum handles
   g_handleMACD = iMACD(_Symbol, PERIOD_CURRENT, InpMACDFast, InpMACDSlow, InpMACDSignal, PRICE_CLOSE);
   g_handleRSI  = iRSI(_Symbol,  PERIOD_CURRENT, InpRSIPeriod, PRICE_CLOSE);
   g_handleADX  = iADX(_Symbol,  PERIOD_CURRENT, InpADXPeriod);
   g_handleATR  = iATR(_Symbol,  PERIOD_CURRENT, InpATRPeriod);

   // Validate handles
   if(g_handleEMAFast   == INVALID_HANDLE ||
      g_handleEMAMid    == INVALID_HANDLE ||
      g_handleEMASlow   == INVALID_HANDLE ||
      g_handleEMAMaster == INVALID_HANDLE ||
      g_handleMACD      == INVALID_HANDLE ||
      g_handleRSI       == INVALID_HANDLE ||
      g_handleADX       == INVALID_HANDLE ||
      g_handleATR       == INVALID_HANDLE)
     {
      Alert("QUANTUM APEX: FAILED to create indicator handles! EA stopping.");
      return(INIT_FAILED);
     }

   // Store starting balances
   g_totalStartBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   g_dailyStartBalance = AccountInfoDouble(ACCOUNT_BALANCE);

   // Init VWAP
   g_vwapLastReset = 0;
   g_vwapCumVol    = 0;
   g_vwapCumTP     = 0;

   // Init arrays
   ArrayResize(g_orderBlocks, 0);
   ArrayResize(g_fvgZones,    0);
   ArrayResize(g_tradeLevels, 0);

   Print("=== QUANTUM APEX v3.0 INITIALIZED SUCCESSFULLY ===");
   Print("Symbol: ", _Symbol, " | Magic: ", InpMagicNumber);
   Print("Risk per trade: ", InpRiskPercent, "%");
   Print("Min AI Score to trade: ", InpMinScoreTrade);

   // Draw dashboard
   if(InpEnableDashboard)
      DrawDashboard();

   EventSetTimer(1);
   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//|                    EXPERT DEINITIALIZATION                        |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   EventKillTimer();
   ObjectsDeleteAll(0, "QA_");
   Print("QUANTUM APEX: EA Deinitialized. Reason: ", reason);
  }

//+------------------------------------------------------------------+
//|                    EXPERT TICK FUNCTION                           |
//+------------------------------------------------------------------+
void OnTick()
  {
   // ── Manage existing trades every tick ──────────────────────────
   ManageOpenTrades();

   // ── Only process new bar logic on new bar ──────────────────────
   static datetime lastBarTime = 0;
   datetime        currentBar  = iTime(_Symbol, PERIOD_CURRENT, 0);
   if(currentBar == lastBarTime) return;
   lastBarTime = currentBar;

   // ── Trading enabled check ─────────────────────────────────────
   if(!InpEnableTrading) return;

   // ── Daily DD and cooling period check ─────────────────────────
   if(!CheckRiskLimits()) return;

   // ── Check session filter ───────────────────────────────────────
   if(InpUseSessionFilter && !IsActiveSession()) return;

   // ── Check spread filter ────────────────────────────────────────
   if(InpUseSpreadFilter && !IsSpreadOK()) return;

   // ── Check news filter ──────────────────────────────────────────
   if(InpUseNewsFilter && IsNearHighImpactNews()) return;

   // ── Check max open trades ──────────────────────────────────────
   if(CountOpenTrades() >= InpMaxOpenTrades) return;

   // ── Update VWAP ────────────────────────────────────────────────
   if(InpUseVWAP) UpdateVWAP();

   // ── Update ATR ─────────────────────────────────────────────────
   UpdateATR();

   // ── Scan ICT zones ─────────────────────────────────────────────
   if(InpUseICT)
     {
      ScanOrderBlocks();
      ScanFairValueGaps();
     }

   // ── Compute AI Score ───────────────────────────────────────────
   g_scoreCard = ComputeAIScore();
   g_aiScore   = g_scoreCard.totalScore;

   // ── Update dashboard ───────────────────────────────────────────
   if(InpEnableDashboard)
      UpdateDashboard(g_scoreCard);

   // ── Fire trade if score is sufficient ─────────────────────────
   if(g_aiScore >= InpMinScoreTrade)
      ExecuteTrade(g_scoreCard);
  }

//+------------------------------------------------------------------+
//|                    TIMER (every second)                           |
//+------------------------------------------------------------------+
void OnTimer()
  {
   if(InpEnableDashboard)
     {
      // Refresh live data on dashboard
      string score = IntegerToString(g_aiScore);
      ObjectSetString(0, "QA_Score_Val", OBJPROP_TEXT, score + "/100");
     }
  }

//+------------------------------------------------------------------+
//|              LAYER 1A: SCAN ORDER BLOCKS                          |
//+------------------------------------------------------------------+
void ScanOrderBlocks()
  {
   ArrayResize(g_orderBlocks, 0);
   int bars = InpOBLookback;

   double closeArr[], openArr[], highArr[], lowArr[];
   ArraySetAsSeries(closeArr, true);
   ArraySetAsSeries(openArr,  true);
   ArraySetAsSeries(highArr,  true);
   ArraySetAsSeries(lowArr,   true);

   CopyClose(_Symbol, InpHTFBiasTF, 0, bars + 5, closeArr);
   CopyOpen(_Symbol,  InpHTFBiasTF, 0, bars + 5, openArr);
   CopyHigh(_Symbol,  InpHTFBiasTF, 0, bars + 5, highArr);
   CopyLow(_Symbol,   InpHTFBiasTF, 0, bars + 5, lowArr);

   for(int i = 2; i < bars - 2; i++)
     {
      // Detect Bullish Order Block:
      // Last bearish candle before a bullish BOS
      bool isBearishCandle = (openArr[i] > closeArr[i]);
      bool subsequentBullish = (closeArr[i-1] > openArr[i-1]) &&
                               (closeArr[i-2] > openArr[i-2]);
      bool bos = (highArr[i-1] > highArr[i] && highArr[i-2] > highArr[i-1]);

      if(isBearishCandle && subsequentBullish && bos)
        {
         SOrderBlock ob;
         ob.high    = highArr[i];
         ob.low     = lowArr[i];
         ob.mid     = (highArr[i] + lowArr[i]) / 2.0;
         ob.bullish = true;
         ob.active  = true;
         ob.time    = iTime(_Symbol, InpHTFBiasTF, i);

         int sz = ArraySize(g_orderBlocks);
         ArrayResize(g_orderBlocks, sz + 1);
         g_orderBlocks[sz] = ob;

         if(InpShowOBZones)
            DrawOBZone(ob, sz);
        }

      // Detect Bearish Order Block:
      bool isBullishCandle = (closeArr[i] > openArr[i]);
      bool subsequentBearish = (closeArr[i-1] < openArr[i-1]) &&
                               (closeArr[i-2] < openArr[i-2]);
      bool bosBear = (lowArr[i-1] < lowArr[i] && lowArr[i-2] < lowArr[i-1]);

      if(isBullishCandle && subsequentBearish && bosBear)
        {
         SOrderBlock ob;
         ob.high    = highArr[i];
         ob.low     = lowArr[i];
         ob.mid     = (highArr[i] + lowArr[i]) / 2.0;
         ob.bullish = false;
         ob.active  = true;
         ob.time    = iTime(_Symbol, InpHTFBiasTF, i);

         int sz = ArraySize(g_orderBlocks);
         ArrayResize(g_orderBlocks, sz + 1);
         g_orderBlocks[sz] = ob;

         if(InpShowOBZones)
            DrawOBZone(ob, sz);
        }
     }
  }

//+------------------------------------------------------------------+
//|              LAYER 1B: SCAN FAIR VALUE GAPS                       |
//+------------------------------------------------------------------+
void ScanFairValueGaps()
  {
   ArrayResize(g_fvgZones, 0);
   int bars = InpFVGLookback;

   double highArr[], lowArr[], closeArr[];
   ArraySetAsSeries(highArr,  true);
   ArraySetAsSeries(lowArr,   true);
   ArraySetAsSeries(closeArr, true);

   CopyHigh(_Symbol,  PERIOD_CURRENT, 0, bars + 3, highArr);
   CopyLow(_Symbol,   PERIOD_CURRENT, 0, bars + 3, lowArr);
   CopyClose(_Symbol, PERIOD_CURRENT, 0, bars + 3, closeArr);

   for(int i = 1; i < bars - 1; i++)
     {
      // Bullish FVG: candle[i+1].high < candle[i-1].low
      if(highArr[i+1] < lowArr[i-1])
        {
         SFVG fvg;
         fvg.top     = lowArr[i-1];
         fvg.bottom  = highArr[i+1];
         fvg.bullish = true;
         fvg.active  = (MathMin(closeArr[0], closeArr[1]) > fvg.bottom);
         fvg.time    = iTime(_Symbol, PERIOD_CURRENT, i);

         int sz = ArraySize(g_fvgZones);
         ArrayResize(g_fvgZones, sz + 1);
         g_fvgZones[sz] = fvg;

         if(InpShowFVGZones && fvg.active)
            DrawFVGZone(fvg, sz);
        }

      // Bearish FVG: candle[i+1].low > candle[i-1].high
      if(lowArr[i+1] > highArr[i-1])
        {
         SFVG fvg;
         fvg.top     = lowArr[i+1];
         fvg.bottom  = highArr[i-1];
         fvg.bullish = false;
         fvg.active  = (MathMax(closeArr[0], closeArr[1]) < fvg.top);
         fvg.time    = iTime(_Symbol, PERIOD_CURRENT, i);

         int sz = ArraySize(g_fvgZones);
         ArrayResize(g_fvgZones, sz + 1);
         g_fvgZones[sz] = fvg;

         if(InpShowFVGZones && fvg.active)
            DrawFVGZone(fvg, sz);
        }
     }
  }

//+------------------------------------------------------------------+
//|              LAYER 1C: LIQUIDITY SWEEP DETECTION                  |
//+------------------------------------------------------------------+
bool DetectLiquiditySweep(bool checkBullish)
  {
   double highArr[], lowArr[], closeArr[], openArr[];
   ArraySetAsSeries(highArr,  true);
   ArraySetAsSeries(lowArr,   true);
   ArraySetAsSeries(closeArr, true);
   ArraySetAsSeries(openArr,  true);

   CopyHigh(_Symbol,  PERIOD_CURRENT, 0, 20, highArr);
   CopyLow(_Symbol,   PERIOD_CURRENT, 0, 20, lowArr);
   CopyClose(_Symbol, PERIOD_CURRENT, 0, 20, closeArr);
   CopyOpen(_Symbol,  PERIOD_CURRENT, 0, 20, openArr);

   if(checkBullish)
     {
      // Bullish sweep: price takes out a recent low then closes back above
      double recentLow = lowArr[1];
      for(int i = 2; i < 10; i++)
         recentLow = MathMin(recentLow, lowArr[i]);

      bool swept  = (lowArr[1] < recentLow * 0.9999);
      bool closed = (closeArr[1] > recentLow);
      return(swept && closed);
     }
   else
     {
      // Bearish sweep: price takes out a recent high then closes back below
      double recentHigh = highArr[1];
      for(int i = 2; i < 10; i++)
         recentHigh = MathMax(recentHigh, highArr[i]);

      bool swept  = (highArr[1] > recentHigh * 1.0001);
      bool closed = (closeArr[1] < recentHigh);
      return(swept && closed);
     }
  }

//+------------------------------------------------------------------+
//|              LAYER 1D: MARKET STRUCTURE SHIFT DETECTION           |
//+------------------------------------------------------------------+
ENUM_BIAS DetectMarketStructure()
  {
   double highArr[], lowArr[], closeArr[];
   ArraySetAsSeries(highArr,  true);
   ArraySetAsSeries(lowArr,   true);
   ArraySetAsSeries(closeArr, true);

   int bars = 30;
   CopyHigh(_Symbol,  InpHTFBiasTF, 0, bars, highArr);
   CopyLow(_Symbol,   InpHTFBiasTF, 0, bars, lowArr);
   CopyClose(_Symbol, InpHTFBiasTF, 0, bars, closeArr);

   // Find recent swing high and swing low
   double swingHigh = highArr[0], swingLow = lowArr[0];
   int    swingHighIdx = 0, swingLowIdx = 0;

   for(int i = 1; i < bars - 1; i++)
     {
      if(highArr[i] > highArr[i-1] && highArr[i] > highArr[i+1])
        {
         if(highArr[i] > swingHigh)
           {
            swingHigh    = highArr[i];
            swingHighIdx = i;
           }
        }
      if(lowArr[i] < lowArr[i-1] && lowArr[i] < lowArr[i+1])
        {
         if(lowArr[i] < swingLow)
           {
            swingLow    = lowArr[i];
            swingLowIdx = i;
           }
        }
     }

   double currentClose = closeArr[0];

   // BOS Bullish: current price breaks above recent swing high
   bool bullishBOS = (currentClose > swingHigh * 1.0001);
   // BOS Bearish: current price breaks below recent swing low
   bool bearishBOS = (currentClose < swingLow  * 0.9999);

   if(bullishBOS)  return(BIAS_BULLISH);
   if(bearishBOS)  return(BIAS_BEARISH);
   return(BIAS_NONE);
  }

//+------------------------------------------------------------------+
//|              LAYER 1E: PRICE IN ORDER BLOCK / FVG                 |
//+------------------------------------------------------------------+
bool PriceInICTZone(bool isBuy)
  {
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double price = isBuy ? ask : bid;

   // Check order blocks
   int obCount = ArraySize(g_orderBlocks);
   for(int i = 0; i < obCount; i++)
     {
      if(!g_orderBlocks[i].active) continue;
      if(g_orderBlocks[i].bullish != isBuy) continue;
      if(price >= g_orderBlocks[i].low && price <= g_orderBlocks[i].high)
         return(true);
     }

   // Check FVG zones
   int fvgCount = ArraySize(g_fvgZones);
   for(int i = 0; i < fvgCount; i++)
     {
      if(!g_fvgZones[i].active) continue;
      if(g_fvgZones[i].bullish != isBuy) continue;
      if(price >= g_fvgZones[i].bottom && price <= g_fvgZones[i].top)
         return(true);
     }

   return(false);
  }

//+------------------------------------------------------------------+
//|              LAYER 2: MULTI-EMA BIAS CHECK                        |
//+------------------------------------------------------------------+
int CheckEMALayer(bool isBuy)
  {
   double emaFast[2], emaMid[2], emaSlow[2], emaMaster[2];

   if(CopyBuffer(g_handleEMAFast,   0, 0, 2, emaFast)   < 2) return 0;
   if(CopyBuffer(g_handleEMAMid,    0, 0, 2, emaMid)    < 2) return 0;
   if(CopyBuffer(g_handleEMASlow,   0, 0, 2, emaSlow)   < 2) return 0;
   if(CopyBuffer(g_handleEMAMaster, 0, 0, 2, emaMaster) < 2) return 0;

   double price = isBuy ?
                  SymbolInfoDouble(_Symbol, SYMBOL_ASK) :
                  SymbolInfoDouble(_Symbol, SYMBOL_BID);

   int score = 0;

   if(isBuy)
     {
      if(emaFast[0]   > emaMid[0])    score += 3;
      if(emaMid[0]    > emaSlow[0])   score += 3;
      if(emaSlow[0]   > emaMaster[0]) score += 4;
      if(price        > emaMaster[0]) score += 5;
     }
   else
     {
      if(emaFast[0]   < emaMid[0])    score += 3;
      if(emaMid[0]    < emaSlow[0])   score += 3;
      if(emaSlow[0]   < emaMaster[0]) score += 4;
      if(price        < emaMaster[0]) score += 5;
     }

   // Max = 15 points
   return(score);
  }

//+------------------------------------------------------------------+
//|              LAYER 3: MACD + RSI + ADX CHECK                      |
//+------------------------------------------------------------------+
int CheckMomentumLayer(bool isBuy)
  {
   double macdMain[2], macdSignal[2], macdHist[2];
   double rsiVal[2];
   double adxMain[2], adxPlus[2], adxMinus[2];

   if(CopyBuffer(g_handleMACD, 0, 0, 2, macdMain)   < 2) return 0;
   if(CopyBuffer(g_handleMACD, 1, 0, 2, macdSignal) < 2) return 0;
   if(CopyBuffer(g_handleMACD, 2, 0, 2, macdHist)   < 2) return 0;
   if(CopyBuffer(g_handleRSI,  0, 0, 2, rsiVal)     < 2) return 0;
   if(CopyBuffer(g_handleADX,  0, 0, 2, adxMain)    < 2) return 0;
   if(CopyBuffer(g_handleADX,  1, 0, 2, adxPlus)    < 2) return 0;
   if(CopyBuffer(g_handleADX,  2, 0, 2, adxMinus)   < 2) return 0;

   int score = 0;

   // ADX check: if below threshold, market is ranging — heavy penalty
   if(adxMain[0] < InpADXMinStrength) return(0);

   if(isBuy)
     {
      // MACD
      if(macdMain[0] > macdSignal[0])   score += 4;
      if(macdHist[0] > 0)               score += 2;
      if(macdHist[0] > macdHist[1])     score += 2; // Expanding histogram
      // RSI
      if(rsiVal[0] >= InpRSIBuyMin && rsiVal[0] <= InpRSIBuyMax) score += 4;
      // ADX directional
      if(adxPlus[0] > adxMinus[0])      score += 3;
     }
   else
     {
      // MACD
      if(macdMain[0] < macdSignal[0])   score += 4;
      if(macdHist[0] < 0)               score += 2;
      if(macdHist[0] < macdHist[1])     score += 2; // Expanding histogram
      // RSI
      if(rsiVal[0] >= InpRSISellMin && rsiVal[0] <= InpRSISellMax) score += 4;
      // ADX directional
      if(adxMinus[0] > adxPlus[0])      score += 3;
     }

   // Max = 15 points
   return(MathMin(score, 15));
  }

//+------------------------------------------------------------------+
//|              LAYER 4A: VWAP UPDATE                                |
//+------------------------------------------------------------------+
void UpdateVWAP()
  {
   datetime now = TimeCurrent();
   MqlDateTime dt;
   TimeToStruct(now, dt);

   // Reset VWAP daily at midnight
   datetime todayMidnight = now - (dt.hour * 3600 + dt.min * 60 + dt.sec);
   if(g_vwapLastReset < todayMidnight)
     {
      g_vwapCumVol    = 0;
      g_vwapCumTP     = 0;
      g_vwapLastReset = todayMidnight;
     }

   double high[1], low[1], close[1], vol[1];
   if(CopyHigh(_Symbol,    PERIOD_M1, 0, 1, high)  < 1) return;
   if(CopyLow(_Symbol,     PERIOD_M1, 0, 1, low)   < 1) return;
   if(CopyClose(_Symbol,   PERIOD_M1, 0, 1, close) < 1) return;
   if(CopyTickVolume(_Symbol, PERIOD_M1, 0, 1, (long&)vol) < 1)
     {
      vol[0] = 1;
     }

   double typicalPrice = (high[0] + low[0] + close[0]) / 3.0;
   g_vwapCumTP  += typicalPrice * vol[0];
   g_vwapCumVol += vol[0];
   g_vwapValue   = (g_vwapCumVol > 0) ? g_vwapCumTP / g_vwapCumVol : close[0];
  }

//+------------------------------------------------------------------+
//|              LAYER 4B: VWAP SCORE                                 |
//+------------------------------------------------------------------+
int CheckVWAPLayer(bool isBuy)
  {
   if(!InpUseVWAP || g_vwapValue == 0) return(5); // Neutral score if disabled
   double price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   int score = 0;

   if(isBuy  && price > g_vwapValue) score = 10;
   if(!isBuy && price < g_vwapValue) score = 10;

   // Kill zone bonus
   if(IsActiveSession()) score += 5;

   return(MathMin(score, 15)); // Max 15 (10 VWAP + 5 session)
  }

//+------------------------------------------------------------------+
//|              LAYER 5: ADAPTIVE SUPERTREND                         |
//+------------------------------------------------------------------+
int CheckSuperTrendLayer(bool isBuy)
  {
   // Compute SuperTrend manually using ATR
   double highArr[], lowArr[], closeArr[];
   ArraySetAsSeries(highArr,  true);
   ArraySetAsSeries(lowArr,   true);
   ArraySetAsSeries(closeArr, true);

   int lookback = InpSTPeriod * 3;
   if(CopyHigh(_Symbol,  InpSTTF, 0, lookback, highArr)  < lookback) return 0;
   if(CopyLow(_Symbol,   InpSTTF, 0, lookback, lowArr)   < lookback) return 0;
   if(CopyClose(_Symbol, InpSTTF, 0, lookback, closeArr) < lookback) return 0;

   // Calculate ATR for SuperTrend
   double atrValues[];
   ArrayResize(atrValues, lookback);
   ArraySetAsSeries(atrValues, true);

   for(int i = 1; i < lookback - 1; i++)
     {
      double hl  = highArr[i] - lowArr[i];
      double hpc = MathAbs(highArr[i] - closeArr[i+1]);
      double lpc = MathAbs(lowArr[i]  - closeArr[i+1]);
      atrValues[i] = MathMax(hl, MathMax(hpc, lpc));
     }

   // Smooth ATR (SMA)
   double atr = 0;
   for(int i = 1; i <= InpSTPeriod; i++)
      atr += atrValues[i];
   atr /= InpSTPeriod;

   // SuperTrend bands
   double hl2       = (highArr[1] + lowArr[1]) / 2.0;
   double upperBand = hl2 + InpSTMultiplier * atr;
   double lowerBand = hl2 - InpSTMultiplier * atr;
   double prevClose = closeArr[2];
   double currClose = closeArr[1];

   bool stBullish = (prevClose < upperBand && currClose > lowerBand);
   bool stBearish = (prevClose > lowerBand && currClose < upperBand);

   if(isBuy  && stBullish) return(10);
   if(!isBuy && stBearish) return(10);
   return(0);
  }

//+------------------------------------------------------------------+
//|              LAYER 6: FIBONACCI OTE CHECK                         |
//+------------------------------------------------------------------+
int CheckFibonacciLayer(bool isBuy)
  {
   double highArr[], lowArr[];
   ArraySetAsSeries(highArr, true);
   ArraySetAsSeries(lowArr,  true);

   int lookback = InpFibSwingLookback;
   if(CopyHigh(_Symbol, PERIOD_CURRENT, 0, lookback, highArr) < lookback) return 0;
   if(CopyLow(_Symbol,  PERIOD_CURRENT, 0, lookback, lowArr)  < lookback) return 0;

   // Find swing high and swing low
   double swingHigh = highArr[0];
   double swingLow  = lowArr[0];
   for(int i = 0; i < lookback; i++)
     {
      swingHigh = MathMax(swingHigh, highArr[i]);
      swingLow  = MathMin(swingLow,  lowArr[i]);
     }

   double range = swingHigh - swingLow;
   if(range <= 0) return(0);

   double price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double retracement;

   if(isBuy)
     {
      // Bullish: price retraces from high to low, OTE = 61.8–78.6% of range
      retracement = (swingHigh - price) / range;
     }
   else
     {
      // Bearish: price retraces from low to high, OTE = 61.8–78.6% of range
      retracement = (price - swingLow) / range;
     }

   if(retracement >= InpFibOTELow && retracement <= InpFibOTEHigh)
      return(15); // In OTE zone
   if(retracement >= 0.5 && retracement < InpFibOTELow)
      return(8);  // At 50% — secondary
   return(0);
  }

//+------------------------------------------------------------------+
//|              LAYER 7: SPREAD + NEWS CHECK                         |
//+------------------------------------------------------------------+
bool IsSpreadOK()
  {
   double spread = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   bool   isGold = (StringFind(_Symbol, "XAU") >= 0 ||
                    StringFind(_Symbol, "GOLD") >= 0);
   double maxSpread = isGold ? InpMaxSpreadGold : InpMaxSpreadForex;
   return(spread <= maxSpread);
  }

// Simple time-based news filter (blocks known high-impact windows)
bool IsNearHighImpactNews()
  {
   if(!InpUseNewsFilter) return(false);

   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);

   int hour = dt.hour;
   int min  = dt.min;
   int dayOfWeek = dt.day_of_week;

   // NFP — First Friday 12:30 GMT
   if(dayOfWeek == 5 && hour == 12 && min >= 0 && min <= 60)
      return(true);

   // Common high-impact news windows (GMT)
   // FOMC 18:00 | CPI 12:30 | GDP 12:30 | Retail 12:30
   if((hour == 12 && min >= 20 && min <= 60) ||
      (hour == 13 && min <=  5))
      return(true);

   if((hour == 17 && min >= 45) ||
      (hour == 18 && min <= 30))
      return(true);

   // ECB / BOE 11:00-12:30 GMT
   if((hour == 11 && min >= 45) ||
      (hour == 12 && min <=  0))
      return(true);

   return(false);
  }

int CheckNewsSpreadLayer()
  {
   bool spreadOK = IsSpreadOK();
   bool newsOK   = !IsNearHighImpactNews();

   if(spreadOK && newsOK) return(10);
   if(!newsOK) return(-20); // Heavy penalty for news proximity
   return(0);
  }

//+------------------------------------------------------------------+
//|              LAYER 8: ATR RISK VALIDITY                           |
//+------------------------------------------------------------------+
void UpdateATR()
  {
   double atrBuf[1];
   if(CopyBuffer(g_handleATR, 0, 0, 1, atrBuf) < 1) return;
   g_currentATR = atrBuf[0];
  }

double CalculateLotSize(double slPoints)
  {
   double balance  = AccountInfoDouble(ACCOUNT_BALANCE);
   double riskPct  = InpRiskPercent;

   // Prop firm mode: reduce risk when DD > 3%
   if(InpPropFirmMode)
     {
      double currentDD = (g_totalStartBalance - balance) / g_totalStartBalance * 100.0;
      if(currentDD > 3.0) riskPct = 0.5;
     }

   // Scale lot by AI score
   if(InpDynamicLotSize)
     {
      if(g_aiScore >= InpMinScoreFull)   riskPct *= 1.00;
      else if(g_aiScore >= 80)            riskPct *= 0.75;
      else if(g_aiScore >= 70)            riskPct *= 0.50;
      else                                riskPct *= 0.25;
     }

   double riskAmount  = balance * (riskPct / 100.0);
   double tickValue   = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double tickSize    = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   double pointValue  = tickValue / tickSize;

   if(slPoints <= 0 || pointValue <= 0) return(0.01);

   double lotSize = riskAmount / (slPoints * pointValue);

   double minLot  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxLot  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double stepLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);

   lotSize = MathFloor(lotSize / stepLot) * stepLot;
   lotSize = MathMax(minLot, MathMin(maxLot, lotSize));

   return(NormalizeDouble(lotSize, 2));
  }

int CheckATRRRLayer(double slDistance)
  {
   if(g_currentATR <= 0) return(0);
   double tp2Distance = InpATRTP2Mult * g_currentATR;
   double rr = tp2Distance / slDistance;
   if(rr >= 2.0) return(5);
   return(0);
  }

//+------------------------------------------------------------------+
//|              LAYER 9: AI CONFLUENCE SCORING ENGINE                |
//+------------------------------------------------------------------+
SScoreCard ComputeAIScore()
  {
   SScoreCard card;
   ZeroMemory(card);

   // Determine bias first
   ENUM_BIAS msBias = DetectMarketStructure();
   g_currentBias    = msBias;

   if(msBias == BIAS_NONE)
     {
      // No clear bias — skip scoring
      card.totalScore = 0;
      card.grade      = GRADE_NONE;
      return(card);
     }

   bool isBuy = (msBias == BIAS_BULLISH);

   // ── Layer 1: ICT Score (max 20) ───────────────────────────────
   bool inZone    = PriceInICTZone(isBuy);
   bool liqSweep  = InpRequireLiqSweep ? DetectLiquiditySweep(isBuy) : true;
   bool fvgExists = false;
   bool obExists  = false;
   bool unicorn   = false;

   for(int i = 0; i < ArraySize(g_orderBlocks); i++)
      if(g_orderBlocks[i].active && g_orderBlocks[i].bullish == isBuy)
        {
         obExists = true; break;
        }
   for(int i = 0; i < ArraySize(g_fvgZones); i++)
      if(g_fvgZones[i].active && g_fvgZones[i].bullish == isBuy)
        {
         fvgExists = true; break;
        }

   unicorn = (obExists && fvgExists && inZone);

   if(unicorn && liqSweep)      card.ictScore = 20;
   else if(unicorn)             card.ictScore = 15;
   else if(inZone && liqSweep)  card.ictScore = 15;
   else if(obExists && fvgExists) card.ictScore = 10;
   else if(inZone)              card.ictScore = 8;
   else                         card.ictScore = 0;

   // ── Layer 2: EMA Score (max 15) ───────────────────────────────
   if(InpUseEMA) card.emaScore = CheckEMALayer(isBuy);

   // ── Layer 3: Momentum Score (max 15) ──────────────────────────
   if(InpUseMACD && InpUseRSI && InpUseADX)
      card.momentumScore = CheckMomentumLayer(isBuy);

   // ── Layer 4: VWAP+Session Score (max 15) ──────────────────────
   card.vwapScore = CheckVWAPLayer(isBuy);

   // ── Layer 5: SuperTrend Score (max 10) ────────────────────────
   if(InpUseSuperTrend)
      card.superTrendScore = CheckSuperTrendLayer(isBuy);

   // ── Layer 6: Fibonacci OTE Score (max 15) ─────────────────────
   if(InpUseFibonacci)
      card.fibScore = CheckFibonacciLayer(isBuy);

   // ── Layer 7: News + Spread Score (max 10, min -20) ────────────
   card.newsSpreadScore = CheckNewsSpreadLayer();

   // ── Layer 8: ATR RR Score (max 5) ─────────────────────────────
   double slDist = InpATRSLMult * g_currentATR;
   if(InpUseATRRisk && slDist > 0)
      card.atrRRScore = CheckATRRRLayer(slDist);

   // ── Total Score ───────────────────────────────────────────────
   int total = card.ictScore      +
               card.emaScore      +
               card.momentumScore +
               card.vwapScore     +
               card.superTrendScore +
               card.fibScore      +
               card.newsSpreadScore +
               card.atrRRScore;

   card.totalScore = MathMax(0, MathMin(100, total));

   // ── Grade ─────────────────────────────────────────────────────
   if(card.totalScore >= 90)      card.grade = GRADE_APEX;
   else if(card.totalScore >= 80) card.grade = GRADE_ELITE;
   else if(card.totalScore >= 70) card.grade = GRADE_STANDARD;
   else if(card.totalScore >= 60) card.grade = GRADE_WEAK;
   else                           card.grade = GRADE_NONE;

   return(card);
  }

//+------------------------------------------------------------------+
//|              TRADE EXECUTION ENGINE                               |
//+------------------------------------------------------------------+
void ExecuteTrade(SScoreCard &scoreCard)
  {
   if(scoreCard.totalScore < InpMinScoreTrade) return;
   if(g_currentBias == BIAS_NONE) return;

   bool isBuy = (g_currentBias == BIAS_BULLISH);

   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double price = isBuy ? ask : bid;

   // Calculate SL and TPs using ATR
   double atr = g_currentATR;
   if(atr <= 0) return;

   double slDist  = InpATRSLMult  * atr;
   double tp1Dist = InpATRTP1Mult * atr;
   double tp2Dist = InpATRTP2Mult * atr;

   double sl, tp1, tp2;
   if(isBuy)
     {
      sl  = price - slDist;
      tp1 = price + tp1Dist;
      tp2 = price + tp2Dist;
     }
   else
     {
      sl  = price + slDist;
      tp1 = price - tp1Dist;
      tp2 = price - tp2Dist;
     }

   int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   sl  = NormalizeDouble(sl,  digits);
   tp1 = NormalizeDouble(tp1, digits);
   tp2 = NormalizeDouble(tp2, digits);

   // Validate SL minimum distance
   double minSL = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL) *
                  SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(MathAbs(price - sl) < minSL)
      sl = isBuy ? price - minSL * 1.5 : price + minSL * 1.5;

   // Calculate lot size
   double lot = CalculateLotSize(slDist / SymbolInfoDouble(_Symbol, SYMBOL_POINT));
   if(lot <= 0) return;

   // Build comment
   string comment = StringFormat("QAPEX|Score:%d|Grade:%d|ATR:%.5f",
                                  scoreCard.totalScore, (int)scoreCard.grade, atr);

   // Place order
   bool result = false;
   if(isBuy)
      result = trade.Buy(lot, _Symbol, 0, sl, tp2, comment);
   else
      result = trade.Sell(lot, _Symbol, 0, sl, tp2, comment);

   if(result)
     {
      ulong ticket = trade.ResultOrder();

      // Register trade levels for partial close management
      STradeLevel tl;
      tl.ticket    = ticket;
      tl.tp1Price  = tp1;
      tl.tp2Price  = tp2;
      tl.tp1Hit    = false;
      tl.tp2Hit    = false;
      tl.beSet     = false;
      tl.entryPrice = price;
      tl.atrAtEntry = atr;
      tl.isBuy     = isBuy;

      int sz = ArraySize(g_tradeLevels);
      ArrayResize(g_tradeLevels, sz + 1);
      g_tradeLevels[sz] = tl;

      g_lastTradeTime = TimeCurrent();

      string gradeStr = GetGradeString(scoreCard.grade);
      Print("=== QUANTUM APEX TRADE OPENED ===");
      Print("Direction: ", (isBuy ? "BUY" : "SELL"),
            " | Lot: ",   lot,
            " | Score: ", scoreCard.totalScore,
            " | Grade: ", gradeStr);
      Print("SL: ", sl, " | TP1: ", tp1, " | TP2: ", tp2);

      if(InpEnableAlerts)
         Alert("QUANTUM APEX: ", (isBuy ? "BUY" : "SELL"),
               " | ", _Symbol, " | Score: ", scoreCard.totalScore,
               " | Grade: ", gradeStr);

      if(InpEnableLogging)
         LogTrade(ticket, isBuy, lot, price, sl, tp1, tp2, scoreCard);
     }
   else
     {
      Print("QUANTUM APEX: Trade failed. Error: ", GetLastError(),
            " | ", trade.ResultRetcodeDescription());
     }
  }

//+------------------------------------------------------------------+
//|              TRADE MANAGEMENT ENGINE                              |
//+------------------------------------------------------------------+
void ManageOpenTrades()
  {
   int count = ArraySize(g_tradeLevels);
   if(count == 0) return;

   for(int i = count - 1; i >= 0; i--)
     {
      STradeLevel &tl = g_tradeLevels[i];

      // Check if position still open
      if(!posInfo.SelectByTicket(tl.ticket)) continue;
      if(posInfo.Magic() != InpMagicNumber)  continue;

      double currentPrice = tl.isBuy ?
                            SymbolInfoDouble(_Symbol, SYMBOL_BID) :
                            SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      double entryPrice = posInfo.PriceOpen();
      double currentSL  = posInfo.StopLoss();
      double atr        = g_currentATR;

      // ── Partial Close at TP1 ─────────────────────────────────
      if(!tl.tp1Hit && InpScaleOutPartials)
        {
         bool tp1Reached = tl.isBuy ? (currentPrice >= tl.tp1Price) :
                                      (currentPrice <= tl.tp1Price);
         if(tp1Reached)
           {
            double posVol    = posInfo.Volume();
            double closeVol  = NormalizeDouble(posVol * 0.25, 2);
            double minLot    = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
            if(closeVol < minLot) closeVol = minLot;
            if(closeVol <= posVol)
              {
               if(trade.PositionClosePartial(tl.ticket, closeVol))
                 {
                  tl.tp1Hit = true;
                  Print("QUANTUM APEX: TP1 Partial close (25%) | Ticket: ", tl.ticket);

                  // Move SL to break-even
                  if(!tl.beSet)
                    {
                     double beSL = tl.isBuy ? entryPrice + _Point * 5 :
                                              entryPrice - _Point * 5;
                     if(trade.PositionModify(tl.ticket, beSL, posInfo.TakeProfit()))
                       {
                        tl.beSet = true;
                        Print("QUANTUM APEX: Break-even set | Ticket: ", tl.ticket);
                       }
                    }
                 }
              }
           }
        }

      // ── Partial Close at TP2 ─────────────────────────────────
      if(tl.tp1Hit && !tl.tp2Hit && InpScaleOutPartials)
        {
         bool tp2Reached = tl.isBuy ? (currentPrice >= tl.tp2Price) :
                                      (currentPrice <= tl.tp2Price);
         if(tp2Reached)
           {
            double posVol   = posInfo.Volume();
            double closeVol = NormalizeDouble(posVol * 0.667, 2);
            double minLot   = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
            if(closeVol < minLot) closeVol = minLot;
            if(closeVol <= posVol)
              {
               if(trade.PositionClosePartial(tl.ticket, closeVol))
                 {
                  tl.tp2Hit = true;
                  Print("QUANTUM APEX: TP2 Partial close (50%) | Ticket: ", tl.ticket);
                 }
              }
           }
        }

      // ── Adaptive Trailing Stop ────────────────────────────────
      if(tl.beSet && atr > 0)
        {
         double trailDist    = InpATRTrailMult    * atr;
         double activateDist = InpTrailActivation * atr;

         double profitDist = tl.isBuy ?
                             (currentPrice - entryPrice) :
                             (entryPrice  - currentPrice);

         if(profitDist >= activateDist)
           {
            double newSL;
            if(tl.isBuy)
              {
               newSL = currentPrice - trailDist;
               if(newSL > currentSL + _Point)
                  trade.PositionModify(tl.ticket, newSL, posInfo.TakeProfit());
              }
            else
              {
               newSL = currentPrice + trailDist;
               if(newSL < currentSL - _Point || currentSL == 0)
                  trade.PositionModify(tl.ticket, newSL, posInfo.TakeProfit());
              }
           }
        }
     }

   // Cleanup closed positions from array
   CleanupTradeLevels();
  }

//+------------------------------------------------------------------+
//|              CLEANUP CLOSED TRADES FROM ARRAY                     |
//+------------------------------------------------------------------+
void CleanupTradeLevels()
  {
   int count = ArraySize(g_tradeLevels);
   for(int i = count - 1; i >= 0; i--)
     {
      if(!posInfo.SelectByTicket(g_tradeLevels[i].ticket))
        {
         // Position closed — check result for consecutive loss tracking
         // and remove from array
         if(HistoryOrderSelect(g_tradeLevels[i].ticket))
           {
            double profit = HistoryOrderGetDouble(g_tradeLevels[i].ticket,
                                                   ORDER_PROFIT);
            if(profit < 0)
               g_consecutiveLosses++;
            else
               g_consecutiveLosses = 0;

            // Cooling period after 3 consecutive losses
            if(g_consecutiveLosses >= 3)
              {
               g_coolingPeriodEnd = TimeCurrent() + 86400; // 24 hours
               g_consecutiveLosses = 0;
               Print("QUANTUM APEX: 3 consecutive losses. 24hr cooling period activated.");
               if(InpEnableAlerts)
                  Alert("QUANTUM APEX: Cooling period activated — 24hr trading halt.");
              }
           }

         // Remove element from array
         for(int j = i; j < count - 1; j++)
            g_tradeLevels[j] = g_tradeLevels[j+1];
         ArrayResize(g_tradeLevels, count - 1);
         count--;
        }
     }
  }

//+------------------------------------------------------------------+
//|              RISK LIMIT CHECKS                                    |
//+------------------------------------------------------------------+
bool CheckRiskLimits()
  {
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double equity  = AccountInfoDouble(ACCOUNT_EQUITY);

   // Daily drawdown check
   double dailyDD = (g_dailyStartBalance - equity) / g_dailyStartBalance * 100.0;
   if(dailyDD >= InpMaxDailyDD)
     {
      if(!g_dailyHaltActive)
        {
         g_dailyHaltActive = true;
         Print("QUANTUM APEX: Daily DD limit reached (", NormalizeDouble(dailyDD, 2),
               "%). Trading halted for today.");
         if(InpEnableAlerts)
            Alert("QUANTUM APEX: Daily DD limit reached! Trading halted.");
        }
      return(false);
     }

   // Total drawdown check
   double totalDD = (g_totalStartBalance - equity) / g_totalStartBalance * 100.0;
   if(totalDD >= InpMaxTotalDD)
     {
      Print("QUANTUM APEX: Total DD limit reached (", NormalizeDouble(totalDD, 2),
            "%). EA fully halted.");
      if(InpEnableAlerts)
         Alert("QUANTUM APEX: Total DD limit reached! EA halted.");
      ExpertRemove();
      return(false);
     }

   // Cooling period check
   if(TimeCurrent() < g_coolingPeriodEnd)
     {
      return(false);
     }

   // Reset daily balance at start of new day
   static datetime lastDayReset = 0;
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   datetime todayMidnight = TimeCurrent() - (dt.hour*3600 + dt.min*60 + dt.sec);
   if(todayMidnight > lastDayReset)
     {
      g_dailyStartBalance = AccountInfoDouble(ACCOUNT_BALANCE);
      g_dailyHaltActive   = false;
      lastDayReset        = todayMidnight;
     }

   return(true);
  }

//+------------------------------------------------------------------+
//|              SESSION FILTER                                       |
//+------------------------------------------------------------------+
bool IsActiveSession()
  {
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   int hour = dt.hour;
   int min  = dt.min;

   // Convert to fractional hours
   double fracHour = hour + min / 60.0;

   bool londonOpen = (fracHour >= InpLondonStart && fracHour < InpLondonEnd);
   bool nyOpen     = (fracHour >= InpNYStart     && fracHour < InpNYEnd);
   bool overlap    = InpAllowOverlap &&
                     (fracHour >= InpNYStart && fracHour < InpLondonEnd);

   return(londonOpen || nyOpen || overlap);
  }

//+------------------------------------------------------------------+
//|              COUNT OPEN TRADES                                    |
//+------------------------------------------------------------------+
int CountOpenTrades()
  {
   int count = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      if(posInfo.SelectByIndex(i))
         if(posInfo.Magic() == InpMagicNumber && posInfo.Symbol() == _Symbol)
            count++;
     }
   return(count);
  }

//+------------------------------------------------------------------+
//|              TRADE LOGGING                                        |
//+------------------------------------------------------------------+
void LogTrade(ulong ticket, bool isBuy, double lot,
              double price, double sl, double tp1, double tp2,
              SScoreCard &sc)
  {
   string filename = "QuantumAPEX_TradeLog.csv";
   int    handle   = FileOpen(filename, FILE_WRITE | FILE_READ | FILE_CSV | FILE_SHARE_READ);
   if(handle == INVALID_HANDLE)
     {
      handle = FileOpen(filename, FILE_WRITE | FILE_CSV);
      // Write header
      FileWrite(handle,
                "Timestamp", "Symbol", "Direction", "Lot",
                "EntryPrice", "SL", "TP1", "TP2",
                "AIScore", "Grade",
                "ICT", "EMA", "Momentum", "VWAP",
                "SuperTrend", "Fibonacci", "News", "ATR_RR",
                "ATR_Value");
     }
   else
     {
      FileSeek(handle, 0, SEEK_END);
     }

   FileWrite(handle,
             TimeToString(TimeCurrent(), TIME_DATE | TIME_MINUTES),
             _Symbol,
             (isBuy ? "BUY" : "SELL"),
             DoubleToString(lot, 2),
             DoubleToString(price, _Digits),
             DoubleToString(sl,    _Digits),
             DoubleToString(tp1,   _Digits),
             DoubleToString(tp2,   _Digits),
             IntegerToString(sc.totalScore),
             GetGradeString(sc.grade),
             IntegerToString(sc.ictScore),
             IntegerToString(sc.emaScore),
             IntegerToString(sc.momentumScore),
             IntegerToString(sc.vwapScore),
             IntegerToString(sc.superTrendScore),
             IntegerToString(sc.fibScore),
             IntegerToString(sc.newsSpreadScore),
             IntegerToString(sc.atrRRScore),
             DoubleToString(g_currentATR, _Digits));

   FileClose(handle);
  }

//+------------------------------------------------------------------+
//|              HELPER: GET GRADE STRING                             |
//+------------------------------------------------------------------+
string GetGradeString(ENUM_SIGNAL_GRADE grade)
  {
   switch(grade)
     {
      case GRADE_APEX:     return("⭐ APEX");
      case GRADE_ELITE:    return("🔥 ELITE");
      case GRADE_STANDARD: return("✅ STANDARD");
      case GRADE_WEAK:     return("⚠️ WEAK");
      default:             return("❌ NONE");
     }
  }

//+------------------------------------------------------------------+
//|              DRAW ORDER BLOCK ZONE                                |
//+------------------------------------------------------------------+
void DrawOBZone(SOrderBlock &ob, int idx)
  {
   string name = "QA_OB_" + IntegerToString(idx);
   color  clr  = ob.bullish ? InpBullishColor : InpBearishColor;

   ObjectCreate(0, name, OBJ_RECTANGLE, 0, ob.time, ob.high, TimeCurrent(), ob.low);
   ObjectSetInteger(0, name, OBJPROP_COLOR,   clr);
   ObjectSetInteger(0, name, OBJPROP_STYLE,   STYLE_SOLID);
   ObjectSetInteger(0, name, OBJPROP_WIDTH,   1);
   ObjectSetInteger(0, name, OBJPROP_FILL,    true);
   ObjectSetInteger(0, name, OBJPROP_BACK,    true);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);

   // Label
   string lblName = "QA_OBL_" + IntegerToString(idx);
   ObjectCreate(0, lblName, OBJ_TEXT, 0, ob.time, ob.high);
   ObjectSetString(0, lblName, OBJPROP_TEXT, ob.bullish ? "Bull OB" : "Bear OB");
   ObjectSetInteger(0, lblName, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, lblName, OBJPROP_FONTSIZE, 7);
  }

//+------------------------------------------------------------------+
//|              DRAW FVG ZONE                                        |
//+------------------------------------------------------------------+
void DrawFVGZone(SFVG &fvg, int idx)
  {
   string name = "QA_FVG_" + IntegerToString(idx);
   color  clr  = fvg.bullish ? clrLightSkyBlue : clrLightCoral;

   ObjectCreate(0, name, OBJ_RECTANGLE, 0, fvg.time, fvg.top, TimeCurrent(), fvg.bottom);
   ObjectSetInteger(0, name, OBJPROP_COLOR,   clr);
   ObjectSetInteger(0, name, OBJPROP_STYLE,   STYLE_DOT);
   ObjectSetInteger(0, name, OBJPROP_WIDTH,   1);
   ObjectSetInteger(0, name, OBJPROP_FILL,    true);
   ObjectSetInteger(0, name, OBJPROP_BACK,    true);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);

   string lblName = "QA_FVGL_" + IntegerToString(idx);
   ObjectCreate(0, lblName, OBJ_TEXT, 0, fvg.time, fvg.top);
   ObjectSetString(0, lblName, OBJPROP_TEXT, fvg.bullish ? "Bull FVG" : "Bear FVG");
   ObjectSetInteger(0, lblName, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, lblName, OBJPROP_FONTSIZE, 7);
  }

//+------------------------------------------------------------------+
//|              DASHBOARD — INITIAL DRAW                             |
//+------------------------------------------------------------------+
void DrawDashboard()
  {
   int x = 10, y = 20;
   int w = 320, lh = 18;

   // Background panel
   CreateRect("QA_BG", x-5, y-5, w+10, lh*22+10, C'20,20,30', true);

   // Title
   CreateLabel("QA_Title",    x,      y,      "QUANTUM APEX v3.0  |  " + _Symbol, clrGold, 10, true);
   CreateLabel("QA_Subtitle", x,      y+lh,   "9-Layer Institutional Confluence Engine", clrSilver, 8);

   CreateLabel("QA_Sep1",     x, y+lh*2, "─────────────────────────────────", InpNeutralColor, 8);

   // Score
   CreateLabel("QA_Score_Lbl", x,      y+lh*3, "AI CONFLUENCE SCORE:", clrWhite,  9, true);
   CreateLabel("QA_Score_Val", x+190,  y+lh*3, "0/100", clrYellow, 9, true);
   CreateLabel("QA_Grade_Lbl", x,      y+lh*4, "SIGNAL GRADE:", clrWhite, 9, true);
   CreateLabel("QA_Grade_Val", x+190,  y+lh*4, "—", InpNeutralColor, 9, true);
   CreateLabel("QA_Bias_Lbl",  x,      y+lh*5, "TRADE BIAS:", clrWhite, 9, true);
   CreateLabel("QA_Bias_Val",  x+190,  y+lh*5, "—", InpNeutralColor, 9, true);

   CreateLabel("QA_Sep2", x, y+lh*6, "─────────────────────────────────", InpNeutralColor, 8);

   // Layer rows
   CreateLabel("QA_L1_Lbl",   x,     y+lh*7,  "Layer 1 | ICT/SMC:",      clrWhite, 8);
   CreateLabel("QA_L1_Val",   x+190, y+lh*7,  "—", InpNeutralColor, 8);
   CreateLabel("QA_L2_Lbl",   x,     y+lh*8,  "Layer 2 | EMA Stack:",     clrWhite, 8);
   CreateLabel("QA_L2_Val",   x+190, y+lh*8,  "—", InpNeutralColor, 8);
   CreateLabel("QA_L3_Lbl",   x,     y+lh*9,  "Layer 3 | MACD+RSI+ADX:", clrWhite, 8);
   CreateLabel("QA_L3_Val",   x+190, y+lh*9,  "—", InpNeutralColor, 8);
   CreateLabel("QA_L4_Lbl",   x,     y+lh*10, "Layer 4 | VWAP+Session:",  clrWhite, 8);
   CreateLabel("QA_L4_Val",   x+190, y+lh*10, "—", InpNeutralColor, 8);
   CreateLabel("QA_L5_Lbl",   x,     y+lh*11, "Layer 5 | SuperTrend:",    clrWhite, 8);
   CreateLabel("QA_L5_Val",   x+190, y+lh*11, "—", InpNeutralColor, 8);
   CreateLabel("QA_L6_Lbl",   x,     y+lh*12, "Layer 6 | Fib OTE:",       clrWhite, 8);
   CreateLabel("QA_L6_Val",   x+190, y+lh*12, "—", InpNeutralColor, 8);
   CreateLabel("QA_L7_Lbl",   x,     y+lh*13, "Layer 7 | News+Spread:",   clrWhite, 8);
   CreateLabel("QA_L7_Val",   x+190, y+lh*13, "—", InpNeutralColor, 8);
   CreateLabel("QA_L8_Lbl",   x,     y+lh*14, "Layer 8 | ATR Risk RR:",   clrWhite, 8);
   CreateLabel("QA_L8_Val",   x+190, y+lh*14, "—", InpNeutralColor, 8);

   CreateLabel("QA_Sep3", x, y+lh*15, "─────────────────────────────────", InpNeutralColor, 8);

   // Live data
   CreateLabel("QA_Sess_Lbl",  x,     y+lh*16, "SESSION:",    clrWhite, 8);
   CreateLabel("QA_Sess_Val",  x+190, y+lh*16, "—", InpNeutralColor, 8);
   CreateLabel("QA_Spr_Lbl",   x,     y+lh*17, "SPREAD:",     clrWhite, 8);
   CreateLabel("QA_Spr_Val",   x+190, y+lh*17, "—", InpNeutralColor, 8);
   CreateLabel("QA_ATR_Lbl",   x,     y+lh*18, "ATR:",        clrWhite, 8);
   CreateLabel("QA_ATR_Val",   x+190, y+lh*18, "—", InpNeutralColor, 8);
   CreateLabel("QA_DD_Lbl",    x,     y+lh*19, "DAILY DD:",   clrWhite, 8);
   CreateLabel("QA_DD_Val",    x+190, y+lh*19, "—", InpNeutralColor, 8);
   CreateLabel("QA_Trades_Lbl",x,     y+lh*20, "OPEN TRADES:",clrWhite, 8);
   CreateLabel("QA_Trades_Val",x+190, y+lh*20, "—", InpNeutralColor, 8);

   ChartRedraw();
  }

//+------------------------------------------------------------------+
//|              DASHBOARD — UPDATE                                   |
//+------------------------------------------------------------------+
void UpdateDashboard(SScoreCard &sc)
  {
   // Score and grade
   string scoreStr = IntegerToString(sc.totalScore) + "/100";
   ObjectSetString(0, "QA_Score_Val", OBJPROP_TEXT, scoreStr);
   color scoreColor = sc.totalScore >= 80 ? clrLime :
                      sc.totalScore >= 70 ? clrYellow : clrOrangeRed;
   ObjectSetInteger(0, "QA_Score_Val", OBJPROP_COLOR, scoreColor);

   ObjectSetString(0, "QA_Grade_Val", OBJPROP_TEXT, GetGradeString(sc.grade));
   color gradeColor = sc.grade == GRADE_APEX  ? clrGold :
                      sc.grade == GRADE_ELITE ? clrLime :
                      sc.grade == GRADE_STANDARD ? clrYellow : clrOrangeRed;
   ObjectSetInteger(0, "QA_Grade_Val", OBJPROP_COLOR, gradeColor);

   // Bias
   string biasStr = (g_currentBias == BIAS_BULLISH) ? "📈 BULLISH" :
                    (g_currentBias == BIAS_BEARISH) ? "📉 BEARISH" : "— NEUTRAL";
   color biasColor = (g_currentBias == BIAS_BULLISH) ? InpBullishColor :
                     (g_currentBias == BIAS_BEARISH) ? InpBearishColor : InpNeutralColor;
   ObjectSetString(0,  "QA_Bias_Val", OBJPROP_TEXT,  biasStr);
   ObjectSetInteger(0, "QA_Bias_Val", OBJPROP_COLOR, biasColor);

   // Layer scores
   UpdateLayerLabel("QA_L1_Val", sc.ictScore,       20);
   UpdateLayerLabel("QA_L2_Val", sc.emaScore,        15);
   UpdateLayerLabel("QA_L3_Val", sc.momentumScore,   15);
   UpdateLayerLabel("QA_L4_Val", sc.vwapScore,       15);
   UpdateLayerLabel("QA_L5_Val", sc.superTrendScore, 10);
   UpdateLayerLabel("QA_L6_Val", sc.fibScore,        15);
   UpdateLayerLabel("QA_L7_Val", sc.newsSpreadScore, 10);
   UpdateLayerLabel("QA_L8_Val", sc.atrRRScore,       5);

   // Live data
   string sessStr = IsActiveSession() ? "🟢 ACTIVE" : "🔴 INACTIVE";
   ObjectSetString(0, "QA_Sess_Val", OBJPROP_TEXT, sessStr);
   ObjectSetInteger(0, "QA_Sess_Val", OBJPROP_COLOR,
                    IsActiveSession() ? clrLime : clrOrangeRed);

   double spread = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   bool spreadOK = IsSpreadOK();
   ObjectSetString(0,  "QA_Spr_Val", OBJPROP_TEXT,
                   DoubleToString(spread, 0) + " pts " + (spreadOK ? "✅" : "❌"));
   ObjectSetInteger(0, "QA_Spr_Val", OBJPROP_COLOR, spreadOK ? clrLime : clrOrangeRed);

   ObjectSetString(0, "QA_ATR_Val", OBJPROP_TEXT,
                   DoubleToString(g_currentATR, _Digits));
   ObjectSetInteger(0, "QA_ATR_Val", OBJPROP_COLOR, clrWhite);

   double balance  = AccountInfoDouble(ACCOUNT_BALANCE);
   double equity   = AccountInfoDouble(ACCOUNT_EQUITY);
   double dailyDD  = (g_dailyStartBalance > 0) ?
                     (g_dailyStartBalance - equity) / g_dailyStartBalance * 100.0 : 0;
   ObjectSetString(0,  "QA_DD_Val", OBJPROP_TEXT,
                   DoubleToString(NormalizeDouble(dailyDD, 2), 2) + "%");
   ObjectSetInteger(0, "QA_DD_Val", OBJPROP_COLOR,
                    dailyDD < 2.0 ? clrLime : dailyDD < 4.0 ? clrYellow : clrOrangeRed);

   int openTrades = CountOpenTrades();
   ObjectSetString(0, "QA_Trades_Val", OBJPROP_TEXT,
                   IntegerToString(openTrades) + "/" + IntegerToString(InpMaxOpenTrades));

   ChartRedraw();
  }

//+------------------------------------------------------------------+
//|              DASHBOARD HELPER: UPDATE LAYER LABEL                 |
//+------------------------------------------------------------------+
void UpdateLayerLabel(string name, int score, int maxScore)
  {
   string txt;
   color  clr;

   if(score <= 0)
     {
      txt = "❌ 0/" + IntegerToString(maxScore);
      clr = clrOrangeRed;
     }
   else if(score >= maxScore)
     {
      txt = "✅ " + IntegerToString(score) + "/" + IntegerToString(maxScore);
      clr = clrLime;
     }
   else
     {
      txt = "⚠️ " + IntegerToString(score) + "/" + IntegerToString(maxScore);
      clr = clrYellow;
     }

   ObjectSetString(0,  name, OBJPROP_TEXT,  txt);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
  }

//+------------------------------------------------------------------+
//|              OBJECT CREATION HELPERS                              |
//+------------------------------------------------------------------+
void CreateLabel(string name, int x, int y, string text,
                 color clr, int fontSize = 9, bool bold = false)
  {
   if(ObjectFind(0, name) < 0)
      ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);

   ObjectSetInteger(0, name, OBJPROP_XDISTANCE,  x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE,  y);
   ObjectSetString(0,  name, OBJPROP_TEXT,        text);
   ObjectSetInteger(0, name, OBJPROP_COLOR,       clr);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE,    fontSize);
   ObjectSetString(0,  name, OBJPROP_FONT,        bold ? "Arial Bold" : "Arial");
   ObjectSetInteger(0, name, OBJPROP_CORNER,      CORNER_LEFT_UPPER);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE,  false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN,      true);
  }

void CreateRect(string name, int x, int y, int w, int h,
                color clr, bool fill)
  {
   if(ObjectFind(0, name) < 0)
      ObjectCreate(0, name, OBJ_RECTANGLE_LABEL, 0, 0, 0);

   ObjectSetInteger(0, name, OBJPROP_XDISTANCE,  x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE,  y);
   ObjectSetInteger(0, name, OBJPROP_XSIZE,      w);
   ObjectSetInteger(0, name, OBJPROP_YSIZE,      h);
   ObjectSetInteger(0, name, OBJPROP_BGCOLOR,    clr);
   ObjectSetInteger(0, name, OBJPROP_BORDER_TYPE, BORDER_FLAT);
   ObjectSetInteger(0, name, OBJPROP_COLOR,      C'50,50,70');
   ObjectSetInteger(0, name, OBJPROP_CORNER,     CORNER_LEFT_UPPER);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN,     true);
   ObjectSetInteger(0, name, OBJPROP_BACK,       true);
  }

//+------------------------------------------------------------------+
//|              ON TRADE EVENT                                       |
//+------------------------------------------------------------------+
void OnTrade()
  {
   // Refresh trade levels on any trade event
   CleanupTradeLevels();
  }

//+------------------------------------------------------------------+
//|              END OF QUANTUM APEX EA v3.0                          |
//+------------------------------------------------------------------+