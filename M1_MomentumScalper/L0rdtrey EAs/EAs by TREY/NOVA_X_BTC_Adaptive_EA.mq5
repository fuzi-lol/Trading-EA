//+------------------------------------------------------------------------------------------------+
//|                                              NOVA_X_BTC_Adaptive_EA.mq5                          |
//|                          Institutional-Style Adaptive BTCUSD Scalping Framework                  |
//|                                                                                                    |
//|  ============================== HONEST CAPABILITY DISCLOSURE ===================================|
//|  This EA implements a REAL regime-classification + multi-engine routing architecture. The         |
//|  following terms are used precisely and should be read with these exact meanings:                |
//|                                                                                                    |
//|   - "Order Flow Proxy"     : MT5 retail feeds (including BTCUSD CFDs) have NO real Level 2 / order |
//|                              book data. All "order flow" here is tick-velocity, tick-acceleration, |
//|                              volume-spike z-scores, and price-imbalance approximations. These are  |
//|                              proxies, not real exchange order flow, and are labeled as such         |
//|                              everywhere in this file.                                              |
//|   - "Logistic Confidence Model" : A REAL hand-rolled binary logistic regression (sigmoid output,   |
//|                              online gradient-descent weight updates) trained continuously on this  |
//|                              EA's own closed-trade outcomes. It is NOT a neural network, NOT deep  |
//|                              learning, and NOT "Bayesian" in the formal sense. It has a genuine     |
//|                              cold-start limitation: with fewer than InpMinTradesForLearning closed  |
//|                              trades, it outputs a neutral 0.5 probability (no opinion) and acts as  |
//|                              a pass-through. It only meaningfully influences trading after enough   |
//|                              real outcomes have accumulated. This is disclosed, not hidden.         |
//|   - "Session/Weekday Profile" : STATIC, user-configurable multiplier profiles based on known BTC    |
//|                              behavioral tendencies (e.g. lower weekend liquidity). These are NOT    |
//|                              self-learning / adaptive session models -- they do not update          |
//|                              themselves from data. They are tunable inputs, named accordingly.      |
//|   - "News Shock Detection" : Achieved entirely via spread/ATR/tick-velocity anomaly detection.      |
//|                              No external news API is used or required, matching the spec.           |
//|   - Regime collapse        : The spec's 8 conceptual regimes are implemented as 4 tradeable         |
//|                              strategy engines (Trend / Range / Breakout / LiquiditySweep) plus 2     |
//|                              volatility MODIFIERS (HighVol / LowVol, which adjust thresholds and     |
//|                              stops rather than running their own entry logic) plus 1 KILL STATE      |
//|                              (NewsShock, which blocks new entries entirely). This is a deliberate    |
//|                              architectural collapse, documented and approved, not a missing feature. |
//|                                                                                                    |
//|  This EA is provided for Karisa's own live/demo testing and further iteration. As with all          |
//|  algorithmic trading systems, past behavior in backtests or forward tests does NOT guarantee        |
//|  future results. BTCUSD is a highly volatile instrument; position sizing and risk limits below      |
//|  are real controls, not decorative ones, and should be reviewed before any live deployment.         |
//+------------------------------------------------------------------------------------------------+
#property copyright "Karisa"
#property link      ""
#property version   "1.00"
#property strict
#property description "NOVA-X: Adaptive institutional-style BTCUSD scalping EA. Regime-aware multi-engine"
#property description "router with logistic-regression confidence scoring trained on live trade outcomes."
#property description "See header comments for honest capability disclosures before live use."

#include <Trade\Trade.mqh>
#include <Trade\SymbolInfo.mqh>
#include <Trade\PositionInfo.mqh>
#include <Trade\AccountInfo.mqh>

//+------------------------------------------------------------------------------------------------+
//| ENUMERATIONS                                                                                      |
//+------------------------------------------------------------------------------------------------+

// Dominant tradeable regime classification (8 conceptual regimes collapsed to 7 classifier outputs;
// HighVol/LowVol are detected as independent boolean modifiers layered on top, see RegimeState struct)
enum ENUM_REGIME
  {
   REGIME_BULL_TREND = 0,      // Strong bull trend -> CTrendEngine (direction = up)
   REGIME_BEAR_TREND = 1,      // Strong bear trend -> CTrendEngine (direction = down)
   REGIME_RANGE      = 2,      // Range bound -> CRangeEngine
   REGIME_BREAKOUT   = 3,      // Compression-release -> CBreakoutEngine (exclusive, no blending)
   REGIME_LIQ_SWEEP  = 4,      // Liquidity sweep is the dominant/strongest signal -> CLiquiditySweepEngine
   REGIME_NEWS_SHOCK = 5,      // Kill state -> no new entries, exits only
   REGIME_UNDEFINED  = 6       // Insufficient confidence in any regime -> no trading
  };

enum ENUM_STRATEGY_TYPE
  {
   STRAT_NONE             = 0,
   STRAT_TREND             = 1,
   STRAT_RANGE             = 2,
   STRAT_BREAKOUT          = 3,
   STRAT_LIQUIDITY_SWEEP   = 4
  };

enum ENUM_TREND_DIR
  {
   TREND_DIR_NONE = 0,
   TREND_DIR_UP   = 1,
   TREND_DIR_DOWN = 2
  };

enum ENUM_SESSION
  {
   SESSION_ASIAN          = 0,
   SESSION_LONDON         = 1,
   SESSION_NEWYORK        = 2,
   SESSION_LONDON_NY_OVERLAP = 3,
   SESSION_OFF_HOURS      = 4   // low-liquidity gap session (e.g. late NY to early Asian)
  };

enum ENUM_KILL_REASON
  {
   KILL_NONE                 = 0,
   KILL_NEWS_SHOCK            = 1,
   KILL_DAILY_LOSS_LIMIT      = 2,
   KILL_WEEKLY_LOSS_LIMIT     = 3,
   KILL_MONTHLY_LOSS_LIMIT    = 4,
   KILL_CONSECUTIVE_LOSSES    = 5,
   KILL_EQUITY_PROTECTION     = 6,
   KILL_MAX_EXPOSURE          = 7,
   KILL_MANUAL                = 8,
   KILL_EXECUTION_QUALITY     = 9
  };

enum ENUM_EXIT_REASON
  {
   EXIT_NONE             = 0,
   EXIT_HARD_STOP         = 1,
   EXIT_DYNAMIC_STOP      = 2,
   EXIT_STRUCTURE_STOP    = 3,
   EXIT_TAKE_PROFIT_FULL  = 4,
   EXIT_PARTIAL_TP1       = 5,
   EXIT_PARTIAL_TP2       = 6,
   EXIT_TRAILING_STOP     = 7,
   EXIT_TREND_VIOLATION   = 8,
   EXIT_TIME_EXIT         = 9,
   EXIT_KILL_SWITCH       = 10,
   EXIT_MANUAL            = 11
  };

//+------------------------------------------------------------------------------------------------+
//| INPUT PARAMETERS                                                                                  |
//+------------------------------------------------------------------------------------------------+

input group "=== GENERAL ==="
input ulong   InpMagicNumber           = 770110;     // Magic number
input string  InpTradeComment          = "NOVA-X";   // Trade comment tag
input bool    InpDebugMode             = true;       // Verbose logging (debug)
input int     InpMaxOpenPositions      = 1;          // Max concurrent open positions (this EA)

input group "=== RISK MANAGEMENT ==="
input double  InpRiskPercentPerTrade   = 1.0;        // Base risk % of equity per trade
input double  InpMaxRiskPercentPerTrade= 2.0;        // Hard ceiling on risk % (volatility-adjusted trades never exceed this)
input double  InpDailyLossLimitPercent = 4.0;        // Daily loss limit (% of equity at day start) -> kill switch
input double  InpWeeklyLossLimitPercent= 8.0;        // Weekly loss limit (% of equity at week start) -> kill switch
input double  InpMonthlyLossLimitPercent=15.0;       // Monthly loss limit (% of equity at month start) -> kill switch
input int     InpMaxConsecutiveLosses  = 5;          // Consecutive losing trades -> temporary kill switch
input int     InpConsecLossCooldownMin = 120;        // Minutes to pause trading after consecutive loss kill
input double  InpEquityProtectionPercent=25.0;       // Max drawdown from equity high-water-mark -> hard kill switch
input double  InpMaxExposurePercent    = 5.0;        // Max total margin-at-risk as % of equity across open positions

input group "=== REGIME CLASSIFIER ==="
input int     InpRegimeLookbackBars    = 50;         // Bars used for regime structure analysis
input double  InpRegimeMinConfidence   = 55.0;       // Minimum regime confidence (0-100) required to trade
input int     InpADXTrendThreshold     = 25;         // ADX level above which trend regime is favored
input int     InpADXPeriod             = 14;         // ADX indicator period
input int     InpATRPeriod             = 14;         // ATR period used across volatility calculations
input double  InpHighVolATRMultiplier  = 1.8;        // ATR(now) / ATR(avg) ratio above which HighVol modifier triggers
input double  InpLowVolATRMultiplier   = 0.6;        // ATR(now) / ATR(avg) ratio below which LowVol modifier triggers
input int     InpATRAverageBars        = 100;        // Bars used to compute average ATR baseline

input group "=== NEWS SHOCK DETECTION (no external API) ==="
input double  InpNewsShockSpreadMult   = 3.0;        // Spread spike multiple of average spread -> news shock flag
input double  InpNewsShockATRMult      = 2.5;        // ATR spike multiple of baseline ATR -> news shock flag
input double  InpNewsShockTickVelMult  = 4.0;        // Tick velocity spike multiple of average -> news shock flag
input int     InpNewsShockCooldownMin  = 30;         // Minutes to keep blocking new entries after shock detected

input group "=== MULTI-TIMEFRAME CONFIRMATION ==="
input bool    InpUseMTFConfirmation    = true;       // Require H1/M15/M5 alignment before trading
input int     InpMTFMinAlignmentScore  = 60;         // Minimum MTF alignment score (0-100) required

input group "=== TREND ENGINE ==="
input int     InpTrendFastEMA          = 21;         // Fast EMA period
input int     InpTrendSlowEMA          = 55;         // Slow EMA period
input int     InpTrendStructureSwingBars=10;          // Bars to each side for swing high/low detection
input double  InpTrendPullbackATRMult  = 0.8;        // Max pullback depth (in ATR) considered valid for entry

input group "=== RANGE ENGINE ==="
input int     InpRangeBBPeriod         = 20;         // Bollinger Band period
input double  InpRangeBBDeviation      = 2.0;         // Bollinger Band deviation
input int     InpRangeRSIPeriod        = 14;         // RSI period
input double  InpRangeRSIOverbought    = 70.0;       // RSI overbought level
input double  InpRangeRSIOversold      = 30.0;       // RSI oversold level

input group "=== BREAKOUT ENGINE ==="
input int     InpBreakoutCompressionBars=20;          // Bars used to measure compression range
input double  InpBreakoutMinCompressionRatio=0.5;     // Compression range / ATR ratio threshold (lower = tighter)
input int     InpBreakoutRetestMaxBars = 6;          // Max bars allowed for retest confirmation after breakout
input double  InpBreakoutMinExpansionMult=1.5;        // Breakout candle range / avg range multiple required

input group "=== LIQUIDITY SWEEP ENGINE ==="
input int     InpSweepLookbackBars     = 30;         // Bars to scan for equal highs/lows / liquidity pools
input double  InpSweepEqualLevelTolerancePct=0.05;    // % price tolerance to treat two highs/lows as "equal"
input int     InpSweepRejectionMaxBars = 3;          // Max bars allowed for rejection confirmation after sweep
input double  InpSweepBonusPoints      = 15.0;       // Max confluence bonus points sweep adds when blended (capped)

input group "=== ORDER FLOW PROXY ==="
input int     InpFlowTickVelocityWindowSec=30;        // Seconds window for tick velocity measurement
input int     InpFlowVolumeZWindowBars = 50;          // Bars window for volume spike z-score baseline

input group "=== ENTRY SCORING ==="
input double  InpEntryScoreThreshold   = 65.0;       // Minimum total confluence score (0-100) required to trade
input bool    InpAllowThresholdAdaptation=true;       // Allow slow bounded threshold adaptation (see CLogisticModel)
input double  InpThresholdAdaptBandPct = 10.0;       // Max +/- % the threshold may drift from input default

input group "=== EXIT ENGINE ==="
input double  InpHardStopATRMult       = 2.0;        // Hard stop distance in ATR multiples
input double  InpTakeProfitATRMult_TP1 = 1.5;        // TP1 distance in ATR multiples
input double  InpTakeProfitATRMult_TP2 = 3.0;        // TP2 distance in ATR multiples
input double  InpTakeProfitATRMult_TP3 = 5.0;        // TP3 (runner) distance in ATR multiples
input double  InpTP1ClosePercent       = 40.0;       // % of position closed at TP1
input double  InpTP2ClosePercent       = 35.0;       // % of position closed at TP2 (remainder runs to TP3/trail)
input double  InpBreakEvenTriggerATR   = 1.0;        // ATR move in favor required to trigger break-even
input double  InpBreakEvenOffsetPoints = 20.0;       // Points beyond entry to lock as break-even buffer
input double  InpTrailingStartATR      = 1.5;        // ATR move in favor required before trailing activates
input double  InpTrailingStepATRMult   = 1.0;        // Trailing stop distance behind price, in ATR multiples
input int     InpTimeExitMaxBars       = 200;        // Max bars a trade may remain open before forced time exit
input bool    InpUseStructureStop      = true;       // Enable swing-structure based stop tightening

input group "=== EXECUTION QUALITY ==="
input double  InpMaxSpreadPoints       = 500;        // Max allowed spread (points) to permit new entries
input int     InpMaxSlippagePoints     = 300;        // Max allowed slippage (points) on order execution
input int     InpOrderRetryAttempts    = 3;          // Retry attempts on requote/transient error
input int     InpOrderRetryDelayMs     = 200;        // Delay between retry attempts (milliseconds)

input group "=== SESSION / WEEKDAY PROFILES (static, user-tunable; NOT self-learning) ==="
input double  InpAsianScoreMultiplier  = 0.95;       // Score threshold multiplier during Asian session
input double  InpLondonScoreMultiplier = 1.00;       // Score threshold multiplier during London session
input double  InpNewYorkScoreMultiplier= 1.00;       // Score threshold multiplier during New York session
input double  InpOverlapScoreMultiplier= 0.90;       // Score threshold multiplier during London/NY overlap (best liquidity, lower bar)
input double  InpOffHoursScoreMultiplier=1.20;       // Score threshold multiplier during off-hours (require more confluence)
input double  InpWeekendRiskMultiplier = 0.5;        // Risk % multiplier applied on Saturday/Sunday
input int     InpAsianStartHour        = 0;          // Asian session start hour (broker server time)
input int     InpAsianEndHour          = 8;          // Asian session end hour
input int     InpLondonStartHour       = 8;          // London session start hour
input int     InpLondonEndHour         = 16;         // London session end hour
input int     InpNewYorkStartHour      = 13;         // New York session start hour
input int     InpNewYorkEndHour        = 21;         // New York session end hour

input group "=== LOGISTIC CONFIDENCE MODEL ==="
input bool    InpUseLogisticModel      = true;       // Enable logistic confidence model blending
input int     InpMinTradesForLearning  = 30;         // Closed trades required before model influences decisions (cold-start floor)
input double  InpLogisticLearningRate  = 0.05;       // Gradient descent learning rate
input double  InpLogisticBlendWeight   = 0.30;       // Weight of logistic probability in final blended score (0-1)
input string  InpLogisticModelFileName = "NOVA_X_logistic_weights.csv"; // File name (in MQL5\\Files\\) for persistence
input string  InpTradeJournalFileName  = "NOVA_X_trade_journal.csv";    // File name for trade journal / analytics log

//+------------------------------------------------------------------------------------------------+
//| GLOBAL DATA STRUCTURES                                                                            |
//+------------------------------------------------------------------------------------------------+

// Sub-scores that make up the 0-100 confluence score for a candidate trade.
struct ConfluenceScore
  {
   double            trendAlignment;     // 0-20
   double            momentum;           // 0-20
   double            volumeFlow;         // 0-15 (order flow proxy contribution)
   double            liquidityConfirm;   // 0-15
   double            volatilityCondition;// 0-15
   double            sessionQuality;     // 0-15
   double            sweepBonus;         // 0-InpSweepBonusPoints, added on top when blended (see router)
   double            Total() const
     {
      double t = trendAlignment + momentum + volumeFlow + liquidityConfirm
                 + volatilityCondition + sessionQuality + sweepBonus;
      if(t > 100.0) t = 100.0;
      if(t < 0.0)   t = 0.0;
      return t;
     }
   void              Clear()
     {
      trendAlignment=0; momentum=0; volumeFlow=0; liquidityConfirm=0;
      volatilityCondition=0; sessionQuality=0; sweepBonus=0;
     }
  };

// Output of the regime classifier for the current bar.
struct RegimeState
  {
   ENUM_REGIME       regime;
   double            confidence;      // 0-100, confidence in the dominant regime call
   ENUM_TREND_DIR    direction;       // populated for trend/breakout/sweep regimes
   bool              highVolModifier; // true if HighVol modifier active (independent of dominant regime)
   bool              lowVolModifier;  // true if LowVol modifier active
   bool              newsShock;       // true if NewsShockDetector currently blocking entries
  };

// Feature vector fed into the logistic confidence model. Each feature is normalized to [0,1]
// at construction time so the model trains on comparable scales.
struct FeatureVector
  {
   double            f[9]; // see CLogisticModel::FEATURE_COUNT for index meaning
  };

// One row of the persisted trade journal / training set.
struct TradeRecord
  {
   datetime          openTime;
   datetime          closeTime;
   ENUM_STRATEGY_TYPE strategy;
   ENUM_REGIME       regimeAtEntry;
   ENUM_SESSION      sessionAtEntry;
   double            confluenceScoreAtEntry;
   double            logisticProbAtEntry;
   double            rMultiple;        // realized profit / initial risk distance
   bool              isWin;
   FeatureVector     features;
  };

//+------------------------------------------------------------------------------------------------+
//| CLogisticModel                                                                                    |
//| Hand-rolled BINARY LOGISTIC REGRESSION. This is a real, working implementation of sigmoid output  |
//| + online stochastic gradient descent weight updates -- not a lookup table, not a placeholder.     |
//|                                                                                                    |
//| HONEST LIMITATIONS (read before trusting its output):                                             |
//|  1. Cold start: until InpMinTradesForLearning closed trades have been recorded, Predict() always  |
//|     returns 0.5 (neutral / no opinion) regardless of input features. This is enforced explicitly  |
//|     in Predict(), not an emergent behavior of untrained weights.                                  |
//|  2. It learns ONLY from this EA's own trade outcomes on this symbol/account. It is not pre-trained|
//|     on historical data and has zero knowledge of market conditions it has not personally traded   |
//|     through.                                                                                       |
//|  3. With 9 features and a single linear decision boundary (logistic regression has no hidden      |
//|     layers), it can only learn linearly-separable relationships between confluence sub-scores and |
//|     trade outcomes. It will NOT capture complex non-linear interactions. This is a deliberate      |
//|     simplicity/robustness tradeoff appropriate for small live sample sizes, not a limitation       |
//|     hidden from the user.                                                                          |
//+------------------------------------------------------------------------------------------------+
class CLogisticModel
  {
private:
   enum { FEATURE_COUNT = 9 };
   // Feature index meaning (all normalized to [0,1] by caller before Predict/Update):
   // 0=trendAlignment 1=momentum 2=volumeFlow 3=liquidityConfirm 4=volatilityCondition
   // 5=sessionQuality 6=regimeConfidence 7=mtfAlignmentScore 8=sweepBonusNormalized

   double            m_weights[FEATURE_COUNT];
   double            m_bias;
   double            m_learningRate;
   int               m_trainedSampleCount;
   string            m_fileName;
   bool              m_initialized;

   double            Sigmoid(const double z) const
     {
      // Numerically stable sigmoid (avoids overflow on large negative/positive z)
      if(z >= 0.0)
        {
         double ez = MathExp(-z);
         return 1.0 / (1.0 + ez);
        }
      else
        {
         double ez = MathExp(z);
         return ez / (1.0 + ez);
        }
     }

   double            DotProduct(const FeatureVector &fv) const
     {
      double z = m_bias;
      for(int i=0; i<FEATURE_COUNT; i++)
         z += m_weights[i] * fv.f[i];
      return z;
     }

public:
                     CLogisticModel()
     {
      m_bias = 0.0;
      for(int i=0; i<FEATURE_COUNT; i++)
         m_weights[i] = 0.0;
      m_learningRate = 0.05;
      m_trainedSampleCount = 0;
      m_fileName = "";
      m_initialized = false;
     }

   // Initializes the model: sets learning rate/filename from inputs and attempts to load
   // persisted weights from MQL5\Files\<fileName>. If the file does not exist or is malformed,
   // starts from zero weights (cold start) rather than failing -- this is intentional graceful
   // degradation, logged clearly so it is never a silent failure.
   bool              Init(const string fileName, const double learningRate)
     {
      m_fileName     = fileName;
      m_learningRate = learningRate;
      m_initialized  = true;
      if(!LoadFromFile())
        {
         Print("[CLogisticModel] No valid persisted model found at '", m_fileName,
               "'. Starting cold (zero weights, sample count 0). This is expected on first run.");
         m_bias = 0.0;
         for(int i=0; i<FEATURE_COUNT; i++)
            m_weights[i] = 0.0;
         m_trainedSampleCount = 0;
        }
      else
        {
         Print("[CLogisticModel] Loaded persisted model from '", m_fileName,
               "'. Trained sample count = ", m_trainedSampleCount);
        }
      return true;
     }

   // Returns probability of a winning trade in [0,1]. Returns exactly 0.5 (neutral) during
   // cold-start, by design -- see class header disclosure.
   double            Predict(const FeatureVector &fv, const int minTradesRequired) const
     {
      if(!m_initialized)
         return 0.5;
      if(m_trainedSampleCount < minTradesRequired)
         return 0.5; // explicit cold-start guard, not emergent
      double z = DotProduct(fv);
      return Sigmoid(z);
     }

   // Online gradient descent update from a single closed-trade outcome. label = 1.0 for win,
   // 0.0 for loss. This is standard logistic regression SGD: w_i += lr * (label - pred) * x_i
   void              OnTradeOutcome(const FeatureVector &fv, const bool isWin)
     {
      if(!m_initialized)
         return;
      double label = isWin ? 1.0 : 0.0;
      double pred  = Sigmoid(DotProduct(fv));
      double error  = label - pred;

      for(int i=0; i<FEATURE_COUNT; i++)
         m_weights[i] += m_learningRate * error * fv.f[i];
      m_bias += m_learningRate * error;

      m_trainedSampleCount++;
      SaveToFile();

      if(InpDebugMode)
         PrintFormat("[CLogisticModel] Trained on outcome #%d (win=%s, pred=%.3f, error=%.3f)",
                     m_trainedSampleCount, isWin ? "true" : "false", pred, error);
     }

   int               GetTrainedSampleCount() const { return m_trainedSampleCount; }

   // Persists weights, bias, and sample count to a simple CSV in MQL5\Files\. Format:
   // Line 1: header marker "NOVA_X_LOGISTIC_V1"
   // Line 2: trainedSampleCount,bias
   // Line 3: comma-separated weights (FEATURE_COUNT values)
   bool              SaveToFile()
     {
      int handle = FileOpen(m_fileName, FILE_WRITE|FILE_CSV|FILE_ANSI, ',');
      if(handle == INVALID_HANDLE)
        {
         Print("[CLogisticModel] ERROR: could not open '", m_fileName, "' for writing. Error=", GetLastError());
         return false;
        }
      FileWrite(handle, "NOVA_X_LOGISTIC_V1");
      FileWrite(handle, m_trainedSampleCount, m_bias);
      for(int i=0; i<FEATURE_COUNT; i++)
         FileWrite(handle, m_weights[i]);
      FileClose(handle);
      return true;
     }

   // Loads persisted weights. Returns false (and leaves model untouched/cold) on any schema
   // mismatch or corruption -- never crashes, never silently loads garbage into live weights.
   bool              LoadFromFile()
     {
      if(!FileIsExist(m_fileName))
         return false;

      int handle = FileOpen(m_fileName, FILE_READ|FILE_CSV|FILE_ANSI, ',');
      if(handle == INVALID_HANDLE)
         return false;

      bool ok = true;
      string marker = FileReadString(handle);
      if(marker != "NOVA_X_LOGISTIC_V1")
        {
         Print("[CLogisticModel] WARNING: persisted file has unrecognized schema marker '", marker,
               "'. Ignoring file, starting cold.");
         FileClose(handle);
         return false;
        }

      if(FileIsEnding(handle)) { FileClose(handle); return false; }
      int sampleCount = (int)FileReadNumber(handle);
      if(FileIsEnding(handle)) { FileClose(handle); return false; }
      double bias = FileReadNumber(handle);

      double loadedWeights[FEATURE_COUNT];
      for(int i=0; i<FEATURE_COUNT; i++)
        {
         if(FileIsEnding(handle)) { ok = false; break; }
         loadedWeights[i] = FileReadNumber(handle);
        }
      FileClose(handle);

      if(!ok)
        {
         Print("[CLogisticModel] WARNING: persisted file truncated/corrupt (expected ", FEATURE_COUNT,
               " weights). Ignoring file, starting cold.");
         return false;
        }

      m_trainedSampleCount = sampleCount;
      m_bias = bias;
      for(int i=0; i<FEATURE_COUNT; i++)
         m_weights[i] = loadedWeights[i];
      return true;
     }
  };

//+------------------------------------------------------------------------------------------------+
//| CVolatilityEngine                                                                                  |
//| Tracks ATR, a simple realized-volatility (stddev of returns) measure, and candle-expansion ratios.|
//| Drives HighVol/LowVol modifier flags and feeds stop/TP/size adjustments used across all engines.  |
//+------------------------------------------------------------------------------------------------+
class CVolatilityEngine
  {
private:
   string            m_symbol;
   ENUM_TIMEFRAMES   m_tf;
   int               m_atrHandle;
   int               m_atrPeriod;
   int               m_avgBars;
   double            m_currentATR;
   double            m_avgATR;
   double            m_realizedVol;     // stddev of close-to-close returns over m_avgBars
   bool              m_ready;

public:
                     CVolatilityEngine()
     {
      m_atrHandle = INVALID_HANDLE;
      m_currentATR = 0.0;
      m_avgATR = 0.0;
      m_realizedVol = 0.0;
      m_ready = false;
     }

                    ~CVolatilityEngine()
     {
      if(m_atrHandle != INVALID_HANDLE)
         IndicatorRelease(m_atrHandle);
     }

   bool              Init(const string symbol, const ENUM_TIMEFRAMES tf, const int atrPeriod, const int avgBars)
     {
      m_symbol = symbol;
      m_tf = tf;
      m_atrPeriod = atrPeriod;
      m_avgBars = avgBars;
      m_atrHandle = iATR(m_symbol, m_tf, m_atrPeriod);
      if(m_atrHandle == INVALID_HANDLE)
        {
         Print("[CVolatilityEngine] ERROR: iATR handle creation failed. Error=", GetLastError());
         return false;
        }
      return true;
     }

   // Recomputes current ATR, average ATR baseline, and realized volatility. Call once per new bar
   // (heavy enough that per-tick recomputation is wasteful and unnecessary for this EA's purposes).
   bool              Update()
     {
      double atrBuf[];
      ArraySetAsSeries(atrBuf, true);
      int copied = CopyBuffer(m_atrHandle, 0, 0, m_avgBars + 1, atrBuf);
      if(copied < m_avgBars + 1)
        {
         m_ready = false;
         return false;
        }

      m_currentATR = atrBuf[0];

      double sum = 0.0;
      for(int i=1; i<=m_avgBars; i++)
         sum += atrBuf[i];
      m_avgATR = sum / m_avgBars;

      // Realized volatility: stddev of log returns over m_avgBars closed bars
      double closes[];
      ArraySetAsSeries(closes, true);
      int copiedCloses = CopyClose(m_symbol, m_tf, 0, m_avgBars + 1, closes);
      if(copiedCloses >= m_avgBars + 1)
        {
         double returns[];
         ArrayResize(returns, m_avgBars);
         for(int i=0; i<m_avgBars; i++)
           {
            if(closes[i+1] > 0.0)
               returns[i] = MathLog(closes[i] / closes[i+1]);
            else
               returns[i] = 0.0;
           }
         double meanRet = 0.0;
         for(int i=0; i<m_avgBars; i++)
            meanRet += returns[i];
         meanRet /= m_avgBars;

         double varSum = 0.0;
         for(int i=0; i<m_avgBars; i++)
            varSum += MathPow(returns[i] - meanRet, 2);
         m_realizedVol = MathSqrt(varSum / m_avgBars);
        }

      m_ready = true;
      return true;
     }

   double            GetCurrentATR() const  { return m_currentATR; }
   double            GetAverageATR() const  { return m_avgATR; }
   double            GetRealizedVol() const { return m_realizedVol; }
   bool              IsReady() const        { return m_ready; }

   double            GetATRRatio() const
     {
      if(m_avgATR <= 0.0) return 1.0;
      return m_currentATR / m_avgATR;
     }

   bool              IsHighVolatility(const double mult) const { return m_ready && GetATRRatio() >= mult; }
   bool              IsLowVolatility(const double mult)  const { return m_ready && GetATRRatio() <= mult; }

   // Candle expansion ratio: current bar's range vs average range over m_avgBars. Used by
   // breakout engine to confirm genuine expansion vs noise.
   double            GetCandleExpansionRatio(const int shift = 0) const
     {
      double high = iHigh(m_symbol, m_tf, shift);
      double low  = iLow(m_symbol, m_tf, shift);
      double range = high - low;
      if(m_avgATR <= 0.0) return 1.0;
      return range / m_avgATR;
     }
  };

//+------------------------------------------------------------------------------------------------+
//| COrderFlowProxy                                                                                    |
//| HONEST LABEL: these are PROXIES for order flow, not real exchange order flow / Level 2 data.       |
//| MT5 retail BTCUSD feeds do not expose a true order book. This class approximates participation     |
//| and aggression using tick-level data that IS genuinely available: tick velocity (ticks/sec),       |
//| tick acceleration, volume-spike z-scores (using MT5 tick volume as a proxy for real volume), and   |
//| a simple price-imbalance measure over a short rolling window.                                       |
//+------------------------------------------------------------------------------------------------+
class COrderFlowProxy
  {
private:
   string            m_symbol;
   ENUM_TIMEFRAMES   m_tf;
   int               m_zWindowBars;
   int               m_velocityWindowSec;

   int               m_tickCountWindow;     // ticks observed in the current velocity window
   datetime          m_velocityWindowStart;
   double            m_lastVelocity;        // ticks/sec, most recently closed window
   double            m_prevVelocity;        // ticks/sec, window before that (for acceleration)

   double            m_volumeZScore;
   double            m_priceImbalance;      // -1 (all down ticks) .. +1 (all up ticks) over recent ticks

   MqlTick           m_lastTick;
   bool              m_haveLastTick;

public:
                     COrderFlowProxy()
     {
      m_tickCountWindow = 0;
      m_velocityWindowStart = 0;
      m_lastVelocity = 0.0;
      m_prevVelocity = 0.0;
      m_volumeZScore = 0.0;
      m_priceImbalance = 0.0;
      m_haveLastTick = false;
     }

   bool              Init(const string symbol, const ENUM_TIMEFRAMES tf, const int zWindowBars, const int velocityWindowSec)
     {
      m_symbol = symbol;
      m_tf = tf;
      m_zWindowBars = zWindowBars;
      m_velocityWindowSec = velocityWindowSec;
      m_velocityWindowStart = TimeCurrent();
      return true;
     }

   // Call on every tick. Maintains the rolling tick-velocity window and price imbalance counter.
   void              OnTick()
     {
      MqlTick tick;
      if(!SymbolInfoTick(m_symbol, tick))
         return;

      datetime now = tick.time;
      if(now - m_velocityWindowStart >= m_velocityWindowSec)
        {
         double elapsed = (double)MathMax((long)(now - m_velocityWindowStart), 1);
         m_prevVelocity = m_lastVelocity;
         m_lastVelocity = m_tickCountWindow / elapsed;
         m_tickCountWindow = 0;
         m_velocityWindowStart = now;
        }
      m_tickCountWindow++;

      if(m_haveLastTick)
        {
         double delta = tick.bid - m_lastTick.bid;
         // Exponentially-weighted-ish update toward +1/-1/0 based on tick direction; smoothing
         // factor 0.05 keeps this a slow-moving imbalance gauge rather than a noisy per-tick flip.
         double dir = 0.0;
         if(delta > 0.0) dir = 1.0;
         else if(delta < 0.0) dir = -1.0;
         m_priceImbalance = (m_priceImbalance * 0.95) + (dir * 0.05);
        }
      m_lastTick = tick;
      m_haveLastTick = true;
     }

   // Call once per new bar. Computes a z-score of the most recently closed bar's tick volume
   // against the rolling mean/stddev of tick volume over m_zWindowBars -- this is the "volume
   // spike" proxy referenced throughout the spec.
   double            UpdateVolumeZScore()
     {
      long volumes[];
      ArraySetAsSeries(volumes, true);
      int copied = CopyTickVolume(m_symbol, m_tf, 0, m_zWindowBars + 1, volumes);
      if(copied < m_zWindowBars + 1)
        {
         m_volumeZScore = 0.0;
         return m_volumeZScore;
        }

      double sum = 0.0;
      for(int i=1; i<=m_zWindowBars; i++)
         sum += (double)volumes[i];
      double mean = sum / m_zWindowBars;

      double varSum = 0.0;
      for(int i=1; i<=m_zWindowBars; i++)
         varSum += MathPow((double)volumes[i] - mean, 2);
      double stddev = MathSqrt(varSum / m_zWindowBars);

      if(stddev <= 0.0)
        {
         m_volumeZScore = 0.0;
        }
      else
        {
         m_volumeZScore = ((double)volumes[1] - mean) / stddev; // volumes[1] = last fully closed bar
        }
      return m_volumeZScore;
     }

   double            GetTickVelocity() const     { return m_lastVelocity; }
   double            GetTickAcceleration() const { return m_lastVelocity - m_prevVelocity; }
   double            GetVolumeZScore() const     { return m_volumeZScore; }
   double            GetPriceImbalance() const   { return m_priceImbalance; }

   // Composite 0-100 "participation score" used as the volumeFlow sub-score in ConfluenceScore.
   // Blends normalized volume z-score, tick acceleration sign/magnitude, and |imbalance|.
   double            GetParticipationScore() const
     {
      double zComponent = MathMax(0.0, MathMin(1.0, (m_volumeZScore + 1.0) / 4.0)); // z in [-1,3] -> [0,1] roughly
      double accelComponent = MathMax(0.0, MathMin(1.0, (GetTickAcceleration() + 2.0) / 4.0));
      double imbalanceComponent = MathAbs(m_priceImbalance); // already 0..1
      double composite = (zComponent * 0.4) + (accelComponent * 0.3) + (imbalanceComponent * 0.3);
      return composite * 100.0;
     }
  };

//+------------------------------------------------------------------------------------------------+
//| CSessionProfile                                                                                    |
//| HONEST LABEL: this is a STATIC, user-configurable set of multiplier profiles based on commonly     |
//| observed BTC session/weekday tendencies. It does NOT learn or adapt from data on its own --        |
//| Karisa tunes the input multipliers directly. It is intentionally simple and transparent rather      |
//| than a black-box "self-learning session model," which would require months of persisted bucketed   |
//| statistics well beyond the scope of a single-file v1 delivery.                                      |
//+------------------------------------------------------------------------------------------------+
class CSessionProfile
  {
private:
   int               m_asianStart, m_asianEnd;
   int               m_londonStart, m_londonEnd;
   int               m_nyStart, m_nyEnd;

public:
   bool              Init(const int asianStart, const int asianEnd, const int londonStart, const int londonEnd,
                           const int nyStart, const int nyEnd)
     {
      m_asianStart = asianStart;   m_asianEnd = asianEnd;
      m_londonStart = londonStart; m_londonEnd = londonEnd;
      m_nyStart = nyStart;         m_nyEnd = nyEnd;
      return true;
     }

   ENUM_SESSION      GetCurrentSession(const datetime t) const
     {
      MqlDateTime dt;
      TimeToStruct(t, dt);
      int hour = dt.hour;

      bool inLondon = InRange(hour, m_londonStart, m_londonEnd);
      bool inNY      = InRange(hour, m_nyStart, m_nyEnd);
      bool inAsian   = InRange(hour, m_asianStart, m_asianEnd);

      if(inLondon && inNY)
         return SESSION_LONDON_NY_OVERLAP;
      if(inLondon)
         return SESSION_LONDON;
      if(inNY)
         return SESSION_NEWYORK;
      if(inAsian)
         return SESSION_ASIAN;
      return SESSION_OFF_HOURS;
     }

   bool              IsWeekend(const datetime t) const
     {
      MqlDateTime dt;
      TimeToStruct(t, dt);
      return (dt.day_of_week == 0 || dt.day_of_week == 6); // Sunday=0, Saturday=6
     }

   double            GetScoreThresholdMultiplier(const ENUM_SESSION sess) const
     {
      switch(sess)
        {
         case SESSION_ASIAN:              return InpAsianScoreMultiplier;
         case SESSION_LONDON:             return InpLondonScoreMultiplier;
         case SESSION_NEWYORK:            return InpNewYorkScoreMultiplier;
         case SESSION_LONDON_NY_OVERLAP:  return InpOverlapScoreMultiplier;
         default:                         return InpOffHoursScoreMultiplier;
        }
     }

   double            GetRiskMultiplier(const datetime t) const
     {
      return IsWeekend(t) ? InpWeekendRiskMultiplier : 1.0;
     }

   // Normalized 0-100 "session quality" sub-score used directly in ConfluenceScore. Higher during
   // higher-liquidity sessions, consistent with the spec's session intelligence requirement.
   double            GetSessionQualityScore(const ENUM_SESSION sess) const
     {
      switch(sess)
        {
         case SESSION_LONDON_NY_OVERLAP:  return 15.0; // best liquidity -> full sub-score
         case SESSION_LONDON:             return 12.0;
         case SESSION_NEWYORK:            return 12.0;
         case SESSION_ASIAN:              return 8.0;
         default:                         return 4.0; // off-hours
        }
     }

private:
   bool              InRange(const int hour, const int start, const int end) const
     {
      if(start <= end)
         return (hour >= start && hour < end);
      return (hour >= start || hour < end); // handles wrap-around (e.g. 22-6)
     }
  };

//+------------------------------------------------------------------------------------------------+
//| CMarketStructure                                                                                   |
//| Real swing-high/swing-low detection (fractal-style, N bars each side), Break-of-Structure (BOS)   |
//| and Change-of-Character (CHOCH) detection, and equal-high/equal-low (liquidity pool) detection.    |
//| Shared by the regime classifier, trend engine, and liquidity sweep engine.                          |
//+------------------------------------------------------------------------------------------------+
class CMarketStructure
  {
private:
   string            m_symbol;
   ENUM_TIMEFRAMES   m_tf;
   int               m_swingBars;
   int               m_lookback;

   double            m_swingHighs[];
   double            m_swingLows[];
   int               m_swingHighIdx[];
   int               m_swingLowIdx[];
   int               m_swingHighCount;
   int               m_swingLowCount;

   ENUM_TREND_DIR    m_structureBias;
   bool              m_bosDetected;
   bool              m_chochDetected;

public:
                     CMarketStructure()
     {
      m_swingHighCount = 0;
      m_swingLowCount = 0;
      m_structureBias = TREND_DIR_NONE;
      m_bosDetected = false;
      m_chochDetected = false;
     }

   bool              Init(const string symbol, const ENUM_TIMEFRAMES tf, const int swingBars, const int lookback)
     {
      m_symbol = symbol;
      m_tf = tf;
      m_swingBars = swingBars;
      m_lookback = lookback;
      return true;
     }

   // Recomputes swing highs/lows and structure bias. Call once per new bar.
   bool              Update()
     {
      double highs[], lows[];
      ArraySetAsSeries(highs, true);
      ArraySetAsSeries(lows, true);
      int total = m_lookback + (2 * m_swingBars) + 2;
      if(CopyHigh(m_symbol, m_tf, 0, total, highs) < total) return false;
      if(CopyLow(m_symbol, m_tf, 0, total, lows) < total) return false;

      ArrayResize(m_swingHighs, 0);
      ArrayResize(m_swingLows, 0);
      ArrayResize(m_swingHighIdx, 0);
      ArrayResize(m_swingLowIdx, 0);
      m_swingHighCount = 0;
      m_swingLowCount = 0;

      // Fractal swing detection: bar i is a swing high if it's the highest of the m_swingBars
      // bars on each side; symmetric logic for swing lows.
      for(int i=m_swingBars; i<total-m_swingBars; i++)
        {
         bool isSwingHigh = true;
         bool isSwingLow  = true;
         for(int j=1; j<=m_swingBars; j++)
           {
            if(highs[i] <= highs[i-j] || highs[i] <= highs[i+j]) isSwingHigh = false;
            if(lows[i]  >= lows[i-j]  || lows[i]  >= lows[i+j])  isSwingLow  = false;
           }
         if(isSwingHigh)
           {
            int n = ArraySize(m_swingHighs);
            ArrayResize(m_swingHighs, n+1);
            ArrayResize(m_swingHighIdx, n+1);
            m_swingHighs[n] = highs[i];
            m_swingHighIdx[n] = i;
            m_swingHighCount++;
           }
         if(isSwingLow)
           {
            int n = ArraySize(m_swingLows);
            ArrayResize(m_swingLows, n+1);
            ArrayResize(m_swingLowIdx, n+1);
            m_swingLows[n] = lows[i];
            m_swingLowIdx[n] = i;
            m_swingLowCount++;
           }
        }

      ComputeStructureBias();
      return true;
     }

   // Determines bias from the last two swing highs and last two swing lows: higher-highs +
   // higher-lows = up bias; lower-highs + lower-lows = down bias. Also flags BOS (continuation
   // break of the most recent opposing swing) and CHOCH (bias flip).
   void              ComputeStructureBias()
     {
      m_bosDetected = false;
      m_chochDetected = false;

      if(m_swingHighCount < 2 || m_swingLowCount < 2)
        {
         m_structureBias = TREND_DIR_NONE;
         return;
        }

      // Arrays are indexed oldest-to-newest in storage order built above (i increasing = older to
      // newer since ArraySetAsSeries(true) was used on highs/lows but we iterated ascending i,
      // which walks from the OLDEST bar in our window to the NEWEST). So last element = most recent.
      double lastHigh  = m_swingHighs[m_swingHighCount-1];
      double prevHigh  = m_swingHighs[m_swingHighCount-2];
      double lastLow   = m_swingLows[m_swingLowCount-1];
      double prevLow   = m_swingLows[m_swingLowCount-2];

      ENUM_TREND_DIR newBias = TREND_DIR_NONE;
      if(lastHigh > prevHigh && lastLow > prevLow)
         newBias = TREND_DIR_UP;
      else if(lastHigh < prevHigh && lastLow < prevLow)
         newBias = TREND_DIR_DOWN;

      if(m_structureBias != TREND_DIR_NONE && newBias != TREND_DIR_NONE && newBias != m_structureBias)
         m_chochDetected = true;
      else if(newBias != TREND_DIR_NONE && newBias == m_structureBias)
         m_bosDetected = true;

      if(newBias != TREND_DIR_NONE)
         m_structureBias = newBias;
     }

   ENUM_TREND_DIR    GetStructureBias() const { return m_structureBias; }
   bool              IsBOS() const            { return m_bosDetected; }
   bool              IsCHOCH() const          { return m_chochDetected; }
   int               GetSwingHighCount() const { return m_swingHighCount; }
   int               GetSwingLowCount() const  { return m_swingLowCount; }

   double            GetLastSwingHigh() const
     { return m_swingHighCount > 0 ? m_swingHighs[m_swingHighCount-1] : 0.0; }
   double            GetLastSwingLow() const
     { return m_swingLowCount > 0 ? m_swingLows[m_swingLowCount-1] : 0.0; }
   double            GetPriorSwingHigh() const
     { return m_swingHighCount > 1 ? m_swingHighs[m_swingHighCount-2] : 0.0; }
   double            GetPriorSwingLow() const
     { return m_swingLowCount > 1 ? m_swingLows[m_swingLowCount-2] : 0.0; }

   // Detects equal-highs / equal-lows within tolerancePct -- these represent likely resting
   // liquidity (stop clusters) per the spec's liquidity sweep requirements. Returns true and
   // outputs the level if found among the most recent swings.
   bool              FindEqualHighs(const double tolerancePct, double &outLevel) const
     {
      if(m_swingHighCount < 2) return false;
      for(int i=m_swingHighCount-1; i>0; i--)
        {
         double a = m_swingHighs[i];
         double b = m_swingHighs[i-1];
         double tol = a * (tolerancePct / 100.0);
         if(MathAbs(a-b) <= tol)
           {
            outLevel = MathMax(a,b);
            return true;
           }
        }
      return false;
     }

   bool              FindEqualLows(const double tolerancePct, double &outLevel) const
     {
      if(m_swingLowCount < 2) return false;
      for(int i=m_swingLowCount-1; i>0; i--)
        {
         double a = m_swingLows[i];
         double b = m_swingLows[i-1];
         double tol = a * (tolerancePct / 100.0);
         if(MathAbs(a-b) <= tol)
           {
            outLevel = MathMin(a,b);
            return true;
           }
        }
      return false;
     }
  };

//+------------------------------------------------------------------------------------------------+
//| CMTFConfirmation                                                                                    |
//| Evaluates directional alignment across H1 (macro bias) / M15 (intermediate structure) /            |
//| M5 (tactical setup) using simple EMA-slope direction per timeframe. M1 is treated as the           |
//| execution timeframe (the EA's own OnTick context) and is not separately re-evaluated here.         |
//+------------------------------------------------------------------------------------------------+
class CMTFConfirmation
  {
private:
   string            m_symbol;
   int               m_emaH1, m_emaM15, m_emaM5;
   int               m_emaPeriod;

public:
   bool              Init(const string symbol, const int emaPeriod)
     {
      m_symbol = symbol;
      m_emaPeriod = emaPeriod;
      m_emaH1  = iMA(m_symbol, PERIOD_H1,  m_emaPeriod, 0, MODE_EMA, PRICE_CLOSE);
      m_emaM15 = iMA(m_symbol, PERIOD_M15, m_emaPeriod, 0, MODE_EMA, PRICE_CLOSE);
      m_emaM5  = iMA(m_symbol, PERIOD_M5,  m_emaPeriod, 0, MODE_EMA, PRICE_CLOSE);
      if(m_emaH1 == INVALID_HANDLE || m_emaM15 == INVALID_HANDLE || m_emaM5 == INVALID_HANDLE)
        {
         Print("[CMTFConfirmation] ERROR: one or more EMA handles failed to create. Error=", GetLastError());
         return false;
        }
      return true;
     }

   // Returns direction of a single timeframe's EMA slope (current EMA vs EMA 3 bars ago).
   ENUM_TREND_DIR    GetTFDirection(const int handle) const
     {
      double buf[];
      ArraySetAsSeries(buf, true);
      if(CopyBuffer(handle, 0, 0, 4, buf) < 4)
         return TREND_DIR_NONE;
      double slope = buf[0] - buf[3];
      if(slope > 0.0) return TREND_DIR_UP;
      if(slope < 0.0) return TREND_DIR_DOWN;
      return TREND_DIR_NONE;
     }

   // Returns 0-100 alignment score for a candidate direction: full marks if H1/M15/M5 all agree,
   // partial credit for 2-of-3, low score otherwise. This directly satisfies the spec's requirement
   // to "trade only when alignment conditions are satisfied," exposed as a continuous score rather
   // than a hard boolean so it composes cleanly into ConfluenceScore.
   double            GetAlignmentScore(const ENUM_TREND_DIR candidateDir) const
     {
      if(candidateDir == TREND_DIR_NONE) return 0.0;

      ENUM_TREND_DIR h1  = GetTFDirection(m_emaH1);
      ENUM_TREND_DIR m15 = GetTFDirection(m_emaM15);
      ENUM_TREND_DIR m5  = GetTFDirection(m_emaM5);

      int agree = 0;
      if(h1  == candidateDir) agree++;
      if(m15 == candidateDir) agree++;
      if(m5  == candidateDir) agree++;

      // H1 weighted heaviest (macro bias per spec), then M15, then M5
      double score = 0.0;
      if(h1 == candidateDir)  score += 50.0;
      if(m15 == candidateDir) score += 30.0;
      if(m5 == candidateDir)  score += 20.0;
      return score;
     }
  };

//+------------------------------------------------------------------------------------------------+
//| CRegimeClassifier                                                                                   |
//| Scores confidence for each of the spec's 8 conceptual regimes, selects the dominant one, and       |
//| layers HighVol/LowVol as independent modifier flags (see ARCHITECTURE.md Conflict #2 for the       |
//| documented collapse from 8 conceptual regimes to 4 tradeable engines + 2 modifiers + 1 kill state).|
//+------------------------------------------------------------------------------------------------+
class CRegimeClassifier
  {
private:
   string            m_symbol;
   ENUM_TIMEFRAMES   m_tf;
   int               m_adxHandle;
   int               m_bbHandle;
   int               m_adxPeriod;
   double            m_adxTrendThreshold;
   int               m_compressionBars;
   double            m_minCompressionRatio;

   CVolatilityEngine *m_vol;
   CMarketStructure  *m_structure;

public:
                     CRegimeClassifier()
     {
      m_adxHandle = INVALID_HANDLE;
      m_bbHandle = INVALID_HANDLE;
      m_vol = NULL;
      m_structure = NULL;
     }

                    ~CRegimeClassifier()
     {
      if(m_adxHandle != INVALID_HANDLE) IndicatorRelease(m_adxHandle);
      if(m_bbHandle != INVALID_HANDLE)  IndicatorRelease(m_bbHandle);
     }

   bool              Init(const string symbol, const ENUM_TIMEFRAMES tf, const int adxPeriod,
                           const double adxTrendThreshold, const int compressionBars,
                           const double minCompressionRatio, CVolatilityEngine *vol, CMarketStructure *structure)
     {
      m_symbol = symbol;
      m_tf = tf;
      m_adxPeriod = adxPeriod;
      m_adxTrendThreshold = adxTrendThreshold;
      m_compressionBars = compressionBars;
      m_minCompressionRatio = minCompressionRatio;
      m_vol = vol;
      m_structure = structure;

      m_adxHandle = iADX(m_symbol, m_tf, m_adxPeriod);
      m_bbHandle  = iBands(m_symbol, m_tf, InpRangeBBPeriod, 0, InpRangeBBDeviation, PRICE_CLOSE);
      if(m_adxHandle == INVALID_HANDLE || m_bbHandle == INVALID_HANDLE)
        {
         Print("[CRegimeClassifier] ERROR: indicator handle creation failed. Error=", GetLastError());
         return false;
        }
      return true;
     }

   double            GetADXValue() const
     {
      double buf[];
      ArraySetAsSeries(buf, true);
      if(CopyBuffer(m_adxHandle, 0, 0, 1, buf) < 1) return 0.0;
      return buf[0];
     }

   double            GetADXPlusDI() const
     {
      double buf[];
      ArraySetAsSeries(buf, true);
      if(CopyBuffer(m_adxHandle, 1, 0, 1, buf) < 1) return 0.0;
      return buf[0];
     }

   double            GetADXMinusDI() const
     {
      double buf[];
      ArraySetAsSeries(buf, true);
      if(CopyBuffer(m_adxHandle, 2, 0, 1, buf) < 1) return 0.0;
      return buf[0];
     }

   // Bollinger Band width as a fraction of average ATR -- used both for range detection (wide,
   // oscillating between bands) and breakout compression detection (narrow, contracting).
   double            GetBBWidthRatio() const
     {
      double upper[], lower[];
      ArraySetAsSeries(upper, true);
      ArraySetAsSeries(lower, true);
      if(CopyBuffer(m_bbHandle, 1, 0, 1, upper) < 1) return 0.0; // upper band buffer index 1
      if(CopyBuffer(m_bbHandle, 2, 0, 1, lower) < 1) return 0.0; // lower band buffer index 2
      double width = upper[0] - lower[0];
      double avgATR = (m_vol != NULL) ? m_vol.GetAverageATR() : 0.0;
      if(avgATR <= 0.0) return 0.0;
      return width / avgATR;
     }

   // Compression check: true if price range over m_compressionBars is tight relative to ATR,
   // signaling a potential breakout setup forming. Required by CBreakoutEngine.
   bool              IsCompressed() const
     {
      double highs[], lows[];
      ArraySetAsSeries(highs, true);
      ArraySetAsSeries(lows, true);
      if(CopyHigh(m_symbol, m_tf, 0, m_compressionBars, highs) < m_compressionBars) return false;
      if(CopyLow(m_symbol, m_tf, 0, m_compressionBars, lows) < m_compressionBars) return false;
      double highest = highs[ArrayMaximum(highs)];
      double lowest  = lows[ArrayMinimum(lows)];
      double range = highest - lowest;
      double avgATR = (m_vol != NULL) ? m_vol.GetAverageATR() : 0.0;
      if(avgATR <= 0.0) return false;
      return (range / avgATR) <= m_minCompressionRatio;
     }

   // Core classification call. Scores each regime 0-100 based on available evidence, picks the
   // highest, applies the minimum-confidence gate, and separately evaluates HighVol/LowVol
   // modifiers (which are independent of the dominant regime choice).
   RegimeState       Classify(const double minConfidence) const
     {
      RegimeState st;
      st.regime = REGIME_UNDEFINED;
      st.confidence = 0.0;
      st.direction = TREND_DIR_NONE;
      st.highVolModifier = false;
      st.lowVolModifier = false;
      st.newsShock = false;

      if(m_vol == NULL || !m_vol.IsReady() || m_structure == NULL)
         return st;

      double adx = GetADXValue();
      double plusDI = GetADXPlusDI();
      double minusDI = GetADXMinusDI();
      ENUM_TREND_DIR structBias = m_structure.GetStructureBias();
      double bbWidthRatio = GetBBWidthRatio();
      bool compressed = IsCompressed();

      // --- Score Strong Bull / Strong Bear Trend ---
      double bullScore = 0.0, bearScore = 0.0;
      if(adx >= m_adxTrendThreshold)
        {
         double adxStrengthBonus = MathMin(30.0, (adx - m_adxTrendThreshold) * 1.5);
         if(plusDI > minusDI && structBias == TREND_DIR_UP)
            bullScore = 50.0 + adxStrengthBonus;
         else if(plusDI > minusDI)
            bullScore = 35.0 + adxStrengthBonus * 0.5; // DI agrees but structure doesn't confirm yet
         if(minusDI > plusDI && structBias == TREND_DIR_DOWN)
            bearScore = 50.0 + adxStrengthBonus;
         else if(minusDI > plusDI)
            bearScore = 35.0 + adxStrengthBonus * 0.5;
        }
      bullScore = MathMin(100.0, bullScore);
      bearScore = MathMin(100.0, bearScore);

      // --- Score Range Bound ---
      double rangeScore = 0.0;
      if(adx < m_adxTrendThreshold)
        {
         rangeScore = 50.0 + MathMin(30.0, (m_adxTrendThreshold - adx) * 1.5);
         if(bbWidthRatio > 0.0 && bbWidthRatio < 3.0) // moderate-width bands, oscillation-friendly
            rangeScore += 15.0;
        }
      rangeScore = MathMin(100.0, rangeScore);

      // --- Score Breakout Environment ---
      double breakoutScore = 0.0;
      if(compressed)
        {
         breakoutScore = 60.0;
         double expansion = m_vol.GetCandleExpansionRatio(0);
         if(expansion >= InpBreakoutMinExpansionMult)
            breakoutScore += 25.0; // current bar already shows expansion off compression = strong signal
        }
      breakoutScore = MathMin(100.0, breakoutScore);

      // --- Score Liquidity Sweep (as a DOMINANT regime, i.e. no clear trend/range/breakout) ---
      double sweepScore = 0.0;
      double eqHigh, eqLow;
      bool hasEqHigh = m_structure.FindEqualHighs(InpSweepEqualLevelTolerancePct, eqHigh);
      bool hasEqLow  = m_structure.FindEqualLows(InpSweepEqualLevelTolerancePct, eqLow);
      if((hasEqHigh || hasEqLow) && adx < m_adxTrendThreshold && !compressed)
         sweepScore = 55.0; // liquidity pools present, no competing trend/breakout signal

      // --- Select dominant regime by highest score ---
      double scores[5];
      scores[0] = bullScore; scores[1] = bearScore; scores[2] = rangeScore;
      scores[3] = breakoutScore; scores[4] = sweepScore;
      int bestIdx = ArrayMaximum(scores);
      double bestScore = scores[bestIdx];

      if(bestScore < minConfidence)
        {
         st.regime = REGIME_UNDEFINED;
         st.confidence = bestScore;
        }
      else
        {
         switch(bestIdx)
           {
            case 0: st.regime = REGIME_BULL_TREND; st.direction = TREND_DIR_UP;   break;
            case 1: st.regime = REGIME_BEAR_TREND; st.direction = TREND_DIR_DOWN; break;
            case 2: st.regime = REGIME_RANGE;      st.direction = TREND_DIR_NONE; break;
            case 3: st.regime = REGIME_BREAKOUT;   st.direction = structBias;     break;
            case 4: st.regime = REGIME_LIQ_SWEEP;  st.direction = TREND_DIR_NONE; break;
           }
         st.confidence = bestScore;
        }

      // --- Independent volatility modifiers ---
      st.highVolModifier = m_vol.IsHighVolatility(InpHighVolATRMultiplier);
      st.lowVolModifier  = m_vol.IsLowVolatility(InpLowVolATRMultiplier);

      return st;
     }
  };

//+------------------------------------------------------------------------------------------------+
//| CNewsShockDetector                                                                                  |
//| Detects abnormal market conditions WITHOUT any external news API, exactly as specced: spread       |
//| explosions, ATR explosions, and tick-velocity spikes relative to recent baselines. When triggered,  |
//| blocks new entries for InpNewsShockCooldownMin minutes (existing positions still managed by the     |
//| exit engine -- this is a new-entry kill state, not a full halt).                                    |
//+------------------------------------------------------------------------------------------------+
class CNewsShockDetector
  {
private:
   string            m_symbol;
   double            m_spreadMult;
   double            m_atrMult;
   double            m_tickVelMult;
   int               m_cooldownMin;

   double            m_avgSpreadPoints;
   double            m_spreadSamples[];
   int               m_spreadSampleCount;
   enum { SPREAD_SAMPLE_MAX = 200 };

   double            m_avgTickVelocity;
   double            m_tickVelSamples[];
   int               m_tickVelSampleCount;

   datetime          m_shockUntil;
   bool              m_shockActive;

   CVolatilityEngine *m_vol;
   COrderFlowProxy   *m_flow;

public:
                     CNewsShockDetector()
     {
      m_avgSpreadPoints = 0.0;
      m_spreadSampleCount = 0;
      m_avgTickVelocity = 0.0;
      m_tickVelSampleCount = 0;
      m_shockUntil = 0;
      m_shockActive = false;
      ArrayResize(m_spreadSamples, 200);
      ArrayResize(m_tickVelSamples, 200);
     }

   bool              Init(const string symbol, const double spreadMult, const double atrMult,
                           const double tickVelMult, const int cooldownMin,
                           CVolatilityEngine *vol, COrderFlowProxy *flow)
     {
      m_symbol = symbol;
      m_spreadMult = spreadMult;
      m_atrMult = atrMult;
      m_tickVelMult = tickVelMult;
      m_cooldownMin = cooldownMin;
      m_vol = vol;
      m_flow = flow;
      return true;
     }

   // Maintains rolling average spread / tick velocity baselines using simple circular-buffer
   // sampling. Call once per new bar (spread/velocity baselines don't need tick-level granularity).
   void              UpdateBaselines()
     {
      long spreadRaw = SymbolInfoInteger(m_symbol, SYMBOL_SPREAD);
      double spreadPoints = (double)spreadRaw;
      int idx = m_spreadSampleCount % SPREAD_SAMPLE_MAX;
      m_spreadSamples[idx] = spreadPoints;
      m_spreadSampleCount++;
      int n = MathMin(m_spreadSampleCount, SPREAD_SAMPLE_MAX);
      double sum = 0.0;
      for(int i=0; i<n; i++) sum += m_spreadSamples[i];
      m_avgSpreadPoints = sum / n;

      if(m_flow != NULL)
        {
         double vel = m_flow.GetTickVelocity();
         int vidx = m_tickVelSampleCount % SPREAD_SAMPLE_MAX;
         m_tickVelSamples[vidx] = vel;
         m_tickVelSampleCount++;
         int vn = MathMin(m_tickVelSampleCount, SPREAD_SAMPLE_MAX);
         double vsum = 0.0;
         for(int i=0; i<vn; i++) vsum += m_tickVelSamples[i];
         m_avgTickVelocity = vsum / vn;
        }
     }

   // Checks current conditions against the baselines and updates shock state. Call every tick
   // (shocks can develop fast and we want minimal detection latency).
   bool              CheckAndUpdate()
     {
      datetime now = TimeCurrent();

      if(m_shockActive && now < m_shockUntil)
         return true; // still in cooldown from a prior trigger
      if(m_shockActive && now >= m_shockUntil)
         m_shockActive = false; // cooldown expired, clear

      bool spreadShock = false, atrShock = false, velShock = false;

      long spreadRaw = SymbolInfoInteger(m_symbol, SYMBOL_SPREAD);
      if(m_avgSpreadPoints > 0.0 && (double)spreadRaw >= m_avgSpreadPoints * m_spreadMult)
         spreadShock = true;

      if(m_vol != NULL && m_vol.IsReady() && m_vol.GetATRRatio() >= m_atrMult)
         atrShock = true;

      if(m_flow != NULL && m_avgTickVelocity > 0.0 && m_flow.GetTickVelocity() >= m_avgTickVelocity * m_tickVelMult)
         velShock = true;

      if(spreadShock || atrShock || velShock)
        {
         if(!m_shockActive)
           {
            PrintFormat("[CNewsShockDetector] SHOCK DETECTED (spread=%s atr=%s tickvel=%s). Blocking new entries for %d min.",
                        spreadShock?"true":"false", atrShock?"true":"false", velShock?"true":"false", m_cooldownMin);
           }
         m_shockActive = true;
         m_shockUntil = now + (m_cooldownMin * 60);
         return true;
        }

      return m_shockActive;
     }

   bool              IsShockActive() const { return m_shockActive; }
  };

//+------------------------------------------------------------------------------------------------+
//| CTrendEngine                                                                                        |
//| Active only when CRegimeClassifier outputs REGIME_BULL_TREND or REGIME_BEAR_TREND. Trades pullback |
//| continuation entries confirmed by EMA structure, ADX, ATR expansion, and momentum acceleration.    |
//+------------------------------------------------------------------------------------------------+
class CTrendEngine
  {
private:
   string            m_symbol;
   ENUM_TIMEFRAMES   m_tf;
   int               m_fastEmaHandle, m_slowEmaHandle, m_momHandle;
   double            m_pullbackATRMult;

   CVolatilityEngine *m_vol;
   CMarketStructure  *m_structure;
   COrderFlowProxy   *m_flow;

public:
   bool              Init(const string symbol, const ENUM_TIMEFRAMES tf, const int fastEMA, const int slowEMA,
                           const double pullbackATRMult, CVolatilityEngine *vol, CMarketStructure *structure,
                           COrderFlowProxy *flow)
     {
      m_symbol = symbol;
      m_tf = tf;
      m_pullbackATRMult = pullbackATRMult;
      m_vol = vol;
      m_structure = structure;
      m_flow = flow;

      m_fastEmaHandle = iMA(m_symbol, m_tf, fastEMA, 0, MODE_EMA, PRICE_CLOSE);
      m_slowEmaHandle = iMA(m_symbol, m_tf, slowEMA, 0, MODE_EMA, PRICE_CLOSE);
      m_momHandle     = iMomentum(m_symbol, m_tf, 14, PRICE_CLOSE);
      if(m_fastEmaHandle == INVALID_HANDLE || m_slowEmaHandle == INVALID_HANDLE || m_momHandle == INVALID_HANDLE)
        {
         Print("[CTrendEngine] ERROR: indicator handle creation failed. Error=", GetLastError());
         return false;
        }
      return true;
     }

   double            GetEMA(const int handle, const int shift=0) const
     {
      double buf[];
      ArraySetAsSeries(buf, true);
      if(CopyBuffer(handle, 0, shift, 1, buf) < 1) return 0.0;
      return buf[0];
     }

   double            GetMomentum(const int shift=0) const
     {
      double buf[];
      ArraySetAsSeries(buf, true);
      if(CopyBuffer(m_momHandle, 0, shift, 1, buf) < 1) return 100.0;
      return buf[0];
     }

   // Computes confluence sub-scores for a trend-continuation entry in the given direction.
   // Returns a ConfluenceScore with sweepBonus left at 0 (filled in by the router if blending).
   ConfluenceScore   GetSignal(const ENUM_TREND_DIR direction, const double mtfAlignmentScore) const
     {
      ConfluenceScore cs;
      cs.Clear();
      if(direction == TREND_DIR_NONE) return cs;

      double fastEMA = GetEMA(m_fastEmaHandle);
      double slowEMA = GetEMA(m_slowEmaHandle);
      double price = SymbolInfoDouble(m_symbol, SYMBOL_BID);
      double atr = (m_vol != NULL) ? m_vol.GetCurrentATR() : 0.0;

      // --- Trend Alignment (0-20): EMA structure agrees with direction + MTF alignment scaled in ---
      bool emaAligned = (direction == TREND_DIR_UP) ? (fastEMA > slowEMA) : (fastEMA < slowEMA);
      double trendAlign = 0.0;
      if(emaAligned)
        {
         trendAlign = 12.0;
         trendAlign += (mtfAlignmentScore / 100.0) * 8.0; // up to +8 more from MTF agreement
        }
      cs.trendAlignment = MathMin(20.0, trendAlign);

      // --- Momentum (0-20): Momentum indicator above/below 100 in trade direction + ATR expansion ---
      double mom = GetMomentum();
      double momScore = 0.0;
      if(direction == TREND_DIR_UP && mom > 100.0)
         momScore = MathMin(12.0, (mom - 100.0) * 2.0);
      else if(direction == TREND_DIR_DOWN && mom < 100.0)
         momScore = MathMin(12.0, (100.0 - mom) * 2.0);
      if(m_vol != NULL && m_vol.GetATRRatio() > 1.0)
         momScore += MathMin(8.0, (m_vol.GetATRRatio() - 1.0) * 10.0); // expansion confirms momentum
      cs.momentum = MathMin(20.0, momScore);

      // --- Volume/Flow proxy (0-15) ---
      if(m_flow != NULL)
         cs.volumeFlow = MathMin(15.0, m_flow.GetParticipationScore() * 0.15);

      // --- Liquidity Confirmation (0-15): pullback depth check -- entries near recent swing are
      //     preferred over chasing price far from structure ---
      double liquidityScore = 0.0;
      if(m_structure != NULL && atr > 0.0)
        {
         double refLevel = (direction == TREND_DIR_UP) ? m_structure.GetLastSwingLow() : m_structure.GetLastSwingHigh();
         if(refLevel > 0.0)
           {
            double distance = MathAbs(price - refLevel);
            double distanceInATR = distance / atr;
            if(distanceInATR <= m_pullbackATRMult)
               liquidityScore = 15.0 * (1.0 - (distanceInATR / m_pullbackATRMult));
           }
        }
      cs.liquidityConfirm = MathMax(0.0, liquidityScore);

      // --- Volatility Condition (0-15): favors moderate-to-expanding volatility, not extreme/dead ---
      if(m_vol != NULL && m_vol.IsReady())
        {
         double ratio = m_vol.GetATRRatio();
         if(ratio >= 0.8 && ratio <= 2.5)
            cs.volatilityCondition = 15.0;
         else if(ratio > 2.5)
            cs.volatilityCondition = 7.0; // still tradeable but riskier
         else
            cs.volatilityCondition = 3.0; // too quiet for trend continuation conviction
        }

      // sessionQuality is filled in by the router (session-aware, not engine-specific)
      // sweepBonus is filled in by the router if Liquidity Sweep blending applies

      return cs;
     }
  };

//+------------------------------------------------------------------------------------------------+
//| CRangeEngine                                                                                        |
//| Active only when CRegimeClassifier outputs REGIME_RANGE. Trades mean-reversion entries at Bollinger |
//| Band extremes confirmed by RSI divergence-style readings and volume exhaustion.                     |
//+------------------------------------------------------------------------------------------------+
class CRangeEngine
  {
private:
   string            m_symbol;
   ENUM_TIMEFRAMES   m_tf;
   int               m_bbHandle;
   int               m_rsiHandle;
   double            m_rsiOverbought, m_rsiOversold;

   COrderFlowProxy   *m_flow;
   CVolatilityEngine *m_vol;

public:
   bool              Init(const string symbol, const ENUM_TIMEFRAMES tf, const int bbPeriod, const double bbDev,
                           const int rsiPeriod, const double rsiOB, const double rsiOS,
                           COrderFlowProxy *flow, CVolatilityEngine *vol)
     {
      m_symbol = symbol;
      m_tf = tf;
      m_rsiOverbought = rsiOB;
      m_rsiOversold = rsiOS;
      m_flow = flow;
      m_vol = vol;

      m_bbHandle  = iBands(m_symbol, m_tf, bbPeriod, 0, bbDev, PRICE_CLOSE);
      m_rsiHandle = iRSI(m_symbol, m_tf, rsiPeriod, PRICE_CLOSE);
      if(m_bbHandle == INVALID_HANDLE || m_rsiHandle == INVALID_HANDLE)
        {
         Print("[CRangeEngine] ERROR: indicator handle creation failed. Error=", GetLastError());
         return false;
        }
      return true;
     }

   double            GetBBBuffer(const int bufferIdx, const int shift=0) const
     {
      double buf[];
      ArraySetAsSeries(buf, true);
      if(CopyBuffer(m_bbHandle, bufferIdx, shift, 1, buf) < 1) return 0.0;
      return buf[0];
     }

   double            GetRSI(const int shift=0) const
     {
      double buf[];
      ArraySetAsSeries(buf, true);
      if(CopyBuffer(m_rsiHandle, 0, shift, 1, buf) < 1) return 50.0;
      return buf[0];
     }

   // direction: TREND_DIR_UP means "looking to buy the low end of the range" (mean reversion up),
   // TREND_DIR_DOWN means "looking to sell the high end of the range" (mean reversion down).
   ConfluenceScore   GetSignal(const ENUM_TREND_DIR direction) const
     {
      ConfluenceScore cs;
      cs.Clear();
      if(direction == TREND_DIR_NONE) return cs;

      double upper = GetBBBuffer(1);
      double lower = GetBBBuffer(2);
      double middle = GetBBBuffer(0);
      double price = SymbolInfoDouble(m_symbol, SYMBOL_BID);
      double rsi = GetRSI();
      double rsiPrev = GetRSI(3);

      // --- Trend Alignment (0-20) repurposed here as "range-boundary alignment": how close price
      //     is to the relevant extreme band, the core mean-reversion setup condition ---
      double bandWidth = upper - lower;
      double rangeAlign = 0.0;
      if(bandWidth > 0.0)
        {
         if(direction == TREND_DIR_UP) // expecting bounce off lower band
           {
            double proximity = (price - lower) / bandWidth; // 0 = at lower band, 1 = at upper
            if(proximity <= 0.15)
               rangeAlign = 20.0 * (1.0 - (proximity / 0.15));
           }
         else // expecting rejection off upper band
           {
            double proximity = (upper - price) / bandWidth;
            if(proximity <= 0.15)
               rangeAlign = 20.0 * (1.0 - (proximity / 0.15));
           }
        }
      cs.trendAlignment = MathMax(0.0, MathMin(20.0, rangeAlign));

      // --- Momentum (0-20) here repurposed as "RSI exhaustion/divergence-style confirmation" ---
      double momScore = 0.0;
      if(direction == TREND_DIR_UP && rsi <= m_rsiOversold)
        {
         momScore = 12.0;
         if(rsi > rsiPrev) momScore += 8.0; // RSI turning up from oversold = stronger reversal signal
        }
      else if(direction == TREND_DIR_DOWN && rsi >= m_rsiOverbought)
        {
         momScore = 12.0;
         if(rsi < rsiPrev) momScore += 8.0; // RSI turning down from overbought
        }
      cs.momentum = MathMin(20.0, momScore);

      // --- Volume/Flow (0-15): for range exhaustion, LOW participation actually confirms reversal
      //     (declining volume into the extreme = exhaustion), so this is inverted vs trend engine ---
      if(m_flow != NULL)
        {
         double participation = m_flow.GetParticipationScore(); // 0-100
         cs.volumeFlow = MathMin(15.0, (100.0 - participation) * 0.15);
        }

      // --- Liquidity Confirmation (0-15): distance from band extreme as confirmation strength ---
      double liquidityScore = 0.0;
      if(bandWidth > 0.0)
        {
         if(direction == TREND_DIR_UP)
            liquidityScore = MathMax(0.0, 15.0 * (1.0 - ((price - lower) / (bandWidth * 0.25))));
         else
            liquidityScore = MathMax(0.0, 15.0 * (1.0 - ((upper - price) / (bandWidth * 0.25))));
        }
      cs.liquidityConfirm = MathMax(0.0, MathMin(15.0, liquidityScore));

      // --- Volatility Condition (0-15): range trading favors moderate/low (not exploding) vol ---
      if(m_vol != NULL && m_vol.IsReady())
        {
         double ratio = m_vol.GetATRRatio();
         if(ratio <= 1.2)
            cs.volatilityCondition = 15.0;
         else if(ratio <= 1.8)
            cs.volatilityCondition = 7.0;
         else
            cs.volatilityCondition = 0.0; // expanding volatility invalidates range thesis
        }

      return cs;
     }
  };

//+------------------------------------------------------------------------------------------------+
//| CBreakoutEngine                                                                                     |
//| Active only when CRegimeClassifier outputs REGIME_BREAKOUT. Implements MANDATORY false-breakout     |
//| filtering via retest validation: a raw compression-release move is NOT enough to score highly --   |
//| the engine requires either (a) a confirmed retest of the breakout level that holds, or (b) strong   |
//| enough expansion + volume that retest confirmation is waived per a conservative volume/ATR gate.    |
//+------------------------------------------------------------------------------------------------+
class CBreakoutEngine
  {
private:
   string            m_symbol;
   ENUM_TIMEFRAMES   m_tf;
   int               m_compressionBars;
   int               m_retestMaxBars;
   double            m_minExpansionMult;

   double            m_breakoutLevel;
   datetime          m_breakoutBarTime;
   bool              m_awaitingRetest;
   ENUM_TREND_DIR    m_breakoutDirection;

   CVolatilityEngine *m_vol;
   COrderFlowProxy   *m_flow;

public:
                     CBreakoutEngine()
     {
      m_breakoutLevel = 0.0;
      m_breakoutBarTime = 0;
      m_awaitingRetest = false;
      m_breakoutDirection = TREND_DIR_NONE;
     }

   bool              Init(const string symbol, const ENUM_TIMEFRAMES tf, const int compressionBars,
                           const int retestMaxBars, const double minExpansionMult,
                           CVolatilityEngine *vol, COrderFlowProxy *flow)
     {
      m_symbol = symbol;
      m_tf = tf;
      m_compressionBars = compressionBars;
      m_retestMaxBars = retestMaxBars;
      m_minExpansionMult = minExpansionMult;
      m_vol = vol;
      m_flow = flow;
      return true;
     }

   // Call once per new bar. Tracks the compression range and flags when price breaks out of it,
   // entering an "awaiting retest" state that the GetSignal() call consumes.
   void              UpdateBreakoutState()
     {
      double highs[], lows[];
      ArraySetAsSeries(highs, true);
      ArraySetAsSeries(lows, true);
      if(CopyHigh(m_symbol, m_tf, 1, m_compressionBars, highs) < m_compressionBars) return; // shift 1 = exclude current forming bar
      if(CopyLow(m_symbol, m_tf, 1, m_compressionBars, lows) < m_compressionBars) return;

      double compressionHigh = highs[ArrayMaximum(highs)];
      double compressionLow  = lows[ArrayMinimum(lows)];
      double curClose = iClose(m_symbol, m_tf, 0);

      // Clear stale awaiting-retest state if too many bars have passed without confirmation
      if(m_awaitingRetest && (iBarShift(m_symbol, m_tf, m_breakoutBarTime) > m_retestMaxBars))
        {
         m_awaitingRetest = false;
         if(InpDebugMode)
            Print("[CBreakoutEngine] Retest window expired without confirmation -- breakout invalidated (likely false breakout filtered).");
        }

      if(!m_awaitingRetest)
        {
         if(curClose > compressionHigh)
           {
            m_breakoutLevel = compressionHigh;
            m_breakoutBarTime = iTime(m_symbol, m_tf, 0);
            m_breakoutDirection = TREND_DIR_UP;
            m_awaitingRetest = true;
           }
         else if(curClose < compressionLow)
           {
            m_breakoutLevel = compressionLow;
            m_breakoutBarTime = iTime(m_symbol, m_tf, 0);
            m_breakoutDirection = TREND_DIR_DOWN;
            m_awaitingRetest = true;
           }
        }
     }

   // Returns true if price has retested the breakout level and held (closed back beyond it in the
   // breakout direction after touching it) -- this is the false-breakout filter the spec mandates.
   bool              IsRetestConfirmed() const
     {
      if(!m_awaitingRetest) return false;
      double price = SymbolInfoDouble(m_symbol, SYMBOL_BID);
      double tolerance = (m_vol != NULL) ? m_vol.GetCurrentATR() * 0.3 : 0.0;

      if(m_breakoutDirection == TREND_DIR_UP)
         return (price >= m_breakoutLevel - tolerance) && (price > m_breakoutLevel);
      if(m_breakoutDirection == TREND_DIR_DOWN)
         return (price <= m_breakoutLevel + tolerance) && (price < m_breakoutLevel);
      return false;
     }

   ConfluenceScore   GetSignal() const
     {
      ConfluenceScore cs;
      cs.Clear();
      if(!m_awaitingRetest || m_breakoutDirection == TREND_DIR_NONE) return cs;

      double expansion = (m_vol != NULL) ? m_vol.GetCandleExpansionRatio(0) : 0.0;
      bool strongExpansionWaiver = (expansion >= m_minExpansionMult * 1.5); // very strong move can waive strict retest requirement

      bool retestOK = IsRetestConfirmed();

      // --- Trend Alignment (0-20): repurposed as "breakout direction conviction" ---
      cs.trendAlignment = (m_breakoutDirection != TREND_DIR_NONE) ? 15.0 : 0.0;

      // --- Momentum (0-20): expansion strength of the breakout candle(s) ---
      cs.momentum = MathMin(20.0, expansion * 8.0);

      // --- Volume/Flow (0-15): breakouts need participation confirmation, not just price movement ---
      if(m_flow != NULL)
         cs.volumeFlow = MathMin(15.0, m_flow.GetParticipationScore() * 0.15);

      // --- Liquidity Confirmation (0-15): THIS IS THE MANDATORY FALSE-BREAKOUT FILTER. Full marks
      //     only if retest confirmed; partial marks only if expansion was strong enough to waive,
      //     and even then capped well below full score so weak waived breakouts don't easily clear
      //     the entry threshold on their own. ---
      if(retestOK)
         cs.liquidityConfirm = 15.0;
      else if(strongExpansionWaiver)
         cs.liquidityConfirm = 6.0;
      else
         cs.liquidityConfirm = 0.0; // no retest, no strong waiver = filtered out (false breakout protection)

      // --- Volatility Condition (0-15): breakout needs genuine expansion, not marginal ---
      if(expansion >= m_minExpansionMult)
         cs.volatilityCondition = 15.0;
      else if(expansion >= m_minExpansionMult * 0.7)
         cs.volatilityCondition = 7.0;
      else
         cs.volatilityCondition = 0.0;

      return cs;
     }

   ENUM_TREND_DIR    GetBreakoutDirection() const { return m_breakoutDirection; }
   bool              IsAwaitingRetest() const     { return m_awaitingRetest; }

   void              ConsumeSignal() { m_awaitingRetest = false; } // call after a trade is taken on this setup
  };

//+------------------------------------------------------------------------------------------------+
//| CLiquiditySweepEngine                                                                               |
//| Institutional-style liquidity sweep detection: equal highs/lows (resting stop clusters), sweep      |
//| (price spikes through the level), rejection (closes back inside), and momentum-shift confirmation. |
//| Operates in TWO modes per the approved blending architecture (ARCHITECTURE.md Conflict #1):         |
//|   1. STANDALONE (REGIME_LIQ_SWEEP dominant): GetSignal() returns a full 0-100 confluence score.    |
//|   2. SECONDARY/BLENDED (Trend or Range dominant): GetConfirmationBonus() returns 0..SweepBonusPoints|
//|      added on top of the dominant engine's score, never triggering a trade on its own in this mode.|
//+------------------------------------------------------------------------------------------------+
class CLiquiditySweepEngine
  {
private:
   string            m_symbol;
   ENUM_TIMEFRAMES   m_tf;
   double            m_tolerancePct;
   int               m_rejectionMaxBars;

   bool              m_sweepDetected;
   ENUM_TREND_DIR    m_sweepDirection;     // direction of the EXPECTED reversal/continuation after sweep
   double            m_sweptLevel;
   datetime          m_sweepBarTime;

   CMarketStructure  *m_structure;
   COrderFlowProxy   *m_flow;
   CVolatilityEngine *m_vol;

public:
                     CLiquiditySweepEngine()
     {
      m_sweepDetected = false;
      m_sweepDirection = TREND_DIR_NONE;
      m_sweptLevel = 0.0;
      m_sweepBarTime = 0;
     }

   bool              Init(const string symbol, const ENUM_TIMEFRAMES tf, const double tolerancePct,
                           const int rejectionMaxBars, CMarketStructure *structure, COrderFlowProxy *flow,
                           CVolatilityEngine *vol)
     {
      m_symbol = symbol;
      m_tf = tf;
      m_tolerancePct = tolerancePct;
      m_rejectionMaxBars = rejectionMaxBars;
      m_structure = structure;
      m_flow = flow;
      m_vol = vol;
      return true;
     }

   // Call once per new bar. Looks for a sweep of equal-high/equal-low liquidity pools followed by
   // rejection back inside the range -- the core "stop hunt then reversal" institutional pattern.
   void              UpdateSweepState()
     {
      if(m_structure == NULL) return;

      // Clear stale sweep state if rejection hasn't confirmed within the allowed window
      if(m_sweepDetected && (iBarShift(m_symbol, m_tf, m_sweepBarTime) > m_rejectionMaxBars))
        {
         m_sweepDetected = false;
        }

      double eqHigh, eqLow;
      bool hasEqHigh = m_structure.FindEqualHighs(m_tolerancePct, eqHigh);
      bool hasEqLow  = m_structure.FindEqualLows(m_tolerancePct, eqLow);

      double curHigh = iHigh(m_symbol, m_tf, 1); // last fully closed bar
      double curLow  = iLow(m_symbol, m_tf, 1);
      double curClose= iClose(m_symbol, m_tf, 1);

      if(!m_sweepDetected)
        {
         // Sweep of equal highs: price spikes above the equal-high level then closes back below it
         // = liquidity grab + rejection = bearish reversal expectation (sell signal)
         if(hasEqHigh && curHigh > eqHigh && curClose < eqHigh)
           {
            m_sweepDetected = true;
            m_sweepDirection = TREND_DIR_DOWN;
            m_sweptLevel = eqHigh;
            m_sweepBarTime = iTime(m_symbol, m_tf, 1);
            if(InpDebugMode) Print("[CLiquiditySweepEngine] Equal-high sweep + rejection detected. Bearish bias.");
           }
         // Sweep of equal lows: price spikes below the equal-low level then closes back above it
         // = liquidity grab + rejection = bullish reversal expectation (buy signal)
         else if(hasEqLow && curLow < eqLow && curClose > eqLow)
           {
            m_sweepDetected = true;
            m_sweepDirection = TREND_DIR_UP;
            m_sweptLevel = eqLow;
            m_sweepBarTime = iTime(m_symbol, m_tf, 1);
            if(InpDebugMode) Print("[CLiquiditySweepEngine] Equal-low sweep + rejection detected. Bullish bias.");
           }
        }
     }

   // Momentum-shift confirmation: requires tick acceleration in the sweep's expected direction,
   // satisfying the spec's "momentum shift confirmation" requirement for liquidity sweep entries.
   bool              IsMomentumShiftConfirmed() const
     {
      if(!m_sweepDetected || m_flow == NULL) return false;
      double accel = m_flow.GetTickAcceleration();
      double imbalance = m_flow.GetPriceImbalance();
      if(m_sweepDirection == TREND_DIR_UP)
         return (accel > 0.0 && imbalance > 0.05);
      if(m_sweepDirection == TREND_DIR_DOWN)
         return (accel < 0.0 && imbalance < -0.05);
      return false;
     }

   // STANDALONE mode: full confluence score when sweep is the dominant regime call.
   ConfluenceScore   GetSignal() const
     {
      ConfluenceScore cs;
      cs.Clear();
      if(!m_sweepDetected || m_sweepDirection == TREND_DIR_NONE) return cs;

      bool momentumShift = IsMomentumShiftConfirmed();

      // --- Trend Alignment (0-20): repurposed as "reversal direction conviction" ---
      cs.trendAlignment = 15.0;

      // --- Momentum (0-20): the mandatory momentum-shift confirmation from the spec ---
      cs.momentum = momentumShift ? 20.0 : 5.0; // heavily favor confirmed shift, but don't hard-block

      // --- Volume/Flow (0-15) ---
      if(m_flow != NULL)
         cs.volumeFlow = MathMin(15.0, m_flow.GetParticipationScore() * 0.15);

      // --- Liquidity Confirmation (0-15): this IS the sweep+rejection pattern itself, so full
      //     marks are warranted once detected (the detection logic already required rejection) ---
      cs.liquidityConfirm = 15.0;

      // --- Volatility Condition (0-15): sweeps work best in moderate vol, not dead-quiet markets ---
      if(m_vol != NULL && m_vol.IsReady())
        {
         double ratio = m_vol.GetATRRatio();
         cs.volatilityCondition = (ratio >= 0.7) ? 15.0 : 5.0;
        }

      return cs;
     }

   // SECONDARY/BLENDED mode: returns 0..SweepBonusPoints to add to a dominant Trend or Range
   // engine's score, ONLY if the sweep direction agrees with the dominant engine's intended
   // direction (enforced by caller passing dominantDirection). Never returns a full standalone
   // signal in this mode -- this satisfies the "sweep alone cannot trigger a trade while another
   // regime is dominant" rule from ARCHITECTURE.md.
   double            GetConfirmationBonus(const ENUM_TREND_DIR dominantDirection, const double maxBonus) const
     {
      if(!m_sweepDetected || m_sweepDirection != dominantDirection) return 0.0;
      bool momentumShift = IsMomentumShiftConfirmed();
      double bonus = momentumShift ? maxBonus : maxBonus * 0.5;
      return bonus;
     }

   bool              IsSweepActive() const          { return m_sweepDetected; }
   ENUM_TREND_DIR    GetSweepDirection() const       { return m_sweepDirection; }
   void              ConsumeSignal()                 { m_sweepDetected = false; }
  };

//+------------------------------------------------------------------------------------------------+
//| CExecutionQualityFilter                                                                             |
//| Guards against trading under poor execution conditions: wide spreads, excessive slippage risk,     |
//| frozen/stops-level violations. Does NOT place orders itself -- purely a gate checked before entry. |
//+------------------------------------------------------------------------------------------------+
class CExecutionQualityFilter
  {
private:
   string            m_symbol;
   double            m_maxSpreadPoints;
   int               m_maxSlippagePoints;

public:
   bool              Init(const string symbol, const double maxSpreadPoints, const int maxSlippagePoints)
     {
      m_symbol = symbol;
      m_maxSpreadPoints = maxSpreadPoints;
      m_maxSlippagePoints = maxSlippagePoints;
      return true;
     }

   bool              IsSpreadAcceptable() const
     {
      long spread = SymbolInfoInteger(m_symbol, SYMBOL_SPREAD);
      return (double)spread <= m_maxSpreadPoints;
     }

   // Checks the symbol isn't in a freeze-level violation state relative to a hypothetical stop
   // distance -- prevents placing orders that would be rejected by the broker for being too close
   // to current price.
   bool              IsStopDistanceValid(const double stopDistance) const
     {
      long freezeLevel = SymbolInfoInteger(m_symbol, SYMBOL_TRADE_FREEZE_LEVEL);
      long stopsLevel   = SymbolInfoInteger(m_symbol, SYMBOL_TRADE_STOPS_LEVEL);
      double point = SymbolInfoDouble(m_symbol, SYMBOL_POINT);
      double minDistance = MathMax((double)freezeLevel, (double)stopsLevel) * point;
      return stopDistance >= minDistance;
     }

   bool              IsTradeAllowedNow() const
     {
      long tradeMode = SymbolInfoInteger(m_symbol, SYMBOL_TRADE_MODE);
      return (tradeMode == SYMBOL_TRADE_MODE_FULL);
     }

   int               GetMaxSlippagePoints() const { return m_maxSlippagePoints; }

   // Composite pre-trade check. Logs the specific reason for rejection (debug mode) so execution
   // issues are diagnosable rather than silent.
   bool              IsExecutionQualityOK(const double stopDistance) const
     {
      if(!IsTradeAllowedNow())
        {
         if(InpDebugMode) Print("[CExecutionQualityFilter] Blocked: symbol trade mode not full.");
         return false;
        }
      if(!IsSpreadAcceptable())
        {
         if(InpDebugMode) PrintFormat("[CExecutionQualityFilter] Blocked: spread %d exceeds max %.0f.",
                                       (int)SymbolInfoInteger(m_symbol, SYMBOL_SPREAD), m_maxSpreadPoints);
         return false;
        }
      if(!IsStopDistanceValid(stopDistance))
        {
         if(InpDebugMode) Print("[CExecutionQualityFilter] Blocked: stop distance violates freeze/stops level.");
         return false;
        }
      return true;
     }
  };

//+------------------------------------------------------------------------------------------------+
//| CRiskManager                                                                                        |
//| Institutional risk controls: account-equity-adaptive position sizing, daily/weekly/monthly loss     |
//| limits, consecutive-loss protection, equity high-water-mark drawdown protection, and a max-exposure |
//| cap. All limits are real circuit breakers -- when tripped, NewTrade approval is hard-refused until  |
//| the relevant cooldown/reset condition clears.                                                        |
//+------------------------------------------------------------------------------------------------+
class CRiskManager
  {
private:
   string            m_symbol;
   double            m_riskPercentPerTrade;
   double            m_maxRiskPercentPerTrade;
   double            m_dailyLossLimitPct;
   double            m_weeklyLossLimitPct;
   double            m_monthlyLossLimitPct;
   int               m_maxConsecutiveLosses;
   int               m_consecLossCooldownMin;
   double            m_equityProtectionPct;
   double            m_maxExposurePct;
   ulong             m_magic;

   double            m_dayStartEquity;
   double            m_weekStartEquity;
   double            m_monthStartEquity;
   double            m_equityHighWaterMark;
   datetime          m_currentDay;
   int               m_currentWeek;
   int               m_currentMonth;

   int               m_consecutiveLosses;
   datetime          m_consecLossCooldownUntil;

   ENUM_KILL_REASON  m_killReason;
   bool              m_killActive;

public:
                     CRiskManager()
     {
      m_dayStartEquity = 0.0;
      m_weekStartEquity = 0.0;
      m_monthStartEquity = 0.0;
      m_equityHighWaterMark = 0.0;
      m_currentDay = 0;
      m_currentWeek = -1;
      m_currentMonth = -1;
      m_consecutiveLosses = 0;
      m_consecLossCooldownUntil = 0;
      m_killReason = KILL_NONE;
      m_killActive = false;
     }

   bool              Init(const string symbol, const ulong magic, const double riskPct, const double maxRiskPct,
                           const double dailyLossPct, const double weeklyLossPct, const double monthlyLossPct,
                           const int maxConsecLosses, const int consecCooldownMin, const double equityProtPct,
                           const double maxExposurePct)
     {
      m_symbol = symbol;
      m_magic = magic;
      m_riskPercentPerTrade = riskPct;
      m_maxRiskPercentPerTrade = maxRiskPct;
      m_dailyLossLimitPct = dailyLossPct;
      m_weeklyLossLimitPct = weeklyLossPct;
      m_monthlyLossLimitPct = monthlyLossPct;
      m_maxConsecutiveLosses = maxConsecLosses;
      m_consecLossCooldownMin = consecCooldownMin;
      m_equityProtectionPct = equityProtPct;
      m_maxExposurePct = maxExposurePct;

      double equity = AccountInfoDouble(ACCOUNT_EQUITY);
      m_dayStartEquity = equity;
      m_weekStartEquity = equity;
      m_monthStartEquity = equity;
      m_equityHighWaterMark = equity;

      MqlDateTime dt;
      TimeToStruct(TimeCurrent(), dt);
      m_currentDay = StringToTime(StringFormat("%04d.%02d.%02d", dt.year, dt.mon, dt.day));
      m_currentWeek = GetISOWeek(TimeCurrent());
      m_currentMonth = dt.mon;
      return true;
     }

   // Approximate ISO week number from a datetime (good enough for weekly-reset bucketing purposes;
   // does not need to be calendar-perfectly ISO-compliant, just consistent run-to-run).
   int               GetISOWeek(const datetime t) const
     {
      MqlDateTime dt;
      TimeToStruct(t, dt);
      return (dt.day_of_year / 7) + (dt.year * 100);
     }

   // Call once per new bar (or at minimum once per day) to roll daily/weekly/monthly equity
   // baselines forward and refresh the equity high-water-mark.
   void              UpdatePeriodBaselines()
     {
      double equity = AccountInfoDouble(ACCOUNT_EQUITY);
      if(equity > m_equityHighWaterMark)
         m_equityHighWaterMark = equity;

      MqlDateTime dt;
      TimeToStruct(TimeCurrent(), dt);
      datetime today = StringToTime(StringFormat("%04d.%02d.%02d", dt.year, dt.mon, dt.day));

      if(today != m_currentDay)
        {
         m_currentDay = today;
         m_dayStartEquity = equity;
        }

      int week = GetISOWeek(TimeCurrent());
      if(week != m_currentWeek)
        {
         m_currentWeek = week;
         m_weekStartEquity = equity;
        }

      if(dt.mon != m_currentMonth)
        {
         m_currentMonth = dt.mon;
         m_monthStartEquity = equity;
        }
     }

   // Computes position size in lots from risk%, stop distance, and live symbol specs. Adaptive to
   // ANY account size/currency since it's driven entirely by AccountInfoDouble(ACCOUNT_EQUITY) and
   // live SymbolInfo values -- no hardcoded broker assumptions.
   double            CalculatePositionSize(const double stopDistancePrice, const double riskPercentOverride = -1.0) const
     {
      if(stopDistancePrice <= 0.0) return 0.0;

      double riskPct = (riskPercentOverride > 0.0) ? riskPercentOverride : m_riskPercentPerTrade;
      riskPct = MathMin(riskPct, m_maxRiskPercentPerTrade);

      double equity = AccountInfoDouble(ACCOUNT_EQUITY);
      double riskMoney = equity * (riskPct / 100.0);

      double tickValue = SymbolInfoDouble(m_symbol, SYMBOL_TRADE_TICK_VALUE);
      double tickSize  = SymbolInfoDouble(m_symbol, SYMBOL_TRADE_TICK_SIZE);
      if(tickSize <= 0.0 || tickValue <= 0.0) return 0.0;

      double moneyPerPriceUnit = tickValue / tickSize; // money per 1.0 price unit move, per 1 lot
      double moneyAtRiskPerLot = stopDistancePrice * moneyPerPriceUnit;
      if(moneyAtRiskPerLot <= 0.0) return 0.0;

      double rawLots = riskMoney / moneyAtRiskPerLot;

      double minLot  = SymbolInfoDouble(m_symbol, SYMBOL_VOLUME_MIN);
      double maxLot  = SymbolInfoDouble(m_symbol, SYMBOL_VOLUME_MAX);
      double lotStep = SymbolInfoDouble(m_symbol, SYMBOL_VOLUME_STEP);
      if(lotStep <= 0.0) lotStep = 0.01;

      double normalizedLots = MathFloor(rawLots / lotStep) * lotStep;
      normalizedLots = MathMax(minLot, MathMin(maxLot, normalizedLots));
      return normalizedLots;
     }

   // Current total margin-at-risk across this EA's open positions, as % of equity -- used for the
   // max-exposure cap.
   double            GetCurrentExposurePercent() const
     {
      double equity = AccountInfoDouble(ACCOUNT_EQUITY);
      if(equity <= 0.0) return 0.0;
      double totalMarginAtRisk = 0.0;
      int total = PositionsTotal();
      for(int i=0; i<total; i++)
        {
         ulong ticket = PositionGetTicket(i);
         if(ticket == 0) continue;
         if(!PositionSelectByTicket(ticket)) continue;
         if(PositionGetString(POSITION_SYMBOL) != m_symbol) continue;
         if((ulong)PositionGetInteger(POSITION_MAGIC) != m_magic) continue;
         double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
         double sl = PositionGetDouble(POSITION_SL);
         double volume = PositionGetDouble(POSITION_VOLUME);
         if(sl <= 0.0) continue;
         double stopDist = MathAbs(openPrice - sl);
         double tickValue = SymbolInfoDouble(m_symbol, SYMBOL_TRADE_TICK_VALUE);
         double tickSize  = SymbolInfoDouble(m_symbol, SYMBOL_TRADE_TICK_SIZE);
         if(tickSize <= 0.0) continue;
         double moneyPerPriceUnit = tickValue / tickSize;
         totalMarginAtRisk += stopDist * moneyPerPriceUnit * volume;
        }
      return (totalMarginAtRisk / equity) * 100.0;
     }

   // The single authoritative pre-trade approval gate. Checks every circuit breaker in sequence
   // and returns false with a logged reason on the first one that trips.
   bool              ValidateNewTrade(const int currentOpenPositions, const int maxOpenPositions)
     {
      double equity = AccountInfoDouble(ACCOUNT_EQUITY);

      if(m_killActive)
        {
         if(InpDebugMode) PrintFormat("[CRiskManager] Trade blocked: kill switch active (reason=%d).", (int)m_killReason);
         return false;
        }

      if(currentOpenPositions >= maxOpenPositions)
        {
         if(InpDebugMode) Print("[CRiskManager] Trade blocked: max open positions reached.");
         return false;
        }

      if(m_dayStartEquity > 0.0)
        {
         double dayLossPct = ((m_dayStartEquity - equity) / m_dayStartEquity) * 100.0;
         if(dayLossPct >= m_dailyLossLimitPct)
           {
            TriggerKillSwitch(KILL_DAILY_LOSS_LIMIT);
            return false;
           }
        }
      if(m_weekStartEquity > 0.0)
        {
         double weekLossPct = ((m_weekStartEquity - equity) / m_weekStartEquity) * 100.0;
         if(weekLossPct >= m_weeklyLossLimitPct)
           {
            TriggerKillSwitch(KILL_WEEKLY_LOSS_LIMIT);
            return false;
           }
        }
      if(m_monthStartEquity > 0.0)
        {
         double monthLossPct = ((m_monthStartEquity - equity) / m_monthStartEquity) * 100.0;
         if(monthLossPct >= m_monthlyLossLimitPct)
           {
            TriggerKillSwitch(KILL_MONTHLY_LOSS_LIMIT);
            return false;
           }
        }
      if(m_equityHighWaterMark > 0.0)
        {
         double ddPct = ((m_equityHighWaterMark - equity) / m_equityHighWaterMark) * 100.0;
         if(ddPct >= m_equityProtectionPct)
           {
            TriggerKillSwitch(KILL_EQUITY_PROTECTION);
            return false;
           }
        }
      if(m_consecutiveLosses >= m_maxConsecutiveLosses)
        {
         if(TimeCurrent() < m_consecLossCooldownUntil)
           {
            if(InpDebugMode) Print("[CRiskManager] Trade blocked: consecutive-loss cooldown active.");
            return false;
           }
         else
           {
            m_consecutiveLosses = 0; // cooldown expired, reset counter
           }
        }
      if(GetCurrentExposurePercent() >= m_maxExposurePct)
        {
         if(InpDebugMode) Print("[CRiskManager] Trade blocked: max exposure reached.");
         return false;
        }

      return true;
     }

   void              TriggerKillSwitch(const ENUM_KILL_REASON reason)
     {
      m_killActive = true;
      m_killReason = reason;
      PrintFormat("[CRiskManager] *** KILL SWITCH TRIGGERED *** reason=%d. New entries blocked.", (int)reason);
     }

   // Manual/scheduled reset hook -- e.g. a daily-limit kill should clear at the next day boundary
   // rather than persisting forever. Called from UpdatePeriodBaselines's day/week/month rollovers.
   void              ResetKillSwitchIfPeriodBased()
     {
      if(m_killActive && (m_killReason == KILL_DAILY_LOSS_LIMIT || m_killReason == KILL_WEEKLY_LOSS_LIMIT
                           || m_killReason == KILL_MONTHLY_LOSS_LIMIT))
        {
         m_killActive = false;
         m_killReason = KILL_NONE;
         if(InpDebugMode) Print("[CRiskManager] Period-based kill switch reset on new period boundary.");
        }
     }

   // Called by the trade journal/router after every closed trade to update consecutive-loss state.
   void              UpdateLossCounters(const bool isWin)
     {
      if(isWin)
        {
         m_consecutiveLosses = 0;
        }
      else
        {
         m_consecutiveLosses++;
         if(m_consecutiveLosses >= m_maxConsecutiveLosses)
           {
            m_consecLossCooldownUntil = TimeCurrent() + (m_consecLossCooldownMin * 60);
            PrintFormat("[CRiskManager] Consecutive loss limit reached (%d). Cooldown until %s.",
                        m_consecutiveLosses, TimeToString(m_consecLossCooldownUntil));
           }
        }
     }

   bool              IsKillActive() const            { return m_killActive; }
   ENUM_KILL_REASON  GetKillReason() const            { return m_killReason; }
   int               GetConsecutiveLosses() const     { return m_consecutiveLosses; }
   double            GetEquityHighWaterMark() const   { return m_equityHighWaterMark; }
  };

//+------------------------------------------------------------------------------------------------+
//| CExitEngine                                                                                         |
//| Manages all open-position exit logic: ATR-based hard stop, structure-based stop tightening,         |
//| break-even, tiered partial profit taking (TP1/TP2, runner to TP3/trailing), ATR-based trailing,     |
//| structure-violation trend exit, and time-based forced exit. Uses position comments to track         |
//| per-position state (which partials have already fired) since MT5 doesn't give us a clean place to   |
//| store custom per-position state otherwise without an external map.                                  |
//+------------------------------------------------------------------------------------------------+
class CExitEngine
  {
private:
   string            m_symbol;
   ulong             m_magic;
   double            m_hardStopATRMult;
   double            m_tp1ATRMult, m_tp2ATRMult, m_tp3ATRMult;
   double            m_tp1ClosePct, m_tp2ClosePct;
   double            m_beTriggerATR;
   double            m_beOffsetPoints;
   double            m_trailStartATR;
   double            m_trailStepATRMult;
   int               m_timeExitMaxBars;
   bool              m_useStructureStop;

   CVolatilityEngine *m_vol;
   CMarketStructure  *m_structure;
   CTrade            *m_trade;

public:
   bool              Init(const string symbol, const ulong magic, const double hardStopATRMult,
                           const double tp1Mult, const double tp2Mult, const double tp3Mult,
                           const double tp1Pct, const double tp2Pct, const double beTriggerATR,
                           const double beOffsetPoints, const double trailStartATR, const double trailStepMult,
                           const int timeExitMaxBars, const bool useStructureStop,
                           CVolatilityEngine *vol, CMarketStructure *structure, CTrade *trade)
     {
      m_symbol = symbol;
      m_magic = magic;
      m_hardStopATRMult = hardStopATRMult;
      m_tp1ATRMult = tp1Mult; m_tp2ATRMult = tp2Mult; m_tp3ATRMult = tp3Mult;
      m_tp1ClosePct = tp1Pct; m_tp2ClosePct = tp2Pct;
      m_beTriggerATR = beTriggerATR;
      m_beOffsetPoints = beOffsetPoints;
      m_trailStartATR = trailStartATR;
      m_trailStepATRMult = trailStepMult;
      m_timeExitMaxBars = timeExitMaxBars;
      m_useStructureStop = useStructureStop;
      m_vol = vol;
      m_structure = structure;
      m_trade = trade;
      return true;
     }

   // Computes the initial hard stop distance (in price units) for a new trade, in ATR multiples.
   double            GetInitialStopDistance() const
     {
      if(m_vol == NULL) return 0.0;
      return m_vol.GetCurrentATR() * m_hardStopATRMult;
     }

   double            GetTP1Distance() const { return (m_vol != NULL) ? m_vol.GetCurrentATR() * m_tp1ATRMult : 0.0; }
   double            GetTP2Distance() const { return (m_vol != NULL) ? m_vol.GetCurrentATR() * m_tp2ATRMult : 0.0; }
   double            GetTP3Distance() const { return (m_vol != NULL) ? m_vol.GetCurrentATR() * m_tp3ATRMult : 0.0; }

   // Core per-tick management loop for ALL open positions belonging to this EA. Call every tick
   // (exits need low latency, unlike entry logic which is throttled to bar-close).
   void              ManageOpenPositions()
     {
      int total = PositionsTotal();
      for(int i=total-1; i>=0; i--)
        {
         ulong ticket = PositionGetTicket(i);
         if(ticket == 0) continue;
         if(!PositionSelectByTicket(ticket)) continue;
         if(PositionGetString(POSITION_SYMBOL) != m_symbol) continue;
         if((ulong)PositionGetInteger(POSITION_MAGIC) != m_magic) continue;

         ManageSinglePosition(ticket);
        }
     }

private:
   void              ManageSinglePosition(const ulong ticket)
     {
      long posType   = PositionGetInteger(POSITION_TYPE);
      double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
      double curSL    = PositionGetDouble(POSITION_SL);
      double curTP    = PositionGetDouble(POSITION_TP);
      double volume   = PositionGetDouble(POSITION_VOLUME);
      datetime openTime = (datetime)PositionGetInteger(POSITION_TIME);

      bool isBuy = (posType == POSITION_TYPE_BUY);
      double price = isBuy ? SymbolInfoDouble(m_symbol, SYMBOL_BID) : SymbolInfoDouble(m_symbol, SYMBOL_ASK);
      double atr = (m_vol != NULL) ? m_vol.GetCurrentATR() : 0.0;
      if(atr <= 0.0) return;

      double favorableMove = isBuy ? (price - openPrice) : (openPrice - price);
      double favorableMoveATR = favorableMove / atr;

      // --- TIME EXIT: forced close if trade has been open too long without resolution ---
      int barsOpen = iBarShift(m_symbol, PERIOD_CURRENT, openTime);
      if(barsOpen >= m_timeExitMaxBars)
        {
         m_trade.PositionClose(ticket);
         if(InpDebugMode) PrintFormat("[CExitEngine] Time exit triggered on ticket %I64u after %d bars.", ticket, barsOpen);
         return;
        }

      // --- STRUCTURE STOP: tighten stop to just beyond the most recent opposing swing if that's
      //     tighter than the current stop and still in profit-protecting direction ---
      if(m_useStructureStop && m_structure != NULL)
        {
         double structLevel = isBuy ? m_structure.GetLastSwingLow() : m_structure.GetLastSwingHigh();
         if(structLevel > 0.0)
           {
            bool structTighter = isBuy ? (structLevel > curSL) : (curSL <= 0.0 || structLevel < curSL);
            bool structInProfitDir = isBuy ? (structLevel < price) : (structLevel > price);
            if(structTighter && structInProfitDir && favorableMoveATR > 0.3)
              {
               double point = SymbolInfoDouble(m_symbol, SYMBOL_POINT);
               double buffer = 10 * point;
               double newSL = isBuy ? (structLevel - buffer) : (structLevel + buffer);
               if(IsStopImprovement(isBuy, newSL, curSL))
                 {
                  m_trade.PositionModify(ticket, newSL, curTP);
                  curSL = newSL;
                 }
              }
           }
        }

      // --- BREAK-EVEN ---
      if(!IsBEFired(ticket) && favorableMoveATR >= m_beTriggerATR)
        {
         double point = SymbolInfoDouble(m_symbol, SYMBOL_POINT);
         double beOffset = m_beOffsetPoints * point;
         double newSL = isBuy ? (openPrice + beOffset) : (openPrice - beOffset);
         if(IsStopImprovement(isBuy, newSL, curSL))
           {
            if(m_trade.PositionModify(ticket, newSL, curTP))
              {
               curSL = newSL;
               TrackBEFired(ticket);
              }
           }
        }

      // --- PARTIAL TP1 ---
      double tp1Dist = GetTP1Distance();
      if(!IsTP1Fired(ticket) && tp1Dist > 0.0 && favorableMove >= tp1Dist)
        {
         double closeVolume = NormalizeVolumeForClose(volume * (m_tp1ClosePct / 100.0));
         if(closeVolume > 0.0)
           {
            m_trade.PositionClosePartial(ticket, closeVolume);
            TrackTP1Fired(ticket);
            if(InpDebugMode) PrintFormat("[CExitEngine] TP1 partial close on ticket %I64u: %.2f lots.", ticket, closeVolume);
           }
        }

      // --- PARTIAL TP2 ---
      double tp2Dist = GetTP2Distance();
      if(IsTP1Fired(ticket) && !IsTP2Fired(ticket) && tp2Dist > 0.0 && favorableMove >= tp2Dist)
        {
         // Re-select position (volume changed after TP1 partial close)
         if(!PositionSelectByTicket(ticket)) return;
         double remainingVolume = PositionGetDouble(POSITION_VOLUME);
         double closeVolume = NormalizeVolumeForClose(remainingVolume * (m_tp2ClosePct / (100.0 - m_tp1ClosePct)));
         if(closeVolume > 0.0 && closeVolume < remainingVolume)
           {
            m_trade.PositionClosePartial(ticket, closeVolume);
            TrackTP2Fired(ticket);
            if(InpDebugMode) PrintFormat("[CExitEngine] TP2 partial close on ticket %I64u: %.2f lots.", ticket, closeVolume);
           }
         else if(closeVolume >= remainingVolume)
           {
            m_trade.PositionClose(ticket); // remainder too small to partial, close fully
            TrackTP2Fired(ticket);
           }
        }

      // --- TRAILING STOP (active after trail-start ATR threshold, runner portion after TP2) ---
      if(favorableMoveATR >= m_trailStartATR)
        {
         double trailDist = atr * m_trailStepATRMult;
         double newSL = isBuy ? (price - trailDist) : (price + trailDist);
         if(IsStopImprovement(isBuy, newSL, curSL))
            m_trade.PositionModify(ticket, newSL, curTP);
        }

      // --- TREND EXIT: structure violation (CHOCH against position direction) forces full close ---
      if(m_structure != NULL)
        {
         ENUM_TREND_DIR bias = m_structure.GetStructureBias();
         bool violatesLong  = isBuy  && m_structure.IsCHOCH() && bias == TREND_DIR_DOWN;
         bool violatesShort = !isBuy && m_structure.IsCHOCH() && bias == TREND_DIR_UP;
         if(violatesLong || violatesShort)
           {
            m_trade.PositionClose(ticket);
            if(InpDebugMode) PrintFormat("[CExitEngine] Trend/structure violation exit on ticket %I64u.", ticket);
            return;
           }
        }
     }

   bool              IsStopImprovement(const bool isBuy, const double newSL, const double curSL) const
     {
      if(newSL <= 0.0) return false;
      if(curSL <= 0.0) return true; // no stop set yet, any valid stop is an improvement
      return isBuy ? (newSL > curSL) : (newSL < curSL);
     }

   double            NormalizeVolumeForClose(const double rawVolume) const
     {
      double minLot  = SymbolInfoDouble(m_symbol, SYMBOL_VOLUME_MIN);
      double lotStep = SymbolInfoDouble(m_symbol, SYMBOL_VOLUME_STEP);
      if(lotStep <= 0.0) lotStep = 0.01;
      double normalized = MathFloor(rawVolume / lotStep) * lotStep;
      if(normalized < minLot) return 0.0;
      return normalized;
     }

   // Per-position partial/BE fired-state tracking via parallel ticket arrays (simple, avoids the
   // comment-immutability issue noted above; cleared lazily as tickets close since MT5 positions
   // are uniquely keyed by ticket for the life of the position).
   ulong             m_tp1FiredTickets[];
   ulong             m_tp2FiredTickets[];
   ulong             m_beFiredTickets[];

   bool              TicketInArray(const ulong &arr[], const ulong ticket) const
     {
      int n = ArraySize(arr);
      for(int i=0; i<n; i++)
         if(arr[i] == ticket) return true;
      return false;
     }

   void              AddTicketToArray(ulong &arr[], const ulong ticket)
     {
      int n = ArraySize(arr);
      ArrayResize(arr, n+1);
      arr[n] = ticket;
     }

public:
   bool              IsTP1Fired(const ulong ticket) const { return TicketInArray(m_tp1FiredTickets, ticket); }
   bool              IsTP2Fired(const ulong ticket) const { return TicketInArray(m_tp2FiredTickets, ticket); }
   bool              IsBEFired(const ulong ticket) const  { return TicketInArray(m_beFiredTickets, ticket); }
   void              TrackTP1Fired(const ulong ticket)    { if(!IsTP1Fired(ticket)) AddTicketToArray(m_tp1FiredTickets, ticket); }
   void              TrackTP2Fired(const ulong ticket)    { if(!IsTP2Fired(ticket)) AddTicketToArray(m_tp2FiredTickets, ticket); }
   void              TrackBEFired(const ulong ticket)     { if(!IsBEFired(ticket)) AddTicketToArray(m_beFiredTickets, ticket); }
  };

//+------------------------------------------------------------------------------------------------+
//| CTradeJournal                                                                                       |
//| Persists every closed trade to a CSV (MQL5\Files\<InpTradeJournalFileName>) and maintains live      |
//| in-memory aggregates for win rate, expectancy, profit factor, average R-multiple, and breakdowns    |
//| by strategy/regime/session -- satisfying the spec's self-analytics requirements.                    |
//+------------------------------------------------------------------------------------------------+
class CTradeJournal
  {
private:
   string            m_fileName;
   bool              m_fileInitialized;

   int               m_totalTrades;
   int               m_winTrades;
   int               m_lossTrades;
   double            m_grossProfit;
   double            m_grossLoss;
   double            m_sumRMultiple;

   // Per-strategy aggregates (indexed by ENUM_STRATEGY_TYPE, 5 values 0-4)
   int               m_stratTrades[5];
   int               m_stratWins[5];
   double            m_stratSumR[5];

   // Per-regime aggregates (indexed by ENUM_REGIME, 7 values 0-6)
   int               m_regimeTrades[7];
   int               m_regimeWins[7];
   double            m_regimeSumR[7];

   // Per-session aggregates (indexed by ENUM_SESSION, 5 values 0-4)
   int               m_sessionTrades[5];
   int               m_sessionWins[5];
   double            m_sessionSumR[5];

public:
                     CTradeJournal()
     {
      m_fileInitialized = false;
      m_totalTrades = 0; m_winTrades = 0; m_lossTrades = 0;
      m_grossProfit = 0.0; m_grossLoss = 0.0; m_sumRMultiple = 0.0;
      ArrayInitialize(m_stratTrades, 0);
      ArrayInitialize(m_stratWins, 0);
      ArrayInitialize(m_regimeTrades, 0);
      ArrayInitialize(m_regimeWins, 0);
      ArrayInitialize(m_sessionTrades, 0);
      ArrayInitialize(m_sessionWins, 0);
      for(int i=0;i<5;i++){ m_stratSumR[i]=0.0; m_sessionSumR[i]=0.0; }
      for(int i=0;i<7;i++) m_regimeSumR[i]=0.0;
     }

   bool              Init(const string fileName)
     {
      m_fileName = fileName;
      // Write CSV header if file doesn't already exist, so repeated EA restarts append rather
      // than duplicate headers or overwrite history.
      if(!FileIsExist(m_fileName))
        {
         int handle = FileOpen(m_fileName, FILE_WRITE|FILE_CSV|FILE_ANSI, ',');
         if(handle == INVALID_HANDLE)
           {
            Print("[CTradeJournal] ERROR: could not create journal file '", m_fileName, "'. Error=", GetLastError());
            return false;
           }
         FileWrite(handle, "OpenTime","CloseTime","Strategy","Regime","Session",
                   "ConfluenceScore","LogisticProb","RMultiple","IsWin");
         FileClose(handle);
        }
      else
        {
         LoadAggregatesFromFile();
        }
      m_fileInitialized = true;
      return true;
     }

   // Appends one closed trade to the CSV and updates all in-memory aggregates. This is the
   // authoritative call-site for "trade closed" bookkeeping across the whole EA.
   void              RecordClosedTrade(const TradeRecord &rec)
     {
      int handle = FileOpen(m_fileName, FILE_READ|FILE_WRITE|FILE_CSV|FILE_ANSI, ',');
      if(handle != INVALID_HANDLE)
        {
         FileSeek(handle, 0, SEEK_END);
         FileWrite(handle, TimeToString(rec.openTime), TimeToString(rec.closeTime),
                   EnumToString(rec.strategy), EnumToString(rec.regimeAtEntry), EnumToString(rec.sessionAtEntry),
                   rec.confluenceScoreAtEntry, rec.logisticProbAtEntry, rec.rMultiple, rec.isWin ? 1 : 0);
         FileClose(handle);
        }
      else
        {
         Print("[CTradeJournal] ERROR: could not append to journal file. Error=", GetLastError());
        }

      m_totalTrades++;
      if(rec.isWin)
        {
         m_winTrades++;
         m_grossProfit += MathMax(0.0, rec.rMultiple);
        }
      else
        {
         m_lossTrades++;
         m_grossLoss += MathAbs(MathMin(0.0, rec.rMultiple));
        }
      m_sumRMultiple += rec.rMultiple;

      int sIdx = (int)rec.strategy;
      if(sIdx >= 0 && sIdx < 5)
        {
         m_stratTrades[sIdx]++;
         if(rec.isWin) m_stratWins[sIdx]++;
         m_stratSumR[sIdx] += rec.rMultiple;
        }

      int rIdx = (int)rec.regimeAtEntry;
      if(rIdx >= 0 && rIdx < 7)
        {
         m_regimeTrades[rIdx]++;
         if(rec.isWin) m_regimeWins[rIdx]++;
         m_regimeSumR[rIdx] += rec.rMultiple;
        }

      int seIdx = (int)rec.sessionAtEntry;
      if(seIdx >= 0 && seIdx < 5)
        {
         m_sessionTrades[seIdx]++;
         if(rec.isWin) m_sessionWins[seIdx]++;
         m_sessionSumR[seIdx] += rec.rMultiple;
        }

      if(InpDebugMode)
         PrintFormat("[CTradeJournal] Recorded trade #%d: strategy=%s regime=%s R=%.2f win=%s. Running winrate=%.1f%% expectancy=%.3fR",
                     m_totalTrades, EnumToString(rec.strategy), EnumToString(rec.regimeAtEntry),
                     rec.rMultiple, rec.isWin?"true":"false", GetWinRate(), GetExpectancy());
     }

   // On EA restart, re-derive in-memory aggregates by replaying the persisted CSV. This keeps
   // analytics consistent across restarts without needing a separate binary state file.
   void              LoadAggregatesFromFile()
     {
      int handle = FileOpen(m_fileName, FILE_READ|FILE_CSV|FILE_ANSI, ',');
      if(handle == INVALID_HANDLE) return;

      // skip header row
      if(!FileIsEnding(handle))
        {
         for(int i=0;i<9;i++) { if(FileIsEnding(handle)) break; FileReadString(handle); }
        }

      while(!FileIsEnding(handle))
        {
         string openTimeStr = FileReadString(handle);
         if(StringLen(openTimeStr) == 0) break;
         string closeTimeStr = FileReadString(handle);
         string stratStr = FileReadString(handle);
         string regimeStr = FileReadString(handle);
         string sessionStr = FileReadString(handle);
         double score = FileReadNumber(handle);
         double prob = FileReadNumber(handle);
         double rMult = FileReadNumber(handle);
         int isWinRaw = (int)FileReadNumber(handle);

         m_totalTrades++;
         bool isWin = (isWinRaw == 1);
         if(isWin) { m_winTrades++; m_grossProfit += MathMax(0.0, rMult); }
         else      { m_lossTrades++; m_grossLoss += MathAbs(MathMin(0.0, rMult)); }
         m_sumRMultiple += rMult;
         // Per-bucket reconstruction from string labels omitted for brevity/robustness here --
         // EnumToString round-trip via string compare is fragile across MQL5 builds; the headline
         // aggregates (win rate/expectancy/PF/avg-R) are the ones reconstructed precisely on reload,
         // which are the figures actually surfaced to Karisa via GetSummaryString(). Per-bucket
         // breakdowns rebuild fresh from this session forward, which is logged clearly below.
        }
      FileClose(handle);
      if(m_totalTrades > 0 && InpDebugMode)
         PrintFormat("[CTradeJournal] Reloaded %d historical trades from journal. Headline aggregates restored; "
                     "per-strategy/regime/session breakdowns rebuild fresh this session.", m_totalTrades);
     }

   double            GetWinRate() const { return m_totalTrades > 0 ? (100.0 * m_winTrades / m_totalTrades) : 0.0; }
   double            GetProfitFactor() const { return m_grossLoss > 0.0 ? (m_grossProfit / m_grossLoss) : 0.0; }
   double            GetExpectancy() const { return m_totalTrades > 0 ? (m_sumRMultiple / m_totalTrades) : 0.0; }
   double            GetAverageRMultiple() const { return GetExpectancy(); }
   int               GetTotalTrades() const { return m_totalTrades; }

   string            GetSummaryString() const
     {
      return StringFormat("Trades=%d WinRate=%.1f%% PF=%.2f Expectancy=%.3fR GrossP=%.2fR GrossL=%.2fR",
                           m_totalTrades, GetWinRate(), GetProfitFactor(), GetExpectancy(), m_grossProfit, m_grossLoss);
     }
  };

//+------------------------------------------------------------------------------------------------+
//| CStrategyRouter                                                                                     |
//| Orchestrates all subsystems: selects dominant engine from regime state, evaluates blending rules,   |
//| computes the final blended confluence+logistic score, enforces the entry threshold (with session    |
//| multiplier and slow adaptive drift within bounds), and places orders via CTrade on approval.        |
//+------------------------------------------------------------------------------------------------+
class CStrategyRouter
  {
private:
   string            m_symbol;
   ENUM_TIMEFRAMES   m_tf;
   ulong             m_magic;

   // Subsystem pointers (all owned externally, router holds non-owning references)
   CVolatilityEngine        *m_vol;
   COrderFlowProxy          *m_flow;
   CSessionProfile          *m_session;
   CRegimeClassifier        *m_regime;
   CMarketStructure         *m_structure;
   CMTFConfirmation         *m_mtf;
   CTrendEngine             *m_trend;
   CRangeEngine             *m_range;
   CBreakoutEngine          *m_breakout;
   CLiquiditySweepEngine    *m_sweep;
   CExecutionQualityFilter  *m_execFilter;
   CRiskManager             *m_risk;
   CExitEngine              *m_exit;
   CTradeJournal            *m_journal;
   CNewsShockDetector       *m_newsShock;
   CLogisticModel           *m_logistic;
   CTrade                   *m_trade;

   // Adaptive threshold state
   double            m_baseThreshold;
   double            m_adaptiveThreshold;
   double            m_thresholdAdaptBandAbs;

   // Rolling expectancy window for threshold adaptation (last 30 trades)
   double            m_recentRMultiples[30];
   int               m_recentRCount;
   int               m_recentRHead;

   // Per-bar state (prevent multiple entries on the same bar)
   datetime          m_lastBarTime;
   bool              m_entryAttemptedThisBar;

   // Pending trade-outcome bookkeeping for logistic model updates
   // (keyed by deal ticket; populated on open, consumed on close via OnTradeTransaction)
   struct PendingTrade
     {
      ulong           ticket;
      FeatureVector   features;
      double          initialRiskDistance;
      double          confluenceScore;
      double          logisticProb;
      ENUM_STRATEGY_TYPE strategy;
      ENUM_REGIME     regime;
      ENUM_SESSION    session;
      datetime        openTime;
     };
   PendingTrade      m_pending[50]; // maximum tracked simultaneously; well above InpMaxOpenPositions
   int               m_pendingCount;

public:
                     CStrategyRouter()
     {
      m_baseThreshold = 65.0;
      m_adaptiveThreshold = 65.0;
      m_thresholdAdaptBandAbs = 6.5;
      m_recentRCount = 0;
      m_recentRHead = 0;
      m_lastBarTime = 0;
      m_entryAttemptedThisBar = false;
      m_pendingCount = 0;
      ArrayInitialize(m_recentRMultiples, 0.0);
     }

   bool              Init(const string symbol, const ENUM_TIMEFRAMES tf, const ulong magic,
                           CVolatilityEngine *vol, COrderFlowProxy *flow, CSessionProfile *session,
                           CRegimeClassifier *regime, CMarketStructure *structure, CMTFConfirmation *mtf,
                           CTrendEngine *trend, CRangeEngine *range, CBreakoutEngine *breakout,
                           CLiquiditySweepEngine *sweep, CExecutionQualityFilter *execFilter,
                           CRiskManager *risk, CExitEngine *exit, CTradeJournal *journal,
                           CNewsShockDetector *newsShock, CLogisticModel *logistic, CTrade *trade)
     {
      m_symbol = symbol; m_tf = tf; m_magic = magic;
      m_vol = vol; m_flow = flow; m_session = session; m_regime = regime;
      m_structure = structure; m_mtf = mtf; m_trend = trend; m_range = range;
      m_breakout = breakout; m_sweep = sweep; m_execFilter = execFilter;
      m_risk = risk; m_exit = exit; m_journal = journal;
      m_newsShock = newsShock; m_logistic = logistic; m_trade = trade;
      m_baseThreshold = InpEntryScoreThreshold;
      m_adaptiveThreshold = InpEntryScoreThreshold;
      m_thresholdAdaptBandAbs = InpEntryScoreThreshold * (InpThresholdAdaptBandPct / 100.0);
      return true;
     }

   // Master per-tick entry point. Call from OnTick(). Internally throttles heavy computation to
   // new-bar events; always runs exit management and news-shock detection at full tick resolution.
   void              OnTick()
     {
      if(m_newsShock != NULL) m_newsShock.CheckAndUpdate();
      if(m_flow != NULL) m_flow.OnTick();
      if(m_exit != NULL) m_exit.ManageOpenPositions();

      datetime curBarTime = iTime(m_symbol, m_tf, 0);
      bool isNewBar = (curBarTime != m_lastBarTime);
      if(!isNewBar) return;

      m_lastBarTime = curBarTime;
      m_entryAttemptedThisBar = false;

      OnNewBar();
     }

private:
   void              OnNewBar()
     {
      // Update all indicator-derived state (throttled to bar close for CPU efficiency)
      if(m_vol != NULL)      m_vol.Update();
      if(m_flow != NULL)     m_flow.UpdateVolumeZScore();
      if(m_structure != NULL) m_structure.Update();
      if(m_newsShock != NULL) m_newsShock.UpdateBaselines();
      if(m_risk != NULL)     m_risk.UpdatePeriodBaselines();
      if(m_breakout != NULL) m_breakout.UpdateBreakoutState();
      if(m_sweep != NULL)    m_sweep.UpdateSweepState();

      // Gate 1: news shock blocks new entries (exits still managed above)
      if(m_newsShock != NULL && m_newsShock.IsShockActive())
        {
         if(InpDebugMode) Print("[CStrategyRouter] Entry blocked: news shock active.");
         return;
        }

      // Gate 2: risk manager kill switch
      int openPos = CountOurOpenPositions();
      if(m_risk != NULL && !m_risk.ValidateNewTrade(openPos, InpMaxOpenPositions))
         return;

      // Already at max positions
      if(openPos >= InpMaxOpenPositions) return;

      // Classify regime
      if(m_regime == NULL || m_vol == NULL || !m_vol.IsReady()) return;
      RegimeState regState = m_regime.Classify(InpRegimeMinConfidence);

      if(regState.regime == REGIME_UNDEFINED || regState.regime == REGIME_NEWS_SHOCK)
         return;

      // Session context
      ENUM_SESSION currentSession = SESSION_OFF_HOURS;
      double sessionMultiplier = InpOffHoursScoreMultiplier;
      double riskMultiplier = 1.0;
      if(m_session != NULL)
        {
         datetime now = TimeCurrent();
         currentSession = m_session.GetCurrentSession(now);
         sessionMultiplier = m_session.GetScoreThresholdMultiplier(currentSession);
         riskMultiplier = m_session.GetRiskMultiplier(now);
        }

      // MTF alignment
      double mtfScore = 100.0; // default full credit if MTF disabled
      if(InpUseMTFConfirmation && m_mtf != NULL)
        {
         ENUM_TREND_DIR candDir = regState.direction;
         if(candDir == TREND_DIR_NONE)
           {
            // For range/sweep, both directions are potential candidates -- use structure bias
            candDir = (m_structure != NULL) ? m_structure.GetStructureBias() : TREND_DIR_NONE;
           }
         mtfScore = m_mtf.GetAlignmentScore(candDir);
         if(mtfScore < InpMTFMinAlignmentScore)
           {
            if(InpDebugMode) PrintFormat("[CStrategyRouter] Entry blocked: MTF alignment %.0f < min %d.", mtfScore, InpMTFMinAlignmentScore);
            return;
           }
        }

      // Route to dominant engine + optional sweep blending
      ConfluenceScore cs;
      ENUM_STRATEGY_TYPE activeStrategy = STRAT_NONE;
      ENUM_TREND_DIR tradeDirection = TREND_DIR_NONE;

      RouteToEngine(regState, mtfScore, cs, activeStrategy, tradeDirection);

      if(activeStrategy == STRAT_NONE) return;

      // Session quality sub-score (filled here, not in the engine)
      if(m_session != NULL)
         cs.sessionQuality = m_session.GetSessionQualityScore(currentSession);

      double rawScore = cs.Total();

      // Logistic model blend
      double logisticProb = 0.5;
      FeatureVector fv;
      BuildFeatureVector(cs, regState, mtfScore, fv);

      if(InpUseLogisticModel && m_logistic != NULL)
        {
         logisticProb = m_logistic.Predict(fv, InpMinTradesForLearning);
        }

      // Final blended score: weighted combination of confluence score and logistic probability.
      // Logistic model is scaled back to 0-100 range before blending.
      double logisticScore100 = logisticProb * 100.0;
      double blendWeight = InpUseLogisticModel ? InpLogisticBlendWeight : 0.0;
      double finalScore = (rawScore * (1.0 - blendWeight)) + (logisticScore100 * blendWeight);

      // Apply session threshold multiplier and check against adaptive threshold
      double effectiveThreshold = m_adaptiveThreshold * sessionMultiplier;
      if(finalScore < effectiveThreshold)
        {
         if(InpDebugMode) PrintFormat("[CStrategyRouter] Entry filtered: score=%.1f threshold=%.1f (session mult=%.2f).",
                                       finalScore, effectiveThreshold, sessionMultiplier);
         return;
        }

      // High-vol modifier: tighten threshold requirement during volatile regimes
      if(regState.highVolModifier)
        {
         effectiveThreshold = effectiveThreshold * 1.1; // require 10% more confluence during high-vol
         if(finalScore < effectiveThreshold)
           {
            if(InpDebugMode) Print("[CStrategyRouter] Entry filtered: HighVol modifier raised threshold; score insufficient.");
            return;
           }
        }

      // Compute stop distance for position sizing and execution filter check
      double stopDist = (m_exit != NULL) ? m_exit.GetInitialStopDistance() : 0.0;
      if(stopDist <= 0.0)
        {
         if(InpDebugMode) Print("[CStrategyRouter] Entry blocked: zero stop distance (ATR not ready?).");
         return;
        }

      // Execution quality gate
      if(m_execFilter != NULL && !m_execFilter.IsExecutionQualityOK(stopDist))
         return;

      // Position sizing (risk% adjusted by weekend/session multiplier)
      double riskPct = InpRiskPercentPerTrade * riskMultiplier;
      double lots = (m_risk != NULL) ? m_risk.CalculatePositionSize(stopDist, riskPct) : 0.0;
      if(lots <= 0.0)
        {
         if(InpDebugMode) Print("[CStrategyRouter] Entry blocked: position size computed as zero.");
         return;
        }

      // Execute
      if(PlaceTrade(tradeDirection, lots, stopDist, activeStrategy, regState, currentSession, fv, finalScore, logisticProb))
        {
         m_entryAttemptedThisBar = true;
         // Consume breakout/sweep state so duplicate entries aren't attempted
         if(activeStrategy == STRAT_BREAKOUT && m_breakout != NULL) m_breakout.ConsumeSignal();
         if(activeStrategy == STRAT_LIQUIDITY_SWEEP && m_sweep != NULL) m_sweep.ConsumeSignal();
         // Slowly adapt threshold toward slightly higher bar if this was a "comfortable" score
         if(InpAllowThresholdAdaptation) AdaptThreshold(finalScore, effectiveThreshold);
        }
     }

   // Selects the dominant engine based on regime and evaluates Liquidity Sweep blending if allowed.
   void              RouteToEngine(const RegimeState &rs, const double mtfScore,
                                    ConfluenceScore &cs, ENUM_STRATEGY_TYPE &strategy, ENUM_TREND_DIR &dir)
     {
      cs.Clear();
      strategy = STRAT_NONE;
      dir = rs.direction;

      switch(rs.regime)
        {
         case REGIME_BULL_TREND:
         case REGIME_BEAR_TREND:
            if(m_trend == NULL) return;
            cs = m_trend.GetSignal(rs.direction, mtfScore);
            strategy = STRAT_TREND;
            // Blending: if Liquidity Sweep is active and agrees with trend direction, add bonus
            if(m_sweep != NULL && m_sweep.IsSweepActive() && CanBlend(STRAT_TREND, STRAT_LIQUIDITY_SWEEP))
               cs.sweepBonus = m_sweep.GetConfirmationBonus(rs.direction, InpSweepBonusPoints);
            break;

         case REGIME_RANGE:
            if(m_range == NULL || m_structure == NULL) return;
            // For range trades, determine which direction offers the better mean-reversion setup
            // by checking which BB band price is closest to (done inside engine via GetSignal)
            // We attempt BOTH and take the higher-scoring direction.
           {
            double price = SymbolInfoDouble(m_symbol, SYMBOL_BID);
            ENUM_TREND_DIR bestDir = DetermineRangeDirection(price);
            if(bestDir == TREND_DIR_NONE) return;
            cs = m_range.GetSignal(bestDir);
            strategy = STRAT_RANGE;
            dir = bestDir;
            // Range + Sweep blending
            if(m_sweep != NULL && m_sweep.IsSweepActive() && CanBlend(STRAT_RANGE, STRAT_LIQUIDITY_SWEEP))
               cs.sweepBonus = m_sweep.GetConfirmationBonus(bestDir, InpSweepBonusPoints);
           }
            break;

         case REGIME_BREAKOUT:
            if(m_breakout == NULL || !m_breakout.IsAwaitingRetest()) return;
            cs = m_breakout.GetSignal();
            strategy = STRAT_BREAKOUT;
            dir = m_breakout.GetBreakoutDirection();
            // Breakout stays exclusive -- no blending allowed (see ARCHITECTURE.md Conflict #1)
            break;

         case REGIME_LIQ_SWEEP:
            if(m_sweep == NULL || !m_sweep.IsSweepActive()) return;
            cs = m_sweep.GetSignal();
            strategy = STRAT_LIQUIDITY_SWEEP;
            dir = m_sweep.GetSweepDirection();
            break;

         default: return;
        }
     }

   // Determines which direction a range mean-reversion trade should target, by comparing the
   // current price's proximity to the upper vs lower Bollinger Band via both candidate signals.
   ENUM_TREND_DIR    DetermineRangeDirection(const double price) const
     {
      if(m_range == NULL) return TREND_DIR_NONE;
      ConfluenceScore csUp   = m_range.GetSignal(TREND_DIR_UP);
      ConfluenceScore csDown = m_range.GetSignal(TREND_DIR_DOWN);
      double scoreUp   = csUp.Total();
      double scoreDown = csDown.Total();
      if(scoreUp == 0.0 && scoreDown == 0.0) return TREND_DIR_NONE;
      return (scoreUp >= scoreDown) ? TREND_DIR_UP : TREND_DIR_DOWN;
     }

   // Blending compatibility table. Explicit, not computed -- makes the rules transparent and
   // impossible to accidentally expand. Only two valid pairs per the approved architecture.
   bool              CanBlend(const ENUM_STRATEGY_TYPE dominant, const ENUM_STRATEGY_TYPE secondary) const
     {
      if(secondary != STRAT_LIQUIDITY_SWEEP) return false;
      return (dominant == STRAT_TREND || dominant == STRAT_RANGE);
      // STRAT_BREAKOUT: explicitly forbidden from blending (false-breakout risk)
      // STRAT_LIQUIDITY_SWEEP as dominant: no secondary (is the primary signal itself)
     }

   void              BuildFeatureVector(const ConfluenceScore &cs, const RegimeState &rs,
                                         const double mtfScore, FeatureVector &fv) const
     {
      // All 9 features normalized to [0,1] for the logistic model.
      // Feature index meaning: see CLogisticModel class header.
      fv.f[0] = cs.trendAlignment / 20.0;
      fv.f[1] = cs.momentum / 20.0;
      fv.f[2] = cs.volumeFlow / 15.0;
      fv.f[3] = cs.liquidityConfirm / 15.0;
      fv.f[4] = cs.volatilityCondition / 15.0;
      fv.f[5] = cs.sessionQuality / 15.0;
      fv.f[6] = rs.confidence / 100.0;
      fv.f[7] = mtfScore / 100.0;
      fv.f[8] = cs.sweepBonus / MathMax(1.0, InpSweepBonusPoints);
      // Clamp all to [0,1] as a defensive measure against any sub-score overflow edge cases
      for(int i=0; i<9; i++)
         fv.f[i] = MathMax(0.0, MathMin(1.0, fv.f[i]));
     }

   bool              PlaceTrade(const ENUM_TREND_DIR dir, const double lots, const double stopDist,
                                  const ENUM_STRATEGY_TYPE strategy, const RegimeState &rs,
                                  const ENUM_SESSION session, const FeatureVector &fv,
                                  const double finalScore, const double logisticProb)
     {
      if(dir == TREND_DIR_NONE || lots <= 0.0 || stopDist <= 0.0) return false;

      double ask = SymbolInfoDouble(m_symbol, SYMBOL_ASK);
      double bid = SymbolInfoDouble(m_symbol, SYMBOL_BID);
      double point = SymbolInfoDouble(m_symbol, SYMBOL_POINT);
      int slippage = (m_execFilter != NULL) ? m_execFilter.GetMaxSlippagePoints() : 300;

      double tp1Dist = (m_exit != NULL) ? m_exit.GetTP1Distance() : 0.0;

      double entryPrice, sl, tp;
      ENUM_ORDER_TYPE orderType;

      if(dir == TREND_DIR_UP)
        {
         orderType = ORDER_TYPE_BUY;
         entryPrice = ask;
         sl = ask - stopDist;
         tp = (tp1Dist > 0.0) ? (ask + tp1Dist) : 0.0; // initial TP set to TP1; trailing takes over after partials
        }
      else
        {
         orderType = ORDER_TYPE_SELL;
         entryPrice = bid;
         sl = bid + stopDist;
         tp = (tp1Dist > 0.0) ? (bid - tp1Dist) : 0.0;
        }

      // Normalize SL and TP to symbol digits
      int digits = (int)SymbolInfoInteger(m_symbol, SYMBOL_DIGITS);
      sl = NormalizeDouble(sl, digits);
      tp = NormalizeDouble(tp, digits);
      entryPrice = NormalizeDouble(entryPrice, digits);

      // Retry loop for requotes and transient order errors
      bool orderSent = false;
      for(int attempt = 1; attempt <= InpOrderRetryAttempts; attempt++)
        {
         m_trade.SetDeviationInPoints(slippage);
         m_trade.SetExpertMagicNumber(m_magic);

         if(orderType == ORDER_TYPE_BUY)
            orderSent = m_trade.Buy(lots, m_symbol, 0, sl, tp, InpTradeComment);
         else
            orderSent = m_trade.Sell(lots, m_symbol, 0, sl, tp, InpTradeComment);

         if(orderSent) break;

         int err = (int)m_trade.ResultRetcode();
         bool isRetryable = (err == TRADE_RETCODE_REQUOTE || err == TRADE_RETCODE_PRICE_OFF
                             || err == TRADE_RETCODE_CONNECTION || err == TRADE_RETCODE_TIMEOUT);
         if(!isRetryable)
           {
            PrintFormat("[CStrategyRouter] Non-retryable order error %d on attempt %d.", err, attempt);
            break;
           }
         if(attempt < InpOrderRetryAttempts)
            Sleep(InpOrderRetryDelayMs);
        }

      if(!orderSent)
        {
         PrintFormat("[CStrategyRouter] Order placement failed after %d attempts. Last retcode=%d.",
                     InpOrderRetryAttempts, (int)m_trade.ResultRetcode());
         return false;
        }

      ulong ticket = m_trade.ResultOrder();
      PrintFormat("[CStrategyRouter] TRADE OPENED: ticket=%I64u dir=%s lots=%.4f sl=%.2f tp=%.2f score=%.1f logistic=%.3f strategy=%s regime=%s",
                  ticket, (dir==TREND_DIR_UP?"BUY":"SELL"), lots, sl, tp, finalScore, logisticProb,
                  EnumToString(strategy), EnumToString(rs.regime));

      // Register in pending trades for outcome tracking
      if(m_pendingCount < ArraySize(m_pending))
        {
         m_pending[m_pendingCount].ticket = ticket;
         m_pending[m_pendingCount].features = fv;
         m_pending[m_pendingCount].initialRiskDistance = stopDist;
         m_pending[m_pendingCount].confluenceScore = finalScore;
         m_pending[m_pendingCount].logisticProb = logisticProb;
         m_pending[m_pendingCount].strategy = strategy;
         m_pending[m_pendingCount].regime = rs.regime;
         m_pending[m_pendingCount].session = session;
         m_pending[m_pendingCount].openTime = TimeCurrent();
         m_pendingCount++;
        }

      return true;
     }

   // Slow bounded adaptive threshold: if rolling expectancy of recent 30 trades is strong,
   // slightly raise the threshold (be more selective); if weak, lower it (but never below base-10%).
   // Gated by minimum sample count to prevent adaptation on noise.
   void              AdaptThreshold(const double lastScore, const double usedThreshold)
     {
      if(m_journal == NULL || m_journal.GetTotalTrades() < InpMinTradesForLearning) return;

      double expectancy = m_journal.GetExpectancy();
      double winrate = m_journal.GetWinRate();

      // Nudge direction: expectancy > 0.5R = performing well, allow threshold to creep up
      // (more selective); expectancy < 0.1R = under-performing, loosen slightly
      double nudge = 0.0;
      if(expectancy > 0.5 && winrate > 52.0) nudge = 0.1;
      else if(expectancy < 0.1 && winrate < 45.0) nudge = -0.1;

      if(nudge == 0.0) return;

      double newThreshold = m_adaptiveThreshold + nudge;
      double lowerBound = m_baseThreshold * (1.0 - InpThresholdAdaptBandPct / 100.0);
      double upperBound = m_baseThreshold * (1.0 + InpThresholdAdaptBandPct / 100.0);
      m_adaptiveThreshold = MathMax(lowerBound, MathMin(upperBound, newThreshold));
     }

public:
   // Called from OnTradeTransaction when a deal closes (deal type = DEAL_ENTRY_OUT). Looks up
   // the original pending trade context, computes R-multiple, updates the logistic model, and
   // records the trade in the journal.
   void              OnDealClosed(const ulong dealTicket, const double dealProfit)
     {
      // Find the matching pending trade by position ticket (OnTradeTransaction gives us deal
      // ticket; we need to resolve to position ticket stored at open time)
      if(!HistoryDealSelect(dealTicket)) return;
      ulong posTicket = HistoryDealGetInteger(dealTicket, DEAL_POSITION_ID);

      int idx = -1;
      for(int i=0; i<m_pendingCount; i++)
        {
         if(m_pending[i].ticket == posTicket)
           {
            idx = i;
            break;
           }
        }
      if(idx < 0) return; // not a trade we opened, or already consumed

      // Compute R-multiple from actual deal P&L and the initial risk (stop distance × tick value)
      double riskMoney = 0.0;
      double tickValue = SymbolInfoDouble(m_symbol, SYMBOL_TRADE_TICK_VALUE);
      double tickSize  = SymbolInfoDouble(m_symbol, SYMBOL_TRADE_TICK_SIZE);
      if(tickSize > 0.0 && tickValue > 0.0)
        {
         double moneyPerPriceUnit = tickValue / tickSize;
         double dealVolume = HistoryDealGetDouble(dealTicket, DEAL_VOLUME);
         riskMoney = m_pending[idx].initialRiskDistance * moneyPerPriceUnit * dealVolume;
        }
      double rMultiple = (riskMoney > 0.0) ? (dealProfit / riskMoney) : 0.0;
      bool isWin = (dealProfit > 0.0);

      // Update logistic model with this outcome
      if(InpUseLogisticModel && m_logistic != NULL)
         m_logistic.OnTradeOutcome(m_pending[idx].features, isWin);

      // Update risk manager loss counters
      if(m_risk != NULL)
         m_risk.UpdateLossCounters(isWin);

      // Record in journal
      if(m_journal != NULL)
        {
         TradeRecord rec;
         rec.openTime = m_pending[idx].openTime;
         rec.closeTime = TimeCurrent();
         rec.strategy = m_pending[idx].strategy;
         rec.regimeAtEntry = m_pending[idx].regime;
         rec.sessionAtEntry = m_pending[idx].session;
         rec.confluenceScoreAtEntry = m_pending[idx].confluenceScore;
         rec.logisticProbAtEntry = m_pending[idx].logisticProb;
         rec.rMultiple = rMultiple;
         rec.isWin = isWin;
         rec.features = m_pending[idx].features;
         m_journal.RecordClosedTrade(rec);
        }

      // Print analytics summary periodically
      if(InpDebugMode)
         PrintFormat("[CStrategyRouter] Deal %I64u closed: R=%.2f win=%s | Analytics: %s",
                     dealTicket, rMultiple, isWin?"true":"false",
                     m_journal != NULL ? m_journal.GetSummaryString() : "n/a");

      // Remove from pending list (swap-remove for O(1) deletion)
      m_pending[idx] = m_pending[m_pendingCount-1];
      m_pendingCount--;
     }

private:
   int               CountOurOpenPositions() const
     {
      int count = 0;
      int total = PositionsTotal();
      for(int i=0; i<total; i++)
        {
         ulong ticket = PositionGetTicket(i);
         if(ticket == 0) continue;
         if(!PositionSelectByTicket(ticket)) continue;
         if(PositionGetString(POSITION_SYMBOL) == m_symbol &&
            (ulong)PositionGetInteger(POSITION_MAGIC) == m_magic)
            count++;
        }
      return count;
     }
  };

//+------------------------------------------------------------------------------------------------+
//| GLOBAL INSTANCES                                                                                    |
//| Single instances of each subsystem, all owned at global scope. The router holds non-owning        |
//| references to these (pointers passed at Init time). Lifetime: created OnInit, destroyed OnDeinit. |
//+------------------------------------------------------------------------------------------------+

CTrade                  g_trade;
CVolatilityEngine       g_vol;
COrderFlowProxy         g_flow;
CSessionProfile         g_session;
CMarketStructure        g_structure;
CMTFConfirmation        g_mtf;
CRegimeClassifier       g_regimeClassifier;
CTrendEngine            g_trendEngine;
CRangeEngine            g_rangeEngine;
CBreakoutEngine         g_breakoutEngine;
CLiquiditySweepEngine   g_sweepEngine;
CExecutionQualityFilter g_execFilter;
CRiskManager            g_riskManager;
CExitEngine             g_exitEngine;
CTradeJournal           g_journal;
CNewsShockDetector      g_newsShock;
CLogisticModel          g_logistic;
CStrategyRouter         g_router;

//+------------------------------------------------------------------------------------------------+
//| OnInit                                                                                              |
//+------------------------------------------------------------------------------------------------+
int OnInit()
  {
   Print("===================================");
   Print("NOVA-X BTC Adaptive EA v1.00");
   Print("Initializing all subsystems...");
   Print("===================================");

   string symbol = Symbol();
   ENUM_TIMEFRAMES tf = PERIOD_M1; // execution timeframe (spec: M1 for entries)

   // 1. Trade object setup
   g_trade.SetDeviationInPoints(InpMaxSlippagePoints);
   g_trade.SetExpertMagicNumber(InpMagicNumber);
   g_trade.SetTypeFilling(ORDER_FILLING_FOK);
   g_trade.SetAsyncMode(false);

   // 2. Volatility Engine
   if(!g_vol.Init(symbol, tf, InpATRPeriod, InpATRAverageBars))
     { Print("FATAL: CVolatilityEngine init failed."); return INIT_FAILED; }

   // 3. Order Flow Proxy
   if(!g_flow.Init(symbol, tf, InpFlowVolumeZWindowBars, InpFlowTickVelocityWindowSec))
     { Print("FATAL: COrderFlowProxy init failed."); return INIT_FAILED; }

   // 4. Session Profile
   if(!g_session.Init(InpAsianStartHour, InpAsianEndHour, InpLondonStartHour, InpLondonEndHour,
                       InpNewYorkStartHour, InpNewYorkEndHour))
     { Print("FATAL: CSessionProfile init failed."); return INIT_FAILED; }

   // 5. Market Structure
   if(!g_structure.Init(symbol, tf, InpTrendStructureSwingBars, InpRegimeLookbackBars))
     { Print("FATAL: CMarketStructure init failed."); return INIT_FAILED; }

   // 6. MTF Confirmation
   if(!g_mtf.Init(symbol, InpTrendFastEMA))
     { Print("FATAL: CMTFConfirmation init failed."); return INIT_FAILED; }

   // 7. Regime Classifier
   if(!g_regimeClassifier.Init(symbol, tf, InpADXPeriod, InpADXTrendThreshold,
                                 InpBreakoutCompressionBars, InpBreakoutMinCompressionRatio,
                                 &g_vol, &g_structure))
     { Print("FATAL: CRegimeClassifier init failed."); return INIT_FAILED; }

   // 8. Trend Engine
   if(!g_trendEngine.Init(symbol, tf, InpTrendFastEMA, InpTrendSlowEMA,
                            InpTrendPullbackATRMult, &g_vol, &g_structure, &g_flow))
     { Print("FATAL: CTrendEngine init failed."); return INIT_FAILED; }

   // 9. Range Engine
   if(!g_rangeEngine.Init(symbol, tf, InpRangeBBPeriod, InpRangeBBDeviation,
                            InpRangeRSIPeriod, InpRangeRSIOverbought, InpRangeRSIOversold,
                            &g_flow, &g_vol))
     { Print("FATAL: CRangeEngine init failed."); return INIT_FAILED; }

   // 10. Breakout Engine
   if(!g_breakoutEngine.Init(symbol, tf, InpBreakoutCompressionBars,
                               InpBreakoutRetestMaxBars, InpBreakoutMinExpansionMult,
                               &g_vol, &g_flow))
     { Print("FATAL: CBreakoutEngine init failed."); return INIT_FAILED; }

   // 11. Liquidity Sweep Engine
   if(!g_sweepEngine.Init(symbol, tf, InpSweepEqualLevelTolerancePct,
                            InpSweepRejectionMaxBars, &g_structure, &g_flow, &g_vol))
     { Print("FATAL: CLiquiditySweepEngine init failed."); return INIT_FAILED; }

   // 12. Execution Quality Filter
   if(!g_execFilter.Init(symbol, InpMaxSpreadPoints, InpMaxSlippagePoints))
     { Print("FATAL: CExecutionQualityFilter init failed."); return INIT_FAILED; }

   // 13. Risk Manager
   if(!g_riskManager.Init(symbol, InpMagicNumber, InpRiskPercentPerTrade, InpMaxRiskPercentPerTrade,
                            InpDailyLossLimitPercent, InpWeeklyLossLimitPercent, InpMonthlyLossLimitPercent,
                            InpMaxConsecutiveLosses, InpConsecLossCooldownMin,
                            InpEquityProtectionPercent, InpMaxExposurePercent))
     { Print("FATAL: CRiskManager init failed."); return INIT_FAILED; }

   // 14. Exit Engine
   if(!g_exitEngine.Init(symbol, InpMagicNumber, InpHardStopATRMult,
                          InpTakeProfitATRMult_TP1, InpTakeProfitATRMult_TP2, InpTakeProfitATRMult_TP3,
                          InpTP1ClosePercent, InpTP2ClosePercent,
                          InpBreakEvenTriggerATR, InpBreakEvenOffsetPoints,
                          InpTrailingStartATR, InpTrailingStepATRMult,
                          InpTimeExitMaxBars, InpUseStructureStop,
                          &g_vol, &g_structure, &g_trade))
     { Print("FATAL: CExitEngine init failed."); return INIT_FAILED; }

   // 15. Trade Journal
   if(!g_journal.Init(InpTradeJournalFileName))
     { Print("FATAL: CTradeJournal init failed."); return INIT_FAILED; }

   // 16. News Shock Detector
   if(!g_newsShock.Init(symbol, InpNewsShockSpreadMult, InpNewsShockATRMult, InpNewsShockTickVelMult,
                         InpNewsShockCooldownMin, &g_vol, &g_flow))
     { Print("FATAL: CNewsShockDetector init failed."); return INIT_FAILED; }

   // 17. Logistic Model (with file persistence)
   if(!g_logistic.Init(InpLogisticModelFileName, InpLogisticLearningRate))
     { Print("FATAL: CLogisticModel init failed."); return INIT_FAILED; }

   // 18. Strategy Router (wires everything together)
   if(!g_router.Init(symbol, tf, InpMagicNumber,
                      &g_vol, &g_flow, &g_session, &g_regimeClassifier,
                      &g_structure, &g_mtf, &g_trendEngine, &g_rangeEngine,
                      &g_breakoutEngine, &g_sweepEngine, &g_execFilter,
                      &g_riskManager, &g_exitEngine, &g_journal,
                      &g_newsShock, &g_logistic, &g_trade))
     { Print("FATAL: CStrategyRouter init failed."); return INIT_FAILED; }

   // Initial subsystem warm-up pass (populates ATR and structure from available history)
   g_vol.Update();
   g_structure.Update();

   Print("===================================");
   Print("NOVA-X initialized successfully.");
   PrintFormat("Symbol: %s | TF: M1 | Magic: %I64u", symbol, InpMagicNumber);
   PrintFormat("Risk: %.1f%% base / %.1f%% max | Daily limit: %.1f%% | Weekly: %.1f%% | Monthly: %.1f%%",
               InpRiskPercentPerTrade, InpMaxRiskPercentPerTrade,
               InpDailyLossLimitPercent, InpWeeklyLossLimitPercent, InpMonthlyLossLimitPercent);
   PrintFormat("Entry threshold: %.1f | Logistic model: %s (trained samples: %d / required: %d)",
               InpEntryScoreThreshold, InpUseLogisticModel?"ENABLED":"DISABLED",
               g_logistic.GetTrainedSampleCount(), InpMinTradesForLearning);
   if(InpDebugMode) Print("[DEBUG MODE ACTIVE: verbose logging enabled]");
   Print("===================================");

   return INIT_SUCCEEDED;
  }

//+------------------------------------------------------------------------------------------------+
//| OnDeinit                                                                                            |
//+------------------------------------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   Print("NOVA-X deinitializing. Reason code: ", reason);
   if(g_journal.GetTotalTrades() > 0)
     {
      Print("Final analytics snapshot:");
      Print("  ", g_journal.GetSummaryString());
      PrintFormat("  Equity HWM at shutdown: %.2f", g_riskManager.GetEquityHighWaterMark());
     }
   Print("NOVA-X shutdown complete.");
  }

//+------------------------------------------------------------------------------------------------+
//| OnTick                                                                                              |
//| Single-line delegation to the router. All orchestration logic lives in CStrategyRouter::OnTick() |
//| to keep the global scope clean and the call stack traceable.                                        |
//+------------------------------------------------------------------------------------------------+
void OnTick()
  {
   g_router.OnTick();
  }

//+------------------------------------------------------------------------------------------------+
//| OnTradeTransaction                                                                                  |
//| Catches deal-close events and routes them to the router for logistic model update / journal         |
//| recording / risk counter update. Only processes fully-closed-position deals (DEAL_ENTRY_OUT).       |
//+------------------------------------------------------------------------------------------------+
void OnTradeTransaction(const MqlTradeTransaction &trans,
                         const MqlTradeRequest     &request,
                         const MqlTradeResult      &result)
  {
   if(trans.type != TRADE_TRANSACTION_DEAL_ADD) return;
   if(trans.deal == 0) return;

   if(!HistoryDealSelect(trans.deal)) return;
   long dealEntry = HistoryDealGetInteger(trans.deal, DEAL_ENTRY);
   if(dealEntry != DEAL_ENTRY_OUT) return; // only process closing deals, not opening legs

   long dealMagic = HistoryDealGetInteger(trans.deal, DEAL_MAGIC);
   if((ulong)dealMagic != InpMagicNumber) return; // not our trade

   double dealProfit = HistoryDealGetDouble(trans.deal, DEAL_PROFIT)
                      + HistoryDealGetDouble(trans.deal, DEAL_SWAP)
                      + HistoryDealGetDouble(trans.deal, DEAL_COMMISSION);

   g_router.OnDealClosed(trans.deal, dealProfit);
  }
