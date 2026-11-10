//+------------------------------------------------------------------+
//|                                   QUANTUM_PLUS_SYSTEMATIC_EA.mq5 |
//|                                  Copyright 2026, FXBotHub Systems|
//|                                             https://fxbothub.com |
//+------------------------------------------------------------------+
#property copyright   "Copyright 2026, FXBotHub Systems"
#property link        "https://fxbothub.com"
#property version     "9.00"
#property description "Institutional Quantitative XAUUSD Trading System with Candle Psychology Gates"
#property strict

#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>

//+------------------------------------------------------------------+
//| SYSTEM DEFINITIONS & CONSTANTS                                   |
//+------------------------------------------------------------------+
#define MAX_LIQUIDITY_ZONES  100
#define MAX_FVG_ZONES        100
#define TICK_BUFFER_SIZE     50
#define STRATEGY_COUNT       5
#define DASH_PREFIX          "SYS_Q_PLUS_"

enum ENUM_MARKET_STATE
{
   STATE_TREND_EXPANSION,
   STATE_TREND_CONTINUATION,
   STATE_TREND_EXHAUSTION,
   STATE_RANGE_ACCUMULATION,
   STATE_RANGE_DISTRIBUTION,
   STATE_VOLATILITY_EXPANSION,
   STATE_VOLATILITY_CONTRACTION,
   STATE_LIQUIDITY_HUNT,
   STATE_TRANSITION,
   STATE_UNDEFINED
};

enum ENUM_VOL_STATE
{
   VOL_SUPPRESSED,
   VOL_NORMAL,
   VOL_EXPANDING,
   VOL_EXTREME,
   VOL_CHAOTIC
};

enum ENUM_STRUCT_CLASS
{
   STRUCTURE_BULL,
   STRUCTURE_BEAR,
   STRUCTURE_TRANSITION,
   STRUCTURE_RANGE
};

enum ENUM_STRATEGY_TYPE
{
   STRAT_TREND_CONTINUATION,
   STRAT_RANGE_REVERSION,
   STRAT_LIQUIDITY_SWEEP,
   STRAT_VOLATILITY_BREAKOUT,
   STRAT_TREND_EXHAUSTION,
   STRAT_STAND_ASIDE
};

enum ENUM_SIGNAL
{
   SIGNAL_BUY  =  1,
   SIGNAL_SELL = -1,
   SIGNAL_NONE =  0
};

struct MarketStateResult
{
   ENUM_MARKET_STATE State;
   double Confidence;
};

struct LiquidityZone
{
   double Price;
   double Strength;
   datetime Created;
   bool Swept;
   int Touches;
   string LevelType; 
};

struct FairValueGap
{
   double UpperBound;
   double LowerBound;
   double Size;
   bool Filled;
   double QualityScore;
   datetime Created;
};

struct STRUCT_ORDERFLOW
{
   double AggressionScore;
   double BullishPressure;
   double BearishPressure;
   string Dominance;
};

struct STRUCT_SESSION_PROB
{
   double ExpansionProbability;
   double ContinuationProbability;
   double ReversalProbability;
};

struct STRUCT_STRATEGY_STATS
{
   int TotalTrades;
   int Wins;
   double NetProfit;
   double ProfitFactor;
   double WinRate;
   bool IsDisabled;
   double AllocationScale;
};

struct STRUCT_KALMAN_FILTER
{
   double estimate;      
   double error_cov;     
   double process_noise; 
   double measure_noise; 
   double gain;          
};

//+------------------------------------------------------------------+
//| SYSTEM INPUT PARAMETERS                                          |
//+------------------------------------------------------------------+
input group "=== 1. SYSTEM IDENTITY ==="
input ulong   InpMagicNumber       = 888111;
input string  InpTradeComment      = "Quantum_Plus_Systematic";

input group "=== 2. MATHEMATICAL KALMAN NOISE ==="
input double  InpProcessNoise      = 0.001;  
input double  InpMeasureNoise      = 0.1;    

input group "=== 3. VOLATILITY ENGINE ==="
input int     InpATRPeriod         = 14;
input int     InpPercentilePeriod  = 200;    

input group "=== 4. ADVANCED CANDLE MOMENTUM GATES ==="
input bool    InpRequireCandleGate = true;   // Intercept and block entries into unconfirmed candles
input double  InpMinRejectionWick  = 35.0;   // Minimum required rejection shadow (%) to trade a retracement
input int     InpMaxAllowedBodyPoints = 1800; // Block entries if current counter-candle body is too massive (180 Gold Points)

input group "=== 5. SYSTEM PIPELINE THRESHOLDS ==="
input double  InpMinFusionScore    = 80.0;   
input double  InpMaxSpreadPercentile = 85.0; 
input int     InpMaxExecutionLatency = 100;  

input group "=== 6. BASE RISK MANAGEMENT ==="
input double  InpBaseRiskPercent   = 1.0;    
input double  InpMaxDrawdownLimit  = 10.0;   

//+------------------------------------------------------------------+
//| GLOBAL SYSTEM CORE STORAGE                                       |
//+------------------------------------------------------------------+
CTrade                g_Trade;
CPositionInfo         g_Pos;
STRUCT_KALMAN_FILTER  g_KFast;
STRUCT_KALMAN_FILTER  g_KSlow;

LiquidityZone         g_LiquidityMap[MAX_LIQUIDITY_ZONES];
int                   g_TotalLiquidityZones = 0;
FairValueGap          g_FVGMap[MAX_FVG_ZONES];
int                   g_TotalFVGZones       = 0;
STRUCT_STRATEGY_STATS g_StrategyHealth[STRATEGY_COUNT];

MqlTick               g_TickBuffer[TICK_BUFFER_SIZE];
int                   g_TickCount           = 0;
double                g_HistoricalSpreads[];

MarketStateResult     g_CurrentState;
ENUM_VOL_STATE        g_CurrentVolState;
double                g_VolCompositeIndex   = 0.0;
ENUM_STRUCT_CLASS     g_CurrentStructure;
double                g_StructureStrength   = 0.0;
STRUCT_ORDERFLOW      g_CurrentOrderFlow;
STRUCT_SESSION_PROB   g_CurrentSessionProb;
double                g_FinalFusionScore    = 0.0;

int                   g_hATR                = INVALID_HANDLE;

//+------------------------------------------------------------------+
//| INITIALIZATION PIPELINE                                          |
//+------------------------------------------------------------------+
int OnInit()
{
   g_Trade.SetExpertMagicNumber(InpMagicNumber);
   g_Trade.SetDeviationInPoints(15);
   g_Trade.SetTypeFilling(ORDER_FILLING_FOK);
   
   g_hATR = iATR(_Symbol, _Period, InpATRPeriod);
   if(g_hATR == INVALID_HANDLE) return INIT_FAILED;
   
   double startPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   g_KFast.estimate = startPrice; g_KFast.error_cov = 1.0; g_KFast.process_noise = InpProcessNoise; g_KFast.measure_noise = InpMeasureNoise;
   g_KSlow.estimate = startPrice; g_KSlow.error_cov = 1.0; g_KSlow.process_noise = InpProcessNoise * 0.05; g_KSlow.measure_noise = InpMeasureNoise * 4.0;
   
   ArrayResize(g_HistoricalSpreads, 1000);
   ZeroMemory(g_LiquidityMap);
   ZeroMemory(g_FVGMap);
   
   for(int i=0; i<STRATEGY_COUNT; i++)
   {
      g_StrategyHealth[i].TotalTrades = 0;
      g_StrategyHealth[i].Wins = 0;
      g_StrategyHealth[i].NetProfit = 0.0;
      g_StrategyHealth[i].ProfitFactor = 1.5;
      g_StrategyHealth[i].WinRate = 0.50;
      g_StrategyHealth[i].IsDisabled = false;
      g_StrategyHealth[i].AllocationScale = 1.0;
   }
   
   BuildInitialLiquidityMap();
   ScanFairValueGaps();
   
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
   if(g_hATR != INVALID_HANDLE) IndicatorRelease(g_hATR);
   ObjectsDeleteAll(0, DASH_PREFIX);
}

//+------------------------------------------------------------------+
//| EXPLICIT SYSTEMATIC PIPELINE CORE                                |
//+------------------------------------------------------------------+
void OnTick()
{
   if(!ObserveMarket()) return;
   
   g_CurrentState = ClassifyMarketState();
   AnalyzeLiquidity();
   AnalyzeVolatility();
   AnalyzeMarketStructure();
   EstimateOrderFlow();
   
   g_FinalFusionScore = CalculateFusionScore();
   ENUM_STRATEGY_TYPE chosenStrategy = MetaRouter();
   
   if(chosenStrategy == STRAT_STAND_ASIDE) return; 
   
   if(IsPositionOpen())
   {
      ManageLifecycle();
      return;
   }
   
   double calculatedRisk = AllocateRisk(chosenStrategy);
   if(calculatedRisk <= 0) return;
   
   if(!VerifyExecutionQuality()) return;
   
   // Route into execution engine loops
   ExecuteRoutedStrategy(chosenStrategy, calculatedRisk);
}

//+------------------------------------------------------------------+
//| LAYER 1: MARKET OBSERVATION LAYER                                |
//+------------------------------------------------------------------+
bool ObserveMarket()
{
   MqlTick tick;
   if(!SymbolInfoTick(_Symbol, tick)) return false;
   
   if(g_TickCount >= TICK_BUFFER_SIZE)
   {
      for(int i=0; i<TICK_BUFFER_SIZE-1; i++) g_TickBuffer[i] = g_TickBuffer[i+1];
      g_TickBuffer[TICK_BUFFER_SIZE-1] = tick;
   }
   else
   {
      g_TickBuffer[g_TickCount] = tick;
      g_TickCount++;
   }
   
   int totalSpreads = ArraySize(g_HistoricalSpreads);
   for(int i=0; i<totalSpreads-1; i++) g_HistoricalSpreads[i] = g_HistoricalSpreads[i+1];
   g_HistoricalSpreads[totalSpreads-1] = (tick.ask - tick.bid) / _Point;
   
   g_KFast.error_cov += g_KFast.process_noise;
   g_KFast.gain = g_KFast.error_cov / (g_KFast.error_cov + g_KFast.measure_noise);
   g_KFast.estimate = g_KFast.estimate + g_KFast.gain * (tick.bid - g_KFast.estimate);
   g_KFast.error_cov = (1.0 - g_KFast.gain) * g_KFast.error_cov;
   
   g_KSlow.error_cov += g_KSlow.process_noise;
   g_KSlow.gain = g_KSlow.error_cov / (g_KSlow.error_cov + g_KSlow.measure_noise);
   g_KSlow.estimate = g_KSlow.estimate + g_KSlow.gain * (tick.bid - g_KSlow.estimate);
   g_KSlow.error_cov = (1.0 - g_KSlow.gain) * g_KSlow.error_cov;
   
   return (g_TickCount >= 5);
}

//+------------------------------------------------------------------+
//| LAYER 2: INSTITUTIONAL MARKET STATE ENGINE                       |
//+------------------------------------------------------------------+
MarketStateResult ClassifyMarketState()
{
   MarketStateResult res;
   res.State = STATE_UNDEFINED;
   res.Confidence = 0.0;
   
   double fast = g_KFast.estimate;
   double slow = g_KSlow.estimate;
   double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   
   double devFastSlow = MathAbs(fast - slow) / _Point;
   double devPriceFast = (currentPrice - fast) / _Point;
   
   double trendExpansionScore     = 0.0;
   double rangeAccumulationScore  = 0.0;
   double liquidityHuntScore      = 0.0;
   double trendExhaustionScore    = 0.0;
   
   if(devFastSlow > 250.0) trendExpansionScore += 40.0;
   else rangeAccumulationScore += 50.0;
   
   if(MathAbs(devPriceFast) > 180.0) 
   {
      trendExhaustionScore += 45.0;
      liquidityHuntScore   += 20.0;
   }
   
   MqlRates rates[];
   if(CopyRates(_Symbol, _Period, 0, 5, rates) == 5)
   {
      double h1 = rates[1].high; double l1 = rates[1].low;
      double h2 = rates[2].high; double l2 = rates[2].low;
      if(MathAbs(h1 - h2) / _Point < 30.0) liquidityHuntScore += 35.0;
      if(MathAbs(l1 - l2) / _Point < 30.0) liquidityHuntScore += 35.0;
   }
   
   if(trendExpansionScore > rangeAccumulationScore && trendExpansionScore > liquidityHuntScore && trendExpansionScore > trendExhaustionScore)
   {
      res.State = (devPriceFast * (fast - slow) > 0) ? STATE_TREND_EXPANSION : STATE_TREND_CONTINUATION;
      res.Confidence = MathMin(trendExpansionScore, 100.0);
   }
   else if(liquidityHuntScore > rangeAccumulationScore && liquidityHuntScore > trendExhaustionScore)
   {
      res.State = STATE_LIQUIDITY_HUNT;
      res.Confidence = MathMin(liquidityHuntScore, 100.0);
   }
   else if(trendExhaustionScore > rangeAccumulationScore)
   {
      res.State = STATE_TREND_EXHAUSTION;
      res.Confidence = MathMin(trendExhaustionScore, 100.0);
   }
   else
   {
      res.State = (fast > slow) ? STATE_RANGE_DISTRIBUTION : STATE_RANGE_ACCUMULATION;
      res.Confidence = MathMin(rangeAccumulationScore, 100.0);
   }
   
   return res;
}

//+------------------------------------------------------------------+
//| LAYER 3: INSTITUTIONAL LIQUIDITY INTELLIGENCE ENGINE             |
//+------------------------------------------------------------------+
void BuildInitialLiquidityMap()
{
   g_TotalLiquidityZones = 0;
   MqlRates dailyRates[];
   if(CopyRates(_Symbol, PERIOD_D1, 1, 10, dailyRates) > 0)
   {
      for(int i=0; i<ArraySize(dailyRates) && g_TotalLiquidityZones < MAX_LIQUIDITY_ZONES; i++)
      {
         g_LiquidityMap[g_TotalLiquidityZones].Price = dailyRates[i].high;
         g_LiquidityMap[g_TotalLiquidityZones].Strength = 75.0;
         g_LiquidityMap[g_TotalLiquidityZones].Created = dailyRates[i].time;
         g_LiquidityMap[g_TotalLiquidityZones].Swept = false;
         g_LiquidityMap[g_TotalLiquidityZones].Touches = 0;
         g_LiquidityMap[g_TotalLiquidityZones].LevelType = "Daily_High";
         g_TotalLiquidityZones++;
         
         g_LiquidityMap[g_TotalLiquidityZones].Price = dailyRates[i].low;
         g_LiquidityMap[g_TotalLiquidityZones].Strength = 75.0;
         g_LiquidityMap[g_TotalLiquidityZones].Created = dailyRates[i].time;
         g_LiquidityMap[g_TotalLiquidityZones].Swept = false;
         g_LiquidityMap[g_TotalLiquidityZones].Touches = 0;
         g_LiquidityMap[g_TotalLiquidityZones].LevelType = "Daily_Low";
         g_TotalLiquidityZones++;
      }
   }
}

void AnalyzeLiquidity()
{
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   
   for(int i=0; i<g_TotalLiquidityZones; i++)
   {
      if(g_LiquidityMap[i].Swept) continue;
      
      if(g_LiquidityMap[i].LevelType == "Daily_High" && ask >= g_LiquidityMap[i].Price)
      {
         g_LiquidityMap[i].Swept = true;
         continue;
      }
      if(g_LiquidityMap[i].LevelType == "Daily_Low" && bid <= g_LiquidityMap[i].Price)
      {
         g_LiquidityMap[i].Swept = true;
         continue;
      }
      
      double dist = MathAbs(bid - g_LiquidityMap[i].Price) / _Point;
      double proximityScore = (dist > 500.0) ? 10.0 : (1.0 - (dist / 500.0)) * 50.0;
      double structuralAgeWeight = (double)(TimeCurrent() - g_LiquidityMap[i].Created) / 86400.0;
      double ageScore = MathMax(0.0, 30.0 - (structuralAgeWeight * 2.0));
      
      g_LiquidityMap[i].Strength = NormalizeDouble(proximityScore + ageScore + (g_LiquidityMap[i].Touches * 10.0), 2);
      g_LiquidityMap[i].Strength = MathMin(MathMax(g_LiquidityMap[i].Strength, 0.0), 100.0);
   }
}

//+------------------------------------------------------------------+
//| LAYER 4: ADAPTIVE VOLATILITY INTELLIGENCE ENGINE                 |
//+------------------------------------------------------------------+
void AnalyzeVolatility()
{
   double atr = 0.0;
   double atrBuffer[1];
   if(CopyBuffer(g_hATR, 0, 0, 1, atrBuffer) == 1) atr = atrBuffer[0];
   else return;
   
   double currentPrice = g_TickBuffer[g_TickCount-1].bid;
   double startPrice   = g_TickBuffer[0].bid;
   double tickVelocity = MathAbs(currentPrice - startPrice) / _Point;
   
   g_VolCompositeIndex = (atr / _Point) * 0.6 + (tickVelocity * 4.0) * 0.4;
   
   if(g_VolCompositeIndex < 50.0)       g_CurrentVolState = VOL_SUPPRESSED;
   else if(g_VolCompositeIndex < 150.0) g_CurrentVolState = VOL_NORMAL;
   else if(g_VolCompositeIndex < 350.0) g_CurrentVolState = VOL_EXPANDING;
   else if(g_VolCompositeIndex < 600.0) g_CurrentVolState = VOL_EXTREME;
   else                                 g_CurrentVolState = VOL_CHAOTIC;
}

//+------------------------------------------------------------------+
//| LAYER 5: MARKET STRUCTURE SWING ENGINE V2                        |
//+------------------------------------------------------------------+
void AnalyzeMarketStructure()
{
   MqlRates rates[];
   if(CopyRates(_Symbol, _Period, 1, 20, rates) < 20) return;
   
   double highestHigh = -1.0; double lowestLow = 999999.0;
   for(int i=0; i<20; i++)
   {
      if(rates[i].high > highestHigh) highestHigh = rates[i].high;
      if(rates[i].low < lowestLow)   lowestLow   = rates[i].low;
   }
   
   double currentClose = rates[19].close;
   double structureMid = lowestLow + ((highestHigh - lowestLow) / 2.0);
   
   if(currentClose > highestHigh - ((highestHigh - lowestLow)*0.2))
   {
      g_CurrentStructure = STRUCTURE_BULL;
      g_StructureStrength = 85.0;
   }
   else if(currentClose < lowestLow + ((highestHigh - lowestLow)*0.2))
   {
      g_CurrentStructure = STRUCTURE_BEAR;
      g_StructureStrength = 85.0;
   }
   else
   {
      g_CurrentStructure = (MathAbs(currentClose - structureMid) / _Point < 100.0) ? STRUCTURE_RANGE : STRUCTURE_TRANSITION;
      g_StructureStrength = 50.0;
   }
}

//+------------------------------------------------------------------+
//| LAYER 6: INSTITUTIONAL ORDER FLOW PROXY ENGINE                   |
//+------------------------------------------------------------------+
void EstimateOrderFlow()
{
   double bidAggression = 0.0; double askAggression = 0.0;
   
   for(int i=1; i<g_TickCount; i++)
   {
      double diff = g_TickBuffer[i].bid - g_TickBuffer[i-1].bid;
      long size = g_TickBuffer[i].volume;
      if(size <= 0) size = 1; 
      
      if(diff > 0)      bidAggression += (diff / _Point) * (double)size;
      else if(diff < 0) askAggression += (MathAbs(diff) / _Point) * (double)size;
   }
   
   double totalAggression = bidAggression + askAggression;
   if(totalAggression <= 0) totalAggression = 1.0;
   
   g_CurrentOrderFlow.AggressionScore = NormalizeDouble((bidAggression / totalAggression) * 100.0, 2);
   g_CurrentOrderFlow.BullishPressure = NormalizeDouble(bidAggression, 2);
   g_CurrentOrderFlow.BearishPressure = NormalizeDouble(askAggression, 2);
   g_CurrentOrderFlow.Dominance = (g_CurrentOrderFlow.AggressionScore > 55.0) ? "BULLS" : ((g_CurrentOrderFlow.AggressionScore < 45.0) ? "BEARS" : "NEUTRAL");
}

void ScanFairValueGaps()
{
   MqlRates rates[];
   if(CopyRates(_Symbol, _Period, 1, 5, rates) < 5) return;
   
   g_TotalFVGZones = 0;
   
   if(rates[4].low > rates[2].high)
   {
      g_FVGMap[g_TotalFVGZones].UpperBound   = rates[4].low;
      g_FVGMap[g_TotalFVGZones].LowerBound   = rates[2].high;
      g_FVGMap[g_TotalFVGZones].Size         = (rates[4].low - rates[2].high) / _Point;
      g_FVGMap[g_TotalFVGZones].Filled       = false;
      g_FVGMap[g_TotalFVGZones].Created      = rates[3].time;
      g_FVGMap[g_TotalFVGZones].QualityScore = MathMin((g_FVGMap[g_TotalFVGZones].Size / 50.0) * 100.0, 100.0);
      g_TotalFVGZones++;
   }
   else if(rates[4].high < rates[2].low)
   {
      g_FVGMap[g_TotalFVGZones].UpperBound   = rates[2].low;
      g_FVGMap[g_TotalFVGZones].LowerBound   = rates[4].high;
      g_FVGMap[g_TotalFVGZones].Size         = (rates[2].low - rates[4].high) / _Point;
      g_FVGMap[g_TotalFVGZones].Filled       = false;
      g_FVGMap[g_TotalFVGZones].Created      = rates[3].time;
      g_FVGMap[g_TotalFVGZones].QualityScore = MathMin((g_FVGMap[g_TotalFVGZones].Size / 50.0) * 100.0, 100.0);
      g_TotalFVGZones++;
   }
}

void CalculateSessionProbability()
{
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   
   g_CurrentSessionProb.ExpansionProbability    = 33.0;
   g_CurrentSessionProb.ContinuationProbability = 33.0;
   g_CurrentSessionProb.ReversalProbability     = 33.0;
   
   if(dt.hour >= 0 && dt.hour < 7)
   {
      g_CurrentSessionProb.ExpansionProbability    = 15.0;
      g_CurrentSessionProb.ContinuationProbability = 20.0;
      g_CurrentSessionProb.ReversalProbability     = 65.0; 
   }
   else if(dt.hour >= 7 && dt.hour < 13)
   {
      g_CurrentSessionProb.ExpansionProbability    = 70.0; 
      g_CurrentSessionProb.ContinuationProbability = 20.0;
      g_CurrentSessionProb.ReversalProbability     = 10.0;
   }
   else if(dt.hour >= 13 && dt.hour < 20)
   {
      g_CurrentSessionProb.ExpansionProbability    = 40.0;
      g_CurrentSessionProb.ContinuationProbability = 50.0; 
      g_CurrentSessionProb.ReversalProbability     = 10.0;
   }
}

//+------------------------------------------------------------------+
//| LAYER 7: MATHEMATICAL PROBABILITY FUSION ENGINE                  |
//+------------------------------------------------------------------+
double CalculateFusionScore()
{
   ScanFairValueGaps();
   CalculateSessionProbability();
   
   double structureWeight = 0.25;
   double liquidityWeight = 0.20;
   double volatilityWeight = 0.15;
   double orderFlowWeight = 0.15;
   double sessionWeight   = 0.15;
   double fvgWeight       = 0.10;
   
   double fvgScore = (g_TotalFVGZones > 0) ? g_FVGMap[0].QualityScore : 30.0;
   double liquidityScore = 0.0;
   
   for(int i=0; i<g_TotalLiquidityZones; i++)
   {
      if(!g_LiquidityMap[i].Swept && g_LiquidityMap[i].Strength > liquidityScore)
      {
         liquidityScore = g_LiquidityMap[i].Strength;
      }
   }
   if(liquidityScore == 0) liquidityScore = 50.0;
   
   double totalScore = (g_StructureStrength * structureWeight) +
                       (liquidityScore * liquidityWeight) +
                       ((100.0 - MathAbs(g_VolCompositeIndex - 200.0)/10.0) * volatilityWeight) +
                       (g_CurrentOrderFlow.AggressionScore * orderFlowWeight) +
                       (g_CurrentSessionProb.ContinuationProbability * sessionWeight) +
                       (fvgScore * fvgWeight);
                       
   return NormalizeDouble(MathMin(MathMax(totalScore, 0.0), 100.0), 2);
}

//+------------------------------------------------------------------+
//| LAYER 8: META-ROUTER ENGINE                                      |
//+------------------------------------------------------------------+
ENUM_STRATEGY_TYPE MetaRouter()
{
   if(g_FinalFusionScore < InpMinFusionScore)                                  return STRAT_STAND_ASIDE;
   if(g_CurrentVolState == VOL_CHAOTIC || g_CurrentVolState == VOL_SUPPRESSED) return STRAT_STAND_ASIDE;
   
   if(g_CurrentState.State == STATE_TREND_EXPANSION && g_CurrentStructure == STRUCTURE_BULL) return STRAT_TREND_CONTINUATION;
   if(g_CurrentState.State == STATE_TREND_EXPANSION && g_CurrentStructure == STRUCTURE_BEAR) return STRAT_TREND_CONTINUATION;
      
   if(g_CurrentState.State == STATE_LIQUIDITY_HUNT)       return STRAT_LIQUIDITY_SWEEP;
   if(g_CurrentState.State == STATE_RANGE_ACCUMULATION)   return STRAT_RANGE_REVERSION;
   if(g_CurrentState.State == STATE_VOLATILITY_EXPANSION) return STRAT_VOLATILITY_BREAKOUT;
   if(g_CurrentState.State == STATE_TREND_EXHAUSTION)     return STRAT_TREND_EXHAUSTION;
   
   return STRAT_STAND_ASIDE;
}

//+------------------------------------------------------------------+
//| LAYER 8 (Cont.): RISK ENGINE                                     |
//+------------------------------------------------------------------+
double AllocateRisk(ENUM_STRATEGY_TYPE strategy)
{
   int index = (int)strategy;
   if(index < 0 || index >= STRATEGY_COUNT) return 0.0;
   if(g_StrategyHealth[index].IsDisabled) return 0.0;
   
   double riskAllocationBase = InpBaseRiskPercent;
   
   if(g_FinalFusionScore < 82.0)      riskAllocationBase *= 0.25; 
   else if(g_FinalFusionScore < 88.0) riskAllocationBase *= 0.50; 
   else                               riskAllocationBase *= 1.00; 
   
   if(g_CurrentVolState == VOL_EXTREME) riskAllocationBase *= 0.50;
   
   double absoluteRiskFunds = AccountInfoDouble(ACCOUNT_EQUITY) * (riskAllocationBase / 100.0);
   
   double atr = 0.0; double atrBuf[1];
   if(CopyBuffer(g_hATR, 0, 0, 1, atrBuf) == 1) atr = atrBuf[0];
   if(atr <= 0) return 0.0;
   
   double slDistancePoints = (atr * 2.0) / _Point;
   if(slDistancePoints < 150) slDistancePoints = 150; 
   
   double tickVal  = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   if(tickSize <= 0 || tickVal <= 0) return 0.0;
   
   double pointCost = (tickVal / tickSize) * _Point;
   double targetLot = absoluteRiskFunds / (slDistancePoints * pointCost);
   
   double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   
   double stepNormalizedLot = MathFloor(targetLot / lotStep) * lotStep;
   if(stepNormalizedLot < minLot) stepNormalizedLot = minLot;
   if(stepNormalizedLot > maxLot) stepNormalizedLot = maxLot;
   
   return NormalizeDouble(stepNormalizedLot, 2);
}

//+------------------------------------------------------------------+
//| NEW INTEGRATION: LAYER 9 CANDLEPSYCHOLOGY INTERCEPT GATE        |
//+------------------------------------------------------------------+
bool VerifyCandleMomentumGate(ENUM_SIGNAL sig)
{
   if(!InpRequireCandleGate) return true;
   
   MqlRates rates[];
   // Fetch bar 0 (live unclosed) and bar 1 (last fully completed closed candle)
   if(CopyRates(_Symbol, _Period, 0, 2, rates) < 2) return false;
   
   double open1  = rates[1].open;
   double close1 = rates[1].close;
   double high1  = rates[1].high;
   double low1   = rates[1].low;
   double range1 = high1 - low1;
   if(range1 <= 0) range1 = _Point;
   
   double bodySize1 = MathAbs(close1 - open1);
   
   if(sig == SIGNAL_BUY)
   {
      // FLAW PREVENTION 1: If last candle closed heavily bearish, require an institutional rejection tail
      if(close1 < open1)
      {
         double lowerWick = MathMin(open1, close1) - low1;
         double lowerWickPercent = (lowerWick / range1) * 100.0;
         
         if(lowerWickPercent < InpMinRejectionWick)
         {
            Print("[CANDLE GATE] BUY ABORTED: Previous candle is a solid bear knife. Lower shadow rejection (", 
                  DoubleToString(lowerWickPercent, 1), "%) is below required ", DoubleToString(InpMinRejectionWick, 1), "%");
            return false;
         }
         
         if((bodySize1 / _Point) > InpMaxAllowedBodyPoints)
         {
            Print("[CANDLE GATE] BUY ABORTED: Bearish expansion candle body size too extreme (", DoubleToString(bodySize1 / _Point, 0), " points).");
            return false;
         }
      }
      
      // FLAW PREVENTION 2: Inspect the live unclosed candle (Bar 0). If it's bleeding aggressively down, freeze!
      if(rates[0].close < rates[0].open)
      {
         double liveBody = (rates[0].open - rates[0].close) / _Point;
         if(liveBody > (InpMaxAllowedBodyPoints * 0.5))
         {
            Print("[CANDLE GATE] BUY ABORTED: Live unclosed candle is expanding aggressively downward. Awaiting deceleration.");
            return false;
         }
      }
   }
   
   if(sig == SIGNAL_SELL)
   {
      if(close1 > open1)
      {
         double upperWick = high1 - MathMax(open1, close1);
         double upperWickPercent = (upperWick / range1) * 100.0;
         
         if(upperWickPercent < InpMinRejectionWick)
         {
            Print("[CANDLE GATE] SELL ABORTED: Previous candle is a solid bull marquee. Upper shadow rejection (", 
                  DoubleToString(upperWickPercent, 1), "%) is below required ", DoubleToString(InpMinRejectionWick, 1), "%");
            return false;
         }
         
         if((bodySize1 / _Point) > InpMaxAllowedBodyPoints)
         {
            Print("[CANDLE GATE] SELL ABORTED: Bullish expansion candle body size too extreme.");
            return false;
         }
      }
      
      if(rates[0].close > rates[0].open)
      {
         double liveBody = (rates[0].close - rates[0].open) / _Point;
         if(liveBody > (InpMaxAllowedBodyPoints * 0.5))
         {
            Print("[CANDLE GATE] SELL ABORTED: Live unclosed candle is expanding aggressively upward.");
            return false;
         }
      }
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| LAYER 9: PRE-FLIGHT EXECUTION QUALITY VERIFICATION GATE          |
//+------------------------------------------------------------------+
bool VerifyExecutionQuality()
{
   MqlTick tick;
   if(!SymbolInfoTick(_Symbol, tick)) return false;
   
   double liveSpreadPoints = (tick.ask - tick.bid) / _Point;
   
   int samples = ArraySize(g_HistoricalSpreads);
   int higherCount = 0;
   for(int i=0; i<samples; i++)
   {
      if(g_HistoricalSpreads[i] < liveSpreadPoints) higherCount++;
   }
   
   double liveSpreadPercentile = ((double)higherCount / (double)samples) * 100.0;
   if(liveSpreadPercentile > InpMaxSpreadPercentile)
   {
      Print("[EXECUTION PRE-GATES] Execution aborted. Spread conditions too wide: Percentile ", DoubleToString(liveSpreadPercentile, 1));
      return false; 
   }
   
   return true; 
}

//+------------------------------------------------------------------+
//| EXECUTION STRATEGIC ROUTER TRANSACTION ENGINE                    |
//+------------------------------------------------------------------+
void ExecuteRoutedStrategy(ENUM_STRATEGY_TYPE strategy, double lotSize)
{
   ENUM_SIGNAL entrySignal = SIGNAL_NONE;
   
   if(strategy == STRAT_TREND_CONTINUATION || strategy == STRAT_VOLATILITY_BREAKOUT)
   {
      if(g_CurrentStructure == STRUCTURE_BULL && g_CurrentOrderFlow.AggressionScore > 50.0) entrySignal = SIGNAL_BUY;
      if(g_CurrentStructure == STRUCTURE_BEAR && g_CurrentOrderFlow.AggressionScore < 50.0) entrySignal = SIGNAL_SELL;
   }
   else if(strategy == STRAT_RANGE_REVERSION || strategy == STRAT_TREND_EXHAUSTION)
   {
      if(g_CurrentOrderFlow.AggressionScore < 40.0) entrySignal = SIGNAL_SELL; 
      if(g_CurrentOrderFlow.AggressionScore > 60.0) entrySignal = SIGNAL_BUY;  
   }
   else if(strategy == STRAT_LIQUIDITY_SWEEP)
   {
      for(int i=0; i<g_TotalLiquidityZones; i++)
      {
         if(g_LiquidityMap[i].Swept && (TimeCurrent() - g_LiquidityMap[i].Created < 3600))
         {
            if(g_LiquidityMap[i].LevelType == "Daily_High" && g_CurrentOrderFlow.AggressionScore < 45.0) entrySignal = SIGNAL_SELL;
            if(g_LiquidityMap[i].LevelType == "Daily_Low"  && g_CurrentOrderFlow.AggressionScore > 55.0) entrySignal = SIGNAL_BUY;
         }
      }
   }
   
   if(entrySignal == SIGNAL_NONE) return;
   
   // CRITICAL UPGRADE GATE INTERCEPT: Pass signal through the candlestick psychology momentum interceptor
   if(!VerifyCandleMomentumGate(entrySignal))
   {
      return; // Execution safely aborted to prevent buying into a knife
   }
   
   double price = (entrySignal == SIGNAL_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double atr = 0.0; double atrBuf[1];
   if(CopyBuffer(g_hATR, 0, 0, 1, atrBuf) == 1) atr = atrBuf[0];
   if(atr <= 0) return;
   
   double slDistancePoints = (atr * 2.0) / _Point; if(slDistancePoints < 150) slDistancePoints = 150;
   double tpDistancePoints = slDistancePoints * 3.0; // Fixed 1:3 RR Matrix to lock absolute mathematical expectancy
   
   double slPrice = (entrySignal == SIGNAL_BUY) ? (price - (slDistancePoints * _Point)) : (price + (slDistancePoints * _Point));
   double tpPrice = (entrySignal == SIGNAL_BUY) ? (price + (tpDistancePoints * _Point)) : (price - (tpDistancePoints * _Point));
   
   MqlTradeRequest request; ZeroMemory(request);
   MqlTradeResult  result;  ZeroMemory(result);
   
   request.action       = TRADE_ACTION_DEAL;
   request.symbol       = _Symbol;
   request.volume       = lotSize;
   request.type         = (entrySignal == SIGNAL_BUY) ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
   request.price        = price;
   request.sl           = NormalizeDouble(slPrice, _Digits);
   request.tp           = NormalizeDouble(tpPrice, _Digits);
   request.deviation    = 15;
   request.magic        = InpMagicNumber;
   request.comment      = InpTradeComment + "_" + IntegerToString((int)strategy);
   request.type_filling = ORDER_FILLING_FOK;
   
   for(int i=0; i<3; i++)
   {
      if(OrderSend(request, result))
      {
         if(result.retcode == TRADE_RETCODE_DONE || result.retcode == TRADE_RETCODE_PLACED)
         {
            Print("[SYSTEM TRANSACTION] Order executed successfully via Ticket ID allocation: ", result.deal);
            break;
         }
      }
      if(result.retcode == TRADE_RETCODE_REQUOTE || result.retcode == TRADE_RETCODE_PRICE_OFF)
      {
         Sleep(100);
         request.price = (entrySignal == SIGNAL_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);
      }
      else break;
   }
}

//+------------------------------------------------------------------+
//| LAYER 10: TRADE LIFECYCLE MANAGEMENT                             |
//+------------------------------------------------------------------+
void ManageLifecycle()
{
   if(!PositionSelectByTicket(g_Pos.Ticket())) return;
   
   double entryPrice = g_Pos.PriceOpen();
   double currentBid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double currentAsk = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double stopLoss   = g_Pos.StopLoss();
   double takeProfit = g_Pos.TakeProfit();
   bool   isBuy      = (g_Pos.PositionType() == POSITION_TYPE_BUY);
   
   double initialRiskPoints = MathAbs(entryPrice - stopLoss) / _Point;
   if(initialRiskPoints <= 0) return;
   
   double currentProfitPoints = isBuy ? ((currentBid - entryPrice) / _Point) : ((entryPrice - currentAsk) / _Point);
   
   double milestone1Trigger = initialRiskPoints * 1.5; 
   double milestone1Lock    = initialRiskPoints * 0.5;
   
   double milestone2Trigger = initialRiskPoints * 2.5; 
   double milestone2Lock    = initialRiskPoints * 1.5;
   
   if(currentProfitPoints >= milestone2Trigger)
   {
      double targetSL = isBuy ? (entryPrice + (milestone2Lock * _Point)) : (entryPrice - (milestone2Lock * _Point));
      if((isBuy && targetSL > stopLoss) || (!isBuy && (targetSL < stopLoss || stopLoss == 0)))
      {
         g_Trade.PositionModify(g_Pos.Ticket(), NormalizeDouble(targetSL, _Digits), NormalizeDouble(takeProfit, _Digits));
      }
   }
   else if(currentProfitPoints >= milestone1Trigger)
   {
      double targetSL = isBuy ? (entryPrice + (milestone1Lock * _Point)) : (entryPrice - (milestone1Lock * _Point));
      if((isBuy && targetSL > stopLoss) || (!isBuy && (targetSL < stopLoss || stopLoss == 0)))
      {
         g_Trade.PositionModify(g_Pos.Ticket(), NormalizeDouble(targetSL, _Digits), NormalizeDouble(takeProfit, _Digits));
      }
   }
}

bool IsPositionOpen()
{
   for(int i = PositionsTotal()-1; i >= 0; i--)
   {
      if(g_Pos.SelectByIndex(i) && g_Pos.Magic() == InpMagicNumber && g_Pos.Symbol() == _Symbol) return true;
   }
   return false;
}