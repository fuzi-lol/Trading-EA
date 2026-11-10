//+------------------------------------------------------------------+
//|            THEE EliteScalper v7.0 SMC EDITION                    |
//|              Smart Money Concepts + AI Probability Engine        |
//|        BOS | CHOCH | FVG | Order Block | Liquidity Sweep        |
//|                 Dynamic SL | Trailing | Scale‑in                |
//+------------------------------------------------------------------+
#property copyright   "Copyright 2026, ELITE Systems"
#property version     "7.00"
#property description "SMC EDITION — Smart Money Concepts Engine"
#property description "BOS/CHOCH • Liquidity Sweeps • FVG • Order Blocks"
#property description "Volume Analysis • News Protection • Probability Ranking"
#property description "Scale‑in after Profit | ATR‑based Dynamic SL | Trailing"
#property strict

#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>

#define DASH_PREFIX  "SMCV7_"
#define MAX_ORDERS   20

//+------------------------------------------------------------------+
//| ENUMERATIONS                                                     |
//+------------------------------------------------------------------+
enum ENUM_TRADE_DIR { DIR_NONE=0, DIR_LONG=1, DIR_SHORT=-1 };
enum ENUM_SMC_PATTERN { PAT_NONE, PAT_BOS, PAT_CHOCH, PAT_SWEEP, PAT_FVG, PAT_OB };
enum ENUM_REGIME { REGIME_TREND_UP, REGIME_TREND_DOWN, REGIME_RANGE, REGIME_NEWS };

//+------------------------------------------------------------------+
//| INPUT PARAMETERS                                                 |
//+------------------------------------------------------------------+
input group "=== CORE SETTINGS ==="
input ulong   InpMagicNumber         = 777333;
input double  InpRiskPercent         = 1.0;           // Risk % per trade
input double  InpMinRR               = 1.5;           // Minimum Reward:Risk
input double  InpMaxRR               = 3.0;           // Maximum Reward:Risk target for take profit
input int     InpMaxSpreadPoints     = 25;

input group "=== PROBABILITY ENGINE WEIGHTS ==="
input int     InpWeightBOS           = 30;
input int     InpWeightSWEEP         = 25;
input int     InpWeightFVG           = 20;
input int     InpWeightOB            = 15;
input int     InpWeightVolume        = 10;
input int     InpMinProbability      = 65;            // Minimum combined probability to trade

input group "=== SMC PATTERN PARAMETERS ==="
input int     InpSwingLookback       = 5;
input double  InpMinSwingSizePoints  = 50;            // Minimum swing in points
input int     InpFVGLookback         = 3;
input double  InpFVGMitigationPct    = 0.5;           // Mitigation % to consider FVG filled
input int     InpOBLookback          = 5;
input double  InpOBMitigationPct     = 0.7;

input group "=== VOLUME & NEWS ==="
input bool    InpUseVolume           = true;
input double  InpVolumeMultiplier    = 1.5;           // Relative volume spike threshold
input bool    InpNewsFilter          = true;
input string  InpNewsTimes           = "13:30,15:00"; // UTC high impact news times (comma separated)

input group "=== REGIME DETECTION ==="
input int     InpADXPeriod           = 14;
input double  InpADXTrendThreshold   = 25.0;
input int     InpEMAPeriodRegime     = 50;
input double  InpRangeATRMult        = 0.7;           // ATR multiplier to classify range

input group "=== TRADE MANAGEMENT ==="
input double  InpSLATRMult           = 1.5;           // Stop Loss = ATR * multiplier
input double  InpTPATRMult           = 3.0;           // Take Profit = ATR * multiplier (if not overridden by RR)
input double  InpBEActivationRR      = 1.0;           // Move to BE when price reaches this RR
input double  InpTrailATRMult        = 1.0;           // Trailing stop distance in ATR multiples
input int     InpMaxScaleIn           = 3;            // Maximum additional entries
input double  InpScaleInRR           = 0.8;           // RR required on current position before scale‑in

input group "=== INTERFACE ==="
input int     InpDashXOffset         = 15;
input int     InpDashYOffset         = 15;

//+------------------------------------------------------------------+
//| COLOR PALETTE                                                    |
//+------------------------------------------------------------------+
color C_BG        = C'4,6,10';
color C_PANEL     = C'10,16,26';
color C_HEADER    = C'14,32,66';
color C_BORDER    = C'0,90,180';
color C_NEON      = C'0,225,120';
color C_RED       = C'235,45,65';
color C_GOLD      = C'255,185,25';
color C_PURPLE    = C'180,0,255';
color C_ORANGE    = C'255,120,0';
color C_TEAL      = C'0,200,180';
color C_LIGHT     = C'235,242,255';
color C_MUTED     = C'130,145,170';

//+------------------------------------------------------------------+
//| STRUCTURES                                                       |
//+------------------------------------------------------------------+
struct SwingPoint { datetime time; double price; int index; };
struct FVG { datetime start; double upper, lower; bool mitigated; };
struct OrderBlock { datetime time; double price; ENUM_TRADE_DIR dir; bool mitigated; };

//+------------------------------------------------------------------+
//| GLOBAL VARIABLES                                                 |
//+------------------------------------------------------------------+
CTrade         g_Trade;
CPositionInfo  g_Pos;
//--- Indicators
int   g_hADX     = INVALID_HANDLE;
int   g_hATR     = INVALID_HANDLE;
int   g_hEMA50   = INVALID_HANDLE;
int   g_hVolume  = INVALID_HANDLE;
//--- State
ENUM_TRADE_DIR  g_MarketBias = DIR_NONE;
ENUM_REGIME     g_Regime      = REGIME_RANGE;
double          g_ATR         = 0.0;
int             g_Probability = 0;
datetime        g_LastNewsCheck = 0;
bool            g_NewsActive  = false;
//--- Swing & SMC detection
SwingPoint      g_SwingHighs[], g_SwingLows[];
FVG             g_FVGs[];
OrderBlock      g_OrderBlocks[];
//--- Trade management
int             g_ScaleCount   = 0;
double          g_EntryPrice   = 0.0;
//--- Dashboard
string          g_StatusText  = "INITIALISING";
color           g_StatusColor = C_GOLD;

//+------------------------------------------------------------------+
//| FORWARD DECLARATIONS                                             |
//+------------------------------------------------------------------+
void   ScanSMC();
int    ComputeProbability(ENUM_TRADE_DIR dir);
bool   DetectBOS(ENUM_TRADE_DIR dir, double &price);
bool   DetectLiquiditySweep(ENUM_TRADE_DIR dir, double &price);
bool   DetectFVG(ENUM_TRADE_DIR dir, double &price);
bool   DetectOrderBlock(ENUM_TRADE_DIR dir, double &price);
bool   VolumeConfirmation(ENUM_TRADE_DIR dir);
bool   NewsCheck();
ENUM_REGIME DetectRegime();
void   ExecuteEntry(ENUM_TRADE_DIR dir);
void   ManagePositions();
double CalcSL(ENUM_TRADE_DIR dir, double entry);
double CalcTP(ENUM_TRADE_DIR dir, double entry, double sl);
void   ScaleIn(ENUM_TRADE_DIR dir);
void   RenderDashboard();
void   RefreshDashboard();
void   PurgeDashboard();

//+------------------------------------------------------------------+
//| INIT/DEINIT                                                      |
//+------------------------------------------------------------------+
int OnInit()
{
   g_Trade.SetExpertMagicNumber(InpMagicNumber);
   g_hADX    = iADX(_Symbol, PERIOD_CURRENT, InpADXPeriod);
   g_hATR    = iATR(_Symbol, PERIOD_CURRENT, 14);
   g_hEMA50  = iMA(_Symbol, PERIOD_CURRENT, InpEMAPeriodRegime, 0, MODE_EMA, PRICE_CLOSE);
   g_hVolume = iVolumes(_Symbol, PERIOD_CURRENT, VOLUME_TICK);
   if(g_hADX==INVALID_HANDLE || g_hATR==INVALID_HANDLE || g_hEMA50==INVALID_HANDLE || g_hVolume==INVALID_HANDLE)
      return INIT_FAILED;
   ArrayResize(g_SwingHighs, 10); ArrayResize(g_SwingLows, 10);
   ArrayResize(g_FVGs, 10);       ArrayResize(g_OrderBlocks, 10);
   RenderDashboard();
   return INIT_SUCCEEDED;
}
void OnDeinit(const int) { PurgeDashboard(); IndicatorRelease(g_hADX); IndicatorRelease(g_hATR); IndicatorRelease(g_hEMA50); IndicatorRelease(g_hVolume); }

//+------------------------------------------------------------------+
//| ON TICK                                                          |
//+------------------------------------------------------------------+
void OnTick()
{
   static datetime lastSec=0;
   if(TimeCurrent()==lastSec) return;
   lastSec=TimeCurrent();
   
   // Update ATR and Regime
   double atrBuf[1]; CopyBuffer(g_hATR,0,0,1,atrBuf); g_ATR=atrBuf[0];
   g_Regime = DetectRegime();
   if(NewsCheck()) { g_NewsActive=true; } else { g_NewsActive=false; }
   
   // Scan SMC patterns every tick (or new bar)
   ScanSMC();
   
   // Determine market bias and probability
   int probLong = ComputeProbability(DIR_LONG);
   int probShort= ComputeProbability(DIR_SHORT);
   g_Probability = MathMax(probLong, probShort);
   g_MarketBias  = (probLong>=probShort) ? DIR_LONG : DIR_SHORT;
   
   // Entry logic: only if not in news, probability above threshold
   if(!g_NewsActive && g_Probability >= InpMinProbability)
   {
      ExecuteEntry(g_MarketBias);
   }
   
   // Manage open positions (trailing, BE, scale-in)
   ManagePositions();
   
   RefreshDashboard();
}

//+------------------------------------------------------------------+
//| SMC PATTERN SCANNING                                            |
//+------------------------------------------------------------------+
void ScanSMC()
{
   // Swing points detection
   int totalBars = InpSwingLookback*2+1;
   double high[], low[], close[];
   ArraySetAsSeries(high,true); ArraySetAsSeries(low,true); ArraySetAsSeries(close,true);
   if(CopyHigh(_Symbol,PERIOD_CURRENT,0,totalBars,high)<totalBars) return;
   if(CopyLow(_Symbol,PERIOD_CURRENT,0,totalBars,low)<totalBars) return;
   if(CopyClose(_Symbol,PERIOD_CURRENT,0,totalBars,close)<totalBars) return;
   
   // Find swing highs/lows (simple: highest/lowest in window)
   int hIdx = ArrayMaximum(high,InpSwingLookback,InpSwingLookback);
   int lIdx = ArrayMinimum(low,InpSwingLookback,InpSwingLookback);
   if(hIdx>=0) { AddSwing(g_SwingHighs, iTime(_Symbol,PERIOD_CURRENT,hIdx), high[hIdx], hIdx); }
   if(lIdx>=0) { AddSwing(g_SwingLows, iTime(_Symbol,PERIOD_CURRENT,lIdx), low[lIdx], lIdx); }
   
   // FVG detection (3-candle pattern)
   for(int i=1; i<InpFVGLookback+1; i++)
   {
      double prevHigh=high[i+1], prevLow=low[i+1];
      double currHigh=high[i], currLow=low[i];
      if(currLow > prevHigh) // bullish FVG
         AddFVG(iTime(_Symbol,PERIOD_CURRENT,i), prevHigh, currLow);
      else if(currHigh < prevLow) // bearish FVG
         AddFVG(iTime(_Symbol,PERIOD_CURRENT,i), currHigh, prevLow);
   }
   // Order Block detection (last strong candle before impulse)
   for(int i=1; i<InpOBLookback+1; i++)
   {
      double body=MathAbs(close[i]-open[i]);
      double range=high[i]-low[i];
      if(range>0 && body>range*0.6)
      {
         ENUM_TRADE_DIR dir = (close[i]>open[i])?DIR_LONG:DIR_SHORT;
         AddOB(iTime(_Symbol,PERIOD_CURRENT,i), close[i], dir);
      }
   }
}
void AddSwing(SwingPoint &arr[], datetime t, double p, int idx)
{
   for(int i=0;i<ArraySize(arr);i++) if(arr[i].time==t) return;
   int sz=ArraySize(arr); ArrayResize(arr,sz+1); arr[sz].time=t; arr[sz].price=p; arr[sz].index=idx;
}
void AddFVG(datetime t, double up, double lo)
{
   int sz=ArraySize(g_FVGs); ArrayResize(g_FVGs,sz+1);
   g_FVGs[sz].start=t; g_FVGs[sz].upper=up; g_FVGs[sz].lower=lo; g_FVGs[sz].mitigated=false;
}
void AddOB(datetime t, double p, ENUM_TRADE_DIR d)
{
   int sz=ArraySize(g_OrderBlocks); ArrayResize(g_OrderBlocks,sz+1);
   g_OrderBlocks[sz].time=t; g_OrderBlocks[sz].price=p; g_OrderBlocks[sz].dir=d; g_OrderBlocks[sz].mitigated=false;
}

//+------------------------------------------------------------------+
//| PROBABILITY ENGINE                                               |
//+------------------------------------------------------------------+
int ComputeProbability(ENUM_TRADE_DIR dir)
{
   double bosPrice, sweepPrice, fvgPrice, obPrice;
   int score=0;
   if(DetectBOS(dir, bosPrice))           score += InpWeightBOS;
   if(DetectLiquiditySweep(dir, sweepPrice)) score += InpWeightSWEEP;
   if(DetectFVG(dir, fvgPrice))           score += InpWeightFVG;
   if(DetectOrderBlock(dir, obPrice))     score += InpWeightOB;
   if(VolumeConfirmation(dir))            score += InpWeightVolume;
   return score;
}
bool DetectBOS(ENUM_TRADE_DIR dir, double &price)
{
   // BOS: break of previous swing high (long) or swing low (short)
   double bid=SymbolInfoDouble(_Symbol,SYMBOL_BID);
   if(dir==DIR_LONG && ArraySize(g_SwingHighs)>0)
   {
      double prevHigh = g_SwingHighs[ArraySize(g_SwingHighs)-1].price;
      if(bid > prevHigh) { price=prevHigh; return true; }
   }
   else if(dir==DIR_SHORT && ArraySize(g_SwingLows)>0)
   {
      double prevLow = g_SwingLows[ArraySize(g_SwingLows)-1].price;
      if(bid < prevLow) { price=prevLow; return true; }
   }
   return false;
}
bool DetectLiquiditySweep(ENUM_TRADE_DIR dir, double &price)
{
   // Sweep: price spikes beyond swing point and reverses
   double bid=SymbolInfoDouble(_Symbol,SYMBOL_BID);
   if(dir==DIR_LONG && ArraySize(g_SwingLows)>0)
   {
      double prevLow = g_SwingLows[ArraySize(g_SwingLows)-1].price;
      if(bid < prevLow) { price=prevLow; return true; }
   }
   else if(dir==DIR_SHORT && ArraySize(g_SwingHighs)>0)
   {
      double prevHigh = g_SwingHighs[ArraySize(g_SwingHighs)-1].price;
      if(bid > prevHigh) { price=prevHigh; return true; }
   }
   return false;
}
bool DetectFVG(ENUM_TRADE_DIR dir, double &price)
{
   double bid=SymbolInfoDouble(_Symbol,SYMBOL_BID);
   for(int i=0;i<ArraySize(g_FVGs);i++)
   {
      if(g_FVGs[i].mitigated) continue;
      if(dir==DIR_LONG && bid <= g_FVGs[i].upper && bid >= g_FVGs[i].lower)
         { price=(g_FVGs[i].upper+g_FVGs[i].lower)/2; g_FVGs[i].mitigated=true; return true; }
      else if(dir==DIR_SHORT && bid >= g_FVGs[i].lower && bid <= g_FVGs[i].upper)
         { price=(g_FVGs[i].upper+g_FVGs[i].lower)/2; g_FVGs[i].mitigated=true; return true; }
   }
   return false;
}
bool DetectOrderBlock(ENUM_TRADE_DIR dir, double &price)
{
   double bid=SymbolInfoDouble(_Symbol,SYMBOL_BID);
   for(int i=0;i<ArraySize(g_OrderBlocks);i++)
   {
      if(g_OrderBlocks[i].mitigated) continue;
      if(dir==DIR_LONG && g_OrderBlocks[i].dir==DIR_LONG && bid <= g_OrderBlocks[i].price)
         { price=g_OrderBlocks[i].price; g_OrderBlocks[i].mitigated=true; return true; }
      else if(dir==DIR_SHORT && g_OrderBlocks[i].dir==DIR_SHORT && bid >= g_OrderBlocks[i].price)
         { price=g_OrderBlocks[i].price; g_OrderBlocks[i].mitigated=true; return true; }
   }
   return false;
}
bool VolumeConfirmation(ENUM_TRADE_DIR dir)
{
   if(!InpUseVolume) return false;
   double vol[2]; CopyBuffer(g_hVolume,0,0,2,vol);
   return (vol[0] > vol[1]*InpVolumeMultiplier);
}
bool NewsCheck()
{
   if(!InpNewsFilter) return false;
   if(TimeCurrent()-g_LastNewsCheck < 60) return g_NewsActive;
   g_LastNewsCheck=TimeCurrent();
   MqlDateTime dt; TimeToStruct(TimeGMT(),dt);
   string times[], now=StringFormat("%02d:%02d",dt.hour,dt.min);
   StringSplit(InpNewsTimes,',',times);
   for(int i=0;i<ArraySize(times);i++)
      if(now==times[i]) return true;
   return false;
}

//+------------------------------------------------------------------+
//| REGIME DETECTION                                                 |
//+------------------------------------------------------------------+
ENUM_REGIME DetectRegime()
{
   double adx[1], ema[1], atr[1];
   CopyBuffer(g_hADX,0,0,1,adx); CopyBuffer(g_hEMA50,0,0,1,ema); CopyBuffer(g_hATR,0,0,1,atr);
   double price=SymbolInfoDouble(_Symbol,SYMBOL_BID);
   if(g_NewsActive) return REGIME_NEWS;
   if(adx[0]>=InpADXTrendThreshold)
   {
      if(price>ema[0]) return REGIME_TREND_UP;
      else return REGIME_TREND_DOWN;
   }
   return REGIME_RANGE;
}

//+------------------------------------------------------------------+
//| TRADE EXECUTION                                                  |
//+------------------------------------------------------------------+
void ExecuteEntry(ENUM_TRADE_DIR dir)
{
   // Only if no position exists of the opposite direction
   if(HasPositionOfDirection(dir==DIR_LONG?POSITION_TYPE_BUY:POSITION_TYPE_SELL)) return;
   // Regime check: avoid range unless strong signal?
   if(g_Regime==REGIME_RANGE && g_Probability<80) return;
   
   double entry = (dir==DIR_LONG) ? SymbolInfoDouble(_Symbol,SYMBOL_ASK) : SymbolInfoDouble(_Symbol,SYMBOL_BID);
   double sl = CalcSL(dir, entry);
   double tp = CalcTP(dir, entry, sl);
   double lot = CalcLotSize(sl, entry);
   if(lot<=0) return;
   
   if(dir==DIR_LONG) g_Trade.Buy(lot,_Symbol,entry,sl,tp,"SMC Long");
   else g_Trade.Sell(lot,_Symbol,entry,sl,tp,"SMC Short");
   
   g_EntryPrice=entry;
   g_ScaleCount=0;
   Print("SMC Entry: ",EnumToString(dir)," Lot=",lot," SL=",sl," TP=",tp);
}
double CalcSL(ENUM_TRADE_DIR dir, double entry)
{
   double slDist = g_ATR * InpSLATRMult;
   double point = SymbolInfoDouble(_Symbol,SYMBOL_POINT);
   return (dir==DIR_LONG) ? entry - slDist*point : entry + slDist*point;
}
double CalcTP(ENUM_TRADE_DIR dir, double entry, double sl)
{
   double risk = MathAbs(entry - sl);
   double tpDist = risk * MathMax(InpMinRR, InpMaxRR);
   return (dir==DIR_LONG) ? entry + tpDist : entry - tpDist;
}
double CalcLotSize(double sl, double entry)
{
   double risk = MathAbs(entry - sl);
   double tickValue = SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_VALUE);
   double tickSize = SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE);
   double pointValue = tickValue * (SymbolInfoDouble(_Symbol,SYMBOL_POINT) / tickSize);
   if(pointValue<=0) return 0.01;
   double riskMoney = AccountInfoDouble(ACCOUNT_EQUITY) * InpRiskPercent / 100.0;
   double lots = riskMoney / (risk * pointValue);
   double minLot = SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN);
   double maxLot = SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MAX);
   double step = SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_STEP);
   lots = MathMax(minLot, MathMin(maxLot, MathRound(lots/step)*step));
   return lots;
}

//+------------------------------------------------------------------+
//| POSITION MANAGEMENT (trailing, BE, scale‑in)                    |
//+------------------------------------------------------------------+
void ManagePositions()
{
   for(int i=PositionsTotal()-1; i>=0; i--)
   {
      if(!g_Pos.SelectByIndex(i) || g_Pos.Magic()!=InpMagicNumber || g_Pos.Symbol()!=_Symbol) continue;
      double openPrice = g_Pos.PriceOpen();
      double currentSl = g_Pos.StopLoss();
      double currentTp = g_Pos.TakeProfit();
      double profit = g_Pos.Profit()+g_Pos.Swap()+g_Pos.Commission();
      bool isLong = (g_Pos.PositionType()==POSITION_TYPE_BUY);
      double bid = SymbolInfoDouble(_Symbol,SYMBOL_BID);
      double ask = SymbolInfoDouble(_Symbol,SYMBOL_ASK);
      double price = isLong ? bid : ask;
      double risk = MathAbs(openPrice - currentSl);
      if(risk <= 0) return;
      double rr = (isLong ? (price - openPrice) : (openPrice - price)) / risk;
      
      // Move to breakeven
      if(rr >= InpBEActivationRR && (isLong ? currentSl < openPrice : currentSl > openPrice))
      {
         double newSl = openPrice;
         if(MathAbs(newSl-currentSl) > SymbolInfoDouble(_Symbol,SYMBOL_POINT))
         {
            g_Trade.PositionModify(g_Pos.Ticket(), newSl, currentTp);
            Print("BE moved for ticket ", g_Pos.Ticket());
         }
      }
      // Trailing stop
      if(rr >= InpBEActivationRR+0.5)
      {
         double trailDist = g_ATR * InpTrailATRMult * SymbolInfoDouble(_Symbol,SYMBOL_POINT);
         double newSl = isLong ? price - trailDist : price + trailDist;
         if((isLong && newSl > currentSl) || (!isLong && newSl < currentSl))
         {
            g_Trade.PositionModify(g_Pos.Ticket(), newSl, currentTp);
         }
      }
      // Scale‑in opportunity
      if(profit > 0 && rr >= InpScaleInRR && g_ScaleCount < InpMaxScaleIn)
      {
         ScaleIn(isLong ? DIR_LONG : DIR_SHORT);
      }
   }
}
void ScaleIn(ENUM_TRADE_DIR dir)
{
   // Only add if new SMC confirmation appears
   int prob = ComputeProbability(dir);
   if(prob < InpMinProbability) return;
   double entry = (dir==DIR_LONG) ? SymbolInfoDouble(_Symbol,SYMBOL_ASK) : SymbolInfoDouble(_Symbol,SYMBOL_BID);
   double sl = CalcSL(dir, entry);
   double tp = CalcTP(dir, entry, sl);
   double lot = CalcLotSize(sl, entry);
   if(lot<=0) return;
   if(dir==DIR_LONG) g_Trade.Buy(lot,_Symbol,entry,sl,tp,"SMC Scale Long");
   else g_Trade.Sell(lot,_Symbol,entry,sl,tp,"SMC Scale Short");
   g_ScaleCount++;
   Print("Scale‑in executed, count=",g_ScaleCount);
}
bool HasPositionOfDirection(ENUM_POSITION_TYPE type)
{
   for(int i=PositionsTotal()-1;i>=0;i--)
      if(g_Pos.SelectByIndex(i) && g_Pos.Magic()==InpMagicNumber && g_Pos.Symbol()==_Symbol && g_Pos.PositionType()==type)
         return true;
   return false;
}

//+------------------------------------------------------------------+
//| DASHBOARD                                                        |
//+------------------------------------------------------------------+
void RenderDashboard()
{
   int x=InpDashXOffset, y=InpDashYOffset, w=320, h=400;
   string p=DASH_PREFIX;
   CreateRect(p+"Bg",x,y,w,h,C_BG,C_BORDER,2);
   CreateLabel(p+"T1",x+10,y+5,"SMC v7.0 Elite",C_GOLD,14,"Arial Black");
   CreateLabel(p+"Prob",x+10,y+35,"Prob: 0%",C_MUTED,10,"Arial");
   CreateLabel(p+"Bias",x+10,y+55,"Bias: NONE",C_MUTED,10,"Arial");
   CreateLabel(p+"Regime",x+10,y+75,"Regime: RANGE",C_MUTED,10,"Arial");
   CreateLabel(p+"ATR",x+10,y+95,"ATR: 0.0",C_MUTED,10,"Arial");
   CreateLabel(p+"News",x+10,y+115,"News: OFF",C_MUTED,10,"Arial");
   ChartRedraw();
}
void RefreshDashboard()
{
   string p=DASH_PREFIX;
   UpdateLabel(p+"Prob","Prob: "+IntegerToString(g_Probability)+"%",(g_Probability>=InpMinProbability?C_NEON:C_MUTED));
   UpdateLabel(p+"Bias","Bias: "+(g_MarketBias==DIR_LONG?"LONG":"SHORT"),(g_MarketBias==DIR_LONG?C_NEON:C_RED));
   string regStr=""; color rc;
   switch(g_Regime){ case REGIME_TREND_UP: regStr="UP"; rc=C_NEON; break; case REGIME_TREND_DOWN: regStr="DOWN"; rc=C_RED; break; case REGIME_RANGE: regStr="RANGE"; rc=C_ORANGE; break; case REGIME_NEWS: regStr="NEWS"; rc=C_PURPLE; break; }
   UpdateLabel(p+"Regime","Regime: "+regStr,rc);
   UpdateLabel(p+"ATR","ATR: "+DoubleToString(g_ATR,1),C_LIGHT);
   UpdateLabel(p+"News","News: "+(g_NewsActive?"ACTIVE":"OFF"),(g_NewsActive?C_RED:C_MUTED));
   ChartRedraw();
}
void PurgeDashboard(){ ObjectsDeleteAll(0,DASH_PREFIX); }
void CreateRect(string nm,int x,int y,int w,int h,color bg,color bd,int bw)
{
   ObjectCreate(0,nm,OBJ_RECTANGLE_LABEL,0,0,0); ObjectSetInteger(0,nm,OBJPROP_CORNER,CORNER_LEFT_UPPER);
   ObjectSetInteger(0,nm,OBJPROP_XDISTANCE,x); ObjectSetInteger(0,nm,OBJPROP_YDISTANCE,y);
   ObjectSetInteger(0,nm,OBJPROP_XSIZE,w); ObjectSetInteger(0,nm,OBJPROP_YSIZE,h);
   ObjectSetInteger(0,nm,OBJPROP_BGCOLOR,bg); if(bd!=clrNONE){ ObjectSetInteger(0,nm,OBJPROP_BORDER_TYPE,BORDER_FLAT); ObjectSetInteger(0,nm,OBJPROP_COLOR,bd); ObjectSetInteger(0,nm,OBJPROP_WIDTH,bw); }
   ObjectSetInteger(0,nm,OBJPROP_SELECTABLE,false); ObjectSetInteger(0,nm,OBJPROP_HIDDEN,true);
}
void CreateLabel(string nm,int x,int y,string txt,color clr,int sz,string font)
{
   ObjectCreate(0,nm,OBJ_LABEL,0,0,0); ObjectSetInteger(0,nm,OBJPROP_CORNER,CORNER_LEFT_UPPER);
   ObjectSetInteger(0,nm,OBJPROP_XDISTANCE,x); ObjectSetInteger(0,nm,OBJPROP_YDISTANCE,y);
   ObjectSetString(0,nm,OBJPROP_TEXT,txt); ObjectSetInteger(0,nm,OBJPROP_COLOR,clr);
   ObjectSetInteger(0,nm,OBJPROP_FONTSIZE,sz); ObjectSetString(0,nm,OBJPROP_FONT,font);
   ObjectSetInteger(0,nm,OBJPROP_SELECTABLE,false); ObjectSetInteger(0,nm,OBJPROP_HIDDEN,true);
}
void UpdateLabel(string nm,string txt,color clr=clrNONE)
{
   if(ObjectFind(0,nm)>=0){ ObjectSetString(0,nm,OBJPROP_TEXT,txt); if(clr!=clrNONE) ObjectSetInteger(0,nm,OBJPROP_COLOR,clr); }
}
//+------------------------------------------------------------------+