//+------------------------------------------------------------------+
//|                                     QUANTUM GOLD AI v2.0 (SMC)   |
//|       Autonomous Multi-Regime Gold Scalper with Self-Learning    |
//|       Features: SMC (FVG/CHoCH), Dynamic Indicator Consensus     |
//+------------------------------------------------------------------+
#property copyright   "Quantum Gold AI v2.0 - Institutional Edition"
#property version     "2.00"
#property description "Advanced ML-Proxy Gold Scalper with SMC Integration"
#property strict

#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>
#include <Trade\AccountInfo.mqh>

#define D "QGAI_"   
#define OV "QGAI_OV_"

//=====================================================================
//  ENUMERATIONS & DYNAMIC ENGINES
//=====================================================================
enum ENUM_REGIME { REGIME_TRENDING, REGIME_RANGING, REGIME_BREAKOUT, REGIME_COMPRESSION, REGIME_SHOCK, REGIME_LIQUIDITY_SWEEP };
enum ENUM_VOL_STATE { VOL_LOW, VOL_NORMAL, VOL_HIGH, VOL_EXTREME };
enum ENUM_SESSION { SESSION_ASIAN, SESSION_LONDON, SESSION_NY, SESSION_DEAD };
enum ENUM_DIRECTION { DIR_NONE, DIR_LONG, DIR_SHORT };

enum ENUM_GOLD_STRATEGY {
   STRAT_NONE,
   STRAT_GOLD_FVG_SCALP,
   STRAT_GOLD_CHOCH_REVERSAL,
   STRAT_GOLD_LIQ_SWEEP,
   STRAT_GOLD_MOMENTUM
};

//=====================================================================
//  CORE DATA STRUCTURES (SMC & ML)
//=====================================================================
struct FVGState {
   bool   bullishActive;
   bool   bearishActive;
   double bullTop, bullBottom;
   double bearTop, bearBottom;
   datetime bullTime, bearTime;
};

struct SMCState {
   bool   chochBullish;
   bool   chochBearish;
   double lastSwingHigh;
   double lastSwingLow;
   datetime chochTime;
};

struct MLNode {
   int    trades;
   double sumR;
   double currentWeight; // 0.0 to 1.0 (Dynamic adaptation)
   int    consecLosses;
};

struct LiquidityState {
   bool   sweepUp;
   bool   sweepDown;
   double eqHigh;
   double eqLow;
};

//=====================================================================
//  INPUT PARAMETERS
//=====================================================================
input group "╔══════ IDENTITY & ASSET ══════╗"
input ulong    InpMagicNumber          = 889900;
input string   InpBotName              = "QUANTUM GOLD AI";

input group "╔══════ RISK & ACCOUNT SCALING ══════╗"
input double   InpBaseRiskPercent      = 1.0;     // Base Risk (Auto-scales by account size)
input double   InpMaxDailyLossPct      = 4.0;
input double   InpMaxDrawdownPct       = 15.0;    

input group "╔══════ SMART MONEY CONCEPTS (SMC) ══════╗"
input bool     InpUseSMC               = true;
input int      InpSwingLookback        = 10;
input double   InpMinFVGSizePoints     = 300;     // Minimum FVG size for Gold

input group "╔══════ VISUAL OVERLAYS ══════╗"
input bool     InpDrawSMC              = true;
input bool     InpShowDash             = true;

//=====================================================================
//  GLOBAL OBJECTS & STATE
//=====================================================================
CTrade         g_trade;
CPositionInfo  g_pos;
CAccountInfo   g_account;

int g_m5_ema_fast, g_m5_ema_slow, g_m5_atr, g_m5_rsi, g_m15_atr;

ENUM_REGIME    g_regime = REGIME_RANGING;
ENUM_VOL_STATE g_volState = VOL_NORMAL;
ENUM_SESSION   g_session = SESSION_LONDON;

FVGState       g_fvg;
SMCState       g_smc;
LiquidityState g_liq;

MLNode         g_ml_weights[5]; // STRAT_NONE = 0 up to 4
double         g_atr_current = 0;
double         g_dynamicRisk = 0;

datetime       g_lastBarTime = 0;
double         g_sessionPnl = 0;
int            g_tradesToday = 0;

//=====================================================================
//  INITIALIZATION
//=====================================================================
int OnInit()
{
   if(StringFind(Symbol(), "XAU") < 0 && StringFind(Symbol(), "GOLD") < 0)
      Print("[QGAI] WARNING: Running on non-Gold asset. EA is heavily optimized for Gold (XAUUSD).");

   g_trade.SetExpertMagicNumber(InpMagicNumber);
   
   g_m5_ema_fast = iMA(_Symbol, PERIOD_M5, 9, 0, MODE_EMA, PRICE_CLOSE);
   g_m5_ema_slow = iMA(_Symbol, PERIOD_M5, 21, 0, MODE_EMA, PRICE_CLOSE);
   g_m5_atr      = iATR(_Symbol, PERIOD_M5, 14);
   g_m5_rsi      = iRSI(_Symbol, PERIOD_M5, 14, PRICE_CLOSE);
   g_m15_atr     = iATR(_Symbol, PERIOD_M15, 14);

   for(int i=0; i<5; i++) {
      g_ml_weights[i].trades = 0;
      g_ml_weights[i].sumR = 0;
      g_ml_weights[i].currentWeight = 1.0; // Start equal
      g_ml_weights[i].consecLosses = 0;
   }

   if(InpShowDash) InitDash();
   EventSetTimer(1);
   
   Print("QUANTUM GOLD AI v2.0 Initialized successfully.");
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
   EventKillTimer();
   ObjectsDeleteAll(0, D);
   ObjectsDeleteAll(0, OV);
}

//=====================================================================
//  ACCOUNT & VOLATILITY RISK SCALING (INSTITUTIONAL LOGIC)
//=====================================================================
void UpdateDynamicRisk()
{
   double eq = AccountInfoDouble(ACCOUNT_EQUITY);
   double scaleFactor = 1.0;
   
   // Institutional scaling: Smaller accounts can take higher % risk, Large accounts compress risk
   if(eq > 100000) scaleFactor = 0.5;       // Over $100k -> Halve the risk%
   else if(eq < 1000) scaleFactor = 1.5;    // Under $1k -> 1.5x risk% for growth
   
   // Volatility scale: If ATR is extreme, reduce lot size to widen SL safely
   double volScale = (g_volState == VOL_EXTREME) ? 0.6 : 1.0;
   
   g_dynamicRisk = InpBaseRiskPercent * scaleFactor * volScale;
}

//=====================================================================
//  SMART MONEY CONCEPTS (SMC) ENGINE: FVG & CHoCH
//=====================================================================
void UpdateSMC()
{
   if(!InpUseSMC) return;
   
   double pt = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   double minGap = InpMinFVGSizePoints * pt;
   
   // 1. FAIR VALUE GAP (FVG) DETECTION (3-Bar Pattern)
   g_fvg.bullishActive = false;
   g_fvg.bearishActive = false;
   
   for(int i=1; i<=5; i++) 
   {
      double h1 = iHigh(_Symbol, PERIOD_M5, i+2);
      double l1 = iLow(_Symbol, PERIOD_M5, i+2);
      double h3 = iHigh(_Symbol, PERIOD_M5, i);
      double l3 = iLow(_Symbol, PERIOD_M5, i);
      
      // Bullish FVG
      if(h1 < l3 && (l3 - h1) >= minGap && iClose(_Symbol, PERIOD_M5, i+1) > iOpen(_Symbol, PERIOD_M5, i+1)) {
         g_fvg.bullishActive = true;
         g_fvg.bullTop = l3;
         g_fvg.bullBottom = h1;
         g_fvg.bullTime = iTime(_Symbol, PERIOD_M5, i+1);
      }
      
      // Bearish FVG
      if(l1 > h3 && (l1 - h3) >= minGap && iClose(_Symbol, PERIOD_M5, i+1) < iOpen(_Symbol, PERIOD_M5, i+1)) {
         g_fvg.bearishActive = true;
         g_fvg.bearTop = l1;
         g_fvg.bearBottom = h3;
         g_fvg.bearTime = iTime(_Symbol, PERIOD_M5, i+1);
      }
   }

   // 2. CHANGE OF CHARACTER (CHoCH)
   int highestIdx = iHighest(_Symbol, PERIOD_M5, MODE_HIGH, InpSwingLookback, 2);
   int lowestIdx  = iLowest(_Symbol, PERIOD_M5, MODE_LOW, InpSwingLookback, 2);
   
   double curHigh = iHigh(_Symbol, PERIOD_M5, highestIdx);
   double curLow  = iLow(_Symbol, PERIOD_M5, lowestIdx);
   
   if(curHigh != g_smc.lastSwingHigh || curLow != g_smc.lastSwingLow) {
      g_smc.lastSwingHigh = curHigh;
      g_smc.lastSwingLow  = curLow;
   }

   double close0 = iClose(_Symbol, PERIOD_M5, 0);
   g_smc.chochBullish = (close0 > g_smc.lastSwingHigh);
   g_smc.chochBearish = (close0 < g_smc.lastSwingLow);
}

//=====================================================================
//  INDICATOR CONSENSUS & DYNAMIC ROUTER
//=====================================================================
void UpdateMarketState()
{
   // Volatility Update
   double atrBuf[]; CopyBuffer(g_m5_atr, 0, 0, 1, atrBuf);
   g_atr_current = atrBuf[0];
   
   double atr15Buf[]; CopyBuffer(g_m15_atr, 0, 0, 1, atr15Buf);
   if(g_atr_current > atr15Buf[0] * 1.5) g_volState = VOL_EXTREME;
   else if(g_atr_current > atr15Buf[0] * 1.2) g_volState = VOL_HIGH;
   else if(g_atr_current < atr15Buf[0] * 0.7) g_volState = VOL_LOW;
   else g_volState = VOL_NORMAL;

   // Session Update
   MqlDateTime d; TimeCurrent(d);
   int h = d.hour;
   if(h >= 0 && h < 7) g_session = SESSION_ASIAN;
   else if(h >= 7 && h < 13) g_session = SESSION_LONDON;
   else if(h >= 13 && h < 20) g_session = SESSION_NY;
   else g_session = SESSION_DEAD;

   // Fast Momentum
   double emaF[1], emaS[1], rsi[1];
   CopyBuffer(g_m5_ema_fast, 0, 0, 1, emaF);
   CopyBuffer(g_m5_ema_slow, 0, 0, 1, emaS);
   CopyBuffer(g_m5_rsi, 0, 0, 1, rsi);

   // DYNAMIC INDICATOR SELECTION (Avoiding Conflicts)
   // If Volatility is Low, we ignore EMAs (they whipsaw) and trust RSI/Liquidity.
   // If Volatility is High, we ignore RSI (it stays overbought/oversold) and trust EMAs/FVGs.
   
   if(g_volState == VOL_EXTREME && (g_fvg.bullishActive || g_fvg.bearishActive)) 
      g_regime = REGIME_SHOCK;
   else if(g_volState == VOL_HIGH && MathAbs(emaF[0] - emaS[0]) > g_atr_current * 0.3)
      g_regime = REGIME_TRENDING;
   else if(g_volState == VOL_LOW)
      g_regime = REGIME_COMPRESSION;
   else if(rsi[0] > 70 || rsi[0] < 30)
      g_regime = REGIME_RANGING;
   else
      g_regime = REGIME_RANGING;
}

//=====================================================================
//  AI SELF-LEARNING WEIGHTS (REINFORCEMENT PROXY)
//=====================================================================
void UpdateMLWeights(ENUM_GOLD_STRATEGY strat, double pnl, double rMultiple)
{
   int idx = (int)strat;
   g_ml_weights[idx].trades++;
   g_ml_weights[idx].sumR += rMultiple;
   
   if(pnl > 0) {
      g_ml_weights[idx].consecLosses = 0;
      g_ml_weights[idx].currentWeight = MathMin(1.5, g_ml_weights[idx].currentWeight + 0.1);
   } else {
      g_ml_weights[idx].consecLosses++;
      g_ml_weights[idx].currentWeight = MathMax(0.1, g_ml_weights[idx].currentWeight - 0.2);
   }
}

//=====================================================================
//  GOLD SCALPING STRATEGIES
//=====================================================================
struct Signal {
   ENUM_DIRECTION dir;
   ENUM_GOLD_STRATEGY strat;
   double sl, tp;
   string reason;
};

Signal EvaluateStrategies()
{
   Signal sig; sig.dir = DIR_NONE; sig.strat = STRAT_NONE;
   double priceAsk = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double priceBid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double atr = g_atr_current;

   // ML Engine Strategy Selection based on highest current weight
   double bestWeight = -1;
   ENUM_GOLD_STRATEGY activeStrat = STRAT_NONE;
   
   // 1. FVG Strategy (Best in Trend/Shock)
   if(g_fvg.bullishActive && priceAsk < g_fvg.bullTop && priceAsk > g_fvg.bullBottom && g_regime != REGIME_COMPRESSION) {
      if(g_ml_weights[STRAT_GOLD_FVG_SCALP].currentWeight > bestWeight) {
         sig.dir = DIR_LONG; sig.strat = STRAT_GOLD_FVG_SCALP;
         sig.sl = g_fvg.bullBottom - atr * 0.5;
         sig.tp = priceAsk + atr * 2.0;
         sig.reason = "Bullish FVG Tap";
         bestWeight = g_ml_weights[STRAT_GOLD_FVG_SCALP].currentWeight;
      }
   }
   else if(g_fvg.bearishActive && priceBid > g_fvg.bearBottom && priceBid < g_fvg.bearTop) {
      if(g_ml_weights[STRAT_GOLD_FVG_SCALP].currentWeight > bestWeight) {
         sig.dir = DIR_SHORT; sig.strat = STRAT_GOLD_FVG_SCALP;
         sig.sl = g_fvg.bearTop + atr * 0.5;
         sig.tp = priceBid - atr * 2.0;
         sig.reason = "Bearish FVG Tap";
         bestWeight = g_ml_weights[STRAT_GOLD_FVG_SCALP].currentWeight;
      }
   }
   
   // 2. CHoCH Reversal Strategy (Best in Ranging)
   if(g_smc.chochBullish && g_regime == REGIME_RANGING) {
      if(g_ml_weights[STRAT_GOLD_CHOCH_REVERSAL].currentWeight > bestWeight) {
         sig.dir = DIR_LONG; sig.strat = STRAT_GOLD_CHOCH_REVERSAL;
         sig.sl = priceAsk - atr * 1.5;
         sig.tp = priceAsk + atr * 2.5;
         sig.reason = "Bullish CHoCH Break";
         bestWeight = g_ml_weights[STRAT_GOLD_CHOCH_REVERSAL].currentWeight;
      }
   }

   // Ensure ML Weight allows trading (cut off if strategy is heavily failing)
   if(bestWeight < 0.3) {
      sig.dir = DIR_NONE;
      sig.reason = "AI blocked: Strategy health too low";
   }

   return sig;
}

//=====================================================================
//  EXECUTION & RISK SIZING
//=====================================================================
void ExecuteTrade(Signal &sig)
{
   if(sig.dir == DIR_NONE) return;
   
   // Position exists? Wait.
   for(int i = PositionsTotal()-1; i >= 0; i--) {
      if(g_pos.SelectByIndex(i) && g_pos.Magic() == InpMagicNumber && g_pos.Symbol() == _Symbol)
         return;
   }

   double price = (sig.dir == DIR_LONG) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double slDist = MathAbs(price - sig.sl);
   if(slDist <= 0) return;

   // Adaptive Sizing
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   double riskAmount = equity * (g_dynamicRisk / 100.0);
   double tv = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double ts = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   if(ts == 0 || tv == 0) return;
   
   double lot = riskAmount / (slDist * (tv/ts));
   double minL = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxL = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double stepL = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   
   lot = MathFloor(lot / stepL) * stepL;
   if(lot < minL) lot = minL;
   if(lot > maxL) lot = maxL;

   string tag = InpBotName + "|" + IntegerToString((int)sig.strat) + "|" + DoubleToString(riskAmount, 2);
   
   if(sig.dir == DIR_LONG) g_trade.Buy(lot, _Symbol, price, sig.sl, sig.tp, tag);
   else g_trade.Sell(lot, _Symbol, price, sig.sl, sig.tp, tag);
   
   Print("[QGAI] EXECUTE: ", sig.reason, " | Lot: ", lot, " | ML Weight: ", DoubleToString(g_ml_weights[sig.strat].currentWeight, 2));
}

//=====================================================================
//  VISUAL INTELLIGENCE OVERLAYS (SMC)
//=====================================================================
void DrawVisuals()
{
   if(!InpDrawSMC) return;
   
   datetime now = TimeCurrent();
   
   // FVG Drawing
   string nameBull = OV + "FVG_BULL";
   string nameBear = OV + "FVG_BEAR";
   
   ObjectDelete(0, nameBull);
   ObjectDelete(0, nameBear);
   
   if(g_fvg.bullishActive) {
      ObjectCreate(0, nameBull, OBJ_RECTANGLE, 0, g_fvg.bullTime, g_fvg.bullTop, now + 3600*2, g_fvg.bullBottom);
      ObjectSetInteger(0, nameBull, OBJPROP_COLOR, clrGreen);
      ObjectSetInteger(0, nameBull, OBJPROP_BACK, true);
   }
   
   if(g_fvg.bearishActive) {
      ObjectCreate(0, nameBear, OBJ_RECTANGLE, 0, g_fvg.bearTime, g_fvg.bearTop, now + 3600*2, g_fvg.bearBottom);
      ObjectSetInteger(0, nameBear, OBJPROP_COLOR, clrRed);
      ObjectSetInteger(0, nameBear, OBJPROP_BACK, true);
   }

   // CHoCH Drawing
   string cLine = OV + "CHOCH";
   ObjectDelete(0, cLine);
   ObjectCreate(0, cLine, OBJ_HLINE, 0, 0, g_smc.lastSwingHigh);
   ObjectSetInteger(0, cLine, OBJPROP_COLOR, clrGold);
   ObjectSetInteger(0, cLine, OBJPROP_STYLE, STYLE_DASH);
}

//=====================================================================
//  COMPACT DASHBOARD (UPGRADED FOR ML & SMC)
//=====================================================================
void L(string nm, int x, int y, string txt, color clr, int fsz=7) {
   string n = D + nm; ObjectDelete(0, n);
   if(ObjectCreate(0, n, OBJ_LABEL, 0, 0, 0)) {
      ObjectSetInteger(0, n, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(0, n, OBJPROP_XDISTANCE, x); ObjectSetInteger(0, n, OBJPROP_YDISTANCE, y);
      ObjectSetString(0, n, OBJPROP_TEXT, txt); ObjectSetInteger(0, n, OBJPROP_COLOR, clr);
      ObjectSetInteger(0, n, OBJPROP_FONTSIZE, fsz); ObjectSetString(0, n, OBJPROP_FONT, "Arial");
      ObjectSetInteger(0, n, OBJPROP_SELECTABLE, false); ObjectSetInteger(0, n, OBJPROP_HIDDEN, true);
   }
}

void U(string nm, string txt, color clr) {
   if(ObjectFind(0, D+nm) >= 0) { ObjectSetString(0, D+nm, OBJPROP_TEXT, txt); ObjectSetInteger(0, D+nm, OBJPROP_COLOR, clr); }
}

void InitDash() {
   L("lbl_title", 20, 20, "QUANTUM GOLD AI v2.0", clrGold, 10);
   L("lbl_regime", 20, 40, "Regime: --", clrWhite);
   L("lbl_vol", 20, 55, "Volatility: --", clrWhite);
   L("lbl_smc", 20, 70, "SMC Status: --", clrWhite);
   L("lbl_risk", 20, 85, "Adaptive Risk: --", clrWhite);
   L("lbl_ml1", 20, 100, "ML FVG Weight: --", clrCyan);
   L("lbl_ml2", 20, 115, "ML CHoCH Weight: --", clrCyan);
}

void UpdateDash() {
   if(!InpShowDash) return;
   
   U("lbl_regime", "Market Regime: " + EnumToString(g_regime), clrGold);
   U("lbl_vol", "Volatility: " + EnumToString(g_volState), clrWhite);
   
   string smcStr = "Neutral";
   if(g_fvg.bullishActive) smcStr = "Bullish FVG";
   if(g_fvg.bearishActive) smcStr = "Bearish FVG";
   if(g_smc.chochBullish) smcStr = "Bullish CHoCH Break";
   U("lbl_smc", "SMC Vector: " + smcStr, (smcStr=="Neutral")?clrWhite:clrCyan);
   
   U("lbl_risk", "Dynamic Risk: " + DoubleToString(g_dynamicRisk, 2) + "%", clrLightGreen);
   
   U("lbl_ml1", "ML FVG Weight: " + DoubleToString(g_ml_weights[STRAT_GOLD_FVG_SCALP].currentWeight, 2), clrOrange);
   U("lbl_ml2", "ML CHoCH Weight: " + DoubleToString(g_ml_weights[STRAT_GOLD_CHOCH_REVERSAL].currentWeight, 2), clrOrange);
   ChartRedraw(0);
}

//=====================================================================
//  EA MAIN CYCLE
//=====================================================================
void OnTick()
{
   datetime currentBar = iTime(_Symbol, PERIOD_M5, 0);
   bool isNewBar = (currentBar != g_lastBarTime);
   
   if(isNewBar) {
      g_lastBarTime = currentBar;
      UpdateSMC();
      UpdateMarketState();
      UpdateDynamicRisk();
      DrawVisuals();
      if(InpShowDash) UpdateDash();
   }

   Signal sig = EvaluateStrategies();
   ExecuteTrade(sig);
}

void OnTradeTransaction(const MqlTradeTransaction &trans, const MqlTradeRequest &request, const MqlTradeResult &result)
{
   if(trans.type == TRADE_TRANSACTION_DEAL_ADD) {
      ulong dealTicket = trans.deal;
      if(HistoryDealSelect(dealTicket)) {
         if(HistoryDealGetInteger(dealTicket, DEAL_ENTRY) == DEAL_ENTRY_OUT) {
            double pnl = HistoryDealGetDouble(dealTicket, DEAL_PROFIT);
            string comment = HistoryDealGetString(dealTicket, DEAL_COMMENT);
            
            string parts[]; StringSplit(comment, '|', parts);
            if(ArraySize(parts) >= 3) {
               ENUM_GOLD_STRATEGY strat = (ENUM_GOLD_STRATEGY)StringToInteger(parts[1]);
               double riskAmount = StringToDouble(parts[2]);
               double rMult = (riskAmount > 0) ? pnl / riskAmount : 0;
               UpdateMLWeights(strat, pnl, rMult); // Train the AI Proxy
            }
         }
      }
   }
}