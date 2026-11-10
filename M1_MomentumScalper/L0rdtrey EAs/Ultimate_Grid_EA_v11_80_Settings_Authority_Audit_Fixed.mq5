#property strict
#property version   "11.80"
#property description "Ultimate Grid EA v11.70 - VPS Optional Restart-Safe Recovery"

#include <Trade/Trade.mqh>
CTrade trade;

enum ENUM_GRID_TYPE{BASIC_GRID=0,HEDGE_GRID,TREND_GRID,VOLATILITY_GRID,AI_GRID,GEOMETRIC_GRID,FIBONACCI_GRID,ATR_ADAPTIVE_GRID,MEAN_REVERSION_GRID,BREAKOUT_GRID,MOMENTUM_GRID,HYBRID_GRID,BULLISH_GRID,BEARISH_GRID,BIDIRECTIONAL_GRID,LADDER_GRID,ANTI_MARTINGALE_GRID,RANGE_SCALING_GRID,VOLATILITY_BREAKOUT_GRID,SESSION_GRID,SMART_REGIME_GRID};
enum ENUM_ENTRY_MODE{MANUAL_ENTRY=0,AUTO_ENTRY,AI_ENTRY,TIME_ENTRY};
enum ENUM_RISK_MODE{CONSERVATIVE=0,BALANCED,AGGRESSIVE,ADAPTIVE};
enum ENUM_REENTRY_MODE{REENTRY_OFF=0,REENTRY_ON_CLOSE,REENTRY_ON_CENTER_SHIFT,REENTRY_ON_REGIME_CHANGE};
enum ENUM_PANEL_THEME{THEME_ONYX=0,THEME_GOLD,THEME_TEAL};
enum ENUM_CHART_THEME_MODE{CHART_THEME_AUTO_REGIME=0,CHART_THEME_DARK_LUXURY,CHART_THEME_OCEAN,CHART_THEME_EMERALD,CHART_THEME_MONOCHROME,CHART_THEME_AMETHYST,CHART_THEME_SANDSTONE,CHART_THEME_CRIMSON_NOIR,CHART_THEME_ARCTIC_SILVER};
enum ENUM_CONTROL_MODE{CONTROL_MANUAL=0,CONTROL_ASSIST,CONTROL_AUTONOMOUS};

input group "=== GRID ENGINE ==="
input ENUM_GRID_TYPE InpGridType=SMART_REGIME_GRID;
input ENUM_ENTRY_MODE InpEntryMode=AUTO_ENTRY;
input double InpLotSize=0.01;
input double InpGridStep=20.0;
input int InpGridLevels=6;
input double InpLotMultiplier=1.20;
input double InpFrontOrderDistancePips=5.0;
input bool InpAutonomousMode=true;
input bool InpUseATRSpacing=true;
input double InpATRSpacingMultiplier=0.80;
input double InpMinGridStepPips=5.0;
input double InpMaxGridStepPips=150.0;
input int InpRecenterATRPeriod=14;
input double InpRecenterATRMultiple=2.5;
input bool InpAutoRecenter=true;
input ENUM_REENTRY_MODE InpReentryMode=REENTRY_ON_CENTER_SHIFT;
input ulong InpMagicNumber=123456;

input group "=== AI / REGIME ENGINE ==="
input bool InpEnableAI=true;
input bool InpNeuralNetwork=false;
input double InpAIConfidence=0.75;
input int InpLearningPeriod=100;
input bool InpRegimeFilter=true;
input double InpBullThreshold=0.62;
input double InpBearThreshold=0.38;
input double InpHighVolThreshold=0.70;
input double InpLowVolThreshold=0.30;

input group "=== RISK & BASKET MANAGEMENT ==="
input ENUM_RISK_MODE InpRiskMode=ADAPTIVE;
input bool InpUseDynamicRiskLot=true;
input bool InpRiskManagedTrading=true;
input bool InpUseStopLossForNewOrders=true;
input bool InpUseTakeProfitForNewOrders=true;
input double InpRiskPerGridPct=0.50;
input double InpMaxGridRiskPct=5.0;
input double InpMaxDrawdownPct=5.0;
input double InpDailyLossLimitPct=3.0;
input double InpDailyProfitLockPct=5.0;
input double InpBasketTakeProfitUSD=0.0;
input double InpBasketStopLossUSD=0.0;
input double InpStopLossPips=100.0;
input double InpTakeProfitPips=50.0;
input bool InpUseBreakEven=true;
input double InpBreakEvenTriggerPips=30.0;
input double InpBreakEvenOffsetPips=2.0;
input bool InpTrailingStop=true;
input double InpTrailingATRMultiple=1.5;
input bool InpStrategyAwareManagement=false; // Optional: adapt BE/trailing/hold policy to selected grid type
input bool InpStrategyExitCoordination=false; // Optional: coordinate exits, OCO, recentering and replenishment
input double InpMaxHoldMinutes=0.0;
input int InpMaxPositions=20;
input int InpMaxPendingOrders=30;
input bool InpOCO=true;
input bool InpCloseOppositePendingOnFill=true;

input group "=== EXECUTION ENGINE ==="
input int InpSlippage=20;
input double InpMaxSpreadPips=5.0;
input int InpPendingExpiryMinutes=0;
input bool InpSmartExecution=true;
input bool InpValidateStops=true;
input bool InpDeleteInvalidLevels=true;
input int InpOrderRetryCount=2;
input bool InpUseAsyncSafety=false;

input group "=== SESSION / MARKET FILTERS ==="
input bool InpUseSessionFilter=false;
input int InpSessionStartHour=7;
input int InpSessionEndHour=21;
input bool InpAvoidWeekend=true;
input bool InpPauseOnHighVolatility=false;

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
input bool InpAutoRecoverOnInit=true;
input bool InpPersistRuntimeState=true;
input int InpCheckpointSeconds=15;
input bool InpRecoverOrdersAndPositions=true;
input bool InpExposureManager=false;
input bool InpAdvancedProtection=false;
input bool InpDecisionJournal=true;
input bool InpOrderGuardian=true;
input double InpAdaptiveSensitivity=0.65;
input double InpMaxStepChangePct=25.0;
input double InpMaxTotalLots=0.0;
input int InpMaxAutonomousGridsPerDay=0;
input double InpAutonomousMinSuitability=0.60;
input int InpAdaptiveMinLevels=1;
input int InpAdaptiveMaxLevels=50;

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
   ENUM_CONTROL_MODE controlMode;
   bool advancedEntryDecision,adaptiveGrid,adaptiveLevels,adaptiveLot,marketIntelligence,smartRegime,smartRecenter,smartReplenishment,exposureManager,advancedProtection,decisionJournal;
   double adaptiveSensitivity,maxStepChangePct,maxTotalLots,autonomousMinSuitability;
   int adaptiveMinLevels,adaptiveMaxLevels;
   double marketSuitabilityScore,intelligenceConfidence;
   string adaptiveGridReason,marketDecisionReason;
   int maxAutonomousGridsPerDay,autonomousGridsToday;
   int replenishDelaySeconds; datetime lastReplenishTime; int replenishments; bool gridRecovery;
   double effectiveGridStepPips,effectiveLot; int effectiveGridLevels; double gridPolicyStepFactor,gridPolicyLotFactor; string gridPolicyReason,gridPolicyLevelReason;
   double totalOpenLots,totalPendingLots,totalExposureLots,exposureUtilizationPct,gridRiskPct,accountMarginUsedPct;
   bool entryThrottleActive; string entryThrottleReason;
   string lastActionOwner,lastActionReason,lastDecision;
   bool orderGuardian; ulong lastOrderLatencyMs; uint lastOrderRetcode; string lastOrderRetcodeText,lastOrderType; double lastOrderPrice,lastOrderLots; int lastOrderRetryCount;
   int configWarningCount; string configHealth,configWarnings;
   int g_state.settingsAuditChecked,g_state.settingsAuditPassed,g_state.settingsAuditWarnings,g_state.settingsAuditFailed; datetime g_state.settingsAuditTime; string g_state.settingsAuditStatus,g_state.settingsAuditSummary;
   int lastGridRequestedOrders,lastGridAcceptedOrders,lastGridShortfall; string lastGridAudit; datetime lastConfigCheckTime; string lastConfigCheckResult; int configCheckSequence;
   ulong gridCycleId; int lifecycleFillCount,lifecycleDeleteCount,lifecycleRecoveryCount; string gridLifecycleState,gridLifecycleReason; bool exitCoordinationActive; string exitCoordinationReason; datetime exitCoordinationTime;
   bool autoRecoverOnInit,persistRuntimeState,recoverOrdersAndPositions; int checkpointSeconds; datetime lastCheckpointTime,lastRecoveryTime; string recoveryStatus,recoverySource,recoveryFile;
};
GridState g_state;

struct DashboardConfig{
   int x,y,width,height,currentTab;
   int homeSubTab,gridSubTab,riskSubTab,analyticsSubTab,aiSubTab,executionSubTab,tradesSubTab,transparencySubTab,diagnosticsSubTab,toolsSubTab;
   int settingsPage,settingsSubTab,settingsSubTab2,settingsSubTab3,settingsSubTab4,settingsSubTab5,settingsSubTab6,settingsSubTab7;
   int navOffset;
   bool isVisible;
};
DashboardConfig g_dashboard;
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
const int TAB_COUNT=11;
const int GRID_TYPE_COUNT=21;
const int TRADE_TAB_COUNT=4;
const int SETTINGS_TAB_COUNT=40;
const int SETTINGS_PAGE_COUNT=7;
color COLOR_BG,COLOR_PANEL,COLOR_PANEL2,COLOR_TEXT,COLOR_MUTED,COLOR_ACCENT,COLOR_GOLD,COLOR_GREEN,COLOR_RED,COLOR_ORANGE,COLOR_TEAL;
int g_atrHandle=INVALID_HANDLE,g_maHandle=INVALID_HANDLE,g_rsiHandle=INVALID_HANDLE;

string ObjName(string s){return PREFIX+s;}
double PipSize(){int d=(int)SymbolInfoInteger(_Symbol,SYMBOL_DIGITS); double p=SymbolInfoDouble(_Symbol,SYMBOL_POINT); return (d==3||d==5)?p*10.0:p;}
double NormalizeLots(double lots){double mn=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN),mx=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MAX),st=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_STEP); if(mn<=0)mn=0.01;if(mx<=0)mx=100;lots=MathMax(mn,MathMin(mx,lots));if(st>0)lots=MathRound(lots/st)*st;return NormalizeDouble(lots,2);}
bool IsGridOrder(ulong ticket,bool pending=false){if(pending){if(!OrderSelect(ticket))return false;return OrderGetString(ORDER_SYMBOL)==_Symbol&&(ulong)OrderGetInteger(ORDER_MAGIC)==InpMagicNumber;}if(!PositionSelectByTicket(ticket))return false;return PositionGetString(POSITION_SYMBOL)==_Symbol&&(ulong)PositionGetInteger(POSITION_MAGIC)==InpMagicNumber;}
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
double CalculateVolatility(){if(g_atrHandle==INVALID_HANDLE)return 0.5;double atr[];ArraySetAsSeries(atr,true);if(CopyBuffer(g_atrHandle,0,0,5,atr)<5)return 0.5;double px=SymbolInfoDouble(_Symbol,SYMBOL_BID);if(px<=0)return 0.5;return MathMax(0.0,MathMin(1.0,(atr[0]/px)*1000.0));}
double CalculateSentiment(){if(g_rsiHandle==INVALID_HANDLE)return 0.5;double r[];ArraySetAsSeries(r,true);if(CopyBuffer(g_rsiHandle,0,0,1,r)<1)return 0.5;return MathMax(0.0,MathMin(1.0,r[0]/100.0));}
double GetCurrentATRPrice(){if(g_atrHandle==INVALID_HANDLE)return 0.0;double a[];ArraySetAsSeries(a,true);if(CopyBuffer(g_atrHandle,0,0,1,a)<1)return 0.0;return MathMax(a[0],SymbolInfoDouble(_Symbol,SYMBOL_POINT)*2.0);}

// -------------------- ADVANCED CONTROL / TRANSPARENCY --------------------
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
   if(g_state.maxAutonomousGridsPerDay==0)
      AddConfigurationWarning(warnings,msg,"Autonomous grids/day is unlimited");

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
   WriteProfileValue(h,"SMART_REGIME",g_state.smartRegime?"1":"0");
   WriteProfileValue(h,"SMART_RECENTER",g_state.smartRecenter?"1":"0");
   WriteProfileValue(h,"SMART_REPLENISH",g_state.smartReplenishment?"1":"0");
   WriteProfileValue(h,"EXPOSURE",g_state.exposureManager?"1":"0");
   WriteProfileValue(h,"ADV_PROTECT",g_state.advancedProtection?"1":"0");
   WriteProfileValue(h,"GUARDIAN",g_state.orderGuardian?"1":"0");
   WriteProfileValue(h,"JOURNAL",g_state.decisionJournal?"1":"0");
   WriteProfileValue(h,"SENS",DoubleToString(g_state.adaptiveSensitivity,8));
   WriteProfileValue(h,"MAXSTEPCHANGE",DoubleToString(g_state.maxStepChangePct,8));
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
   v=ReadProfileField(keys,vals,n,"SMART_REGIME"); if(v!="") g_state.smartRegime=(StringToInteger(v)!=0);
   v=ReadProfileField(keys,vals,n,"SMART_RECENTER"); if(v!="") g_state.smartRecenter=(StringToInteger(v)!=0);
   v=ReadProfileField(keys,vals,n,"SMART_REPLENISH"); if(v!="") g_state.smartReplenishment=(StringToInteger(v)!=0);
   v=ReadProfileField(keys,vals,n,"EXPOSURE"); if(v!="") g_state.exposureManager=(StringToInteger(v)!=0);
   v=ReadProfileField(keys,vals,n,"ADV_PROTECT"); if(v!="") g_state.advancedProtection=(StringToInteger(v)!=0);
   v=ReadProfileField(keys,vals,n,"GUARDIAN"); if(v!="") g_state.orderGuardian=(StringToInteger(v)!=0);
   v=ReadProfileField(keys,vals,n,"JOURNAL"); if(v!="") g_state.decisionJournal=(StringToInteger(v)!=0);
   v=ReadProfileField(keys,vals,n,"SENS"); if(v!="") g_state.adaptiveSensitivity=StringToDouble(v);
   v=ReadProfileField(keys,vals,n,"MAXSTEPCHANGE"); if(v!="") g_state.maxStepChangePct=StringToDouble(v);
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

double CalculateEffectiveGridStepPips()
{
   double base=MathMax(0.1,g_state.gridStep);
   if(!g_state.adaptiveGrid){g_state.gridPolicyStepFactor=1.0;g_state.gridPolicyLotFactor=1.0;g_state.gridPolicyReason="USER FIXED | no adaptive grid policy";g_state.adaptiveGridReason="USER FIXED";return base;}
   double sens=ClampDouble(g_state.adaptiveSensitivity,0,1);
   double atrPips=(PipSize()>0&&g_state.atrPrice>0)?g_state.atrPrice/PipSize():base;
   double target=MathMax(base,atrPips*g_state.atrSpacingMultiplier);
   double policy=GridStepPolicyFactor(g_state.gridType);
   g_state.gridPolicyStepFactor=policy;
   g_state.gridPolicyReason=GridAdaptivePolicyReason(g_state.gridType);
   target*=policy;
   double volFactor=1.0+((ClampDouble(g_state.volatilityIndex,0,1)-0.5)*0.70*sens);
   double regimeFactor=1.0;
   if(g_state.smartRegime){
      if(g_state.regime=="BREAKOUT / HIGH VOL") regimeFactor=1.10;
      else if(StringFind(g_state.regime,"RANGE")>=0) regimeFactor=0.92;
   }
   double candidate=base*(1.0-sens)+target*sens;
   candidate*=volFactor*regimeFactor;
   double lim=MathMax(0.0,g_state.maxStepChangePct)/100.0;
   candidate=ClampDouble(candidate,base*(1.0-lim),base*(1.0+lim));
   candidate=ClampDouble(candidate,g_state.minGridStep,g_state.maxGridStep);
   g_state.adaptiveGridReason=StringFormat("ATR %.1f | VOL %.2f | %s",atrPips,g_state.volatilityIndex,g_state.regime);
   return candidate;
}

int CalculateEffectiveGridLevels()
{
   int base=MathMax(1,g_state.gridLevels);
   if(!g_state.adaptiveLevels)return base;
   int lo=MathMax(1,MathMin(g_state.adaptiveMinLevels,50));
   int hi=MathMax(lo,MathMin(g_state.adaptiveMaxLevels,50));
   double v=ClampDouble(g_state.volatilityIndex,0,1);
   double sens=ClampDouble(g_state.adaptiveSensitivity,0,1);
   double center=(g_state.lowVolThreshold+g_state.highVolThreshold)*0.5;
   int target=base;
   if(v<center) target+=(int)MathRound((center-v)/MathMax(0.05,center)*sens*3.0);
   else target-=(int)MathRound((v-center)/MathMax(0.05,1.0-center)*sens*3.0);
   int bias=GridLevelPolicyBias(g_state.gridType);
   if(bias>0 && v<=center) target+=MathMax(0,(int)MathRound(sens));
   if(bias<0 && v>=center) target-=MathMax(0,(int)MathRound(sens));
   g_state.gridPolicyLevelReason=StringFormat("Base %d | Vol %.2f | Bias %d",base,v,bias);
   return MathMax(lo,MathMin(hi,target));
}

void UpdateEffectiveState()
{
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
      if(t>0 && IsGridOrder(t,false)) lots+=PositionGetDouble(POSITION_VOLUME);
   }
   for(int i=0;i<OrdersTotal();i++)
   {
      ulong t=OrderGetTicket(i);
      if(t>0 && IsGridOrder(t,true)) lots+=OrderGetDouble(ORDER_VOLUME_CURRENT);
   }
   return lots;
}

double CalculateAdaptiveLot(double requested)
{
   double lot=requested;
   if(g_state.adaptiveLot)
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
   if(g_state.exposureManager && g_state.maxTotalLots>0)
   {
      double used=CurrentGridExposureLots();
      lot=MathMax(0,MathMin(lot,g_state.maxTotalLots-used));
   }
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
   if(!g_state.advancedEntryDecision)
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
void CreateHedgeGrid(double b,double s){double lot=NormalizeLots(g_state.lotSize);PlaceManagedMarketOrder(true,lot,"Hedge Buy");PlaceManagedMarketOrder(false,lot,"Hedge Sell");for(int i=1;i<=g_state.gridLevels;i++){double l=NormalizeLots(lot*MathPow(g_state.lotMultiplier,i));PlaceGridOrder(ORDER_TYPE_BUY_STOP,NormalizeDouble(b+s*i,_Digits),l);PlaceGridOrder(ORDER_TYPE_SELL_STOP,NormalizeDouble(b-s*i,_Digits),l);}}
void CreateTrendGrid(double b,double s){double tr=CalculateTrendStrength(),lot=NormalizeLots(g_state.lotSize);if(tr>0.6){PlaceManagedMarketOrder(true,lot,"Trend Buy");for(int i=1;i<=g_state.gridLevels;i++)PlaceGridOrder(ORDER_TYPE_BUY_STOP,NormalizeDouble(b+s*i,_Digits),lot);}else if(tr<0.4){PlaceManagedMarketOrder(false,lot,"Trend Sell");for(int i=1;i<=g_state.gridLevels;i++)PlaceGridOrder(ORDER_TYPE_SELL_STOP,NormalizeDouble(b-s*i,_Digits),lot);}}
void CreateVolatilityGrid(double b,double s){double v=CalculateVolatility();s*=1.0+v;for(int i=1;i<=g_state.gridLevels;i++){double l=NormalizeLots(g_state.lotSize*(1.0+v*0.5));PlaceGridOrder(ORDER_TYPE_BUY_STOP,NormalizeDouble(b+s*i,_Digits),l);PlaceGridOrder(ORDER_TYPE_SELL_STOP,NormalizeDouble(b-s*i,_Digits),l);}}
void CreateAIGrid(double b,double s){if(!g_state.aiEnabled){CreateBasicGrid(b,s);return;}double tr=CalculateTrendStrength(),v=CalculateVolatility(),sent=CalculateSentiment();s*=1.0+v*0.5;int levels=(int)MathRound(g_state.gridLevels*(1.0+tr*0.3));levels=MathMax(3,MathMin(10,levels));for(int i=1;i<=levels;i++){double l=NormalizeLots(g_state.lotSize*(1.0+sent*0.2));PlaceGridOrder(ORDER_TYPE_BUY_STOP,NormalizeDouble(b+s*i,_Digits),l);PlaceGridOrder(ORDER_TYPE_SELL_STOP,NormalizeDouble(b-s*i,_Digits),l);}}
void CreateGeometricGrid(double b,double s){double r=MathMax(1.05,g_state.lotMultiplier);for(int i=1;i<=g_state.gridLevels;i++){double d=s*MathPow(r,i-1),l=NormalizeLots(g_state.lotSize);PlaceGridOrder(ORDER_TYPE_BUY_STOP,NormalizeDouble(b+d,_Digits),l);PlaceGridOrder(ORDER_TYPE_SELL_STOP,NormalizeDouble(b-d,_Digits),l);}}
void CreateFibonacciGrid(double b,double s){double f[]={0.236,0.382,0.500,0.618,0.786,1.000,1.272,1.618};int n=MathMin(g_state.gridLevels,ArraySize(f));for(int i=0;i<n;i++){double d=s*f[i],l=NormalizeLots(g_state.lotSize*(1.0+f[i]*0.10));PlaceGridOrder(ORDER_TYPE_BUY_STOP,NormalizeDouble(b+d,_Digits),l);PlaceGridOrder(ORDER_TYPE_SELL_STOP,NormalizeDouble(b-d,_Digits),l);}}
void CreateATRAdaptiveGrid(double b,double s){double atr=GetCurrentATRPrice();if(atr<=0){CreateVolatilityGrid(b,s);return;}double step=MathMax(s,atr),v=CalculateVolatility();for(int i=1;i<=g_state.gridLevels;i++){double d=step*i,l=NormalizeLots(g_state.lotSize*MathMax(0.5,1.0-v*0.4));PlaceGridOrder(ORDER_TYPE_BUY_STOP,NormalizeDouble(b+d,_Digits),l);PlaceGridOrder(ORDER_TYPE_SELL_STOP,NormalizeDouble(b-d,_Digits),l);}}
void CreateMeanReversionGrid(double b,double s){for(int i=1;i<=g_state.gridLevels;i++){double d=s*i,l=NormalizeLots(g_state.lotSize);PlaceGridOrder(ORDER_TYPE_BUY_LIMIT,NormalizeDouble(b-d,_Digits),l);PlaceGridOrder(ORDER_TYPE_SELL_LIMIT,NormalizeDouble(b+d,_Digits),l);}}
void CreateBreakoutGrid(double b,double s){double atr=GetCurrentATRPrice(),d0=MathMax(s,atr>0?atr*0.75:s);for(int i=1;i<=g_state.gridLevels;i++){double d=d0*i,l=NormalizeLots(g_state.lotSize*(1.0+0.05*(i-1)));PlaceGridOrder(ORDER_TYPE_BUY_STOP,NormalizeDouble(b+d,_Digits),l);PlaceGridOrder(ORDER_TYPE_SELL_STOP,NormalizeDouble(b-d,_Digits),l);}}
void CreateMomentumGrid(double b,double s){double tr=CalculateTrendStrength(),l=NormalizeLots(g_state.lotSize);if(tr>=0.60){for(int i=1;i<=g_state.gridLevels;i++)PlaceGridOrder(ORDER_TYPE_BUY_STOP,NormalizeDouble(b+s*i,_Digits),l);}else if(tr<=0.40){for(int i=1;i<=g_state.gridLevels;i++)PlaceGridOrder(ORDER_TYPE_SELL_STOP,NormalizeDouble(b-s*i,_Digits),l);}else CreateBreakoutGrid(b,s);}
void CreateHybridGrid(double b,double s){double tr=CalculateTrendStrength(),v=CalculateVolatility(),atr=GetCurrentATRPrice(),hs=s;if(atr>0)hs=MathMax(s,atr*(0.75+v*0.75));if(tr>0.65){for(int i=1;i<=g_state.gridLevels;i++)PlaceGridOrder(ORDER_TYPE_BUY_STOP,NormalizeDouble(b+hs*i,_Digits),NormalizeLots(g_state.lotSize*MathMax(0.5,1.0-v*0.3)));}else if(tr<0.35){for(int i=1;i<=g_state.gridLevels;i++)PlaceGridOrder(ORDER_TYPE_SELL_STOP,NormalizeDouble(b-hs*i,_Digits),NormalizeLots(g_state.lotSize*MathMax(0.5,1.0-v*0.3)));}else if(v<0.35)CreateMeanReversionGrid(b,hs);else CreateBreakoutGrid(b,hs);}
void CreateBullishGrid(double b,double s){double tr=CalculateTrendStrength();if(tr<0.55)return;double atr=GetCurrentATRPrice(),step=MathMax(s,atr>0?atr*0.65:s),lot=NormalizeLots(g_state.lotSize*MathMax(0.5,1.0-CalculateVolatility()*0.35));for(int i=1;i<=g_state.gridLevels;i++){PlaceGridOrder(ORDER_TYPE_BUY_STOP,NormalizeDouble(b+step*i,_Digits),lot);if(i<=MathMax(1,g_state.gridLevels/2))PlaceGridOrder(ORDER_TYPE_BUY_LIMIT,NormalizeDouble(b-step*(0.35*i),_Digits),lot);}}
void CreateBearishGrid(double b,double s){double tr=CalculateTrendStrength();if(tr>0.45)return;double atr=GetCurrentATRPrice(),step=MathMax(s,atr>0?atr*0.65:s),lot=NormalizeLots(g_state.lotSize*MathMax(0.5,1.0-CalculateVolatility()*0.35));for(int i=1;i<=g_state.gridLevels;i++){PlaceGridOrder(ORDER_TYPE_SELL_STOP,NormalizeDouble(b-step*i,_Digits),lot);if(i<=MathMax(1,g_state.gridLevels/2))PlaceGridOrder(ORDER_TYPE_SELL_LIMIT,NormalizeDouble(b+step*(0.35*i),_Digits),lot);}}
void CreateBidirectionalGrid(double b,double s){double atr=GetCurrentATRPrice(),step=MathMax(s,atr>0?atr*0.70:s),v=CalculateVolatility(),lot=NormalizeLots(g_state.lotSize*MathMax(0.45,1.0-v*0.45));for(int i=1;i<=g_state.gridLevels;i++){PlaceGridOrder(ORDER_TYPE_BUY_STOP,NormalizeDouble(b+step*i,_Digits),lot);PlaceGridOrder(ORDER_TYPE_SELL_STOP,NormalizeDouble(b-step*i,_Digits),lot);}}
void CreateLadderGrid(double b,double s){for(int i=1;i<=g_state.gridLevels;i++){double d=s*(i+0.5*i*(i-1)/(double)MathMax(1,g_state.gridLevels)),l=NormalizeLots(g_state.lotSize*(1.0-0.25*(double)(i-1)/MathMax(1,g_state.gridLevels)));PlaceGridOrder(ORDER_TYPE_BUY_STOP,NormalizeDouble(b+d,_Digits),l);PlaceGridOrder(ORDER_TYPE_SELL_STOP,NormalizeDouble(b-d,_Digits),l);}}
void CreateAntiMartingaleGrid(double b,double s){double wb=1.0;if(g_state.predictionAccuracy>0.60)wb=1.0+MathMin(0.50,(g_state.predictionAccuracy-0.60)*1.5);double v=CalculateVolatility();for(int i=1;i<=g_state.gridLevels;i++){double prog=MathPow(1.0+0.08*wb,i-1),l=NormalizeLots(g_state.lotSize*prog*MathMax(0.5,1.0-v*0.35));PlaceGridOrder(ORDER_TYPE_BUY_STOP,NormalizeDouble(b+s*i,_Digits),l);PlaceGridOrder(ORDER_TYPE_SELL_STOP,NormalizeDouble(b-s*i,_Digits),l);}}
void CreateRangeScalingGrid(double b,double s){double tr=CalculateTrendStrength();if(tr>0.58||tr<0.42){CreateHybridGrid(b,s);return;}double atr=GetCurrentATRPrice(),step=MathMax(s,atr>0?atr*0.50:s);for(int i=1;i<=g_state.gridLevels;i++){double sc=1.0+0.20*(i-1),d=step*i*sc,l=NormalizeLots(g_state.lotSize*MathMax(0.5,1.0-0.08*(i-1)));PlaceGridOrder(ORDER_TYPE_BUY_LIMIT,NormalizeDouble(b-d,_Digits),l);PlaceGridOrder(ORDER_TYPE_SELL_LIMIT,NormalizeDouble(b+d,_Digits),l);}}
void CreateVolatilityBreakoutGrid(double b,double s){double atr=GetCurrentATRPrice();if(atr<=0){CreateBreakoutGrid(b,s);return;}double step=MathMax(s,atr),v=CalculateVolatility();for(int i=1;i<=MathMax(2,g_state.gridLevels);i++){double d=step*(0.75+0.35*(i-1)),l=NormalizeLots(g_state.lotSize*MathMax(0.40,1.0-v*0.50));PlaceGridOrder(ORDER_TYPE_BUY_STOP,NormalizeDouble(b+d,_Digits),l);PlaceGridOrder(ORDER_TYPE_SELL_STOP,NormalizeDouble(b-d,_Digits),l);}}
int CurrentServerHour(){MqlDateTime dt;TimeToStruct(TimeCurrent(),dt);return dt.hour;}
void CreateSessionGrid(double b,double s){int h=CurrentServerHour();double f=0.75;if(h>=7&&h<13)f=1.0;else if(h>=13&&h<18)f=1.2;else if(h>=18&&h<22)f=1.05;CreateBidirectionalGrid(b,s*f);}
void CreateSmartRegimeGrid(double b,double s){double tr=CalculateTrendStrength(),v=CalculateVolatility(),sent=CalculateSentiment();if(tr>=0.68&&sent>=0.55)CreateBullishGrid(b,s);else if(tr<=0.32&&sent<=0.45)CreateBearishGrid(b,s);else if(v>=0.70)CreateVolatilityBreakoutGrid(b,s);else if(tr>=0.45&&tr<=0.55)CreateRangeScalingGrid(b,s);else CreateBidirectionalGrid(b,s);}

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

void CaptureOrderTelemetry(ENUM_ORDER_TYPE type,double price,double lots,uint retcode,string text,int retries,ulong latencyMs)
{
   g_state.lastOrderLatencyMs=latencyMs;g_state.lastOrderRetcode=retcode;g_state.lastOrderRetcodeText=text;g_state.lastOrderType=EnumToString(type);g_state.lastOrderPrice=price;g_state.lastOrderLots=lots;g_state.lastOrderRetryCount=retries;
}

// -------------------- ORDER HELPERS -----------------------------
double GetStopDistancePrice(){double p=PipSize(),point=SymbolInfoDouble(_Symbol,SYMBOL_POINT);long stops=(long)SymbolInfoInteger(_Symbol,SYMBOL_TRADE_STOPS_LEVEL);return MathMax(stops*point,g_state.stopLossPips>0?g_state.stopLossPips*p:0.0);}
double GetTakeDistancePrice(){return g_state.takeProfitPips>0?g_state.takeProfitPips*PipSize():0.0;}
double RiskAdjustedLot(double requested,double dist){double lot=NormalizeLots(requested);if(!g_state.useDynamicRiskLot||dist<=0)return lot;double eq=AccountInfoDouble(ACCOUNT_EQUITY),riskMoney=eq*g_state.riskPerGridPct/100.0,tickSize=SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE),tickValue=SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_VALUE);if(tickSize<=0||tickValue<=0)return lot;double perLot=(dist/tickSize)*tickValue;if(perLot<=0)return lot;return NormalizeLots(MathMin(lot,riskMoney/perLot));}
bool ValidatePendingPrice(ENUM_ORDER_TYPE type,double price){if(!g_state.validateStops)return true;MqlTick t;if(!SymbolInfoTick(_Symbol,t))return false;double md=(double)SymbolInfoInteger(_Symbol,SYMBOL_TRADE_STOPS_LEVEL)*SymbolInfoDouble(_Symbol,SYMBOL_POINT);if(type==ORDER_TYPE_BUY_STOP)return price-t.ask>=md;if(type==ORDER_TYPE_SELL_STOP)return t.bid-price>=md;if(type==ORDER_TYPE_BUY_LIMIT)return t.ask-price>=md;if(type==ORDER_TYPE_SELL_LIMIT)return price-t.bid>=md;return false;}
bool PlaceManagedMarketOrder(bool buy,double requested,string comment)
{
   if(GetPositionCount()>=g_state.maxPositions){g_state.rejectedOrders++;RecordEvent("ORDER_GUARD","Market order blocked | max positions reached");return false;}
   MqlTick t;if(!SymbolInfoTick(_Symbol,t)){g_state.rejectedOrders++;RecordEvent("ORDER_GUARD","Market order blocked | no tick");return false;}
   double e=buy?t.ask:t.bid,sd=g_state.useStopLossForNewOrders?GetStopDistancePrice():0,td=g_state.useTakeProfitForNewOrders?GetTakeDistancePrice():0,sl=0,tp=0;
   if(sd>0)sl=NormalizeDouble(buy?e-sd:e+sd,_Digits);if(td>0)tp=NormalizeDouble(buy?e+td:e-td,_Digits);
   double lot=CalculateAdaptiveLot(requested);if(g_state.riskManagedTrading)lot=RiskAdjustedLot(lot,sd>0?sd:MathMax(PipSize(),g_state.effectiveGridStepPips>0?g_state.effectiveGridStepPips*PipSize():g_state.gridStep*PipSize()));
   if(lot<=0){g_state.rejectedOrders++;RecordEvent("ORDER_GUARD","Market order blocked | effective lot is zero");return false;}
   if(g_state.exposureManager&&g_state.maxTotalLots>0&&CurrentGridExposureLots()+lot>g_state.maxTotalLots+0.0000001){g_state.rejectedOrders++;RecordEvent("ORDER_GUARD","Market order blocked | exposure ceiling");return false;}
   string reason="";if(!ValidateMarketOrderRequest(buy,e,lot,sl,tp,reason)){g_state.rejectedOrders++;if(g_state.orderGuardian)RecordEvent("ORDER_GUARD","Market order blocked | "+reason);return false;}
   trade.SetExpertMagicNumber(InpMagicNumber);trade.SetDeviationInPoints((ulong)MathMax(0,g_state.slippage));trade.SetTypeFillingBySymbol(_Symbol);
   int maxRetry=g_state.smartExecution?g_state.orderRetryCount:0;bool ok=false;uint rc=0;string txt="";ulong startMs=GetTickCount64();int usedRetry=0;
   for(int r=0;r<=maxRetry;r++)
   {
      if(r>0){MqlTick rt;if(SymbolInfoTick(_Symbol,rt)){e=buy?rt.ask:rt.bid;if(sd>0)sl=NormalizeDouble(buy?e-sd:e+sd,_Digits);if(td>0)tp=NormalizeDouble(buy?e+td:e-td,_Digits);}if(!ValidateMarketOrderRequest(buy,e,lot,sl,tp,reason)){txt=reason;break;}usedRetry=r;}
      ok=buy?trade.Buy(lot,_Symbol,0,sl,tp,comment):trade.Sell(lot,_Symbol,0,sl,tp,comment);rc=(uint)trade.ResultRetcode();txt=trade.ResultRetcodeDescription();if(ok||!IsRetryableTradeRetcode(rc))break;
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
   if(g_state.useStopLossForNewOrders&&sl==0&&sd>0)sl=NormalizeDouble(buy?price-sd:price+sd,_Digits);else if(!g_state.useStopLossForNewOrders)sl=0;if(g_state.useTakeProfitForNewOrders&&tp==0&&td>0)tp=NormalizeDouble(buy?price+td:price-td,_Digits);else if(!g_state.useTakeProfitForNewOrders)tp=0;
   double bid=SymbolInfoDouble(_Symbol,SYMBOL_BID),lot=CalculateAdaptiveLot(lots);if(g_state.riskManagedTrading)lot=RiskAdjustedLot(lot,sd>0?sd:MathMax(PipSize(),MathAbs(price-bid)));if(lot<=0){g_state.rejectedOrders++;RecordEvent("ORDER_GUARD",EnumToString(type)+" effective lot is zero");return false;}
   if(g_state.exposureManager&&g_state.maxTotalLots>0&&CurrentGridExposureLots()+lot>g_state.maxTotalLots+0.0000001){g_state.rejectedOrders++;RecordEvent("ORDER_GUARD",EnumToString(type)+" exposure ceiling");return false;}
   string reason="";if(!ValidatePendingOrderRequest(type,price,lot,sl,tp,reason)){g_state.rejectedOrders++;if(g_state.orderGuardian)RecordEvent("ORDER_GUARD",EnumToString(type)+" blocked | "+reason);return false;}
   trade.SetExpertMagicNumber(InpMagicNumber);trade.SetDeviationInPoints((ulong)MathMax(0,g_state.slippage));trade.SetTypeFillingBySymbol(_Symbol);
   int maxRetry=g_state.smartExecution?g_state.orderRetryCount:0;bool ok=false;uint rc=0;string txt="";ulong startMs=GetTickCount64();int usedRetry=0;
   for(int r=0;r<=maxRetry;r++){if(r>0){if(!ValidatePendingOrderRequest(type,price,lot,sl,tp,reason)){txt=reason;break;}usedRetry=r;}
      if(type==ORDER_TYPE_BUY_STOP)ok=trade.BuyStop(lot,price,_Symbol,sl,tp,ORDER_TIME_GTC,0,"UG7 BUY STOP");else if(type==ORDER_TYPE_SELL_STOP)ok=trade.SellStop(lot,price,_Symbol,sl,tp,ORDER_TIME_GTC,0,"UG7 SELL STOP");else if(type==ORDER_TYPE_BUY_LIMIT)ok=trade.BuyLimit(lot,price,_Symbol,sl,tp,ORDER_TIME_GTC,0,"UG7 BUY LIMIT");else if(type==ORDER_TYPE_SELL_LIMIT)ok=trade.SellLimit(lot,price,_Symbol,sl,tp,ORDER_TIME_GTC,0,"UG7 SELL LIMIT");
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
         if(CalculateTrendStrength()>=0.68&&CalculateSentiment()>=0.55) return n+MathMax(1,n/2);
         if(CalculateTrendStrength()<=0.32&&CalculateSentiment()<=0.45) return n+MathMax(1,n/2);
         if(CalculateVolatility()>=0.70) return MathMax(2,n)*2;
         return n*2;
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

void CreateGrid()
{
   if(g_state.gridActive)return;
   int acceptedBefore=GetPositionCount()+GetPendingCount();
   MqlTick t;if(!SymbolInfoTick(_Symbol,t))return;
   double b=(t.ask+t.bid)/2.0;
   double effectiveStep=CalculateEffectiveGridStepPips();
   int effectiveLevels=CalculateEffectiveGridLevels();
   int oldLevels=g_state.gridLevels; double oldStep=g_state.gridStep;
   g_state.effectiveGridStepPips=effectiveStep; g_state.effectiveGridLevels=effectiveLevels;
   double s=effectiveStep*PipSize();
   if(g_state.useATRSpacing && !g_state.adaptiveGrid && g_state.atrPrice>0) s=MathMax(g_state.minGridStep*PipSize(),MathMin(g_state.maxGridStep*PipSize(),g_state.atrPrice*g_state.atrSpacingMultiplier));
   if(g_state.adaptiveLevels) g_state.gridLevels=effectiveLevels;
   if(g_state.gridCycleId==0)g_state.gridCycleId=1;else g_state.gridCycleId++;
   g_state.lifecycleFillCount=0;g_state.lifecycleDeleteCount=0;g_state.gridLifecycleState="DEPLOYING";g_state.gridLifecycleReason=GridLifecycleModel(g_state.gridType);
   trade.SetExpertMagicNumber(InpMagicNumber);
   switch(g_state.gridType){case BASIC_GRID:CreateBasicGrid(b,s);break;case HEDGE_GRID:CreateHedgeGrid(b,s);break;case TREND_GRID:CreateTrendGrid(b,s);break;case VOLATILITY_GRID:CreateVolatilityGrid(b,s);break;case AI_GRID:CreateAIGrid(b,s);break;case GEOMETRIC_GRID:CreateGeometricGrid(b,s);break;case FIBONACCI_GRID:CreateFibonacciGrid(b,s);break;case ATR_ADAPTIVE_GRID:CreateATRAdaptiveGrid(b,s);break;case MEAN_REVERSION_GRID:CreateMeanReversionGrid(b,s);break;case BREAKOUT_GRID:CreateBreakoutGrid(b,s);break;case MOMENTUM_GRID:CreateMomentumGrid(b,s);break;case HYBRID_GRID:CreateHybridGrid(b,s);break;case BULLISH_GRID:CreateBullishGrid(b,s);break;case BEARISH_GRID:CreateBearishGrid(b,s);break;case BIDIRECTIONAL_GRID:CreateBidirectionalGrid(b,s);break;case LADDER_GRID:CreateLadderGrid(b,s);break;case ANTI_MARTINGALE_GRID:CreateAntiMartingaleGrid(b,s);break;case RANGE_SCALING_GRID:CreateRangeScalingGrid(b,s);break;case VOLATILITY_BREAKOUT_GRID:CreateVolatilityBreakoutGrid(b,s);break;case SESSION_GRID:CreateSessionGrid(b,s);break;case SMART_REGIME_GRID:CreateSmartRegimeGrid(b,s);break;}
   if(g_state.adaptiveLevels)g_state.gridLevels=oldLevels;
   g_state.effectiveGridLevels=effectiveLevels;
   g_state.positionCount=GetPositionCount();g_state.pendingCount=GetPendingCount();
   if(g_state.positionCount==0&&g_state.pendingCount==0){g_state.gridActive=false;g_state.executionStatus="NO ORDERS ACCEPTED";SetAction(IsAutonomousControl()?"AUTONOMOUS":"USER","GRID FAILED","No orders accepted");return;}
   AuditGridDeployment(g_state.gridLevels,acceptedBefore);
   g_state.gridActive=true;g_state.startTime=TimeCurrent();g_state.initialEquity=AccountInfoDouble(ACCOUNT_EQUITY);g_state.anchorPrice=b;g_state.executionStatus="GRID ACTIVE";
   if(IsAutonomousControl())g_state.autonomousGridsToday++;
   g_state.gridLifecycleState="ACTIVE";
   g_state.gridLifecycleReason=GridLifecycleModel(g_state.gridType);
   SetAction(IsAutonomousControl()?"AUTONOMOUS":"USER","GRID DEPLOYED",IsAutonomousControl()?"Autonomous deployment":"Manual START command");
    RecordEvent("GRID STRATEGY",StringFormat("%s | %s | %s | %s",CompactGridName(g_state.gridType),GridStrategyName(g_state.gridType),GridDistanceModel(g_state.gridType),GridSpecialRule(g_state.gridType)));
    RecordEvent("GRID POLICY",StringFormat("Step x%.2f | Lot x%.2f | %s",g_state.gridPolicyStepFactor,g_state.gridPolicyLotFactor,g_state.gridPolicyLevelReason));
   if(MathAbs(effectiveStep-oldStep)>0.01)RecordEvent("ADAPTIVE GRID",StringFormat("Step %.1f -> %.1f pips",oldStep,effectiveStep));
   if(effectiveLevels!=oldLevels)RecordEvent("ADAPTIVE LEVELS",StringFormat("Levels %d -> %d",oldLevels,effectiveLevels));
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
   g_dashboard.diagnosticsSubTab=0;
   g_dashboard.toolsSubTab=0;
   g_dashboard.navOffset=0;
   g_dashboard.settingsPage=0;
   g_dashboard.settingsSubTab=0;
   g_dashboard.settingsSubTab2=0;
   g_dashboard.settingsSubTab3=0;
   g_dashboard.settingsSubTab4=0;
   g_dashboard.settingsSubTab5=0;
   g_dashboard.settingsSubTab6=0;
   g_dashboard.settingsSubTab7=0;
   g_dashboard.isVisible=InpShowDashboard;
   ApplyTheme();
}

void FitDashboard()
{
   int cw=(int)ChartGetInteger(0,CHART_WIDTH_IN_PIXELS);
   int ch=(int)ChartGetInteger(0,CHART_HEIGHT_IN_PIXELS);
   if(cw<220 || ch<220) return;

   // Responsive sizing: reserve chart space and keep every dashboard object inside its frame.
   int maxW=(int)MathFloor((double)cw*0.48);
   int desiredW=MathMax(390,MathMin(600,maxW));
   if(desiredW>cw-12) desiredW=cw-12;
   if(desiredW<300) desiredW=cw-12;
   g_dashboard.width=MathMax(300,desiredW);
   int desiredH=MathMax(300,ch-12);
   g_dashboard.height=MathMin(desiredH,MathMin(760,ch-12));
   g_dashboard.x=6;
   g_dashboard.y=6;
}

int ContentX(){ return g_dashboard.x+MathMax(112,MathMin(124,(int)(g_dashboard.width*0.29))); }
int ContentY(){ return g_dashboard.y+103; }
int ContentW(){ return MathMax(170,g_dashboard.width-(ContentX()-g_dashboard.x)-12); }
int ContentH(){ return MathMax(180,g_dashboard.height-134); }

void DRect(string id,int x,int y,int w,int h,color bg,color border=clrNONE)
{
   if(w<=0 || h<=0) return;
   string n=ObjName(id);
   if(ObjectFind(0,n)<0) ObjectCreate(0,n,OBJ_RECTANGLE_LABEL,0,0,0);
   ObjectSetInteger(0,n,OBJPROP_XDISTANCE,x);
   ObjectSetInteger(0,n,OBJPROP_YDISTANCE,y);
   ObjectSetInteger(0,n,OBJPROP_XSIZE,w);
   ObjectSetInteger(0,n,OBJPROP_YSIZE,h);
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
   ObjectSetInteger(0,n,OBJPROP_XDISTANCE,x);
   ObjectSetInteger(0,n,OBJPROP_YDISTANCE,y);
   ObjectSetInteger(0,n,OBJPROP_FONTSIZE,MathMax(7,fs));
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
   if(w<=8 || h<=8) return;
   string n=ObjName(id);
   if(ObjectFind(0,n)<0) ObjectCreate(0,n,OBJ_BUTTON,0,0,0);
   ObjectSetInteger(0,n,OBJPROP_XDISTANCE,x);
   ObjectSetInteger(0,n,OBJPROP_YDISTANCE,y);
   ObjectSetInteger(0,n,OBJPROP_XSIZE,w);
   ObjectSetInteger(0,n,OBJPROP_YSIZE,h);
   ObjectSetInteger(0,n,OBJPROP_FONTSIZE,MathMax(7,fs));
   ObjectSetString(0,n,OBJPROP_FONT,"Arial Bold");
   ObjectSetString(0,n,OBJPROP_TEXT,text);
   ObjectSetInteger(0,n,OBJPROP_COLOR,COLOR_TEXT);
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
   ObjectSetInteger(0,name,OBJPROP_XDISTANCE,x);
   ObjectSetInteger(0,name,OBJPROP_YDISTANCE,y);
   ObjectSetInteger(0,name,OBJPROP_XSIZE,w);
   ObjectSetInteger(0,name,OBJPROP_YSIZE,20);
   ObjectSetInteger(0,name,OBJPROP_FONTSIZE,8);
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

void DSubTabs(const string &labels[],int count,int selected,string prefix)
{
   int x=ContentX();
   int y=ContentY()+32;
   int w=ContentW();
   int gap=5;
   int cols=count<=4?count:3;
   int rows=(count+cols-1)/cols;
   int bw=(w-gap*(cols-1))/cols;
   int bh=23;

   for(int i=0;i<count;i++)
   {
      int r=i/cols;
      int c=i%cols;
      string id=prefix+IntegerToString(i);
      DButton(id,labels[i],x+c*(bw+gap),y+r*(bh+5),bw,bh,
              i==selected?COLOR_ACCENT:COLOR_PANEL2,i==selected,6);
   }
}

int PageBodyY(int subCount)
{
   int rows=(subCount<=4?1:2);
   return ContentY()+32+rows*28+8;
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

void DashboardHeader()
{
   int x=g_dashboard.x,y=g_dashboard.y,w=g_dashboard.width;
   DRect("ROOT",x,y,w,g_dashboard.height,COLOR_BG,COLOR_ACCENT);
   DRect("HEADER",x+1,y+1,w-2,92,C'8,18,23',COLOR_PANEL2);

   DText("HEADER_TITLE","ULTIMATE GRID EA",x+14,y+8,14,COLOR_GOLD,"Arial Bold");
   DText("HEADER_SUB",
         StringFormat("%s  |  %s  |  %s",_Symbol,EnumToString((ENUM_TIMEFRAMES)_Period),CompactGridName(g_state.gridType)),
         x+14,y+31,7,COLOR_MUTED,"Arial");
   DText("HEADER_STATE",g_state.gridActive?"● LIVE":"● READY",x+w-72,y+8,8,
         g_state.gridActive?COLOR_GREEN:COLOR_MUTED,"Arial Bold");
   DText("HEADER_EQ",StringFormat("EQ %s",FormatNumber(AccountInfoDouble(ACCOUNT_EQUITY))),x+w-205,y+31,7,COLOR_TEXT,"Arial Bold");
   DText("HEADER_PL",StringFormat("P/L %s",FormatNumber(g_state.currentProfit)),x+w-92,y+31,7,
         g_state.currentProfit>=0?COLOR_GREEN:COLOR_RED,"Arial Bold");

   int ax=x+12,ay=y+52,gap=5;
   int bw=MathMax(52,(w-24-4*gap)/5);
   DButton("BTN_START","START",ax,ay,bw,28,COLOR_GREEN,false,7);
   DButton("BTN_REBAL","RE-CENTER",ax+bw+gap,ay,bw,28,COLOR_ACCENT,false,6);
   DButton("BTN_CLOSE_PROFIT","CLOSE +",ax+2*(bw+gap),ay,bw,28,COLOR_GREEN,false,6);
   DButton("BTN_CLOSE_LOSS","CLOSE -",ax+3*(bw+gap),ay,bw,28,COLOR_RED,false,6);
   DButton("BTN_STOP","CLOSE ALL",ax+4*(bw+gap),ay,bw,28,COLOR_RED,false,6);
}

string DashboardNavLabel(int i)
{
   switch(i)
   {
      case 0: return "HOME";
      case 1: return "GRID";
      case 2: return "RISK";
      case 3: return "ANALYTICS";
      case 4: return "AI ENGINE";
      case 5: return "EXECUTION";
      case 6: return "TRADES";
      case 7: return "TRANSPARENCY";
      case 8: return "DIAGNOSTICS";
      case 9: return "TOOLS";
      case 10: return "SETTINGS";
   }
   return "";
}

void DashboardNavigation()
{
   int x=g_dashboard.x+7,y=g_dashboard.y+103;
   int navW=MathMax(96,MathMin(112,(int)(g_dashboard.width*0.27)));
   int navH=g_dashboard.height-134;
   

   DRect("NAV_BG",x,y,navW,navH,C'8,15,19',COLOR_PANEL2);
   DText("NAV_TITLE","COMMAND",x+10,y+10,7,COLOR_MUTED,"Arial Bold");

   // Responsive navigator: show as many entries as the available chart height permits
   // and provide scroll controls when the chart is too short for the full command list.
   int top=y+31;
   int bottom=y+navH-46;
   int available=bottom-top;
   int visible=MathMax(4,MathMin(TAB_COUNT,(available+4)/28));
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
      DButton("NAV_UP","▲",x+6,y+navH-83,(navW-15)/2,22,
              g_dashboard.navOffset>0?COLOR_PANEL2:C'6,11,15',false,7);
      DButton("NAV_DOWN","▼",x+9+(navW-15)/2,y+navH-83,(navW-15)/2,22,
              g_dashboard.navOffset<maxOffset?COLOR_PANEL2:C'6,11,15',false,7);
      DText("NAV_INDEX",StringFormat("%d-%d / %d",g_dashboard.navOffset+1,
            MathMin(TAB_COUNT,g_dashboard.navOffset+visible),TAB_COUNT),
            x+9,y+navH-58,6,COLOR_MUTED,"Arial Bold");
   }

   int sy=y+navH-33;
   DRect("NAV_STATUS",x+8,sy,navW-16,28,COLOR_PANEL,COLOR_PANEL2);
   DText("NAV_STATUS_T","SYSTEM",x+15,sy+4,6,COLOR_MUTED,"Arial Bold");
   DText("NAV_STATUS_V",StringFormat("%s | %s",ControlModeName(g_state.controlMode),g_state.gridActive?"EA ACTIVE":"EA READY"),x+15,sy+15,6,
         g_state.gridActive?COLOR_GREEN:COLOR_TEXT,"Arial Bold");
}

void DashboardFooter()
{
   int x=g_dashboard.x+7,y=g_dashboard.y+g_dashboard.height-19,w=g_dashboard.width-14;
   DRect("FOOTER",x,y,w,14,C'7,14,18',COLOR_PANEL2);
   DText("FOOTER_TEXT",StringFormat("MAGIC %I64u  |  %s  |  %s",InpMagicNumber,TimeToString(TimeCurrent(),TIME_SECONDS),g_state.executionStatus),x+7,y+2,6,COLOR_MUTED,"Arial");
}

// -------------------- HOME --------------------
void CreateHomeAccount(){int x=ContentX(),y=PageBodyY(5),w=ContentW();DSectionSingle("HOME_ACCOUNT","ACCOUNT",x,y,w,170);DMetric("HA_EQ","EQUITY",FormatNumber(AccountInfoDouble(ACCOUNT_EQUITY)),x+12,y+42,(w-36)/2,COLOR_TEXT);DMetric("HA_BAL","BALANCE",FormatNumber(AccountInfoDouble(ACCOUNT_BALANCE)),x+24+(w-36)/2,y+42,(w-36)/2,COLOR_TEXT);DKV("HA_DAY","TODAY P/L",FormatNumber(g_state.todayProfit),x+14,y+116,70,g_state.todayProfit>=0?COLOR_GREEN:COLOR_RED);}
void CreateHomeGrid(){int x=ContentX(),y=PageBodyY(5),w=ContentW();DSectionSingle("HOME_GRID","GRID STATUS",x,y,w,215);DKV("HG_STATE","STATE",g_state.gridActive?"ACTIVE":"IDLE",x+14,y+42,62,g_state.gridActive?COLOR_GREEN:COLOR_MUTED);DKV("HG_TYPE","TYPE",CompactGridName(g_state.gridType),x+14,y+70,62,COLOR_GOLD);DKV("HG_POS","POSITIONS",StringFormat("%d / %d",g_state.positionCount,g_state.maxPositions),x+14,y+98,62,COLOR_TEXT);DKV("HG_PEND","PENDING",StringFormat("%d / %d",g_state.pendingCount,g_state.maxPendingOrders),x+14,y+126,62,COLOR_GOLD);DKV("HG_ANCHOR","ANCHOR",DoubleToString(g_state.anchorPrice,_Digits),x+14,y+154,62,COLOR_TEXT);DBar("HG_LOAD","POSITION LOAD",g_state.maxPositions>0?100.0*g_state.positionCount/g_state.maxPositions:0,x+14,y+182,w-42,COLOR_TEAL);}
void CreateHomeMarket(){int x=ContentX(),y=PageBodyY(5),w=ContentW();DSectionSingle("HOME_MARKET","MARKET STATE",x,y,w,235);DKV("HM_REG","REGIME",g_state.regime,x+14,y+42,66,COLOR_GOLD);DKV("HM_ATR","ATR",DoubleToString(g_state.atrPrice,_Digits),x+14,y+72,66,COLOR_TEXT);DKV("HM_SPR","SPREAD",StringFormat("%.2f pips",g_state.currentSpreadPips),x+14,y+102,66,(g_state.maxSpreadPips<=0||g_state.currentSpreadPips<=g_state.maxSpreadPips)?COLOR_GREEN:COLOR_RED);DBar("HM_TREND","TREND",g_state.trendStrength*100.0,x+14,y+132,w-42,g_state.trendStrength>=g_state.bullThreshold?COLOR_GREEN:COLOR_TEAL);DBar("HM_VOL","VOLATILITY",g_state.volatilityIndex*100.0,x+14,y+168,w-42,COLOR_ORANGE);DBar("HM_SENT","SENTIMENT",g_state.sentimentScore*100.0,x+14,y+204,w-42,COLOR_TEAL);}
void CreateHomeExposure(){int x=ContentX(),y=PageBodyY(5),w=ContentW();DSectionSingle("HOME_EXPOSURE","EXPOSURE",x,y,w,190);DMetric("HE_PL","OPEN P/L",FormatNumber(g_state.currentProfit),x+12,y+42,(w-36)/3,g_state.currentProfit>=0?COLOR_GREEN:COLOR_RED);DMetric("HE_POS","POSITIONS",IntegerToString(g_state.positionCount),x+24+(w-36)/3,y+42,(w-36)/3,COLOR_TEAL);DMetric("HE_PD","PENDING",IntegerToString(g_state.pendingCount),x+36+2*(w-36)/3,y+42,(w-36)/3,COLOR_GOLD);DKV("HE_BUY","BUY",IntegerToString(g_state.buyPositions),x+14,y+120,58,COLOR_GREEN);DKV("HE_SELL","SELL",IntegerToString(g_state.sellPositions),x+14,y+148,58,COLOR_RED);}
void CreateHomePerformance(){int x=ContentX(),y=PageBodyY(5),w=ContentW();DSectionSingle("HOME_PERF","PERFORMANCE",x,y,w,235);DKV("HP_T","TRADES",IntegerToString(g_state.totalTrades),x+14,y+42,70,COLOR_TEXT);DKV("HP_W","WINS",IntegerToString(g_state.wins),x+14,y+72,70,COLOR_GREEN);DKV("HP_L","LOSSES",IntegerToString(g_state.losses),x+14,y+102,70,COLOR_RED);DKV("HP_WR","WIN RATE",StringFormat("%.1f%%",g_state.winRate),x+14,y+132,70,COLOR_GREEN);DKV("HP_P","TOTAL P/L",FormatNumber(g_state.totalProfit),x+14,y+162,70,g_state.totalProfit>=0?COLOR_GREEN:COLOR_RED);DKV("HP_R","RE-CENTERS",IntegerToString(g_state.rebalances),x+14,y+192,70,COLOR_TEXT);}
void CreateHomeTab(){string s[] = {"ACCOUNT","GRID STATUS","MARKET STATE","EXPOSURE","PERFORMANCE"};DPageTitle("HOME","Live command center");DSubTabs(s,5,g_dashboard.homeSubTab,"HOME_SUB_");switch(g_dashboard.homeSubTab){case 0:CreateHomeAccount();break;case 1:CreateHomeGrid();break;case 2:CreateHomeMarket();break;case 3:CreateHomeExposure();break;case 4:CreateHomePerformance();break;}}

// -------------------- GRID --------------------
void CreateGridCurrent(){int x=ContentX(),y=PageBodyY(4),w=ContentW();DSectionSingle("GRID_CURRENT","CURRENT GRID",x,y,w,255);DKV("GC1","TYPE",CompactGridName(g_state.gridType),x+14,y+42,74,COLOR_GOLD);DKV("GC2","ENTRY",EntryModeName(g_state.entryMode),x+14,y+72,74,COLOR_TEXT);DKV("GC3","LOT",DoubleToString(g_state.lotSize,3),x+14,y+102,74,COLOR_TEXT);DKV("GC4","STEP",StringFormat("%.1f pips",g_state.gridStep),x+14,y+132,74,COLOR_TEXT);DKV("GC5","LEVELS",IntegerToString(g_state.gridLevels),x+14,y+162,74,COLOR_TEXT);DKV("GC6","ATR SPACE",g_state.useATRSpacing?"ON":"OFF",x+14,y+192,74,g_state.useATRSpacing?COLOR_GREEN:COLOR_MUTED);DKV("GC7","RE-CENTER",g_state.autoRecenter?"ON":"OFF",x+14,y+222,74,g_state.autoRecenter?COLOR_GREEN:COLOR_MUTED);}
void CreateGridTypes(){int x=ContentX(),y=PageBodyY(4),w=ContentW(),h=ContentH()-(y-ContentY())-6;DSectionSingle("GRID_TYPES","21 GRID TYPES",x,y,w,h);int cols=2,gapX=7,gapY=5;int bw=(w-28-gapX)/2;int rows=11;int bh=MathMax(22,MathMin(31,(h-44-(rows-1)*gapY)/rows));int by=y+36;for(int i=0;i<GRID_TYPE_COUNT;i++){int r=i/cols,c=i%cols;DButton("GRID_SEL_"+IntegerToString(i),GridButtonLabel(i),x+10+c*(bw+gapX),by+r*(bh+gapY),bw,bh,i==(int)g_state.gridType?COLOR_ACCENT:COLOR_PANEL2,i==(int)g_state.gridType,6);}DText("GRID_TYPES_NOTE","Select a grid type. Existing trades and pending orders are not modified.",x+10,y+h-15,6,COLOR_MUTED,"Arial");}
void CreateGridActions(){int x=ContentX(),y=PageBodyY(4),w=ContentW();DSectionSingle("GRID_ACTIONS","GRID ACTIONS",x,y,w,250);DButton("BTN_GRID_REBUILD","REBUILD GRID",x+14,y+44,w-28,30,COLOR_GOLD,false,7);DButton("BTN_REBAL_GRID","RE-CENTER GRID",x+14,y+82,w-28,30,COLOR_ACCENT,false,7);DButton("BTN_CANCEL_GRID2","CANCEL PENDING",x+14,y+120,w-28,30,COLOR_PANEL2,false,7);DButton("BTN_CLOSE_GRID2","CLOSE ALL GRID",x+14,y+158,w-28,30,COLOR_RED,false,7);DKV("GACT_STATUS","STATUS",g_state.executionStatus,x+14,y+210,60,COLOR_GOLD);}
void CreateGridModeInfo(){int x=ContentX(),y=PageBodyY(4),w=ContentW();DSectionSingle("GRID_INFO","GRID ENGINE STATUS",x,y,w,235);DKV("GI1","ANCHOR",DoubleToString(g_state.anchorPrice,_Digits),x+14,y+42,62,COLOR_TEXT);DKV("GI2","BUY / SELL",StringFormat("%d / %d",g_state.buyPositions,g_state.sellPositions),x+14,y+72,62,COLOR_TEXT);DKV("GI3","BUY PENDING",IntegerToString(g_state.buyPending),x+14,y+102,62,COLOR_GREEN);DKV("GI4","SELL PENDING",IntegerToString(g_state.sellPending),x+14,y+132,62,COLOR_RED);DKV("GI5","AUTONOMOUS",g_state.autonomousMode?"ON":"OFF",x+14,y+162,62,g_state.autonomousMode?COLOR_GREEN:COLOR_MUTED);DKV("GI6","REENTRY",EnumToString(g_state.reentryMode),x+14,y+192,62,COLOR_TEXT);}
void CreateGridStrategyPolicy(){int x=ContentX(),y=PageBodyY(4),w=ContentW(),gap=8,cw=(w-gap)/2;DSectionSingle("GRID_POLICY_A","STRATEGY POLICY",x,y,cw,285);SettingsSectionStatus("GSP_T","TYPE",CompactGridName(g_state.gridType),x+14,y+42,COLOR_GOLD);SettingsSectionStatus("GSP_S","STRATEGY",GridStrategyName(g_state.gridType),x+14,y+72,COLOR_TEXT);SettingsSectionStatus("GSP_D","DIRECTION",GridDirectionModel(g_state.gridType),x+14,y+102,COLOR_TEAL);SettingsSectionStatus("GSP_X","DISTANCE",GridDistanceModel(g_state.gridType),x+14,y+132,COLOR_TEXT);SettingsSectionStatus("GSP_L","LOT MODEL",GridLotModel(g_state.gridType),x+14,y+162,COLOR_TEXT);SettingsSectionStatus("GSP_R","SPECIAL RULE",GridSpecialRule(g_state.gridType),x+14,y+192,COLOR_MUTED);SettingsSectionStatus("GSP_P","ADAPTIVE POLICY",GridAdaptivePolicyReason(g_state.gridType),x+14,y+222,COLOR_GOLD);DSectionSingle("GRID_POLICY_B","LIVE EFFECT",x+cw+gap,y,cw,285);SettingsSectionStatus("GSPE_S","STEP FACTOR",StringFormat("x %.2f",g_state.gridPolicyStepFactor),x+cw+gap+14,y+42,COLOR_TEAL);SettingsSectionStatus("GSPE_L","LOT FACTOR",StringFormat("x %.2f",g_state.gridPolicyLotFactor),x+cw+gap+14,y+72,COLOR_TEAL);SettingsSectionStatus("GSPE_LV","LEVEL POLICY",g_state.gridPolicyLevelReason!=""?g_state.gridPolicyLevelReason:"USER BASE",x+cw+gap+14,y+102,COLOR_TEXT);SettingsSectionStatus("GSPE_ES","EFFECTIVE STEP",StringFormat("%.1f pips",g_state.effectiveGridStepPips),x+cw+gap+14,y+144,COLOR_GOLD);SettingsSectionStatus("GSPE_EL","EFFECTIVE LEVELS",IntegerToString(g_state.effectiveGridLevels),x+cw+gap+14,y+174,COLOR_GOLD);SettingsSectionStatus("GSPE_ELOT","EFFECTIVE LOT",DoubleToString(g_state.effectiveLot,3),x+cw+gap+14,y+204,COLOR_GOLD);DText("GSPE_NOTE","Policy factors activate only when the corresponding optional adaptive engine is ON.",x+cw+gap+14,y+244,6,COLOR_MUTED,"Arial");}
void CreateGridTab(){string s[]={"CURRENT GRID","GRID TYPES","GRID ACTIONS","ENGINE STATUS","STRATEGY POLICY"};DPageTitle("GRID ENGINE","Grid selection, state and controls");DSubTabs(s,5,g_dashboard.gridSubTab,"GRID_SUB_");switch(g_dashboard.gridSubTab){case 0:CreateGridCurrent();break;case 1:CreateGridTypes();break;case 2:CreateGridActions();break;case 3:CreateGridModeInfo();break;case 4:CreateGridStrategyPolicy();break;}}

// -------------------- RISK --------------------
void CreateRiskProfile(){int x=ContentX(),y=PageBodyY(4),w=ContentW();DSectionSingle("RISK_PROFILE","RISK PROFILE",x,y,w,240);DButton("BTN_RISK_MODE","PROFILE  "+RiskModeName(g_state.riskMode),x+14,y+42,w-28,30,COLOR_ACCENT,false,7);DToggle("BTN_RISK_MANAGED","RISK ENGINE",g_state.riskManagedTrading,x+14,y+84,w-28);DToggle("FLG_RISK","DYNAMIC RISK LOT",g_state.useDynamicRiskLot,x+14,y+116,w-28);DKV("RPD","RISK SIZING",g_state.useDynamicRiskLot?"DYNAMIC":"FIXED",x+14,y+148,78,g_state.useDynamicRiskLot?COLOR_TEAL:COLOR_MUTED);DKV("RP1","RISK / GRID",StringFormat("%.2f%%",g_state.riskPerGridPct),x+14,y+160,78,COLOR_TEXT);DKV("RP2","MAX GRID RISK",StringFormat("%.2f%%",g_state.maxGridRiskPct),x+14,y+190,78,COLOR_TEXT);}
void CreateRiskLimits(){int x=ContentX(),y=PageBodyY(4),w=ContentW();DSectionSingle("RISK_LIMITS","RISK LIMITS",x,y,w,255);DKV("RL1","MAX DD",StringFormat("%.2f%%",g_state.maxDrawdownPct),x+14,y+42,82,COLOR_TEXT);DKV("RL2","DAILY LOSS",StringFormat("%.2f%%",g_state.dailyLossLimitPct),x+14,y+72,82,COLOR_TEXT);DKV("RL3","PROFIT LOCK",StringFormat("%.2f%%",g_state.dailyProfitLockPct),x+14,y+102,82,COLOR_TEXT);DKV("RL4","BASKET TP",FormatNumber(g_state.basketTakeProfitUSD),x+14,y+132,82,COLOR_TEXT);DKV("RL5","BASKET SL",FormatNumber(g_state.basketStopLossUSD),x+14,y+162,82,COLOR_TEXT);DBar("RL_DD","DD USED",g_state.maxDrawdownPct>0?g_state.maxDrawdown/g_state.maxDrawdownPct*100.0:0,x+14,y+198,w-42,g_state.maxDrawdown>=g_state.maxDrawdownPct*0.8?COLOR_RED:COLOR_GREEN);}
void CreateRiskProtection(){int x=ContentX(),y=PageBodyY(4),w=ContentW();DSectionSingle("RISK_PROTECTION","ORDER PROTECTION",x,y,w,260);DToggle("BTN_NEW_ORDER_SL","STOP LOSS",g_state.useStopLossForNewOrders,x+14,y+42,w-28);DToggle("BTN_NEW_ORDER_TP","TAKE PROFIT",g_state.useTakeProfitForNewOrders,x+14,y+74,w-28);DToggle("FLG_BE","BREAK EVEN",g_state.breakEven,x+14,y+106,w-28);DToggle("FLG_TRAIL","TRAILING",g_state.trailingStop,x+14,y+138,w-28);DKV("RPR1","SL",StringFormat("%.1f pips",g_state.stopLossPips),x+14,y+180,62,COLOR_TEXT);DKV("RPR2","TP",StringFormat("%.1f pips",g_state.takeProfitPips),x+14,y+210,62,COLOR_TEXT);DKV("RPR3","TRAIL ATR",DoubleToString(g_state.trailingATRMultiple,2),x+14,y+240,62,COLOR_TEXT);}
void CreateRiskSafety(){int x=ContentX(),y=PageBodyY(4),w=ContentW();DSectionSingle("RISK_SAFETY","POSITION SAFETY",x,y,w,255);DKV("RS1","BE TRIGGER",StringFormat("%.1f pips",g_state.breakEvenTriggerPips),x+14,y+42,85,COLOR_TEXT);DKV("RS2","BE OFFSET",StringFormat("%.1f pips",g_state.breakEvenOffsetPips),x+14,y+72,85,COLOR_TEXT);DKV("RS3","MAX HOLD",g_state.maxHoldMinutes>0?StringFormat("%.0f min",g_state.maxHoldMinutes):"UNLIMITED",x+14,y+102,85,COLOR_TEXT);DKV("RS4","OCO",g_state.oco?"ON":"OFF",x+14,y+132,85,g_state.oco?COLOR_GREEN:COLOR_MUTED);DKV("RS5","OPPOSITE",g_state.closeOppositeOnFill?"CLOSE":"KEEP",x+14,y+162,85,g_state.closeOppositeOnFill?COLOR_GREEN:COLOR_MUTED);DToggle("TR_OCO","OCO TOGGLE",g_state.oco,x+14,y+202,w-28);}
void CreateRiskTab(){string s[]={"RISK PROFILE","RISK LIMITS","ORDER PROTECTION","POSITION SAFETY"};DPageTitle("RISK CONTROL","Risk settings and protective state");DSubTabs(s,4,g_dashboard.riskSubTab,"RISK_SUB_");switch(g_dashboard.riskSubTab){case 0:CreateRiskProfile();break;case 1:CreateRiskLimits();break;case 2:CreateRiskProtection();break;case 3:CreateRiskSafety();break;}}

// -------------------- ANALYTICS --------------------
void CreateAnalyticsMarket(){int x=ContentX(),y=PageBodyY(3),w=ContentW();DSectionSingle("AN_MARKET","MARKET STATE",x,y,w,270);DKV("ANM1","REGIME",g_state.regime,x+14,y+42,70,COLOR_GOLD);DBar("ANM2","TREND",g_state.trendStrength*100.0,x+14,y+78,w-42,g_state.trendStrength>=g_state.bullThreshold?COLOR_GREEN:COLOR_TEAL);DBar("ANM3","VOLATILITY",g_state.volatilityIndex*100.0,x+14,y+124,w-42,COLOR_ORANGE);DBar("ANM4","SENTIMENT",g_state.sentimentScore*100.0,x+14,y+170,w-42,COLOR_TEAL);DKV("ANM5","ATR",DoubleToString(g_state.atrPrice,_Digits),x+14,y+216,70,COLOR_TEXT);}
void CreateAnalyticsPerformance(){int x=ContentX(),y=PageBodyY(3),w=ContentW();DSectionSingle("AN_PERF","PERFORMANCE",x,y,w,275);DKV("AP1","TRADES",IntegerToString(g_state.totalTrades),x+14,y+42,72,COLOR_TEXT);DKV("AP2","WINS",IntegerToString(g_state.wins),x+14,y+72,72,COLOR_GREEN);DKV("AP3","LOSSES",IntegerToString(g_state.losses),x+14,y+102,72,COLOR_RED);DKV("AP4","WIN RATE",StringFormat("%.1f%%",g_state.winRate),x+14,y+132,72,COLOR_GREEN);DKV("AP5","TOTAL P/L",FormatNumber(g_state.totalProfit),x+14,y+162,72,g_state.totalProfit>=0?COLOR_GREEN:COLOR_RED);DKV("AP6","RE-CENTERS",IntegerToString(g_state.rebalances),x+14,y+192,72,COLOR_TEXT);DKV("AP7","TODAY P/L",FormatNumber(g_state.todayProfit),x+14,y+222,72,g_state.todayProfit>=0?COLOR_GREEN:COLOR_RED);}
void CreateAnalyticsTelemetry(){int x=ContentX(),y=PageBodyY(3),w=ContentW();DSectionSingle("AN_TELEM","LIVE TELEMETRY",x,y,w,290);DKV("AT1","SYMBOL",_Symbol,x+14,y+42,70,COLOR_GOLD);DKV("AT2","TIMEFRAME",EnumToString((ENUM_TIMEFRAMES)_Period),x+14,y+72,70,COLOR_TEXT);DKV("AT3","SPREAD",StringFormat("%.2f pips",g_state.currentSpreadPips),x+14,y+102,70,(g_state.maxSpreadPips<=0||g_state.currentSpreadPips<=g_state.maxSpreadPips)?COLOR_GREEN:COLOR_RED);DKV("AT4","EQUITY",FormatNumber(AccountInfoDouble(ACCOUNT_EQUITY)),x+14,y+132,70,COLOR_TEXT);DKV("AT5","BALANCE",FormatNumber(AccountInfoDouble(ACCOUNT_BALANCE)),x+14,y+162,70,COLOR_TEXT);DKV("AT6","OPEN P/L",FormatNumber(g_state.currentProfit),x+14,y+192,70,g_state.currentProfit>=0?COLOR_GREEN:COLOR_RED);DKV("AT7","EXECUTION",g_state.executionStatus,x+14,y+222,70,COLOR_GOLD);DBar("AT8","POSITION LOAD",g_state.maxPositions>0?100.0*g_state.positionCount/g_state.maxPositions:0,x+14,y+250,w-42,COLOR_TEAL);}
void CreateAnalyticsTab(){string s[]={"MARKET STATE","PERFORMANCE","LIVE TELEMETRY"};DPageTitle("ANALYTICS","Performance and market telemetry");DSubTabs(s,3,g_dashboard.analyticsSubTab,"AN_SUB_");switch(g_dashboard.analyticsSubTab){case 0:CreateAnalyticsMarket();break;case 1:CreateAnalyticsPerformance();break;case 2:CreateAnalyticsTelemetry();break;}}

// -------------------- AI --------------------
void CreateAICore(){int x=ContentX(),y=PageBodyY(4),w=ContentW();DSectionSingle("AI_CORE","AI CORE",x,y,w,255);DToggle("BTN_AI_TOGGLE","AI ENGINE",g_state.aiEnabled,x+14,y+42,w-28);DToggle("AI_SET_NETWORK","NEURAL NETWORK",g_state.neuralNetwork,x+14,y+76,w-28);DKV("AIC1","CONFIDENCE",StringFormat("%.0f%%",g_state.aiConfidence*100),x+14,y+122,78,COLOR_TEXT);DKV("AIC2","LEARNING PERIOD",IntegerToString(g_state.learningPeriod),x+14,y+152,78,COLOR_TEXT);DKV("AIC3","PREDICTION",StringFormat("%.0f%%",g_state.predictionAccuracy*100),x+14,y+182,78,COLOR_GOLD);}
void CreateAISignal(){int x=ContentX(),y=PageBodyY(4),w=ContentW();DSectionSingle("AI_SIGNAL","AI SIGNAL STATE",x,y,w,275);DKV("AIS1","TREND",StringFormat("%.0f%%",g_state.trendStrength*100),x+14,y+42,76,COLOR_GREEN);DKV("AIS2","SENTIMENT",StringFormat("%.0f%%",g_state.sentimentScore*100),x+14,y+72,76,COLOR_TEAL);DKV("AIS3","VOLATILITY",StringFormat("%.0f%%",g_state.volatilityIndex*100),x+14,y+102,76,COLOR_ORANGE);DKV("AIS4","REGIME",g_state.regime,x+14,y+132,76,COLOR_GOLD);DKV("AIS5","ATR",DoubleToString(g_state.atrPrice,_Digits),x+14,y+162,76,COLOR_TEXT);DBar("AIS6","SUITABILITY",g_state.marketSuitabilityScore*100.0,x+14,y+198,w-42,COLOR_TEAL);DKV("AIS7","CONFIDENCE",StringFormat("%.0f%%",g_state.intelligenceConfidence*100),x+14,y+232,76,COLOR_GOLD);}
void CreateAIThresholds(){int x=ContentX(),y=PageBodyY(4),w=ContentW();DSectionSingle("AI_THRESH","REGIME THRESHOLDS",x,y,w,250);DKV("AIT1","BULL",StringFormat("%.2f",g_state.bullThreshold),x+14,y+42,80,COLOR_GREEN);DKV("AIT2","BEAR",StringFormat("%.2f",g_state.bearThreshold),x+14,y+72,80,COLOR_RED);DKV("AIT3","HIGH VOL",StringFormat("%.2f",g_state.highVolThreshold),x+14,y+102,80,COLOR_ORANGE);DKV("AIT4","LOW VOL",StringFormat("%.2f",g_state.lowVolThreshold),x+14,y+132,80,COLOR_TEAL);DButton("AI_RESET","RESET AI METRICS",x+14,y+178,w-28,30,COLOR_PANEL2,false,7);}
void CreateAIFilters(){int x=ContentX(),y=PageBodyY(4),w=ContentW();DSectionSingle("AI_FILTERS","AUTONOMOUS FILTERS",x,y,w,270);DToggle("AI_SET_REGIME","REGIME FILTER",g_state.regimeFilter,x+14,y+42,w-28);DToggle("AI_SET_AUTO","AUTONOMOUS",g_state.autonomousMode,x+14,y+78,w-28);DToggle("AI_SET_RISK","DYNAMIC RISK LOT",g_state.useDynamicRiskLot,x+14,y+114,w-28);DKV("AIR1","EFFECTIVE LOT",DoubleToString(g_state.effectiveLot,3),x+14,y+151,95,g_state.useDynamicRiskLot?COLOR_TEAL:COLOR_MUTED);DToggle("AI_SET_HIVOL","HIGH VOL PAUSE",g_state.pauseHighVolatility,x+14,y+182,w-28);}
void CreateAITab(){string s[]={"AI CORE","SIGNAL STATE","THRESHOLDS","AUTONOMOUS FILTERS"};DPageTitle("AI ENGINE","AI, regime and autonomous controls");DSubTabs(s,4,g_dashboard.aiSubTab,"AI_SUB_");switch(g_dashboard.aiSubTab){case 0:CreateAICore();break;case 1:CreateAISignal();break;case 2:CreateAIThresholds();break;case 3:CreateAIFilters();break;}}

// -------------------- EXECUTION --------------------
void CreateExecutionHealth(){int x=ContentX(),y=PageBodyY(4),w=ContentW();DSectionSingle("EX_HEALTH","EXECUTION HEALTH",x,y,w,260);DKV("EX1","STATUS",g_state.executionStatus,x+14,y+42,70,COLOR_GOLD);DKV("EX2","SPREAD",StringFormat("%.2f / %.2f",g_state.currentSpreadPips,g_state.maxSpreadPips),x+14,y+72,70,g_state.currentSpreadPips<=g_state.maxSpreadPips?COLOR_GREEN:COLOR_RED);DKV("EX3","SLIPPAGE",IntegerToString(g_state.slippage),x+14,y+102,70,COLOR_TEXT);DKV("EX4","RETRIES",IntegerToString(g_state.orderRetryCount),x+14,y+132,70,COLOR_TEXT);DToggle("BTN_SMART","SMART EXECUTION",g_state.smartExecution,x+14,y+176,w-28);}
void CreateExecutionParameters(){int x=ContentX(),y=PageBodyY(4),w=ContentW();DSectionSingle("EX_PARAMS","EXECUTION PARAMETERS",x,y,w,260);DKV("EP1","DEVIATION",IntegerToString(g_state.slippage),x+14,y+42,90,COLOR_TEXT);DKV("EP2","EXPIRY",g_state.pendingExpiryMinutes>0?StringFormat("%d min",g_state.pendingExpiryMinutes):"GTC",x+14,y+72,90,COLOR_TEXT);DKV("EP3","MAX SPREAD",StringFormat("%.1f pips",g_state.maxSpreadPips),x+14,y+102,90,COLOR_TEXT);DKV("EP4","SMART",g_state.smartExecution?"ON":"OFF",x+14,y+132,90,g_state.smartExecution?COLOR_GREEN:COLOR_MUTED);DToggle("FLG_VALIDATE","VALIDATE STOPS",g_state.validateStops,x+14,y+176,w-28);}
void CreateExecutionFilters(){int x=ContentX(),y=PageBodyY(4),w=ContentW();DSectionSingle("EX_FILTERS","MARKET FILTERS",x,y,w,280);DToggle("FLG_SESSION","SESSION FILTER",g_state.useSessionFilter,x+14,y+42,w-28);DToggle("FLG_WEEK","WEEKEND BLOCK",g_state.avoidWeekend,x+14,y+78,w-28);DToggle("FLG_HIV","HIGH VOL PAUSE",g_state.pauseHighVolatility,x+14,y+114,w-28);DKV("EF1","SESSION HOURS",StringFormat("%02d-%02d",g_state.sessionStartHour,g_state.sessionEndHour),x+14,y+160,90,COLOR_TEXT);DKV("EF2","SERVER HOUR",StringFormat("%02d",CurrentServerHour()),x+14,y+190,90,COLOR_TEXT);}
void CreateExecutionFlow(){int x=ContentX(),y=PageBodyY(4),w=ContentW();DSectionSingle("EX_FLOW","ORDER FLOW",x,y,w,275);DMetric("OF1","ACCEPTED",IntegerToString(g_state.acceptedOrders),x+12,y+42,(w-36)/2,COLOR_GREEN);DMetric("OF2","REJECTED",IntegerToString(g_state.rejectedOrders),x+24+(w-36)/2,y+42,(w-36)/2,g_state.rejectedOrders?COLOR_ORANGE:COLOR_GREEN);DKV("OF3","POSITIONS",IntegerToString(g_state.positionCount),x+14,y+122,72,COLOR_TEAL);DKV("OF4","PENDING",IntegerToString(g_state.pendingCount),x+14,y+152,72,COLOR_GOLD);DBar("OF5","POSITION LOAD",g_state.maxPositions>0?100.0*g_state.positionCount/g_state.maxPositions:0,x+14,y+190,w-42,COLOR_TEAL);DBar("OF6","PENDING LOAD",g_state.maxPendingOrders>0?100.0*g_state.pendingCount/g_state.maxPendingOrders:0,x+14,y+230,w-42,COLOR_GOLD);}
void CreateExecutionTab(){string s[]={"EXECUTION HEALTH","PARAMETERS","MARKET FILTERS","ORDER FLOW"};DPageTitle("EXECUTION","Execution quality and market controls");DSubTabs(s,4,g_dashboard.executionSubTab,"EX_SUB_");switch(g_dashboard.executionSubTab){case 0:CreateExecutionHealth();break;case 1:CreateExecutionParameters();break;case 2:CreateExecutionFilters();break;case 3:CreateExecutionFlow();break;}}

// -------------------- TRADES --------------------
void CreateTradesPositionsPage(){int x=ContentX(),y=PageBodyY(4),w=ContentW();DSectionSingle("TR_POS","POSITIONS",x,y,w,285);DMetric("TP_TOTAL","OPEN POSITIONS",IntegerToString(g_state.positionCount),x+12,y+42,(w-36)/2,COLOR_TEAL);DMetric("TP_PL","OPEN P/L",FormatNumber(g_state.currentProfit),x+24+(w-36)/2,y+42,(w-36)/2,g_state.currentProfit>=0?COLOR_GREEN:COLOR_RED);DKV("TP_BUY","BUY POSITIONS",IntegerToString(g_state.buyPositions),x+14,y+124,92,COLOR_GREEN);DKV("TP_SELL","SELL POSITIONS",IntegerToString(g_state.sellPositions),x+14,y+154,92,COLOR_RED);DKV("TP_CAP","CAPACITY",StringFormat("%d / %d",g_state.positionCount,g_state.maxPositions),x+14,y+184,92,COLOR_TEXT);DBar("TP_LOAD","POSITION LOAD",g_state.maxPositions>0?100.0*g_state.positionCount/g_state.maxPositions:0,x+14,y+224,w-42,COLOR_TEAL);}
void CreateTradesPendingPage(){int x=ContentX(),y=PageBodyY(4),w=ContentW();DSectionSingle("TR_PENDING","PENDING ORDERS",x,y,w,285);DMetric("TN_TOTAL","PENDING",IntegerToString(g_state.pendingCount),x+12,y+42,(w-36)/2,COLOR_GOLD);DMetric("TN_CAP","CAPACITY",StringFormat("%d / %d",g_state.pendingCount,g_state.maxPendingOrders),x+24+(w-36)/2,y+42,(w-36)/2,COLOR_TEXT);DKV("TN_BUY","BUY STOP/LIMIT",IntegerToString(g_state.buyPending),x+14,y+124,100,COLOR_GREEN);DKV("TN_SELL","SELL STOP/LIMIT",IntegerToString(g_state.sellPending),x+14,y+154,100,COLOR_RED);DKV("TN_FRONT","FRONT DIST",StringFormat("%.1f pips",g_state.frontOrderDistancePips),x+14,y+184,100,COLOR_TEXT);DKV("TN_EXP","EXPIRY",g_state.pendingExpiryMinutes>0?StringFormat("%d min",g_state.pendingExpiryMinutes):"GTC",x+14,y+214,100,COLOR_TEXT);DBar("TN_LOAD","PENDING LOAD",g_state.maxPendingOrders>0?100.0*g_state.pendingCount/g_state.maxPendingOrders:0,x+14,y+250,w-42,COLOR_GOLD);}
void CreateTradesActionsPage(){int x=ContentX(),y=PageBodyY(4),w=ContentW();DSectionSingle("TR_ACTIONS","TRADE ACTIONS",x,y,w,285);DButton("TR_CLOSE_PROFIT","CLOSE PROFIT",x+14,y+44,w-28,30,COLOR_GREEN,false,7);DButton("TR_CLOSE_LOSS","CLOSE LOSS",x+14,y+82,w-28,30,COLOR_RED,false,7);DButton("TR_CANCEL","CANCEL PENDING",x+14,y+120,w-28,30,COLOR_PANEL2,false,7);DButton("TR_RECENTER","RE-CENTER",x+14,y+158,w-28,30,COLOR_ACCENT,false,7);DButton("TR_CLOSE_ALL","CLOSE ALL",x+14,y+196,w-28,30,COLOR_RED,false,7);DKV("TAS","STATUS",g_state.executionStatus,x+14,y+244,62,COLOR_GOLD);}
void CreateTradesSafetyPage(){int x=ContentX(),y=PageBodyY(4),w=ContentW();DSectionSingle("TR_SAFETY","TRADE SAFETY",x,y,w,295);DToggle("TR_SL","STOP LOSS",g_state.useStopLossForNewOrders,x+14,y+42,w-28);DToggle("TR_TP","TAKE PROFIT",g_state.useTakeProfitForNewOrders,x+14,y+76,w-28);DToggle("TR_BE","BREAK EVEN",g_state.breakEven,x+14,y+110,w-28);DToggle("TR_TRAIL","TRAILING",g_state.trailingStop,x+14,y+144,w-28);DToggle("TR_RISK","RISK ENGINE",g_state.riskManagedTrading,x+14,y+178,w-28);DToggle("TR_OCO","OCO",g_state.oco,x+14,y+212,w-28);DKV("TS_OP","OPPOSITE",g_state.closeOppositeOnFill?"CLOSE":"KEEP",x+14,y+252,72,g_state.closeOppositeOnFill?COLOR_GREEN:COLOR_MUTED);}
void CreateTradesTab(){string s[]={"POSITIONS","PENDING ORDERS","TRADE ACTIONS","TRADE SAFETY"};DPageTitle("TRADES","Dedicated trade workspaces");DSubTabs(s,4,g_dashboard.tradesSubTab,"TR_SUB_");switch(g_dashboard.tradesSubTab){case 0:CreateTradesPositionsPage();break;case 1:CreateTradesPendingPage();break;case 2:CreateTradesActionsPage();break;case 3:CreateTradesSafetyPage();break;}}

void SettingsCard(string id,string title,string subtitle,int x,int y,int w,int h);
void SettingsSectionStatus(string prefix,string label,string value,int x,int y,color c=clrWhite);
void SettingsPageHeader(string title,string subtitle);
void SettingsColumnField(string id,string label,string value,int x,int y);
// -------------------- TRANSPARENCY --------------------
void CreateTransparencyOverview(){int x=ContentX(),y=PageBodyY(2),w=ContentW(),gap=8,cw=(w-gap)/2;
   DSectionSingle("TRN_OV_A","CONTROL OWNERSHIP",x,y,cw,235);
   SettingsSectionStatus("TRN_MODE","CONTROL MODE",ControlModeName(g_state.controlMode),x+14,y+42,g_state.controlMode==CONTROL_AUTONOMOUS?COLOR_ORANGE:(g_state.controlMode==CONTROL_ASSIST?COLOR_GOLD:COLOR_GREEN));
   SettingsSectionStatus("TRN_GRID","GRID OWNER",g_state.adaptiveGrid?"ADAPTIVE GRID":"USER",x+14,y+74,g_state.adaptiveGrid?COLOR_GOLD:COLOR_GREEN);
   SettingsSectionStatus("TRN_ENTRY","ENTRY OWNER",(IsAutonomousControl()&&g_state.advancedEntryDecision)?"ENTRY ENGINE":"USER",x+14,y+106,(IsAutonomousControl()&&g_state.advancedEntryDecision)?COLOR_GOLD:COLOR_GREEN);
   SettingsSectionStatus("TRN_RISK","LOT OWNER",g_state.adaptiveLot?"ADAPTIVE LOT":"USER",x+14,y+138,g_state.adaptiveLot?COLOR_GOLD:COLOR_GREEN);
    SettingsSectionStatus("TRN_MGMT","POSITION POLICY",g_state.strategyAwareManagement?GridStrategyName(g_state.gridType):"USER FIXED",x+14,y+170,g_state.strategyAwareManagement?COLOR_GOLD:COLOR_GREEN);
    SettingsSectionStatus("TRN_EXIT","EXIT COORD",g_state.strategyExitCoordination?(g_state.exitCoordinationActive?"ACTIVE":"ARMED"):"OFF",x+14,y+202,g_state.strategyExitCoordination?COLOR_GOLD:COLOR_MUTED);
   SettingsSectionStatus("TRN_LAST","LAST ACTION",g_state.lastDecision,x+14,y+170,COLOR_TEXT);
   DSectionSingle("TRN_OV_B","DECISION",x+cw+gap,y,cw,235);
   SettingsSectionStatus("TRD_O","OWNER",g_state.lastActionOwner,x+cw+gap+14,y+42,COLOR_GOLD);
   SettingsSectionStatus("TRD_R","REASON",g_state.lastActionReason,x+cw+gap+14,y+74,COLOR_TEXT);
   SettingsSectionStatus("TRD_T","TIME",g_state.lastActionTime>0?TimeToString(g_state.lastActionTime,TIME_SECONDS):"--",x+cw+gap+14,y+106,COLOR_MUTED);
   SettingsSectionStatus("TRD_D","DECISION",g_state.lastDecision,x+cw+gap+14,y+138,COLOR_TEXT);
   SettingsSectionStatus("TRD_E","ENTRY THROTTLE",g_state.entryThrottleActive?"ACTIVE":"OFF",x+cw+gap+14,y+170,g_state.entryThrottleActive?COLOR_RED:COLOR_GREEN);SettingsSectionStatus("TRD_S","SUITABILITY",StringFormat("%.0f%%",g_state.marketSuitabilityScore*100),x+cw+gap+14,y+202,COLOR_TEAL);
}
void CreateTransparencyEffective(){int x=ContentX(),y=PageBodyY(2),w=ContentW(),gap=8,cw=(w-gap)/2;
   DSectionSingle("TRN_EA","CONFIGURED VS EFFECTIVE",x,y,cw,250);
   SettingsSectionStatus("TE1","GRID STEP",StringFormat("%.1f  →  %.1f",g_state.gridStep,g_state.effectiveGridStepPips),x+14,y+42,COLOR_GOLD);
   SettingsSectionStatus("TE2","LEVELS",StringFormat("%d  →  %d",g_state.gridLevels,g_state.effectiveGridLevels),x+14,y+72,COLOR_GOLD);
   SettingsSectionStatus("TE3","LOT",StringFormat("%.3f  →  %.3f",g_state.lotSize,g_state.effectiveLot),x+14,y+102,COLOR_GOLD);
   SettingsSectionStatus("TE4","EXPOSURE",StringFormat("%.2f / %.2f lots",g_state.totalExposureLots,g_state.maxTotalLots),x+14,y+132,COLOR_TEAL);
   SettingsSectionStatus("TE5","GRID RISK",StringFormat("%.2f%% / %.2f%%",g_state.gridRiskPct,g_state.maxGridRiskPct),x+14,y+162,COLOR_TEXT);
    SettingsSectionStatus("TE5M","POSITION POLICY",g_state.strategyAwareManagement?"STRATEGY-AWARE":"USER FIXED",x+14,y+192,g_state.strategyAwareManagement?COLOR_GOLD:COLOR_GREEN);
   DSectionSingle("TRN_EB","PROTECTION",x+cw+gap,y,cw,250);
   SettingsSectionStatus("TE6","THROTTLE",g_state.entryThrottleActive?"ACTIVE":"OFF",x+cw+gap+14,y+42,g_state.entryThrottleActive?COLOR_RED:COLOR_GREEN);
   SettingsSectionStatus("TE7","REASON",g_state.entryThrottleReason!=""?g_state.entryThrottleReason:"None",x+cw+gap+14,y+72,COLOR_MUTED);
   SettingsSectionStatus("TE8","DD",StringFormat("%.2f%% / %.2f%%",g_state.maxDrawdown,g_state.maxDrawdownPct),x+cw+gap+14,y+102,COLOR_TEXT);
   SettingsSectionStatus("TE9","DAILY P/L",FormatNumber(g_state.todayProfit),x+cw+gap+14,y+132,g_state.todayProfit>=0?COLOR_GREEN:COLOR_RED);
   int y2=y+260;
   DSectionSingle("TRN_GI","GRID PROFILE INTEGRITY",x,y2,w,230);
   SettingsSectionStatus("TGI_TYPE","PROFILE",CompactGridName(g_state.gridType),x+14,y2+42,COLOR_GOLD);
   SettingsSectionStatus("TGI_STRAT","STRATEGY",GridStrategyName(g_state.gridType),x+14,y2+72,COLOR_TEXT);
   SettingsSectionStatus("TGI_DIR","DIRECTION",GridDirectionModel(g_state.gridType),x+14,y2+102,COLOR_TEAL);
   SettingsSectionStatus("TGI_DIST","DISTANCE",GridDistanceModel(g_state.gridType),x+14,y2+132,COLOR_TEXT);
   SettingsSectionStatus("TGI_LOT","LOT MODEL",GridLotModel(g_state.gridType),x+14,y2+162,COLOR_TEXT);
   SettingsSectionStatus("TGI_RULE","SPECIAL RULE",GridSpecialRule(g_state.gridType),x+14,y2+192,COLOR_MUTED);
   SettingsSectionStatus("TGI_ADV","ADVANCED POLICY",GridAdvancedPolicySummary(g_state.gridType),x+14,y2+222,COLOR_GOLD);
    SettingsSectionStatus("TGI_POL","POLICY FACTOR",StringFormat("Step x%.2f | Lot x%.2f",g_state.gridPolicyStepFactor,g_state.gridPolicyLotFactor),x+cw+gap+14,y2+42,COLOR_TEAL);
    SettingsSectionStatus("TGI_LVL","LEVEL POLICY",g_state.gridPolicyLevelReason!=""?g_state.gridPolicyLevelReason:"USER BASE",x+cw+gap+14,y2+72,COLOR_MUTED);
}
void CreateTransparencyActivity(){int x=ContentX(),y=PageBodyY(2),w=ContentW();
   DSectionSingle("TRN_LOG","RECENT EA ACTIVITY",x,y,w,ContentH()-(y-ContentY())-6);
   int rows=MathMin(g_eventCount,12);
   for(int i=0;i<rows;i++){int idx=g_eventCount-1-i;int yy=y+42+i*22;DText("TRNLT_"+IntegerToString(i),g_eventTime[idx],x+12,yy,6,COLOR_MUTED,"Arial");DText("TRNLE_"+IntegerToString(i),g_eventType[idx],x+78,yy,6,COLOR_GOLD,"Arial Bold");DText("TRNLD_"+IntegerToString(i),g_eventDetail[idx],x+190,yy,6,COLOR_TEXT,"Arial");}
   DButton("TRN_CLEAR", "CLEAR JOURNAL",x+w-124,y+8,112,24,COLOR_PANEL2,false,6);
}
void CreateTransparencyTab(){int x=ContentX();DPageTitle("TRANSPARENCY","See who controls the EA, what changed, and why");string s[]={"OVERVIEW","EFFECTIVE VALUES","ACTIVITY"};DSubTabs(s,3,g_dashboard.transparencySubTab,"TRN_SUB_");switch(g_dashboard.transparencySubTab){case 0:CreateTransparencyOverview();break;case 1:CreateTransparencyEffective();break;default:CreateTransparencyActivity();break;}}

void CreateDiagnosticsSystem(){int x=ContentX(),y=PageBodyY(2),w=ContentW(),gap=8,cw=(w-gap)/2;
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
void CreateDiagnosticsJournal(){int x=ContentX(),y=PageBodyY(2),w=ContentW();DSectionSingle("DIA_LOG2","DECISION JOURNAL",x,y,w,ContentH()-(y-ContentY())-6);int rows=MathMin(g_eventCount,12);for(int i=0;i<rows;i++){int idx=g_eventCount-1-i;int yy=y+42+i*22;DText("DLOGT2_"+IntegerToString(i),g_eventTime[idx],x+12,yy,6,COLOR_MUTED,"Arial");DText("DLOGE2_"+IntegerToString(i),g_eventType[idx],x+78,yy,6,COLOR_GOLD,"Arial Bold");DText("DLOGD2_"+IntegerToString(i),g_eventDetail[idx],x+190,yy,6,COLOR_TEXT,"Arial");}DButton("DIA_CLEAR","CLEAR JOURNAL",x+w-124,y+8,112,24,COLOR_PANEL2,false,6);}
void CreateDiagnosticsTab(){DPageTitle("DIAGNOSTICS","Execution health, decisions and live system state");string s[]={"SYSTEM","JOURNAL"};DSubTabs(s,2,g_dashboard.diagnosticsSubTab,"DIA_SUB_");if(g_dashboard.diagnosticsSubTab==0)CreateDiagnosticsSystem();else CreateDiagnosticsJournal();}


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
   DPageTitle("TOOLS","User utilities, safe preview, recovery and system health");
   string s[]={"PROFILE MANAGER","SIMULATION LAB","RECOVERY CENTER","SYSTEM HEALTH"};
   DSubTabs(s,4,g_dashboard.toolsSubTab,"TOOLS_SUB_");
   switch(g_dashboard.toolsSubTab)
   {
      case 0:CreateToolsProfiles();break;
      case 1:CreateToolsSimulation();break;
      case 2:CreateToolsRecovery();break;
      case 3:CreateToolsHealth();break;
   }
}

// -------------------- SETTINGS --------------------
// Two-level luxury settings workspace. 20 dedicated configuration domains are
// distributed across SETTINGS I and SETTINGS II so every domain gets its own tab.

void RunSettingsAuthorityAudit()
{
   int checked=0,passed=0,warn=0,failed=0; string summary="";
   #define AUDIT_FAIL(COND,NAME) {checked++; if(COND)passed++; else {failed++; if(summary!="")summary+=" | ";summary+=NAME;}}
   #define AUDIT_WARN(COND,NAME) {checked++; if(COND)passed++; else {warn++; if(summary!="")summary+=" | ";summary+=NAME;}}
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
   AUDIT_WARN(!g_state.advancedEntryDecision || IsAutonomousControl(),"Advanced Entry inactive outside Autonomous");
   AUDIT_WARN(!g_state.exposureManager || g_state.maxTotalLots>0,"Exposure Manager unlimited");
   AUDIT_WARN(!g_state.smartRecenter || g_state.autoRecenter,"Smart Recenter requires Auto Recenter");
   AUDIT_WARN(!g_state.smartReplenishment || IsReplenishableStopGrid(),"Replenishment not applicable to current grid");
   AUDIT_WARN(g_state.maxAutonomousGridsPerDay>0 || !IsAutonomousControl(),"Autonomous grids/day unlimited");
   AUDIT_WARN(!g_state.useDynamicRiskLot || g_state.riskPerGridPct>0,"Dynamic risk has zero risk budget");
   g_state.settingsAuditChecked=checked; g_state.settingsAuditPassed=passed; g_state.settingsAuditWarnings=warn; g_state.settingsAuditFailed=failed; g_state.settingsAuditTime=TimeCurrent();
   g_state.settingsAuditStatus=failed>0?"FAILED":warn>0?"REVIEW":"PASS";
   g_state.settingsAuditSummary=summary==""?"All audited settings are within valid authority bounds":summary;
   RecordEvent("SETTINGS AUDIT",StringFormat("%s | checked %d | pass %d | warn %d | fail %d",g_state.settingsAuditStatus,checked,passed,warn,failed));
   #undef AUDIT_FAIL
   #undef AUDIT_WARN
}

void CreateSettingsAuthorityPage(int idx)
{
   int x=ContentX(),y=SettingsBodyY(),w=ContentW(),h=SettingsBodyH(),gap=8,cw=(w-gap)/2;
   string title="",sub="";
   switch(idx){
      case 0:title="AUTHORITY OVERVIEW";sub="Single runtime source of truth after Apply";break;
      case 1:title="CORE MAPPING";sub="Grid, spacing and capacity authority";break;
      case 2:title="RISK MAPPING";sub="Risk, protection and governor authority";break;
      case 3:title="INTELLIGENCE MAPPING";sub="AI and adaptive-engine authority";break;
      case 4:title="EXECUTION MAPPING";sub="Execution and session authority";break;
      case 5:title="ADVANCED MAPPING";sub="Advanced-management authority";break;
      case 6:title="LIFECYCLE MAPPING";sub="Lifecycle, recovery and strategy authority";break;
      case 7:title="AUTONOMY MAPPING";sub="Autonomous permissions and hard boundaries";break;
      case 8:title="TOGGLE INTEGRITY";sub="Runtime switches and ownership state";break;
      default:title="APPLY & AUDIT";sub="Commit, validate and verify settings";break;
   }
   SettingsPageHeader(title,sub);
   SettingsCard("SAU_A","AUTHORITY STATUS",title,x,y,cw,h);
   SettingsCard("SAU_B","AUDIT RESULT","Latest configuration authority audit",x+cw+gap,y,cw,h);
   if(idx==0){
      SettingsSectionStatus("SAC1","RUNTIME SOURCE","DASHBOARD + USER APPLY",x+14,y+54,COLOR_GOLD);SettingsSectionStatus("SAC2","MANUAL COMMAND","AUTHORITATIVE",x+14,y+84,COLOR_GREEN);SettingsSectionStatus("SAC3","AUTONOMOUS","OPTIONAL",x+14,y+114,COLOR_TEAL);SettingsSectionStatus("SAC4","HARD LIMITS","AUTHORITATIVE",x+14,y+144,COLOR_GOLD);SettingsSectionStatus("SAC5","ADVANCED ENGINES","OPT-IN",x+14,y+174,COLOR_TEXT);
   } else if(idx==1){SettingsSectionStatus("SACG1","GRID STEP",DoubleToString(g_state.gridStep,1),x+14,y+54,COLOR_TEXT);SettingsSectionStatus("SACG2","LEVELS",IntegerToString(g_state.gridLevels),x+14,y+84,COLOR_TEXT);SettingsSectionStatus("SACG3","LOT",DoubleToString(g_state.lotSize,3),x+14,y+114,COLOR_TEXT);SettingsSectionStatus("SACG4","CAPACITY",StringFormat("%d / %d",g_state.positionCount,g_state.maxPositions),x+14,y+144,COLOR_TEAL);
   } else if(idx==2){SettingsSectionStatus("SACR1","RISK / GRID",StringFormat("%.2f%%",g_state.riskPerGridPct),x+14,y+54,COLOR_GOLD);SettingsSectionStatus("SACR2","MAX GRID RISK",StringFormat("%.2f%%",g_state.maxGridRiskPct),x+14,y+84,COLOR_GOLD);SettingsSectionStatus("SACR3","MAX DD",StringFormat("%.2f%%",g_state.maxDrawdownPct),x+14,y+114,COLOR_TEXT);SettingsSectionStatus("SACR4","DYNAMIC LOT",g_state.useDynamicRiskLot?"ON":"OFF",x+14,y+144,g_state.useDynamicRiskLot?COLOR_TEAL:COLOR_MUTED);
   } else if(idx==3){SettingsSectionStatus("SACI1","AI",g_state.aiEnabled?"ON":"OFF",x+14,y+54,COLOR_GOLD);SettingsSectionStatus("SACI2","ADAPTIVE GRID",g_state.adaptiveGrid?"ON":"OFF",x+14,y+84,COLOR_TEAL);SettingsSectionStatus("SACI3","ADAPTIVE LOT",g_state.adaptiveLot?"ON":"OFF",x+14,y+114,COLOR_TEAL);SettingsSectionStatus("SACI4","SMART REGIME",g_state.smartRegime?"ON":"OFF",x+14,y+144,COLOR_GOLD);
   } else if(idx==4){SettingsSectionStatus("SACE1","SMART EXEC",g_state.smartExecution?"ON":"OFF",x+14,y+54,COLOR_TEXT);SettingsSectionStatus("SACE2","SPREAD",StringFormat("%.1f pips",g_state.maxSpreadPips),x+14,y+84,COLOR_TEXT);SettingsSectionStatus("SACE3","RETRIES",IntegerToString(g_state.orderRetryCount),x+14,y+114,COLOR_TEXT);SettingsSectionStatus("SACE4","SESSION",g_state.useSessionFilter?"ON":"OFF",x+14,y+144,COLOR_TEAL);
   } else if(idx==5){SettingsSectionStatus("SACA1","STRATEGY MGMT",g_state.strategyAwareManagement?"ON":"OFF",x+14,y+54,COLOR_GOLD);SettingsSectionStatus("SACA2","EXIT COORD",g_state.strategyExitCoordination?"ON":"OFF",x+14,y+84,COLOR_GOLD);SettingsSectionStatus("SACA3","ORDER GUARDIAN",g_state.orderGuardian?"ON":"OFF",x+14,y+114,COLOR_TEAL);
   } else if(idx==6){SettingsSectionStatus("SACL1","RECOVERY",g_state.gridRecovery?"ON":"OFF",x+14,y+54,COLOR_GOLD);SettingsSectionStatus("SACL2","REPLENISH",g_state.smartReplenishment?"ON":"OFF",x+14,y+84,COLOR_TEAL);SettingsSectionStatus("SACL3","RECENTER",g_state.smartRecenter?"ON":"OFF",x+14,y+114,COLOR_GOLD);SettingsSectionStatus("SACL4","CYCLE",StringFormat("%I64u",g_state.gridCycleId),x+14,y+144,COLOR_TEXT);
   } else if(idx==7){SettingsSectionStatus("SAAU1","CONTROL",ControlModeName(g_state.controlMode),x+14,y+54,COLOR_GOLD);SettingsSectionStatus("SAAU2","ENTRY ENGINE",g_state.advancedEntryDecision?"ON":"OFF",x+14,y+84,COLOR_GOLD);SettingsSectionStatus("SAAU3","MAX GRIDS/DAY",g_state.maxAutonomousGridsPerDay>0?IntegerToString(g_state.maxAutonomousGridsPerDay):"UNLIMITED",x+14,y+114,COLOR_TEXT);SettingsSectionStatus("SAAU4","MAX LOTS",g_state.maxTotalLots>0?DoubleToString(g_state.maxTotalLots,2):"UNLIMITED",x+14,y+144,COLOR_TEXT);
   } else if(idx==8){SettingsSectionStatus("SAUT1","SL / TP",StringFormat("%s / %s",g_state.useStopLossForNewOrders?"ON":"OFF",g_state.useTakeProfitForNewOrders?"ON":"OFF"),x+14,y+54,COLOR_TEXT);SettingsSectionStatus("SAUT2","BE / TRAIL",StringFormat("%s / %s",g_state.breakEven?"ON":"OFF",g_state.trailingStop?"ON":"OFF"),x+14,y+84,COLOR_TEXT);SettingsSectionStatus("SAUT3","OCO",g_state.oco?"ON":"OFF",x+14,y+114,COLOR_TEXT);SettingsSectionStatus("SAUT4","PERSISTENCE",g_state.persistRuntimeState?"ON":"OFF",x+14,y+144,COLOR_TEAL);SettingsSectionStatus("SAUT5","AUTO RECOVER",g_state.autoRecoverOnInit?"ON":"OFF",x+14,y+174,COLOR_GOLD);
   } else {SettingsSectionStatus("SAAU5","STATUS",g_state.settingsAuditStatus!=""?g_state.settingsAuditStatus:"NOT RUN",x+14,y+54,g_state.settingsAuditFailed>0?COLOR_RED:(g_state.settingsAuditWarnings>0?COLOR_ORANGE:COLOR_GREEN));SettingsSectionStatus("SAAU6","CHECKED",IntegerToString(g_state.settingsAuditChecked),x+14,y+84,COLOR_TEXT);SettingsSectionStatus("SAAU7","PASSED",IntegerToString(g_state.settingsAuditPassed),x+14,y+114,COLOR_GREEN);SettingsSectionStatus("SAAU8","WARNINGS",IntegerToString(g_state.settingsAuditWarnings),x+14,y+144,COLOR_ORANGE);SettingsSectionStatus("SAAU9","FAILED",IntegerToString(g_state.settingsAuditFailed),x+14,y+174,COLOR_RED);DButton("BTN_SETTINGS_AUDIT","RUN AUTHORITY AUDIT",x+14,y+h-42,cw-28,28,COLOR_ACCENT,false,6);}
   SettingsSectionStatus("SAUR1","RESULT",g_state.settingsAuditStatus!=""?g_state.settingsAuditStatus:"NOT RUN",x+cw+gap+14,y+54,g_state.settingsAuditFailed>0?COLOR_RED:(g_state.settingsAuditWarnings>0?COLOR_ORANGE:COLOR_GREEN));SettingsSectionStatus("SAUR2","TIME",g_state.settingsAuditTime>0?TimeToString(g_state.settingsAuditTime,TIME_SECONDS):"--",x+cw+gap+14,y+84,COLOR_MUTED);SettingsSectionStatus("SAUR3","SUMMARY",g_state.settingsAuditSummary!=""?g_state.settingsAuditSummary:"Run audit to verify",x+cw+gap+14,y+114,COLOR_TEXT);SettingsSectionStatus("SAUR4","GRID OWNER",g_state.adaptiveGrid?"ADAPTIVE":"USER",x+cw+gap+14,y+154,g_state.adaptiveGrid?COLOR_GOLD:COLOR_GREEN);SettingsSectionStatus("SAUR5","LOT OWNER",g_state.adaptiveLot?"ADAPTIVE":"USER",x+cw+gap+14,y+184,g_state.adaptiveLot?COLOR_GOLD:COLOR_GREEN);SettingsSectionStatus("SAUR6","ENTRY OWNER",IsAutonomousControl()&&g_state.advancedEntryDecision?"ENTRY ENGINE":"USER",x+cw+gap+14,y+214,COLOR_GOLD);
}

void CreateSettingsTabBar()
{
   int x=ContentX(),y=ContentY()+30,w=ContentW();
   string p[]={"I","II","III","IV","V","VI","VII"};
   int gap=3,cols=7,pw=MathMax(22,(w-gap*(cols-1))/cols);
   for(int i=0;i<7;i++)
      DButton("SET_PAGE_"+IntegerToString(i),p[i],x+i*(pw+gap),y,pw,25,g_dashboard.settingsPage==i?COLOR_ACCENT:COLOR_PANEL2,g_dashboard.settingsPage==i,6);
   int selected=(g_dashboard.settingsPage==0?g_dashboard.settingsSubTab:
                 g_dashboard.settingsPage==1?g_dashboard.settingsSubTab2:
                 g_dashboard.settingsPage==2?g_dashboard.settingsSubTab3:
                 g_dashboard.settingsPage==3?g_dashboard.settingsSubTab4:
                 g_dashboard.settingsPage==4?g_dashboard.settingsSubTab5:g_dashboard.settingsPage==5?g_dashboard.settingsSubTab6:g_dashboard.settingsSubTab7);
   string labs1[]={"GRID PROFILE","LIVE GRID STATE","BASE SPACING","RECENTER & FRONT ORDER","ORDER CAPACITY","GRID BEHAVIOR","RISK ENGINE","DAILY GOVERNOR","ENTRY PROTECTION","POSITION MANAGEMENT"};
   string labs2[]={"AI CORE","AI TELEMETRY","RISK THRESHOLD","REGIME FILTER","ORDER EXECUTION","RELIABILITY","SESSION CONTROL","MARKET GATES","CHART THEME","CHART OPTIONS"};
   string labs3[]={"ADVANCED MODE","ADAPTIVE GRID","ADAPTIVE LEVELS","ADAPTIVE LOT","SMART ENTRY","MARKET INTELLIGENCE","SMART REGIME","AUTHORITY","AUTONOMY LIMITS","EFFECTIVE STATE"};
   string labs4[]={"SMART RECENTER","SMART REPLENISH","EXPOSURE MANAGER","ADVANCED PROTECTION","GRID RECOVERY","ORDER GUARDIAN","DECISION JOURNAL","PROFILE CONTROL","SIMULATION","SYSTEM HEALTH"};
   string labs5[]={"GRID LIFECYCLE","STRATEGY POLICY","STRATEGY-AWARE MANAGEMENT","EXIT COORDINATION","LIFECYCLE RECOVERY","REPLENISHMENT POLICY","RECENTER POLICY","EXIT POLICY","GRID SESSION CONTROL","LIFECYCLE DIAGNOSTICS"};
   string labs6[]={"AUTONOMOUS CONTROLLER","AUTONOMOUS SCHEDULE","AUTONOMOUS ENTRY","AUTONOMOUS RISK","AUTONOMOUS GRID","STRATEGY SELECTION","AUTONOMOUS EXPOSURE","EMERGENCY CONTROL","DECISION HISTORY","AUTONOMOUS PERFORMANCE"};
   string labs7[]={"AUTHORITY OVERVIEW","CORE MAPPING","RISK MAPPING","INTELLIGENCE MAPPING","EXECUTION MAPPING","ADVANCED MAPPING","LIFECYCLE MAPPING","AUTONOMY MAPPING","TOGGLE INTEGRITY","APPLY & AUDIT"};
   string label=(g_dashboard.settingsPage==0?labs1[selected]:g_dashboard.settingsPage==1?labs2[selected]:g_dashboard.settingsPage==2?labs3[selected]:g_dashboard.settingsPage==3?labs4[selected]:g_dashboard.settingsPage==4?labs5[selected]:g_dashboard.settingsPage==5?labs6[selected]:labs7[selected]);
   int ry=y+33;
   DRect("SET_SUB_RAIL",x,ry,w,31,C'7,14,18',COLOR_PANEL2);
   DButton("SET_PREV","<",x+4,ry+4,28,23,COLOR_PANEL2,false,8);
   DText("SET_SUB_INDEX",StringFormat("%02d / 10",selected+1),x+38,ry+8,6,COLOR_MUTED,"Arial Bold");
   DText("SET_SUB_ACTIVE",label,x+82,ry+8,7,COLOR_GOLD,"Arial Bold");
   DButton("SET_NEXT",">",x+w-32,ry+4,28,23,COLOR_PANEL2,false,8);
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

void CreateAutonomyDomainPage(int idx)
{
   int x=ContentX(),y=SettingsBodyY(),w=ContentW(),h=SettingsBodyH(),gap=8,cw=(w-gap)/2;
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
      default:title="AUTONOMOUS PERFORMANCE";sub="Autonomous trade and grid performance telemetry";break;
   }
   SettingsPageHeader(title,sub);
   SettingsCard("SA_A","CONTROL",title,x,y,cw,h);
   SettingsCard("SA_B","LIVE STATE","Current autonomous telemetry",x+cw+gap,y,cw,h);
   if(idx==0){
      DToggle("AI_SET_AUTO","AUTONOMOUS MODE",g_state.autonomousMode,x+14,y+54,cw-28);
      SettingsSectionStatus("SA_ADV","ENTRY ENGINE",g_state.advancedEntryDecision?"ON":"OFF",x+14,y+104,g_state.advancedEntryDecision?COLOR_GOLD:COLOR_MUTED);
      SettingsSectionStatus("SA_INT","INTELLIGENCE",g_state.marketIntelligence?"ON":"OFF",x+14,y+134,g_state.marketIntelligence?COLOR_TEAL:COLOR_MUTED);
      SettingsSectionStatus("SA_REG","SMART REGIME",g_state.smartRegime?"ON":"OFF",x+14,y+164,g_state.smartRegime?COLOR_GOLD:COLOR_MUTED);
   }else if(idx==1){
      SettingsSectionStatus("SA_S","SESSION FILTER",g_state.useSessionFilter?"ON":"OFF",x+14,y+54,COLOR_TEXT);
      SettingsSectionStatus("SA_SW","WINDOW",StringFormat("%02d:00 - %02d:00",g_state.sessionStartHour,g_state.sessionEndHour),x+14,y+84,COLOR_TEXT);
      SettingsSectionStatus("SA_DAY","GRIDS TODAY",IntegerToString(g_state.autonomousGridsToday),x+14,y+114,COLOR_TEAL);
      SettingsSectionStatus("SA_MAX","MAX / DAY",g_state.maxAutonomousGridsPerDay>0?IntegerToString(g_state.maxAutonomousGridsPerDay):"UNLIMITED",x+14,y+144,COLOR_GOLD);
   }else if(idx==2){
      DToggle("ADV_ENTRY2","ENTRY DECISION ENGINE",g_state.advancedEntryDecision,x+14,y+54,cw-28);
      SettingsSectionStatus("SA_MAN","MANUAL START","NOT FILTERED",x+14,y+104,COLOR_GREEN);
      SettingsSectionStatus("SA_AUTO","AUTONOMOUS",g_state.autonomousMode?"ELIGIBLE":"OFF",x+14,y+134,COLOR_GOLD);
      SettingsSectionStatus("SA_DEC","LAST",g_state.lastDecision,x+14,y+164,COLOR_TEXT);
   }else if(idx==3){
      SettingsSectionStatus("SA_RISK","RISK ENGINE",g_state.riskManagedTrading?"ON":"OFF",x+14,y+54,g_state.riskManagedTrading?COLOR_GREEN:COLOR_MUTED);
      SettingsSectionStatus("SA_DYN","DYNAMIC LOT",g_state.useDynamicRiskLot?"ON":"OFF",x+14,y+84,g_state.useDynamicRiskLot?COLOR_TEAL:COLOR_MUTED);
      SettingsSectionStatus("SA_RMAX","MAX GRID RISK",StringFormat("%.2f%%",g_state.maxGridRiskPct),x+14,y+114,COLOR_GOLD);
      SettingsSectionStatus("SA_DD","MAX DD",StringFormat("%.2f%%",g_state.maxDrawdownPct),x+14,y+144,COLOR_TEXT);
   }else if(idx==4){
      SettingsSectionStatus("SA_G","GRID",CompactGridName(g_state.gridType),x+14,y+54,COLOR_GOLD);
      SettingsSectionStatus("SA_L","LEVELS",IntegerToString(g_state.effectiveGridLevels),x+14,y+84,COLOR_TEXT);
      SettingsSectionStatus("SA_STEP","STEP",StringFormat("%.1f pips",g_state.effectiveGridStepPips),x+14,y+114,COLOR_TEAL);
      SettingsSectionStatus("SA_CAP","CAPACITY",StringFormat("%d / %d",g_state.pendingCount,g_state.maxPendingOrders),x+14,y+144,COLOR_TEXT);
   }else if(idx==5){
      SettingsSectionStatus("SA_SEL","SELECTED",CompactGridName(g_state.gridType),x+14,y+54,COLOR_GOLD);
      SettingsSectionStatus("SA_POLICY","POLICY",GridAdvancedPolicySummary(g_state.gridType),x+14,y+84,COLOR_TEXT);
      SettingsSectionStatus("SA_SM","SMART REGIME",g_state.smartRegime?"ON":"OFF",x+14,y+114,g_state.smartRegime?COLOR_GOLD:COLOR_MUTED);
   }else if(idx==6){
      SettingsSectionStatus("SA_EX","EXPOSURE ENGINE",g_state.exposureManager?"ON":"OFF",x+14,y+54,g_state.exposureManager?COLOR_GREEN:COLOR_MUTED);
      SettingsSectionStatus("SA_MAXL","MAX LOTS",g_state.maxTotalLots>0?DoubleToString(g_state.maxTotalLots,2):"UNLIMITED",x+14,y+84,COLOR_GOLD);
      SettingsSectionStatus("SA_USED","USED LOTS",DoubleToString(g_state.totalExposureLots,2),x+14,y+114,COLOR_TEAL);
      SettingsSectionStatus("SA_UTIL","UTILIZATION",StringFormat("%.1f%%",g_state.exposureUtilizationPct),x+14,y+144,COLOR_TEXT);
   }else if(idx==7){
      SettingsSectionStatus("SA_EP","ADV PROTECTION",g_state.advancedProtection?"ON":"OFF",x+14,y+54,g_state.advancedProtection?COLOR_GREEN:COLOR_MUTED);
      SettingsSectionStatus("SA_TH","THROTTLE",g_state.entryThrottleActive?"ACTIVE":"OFF",x+14,y+84,g_state.entryThrottleActive?COLOR_RED:COLOR_GREEN);
      SettingsSectionStatus("SA_TR","REASON",g_state.entryThrottleReason!=""?g_state.entryThrottleReason:"None",x+14,y+114,COLOR_TEXT);
   }else if(idx==8){
      SettingsSectionStatus("SA_H1","LAST DECISION",g_state.lastDecision,x+14,y+54,COLOR_TEXT);
      SettingsSectionStatus("SA_H2","OWNER",g_state.lastActionOwner,x+14,y+84,COLOR_GOLD);
      SettingsSectionStatus("SA_H3","REASON",g_state.lastActionReason,x+14,y+114,COLOR_MUTED);
      SettingsSectionStatus("SA_H4","TIME",g_state.lastActionTime>0?TimeToString(g_state.lastActionTime,TIME_SECONDS):"--",x+14,y+144,COLOR_TEXT);
   }else{
      SettingsSectionStatus("SA_PT","TRADES",IntegerToString(g_state.totalTrades),x+14,y+54,COLOR_TEXT);
      SettingsSectionStatus("SA_PW","WINS",IntegerToString(g_state.wins),x+14,y+84,COLOR_GREEN);
      SettingsSectionStatus("SA_PL","LOSSES",IntegerToString(g_state.losses),x+14,y+114,COLOR_RED);
      SettingsSectionStatus("SA_WR","WIN RATE",StringFormat("%.1f%%",g_state.winRate),x+14,y+144,COLOR_GOLD);
   }
   SettingsSectionStatus("SA_LIVE","CONTROL",ControlModeName(g_state.controlMode),x+cw+gap+14,y+54,COLOR_GOLD);
   SettingsSectionStatus("SA_REGIME","REGIME",g_state.regime,x+cw+gap+14,y+84,COLOR_TEAL);
   SettingsSectionStatus("SA_SUIT","SUITABILITY",StringFormat("%.0f%%",g_state.marketSuitabilityScore*100),x+cw+gap+14,y+114,COLOR_TEAL);
   SettingsSectionStatus("SA_CONF","CONFIDENCE",StringFormat("%.0f%%",g_state.intelligenceConfidence*100),x+cw+gap+14,y+144,COLOR_GOLD);
}

void CreateSettingsTab(){
   string titles[]={"SETTINGS I","SETTINGS II","SETTINGS III","SETTINGS IV","SETTINGS V","SETTINGS VI","SETTINGS VII"};
   string subs[]={"Normal core grid and user configuration","Normal operational, AI, risk and chart controls","Optional advanced intelligence and autonomy","Optional advanced management and system controls","New lifecycle and strategy-specific controls","Autonomous permissions and intelligence governance","Settings authority, mapping and apply integrity"};
   string title=titles[g_dashboard.settingsPage];
   DPageTitle(title,subs[g_dashboard.settingsPage]);
   CreateSettingsTabBar();
   if(g_dashboard.settingsPage==0){switch(g_dashboard.settingsSubTab){case 0:CreateGridProfileSettingsPage();break;case 1:CreateLiveGridStateSettingsPage();break;case 2:CreateBaseSpacingSettingsPage();break;case 3:CreateRecenterFrontSettingsPage();break;case 4:CreateOrderCapacitySettingsPage();break;case 5:CreateGridBehaviorSettingsPage();break;case 6:CreateRiskEngineSettingsPage();break;case 7:CreateDailyGovernorSettingsPage();break;case 8:CreateEntryProtectionSettingsPage();break;case 9:CreatePositionManagementSettingsPage();break;}}
   else if(g_dashboard.settingsPage==1){switch(g_dashboard.settingsSubTab2){case 0:CreateAICoreSettingsPage();break;case 1:CreateAITelemetrySettingsPage();break;case 2:CreateRiskThresholdSettingsPage();break;case 3:CreateRegimeFilterSettingsPage();break;case 4:CreateOrderExecutionSettingsPage();break;case 5:CreateReliabilitySettingsPage();break;case 6:CreateSessionControlSettingsPage();break;case 7:CreateMarketGatesSettingsPage();break;case 8:CreateChartThemeSettingsPage();break;case 9:CreateChartOptionsSettingsPage();break;}}
   else if(g_dashboard.settingsPage==2){switch(g_dashboard.settingsSubTab3){case 0:CreateAdvancedModeSettingsPage();break;case 1:CreateAdaptiveGridSettingsPage();break;case 2:CreateAdaptiveLevelsSettingsPage();break;case 3:CreateAdaptiveLotSettingsPage();break;case 4:CreateSmartEntrySettingsPage();break;case 5:CreateMarketIntelligenceSettingsPage();break;case 6:CreateSmartRegimeSettingsPage();break;case 7:CreateAuthoritySettingsPage();break;case 8:CreateAutonomyLimitsSettingsPage();break;case 9:CreateEffectiveStateSettingsPage();break;}}
   else if(g_dashboard.settingsPage==3){switch(g_dashboard.settingsSubTab4){case 0:CreateSmartRecenterSettingsPage();break;case 1:CreateSmartReplenishSettingsPage();break;case 2:CreateExposureManagerSettingsPage();break;case 3:CreateAdvancedProtectionSettingsPage();break;case 4:CreateGridRecoverySettingsPage();break;case 5:CreateOrderGuardianSettingsPage();break;case 6:CreateDecisionJournalSettingsPage();break;case 7:CreateProfileControlSettingsPage();break;case 8:CreateSimulationSettingsPage();break;case 9:CreateSystemHealthSettingsPage();break;}}
   else if(g_dashboard.settingsPage==4) CreateLifecycleDomainPage(g_dashboard.settingsSubTab5);
   else if(g_dashboard.settingsPage==5) CreateAutonomyDomainPage(g_dashboard.settingsSubTab6);
   else CreateSettingsAuthorityPage(g_dashboard.settingsSubTab7);
   int bx=ContentX(),by=g_dashboard.y+g_dashboard.height-50;
   DRect("SET_ACTION_BAR",bx,by,ContentW(),34,C'7,15,19',COLOR_PANEL2);
   DButton("BTN_APPLY","APPLY CHANGES",bx+8,by+3,125,28,COLOR_GOLD,false,7);
   DButton("BTN_RESET","RESET",bx+141,by+3,90,28,COLOR_RED,false,7);
   DText("SET_ACTION_NOTE","Live edits are staged • Apply commits them to the trading engine.",bx+242,by+11,6,COLOR_MUTED,"Arial");
}

void CreateDashboard()
{
   if(!g_dashboard.isVisible) return;
   FitDashboard();
   DeleteDashboard();
   DashboardHeader();
   DashboardNavigation();
   switch(g_dashboard.currentTab)
   {
      case 0:CreateHomeTab();break;
      case 1:CreateGridTab();break;
      case 2:CreateRiskTab();break;
      case 3:CreateAnalyticsTab();break;
      case 4:CreateAITab();break;
      case 5:CreateExecutionTab();break;
      case 6:CreateTradesTab();break;
      case 7:CreateTransparencyTab();break;
      case 8:CreateDiagnosticsTab();break;
      case 9:CreateToolsTab();break;
      case 10:CreateSettingsTab();break;
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
   DSet("HEADER_STATE",g_state.gridActive?"● LIVE":"● READY",g_state.gridActive?COLOR_GREEN:COLOR_MUTED);
   DSet("HEADER_EQ",StringFormat("EQ %s",FormatNumber(AccountInfoDouble(ACCOUNT_EQUITY))),COLOR_TEXT);
   DSet("HEADER_PL",StringFormat("P/L %s",FormatNumber(g_state.currentProfit)),g_state.currentProfit>=0?COLOR_GREEN:COLOR_RED);
   DSet("NAV_STATUS_V",StringFormat("%s | %s",ControlModeName(g_state.controlMode),g_state.gridActive?"EA ACTIVE":"EA READY"),g_state.gridActive?COLOR_GREEN:COLOR_TEXT);
   DSet("FOOTER_TEXT",StringFormat("MAGIC %I64u  |  %s  |  %s",InpMagicNumber,TimeToString(TimeCurrent(),TIME_SECONDS),g_state.executionStatus),COLOR_MUTED);
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
   if(ObjectFind(0,name)>=0)
      return ObjectGetString(0,name,OBJPROP_TEXT);
   return "";
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
   trade.SetExpertMagicNumber(InpMagicNumber);
   trade.SetDeviationInPoints((ulong)MathMax(0,g_state.slippage));

   ValidateSettings();
   UpdateConfigurationHealth();
   g_state.executionStatus="SETTINGS APPLIED";
   g_state.lastActionTime=TimeCurrent();
}

bool ValidateSettings(){if(g_state.gridStep<=0)g_state.gridStep=1;if(g_state.minGridStep<=0)g_state.minGridStep=1;if(g_state.maxGridStep<g_state.minGridStep)g_state.maxGridStep=g_state.minGridStep;if(g_state.gridLevels<1)g_state.gridLevels=1;if(g_state.gridLevels>50)g_state.gridLevels=50;if(g_state.lotSize<=0)g_state.lotSize=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN);if(g_state.lotMultiplier<0.1)g_state.lotMultiplier=0.1;if(g_state.maxPositions<1)g_state.maxPositions=1;if(g_state.maxPendingOrders<1)g_state.maxPendingOrders=1;if(g_state.maxSpreadPips<0)g_state.maxSpreadPips=0;if(g_state.riskPerGridPct<0.01)g_state.riskPerGridPct=0.01;if(g_state.riskPerGridPct>100)g_state.riskPerGridPct=100;if(g_state.maxGridRiskPct<0)g_state.maxGridRiskPct=0;if(g_state.maxGridRiskPct>100)g_state.maxGridRiskPct=100;if(g_state.maxDrawdownPct<0.1)g_state.maxDrawdownPct=0.1;if(g_state.stopLossPips<0)g_state.stopLossPips=0;if(g_state.takeProfitPips<0)g_state.takeProfitPips=0;if(g_state.recenterATRMultiple<0.5)g_state.recenterATRMultiple=0.5;if(g_state.frontOrderDistancePips<0.1)g_state.frontOrderDistancePips=0.1;if(g_state.atrSpacingMultiplier<0.1)g_state.atrSpacingMultiplier=0.1;g_state.sessionStartHour=MathMax(0,MathMin(23,g_state.sessionStartHour));g_state.sessionEndHour=MathMax(0,MathMin(23,g_state.sessionEndHour));g_state.orderRetryCount=MathMax(0,MathMin(10,g_state.orderRetryCount));g_state.replenishDelaySeconds=MathMax(0,MathMin(3600,g_state.replenishDelaySeconds));g_state.pendingExpiryMinutes=MathMax(0,g_state.pendingExpiryMinutes);g_state.learningPeriod=MathMax(1,g_state.learningPeriod);g_state.adaptiveSensitivity=ClampDouble(g_state.adaptiveSensitivity,0,1);g_state.maxStepChangePct=ClampDouble(g_state.maxStepChangePct,0,100);if(g_state.maxTotalLots<0)g_state.maxTotalLots=0;g_state.maxAutonomousGridsPerDay=MathMax(0,MathMin(1000,g_state.maxAutonomousGridsPerDay));g_state.autonomousMinSuitability=ClampDouble(g_state.autonomousMinSuitability,0,1);g_state.adaptiveMinLevels=MathMax(1,MathMin(50,g_state.adaptiveMinLevels));g_state.adaptiveMaxLevels=MathMax(g_state.adaptiveMinLevels,MathMin(50,g_state.adaptiveMaxLevels));return true;}

bool IsWeekend(){MqlDateTime dt;TimeToStruct(TimeCurrent(),dt);return dt.day_of_week==0||dt.day_of_week==6;}
bool IsSessionAllowed(){if(g_state.avoidWeekend&&IsWeekend())return false;if(!g_state.useSessionFilter)return true;int h=CurrentServerHour();if(g_state.sessionStartHour==g_state.sessionEndHour)return true;if(g_state.sessionStartHour<g_state.sessionEndHour)return h>=g_state.sessionStartHour&&h<g_state.sessionEndHour;return h>=g_state.sessionStartHour||h<g_state.sessionEndHour;}
datetime DayStart(){MqlDateTime dt;TimeToStruct(TimeCurrent(),dt);dt.hour=0;dt.min=0;dt.sec=0;return StructToTime(dt);}
double CalculateTodayClosedProfit(){datetime f=DayStart(),t=TimeCurrent();if(!HistorySelect(f,t))return 0;double p=0;for(int i=0;i<HistoryDealsTotal();i++){ulong d=HistoryDealGetTicket(i);if(d==0)continue;if(HistoryDealGetString(d,DEAL_SYMBOL)!=_Symbol)continue;if((ulong)HistoryDealGetInteger(d,DEAL_MAGIC)!=InpMagicNumber)continue;if((ENUM_DEAL_ENTRY)HistoryDealGetInteger(d,DEAL_ENTRY)!=DEAL_ENTRY_OUT)continue;p+=HistoryDealGetDouble(d,DEAL_PROFIT)+HistoryDealGetDouble(d,DEAL_SWAP)+HistoryDealGetDouble(d,DEAL_COMMISSION);}return p;}
void UpdatePerformanceStats(){g_state.todayProfit=CalculateTodayClosedProfit();g_state.totalTrades=0;g_state.wins=0;g_state.losses=0;g_state.totalProfit=0;if(!HistorySelect(TimeCurrent()-86400*30,TimeCurrent())){g_state.winRate=0;return;}for(int i=0;i<HistoryDealsTotal();i++){ulong d=HistoryDealGetTicket(i);if(d==0)continue;if(HistoryDealGetString(d,DEAL_SYMBOL)!=_Symbol)continue;if((ulong)HistoryDealGetInteger(d,DEAL_MAGIC)!=InpMagicNumber)continue;if((ENUM_DEAL_ENTRY)HistoryDealGetInteger(d,DEAL_ENTRY)!=DEAL_ENTRY_OUT)continue;double p=HistoryDealGetDouble(d,DEAL_PROFIT)+HistoryDealGetDouble(d,DEAL_SWAP)+HistoryDealGetDouble(d,DEAL_COMMISSION);g_state.totalProfit+=p;g_state.totalTrades++;if(p>=0)g_state.wins++;else g_state.losses++;}g_state.winRate=g_state.totalTrades>0?(double)g_state.wins/g_state.totalTrades*100.0:0;}
double EstimateGridRiskPct(){double eq=AccountInfoDouble(ACCOUNT_EQUITY);if(eq<=0)return 0;double ts=SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE),tv=SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_VALUE),sd=GetStopDistancePrice();if(ts<=0||tv<=0||sd<=0)return 0;double perLot=(sd/ts)*tv,total=0;for(int i=0;i<PositionsTotal();i++){ulong t=PositionGetTicket(i);if(t>0&&IsGridOrder(t,false))total+=PositionGetDouble(POSITION_VOLUME);}return total*perLot/eq*100.0;}
void UpdateExposureMetrics()
{
   g_state.totalOpenLots=0.0;
   g_state.totalPendingLots=0.0;
   for(int i=0;i<PositionsTotal();i++){ulong t=PositionGetTicket(i);if(t>0&&IsGridOrder(t,false))g_state.totalOpenLots+=PositionGetDouble(POSITION_VOLUME);}
   for(int i=0;i<OrdersTotal();i++){ulong t=OrderGetTicket(i);if(t>0&&IsGridOrder(t,true))g_state.totalPendingLots+=OrderGetDouble(ORDER_VOLUME_CURRENT);}
   g_state.totalExposureLots=g_state.totalOpenLots+g_state.totalPendingLots;
   g_state.exposureUtilizationPct=(g_state.exposureManager&&g_state.maxTotalLots>0)?100.0*g_state.totalExposureLots/g_state.maxTotalLots:0.0;
   g_state.gridRiskPct=EstimateGridRiskPct();
   double bal=AccountInfoDouble(ACCOUNT_BALANCE);
   double margin=AccountInfoDouble(ACCOUNT_MARGIN);
   g_state.accountMarginUsedPct=(bal>0)?100.0*margin/bal:0.0;
}
bool RiskGuardBlocksNewGrid(){if(!IsSessionAllowed())return true;if(g_state.maxSpreadPips>0&&g_state.currentSpreadPips>g_state.maxSpreadPips)return true;double eq=AccountInfoDouble(ACCOUNT_EQUITY);if(g_state.peakEquity<=0)g_state.peakEquity=eq;if(eq>g_state.peakEquity)g_state.peakEquity=eq;if(g_state.peakEquity>0)g_state.maxDrawdown=MathMax(g_state.maxDrawdown,(g_state.peakEquity-eq)/g_state.peakEquity*100.0);double bal=AccountInfoDouble(ACCOUNT_BALANCE),dayPct=bal>0?g_state.todayProfit/bal*100.0:0;if(g_state.dailyLossLimitPct>0&&dayPct<=-g_state.dailyLossLimitPct)return true;if(g_state.dailyProfitLockPct>0&&dayPct>=g_state.dailyProfitLockPct)return true;if(g_state.maxDrawdownPct>0&&g_state.maxDrawdown>=g_state.maxDrawdownPct)return true;if(g_state.pauseHighVolatility&&g_state.volatilityIndex>=g_state.highVolThreshold)return true;if(g_state.maxGridRiskPct>0&&EstimateGridRiskPct()>=g_state.maxGridRiskPct)return true;if(g_state.exposureManager&&g_state.maxTotalLots>0&&CurrentGridExposureLots()>=g_state.maxTotalLots)return true;return false;}

// -------------------- POSITION MANAGEMENT ------------------------
void DeletePendingType(ENUM_ORDER_TYPE type){for(int i=OrdersTotal()-1;i>=0;i--){ulong t=OrderGetTicket(i);if(t==0||!IsGridOrder(t,true))continue;if((ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE)==type)trade.OrderDelete(t);}}
void ExpirePendingOrders(){if(g_state.pendingExpiryMinutes<=0)return;datetime now=TimeCurrent();for(int i=OrdersTotal()-1;i>=0;i--){ulong t=OrderGetTicket(i);if(t==0||!IsGridOrder(t,true))continue;datetime setup=(datetime)OrderGetInteger(ORDER_TIME_SETUP);if(setup>0&&(now-setup)>=g_state.pendingExpiryMinutes*60)trade.OrderDelete(t);}}
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
   RecordEvent("COORDINATED EXIT",StringFormat("Cycle %I64u | %s | %s",g_state.gridCycleId,CompactGridName(g_state.gridType),reason));
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
   if(!g_state.oco || !g_state.closeOppositeOnFill || !OCOEligibleForCurrentGrid() || g_state.exitCoordinationActive) return;
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

void ManagePositions(){
   MqlTick tk;
   if(!SymbolInfoTick(_Symbol,tk)) return;
   double pip=PipSize(),atr=GetCurrentATRPrice();

   for(int i=PositionsTotal()-1;i>=0;i--)
   {
      ulong t=PositionGetTicket(i);
      if(t==0 || !IsGridOrder(t,false) || !PositionSelectByTicket(t)) continue;

      long type=PositionGetInteger(POSITION_TYPE);
      double open=PositionGetDouble(POSITION_PRICE_OPEN);
      double sl=PositionGetDouble(POSITION_SL);
      double tp=PositionGetDouble(POSITION_TP);
      double price=type==POSITION_TYPE_BUY?tk.bid:tk.ask;
      datetime ot=(datetime)PositionGetInteger(POSITION_TIME);
      double pp=type==POSITION_TYPE_BUY?(price-open)/pip:(open-price)/pip;
      double newSL=sl;

      if(g_state.useStopLossForNewOrders && g_state.breakEven && pp>=EffectiveBreakEvenTrigger())
      {
         double be=type==POSITION_TYPE_BUY?open+g_state.breakEvenOffsetPips*pip:open-g_state.breakEvenOffsetPips*pip;
         if(type==POSITION_TYPE_BUY && (sl==0 || be>sl)) newSL=be;
         if(type==POSITION_TYPE_SELL && (sl==0 || be<sl)) newSL=be;
      }

      if(g_state.useStopLossForNewOrders && g_state.trailingStop && atr>0)
      {
         double td=atr*EffectiveTrailingATR();
         double tr=type==POSITION_TYPE_BUY?price-td:price+td;
         if(type==POSITION_TYPE_BUY && (newSL==0 || tr>newSL)) newSL=tr;
         if(type==POSITION_TYPE_SELL && (newSL==0 || tr<newSL)) newSL=tr;
      }

      if(newSL!=sl)
         trade.PositionModify(t,NormalizeDouble(newSL,_Digits),tp);

      // Max-hold is part of automatic risk management. It must not close
      // positions when the Risk Engine is OFF.
      if(g_state.riskManagedTrading && g_state.maxHoldMinutes>0 &&
         (TimeCurrent()-ot)>=(long)(EffectiveMaxHoldMinutes()*60.0))
      {
         trade.PositionClose(t,(ulong)MathMax(0,g_state.slippage));
      }
   }
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

   g_state.gridActive=false;
   g_state.startTime=0;
   g_state.anchorPrice=0.0;
   g_state.executionStatus="GRID CLOSED";
   g_state.exitCoordinationActive=false; g_state.exitCoordinationReason=""; g_state.exitCoordinationTime=0;
   g_state.gridLifecycleState="IDLE"; g_state.gridLifecycleReason="Manual/standard close";
}

void ManageGridRisk(){
   g_state.currentProfit=GetGridProfit();

   // All automatic account/grid closure rules are controlled by the Risk Engine.
   // When Risk Engine is OFF, the EA will not call CloseGrid() because of
   // basket targets, drawdown or daily locks.
   if(!g_state.riskManagedTrading) return;

   if(g_state.basketTakeProfitUSD>0 && g_state.currentProfit>=g_state.basketTakeProfitUSD)
   {
      if(g_state.strategyExitCoordination) BeginCoordinatedExit("Basket take-profit reached"); else CloseGrid();
      return;
   }

   if(g_state.basketStopLossUSD>0 && g_state.currentProfit<=-MathAbs(g_state.basketStopLossUSD))
   {
      if(g_state.strategyExitCoordination) BeginCoordinatedExit("Basket stop-loss reached"); else CloseGrid();
      return;
   }

   if(g_state.maxDrawdownPct>0 && g_state.initialEquity>0)
   {
      double eq=AccountInfoDouble(ACCOUNT_EQUITY);
      double dd=(g_state.initialEquity-eq)/g_state.initialEquity*100.0;
      if(dd>=g_state.maxDrawdownPct)
      {
         if(g_state.strategyExitCoordination) BeginCoordinatedExit("Maximum drawdown reached"); else CloseGrid();
         return;
      }
   }

   double bal=AccountInfoDouble(ACCOUNT_BALANCE);
   if(bal>0)
   {
      double dayPct=g_state.todayProfit/bal*100.0;
      if((g_state.dailyLossLimitPct>0 && dayPct<=-g_state.dailyLossLimitPct) ||
         (g_state.dailyProfitLockPct>0 && dayPct>=g_state.dailyProfitLockPct))
      {
         if(g_state.strategyExitCoordination) BeginCoordinatedExit("Daily governor reached"); else CloseGrid();
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
   if(!g_state.smartReplenishment || !g_state.gridActive || g_state.exitCoordinationActive) return;
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
      RecordEvent("GRID REPLENISH",StringFormat("Cycle %I64u | %s | Pending %d/%d",g_state.gridCycleId,g_state.gridLifecycleReason,GetPendingCount(),g_state.maxPendingOrders));
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
   RecordEvent("GRID RECOVERY",StringFormat("Cycle %I64u | Anchor %.5f | %s",g_state.gridCycleId,g_state.anchorPrice,g_state.gridLifecycleReason));
}

void RecenterGrid()
{
   if(!g_state.autoRecenter||!g_state.gridActive||g_state.exitCoordinationActive) return;
   double atr=GetCurrentATRPrice(); if(atr<=0||g_state.anchorPrice<=0) return;
   double oldAnchor=g_state.anchorPrice;
   double mid=(SymbolInfoDouble(_Symbol,SYMBOL_ASK)+SymbolInfoDouble(_Symbol,SYMBOL_BID))/2.0;
   double multiple=g_state.recenterATRMultiple;
   if(g_state.smartRecenter) multiple=ClampDouble(multiple*(1.0+0.35*(g_state.volatilityIndex-0.5)),0.5,5.0);
   if(MathAbs(mid-g_state.anchorPrice)<atr*multiple) return;
   int openPos=GetPositionCount();
   bool preserveStructure=(g_state.gridType==HEDGE_GRID||g_state.gridType==FIBONACCI_GRID||g_state.gridType==GEOMETRIC_GRID||g_state.gridType==LADDER_GRID||g_state.gridType==SMART_REGIME_GRID);
   if(openPos>0 && preserveStructure)
   {
      g_state.gridLifecycleState="RECENTER PENDING";
      g_state.gridLifecycleReason="Open positions retained; structure will be rebuilt around new anchor";
   }
   for(int i=OrdersTotal()-1;i>=0;i--){ulong t=OrderGetTicket(i);if(t>0&&IsGridOrder(t,true)){if(trade.OrderDelete(t))g_state.lifecycleDeleteCount++;}}
   g_state.anchorPrice=mid;
   g_state.rebalances++;
   g_state.gridActive=false;
   g_state.gridLifecycleState="RECENTERING";
   g_state.gridLifecycleReason=GridLifecycleModel(g_state.gridType);
   SetAction(g_state.smartRecenter?"SMART RECENTER":"USER","GRID RECENTER",StringFormat("%.2f ATR | %s",multiple,g_state.gridLifecycleReason));
   RecordEvent("GRID RECENTER",StringFormat("Cycle %I64u | %.5f -> %.5f | %s",g_state.gridCycleId,oldAnchor,mid,g_state.gridLifecycleReason));
   CreateGrid();
}

void CloseProfitPositions(){int c=0,f=0;for(int i=PositionsTotal()-1;i>=0;i--){ulong t=PositionGetTicket(i);if(t==0||!IsGridOrder(t,false)||!PositionSelectByTicket(t))continue;double p=PositionGetDouble(POSITION_PROFIT)+PositionGetDouble(POSITION_SWAP);if(p>0){if(trade.PositionClose(t,(ulong)MathMax(0,g_state.slippage)))c++;else f++;}}g_state.executionStatus=StringFormat("CLOSE PROFIT: %d/%d",c,f);}
void CloseLossPositions(){int c=0,f=0;for(int i=PositionsTotal()-1;i>=0;i--){ulong t=PositionGetTicket(i);if(t==0||!IsGridOrder(t,false)||!PositionSelectByTicket(t))continue;double p=PositionGetDouble(POSITION_PROFIT)+PositionGetDouble(POSITION_SWAP);if(p<0){if(trade.PositionClose(t,(ulong)MathMax(0,g_state.slippage)))c++;else f++;}}g_state.executionStatus=StringFormat("CLOSE LOSS: %d/%d",c,f);}
void CancelPendingGridOrders(){int c=0,f=0;for(int i=OrdersTotal()-1;i>=0;i--){ulong t=OrderGetTicket(i);if(t==0||!IsGridOrder(t,true))continue;if(trade.OrderDelete(t))c++;else f++;}if(GetPositionCount()==0&&GetPendingCount()==0)g_state.gridActive=false;g_state.executionStatus=StringFormat("CANCEL PENDING: %d/%d",c,f);}

// -------------------- STATE / EVENTS -----------------------------

string RuntimeCheckpointFile()
{
   return StringFormat("UG7_Runtime_%s_%I64u.dat",_Symbol,InpMagicNumber);
}
void SaveRuntimeCheckpoint()
{
   if(!g_state.persistRuntimeState) return;
   int h=FileOpen(RuntimeCheckpointFile(),FILE_WRITE|FILE_TXT|FILE_ANSI);
   if(h==INVALID_HANDLE) return;
   FileWrite(h,"VERSION=1170");
   FileWrite(h,"GRIDTYPE="+(string)((int)g_state.gridType));
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
   FileWrite(h,"ADAPTGRID="+(g_state.adaptiveGrid?"1":"0"));
   FileWrite(h,"ADAPTLEVELS="+(g_state.adaptiveLevels?"1":"0"));
   FileWrite(h,"ADAPTLOT="+(g_state.adaptiveLot?"1":"0"));
   FileWrite(h,"SMARTREGIME="+(g_state.smartRegime?"1":"0"));
   FileWrite(h,"SMARTRECENTER="+(g_state.smartRecenter?"1":"0"));
   FileWrite(h,"SMARTREPLENISH="+(g_state.smartReplenishment?"1":"0"));
   FileWrite(h,"RECOVERY="+(g_state.gridRecovery?"1":"0"));
   FileWrite(h,"AUTOGRIDS="+(string)g_state.autonomousGridsToday);
   FileWrite(h,"TIMESTAMP="+(string)TimeCurrent());
   FileClose(h);
   g_state.lastCheckpointTime=TimeCurrent();
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
   string v=ReadCheckpointValue(lines,n,"VERSION"); if(v!="1170") return false;
   string x;
   x=ReadCheckpointValue(lines,n,"GRIDTYPE"); if(x!="") g_state.gridType=(ENUM_GRID_TYPE)(int)StringToInteger(x);
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
   x=ReadCheckpointValue(lines,n,"ADAPTGRID"); if(x!="") g_state.adaptiveGrid=(StringToInteger(x)!=0);
   x=ReadCheckpointValue(lines,n,"ADAPTLEVELS"); if(x!="") g_state.adaptiveLevels=(StringToInteger(x)!=0);
   x=ReadCheckpointValue(lines,n,"ADAPTLOT"); if(x!="") g_state.adaptiveLot=(StringToInteger(x)!=0);
   x=ReadCheckpointValue(lines,n,"SMARTREGIME"); if(x!="") g_state.smartRegime=(StringToInteger(x)!=0);
   x=ReadCheckpointValue(lines,n,"SMARTRECENTER"); if(x!="") g_state.smartRecenter=(StringToInteger(x)!=0);
   x=ReadCheckpointValue(lines,n,"SMARTREPLENISH"); if(x!="") g_state.smartReplenishment=(StringToInteger(x)!=0);
   x=ReadCheckpointValue(lines,n,"RECOVERY"); if(x!="") g_state.gridRecovery=(StringToInteger(x)!=0);
   x=ReadCheckpointValue(lines,n,"AUTOGRIDS"); if(x!="") g_state.autonomousGridsToday=(int)StringToInteger(x);
   g_state.autonomousMode=(g_state.controlMode==CONTROL_AUTONOMOUS);
   g_state.recoveryStatus="CHECKPOINT LOADED"; g_state.recoverySource="LOCAL TERMINAL CHECKPOINT"; g_state.lastRecoveryTime=TimeCurrent();
   RecordEvent("RECOVERY CHECKPOINT","Runtime configuration restored before live-state reconciliation");
   return true;
}
void ReconcileRuntimeAfterRestart()
{
   int pos=GetPositionCount(), pend=GetPendingCount();
   if(pos==0 && pend==0){g_state.gridActive=false;g_state.gridLifecycleState="IDLE";g_state.recoveryStatus="NO LIVE GRID";return;}
   if(!g_state.recoverOrdersAndPositions){g_state.gridActive=true;g_state.recoveryStatus="LIVE STATE DETECTED";return;}
   RecoverGridState();
   g_state.recoveryStatus="LIVE STATE RECONCILED";
   g_state.recoverySource="POSITIONS + PENDING ORDERS";
   RecordEvent("RECOVERY RECONCILED",StringFormat("%d positions / %d pending | %s",pos,pend,CompactGridName(g_state.gridType)));
}
void MaintainRuntimeCheckpoint()
{
   if(!g_state.persistRuntimeState) return;
   if(g_state.checkpointSeconds<=0) return;
   if(g_state.lastCheckpointTime==0 || (TimeCurrent()-g_state.lastCheckpointTime)>=g_state.checkpointSeconds) SaveRuntimeCheckpoint();
}

void InitializeState(){ZeroMemory(g_state);g_state.gridType=InpGridType;g_state.entryMode=InpEntryMode;g_state.riskMode=InpRiskMode;g_state.reentryMode=InpReentryMode;g_state.lotSize=InpLotSize;g_state.gridStep=InpGridStep;g_state.gridLevels=InpGridLevels;g_state.lotMultiplier=InpLotMultiplier;g_state.autonomousMode=InpAutonomousMode;g_state.useATRSpacing=InpUseATRSpacing;g_state.atrSpacingMultiplier=InpATRSpacingMultiplier;g_state.minGridStep=InpMinGridStepPips;g_state.maxGridStep=InpMaxGridStepPips;g_state.recenterATRMultiple=InpRecenterATRMultiple;g_state.autoRecenter=InpAutoRecenter;g_state.aiEnabled=InpEnableAI;g_state.neuralNetwork=InpNeuralNetwork;g_state.aiConfidence=InpAIConfidence;g_state.learningPeriod=InpLearningPeriod;g_state.regimeFilter=InpRegimeFilter;g_state.bullThreshold=InpBullThreshold;g_state.bearThreshold=InpBearThreshold;g_state.highVolThreshold=InpHighVolThreshold;g_state.lowVolThreshold=InpLowVolThreshold;g_state.useDynamicRiskLot=InpUseDynamicRiskLot;g_state.riskManagedTrading=InpRiskManagedTrading;g_state.useStopLossForNewOrders=InpUseStopLossForNewOrders;g_state.useTakeProfitForNewOrders=InpUseTakeProfitForNewOrders;g_state.riskPerGridPct=InpRiskPerGridPct;g_state.maxGridRiskPct=InpMaxGridRiskPct;g_state.maxDrawdownPct=InpMaxDrawdownPct;g_state.dailyLossLimitPct=InpDailyLossLimitPct;g_state.dailyProfitLockPct=InpDailyProfitLockPct;g_state.basketTakeProfitUSD=InpBasketTakeProfitUSD;g_state.basketStopLossUSD=InpBasketStopLossUSD;g_state.stopLossPips=InpStopLossPips;g_state.takeProfitPips=InpTakeProfitPips;g_state.breakEven=InpUseBreakEven;g_state.breakEvenTriggerPips=InpBreakEvenTriggerPips;g_state.breakEvenOffsetPips=InpBreakEvenOffsetPips;g_state.trailingStop=InpTrailingStop;g_state.trailingATRMultiple=InpTrailingATRMultiple;g_state.maxHoldMinutes=InpMaxHoldMinutes;g_state.maxPositions=InpMaxPositions;g_state.maxPendingOrders=InpMaxPendingOrders;g_state.oco=InpOCO;g_state.closeOppositeOnFill=InpCloseOppositePendingOnFill;g_state.slippage=InpSlippage;g_state.maxSpreadPips=InpMaxSpreadPips;g_state.pendingExpiryMinutes=InpPendingExpiryMinutes;g_state.smartExecution=InpSmartExecution;g_state.validateStops=InpValidateStops;g_state.orderRetryCount=InpOrderRetryCount;g_state.useSessionFilter=InpUseSessionFilter;g_state.sessionStartHour=InpSessionStartHour;g_state.sessionEndHour=InpSessionEndHour;g_state.avoidWeekend=InpAvoidWeekend;g_state.pauseHighVolatility=InpPauseOnHighVolatility;g_state.frontOrderDistancePips=InpFrontOrderDistancePips;g_state.gridActive=false;g_state.initialEquity=AccountInfoDouble(ACCOUNT_EQUITY);g_state.peakEquity=g_state.initialEquity;g_state.dayAnchor=DayStart();g_state.regime="UNKNOWN";g_state.executionStatus="READY";g_state.appliedChartTheme=-1;g_state.autoChartTheme=InpAutoChartTheme;g_state.chartThemeMode=InpChartThemeMode;g_state.chartShowGrid=InpChartShowGrid;g_state.chartShowTradeLevels=InpChartShowTradeLevels;g_state.chartAutoScroll=InpChartAutoScroll;g_state.chartShift=InpChartShift;g_state.chartShowVolumes=InpChartShowVolumes;
   g_state.controlMode=InpControlMode; g_state.autonomousMode=(g_state.controlMode==CONTROL_AUTONOMOUS); g_state.strategyAwareManagement=InpStrategyAwareManagement; g_state.strategyExitCoordination=InpStrategyExitCoordination;
   g_state.advancedEntryDecision=InpAdvancedEntryDecision;g_state.adaptiveGrid=InpAdaptiveGrid;g_state.adaptiveLevels=InpAdaptiveLevels;g_state.adaptiveLot=InpAdaptiveLot;g_state.marketIntelligence=InpMarketIntelligence;g_state.smartRegime=InpSmartRegime;g_state.smartRecenter=InpSmartRecenter;g_state.smartReplenishment=InpSmartReplenishment;g_state.exposureManager=InpExposureManager;g_state.advancedProtection=InpAdvancedProtection;g_state.decisionJournal=InpDecisionJournal;g_state.orderGuardian=InpOrderGuardian;
   g_state.adaptiveSensitivity=InpAdaptiveSensitivity;g_state.maxStepChangePct=InpMaxStepChangePct;g_state.maxTotalLots=InpMaxTotalLots;g_state.maxAutonomousGridsPerDay=InpMaxAutonomousGridsPerDay; g_state.autonomousMinSuitability=InpAutonomousMinSuitability; g_state.adaptiveMinLevels=InpAdaptiveMinLevels; g_state.adaptiveMaxLevels=InpAdaptiveMaxLevels;g_state.replenishDelaySeconds=MathMax(0,InpReplenishDelaySeconds);g_state.lastReplenishTime=0;g_state.replenishments=0;g_state.gridRecovery=InpGridRecovery;g_state.autonomousGridsToday=0;
   g_state.effectiveGridStepPips=g_state.gridStep;g_state.effectiveGridLevels=g_state.gridLevels;g_state.effectiveLot=g_state.lotSize;g_state.gridCycleId=0;g_state.lifecycleFillCount=0;g_state.lifecycleDeleteCount=0;g_state.lifecycleRecoveryCount=0;g_state.gridLifecycleState="IDLE";g_state.gridLifecycleReason="Initialization";g_state.exitCoordinationActive=false;g_state.exitCoordinationReason="";g_state.exitCoordinationTime=0;g_state.gridPolicyStepFactor=1.0;g_state.gridPolicyLotFactor=1.0;g_state.gridPolicyReason="USER BASE";g_state.gridPolicyLevelReason="USER BASE";g_state.lastActionOwner="SYSTEM";g_state.lastActionReason="Initialization";g_state.lastDecision="READY";g_state.configWarningCount=0;g_state.configHealth="UNKNOWN";g_state.configWarnings="";g_state.settingsAuditChecked=0;g_state.settingsAuditPassed=0;g_state.settingsAuditWarnings=0;g_state.settingsAuditFailed=0;g_state.settingsAuditTime=0;g_state.settingsAuditStatus="NOT RUN";g_state.settingsAuditSummary="";g_state.lastConfigCheckTime=0;g_state.lastConfigCheckResult="NOT CHECKED";g_state.configCheckSequence=0;g_state.autoRecoverOnInit=InpAutoRecoverOnInit;g_state.persistRuntimeState=InpPersistRuntimeState;g_state.recoverOrdersAndPositions=InpRecoverOrdersAndPositions;g_state.checkpointSeconds=MathMax(0,InpCheckpointSeconds);g_state.lastCheckpointTime=0;g_state.lastRecoveryTime=0;g_state.recoveryStatus="NOT CHECKED";g_state.recoverySource="";g_state.recoveryFile=RuntimeCheckpointFile();ResetEventJournal();
   ValidateSettings();
   UpdateConfigurationHealth();
   RunSettingsAuthorityAudit();}
void UpdateState(){g_state.autonomousMode=(g_state.controlMode==CONTROL_AUTONOMOUS);if(g_state.dayAnchor!=DayStart()){g_state.dayAnchor=DayStart();g_state.autonomousGridsToday=0;RecordEvent("DAY RESET","Autonomous daily counter reset");}g_state.trendStrength=CalculateTrendStrength();g_state.volatilityIndex=CalculateVolatility();g_state.sentimentScore=CalculateSentiment();g_state.atrPrice=GetCurrentATRPrice();MqlTick t;if(SymbolInfoTick(_Symbol,t))g_state.currentSpreadPips=PipSize()>0?(t.ask-t.bid)/PipSize():0; if(g_state.trendStrength>=g_state.bullThreshold)g_state.regime=g_state.volatilityIndex>=g_state.highVolThreshold?"BULL / HIGH VOL":"BULL TREND";else if(g_state.trendStrength<=g_state.bearThreshold)g_state.regime=g_state.volatilityIndex>=g_state.highVolThreshold?"BEAR / HIGH VOL":"BEAR TREND";else if(g_state.volatilityIndex<=g_state.lowVolThreshold)g_state.regime="RANGE / MEAN REV";else if(g_state.volatilityIndex>=g_state.highVolThreshold)g_state.regime="BREAKOUT / HIGH VOL";else g_state.regime="TRANSITION";g_state.positionCount=GetPositionCount();g_state.pendingCount=GetPendingCount();g_state.currentProfit=GetGridProfit();g_state.buyPositions=g_state.sellPositions=g_state.buyPending=g_state.sellPending=0;for(int i=0;i<PositionsTotal();i++){ulong tkt=PositionGetTicket(i);if(tkt>0&&IsGridOrder(tkt,false)){ENUM_POSITION_TYPE p=(ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);if(p==POSITION_TYPE_BUY)g_state.buyPositions++;else if(p==POSITION_TYPE_SELL)g_state.sellPositions++;}}for(int i=0;i<OrdersTotal();i++){ulong ot=OrderGetTicket(i);if(ot>0&&IsGridOrder(ot,true)){ENUM_ORDER_TYPE o=(ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);if(o==ORDER_TYPE_BUY_STOP||o==ORDER_TYPE_BUY_LIMIT)g_state.buyPending++;else if(o==ORDER_TYPE_SELL_STOP||o==ORDER_TYPE_SELL_LIMIT)g_state.sellPending++;}}UpdatePerformanceStats();UpdateExposureMetrics();UpdateEffectiveState();UpdateConfigurationHealth();double eq=AccountInfoDouble(ACCOUNT_EQUITY);if(g_state.peakEquity<=0)g_state.peakEquity=eq;if(eq>g_state.peakEquity)g_state.peakEquity=eq;}
bool ShouldStartGrid(){if(!IsAutonomousControl())return false;if(g_state.gridActive||RiskGuardBlocksNewGrid())return false;if(g_state.entryMode==MANUAL_ENTRY)return false;if(g_state.entryMode==AI_ENTRY&&(!g_state.aiEnabled||(g_state.predictionAccuracy>0&&g_state.predictionAccuracy<g_state.aiConfidence)))return false;if(g_state.advancedEntryDecision){if(!AdvancedAutonomousDecision())return false;}return true;}

void ToggleDynamicRiskLot(const string source)
{
   g_state.useDynamicRiskLot=!g_state.useDynamicRiskLot;
   UpdateEffectiveState();
   SetAction("USER","DYNAMIC RISK LOT",g_state.useDynamicRiskLot?"ON":"OFF");
   g_state.executionStatus=g_state.useDynamicRiskLot?"DYNAMIC RISK ON":"DYNAMIC RISK OFF";
   RecordEvent("RISK",StringFormat("Dynamic risk lot %s via %s | Effective lot %.3f",g_state.useDynamicRiskLot?"ENABLED":"DISABLED",source,g_state.effectiveLot));
}

void OnChartEvent(const int id,const long &lparam,const double &dparam,const string &sparam)
{
   if(id==CHARTEVENT_CHART_CHANGE)
   {
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

   if(sparam==ObjName("NAV_UP") || sparam==ObjName("NAV_DOWN"))
   {
      if(sparam==ObjName("NAV_UP")) g_dashboard.navOffset--; else g_dashboard.navOffset++;
      int navH=g_dashboard.height-134;
      int available=navH-83;
      int visible=MathMax(4,MathMin(TAB_COUNT,(available+4)/28));
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
         int available=navH-46-31;
         int visible=MathMax(4,MathMin(TAB_COUNT,(available+4)/28));
         int maxOffset=MathMax(0,TAB_COUNT-visible);
         g_dashboard.navOffset=MathMax(0,MathMin(g_dashboard.navOffset,maxOffset));
         if(i==10) g_dashboard.settingsPage=0;
         CreateDashboard();
         return;
      }
   }

   if(StringFind(sparam,ObjName("HOME_SUB_"))==0)
   {
      g_dashboard.homeSubTab=(int)StringToInteger(StringSubstr(sparam,StringLen(ObjName("HOME_SUB_"))));
      CreateDashboard(); return;
   }
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
   if(sparam==ObjName("SET_PREV") || sparam==ObjName("SET_NEXT")){bool next=(sparam==ObjName("SET_NEXT"));if(g_dashboard.settingsPage==0)g_dashboard.settingsSubTab=next?((g_dashboard.settingsSubTab+1)%10):((g_dashboard.settingsSubTab+9)%10);else if(g_dashboard.settingsPage==1)g_dashboard.settingsSubTab2=next?((g_dashboard.settingsSubTab2+1)%10):((g_dashboard.settingsSubTab2+9)%10);else if(g_dashboard.settingsPage==2)g_dashboard.settingsSubTab3=next?((g_dashboard.settingsSubTab3+1)%10):((g_dashboard.settingsSubTab3+9)%10);else if(g_dashboard.settingsPage==3)g_dashboard.settingsSubTab4=next?((g_dashboard.settingsSubTab4+1)%10):((g_dashboard.settingsSubTab4+9)%10);else if(g_dashboard.settingsPage==4)g_dashboard.settingsSubTab5=next?((g_dashboard.settingsSubTab5+1)%10):((g_dashboard.settingsSubTab5+9)%10);else if(g_dashboard.settingsPage==5)g_dashboard.settingsSubTab6=next?((g_dashboard.settingsSubTab6+1)%10):((g_dashboard.settingsSubTab6+9)%10);else g_dashboard.settingsSubTab7=next?((g_dashboard.settingsSubTab7+1)%10):((g_dashboard.settingsSubTab7+9)%10);CreateDashboard();return;}
   if(StringFind(sparam,ObjName("SET_SUB_"))==0){int idx=(int)StringToInteger(StringSubstr(sparam,StringLen(ObjName("SET_SUB_"))));if(idx<0)idx=0;if(idx>9)idx=9;if(g_dashboard.settingsPage==0)g_dashboard.settingsSubTab=idx;else if(g_dashboard.settingsPage==1)g_dashboard.settingsSubTab2=idx;else if(g_dashboard.settingsPage==2)g_dashboard.settingsSubTab3=idx;else if(g_dashboard.settingsPage==3)g_dashboard.settingsSubTab4=idx;else if(g_dashboard.settingsPage==4)g_dashboard.settingsSubTab5=idx;else if(g_dashboard.settingsPage==5)g_dashboard.settingsSubTab6=idx;else g_dashboard.settingsSubTab7=idx;CreateDashboard();return;}

   if(StringFind(sparam,ObjName("GRID_SEL_"))==0)
   {
      int idx=(int)StringToInteger(StringSubstr(sparam,StringLen(ObjName("GRID_SEL_"))));
      if(idx>=0 && idx<GRID_TYPE_COUNT)
      {
         g_state.gridType=(ENUM_GRID_TYPE)idx;
         g_dashboard.currentTab=1;
         g_dashboard.gridSubTab=1;
         g_state.executionStatus="GRID TYPE SELECTED";
         CreateDashboard();
      }
      return;
   }

   if(sparam==ObjName("BTN_START"))
   {
      if(!g_state.gridActive){SetAction("USER","START PRESSED","Manual grid deployment requested");CreateGrid();}
      UpdateState();CreateDashboard();
   }
   else if(sparam==ObjName("BTN_REBAL"))
   {
      RecenterGrid(); UpdateState(); CreateDashboard();
   }
   else if(sparam==ObjName("BTN_CLOSE_PROFIT") || sparam==ObjName("TR_CLOSE_PROFIT"))
   {
      CloseProfitPositions(); UpdateState(); CreateDashboard();
   }
   else if(sparam==ObjName("BTN_CLOSE_LOSS") || sparam==ObjName("TR_CLOSE_LOSS"))
   {
      CloseLossPositions(); UpdateState(); CreateDashboard();
   }
   else if(sparam==ObjName("BTN_CANCEL_GRID") || sparam==ObjName("TR_CANCEL") || sparam==ObjName("BTN_CANCEL_GRID2"))
   {
      CancelPendingGridOrders(); UpdateState(); CreateDashboard();
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
      RecenterGrid(); UpdateState(); CreateDashboard();
   }
   else if(sparam==ObjName("AI_RESET2"))
   {
      g_state.predictionAccuracy=0.0; g_state.totalTrades=0; g_state.wins=0; g_state.losses=0; g_state.winRate=0.0; CreateDashboard();
   }
   else if(sparam==ObjName("BTN_GRID_REBUILD"))
   {
      CloseGrid(); CreateGrid(); UpdateState(); CreateDashboard();
   }
   else if(sparam==ObjName("BTN_REBAL_GRID") || sparam==ObjName("TR_RECENTER"))
   {
      RecenterGrid(); UpdateState(); CreateDashboard();
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
      g_state.controlMode=(g_state.controlMode==CONTROL_AUTONOMOUS)?CONTROL_MANUAL:CONTROL_AUTONOMOUS;g_state.autonomousMode=(g_state.controlMode==CONTROL_AUTONOMOUS);SetAction("USER","CONTROL MODE",ControlModeName(g_state.controlMode));CreateDashboard();
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
   else if(sparam==ObjName("BTN_CONTROL_MODE")){g_state.controlMode=(ENUM_CONTROL_MODE)(((int)g_state.controlMode+1)%3);g_state.autonomousMode=(g_state.controlMode==CONTROL_AUTONOMOUS);SetAction("USER","CONTROL MODE",ControlModeName(g_state.controlMode));CreateDashboard();}
   else if(sparam==ObjName("ADV_ENTRY") || sparam==ObjName("ADV_ENTRY2")){g_state.advancedEntryDecision=!g_state.advancedEntryDecision;CreateDashboard();}
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
   else if(sparam==ObjName("BTN_APPLY"))
   {
      g_pendingApplySummary=BuildApplySummary();
      AddApplyHistory();
      SyncFromDashboard(); ValidateSettings(); UpdateConfigurationHealth(); RunSettingsAuthorityAudit(); if(g_state.persistRuntimeState) SaveRuntimeCheckpoint(); ClearEditCache();
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


int OnInit(){InitializeState();InitializeDashboard();trade.SetExpertMagicNumber(InpMagicNumber);trade.SetDeviationInPoints((ulong)MathMax(0,InpSlippage));g_atrHandle=iATR(_Symbol,PERIOD_CURRENT,InpRecenterATRPeriod);g_maHandle=iMA(_Symbol,PERIOD_CURRENT,20,0,MODE_SMA,PRICE_CLOSE);g_rsiHandle=iRSI(_Symbol,PERIOD_CURRENT,14,PRICE_CLOSE);bool checkpoint=LoadRuntimeCheckpoint();UpdateState();ApplyChartTheme(true);if(g_state.autoRecoverOnInit){if(!checkpoint){g_state.recoveryStatus="NO CHECKPOINT";g_state.recoverySource="LIVE STATE";}ReconcileRuntimeAfterRestart();}else if(g_state.positionCount>0||g_state.pendingCount>0){g_state.gridActive=true;g_state.recoveryStatus="LIVE STATE DETECTED";g_state.recoverySource="MANUAL RECOVERY MODE";RecordEvent("GRID RECOVERY","Live inventory detected; automatic recovery disabled");}SaveRuntimeCheckpoint();if(g_dashboard.isVisible)CreateDashboard();return INIT_SUCCEEDED;}
void OnTradeTransaction(const MqlTradeTransaction& trans,const MqlTradeRequest& request,const MqlTradeResult& result){if(result.retcode!=0 && result.retcode!=TRADE_RETCODE_DONE && result.retcode!=TRADE_RETCODE_PLACED && result.retcode!=TRADE_RETCODE_DONE_PARTIAL){g_state.lastOrderRetcode=(uint)result.retcode;g_state.lastOrderRetcodeText=result.comment;RecordEvent("TRADE RETCODE",StringFormat("%u | %s",(uint)result.retcode,result.comment));}if(trans.type==TRADE_TRANSACTION_DEAL_ADD){if(HistoryDealSelect(trans.deal)){string sym=HistoryDealGetString(trans.deal,DEAL_SYMBOL);if(sym==_Symbol&&(ulong)HistoryDealGetInteger(trans.deal,DEAL_MAGIC)==InpMagicNumber){ENUM_DEAL_ENTRY e=(ENUM_DEAL_ENTRY)HistoryDealGetInteger(trans.deal,DEAL_ENTRY);ENUM_DEAL_TYPE dt=(ENUM_DEAL_TYPE)HistoryDealGetInteger(trans.deal,DEAL_TYPE);if(e==DEAL_ENTRY_IN)g_state.lifecycleFillCount++;g_state.gridLifecycleState=e==DEAL_ENTRY_IN?"ACTIVE / FILL":"ACTIVE / CLOSE";g_state.gridLifecycleReason=GridLifecycleModel(g_state.gridType);RecordEvent(e==DEAL_ENTRY_IN?"ORDER FILLED":"POSITION CLOSED",StringFormat("%s | cycle %I64u | fill %d",EnumToString(dt),g_state.gridCycleId,g_state.lifecycleFillCount));}}}if(trans.type==TRADE_TRANSACTION_ORDER_DELETE){g_state.lifecycleDeleteCount++;g_state.gridLifecycleState="ACTIVE / ORDER CHANGE";RecordEvent("PENDING DELETED",StringFormat("Cycle %I64u | deleted %d",g_state.gridCycleId,g_state.lifecycleDeleteCount));}}
void OnDeinit(const int reason){SaveRuntimeCheckpoint();if(g_atrHandle!=INVALID_HANDLE)IndicatorRelease(g_atrHandle);if(g_maHandle!=INVALID_HANDLE)IndicatorRelease(g_maHandle);if(g_rsiHandle!=INVALID_HANDLE)IndicatorRelease(g_rsiHandle);DeleteDashboard();Comment("");}
void OnTick(){UpdateState();if(g_state.autoChartTheme)ApplyChartTheme(false);ExpirePendingOrders();ManagePositions();ApplyOCO();ManageGridRisk();FinalizeCoordinatedExit();if(g_state.gridActive&&!g_state.exitCoordinationActive){RecenterGrid();SmartReplenishGrid();}if(IsAutonomousControl()&&!g_state.exitCoordinationActive&&ShouldStartGrid())CreateGrid();g_state.executionStatus=(g_state.maxSpreadPips<=0||g_state.currentSpreadPips<=g_state.maxSpreadPips)?"NORMAL":"SPREAD HIGH";MaintainRuntimeCheckpoint();UpdateDashboard();}
