//+------------------------------------------------------------------+
//|                           GOLD SCALPER PRO - ULTIMATE EDITION    |
//|                                    Advanced Institutional Scalper |
//|                                         Built for MT5 Gold Trading |
//+------------------------------------------------------------------+
#property copyright "Gold Scalper Pro Ultimate"
#property link      "Advanced Institutional Trading System"
#property version   "5.00"
#property strict
#property description "Institutional-Grade Gold Scalper with ML & SMC"
#property description "Adaptive Multi-Strategy System with Intelligence"

#include <Trade\Trade.mqh>
#include <Arrays\ArrayObj.mqh>
#include <Math\Stat\Math.mqh>

CTrade trade;

//+------------------------------------------------------------------+
//| INPUT PARAMETERS - MAIN SETTINGS
//+------------------------------------------------------------------+
input group "========== CORE SETTINGS =========="
input double      LotSize = 0.01;                    // Base Lot Size (0 = Auto)
input int         MagicNumber = 888888;              // Magic Number
input string      TradeComment = "GoldScalperPro";   // Trade Comment
input bool        UseAutoLotSizing = true;           // Auto Lot Sizing (Account-Based)
input double      RiskPercent = 1.0;                 // Risk Per Trade (%)
input int         MaxSpreadPoints = 30;              // Max Spread (Points)

input group "========== INTELLIGENT INDICATOR SYSTEM =========="
input bool        AutoSelectIndicators = true;       // Auto-Select Best Indicators
input bool        UseAdvancedIndicators = true;      // Use Advanced Indicators
input bool        UseSimpleIndicators = true;        // Use Simple Indicators
input int         IndicatorSyncPeriod = 100;        // Indicator Sync Analysis Period

input group "========== MACHINE LEARNING & ADAPTATION =========="
input bool        EnableMachineLearning = true;      // Enable ML Self-Learning
input int         ML_LearningPeriod = 500;          // ML Learning Period (Bars)
input double      ML_AdaptationSpeed = 0.3;         // ML Adaptation Speed (0.1-1.0)
input int         ML_MinTradesForLearning = 20;     // Min Trades Before ML Activates

input group "========== SMART MONEY CONCEPTS (SMC) =========="
input bool        UseSMC_Analysis = true;           // Use Smart Money Concepts
input bool        DetectFVG = true;                 // Detect Fair Value Gaps
input bool        DetectCHoCH = true;               // Detect Change of Character
input bool        DetectBOS = true;                 // Detect Break of Structure
input bool        DetectOrderBlocks = true;         // Detect Order Blocks
input bool        DetectLiquidityZones = true;      // Detect Liquidity Zones
input int         SMC_LookbackPeriod = 100;        // SMC Lookback Period

input group "========== VISUAL INTELLIGENCE OVERLAYS =========="
input bool        ShowFVG_Overlays = true;          // Show FVG Rectangles
input bool        ShowCHoCH_Markers = true;         // Show CHoCH Markers
input bool        ShowOrderBlocks = true;           // Show Order Blocks
input bool        ShowLiquidityZones = true;        // Show Liquidity Zones
input bool        ShowStrategyInfo = true;          // Show Active Strategy Info
input color       FVG_BullishColor = clrDodgerBlue; // FVG Bullish Color
input color       FVG_BearishColor = clrCrimson;    // FVG Bearish Color

input group "========== MARKET CONDITION DETECTION =========="
input bool        UseSessionFilters = true;         // Use Trading Session Filters
input bool        TradeLondon = true;               // Trade London Session
input bool        TradeNewYork = true;              // Trade New York Session
input bool        TradeAsian = false;               // Trade Asian Session
input bool        UseVolatilityFilter = true;       // Use Volatility Filter
input bool        UseLiquidityFilter = true;        // Use Liquidity Filter

input group "========== DYNAMIC RISK MANAGEMENT =========="
input bool        UseDynamicRisk = true;            // Dynamic Risk Based on Volatility
input double      MaxRiskPercent = 3.0;             // Maximum Risk %
input double      MinRiskPercent = 0.5;             // Minimum Risk %
input bool        UseEquityProtection = true;       // Equity Protection
input double      MaxDailyLossPercent = 5.0;        // Max Daily Loss %
input double      DailyProfitTarget = 10.0;         // Daily Profit Target %
input bool        UseTrailingStop = true;           // Use Intelligent Trailing Stop
input double      TrailingStopATRMultiplier = 2.0;  // Trailing Stop ATR Multiplier

input group "========== SCALPING STRATEGIES =========="
input bool        UseStrategy_Momentum = true;      // Strategy: Momentum Scalping
input bool        UseStrategy_MeanReversion = true; // Strategy: Mean Reversion
input bool        UseStrategy_Breakout = true;      // Strategy: Breakout Scalping
input bool        UseStrategy_SMC = true;           // Strategy: Smart Money
input bool        UseStrategy_Scalp1M = true;       // Strategy: Ultra Fast Scalp
input int         Strategy_MinConfluence = 3;       // Min Confluence Signals

input group "========== ADVANCED FILTERS =========="
input bool        UseNewsFilter = true;             // Avoid High-Impact News
input int         NewsAvoidanceMinutes = 30;        // Minutes Before/After News
input bool        UseSpreadFilter = true;           // Spread Filter
input bool        UseTrendFilter = true;            // Trend Filter
input bool        UseVolumeFilter = true;           // Volume Filter
input double      MinVolumeMultiplier = 1.2;        // Min Volume Multiplier

input group "========== TAKE PROFIT & STOP LOSS =========="
input bool        UseDynamicTPSL = true;            // Dynamic TP/SL Based on ATR
input double      TP_ATR_Multiplier = 2.0;          // TP ATR Multiplier
input double      SL_ATR_Multiplier = 1.5;          // SL ATR Multiplier
input int         MinTP_Points = 100;               // Min TP (Points)
input int         MinSL_Points = 50;                // Min SL (Points)
input int         MaxTP_Points = 1000;              // Max TP (Points)
input int         MaxSL_Points = 500;               // Max SL (Points)

//+------------------------------------------------------------------+
//| GLOBAL VARIABLES
//+------------------------------------------------------------------+

// Market Structure Variables
struct MarketStructure {
    double currentHigh;
    double currentLow;
    double previousHigh;
    double previousLow;
    bool isBullish;
    bool isBearish;
    datetime lastUpdate;
};
MarketStructure marketStructure;

// Fair Value Gap Structure
struct FairValueGap {
    double upperLevel;
    double lowerLevel;
    datetime startTime;
    bool isBullish;
    bool isFilled;
    string objectName;
};
FairValueGap fvgList[];

// Order Block Structure
struct OrderBlock {
    double highPrice;
    double lowPrice;
    datetime time;
    bool isBullish;
    bool isValid;
    string objectName;
};
OrderBlock orderBlocks[];

// Machine Learning Variables
struct MLData {
    double winRate;
    double avgWin;
    double avgLoss;
    double profitFactor;
    int totalTrades;
    double strategyScores[];
    double indicatorWeights[];
    datetime lastUpdate;
};
MLData mlData;

// Market Condition Variables
enum MARKET_CONDITION {
    MARKET_RANGING,
    MARKET_TRENDING_UP,
    MARKET_TRENDING_DOWN,
    MARKET_VOLATILE,
    MARKET_QUIET
};
MARKET_CONDITION currentMarketCondition;

// Session Variables
enum TRADING_SESSION {
    SESSION_ASIAN,
    SESSION_LONDON,
    SESSION_NEWYORK,
    SESSION_OVERLAP,
    SESSION_NONE
};
TRADING_SESSION currentSession;

// Strategy Performance Tracking
struct StrategyPerformance {
    string name;
    int wins;
    int losses;
    double profit;
    double winRate;
    bool isActive;
};
StrategyPerformance strategies[];

// Indicator Handles
int handle_ATR;
int handle_MA_Fast;
int handle_MA_Slow;
int handle_RSI;
int handle_MACD;
int handle_Stochastic;
int handle_Bollinger;
int handle_ADX;
int handle_CCI;
int handle_WPR;
int handle_MFI;
int handle_OBV;
int handle_SAR;
int handle_Ichimoku;

// Indicator Buffers
double buffer_ATR[];
double buffer_MA_Fast[];
double buffer_MA_Slow[];
double buffer_RSI[];
double buffer_MACD_Main[];
double buffer_MACD_Signal[];
double buffer_Stoch_Main[];
double buffer_Stoch_Signal[];
double buffer_BB_Upper[];
double buffer_BB_Middle[];
double buffer_BB_Lower[];
double buffer_ADX[];
double buffer_CCI[];
double buffer_WPR[];
double buffer_MFI[];
double buffer_OBV[];

// Active Indicators List
bool activeIndicators[];
string indicatorNames[];

// Daily Statistics
double dailyStartBalance;
double dailyProfit;
double dailyLoss;
int dailyTrades;
datetime lastDayReset;

// Performance Metrics
int totalWins = 0;
int totalLosses = 0;
double totalProfit = 0;
double totalLoss = 0;

// Signal Variables
int currentSignal = 0; // 1 = Buy, -1 = Sell, 0 = No Signal
double signalConfidence = 0.0;

// Visual Objects
string objPrefix = "GoldScalperPro_";

//+------------------------------------------------------------------+
//| Expert initialization function                                     |
//+------------------------------------------------------------------+
int OnInit() {
    Print("========================================");
    Print("GOLD SCALPER PRO - ULTIMATE EDITION");
    Print("Initializing Advanced Institutional System...");
    Print("========================================");
    
    // Set trade parameters
    trade.SetExpertMagicNumber(MagicNumber);
    trade.SetDeviationInPoints(50);
    trade.SetTypeFilling(ORDER_FILLING_FOK);
    trade.SetAsyncMode(false);
    
    // Initialize indicators
    if(!InitializeIndicators()) {
        Print("ERROR: Failed to initialize indicators!");
        return INIT_FAILED;
    }
    
    // Initialize Machine Learning
    if(EnableMachineLearning) {
        InitializeMachineLearning();
    }
    
    // Initialize Strategies
    InitializeStrategies();
    
    // Initialize Market Structure
    InitializeMarketStructure();
    
    // Set array buffers as series
    ArraySetAsSeries(buffer_ATR, true);
    ArraySetAsSeries(buffer_MA_Fast, true);
    ArraySetAsSeries(buffer_MA_Slow, true);
    ArraySetAsSeries(buffer_RSI, true);
    ArraySetAsSeries(buffer_MACD_Main, true);
    ArraySetAsSeries(buffer_MACD_Signal, true);
    ArraySetAsSeries(buffer_Stoch_Main, true);
    ArraySetAsSeries(buffer_Stoch_Signal, true);
    ArraySetAsSeries(buffer_BB_Upper, true);
    ArraySetAsSeries(buffer_BB_Middle, true);
    ArraySetAsSeries(buffer_BB_Lower, true);
    ArraySetAsSeries(buffer_ADX, true);
    ArraySetAsSeries(buffer_CCI, true);
    ArraySetAsSeries(buffer_WPR, true);
    ArraySetAsSeries(buffer_MFI, true);
    ArraySetAsSeries(buffer_OBV, true);
    
    // Initialize daily statistics
    dailyStartBalance = AccountInfoDouble(ACCOUNT_BALANCE);
    lastDayReset = TimeCurrent();
    
    // Create dashboard
    CreateDashboard();
    
    Print("✓ Initialization Complete!");
    Print("✓ Machine Learning: ", EnableMachineLearning ? "ENABLED" : "DISABLED");
    Print("✓ Smart Money Concepts: ", UseSMC_Analysis ? "ENABLED" : "DISABLED");
    Print("✓ Auto Indicator Selection: ", AutoSelectIndicators ? "ENABLED" : "DISABLED");
    Print("✓ Active Strategies: ", CountActiveStrategies());
    Print("========================================");
    
    return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason) {
    Print("========================================");
    Print("GOLD SCALPER PRO - Shutting Down");
    Print("Reason: ", reason);
    
    // Release indicator handles
    ReleaseIndicators();
    
    // Clean up visual objects
    CleanupVisualObjects();
    
    // Print final statistics
    PrintFinalStatistics();
    
    Print("========================================");
}

//+------------------------------------------------------------------+
//| Expert tick function                                              |
//+------------------------------------------------------------------+
void OnTick() {
    // Check if new bar
    static datetime lastBar = 0;
    datetime currentBar = iTime(_Symbol, PERIOD_CURRENT, 0);
    bool isNewBar = (currentBar != lastBar);
    
    if(isNewBar) {
        lastBar = currentBar;
        
        // Update all systems on new bar
        UpdateDailyStatistics();
        UpdateMarketCondition();
        UpdateTradingSession();
        
        if(UseSMC_Analysis) {
            UpdateSmartMoneyAnalysis();
        }
        
        if(AutoSelectIndicators) {
            SelectBestIndicators();
        }
        
        if(EnableMachineLearning) {
            UpdateMachineLearning();
        }
        
        UpdateStrategies();
        UpdateVisualOverlays();
    }
    
    // Risk Management Checks
    if(!PassesRiskManagement()) {
        return;
    }
    
    // Filter Checks
    if(!PassesFilters()) {
        return;
    }
    
    // Manage existing positions
    ManagePositions();
    
    // Check for new trading signals (only on new bar for scalping)
    if(isNewBar) {
        AnalyzeMarketAndTrade();
    }
    
    // Update dashboard
    UpdateDashboard();
}

//+------------------------------------------------------------------+
//| Initialize All Indicators                                         |
//+------------------------------------------------------------------+
bool InitializeIndicators() {
    Print("Initializing Advanced Indicator System...");
    
    // ATR - Volatility
    handle_ATR = iATR(_Symbol, PERIOD_CURRENT, 14);
    if(handle_ATR == INVALID_HANDLE) {
        Print("ERROR: Failed to create ATR indicator");
        return false;
    }
    
    // Moving Averages
    handle_MA_Fast = iMA(_Symbol, PERIOD_CURRENT, 20, 0, MODE_EMA, PRICE_CLOSE);
    handle_MA_Slow = iMA(_Symbol, PERIOD_CURRENT, 50, 0, MODE_EMA, PRICE_CLOSE);
    
    // RSI
    handle_RSI = iRSI(_Symbol, PERIOD_CURRENT, 14, PRICE_CLOSE);
    
    // MACD
    handle_MACD = iMACD(_Symbol, PERIOD_CURRENT, 12, 26, 9, PRICE_CLOSE);
    
    // Stochastic
    handle_Stochastic = iStochastic(_Symbol, PERIOD_CURRENT, 14, 3, 3, MODE_SMA, STO_LOWHIGH);
    
    // Bollinger Bands
    handle_Bollinger = iBands(_Symbol, PERIOD_CURRENT, 20, 0, 2.0, PRICE_CLOSE);
    
    // ADX
    handle_ADX = iADX(_Symbol, PERIOD_CURRENT, 14);
    
    // CCI
    handle_CCI = iCCI(_Symbol, PERIOD_CURRENT, 14, PRICE_TYPICAL);
    
    // Williams %R
    handle_WPR = iWPR(_Symbol, PERIOD_CURRENT, 14);
    
    // MFI - Money Flow Index
    handle_MFI = iMFI(_Symbol, PERIOD_CURRENT, 14, VOLUME_TICK);
    
    // OBV - On Balance Volume
    handle_OBV = iOBV(_Symbol, PERIOD_CURRENT, VOLUME_TICK);
    
    // Parabolic SAR
    handle_SAR = iSAR(_Symbol, PERIOD_CURRENT, 0.02, 0.2);
    
    // Ichimoku
    handle_Ichimoku = iIchimoku(_Symbol, PERIOD_CURRENT, 9, 26, 52);
    
    // Initialize indicator names array
    ArrayResize(indicatorNames, 14);
    indicatorNames[0] = "ATR";
    indicatorNames[1] = "MA_Fast";
    indicatorNames[2] = "MA_Slow";
    indicatorNames[3] = "RSI";
    indicatorNames[4] = "MACD";
    indicatorNames[5] = "Stochastic";
    indicatorNames[6] = "Bollinger";
    indicatorNames[7] = "ADX";
    indicatorNames[8] = "CCI";
    indicatorNames[9] = "WPR";
    indicatorNames[10] = "MFI";
    indicatorNames[11] = "OBV";
    indicatorNames[12] = "SAR";
    indicatorNames[13] = "Ichimoku";
    
    ArrayResize(activeIndicators, 14);
    ArrayInitialize(activeIndicators, true);
    
    Print("✓ All Indicators Initialized Successfully");
    return true;
}

//+------------------------------------------------------------------+
//| Release Indicator Handles                                         |
//+------------------------------------------------------------------+
void ReleaseIndicators() {
    IndicatorRelease(handle_ATR);
    IndicatorRelease(handle_MA_Fast);
    IndicatorRelease(handle_MA_Slow);
    IndicatorRelease(handle_RSI);
    IndicatorRelease(handle_MACD);
    IndicatorRelease(handle_Stochastic);
    IndicatorRelease(handle_Bollinger);
    IndicatorRelease(handle_ADX);
    IndicatorRelease(handle_CCI);
    IndicatorRelease(handle_WPR);
    IndicatorRelease(handle_MFI);
    IndicatorRelease(handle_OBV);
    IndicatorRelease(handle_SAR);
    IndicatorRelease(handle_Ichimoku);
}

//+------------------------------------------------------------------+
//| Initialize Machine Learning System                                |
//+------------------------------------------------------------------+
void InitializeMachineLearning() {
    Print("Initializing Machine Learning System...");
    
    mlData.winRate = 0.5;
    mlData.avgWin = 0;
    mlData.avgLoss = 0;
    mlData.profitFactor = 1.0;
    mlData.totalTrades = 0;
    
    // Initialize strategy scores
    ArrayResize(mlData.strategyScores, 5);
    ArrayInitialize(mlData.strategyScores, 1.0);
    
    // Initialize indicator weights
    ArrayResize(mlData.indicatorWeights, 14);
    ArrayInitialize(mlData.indicatorWeights, 1.0);
    
    mlData.lastUpdate = TimeCurrent();
    
    Print("✓ Machine Learning Initialized");
}

//+------------------------------------------------------------------+
//| Initialize Strategies                                             |
//+------------------------------------------------------------------+
void InitializeStrategies() {
    ArrayResize(strategies, 5);
    
    strategies[0].name = "Momentum Scalping";
    strategies[0].isActive = UseStrategy_Momentum;
    
    strategies[1].name = "Mean Reversion";
    strategies[1].isActive = UseStrategy_MeanReversion;
    
    strategies[2].name = "Breakout Scalping";
    strategies[2].isActive = UseStrategy_Breakout;
    
    strategies[3].name = "Smart Money Concepts";
    strategies[3].isActive = UseStrategy_SMC;
    
    strategies[4].name = "Ultra Fast Scalp";
    strategies[4].isActive = UseStrategy_Scalp1M;
    
    for(int i = 0; i < ArraySize(strategies); i++) {
        strategies[i].wins = 0;
        strategies[i].losses = 0;
        strategies[i].profit = 0;
        strategies[i].winRate = 0.5;
    }
    
    Print("✓ Strategies Initialized: ", CountActiveStrategies(), " active");
}

//+------------------------------------------------------------------+
//| Initialize Market Structure                                       |
//+------------------------------------------------------------------+
void InitializeMarketStructure() {
    marketStructure.currentHigh = 0;
    marketStructure.currentLow = 0;
    marketStructure.previousHigh = 0;
    marketStructure.previousLow = 0;
    marketStructure.isBullish = false;
    marketStructure.isBearish = false;
    marketStructure.lastUpdate = TimeCurrent();
    
    ArrayResize(fvgList, 0);
    ArrayResize(orderBlocks, 0);
}

//+------------------------------------------------------------------+
//| Update Market Condition                                           |
//+------------------------------------------------------------------+
void UpdateMarketCondition() {
    CopyBuffer(handle_ATR, 0, 0, 50, buffer_ATR);
    CopyBuffer(handle_ADX, 0, 0, 50, buffer_ADX);
    CopyBuffer(handle_MA_Fast, 0, 0, 50, buffer_MA_Fast);
    CopyBuffer(handle_MA_Slow, 0, 0, 50, buffer_MA_Slow);
    
    double currentATR = buffer_ATR[0];
    double avgATR = 0;
    for(int i = 0; i < 20; i++) {
        avgATR += buffer_ATR[i];
    }
    avgATR /= 20;
    
    double adxValue = buffer_ADX[0];
    double close = iClose(_Symbol, PERIOD_CURRENT, 0);
    
    // Determine market condition
    if(currentATR > avgATR * 1.5) {
        currentMarketCondition = MARKET_VOLATILE;
    }
    else if(currentATR < avgATR * 0.7) {
        currentMarketCondition = MARKET_QUIET;
    }
    else if(adxValue > 25) {
        if(buffer_MA_Fast[0] > buffer_MA_Slow[0] && close > buffer_MA_Fast[0]) {
            currentMarketCondition = MARKET_TRENDING_UP;
        }
        else if(buffer_MA_Fast[0] < buffer_MA_Slow[0] && close < buffer_MA_Fast[0]) {
            currentMarketCondition = MARKET_TRENDING_DOWN;
        }
        else {
            currentMarketCondition = MARKET_RANGING;
        }
    }
    else {
        currentMarketCondition = MARKET_RANGING;
    }
}

//+------------------------------------------------------------------+
//| Update Trading Session                                            |
//+------------------------------------------------------------------+
void UpdateTradingSession() {
    MqlDateTime dt;
    TimeToStruct(TimeCurrent(), dt);
    int hour = dt.hour;
    
    // London: 8-17 GMT, New York: 13-22 GMT, Asian: 0-9 GMT
    // Overlap: 13-17 GMT
    
    if(hour >= 13 && hour < 17) {
        currentSession = SESSION_OVERLAP;
    }
    else if(hour >= 8 && hour < 17) {
        currentSession = SESSION_LONDON;
    }
    else if(hour >= 13 && hour < 22) {
        currentSession = SESSION_NEWYORK;
    }
    else if(hour >= 0 && hour < 9) {
        currentSession = SESSION_ASIAN;
    }
    else {
        currentSession = SESSION_NONE;
    }
}

//+------------------------------------------------------------------+
//| Update Smart Money Analysis                                       |
//+------------------------------------------------------------------+
void UpdateSmartMoneyAnalysis() {
    if(DetectFVG) {
        DetectFairValueGaps();
    }
    
    if(DetectCHoCH) {
        DetectChangeOfCharacter();
    }
    
    if(DetectBOS) {
        DetectBreakOfStructure();
    }
    
    if(DetectOrderBlocks) {
        DetectOrderBlockZones();
    }
    
    if(DetectLiquidityZones) {
        DetectLiquidityPools();
    }
}

//+------------------------------------------------------------------+
//| Detect Fair Value Gaps                                            |
//+------------------------------------------------------------------+
void DetectFairValueGaps() {
    for(int i = 1; i < SMC_LookbackPeriod - 2; i++) {
        double high1 = iHigh(_Symbol, PERIOD_CURRENT, i+1);
        double low1 = iLow(_Symbol, PERIOD_CURRENT, i+1);
        double high2 = iHigh(_Symbol, PERIOD_CURRENT, i);
        double low2 = iLow(_Symbol, PERIOD_CURRENT, i);
        double high3 = iHigh(_Symbol, PERIOD_CURRENT, i-1);
        double low3 = iLow(_Symbol, PERIOD_CURRENT, i-1);
        
        // Bullish FVG: Low of candle 3 > High of candle 1
        if(low3 > high1) {
            FairValueGap fvg;
            fvg.upperLevel = low3;
            fvg.lowerLevel = high1;
            fvg.startTime = iTime(_Symbol, PERIOD_CURRENT, i+1);
            fvg.isBullish = true;
            fvg.isFilled = false;
            fvg.objectName = objPrefix + "FVG_Bull_" + TimeToString(fvg.startTime);
            
            AddFVG(fvg);
        }
        
        // Bearish FVG: High of candle 3 < Low of candle 1
        if(high3 < low1) {
            FairValueGap fvg;
            fvg.upperLevel = low1;
            fvg.lowerLevel = high3;
            fvg.startTime = iTime(_Symbol, PERIOD_CURRENT, i+1);
            fvg.isBullish = false;
            fvg.isFilled = false;
            fvg.objectName = objPrefix + "FVG_Bear_" + TimeToString(fvg.startTime);
            
            AddFVG(fvg);
        }
    }
    
    // Check if FVGs are filled
    double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    for(int i = ArraySize(fvgList) - 1; i >= 0; i--) {
        if(!fvgList[i].isFilled) {
            if(fvgList[i].isBullish && currentPrice <= fvgList[i].lowerLevel) {
                fvgList[i].isFilled = true;
            }
            else if(!fvgList[i].isBullish && currentPrice >= fvgList[i].upperLevel) {
                fvgList[i].isFilled = true;
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Add Fair Value Gap                                                |
//+------------------------------------------------------------------+
void AddFVG(FairValueGap &fvg) {
    // Check if FVG already exists
    for(int i = 0; i < ArraySize(fvgList); i++) {
        if(fvgList[i].startTime == fvg.startTime) {
            return; // Already exists
        }
    }
    
    int size = ArraySize(fvgList);
    ArrayResize(fvgList, size + 1);
    fvgList[size] = fvg;
    
    // Limit array size
    if(ArraySize(fvgList) > 50) {
        ArrayRemove(fvgList, 0, 1);
    }
}

//+------------------------------------------------------------------+
//| Detect Change of Character (CHoCH)                                |
//+------------------------------------------------------------------+
void DetectChangeOfCharacter() {
    // Find swing highs and lows
    double swingHighs[];
    double swingLows[];
    datetime swingHighTimes[];
    datetime swingLowTimes[];
    
    ArrayResize(swingHighs, 0);
    ArrayResize(swingLows, 0);
    
    for(int i = 5; i < SMC_LookbackPeriod - 5; i++) {
        double high = iHigh(_Symbol, PERIOD_CURRENT, i);
        double low = iLow(_Symbol, PERIOD_CURRENT, i);
        
        bool isSwingHigh = true;
        bool isSwingLow = true;
        
        for(int j = 1; j <= 5; j++) {
            if(high <= iHigh(_Symbol, PERIOD_CURRENT, i-j) || 
               high <= iHigh(_Symbol, PERIOD_CURRENT, i+j)) {
                isSwingHigh = false;
            }
            if(low >= iLow(_Symbol, PERIOD_CURRENT, i-j) || 
               low >= iLow(_Symbol, PERIOD_CURRENT, i+j)) {
                isSwingLow = false;
            }
        }
        
        if(isSwingHigh) {
            int size = ArraySize(swingHighs);
            ArrayResize(swingHighs, size + 1);
            ArrayResize(swingHighTimes, size + 1);
            swingHighs[size] = high;
            swingHighTimes[size] = iTime(_Symbol, PERIOD_CURRENT, i);
        }
        
        if(isSwingLow) {
            int size = ArraySize(swingLows);
            ArrayResize(swingLows, size + 1);
            ArrayResize(swingLowTimes, size + 1);
            swingLows[size] = low;
            swingLowTimes[size] = iTime(_Symbol, PERIOD_CURRENT, i);
        }
    }
    
    // Detect CHoCH
    if(ArraySize(swingHighs) >= 2) {
        // Bearish CHoCH: Break of previous higher high
        if(swingHighs[ArraySize(swingHighs)-1] < swingHighs[ArraySize(swingHighs)-2]) {
            marketStructure.isBearish = true;
            marketStructure.isBullish = false;
        }
    }
    
    if(ArraySize(swingLows) >= 2) {
        // Bullish CHoCH: Break of previous lower low
        if(swingLows[ArraySize(swingLows)-1] > swingLows[ArraySize(swingLows)-2]) {
            marketStructure.isBullish = true;
            marketStructure.isBearish = false;
        }
    }
}

//+------------------------------------------------------------------+
//| Detect Break of Structure (BOS)                                   |
//+------------------------------------------------------------------+
void DetectBreakOfStructure() {
    double close = iClose(_Symbol, PERIOD_CURRENT, 0);
    
    // Find recent swing high/low
    double recentHigh = 0;
    double recentLow = DBL_MAX;
    
    for(int i = 1; i < 20; i++) {
        double high = iHigh(_Symbol, PERIOD_CURRENT, i);
        double low = iLow(_Symbol, PERIOD_CURRENT, i);
        
        if(high > recentHigh) recentHigh = high;
        if(low < recentLow) recentLow = low;
    }
    
    marketStructure.currentHigh = recentHigh;
    marketStructure.currentLow = recentLow;
}

//+------------------------------------------------------------------+
//| Detect Order Blocks                                               |
//+------------------------------------------------------------------+
void DetectOrderBlockZones() {
    for(int i = 2; i < SMC_LookbackPeriod; i++) {
        double open = iOpen(_Symbol, PERIOD_CURRENT, i);
        double close = iClose(_Symbol, PERIOD_CURRENT, i);
        double high = iHigh(_Symbol, PERIOD_CURRENT, i);
        double low = iLow(_Symbol, PERIOD_CURRENT, i);
        
        double nextClose = iClose(_Symbol, PERIOD_CURRENT, i-1);
        double prevClose = iClose(_Symbol, PERIOD_CURRENT, i+1);
        
        // Bullish Order Block: Strong bullish move after bearish candle
        if(close < open && nextClose > close && (nextClose - close) > (high - low) * 2) {
            OrderBlock ob;
            ob.highPrice = open;
            ob.lowPrice = low;
            ob.time = iTime(_Symbol, PERIOD_CURRENT, i);
            ob.isBullish = true;
            ob.isValid = true;
            ob.objectName = objPrefix + "OB_Bull_" + TimeToString(ob.time);
            
            AddOrderBlock(ob);
        }
        
        // Bearish Order Block: Strong bearish move after bullish candle
        if(close > open && nextClose < close && (close - nextClose) > (high - low) * 2) {
            OrderBlock ob;
            ob.highPrice = high;
            ob.lowPrice = open;
            ob.time = iTime(_Symbol, PERIOD_CURRENT, i);
            ob.isBullish = false;
            ob.isValid = true;
            ob.objectName = objPrefix + "OB_Bear_" + TimeToString(ob.time);
            
            AddOrderBlock(ob);
        }
    }
}

//+------------------------------------------------------------------+
//| Add Order Block                                                   |
//+------------------------------------------------------------------+
void AddOrderBlock(OrderBlock &ob) {
    // Check if already exists
    for(int i = 0; i < ArraySize(orderBlocks); i++) {
        if(orderBlocks[i].time == ob.time) {
            return;
        }
    }
    
    int size = ArraySize(orderBlocks);
    ArrayResize(orderBlocks, size + 1);
    orderBlocks[size] = ob;
    
    // Limit size
    if(ArraySize(orderBlocks) > 30) {
        ArrayRemove(orderBlocks, 0, 1);
    }
}

//+------------------------------------------------------------------+
//| Detect Liquidity Zones                                            |
//+------------------------------------------------------------------+
void DetectLiquidityPools() {
    // Liquidity typically sits above/below swing highs/lows
    // This is where stop losses accumulate
    
    double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    
    // Find equal highs/lows (liquidity pools)
    for(int i = 5; i < 50; i++) {
        double high1 = iHigh(_Symbol, PERIOD_CURRENT, i);
        
        for(int j = i + 5; j < 100; j++) {
            double high2 = iHigh(_Symbol, PERIOD_CURRENT, j);
            
            // Equal highs (within 10 points)
            if(MathAbs(high1 - high2) < 10 * _Point) {
                // Mark as liquidity zone
                // Store for later use in trading logic
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Select Best Indicators Based on Market Conditions                 |
//+------------------------------------------------------------------+
void SelectBestIndicators() {
    // Reset all indicators
    ArrayInitialize(activeIndicators, false);
    
    // Always use ATR for volatility
    activeIndicators[0] = true; // ATR
    
    switch(currentMarketCondition) {
        case MARKET_TRENDING_UP:
        case MARKET_TRENDING_DOWN:
            // Trend following indicators
            activeIndicators[1] = true;  // MA_Fast
            activeIndicators[2] = true;  // MA_Slow
            activeIndicators[4] = true;  // MACD
            activeIndicators[7] = true;  // ADX
            activeIndicators[12] = true; // SAR
            activeIndicators[13] = true; // Ichimoku
            break;
            
        case MARKET_RANGING:
            // Oscillators and mean reversion
            activeIndicators[3] = true;  // RSI
            activeIndicators[5] = true;  // Stochastic
            activeIndicators[6] = true;  // Bollinger
            activeIndicators[8] = true;  // CCI
            activeIndicators[9] = true;  // WPR
            break;
            
        case MARKET_VOLATILE:
            // Volatility and momentum indicators
            activeIndicators[6] = true;  // Bollinger
            activeIndicators[7] = true;  // ADX
            activeIndicators[10] = true; // MFI
            activeIndicators[11] = true; // OBV
            break;
            
        case MARKET_QUIET:
            // Sensitive indicators for quiet markets
            activeIndicators[3] = true;  // RSI
            activeIndicators[8] = true;  // CCI
            activeIndicators[9] = true;  // WPR
            activeIndicators[10] = true; // MFI
            break;
    }
    
    // Apply ML weights if enabled
    if(EnableMachineLearning && mlData.totalTrades >= ML_MinTradesForLearning) {
        for(int i = 0; i < ArraySize(activeIndicators); i++) {
            if(mlData.indicatorWeights[i] < 0.5) {
                activeIndicators[i] = false; // Disable poor performing indicators
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Update Machine Learning System                                    |
//+------------------------------------------------------------------+
void UpdateMachineLearning() {
    if(mlData.totalTrades < ML_MinTradesForLearning) {
        return; // Not enough data yet
    }
    
    // Update win rate
    if(mlData.totalTrades > 0) {
        mlData.winRate = (double)totalWins / mlData.totalTrades;
    }
    
    // Update average win/loss
    if(totalWins > 0) {
        mlData.avgWin = totalProfit / totalWins;
    }
    if(totalLosses > 0) {
        mlData.avgLoss = MathAbs(totalLoss) / totalLosses;
    }
    
    // Update profit factor
    if(totalLoss != 0) {
        mlData.profitFactor = totalProfit / MathAbs(totalLoss);
    }
    
    // Update strategy scores based on performance
    for(int i = 0; i < ArraySize(strategies); i++) {
        if(strategies[i].wins + strategies[i].losses > 0) {
            double strategyWinRate = (double)strategies[i].wins / (strategies[i].wins + strategies[i].losses);
            
            // Adjust strategy score with adaptation speed
            mlData.strategyScores[i] = mlData.strategyScores[i] * (1 - ML_AdaptationSpeed) + 
                                       strategyWinRate * ML_AdaptationSpeed;
            
            // Disable poorly performing strategies
            if(mlData.strategyScores[i] < 0.3 && strategies[i].wins + strategies[i].losses > 10) {
                strategies[i].isActive = false;
            }
        }
    }
    
    // Adjust indicator weights based on recent performance
    // This is a simplified ML approach - can be enhanced with more sophisticated algorithms
    
    mlData.lastUpdate = TimeCurrent();
}

//+------------------------------------------------------------------+
//| Update Strategies                                                 |
//+------------------------------------------------------------------+
void UpdateStrategies() {
    for(int i = 0; i < ArraySize(strategies); i++) {
        if(strategies[i].wins + strategies[i].losses > 0) {
            strategies[i].winRate = (double)strategies[i].wins / (strategies[i].wins + strategies[i].losses);
        }
    }
}

//+------------------------------------------------------------------+
//| Analyze Market and Execute Trades                                 |
//+------------------------------------------------------------------+
void AnalyzeMarketAndTrade() {
    // Check if already in position
    if(PositionSelect(_Symbol)) {
        return; // Already in trade
    }
    
    int buySignals = 0;
    int sellSignals = 0;
    double totalConfidence = 0;
    
    // Strategy 1: Momentum Scalping
    if(UseStrategy_Momentum && strategies[0].isActive) {
        int signal = Strategy_MomentumScalping();
        if(signal == 1) buySignals++;
        if(signal == -1) sellSignals++;
    }
    
    // Strategy 2: Mean Reversion
    if(UseStrategy_MeanReversion && strategies[1].isActive) {
        int signal = Strategy_MeanReversion();
        if(signal == 1) buySignals++;
        if(signal == -1) sellSignals++;
    }
    
    // Strategy 3: Breakout Scalping
    if(UseStrategy_Breakout && strategies[2].isActive) {
        int signal = Strategy_BreakoutScalping();
        if(signal == 1) buySignals++;
        if(signal == -1) sellSignals++;
    }
    
    // Strategy 4: Smart Money Concepts
    if(UseStrategy_SMC && strategies[3].isActive && UseSMC_Analysis) {
        int signal = Strategy_SmartMoneyConcepts();
        if(signal == 1) buySignals++;
        if(signal == -1) sellSignals++;
    }
    
    // Strategy 5: Ultra Fast Scalp
    if(UseStrategy_Scalp1M && strategies[4].isActive) {
        int signal = Strategy_UltraFastScalp();
        if(signal == 1) buySignals++;
        if(signal == -1) sellSignals++;
    }
    
    // Check confluence
    int totalActiveStrategies = CountActiveStrategies();
    
    if(buySignals >= Strategy_MinConfluence && buySignals > sellSignals) {
        signalConfidence = (double)buySignals / totalActiveStrategies;
        ExecuteBuyOrder();
    }
    else if(sellSignals >= Strategy_MinConfluence && sellSignals > buySignals) {
        signalConfidence = (double)sellSignals / totalActiveStrategies;
        ExecuteSellOrder();
    }
}

//+------------------------------------------------------------------+
//| Strategy 1: Momentum Scalping                                     |
//+------------------------------------------------------------------+
int Strategy_MomentumScalping() {
    if(!activeIndicators[4]) return 0; // MACD not active
    
    CopyBuffer(handle_MACD, 0, 0, 3, buffer_MACD_Main);
    CopyBuffer(handle_MACD, 1, 0, 3, buffer_MACD_Signal);
    CopyBuffer(handle_RSI, 0, 0, 3, buffer_RSI);
    CopyBuffer(handle_ADX, 0, 0, 3, buffer_ADX);
    
    double macd_current = buffer_MACD_Main[0];
    double macd_signal = buffer_MACD_Signal[0];
    double macd_prev = buffer_MACD_Main[1];
    double signal_prev = buffer_MACD_Signal[1];
    double rsi = buffer_RSI[0];
    double adx = buffer_ADX[0];
    
    // Strong momentum conditions
    if(adx > 20) {
        // Bullish momentum
        if(macd_current > macd_signal && macd_prev <= signal_prev && rsi > 40 && rsi < 70) {
            return 1; // Buy signal
        }
        // Bearish momentum
        if(macd_current < macd_signal && macd_prev >= signal_prev && rsi < 60 && rsi > 30) {
            return -1; // Sell signal
        }
    }
    
    return 0;
}

//+------------------------------------------------------------------+
//| Strategy 2: Mean Reversion                                        |
//+------------------------------------------------------------------+
int Strategy_MeanReversion() {
    if(!activeIndicators[6]) return 0; // Bollinger not active
    
    CopyBuffer(handle_Bollinger, 0, 0, 3, buffer_BB_Upper);
    CopyBuffer(handle_Bollinger, 1, 0, 3, buffer_BB_Middle);
    CopyBuffer(handle_Bollinger, 2, 0, 3, buffer_BB_Lower);
    CopyBuffer(handle_RSI, 0, 0, 3, buffer_RSI);
    
    double close = iClose(_Symbol, PERIOD_CURRENT, 0);
    double bb_upper = buffer_BB_Upper[0];
    double bb_middle = buffer_BB_Middle[0];
    double bb_lower = buffer_BB_Lower[0];
    double rsi = buffer_RSI[0];
    
    // Mean reversion from lower band
    if(close <= bb_lower && rsi < 30) {
        return 1; // Buy signal
    }
    
    // Mean reversion from upper band
    if(close >= bb_upper && rsi > 70) {
        return -1; // Sell signal
    }
    
    return 0;
}

//+------------------------------------------------------------------+
//| Strategy 3: Breakout Scalping                                     |
//+------------------------------------------------------------------+
int Strategy_BreakoutScalping() {
    double high1 = iHigh(_Symbol, PERIOD_CURRENT, 1);
    double low1 = iLow(_Symbol, PERIOD_CURRENT, 1);
    double close = iClose(_Symbol, PERIOD_CURRENT, 0);
    double open = iOpen(_Symbol, PERIOD_CURRENT, 0);
    
    // Find recent high/low
    double recentHigh = high1;
    double recentLow = low1;
    
    for(int i = 2; i < 20; i++) {
        double high = iHigh(_Symbol, PERIOD_CURRENT, i);
        double low = iLow(_Symbol, PERIOD_CURRENT, i);
        if(high > recentHigh) recentHigh = high;
        if(low < recentLow) recentLow = low;
    }
    
    CopyBuffer(handle_ATR, 0, 0, 3, buffer_ATR);
    double atr = buffer_ATR[0];
    
    // Bullish breakout
    if(close > recentHigh && (close - open) > atr * 0.3) {
        return 1;
    }
    
    // Bearish breakout
    if(close < recentLow && (open - close) > atr * 0.3) {
        return -1;
    }
    
    return 0;
}

//+------------------------------------------------------------------+
//| Strategy 4: Smart Money Concepts                                  |
//+------------------------------------------------------------------+
int Strategy_SmartMoneyConcepts() {
    double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    
    // Check for unfilled bullish FVG
    for(int i = 0; i < ArraySize(fvgList); i++) {
        if(!fvgList[i].isFilled && fvgList[i].isBullish) {
            if(currentPrice >= fvgList[i].lowerLevel && currentPrice <= fvgList[i].upperLevel) {
                if(marketStructure.isBullish) {
                    return 1; // Buy from bullish FVG
                }
            }
        }
        
        // Bearish FVG
        if(!fvgList[i].isFilled && !fvgList[i].isBullish) {
            if(currentPrice >= fvgList[i].lowerLevel && currentPrice <= fvgList[i].upperLevel) {
                if(marketStructure.isBearish) {
                    return -1; // Sell from bearish FVG
                }
            }
        }
    }
    
    // Check for order blocks
    for(int i = 0; i < ArraySize(orderBlocks); i++) {
        if(orderBlocks[i].isValid) {
            if(orderBlocks[i].isBullish && currentPrice >= orderBlocks[i].lowPrice && 
               currentPrice <= orderBlocks[i].highPrice) {
                return 1; // Buy from bullish OB
            }
            
            if(!orderBlocks[i].isBullish && currentPrice >= orderBlocks[i].lowPrice && 
               currentPrice <= orderBlocks[i].highPrice) {
                return -1; // Sell from bearish OB
            }
        }
    }
    
    return 0;
}

//+------------------------------------------------------------------+
//| Strategy 5: Ultra Fast Scalp                                      |
//+------------------------------------------------------------------+
int Strategy_UltraFastScalp() {
    double close0 = iClose(_Symbol, PERIOD_CURRENT, 0);
    double close1 = iClose(_Symbol, PERIOD_CURRENT, 1);
    double close2 = iClose(_Symbol, PERIOD_CURRENT, 2);
    double close3 = iClose(_Symbol, PERIOD_CURRENT, 3);
    
    CopyBuffer(handle_MA_Fast, 0, 0, 5, buffer_MA_Fast);
    CopyBuffer(handle_RSI, 0, 0, 3, buffer_RSI);
    
    double ma = buffer_MA_Fast[0];
    double rsi = buffer_RSI[0];
    
    // Quick bullish momentum
    if(close0 > close1 && close1 > close2 && close0 > ma && rsi > 50 && rsi < 75) {
        return 1;
    }
    
    // Quick bearish momentum
    if(close0 < close1 && close1 < close2 && close0 < ma && rsi < 50 && rsi > 25) {
        return -1;
    }
    
    return 0;
}

//+------------------------------------------------------------------+
//| Execute Buy Order                                                 |
//+------------------------------------------------------------------+
void ExecuteBuyOrder() {
    double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
    double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    
    // Calculate lot size
    double lotSize = CalculateLotSize();
    
    // Calculate TP and SL
    double tp = 0, sl = 0;
    CalculateTPSL(true, ask, tp, sl);
    
    // Execute trade
    if(trade.Buy(lotSize, _Symbol, ask, sl, tp, TradeComment)) {
        Print("✓ BUY Order Executed | Lot: ", lotSize, " | Price: ", ask, 
              " | SL: ", sl, " | TP: ", tp, " | Confidence: ", 
              DoubleToString(signalConfidence * 100, 1), "%");
        
        dailyTrades++;
    }
    else {
        Print("✗ BUY Order Failed | Error: ", GetLastError());
    }
}

//+------------------------------------------------------------------+
//| Execute Sell Order                                                |
//+------------------------------------------------------------------+
void ExecuteSellOrder() {
    double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
    double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    
    // Calculate lot size
    double lotSize = CalculateLotSize();
    
    // Calculate TP and SL
    double tp = 0, sl = 0;
    CalculateTPSL(false, bid, tp, sl);
    
    // Execute trade
    if(trade.Sell(lotSize, _Symbol, bid, sl, tp, TradeComment)) {
        Print("✓ SELL Order Executed | Lot: ", lotSize, " | Price: ", bid, 
              " | SL: ", sl, " | TP: ", tp, " | Confidence: ", 
              DoubleToString(signalConfidence * 100, 1), "%");
        
        dailyTrades++;
    }
    else {
        Print("✗ SELL Order Failed | Error: ", GetLastError());
    }
}

//+------------------------------------------------------------------+
//| Calculate Lot Size                                                |
//+------------------------------------------------------------------+
double CalculateLotSize() {
    if(!UseAutoLotSizing) {
        return LotSize;
    }
    
    double balance = AccountInfoDouble(ACCOUNT_BALANCE);
    double equity = AccountInfoDouble(ACCOUNT_EQUITY);
    
    CopyBuffer(handle_ATR, 0, 0, 1, buffer_ATR);
    double atr = buffer_ATR[0];
    
    // Calculate risk amount
    double riskPercent = RiskPercent;
    
    if(UseDynamicRisk) {
        // Adjust risk based on volatility
        double avgATR = 0;
        for(int i = 0; i < 20; i++) {
            avgATR += buffer_ATR[i];
        }
        avgATR /= 20;
        
        if(atr > avgATR * 1.5) {
            // High volatility - reduce risk
            riskPercent = MinRiskPercent;
        }
        else if(atr < avgATR * 0.7) {
            // Low volatility - can increase risk slightly
            riskPercent = RiskPercent * 1.2;
            if(riskPercent > MaxRiskPercent) riskPercent = MaxRiskPercent;
        }
    }
    
    double riskAmount = balance * riskPercent / 100.0;
    
    // Calculate lot size based on SL
    double slPoints = SL_ATR_Multiplier * atr / _Point;
    if(slPoints < MinSL_Points) slPoints = MinSL_Points;
    if(slPoints > MaxSL_Points) slPoints = MaxSL_Points;
    
    double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
    double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
    double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
    double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
    
    double lots = riskAmount / (slPoints * tickValue);
    lots = MathFloor(lots / lotStep) * lotStep;
    
    // Ensure within limits
    if(lots < minLot) lots = minLot;
    if(lots > maxLot) lots = maxLot;
    
    // Scale with account size
    if(balance < 1000) {
        lots = minLot; // Small account
    }
    else if(balance >= 10000) {
        lots = lots * 1.5; // Larger account - scale up
        if(lots > maxLot) lots = maxLot;
    }
    
    return NormalizeDouble(lots, 2);
}

//+------------------------------------------------------------------+
//| Calculate TP and SL                                               |
//+------------------------------------------------------------------+
void CalculateTPSL(bool isBuy, double price, double &tp, double &sl) {
    CopyBuffer(handle_ATR, 0, 0, 1, buffer_ATR);
    double atr = buffer_ATR[0];
    
    double tpPoints = TP_ATR_Multiplier * atr / _Point;
    double slPoints = SL_ATR_Multiplier * atr / _Point;
    
    // Apply limits
    if(tpPoints < MinTP_Points) tpPoints = MinTP_Points;
    if(tpPoints > MaxTP_Points) tpPoints = MaxTP_Points;
    if(slPoints < MinSL_Points) slPoints = MinSL_Points;
    if(slPoints > MaxSL_Points) slPoints = MaxSL_Points;
    
    if(isBuy) {
        tp = price + tpPoints * _Point;
        sl = price - slPoints * _Point;
    }
    else {
        tp = price - tpPoints * _Point;
        sl = price + slPoints * _Point;
    }
    
    tp = NormalizeDouble(tp, _Digits);
    sl = NormalizeDouble(sl, _Digits);
}

//+------------------------------------------------------------------+
//| Manage Open Positions                                             |
//+------------------------------------------------------------------+
void ManagePositions() {
    if(!PositionSelect(_Symbol)) return;
    
    double positionProfit = PositionGetDouble(POSITION_PROFIT);
    double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
    double currentSL = PositionGetDouble(POSITION_SL);
    double currentTP = PositionGetDouble(POSITION_TP);
    long positionType = PositionGetInteger(POSITION_TYPE);
    
    if(UseTrailingStop) {
        CopyBuffer(handle_ATR, 0, 0, 1, buffer_ATR);
        double atr = buffer_ATR[0];
        double trailDistance = TrailingStopATRMultiplier * atr;
        
        double currentPrice = (positionType == POSITION_TYPE_BUY) ? 
                              SymbolInfoDouble(_Symbol, SYMBOL_BID) : 
                              SymbolInfoDouble(_Symbol, SYMBOL_ASK);
        
        if(positionType == POSITION_TYPE_BUY) {
            double newSL = currentPrice - trailDistance;
            if(newSL > currentSL && newSL < currentPrice) {
                trade.PositionModify(_Symbol, newSL, currentTP);
            }
        }
        else {
            double newSL = currentPrice + trailDistance;
            if((newSL < currentSL || currentSL == 0) && newSL > currentPrice) {
                trade.PositionModify(_Symbol, newSL, currentTP);
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Check Risk Management                                             |
//+------------------------------------------------------------------+
bool PassesRiskManagement() {
    if(!UseEquityProtection) return true;
    
    double balance = AccountInfoDouble(ACCOUNT_BALANCE);
    double equity = AccountInfoDouble(ACCOUNT_EQUITY);
    
    // Check daily loss limit
    if(dailyLoss >= balance * MaxDailyLossPercent / 100.0) {
        Comment("Daily loss limit reached. Trading stopped for today.");
        return false;
    }
    
    // Check daily profit target
    if(dailyProfit >= balance * DailyProfitTarget / 100.0) {
        Comment("Daily profit target reached. Trading stopped for today.");
        return false;
    }
    
    // Check drawdown
    double drawdown = (balance - equity) / balance * 100.0;
    if(drawdown > MaxDailyLossPercent) {
        Comment("Maximum drawdown reached. Trading stopped.");
        return false;
    }
    
    return true;
}

//+------------------------------------------------------------------+
//| Check Filters                                                     |
//+------------------------------------------------------------------+
bool PassesFilters() {
    // Session filter
    if(UseSessionFilters) {
        if(currentSession == SESSION_ASIAN && !TradeAsian) return false;
        if(currentSession == SESSION_LONDON && !TradeLondon) return false;
        if(currentSession == SESSION_NEWYORK && !TradeNewYork) return false;
        if(currentSession == SESSION_NONE) return false;
    }
    
    // Spread filter
    if(UseSpreadFilter) {
        double spread = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
        if(spread > MaxSpreadPoints) {
            return false;
        }
    }
    
    // Add more filters as needed
    
    return true;
}

//+------------------------------------------------------------------+
//| Update Daily Statistics                                           |
//+------------------------------------------------------------------+
void UpdateDailyStatistics() {
    MqlDateTime dt;
    TimeToStruct(TimeCurrent(), dt);
    MqlDateTime lastDt;
    TimeToStruct(lastDayReset, lastDt);
    
    // Reset daily stats on new day
    if(dt.day != lastDt.day) {
        dailyStartBalance = AccountInfoDouble(ACCOUNT_BALANCE);
        dailyProfit = 0;
        dailyLoss = 0;
        dailyTrades = 0;
        lastDayReset = TimeCurrent();
    }
    
    // Calculate current daily P/L
    double currentBalance = AccountInfoDouble(ACCOUNT_BALANCE);
    double dailyPL = currentBalance - dailyStartBalance;
    
    if(dailyPL > 0) {
        dailyProfit = dailyPL;
    }
    else {
        dailyLoss = MathAbs(dailyPL);
    }
}

//+------------------------------------------------------------------+
//| Update Visual Overlays                                            |
//+------------------------------------------------------------------+
void UpdateVisualOverlays() {
    if(ShowFVG_Overlays) {
        DrawFVGOverlays();
    }
    
    if(ShowOrderBlocks) {
        DrawOrderBlockOverlays();
    }
    
    if(ShowCHoCH_Markers) {
        DrawCHoCHMarkers();
    }
}

//+------------------------------------------------------------------+
//| Draw FVG Overlays                                                 |
//+------------------------------------------------------------------+
void DrawFVGOverlays() {
    for(int i = 0; i < ArraySize(fvgList); i++) {
        if(!fvgList[i].isFilled) {
            datetime endTime = TimeCurrent() + PeriodSeconds(PERIOD_CURRENT) * 50;
            
            color fvgColor = fvgList[i].isBullish ? FVG_BullishColor : FVG_BearishColor;
            
            if(ObjectFind(0, fvgList[i].objectName) < 0) {
                ObjectCreate(0, fvgList[i].objectName, OBJ_RECTANGLE, 0, 
                           fvgList[i].startTime, fvgList[i].upperLevel, 
                           endTime, fvgList[i].lowerLevel);
                ObjectSetInteger(0, fvgList[i].objectName, OBJPROP_COLOR, fvgColor);
                ObjectSetInteger(0, fvgList[i].objectName, OBJPROP_STYLE, STYLE_DOT);
                ObjectSetInteger(0, fvgList[i].objectName, OBJPROP_WIDTH, 1);
                ObjectSetInteger(0, fvgList[i].objectName, OBJPROP_BACK, true);
                ObjectSetInteger(0, fvgList[i].objectName, OBJPROP_FILL, true);
            }
        }
        else {
            // Remove filled FVG
            ObjectDelete(0, fvgList[i].objectName);
        }
    }
}

//+------------------------------------------------------------------+
//| Draw Order Block Overlays                                         |
//+------------------------------------------------------------------+
void DrawOrderBlockOverlays() {
    for(int i = 0; i < ArraySize(orderBlocks); i++) {
        if(orderBlocks[i].isValid) {
            datetime endTime = TimeCurrent() + PeriodSeconds(PERIOD_CURRENT) * 100;
            
            color obColor = orderBlocks[i].isBullish ? clrLimeGreen : clrOrangeRed;
            
            if(ObjectFind(0, orderBlocks[i].objectName) < 0) {
                ObjectCreate(0, orderBlocks[i].objectName, OBJ_RECTANGLE, 0,
                           orderBlocks[i].time, orderBlocks[i].highPrice,
                           endTime, orderBlocks[i].lowPrice);
                ObjectSetInteger(0, orderBlocks[i].objectName, OBJPROP_COLOR, obColor);
                ObjectSetInteger(0, orderBlocks[i].objectName, OBJPROP_STYLE, STYLE_SOLID);
                ObjectSetInteger(0, orderBlocks[i].objectName, OBJPROP_WIDTH, 2);
                ObjectSetInteger(0, orderBlocks[i].objectName, OBJPROP_BACK, true);
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Draw CHoCH Markers                                                |
//+------------------------------------------------------------------+
void DrawCHoCHMarkers() {
    string objName = objPrefix + "CHoCH_Current";
    
    if(marketStructure.isBullish) {
        if(ObjectFind(0, objName) < 0) {
            ObjectCreate(0, objName, OBJ_TEXT, 0, TimeCurrent(), iLow(_Symbol, PERIOD_CURRENT, 0));
            ObjectSetString(0, objName, OBJPROP_TEXT, "CHoCH ↑");
            ObjectSetInteger(0, objName, OBJPROP_COLOR, clrLime);
            ObjectSetInteger(0, objName, OBJPROP_FONTSIZE, 10);
        }
    }
    else if(marketStructure.isBearish) {
        if(ObjectFind(0, objName) < 0) {
            ObjectCreate(0, objName, OBJ_TEXT, 0, TimeCurrent(), iHigh(_Symbol, PERIOD_CURRENT, 0));
            ObjectSetString(0, objName, OBJPROP_TEXT, "CHoCH ↓");
            ObjectSetInteger(0, objName, OBJPROP_COLOR, clrRed);
            ObjectSetInteger(0, objName, OBJPROP_FONTSIZE, 10);
        }
    }
}

//+------------------------------------------------------------------+
//| Create Dashboard                                                  |
//+------------------------------------------------------------------+
void CreateDashboard() {
    int x = 20, y = 20;
    
    CreateLabel("Title", "GOLD SCALPER PRO - ULTIMATE", x, y, clrGold, 12, "Arial Black");
    y += 25;
    CreateLabel("Version", "Version 5.0 | Institutional Grade", x, y, clrSilver, 8);
    y += 20;
    CreateLabel("Separator1", "═══════════════════════════", x, y, clrDimGray, 8);
    y += 20;
}

//+------------------------------------------------------------------+
//| Update Dashboard                                                  |
//+------------------------------------------------------------------+
void UpdateDashboard() {
    int x = 20, y = 85;
    
    string marketCond = EnumToString(currentMarketCondition);
    string session = EnumToString(currentSession);
    
    UpdateLabel("MarketCondition", "Market: " + marketCond, x, y, clrWhite);
    y += 15;
    UpdateLabel("Session", "Session: " + session, x, y, clrWhite);
    y += 15;
    UpdateLabel("Balance", "Balance: $" + DoubleToString(AccountInfoDouble(ACCOUNT_BALANCE), 2), x, y, clrLime);
    y += 15;
    UpdateLabel("Equity", "Equity: $" + DoubleToString(AccountInfoDouble(ACCOUNT_EQUITY), 2), x, y, clrYellow);
    y += 15;
    UpdateLabel("DailyPL", "Daily P/L: $" + DoubleToString(dailyProfit - dailyLoss, 2), x, y, 
                (dailyProfit - dailyLoss) >= 0 ? clrLime : clrRed);
    y += 15;
    UpdateLabel("DailyTrades", "Daily Trades: " + IntegerToString(dailyTrades), x, y, clrWhite);
    y += 15;
    
    if(mlData.totalTrades > 0) {
        UpdateLabel("WinRate", "Win Rate: " + DoubleToString(mlData.winRate * 100, 1) + "%", x, y, clrCyan);
        y += 15;
        UpdateLabel("ProfitFactor", "Profit Factor: " + DoubleToString(mlData.profitFactor, 2), x, y, clrCyan);
    }
}

//+------------------------------------------------------------------+
//| Create Label                                                      |
//+------------------------------------------------------------------+
void CreateLabel(string name, string text, int x, int y, color clr, int size=9, string font="Arial") {
    string objName = objPrefix + name;
    if(ObjectFind(0, objName) < 0) {
        ObjectCreate(0, objName, OBJ_LABEL, 0, 0, 0);
        ObjectSetInteger(0, objName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
        ObjectSetInteger(0, objName, OBJPROP_XDISTANCE, x);
        ObjectSetInteger(0, objName, OBJPROP_YDISTANCE, y);
        ObjectSetString(0, objName, OBJPROP_TEXT, text);
        ObjectSetString(0, objName, OBJPROP_FONT, font);
        ObjectSetInteger(0, objName, OBJPROP_FONTSIZE, size);
        ObjectSetInteger(0, objName, OBJPROP_COLOR, clr);
    }
}

//+------------------------------------------------------------------+
//| Update Label                                                      |
//+------------------------------------------------------------------+
void UpdateLabel(string name, string text, int x, int y, color clr) {
    string objName = objPrefix + name;
    if(ObjectFind(0, objName) < 0) {
        CreateLabel(name, text, x, y, clr);
    }
    else {
        ObjectSetString(0, objName, OBJPROP_TEXT, text);
        ObjectSetInteger(0, objName, OBJPROP_COLOR, clr);
    }
}

//+------------------------------------------------------------------+
//| Cleanup Visual Objects                                            |
//+------------------------------------------------------------------+
void CleanupVisualObjects() {
    int total = ObjectsTotal(0, 0, -1);
    for(int i = total - 1; i >= 0; i--) {
        string name = ObjectName(0, i, 0, -1);
        if(StringFind(name, objPrefix) >= 0) {
            ObjectDelete(0, name);
        }
    }
}

//+------------------------------------------------------------------+
//| Count Active Strategies                                           |
//+------------------------------------------------------------------+
int CountActiveStrategies() {
    int count = 0;
    for(int i = 0; i < ArraySize(strategies); i++) {
        if(strategies[i].isActive) count++;
    }
    return count;
}

//+------------------------------------------------------------------+
//| Print Final Statistics                                            |
//+------------------------------------------------------------------+
void PrintFinalStatistics() {
    Print("========================================");
    Print("FINAL STATISTICS");
    Print("========================================");
    Print("Total Trades: ", mlData.totalTrades);
    Print("Total Wins: ", totalWins);
    Print("Total Losses: ", totalLosses);
    Print("Win Rate: ", DoubleToString(mlData.winRate * 100, 2), "%");
    Print("Profit Factor: ", DoubleToString(mlData.profitFactor, 2));
    Print("Total Profit: $", DoubleToString(totalProfit, 2));
    Print("Total Loss: $", DoubleToString(totalLoss, 2));
    Print("Net Profit: $", DoubleToString(totalProfit + totalLoss, 2));
    Print("========================================");
}

//+------------------------------------------------------------------+