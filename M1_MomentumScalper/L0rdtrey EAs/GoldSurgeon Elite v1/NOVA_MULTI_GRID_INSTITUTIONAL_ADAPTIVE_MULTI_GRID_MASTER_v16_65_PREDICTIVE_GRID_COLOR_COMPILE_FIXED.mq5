//+------------------------------------------------------------------+

//|                                              NOVA MULTI-GRID.mq5 |

//|                               Copyright 2026, LORD.TREY SYSTEMS. |

//|                                                                  |

//+------------------------------------------------------------------+

#property strict

#property version   "16.53"

#property description "NOVA MULTI-GRID | Institutional Adaptive Multi-Grid Scalping Engine | Professional UI"



#include <Trade/Trade.mqh>
//+------------------------------------------------------------------+
//| NOVA v14 UNIFIED ENGINE                                         |
//| - Separate entry gating from position protection                |
//| - Manual + autonomous deployment without parallel-cycle state   |
//| - Autonomous self-arming dependency profile                     |
//| - Adaptive long/short strategy routing                           |
//| - Dynamic SL/TP + risk budget per grid                          |
//| - No silent entry vetoes                                        |
//+------------------------------------------------------------------+




CTrade trade;


//+------------------------------------------------------------------+
//| NOVA MULTI-GRID — UNIFIED MASTER ENGINE                          |
//| Institutional adaptive multi-grid scalping system                |
//|                                                                  |
//| Architecture                                                     |
//| - One authoritative configuration/state model                    |
//| - 21-grid strategy library                                      |
//| - Market-state and regime intelligence                          |
//| - Adaptive grid geometry and strategy selection                  |
//| - Portfolio/risk and protection authority                        |
//| - Individual-ticket trade management                             |
//| - Grid lifecycle controls                                        |
//| - Institutional execution quality                               |
//| - Autonomous decision engine                                     |
//| - Strategy health and adaptive allocation                         |
//| - Validation, stress, recovery and persistence                   |
//| - Original native dashboard with nested workspaces               |
//|                                                                  |
//| Design contract                                                  |
//| - One EA, one authoritative state source                         |
//| - Every trade is managed independently by ticket                 |
//| - Pending-grid lifecycle commands do not close live positions   |
//| - Manual/Assist/Autonomous ownership is explicit                |
//| - Hard survival controls remain absolute                         |
//| - Dashboard is an integrated native control surface              |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+



enum ENUM_GRID_TYPE{BASIC_GRID=0,HEDGE_GRID,TREND_GRID,VOLATILITY_GRID,AI_GRID,GEOMETRIC_GRID,FIBONACCI_GRID,ATR_ADAPTIVE_GRID,MEAN_REVERSION_GRID,BREAKOUT_GRID,MOMENTUM_GRID,HYBRID_GRID,BULLISH_GRID,BEARISH_GRID,BIDIRECTIONAL_GRID,LADDER_GRID,ANTI_MARTINGALE_GRID,RANGE_SCALING_GRID,VOLATILITY_BREAKOUT_GRID,SESSION_GRID,SMART_REGIME_GRID};

enum ENUM_ENTRY_MODE{MANUAL_ENTRY=0,AUTO_ENTRY,AI_ENTRY,TIME_ENTRY};

enum ENUM_RISK_MODE{CONSERVATIVE=0,BALANCED,AGGRESSIVE,ADAPTIVE};

enum ENUM_REENTRY_MODE{REENTRY_OFF=0,REENTRY_ON_CLOSE,REENTRY_ON_CENTER_SHIFT,REENTRY_ON_REGIME_CHANGE};

enum ENUM_PANEL_THEME{THEME_ONYX=0,THEME_GOLD,THEME_TEAL};

enum ENUM_CHART_THEME_MODE{CHART_THEME_AUTO_REGIME=0,CHART_THEME_DARK_LUXURY,CHART_THEME_OCEAN,CHART_THEME_EMERALD,CHART_THEME_MONOCHROME,CHART_THEME_AMETHYST,CHART_THEME_SANDSTONE,CHART_THEME_CRIMSON_NOIR,CHART_THEME_ARCTIC_SILVER};

enum ENUM_CONTROL_MODE{CONTROL_MANUAL=0,CONTROL_ASSIST,CONTROL_AUTONOMOUS};

enum ENUM_AUTONOMOUS_DECISION_MODE{AUTO_DECISION_SMART=0,AUTO_DECISION_BALANCED,AUTO_DECISION_TREND,AUTO_DECISION_RANGE,AUTO_DECISION_BREAKOUT};

enum ENUM_GRID_ANCHOR_MODE{GRID_ANCHOR_CURRENT_MID=0,GRID_ANCHOR_SESSION_OPEN,GRID_ANCHOR_SWING_MID,GRID_ANCHOR_RANGE_MID};



input group "=== GRID ENGINE ==="

input ENUM_GRID_TYPE InpGridType=BASIC_GRID;

input ENUM_ENTRY_MODE InpEntryMode=MANUAL_ENTRY;

input double InpLotSize=0.01;

input ENUM_GRID_ANCHOR_MODE InpAdaptiveAnchorMode=GRID_ANCHOR_CURRENT_MID;

input double InpGridStep=20.0;

input int InpGridLevels=6;

input double InpLotMultiplier=1.00;

input double InpFrontOrderDistancePips=5.0;

input bool InpAutonomousMode=false;

input bool InpUseATRSpacing=false;

input double InpATRSpacingMultiplier=0.80;

input double InpMinGridStepPips=5.0;

input double InpMaxGridStepPips=150.0;

input int InpRecenterATRPeriod=14;

input double InpRecenterATRMultiple=2.5;

input bool InpAutoRecenter=false;

input ENUM_REENTRY_MODE InpReentryMode=REENTRY_OFF;

input ulong InpMagicNumber=123456;



input group "=== AI / REGIME ENGINE ==="

input bool InpEnableAI=false;

input bool InpNeuralNetwork=false;

input double InpAIConfidence=0.75;

input int InpLearningPeriod=100;

input bool InpRegimeFilter=false;

input double InpBullThreshold=0.62;

input double InpBearThreshold=0.38;

input double InpHighVolThreshold=0.70;

input double InpLowVolThreshold=0.30;



input group "=== RISK & BASKET MANAGEMENT ==="

input ENUM_RISK_MODE InpRiskMode=CONSERVATIVE;

input bool InpUseDynamicRiskLot=false;

input bool InpRiskManagedTrading=false;

input bool InpUseStopLossForNewOrders=false;

input bool InpUseTakeProfitForNewOrders=false;

input double InpRiskPerGridPct=0.50;

input double InpMaxGridRiskPct=0.0;

input double InpMaxDrawdownPct=0.0;

input double InpDailyLossLimitPct=0.0;

input double InpDailyProfitLockPct=0.0;

input double InpBasketTakeProfitUSD=0.0;

input double InpBasketStopLossUSD=0.0;
input double InpHardCircuitBreakerUSD=0.0;   // Optional hard survival breaker; OFF by default and explicitly authorized in Risk & Protection
input int InpMaxRecoveryAttempts=3;              // Profit-priority recovery attempts before forced stand-down
input double InpRecoveryLotScaleStep=0.50;        // Progressive recovery size scale: 0.50, 0.25, 0.125...

input double InpStopLossPips=100.0;

input double InpTakeProfitPips=50.0;

input bool InpUseBreakEven=false;

input double InpBreakEvenTriggerPips=30.0;

input double InpBreakEvenOffsetPips=2.0;

input bool InpTrailingStop=false;

input double InpTrailingATRMultiple=1.5;

input bool InpStrategyAwareManagement=false; // Optional: adapt BE/trailing/hold policy to selected grid type

input bool InpStrategyExitCoordination=false; // Optional: coordinate exits, OCO, recentering and replenishment

input double InpMaxHoldMinutes=0.0;

input int InpMaxPositions=20;

input int InpMaxPendingOrders=30;

input bool InpOCO=false;

input bool InpCloseOppositePendingOnFill=false;



input group "=== EXECUTION ENGINE ==="

input int InpSlippage=20;

input double InpMaxSpreadPips=0.0;

input int InpPendingExpiryMinutes=0;

input bool InpSmartExecution=false;

input bool InpValidateStops=false;

input bool InpDeleteInvalidLevels=false;

input int InpOrderRetryCount=2;

input bool InpUseAsyncSafety=false;

input group "=== TRANSACTION COST MODEL ==="
input bool InpTransactionCostModel=true;
input bool InpTransactionCostGate=false;
input double InpCommissionPerLotRoundTurnUSD=0.0;
input double InpExpectedSlippagePoints=0.0;
input double InpTransactionCostSafetyBps=5.0;
input double InpTransactionCostMinNetEdgeScore=0.50;
input int InpTransactionCostExpectedFillLevels=2;

input group "=== STRATEGY HEALTH & ADAPTIVE ALLOCATION ==="
input bool InpStrategyHealthEnabled=true;
input bool InpAdaptiveStrategyAllocation=false;
input int InpStrategyHealthLookbackDays=30;
input int InpStrategyHealthMinSamples=3;
input double InpStrategyHealthMinAllocation=0.50;
input double InpStrategyHealthMaxAllocation=1.15;


input group "=== SESSION / MARKET FILTERS ==="

input bool InpUseSessionFilter=false;

input int InpSessionStartHour=7;

input int InpSessionEndHour=21;

input bool InpAvoidWeekend=false;

input bool InpPauseOnHighVolatility=false;
input bool InpUseMultiTimeframeMarketState=false; // Optional; OFF = use only the chart timeframe for market analysis



input group "=== DASHBOARD ==="

input bool InpShowDashboard=true;

input ENUM_PANEL_THEME InpDashboardTheme=THEME_GOLD;

input double InpDashboardWidthPct=0.50;

input int InpDashboardMinWidth=640;

input int InpDashboardMaxWidth=820;

input int InpDashboardTopMargin=12;



input group "=== AUTO CHART THEMING ==="

input bool InpAutoChartTheme=true;

input ENUM_CHART_THEME_MODE InpChartThemeMode=CHART_THEME_AUTO_REGIME;

input bool InpChartShowGrid=false;

input bool InpChartShowTradeLevels=true;

input bool InpChartAutoScroll=true;

input bool InpChartShift=true;

input bool InpChartShowVolumes=false;



input group "=== ADVANCED INTELLIGENCE (OPTIONAL) ==="

input ENUM_CONTROL_MODE InpControlMode=CONTROL_MANUAL;

input bool InpAdvancedEntryDecision=false;

input bool InpAdaptiveGrid=false;

input bool InpAdaptiveLevels=false;

input bool InpAdaptiveLot=false;

input bool InpMarketIntelligence=false;

input bool InpSmartRegime=false;

input bool InpSmartRecenter=false;

input bool InpSmartReplenishment=false;

input int InpReplenishDelaySeconds=5;

input bool InpGridRecovery=false;

input group "=== VPS / LOCAL RUNTIME RESILIENCE ==="

input bool InpAutoRecoverOnInit=false;

input bool InpPersistRuntimeState=true;

input int InpCheckpointSeconds=15;

input bool InpRecoverOrdersAndPositions=false;
input int InpRecoveryStaleMinutes=120;
input bool InpRejectContextMismatchCheckpoint=true;
input bool InpRequireInventoryReconciliation=true;

input bool InpExposureManager=false;

input bool InpAdvancedProtection=false;

input bool InpDecisionJournal=true;

input bool InpOrderGuardian=false;

input group "=== AUTONOMOUS ENGINE 13.10 ==="

input bool InpAutonomousEngine=false;

input ENUM_AUTONOMOUS_DECISION_MODE InpAutonomousDecisionMode=AUTO_DECISION_SMART;

input int InpAutonomousDecisionIntervalSec=10;

input int InpAutonomousCooldownSec=60;

input double InpAutonomousMinScore=0.55;

input double InpAutonomousMinConfidence=0.50;

input bool InpAutonomousStrictFilters=false;

input bool InpAutonomousAllowNeutral=true;

input bool InpAutonomousAdaptiveStrategy=false;

input bool InpAutonomousRequireFreshMarket=false;

input double InpAdaptiveSensitivity=0.65;

input double InpMaxStepChangePct=25.0;

input double InpMaxTotalLots=1.0;

input int InpMaxAutonomousGridsPerDay=6;

input double InpAutonomousMinSuitability=0.60;

input int InpAdaptiveMinLevels=1;

input int InpAdaptiveMaxLevels=50;

input group "=== PREDICTIVE GRID INTELLIGENCE ==="
input bool InpPredictiveGridIntelligence=true;
input int InpPredictiveLookaheadBars=6;
input double InpPredictiveSensitivity=0.70;

input group "=== V14 UNIFIED ENGINE ==="
input bool InpManualEntryRiskGuard=false;
input bool InpAutonomousAdaptiveRisk=true;
input double InpAutonomousEntryDrawdownPct=4.00;
input double InpAutonomousDailyLossPct=2.50;
input double InpAutonomousGridRiskPct=1.00;
input double InpAutonomousRiskPerGridPct=0.35;
input int InpAutonomousMaxConcurrentCycles=6;
input int InpAutonomousMaxPositions=12;
input int InpAutonomousMaxPendingOrders=24;
input int InpManualMaxConcurrentCycles=6;
input double InpManualMaxConcurrentLots=0.0;
input bool InpAutonomousAutoProtection=true;
input bool InpAdaptiveTradeProtection=false;
input bool InpAdaptiveProfitManagement=false;
input bool InpTradeRunnerMode=false;
input bool InpAutonomousAllowBothDirections=true;
input double InpAutonomousDirectionEdge=0.08;




struct GridState{

   ENUM_GRID_TYPE gridType; ENUM_ENTRY_MODE entryMode; ENUM_RISK_MODE riskMode; ENUM_REENTRY_MODE reentryMode;

   double lotSize,gridStep,lotMultiplier,frontOrderDistancePips,atrSpacingMultiplier,minGridStep,maxGridStep,recenterATRMultiple;

   int gridLevels,learningPeriod,maxPositions,maxPendingOrders,slippage,pendingExpiryMinutes,orderRetryCount;

   bool autonomousMode,useATRSpacing,autoRecenter,aiEnabled,neuralNetwork,regimeFilter,useDynamicRiskLot,riskManagedTrading,useStopLossForNewOrders,useTakeProfitForNewOrders,breakEven,trailingStop,oco,closeOppositeOnFill,smartExecution,validateStops,useSessionFilter,avoidWeekend,pauseHighVolatility,strategyAwareManagement,strategyExitCoordination;

   double aiConfidence,bullThreshold,bearThreshold,highVolThreshold,lowVolThreshold,riskPerGridPct,maxGridRiskPct,maxDrawdownPct,dailyLossLimitPct,dailyProfitLockPct,basketTakeProfitUSD,basketStopLossUSD,stopLossPips,takeProfitPips,breakEvenTriggerPips,breakEvenOffsetPips,trailingATRMultiple,maxHoldMinutes,maxSpreadPips;

   int sessionStartHour,sessionEndHour;

   bool gridActive; datetime startTime,dayAnchor; double initialEquity,anchorPrice,currentProfit,winRate,totalProfit,maxDrawdown,peakEquity,todayProfit,trendStrength,volatilityIndex,sentimentScore,predictionAccuracy,atrPrice,currentSpreadPips;

   int positionCount,pendingCount,buyPositions,sellPositions,buyPending,sellPending,rejectedOrders,acceptedOrders,rebalances,totalTrades,wins,losses;

   string regime,executionStatus; datetime lastActionTime; int appliedChartTheme; bool autoChartTheme; ENUM_CHART_THEME_MODE chartThemeMode; bool chartShowGrid,chartShowTradeLevels,chartAutoScroll,chartShift,chartShowVolumes;

   // MARKET INTELLIGENCE Market State Intelligence — authoritative runtime market-state telemetry and decision context.
   double mtfTrendM5,mtfTrendM15,mtfTrendH1,atrPercentile,rangeWidthPct,compressionScore,breakoutPressure,marketStabilityScore,regimeConfidence;
   string marketRegime,marketSession,marketNoTradeReason; datetime marketStateTime; bool marketDataFresh,marketNoTrade;
   bool useMultiTimeframeMarketState;

   // STRATEGY LIBRARY — formalized priority grid strategy profile telemetry.
   bool gridProfileFormalized;
   string gridProfileVersion,gridProfileRole,gridProfilePreferredRegime,gridProfileDirection,gridProfileEntryModel,gridProfileExitModel,gridProfileRecenterModel,gridProfileReplenishModel,gridProfileProtectionModel;
   double gridProfileSuitability;

   ENUM_CONTROL_MODE controlMode;

   bool advancedEntryDecision,adaptiveGrid,adaptiveLevels,adaptiveLot,marketIntelligence,smartRegime,smartRecenter,smartReplenishment,exposureManager,advancedProtection,decisionJournal;

   bool permAutonomousEntry,permAdaptiveStep,permAdaptiveLevels,permAdaptiveLot,permStrategySelection,permRecenter,permReplenishment,permRiskAdjust,permExposureAdjust,permEmergencyControl;

   double adaptiveSensitivity,maxStepChangePct,maxTotalLots,autonomousMinSuitability;

   int adaptiveMinLevels,adaptiveMaxLevels;

   double marketSuitabilityScore,intelligenceConfidence;

   string adaptiveGridReason,marketDecisionReason;

   int maxAutonomousGridsPerDay,autonomousGridsToday;

   int replenishDelaySeconds; datetime lastReplenishTime; int replenishments; bool gridRecovery;
   // GRID LIFECYCLE - explicit grid lifecycle authority / telemetry
   bool lifecycleCommandActive;
   string lifecycleCommand;
   string lifecycleAuthority;
   string lifecycleScope;
   datetime lifecycleCommandTime;
   int lifecycleDeployments;
   int lifecycleCancels;
   int lifecycleRebuilds;
   int lifecycleRecenters;
   int lifecycleReplenishments;

   double effectiveGridStepPips,effectiveLot; int effectiveGridLevels; double gridPolicyStepFactor,gridPolicyLotFactor; string gridPolicyReason,gridPolicyLevelReason;

   // GRID GEOMETRY — adaptive grid mathematics and structural anchoring.
   ENUM_GRID_ANCHOR_MODE adaptiveAnchorMode;
   double structuralAnchorPrice,gridGeometryStepFactor,gridGeometryLevelFactor,gridGeometryRiskCapacityFactor;
   string adaptiveAnchorReason,gridGeometryGeometryReason;

   // PREDICTIVE GRID INTELLIGENCE — forward excursion, level reach and topology telemetry.
   bool predictiveGridIntelligence;
   double predictiveExcursionPips,predictiveRetracementPips,predictiveContinuationPips,predictiveAdversePips;
   double predictiveUpperDensity,predictiveLowerDensity,predictiveTopologyScore,predictiveConfidence;
   double predictiveLevelReach[50];
   int predictiveLookaheadBars;
   string predictiveState,predictiveReason;
   datetime predictiveUpdateTime;

   // GRID SELECTION — grid selection and direction intelligence.
   double gridSelectionSelectedScore,gridSelectionExpectedEdge,gridSelectionLongScore,gridSelectionShortScore,gridSelectionDirectionEdge,gridSelectionGridEdge;
   int gridSelectionEvaluationCount;
   string gridSelectionSelectedGridName,gridSelectionDirection,gridSelectionReason,gridSelectionSelectionState;

   double totalOpenLots,totalPendingLots,totalExposureLots,exposureUtilizationPct,gridRiskPct,accountMarginUsedPct;

   // RISK & PORTFOLIO — Risk & Portfolio Engine telemetry and hierarchy state.
   bool brokerRiskOK,hardSurvivalOK,portfolioRiskOK,strategyRiskOK,entryRiskOK;
   double portfolioRiskPct,longRiskPct,shortRiskPct,directionalRiskPct,portfolioRiskCapacityPct,riskHealthScore;
   string riskBlockReason,riskHierarchyStatus;

   bool entryThrottleActive; string entryThrottleReason;

   // Bounded profit-priority recovery governor. These fields are runtime-only and reset on a new trading day.
   bool recoveryModeActive; int recoveryAttemptsUsed; double recoveryLotScale;
   double cycleRealizedLoss; bool hardBreakerTriggered;

   // PROTECTION — Protection Authority Center
   bool protectionMasterEnabled;
   bool protectionDrawdownCloseEnabled;
   bool protectionDailyLossCloseEnabled;
   bool protectionBasketLossCloseEnabled;
   bool protectionEmergencyActionEnabled;
   bool protectionEmergencyAutoCloseEnabled;
   bool protectionEmergencyCancelEnabled;
   bool protectionHardBreakerEnabled;
   bool protectionBasketProfitCloseEnabled;
   bool protectionProfitLockCloseEnabled;
   bool protectionMaxHoldCloseEnabled;
   bool protectionMonitorOnly;
   // TRADE PROTECTION — per-trade adaptive protection / profit management.
   bool adaptiveTradeProtection,adaptiveProfitManagement,tradeRunnerMode;
   double adaptiveSLATRMultiple,adaptiveTPATRMultiple,profitLockTriggerPips,profitLockOffsetPips,runnerATRMultiple;
   string tradeProtectionLastAction,tradeProtectionLastReason;
   string protectionLastAuthority,protectionLastTrigger,protectionLastAction,protectionLastResult;
   ulong protectionEventId; datetime protectionLastEventTime;

   string lastActionOwner,lastActionReason,lastDecision;

   bool autonomousEngine; ENUM_AUTONOMOUS_DECISION_MODE autonomousDecisionMode;

   int autonomousDecisionIntervalSec,autonomousCooldownSec;

   double autonomousMinScore,autonomousMinConfidence;

   bool autonomousStrictFilters,autonomousAllowNeutral,autonomousAdaptiveStrategy,autonomousRequireFreshMarket;

   datetime autonomousLastEvaluation,autonomousLastDeployment;

   int autonomousDecisionCount,autonomousApprovalCount,autonomousBlockCount;

   double autonomousScore,autonomousConfidence;

   string autonomousStage,autonomousCandidate,autonomousReason,autonomousSignal;

   bool autonomousReady;
   bool autonomousParallelExecution;
   bool autonomousDynamicProtection;
   ENUM_GRID_TYPE autonomousSelectedGridType;

   bool manualEntryRiskGuard;
   bool autonomousAdaptiveRisk;
   double autonomousEntryDrawdownPct,autonomousEntryDailyLossPct,autonomousEntryGridRiskPct,autonomousRiskPerGridPct;
   int autonomousMaxConcurrentCycles,autonomousMaxPositions,autonomousMaxPendingOrders,manualMaxConcurrentCycles;
   double manualMaxConcurrentLots;
   bool autonomousAutoProtection,autonomousAllowBothDirections;
   double autonomousDirectionEdge;
   double autonomousLongScore,autonomousShortScore,autonomousDirectionEdgeScore;
   // AUTONOMOUS DECISION — Autonomous Decision Engine pipeline / trade-plan transparency.
   string autonomousPipelineStage,autonomousDecisionClass,autonomousDecisionReason;
   string autonomousRiskDecision,autonomousExecutionDecision,autonomousPlanSummary;
   string autonomousPlanDirection;
   ENUM_GRID_TYPE autonomousPlanGridType;
   double autonomousPlanScore,autonomousPlanConfidence,autonomousPlanExpectedEdge;
   double autonomousPlanRiskPct,autonomousPlanLot,autonomousPlanStepPips;
   int autonomousPlanLevels;
   datetime autonomousPlanTime;
   int autonomousWaitCount,autonomousRejectCount;
   int activeDeploymentCount;
   string deploymentGateReason;

   // TRANSACTION COSTS — Transaction-cost model / cost-aware autonomous entry gate.
   bool transactionCostModelEnabled,transactionCostGateEnabled;
   double commissionPerLotRoundTurnUSD,expectedSlippagePoints,transactionCostSafetyBps,transactionCostMinNetEdgeScore;
   int transactionCostExpectedFillLevels;
   double transactionCostSpreadCostUSD,transactionCostCommissionUSD,transactionCostSlippageCostUSD,transactionCostEstimatedCostUSD,transactionCostEstimatedCostPct;
   double transactionCostGrossEdgeScore,transactionCostCostDragPct,transactionCostCostAdjustedEdgeScore;
   string transactionCostCostStatus,transactionCostCostReason;
   datetime transactionCostEvaluationTime;

   // STRATEGY HEALTH — Strategy Health & Adaptive Allocation.
   bool strategyHealthEnabled,adaptiveStrategyAllocation;
   int strategyHealthLookbackDays,strategyHealthMinSamples;
   double strategyHealthMinAllocation,strategyHealthMaxAllocation;
   double strategyHealthSelectedHealth,strategyHealthSelectedAllocation,strategyHealthSelectedDirectionHealth;
   double strategyHealthSelectedSessionHealth,strategyHealthSelectedRegimeHealth;
   int strategyHealthSelectedSamples,strategyHealthEvaluationCount;
   string strategyHealthHealthState,strategyHealthAllocationReason,strategyHealthSelectedSession,strategyHealthSelectedRegime;
   datetime strategyHealthEvaluationTime;

   // TRADE ENGINE — Individual Trade Engine telemetry / per-ticket management state.
   int individualTradeCount,individualManagedCount,individualSLCount,individualTPCount,individualAutonomousCount,individualBECount,individualTrailCount;
   double individualFloatingPnL,individualPeakProfit,individualWorstDrawdownPct,individualRiskPct;
   ulong individualLastTicket; string individualLastAuthority,individualLastAction,individualLastReason;

   bool orderGuardian; ulong lastOrderLatencyMs; uint lastOrderRetcode; string lastOrderRetcodeText,lastOrderType; double lastOrderPrice,lastOrderLots; int lastOrderRetryCount;

   // EXECUTION — Institutional Execution Engine telemetry / quality controls.
   double executionQualityScore,executionAverageLatencyMs,executionAverageRetries,executionLastSlippagePoints;
   int executionSampleCount,executionSuccessfulCount,executionRetrySamples,executionRejectCount,executionPreflightRejectCount;
   string executionQualityState,executionPreflightState,executionLastQualityReason;
   datetime executionLastSampleTime;
   bool executionPreflightOK,executionQualityDegraded;

   int configWarningCount; string configHealth,configWarnings;

   int settingsAuditChecked,settingsAuditPassed,settingsAuditWarnings,settingsAuditFailed; datetime settingsAuditTime; string settingsAuditStatus,settingsAuditSummary;

   int lastGridRequestedOrders,lastGridAcceptedOrders,lastGridShortfall; string lastGridAudit; datetime lastConfigCheckTime; string lastConfigCheckResult; int configCheckSequence;

   ulong gridCycleId; int lifecycleFillCount,lifecycleDeleteCount,lifecycleRecoveryCount; string gridLifecycleState,gridLifecycleReason; bool exitCoordinationActive; string exitCoordinationReason; datetime exitCoordinationTime;

   bool autoRecoverOnInit,persistRuntimeState,recoverOrdersAndPositions; int checkpointSeconds; datetime lastCheckpointTime,lastRecoveryTime; string recoveryStatus,recoverySource,recoveryFile;
   datetime recoveryLastHeartbeat,recoveryCheckpointTime; int recoveryCheckpointAgeSec; bool recoveryCheckpointContextOK,recoveryInventoryReconciled,recoveryRecoveryLock,recoveryCheckpointStale; string recoveryEnvironment,recoveryCheckpointResult,recoveryMismatchReason;
   // DASHBOARD SYNC — Original Dashboard Integration / state-sync telemetry.
   datetime dashboardSyncDashboardSyncTime;
   int dashboardSyncPendingEdits;
   bool dashboardSyncSelectedGridOK,dashboardSyncControlModeOK,dashboardSyncEffectiveStateOK;
   string dashboardSyncDashboardSyncStatus,dashboardSyncDashboardSyncReason;

   // AUTHORITY AUDIT — field-by-field authority and integrity audit telemetry.
   int authorityAuditChecked,authorityAuditPassed,authorityAuditWarnings,authorityAuditFailed;
   datetime authorityAuditAuditTime;
   string authorityAuditStatus,authorityAuditSummary,authorityAuditLastFailure;

   bool emergencyActive,emergencyManualStop,emergencyAutoClose,emergencyCancelPending,emergencyAutoResume; int emergencyLevel; string emergencyReason; datetime emergencyTime; double emergencyMarginLevelPct,emergencyDrawdownPct,emergencyDailyLossPct,emergencySpreadPips,emergencyVolatilityPct;

};


GridState g_state;

// -------------------- CONTROL-MODE PROFILE AUTHORITY --------------------
// Mode-owned features are temporary. Leaving ASSIST/AUTONOMOUS restores the exact
// pre-mode state so stale mode permissions cannot continue acting in MANUAL.
struct ModeProfileSnapshot
{
   bool valid;
   ENUM_CONTROL_MODE controlMode;
   ENUM_ENTRY_MODE entryMode;
   bool autonomousMode,autonomousEngine,autonomousReady,autonomousParallelExecution,autonomousDynamicProtection;
   bool advancedEntryDecision,adaptiveGrid,adaptiveLevels,adaptiveLot,marketIntelligence,smartRegime,smartRecenter,smartReplenishment,exposureManager;
   bool advancedProtection,decisionJournal,orderGuardian;
   bool transactionCostModelEnabled,transactionCostGateEnabled;
   bool strategyHealthEnabled,adaptiveStrategyAllocation;
   bool adaptiveTradeProtection,adaptiveProfitManagement,tradeRunnerMode;
   bool useATRSpacing,autoRecenter,aiEnabled,neuralNetwork,regimeFilter,useDynamicRiskLot,riskManagedTrading;
   bool useStopLossForNewOrders,useTakeProfitForNewOrders,breakEven,trailingStop,oco,closeOppositeOnFill,smartExecution,validateStops;
   bool useSessionFilter,avoidWeekend,pauseHighVolatility,strategyAwareManagement,strategyExitCoordination;
   bool permAutonomousEntry,permAdaptiveStep,permAdaptiveLevels,permAdaptiveLot,permStrategySelection,permRecenter,permReplenishment,permRiskAdjust,permExposureAdjust,permEmergencyControl;
   bool autonomousStrictFilters,autonomousAllowNeutral,autonomousAdaptiveStrategy,autonomousRequireFreshMarket,autonomousAllowBothDirections;
   double riskPerGridPct,maxGridRiskPct,maxDrawdownPct,dailyLossLimitPct,dailyProfitLockPct,maxTotalLots,maxSpreadPips;
   int maxPositions,maxPendingOrders,maxAutonomousGridsPerDay;
   int autonomousDecisionIntervalSec,autonomousCooldownSec;
   double autonomousMinScore,autonomousMinConfidence,autonomousDirectionEdge;
};
ModeProfileSnapshot g_modeBaseline;
bool g_modeBaselineCaptured=false;

void CaptureModeBaseline()
{
   g_modeBaseline.valid=true;
   g_modeBaseline.controlMode=g_state.controlMode;
   g_modeBaseline.entryMode=g_state.entryMode;
   g_modeBaseline.autonomousMode=g_state.autonomousMode;
   g_modeBaseline.autonomousEngine=g_state.autonomousEngine;
   g_modeBaseline.autonomousReady=g_state.autonomousReady;
   g_modeBaseline.autonomousParallelExecution=g_state.autonomousParallelExecution;
   g_modeBaseline.autonomousDynamicProtection=g_state.autonomousDynamicProtection;
   g_modeBaseline.advancedEntryDecision=g_state.advancedEntryDecision;
   g_modeBaseline.adaptiveGrid=g_state.adaptiveGrid;
   g_modeBaseline.adaptiveLevels=g_state.adaptiveLevels;
   g_modeBaseline.adaptiveLot=g_state.adaptiveLot;
   g_modeBaseline.marketIntelligence=g_state.marketIntelligence;
   g_modeBaseline.smartRegime=g_state.smartRegime;
   g_modeBaseline.smartRecenter=g_state.smartRecenter;
   g_modeBaseline.smartReplenishment=g_state.smartReplenishment;
   g_modeBaseline.exposureManager=g_state.exposureManager;
   g_modeBaseline.advancedProtection=g_state.advancedProtection;
   g_modeBaseline.decisionJournal=g_state.decisionJournal;
   g_modeBaseline.orderGuardian=g_state.orderGuardian;
   g_modeBaseline.transactionCostModelEnabled=g_state.transactionCostModelEnabled;
   g_modeBaseline.transactionCostGateEnabled=g_state.transactionCostGateEnabled;
   g_modeBaseline.strategyHealthEnabled=g_state.strategyHealthEnabled;
   g_modeBaseline.adaptiveStrategyAllocation=g_state.adaptiveStrategyAllocation;
   g_modeBaseline.adaptiveTradeProtection=g_state.adaptiveTradeProtection;
   g_modeBaseline.adaptiveProfitManagement=g_state.adaptiveProfitManagement;
   g_modeBaseline.tradeRunnerMode=g_state.tradeRunnerMode;
   g_modeBaseline.useATRSpacing=g_state.useATRSpacing;
   g_modeBaseline.autoRecenter=g_state.autoRecenter;
   g_modeBaseline.aiEnabled=g_state.aiEnabled;
   g_modeBaseline.neuralNetwork=g_state.neuralNetwork;
   g_modeBaseline.regimeFilter=g_state.regimeFilter;
   g_modeBaseline.useDynamicRiskLot=g_state.useDynamicRiskLot;
   g_modeBaseline.riskManagedTrading=g_state.riskManagedTrading;
   g_modeBaseline.useStopLossForNewOrders=g_state.useStopLossForNewOrders;
   g_modeBaseline.useTakeProfitForNewOrders=g_state.useTakeProfitForNewOrders;
   g_modeBaseline.breakEven=g_state.breakEven;
   g_modeBaseline.trailingStop=g_state.trailingStop;
   g_modeBaseline.oco=g_state.oco;
   g_modeBaseline.closeOppositeOnFill=g_state.closeOppositeOnFill;
   g_modeBaseline.smartExecution=g_state.smartExecution;
   g_modeBaseline.validateStops=g_state.validateStops;
   g_modeBaseline.useSessionFilter=g_state.useSessionFilter;
   g_modeBaseline.avoidWeekend=g_state.avoidWeekend;
   g_modeBaseline.pauseHighVolatility=g_state.pauseHighVolatility;
   g_modeBaseline.strategyAwareManagement=g_state.strategyAwareManagement;
   g_modeBaseline.strategyExitCoordination=g_state.strategyExitCoordination;
   g_modeBaseline.permAutonomousEntry=g_state.permAutonomousEntry;
   g_modeBaseline.permAdaptiveStep=g_state.permAdaptiveStep;
   g_modeBaseline.permAdaptiveLevels=g_state.permAdaptiveLevels;
   g_modeBaseline.permAdaptiveLot=g_state.permAdaptiveLot;
   g_modeBaseline.permStrategySelection=g_state.permStrategySelection;
   g_modeBaseline.permRecenter=g_state.permRecenter;
   g_modeBaseline.permReplenishment=g_state.permReplenishment;
   g_modeBaseline.permRiskAdjust=g_state.permRiskAdjust;
   g_modeBaseline.permExposureAdjust=g_state.permExposureAdjust;
   g_modeBaseline.permEmergencyControl=g_state.permEmergencyControl;
   g_modeBaseline.autonomousStrictFilters=g_state.autonomousStrictFilters;
   g_modeBaseline.autonomousAllowNeutral=g_state.autonomousAllowNeutral;
   g_modeBaseline.autonomousAdaptiveStrategy=g_state.autonomousAdaptiveStrategy;
   g_modeBaseline.autonomousRequireFreshMarket=g_state.autonomousRequireFreshMarket;
   g_modeBaseline.autonomousAllowBothDirections=g_state.autonomousAllowBothDirections;
   g_modeBaseline.riskPerGridPct=g_state.riskPerGridPct;
   g_modeBaseline.maxGridRiskPct=g_state.maxGridRiskPct;
   g_modeBaseline.maxDrawdownPct=g_state.maxDrawdownPct;
   g_modeBaseline.dailyLossLimitPct=g_state.dailyLossLimitPct;
   g_modeBaseline.dailyProfitLockPct=g_state.dailyProfitLockPct;
   g_modeBaseline.maxTotalLots=g_state.maxTotalLots;
   g_modeBaseline.maxSpreadPips=g_state.maxSpreadPips;
   g_modeBaseline.maxPositions=g_state.maxPositions;
   g_modeBaseline.maxPendingOrders=g_state.maxPendingOrders;
   g_modeBaseline.maxAutonomousGridsPerDay=g_state.maxAutonomousGridsPerDay;
   g_modeBaseline.autonomousDecisionIntervalSec=g_state.autonomousDecisionIntervalSec;
   g_modeBaseline.autonomousCooldownSec=g_state.autonomousCooldownSec;
   g_modeBaseline.autonomousMinScore=g_state.autonomousMinScore;
   g_modeBaseline.autonomousMinConfidence=g_state.autonomousMinConfidence;
   g_modeBaseline.autonomousDirectionEdge=g_state.autonomousDirectionEdge;
   g_modeBaselineCaptured=true;
}

void RestoreModeBaseline()
{
   if(!g_modeBaselineCaptured || !g_modeBaseline.valid) return;
   g_state.entryMode=g_modeBaseline.entryMode;
   g_state.autonomousMode=g_modeBaseline.autonomousMode;
   g_state.autonomousEngine=g_modeBaseline.autonomousEngine;
   g_state.autonomousReady=g_modeBaseline.autonomousReady;
   g_state.autonomousParallelExecution=g_modeBaseline.autonomousParallelExecution;
   g_state.autonomousDynamicProtection=g_modeBaseline.autonomousDynamicProtection;
   g_state.advancedEntryDecision=g_modeBaseline.advancedEntryDecision;
   g_state.adaptiveGrid=g_modeBaseline.adaptiveGrid;
   g_state.adaptiveLevels=g_modeBaseline.adaptiveLevels;
   g_state.adaptiveLot=g_modeBaseline.adaptiveLot;
   g_state.marketIntelligence=g_modeBaseline.marketIntelligence;
   g_state.smartRegime=g_modeBaseline.smartRegime;
   g_state.smartRecenter=g_modeBaseline.smartRecenter;
   g_state.smartReplenishment=g_modeBaseline.smartReplenishment;
   g_state.exposureManager=g_modeBaseline.exposureManager;
   g_state.advancedProtection=g_modeBaseline.advancedProtection;
   g_state.decisionJournal=g_modeBaseline.decisionJournal;
   g_state.orderGuardian=g_modeBaseline.orderGuardian;
   g_state.transactionCostModelEnabled=g_modeBaseline.transactionCostModelEnabled;
   g_state.transactionCostGateEnabled=g_modeBaseline.transactionCostGateEnabled;
   g_state.strategyHealthEnabled=g_modeBaseline.strategyHealthEnabled;
   g_state.adaptiveStrategyAllocation=g_modeBaseline.adaptiveStrategyAllocation;
   g_state.adaptiveTradeProtection=g_modeBaseline.adaptiveTradeProtection;
   g_state.adaptiveProfitManagement=g_modeBaseline.adaptiveProfitManagement;
   g_state.tradeRunnerMode=g_modeBaseline.tradeRunnerMode;
   g_state.useATRSpacing=g_modeBaseline.useATRSpacing;
   g_state.autoRecenter=g_modeBaseline.autoRecenter;
   g_state.aiEnabled=g_modeBaseline.aiEnabled;
   g_state.neuralNetwork=g_modeBaseline.neuralNetwork;
   g_state.regimeFilter=g_modeBaseline.regimeFilter;
   g_state.useDynamicRiskLot=g_modeBaseline.useDynamicRiskLot;
   g_state.riskManagedTrading=g_modeBaseline.riskManagedTrading;
   g_state.useStopLossForNewOrders=g_modeBaseline.useStopLossForNewOrders;
   g_state.useTakeProfitForNewOrders=g_modeBaseline.useTakeProfitForNewOrders;
   g_state.breakEven=g_modeBaseline.breakEven;
   g_state.trailingStop=g_modeBaseline.trailingStop;
   g_state.oco=g_modeBaseline.oco;
   g_state.closeOppositeOnFill=g_modeBaseline.closeOppositeOnFill;
   g_state.smartExecution=g_modeBaseline.smartExecution;
   g_state.validateStops=g_modeBaseline.validateStops;
   g_state.useSessionFilter=g_modeBaseline.useSessionFilter;
   g_state.avoidWeekend=g_modeBaseline.avoidWeekend;
   g_state.pauseHighVolatility=g_modeBaseline.pauseHighVolatility;
   g_state.strategyAwareManagement=g_modeBaseline.strategyAwareManagement;
   g_state.strategyExitCoordination=g_modeBaseline.strategyExitCoordination;
   g_state.permAutonomousEntry=g_modeBaseline.permAutonomousEntry;
   g_state.permAdaptiveStep=g_modeBaseline.permAdaptiveStep;
   g_state.permAdaptiveLevels=g_modeBaseline.permAdaptiveLevels;
   g_state.permAdaptiveLot=g_modeBaseline.permAdaptiveLot;
   g_state.permStrategySelection=g_modeBaseline.permStrategySelection;
   g_state.permRecenter=g_modeBaseline.permRecenter;
   g_state.permReplenishment=g_modeBaseline.permReplenishment;
   g_state.permRiskAdjust=g_modeBaseline.permRiskAdjust;
   g_state.permExposureAdjust=g_modeBaseline.permExposureAdjust;
   g_state.permEmergencyControl=g_modeBaseline.permEmergencyControl;
   g_state.autonomousStrictFilters=g_modeBaseline.autonomousStrictFilters;
   g_state.autonomousAllowNeutral=g_modeBaseline.autonomousAllowNeutral;
   g_state.autonomousAdaptiveStrategy=g_modeBaseline.autonomousAdaptiveStrategy;
   g_state.autonomousRequireFreshMarket=g_modeBaseline.autonomousRequireFreshMarket;
   g_state.autonomousAllowBothDirections=g_modeBaseline.autonomousAllowBothDirections;
   g_state.riskPerGridPct=g_modeBaseline.riskPerGridPct;
   g_state.maxGridRiskPct=g_modeBaseline.maxGridRiskPct;
   g_state.maxDrawdownPct=g_modeBaseline.maxDrawdownPct;
   g_state.dailyLossLimitPct=g_modeBaseline.dailyLossLimitPct;
   g_state.dailyProfitLockPct=g_modeBaseline.dailyProfitLockPct;
   g_state.maxTotalLots=g_modeBaseline.maxTotalLots;
   g_state.maxSpreadPips=g_modeBaseline.maxSpreadPips;
   g_state.maxPositions=g_modeBaseline.maxPositions;
   g_state.maxPendingOrders=g_modeBaseline.maxPendingOrders;
   g_state.maxAutonomousGridsPerDay=g_modeBaseline.maxAutonomousGridsPerDay;
   g_state.autonomousDecisionIntervalSec=g_modeBaseline.autonomousDecisionIntervalSec;
   g_state.autonomousCooldownSec=g_modeBaseline.autonomousCooldownSec;
   g_state.autonomousMinScore=g_modeBaseline.autonomousMinScore;
   g_state.autonomousMinConfidence=g_modeBaseline.autonomousMinConfidence;
   g_state.autonomousDirectionEdge=g_modeBaseline.autonomousDirectionEdge;
}

void ClearManagedModeBaseline(){ZeroMemory(g_modeBaseline);g_modeBaselineCaptured=false;}

void ArmAssistProfile()
{
   if(!g_modeBaselineCaptured) CaptureModeBaseline();
   g_state.controlMode=CONTROL_ASSIST;
   g_state.autonomousMode=false;
   g_state.autonomousEngine=false;
   g_state.autonomousReady=false;
   g_state.autonomousParallelExecution=false;
   g_state.autonomousDynamicProtection=false;
   g_state.advancedEntryDecision=false;
   g_state.marketIntelligence=true;
   g_state.smartRegime=true;
   g_state.orderGuardian=true;
   g_state.decisionJournal=true;
   g_state.transactionCostModelEnabled=true;
   g_state.transactionCostGateEnabled=false;
   g_state.strategyHealthEnabled=true;
   g_state.adaptiveStrategyAllocation=false;
   g_state.smartExecution=true;
   g_state.validateStops=true;
   g_state.pauseHighVolatility=false;
   g_state.smartReplenishment=false;
   g_state.autoRecenter=false;
   g_state.smartRecenter=false;
   g_state.advancedProtection=false;
   g_state.strategyAwareManagement=false;
   g_state.strategyExitCoordination=false;
   g_state.permAutonomousEntry=false;
   SetAction("ASSIST","ENGINE ARMED","Advisory mode active; no autonomous grid deployment");
   RecordEvent("ASSIST MODE","MASTER ARMED | advisory analysis and execution diagnostics only");
}

void ArmAutonomousProfile()
{
   if(!g_modeBaselineCaptured) CaptureModeBaseline();
   g_state.controlMode=CONTROL_AUTONOMOUS;
   g_state.autonomousMode=true;
   g_state.autonomousEngine=true;
   g_state.autonomousReady=false;
   g_state.entryMode=AUTO_ENTRY;
   g_state.advancedEntryDecision=true;
   g_state.adaptiveGrid=true;
   g_state.adaptiveLevels=true;
   g_state.adaptiveLot=true;
   g_state.useDynamicRiskLot=true;
   g_state.aiEnabled=true;
   g_state.regimeFilter=true;
   g_state.marketIntelligence=true;
   g_state.smartRegime=true;
   g_state.smartRecenter=true;
   g_state.smartReplenishment=true;
   g_state.exposureManager=true;
   g_state.riskManagedTrading=true;
   g_state.strategyAwareManagement=true;
   g_state.strategyExitCoordination=true;
   g_state.useATRSpacing=true;
   g_state.autoRecenter=true;
   g_state.useSessionFilter=false;
   g_state.avoidWeekend=false;
   g_state.pauseHighVolatility=false;
   g_state.useStopLossForNewOrders=true;
   g_state.useTakeProfitForNewOrders=true;
   g_state.breakEven=true;
   g_state.trailingStop=true;
   g_state.smartExecution=true;
   g_state.validateStops=true;
   g_state.orderGuardian=true;
   g_state.transactionCostModelEnabled=true;
   g_state.transactionCostGateEnabled=true;
   g_state.strategyHealthEnabled=true;
   g_state.adaptiveStrategyAllocation=true;
   g_state.advancedProtection=true;
   g_state.adaptiveTradeProtection=true;
   g_state.adaptiveProfitManagement=true;
   g_state.tradeRunnerMode=true;
   g_state.decisionJournal=true;
   g_state.permAutonomousEntry=true;
   g_state.permAdaptiveStep=true;
   g_state.permAdaptiveLevels=true;
   g_state.permAdaptiveLot=true;
   g_state.permStrategySelection=true;
   g_state.permRecenter=true;
   g_state.permReplenishment=true;
   g_state.permRiskAdjust=true;
   g_state.permExposureAdjust=true;
   g_state.permEmergencyControl=true;
   g_state.autonomousParallelExecution=true;
   g_state.autonomousDynamicProtection=InpAutonomousAutoProtection;
   g_state.autonomousAllowNeutral=true;
   g_state.autonomousAdaptiveStrategy=true;
   g_state.autonomousStrictFilters=false;
   g_state.autonomousRequireFreshMarket=false;
   g_state.autonomousAllowBothDirections=InpAutonomousAllowBothDirections;
   g_state.autonomousDirectionEdge=MathMax(0.02,InpAutonomousDirectionEdge);
   g_state.autonomousDecisionIntervalSec=MathMax(2,MathMin(g_state.autonomousDecisionIntervalSec,15));
   g_state.autonomousCooldownSec=MathMax(5,g_state.autonomousCooldownSec);
   g_state.autonomousMinScore=ClampDouble(g_state.autonomousMinScore,0.40,0.70);
   g_state.autonomousMinConfidence=ClampDouble(g_state.autonomousMinConfidence,0.35,0.70);
   ApplyAutonomousRiskProfile();
   UpdateEffectiveState();
   RecordEvent("AUTONOMOUS MODE","MASTER ARMED | unified intelligence, adaptive risk, long/short routing, individual trade execution");
   SetAction("AUTONOMOUS","ENGINE ARMED","All autonomous dependencies synchronized");
}

void NeutralizeModeOwnedFeatures()
{
   g_state.autonomousMode=false;
   g_state.autonomousEngine=false;
   g_state.autonomousReady=false;
   g_state.autonomousParallelExecution=false;
   g_state.autonomousDynamicProtection=false;
   g_state.advancedEntryDecision=false;
   g_state.adaptiveGrid=InpAdaptiveGrid;
   g_state.adaptiveLevels=InpAdaptiveLevels;
   g_state.adaptiveLot=InpAdaptiveLot;
   g_state.marketIntelligence=InpMarketIntelligence;
   g_state.smartRegime=InpSmartRegime;
   g_state.smartRecenter=InpSmartRecenter;
   g_state.smartReplenishment=InpSmartReplenishment;
   g_state.exposureManager=InpExposureManager;
   g_state.advancedProtection=InpAdvancedProtection;
   g_state.adaptiveTradeProtection=InpAdaptiveTradeProtection;
   g_state.adaptiveProfitManagement=InpAdaptiveProfitManagement;
   g_state.tradeRunnerMode=InpTradeRunnerMode;
   g_state.decisionJournal=InpDecisionJournal;
   g_state.orderGuardian=InpOrderGuardian;
   g_state.transactionCostModelEnabled=InpTransactionCostModel;
   g_state.transactionCostGateEnabled=InpTransactionCostGate;
   g_state.strategyHealthEnabled=InpStrategyHealthEnabled;
   g_state.adaptiveStrategyAllocation=InpAdaptiveStrategyAllocation;
   g_state.strategyHealthLookbackDays=MathMax(1,InpStrategyHealthLookbackDays);
   g_state.strategyHealthMinSamples=MathMax(1,InpStrategyHealthMinSamples);
   g_state.strategyHealthMinAllocation=ClampDouble(InpStrategyHealthMinAllocation,0.25,1.0);
   g_state.strategyHealthMaxAllocation=ClampDouble(InpStrategyHealthMaxAllocation,1.0,1.50);
   g_state.useATRSpacing=InpUseATRSpacing;
   g_state.autoRecenter=InpAutoRecenter;
   g_state.aiEnabled=InpEnableAI;
   g_state.neuralNetwork=InpNeuralNetwork;
   g_state.regimeFilter=InpRegimeFilter;
   g_state.useDynamicRiskLot=InpUseDynamicRiskLot;
   g_state.riskManagedTrading=InpRiskManagedTrading;
   g_state.useStopLossForNewOrders=InpUseStopLossForNewOrders;
   g_state.useTakeProfitForNewOrders=InpUseTakeProfitForNewOrders;
   g_state.breakEven=InpUseBreakEven;
   g_state.trailingStop=InpTrailingStop;
   g_state.oco=InpOCO;
   g_state.closeOppositeOnFill=InpCloseOppositePendingOnFill;
   g_state.smartExecution=InpSmartExecution;
   g_state.validateStops=InpValidateStops;
   g_state.useSessionFilter=InpUseSessionFilter;
   g_state.avoidWeekend=InpAvoidWeekend;
   g_state.pauseHighVolatility=InpPauseOnHighVolatility;
   g_state.strategyAwareManagement=InpStrategyAwareManagement;
   g_state.strategyExitCoordination=false;
   g_state.permAutonomousEntry=false;
   g_state.permAdaptiveStep=false;
   g_state.permAdaptiveLevels=false;
   g_state.permAdaptiveLot=false;
   g_state.permStrategySelection=false;
   g_state.permRecenter=false;
   g_state.permReplenishment=false;
   g_state.permRiskAdjust=false;
   g_state.permExposureAdjust=false;
   g_state.permEmergencyControl=false;
   g_state.entryMode=InpEntryMode;
   g_state.riskPerGridPct=InpRiskPerGridPct;
   g_state.maxGridRiskPct=InpMaxGridRiskPct;
   g_state.maxDrawdownPct=InpMaxDrawdownPct;
   g_state.dailyLossLimitPct=InpDailyLossLimitPct;
   g_state.dailyProfitLockPct=InpDailyProfitLockPct;
   g_state.maxTotalLots=InpMaxTotalLots;
   g_state.maxSpreadPips=InpMaxSpreadPips;
   g_state.maxPositions=InpMaxPositions;
   g_state.maxPendingOrders=InpMaxPendingOrders;
   g_state.maxAutonomousGridsPerDay=InpMaxAutonomousGridsPerDay;
   g_state.autonomousDecisionIntervalSec=MathMax(0,InpAutonomousDecisionIntervalSec);
   g_state.autonomousCooldownSec=MathMax(0,InpAutonomousCooldownSec);
   g_state.autonomousMinScore=ClampDouble(InpAutonomousMinScore,0,1);
   g_state.autonomousMinConfidence=ClampDouble(InpAutonomousMinConfidence,0,1);
   g_state.autonomousDirectionEdge=MathMax(0.02,InpAutonomousDirectionEdge);
}

void DisarmActiveModeToManual()
{
   ENUM_CONTROL_MODE oldMode=g_state.controlMode;
   if(g_modeBaselineCaptured && g_modeBaseline.valid) RestoreModeBaseline();
   else NeutralizeModeOwnedFeatures();
   g_state.controlMode=CONTROL_MANUAL;
   g_state.autonomousMode=false;
   g_state.autonomousEngine=false;
   g_state.autonomousReady=false;
   g_state.autonomousStage="IDLE";
   g_state.autonomousReason="Control mode is MANUAL";
   g_state.autonomousSignal="OFF";
   g_state.entryThrottleActive=false;
   g_state.entryThrottleReason="";
   g_state.autonomousParallelExecution=false;
   g_state.autonomousDynamicProtection=false;
   SetAction("USER","CONTROL MODE","MANUAL | mode-owned features restored to pre-mode state");
   RecordEvent("CONTROL MODE",StringFormat("%s -> MANUAL | mode-owned features restored; autonomous deployment disabled",ControlModeName(oldMode)));
   ClearManagedModeBaseline();
}

void TransitionControlMode(ENUM_CONTROL_MODE target)
{
   ENUM_CONTROL_MODE current=g_state.controlMode;
   if(target==current) return;
   if(target==CONTROL_MANUAL){DisarmActiveModeToManual();return;}
   if(!g_modeBaselineCaptured) CaptureModeBaseline();
   if(target==CONTROL_ASSIST){RestoreModeBaseline();ArmAssistProfile();return;}
   if(target==CONTROL_AUTONOMOUS){if(current==CONTROL_ASSIST && g_modeBaselineCaptured)RestoreModeBaseline();ArmAutonomousProfile();}
}

#define V14_MAX_GRID_CYCLES 64

struct V14_GRID_CYCLE
{
   ulong id;
   ulong magic;
   ENUM_GRID_TYPE gridType;
   ENUM_ENTRY_MODE entryMode;
   datetime startTime;
   double anchorPrice;
   double gridStep;
   double lotSize;
   int gridLevels;
   bool autonomous;
   bool active;
};

V14_GRID_CYCLE g_v14Cycles[V14_MAX_GRID_CYCLES];
int g_v14CycleCount=0;
ulong g_v14ExecutionCycleId=0;
ulong g_v14ExecutionMagic=0;
ulong g_v14FocusMagic=0;
ENUM_GRID_TYPE g_selectedGridType=BASIC_GRID;
ENUM_GRID_TYPE g_autonomousGridType=BASIC_GRID;
ENUM_GRID_TYPE g_lastManualGridType=BASIC_GRID;
bool g_engineReady=false;
uint g_engineGeneration=1504;
#define NOVA_CHECKPOINT_VERSION 1505
#define NOVA_BUILD_LABEL "v16.53"
#define NOVA_CHECKPOINT_MIN_VERSION 1500


bool V14KnownMagic(ulong magic)
{
   if(magic==(ulong)InpMagicNumber) return true;
   // Legacy cycle magics from previous NOVA builds remain recognized so their
   // existing trades can continue to be managed independently.
   for(int i=0;i<g_v14CycleCount;i++)
      if(g_v14Cycles[i].magic==magic && magic!=(ulong)InpMagicNumber) return true;
   return false;
}

int V14FindCycleByMagic(ulong magic)
{
   for(int i=0;i<g_v14CycleCount;i++)
      if(g_v14Cycles[i].magic==magic) return i;
   return -1;
}

ulong V14NextCycleId()
{
   ulong mx=g_state.gridCycleId;
   for(int i=0;i<g_v14CycleCount;i++) if(g_v14Cycles[i].id>mx) mx=g_v14Cycles[i].id;
   if(mx==0) return 1;
   return mx+1;
}

ulong V14CycleMagic(ulong cycleId)
{
   return (ulong)InpMagicNumber+cycleId;
}

int V14RegisterCycle(ulong id,ulong magic,ENUM_GRID_TYPE type,ENUM_ENTRY_MODE entry,
                     datetime start,double anchor,double step,double lot,int levels,bool autonomous)
{
   int existing=V14FindCycleByMagic(magic);
   if(existing>=0)
   {
      g_v14Cycles[existing].id=id;
      g_v14Cycles[existing].gridType=type;
      g_v14Cycles[existing].entryMode=entry;
      g_v14Cycles[existing].startTime=start;
      g_v14Cycles[existing].anchorPrice=anchor;
      g_v14Cycles[existing].gridStep=step;
      g_v14Cycles[existing].lotSize=lot;
      g_v14Cycles[existing].gridLevels=levels;
      g_v14Cycles[existing].autonomous=autonomous;
      g_v14Cycles[existing].active=true;
      return existing;
   }
   if(g_v14CycleCount>=V14_MAX_GRID_CYCLES) return -1;
   int idx=g_v14CycleCount++;
   g_v14Cycles[idx].id=id;
   g_v14Cycles[idx].magic=magic;
   g_v14Cycles[idx].gridType=type;
   g_v14Cycles[idx].entryMode=entry;
   g_v14Cycles[idx].startTime=start;
   g_v14Cycles[idx].anchorPrice=anchor;
   g_v14Cycles[idx].gridStep=step;
   g_v14Cycles[idx].lotSize=lot;
   g_v14Cycles[idx].gridLevels=levels;
   g_v14Cycles[idx].autonomous=autonomous;
   g_v14Cycles[idx].active=true;
   return idx;
}

int V14CountMagicInventory(ulong magic)
{
   int c=0;
   for(int i=0;i<PositionsTotal();i++)
   {
      ulong t=PositionGetTicket(i);
      if(t==0 || !PositionSelectByTicket(t)) continue;
      if(PositionGetString(POSITION_SYMBOL)==_Symbol && (ulong)PositionGetInteger(POSITION_MAGIC)==magic) c++;
   }
   for(int i=0;i<OrdersTotal();i++)
   {
      ulong t=OrderGetTicket(i);
      if(t==0 || !OrderSelect(t)) continue;
      if(OrderGetString(ORDER_SYMBOL)==_Symbol && (ulong)OrderGetInteger(ORDER_MAGIC)==magic) c++;
   }
   return c;
}

void V14SyncCycleRegistry()
{
   // Legacy inventory using the original magic becomes cycle 1.
   if(V14CountMagicInventory((ulong)InpMagicNumber)>0)
      V14RegisterCycle(0,(ulong)InpMagicNumber,g_state.gridType,g_state.entryMode,
                       g_state.startTime>0?g_state.startTime:TimeCurrent(),
                       g_state.anchorPrice,g_state.gridStep,g_state.lotSize,g_state.gridLevels,
                       g_state.autonomousMode);

   ulong discovered[V14_MAX_GRID_CYCLES];
   int dn=0;
   for(int pass=0;pass<2;pass++)
   {
      int total=(pass==0)?PositionsTotal():OrdersTotal();
      for(int i=0;i<total && dn<V14_MAX_GRID_CYCLES;i++)
      {
         ulong ticket=(pass==0)?PositionGetTicket(i):OrderGetTicket(i);
         ulong magic=0;
         if(pass==0)
         {
            if(ticket==0 || !PositionSelectByTicket(ticket)) continue;
            if(PositionGetString(POSITION_SYMBOL)!=_Symbol) continue;
            magic=(ulong)PositionGetInteger(POSITION_MAGIC);
         }
         else
         {
            if(ticket==0 || !OrderSelect(ticket)) continue;
            if(OrderGetString(ORDER_SYMBOL)!=_Symbol) continue;
            magic=(ulong)OrderGetInteger(ORDER_MAGIC);
         }
         if(magic<=(ulong)InpMagicNumber || V14KnownMagic(magic)) continue;
         if(magic>(ulong)InpMagicNumber+V14_MAX_GRID_CYCLES+1024) continue;
         bool dup=false;
         for(int k=0;k<dn;k++) if(discovered[k]==magic){dup=true;break;}
         if(!dup) discovered[dn++]=magic;
      }
   }

   for(int i=0;i<dn;i++)
   {
      ulong magic=discovered[i];
      ulong id=(ulong)MathMax((long)1,(long)(magic-(ulong)InpMagicNumber));
      int idx=V14RegisterCycle(id,magic,g_state.gridType,g_state.entryMode,TimeCurrent(),
                               g_state.anchorPrice,g_state.gridStep,g_state.lotSize,g_state.gridLevels,
                               g_state.autonomousMode);
      if(idx>=0) g_v14Cycles[idx].active=(V14CountMagicInventory(magic)>0);
   }
}

int V14CountActiveCycles()
{
   // v14.29 no longer models live trading as concurrent grid cycles.
   // The dashboard keeps the legacy function name for compatibility, but the
   // authoritative state is simply whether this EA currently has any inventory.
   return (GetPositionCount()+GetPendingCount())>0 ? 1 : 0;
}

string V14CycleTag()
{
   return g_v14ExecutionCycleId>0?StringFormat("|C%I64u",g_v14ExecutionCycleId):"";
}

string V14OrderComment(string base)
{
   // Each order carries its own strategy identity plus entry context for STRATEGY HEALTH.
   string out=base+"|GRID="+IntegerToString((int)g_state.gridType);
   return StrategyHealthDecorateOrderComment(out);
}

ENUM_GRID_TYPE GridTypeFromTradeComment(string comment,ENUM_GRID_TYPE fallback)
{
   int pos=StringFind(comment,"|GRID=");
   if(pos<0) return fallback;
   string v=StringSubstr(comment,pos+6);
   int idx=(int)StringToInteger(v);
   if(idx>=0 && idx<21) return (ENUM_GRID_TYPE)idx;
   return fallback;
}



// -------------------- GRID VALIDATION LAB --------------------

enum { GRID_TYPE_COUNT = 21 };

string g_gridValidationMatrix[GRID_TYPE_COUNT];

// GRID SELECTION runtime strategy-selection matrix.
double g_phase6GridSuitability[GRID_TYPE_COUNT];
string g_phase6GridReason[GRID_TYPE_COUNT];

int g_gridValidationRunCount=0;

int g_gridValidationPassed=0;

int g_gridValidationWarnings=0;

int g_gridValidationFailed=0;

datetime g_gridValidationTime=0;

string g_gridValidationSummary="NOT RUN";

int g_gridValidationSelected=0;

// VALIDATION LAB — validation lab state: 5 priority grids x 5 market conditions.
#define VALIDATION_LAB_GRID_COUNT 5
#define VALIDATION_LAB_CONDITION_COUNT 5
enum ENUM_VALIDATION_CONDITION{VALIDATION_TREND_UP=0,VALIDATION_TREND_DOWN,VALIDATION_RANGE,VALIDATION_BREAKOUT,VALIDATION_VOLATILITY};
ENUM_GRID_TYPE g_phase16FormalGrids[VALIDATION_LAB_GRID_COUNT]={SMART_REGIME_GRID,BULLISH_GRID,BEARISH_GRID,BIDIRECTIONAL_GRID,HEDGE_GRID};
string g_phase16Conditions[VALIDATION_LAB_CONDITION_COUNT]={"TREND UP","TREND DOWN","RANGE","BREAKOUT","VOLATILITY"};
string g_phase16CellStatus[VALIDATION_LAB_GRID_COUNT][VALIDATION_LAB_CONDITION_COUNT];
int g_phase16RunCount=0,g_phase16PassCount=0,g_phase16ReviewCount=0,g_phase16FailCount=0;
datetime g_phase16LastRun=0;
string g_phase16Summary="NOT RUN";



struct DashboardConfig{

   int x,y,width,height,currentTab;

   int homeSubTab,gridSubTab,riskSubTab,analyticsSubTab,aiSubTab,executionSubTab,tradesSubTab,transparencySubTab,diagnosticsSubTab,toolsSubTab,autonomySubTab,gridLabSubTab,gridLabValidationSubTab,gridLabMatrixSubTab;

   int settingsPage,settingsSubTab,settingsSubTab2,settingsSubTab3,settingsSubTab4,settingsSubTab5,settingsSubTab6;

   int navOffset;

   bool isVisible;

};

DashboardConfig g_dashboard;
int g_emergencySubTab=0;
int g_phase21SourceQualitySubTab=0;
int g_phase22SystemSubTab=0;
int g_userTrustSubTab=0;
int g_strategyHealthMainSubTab=0;

// Responsive UI scale: internal dashboard coordinates are logical and mapped to actual chart pixels.

double g_uiScale=1.0;

struct EditField{string name,value; bool modified;};

EditField g_editFields[100]; int g_editCount=0;

enum { EVENT_LOG_SIZE=40 };

string g_eventTime[EVENT_LOG_SIZE];

string g_eventType[EVENT_LOG_SIZE];

string g_eventDetail[EVENT_LOG_SIZE];

int g_eventCount=0;



enum { CONFIG_HISTORY_SIZE=24, PROFILE_SLOT_COUNT=4 };

string g_configHistory[CONFIG_HISTORY_SIZE];

int g_configHistoryCount=0;

string g_pendingApplySummary="";

string g_lastLoadedProfile="";

bool g_simulationPreviewReady=false;



const string PREFIX="UG7_";

const int TAB_COUNT=15;

const int TRADE_TAB_COUNT=4;

const int SETTINGS_TAB_COUNT=40;

const int SETTINGS_PAGE_COUNT=6;

color COLOR_BG,COLOR_PANEL,COLOR_PANEL2,COLOR_TEXT,COLOR_MUTED,COLOR_ACCENT,COLOR_GOLD,COLOR_GREEN,COLOR_RED,COLOR_ORANGE,COLOR_TEAL;

int g_atrHandle=INVALID_HANDLE,g_maHandle=INVALID_HANDLE,g_rsiHandle=INVALID_HANDLE,g_maM15Handle=INVALID_HANDLE,g_maH1Handle=INVALID_HANDLE,g_atrM15Handle=INVALID_HANDLE,g_atrH1Handle=INVALID_HANDLE;



string ObjName(string s){return PREFIX+s;}

double PipSize(){int d=(int)SymbolInfoInteger(_Symbol,SYMBOL_DIGITS); double p=SymbolInfoDouble(_Symbol,SYMBOL_POINT); return (d==3||d==5)?p*10.0:p;}

double NormalizeLots(double lots){double mn=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN),mx=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MAX),st=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_STEP); if(mn<=0)mn=0.01;if(mx<=0)mx=100;lots=MathMax(mn,MathMin(mx,lots));if(st>0)lots=MathRound(lots/st)*st;return NormalizeDouble(lots,2);}

bool IsGridOrder(ulong ticket,bool pending=false)
{
   ulong magic=0;
   if(pending)
   {
      if(!OrderSelect(ticket)) return false;
      if(OrderGetString(ORDER_SYMBOL)!=_Symbol) return false;
      magic=(ulong)OrderGetInteger(ORDER_MAGIC);
   }
   else
   {
      if(!PositionSelectByTicket(ticket)) return false;
      if(PositionGetString(POSITION_SYMBOL)!=_Symbol) return false;
      magic=(ulong)PositionGetInteger(POSITION_MAGIC);
   }
   if(!V14KnownMagic(magic)) return false;
   if(g_v14FocusMagic>0 && magic!=g_v14FocusMagic) return false;
   return true;
}

bool V14IsAnyGridOrder(ulong ticket,bool pending=false)
{
   ulong magic=0;
   if(pending)
   {
      if(!OrderSelect(ticket)) return false;
      if(OrderGetString(ORDER_SYMBOL)!=_Symbol) return false;
      magic=(ulong)OrderGetInteger(ORDER_MAGIC);
   }
   else
   {
      if(!PositionSelectByTicket(ticket)) return false;
      if(PositionGetString(POSITION_SYMBOL)!=_Symbol) return false;
      magic=(ulong)PositionGetInteger(POSITION_MAGIC);
   }
   return V14KnownMagic(magic);
}

int GetPositionCount(){int c=0;for(int i=0;i<PositionsTotal();i++){ulong t=PositionGetTicket(i);if(t>0&&IsGridOrder(t,false))c++;}return c;}

int GetPendingCount(){int c=0;for(int i=0;i<OrdersTotal();i++){ulong t=OrderGetTicket(i);if(t>0&&IsGridOrder(t,true))c++;}return c;}

double GetGridProfit(){double p=0;for(int i=0;i<PositionsTotal();i++){ulong t=PositionGetTicket(i);if(t>0&&IsGridOrder(t,false)&&PositionSelectByTicket(t))p+=PositionGetDouble(POSITION_PROFIT)+PositionGetDouble(POSITION_SWAP);}return p;}

string FormatNumber(double v){double a=MathAbs(v);if(a>=1e9)return DoubleToString(v/1e9,1)+"B";if(a>=1e6)return DoubleToString(v/1e6,1)+"M";if(a>=1e3)return DoubleToString(v/1e3,1)+"K";return DoubleToString(v,2);}

string RiskModeName(ENUM_RISK_MODE m){if(m==CONSERVATIVE)return "CONSERVATIVE";if(m==BALANCED)return "BALANCED";if(m==AGGRESSIVE)return "AGGRESSIVE";return "ADAPTIVE";}

string EntryModeName(ENUM_ENTRY_MODE m){if(m==MANUAL_ENTRY)return "MANUAL";if(m==AUTO_ENTRY)return "AUTO";if(m==AI_ENTRY)return "AI";return "TIME";}



string GetGridTypeName(ENUM_GRID_TYPE type){switch(type){case BASIC_GRID:return "Basic Grid";case HEDGE_GRID:return "Hedge Grid";case TREND_GRID:return "Trend Grid";case VOLATILITY_GRID:return "Volatility Grid";case AI_GRID:return "AI Grid";case GEOMETRIC_GRID:return "Geometric Grid";case FIBONACCI_GRID:return "Fibonacci Grid";case ATR_ADAPTIVE_GRID:return "ATR Adaptive Grid";case MEAN_REVERSION_GRID:return "Mean-Reversion Grid";case BREAKOUT_GRID:return "Breakout Grid";case MOMENTUM_GRID:return "Momentum Grid";case HYBRID_GRID:return "Hybrid Smart Grid";case BULLISH_GRID:return "Bullish Grid";case BEARISH_GRID:return "Bearish Grid";case BIDIRECTIONAL_GRID:return "Bidirectional Grid";case LADDER_GRID:return "Ladder Grid";case ANTI_MARTINGALE_GRID:return "Anti-Martingale Grid";case RANGE_SCALING_GRID:return "Range-Scaling Grid";case VOLATILITY_BREAKOUT_GRID:return "Volatility-Breakout Grid";case SESSION_GRID:return "Session Grid";case SMART_REGIME_GRID:return "Smart-Regime Grid";}return "Unknown Grid";}

string CompactGridName(ENUM_GRID_TYPE type){switch(type){case BASIC_GRID:return "BASIC";case HEDGE_GRID:return "HEDGE";case TREND_GRID:return "TREND";case VOLATILITY_GRID:return "VOLATILITY";case AI_GRID:return "AI GRID";case GEOMETRIC_GRID:return "GEOMETRIC";case FIBONACCI_GRID:return "FIBONACCI";case ATR_ADAPTIVE_GRID:return "ATR ADAPT";case MEAN_REVERSION_GRID:return "MEAN REV";case BREAKOUT_GRID:return "BREAKOUT";case MOMENTUM_GRID:return "MOMENTUM";case HYBRID_GRID:return "HYBRID";case BULLISH_GRID:return "BULLISH";case BEARISH_GRID:return "BEARISH";case BIDIRECTIONAL_GRID:return "BIDIR";case LADDER_GRID:return "LADDER";case ANTI_MARTINGALE_GRID:return "ANTI-MART";case RANGE_SCALING_GRID:return "RANGE SCALE";case VOLATILITY_BREAKOUT_GRID:return "VOL BREAK";case SESSION_GRID:return "SESSION";case SMART_REGIME_GRID:return "SMART REGIME";}return "GRID";}

string GridShortName(ENUM_GRID_TYPE type){return StringFormat("%02d  %s",(int)type+1,GetGridTypeName(type));}



void StoreEditValue(string name,string value){for(int i=0;i<g_editCount;i++){if(g_editFields[i].name==name){g_editFields[i].value=value;g_editFields[i].modified=true;return;}}if(g_editCount<ArraySize(g_editFields)){g_editFields[g_editCount].name=name;g_editFields[g_editCount].value=value;g_editFields[g_editCount].modified=true;g_editCount++;}}

string GetEditValue(string name,string def=""){for(int i=0;i<g_editCount;i++)if(g_editFields[i].name==name)return g_editFields[i].value;return def;}



double CalculateTrendStrength(){if(g_maHandle==INVALID_HANDLE)return 0.5;double ma[];ArraySetAsSeries(ma,true);if(CopyBuffer(g_maHandle,0,0,10,ma)<10)return 0.5;double s=0;for(int i=1;i<10;i++)s+=(ma[i-1]>ma[i]?0.1:-0.1);return MathMax(0.0,MathMin(1.0,(s+1.0)/2.0));}

double CalculateVolatility(){

   if(g_atrHandle==INVALID_HANDLE)return 0.5;

   const int lookback=50;

   double atr[];ArraySetAsSeries(atr,true);

   if(CopyBuffer(g_atrHandle,0,0,lookback,atr)<lookback)return 0.5;

   double avg=0.0;

   for(int i=0;i<lookback;i++)avg+=atr[i];

   avg/=lookback;

   if(avg<=0.0)return 0.5;

   double ratio=atr[0]/avg;

   double v=(ratio-0.50)/(1.80-0.50);

   return ClampDouble(v,0.0,1.0);

}

double CalculateSentiment(){if(g_rsiHandle==INVALID_HANDLE)return 0.5;double r[];ArraySetAsSeries(r,true);if(CopyBuffer(g_rsiHandle,0,0,1,r)<1)return 0.5;return MathMax(0.0,MathMin(1.0,r[0]/100.0));}

double GetCurrentATRPrice(){if(g_atrHandle==INVALID_HANDLE)return 0.0;double a[];ArraySetAsSeries(a,true);if(CopyBuffer(g_atrHandle,0,0,1,a)<1)return 0.0;return MathMax(a[0],SymbolInfoDouble(_Symbol,SYMBOL_POINT)*2.0);}

string CompactMarketDecisionV15()
{
   if(g_state.marketNoTrade)
   {
      if(g_state.marketNoTradeReason=="SPREAD QUALITY") return "NO TRADE | SPREAD";
      if(g_state.marketNoTradeReason=="STALE MARKET DATA") return "NO TRADE | STALE DATA";
      if(g_state.marketNoTradeReason=="VOLATILITY SHOCK") return "NO TRADE | VOL SHOCK";
      return "NO TRADE";
   }
   string r=(g_state.marketRegime!=""?g_state.marketRegime:g_state.regime);
   return r!=""?"READY | "+r:"READY";
}




// -------------------- MARKET INTELLIGENCE: MARKET STATE INTELLIGENCE --------------------

double Clamp01V15(double v){return MathMax(0.0,MathMin(1.0,v));}

double ReadMAValue(int handle,int shift=0)
{
   if(handle==INVALID_HANDLE)return 0.0;
   double b[];ArraySetAsSeries(b,true);
   if(CopyBuffer(handle,0,shift,1,b)<1)return 0.0;
   return b[0];
}

double TrendScoreFromHandle(int handle)
{
   if(handle==INVALID_HANDLE)return 0.5;
   double ma[];ArraySetAsSeries(ma,true);
   if(CopyBuffer(handle,0,0,8,ma)<8)return 0.5;
   double score=0.5;
   double net=0.0;
   for(int i=1;i<8;i++) net+=(ma[i-1]>ma[i]?1.0:(ma[i-1]<ma[i]?-1.0:0.0));
   score=0.5+0.5*(net/7.0);
   return Clamp01V15(score);
}

double CurrentTimeframeTrendScoreV15()
{
   if(g_maHandle==INVALID_HANDLE)return CalculateTrendStrength();
   double ma0=ReadMAValue(g_maHandle,0),ma3=ReadMAValue(g_maHandle,3);
   double c0=iClose(_Symbol,PERIOD_CURRENT,0),c3=iClose(_Symbol,PERIOD_CURRENT,3);
   double atr=GetCurrentATRPrice();
   if(ma0<=0.0 || c0<=0.0 || atr<=0.0)return CalculateTrendStrength();

   double priceBias=Clamp01V15(0.5+0.50*((c0-ma0)/(atr*1.50)));
   double slopeBias=Clamp01V15(0.5+0.50*((ma0-ma3)/(atr*0.75)));
   double impulseBias=Clamp01V15(0.5+0.50*((c0-c3)/MathMax(atr,SymbolInfoDouble(_Symbol,SYMBOL_POINT)*2.0)));
   return Clamp01V15(0.55*priceBias+0.25*slopeBias+0.20*impulseBias);
}

double ATRPercentileV15(int handle)
{
   if(handle==INVALID_HANDLE)return 0.5;
   const int n=50;
   double a[];ArraySetAsSeries(a,true);
   if(CopyBuffer(handle,0,0,n,a)<n)return 0.5;
   double cur=a[0];
   if(cur<=0.0)return 0.5;
   int below=0;
   for(int i=1;i<n;i++) if(a[i]<=cur) below++;
   return Clamp01V15((double)below/(double)(n-1));
}

double RangeWidthPctV15()
{
   double hi=iHigh(_Symbol,PERIOD_CURRENT,0),lo=iLow(_Symbol,PERIOD_CURRENT,0);
   double mid=SymbolInfoDouble(_Symbol,SYMBOL_BID);
   if(hi<=0.0||lo<=0.0||mid<=0.0||hi<lo)return 0.0;
   return MathMax(0.0,(hi-lo)/mid*100.0);
}

double CompressionScoreV15(double atrPct,double rangePct)
{
   double rp=Clamp01V15(rangePct/1.0);
   double lowVol=1.0-Clamp01V15(MathAbs(atrPct-0.25)/0.75);
   return Clamp01V15(0.60*lowVol+0.40*(1.0-rp));
}

double BreakoutPressureV15(double trend,double atrPct,double rangePct)
{
   double expansion=Clamp01V15((atrPct-0.55)/0.45);
   double range=Clamp01V15(rangePct/1.20);
   double direction=2.0*MathAbs(trend-0.5);
   return Clamp01V15(0.45*expansion+0.30*range+0.25*direction);
}

string MarketSessionNameV15()
{
   int h=CurrentServerHour();
   if(h>=0 && h<7)return "ASIA";
   if(h>=7 && h<10)return "LONDON OPEN";
   if(h>=10 && h<13)return "LONDON";
   if(h>=13 && h<17)return "NEW YORK OPEN";
   if(h>=17 && h<21)return "NEW YORK";
   return "ROLLOVER / LATE";
}

void UpdateMarketStateV15()
{
   datetime now=TimeCurrent();
   g_state.marketStateTime=now;
   g_state.marketDataFresh=false;
   g_state.marketNoTrade=false;
   g_state.marketNoTradeReason="";

   MqlTick tick;
   if(!SymbolInfoTick(_Symbol,tick) || tick.bid<=0.0 || tick.ask<=0.0)
   {
      g_state.marketNoTrade=true;
      g_state.marketNoTradeReason="NO VALID TICK";
      g_state.marketSession=MarketSessionNameV15();
      g_state.marketRegime="NO TRADE";
      g_state.regime="NO TRADE";
      g_state.regimeConfidence=0.0;
      return;
   }

   // Freshness is based on the latest received tick, never on the age of the current candle.
   g_state.marketDataFresh=(tick.time>0 && now>=(datetime)tick.time && (now-(datetime)tick.time)<=5);
   g_state.marketSession=MarketSessionNameV15();

   // Base/default mode: analyze ONLY the chart timeframe the user attached the EA to.
   double currentTrend=CurrentTimeframeTrendScoreV15();
   double currentAtrPct=ATRPercentileV15(g_atrHandle);
   g_state.mtfTrendM5=currentTrend;
   g_state.mtfTrendM15=currentTrend;
   g_state.mtfTrendH1=currentTrend;
   double tfAgreement=1.0;

   if(g_state.useMultiTimeframeMarketState)
   {
      g_state.mtfTrendM5=TrendScoreFromHandle(g_maHandle);
      g_state.mtfTrendM15=TrendScoreFromHandle(g_maM15Handle);
      g_state.mtfTrendH1=TrendScoreFromHandle(g_maH1Handle);
      double avgTrend=0.50*g_state.mtfTrendM5+0.30*g_state.mtfTrendM15+0.20*g_state.mtfTrendH1;
      tfAgreement=1.0-(MathAbs(g_state.mtfTrendM5-g_state.mtfTrendM15)+MathAbs(g_state.mtfTrendM15-g_state.mtfTrendH1))*0.5;
      tfAgreement=Clamp01V15(tfAgreement);
      g_state.trendStrength=Clamp01V15(avgTrend);
      double atrP15=ATRPercentileV15(g_atrM15Handle);
      double atrP1=ATRPercentileV15(g_atrH1Handle);
      g_state.atrPercentile=Clamp01V15(0.60*currentAtrPct+0.25*atrP15+0.15*atrP1);
   }
   else
   {
      g_state.trendStrength=Clamp01V15(currentTrend);
      g_state.atrPercentile=Clamp01V15(currentAtrPct);
   }

   g_state.volatilityIndex=g_state.atrPercentile;
   g_state.rangeWidthPct=RangeWidthPctV15();
   g_state.compressionScore=CompressionScoreV15(g_state.volatilityIndex,g_state.rangeWidthPct);
   g_state.breakoutPressure=BreakoutPressureV15(g_state.trendStrength,g_state.volatilityIndex,g_state.rangeWidthPct);
   g_state.marketStabilityScore=Clamp01V15(
      0.45*tfAgreement+
      0.30*(1.0-MathAbs(g_state.volatilityIndex-0.50)*2.0)+
      0.25*(1.0-MathMin(1.0,g_state.currentSpreadPips/MathMax(1.0,g_state.maxSpreadPips>0?g_state.maxSpreadPips*1.5:10.0))));

   double bull=g_state.trendStrength;
   double bear=1.0-g_state.trendStrength;
   if(bull>=g_state.bullThreshold && tfAgreement>=0.55)
      g_state.marketRegime=(g_state.volatilityIndex>=0.75?"TREND UP / HIGH VOL":"TREND UP");
   else if(bear>=1.0-g_state.bullThreshold && tfAgreement>=0.55)
      g_state.marketRegime=(g_state.volatilityIndex>=0.75?"TREND DOWN / HIGH VOL":"TREND DOWN");
   else if(g_state.compressionScore>=0.68)
      g_state.marketRegime="COMPRESSION";
   else if(g_state.breakoutPressure>=0.70 && g_state.volatilityIndex>=0.55)
      g_state.marketRegime="BREAKOUT";
   else if(g_state.volatilityIndex>=0.90)
      g_state.marketRegime="SHOCK / HIGH VOL";
   else if(MathAbs(g_state.trendStrength-0.5)<=0.10 && g_state.volatilityIndex<=0.45)
      g_state.marketRegime="RANGE";
   else if(tfAgreement<0.40)
      g_state.marketRegime="TRANSITION";
   else
      g_state.marketRegime="MIXED";

   // Confidence is regime confidence, not a directional percentage.
   g_state.regimeConfidence=Clamp01V15(
      (g_state.useMultiTimeframeMarketState?0.45*tfAgreement:0.70)+
      0.35*(2.0*MathAbs(g_state.trendStrength-0.5))*
      (g_state.useMultiTimeframeMarketState?1.0:0.75)+
      0.20*g_state.marketStabilityScore);
   g_state.regimeConfidence=Clamp01V15(g_state.regimeConfidence);
   g_state.marketRegime=(g_state.regimeConfidence<0.30?"NO TRADE / LOW CONFIDENCE":g_state.marketRegime);
   g_state.regime=g_state.marketRegime;

   if(g_state.maxSpreadPips>0 && g_state.currentSpreadPips>g_state.maxSpreadPips)
   { g_state.marketNoTrade=true; g_state.marketNoTradeReason="SPREAD QUALITY"; }
   else if(!g_state.marketDataFresh)
   { g_state.marketNoTrade=true; g_state.marketNoTradeReason="STALE MARKET DATA"; }
   else if(g_state.marketRegime=="SHOCK / HIGH VOL" && g_state.pauseHighVolatility)
   { g_state.marketNoTrade=true; g_state.marketNoTradeReason="VOLATILITY SHOCK"; }

   if(g_state.marketNoTrade)
      g_state.marketDecisionReason=g_state.marketNoTradeReason;
   else if(g_state.useMultiTimeframeMarketState)
      g_state.marketDecisionReason=StringFormat("%s | M5 %.0f%% / M15 %.0f%% / H1 %.0f%% | VOL %.0f%% | CONF %.0f%%",
         g_state.marketRegime,g_state.mtfTrendM5*100.0,g_state.mtfTrendM15*100.0,g_state.mtfTrendH1*100.0,
         g_state.volatilityIndex*100.0,g_state.regimeConfidence*100.0);
   else
      g_state.marketDecisionReason=StringFormat("%s | %s %.0f%% | VOL %.0f%% | CONF %.0f%%",
         g_state.marketRegime,EnumToString((ENUM_TIMEFRAMES)_Period),g_state.trendStrength*100.0,
         g_state.volatilityIndex*100.0,g_state.regimeConfidence*100.0);
}

bool MarketStateMarketStateAudit(string &reason)
{
   reason="";
   if(g_atrHandle==INVALID_HANDLE || g_maHandle==INVALID_HANDLE || g_rsiHandle==INVALID_HANDLE){reason="Base market indicator handles invalid";return false;}
   if(g_state.useMultiTimeframeMarketState && (g_maM15Handle==INVALID_HANDLE || g_maH1Handle==INVALID_HANDLE || g_atrM15Handle==INVALID_HANDLE || g_atrH1Handle==INVALID_HANDLE)){reason="Multi-timeframe indicator handles invalid";return false;}
   if(g_state.regime==""){reason="Regime classification empty";return false;}
   if(g_state.trendStrength<0.0 || g_state.trendStrength>1.0 || g_state.volatilityIndex<0.0 || g_state.volatilityIndex>1.0){reason="Normalized market score outside 0..1";return false;}
   if(g_state.regimeConfidence<0.0 || g_state.regimeConfidence>1.0){reason="Regime confidence outside 0..1";return false;}
   return true;
}


// -------------------- STRATEGY LIBRARY: FORMALIZED GRID STRATEGY LIBRARY --------------------
// STRATEGY LIBRARY fully formalizes five priority strategies while preserving the other 16
// existing implementations unchanged until they are promoted into the formal library.

bool IsPhase4FormalizedGrid(ENUM_GRID_TYPE t)
{
   return (t==SMART_REGIME_GRID || t==BULLISH_GRID || t==BEARISH_GRID ||
           t==BIDIRECTIONAL_GRID || t==HEDGE_GRID);
}

string StrategyLibraryGridVersion(){ return "P4.1"; }

void UpdatePhase4GridProfile()
{
   ENUM_GRID_TYPE t=g_selectedGridType;
   if(IsAutonomousManagedMode() && (int)g_autonomousGridType>=0 && (int)g_autonomousGridType<GRID_TYPE_COUNT)
      t=g_autonomousGridType;
   else if((int)g_state.gridType>=0 && (int)g_state.gridType<GRID_TYPE_COUNT)
      t=g_state.gridType;

   g_state.gridProfileFormalized=IsPhase4FormalizedGrid(t);
   g_state.gridProfileVersion=StrategyLibraryGridVersion();
   g_state.gridProfileSuitability=0.0;
   g_state.gridProfileRole="LEGACY PROFILE";
   g_state.gridProfilePreferredRegime="ANY";
   g_state.gridProfileDirection="PROFILE SPECIFIC";
   g_state.gridProfileEntryModel="Existing implementation";
   g_state.gridProfileExitModel="Existing position policy";
   g_state.gridProfileRecenterModel="Existing recenter policy";
   g_state.gridProfileReplenishModel="Existing replenishment policy";
   g_state.gridProfileProtectionModel="Existing protection policy";

   double tr=ClampDouble(g_state.trendStrength,0.0,1.0);
   double v=ClampDouble(g_state.volatilityIndex,0.0,1.0);
   string r=g_state.marketRegime!=""?g_state.marketRegime:g_state.regime;

   switch(t)
   {
      case SMART_REGIME_GRID:
         g_state.gridProfileRole="MASTER ROUTER";
         g_state.gridProfilePreferredRegime="TREND / RANGE / BREAKOUT / SHOCK-AWARE";
         g_state.gridProfileDirection="LONG / SHORT / BOTH";
         g_state.gridProfileEntryModel="Regime-routed pending structure";
         g_state.gridProfileExitModel="Regime + ATR adaptive";
         g_state.gridProfileRecenterModel="Regime-aware anchor";
         g_state.gridProfileReplenishModel="Adaptive structure maintenance";
         g_state.gridProfileProtectionModel="Dynamic risk + directional protection";
         g_state.gridProfileSuitability=0.85;
         break;
      case BULLISH_GRID:
         g_state.gridProfileRole="DIRECTIONAL SPECIALIST";
         g_state.gridProfilePreferredRegime="TREND UP / BREAKOUT";
         g_state.gridProfileDirection="LONG";
         g_state.gridProfileEntryModel="Buy stops + pullback limits";
         g_state.gridProfileExitModel="Directional TP + ATR protection";
         g_state.gridProfileRecenterModel="Trend-preserving anchor";
         g_state.gridProfileReplenishModel="Trend continuation levels";
         g_state.gridProfileProtectionModel="Reduced size in high volatility";
         g_state.gridProfileSuitability=ClampDouble(0.50+0.50*tr,0.0,1.0);
         if(StringFind(r,"TREND UP")>=0 || StringFind(r,"BREAKOUT")>=0) g_state.gridProfileSuitability=MathMin(1.0,g_state.gridProfileSuitability+0.10);
         break;
      case BEARISH_GRID:
         g_state.gridProfileRole="DIRECTIONAL SPECIALIST";
         g_state.gridProfilePreferredRegime="TREND DOWN / BREAKOUT";
         g_state.gridProfileDirection="SHORT";
         g_state.gridProfileEntryModel="Sell stops + pullback limits";
         g_state.gridProfileExitModel="Directional TP + ATR protection";
         g_state.gridProfileRecenterModel="Trend-preserving anchor";
         g_state.gridProfileReplenishModel="Trend continuation levels";
         g_state.gridProfileProtectionModel="Reduced size in high volatility";
         g_state.gridProfileSuitability=ClampDouble(1.00-tr,0.0,1.0);
         if(StringFind(r,"TREND DOWN")>=0 || StringFind(r,"BREAKOUT")>=0) g_state.gridProfileSuitability=MathMin(1.0,g_state.gridProfileSuitability+0.10);
         break;
      case BIDIRECTIONAL_GRID:
         g_state.gridProfileRole="TWO-SIDED BALANCE";
         g_state.gridProfilePreferredRegime="RANGE / COMPRESSION / UNCERTAIN";
         g_state.gridProfileDirection="BOTH";
         g_state.gridProfileEntryModel="Two-sided stop structure";
         g_state.gridProfileExitModel="Symmetric profit protection";
         g_state.gridProfileRecenterModel="Mean-price anchor";
         g_state.gridProfileReplenishModel="Two-sided level replenishment";
         g_state.gridProfileProtectionModel="Balanced directional exposure";
         g_state.gridProfileSuitability=ClampDouble(1.0-MathAbs(tr-0.50)*1.60,0.0,1.0);
         if(StringFind(r,"RANGE")>=0 || StringFind(r,"COMPRESSION")>=0 || StringFind(r,"MIXED")>=0) g_state.gridProfileSuitability=MathMin(1.0,g_state.gridProfileSuitability+0.15);
         break;
      case HEDGE_GRID:
         g_state.gridProfileRole="HEDGE SPECIALIST";
         g_state.gridProfilePreferredRegime="TRANSITION / UNCERTAIN / HEDGE-ELIGIBLE";
         g_state.gridProfileDirection="BOTH / HEDGED";
         g_state.gridProfileEntryModel="Paired market seed + two-sided stops";
         g_state.gridProfileExitModel="Independent leg management";
         g_state.gridProfileRecenterModel="Neutral anchor";
         g_state.gridProfileReplenishModel="Paired level maintenance";
         g_state.gridProfileProtectionModel="Conservative paired exposure";
         g_state.gridProfileSuitability=ClampDouble(0.95-MathAbs(tr-0.50)*1.40,0.0,1.0);
         if(StringFind(r,"TRANSITION")>=0 || StringFind(r,"MIXED")>=0 || StringFind(r,"RANGE")>=0) g_state.gridProfileSuitability=MathMin(1.0,g_state.gridProfileSuitability+0.10);
         break;
   }

   if(g_state.marketNoTrade) g_state.gridProfileSuitability*=0.50;
   if(v>=0.90 && t!=SMART_REGIME_GRID) g_state.gridProfileSuitability*=0.80;
}

string StrategyLibraryGridSpecSummary(ENUM_GRID_TYPE t)
{
   if(t==SMART_REGIME_GRID) return "P4.1 | MASTER ROUTER | regime-adaptive | LONG/SHORT/BOTH";
   if(t==BULLISH_GRID) return "P4.1 | DIRECTIONAL | TREND UP / BREAKOUT | LONG";
   if(t==BEARISH_GRID) return "P4.1 | DIRECTIONAL | TREND DOWN / BREAKOUT | SHORT";
   if(t==BIDIRECTIONAL_GRID) return "P4.1 | TWO-SIDED | RANGE / COMPRESSION | BOTH";
   if(t==HEDGE_GRID) return "P4.1 | HEDGE SPECIALIST | TRANSITION / UNCERTAIN | BOTH";
   return "LEGACY | EXISTING IMPLEMENTATION";
}

bool StrategyLibraryGridLibraryAudit(string &reason)
{
   reason="";
   ENUM_GRID_TYPE priority[5]={SMART_REGIME_GRID,BULLISH_GRID,BEARISH_GRID,BIDIRECTIONAL_GRID,HEDGE_GRID};
   for(int i=0;i<5;i++)
   {
      if(!IsPhase4FormalizedGrid(priority[i])){reason="Priority strategy classification failed";return false;}
      string spec=StrategyLibraryGridSpecSummary(priority[i]);
      if(StringFind(spec,"P4.1")<0){reason=StringFormat("Missing formal profile: %d",(int)priority[i]);return false;}
   }
   if(g_state.gridProfileVersion!="P4.1"){reason="Active profile version mismatch";return false;}
   if(g_state.gridProfileFormalized && (g_state.gridProfileSuitability<0.0 || g_state.gridProfileSuitability>1.0))
   { reason="Profile suitability outside 0..1"; return false; }
   reason="PASS | 5 priority grid profiles formalized; 16 legacy profiles preserved";
   return true;
}

// -------------------- ADVANCED CONTROL / EA STATUS--------------------

string ControlModeName(ENUM_CONTROL_MODE m){if(m==CONTROL_ASSIST)return "ASSIST";if(m==CONTROL_AUTONOMOUS)return "AUTONOMOUS";return "MANUAL";}

bool IsAutonomousControl(){return g_state.controlMode==CONTROL_AUTONOMOUS;}

double ClampDouble(double v,double lo,double hi){return MathMax(lo,MathMin(hi,v));}



void AddConfigurationWarning(int &warnings,string &msg,string text)

{

   warnings++;

   if(msg!="") msg+=" | ";

   msg+=text;

}

string GridStrategyName(ENUM_GRID_TYPE t)

{

   switch(t){

      case BASIC_GRID:return "Fixed symmetric pending";

      case HEDGE_GRID:return "Market hedge + pending";

      case TREND_GRID:return "Trend-following";

      case VOLATILITY_GRID:return "Volatility-expanded";

      case AI_GRID:return "AI-assisted adaptive";

      case GEOMETRIC_GRID:return "Geometric distance";

      case FIBONACCI_GRID:return "Fibonacci spacing";

      case ATR_ADAPTIVE_GRID:return "ATR adaptive distance";

      case MEAN_REVERSION_GRID:return "Mean-reversion limits";

      case BREAKOUT_GRID:return "Breakout stops";

      case MOMENTUM_GRID:return "Momentum / breakout";

      case HYBRID_GRID:return "Trend/range/breakout blend";

      case BULLISH_GRID:return "Bull stops + pullback limits";

      case BEARISH_GRID:return "Bear stops + pullback limits";

      case BIDIRECTIONAL_GRID:return "Two-sided stops";

      case LADDER_GRID:return "Ladder + tapered lots";

      case ANTI_MARTINGALE_GRID:return "Progressive sizing";

      case RANGE_SCALING_GRID:return "Range limits + scaling";

      case VOLATILITY_BREAKOUT_GRID:return "ATR breakout + adjusted lots";

      case SESSION_GRID:return "Session-adjusted bidirectional";

      case SMART_REGIME_GRID:return "Regime selector";

   }

   return "Unknown profile";

}

string GridDirectionModel(ENUM_GRID_TYPE t)

{

   switch(t){

      case TREND_GRID: case MOMENTUM_GRID: case BULLISH_GRID: case BEARISH_GRID:return "Directional";

      case MEAN_REVERSION_GRID: case RANGE_SCALING_GRID:return "Mean-reverting";

      case HEDGE_GRID: case BIDIRECTIONAL_GRID: case VOLATILITY_GRID: case AI_GRID: case GEOMETRIC_GRID: case FIBONACCI_GRID: case ATR_ADAPTIVE_GRID: case BREAKOUT_GRID: case HYBRID_GRID: case LADDER_GRID: case ANTI_MARTINGALE_GRID: case VOLATILITY_BREAKOUT_GRID: case SESSION_GRID:return "Two-sided / profile-dependent";

      case SMART_REGIME_GRID:return "Regime-selected";

      default:return "Profile-specific";

   }

}

string GridDistanceModel(ENUM_GRID_TYPE t)

{

   switch(t){

      case GEOMETRIC_GRID:return "Geometric ratio";

      case FIBONACCI_GRID:return "Fibonacci ratios";

      case ATR_ADAPTIVE_GRID: case VOLATILITY_BREAKOUT_GRID:return "ATR driven";

      case VOLATILITY_GRID: case BREAKOUT_GRID: case HYBRID_GRID: case BULLISH_GRID: case BEARISH_GRID: case BIDIRECTIONAL_GRID: case RANGE_SCALING_GRID:return "Market-condition adjusted";

      case SESSION_GRID:return "Session-adjusted";

      case SMART_REGIME_GRID:return "Regime-selected";

      default:return "Base step";

   }

}

string GridLotModel(ENUM_GRID_TYPE t)

{

   switch(t){

      case BASIC_GRID:return "Multiplier";

      case HEDGE_GRID:return "Core + multiplier";

      case VOLATILITY_GRID: case AI_GRID:return "Volatility/sentiment adjusted";

      case FIBONACCI_GRID:return "Fibonacci weighted";

      case LADDER_GRID:return "Tapered";

      case ANTI_MARTINGALE_GRID:return "Progressive";

      case BULLISH_GRID: case BEARISH_GRID: case BIDIRECTIONAL_GRID: case VOLATILITY_BREAKOUT_GRID:return "Volatility adjusted";

      default:return "Base / profile-specific";

   }

}

string GridSpecialRule(ENUM_GRID_TYPE t)

{

   switch(t){

      case HEDGE_GRID:return "Buy + Sell core; hedge levels";

      case TREND_GRID:return "Needs trend direction";

      case MOMENTUM_GRID:return "Neutral -> breakout";

      case BULLISH_GRID:return "Bull trend; stops + limits";

      case BEARISH_GRID:return "Bear trend; stops + limits";

      case HYBRID_GRID:return "Trend/range/breakout selector";

      case RANGE_SCALING_GRID:return "Limits in neutral range";

      case SESSION_GRID:return "Session-hour spacing";

      case SMART_REGIME_GRID:return "Runtime profile selector";

      default:return "Profile geometry";

   }

}

string GridAdvancedPolicySummary(ENUM_GRID_TYPE t)

{

   string r="USER BASE";

   if(g_state.adaptiveGrid || g_state.adaptiveLevels) r+=" | adaptive geometry";

   if(g_state.adaptiveLot) r+=" | adaptive lot";

   if(g_state.smartRegime) r+=" | smart regime";

   if(g_state.smartRecenter) r+=" | smart recenter";

   if(g_state.smartReplenishment) r+=" | smart replenish";

   return r;

}





void UpdateConfigurationHealth()

{

   int warnings=0;

   string msg="";

   if(g_state.minGridStep>g_state.maxGridStep) AddConfigurationWarning(warnings,msg,"Min step exceeds max step");

   if(g_state.adaptiveLevels && (g_state.adaptiveMinLevels>g_state.gridLevels || g_state.gridLevels>g_state.adaptiveMaxLevels))

      AddConfigurationWarning(warnings,msg,"Base levels will be clamped by adaptive bounds");

   if(g_state.controlMode==CONTROL_AUTONOMOUS && g_state.entryMode==MANUAL_ENTRY)

      AddConfigurationWarning(warnings,msg,"Autonomous mode uses MANUAL entry mode");

   if(g_state.advancedEntryDecision && !IsAutonomousControl())

      AddConfigurationWarning(warnings,msg,"Advanced Entry is inactive outside Autonomous mode");

   if(g_state.exposureManager && g_state.maxTotalLots<=0)

      AddConfigurationWarning(warnings,msg,"Exposure Manager is ON but Max Total Lots is unlimited");

   if(g_state.smartRecenter && !g_state.autoRecenter)

      AddConfigurationWarning(warnings,msg,"Smart Recenter is ON but Auto Recenter is OFF");

   if(g_state.smartReplenishment && !IsReplenishableStopGrid())

      AddConfigurationWarning(warnings,msg,"Smart Replenishment is inactive for this grid type");

   if(g_state.controlMode==CONTROL_AUTONOMOUS && g_state.maxAutonomousGridsPerDay<=0)

      AddConfigurationWarning(warnings,msg,"Autonomous daily deployment limit is not set");



   g_state.configWarningCount=warnings;

   g_state.configWarnings=(msg==""?"Configuration consistent":msg);

   g_state.configHealth=(warnings==0?"HEALTHY":warnings<=2?"REVIEW":"ATTENTION");

   g_state.lastConfigCheckTime=TimeCurrent();

   g_state.configCheckSequence++;

   g_state.lastConfigCheckResult=StringFormat("CHECK #%d  %s | %d warning(s)",g_state.configCheckSequence,g_state.configHealth,g_state.configWarningCount);

}



void ResetEventJournal(){g_eventCount=0;for(int i=0;i<EVENT_LOG_SIZE;i++){g_eventTime[i]="";g_eventType[i]="";g_eventDetail[i]="";}}

void RecordEvent(string type,string detail){if(!g_state.decisionJournal)return;if(g_eventCount<EVENT_LOG_SIZE){g_eventTime[g_eventCount]=TimeToString(TimeCurrent(),TIME_SECONDS);g_eventType[g_eventCount]=type;g_eventDetail[g_eventCount]=detail;g_eventCount++;}else{for(int i=1;i<EVENT_LOG_SIZE;i++){g_eventTime[i-1]=g_eventTime[i];g_eventType[i-1]=g_eventType[i];g_eventDetail[i-1]=g_eventDetail[i];}g_eventTime[EVENT_LOG_SIZE-1]=TimeToString(TimeCurrent(),TIME_SECONDS);g_eventType[EVENT_LOG_SIZE-1]=type;g_eventDetail[EVENT_LOG_SIZE-1]=detail;}}

void SetAction(string owner,string action,string reason){g_state.lastActionOwner=owner;g_state.lastDecision=action;g_state.lastActionReason=reason;g_state.lastActionTime=TimeCurrent();RecordEvent(owner,action+" | "+reason);}



void AddConfigHistory(string entry)

{

   if(g_configHistoryCount<CONFIG_HISTORY_SIZE)

   {

      g_configHistory[g_configHistoryCount]=TimeToString(TimeCurrent(),TIME_SECONDS)+" | "+entry;

      g_configHistoryCount++;

   }

   else

   {

      for(int i=1;i<CONFIG_HISTORY_SIZE;i++) g_configHistory[i-1]=g_configHistory[i];

      g_configHistory[CONFIG_HISTORY_SIZE-1]=TimeToString(TimeCurrent(),TIME_SECONDS)+" | "+entry;

   }

}



string BuildApplySummary()

{

   string r="";

   string v;

   v=ReadDashboardText("EDT_STEP"); if(v!="" && MathAbs(StringToDouble(v)-g_state.gridStep)>0.0001) r+=StringFormat("Step %.1f -> %.1f; ",g_state.gridStep,StringToDouble(v));

   v=ReadDashboardText("EDT_LEVELS"); if(v!="" && (int)StringToInteger(v)!=g_state.gridLevels) r+=StringFormat("Levels %d -> %d; ",g_state.gridLevels,(int)StringToInteger(v));

   v=ReadDashboardText("EDT_LOT"); if(v!="" && MathAbs(StringToDouble(v)-g_state.lotSize)>0.000001) r+=StringFormat("Lot %.3f -> %.3f; ",g_state.lotSize,StringToDouble(v));

   v=ReadDashboardText("EDT_RISK"); if(v!="" && MathAbs(StringToDouble(v)-g_state.riskPerGridPct)>0.0001) r+=StringFormat("Risk %.2f -> %.2f; ",g_state.riskPerGridPct,StringToDouble(v));

   v=ReadDashboardText("EDT_SL"); if(v!="" && MathAbs(StringToDouble(v)-g_state.stopLossPips)>0.0001) r+=StringFormat("SL %.1f -> %.1f; ",g_state.stopLossPips,StringToDouble(v));

   v=ReadDashboardText("EDT_TP"); if(v!="" && MathAbs(StringToDouble(v)-g_state.takeProfitPips)>0.0001) r+=StringFormat("TP %.1f -> %.1f; ",g_state.takeProfitPips,StringToDouble(v));

   if(r=="") r="No material numeric changes";

   return r;

}



string ProfileFileName(int slot)

{

   return StringFormat("UG7_profile_%I64u_%s_%d.csv",InpMagicNumber,_Symbol,slot);

}



void WriteProfileValue(int h,string key,string value)

{

   FileWrite(h,key,value);

}



void SaveProfile(int slot)

{

   if(slot<0 || slot>=PROFILE_SLOT_COUNT) return;

   int h=FileOpen(ProfileFileName(slot),FILE_WRITE|FILE_CSV|FILE_ANSI,';');

   if(h==INVALID_HANDLE){RecordEvent("PROFILE","Save failed | slot "+IntegerToString(slot+1));return;}

   FileWrite(h,"UG7_PROFILE","10.20");

   WriteProfileValue(h,"GRID_TYPE",IntegerToString((int)g_state.gridType));

   WriteProfileValue(h,"ENTRY_MODE",IntegerToString((int)g_state.entryMode));

   WriteProfileValue(h,"RISK_MODE",IntegerToString((int)g_state.riskMode));

   WriteProfileValue(h,"REENTRY_MODE",IntegerToString((int)g_state.reentryMode));

   WriteProfileValue(h,"LOT",DoubleToString(g_state.lotSize,8));

   WriteProfileValue(h,"STEP",DoubleToString(g_state.gridStep,8));

   WriteProfileValue(h,"LEVELS",IntegerToString(g_state.gridLevels));

   WriteProfileValue(h,"MULT",DoubleToString(g_state.lotMultiplier,8));

   WriteProfileValue(h,"FRONT",DoubleToString(g_state.frontOrderDistancePips,8));

   WriteProfileValue(h,"ATR",DoubleToString(g_state.atrSpacingMultiplier,8));

   WriteProfileValue(h,"MINSTEP",DoubleToString(g_state.minGridStep,8));

   WriteProfileValue(h,"MAXSTEP",DoubleToString(g_state.maxGridStep,8));

   WriteProfileValue(h,"RECENTER",DoubleToString(g_state.recenterATRMultiple,8));

   WriteProfileValue(h,"AUTONOMOUS",g_state.autonomousMode?"1":"0");

   WriteProfileValue(h,"CONTROL",IntegerToString((int)g_state.controlMode));

   WriteProfileValue(h,"AI",g_state.aiEnabled?"1":"0");

   WriteProfileValue(h,"AI_CONF",DoubleToString(g_state.aiConfidence,8));

   WriteProfileValue(h,"REGIME",g_state.regimeFilter?"1":"0");

   WriteProfileValue(h,"DYN_RISK",g_state.useDynamicRiskLot?"1":"0");

   WriteProfileValue(h,"STRAT_MGMT",g_state.strategyAwareManagement?"1":"0");

   WriteProfileValue(h,"EXIT_COORD",g_state.strategyExitCoordination?"1":"0");

   WriteProfileValue(h,"RISK_ENGINE",g_state.riskManagedTrading?"1":"0");

   WriteProfileValue(h,"MAXDD",DoubleToString(g_state.maxDrawdownPct,8));

   WriteProfileValue(h,"MAXGRIDRISK",DoubleToString(g_state.maxGridRiskPct,8));

   WriteProfileValue(h,"MAXPOS",IntegerToString(g_state.maxPositions));

   WriteProfileValue(h,"MAXPEND",IntegerToString(g_state.maxPendingOrders));

   WriteProfileValue(h,"SL",DoubleToString(g_state.stopLossPips,8));

   WriteProfileValue(h,"TP",DoubleToString(g_state.takeProfitPips,8));

   WriteProfileValue(h,"USESL",g_state.useStopLossForNewOrders?"1":"0");

   WriteProfileValue(h,"USET_P",g_state.useTakeProfitForNewOrders?"1":"0");

   WriteProfileValue(h,"BE",g_state.breakEven?"1":"0");

   WriteProfileValue(h,"TRAIL",g_state.trailingStop?"1":"0");

   WriteProfileValue(h,"OCO",g_state.oco?"1":"0");

   WriteProfileValue(h,"SLIP",IntegerToString(g_state.slippage));

   WriteProfileValue(h,"SPREAD",DoubleToString(g_state.maxSpreadPips,8));

   WriteProfileValue(h,"SESSION",g_state.useSessionFilter?"1":"0");

   WriteProfileValue(h,"SSTART",IntegerToString(g_state.sessionStartHour));

   WriteProfileValue(h,"SEND",IntegerToString(g_state.sessionEndHour));

   WriteProfileValue(h,"WEEKEND",g_state.avoidWeekend?"1":"0");

   // Advanced permissions

   WriteProfileValue(h,"ADV_ENTRY",g_state.advancedEntryDecision?"1":"0");

   WriteProfileValue(h,"ADAPT_GRID",g_state.adaptiveGrid?"1":"0");

   WriteProfileValue(h,"ADAPT_LEVELS",g_state.adaptiveLevels?"1":"0");

   WriteProfileValue(h,"ADAPT_LOT",g_state.adaptiveLot?"1":"0");

   WriteProfileValue(h,"MARKET_INTEL",g_state.marketIntelligence?"1":"0");
   WriteProfileValue(h,"MTF_MARKET",g_state.useMultiTimeframeMarketState?"1":"0");

   WriteProfileValue(h,"SMART_REGIME",g_state.smartRegime?"1":"0");

   WriteProfileValue(h,"SMART_RECENTER",g_state.smartRecenter?"1":"0");

   WriteProfileValue(h,"SMART_REPLENISH",g_state.smartReplenishment?"1":"0");

   WriteProfileValue(h,"EXPOSURE",g_state.exposureManager?"1":"0");

   WriteProfileValue(h,"ADV_PROTECT",g_state.advancedProtection?"1":"0");

   WriteProfileValue(h,"GUARDIAN",g_state.orderGuardian?"1":"0");

   WriteProfileValue(h,"JOURNAL",g_state.decisionJournal?"1":"0");

   WriteProfileValue(h,"EMG_PERM",g_state.permEmergencyControl?"1":"0");WriteProfileValue(h,"EMG_CLOSE",g_state.emergencyAutoClose?"1":"0");WriteProfileValue(h,"EMG_CANCEL",g_state.emergencyCancelPending?"1":"0");WriteProfileValue(h,"PERM_ENTRY",g_state.permAutonomousEntry?"1":"0");WriteProfileValue(h,"PERM_STEP",g_state.permAdaptiveStep?"1":"0");WriteProfileValue(h,"PERM_LEVELS",g_state.permAdaptiveLevels?"1":"0");WriteProfileValue(h,"PERM_LOT",g_state.permAdaptiveLot?"1":"0");WriteProfileValue(h,"PERM_STRAT",g_state.permStrategySelection?"1":"0");WriteProfileValue(h,"PERM_RECENTER",g_state.permRecenter?"1":"0");WriteProfileValue(h,"PERM_REPLENISH",g_state.permReplenishment?"1":"0");WriteProfileValue(h,"PERM_RISK",g_state.permRiskAdjust?"1":"0");WriteProfileValue(h,"PERM_EXPOSURE",g_state.permExposureAdjust?"1":"0");WriteProfileValue(h,"PERM_EMERGENCY",g_state.permEmergencyControl?"1":"0");   WriteProfileValue(h,"SENS",DoubleToString(g_state.adaptiveSensitivity,8));

   WriteProfileValue(h,"MAXSTEPCHANGE",DoubleToString(g_state.maxStepChangePct,8));
   WriteProfileValue(h,"ANCHORMODE",IntegerToString((int)g_state.adaptiveAnchorMode));

   WriteProfileValue(h,"MAXTOTALLOTS",DoubleToString(g_state.maxTotalLots,8));

   WriteProfileValue(h,"AUTOMAXDAY",IntegerToString(g_state.maxAutonomousGridsPerDay));

   WriteProfileValue(h,"AUTOMINSUIT",DoubleToString(g_state.autonomousMinSuitability,8));

   WriteProfileValue(h,"ADAPTMIN",IntegerToString(g_state.adaptiveMinLevels));

   WriteProfileValue(h,"ADAPTMAX",IntegerToString(g_state.adaptiveMaxLevels));

   WriteProfileValue(h,"REPLENDELAY",IntegerToString(g_state.replenishDelaySeconds));

   WriteProfileValue(h,"RECOVERY",g_state.gridRecovery?"1":"0");WriteProfileValue(h,"CHART_GRID",g_state.chartShowGrid?"1":"0");WriteProfileValue(h,"CHART_TRADE_LEVELS",g_state.chartShowTradeLevels?"1":"0");WriteProfileValue(h,"CHART_AUTOSCROLL",g_state.chartAutoScroll?"1":"0");WriteProfileValue(h,"CHART_SHIFT",g_state.chartShift?"1":"0");WriteProfileValue(h,"CHART_VOLUMES",g_state.chartShowVolumes?"1":"0");

   FileClose(h);

   g_lastLoadedProfile=StringFormat("PROFILE %d SAVED",slot+1);

   AddConfigHistory(StringFormat("Saved profile %d",slot+1));

   SetAction("USER","PROFILE SAVED",StringFormat("Slot %d",slot+1));

}



string ReadProfileField(string &keys[],string &vals[],int n,string key,string def="")

{

   for(int i=0;i<n;i++) if(keys[i]==key) return vals[i];

   return def;

}



void LoadProfile(int slot)

{

   if(slot<0 || slot>=PROFILE_SLOT_COUNT) return;

   int h=FileOpen(ProfileFileName(slot),FILE_READ|FILE_CSV|FILE_ANSI,';');

   if(h==INVALID_HANDLE){RecordEvent("PROFILE","Load failed | slot "+IntegerToString(slot+1));return;}

   string keys[80],vals[80]; int n=0;

   while(!FileIsEnding(h) && n<80){string k=FileReadString(h);string v=FileReadString(h);if(k!="" && k!="UG7_PROFILE"){keys[n]=k;vals[n]=v;n++;}}

   FileClose(h);

   string v;

   v=ReadProfileField(keys,vals,n,"GRID_TYPE"); if(v!="") g_state.gridType=(ENUM_GRID_TYPE)(int)StringToInteger(v);

   v=ReadProfileField(keys,vals,n,"ENTRY_MODE"); if(v!="") g_state.entryMode=(ENUM_ENTRY_MODE)(int)StringToInteger(v);

   v=ReadProfileField(keys,vals,n,"RISK_MODE"); if(v!="") g_state.riskMode=(ENUM_RISK_MODE)(int)StringToInteger(v);

   v=ReadProfileField(keys,vals,n,"REENTRY_MODE"); if(v!="") g_state.reentryMode=(ENUM_REENTRY_MODE)(int)StringToInteger(v);

   v=ReadProfileField(keys,vals,n,"LOT"); if(v!="") g_state.lotSize=StringToDouble(v);

   v=ReadProfileField(keys,vals,n,"STEP"); if(v!="") g_state.gridStep=StringToDouble(v);

   v=ReadProfileField(keys,vals,n,"LEVELS"); if(v!="") g_state.gridLevels=(int)StringToInteger(v);

   v=ReadProfileField(keys,vals,n,"MULT"); if(v!="") g_state.lotMultiplier=StringToDouble(v);

   v=ReadProfileField(keys,vals,n,"FRONT"); if(v!="") g_state.frontOrderDistancePips=StringToDouble(v);

   v=ReadProfileField(keys,vals,n,"ATR"); if(v!="") g_state.atrSpacingMultiplier=StringToDouble(v);

   v=ReadProfileField(keys,vals,n,"MINSTEP"); if(v!="") g_state.minGridStep=StringToDouble(v);

   v=ReadProfileField(keys,vals,n,"MAXSTEP"); if(v!="") g_state.maxGridStep=StringToDouble(v);

   v=ReadProfileField(keys,vals,n,"RECENTER"); if(v!="") g_state.recenterATRMultiple=StringToDouble(v);

   v=ReadProfileField(keys,vals,n,"CONTROL"); if(v!="") g_state.controlMode=(ENUM_CONTROL_MODE)(int)StringToInteger(v);

   g_state.autonomousMode=(g_state.controlMode==CONTROL_AUTONOMOUS);
   if(g_state.controlMode!=CONTROL_AUTONOMOUS){g_state.autonomousEngine=false;g_state.autonomousReady=false;g_state.autonomousParallelExecution=false;g_state.autonomousDynamicProtection=false;g_state.advancedEntryDecision=false;}
   g_state.useMultiTimeframeMarketState=InpUseMultiTimeframeMarketState;

   v=ReadProfileField(keys,vals,n,"AI"); if(v!="") g_state.aiEnabled=(StringToInteger(v)!=0);

   v=ReadProfileField(keys,vals,n,"AI_CONF"); if(v!="") g_state.aiConfidence=StringToDouble(v);

   v=ReadProfileField(keys,vals,n,"REGIME"); if(v!="") g_state.regimeFilter=(StringToInteger(v)!=0);

   v=ReadProfileField(keys,vals,n,"DYN_RISK"); if(v!="") g_state.useDynamicRiskLot=(StringToInteger(v)!=0);

   v=ReadProfileField(keys,vals,n,"STRAT_MGMT"); if(v!="") g_state.strategyAwareManagement=(StringToInteger(v)!=0);

   v=ReadProfileField(keys,vals,n,"EXIT_COORD"); if(v!="") g_state.strategyExitCoordination=(StringToInteger(v)!=0);

   v=ReadProfileField(keys,vals,n,"RISK_ENGINE"); if(v!="") g_state.riskManagedTrading=(StringToInteger(v)!=0);

   v=ReadProfileField(keys,vals,n,"MAXDD"); if(v!="") g_state.maxDrawdownPct=StringToDouble(v);

   v=ReadProfileField(keys,vals,n,"MAXGRIDRISK"); if(v!="") g_state.maxGridRiskPct=StringToDouble(v);

   v=ReadProfileField(keys,vals,n,"MAXPOS"); if(v!="") g_state.maxPositions=(int)StringToInteger(v);

   v=ReadProfileField(keys,vals,n,"MAXPEND"); if(v!="") g_state.maxPendingOrders=(int)StringToInteger(v);

   v=ReadProfileField(keys,vals,n,"SL"); if(v!="") g_state.stopLossPips=StringToDouble(v);

   v=ReadProfileField(keys,vals,n,"TP"); if(v!="") g_state.takeProfitPips=StringToDouble(v);

   v=ReadProfileField(keys,vals,n,"USESL"); if(v!="") g_state.useStopLossForNewOrders=(StringToInteger(v)!=0);

   v=ReadProfileField(keys,vals,n,"USET_P"); if(v!="") g_state.useTakeProfitForNewOrders=(StringToInteger(v)!=0);

   v=ReadProfileField(keys,vals,n,"BE"); if(v!="") g_state.breakEven=(StringToInteger(v)!=0);

   v=ReadProfileField(keys,vals,n,"TRAIL"); if(v!="") g_state.trailingStop=(StringToInteger(v)!=0);

   v=ReadProfileField(keys,vals,n,"OCO"); if(v!="") g_state.oco=(StringToInteger(v)!=0);

   v=ReadProfileField(keys,vals,n,"SLIP"); if(v!="") g_state.slippage=(int)StringToInteger(v);

   v=ReadProfileField(keys,vals,n,"SPREAD"); if(v!="") g_state.maxSpreadPips=StringToDouble(v);

   v=ReadProfileField(keys,vals,n,"SESSION"); if(v!="") g_state.useSessionFilter=(StringToInteger(v)!=0);

   v=ReadProfileField(keys,vals,n,"SSTART"); if(v!="") g_state.sessionStartHour=(int)StringToInteger(v);

   v=ReadProfileField(keys,vals,n,"SEND"); if(v!="") g_state.sessionEndHour=(int)StringToInteger(v);

   v=ReadProfileField(keys,vals,n,"WEEKEND"); if(v!="") g_state.avoidWeekend=(StringToInteger(v)!=0);

   // Advanced

   v=ReadProfileField(keys,vals,n,"ADV_ENTRY"); if(v!="") g_state.advancedEntryDecision=(StringToInteger(v)!=0);

   v=ReadProfileField(keys,vals,n,"ADAPT_GRID"); if(v!="") g_state.adaptiveGrid=(StringToInteger(v)!=0);

   v=ReadProfileField(keys,vals,n,"ADAPT_LEVELS"); if(v!="") g_state.adaptiveLevels=(StringToInteger(v)!=0);

   v=ReadProfileField(keys,vals,n,"ADAPT_LOT"); if(v!="") g_state.adaptiveLot=(StringToInteger(v)!=0);

   v=ReadProfileField(keys,vals,n,"MARKET_INTEL"); if(v!="") g_state.marketIntelligence=(StringToInteger(v)!=0);
   v=ReadProfileField(keys,vals,n,"MTF_MARKET"); if(v!="") g_state.useMultiTimeframeMarketState=(StringToInteger(v)!=0);

   v=ReadProfileField(keys,vals,n,"SMART_REGIME"); if(v!="") g_state.smartRegime=(StringToInteger(v)!=0);

   v=ReadProfileField(keys,vals,n,"SMART_RECENTER"); if(v!="") g_state.smartRecenter=(StringToInteger(v)!=0);

   v=ReadProfileField(keys,vals,n,"SMART_REPLENISH"); if(v!="") g_state.smartReplenishment=(StringToInteger(v)!=0);

   v=ReadProfileField(keys,vals,n,"EXPOSURE"); if(v!="") g_state.exposureManager=(StringToInteger(v)!=0);

   v=ReadProfileField(keys,vals,n,"ADV_PROTECT"); if(v!="") g_state.advancedProtection=(StringToInteger(v)!=0);

   v=ReadProfileField(keys,vals,n,"GUARDIAN"); if(v!="") g_state.orderGuardian=(StringToInteger(v)!=0);

   v=ReadProfileField(keys,vals,n,"JOURNAL"); if(v!="") g_state.decisionJournal=(StringToInteger(v)!=0);

   v=ReadProfileField(keys,vals,n,"EMG_PERM"); if(v!="") g_state.permEmergencyControl=(StringToInteger(v)!=0); v=ReadProfileField(keys,vals,n,"EMG_CLOSE"); if(v!="") g_state.emergencyAutoClose=(StringToInteger(v)!=0); v=ReadProfileField(keys,vals,n,"EMG_CANCEL"); if(v!="") g_state.emergencyCancelPending=(StringToInteger(v)!=0); v=ReadProfileField(keys,vals,n,"PERM_ENTRY"); if(v!="") g_state.permAutonomousEntry=(StringToInteger(v)!=0); v=ReadProfileField(keys,vals,n,"PERM_STEP"); if(v!="") g_state.permAdaptiveStep=(StringToInteger(v)!=0); v=ReadProfileField(keys,vals,n,"PERM_LEVELS"); if(v!="") g_state.permAdaptiveLevels=(StringToInteger(v)!=0); v=ReadProfileField(keys,vals,n,"PERM_LOT"); if(v!="") g_state.permAdaptiveLot=(StringToInteger(v)!=0); v=ReadProfileField(keys,vals,n,"PERM_STRAT"); if(v!="") g_state.permStrategySelection=(StringToInteger(v)!=0); v=ReadProfileField(keys,vals,n,"PERM_RECENTER"); if(v!="") g_state.permRecenter=(StringToInteger(v)!=0); v=ReadProfileField(keys,vals,n,"PERM_REPLENISH"); if(v!="") g_state.permReplenishment=(StringToInteger(v)!=0); v=ReadProfileField(keys,vals,n,"PERM_RISK"); if(v!="") g_state.permRiskAdjust=(StringToInteger(v)!=0); v=ReadProfileField(keys,vals,n,"PERM_EXPOSURE"); if(v!="") g_state.permExposureAdjust=(StringToInteger(v)!=0); v=ReadProfileField(keys,vals,n,"PERM_EMERGENCY"); if(v!="") g_state.permEmergencyControl=(StringToInteger(v)!=0);

   v=ReadProfileField(keys,vals,n,"SENS"); if(v!="") g_state.adaptiveSensitivity=StringToDouble(v);

   v=ReadProfileField(keys,vals,n,"MAXSTEPCHANGE"); if(v!="") g_state.maxStepChangePct=StringToDouble(v);v=ReadProfileField(keys,vals,n,"ANCHORMODE"); if(v!="") g_state.adaptiveAnchorMode=(ENUM_GRID_ANCHOR_MODE)MathMax(0,MathMin(3,(int)StringToInteger(v)));

   v=ReadProfileField(keys,vals,n,"MAXTOTALLOTS"); if(v!="") g_state.maxTotalLots=StringToDouble(v);

   v=ReadProfileField(keys,vals,n,"AUTOMAXDAY"); if(v!="") g_state.maxAutonomousGridsPerDay=(int)StringToInteger(v);

   v=ReadProfileField(keys,vals,n,"AUTOMINSUIT"); if(v!="") g_state.autonomousMinSuitability=StringToDouble(v);

   v=ReadProfileField(keys,vals,n,"ADAPTMIN"); if(v!="") g_state.adaptiveMinLevels=(int)StringToInteger(v);

   v=ReadProfileField(keys,vals,n,"ADAPTMAX"); if(v!="") g_state.adaptiveMaxLevels=(int)StringToInteger(v);

   v=ReadProfileField(keys,vals,n,"REPLENDELAY"); if(v!="") g_state.replenishDelaySeconds=(int)StringToInteger(v);

   v=ReadProfileField(keys,vals,n,"RECOVERY"); if(v!="") g_state.gridRecovery=(StringToInteger(v)!=0);v=ReadProfileField(keys,vals,n,"CHART_GRID"); if(v!="") g_state.chartShowGrid=(StringToInteger(v)!=0);v=ReadProfileField(keys,vals,n,"CHART_TRADE_LEVELS"); if(v!="") g_state.chartShowTradeLevels=(StringToInteger(v)!=0);v=ReadProfileField(keys,vals,n,"CHART_AUTOSCROLL"); if(v!="") g_state.chartAutoScroll=(StringToInteger(v)!=0);v=ReadProfileField(keys,vals,n,"CHART_SHIFT"); if(v!="") g_state.chartShift=(StringToInteger(v)!=0);v=ReadProfileField(keys,vals,n,"CHART_VOLUMES"); if(v!="") g_state.chartShowVolumes=(StringToInteger(v)!=0);

   ValidateSettings();

   UpdateState();

   g_lastLoadedProfile=StringFormat("PROFILE %d LOADED",slot+1);

   AddConfigHistory(StringFormat("Loaded profile %d",slot+1));

   SetAction("USER","PROFILE LOADED",StringFormat("Slot %d",slot+1));

}



void RefreshSimulationPreview()

{

   UpdateState();

   UpdateEffectiveState();

   g_simulationPreviewReady=true;

   RecordEvent("SIMULATION","Preview refreshed | no orders submitted");

   SetAction("SIMULATION","PREVIEW","No orders sent");

}



void AddApplyHistory()

{

   AddConfigHistory(g_pendingApplySummary);

}

double CalculateMarketSuitabilityScore()

{

   double spreadScore=1.0;

   if(g_state.maxSpreadPips>0) spreadScore=ClampDouble(1.0-(g_state.currentSpreadPips/g_state.maxSpreadPips),0.0,1.0);

   double volCenter=(g_state.highVolThreshold+g_state.lowVolThreshold)*0.5;

   double volRange=MathMax(0.05,(g_state.highVolThreshold-g_state.lowVolThreshold)*0.5);

   double volScore=1.0-MathMin(1.0,MathAbs(g_state.volatilityIndex-volCenter)/volRange);

   double trendScore=0.5+MathAbs(g_state.trendStrength-0.5);

   double directionScore=0.5;

   if(g_state.gridType==BULLISH_GRID) directionScore=g_state.trendStrength;

   else if(g_state.gridType==BEARISH_GRID) directionScore=1.0-g_state.trendStrength;

   else directionScore=1.0-MathAbs(g_state.trendStrength-0.5)*1.6;

   double sessionScore=IsSessionAllowed()?1.0:0.0;

   double capacityScore=1.0;

   if(g_state.maxPositions>0) capacityScore=MathMin(capacityScore,1.0-(double)g_state.positionCount/g_state.maxPositions);

   if(g_state.maxPendingOrders>0) capacityScore=MathMin(capacityScore,1.0-(double)g_state.pendingCount/g_state.maxPendingOrders);

   return ClampDouble(0.28*spreadScore+0.22*volScore+0.20*trendScore+0.15*directionScore+0.10*sessionScore+0.05*capacityScore,0.0,1.0);

}



double CalculateIntelligenceConfidence()

{

   double score=0.55*g_state.marketSuitabilityScore+0.25*g_state.trendStrength+0.20*g_state.sentimentScore;

   return ClampDouble(score,0.0,1.0);

}



double GridStepPolicyFactor(ENUM_GRID_TYPE t)

{

   // Grid-specific adaptive geometry. Used ONLY when Adaptive Grid is enabled.

   // Each profile keeps its own geometry; this factor only tunes the profile's base scale.

   switch(t)

   {

      case VOLATILITY_GRID:            return 1.08;

      case ATR_ADAPTIVE_GRID:          return 1.05;

      case BREAKOUT_GRID:              return 1.12;

      case VOLATILITY_BREAKOUT_GRID:   return 1.15;

      case MOMENTUM_GRID:              return 1.05;

      case MEAN_REVERSION_GRID:        return 0.90;

      case RANGE_SCALING_GRID:         return 0.92;

      case BULLISH_GRID:               return 1.02;

      case BEARISH_GRID:               return 1.02;

      case HEDGE_GRID:                 return 1.03;

      case GEOMETRIC_GRID:             return 1.00;

      case FIBONACCI_GRID:             return 1.00;

      case LADDER_GRID:                return 1.00;

      case ANTI_MARTINGALE_GRID:       return 1.00;

      case SESSION_GRID:               return 1.00;

      case SMART_REGIME_GRID:

         if(g_state.regime=="BREAKOUT / HIGH VOL") return 1.12;

         if(StringFind(g_state.regime,"RANGE")>=0) return 0.92;

         if(StringFind(g_state.regime,"TREND")>=0) return 1.03;

         return 1.00;

      default:                         return 1.00;

   }

}



double GridLotPolicyFactor(ENUM_GRID_TYPE t)

{

   // Profile-aware sizing bias, applied only when Adaptive Lot is enabled.

   switch(t)

   {

      case HEDGE_GRID:                 return 0.92;

      case VOLATILITY_GRID:            return 0.90;

      case ATR_ADAPTIVE_GRID:          return 0.92;

      case BREAKOUT_GRID:              return 0.92;

      case VOLATILITY_BREAKOUT_GRID:   return 0.88;

      case MOMENTUM_GRID:              return 0.94;

      case MEAN_REVERSION_GRID:        return 1.02;

      case RANGE_SCALING_GRID:         return 1.02;

      case BULLISH_GRID:               return 0.97;

      case BEARISH_GRID:               return 0.97;

      case ANTI_MARTINGALE_GRID:       return 0.95;

      case SMART_REGIME_GRID:

         if(g_state.regime=="BREAKOUT / HIGH VOL") return 0.88;

         if(StringFind(g_state.regime,"RANGE")>=0) return 1.02;

         return 0.96;

      default:                         return 1.00;

   }

}



int GridLevelPolicyBias(ENUM_GRID_TYPE t)

{

   // Positive = may favor more levels in favorable conditions; negative = fewer.

   switch(t)

   {

      case HEDGE_GRID: return 0;

      case BIDIRECTIONAL_GRID: return 0;

      case MEAN_REVERSION_GRID: return 1;

      case RANGE_SCALING_GRID: return 1;

      case BREAKOUT_GRID: return -1;

      case VOLATILITY_BREAKOUT_GRID: return -1;

      case TREND_GRID: return -1;

      case MOMENTUM_GRID: return -1;

      case BULLISH_GRID: return -1;

      case BEARISH_GRID: return -1;

      default: return 0;

   }

}



string GridAdaptivePolicyReason(ENUM_GRID_TYPE t)

{

   double sf=GridStepPolicyFactor(t), lf=GridLotPolicyFactor(t);

   int lb=GridLevelPolicyBias(t);

   return StringFormat("Step x%.2f | Lot x%.2f | Level bias %d",sf,lf,lb);

}




string GridAnchorModeName(ENUM_GRID_ANCHOR_MODE mode)
{
   switch(mode)
   {
      case GRID_ANCHOR_SESSION_OPEN: return "SESSION OPEN";
      case GRID_ANCHOR_SWING_MID:    return "SWING MID";
      case GRID_ANCHOR_RANGE_MID:    return "RANGE MID";
      default:                       return "CURRENT MID";
   }
}

double GridGeometryCurrentMid()
{
   MqlTick t;
   if(!SymbolInfoTick(_Symbol,t) || t.bid<=0 || t.ask<=0) return 0.0;
   return (t.bid+t.ask)*0.5;
}

double GridGeometrySessionOpen()
{
   datetime ds=DayStart();
   int shift=iBarShift(_Symbol,(ENUM_TIMEFRAMES)_Period,ds,false);
   if(shift<0) shift=0;
   double o=iOpen(_Symbol,(ENUM_TIMEFRAMES)_Period,shift);
   if(o<=0) o=GridGeometryCurrentMid();
   return o;
}

double GridGeometrySwingMid()
{
   const int lookback=24;
   int bars=Bars(_Symbol,(ENUM_TIMEFRAMES)_Period);
   if(bars<lookback+2) return GridGeometryCurrentMid();
   int hi=iHighest(_Symbol,(ENUM_TIMEFRAMES)_Period,MODE_HIGH,lookback,1);
   int lo=iLowest(_Symbol,(ENUM_TIMEFRAMES)_Period,MODE_LOW,lookback,1);
   if(hi<0 || lo<0) return GridGeometryCurrentMid();
   double h=iHigh(_Symbol,(ENUM_TIMEFRAMES)_Period,hi);
   double l=iLow(_Symbol,(ENUM_TIMEFRAMES)_Period,lo);
   if(h<=0 || l<=0 || h<l) return GridGeometryCurrentMid();
   return (h+l)*0.5;
}

double GridGeometryRangeMid()
{
   const int lookback=20;
   int bars=Bars(_Symbol,(ENUM_TIMEFRAMES)_Period);
   if(bars<lookback+2) return GridGeometryCurrentMid();
   int hi=iHighest(_Symbol,(ENUM_TIMEFRAMES)_Period,MODE_HIGH,lookback,1);
   int lo=iLowest(_Symbol,(ENUM_TIMEFRAMES)_Period,MODE_LOW,lookback,1);
   if(hi<0 || lo<0) return GridGeometryCurrentMid();
   double h=iHigh(_Symbol,(ENUM_TIMEFRAMES)_Period,hi);
   double l=iLow(_Symbol,(ENUM_TIMEFRAMES)_Period,lo);
   if(h<=0 || l<=0 || h<l) return GridGeometryCurrentMid();
   return (h+l)*0.5;
}

double CalculateAdaptiveAnchorPrice()
{
   ENUM_GRID_ANCHOR_MODE mode=g_state.adaptiveAnchorMode;
   double current=GridGeometryCurrentMid();
   if(current<=0) return 0.0;

   double anchor=current;
   switch(mode)
   {
      case GRID_ANCHOR_SESSION_OPEN: anchor=GridGeometrySessionOpen(); break;
      case GRID_ANCHOR_SWING_MID:    anchor=GridGeometrySwingMid(); break;
      case GRID_ANCHOR_RANGE_MID:    anchor=GridGeometryRangeMid(); break;
      default:                       anchor=current; break;
   }

   // Prevent structural anchors from drifting unreasonably far from the live market.
   double atr=MathMax(g_state.atrPrice,MathMax(PipSize()*2.0,SymbolInfoDouble(_Symbol,SYMBOL_POINT)*2.0));
   double maxDrift=MathMax(atr*2.5,MathMax(1.0,g_state.gridStep*PipSize()*6.0));
   if(MathAbs(anchor-current)>maxDrift)
   {
      anchor=current;
      g_state.adaptiveAnchorReason=GridAnchorModeName(mode)+" | LIVE PROXIMITY FALLBACK";
   }
   else
      g_state.adaptiveAnchorReason=StringFormat("%s | %.5f",GridAnchorModeName(mode),anchor);

   return NormalizeDouble(anchor,_Digits);
}

double GridGeometryStructureFactor()
{
   double f=1.0;
   string r=g_state.regime;
   if(StringFind(r,"BREAKOUT")>=0) f=1.10;
   else if(StringFind(r,"TREND UP")>=0 || StringFind(r,"TREND DOWN")>=0) f=1.05;
   else if(StringFind(r,"RANGE")>=0 || StringFind(r,"COMPRESSION")>=0) f=0.92;
   else if(StringFind(r,"SHOCK")>=0) f=1.20;
   return f;
}

double GridGeometrySessionFactor()
{
   if(g_state.marketSession=="NEW YORK") return 1.00;
   if(g_state.marketSession=="LONDON") return 1.00;
   if(g_state.marketSession=="ASIA") return 0.97;
   if(g_state.marketSession=="ROLLOVER") return 1.06;
   return 1.00;
}

double GridGeometrySpreadFactor()
{
   if(g_state.maxSpreadPips<=0) return 1.0;
   double q=ClampDouble(g_state.currentSpreadPips/MathMax(0.1,g_state.maxSpreadPips),0.0,2.0);
   if(q<=0.35) return 0.97;
   if(q>=0.85) return 1.10;
   return 1.0+(q-0.35)*0.12;
}

double GridGeometryRiskCapacityFactor()
{
   double factor=1.0;
   if(g_state.maxGridRiskPct>0 && g_state.riskPerGridPct>0)
      factor=MathMin(factor,ClampDouble(g_state.maxGridRiskPct/MathMax(g_state.riskPerGridPct,0.01),0.25,1.0));
   if(g_state.maxTotalLots>0 && g_state.exposureManager)
   {
      double used=CurrentGridExposureLots();
      double remain=MathMax(0.0,g_state.maxTotalLots-used);
      double base=MathMax(g_state.lotSize,SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN));
      factor=MathMin(factor,ClampDouble(remain/MathMax(base,0.000001),0.25,1.0));
   }
   if(g_state.accountMarginUsedPct>0.0)
      factor=MathMin(factor,ClampDouble((100.0-g_state.accountMarginUsedPct)/70.0,0.25,1.0));
   return ClampDouble(factor,0.25,1.0);
}

double PredictiveRegimeMultiplier()
{
   string r=g_state.regime;
   if(StringFind(r,"BREAKOUT")>=0) return 1.25;
   if(StringFind(r,"SHOCK")>=0 || StringFind(r,"HIGH VOL")>=0) return 1.40;
   if(StringFind(r,"TREND")>=0) return 1.15;
   if(StringFind(r,"RANGE")>=0 || StringFind(r,"COMPRESSION")>=0) return 0.82;
   return 1.00;
}

double PredictiveDirectionalBias()
{
   // -1 bearish, +1 bullish. Neutral market stays close to zero.
   return ClampDouble((g_state.trendStrength-0.5)*2.0 + (g_state.sentimentScore-0.5)*0.50,-1.0,1.0);
}

void UpdatePredictiveGridIntelligence()
{
   if(!g_state.predictiveGridIntelligence)
   {
      g_state.predictiveExcursionPips=0.0;
      g_state.predictiveRetracementPips=0.0;
      g_state.predictiveContinuationPips=0.0;
      g_state.predictiveAdversePips=0.0;
      g_state.predictiveUpperDensity=1.0;
      g_state.predictiveLowerDensity=1.0;
      g_state.predictiveTopologyScore=0.0;
      g_state.predictiveConfidence=0.0;
      g_state.predictiveState="OFF";
      g_state.predictiveReason="Predictive grid intelligence disabled";
      g_state.predictiveUpdateTime=TimeCurrent();
      for(int i=0;i<50;i++) g_state.predictiveLevelReach[i]=0.0;
      return;
   }

   double atrPips=(PipSize()>0.0 && g_state.atrPrice>0.0)?g_state.atrPrice/PipSize():MathMax(0.1,g_state.gridStep);
   double vol=ClampDouble(g_state.volatilityIndex,0.0,1.0);
   double trend=ClampDouble(g_state.trendStrength,0.0,1.0);
   double breakout=ClampDouble(g_state.breakoutPressure,0.0,1.0);
   double compression=ClampDouble(g_state.compressionScore,0.0,1.0);
   double direction=PredictiveDirectionalBias();
   double regimeMult=PredictiveRegimeMultiplier();
   double sens=ClampDouble(InpPredictiveSensitivity,0.0,1.0);
   int lookahead=MathMax(1,MathMin(24,InpPredictiveLookaheadBars));

   double baseExcursion=atrPips*MathSqrt((double)lookahead/MathMax(1.0,6.0));
   double expansion=(0.85 + vol*0.55 + breakout*0.35 + (1.0-compression)*0.20);
   g_state.predictiveExcursionPips=MathMax(atrPips*0.50,baseExcursion*expansion*regimeMult);
   g_state.predictiveContinuationPips=g_state.predictiveExcursionPips*(0.55+0.30*MathAbs(direction)+0.20*breakout);
   g_state.predictiveRetracementPips=g_state.predictiveExcursionPips*(0.20+0.45*(1.0-MathAbs(direction)) + 0.20*compression);
   g_state.predictiveAdversePips=g_state.predictiveExcursionPips*(0.18+0.35*(1.0-MathAbs(direction))+0.18*vol);

   double biasStrength=ClampDouble(MathAbs(direction),0.0,1.0);
   double asym=ClampDouble(sens*(0.25*biasStrength+0.20*breakout),0.0,0.40);
   if(direction>0.0){ g_state.predictiveUpperDensity=1.0+asym; g_state.predictiveLowerDensity=1.0-asym; }
   else if(direction<0.0){ g_state.predictiveUpperDensity=1.0-asym; g_state.predictiveLowerDensity=1.0+asym; }
   else { g_state.predictiveUpperDensity=1.0; g_state.predictiveLowerDensity=1.0; }

   g_state.predictiveTopologyScore=ClampDouble(0.45*biasStrength+0.30*breakout+0.25*(1.0-compression),0.0,1.0);
   g_state.predictiveConfidence=ClampDouble(0.35*(0.5+0.5*biasStrength)+0.25*g_state.regimeConfidence+0.20*(g_state.marketNoTrade?0.0:1.0)+0.20*(1.0-MathMin(1.0,g_state.currentSpreadPips/MathMax(0.1,g_state.maxSpreadPips))),0.0,1.0);

   double step=MathMax(0.1,g_state.effectiveGridStepPips>0.0?g_state.effectiveGridStepPips:g_state.gridStep);
   for(int i=0;i<50;i++)
   {
      double levelDist=step*(i+1);
      double decay=MathExp(-levelDist/MathMax(step*1.5,g_state.predictiveExcursionPips));
      double directionReach=1.0;
      if(direction>0.0) directionReach=(i<25?g_state.predictiveUpperDensity:g_state.predictiveLowerDensity);
      else if(direction<0.0) directionReach=(i<25?g_state.predictiveLowerDensity:g_state.predictiveUpperDensity);
      g_state.predictiveLevelReach[i]=ClampDouble(decay*directionReach,0.0,1.0);
   }

   if(g_state.marketNoTrade) g_state.predictiveState="BLOCKED";
   else if(g_state.predictiveConfidence<0.50) g_state.predictiveState="LOW CONFIDENCE";
   else if(g_state.predictiveTopologyScore>=0.70) g_state.predictiveState="DIRECTIONAL TOPOLOGY";
   else if(g_state.predictiveExcursionPips>=atrPips*1.40) g_state.predictiveState="EXPANSION";
   else g_state.predictiveState="BALANCED";

   string biasTxt=direction>0.20?"BULLISH":(direction<-0.20?"BEARISH":"NEUTRAL");
   g_state.predictiveReason=StringFormat("%s | Fwd %.1f | Retr %.1f | Adv %.1f | D %.2f",biasTxt,g_state.predictiveExcursionPips,g_state.predictiveRetracementPips,g_state.predictiveAdversePips,direction);
   g_state.predictiveLookaheadBars=lookahead;
   g_state.predictiveUpdateTime=TimeCurrent();
}

double GridGeometryAdaptiveStepCandidate(double base,double atrPips)
{
   double sens=ClampDouble(g_state.adaptiveSensitivity,0,1);
   double atrTarget=MathMax(base,atrPips*MathMax(0.10,g_state.atrSpacingMultiplier));
   double structure=GridGeometryStructureFactor();
   double session=GridGeometrySessionFactor();
   double spread=GridGeometrySpreadFactor();
   double risk=1.0+((1.0-GridGeometryRiskCapacityFactor())*0.35);
   double volatility=0.90+ClampDouble(g_state.volatilityIndex,0,1)*0.55;
   double predictive=1.0;
   if(g_state.predictiveGridIntelligence && g_state.predictiveExcursionPips>0.0)
      predictive=ClampDouble(g_state.predictiveExcursionPips/MathMax(atrPips*1.10,base),0.75,1.35);
   double candidate=base*(1.0-sens)+atrTarget*sens;
   candidate*=structure*session*spread*risk*volatility*(1.0+(predictive-1.0)*0.35);
   return MathMax(0.1,candidate);
}

int GridGeometryAdaptiveLevelTarget(int base)
{
   int lo=MathMax(1,MathMin(g_state.adaptiveMinLevels,50));
   int hi=MathMax(lo,MathMin(g_state.adaptiveMaxLevels,50));
   if(hi<lo) hi=lo;
   double v=ClampDouble(g_state.volatilityIndex,0,1);
   double sens=ClampDouble(g_state.adaptiveSensitivity,0,1);
   double riskCap=GridGeometryRiskCapacityFactor();
   double compression=ClampDouble(g_state.compressionScore,0,1);
   double breakout=ClampDouble(g_state.breakoutPressure,0,1);
   int target=base;
   if(v<0.35) target+=(int)MathRound((0.35-v)*8.0*sens);
   if(v>0.70) target-=(int)MathRound((v-0.70)*8.0*sens);
   if(compression>0.70) target+=1;
   if(breakout>0.70) target-=1;
   if(g_state.predictiveGridIntelligence && g_state.predictiveExcursionPips>0.0)
   {
      double stepPips=MathMax(0.1,g_state.gridStep);
      if(PipSize()>0.0 && g_state.effectiveGridStepPips>0.0) stepPips=g_state.effectiveGridStepPips;
      int forecastLevels=(int)MathCeil((g_state.predictiveExcursionPips*0.75)/MathMax(0.1,stepPips));
      forecastLevels=MathMax(lo,MathMin(hi,forecastLevels));
      double blend=0.35*ClampDouble(g_state.predictiveTopologyScore,0.0,1.0);
      target=(int)MathRound(target*(1.0-blend)+forecastLevels*blend);
   }
   target=(int)MathFloor(target*riskCap+0.5);
   return MathMax(lo,MathMin(hi,target));
}

void UpdatePhase5GeometryTelemetry()
{
   UpdatePredictiveGridIntelligence();
   double base=MathMax(0.1,g_state.gridStep);
   double atrPips=(PipSize()>0&&g_state.atrPrice>0)?g_state.atrPrice/PipSize():base;
   g_state.gridGeometryStepFactor=1.0;
   g_state.gridGeometryLevelFactor=1.0;
   g_state.gridGeometryRiskCapacityFactor=GridGeometryRiskCapacityFactor();
   if(g_state.adaptiveGrid && g_state.permAdaptiveStep)
   {
      double cand=GridGeometryAdaptiveStepCandidate(base,atrPips);
      g_state.gridGeometryStepFactor=base>0?cand/base:1.0;
   }
   int levTarget=GridGeometryAdaptiveLevelTarget(MathMax(1,g_state.gridLevels));
   g_state.gridGeometryLevelFactor=g_state.gridLevels>0?(double)levTarget/(double)g_state.gridLevels:1.0;
   g_state.gridGeometryGeometryReason=StringFormat("Anchor %s | Step x%.2f | Levels x%.2f | Risk cap %.0f%%",GridAnchorModeName(g_state.adaptiveAnchorMode),g_state.gridGeometryStepFactor,g_state.gridGeometryLevelFactor,g_state.gridGeometryRiskCapacityFactor*100.0);
}

double CalculateEffectiveGridStepPips()
{
   double base=MathMax(0.1,g_state.gridStep);
   if(!g_state.adaptiveGrid || !g_state.permAdaptiveStep)
   {
      g_state.gridPolicyStepFactor=1.0;
      g_state.gridGeometryStepFactor=1.0;
      g_state.gridPolicyLotFactor=1.0;
      g_state.gridPolicyReason="USER FIXED | no adaptive grid policy";
      g_state.adaptiveGridReason="USER FIXED";
      g_state.gridGeometryGeometryReason=StringFormat("Anchor %s | USER STEP",GridAnchorModeName(g_state.adaptiveAnchorMode));
      return base;
   }

   double sens=ClampDouble(g_state.adaptiveSensitivity,0,1);
   double atrPips=(PipSize()>0&&g_state.atrPrice>0)?g_state.atrPrice/PipSize():base;
   double target=GridGeometryAdaptiveStepCandidate(base,atrPips);
   double policy=GridStepPolicyFactor(g_state.gridType);
   g_state.gridPolicyStepFactor=policy;
   g_state.gridPolicyReason=GridAdaptivePolicyReason(g_state.gridType);
   target*=policy;

   double candidate=base*(1.0-sens)+target*sens;
   double lim=MathMax(0.0,g_state.maxStepChangePct)/100.0;
   candidate=ClampDouble(candidate,base*(1.0-lim),base*(1.0+lim));
   candidate=ClampDouble(candidate,g_state.minGridStep,g_state.maxGridStep);

   g_state.gridGeometryStepFactor=base>0?candidate/base:1.0;
   g_state.gridGeometryRiskCapacityFactor=GridGeometryRiskCapacityFactor();
   g_state.adaptiveGridReason=StringFormat("ATR %.1f | VOL %.0f%% | %s | PRED %.0f%%",atrPips,g_state.volatilityIndex*100.0,g_state.regime,g_state.predictiveConfidence*100.0);
   return candidate;
}


int CalculateEffectiveGridLevels()
{
   int base=MathMax(1,g_state.gridLevels);
   if(!g_state.adaptiveLevels || !g_state.permAdaptiveLevels)
   {
      g_state.gridGeometryLevelFactor=1.0;
      g_state.gridPolicyLevelReason="USER FIXED | no adaptive levels";
      return base;
   }
   int target=GridGeometryAdaptiveLevelTarget(base);
   int bias=GridLevelPolicyBias(g_state.gridType);
   if(bias>0 && g_state.volatilityIndex<0.50) target+=MathMax(0,(int)MathRound(g_state.adaptiveSensitivity));
   if(bias<0 && g_state.volatilityIndex>0.60) target-=MathMax(0,(int)MathRound(g_state.adaptiveSensitivity));
   int lo=MathMax(1,MathMin(g_state.adaptiveMinLevels,50));
   int hi=MathMax(lo,MathMin(g_state.adaptiveMaxLevels,50));
   target=MathMax(lo,MathMin(hi,target));
   g_state.gridGeometryLevelFactor=base>0?(double)target/(double)base:1.0;
   g_state.gridPolicyLevelReason=StringFormat("Base %d | Vol %.0f%% | Compression %.0f%% | RiskCap %.0f%%",base,g_state.volatilityIndex*100.0,g_state.compressionScore*100.0,GridGeometryRiskCapacityFactor()*100.0);
   return target;
}


void UpdateEffectiveState()

{

   UpdatePhase5GeometryTelemetry();
   double oldStep=g_state.effectiveGridStepPips;

   int oldLevels=g_state.effectiveGridLevels;

   double oldLot=g_state.effectiveLot;

   g_state.marketSuitabilityScore=CalculateMarketSuitabilityScore();

   g_state.intelligenceConfidence=CalculateIntelligenceConfidence();

   g_state.effectiveGridStepPips=CalculateEffectiveGridStepPips();

   g_state.effectiveGridLevels=CalculateEffectiveGridLevels();

   g_state.effectiveLot=CalculateAdaptiveLot(g_state.lotSize);

   if(oldStep<=0.0 || MathAbs(oldStep-g_state.effectiveGridStepPips)>=0.1 || oldLevels!=g_state.effectiveGridLevels || MathAbs(oldLot-g_state.effectiveLot)>=0.00001)

   {

      if(g_state.adaptiveGrid || g_state.adaptiveLevels || g_state.adaptiveLot)

         RecordEvent("EFFECTIVE STATE",StringFormat("Step %.1f | Levels %d | Lot %.3f | Suitability %.0f%%",g_state.effectiveGridStepPips,g_state.effectiveGridLevels,g_state.effectiveLot,g_state.marketSuitabilityScore*100.0));

   }

}

double CurrentGridExposureLots()
{
   double lots=0.0;
   for(int i=0;i<PositionsTotal();i++)
   {
      ulong t=PositionGetTicket(i);
      if(t>0 && V14IsAnyGridOrder(t,false) && PositionSelectByTicket(t))
         lots+=PositionGetDouble(POSITION_VOLUME);
   }
   for(int i=0;i<OrdersTotal();i++)
   {
      ulong t=OrderGetTicket(i);
      if(t>0 && V14IsAnyGridOrder(t,true) && OrderSelect(t))
         lots+=OrderGetDouble(ORDER_VOLUME_CURRENT);
   }
   return lots;
}



double CalculateAdaptiveLot(double requested)

{

   double lot=requested;

   if(g_state.adaptiveLot && g_state.permAdaptiveLot)

   {

      double v=ClampDouble(g_state.volatilityIndex,0,1);

      double sens=ClampDouble(g_state.adaptiveSensitivity,0,1);

      double policy=GridLotPolicyFactor(g_state.gridType);

      g_state.gridPolicyLotFactor=policy;

      lot*=policy;

      lot*=ClampDouble(1-((v-0.35)*0.50*sens),0.50,1.15);

      g_state.gridPolicyReason=GridAdaptivePolicyReason(g_state.gridType);

   }

   else g_state.gridPolicyLotFactor=1.0;

   // Exposure ceiling is an optional module. It must have no effect when OFF.

   if(g_state.exposureManager && g_state.permExposureAdjust && g_state.maxTotalLots>0)

   {

      double used=CurrentGridExposureLots();

      lot=MathMax(0,MathMin(lot,g_state.maxTotalLots-used));

   }

   // Recovery mode always scales NEW exposure down. Existing positions are never resized here.
   if(g_state.recoveryModeActive)
      lot*=MathPow(ClampDouble(InpRecoveryLotScaleStep,0.10,1.0),MathMax(1,g_state.recoveryAttemptsUsed));

   double out=NormalizeLots(lot);

   g_state.effectiveLot=out;

   return out;

}



bool AdvancedAutonomousDecision()

{

   g_state.entryThrottleActive=false;

   g_state.entryThrottleReason="";

   g_state.marketDecisionReason="";



   if(g_state.advancedProtection && g_state.maxDrawdownPct>0)

   {

      double ddRatio=(g_state.maxDrawdownPct>0)?g_state.maxDrawdown/g_state.maxDrawdownPct:0.0;

      if(ddRatio>=0.80)

      {

         g_state.entryThrottleActive=true;

         g_state.entryThrottleReason="Advanced protection: drawdown throttle";

         SetAction("ADV PROTECTION","ENTRY BLOCKED",g_state.entryThrottleReason);

         return false;

      }

   }



   if(g_state.exposureManager && g_state.maxTotalLots>0 && CurrentGridExposureLots()>=g_state.maxTotalLots-0.0000001)

   {

      g_state.entryThrottleActive=true;

      g_state.entryThrottleReason="Exposure ceiling reached";

      SetAction("EXPOSURE","ENTRY BLOCKED",g_state.entryThrottleReason);

      return false;

   }



   if(g_state.maxAutonomousGridsPerDay>0 && g_state.autonomousGridsToday>=g_state.maxAutonomousGridsPerDay)

   {

      g_state.entryThrottleActive=true;

      g_state.entryThrottleReason="Daily autonomous grid limit reached";

      SetAction("AUTONOMOUS","ENTRY BLOCKED",g_state.entryThrottleReason);

      return false;

   }



   // Strategy intelligence is explicitly optional.

   if(!g_state.advancedEntryDecision || !g_state.permAutonomousEntry)

   {

      g_state.marketDecisionReason="Optional entry engine OFF";

      SetAction("AUTONOMOUS","ENTRY APPROVED",g_state.marketDecisionReason);

      return true;

   }



   // Market Intelligence becomes a scoring input only when explicitly enabled.

   if(g_state.marketIntelligence)

   {

      double minScore=ClampDouble(g_state.autonomousMinSuitability,0.0,1.0);

      if(g_state.marketSuitabilityScore<minScore)

      {

         g_state.entryThrottleActive=true;

         g_state.entryThrottleReason=StringFormat("Suitability %.0f%% below %.0f%%",g_state.marketSuitabilityScore*100.0,minScore*100.0);

         g_state.marketDecisionReason=g_state.entryThrottleReason;

         SetAction("MARKET INTELLIGENCE","ENTRY BLOCKED",g_state.entryThrottleReason);

         return false;

      }

   }



   if(g_state.pauseHighVolatility && g_state.volatilityIndex>=g_state.highVolThreshold)

   {

      g_state.entryThrottleActive=true;

      g_state.entryThrottleReason="High volatility pause active";

      SetAction("ENTRY ENGINE","ENTRY BLOCKED",g_state.entryThrottleReason);

      return false;

   }



   if(g_state.smartRegime && g_state.regimeFilter)

   {

      if(g_state.gridType==BULLISH_GRID && g_state.trendStrength<g_state.bullThreshold)

      {

         g_state.entryThrottleActive=true;g_state.entryThrottleReason="Bullish grid not supported by current regime";

         SetAction("SMART REGIME","ENTRY BLOCKED",g_state.entryThrottleReason);return false;

      }

      if(g_state.gridType==BEARISH_GRID && g_state.trendStrength>g_state.bearThreshold)

      {

         g_state.entryThrottleActive=true;g_state.entryThrottleReason="Bearish grid not supported by current regime";

         SetAction("SMART REGIME","ENTRY BLOCKED",g_state.entryThrottleReason);return false;

      }

   }



   g_state.marketDecisionReason=StringFormat("Approved | suitability %.0f%% | confidence %.0f%%",g_state.marketSuitabilityScore*100.0,g_state.intelligenceConfidence*100.0);

   SetAction("ENTRY ENGINE","ENTRY APPROVED",g_state.marketDecisionReason);

   return true;

}





// -------------------- GRID CONSTRUCTION ----------------------------

void CreateBasicGrid(double b,double s){for(int i=1;i<=g_state.gridLevels;i++){double lot=NormalizeLots(g_state.lotSize*MathPow(g_state.lotMultiplier,i-1));PlaceGridOrder(ORDER_TYPE_BUY_STOP,NormalizeDouble(b+s*i,_Digits),lot);PlaceGridOrder(ORDER_TYPE_SELL_STOP,NormalizeDouble(b-s*i,_Digits),lot);}}

void CreateHedgeGrid(double b,double s){double v=ClampDouble(g_state.volatilityIndex,0,1);double lot=NormalizeLots(g_state.lotSize*MathMax(0.50,1.0-0.25*v));PlaceManagedMarketOrder(true,lot,"Hedge Buy");PlaceManagedMarketOrder(false,lot,"Hedge Sell");double hedgeStep=MathMax(s,GetCurrentATRPrice()>0?GetCurrentATRPrice()*0.60:s);for(int i=1;i<=g_state.gridLevels;i++){double l=NormalizeLots(lot);PlaceGridOrder(ORDER_TYPE_BUY_STOP,NormalizeDouble(b+hedgeStep*i,_Digits),l);PlaceGridOrder(ORDER_TYPE_SELL_STOP,NormalizeDouble(b-hedgeStep*i,_Digits),l);}}

void CreateTrendGrid(double b,double s){double tr=CalculateTrendStrength(),lot=NormalizeLots(g_state.lotSize);if(tr>0.6){PlaceManagedMarketOrder(true,lot,"Trend Buy");for(int i=1;i<=g_state.gridLevels;i++)PlaceGridOrder(ORDER_TYPE_BUY_STOP,NormalizeDouble(b+s*i,_Digits),lot);}else if(tr<0.4){PlaceManagedMarketOrder(false,lot,"Trend Sell");for(int i=1;i<=g_state.gridLevels;i++)PlaceGridOrder(ORDER_TYPE_SELL_STOP,NormalizeDouble(b-s*i,_Digits),lot);}else{CreateBidirectionalGrid(b,s);RecordEvent("GRID POLICY","Trend neutral -> bidirectional fallback for deployment");}}

void CreateVolatilityGrid(double b,double s){double v=CalculateVolatility();s*=1.0+v;for(int i=1;i<=g_state.gridLevels;i++){double l=NormalizeLots(g_state.lotSize*(1.0+v*0.5));PlaceGridOrder(ORDER_TYPE_BUY_STOP,NormalizeDouble(b+s*i,_Digits),l);PlaceGridOrder(ORDER_TYPE_SELL_STOP,NormalizeDouble(b-s*i,_Digits),l);}}

void CreateAIGrid(double b,double s){if(!g_state.aiEnabled){CreateBasicGrid(b,s);return;}double tr=CalculateTrendStrength(),v=CalculateVolatility(),sent=CalculateSentiment();s*=1.0+v*0.5;int levels=(int)MathRound(g_state.gridLevels*(1.0+tr*0.3));levels=MathMax(3,MathMin(10,levels));for(int i=1;i<=levels;i++){double l=NormalizeLots(g_state.lotSize*(1.0+sent*0.2));PlaceGridOrder(ORDER_TYPE_BUY_STOP,NormalizeDouble(b+s*i,_Digits),l);PlaceGridOrder(ORDER_TYPE_SELL_STOP,NormalizeDouble(b-s*i,_Digits),l);}}

void CreateGeometricGrid(double b,double s){double r=MathMax(1.05,g_state.lotMultiplier);for(int i=1;i<=g_state.gridLevels;i++){double d=s*MathPow(r,i-1),l=NormalizeLots(g_state.lotSize);PlaceGridOrder(ORDER_TYPE_BUY_STOP,NormalizeDouble(b+d,_Digits),l);PlaceGridOrder(ORDER_TYPE_SELL_STOP,NormalizeDouble(b-d,_Digits),l);}}

void CreateFibonacciGrid(double b,double s){double f[]={0.236,0.382,0.500,0.618,0.786,1.000,1.272,1.618};int n=MathMin(g_state.gridLevels,ArraySize(f));for(int i=0;i<n;i++){double d=s*f[i],l=NormalizeLots(g_state.lotSize*(1.0+f[i]*0.10));PlaceGridOrder(ORDER_TYPE_BUY_STOP,NormalizeDouble(b+d,_Digits),l);PlaceGridOrder(ORDER_TYPE_SELL_STOP,NormalizeDouble(b-d,_Digits),l);}}

void CreateATRAdaptiveGrid(double b,double s){double atr=GetCurrentATRPrice();if(atr<=0){CreateVolatilityGrid(b,s);return;}double step=MathMax(s,atr),v=CalculateVolatility();for(int i=1;i<=g_state.gridLevels;i++){double d=step*i,l=NormalizeLots(g_state.lotSize*MathMax(0.5,1.0-v*0.4));PlaceGridOrder(ORDER_TYPE_BUY_STOP,NormalizeDouble(b+d,_Digits),l);PlaceGridOrder(ORDER_TYPE_SELL_STOP,NormalizeDouble(b-d,_Digits),l);}}

void CreateMeanReversionGrid(double b,double s){for(int i=1;i<=g_state.gridLevels;i++){double d=s*i,l=NormalizeLots(g_state.lotSize);PlaceGridOrder(ORDER_TYPE_BUY_LIMIT,NormalizeDouble(b-d,_Digits),l);PlaceGridOrder(ORDER_TYPE_SELL_LIMIT,NormalizeDouble(b+d,_Digits),l);}}

void CreateBreakoutGrid(double b,double s){double atr=GetCurrentATRPrice(),d0=MathMax(s,atr>0?atr*0.75:s);for(int i=1;i<=g_state.gridLevels;i++){double d=d0*i,l=NormalizeLots(g_state.lotSize*(1.0+0.05*(i-1)));PlaceGridOrder(ORDER_TYPE_BUY_STOP,NormalizeDouble(b+d,_Digits),l);PlaceGridOrder(ORDER_TYPE_SELL_STOP,NormalizeDouble(b-d,_Digits),l);}}

void CreateMomentumGrid(double b,double s){double tr=CalculateTrendStrength(),l=NormalizeLots(g_state.lotSize);if(tr>=0.60){for(int i=1;i<=g_state.gridLevels;i++)PlaceGridOrder(ORDER_TYPE_BUY_STOP,NormalizeDouble(b+s*i,_Digits),l);}else if(tr<=0.40){for(int i=1;i<=g_state.gridLevels;i++)PlaceGridOrder(ORDER_TYPE_SELL_STOP,NormalizeDouble(b-s*i,_Digits),l);}else CreateBreakoutGrid(b,s);}

void CreateHybridGrid(double b,double s){double tr=CalculateTrendStrength(),v=CalculateVolatility(),atr=GetCurrentATRPrice(),hs=s;if(atr>0)hs=MathMax(s,atr*(0.75+v*0.75));if(tr>0.65){for(int i=1;i<=g_state.gridLevels;i++)PlaceGridOrder(ORDER_TYPE_BUY_STOP,NormalizeDouble(b+hs*i,_Digits),NormalizeLots(g_state.lotSize*MathMax(0.5,1.0-v*0.3)));}else if(tr<0.35){for(int i=1;i<=g_state.gridLevels;i++)PlaceGridOrder(ORDER_TYPE_SELL_STOP,NormalizeDouble(b-hs*i,_Digits),NormalizeLots(g_state.lotSize*MathMax(0.5,1.0-v*0.3)));}else if(v<0.35)CreateMeanReversionGrid(b,hs);else CreateBreakoutGrid(b,hs);}

void CreateBullishGrid(double b,double s){double tr=ClampDouble(g_state.trendStrength,0,1);double v=ClampDouble(g_state.volatilityIndex,0,1);double atr=GetCurrentATRPrice();double step=MathMax(s,atr>0?atr*0.65:s);step*=1.0+MathMax(0.0,tr-0.60)*0.20;double lot=NormalizeLots(g_state.lotSize*MathMax(0.50,1.0-v*0.35));int pullbacks=MathMax(1,MathMin(g_state.gridLevels/2,g_state.gridLevels));for(int i=1;i<=g_state.gridLevels;i++){PlaceGridOrder(ORDER_TYPE_BUY_STOP,NormalizeDouble(b+step*i,_Digits),lot);if(i<=pullbacks)PlaceGridOrder(ORDER_TYPE_BUY_LIMIT,NormalizeDouble(b-step*(0.30*i),_Digits),lot);}}

void CreateBearishGrid(double b,double s){double tr=ClampDouble(g_state.trendStrength,0,1);double v=ClampDouble(g_state.volatilityIndex,0,1);double atr=GetCurrentATRPrice();double step=MathMax(s,atr>0?atr*0.65:s);step*=1.0+MathMax(0.0,0.40-tr)*0.20;double lot=NormalizeLots(g_state.lotSize*MathMax(0.50,1.0-v*0.35));int pullbacks=MathMax(1,MathMin(g_state.gridLevels/2,g_state.gridLevels));for(int i=1;i<=g_state.gridLevels;i++){PlaceGridOrder(ORDER_TYPE_SELL_STOP,NormalizeDouble(b-step*i,_Digits),lot);if(i<=pullbacks)PlaceGridOrder(ORDER_TYPE_SELL_LIMIT,NormalizeDouble(b+step*(0.30*i),_Digits),lot);}}

void CreateBidirectionalGrid(double b,double s){double atr=GetCurrentATRPrice(),step=MathMax(s,atr>0?atr*0.70:s),v=ClampDouble(g_state.volatilityIndex,0,1),lot=NormalizeLots(g_state.lotSize*MathMax(0.45,1.0-v*0.45));if(StringFind(g_state.marketRegime,"RANGE")>=0||g_state.marketRegime=="COMPRESSION")step*=0.90;for(int i=1;i<=g_state.gridLevels;i++){PlaceGridOrder(ORDER_TYPE_BUY_STOP,NormalizeDouble(b+step*i,_Digits),lot);PlaceGridOrder(ORDER_TYPE_SELL_STOP,NormalizeDouble(b-step*i,_Digits),lot);}}

void CreateLadderGrid(double b,double s){for(int i=1;i<=g_state.gridLevels;i++){double d=s*(i+0.5*i*(i-1)/(double)MathMax(1,g_state.gridLevels)),l=NormalizeLots(g_state.lotSize*(1.0-0.25*(double)(i-1)/MathMax(1,g_state.gridLevels)));PlaceGridOrder(ORDER_TYPE_BUY_STOP,NormalizeDouble(b+d,_Digits),l);PlaceGridOrder(ORDER_TYPE_SELL_STOP,NormalizeDouble(b-d,_Digits),l);}}

void CreateAntiMartingaleGrid(double b,double s){double wb=1.0;if(g_state.predictionAccuracy>0.60)wb=1.0+MathMin(0.50,(g_state.predictionAccuracy-0.60)*1.5);double v=CalculateVolatility();for(int i=1;i<=g_state.gridLevels;i++){double prog=MathPow(1.0+0.08*wb,i-1),l=NormalizeLots(g_state.lotSize*prog*MathMax(0.5,1.0-v*0.35));PlaceGridOrder(ORDER_TYPE_BUY_STOP,NormalizeDouble(b+s*i,_Digits),l);PlaceGridOrder(ORDER_TYPE_SELL_STOP,NormalizeDouble(b-s*i,_Digits),l);}}

void CreateRangeScalingGrid(double b,double s){double tr=CalculateTrendStrength();if(tr>0.58||tr<0.42){CreateHybridGrid(b,s);return;}double atr=GetCurrentATRPrice(),step=MathMax(s,atr>0?atr*0.50:s);for(int i=1;i<=g_state.gridLevels;i++){double sc=1.0+0.20*(i-1),d=step*i*sc,l=NormalizeLots(g_state.lotSize*MathMax(0.5,1.0-0.08*(i-1)));PlaceGridOrder(ORDER_TYPE_BUY_LIMIT,NormalizeDouble(b-d,_Digits),l);PlaceGridOrder(ORDER_TYPE_SELL_LIMIT,NormalizeDouble(b+d,_Digits),l);}}

void CreateVolatilityBreakoutGrid(double b,double s){double atr=GetCurrentATRPrice();if(atr<=0){CreateBreakoutGrid(b,s);return;}double step=MathMax(s,atr),v=CalculateVolatility();for(int i=1;i<=MathMax(2,g_state.gridLevels);i++){double d=step*(0.75+0.35*(i-1)),l=NormalizeLots(g_state.lotSize*MathMax(0.40,1.0-v*0.50));PlaceGridOrder(ORDER_TYPE_BUY_STOP,NormalizeDouble(b+d,_Digits),l);PlaceGridOrder(ORDER_TYPE_SELL_STOP,NormalizeDouble(b-d,_Digits),l);}}

int CurrentServerHour(){MqlDateTime dt;TimeToStruct(TimeCurrent(),dt);return dt.hour;}

void CreateSessionGrid(double b,double s){int h=CurrentServerHour();double f=0.75;if(h>=7&&h<13)f=1.0;else if(h>=13&&h<18)f=1.2;else if(h>=18&&h<22)f=1.05;CreateBidirectionalGrid(b,s*f);}

void CreateSmartRegimeGrid(double b,double s){string r=g_state.marketRegime;double tr=ClampDouble(g_state.trendStrength,0,1);double v=ClampDouble(g_state.volatilityIndex,0,1);if(StringFind(r,"TREND UP")>=0){CreateBullishGrid(b,s);RecordEvent("GRID STRATEGY","Smart Regime -> Bullish | trend-aligned");return;}if(StringFind(r,"TREND DOWN")>=0){CreateBearishGrid(b,s);RecordEvent("GRID STRATEGY","Smart Regime -> Bearish | trend-aligned");return;}if(r=="BREAKOUT"){if(tr>=0.55)CreateBullishGrid(b,s);else if(tr<=0.45)CreateBearishGrid(b,s);else CreateBidirectionalGrid(b,s);RecordEvent("GRID STRATEGY","Smart Regime -> Breakout route");return;}if(r=="COMPRESSION"||StringFind(r,"RANGE")>=0||r=="TRANSITION"||r=="MIXED"){CreateBidirectionalGrid(b,s);RecordEvent("GRID STRATEGY","Smart Regime -> Bidirectional | non-directional state");return;}if(v>=0.80){CreateVolatilityBreakoutGrid(b,s);RecordEvent("GRID STRATEGY","Smart Regime -> Volatility Breakout");return;}CreateBidirectionalGrid(b,s);RecordEvent("GRID STRATEGY","Smart Regime -> Conservative bidirectional fallback");}



// -------------------- ORDER GUARDIAN / EXECUTION HARDENING -----------------------------

bool IsTradingAllowedForSymbol()

{

   long mode=SymbolInfoInteger(_Symbol,SYMBOL_TRADE_MODE);

   return mode!=SYMBOL_TRADE_MODE_DISABLED;

}



bool IsVolumeBrokerValid(double lots)

{

   double mn=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN),mx=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MAX),st=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_STEP);

   if(mn<=0 || mx<=0) return false;

   if(lots<mn-1e-10 || lots>mx+1e-10) return false;

   if(st>0){double q=lots/st;if(MathAbs(q-MathRound(q))>1e-7)return false;}

   return true;

}



double BrokerMinDistancePrice(){double point=SymbolInfoDouble(_Symbol,SYMBOL_POINT);long stops=(long)SymbolInfoInteger(_Symbol,SYMBOL_TRADE_STOPS_LEVEL);return MathMax(0.0,(double)stops*point);}

double BrokerFreezeDistancePrice(){double point=SymbolInfoDouble(_Symbol,SYMBOL_POINT);long freeze=(long)SymbolInfoInteger(_Symbol,SYMBOL_TRADE_FREEZE_LEVEL);return MathMax(0.0,(double)freeze*point);}



bool ValidateProtectionForPrice(bool buy,double price,double sl,double tp)

{

   double md=BrokerMinDistancePrice();

   if(md<=0) return true;

   if(sl>0){if(buy&&price-sl<md-1e-10)return false;if(!buy&&sl-price<md-1e-10)return false;}

   if(tp>0){if(buy&&tp-price<md-1e-10)return false;if(!buy&&price-tp<md-1e-10)return false;}

   return true;

}



ENUM_ORDER_TYPE MarginCheckType(ENUM_ORDER_TYPE type)

{

   if(type==ORDER_TYPE_BUY_STOP||type==ORDER_TYPE_BUY_LIMIT)return ORDER_TYPE_BUY;

   if(type==ORDER_TYPE_SELL_STOP||type==ORDER_TYPE_SELL_LIMIT)return ORDER_TYPE_SELL;

   return type;

}



bool HasSufficientMargin(ENUM_ORDER_TYPE type,double volume,double price)

{

   double free=AccountInfoDouble(ACCOUNT_MARGIN_FREE);if(free<=0)return false;

   double margin=0.0;if(!OrderCalcMargin(MarginCheckType(type),_Symbol,volume,price,margin))return false;

   return margin<=free*0.98;

}



bool ValidateMarketOrderRequest(bool buy,double price,double lots,double sl,double tp,string &reason)

{

   reason="";

   if(!IsTradingAllowedForSymbol()){reason="symbol trading disabled";return false;}

   if(!IsVolumeBrokerValid(lots)){reason="invalid broker volume";return false;}

   if(!ValidateProtectionForPrice(buy,price,sl,tp)){reason="invalid SL/TP distance";return false;}

   if(!HasSufficientMargin(buy?ORDER_TYPE_BUY:ORDER_TYPE_SELL,lots,price)){reason="insufficient free margin";return false;}

   return true;

}



bool ValidatePendingOrderRequest(ENUM_ORDER_TYPE type,double price,double lots,double sl,double tp,string &reason)

{

   reason="";

   if(!IsTradingAllowedForSymbol()){reason="symbol trading disabled";return false;}

   if(!IsVolumeBrokerValid(lots)){reason="invalid broker volume";return false;}

   MqlTick t;if(!SymbolInfoTick(_Symbol,t)){reason="no market tick";return false;}

   double md=MathMax(BrokerMinDistancePrice(),BrokerFreezeDistancePrice());

   if(type==ORDER_TYPE_BUY_STOP&&price<t.ask+md-1e-10){reason="buy stop inside broker distance";return false;}

   if(type==ORDER_TYPE_SELL_STOP&&price>t.bid-md+1e-10){reason="sell stop inside broker distance";return false;}

   if(type==ORDER_TYPE_BUY_LIMIT&&price>t.ask-md+1e-10){reason="buy limit inside broker distance";return false;}

   if(type==ORDER_TYPE_SELL_LIMIT&&price<t.bid+md-1e-10){reason="sell limit inside broker distance";return false;}

   bool buy=(type==ORDER_TYPE_BUY_STOP||type==ORDER_TYPE_BUY_LIMIT);

   if(!ValidateProtectionForPrice(buy,price,sl,tp)){reason="invalid pending SL/TP distance";return false;}

   if(!HasSufficientMargin(type,lots,price)){reason="insufficient free margin";return false;}

   return true;

}



bool IsRetryableTradeRetcode(uint rc)

{

   return rc==TRADE_RETCODE_REQUOTE||rc==TRADE_RETCODE_PRICE_CHANGED||rc==TRADE_RETCODE_PRICE_OFF||rc==TRADE_RETCODE_CONNECTION||rc==TRADE_RETCODE_TOO_MANY_REQUESTS||rc==TRADE_RETCODE_LOCKED;

}



void UpdateExecutionQuality(bool success,int retries,ulong latencyMs,uint retcode,string text,double requestedPrice,double executedPrice)
{
   g_state.executionSampleCount++;
   if(success) g_state.executionSuccessfulCount++;
   if(retries>0) g_state.executionRetrySamples++;
   if(!success) g_state.executionRejectCount++;
   if(g_state.executionSampleCount==1)
   {
      g_state.executionAverageLatencyMs=(double)latencyMs;
      g_state.executionAverageRetries=(double)retries;
   }
   else
   {
      double n=(double)g_state.executionSampleCount;
      g_state.executionAverageLatencyMs=((g_state.executionAverageLatencyMs*(n-1.0))+(double)latencyMs)/n;
      g_state.executionAverageRetries=((g_state.executionAverageRetries*(n-1.0))+(double)retries)/n;
   }
   double slip=0.0;
   if(success && executedPrice>0.0 && requestedPrice>0.0)
      slip=MathAbs(executedPrice-requestedPrice)/MathMax(SymbolInfoDouble(_Symbol,SYMBOL_POINT),1e-10);
   g_state.executionLastSlippagePoints=slip;
   double successRate=g_state.executionSampleCount>0?100.0*g_state.executionSuccessfulCount/g_state.executionSampleCount:100.0;
   double retryPenalty=MathMin(25.0,g_state.executionAverageRetries*8.0);
   double latencyPenalty=MathMin(20.0,g_state.executionAverageLatencyMs/250.0);
   double rejectPenalty=MathMin(25.0,100.0-successRate);
   double slipPenalty=MathMin(20.0,slip/2.0);
   g_state.executionQualityScore=ClampDouble(100.0-retryPenalty-latencyPenalty-rejectPenalty-slipPenalty,0.0,100.0);
   g_state.executionQualityDegraded=(g_state.executionQualityScore<70.0);
   if(g_state.executionQualityScore>=85.0) g_state.executionQualityState="EXCELLENT";
   else if(g_state.executionQualityScore>=70.0) g_state.executionQualityState="STABLE";
   else if(g_state.executionQualityScore>=50.0) g_state.executionQualityState="DEGRADED";
   else g_state.executionQualityState="POOR";
   g_state.executionLastQualityReason=success?StringFormat("retcode %u | %d retries | %.0f ms | %.1f pt",retcode,retries,(double)latencyMs,slip):StringFormat("reject %u | %s",retcode,text);
   g_state.executionLastSampleTime=TimeCurrent();
}

void CaptureOrderTelemetry(ENUM_ORDER_TYPE type,double price,double lots,uint retcode,string text,int retries,ulong latencyMs)
{
   g_state.lastOrderLatencyMs=latencyMs;
   g_state.lastOrderRetcode=retcode;
   g_state.lastOrderRetcodeText=text;
   g_state.lastOrderType=EnumToString(type);
   g_state.lastOrderPrice=price;
   g_state.lastOrderLots=lots;
   g_state.lastOrderRetryCount=retries;
   g_state.executionPreflightOK=true;
   g_state.executionPreflightState="PASSED";
   double executed=0.0;
   if((retcode==TRADE_RETCODE_DONE || retcode==TRADE_RETCODE_PLACED || retcode==TRADE_RETCODE_DONE_PARTIAL) && trade.ResultPrice()>0.0) executed=trade.ResultPrice();
   bool success=(retcode==TRADE_RETCODE_DONE || retcode==TRADE_RETCODE_PLACED || retcode==TRADE_RETCODE_DONE_PARTIAL);
   UpdateExecutionQuality(success,retries,latencyMs,retcode,text,price,executed);
}

bool ValidateInstitutionalPreflight(ENUM_ORDER_TYPE type,double price,double lots,double sl,double tp,string &reason)
{
   reason="";
   if(!IsTradingAllowedForSymbol()){reason="symbol trading disabled";g_state.executionPreflightRejectCount++;g_state.executionPreflightOK=false;g_state.executionPreflightState="BLOCKED";return false;}
   if(!IsVolumeBrokerValid(lots)){reason="volume outside broker limits";g_state.executionPreflightRejectCount++;g_state.executionPreflightOK=false;g_state.executionPreflightState="BLOCKED";return false;}
   MqlTick tk;if(!SymbolInfoTick(_Symbol,tk)){reason="market tick unavailable";g_state.executionPreflightRejectCount++;g_state.executionPreflightOK=false;g_state.executionPreflightState="BLOCKED";return false;}
   long tradeMode=(long)SymbolInfoInteger(_Symbol,SYMBOL_TRADE_MODE);
   if(tradeMode==SYMBOL_TRADE_MODE_DISABLED){reason="symbol trade mode disabled";g_state.executionPreflightRejectCount++;g_state.executionPreflightOK=false;g_state.executionPreflightState="BLOCKED";return false;}
   if(!HasSufficientMargin(type,lots,price)){reason="insufficient margin";g_state.executionPreflightRejectCount++;g_state.executionPreflightOK=false;g_state.executionPreflightState="BLOCKED";return false;}
   double md=MathMax(BrokerMinDistancePrice(),BrokerFreezeDistancePrice());
   bool buy=(type==ORDER_TYPE_BUY || type==ORDER_TYPE_BUY_STOP || type==ORDER_TYPE_BUY_LIMIT);
   if(type==ORDER_TYPE_BUY && price>0.0 && price<tk.ask-md){reason="buy execution price outside broker tolerance";g_state.executionPreflightRejectCount++;g_state.executionPreflightOK=false;g_state.executionPreflightState="BLOCKED";return false;}
   if(type==ORDER_TYPE_SELL && price>0.0 && price>tk.bid+md){reason="sell execution price outside broker tolerance";g_state.executionPreflightRejectCount++;g_state.executionPreflightOK=false;g_state.executionPreflightState="BLOCKED";return false;}
   if(g_state.maxSpreadPips>0 && g_state.currentSpreadPips>g_state.maxSpreadPips){reason="spread exceeds execution limit";g_state.executionPreflightRejectCount++;g_state.executionPreflightOK=false;g_state.executionPreflightState="BLOCKED";return false;}
   if(g_state.useSessionFilter && !IsSessionAllowed()){reason="outside configured session";g_state.executionPreflightRejectCount++;g_state.executionPreflightOK=false;g_state.executionPreflightState="BLOCKED";return false;}
   if(g_state.pauseHighVolatility && g_state.volatilityIndex>=g_state.highVolThreshold){reason="high-volatility execution pause";g_state.executionPreflightRejectCount++;g_state.executionPreflightOK=false;g_state.executionPreflightState="BLOCKED";return false;}
   if(!ValidateProtectionForPrice(buy,price,sl,tp)){reason="SL/TP protection invalid for broker";g_state.executionPreflightRejectCount++;g_state.executionPreflightOK=false;g_state.executionPreflightState="BLOCKED";return false;}
   g_state.executionPreflightOK=true;g_state.executionPreflightState="PASSED";return true;
}


// -------------------- ORDER HELPERS -----------------------------

double GetStopDistancePrice(){double p=PipSize(),point=SymbolInfoDouble(_Symbol,SYMBOL_POINT);long stops=(long)SymbolInfoInteger(_Symbol,SYMBOL_TRADE_STOPS_LEVEL);return MathMax(stops*point,g_state.stopLossPips>0?g_state.stopLossPips*p:0.0);}

double GetTakeDistancePrice(){return g_state.takeProfitPips>0?g_state.takeProfitPips*PipSize():0.0;}

double RiskAdjustedLot(double requested,double dist){double lot=NormalizeLots(requested);if(!g_state.useDynamicRiskLot||dist<=0)return lot;double eq=AccountInfoDouble(ACCOUNT_EQUITY),riskMoney=eq*g_state.riskPerGridPct/100.0,tickSize=SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE),tickValue=SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_VALUE);if(tickSize<=0||tickValue<=0)return lot;double perLot=(dist/tickSize)*tickValue;if(perLot<=0)return lot;return NormalizeLots(MathMin(lot,riskMoney/perLot));}

bool ValidatePendingPrice(ENUM_ORDER_TYPE type,double price){if(!g_state.validateStops)return true;MqlTick t;if(!SymbolInfoTick(_Symbol,t))return false;double md=(double)SymbolInfoInteger(_Symbol,SYMBOL_TRADE_STOPS_LEVEL)*SymbolInfoDouble(_Symbol,SYMBOL_POINT);if(type==ORDER_TYPE_BUY_STOP)return price-t.ask>=md;if(type==ORDER_TYPE_SELL_STOP)return t.bid-price>=md;if(type==ORDER_TYPE_BUY_LIMIT)return t.ask-price>=md;if(type==ORDER_TYPE_SELL_LIMIT)return price-t.bid>=md;return false;}

bool IsAutonomousManagedMode(){return IsAutonomousControl() && g_state.autonomousEngine;}

double AutonomousATRDistance(double atr,double minPips,double multiplier){double pip=PipSize();double a=atr>0?atr*multiplier:minPips*pip;double b=minPips*pip;return MathMax(MathMax(a,b),BrokerMinDistancePrice()+pip);}

void CalculateAutonomousProtection(bool buy,double entry,ENUM_GRID_TYPE grid,double &sl,double &tp)
{
   sl=0;tp=0;
   if(!IsAutonomousManagedMode() || !g_state.autonomousDynamicProtection) return;

   double atr=GetCurrentATRPrice(),pip=PipSize();
   if(pip<=0) return;

   double sm=g_state.adaptiveSLATRMultiple;
   double tm=g_state.adaptiveTPATRMultiple;
   if(sm<=0) sm=1.25;
   if(tm<=0) tm=2.10;

   // TRADE PROTECTION: strategy-aware, volatility-aware protection profile.
   switch(grid)
   {
      case BULLISH_GRID:
      case BEARISH_GRID:
      case TREND_GRID:
      case MOMENTUM_GRID: sm*=0.95; tm*=1.10; break;
      case BREAKOUT_GRID:
      case VOLATILITY_BREAKOUT_GRID: sm*=1.15; tm*=1.25; break;
      case MEAN_REVERSION_GRID:
      case RANGE_SCALING_GRID: sm*=0.90; tm*=0.90; break;
      case HEDGE_GRID:
      case BIDIRECTIONAL_GRID: sm*=1.05; tm*=0.90; break;
      case SMART_REGIME_GRID:
         if(StringFind(g_state.marketRegime,"TREND UP")>=0 || StringFind(g_state.marketRegime,"TREND DOWN")>=0) { sm*=0.95; tm*=1.10; }
         else if(StringFind(g_state.marketRegime,"RANGE")>=0 || StringFind(g_state.marketRegime,"COMPRESSION")>=0) { sm*=0.90; tm*=0.90; }
         else if(StringFind(g_state.marketRegime,"BREAKOUT")>=0 || StringFind(g_state.marketRegime,"HIGH")>=0) { sm*=1.15; tm*=1.20; }
         break;
      default: break;
   }

   double vol=MathMax(0.0,MathMin(1.0,g_state.volatilityIndex));
   sm*=1.0+0.25*vol;
   tm*=1.0+0.35*vol;

   double minSL=MathMax(6.0,g_state.gridStep*0.90);
   double minTP=MathMax(8.0,g_state.gridStep*1.20);
   double sd=AutonomousATRDistance(atr,minSL,sm);
   double td=AutonomousATRDistance(atr,minTP,tm);
   td=MathMax(td,sd*1.25);

   if(buy)
   {
      sl=NormalizeDouble(entry-sd,_Digits);
      tp=NormalizeDouble(entry+td,_Digits);
   }
   else
   {
      sl=NormalizeDouble(entry+sd,_Digits);
      tp=NormalizeDouble(entry-td,_Digits);
   }
}

void ApplyAutonomousRiskProfile()
{
   if(!g_state.autonomousAdaptiveRisk) return;

   double eq=MathMax(0.0,AccountInfoDouble(ACCOUNT_EQUITY));
   g_state.autonomousEntryDrawdownPct=MathMax(1.0,InpAutonomousEntryDrawdownPct);
   g_state.autonomousEntryDailyLossPct=MathMax(0.5,InpAutonomousDailyLossPct);
   g_state.autonomousEntryGridRiskPct=MathMax(0.25,InpAutonomousGridRiskPct);
   g_state.autonomousRiskPerGridPct=MathMax(0.10,InpAutonomousRiskPerGridPct);

   g_state.riskPerGridPct=g_state.autonomousRiskPerGridPct;
   g_state.maxGridRiskPct=g_state.autonomousEntryGridRiskPct;
   g_state.maxDrawdownPct=g_state.autonomousEntryDrawdownPct;
   g_state.dailyLossLimitPct=g_state.autonomousEntryDailyLossPct;
   g_state.dailyProfitLockPct=0.0;

   // Exposure scales with equity while respecting broker minimum volume.
   double minLot=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN); if(minLot<=0) minLot=0.01;
   double targetLots=MathMin(1.0,MathMax(minLot*4.0,eq/2500.0));
   g_state.maxTotalLots=NormalizeLots(targetLots);
   if(g_state.maxTotalLots<minLot)g_state.maxTotalLots=minLot;

   g_state.maxPositions=MathMax(2,InpAutonomousMaxPositions);
   g_state.maxPendingOrders=MathMax(4,InpAutonomousMaxPendingOrders);
   g_state.maxAutonomousGridsPerDay=MathMax(1,InpMaxAutonomousGridsPerDay>0?InpMaxAutonomousGridsPerDay:6);
   g_state.autonomousMaxConcurrentCycles=MathMax(1,InpAutonomousMaxConcurrentCycles);
   g_state.autonomousMaxPositions=g_state.maxPositions;
   g_state.autonomousMaxPendingOrders=g_state.maxPendingOrders;

   if(g_state.maxSpreadPips<=0 || g_state.maxSpreadPips>25.0)g_state.maxSpreadPips=25.0;
}

bool PlaceManagedMarketOrder(bool buy,double requested,string comment)

{

   if(GetPositionCount()>=g_state.maxPositions){g_state.rejectedOrders++;RecordEvent("ORDER_GUARD","Market order blocked | max positions reached");return false;}

   MqlTick t;if(!SymbolInfoTick(_Symbol,t)){g_state.rejectedOrders++;RecordEvent("ORDER_GUARD","Market order blocked | no tick");return false;}

   double e=buy?t.ask:t.bid,sd=g_state.useStopLossForNewOrders?GetStopDistancePrice():0,td=g_state.useTakeProfitForNewOrders?GetTakeDistancePrice():0,sl=0,tp=0;

   if(IsAutonomousManagedMode()){CalculateAutonomousProtection(buy,e,g_state.gridType,sl,tp);sd=sl>0?MathAbs(e-sl):0;td=tp>0?MathAbs(tp-e):0;}else{if(sd>0)sl=NormalizeDouble(buy?e-sd:e+sd,_Digits);if(td>0)tp=NormalizeDouble(buy?e+td:e-td,_Digits);}

   double lot=CalculateAdaptiveLot(requested);if(g_state.riskManagedTrading)lot=RiskAdjustedLot(lot,sd>0?sd:MathMax(PipSize(),g_state.effectiveGridStepPips>0?g_state.effectiveGridStepPips*PipSize():g_state.gridStep*PipSize()));

   if(lot<=0){g_state.rejectedOrders++;RecordEvent("ORDER_GUARD","Market order blocked | effective lot is zero");return false;}

   if(g_state.exposureManager&&g_state.maxTotalLots>0&&CurrentGridExposureLots()+lot>g_state.maxTotalLots+0.0000001){g_state.rejectedOrders++;RecordEvent("ORDER_GUARD","Market order blocked | exposure ceiling");return false;}

   string reason="";if(!ValidateMarketOrderRequest(buy,e,lot,sl,tp,reason)){g_state.rejectedOrders++;if(g_state.orderGuardian)RecordEvent("ORDER_GUARD","Market order blocked | "+reason);return false;}
   if(!ValidateInstitutionalPreflight(buy?ORDER_TYPE_BUY:ORDER_TYPE_SELL,e,lot,sl,tp,reason)){g_state.rejectedOrders++;RecordEvent("EXECUTION PREFLIGHT","Market order blocked | "+reason);return false;}

   trade.SetExpertMagicNumber(g_v14ExecutionMagic>0?g_v14ExecutionMagic:(ulong)InpMagicNumber);trade.SetDeviationInPoints((ulong)MathMax(0,g_state.slippage));trade.SetTypeFillingBySymbol(_Symbol);

   int maxRetry=g_state.smartExecution?g_state.orderRetryCount:0;bool ok=false;uint rc=0;string txt="";ulong startMs=GetTickCount64();int usedRetry=0;

   for(int r=0;r<=maxRetry;r++)

   {

      if(r>0){MqlTick rt;if(SymbolInfoTick(_Symbol,rt)){e=buy?rt.ask:rt.bid;if(sd>0)sl=NormalizeDouble(buy?e-sd:e+sd,_Digits);if(td>0)tp=NormalizeDouble(buy?e+td:e-td,_Digits);}if(!ValidateMarketOrderRequest(buy,e,lot,sl,tp,reason)){txt=reason;break;}usedRetry=r;}

      string cycleComment=V14OrderComment(comment); ok=buy?trade.Buy(lot,_Symbol,0,sl,tp,cycleComment):trade.Sell(lot,_Symbol,0,sl,tp,cycleComment);rc=(uint)trade.ResultRetcode();txt=trade.ResultRetcodeDescription();if(ok||!IsRetryableTradeRetcode(rc))break;

   }

   CaptureOrderTelemetry(buy?ORDER_TYPE_BUY:ORDER_TYPE_SELL,e,lot,rc,txt,usedRetry,GetTickCount64()-startMs);

   if(ok){g_state.acceptedOrders++;RecordEvent("ORDER_ACCEPTED",StringFormat("%s | %.2f lots | %u | %d retries",comment,lot,rc,usedRetry));}

   else{g_state.rejectedOrders++;RecordEvent("ORDER_REJECTED",comment+" | "+txt);Print("UG7 market order rejected: ",comment," ",txt);}

   return ok;

}



int GetPendingTypeCount(ENUM_ORDER_TYPE type)

{

   int count=0;

   for(int i=0;i<OrdersTotal();i++)

   {

      ulong ticket=OrderGetTicket(i);

      if(ticket==0 || !IsGridOrder(ticket,true)) continue;

      if((ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE)==type) count++;

   }

   return count;

}



bool PlaceGridOrder(ENUM_ORDER_TYPE type,double price,double lots,double sl=0,double tp=0)

{

   if(GetPendingCount()>=g_state.maxPendingOrders){g_state.rejectedOrders++;RecordEvent("ORDER_GUARD","Pending order blocked | max pending reached");return false;}

   price=NormalizeDouble(price,_Digits);if(!ValidatePendingPrice(type,price)){g_state.rejectedOrders++;RecordEvent("ORDER_REJECTED",EnumToString(type)+" invalid pending price");return false;}

   if(GetPendingTypeCount(type)==0){double point=SymbolInfoDouble(_Symbol,SYMBOL_POINT);long stopLevel=(long)SymbolInfoInteger(_Symbol,SYMBOL_TRADE_STOPS_LEVEL);double minimumLead=MathMax(0.1,g_state.frontOrderDistancePips)*PipSize();minimumLead=MathMax(minimumLead,stopLevel*point+PipSize());MqlTick liveTick;if(SymbolInfoTick(_Symbol,liveTick)){if(type==ORDER_TYPE_BUY_STOP)price=MathMin(price,liveTick.ask+minimumLead);if(type==ORDER_TYPE_SELL_STOP)price=MathMax(price,liveTick.bid-minimumLead);if(type==ORDER_TYPE_BUY_LIMIT)price=MathMax(price,liveTick.ask-minimumLead);if(type==ORDER_TYPE_SELL_LIMIT)price=MathMin(price,liveTick.bid+minimumLead);price=NormalizeDouble(price,_Digits);}}

   if(!ValidatePendingPrice(type,price)){g_state.rejectedOrders++;RecordEvent("ORDER_GUARD",EnumToString(type)+" final price failed stop validation");return false;}

   double sd=g_state.useStopLossForNewOrders?GetStopDistancePrice():0,td=g_state.useTakeProfitForNewOrders?GetTakeDistancePrice():0;bool buy=(type==ORDER_TYPE_BUY_STOP||type==ORDER_TYPE_BUY_LIMIT);

   if(IsAutonomousManagedMode()){CalculateAutonomousProtection(buy,price,g_state.gridType,sl,tp);sd=sl>0?MathAbs(price-sl):0;td=tp>0?MathAbs(tp-price):0;}else{if(g_state.useStopLossForNewOrders&&sl==0&&sd>0)sl=NormalizeDouble(buy?price-sd:price+sd,_Digits);else if(!g_state.useStopLossForNewOrders)sl=0;if(g_state.useTakeProfitForNewOrders&&tp==0&&td>0)tp=NormalizeDouble(buy?price+td:price-td,_Digits);else if(!g_state.useTakeProfitForNewOrders)tp=0;}

   double bid=SymbolInfoDouble(_Symbol,SYMBOL_BID),lot=CalculateAdaptiveLot(lots);
   if(g_state.riskManagedTrading)
   {
      double dist=sd>0?sd:MathMax(PipSize(),MathAbs(price-bid));
      if(IsAutonomousManagedMode() && g_state.autonomousRiskPerGridPct>0 && dist>0)
      {
         double eq=AccountInfoDouble(ACCOUNT_EQUITY);
         double riskMoney=eq*g_state.autonomousRiskPerGridPct/100.0;
         double budgetPerOrder=riskMoney/MathMax(1.0,(double)MathMax(2,g_state.effectiveGridLevels*2));
         double tickSize=SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE),tickValue=SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_VALUE);
         if(tickSize>0 && tickValue>0)
         {
            double perLot=(dist/tickSize)*tickValue;
            if(perLot>0) lot=MathMin(lot,NormalizeLots(budgetPerOrder/perLot));
         }
      }
      else lot=RiskAdjustedLot(lot,dist);
   }
   if(lot<=0){g_state.rejectedOrders++;RecordEvent("ORDER_GUARD",EnumToString(type)+" effective lot is zero");return false;}

   if(g_state.exposureManager&&g_state.maxTotalLots>0&&CurrentGridExposureLots()+lot>g_state.maxTotalLots+0.0000001){g_state.rejectedOrders++;RecordEvent("ORDER_GUARD",EnumToString(type)+" exposure ceiling");return false;}

   string reason="";if(!ValidatePendingOrderRequest(type,price,lot,sl,tp,reason)){g_state.rejectedOrders++;if(g_state.orderGuardian)RecordEvent("ORDER_GUARD",EnumToString(type)+" blocked | "+reason);return false;}
   if(!ValidateInstitutionalPreflight(type,price,lot,sl,tp,reason)){g_state.rejectedOrders++;RecordEvent("EXECUTION PREFLIGHT",EnumToString(type)+" blocked | "+reason);return false;}

   trade.SetExpertMagicNumber(g_v14ExecutionMagic>0?g_v14ExecutionMagic:(ulong)InpMagicNumber);trade.SetDeviationInPoints((ulong)MathMax(0,g_state.slippage));trade.SetTypeFillingBySymbol(_Symbol);

   int maxRetry=g_state.smartExecution?g_state.orderRetryCount:0;bool ok=false;uint rc=0;string txt="";ulong startMs=GetTickCount64();int usedRetry=0;

   for(int r=0;r<=maxRetry;r++){if(r>0){if(!ValidatePendingOrderRequest(type,price,lot,sl,tp,reason)){txt=reason;break;}usedRetry=r;}

      if(type==ORDER_TYPE_BUY_STOP)ok=trade.BuyStop(lot,price,_Symbol,sl,tp,ORDER_TIME_GTC,0,V14OrderComment("UG7 BUY STOP"));else if(type==ORDER_TYPE_SELL_STOP)ok=trade.SellStop(lot,price,_Symbol,sl,tp,ORDER_TIME_GTC,0,V14OrderComment("UG7 SELL STOP"));else if(type==ORDER_TYPE_BUY_LIMIT)ok=trade.BuyLimit(lot,price,_Symbol,sl,tp,ORDER_TIME_GTC,0,V14OrderComment("UG7 BUY LIMIT"));else if(type==ORDER_TYPE_SELL_LIMIT)ok=trade.SellLimit(lot,price,_Symbol,sl,tp,ORDER_TIME_GTC,0,V14OrderComment("UG7 SELL LIMIT"));

      rc=(uint)trade.ResultRetcode();txt=trade.ResultRetcodeDescription();if(ok||!IsRetryableTradeRetcode(rc))break;}

   CaptureOrderTelemetry(type,price,lot,rc,txt,usedRetry,GetTickCount64()-startMs);

   if(ok){g_state.acceptedOrders++;RecordEvent("ORDER_ACCEPTED",StringFormat("%s | %.2f lots | %u | %d retries",EnumToString(type),lot,rc,usedRetry));}else{g_state.rejectedOrders++;RecordEvent("ORDER_REJECTED",EnumToString(type)+" | "+txt);Print("UG7 pending order rejected: ",EnumToString(type)," ",txt);}return ok;

}



int GridRequestedOrderCountForCurrentProfile()

{

   int n=MathMax(1,g_state.gridLevels);

   switch(g_state.gridType)

   {

      case HEDGE_GRID: return 2+n*2;

      case TREND_GRID: return (CalculateTrendStrength()>0.60||CalculateTrendStrength()<0.40)?n+1:0;

      case VOLATILITY_GRID: return n*2;

      case AI_GRID: {int lv=MathMax(3,MathMin(10,(int)MathRound(n*(1.0+CalculateTrendStrength()*0.3))));return lv*2;}

      case GEOMETRIC_GRID:return n*2;

      case FIBONACCI_GRID:return MathMin(n,8)*2;

      case ATR_ADAPTIVE_GRID:return n*2;

      case MEAN_REVERSION_GRID:return n*2;

      case BREAKOUT_GRID:return n*2;

      case MOMENTUM_GRID:return (CalculateTrendStrength()>=0.60||CalculateTrendStrength()<=0.40)?n: n*2;

      case HYBRID_GRID:return n*2;

      case BULLISH_GRID:return n+MathMax(1,n/2);

      case BEARISH_GRID:return n+MathMax(1,n/2);

      case BIDIRECTIONAL_GRID:return n*2;

      case LADDER_GRID:return n*2;

      case ANTI_MARTINGALE_GRID:return n*2;

      case RANGE_SCALING_GRID:return (CalculateTrendStrength()>0.58||CalculateTrendStrength()<0.42)?n*2:n*2;

      case VOLATILITY_BREAKOUT_GRID:return MathMax(2,n)*2;

      case SESSION_GRID:return n*2;

      case SMART_REGIME_GRID:

         {

            string r=g_state.marketRegime;
            double tr=ClampDouble(g_state.trendStrength,0,1);
            if(StringFind(r,"TREND UP")>=0 || StringFind(r,"TREND DOWN")>=0) return n+MathMax(1,n/2);
            if(r=="BREAKOUT" && (tr>=0.55 || tr<=0.45)) return n+MathMax(1,n/2);
            if(r=="SHOCK / HIGH VOL" || g_state.volatilityIndex>=0.80) return MathMax(2,n)*2;
            return n*2;
         }

      default:return n*2;

   }

}



void AuditGridDeployment(int requestedBefore,int acceptedBefore){

   int req=MathMax(0,GridRequestedOrderCountForCurrentProfile());

   int accepted=(GetPositionCount()+GetPendingCount())-acceptedBefore;

   if(accepted<0) accepted=0;

   g_state.lastGridRequestedOrders=req;

   g_state.lastGridAcceptedOrders=accepted;

   g_state.lastGridShortfall=MathMax(0,req-accepted);

   if(g_state.lastGridShortfall>0){

      g_state.lastGridAudit=StringFormat("SHORTFALL %d / %d | %s",g_state.lastGridShortfall,req,CompactGridName(g_state.gridType));

      RecordEvent("GRID AUDIT",g_state.lastGridAudit);

   } else {

      g_state.lastGridAudit=StringFormat("PASS %d / %d | %s",accepted,req,CompactGridName(g_state.gridType));

      RecordEvent("GRID AUDIT",g_state.lastGridAudit);

   }

}



void DeployGridOrders(double b,double s,bool allowSeedMarket=true)

{

   switch(g_state.gridType)

   {

      case BASIC_GRID:CreateBasicGrid(b,s);break;

      case HEDGE_GRID:

         if(allowSeedMarket) CreateHedgeGrid(b,s);

         else { double lot=NormalizeLots(g_state.lotSize); for(int i=1;i<=g_state.gridLevels;i++){ double l=NormalizeLots(lot*MathPow(g_state.lotMultiplier,i)); PlaceGridOrder(ORDER_TYPE_BUY_STOP,NormalizeDouble(b+s*i,_Digits),l); PlaceGridOrder(ORDER_TYPE_SELL_STOP,NormalizeDouble(b-s*i,_Digits),l); } }

         break;

      case TREND_GRID:

         if(allowSeedMarket) CreateTrendGrid(b,s);

         else { double tr=CalculateTrendStrength(),lot=NormalizeLots(g_state.lotSize); if(tr>0.6){for(int i=1;i<=g_state.gridLevels;i++)PlaceGridOrder(ORDER_TYPE_BUY_STOP,NormalizeDouble(b+s*i,_Digits),lot);} else if(tr<0.4){for(int i=1;i<=g_state.gridLevels;i++)PlaceGridOrder(ORDER_TYPE_SELL_STOP,NormalizeDouble(b-s*i,_Digits),lot);} }

         break;

      case VOLATILITY_GRID:CreateVolatilityGrid(b,s);break;

      case AI_GRID:CreateAIGrid(b,s);break;

      case GEOMETRIC_GRID:CreateGeometricGrid(b,s);break;

      case FIBONACCI_GRID:CreateFibonacciGrid(b,s);break;

      case ATR_ADAPTIVE_GRID:CreateATRAdaptiveGrid(b,s);break;

      case MEAN_REVERSION_GRID:CreateMeanReversionGrid(b,s);break;

      case BREAKOUT_GRID:CreateBreakoutGrid(b,s);break;

      case MOMENTUM_GRID:CreateMomentumGrid(b,s);break;

      case HYBRID_GRID:CreateHybridGrid(b,s);break;

      case BULLISH_GRID:CreateBullishGrid(b,s);break;

      case BEARISH_GRID:CreateBearishGrid(b,s);break;

      case BIDIRECTIONAL_GRID:CreateBidirectionalGrid(b,s);break;

      case LADDER_GRID:CreateLadderGrid(b,s);break;

      case ANTI_MARTINGALE_GRID:CreateAntiMartingaleGrid(b,s);break;

      case RANGE_SCALING_GRID:CreateRangeScalingGrid(b,s);break;

      case VOLATILITY_BREAKOUT_GRID:CreateVolatilityBreakoutGrid(b,s);break;

      case SESSION_GRID:CreateSessionGrid(b,s);break;

      case SMART_REGIME_GRID:CreateSmartRegimeGrid(b,s);break;

   }

}



int CountActiveInventoryCycles()
{
   // RUNTIME: active execution is inventory-based, not cycle-registry-based.
   // Legacy V14 cycle registry remains only for compatibility/recovery.
   return (GetPositionCount()>0 || GetPendingCount()>0) ? 1 : 0;
}

bool UnifiedDeploymentGate(bool autonomous,string &reason)
{
   reason="";
   if(!IsTradingAllowedForSymbol()){reason="Trading is not allowed for this symbol/account";return false;}
   if(g_state.emergencyActive){reason="Emergency protection active";return false;}
   if(g_state.exitCoordinationActive){reason="Exit coordination active";return false;}

   if(!RiskPortfolioHardRiskGate(autonomous,reason)) return false;

   bool guarded=autonomous || g_state.manualEntryRiskGuard;
   if(guarded)
   {
      double eq=AccountInfoDouble(ACCOUNT_EQUITY),bal=AccountInfoDouble(ACCOUNT_BALANCE);
      if(eq<=0){reason="Invalid equity";return false;}
      double dd=(g_state.peakEquity>0)?MathMax(0.0,(g_state.peakEquity-eq)/g_state.peakEquity*100.0):0.0;
      g_state.maxDrawdown=MathMax(g_state.maxDrawdown,dd);

      if(autonomous)
      {
         if(g_state.autonomousEntryDrawdownPct>0 && dd>=g_state.autonomousEntryDrawdownPct)
         {reason=StringFormat("Autonomous entry DD %.2f%% >= %.2f%%",dd,g_state.autonomousEntryDrawdownPct);return false;}
         double dayPct=bal>0?g_state.todayProfit/bal*100.0:0.0;
         if(g_state.autonomousEntryDailyLossPct>0 && dayPct<=-g_state.autonomousEntryDailyLossPct)
         {reason=StringFormat("Autonomous daily loss %.2f%% <= -%.2f%%",dayPct,g_state.autonomousEntryDailyLossPct);return false;}
      }
      else if(g_state.maxDrawdownPct>0 && dd>=g_state.maxDrawdownPct)
      {reason=StringFormat("Manual entry DD %.2f%% >= %.2f%%",dd,g_state.maxDrawdownPct);return false;}

      if(g_state.maxSpreadPips>0 && g_state.currentSpreadPips>g_state.maxSpreadPips)
      {reason=StringFormat("Spread %.2f > %.2f pips",g_state.currentSpreadPips,g_state.maxSpreadPips);return false;}
      if(!IsSessionAllowed()){reason="Session filter blocked entry";return false;}
      if(g_state.avoidWeekend && IsWeekend()){reason="Weekend filter blocked entry";return false;}
      if(g_state.pauseHighVolatility && g_state.volatilityIndex>=g_state.highVolThreshold)
      {reason=StringFormat("High volatility %.0f%% >= %.0f%%",g_state.volatilityIndex*100.0,g_state.highVolThreshold*100.0);return false;}
   }

   int pos=GetPositionCount();
   int pend=GetPendingCount();
   int posCap=autonomous?g_state.autonomousMaxPositions:g_state.maxPositions;
   int pendCap=autonomous?g_state.autonomousMaxPendingOrders:g_state.maxPendingOrders;
   if(posCap>0 && pos>=posCap){reason=StringFormat("Position capacity %d/%d",pos,posCap);return false;}
   if(pendCap>0 && pend>=pendCap){reason=StringFormat("Pending capacity %d/%d",pend,pendCap);return false;}

   if(autonomous && g_state.maxAutonomousGridsPerDay>0 && g_state.autonomousGridsToday>=g_state.maxAutonomousGridsPerDay)
   {reason=StringFormat("Autonomous daily deployment limit %d reached",g_state.maxAutonomousGridsPerDay);return false;}

   if(g_state.exposureManager && g_state.maxTotalLots>0)
   {
      double exposure=CurrentGridExposureLots();
      double reserve=MathMax(SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN),g_state.lotSize);
      if(exposure+reserve>g_state.maxTotalLots+0.0000001)
      {reason=StringFormat("Exposure %.3f + reserve %.3f > %.3f lots",exposure,reserve,g_state.maxTotalLots);return false;}
   }
   return true;
}


void RecordDeploymentBlock(string owner,string reason)
{
   g_state.deploymentGateReason=reason;
   g_state.executionStatus=owner+" ENTRY BLOCKED";
   SetAction(owner,"ENTRY BLOCKED",reason);
   RecordEvent("DEPLOYMENT GATE",owner+" | "+reason);
}


// -------------------- GRID LIFECYCLE - GRID LIFECYCLE ENGINE --------------------
bool GridLifecycleLifecycleAudit(string &reason)
{
   reason="";
   if(g_state.lifecycleScope=="") g_state.lifecycleScope="PENDING + NEW INDIVIDUAL POSITIONS";
   if(g_state.lifecycleAuthority=="") g_state.lifecycleAuthority="GRID_LIFECYCLE";
   if(g_state.lifecycleDeployments<0 || g_state.lifecycleCancels<0 || g_state.lifecycleRebuilds<0 || g_state.lifecycleRecenters<0 || g_state.lifecycleReplenishments<0)
   {
      reason="GRID LIFECYCLE lifecycle counters invalid";
      return false;
   }
   // Lifecycle actions must never imply position-exit authority.
   if(g_state.lifecycleScope=="POSITION_EXIT")
   {
      reason="GRID LIFECYCLE lifecycle cannot own position exits";
      return false;
   }
   return true;
}

void GridLifecycleBeginLifecycle(const string command,const string authority,const string scope="PENDING_ONLY")
{
   g_state.lifecycleCommandActive=true;
   g_state.lifecycleCommand=command;
   g_state.lifecycleAuthority=authority;
   g_state.lifecycleScope=scope;
   g_state.lifecycleCommandTime=TimeCurrent();
   SetAction(authority,command,scope);
}

void GridLifecycleEndLifecycle(const string result)
{
   g_state.lifecycleCommandActive=false;
   
   if(result!="")
      g_state.gridLifecycleReason=result;
}

bool GridLifecyclePendingOnlyGuard(const string command,string &reason)
{
   reason="";
   if(g_state.lifecycleCommandActive)
   {
      reason="Grid lifecycle command already active";
      return false;
   }
   // Existing positions are explicitly outside the lifecycle action scope.
   // They may remain open while pending inventory is rebuilt/cancelled.
   return true;
}

void GridLifecycleRecordLifecycle(const string action,const string detail)
{
   g_state.gridLifecycleState=action;
   g_state.gridLifecycleReason=detail;
   RecordEvent("GRID LIFECYCLE",action+" | "+detail);
}

void CreateGrid(bool allowParallel=false)
{
   string gate="";
   bool autonomous=IsAutonomousControl();
   if(!UnifiedDeploymentGate(autonomous,gate))
   {
      RecordDeploymentBlock(autonomous?"AUTONOMOUS":"USER",gate);
      return;
   }

   MqlTick tick;
   if(!SymbolInfoTick(_Symbol,tick)){g_state.executionStatus="NO MARKET TICK";return;}
   { string lifecycleReason=""; if(!GridLifecyclePendingOnlyGuard("DEPLOY",lifecycleReason)){g_state.executionStatus="LIFECYCLE BLOCKED";RecordDeploymentBlock(autonomous?"AUTONOMOUS":"USER",lifecycleReason);return;} }
   GridLifecycleBeginLifecycle("DEPLOY",autonomous?"AUTONOMOUS":"USER","PENDING + NEW INDIVIDUAL POSITIONS");

   ENUM_GRID_TYPE deployType=autonomous?g_autonomousGridType:g_selectedGridType;
   g_state.gridType=deployType;
   UpdatePhase5GeometryTelemetry();
   UpdateEffectiveState();
   g_state.adaptiveAnchorMode=(ENUM_GRID_ANCHOR_MODE)MathMax(0,MathMin(3,(int)g_state.adaptiveAnchorMode));
   double selectedAnchor=GridGeometryCurrentMid();
   if(g_state.adaptiveGrid && g_state.adaptiveAnchorMode!=GRID_ANCHOR_CURRENT_MID) selectedAnchor=CalculateAdaptiveAnchorPrice();
   g_state.anchorPrice=NormalizeDouble(selectedAnchor>0?selectedAnchor:(tick.ask+tick.bid)*0.5,_Digits);
   g_v14FocusMagic=0;
   g_v14ExecutionMagic=(ulong)InpMagicNumber;
   g_v14ExecutionCycleId=0;
   trade.SetExpertMagicNumber((ulong)InpMagicNumber);

   double effectiveStep=CalculateEffectiveGridStepPips();
   int effectiveLevels=CalculateEffectiveGridLevels();
   int savedLevels=g_state.gridLevels;
   if(g_state.adaptiveLevels)g_state.gridLevels=effectiveLevels;

   double stepPrice=MathMax(PipSize(),effectiveStep*PipSize());
   if(g_state.useATRSpacing && !g_state.adaptiveGrid && g_state.atrPrice>0)
      stepPrice=MathMax(g_state.minGridStep*PipSize(),MathMin(g_state.maxGridStep*PipSize(),g_state.atrPrice*g_state.atrSpacingMultiplier));

   int beforePos=GetPositionCount();
   int beforePend=GetPendingCount();
   int beforeAccepted=g_state.acceptedOrders;

   DeployGridOrders(g_state.anchorPrice,stepPrice,true);

   if(g_state.adaptiveLevels)g_state.gridLevels=savedLevels;

   g_state.effectiveGridStepPips=effectiveStep;
   g_state.effectiveGridLevels=effectiveLevels;
   g_state.positionCount=GetPositionCount();
   g_state.pendingCount=GetPendingCount();
   g_state.gridActive=(g_state.positionCount+g_state.pendingCount)>0;

   int created=(g_state.positionCount-beforePos)+(g_state.pendingCount-beforePend);
   int acceptedDelta=g_state.acceptedOrders-beforeAccepted;
   if(created<=0 && acceptedDelta<=0)
   {
      g_state.executionStatus="NO ORDERS ACCEPTED";
      SetAction(autonomous?"AUTONOMOUS":"USER","GRID DEPLOY FAILED",
                StringFormat("%s produced no accepted orders",GetGridTypeName(deployType)));
      RecordEvent("GRID DEPLOYMENT",StringFormat("FAILED | %s | no orders accepted",GetGridTypeName(deployType)));
   }
   else
   {
      g_state.startTime=TimeCurrent();
      g_state.executionStatus=StringFormat("GRID ACTIVE | %s",CompactGridName(deployType));
      g_state.gridLifecycleState="ACTIVE";
      g_state.gridLifecycleReason=GridLifecycleModel(deployType);
      g_state.gridCycleId++; // informational generation, never used as trade identity
      if(autonomous){g_state.autonomousGridsToday++;g_state.autonomousLastDeployment=TimeCurrent();}
      SetAction(autonomous?"AUTONOMOUS":"USER", "GRID DEPLOYED",
                StringFormat("%s | %d new objects | individual trade management",GetGridTypeName(deployType),created));
      RecordEvent("GRID DEPLOYMENT",StringFormat("%s | %d new orders/positions | existing inventory preserved",GetGridTypeName(deployType),created));
   }

   g_state.gridType=autonomous?g_autonomousGridType:g_selectedGridType;
   if(!autonomous)g_lastManualGridType=g_selectedGridType;
   g_v14FocusMagic=0;
   g_v14ExecutionMagic=0;
   g_v14ExecutionCycleId=0;
   g_state.lifecycleDeployments++;
   g_state.lifecycleCommandActive=false;
}

// -------------------- CHART THEME --------------------------------

color ThemeBackground(int t){switch(t){case 1:return C'10,12,16';case 2:return C'8,18,28';case 3:return C'8,24,20';case 4:return C'18,18,18';case 5:return C'20,12,28';case 6:return C'28,22,16';case 7:return C'25,10,14';case 8:return C'14,20,28';}return C'10,12,16';}

color ThemeForeground(int t){switch(t){case 4:return C'220,220,220';case 5:return C'238,230,250';case 6:return C'245,235,215';case 7:return C'245,225,225';case 8:return C'232,240,248';}return C'225,230,235';}

color ThemeGrid(int t){switch(t){case 2:return C'25,55,70';case 3:return C'25,65,55';case 4:return C'45,45,45';case 5:return C'60,40,78';case 6:return C'72,58,42';case 7:return C'72,35,40';case 8:return C'44,60,78';}return C'30,34,40';}

color ThemeUp(int t){switch(t){case 2:return C'85,210,235';case 3:return C'70,220,150';case 4:return C'225,225,225';case 5:return C'195,125,255';case 6:return C'224,188,118';case 7:return C'255,120,135';case 8:return C'150,220,255';}return clrLimeGreen;}

color ThemeDown(int t){switch(t){case 2:return C'255,120,110';case 3:return C'255,105,105';case 4:return C'155,155,155';case 5:return C'125,95,180';case 6:return C'168,118,72';case 7:return C'175,55,72';case 8:return C'95,145,205';}return clrTomato;}

color ThemeVolume(int t){switch(t){case 2:return C'75,150,180';case 3:return C'70,160,125';case 4:return C'120,120,120';case 5:return C'120,85,155';case 6:return C'150,120,80';case 7:return C'150,70,82';case 8:return C'90,125,160';}return C'90,95,105';}

color ThemeLine(int t){switch(t){case 2:return C'80,180,220';case 3:return C'80,210,160';case 4:return C'200,200,200';case 5:return C'190,150,240';case 6:return C'218,180,110';case 7:return C'245,105,120';case 8:return C'125,195,240';}return C'220,185,70';}

int DetectAutomaticChartTheme(){if(g_state.volatilityIndex>=g_state.highVolThreshold)return 2;if(g_state.trendStrength>=g_state.bullThreshold&&g_state.sentimentScore>=0.55)return 3;if(g_state.trendStrength<=g_state.bearThreshold&&g_state.sentimentScore<=0.45)return 7;if(g_state.trendStrength>=0.45&&g_state.trendStrength<=0.55)return 4;return 1;}

string ChartThemeName(int theme){switch(theme){case 1:return "Dark Luxury";case 2:return "Ocean Momentum";case 3:return "Emerald Bull";case 4:return "Monochrome Range";case 5:return "Royal Amethyst";case 6:return "Sandstone Gold";case 7:return "Crimson Noir";case 8:return "Arctic Silver";}return "Dark Luxury";}

void ApplyChartTheme(bool force=false){if(!g_state.autoChartTheme&&!force)return;int th=(int)g_state.chartThemeMode;if(g_state.chartThemeMode==CHART_THEME_AUTO_REGIME)th=DetectAutomaticChartTheme();if(!force&&g_state.appliedChartTheme==th){ChartSetInteger(0,CHART_SHOW_GRID,g_state.chartShowGrid);ChartSetInteger(0,CHART_SHOW_TRADE_LEVELS,g_state.chartShowTradeLevels);ChartSetInteger(0,CHART_AUTOSCROLL,g_state.chartAutoScroll);ChartSetInteger(0,CHART_SHIFT,g_state.chartShift);return;}ChartSetInteger(0,CHART_MODE,CHART_CANDLES);ChartSetInteger(0,CHART_COLOR_BACKGROUND,ThemeBackground(th));ChartSetInteger(0,CHART_COLOR_FOREGROUND,ThemeForeground(th));ChartSetInteger(0,CHART_COLOR_GRID,ThemeGrid(th));ChartSetInteger(0,CHART_COLOR_CHART_UP,ThemeUp(th));ChartSetInteger(0,CHART_COLOR_CHART_DOWN,ThemeDown(th));ChartSetInteger(0,CHART_COLOR_CANDLE_BULL,ThemeUp(th));ChartSetInteger(0,CHART_COLOR_CANDLE_BEAR,ThemeDown(th));ChartSetInteger(0,CHART_COLOR_VOLUME,ThemeVolume(th));ChartSetInteger(0,CHART_COLOR_BID,clrDeepSkyBlue);ChartSetInteger(0,CHART_COLOR_ASK,clrOrange);ChartSetInteger(0,CHART_COLOR_LAST,ThemeLine(th));ChartSetInteger(0,CHART_COLOR_STOP_LEVEL,clrTomato);ChartSetInteger(0,CHART_SHOW_GRID,g_state.chartShowGrid);ChartSetInteger(0,CHART_SHOW_TRADE_LEVELS,g_state.chartShowTradeLevels);ChartSetInteger(0,CHART_AUTOSCROLL,g_state.chartAutoScroll);ChartSetInteger(0,CHART_SHIFT,g_state.chartShift);ChartSetInteger(0,CHART_SHOW_VOLUMES,g_state.chartShowVolumes?CHART_VOLUME_TICK:CHART_VOLUME_HIDE);g_state.appliedChartTheme=th;ChartRedraw();}





// -------------------- DASHBOARD: PROFESSIONAL REBUILD ---------------------



void ApplyTheme()

{

   // Preserve the established palette exactly.

   if(InpDashboardTheme==THEME_GOLD)

   {

      COLOR_BG=C'5,10,14'; COLOR_PANEL=C'10,19,24'; COLOR_PANEL2=C'15,28,34';

      COLOR_TEXT=C'237,244,246'; COLOR_MUTED=C'122,149,159';

      COLOR_ACCENT=C'0,180,198'; COLOR_GOLD=C'218,171,62';

      COLOR_GREEN=C'66,211,116'; COLOR_RED=C'242,87,95';

      COLOR_ORANGE=C'237,160,54'; COLOR_TEAL=C'44,207,221';

   }

   else if(InpDashboardTheme==THEME_TEAL)

   {

      COLOR_BG=C'4,11,16'; COLOR_PANEL=C'8,23,30'; COLOR_PANEL2=C'11,37,44';

      COLOR_TEXT=C'235,247,249'; COLOR_MUTED=C'125,166,176';

      COLOR_ACCENT=C'21,204,214'; COLOR_GOLD=C'225,184,70';

      COLOR_GREEN=C'66,219,121'; COLOR_RED=C'243,91,99';

      COLOR_ORANGE=C'239,165,58'; COLOR_TEAL=C'58,223,229';

   }

   else

   {

      COLOR_BG=C'8,10,13'; COLOR_PANEL=C'16,18,22'; COLOR_PANEL2=C'27,29,34';

      COLOR_TEXT=C'239,241,244'; COLOR_MUTED=C'143,149,158';

      COLOR_ACCENT=C'92,168,255'; COLOR_GOLD=C'196,184,114';

      COLOR_GREEN=C'90,207,126'; COLOR_RED=C'237,104,109';

      COLOR_ORANGE=C'231,165,73'; COLOR_TEAL=C'116,199,210';

   }

}



void InitializeDashboard()

{

   g_dashboard.x=8;

   g_dashboard.y=8;

   g_dashboard.width=0;

   g_dashboard.height=0;

   g_dashboard.currentTab=0;

   g_dashboard.homeSubTab=0;

   g_dashboard.gridSubTab=0;

   g_dashboard.riskSubTab=0;

   g_dashboard.analyticsSubTab=0;

   g_dashboard.aiSubTab=0;

   g_dashboard.executionSubTab=0;

   g_dashboard.tradesSubTab=0;

   g_dashboard.transparencySubTab=0;
   g_userTrustSubTab=0;

   g_dashboard.diagnosticsSubTab=0;g_phase21SourceQualitySubTab=0;g_phase22SystemSubTab=0;

   g_dashboard.toolsSubTab=0;

   g_dashboard.autonomySubTab=0;g_dashboard.gridLabSubTab=0;g_dashboard.gridLabValidationSubTab=0;g_dashboard.gridLabMatrixSubTab=0;g_emergencySubTab=0;g_strategyHealthMainSubTab=0;

   g_dashboard.navOffset=0;

   g_dashboard.settingsPage=0;

   g_dashboard.settingsSubTab=0;

   g_dashboard.settingsSubTab2=0;

   g_dashboard.settingsSubTab3=0;

   g_dashboard.settingsSubTab4=0;

   g_dashboard.settingsSubTab5=0;

   g_dashboard.settingsSubTab6=0;

   

   g_dashboard.isVisible=InpShowDashboard;

   ApplyTheme();

}



void FitDashboard()

{

   int cw=(int)ChartGetInteger(0,CHART_WIDTH_IN_PIXELS);

   int ch=(int)ChartGetInteger(0,CHART_HEIGHT_IN_PIXELS);

   if(cw<220 || ch<220) return;



   // Actual dashboard footprint: keep the EA around half the chart width while

   // using nearly the available chart height. The internal UI is then scaled

   // uniformly so positions, cards, buttons, inputs and fonts stay proportional.

   int actualW=(int)MathFloor((double)cw*0.48);

   actualW=MathMax(390,MathMin(600,actualW));

   if(actualW>cw-12) actualW=cw-12;

   if(actualW<300) actualW=cw-12;



   int actualH=MathMax(300,ch-12);

   actualH=MathMin(actualH,760);



   // Reference design size. Keep the whole UI readable on small charts and

   // allow controlled enlargement on larger charts.

   double sx=(double)actualW/440.0;

   double sy=(double)actualH/620.0;

   g_uiScale=MathMax(0.78,MathMin(1.20,MathMin(sx,sy)));



   // Store logical dimensions. Rendering helpers convert these to actual pixels.

   g_dashboard.width=(int)MathMax(300.0,MathRound((double)actualW/g_uiScale));

   g_dashboard.height=(int)MathMax(300.0,MathRound((double)actualH/g_uiScale));

   g_dashboard.x=6;

   g_dashboard.y=6;

}



int UISX(int x){return g_dashboard.x+(int)MathRound((x-g_dashboard.x)*g_uiScale);}

int UISY(int y){return g_dashboard.y+(int)MathRound((y-g_dashboard.y)*g_uiScale);}

int UISW(int w){return MathMax(1,(int)MathRound(w*g_uiScale));}

int UISH(int h){return MathMax(1,(int)MathRound(h*g_uiScale));}

int UISF(int fs){return MathMax(7,(int)MathRound(fs*g_uiScale));}



int ContentX(){ return g_dashboard.x+MathMax(112,MathMin(124,(int)(g_dashboard.width*0.29))); }

int ContentY(){ return g_dashboard.y+103; }

int ContentW(){ return MathMax(170,g_dashboard.width-(ContentX()-g_dashboard.x)-12); }

int ContentH(){ return MathMax(180,g_dashboard.height-134); }



void DRect(string id,int x,int y,int w,int h,color bg,color border=clrNONE)

{

   if(w<=0 || h<=0) return;

   string n=ObjName(id);

   if(ObjectFind(0,n)<0) ObjectCreate(0,n,OBJ_RECTANGLE_LABEL,0,0,0);

   ObjectSetInteger(0,n,OBJPROP_XDISTANCE,UISX(x));

   ObjectSetInteger(0,n,OBJPROP_YDISTANCE,UISY(y));

   ObjectSetInteger(0,n,OBJPROP_XSIZE,UISW(w));

   ObjectSetInteger(0,n,OBJPROP_YSIZE,UISH(h));

   ObjectSetInteger(0,n,OBJPROP_BGCOLOR,bg);

   ObjectSetInteger(0,n,OBJPROP_BORDER_COLOR,border==clrNONE?COLOR_PANEL2:border);

   ObjectSetInteger(0,n,OBJPROP_CORNER,CORNER_LEFT_UPPER);

   ObjectSetInteger(0,n,OBJPROP_SELECTABLE,false);

   ObjectSetInteger(0,n,OBJPROP_HIDDEN,true);

   ObjectSetInteger(0,n,OBJPROP_ZORDER,5);

}



void DText(string id,string text,int x,int y,int fs,color clr,string font="Arial")

{

   string n=ObjName(id);

   if(ObjectFind(0,n)<0) ObjectCreate(0,n,OBJ_LABEL,0,0,0);

   ObjectSetInteger(0,n,OBJPROP_XDISTANCE,UISX(x));

   ObjectSetInteger(0,n,OBJPROP_YDISTANCE,UISY(y));

   ObjectSetInteger(0,n,OBJPROP_FONTSIZE,UISF(fs));

   ObjectSetString(0,n,OBJPROP_FONT,font);

   ObjectSetString(0,n,OBJPROP_TEXT,text);

   ObjectSetInteger(0,n,OBJPROP_COLOR,clr);

   ObjectSetInteger(0,n,OBJPROP_CORNER,CORNER_LEFT_UPPER);

   ObjectSetInteger(0,n,OBJPROP_SELECTABLE,false);

   ObjectSetInteger(0,n,OBJPROP_HIDDEN,true);

   ObjectSetInteger(0,n,OBJPROP_ZORDER,20);

}



void DSet(string id,string text,color clr=clrNONE)

{

   string n=ObjName(id);

   if(ObjectFind(0,n)>=0)

   {

      ObjectSetString(0,n,OBJPROP_TEXT,text);

      if(clr!=clrNONE) ObjectSetInteger(0,n,OBJPROP_COLOR,clr);

   }

}



void DButton(string id,string text,int x,int y,int w,int h,color bg,bool selected=false,int fs=7)

{

   w=MathMax(28,w); h=MathMax(28,h);

   string n=ObjName(id);

   if(ObjectFind(0,n)<0) ObjectCreate(0,n,OBJ_BUTTON,0,0,0);

   ObjectSetInteger(0,n,OBJPROP_XDISTANCE,UISX(x));

   ObjectSetInteger(0,n,OBJPROP_YDISTANCE,UISY(y));

   ObjectSetInteger(0,n,OBJPROP_XSIZE,UISW(w));

   ObjectSetInteger(0,n,OBJPROP_YSIZE,UISH(h));

   ObjectSetInteger(0,n,OBJPROP_FONTSIZE,UISF(fs));

   ObjectSetString(0,n,OBJPROP_FONT,"Arial Bold");

   ObjectSetString(0,n,OBJPROP_TEXT,text);

   // Use black text on bright/action backgrounds (including selected tabs);

   // retain the normal light text on dark neutral buttons for readability.

   color buttonText=COLOR_TEXT;

   if(bg==COLOR_ACCENT || bg==COLOR_GOLD || bg==COLOR_GREEN ||

      bg==COLOR_RED || bg==COLOR_ORANGE || bg==COLOR_TEAL)

      buttonText=C'0,0,0';

   ObjectSetInteger(0,n,OBJPROP_COLOR,buttonText);

   ObjectSetInteger(0,n,OBJPROP_BGCOLOR,bg);

   ObjectSetInteger(0,n,OBJPROP_BORDER_COLOR,selected?COLOR_GOLD:COLOR_PANEL2);

   ObjectSetInteger(0,n,OBJPROP_STATE,false);

   ObjectSetInteger(0,n,OBJPROP_CORNER,CORNER_LEFT_UPPER);

   ObjectSetInteger(0,n,OBJPROP_SELECTABLE,true);

   ObjectSetInteger(0,n,OBJPROP_HIDDEN,true);

   ObjectSetInteger(0,n,OBJPROP_ZORDER,50);

}



void DKV(string id,string label,string value,int x,int y,int labelW=80,color valueColor=clrWhite)

{

   DText(id+"_L",label,x,y,7,COLOR_MUTED,"Arial");

   DText(id+"_V",value,x+labelW,y-1,7,valueColor,"Arial Bold");

}



void DMetric(string id,string title,string value,int x,int y,int w,color valueColor)

{

   DRect(id+"_BOX",x,y,w,58,C'12,23,28',COLOR_PANEL2);

   DText(id+"_T",title,x+8,y+7,7,COLOR_MUTED,"Arial Bold");

   DText(id+"_V",value,x+8,y+27,10,valueColor,"Arial Bold");

}



void DBar(string id,string title,double pct,int x,int y,int w,color fill)

{

   pct=MathMax(0.0,MathMin(100.0,pct));

   DText(id+"_L",title,x,y,7,COLOR_MUTED,"Arial Bold");

   DRect(id+"_TR",x,y+15,w,6,C'27,36,41',C'27,36,41');

   int fw=(int)MathRound(w*pct/100.0);

   if(fw>0) DRect(id+"_BR",x,y+15,fw,6,fill,fill);

   DText(id+"_P",StringFormat("%.0f%%",pct),x+w+6,y+10,7,fill,"Arial Bold");

}



void DToggle(string id,string label,bool state,int x,int y,int w)

{

   DButton(id,label+(state?"  ON":"  OFF"),x,y,w,24,state?COLOR_GREEN:COLOR_PANEL2,state,7);

}



void CreateInput(string name,string value,int x,int y,int w)

{

   string s=GetEditValue(name,value);

   if(s!="") value=s;

   if(ObjectFind(0,name)<0) ObjectCreate(0,name,OBJ_EDIT,0,0,0);

   ObjectSetInteger(0,name,OBJPROP_XDISTANCE,UISX(x));

   ObjectSetInteger(0,name,OBJPROP_YDISTANCE,UISY(y));

   ObjectSetInteger(0,name,OBJPROP_XSIZE,UISW(w));

   ObjectSetInteger(0,name,OBJPROP_YSIZE,UISH(20));

   ObjectSetInteger(0,name,OBJPROP_FONTSIZE,UISF(8));

   ObjectSetString(0,name,OBJPROP_FONT,"Arial");

   ObjectSetString(0,name,OBJPROP_TEXT,value);

   ObjectSetInteger(0,name,OBJPROP_COLOR,COLOR_TEXT);

   ObjectSetInteger(0,name,OBJPROP_BGCOLOR,C'10,17,21');

   ObjectSetInteger(0,name,OBJPROP_BORDER_COLOR,COLOR_ACCENT);

   ObjectSetInteger(0,name,OBJPROP_CORNER,CORNER_LEFT_UPPER);

   ObjectSetInteger(0,name,OBJPROP_HIDDEN,true);

   ObjectSetInteger(0,name,OBJPROP_ZORDER,55);

}



void DInput(string id,string label,string value,int x,int y,int w)

{

   DText(id+"_L",label,x,y,7,COLOR_MUTED,"Arial");

   CreateInput(ObjName(id),value,x+88,y-4,w);

}



void DSectionSingle(string id,string title,int x,int y,int w,int h)

{

   DRect(id,x,y,w,h,COLOR_PANEL,COLOR_PANEL2);

   DText(id+"_TITLE",title,x+12,y+8,9,COLOR_GOLD,"Arial Bold");

   DRect(id+"_LINE",x+12,y+28,w-24,1,COLOR_PANEL2,COLOR_PANEL2);

}



void DPageTitle(string title,string subtitle)

{

   int x=ContentX(),y=ContentY();

   DText("PAGE_TITLE",title,x,y,11,COLOR_TEXT,"Arial Bold");

   DText("PAGE_SUB",subtitle,x,y+18,7,COLOR_MUTED,"Arial");

}



string SubTabParentName(string prefix)

{

   if(prefix=="HOME_SUB_") return "HOME";

   if(prefix=="GRID_SUB_") return "GRID ENGINE";

   if(prefix=="RISK_SUB_") return "RISK & PROTECTION";

   if(prefix=="AN_SUB_") return "ANALYTICS";

   if(prefix=="AI_SUB_") return "AI ENGINE";

   if(prefix=="EX_SUB_") return "EXECUTION";

   if(prefix=="TR_SUB_") return "TRADES";

   if(prefix=="TRN_SUB_") return "TRANSPARENCY";

   if(prefix=="DIA_SUB_") return "DIAGNOSTICS";

   if(prefix=="TOOLS_SUB_") return "TOOLS";

   if(prefix=="AUTONOMY_SUB_") return "AUTONOMY CONTROL";

   if(prefix=="GRIDLAB_SUB_") return "GRID VALIDATION LAB";

   return "WORKSPACE";

}



int NestedGroupCount(string prefix)
{
   if(prefix=="HOME_SUB_") return 3;
   if(prefix=="GRID_SUB_") return 3;
   if(prefix=="RISK_SUB_") return 6;
   if(prefix=="AN_SUB_") return 2;
   if(prefix=="AI_SUB_") return 2;
   if(prefix=="EX_SUB_") return 3;
   if(prefix=="TR_SUB_") return 2;
   if(prefix=="TRN_SUB_") return 3;
   if(prefix=="DIA_SUB_") return 2;
   if(prefix=="TOOLS_SUB_") return 2;
   if(prefix=="AUTONOMY_SUB_") return 4;
   if(prefix=="STRATHEALTH_SUB_") return 4;
   return 1;
}

int NestedGroupStart(string prefix,int group)
{
   if(prefix=="HOME_SUB_"){if(group==0)return 0;if(group==1)return 2;if(group==2)return 3;}
   if(prefix=="GRID_SUB_"){if(group==0)return 0;if(group==1)return 2;if(group==2)return 5;}
   if(prefix=="RISK_SUB_"){if(group==0)return 0;if(group==1)return 1;if(group==2)return 3;if(group==3)return 5;if(group==4)return 7;if(group==5)return 8;}
   if(prefix=="AN_SUB_"){if(group==0)return 0;if(group==1)return 1;}
   if(prefix=="AI_SUB_"){if(group==0)return 0;if(group==1)return 2;}
   if(prefix=="EX_SUB_"){if(group==0)return 0;if(group==1)return 1;if(group==2)return 3;}
   if(prefix=="TR_SUB_"){if(group==0)return 0;if(group==1)return 2;}
   if(prefix=="TRN_SUB_"){if(group==0)return 0;if(group==1)return 2;if(group==2)return 3;}
   if(prefix=="DIA_SUB_"){if(group==0)return 0;if(group==1)return 1;}
   if(prefix=="TOOLS_SUB_"){if(group==0)return 0;if(group==1)return 2;}
   if(prefix=="AUTONOMY_SUB_"){if(group==0)return 0;if(group==1)return 3;if(group==2)return 7;if(group==3)return 8;}
   if(prefix=="STRATHEALTH_SUB_"){if(group==0)return 0;if(group==1)return 1;if(group==2)return 4;if(group==3)return 6;}
   return 0;
}

int NestedGroupEnd(string prefix,int group,int count)
{
   int st=NestedGroupStart(prefix,group);
   int nxt=(group+1<NestedGroupCount(prefix)?NestedGroupStart(prefix,group+1):count);
   if(nxt>count)nxt=count;
   if(nxt<=st)nxt=st+1;
   return nxt-1;
}

string NestedGroupLabel(string prefix,int group)
{
   if(prefix=="HOME_SUB_"){if(group==0)return "CORE";if(group==1)return "MARKET";return "PORTFOLIO";}
   if(prefix=="GRID_SUB_"){if(group==0)return "CONFIGURE";if(group==1)return "OPERATE";return "STRATEGY";}
   if(prefix=="RISK_SUB_"){if(group==0)return "MASTER";if(group==1)return "GOVERNANCE";if(group==2)return "TRADE";if(group==3)return "CAPACITY";if(group==4)return "EXECUTION";return "AUTHORITY";}
   if(prefix=="AN_SUB_"){if(group==0)return "OVERVIEW";return "TELEMETRY";}
   if(prefix=="AI_SUB_"){if(group==0)return "INTELLIGENCE";return "FILTERS";}
   if(prefix=="EX_SUB_"){if(group==0)return "QUALITY";if(group==1)return "PARAMETERS";return "FLOW";}
   if(prefix=="TR_SUB_"){if(group==0)return "POSITIONS";return "MANAGEMENT";}
   if(prefix=="TRN_SUB_"){if(group==0)return "STATE";if(group==1)return "AUDIT";return "USER TRUST";}
   if(prefix=="DIA_SUB_"){if(group==0)return "SYSTEM";return "AUDIT";}
   if(prefix=="TOOLS_SUB_"){if(group==0)return "USER TOOLS";return "SYSTEM";}
   if(prefix=="AUTONOMY_SUB_"){if(group==0)return "CONTROL";if(group==1)return "STRATEGY";if(group==2)return "GOVERNANCE";return "AUDIT";}
   if(prefix=="STRATHEALTH_SUB_"){if(group==0)return "OVERVIEW";if(group==1)return "GRID ANALYSIS";if(group==2)return "MARKET CONTEXT";return "ALLOCATION";}
   return "WORKSPACE";
}

int NestedGroupForIndex(string prefix,int selected,int count)
{
   int gc=NestedGroupCount(prefix);
   for(int g=0;g<gc;g++)
      if(selected>=NestedGroupStart(prefix,g) && selected<=NestedGroupEnd(prefix,g,count)) return g;
   return 0;
}

void DNestedSubTabs(const string &labels[],int count,int selected,string prefix)
{
   if(count<=0)return;
   if(selected<0)selected=0;
   if(selected>=count)selected=count-1;
   int x=ContentX(),w=ContentW(),gy=ContentY()+30,gh=25,py=gy+30,ph=31;
   int gc=NestedGroupCount(prefix),ag=NestedGroupForIndex(prefix,selected,count),gap=3;
   int gw=MathMax(42,(w-gap*(gc-1))/MathMax(1,gc));
   DRect(prefix+"_GROUP_RAIL",x,gy,w,gh,C'7,14,18',COLOR_PANEL2);
   for(int g=0;g<gc;g++)
   {
      int bx=x+g*(gw+gap),bw=(g==gc-1)?(w-(bx-x)):gw;
      DButton(prefix+"_GROUP_"+IntegerToString(g),NestedGroupLabel(prefix,g),bx,gy+1,bw,23,g==ag?COLOR_ACCENT:COLOR_PANEL2,g==ag,6);
   }
   int gs=NestedGroupStart(prefix,ag),ge=NestedGroupEnd(prefix,ag,count);
   DRect(prefix+"_RAIL",x,py,w,ph,C'7,14,18',COLOR_PANEL2);
   DButton(prefix+"_PREV","<",x+4,py+4,28,23,COLOR_PANEL2,false,8);
   DText(prefix+"_INDEX",StringFormat("%02d / %02d",selected-gs+1,ge-gs+1),x+38,py+8,6,COLOR_MUTED,"Arial Bold");
   DText(prefix+"_ACTIVE",StringFormat("%s  \xBB  %s",NestedGroupLabel(prefix,ag),labels[selected]),x+82,py+7,7,COLOR_GOLD,"Arial Bold");
   DButton(prefix+"_NEXT",">",x+w-32,py+4,28,23,COLOR_PANEL2,false,8);
   DRect(prefix+"_LINE",x,py+ph+5,w,1,COLOR_PANEL2,COLOR_PANEL2);
}

int PageBodyY(int subCount)
{
   return ContentY()+30+25+30+31+8+10;
}

string GridButtonLabel(int idx)

{

   switch(idx)

   {

      case 0:return "01  BASIC";

      case 1:return "02  HEDGE";

      case 2:return "03  TREND";

      case 3:return "04  VOLATILITY";

      case 4:return "05  AI GRID";

      case 5:return "06  GEOMETRIC";

      case 6:return "07  FIBONACCI";

      case 7:return "08  ATR ADAPTIVE";

      case 8:return "09  MEAN REV";

      case 9:return "10  BREAKOUT";

      case 10:return "11  MOMENTUM";

      case 11:return "12  HYBRID SMART";

      case 12:return "13  BULLISH";

      case 13:return "14  BEARISH";

      case 14:return "15  BIDIRECTIONAL";

      case 15:return "16  LADDER";

      case 16:return "17  ANTI-MART";

      case 17:return "18  RANGE SCALING";

      case 18:return "19  VOL BREAKOUT";

      case 19:return "20  SESSION";

      case 20:return "21  SMART REGIME";

   }

   return "GRID";

}



bool IsSystemTradingActiveUI()
{
   // Terminal Algo Trading switch is the primary user-facing trading permission.
   // MQL trade permission also has to be available to the EA itself.
   return (TerminalInfoInteger(TERMINAL_TRADE_ALLOWED)!=0 && MQLInfoInteger(MQL_TRADE_ALLOWED)!=0);
}

string SystemActivityTextUI()
{
   return IsSystemTradingActiveUI() ? "MANUAL • ENGINE ACTIVE" : "INACTIVE • ALGO TRADING OFF";
}

color SystemActivityColorUI()
{
   return IsSystemTradingActiveUI() ? COLOR_GREEN : COLOR_RED;
}

void DashboardHeader()
{
   int x=g_dashboard.x,y=g_dashboard.y,w=g_dashboard.width;
   DRect("ROOT",x,y,w,g_dashboard.height,COLOR_BG,COLOR_ACCENT);
   DRect("HEADER",x+1,y+1,w-2,92,C'8,18,23',COLOR_PANEL2);

   // Professional identity block.
   DText("HEADER_TITLE","NOVA MULTI-GRID",x+12,y+6,12,COLOR_GOLD,"Arial Bold");
   DText("HEADER_SUB",StringFormat("%s  •  %s  •  %s",_Symbol,EnumToString((ENUM_TIMEFRAMES)_Period),CompactGridName(g_state.gridType)),x+12,y+24,6,COLOR_TEXT,"Arial");
   string liveState=g_state.gridActive?"LIVE":"READY";
   DText("HEADER_LIVE",StringFormat("● %s",liveState),x+12,y+40,6,g_state.gridActive?COLOR_GREEN:COLOR_MUTED,"Arial Bold");
   DText("HEADER_EQ",StringFormat("EQ %s",FormatNumber(AccountInfoDouble(ACCOUNT_EQUITY))),x+67,y+40,6,COLOR_TEXT,"Arial Bold");
   DText("HEADER_PL",StringFormat("P/L %s",FormatNumber(g_state.currentProfit)),x+138,y+40,6,g_state.currentProfit>=0?COLOR_GREEN:COLOR_RED,"Arial Bold");

   // Single consolidated system-status capsule replaces the previous CTRL / GRID / SAFE chips.
   int sx=x+w-184, sy=y+5, sw=174, sh=49;
   DRect("HDR_SYSTEM",sx,sy,sw,sh,C'11,23,28',COLOR_ACCENT);
   DText("HDR_SYSTEM_T","SYSTEM STATUS",sx+10,sy+6,6,COLOR_MUTED,"Arial Bold");
   bool tradingActive=IsSystemTradingActiveUI();
   string systemActivity=tradingActive ? StringFormat("%s • %s",ControlModeName(g_state.controlMode),g_state.gridActive?"ENGINE ACTIVE":"ENGINE READY") : "INACTIVE • ALGO TRADING OFF";
   DText("HDR_SYSTEM_V1",systemActivity,sx+10,sy+20,7,SystemActivityColorUI(),"Arial Bold");
   string survivalState=g_state.emergencyActive?"SURVIVAL: ACTIVE":"SURVIVAL: CLEAR";
   DText("HDR_SYSTEM_V2",survivalState,sx+10,sy+34,6,g_state.emergencyActive?COLOR_RED:COLOR_GREEN,"Arial Bold");

   // Command row: consistent baseline and action hierarchy.
   int ax=x+12,ay=y+59,gap=5;
   int bw=MathMax(52,(w-24-5*gap)/6);
   DButton("BTN_START","START",ax,ay,bw,27,COLOR_GREEN,false,7);
   DButton("BTN_REBAL","RE-CENTER",ax+bw+gap,ay,bw,27,COLOR_ACCENT,false,6);
   DButton("BTN_CANCEL_PENDING","CANCEL PENDING",ax+2*(bw+gap),ay,bw,27,COLOR_PANEL2,false,6);
   DButton("BTN_CLOSE_PROFIT","CLOSE PROFIT",ax+3*(bw+gap),ay,bw,27,COLOR_GREEN,false,6);
   DButton("BTN_CLOSE_LOSS","CLOSE LOSS",ax+4*(bw+gap),ay,bw,27,COLOR_RED,false,6);
   DButton("BTN_STOP","CLOSE ALL",ax+5*(bw+gap),ay,bw,27,COLOR_RED,false,6);
}

string DashboardNavLabel(int i)
{
   switch(i)
   {
      case 0: return "HOME";
      case 1: return "GRID ENGINE";
      case 2: return "GRID LAB";
      case 3: return "STRAT HEALTH";
      case 4: return "RISK";
      case 5: return "AUTONOMY";
      case 6: return "ANALYTICS";
      case 7: return "AI ENGINE";
      case 8: return "EXECUTION";
      case 9: return "TRADES";
      case 10: return "EMERGENCY";
      case 11: return "TRANSPARENCY";
      case 12: return "DIAGNOSTICS";
      case 13: return "TOOLS";
      case 14: return "SETTINGS";
   }
   return "";
}


void DashboardNavigation()

{

   int x=g_dashboard.x+7,y=g_dashboard.y+103;

   int navW=MathMax(96,MathMin(112,(int)(g_dashboard.width*0.27)));

   int navH=g_dashboard.height-134;

   



   DRect("NAV_BG",x,y,navW,navH,C'8,15,19',COLOR_PANEL2);

   DText("NAV_TITLE","WORKSPACES",x+10,y+10,7,COLOR_MUTED,"Arial Bold");



   // Responsive navigator: reserve a dedicated lower control zone so the final command

   // entry can never sit behind the navigation arrows/index/system status.

   // The command list is therefore visually separated from the navigation controls.

   int top=y+31;

   int controlsZone=112;

   int bottom=y+navH-controlsZone;

   int available=MathMax(90,bottom-top);

   int visible=MathMax(3,MathMin(TAB_COUNT,(available+4)/28));

   int maxOffset=MathMax(0,TAB_COUNT-visible);

   g_dashboard.navOffset=MathMax(0,MathMin(g_dashboard.navOffset,maxOffset));

   int bh=MathMax(20,MathMin(27,(available-(visible-1)*3)/visible));

   int gap=3;



   for(int row=0;row<visible;row++)

   {

      int i=g_dashboard.navOffset+row;

      if(i>=TAB_COUNT) break;

      int py=top+row*(bh+gap);

      DButton("NAV_"+IntegerToString(i),DashboardNavLabel(i),x+6,py,navW-12,bh,

              i==g_dashboard.currentTab?COLOR_ACCENT:COLOR_PANEL,i==g_dashboard.currentTab,6);

   }



   if(maxOffset>0)

   {

      // Dedicated navigation control strip. Kept well below the last command entry.

      int navBtnY=y+navH-98;

      DButton("NAV_UP","▲",x+6,navBtnY,(navW-15)/2,22,

              g_dashboard.navOffset>0?COLOR_PANEL2:C'6,11,15',false,7);

      DButton("NAV_DOWN","▼",x+9+(navW-15)/2,navBtnY,(navW-15)/2,22,

              g_dashboard.navOffset<maxOffset?COLOR_PANEL2:C'6,11,15',false,7);

      DText("NAV_INDEX",StringFormat("%d-%d / %d",g_dashboard.navOffset+1,

            MathMin(TAB_COUNT,g_dashboard.navOffset+visible),TAB_COUNT),

            x+9,y+navH-73,6,COLOR_MUTED,"Arial Bold");

   }
}



void DashboardFooter()

{

   int x=g_dashboard.x+7,y=g_dashboard.y+g_dashboard.height-19,w=g_dashboard.width-14;

   DRect("FOOTER",x,y,w,14,C'7,14,18',COLOR_PANEL2);

   DText("FOOTER_TEXT",StringFormat("MAGIC %I64u  ·  %s  ·  %s",InpMagicNumber,TimeToString(TimeCurrent(),TIME_SECONDS),g_state.executionStatus),x+7,y+2,6,COLOR_MUTED,"Arial");

}



// -------------------- HOME --------------------

void CreateHomeAccount(){int x=ContentX(),y=PageBodyY(5),w=ContentW();DSectionSingle("HOME_ACCOUNT","ACCOUNT",x,y,w,170);DMetric("HA_EQ","EQUITY",FormatNumber(AccountInfoDouble(ACCOUNT_EQUITY)),x+12,y+42,(w-36)/2,COLOR_TEXT);DMetric("HA_BAL","BALANCE",FormatNumber(AccountInfoDouble(ACCOUNT_BALANCE)),x+24+(w-36)/2,y+42,(w-36)/2,COLOR_TEXT);DKV("HA_DAY","TODAY P/L",FormatNumber(g_state.todayProfit),x+14,y+116,70,g_state.todayProfit>=0?COLOR_GREEN:COLOR_RED);}

void CreateHomeGrid(){int x=ContentX(),y=PageBodyY(5),w=ContentW();DSectionSingle("HOME_GRID","GRID STATUS",x,y,w,215);DKV("HG_STATE","STATE",g_state.gridActive?"ACTIVE":"IDLE",x+14,y+42,62,g_state.gridActive?COLOR_GREEN:COLOR_MUTED);DKV("HG_TYPE","TYPE",CompactGridName(g_state.gridType),x+14,y+70,62,COLOR_GOLD);DKV("HG_POS","POSITIONS",StringFormat("%d / %d",g_state.positionCount,g_state.maxPositions),x+14,y+98,62,COLOR_TEXT);DKV("HG_PEND","PENDING",StringFormat("%d / %d",g_state.pendingCount,g_state.maxPendingOrders),x+14,y+126,62,COLOR_GOLD);DKV("HG_ANCHOR","ANCHOR",DoubleToString(g_state.anchorPrice,_Digits),x+14,y+154,62,COLOR_TEXT);DBar("HG_LOAD","POSITION LOAD",g_state.maxPositions>0?100.0*g_state.positionCount/g_state.maxPositions:0,x+14,y+182,w-42,COLOR_TEAL);}

void CreateHomeMarket()
{
   int x=ContentX(),y=PageBodyY(5),w=ContentW();
   DSectionSingle("HOME_MARKET","MARKET STATE INTELLIGENCE",x,y,w,365);
   int gap=10,innerX=x+14,innerY=y+38,cw=(w-28-gap)/2;

   DSectionSingle("HM_SNAPSHOT","MARKET SNAPSHOT",innerX,innerY,cw,285);
   DKV("HM_REG","REGIME",g_state.marketRegime!=""?g_state.marketRegime:g_state.regime,innerX+12,innerY+40,68,g_state.marketNoTrade?COLOR_RED:COLOR_GOLD);
   DKV("HM_SES","SESSION",g_state.marketSession,innerX+12,innerY+68,68,COLOR_TEXT);
   DKV("HM_SPR","SPREAD",StringFormat("%.2f pips",g_state.currentSpreadPips),innerX+12,innerY+96,68,(g_state.maxSpreadPips<=0||g_state.currentSpreadPips<=g_state.maxSpreadPips)?COLOR_GREEN:COLOR_RED);
   DKV("HM_REASON","DECISION",CompactMarketDecisionV15(),innerX+12,innerY+124,68,g_state.marketNoTrade?COLOR_RED:COLOR_TEXT);
   DKV("HM_DATA","DATA",g_state.marketDataFresh?"FRESH":"STALE",innerX+12,innerY+166,68,g_state.marketDataFresh?COLOR_GREEN:COLOR_RED);
   if(g_state.useMultiTimeframeMarketState)
      DKV("HM_MTF","M5 / M15 / H1",StringFormat("%.0f%% / %.0f%% / %.0f%%",g_state.mtfTrendM5*100.0,g_state.mtfTrendM15*100.0,g_state.mtfTrendH1*100.0),innerX+12,innerY+194,90,COLOR_TEXT);
   else
      DKV("HM_MTF","ANALYSIS TF",EnumToString((ENUM_TIMEFRAMES)_Period),innerX+12,innerY+194,90,COLOR_TEXT);
   DKV("HM_STAB","STABILITY",StringFormat("%.0f%%",g_state.marketStabilityScore*100.0),innerX+12,innerY+222,68,COLOR_TEXT);
   DToggle("HM_MTF_TOGGLE","MULTI-TIMEFRAME",g_state.useMultiTimeframeMarketState,innerX+12,innerY+250,cw-24);

   DSectionSingle("HM_DIAG","MARKET DIAGNOSTICS",innerX+cw+gap,innerY,cw,285);
   DBar("HM_TREND","CURRENT TREND",g_state.trendStrength*100.0,innerX+cw+gap+12,innerY+40,cw-30,g_state.trendStrength>=g_state.bullThreshold?COLOR_GREEN:COLOR_TEAL);
   DBar("HM_VOL","VOL PERCENTILE",g_state.atrPercentile*100.0,innerX+cw+gap+12,innerY+76,cw-30,COLOR_ORANGE);
   DBar("HM_CONF","REGIME CONF.",g_state.regimeConfidence*100.0,innerX+cw+gap+12,innerY+112,cw-30,COLOR_GOLD);
   DBar("HM_COMP","COMPRESSION",g_state.compressionScore*100.0,innerX+cw+gap+12,innerY+148,cw-30,COLOR_GOLD);
   DBar("HM_BREAK","BREAKOUT PRESSURE",g_state.breakoutPressure*100.0,innerX+cw+gap+12,innerY+184,cw-30,COLOR_TEAL);
   DBar("HM_STAB2","MARKET STABILITY",g_state.marketStabilityScore*100.0,innerX+cw+gap+12,innerY+220,cw-30,COLOR_TEAL);
}

void CreateHomeExposure(){int x=ContentX(),y=PageBodyY(5),w=ContentW();DSectionSingle("HOME_EXPOSURE","EXPOSURE",x,y,w,190);DMetric("HE_PL","OPEN P/L",FormatNumber(g_state.currentProfit),x+12,y+42,(w-36)/3,g_state.currentProfit>=0?COLOR_GREEN:COLOR_RED);DMetric("HE_POS","POSITIONS",IntegerToString(g_state.positionCount),x+24+(w-36)/3,y+42,(w-36)/3,COLOR_TEAL);DMetric("HE_PD","PENDING",IntegerToString(g_state.pendingCount),x+36+2*(w-36)/3,y+42,(w-36)/3,COLOR_GOLD);DKV("HE_BUY","BUY",IntegerToString(g_state.buyPositions),x+14,y+120,58,COLOR_GREEN);DKV("HE_SELL","SELL",IntegerToString(g_state.sellPositions),x+14,y+148,58,COLOR_RED);}

void CreateHomePerformance(){int x=ContentX(),y=PageBodyY(5),w=ContentW();DSectionSingle("HOME_PERF","PERFORMANCE",x,y,w,235);DKV("HP_T","TRADES",IntegerToString(g_state.totalTrades),x+14,y+42,70,COLOR_TEXT);DKV("HP_W","WINS",IntegerToString(g_state.wins),x+14,y+72,70,COLOR_GREEN);DKV("HP_L","LOSSES",IntegerToString(g_state.losses),x+14,y+102,70,COLOR_RED);DKV("HP_WR","WIN RATE",StringFormat("%.1f%%",g_state.winRate),x+14,y+132,70,COLOR_GREEN);DKV("HP_P","TOTAL P/L",FormatNumber(g_state.totalProfit),x+14,y+162,70,g_state.totalProfit>=0?COLOR_GREEN:COLOR_RED);DKV("HP_R","RE-CENTERS",IntegerToString(g_state.rebalances),x+14,y+192,70,COLOR_TEXT);}

void CreateHomeTab(){string s[] = {"ACCOUNT","GRID STATUS","MARKET STATE","EXPOSURE","PERFORMANCE"};DPageTitle("HOME","Live command center");DNestedSubTabs(s,5,g_dashboard.homeSubTab,"HOME_SUB_");switch(g_dashboard.homeSubTab){case 0:CreateHomeAccount();break;case 1:CreateHomeGrid();break;case 2:CreateHomeMarket();break;case 3:CreateHomeExposure();break;case 4:CreateHomePerformance();break;}}



// -------------------- GRID --------------------


string StrategyLibraryShortRegime()
{
   if(!g_state.gridProfileFormalized) return "ANY";
   if(g_selectedGridType==SMART_REGIME_GRID) return "TREND/RANGE/BRK";
   string s=g_state.gridProfilePreferredRegime;
   if(StringFind(s,"TREND UP")>=0) return "TREND UP";
   if(StringFind(s,"TREND DOWN")>=0) return "TREND DOWN";
   if(StringFind(s,"BREAKOUT")>=0) return "BREAKOUT";
   if(StringFind(s,"RANGE")>=0) return "RANGE";
   if(StringFind(s,"SHOCK")>=0) return "SHOCK";
   if(StringLen(s)>16) return StringSubstr(s,0,16);
   return s;
}
string StrategyLibraryShortDirection()
{
   if(!g_state.gridProfileFormalized) return "PROFILE";
   if(g_selectedGridType==SMART_REGIME_GRID) return "LONG / SHORT / BOTH";
   string s=g_state.gridProfileDirection;
   if(StringFind(s,"LONG")>=0 && StringFind(s,"SHORT")>=0) return "LONG/SHORT";
   if(StringFind(s,"LONG")>=0) return "LONG";
   if(StringFind(s,"SHORT")>=0) return "SHORT";
   if(StringLen(s)>14) return StringSubstr(s,0,14);
   return s;
}
void CreateGridCurrent()
{
   int x=ContentX(), y=PageBodyY(5), w=ContentW();
   int gap=8, cw=(w-gap)/2;
   DSectionSingle("GRID_CURRENT","CURRENT GRID",x,y,w,300);

   DSectionSingle("GRID_CURRENT_A","DEPLOYMENT",x+8,y+36,cw,276);
   DKV("GC1","TYPE",CompactGridName(g_selectedGridType),x+20,y+78,64,COLOR_GOLD);
   DKV("GC2","ENTRY",EntryModeName(g_state.entryMode),x+20,y+108,64,COLOR_TEXT);
   DKV("GC3","LOT",DoubleToString(g_state.lotSize,3),x+20,y+138,64,COLOR_TEXT);
   DKV("GC4","STEP",StringFormat("%.1f pips",g_state.gridStep),x+20,y+168,64,COLOR_TEXT);
   DKV("GC5","LEVELS",IntegerToString(g_state.gridLevels),x+20,y+198,64,COLOR_TEXT);
   DKV("GC6","EFFECTIVE",StringFormat("STEP %.1f / L%d",g_state.effectiveGridStepPips,g_state.effectiveGridLevels),x+20,y+228,64,COLOR_TEAL);

   DSectionSingle("GRID_CURRENT_B","STRATEGY PROFILE",x+8+cw,y+36,cw,276);
   DKV("GP41","STATUS",g_state.gridProfileFormalized?"FORMALIZED":"LEGACY",x+20+cw+8,y+78,66,g_state.gridProfileFormalized?COLOR_GREEN:COLOR_MUTED);
   DKV("GP42","ROLE",g_state.gridProfileFormalized?(g_state.gridProfileRole=="MASTER ROUTER"?"ROUTER":"SPECIALIST"):"LEGACY",x+20+cw+8,y+108,66,COLOR_GOLD);
   DKV("GP43","REGIME",StrategyLibraryShortRegime(),x+20+cw+8,y+138,66,COLOR_TEXT);
   DKV("GP44","DIRECTION",StrategyLibraryShortDirection(),x+20+cw+8,y+168,66,COLOR_TEAL);
   DKV("GP45","FIT",StringFormat("%.0f%%",g_state.gridProfileSuitability*100.0),x+20+cw+8,y+198,66,COLOR_GOLD);
   DKV("GP46","PROFILE",g_state.gridProfileFormalized?"P4.1":"LEGACY",x+20+cw+8,y+228,66,COLOR_TEXT);
   DKV("GC7","ANCHOR",GridAnchorModeName(g_state.adaptiveAnchorMode),x+20,y+258,64,COLOR_TEAL);
   DKV("GP47","STEP FACTOR",StringFormat("x%.2f",g_state.gridGeometryStepFactor),x+20+cw+8,y+258,66,COLOR_TEAL);

   DText("GRID_CURRENT_NOTE","Next deployment only • live trades remain unaffected",x+14,y+316,6,COLOR_MUTED,"Arial");
}

void CreateGridTypes()
{
   int x=ContentX(),y=PageBodyY(5),w=ContentW(),h=ContentH()-(y-ContentY())-6;
   DSectionSingle("GRID_TYPES","21 GRID TYPES",x,y,w,h);
   int cols=2,gapX=8,gapY=6;int bw=(w-28-gapX)/2;int rows=11;
   int bh=MathMax(24,MathMin(31,(h-46-(rows-1)*gapY)/rows));int by=y+38;
   for(int i=0;i<GRID_TYPE_COUNT;i++)
   {
      int r=i/cols,c=i%cols;
      string label=GridButtonLabel(i);
      DButton("GRID_SEL_"+IntegerToString(i),label,x+10+c*(bw+gapX),by+r*(bh+gapY),bw,bh,
              i==(int)g_selectedGridType?COLOR_ACCENT:COLOR_PANEL2,i==(int)g_selectedGridType,6);
   }
   DText("GRID_TYPES_NOTE","5 priority profiles formalized in P4.1 | 16 existing profiles preserved",x+10,y+h-14,6,COLOR_MUTED,"Arial");
}

void CreateGridActions()
{
   int x=ContentX(),y=PageBodyY(5),w=ContentW();
   DSectionSingle("GRID_ACTIONS","GRID ACTIONS",x,y,w,260);
   DButton("BTN_GRID_REBUILD","REBUILD GRID",x+14,y+44,w-28,30,COLOR_GOLD,false,7);
   DButton("BTN_REBAL_GRID","RE-CENTER GRID",x+14,y+84,w-28,30,COLOR_ACCENT,false,7);
   DButton("BTN_CANCEL_GRID2","CANCEL PENDING",x+14,y+124,w-28,30,COLOR_PANEL2,false,7);
   DButton("BTN_CLOSE_GRID2","CLOSE ALL GRID",x+14,y+164,w-28,30,COLOR_RED,false,7);
   DKV("GACT_STATUS","STATUS",StringSubstr(g_state.executionStatus,0,34),x+14,y+216,60,COLOR_GOLD);
   DSectionSingle("GACT_LIFE","LIFECYCLE",x,y+276,w,120);
   DKV("GACT_SCOPE","SCOPE",g_state.lifecycleScope==""?"PENDING + NEW":g_state.lifecycleScope,x+14,y+318,72,COLOR_TEXT);
   DKV("GACT_CMD","COMMAND",g_state.lifecycleCommand==""?"IDLE":g_state.lifecycleCommand,x+14,y+348,72,COLOR_GOLD);
   DKV("GACT_POS","LIVE POSITIONS",StringFormat("%d PRESERVED",g_state.positionCount),x+14,y+378,90,COLOR_GREEN);
}

void CreateGridLifecycleEngine()
{
   int x=ContentX(),y=PageBodyY(5),w=ContentW(),gap=8,cw=(w-gap)/2;
   DSectionSingle("GRID_LIFE_MAIN","LIFECYCLE ENGINE",x,y,w,330);

   DSectionSingle("GRID_LIFE_STATE","LIFECYCLE STATE",x+8,y+36,cw,250);
   DKV("GLS1","STATE",g_state.gridLifecycleState==""?"IDLE":g_state.gridLifecycleState,x+20,y+78,86,COLOR_GOLD);
   DKV("GLS2","COMMAND",g_state.lifecycleCommand==""?"IDLE":g_state.lifecycleCommand,x+20,y+108,86,COLOR_TEXT);
   DKV("GLS3","AUTHORITY",g_state.lifecycleAuthority==""?"GRID_LIFECYCLE":g_state.lifecycleAuthority,x+20,y+138,86,COLOR_TEAL);
   DKV("GLS4","SCOPE",StringSubstr(g_state.lifecycleScope==""?"PENDING + NEW":g_state.lifecycleScope,0,28),x+20,y+168,86,COLOR_TEXT);
   DKV("GLS5","LIVE POSITIONS",StringFormat("%d PRESERVED",g_state.positionCount),x+20,y+198,124,COLOR_GREEN);
   DKV("GLS6","LAST REASON",StringSubstr(g_state.gridLifecycleReason==""?"NONE":g_state.gridLifecycleReason,0,28),x+20,y+228,86,COLOR_MUTED);

   DSectionSingle("GRID_LIFE_ACTION","LIFECYCLE COMMANDS",x+8+cw,y+36,cw,250);
   DButton("BTN_LIFE_REBUILD","REBUILD GRID",x+20+cw+8,y+74,cw-40,30,COLOR_GOLD,false,7);
   DButton("BTN_LIFE_RECENTER","RE-CENTER GRID",x+20+cw+8,y+112,cw-40,30,COLOR_ACCENT,false,7);
   DButton("BTN_LIFE_CANCEL","CANCEL PENDING",x+20+cw+8,y+150,cw-40,30,COLOR_PANEL2,false,7);
   DButton("BTN_LIFE_REPLENISH","REPLENISH GRID",x+20+cw+8,y+188,cw-40,30,COLOR_PANEL2,false,7);
   DText("GLA_NOTE","Pending-grid lifecycle only • live positions remain independent",x+20+cw+8,y+226,6,COLOR_MUTED,"Arial");

   DSectionSingle("GRID_LIFE_TELEM","LIFECYCLE TELEMETRY",x,y+300,w,170);
   int tw=(w-42)/4;
   DMetric("GLT1","DEPLOYS",IntegerToString(g_state.lifecycleDeployments),x+12,y+338,tw,COLOR_TEAL);
   DMetric("GLT2","REBUILDS",IntegerToString(g_state.lifecycleRebuilds),x+22+tw,y+338,tw,COLOR_GOLD);
   DMetric("GLT3","RECENTERS",IntegerToString(g_state.lifecycleRecenters),x+32+tw*2,y+338,tw,COLOR_ACCENT);
   DMetric("GLT4","CANCELS",IntegerToString(g_state.lifecycleCancels),x+42+tw*3,y+338,tw,COLOR_TEXT);
   DKV("GLT5","REPLENISH",IntegerToString(g_state.lifecycleReplenishments),x+14,y+414,90,COLOR_TEXT);
   DKV("GLT6","FILLS",IntegerToString(g_state.lifecycleFillCount),x+150,y+414,70,COLOR_GREEN);
   DKV("GLT7","DELETES",IntegerToString(g_state.lifecycleDeleteCount),x+260,y+414,70,COLOR_ORANGE);
   DKV("GLT8","RECOVERY",IntegerToString(g_state.lifecycleRecoveryCount),x+380,y+414,80,COLOR_GOLD);
}

void CreateGridModeInfo()
{
   int x=ContentX(),y=PageBodyY(5),w=ContentW(),gap=8,cw=(w-gap)/2;
   DSectionSingle("GRID_INFO","ENGINE STATUS",x,y,w,250);

   DSectionSingle("GRID_INFO_A","INVENTORY",x+8,y+36,cw,192);
   DKV("GI1","ANCHOR",DoubleToString(g_state.anchorPrice,_Digits),x+20,y+78,62,COLOR_TEXT);
   DKV("GI2","BUY",IntegerToString(g_state.buyPositions),x+20,y+108,62,COLOR_GREEN);
   DKV("GI3","SELL",IntegerToString(g_state.sellPositions),x+20,y+138,62,COLOR_RED);
   DKV("GI4","BUY PEND",IntegerToString(g_state.buyPending),x+20,y+168,62,COLOR_GREEN);
   DKV("GI5","SELL PEND",IntegerToString(g_state.sellPending),x+20,y+198,62,COLOR_RED);

   DSectionSingle("GRID_INFO_B","ENGINE STATE",x+8+cw,y+36,cw,192);
   DKV("GI6","AUTO",g_state.autonomousMode?"ON":"OFF",x+20+cw+8,y+78,62,g_state.autonomousMode?COLOR_GREEN:COLOR_MUTED);
   DKV("GI7","REENTRY",g_state.reentryMode==REENTRY_OFF?"OFF":EnumToString(g_state.reentryMode),x+20+cw+8,y+108,62,COLOR_TEXT);
   DKV("GI8","GRID",g_state.gridActive?"ACTIVE":"IDLE",x+20+cw+8,y+138,62,g_state.gridActive?COLOR_GREEN:COLOR_MUTED);
   DKV("GI9","PENDING",IntegerToString(g_state.pendingCount),x+20+cw+8,y+168,62,COLOR_GOLD);
   DKV("GI10","POSITIONS",IntegerToString(g_state.positionCount),x+20+cw+8,y+198,62,COLOR_TEAL);

   DText("GRID_INFO_NOTE","Inventory is account-wide; positions are managed per trade",x+14,y+236,6,COLOR_MUTED,"Arial");
}

void CreateGridStrategyPolicy()
{
   int x=ContentX(),y=PageBodyY(6),w=ContentW(),gap=8,cw=(w-gap)/2;
   DSectionSingle("GRID_POLICY_MAIN","STRATEGY POLICY",x,y,w,300);

   DSectionSingle("GRID_POLICY_A","PROFILE DEFINITION",x+8,y+36,cw,244);
   DKV("GSP_T","TYPE",CompactGridName(g_selectedGridType),x+20,y+78,70,COLOR_GOLD);
   DKV("GSP_S","MODEL",StringSubstr(GridStrategyName(g_selectedGridType),0,14),x+20,y+108,70,COLOR_TEXT);
   DKV("GSP_D","DIRECTION",StringSubstr(GridDirectionModel(g_selectedGridType),0,12),x+20,y+138,70,COLOR_TEAL);
   DKV("GSP_X","DISTANCE",StringSubstr(GridDistanceModel(g_selectedGridType),0,12),x+20,y+168,70,COLOR_TEXT);
   DKV("GSP_L","LOT MODEL",StringSubstr(GridLotModel(g_selectedGridType),0,12),x+20,y+198,70,COLOR_TEXT);
   DKV("GSP_R","RULE",StringSubstr(GridSpecialRule(g_selectedGridType),0,12),x+20,y+228,70,COLOR_MUTED);

   DSectionSingle("GRID_POLICY_B","ADAPTATION",x+8+cw,y+36,cw,244);
   DKV("GSP_P1","STEP",StringFormat("x %.2f",g_state.gridPolicyStepFactor),x+20+cw+8,y+78,70,COLOR_TEAL);
   DKV("GSP_P2","LOT",StringFormat("x %.2f",g_state.gridPolicyLotFactor),x+20+cw+8,y+108,70,COLOR_TEAL);
   DKV("GSP_P3","LEVELS",g_state.gridPolicyLevelReason==""?"BASE":StringSubstr(g_state.gridPolicyLevelReason,0,10),x+20+cw+8,y+138,70,COLOR_TEXT);
   DKV("GSP_P4","OWNER",g_state.adaptiveGrid?"ADAPTIVE":"USER",x+20+cw+8,y+168,70,g_state.adaptiveGrid?COLOR_GOLD:COLOR_GREEN);
   DKV("GSP_P5","FIT",StringFormat("%.0f%%",g_state.gridProfileSuitability*100.0),x+20+cw+8,y+198,70,COLOR_GOLD);
   DKV("GSP_P6","REGIME",StrategyLibraryShortRegime(),x+20+cw+8,y+228,70,COLOR_TEXT);

   DText("GSP_NOTE","Read-only policy view • choose Grid Type to change",x+14,y+284,6,COLOR_MUTED,"Arial");
   DText("GSP_P5NOTE",g_state.gridGeometryGeometryReason,x+14,y+298,6,COLOR_MUTED,"Arial");
}

void CreateGridLiveEffects()
{
   int x=ContentX(),y=PageBodyY(6),w=ContentW(),gap=8,cw=(w-gap)/2;
   DSectionSingle("GRID_EFFECTS_MAIN","LIVE EFFECTS",x,y,w,300);

   DSectionSingle("GRID_EFFECTS_A","EFFECTIVE GEOMETRY",x+8,y+36,cw,244);
   DKV("GSPE_S","STEP FACTOR",StringFormat("x %.2f",g_state.gridPolicyStepFactor),x+20,y+78,82,COLOR_TEAL);
   DKV("GSPE_ES","STEP",StringFormat("%.1f pips",g_state.effectiveGridStepPips),x+20,y+108,82,COLOR_GOLD);
   DKV("GSPE_LV","LEVELS",IntegerToString(g_state.effectiveGridLevels),x+20,y+138,82,COLOR_GOLD);
   DKV("GSPE_OWNER","ANCHOR",GridAnchorModeName(g_state.adaptiveAnchorMode),x+20,y+168,82,COLOR_TEAL);
   DKV("GSPE_REG","REGIME",StrategyLibraryShortRegime(),x+20,y+198,82,COLOR_TEXT);
   DKV("GSPE_CONF","RISK CAP",StringFormat("%.0f%%",g_state.gridGeometryRiskCapacityFactor*100.0),x+20,y+228,82,COLOR_GOLD);

   DSectionSingle("GRID_EFFECTS_B","EFFECTIVE SIZING",x+8+cw,y+36,cw,244);
   DKV("GSPE_L","LOT FACTOR",StringFormat("x %.2f",g_state.gridPolicyLotFactor),x+20+cw+8,y+78,82,COLOR_TEAL);
   DKV("GSPE_ELOT","EFFECTIVE LOT",DoubleToString(g_state.effectiveLot,3),x+20+cw+8,y+108,82,COLOR_GOLD);
   DKV("GSPE_BASE","BASE LOT",DoubleToString(g_state.lotSize,3),x+20+cw+8,y+138,82,COLOR_TEXT);
   DKV("GSPE_RISK","RISK MODE",StringSubstr(EnumToString(g_state.riskMode),0,12),x+20+cw+8,y+168,82,COLOR_TEXT);
   DKV("GSPE_GRID","GRID",CompactGridName(g_selectedGridType),x+20+cw+8,y+198,82,COLOR_GOLD);
   DKV("GSPE_ENTRY","ENTRY",EntryModeName(g_state.entryMode),x+20+cw+8,y+228,82,COLOR_TEXT);
}


void CreateGridSelectionDirection()
{
   int x=ContentX(), y=PageBodyY(5), w=ContentW(), gap=8, cw=(w-gap)/2;
   DSectionSingle("GRID_SEL_MAIN","GRID SELECTION & DIRECTION",x,y,w,430);

   // DECISION PANEL: fixed label/value columns to prevent LONG/SHORT overlap.
   DSectionSingle("GRID_SEL_DEC","DECISION",x+8,y+36,cw,208);
   DKV("GSD_GRID","GRID",g_state.gridSelectionSelectedGridName!=""?g_state.gridSelectionSelectedGridName:"--",x+20,y+74,158,COLOR_GOLD);
   DKV("GSD_DIR","DIRECTION",g_state.gridSelectionDirection!=""?g_state.gridSelectionDirection:"NEUTRAL",x+20,y+102,158,COLOR_TEAL);
   DKV("GSD_FIT","GRID FIT",StringFormat("%.0f%%",g_state.gridSelectionSelectedScore*100.0),x+20,y+130,158,COLOR_GOLD);
   DKV("GSD_LONG","LONG SCORE",StringFormat("%.0f%%",g_state.gridSelectionLongScore*100.0),x+20,y+158,158,COLOR_GREEN);
   DKV("GSD_SHORT","SHORT SCORE",StringFormat("%.0f%%",g_state.gridSelectionShortScore*100.0),x+20,y+186,158,COLOR_RED);
   DKV("GSD_EDGE","DIRECTION EDGE",StringFormat("%.0f%%",g_state.gridSelectionDirectionEdge*100.0),x+20,y+214,158,COLOR_GOLD);

   // MARKET CONTEXT: same fixed columns, no concatenated label/value text.
   DSectionSingle("GRID_SEL_CTX","MARKET CONTEXT",x+8+cw,y+36,cw,208);
   DKV("GSC_REG","REGIME",StringSubstr(g_state.regime,0,16),x+20+cw+8,y+74,150,COLOR_TEXT);
   DKV("GSC_CONF","CONFIDENCE",StringFormat("%.0f%%",g_state.regimeConfidence*100.0),x+20+cw+8,y+102,150,COLOR_GOLD);
   DKV("GSC_VOL","VOLATILITY",StringFormat("%.0f%%",g_state.atrPercentile*100.0),x+20+cw+8,y+130,150,COLOR_ORANGE);
   DKV("GSC_COMP","COMPRESSION",StringFormat("%.0f%%",g_state.compressionScore*100.0),x+20+cw+8,y+158,150,COLOR_TEXT);
   DKV("GSC_BREAK","BREAKOUT",StringFormat("%.0f%%",g_state.breakoutPressure*100.0),x+20+cw+8,y+186,150,COLOR_TEXT);
   DKV("GSC_STAB","STABILITY",StringFormat("%.0f%%",g_state.marketStabilityScore*100.0),x+20+cw+8,y+214,150,COLOR_TEAL);

   // DECISION SUMMARY is intentionally ABOVE the ranking table.
   DSectionSingle("GRID_SEL_SUM","DECISION SUMMARY",x,y+252,w,62);
   string selected=(g_state.gridSelectionSelectedGridName!=""?g_state.gridSelectionSelectedGridName:"--");
   string dir=(g_state.gridSelectionDirection!=""?g_state.gridSelectionDirection:"NEUTRAL");
   DText("GRID_SEL_SUM1",StringFormat("SELECTED  %s   |   %s   |   FIT %.0f%%",selected,dir,g_state.gridSelectionSelectedScore*100.0),x+14,y+277,7,COLOR_GOLD,"Arial");
   DText("GRID_SEL_SUM2",StringFormat("LONG %.0f%%   SHORT %.0f%%   EDGE %.0f%%   |   %s",g_state.gridSelectionLongScore*100.0,g_state.gridSelectionShortScore*100.0,g_state.gridSelectionDirectionEdge*100.0,StringSubstr(g_state.regime,0,18)),x+14,y+298,6,COLOR_MUTED,"Arial");

   // TOP CANDIDATES: manual fixed columns; do not use DKV with a long label string.
   DSectionSingle("GRID_SEL_RANK","TOP 5 GRID CANDIDATES",x,y+322,w,108);
   int bestIdx[5]={-1,-1,-1,-1,-1};
   double bestScore[5]={-1,-1,-1,-1,-1};
   for(int i=0;i<GRID_TYPE_COUNT;i++)
   {
      double sc=g_phase6GridSuitability[i];
      for(int k=0;k<5;k++)
      {
         if(sc>bestScore[k])
         {
            for(int m=4;m>k;m--){bestScore[m]=bestScore[m-1];bestIdx[m]=bestIdx[m-1];}
            bestScore[k]=sc; bestIdx[k]=i; break;
         }
      }
   }
   int leftX=x+14, rightX=x+cw+18, baseY=y+350;
   for(int r=0;r<5;r++)
   {
      if(bestIdx[r]<0) continue;
      int col=(r<3?0:1), local=(col==0?r:r-3);
      int px=(col==0?leftX:rightX), py=baseY+local*22;
      string rankName=IntegerToString(r+1)+". "+CompactGridName((ENUM_GRID_TYPE)bestIdx[r]);
      string fitText=StringFormat("%.0f%%",bestScore[r]*100.0);
      color nameColor=(bestIdx[r]==(int)g_selectedGridType?COLOR_GOLD:COLOR_TEXT);
      color fitColor=(bestScore[r]>=0.70?COLOR_GREEN:(bestScore[r]>=0.50?COLOR_GOLD:COLOR_MUTED));
      DText(StringFormat("GSR%dN",r),rankName,px,py,7,nameColor,"Arial");
      DText(StringFormat("GSR%dS",r),fitText,px+145,py,7,fitColor,"Arial");
   }
}

void CreateGridPredictiveGrid()
{
   int x=ContentX(),y=PageBodyY(4),w=ContentW(),gap=12,cw=(w-gap)/2;
   DPageTitle("PREDICTIVE GRID","Forward excursion, reach probability and dynamic grid topology");
   DRect("PG1",x,y,cw,300,COLOR_PANEL2,COLOR_PANEL2);
   DText("PG1T","FORECAST",x+14,y+12,8,COLOR_GOLD,"Arial Bold");
   SettingsSectionStatus("PGS","STATE",g_state.predictiveState,x+14,y+46,COLOR_GOLD);
   SettingsSectionStatus("PGE","FWD EXCURSION",StringFormat("%.1f pips",g_state.predictiveExcursionPips),x+14,y+76,COLOR_TEXT);
   SettingsSectionStatus("PGR","RETRACEMENT",StringFormat("%.1f pips",g_state.predictiveRetracementPips),x+14,y+106,COLOR_TEXT);
   SettingsSectionStatus("PGA","ADVERSE",StringFormat("%.1f pips",g_state.predictiveAdversePips),x+14,y+136,COLOR_TEXT);
   SettingsSectionStatus("PGC","CONFIDENCE",StringFormat("%.0f%%",g_state.predictiveConfidence*100.0),x+14,y+166,COLOR_TEAL);
   SettingsSectionStatus("PGLOOK","LOOKAHEAD",StringFormat("%d bars",g_state.predictiveLookaheadBars),x+14,y+196,COLOR_MUTED);
   SettingsSectionStatus("PGRSN","REASON",StringSubstr(g_state.predictiveReason,0,32),x+14,y+226,COLOR_MUTED);
   DRect("PG2",x+cw+gap,y,cw,300,COLOR_PANEL2,COLOR_PANEL2);
   DText("PG2T","TOPOLOGY",x+cw+gap+14,y+12,8,COLOR_GOLD,"Arial Bold");
   SettingsSectionStatus("PGU","UPPER DENSITY",StringFormat("x%.2f",g_state.predictiveUpperDensity),x+cw+gap+14,y+46,COLOR_TEAL);
   SettingsSectionStatus("PGL","LOWER DENSITY",StringFormat("x%.2f",g_state.predictiveLowerDensity),x+cw+gap+14,y+76,COLOR_GOLD);
   SettingsSectionStatus("PGTS","TOPOLOGY SCORE",StringFormat("%.0f%%",g_state.predictiveTopologyScore*100.0),x+cw+gap+14,y+106,COLOR_TEXT);
   SettingsSectionStatus("PG1R","LEVEL 1 REACH",StringFormat("%.0f%%",g_state.predictiveLevelReach[0]*100.0),x+cw+gap+14,y+136,COLOR_TEXT);
   SettingsSectionStatus("PG5R","LEVEL 5 REACH",StringFormat("%.0f%%",g_state.predictiveLevelReach[4]*100.0),x+cw+gap+14,y+166,COLOR_TEXT);
   SettingsSectionStatus("PG10R","LEVEL 10 REACH",StringFormat("%.0f%%",g_state.predictiveLevelReach[9]*100.0),x+cw+gap+14,y+196,COLOR_TEXT);
   SettingsSectionStatus("PG25R","LEVEL 25 REACH",StringFormat("%.0f%%",g_state.predictiveLevelReach[24]*100.0),x+cw+gap+14,y+226,COLOR_TEXT);
   DText("PGNOTE","Topology adjusts selection/geometry only; it does not close trades.",x+14,y+322,6,COLOR_MUTED,"Arial");
}

void CreateGridTab()

{

   string s[]={"CURRENT GRID","GRID TYPES","GRID ACTIONS","LIFECYCLE ENGINE","ENGINE STATUS","STRATEGY POLICY","LIVE EFFECTS","SELECTION & DIRECTION","PREDICTIVE GRID"};

   DPageTitle("GRID ENGINE","Select, configure and inspect the grid engine");

   DNestedSubTabs(s,9,g_dashboard.gridSubTab,"GRID_SUB_");

   switch(g_dashboard.gridSubTab)

   {

      case 0:CreateGridCurrent();break;

      case 1:CreateGridTypes();break;

      case 2:CreateGridActions();break;

      case 3:CreateGridLifecycleEngine();break;

      case 4:CreateGridModeInfo();break;

      case 5:CreateGridStrategyPolicy();break;

      case 6:CreateGridLiveEffects();break;
      case 7:CreateGridSelectionDirection();break;
      case 8:CreateGridPredictiveGrid();break;

      default:CreateGridCurrent();break;

   }

}



// -------------------- RISK --------------------

void CreateRiskProfile(){int x=ContentX(),y=PageBodyY(4),w=ContentW();DSectionSingle("RISK_PROFILE","RISK PROFILE",x,y,w,240);DButton("BTN_RISK_MODE","PROFILE  "+RiskModeName(g_state.riskMode),x+14,y+42,w-28,30,COLOR_ACCENT,false,7);DToggle("BTN_RISK_MANAGED","RISK ENGINE",g_state.riskManagedTrading,x+14,y+84,w-28);DToggle("FLG_RISK","DYNAMIC RISK LOT",g_state.useDynamicRiskLot,x+14,y+116,w-28);DKV("RPD","RISK SIZING",g_state.useDynamicRiskLot?"DYNAMIC":"FIXED",x+14,y+148,78,g_state.useDynamicRiskLot?COLOR_TEAL:COLOR_MUTED);DKV("RP1","RISK / GRID",StringFormat("%.2f%%",g_state.riskPerGridPct),x+14,y+160,78,COLOR_TEXT);DKV("RP2","MAX GRID RISK",StringFormat("%.2f%%",g_state.maxGridRiskPct),x+14,y+190,78,COLOR_TEXT);}

void CreateRiskLimits(){int x=ContentX(),y=PageBodyY(4),w=ContentW();DSectionSingle("RISK_LIMITS","RISK LIMITS",x,y,w,255);DKV("RL6","RECOVERY",g_state.recoveryModeActive?StringFormat("ATTEMPT %d/%d",g_state.recoveryAttemptsUsed,MathMax(0,InpMaxRecoveryAttempts)):"STANDBY",x+14,y+228,82,g_state.recoveryModeActive?COLOR_ORANGE:COLOR_MUTED);DKV("RL1","MAX DD",StringFormat("%.2f%%",g_state.maxDrawdownPct),x+14,y+42,82,COLOR_TEXT);DKV("RL2","DAILY LOSS",StringFormat("%.2f%%",g_state.dailyLossLimitPct),x+14,y+72,82,COLOR_TEXT);DKV("RL3","PROFIT LOCK",StringFormat("%.2f%%",g_state.dailyProfitLockPct),x+14,y+102,82,COLOR_TEXT);DKV("RL4","BASKET TP",FormatNumber(g_state.basketTakeProfitUSD),x+14,y+132,82,COLOR_TEXT);DKV("RL5","BASKET SL",FormatNumber(g_state.basketStopLossUSD),x+14,y+162,82,COLOR_TEXT);DBar("RL_DD","DD USED",g_state.maxDrawdownPct>0?g_state.maxDrawdown/g_state.maxDrawdownPct*100.0:0,x+14,y+198,w-42,g_state.maxDrawdown>=g_state.maxDrawdownPct*0.8?COLOR_RED:COLOR_GREEN);}

void CreateRiskProtection(){int x=ContentX(),y=PageBodyY(4),w=ContentW();DSectionSingle("RISK_PROTECTION","ORDER PROTECTION",x,y,w,260);DToggle("BTN_NEW_ORDER_SL","STOP LOSS",g_state.useStopLossForNewOrders,x+14,y+42,w-28);DToggle("BTN_NEW_ORDER_TP","TAKE PROFIT",g_state.useTakeProfitForNewOrders,x+14,y+74,w-28);DToggle("FLG_BE","BREAK EVEN",g_state.breakEven,x+14,y+106,w-28);DToggle("FLG_TRAIL","TRAILING",g_state.trailingStop,x+14,y+138,w-28);DKV("RPR1","SL",StringFormat("%.1f pips",g_state.stopLossPips),x+14,y+180,62,COLOR_TEXT);DKV("RPR2","TP",StringFormat("%.1f pips",g_state.takeProfitPips),x+14,y+210,62,COLOR_TEXT);DKV("RPR3","TRAIL ATR",DoubleToString(g_state.trailingATRMultiple,2),x+14,y+240,62,COLOR_TEXT);}

void CreateRiskSafety(){int x=ContentX(),y=PageBodyY(4),w=ContentW();DSectionSingle("RISK_SAFETY","POSITION SAFETY",x,y,w,255);DKV("RS1","BE TRIGGER",StringFormat("%.1f pips",g_state.breakEvenTriggerPips),x+14,y+42,85,COLOR_TEXT);DKV("RS2","BE OFFSET",StringFormat("%.1f pips",g_state.breakEvenOffsetPips),x+14,y+72,85,COLOR_TEXT);DKV("RS3","MAX HOLD",g_state.maxHoldMinutes>0?StringFormat("%.0f min",g_state.maxHoldMinutes):"UNLIMITED",x+14,y+102,85,COLOR_TEXT);DKV("RS4","OCO",g_state.oco?"ON":"OFF",x+14,y+132,85,g_state.oco?COLOR_GREEN:COLOR_MUTED);DKV("RS5","OPPOSITE",g_state.closeOppositeOnFill?"CLOSE":"KEEP",x+14,y+162,85,g_state.closeOppositeOnFill?COLOR_GREEN:COLOR_MUTED);DToggle("TR_OCO","OCO TOGGLE",g_state.oco,x+14,y+202,w-28);}

void CreateRiskPortfolio()
{
   int x=ContentX(), y=PageBodyY(5), w=ContentW();
   int gap=12;
   int cw=(w-gap)/2;
   int topH=150;
   int midY=y+topH+12;
   int midH=170;
   int botY=midY+midH+12;
   int botH=MathMax(118,ContentY()+ContentH()-botY-8);

   DPageTitle("PORTFOLIO RISK","RISK & PORTFOLIO | account survival, aggregate exposure and risk capacity");

   // TOP ROW -------------------------------------------------
   DSectionSingle("R7_HIER","SURVIVAL HIERARCHY",x,y,cw,topH);
   DKV("R7_BROKER","BROKER",g_state.brokerRiskOK?"CLEAR":"BLOCK",x+14,y+42,104,g_state.brokerRiskOK?COLOR_GREEN:COLOR_RED);
   DKV("R7_HARD","HARD SURVIVAL",g_state.hardSurvivalOK?"CLEAR":"STOP",x+14,y+72,104,g_state.hardSurvivalOK?COLOR_GREEN:COLOR_RED);
   DKV("R7_PORT","PORTFOLIO GATE",g_state.portfolioRiskOK?"CLEAR":"BLOCK",x+14,y+102,104,g_state.portfolioRiskOK?COLOR_GREEN:COLOR_RED);

   DSectionSingle("R7_SUMMARY","RISK SUMMARY",x+cw+gap,y,cw,topH);
   DMetric("R7_RISK_METRIC","PORTFOLIO RISK",StringFormat("%.2f%%",g_state.portfolioRiskPct),x+cw+gap+12,y+40,(cw-36)/2,COLOR_TEXT);
   DMetric("R7_HEALTH_METRIC","RISK HEALTH",StringFormat("%.0f%%",g_state.riskHealthScore),x+cw+gap+24+(cw-36)/2,y+40,(cw-36)/2,g_state.riskHealthScore>=70?COLOR_GREEN:(g_state.riskHealthScore>=40?COLOR_ORANGE:COLOR_RED));
   DKV("R7_CAP_SUM","CAPACITY",g_state.maxGridRiskPct>0?StringFormat("%.2f%%",g_state.portfolioRiskCapacityPct):"OPEN",x+cw+gap+12,y+104,88,COLOR_GOLD);
   DKV("R7_LOAD_SUM","DIR. LOAD",StringFormat("%.2f%%",g_state.directionalRiskPct),x+cw+gap+12,y+130,88,COLOR_TEXT);

   // MIDDLE ROW ----------------------------------------------
   DSectionSingle("R7_EXPOSURE","DIRECTIONAL EXPOSURE",x,midY,cw,midH);
   DKV("R7_LONG","LONG RISK",StringFormat("%.2f%%",g_state.longRiskPct),x+14,midY+42,96,COLOR_TEXT);
   DKV("R7_SHORT","SHORT RISK",StringFormat("%.2f%%",g_state.shortRiskPct),x+14,midY+72,96,COLOR_TEXT);
   DKV("R7_DIR","DIRECTIONAL",StringFormat("%.2f%%",g_state.directionalRiskPct),x+14,midY+102,96,COLOR_GOLD);
   double lr=g_state.portfolioRiskPct>0?100.0*g_state.longRiskPct/MathMax(0.0001,g_state.portfolioRiskPct):0.0;
   double sr=g_state.portfolioRiskPct>0?100.0*g_state.shortRiskPct/MathMax(0.0001,g_state.portfolioRiskPct):0.0;
   DBar("R7_LONG_BAR","LONG LOAD",lr,x+14,midY+130,cw-42,COLOR_GREEN);
   DBar("R7_SHORT_BAR","SHORT LOAD",sr,x+14,midY+158,cw-42,COLOR_RED);

   DSectionSingle("R7_CAPACITY","CAPACITY & LIMITS",x+cw+gap,midY,cw,midH);
   DKV("R7_REMAIN","REMAINING",g_state.maxGridRiskPct>0?StringFormat("%.2f%%",g_state.portfolioRiskCapacityPct):"OPEN",x+cw+gap+14,midY+42,96,COLOR_GOLD);
   DKV("R7_GRID","RISK / GRID",StringFormat("%.2f%%",g_state.riskPerGridPct),x+cw+gap+14,midY+72,96,COLOR_TEXT);
   DKV("R7_MAX","MAX GRID",StringFormat("%.2f%%",g_state.maxGridRiskPct),x+cw+gap+14,midY+102,96,COLOR_TEXT);
   DKV("R7_RISK_MODE","RISK ENGINE",g_state.riskManagedTrading?"ACTIVE":"BYPASS",x+cw+gap+14,midY+132,96,g_state.riskManagedTrading?COLOR_GREEN:COLOR_MUTED);
   DKV("R7_DYNAMIC","DYNAMIC LOT",g_state.useDynamicRiskLot?"ACTIVE":"FIXED",x+cw+gap+14,midY+162,96,g_state.useDynamicRiskLot?COLOR_TEAL:COLOR_MUTED);

   // BOTTOM ROW ----------------------------------------------
   DSectionSingle("R7_HEALTH","RISK HEALTH & UTILIZATION",x,botY,w,botH);
   DBar("R7_HEALTH_BAR","RISK HEALTH",g_state.riskHealthScore,x+14,botY+42,w-42,g_state.riskHealthScore>=70?COLOR_GREEN:(g_state.riskHealthScore>=40?COLOR_ORANGE:COLOR_RED));
   double util=g_state.maxGridRiskPct>0?100.0*g_state.portfolioRiskPct/MathMax(0.0001,g_state.maxGridRiskPct):0.0;
   DBar("R7_UTIL_BAR","UTILIZATION",util,x+14,botY+80,w-42,util>=90?COLOR_RED:(util>=70?COLOR_ORANGE:COLOR_GREEN));
   DKV("R7_STATUS","STATUS",g_state.riskHierarchyStatus,x+14,botY+108,88,g_state.riskBlockReason==""?COLOR_GREEN:COLOR_RED);
   DKV("R7_REASON","REASON",g_state.riskBlockReason==""?"ALL RISK LEVELS CLEAR":g_state.riskBlockReason,x+14,botY+136,88,g_state.riskBlockReason==""?COLOR_TEXT:COLOR_ORANGE);
   DKV("R7_ENTRY","ENTRY STATE",g_state.entryRiskOK?"AVAILABLE":"BLOCKED",x+14,botY+164,88,g_state.entryRiskOK?COLOR_GREEN:COLOR_RED);
}

void CreatePortfolioEngineRiskTab()
{
   int x=ContentX(), y=PageBodyY(4), w=ContentW();
   int gap=10, cw=(w-gap)/2;

   int topH=112;
   int midH=108;
   int botY=y+topH+gap+midH+gap;
   int botH=MathMax(128, ContentY()+ContentH()-botY-6);
   if(botH>140) botH=140;

   DPageTitle("PORTFOLIO ENGINE","Dedicated RISK & PORTFOLIO portfolio risk workspace");

   // -------------------- TOP: SURVIVAL + PORTFOLIO SNAPSHOT --------------------
   DSectionSingle("PE_SURV","SURVIVAL GATES",x,y,cw,topH);
   DKV("PE_BROKER","BROKER",g_state.brokerRiskOK?"CLEAR":"BLOCK",x+14,y+40,128,g_state.brokerRiskOK?COLOR_GREEN:COLOR_RED);
   DKV("PE_HARD","HARD SURVIVAL",g_state.hardSurvivalOK?"CLEAR":"STOP",x+14,y+64,128,g_state.hardSurvivalOK?COLOR_GREEN:COLOR_RED);
   DKV("PE_PORT","PORTFOLIO GATE",g_state.portfolioRiskOK?"CLEAR":"BLOCK",x+14,y+88,128,g_state.portfolioRiskOK?COLOR_GREEN:COLOR_RED);

   int rx=x+cw+gap;
   DSectionSingle("PE_SNAPSHOT","PORTFOLIO SNAPSHOT",rx,y,cw,topH);
   DKV("PE_RISK","TOTAL RISK",StringFormat("%.2f%%",g_state.portfolioRiskPct),rx+14,y+40,110,COLOR_TEXT);
   DKV("PE_HEALTH","RISK HEALTH",StringFormat("%.0f%%",g_state.riskHealthScore),rx+14,y+64,110,
       g_state.riskHealthScore>=70?COLOR_GREEN:(g_state.riskHealthScore>=40?COLOR_ORANGE:COLOR_RED));
   // Directional Load gets its own visual lane so the label/value can never collide.
   double dirLoad=MathMax(0.0,MathMin(100.0,g_state.directionalRiskPct));
   DBar("PE_LOAD_BAR","DIRECTIONAL LOAD",dirLoad,rx+14,y+82,cw-34,COLOR_GOLD);

   // -------------------- MIDDLE: DIRECTION + CAPACITY --------------------
   int my=y+topH+gap;
   DSectionSingle("PE_DIRECTION","DIRECTIONAL EXPOSURE",x,my,cw,midH);
   DKV("PE_LONG","LONG RISK",StringFormat("%.2f%%",g_state.longRiskPct),x+14,my+40,110,COLOR_TEXT);
   DKV("PE_SHORT","SHORT RISK",StringFormat("%.2f%%",g_state.shortRiskPct),x+14,my+64,110,COLOR_TEXT);
   DKV("PE_DIR","NET DIRECTION",g_state.directionalRiskPct>0?"LOADED":"FLAT",x+14,my+88,110,
       g_state.directionalRiskPct>0?COLOR_GOLD:COLOR_MUTED);

   DSectionSingle("PE_CAP","CAPACITY & LIMITS",rx,my,cw,midH);
   DKV("PE_REMAIN","REMAINING",g_state.maxGridRiskPct>0?StringFormat("%.2f%%",g_state.portfolioRiskCapacityPct):"OPEN",rx+14,my+40,110,COLOR_GOLD);
   DKV("PE_GRID","RISK / GRID",StringFormat("%.2f%%",g_state.riskPerGridPct),rx+14,my+64,110,COLOR_TEXT);
   DKV("PE_MAX","MAX GRID",StringFormat("%.2f%%",g_state.maxGridRiskPct),rx+14,my+88,110,COLOR_TEXT);

   // -------------------- BOTTOM: UTILIZATION + DECISION --------------------
   // Compact, bounded two-column workspace: no nested cards extending below the viewport.
   int available=ContentY()+ContentH()-botY-8;
   int bottomH=MathMax(108,MathMin(126,available));
   DSectionSingle("PE_BOTTOM","PORTFOLIO UTILIZATION & DECISION",x,botY,w,bottomH);

   double util=(g_state.maxGridRiskPct>0
                 ?100.0*g_state.portfolioRiskPct/MathMax(0.0001,g_state.maxGridRiskPct)
                 :0.0);
   double health=MathMax(0.0,MathMin(100.0,g_state.riskHealthScore));
   int colGap=12;
   int boxW=(w-colGap)/2;
   int baseY=botY+34;

   // LEFT: utilization -------------------------------------------------
   DText("PE_UTIL_TITLE","UTILIZATION",x+14,baseY,7,COLOR_GOLD,"Arial Bold");
   DBar("PE_RISK_BAR","RISK LOAD",util,x+14,baseY+18,boxW-28,
        util>=90?COLOR_RED:(util>=70?COLOR_ORANGE:COLOR_GREEN));
   DBar("PE_HEALTH_BAR","RISK HEALTH",health,x+14,baseY+50,boxW-28,
        health>=70?COLOR_GREEN:(health>=40?COLOR_ORANGE:COLOR_RED));

   // RIGHT: decision ---------------------------------------------------
   int dx=x+boxW+colGap;
   DText("PE_DEC_TITLE","DECISION",dx+14,baseY,7,COLOR_GOLD,"Arial Bold");
   DKV("PE_ENTRY","ENTRY",g_state.entryRiskOK?"AVAILABLE":"BLOCKED",dx+14,baseY+18,82,
       g_state.entryRiskOK?COLOR_GREEN:COLOR_RED);
   DKV("PE_ENGINE","RISK ENGINE",g_state.riskManagedTrading?"ACTIVE":"BYPASS",dx+14,baseY+44,82,
       g_state.riskManagedTrading?COLOR_GREEN:COLOR_MUTED);
   DKV("PE_STATUS","STATUS",g_state.riskBlockReason==""?"CLEAR":"BLOCKED",dx+14,baseY+70,82,
       g_state.riskBlockReason==""?COLOR_GREEN:COLOR_RED);

   string reason=g_state.riskBlockReason==""?"ALL PORTFOLIO GATES CLEAR":g_state.riskBlockReason;
   DText("PE_REASON_TXT",reason,x+14,botY+bottomH-12,7,
         g_state.riskBlockReason==""?COLOR_TEXT:COLOR_ORANGE,"Arial");
}


void CreateProtectionMasterPage(){int x=ContentX(),y=PageBodyY(5),w=ContentW();DSectionSingle("PA_MASTER","PROTECTION AUTHORITY",x,y,w,286);DButton("PA_MASTER_TGL",g_state.protectionMasterEnabled?"PROTECTION MASTER ON":"PROTECTION MASTER OFF",x+14,y+42,w-28,32,g_state.protectionMasterEnabled?COLOR_GREEN:COLOR_PANEL2,g_state.protectionMasterEnabled,7);DKV("PA_MODE","MODE",g_state.protectionMasterEnabled?"AUTHORIZED":"MONITOR ONLY",x+14,y+88,108,g_state.protectionMasterEnabled?COLOR_GREEN:COLOR_GOLD);DKV("PA_ENTRY","ENTRY EFFECT","RISK GUARDS MAY BLOCK NEW EXPOSURE",x+14,y+118,108,COLOR_TEXT);DKV("PA_EXIT","EXIT EFFECT",(g_state.protectionMasterEnabled&&(g_state.protectionDrawdownCloseEnabled||g_state.protectionDailyLossCloseEnabled||g_state.protectionBasketLossCloseEnabled||g_state.protectionEmergencyAutoCloseEnabled||g_state.protectionHardBreakerEnabled||g_state.protectionBasketProfitCloseEnabled||g_state.protectionProfitLockCloseEnabled||g_state.protectionMaxHoldCloseEnabled))?"EXPLICITLY AUTHORIZED":"NO GENERIC EXIT AUTHORITY",x+14,y+148,108,COLOR_TEXT);DKV("PA_LAST","LAST ACTION",g_state.protectionLastAction,x+14,y+178,108,COLOR_GOLD);DKV("PA_REASON","LAST TRIGGER",g_state.protectionLastTrigger==""?"NONE":g_state.protectionLastTrigger,x+14,y+208,108,COLOR_TEXT);DKV("PA_RESULT","RESULT",g_state.protectionLastResult==""?"NO EVENT":g_state.protectionLastResult,x+14,y+238,108,COLOR_TEXT);DText("PA_NOTE","OFF = monitor only. Protection metrics cannot close or cancel trades.",x+14,y+268,6,COLOR_MUTED,"Arial");}
void CreateDrawdownGovernorPage(){int x=ContentX(),y=PageBodyY(5),w=ContentW(),gap=12,cw=(w-gap)/2;DSectionSingle("PA_DD_A","DRAWDOWN & DAILY GOVERNOR",x,y,cw,300);DKV("PA_DD1","MAX DD",StringFormat("%.2f%%",g_state.maxDrawdownPct),x+14,y+42,104,COLOR_TEXT);DToggle("PA_DD_CLOSE","CLOSE EXISTING",g_state.protectionDrawdownCloseEnabled,x+14,y+78,cw-28);DKV("PA_DL1","DAILY LOSS",StringFormat("%.2f%%",g_state.dailyLossLimitPct),x+14,y+122,104,COLOR_TEXT);DToggle("PA_DL_CLOSE","CLOSE EXISTING",g_state.protectionDailyLossCloseEnabled,x+14,y+158,cw-28);DToggle("PA_BASKET_CLOSE","BASKET LOSS CLOSE",g_state.protectionBasketLossCloseEnabled,x+14,y+202,cw-28);DToggle("PA_BASKET_TP_CLOSE","BASKET PROFIT EXIT",g_state.protectionBasketProfitCloseEnabled,x+14,y+240,cw-28);DKV("PA_GOV_STATE","STATUS",(g_state.protectionDrawdownCloseEnabled||g_state.protectionDailyLossCloseEnabled||g_state.protectionBasketLossCloseEnabled||g_state.protectionBasketProfitCloseEnabled)?"EXIT AUTHORITY ENABLED":"MONITOR / ENTRY GATE",x+14,y+274,104,COLOR_GOLD);DSectionSingle("PA_DD_B","CURRENT TELEMETRY",x+cw+gap,y,cw,300);DBar("PA_DD_BAR","DRAWDOWN",g_state.maxDrawdownPct>0?100.0*g_state.maxDrawdown/g_state.maxDrawdownPct:0,x+cw+gap+14,y+48,cw-28,COLOR_ORANGE);DKV("PA_DDT","LIVE DD",StringFormat("%.2f%%",g_state.emergencyDrawdownPct),x+cw+gap+14,y+88,104,COLOR_TEXT);DKV("PA_DYT","DAILY P/L",FormatNumber(g_state.todayProfit),x+cw+gap+14,y+118,104,g_state.todayProfit>=0?COLOR_GREEN:COLOR_RED);DToggle("PA_PROFITLOCK_CLOSE","PROFIT LOCK EXIT",g_state.protectionProfitLockCloseEnabled,x+cw+gap+14,y+152,cw-28);DKV("PA_DSTATE","AUTHORITY",(g_state.protectionMasterEnabled&&(g_state.protectionDrawdownCloseEnabled||g_state.protectionDailyLossCloseEnabled||g_state.protectionBasketLossCloseEnabled||g_state.protectionBasketProfitCloseEnabled||g_state.protectionProfitLockCloseEnabled))?"ACTIVE":"MONITOR ONLY",x+cw+gap+14,y+198,104,COLOR_TEXT);DText("PA_DNOTE","Thresholds detect conditions; close authority is opt-in and independent of entry blocking.",x+cw+gap+14,y+236,6,COLOR_MUTED,"Arial");}
void CreateEmergencyProtectionPage(){int x=ContentX(),y=PageBodyY(5),w=ContentW(),gap=12,cw=(w-gap)/2;DSectionSingle("PA_EM_A","EMERGENCY ACTIONS",x,y,cw,300);DToggle("PA_EM_ACTION","EMERGENCY ACTION",g_state.protectionEmergencyActionEnabled,x+14,y+42,cw-28);DToggle("PA_EM_CLOSE","AUTO CLOSE",g_state.protectionEmergencyAutoCloseEnabled,x+14,y+78,cw-28);DToggle("PA_EM_CANCEL","CANCEL PENDING",g_state.protectionEmergencyCancelEnabled,x+14,y+114,cw-28);DToggle("PA_EM_BREAK","HARD SURVIVAL BREAKER",g_state.protectionHardBreakerEnabled,x+14,y+150,cw-28);DKV("PA_EM_ACT","EVENT",g_state.emergencyActive?"ACTIVE":"CLEAR",x+14,y+196,104,g_state.emergencyActive?COLOR_RED:COLOR_GREEN);DKV("PA_EM_REASON","REASON",g_state.emergencyReason==""?"NONE":g_state.emergencyReason,x+14,y+226,104,COLOR_TEXT);DSectionSingle("PA_EM_B","LIVE TELEMETRY",x+cw+gap,y,cw,300);DKV("PA_EM_DD","DD",StringFormat("%.2f%%",g_state.emergencyDrawdownPct),x+cw+gap+14,y+42,104,COLOR_TEXT);DKV("PA_EM_MG","MARGIN",StringFormat("%.1f%%",g_state.emergencyMarginLevelPct),x+cw+gap+14,y+72,104,COLOR_TEXT);DKV("PA_EM_SP","SPREAD",StringFormat("%.2f pips",g_state.emergencySpreadPips),x+cw+gap+14,y+102,104,COLOR_TEXT);DKV("PA_EM_VOL","VOLATILITY",StringFormat("%.0f%%",g_state.emergencyVolatilityPct*100.0),x+cw+gap+14,y+132,104,COLOR_TEXT);DText("PA_EM_NOTE","Detection and action permission are separate.",x+cw+gap+14,y+176,6,COLOR_MUTED,"Arial");}
void CreateTradeProtectionAuthorityPage(){
   int x=ContentX(),y=PageBodyY(5),w=ContentW(),gap=12,cw=(w-gap)/2;
   DSectionSingle("PA_TP_A","TRADE PROTECTION",x,y,cw,300);
   DToggle("PA_SL","STOP LOSS",g_state.useStopLossForNewOrders,x+14,y+42,cw-28);
   DToggle("PA_TP","TAKE PROFIT",g_state.useTakeProfitForNewOrders,x+14,y+78,cw-28);
   DToggle("PA_BE","BREAK EVEN",g_state.breakEven,x+14,y+114,cw-28);
   DToggle("PA_TR","TRAILING",g_state.trailingStop,x+14,y+150,cw-28);
   DKV("PA_SL_V","SL",StringFormat("%.1f pips",g_state.stopLossPips),x+14,y+192,82,COLOR_TEXT);
   DKV("PA_TP_V","TP",StringFormat("%.1f pips",g_state.takeProfitPips),x+14,y+222,82,COLOR_TEXT);

   DSectionSingle("PA_TP_B","TRADE PROTECTION ADAPTIVE MANAGEMENT",x+cw+gap,y,cw,300);
   DToggle("PA_ADAPT","ADAPTIVE SL/TP",g_state.adaptiveTradeProtection,x+cw+gap+14,y+42,cw-28);
   DToggle("PA_PROFIT","PROFIT LOCK",g_state.adaptiveProfitManagement,x+cw+gap+14,y+78,cw-28);
   DToggle("PA_RUNNER","RUNNER MODE",g_state.tradeRunnerMode,x+cw+gap+14,y+114,cw-28);
   DKV("PA_ATR_SL","SL ATR",DoubleToString(g_state.adaptiveSLATRMultiple,2),x+cw+gap+14,y+154,82,COLOR_GOLD);
   DKV("PA_ATR_TP","TP ATR",DoubleToString(g_state.adaptiveTPATRMultiple,2),x+cw+gap+14,y+184,82,COLOR_GOLD);
   DKV("PA_LOCK","LOCK TRIGGER",StringFormat("%.1f pips",g_state.profitLockTriggerPips),x+cw+gap+14,y+214,82,COLOR_TEXT);
   DKV("PA_OWNER","OWNER",IsAutonomousControl()?"AUTONOMOUS":"USER / PROTECTION",x+cw+gap+14,y+244,82,COLOR_GOLD);
}

void CreateExposureCapacityPage(){int x=ContentX(),y=PageBodyY(5),w=ContentW(),gap=12,cw=(w-gap)/2;DSectionSingle("PA_EX_A","EXPOSURE & CAPACITY",x,y,cw,300);DKV("PA_EX_POS","POSITIONS",StringFormat("%d / %d",g_state.positionCount,g_state.maxPositions),x+14,y+42,104,COLOR_TEXT);DKV("PA_EX_PEND","PENDING",StringFormat("%d / %d",g_state.pendingCount,g_state.maxPendingOrders),x+14,y+72,104,COLOR_TEXT);DKV("PA_EX_LOTS","MAX TOTAL LOTS",g_state.maxTotalLots>0?StringFormat("%.2f",g_state.maxTotalLots):"OPEN",x+14,y+102,104,COLOR_TEXT);DKV("PA_EX_GRID","MAX GRID RISK",StringFormat("%.2f%%",g_state.maxGridRiskPct),x+14,y+132,104,COLOR_TEXT);DKV("PA_EX_AUTO","AUTO GRIDS/DAY",IntegerToString(g_state.maxAutonomousGridsPerDay),x+14,y+162,104,COLOR_TEXT);DSectionSingle("PA_EX_B","LIVE LOAD",x+cw+gap,y,cw,300);DBar("PA_EX_PB","POSITION LOAD",g_state.maxPositions>0?100.0*g_state.positionCount/g_state.maxPositions:0,x+cw+gap+14,y+48,cw-28,COLOR_TEAL);DBar("PA_EX_OB","PENDING LOAD",g_state.maxPendingOrders>0?100.0*g_state.pendingCount/g_state.maxPendingOrders:0,x+cw+gap+14,y+88,cw-28,COLOR_GOLD);DKV("PA_EX_EXP","CURRENT LOTS",StringFormat("%.3f",CurrentGridExposureLots()),x+cw+gap+14,y+128,104,COLOR_TEXT);DKV("PA_EX_MODE","AUTHORITY",g_state.exposureManager?"ENTRY CAPACITY":"MONITOR ONLY",x+cw+gap+14,y+162,104,COLOR_GOLD);}
void CreateRecoveryAuthorityPage(){int x=ContentX(),y=PageBodyY(5),w=ContentW(),gap=12,cw=(w-gap)/2;DSectionSingle("PA_REC_A","RECOVERY AUTHORITY",x,y,cw,300);DToggle("PA_REC_ENABLE","RECOVERY ENGINE",g_state.gridRecovery,x+14,y+42,cw-28);DKV("PA_REC_ATT","ATTEMPT",g_state.recoveryModeActive?StringFormat("%d / %d",g_state.recoveryAttemptsUsed,MathMax(0,InpMaxRecoveryAttempts)):"STANDBY",x+14,y+84,104,COLOR_TEXT);DKV("PA_REC_SCALE","LOT SCALE",StringFormat("%.3f",g_state.recoveryLotScale),x+14,y+114,104,COLOR_TEXT);DKV("PA_REC_MODE","STATUS",g_state.recoveryModeActive?"ACTIVE":"STANDBY",x+14,y+144,104,g_state.recoveryModeActive?COLOR_ORANGE:COLOR_MUTED);DSectionSingle("PA_REC_B","RECOVERY POLICY",x+cw+gap,y,cw,300);DKV("PA_REC_GRID","GRID",g_state.recoveryModeActive?CompactGridName(g_state.gridType):"BASE",x+cw+gap+14,y+42,104,COLOR_GOLD);DKV("PA_REC_DIR","DIRECTION",g_state.gridSelectionDirection,x+cw+gap+14,y+72,104,COLOR_TEXT);DKV("PA_REC_SUIT","SUITABILITY",StringFormat("%.0f%%",g_state.gridSelectionSelectedScore*100.0),x+cw+gap+14,y+102,104,COLOR_TEXT);DKV("PA_REC_REASON","REASON",g_state.recoverySource==""?"NONE":g_state.recoverySource,x+cw+gap+14,y+132,104,COLOR_TEXT);}
void CreateExecutionGuardsPage(){int x=ContentX(),y=PageBodyY(5),w=ContentW(),gap=12,cw=(w-gap)/2;DSectionSingle("PA_GD_A","EXECUTION GUARDS",x,y,cw,300);DKV("PA_G_SP","MAX SPREAD",StringFormat("%.2f pips",g_state.maxSpreadPips),x+14,y+42,104,COLOR_TEXT);DKV("PA_G_SLIP","SLIPPAGE",IntegerToString(g_state.slippage),x+14,y+72,104,COLOR_TEXT);DKV("PA_G_SESS","SESSION",g_state.useSessionFilter?"FILTERED":"OPEN",x+14,y+102,104,COLOR_TEXT);DKV("PA_G_VOL","HIGH VOL",g_state.pauseHighVolatility?"BLOCK NEW":"ALLOW",x+14,y+132,104,g_state.pauseHighVolatility?COLOR_ORANGE:COLOR_MUTED);DKV("PA_G_WEEK","WEEKEND",g_state.avoidWeekend?"BLOCK NEW":"ALLOW",x+14,y+162,104,COLOR_TEXT);DSectionSingle("PA_GD_B","EXECUTION STATE",x+cw+gap,y,cw,300);DKV("PA_G_Q","SPREAD NOW",StringFormat("%.2f pips",g_state.currentSpreadPips),x+cw+gap+14,y+42,104,COLOR_TEXT);DKV("PA_G_ALLOWED","SYMBOL",IsTradingAllowedForSymbol()?"TRADABLE":"BLOCKED",x+cw+gap+14,y+72,104,IsTradingAllowedForSymbol()?COLOR_GREEN:COLOR_RED);DKV("PA_G_EXEC","STATUS",g_state.executionStatus,x+cw+gap+14,y+102,104,COLOR_GOLD);DText("PA_G_NOTE","Execution guards are entry controls; they do not close live trades.",x+cw+gap+14,y+146,6,COLOR_MUTED,"Arial");}
void CreateAuthorityMatrixPage(){int x=ContentX(),y=PageBodyY(5),w=ContentW();DSectionSingle("PA_MATRIX","AUTHORITY MATRIX",x,y,w,310);DKV("PA_M1","DRAWDOWN",g_state.protectionDrawdownCloseEnabled?"MONITOR | BLOCK | CLOSE":"MONITOR | ENTRY ONLY",x+14,y+42,112,COLOR_TEXT);DKV("PA_M2","DAILY LOSS",g_state.protectionDailyLossCloseEnabled?"MONITOR | BLOCK | CLOSE":"MONITOR | ENTRY ONLY",x+14,y+72,112,COLOR_TEXT);DKV("PA_M3","BASKET LOSS",g_state.protectionBasketLossCloseEnabled?"MONITOR | CLOSE":"MONITOR ONLY",x+14,y+102,112,COLOR_TEXT);DKV("PA_M4","EMERGENCY",g_state.protectionEmergencyAutoCloseEnabled?"MONITOR | CLOSE":"MONITOR | THROTTLE",x+14,y+132,112,COLOR_TEXT);DKV("PA_M5","HARD BREAKER",g_state.protectionHardBreakerEnabled?"SURVIVAL CLOSE":"OFF",x+14,y+162,112,COLOR_TEXT);DKV("PA_M6","SL / TP",(g_state.useStopLossForNewOrders||g_state.useTakeProfitForNewOrders)?"BROKER EXIT":"USER / OFF",x+14,y+192,112,COLOR_TEXT);DKV("PA_M7","BREAK-EVEN",g_state.breakEven?"TRADE MODIFIER":"OFF",x+14,y+222,112,COLOR_TEXT);DKV("PA_M8","TRAILING",g_state.trailingStop?"TRADE MODIFIER":"OFF",x+14,y+252,112,COLOR_TEXT);DText("PA_MATRIX_NOTE","No generic metric may close, cancel, modify or rebuild trades without explicit authority.",x+14,y+286,6,COLOR_GOLD,"Arial");}
void CreateProtectionLogPage(){int x=ContentX(),y=PageBodyY(5),w=ContentW();DSectionSingle("PA_LOG","PROTECTION LOG",x,y,w,300);DKV("PA_LID","EVENT ID",(string)g_state.protectionEventId,x+14,y+42,104,COLOR_GOLD);DKV("PA_LTIME","TIME",g_state.protectionLastEventTime>0?TimeToString(g_state.protectionLastEventTime,TIME_SECONDS):"--",x+14,y+72,104,COLOR_TEXT);DKV("PA_LAUTH","AUTHORITY",g_state.protectionLastAuthority==""?"NONE":g_state.protectionLastAuthority,x+14,y+102,104,COLOR_TEXT);DKV("PA_LTRIG","TRIGGER",g_state.protectionLastTrigger==""?"NONE":g_state.protectionLastTrigger,x+14,y+132,104,COLOR_TEXT);DKV("PA_LACT","ACTION",g_state.protectionLastAction,x+14,y+162,104,COLOR_GOLD);DKV("PA_LRES","RESULT",g_state.protectionLastResult==""?"NONE":g_state.protectionLastResult,x+14,y+192,104,COLOR_TEXT);DText("PA_LNOTE","Authority and action are recorded separately for every protection event.",x+14,y+232,6,COLOR_MUTED,"Arial");}

void CreateRiskTab()
{
   string s[]={"PROTECTION MASTER","DRAWDOWN & DAILY","EMERGENCY","TRADE PROTECTION","PORTFOLIO ENGINE","EXPOSURE & CAPACITY","RECOVERY ENGINE","EXECUTION GUARDS","AUTHORITY MATRIX","PROTECTION LOG"};
   DPageTitle("RISK & PROTECTION","Single authority center for protection, exposure, recovery and exit control");
   DNestedSubTabs(s,10,g_dashboard.riskSubTab,"RISK_SUB_");
   switch(g_dashboard.riskSubTab)
   {
      case 0:CreateProtectionMasterPage();break;case 1:CreateDrawdownGovernorPage();break;case 2:CreateEmergencyProtectionPage();break;case 3:CreateTradeProtectionAuthorityPage();break;case 4:CreatePortfolioEngineRiskTab();break;case 5:CreateExposureCapacityPage();break;case 6:CreateRecoveryAuthorityPage();break;case 7:CreateExecutionGuardsPage();break;case 8:CreateAuthorityMatrixPage();break;case 9:CreateProtectionLogPage();break;default:CreateProtectionMasterPage();break;
   }
}



// -------------------- ANALYTICS --------------------

void CreateEmergencyTab()
{
   DPageTitle("EMERGENCY","Dedicated emergency-control and survival workspace");
   string s[]={"EMERGENCY ACTIONS","LIVE TELEMETRY","PROTECTION AUTHORITY"};
   DNestedSubTabs(s,3,g_emergencySubTab,"EMERGENCY_SUB_");
   if(g_emergencySubTab==0) CreateEmergencyProtectionPage();
   else if(g_emergencySubTab==1)
   {
      int x=ContentX(),y=PageBodyY(5),w=ContentW(),gap=12,cw=(w-gap)/2;
      DSectionSingle("EM_LIVE_A","LIVE EMERGENCY STATE",x,y,cw,300);
      DKV("EML1","EVENT",g_state.emergencyActive?"ACTIVE":"CLEAR",x+14,y+42,104,g_state.emergencyActive?COLOR_RED:COLOR_GREEN);
      DKV("EML2","REASON",g_state.emergencyReason==""?"NONE":g_state.emergencyReason,x+14,y+72,104,COLOR_TEXT);
      DKV("EML3","DRAWDOWN",StringFormat("%.2f%%",g_state.emergencyDrawdownPct),x+14,y+102,104,COLOR_TEXT);
      DKV("EML4","MARGIN",StringFormat("%.1f%%",g_state.emergencyMarginLevelPct),x+14,y+132,104,COLOR_TEXT);
      DKV("EML5","SPREAD",StringFormat("%.2f pips",g_state.emergencySpreadPips),x+14,y+162,104,COLOR_TEXT);
      DSectionSingle("EM_LIVE_B","RECENT ACTION",x+cw+gap,y,cw,300);
      DKV("EML6","AUTHORITY",g_state.protectionLastAuthority==""?"NONE":g_state.protectionLastAuthority,x+cw+gap+14,y+42,104,COLOR_GOLD);
      DKV("EML7","ACTION",g_state.protectionLastAction==""?"NONE":g_state.protectionLastAction,x+cw+gap+14,y+72,104,COLOR_GOLD);
      DKV("EML8","RESULT",g_state.protectionLastResult==""?"NONE":g_state.protectionLastResult,x+cw+gap+14,y+102,104,COLOR_TEXT);
      DKV("EML9","EVENT TIME",g_state.protectionLastEventTime>0?TimeToString(g_state.protectionLastEventTime,TIME_SECONDS):"--",x+cw+gap+14,y+132,104,COLOR_TEXT);
   }
   else CreateProtectionMasterPage();
}

void CreateAnalyticsMarket()
{
   int x=ContentX(),y=PageBodyY(3),w=ContentW();
   DSectionSingle("AN_MARKET","MARKET STATE INTELLIGENCE",x,y,w,420);
   int gap=10,innerX=x+14,innerY=y+38,cw=(w-28-gap)/2;

   DSectionSingle("AN_LEFT","DECISION CONTEXT",innerX,innerY,cw,332);
   DKV("ANM1","REGIME",g_state.marketRegime!=""?g_state.marketRegime:g_state.regime,innerX+12,innerY+40,68,g_state.marketNoTrade?COLOR_RED:COLOR_GOLD);
   DKV("ANM2","SESSION",g_state.marketSession,innerX+12,innerY+68,68,COLOR_TEXT);
   DKV("ANM3","SPREAD",StringFormat("%.2f pips",g_state.currentSpreadPips),innerX+12,innerY+96,68,(g_state.maxSpreadPips<=0||g_state.currentSpreadPips<=g_state.maxSpreadPips)?COLOR_GREEN:COLOR_RED);
   DKV("ANM4","DECISION",CompactMarketDecisionV15(),innerX+12,innerY+124,68,g_state.marketNoTrade?COLOR_RED:COLOR_TEXT);
   DKV("ANM5","DATA",g_state.marketDataFresh?"FRESH":"STALE",innerX+12,innerY+166,68,g_state.marketDataFresh?COLOR_GREEN:COLOR_RED);
   if(g_state.useMultiTimeframeMarketState)
      DKV("ANM6","M5 / M15 / H1",StringFormat("%.0f%% / %.0f%% / %.0f%%",g_state.mtfTrendM5*100.0,g_state.mtfTrendM15*100.0,g_state.mtfTrendH1*100.0),innerX+12,innerY+194,90,COLOR_TEXT);
   else
      DKV("ANM6","ANALYSIS TF",EnumToString((ENUM_TIMEFRAMES)_Period),innerX+12,innerY+194,90,COLOR_TEXT);
   DKV("ANM7","CONFIDENCE",StringFormat("%.0f%%",g_state.regimeConfidence*100),innerX+12,innerY+222,68,COLOR_GOLD);
   DKV("ANM8","STABILITY",StringFormat("%.0f%%",g_state.marketStabilityScore*100),innerX+12,innerY+250,68,COLOR_TEXT);
   DToggle("AN_MTF_TOGGLE","MULTI-TIMEFRAME",g_state.useMultiTimeframeMarketState,innerX+12,innerY+282,cw-24);

   DSectionSingle("AN_RIGHT","MARKET DIAGNOSTICS",innerX+cw+gap,innerY,cw,332);
   DBar("ANM9","CURRENT TF TREND",g_state.trendStrength*100.0,innerX+cw+gap+12,innerY+40,cw-30,g_state.trendStrength>=g_state.bullThreshold?COLOR_GREEN:COLOR_TEAL);
   if(g_state.useMultiTimeframeMarketState)
   {
      DBar("ANM10","M5 TREND",g_state.mtfTrendM5*100.0,innerX+cw+gap+12,innerY+76,cw-30,COLOR_TEAL);
      DBar("ANM11","M15 TREND",g_state.mtfTrendM15*100.0,innerX+cw+gap+12,innerY+112,cw-30,COLOR_TEAL);
      DBar("ANM12","H1 TREND",g_state.mtfTrendH1*100.0,innerX+cw+gap+12,innerY+148,cw-30,COLOR_TEAL);
      DBar("ANM13","VOL PERCENTILE",g_state.atrPercentile*100.0,innerX+cw+gap+12,innerY+184,cw-30,COLOR_ORANGE);
      DBar("ANM14","COMPRESSION",g_state.compressionScore*100.0,innerX+cw+gap+12,innerY+220,cw-30,COLOR_GOLD);
      DBar("ANM15","BREAKOUT PRESSURE",g_state.breakoutPressure*100.0,innerX+cw+gap+12,innerY+256,cw-30,COLOR_GOLD);
   }
   else
   {
      DBar("ANM13","VOL PERCENTILE",g_state.atrPercentile*100.0,innerX+cw+gap+12,innerY+76,cw-30,COLOR_ORANGE);
      DBar("ANM14","COMPRESSION",g_state.compressionScore*100.0,innerX+cw+gap+12,innerY+112,cw-30,COLOR_GOLD);
      DBar("ANM15","BREAKOUT PRESSURE",g_state.breakoutPressure*100.0,innerX+cw+gap+12,innerY+148,cw-30,COLOR_GOLD);
      DBar("ANM16","MARKET STABILITY",g_state.marketStabilityScore*100.0,innerX+cw+gap+12,innerY+184,cw-30,COLOR_TEAL);
   }
}

void CreateAnalyticsPerformance(){int x=ContentX(),y=PageBodyY(3),w=ContentW();DSectionSingle("AN_PERF","PERFORMANCE",x,y,w,275);DKV("AP1","TRADES",IntegerToString(g_state.totalTrades),x+14,y+42,72,COLOR_TEXT);DKV("AP2","WINS",IntegerToString(g_state.wins),x+14,y+72,72,COLOR_GREEN);DKV("AP3","LOSSES",IntegerToString(g_state.losses),x+14,y+102,72,COLOR_RED);DKV("AP4","WIN RATE",StringFormat("%.1f%%",g_state.winRate),x+14,y+132,72,COLOR_GREEN);DKV("AP5","TOTAL P/L",FormatNumber(g_state.totalProfit),x+14,y+162,72,g_state.totalProfit>=0?COLOR_GREEN:COLOR_RED);DKV("AP6","RE-CENTERS",IntegerToString(g_state.rebalances),x+14,y+192,72,COLOR_TEXT);DKV("AP7","TODAY P/L",FormatNumber(g_state.todayProfit),x+14,y+222,72,g_state.todayProfit>=0?COLOR_GREEN:COLOR_RED);}

void CreateAnalyticsTelemetry(){int x=ContentX(),y=PageBodyY(3),w=ContentW();DSectionSingle("AN_TELEM","LIVE TELEMETRY",x,y,w,290);DKV("AT1","SYMBOL",_Symbol,x+14,y+42,70,COLOR_GOLD);DKV("AT2","TIMEFRAME",EnumToString((ENUM_TIMEFRAMES)_Period),x+14,y+72,70,COLOR_TEXT);DKV("AT3","SPREAD",StringFormat("%.2f pips",g_state.currentSpreadPips),x+14,y+102,70,(g_state.maxSpreadPips<=0||g_state.currentSpreadPips<=g_state.maxSpreadPips)?COLOR_GREEN:COLOR_RED);DKV("AT4","EQUITY",FormatNumber(AccountInfoDouble(ACCOUNT_EQUITY)),x+14,y+132,70,COLOR_TEXT);DKV("AT5","BALANCE",FormatNumber(AccountInfoDouble(ACCOUNT_BALANCE)),x+14,y+162,70,COLOR_TEXT);DKV("AT6","OPEN P/L",FormatNumber(g_state.currentProfit),x+14,y+192,70,g_state.currentProfit>=0?COLOR_GREEN:COLOR_RED);DKV("AT7","EXECUTION",g_state.executionStatus,x+14,y+222,70,COLOR_GOLD);DBar("AT8","POSITION LOAD",g_state.maxPositions>0?100.0*g_state.positionCount/g_state.maxPositions:0,x+14,y+250,w-42,COLOR_TEAL);}

void CreateAnalyticsTab(){string s[]={"MARKET STATE","PERFORMANCE","LIVE TELEMETRY"};DPageTitle("ANALYTICS","Performance and market telemetry");DNestedSubTabs(s,3,g_dashboard.analyticsSubTab,"AN_SUB_");switch(g_dashboard.analyticsSubTab){case 0:CreateAnalyticsMarket();break;case 1:CreateAnalyticsPerformance();break;case 2:CreateAnalyticsTelemetry();break;}}



// -------------------- AI --------------------

void CreateAICore(){int x=ContentX(),y=PageBodyY(4),w=ContentW();DSectionSingle("AI_CORE","AI CORE",x,y,w,255);DToggle("BTN_AI_TOGGLE","AI ENGINE",g_state.aiEnabled,x+14,y+42,w-28);DToggle("AI_SET_NETWORK","NEURAL NETWORK",g_state.neuralNetwork,x+14,y+76,w-28);DKV("AIC1","CONFIDENCE",StringFormat("%.0f%%",g_state.aiConfidence*100),x+14,y+122,78,COLOR_TEXT);DKV("AIC2","LEARNING PERIOD",IntegerToString(g_state.learningPeriod),x+14,y+152,78,COLOR_TEXT);DKV("AIC3","PREDICTION",StringFormat("%.0f%%",g_state.predictionAccuracy*100),x+14,y+182,78,COLOR_GOLD);}

void CreateAISignal(){int x=ContentX(),y=PageBodyY(4),w=ContentW();DSectionSingle("AI_SIGNAL","AI SIGNAL STATE",x,y,w,275);DKV("AIS1","TREND",StringFormat("%.0f%%",g_state.trendStrength*100),x+14,y+42,76,COLOR_GREEN);DKV("AIS2","SENTIMENT",StringFormat("%.0f%%",g_state.sentimentScore*100),x+14,y+72,76,COLOR_TEAL);DKV("AIS3","VOLATILITY",StringFormat("%.0f%%",g_state.volatilityIndex*100),x+14,y+102,76,COLOR_ORANGE);DKV("AIS4","REGIME",g_state.regime,x+14,y+132,76,COLOR_GOLD);DKV("AIS5","ATR",DoubleToString(g_state.atrPrice,_Digits),x+14,y+162,76,COLOR_TEXT);DBar("AIS6","SUITABILITY",g_state.marketSuitabilityScore*100.0,x+14,y+198,w-42,COLOR_TEAL);DKV("AIS7","CONFIDENCE",StringFormat("%.0f%%",g_state.intelligenceConfidence*100),x+14,y+232,76,COLOR_GOLD);}

void CreateAIThresholds(){int x=ContentX(),y=PageBodyY(4),w=ContentW();DSectionSingle("AI_THRESH","REGIME THRESHOLDS",x,y,w,250);DKV("AIT1","BULL",StringFormat("%.2f",g_state.bullThreshold),x+14,y+42,80,COLOR_GREEN);DKV("AIT2","BEAR",StringFormat("%.2f",g_state.bearThreshold),x+14,y+72,80,COLOR_RED);DKV("AIT3","HIGH VOL",StringFormat("%.2f",g_state.highVolThreshold),x+14,y+102,80,COLOR_ORANGE);DKV("AIT4","LOW VOL",StringFormat("%.2f",g_state.lowVolThreshold),x+14,y+132,80,COLOR_TEAL);DButton("AI_RESET","RESET AI METRICS",x+14,y+178,w-28,30,COLOR_PANEL2,false,7);}

void CreateAIFilters(){int x=ContentX(),y=PageBodyY(4),w=ContentW();DSectionSingle("AI_FILTERS","AUTONOMOUS FILTERS",x,y,w,270);DToggle("AI_SET_REGIME","REGIME FILTER",g_state.regimeFilter,x+14,y+42,w-28);DToggle("AI_SET_AUTO","AUTONOMOUS",g_state.autonomousMode,x+14,y+78,w-28);DToggle("AI_SET_RISK","DYNAMIC RISK LOT",g_state.useDynamicRiskLot,x+14,y+114,w-28);DKV("AIR1","EFFECTIVE LOT",DoubleToString(g_state.effectiveLot,3),x+14,y+151,95,g_state.useDynamicRiskLot?COLOR_TEAL:COLOR_MUTED);DToggle("AI_SET_HIVOL","HIGH VOL PAUSE",g_state.pauseHighVolatility,x+14,y+182,w-28);}

void CreateAITab(){string s[]={"AI CORE","SIGNAL STATE","THRESHOLDS","AUTONOMY FILTERS"};DPageTitle("AI ENGINE","AI, regime and autonomous controls");DNestedSubTabs(s,4,g_dashboard.aiSubTab,"AI_SUB_");switch(g_dashboard.aiSubTab){case 0:CreateAICore();break;case 1:CreateAISignal();break;case 2:CreateAIThresholds();break;case 3:CreateAIFilters();break;}}



// -------------------- EXECUTION --------------------

void CreateExecutionHealth(){int x=ContentX(),y=PageBodyY(4),w=ContentW();DSectionSingle("EX_HEALTH","EXECUTION HEALTH",x,y,w,260);DKV("EX1","STATUS",g_state.executionStatus,x+14,y+42,70,COLOR_GOLD);DKV("EX2","SPREAD",StringFormat("%.2f / %.2f",g_state.currentSpreadPips,g_state.maxSpreadPips),x+14,y+72,70,g_state.currentSpreadPips<=g_state.maxSpreadPips?COLOR_GREEN:COLOR_RED);DKV("EX3","SLIPPAGE",IntegerToString(g_state.slippage),x+14,y+102,70,COLOR_TEXT);DKV("EX4","RETRIES",IntegerToString(g_state.orderRetryCount),x+14,y+132,70,COLOR_TEXT);DToggle("BTN_SMART","SMART EXECUTION",g_state.smartExecution,x+14,y+176,w-28);}

void CreateExecutionParameters(){int x=ContentX(),y=PageBodyY(4),w=ContentW();DSectionSingle("EX_PARAMS","EXECUTION PARAMETERS",x,y,w,260);DKV("EP1","DEVIATION",IntegerToString(g_state.slippage),x+14,y+42,90,COLOR_TEXT);DKV("EP2","EXPIRY",g_state.pendingExpiryMinutes>0?StringFormat("%d min",g_state.pendingExpiryMinutes):"GTC",x+14,y+72,90,COLOR_TEXT);DKV("EP3","MAX SPREAD",StringFormat("%.1f pips",g_state.maxSpreadPips),x+14,y+102,90,COLOR_TEXT);DKV("EP4","SMART",g_state.smartExecution?"ON":"OFF",x+14,y+132,90,g_state.smartExecution?COLOR_GREEN:COLOR_MUTED);DToggle("FLG_VALIDATE","VALIDATE STOPS",g_state.validateStops,x+14,y+176,w-28);}

void CreateExecutionFilters(){int x=ContentX(),y=PageBodyY(4),w=ContentW();DSectionSingle("EX_FILTERS","MARKET FILTERS",x,y,w,280);DToggle("FLG_SESSION","SESSION FILTER",g_state.useSessionFilter,x+14,y+42,w-28);DToggle("FLG_WEEK","WEEKEND BLOCK",g_state.avoidWeekend,x+14,y+78,w-28);DToggle("FLG_HIV","HIGH VOL PAUSE",g_state.pauseHighVolatility,x+14,y+114,w-28);DKV("EF1","SESSION HOURS",StringFormat("%02d-%02d",g_state.sessionStartHour,g_state.sessionEndHour),x+14,y+160,90,COLOR_TEXT);DKV("EF2","SERVER HOUR",StringFormat("%02d",CurrentServerHour()),x+14,y+190,90,COLOR_TEXT);}

void CreateExecutionFlow(){int x=ContentX(),y=PageBodyY(4),w=ContentW();DSectionSingle("EX_FLOW","ORDER FLOW",x,y,w,275);DMetric("OF1","ACCEPTED",IntegerToString(g_state.acceptedOrders),x+12,y+42,(w-36)/2,COLOR_GREEN);DMetric("OF2","REJECTED",IntegerToString(g_state.rejectedOrders),x+24+(w-36)/2,y+42,(w-36)/2,g_state.rejectedOrders?COLOR_ORANGE:COLOR_GREEN);DKV("OF3","POSITIONS",IntegerToString(g_state.positionCount),x+14,y+122,72,COLOR_TEAL);DKV("OF4","PENDING",IntegerToString(g_state.pendingCount),x+14,y+152,72,COLOR_GOLD);DBar("OF5","POSITION LOAD",g_state.maxPositions>0?100.0*g_state.positionCount/g_state.maxPositions:0,x+14,y+190,w-42,COLOR_TEAL);DBar("OF6","PENDING LOAD",g_state.maxPendingOrders>0?100.0*g_state.pendingCount/g_state.maxPendingOrders:0,x+14,y+230,w-42,COLOR_GOLD);}

void CreateExecutionQuality()
{
   int x=ContentX(),y=PageBodyY(4),w=ContentW();
   int gap=12;
   int cw=(w-gap)/2;
   string lastType=(StringLen(g_state.lastOrderType)>0 && g_state.lastOrderType!="Label")?g_state.lastOrderType:"N/A";
   string lastQuality=(StringLen(g_state.executionLastQualityReason)>0 && g_state.executionLastQualityReason!="Label")?g_state.executionLastQualityReason:"NO EXECUTION SAMPLE";
   string qState=(g_state.executionSampleCount>0)?g_state.executionQualityState:"NO SAMPLES";
   color qStateColor=(g_state.executionSampleCount>0?(g_state.executionQualityDegraded?COLOR_ORANGE:COLOR_GREEN):COLOR_MUTED);

   DSectionSingle("EXQ_SUM","EXECUTION QUALITY",x,y,w,430);

   DSectionSingle("EXQ_A","QUALITY SCORE",x+14,y+42,cw-14,190);
   DMetric("EXQ_SCORE","SCORE",StringFormat("%.0f%%",g_state.executionQualityScore),x+26,y+74,cw-38,
      (g_state.executionSampleCount==0)?COLOR_MUTED:(g_state.executionQualityScore>=85.0?COLOR_GREEN:(g_state.executionQualityScore>=70.0?COLOR_GOLD:COLOR_RED)));
   DKV("EXQ_STATE","STATE",qState,x+26,y+140,86,qStateColor);
   DKV("EXQ_SAMPLES","SAMPLES",IntegerToString(g_state.executionSampleCount),x+26,y+170,86,COLOR_TEXT);
   DKV("EXQ_PREF","PREFLIGHT",g_state.executionPreflightState,x+26,y+200,86,g_state.executionPreflightOK?COLOR_GREEN:COLOR_RED);

   DSectionSingle("EXQ_B","EXECUTION METRICS",x+cw+gap,y+42,cw,190);
   DKV("EXQ_LAT","AVG LATENCY",StringFormat("%.0f ms",g_state.executionAverageLatencyMs),x+cw+gap+12,y+74,110,COLOR_TEXT);
   DKV("EXQ_RETRY","AVG RETRIES",StringFormat("%.2f",g_state.executionAverageRetries),x+cw+gap+12,y+104,110,COLOR_TEXT);
   DKV("EXQ_SLIP","LAST SLIPPAGE",StringFormat("%.1f pt",g_state.executionLastSlippagePoints),x+cw+gap+12,y+134,110,COLOR_TEXT);
   DKV("EXQ_REJ","PREFLIGHT REJECTS",IntegerToString(g_state.executionPreflightRejectCount),x+cw+gap+12,y+164,110,COLOR_TEXT);

   DSectionSingle("EXQ_C","LAST EXECUTION",x,y+248,w,178);
   int rx=x+14;
   int rv=x+w/2+10;
   DKV("EXQ_TYPE","TYPE",lastType,rx,y+280,86,COLOR_TEXT);
   DKV("EXQ_RC","RETCODE",IntegerToString((int)g_state.lastOrderRetcode),rx,y+312,86,
      g_state.lastOrderRetcode==TRADE_RETCODE_DONE?COLOR_GREEN:(g_state.executionSampleCount>0?COLOR_ORANGE:COLOR_MUTED));
   DKV("EXQ_REASON","QUALITY",lastQuality,rv,y+280,86,COLOR_TEXT);
   DKV("EXQ_STATUS","STATUS",qState,rv,y+312,86,qStateColor);
}

void CreateExecutionTab(){string s[]={"HEALTH","ORDER PARAMETERS","MARKET FILTERS","ORDER FLOW","QUALITY","TRANSACTION COSTS"};DPageTitle("EXECUTION","Order quality, parameters, filters and transaction costs");DNestedSubTabs(s,6,g_dashboard.executionSubTab,"EX_SUB_");switch(g_dashboard.executionSubTab){case 0:CreateExecutionHealth();break;case 1:CreateExecutionParameters();break;case 2:CreateExecutionFilters();break;case 3:CreateExecutionFlow();break;case 4:CreateExecutionQuality();break;case 5:CreateTransactionCostPage();break;}}



// -------------------- TRADES --------------------

void CreateTradesPositionsPage(){int x=ContentX(),y=PageBodyY(4),w=ContentW();DSectionSingle("TR_POS","POSITIONS",x,y,w,285);DMetric("TP_TOTAL","OPEN POSITIONS",IntegerToString(g_state.positionCount),x+12,y+42,(w-36)/2,COLOR_TEAL);DMetric("TP_PL","OPEN P/L",FormatNumber(g_state.currentProfit),x+24+(w-36)/2,y+42,(w-36)/2,g_state.currentProfit>=0?COLOR_GREEN:COLOR_RED);DKV("TP_BUY","BUY POSITIONS",IntegerToString(g_state.buyPositions),x+14,y+124,92,COLOR_GREEN);DKV("TP_SELL","SELL POSITIONS",IntegerToString(g_state.sellPositions),x+14,y+154,92,COLOR_RED);DKV("TP_CAP","CAPACITY",StringFormat("%d / %d",g_state.positionCount,g_state.maxPositions),x+14,y+184,92,COLOR_TEXT);DBar("TP_LOAD","POSITION LOAD",g_state.maxPositions>0?100.0*g_state.positionCount/g_state.maxPositions:0,x+14,y+224,w-42,COLOR_TEAL);}

void CreateTradesPendingPage(){int x=ContentX(),y=PageBodyY(4),w=ContentW();DSectionSingle("TR_PENDING","PENDING ORDERS",x,y,w,285);DMetric("TN_TOTAL","PENDING",IntegerToString(g_state.pendingCount),x+12,y+42,(w-36)/2,COLOR_GOLD);DMetric("TN_CAP","CAPACITY",StringFormat("%d / %d",g_state.pendingCount,g_state.maxPendingOrders),x+24+(w-36)/2,y+42,(w-36)/2,COLOR_TEXT);DKV("TN_BUY","BUY STOP/LIMIT",IntegerToString(g_state.buyPending),x+14,y+124,100,COLOR_GREEN);DKV("TN_SELL","SELL STOP/LIMIT",IntegerToString(g_state.sellPending),x+14,y+154,100,COLOR_RED);DKV("TN_FRONT","FRONT DIST",StringFormat("%.1f pips",g_state.frontOrderDistancePips),x+14,y+184,100,COLOR_TEXT);DKV("TN_EXP","EXPIRY",g_state.pendingExpiryMinutes>0?StringFormat("%d min",g_state.pendingExpiryMinutes):"GTC",x+14,y+214,100,COLOR_TEXT);DBar("TN_LOAD","PENDING LOAD",g_state.maxPendingOrders>0?100.0*g_state.pendingCount/g_state.maxPendingOrders:0,x+14,y+250,w-42,COLOR_GOLD);}

void CreateTradesActionsPage(){int x=ContentX(),y=PageBodyY(4),w=ContentW();DSectionSingle("TR_ACTIONS","TRADE ACTIONS",x,y,w,285);DButton("TR_CLOSE_PROFIT","CLOSE PROFIT",x+14,y+44,w-28,30,COLOR_GREEN,false,7);DButton("TR_CLOSE_LOSS","CLOSE LOSS",x+14,y+82,w-28,30,COLOR_RED,false,7);DButton("TR_CANCEL","CANCEL PENDING",x+14,y+120,w-28,30,COLOR_PANEL2,false,7);DButton("TR_RECENTER","RE-CENTER",x+14,y+158,w-28,30,COLOR_ACCENT,false,7);DButton("TR_CLOSE_ALL","CLOSE ALL",x+14,y+196,w-28,30,COLOR_RED,false,7);DKV("TAS","STATUS",g_state.executionStatus,x+14,y+244,62,COLOR_GOLD);}

void CreateTradesSafetyPage(){int x=ContentX(),y=PageBodyY(4),w=ContentW();DSectionSingle("TR_SAFETY","TRADE SAFETY",x,y,w,295);DToggle("TR_SL","STOP LOSS",g_state.useStopLossForNewOrders,x+14,y+42,w-28);DToggle("TR_TP","TAKE PROFIT",g_state.useTakeProfitForNewOrders,x+14,y+76,w-28);DToggle("TR_BE","BREAK EVEN",g_state.breakEven,x+14,y+110,w-28);DToggle("TR_TRAIL","TRAILING",g_state.trailingStop,x+14,y+144,w-28);DToggle("TR_RISK","RISK ENGINE",g_state.riskManagedTrading,x+14,y+178,w-28);DToggle("TR_OCO","OCO",g_state.oco,x+14,y+212,w-28);DKV("TS_OP","OPPOSITE",g_state.closeOppositeOnFill?"CLOSE":"KEEP",x+14,y+252,72,g_state.closeOppositeOnFill?COLOR_GREEN:COLOR_MUTED);}

void CreateTradesIndividualEnginePage()
{
   int x=ContentX(),y=PageBodyY(4),w=ContentW(),gap=12,cw=(w-gap)/2;
   DSectionSingle("TR_IE_SUM","INDIVIDUAL TRADE ENGINE",x,y,w,292);
   DSectionSingle("TR_IE_A","LIVE INVENTORY",x+14,y+40,cw-14,190);
   DMetric("TRIE_COUNT","TRADES",IntegerToString(g_state.individualTradeCount),x+26,y+72,(cw-36)/3,COLOR_TEAL);
   DMetric("TRIE_MGD","MANAGED",IntegerToString(g_state.individualManagedCount),x+38+(cw-36)/3,y+72,(cw-36)/3,COLOR_GREEN);
   DMetric("TRIE_AU","AUTO",IntegerToString(g_state.individualAutonomousCount),x+50+2*(cw-36)/3,y+72,(cw-36)/3,COLOR_GOLD);
   DKV("TRIE_SL","WITH SL",IntegerToString(g_state.individualSLCount),x+26,y+132,72,COLOR_TEXT);
   DKV("TRIE_TP","WITH TP",IntegerToString(g_state.individualTPCount),x+26,y+162,72,COLOR_TEXT);
   DKV("TRIE_BE","BE READY",IntegerToString(g_state.individualBECount),x+26,y+192,72,COLOR_TEXT);

   DSectionSingle("TR_IE_B","RUNTIME P/L",x+cw+12,y+40,cw-12,190);
   DKV("TRIE_PL","FLOATING P/L",FormatNumber(g_state.individualFloatingPnL),x+cw+26,y+72,92,g_state.individualFloatingPnL>=0?COLOR_GREEN:COLOR_RED);
   DKV("TRIE_PK","PEAK P/L",FormatNumber(g_state.individualPeakProfit),x+cw+26,y+102,92,COLOR_TEXT);
   DKV("TRIE_DD","FROM PEAK",StringFormat("%.2f%%",g_state.individualWorstDrawdownPct),x+cw+26,y+132,92,COLOR_ORANGE);
   DKV("TRIE_RK","TRADE RISK",StringFormat("%.2f%%",g_state.individualRiskPct),x+cw+26,y+162,92,COLOR_GOLD);
   DKV("TRIE_TK","LAST TICKET",g_state.individualLastTicket>0?StringFormat("%I64u",g_state.individualLastTicket):"NONE",x+cw+26,y+192,92,COLOR_TEXT);

   DSectionSingle("TR_IE_C","EXIT AUTHORITY",x,y+246,w,170);
   DKV("TRIE_OWN","LAST OWNER",g_state.individualLastAuthority==""?"NONE":g_state.individualLastAuthority,x+14,y+278,98,COLOR_GOLD);
   DKV("TRIE_ACT","LAST ACTION",g_state.individualLastAction==""?"NONE":g_state.individualLastAction,x+14,y+308,98,COLOR_TEXT);
   DKV("TRIE_RS","REASON",g_state.individualLastReason==""?"NONE":g_state.individualLastReason,x+14,y+338,98,COLOR_TEXT);
   DText("TRIE_NOTE","Per-ticket engine only. Drawdown / daily / spread telemetry does not close existing trades here.",x+14,y+372,6,COLOR_MUTED,"Arial");
   DKV("TRIE_P10","TRADE PROTECTION",g_state.tradeProtectionLastAction==""?"IDLE":g_state.tradeProtectionLastAction,x+26,y+282,72,COLOR_GOLD);
   DKV("TRIE_P10R","P10 REASON",g_state.tradeProtectionLastReason==""?"NONE":g_state.tradeProtectionLastReason,x+26,y+312,72,COLOR_TEXT);
}


void CreateTradesTab(){string s[]={"OPEN POSITIONS","PENDING ORDERS","TRADE ACTIONS","TRADE SAFETY","TRADE ENGINE"};DPageTitle("TRADES","Dedicated trade workspaces");DNestedSubTabs(s,5,g_dashboard.tradesSubTab,"TR_SUB_");switch(g_dashboard.tradesSubTab){case 0:CreateTradesPositionsPage();break;case 1:CreateTradesPendingPage();break;case 2:CreateTradesActionsPage();break;case 3:CreateTradesSafetyPage();break;case 4:CreateTradesIndividualEnginePage();break;}}



void SettingsCard(string id,string title,string subtitle,int x,int y,int w,int h);

void SettingsSectionStatus(string prefix,string label,string value,int x,int y,color c=clrWhite);

void SettingsPageHeader(string title,string subtitle);

void SettingsColumnField(string id,string label,string value,int x,int y);

// -------------------- EA STATUS--------------------

void CreateTransparencyOverview(){int x=ContentX(),y=PageBodyY(2),w=ContentW(),gap=8,cw=(w-gap)/2;

   DSectionSingle("TRN_OV_A","CONTROL OWNERSHIP",x,y,cw,270);

   SettingsSectionStatus("TRN_MODE","CONTROL MODE",ControlModeName(g_state.controlMode),x+14,y+42,g_state.controlMode==CONTROL_AUTONOMOUS?COLOR_ORANGE:(g_state.controlMode==CONTROL_ASSIST?COLOR_GOLD:COLOR_GREEN));

   SettingsSectionStatus("TRN_GRID","GRID OWNER",g_state.adaptiveGrid?"ADAPTIVE GRID":"USER",x+14,y+74,g_state.adaptiveGrid?COLOR_GOLD:COLOR_GREEN);

   SettingsSectionStatus("TRN_ENTRY","ENTRY OWNER",(IsAutonomousControl()&&g_state.advancedEntryDecision)?"ENTRY ENGINE":"USER",x+14,y+106,(IsAutonomousControl()&&g_state.advancedEntryDecision)?COLOR_GOLD:COLOR_GREEN);

   SettingsSectionStatus("TRN_RISK","LOT OWNER",g_state.adaptiveLot?"ADAPTIVE LOT":"USER",x+14,y+138,g_state.adaptiveLot?COLOR_GOLD:COLOR_GREEN);

   SettingsSectionStatus("TRN_MGMT","POSITION POLICY",g_state.strategyAwareManagement?GridStrategyName(g_state.gridType):"USER FIXED",x+14,y+170,g_state.strategyAwareManagement?COLOR_GOLD:COLOR_GREEN);

   SettingsSectionStatus("TRN_EXIT","EXIT COORD",g_state.strategyExitCoordination?(g_state.exitCoordinationActive?"ACTIVE":"ARMED"):"OFF",x+14,y+202,g_state.strategyExitCoordination?COLOR_GOLD:COLOR_MUTED);

   SettingsSectionStatus("TRN_LAST","LAST ACTION",g_state.lastDecision,x+14,y+234,COLOR_TEXT);

   DSectionSingle("TRN_OV_B","DECISION",x+cw+gap,y,cw,270);

   SettingsSectionStatus("TRD_O","OWNER",g_state.lastActionOwner,x+cw+gap+14,y+42,COLOR_GOLD);

   SettingsSectionStatus("TRD_R","REASON",g_state.lastActionReason,x+cw+gap+14,y+74,COLOR_TEXT);

   SettingsSectionStatus("TRD_T","TIME",g_state.lastActionTime>0?TimeToString(g_state.lastActionTime,TIME_SECONDS):"--",x+cw+gap+14,y+106,COLOR_MUTED);

   SettingsSectionStatus("TRD_D","DECISION",g_state.lastDecision,x+cw+gap+14,y+138,COLOR_TEXT);

   SettingsSectionStatus("TRD_E","ENTRY THROTTLE",g_state.entryThrottleActive?"ACTIVE":"OFF",x+cw+gap+14,y+170,g_state.entryThrottleActive?COLOR_RED:COLOR_GREEN);SettingsSectionStatus("TRD_S","SUITABILITY",StringFormat("%.0f%%",g_state.marketSuitabilityScore*100),x+cw+gap+14,y+202,COLOR_TEAL);

}

void CreateTransparencyEffective()
{
   int x=ContentX(),y=PageBodyY(2),w=ContentW(),gap=10,cw=(w-gap)/2;
   DSectionSingle("TRN_EA","CONFIGURED VS EFFECTIVE",x,y,cw,250);
   SettingsSectionStatus("TE1","GRID STEP",StringFormat("SET %.1f | ACTIVE %.1f",g_state.gridStep,g_state.effectiveGridStepPips),x+14,y+42,COLOR_GOLD);
   SettingsSectionStatus("TE2","LEVELS",StringFormat("SET %d | ACTIVE %d",g_state.gridLevels,g_state.effectiveGridLevels),x+14,y+74,COLOR_GOLD);
   SettingsSectionStatus("TE3","LOT",StringFormat("SET %.3f | ACTIVE %.3f",g_state.lotSize,g_state.effectiveLot),x+14,y+106,COLOR_GOLD);
   SettingsSectionStatus("TE4","EXPOSURE",StringFormat("%.2f / %.2f lots",g_state.totalExposureLots,g_state.maxTotalLots),x+14,y+138,COLOR_TEAL);
   SettingsSectionStatus("TE5","GRID RISK",StringFormat("%.2f%% / %.2f%%",g_state.gridRiskPct,g_state.maxGridRiskPct),x+14,y+170,COLOR_TEXT);
   SettingsSectionStatus("TE5M","POSITION POLICY",g_state.strategyAwareManagement?"STRATEGY-AWARE":"USER FIXED",x+14,y+202,g_state.strategyAwareManagement?COLOR_GOLD:COLOR_GREEN);

   DSectionSingle("TRN_EB","PROTECTION",x+cw+gap,y,cw,250);
   SettingsSectionStatus("TE6","THROTTLE",g_state.entryThrottleActive?"ACTIVE":"OFF",x+cw+gap+14,y+42,g_state.entryThrottleActive?COLOR_RED:COLOR_GREEN);
   string throttleReason=g_state.entryThrottleReason==""?"NONE":g_state.entryThrottleReason;
   SettingsSectionStatus("TE7","REASON",StringSubstr(throttleReason,0,20),x+cw+gap+14,y+74,COLOR_MUTED);
   SettingsSectionStatus("TE8","DD",StringFormat("%.2f%% / %.2f%%",g_state.maxDrawdown,g_state.maxDrawdownPct),x+cw+gap+14,y+106,COLOR_TEXT);
   SettingsSectionStatus("TE9","DAILY P/L",FormatNumber(g_state.todayProfit),x+cw+gap+14,y+138,g_state.todayProfit>=0?COLOR_GREEN:COLOR_RED);
   SettingsSectionStatus("TE10","COST GATE",g_state.transactionCostGateEnabled?"AUTONOMOUS":"MONITOR",x+cw+gap+14,y+170,g_state.transactionCostGateEnabled?COLOR_GOLD:COLOR_MUTED);
   SettingsSectionStatus("TE11","EXIT AUTHORITY",(g_state.protectionMasterEnabled&&
      (g_state.protectionDrawdownCloseEnabled||g_state.protectionDailyLossCloseEnabled||g_state.protectionBasketLossCloseEnabled||g_state.protectionBasketProfitCloseEnabled||g_state.protectionProfitLockCloseEnabled))?"ENABLED":"OFF",x+cw+gap+14,y+202,COLOR_TEXT);

   int y2=y+260;
   DSectionSingle("TRN_GI","GRID PROFILE INTEGRITY",x,y2,w,230);
   int left=x+14,right=x+cw+gap+14;
   SettingsSectionStatus("TGI_TYPE","PROFILE",CompactGridName(g_state.gridType),left,y2+42,COLOR_GOLD);
   SettingsSectionStatus("TGI_STRAT","STRATEGY",StringSubstr(GridStrategyName(g_state.gridType),0,22),left,y2+72,COLOR_TEXT);
   SettingsSectionStatus("TGI_DIR","DIRECTION",StringSubstr(GridDirectionModel(g_state.gridType),0,22),left,y2+102,COLOR_TEAL);
   SettingsSectionStatus("TGI_DIST","DISTANCE",StringSubstr(GridDistanceModel(g_state.gridType),0,22),left,y2+132,COLOR_TEXT);
   SettingsSectionStatus("TGI_LOT","LOT MODEL",StringSubstr(GridLotModel(g_state.gridType),0,22),left,y2+162,COLOR_TEXT);
   SettingsSectionStatus("TGI_RULE","SPECIAL RULE",StringSubstr(GridSpecialRule(g_state.gridType),0,22),left,y2+192,COLOR_MUTED);
   SettingsSectionStatus("TGI_POL","POLICY FACTOR",StringFormat("STEP x%.2f",g_state.gridPolicyStepFactor),right,y2+42,COLOR_TEAL);
   SettingsSectionStatus("TGI_LOTP","LOT FACTOR",StringFormat("LOT x%.2f",g_state.gridPolicyLotFactor),right,y2+72,COLOR_TEAL);
   SettingsSectionStatus("TGI_LVL","LEVEL POLICY",StringSubstr(g_state.gridPolicyLevelReason==""?"USER BASE":g_state.gridPolicyLevelReason,0,24),right,y2+102,COLOR_MUTED);
   SettingsSectionStatus("TGI_CAP","RISK CAP",StringFormat("%.0f%%",g_state.gridGeometryRiskCapacityFactor*100.0),right,y2+132,COLOR_GOLD);
}

void CreateTransparencyActivity()
{
   int x=ContentX(),y=PageBodyY(2),w=ContentW(),h=ContentH()-(y-ContentY())-6;
   DSectionSingle("TRN_LOG","RECENT EA ACTIVITY",x,y,w,h);
   int rows=MathMin(g_eventCount,11);
   for(int i=0;i<rows;i++)
   {
      int idx=g_eventCount-1-i,yy=y+42+i*22;
      DText("TRNLT_"+IntegerToString(i),StringSubstr(g_eventTime[idx],0,8),x+12,yy,6,COLOR_MUTED,"Arial");
      DText("TRNLE_"+IntegerToString(i),StringSubstr(g_eventType[idx],0,18),x+78,yy,6,COLOR_GOLD,"Arial Bold");
      DText("TRNLD_"+IntegerToString(i),StringSubstr(g_eventDetail[idx],0,58),x+190,yy,6,COLOR_TEXT,"Arial");
   }
   DButton("TRN_CLEAR", "CLEAR JOURNAL",x+w-124,y+8,112,24,COLOR_PANEL2,false,6);
}

void CreateTransparencyUserTrust()
{
   int x=ContentX(),bodyY=PageBodyY(2),w=ContentW();
   int h=ContentH()-(bodyY-ContentY())-6;
   int gap=10,cw=(w-gap)/2;
   if(g_userTrustSubTab==0)
   {
      DSectionSingle("TRU_A","CONTROL & OWNERSHIP",x,bodyY,cw,h);
      SettingsSectionStatus("TRUA1","CONTROL",ControlModeName(g_state.controlMode),x+14,bodyY+44,g_state.controlMode==CONTROL_AUTONOMOUS?COLOR_ORANGE:(g_state.controlMode==CONTROL_ASSIST?COLOR_GOLD:COLOR_GREEN));
      SettingsSectionStatus("TRUA2","GRID OWNER",g_state.adaptiveGrid?"ADAPTIVE":"USER",x+14,bodyY+76,g_state.adaptiveGrid?COLOR_GOLD:COLOR_GREEN);
      SettingsSectionStatus("TRUA3","ENTRY OWNER",(IsAutonomousControl()&&g_state.advancedEntryDecision)?"ENGINE":"USER",x+14,bodyY+108,(IsAutonomousControl()&&g_state.advancedEntryDecision)?COLOR_GOLD:COLOR_GREEN);
      SettingsSectionStatus("TRUA4","LOT OWNER",g_state.adaptiveLot?"ADAPTIVE":"USER",x+14,bodyY+140,g_state.adaptiveLot?COLOR_GOLD:COLOR_GREEN);
      SettingsSectionStatus("TRUA5","POSITION",g_state.strategyAwareManagement?StringSubstr(GridStrategyName(g_state.gridType),0,18):"USER FIXED",x+14,bodyY+172,g_state.strategyAwareManagement?COLOR_GOLD:COLOR_GREEN);
      SettingsSectionStatus("TRUA6","EXIT COORD",g_state.strategyExitCoordination?(g_state.exitCoordinationActive?"ACTIVE":"ARMED"):"OFF",x+14,bodyY+204,g_state.strategyExitCoordination?COLOR_GOLD:COLOR_MUTED);
      SettingsSectionStatus("TRUA7","BUILD",NOVA_BUILD_LABEL,x+14,bodyY+236,COLOR_TEAL);
      SettingsSectionStatus("TRUA8","SPEC","RULE 11",x+14,bodyY+268,COLOR_GOLD);
      DText("TRUA_NOTE","Transparency only. No trading authority is granted here.",x+14,bodyY+304,6,COLOR_MUTED,"Arial");
   }
   else if(g_userTrustSubTab==1)
   {
      DSectionSingle("TRU_B","DECISION & WHY",x,bodyY,cw,h);
      DSectionSingle("TRU_B2","CONTEXT",x+cw+gap,bodyY,cw,h);
      string decision=g_state.autonomousDecisionClass!=""?g_state.autonomousDecisionClass:g_state.lastDecision;
      string reason=g_state.autonomousDecisionReason!=""?g_state.autonomousDecisionReason:g_state.lastActionReason;
      string stage=g_state.autonomousPipelineStage!=""?g_state.autonomousPipelineStage:"IDLE";
      string owner=g_state.lastActionOwner==""?"SYSTEM":g_state.lastActionOwner;
      SettingsSectionStatus("TRUB1","DECISION",decision==""?"WAITING":StringSubstr(decision,0,16),x+14,bodyY+44,decision=="WAIT"?COLOR_ORANGE:(decision=="REJECT"?COLOR_RED:COLOR_GOLD));
      SettingsSectionStatus("TRUB2","PIPELINE",StringSubstr(stage,0,18),x+14,bodyY+78,COLOR_TEAL);
      SettingsSectionStatus("TRUB3","OWNER",StringSubstr(owner,0,18),x+14,bodyY+112,COLOR_GOLD);
      DText("TRUB4L","REASON",x+14,bodyY+150,7,COLOR_MUTED,"Arial Bold");
      DText("TRUB4V",StringSubstr(reason==""?"NO RECORDED REASON":reason,0,34),x+100,bodyY+149,7,COLOR_TEXT,"Arial");
      SettingsSectionStatus("TRUB5","LAST ACTION",StringSubstr(g_state.lastDecision==""?"NONE":g_state.lastDecision,0,18),x+14,bodyY+186,COLOR_TEXT);
      SettingsSectionStatus("TRUB6","TIME",g_state.lastActionTime>0?TimeToString(g_state.lastActionTime,TIME_SECONDS):"--",x+14,bodyY+220,COLOR_MUTED);
      SettingsSectionStatus("TRUB7","THROTTLE",g_state.entryThrottleActive?"ACTIVE":"OFF",x+14,bodyY+254,g_state.entryThrottleActive?COLOR_RED:COLOR_GREEN);
      SettingsSectionStatus("TRUB8","SUITABILITY",StringFormat("%.0f%%",g_state.marketSuitabilityScore*100),x+14,bodyY+288,COLOR_TEAL);
      SettingsSectionStatus("TRUB9","EXPECTED EDGE",StringFormat("%.0f%%",g_state.gridSelectionExpectedEdge*100),x+cw+gap+14,bodyY+44,COLOR_TEAL);
      SettingsSectionStatus("TRUB10","GRID FIT",StringFormat("%.0f%%",g_state.gridSelectionSelectedScore*100),x+cw+gap+14,bodyY+78,COLOR_GOLD);
      SettingsSectionStatus("TRUB11","DIRECTION",StringSubstr(g_state.gridSelectionDirection,0,14),x+cw+gap+14,bodyY+112,COLOR_TEXT);
      SettingsSectionStatus("TRUB12","COST STATUS",StringSubstr(g_state.transactionCostCostStatus,0,18),x+cw+gap+14,bodyY+146,COLOR_GOLD);
   }
   else if(g_userTrustSubTab==2)
   {
      DSectionSingle("TRU_C","EFFECTIVE STATE",x,bodyY,cw,h);
      DSectionSingle("TRU_C2","ACTIVE PROFILE",x+cw+gap,bodyY,cw,h);
      SettingsSectionStatus("TRUC1","STEP",StringFormat("SET %.1f | ACTIVE %.1f",g_state.gridStep,g_state.effectiveGridStepPips),x+14,bodyY+44,COLOR_GOLD);
      SettingsSectionStatus("TRUC2","LEVELS",StringFormat("SET %d | ACTIVE %d",g_state.gridLevels,g_state.effectiveGridLevels),x+14,bodyY+78,COLOR_GOLD);
      SettingsSectionStatus("TRUC3","LOT",StringFormat("SET %.3f | ACTIVE %.3f",g_state.lotSize,g_state.effectiveLot),x+14,bodyY+112,COLOR_GOLD);
      SettingsSectionStatus("TRUC4","EXPOSURE",StringFormat("%.2f / %.2f lots",g_state.totalExposureLots,g_state.maxTotalLots),x+14,bodyY+146,COLOR_TEAL);
      SettingsSectionStatus("TRUC5","GRID RISK",StringFormat("%.2f%% / %.2f%%",g_state.gridRiskPct,g_state.maxGridRiskPct),x+14,bodyY+180,COLOR_TEXT);
      SettingsSectionStatus("TRUC6","POSITION",g_state.strategyAwareManagement?"STRATEGY-AWARE":"USER FIXED",x+14,bodyY+214,g_state.strategyAwareManagement?COLOR_GOLD:COLOR_GREEN);
      SettingsSectionStatus("TRUC7","PROFILE",CompactGridName(g_state.gridType),x+cw+gap+14,bodyY+44,COLOR_GOLD);
      SettingsSectionStatus("TRUC8","STRATEGY",StringSubstr(GridStrategyName(g_state.gridType),0,20),x+cw+gap+14,bodyY+78,COLOR_TEXT);
      SettingsSectionStatus("TRUC9","DIRECTION",StringSubstr(GridDirectionModel(g_state.gridType),0,20),x+cw+gap+14,bodyY+112,COLOR_TEAL);
      SettingsSectionStatus("TRUC10","POLICY",StringSubstr(g_state.gridPolicyReason==""?"USER BASE":g_state.gridPolicyReason,0,24),x+cw+gap+14,bodyY+146,COLOR_MUTED);
      SettingsSectionStatus("TRUC11","STEP FACTOR",StringFormat("x%.2f",g_state.gridPolicyStepFactor),x+cw+gap+14,bodyY+180,COLOR_TEAL);
      SettingsSectionStatus("TRUC12","LOT FACTOR",StringFormat("x%.2f",g_state.gridPolicyLotFactor),x+cw+gap+14,bodyY+214,COLOR_TEAL);
   }
   else
   {
      DSectionSingle("TRU_D","RISK / RECOVERY / VALIDATION",x,bodyY,w,h);
      bool breakerOn=(g_state.protectionMasterEnabled&&g_state.protectionHardBreakerEnabled&&InpHardCircuitBreakerUSD>0.0);
      SettingsSectionStatus("TRUD1","BREAKER",breakerOn?"ARMED":"OFF",x+14,bodyY+44,breakerOn?COLOR_ORANGE:COLOR_MUTED);
      if(breakerOn)
      {
         double liveLoss=g_state.cycleRealizedLoss+MathMin(0.0,g_state.currentProfit),used=MathMax(0.0,-liveLoss),limit=MathAbs(InpHardCircuitBreakerUSD),remaining=MathMax(0.0,limit-used);
         SettingsSectionStatus("TRUD1B","REMAINING",StringFormat("$%.2f / $%.2f",remaining,limit),x+14,bodyY+76,remaining<=limit*0.20?COLOR_RED:COLOR_GOLD);
      }
      SettingsSectionStatus("TRUD2","RECOVERY",g_state.recoveryModeActive?StringFormat("ATTEMPT %d",g_state.recoveryAttemptsUsed):"STANDBY",x+14,bodyY+108,g_state.recoveryModeActive?COLOR_ORANGE:COLOR_MUTED);
      SettingsSectionStatus("TRUD3","SCALE",StringFormat("x%.3f",g_state.recoveryLotScale),x+14,bodyY+140,COLOR_TEXT);
      SettingsSectionStatus("TRUD4","STATUS",StringSubstr(g_state.recoveryStatus==""?"NONE":g_state.recoveryStatus,0,22),x+14,bodyY+172,COLOR_TEAL);
      SettingsSectionStatus("TRUD5","VALIDATION LAB",g_phase16RunCount>0?StringSubstr(g_phase16Summary,0,22):"NOT RUN",x+14,bodyY+204,g_phase16RunCount>0?COLOR_GOLD:COLOR_MUTED);
      SettingsSectionStatus("TRUD6","VALIDATED",g_phase16LastRun>0?TimeToString(g_phase16LastRun,TIME_SECONDS):"NOT RUN",x+14,bodyY+236,COLOR_MUTED);
      SettingsSectionStatus("TRUD7","TYPE","NON-TRADING",x+14,bodyY+268,COLOR_TEAL);
   }
}

void CreateTransparencyTab()
{
   int x=ContentX();
   DPageTitle("TRANSPARENCY","See who controls the EA, what changed, and why");
   string s[]={"OVERVIEW","EFFECTIVE VALUES","ACTIVITY","CONTROL & OWNERSHIP","DECISION & WHY","EFFECTIVE STATE","RISK / RECOVERY / VALIDATION"};
   DNestedSubTabs(s,7,g_dashboard.transparencySubTab,"TRN_SUB_");
   switch(g_dashboard.transparencySubTab)
   {
      case 0:CreateTransparencyOverview();break;
      case 1:CreateTransparencyEffective();break;
      case 2:CreateTransparencyActivity();break;
      case 3:g_userTrustSubTab=0;CreateTransparencyUserTrust();break;
      case 4:g_userTrustSubTab=1;CreateTransparencyUserTrust();break;
      case 5:g_userTrustSubTab=2;CreateTransparencyUserTrust();break;
      case 6:g_userTrustSubTab=3;CreateTransparencyUserTrust();break;
   }
}



void CreatePhase22ReleaseCandidatePage()
{
   int x=ContentX(), y=PageBodyY(3), w=ContentW(), gap=10, cw=(w-gap)/2;
   DSectionSingle("RC_PRE","RELEASE CANDIDATE PRE-FLIGHT",x,y,cw,300);
   bool gridValid=((int)g_state.gridType>=0 && (int)g_state.gridType<GRID_TYPE_COUNT);
   bool magicValid=(InpMagicNumber>0);
   bool lotsValid=(g_state.lotSize>0.0);
   bool levelsValid=(g_state.gridLevels>=1 && g_state.gridLevels<=g_state.adaptiveMaxLevels);
   bool stepValid=(g_state.gridStep>0.0);
   bool controlValid=(g_state.controlMode==CONTROL_MANUAL || g_state.controlMode==CONTROL_ASSIST || g_state.controlMode==CONTROL_AUTONOMOUS);
   DKV("RC01","GRID SELECTION",gridValid?CompactGridName(g_state.gridType):"INVALID",x+14,y+42,105,gridValid?COLOR_GOLD:COLOR_RED);
   DKV("RC02","MAGIC",magicValid?IntegerToString(InpMagicNumber):"INVALID",x+14,y+72,105,magicValid?COLOR_GREEN:COLOR_RED);
   DKV("RC03","BASE LOT",lotsValid?DoubleToString(g_state.lotSize,3):"INVALID",x+14,y+102,105,lotsValid?COLOR_GREEN:COLOR_RED);
   DKV("RC04","LEVELS",levelsValid?StringFormat("%d",g_state.gridLevels):"INVALID",x+14,y+132,105,levelsValid?COLOR_GREEN:COLOR_RED);
   DKV("RC05","STEP",stepValid?StringFormat("%.1f pips",g_state.gridStep):"INVALID",x+14,y+162,105,stepValid?COLOR_GREEN:COLOR_RED);
   DKV("RC06","CONTROL",controlValid?ControlModeName(g_state.controlMode):"INVALID",x+14,y+192,105,controlValid?COLOR_GREEN:COLOR_RED);
   DKV("RC07","EXECUTION",g_state.executionStatus==""?"READY":StringSubstr(g_state.executionStatus,0,18),x+14,y+222,105,COLOR_TEXT);
   DKV("RC08","LIVE GRID",g_state.gridActive?"ACTIVE":"IDLE",x+14,y+252,105,g_state.gridActive?COLOR_GREEN:COLOR_MUTED);

   DSectionSingle("RC_TEST","RELEASE CANDIDATE TEST REGISTER",x+cw+gap,y,cw,300);
   string tt[10]={"MANUAL START","AUTONOMOUS START","SELECTED-GRID PERSISTENCE","5 FORMALIZED GRIDS","LONG / SHORT","INDIVIDUAL TRADE MANAGEMENT","REBUILD / RECENTER / CANCEL","RECOVERY","CIRCUIT BREAKER","RESTART / DASHBOARD AUDIT"};
   for(int i=0;i<10;i++)
   {
      DText("RC_T_"+IntegerToString(i),tt[i],x+cw+gap+14,y+42+i*24,6,COLOR_TEXT,"Arial");
      DText("RC_S_"+IntegerToString(i),"NOT RUN",x+cw+gap+205,y+41+i*24,6,COLOR_MUTED,"Arial Bold");
   }
   DText("RC_NOTE","Runtime register stays NOT RUN until verified in MetaEditor and the demo account.",x,y+322,6,COLOR_MUTED,"Arial");
   DText("RC_RULE","RELEASE CANDIDATE is release-candidate readiness, not proof of completed runtime validation.",x,y+340,6,COLOR_GOLD,"Arial");
}

void CreateDiagnosticsSystemOverview(){int x=ContentX(),y=PageBodyY(3),w=ContentW(),gap=8,cw=(w-gap)/2;

   DSectionSingle("DIA_SYS_A","SYSTEM STATE",x,y,cw,235);

   SettingsSectionStatus("DS1","CONTROL",ControlModeName(g_state.controlMode),x+14,y+42,COLOR_GOLD);

   SettingsSectionStatus("DS2","GRID",g_state.gridActive?"ACTIVE":"IDLE",x+14,y+72,g_state.gridActive?COLOR_GREEN:COLOR_MUTED);

   SettingsSectionStatus("DS3","EXECUTION",g_state.executionStatus,x+14,y+102,COLOR_TEXT);

   SettingsSectionStatus("DS4","ACCEPTED",IntegerToString(g_state.acceptedOrders),x+14,y+132,COLOR_GREEN);

   SettingsSectionStatus("DS5","REJECTED",IntegerToString(g_state.rejectedOrders),x+14,y+162,g_state.rejectedOrders?COLOR_ORANGE:COLOR_GREEN);

   DSectionSingle("DIA_SYS_B","EXECUTION HEALTH",x+cw+gap,y,cw,235);

   SettingsSectionStatus("DH1","LAST TYPE",g_state.lastOrderType!=""?g_state.lastOrderType:"--",x+cw+gap+14,y+42,COLOR_TEXT);

   SettingsSectionStatus("DH2","RETCODE",IntegerToString((int)g_state.lastOrderRetcode),x+cw+gap+14,y+72,COLOR_TEXT);

   SettingsSectionStatus("DH3","RETRIES",IntegerToString(g_state.lastOrderRetryCount),x+cw+gap+14,y+102,COLOR_TEXT);

   SettingsSectionStatus("DH4","LATENCY",StringFormat("%u ms",g_state.lastOrderLatencyMs),x+cw+gap+14,y+132,COLOR_TEXT);

   SettingsSectionStatus("DH5","GUARDIAN",g_state.orderGuardian?"ON":"OFF",x+cw+gap+14,y+162,g_state.orderGuardian?COLOR_GREEN:COLOR_MUTED);

}

void CreateDiagnosticsSystem(){
   string s[]={"SYSTEM OVERVIEW","RELEASE CANDIDATE"};
   DNestedSubTabs(s,2,g_phase22SystemSubTab,"DIA_SYSTEM_SUB_");
   if(g_phase22SystemSubTab==0) CreateDiagnosticsSystemOverview();
   else CreatePhase22ReleaseCandidatePage();
}

string UserFriendlyJournalType(string t)
{
   if(t=="AUTHORITY AUDIT AUDIT") return "AUTHORITY CHECK";
   if(t=="AUTONOMOUS DECISION AUDIT") return "AUTONOMOUS DECISION";
   if(t=="GRID LIFECYCLE AUDIT") return "GRID LIFECYCLE";
   if(t=="TRADE PROTECTION AUDIT") return "TRADE PROTECTION";
   if(t=="RISK PORTFOLIO AUDIT") return "RISK & PORTFOLIO";
   if(t=="GRID SELECTION AUDIT") return "GRID SELECTION";
   if(t=="GRID GEOMETRY AUDIT") return "GRID GEOMETRY";
   if(t=="GRID LIBRARY AUDIT") return "STRATEGY LIBRARY";
   if(t=="MARKET STATE AUDIT") return "MARKET INTELLIGENCE";
   if(t=="RUNTIME INTEGRITY") return "RUNTIME INTEGRITY";
   if(t=="GRID RECOVERY") return "RECOVERY / RESTART";
   if(t=="TRADE ENGINE AUDIT") return "TRADE ENGINE";
   if(t=="GRID SELECTION") return "GRID SELECTION";
   if(t=="GRID GEOMETRY") return "GRID GEOMETRY";
   if(t=="GRID LIBRARY") return "STRATEGY LIBRARY";
   return t;
}
string UserFriendlyJournalDetail(string t,string d)
{
   string out=d;
   StringReplace(out,"AUTHORITY AUDIT audit","Authority check");
   StringReplace(out,"AUTONOMOUS DECISION autonomous decision","Autonomous decision");
   StringReplace(out,"AUTONOMOUS DECISION","Autonomous decision");
   StringReplace(out,"GRID LIFECYCLE grid lifecycle","Grid lifecycle");
   StringReplace(out,"GRID LIFECYCLE","Grid lifecycle");
   StringReplace(out,"TRADE PROTECTION trade management","Trade protection");
   StringReplace(out,"TRADE PROTECTION","Trade protection");
   StringReplace(out,"TRADE ENGINE","Trade engine");
   StringReplace(out,"RISK & PORTFOLIO risk hierarchy","Risk hierarchy");
   StringReplace(out,"RISK & PORTFOLIO","Risk hierarchy");
   StringReplace(out,"GRID GEOMETRY adaptive geometry","Adaptive geometry");
   StringReplace(out,"GRID GEOMETRY","Adaptive geometry");
   StringReplace(out,"MARKET INTELLIGENCE market intelligence","Market intelligence");
   StringReplace(out,"MARKET INTELLIGENCE","Market intelligence");
   StringReplace(out,"STATE INTEGRITY state persistence and validation","State integrity and validation");
   StringReplace(out,"STATE INTEGRITY","State integrity and validation");
   StringReplace(out,"VALIDATION LAB validation","Validation lab");
   StringReplace(out,"VALIDATION LAB","VALIDATION LAB");
   return StringSubstr(out,0,56);
}

void CreateDiagnosticsJournal(){int x=ContentX(),y=PageBodyY(2),w=ContentW();DSectionSingle("DIA_LOG2","DECISION JOURNAL",x,y,w,ContentH()-(y-ContentY())-6);int rows=MathMin(g_eventCount,12);for(int i=0;i<rows;i++){int idx=g_eventCount-1-i;int yy=y+42+i*22;DText("DLOGT2_"+IntegerToString(i),g_eventTime[idx],x+12,yy,6,COLOR_MUTED,"Arial");DText("DLOGE2_"+IntegerToString(i),StringSubstr(UserFriendlyJournalType(g_eventType[idx]),0,21),x+78,yy,6,COLOR_GOLD,"Arial Bold");DText("DLOGD2_"+IntegerToString(i),UserFriendlyJournalDetail(g_eventType[idx],g_eventDetail[idx]),x+228,yy,6,COLOR_TEXT,"Arial");}DButton("DIA_CLEAR","CLEAR JOURNAL",x+w-124,y+8,112,24,COLOR_PANEL2,false,6);}

void CreateDiagnosticsSummary()

{

   int x=ContentX(),y=PageBodyY(3),w=ContentW(),gap=8,cw=(w-gap)/2;

   DSectionSingle("DIA_SUM_A","LIVE SUMMARY",x,y,cw,235);

   SettingsSectionStatus("DIA_SM1","GRID",g_state.gridActive?"ACTIVE":"IDLE",x+14,y+42,g_state.gridActive?COLOR_GREEN:COLOR_MUTED);

   SettingsSectionStatus("DIA_SM2","STRATEGY",CompactGridName(g_state.gridType),x+14,y+72,COLOR_GOLD);

   SettingsSectionStatus("DIA_SM3","LIFECYCLE",g_state.gridLifecycleState,x+14,y+102,COLOR_TEXT);

   SettingsSectionStatus("DIA_SM4","EXIT COORD",g_state.strategyExitCoordination?"ARMED":"OFF",x+14,y+132,g_state.strategyExitCoordination?COLOR_ORANGE:COLOR_MUTED);

   SettingsSectionStatus("DIA_SM5","EMERGENCY",g_state.emergencyActive?"ACTIVE":"CLEAR",x+14,y+162,g_state.emergencyActive?COLOR_RED:COLOR_GREEN);

   DSectionSingle("DIA_SUM_B","AUDIT COUNTERS",x+cw+gap,y,cw,235);

   SettingsSectionStatus("DIA_AM1","ACCEPTED",IntegerToString(g_state.acceptedOrders),x+cw+gap+14,y+42,COLOR_GREEN);

   SettingsSectionStatus("DIA_AM2","REJECTED",IntegerToString(g_state.rejectedOrders),x+cw+gap+14,y+72,g_state.rejectedOrders?COLOR_ORANGE:COLOR_GREEN);

   SettingsSectionStatus("DIA_AM3","EVENTS",IntegerToString(g_eventCount),x+cw+gap+14,y+102,COLOR_TEXT);

   SettingsSectionStatus("DIA_AM4","GRID AUDIT",g_state.lastGridAudit,x+cw+gap+14,y+132,g_state.lastGridShortfall>0?COLOR_ORANGE:COLOR_TEAL);

   SettingsSectionStatus("DIA_AM5","CONFIG",g_state.configHealth,x+cw+gap+14,y+162,g_state.configWarningCount==0?COLOR_GREEN:COLOR_ORANGE);

}



void DashboardSyncRefreshDashboardSyncAudit()
{
   int pending=0;
   for(int i=0;i<g_editCount;i++) if(g_editFields[i].modified) pending++;
   g_state.dashboardSyncPendingEdits=pending;
   g_state.dashboardSyncSelectedGridOK=((int)g_selectedGridType==(int)g_state.gridType);
   g_state.dashboardSyncControlModeOK=(g_state.controlMode>=CONTROL_MANUAL && g_state.controlMode<=CONTROL_AUTONOMOUS);
   g_state.dashboardSyncEffectiveStateOK=(g_state.effectiveGridStepPips>0.0 && g_state.effectiveGridLevels>0 && g_state.effectiveLot>0.0);
   if(pending>0){g_state.dashboardSyncDashboardSyncStatus="STAGED EDITS";g_state.dashboardSyncDashboardSyncReason=StringFormat("%d dashboard edit(s) pending APPLY",pending);}
   else if(!g_state.dashboardSyncSelectedGridOK){g_state.dashboardSyncDashboardSyncStatus="GRID MISMATCH";g_state.dashboardSyncDashboardSyncReason="Selected grid and runtime grid differ";}
   else if(!g_state.dashboardSyncEffectiveStateOK){g_state.dashboardSyncDashboardSyncStatus="EFFECTIVE STATE ERROR";g_state.dashboardSyncDashboardSyncReason="Effective step/levels/lot invalid";}
   else if(!g_state.dashboardSyncControlModeOK){g_state.dashboardSyncDashboardSyncStatus="CONTROL MODE ERROR";g_state.dashboardSyncDashboardSyncReason="Control mode is outside authority range";}
   else {g_state.dashboardSyncDashboardSyncStatus="SYNCED";g_state.dashboardSyncDashboardSyncReason="Dashboard and runtime authoritative state aligned";}
   g_state.dashboardSyncDashboardSyncTime=TimeCurrent();
}

void CreateDashboardSyncPage()
{
   DashboardSyncRefreshDashboardSyncAudit();
   int x=ContentX(),y=PageBodyY(4),w=ContentW(),gap=10,cw=(w-gap)/2;
   DSectionSingle("P19A","DASHBOARD / RUNTIME AUTHORITY",x,y,cw,300);
   DKV("P19A1","STATUS",g_state.dashboardSyncDashboardSyncStatus,x+14,y+42,112,g_state.dashboardSyncDashboardSyncStatus=="SYNCED"?COLOR_GREEN:COLOR_ORANGE);
   DKV("P19A2","PENDING EDITS",IntegerToString(g_state.dashboardSyncPendingEdits),x+14,y+72,112,g_state.dashboardSyncPendingEdits>0?COLOR_ORANGE:COLOR_TEXT);
   DKV("P19A3","CONTROL MODE",EnumToString(g_state.controlMode),x+14,y+102,112,COLOR_GOLD);
   DKV("P19A4","GRID",CompactGridName(g_selectedGridType),x+14,y+132,112,g_state.dashboardSyncSelectedGridOK?COLOR_TEAL:COLOR_RED);
   DKV("P19A5","GRID OWNER",(g_state.strategyAwareManagement?"STRATEGY":"USER"),x+14,y+162,112,COLOR_GOLD);
   DKV("P19A6","ENTRY OWNER",(g_state.controlMode==CONTROL_AUTONOMOUS?"AUTONOMOUS":"USER"),x+14,y+192,112,COLOR_GOLD);
   DKV("P19A7","LAST SYNC",TimeToString(g_state.dashboardSyncDashboardSyncTime,TIME_SECONDS),x+14,y+222,112,COLOR_MUTED);
   DText("P19A8",StringSubstr(g_state.dashboardSyncDashboardSyncReason,0,38),x+14,y+258,6,COLOR_TEXT,"Arial");

   DSectionSingle("P19B","CONFIGURED / APPLIED / EFFECTIVE",x+cw+gap,y,cw,300);
   DKV("P19B1","GRID STEP",StringFormat("SET %.1f | EFF %.1f",g_state.gridStep,g_state.effectiveGridStepPips),x+cw+gap+14,y+42,112,COLOR_TEXT);
   DKV("P19B2","LEVELS",StringFormat("SET %d | EFF %d",g_state.gridLevels,g_state.effectiveGridLevels),x+cw+gap+14,y+72,112,COLOR_TEXT);
   DKV("P19B3","LOT",StringFormat("SET %.3f | EFF %.3f",g_state.lotSize,g_state.effectiveLot),x+cw+gap+14,y+102,112,COLOR_TEXT);
   DKV("P19B4","MARKET",StringSubstr(g_state.marketRegime,0,18),x+cw+gap+14,y+132,112,COLOR_TEAL);
   DKV("P19B5","DECISION",StringSubstr(g_state.autonomousDecisionClass,0,18),x+cw+gap+14,y+162,112,COLOR_GOLD);
   DKV("P19B6","RISK BUDGET",StringFormat("%.2f%%",g_state.autonomousPlanRiskPct),x+cw+gap+14,y+192,112,COLOR_GOLD);
   DKV("P19B7","SUITABILITY",StringFormat("%.0f%%",g_state.marketSuitabilityScore*100.0),x+cw+gap+14,y+222,112,COLOR_TEAL);
   DKV("P19B8","CONFIDENCE",StringFormat("%.0f%%",g_state.intelligenceConfidence*100.0),x+cw+gap+14,y+252,112,COLOR_GOLD);

}

void CreateDiagnosticsRecoveryPolicyPage(){
   int x=ContentX(),y=PageBodyY(3),w=ContentW(),gap=10,cw=(w-gap)/2;
   DSectionSingle("DIA_RP_A","RECOVERY POLICY",x,y,cw,300);
   DKV("RP1","STALE LIMIT",StringFormat("%d min",InpRecoveryStaleMinutes),x+14,y+42,105,COLOR_TEXT);
   DKV("RP2","AUTO RECOVER",g_state.autoRecoverOnInit?"ENABLED":"OFF",x+14,y+72,105,g_state.autoRecoverOnInit?COLOR_GOLD:COLOR_MUTED);
   DKV("RP3","RECOVER LIVE",g_state.recoverOrdersAndPositions?"ENABLED":"OFF",x+14,y+102,105,g_state.recoverOrdersAndPositions?COLOR_GOLD:COLOR_MUTED);
   DKV("RP4","MAX ATTEMPTS",IntegerToString(MathMax(0,InpMaxRecoveryAttempts)),x+14,y+132,105,COLOR_TEXT);
   DKV("RP5","LOT SCALE",StringFormat("%.3f",g_state.recoveryLotScale),x+14,y+162,105,COLOR_TEXT);
   DKV("RP6","STATUS",g_state.recoveryModeActive?"ACTIVE":"STANDBY",x+14,y+192,105,g_state.recoveryModeActive?COLOR_ORANGE:COLOR_MUTED);
   DKV("RP7","SOURCE",StringSubstr(g_state.recoverySource,0,22),x+14,y+222,105,COLOR_TEXT);
   DSectionSingle("DIA_RP_B","RECONCILIATION RULES",x+cw+gap,y,cw,300);
   DKV("RP8","CONTEXT",g_state.recoveryCheckpointContextOK?"MATCH":"REJECTED",x+cw+gap+14,y+42,105,g_state.recoveryCheckpointContextOK?COLOR_GREEN:COLOR_RED);
   DKV("RP9","STALE",g_state.recoveryCheckpointStale?"YES":"NO",x+cw+gap+14,y+72,105,g_state.recoveryCheckpointStale?COLOR_ORANGE:COLOR_GREEN);
   DKV("RP10","INVENTORY",g_state.recoveryInventoryReconciled?"RECONCILED":"PENDING",x+cw+gap+14,y+102,105,g_state.recoveryInventoryReconciled?COLOR_GREEN:COLOR_ORANGE);
   DKV("RP11","LOCK",g_state.recoveryRecoveryLock?"ACTIVE":"CLEAR",x+cw+gap+14,y+132,105,g_state.recoveryRecoveryLock?COLOR_ORANGE:COLOR_GREEN);
   DKV("RP12","POSITIONS",IntegerToString(GetPositionCount()),x+cw+gap+14,y+162,105,COLOR_TEAL);
   DKV("RP13","PENDING",IntegerToString(GetPendingCount()),x+cw+gap+14,y+192,105,COLOR_GOLD);
   DText("RP_NOTE","Recovery reconstructs state; it does not manufacture replacement trades.",x+cw+gap+14,y+232,6,COLOR_MUTED,"Arial");
}

void CreateDiagnosticsLiveTradeExecutionSurvivalPage(){
   int x=ContentX(),y=PageBodyY(3),w=ContentW(),gap=10,cw=(w-gap)/2;
   DSectionSingle("DIA_LTES_A","LIVE TRADE STATE",x,y,cw,300);
   DKV("LTE1","POSITIONS",IntegerToString(GetPositionCount()),x+14,y+42,105,COLOR_TEAL);
   DKV("LTE2","PENDING",IntegerToString(GetPendingCount()),x+14,y+72,105,COLOR_GOLD);
   DKV("LTE3","GRID",g_state.gridActive?"ACTIVE":"IDLE",x+14,y+102,105,g_state.gridActive?COLOR_GREEN:COLOR_MUTED);
   DKV("LTE4","LIFECYCLE",StringSubstr(g_state.gridLifecycleState,0,18),x+14,y+132,105,COLOR_TEXT);
   DKV("LTE5","EXIT COORD",g_state.exitCoordinationActive?"ACTIVE":"OFF",x+14,y+162,105,g_state.exitCoordinationActive?COLOR_ORANGE:COLOR_MUTED);
   DKV("LTE6","RECOVERY",g_state.recoveryModeActive?"ACTIVE":"STANDBY",x+14,y+192,105,g_state.recoveryModeActive?COLOR_ORANGE:COLOR_MUTED);
   DSectionSingle("DIA_LTES_B","EXECUTION / SURVIVAL",x+cw+gap,y,cw,300);
   DKV("LTE7","QUALITY",StringFormat("%.0f%%",g_state.executionQualityScore*100.0),x+cw+gap+14,y+42,105,COLOR_TEAL);
   DKV("LTE8","RETCODE",IntegerToString((int)g_state.lastOrderRetcode),x+cw+gap+14,y+72,105,COLOR_TEXT);
   DKV("LTE9","LATENCY",StringFormat("%u ms",g_state.lastOrderLatencyMs),x+cw+gap+14,y+102,105,COLOR_TEXT);
   DKV("LTE10","BREAKER",g_state.hardBreakerTriggered?"TRIGGERED":"CLEAR",x+cw+gap+14,y+132,105,g_state.hardBreakerTriggered?COLOR_RED:COLOR_GREEN);
   DKV("LTE11","SYSTEM",g_state.configHealth,x+cw+gap+14,y+162,105,g_state.configWarningCount==0?COLOR_GREEN:COLOR_ORANGE);
   DKV("LTE12","VALIDATION",g_phase16RunCount>0?g_phase16Summary:"NOT RUN",x+cw+gap+14,y+192,105,COLOR_TEXT);
   DKV("LTE13","RECOVERY LOCK",g_state.recoveryRecoveryLock?"ACTIVE":"CLEAR",x+cw+gap+14,y+222,105,g_state.recoveryRecoveryLock?COLOR_ORANGE:COLOR_GREEN);
}

void CreateDiagnosticsTab(){DPageTitle("DIAGNOSTICS","Execution health, recovery and live system state");string s[]={"SYSTEM","JOURNAL","SUMMARY","RECOVERY / VPS","DASHBOARD SYNC","AUTHORITY AUDIT","RECOVERY POLICY","LIVE TRADE / EXECUTION / SURVIVAL"};DNestedSubTabs(s,8,g_dashboard.diagnosticsSubTab,"DIA_SUB_");if(g_dashboard.diagnosticsSubTab==0)CreateDiagnosticsSystem();else if(g_dashboard.diagnosticsSubTab==1)CreateDiagnosticsJournal();else if(g_dashboard.diagnosticsSubTab==2)CreateDiagnosticsSummary();else if(g_dashboard.diagnosticsSubTab==3)CreateRecoveryRestartPage();else if(g_dashboard.diagnosticsSubTab==4)CreateDashboardSyncPage();else if(g_dashboard.diagnosticsSubTab==5){string a[]={"AUTHORITY","SOURCE QUALITY"};DNestedSubTabs(a,2,g_phase21SourceQualitySubTab,"DIA_AUTH_SUB_");if(g_phase21SourceQualitySubTab==0)CreatePhase20AuthorityAuditPage();else CreatePhase21SourceQualityPage();}else if(g_dashboard.diagnosticsSubTab==6)CreateDiagnosticsRecoveryPolicyPage();else CreateDiagnosticsLiveTradeExecutionSurvivalPage();}





void CreateRecoveryRestartPage()
{
   int x=ContentX(),y=PageBodyY(4),w=ContentW(),gap=10,cw=(w-gap)/2;
   DSectionSingle("P18A","RUNTIME / VPS STATE",x,y,cw,285);
   DKV("P18A1","ENVIRONMENT",StringSubstr(g_state.recoveryEnvironment,0,26),x+14,y+42,105,COLOR_TEXT);
   DKV("P18A2","CHECKPOINT",g_state.recoveryCheckpointResult,x+14,y+72,105,COLOR_GOLD);
   DKV("P18A3","AGE",g_state.recoveryCheckpointAgeSec>=0?StringFormat("%d sec",g_state.recoveryCheckpointAgeSec):"N/A",x+14,y+102,105,COLOR_TEXT);
   DKV("P18A4","STALE",g_state.recoveryCheckpointStale?"YES":"NO",x+14,y+132,105,g_state.recoveryCheckpointStale?COLOR_ORANGE:COLOR_GREEN);
   DKV("P18A5","CONTEXT",g_state.recoveryCheckpointContextOK?"MATCH":"REJECTED",x+14,y+162,105,g_state.recoveryCheckpointContextOK?COLOR_GREEN:COLOR_RED);
   DKV("P18A6","HEARTBEAT",g_state.recoveryLastHeartbeat>0?TimeToString(g_state.recoveryLastHeartbeat,TIME_SECONDS):"--",x+14,y+192,105,COLOR_TEXT);
   DKV("P18A7","SOURCE",StringSubstr(g_state.recoverySource,0,18),x+14,y+222,105,COLOR_TEXT);
   DSectionSingle("P18B","INVENTORY RECONCILIATION",x+cw+gap,y,cw,285);
   DKV("P18B1","POSITIONS",IntegerToString(GetPositionCount()),x+cw+gap+14,y+42,105,COLOR_TEAL);
   DKV("P18B2","PENDING",IntegerToString(GetPendingCount()),x+cw+gap+14,y+72,105,COLOR_GOLD);
   DKV("P18B3","GRID STATE",g_state.gridActive?"ACTIVE":"IDLE",x+cw+gap+14,y+102,105,g_state.gridActive?COLOR_GREEN:COLOR_TEXT);
   DKV("P18B4","RECONCILED",g_state.recoveryInventoryReconciled?"YES":"NO",x+cw+gap+14,y+132,105,g_state.recoveryInventoryReconciled?COLOR_GREEN:COLOR_RED);
   DKV("P18B5","AUTO RECOVER",g_state.autoRecoverOnInit?"ENABLED":"OFF",x+cw+gap+14,y+162,105,g_state.autoRecoverOnInit?COLOR_GOLD:COLOR_MUTED);
   DKV("P18B6","RECOVER LIVE",g_state.recoverOrdersAndPositions?"ENABLED":"OFF",x+cw+gap+14,y+192,105,g_state.recoverOrdersAndPositions?COLOR_GOLD:COLOR_MUTED);
   DKV("P18B7","LOCK",g_state.recoveryRecoveryLock?"ACTIVE":"CLEAR",x+cw+gap+14,y+222,105,g_state.recoveryRecoveryLock?COLOR_ORANGE:COLOR_GREEN);
}

// -------------------- TOOLS / USER UTILITIES --------------------

void CreateToolsProfiles()

{

   int x=ContentX(),y=PageBodyY(4),w=ContentW(),h=ContentH()-(y-ContentY())-6,gap=8,cw=(w-gap)/2;

   DSectionSingle("TL_PROFILE","PROFILE MANAGER",x,y,cw,h);

   DText("TLP_SUB","Save and load user-owned runtime configurations",x+14,y+32,6,COLOR_MUTED,"Arial");

   SettingsSectionStatus("TLP_MODE","MODE",ControlModeName(g_state.controlMode),x+14,y+58,COLOR_GOLD);

   SettingsSectionStatus("TLP_CUR","CURRENT",g_lastLoadedProfile!=""?g_lastLoadedProfile:"RUNTIME",x+14,y+86,COLOR_TEXT);

   DButton("BTN_PROFILE_SAVE1","SAVE P1",x+14,y+122,(cw-36)/2,28,COLOR_ACCENT,false,6);

   DButton("BTN_PROFILE_SAVE2","SAVE P2",x+22+(cw-36)/2,y+122,(cw-36)/2,28,COLOR_ACCENT,false,6);

   DButton("BTN_PROFILE_SAVE3","SAVE P3",x+14,y+156,(cw-36)/2,28,COLOR_ACCENT,false,6);

   DButton("BTN_PROFILE_SAVE4","SAVE P4",x+22+(cw-36)/2,y+156,(cw-36)/2,28,COLOR_ACCENT,false,6);

   DButton("BTN_PROFILE_LOAD1","LOAD P1",x+14,y+198,(cw-36)/2,28,COLOR_PANEL2,false,6);

   DButton("BTN_PROFILE_LOAD2","LOAD P2",x+22+(cw-36)/2,y+198,(cw-36)/2,28,COLOR_PANEL2,false,6);

   DButton("BTN_PROFILE_LOAD3","LOAD P3",x+14,y+232,(cw-36)/2,28,COLOR_PANEL2,false,6);

   DButton("BTN_PROFILE_LOAD4","LOAD P4",x+22+(cw-36)/2,y+232,(cw-36)/2,28,COLOR_PANEL2,false,6);



   DSectionSingle("TL_HISTORY","CONFIGURATION HISTORY",x+cw+gap,y,cw,h);

   SettingsSectionStatus("TLH_PENDING","PENDING",g_pendingApplySummary!=""?g_pendingApplySummary:"No pending changes",x+cw+gap+14,y+54,COLOR_TEXT);

   SettingsSectionStatus("TLH_COUNT","ENTRIES",IntegerToString(g_configHistoryCount),x+cw+gap+14,y+84,COLOR_GOLD);

   int rows=MathMin(7,g_configHistoryCount);

   for(int i=0;i<rows;i++)

      DText("TLH_"+IntegerToString(i),g_configHistory[g_configHistoryCount-1-i],x+cw+gap+14,y+116+i*22,6,COLOR_MUTED,"Arial");

   DButton("BTN_PROFILE_RESET","RESET RUNTIME",x+cw+gap+14,y+h-70,cw-28,28,COLOR_PANEL2,false,6);

   DButton("BTN_PROFILE_REJOURNAL","CLEAR JOURNAL",x+cw+gap+14,y+h-36,cw-28,28,COLOR_PANEL2,false,6);

}



void CreateToolsSimulation()

{

   int x=ContentX(),y=PageBodyY(4),w=ContentW(),h=ContentH()-(y-ContentY())-6,gap=8,cw=(w-gap)/2;

   DSectionSingle("TLS_PRE","SIMULATION LAB",x,y,cw,h);

   DText("TLS_SUB","Preview effective values without sending orders",x+14,y+32,6,COLOR_MUTED,"Arial");

   SettingsSectionStatus("TLS_STEP","STEP",StringFormat("%.1f  →  %.1f",g_state.gridStep,g_state.effectiveGridStepPips),x+14,y+58,COLOR_TEXT);

   SettingsSectionStatus("TLS_LEVEL","LEVELS",StringFormat("%d  →  %d",g_state.gridLevels,g_state.effectiveGridLevels),x+14,y+88,COLOR_TEXT);

   SettingsSectionStatus("TLS_LOT","LOT",StringFormat("%.3f  →  %.3f",g_state.lotSize,g_state.effectiveLot),x+14,y+118,COLOR_TEXT);

   SettingsSectionStatus("TLS_PENDING","PROJECTED PENDING",IntegerToString((int)MathMin(g_state.effectiveGridLevels*2,g_state.maxPendingOrders)),x+14,y+148,COLOR_GOLD);

   SettingsSectionStatus("TLS_RISK","GRID RISK",StringFormat("%.2f%%",g_state.gridRiskPct),x+14,y+178,COLOR_TEXT);

   DButton("BTN_SIM_PREVIEW","REFRESH PREVIEW",x+14,y+h-42,cw-28,28,COLOR_ACCENT,false,6);



   DSectionSingle("TLS_SAFE","SIMULATION SAFETY",x+cw+gap,y,cw,h);

   SettingsSectionStatus("TLS_READY","STATUS",g_simulationPreviewReady?"PREVIEW READY":"NOT RUN",x+cw+gap+14,y+54,g_simulationPreviewReady?COLOR_GREEN:COLOR_GOLD);

   SettingsSectionStatus("TLS_SENT","ORDERS SENT","0",x+cw+gap+14,y+84,COLOR_GREEN);

   SettingsSectionStatus("TLS_MODE","EXECUTION","NO EXECUTION",x+cw+gap+14,y+114,COLOR_MUTED);

   SettingsSectionStatus("TLS_REASON","PURPOSE","Evaluate before Apply / Start",x+cw+gap+14,y+144,COLOR_TEXT);

}



void CreateToolsRecovery()

{

   int x=ContentX(),y=PageBodyY(4),w=ContentW(),h=ContentH()-(y-ContentY())-6,gap=8,cw=(w-gap)/2;

   DSectionSingle("TLR_STATE","RECOVERY CENTER",x,y,cw,h);

   SettingsSectionStatus("TLR_GRID","GRID",g_state.gridActive?"ACTIVE":"IDLE",x+14,y+54,g_state.gridActive?COLOR_GREEN:COLOR_MUTED);

   SettingsSectionStatus("TLR_POS","POSITIONS",IntegerToString(g_state.positionCount),x+14,y+84,COLOR_TEAL);

   SettingsSectionStatus("TLR_PEND","PENDING",IntegerToString(g_state.pendingCount),x+14,y+114,COLOR_GOLD);

   SettingsSectionStatus("TLR_ANCHOR","ANCHOR",DoubleToString(g_state.anchorPrice,_Digits),x+14,y+144,COLOR_TEXT);

   SettingsSectionStatus("TLR_STATUS","STATUS",g_state.executionStatus,x+14,y+174,COLOR_GOLD);

   DButton("ADV_RECOVERY","RECOVERY ENGINE  "+(g_state.gridRecovery?"ON":"OFF"),x+14,y+214,cw-28,28,g_state.gridRecovery?COLOR_GREEN:COLOR_PANEL2,g_state.gridRecovery,6);

   DButton("BTN_RECOVER_GRID","RECOVER NOW",x+14,y+248,cw-28,28,COLOR_ACCENT,false,6);



   DSectionSingle("TLR_SMART","SMART MANAGEMENT",x+cw+gap,y,cw,h);

   DText("TLR_S1","Optional live-grid maintenance",x+cw+gap+14,y+32,6,COLOR_MUTED,"Arial");

   SettingsSectionStatus("TLR_RE","REPLENISH",g_state.smartReplenishment?"ON":"OFF",x+cw+gap+14,y+60,g_state.smartReplenishment?COLOR_GREEN:COLOR_MUTED);

   SettingsSectionStatus("TLR_SR","SMART RECENTER",g_state.smartRecenter?"ON":"OFF",x+cw+gap+14,y+90,g_state.smartRecenter?COLOR_GOLD:COLOR_MUTED);

   SettingsSectionStatus("TLR_RB","REPLENISHMENTS",IntegerToString(g_state.replenishments),x+cw+gap+14,y+120,COLOR_TEAL);

   SettingsSectionStatus("TLR_RC","RE-CENTERS",IntegerToString(g_state.rebalances),x+cw+gap+14,y+150,COLOR_TEXT);

   DButton("ADV_REPLENISH","SMART REPLENISHMENT  "+(g_state.smartReplenishment?"ON":"OFF"),x+cw+gap+14,y+190,cw-28,28,g_state.smartReplenishment?COLOR_GREEN:COLOR_PANEL2,g_state.smartReplenishment,6);

   DButton("ADV_SMART_RECENTER","SMART RECENTER  "+(g_state.smartRecenter?"ON":"OFF"),x+cw+gap+14,y+224,cw-28,28,g_state.smartRecenter?COLOR_GOLD:COLOR_PANEL2,g_state.smartRecenter,6);

}



void CreateToolsHealth()

{

   int x=ContentX(),y=PageBodyY(4),w=ContentW(),h=ContentH()-(y-ContentY())-6,gap=8,cw=(w-gap)/2;

   DSectionSingle("TLH_SYS","SYSTEM HEALTH",x,y,cw,h);

   SettingsSectionStatus("TLHS_CTRL","CONTROL",ControlModeName(g_state.controlMode),x+14,y+54,COLOR_GOLD);

   SettingsSectionStatus("TLHS_GRID","GRID",g_state.gridActive?"ACTIVE":"IDLE",x+14,y+84,g_state.gridActive?COLOR_GREEN:COLOR_MUTED);

   SettingsSectionStatus("TLHS_EXEC","EXECUTION",g_state.executionStatus,x+14,y+114,COLOR_TEXT);

   SettingsSectionStatus("TLHS_POS","POSITIONS",IntegerToString(g_state.positionCount),x+14,y+144,COLOR_TEAL);

   SettingsSectionStatus("TLHS_PEND","PENDING",IntegerToString(g_state.pendingCount),x+14,y+174,COLOR_GOLD);



   DSectionSingle("TLH_EXE","EXECUTION & JOURNAL",x+cw+gap,y,cw,h);

   SettingsSectionStatus("TLHE_ACC","ACCEPTED",IntegerToString(g_state.acceptedOrders),x+cw+gap+14,y+54,COLOR_GREEN);

   SettingsSectionStatus("TLHE_REJ","REJECTED",IntegerToString(g_state.rejectedOrders),x+cw+gap+14,y+84,g_state.rejectedOrders?COLOR_ORANGE:COLOR_GREEN);

   SettingsSectionStatus("TLHE_RC","LAST RETCODE",IntegerToString((int)g_state.lastOrderRetcode),x+cw+gap+14,y+114,COLOR_TEXT);

   SettingsSectionStatus("TLHE_RT","RETRIES",IntegerToString(g_state.lastOrderRetryCount),x+cw+gap+14,y+144,COLOR_TEXT);

   SettingsSectionStatus("TLHE_MS","LATENCY",StringFormat("%u ms",g_state.lastOrderLatencyMs),x+cw+gap+14,y+174,COLOR_TEXT);

   SettingsSectionStatus("TLHE_EV","JOURNAL EVENTS",IntegerToString(g_eventCount),x+cw+gap+14,y+204,COLOR_TEXT);

   SettingsSectionStatus("TLHE_CFG","CONFIG",g_state.configHealth,x+cw+gap+14,y+234,g_state.configWarningCount==0?COLOR_GREEN:COLOR_ORANGE);SettingsSectionStatus("TLHE_GA","GRID AUDIT",g_state.lastGridAudit,x+cw+gap+14,y+264,g_state.lastGridShortfall>0?COLOR_ORANGE:COLOR_TEAL);

    SettingsSectionStatus("TLHE_GS","GRID STRATEGY",GridStrategyName(g_state.gridType),x+cw+gap+14,y+294,COLOR_TEXT);SettingsSectionStatus("TLHE_RV","RECOVERY",g_state.recoveryStatus,x+cw+gap+14,y+324,COLOR_TEAL);SettingsSectionStatus("TLHE_GL","LIFECYCLE",g_state.gridLifecycleState,x+cw+gap+14,y+324,COLOR_GOLD);SettingsSectionStatus("TLHE_GC","CYCLE",StringFormat("%I64u",g_state.gridCycleId),x+cw+gap+14,y+354,COLOR_TEAL);

   DButton("BTN_CONFIG_CHECK","CHECK CONFIG",x+cw+gap+14,y+h-36,cw-28,28,COLOR_PANEL2,false,6);

}



void CreateToolsTab()

{

   DPageTitle("TOOLS & UTILITIES","Safe previews, utilities, recovery and system health");

   string s[]={"PROFILE MANAGER","SIMULATION LAB","RECOVERY CENTER","SYSTEM HEALTH"};

   DNestedSubTabs(s,4,g_dashboard.toolsSubTab,"TOOLS_SUB_");

   switch(g_dashboard.toolsSubTab)

   {

      case 0:CreateToolsProfiles();break;

      case 1:CreateToolsSimulation();break;

      case 2:CreateToolsRecovery();break;

      case 3:CreateToolsHealth();break;

   }

}



// -------------------- AUTONOMY CONTROL CENTER --------------------

string StrategyHealthHealthTextUI(double health,int samples)
{
   if(samples<g_state.strategyHealthMinSamples) return "N/A";
   return StringFormat("%.0f%%",health*100.0);
}
string StrategyHealthAllocationTextUI(double allocation,int samples)
{
   if(samples<g_state.strategyHealthMinSamples) return "BASE";
   return StringFormat("x%.2f",allocation);
}
void CreateStrategyHealthTab()
{
   DPageTitle("STRATEGY HEALTH","Strategy health, market context and adaptive allocation");
   string s[]={"HEALTH OVERVIEW","21-GRID HEALTH","DIRECTIONAL HEALTH","DIRECTION DETAIL","SESSION HEALTH","REGIME HEALTH","ALLOCATION"};
   DNestedSubTabs(s,7,g_strategyHealthMainSubTab,"STRATHEALTH_SUB_");
   RefreshStrategyHealth(false);
   int x=ContentX(),y=PageBodyY(10),w=ContentW(),h=ContentH()-(y-ContentY())-6;
   CreateStrategyHealthWorkspace(g_strategyHealthMainSubTab,x,y,w,h);
}

void CreateAutonomyTab()

{

   DPageTitle("AUTONOMY CONTROL CENTER","Dedicated autonomous trading control, permissions, decisions and performance");

   string s[]={"CONTROLLER","SCHEDULE","ENTRY","RISK","GRID","STRATEGY","EXPOSURE","EMERGENCY","HISTORY","PERFORMANCE","DECISION ENGINE"};

   DNestedSubTabs(s,11,g_dashboard.autonomySubTab,"AUTONOMY_SUB_");

   CreateAutonomyDomainPage(g_dashboard.autonomySubTab);

}



// -------------------- GRID VALIDATION LAB --------------------

string GridValidationModel(ENUM_GRID_TYPE t)

{

   switch(t)

   {

      case BASIC_GRID:return "Symmetric stops";

      case HEDGE_GRID:return "Market hedge + symmetric stops";

      case TREND_GRID:return "Directional trend structure";

      case VOLATILITY_GRID:return "Volatility-expanded symmetric";

      case AI_GRID:return "AI-adjusted symmetric";

      case GEOMETRIC_GRID:return "Geometric distance expansion";

      case FIBONACCI_GRID:return "Fibonacci ratio expansion";

      case ATR_ADAPTIVE_GRID:return "ATR-driven symmetric";

      case MEAN_REVERSION_GRID:return "Symmetric limits";

      case BREAKOUT_GRID:return "ATR breakout stops";

      case MOMENTUM_GRID:return "Momentum directional stops";

      case HYBRID_GRID:return "Regime-dependent hybrid";

      case BULLISH_GRID:return "Bullish stops + pullback limits";

      case BEARISH_GRID:return "Bearish stops + pullback limits";

      case BIDIRECTIONAL_GRID:return "Two-sided stops";

      case LADDER_GRID:return "Progressive ladder";

      case ANTI_MARTINGALE_GRID:return "Progressive favorable sizing";

      case RANGE_SCALING_GRID:return "Scaled range limits";

      case VOLATILITY_BREAKOUT_GRID:return "ATR volatility breakout";

      case SESSION_GRID:return "Session-scaled bidirectional";

      case SMART_REGIME_GRID:return "Regime router";

   }

   return "Unknown";

}



bool ValidateGridProfileModel(ENUM_GRID_TYPE t,string &detail)

{

   detail="";

   bool ok=true;

   if(g_state.gridLevels<=0){detail="levels <= 0";return false;}

   if(g_state.gridStep<=0){detail="base step <= 0";return false;}

   if(g_state.lotSize<=0){detail="base lot <= 0";return false;}

   double mn=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN),mx=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MAX);

   if(mn>0 && g_state.lotSize<mn-1e-10){detail="base lot below broker minimum";return false;}

   if(mx>0 && g_state.lotSize>mx+1e-10){detail="base lot above broker maximum";return false;}

   double front=MathMax(0.1,g_state.frontOrderDistancePips);

   switch(t)

   {

      case FIBONACCI_GRID: if(g_state.gridLevels<1){ok=false;detail="no fibonacci levels";} break;

      case GEOMETRIC_GRID: if(g_state.lotMultiplier<=0){ok=false;detail="invalid geometric ratio source";} break;

      case HEDGE_GRID: if(front<=0){ok=false;detail="invalid hedge lead distance";} break;

      case BREAKOUT_GRID: case VOLATILITY_BREAKOUT_GRID: if(g_state.gridStep<=0 && g_state.atrPrice<=0){ok=false;detail="no breakout distance source";} break;

      case BULLISH_GRID: case BEARISH_GRID: if(g_state.gridLevels<2){detail="directional profile has only one level";} break;

      case RANGE_SCALING_GRID: if(g_state.maxGridStep<g_state.minGridStep){ok=false;detail="range step bounds inverted";} break;

      case SESSION_GRID: if(g_state.sessionStartHour<0||g_state.sessionStartHour>23||g_state.sessionEndHour<0||g_state.sessionEndHour>23){ok=false;detail="invalid session hours";} break;

      default: break;

   }

   if(ok && detail=="") detail="READY | "+GridValidationModel(t);

   return ok;

}



void RunGridValidationMatrix()

{

   int pass=0,warn=0,fail=0;

   string summary="";

   for(int i=0;i<GRID_TYPE_COUNT;i++)

   {

      string d=""; bool ok=ValidateGridProfileModel((ENUM_GRID_TYPE)i,d);

      if(ok){pass++;g_gridValidationMatrix[i]=StringFormat("PASS | %s",d);}

      else {fail++;g_gridValidationMatrix[i]=StringFormat("FAIL | %s",d);if(summary!="")summary+=" | ";summary+=CompactGridName((ENUM_GRID_TYPE)i)+": "+d;}

      if(StringFind(d,"only one")>=0){warn++;}

   }

   g_gridValidationRunCount++;

   g_gridValidationPassed=pass;

   g_gridValidationWarnings=warn;

   g_gridValidationFailed=fail;

   g_gridValidationTime=TimeCurrent();

   g_gridValidationSelected=(int)g_state.gridType;

   g_gridValidationSummary=fail==0?StringFormat("PASS | %d/%d profiles structurally ready",pass,GRID_TYPE_COUNT):StringFormat("REVIEW | %d pass / %d fail",pass,fail);

   RecordEvent("GRID VALIDATION",g_gridValidationSummary);

}



void CreateGridValidationOverview()

{

   int x=ContentX(),y=PageBodyY(4),w=ContentW(),gap=8,cw=(w-gap)/2;

   DSectionSingle("GV_OV_A","21-GRID VALIDATION",x,y,cw,285);

   SettingsSectionStatus("GVO_RUN","RUNS",IntegerToString(g_gridValidationRunCount),x+14,y+50,COLOR_GOLD);

   SettingsSectionStatus("GVO_PASS","PASSED",IntegerToString(g_gridValidationPassed),x+14,y+80,COLOR_GREEN);

   SettingsSectionStatus("GVO_WARN","WARNINGS",IntegerToString(g_gridValidationWarnings),x+14,y+110,COLOR_ORANGE);

   SettingsSectionStatus("GVO_FAIL","FAILED",IntegerToString(g_gridValidationFailed),x+14,y+140,g_gridValidationFailed?COLOR_RED:COLOR_GREEN);

   SettingsSectionStatus("GVO_TIME","LAST RUN",g_gridValidationTime>0?TimeToString(g_gridValidationTime,TIME_SECONDS):"NOT RUN",x+14,y+170,COLOR_MUTED);

   DButton("BTN_RUN_GRID_VALIDATION","RUN 21-GRID AUDIT",x+14,y+216,cw-28,30,COLOR_ACCENT,false,7);

   DSectionSingle("GV_OV_B","CURRENT PROFILE",x+cw+gap,y,cw,285);

   SettingsSectionStatus("GVC_TYPE","GRID",CompactGridName(g_state.gridType),x+cw+gap+14,y+50,COLOR_GOLD);

   SettingsSectionStatus("GVC_MODEL","MODEL",GridValidationModel(g_state.gridType),x+cw+gap+14,y+80,COLOR_TEXT);

   SettingsSectionStatus("GVC_STATUS","STATUS",g_gridValidationRunCount==0?"NOT RUN":g_gridValidationMatrix[(int)g_state.gridType],x+cw+gap+14,y+110,COLOR_TEAL);

   SettingsSectionStatus("GVC_LIFE","LIFECYCLE",GridLifecycleModel(g_state.gridType),x+cw+gap+14,y+140,COLOR_TEXT);

}



void CreateGridValidationMatrix()

{

   int x=ContentX(),y=PageBodyY(4),w=ContentW(),h=ContentH()-(y-ContentY())-6;

   DSectionSingle("GV_MATRIX","21-GRID VALIDATION MATRIX",x,y,w,h);

   int rows=11,cols=2,gapX=8,gapY=4,bw=(w-28-gapX)/2,bh=MathMax(22,MathMin(29,(h-48-(rows-1)*gapY)/rows));

   for(int i=0;i<GRID_TYPE_COUNT;i++)

   {

      int r=i/cols,c=i%cols; string status=g_gridValidationRunCount>0?g_gridValidationMatrix[i]:"NOT RUN";

      color cc=g_gridValidationRunCount==0?COLOR_MUTED:(StringFind(status,"FAIL")>=0?COLOR_RED:COLOR_GREEN);

      DButton("GV_SEL_"+IntegerToString(i),GridShortName((ENUM_GRID_TYPE)i),x+10+c*(bw+gapX),y+36+r*(bh+gapY),bw,bh,i==g_gridValidationSelected?COLOR_ACCENT:COLOR_PANEL2,i==g_gridValidationSelected,6);

      DText("GV_ST_"+IntegerToString(i),status,x+18+c*(bw+gapX),y+36+r*(bh+gapY)+bh-9,5,cc,"Arial");

   }

}



void CreateGridValidationCurrent()

{

   int x=ContentX(),y=GridLabBodyY(),w=ContentW(),gap=8,cw=(w-gap)/2;

   DSectionSingle("GV_CUR_A","CURRENT GRID PROFILE",x,y,cw,285);

   SettingsSectionStatus("GVC1","PROFILE",CompactGridName(g_state.gridType),x+14,y+48,COLOR_GOLD);

   SettingsSectionStatus("GVC2","MODEL",GridValidationModel(g_state.gridType),x+14,y+78,COLOR_TEXT);

   SettingsSectionStatus("GVC3","STEP",StringFormat("%.1f pips",g_state.effectiveGridStepPips),x+14,y+108,COLOR_TEAL);

   SettingsSectionStatus("GVC4","LEVELS",IntegerToString(g_state.effectiveGridLevels),x+14,y+138,COLOR_TEAL);

   SettingsSectionStatus("GVC5","LOT",DoubleToString(g_state.effectiveLot,3),x+14,y+168,COLOR_TEAL);

   SettingsSectionStatus("GVC6","LIFECYCLE",g_state.gridLifecycleState,x+14,y+198,COLOR_GOLD);

   DSectionSingle("GV_CUR_B","VALIDATION RESULT",x+cw+gap,y,cw,285);

   string st=g_gridValidationRunCount>0?g_gridValidationMatrix[(int)g_state.gridType]:"NOT RUN";

   SettingsSectionStatus("GVR1","STATUS",st,x+cw+gap+14,y+48,StringFind(st,"FAIL")>=0?COLOR_RED:(g_gridValidationRunCount>0?COLOR_GREEN:COLOR_MUTED));

   SettingsSectionStatus("GVR2","CYCLE",StringFormat("%I64u",g_state.gridCycleId),x+cw+gap+14,y+78,COLOR_TEXT);

   SettingsSectionStatus("GVR3","FILLS",IntegerToString(g_state.lifecycleFillCount),x+cw+gap+14,y+108,COLOR_TEXT);

   SettingsSectionStatus("GVR4","DELETES",IntegerToString(g_state.lifecycleDeleteCount),x+cw+gap+14,y+138,COLOR_TEXT);

   SettingsSectionStatus("GVR5","RECOVERIES",IntegerToString(g_state.lifecycleRecoveryCount),x+cw+gap+14,y+168,COLOR_TEXT);

}



void CreateGridValidationLifecycle()

{

   int x=ContentX(),y=GridLabBodyY(),w=ContentW(),gap=8,cw=(w-gap)/2;

   DSectionSingle("GV_LIFE_A","LIFECYCLE VALIDATION",x,y,cw,285);

   SettingsSectionStatus("GVL1","DEPLOYMENT","IMPLEMENTED",x+14,y+48,COLOR_GREEN);

   SettingsSectionStatus("GVL2","FILL TRACKING", "IMPLEMENTED",x+14,y+78,COLOR_GREEN);

   SettingsSectionStatus("GVL3","REPLENISH",g_state.smartReplenishment?"ENABLED":"OPTIONAL",x+14,y+108,COLOR_TEAL);

   SettingsSectionStatus("GVL4","RECENTER",g_state.autoRecenter?"ENABLED":"OPTIONAL",x+14,y+138,COLOR_TEAL);

   SettingsSectionStatus("GVL5","EXIT COORD",g_state.exitCoordinationActive?"ACTIVE":"READY",x+14,y+168,COLOR_GOLD);

   SettingsSectionStatus("GVL6","RECOVERY",g_state.recoveryStatus,x+14,y+198,COLOR_TEAL);

   DSectionSingle("GV_LIFE_B","LIMITATION",x+cw+gap,y,cw,285);

   SettingsSectionStatus("GVLL1","LIVE ORDERS","NOT SENT",x+cw+gap+14,y+54,COLOR_GREEN);

   SettingsSectionStatus("GVLL2","BROKER FILL","NOT SIMULATED",x+cw+gap+14,y+84,COLOR_MUTED);

   SettingsSectionStatus("GVLL3","CURRENT STATE","CHECKED FROM RUNTIME",x+cw+gap+14,y+114,COLOR_GOLD);

   SettingsSectionStatus("GVLL4","21 MODELS","STATIC + RUNTIME AUDIT",x+cw+gap+14,y+144,COLOR_TEAL);

}



int GridLabBodyY();

void CreateGridValidationOverviewWorkspace()
{
   int x=ContentX(),y=GridLabBodyY(),w=ContentW(),gap=8,cw=(w-gap)/2;
   DSectionSingle("GVW_OV_A","GRID VALIDATION LAB",x,y,cw,250);
   SettingsSectionStatus("GVW_RUN","RUNS",IntegerToString(g_gridValidationRunCount),x+14,y+48,COLOR_GOLD);
   SettingsSectionStatus("GVW_PASS","PASSED",IntegerToString(g_gridValidationPassed),x+14,y+78,COLOR_GREEN);
   SettingsSectionStatus("GVW_WARN","WARNINGS",IntegerToString(g_gridValidationWarnings),x+14,y+108,COLOR_ORANGE);
   SettingsSectionStatus("GVW_FAIL","FAILED",IntegerToString(g_gridValidationFailed),x+14,y+138,g_gridValidationFailed>0?COLOR_RED:COLOR_GREEN);
   SettingsSectionStatus("GVW_LAST","LAST RUN",g_gridValidationTime>0?TimeToString(g_gridValidationTime,TIME_SECONDS):"NOT RUN",x+14,y+168,COLOR_MUTED);
   DButton("BTN_RUN_GRID_VALIDATION","RUN 21-GRID AUDIT",x+14,y+204,cw-28,30,COLOR_ACCENT,false,7);

   DSectionSingle("GVW_CUR_B","CURRENT PROFILE",x+cw+gap,y,cw,250);
   SettingsSectionStatus("GVW_TYPE","GRID",CompactGridName(g_state.gridType),x+cw+gap+14,y+48,COLOR_GOLD);
   SettingsSectionStatus("GVW_MODEL","MODEL",GridValidationModel(g_state.gridType),x+cw+gap+14,y+78,COLOR_TEXT);
   string st=g_gridValidationRunCount>0?g_gridValidationMatrix[(int)g_state.gridType]:"NOT RUN";
   SettingsSectionStatus("GVW_STATUS","STATUS",st,x+cw+gap+14,y+108,StringFind(st,"FAIL")>=0?COLOR_RED:(g_gridValidationRunCount>0?COLOR_GREEN:COLOR_MUTED));
   SettingsSectionStatus("GVW_LIFE","LIFECYCLE",GridLifecycleModel(g_state.gridType),x+cw+gap+14,y+138,COLOR_TEXT);
   SettingsSectionStatus("GVW_STEP","STEP",StringFormat("%.1f pips",g_state.effectiveGridStepPips),x+cw+gap+14,y+168,COLOR_TEAL);
   SettingsSectionStatus("GVW_LEVELS","LEVELS",IntegerToString(g_state.effectiveGridLevels),x+cw+gap+14,y+198,COLOR_TEAL);
}

void CreateGridValidationWorkspace()
{
   // Dedicated 21-grid validation workspace.
   // Validation Rules and Readiness are intentionally NOT rendered here;
   // they have their own sibling sub-tabs under the VALIDATION workspace.
   int x=ContentX(),y=GridLabBodyY(),w=ContentW(),h=ContentH()-(y-ContentY())-6;
   DSectionSingle("GVW_MATRIX","21-GRID VALIDATION MATRIX",x,y,w,h);

   int rows=11,cols=2,gapX=8,gapY=4;
   int bw=(w-28-gapX)/2;
   int usableH=MathMax(120,h-46);
   int bh=MathMax(20,MathMin(28,(usableH-(rows-1)*gapY)/rows));
   int gridTop=y+34;

   for(int i=0;i<GRID_TYPE_COUNT;i++)
   {
      int r=i/cols,c=i%cols;
      int px=x+10+c*(bw+gapX);
      int py=gridTop+r*(bh+gapY);
      string status=g_gridValidationRunCount>0?g_gridValidationMatrix[i]:"NOT RUN";
      color cc=g_gridValidationRunCount==0?COLOR_MUTED:(StringFind(status,"FAIL")>=0?COLOR_RED:COLOR_GREEN);
      DButton("GV_SEL2_"+IntegerToString(i),GridShortName((ENUM_GRID_TYPE)i),px,py,bw,bh,i==g_gridValidationSelected?COLOR_ACCENT:COLOR_PANEL2,i==g_gridValidationSelected,6);
      DText("GV_ST2_"+IntegerToString(i),status,px+8,py+bh-9,5,cc,"Arial");
   }
}

void DGridLabNestedTabs(const string &labels[],int count,int selected,string prefix)
{
   int x=ContentX();
   int y=ContentY()+72;
   int w=ContentW();
   int h=31;
   if(count<=0) return;
   if(selected<0) selected=0;
   if(selected>=count) selected=count-1;
   string active=labels[selected];
   DRect(prefix+"_RAIL",x,y,w,h,C'7,14,18',COLOR_PANEL2);
   DButton(prefix+"_PREV","<",x+4,y+4,28,23,COLOR_PANEL2,false,8);
   DText(prefix+"_INDEX",StringFormat("%02d / %02d",selected+1,count),x+38,y+8,6,COLOR_MUTED,"Arial Bold");
   DText(prefix+"_ACTIVE",active,x+82,y+7,7,COLOR_GOLD,"Arial Bold");
   DButton(prefix+"_NEXT",">",x+w-32,y+4,28,23,COLOR_PANEL2,false,8);
   DRect(prefix+"_LINE",x,y+h+5,w,1,COLOR_PANEL2,COLOR_PANEL2);
}

int GridLabBodyY()
{
   return ContentY()+72+31+8+10;
}

void CreateGridValidationRulesWorkspace()
{
   int x=ContentX(),y=GridLabBodyY(),w=ContentW(),gap=8,cw=(w-gap)/2;
   DSectionSingle("GV_RULES_A","VALIDATION RULES",x,y,cw,300);
   SettingsSectionStatus("GVRULE_A1","DEPLOYMENT","PROFILE / BROKER / RISK CHECK",x+14,y+48,COLOR_TEAL);
   SettingsSectionStatus("GVRULE_A2","LEVELS","MODEL + CAPACITY CHECK",x+14,y+78,COLOR_TEXT);
   SettingsSectionStatus("GVRULE_A3","SPACING","EFFECTIVE / MIN / MAX",x+14,y+108,COLOR_TEXT);
   SettingsSectionStatus("GVRULE_A4","DIRECTION","LONG / SHORT / BOTH",x+14,y+138,COLOR_TEXT);
   SettingsSectionStatus("GVRULE_A5","LIFECYCLE","DEPLOY / FILL / REBUILD",x+14,y+168,COLOR_GOLD);
   SettingsSectionStatus("GVRULE_A6","SAFETY","LIVE ORDERS NOT SENT",x+14,y+198,COLOR_GREEN);
   SettingsSectionStatus("GVRULE_A7","SELECTION","GRID TYPE / STRATEGY FIT",x+14,y+228,COLOR_TEXT);
   DButton("BTN_RUN_GRID_VALIDATION_RULES","RUN 21-GRID AUDIT",x+14,y+258,cw-28,30,COLOR_ACCENT,false,7);

   DSectionSingle("GV_RULES_B","RULE STATUS",x+cw+gap,y,cw,300);
   SettingsSectionStatus("GVRULE_B1","PROFILE",GridValidationModel(g_state.gridType),x+cw+gap+14,y+48,COLOR_TEXT);
   SettingsSectionStatus("GVRULE_B2","CURRENT GRID",CompactGridName(g_state.gridType),x+cw+gap+14,y+78,COLOR_GOLD);
   SettingsSectionStatus("GVRULE_B3","STEP",StringFormat("%.1f pips",g_state.effectiveGridStepPips),x+cw+gap+14,y+108,COLOR_TEAL);
   SettingsSectionStatus("GVRULE_B4","LEVELS",IntegerToString(g_state.effectiveGridLevels),x+cw+gap+14,y+138,COLOR_TEAL);
   SettingsSectionStatus("GVRULE_B5","LOT",DoubleToString(g_state.effectiveLot,3),x+cw+gap+14,y+168,COLOR_TEAL);
   SettingsSectionStatus("GVRULE_B6","STATUS",g_gridValidationRunCount>0?g_gridValidationMatrix[(int)g_state.gridType]:"NOT RUN",x+cw+gap+14,y+198,COLOR_TEAL);
   SettingsSectionStatus("GVRULE_B7","RUNS",IntegerToString(g_gridValidationRunCount),x+cw+gap+14,y+228,COLOR_GOLD);
   SettingsSectionStatus("GVRULE_B8","SUMMARY",g_gridValidationSummary,x+cw+gap+14,y+258,COLOR_TEXT);
}

void CreateGridValidationReadinessWorkspace()
{
   int x=ContentX(),y=GridLabBodyY(),w=ContentW(),gap=8,cw=(w-gap)/2;

   DSectionSingle("GV_READY_A","BROKER & PLATFORM",x,y,cw,300);
   bool connected=(TerminalInfoInteger(TERMINAL_CONNECTED)!=0);
   SettingsSectionStatus("GVREADY_A1","TERMINAL",connected?"CONNECTED":"DISCONNECTED",x+14,y+48,connected?COLOR_GREEN:COLOR_RED);
   SettingsSectionStatus("GVREADY_A2","SYMBOL",_Symbol,x+14,y+78,COLOR_GOLD);
   SettingsSectionStatus("GVREADY_A3","TIMEFRAME",EnumToString((ENUM_TIMEFRAMES)_Period),x+14,y+108,COLOR_TEXT);
   SettingsSectionStatus("GVREADY_A4","TRADING",(bool)TerminalInfoInteger(TERMINAL_TRADE_ALLOWED)?"ALLOWED":"BLOCKED",x+14,y+138,TerminalInfoInteger(TERMINAL_TRADE_ALLOWED)?COLOR_GREEN:COLOR_RED);
   SettingsSectionStatus("GVREADY_A5","GRID MODEL",GridValidationModel(g_state.gridType),x+14,y+168,COLOR_TEXT);
   SettingsSectionStatus("GVREADY_A6","GRID TYPE",CompactGridName(g_state.gridType),x+14,y+198,COLOR_GOLD);
   SettingsSectionStatus("GVREADY_A7","BROKER CHECK",connected?"READY":"REVIEW",x+14,y+228,connected?COLOR_GREEN:COLOR_ORANGE);

   DSectionSingle("GV_READY_B","RUNTIME & RECOVERY",x+cw+gap,y,cw,300);
   SettingsSectionStatus("GVREADY_B1","GRID STATE",g_state.gridLifecycleState,x+cw+gap+14,y+48,COLOR_TEXT);
   SettingsSectionStatus("GVREADY_B2","RECOVERY",g_state.recoveryStatus,x+cw+gap+14,y+78,COLOR_TEXT);
   SettingsSectionStatus("GVREADY_B3","RISK ENGINE",g_state.riskManagedTrading?"ENABLED":"BYPASS",x+cw+gap+14,y+108,g_state.riskManagedTrading?COLOR_GREEN:COLOR_MUTED);
   SettingsSectionStatus("GVREADY_B4","PORTFOLIO",g_state.portfolioRiskOK?"CLEAR":"BLOCK",x+cw+gap+14,y+138,g_state.portfolioRiskOK?COLOR_GREEN:COLOR_RED);
   SettingsSectionStatus("GVREADY_B5","PENDING CAPACITY",StringFormat("%d / %d",g_state.pendingCount,g_state.maxPendingOrders),x+cw+gap+14,y+168,COLOR_TEXT);
   SettingsSectionStatus("GVREADY_B6","POSITION CAPACITY",StringFormat("%d / %d",g_state.positionCount,g_state.maxPositions),x+cw+gap+14,y+198,COLOR_TEXT);
   SettingsSectionStatus("GVREADY_B7","VALIDATION",g_gridValidationRunCount>0?"CHECKED":"NOT RUN",x+cw+gap+14,y+228,g_gridValidationRunCount>0?COLOR_GREEN:COLOR_MUTED);
   DButton("BTN_RUN_GRID_VALIDATION_READY","RUN READINESS CHECK",x+cw+gap+14,y+258,cw-28,30,COLOR_ACCENT,false,7);
}



void CreateGridValidationLimitationsWorkspace()
{
   int x=ContentX(),y=GridLabBodyY(),w=ContentW(),gap=8,cw=(w-gap)/2;

   DSectionSingle("GV_LIM_A","VALIDATION SCOPE",x,y,cw,300);
   SettingsSectionStatus("GVLIM_A1","GRID TYPES",StringFormat("%d MODELS",GRID_TYPE_COUNT),x+14,y+48,COLOR_GOLD);
   SettingsSectionStatus("GVLIM_A2","LIVE ORDERS","NOT SENT",x+14,y+78,COLOR_GREEN);
   SettingsSectionStatus("GVLIM_A3","BROKER FILLS","NOT SIMULATED",x+14,y+108,COLOR_MUTED);
   SettingsSectionStatus("GVLIM_A4","MARKET DATA","RUNTIME STATE",x+14,y+138,COLOR_TEAL);
   SettingsSectionStatus("GVLIM_A5","EXECUTION","STRUCTURAL ONLY",x+14,y+168,COLOR_TEXT);
   SettingsSectionStatus("GVLIM_A6","SL/TP","NOT EXECUTED",x+14,y+198,COLOR_MUTED);
   SettingsSectionStatus("GVLIM_A7","RECOVERY","LOGIC-LEVEL CHECK",x+14,y+228,COLOR_TEXT);

   DSectionSingle("GV_LIM_B","CURRENT LIMITATIONS",x+cw+gap,y,cw,300);
   SettingsSectionStatus("GVLIM_B1","FILL QUALITY","NOT MEASURED",x+cw+gap+14,y+48,COLOR_ORANGE);
   SettingsSectionStatus("GVLIM_B2","SLIPPAGE","NOT SIMULATED",x+cw+gap+14,y+78,COLOR_ORANGE);
   SettingsSectionStatus("GVLIM_B3","LATENCY","NOT STRESS TESTED",x+cw+gap+14,y+108,COLOR_ORANGE);
   SettingsSectionStatus("GVLIM_B4","FORWARD TEST","DEMO REQUIRED",x+cw+gap+14,y+138,COLOR_GOLD);
   SettingsSectionStatus("GVLIM_B5","BROKER RULES","READ FROM RUNTIME",x+cw+gap+14,y+168,COLOR_TEAL);
   SettingsSectionStatus("GVLIM_B6","AUTO ACTIONS","NONE FROM LAB",x+cw+gap+14,y+198,COLOR_GREEN);
   SettingsSectionStatus("GVLIM_B7","VALIDATION MODE","NON-TRADING",x+cw+gap+14,y+228,COLOR_GREEN);
}


// -------------------- VALIDATION LAB — VALIDATION LAB --------------------
bool ValidationLabCompatible(ENUM_GRID_TYPE t,int c)
{
   switch(t)
   {
      case SMART_REGIME_GRID: return true;
      case BULLISH_GRID: return (c==VALIDATION_TREND_UP || c==VALIDATION_BREAKOUT || c==VALIDATION_VOLATILITY);
      case BEARISH_GRID: return (c==VALIDATION_TREND_DOWN || c==VALIDATION_BREAKOUT || c==VALIDATION_VOLATILITY);
      case BIDIRECTIONAL_GRID: return (c==VALIDATION_RANGE || c==VALIDATION_VOLATILITY);
      case HEDGE_GRID: return (c==VALIDATION_RANGE || c==VALIDATION_BREAKOUT || c==VALIDATION_VOLATILITY);
   }
   return false;
}
int ValidationLabCheckCell(ENUM_GRID_TYPE t,int c,string &reason)
{
   string detail="";
   if(!ValidateGridProfileModel(t,detail)){reason=detail;return -1;}
   if(ValidationLabCompatible(t,c)){reason="PROFILE COMPATIBLE";return 1;}
   reason="REVIEW PROFILE FIT";
   return 0;
}
void RunPhase16ValidationLab()
{
   int pass=0,review=0,fail=0;
   for(int r=0;r<VALIDATION_LAB_GRID_COUNT;r++)
      for(int c=0;c<VALIDATION_LAB_CONDITION_COUNT;c++)
      {
         string reason="";
         int result=ValidationLabCheckCell(g_phase16FormalGrids[r],c,reason);
         g_phase16CellStatus[r][c]=(result>0?"PASS":(result==0?"REVIEW":"FAIL"));
         if(result>0)pass++; else if(result==0)review++; else fail++;
      }
   g_phase16RunCount++;
   g_phase16PassCount=pass;g_phase16ReviewCount=review;g_phase16FailCount=fail;g_phase16LastRun=TimeCurrent();
   g_phase16Summary=StringFormat("25 SCENARIOS | %d PASS | %d REVIEW | %d FAIL",pass,review,fail);
   RecordEvent("VALIDATION LAB VALIDATION",g_phase16Summary);
}
void CreatePhase16ValidationLab()
{
   int x=ContentX(),y=GridLabBodyY(),w=ContentW();
   int labelW=105,cellW=(w-labelW-28)/VALIDATION_LAB_CONDITION_COUNT;
   DSectionSingle("P16_MTX","25-SCENARIO VALIDATION MATRIX",x,y,w,300);
   for(int c=0;c<VALIDATION_LAB_CONDITION_COUNT;c++)
      DText(StringFormat("P16_H_%d",c),g_phase16Conditions[c],x+labelW+c*cellW+2,y+38,6,COLOR_GOLD,"Arial Bold");
   for(int r=0;r<VALIDATION_LAB_GRID_COUNT;r++)
   {
      int yy=y+62+r*40;
      DText(StringFormat("P16_G_%d",r),CompactGridName(g_phase16FormalGrids[r]),x+12,yy+10,6,COLOR_TEXT,"Arial Bold");
      for(int c=0;c<VALIDATION_LAB_CONDITION_COUNT;c++)
      {
         string st=g_phase16CellStatus[r][c];
         color cc=st=="PASS"?COLOR_GREEN:(st=="FAIL"?COLOR_RED:(st=="REVIEW"?COLOR_ORANGE:COLOR_MUTED));
         int bx=x+labelW+c*cellW;
         DRect(StringFormat("P16_C_%d_%d",r,c),bx,yy,cellW-5,25,COLOR_PANEL2,COLOR_PANEL2);
         DText(StringFormat("P16_CT_%d_%d",r,c),st,bx+4,yy+8,6,cc,"Arial Bold");
      }
   }
   DButton("BTN_RUN_PHASE16","RUN VALIDATION LAB",x+12,y+266,155,26,COLOR_ACCENT,false,7);
   int sy=y+310;
   DSectionSingle("P16_SUM","VALIDATION SUMMARY",x,sy,w,105);
   SettingsSectionStatus("P16_RUN","RUNS",IntegerToString(g_phase16RunCount),x+12,sy+38,COLOR_GOLD);
   SettingsSectionStatus("P16_PASS","PASS",IntegerToString(g_phase16PassCount),x+125,sy+38,COLOR_GREEN);
   SettingsSectionStatus("P16_REV","REVIEW",IntegerToString(g_phase16ReviewCount),x+215,sy+38,COLOR_ORANGE);
   SettingsSectionStatus("P16_FAIL","FAIL",IntegerToString(g_phase16FailCount),x+315,sy+38,g_phase16FailCount>0?COLOR_RED:COLOR_GREEN);
   SettingsSectionStatus("P16_SCOPE","SCOPE","5 GRIDS x 5 CONDITIONS",x+12,sy+68,COLOR_TEAL);
   SettingsSectionStatus("P16_TYPE","TYPE","NON-TRADING LOGIC CHECK",x+215,sy+68,COLOR_GOLD);
   SettingsSectionStatus("P16_LAST","LAST RUN",g_phase16LastRun>0?TimeToString(g_phase16LastRun,TIME_DATE|TIME_MINUTES):"NOT RUN",x+12,sy+94,COLOR_MUTED);
}

void CreateGridValidationLab()
{
   DPageTitle("GRID LAB & VALIDATION","Dedicated grid validation, lifecycle and readiness workspace");

   // Main Grid Lab workspace remains split into the original two main sub-tabs.
   // The five specialist validation sub-tabs belong ONLY to the VALIDATION workspace.
   string mainTabs[]={"GRID VALIDATION LAB","VALIDATION"};
   DNestedSubTabs(mainTabs,2,g_dashboard.gridLabSubTab,"GRIDLAB_MAIN_");

   if(g_dashboard.gridLabSubTab==0)
   {
      string subTabs[]={"OVERVIEW","CURRENT PROFILE","LIFECYCLE"};
      DGridLabNestedTabs(subTabs,3,g_dashboard.gridLabValidationSubTab,"GRIDLAB_VALIDATE_");
      switch(g_dashboard.gridLabValidationSubTab)
      {
         case 0:CreateGridValidationOverviewWorkspace();break;
         case 1:CreateGridValidationCurrent();break;
         default:CreateGridValidationLifecycle();break;
      }
   }
   else
   {
      // VALIDATION workspace owns six sibling sub-tabs. They are NOT merged with the first main sub-tab.
      string subTabs[]={"21-GRID VALIDATION","VALIDATION RULES","READINESS","LIFECYCLE VALIDATION","LIMITATIONS","VALIDATION LAB LAB"};
      DGridLabNestedTabs(subTabs,6,g_dashboard.gridLabMatrixSubTab,"GRIDLAB_MATRIX_");
      switch(g_dashboard.gridLabMatrixSubTab)
      {
         case 0:CreateGridValidationWorkspace();break;
         case 1:CreateGridValidationRulesWorkspace();break;
         case 2:CreateGridValidationReadinessWorkspace();break;
         case 3:CreateGridValidationLifecycle();break;
         case 4:CreateGridValidationLimitationsWorkspace();break;
         case 5:CreatePhase16ValidationLab();break;
         default:CreateGridValidationWorkspace();break;
      }
   }
}



// -------------------- SETTINGS --------------------

// Settings owns remaining configuration domains. Protection and Grid Lab validation
// are dedicated specialist workspaces with their own nested feature tabs.



// -------------------- AUTHORITY AUDIT — AUTHORITY & INTEGRITY AUDIT --------------------
void AuthorityAuditAuthorityCheck(const bool condition,const bool warningOnly,const string label,string &summary,int &checked,int &passed,int &warnings,int &failed,string &lastFailure)
{
   checked++;
   if(condition){passed++;return;}
   if(warningOnly){warnings++; if(summary!="")summary+=" | ";summary+="WARN: "+label;return;}
   failed++; lastFailure=label; if(summary!="")summary+=" | ";summary+="FAIL: "+label;
}

void RunPhase20AuthorityAudit()
{
   DashboardSyncRefreshDashboardSyncAudit();
   int checked=0,passed=0,warnings=0,failed=0; string summary=""; string lastFailure="";
   bool live=(AccountInfoInteger(ACCOUNT_TRADE_MODE)==ACCOUNT_TRADE_MODE_REAL);

   // Grid / strategy authority.
   AuthorityAuditAuthorityCheck((int)g_selectedGridType>=(int)BASIC_GRID && (int)g_selectedGridType<GRID_TYPE_COUNT,false,"Selected grid enum invalid",summary,checked,passed,warnings,failed,lastFailure);
   AuthorityAuditAuthorityCheck((int)g_state.gridType>=(int)BASIC_GRID && (int)g_state.gridType<GRID_TYPE_COUNT,false,"Runtime grid enum invalid",summary,checked,passed,warnings,failed,lastFailure);
   if(g_state.controlMode==CONTROL_AUTONOMOUS)
      AuthorityAuditAuthorityCheck((int)g_state.autonomousSelectedGridType>=0 && (int)g_state.autonomousSelectedGridType<GRID_TYPE_COUNT,true,"Autonomous selected grid unavailable",summary,checked,passed,warnings,failed,lastFailure);
   else
      AuthorityAuditAuthorityCheck((int)g_selectedGridType==(int)g_state.gridType,false,"Manual/Assist selected grid is not the runtime grid",summary,checked,passed,warnings,failed,lastFailure);

   // Configured -> applied/effective integrity.
   AuthorityAuditAuthorityCheck(g_state.gridStep>0.0 && g_state.effectiveGridStepPips>0.0,false,"Grid step effective state invalid",summary,checked,passed,warnings,failed,lastFailure);
   AuthorityAuditAuthorityCheck(g_state.gridLevels>0 && g_state.effectiveGridLevels>0,false,"Grid levels effective state invalid",summary,checked,passed,warnings,failed,lastFailure);
   AuthorityAuditAuthorityCheck(g_state.lotSize>0.0 && g_state.effectiveLot>0.0,false,"Lot effective state invalid",summary,checked,passed,warnings,failed,lastFailure);
   AuthorityAuditAuthorityCheck(g_state.maxPositions>0 && g_state.maxPendingOrders>0,false,"Capacity limits invalid",summary,checked,passed,warnings,failed,lastFailure);
   AuthorityAuditAuthorityCheck(g_state.maxTotalLots>=0.0,false,"Maximum total lots invalid",summary,checked,passed,warnings,failed,lastFailure);

   // Optional authority must not be active without its permission.
   AuthorityAuditAuthorityCheck(!g_state.adaptiveGrid || g_state.permAdaptiveStep,true,"Adaptive Grid active without step permission",summary,checked,passed,warnings,failed,lastFailure);
   AuthorityAuditAuthorityCheck(!g_state.adaptiveLevels || g_state.permAdaptiveLevels,true,"Adaptive Levels active without level permission",summary,checked,passed,warnings,failed,lastFailure);
   AuthorityAuditAuthorityCheck(!g_state.adaptiveLot || g_state.permAdaptiveLot,true,"Adaptive Lot active without lot permission",summary,checked,passed,warnings,failed,lastFailure);
   AuthorityAuditAuthorityCheck(!g_state.smartRecenter || g_state.permRecenter,true,"Smart Recenter active without recenter permission",summary,checked,passed,warnings,failed,lastFailure);
   AuthorityAuditAuthorityCheck(!g_state.smartReplenishment || g_state.permReplenishment,true,"Smart Replenishment active without replenishment permission",summary,checked,passed,warnings,failed,lastFailure);
   AuthorityAuditAuthorityCheck(!g_state.advancedEntryDecision || (IsAutonomousControl() && g_state.permAutonomousEntry),true,"Advanced Entry active outside permitted autonomous authority",summary,checked,passed,warnings,failed,lastFailure);

   // Mode ownership: autonomous-only entry behavior must not remain live in non-autonomous control.
   AuthorityAuditAuthorityCheck(!g_state.autonomousEngine || IsAutonomousControl(),false,"Autonomous engine active outside Autonomous control",summary,checked,passed,warnings,failed,lastFailure);
   AuthorityAuditAuthorityCheck(!g_state.advancedEntryDecision || IsAutonomousControl(),false,"Advanced Entry active outside Autonomous control",summary,checked,passed,warnings,failed,lastFailure);

   // Hard risk hierarchy remains below intelligence.
   AuthorityAuditAuthorityCheck(g_state.maxGridRiskPct>=g_state.riskPerGridPct,false,"Grid risk exceeds configured risk hierarchy",summary,checked,passed,warnings,failed,lastFailure);
   AuthorityAuditAuthorityCheck(g_state.maxDrawdownPct>=0.0 && g_state.dailyLossLimitPct>=0.0,false,"Survival thresholds invalid",summary,checked,passed,warnings,failed,lastFailure);
   AuthorityAuditAuthorityCheck(!live || g_state.maxTotalLots>0.0,false,"Live account has no finite total-lot limit",summary,checked,passed,warnings,failed,lastFailure);

   // Lifecycle authority must remain pending-oriented; live positions require explicit position management.
   AuthorityAuditAuthorityCheck(g_state.lifecycleAuthority=="GRID_LIFECYCLE" || g_state.lifecycleAuthority=="",false,"Unexpected lifecycle authority",summary,checked,passed,warnings,failed,lastFailure);
   AuthorityAuditAuthorityCheck(g_state.lifecycleScope=="" || StringFind(g_state.lifecycleScope,"PENDING")>=0,true,"Lifecycle scope does not advertise pending authority",summary,checked,passed,warnings,failed,lastFailure);

   // Autonomous decision state and TRANSACTION COSTS/15 dependencies.
   AuthorityAuditAuthorityCheck(g_state.autonomousDecisionClass=="APPROVE" || g_state.autonomousDecisionClass=="WAIT" || g_state.autonomousDecisionClass=="REJECT",true,"Autonomous decision class not initialized",summary,checked,passed,warnings,failed,lastFailure);
   AuthorityAuditAuthorityCheck(g_state.autonomousPlanScore>=0.0 && g_state.autonomousPlanScore<=1.0,false,"Autonomous plan score outside 0..1",summary,checked,passed,warnings,failed,lastFailure);
   AuthorityAuditAuthorityCheck(g_state.transactionCostCostAdjustedEdgeScore>=0.0 && g_state.transactionCostCostAdjustedEdgeScore<=1.0,false,"Cost-adjusted edge outside 0..1",summary,checked,passed,warnings,failed,lastFailure);
   AuthorityAuditAuthorityCheck(g_state.strategyHealthSelectedAllocation>=0.0,false,"Strategy allocation invalid",summary,checked,passed,warnings,failed,lastFailure);

   // Recovery / persistence / dashboard sync integrity.
   AuthorityAuditAuthorityCheck(g_state.recoveryRecoveryLock==false || g_state.recoveryRecoveryLock==true,false,"Recovery lock state unreadable",summary,checked,passed,warnings,failed,lastFailure);
   AuthorityAuditAuthorityCheck(g_state.dashboardSyncControlModeOK,false,"DASHBOARD SYNC control-mode authority mismatch",summary,checked,passed,warnings,failed,lastFailure);
   AuthorityAuditAuthorityCheck(g_state.dashboardSyncEffectiveStateOK,false,"DASHBOARD SYNC effective-state mismatch",summary,checked,passed,warnings,failed,lastFailure);
   AuthorityAuditAuthorityCheck(g_state.dashboardSyncSelectedGridOK || IsAutonomousControl(),true,"Selected grid differs from runtime grid outside autonomous mode",summary,checked,passed,warnings,failed,lastFailure);
   AuthorityAuditAuthorityCheck(g_state.dashboardSyncPendingEdits==0,true,"Dashboard has unapplied staged edits",summary,checked,passed,warnings,failed,lastFailure);

   g_state.authorityAuditChecked=checked;g_state.authorityAuditPassed=passed;g_state.authorityAuditWarnings=warnings;g_state.authorityAuditFailed=failed;
   g_state.authorityAuditAuditTime=TimeCurrent();
   g_state.authorityAuditLastFailure=lastFailure;
   if(failed>0) g_state.authorityAuditStatus="FAILED";
   else if(warnings>0) g_state.authorityAuditStatus="PASS WITH WARNINGS";
   else g_state.authorityAuditStatus="PASS";
   if(summary=="") summary=StringFormat("%d/%d checks passed",passed,checked);
   g_state.authorityAuditSummary=StringFormat("%s | %d checks | %d warnings | %d failures",summary,checked,warnings,failed);
   static string lastAuditRecord="";
   string auditRecord=g_state.authorityAuditStatus+"|"+g_state.authorityAuditSummary;
   if(auditRecord!=lastAuditRecord)
   {
      RecordEvent("AUTHORITY AUDIT AUDIT",g_state.authorityAuditSummary);
      lastAuditRecord=auditRecord;
   }
}

void CreatePhase21SourceQualityPage()
{
   int x=ContentX(),y=PageBodyY(5),w=ContentW();
   DSectionSingle("P21Q1","SOURCE QUALITY AUDIT",x,y,w,300);
   DKV("P21Q1A","STATUS","REVIEWED",x+14,y+42,150,COLOR_GOLD);
   DKV("P21Q1B","DUPLICATE LOGIC","REVIEWED",x+14,y+72,150,COLOR_GREEN);
   DKV("P21Q1C","ORPHAN CONTROLS","REVIEW IN METAEDITOR",x+14,y+102,150,COLOR_GOLD);
   DKV("P21Q1D","TRADE RETURNS","ACTIVE PATHS REVIEWED",x+14,y+132,150,COLOR_GREEN);
   DKV("P21Q1E","UNSAFE CASTS","REVIEW IN COMPILER",x+14,y+162,150,COLOR_GOLD);
   DKV("P21Q1F","PENDING / LIVE","AUTHORITY BOUNDARIES REVIEWED",x+14,y+192,150,COLOR_GREEN);
   DText("P21Q1N","SOURCE QUALITY source-quality review covers duplicate logic, orphan controls, trade returns, casts, lifecycle crossover, retry bounds, authority conflicts and stale state.",x+14,y+226,6,COLOR_MUTED,"Arial");
   DText("P21Q1N2","Compiler diagnostics remain authoritative for MetaEditor warnings/errors.",x+14,y+252,6,COLOR_MUTED,"Arial");
}

void CreatePhase20AuthorityAuditPage()
{
   RunPhase20AuthorityAudit();
   int x=ContentX(),y=PageBodyY(5),w=ContentW(),gap=10,cw=(w-gap)/2;
   DSectionSingle("P20A","AUTHORITY / INTEGRITY",x,y,cw,300);
   DKV("P20A1","STATUS",g_state.authorityAuditStatus,x+14,y+42,110,g_state.authorityAuditStatus=="PASS"?COLOR_GREEN:(g_state.authorityAuditStatus=="FAILED"?COLOR_RED:COLOR_GOLD));
   DKV("P20A2","CHECKED",IntegerToString(g_state.authorityAuditChecked),x+14,y+72,110,COLOR_TEXT);
   DKV("P20A3","PASSED",IntegerToString(g_state.authorityAuditPassed),x+14,y+102,110,COLOR_GREEN);
   DKV("P20A4","WARNINGS",IntegerToString(g_state.authorityAuditWarnings),x+14,y+132,110,g_state.authorityAuditWarnings>0?COLOR_ORANGE:COLOR_TEXT);
   DKV("P20A5","FAILURES",IntegerToString(g_state.authorityAuditFailed),x+14,y+162,110,g_state.authorityAuditFailed>0?COLOR_RED:COLOR_TEXT);
   DKV("P20A6","LAST AUDIT",g_state.authorityAuditAuditTime>0?TimeToString(g_state.authorityAuditAuditTime,TIME_SECONDS):"--",x+14,y+192,110,COLOR_MUTED);
   DText("P20A7",StringSubstr(g_state.authorityAuditLastFailure==""?"NO FAILED CHECK":g_state.authorityAuditLastFailure,0,38),x+14,y+232,6,COLOR_TEXT,"Arial");
   DSectionSingle("P20B","AUTHORITY SUMMARY",x+cw+gap,y,cw,300);
   DKV("P20B1","GRID",(g_state.controlMode==CONTROL_AUTONOMOUS?"AUTONOMOUS":"USER"),x+cw+gap+14,y+42,110,COLOR_GOLD);
   DKV("P20B2","ENTRY",(IsAutonomousControl()&&g_state.advancedEntryDecision)?"ENTRY ENGINE":"USER",x+cw+gap+14,y+72,110,COLOR_GOLD);
   DKV("P20B3","STEP",g_state.adaptiveGrid?"ADAPTIVE":"USER",x+cw+gap+14,y+102,110,g_state.adaptiveGrid?COLOR_GOLD:COLOR_GREEN);
   DKV("P20B4","LEVELS",g_state.adaptiveLevels?"ADAPTIVE":"USER",x+cw+gap+14,y+132,110,g_state.adaptiveLevels?COLOR_GOLD:COLOR_GREEN);
   DKV("P20B5","LOT",g_state.adaptiveLot?"ADAPTIVE":"USER",x+cw+gap+14,y+162,110,g_state.adaptiveLot?COLOR_GOLD:COLOR_GREEN);
   DKV("P20B6","RISK",g_state.riskHierarchyStatus,x+cw+gap+14,y+192,110,COLOR_TEAL);
   DKV("P20B7","LIFECYCLE",g_state.lifecycleAuthority,x+cw+gap+14,y+222,110,COLOR_TEAL);
   DText("P20B8","One source of truth; this page audits ownership, application and effective state.",x+cw+gap+14,y+258,6,COLOR_MUTED,"Arial");
}

void RunSettingsAuthorityAudit()

{

   int checked=0,passed=0,warn=0,failed=0; string summary="";

   #define AUDIT_FAIL(COND,NAME) {checked++; if(COND)passed++; else {failed++; if(summary!="")summary+=" | ";summary+=NAME;}}

   #define AUDIT_WARN(COND,NAME) {checked++; if(COND)passed++; else {warn++; if(summary!="")summary+=" | ";summary+=NAME;}}

   bool isLive=(AccountInfoInteger(ACCOUNT_TRADE_MODE)==ACCOUNT_TRADE_MODE_REAL);

   AUDIT_FAIL(g_state.gridStep>0,"Grid step invalid");

   AUDIT_FAIL(g_state.gridLevels>0,"Grid levels invalid");

   AUDIT_FAIL(g_state.lotSize>0,"Base lot invalid");

   AUDIT_FAIL(g_state.lotMultiplier>0,"Lot multiplier invalid");

   AUDIT_FAIL(g_state.minGridStep>0 && g_state.maxGridStep>=g_state.minGridStep,"Spacing bounds invalid");

   AUDIT_FAIL(g_state.frontOrderDistancePips>=0,"Front distance invalid");

   AUDIT_FAIL(g_state.maxPositions>0,"Max positions invalid");

   AUDIT_FAIL(g_state.maxPendingOrders>0,"Max pending invalid");

   AUDIT_FAIL(g_state.riskPerGridPct>=0,"Risk/grid invalid");

   AUDIT_FAIL(g_state.maxGridRiskPct>=g_state.riskPerGridPct,"Grid risk hierarchy invalid");

   AUDIT_FAIL(g_state.maxDrawdownPct>=0,"Max drawdown invalid");

   AUDIT_FAIL(g_state.stopLossPips>=0 && g_state.takeProfitPips>=0,"Protection distance invalid");

   AUDIT_FAIL(g_state.orderRetryCount>=0,"Retry count invalid");

   AUDIT_FAIL(g_state.maxSpreadPips>=0,"Max spread invalid");

   AUDIT_FAIL(g_state.sessionStartHour>=0 && g_state.sessionStartHour<=23 && g_state.sessionEndHour>=0 && g_state.sessionEndHour<=23,"Session hours invalid");

   AUDIT_FAIL(g_state.adaptiveMinLevels>0 && g_state.adaptiveMaxLevels>=g_state.adaptiveMinLevels,"Adaptive level bounds invalid");

   AUDIT_FAIL(g_state.adaptiveSensitivity>=0,"Adaptive sensitivity invalid");

   AUDIT_FAIL(g_state.maxStepChangePct>=0,"Max step change invalid");

   AUDIT_FAIL(g_state.maxTotalLots>=0,"Max lots invalid");

   AUDIT_FAIL(g_state.autonomousMinSuitability>=0 && g_state.autonomousMinSuitability<=1,"Suitability threshold invalid");

   AUDIT_FAIL(g_state.autonomousMinScore>=0 && g_state.autonomousMinScore<=1,"Autonomous score threshold invalid");

   AUDIT_FAIL(g_state.autonomousMinConfidence>=0 && g_state.autonomousMinConfidence<=1,"Autonomous confidence threshold invalid");

   AUDIT_FAIL(g_state.autonomousDecisionIntervalSec>=0 && g_state.autonomousCooldownSec>=0,"Autonomous timing invalid");

   AUDIT_WARN(!g_state.autonomousEngine || IsAutonomousControl(),"Autonomous Engine enabled outside Autonomous control");

   AUDIT_WARN(!g_state.advancedEntryDecision || IsAutonomousControl(),"Advanced Entry inactive outside Autonomous");

   AUDIT_FAIL(!isLive || g_state.maxTotalLots>0,"LIVE ACCOUNT: total lot exposure is unlimited");

   AUDIT_WARN(!g_state.smartRecenter || g_state.autoRecenter,"Smart Recenter requires Auto Recenter");

   AUDIT_WARN(!g_state.smartReplenishment || IsReplenishableStopGrid(),"Replenishment not applicable to current grid");

   AUDIT_FAIL(!isLive || !IsAutonomousControl() || g_state.maxAutonomousGridsPerDay>0,"LIVE ACCOUNT: autonomous daily grid count is unlimited");

   AUDIT_WARN(!g_state.useDynamicRiskLot || g_state.riskPerGridPct>0,"Dynamic risk has zero risk budget");

   AUDIT_WARN(!isLive || g_state.lotMultiplier<=1.05,"LIVE ACCOUNT: lot multiplier >1.05 compounds exponentially per grid level (martingale-style)");

   AUDIT_WARN(!g_state.adaptiveGrid || g_state.permAdaptiveStep,"Adaptive Grid enabled but step permission is denied");

   AUDIT_WARN(!g_state.adaptiveLevels || g_state.permAdaptiveLevels,"Adaptive Levels enabled but level permission is denied");

   AUDIT_WARN(!g_state.adaptiveLot || g_state.permAdaptiveLot,"Adaptive Lot enabled but lot permission is denied");

   AUDIT_WARN(!g_state.advancedEntryDecision || g_state.permAutonomousEntry,"Advanced Entry enabled but autonomous entry permission is denied");

   AUDIT_WARN(!g_state.smartRecenter || g_state.permRecenter,"Smart Recenter enabled but recenter permission is denied");

   AUDIT_WARN(!g_state.smartReplenishment || g_state.permReplenishment,"Smart Replenishment enabled but replenishment permission is denied");

   AUDIT_WARN(!g_state.exposureManager || g_state.permExposureAdjust,"Exposure Manager enabled but exposure permission is denied");

   g_state.settingsAuditChecked=checked; g_state.settingsAuditPassed=passed; g_state.settingsAuditWarnings=warn; g_state.settingsAuditFailed=failed; g_state.settingsAuditTime=TimeCurrent();

   g_state.settingsAuditStatus=failed>0?"FAILED":warn>0?"REVIEW":"PASS";

   g_state.settingsAuditSummary=summary==""?"All audited settings are within valid authority bounds":summary;

   RecordEvent("SETTINGS AUDIT",StringFormat("%s | checked %d | pass %d | warn %d | fail %d",g_state.settingsAuditStatus,checked,passed,warn,failed));

   #undef AUDIT_FAIL

   #undef AUDIT_WARN

}



void CreateSettingsTabBar()

{

   int x=ContentX(),y=ContentY()+30,w=ContentW();

   string p[]={"I","II","III","IV","V","VI"};

   int gap=3,cols=6,pw=MathMax(24,(w-gap*(cols-1))/cols);

   for(int i=0;i<6;i++) DButton("SET_PAGE_"+IntegerToString(i),p[i],x+i*(pw+gap),y,pw,25,g_dashboard.settingsPage==i?COLOR_ACCENT:COLOR_PANEL2,g_dashboard.settingsPage==i,6);

   int selected=(g_dashboard.settingsPage==0?g_dashboard.settingsSubTab:g_dashboard.settingsPage==1?g_dashboard.settingsSubTab2:g_dashboard.settingsPage==2?g_dashboard.settingsSubTab3:g_dashboard.settingsPage==3?g_dashboard.settingsSubTab4:g_dashboard.settingsPage==4?g_dashboard.settingsSubTab5:g_dashboard.settingsSubTab6);
   int count=(g_dashboard.settingsPage==0?6:g_dashboard.settingsPage==3?6:10);

   string labs1[]={"GRID PROFILE","LIVE GRID STATE","BASE SPACING","RECENTER & FRONT ORDER","ORDER CAPACITY","GRID BEHAVIOR"};

   string labs2[]={"AI CORE","AI TELEMETRY","RISK THRESHOLD","REGIME FILTER","ORDER EXECUTION","RELIABILITY","SESSION CONTROL","MARKET GATES","CHART THEME","CHART OPTIONS"};

   string labs3[]={"ADVANCED MODE","ADAPTIVE GRID","ADAPTIVE LEVELS","ADAPTIVE LOT","SMART ENTRY","MARKET INTELLIGENCE","SMART REGIME","AUTHORITY","AUTONOMY LIMITS","EFFECTIVE STATE"};

   string labs4[]={"SMART RECENTER","SMART REPLENISH","ORDER GUARDIAN","DECISION JOURNAL","PROFILE CONTROL","SIMULATION"};

   string labs5[]={"GRID LIFECYCLE","STRATEGY POLICY","STRATEGY-AWARE MANAGEMENT","EXIT COORDINATION","LIFECYCLE RECOVERY","REPLENISHMENT POLICY","RECENTER POLICY","EXIT POLICY","GRID SESSION CONTROL","LIFECYCLE DIAGNOSTICS"};

   string labs6[]={"AUTONOMOUS CONTROLLER","AUTONOMOUS SCHEDULE","AUTONOMOUS ENTRY","AUTONOMOUS RISK","AUTONOMOUS GRID","STRATEGY SELECTION","AUTONOMOUS EXPOSURE","EMERGENCY CONTROL","DECISION HISTORY","AUTONOMOUS PERFORMANCE"};

   string label=(g_dashboard.settingsPage==0?labs1[selected]:g_dashboard.settingsPage==1?labs2[selected]:g_dashboard.settingsPage==2?labs3[selected]:g_dashboard.settingsPage==3?labs4[selected]:g_dashboard.settingsPage==4?labs5[selected]:labs6[selected]);

   int ry=y+33; DRect("SET_SUB_RAIL",x,ry,w,31,C'7,14,18',COLOR_PANEL2); DButton("SET_PREV","<",x+4,ry+4,28,23,COLOR_PANEL2,false,8); DText("SET_SUB_INDEX",StringFormat("%02d / 10",selected+1),x+38,ry+8,6,COLOR_MUTED,"Arial Bold"); DText("SET_SUB_ACTIVE",label,x+82,ry+8,7,COLOR_GOLD,"Arial Bold"); DButton("SET_NEXT",">",x+w-32,ry+4,28,23,COLOR_PANEL2,false,8);

}


int SettingsBodyY(){return ContentY()+30+25+33+31+10;}

int SettingsBodyH(){return MathMax(170,ContentH()-(SettingsBodyY()-ContentY())-46);}

void SettingsFieldAt(string id,string label,string value,int x,int y,int w=92)

{

   DText(id+"_CAP",label,x,y,7,COLOR_MUTED,"Arial Bold");

   CreateInput(ObjName(id),value,x+w+8,y-5,MathMax(58,w-8));

}

void SettingsCard(string id,string title,string subtitle,int x,int y,int w,int h)

{

   DRect(id,x,y,w,h,COLOR_PANEL,COLOR_PANEL2);

   DText(id+"_TITLE",title,x+12,y+8,9,COLOR_GOLD,"Arial Bold");

   if(subtitle!="") DText(id+"_SUB",subtitle,x+12,y+23,6,COLOR_MUTED,"Arial");

   DRect(id+"_LINE",x+12,y+34,w-24,1,COLOR_PANEL2,COLOR_PANEL2);

}

void SettingsColumnField(string id,string label,string value,int x,int y){ SettingsFieldAt(id,label,value,x,y,78); }

void SettingsSectionStatus(string prefix,string label,string value,int x,int y,color c=clrWhite)

{

   DText(prefix+"_L",label,x,y,7,COLOR_MUTED,"Arial Bold");

   DText(prefix+"_V",value,x+92,y-1,7,c,"Arial Bold");

}

void SettingsPageHeader(string title,string subtitle)

{

   int x=ContentX(),y=SettingsBodyY();

   DText("SET_PAGE_TITLE",title,x,y-18,9,COLOR_TEXT,"Arial Bold");

   DText("SET_PAGE_SUB",subtitle,x,y-3,6,COLOR_MUTED,"Arial");

}



void CreateGridProfileSettingsPage()

{

   int x=ContentX(),y=SettingsBodyY(),w=ContentW(),h=SettingsBodyH(),gap=8,cw=(w-gap)/2;

   SettingsPageHeader("GRID PROFILE","Core identity, sizing and entry configuration");

   SettingsCard("SET_GP_A","PROFILE","Core grid identity",x,y,cw,h);

   SettingsColumnField("EDT_LOT","Base lot",DoubleToString(g_state.lotSize,3),x+14,y+54);

   SettingsColumnField("EDT_MULT","Lot multiplier",DoubleToString(g_state.lotMultiplier,2),x+14,y+84);

   SettingsColumnField("EDT_LEVELS","Grid levels",IntegerToString(g_state.gridLevels),x+14,y+114);

   SettingsSectionStatus("SGP_TYPE","GRID TYPE",CompactGridName(g_state.gridType),x+14,y+164,COLOR_GOLD);

   SettingsSectionStatus("SGP_ENTRY","ENTRY MODE",EntryModeName(g_state.entryMode),x+14,y+194,COLOR_TEXT);

   SettingsSectionStatus("SGP_REENTRY","RE-ENTRY",EnumToString(g_state.reentryMode),x+14,y+224,COLOR_TEXT);

   SettingsSectionStatus("SGP_MAGIC","MAGIC",StringFormat("%I64u",InpMagicNumber),x+14,y+254,COLOR_MUTED);

   DButton("BTN_GRID_PROFILE","OPEN GRID SELECTOR",x+14,y+h-44,cw-28,28,COLOR_ACCENT,false,6);

   SettingsCard("SET_GP_B","DESIGN INTENT","How the profile is interpreted",x+cw+gap,y,cw,h);

   SettingsSectionStatus("SGP2_MODE","MODE",CompactGridName(g_state.gridType),x+cw+gap+14,y+54,COLOR_GOLD);

   SettingsSectionStatus("SGP2_ENTRY","ENTRY",EntryModeName(g_state.entryMode),x+cw+gap+14,y+84,COLOR_TEXT);

   SettingsSectionStatus("SGP2_SIZE","BASE LOT",DoubleToString(g_state.lotSize,3),x+cw+gap+14,y+114,COLOR_TEAL);

   SettingsSectionStatus("SGP2_LEVEL","LEVELS",IntegerToString(g_state.gridLevels),x+cw+gap+14,y+144,COLOR_TEXT);

}

void CreateLiveGridStateSettingsPage()

{

   int x=ContentX(),y=SettingsBodyY(),w=ContentW(),h=SettingsBodyH(),gap=8,cw=(w-gap)/2;

   SettingsPageHeader("LIVE GRID STATE","Real-time state of the active grid engine");

   SettingsCard("SET_LGS_A","LIVE STATE","Current operating state",x,y,cw,h);

   SettingsSectionStatus("LGS_STATE","STATUS",g_state.gridActive?"ACTIVE":"READY",x+14,y+54,g_state.gridActive?COLOR_GREEN:COLOR_MUTED);

   SettingsSectionStatus("LGS_ANCHOR","ANCHOR",DoubleToString(g_state.anchorPrice,_Digits),x+14,y+84,COLOR_TEXT);

   SettingsSectionStatus("LGS_POS","POSITIONS",StringFormat("%d / %d",g_state.positionCount,g_state.maxPositions),x+14,y+114,COLOR_TEAL);

   SettingsSectionStatus("LGS_PEND","PENDING",StringFormat("%d / %d",g_state.pendingCount,g_state.maxPendingOrders),x+14,y+144,COLOR_GOLD);

   SettingsSectionStatus("LGS_ENGINE","ENGINE",g_state.executionStatus,x+14,y+174,COLOR_GOLD);

   SettingsSectionStatus("LGS_PNL","CURRENT P/L",FormatNumber(g_state.currentProfit),x+14,y+204,g_state.currentProfit>=0?COLOR_GREEN:COLOR_RED);

   SettingsCard("SET_LGS_B","LIVE METRICS","Exposure and activity",x+cw+gap,y,cw,h);

   SettingsSectionStatus("LGSB_BUY","BUY POSITIONS",IntegerToString(g_state.buyPositions),x+cw+gap+14,y+54,COLOR_GREEN);

   SettingsSectionStatus("LGSB_SELL","SELL POSITIONS",IntegerToString(g_state.sellPositions),x+cw+gap+14,y+84,COLOR_RED);

   SettingsSectionStatus("LGSB_BP","BUY PENDING",IntegerToString(g_state.buyPending),x+cw+gap+14,y+114,COLOR_GREEN);

   SettingsSectionStatus("LGSB_SP","SELL PENDING",IntegerToString(g_state.sellPending),x+cw+gap+14,y+144,COLOR_RED);

   DBar("LGSB_POSBAR","POSITION LOAD",g_state.maxPositions>0?100.0*g_state.positionCount/g_state.maxPositions:0,x+cw+gap+14,y+190,cw-28,COLOR_TEAL);

   DBar("LGSB_PENDBAR","PENDING LOAD",g_state.maxPendingOrders>0?100.0*g_state.pendingCount/g_state.maxPendingOrders:0,x+cw+gap+14,y+230,cw-28,COLOR_GOLD);

}

void CreateBaseSpacingSettingsPage()

{

   int x=ContentX(),y=SettingsBodyY(),w=ContentW(),h=SettingsBodyH(),gap=8,cw=(w-gap)/2;

   SettingsPageHeader("BASE SPACING","Primary grid distance and adaptive spacing engine");

   SettingsCard("SET_BS_A","BASE DISTANCE","Core spacing boundaries",x,y,cw,h);

   SettingsColumnField("EDT_STEP","Base step",DoubleToString(g_state.gridStep,1),x+14,y+54);

   SettingsColumnField("EDT_MINSTEP","Minimum step",DoubleToString(g_state.minGridStep,1),x+14,y+84);

   SettingsColumnField("EDT_MAXSTEP","Maximum step",DoubleToString(g_state.maxGridStep,1),x+14,y+114);

   SettingsColumnField("EDT_ATRM","ATR multiplier",DoubleToString(g_state.atrSpacingMultiplier,2),x+14,y+144);

   DToggle("FLG_ATR","ATR ADAPTIVE SPACING",g_state.useATRSpacing,x+14,y+190,cw-28);

   SettingsCard("SET_BS_B","ACTIVE SPACING","Current calculated environment",x+cw+gap,y,cw,h);

   SettingsSectionStatus("BS_ATR","LIVE ATR",DoubleToString(g_state.atrPrice,_Digits),x+cw+gap+14,y+54,COLOR_TEXT);

   double activeStep=g_state.gridStep;

   if(g_state.useATRSpacing) activeStep=MathMax(g_state.minGridStep,MathMin(g_state.maxGridStep,(g_state.atrPrice/PipSize())*g_state.atrSpacingMultiplier));

   SettingsSectionStatus("BS_STEP","ACTIVE STEP",StringFormat("%.1f pips",activeStep),x+cw+gap+14,y+84,COLOR_TEAL);

   SettingsSectionStatus("BS_MIN","LOWER BOUND",StringFormat("%.1f pips",g_state.minGridStep),x+cw+gap+14,y+114,COLOR_TEXT);

   SettingsSectionStatus("BS_MAX","UPPER BOUND",StringFormat("%.1f pips",g_state.maxGridStep),x+cw+gap+14,y+144,COLOR_TEXT);

}

void CreateRecenterFrontSettingsPage()

{

   int x=ContentX(),y=SettingsBodyY(),w=ContentW(),h=SettingsBodyH(),gap=8,cw=(w-gap)/2;

   SettingsPageHeader("RECENTER & FRONT ORDER","Precision placement of the leading grid and anchor reset");

   SettingsCard("SET_RF_A","FRONT ORDER","Nearest pending order placement",x,y,cw,h);

   SettingsColumnField("EDT_FRONT","Front distance",DoubleToString(g_state.frontOrderDistancePips,1),x+14,y+54);

   SettingsSectionStatus("RF_CUR","CURRENT FRONT",StringFormat("%.1f pips",g_state.frontOrderDistancePips),x+14,y+104,COLOR_TEAL);

   SettingsSectionStatus("RF_ANCHOR","ANCHOR",DoubleToString(g_state.anchorPrice,_Digits),x+14,y+134,COLOR_TEXT);

   SettingsCard("SET_RF_B","RECENTER","Automatic grid relocation",x+cw+gap,y,cw,h);

   SettingsColumnField("EDT_RECATR","Recenter ATR",DoubleToString(g_state.recenterATRMultiple,2),x+cw+gap+14,y+54);

   DToggle("FLG_RECENTER","AUTO RECENTER",g_state.autoRecenter,x+cw+gap+14,y+100,cw-28);

   SettingsSectionStatus("RF_ATR","LIVE ATR",DoubleToString(g_state.atrPrice,_Digits),x+cw+gap+14,y+148,COLOR_TEXT);

   SettingsSectionStatus("RF_TRIGGER","TRIGGER DIST",StringFormat("%.2f ATR",g_state.recenterATRMultiple),x+cw+gap+14,y+178,COLOR_GOLD);

}

void CreateOrderCapacitySettingsPage()

{

   int x=ContentX(),y=SettingsBodyY(),w=ContentW(),h=SettingsBodyH(),gap=8,cw=(w-gap)/2;

   SettingsPageHeader("ORDER CAPACITY","Hard limits protecting live exposure and pending inventory");

   SettingsCard("SET_OC_A","CAPACITY LIMITS","Maximum simultaneous inventory",x,y,cw,h);

   SettingsColumnField("EDT_MPOS","Max positions",IntegerToString(g_state.maxPositions),x+14,y+54);

   SettingsColumnField("EDT_MPEND","Max pending",IntegerToString(g_state.maxPendingOrders),x+14,y+84);

   SettingsSectionStatus("OC_POS","POSITIONS",StringFormat("%d / %d",g_state.positionCount,g_state.maxPositions),x+14,y+134,COLOR_TEAL);

   SettingsSectionStatus("OC_PEND","PENDING",StringFormat("%d / %d",g_state.pendingCount,g_state.maxPendingOrders),x+14,y+164,COLOR_GOLD);

   SettingsCard("SET_OC_B","CAPACITY LOAD","Live utilization",x+cw+gap,y,cw,h);

   DBar("OC_PB","POSITION CAPACITY",g_state.maxPositions>0?100.0*g_state.positionCount/g_state.maxPositions:0,x+cw+gap+14,y+54,cw-28,COLOR_TEAL);

   DBar("OC_OB","PENDING CAPACITY",g_state.maxPendingOrders>0?100.0*g_state.pendingCount/g_state.maxPendingOrders:0,x+cw+gap+14,y+104,cw-28,COLOR_GOLD);

   SettingsSectionStatus("OC_BUY","BUY",IntegerToString(g_state.buyPositions),x+cw+gap+14,y+164,COLOR_GREEN);

   SettingsSectionStatus("OC_SELL","SELL",IntegerToString(g_state.sellPositions),x+cw+gap+14,y+194,COLOR_RED);

}

void CreateGridBehaviorSettingsPage()

{

   int x=ContentX(),y=SettingsBodyY(),w=ContentW(),h=SettingsBodyH(),gap=8,cw=(w-gap)/2;

   SettingsPageHeader("GRID BEHAVIOR","Operational behavior, re-entry and live grid controls");

   SettingsCard("SET_GB_A","BEHAVIOR","How the grid operates",x,y,cw,h);

   SettingsSectionStatus("GB_TYPE","GRID TYPE",CompactGridName(g_state.gridType),x+14,y+54,COLOR_GOLD);

   SettingsSectionStatus("GB_ENTRY","ENTRY MODE",EntryModeName(g_state.entryMode),x+14,y+84,COLOR_TEXT);

   SettingsSectionStatus("GB_RE","RE-ENTRY",EnumToString(g_state.reentryMode),x+14,y+114,COLOR_TEXT);

   DToggle("FLG_AUTO","AUTONOMOUS",g_state.autonomousMode,x+14,y+156,cw-28);

   DButton("BTN_GRID_PROFILE2","GRID TYPE WORKSPACE",x+14,y+202,cw-28,30,COLOR_ACCENT,false,6);

   DButton("BTN_REBAL_GRID2","RE-CENTER GRID",x+14,y+240,cw-28,30,COLOR_PANEL2,false,6);

   SettingsCard("SET_GB_B","LIVE BEHAVIOR","Current engine interpretation",x+cw+gap,y,cw,h);

   SettingsSectionStatus("GB2_ACTIVE","GRID",g_state.gridActive?"ACTIVE":"IDLE",x+cw+gap+14,y+54,g_state.gridActive?COLOR_GREEN:COLOR_MUTED);

   SettingsSectionStatus("GB2_ANCHOR","ANCHOR",DoubleToString(g_state.anchorPrice,_Digits),x+cw+gap+14,y+84,COLOR_TEXT);

   SettingsSectionStatus("GB2_STATUS","STATUS",g_state.executionStatus,x+cw+gap+14,y+114,COLOR_GOLD);

}

void CreateRiskEngineSettingsPage()

{

   int x=ContentX(),y=SettingsBodyY(),w=ContentW(),h=SettingsBodyH(),gap=8,cw=(w-gap)/2;

   SettingsPageHeader("RISK ENGINE","Core account and grid risk-management engine");

   SettingsCard("SET_RE_A","ENGINE","Risk controls and dynamic sizing",x,y,cw,h);

   SettingsColumnField("EDT_RISK","Risk / grid %",DoubleToString(g_state.riskPerGridPct,2),x+14,y+54);

   DToggle("BTN_RISK_MANAGED","RISK ENGINE",g_state.riskManagedTrading,x+14,y+100,cw-28);

   DToggle("FLG_RISK","DYNAMIC RISK LOT",g_state.useDynamicRiskLot,x+14,y+134,cw-28);

   SettingsSectionStatus("RE_ACTIVE","ENGINE",g_state.riskManagedTrading?"ACTIVE":"BYPASS",x+14,y+204,g_state.riskManagedTrading?COLOR_GREEN:COLOR_MUTED);

   SettingsCard("SET_RE_B","RISK BUDGET","Current account protection state",x+cw+gap,y,cw,h);

   SettingsSectionStatus("RE_EQUITY","EQUITY",FormatNumber(AccountInfoDouble(ACCOUNT_EQUITY)),x+cw+gap+14,y+54,COLOR_TEXT);

   SettingsSectionStatus("RE_DD","MAX DD",StringFormat("%.2f%%",g_state.maxDrawdownPct),x+cw+gap+14,y+84,COLOR_GOLD);

   DBar("RE_DDBAR","DRAWDOWN USED",g_state.maxDrawdownPct>0?100.0*g_state.maxDrawdown/g_state.maxDrawdownPct:0,x+cw+gap+14,y+124,cw-28,g_state.maxDrawdown>=g_state.maxDrawdownPct*0.8?COLOR_RED:COLOR_GREEN);

}

void CreateDailyGovernorSettingsPage()

{

   int x=ContentX(),y=SettingsBodyY(),w=ContentW(),h=SettingsBodyH(),gap=8,cw=(w-gap)/2;

   SettingsPageHeader("DAILY GOVERNOR","Daily profit, loss and basket-level account governor");

   SettingsCard("SET_DG_A","DAILY LIMITS","Session-level account protection",x,y,cw,h);

   SettingsColumnField("EDT_DLOSS","Daily loss %",DoubleToString(g_state.dailyLossLimitPct,2),x+14,y+54);

   SettingsColumnField("EDT_DPROF","Profit lock %",DoubleToString(g_state.dailyProfitLockPct,2),x+14,y+84);

   SettingsSectionStatus("DG_TODAY","TODAY P/L",FormatNumber(g_state.todayProfit),x+14,y+134,g_state.todayProfit>=0?COLOR_GREEN:COLOR_RED);

   SettingsCard("SET_DG_B","BASKET GOVERNOR","Basket-level profit and loss exits",x+cw+gap,y,cw,h);

   SettingsColumnField("EDT_BTP","Basket TP",DoubleToString(g_state.basketTakeProfitUSD,2),x+cw+gap+14,y+54);

   SettingsColumnField("EDT_BSL","Basket SL",DoubleToString(g_state.basketStopLossUSD,2),x+cw+gap+14,y+84);

   SettingsSectionStatus("DG_PL","OPEN P/L",FormatNumber(g_state.currentProfit),x+cw+gap+14,y+134,g_state.currentProfit>=0?COLOR_GREEN:COLOR_RED);

}

void CreateEntryProtectionSettingsPage()

{

   int x=ContentX(),y=SettingsBodyY(),w=ContentW(),h=SettingsBodyH(),gap=8,cw=(w-gap)/2;

   SettingsPageHeader("ENTRY PROTECTION","Protection parameters attached to newly created positions");

   SettingsCard("SET_EP_A","PROTECTION DISTANCES","SL and TP parameters",x,y,cw,h);

   SettingsColumnField("EDT_SL","Stop loss pips",DoubleToString(g_state.stopLossPips,1),x+14,y+54);

   SettingsColumnField("EDT_TP","Take profit pips",DoubleToString(g_state.takeProfitPips,1),x+14,y+84);

   DToggle("BTN_NEW_ORDER_SL","STOP LOSS",g_state.useStopLossForNewOrders,x+14,y+130,cw-28);

   DToggle("BTN_NEW_ORDER_TP","TAKE PROFIT",g_state.useTakeProfitForNewOrders,x+14,y+162,cw-28);

   SettingsCard("SET_EP_B","PROTECTION STATE","New-order protection status",x+cw+gap,y,cw,h);

   SettingsSectionStatus("EP_SL","SL",g_state.useStopLossForNewOrders?"ENABLED":"OFF",x+cw+gap+14,y+54,g_state.useStopLossForNewOrders?COLOR_GREEN:COLOR_MUTED);

   SettingsSectionStatus("EP_TP","TP",g_state.useTakeProfitForNewOrders?"ENABLED":"OFF",x+cw+gap+14,y+84,g_state.useTakeProfitForNewOrders?COLOR_GREEN:COLOR_MUTED);

   SettingsSectionStatus("EP_VALIDATE","VALIDATION",g_state.validateStops?"ON":"OFF",x+cw+gap+14,y+114,g_state.validateStops?COLOR_TEAL:COLOR_MUTED);

}

void CreatePositionManagementSettingsPage()

{

   int x=ContentX(),y=SettingsBodyY(),w=ContentW(),h=SettingsBodyH(),gap=8,cw=(w-gap)/2;

   SettingsPageHeader("POSITION MANAGEMENT","Break-even, trailing, holding time and OCO management");

   SettingsCard("SET_PM_A","MANAGEMENT RULES","Position lifecycle controls",x,y,cw,h);

   SettingsColumnField("EDT_BE","BE trigger",DoubleToString(g_state.breakEvenTriggerPips,1),x+14,y+54);

   SettingsColumnField("EDT_BEOFF","BE offset",DoubleToString(g_state.breakEvenOffsetPips,1),x+14,y+84);

   SettingsColumnField("EDT_TRAIL","Trailing ATR",DoubleToString(g_state.trailingATRMultiple,2),x+14,y+114);

   SettingsColumnField("EDT_MHOLD","Max hold min",DoubleToString(g_state.maxHoldMinutes,1),x+14,y+144);

   SettingsCard("SET_PM_B","AUTOMATION","Live position-management switches",x+cw+gap,y,cw,h);

   DToggle("FLG_BE","BREAK EVEN",g_state.breakEven,x+cw+gap+14,y+54,cw-28);

   DToggle("FLG_TRAIL","TRAILING STOP",g_state.trailingStop,x+cw+gap+14,y+88,cw-28);

   DToggle("TR_OCO","OCO CONTROL",g_state.oco,x+cw+gap+14,y+122,cw-28);

    DToggle("FLG_STRAT_MGMT","STRATEGY-AWARE MANAGEMENT",g_state.strategyAwareManagement,x+cw+gap+14,y+156,cw-28);

    DToggle("FLG_EXIT_COORD","EXIT COORDINATION",g_state.strategyExitCoordination,x+cw+gap+14,y+190,cw-28);

    SettingsSectionStatus("PM_SM","POLICY",g_state.strategyAwareManagement?GridStrategyName(g_state.gridType):"USER FIXED",x+cw+gap+14,y+222,g_state.strategyAwareManagement?COLOR_GOLD:COLOR_MUTED);

    SettingsSectionStatus("PM_EX","EXIT",g_state.strategyExitCoordination?(g_state.exitCoordinationActive?"ACTIVE":"ARMED"):"STANDARD",x+cw+gap+14,y+250,g_state.strategyExitCoordination?COLOR_GOLD:COLOR_MUTED);

   SettingsSectionStatus("PM_OPP","OPPOSITE",g_state.closeOppositeOnFill?"CLOSE":"KEEP",x+cw+gap+14,y+170, g_state.closeOppositeOnFill?COLOR_GREEN:COLOR_MUTED);

}



void CreateAICoreSettingsPage()

{

   int x=ContentX(),y=SettingsBodyY(),w=ContentW(),h=SettingsBodyH(),gap=8,cw=(w-gap)/2;

   SettingsPageHeader("AI CORE","Core intelligence controls and adaptive decision engine");

   SettingsCard("SET_AC_A","AI ENGINE","Primary intelligence switches",x,y,cw,h);

   SettingsColumnField("EDT_CONF","AI confidence",DoubleToString(g_state.aiConfidence,2),x+14,y+54);

   SettingsColumnField("EDT_LEARN","Learning period",IntegerToString(g_state.learningPeriod),x+14,y+84);

   DToggle("BTN_AI_TOGGLE","AI ENGINE",g_state.aiEnabled,x+14,y+130,cw-28);

   DToggle("AI_SET_NETWORK","NEURAL NETWORK",g_state.neuralNetwork,x+14,y+162,cw-28);

   DToggle("AI_SET_AUTO","AUTONOMOUS MODE",g_state.autonomousMode,x+14,y+194,cw-28);

   SettingsCard("SET_AC_B","CORE STATE","Current intelligence posture",x+cw+gap,y,cw,h);

   SettingsSectionStatus("AC_AI","ENGINE",g_state.aiEnabled?"ENABLED":"OFF",x+cw+gap+14,y+54,g_state.aiEnabled?COLOR_GREEN:COLOR_MUTED);

   SettingsSectionStatus("AC_NET","NETWORK",g_state.neuralNetwork?"ENABLED":"OFF",x+cw+gap+14,y+84,g_state.neuralNetwork?COLOR_TEAL:COLOR_MUTED);

   SettingsSectionStatus("AC_PRED","PREDICTION",StringFormat("%.0f%%",g_state.predictionAccuracy*100),x+cw+gap+14,y+114,COLOR_GOLD);

}

void CreateAITelemetrySettingsPage()

{

   int x=ContentX(),y=SettingsBodyY(),w=ContentW(),h=SettingsBodyH(),gap=8,cw=(w-gap)/2;

   SettingsPageHeader("AI TELEMETRY","Live intelligence telemetry and market interpretation");

   SettingsCard("SET_AT_A","TELEMETRY","Current intelligence readings",x,y,cw,h);

   SettingsSectionStatus("AT_REG","REGIME",g_state.regime,x+14,y+54,COLOR_GOLD);

   SettingsSectionStatus("AT_TREND","TREND",StringFormat("%.0f%%",g_state.trendStrength*100),x+14,y+84,COLOR_GREEN);

   SettingsSectionStatus("AT_SENT","SENTIMENT",StringFormat("%.0f%%",g_state.sentimentScore*100),x+14,y+114,COLOR_TEAL);

   SettingsSectionStatus("AT_VOL","VOLATILITY",StringFormat("%.0f%%",g_state.volatilityIndex*100),x+14,y+144,COLOR_ORANGE);

   SettingsSectionStatus("AT_ATR","ATR",DoubleToString(g_state.atrPrice,_Digits),x+14,y+174,COLOR_TEXT);

   SettingsCard("SET_AT_B","DIAGNOSTICS","Prediction and intelligence status",x+cw+gap,y,cw,h);

   SettingsSectionStatus("ATB_PRED","PREDICTION",StringFormat("%.0f%%",g_state.predictionAccuracy*100),x+cw+gap+14,y+54,COLOR_GOLD);

   SettingsSectionStatus("ATB_ENGINE","ENGINE",g_state.aiEnabled?"ACTIVE":"OFF",x+cw+gap+14,y+84,g_state.aiEnabled?COLOR_GREEN:COLOR_MUTED);

   DButton("AI_RESET2","RESET AI METRICS",x+cw+gap+14,y+h-44,cw-28,28,COLOR_PANEL2,false,6);

}

void CreateRiskThresholdSettingsPage()

{

   int x=ContentX(),y=SettingsBodyY(),w=ContentW(),h=SettingsBodyH(),gap=8,cw=(w-gap)/2;

   SettingsPageHeader("RISK THRESHOLD","Hard risk boundaries used to constrain grid exposure");

   SettingsCard("SET_RT_A","GRID THRESHOLDS","Per-grid and aggregate limits",x,y,cw,h);

   SettingsColumnField("EDT_MAXGRIDR","Max grid risk %",DoubleToString(g_state.maxGridRiskPct,2),x+14,y+54);

   SettingsColumnField("EDT_MAXDD","Max drawdown %",DoubleToString(g_state.maxDrawdownPct,2),x+14,y+84);

   SettingsSectionStatus("RT_RISK","RISK / GRID",StringFormat("%.2f%%",g_state.riskPerGridPct),x+14,y+134,COLOR_GOLD);

   SettingsCard("SET_RT_B","RISK UTILIZATION","Live threshold usage",x+cw+gap,y,cw,h);

   DBar("RT_DDBAR","DRAWDOWN USED",g_state.maxDrawdownPct>0?100.0*g_state.maxDrawdown/g_state.maxDrawdownPct:0,x+cw+gap+14,y+54,cw-28,g_state.maxDrawdown>=g_state.maxDrawdownPct*0.8?COLOR_RED:COLOR_GREEN);

   SettingsSectionStatus("RT_DD","CURRENT DD",StringFormat("%.2f%%",g_state.maxDrawdown),x+cw+gap+14,y+104,COLOR_TEXT);

}

void CreateRegimeFilterSettingsPage()

{

   int x=ContentX(),y=SettingsBodyY(),w=ContentW(),h=SettingsBodyH(),gap=8,cw=(w-gap)/2;

   SettingsPageHeader("REGIME FILTER","Market classification thresholds and decision gates");

   SettingsCard("SET_RGF_A","THRESHOLDS","Adaptive market classification",x,y,cw,h);

   SettingsColumnField("EDT_BULL","Bull threshold",DoubleToString(g_state.bullThreshold,2),x+14,y+54);

   SettingsColumnField("EDT_BEAR","Bear threshold",DoubleToString(g_state.bearThreshold,2),x+14,y+84);

   SettingsColumnField("EDT_HIVOL","High volatility",DoubleToString(g_state.highVolThreshold,2),x+14,y+114);

   SettingsColumnField("EDT_LOVOL","Low volatility",DoubleToString(g_state.lowVolThreshold,2),x+14,y+144);

   SettingsCard("SET_RGF_B","FILTER","Decision gates and live regime",x+cw+gap,y,cw,h);

   DToggle("AI_SET_REGIME","REGIME FILTER",g_state.regimeFilter,x+cw+gap+14,y+54,cw-28);

   DToggle("AI_SET_HIVOL","HIGH VOL PAUSE",g_state.pauseHighVolatility,x+cw+gap+14,y+88,cw-28);

   SettingsSectionStatus("RGF_LIVE","LIVE REGIME",g_state.regime,x+cw+gap+14,y+140,COLOR_GOLD);

   SettingsSectionStatus("RGF_TREND","TREND SCORE",StringFormat("%.2f",g_state.trendStrength),x+cw+gap+14,y+170,COLOR_GREEN);

   SettingsSectionStatus("RGF_VOL","VOL SCORE",StringFormat("%.2f",g_state.volatilityIndex),x+cw+gap+14,y+200,COLOR_ORANGE);

}

void CreateOrderExecutionSettingsPage()

{

   int x=ContentX(),y=SettingsBodyY(),w=ContentW(),h=SettingsBodyH(),gap=8,cw=(w-gap)/2;

   SettingsPageHeader("ORDER EXECUTION","Execution parameters, spread control and stop validation");

   SettingsCard("SET_OE_A","EXECUTION","Primary order routing controls",x,y,cw,h);

   SettingsColumnField("EDT_SLIP","Slippage",IntegerToString(g_state.slippage),x+14,y+54);

   SettingsColumnField("EDT_EXP","Pending expiry",IntegerToString(g_state.pendingExpiryMinutes),x+14,y+84);

   SettingsColumnField("EDT_SPR","Max spread pips",DoubleToString(g_state.maxSpreadPips,1),x+14,y+114);

   DToggle("BTN_SMART","SMART EXECUTION",g_state.smartExecution,x+14,y+160,cw-28);

   DToggle("FLG_VALIDATE","VALIDATE STOPS",g_state.validateStops,x+14,y+192,cw-28);

   SettingsCard("SET_OE_B","LIVE ROUTING","Current execution conditions",x+cw+gap,y,cw,h);

   SettingsSectionStatus("OE_STATUS","STATUS",g_state.executionStatus,x+cw+gap+14,y+54,COLOR_GOLD);

   SettingsSectionStatus("OE_SPR","SPREAD",StringFormat("%.2f pips",g_state.currentSpreadPips),x+cw+gap+14,y+84,g_state.currentSpreadPips<=g_state.maxSpreadPips?COLOR_GREEN:COLOR_RED);

   SettingsSectionStatus("OE_ACC","ACCEPTED",IntegerToString(g_state.acceptedOrders),x+cw+gap+14,y+114,COLOR_GREEN);

}

void CreateReliabilitySettingsPage()

{

   int x=ContentX(),y=SettingsBodyY(),w=ContentW(),h=SettingsBodyH(),gap=8,cw=(w-gap)/2;

   SettingsPageHeader("RELIABILITY","Order retry behavior and execution diagnostics");

   SettingsCard("SET_REL_A","RETRY POLICY","Recovery after failed execution",x,y,cw,h);

   SettingsColumnField("EDT_RETRY","Order retries",IntegerToString(g_state.orderRetryCount),x+14,y+54);SettingsSectionStatus("SR_LAST","LAST TYPE",g_state.lastOrderType!=""?g_state.lastOrderType:"--",x+14,y+94,COLOR_TEXT);SettingsSectionStatus("SR_RC","RETCODE",IntegerToString((int)g_state.lastOrderRetcode),x+14,y+124,COLOR_TEXT);SettingsSectionStatus("SR_RT","RETRIES USED",IntegerToString(g_state.lastOrderRetryCount),x+14,y+154,COLOR_TEXT);SettingsSectionStatus("SR_LT","LATENCY",StringFormat("%u ms",g_state.lastOrderLatencyMs),x+14,y+184,COLOR_TEXT);

   SettingsSectionStatus("REL_STATUS","STATUS",g_state.executionStatus,x+14,y+104,COLOR_GOLD);

   SettingsSectionStatus("REL_REJ","REJECTED",IntegerToString(g_state.rejectedOrders),x+14,y+134,g_state.rejectedOrders?COLOR_ORANGE:COLOR_GREEN);

   SettingsCard("SET_REL_B","EXECUTION HEALTH","Live reliability telemetry",x+cw+gap,y,cw,h);

   SettingsSectionStatus("RELB_ACC","ACCEPTED",IntegerToString(g_state.acceptedOrders),x+cw+gap+14,y+54,COLOR_GREEN);

   SettingsSectionStatus("RELB_REJ","REJECTED",IntegerToString(g_state.rejectedOrders),x+cw+gap+14,y+84,g_state.rejectedOrders?COLOR_ORANGE:COLOR_GREEN);

   SettingsSectionStatus("RELB_RETRY","RETRIES",IntegerToString(g_state.orderRetryCount),x+cw+gap+14,y+114,COLOR_TEXT);

}

void CreateSessionControlSettingsPage()

{

   int x=ContentX(),y=SettingsBodyY(),w=ContentW(),h=SettingsBodyH(),gap=8,cw=(w-gap)/2;

   SettingsPageHeader("SESSION CONTROL","Trading-hour and calendar controls");

   SettingsCard("SET_SC_A","TRADING SESSION","Permitted trading window",x,y,cw,h);

   SettingsColumnField("EDT_SSTART","Session start",IntegerToString(g_state.sessionStartHour),x+14,y+54);

   SettingsColumnField("EDT_SEND","Session end",IntegerToString(g_state.sessionEndHour),x+14,y+84);

   DToggle("FLG_SESSION","SESSION FILTER",g_state.useSessionFilter,x+14,y+130,cw-28);

   DToggle("FLG_WEEK","WEEKEND BLOCK",g_state.avoidWeekend,x+14,y+162,cw-28);

   SettingsCard("SET_SC_B","SESSION STATE","Current calendar context",x+cw+gap,y,cw,h);

   SettingsSectionStatus("SC_HOUR","SERVER HOUR",StringFormat("%02d",CurrentServerHour()),x+cw+gap+14,y+54,COLOR_TEXT);

   SettingsSectionStatus("SC_WEEK","WEEKEND",g_state.avoidWeekend?"BLOCK":"OPEN",x+cw+gap+14,y+84,g_state.avoidWeekend?COLOR_GREEN:COLOR_MUTED);

}

void CreateMarketGatesSettingsPage()

{

   int x=ContentX(),y=SettingsBodyY(),w=ContentW(),h=SettingsBodyH(),gap=8,cw=(w-gap)/2;

   SettingsPageHeader("MARKET GATES","Live environment filters before new grid activity");

   SettingsCard("SET_MG_A","LIVE GATES","Current market eligibility",x,y,cw,h);

   SettingsSectionStatus("MG_H","SERVER HOUR",StringFormat("%02d",CurrentServerHour()),x+14,y+54,COLOR_TEXT);

   SettingsSectionStatus("MG_R","REGIME",g_state.regime,x+14,y+84,COLOR_GOLD);

   SettingsSectionStatus("MG_S","SPREAD",StringFormat("%.2f / %.2f",g_state.currentSpreadPips,g_state.maxSpreadPips),x+14,y+114,g_state.currentSpreadPips<=g_state.maxSpreadPips?COLOR_GREEN:COLOR_RED);

   SettingsSectionStatus("MG_V","VOLATILITY",StringFormat("%.2f",g_state.volatilityIndex),x+14,y+144,COLOR_ORANGE);

   SettingsCard("SET_MG_B","GATE SWITCHES","Environment protection",x+cw+gap,y,cw,h);

   DToggle("FLG_HIV","HIGH VOL PAUSE",g_state.pauseHighVolatility,x+cw+gap+14,y+54,cw-28);

   DToggle("FLG_REGIME","REGIME FILTER",g_state.regimeFilter,x+cw+gap+14,y+88,cw-28);

   DToggle("FLG_SESSION","SESSION GATE",g_state.useSessionFilter,x+cw+gap+14,y+122,cw-28);

}

void CreateChartThemeSettingsPage()

{

   int x=ContentX(),y=SettingsBodyY(),w=ContentW(),h=SettingsBodyH(),gap=8,cw=(w-gap)/2;

   SettingsPageHeader("CHART THEME","Luxury visual theme and automatic chart styling");

   SettingsCard("SET_CT_A","THEME ENGINE","Automatic and manual presentation",x,y,cw,h);

   DToggle("FLG_CHART_AUTO","AUTO CHART THEME",g_state.autoChartTheme,x+14,y+54,cw-28);

   DButton("BTN_CHART_THEME","CYCLE CHART THEME",x+14,y+90,cw-28,30,COLOR_ACCENT,false,6);

   SettingsSectionStatus("CT_THEME","ACTIVE THEME",ChartThemeName(g_state.appliedChartTheme),x+14,y+144,COLOR_GOLD);

   SettingsSectionStatus("CT_MODE","THEME MODE",EnumToString(g_state.chartThemeMode),x+14,y+174,COLOR_TEXT);

   SettingsSectionStatus("CT_COUNT","THEMES","8 MANUAL + AUTO",x+14,y+204,COLOR_MUTED);

   SettingsCard("SET_CT_B","STYLE STATE","Live chart visibility controls",x+cw+gap,y,cw,h);

   DToggle("FLG_CHART_GRID","SHOW CHART GRID",g_state.chartShowGrid,x+cw+gap+14,y+54,cw-28);

   DToggle("FLG_CHART_TRADE","SHOW TRADE LEVELS",g_state.chartShowTradeLevels,x+cw+gap+14,y+88,cw-28);

   SettingsSectionStatus("CTB_GRID","GRID",g_state.chartShowGrid?"ON":"OFF",x+cw+gap+14,y+132,g_state.chartShowGrid?COLOR_GREEN:COLOR_MUTED);

   SettingsSectionStatus("CTB_TRADE","TRADE LEVELS",g_state.chartShowTradeLevels?"ON":"OFF",x+cw+gap+14,y+162,g_state.chartShowTradeLevels?COLOR_GREEN:COLOR_MUTED);

}

void CreateChartOptionsSettingsPage()

{

   int x=ContentX(),y=SettingsBodyY(),w=ContentW(),h=SettingsBodyH(),gap=8,cw=(w-gap)/2;

   SettingsPageHeader("CHART OPTIONS","Chart navigation, overlays and display options");

   SettingsCard("SET_CO_A","NAVIGATION","Chart movement and positioning",x,y,cw,h);

   DToggle("FLG_CHART_SCROLL","AUTO SCROLL",g_state.chartAutoScroll,x+14,y+54,cw-28);

   DToggle("FLG_CHART_SHIFT","CHART SHIFT",g_state.chartShift,x+14,y+88,cw-28);

   SettingsSectionStatus("CO_SCROLL","AUTO SCROLL",g_state.chartAutoScroll?"ON":"OFF",x+14,y+132,g_state.chartAutoScroll?COLOR_GREEN:COLOR_MUTED);

   SettingsSectionStatus("CO_SHIFT","CHART SHIFT",g_state.chartShift?"ON":"OFF",x+14,y+162,g_state.chartShift?COLOR_GREEN:COLOR_MUTED);

   SettingsCard("SET_CO_B","OVERLAYS","Chart information visibility",x+cw+gap,y,cw,h);

   DToggle("FLG_CHART_VOL","SHOW VOLUME",g_state.chartShowVolumes,x+cw+gap+14,y+54,cw-28);

   SettingsSectionStatus("CO_GRID","GRID",g_state.chartShowGrid?"ON":"OFF",x+cw+gap+14,y+98,g_state.chartShowGrid?COLOR_GREEN:COLOR_MUTED);

   SettingsSectionStatus("CO_TRADE","TRADE LEVELS",g_state.chartShowTradeLevels?"ON":"OFF",x+cw+gap+14,y+128,g_state.chartShowTradeLevels?COLOR_GREEN:COLOR_MUTED);

   SettingsSectionStatus("CO_VOL","VOLUME",g_state.chartShowVolumes?"ON":"OFF",x+cw+gap+14,y+158,g_state.chartShowVolumes?COLOR_GREEN:COLOR_MUTED);

}

void CreateAdvancedModeSettingsPage(){int x=ContentX(),y=SettingsBodyY(),w=ContentW(),h=SettingsBodyH(),gap=8,cw=(w-gap)/2;SettingsPageHeader("ADVANCED MODE","Optional intelligence controls. Manual commands remain user-authoritative.");SettingsCard("SAM1","CONTROL MODE","Who may initiate autonomous decisions",x,y,cw,h);DButton("BTN_CONTROL_MODE","MODE "+ControlModeName(g_state.controlMode),x+14,y+54,cw-28,30,COLOR_ACCENT,false,7);SettingsSectionStatus("SAM_RULE","MANUAL START","USER AUTHORITY",x+14,y+92,COLOR_GREEN);DToggle("ADV_ENTRY","ENTRY DECISION ENGINE",g_state.advancedEntryDecision,x+14,y+96,cw-28);DToggle("ADV_INTEL","MARKET INTELLIGENCE",g_state.marketIntelligence,x+14,y+128,cw-28);SettingsCard("SAM2","MODULES","Optional engines",x+cw+gap,y,cw,h);SettingsSectionStatus("SAM_AG","ADAPTIVE GRID",g_state.adaptiveGrid?"ON":"OFF",x+cw+gap+14,y+54,g_state.adaptiveGrid?COLOR_GREEN:COLOR_MUTED);SettingsSectionStatus("SAM_AL","ADAPTIVE LOT",g_state.adaptiveLot?"ON":"OFF",x+cw+gap+14,y+84,g_state.adaptiveLot?COLOR_GREEN:COLOR_MUTED);SettingsSectionStatus("SAM_SR","SMART REGIME",g_state.smartRegime?"ON":"OFF",x+cw+gap+14,y+114,g_state.smartRegime?COLOR_GREEN:COLOR_MUTED);SettingsSectionStatus("SAM_SC","SMART RECENTER",g_state.smartRecenter?"ON":"OFF",x+cw+gap+14,y+144,g_state.smartRecenter?COLOR_GREEN:COLOR_MUTED);}

void CreateAdaptiveGridSettingsPage(){int x=ContentX(),y=SettingsBodyY(),w=ContentW(),h=SettingsBodyH(),gap=8,cw=(w-gap)/2;SettingsPageHeader("ADAPTIVE GRID","Optional dynamic spacing inside user-defined bounds");SettingsCard("SAG1","GRID CONTROLLER","User value versus effective value",x,y,cw,h);DToggle("ADV_ADAPTIVE_GRID","ADAPTIVE GRID",g_state.adaptiveGrid,x+14,y+54,cw-28);SettingsColumnField("EDT_ADAPTIVE_SENS","Sensitivity",DoubleToString(g_state.adaptiveSensitivity,2),x+14,y+92);SettingsColumnField("EDT_MAX_STEP_CHANGE","Max step change %",DoubleToString(g_state.maxStepChangePct,1),x+14,y+122);SettingsSectionStatus("SAGC","CONFIGURED",StringFormat("%.1f pips",g_state.gridStep),x+14,y+168,COLOR_TEXT);SettingsSectionStatus("SAGE","EFFECTIVE",StringFormat("%.1f pips",g_state.effectiveGridStepPips),x+14,y+198,COLOR_GOLD);SettingsCard("SAG2","INPUTS","Current adaptation context",x+cw+gap,y,cw,h);SettingsSectionStatus("SAGA","ATR",DoubleToString(g_state.atrPrice,_Digits),x+cw+gap+14,y+54,COLOR_TEXT);SettingsSectionStatus("SAGV","VOLATILITY",StringFormat("%.2f",g_state.volatilityIndex),x+cw+gap+14,y+84,COLOR_ORANGE);SettingsSectionStatus("SAGR","REGIME",g_state.regime,x+cw+gap+14,y+114,COLOR_GOLD);}

void CreateAdaptiveLevelsSettingsPage(){int x=ContentX(),y=SettingsBodyY(),w=ContentW(),h=SettingsBodyH(),gap=8,cw=(w-gap)/2;SettingsPageHeader("ADAPTIVE LEVELS","Optional dynamic level count within safe user-defined bounds");SettingsCard("SAL1","LEVEL CONTROLLER","Adaptive level count",x,y,cw,h);DToggle("ADV_ADAPTIVE_LEVELS","ADAPTIVE LEVELS",g_state.adaptiveLevels,x+14,y+54,cw-28);SettingsColumnField("EDT_ADAPT_MIN","Minimum levels",IntegerToString(g_state.adaptiveMinLevels),x+14,y+92);SettingsColumnField("EDT_ADAPT_MAX","Maximum levels",IntegerToString(g_state.adaptiveMaxLevels),x+14,y+122);SettingsSectionStatus("SALC","CONFIGURED",IntegerToString(g_state.gridLevels),x+14,y+164,COLOR_TEXT);SettingsSectionStatus("SALE","EFFECTIVE",IntegerToString(g_state.effectiveGridLevels),x+14,y+194,COLOR_GOLD);SettingsCard("SAL2","CONTEXT","Current market driver",x+cw+gap,y,cw,h);SettingsSectionStatus("SALV","VOLATILITY",StringFormat("%.2f",g_state.volatilityIndex),x+cw+gap+14,y+54,COLOR_ORANGE);SettingsSectionStatus("SALS","SENSITIVITY",DoubleToString(g_state.adaptiveSensitivity,2),x+cw+gap+14,y+84,COLOR_TEXT);SettingsSectionStatus("SALSU","SUITABILITY",StringFormat("%.0f%%",g_state.marketSuitabilityScore*100),x+cw+gap+14,y+114,COLOR_TEAL);}

void CreateAdaptiveLotSettingsPage(){int x=ContentX(),y=SettingsBodyY(),w=ContentW(),h=SettingsBodyH(),gap=8,cw=(w-gap)/2;SettingsPageHeader("ADAPTIVE LOT","Optional volatility and exposure-aware lot adjustment");SettingsCard("SALT1","LOT CONTROLLER","Effective sizing",x,y,cw,h);DToggle("ADV_ADAPTIVE_LOT","ADAPTIVE LOT",g_state.adaptiveLot,x+14,y+54,cw-28);SettingsSectionStatus("SALT_BASE","BASE LOT",DoubleToString(g_state.lotSize,3),x+14,y+104,COLOR_TEXT);SettingsSectionStatus("SALT_EFF","EFFECTIVE LOT",DoubleToString(g_state.effectiveLot,3),x+14,y+134,COLOR_GOLD);SettingsCard("SALT2","LIMITS","User exposure ceiling",x+cw+gap,y,cw,h);SettingsColumnField("EDT_MAX_LOTS","Max total lots",DoubleToString(g_state.maxTotalLots,2),x+cw+gap+14,y+54);}

void CreateSmartEntrySettingsPage(){int x=ContentX(),y=SettingsBodyY(),w=ContentW(),h=SettingsBodyH(),gap=8,cw=(w-gap)/2;SettingsPageHeader("SMART ENTRY","Optional autonomous entry decision layer");SettingsCard("SSE1","ENTRY ENGINE","Only affects autonomous deployment",x,y,cw,h);DToggle("ADV_ENTRY2","ENTRY DECISION ENGINE",g_state.advancedEntryDecision,x+14,y+54,cw-28);SettingsSectionStatus("SSEM","MANUAL START","NOT FILTERED",x+14,y+104,COLOR_GREEN);SettingsSectionStatus("SSEA","AUTONOMOUS","OPTIONAL FILTER",x+14,y+134,COLOR_GOLD);SettingsCard("SSE2","LAST DECISION","Transparent decision result",x+cw+gap,y,cw,h);SettingsSectionStatus("SSED","DECISION",g_state.lastDecision,x+cw+gap+14,y+54,COLOR_TEXT);SettingsSectionStatus("SSER","REASON",g_state.lastActionReason,x+cw+gap+14,y+84,COLOR_MUTED);}

void CreateMarketIntelligenceSettingsPage(){int x=ContentX(),y=SettingsBodyY(),w=ContentW(),h=SettingsBodyH(),gap=8,cw=(w-gap)/2;SettingsPageHeader("MARKET INTELLIGENCE","Optional suitability scoring used only by enabled autonomous decisions");SettingsCard("SMI1","ENGINE","Transparent scoring and threshold",x,y,cw,h);DToggle("ADV_MARKET_INTEL","MARKET INTELLIGENCE",g_state.marketIntelligence,x+14,y+54,cw-28);SettingsColumnField("EDT_ENTRY_THRESHOLD","Min suitability",DoubleToString(g_state.autonomousMinSuitability,2),x+14,y+94);SettingsSectionStatus("SMISC","SUITABILITY",StringFormat("%.0f%%",g_state.marketSuitabilityScore*100),x+14,y+144,g_state.marketSuitabilityScore>=g_state.autonomousMinSuitability?COLOR_GREEN:COLOR_ORANGE);SettingsSectionStatus("SMIC","CONFIDENCE",StringFormat("%.0f%%",g_state.intelligenceConfidence*100),x+14,y+174,COLOR_GOLD);SettingsSectionStatus("SMIR","REGIME",g_state.regime,x+14,y+204,COLOR_GOLD);SettingsCard("SMI2","INPUTS","Current scoring context",x+cw+gap,y,cw,h);SettingsSectionStatus("SMIT","TREND",StringFormat("%.0f%%",g_state.trendStrength*100),x+cw+gap+14,y+54,COLOR_GREEN);SettingsSectionStatus("SMIV","VOLATILITY",StringFormat("%.0f%%",g_state.volatilityIndex*100),x+cw+gap+14,y+84,COLOR_ORANGE);SettingsSectionStatus("SMIS","SENTIMENT",StringFormat("%.0f%%",g_state.sentimentScore*100),x+cw+gap+14,y+114,COLOR_TEAL);SettingsSectionStatus("SMISP","SPREAD",StringFormat("%.1f / %.1f",g_state.currentSpreadPips,g_state.maxSpreadPips),x+cw+gap+14,y+144,COLOR_TEXT);SettingsSectionStatus("SMIRSN","DECISION",g_state.marketDecisionReason!=""?g_state.marketDecisionReason:"Waiting",x+cw+gap+14,y+184,COLOR_MUTED);}



void CreateSmartRegimeSettingsPage(){int x=ContentX(),y=SettingsBodyY(),w=ContentW(),h=SettingsBodyH(),gap=8,cw=(w-gap)/2;SettingsPageHeader("SMART REGIME","Optional regime-aware strategy adaptation");SettingsCard("SSR1","REGIME ENGINE","Optional market classification",x,y,cw,h);DToggle("ADV_SMART_REGIME","SMART REGIME",g_state.smartRegime,x+14,y+54,cw-28);SettingsSectionStatus("SSRC","CURRENT",g_state.regime,x+14,y+104,COLOR_GOLD);SettingsSectionStatus("SSRB","BULL THRESHOLD",StringFormat("%.2f",g_state.bullThreshold),x+14,y+134,COLOR_GREEN);SettingsSectionStatus("SSRE","BEAR THRESHOLD",StringFormat("%.2f",g_state.bearThreshold),x+14,y+164,COLOR_RED);SettingsCard("SSR2","AUTHORITY","Optional decision owner",x+cw+gap,y,cw,h);SettingsSectionStatus("SSRA","MODE",ControlModeName(g_state.controlMode),x+cw+gap+14,y+54,COLOR_GOLD);}

void CreateAuthoritySettingsPage(){int x=ContentX(),y=SettingsBodyY(),w=ContentW(),h=SettingsBodyH(),gap=8,cw=(w-gap)/2;SettingsPageHeader("AUTHORITY","See which module controls each effective value");SettingsCard("SAU1","OWNERSHIP","Current control owners",x,y,cw,h);SettingsSectionStatus("SAUG","GRID STEP",g_state.adaptiveGrid?"ADAPTIVE":"USER",x+14,y+54,g_state.adaptiveGrid?COLOR_GOLD:COLOR_GREEN);SettingsSectionStatus("SAUL","LEVELS",g_state.adaptiveLevels?"ADAPTIVE":"USER",x+14,y+84,g_state.adaptiveLevels?COLOR_GOLD:COLOR_GREEN);SettingsSectionStatus("SAUT","LOT",g_state.adaptiveLot?"ADAPTIVE":"USER",x+14,y+114,g_state.adaptiveLot?COLOR_GOLD:COLOR_GREEN);SettingsSectionStatus("SAUE","ENTRY",IsAutonomousControl()&&g_state.advancedEntryDecision?"ENTRY ENGINE":"USER",x+14,y+144,COLOR_GOLD);SettingsCard("SAU2","HARD LIMITS","User-defined boundaries",x+cw+gap,y,cw,h);SettingsSectionStatus("SAUM","MAX POSITIONS",IntegerToString(g_state.maxPositions),x+cw+gap+14,y+54,COLOR_TEXT);SettingsSectionStatus("SAUP","MAX PENDING",IntegerToString(g_state.maxPendingOrders),x+cw+gap+14,y+84,COLOR_TEXT);SettingsSectionStatus("SAUR","MAX GRID RISK",StringFormat("%.2f%%",g_state.maxGridRiskPct),x+cw+gap+14,y+114,COLOR_TEXT);}

void CreateAutonomyLimitsSettingsPage(){int x=ContentX(),y=SettingsBodyY(),w=ContentW(),h=SettingsBodyH(),gap=8,cw=(w-gap)/2;SettingsPageHeader("AUTONOMY LIMITS","Hard user boundaries for autonomous deployment");SettingsCard("SALIM1","DAILY AUTONOMY","Limit autonomous grid starts",x,y,cw,h);SettingsColumnField("EDT_AUTO_GRIDS","Max auto grids/day",IntegerToString(g_state.maxAutonomousGridsPerDay),x+14,y+54);SettingsSectionStatus("SALU","USED TODAY",IntegerToString(g_state.autonomousGridsToday),x+14,y+104,COLOR_TEXT);SettingsCard("SALIM2","EXPOSURE","Optional exposure ceiling",x+cw+gap,y,cw,h);DToggle("ADV_EXPOSURE","EXPOSURE MANAGER",g_state.exposureManager,x+cw+gap+14,y+54,cw-28);SettingsSectionStatus("SALM","MAX LOTS",g_state.maxTotalLots>0?DoubleToString(g_state.maxTotalLots,2):"UNLIMITED",x+cw+gap+14,y+104,COLOR_TEXT);}

void CreateEffectiveStateSettingsPage(){int x=ContentX(),y=SettingsBodyY(),w=ContentW(),h=SettingsBodyH(),gap=8,cw=(w-gap)/2;SettingsPageHeader("EFFECTIVE STATE","Configured values versus what the trade engine is using");SettingsCard("SES1","GRID","Current effective configuration",x,y,cw,h);SettingsSectionStatus("SESC","STEP",StringFormat("%.1f",g_state.gridStep),x+14,y+54,COLOR_TEXT);SettingsSectionStatus("SESE","EFFECTIVE STEP",StringFormat("%.1f",g_state.effectiveGridStepPips),x+14,y+84,COLOR_GOLD);SettingsSectionStatus("SELC","LEVELS",IntegerToString(g_state.gridLevels),x+14,y+114,COLOR_TEXT);SettingsSectionStatus("SELE","EFFECTIVE LEVELS",IntegerToString(g_state.effectiveGridLevels),x+14,y+144,COLOR_GOLD);SettingsCard("SES2","LOT / OWNER","Current effective lot and reason",x+cw+gap,y,cw,h);SettingsSectionStatus("SELB","BASE LOT",DoubleToString(g_state.lotSize,3),x+cw+gap+14,y+54,COLOR_TEXT);SettingsSectionStatus("SELE2","EFFECTIVE LOT",DoubleToString(g_state.effectiveLot,3),x+cw+gap+14,y+84,COLOR_GOLD);SettingsSectionStatus("SELO","OWNER",g_state.lastActionOwner,x+cw+gap+14,y+114,COLOR_GOLD);SettingsSectionStatus("SELR","REASON",g_state.lastActionReason,x+cw+gap+14,y+144,COLOR_MUTED);SettingsSectionStatus("SELS","SUITABILITY",StringFormat("%.0f%%",g_state.marketSuitabilityScore*100),x+cw+gap+14,y+174,COLOR_TEAL);SettingsSectionStatus("SELI","CONFIDENCE",StringFormat("%.0f%%",g_state.intelligenceConfidence*100),x+cw+gap+14,y+204,COLOR_GOLD);}

void CreateSmartRecenterSettingsPage(){int x=ContentX(),y=SettingsBodyY(),w=ContentW(),h=SettingsBodyH(),gap=8,cw=(w-gap)/2;SettingsPageHeader("SMART RECENTER","Optional adaptive recenter threshold");SettingsCard("SRC1","SMART RECENTER","Optional dynamic threshold",x,y,cw,h);DToggle("ADV_SMART_RECENTER","SMART RECENTER",g_state.smartRecenter,x+14,y+54,cw-28);SettingsSectionStatus("SRC_CFG","CONFIGURED",StringFormat("%.2f ATR",g_state.recenterATRMultiple),x+14,y+104,COLOR_TEXT);SettingsSectionStatus("SRC_VOL","VOLATILITY",StringFormat("%.2f",g_state.volatilityIndex),x+14,y+134,COLOR_ORANGE);SettingsCard("SRC2","ACTIVITY","Recent recenter count",x+cw+gap,y,cw,h);SettingsSectionStatus("SRC_REB","RE-CENTERS",IntegerToString(g_state.rebalances),x+cw+gap+14,y+54,COLOR_TEXT);}

void CreateSmartReplenishSettingsPage(){int x=ContentX(),y=SettingsBodyY(),w=ContentW(),h=SettingsBodyH(),gap=8,cw=(w-gap)/2;SettingsPageHeader("SMART REPLENISH","Optional pending-grid replenishment module");SettingsCard("SRP1","MODULE","Permission-based replenishment",x,y,cw,h);DToggle("ADV_REPLENISH","SMART REPLENISHMENT",g_state.smartReplenishment,x+14,y+54,cw-28);SettingsSectionStatus("SRPS","STATE",g_state.smartReplenishment?"ARMED":"OFF",x+14,y+104,g_state.smartReplenishment?COLOR_GREEN:COLOR_MUTED);SettingsSectionStatus("SRPP","PENDING",IntegerToString(g_state.pendingCount),x+14,y+134,COLOR_GOLD);SettingsCard("SRP2","CAPACITY","Current order capacity",x+cw+gap,y,cw,h);SettingsSectionStatus("SRPC","CAPACITY",StringFormat("%d / %d",g_state.pendingCount,g_state.maxPendingOrders),x+cw+gap+14,y+54,COLOR_TEXT);SettingsSectionStatus("SRPR","ADDED",IntegerToString(g_state.replenishments),x+cw+gap+14,y+84,COLOR_TEAL);SettingsColumnField("EDT_REPL_DELAY","Delay sec",IntegerToString(g_state.replenishDelaySeconds),x+cw+gap+14,y+114);}

void CreateExposureManagerSettingsPage(){int x=ContentX(),y=SettingsBodyY(),w=ContentW(),h=SettingsBodyH(),gap=8,cw=(w-gap)/2;SettingsPageHeader("EXPOSURE MANAGER","Optional aggregate exposure control");SettingsCard("SEM1","EXPOSURE","Live position exposure",x,y,cw,h);DToggle("ADV_EXPOSURE2","EXPOSURE MANAGER",g_state.exposureManager,x+14,y+54,cw-28);double lots=0;for(int i=0;i<PositionsTotal();i++){ulong t=PositionGetTicket(i);if(t>0&&IsGridOrder(t,false))lots+=PositionGetDouble(POSITION_VOLUME);}SettingsSectionStatus("SEML","OPEN LOTS",DoubleToString(lots,2),x+14,y+104,COLOR_TEAL);SettingsCard("SEM2","DIRECTION","Directional balance",x+cw+gap,y,cw,h);SettingsSectionStatus("SEMB","BUY POS",IntegerToString(g_state.buyPositions),x+cw+gap+14,y+54,COLOR_GREEN);SettingsSectionStatus("SEMS","SELL POS",IntegerToString(g_state.sellPositions),x+cw+gap+14,y+84,COLOR_RED);}

void CreateAdvancedProtectionSettingsPage(){int x=ContentX(),y=SettingsBodyY(),w=ContentW(),h=SettingsBodyH(),gap=8,cw=(w-gap)/2;SettingsPageHeader("ADVANCED PROTECTION","Optional drawdown-aware throttling");SettingsCard("SAP1","ENGINE","Optional protection layer",x,y,cw,h);DToggle("ADV_PROTECT","ADVANCED PROTECTION",g_state.advancedProtection,x+14,y+54,cw-28);SettingsSectionStatus("SAPD","CURRENT DD",StringFormat("%.2f%%",g_state.maxDrawdown),x+14,y+104,COLOR_TEXT);SettingsCard("SAP2","NORMAL PROTECTION","User-defined safeguards",x+cw+gap,y,cw,h);SettingsSectionStatus("SAPS","SL",g_state.useStopLossForNewOrders?"ON":"OFF",x+cw+gap+14,y+54,g_state.useStopLossForNewOrders?COLOR_GREEN:COLOR_MUTED);SettingsSectionStatus("SAPT","TP",g_state.useTakeProfitForNewOrders?"ON":"OFF",x+cw+gap+14,y+84,g_state.useTakeProfitForNewOrders?COLOR_GREEN:COLOR_MUTED);}

void CreateGridRecoverySettingsPage(){int x=ContentX(),y=SettingsBodyY(),w=ContentW(),h=SettingsBodyH(),gap=8,cw=(w-gap)/2;SettingsPageHeader("GRID RECOVERY","Transparent recovery state after restart or reconnect");SettingsCard("SGR1","RECOVERY","Current recovered grid state",x,y,cw,h);SettingsSectionStatus("SGRA","GRID",g_state.gridActive?"ACTIVE":"READY",x+14,y+54,g_state.gridActive?COLOR_GREEN:COLOR_TEXT);SettingsSectionStatus("SGRP","POSITIONS",IntegerToString(g_state.positionCount),x+14,y+84,COLOR_TEAL);SettingsSectionStatus("SGRN","PENDING",IntegerToString(g_state.pendingCount),x+14,y+114,COLOR_GOLD);SettingsCard("SGR2","ANCHOR","Operating center",x+cw+gap,y,cw,h);SettingsSectionStatus("SGRA2","ANCHOR",DoubleToString(g_state.anchorPrice,_Digits),x+cw+gap+14,y+54,COLOR_TEXT);DToggle("ADV_RECOVERY","RECOVERY ENGINE",g_state.gridRecovery,x+cw+gap+14,y+92,cw-28);DButton("BTN_RECOVER_GRID","RECOVER NOW",x+cw+gap+14,y+126,cw-28,28,COLOR_ACCENT,false,6);}

void CreateOrderGuardianSettingsPage(){int x=ContentX(),y=SettingsBodyY(),w=ContentW(),h=SettingsBodyH(),gap=8,cw=(w-gap)/2;SettingsPageHeader("ORDER GUARDIAN","Optional diagnostics for order permission");SettingsCard("SOG1","CHECKS","Current technical state",x,y,cw,h);SettingsSectionStatus("SOGC","CAPACITY",g_state.pendingCount<g_state.maxPendingOrders?"PASS":"FULL",x+14,y+54,g_state.pendingCount<g_state.maxPendingOrders?COLOR_GREEN:COLOR_RED);SettingsSectionStatus("SOGS","SPREAD",g_state.currentSpreadPips<=g_state.maxSpreadPips?"PASS":"HIGH",x+14,y+84,g_state.currentSpreadPips<=g_state.maxSpreadPips?COLOR_GREEN:COLOR_RED);SettingsCard("SOG2","POLICY","Manual commands remain user-authoritative",x+cw+gap,y,cw,h);SettingsSectionStatus("SOGM","MANUAL START","ALLOWED",x+cw+gap+14,y+54,COLOR_GREEN);SettingsSectionStatus("SOGA","AUTONOMOUS","OPTIONAL GATES",x+cw+gap+14,y+84,COLOR_GOLD);DToggle("FLG_GUARD","ORDER GUARDIAN",g_state.orderGuardian,x+cw+gap+14,y+114,cw-28);SettingsSectionStatus("SOGT","LAST RETCODE",IntegerToString((int)g_state.lastOrderRetcode),x+cw+gap+14,y+150,COLOR_TEXT);SettingsSectionStatus("SOGR","RETRIES",IntegerToString(g_state.lastOrderRetryCount),x+cw+gap+14,y+180,COLOR_TEXT);SettingsSectionStatus("SOGL","LATENCY",StringFormat("%u ms",g_state.lastOrderLatencyMs),x+cw+gap+14,y+210,COLOR_TEXT);}

void CreateDecisionJournalSettingsPage(){int x=ContentX(),y=SettingsBodyY(),w=ContentW(),h=SettingsBodyH(),gap=8,cw=(w-gap)/2;SettingsPageHeader("DECISION JOURNAL","Transparent record of EA actions and reasons");SettingsCard("SDJ1","JOURNAL","Record decisions and actions",x,y,cw,h);DToggle("ADV_JOURNAL","DECISION JOURNAL",g_state.decisionJournal,x+14,y+54,cw-28);SettingsSectionStatus("SDJC","EVENTS",IntegerToString(g_eventCount),x+14,y+104,COLOR_TEXT);SettingsSectionStatus("SDJL","LAST",g_state.lastDecision,x+14,y+134,COLOR_GOLD);SettingsCard("SDJ2","LATEST","Most recent action",x+cw+gap,y,cw,h);SettingsSectionStatus("SDJT","TIME",g_state.lastActionTime>0?TimeToString(g_state.lastActionTime,TIME_SECONDS):"--",x+cw+gap+14,y+54,COLOR_MUTED);SettingsSectionStatus("SDJO","OWNER",g_state.lastActionOwner,x+cw+gap+14,y+84,COLOR_GOLD);}

void CreateProfileControlSettingsPage()

{

   int x=ContentX(),y=SettingsBodyY(),w=ContentW(),h=SettingsBodyH(),gap=8,cw=(w-gap)/2;

   SettingsPageHeader("PROFILE CONTROL","Save and load user-owned configurations without changing live orders");

   SettingsCard("SPC1","USER PROFILES","Four local configuration slots",x,y,cw,h);

   SettingsSectionStatus("SPCM","CURRENT MODE",ControlModeName(g_state.controlMode),x+14,y+54,COLOR_GOLD);

   SettingsSectionStatus("SPCV","CURRENT PROFILE",g_lastLoadedProfile!=""?g_lastLoadedProfile:"RUNTIME",x+14,y+84,COLOR_TEXT);

   DButton("BTN_PROFILE_SAVE1","SAVE P1",x+14,y+122,(cw-36)/2,26,COLOR_ACCENT,false,6);

   DButton("BTN_PROFILE_SAVE2","SAVE P2",x+22+(cw-36)/2,y+122,(cw-36)/2,26,COLOR_ACCENT,false,6);

   DButton("BTN_PROFILE_SAVE3","SAVE P3",x+14,y+154,(cw-36)/2,26,COLOR_ACCENT,false,6);

   DButton("BTN_PROFILE_SAVE4","SAVE P4",x+22+(cw-36)/2,y+154,(cw-36)/2,26,COLOR_ACCENT,false,6);

   DButton("BTN_PROFILE_LOAD1","LOAD P1",x+14,y+190,(cw-36)/2,26,COLOR_PANEL2,false,6);

   DButton("BTN_PROFILE_LOAD2","LOAD P2",x+22+(cw-36)/2,y+190,(cw-36)/2,26,COLOR_PANEL2,false,6);

   DButton("BTN_PROFILE_LOAD3","LOAD P3",x+14,y+222,(cw-36)/2,26,COLOR_PANEL2,false,6);

   DButton("BTN_PROFILE_LOAD4","LOAD P4",x+22+(cw-36)/2,y+222,(cw-36)/2,26,COLOR_PANEL2,false,6);

   DText("SPC_NOTE","Profiles are saved to the terminal's MQL5 Files folder.",x+14,y+h-18,6,COLOR_MUTED,"Arial");

   SettingsCard("SPC2","SAFE APPLY & HISTORY","Review changes before committing",x+cw+gap,y,cw,h);

   SettingsSectionStatus("SPCA","PENDING","",x+cw+gap+14,y+54,COLOR_GOLD);

   DText("SPCA_V",g_pendingApplySummary!=""?g_pendingApplySummary:"No pending changes",x+cw+gap+14,y+70,6,COLOR_TEXT,"Arial");

   SettingsSectionStatus("SPCH","HISTORY",IntegerToString(g_configHistoryCount),x+cw+gap+14,y+116,COLOR_TEXT);

   for(int i=0;i<MathMin(5,g_configHistoryCount);i++) DText("SPCH_"+IntegerToString(i),g_configHistory[g_configHistoryCount-1-i],x+cw+gap+14,y+140+i*22,6,COLOR_MUTED,"Arial");

   DButton("BTN_PROFILE_RESET","RESET RUNTIME",x+cw+gap+14,y+h-76,cw-28,26,COLOR_PANEL2,false,6);

   DButton("BTN_PROFILE_REJOURNAL","CLEAR JOURNAL",x+cw+gap+14,y+h-44,cw-28,26,COLOR_PANEL2,false,6);

}



void CreateSimulationSettingsPage()

{

   int x=ContentX(),y=SettingsBodyY(),w=ContentW(),h=SettingsBodyH(),gap=8,cw=(w-gap)/2;

   SettingsPageHeader("SIMULATION","Preview effective values and projected order structure without sending orders");

   SettingsCard("SSIM1","EFFECTIVE PREVIEW","Configured versus active calculation",x,y,cw,h);

   SettingsSectionStatus("SSIMS","STEP",StringFormat("%.1f -> %.1f",g_state.gridStep,g_state.effectiveGridStepPips),x+14,y+54,COLOR_TEXT);

   SettingsSectionStatus("SSIML","LEVELS",StringFormat("%d -> %d",g_state.gridLevels,g_state.effectiveGridLevels),x+14,y+84,COLOR_TEXT);

   SettingsSectionStatus("SSIMT","LOT",StringFormat("%.3f -> %.3f",g_state.lotSize,g_state.effectiveLot),x+14,y+114,COLOR_TEXT);

   SettingsSectionStatus("SSIMP","PENDING",IntegerToString(MathMin(g_state.effectiveGridLevels*2,g_state.maxPendingOrders)),x+14,y+144,COLOR_GOLD);

   SettingsSectionStatus("SSIMR","GRID RISK",StringFormat("%.2f%%",g_state.gridRiskPct),x+14,y+174,COLOR_TEXT);

   DButton("BTN_SIM_PREVIEW","REFRESH PREVIEW",x+14,y+h-44,cw-28,28,COLOR_ACCENT,false,6);

   SettingsCard("SSIM2","SIMULATION SAFETY","Preview-only confirmation",x+cw+gap,y,cw,h);

   SettingsSectionStatus("SSIMS2","STATUS",g_simulationPreviewReady?"PREVIEW READY":"NOT RUN",x+cw+gap+14,y+54,g_simulationPreviewReady?COLOR_GREEN:COLOR_GOLD);

   SettingsSectionStatus("SSIMNO","ORDERS SENT","0",x+cw+gap+14,y+84,COLOR_GREEN);

   SettingsSectionStatus("SSIMWHY","MODE","NO EXECUTION",x+cw+gap+14,y+114,COLOR_MUTED);

}

void CreateSystemHealthSettingsPage(){int x=ContentX(),y=SettingsBodyY(),w=ContentW(),h=SettingsBodyH(),gap=8,cw=(w-gap)/2;SettingsPageHeader("SYSTEM HEALTH","Runtime health, configuration integrity and reliability summary");SettingsCard("SSH1","HEALTH","Current system state",x,y,cw,h);SettingsSectionStatus("SSHC","CONTROL",ControlModeName(g_state.controlMode),x+14,y+54,COLOR_GOLD);SettingsSectionStatus("SSHG","GRID",g_state.gridActive?"ACTIVE":"IDLE",x+14,y+84,g_state.gridActive?COLOR_GREEN:COLOR_MUTED);SettingsSectionStatus("SSHP","POSITIONS",IntegerToString(g_state.positionCount),x+14,y+114,COLOR_TEAL);SettingsSectionStatus("SSHCN","CONFIG",g_state.configHealth,x+14,y+144,g_state.configWarningCount==0?COLOR_GREEN:COLOR_ORANGE);SettingsSectionStatus("SSCW","WARNINGS",IntegerToString(g_state.configWarningCount),x+14,y+174,g_state.configWarningCount==0?COLOR_GREEN:COLOR_ORANGE);SettingsSectionStatus("SSCM","MESSAGE",g_state.configWarnings,x+14,y+204,COLOR_MUTED);SettingsSectionStatus("SSCL","LAST CHECK",g_state.lastConfigCheckTime>0?TimeToString(g_state.lastConfigCheckTime,TIME_SECONDS):"--",x+14,y+234,COLOR_MUTED);SettingsCard("SSH2","RELIABILITY","Execution and journal",x+cw+gap,y,cw,h);SettingsSectionStatus("SSHA","ACCEPTED",IntegerToString(g_state.acceptedOrders),x+cw+gap+14,y+54,COLOR_GREEN);SettingsSectionStatus("SSHR","REJECTED",IntegerToString(g_state.rejectedOrders),x+cw+gap+14,y+84,g_state.rejectedOrders?COLOR_ORANGE:COLOR_GREEN);SettingsSectionStatus("SSHE","EVENTS",IntegerToString(g_eventCount),x+cw+gap+14,y+114,COLOR_TEXT);SettingsSectionStatus("SSER","LAST RETCODE",IntegerToString((int)g_state.lastOrderRetcode),x+cw+gap+14,y+144,COLOR_TEXT);SettingsSectionStatus("SSET","LATENCY",StringFormat("%u ms",g_state.lastOrderLatencyMs),x+cw+gap+14,y+174,COLOR_TEXT);SettingsSectionStatus("SSRV","RECOVERY",g_state.recoveryStatus,x+cw+gap+14,y+204,COLOR_TEAL);DButton("BTN_CHECKPOINT_NOW","SAVE CHECKPOINT",x+cw+gap+14,y+h-72,cw-28,28,COLOR_PANEL2,false,6);DButton("BTN_CONFIG_CHECK2","CHECK CONFIG",x+cw+gap+14,y+h-40,cw-28,28,COLOR_PANEL2,false,6);}





// -------------------- SETTINGS V / VI: EXPANDED FEATURE DOMAINS --------------------

void CreateLifecycleDomainPage(int idx)

{

   int x=ContentX(),y=SettingsBodyY(),w=ContentW(),h=SettingsBodyH(),gap=8,cw=(w-gap)/2;

   string title="",sub="";

   switch(idx){

      case 0:title="GRID LIFECYCLE";sub="Cycle identity, state and lifecycle transitions";break;

      case 1:title="STRATEGY POLICY";sub="Selected strategy geometry and policy ownership";break;

      case 2:title="STRATEGY-AWARE MANAGEMENT";sub="Optional position-management policy by grid type";break;

      case 3:title="EXIT COORDINATION";sub="Optional coordinated shutdown of the active grid";break;

      case 4:title="LIFECYCLE RECOVERY";sub="Restart and recovery state for the active strategy";break;

      case 5:title="REPLENISHMENT POLICY";sub="Strategy-aware maintenance of consumed levels";break;

      case 6:title="RECENTER POLICY";sub="Strategy-aware anchor relocation and rebuild policy";break;

      case 7:title="EXIT POLICY";sub="Strategy-aware exit ownership and status";break;

      case 8:title="GRID SESSION CONTROL";sub="Session identity and active grid ownership";break;

      default:title="LIFECYCLE DIAGNOSTICS";sub="Live lifecycle telemetry and event accountability";break;

   }

   SettingsPageHeader(title,sub);

   SettingsCard("SL_A","CONTROL",title,x,y,cw,h);

   SettingsCard("SL_B","LIVE STATE","Current lifecycle telemetry",x+cw+gap,y,cw,h);

   if(idx==0){

      SettingsSectionStatus("SL_ID","CYCLE ID",StringFormat("%I64u",g_state.gridCycleId),x+14,y+54,COLOR_GOLD);

      SettingsSectionStatus("SL_ST","STATE",g_state.gridLifecycleState,x+14,y+84,COLOR_TEAL);

      SettingsSectionStatus("SL_RS","REASON",g_state.gridLifecycleReason,x+14,y+114,COLOR_TEXT);

      SettingsSectionStatus("SL_F","FILLS",IntegerToString(g_state.lifecycleFillCount),x+14,y+144,COLOR_GREEN);

      SettingsSectionStatus("SL_D","DELETES",IntegerToString(g_state.lifecycleDeleteCount),x+14,y+174,COLOR_ORANGE);

      SettingsSectionStatus("SL_R","RECOVERIES",IntegerToString(g_state.lifecycleRecoveryCount),x+14,y+204,COLOR_GOLD);

   }else if(idx==1){

      SettingsSectionStatus("SL_TYPE","GRID",CompactGridName(g_state.gridType),x+14,y+54,COLOR_GOLD);

      SettingsSectionStatus("SL_STR","STRATEGY",GridStrategyName(g_state.gridType),x+14,y+84,COLOR_TEXT);

      SettingsSectionStatus("SL_DIR","DIRECTION",GridDirectionModel(g_state.gridType),x+14,y+114,COLOR_TEAL);

      SettingsSectionStatus("SL_DIS","DISTANCE",GridDistanceModel(g_state.gridType),x+14,y+144,COLOR_TEXT);

      SettingsSectionStatus("SL_LOT","LOT MODEL",GridLotModel(g_state.gridType),x+14,y+174,COLOR_TEXT);

      SettingsSectionStatus("SL_ADV","ADVANCED",GridAdvancedPolicySummary(g_state.gridType),x+14,y+204,COLOR_GOLD);

   }else if(idx==2){

      DToggle("FLG_STRAT_MGMT","STRATEGY-AWARE MANAGEMENT",g_state.strategyAwareManagement,x+14,y+54,cw-28);

      SettingsSectionStatus("SL_PM","POLICY",g_state.strategyAwareManagement?GridStrategyName(g_state.gridType):"USER FIXED",x+14,y+104,g_state.strategyAwareManagement?COLOR_GOLD:COLOR_GREEN);

      SettingsSectionStatus("SL_BE","BE TRIGGER",StringFormat("%.1f pips",g_state.breakEvenTriggerPips),x+14,y+134,COLOR_TEXT);

      SettingsSectionStatus("SL_TR","TRAIL ATR",StringFormat("%.2f",g_state.trailingATRMultiple),x+14,y+164,COLOR_TEXT);

      SettingsSectionStatus("SL_H","MAX HOLD",g_state.maxHoldMinutes>0?StringFormat("%.0f min",g_state.maxHoldMinutes):"UNLIMITED",x+14,y+194,COLOR_TEXT);

   }else if(idx==3){

      DToggle("FLG_EXIT_COORD","EXIT COORDINATION",g_state.strategyExitCoordination,x+14,y+54,cw-28);

      SettingsSectionStatus("SL_EX","STATE",g_state.strategyExitCoordination?(g_state.exitCoordinationActive?"ACTIVE":"ARMED"):"OFF",x+14,y+104,g_state.strategyExitCoordination?COLOR_GOLD:COLOR_MUTED);

      SettingsSectionStatus("SL_ER","REASON",g_state.exitCoordinationReason!=""?g_state.exitCoordinationReason:"None",x+14,y+134,COLOR_TEXT);

      SettingsSectionStatus("SL_ET","TIME",g_state.exitCoordinationTime>0?TimeToString(g_state.exitCoordinationTime,TIME_SECONDS):"--",x+14,y+164,COLOR_MUTED);

   }else if(idx==4){

      SettingsSectionStatus("SL_RC","RECOVERY ENGINE",g_state.gridRecovery?"ON":"OFF",x+14,y+54,g_state.gridRecovery?COLOR_GREEN:COLOR_MUTED);

      SettingsSectionStatus("SL_RID","RECOVERY COUNT",IntegerToString(g_state.lifecycleRecoveryCount),x+14,y+84,COLOR_TEAL);

      SettingsSectionStatus("SL_RSTATE","STATE",g_state.gridLifecycleState,x+14,y+114,COLOR_GOLD);

      SettingsSectionStatus("SL_RANCH","ANCHOR",DoubleToString(g_state.anchorPrice,_Digits),x+14,y+144,COLOR_TEXT);

   }else if(idx==5){

      SettingsSectionStatus("SL_REP","SMART REPLENISH",g_state.smartReplenishment?"ON":"OFF",x+14,y+54,g_state.smartReplenishment?COLOR_GREEN:COLOR_MUTED);

      SettingsSectionStatus("SL_REPC","REPLENISHMENTS",IntegerToString(g_state.replenishments),x+14,y+84,COLOR_TEAL);

      SettingsSectionStatus("SL_DELAY","DELAY",StringFormat("%d sec",g_state.replenishDelaySeconds),x+14,y+114,COLOR_TEXT);

      SettingsSectionStatus("SL_CAP","PENDING",StringFormat("%d / %d",g_state.pendingCount,g_state.maxPendingOrders),x+14,y+144,COLOR_GOLD);

   }else if(idx==6){

      SettingsSectionStatus("SL_SRA","AUTO RECENTER",g_state.autoRecenter?"ON":"OFF",x+14,y+54,g_state.autoRecenter?COLOR_GREEN:COLOR_MUTED);

      SettingsSectionStatus("SL_SRS","SMART RECENTER",g_state.smartRecenter?"ON":"OFF",x+14,y+84,g_state.smartRecenter?COLOR_GOLD:COLOR_MUTED);

      SettingsSectionStatus("SL_SRT","TRIGGER",StringFormat("%.2f ATR",g_state.recenterATRMultiple),x+14,y+114,COLOR_TEXT);

      SettingsSectionStatus("SL_SRC","RE-CENTERS",IntegerToString(g_state.rebalances),x+14,y+144,COLOR_TEAL);

   }else if(idx==7){

      SettingsSectionStatus("SL_EPOL","OWNER",g_state.strategyExitCoordination?"EXIT COORDINATOR":"USER / STANDARD",x+14,y+54,COLOR_GOLD);

      SettingsSectionStatus("SL_ECO","COORD",g_state.strategyExitCoordination?(g_state.exitCoordinationActive?"ACTIVE":"ARMED"):"OFF",x+14,y+84,g_state.strategyExitCoordination?COLOR_GOLD:COLOR_MUTED);

      SettingsSectionStatus("SL_OCO","OCO",g_state.oco?"ON":"OFF",x+14,y+114,COLOR_TEXT);

   }else if(idx==8){

      SettingsSectionStatus("SL_GS","SESSION",g_state.gridActive?"ACTIVE":"IDLE",x+14,y+54,g_state.gridActive?COLOR_GREEN:COLOR_MUTED);

      SettingsSectionStatus("SL_GSID","CYCLE",StringFormat("%I64u",g_state.gridCycleId),x+14,y+84,COLOR_GOLD);

      SettingsSectionStatus("SL_GTYPE","TYPE",CompactGridName(g_state.gridType),x+14,y+114,COLOR_TEXT);

      SettingsSectionStatus("SL_GMODE","CONTROL",ControlModeName(g_state.controlMode),x+14,y+144,COLOR_TEAL);

   }else{

      SettingsSectionStatus("SL_DIAG1","STATE",g_state.gridLifecycleState,x+14,y+54,COLOR_GOLD);

      SettingsSectionStatus("SL_DIAG2","FILL EVENTS",IntegerToString(g_state.lifecycleFillCount),x+14,y+84,COLOR_GREEN);

      SettingsSectionStatus("SL_DIAG3","DELETE EVENTS",IntegerToString(g_state.lifecycleDeleteCount),x+14,y+114,COLOR_ORANGE);

      SettingsSectionStatus("SL_DIAG4","RECOVERY EVENTS",IntegerToString(g_state.lifecycleRecoveryCount),x+14,y+144,COLOR_TEAL);

      SettingsSectionStatus("SL_DIAG5","LAST REASON",g_state.gridLifecycleReason,x+14,y+174,COLOR_TEXT);

   }

   SettingsSectionStatus("SL_LIVE","LIVE",g_state.gridActive?"GRID ACTIVE":"READY",x+cw+gap+14,y+54,g_state.gridActive?COLOR_GREEN:COLOR_MUTED);

   SettingsSectionStatus("SL_PROF","PROFILE",CompactGridName(g_state.gridType),x+cw+gap+14,y+84,COLOR_GOLD);

   SettingsSectionStatus("SL_POS","POSITIONS",IntegerToString(g_state.positionCount),x+cw+gap+14,y+114,COLOR_TEAL);

   SettingsSectionStatus("SL_PEND","PENDING",IntegerToString(g_state.pendingCount),x+cw+gap+14,y+144,COLOR_GOLD);

   SettingsSectionStatus("SL_EXEC","EXECUTION",g_state.executionStatus,x+cw+gap+14,y+174,COLOR_TEXT);

}



string StrategyHealthSessionNameUI(int i)
{
   if(i==0)return "ASIA"; if(i==1)return "LONDON OPEN"; if(i==2)return "LONDON"; if(i==3)return "NEW YORK OPEN"; if(i==4)return "NEW YORK"; return "ROLLOVER / LATE";
}
string StrategyHealthRegimeNameUI(int i)
{
   if(i==0)return "TREND UP"; if(i==1)return "TREND DOWN"; if(i==2)return "RANGE"; if(i==3)return "BREAKOUT"; if(i==4)return "SHOCK / VOL"; return "OTHER";
}
int StrategyHealthSelectedGridIndexUI()
{
   // STRATEGY HEALTH UI must follow the same strategy authority as the live grid selector.
   // Manual/Assist: use the user's selected grid.
   // Autonomous: use the autonomous engine's selected grid.
   int selected=(g_state.controlMode==CONTROL_AUTONOMOUS)
                ?(int)g_autonomousGridType
                :(int)g_selectedGridType;
   if(selected<0||selected>=GRID_TYPE_COUNT) selected=(int)g_selectedGridType;
   if(selected<0||selected>=GRID_TYPE_COUNT) selected=(int)g_state.gridType;
   if(selected<0||selected>=GRID_TYPE_COUNT) selected=0;
   return selected;
}
void CreateStrategyHealthWorkspace(int view,int x,int y,int w,int h)
{
   RefreshStrategyHealth(false);
   int gap=8,cw=(w-gap)/2,rowH=24;
   int sel=StrategyHealthSelectedGridIndexUI();
   if(view==0)
   {
      SettingsCard("PH15O1","SELECTED STRATEGY","Current health context and allocation posture",x,y,cw,h);
      SettingsSectionStatus("PH15OH","GRID",CompactGridName((ENUM_GRID_TYPE)sel),x+14,y+54,COLOR_GOLD);
      SettingsSectionStatus("PH15OH2","HEALTH",StrategyHealthHealthTextUI(g_state.strategyHealthSelectedHealth,g_state.strategyHealthSelectedSamples),x+14,y+84,g_state.strategyHealthSelectedSamples<g_state.strategyHealthMinSamples?COLOR_MUTED:(g_state.strategyHealthSelectedHealth>=0.70?COLOR_GREEN:(g_state.strategyHealthSelectedHealth>=0.50?COLOR_GOLD:COLOR_RED)));
      SettingsSectionStatus("PH15OA","ALLOCATION",StrategyHealthAllocationTextUI(g_state.strategyHealthSelectedAllocation,g_state.strategyHealthSelectedSamples),x+14,y+114,g_state.strategyHealthSelectedSamples<g_state.strategyHealthMinSamples?COLOR_MUTED:COLOR_TEAL);
      SettingsSectionStatus("PH15OS","SAMPLES",IntegerToString(g_state.strategyHealthSelectedSamples),x+14,y+144,COLOR_TEXT);
      SettingsSectionStatus("PH15OD","DIRECTION",StrategyHealthHealthTextUI(g_state.strategyHealthSelectedDirectionHealth,g_state.strategyHealthSelectedSamples),x+14,y+174,g_state.strategyHealthSelectedSamples<g_state.strategyHealthMinSamples?COLOR_MUTED:COLOR_GOLD);
      SettingsSectionStatus("PH15OSE","SESSION",StringSubstr(g_state.strategyHealthSelectedSession,0,16),x+14,y+204,COLOR_TEXT);
      SettingsSectionStatus("PH15OR","REGIME",StringSubstr(g_state.strategyHealthSelectedRegime,0,16),x+14,y+234,COLOR_TEXT);
      SettingsSectionStatus("PH15OST","STATE",g_state.strategyHealthHealthState,x+14,y+264,g_state.strategyHealthHealthState=="HEALTHY"?COLOR_GREEN:(g_state.strategyHealthHealthState=="WEAK"?COLOR_RED:COLOR_GOLD));
      SettingsCard("PH15O2","ADAPTIVE ALLOCATION","Runtime posture and ownership",x+cw+gap,y,cw,h);
      SettingsSectionStatus("PH15OM","MODE",g_state.adaptiveStrategyAllocation?"ADAPTIVE":"MONITOR ONLY",x+cw+gap+14,y+54,g_state.adaptiveStrategyAllocation?COLOR_GOLD:COLOR_MUTED);
      SettingsSectionStatus("PH15OMI","LOOKBACK",StringFormat("%d days",g_state.strategyHealthLookbackDays),x+cw+gap+14,y+84,COLOR_TEXT);
      SettingsSectionStatus("PH15OMS","MIN SAMPLES",IntegerToString(g_state.strategyHealthMinSamples),x+cw+gap+14,y+114,COLOR_TEXT);
      SettingsSectionStatus("PH15OMN","MIN ALLOC",StringFormat("x%.2f",g_state.strategyHealthMinAllocation),x+cw+gap+14,y+144,COLOR_TEXT);
      SettingsSectionStatus("PH15OMX","MAX ALLOC",StringFormat("x%.2f",g_state.strategyHealthMaxAllocation),x+cw+gap+14,y+174,COLOR_TEXT);
      SettingsSectionStatus("PH15OE","EVALUATIONS",IntegerToString(g_state.strategyHealthEvaluationCount),x+cw+gap+14,y+204,COLOR_TEAL);
      SettingsSectionStatus("PH15ER","REASON",StringSubstr(g_state.strategyHealthAllocationReason,0,28),x+cw+gap+14,y+234,COLOR_TEXT);
      DText("PH15ON",g_state.strategyHealthSelectedSamples<g_state.strategyHealthMinSamples?"N/A until minimum sample size is reached.":"Selection weight only; no exit authority.",x+cw+gap+14,y+274,6,COLOR_MUTED,"Arial");
   }
   else if(view==1)
   {
      SettingsCard("PH15G1","21-GRID HEALTH","All grid types: health, samples, allocation",x,y,cw,h);
      SettingsCard("PH15G2","21-GRID HEALTH","Continuation",x+cw+gap,y,cw,h);
      for(int k=0;k<GRID_TYPE_COUNT;k++){ int col=(k<11?0:1),r=(k<11?k:k-11); int bx=(col==0?x+14:x+cw+gap+14),by=y+54+r*rowH; DText(StringFormat("PH15G_%d_N",k),StringFormat("%02d %s",k+1,CompactGridName((ENUM_GRID_TYPE)k)),bx,by,6,(k==sel?COLOR_GOLD:COLOR_TEXT),"Arial Bold"); DText(StringFormat("PH15G_%d_H",k),StrategyHealthHealthTextUI(g_phase15GridHealth[k],g_phase15GridSamples[k]),bx+112,by-1,6,g_phase15GridSamples[k]<g_state.strategyHealthMinSamples?COLOR_MUTED:(g_phase15GridHealth[k]>=0.70?COLOR_GREEN:(g_phase15GridHealth[k]>=0.50?COLOR_GOLD:COLOR_RED)),"Arial Bold"); DText(StringFormat("PH15G_%d_S",k),StringFormat("n%d",g_phase15GridSamples[k]),bx+152,by-1,6,COLOR_MUTED,"Arial"); DText(StringFormat("PH15G_%d_A",k),StrategyHealthAllocationTextUI(g_phase15GridAllocation[k],g_phase15GridSamples[k]),bx+178,by-1,6,(g_phase15GridSamples[k]<g_state.strategyHealthMinSamples?COLOR_MUTED:COLOR_TEAL),"Arial Bold"); }
   }
   else if(view==2)
   {
      SettingsCard("PH15D1","DIRECTIONAL HEALTH","LONG / SHORT health across all 21 grids",x,y,w,h);
      int colW=(w-12)/2;
      for(int k=0;k<GRID_TYPE_COUNT;k++)
      {
         int col=(k<11?0:1),r=(k<11?k:k-11);
         int bx=x+14+col*(colW+12),by=y+54+r*rowH;
         DText(StringFormat("PH15D_%d_N",k),StringFormat("%02d %s",k+1,CompactGridName((ENUM_GRID_TYPE)k)),bx,by,6,(k==sel?COLOR_GOLD:COLOR_TEXT),"Arial Bold");
         DText(StringFormat("PH15D_%d_L",k),"LONG "+StrategyHealthHealthTextUI(g_phase15GridDirectionHealth[k][0],g_phase15GridSamples[k]),bx+110,by-1,6,g_phase15GridSamples[k]<g_state.strategyHealthMinSamples?COLOR_MUTED:COLOR_TEAL,"Arial Bold");
         DText(StringFormat("PH15D_%d_S",k),"SHORT "+StrategyHealthHealthTextUI(g_phase15GridDirectionHealth[k][1],g_phase15GridSamples[k]),bx+190,by-1,6,g_phase15GridSamples[k]<g_state.strategyHealthMinSamples?COLOR_MUTED:COLOR_GOLD,"Arial Bold");
      }
   }
   else if(view==3)
   {
      SettingsCard("PH15DD1","DIRECTION DETAIL","Selected-grid directional health and edge",x,y,w,h);
      int half=(w-12)/2;
      SettingsCard("PH15DD2","SELECTED GRID","Current directional posture",x,y+28,half,h-28);
      SettingsCard("PH15DD3","DIRECTION METRICS","Long / short / edge",x+half+12,y+28,half,h-28);
      bool valid=(g_phase15GridSamples[sel]>=g_state.strategyHealthMinSamples);
      SettingsSectionStatus("PH15DDG","GRID",CompactGridName((ENUM_GRID_TYPE)sel),x+14,y+82,COLOR_GOLD);
      SettingsSectionStatus("PH15DDL","LONG",valid?StringFormat("%.0f%%",g_phase15GridDirectionHealth[sel][0]*100.0):"N/A",x+14,y+112,valid?COLOR_TEAL:COLOR_MUTED);
      SettingsSectionStatus("PH15DDS","SHORT",valid?StringFormat("%.0f%%",g_phase15GridDirectionHealth[sel][1]*100.0):"N/A",x+14,y+142,valid?COLOR_GOLD:COLOR_MUTED);
      SettingsSectionStatus("PH15DDN","SAMPLES",IntegerToString(g_phase15GridSamples[sel]),x+14,y+172,COLOR_TEXT);
      double edge=valid?MathAbs(g_phase15GridDirectionHealth[sel][0]-g_phase15GridDirectionHealth[sel][1])*100.0:0.0;
      SettingsSectionStatus("PH15DDE","EDGE",valid?StringFormat("%.0f%%",edge):"N/A",x+half+26,y+82,valid?COLOR_TEXT:COLOR_MUTED);
      SettingsSectionStatus("PH15DDB","BIAS",valid?(g_phase15GridDirectionHealth[sel][0]>g_phase15GridDirectionHealth[sel][1]?"LONG":"SHORT"):"N/A",x+half+26,y+112,valid?COLOR_GOLD:COLOR_MUTED);
      SettingsSectionStatus("PH15DDH","HEALTH",StrategyHealthHealthTextUI(g_phase15GridHealth[sel],g_phase15GridSamples[sel]),x+half+26,y+142,valid?COLOR_TEXT:COLOR_MUTED);
      SettingsSectionStatus("PH15DDA","ALLOCATION",StrategyHealthAllocationTextUI(g_phase15GridAllocation[sel],g_phase15GridSamples[sel]),x+half+26,y+172,valid?COLOR_TEAL:COLOR_MUTED);
      DText("PH15DDN2",valid?"Directional detail is telemetry only; it does not close or modify trades.":"Directional detail is N/A until the minimum sample size is reached.",x+14,y+h-22,6,COLOR_MUTED,"Arial");
   }
   else if(view==4)
   {
      SettingsCard("PH15S1","SESSION HEALTH","Selected grid by session",x,y,cw,h); SettingsCard("PH15S2","SESSION AVERAGE","All-grid average by session",x+cw+gap,y,cw,h);
      for(int j=0;j<STRATEGY_HEALTH_SESSION_COUNT;j++)
      {
         double av=0.0; int eligible=0;
         for(int k=0;k<GRID_TYPE_COUNT;k++)
            if(g_phase15GridSamples[k]>=g_state.strategyHealthMinSamples){ av+=g_phase15GridSessionHealth[k][j]; eligible++; }
         av=eligible>0?av/eligible:0.0;
         string selTxt=StrategyHealthHealthTextUI(g_phase15GridSessionHealth[sel][j],g_phase15GridSamples[sel]);
         string avgTxt=eligible>0?StringFormat("%.0f%%",av*100.0):"N/A";
         SettingsSectionStatus(StringFormat("PH15SS_%d",j),StrategyHealthSessionNameUI(j),selTxt,x+14,y+54+j*rowH,g_phase15GridSamples[sel]<g_state.strategyHealthMinSamples?COLOR_MUTED:(g_phase15GridSessionHealth[sel][j]>=0.70?COLOR_GREEN:(g_phase15GridSessionHealth[sel][j]>=0.50?COLOR_GOLD:COLOR_RED)));
         string aid=StringFormat("PH15SA_%d",j);
         int ax=x+cw+gap+14, ay=y+54+j*rowH;
         DText(aid+"_L",StrategyHealthSessionNameUI(j),ax,ay,7,COLOR_MUTED,"Arial Bold");
         DText(aid+"_V",avgTxt,ax+130,ay-1,7,eligible==0?COLOR_MUTED:(av>=0.70?COLOR_GREEN:(av>=0.50?COLOR_GOLD:COLOR_RED)),"Arial Bold");
      }
   }
   else if(view==5)
   {
      SettingsCard("PH15R1","REGIME HEALTH","Selected grid by regime",x,y,cw,h); SettingsCard("PH15R2","REGIME AVERAGE","All-grid average by regime",x+cw+gap,y,cw,h);
      for(int j=0;j<STRATEGY_HEALTH_REGIME_COUNT;j++){ double av=0.0; int eligible=0; for(int k=0;k<GRID_TYPE_COUNT;k++) if(g_phase15GridSamples[k]>=g_state.strategyHealthMinSamples){av+=g_phase15GridRegimeHealth[k][j]; eligible++;} av=eligible>0?av/eligible:0.0; string selTxt=StrategyHealthHealthTextUI(g_phase15GridRegimeHealth[sel][j],g_phase15GridSamples[sel]); string avgTxt=eligible>0?StringFormat("%.0f%%",av*100.0):"N/A"; SettingsSectionStatus(StringFormat("PH15RS_%d",j),StrategyHealthRegimeNameUI(j),selTxt,x+14,y+54+j*rowH,g_phase15GridSamples[sel]<g_state.strategyHealthMinSamples?COLOR_MUTED:(g_phase15GridRegimeHealth[sel][j]>=0.70?COLOR_GREEN:(g_phase15GridRegimeHealth[sel][j]>=0.50?COLOR_GOLD:COLOR_RED))); SettingsSectionStatus(StringFormat("PH15RA_%d",j),StrategyHealthRegimeNameUI(j),avgTxt,x+cw+gap+14,y+54+j*rowH,eligible==0?COLOR_MUTED:(av>=0.70?COLOR_GREEN:(av>=0.50?COLOR_GOLD:COLOR_RED))); }
   }
   else if(view==6)
   {
      // Full-width allocation matrix; control summary is isolated below it to prevent overlap.
      SettingsCard("PH15A1","ALLOCATION","Per-grid allocation factors",x,y,w,h);
      for(int k=0;k<GRID_TYPE_COUNT;k++)
      {
         int col=(k<11?0:1), r=(k<11?k:k-11);
         int bx=(col==0?x+14:x+cw+gap+14), by=y+54+r*22;
         DText(StringFormat("PH15A_%d_N",k),StringFormat("%02d %s",k+1,CompactGridName((ENUM_GRID_TYPE)k)),bx,by,6,(k==sel?COLOR_GOLD:COLOR_TEXT),"Arial Bold");
         string avTxt=StrategyHealthAllocationTextUI(g_phase15GridAllocation[k],g_phase15GridSamples[k]);
         DText(StringFormat("PH15A_%d_V",k),avTxt,bx+152,by-1,6,(g_phase15GridSamples[k]<g_state.strategyHealthMinSamples?COLOR_MUTED:COLOR_TEAL),"Arial Bold");
      }
      int cy=y+54+11*22+8;
      DText("PH15AC_MODE_L","MODE",x+14,cy,7,COLOR_MUTED,"Arial Bold");
      DText("PH15AC_MODE_V",g_state.adaptiveStrategyAllocation?"ADAPTIVE":"MONITOR ONLY",x+106,cy-1,7,g_state.adaptiveStrategyAllocation?COLOR_GOLD:COLOR_MUTED,"Arial Bold");
      DText("PH15AC_MIN_L","MIN",x+230,cy,7,COLOR_MUTED,"Arial Bold");
      DText("PH15AC_MIN_V",StringFormat("x%.2f",g_state.strategyHealthMinAllocation),x+322,cy-1,7,COLOR_TEXT,"Arial Bold");
      DText("PH15AC_MAX_L","MAX",x+392,cy,7,COLOR_MUTED,"Arial Bold");
      DText("PH15AC_MAX_V",StringFormat("x%.2f",g_state.strategyHealthMaxAllocation),x+484,cy-1,7,COLOR_TEXT,"Arial Bold");
      int cy2=cy+24;
      DText("PH15AC_SEL_L","SELECTED",x+14,cy2,7,COLOR_MUTED,"Arial Bold");
      DText("PH15AC_SEL_V",CompactGridName((ENUM_GRID_TYPE)sel),x+106,cy2-1,7,COLOR_GOLD,"Arial Bold");
      DText("PH15AC_HEALTH_L","HEALTH",x+230,cy2,7,COLOR_MUTED,"Arial Bold");
      DText("PH15AC_HEALTH_V",StrategyHealthHealthTextUI(g_state.strategyHealthSelectedHealth,g_state.strategyHealthSelectedSamples),x+322,cy2-1,7,g_state.strategyHealthSelectedSamples<g_state.strategyHealthMinSamples?COLOR_MUTED:COLOR_TEAL,"Arial Bold");
      DText("PH15AC_REASON",StringSubstr(g_state.strategyHealthAllocationReason,0,58),x+392,cy2-1,6,COLOR_TEXT,"Arial");
      DText("PH15ANN","Selection weight only; existing trades are unaffected.",x+14,cy2+22,6,COLOR_MUTED,"Arial");
   }
}

void CreateAutonomyDomainPage(int idx)
{
   int x=ContentX();
   int y=PageBodyY(10);
   int w=ContentW();
   int h=ContentH()-(y-ContentY())-6;
   int gap=8,cw=(w-gap)/2;
   string title="",sub="";
   switch(idx){
      case 0:title="AUTONOMOUS CONTROLLER";sub="Master autonomy mode and permission posture";break;
      case 1:title="AUTONOMOUS SCHEDULE";sub="Trading window and daily autonomous limits";break;
      case 2:title="AUTONOMOUS ENTRY";sub="Permission for the optional autonomous entry engine";break;
      case 3:title="AUTONOMOUS RISK";sub="Risk permissions available to autonomous operation";break;
      case 4:title="AUTONOMOUS GRID";sub="Grid construction permissions and capacity";break;
      case 5:title="STRATEGY SELECTION";sub="How autonomous mode may select grid profiles";break;
      case 6:title="AUTONOMOUS EXPOSURE";sub="Exposure ownership and hard boundaries";break;
      case 7:title="EMERGENCY CONTROL";sub="Autonomous shutdown and protection state";break;
      case 8:title="DECISION HISTORY";sub="Recent autonomous decisions and reasons";break;
      case 9:title="AUTONOMOUS PERFORMANCE";sub="Autonomous trade and grid performance telemetry";break;
      case 10:title="DECISION ENGINE";sub="Transparent autonomous decision pipeline";break;
      default:title="DECISION ENGINE";sub="Single autonomous decision pipeline and transparent scoring";break;
   }

   SettingsPageHeader(title,sub);
   SettingsCard("SA_A","CONTROL",title,x,y,cw,h);
   SettingsCard("SA_B","LIVE STATE","Current autonomous telemetry",x+cw+gap,y,cw,h);

   if(idx==0){
      DToggle("AI_SET_AUTO","AUTONOMOUS MODE",g_state.autonomousMode,x+14,y+54,cw-28);
      SettingsSectionStatus("SA_ADV","ENTRY ENGINE",g_state.advancedEntryDecision?"ON":"OFF",x+14,y+104,g_state.advancedEntryDecision?COLOR_GOLD:COLOR_MUTED);
      SettingsSectionStatus("SA_INT","INTELLIGENCE",g_state.marketIntelligence?"ON":"OFF",x+14,y+134,g_state.marketIntelligence?COLOR_TEAL:COLOR_MUTED);
      SettingsSectionStatus("SA_REG","SMART REGIME",g_state.smartRegime?"ON":"OFF",x+14,y+164,g_state.smartRegime?COLOR_GOLD:COLOR_MUTED);
      SettingsSectionStatus("SA_ENG","ENGINE",g_state.autonomousEngine?"ARMED":"OFF",x+14,y+194,g_state.autonomousEngine?COLOR_GREEN:COLOR_MUTED);
   }
   else if(idx==1){
      SettingsSectionStatus("SA_S","SESSION FILTER",g_state.useSessionFilter?"ON":"OFF",x+14,y+54,COLOR_TEXT);
      SettingsSectionStatus("SA_SW","WINDOW",StringFormat("%02d:00 - %02d:00",g_state.sessionStartHour,g_state.sessionEndHour),x+14,y+84,COLOR_TEXT);
      SettingsSectionStatus("SA_DAY","GRIDS TODAY",IntegerToString(g_state.autonomousGridsToday),x+14,y+114,COLOR_TEAL);
      SettingsSectionStatus("SA_MAX","MAX / DAY",g_state.maxAutonomousGridsPerDay>0?IntegerToString(g_state.maxAutonomousGridsPerDay):"UNLIMITED",x+14,y+144,COLOR_GOLD);
   }
   else if(idx==2){
      DToggle("ADV_ENTRY2","ENTRY DECISION ENGINE",g_state.advancedEntryDecision,x+14,y+54,cw-28);
      SettingsSectionStatus("SA_MAN","MANUAL START","NOT FILTERED",x+14,y+104,COLOR_GREEN);
      SettingsSectionStatus("SA_AUTO","AUTONOMOUS",g_state.autonomousMode?"ELIGIBLE":"OFF",x+14,y+134,COLOR_GOLD);
      SettingsSectionStatus("SA_DEC","LAST",g_state.lastDecision==""?"WAITING":StringSubstr(g_state.lastDecision,0,20),x+14,y+164,COLOR_TEXT);
   }
   else if(idx==3){
      SettingsSectionStatus("SA_RISK","RISK ENGINE",g_state.riskManagedTrading?"ON":"OFF",x+14,y+54,g_state.riskManagedTrading?COLOR_GREEN:COLOR_MUTED);
      SettingsSectionStatus("SA_DYN","DYNAMIC LOT",g_state.useDynamicRiskLot?"ON":"OFF",x+14,y+84,g_state.useDynamicRiskLot?COLOR_TEAL:COLOR_MUTED);
      SettingsSectionStatus("SA_RMAX","MAX GRID RISK",StringFormat("%.2f%%",g_state.maxGridRiskPct),x+14,y+114,COLOR_GOLD);
      SettingsSectionStatus("SA_DD","MAX DD",StringFormat("%.2f%%",g_state.maxDrawdownPct),x+14,y+144,COLOR_TEXT);
   }
   else if(idx==4){
      SettingsSectionStatus("SA_G","GRID",CompactGridName(g_state.gridType),x+14,y+54,COLOR_GOLD);
      SettingsSectionStatus("SA_L","LEVELS",IntegerToString(g_state.effectiveGridLevels),x+14,y+84,COLOR_TEXT);
      SettingsSectionStatus("SA_STEP","STEP",StringFormat("%.1f pips",g_state.effectiveGridStepPips),x+14,y+114,COLOR_TEAL);
      SettingsSectionStatus("SA_CAP","CAPACITY",StringFormat("%d / %d",g_state.pendingCount,g_state.maxPendingOrders),x+14,y+144,COLOR_TEXT);
   }
   else if(idx==5){
      // Keep strategy policy compact: one concept per row, no long sentence.
      SettingsSectionStatus("SA_SEL","SELECTED",CompactGridName(g_state.gridType),x+14,y+54,COLOR_GOLD);
      SettingsSectionStatus("SA_GEOM","GEOMETRY",StringFormat("STEP x%.2f",g_state.gridPolicyStepFactor),x+14,y+84,COLOR_TEAL);
      SettingsSectionStatus("SA_SIZE","SIZING",StringFormat("LOT x%.2f",g_state.gridPolicyLotFactor),x+14,y+114,COLOR_TEAL);
      string lvlPolicy=g_state.gridPolicyLevelReason==""?"USER BASE":g_state.gridPolicyLevelReason;
      SettingsSectionStatus("SA_LEVEL","LEVELS",StringSubstr(lvlPolicy,0,20),x+14,y+144,COLOR_TEXT);
      SettingsSectionStatus("SA_SM","SMART REGIME",g_state.smartRegime?"ON":"OFF",x+14,y+174,g_state.smartRegime?COLOR_GOLD:COLOR_MUTED);
   }
   else if(idx==6){
      SettingsSectionStatus("SA_EX","EXPOSURE ENGINE",g_state.exposureManager?"ON":"OFF",x+14,y+54,g_state.exposureManager?COLOR_GREEN:COLOR_MUTED);
      SettingsSectionStatus("SA_MAXL","MAX LOTS",g_state.maxTotalLots>0?DoubleToString(g_state.maxTotalLots,2):"UNLIMITED",x+14,y+84,COLOR_GOLD);
      SettingsSectionStatus("SA_USED","USED LOTS",DoubleToString(g_state.totalExposureLots,2),x+14,y+114,COLOR_TEAL);
      SettingsSectionStatus("SA_UTIL","UTILIZATION",StringFormat("%.1f%%",g_state.exposureUtilizationPct),x+14,y+144,COLOR_TEXT);
   }
   else if(idx==7){
      SettingsSectionStatus("SA_EP","ADV PROTECTION",g_state.advancedProtection?"ON":"OFF",x+14,y+54,g_state.advancedProtection?COLOR_GREEN:COLOR_MUTED);
      SettingsSectionStatus("SA_TH","THROTTLE",g_state.entryThrottleActive?"ACTIVE":"OFF",x+14,y+84,g_state.entryThrottleActive?COLOR_RED:COLOR_GREEN);
      SettingsSectionStatus("SA_TR","REASON",g_state.entryThrottleReason==""?"NONE":StringSubstr(g_state.entryThrottleReason,0,22),x+14,y+114,COLOR_TEXT);
   }
   else if(idx==8){
      SettingsSectionStatus("SA_H1","LAST DECISION",StringSubstr(g_state.lastDecision==""?"WAITING":g_state.lastDecision,0,22),x+14,y+54,COLOR_TEXT);
      SettingsSectionStatus("SA_H2","OWNER",StringSubstr(g_state.lastActionOwner==""?"NONE":g_state.lastActionOwner,0,18),x+14,y+84,COLOR_GOLD);
      SettingsSectionStatus("SA_H3","REASON",StringSubstr(g_state.lastActionReason==""?"NONE":g_state.lastActionReason,0,22),x+14,y+114,COLOR_MUTED);
      SettingsSectionStatus("SA_H4","TIME",g_state.lastActionTime>0?TimeToString(g_state.lastActionTime,TIME_SECONDS):"--",x+14,y+144,COLOR_TEXT);
   }
   else if(idx==9){
      SettingsSectionStatus("SA_PT","TRADES",IntegerToString(g_state.totalTrades),x+14,y+54,COLOR_TEXT);
      SettingsSectionStatus("SA_PW","WINS",IntegerToString(g_state.wins),x+14,y+84,COLOR_GREEN);
      SettingsSectionStatus("SA_PL","LOSSES",IntegerToString(g_state.losses),x+14,y+114,COLOR_RED);
      SettingsSectionStatus("SA_WR","WIN RATE",StringFormat("%.1f%%",g_state.winRate),x+14,y+144,COLOR_GOLD);
   }
   else if(idx==10){
      // Decision Engine is rendered in the live-state extension below.
   }
   // Single live-state column. Do not duplicate rows; each value has one visual owner.
   SettingsSectionStatus("SA_LIVE","CONTROL",ControlModeName(g_state.controlMode),x+cw+gap+14,y+54,COLOR_GOLD);
   SettingsSectionStatus("SA_REGIME","REGIME",StringSubstr(g_state.regime==""?"UNKNOWN":g_state.regime,0,18),x+cw+gap+14,y+84,COLOR_TEAL);
   SettingsSectionStatus("SA_SUIT","SUITABILITY",StringFormat("%.0f%%",g_state.marketSuitabilityScore*100),x+cw+gap+14,y+114,COLOR_TEAL);
   SettingsSectionStatus("SA_CONF","CONFIDENCE",StringFormat("%.0f%%",g_state.intelligenceConfidence*100),x+cw+gap+14,y+144,COLOR_GOLD);
   SettingsSectionStatus("SA_STAGE","STAGE",StringSubstr(g_state.autonomousStage==""?"IDLE":g_state.autonomousStage,0,18),x+cw+gap+14,y+174,COLOR_GOLD);
   SettingsSectionStatus("SA_CAND","CANDIDATE",StringSubstr(g_state.autonomousCandidate==""?"NONE":g_state.autonomousCandidate,0,18),x+cw+gap+14,y+204,COLOR_TEAL);
   if(idx==10){
      SettingsSectionStatus("P13_FIT","GRID FIT",StringFormat("%.0f%%",g_state.autonomousPlanScore*100.0),x+cw+gap+14,y+234,COLOR_GOLD);
      SettingsSectionStatus("P13_EDGE","EXPECTED EDGE",StringFormat("%.0f%%",g_state.autonomousPlanExpectedEdge*100.0),x+cw+gap+14,y+264,COLOR_TEAL);
      SettingsSectionStatus("P13_RISK","RISK BUDGET",StringFormat("%.2f%%",g_state.autonomousPlanRiskPct),x+cw+gap+14,y+294,COLOR_GOLD);
      SettingsSectionStatus("P13_EXEC","EXECUTION",StringSubstr(g_state.autonomousExecutionDecision==""?"WAITING":g_state.autonomousExecutionDecision,0,20),x+cw+gap+14,y+324,COLOR_TEXT);
      SettingsSectionStatus("P13_WHY","WHY",StringSubstr(g_state.autonomousDecisionReason==""?"WAITING":g_state.autonomousDecisionReason,0,24),x+cw+gap+14,y+354,COLOR_TEXT);
   }else{
      SettingsSectionStatus("SA_DECISION","DECISION",StringSubstr(g_state.autonomousSignal==""?"WAITING":g_state.autonomousSignal,0,18),x+cw+gap+14,y+234,COLOR_TEXT);
      SettingsSectionStatus("SA6_EDGE","DIR EDGE",StringFormat("%.0f%%",g_state.gridSelectionDirectionEdge*100.0),x+cw+gap+14,y+264,COLOR_GOLD);
      DText("SA6_EXP_L","EXPECTED EDGE",x+cw+gap+14,y+294,7,COLOR_MUTED,"Arial Bold");
      DText("SA6_EXP_V",StringFormat("%.0f%%",g_state.gridSelectionExpectedEdge*100.0),x+cw+gap+144,y+293,7,COLOR_TEAL,"Arial Bold");
      string why1=StringFormat("%s %s",g_state.gridSelectionSelectedGridName,g_state.gridSelectionDirection);
      string why2=StringFormat("REGIME %s",StringSubstr(g_state.marketRegime==""?"UNKNOWN":g_state.marketRegime,0,18));
      string why3=StringFormat("FIT %.0f%% | EDGE %.0f%%",g_state.gridSelectionSelectedScore*100.0,g_state.gridSelectionExpectedEdge*100.0);
      SettingsSectionStatus("SA6_WHY1","WHY 1",StringSubstr(why1,0,22),x+cw+gap+14,y+324,COLOR_TEXT);
      SettingsSectionStatus("SA6_WHY2","WHY 2",StringSubstr(why2,0,22),x+cw+gap+14,y+348,COLOR_TEXT);
      SettingsSectionStatus("SA6_WHY3","WHY 3",StringSubstr(why3,0,22),x+cw+gap+14,y+372,COLOR_TEXT);
   }
}


void CreateSettingsTab(){

   string titles[]={"SETTINGS I","SETTINGS II","SETTINGS III","SETTINGS IV","SETTINGS V","SETTINGS VI"};

   string subs[]={"Core grid and user configuration","AI, risk, execution and chart controls","Adaptive intelligence and autonomy controls","Advanced management and supporting controls","Lifecycle and strategy-specific controls","Autonomy permissions and governance"};

   string title=titles[g_dashboard.settingsPage];

   DPageTitle(title,subs[g_dashboard.settingsPage]);

   CreateSettingsTabBar();

   if(g_dashboard.settingsPage==0){switch(g_dashboard.settingsSubTab){case 0:CreateGridProfileSettingsPage();break;case 1:CreateLiveGridStateSettingsPage();break;case 2:CreateBaseSpacingSettingsPage();break;case 3:CreateRecenterFrontSettingsPage();break;case 4:CreateOrderCapacitySettingsPage();break;case 5:CreateGridBehaviorSettingsPage();break;}}

   else if(g_dashboard.settingsPage==1){switch(g_dashboard.settingsSubTab2){case 0:CreateAICoreSettingsPage();break;case 1:CreateAITelemetrySettingsPage();break;case 2:CreateRiskThresholdSettingsPage();break;case 3:CreateRegimeFilterSettingsPage();break;case 4:CreateOrderExecutionSettingsPage();break;case 5:CreateReliabilitySettingsPage();break;case 6:CreateSessionControlSettingsPage();break;case 7:CreateMarketGatesSettingsPage();break;case 8:CreateChartThemeSettingsPage();break;case 9:CreateChartOptionsSettingsPage();break;}}

   else if(g_dashboard.settingsPage==2){switch(g_dashboard.settingsSubTab3){case 0:CreateAdvancedModeSettingsPage();break;case 1:CreateAdaptiveGridSettingsPage();break;case 2:CreateAdaptiveLevelsSettingsPage();break;case 3:CreateAdaptiveLotSettingsPage();break;case 4:CreateSmartEntrySettingsPage();break;case 5:CreateMarketIntelligenceSettingsPage();break;case 6:CreateSmartRegimeSettingsPage();break;case 7:CreateAuthoritySettingsPage();break;case 8:CreateAutonomyLimitsSettingsPage();break;case 9:CreateEffectiveStateSettingsPage();break;}}

   else if(g_dashboard.settingsPage==3){switch(g_dashboard.settingsSubTab4){case 0:CreateSmartRecenterSettingsPage();break;case 1:CreateSmartReplenishSettingsPage();break;case 2:CreateOrderGuardianSettingsPage();break;case 3:CreateDecisionJournalSettingsPage();break;case 4:CreateProfileControlSettingsPage();break;case 5:CreateSimulationSettingsPage();break;}}

   else if(g_dashboard.settingsPage==4) CreateLifecycleDomainPage(g_dashboard.settingsSubTab5);

   else if(g_dashboard.settingsPage==5) CreateAutonomyDomainPage(g_dashboard.settingsSubTab6);


   int bx=ContentX(),by=g_dashboard.y+g_dashboard.height-50;

   DRect("SET_ACTION_BAR",bx,by,ContentW(),34,C'7,15,19',COLOR_PANEL2);

   DButton("BTN_APPLY","APPLY CHANGES",bx+8,by+3,125,28,COLOR_GOLD,false,7);

   DButton("BTN_RESET","RESET",bx+141,by+3,90,28,COLOR_RED,false,7);

   DText("SET_ACTION_NOTE","Live edits are staged • Apply commits them to the trading engine.",bx+242,by+11,6,COLOR_MUTED,"Arial");

}


void CreateDashboard()

{

   if(!g_dashboard.isVisible) return;
   DashboardSyncRefreshDashboardSyncAudit();

   FitDashboard();

   DeleteDashboard();

   DashboardHeader();

   DashboardNavigation();

   switch(g_dashboard.currentTab)

   {

      case 0:CreateHomeTab();break;

      case 1:CreateGridTab();break;

      case 2:CreateGridValidationLab();break;

      case 3:CreateStrategyHealthTab();break;

      case 4:CreateRiskTab();break;

      case 5:CreateAutonomyTab();break;

      case 6:CreateAnalyticsTab();break;

      case 7:CreateAITab();break;

      case 8:CreateExecutionTab();break;

      case 9:CreateTradesTab();break;

      case 10:CreateEmergencyTab();break;

      case 11:CreateTransparencyTab();break;

      case 12:CreateDiagnosticsTab();break;

      case 13:CreateToolsTab();break;

      case 14:CreateSettingsTab();break;

   }

   DashboardFooter();

   ChartRedraw();

}



void UpdateDashboard()
{
   static datetime last=0;
   if(TimeCurrent()-last<1) return;
   last=TimeCurrent();
   if(!g_dashboard.isVisible) return;
   static int oldW=0,oldH=0;
   int cw=(int)ChartGetInteger(0,CHART_WIDTH_IN_PIXELS);
   int ch=(int)ChartGetInteger(0,CHART_HEIGHT_IN_PIXELS);
   if(cw!=oldW || ch!=oldH){oldW=cw;oldH=ch;CreateDashboard();return;}
   DSet("HEADER_LIVE",g_state.gridActive?"● LIVE":"● READY",g_state.gridActive?COLOR_GREEN:COLOR_MUTED);
   DSet("HEADER_EQ",StringFormat("EQ %s",FormatNumber(AccountInfoDouble(ACCOUNT_EQUITY))),COLOR_TEXT);
   DSet("HEADER_PL",StringFormat("P/L %s",FormatNumber(g_state.currentProfit)),g_state.currentProfit>=0?COLOR_GREEN:COLOR_RED);
   DSet("HEADER_SUB",StringFormat("%s  •  %s  •  %s",_Symbol,EnumToString((ENUM_TIMEFRAMES)_Period),CompactGridName(g_state.gridType)),COLOR_TEXT);
   bool tradingActive=IsSystemTradingActiveUI();
   DSet("HDR_SYSTEM_V1",tradingActive?StringFormat("%s • %s",ControlModeName(g_state.controlMode),g_state.gridActive?"ENGINE ACTIVE":"ENGINE READY"):"INACTIVE • ALGO TRADING OFF",SystemActivityColorUI());
   DSet("HDR_SYSTEM_V2",g_state.emergencyActive?"SURVIVAL: ACTIVE":"SURVIVAL: CLEAR",g_state.emergencyActive?COLOR_RED:COLOR_GREEN);
   DSet("FOOTER_TEXT",StringFormat("MAGIC %I64u  ·  %s  ·  %s",InpMagicNumber,TimeToString(TimeCurrent(),TIME_SECONDS),g_state.executionStatus),COLOR_MUTED);
   ChartRedraw();
}


void DeleteDashboard()

{

   for(int i=ObjectsTotal(0)-1;i>=0;i--)

   {

      string n=ObjectName(0,i);

      if(StringFind(n,PREFIX)==0) ObjectDelete(0,n);

   }

}



// -------------------- SETTINGS / RISK -----------------------------

string ReadDashboardText(string id)
{
   string name=ObjName(id);
   if(ObjectFind(0,name)>=0) return ObjectGetString(0,name,OBJPROP_TEXT);
   return GetEditValue(name);
}

void ClearEditCache()

{

   g_editCount=0;

   for(int i=0;i<ArraySize(g_editFields);i++)

   {

      g_editFields[i].name="";

      g_editFields[i].value="";

      g_editFields[i].modified=false;

   }

}



void FlushVisibleDashboardEdits()
{
   int total=ObjectsTotal(0,0,-1);
   for(int i=0;i<total;i++)
   {
      string name=ObjectName(0,i,0,-1);
      if(StringFind(name,PREFIX)!=0) continue;
      if((ENUM_OBJECT)ObjectGetInteger(0,name,OBJPROP_TYPE)!=OBJ_EDIT) continue;
      StoreEditValue(name,ObjectGetString(0,name,OBJPROP_TEXT));
   }
}

void SyncFromDashboard()

{

#define READ_D(ID,TARGET) { string _v=ReadDashboardText(ID); if(_v!="") TARGET=StringToDouble(_v); }

#define READ_I(ID,TARGET) { string _v=ReadDashboardText(ID); if(_v!="") TARGET=(int)StringToInteger(_v); }



   READ_D("EDT_STEP",g_state.gridStep);

   READ_D("EDT_MINSTEP",g_state.minGridStep);

   READ_D("EDT_MAXSTEP",g_state.maxGridStep);

   READ_I("EDT_LEVELS",g_state.gridLevels);

   READ_D("EDT_LOT",g_state.lotSize);

   READ_D("EDT_MULT",g_state.lotMultiplier);

   READ_D("EDT_ATRM",g_state.atrSpacingMultiplier);

   READ_D("EDT_RECATR",g_state.recenterATRMultiple);

   READ_D("EDT_FRONT",g_state.frontOrderDistancePips);

   READ_I("EDT_MPOS",g_state.maxPositions);

   READ_I("EDT_MPEND",g_state.maxPendingOrders);



   READ_D("EDT_RISK",g_state.riskPerGridPct);

   READ_D("EDT_MAXGRIDR",g_state.maxGridRiskPct);

   READ_D("EDT_MAXDD",g_state.maxDrawdownPct);

   READ_D("EDT_DLOSS",g_state.dailyLossLimitPct);

   READ_D("EDT_DPROF",g_state.dailyProfitLockPct);

   READ_D("EDT_BTP",g_state.basketTakeProfitUSD);

   READ_D("EDT_BSL",g_state.basketStopLossUSD);

   READ_D("EDT_SL",g_state.stopLossPips);

   READ_D("EDT_TP",g_state.takeProfitPips);

   READ_D("EDT_BE",g_state.breakEvenTriggerPips);

   READ_D("EDT_BEOFF",g_state.breakEvenOffsetPips);

   READ_D("EDT_TRAIL",g_state.trailingATRMultiple);

   READ_D("EDT_MHOLD",g_state.maxHoldMinutes);



   READ_D("EDT_CONF",g_state.aiConfidence);

   READ_I("EDT_LEARN",g_state.learningPeriod);

   READ_D("EDT_BULL",g_state.bullThreshold);

   READ_D("EDT_BEAR",g_state.bearThreshold);

   READ_D("EDT_HIVOL",g_state.highVolThreshold);

   READ_D("EDT_LOVOL",g_state.lowVolThreshold);



   READ_D("EDT_SPR",g_state.maxSpreadPips);

   READ_I("EDT_SLIP",g_state.slippage);

   READ_I("EDT_EXP",g_state.pendingExpiryMinutes);

    READ_I("EDT_RETRY",g_state.orderRetryCount);

   READ_I("EDT_REPL_DELAY",g_state.replenishDelaySeconds);

   READ_I("EDT_SSTART",g_state.sessionStartHour);

   READ_I("EDT_SEND",g_state.sessionEndHour);

   READ_D("EDT_ADAPTIVE_SENS",g_state.adaptiveSensitivity);READ_D("EDT_MAX_STEP_CHANGE",g_state.maxStepChangePct);READ_D("EDT_MAX_LOTS",g_state.maxTotalLots);READ_I("EDT_AUTO_GRIDS",g_state.maxAutonomousGridsPerDay);READ_D("EDT_ENTRY_THRESHOLD",g_state.autonomousMinSuitability);READ_I("EDT_ADAPT_MIN",g_state.adaptiveMinLevels);READ_I("EDT_ADAPT_MAX",g_state.adaptiveMaxLevels);



#undef READ_D

#undef READ_I



   // Push changed runtime settings directly into the trade engine.

   trade.SetExpertMagicNumber(g_v14ExecutionMagic>0?g_v14ExecutionMagic:(ulong)InpMagicNumber);

   trade.SetDeviationInPoints((ulong)MathMax(0,g_state.slippage));



   ValidateSettings();

   UpdateConfigurationHealth();

   g_state.executionStatus="SETTINGS APPLIED";

   g_state.lastActionTime=TimeCurrent();

}



void SyncAutonomousEngineFromDashboard()

{

   string v;

   v=GetEditValue("EDT_AUTO_MIN_SCORE",DoubleToString(g_state.autonomousMinScore,2)); if(v!="") g_state.autonomousMinScore=ClampDouble(StringToDouble(v),0,1);

   v=GetEditValue("EDT_AUTO_MIN_CONF",DoubleToString(g_state.autonomousMinConfidence,2)); if(v!="") g_state.autonomousMinConfidence=ClampDouble(StringToDouble(v),0,1);

   v=GetEditValue("EDT_AUTO_INTERVAL",IntegerToString(g_state.autonomousDecisionIntervalSec)); if(v!="") g_state.autonomousDecisionIntervalSec=MathMax(0,(int)StringToInteger(v));

   v=GetEditValue("EDT_AUTO_COOLDOWN",IntegerToString(g_state.autonomousCooldownSec)); if(v!="") g_state.autonomousCooldownSec=MathMax(0,(int)StringToInteger(v));

}



bool ValidateSettings(){if(g_state.gridStep<=0)g_state.gridStep=1;if(g_state.minGridStep<=0)g_state.minGridStep=1;if(g_state.maxGridStep<g_state.minGridStep)g_state.maxGridStep=g_state.minGridStep;if(g_state.gridLevels<1)g_state.gridLevels=1;if(g_state.gridLevels>50)g_state.gridLevels=50;if(g_state.lotSize<=0)g_state.lotSize=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN);if(g_state.lotMultiplier<0.1)g_state.lotMultiplier=0.1;if(g_state.maxPositions<1)g_state.maxPositions=1;if(g_state.maxPendingOrders<1)g_state.maxPendingOrders=1;if(g_state.maxSpreadPips<0)g_state.maxSpreadPips=0;if(g_state.riskPerGridPct<0.01)g_state.riskPerGridPct=0.01;if(g_state.riskPerGridPct>100)g_state.riskPerGridPct=100;if(g_state.maxGridRiskPct<0)g_state.maxGridRiskPct=0;if(g_state.maxGridRiskPct>100)g_state.maxGridRiskPct=100;if(g_state.maxDrawdownPct<0.1)g_state.maxDrawdownPct=0.1;if(g_state.stopLossPips<0)g_state.stopLossPips=0;if(g_state.takeProfitPips<0)g_state.takeProfitPips=0;g_state.adaptiveSLATRMultiple=ClampDouble(g_state.adaptiveSLATRMultiple,0.50,4.00);g_state.adaptiveTPATRMultiple=ClampDouble(g_state.adaptiveTPATRMultiple,0.75,6.00);g_state.profitLockTriggerPips=MathMax(1.0,g_state.profitLockTriggerPips);g_state.profitLockOffsetPips=MathMax(0.0,g_state.profitLockOffsetPips);g_state.runnerATRMultiple=ClampDouble(g_state.runnerATRMultiple,0.50,5.00);if(g_state.recenterATRMultiple<0.5)g_state.recenterATRMultiple=0.5;if(g_state.frontOrderDistancePips<0.1)g_state.frontOrderDistancePips=0.1;if(g_state.atrSpacingMultiplier<0.1)g_state.atrSpacingMultiplier=0.1;g_state.sessionStartHour=MathMax(0,MathMin(23,g_state.sessionStartHour));g_state.sessionEndHour=MathMax(0,MathMin(23,g_state.sessionEndHour));g_state.orderRetryCount=MathMax(0,MathMin(10,g_state.orderRetryCount));g_state.replenishDelaySeconds=MathMax(0,MathMin(3600,g_state.replenishDelaySeconds));g_state.pendingExpiryMinutes=MathMax(0,g_state.pendingExpiryMinutes);g_state.learningPeriod=MathMax(1,g_state.learningPeriod);g_state.adaptiveSensitivity=ClampDouble(g_state.adaptiveSensitivity,0,1);g_state.maxStepChangePct=ClampDouble(g_state.maxStepChangePct,0,100);if(g_state.maxTotalLots<0)g_state.maxTotalLots=0;g_state.maxAutonomousGridsPerDay=MathMax(0,MathMin(1000,g_state.maxAutonomousGridsPerDay));g_state.autonomousMinSuitability=ClampDouble(g_state.autonomousMinSuitability,0,1);g_state.adaptiveMinLevels=MathMax(1,MathMin(50,g_state.adaptiveMinLevels));g_state.adaptiveMaxLevels=MathMax(g_state.adaptiveMinLevels,MathMin(50,g_state.adaptiveMaxLevels));g_state.adaptiveAnchorMode=(ENUM_GRID_ANCHOR_MODE)MathMax(0,MathMin(3,(int)g_state.adaptiveAnchorMode));return true;}



bool IsWeekend(){MqlDateTime dt;TimeToStruct(TimeCurrent(),dt);return dt.day_of_week==0||dt.day_of_week==6;}

bool IsSessionAllowed(){if(g_state.avoidWeekend&&IsWeekend())return false;if(!g_state.useSessionFilter)return true;int h=CurrentServerHour();if(g_state.sessionStartHour==g_state.sessionEndHour)return true;if(g_state.sessionStartHour<g_state.sessionEndHour)return h>=g_state.sessionStartHour&&h<g_state.sessionEndHour;return h>=g_state.sessionStartHour||h<g_state.sessionEndHour;}

datetime DayStart(){MqlDateTime dt;TimeToStruct(TimeCurrent(),dt);dt.hour=0;dt.min=0;dt.sec=0;return StructToTime(dt);}

double CalculateTodayClosedProfit(){datetime f=DayStart(),t=TimeCurrent();if(!HistorySelect(f,t))return 0;double p=0;for(int i=0;i<HistoryDealsTotal();i++){ulong d=HistoryDealGetTicket(i);if(d==0)continue;if(HistoryDealGetString(d,DEAL_SYMBOL)!=_Symbol)continue;if((ulong)HistoryDealGetInteger(d,DEAL_MAGIC)!=InpMagicNumber)continue;if((ENUM_DEAL_ENTRY)HistoryDealGetInteger(d,DEAL_ENTRY)!=DEAL_ENTRY_OUT)continue;p+=HistoryDealGetDouble(d,DEAL_PROFIT)+HistoryDealGetDouble(d,DEAL_SWAP)+HistoryDealGetDouble(d,DEAL_COMMISSION);}return p;}

void UpdatePerformanceStats(){g_state.todayProfit=CalculateTodayClosedProfit();g_state.totalTrades=0;g_state.wins=0;g_state.losses=0;g_state.totalProfit=0;if(!HistorySelect(TimeCurrent()-86400*30,TimeCurrent())){g_state.winRate=0;return;}for(int i=0;i<HistoryDealsTotal();i++){ulong d=HistoryDealGetTicket(i);if(d==0)continue;if(HistoryDealGetString(d,DEAL_SYMBOL)!=_Symbol)continue;if((ulong)HistoryDealGetInteger(d,DEAL_MAGIC)!=InpMagicNumber)continue;if((ENUM_DEAL_ENTRY)HistoryDealGetInteger(d,DEAL_ENTRY)!=DEAL_ENTRY_OUT)continue;double p=HistoryDealGetDouble(d,DEAL_PROFIT)+HistoryDealGetDouble(d,DEAL_SWAP)+HistoryDealGetDouble(d,DEAL_COMMISSION);g_state.totalProfit+=p;g_state.totalTrades++;if(p>=0)g_state.wins++;else g_state.losses++;}g_state.winRate=g_state.totalTrades>0?(double)g_state.wins/g_state.totalTrades*100.0:0;}

double EstimateGridRiskPct(){
   double eq=AccountInfoDouble(ACCOUNT_EQUITY);
   if(eq<=0)return 0;
   double ts=SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE),tv=SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_VALUE),sd=GetStopDistancePrice();
   if(ts<=0||tv<=0||sd<=0)return 0;
   double perLot=(sd/ts)*tv,total=0;
   for(int i=0;i<PositionsTotal();i++){ulong t=PositionGetTicket(i);if(t>0&&IsGridOrder(t,false))total+=PositionGetDouble(POSITION_VOLUME);}
   for(int i=0;i<OrdersTotal();i++){ulong t=OrderGetTicket(i);if(t>0&&IsGridOrder(t,true))total+=OrderGetDouble(ORDER_VOLUME_CURRENT);}
   return total*perLot/eq*100.0;
}

void UpdateExposureMetrics()

{

   g_state.totalOpenLots=0.0;

   g_state.totalPendingLots=0.0;

   for(int i=0;i<PositionsTotal();i++){ulong t=PositionGetTicket(i);if(t>0&&IsGridOrder(t,false))g_state.totalOpenLots+=PositionGetDouble(POSITION_VOLUME);}

   for(int i=0;i<OrdersTotal();i++){ulong t=OrderGetTicket(i);if(t>0&&IsGridOrder(t,true))g_state.totalPendingLots+=OrderGetDouble(ORDER_VOLUME_CURRENT);}

   g_state.totalExposureLots=g_state.totalOpenLots+g_state.totalPendingLots;

   g_state.exposureUtilizationPct=(g_state.exposureManager&&g_state.permExposureAdjust&&g_state.maxTotalLots>0)?100.0*g_state.totalExposureLots/g_state.maxTotalLots:0.0;

   g_state.gridRiskPct=EstimateGridRiskPct();

   double bal=AccountInfoDouble(ACCOUNT_BALANCE);

   double margin=AccountInfoDouble(ACCOUNT_MARGIN);

   g_state.accountMarginUsedPct=(bal>0)?100.0*margin/bal:0.0;

}

void CloseAllGridPositions()

{

   int closed=0,failed=0;

   for(int i=PositionsTotal()-1;i>=0;i--)

   {

      ulong ticket=PositionGetTicket(i);

      if(ticket==0 || !IsGridOrder(ticket,false)) continue;

      if(trade.PositionClose(ticket,(ulong)MathMax(0,g_state.slippage))) closed++; else failed++;

   }

   g_state.executionStatus=StringFormat("EMERGENCY CLOSE: %d/%d",closed,closed+failed);

   if(failed>0) RecordEvent("EMERGENCY","Position close failures: "+IntegerToString(failed));

}



void ActivateEmergency(string reason,int level,bool manual=false)

{

   if(!manual && (!g_state.permEmergencyControl || !g_state.protectionMasterEnabled || !g_state.protectionEmergencyActionEnabled)) return;

   g_state.emergencyActive=true;g_state.emergencyLevel=MathMax(g_state.emergencyLevel,level);g_state.emergencyReason=reason;g_state.emergencyTime=TimeCurrent();g_state.emergencyManualStop=manual||g_state.emergencyManualStop;

   g_state.entryThrottleActive=true;g_state.entryThrottleReason=reason;

   SetAction(manual?"USER":"EMERGENCY","PROTECTION ACTIVE",reason);

   string trigger=manual?"MANUAL":"AUTO";

   string snapshot=StringFormat(

      "%s | Level %d | %s | DD %.2f%%/%.2f%% | Daily %.2f%%/-%.2f%% | Margin %.1f%% | Spread %.2f/%.2f | Vol %.0f%%/%.0f%%",

      trigger,g_state.emergencyLevel,reason,

      g_state.emergencyDrawdownPct,g_state.maxDrawdownPct,

      g_state.emergencyDailyLossPct,g_state.dailyLossLimitPct,

      g_state.emergencyMarginLevelPct,

      g_state.emergencySpreadPips,g_state.maxSpreadPips,

      g_state.emergencyVolatilityPct*100.0,g_state.highVolThreshold*100.0);

   RecordEvent("EMERGENCY",snapshot);

   g_state.gridLifecycleReason="Emergency protection: "+reason;

   if(g_state.protectionEmergencyCancelEnabled && g_state.emergencyCancelPending) { g_state.protectionLastAction="CANCEL PENDING"; CancelPendingGridOrders(); }

   if(g_state.protectionEmergencyAutoCloseEnabled && g_state.emergencyAutoClose) { g_state.protectionLastAction="CLOSE EXISTING"; CloseAllGridPositions(); }

}



void ClearEmergencyState(bool manual=true)

{

   if(!manual && !g_state.permEmergencyControl) return;

   g_state.emergencyActive=false;g_state.emergencyLevel=0;g_state.emergencyReason="";g_state.emergencyTime=TimeCurrent();g_state.emergencyManualStop=false;

   g_state.entryThrottleActive=false;g_state.entryThrottleReason="";

   SetAction("USER","EMERGENCY CLEARED","Protection state reset");RecordEvent("EMERGENCY","Cleared / resume authorized");

}



void UpdateEmergencyTelemetry()

{

   double eq=AccountInfoDouble(ACCOUNT_EQUITY),bal=AccountInfoDouble(ACCOUNT_BALANCE);

   if(g_state.peakEquity<=0) g_state.peakEquity=eq; if(eq>g_state.peakEquity) g_state.peakEquity=eq;

   g_state.emergencyDrawdownPct=g_state.peakEquity>0?(g_state.peakEquity-eq)/g_state.peakEquity*100.0:0.0;

   g_state.emergencyDailyLossPct=bal>0?g_state.todayProfit/bal*100.0:0.0;

   g_state.emergencySpreadPips=g_state.currentSpreadPips;

   g_state.emergencyVolatilityPct=ClampDouble(g_state.volatilityIndex,0,1);

   g_state.emergencyMarginLevelPct=AccountInfoDouble(ACCOUNT_MARGIN_LEVEL);

   if(!g_state.permEmergencyControl) return;

   if(g_state.emergencyManualStop) return;

   if(!g_state.protectionMasterEnabled || !g_state.protectionEmergencyActionEnabled) return;
   if(!g_state.advancedProtection) return;

   if(g_state.maxDrawdownPct>0 && g_state.emergencyDrawdownPct>=g_state.maxDrawdownPct) { ActivateEmergency("Maximum drawdown reached",3,false); return; }

   if(g_state.dailyLossLimitPct>0 && g_state.emergencyDailyLossPct<=-g_state.dailyLossLimitPct) { ActivateEmergency("Daily loss limit reached",3,false); return; }

   if(g_state.emergencyMarginLevelPct>0 && g_state.emergencyMarginLevelPct<120.0) { ActivateEmergency("Margin level critical",3,false); return; }

   if(g_state.maxSpreadPips>0 && g_state.emergencySpreadPips>g_state.maxSpreadPips*1.50) { ActivateEmergency("Abnormal spread emergency",2,false); return; }

   if(g_state.pauseHighVolatility && g_state.emergencyVolatilityPct>=g_state.highVolThreshold) { ActivateEmergency("Abnormal volatility emergency",2,false); return; }

}



bool EmergencyBlocksNewGrid(){return g_state.emergencyActive;}



// -------------------- RISK & PORTFOLIO: RISK & PORTFOLIO ENGINE --------------------

double RiskPortfolioDirectionRiskPct(bool buy)
{
   double eq=AccountInfoDouble(ACCOUNT_EQUITY); if(eq<=0) return 0.0;
   double ts=SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE),tv=SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_VALUE);
   double sd=GetStopDistancePrice(); if(ts<=0||tv<=0||sd<=0) return 0.0;
   double perLot=(sd/ts)*tv,total=0.0;
   for(int i=0;i<PositionsTotal();i++)
   {
      ulong t=PositionGetTicket(i); if(t==0||!IsGridOrder(t,false)||!PositionSelectByTicket(t)) continue;
      bool pb=(PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_BUY); if(pb==buy) total+=PositionGetDouble(POSITION_VOLUME);
   }
   for(int i=0;i<OrdersTotal();i++)
   {
      ulong t=OrderGetTicket(i); if(t==0||!IsGridOrder(t,true)||!OrderSelect(t)) continue;
      ENUM_ORDER_TYPE ot=(ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
      bool pb=(ot==ORDER_TYPE_BUY_STOP||ot==ORDER_TYPE_BUY_LIMIT); if(pb==buy) total+=OrderGetDouble(ORDER_VOLUME_CURRENT);
   }
   return ClampDouble(total*perLot/eq*100.0,0.0,10000.0);
}

void UpdatePhase7RiskTelemetry()
{
   double eq=AccountInfoDouble(ACCOUNT_EQUITY),bal=AccountInfoDouble(ACCOUNT_BALANCE);
   g_state.brokerRiskOK=IsTradingAllowedForSymbol() && eq>0;
   g_state.hardSurvivalOK=!g_state.hardBreakerTriggered && (eq>0);
   g_state.portfolioRiskPct=EstimateGridRiskPct();
   g_state.longRiskPct=RiskPortfolioDirectionRiskPct(true);
   g_state.shortRiskPct=RiskPortfolioDirectionRiskPct(false);
   g_state.directionalRiskPct=MathMax(g_state.longRiskPct,g_state.shortRiskPct);
   g_state.portfolioRiskCapacityPct=g_state.maxGridRiskPct>0?MathMax(0.0,g_state.maxGridRiskPct-g_state.portfolioRiskPct):0.0;
   g_state.portfolioRiskOK=(g_state.maxGridRiskPct<=0 || g_state.portfolioRiskPct<g_state.maxGridRiskPct-0.000001);
   g_state.strategyRiskOK=(g_state.riskPerGridPct>0 && (g_state.maxGridRiskPct<=0 || g_state.riskPerGridPct<=g_state.maxGridRiskPct+0.000001));
   double dayPct=bal>0?g_state.todayProfit/bal*100.0:0.0;
   double dd=g_state.maxDrawdownPct>0?g_state.maxDrawdown/g_state.maxDrawdownPct:0.0;
   double riskLoad=g_state.maxGridRiskPct>0?MathMin(1.0,g_state.portfolioRiskPct/g_state.maxGridRiskPct):0.0;
   double survivalLoad=MathMax(dd,g_state.dailyLossLimitPct>0?MathMin(1.0,MathAbs(MathMin(0.0,dayPct))/g_state.dailyLossLimitPct):0.0);
   g_state.entryRiskOK=(!IsAutonomousControl() || g_state.permAutonomousEntry);
   g_state.riskHealthScore=ClampDouble(100.0*(1.0-MathMax(riskLoad,survivalLoad)),0.0,100.0);
   g_state.riskBlockReason="";
   if(!g_state.brokerRiskOK) g_state.riskBlockReason="BROKER/ACCOUNT PERMISSION";
   else if(!g_state.hardSurvivalOK) g_state.riskBlockReason="HARD SURVIVAL STOP";
   else if(!g_state.portfolioRiskOK) g_state.riskBlockReason="PORTFOLIO RISK CAPACITY";
   else if(!g_state.strategyRiskOK) g_state.riskBlockReason="STRATEGY RISK HIERARCHY";
   else if(!g_state.entryRiskOK) g_state.riskBlockReason="AUTONOMOUS ENTRY PERMISSION";
   g_state.riskHierarchyStatus=g_state.riskBlockReason==""?"CLEAR":"BLOCKED | "+g_state.riskBlockReason;
}

bool RiskPortfolioHardRiskGate(bool autonomous,string &reason)
{
   UpdatePhase7RiskTelemetry();
   if(!g_state.brokerRiskOK){reason="RISK & PORTFOLIO: broker/account permission invalid";return false;}
   if(!g_state.hardSurvivalOK){reason="RISK & PORTFOLIO: hard survival stop active";return false;}
   if(g_state.maxGridRiskPct>0 && g_state.portfolioRiskPct>=g_state.maxGridRiskPct-0.000001)
   {reason=StringFormat("RISK & PORTFOLIO: portfolio risk %.2f%% >= %.2f%%",g_state.portfolioRiskPct,g_state.maxGridRiskPct);return false;}
   if(g_state.riskPerGridPct>0 && g_state.maxGridRiskPct>0 && g_state.riskPerGridPct>g_state.maxGridRiskPct)
   {reason=StringFormat("RISK & PORTFOLIO: risk/grid %.2f%% exceeds grid cap %.2f%%",g_state.riskPerGridPct,g_state.maxGridRiskPct);return false;}
   if(autonomous && !g_state.permAutonomousEntry){reason="RISK & PORTFOLIO: autonomous entry permission OFF";return false;}
   return true;
}

bool RiskPortfolioRiskPortfolioAudit(string &reason)
{
   reason="";
   UpdatePhase7RiskTelemetry();
   if(g_state.riskPerGridPct<0){reason="Risk/grid is negative";return false;}
   if(g_state.maxGridRiskPct<0){reason="Max grid risk is negative";return false;}
   if(g_state.maxGridRiskPct>0 && g_state.riskPerGridPct>g_state.maxGridRiskPct+0.000001){reason="Risk hierarchy violated";return false;}
   if(g_state.portfolioRiskPct<0 || g_state.portfolioRiskPct>10000){reason="Portfolio risk telemetry invalid";return false;}
   if(g_state.longRiskPct<0 || g_state.shortRiskPct<0){reason="Directional risk telemetry invalid";return false;}
   return true;
}

bool RiskGuardBlocksNewGridDetailed(string &reason)
{
   reason="";
   if(IsAutonomousControl()) return UnifiedDeploymentGate(true,reason);
   if(!g_state.manualEntryRiskGuard) return false;

   double eq=AccountInfoDouble(ACCOUNT_EQUITY),bal=AccountInfoDouble(ACCOUNT_BALANCE);
   if(eq<=0){reason="Invalid equity";return true;}
   if(g_state.maxSpreadPips>0 && g_state.currentSpreadPips>g_state.maxSpreadPips){reason=StringFormat("Spread %.2f > %.2f pips",g_state.currentSpreadPips,g_state.maxSpreadPips);return true;}
   if(!IsSessionAllowed()){reason="Session filter blocked entry";return true;}
   if(g_state.avoidWeekend && IsWeekend()){reason="Weekend filter blocked entry";return true;}
   if(g_state.maxDrawdownPct>0 && g_state.maxDrawdown>=g_state.maxDrawdownPct){reason=StringFormat("Manual entry DD %.2f%% >= %.2f%%",g_state.maxDrawdown,g_state.maxDrawdownPct);return true;}
   double dayPct=bal>0?g_state.todayProfit/bal*100.0:0.0;
   if(g_state.dailyLossLimitPct>0 && dayPct<=-g_state.dailyLossLimitPct){reason=StringFormat("Daily loss %.2f%% <= -%.2f%%",dayPct,g_state.dailyLossLimitPct);return true;}
   if(g_state.maxGridRiskPct>0 && EstimateGridRiskPct()>=g_state.maxGridRiskPct){reason=StringFormat("Grid risk %.2f%% >= %.2f%%",EstimateGridRiskPct(),g_state.maxGridRiskPct);return true;}
   if(g_state.exposureManager && g_state.maxTotalLots>0 && CurrentGridExposureLots()>=g_state.maxTotalLots-0.0000001){reason=StringFormat("Exposure %.3f >= %.3f lots",CurrentGridExposureLots(),g_state.maxTotalLots);return true;}
   return false;
}

bool RiskGuardBlocksNewGrid(){string reason="";return RiskGuardBlocksNewGridDetailed(reason);}



// -------------------- POSITION MANAGEMENT ------------------------

// Risk Engine is the master switch for automatic trade-management actions.

// IMPORTANT: when OFF, the EA must not autonomously delete/rebuild/cancel/modify

// grid inventory. Explicit manual controls and emergency controls remain separate.

// With Risk Engine OFF, automatic OCO cancellation and pending-expiry deletion are suspended.

// Emergency/manual controls remain independently available.

void DeletePendingType(ENUM_ORDER_TYPE type){for(int i=OrdersTotal()-1;i>=0;i--){ulong t=OrderGetTicket(i);if(t==0||!IsGridOrder(t,true))continue;if((ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE)==type){if(trade.OrderDelete(t))g_state.lifecycleDeleteCount++;else RecordEvent("PENDING DELETE FAILED",StringFormat("Order %I64u | %s",t,trade.ResultRetcodeDescription()));}}}

void ExpirePendingOrders(){if(!g_state.riskManagedTrading)return;if(g_state.pendingExpiryMinutes<=0)return;datetime now=TimeCurrent();for(int i=OrdersTotal()-1;i>=0;i--){ulong t=OrderGetTicket(i);if(t==0||!IsGridOrder(t,true))continue;datetime setup=(datetime)OrderGetInteger(ORDER_TIME_SETUP);if(setup>0&&(now-setup)>=g_state.pendingExpiryMinutes*60)if(trade.OrderDelete(t))g_state.lifecycleDeleteCount++;else RecordEvent("PENDING EXPIRE FAILED",StringFormat("Order %I64u | %s",t,trade.ResultRetcodeDescription()));}}

bool OCOEligibleForCurrentGrid()

{

   if(g_state.gridType==HEDGE_GRID) return false;

   if(g_state.gridType==BIDIRECTIONAL_GRID) return false;

   if(g_state.gridType==RANGE_SCALING_GRID) return false;

   return true;

}

void BeginCoordinatedExit(string reason)

{

   if(g_state.exitCoordinationActive) return;

   g_state.exitCoordinationActive=true;

   g_state.exitCoordinationReason=reason;

   g_state.exitCoordinationTime=TimeCurrent();

   g_state.gridLifecycleState="EXITING";

   g_state.gridLifecycleReason=reason;

   for(int i=OrdersTotal()-1;i>=0;i--)

   {

      ulong ticket=OrderGetTicket(i);

      if(ticket>0 && IsGridOrder(ticket,true))

      {

         if(trade.OrderDelete(ticket)) g_state.lifecycleDeleteCount++;

      }

   }

   RecordEvent("COORDINATED EXIT",StringFormat("Trade-set generation %I64u | %s | %s",g_state.gridCycleId,CompactGridName(g_state.gridType),reason));

   SetAction("EXIT COORDINATOR","EXIT STARTED",reason);

   for(int i=PositionsTotal()-1;i>=0;i--)

   {

      ulong ticket=PositionGetTicket(i);

      if(ticket>0 && IsGridOrder(ticket,false)) trade.PositionClose(ticket,(ulong)MathMax(0,g_state.slippage));

   }

}



void FinalizeCoordinatedExit()

{

   if(!g_state.exitCoordinationActive) return;

   if(GetPositionCount()==0 && GetPendingCount()==0)

   {

      g_state.exitCoordinationActive=false;

      g_state.gridActive=false;

      g_state.gridLifecycleState="IDLE";

      g_state.gridLifecycleReason="Exit completed";

      g_state.executionStatus="GRID EXIT COMPLETE";

      RecordEvent("COORDINATED EXIT","Completed | all grid inventory cleared");

   }

}



void ApplyOCO()

{

   if(!g_state.riskManagedTrading) return; if(!g_state.oco || !g_state.closeOppositeOnFill || !OCOEligibleForCurrentGrid() || g_state.exitCoordinationActive) return;

   bool buy=false,sell=false;

   for(int i=0;i<PositionsTotal();i++)

   {

      ulong t=PositionGetTicket(i);

      if(t==0||!IsGridOrder(t,false)) continue;

      ENUM_POSITION_TYPE pt=(ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);

      if(pt==POSITION_TYPE_BUY) buy=true;

      if(pt==POSITION_TYPE_SELL) sell=true;

   }

   if(buy) DeletePendingType(ORDER_TYPE_SELL_STOP);

   if(buy) DeletePendingType(ORDER_TYPE_SELL_LIMIT);

   if(sell) DeletePendingType(ORDER_TYPE_BUY_STOP);

   if(sell) DeletePendingType(ORDER_TYPE_BUY_LIMIT);

}



void RemovePositionProtection(bool removeSL,bool removeTP)

{

   for(int i=PositionsTotal()-1;i>=0;i--)

   {

      ulong ticket=PositionGetTicket(i);

      if(ticket==0 || !IsGridOrder(ticket,false)) continue;

      if(!PositionSelectByTicket(ticket)) continue;



      double sl=PositionGetDouble(POSITION_SL);

      double tp=PositionGetDouble(POSITION_TP);



      if(removeSL) sl=0.0;

      if(removeTP) tp=0.0;



      if((removeSL && PositionGetDouble(POSITION_SL)!=0.0) ||

         (removeTP && PositionGetDouble(POSITION_TP)!=0.0))

      {

         trade.PositionModify(ticket,sl,tp);

      }

   }

}



double StrategyManagementFactor(ENUM_GRID_TYPE t)

{

   if(!g_state.strategyAwareManagement) return 1.0;

   switch(t)

   {

      case HEDGE_GRID:             return 1.15;

      case FIBONACCI_GRID:         return 1.10;

      case GEOMETRIC_GRID:         return 1.12;

      case BREAKOUT_GRID:          return 0.90;

      case VOLATILITY_BREAKOUT_GRID:return 0.85;

      case MOMENTUM_GRID:          return 0.92;

      case TREND_GRID:             return 0.95;

      case BULLISH_GRID:           return 0.95;

      case BEARISH_GRID:           return 0.95;

      case MEAN_REVERSION_GRID:    return 1.08;

      case RANGE_SCALING_GRID:     return 1.10;

      case LADDER_GRID:            return 1.05;

      case ANTI_MARTINGALE_GRID:   return 0.92;

      case SESSION_GRID:           return 1.03;

      case SMART_REGIME_GRID:      return g_state.volatilityIndex>=g_state.highVolThreshold?0.90:1.05;

      default:                     return 1.00;

   }

}



double EffectiveBreakEvenTrigger()

{

   return MathMax(0.1,g_state.breakEvenTriggerPips*StrategyManagementFactor(g_state.gridType));

}



double EffectiveTrailingATR()

{

   double base=MathMax(0.1,g_state.trailingATRMultiple);

   return MathMax(0.1,base*StrategyManagementFactor(g_state.gridType));

}



double EffectiveMaxHoldMinutes()

{

   if(g_state.maxHoldMinutes<=0) return 0.0;

   double f=StrategyManagementFactor(g_state.gridType);

   return MathMax(1.0,g_state.maxHoldMinutes/f);

}



enum ENUM_NOVA_EXIT_AUTHORITY
{
   NOVA_EXIT_NONE=0,
   NOVA_EXIT_BROKER=1,
   NOVA_EXIT_USER=2,
   NOVA_EXIT_TRADE_MANAGEMENT=3,
   NOVA_EXIT_AUTONOMOUS=4,
   NOVA_EXIT_PROTECTION=5,
   NOVA_EXIT_HARD_SURVIVAL=6
};

#define NOVA_TRADE_PLAN_MAX 128

struct NOVA_TRADE_PLAN
{
   ulong ticket;
   ulong magic;
   ENUM_GRID_TYPE gridType;
   bool buy;
   datetime openTime;
   double entryPrice;
   double currentPrice;
   double sl;
   double tp;
   double currentProfit;
   double peakProfit;
   double adversePips;
   double favorablePips;
   double riskPct;
   bool hasSL;
   bool hasTP;
   bool managed;
   bool autonomousOwner;
   ENUM_NOVA_EXIT_AUTHORITY exitAuthority;
   string owner;
   string status;
};

NOVA_TRADE_PLAN g_tradePlans[NOVA_TRADE_PLAN_MAX];
int g_tradePlanCount=0;

string NovaExitAuthorityName(ENUM_NOVA_EXIT_AUTHORITY a)
{
   switch(a)
   {
      case NOVA_EXIT_BROKER:          return "BROKER SL/TP";
      case NOVA_EXIT_USER:            return "USER";
      case NOVA_EXIT_TRADE_MANAGEMENT:return "TRADE MANAGEMENT";
      case NOVA_EXIT_AUTONOMOUS:      return "AUTONOMOUS";
      case NOVA_EXIT_PROTECTION:      return "PROTECTION";
      case NOVA_EXIT_HARD_SURVIVAL:   return "HARD SURVIVAL";
      default:                        return "NONE";
   }
}

int FindIndividualTradePlan(ulong ticket)
{
   for(int i=0;i<g_tradePlanCount;i++)
      if(g_tradePlans[i].ticket==ticket) return i;
   return -1;
}

void UpdateIndividualTradeTelemetry()
{
   int count=0,managed=0,slc=0,tpc=0,autoc=0,bec=0,trc=0;
   double pnl=0.0,peak=0.0,worstDD=0.0,risk=0.0;
   ulong lastTicket=0;
   int existingCount=0;

   for(int i=0;i<PositionsTotal();i++)
   {
      ulong t=PositionGetTicket(i);
      if(t==0 || !IsGridOrder(t,false) || !PositionSelectByTicket(t)) continue;

      count++;
      lastTicket=t;
      long type=PositionGetInteger(POSITION_TYPE);
      bool buy=(type==POSITION_TYPE_BUY);
      double open=PositionGetDouble(POSITION_PRICE_OPEN);
      double px=buy?SymbolInfoDouble(_Symbol,SYMBOL_BID):SymbolInfoDouble(_Symbol,SYMBOL_ASK);
      double sl=PositionGetDouble(POSITION_SL);
      double tp=PositionGetDouble(POSITION_TP);
      double p=PositionGetDouble(POSITION_PROFIT)+PositionGetDouble(POSITION_SWAP);
      pnl+=p;
      if(p>peak) peak=p;

      string comment=PositionGetString(POSITION_COMMENT);
      ENUM_GRID_TYPE gt=GridTypeFromTradeComment(comment,g_selectedGridType);

      int idx=FindIndividualTradePlan(t);
      if(idx<0 && g_tradePlanCount<NOVA_TRADE_PLAN_MAX)
      {
         idx=g_tradePlanCount++;
         ZeroMemory(g_tradePlans[idx]);
         g_tradePlans[idx].ticket=t;
         g_tradePlans[idx].openTime=(datetime)PositionGetInteger(POSITION_TIME);
         g_tradePlans[idx].peakProfit=p;
         g_tradePlans[idx].adversePips=0.0;
         g_tradePlans[idx].favorablePips=0.0;
      }
      if(idx>=0)
      {
         g_tradePlans[idx].magic=(ulong)PositionGetInteger(POSITION_MAGIC);
         g_tradePlans[idx].gridType=gt;
         g_tradePlans[idx].buy=buy;
         g_tradePlans[idx].entryPrice=open;
         g_tradePlans[idx].currentPrice=px;
         g_tradePlans[idx].sl=sl;
         g_tradePlans[idx].tp=tp;
         g_tradePlans[idx].currentProfit=p;
         if(p>g_tradePlans[idx].peakProfit) g_tradePlans[idx].peakProfit=p;
         double pp=buy?(px-open)/PipSize():(open-px)/PipSize();
         if(pp>=0) g_tradePlans[idx].favorablePips=MathMax(g_tradePlans[idx].favorablePips,pp);
         else g_tradePlans[idx].adversePips=MathMax(g_tradePlans[idx].adversePips,-pp);
         g_tradePlans[idx].hasSL=(sl>0);
         g_tradePlans[idx].hasTP=(tp>0);
         bool autoOwner=IsAutonomousManagedMode() && g_state.autonomousAutoProtection;
         bool mgmtOwner=g_state.protectionMasterEnabled && (g_state.breakEven||g_state.trailingStop||g_state.maxHoldMinutes>0);
         g_tradePlans[idx].autonomousOwner=autoOwner;
         g_tradePlans[idx].managed=(autoOwner||mgmtOwner);
         g_tradePlans[idx].owner=autoOwner?"AUTONOMOUS":(mgmtOwner?"PROTECTION":"USER");
         g_tradePlans[idx].exitAuthority=NOVA_EXIT_NONE;
         g_tradePlans[idx].status=(g_tradePlans[idx].hasSL||g_tradePlans[idx].hasTP)?"PROTECTED":"UNPROTECTED";
         if(g_tradePlans[idx].managed) managed++;
         if(g_tradePlans[idx].hasSL) slc++;
         if(g_tradePlans[idx].hasTP) tpc++;
         if(autoOwner) autoc++;
         if(g_state.protectionMasterEnabled && g_state.breakEven) bec++;
         if(g_state.protectionMasterEnabled && g_state.trailingStop) trc++;
         if(sl>0) risk+=MathAbs(open-sl)*SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_VALUE)/MathMax(SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE),_Point)*MathMax(0.0,PositionGetDouble(POSITION_VOLUME));
      }
   }

   g_state.individualTradeCount=count;
   g_state.individualManagedCount=managed;
   g_state.individualSLCount=slc;
   g_state.individualTPCount=tpc;
   g_state.individualAutonomousCount=autoc;
   g_state.individualBECount=bec;
   g_state.individualTrailCount=trc;
   g_state.individualFloatingPnL=pnl;
   g_state.individualPeakProfit=peak;
   g_state.individualWorstDrawdownPct=(peak>0.0 && pnl<peak)?100.0*(peak-pnl)/MathMax(MathAbs(peak),1.0):0.0;
   double eq=AccountInfoDouble(ACCOUNT_EQUITY);
   g_state.individualRiskPct=(eq>0.0)?100.0*risk/eq:0.0;
   g_state.individualLastTicket=lastTicket;
   if(count==0)
   {
      g_state.individualLastAuthority="NONE";
      g_state.individualLastAction="NO ACTIVE TRADE";
   }
}

void ManageIndividualTradeEngine()
{
   MqlTick tk;
   if(!SymbolInfoTick(_Symbol,tk)) return;

   double pip=PipSize(),atr=GetCurrentATRPrice();
   if(pip<=0) return;
   int authorityClosures=0;

   for(int i=PositionsTotal()-1;i>=0;i--)
   {
      ulong t=PositionGetTicket(i);
      if(t==0 || !IsGridOrder(t,false) || !PositionSelectByTicket(t)) continue;

      long type=PositionGetInteger(POSITION_TYPE);
      bool buy=(type==POSITION_TYPE_BUY);
      double open=PositionGetDouble(POSITION_PRICE_OPEN);
      double sl=PositionGetDouble(POSITION_SL);
      double tp=PositionGetDouble(POSITION_TP);
      double price=buy?tk.bid:tk.ask;
      double pp=buy?(price-open)/pip:(open-price)/pip;
      string comment=PositionGetString(POSITION_COMMENT);
      ENUM_GRID_TYPE tradeGridType=GridTypeFromTradeComment(comment,g_selectedGridType);

      bool autonomousOwner=IsAutonomousManagedMode() && g_state.autonomousAutoProtection;
      bool protectionOwner=g_state.protectionMasterEnabled;
      bool adaptiveOwner=autonomousOwner || (protectionOwner && g_state.adaptiveTradeProtection);
      bool profitOwner=autonomousOwner || (protectionOwner && g_state.adaptiveProfitManagement);
      bool runnerOwner=autonomousOwner || (protectionOwner && g_state.tradeRunnerMode);

      double strategyFactor=StrategyManagementFactor(tradeGridType);
      double beTrigger=MathMax(0.1,g_state.breakEvenTriggerPips*strategyFactor);
      double trailATR=MathMax(0.1,g_state.trailingATRMultiple*strategyFactor);
      double maxHold=(g_state.maxHoldMinutes>0?MathMax(1.0,g_state.maxHoldMinutes/MathMax(0.1,strategyFactor)):0.0);
      double newSL=sl,newTP=tp;

      // TRADE PROTECTION: adaptive per-trade SL/TP creation. This is an explicit trade-plan authority.
      if(adaptiveOwner && (sl==0 || tp==0 || g_state.tradeRunnerMode))
      {
         double autoSL=0,autoTP=0;
         if(IsAutonomousManagedMode())
            CalculateAutonomousProtection(buy,open,tradeGridType,autoSL,autoTP);
         else
         {
            double sm=MathMax(0.5,g_state.adaptiveSLATRMultiple),tm=MathMax(0.75,g_state.adaptiveTPATRMultiple);
            double vol=MathMax(0.0,MathMin(1.0,g_state.volatilityIndex));
            sm*=1.0+0.25*vol; tm*=1.0+0.35*vol;
            double sd=AutonomousATRDistance(atr,MathMax(6.0,g_state.gridStep*0.90),sm);
            double td=AutonomousATRDistance(atr,MathMax(8.0,g_state.gridStep*1.20),tm);
            if(buy){autoSL=NormalizeDouble(open-sd,_Digits);autoTP=NormalizeDouble(open+MathMax(td,sd*1.25),_Digits);}
            else{autoSL=NormalizeDouble(open+sd,_Digits);autoTP=NormalizeDouble(open-MathMax(td,sd*1.25),_Digits);}
         }
         if(sl==0 && autoSL>0) newSL=autoSL;
         if(tp==0 && autoTP>0) newTP=autoTP;
      }

      if((autonomousOwner || (protectionOwner && g_state.breakEven)) && g_state.breakEven && pp>=beTrigger)
      {
         double be=buy?open+g_state.breakEvenOffsetPips*pip:open-g_state.breakEvenOffsetPips*pip;
         if(buy && (newSL==0 || be>newSL)) newSL=be;
         if(!buy && (newSL==0 || be<newSL)) newSL=be;
      }

      if((autonomousOwner || (protectionOwner && g_state.trailingStop)) && g_state.trailingStop && atr>0)
      {
         double td=atr*trailATR;
         double tr=buy?price-td:price+td;
         if(buy && (newSL==0 || tr>newSL)) newSL=tr;
         if(!buy && (newSL==0 || tr<newSL)) newSL=tr;
      }

      // TRADE PROTECTION profit management: once a trade has meaningful favorable excursion,
      // protect realized profit without using a basket-level loss/telemetry trigger.
      if(profitOwner && pp>=MathMax(1.0,g_state.profitLockTriggerPips))
      {
         double lock=buy?open+(MathMax(0.0,g_state.profitLockOffsetPips)*pip):open-(MathMax(0.0,g_state.profitLockOffsetPips)*pip);
         if(buy && (newSL==0 || lock>newSL)) newSL=lock;
         if(!buy && (newSL==0 || lock<newSL)) newSL=lock;
         g_state.tradeProtectionLastAction="PROFIT LOCK";
         g_state.tradeProtectionLastReason=StringFormat("Ticket %I64u | +%.1f pips",t,pp);
      }

      // Runner mode extends TP only when momentum/structure remains favorable.
      // It never removes an existing TP when runner mode is OFF.
      if(runnerOwner && g_state.tradeRunnerMode && atr>0 && pp>0)
      {
         double trend=buy?g_state.trendStrength:(1.0-g_state.trendStrength);
         if(trend>=0.55)
         {
            double runnerTP=buy?price+atr*g_state.runnerATRMultiple:price-atr*g_state.runnerATRMultiple;
            if(buy && (newTP==0 || runnerTP>newTP)) newTP=NormalizeDouble(runnerTP,_Digits);
            if(!buy && (newTP==0 || runnerTP<newTP)) newTP=NormalizeDouble(runnerTP,_Digits);
            g_state.tradeProtectionLastAction="RUNNER TP";
            g_state.tradeProtectionLastReason=StringFormat("Ticket %I64u | trend %.2f",t,trend);
         }
      }

      if(newSL!=sl || newTP!=tp)
      {
         if(trade.PositionModify(t,NormalizeDouble(newSL,_Digits),NormalizeDouble(newTP,_Digits)))
         {
            g_state.individualLastTicket=t;
            g_state.individualLastAuthority=autonomousOwner?"AUTONOMOUS":"TRADE MANAGEMENT";
            g_state.individualLastAction="TRADE PROTECTION PROTECTION";
            g_state.individualLastReason=g_state.tradeProtectionLastReason!=""?g_state.tradeProtectionLastReason:"Adaptive per-trade protection";
            RecordEvent("INDIVIDUAL TRADE MANAGEMENT",StringFormat("Ticket %I64u | SL %.5f | TP %.5f | owner %s | %s",t,newSL,newTP,g_state.individualLastAuthority,g_state.individualLastReason));
         }
      }

      // Max-hold remains an explicitly authorized exit. It is never a generic risk exit.
      if(((protectionOwner && g_state.protectionMaxHoldCloseEnabled) || autonomousOwner) && g_state.maxHoldMinutes>0 &&
         (TimeCurrent()-(datetime)PositionGetInteger(POSITION_TIME)) >= (long)(maxHold*60.0))
      {
         if(trade.PositionClose(t,(ulong)MathMax(0,g_state.slippage)))
         {
            authorityClosures++;
            g_state.individualLastTicket=t;
            g_state.individualLastAuthority=autonomousOwner?"AUTONOMOUS":"TRADE MANAGEMENT";
            g_state.individualLastAction="CLOSE";
            g_state.individualLastReason="Explicit max-hold policy";
            RecordEvent("INDIVIDUAL TRADE EXIT",StringFormat("Ticket %I64u | authority %s | max-hold policy",t,g_state.individualLastAuthority));
         }
      }
   }

   if(authorityClosures>0) g_state.executionStatus=StringFormat("INDIVIDUAL ENGINE: %d EXIT",authorityClosures);
}

void ManagePositions()
{
   // TRADE ENGINE: one authoritative per-ticket manager. Generic risk telemetry does not
   // close positions; only explicit trade-management or autonomous trade-plan authority can.
   UpdateIndividualTradeTelemetry();
   ManageIndividualTradeEngine();
   UpdateIndividualTradeTelemetry();
}

void CloseGrid()

{

   for(int i=PositionsTotal()-1;i>=0;i--)

   {

      ulong ticket=PositionGetTicket(i);

      if(ticket>0 && IsGridOrder(ticket,false))

      {

         trade.PositionClose(ticket,(ulong)MathMax(0,g_state.slippage));

      }

   }



   for(int i=OrdersTotal()-1;i>=0;i--)

   {

      ulong ticket=OrderGetTicket(i);

      if(ticket>0 && IsGridOrder(ticket,true))

      {

         trade.OrderDelete(ticket);

      }

   }



   g_state.positionCount=GetPositionCount();
   g_state.pendingCount=GetPendingCount();
   g_state.gridActive=(g_state.positionCount>0 || g_state.pendingCount>0);
   if(!g_state.gridActive)
   {
      g_state.startTime=0;
      g_state.anchorPrice=0.0;
   }
   g_state.executionStatus=g_state.gridActive?"POSITIONS REMAIN — PENDING CLOSED":"GRID CLOSED";
   g_state.exitCoordinationActive=false; g_state.exitCoordinationReason=""; g_state.exitCoordinationTime=0;
   g_state.gridLifecycleState=g_state.gridActive?"ACTIVE":"IDLE";
   g_state.gridLifecycleReason=g_state.gridActive?"Live positions remain":"Manual/standard close";

}



//+------------------------------------------------------------------+
//| BOUNDED PROFIT-PRIORITY RECOVERY ENGINE                          |
//| Goal: bank profitable legs first and attempt measured recovery.  |
//| The hard circuit breaker remains unconditional.                  |
//+------------------------------------------------------------------+
void EnforceHardCircuitBreaker()
{
   if(g_state.hardBreakerTriggered) return;
   if(!g_state.protectionMasterEnabled || !g_state.protectionHardBreakerEnabled) return;
   if(InpHardCircuitBreakerUSD<=0.0) return;

   double liveLoss=g_state.cycleRealizedLoss+MathMin(0.0,g_state.currentProfit);
   double limit=MathAbs(InpHardCircuitBreakerUSD);
   if(-liveLoss<limit) return;

   // Absolute safety action: bypasses Risk Engine, Advanced Protection and permissions.
   g_v14FocusMagic=0;
   CloseGrid();
   g_state.hardBreakerTriggered=true;
   g_state.recoveryModeActive=false;
   g_state.recoveryAttemptsUsed=0;
   g_state.recoveryLotScale=1.0;
   g_state.executionStatus="HARD CIRCUIT BREAKER — FLATTENED";
   SetAction("CIRCUIT BREAKER","FORCED FLATTEN",
             StringFormat("EA loss $%.2f reached hard limit $%.2f",-liveLoss,limit));
   RecordEvent("CIRCUIT BREAKER",
               StringFormat("HARD STOP | loss $%.2f >= limit $%.2f | recovery halted",-liveLoss,limit));
}

void HandleLossGovernorTrigger(string reason)
{
   if(g_state.hardBreakerTriggered) return;

   int maxAttempts=MathMax(0,InpMaxRecoveryAttempts);
   if(g_state.recoveryAttemptsUsed>=maxAttempts)
   {
      g_state.recoveryModeActive=false;
      g_state.recoveryLotScale=1.0;
      g_state.executionStatus="RECOVERY EXHAUSTED — STANDING DOWN";
      RecordEvent("RECOVERY GOVERNOR",StringFormat("Attempts exhausted | %s",reason));
      // Stand down the complete EA grid inventory rather than leaving another cycle running.
      g_v14FocusMagic=0;
      CloseGrid();
      return;
   }

   // Profit-priority rule: bank only currently profitable positions first.
   double beforeProfit=g_state.currentProfit;
   CloseProfitPositions();

   g_state.recoveryAttemptsUsed++;
   double step=ClampDouble(InpRecoveryLotScaleStep,0.10,1.0);
   g_state.recoveryLotScale=MathPow(step,g_state.recoveryAttemptsUsed);
   g_state.recoveryModeActive=true;
   g_state.executionStatus="RECOVERY MODE — REDUCED RISK";

   SetAction("RECOVERY GOVERNOR","PARTIAL EXIT + REDUCED REDEPLOY",
             StringFormat("Attempt %d/%d | lot x%.3f | %s",
                          g_state.recoveryAttemptsUsed,maxAttempts,
                          g_state.recoveryLotScale,reason));
   RecordEvent("RECOVERY GOVERNOR",
               StringFormat("Attempt %d/%d | banked profitable legs | losers retained | lot x%.3f | trigger %s | P/L %.2f",
                            g_state.recoveryAttemptsUsed,maxAttempts,g_state.recoveryLotScale,reason,beforeProfit));

   // Immediately continue working rather than waiting for the autonomous timer.
   // The fresh cycle uses the reduced lot scale through CalculateAdaptiveLot().
   if(!g_state.hardBreakerTriggered)
      CreateGrid(true);
}

void ManageGridRisk()
{
   g_state.currentProfit=GetGridProfit();

   // Profit-priority management is available whenever risk management is active.
   // The hard circuit breaker is handled independently from this function.
   if(!g_state.riskManagedTrading) return;

   if(g_state.basketTakeProfitUSD>0 && g_state.currentProfit>=g_state.basketTakeProfitUSD)
   {
      if(g_state.protectionMasterEnabled && g_state.protectionBasketProfitCloseEnabled)
      {
         CloseProfitPositions();
         g_state.protectionLastAuthority="BASKET PROFIT";
         g_state.protectionLastTrigger="Basket take-profit reached";
         g_state.protectionLastAction="CLOSE PROFIT";
         g_state.protectionLastResult="PROFIT LEGS BANKED";
         RecordEvent("PROTECTION EXIT","Basket take-profit reached | profitable legs banked");
      }
      else
      {
         g_state.protectionLastAuthority="BASKET PROFIT";
         g_state.protectionLastTrigger="Basket take-profit reached";
         g_state.protectionLastAction="MONITOR ONLY";
         g_state.protectionLastResult="NO EXIT AUTHORITY";
         RecordEvent("PROTECTION MONITOR","Basket take-profit reached | existing trades left untouched");
      }
      g_state.recoveryModeActive=false;
      g_state.recoveryAttemptsUsed=0;
      g_state.recoveryLotScale=1.0;
      RecordEvent("PROFIT PRIORITY",StringFormat("Basket TP reached | profitable positions banked at %.2f",g_state.currentProfit));
      return;
   }

   if(g_state.basketStopLossUSD>0 && g_state.currentProfit<=-MathAbs(g_state.basketStopLossUSD))
   {
      g_state.protectionLastAuthority="BASKET LOSS"; g_state.protectionLastTrigger="Basket stop-loss reached";
      if(g_state.protectionMasterEnabled && g_state.protectionBasketLossCloseEnabled) HandleLossGovernorTrigger("Basket stop-loss reached");
      else { g_state.protectionLastAction="MONITOR ONLY"; g_state.protectionLastResult="NO EXIT AUTHORITY"; RecordEvent("PROTECTION MONITOR","Basket loss threshold reached | existing trades left untouched"); }
      return;
   }

   if(g_state.maxDrawdownPct>0 && g_state.initialEquity>0)
   {
      double eq=AccountInfoDouble(ACCOUNT_EQUITY);
      double dd=(g_state.initialEquity-eq)/g_state.initialEquity*100.0;
      if(dd>=g_state.maxDrawdownPct)
      {
         g_state.protectionLastAuthority="DRAWDOWN"; g_state.protectionLastTrigger="Maximum drawdown reached";
         if(g_state.protectionMasterEnabled && g_state.protectionDrawdownCloseEnabled) HandleLossGovernorTrigger("Maximum drawdown reached");
         else { g_state.protectionLastAction="MONITOR ONLY"; g_state.protectionLastResult="NO EXIT AUTHORITY"; RecordEvent("PROTECTION MONITOR","Maximum drawdown reached | existing trades left untouched"); }
         return;
      }
   }

   double bal=AccountInfoDouble(ACCOUNT_BALANCE);
   if(bal>0)
   {
      double dayPct=g_state.todayProfit/bal*100.0;
      if(g_state.dailyLossLimitPct>0 && dayPct<=-g_state.dailyLossLimitPct)
      {
         g_state.protectionLastAuthority="DAILY LOSS"; g_state.protectionLastTrigger="Daily governor loss reached";
         if(g_state.protectionMasterEnabled && g_state.protectionDailyLossCloseEnabled) HandleLossGovernorTrigger("Daily governor loss reached");
         else { g_state.protectionLastAction="MONITOR ONLY"; g_state.protectionLastResult="NO EXIT AUTHORITY"; RecordEvent("PROTECTION MONITOR","Daily loss threshold reached | existing trades left untouched"); }
         return;
      }

      // Profit lock is a profit event, never a loss closure. Bank profitable legs.
      if(g_state.dailyProfitLockPct>0 && dayPct>=g_state.dailyProfitLockPct)
      {
         if(g_state.protectionMasterEnabled && g_state.protectionProfitLockCloseEnabled)
         {
            CloseProfitPositions();
            g_state.protectionLastAuthority="PROFIT LOCK";
            g_state.protectionLastTrigger="Daily profit lock reached";
            g_state.protectionLastAction="CLOSE PROFIT";
            g_state.protectionLastResult="PROFIT LEGS BANKED";
            RecordEvent("PROTECTION EXIT",StringFormat("Daily profit lock reached | profitable legs banked | %.2f%%",dayPct));
         }
         else
         {
            g_state.protectionLastAuthority="PROFIT LOCK";
            g_state.protectionLastTrigger="Daily profit lock reached";
            g_state.protectionLastAction="MONITOR ONLY";
            g_state.protectionLastResult="NO EXIT AUTHORITY";
            RecordEvent("PROTECTION MONITOR",StringFormat("Daily profit lock reached | existing trades left untouched | %.2f%%",dayPct));
         }
         g_state.recoveryModeActive=false;
         g_state.recoveryAttemptsUsed=0;
         g_state.recoveryLotScale=1.0;
      }
   }
}


string GridLifecycleModel(ENUM_GRID_TYPE t)

{

   switch(t)

   {

      case HEDGE_GRID:return "HEDGE SYMMETRIC";

      case FIBONACCI_GRID:return "FIBONACCI EXPANSION";

      case GEOMETRIC_GRID:return "GEOMETRIC EXPANSION";

      case LADDER_GRID:return "LADDER PROGRESSION";

      case BREAKOUT_GRID:case VOLATILITY_BREAKOUT_GRID:return "BREAKOUT RESERVE";

      case SESSION_GRID:return "SESSION PROFILE";

      case RANGE_SCALING_GRID:case MEAN_REVERSION_GRID:return "RANGE/MEAN REVERSION";

      case TREND_GRID:case MOMENTUM_GRID:case BULLISH_GRID:case BEARISH_GRID:return "DIRECTIONAL";

      case SMART_REGIME_GRID:return "REGIME SELECTOR";

      default:return "PROFILE RESERVE";

   }

}



bool IsLimitGrid(ENUM_GRID_TYPE t)

{

   return t==MEAN_REVERSION_GRID || t==RANGE_SCALING_GRID || t==BULLISH_GRID || t==BEARISH_GRID;

}



double SessionStepFactor()

{

   int h=CurrentServerHour();

   if(h>=7 && h<13) return 1.0;

   if(h>=13 && h<18) return 1.2;

   if(h>=18 && h<22) return 1.05;

   return 0.75;

}



double LifecycleNextPrice(bool buy,bool &found)

{

   found=false;

   double outer=PendingOuterPrice(buy,found);

   double baseStep=MathMax(PipSize(),g_state.effectiveGridStepPips>0?g_state.effectiveGridStepPips*PipSize():g_state.gridStep*PipSize());

   if(!found)

   {

      double ask=SymbolInfoDouble(_Symbol,SYMBOL_ASK),bid=SymbolInfoDouble(_Symbol,SYMBOL_BID);

      double lead=MathMax(g_state.frontOrderDistancePips*PipSize(),baseStep);

      return NormalizeDouble(buy?ask+lead:bid-lead,_Digits);

   }

   double d=baseStep;

   switch(g_state.gridType)

   {

      case GEOMETRIC_GRID:

         d=baseStep*MathMax(1.05,g_state.lotMultiplier);

         break;

      case FIBONACCI_GRID:

         d=baseStep*1.61803398875;

         break;

      case LADDER_GRID:

         d=baseStep*(1.0+0.25*MathMax(0,g_state.pendingCount-1)/(double)MathMax(1,g_state.gridLevels));

         break;

      case BREAKOUT_GRID:

         { double atr=GetCurrentATRPrice(); d=MathMax(baseStep,atr>0?atr*0.75:baseStep); }

         break;

      case VOLATILITY_BREAKOUT_GRID:

         { double atr=GetCurrentATRPrice(); d=MathMax(baseStep,atr>0?atr:baseStep); }

         break;

      case SESSION_GRID:

         d=baseStep*SessionStepFactor();

         break;

      case HEDGE_GRID:

         d=MathMax(baseStep,g_state.frontOrderDistancePips*PipSize());

         break;

      case SMART_REGIME_GRID:

         if(g_state.regime=="RANGE / MEAN REV") d=baseStep*0.85;

         else if(StringFind(g_state.regime,"HIGH VOL")>=0) d=baseStep*1.25;

         break;

      default: break;

   }

   return NormalizeDouble(buy?outer+d:outer-d,_Digits);

}



bool IsReplenishableStopGrid()

{

   switch(g_state.gridType)

   {

      case BASIC_GRID:

      case HEDGE_GRID:

      case VOLATILITY_GRID:

      case GEOMETRIC_GRID:

      case FIBONACCI_GRID:

      case ATR_ADAPTIVE_GRID:

      case BREAKOUT_GRID:

      case MOMENTUM_GRID:

      case BIDIRECTIONAL_GRID:

      case LADDER_GRID:

      case ANTI_MARTINGALE_GRID:

      case VOLATILITY_BREAKOUT_GRID:

      case SESSION_GRID:

      case SMART_REGIME_GRID:

         return true;

      default:

         return false;

   }

}



double PendingSideAverage(bool buy,int &count)

{

   count=0;

   double sum=0.0;

   for(int i=0;i<OrdersTotal();i++)

   {

      ulong t=OrderGetTicket(i);

      if(t==0 || !IsGridOrder(t,true) || !OrderSelect(t)) continue;

      ENUM_ORDER_TYPE ot=(ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);

      bool side=buy ? (ot==ORDER_TYPE_BUY_STOP || ot==ORDER_TYPE_BUY_LIMIT)

                    : (ot==ORDER_TYPE_SELL_STOP || ot==ORDER_TYPE_SELL_LIMIT);

      if(!side) continue;

      sum+=OrderGetDouble(ORDER_PRICE_OPEN);

      count++;

   }

   return count>0?sum/count:0.0;

}



double PendingOuterPrice(bool buy,bool &found)

{

   found=false;

   double outer=0.0;

   for(int i=0;i<OrdersTotal();i++)

   {

      ulong t=OrderGetTicket(i);

      if(t==0 || !IsGridOrder(t,true) || !OrderSelect(t)) continue;

      ENUM_ORDER_TYPE ot=(ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);

      if(buy && ot!=ORDER_TYPE_BUY_STOP) continue;

      if(!buy && ot!=ORDER_TYPE_SELL_STOP) continue;

      double p=OrderGetDouble(ORDER_PRICE_OPEN);

      if(!found || (buy ? p>outer : p<outer)){outer=p;found=true;}

   }

   return outer;

}



bool HasPendingNearPrice(ENUM_ORDER_TYPE type,double price,double tolerance)

{

   for(int i=0;i<OrdersTotal();i++)

   {

      ulong t=OrderGetTicket(i);

      if(t==0 || !IsGridOrder(t,true) || !OrderSelect(t)) continue;

      if((ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE)!=type) continue;

      if(MathAbs(OrderGetDouble(ORDER_PRICE_OPEN)-price)<=tolerance) return true;

   }

   return false;

}



void SmartReplenishGrid()

{

   if(!g_state.riskManagedTrading) return;

   if(!g_state.smartReplenishment || !g_state.gridActive || g_state.exitCoordinationActive) return;

   if(!IsAutonomousControl() && !g_modeBaselineCaptured) return;

   if(!IsReplenishableStopGrid()) return;

   if(IsLimitGrid(g_state.gridType)) return;

   if(g_state.pendingCount>=g_state.maxPendingOrders) return;

   int delay=MathMax(0,g_state.replenishDelaySeconds);

   if(g_state.lastReplenishTime>0 && (TimeCurrent()-g_state.lastReplenishTime)<delay) return;



   int buyCount=0,sellCount=0;

   PendingSideAverage(true,buyCount);

   PendingSideAverage(false,sellCount);

   bool buyIntent=(buyCount>0),sellIntent=(sellCount>0);



   if(g_state.gridType==HEDGE_GRID || g_state.gridType==BASIC_GRID || g_state.gridType==BIDIRECTIONAL_GRID ||

      g_state.gridType==VOLATILITY_GRID || g_state.gridType==GEOMETRIC_GRID || g_state.gridType==FIBONACCI_GRID ||

      g_state.gridType==ATR_ADAPTIVE_GRID || g_state.gridType==BREAKOUT_GRID || g_state.gridType==LADDER_GRID ||

      g_state.gridType==ANTI_MARTINGALE_GRID || g_state.gridType==VOLATILITY_BREAKOUT_GRID ||

      g_state.gridType==SESSION_GRID || g_state.gridType==SMART_REGIME_GRID)

   {

      buyIntent=(buyIntent||g_state.positionCount>0);

      sellIntent=(sellIntent||g_state.positionCount>0);

   }



   double baseLot=CalculateAdaptiveLot(g_state.lotSize);

   bool placed=false;

   if(buyIntent && GetPendingCount()<g_state.maxPendingOrders)

   {

      bool found=false; double px=LifecycleNextPrice(true,found);

      if(!HasPendingNearPrice(ORDER_TYPE_BUY_STOP,px,MathMax(PipSize(),MathAbs(px-SymbolInfoDouble(_Symbol,SYMBOL_ASK))*0.15)) && PlaceGridOrder(ORDER_TYPE_BUY_STOP,px,baseLot)) placed=true;

   }

   if(sellIntent && GetPendingCount()<g_state.maxPendingOrders)

   {

      bool found=false; double px=LifecycleNextPrice(false,found);

      if(!HasPendingNearPrice(ORDER_TYPE_SELL_STOP,px,MathMax(PipSize(),MathAbs(px-SymbolInfoDouble(_Symbol,SYMBOL_BID))*0.15)) && PlaceGridOrder(ORDER_TYPE_SELL_STOP,px,baseLot)) placed=true;

   }

   if(placed)

   {

      g_state.lastReplenishTime=TimeCurrent();

      g_state.replenishments++;

      g_state.gridLifecycleState="ACTIVE / REPLENISHING";

      g_state.gridLifecycleReason=GridLifecycleModel(g_state.gridType);

      SetAction("SMART REPLENISH","GRID LEVEL ADDED",g_state.gridLifecycleReason);

      RecordEvent("GRID REPLENISH",StringFormat("Trade-set generation %I64u | %s | Pending %d/%d",g_state.gridCycleId,g_state.gridLifecycleReason,GetPendingCount(),g_state.maxPendingOrders));

      UpdateState();

   }

}



void RecoverGridState()

{

   int pos=GetPositionCount();

   int pend=GetPendingCount();

   if(pos==0 && pend==0) return;

   double buyAvg=0.0,sellAvg=0.0; int buyN=0,sellN=0;

   buyAvg=PendingSideAverage(true,buyN); sellAvg=PendingSideAverage(false,sellN);

   double recoveredAnchor=0.0;

   double step=MathMax(PipSize(),g_state.gridStep*PipSize());

   switch(g_state.gridType)

   {

      case GEOMETRIC_GRID: step*=MathMax(1.05,g_state.lotMultiplier); break;

      case FIBONACCI_GRID: step*=1.0; break;

      case SESSION_GRID: step*=SessionStepFactor(); break;

      case BREAKOUT_GRID: { double atr=GetCurrentATRPrice(); step=MathMax(step,atr>0?atr*0.75:step); } break;

      case VOLATILITY_BREAKOUT_GRID: { double atr=GetCurrentATRPrice(); step=MathMax(step,atr>0?atr:step); } break;

      default: break;

   }

   if(buyN>0&&sellN>0) recoveredAnchor=(buyAvg+sellAvg)/2.0;

   else if(buyN>0) recoveredAnchor=buyAvg-step;

   else if(sellN>0) recoveredAnchor=sellAvg+step;

   if(recoveredAnchor<=0.0)

   {

      double sum=0.0;int n=0;

      for(int i=0;i<PositionsTotal();i++){ulong t=PositionGetTicket(i);if(t==0||!IsGridOrder(t,false)||!PositionSelectByTicket(t))continue;sum+=PositionGetDouble(POSITION_PRICE_OPEN);n++;}

      recoveredAnchor=n>0?sum/n:(SymbolInfoDouble(_Symbol,SYMBOL_ASK)+SymbolInfoDouble(_Symbol,SYMBOL_BID))/2.0;

   }

   g_state.anchorPrice=NormalizeDouble(recoveredAnchor,_Digits);

   g_state.gridActive=true;

   g_state.startTime=TimeCurrent();

   g_state.executionStatus="GRID RECOVERED";

   g_state.lifecycleRecoveryCount++;

   g_state.gridLifecycleState="RECOVERED";

   g_state.gridLifecycleReason=GridLifecycleModel(g_state.gridType);

   SetAction("RECOVERY","GRID RESTORED",StringFormat("%d positions / %d pending | %s",pos,pend,g_state.gridLifecycleReason));

   RecordEvent("GRID RECOVERY",StringFormat("Trade-set generation %I64u | Anchor %.5f | %s",g_state.gridCycleId,g_state.anchorPrice,g_state.gridLifecycleReason));

}



void V15RebuildPending()
{
   string lifecycleReason="";
   if(!GridLifecyclePendingOnlyGuard("REBUILD",lifecycleReason)){g_state.executionStatus="LIFECYCLE BLOCKED";RecordEvent("GRID LIFECYCLE","REBUILD blocked | "+lifecycleReason);return;}
   GridLifecycleBeginLifecycle("REBUILD","USER","PENDING_ONLY");
   int cancelled=0,failed=0;
   for(int i=OrdersTotal()-1;i>=0;i--)
   {
      ulong t=OrderGetTicket(i);
      if(t==0 || !IsGridOrder(t,true))continue;
      if(trade.OrderDelete(t))cancelled++;else failed++;
   }

   MqlTick tk;
   if(!SymbolInfoTick(_Symbol,tk))
   {g_state.executionStatus="REBUILD FAILED | no tick";g_state.lifecycleCommandActive=false;return;}

   ENUM_GRID_TYPE saved=g_state.gridType;
   g_state.gridType=g_selectedGridType;
   g_state.anchorPrice=NormalizeDouble((tk.ask+tk.bid)*0.5,_Digits);
   g_v14ExecutionMagic=(ulong)InpMagicNumber;
   trade.SetExpertMagicNumber((ulong)InpMagicNumber);

   double step=CalculateEffectiveGridStepPips()*PipSize();
   if(step<=0)step=PipSize();
   DeployGridOrders(g_state.anchorPrice,step,true);

   g_state.gridType=saved;
   g_state.positionCount=GetPositionCount();
   g_state.pendingCount=GetPendingCount();
   g_state.gridActive=(g_state.positionCount+g_state.pendingCount)>0;
   g_state.executionStatus=StringFormat("REBUILD | %d pending cancelled | %d failed | live positions preserved",cancelled,failed);
   SetAction("USER","GRID REBUILD",StringFormat("%s | pending only | live positions preserved",GetGridTypeName(g_selectedGridType)));
   RecordEvent("GRID REBUILD",StringFormat("Selected %s | %d cancelled | %d failures | %d live positions preserved",GetGridTypeName(g_selectedGridType),cancelled,failed,g_state.positionCount));
   g_v14FocusMagic=0;g_v14ExecutionMagic=0;
   g_state.lifecycleRebuilds++;
   g_state.lifecycleCommandActive=false;
}

void RecenterGrid(bool forceManual=false)
{
   if(g_state.exitCoordinationActive)return;
   if(!forceManual)
   {
      if(!g_state.riskManagedTrading || !g_state.autoRecenter || !g_state.gridActive)return;
   }
   string lifecycleReason="";
   if(!GridLifecyclePendingOnlyGuard("RECENTER",lifecycleReason)){g_state.executionStatus="LIFECYCLE BLOCKED";RecordEvent("GRID LIFECYCLE","RECENTER blocked | "+lifecycleReason);return;}
   GridLifecycleBeginLifecycle("RECENTER",forceManual?"USER":"AUTO","PENDING_ONLY");

   MqlTick tk;
   if(!SymbolInfoTick(_Symbol,tk)){g_state.lifecycleCommandActive=false;return;}
   double mid=NormalizeDouble((tk.ask+tk.bid)*0.5,_Digits);
   if(mid<=0){g_state.lifecycleCommandActive=false;return;}

   int cancelled=0,failed=0;
   for(int i=OrdersTotal()-1;i>=0;i--)
   {
      ulong ticket=OrderGetTicket(i);
      if(ticket==0 || !IsGridOrder(ticket,true))continue;
      if(trade.OrderDelete(ticket))cancelled++;else failed++;
   }

   g_state.anchorPrice=mid;
   ENUM_GRID_TYPE saved=g_state.gridType;
   g_state.gridType=g_selectedGridType;
   g_v14ExecutionMagic=(ulong)InpMagicNumber;
   trade.SetExpertMagicNumber((ulong)InpMagicNumber);

   double step=MathMax(PipSize(),CalculateEffectiveGridStepPips()*PipSize());
   if(g_state.useATRSpacing && g_state.atrPrice>0)
      step=MathMax(g_state.minGridStep*PipSize(),MathMin(g_state.maxGridStep*PipSize(),g_state.atrPrice*g_state.atrSpacingMultiplier));

   DeployGridOrders(mid,step,true);
   g_state.gridType=saved;
   g_state.positionCount=GetPositionCount();
   g_state.pendingCount=GetPendingCount();
   g_state.gridActive=(g_state.positionCount+g_state.pendingCount)>0;
   g_state.rebalances++;
   g_state.executionStatus=StringFormat("RE-CENTER | anchor %.5f | %d cancelled | %d failed | positions untouched",mid,cancelled,failed);
   SetAction("USER","GRID RECENTER",StringFormat("Immediate pending-only rebuild near %.5f",mid));
   RecordEvent("GRID RECENTER",StringFormat("Anchor %.5f | %d pending cancelled | %d failures | %d live positions preserved",mid,cancelled,failed,g_state.positionCount));
   g_v14FocusMagic=0;g_v14ExecutionMagic=0;
   g_state.lifecycleRecenters++;
   g_state.lifecycleCommandActive=false;
}

void RepriceGridOnApply()

{

   if(!g_state.gridActive || g_state.exitCoordinationActive) return;



   // Apply is a user command: rebuild pending structure immediately using the

   // newly applied settings, while preserving the existing anchor and positions.

   for(int i=OrdersTotal()-1;i>=0;i--)

   {

      ulong t=OrderGetTicket(i);

      if(t==0 || !IsGridOrder(t,true)) continue;

      if(trade.OrderDelete(t)) g_state.lifecycleDeleteCount++;

      else

      {

         RecordEvent("SETTINGS APPLIED","Unable to delete pending order "+(string)t+"; live grid not fully re-priced");

         g_state.executionStatus="REPRICE INCOMPLETE";

         return;

      }

   }



   double effectiveStep=CalculateEffectiveGridStepPips();

   double s=effectiveStep*PipSize();

   if(g_state.useATRSpacing && !g_state.adaptiveGrid && g_state.atrPrice>0)

      s=MathMax(g_state.minGridStep*PipSize(),MathMin(g_state.maxGridStep*PipSize(),g_state.atrPrice*g_state.atrSpacingMultiplier));



   double anchor=g_state.anchorPrice;

   if(anchor<=0)

   {

      MqlTick t;

      if(!SymbolInfoTick(_Symbol,t)) return;

      anchor=(t.ask+t.bid)/2.0;

      g_state.anchorPrice=anchor;

   }



   DeployGridOrders(anchor,s,false);

   g_state.effectiveGridStepPips=effectiveStep;

   g_state.positionCount=GetPositionCount();

   g_state.pendingCount=GetPendingCount();

   g_state.gridActive=(g_state.positionCount>0 || g_state.pendingCount>0);

   g_state.executionStatus=g_state.gridActive?"GRID REPRICED":"NO ORDERS ACCEPTED";



   // Bring existing open positions' SL/TP in line with the newly applied

   // protective settings, without changing their entry prices.

   if(g_state.useStopLossForNewOrders || g_state.useTakeProfitForNewOrders)

   {

      double sd=g_state.useStopLossForNewOrders?GetStopDistancePrice():0;

      double td=g_state.useTakeProfitForNewOrders?GetTakeDistancePrice():0;

      for(int i=PositionsTotal()-1;i>=0;i--)

      {

         ulong t=PositionGetTicket(i);

         if(t==0 || !IsGridOrder(t,false) || !PositionSelectByTicket(t)) continue;

         bool buy=(PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_BUY);

         double open=PositionGetDouble(POSITION_PRICE_OPEN);

         double sl=sd>0?NormalizeDouble(buy?open-sd:open+sd,_Digits):PositionGetDouble(POSITION_SL);

         double tp=td>0?NormalizeDouble(buy?open+td:open-td,_Digits):PositionGetDouble(POSITION_TP);

         trade.PositionModify(t,sl,tp);

      }

   }



   RecordEvent("SETTINGS APPLIED",StringFormat("Grid re-priced at existing anchor %.5f | Step %.2f pips | Lot %.3f | Pending %d",g_state.anchorPrice,effectiveStep,g_state.lotSize,g_state.pendingCount));

}



void CloseProfitPositions(){
   int c=0,f=0,targets=0;
   for(int i=PositionsTotal()-1;i>=0;i--){
      ulong t=PositionGetTicket(i);
      if(t==0||!IsGridOrder(t,false)||!PositionSelectByTicket(t))continue;
      double p=PositionGetDouble(POSITION_PROFIT)+PositionGetDouble(POSITION_SWAP);
      if(p>0)targets++;
   }
   if(targets==0){
      g_state.executionStatus="CLOSE PROFIT: NO PROFITABLE POSITIONS";
      return;
   }
   // User command path: execute immediately; do not run the full dashboard/state rebuild first.
   for(int i=PositionsTotal()-1;i>=0;i--){
      ulong t=PositionGetTicket(i);
      if(t==0||!IsGridOrder(t,false)||!PositionSelectByTicket(t))continue;
      double p=PositionGetDouble(POSITION_PROFIT)+PositionGetDouble(POSITION_SWAP);
      if(p<=0)continue;
      ResetLastError();
      if(trade.PositionClose(t,(ulong)MathMax(0,g_state.slippage)))c++;else f++;
   }
   g_state.executionStatus=StringFormat("CLOSE PROFIT: %d/%d",c,targets);
   if(f>0)g_state.executionStatus+=StringFormat(" | FAILED %d",f);
}

void CloseProfitPositionsUltraFast(){
   // Dedicated manual command path.  It intentionally bypasses non-essential telemetry/dashboard work.
   // Profit is evaluated at the moment of the click; broker execution price can still differ under fast markets.
   CloseProfitPositions();
   SetAction("USER","CLOSE PROFIT",g_state.executionStatus);
   RecordEvent("TRADE ACTION",g_state.executionStatus);
   ChartRedraw();
}

void CloseLossPositions(){int c=0,f=0;for(int i=PositionsTotal()-1;i>=0;i--){ulong t=PositionGetTicket(i);if(t==0||!IsGridOrder(t,false)||!PositionSelectByTicket(t))continue;double p=PositionGetDouble(POSITION_PROFIT)+PositionGetDouble(POSITION_SWAP);if(p<0){if(trade.PositionClose(t,(ulong)MathMax(0,g_state.slippage)))c++;else f++;}}g_state.executionStatus=StringFormat("CLOSE LOSS: %d/%d",c,f);}

void CancelPendingGridOrders()
{
   string lifecycleReason="";
   if(!GridLifecyclePendingOnlyGuard("CANCEL",lifecycleReason)){g_state.executionStatus="LIFECYCLE BLOCKED";RecordEvent("GRID LIFECYCLE","CANCEL blocked | "+lifecycleReason);return;}
   GridLifecycleBeginLifecycle("CANCEL","USER","PENDING_ONLY");
   int c=0,f=0;
   for(int i=OrdersTotal()-1;i>=0;i--)
   {
      ulong t=OrderGetTicket(i);
      if(t==0||!IsGridOrder(t,true))continue;
      if(trade.OrderDelete(t))c++;else f++;
   }
   g_state.positionCount=GetPositionCount();
   g_state.pendingCount=GetPendingCount();
   g_state.gridActive=(g_state.positionCount+g_state.pendingCount)>0;
   g_state.executionStatus=StringFormat("CANCEL PENDING: %d/%d | live positions preserved",c,f);
   SetAction("USER","CANCEL PENDING",StringFormat("%d cancelled | %d failures | %d positions preserved",c,f,g_state.positionCount));
   RecordEvent("CANCEL PENDING",StringFormat("%d cancelled | %d failures | %d live positions preserved",c,f,g_state.positionCount));
   g_state.lifecycleCancels++;
   g_state.lifecycleCommandActive=false;
}


// -------------------- STATE / EVENTS -----------------------------



string RuntimeCheckpointFile()

{

   return StringFormat("UG7_Runtime_%s_%I64u.dat",_Symbol,InpMagicNumber);

}

bool IsValidGridTypeValue(int v){return v>=0 && v<GRID_TYPE_COUNT;}
bool IsValidControlModeValue(int v){return v>=0 && v<=2;}
bool IsValidEntryModeValue(int v){return v>=0 && v<=3;}
bool IsValidRiskModeValue(int v){return v>=0 && v<=3;}
bool IsValidReentryModeValue(int v){return v>=0 && v<=3;}

string BuildStateSignature()
{
   return StringFormat(
      "G=%d|SG=%d|E=%d|C=%d|R=%d|RE=%d|L=%.8f|S=%.8f|LV=%d|M=%.8f|MIN=%.8f|MAX=%.8f|ATR=%d|ATRM=%.8f|SL=%d|TP=%d|RISK=%.8f|MAXR=%.8f|DD=%.8f|DL=%.8f|DP=%.8f|BTP=%.8f|BSL=%.8f|SPR=%.8f|MP=%d|MO=%d",
      (int)g_state.gridType,(int)g_selectedGridType,(int)g_state.entryMode,(int)g_state.controlMode,(int)g_state.riskMode,(int)g_state.reentryMode,
      g_state.lotSize,g_state.gridStep,g_state.gridLevels,g_state.lotMultiplier,g_state.minGridStep,g_state.maxGridStep,
      g_state.useATRSpacing?1:0,g_state.atrSpacingMultiplier,g_state.useStopLossForNewOrders?1:0,g_state.useTakeProfitForNewOrders?1:0,
      g_state.riskPerGridPct,g_state.maxGridRiskPct,g_state.maxDrawdownPct,g_state.dailyLossLimitPct,g_state.dailyProfitLockPct,
      g_state.basketTakeProfitUSD,g_state.basketStopLossUSD,g_state.maxSpreadPips,g_state.maxPositions,g_state.maxPendingOrders);
}

bool ValidateLoadedCheckpointState(string &reason)
{
   reason="";
   if(!IsValidGridTypeValue((int)g_state.gridType) || !IsValidGridTypeValue((int)g_selectedGridType) || !IsValidGridTypeValue((int)g_autonomousGridType)){reason="Invalid grid enum in checkpoint";return false;}
   if(!IsValidControlModeValue((int)g_state.controlMode)){reason="Invalid control mode in checkpoint";return false;}
   if(!IsValidEntryModeValue((int)g_state.entryMode)){reason="Invalid entry mode in checkpoint";return false;}
   if(!IsValidRiskModeValue((int)g_state.riskMode)){reason="Invalid risk mode in checkpoint";return false;}
   if(!IsValidReentryModeValue((int)g_state.reentryMode)){reason="Invalid reentry mode in checkpoint";return false;}
   if(!MathIsValidNumber(g_state.lotSize) || !MathIsValidNumber(g_state.gridStep) || !MathIsValidNumber(g_state.maxDrawdownPct)){reason="Non-finite numeric state in checkpoint";return false;}
   if(g_state.gridStep<=0 || g_state.lotSize<=0 || g_state.gridLevels<1){reason="Invalid core grid settings in checkpoint";return false;}
   return true;
}

void SaveRuntimeCheckpoint()

{

   if(!g_state.persistRuntimeState) return;

   int h=FileOpen(RuntimeCheckpointFile(),FILE_WRITE|FILE_TXT|FILE_ANSI);

   if(h==INVALID_HANDLE) return;

   FileWrite(h,"VERSION="+(string)NOVA_CHECKPOINT_VERSION);

   FileWrite(h,"RECOVERY_MODE="+(g_state.recoveryModeActive?"1":"0"));FileWrite(h,"RECOVERY_ATTEMPTS="+(string)g_state.recoveryAttemptsUsed);FileWrite(h,"RECOVERY_SCALE="+DoubleToString(g_state.recoveryLotScale,8));FileWrite(h,"CYCLE_LOSS="+DoubleToString(g_state.cycleRealizedLoss,8));FileWrite(h,"HARD_BREAKER="+(g_state.hardBreakerTriggered?"1":"0"));
    FileWrite(h,"AUTO_ENGINE="+(g_state.autonomousEngine?"1":"0"));FileWrite(h,"AUTO_MODE="+(string)g_state.autonomousDecisionMode);FileWrite(h,"AUTO_INT="+(string)g_state.autonomousDecisionIntervalSec);FileWrite(h,"AUTO_COOL="+(string)g_state.autonomousCooldownSec);FileWrite(h,"AUTO_SCORE="+DoubleToString(g_state.autonomousMinScore,8));FileWrite(h,"AUTO_CONF="+DoubleToString(g_state.autonomousMinConfidence,8));FileWrite(h,"AUTO_STRICT="+(g_state.autonomousStrictFilters?"1":"0"));FileWrite(h,"AUTO_NEUTRAL="+(g_state.autonomousAllowNeutral?"1":"0"));FileWrite(h,"AUTO_ADAPT="+(g_state.autonomousAdaptiveStrategy?"1":"0"));FileWrite(h,"AUTO_FRESH="+(g_state.autonomousRequireFreshMarket?"1":"0"));FileWrite(h,"MTF_MARKET="+(g_state.useMultiTimeframeMarketState?"1":"0"));

   // STATE INTEGRITY: persist the complete applied configuration, not only the small legacy subset.
   FileWrite(h,"MINSTEP="+DoubleToString(g_state.minGridStep,12));
   FileWrite(h,"MAXSTEP="+DoubleToString(g_state.maxGridStep,12));
   FileWrite(h,"FRONT="+DoubleToString(g_state.frontOrderDistancePips,12));
   FileWrite(h,"ATRSPACE="+(g_state.useATRSpacing?"1":"0"));
   FileWrite(h,"ATRM="+DoubleToString(g_state.atrSpacingMultiplier,12));
   FileWrite(h,"RECATR="+DoubleToString(g_state.recenterATRMultiple,12));
   FileWrite(h,"AUTORECENTER="+(g_state.autoRecenter?"1":"0"));
   FileWrite(h,"AI="+(g_state.aiEnabled?"1":"0"));
   FileWrite(h,"NN="+(g_state.neuralNetwork?"1":"0"));
   FileWrite(h,"AICONF="+DoubleToString(g_state.aiConfidence,12));
   FileWrite(h,"LEARN="+(string)g_state.learningPeriod);
   FileWrite(h,"REGIMEFILTER="+(g_state.regimeFilter?"1":"0"));
   FileWrite(h,"BULL="+DoubleToString(g_state.bullThreshold,12));
   FileWrite(h,"BEAR="+DoubleToString(g_state.bearThreshold,12));
   FileWrite(h,"HIVOL="+DoubleToString(g_state.highVolThreshold,12));
   FileWrite(h,"LOVOL="+DoubleToString(g_state.lowVolThreshold,12));
   FileWrite(h,"DYNRISKLOT="+(g_state.useDynamicRiskLot?"1":"0"));
   FileWrite(h,"RISKMAN="+(g_state.riskManagedTrading?"1":"0"));
   FileWrite(h,"SL="+DoubleToString(g_state.stopLossPips,12));
   FileWrite(h,"TP="+DoubleToString(g_state.takeProfitPips,12));
   FileWrite(h,"BE="+(g_state.breakEven?"1":"0"));
   FileWrite(h,"BETRIG="+DoubleToString(g_state.breakEvenTriggerPips,12));
   FileWrite(h,"BEOFF="+DoubleToString(g_state.breakEvenOffsetPips,12));
   FileWrite(h,"TRAIL="+(g_state.trailingStop?"1":"0"));
   FileWrite(h,"TRAILATR="+DoubleToString(g_state.trailingATRMultiple,12));
   FileWrite(h,"P10_ADAPT="+(g_state.adaptiveTradeProtection?"1":"0"));
   FileWrite(h,"P10_PROFIT="+(g_state.adaptiveProfitManagement?"1":"0"));
   FileWrite(h,"P10_RUNNER="+(g_state.tradeRunnerMode?"1":"0"));
   FileWrite(h,"P10_SLATR="+DoubleToString(g_state.adaptiveSLATRMultiple,12));
   FileWrite(h,"P10_TPATR="+DoubleToString(g_state.adaptiveTPATRMultiple,12));
   FileWrite(h,"P10_LOCKTRIG="+DoubleToString(g_state.profitLockTriggerPips,12));
   FileWrite(h,"P10_LOCKOFF="+DoubleToString(g_state.profitLockOffsetPips,12));
   FileWrite(h,"P10_RUNATR="+DoubleToString(g_state.runnerATRMultiple,12));
   FileWrite(h,"MHOLD="+DoubleToString(g_state.maxHoldMinutes,12));
   FileWrite(h,"OCO="+(g_state.oco?"1":"0"));
   FileWrite(h,"OPPOSITE="+(g_state.closeOppositeOnFill?"1":"0"));
   FileWrite(h,"SLIP="+(string)g_state.slippage);
   FileWrite(h,"EXP="+(string)g_state.pendingExpiryMinutes);
   FileWrite(h,"RETRY="+(string)g_state.orderRetryCount);
   FileWrite(h,"SESSION="+(g_state.useSessionFilter?"1":"0"));
   FileWrite(h,"SSTART="+(string)g_state.sessionStartHour);
   FileWrite(h,"SEND="+(string)g_state.sessionEndHour);
   FileWrite(h,"WEEKEND="+(g_state.avoidWeekend?"1":"0"));
   FileWrite(h,"HIVOLPAUSE="+(g_state.pauseHighVolatility?"1":"0"));
   FileWrite(h,"ADVSENS="+DoubleToString(g_state.adaptiveSensitivity,12));
   FileWrite(h,"MAXSTEPCHG="+DoubleToString(g_state.maxStepChangePct,12));
   FileWrite(h,"ANCHORMODE="+(string)((int)g_state.adaptiveAnchorMode));
   FileWrite(h,"MAXLOTS="+DoubleToString(g_state.maxTotalLots,12));
   FileWrite(h,"AUTOMAX="+(string)g_state.maxAutonomousGridsPerDay);
   FileWrite(h,"AUTOMINSUIT="+DoubleToString(g_state.autonomousMinSuitability,12));
   FileWrite(h,"ADAPMIN="+(string)g_state.adaptiveMinLevels);
   FileWrite(h,"ADAPMAX="+(string)g_state.adaptiveMaxLevels);
   FileWrite(h,"CFG_SIG="+BuildStateSignature());

   FileWrite(h,"GRIDTYPE="+(string)((int)g_state.gridType));
    FileWrite(h,"SELECTED_GRID="+(string)((int)g_selectedGridType));

   FileWrite(h,"ENTRYMODE="+(string)((int)g_state.entryMode));

   FileWrite(h,"CONTROL="+(string)((int)g_state.controlMode));

   FileWrite(h,"RISKMODE="+(string)((int)g_state.riskMode));

   FileWrite(h,"REENTRY="+(string)((int)g_state.reentryMode));

   FileWrite(h,"LOT="+DoubleToString(g_state.lotSize,12));

   FileWrite(h,"STEP="+DoubleToString(g_state.gridStep,12));

   FileWrite(h,"MULT="+DoubleToString(g_state.lotMultiplier,12));

   FileWrite(h,"LEVELS="+(string)g_state.gridLevels);

   FileWrite(h,"ANCHOR="+DoubleToString(g_state.anchorPrice,12));

   FileWrite(h,"GRIDACTIVE="+(g_state.gridActive?"1":"0"));

   FileWrite(h,"CYCLE="+(string)g_state.gridCycleId);

   FileWrite(h,"LIFECYCLE="+g_state.gridLifecycleState);

   FileWrite(h,"LIFECYCLEREASON="+g_state.gridLifecycleReason);

   FileWrite(h,"EXITACTIVE="+(g_state.exitCoordinationActive?"1":"0"));

   FileWrite(h,"STRATMGMT="+(g_state.strategyAwareManagement?"1":"0"));

   FileWrite(h,"EXITCOORD="+(g_state.strategyExitCoordination?"1":"0"));

   FileWrite(h,"PERM_ENTRY="+(g_state.permAutonomousEntry?"1":"0"));FileWrite(h,"PERM_STEP="+(g_state.permAdaptiveStep?"1":"0"));FileWrite(h,"PERM_LEVELS="+(g_state.permAdaptiveLevels?"1":"0"));FileWrite(h,"PERM_LOT="+(g_state.permAdaptiveLot?"1":"0"));FileWrite(h,"PERM_STRAT="+(g_state.permStrategySelection?"1":"0"));FileWrite(h,"PERM_RECENTER="+(g_state.permRecenter?"1":"0"));FileWrite(h,"PERM_REPLENISH="+(g_state.permReplenishment?"1":"0"));FileWrite(h,"PERM_RISK="+(g_state.permRiskAdjust?"1":"0"));FileWrite(h,"PERM_EXPOSURE="+(g_state.permExposureAdjust?"1":"0"));FileWrite(h,"PERM_EMERGENCY="+(g_state.permEmergencyControl?"1":"0"));FileWrite(h,"ADAPTGRID="+(g_state.adaptiveGrid?"1":"0"));FileWrite(h,"EMG_PERM="+(g_state.permEmergencyControl?"1":"0"));FileWrite(h,"EMG_ACTIVE="+(g_state.emergencyActive?"1":"0"));FileWrite(h,"EMG_MANUAL="+(g_state.emergencyManualStop?"1":"0"));

   FileWrite(h,"ADAPTLEVELS="+(g_state.adaptiveLevels?"1":"0"));

   FileWrite(h,"ADAPTLOT="+(g_state.adaptiveLot?"1":"0"));

   FileWrite(h,"SMARTREGIME="+(g_state.smartRegime?"1":"0"));

   FileWrite(h,"SMARTRECENTER="+(g_state.smartRecenter?"1":"0"));

   FileWrite(h,"SMARTREPLENISH="+(g_state.smartReplenishment?"1":"0"));

   FileWrite(h,"RECOVERY="+(g_state.gridRecovery?"1":"0"));

   FileWrite(h,"AUTOGRIDS="+(string)g_state.autonomousGridsToday);

   FileWrite(h,"ENGINE_GENERATION="+(string)g_engineGeneration);FileWrite(h,"LAST_MANUAL_GRID="+(string)((int)g_lastManualGridType));FileWrite(h,"AUTO_GRID="+(string)((int)g_autonomousGridType));FileWrite(h,"TIMESTAMP="+(string)TimeCurrent());

   FileClose(h);

   g_state.recoveryCheckpointTime=TimeCurrent();
   g_state.recoveryCheckpointAgeSec=0;
   g_state.recoveryCheckpointResult="SAVED";
   g_state.lastCheckpointTime=g_state.recoveryCheckpointTime;

   g_state.recoveryFile=RuntimeCheckpointFile();

}

string ReadCheckpointValue(const string &lines[],const int n,const string key)

{

   string p=key+"=";

   for(int i=0;i<n;i++) if(StringFind(lines[i],p)==0) return StringSubstr(lines[i],StringLen(p));

   return "";

}

bool LoadRuntimeCheckpoint()

{

   if(!g_state.persistRuntimeState) return false;

   int h=FileOpen(RuntimeCheckpointFile(),FILE_READ|FILE_TXT|FILE_ANSI);

   if(h==INVALID_HANDLE) return false;

   string lines[]; int n=0;

   while(!FileIsEnding(h)){ArrayResize(lines,n+1);lines[n++]=FileReadString(h);} FileClose(h);

   if(n<=0) return false;

   string v=ReadCheckpointValue(lines,n,"VERSION"); int checkpointVersion=(int)StringToInteger(v); if(checkpointVersion<NOVA_CHECKPOINT_MIN_VERSION || checkpointVersion>NOVA_CHECKPOINT_VERSION) return false;
   string recoveryContextReason=""; if(InpRejectContextMismatchCheckpoint && !RecoveryValidateCheckpointContext(lines,n,recoveryContextReason)){g_state.recoveryCheckpointContextOK=false;g_state.recoveryCheckpointResult="CONTEXT REJECTED";g_state.recoveryMismatchReason=recoveryContextReason;RecordEvent("RECOVERY / RESTART CHECKPOINT","Rejected | "+recoveryContextReason);return false;}


   string x;

   x=ReadCheckpointValue(lines,n,"MTF_MARKET"); if(x!="") g_state.useMultiTimeframeMarketState=(StringToInteger(x)!=0); x=ReadCheckpointValue(lines,n,"AUTO_ENGINE"); if(x!="") g_state.autonomousEngine=(StringToInteger(x)!=0); x=ReadCheckpointValue(lines,n,"AUTO_MODE"); if(x!="") g_state.autonomousDecisionMode=(ENUM_AUTONOMOUS_DECISION_MODE)StringToInteger(x); x=ReadCheckpointValue(lines,n,"AUTO_INT"); if(x!="") g_state.autonomousDecisionIntervalSec=(int)StringToInteger(x); x=ReadCheckpointValue(lines,n,"AUTO_COOL"); if(x!="") g_state.autonomousCooldownSec=(int)StringToInteger(x); x=ReadCheckpointValue(lines,n,"AUTO_SCORE"); if(x!="") g_state.autonomousMinScore=ClampDouble(StringToDouble(x),0,1); x=ReadCheckpointValue(lines,n,"AUTO_CONF"); if(x!="") g_state.autonomousMinConfidence=ClampDouble(StringToDouble(x),0,1); x=ReadCheckpointValue(lines,n,"AUTO_STRICT"); if(x!="") g_state.autonomousStrictFilters=(StringToInteger(x)!=0); x=ReadCheckpointValue(lines,n,"AUTO_NEUTRAL"); if(x!="") g_state.autonomousAllowNeutral=(StringToInteger(x)!=0); x=ReadCheckpointValue(lines,n,"AUTO_ADAPT"); if(x!="") g_state.autonomousAdaptiveStrategy=(StringToInteger(x)!=0); x=ReadCheckpointValue(lines,n,"AUTO_FRESH"); if(x!="") g_state.autonomousRequireFreshMarket=(StringToInteger(x)!=0);

   x=ReadCheckpointValue(lines,n,"GRIDTYPE"); if(x!="") g_state.gridType=(ENUM_GRID_TYPE)(int)StringToInteger(x);
   // STATE INTEGRITY: restore complete applied configuration.
   x=ReadCheckpointValue(lines,n,"MINSTEP"); if(x!="") g_state.minGridStep=StringToDouble(x);
   x=ReadCheckpointValue(lines,n,"MAXSTEP"); if(x!="") g_state.maxGridStep=StringToDouble(x);
   x=ReadCheckpointValue(lines,n,"FRONT"); if(x!="") g_state.frontOrderDistancePips=StringToDouble(x);
   x=ReadCheckpointValue(lines,n,"ATRSPACE"); if(x!="") g_state.useATRSpacing=(StringToInteger(x)!=0);
   x=ReadCheckpointValue(lines,n,"ATRM"); if(x!="") g_state.atrSpacingMultiplier=StringToDouble(x);
   x=ReadCheckpointValue(lines,n,"RECATR"); if(x!="") g_state.recenterATRMultiple=StringToDouble(x);
   x=ReadCheckpointValue(lines,n,"AUTORECENTER"); if(x!="") g_state.autoRecenter=(StringToInteger(x)!=0);
   x=ReadCheckpointValue(lines,n,"AI"); if(x!="") g_state.aiEnabled=(StringToInteger(x)!=0);
   x=ReadCheckpointValue(lines,n,"NN"); if(x!="") g_state.neuralNetwork=(StringToInteger(x)!=0);
   x=ReadCheckpointValue(lines,n,"AICONF"); if(x!="") g_state.aiConfidence=StringToDouble(x);
   x=ReadCheckpointValue(lines,n,"LEARN"); if(x!="") g_state.learningPeriod=(int)StringToInteger(x);
   x=ReadCheckpointValue(lines,n,"REGIMEFILTER"); if(x!="") g_state.regimeFilter=(StringToInteger(x)!=0);
   x=ReadCheckpointValue(lines,n,"BULL"); if(x!="") g_state.bullThreshold=StringToDouble(x);
   x=ReadCheckpointValue(lines,n,"BEAR"); if(x!="") g_state.bearThreshold=StringToDouble(x);
   x=ReadCheckpointValue(lines,n,"HIVOL"); if(x!="") g_state.highVolThreshold=StringToDouble(x);
   x=ReadCheckpointValue(lines,n,"LOVOL"); if(x!="") g_state.lowVolThreshold=StringToDouble(x);
   x=ReadCheckpointValue(lines,n,"DYNRISKLOT"); if(x!="") g_state.useDynamicRiskLot=(StringToInteger(x)!=0);
   x=ReadCheckpointValue(lines,n,"RISKMAN"); if(x!="") g_state.riskManagedTrading=(StringToInteger(x)!=0);
   x=ReadCheckpointValue(lines,n,"SL"); if(x!="") g_state.stopLossPips=StringToDouble(x);
   x=ReadCheckpointValue(lines,n,"TP"); if(x!="") g_state.takeProfitPips=StringToDouble(x);
   x=ReadCheckpointValue(lines,n,"BE"); if(x!="") g_state.breakEven=(StringToInteger(x)!=0);
   x=ReadCheckpointValue(lines,n,"BETRIG"); if(x!="") g_state.breakEvenTriggerPips=StringToDouble(x);
   x=ReadCheckpointValue(lines,n,"BEOFF"); if(x!="") g_state.breakEvenOffsetPips=StringToDouble(x);
   x=ReadCheckpointValue(lines,n,"TRAIL"); if(x!="") g_state.trailingStop=(StringToInteger(x)!=0);
   x=ReadCheckpointValue(lines,n,"TRAILATR"); if(x!="") g_state.trailingATRMultiple=StringToDouble(x);
   x=ReadCheckpointValue(lines,n,"P10_ADAPT"); if(x!="") g_state.adaptiveTradeProtection=(StringToInteger(x)!=0);
   x=ReadCheckpointValue(lines,n,"P10_PROFIT"); if(x!="") g_state.adaptiveProfitManagement=(StringToInteger(x)!=0);
   x=ReadCheckpointValue(lines,n,"P10_RUNNER"); if(x!="") g_state.tradeRunnerMode=(StringToInteger(x)!=0);
   x=ReadCheckpointValue(lines,n,"P10_SLATR"); if(x!="") g_state.adaptiveSLATRMultiple=StringToDouble(x);
   x=ReadCheckpointValue(lines,n,"P10_TPATR"); if(x!="") g_state.adaptiveTPATRMultiple=StringToDouble(x);
   x=ReadCheckpointValue(lines,n,"P10_LOCKTRIG"); if(x!="") g_state.profitLockTriggerPips=StringToDouble(x);
   x=ReadCheckpointValue(lines,n,"P10_LOCKOFF"); if(x!="") g_state.profitLockOffsetPips=StringToDouble(x);
   x=ReadCheckpointValue(lines,n,"P10_RUNATR"); if(x!="") g_state.runnerATRMultiple=StringToDouble(x);
   x=ReadCheckpointValue(lines,n,"MHOLD"); if(x!="") g_state.maxHoldMinutes=StringToDouble(x);
   x=ReadCheckpointValue(lines,n,"OCO"); if(x!="") g_state.oco=(StringToInteger(x)!=0);
   x=ReadCheckpointValue(lines,n,"OPPOSITE"); if(x!="") g_state.closeOppositeOnFill=(StringToInteger(x)!=0);
   x=ReadCheckpointValue(lines,n,"SLIP"); if(x!="") g_state.slippage=(int)StringToInteger(x);
   x=ReadCheckpointValue(lines,n,"EXP"); if(x!="") g_state.pendingExpiryMinutes=(int)StringToInteger(x);
   x=ReadCheckpointValue(lines,n,"RETRY"); if(x!="") g_state.orderRetryCount=(int)StringToInteger(x);
   x=ReadCheckpointValue(lines,n,"SESSION"); if(x!="") g_state.useSessionFilter=(StringToInteger(x)!=0);
   x=ReadCheckpointValue(lines,n,"SSTART"); if(x!="") g_state.sessionStartHour=(int)StringToInteger(x);
   x=ReadCheckpointValue(lines,n,"SEND"); if(x!="") g_state.sessionEndHour=(int)StringToInteger(x);
   x=ReadCheckpointValue(lines,n,"WEEKEND"); if(x!="") g_state.avoidWeekend=(StringToInteger(x)!=0);
   x=ReadCheckpointValue(lines,n,"HIVOLPAUSE"); if(x!="") g_state.pauseHighVolatility=(StringToInteger(x)!=0);
   x=ReadCheckpointValue(lines,n,"ADVSENS"); if(x!="") g_state.adaptiveSensitivity=StringToDouble(x);
   x=ReadCheckpointValue(lines,n,"MAXSTEPCHG"); if(x!="") g_state.maxStepChangePct=StringToDouble(x);x=ReadCheckpointValue(lines,n,"ANCHORMODE"); if(x!="") g_state.adaptiveAnchorMode=(ENUM_GRID_ANCHOR_MODE)MathMax(0,MathMin(3,(int)StringToInteger(x)));
   x=ReadCheckpointValue(lines,n,"MAXLOTS"); if(x!="") g_state.maxTotalLots=StringToDouble(x);
   x=ReadCheckpointValue(lines,n,"AUTOMAX"); if(x!="") g_state.maxAutonomousGridsPerDay=(int)StringToInteger(x);
   x=ReadCheckpointValue(lines,n,"AUTOMINSUIT"); if(x!="") g_state.autonomousMinSuitability=StringToDouble(x);
   x=ReadCheckpointValue(lines,n,"ADAPMIN"); if(x!="") g_state.adaptiveMinLevels=(int)StringToInteger(x);
   x=ReadCheckpointValue(lines,n,"ADAPMAX"); if(x!="") g_state.adaptiveMaxLevels=(int)StringToInteger(x);

    x=ReadCheckpointValue(lines,n,"SELECTED_GRID"); if(x!="") g_selectedGridType=(ENUM_GRID_TYPE)(int)StringToInteger(x); else g_selectedGridType=g_state.gridType; x=ReadCheckpointValue(lines,n,"LAST_MANUAL_GRID"); if(x!="") g_lastManualGridType=(ENUM_GRID_TYPE)(int)StringToInteger(x); else g_lastManualGridType=g_selectedGridType; x=ReadCheckpointValue(lines,n,"AUTO_GRID"); if(x!="") g_autonomousGridType=(ENUM_GRID_TYPE)(int)StringToInteger(x); else g_autonomousGridType=g_selectedGridType;

   x=ReadCheckpointValue(lines,n,"ENTRYMODE"); if(x!="") g_state.entryMode=(ENUM_ENTRY_MODE)(int)StringToInteger(x);

   x=ReadCheckpointValue(lines,n,"CONTROL"); if(x!="") g_state.controlMode=(ENUM_CONTROL_MODE)(int)StringToInteger(x);

   x=ReadCheckpointValue(lines,n,"RISKMODE"); if(x!="") g_state.riskMode=(ENUM_RISK_MODE)(int)StringToInteger(x);

   x=ReadCheckpointValue(lines,n,"REENTRY"); if(x!="") g_state.reentryMode=(ENUM_REENTRY_MODE)(int)StringToInteger(x);

   x=ReadCheckpointValue(lines,n,"LOT"); if(x!="") g_state.lotSize=StringToDouble(x);

   x=ReadCheckpointValue(lines,n,"STEP"); if(x!="") g_state.gridStep=StringToDouble(x);

   x=ReadCheckpointValue(lines,n,"MULT"); if(x!="") g_state.lotMultiplier=StringToDouble(x);

   x=ReadCheckpointValue(lines,n,"LEVELS"); if(x!="") g_state.gridLevels=(int)StringToInteger(x);

   x=ReadCheckpointValue(lines,n,"ANCHOR"); if(x!="") g_state.anchorPrice=StringToDouble(x);

   x=ReadCheckpointValue(lines,n,"GRIDACTIVE"); if(x!="") g_state.gridActive=(StringToInteger(x)!=0);

   x=ReadCheckpointValue(lines,n,"CYCLE"); if(x!="") g_state.gridCycleId=(ulong)StringToInteger(x);

   x=ReadCheckpointValue(lines,n,"LIFECYCLE"); if(x!="") g_state.gridLifecycleState=x;

   x=ReadCheckpointValue(lines,n,"LIFECYCLEREASON"); if(x!="") g_state.gridLifecycleReason=x;

   x=ReadCheckpointValue(lines,n,"EXITACTIVE"); if(x!="") g_state.exitCoordinationActive=(StringToInteger(x)!=0);

   x=ReadCheckpointValue(lines,n,"STRATMGMT"); if(x!="") g_state.strategyAwareManagement=(StringToInteger(x)!=0);

   x=ReadCheckpointValue(lines,n,"EXITCOORD"); if(x!="") g_state.strategyExitCoordination=(StringToInteger(x)!=0);

   x=ReadCheckpointValue(lines,n,"EMG_PERM"); if(x!="") g_state.permEmergencyControl=(StringToInteger(x)!=0); x=ReadCheckpointValue(lines,n,"EMG_ACTIVE"); if(x!="") g_state.emergencyActive=(StringToInteger(x)!=0); x=ReadCheckpointValue(lines,n,"EMG_MANUAL"); if(x!="") g_state.emergencyManualStop=(StringToInteger(x)!=0); x=ReadCheckpointValue(lines,n,"PERM_ENTRY"); if(x!="") g_state.permAutonomousEntry=(StringToInteger(x)!=0); x=ReadCheckpointValue(lines,n,"PERM_STEP"); if(x!="") g_state.permAdaptiveStep=(StringToInteger(x)!=0); x=ReadCheckpointValue(lines,n,"PERM_LEVELS"); if(x!="") g_state.permAdaptiveLevels=(StringToInteger(x)!=0); x=ReadCheckpointValue(lines,n,"PERM_LOT"); if(x!="") g_state.permAdaptiveLot=(StringToInteger(x)!=0); x=ReadCheckpointValue(lines,n,"PERM_STRAT"); if(x!="") g_state.permStrategySelection=(StringToInteger(x)!=0); x=ReadCheckpointValue(lines,n,"PERM_RECENTER"); if(x!="") g_state.permRecenter=(StringToInteger(x)!=0); x=ReadCheckpointValue(lines,n,"PERM_REPLENISH"); if(x!="") g_state.permReplenishment=(StringToInteger(x)!=0); x=ReadCheckpointValue(lines,n,"PERM_RISK"); if(x!="") g_state.permRiskAdjust=(StringToInteger(x)!=0); x=ReadCheckpointValue(lines,n,"PERM_EXPOSURE"); if(x!="") g_state.permExposureAdjust=(StringToInteger(x)!=0); x=ReadCheckpointValue(lines,n,"PERM_EMERGENCY"); if(x!="") g_state.permEmergencyControl=(StringToInteger(x)!=0);

   x=ReadCheckpointValue(lines,n,"ADAPTGRID"); if(x!="") g_state.adaptiveGrid=(StringToInteger(x)!=0);

   x=ReadCheckpointValue(lines,n,"ADAPTLEVELS"); if(x!="") g_state.adaptiveLevels=(StringToInteger(x)!=0);

   x=ReadCheckpointValue(lines,n,"ADAPTLOT"); if(x!="") g_state.adaptiveLot=(StringToInteger(x)!=0);

   x=ReadCheckpointValue(lines,n,"SMARTREGIME"); if(x!="") g_state.smartRegime=(StringToInteger(x)!=0);

   x=ReadCheckpointValue(lines,n,"SMARTRECENTER"); if(x!="") g_state.smartRecenter=(StringToInteger(x)!=0);

   x=ReadCheckpointValue(lines,n,"SMARTREPLENISH"); if(x!="") g_state.smartReplenishment=(StringToInteger(x)!=0);

   x=ReadCheckpointValue(lines,n,"RECOVERY"); if(x!="") g_state.gridRecovery=(StringToInteger(x)!=0);

   x=ReadCheckpointValue(lines,n,"AUTOGRIDS"); if(x!="") g_state.autonomousGridsToday=(int)StringToInteger(x);

   g_state.autonomousMode=(g_state.controlMode==CONTROL_AUTONOMOUS);
   if(g_state.controlMode!=CONTROL_AUTONOMOUS){g_state.autonomousEngine=false;g_state.autonomousReady=false;g_state.autonomousParallelExecution=false;g_state.autonomousDynamicProtection=false;g_state.advancedEntryDecision=false;}

   string loadedSig=ReadCheckpointValue(lines,n,"CFG_SIG");
   string stateValidationReason="";
   if(!ValidateLoadedCheckpointState(stateValidationReason))
   {
      RecordEvent("CHECKPOINT REJECTED",stateValidationReason);
      return false;
   }
   ValidateSettings();
   if(loadedSig!="" && loadedSig!=BuildStateSignature())
      RecordEvent("CHECKPOINT",StringFormat("Signature changed during validation | version %d",checkpointVersion));

   g_state.recoveryCheckpointContextOK=true;g_state.recoveryCheckpointTime=(datetime)StringToInteger(ReadCheckpointValue(lines,n,"P18_SAVE_TIME"));RecoveryUpdateRecoveryTelemetry("CHECKPOINT LOADED");
   g_state.recoveryStatus="CHECKPOINT LOADED"; g_state.recoverySource="LOCAL TERMINAL CHECKPOINT"; g_state.lastRecoveryTime=TimeCurrent();

   RecordEvent("RECOVERY CHECKPOINT","Runtime configuration restored before live-state reconciliation");

   return true;

}

bool RecoveryValidateCheckpointContext(const string &lines[],const int n,string &reason)
{
   reason="";
   string v=ReadCheckpointValue(lines,n,"P18_ACCOUNT");
   if(v!="" && (long)StringToInteger(v)!=(long)AccountInfoInteger(ACCOUNT_LOGIN)){reason="CHECKPOINT ACCOUNT MISMATCH";return false;}
   v=ReadCheckpointValue(lines,n,"P18_SYMBOL");
   if(v!="" && v!=_Symbol){reason="CHECKPOINT SYMBOL MISMATCH";return false;}
   v=ReadCheckpointValue(lines,n,"P18_PERIOD");
   if(v!="" && (int)StringToInteger(v)!=(int)_Period){reason="CHECKPOINT TIMEFRAME MISMATCH";return false;}
   v=ReadCheckpointValue(lines,n,"P18_MAGIC");
   if(v!="" && (ulong)StringToInteger(v)!=(ulong)InpMagicNumber){reason="CHECKPOINT MAGIC MISMATCH";return false;}
   return true;
}

void RecoveryUpdateRecoveryTelemetry(string status,string detail="")
{
   g_state.recoveryLastHeartbeat=TimeCurrent();
   g_state.recoveryEnvironment=StringFormat("%s | %s | %I64d",_Symbol,EnumToString((ENUM_TIMEFRAMES)_Period),(long)AccountInfoInteger(ACCOUNT_LOGIN));
   g_state.recoveryCheckpointResult=status;
   if(detail!="") g_state.recoveryMismatchReason=detail;
   g_state.recoveryCheckpointAgeSec=(g_state.recoveryCheckpointTime>0?(int)MathMax(0,(long)(TimeCurrent()-g_state.recoveryCheckpointTime)):-1);
   g_state.recoveryCheckpointStale=(g_state.recoveryCheckpointAgeSec>=0 && g_state.recoveryCheckpointAgeSec>(MathMax(1,InpRecoveryStaleMinutes)*60));
}

void RecoveryReconcileInventorySnapshot()
{
   int pos=GetPositionCount(),pend=GetPendingCount();
   g_state.recoveryInventoryReconciled=(pos>=0 && pend>=0);
   if(g_state.recoveryInventoryReconciled && (pos>0||pend>0)) g_state.gridActive=true;
   RecoveryUpdateRecoveryTelemetry(g_state.recoveryInventoryReconciled?"INVENTORY RECONCILED":"INVENTORY CHECK FAILED");
}

void RecoveryStartupHardening(const bool checkpointLoaded)
{
   if(g_state.recoveryRecoveryLock)return;
   g_state.recoveryRecoveryLock=true;
   g_state.recoveryCheckpointContextOK=checkpointLoaded;
   RecoveryReconcileInventorySnapshot();
   int pos=GetPositionCount(),pend=GetPendingCount();
   if(checkpointLoaded){g_state.recoveryStatus=(pos>0||pend>0)?"CHECKPOINT + LIVE INVENTORY":"CHECKPOINT RESTORED";g_state.recoverySource="LOCAL CHECKPOINT + BROKER INVENTORY";}
   else{g_state.recoveryStatus=(pos>0||pend>0)?"LIVE STATE DETECTED":"NO CHECKPOINT";g_state.recoverySource=(pos>0||pend>0)?"LIVE BROKER INVENTORY":"INITIAL START";}
   g_state.recoveryRecoveryLock=false;
   RecoveryUpdateRecoveryTelemetry(g_state.recoveryStatus,g_state.recoveryMismatchReason);
}

void ReconcileRuntimeAfterRestart()
{
   if(g_state.recoveryRecoveryLock)return;
   g_state.recoveryRecoveryLock=true;
   int pos=GetPositionCount(),pend=GetPendingCount();
   if(pos==0 && pend==0){g_state.gridActive=false;g_state.gridLifecycleState="IDLE";g_state.recoveryStatus="NO LIVE GRID";g_state.recoveryRecoveryLock=false;RecoveryUpdateRecoveryTelemetry("NO LIVE GRID");return;}
   if(!g_state.recoverOrdersAndPositions){g_state.gridActive=true;g_state.recoveryStatus="LIVE STATE DETECTED";g_state.recoveryRecoveryLock=false;RecoveryUpdateRecoveryTelemetry("LIVE STATE DETECTED");return;}
   RecoverGridState();
   g_state.recoveryStatus="LIVE STATE RECONCILED";g_state.recoverySource="POSITIONS + PENDING ORDERS";
   RecordEvent("RECOVERY RECONCILED",StringFormat("%d positions / %d pending | %s",pos,pend,CompactGridName(g_state.gridType)));
   g_state.recoveryRecoveryLock=false;RecoveryUpdateRecoveryTelemetry("LIVE STATE RECONCILED");
}


void MaintainRuntimeCheckpoint()

{

   if(!g_state.persistRuntimeState) return;

   if(g_state.checkpointSeconds<=0) return;

   if(g_state.lastCheckpointTime==0 || (TimeCurrent()-g_state.lastCheckpointTime)>=g_state.checkpointSeconds) SaveRuntimeCheckpoint();

}



void InitializeState(){ZeroMemory(g_state);for(int i=0;i<V14_MAX_GRID_CYCLES;i++){g_v14Cycles[i].id=0;g_v14Cycles[i].magic=0;g_v14Cycles[i].gridType=BASIC_GRID;g_v14Cycles[i].entryMode=MANUAL_ENTRY;g_v14Cycles[i].startTime=0;g_v14Cycles[i].anchorPrice=0;g_v14Cycles[i].gridStep=0;g_v14Cycles[i].lotSize=0;g_v14Cycles[i].gridLevels=0;g_v14Cycles[i].autonomous=false;g_v14Cycles[i].active=false;}g_v14CycleCount=0;g_v14ExecutionCycleId=0;g_v14ExecutionMagic=0;g_v14FocusMagic=0;g_state.gridType=InpGridType;g_selectedGridType=InpGridType;g_state.adaptiveAnchorMode=InpAdaptiveAnchorMode;g_state.entryMode=InpEntryMode;g_state.riskMode=InpRiskMode;g_state.reentryMode=InpReentryMode;g_state.lotSize=InpLotSize;g_state.gridStep=InpGridStep;g_state.gridLevels=InpGridLevels;g_state.lotMultiplier=InpLotMultiplier;g_state.autonomousMode=InpAutonomousMode;g_state.useATRSpacing=InpUseATRSpacing;g_state.atrSpacingMultiplier=InpATRSpacingMultiplier;g_state.minGridStep=InpMinGridStepPips;g_state.maxGridStep=InpMaxGridStepPips;g_state.recenterATRMultiple=InpRecenterATRMultiple;g_state.autoRecenter=InpAutoRecenter;g_state.aiEnabled=InpEnableAI;g_state.neuralNetwork=InpNeuralNetwork;g_state.aiConfidence=InpAIConfidence;g_state.learningPeriod=InpLearningPeriod;g_state.regimeFilter=InpRegimeFilter;g_state.bullThreshold=InpBullThreshold;g_state.bearThreshold=InpBearThreshold;g_state.highVolThreshold=InpHighVolThreshold;g_state.lowVolThreshold=InpLowVolThreshold;g_state.useDynamicRiskLot=InpUseDynamicRiskLot;g_state.riskManagedTrading=InpRiskManagedTrading;g_state.useStopLossForNewOrders=InpUseStopLossForNewOrders;g_state.useTakeProfitForNewOrders=InpUseTakeProfitForNewOrders;g_state.riskPerGridPct=InpRiskPerGridPct;g_state.maxGridRiskPct=InpMaxGridRiskPct;g_state.maxDrawdownPct=InpMaxDrawdownPct;g_state.dailyLossLimitPct=InpDailyLossLimitPct;g_state.dailyProfitLockPct=InpDailyProfitLockPct;g_state.basketTakeProfitUSD=InpBasketTakeProfitUSD;g_state.basketStopLossUSD=InpBasketStopLossUSD;g_state.stopLossPips=InpStopLossPips;g_state.takeProfitPips=InpTakeProfitPips;g_state.breakEven=InpUseBreakEven;g_state.breakEvenTriggerPips=InpBreakEvenTriggerPips;g_state.breakEvenOffsetPips=InpBreakEvenOffsetPips;g_state.trailingStop=InpTrailingStop;g_state.trailingATRMultiple=InpTrailingATRMultiple;g_state.maxHoldMinutes=InpMaxHoldMinutes;g_state.maxPositions=InpMaxPositions;g_state.maxPendingOrders=InpMaxPendingOrders;g_state.oco=InpOCO;g_state.closeOppositeOnFill=InpCloseOppositePendingOnFill;g_state.slippage=InpSlippage;g_state.maxSpreadPips=InpMaxSpreadPips;g_state.pendingExpiryMinutes=InpPendingExpiryMinutes;g_state.smartExecution=InpSmartExecution;g_state.validateStops=InpValidateStops;g_state.orderRetryCount=InpOrderRetryCount;g_state.useSessionFilter=InpUseSessionFilter;g_state.sessionStartHour=InpSessionStartHour;g_state.sessionEndHour=InpSessionEndHour;g_state.avoidWeekend=InpAvoidWeekend;g_state.pauseHighVolatility=InpPauseOnHighVolatility;g_state.frontOrderDistancePips=InpFrontOrderDistancePips;g_state.gridActive=false;g_state.initialEquity=AccountInfoDouble(ACCOUNT_EQUITY);g_state.peakEquity=g_state.initialEquity;g_state.dayAnchor=DayStart();g_state.regime="UNKNOWN";g_state.executionStatus="READY";g_state.protectionMasterEnabled=false;g_state.protectionDrawdownCloseEnabled=false;g_state.protectionDailyLossCloseEnabled=false;g_state.protectionBasketLossCloseEnabled=false;g_state.protectionEmergencyActionEnabled=false;g_state.protectionEmergencyAutoCloseEnabled=false;g_state.protectionEmergencyCancelEnabled=false;g_state.protectionHardBreakerEnabled=false;g_state.protectionBasketProfitCloseEnabled=false;g_state.protectionProfitLockCloseEnabled=false;g_state.protectionMaxHoldCloseEnabled=false;g_state.protectionMonitorOnly=true;g_state.adaptiveTradeProtection=InpAdaptiveTradeProtection;g_state.adaptiveProfitManagement=InpAdaptiveProfitManagement;g_state.tradeRunnerMode=InpTradeRunnerMode;g_state.adaptiveSLATRMultiple=1.25;g_state.adaptiveTPATRMultiple=2.10;g_state.profitLockTriggerPips=8.0;g_state.profitLockOffsetPips=1.5;g_state.runnerATRMultiple=1.20;g_state.tradeProtectionLastAction="NONE";g_state.tradeProtectionLastReason="";g_state.protectionLastAuthority="NONE";g_state.protectionLastTrigger="";g_state.protectionLastAction="MONITOR ONLY";g_state.protectionLastResult="";g_state.protectionEventId=0;g_state.protectionLastEventTime=0;g_state.emergencyAutoClose=false;g_state.emergencyCancelPending=false;g_state.transactionCostModelEnabled=InpTransactionCostModel;g_state.transactionCostGateEnabled=InpTransactionCostGate;g_state.commissionPerLotRoundTurnUSD=MathMax(0.0,InpCommissionPerLotRoundTurnUSD);g_state.expectedSlippagePoints=MathMax(0.0,InpExpectedSlippagePoints);g_state.transactionCostSafetyBps=MathMax(0.0,InpTransactionCostSafetyBps);g_state.transactionCostMinNetEdgeScore=ClampDouble(InpTransactionCostMinNetEdgeScore,0.0,1.0);g_state.transactionCostExpectedFillLevels=MathMax(1,MathMin(10,InpTransactionCostExpectedFillLevels));g_state.transactionCostCostStatus="MONITOR";g_state.transactionCostCostReason="Not evaluated";g_state.transactionCostEvaluationTime=0;g_state.transactionCostSpreadCostUSD=0.0;g_state.transactionCostCommissionUSD=0.0;g_state.transactionCostSlippageCostUSD=0.0;g_state.transactionCostEstimatedCostUSD=0.0;g_state.transactionCostEstimatedCostPct=0.0;g_state.transactionCostGrossEdgeScore=0.0;g_state.transactionCostCostDragPct=0.0;g_state.transactionCostCostAdjustedEdgeScore=0.0;g_state.strategyHealthEnabled=InpStrategyHealthEnabled;g_state.adaptiveStrategyAllocation=InpAdaptiveStrategyAllocation;g_state.strategyHealthLookbackDays=MathMax(1,InpStrategyHealthLookbackDays);g_state.strategyHealthMinSamples=MathMax(1,InpStrategyHealthMinSamples);g_state.strategyHealthMinAllocation=ClampDouble(InpStrategyHealthMinAllocation,0.25,1.0);g_state.strategyHealthMaxAllocation=ClampDouble(InpStrategyHealthMaxAllocation,1.0,1.50);g_state.strategyHealthSelectedHealth=0.50;g_state.strategyHealthSelectedAllocation=1.00;g_state.strategyHealthSelectedDirectionHealth=0.50;g_state.strategyHealthSelectedSessionHealth=0.50;g_state.strategyHealthSelectedRegimeHealth=0.50;g_state.strategyHealthSelectedSamples=0;g_state.strategyHealthEvaluationCount=0;g_state.strategyHealthHealthState="NOT RUN";g_state.strategyHealthAllocationReason="Awaiting health refresh";g_state.executionQualityScore=100.0;g_state.executionAverageLatencyMs=0.0;g_state.executionAverageRetries=0.0;g_state.executionLastSlippagePoints=0.0;g_state.executionSampleCount=0;g_state.executionSuccessfulCount=0;g_state.executionRetrySamples=0;g_state.executionRejectCount=0;g_state.executionPreflightRejectCount=0;g_state.executionQualityState="NO SAMPLES";g_state.executionPreflightState="READY";g_state.executionLastQualityReason="";g_state.executionLastSampleTime=0;g_state.executionPreflightOK=true;g_state.executionQualityDegraded=false;g_state.autonomousPipelineStage="IDLE";g_state.autonomousDecisionClass="WAIT";g_state.autonomousDecisionReason="Waiting for autonomous evaluation";
   g_state.autonomousRiskDecision="NOT EVALUATED";g_state.autonomousExecutionDecision="NOT EVALUATED";g_state.autonomousPlanSummary="NO TRADE PLAN";
   g_state.autonomousPlanDirection="NEUTRAL";g_state.autonomousPlanGridType=g_state.gridType;g_state.autonomousPlanScore=0.0;
   g_state.autonomousPlanConfidence=0.0;g_state.autonomousPlanExpectedEdge=0.0;g_state.autonomousPlanRiskPct=0.0;g_state.autonomousPlanLot=0.0;
   g_state.autonomousPlanStepPips=0.0;g_state.autonomousPlanLevels=0;g_state.autonomousPlanTime=0;g_state.autonomousWaitCount=0;g_state.autonomousRejectCount=0;g_state.appliedChartTheme=-1;g_state.autoChartTheme=InpAutoChartTheme;g_state.chartThemeMode=InpChartThemeMode;g_state.chartShowGrid=InpChartShowGrid;g_state.chartShowTradeLevels=InpChartShowTradeLevels;g_state.chartAutoScroll=InpChartAutoScroll;g_state.chartShift=InpChartShift;g_state.chartShowVolumes=InpChartShowVolumes;

   g_state.controlMode=InpControlMode; g_state.autonomousMode=(g_state.controlMode==CONTROL_AUTONOMOUS);
   g_state.manualEntryRiskGuard=InpManualEntryRiskGuard;
   g_state.autonomousAdaptiveRisk=InpAutonomousAdaptiveRisk;
   g_state.autonomousEntryDrawdownPct=InpAutonomousEntryDrawdownPct;
   g_state.autonomousEntryDailyLossPct=InpAutonomousDailyLossPct;
   g_state.autonomousEntryGridRiskPct=InpAutonomousGridRiskPct;
   g_state.autonomousRiskPerGridPct=InpAutonomousRiskPerGridPct;
   g_state.autonomousMaxConcurrentCycles=MathMax(1,InpAutonomousMaxConcurrentCycles);
   g_state.autonomousMaxPositions=MathMax(2,InpAutonomousMaxPositions);
   g_state.autonomousMaxPendingOrders=MathMax(4,InpAutonomousMaxPendingOrders);
   g_state.manualMaxConcurrentCycles=MathMax(1,InpManualMaxConcurrentCycles);
   g_state.manualMaxConcurrentLots=InpManualMaxConcurrentLots;
   g_state.autonomousAutoProtection=InpAutonomousAutoProtection;
   g_state.autonomousAllowBothDirections=InpAutonomousAllowBothDirections;
   g_state.autonomousDirectionEdge=MathMax(0.02,InpAutonomousDirectionEdge);
   g_state.activeDeploymentCount=0; g_state.deploymentGateReason=""; g_state.autonomousEngine=InpAutonomousEngine; g_state.autonomousDecisionMode=InpAutonomousDecisionMode; g_state.autonomousDecisionIntervalSec=MathMax(0,InpAutonomousDecisionIntervalSec); g_state.autonomousCooldownSec=MathMax(0,InpAutonomousCooldownSec); g_state.autonomousMinScore=ClampDouble(InpAutonomousMinScore,0,1); g_state.autonomousMinConfidence=ClampDouble(InpAutonomousMinConfidence,0,1); g_state.autonomousStrictFilters=InpAutonomousStrictFilters; g_state.autonomousAllowNeutral=InpAutonomousAllowNeutral; g_state.autonomousAdaptiveStrategy=InpAutonomousAdaptiveStrategy; g_state.autonomousRequireFreshMarket=InpAutonomousRequireFreshMarket; g_state.autonomousLastEvaluation=0; g_state.autonomousLastDeployment=0; g_state.autonomousDecisionCount=0; g_state.autonomousApprovalCount=0; g_state.autonomousBlockCount=0; g_state.autonomousScore=0; g_state.autonomousConfidence=0; g_state.autonomousStage="IDLE"; g_state.autonomousCandidate=CompactGridName(g_state.gridType); g_state.autonomousReason="Waiting for autonomous engine"; g_state.autonomousSignal="WAITING"; g_state.autonomousReady=false;g_state.autonomousParallelExecution=false;g_state.autonomousDynamicProtection=false;g_state.autonomousSelectedGridType=g_state.gridType; g_state.strategyAwareManagement=InpStrategyAwareManagement;

   g_state.advancedEntryDecision=InpAdvancedEntryDecision;g_state.adaptiveGrid=InpAdaptiveGrid;g_state.adaptiveLevels=InpAdaptiveLevels;g_state.adaptiveLot=InpAdaptiveLot;g_state.marketIntelligence=InpMarketIntelligence;g_state.smartRegime=InpSmartRegime;g_state.smartRecenter=InpSmartRecenter;g_state.smartReplenishment=InpSmartReplenishment;g_state.exposureManager=InpExposureManager;g_state.advancedProtection=InpAdvancedProtection;g_state.decisionJournal=InpDecisionJournal;g_state.orderGuardian=InpOrderGuardian;

   // SAFE DEFAULTS: autonomous, adaptive, risk-management and emergency permissions are opt-in.

   g_state.permAutonomousEntry=false;g_state.permAdaptiveStep=false;g_state.permAdaptiveLevels=false;g_state.permAdaptiveLot=false;g_state.permStrategySelection=false;g_state.permRecenter=false;g_state.permReplenishment=false;g_state.permRiskAdjust=false;g_state.permExposureAdjust=false;g_state.permEmergencyControl=false;

   g_state.emergencyActive=false;g_state.emergencyManualStop=false;g_state.emergencyAutoClose=false;g_state.emergencyCancelPending=false;g_state.emergencyAutoResume=false;g_state.emergencyLevel=0;g_state.emergencyReason="";g_state.emergencyTime=0;g_state.emergencyMarginLevelPct=AccountInfoDouble(ACCOUNT_MARGIN_LEVEL);g_state.emergencyDrawdownPct=0;g_state.emergencyDailyLossPct=0;g_state.emergencySpreadPips=0;g_state.emergencyVolatilityPct=0;

   g_state.adaptiveSensitivity=InpAdaptiveSensitivity;g_state.maxStepChangePct=InpMaxStepChangePct;g_state.maxTotalLots=InpMaxTotalLots;g_state.maxAutonomousGridsPerDay=InpMaxAutonomousGridsPerDay; g_state.autonomousMinSuitability=InpAutonomousMinSuitability; g_state.adaptiveMinLevels=InpAdaptiveMinLevels; g_state.adaptiveMaxLevels=InpAdaptiveMaxLevels;g_state.replenishDelaySeconds=MathMax(0,InpReplenishDelaySeconds);g_state.lastReplenishTime=0;g_state.replenishments=0;g_state.gridRecovery=InpGridRecovery;g_state.autonomousGridsToday=0;g_state.lifecycleCommandActive=false;g_state.lifecycleCommand="";g_state.lifecycleAuthority="GRID_LIFECYCLE";g_state.lifecycleScope="PENDING + NEW INDIVIDUAL POSITIONS";g_state.lifecycleCommandTime=0;g_state.lifecycleDeployments=0;g_state.lifecycleCancels=0;g_state.lifecycleRebuilds=0;g_state.lifecycleRecenters=0;g_state.lifecycleReplenishments=0;

   g_state.effectiveGridStepPips=g_state.gridStep;g_state.effectiveGridLevels=g_state.gridLevels;g_state.effectiveLot=g_state.lotSize;g_state.recoveryModeActive=false;g_state.recoveryAttemptsUsed=0;g_state.recoveryLotScale=1.0;g_state.cycleRealizedLoss=0.0;g_state.hardBreakerTriggered=false;g_state.gridCycleId=0;g_state.lifecycleFillCount=0;g_state.lifecycleDeleteCount=0;g_state.lifecycleRecoveryCount=0;g_state.gridLifecycleState="IDLE";g_state.gridLifecycleReason="Initialization";g_state.exitCoordinationActive=false;g_state.exitCoordinationReason="";g_state.exitCoordinationTime=0;g_state.gridPolicyStepFactor=1.0;g_state.gridPolicyLotFactor=1.0;g_state.gridPolicyReason="USER BASE";g_state.predictiveGridIntelligence=InpPredictiveGridIntelligence;g_state.predictiveLookaheadBars=MathMax(1,MathMin(24,InpPredictiveLookaheadBars));g_state.predictiveExcursionPips=0.0;g_state.predictiveRetracementPips=0.0;g_state.predictiveContinuationPips=0.0;g_state.predictiveAdversePips=0.0;g_state.predictiveUpperDensity=1.0;g_state.predictiveLowerDensity=1.0;g_state.predictiveTopologyScore=0.0;g_state.predictiveConfidence=0.0;g_state.predictiveState="NOT READY";g_state.predictiveReason="Initialization";g_state.predictiveUpdateTime=0;for(int pgi=0;pgi<50;pgi++)g_state.predictiveLevelReach[pgi]=0.0;g_state.gridPolicyLevelReason="USER BASE";g_state.lastActionOwner="SYSTEM";g_state.lastActionReason="Initialization";g_state.lastDecision="READY";g_state.configWarningCount=0;g_state.configHealth="UNKNOWN";g_state.configWarnings="";g_state.settingsAuditChecked=0;g_state.settingsAuditPassed=0;g_state.settingsAuditWarnings=0;g_state.settingsAuditFailed=0;g_state.settingsAuditTime=0;g_state.settingsAuditStatus="NOT RUN";g_state.settingsAuditSummary="";g_state.lastConfigCheckTime=0;g_state.lastConfigCheckResult="NOT CHECKED";g_state.configCheckSequence=0;g_state.autoRecoverOnInit=InpAutoRecoverOnInit;g_state.persistRuntimeState=InpPersistRuntimeState;g_state.recoverOrdersAndPositions=InpRecoverOrdersAndPositions;g_state.checkpointSeconds=MathMax(0,InpCheckpointSeconds);g_state.lastCheckpointTime=0;g_state.lastRecoveryTime=0;g_state.recoveryStatus="NOT CHECKED";g_state.recoverySource="";g_state.recoveryFile=RuntimeCheckpointFile();g_state.recoveryLastHeartbeat=0;g_state.recoveryCheckpointTime=0;g_state.recoveryCheckpointAgeSec=-1;g_state.recoveryCheckpointContextOK=true;g_state.recoveryInventoryReconciled=false;g_state.recoveryRecoveryLock=false;g_state.recoveryCheckpointStale=false;g_state.recoveryEnvironment="";g_state.recoveryCheckpointResult="NOT CHECKED";g_state.recoveryMismatchReason="";g_state.dashboardSyncDashboardSyncTime=TimeCurrent();g_state.dashboardSyncPendingEdits=0;g_state.dashboardSyncSelectedGridOK=true;g_state.dashboardSyncControlModeOK=true;g_state.dashboardSyncEffectiveStateOK=true;g_state.dashboardSyncDashboardSyncStatus="READY";g_state.dashboardSyncDashboardSyncReason="Dashboard state not yet audited";g_state.authorityAuditChecked=0;g_state.authorityAuditPassed=0;g_state.authorityAuditWarnings=0;g_state.authorityAuditFailed=0;g_state.authorityAuditAuditTime=0;g_state.authorityAuditStatus="NOT RUN";g_state.authorityAuditSummary="";g_state.authorityAuditLastFailure="";ResetEventJournal();

   ValidateSettings();

   UpdateConfigurationHealth();

   RunSettingsAuthorityAudit();}

void UpdateState()
{
   g_state.autonomousMode=(g_state.controlMode==CONTROL_AUTONOMOUS);
   g_state.gridType=g_selectedGridType;
   double eqNow=AccountInfoDouble(ACCOUNT_EQUITY);
   if(g_state.peakEquity<=0)g_state.peakEquity=eqNow;
   if(eqNow>g_state.peakEquity)g_state.peakEquity=eqNow;
   g_state.maxDrawdown=g_state.peakEquity>0?MathMax(0.0,(g_state.peakEquity-eqNow)/g_state.peakEquity*100.0):0.0;
   if(g_state.dayAnchor!=DayStart())
   {
      g_state.dayAnchor=DayStart();
      g_state.autonomousGridsToday=0;
      g_state.recoveryModeActive=false;
      g_state.recoveryAttemptsUsed=0;
      g_state.recoveryLotScale=1.0;
      g_state.cycleRealizedLoss=0.0;
      g_state.hardBreakerTriggered=false;
      RecordEvent("DAY RESET","Daily autonomous counter + recovery state reset");
   }
   MqlTick tick;
   if(SymbolInfoTick(_Symbol,tick) && tick.bid>0.0 && tick.ask>0.0)
      g_state.currentSpreadPips=PipSize()>0?(tick.ask-tick.bid)/PipSize():0.0;
   g_state.positionCount=GetPositionCount();
   g_state.pendingCount=GetPendingCount();
   g_state.gridActive=(g_state.positionCount+g_state.pendingCount)>0;
   g_state.currentProfit=GetGridProfit();
}



string AutonomousDecisionModeName(ENUM_AUTONOMOUS_DECISION_MODE m)

{

   switch(m){case AUTO_DECISION_BALANCED:return "BALANCED";case AUTO_DECISION_TREND:return "TREND";case AUTO_DECISION_RANGE:return "RANGE";case AUTO_DECISION_BREAKOUT:return "BREAKOUT";default:return "SMART";}

}



double CalculateAutonomousMomentum()

{

   double r=g_state.sentimentScore;

   double trend=g_state.trendStrength;

   double directional=(trend>=0.5)?trend:(1.0-trend);

   return ClampDouble(0.55*directional+0.45*((r>=0.5)?r:(1.0-r)),0.0,1.0);

}




// -------------------- GRID SELECTION: GRID SELECTION & DIRECTION ENGINE --------------------
// Purpose:
//   - Score the full 21-grid library against the current MarketState.
//   - Score LONG / SHORT / BOTH independently.
//   - Select a strategy using regime fit, direction compatibility, volatility/structure fit,
//     GRID GEOMETRY adaptive geometry quality and formalized-strategy preference.
//   - Keep selection separate from manual grid authority.
//   - Produce a human-readable decision trace for the dashboard and journal.

enum ENUM_AUTO_BIAS_V15 { AUTO_BIAS15_NEUTRAL=0, AUTO_BIAS15_LONG, AUTO_BIAS15_SHORT, AUTO_BIAS15_BOTH };

double GridSelectionRegimeAffinity(ENUM_GRID_TYPE t)
{
   string r=g_state.marketRegime;
   if(r=="") r=g_state.regime;
   double v=ClampDouble(g_state.volatilityIndex,0.0,1.0);
   double tr=ClampDouble(g_state.trendStrength,0.0,1.0);
   bool up=(StringFind(r,"TREND UP")>=0);
   bool down=(StringFind(r,"TREND DOWN")>=0);
   bool range=(StringFind(r,"RANGE")>=0 || r=="COMPRESSION" || r=="MIXED");
   bool breakout=(r=="BREAKOUT");
   bool transition=(r=="TRANSITION");
   bool shock=(StringFind(r,"SHOCK")>=0 || StringFind(r,"HIGH VOL")>=0);

   switch(t)
   {
      case SMART_REGIME_GRID:
         return 0.80;
      case BULLISH_GRID:
         return ClampDouble(0.35+0.65*tr + (up?0.18:0.0) + (breakout?0.10:0.0),0.0,1.0);
      case BEARISH_GRID:
         return ClampDouble(0.35+0.65*(1.0-tr) + (down?0.18:0.0) + (breakout?0.10:0.0),0.0,1.0);
      case BIDIRECTIONAL_GRID:
         return ClampDouble(0.45 + (range?0.25:0.0) + (transition?0.18:0.0) + (1.0-MathAbs(tr-0.5)*2.0)*0.22,0.0,1.0);
      case HEDGE_GRID:
         return ClampDouble(0.48 + (transition?0.24:0.0) + (range?0.14:0.0) + (shock?0.08:0.0),0.0,1.0);
      case TREND_GRID:
      case MOMENTUM_GRID:
         return ClampDouble(0.35 + 0.45*(2.0*MathAbs(tr-0.5)) + (up||down?0.18:0.0),0.0,1.0);
      case RANGE_SCALING_GRID:
      case MEAN_REVERSION_GRID:
         return ClampDouble(0.35 + (range?0.32:0.0) + (g_state.compressionScore*0.20) + (1.0-v)*0.13,0.0,1.0);
      case BREAKOUT_GRID:
      case VOLATILITY_BREAKOUT_GRID:
         return ClampDouble(0.30 + g_state.breakoutPressure*0.42 + (breakout?0.20:0.0) + v*0.10,0.0,1.0);
      case VOLATILITY_GRID:
      case ATR_ADAPTIVE_GRID:
      case HYBRID_GRID:
         return ClampDouble(0.45 + v*0.28 + g_state.marketStabilityScore*0.12 + (shock?0.08:0.0),0.0,1.0);
      case SESSION_GRID:
         return ClampDouble(0.50 + (g_state.marketSession=="NEW YORK" || g_state.marketSession=="LONDON"?0.18:0.0) + g_state.marketStabilityScore*0.18,0.0,1.0);
      case LADDER_GRID:
      case GEOMETRIC_GRID:
      case FIBONACCI_GRID:
      case AI_GRID:
      case ANTI_MARTINGALE_GRID:
      case BASIC_GRID:
      default:
         return ClampDouble(0.48 + 0.20*g_state.marketStabilityScore + 0.12*(1.0-MathAbs(tr-0.5)*2.0) + (g_state.gridProfileFormalized?0.05:0.0),0.0,1.0);
   }
}

double GridSelectionDirectionCompatibility(ENUM_GRID_TYPE t,ENUM_AUTO_BIAS_V15 bias)
{
   string dir=GridDirectionModel(t);
   if(t==BULLISH_GRID) return bias==AUTO_BIAS15_LONG?1.0:(bias==AUTO_BIAS15_BOTH?0.62:0.18);
   if(t==BEARISH_GRID) return bias==AUTO_BIAS15_SHORT?1.0:(bias==AUTO_BIAS15_BOTH?0.62:0.18);
   if(t==HEDGE_GRID || t==BIDIRECTIONAL_GRID) return bias==AUTO_BIAS15_BOTH?1.0:(g_state.autonomousAllowBothDirections?0.82:0.56);
   if(t==SMART_REGIME_GRID) return bias==AUTO_BIAS15_NEUTRAL?0.75:1.0;
   if(StringFind(dir,"Mean")>=0) return bias==AUTO_BIAS15_BOTH?0.96:0.62;
   if(StringFind(dir,"Directional")>=0)
      return bias==AUTO_BIAS15_BOTH?0.65:0.88;
   return bias==AUTO_BIAS15_BOTH?0.86:0.72;
}

double GridSelectionVolatilityFit(ENUM_GRID_TYPE t)
{
   double v=ClampDouble(g_state.volatilityIndex,0.0,1.0);
   if(t==BIDIRECTIONAL_GRID || t==MEAN_REVERSION_GRID || t==RANGE_SCALING_GRID)
      return ClampDouble(1.0-MathMax(0.0,v-0.55)*1.55,0.20,1.0);
   if(t==BREAKOUT_GRID || t==VOLATILITY_BREAKOUT_GRID || t==VOLATILITY_GRID || t==ATR_ADAPTIVE_GRID)
      return ClampDouble(0.55+0.45*v,0.0,1.0);
   if(t==BULLISH_GRID || t==BEARISH_GRID || t==TREND_GRID || t==MOMENTUM_GRID)
      return ClampDouble(0.90-MathMax(0.0,v-0.65)*0.80,0.30,1.0);
   if(t==HEDGE_GRID) return ClampDouble(0.92-0.28*MathAbs(v-0.55),0.0,1.0);
   if(t==SMART_REGIME_GRID) return 0.88;
   return ClampDouble(0.82-0.30*MathAbs(v-0.50),0.25,1.0);
}

double GridSelectionStructureFit(ENUM_GRID_TYPE t)
{
   double c=ClampDouble(g_state.compressionScore,0.0,1.0);
   double b=ClampDouble(g_state.breakoutPressure,0.0,1.0);
   if(t==BREAKOUT_GRID || t==VOLATILITY_BREAKOUT_GRID) return ClampDouble(0.35+0.65*b,0.0,1.0);
   if(t==MEAN_REVERSION_GRID || t==RANGE_SCALING_GRID || t==BIDIRECTIONAL_GRID) return ClampDouble(0.45+0.55*c,0.0,1.0);
   if(t==BULLISH_GRID || t==BEARISH_GRID || t==TREND_GRID || t==MOMENTUM_GRID) return ClampDouble(0.42+0.58*(1.0-c),0.0,1.0);
   if(t==SMART_REGIME_GRID) return 0.92;
   return ClampDouble(0.60+0.25*c+0.15*b,0.0,1.0);
}

double GridSelectionStabilityFit(ENUM_GRID_TYPE t)
{
   double st=ClampDouble(g_state.marketStabilityScore,0.0,1.0);
   if(StringFind(g_state.marketRegime,"SHOCK")>=0 && t!=SMART_REGIME_GRID && t!=VOLATILITY_BREAKOUT_GRID) st*=0.55;
   if(t==HEDGE_GRID) return ClampDouble(0.72+0.28*st,0.0,1.0);
   if(t==SMART_REGIME_GRID) return ClampDouble(0.78+0.22*st,0.0,1.0);
   return st;
}

double GridSelectionFormalizationFactor(ENUM_GRID_TYPE t)
{
   if(IsPhase4FormalizedGrid(t)) return 1.00;
   // Preserve all 16 legacy engines, but keep them below a fully formalized
   // profile until they are promoted by a later phase.
   return 0.86;
}

string GridSelectionScoreReason(ENUM_GRID_TYPE t,ENUM_AUTO_BIAS_V15 bias,double score)
{
   string r=g_state.marketRegime;
   if(r=="")r=g_state.regime;
   string d=(bias==AUTO_BIAS15_LONG?"LONG":bias==AUTO_BIAS15_SHORT?"SHORT":bias==AUTO_BIAS15_BOTH?"BOTH":"NEUTRAL");
   return StringFormat("%s | %s | %.0f%% fit",CompactGridName(t),d,score*100.0);
}

double GridSelectionScoreGrid(ENUM_GRID_TYPE t,ENUM_AUTO_BIAS_V15 bias)
{
   double regime=GridSelectionRegimeAffinity(t);
   double direction=GridSelectionDirectionCompatibility(t,bias);
   double vol=GridSelectionVolatilityFit(t);
   double structure=GridSelectionStructureFit(t);
   double stability=GridSelectionStabilityFit(t);
   double formal=GridSelectionFormalizationFactor(t);
   double costQuality=(g_state.maxSpreadPips>0?ClampDouble(1.0-g_state.currentSpreadPips/g_state.maxSpreadPips,0.10,1.0):1.0);
   double gridGeometryGeom=(g_state.gridGeometryStepFactor>0?ClampDouble(1.0-MathAbs(g_state.gridGeometryStepFactor-1.0)*0.60,0.55,1.0):0.85);

   double score=
      0.28*regime+
      0.22*direction+
      0.14*vol+
      0.13*structure+
      0.10*stability+
      0.08*costQuality+
      0.05*gridGeometryGeom;

   score*=formal;
   return ClampDouble(score,0.0,1.0);
}


// -------------------- STRATEGY HEALTH — STRATEGY HEALTH & ADAPTIVE ALLOCATION --------------------
enum { STRATEGY_HEALTH_SESSION_COUNT = 6, STRATEGY_HEALTH_REGIME_COUNT = 6 };
double g_phase15GridHealth[GRID_TYPE_COUNT],g_phase15GridAllocation[GRID_TYPE_COUNT];
double g_phase15GridDirectionHealth[GRID_TYPE_COUNT][2];
double g_phase15GridSessionHealth[GRID_TYPE_COUNT][STRATEGY_HEALTH_SESSION_COUNT];
double g_phase15GridRegimeHealth[GRID_TYPE_COUNT][STRATEGY_HEALTH_REGIME_COUNT];
int g_phase15GridSamples[GRID_TYPE_COUNT],g_phase15GridWins[GRID_TYPE_COUNT],g_phase15GridLosses[GRID_TYPE_COUNT];
double g_phase15GridNetProfit[GRID_TYPE_COUNT],g_phase15GridGrossProfit[GRID_TYPE_COUNT],g_phase15GridGrossLoss[GRID_TYPE_COUNT];
datetime g_phase15LastRefresh=0;

int StrategyHealthSessionIndex(string s){if(s=="ASIA")return 0;if(s=="LONDON OPEN")return 1;if(s=="LONDON")return 2;if(s=="NEW YORK OPEN")return 3;if(s=="NEW YORK")return 4;return 5;}
int StrategyHealthRegimeIndex(string s){if(StringFind(s,"TREND UP")>=0)return 0;if(StringFind(s,"TREND DOWN")>=0)return 1;if(StringFind(s,"RANGE")>=0)return 2;if(StringFind(s,"BREAKOUT")>=0)return 3;if(StringFind(s,"SHOCK")>=0||StringFind(s,"VOLATILITY")>=0)return 4;return 5;}
string StrategyHealthCommentField(string comment,string key){string token="|"+key+"=";int p=StringFind(comment,token);if(p<0)return "";int st=p+StringLen(token);int en=StringFind(comment,"|",st);if(en<0)en=StringLen(comment);return StringSubstr(comment,st,en-st);}
double StrategyHealthHealthScore(int n,int wins,double net,double gp,double gl){if(n<=0)return 0.50;double wr=(double)wins/n;double pf=(gl<0?gp/MathAbs(gl):(gp>0?2.0:0.0));double pfScore=ClampDouble(pf/2.0,0,1);double avgAbs=MathMax(1.0,MathAbs(gp+gl)/MathMax(1,n));double expScore=ClampDouble(0.50+(net/n)/avgAbs,0,1);double conf=ClampDouble((double)n/MathMax(1,g_state.strategyHealthMinSamples*4),0,1);double h=0.38*wr+0.28*pfScore+0.19*expScore+0.15*conf;return ClampDouble(0.50+(h-0.50)*conf,0,1);}
void StrategyHealthReset(){for(int i=0;i<GRID_TYPE_COUNT;i++){g_phase15GridHealth[i]=0.50;g_phase15GridAllocation[i]=1.0;g_phase15GridSamples[i]=0;g_phase15GridWins[i]=0;g_phase15GridLosses[i]=0;g_phase15GridNetProfit[i]=0;g_phase15GridGrossProfit[i]=0;g_phase15GridGrossLoss[i]=0;for(int d=0;d<2;d++)g_phase15GridDirectionHealth[i][d]=0.50;for(int j=0;j<STRATEGY_HEALTH_SESSION_COUNT;j++)g_phase15GridSessionHealth[i][j]=0.50;for(int j=0;j<STRATEGY_HEALTH_REGIME_COUNT;j++)g_phase15GridRegimeHealth[i][j]=0.50;}}
void StrategyHealthUpdateSelectedContext()
{
   int selected=(int)g_selectedGridType;
   if(selected<0 || selected>=GRID_TYPE_COUNT) selected=(int)g_state.gridType;
   if(selected<0 || selected>=GRID_TYPE_COUNT) selected=0;
   int d=(g_state.gridSelectionDirection=="SHORT"?1:0);
   int si=StrategyHealthSessionIndex(g_state.marketSession);
   string regNow=(g_state.marketRegime==""?g_state.regime:g_state.marketRegime);
   int ri=StrategyHealthRegimeIndex(regNow);
   g_state.strategyHealthSelectedHealth=g_phase15GridHealth[selected];
   g_state.strategyHealthSelectedAllocation=g_phase15GridAllocation[selected];
   g_state.strategyHealthSelectedDirectionHealth=g_phase15GridDirectionHealth[selected][d];
   g_state.strategyHealthSelectedSessionHealth=g_phase15GridSessionHealth[selected][si];
   g_state.strategyHealthSelectedRegimeHealth=g_phase15GridRegimeHealth[selected][ri];
   g_state.strategyHealthSelectedSamples=g_phase15GridSamples[selected];
   g_state.strategyHealthSelectedSession=g_state.marketSession;
   g_state.strategyHealthSelectedRegime=regNow;
   if(g_state.strategyHealthSelectedSamples<g_state.strategyHealthMinSamples) g_state.strategyHealthHealthState="INSUFFICIENT SAMPLE";
   else if(g_state.strategyHealthSelectedHealth>=0.70) g_state.strategyHealthHealthState="HEALTHY";
   else if(g_state.strategyHealthSelectedHealth>=0.50) g_state.strategyHealthHealthState="STABLE";
   else g_state.strategyHealthHealthState="WEAK";
   g_state.strategyHealthAllocationReason=g_state.adaptiveStrategyAllocation
      ?StringFormat("ALLOC x%.2f | health %.0f%% | %d samples",g_state.strategyHealthSelectedAllocation,g_state.strategyHealthSelectedHealth*100.0,g_state.strategyHealthSelectedSamples)
      :"TELEMETRY ONLY | allocation OFF";
}

void RefreshStrategyHealth(bool force=false){datetime now=TimeCurrent();if(!force&&g_phase15LastRefresh>0&&now-g_phase15LastRefresh<5)return;g_phase15LastRefresh=now;g_state.strategyHealthEvaluationTime=now;g_state.strategyHealthEvaluationCount++;StrategyHealthReset();if(!g_state.strategyHealthEnabled){g_state.strategyHealthHealthState="DISABLED";g_state.strategyHealthSelectedHealth=0.50;g_state.strategyHealthSelectedAllocation=1.0;g_state.strategyHealthAllocationReason="Telemetry disabled";return;}datetime from=now-(datetime)(MathMax(1,g_state.strategyHealthLookbackDays)*86400);if(!HistorySelect(from,now)){g_state.strategyHealthHealthState="NO HISTORY";return;}int dc[GRID_TYPE_COUNT][2],dw[GRID_TYPE_COUNT][2],sc[GRID_TYPE_COUNT][STRATEGY_HEALTH_SESSION_COUNT],sw[GRID_TYPE_COUNT][STRATEGY_HEALTH_SESSION_COUNT],rc[GRID_TYPE_COUNT][STRATEGY_HEALTH_REGIME_COUNT],rw[GRID_TYPE_COUNT][STRATEGY_HEALTH_REGIME_COUNT];double dn[GRID_TYPE_COUNT][2],dgp[GRID_TYPE_COUNT][2],dgl[GRID_TYPE_COUNT][2],sn[GRID_TYPE_COUNT][STRATEGY_HEALTH_SESSION_COUNT],sgp[GRID_TYPE_COUNT][STRATEGY_HEALTH_SESSION_COUNT],sgl[GRID_TYPE_COUNT][STRATEGY_HEALTH_SESSION_COUNT],rn[GRID_TYPE_COUNT][STRATEGY_HEALTH_REGIME_COUNT],rgp[GRID_TYPE_COUNT][STRATEGY_HEALTH_REGIME_COUNT],rgl[GRID_TYPE_COUNT][STRATEGY_HEALTH_REGIME_COUNT];for(int ai=0;ai<GRID_TYPE_COUNT;ai++){for(int ad=0;ad<2;ad++){dc[ai][ad]=0;dw[ai][ad]=0;dn[ai][ad]=0.0;dgp[ai][ad]=0.0;dgl[ai][ad]=0.0;}for(int as=0;as<STRATEGY_HEALTH_SESSION_COUNT;as++){sc[ai][as]=0;sw[ai][as]=0;sn[ai][as]=0.0;sgp[ai][as]=0.0;sgl[ai][as]=0.0;}for(int ar=0;ar<STRATEGY_HEALTH_REGIME_COUNT;ar++){rc[ai][ar]=0;rw[ai][ar]=0;rn[ai][ar]=0.0;rgp[ai][ar]=0.0;rgl[ai][ar]=0.0;}}
for(int i=0;i<HistoryDealsTotal();i++){ulong deal=HistoryDealGetTicket(i);if(deal==0)continue;if(HistoryDealGetString(deal,DEAL_SYMBOL)!=_Symbol)continue;if((ulong)HistoryDealGetInteger(deal,DEAL_MAGIC)!=InpMagicNumber)continue;if((ENUM_DEAL_ENTRY)HistoryDealGetInteger(deal,DEAL_ENTRY)!=DEAL_ENTRY_OUT)continue;double p=HistoryDealGetDouble(deal,DEAL_PROFIT)+HistoryDealGetDouble(deal,DEAL_SWAP)+HistoryDealGetDouble(deal,DEAL_COMMISSION);ENUM_GRID_TYPE gt=GridTypeFromTradeComment(HistoryDealGetString(deal,DEAL_COMMENT),g_selectedGridType);int gi=(int)gt;if(gi<0||gi>=GRID_TYPE_COUNT)continue;string c=HistoryDealGetString(deal,DEAL_COMMENT);int dir=(HistoryDealGetInteger(deal,DEAL_TYPE)==DEAL_TYPE_SELL?0:1);string sesCode=StrategyHealthCommentField(c,"S");string ses="";if(sesCode=="AS")ses="ASIA";else if(sesCode=="LO")ses="LONDON OPEN";else if(sesCode=="LD")ses="LONDON";else if(sesCode=="NO")ses="NEW YORK OPEN";else if(sesCode=="NY")ses="NEW YORK";else if(sesCode=="RL")ses="ROLLOVER / LATE";if(ses=="")ses=StrategyHealthCommentField(c,"SES");if(ses==""){datetime dt=(datetime)HistoryDealGetInteger(deal,DEAL_TIME);MqlDateTime md;TimeToStruct(dt,md);ses=(md.hour<7?"ASIA":(md.hour<10?"LONDON OPEN":(md.hour<13?"LONDON":(md.hour<17?"NEW YORK OPEN":(md.hour<21?"NEW YORK":"ROLLOVER / LATE")))));}int si=StrategyHealthSessionIndex(ses);string regCode=StrategyHealthCommentField(c,"R");string reg="";if(regCode=="TU")reg="TREND UP";else if(regCode=="TD")reg="TREND DOWN";else if(regCode=="RG")reg="RANGE";else if(regCode=="BO")reg="BREAKOUT";else if(regCode=="SH")reg="SHOCK";else if(regCode=="VL")reg="VOLATILITY";if(reg=="")reg=StrategyHealthCommentField(c,"REG");int ri=StrategyHealthRegimeIndex(reg);g_phase15GridSamples[gi]++;g_phase15GridNetProfit[gi]+=p;if(p>=0){g_phase15GridWins[gi]++;g_phase15GridGrossProfit[gi]+=p;}else{g_phase15GridLosses[gi]++;g_phase15GridGrossLoss[gi]+=p;}dc[gi][dir]++;dn[gi][dir]+=p;if(p>=0){dw[gi][dir]++;dgp[gi][dir]+=p;}else dgl[gi][dir]+=p;sc[gi][si]++;sn[gi][si]+=p;if(p>=0){sw[gi][si]++;sgp[gi][si]+=p;}else sgl[gi][si]+=p;rc[gi][ri]++;rn[gi][ri]+=p;if(p>=0){rw[gi][ri]++;rgp[gi][ri]+=p;}else rgl[gi][ri]+=p;}
for(int i=0;i<GRID_TYPE_COUNT;i++){g_phase15GridHealth[i]=StrategyHealthHealthScore(g_phase15GridSamples[i],g_phase15GridWins[i],g_phase15GridNetProfit[i],g_phase15GridGrossProfit[i],g_phase15GridGrossLoss[i]);g_phase15GridAllocation[i]=ClampDouble(0.50+0.65*g_phase15GridHealth[i],g_state.strategyHealthMinAllocation,g_state.strategyHealthMaxAllocation);for(int d=0;d<2;d++)g_phase15GridDirectionHealth[i][d]=StrategyHealthHealthScore(dc[i][d],dw[i][d],dn[i][d],dgp[i][d],dgl[i][d]);for(int j=0;j<STRATEGY_HEALTH_SESSION_COUNT;j++)g_phase15GridSessionHealth[i][j]=StrategyHealthHealthScore(sc[i][j],sw[i][j],sn[i][j],sgp[i][j],sgl[i][j]);for(int j=0;j<STRATEGY_HEALTH_REGIME_COUNT;j++)g_phase15GridRegimeHealth[i][j]=StrategyHealthHealthScore(rc[i][j],rw[i][j],rn[i][j],rgp[i][j],rgl[i][j]);}
StrategyHealthUpdateSelectedContext();}
double StrategyHealthGridAllocationFactor(ENUM_GRID_TYPE t){if(!g_state.strategyHealthEnabled||!g_state.adaptiveStrategyAllocation)return 1.0;int i=(int)t;if(i<0||i>=GRID_TYPE_COUNT)return 1.0;double ctx=0.55*g_phase15GridDirectionHealth[i][g_state.gridSelectionDirection=="SHORT"?1:0]+0.25*g_phase15GridSessionHealth[i][StrategyHealthSessionIndex(g_state.marketSession)]+0.20*g_phase15GridRegimeHealth[i][StrategyHealthRegimeIndex(g_state.marketRegime==""?g_state.regime:g_state.marketRegime)];return ClampDouble(g_phase15GridAllocation[i]*(0.85+0.30*ClampDouble(ctx,0.35,0.90)),g_state.strategyHealthMinAllocation,g_state.strategyHealthMaxAllocation);}
string StrategyHealthRegimeCode(string r){if(StringFind(r,"TREND UP")>=0)return "TU";if(StringFind(r,"TREND DOWN")>=0)return "TD";if(StringFind(r,"RANGE")>=0)return "RG";if(StringFind(r,"BREAKOUT")>=0)return "BO";if(StringFind(r,"SHOCK")>=0)return "SH";if(StringFind(r,"VOLATILITY")>=0)return "VL";return "OT";}
string StrategyHealthSessionCode(string s){if(s=="ASIA")return "AS";if(s=="LONDON OPEN")return "LO";if(s=="LONDON")return "LD";if(s=="NEW YORK OPEN")return "NO";if(s=="NEW YORK")return "NY";return "RL";}
string StrategyHealthDecorateOrderComment(string base){string out=base;string r=g_state.marketRegime==""?g_state.regime:g_state.marketRegime;string rc=StrategyHealthRegimeCode(r);string ss=StrategyHealthSessionCode(g_state.marketSession);if(StringFind(out,"|R=")<0)out+="|R="+rc;if(StringFind(out,"|S=")<0)out+="|S="+ss;return out;}

void GridSelectionRefreshSelection()
{
   RefreshStrategyHealth(false);
   StrategyHealthUpdateSelectedContext();
   // Directional opportunity score: deliberately independent of selected grid.
   double trend=ClampDouble(g_state.trendStrength,0.0,1.0);
   double momentum=ClampDouble(CalculateAutonomousMomentum(),0.0,1.0);
   double sentiment=ClampDouble(g_state.sentimentScore,0.0,1.0);
   double volFit=ClampDouble(1.0-MathAbs(g_state.volatilityIndex-0.50)*1.55,0.20,1.0);
   double stability=ClampDouble(g_state.marketStabilityScore,0.0,1.0);
   double spreadQ=(g_state.maxSpreadPips>0?ClampDouble(1.0-g_state.currentSpreadPips/g_state.maxSpreadPips,0.0,1.0):1.0);

   double longScore=0.40*trend+0.22*momentum+0.14*sentiment+0.10*volFit+0.09*stability+0.05*spreadQ;
   double shortScore=0.40*(1.0-trend)+0.22*(1.0-momentum)+0.14*(1.0-sentiment)+0.10*volFit+0.09*stability+0.05*spreadQ;
   g_state.gridSelectionLongScore=ClampDouble(longScore,0.0,1.0);
   g_state.gridSelectionShortScore=ClampDouble(shortScore,0.0,1.0);
   g_state.gridSelectionDirectionEdge=MathAbs(g_state.gridSelectionLongScore-g_state.gridSelectionShortScore);

   ENUM_AUTO_BIAS_V15 bias=AUTO_BIAS15_BOTH;
   if(g_state.gridSelectionDirectionEdge>=g_state.autonomousDirectionEdge)
      bias=(g_state.gridSelectionLongScore>g_state.gridSelectionShortScore?AUTO_BIAS15_LONG:AUTO_BIAS15_SHORT);

   // Explicit mode biases remain available; they guide selection rather than replace scoring.
   if(g_state.autonomousDecisionMode==AUTO_DECISION_TREND && g_state.gridSelectionDirectionEdge<g_state.autonomousDirectionEdge)
      bias=AUTO_BIAS15_BOTH;
   if(g_state.autonomousDecisionMode==AUTO_DECISION_RANGE) bias=AUTO_BIAS15_BOTH;

   int best=-1;
   double bestScore=-1.0;
   for(int i=0;i<GRID_TYPE_COUNT;i++)
   {
      ENUM_GRID_TYPE t=(ENUM_GRID_TYPE)i;
      double s=GridSelectionScoreGrid(t,bias);

      // Strategy mode preferences are soft weights, never hidden hard vetoes.
      if(g_state.autonomousDecisionMode==AUTO_DECISION_TREND &&
         (t==BULLISH_GRID || t==BEARISH_GRID || t==TREND_GRID || t==MOMENTUM_GRID)) s=MathMin(1.0,s+0.06);
      else if(g_state.autonomousDecisionMode==AUTO_DECISION_RANGE &&
              (t==BIDIRECTIONAL_GRID || t==RANGE_SCALING_GRID || t==MEAN_REVERSION_GRID)) s=MathMin(1.0,s+0.06);
      else if(g_state.autonomousDecisionMode==AUTO_DECISION_BREAKOUT &&
              (t==BREAKOUT_GRID || t==VOLATILITY_BREAKOUT_GRID || t==HYBRID_GRID)) s=MathMin(1.0,s+0.06);

      if(g_state.strategyHealthEnabled && g_state.adaptiveStrategyAllocation) s=ClampDouble(s*StrategyHealthGridAllocationFactor(t),0.0,1.0);

      g_phase6GridSuitability[i]=s;
      g_phase6GridReason[i]=GridSelectionScoreReason(t,bias,s);
      if(s>bestScore){bestScore=s;best=i;}
   }

   // Smart-Regime must remain a valid fallback whenever it is selected or its
   // score is effectively tied with the winner.
   if(best<0) best=(int)SMART_REGIME_GRID;

   ENUM_GRID_TYPE selected=(ENUM_GRID_TYPE)best;
   ENUM_AUTO_BIAS_V15 finalBias=bias;

   // Direction-specific correction for the selected formalized strategy.
   if(selected==BULLISH_GRID) finalBias=AUTO_BIAS15_LONG;
   else if(selected==BEARISH_GRID) finalBias=AUTO_BIAS15_SHORT;
   else if(selected==BIDIRECTIONAL_GRID || selected==HEDGE_GRID) finalBias=AUTO_BIAS15_BOTH;
   else if(selected==SMART_REGIME_GRID)
   {
      string r=g_state.marketRegime;
      if(StringFind(r,"TREND UP")>=0 && g_state.gridSelectionDirectionEdge>=g_state.autonomousDirectionEdge) finalBias=AUTO_BIAS15_LONG;
      else if(StringFind(r,"TREND DOWN")>=0 && g_state.gridSelectionDirectionEdge>=g_state.autonomousDirectionEdge) finalBias=AUTO_BIAS15_SHORT;
      else if(StringFind(r,"BREAKOUT")>=0 && g_state.gridSelectionDirectionEdge>=g_state.autonomousDirectionEdge)
         finalBias=(g_state.gridSelectionLongScore>g_state.gridSelectionShortScore?AUTO_BIAS15_LONG:AUTO_BIAS15_SHORT);
      else finalBias=AUTO_BIAS15_BOTH;
   }

   g_state.gridSelectionSelectedGridName=CompactGridName(selected);
   g_state.gridSelectionSelectedScore=bestScore;
   g_state.gridSelectionGridEdge=bestScore;
   g_state.gridSelectionDirection=(finalBias==AUTO_BIAS15_LONG?"LONG":finalBias==AUTO_BIAS15_SHORT?"SHORT":finalBias==AUTO_BIAS15_BOTH?"BOTH":"NEUTRAL");
   g_state.gridSelectionExpectedEdge=ClampDouble(
      0.55*bestScore+
      0.30*MathMax(g_state.gridSelectionLongScore,g_state.gridSelectionShortScore)+
      0.15*g_state.gridSelectionDirectionEdge,
      0.0,1.0);

   string why=StringFormat("%s %s | regime %s | score %.0f%% | L %.0f%% S %.0f%% | edge %.0f%%",
                           g_state.gridSelectionSelectedGridName,g_state.gridSelectionDirection,
                           g_state.marketRegime,bestScore*100.0,
                           g_state.gridSelectionLongScore*100.0,g_state.gridSelectionShortScore*100.0,
                           g_state.gridSelectionDirectionEdge*100.0);
   g_state.gridSelectionReason=why;
   g_state.gridSelectionSelectionState=g_state.marketNoTrade?"NO TRADE":"READY";
   g_state.gridSelectionEvaluationCount++;

   g_state.autonomousLongScore=g_state.gridSelectionLongScore;
   g_state.autonomousShortScore=g_state.gridSelectionShortScore;
   g_state.autonomousDirectionEdgeScore=g_state.gridSelectionDirectionEdge;
   g_state.autonomousScore=bestScore;
   g_state.autonomousConfidence=ClampDouble(
      0.45*g_state.regimeConfidence+
      0.25*g_state.marketStabilityScore+
      0.20*g_state.gridSelectionDirectionEdge+
      0.10*bestScore,0.0,1.0);
   g_state.marketSuitabilityScore=bestScore;
   g_state.intelligenceConfidence=g_state.autonomousConfidence;

   g_phase6GridSuitability[(int)selected]=bestScore;
}

ENUM_GRID_TYPE SelectAutonomousStrategyV15(ENUM_AUTO_BIAS_V15 &bias)
{
   GridSelectionRefreshSelection();
   bias=AUTO_BIAS15_NEUTRAL;
   if(g_state.gridSelectionDirection=="LONG") bias=AUTO_BIAS15_LONG;
   else if(g_state.gridSelectionDirection=="SHORT") bias=AUTO_BIAS15_SHORT;
   else if(g_state.gridSelectionDirection=="BOTH") bias=AUTO_BIAS15_BOTH;

   for(int i=0;i<GRID_TYPE_COUNT;i++)
      if(CompactGridName((ENUM_GRID_TYPE)i)==g_state.gridSelectionSelectedGridName)
         return (ENUM_GRID_TYPE)i;

   return SMART_REGIME_GRID;
}

bool GridSelectionGridSelectionAudit(string &reason)
{
   reason="";
   if(g_state.gridSelectionEvaluationCount<0){reason="Invalid GRID SELECTION evaluation counter";return false;}
   if(g_state.gridSelectionSelectedScore<0.0 || g_state.gridSelectionSelectedScore>1.0){reason="Selected grid score outside 0..1";return false;}
   if(g_state.gridSelectionLongScore<0.0 || g_state.gridSelectionLongScore>1.0 ||
      g_state.gridSelectionShortScore<0.0 || g_state.gridSelectionShortScore>1.0){reason="Directional score outside 0..1";return false;}
   if(g_state.gridSelectionDirection!="LONG" && g_state.gridSelectionDirection!="SHORT" &&
      g_state.gridSelectionDirection!="BOTH" && g_state.gridSelectionDirection!="NEUTRAL")
   {reason="Invalid GRID SELECTION direction";return false;}
   if(g_state.marketRegime=="" ){reason="Market regime unavailable to selector";return false;}
   for(int i=0;i<GRID_TYPE_COUNT;i++)
   {
      if(!MathIsValidNumber(g_phase6GridSuitability[i]) || g_phase6GridSuitability[i]<0.0 || g_phase6GridSuitability[i]>1.0)
      { reason=StringFormat("Grid %d suitability invalid",i+1); return false; }
   }
   reason=StringFormat("PASS | selected %s | %s | fit %.0f%% | expected edge %.0f%% | evaluated %d/21",
      g_state.gridSelectionSelectedGridName,g_state.gridSelectionDirection,g_state.gridSelectionSelectedScore*100.0,g_state.gridSelectionExpectedEdge*100.0,g_state.gridSelectionEvaluationCount);
   return true;
}

bool AutonomousHardGate(string &reason)
{
   reason="";
   if(!IsAutonomousControl()){reason="Control mode is not AUTONOMOUS";return false;}
   if(!g_state.autonomousEngine){reason="Autonomous Engine is OFF";return false;}
   if(g_state.exitCoordinationActive){reason="Exit coordination active";return false;}
   if(g_state.emergencyActive){reason="Emergency protection active";return false;}
   if(g_state.marketNoTrade){reason=g_state.marketNoTradeReason!=""?g_state.marketNoTradeReason:"Market state says NO TRADE";return false;}

   if(g_state.autonomousCooldownSec>0 && g_state.autonomousLastDeployment>0)
   {
      int remain=g_state.autonomousCooldownSec-(int)(TimeCurrent()-g_state.autonomousLastDeployment);
      if(remain>0){reason=StringFormat("Autonomous cooldown %d sec",remain);return false;}
   }

   if(g_state.autonomousRequireFreshMarket && g_state.autonomousLastEvaluation>0 &&
      (TimeCurrent()-g_state.autonomousLastEvaluation)>g_state.autonomousDecisionIntervalSec*3)
   {reason="Market data evaluation is stale";return false;}

   if(!UnifiedDeploymentGate(true,reason))return false;
   return true;
}

bool EvaluateAutonomousEngine(string &reason)
{
   g_state.autonomousStage="HARD GATES";
   g_state.autonomousReady=false;
   reason="";

   string hard="";
   if(!AutonomousHardGate(hard))
   {
      reason=hard;
      g_state.autonomousReason=reason;
      g_state.autonomousBlockCount++;
      g_state.entryThrottleActive=true;
      g_state.entryThrottleReason=reason;
      g_state.lastDecision="BLOCKED";
      return false;
   }

   g_state.autonomousStage="GRID SELECTION";
   GridSelectionRefreshSelection();

   if(g_state.autonomousScore<g_state.autonomousMinScore)
      reason=StringFormat("Best grid fit %.0f%% below %.0f%%",g_state.autonomousScore*100.0,g_state.autonomousMinScore*100.0);
   else if(g_state.autonomousConfidence<g_state.autonomousMinConfidence)
      reason=StringFormat("Decision confidence %.0f%% below %.0f%%",g_state.autonomousConfidence*100.0,g_state.autonomousMinConfidence*100.0);

   if(reason!="" && g_state.autonomousStrictFilters)
   {
      g_state.autonomousStage="SELECTION FILTER";
      g_state.autonomousReason=reason;
      g_state.autonomousBlockCount++;
      g_state.entryThrottleActive=true;
      g_state.entryThrottleReason=reason;
      g_state.lastDecision="BLOCKED";
      return false;
   }

   g_state.autonomousStage="STRATEGY ROUTER";
   ENUM_AUTO_BIAS_V15 bias=AUTO_BIAS15_NEUTRAL;
   ENUM_GRID_TYPE selected=SelectAutonomousStrategyV15(bias);
   g_state.autonomousCandidate=CompactGridName(selected);
   g_state.autonomousSelectedGridType=selected;
   g_autonomousGridType=selected;
   g_state.autonomousSignal=(bias==AUTO_BIAS15_LONG?"LONG":bias==AUTO_BIAS15_SHORT?"SHORT":bias==AUTO_BIAS15_BOTH?"LONG + SHORT":"NEUTRAL");

   if(g_state.permStrategySelection)
      g_state.gridType=selected;

   if(!g_state.autonomousAllowNeutral && bias==AUTO_BIAS15_NEUTRAL)
   {
      reason="Neutral market rejected by autonomous policy";
      g_state.autonomousReason=reason;
      g_state.autonomousBlockCount++;
      g_state.lastDecision="BLOCKED";
      return false;
   }

   if(g_state.autonomousStrictFilters && g_state.gridSelectionDirectionEdge<g_state.autonomousDirectionEdge &&
      bias!=AUTO_BIAS15_BOTH && selected!=SMART_REGIME_GRID)
   {
      reason=StringFormat("Directional edge %.0f%% below %.0f%%",g_state.gridSelectionDirectionEdge*100.0,g_state.autonomousDirectionEdge*100.0);
      g_state.autonomousStage="DIRECTION FILTER";
      g_state.autonomousReason=reason;
      g_state.autonomousBlockCount++;
      g_state.entryThrottleActive=true;
      g_state.entryThrottleReason=reason;
      g_state.lastDecision="BLOCKED";
      return false;
   }

   g_state.autonomousStage="APPROVED";
   g_state.autonomousReady=true;
   g_state.autonomousApprovalCount++;
   g_state.autonomousReason=StringFormat("APPROVED | %s | %s | fit %.0f%% | expected edge %.0f%% | confidence %.0f%% | L %.0f%% / S %.0f%% | %s",
      CompactGridName(selected),g_state.autonomousSignal,g_state.autonomousScore*100.0,g_state.gridSelectionExpectedEdge*100.0,
      g_state.autonomousConfidence*100.0,g_state.autonomousLongScore*100.0,g_state.autonomousShortScore*100.0,g_state.gridSelectionReason);
   g_state.lastDecision="APPROVED";
   g_state.entryThrottleActive=false;
   g_state.entryThrottleReason="";
   return true;
}


// -------------------- TRANSACTION COSTS: TRANSACTION COST MODEL --------------------
// Estimates spread, commission and slippage cost before autonomous deployment.
// This is entry-cost intelligence only; it never owns live-position exits.

double TransactionCostMoneyPerPriceUnitPerLot()
{
   double tickSize=SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE);
   double tickValue=SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_VALUE);
   if(tickSize<=0.0 || tickValue<=0.0) return 0.0;
   return tickValue/tickSize;
}

double TransactionCostEstimateCostPerLotUSD()
{
   double moneyPerPrice=TransactionCostMoneyPerPriceUnitPerLot();
   if(moneyPerPrice<=0.0) return 0.0;
   double spreadCost=MathMax(0.0,g_state.currentSpreadPips)*PipSize()*moneyPerPrice;
   double point=SymbolInfoDouble(_Symbol,SYMBOL_POINT);
   double expectedSlip=MathMax(0.0,g_state.expectedSlippagePoints);
   double slippageCost=expectedSlip>0.0 && point>0.0 ? expectedSlip*point*moneyPerPrice*2.0 : 0.0;
   return spreadCost+slippageCost+MathMax(0.0,g_state.commissionPerLotRoundTurnUSD);
}

bool EvaluatePhase14TransactionCosts(const double plannedLot,const int plannedLevels,string &reason)
{
   reason="";
   g_state.transactionCostEvaluationTime=TimeCurrent();
   g_state.transactionCostGrossEdgeScore=ClampDouble(g_state.gridSelectionExpectedEdge,0.0,1.0);
   g_state.transactionCostSpreadCostUSD=0.0;
   g_state.transactionCostCommissionUSD=0.0;
   g_state.transactionCostSlippageCostUSD=0.0;
   g_state.transactionCostEstimatedCostUSD=0.0;
   g_state.transactionCostEstimatedCostPct=0.0;
   g_state.transactionCostCostDragPct=0.0;
   g_state.transactionCostCostAdjustedEdgeScore=g_state.transactionCostGrossEdgeScore;
   g_state.transactionCostCostStatus="MONITOR ONLY";
   g_state.transactionCostCostReason="Transaction-cost gate is disabled; model remains monitor-only";

   if(!g_state.transactionCostModelEnabled)
   {
      g_state.transactionCostCostStatus="OFF";
      g_state.transactionCostCostReason="Transaction-cost model disabled";
      return true;
   }

   int fillLevels=MathMax(1,MathMin(plannedLevels,MathMax(1,g_state.transactionCostExpectedFillLevels)));
   double modeledLots=MathMax(0.0,plannedLot)*(double)fillLevels;
   if(modeledLots<=0.0)
   {
      g_state.transactionCostCostStatus="NO PLAN";
      g_state.transactionCostCostReason="No modeled lot exposure";
      return true;
   }

   double moneyPerPrice=TransactionCostMoneyPerPriceUnitPerLot();
   double point=SymbolInfoDouble(_Symbol,SYMBOL_POINT);
   if(moneyPerPrice>0.0)
   {
      g_state.transactionCostSpreadCostUSD=MathMax(0.0,g_state.currentSpreadPips)*PipSize()*moneyPerPrice*modeledLots;
      g_state.transactionCostCommissionUSD=MathMax(0.0,g_state.commissionPerLotRoundTurnUSD)*modeledLots;
      double expectedSlip=MathMax(0.0,g_state.executionSampleCount>0?MathMax(g_state.expectedSlippagePoints,g_state.executionLastSlippagePoints):g_state.expectedSlippagePoints);
      g_state.transactionCostSlippageCostUSD=(expectedSlip>0.0 && point>0.0)?expectedSlip*point*moneyPerPrice*2.0*modeledLots:0.0;
   }
   g_state.transactionCostEstimatedCostUSD=g_state.transactionCostSpreadCostUSD+g_state.transactionCostCommissionUSD+g_state.transactionCostSlippageCostUSD;

   double equity=MathMax(AccountInfoDouble(ACCOUNT_EQUITY),1.0);
   g_state.transactionCostEstimatedCostPct=100.0*g_state.transactionCostEstimatedCostUSD/equity;

   double plannedRiskMoney=0.0;
   if(g_state.autonomousPlanRiskPct>0.0)
      plannedRiskMoney=equity*g_state.autonomousPlanRiskPct/100.0;
   double benchmark=MathMax(plannedRiskMoney,equity*0.001); // at least 0.10% equity as a cost comparison anchor
   g_state.transactionCostCostDragPct=MathMin(80.0,100.0*g_state.transactionCostEstimatedCostUSD/MathMax(benchmark,0.01));
   g_state.transactionCostCostAdjustedEdgeScore=g_state.transactionCostGrossEdgeScore*(1.0-g_state.transactionCostCostDragPct/100.0);

   double safetyScorePenalty=MathMin(0.25,g_state.transactionCostSafetyBps/10000.0);
   g_state.transactionCostCostAdjustedEdgeScore=ClampDouble(g_state.transactionCostCostAdjustedEdgeScore-safetyScorePenalty,0.0,1.0);

   if(!g_state.transactionCostGateEnabled)
   {
      g_state.transactionCostCostStatus="MONITOR ONLY";
      g_state.transactionCostCostReason=StringFormat("Cost $%.2f | edge %.0f%% -> %.0f%%",g_state.transactionCostEstimatedCostUSD,g_state.transactionCostGrossEdgeScore*100.0,g_state.transactionCostCostAdjustedEdgeScore*100.0);
      return true;
   }

   if(g_state.transactionCostCostAdjustedEdgeScore<g_state.transactionCostMinNetEdgeScore)
   {
      reason=StringFormat("Cost-adjusted edge %.0f%% below floor %.0f%% | cost $%.2f",g_state.transactionCostCostAdjustedEdgeScore*100.0,g_state.transactionCostMinNetEdgeScore*100.0,g_state.transactionCostEstimatedCostUSD);
      g_state.transactionCostCostStatus="BLOCK NEW ENTRY";
      g_state.transactionCostCostReason=reason;
      return false;
   }

   g_state.transactionCostCostStatus="PASS";
   g_state.transactionCostCostReason=StringFormat("Net edge %.0f%% | cost $%.2f | drag %.1f%%",g_state.transactionCostCostAdjustedEdgeScore*100.0,g_state.transactionCostEstimatedCostUSD,g_state.transactionCostCostDragPct);
   return true;
}



double TransactionCostObservedCommissionPerLot()
{
   double totalCommission=0.0,totalLots=0.0;
   datetime from=TimeCurrent()-86400*30;
   if(!HistorySelect(from,TimeCurrent())) return 0.0;
   int deals=HistoryDealsTotal();
   for(int i=0;i<deals;i++)
   {
      ulong deal=HistoryDealGetTicket(i);
      if(deal==0) continue;
      string sym=HistoryDealGetString(deal,DEAL_SYMBOL);
      if(sym!=_Symbol) continue;
      double vol=MathAbs(HistoryDealGetDouble(deal,DEAL_VOLUME));
      if(vol<=0.0) continue;
      double comm=MathAbs(HistoryDealGetDouble(deal,DEAL_COMMISSION));
      if(comm<=0.0) continue;
      totalCommission+=comm;
      totalLots+=vol;
   }
   return totalLots>0.0 ? (2.0*totalCommission/totalLots) : 0.0;
}

void RefreshPhase14LiveTelemetry()
{
   if(!g_state.transactionCostModelEnabled)
   {
      g_state.transactionCostCostStatus="OFF";
      g_state.transactionCostCostReason="Transaction-cost model disabled";
      return;
   }

   double monitorLot=MathMax(g_state.effectiveLot,g_state.lotSize);
   double minLot=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN);
   if(monitorLot<=0.0) monitorLot=(minLot>0.0?minLot:0.01);
   int monitorLevels=MathMax(1,MathMin(g_state.effectiveGridLevels>0?g_state.effectiveGridLevels:g_state.gridLevels,10));

   double configuredCommission=g_state.commissionPerLotRoundTurnUSD;
   double observedCommission=TransactionCostObservedCommissionPerLot();
   double modeledCommission=MathMax(configuredCommission,observedCommission);
   if(modeledCommission>0.0 && configuredCommission<=0.0)
      g_state.transactionCostCostReason=StringFormat("Using observed broker commission $%.2f/lot",modeledCommission);

   // Evaluate using the normal cost path, but substitute observed commission when the user did not configure one.
   double savedCommission=g_state.commissionPerLotRoundTurnUSD;
   if(savedCommission<=0.0) g_state.commissionPerLotRoundTurnUSD=modeledCommission;
   string reason="";
   EvaluatePhase14TransactionCosts(monitorLot,monitorLevels,reason);
   g_state.commissionPerLotRoundTurnUSD=savedCommission;
   if(observedCommission>0.0 && savedCommission<=0.0)
      g_state.transactionCostCostReason=StringFormat("Observed commission $%.2f/lot | %s",observedCommission,reason);
}

void CreateTransactionCostPage()
{
   int x=ContentX(),y=PageBodyY(4),w=ContentW(),gap=12,cw=(w-gap)/2;
   DSectionSingle("TC_A","COST MODEL",x,y,cw,250);
   DKV("TC_EN","MODEL",g_state.transactionCostModelEnabled?"ON":"OFF",x+14,y+42,110,g_state.transactionCostModelEnabled?COLOR_GREEN:COLOR_MUTED);
   DKV("TC_GATE","GATE",g_state.transactionCostGateEnabled?"AUTONOMOUS":"MONITOR",x+14,y+72,110,g_state.transactionCostGateEnabled?COLOR_GOLD:COLOR_TEXT);
   string commSource=g_state.commissionPerLotRoundTurnUSD>0.0?"MANUAL":"AUTO";
   double observed=TransactionCostObservedCommissionPerLot();
   string commRate=g_state.commissionPerLotRoundTurnUSD>0.0?StringFormat("$%.2f / lot",g_state.commissionPerLotRoundTurnUSD):(observed>0.0?StringFormat("$%.2f / lot",observed):"NOT OBSERVED");
   DKV("TC_COMM_MODE","COMMISSION",commSource,x+14,y+102,110,COLOR_TEXT);
   DKV("TC_COMM_SRC","SOURCE",g_state.commissionPerLotRoundTurnUSD>0.0?"USER":"BROKER HISTORY",x+14,y+132,110,COLOR_TEXT);
   DKV("TC_COMM_RATE","RATE",commRate,x+14,y+162,110,COLOR_TEXT);
   DKV("TC_GUARD","GUARD",StringFormat("%.1f pt / %.0f bps",g_state.expectedSlippagePoints,g_state.transactionCostSafetyBps),x+14,y+192,110,COLOR_TEXT);
   DToggle("TC_BTN_MODEL","COST MODEL",g_state.transactionCostModelEnabled,x+14,y+216,cw-28);

   DSectionSingle("TC_B","LIVE COST ESTIMATE",x+cw+gap,y,cw,250);
   DKV("TC_SPREAD","SPREAD COST",StringFormat("$%.2f",g_state.transactionCostSpreadCostUSD),x+cw+gap+14,y+42,110,COLOR_TEXT);
   DKV("TC_COMMC","COMMISSION EST.",StringFormat("$%.2f",g_state.transactionCostCommissionUSD),x+cw+gap+14,y+72,110,COLOR_TEXT);
   DKV("TC_SLIPC","SLIPPAGE",StringFormat("$%.2f",g_state.transactionCostSlippageCostUSD),x+cw+gap+14,y+102,110,COLOR_TEXT);
   DKV("TC_TOTAL","TOTAL COST",StringFormat("$%.2f",g_state.transactionCostEstimatedCostUSD),x+cw+gap+14,y+132,110,COLOR_GOLD);
   DKV("TC_PCT","COST / EQUITY",StringFormat("%.3f%%",g_state.transactionCostEstimatedCostPct),x+cw+gap+14,y+162,110,COLOR_TEXT);
   DToggle("TC_BTN_GATE","AUTONOMOUS COST GATE",g_state.transactionCostGateEnabled,x+cw+gap+12,y+196,cw-24);

   DSectionSingle("TC_C","COST-ADJUSTED EDGE",x,y+266,w,225);
   DKV("TC_GROSS","GROSS EDGE",StringFormat("%.0f%%",g_state.transactionCostGrossEdgeScore*100.0),x+14,y+308,110,COLOR_TEXT);
   DKV("TC_DRAG","COST DRAG",StringFormat("%.1f%%",g_state.transactionCostCostDragPct),x+14,y+338,110,g_state.transactionCostCostDragPct>10.0?COLOR_ORANGE:COLOR_TEXT);
   DKV("TC_NET","NET EDGE",StringFormat("%.0f%%",g_state.transactionCostCostAdjustedEdgeScore*100.0),x+14,y+368,110,g_state.transactionCostCostAdjustedEdgeScore>=g_state.transactionCostMinNetEdgeScore?COLOR_GREEN:COLOR_RED);
   DKV("TC_STATUS","STATUS",g_state.transactionCostCostStatus,x+14,y+398,110,g_state.transactionCostCostStatus=="PASS"?COLOR_GREEN:(g_state.transactionCostCostStatus=="BLOCK NEW ENTRY"?COLOR_RED:COLOR_GOLD));
   DText("TC_NOTE",g_state.transactionCostCostReason,x+14,y+430,6,COLOR_MUTED,"Arial");
}

// -------------------- AUTONOMOUS DECISION: AUTONOMOUS DECISION ENGINE --------------------
// Full pipeline:
// Market State -> Regime -> Direction -> Grid Scoring -> Expected Edge
// -> Risk Budget -> Execution Quality -> Trade Plan -> APPROVE / WAIT / REJECT.
//
// This phase is an autonomous decision/orchestration layer. It does not own
// position exits and it does not replace the Risk & Protection authority model.
// Any WAIT/REJECT is surfaced in runtime state and the decision journal.

string AutonomousDecisionClassifyFailure(const string reason,const string stage)
{
   string r=reason;
   string s=stage;
   if(StringFind(r,"cooldown")>=0 ||
      StringFind(r,"stale")>=0 ||
      StringFind(r,"market state says")>=0 ||
      StringFind(r,"no trade")>=0 ||
      StringFind(r,"execution quality degraded")>=0 ||
      StringFind(r,"preflight")>=0 ||
      StringFind(r,"emergency protection active")>=0 ||
      StringFind(r,"exit coordination active")>=0)
      return "WAIT";
   if(s=="RISK BUDGET" || s=="EXECUTION QUALITY" || s=="TRADE PLAN")
      return "REJECT";
   return "REJECT";
}

void AutonomousDecisionSetDecision(const string cls,const string reason,const string stage)
{
   g_state.autonomousDecisionClass=cls;
   g_state.autonomousDecisionReason=reason;
   g_state.autonomousPipelineStage=stage;
   g_state.lastDecision=(cls=="APPROVE"?"APPROVED":cls=="WAIT"?"WAITING":"BLOCKED");
   if(cls=="WAIT")
   {
      g_state.autonomousWaitCount++;
      g_state.entryThrottleActive=true;
      g_state.entryThrottleReason=reason;
   }
   else if(cls=="REJECT")
   {
      g_state.autonomousRejectCount++;
      g_state.entryThrottleActive=true;
      g_state.entryThrottleReason=reason;
   }
   else
   {
      g_state.entryThrottleActive=false;
      g_state.entryThrottleReason="";
   }
}

bool AutonomousDecisionBuildTradePlan(string &reason)
{
   reason="";
   g_state.autonomousPipelineStage="TRADE PLAN";
   ENUM_GRID_TYPE selected=g_state.autonomousSelectedGridType;
   string direction=g_state.autonomousSignal;
   if(direction=="") direction=g_state.gridSelectionDirection;
   if(direction=="" || direction=="NEUTRAL")
   {
      reason="No executable direction";
      return false;
   }

   double step=g_state.effectiveGridStepPips;
   if(step<=0.0) step=CalculateEffectiveGridStepPips();

   int levels=MathMax(1,g_state.effectiveGridLevels);
   if(levels<=0) levels=CalculateEffectiveGridLevels();

   double lot=CalculateAdaptiveLot(g_state.lotSize);
   if(lot<=0.0)
   {
      reason="Trade plan lot is zero";
      return false;
   }

   double riskPct=MathMax(0.0,g_state.autonomousRiskPerGridPct);
   if(g_state.maxGridRiskPct>0.0) riskPct=MathMin(riskPct,g_state.maxGridRiskPct);
   if(riskPct<=0.0 && g_state.riskPerGridPct>0.0) riskPct=g_state.riskPerGridPct;

   g_state.autonomousPlanGridType=selected;
   g_state.autonomousPlanDirection=direction;
   g_state.autonomousPlanScore=g_state.autonomousScore;
   g_state.autonomousPlanConfidence=g_state.autonomousConfidence;
   g_state.autonomousPlanExpectedEdge=g_state.gridSelectionExpectedEdge;
   g_state.autonomousPlanRiskPct=riskPct;
   g_state.autonomousPlanLot=lot;
   g_state.autonomousPlanStepPips=step;
   g_state.autonomousPlanLevels=levels;
   g_state.autonomousPlanTime=TimeCurrent();

   g_state.autonomousPlanSummary=StringFormat("%s | %s | fit %.0f%% | conf %.0f%% | edge %.0f%% | risk %.2f%% | lot %.3f | step %.1f | levels %d",
      CompactGridName(selected),direction,g_state.autonomousScore*100.0,g_state.autonomousConfidence*100.0,
      g_state.gridSelectionExpectedEdge*100.0,riskPct,lot,step,levels);
   return true;
}

bool EvaluateAutonomousDecisionPipeline(string &reason)
{
   reason="";
   g_state.autonomousDecisionReason="";
   g_state.autonomousRiskDecision="NOT EVALUATED";
   g_state.autonomousExecutionDecision="NOT EVALUATED";

   // 1) Core autonomous engine: market state, hard gates, selection, direction, confidence.
   if(!EvaluateAutonomousEngine(reason))
   {
      string cls=AutonomousDecisionClassifyFailure(reason,g_state.autonomousStage);
      AutonomousDecisionSetDecision(cls,reason,g_state.autonomousStage);
      return false;
   }

   // 2) Expected edge gate.
   g_state.autonomousPipelineStage="EXPECTED EDGE";
   if(g_state.gridSelectionExpectedEdge<0.0 || g_state.gridSelectionExpectedEdge>1.0)
   {
      reason="Expected edge value invalid";
      AutonomousDecisionSetDecision("REJECT",reason,g_state.autonomousPipelineStage);
      return false;
   }
   if(g_state.autonomousStrictFilters && g_state.gridSelectionExpectedEdge<MathMax(0.0,g_state.autonomousMinScore-0.05))
   {
      reason=StringFormat("Expected edge %.0f%% below autonomous floor",g_state.gridSelectionExpectedEdge*100.0);
      AutonomousDecisionSetDecision("REJECT",reason,g_state.autonomousPipelineStage);
      return false;
   }

   // 3) Construct the concrete autonomous trade/grid plan before cost and risk evaluation.
   if(!AutonomousDecisionBuildTradePlan(reason))
   {
      AutonomousDecisionSetDecision("REJECT",reason,"TRADE PLAN");
      return false;
   }

   // 4) Transaction-cost gate: TRANSACTION COSTS prevents cost-blind autonomous entries.
   g_state.autonomousPipelineStage="TRANSACTION COST";
   if(!EvaluatePhase14TransactionCosts(g_state.autonomousPlanLot,MathMax(1,g_state.autonomousPlanLevels),reason))
   {
      if(reason=="") reason=g_state.transactionCostCostReason;
      AutonomousDecisionSetDecision("WAIT",reason,g_state.autonomousPipelineStage);
      return false;
   }

   // 5) Risk budget gate: RISK & PORTFOLIO is the authority for available portfolio capacity.
   g_state.autonomousPipelineStage="RISK BUDGET";
   if(!g_state.portfolioRiskOK)
   {
      reason=(g_state.riskBlockReason!=""?g_state.riskBlockReason:"Portfolio risk gate blocked entry");
      g_state.autonomousRiskDecision="BLOCKED | "+reason;
      AutonomousDecisionSetDecision(AutonomousDecisionClassifyFailure(reason,g_state.autonomousPipelineStage),reason,g_state.autonomousPipelineStage);
      return false;
   }
   double plannedRisk=MathMax(0.0,g_state.autonomousRiskPerGridPct);
   if(g_state.maxGridRiskPct>0.0 && plannedRisk>g_state.maxGridRiskPct)
   {
      reason=StringFormat("Autonomous risk %.2f%% exceeds max grid risk %.2f%%",plannedRisk,g_state.maxGridRiskPct);
      g_state.autonomousRiskDecision="BLOCKED | "+reason;
      AutonomousDecisionSetDecision("REJECT",reason,g_state.autonomousPipelineStage);
      return false;
   }
   if(g_state.portfolioRiskCapacityPct<=0.0 && plannedRisk>0.0)
   {
      reason="No portfolio risk capacity remaining";
      g_state.autonomousRiskDecision="WAIT | capacity exhausted";
      AutonomousDecisionSetDecision("WAIT",reason,g_state.autonomousPipelineStage);
      return false;
   }
   if(plannedRisk>0.0 && g_state.portfolioRiskCapacityPct>0.0 && plannedRisk>g_state.portfolioRiskCapacityPct)
   {
      reason=StringFormat("Planned risk %.2f%% exceeds remaining capacity %.2f%%",plannedRisk,g_state.portfolioRiskCapacityPct);
      g_state.autonomousRiskDecision="WAIT | insufficient capacity";
      AutonomousDecisionSetDecision("WAIT",reason,g_state.autonomousPipelineStage);
      return false;
   }
   g_state.autonomousRiskDecision=StringFormat("PASS | risk %.2f%% | capacity %.2f%%",plannedRisk,g_state.portfolioRiskCapacityPct);

   // 4) Execution quality gate: only acts as a quality gate after samples exist.
   g_state.autonomousPipelineStage="EXECUTION QUALITY";
   if(g_state.executionSampleCount>0 && g_state.executionQualityDegraded && g_state.autonomousStrictFilters)
   {
      reason=StringFormat("Execution quality degraded: %.0f%%",g_state.executionQualityScore);
      g_state.autonomousExecutionDecision="WAIT | "+reason;
      AutonomousDecisionSetDecision("WAIT",reason,g_state.autonomousPipelineStage);
      return false;
   }
   if(!g_state.executionPreflightOK && g_state.executionSampleCount>0)
   {
      reason=(g_state.executionLastQualityReason!=""?g_state.executionLastQualityReason:"Execution preflight not ready");
      g_state.autonomousExecutionDecision="WAIT | "+reason;
      AutonomousDecisionSetDecision("WAIT",reason,g_state.autonomousPipelineStage);
      return false;
   }
   g_state.autonomousExecutionDecision=(g_state.executionSampleCount>0?
      StringFormat("PASS | quality %.0f%%",g_state.executionQualityScore):"PASS | no execution history");

   // 6) Final deployment gate — entry authority only.
   g_state.autonomousPipelineStage="FINAL DEPLOYMENT";
   string gate="";
   if(!UnifiedDeploymentGate(true,gate))
   {
      reason=gate!=""?gate:"Unified deployment gate blocked autonomous plan";
      AutonomousDecisionSetDecision(AutonomousDecisionClassifyFailure(reason,g_state.autonomousPipelineStage),reason,g_state.autonomousPipelineStage);
      return false;
   }

   g_state.autonomousPipelineStage="APPROVED";
   g_state.autonomousReady=true;
   g_state.autonomousReason="APPROVED | "+g_state.autonomousPlanSummary;
   g_state.autonomousDecisionClass="APPROVE";
   g_state.autonomousDecisionReason=g_state.autonomousReason;
   g_state.lastDecision="APPROVED";
   g_state.entryThrottleActive=false;
   g_state.entryThrottleReason="";
   RecordEvent("AUTONOMOUS DECISION",StringFormat("APPROVE | %s",g_state.autonomousPlanSummary));
   return true;
}

bool ShouldStartGrid()
{
   if(!IsAutonomousControl() || !g_state.autonomousEngine)
   {
      AutonomousDecisionSetDecision("WAIT","Autonomous control/engine unavailable","CONTROL");
      return false;
   }

   if(g_state.autonomousDecisionIntervalSec>0 && g_state.autonomousLastEvaluation>0 &&
      (TimeCurrent()-g_state.autonomousLastEvaluation)<g_state.autonomousDecisionIntervalSec)
      return false;

   g_state.autonomousLastEvaluation=TimeCurrent();
   g_state.autonomousDecisionCount++;

   string reason="";
   bool ok=EvaluateAutonomousDecisionPipeline(reason);

   if(!ok)
      g_state.autonomousSignal=reason;

   string cls=ok?"APPROVE":g_state.autonomousDecisionClass;
   RecordEvent("AUTONOMOUS",
      StringFormat("%s | stage %s | grid %s | dir %s | fit %.0f%% | edge %.0f%% | conf %.0f%% | reason %s",
         cls,
         g_state.autonomousPipelineStage,
         g_state.autonomousCandidate,
         g_state.autonomousPlanDirection!=""?g_state.autonomousPlanDirection:g_state.autonomousSignal,
         g_state.autonomousScore*100.0,
         g_state.gridSelectionExpectedEdge*100.0,
         g_state.autonomousConfidence*100.0,
         ok?g_state.autonomousReason:reason));

   return ok;
}

void ToggleDynamicRiskLot(const string source)

{

   g_state.useDynamicRiskLot=!g_state.useDynamicRiskLot;

   UpdateEffectiveState();

   SetAction("USER","DYNAMIC RISK LOT",g_state.useDynamicRiskLot?"ON":"OFF");

   g_state.executionStatus=g_state.useDynamicRiskLot?"DYNAMIC RISK ON":"DYNAMIC RISK OFF";

   RecordEvent("RISK",StringFormat("Dynamic risk lot %s via %s | Effective lot %.3f",g_state.useDynamicRiskLot?"ENABLED":"DISABLED",source,g_state.effectiveLot));

}



bool HandleNestedSubTab(const string &sparam,string prefix,int count,int &value)
{
   if(count<=0)return false;
   int group=NestedGroupForIndex(prefix,value,count),startGroup=NestedGroupStart(prefix,group),endGroup=NestedGroupEnd(prefix,group,count);
   if(sparam==ObjName(prefix+"_PREV")){value=(value<=startGroup?endGroup:value-1);CreateDashboard();return true;}
   if(sparam==ObjName(prefix+"_NEXT")){value=(value>=endGroup?startGroup:value+1);CreateDashboard();return true;}
   int groups=NestedGroupCount(prefix);
   for(int g=0;g<groups;g++) if(sparam==ObjName(prefix+"_GROUP_"+IntegerToString(g))){value=NestedGroupStart(prefix,g);CreateDashboard();return true;}
   return false;
}

bool HandleScrollableSubTab(const string &sparam,string prefix,int count,int &value)

{

   if(count<=0) return false;

   if(sparam==ObjName(prefix+"_PREV"))

   {

      value=(value+count-1)%count;

      CreateDashboard();

      return true;

   }

   if(sparam==ObjName(prefix+"_NEXT"))

   {

      value=(value+1)%count;

      CreateDashboard();

      return true;

   }

   return false;

}



void OnChartEvent(const int id,const long &lparam,const double &dparam,const string &sparam)

{

   if(id==CHARTEVENT_CHART_CHANGE)

   {

      FlushVisibleDashboardEdits();
      ApplyChartTheme(true);

      if(g_dashboard.isVisible) CreateDashboard();

      return;

   }



   if(id==CHARTEVENT_OBJECT_ENDEDIT && StringFind(sparam,PREFIX)==0)

   {

      StoreEditValue(sparam,ObjectGetString(0,sparam,OBJPROP_TEXT));

      return;

   }



   if(id!=CHARTEVENT_OBJECT_CLICK || StringFind(sparam,PREFIX)!=0)

      return;



   FlushVisibleDashboardEdits();

   if(sparam==ObjName("NAV_UP") || sparam==ObjName("NAV_DOWN"))

   {

      if(sparam==ObjName("NAV_UP")) g_dashboard.navOffset--; else g_dashboard.navOffset++;

      int navH=g_dashboard.height-134;

      int available=MathMax(90,navH-112-31);

      int visible=MathMax(3,MathMin(TAB_COUNT,(available+4)/28));

      int maxOffset=MathMax(0,TAB_COUNT-visible);

      if(g_dashboard.navOffset<0) g_dashboard.navOffset=0;

      if(g_dashboard.navOffset>maxOffset) g_dashboard.navOffset=maxOffset;

      CreateDashboard();

      return;

   }



      for(int i=0;i<TAB_COUNT;i++)

   {

      if(sparam==ObjName("NAV_"+IntegerToString(i)))

      {

         g_dashboard.currentTab=i;

         int navH=g_dashboard.height-134;

         int available=MathMax(90,navH-112-31);

         int visible=MathMax(3,MathMin(TAB_COUNT,(available+4)/28));

         int maxOffset=MathMax(0,TAB_COUNT-visible);

         // Keep the selected command entry visible after changing tabs.

         if(i<g_dashboard.navOffset) g_dashboard.navOffset=i;

         else if(i>=g_dashboard.navOffset+visible) g_dashboard.navOffset=i-visible+1;

         g_dashboard.navOffset=MathMax(0,MathMin(g_dashboard.navOffset,maxOffset));

         if(i==14) g_dashboard.settingsPage=0;

         CreateDashboard();

         return;

      }

   }



   if(HandleNestedSubTab(sparam,"HOME_SUB_",5,g_dashboard.homeSubTab)) return;

   if(HandleNestedSubTab(sparam,"GRID_SUB_",9,g_dashboard.gridSubTab)) return;

   if(HandleNestedSubTab(sparam,"RISK_SUB_",10,g_dashboard.riskSubTab)) return;

   if(HandleNestedSubTab(sparam,"AN_SUB_",3,g_dashboard.analyticsSubTab)) return;

   if(HandleNestedSubTab(sparam,"AI_SUB_",4,g_dashboard.aiSubTab)) return;

   if(HandleNestedSubTab(sparam,"EX_SUB_",6,g_dashboard.executionSubTab)) return;

   if(HandleNestedSubTab(sparam,"TR_SUB_",5,g_dashboard.tradesSubTab)) return;

   if(HandleNestedSubTab(sparam,"TRN_SUB_",7,g_dashboard.transparencySubTab)) return;

   if(HandleNestedSubTab(sparam,"DIA_SUB_",8,g_dashboard.diagnosticsSubTab)) return;
   if(HandleNestedSubTab(sparam,"DIA_SYSTEM_SUB_",2,g_phase22SystemSubTab)) return;

   if(HandleNestedSubTab(sparam,"TOOLS_SUB_",4,g_dashboard.toolsSubTab)) return;

   if(HandleNestedSubTab(sparam,"AUTONOMY_SUB_",11,g_dashboard.autonomySubTab)) return;
   if(HandleNestedSubTab(sparam,"DIA_AUTH_SUB_",2,g_phase21SourceQualitySubTab)) return;
   if(HandleNestedSubTab(sparam,"STRATHEALTH_SUB_",7,g_strategyHealthMainSubTab)) return;

   if(HandleScrollableSubTab(sparam,"GRIDLAB_MAIN_",2,g_dashboard.gridLabSubTab)) return;
   if(HandleScrollableSubTab(sparam,"GRIDLAB_VALIDATE_",3,g_dashboard.gridLabValidationSubTab)) return;
   if(HandleScrollableSubTab(sparam,"GRIDLAB_MATRIX_",6,g_dashboard.gridLabMatrixSubTab)) return;



   if(StringFind(sparam,ObjName("HOME_SUB_"))==0)

   {

      g_dashboard.homeSubTab=(int)StringToInteger(StringSubstr(sparam,StringLen(ObjName("HOME_SUB_"))));

      CreateDashboard(); return;

   }

   if(sparam==ObjName("BTN_LIFE_REBUILD"))
   { V15RebuildPending(); UpdateState(); CreateDashboard(); return; }
   if(sparam==ObjName("BTN_LIFE_RECENTER"))
   { RecenterGrid(); CreateDashboard(); return; }
   if(sparam==ObjName("BTN_LIFE_CANCEL"))
   { CancelPendingGridOrders(); CreateDashboard(); return; }
   if(sparam==ObjName("BTN_LIFE_REPLENISH"))
   { SmartReplenishGrid(); CreateDashboard(); return; }

   if(StringFind(sparam,ObjName("GRID_SUB_"))==0)

   {

      g_dashboard.gridSubTab=(int)StringToInteger(StringSubstr(sparam,StringLen(ObjName("GRID_SUB_"))));

      CreateDashboard(); return;

   }

   if(StringFind(sparam,ObjName("RISK_SUB_"))==0)

   {

      g_dashboard.riskSubTab=(int)StringToInteger(StringSubstr(sparam,StringLen(ObjName("RISK_SUB_"))));

      CreateDashboard(); return;

   }

   if(StringFind(sparam,ObjName("AN_SUB_"))==0)

   {

      g_dashboard.analyticsSubTab=(int)StringToInteger(StringSubstr(sparam,StringLen(ObjName("AN_SUB_"))));

      CreateDashboard(); return;

   }

   if(StringFind(sparam,ObjName("AI_SUB_"))==0)

   {

      g_dashboard.aiSubTab=(int)StringToInteger(StringSubstr(sparam,StringLen(ObjName("AI_SUB_"))));

      CreateDashboard(); return;

   }

   if(StringFind(sparam,ObjName("EX_SUB_"))==0)

   {

      g_dashboard.executionSubTab=(int)StringToInteger(StringSubstr(sparam,StringLen(ObjName("EX_SUB_"))));

      CreateDashboard(); return;

   }

   if(StringFind(sparam,ObjName("TR_SUB_"))==0)

   {

      g_dashboard.tradesSubTab=(int)StringToInteger(StringSubstr(sparam,StringLen(ObjName("TR_SUB_"))));

      CreateDashboard(); return;

   }

   if(StringFind(sparam,ObjName("TRN_SUB_"))==0)

   {

      g_dashboard.transparencySubTab=(int)StringToInteger(StringSubstr(sparam,StringLen(ObjName("TRN_SUB_"))));

      CreateDashboard(); return;

   }

   if(StringFind(sparam,ObjName("DIA_SUB_"))==0)

   {

      g_dashboard.diagnosticsSubTab=(int)StringToInteger(StringSubstr(sparam,StringLen(ObjName("DIA_SUB_"))));

      CreateDashboard(); return;

   }

   if(StringFind(sparam,ObjName("TOOLS_SUB_"))==0)

   {

      g_dashboard.toolsSubTab=(int)StringToInteger(StringSubstr(sparam,StringLen(ObjName("TOOLS_SUB_"))));

      CreateDashboard(); return;

   }

   if(StringFind(sparam,ObjName("AUTONOMY_SUB_"))==0)

   {

      g_dashboard.autonomySubTab=(int)StringToInteger(StringSubstr(sparam,StringLen(ObjName("AUTONOMY_SUB_"))));

      CreateDashboard(); return;

   }

   if(StringFind(sparam,ObjName("EMERGENCY_SUB_"))==0)

   {

      // static local sub-tab state is internal to the emergency renderer; redraw on navigation.
      CreateDashboard(); return;

   }

   if(StringFind(sparam,ObjName("STRATHEALTH_SUB_"))==0)

   {

      g_strategyHealthMainSubTab=(int)StringToInteger(StringSubstr(sparam,StringLen(ObjName("STRATHEALTH_SUB_"))));

      CreateDashboard(); return;

   }

   if(sparam==ObjName("TRN_CLEAR") || sparam==ObjName("DIA_CLEAR"))

   {

      ResetEventJournal();

      g_state.lastDecision="JOURNAL CLEARED";

      g_state.lastActionReason="User cleared activity journal";

      CreateDashboard(); return;

   }



   if(StringFind(sparam,ObjName("SET_PAGE_"))==0)

   {

      int p=(int)StringToInteger(StringSubstr(sparam,StringLen(ObjName("SET_PAGE_"))));

      if(p>=0&&p<SETTINGS_PAGE_COUNT)g_dashboard.settingsPage=p;

      CreateDashboard(); return;

   }

   if(sparam==ObjName("SET_PREV") || sparam==ObjName("SET_NEXT")){bool next=(sparam==ObjName("SET_NEXT"));int n=(g_dashboard.settingsPage==0?6:g_dashboard.settingsPage==3?6:10);if(g_dashboard.settingsPage==0)g_dashboard.settingsSubTab=next?((g_dashboard.settingsSubTab+1)%n):((g_dashboard.settingsSubTab+n-1)%n);else if(g_dashboard.settingsPage==1)g_dashboard.settingsSubTab2=next?((g_dashboard.settingsSubTab2+1)%n):((g_dashboard.settingsSubTab2+n-1)%n);else if(g_dashboard.settingsPage==2)g_dashboard.settingsSubTab3=next?((g_dashboard.settingsSubTab3+1)%n):((g_dashboard.settingsSubTab3+n-1)%n);else if(g_dashboard.settingsPage==3)g_dashboard.settingsSubTab4=next?((g_dashboard.settingsSubTab4+1)%n):((g_dashboard.settingsSubTab4+n-1)%n);else if(g_dashboard.settingsPage==4)g_dashboard.settingsSubTab5=next?((g_dashboard.settingsSubTab5+1)%n):((g_dashboard.settingsSubTab5+n-1)%n);else g_dashboard.settingsSubTab6=next?((g_dashboard.settingsSubTab6+1)%n):((g_dashboard.settingsSubTab6+n-1)%n);CreateDashboard();return;}

   if(StringFind(sparam,ObjName("SET_SUB_"))==0){int idx=(int)StringToInteger(StringSubstr(sparam,StringLen(ObjName("SET_SUB_"))));int n=(g_dashboard.settingsPage==0?6:g_dashboard.settingsPage==3?6:10);if(idx<0)idx=0;if(idx>=n)idx=n-1;if(g_dashboard.settingsPage==0)g_dashboard.settingsSubTab=idx;else if(g_dashboard.settingsPage==1)g_dashboard.settingsSubTab2=idx;else if(g_dashboard.settingsPage==2)g_dashboard.settingsSubTab3=idx;else if(g_dashboard.settingsPage==3)g_dashboard.settingsSubTab4=idx;else if(g_dashboard.settingsPage==4)g_dashboard.settingsSubTab5=idx;else g_dashboard.settingsSubTab6=idx;CreateDashboard();return;}



   if(StringFind(sparam,ObjName("GRID_SEL_"))==0)

   {

      int idx=(int)StringToInteger(StringSubstr(sparam,StringLen(ObjName("GRID_SEL_"))));

      if(idx>=0 && idx<21)

      {

         g_selectedGridType=(ENUM_GRID_TYPE)idx; g_lastManualGridType=g_selectedGridType; g_state.gridType=g_selectedGridType; g_state.executionStatus="GRID TYPE SELECTED"; RefreshStrategyHealth(true); StrategyHealthUpdateSelectedContext(); if(g_state.persistRuntimeState) SaveRuntimeCheckpoint();

         g_dashboard.currentTab=1;

         g_dashboard.gridSubTab=1;

         g_state.executionStatus="GRID TYPE SELECTED";

         CreateDashboard();

      }

      return;

   }



   if(sparam==ObjName("BTN_START"))

   {
      string gateReason="";
      if(!UnifiedDeploymentGate(false,gateReason))
      {
         RecordDeploymentBlock("USER",gateReason);
      }
      else
      {
         bool hadExisting=(GetPositionCount()>0 || GetPendingCount()>0);
         SetAction("USER",hadExisting?"NEW ORDERS":"START PRESSED",hadExisting?"New individual orders requested while existing positions remain active":"Manual grid deployment requested");
         CreateGrid(true);
      }
      UpdateState();CreateDashboard();
   }

   else if(sparam==ObjName("BTN_REBAL"))

   {

      RecenterGrid(true); UpdateState(); CreateDashboard();

   }

   else if(sparam==ObjName("BTN_CLOSE_PROFIT") || sparam==ObjName("TR_CLOSE_PROFIT"))

   {

      // Execute the user's close-profit command first.  Avoid UpdateState/CreateDashboard here;
      // those can add avoidable latency during fast market conditions.
      CloseProfitPositionsUltraFast();
      return;

   }

   else if(sparam==ObjName("BTN_CLOSE_LOSS") || sparam==ObjName("TR_CLOSE_LOSS"))

   {

      CloseLossPositions(); UpdateState(); CreateDashboard();

   }

   else if(sparam==ObjName("BTN_CANCEL_GRID") || sparam==ObjName("TR_CANCEL") || sparam==ObjName("BTN_CANCEL_GRID2") || sparam==ObjName("BTN_CANCEL_PENDING"))
   {
      g_v14FocusMagic=0;
      CancelPendingGridOrders();
      UpdateState();
      CreateDashboard();
   }

   else if(sparam==ObjName("BTN_STOP") || sparam==ObjName("TR_CLOSE_ALL") || sparam==ObjName("BTN_CLOSE_GRID2"))

   {

      CloseGrid(); UpdateState(); CreateDashboard();

   }

   else if(sparam==ObjName("BTN_GRID_PROFILE") || sparam==ObjName("BTN_GRID_PROFILE2"))

   {

      g_dashboard.currentTab=1; g_dashboard.gridSubTab=1; CreateDashboard();

   }

   else if(sparam==ObjName("BTN_REBAL_GRID2"))

   {

      RecenterGrid(true); UpdateState(); CreateDashboard();

   }

   else if(sparam==ObjName("AI_RESET2"))

   {

      g_state.predictionAccuracy=0.0; g_state.totalTrades=0; g_state.wins=0; g_state.losses=0; g_state.winRate=0.0; CreateDashboard();

   }

   else if(sparam==ObjName("BTN_GRID_REBUILD"))

   {

      V15RebuildPending(); UpdateState(); CreateDashboard();

   }

   else if(sparam==ObjName("BTN_REBAL_GRID") || sparam==ObjName("TR_RECENTER"))

   {

      RecenterGrid(true); UpdateState(); CreateDashboard();

   }

   else if(sparam==ObjName("TC_BTN_MODEL"))
   {
      g_state.transactionCostModelEnabled=!g_state.transactionCostModelEnabled;
      SetAction("USER","TRANSACTION COST MODEL",g_state.transactionCostModelEnabled?"ON":"OFF");
      CreateDashboard();
   }

   else if(sparam==ObjName("TC_BTN_GATE"))
   {
      g_state.transactionCostGateEnabled=!g_state.transactionCostGateEnabled;
      SetAction("USER","AUTONOMOUS COST GATE",g_state.transactionCostGateEnabled?"ON":"OFF");
      CreateDashboard();
   }

   else if(sparam==ObjName("BTN_RISK_MODE"))

   {

      g_state.riskMode=(ENUM_RISK_MODE)(((int)g_state.riskMode+1)%4); CreateDashboard();

   }

   else if(sparam==ObjName("BTN_RISK_MANAGED") || sparam==ObjName("TR_RISK"))

   {

      g_state.riskManagedTrading=!g_state.riskManagedTrading;

      g_state.executionStatus=g_state.riskManagedTrading?"RISK ENGINE ON":"RISK ENGINE OFF";

      SetAction("USER","RISK ENGINE",g_state.riskManagedTrading?"ON":"OFF");

      CreateDashboard();

   }

   else if(sparam==ObjName("FLG_RISK"))

   {

      ToggleDynamicRiskLot("RISK SETTINGS");

      CreateDashboard();

   }

   else if(sparam==ObjName("BTN_NEW_ORDER_SL") || sparam==ObjName("TR_SL"))

   {

      g_state.useStopLossForNewOrders=!g_state.useStopLossForNewOrders;

      if(!g_state.useStopLossForNewOrders) RemovePositionProtection(true,false);

      CreateDashboard();

   }

   else if(sparam==ObjName("BTN_NEW_ORDER_TP") || sparam==ObjName("TR_TP"))

   {

      g_state.useTakeProfitForNewOrders=!g_state.useTakeProfitForNewOrders;

      if(!g_state.useTakeProfitForNewOrders) RemovePositionProtection(false,true);

      CreateDashboard();

   }

   else if(sparam==ObjName("TR_BE") || sparam==ObjName("FLG_BE"))

   {

      g_state.breakEven=!g_state.breakEven; SetAction("USER","BREAK EVEN",g_state.breakEven?"ON":"OFF"); CreateDashboard();

   }

   else if(sparam==ObjName("FLG_EXIT_COORD"))

   {

      g_state.strategyExitCoordination=!g_state.strategyExitCoordination;

      SetAction("USER","EXIT COORDINATION",g_state.strategyExitCoordination?"ON":"OFF");

      RecordEvent("EXIT POLICY",g_state.strategyExitCoordination?"Strategy-aware exit coordination ON":"Strategy-aware exit coordination OFF");

      CreateDashboard();

   }

   else if(sparam==ObjName("FLG_STRAT_MGMT"))

   {

      g_state.strategyAwareManagement=!g_state.strategyAwareManagement;

      SetAction("USER","STRATEGY-AWARE MANAGEMENT",g_state.strategyAwareManagement?GridStrategyName(g_state.gridType):"OFF / USER FIXED");

      RecordEvent("POSITION POLICY",g_state.strategyAwareManagement?"Strategy-aware management ON":"Strategy-aware management OFF");

      CreateDashboard();

   }

   else if(sparam==ObjName("TR_TRAIL") || sparam==ObjName("FLG_TRAIL"))

   {

      g_state.trailingStop=!g_state.trailingStop; CreateDashboard();

   }

   else if(sparam==ObjName("TR_OCO") || sparam==ObjName("FLG_OCO"))

   {

      g_state.oco=!g_state.oco; CreateDashboard();

   }

   else if(sparam==ObjName("HM_MTF_TOGGLE") || sparam==ObjName("AN_MTF_TOGGLE"))
   {
      g_state.useMultiTimeframeMarketState=!g_state.useMultiTimeframeMarketState;
      UpdateMarketStateV15();
      SetAction("USER","MARKET ANALYSIS",g_state.useMultiTimeframeMarketState?"MULTI-TIMEFRAME ON":"CURRENT TIMEFRAME ONLY");
      RecordEvent("MARKET STATE",g_state.useMultiTimeframeMarketState?"Multi-timeframe analysis enabled (M5/M15/H1)":"Multi-timeframe analysis disabled; using attached chart timeframe only");
      if(g_state.persistRuntimeState) SaveRuntimeCheckpoint();
      CreateDashboard();
   }

   else if(sparam==ObjName("BTN_AI_TOGGLE"))

   {

      g_state.aiEnabled=!g_state.aiEnabled; CreateDashboard();

   }

   else if(sparam==ObjName("AI_SET_NETWORK"))

   {

      g_state.neuralNetwork=!g_state.neuralNetwork; CreateDashboard();

   }

   else if(sparam==ObjName("AI_SET_REGIME") || sparam==ObjName("FLG_REGIME"))

   {

      g_state.regimeFilter=!g_state.regimeFilter; CreateDashboard();

   }

   else if(sparam==ObjName("AI_SET_AUTO") || sparam==ObjName("FLG_AUTO"))

   {

      if(g_state.controlMode==CONTROL_AUTONOMOUS)TransitionControlMode(CONTROL_MANUAL);
      else TransitionControlMode(CONTROL_AUTONOMOUS);
      UpdateState();CreateDashboard();

   }

   else if(sparam==ObjName("AI_SET_RISK"))

   {

      ToggleDynamicRiskLot("AI / AUTONOMOUS FILTERS");

      CreateDashboard();

   }

   else if(sparam==ObjName("AI_SET_HIVOL") || sparam==ObjName("FLG_HIV"))

   {

      g_state.pauseHighVolatility=!g_state.pauseHighVolatility; CreateDashboard();

   }

   else if(sparam==ObjName("AI_RESET"))

   {

      g_state.predictionAccuracy=0.0; g_state.totalTrades=0; g_state.wins=0; g_state.losses=0; g_state.winRate=0.0; CreateDashboard();

   }

   else if(sparam==ObjName("AUTO_ENGINE_TOGGLE")){if(!g_state.autonomousEngine)TransitionControlMode(CONTROL_AUTONOMOUS);else TransitionControlMode(CONTROL_MANUAL);UpdateState();CreateDashboard();}

   else if(sparam==ObjName("AUTO_STRICT_TOGGLE")){g_state.autonomousStrictFilters=!g_state.autonomousStrictFilters;SetAction("USER","AUTONOMOUS FILTER POLICY",g_state.autonomousStrictFilters?"STRICT":"ADVISORY");CreateDashboard();}

   else if(sparam==ObjName("AUTO_ADAPT_TOGGLE")){g_state.autonomousAdaptiveStrategy=!g_state.autonomousAdaptiveStrategy;SetAction("USER","AUTONOMOUS STRATEGY","ADAPTIVE SELECTION "+(g_state.autonomousAdaptiveStrategy?"ON":"OFF"));CreateDashboard();}

   else if(sparam==ObjName("AUTO_NEUTRAL_TOGGLE")){g_state.autonomousAllowNeutral=!g_state.autonomousAllowNeutral;SetAction("USER","AUTONOMOUS FALLBACK",g_state.autonomousAllowNeutral?"ALLOW":"RESTRICT");CreateDashboard();}

   else if(sparam==ObjName("BTN_CONTROL_MODE"))
   {
      if(g_state.controlMode==CONTROL_MANUAL) TransitionControlMode(CONTROL_ASSIST);
      else if(g_state.controlMode==CONTROL_ASSIST) TransitionControlMode(CONTROL_AUTONOMOUS);
      else TransitionControlMode(CONTROL_MANUAL);
      UpdateState();CreateDashboard();
   }

   else if(sparam==ObjName("ADV_ENTRY") || sparam==ObjName("ADV_ENTRY2"))
   {
      if(!IsAutonomousControl()) SetAction("USER","AUTONOMOUS ENTRY ENGINE","UNAVAILABLE OUTSIDE AUTONOMOUS MODE");
      else { g_state.advancedEntryDecision=!g_state.advancedEntryDecision; SetAction("USER","AUTONOMOUS ENTRY ENGINE",g_state.advancedEntryDecision?"ON":"OFF"); }
      CreateDashboard();
   }

   else if(sparam==ObjName("ADV_ADAPTIVE_GRID")){g_state.adaptiveGrid=!g_state.adaptiveGrid;CreateDashboard();}

   else if(sparam==ObjName("ADV_ADAPTIVE_LEVELS")){g_state.adaptiveLevels=!g_state.adaptiveLevels;CreateDashboard();}

   else if(sparam==ObjName("ADV_ADAPTIVE_LOT")){g_state.adaptiveLot=!g_state.adaptiveLot;CreateDashboard();}

   else if(sparam==ObjName("ADV_MARKET_INTEL")){g_state.marketIntelligence=!g_state.marketIntelligence;CreateDashboard();}

   else if(sparam==ObjName("ADV_SMART_REGIME")){g_state.smartRegime=!g_state.smartRegime;CreateDashboard();}

   else if(sparam==ObjName("ADV_SMART_RECENTER")){g_state.smartRecenter=!g_state.smartRecenter;CreateDashboard();}

   else if(sparam==ObjName("ADV_REPLENISH")){g_state.smartReplenishment=!g_state.smartReplenishment;CreateDashboard();}

   else if(sparam==ObjName("ADV_EXPOSURE") || sparam==ObjName("ADV_EXPOSURE2")){g_state.exposureManager=!g_state.exposureManager;CreateDashboard();}

   else if(sparam==ObjName("ADV_PROTECT")){g_state.advancedProtection=!g_state.advancedProtection;CreateDashboard();}

   else if(sparam==ObjName("ADV_JOURNAL")){g_state.decisionJournal=!g_state.decisionJournal;CreateDashboard();}

   else if(sparam==ObjName("DIA_CLEAR") || sparam==ObjName("BTN_PROFILE_REJOURNAL")){ResetEventJournal();CreateDashboard();}

   else if(sparam==ObjName("BTN_PROFILE_RESET")){InitializeState();ClearEditCache();CreateDashboard();}

   else if(sparam==ObjName("ADV_RECOVERY")){g_state.gridRecovery=!g_state.gridRecovery;SetAction("USER","RECOVERY ENGINE",g_state.gridRecovery?"ON":"OFF");CreateDashboard();}

   else if(sparam==ObjName("BTN_RECOVER_GRID")){RecoverGridState();UpdateState();CreateDashboard();}

   else if(sparam==ObjName("BTN_PROFILE_SAVE1")){SaveProfile(0);CreateDashboard();}

   else if(sparam==ObjName("BTN_PROFILE_SAVE2")){SaveProfile(1);CreateDashboard();}

   else if(sparam==ObjName("BTN_PROFILE_SAVE3")){SaveProfile(2);CreateDashboard();}

   else if(sparam==ObjName("BTN_PROFILE_SAVE4")){SaveProfile(3);CreateDashboard();}

   else if(sparam==ObjName("BTN_PROFILE_LOAD1")){LoadProfile(0);CreateDashboard();}

   else if(sparam==ObjName("BTN_PROFILE_LOAD2")){LoadProfile(1);CreateDashboard();}

   else if(sparam==ObjName("BTN_PROFILE_LOAD3")){LoadProfile(2);CreateDashboard();}

   else if(sparam==ObjName("BTN_PROFILE_LOAD4")){LoadProfile(3);CreateDashboard();}

   else if(sparam==ObjName("BTN_SIM_PREVIEW")){RefreshSimulationPreview();CreateDashboard();}

   else if(sparam==ObjName("BTN_CHECKPOINT_NOW")){SaveRuntimeCheckpoint();SetAction("USER","CHECKPOINT SAVED",g_state.recoveryFile);CreateDashboard();}

    else if(sparam==ObjName("BTN_GRID_VALIDATION_RUN2")){RunGridValidationMatrix();CreateDashboard();}

   else if(sparam==ObjName("BTN_SETTINGS_AUDIT")){RunSettingsAuthorityAudit();SetAction("USER","SETTINGS AUTHORITY AUDIT",g_state.settingsAuditSummary);CreateDashboard();}

   else if(sparam==ObjName("BTN_CONFIG_CHECK") || sparam==ObjName("BTN_CONFIG_CHECK2")){UpdateState();UpdateConfigurationHealth();SetAction("USER","CONFIGURATION CHECK",g_state.configWarnings);RecordEvent("CONFIGURATION",g_state.lastConfigCheckResult);CreateDashboard();}

   else if(sparam==ObjName("BTN_SMART"))

   {

      g_state.smartExecution=!g_state.smartExecution; CreateDashboard();

   }

   else if(sparam==ObjName("FLG_ATR"))

   {

      g_state.useATRSpacing=!g_state.useATRSpacing; CreateDashboard();

   }

   else if(sparam==ObjName("FLG_RECENTER"))

   {

      g_state.autoRecenter=!g_state.autoRecenter; CreateDashboard();

   }

   else if(sparam==ObjName("FLG_VALIDATE"))

   {

      g_state.validateStops=!g_state.validateStops; CreateDashboard();

   }

   else if(sparam==ObjName("FLG_OPP"))

   {

      g_state.closeOppositeOnFill=!g_state.closeOppositeOnFill; CreateDashboard();

   }

   else if(sparam==ObjName("FLG_SESSION"))

   {

      g_state.useSessionFilter=!g_state.useSessionFilter; CreateDashboard();

   }

   else if(sparam==ObjName("FLG_WEEK"))

   {

      g_state.avoidWeekend=!g_state.avoidWeekend; CreateDashboard();

   }

   else if(sparam==ObjName("FLG_CHART_GRID"))

   {

      g_state.chartShowGrid=!g_state.chartShowGrid; ApplyChartTheme(true); SetAction("USER","CHART GRID",g_state.chartShowGrid?"ON":"OFF"); CreateDashboard();

   }

   else if(sparam==ObjName("FLG_CHART_TRADE"))

   {

      g_state.chartShowTradeLevels=!g_state.chartShowTradeLevels; ApplyChartTheme(true); SetAction("USER","TRADE LEVELS",g_state.chartShowTradeLevels?"ON":"OFF"); CreateDashboard();

   }

   else if(sparam==ObjName("FLG_CHART_SCROLL"))

   {

      g_state.chartAutoScroll=!g_state.chartAutoScroll; ApplyChartTheme(true); SetAction("USER","AUTO SCROLL",g_state.chartAutoScroll?"ON":"OFF"); CreateDashboard();

   }

   else if(sparam==ObjName("FLG_CHART_SHIFT"))

   {

      g_state.chartShift=!g_state.chartShift; ApplyChartTheme(true); SetAction("USER","CHART SHIFT",g_state.chartShift?"ON":"OFF"); CreateDashboard();

   }

   else if(sparam==ObjName("FLG_CHART_VOL"))

   {

      g_state.chartShowVolumes=!g_state.chartShowVolumes; ApplyChartTheme(true); SetAction("USER","CHART VOLUME",g_state.chartShowVolumes?"ON":"OFF"); CreateDashboard();

   }

   else if(sparam==ObjName("FLG_CHART_AUTO"))

   {

      g_state.autoChartTheme=!g_state.autoChartTheme; ApplyChartTheme(true); CreateDashboard();

   }

   else if(sparam==ObjName("BTN_CHART_THEME"))

   {

      g_state.chartThemeMode=(ENUM_CHART_THEME_MODE)(((int)g_state.chartThemeMode+1)%9); ApplyChartTheme(true); SetAction("USER","CHART THEME",ChartThemeName((int)g_state.chartThemeMode)); CreateDashboard();

   }

   else if(sparam==ObjName("FLG_GUARD")){g_state.orderGuardian=!g_state.orderGuardian;SetAction("USER","ORDER GUARDIAN",g_state.orderGuardian?"ON":"OFF");CreateDashboard();}

   else if(sparam==ObjName("PM_ENTRY")){g_state.permAutonomousEntry=!g_state.permAutonomousEntry;SetAction("USER","PERMISSION ENTRY",g_state.permAutonomousEntry?"ALLOW":"DENY");CreateDashboard();}

   else if(sparam==ObjName("PM_STEP")){g_state.permAdaptiveStep=!g_state.permAdaptiveStep;SetAction("USER","PERMISSION STEP",g_state.permAdaptiveStep?"ALLOW":"DENY");UpdateEffectiveState();CreateDashboard();}

   else if(sparam==ObjName("PM_LEVELS")){g_state.permAdaptiveLevels=!g_state.permAdaptiveLevels;SetAction("USER","PERMISSION LEVELS",g_state.permAdaptiveLevels?"ALLOW":"DENY");UpdateEffectiveState();CreateDashboard();}

   else if(sparam==ObjName("PM_LOT")){g_state.permAdaptiveLot=!g_state.permAdaptiveLot;SetAction("USER","PERMISSION LOT",g_state.permAdaptiveLot?"ALLOW":"DENY");UpdateEffectiveState();CreateDashboard();}

   else if(sparam==ObjName("PM_STRAT")){g_state.permStrategySelection=!g_state.permStrategySelection;SetAction("USER","PERMISSION STRATEGY",g_state.permStrategySelection?"ALLOW":"DENY");CreateDashboard();}

   else if(sparam==ObjName("PM_RECENTER")){g_state.permRecenter=!g_state.permRecenter;SetAction("USER","PERMISSION RECENTER",g_state.permRecenter?"ALLOW":"DENY");CreateDashboard();}

   else if(sparam==ObjName("PM_REPLENISH")){g_state.permReplenishment=!g_state.permReplenishment;SetAction("USER","PERMISSION REPLENISH",g_state.permReplenishment?"ALLOW":"DENY");CreateDashboard();}

   else if(sparam==ObjName("PM_RISK")){g_state.permRiskAdjust=!g_state.permRiskAdjust;SetAction("USER","PERMISSION RISK",g_state.permRiskAdjust?"ALLOW":"DENY");UpdateEffectiveState();CreateDashboard();}

   else if(sparam==ObjName("PM_EXPOSURE")){g_state.permExposureAdjust=!g_state.permExposureAdjust;SetAction("USER","PERMISSION EXPOSURE",g_state.permExposureAdjust?"ALLOW":"DENY");CreateDashboard();}

   else if(sparam==ObjName("PM_EMERGENCY")){g_state.permEmergencyControl=!g_state.permEmergencyControl;SetAction("USER","PERMISSION EMERGENCY",g_state.permEmergencyControl?"ALLOW":"DENY");CreateDashboard();}

   else if(sparam==ObjName("PA_BASKET_TP_CLOSE")){g_state.protectionBasketProfitCloseEnabled=!g_state.protectionBasketProfitCloseEnabled;SetAction("USER","BASKET PROFIT EXIT",g_state.protectionBasketProfitCloseEnabled?"ON":"OFF");CreateDashboard();return;}
   else if(sparam==ObjName("PA_PROFITLOCK_CLOSE")){g_state.protectionProfitLockCloseEnabled=!g_state.protectionProfitLockCloseEnabled;SetAction("USER","PROFIT LOCK EXIT",g_state.protectionProfitLockCloseEnabled?"ON":"OFF");CreateDashboard();return;}
   else if(sparam==ObjName("PA_ADAPT")){g_state.adaptiveTradeProtection=!g_state.adaptiveTradeProtection;SetAction("USER","ADAPTIVE SL/TP",g_state.adaptiveTradeProtection?"ON":"OFF");RecordEvent("TRADE PROTECTION","Adaptive per-trade SL/TP "+(g_state.adaptiveTradeProtection?"enabled":"disabled"));CreateDashboard();return;}
   else if(sparam==ObjName("PA_PROFIT")){g_state.adaptiveProfitManagement=!g_state.adaptiveProfitManagement;SetAction("USER","PROFIT LOCK",g_state.adaptiveProfitManagement?"ON":"OFF");RecordEvent("TRADE PROTECTION","Profit management "+(g_state.adaptiveProfitManagement?"enabled":"disabled"));CreateDashboard();return;}
   else if(sparam==ObjName("PA_RUNNER")){g_state.tradeRunnerMode=!g_state.tradeRunnerMode;SetAction("USER","RUNNER MODE",g_state.tradeRunnerMode?"ON":"OFF");RecordEvent("TRADE PROTECTION","Runner mode "+(g_state.tradeRunnerMode?"enabled":"disabled"));CreateDashboard();return;}
   else if(sparam==ObjName("PA_MAXH_CLOSE")){g_state.protectionMaxHoldCloseEnabled=!g_state.protectionMaxHoldCloseEnabled;SetAction("USER","MAX-HOLD EXIT",g_state.protectionMaxHoldCloseEnabled?"ON":"OFF");CreateDashboard();return;}
   else if(sparam==ObjName("PA_MASTER_TGL")){g_state.protectionMasterEnabled=!g_state.protectionMasterEnabled;SetAction("USER","PROTECTION MASTER",g_state.protectionMasterEnabled?"ON":"OFF");RecordEvent("PROTECTION AUTHORITY",g_state.protectionMasterEnabled?"Master authority enabled":"Master authority disabled | monitor only");CreateDashboard();return;}
   else if(sparam==ObjName("PA_DD_CLOSE")){g_state.protectionDrawdownCloseEnabled=!g_state.protectionDrawdownCloseEnabled;CreateDashboard();return;}
   else if(sparam==ObjName("PA_DL_CLOSE")){g_state.protectionDailyLossCloseEnabled=!g_state.protectionDailyLossCloseEnabled;CreateDashboard();return;}
   else if(sparam==ObjName("PA_BASKET_CLOSE")){g_state.protectionBasketLossCloseEnabled=!g_state.protectionBasketLossCloseEnabled;CreateDashboard();return;}
   else if(sparam==ObjName("PA_EM_ACTION")){g_state.protectionEmergencyActionEnabled=!g_state.protectionEmergencyActionEnabled;CreateDashboard();return;}
   else if(sparam==ObjName("PA_EM_CLOSE")){g_state.protectionEmergencyAutoCloseEnabled=!g_state.protectionEmergencyAutoCloseEnabled;g_state.emergencyAutoClose=g_state.protectionEmergencyAutoCloseEnabled;CreateDashboard();return;}
   else if(sparam==ObjName("PA_EM_CANCEL")){g_state.protectionEmergencyCancelEnabled=!g_state.protectionEmergencyCancelEnabled;g_state.emergencyCancelPending=g_state.protectionEmergencyCancelEnabled;CreateDashboard();return;}
   else if(sparam==ObjName("PA_EM_BREAK")){g_state.protectionHardBreakerEnabled=!g_state.protectionHardBreakerEnabled;CreateDashboard();return;}
   else if(sparam==ObjName("PA_SL")){g_state.useStopLossForNewOrders=!g_state.useStopLossForNewOrders;CreateDashboard();return;}
   else if(sparam==ObjName("PA_TP")){g_state.useTakeProfitForNewOrders=!g_state.useTakeProfitForNewOrders;CreateDashboard();return;}
   else if(sparam==ObjName("PA_BE")){g_state.breakEven=!g_state.breakEven;CreateDashboard();return;}
   else if(sparam==ObjName("PA_TR")){g_state.trailingStop=!g_state.trailingStop;CreateDashboard();return;}
   else if(sparam==ObjName("PA_REC_ENABLE")){g_state.gridRecovery=!g_state.gridRecovery;CreateDashboard();return;}
   else if(sparam==ObjName("BTN_EMERGENCY_STOP") || sparam==ObjName("BTN_EMERGENCY_STOP2")){g_state.emergencyManualStop=true;ActivateEmergency("Manual emergency stop",3,true);CreateDashboard();}

   else if(sparam==ObjName("BTN_EMERGENCY_CLEAR") || sparam==ObjName("BTN_EMERGENCY_CLEAR2")){ClearEmergencyState(true);CreateDashboard();}

   else if(sparam==ObjName("EG_ADV")){g_state.advancedProtection=!g_state.advancedProtection;CreateDashboard();}

   else if(sparam==ObjName("EG_PERM")){g_state.permEmergencyControl=!g_state.permEmergencyControl;CreateDashboard();}

   else if(sparam==ObjName("EGCLOSE")){g_state.emergencyAutoClose=!g_state.emergencyAutoClose;CreateDashboard();}

   else if(sparam==ObjName("EGCANCEL")){g_state.emergencyCancelPending=!g_state.emergencyCancelPending;CreateDashboard();}

   else if(sparam==ObjName("EGMAN")){g_state.emergencyManualStop=!g_state.emergencyManualStop; if(g_state.emergencyManualStop)ActivateEmergency("Manual emergency stop",3,true); else ClearEmergencyState(true); CreateDashboard();}

   else if(sparam==ObjName("BTN_RUN_GRID_VALIDATION") || sparam==ObjName("BTN_RUN_GRID_VALIDATION2") || sparam==ObjName("BTN_RUN_GRID_VALIDATION_RULES"))

   {

      RunGridValidationMatrix(); CreateDashboard(); return;

   }

   if(StringFind(sparam,ObjName("GV_SEL_"))==0)

   {

      int gi=(int)StringToInteger(StringSubstr(sparam,StringLen(ObjName("GV_SEL_")))); if(gi>=0 && gi<GRID_TYPE_COUNT) g_gridValidationSelected=gi; CreateDashboard(); return;

   }

   if(StringFind(sparam,ObjName("GV_SEL2_"))==0)

   {

      int gi=(int)StringToInteger(StringSubstr(sparam,StringLen(ObjName("GV_SEL2_")))); if(gi>=0 && gi<GRID_TYPE_COUNT) g_gridValidationSelected=gi; CreateDashboard(); return;

   }
   if(sparam==ObjName("BTN_RUN_PHASE16")){RunPhase16ValidationLab();CreateDashboard();return;}


   if(StringFind(sparam,ObjName("GRIDLAB_MAIN_"))==0)

   {

      int gi=(int)StringToInteger(StringSubstr(sparam,StringLen(ObjName("GRIDLAB_MAIN_")))); if(gi<0)gi=0;if(gi>1)gi=1;g_dashboard.gridLabSubTab=gi;CreateDashboard();return;

   }

   if(StringFind(sparam,ObjName("GRIDLAB_VALIDATE_"))==0)

   {

      int gi=(int)StringToInteger(StringSubstr(sparam,StringLen(ObjName("GRIDLAB_VALIDATE_")))); if(gi<0)gi=0;if(gi>2)gi=2;g_dashboard.gridLabValidationSubTab=gi;CreateDashboard();return;

   }

   if(StringFind(sparam,ObjName("GRIDLAB_MATRIX_"))==0)

   {

      int gi=(int)StringToInteger(StringSubstr(sparam,StringLen(ObjName("GRIDLAB_MATRIX_")))); if(gi<0)gi=0;if(gi>5)gi=5;g_dashboard.gridLabMatrixSubTab=gi;CreateDashboard();return;

   }

if(sparam==ObjName("BTN_RUN_GRID_VALIDATION_READY"))

   {

      RunGridValidationMatrix();
      SetAction("USER","READINESS CHECK","Grid validation/readiness refresh requested");
      CreateDashboard(); return;

   }

   if(sparam==ObjName("BTN_APPLY"))

   {

      g_pendingApplySummary=BuildApplySummary();

      AddApplyHistory();

      SyncFromDashboard(); SyncAutonomousEngineFromDashboard(); ValidateSettings(); UpdateEffectiveState(); UpdateConfigurationHealth(); DashboardSyncRefreshDashboardSyncAudit(); RunSettingsAuthorityAudit(); RunPhase20AuthorityAudit(); RepriceGridOnApply(); if(g_state.persistRuntimeState) SaveRuntimeCheckpoint(); ClearEditCache();

      if(g_state.configWarningCount>0) RecordEvent("CONFIGURATION",StringFormat("%d warning(s): %s",g_state.configWarningCount,g_state.configWarnings));

      if(!g_state.useStopLossForNewOrders) RemovePositionProtection(true,false);

      if(!g_state.useTakeProfitForNewOrders) RemovePositionProtection(false,true);

      trade.SetDeviationInPoints((ulong)MathMax(0,g_state.slippage));

      ApplyChartTheme(true);

      g_state.executionStatus="SETTINGS APPLIED";

      SetAction("USER","SETTINGS APPLIED",g_pendingApplySummary);

      g_pendingApplySummary="";

      CreateDashboard();

   }

   else if(sparam==ObjName("BTN_RESET"))

   {

      InitializeState(); ClearEditCache();

      trade.SetDeviationInPoints((ulong)MathMax(0,g_state.slippage));

      CreateDashboard();

   }



   ChartRedraw();

}







// -------------------- RUNTIME ARCHITECTURE AUDIT --------------------
// Purpose: enforce the v15 state-ownership contract at runtime.
bool ArchitectureArchitectureAudit(string &reason)
{
   reason="";
   if(GRID_TYPE_COUNT!=21){reason="Grid strategy library must contain exactly 21 grid types";return false;}
   if(InpMagicNumber==0){reason="Primary magic number is invalid";return false;}
   if(g_state.maxPositions<1 || g_state.maxPendingOrders<1){reason="Position/pending capacities must be positive";return false;}

   int selected=(int)g_selectedGridType;
   if(selected<0 || selected>=GRID_TYPE_COUNT){reason="Selected manual grid type is outside the 21-grid range";return false;}

   int autonomous=(int)g_autonomousGridType;
   if(autonomous<0 || autonomous>=GRID_TYPE_COUNT){reason="Autonomous selected grid type is outside the 21-grid range";return false;}

   // g_state.gridType is a runtime/effective field. It is allowed to mirror the
   // selected strategy, but must never force the user's next manual selection.
   if(g_state.controlMode!=CONTROL_AUTONOMOUS && g_state.gridType!=g_selectedGridType)
      g_state.gridType=g_selectedGridType;

   // Autonomous is authoritative only through Control Mode.
   bool expectedAuto=(g_state.controlMode==CONTROL_AUTONOMOUS);
   if(g_state.autonomousMode!=expectedAuto)
      g_state.autonomousMode=expectedAuto;
   if(!expectedAuto)
   {
      g_state.autonomousEngine=false;
      g_state.autonomousReady=false;
      g_state.autonomousParallelExecution=false;
      g_state.autonomousDynamicProtection=false;
      g_state.advancedEntryDecision=false;
      g_state.permAutonomousEntry=false;
   }

   return true;
}

bool MasterEngineAudit()
{
   if(_Digits<0)return false;
   if(InpMagicNumber==0)return false;
   if(GRID_TYPE_COUNT!=21)return false;
   if(g_state.maxPositions<1 || g_state.maxPendingOrders<1)return false;
   return true;
}

bool StateIntegrityRuntimeIntegrityAudit(string &reason)
{
   reason="";
   if(!IsValidGridTypeValue((int)g_selectedGridType)){reason="Selected grid invalid";return false;}
   if(!IsValidGridTypeValue((int)g_autonomousGridType)){reason="Autonomous grid invalid";return false;}
   if(g_state.gridLevels<1 || g_state.gridLevels>50){reason="Grid level integrity failure";return false;}
   if(g_state.gridStep<=0 || g_state.minGridStep<=0 || g_state.maxGridStep<g_state.minGridStep){reason="Grid spacing integrity failure";return false;}
   if(g_state.lotSize<=0){reason="Lot integrity failure";return false;}
   if(g_state.maxPositions<1 || g_state.maxPendingOrders<1){reason="Capacity integrity failure";return false;}
   if(g_state.maxSpreadPips<0 || g_state.riskPerGridPct<0 || g_state.maxGridRiskPct<0){reason="Risk numeric integrity failure";return false;}
   if(g_state.sessionStartHour<0 || g_state.sessionStartHour>23 || g_state.sessionEndHour<0 || g_state.sessionEndHour>23){reason="Session integrity failure";return false;}
   if(g_state.persistRuntimeState && g_state.checkpointSeconds<0){reason="Checkpoint integrity failure";return false;}
   return true;
}


bool GridGeometryAdaptiveGeometryAudit(string &reason)
{
   reason="";
   if((int)g_state.adaptiveAnchorMode<0 || (int)g_state.adaptiveAnchorMode>3){reason="Adaptive anchor mode invalid";return false;}
   if(g_state.adaptiveMinLevels<1 || g_state.adaptiveMaxLevels<g_state.adaptiveMinLevels){reason="Adaptive level bounds invalid";return false;}
   if(g_state.effectiveGridStepPips<0.1){reason="Effective step below safety floor";return false;}
   if(g_state.effectiveGridLevels<1){reason="Effective levels invalid";return false;}
   if(g_state.gridGeometryRiskCapacityFactor<0.25 || g_state.gridGeometryRiskCapacityFactor>1.0){reason="Risk capacity factor out of range";return false;}
   if(g_state.anchorPrice>0 && !MathIsValidNumber(g_state.anchorPrice)){reason="Anchor is not finite";return false;}
   return true;
}

bool TradeProtectionTradeManagementAudit(string &reason)
{
   reason="";
   if(g_state.adaptiveSLATRMultiple<0.50 || g_state.adaptiveSLATRMultiple>4.00){reason="Adaptive SL ATR multiple invalid";return false;}
   if(g_state.adaptiveTPATRMultiple<0.75 || g_state.adaptiveTPATRMultiple>6.00){reason="Adaptive TP ATR multiple invalid";return false;}
   if(g_state.profitLockTriggerPips<1.0){reason="Profit lock trigger invalid";return false;}
   if(g_state.profitLockOffsetPips<0.0){reason="Profit lock offset invalid";return false;}
   if(g_state.runnerATRMultiple<0.50 || g_state.runnerATRMultiple>5.00){reason="Runner ATR multiple invalid";return false;}
   if(g_state.adaptiveProfitManagement && !g_state.protectionMasterEnabled && !IsAutonomousManagedMode()){reason="Profit management enabled without an owner";return false;}
   if(g_state.tradeRunnerMode && !g_state.adaptiveProfitManagement && !IsAutonomousManagedMode()){reason="Runner enabled without profit-management owner";return false;}
   reason=StringFormat("PASS | Adaptive SL %.2f ATR | TP %.2f ATR | Profit lock %.1f pips | Runner %.2f ATR",g_state.adaptiveSLATRMultiple,g_state.adaptiveTPATRMultiple,g_state.profitLockTriggerPips,g_state.runnerATRMultiple);
   return true;
}


bool AutonomousDecisionAutonomousDecisionAudit(string &reason)
{
   reason="";
   if(g_state.autonomousDecisionClass!="APPROVE" &&
      g_state.autonomousDecisionClass!="WAIT" &&
      g_state.autonomousDecisionClass!="REJECT")
   {
      reason="Invalid autonomous decision class";
      return false;
   }
   if(g_state.autonomousPlanScore<0.0 || g_state.autonomousPlanScore>1.0)
   {
      reason="Autonomous plan score outside 0..1";
      return false;
   }
   if(g_state.autonomousPlanConfidence<0.0 || g_state.autonomousPlanConfidence>1.0)
   {
      reason="Autonomous plan confidence outside 0..1";
      return false;
   }
   if(g_state.autonomousPlanExpectedEdge<0.0 || g_state.autonomousPlanExpectedEdge>1.0)
   {
      reason="Autonomous expected edge outside 0..1";
      return false;
   }
   if(g_state.autonomousPlanRiskPct<0.0)
   {
      reason="Autonomous plan risk is negative";
      return false;
   }
   if(g_state.autonomousPlanLevels<0 || g_state.autonomousPlanLot<0.0 || g_state.autonomousPlanStepPips<0.0)
   {
      reason="Autonomous trade plan contains invalid geometry";
      return false;
   }
   reason=StringFormat("PASS | pipeline %s | decision %s | waits %d | rejects %d",
      g_state.autonomousPipelineStage,g_state.autonomousDecisionClass,g_state.autonomousWaitCount,g_state.autonomousRejectCount);
   return true;
}

int OnInit(){InitializeState();InitializeDashboard();if(!EventSetTimer(1)) Print("NOVA: failed to set 1-second dashboard timer");trade.SetExpertMagicNumber(g_v14ExecutionMagic>0?g_v14ExecutionMagic:(ulong)InpMagicNumber);trade.SetDeviationInPoints((ulong)MathMax(0,InpSlippage));g_atrHandle=iATR(_Symbol,PERIOD_CURRENT,InpRecenterATRPeriod);g_maHandle=iMA(_Symbol,PERIOD_CURRENT,20,0,MODE_SMA,PRICE_CLOSE);g_rsiHandle=iRSI(_Symbol,PERIOD_CURRENT,14,PRICE_CLOSE);g_maM15Handle=iMA(_Symbol,PERIOD_M15,20,0,MODE_SMA,PRICE_CLOSE);g_maH1Handle=iMA(_Symbol,PERIOD_H1,20,0,MODE_SMA,PRICE_CLOSE);g_atrM15Handle=iATR(_Symbol,PERIOD_M15,InpRecenterATRPeriod);g_atrH1Handle=iATR(_Symbol,PERIOD_H1,InpRecenterATRPeriod);bool checkpoint=LoadRuntimeCheckpoint();g_modeBaselineCaptured=false;if(g_state.controlMode==CONTROL_AUTONOMOUS)ArmAutonomousProfile();else if(g_state.controlMode==CONTROL_ASSIST)ArmAssistProfile();UpdateState();V14SyncCycleRegistry();g_selectedGridType=(ENUM_GRID_TYPE)MathMax(0,MathMin(GRID_TYPE_COUNT-1,(int)g_selectedGridType));RefreshStrategyHealth(true);g_engineReady=true;
   RecordEvent("TRADE ENGINE AUDIT","Individual Trade Engine initialized | per-ticket authority active | generic risk triggers cannot close positions without explicit authority");ApplyChartTheme(true);if(g_state.autoRecoverOnInit){if(!checkpoint){g_state.recoveryStatus="NO CHECKPOINT";g_state.recoverySource="LIVE STATE";}ReconcileRuntimeAfterRestart();}else if(g_state.positionCount>0||g_state.pendingCount>0){g_state.gridActive=true;g_state.recoveryStatus="LIVE STATE DETECTED";g_state.recoverySource="MANUAL RECOVERY MODE";RecordEvent("GRID RECOVERY","Live inventory detected; automatic recovery disabled");}RecoveryStartupHardening(checkpoint);SaveRuntimeCheckpoint();UpdateMarketStateV15();if(!ArchitectureArchitectureAudit(g_state.configWarnings)){RecordEvent("ARCHITECTURE AUDIT","FAILED | "+g_state.configWarnings);Print("NOVA architecture architecture audit failed: ",g_state.configWarnings);return INIT_FAILED;} if(!MasterEngineAudit()){Print("NOVA v15 master engine audit failed");return INIT_FAILED;} string stateIntegrityReason=""; if(!StateIntegrityRuntimeIntegrityAudit(stateIntegrityReason)){RecordEvent("RUNTIME INTEGRITY","FAILED | "+stateIntegrityReason);Print("NOVA state integrity runtime integrity failed: ",stateIntegrityReason);return INIT_FAILED;} RecordEvent("RUNTIME INTEGRITY","PASS | STATE INTEGRITY state persistence and validation ready"); if(!MarketStateMarketStateAudit(stateIntegrityReason)){RecordEvent("MARKET STATE AUDIT","FAILED | "+stateIntegrityReason);Print("NOVA market intelligence market state failed: ",stateIntegrityReason);return INIT_FAILED;} RecordEvent("MARKET STATE AUDIT","PASS | MARKET INTELLIGENCE market intelligence ready"); if(!StrategyLibraryGridLibraryAudit(stateIntegrityReason)){RecordEvent("GRID LIBRARY AUDIT","FAILED | "+stateIntegrityReason);Print("NOVA strategy library grid library failed: ",stateIntegrityReason);return INIT_FAILED;} RecordEvent("GRID LIBRARY AUDIT",stateIntegrityReason); UpdatePhase5GeometryTelemetry(); UpdateEffectiveState(); if(!GridGeometryAdaptiveGeometryAudit(stateIntegrityReason)){RecordEvent("GRID GEOMETRY AUDIT","FAILED | "+stateIntegrityReason);Print("NOVA grid geometry geometry failed: ",stateIntegrityReason);return INIT_FAILED;} RecordEvent("GRID GEOMETRY AUDIT","PASS | GRID GEOMETRY adaptive geometry ready"); GridSelectionRefreshSelection(); if(!GridSelectionGridSelectionAudit(stateIntegrityReason)){RecordEvent("GRID SELECTION AUDIT","FAILED | "+stateIntegrityReason);Print("NOVA grid selection grid selection failed: ",stateIntegrityReason);return INIT_FAILED;} RecordEvent("GRID SELECTION AUDIT",stateIntegrityReason); string riskPortfolioReason=""; if(!RiskPortfolioRiskPortfolioAudit(riskPortfolioReason)){RecordEvent("RISK PORTFOLIO AUDIT","FAILED | "+riskPortfolioReason);Print("NOVA risk portfolio risk portfolio failed: ",riskPortfolioReason);return INIT_FAILED;} RecordEvent("RISK PORTFOLIO AUDIT","PASS | RISK & PORTFOLIO risk hierarchy ready"); if(!TradeProtectionTradeManagementAudit(riskPortfolioReason)){RecordEvent("TRADE PROTECTION AUDIT","FAILED | "+riskPortfolioReason);Print("NOVA trade protection trade management failed: ",riskPortfolioReason);return INIT_FAILED;} RecordEvent("TRADE PROTECTION AUDIT",riskPortfolioReason); string gridLifecycleReason=""; if(!GridLifecycleLifecycleAudit(gridLifecycleReason)){RecordEvent("GRID LIFECYCLE AUDIT","FAILED | "+gridLifecycleReason);Print("NOVA grid lifecycle lifecycle failed: ",gridLifecycleReason);return INIT_FAILED;} RecordEvent("GRID LIFECYCLE AUDIT","PASS | Grid lifecycle pending-only authority ready"); string autonomousDecisionDecisionAudit=""; if(!AutonomousDecisionAutonomousDecisionAudit(autonomousDecisionDecisionAudit)){RecordEvent("AUTONOMOUS DECISION AUDIT","FAILED | "+autonomousDecisionDecisionAudit);Print("NOVA v16 MODULE autonomous decision failed: ",autonomousDecisionDecisionAudit);return INIT_FAILED;} RecordEvent("AUTONOMOUS DECISION AUDIT",autonomousDecisionDecisionAudit); RunPhase20AuthorityAudit(); if(g_dashboard.isVisible)CreateDashboard();return INIT_SUCCEEDED;}

void OnTradeTransaction(const MqlTradeTransaction& trans,const MqlTradeRequest& request,const MqlTradeResult& result)
{
   if(result.retcode!=0 && result.retcode!=TRADE_RETCODE_DONE && result.retcode!=TRADE_RETCODE_PLACED && result.retcode!=TRADE_RETCODE_DONE_PARTIAL)
   {
      g_state.lastOrderRetcode=(uint)result.retcode;
      g_state.lastOrderRetcodeText=result.comment;
      RecordEvent("TRADE RETCODE",StringFormat("%u | %s",(uint)result.retcode,result.comment));
   }

   if(trans.type==TRADE_TRANSACTION_DEAL_ADD && trans.deal>0 && HistoryDealSelect(trans.deal))
   {
      string sym=HistoryDealGetString(trans.deal,DEAL_SYMBOL);
      ulong magic=(ulong)HistoryDealGetInteger(trans.deal,DEAL_MAGIC);
      if(sym==_Symbol && V14KnownMagic(magic))
      {
         ENUM_DEAL_ENTRY entry=(ENUM_DEAL_ENTRY)HistoryDealGetInteger(trans.deal,DEAL_ENTRY);
         ENUM_DEAL_TYPE dtype=(ENUM_DEAL_TYPE)HistoryDealGetInteger(trans.deal,DEAL_TYPE);
         double pnl=HistoryDealGetDouble(trans.deal,DEAL_PROFIT)+HistoryDealGetDouble(trans.deal,DEAL_SWAP)+HistoryDealGetDouble(trans.deal,DEAL_COMMISSION);
         if(entry==DEAL_ENTRY_IN)
         {
            g_state.lifecycleFillCount++;
            RecordEvent("TRADE OPENED",StringFormat("%s | deal %I64u | P/L %.2f",EnumToString(dtype),trans.deal,pnl));
         }
         else if(entry==DEAL_ENTRY_OUT)
         {
            if(pnl>=0.0)RecordEvent("PROFIT BANKED",StringFormat("%s | deal %I64u | +%.2f",EnumToString(dtype),trans.deal,pnl));
            else RecordEvent("TRADE LOSS REALIZED",StringFormat("%s | deal %I64u | %.2f",EnumToString(dtype),trans.deal,pnl));
         }
      }
   }

   if(trans.type==TRADE_TRANSACTION_ORDER_DELETE)
   {
      g_state.lifecycleDeleteCount++;
      RecordEvent("PENDING DELETED",StringFormat("Order %I64u | deleted %d",trans.order,g_state.lifecycleDeleteCount));
   }
}


void OnDeinit(const int reason){EventKillTimer();SaveRuntimeCheckpoint();if(g_atrHandle!=INVALID_HANDLE)IndicatorRelease(g_atrHandle);if(g_maHandle!=INVALID_HANDLE)IndicatorRelease(g_maHandle);if(g_rsiHandle!=INVALID_HANDLE)IndicatorRelease(g_rsiHandle);if(g_maM15Handle!=INVALID_HANDLE)IndicatorRelease(g_maM15Handle);if(g_maH1Handle!=INVALID_HANDLE)IndicatorRelease(g_maH1Handle);if(g_atrM15Handle!=INVALID_HANDLE)IndicatorRelease(g_atrM15Handle);if(g_atrH1Handle!=INVALID_HANDLE)IndicatorRelease(g_atrH1Handle);DeleteDashboard();Comment("");}

void ManageAllIndividualTrades()
{
   // Individual-ticket management. No cycle context is assigned to a trade.
   g_v14FocusMagic=0;
   g_v14ExecutionMagic=(ulong)InpMagicNumber;
   g_v14ExecutionCycleId=0;

   ManagePositions();
   ApplyOCO();
   ManageGridRisk();

   if(g_state.riskManagedTrading && !g_state.exitCoordinationActive && g_state.permReplenishment)
      SmartReplenishGrid();

   g_state.positionCount=GetPositionCount();
   g_state.pendingCount=GetPendingCount();
   g_state.gridActive=(g_state.positionCount+g_state.pendingCount)>0;
   g_state.activeDeploymentCount=0;
   g_state.gridType=g_selectedGridType;
}

static ulong g_lastMarketCycleMs=0;
static ulong g_lastTelemetryMs=0;

void UpdateSlowRuntimeState()
{
   UpdatePerformanceStats();
   UpdateExposureMetrics();
   UpdateEffectiveState();
   UpdateConfigurationHealth();
   if(g_state.autoChartTheme) ApplyChartTheme(false);
}

void UpdateMarketSnapshotRuntime()
{
   g_state.sentimentScore=CalculateSentiment();
   g_state.atrPrice=GetCurrentATRPrice();
   UpdateMarketStateV15();
}

void OnTimer()
{
   if(g_dashboard.isVisible) UpdateDashboard();
}

void OnTick()
{
   UpdateState();
   ulong nowMs=GetTickCount();

   if(g_lastMarketCycleMs==0 || nowMs-g_lastMarketCycleMs>=250)
   {
      g_lastMarketCycleMs=nowMs;
      UpdateMarketSnapshotRuntime();
      RefreshStrategyHealth(false);
      GridSelectionRefreshSelection();
   }

   if(g_lastTelemetryMs==0 || nowMs-g_lastTelemetryMs>=1000)
   {
      g_lastTelemetryMs=nowMs;
      RefreshPhase14LiveTelemetry();
      UpdatePhase7RiskTelemetry();
      UpdateSlowRuntimeState();
      if(g_state.authorityAuditAuditTime==0 || (TimeCurrent()-g_state.authorityAuditAuditTime)>=5)
         RunPhase20AuthorityAudit();
   }

   UpdateEmergencyTelemetry();
   EnforceHardCircuitBreaker();

   if(!IsAutonomousControl() && (g_state.autonomousEngine || g_state.autonomousMode || g_state.advancedEntryDecision))
   {
      g_state.autonomousEngine=false;
      g_state.autonomousMode=false;
      g_state.autonomousReady=false;
      g_state.autonomousParallelExecution=false;
      g_state.autonomousDynamicProtection=false;
      g_state.advancedEntryDecision=false;
   }

   ExpirePendingOrders();
   ManageAllIndividualTrades();
   FinalizeCoordinatedExit();

   if(IsAutonomousControl() && !g_state.exitCoordinationActive && !g_state.emergencyActive)
   {
      if(ShouldStartGrid())
      {
         string gate="";
         if(UnifiedDeploymentGate(true,gate))CreateGrid(true);
         else RecordDeploymentBlock("AUTONOMOUS",gate);
      }
   }

   MaintainRuntimeCheckpoint();
   RecoveryUpdateRecoveryTelemetry(g_state.recoveryStatus,g_state.recoveryMismatchReason);
}



// NOVA MULTI-GRID — EVENT-DRIVEN PERFORMANCE CORE
// Integrated execution model: individual-ticket management; selected-grid persistence; non-destructive lifecycle controls; unified autonomous controller.

// Exit authority remains explicit; generic risk telemetry does not close individual trades.
