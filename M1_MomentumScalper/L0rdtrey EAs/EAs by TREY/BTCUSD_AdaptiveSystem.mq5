//+------------------------------------------------------------------+
//|                                        BTCUSD_AdaptiveSystem.mq5 |
//|                                  Copyright 2026, Quant Engineer |
//|                                             https://www.mql5.com |
//|                                                                  |
//| BUILD PHASE 1: Skeleton + Risk Engine + Account Protection Only  |
//| This file provides a fully stable, defensively coded foundation  |
//| that tracks equity boundaries, evaluates tier-based allocations,  |
//| implements order splitting, and enforces hard risk ceilings.    |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, Quant Engineer"
#property link      "https://www.mql5.com"
#property version   "1.00"
#property strict

//--- Include Standard Library Modules
#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>
#include <Trade\SymbolInfo.mqh>

//--- Define Market Regime Enumeration for Future Modules
enum ENUM_MARKET_REGIME
{
   REGIME_TREND_BULL,
   REGIME_TREND_BEAR,
   REGIME_RANGE,
   REGIME_HIGH_VOLATILITY,
   REGIME_UNDEFINED
};

//#region Inputs
//+------------------------------------------------------------------+
//| INPUTS: SYSTEM CONFIGURATION                                     |
//+------------------------------------------------------------------+
input ulong    InpMagicNumber               = 88112233;     // EA Magic Number
input int      InpMaxRetries                = 3;            // Maximum order execution retries
input int      InpRetryDelayMs              = 200;          // Delay between order retries in milliseconds

//+------------------------------------------------------------------+
//| INPUTS: ACCOUNT-ADAPTIVE RISK ENGINE                             |
//+------------------------------------------------------------------+
input double   InpSmallAccountThreshold     = 2000.0;       // Below this = tight risk mode (USD)
input double   InpLargeAccountThreshold     = 50000.0;      // Above this = scale-mode / split orders (USD)
input double   InpRiskPercent_Small         = 0.3;          // % risk per trade, small accounts
input double   InpRiskPercent_Mid           = 0.75;         // % risk per trade, mid accounts
input double   InpRiskPercent_Large         = 0.5;          // % risk per trade, large accounts
input int      InpMaxConcurrentTrades_Small = 1;            // Max concurrent positions for small tier
input int      InpMaxConcurrentTrades_Mid   = 3;            // Max concurrent positions for mid tier
input int      InpMaxConcurrentTrades_Large = 6;            // Max concurrent positions for large tier
input double   InpMaxSingleOrderLots        = 5.0;          // Max lot size per individual ticket execution
input int      InpOrderSplitDelaySec        = 3;            // Delay in seconds between split order tranches
input int      InpATRPeriod                 = 14;           // Volatility evaluation ATR period
input int      InpATRBaselineDays           = 90;           // Window in days for baseline average volatility
input double   InpVolatilityDeriskMultiple  = 1.5;          // ATR threshold multiple to activate de-risking
input double   InpVolatilityDeriskFactor    = 0.5;          // Position scaling multiplier under extreme volatility

//+------------------------------------------------------------------+
//| INPUTS: HARD ACCOUNT PROTECTION                                  |
//+------------------------------------------------------------------+
input double   InpDailyLossLimitPercent     = 3.0;          // Maximum realized daily loss percentage
input double   InpWeeklyLossLimitPercent    = 7.0;          // Maximum realized weekly loss percentage
input double   InpMonthlyLossLimitPercent   = 15.0;         // Maximum realized monthly loss percentage
input int      InpMaxConsecutiveLosses      = 4;            // Max sequential losses before cooldown lock
input double   InpMaxTotalOpenRiskPercent   = 4.0;          // Maximum aggregated risk across open tickets
input bool     InpKillSwitchEnabled         = true;         // Master structural account protection switch
input double   InpKillSwitchDrawdown        = 20.0;         // Max drawdown % from historical high-water equity
//#endregion

//#region Globals
//+------------------------------------------------------------------+
//| GLOBAL STATE ENGINE VARIABLES                                    |
//+------------------------------------------------------------------+
CTrade         m_trade;                                     // Standard Library Trade execution wrapper
CPositionInfo  m_position;                                  // Position inspection wrapper
CSymbolInfo    m_symbol;                                    // Native symbol parameter caching engine

double         g_peakEquity            = 0.0;               // Maximum recorded equity during lifecycle
double         g_dailyStartEquity      = 0.0;               // Equity at the initialization of the current day
double         g_weeklyStartEquity     = 0.0;               // Equity at the initialization of the current week
double         g_monthlyStartEquity    = 0.0;               // Equity at the initialization of the current month

int            g_consecutiveLosses     = 0;                 // Tracks current unbroken string of losing trades
datetime       g_cooldownExpiryTime    = 0;                 // Epoch timestamp defining active entry lockout
bool           g_killSwitchTriggered   = false;             // Flag indicating permanent operational lockdown

int            g_lastCachedDay         = -1;                // Last evaluated calendar day
int            g_lastCachedWeek        = -1;                // Last evaluated calendar week
int            g_lastCachedMonth       = -1;                // Last evaluated calendar month

int            g_atrHandle             = INVALID_HANDLE;    // Reference to structural ATR instance
//#endregion

//#region Event Handlers
//+------------------------------------------------------------------+
//| Expert Initialization Function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
   // Validate asset parameters via Standard Library
   if(!m_symbol.Name(_Symbol))
     {
      Print("CRITICAL: Asset initialization failure for symbol: ", _Symbol);
      return(INIT_FAILED);
     }
     
   m_symbol.RefreshRates();
   m_trade.SetExpertMagicNumber(InpMagicNumber);
   m_trade.SetMarginMode();
   
   // Instantiate indicators natively inside structural boundaries
   g_atrHandle = iATR(_Symbol, _Period, InpATRPeriod);
   if(g_atrHandle == INVALID_HANDLE)
     {
      Print("CRITICAL: Failed to construct iATR handle.");
      return(INIT_FAILED);
     }

   // Initialize period-opening benchmarks
   double currentEquity = AccountInfoDouble(ACCOUNT_EQUITY);
   g_peakEquity         = currentEquity;
   g_dailyStartEquity   = currentEquity;
   g_weeklyStartEquity  = currentEquity;
   g_monthlyStartEquity = currentEquity;

   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   g_lastCachedDay   = dt.day;
   g_lastCachedMonth = dt.mon;
   g_lastCachedWeek  = dt.day_of_week;

   Print("INITIALIZATION SUCCESSFUL: Core Risk Engine & Hard Protection Systems Active.");
   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Expert Deinitialization Function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   if(g_atrHandle != INVALID_HANDLE)
     {
      IndicatorRelease(g_atrHandle);
     }
   Print("DEINITIALIZATION: Subsystems completely offline. Reason code: ", reason);
  }

//+------------------------------------------------------------------+
//| Expert Tick Function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
   // Synchronize standard pricing data structures
   if(!m_symbol.RefreshRates())
     {
      return; 
     }

   // Periodically refresh tracking boundaries based on server clock
   SynchronizeAccountingBoundaries();

   // Continuously test protection constraints
   if(EvaluateProtectionLimits())
     {
      // Subsystems remain online for position maintenance, but entry execution path is suppressed
      return;
     }
  }
//#endregion

//#region Risk Engine
//+------------------------------------------------------------------+
//| Function: Synchronize Accounting Boundaries                      |
//+------------------------------------------------------------------+
void SynchronizeAccountingBoundaries()
  {
   MqlDateTime serverTime;
   TimeToStruct(TimeCurrent(), serverTime);
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);

   // Track historical structural peak
   if(equity > g_peakEquity)
     {
      g_peakEquity = equity;
     }

   // Validate daily transition rollover
   if(serverTime.day != g_lastCachedDay)
     {
      g_dailyStartEquity = equity;
      g_lastCachedDay    = serverTime.day;
      Print("BOUNDARIES: New Daily Block Established. Starting Reference: ", g_dailyStartEquity);
     }

   // Validate weekly transition rollover
   if(serverTime.day_of_week < g_lastCachedWeek)
     {
      g_weeklyStartEquity = equity;
      Print("BOUNDARIES: New Weekly Block Established. Starting Reference: ", g_weeklyStartEquity);
     }
   g_lastCachedWeek = serverTime.day_of_week;

   // Validate monthly transition rollover
   if(serverTime.mon != g_lastCachedMonth)
     {
      g_monthlyStartEquity = equity;
      g_lastCachedMonth    = serverTime.mon;
      Print("BOUNDARIES: New Monthly Block Established. Starting Reference: ", g_monthlyStartEquity);
     }
  }

//+------------------------------------------------------------------+
//| Function: Evaluate Protection Limits                             |
//+------------------------------------------------------------------+
bool EvaluateProtectionLimits()
  {
   double currentEquity = AccountInfoDouble(ACCOUNT_EQUITY);

   // 1. Permanent Kill Switch Verification
   if(InpKillSwitchEnabled)
     {
      if(g_killSwitchTriggered)
        {
         return true;
        }
        
      if(g_peakEquity > 0.0)
        {
         double absoluteDrawdownPct = ((g_peakEquity - currentEquity) / g_peakEquity) * 100.0;
         if(absoluteDrawdownPct >= InpKillSwitchDrawdown)
           {
            g_killSwitchTriggered = true;
            Print("CRITICAL BLOCK: Terminal Kill Switch Activated. Equity Drawdown from Peak exceeded ceiling: ", DoubleToString(absoluteDrawdownPct, 2), "%");
            return true;
           }
        }
     }

   // 2. Cooldown Expiry Evaluation
   if(TimeCurrent() < g_cooldownExpiryTime)
     {
      return true;
     }

   // 3. Intraday Realized Losses Protection
   if(g_dailyStartEquity > 0.0)
     {
      double currentDailyLossPct = ((g_dailyStartEquity - currentEquity) / g_dailyStartEquity) * 100.0;
      if(currentDailyLossPct >= InpDailyLossLimitPercent)
        {
         Print("ENTRY VIOLATION: Daily Risk Ceiling Breached. Session allocations locked.");
         return true;
        }
     }

   // 4. Weekly Loss Protection
   if(g_weeklyStartEquity > 0.0)
     {
      double currentWeeklyLossPct = ((g_weeklyStartEquity - currentEquity) / g_weeklyStartEquity) * 100.0;
      if(currentWeeklyLossPct >= InpWeeklyLossLimitPercent)
        {
         Print("ENTRY VIOLATION: Weekly Risk Ceiling Breached. Execution pipeline locked.");
         return true;
        }
     }

   // 5. Monthly Loss Protection
   if(g_monthlyStartEquity > 0.0)
     {
      double currentMonthlyLossPct = ((g_monthlyStartEquity - currentEquity) / g_monthlyStartEquity) * 100.0;
      if(currentMonthlyLossPct >= InpMonthlyLossLimitPercent)
        {
         Print("ENTRY VIOLATION: Monthly Risk Ceiling Breached. Execution pipeline locked.");
         return true;
        }
     }

   // 6. Aggregate Position Exposure Risk Constraints
   if(IsAggregateRiskExceeded())
     {
      Print("ENTRY VIOLATION: Aggregate risk footprint across existing allocations matches or exceeds structural boundaries.");
      return true;
     }

   return false;
  }

//+------------------------------------------------------------------+
//| Function: Is Aggregate Risk Exceeded                            |
//+------------------------------------------------------------------+
bool IsAggregateRiskExceeded()
  {
   double totalAllocatedRiskValue = 0.0;
   double currentEquity = AccountInfoDouble(ACCOUNT_EQUITY);
   uint totalPositions = PositionsTotal();

   for(uint i = 0; i < totalPositions; i++)
     {
      if(m_position.SelectByIndex(i))
        {
         if(m_position.Symbol() == _Symbol && m_position.MagicNumber() == InpMagicNumber)
           {
            double positionLots = m_position.Volume();
            double openPrice    = m_position.PriceOpen();
            double stopLoss     = m_position.StopLoss();

            if(stopLoss > 0.0)
              {
               double rawDistancePoints = MathAbs(openPrice - stopLoss) / m_symbol.Point();
               double tickValue = m_symbol.TickValue();
               double tickSize  = m_symbol.TickSize();
               if(tickSize > 0)
                 {
                  double contractRiskValue = (rawDistancePoints * (tickValue / (tickSize / m_symbol.Point()))) * positionLots;
                  totalAllocatedRiskValue += contractRiskValue;
                 }
              }
           }
        }
     }

   double overallRiskPct = (totalAllocatedRiskValue / currentEquity) * 100.0;
   return (overallRiskPct >= InpMaxTotalOpenRiskPercent);
  }

//+------------------------------------------------------------------+
//| Function: Get Volatility Adjustment Factor                       |
//+------------------------------------------------------------------+
double GetVolatilityAdjustmentFactor()
  {
   double currentAtrValues[];
   ArraySetAsSeries(currentAtrValues, true);
   
   if(CopyBuffer(g_atrHandle, 0, 0, 2, currentAtrValues) < 2)
     {
      return 1.0; 
     }

   // Obtain historical context using multi-bar shifting technique
   double accumulatedATRSum = 0.0;
   int availableBars = iBars(_Symbol, PERIOD_D1);
   int targetBars = MathMin(InpATRBaselineDays, availableBars);

   if(targetBars <= 0) 
     {
      return 1.0;
     }

   double d1Atr[];
   int dailyAtrHandle = iATR(_Symbol, PERIOD_D1, InpATRPeriod);
   if(dailyAtrHandle == INVALID_HANDLE) 
     {
      return 1.0;
     }
     
   ArraySetAsSeries(d1Atr, true);
   int copied = CopyBuffer(dailyAtrHandle, 0, 0, targetBars, d1Atr);
   IndicatorRelease(dailyAtrHandle);

   if(copied <= 0) 
     {
      return 1.0;
     }

   for(int i = 0; i < copied; i++)
     {
      accumulatedATRSum += d1Atr[i];
     }
     
   double dailyBaselineAverage = accumulatedATRSum / copied;
   if(dailyBaselineAverage <= 0.0) 
     {
      return 1.0;
     }

   // Evaluate localized intraday volatility against the long-term context
   if(currentAtrValues[0] > (dailyBaselineAverage * InpVolatilityDeriskMultiple))
     {
      return InpVolatilityDeriskFactor;
     }

   return 1.0;
  }

//+------------------------------------------------------------------+
//| Function: Compute Position Sizing Engine                         |
//+------------------------------------------------------------------+
double ComputePositionSizingEngine(double stopDistancePoints, int &outMaxAllowedTrades)
  {
   outMaxAllowedTrades = InpMaxConcurrentTrades_Small;
   if(stopDistancePoints <= 0.0) 
     {
      return 0.0;
     }

   double currentEquity       = AccountInfoDouble(ACCOUNT_EQUITY);
   double targetedRiskPercent = InpRiskPercent_Small;

   // Select parameters dynamically depending on capitalized scaling structures
   if(currentEquity >= InpLargeAccountThreshold)
     {
      targetedRiskPercent = InpRiskPercent_Large;
      outMaxAllowedTrades = InpMaxConcurrentTrades_Large;
     }
   else if(currentEquity >= InpSmallAccountThreshold)
     {
      targetedRiskPercent = InpRiskPercent_Mid;
      outMaxAllowedTrades = InpMaxConcurrentTrades_Mid;
     }

   // Inject risk reductions under highly unstable market structures
   double volMultiplier = GetVolatilityAdjustmentFactor();
   targetedRiskPercent *= volMultiplier;
   
   if(volMultiplier < 1.0)
     {
      Print("RISK ENGINE: High localized volatility identified. Target Risk adjusted down to: ", DoubleToString(targetedRiskPercent, 3), "%");
     }

   // Compute localized lot size relative to nominal cost structures
   double tickValue = m_symbol.TickValue();
   double tickSize  = m_symbol.TickSize();
   
   if(tickValue <= 0.0 || tickSize <= 0.0) 
     {
      return 0.0;
     }

   double convertedPointValue = tickValue / (tickSize / m_symbol.Point());
   double currencyRiskValue   = currentEquity * (targetedRiskPercent / 100.0);
   double mathematicallyRawLots = currencyRiskValue / (stopDistancePoints * convertedPointValue);

   // Align raw values with concrete broker limitations
   double volumeStep = m_symbol.VolStep();
   double executionLots = MathFloor(mathematicallyRawLots / volumeStep) * volumeStep;

   // Ensure calculations fulfill small-account safety constraints
   double finalRealRiskValue = executionLots * stopDistancePoints * convertedPointValue;
   double finalRealRiskPct   = (finalRealRiskValue / currentEquity) * 100.0;

   if(finalRealRiskPct > (targetedRiskPercent * 1.5))
     {
      Print("RISK CRITICAL FLUSH: Allocation discarded. Rounding anomalies generated excessive exposure profiles: ", 
            DoubleToString(finalRealRiskPct, 3), "% calculated vs maximum limit threshold of ", DoubleToString(targetedRiskPercent * 1.5, 3), "%");
      return 0.0;
     }

   // Boundary checks against broker volume spectrum
   if(executionLots < m_symbol.VolMin())
     {
      Print("RISK DETECTOR: Execution payload truncated below minimal broker capacity constraints. Allocation skipped.");
      return 0.0;
     }
     
   if(executionLots > m_symbol.VolMax())
     {
      executionLots = m_symbol.VolMax();
     }

   return executionLots;
  }
//#endregion

//#region Order Execution
//+------------------------------------------------------------------+
//| Function: SubmitDefensiveOrder                                   |
//+------------------------------------------------------------------+
bool SubmitDefensiveOrder(ENUM_ORDER_TYPE orderType, double targetVolume, double targetPrice, double rawSL, double rawTP)
  {
   // Enforce freeze and stop level parameter validation boundaries
   double currentSpread = MathAbs(m_symbol.Ask() - m_symbol.Bid());
   double stopLevelPoints = m_symbol.StopsLevel() * m_symbol.Point();
   double freezeLevelPoints = m_symbol.FreezeLevel() * m_symbol.Point();

   // Baseline stop checks
   if(MathAbs(targetPrice - rawSL) < stopLevelPoints || MathAbs(targetPrice - rawTP) < stopLevelPoints)
     {
      Print("ORDER REJECTED: Internal stops configuration violates broker structural minimum level boundaries.");
      return false;
     }

   int targetAllowedTrades = 1;
   double initialDistancePoints = MathAbs(targetPrice - rawSL) / m_symbol.Point();
   double finalCalculatedLots = ComputePositionSizingEngine(initialDistancePoints, targetAllowedTrades);

   if(finalCalculatedLots <= 0.0)
     {
      return false;
     }

   // Track concurrency metrics before pushing transaction down pipeline
   if(PositionsTotal() >= (uint)targetAllowedTrades)
     {
      Print("ORDER REJECTED: Concurrency ceiling saturated for current financial tier tier limitations.");
      return false;
     }

   // Execute institutional grade order-splitting mechanisms for heavy trade tickets
   if(finalCalculatedLots > InpMaxSingleOrderLots && AccountInfoDouble(ACCOUNT_EQUITY) >= InpLargeAccountThreshold)
     {
      double remainingLiquidityVolume = finalCalculatedLots;
      Print("ROUTING ORDER SPLITTING: Total volume allocation [", DoubleToString(finalCalculatedLots, 2), "] exceeds limit thresholds. Dispatching separated market orders.");
      
      while(remainingLiquidityVolume > 0.0)
        {
         double allocationChunk = MathMin(remainingLiquidityVolume, InpMaxSingleOrderLots);
         allocationChunk = MathFloor(allocationChunk / m_symbol.VolStep()) * m_symbol.VolStep();
         
         if(allocationChunk < m_symbol.VolMin() 
           {
            break;
           }

         if(!ExecuteBaseTransactionWithRetry(orderType, , rawSL, rawTP))
           {
            Print("CRITICAL ORDER ERROR: Block split execution segment failed during delivery phase.");
            return false;
           }
           
         remainingLiquidityVolume -= allocationChunk;
         if(remainingLiquidityVolume > 0.0)
           {
            Sleep(InpOrderSplitDelaySec * 1000);
            m_symbol.RefreshRates();
           }
        }
      return true;
     }

   return ExecuteBaseTransactionWithRetry(orderType, finalCalculatedLots, rawSL, rawTP);
  }

//+------------------------------------------------------------------+
//| Function: ExecuteBaseTransactionWithRetry                        |
//+------------------------------------------------------------------+
bool ExecuteBaseTransactionWithRetry(ENUM_ORDER_TYPE type, double verifiedLots, double calculatedSL, double calculatedTP)
  {
   int currentAttemptCounter = 0;
   bool processSucceeded = false;

   while(currentAttemptCounter < InpMaxRetries)
     {
      m_symbol.RefreshRates();
      double executionReferencePrice = (type == ORDER_TYPE_BUY) ? m_symbol.Ask() : m_symbol.Bid();
      
      m_trade.SetDeviationInPoints(100); // Sane slippage protection parameter for BTCUSD CFDs
      
      bool sentToken = false;
      if(type == ORDER_TYPE_BUY)
        {
         sentToken = m_trade.Buy(verifiedLots, _Symbol, executionReferencePrice, calculatedSL, calculatedTP);
        }
      else if(type == ORDER_TYPE_SELL)
        {
         sentToken = m_trade.Sell(verifiedLots, _Symbol, executionReferencePrice, calculatedSL, calculatedTP);
        }

      if(sentToken && m_trade.ResultRetcode() == TRADE_RETCODE_DONE)
        {
         Print("EXECUTION SUCCESS: Transaction filled completely. Ticket ID: ", m_trade.ResultOrder());
         processSucceeded = true;
         break;
        }
      
      uint currentErrorCode = m_trade.ResultRetcode();
      Print("EXECUTION WARNING: Order failed on attempt (", currentAttemptCounter + 1, "/", InpMaxRetries, "). Server Code: ", currentErrorCode);

      if(currentErrorCode == TRADE_RETCODE_REQUOTE || currentErrorCode == TRADE_RETCODE_PRICE_CHANGED)
        {
         currentAttemptCounter++;
         Sleep(InpRetryDelayMs);
        }
      else
        {
         // Fail immediately for high-level fatal error architectures (no money, bad stops)
         break;
        }
     }

   return processSucceeded;
  }
//#endregion

//#region Strategic Post-Trade Tracking
//+------------------------------------------------------------------+
//| Function: RegisterClosedDealState                               |
//+------------------------------------------------------------------+
void RegisterClosedDealState(double profitValue)
  {
   if(profitValue < 0.0)
     {
      g_consecutiveLosses++;
      if(g_consecutiveLosses >= InpMaxConsecutiveLosses)
        {
         g_cooldownExpiryTime = TimeCurrent() + 86400; // Enforce structural lockout through next 24H cycle
         Print("COOLDOWN TRIGGERED: Sequential metrics saturated. Execution pipeline isolated until: ", TimeToString(g_cooldownExpiryTime));
        }
     }
   else if(profitValue > 0.0)
     {
      g_consecutiveLosses = 0; // Completely clear sequential performance failure logs
     }
  }

//+------------------------------------------------------------------+
//| Function: OnTester                                               |
//+------------------------------------------------------------------+
double OnTester()
  {
   // Establish optimization criteria using custom metrics
   double historicalProfitFactor = TesterStatistics(STAT_PROFIT_FACTOR);
   double completedTradesCount  = TesterStatistics(STAT_TRADES);
   
   if(completedTradesCount < 30) 
     {
      return historicalProfitFactor * 0.1;
     }

   return historicalProfitFactor * (1.0 + MathLog10(completedTradesCount));
  }
//#endregion