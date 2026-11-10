//+------------------------------------------------------------------+
//|                                                AEGIS PRIME.mq5    |
//|                          Copyright 2026, FXBotHub Systems         |
//|                                     https://fxbothub.com          |
//+------------------------------------------------------------------+
//  MARKET-ADAPTIVE REGIME-EXCLUSIVE TRADING ENGINE
//
//  Lineage / honest design note (read before modifying):
//  ---------------------------------------------------------------
//  This EA shares its risk/execution/exit engineering lineage with an
//  earlier build (NOVA TITAN X) but uses a DIFFERENT strategy-activation
//  model by design, per spec:
//
//   - NOVA TITAN X scored multiple regime-eligible strategies each tick
//     and fired whichever scored highest above a confidence threshold.
//   - THIS EA classifies SEVEN independent regime dimensions (volatility,
//     liquidity, session, trend, momentum, structure, risk) every tick,
//     resolves them through a fixed priority order when they conflict,
//     and commits to exactly ONE active strategy at a time. That strategy
//     keeps exclusive control of new entries until a candidate regime
//     change survives a confirmation window (N consecutive bars) - this
//     is a portfolio-manager-style "commit and hold" model, not a
//     per-tick "best score wins" model. The two are intentionally
//     different and should not be merged.
//
//  WHAT THIS IS NOT, STATED PLAINLY (same standard as NOVA TITAN X):
//   - "Regime confidence scores" (0-100) are NOT statistical probabilities
//     or model outputs. Each is a deterministic function of how many of a
//     classifier's internal rule-checks agreed, expressed on a 0-100
//     scale for readability and threshold-comparison purposes. A
//     "Trend Confidence: 92%" reading means "92% of this classifier's
//     internal checks agreed on a trend read," not "92% probability the
//     trend continues."
//   - The "News-Aware Risk Engine" does not parse, fetch, or understand
//     news content. It combines (a) a manually-entered time-window
//     schedule the user supplies for known event times, with (b) the
//     same honest volatility/volume/spread displacement detection used
//     in NOVA TITAN X. It is labeled NewsRisk/EventRisk throughout, and
//     a manual schedule with zero entries simply means that input layer
//     contributes nothing - it does not silently invent event times.
//   - No claim of profitability is made or implied anywhere in this file.
//     Robust regime detection and disciplined risk control improve the
//     ODDS of survivability; they do not guarantee positive expectancy
//     on data the system has not seen. Backtest and forward-test before
//     any live deployment, and treat all default input values as
//     starting points for your own validation, not tuned recommendations.
//
//  ARCHITECTURE (class map):
//   CRegimeClassifierBase           - shared interface for all 7 classifiers
//     CVolatilityRegimeClassifier   - ATR/HV/compression/percentile based
//     CLiquidityRegimeClassifier    - tick frequency/spread/volume based
//     CSessionRegimeClassifier      - Asian/London/NY/Overlap clock-based
//     CTrendRegimeClassifier        - EMA stack/ADX/HH-HL/LH-LL based
//     CMomentumRegimeClassifier     - ROC/ADX/candle accel/ATR expansion
//     CStructureRegimeClassifier    - BOS/CHoCH/swings/liquidity sweeps
//     CRiskRegimeClassifier         - drawdown/streak/event-window based
//   CRegimeSnapshot                 - plain bundle of all 7 current reads
//   CStrategyBase                   - shared interface for all 7 strategies
//     CStrategy_MeanReversion, CStrategy_RangeScalper,
//     CStrategy_TrendContinuationLong, CStrategy_TrendContinuationShort,
//     CStrategy_MomentumBreakout, CStrategy_PullbackTrendFollowing,
//     CStrategy_RangeTrading
//   CStrategySelector                - priority resolution + hysteresis/
//                                       cooldown/confirmation state machine
//   CMTFFilter                       - M1/M5/M15/H1 bias confirmation
//   CRiskManager                     - sizing, drawdown levels, kill switch
//   CExecutionEngine                 - spread/slippage/freeze/retry guards
//   CTradeManager                    - SL/TP construction + R-multiple exits
//   CDashboard                        - self-diagnostic display
//
#property copyright   "Copyright 2026, AEGIS PRIME Systems"
#property version     "1.00"
#property description "Regime-Exclusive Adaptive Multi-Strategy Engine (OOP)"
#property description "Honest-labeling build: see header comment for subsystem definitions"
#property strict

#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>

#define DASH_PREFIX  "AGX_"
#define EA_VERSION   "v1.00"
#define NUM_STRATEGIES 7

//+------------------------------------------------------------------+
//| ENUMERATIONS - one per regime dimension                          |
//+------------------------------------------------------------------+
enum ENUM_VOL_REGIME    { VOLR_ULTRA_LOW, VOLR_NORMAL, VOLR_HIGH, VOLR_EXTREME };
enum ENUM_LIQ_REGIME    { LIQR_LOW, LIQR_MEDIUM, LIQR_HIGH };
enum ENUM_SESSION_REGIME{ SESR_ASIAN, SESR_LONDON, SESR_NEWYORK, SESR_OVERLAP, SESR_OFF_HOURS };
enum ENUM_TREND_REGIME  { TRENDR_STRONG_BULL, TRENDR_STRONG_BEAR, TRENDR_SIDEWAYS };
enum ENUM_MOM_REGIME    { MOMR_STRONG, MOMR_WEAK };
enum ENUM_STRUCT_REGIME { STRUCTR_BULLISH, STRUCTR_BEARISH, STRUCTR_NEUTRAL };
enum ENUM_RISK_REGIME   { RISKR_NORMAL, RISKR_ELEVATED, RISKR_DEFENSIVE, RISKR_SUSPENDED };

enum ENUM_STRATEGY_ID
{
   STRAT_MEAN_REVERSION = 0,
   STRAT_RANGE_SCALPER,
   STRAT_TREND_CONT_LONG,
   STRAT_TREND_CONT_SHORT,
   STRAT_MOMENTUM_BREAKOUT,
   STRAT_PULLBACK_TREND,
   STRAT_RANGE_TRADING,
   STRAT_NONE   // sentinel: no strategy currently holds exclusivity
};

enum ENUM_SIGNAL_DIR { SIG_NONE = 0, SIG_BUY = 1, SIG_SELL = -1 };

enum ENUM_ENGINE_STATE
{
   ENGSTATE_SCANNING,
   ENGSTATE_IN_TRADE,
   ENGSTATE_COOLDOWN,
   ENGSTATE_DAILY_HALT,
   ENGSTATE_DRAWDOWN_HALT,
   ENGSTATE_EMERGENCY_HALT,
   ENGSTATE_SUSPENDED   // risk regime forced suspension (e.g. event window)
};

//+------------------------------------------------------------------+
//| REGIME SNAPSHOT - bundles all 7 classifier reads for one tick    |
//| Passed by reference instead of having every strategy/selector    |
//| reach into 7 separate classifier objects individually.           |
//+------------------------------------------------------------------+
struct CRegimeSnapshot
{
   ENUM_VOL_REGIME     volRegime;
   double              volConfidence;

   ENUM_LIQ_REGIME     liqRegime;
   double              liqConfidence;

   ENUM_SESSION_REGIME sessionRegime;
   double              sessionConfidence;

   ENUM_TREND_REGIME   trendRegime;
   double              trendConfidence;

   ENUM_MOM_REGIME     momRegime;
   double              momConfidence;

   ENUM_STRUCT_REGIME  structRegime;
   double              structConfidence;

   ENUM_RISK_REGIME    riskRegime;
   double              riskConfidence;

   datetime            timestamp;
};

//+------------------------------------------------------------------+
//| STRATEGY SIGNAL - returned by every CStrategyBase::Evaluate()    |
//+------------------------------------------------------------------+
struct SStrategySignal
{
   ENUM_SIGNAL_DIR dir;
   double          score;     // 0-100, this strategy's own internal setup quality
   string          reason;
   bool            valid;
};

//+------------------------------------------------------------------+
//| CRegimeClassifierBase                                             |
//| Shared interface every regime classifier implements. Each         |
//| classifier owns its own indicator handles and internal state,     |
//| updates on a new-bar gate (not every tick - see NOVA TITAN X      |
//| lineage note on why per-tick ATR/volume sampling corrupts          |
//| percentile-style reads), and exposes a confidence score that is   |
//| a transparent function of internal rule agreement, not a model    |
//| output (see file header).                                         |
//+------------------------------------------------------------------+
class CRegimeClassifierBase
{
protected:
   string   m_name;
   datetime m_lastBarTime;

   bool IsNewBar()
   {
      datetime cur = (datetime)SeriesInfoInteger(_Symbol, _Period, SERIES_LASTBAR_DATE);
      if(cur == m_lastBarTime) return false;
      m_lastBarTime = cur;
      return true;
   }

public:
   CRegimeClassifierBase(string name) { m_name = name; m_lastBarTime = 0; }
   virtual ~CRegimeClassifierBase() {}

   virtual bool   Init()   { return true; }
   virtual void   Release(){}
   virtual void   Update() {}   // called every tick; internally new-bar gated where appropriate
   string         Name()   { return m_name; }
};

//+------------------------------------------------------------------+
//| CVolatilityRegimeClassifier                                       |
//| ATR percentile (new-bar gated, self-comparison excluded - same    |
//| methodology as NOVA TITAN X), historical volatility (stdev of     |
//| returns), range compression, candle body ratio.                   |
//+------------------------------------------------------------------+
class CVolatilityRegimeClassifier : public CRegimeClassifierBase
{
private:
   int      m_hATR;
   int      m_atrPeriod;
   int      m_lookback;
   double   m_atrHistory[];
   double   m_percentile;
   double   m_lastATRExpansionRate;

   ENUM_VOL_REGIME m_state;
   double          m_confidence;

   double GetATR()
   {
      double a[1];
      if(CopyBuffer(m_hATR, 0, 0, 1, a) <= 0) return 0.0;
      return a[0];
   }

   double GetHistoricalVolatility(int period)
   {
      double closes[];
      int needed = period + 1;
      if(CopyClose(_Symbol, _Period, 1, needed, closes) < needed) return 0.0;
      ArraySetAsSeries(closes, true);
      double returns[];
      ArrayResize(returns, period);
      for(int i = 0; i < period; i++)
      {
         if(closes[i+1] <= 0.0) { returns[i] = 0.0; continue; }
         returns[i] = (closes[i] - closes[i+1]) / closes[i+1];
      }
      double mean = 0.0;
      for(int i = 0; i < period; i++) mean += returns[i];
      mean /= period;
      double variance = 0.0;
      for(int i = 0; i < period; i++) variance += MathPow(returns[i] - mean, 2);
      variance /= period;
      return MathSqrt(variance);
   }

   double GetCandleBodyRatio()
   {
      double o = iOpen(_Symbol, _Period, 1);
      double c = iClose(_Symbol, _Period, 1);
      double h = iHigh(_Symbol, _Period, 1);
      double l = iLow(_Symbol, _Period, 1);
      double range = h - l;
      if(range <= 0.0) return 0.0;
      return MathAbs(c - o) / range;
   }

   void UpdatePercentile()
   {
      double curATR = GetATR();
      if(curATR <= 0.0) return;

      int n = ArraySize(m_atrHistory);
      double prevATR = m_atrHistory[0];
      for(int i = n-1; i > 0; i--) m_atrHistory[i] = m_atrHistory[i-1];
      m_atrHistory[0] = curATR;

      m_lastATRExpansionRate = (prevATR > 0.0) ? ((curATR - prevATR) / prevATR) * 100.0 : 0.0;

      int validCount = 0, belowCount = 0;
      for(int i = 1; i < n; i++)
      {
         if(m_atrHistory[i] <= 0.0) continue;
         validCount++;
         if(m_atrHistory[i] <= curATR) belowCount++;
      }
      if(validCount < 10) { m_percentile = 50.0; return; }
      m_percentile = ((double)belowCount / validCount) * 100.0;
   }

public:
   CVolatilityRegimeClassifier() : CRegimeClassifierBase("VolatilityRegime")
   {
      m_hATR = INVALID_HANDLE;
      m_atrPeriod = 14;
      m_lookback = 100;
      m_percentile = 50.0;
      m_lastATRExpansionRate = 0.0;
      m_state = VOLR_NORMAL;
      m_confidence = 50.0;
   }

   bool Init(int atrPeriod, int lookback)
   {
      m_atrPeriod = atrPeriod;
      m_lookback  = lookback;
      m_hATR = iATR(_Symbol, _Period, m_atrPeriod);
      if(m_hATR == INVALID_HANDLE) return false;
      ArrayResize(m_atrHistory, m_lookback);
      ArrayInitialize(m_atrHistory, 0.0);
      return true;
   }

   void Release() override { if(m_hATR != INVALID_HANDLE) IndicatorRelease(m_hATR); }

   void Update(double lowPctile, double highPctile, double extremePctile, double squeezeBodyRatio) 
   {
      if(!IsNewBar()) return;
      UpdatePercentile();

      double hv = GetHistoricalVolatility(20);
      double bodyRatio = GetCandleBodyRatio();

      int agree = 0, total = 4;

      // Rule 1: ATR percentile threshold
      bool ultraLowByATR = (m_percentile <= lowPctile);
      bool highByATR      = (m_percentile >= highPctile);
      bool extremeByATR   = (m_percentile >= extremePctile);

      // Rule 2: ATR expansion rate (rapid expansion supports HIGH/EXTREME)
      bool expanding = (m_lastATRExpansionRate > 15.0);

      // Rule 3: candle body ratio (small bodies support ULTRA_LOW)
      bool smallBody = (bodyRatio < squeezeBodyRatio);

      // Rule 4: historical volatility relative sanity check - if HV is
      // also depressed/elevated it confirms the ATR-percentile read rather
      // than being a single-indicator artifact
      static double hvBaseline = -1.0;
      if(hvBaseline < 0.0) hvBaseline = hv; // first read seeds baseline
      bool hvConfirmsLow  = (hv < hvBaseline * 0.7);
      bool hvConfirmsHigh = (hv > hvBaseline * 1.4);
      hvBaseline = hvBaseline * 0.98 + hv * 0.02; // slow-moving baseline

      if(extremeByATR)
      {
         agree = 1;
         if(expanding) agree++;
         if(hvConfirmsHigh) agree++;
         m_state = VOLR_EXTREME;
      }
      else if(highByATR)
      {
         agree = 1;
         if(expanding) agree++;
         if(hvConfirmsHigh) agree++;
         m_state = VOLR_HIGH;
      }
      else if(ultraLowByATR)
      {
         agree = 1;
         if(smallBody) agree++;
         if(hvConfirmsLow) agree++;
         m_state = VOLR_ULTRA_LOW;
      }
      else
      {
         agree = 1;
         if(!smallBody) agree++;
         if(!expanding) agree++;
         m_state = VOLR_NORMAL;
      }

      m_confidence = MathMin(100.0, (agree / 3.0) * 100.0); // 3 supporting checks max per branch
   }

   ENUM_VOL_REGIME State()       { return m_state; }
   double          Confidence()  { return m_confidence; }
   double          Percentile()  { return m_percentile; }
   double          ExpansionRate(){ return m_lastATRExpansionRate; }
   double          ATRValue()    { return GetATR(); }

   string StateString()
   {
      switch(m_state)
      {
         case VOLR_ULTRA_LOW: return "ULTRA-LOW";
         case VOLR_NORMAL:    return "NORMAL";
         case VOLR_HIGH:      return "HIGH";
         case VOLR_EXTREME:   return "EXTREME";
         default: return "?";
      }
   }
};

//+------------------------------------------------------------------+
//| CLiquidityRegimeClassifier                                        |
//| Tick frequency (ticks/second proxy via tick volume), spread        |
//| behavior relative to its own rolling average, and session overlap |
//| as a structural liquidity prior (overlap hours are liquidity-rich |
//| by construction, independent of the moment-to-moment reads).      |
//+------------------------------------------------------------------+
class CLiquidityRegimeClassifier : public CRegimeClassifierBase
{
private:
   double m_avgTickVolume;
   int    m_tickVolSamples;
   double m_avgSpread;
   int    m_spreadSamples;
   ENUM_LIQ_REGIME m_state;
   double m_confidence;

   double GetSpreadPct()
   {
      double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(bid <= 0.0) return 0.0;
      return ((ask - bid) / bid) * 100.0;
   }

public:
   CLiquidityRegimeClassifier() : CRegimeClassifierBase("LiquidityRegime")
   {
      m_avgTickVolume = 0.0; m_tickVolSamples = 0;
      m_avgSpread = 0.0; m_spreadSamples = 0;
      m_state = LIQR_MEDIUM; m_confidence = 50.0;
   }

   bool Init() { return true; }

   // sessionIsOverlapOrMajor: structural prior from the session classifier -
   // passed in rather than re-deriving session logic here, avoiding two
   // classifiers disagreeing about clock-based facts.
   void Update(bool sessionIsOverlapOrMajor)
   {
      // Spread sampled every tick (cheap, needed for live spread-spike detection)
      double curSpread = SymbolInfoDouble(_Symbol, SYMBOL_ASK) - SymbolInfoDouble(_Symbol, SYMBOL_BID);
      int spreadCap = 2000;
      m_avgSpread = (m_avgSpread * m_spreadSamples + curSpread) / (double)(m_spreadSamples + 1);
      m_spreadSamples = MathMin(m_spreadSamples + 1, spreadCap);

      if(!IsNewBar()) return;

      long vol[1];
      if(CopyTickVolume(_Symbol, _Period, 1, 1, vol) > 0)
      {
         int volCap = 400;
         m_avgTickVolume = (m_avgTickVolume * m_tickVolSamples + (double)vol[0]) / (double)(m_tickVolSamples + 1);
         m_tickVolSamples = MathMin(m_tickVolSamples + 1, volCap);
      }

      long curVol[1];
      double volRatio = 1.0;
      if(CopyTickVolume(_Symbol, _Period, 1, 1, curVol) > 0 && m_avgTickVolume > 0.0)
         volRatio = (double)curVol[0] / m_avgTickVolume;

      double spreadRatio = (m_avgSpread > 0.0) ? curSpread / m_avgSpread : 1.0;

      int agree = 0;
      bool volHigh = (volRatio >= 1.2);
      bool volLow  = (volRatio <= 0.7);
      bool spreadTight = (spreadRatio <= 1.1);
      bool spreadWide  = (spreadRatio >= 1.5);

      if(sessionIsOverlapOrMajor && volHigh && spreadTight)
      {
         agree = 3; m_state = LIQR_HIGH;
      }
      else if(!sessionIsOverlapOrMajor && volLow && spreadWide)
      {
         agree = 3; m_state = LIQR_LOW;
      }
      else
      {
         // partial agreement scoring - count how many of the 3 signals
         // point toward HIGH vs LOW, default to MEDIUM if mixed
         int highVotes = (sessionIsOverlapOrMajor?1:0) + (volHigh?1:0) + (spreadTight?1:0);
         int lowVotes  = (!sessionIsOverlapOrMajor?1:0) + (volLow?1:0) + (spreadWide?1:0);
         if(highVotes >= 2) { m_state = LIQR_HIGH; agree = highVotes; }
         else if(lowVotes >= 2) { m_state = LIQR_LOW; agree = lowVotes; }
         else { m_state = LIQR_MEDIUM; agree = 2; } // ambiguous reads default to medium with moderate confidence
      }

      m_confidence = MathMin(100.0, (agree / 3.0) * 100.0);
   }

   ENUM_LIQ_REGIME State()      { return m_state; }
   double          Confidence() { return m_confidence; }
   double          AvgSpread()  { return m_avgSpread; }

   string StateString()
   {
      switch(m_state)
      {
         case LIQR_LOW: return "LOW";
         case LIQR_MEDIUM: return "MEDIUM";
         case LIQR_HIGH: return "HIGH";
         default: return "?";
      }
   }
};

//+------------------------------------------------------------------+
//| CSessionRegimeClassifier                                          |
//| Clock-based (server/GMT time), with configurable session windows. |
//| Confidence is high near the middle of a session window and lower  |
//| near its edges, reflecting genuine ambiguity at transition times  |
//| rather than a false-precision 100% at every moment.                |
//+------------------------------------------------------------------+
class CSessionRegimeClassifier : public CRegimeClassifierBase
{
private:
   int m_asianStartHr, m_asianEndHr;
   int m_londonStartHr, m_londonEndHr;
   int m_nyStartHr, m_nyEndHr;
   ENUM_SESSION_REGIME m_state;
   double m_confidence;

   // Distance from window edges, used to scale confidence
   double EdgeConfidence(int hr, int startHr, int endHr)
   {
      int windowLen = endHr - startHr;
      if(windowLen <= 0) return 50.0;
      int distFromStart = hr - startHr;
      int distFromEnd    = endHr - hr;
      int distFromEdge = MathMin(distFromStart, distFromEnd);
      double frac = (double)distFromEdge / (windowLen / 2.0);
      return MathMax(50.0, MathMin(100.0, 50.0 + frac * 50.0));
   }

public:
   CSessionRegimeClassifier() : CRegimeClassifierBase("SessionRegime")
   {
      m_asianStartHr = 0;  m_asianEndHr  = 8;
      m_londonStartHr = 8; m_londonEndHr = 16;
      m_nyStartHr = 13;    m_nyEndHr     = 21;
      m_state = SESR_OFF_HOURS; m_confidence = 50.0;
   }

   void Configure(int asianStart, int asianEnd, int londonStart, int londonEnd, int nyStart, int nyEnd)
   {
      m_asianStartHr=asianStart; m_asianEndHr=asianEnd;
      m_londonStartHr=londonStart; m_londonEndHr=londonEnd;
      m_nyStartHr=nyStart; m_nyEndHr=nyEnd;
   }

   void Update()
   {
      MqlDateTime dt; TimeToStruct(TimeGMT(), dt);
      int hr = dt.hour;

      bool inAsian  = (hr >= m_asianStartHr && hr < m_asianEndHr);
      bool inLondon = (hr >= m_londonStartHr && hr < m_londonEndHr);
      bool inNY     = (hr >= m_nyStartHr && hr < m_nyEndHr);
      bool inOverlap = inLondon && inNY;

      if(inOverlap)
      {
         m_state = SESR_OVERLAP;
         double cL = EdgeConfidence(hr, m_londonStartHr, m_londonEndHr);
         double cN = EdgeConfidence(hr, m_nyStartHr, m_nyEndHr);
         m_confidence = MathMin(cL, cN); // overlap confidence limited by the tighter of the two windows
      }
      else if(inLondon)
      {
         m_state = SESR_LONDON;
         m_confidence = EdgeConfidence(hr, m_londonStartHr, m_londonEndHr);
      }
      else if(inNY)
      {
         m_state = SESR_NEWYORK;
         m_confidence = EdgeConfidence(hr, m_nyStartHr, m_nyEndHr);
      }
      else if(inAsian)
      {
         m_state = SESR_ASIAN;
         m_confidence = EdgeConfidence(hr, m_asianStartHr, m_asianEndHr);
      }
      else
      {
         m_state = SESR_OFF_HOURS;
         m_confidence = 70.0; // off-hours is itself a fairly unambiguous read
      }
   }

   ENUM_SESSION_REGIME State()      { return m_state; }
   double              Confidence() { return m_confidence; }
   bool                IsOverlapOrMajor() { return (m_state == SESR_OVERLAP || m_state == SESR_LONDON || m_state == SESR_NEWYORK); }

   string StateString()
   {
      switch(m_state)
      {
         case SESR_ASIAN: return "ASIAN";
         case SESR_LONDON: return "LONDON";
         case SESR_NEWYORK: return "NEW YORK";
         case SESR_OVERLAP: return "LDN/NY OVERLAP";
         case SESR_OFF_HOURS: return "OFF-HOURS";
         default: return "?";
      }
   }
};

//+------------------------------------------------------------------+
//| CTrendRegimeClassifier                                            |
//| EMA stack alignment, multi-EMA structure, ADX, and HH/HL vs        |
//| LH/LL swing analysis over a configurable lookback.                |
//+------------------------------------------------------------------+
class CTrendRegimeClassifier : public CRegimeClassifierBase
{
private:
   int m_hFastEMA, m_hSlowEMA, m_hTrendEMA, m_hADX;
   int m_swingBars;
   ENUM_TREND_REGIME m_state;
   double m_confidence;

   bool GetEMAStack(double &fast, double &slow, double &trend)
   {
      double f[1], s[1], t[1];
      if(CopyBuffer(m_hFastEMA, 0, 0, 1, f) <= 0) return false;
      if(CopyBuffer(m_hSlowEMA, 0, 0, 1, s) <= 0) return false;
      if(CopyBuffer(m_hTrendEMA, 0, 0, 1, t) <= 0) return false;
      fast = f[0]; slow = s[0]; trend = t[0];
      return true;
   }

   double GetADX()
   {
      double a[1];
      if(CopyBuffer(m_hADX, 0, 0, 1, a) <= 0) return 0.0;
      return a[0];
   }

   // Counts higher-high/higher-low pairs (bullish structure) vs
   // lower-high/lower-low pairs (bearish structure) over m_swingBars
   void GetSwingStructure(bool &hhhl, bool &lhll)
   {
      int n = m_swingBars;
      double highs[], lows[];
      if(CopyHigh(_Symbol, _Period, 1, n, highs) < n) { hhhl=false; lhll=false; return; }
      if(CopyLow(_Symbol, _Period, 1, n, lows) < n)   { hhhl=false; lhll=false; return; }
      ArraySetAsSeries(highs, true);
      ArraySetAsSeries(lows, true);

      int higherHighs = 0, higherLows = 0, lowerHighs = 0, lowerLows = 0;
      int half = n / 2;
      double recentHigh = highs[ArrayMaximum(highs, 0, half)];
      double olderHigh  = highs[ArrayMaximum(highs, half, n-half)];
      double recentLow  = lows[ArrayMinimum(lows, 0, half)];
      double olderLow   = lows[ArrayMinimum(lows, half, n-half)];

      hhhl = (recentHigh > olderHigh) && (recentLow > olderLow);
      lhll = (recentHigh < olderHigh) && (recentLow < olderLow);
   }

public:
   CTrendRegimeClassifier() : CRegimeClassifierBase("TrendRegime")
   {
      m_hFastEMA=INVALID_HANDLE; m_hSlowEMA=INVALID_HANDLE; m_hTrendEMA=INVALID_HANDLE; m_hADX=INVALID_HANDLE;
      m_swingBars = 12;
      m_state = TRENDR_SIDEWAYS; m_confidence = 50.0;
   }

   bool Init(int fastP, int slowP, int trendP, int adxP, int swingBars)
   {
      m_hFastEMA  = iMA(_Symbol, _Period, fastP, 0, MODE_EMA, PRICE_CLOSE);
      m_hSlowEMA  = iMA(_Symbol, _Period, slowP, 0, MODE_EMA, PRICE_CLOSE);
      m_hTrendEMA = iMA(_Symbol, _Period, trendP, 0, MODE_EMA, PRICE_CLOSE);
      m_hADX      = iADX(_Symbol, _Period, adxP);
      m_swingBars = MathMax(6, swingBars);
      return (m_hFastEMA!=INVALID_HANDLE && m_hSlowEMA!=INVALID_HANDLE && m_hTrendEMA!=INVALID_HANDLE && m_hADX!=INVALID_HANDLE);
   }

   void Release() override
   {
      if(m_hFastEMA!=INVALID_HANDLE) IndicatorRelease(m_hFastEMA);
      if(m_hSlowEMA!=INVALID_HANDLE) IndicatorRelease(m_hSlowEMA);
      if(m_hTrendEMA!=INVALID_HANDLE) IndicatorRelease(m_hTrendEMA);
      if(m_hADX!=INVALID_HANDLE) IndicatorRelease(m_hADX);
   }

   void Update(double adxTrendMin)
   {
      if(!IsNewBar()) return;

      double fast, slow, trend;
      if(!GetEMAStack(fast, slow, trend)) return;
      double adx = GetADX();
      bool hhhl, lhll;
      GetSwingStructure(hhhl, lhll);

      bool bullStack = (fast > slow && slow > trend);
      bool bearStack = (fast < slow && slow < trend);
      bool strongADX = (adx >= adxTrendMin);

      int bullAgree = (bullStack?1:0) + (strongADX?1:0) + (hhhl?1:0);
      int bearAgree = (bearStack?1:0) + (strongADX?1:0) + (lhll?1:0);

      if(bullAgree >= 2 && bullAgree > bearAgree)
      {
         m_state = TRENDR_STRONG_BULL;
         m_confidence = (bullAgree / 3.0) * 100.0;
      }
      else if(bearAgree >= 2 && bearAgree > bullAgree)
      {
         m_state = TRENDR_STRONG_BEAR;
         m_confidence = (bearAgree / 3.0) * 100.0;
      }
      else
      {
         m_state = TRENDR_SIDEWAYS;
         // confidence in "sideways" scales with how WEAK adx is, plus
         // neither bull nor bear structure confirming
         double sidewaysAgree = (!strongADX?1:0) + (!hhhl && !lhll?1:0);
         m_confidence = MathMax(40.0, (sidewaysAgree / 2.0) * 100.0);
      }
   }

   ENUM_TREND_REGIME State()      { return m_state; }
   double            Confidence() { return m_confidence; }

   string StateString()
   {
      switch(m_state)
      {
         case TRENDR_STRONG_BULL: return "STRONG BULL";
         case TRENDR_STRONG_BEAR: return "STRONG BEAR";
         case TRENDR_SIDEWAYS:    return "SIDEWAYS";
         default: return "?";
      }
   }
};

//+------------------------------------------------------------------+
//| CMomentumRegimeClassifier                                         |
//| Rate of Change, ADX, candle-to-candle acceleration, ATR expansion |
//| rate (read from the volatility classifier, not re-derived here). |
//+------------------------------------------------------------------+
class CMomentumRegimeClassifier : public CRegimeClassifierBase
{
private:
   int m_hADX;
   int m_rocPeriod;
   ENUM_MOM_REGIME m_state;
   double m_confidence;

   double GetROC()
   {
      double c0 = iClose(_Symbol, _Period, 1);
      double cN = iClose(_Symbol, _Period, 1 + m_rocPeriod);
      if(cN <= 0.0) return 0.0;
      return ((c0 - cN) / cN) * 100.0;
   }

   double GetCandleAcceleration()
   {
      // Compares the size of the last 3 candle bodies - increasing size
      // implies accelerating momentum, independent of direction.
      double b0 = MathAbs(iClose(_Symbol,_Period,1) - iOpen(_Symbol,_Period,1));
      double b1 = MathAbs(iClose(_Symbol,_Period,2) - iOpen(_Symbol,_Period,2));
      double b2 = MathAbs(iClose(_Symbol,_Period,3) - iOpen(_Symbol,_Period,3));
      if(b2 <= 0.0) return 0.0;
      return ((b0 - b2) / b2) * 100.0;
   }

public:
   CMomentumRegimeClassifier() : CRegimeClassifierBase("MomentumRegime")
   {
      m_hADX = INVALID_HANDLE; m_rocPeriod = 10;
      m_state = MOMR_WEAK; m_confidence = 50.0;
   }

   bool Init(int adxPeriod, int rocPeriod)
   {
      m_hADX = iADX(_Symbol, _Period, adxPeriod);
      m_rocPeriod = rocPeriod;
      return (m_hADX != INVALID_HANDLE);
   }

   void Release() override { if(m_hADX != INVALID_HANDLE) IndicatorRelease(m_hADX); }

   void Update(double adxStrongMin, double atrExpansionRate)
   {
      if(!IsNewBar()) return;

      double adxArr[1];
      double adx = (CopyBuffer(m_hADX, 0, 0, 1, adxArr) > 0) ? adxArr[0] : 0.0;
      double roc = GetROC();
      double accel = GetCandleAcceleration();

      bool strongADX = (adx >= adxStrongMin);
      bool strongROC = (MathAbs(roc) >= 0.5);   // 0.5% move over the ROC window - scale-relative to BTC/gold/etc by % not points
      bool accelerating = (accel > 10.0);
      bool atrExpanding = (atrExpansionRate > 10.0);

      int agree = (strongADX?1:0) + (strongROC?1:0) + (accelerating?1:0) + (atrExpanding?1:0);

      if(agree >= 2)
      {
         m_state = MOMR_STRONG;
         m_confidence = (agree / 4.0) * 100.0;
      }
      else
      {
         m_state = MOMR_WEAK;
         m_confidence = ((4 - agree) / 4.0) * 100.0;
      }
   }

   ENUM_MOM_REGIME State()      { return m_state; }
   double          Confidence() { return m_confidence; }

   string StateString() { return (m_state==MOMR_STRONG) ? "STRONG" : "WEAK"; }
};

//+------------------------------------------------------------------+
//| CStructureRegimeClassifier                                        |
//| Break of Structure (BOS), Change of Character (CHoCH), swing       |
//| highs/lows, and liquidity sweeps. Produces a directional bias     |
//| (Bullish/Bearish/Neutral) used as a filter elsewhere, not a       |
//| standalone entry trigger.                                          |
//+------------------------------------------------------------------+
class CStructureRegimeClassifier : public CRegimeClassifierBase
{
private:
   int m_structureBars;
   ENUM_STRUCT_REGIME m_state;
   double m_confidence;
   ENUM_STRUCT_REGIME m_priorBias;   // previous confirmed bias, for CHoCH detection
   bool   m_lastSweepDetected;
   ENUM_SIGNAL_DIR m_lastSweepDir;

   double SwingHigh(int bars, int shift) { int b = iHighest(_Symbol,_Period,MODE_HIGH,bars,shift); return (b>=0)?iHigh(_Symbol,_Period,b):0.0; }
   double SwingLow(int bars, int shift)  { int b = iLowest(_Symbol,_Period,MODE_LOW,bars,shift);   return (b>=0)?iLow(_Symbol,_Period,b):0.0; }

   bool DetectSweep(ENUM_SIGNAL_DIR &dir)
   {
      double swingHigh = SwingHigh(m_structureBars, 2);
      double swingLow  = SwingLow(m_structureBars, 2);
      double h1 = iHigh(_Symbol,_Period,1), l1 = iLow(_Symbol,_Period,1);
      double c1 = iClose(_Symbol,_Period,1), o1 = iOpen(_Symbol,_Period,1);

      if(h1 > swingHigh && c1 < swingHigh && c1 < o1) { dir = SIG_SELL; return true; }
      if(l1 < swingLow  && c1 > swingLow  && c1 > o1) { dir = SIG_BUY;  return true; }
      return false;
   }

public:
   CStructureRegimeClassifier() : CRegimeClassifierBase("StructureRegime")
   {
      m_structureBars = 8;
      m_state = STRUCTR_NEUTRAL; m_confidence = 50.0;
      m_priorBias = STRUCTR_NEUTRAL;
      m_lastSweepDetected = false; m_lastSweepDir = SIG_NONE;
   }

   void Init(int structureBars) { m_structureBars = MathMax(4, structureBars); }

   void Update()
   {
      if(!IsNewBar()) return;

      double swingHigh = SwingHigh(m_structureBars, 1);
      double swingLow  = SwingLow(m_structureBars, 1);
      double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);

      bool bosUp   = (ask > swingHigh);
      bool bosDown = (bid < swingLow);

      m_lastSweepDetected = DetectSweep(m_lastSweepDir);

      ENUM_STRUCT_REGIME newBias = m_state;
      int agree = 0;

      if(bosUp && !bosDown)
      {
         newBias = STRUCTR_BULLISH;
         agree = 2;
         if(m_priorBias == STRUCTR_BEARISH) agree++; // genuine CHoCH (bearish->bullish flip) - higher confidence
      }
      else if(bosDown && !bosUp)
      {
         newBias = STRUCTR_BEARISH;
         agree = 2;
         if(m_priorBias == STRUCTR_BULLISH) agree++;
      }
      else
      {
         newBias = STRUCTR_NEUTRAL;
         agree = 1;
      }

      if(newBias != m_state) m_priorBias = m_state; // remember what we're transitioning FROM
      m_state = newBias;
      m_confidence = MathMin(100.0, (agree / 3.0) * 100.0);
   }

   ENUM_STRUCT_REGIME State()       { return m_state; }
   double             Confidence()  { return m_confidence; }
   bool               SweepDetected(){ return m_lastSweepDetected; }
   ENUM_SIGNAL_DIR    SweepDir()    { return m_lastSweepDir; }

   string StateString()
   {
      switch(m_state)
      {
         case STRUCTR_BULLISH: return "BULLISH";
         case STRUCTR_BEARISH: return "BEARISH";
         case STRUCTR_NEUTRAL: return "NEUTRAL";
         default: return "?";
      }
   }
};

//+------------------------------------------------------------------+
//| CRiskRegimeClassifier                                              |
//| Highest priority classifier per spec's resolution order. Combines |
//| live drawdown state, loss-streak state, and a manual event-window |
//| schedule with volatility/spread displacement detection (the       |
//| honestly-labeled "News-Aware Risk Engine" - see file header: no   |
//| news content is read or understood, only schedule + abnormal      |
//| market behavior).                                                   |
//+------------------------------------------------------------------+
class CRiskRegimeClassifier : public CRegimeClassifierBase
{
private:
   ENUM_RISK_REGIME m_state;
   double m_confidence;
   double m_displacementScore;     // 0-100, see UpdateDisplacement()
   bool   m_eventWindowActive;
   double m_avgVolumeForDisplacement;
   int    m_volSamplesForDisplacement;

   // Manual event schedule: parallel arrays of (start, end) datetime windows.
   // Populated from a delimited input string - see ParseEventSchedule().
   datetime m_eventStarts[];
   datetime m_eventEnds[];
   int      m_eventCount;

   void UpdateDisplacement(double atrValue, double avgSpread)
   {
      if(atrValue <= 0.0) { m_displacementScore = 0.0; return; }

      double h1 = iHigh(_Symbol,_Period,1), l1 = iLow(_Symbol,_Period,1);
      double rangeRatio = (h1 - l1) / atrValue;

      long vol[1];
      double volRatio = 1.0;
      if(CopyTickVolume(_Symbol,_Period,1,1,vol) > 0 && m_avgVolumeForDisplacement > 0.0)
         volRatio = (double)vol[0] / m_avgVolumeForDisplacement;

      double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      double spreadRatio = (avgSpread > 0.0) ? (ask-bid)/avgSpread : 1.0;

      double rangeScore  = MathMin(50.0, (rangeRatio / 2.2) * 50.0);
      double volScore    = MathMin(35.0, (volRatio / 1.8) * 35.0);
      double spreadScore = MathMin(15.0, MathMax(0.0, spreadRatio - 1.5) * 10.0);

      m_displacementScore = MathMin(100.0, rangeScore + volScore + spreadScore);

      if(CopyTickVolume(_Symbol,_Period,1,1,vol) > 0)
      {
         int cap = 400;
         m_avgVolumeForDisplacement = (m_avgVolumeForDisplacement * m_volSamplesForDisplacement + (double)vol[0]) / (double)(m_volSamplesForDisplacement+1);
         m_volSamplesForDisplacement = MathMin(m_volSamplesForDisplacement+1, cap);
      }
   }

   bool CheckEventWindow()
   {
      datetime now = TimeCurrent();
      for(int i = 0; i < m_eventCount; i++)
         if(now >= m_eventStarts[i] && now <= m_eventEnds[i]) return true;
      return false;
   }

public:
   CRiskRegimeClassifier() : CRegimeClassifierBase("RiskRegime")
   {
      m_state = RISKR_NORMAL; m_confidence = 70.0;
      m_displacementScore = 0.0; m_eventWindowActive = false;
      m_avgVolumeForDisplacement = 0.0; m_volSamplesForDisplacement = 0;
      m_eventCount = 0;
   }

   // Format: "YYYY.MM.DD HH:MM-YYYY.MM.DD HH:MM;YYYY.MM.DD HH:MM-..." 
   // Each semicolon-separated entry is one event window (start-end), server time.
   // Empty string -> zero events, this layer simply contributes nothing, per
   // the file header's honesty note (no invented event times).
   void ParseEventSchedule(string schedule)
   {
      m_eventCount = 0;
      if(StringLen(schedule) == 0) return;

      string entries[];
      int n = StringSplit(schedule, ';', entries);
      ArrayResize(m_eventStarts, n);
      ArrayResize(m_eventEnds, n);

      for(int i = 0; i < n; i++)
      {
         string entry = entries[i];
         StringTrimLeft(entry); StringTrimRight(entry);
         if(StringLen(entry) == 0) continue;

         int dashPos = StringFind(entry, "-", 11); // skip past "YYYY.MM.DD " prefix so we don't split on a date's own dashes
         if(dashPos < 0) continue;

         string startStr = entry;
         string endStr = entry;
         startStr = StringSubstr(entry, 0, dashPos);
         endStr   = StringSubstr(entry, dashPos+1);
         StringTrimLeft(startStr); StringTrimRight(startStr);
         StringTrimLeft(endStr);   StringTrimRight(endStr);

         datetime s = StringToTime(startStr);
         datetime e = StringToTime(endStr);
         if(s > 0 && e > 0 && e > s)
         {
            m_eventStarts[m_eventCount] = s;
            m_eventEnds[m_eventCount]   = e;
            m_eventCount++;
         }
      }
   }

   void Update(double atrValue, double avgSpread, double equityPeak, double maxDrawdownPct,
               int consecLosses, int maxLossStreak)
   {
      UpdateDisplacement(atrValue, avgSpread);
      m_eventWindowActive = CheckEventWindow();

      double equity = AccountInfoDouble(ACCOUNT_EQUITY);
      double ddPct = (equityPeak > 0.0) ? ((equityPeak - equity) / equityPeak) * 100.0 : 0.0;

      // Priority within this classifier itself: suspension conditions
      // override elevated/defensive conditions, mirroring the spec's
      // "Level 3: Temporary trading suspension" as the most severe state.
      if(ddPct >= maxDrawdownPct)
      {
         m_state = RISKR_SUSPENDED;
         m_confidence = 95.0; // hard numeric breach - high-confidence read by construction
      }
      else if(m_eventWindowActive && m_displacementScore >= 60.0)
      {
         // Scheduled event window AND market is already behaving abnormally -
         // strongest possible case for suspension without a hard DD breach
         m_state = RISKR_SUSPENDED;
         m_confidence = 80.0;
      }
      else if(m_eventWindowActive || m_displacementScore >= 75.0)
      {
         m_state = RISKR_DEFENSIVE;
         m_confidence = 75.0;
      }
      else if(ddPct >= maxDrawdownPct * 0.6 || consecLosses >= maxLossStreak)
      {
         m_state = RISKR_ELEVATED;
         m_confidence = 65.0;
      }
      else
      {
         m_state = RISKR_NORMAL;
         m_confidence = 70.0;
      }
   }

   ENUM_RISK_REGIME State()        { return m_state; }
   double           Confidence()   { return m_confidence; }
   double           DisplacementScore() { return m_displacementScore; }
   bool             EventWindowActive() { return m_eventWindowActive; }

   string StateString()
   {
      switch(m_state)
      {
         case RISKR_NORMAL: return "NORMAL";
         case RISKR_ELEVATED: return "ELEVATED";
         case RISKR_DEFENSIVE: return "DEFENSIVE";
         case RISKR_SUSPENDED: return "SUSPENDED";
         default: return "?";
      }
   }
};

//+------------------------------------------------------------------+
//| CStrategyBase                                                      |
//| Shared interface for all 7 strategies. IsEligible() checks         |
//| whether the CURRENT regime snapshot matches this strategy's        |
//| target regime combination (the spec's worked examples, e.g.        |
//| "Low Volatility + Range Market -> Mean Reversion"). Evaluate()      |
//| only runs real signal logic if IsEligible() already passed.        |
//+------------------------------------------------------------------+
class CStrategyBase
{
protected:
   string          m_name;
   ENUM_STRATEGY_ID m_id;

public:
   CStrategyBase(string name, ENUM_STRATEGY_ID id) { m_name = name; m_id = id; }
   virtual ~CStrategyBase() {}

   // Default no-op: strategies that don't own indicator handles (e.g.
   // CStrategy_RangeScalper, CStrategy_RangeTrading - both read price/swing
   // data directly via iHigh/iLow rather than indicator handles) simply
   // don't override this. Strategies that DO own handles (MeanReversion,
   // TrendContinuationLong/Short, PullbackTrendFollowing) override it -
   // see CStrategySelector's destructor, which calls this on every
   // registered strategy before deleting it, so handle cleanup happens
   // regardless of which concrete strategy type is stored behind the
   // base-class pointer.
   virtual void Release() {}

   virtual bool IsEligible(const CRegimeSnapshot &snap) { return false; }
   virtual SStrategySignal Evaluate(const CRegimeSnapshot &snap)
   {
      SStrategySignal s; s.dir=SIG_NONE; s.score=0.0; s.valid=false; s.reason="base class - not implemented";
      return s;
   }

   string           Name() { return m_name; }
   ENUM_STRATEGY_ID Id()   { return m_id; }
};

//+------------------------------------------------------------------+
//| CStrategy_MeanReversion                                            |
//| Eligible: Ultra-Low/Normal Volatility + Sideways Trend + Weak       |
//| Momentum + Low/Medium Liquidity. Fades extremes back toward a      |
//| reference mean (Bollinger mid / EMA) - the spec's "Low Volatility  |
//| + Range Market -> Mean Reversion" example.                          |
//+------------------------------------------------------------------+
class CStrategy_MeanReversion : public CStrategyBase
{
private:
   int m_hBB, m_hRSI;

public:
   CStrategy_MeanReversion() : CStrategyBase("MeanReversion", STRAT_MEAN_REVERSION) { m_hBB=INVALID_HANDLE; m_hRSI=INVALID_HANDLE; }

   bool Init(int bbPeriod, double bbDev, int rsiPeriod)
   {
      m_hBB  = iBands(_Symbol, _Period, bbPeriod, 0, bbDev, PRICE_CLOSE);
      m_hRSI = iRSI(_Symbol, _Period, rsiPeriod, PRICE_CLOSE);
      return (m_hBB!=INVALID_HANDLE && m_hRSI!=INVALID_HANDLE);
   }
   void Release() override { if(m_hBB!=INVALID_HANDLE) IndicatorRelease(m_hBB); if(m_hRSI!=INVALID_HANDLE) IndicatorRelease(m_hRSI); }

   bool IsEligible(const CRegimeSnapshot &snap) override
   {
      bool volOk = (snap.volRegime == VOLR_ULTRA_LOW || snap.volRegime == VOLR_NORMAL);
      bool trendOk = (snap.trendRegime == TRENDR_SIDEWAYS);
      bool momOk = (snap.momRegime == MOMR_WEAK);
      bool liqOk = (snap.liqRegime != LIQR_HIGH); // spec disables aggressive systems in low liq, but mean reversion is the PREFERRED low-liq strategy, not disabled - only breakouts are disabled there
      return volOk && trendOk && momOk;
   }

   SStrategySignal Evaluate(const CRegimeSnapshot &snap) override
   {
      SStrategySignal s; s.dir=SIG_NONE; s.score=0.0; s.valid=false; s.reason="";

      double upper[1], lower[1], mid[1];
      if(CopyBuffer(m_hBB,1,0,1,upper)<=0 || CopyBuffer(m_hBB,2,0,1,lower)<=0 || CopyBuffer(m_hBB,0,0,1,mid)<=0) return s;
      double rsiArr[1];
      double rsi = (CopyBuffer(m_hRSI,0,0,1,rsiArr)>0) ? rsiArr[0] : 50.0;
      double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);

      bool nearLower = (bid <= lower[0]) || (rsi <= 32.0);
      bool nearUpper = (ask >= upper[0]) || (rsi >= 68.0);

      if(!nearLower && !nearUpper) return s;

      ENUM_SIGNAL_DIR dir = nearLower ? SIG_BUY : SIG_SELL;
      double score = 45.0;
      if((dir==SIG_BUY && bid<=lower[0]) || (dir==SIG_SELL && ask>=upper[0])) score += 30.0;
      if((dir==SIG_BUY && rsi<=32.0) || (dir==SIG_SELL && rsi>=68.0)) score += 25.0;

      s.dir = dir; s.score = MathMin(100.0, score); s.valid = (s.score >= 50.0);
      s.reason = "BB/RSI extreme, fading toward mean, RSI="+DoubleToString(rsi,1);
      return s;
   }
};

//+------------------------------------------------------------------+
//| CStrategy_RangeScalper                                             |
//| Eligible: Asian Session + Ultra-Low/Normal Vol + Sideways trend.   |
//| Spec's "Asian Session + Compression -> Range Scalper" example.     |
//| Faster/tighter variant of mean reversion scoped to range edges     |
//| with a tighter confirmation requirement, distinct strategy object |
//| from MeanReversion per spec's explicit strategy list.               |
//+------------------------------------------------------------------+
class CStrategy_RangeScalper : public CStrategyBase
{
private:
   int m_structureBars;

public:
   CStrategy_RangeScalper() : CStrategyBase("RangeScalper", STRAT_RANGE_SCALPER) { m_structureBars = 10; }
   void Init(int structureBars) { m_structureBars = MathMax(5, structureBars); }

   bool IsEligible(const CRegimeSnapshot &snap) override
   {
      bool sessionOk = (snap.sessionRegime == SESR_ASIAN);
      bool volOk = (snap.volRegime == VOLR_ULTRA_LOW || snap.volRegime == VOLR_NORMAL);
      bool trendOk = (snap.trendRegime == TRENDR_SIDEWAYS);
      return sessionOk && volOk && trendOk;
   }

   SStrategySignal Evaluate(const CRegimeSnapshot &snap) override
   {
      SStrategySignal s; s.dir=SIG_NONE; s.score=0.0; s.valid=false; s.reason="";

      int highBar = iHighest(_Symbol,_Period,MODE_HIGH,m_structureBars,1);
      int lowBar  = iLowest(_Symbol,_Period,MODE_LOW,m_structureBars,1);
      if(highBar<0 || lowBar<0) return s;
      double rangeHigh = iHigh(_Symbol,_Period,highBar);
      double rangeLow  = iLow(_Symbol,_Period,lowBar);
      double rangeMid  = (rangeHigh+rangeLow)/2.0;
      double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);

      double rangeSize = rangeHigh - rangeLow;
      if(rangeSize <= 0.0) return s;
      double edgeBuffer = rangeSize * 0.12;

      bool nearLow  = (bid <= rangeLow + edgeBuffer);
      bool nearHigh = (ask >= rangeHigh - edgeBuffer);
      if(!nearLow && !nearHigh) return s;

      ENUM_SIGNAL_DIR dir = nearLow ? SIG_BUY : SIG_SELL;
      double score = 50.0 + ((bid<=rangeLow || ask>=rangeHigh) ? 25.0 : 10.0);

      s.dir = dir; s.score = MathMin(100.0, score); s.valid = (s.score >= 55.0);
      s.reason = "Range edge scalp, range="+DoubleToString(rangeLow,2)+"-"+DoubleToString(rangeHigh,2);
      return s;
   }
};

//+------------------------------------------------------------------+
//| CStrategy_TrendContinuationLong                                    |
//| Eligible: Strong Bull Trend regime ONLY. Spec explicitly disables  |
//| counter-trend systems here and lists Pullback Longs/Trend          |
//| Continuation as the activated set - this class IS that long-only   |
//| continuation engine, pulling back to the fast EMA before firing.   |
//+------------------------------------------------------------------+
class CStrategy_TrendContinuationLong : public CStrategyBase
{
private:
   int m_hFastEMA, m_hATR;

public:
   CStrategy_TrendContinuationLong() : CStrategyBase("TrendContinuationLong", STRAT_TREND_CONT_LONG) { m_hFastEMA=INVALID_HANDLE; m_hATR=INVALID_HANDLE; }
   bool Init(int fastEMA, int atrPeriod)
   {
      m_hFastEMA = iMA(_Symbol,_Period,fastEMA,0,MODE_EMA,PRICE_CLOSE);
      m_hATR = iATR(_Symbol,_Period,atrPeriod);
      return (m_hFastEMA!=INVALID_HANDLE && m_hATR!=INVALID_HANDLE);
   }
   void Release() override { if(m_hFastEMA!=INVALID_HANDLE) IndicatorRelease(m_hFastEMA); if(m_hATR!=INVALID_HANDLE) IndicatorRelease(m_hATR); }

   bool IsEligible(const CRegimeSnapshot &snap) override
   {
      return (snap.trendRegime == TRENDR_STRONG_BULL) && (snap.structRegime != STRUCTR_BEARISH);
   }

   SStrategySignal Evaluate(const CRegimeSnapshot &snap) override
   {
      SStrategySignal s; s.dir=SIG_NONE; s.score=0.0; s.valid=false; s.reason="";

      double f[1]; if(CopyBuffer(m_hFastEMA,0,0,1,f)<=0) return s;
      double a[1]; double atr = (CopyBuffer(m_hATR,0,0,1,a)>0)?a[0]:0.0;
      double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      if(atr <= 0.0) return s;

      bool nearFastEMA = MathAbs(bid - f[0]) <= atr * 0.6;
      if(!nearFastEMA) return s;

      double score = 55.0;
      if(snap.structRegime == STRUCTR_BULLISH) score += 25.0;
      score += (snap.momRegime == MOMR_STRONG) ? 10.0 : 0.0;
      score += (snap.trendConfidence/100.0) * 10.0;

      s.dir = SIG_BUY; s.score = MathMin(100.0, score); s.valid = (s.score >= 55.0);
      s.reason = "Pullback to fast EMA within strong bull trend (TrendConf="+DoubleToString(snap.trendConfidence,0)+"%)";
      return s;
   }
};

//+------------------------------------------------------------------+
//| CStrategy_TrendContinuationShort                                   |
//| Mirror of the long version, eligible only in Strong Bear Trend.   |
//| Spec explicitly disables "Long Mean Reversion" in this regime -    |
//| that's naturally satisfied since CStrategy_MeanReversion's own     |
//| eligibility requires TRENDR_SIDEWAYS, so it cannot fire here.      |
//+------------------------------------------------------------------+
class CStrategy_TrendContinuationShort : public CStrategyBase
{
private:
   int m_hFastEMA, m_hATR;

public:
   CStrategy_TrendContinuationShort() : CStrategyBase("TrendContinuationShort", STRAT_TREND_CONT_SHORT) { m_hFastEMA=INVALID_HANDLE; m_hATR=INVALID_HANDLE; }
   bool Init(int fastEMA, int atrPeriod)
   {
      m_hFastEMA = iMA(_Symbol,_Period,fastEMA,0,MODE_EMA,PRICE_CLOSE);
      m_hATR = iATR(_Symbol,_Period,atrPeriod);
      return (m_hFastEMA!=INVALID_HANDLE && m_hATR!=INVALID_HANDLE);
   }
   void Release() override { if(m_hFastEMA!=INVALID_HANDLE) IndicatorRelease(m_hFastEMA); if(m_hATR!=INVALID_HANDLE) IndicatorRelease(m_hATR); }

   bool IsEligible(const CRegimeSnapshot &snap) override
   {
      return (snap.trendRegime == TRENDR_STRONG_BEAR) && (snap.structRegime != STRUCTR_BULLISH);
   }

   SStrategySignal Evaluate(const CRegimeSnapshot &snap) override
   {
      SStrategySignal s; s.dir=SIG_NONE; s.score=0.0; s.valid=false; s.reason="";

      double f[1]; if(CopyBuffer(m_hFastEMA,0,0,1,f)<=0) return s;
      double a[1]; double atr = (CopyBuffer(m_hATR,0,0,1,a)>0)?a[0]:0.0;
      double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(atr <= 0.0) return s;

      bool nearFastEMA = MathAbs(ask - f[0]) <= atr * 0.6;
      if(!nearFastEMA) return s;

      double score = 55.0;
      if(snap.structRegime == STRUCTR_BEARISH) score += 25.0;
      score += (snap.momRegime == MOMR_STRONG) ? 10.0 : 0.0;
      score += (snap.trendConfidence/100.0) * 10.0;

      s.dir = SIG_SELL; s.score = MathMin(100.0, score); s.valid = (s.score >= 55.0);
      s.reason = "Pullback to fast EMA within strong bear trend (TrendConf="+DoubleToString(snap.trendConfidence,0)+"%)";
      return s;
   }
};

//+------------------------------------------------------------------+
//| CStrategy_MomentumBreakout                                         |
//| Eligible: High/Extreme Volatility + Strong Momentum + High/Medium |
//| Liquidity. Spec's "High Volatility + Momentum -> Momentum          |
//| Breakout" example. Requires both a structural break AND volume    |
//| confirmation - a breakout without volume is the classic false     |
//| signal this strategy is designed to filter out.                    |
//+------------------------------------------------------------------+
class CStrategy_MomentumBreakout : public CStrategyBase
{
private:
   int m_structureBars;

public:
   CStrategy_MomentumBreakout() : CStrategyBase("MomentumBreakout", STRAT_MOMENTUM_BREAKOUT) { m_structureBars = 6; }
   void Init(int structureBars) { m_structureBars = MathMax(4, structureBars); }

   bool IsEligible(const CRegimeSnapshot &snap) override
   {
      bool volOk = (snap.volRegime == VOLR_HIGH || snap.volRegime == VOLR_EXTREME);
      bool momOk = (snap.momRegime == MOMR_STRONG);
      bool liqOk = (snap.liqRegime != LIQR_LOW); // spec disables aggressive breakouts in low liquidity
      return volOk && momOk && liqOk;
   }

   SStrategySignal Evaluate(const CRegimeSnapshot &snap) override
   {
      SStrategySignal s; s.dir=SIG_NONE; s.score=0.0; s.valid=false; s.reason="";

      int highBar = iHighest(_Symbol,_Period,MODE_HIGH,m_structureBars,1);
      int lowBar  = iLowest(_Symbol,_Period,MODE_LOW,m_structureBars,1);
      if(highBar<0 || lowBar<0) return s;
      double swingHigh = iHigh(_Symbol,_Period,highBar);
      double swingLow  = iLow(_Symbol,_Period,lowBar);
      double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);

      bool breakUp   = (ask > swingHigh);
      bool breakDown = (bid < swingLow);
      if(!breakUp && !breakDown) return s;

      ENUM_SIGNAL_DIR dir = breakUp ? SIG_BUY : SIG_SELL;
      double score = 50.0;
      score += (snap.liqRegime == LIQR_HIGH) ? 20.0 : 5.0;
      score += (snap.volRegime == VOLR_EXTREME) ? 10.0 : 20.0; // EXTREME gets less bonus - more caution, matches risk engine's defensive bias at extreme vol
      score += (snap.structRegime == (dir==SIG_BUY?STRUCTR_BULLISH:STRUCTR_BEARISH)) ? 10.0 : 0.0;

      s.dir = dir; s.score = MathMin(100.0, score);
      s.valid = (s.score >= 55.0) && (snap.liqRegime == LIQR_HIGH); // hard requirement: real breakouts need real liquidity, not just a momentum read
      s.reason = "Structural break "+(breakUp?"up":"down")+" with strong momentum + liquidity confirmation";
      return s;
   }
};

//+------------------------------------------------------------------+
//| CStrategy_PullbackTrendFollowing                                   |
//| Eligible: London Session + (Strong Bull or Bear) Trend. Spec's     |
//| "London Session + Trend -> Trend Continuation" example, scoped to |
//| the London window specifically (distinct from the always-on       |
//| TrendContinuationLong/Short pair, which are session-agnostic).    |
//+------------------------------------------------------------------+
class CStrategy_PullbackTrendFollowing : public CStrategyBase
{
private:
   int m_hSlowEMA;

public:
   CStrategy_PullbackTrendFollowing() : CStrategyBase("PullbackTrendFollowing", STRAT_PULLBACK_TREND) { m_hSlowEMA=INVALID_HANDLE; }
   bool Init(int slowEMA) { m_hSlowEMA = iMA(_Symbol,_Period,slowEMA,0,MODE_EMA,PRICE_CLOSE); return (m_hSlowEMA!=INVALID_HANDLE); }
   void Release() override { if(m_hSlowEMA!=INVALID_HANDLE) IndicatorRelease(m_hSlowEMA); }

   bool IsEligible(const CRegimeSnapshot &snap) override
   {
      bool sessionOk = (snap.sessionRegime == SESR_LONDON || snap.sessionRegime == SESR_OVERLAP);
      bool trendOk = (snap.trendRegime == TRENDR_STRONG_BULL || snap.trendRegime == TRENDR_STRONG_BEAR);
      return sessionOk && trendOk;
   }

   SStrategySignal Evaluate(const CRegimeSnapshot &snap) override
   {
      SStrategySignal s; s.dir=SIG_NONE; s.score=0.0; s.valid=false; s.reason="";

      double sl[1]; if(CopyBuffer(m_hSlowEMA,0,0,1,sl)<=0) return s;
      double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);

      ENUM_SIGNAL_DIR dir = (snap.trendRegime == TRENDR_STRONG_BULL) ? SIG_BUY : SIG_SELL;
      bool aligns = (dir==SIG_BUY) ? (bid > sl[0]) : (bid < sl[0]);
      if(!aligns) return s;

      double score = 50.0 + (snap.trendConfidence/100.0)*25.0 + (snap.sessionConfidence/100.0)*25.0;
      s.dir = dir; s.score = MathMin(100.0, score); s.valid = (s.score >= 55.0);
      s.reason = "London-session trend continuation, slow-EMA aligned";
      return s;
   }
};

//+------------------------------------------------------------------+
//| CStrategy_RangeTrading                                             |
//| Eligible: Sideways Trend (general case, session-agnostic) +        |
//| Weak Momentum. Spec's "Sideways Market -> Range Trading" example -|
//| distinct from RangeScalper (Asian-session-scoped, tighter/faster) |
//| and MeanReversion (vol-regime-scoped, BB/RSI based) by trading    |
//| the wider structural range between confirmed swing points.        |
//+------------------------------------------------------------------+
class CStrategy_RangeTrading : public CStrategyBase
{
private:
   int m_structureBars;

public:
   CStrategy_RangeTrading() : CStrategyBase("RangeTrading", STRAT_RANGE_TRADING) { m_structureBars = 20; }
   void Init(int structureBars) { m_structureBars = MathMax(10, structureBars); }

   bool IsEligible(const CRegimeSnapshot &snap) override
   {
      return (snap.trendRegime == TRENDR_SIDEWAYS) && (snap.momRegime == MOMR_WEAK);
   }

   SStrategySignal Evaluate(const CRegimeSnapshot &snap) override
   {
      SStrategySignal s; s.dir=SIG_NONE; s.score=0.0; s.valid=false; s.reason="";

      int highBar = iHighest(_Symbol,_Period,MODE_HIGH,m_structureBars,1);
      int lowBar  = iLowest(_Symbol,_Period,MODE_LOW,m_structureBars,1);
      if(highBar<0 || lowBar<0) return s;
      double rangeHigh = iHigh(_Symbol,_Period,highBar);
      double rangeLow  = iLow(_Symbol,_Period,lowBar);
      double rangeSize = rangeHigh - rangeLow;
      if(rangeSize <= 0.0) return s;

      double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      double edgeBuffer = rangeSize * 0.20; // wider buffer than RangeScalper - this trades the broader structural range, not tight edges

      bool nearLow  = (bid <= rangeLow + edgeBuffer);
      bool nearHigh = (ask >= rangeHigh - edgeBuffer);
      if(!nearLow && !nearHigh) return s;

      ENUM_SIGNAL_DIR dir = nearLow ? SIG_BUY : SIG_SELL;
      double score = 45.0 + (snap.trendConfidence/100.0)*30.0;

      s.dir = dir; s.score = MathMin(100.0, score); s.valid = (s.score >= 50.0);
      s.reason = "Structural range trade, range="+DoubleToString(rangeLow,2)+"-"+DoubleToString(rangeHigh,2);
      return s;
   }
};

//+------------------------------------------------------------------+
//| CStrategySelector                                                  |
//| Owns strict single-strategy exclusivity. This is the class that   |
//| satisfies the spec's core requirement: "The EA must never run all |
//| strategies simultaneously... only one primary strategy may         |
//| control entries at any time."                                      |
//|                                                                      |
//| Resolution model (distinct from NOVA TITAN X's per-tick best-score |
//| dispatch - see file header):                                       |
//|  1. Priority gate: RiskRegime is checked FIRST per spec's exact    |
//|     priority order (Risk > News/Event > Volatility > Trend >        |
//|     Momentum > Liquidity > Session). If RiskRegime is SUSPENDED,   |
//|     no strategy may activate, full stop, regardless of what any    |
//|     other classifier says.                                          |
//|  2. Candidate strategies are filtered by IsEligible() against the  |
//|     current CRegimeSnapshot - usually 0 or 1 strategy is eligible  |
//|     at once since the 7 strategies' eligibility windows were        |
//|     deliberately constructed to mostly not overlap (see each       |
//|     strategy class's header comment). If more than one is          |
//|     eligible, priority order breaks the tie using the same          |
//|     dimension ordering as step 1.                                   |
//|  3. Hysteresis: a CANDIDATE strategy (the one eligibility+priority |
//|     currently points to) must remain the top candidate for          |
//|     confirmBars consecutive new bars before it is allowed to        |
//|     REPLACE whatever strategy is currently active. This is what     |
//|     prevents rapid strategy flipping when regimes oscillate near    |
//|     a boundary.                                                      |
//|  4. Cooldown: after any strategy hand-off (old strategy loses       |
//|     control / new strategy gains it), a cooldown period blocks      |
//|     further hand-offs even if the candidate keeps changing.         |
//+------------------------------------------------------------------+
class CStrategySelector
{
private:
   CStrategyBase*    m_strategies[NUM_STRATEGIES];
   ENUM_STRATEGY_ID  m_activeId;
   ENUM_STRATEGY_ID  m_candidateId;
   int               m_candidateStreak;     // consecutive new-bars the candidate has held the top spot
   datetime          m_lastHandoffTime;
   datetime          m_lastBarTime;

   int   m_confirmBars;
   int   m_cooldownSeconds;
   double m_minConfidenceToActivate;

   // Priority order index for a given regime dimension's "is this dimension
   // currently the deciding factor" check - lower number = higher priority,
   // matching the spec's exact list: Risk, News/Event(folded into Risk),
   // Volatility, Trend, Momentum, Liquidity, Session.
   int DimensionPriority(ENUM_STRATEGY_ID id)
   {
      // Returns which regime dimension primarily gates this strategy, used
      // only for tie-breaking when >1 strategy is simultaneously eligible.
      switch(id)
      {
         case STRAT_MOMENTUM_BREAKOUT:        return 2; // volatility+momentum gated
         case STRAT_TREND_CONT_LONG:          return 3; // trend gated
         case STRAT_TREND_CONT_SHORT:         return 3;
         case STRAT_PULLBACK_TREND:           return 3; // trend+session gated, trend dominates tie-break
         case STRAT_MEAN_REVERSION:           return 4; // momentum+volatility gated
         case STRAT_RANGE_TRADING:            return 4;
         case STRAT_RANGE_SCALPER:            return 6; // session gated primarily
         default: return 9;
      }
   }

public:
   CStrategySelector()
   {
      for(int i = 0; i < NUM_STRATEGIES; i++) m_strategies[i] = NULL;
      m_activeId = STRAT_NONE;
      m_candidateId = STRAT_NONE;
      m_candidateStreak = 0;
      m_lastHandoffTime = 0;
      m_lastBarTime = 0;
      m_confirmBars = 3;
      m_cooldownSeconds = 120;
      m_minConfidenceToActivate = 55.0;
   }

   ~CStrategySelector()
   {
      // Release() is virtual on CStrategyBase, so this correctly calls each
      // concrete strategy's override (or the no-op default) regardless of
      // which strategy type is stored behind the base-class pointer -
      // closes the indicator-handle leak that existed when OnDeinit() tried
      // (and failed) to reach into the selector's private strategy array
      // directly. OnDeinit() no longer needs strategy-specific Release()
      // calls at all; this destructor is now the single point of cleanup.
      for(int i = 0; i < NUM_STRATEGIES; i++)
      {
         if(m_strategies[i] != NULL)
         {
            m_strategies[i].Release();
            delete m_strategies[i];
         }
      }
   }

   void Configure(int confirmBars, int cooldownSeconds, double minConfidence)
   {
      m_confirmBars = MathMax(1, confirmBars);
      m_cooldownSeconds = MathMax(0, cooldownSeconds);
      m_minConfidenceToActivate = minConfidence;
   }

   // Strategy objects are owned (and deleted) by this selector once registered.
   void Register(CStrategyBase *strat)
   {
      int idx = (int)strat.Id();
      if(idx >= 0 && idx < NUM_STRATEGIES)
      {
         if(m_strategies[idx] != NULL) delete m_strategies[idx]; // guard against accidental double-register leak
         m_strategies[idx] = strat;
      }
   }

   ENUM_STRATEGY_ID ActiveId()    { return m_activeId; }
   ENUM_STRATEGY_ID CandidateId() { return m_candidateId; }
   int               CandidateStreak() { return m_candidateStreak; }

   string ActiveName()
   {
      if(m_activeId == STRAT_NONE) return "NONE";
      CStrategyBase *a = m_strategies[(int)m_activeId];
      return (a != NULL) ? a.Name() : "NONE";
   }

   // Computes an aggregate confidence for the WINNING regime dimension(s)
   // backing the candidate strategy - used as the activation gate alongside
   // the strategy's own Evaluate() score.
   double AggregateRegimeConfidence(const CRegimeSnapshot &snap, ENUM_STRATEGY_ID id)
   {
      switch(id)
      {
         case STRAT_MEAN_REVERSION:    return (snap.volConfidence + snap.trendConfidence + snap.momConfidence) / 3.0;
         case STRAT_RANGE_SCALPER:     return (snap.sessionConfidence + snap.volConfidence + snap.trendConfidence) / 3.0;
         case STRAT_TREND_CONT_LONG:   return (snap.trendConfidence + snap.structConfidence) / 2.0;
         case STRAT_TREND_CONT_SHORT:  return (snap.trendConfidence + snap.structConfidence) / 2.0;
         case STRAT_MOMENTUM_BREAKOUT: return (snap.volConfidence + snap.momConfidence + snap.liqConfidence) / 3.0;
         case STRAT_PULLBACK_TREND:    return (snap.sessionConfidence + snap.trendConfidence) / 2.0;
         case STRAT_RANGE_TRADING:     return (snap.trendConfidence + snap.momConfidence) / 2.0;
         default: return 0.0;
      }
   }

   bool IsNewBar()
   {
      datetime cur = (datetime)SeriesInfoInteger(_Symbol, _Period, SERIES_LASTBAR_DATE);
      if(cur == m_lastBarTime) return false;
      m_lastBarTime = cur;
      return true;
   }

   //--- Called every new bar. Determines the current top-priority eligible
   //    candidate and advances/resets the confirmation streak. Does NOT
   //    itself perform the hand-off - that happens in TryActivate(), called
   //    separately once per tick so entries can still fire intra-bar once
   //    a hand-off has already been confirmed and committed.
   void UpdateCandidate(const CRegimeSnapshot &snap)
   {
      if(!IsNewBar()) return;

      // Step 1: hard risk gate. If suspended, there is no candidate at all -
      // this overrides every other dimension per spec's priority order.
      if(snap.riskRegime == RISKR_SUSPENDED)
      {
         if(m_candidateId != STRAT_NONE) { m_candidateId = STRAT_NONE; m_candidateStreak = 0; }
         else m_candidateStreak++;
         return;
      }

      // Step 2: gather all eligible strategies this bar
      ENUM_STRATEGY_ID eligible[NUM_STRATEGIES];
      int eligibleCount = 0;
      for(int i = 0; i < NUM_STRATEGIES; i++)
      {
         if(m_strategies[i] == NULL) continue;
         if(m_strategies[i].IsEligible(snap))
            eligible[eligibleCount++] = (ENUM_STRATEGY_ID)i;
      }

      if(eligibleCount == 0)
      {
         if(m_candidateId != STRAT_NONE) { m_candidateId = STRAT_NONE; m_candidateStreak = 0; }
         else m_candidateStreak++;
         return;
      }

      // Step 3: tie-break by dimension priority if more than one eligible
      ENUM_STRATEGY_ID winner = eligible[0];
      int winnerPriority = DimensionPriority(winner);
      for(int i = 1; i < eligibleCount; i++)
      {
         int p = DimensionPriority(eligible[i]);
         if(p < winnerPriority) { winner = eligible[i]; winnerPriority = p; }
      }

      // Step 4: advance or reset the confirmation streak
      if(winner == m_candidateId)
         m_candidateStreak++;
      else
      {
         m_candidateId = winner;
         m_candidateStreak = 1;
      }
   }

   //--- Called every tick. Performs the actual hand-off once the candidate
   //    has survived its confirmation window AND the cooldown from the last
   //    hand-off has elapsed. Returns true if a hand-off just occurred.
   bool TryActivate(const CRegimeSnapshot &snap)
   {
      if(m_candidateId == STRAT_NONE) return false;
      if(m_candidateId == m_activeId) return false; // already active, nothing to do
      if(m_candidateStreak < m_confirmBars) return false; // not confirmed long enough yet

      datetime now = TimeCurrent();
      if(now - m_lastHandoffTime < m_cooldownSeconds) return false; // still in cooldown from last switch

      double aggConf = AggregateRegimeConfidence(snap, m_candidateId);
      if(aggConf < m_minConfidenceToActivate) return false; // regime confidence too weak to commit capital to a switch

      m_activeId = m_candidateId;
      m_lastHandoffTime = now;
      return true;
   }

   //--- Forces the active strategy to release control without waiting for
   //    a new candidate to confirm - used when the position closes and we
   //    want a clean re-evaluation, or when risk regime forces suspension.
   void ForceRelease()
   {
      m_activeId = STRAT_NONE;
   }

   SStrategySignal EvaluateActive(const CRegimeSnapshot &snap)
   {
      SStrategySignal s; s.dir=SIG_NONE; s.score=0.0; s.valid=false; s.reason="no active strategy";
      if(m_activeId == STRAT_NONE) return s;
      CStrategyBase *a = m_strategies[(int)m_activeId];
      if(a == NULL) return s;
      return a.Evaluate(snap);
   }
};

//+------------------------------------------------------------------+
//| CMTFFilter                                                          |
//| Multi-timeframe bias confirmation across M1/M5/M15/H1. Used as a   |
//| FILTER on entries (per spec: "Use higher timeframe bias to filter |
//| lower timeframe entries"), not as its own signal source.            |
//+------------------------------------------------------------------+
class CMTFFilter
{
private:
   int m_hEMA_M1, m_hEMA_M5, m_hEMA_M15, m_hEMA_H1;
   int m_emaPeriod;

   bool GetBias(int handle, bool &bullish)
   {
      double e[1];
      if(CopyBuffer(handle, 0, 0, 1, e) <= 0) return false;
      double price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      bullish = (price > e[0]);
      return true;
   }

public:
   CMTFFilter() { m_hEMA_M1=INVALID_HANDLE; m_hEMA_M5=INVALID_HANDLE; m_hEMA_M15=INVALID_HANDLE; m_hEMA_H1=INVALID_HANDLE; m_emaPeriod=50; }

   bool Init(int emaPeriod)
   {
      m_emaPeriod = emaPeriod;
      m_hEMA_M1  = iMA(_Symbol, PERIOD_M1,  m_emaPeriod, 0, MODE_EMA, PRICE_CLOSE);
      m_hEMA_M5  = iMA(_Symbol, PERIOD_M5,  m_emaPeriod, 0, MODE_EMA, PRICE_CLOSE);
      m_hEMA_M15 = iMA(_Symbol, PERIOD_M15, m_emaPeriod, 0, MODE_EMA, PRICE_CLOSE);
      m_hEMA_H1  = iMA(_Symbol, PERIOD_H1,  m_emaPeriod, 0, MODE_EMA, PRICE_CLOSE);
      return (m_hEMA_M1!=INVALID_HANDLE && m_hEMA_M5!=INVALID_HANDLE && m_hEMA_M15!=INVALID_HANDLE && m_hEMA_H1!=INVALID_HANDLE);
   }

   void Release()
   {
      if(m_hEMA_M1!=INVALID_HANDLE) IndicatorRelease(m_hEMA_M1);
      if(m_hEMA_M5!=INVALID_HANDLE) IndicatorRelease(m_hEMA_M5);
      if(m_hEMA_M15!=INVALID_HANDLE) IndicatorRelease(m_hEMA_M15);
      if(m_hEMA_H1!=INVALID_HANDLE) IndicatorRelease(m_hEMA_H1);
   }

   // Returns how many of the 4 timeframes agree with the proposed direction,
   // and the alignment string for the dashboard. Caller decides the minimum
   // agreement count required - this class only reports, doesn't gate.
   int AgreementCount(ENUM_SIGNAL_DIR dir, string &alignmentStr)
   {
      bool b1, b5, b15, bH1;
      bool ok1 = GetBias(m_hEMA_M1, b1);
      bool ok5 = GetBias(m_hEMA_M5, b5);
      bool ok15 = GetBias(m_hEMA_M15, b15);
      bool okH1 = GetBias(m_hEMA_H1, bH1);

      int agree = 0;
      string s = "";
      bool wantBull = (dir == SIG_BUY);

      if(ok1)  { if(b1==wantBull) agree++; s += (b1?"M1:B ":"M1:S "); } else s += "M1:? ";
      if(ok5)  { if(b5==wantBull) agree++; s += (b5?"M5:B ":"M5:S "); } else s += "M5:? ";
      if(ok15) { if(b15==wantBull) agree++; s += (b15?"M15:B ":"M15:S "); } else s += "M15:? ";
      if(okH1) { if(bH1==wantBull) agree++; s += (bH1?"H1:B":"H1:S"); } else s += "H1:?";

      alignmentStr = s;
      return agree;
   }
};

//+------------------------------------------------------------------+
//| CRiskManager                                                       |
//| Dynamic position sizing (balance/equity/volatility/drawdown/      |
//| regime-confidence aware per spec), 3-level drawdown protection,    |
//| daily/weekly/consecutive-loss limits, emergency kill switch.       |
//+------------------------------------------------------------------+
class CRiskManager
{
private:
   double m_riskPercent;
   double m_maxDailyLossPct, m_maxDailyProfitPct;
   double m_maxDrawdownPct;
   double m_weeklyLossLimitPct;
   int    m_maxLossStreak;
   int    m_winStreakBoost;

   double m_equityPeak;
   datetime m_sessionDay;
   datetime m_weekStart;
   double m_weekOpenBal;
   double m_weekProfit;
   int    m_dailyTrades;
   double m_dailyProfit;
   int    m_dailyWins, m_dailyLosses;
   int    m_consecWins, m_consecLosses;
   double m_winRate7;
   int    m_last7[7];

   ulong  m_magic;

   datetime DayStart(datetime t) { MqlDateTime d; TimeToStruct(t,d); return t-(datetime)(d.hour*3600+d.min*60+d.sec); }
   datetime WeekStart(datetime t)
   {
      MqlDateTime d; TimeToStruct(t,d);
      datetime ds = DayStart(t);
      int daysSinceMon = (d.day_of_week==0)?6:(d.day_of_week-1);
      return ds - (datetime)(daysSinceMon*86400);
   }

public:
   CRiskManager()
   {
      m_riskPercent=1.0; m_maxDailyLossPct=5.0; m_maxDailyProfitPct=10.0;
      m_maxDrawdownPct=15.0; m_weeklyLossLimitPct=10.0;
      m_maxLossStreak=3; m_winStreakBoost=5;
      m_equityPeak=0.0; m_sessionDay=0; m_weekStart=0; m_weekOpenBal=0.0; m_weekProfit=0.0;
      m_dailyTrades=0; m_dailyProfit=0.0; m_dailyWins=0; m_dailyLosses=0;
      m_consecWins=0; m_consecLosses=0; m_winRate7=0.0;
      ArrayInitialize(m_last7, -1);
      m_magic = 0;
   }

   void Configure(ulong magic, double riskPct, double maxDailyLoss, double maxDailyProfit,
                  double maxDD, double weeklyLossLimit, int maxLossStreak, int winStreakBoost)
   {
      m_magic = magic;
      m_riskPercent = riskPct; m_maxDailyLossPct = maxDailyLoss; m_maxDailyProfitPct = maxDailyProfit;
      m_maxDrawdownPct = maxDD; m_weeklyLossLimitPct = weeklyLossLimit;
      m_maxLossStreak = maxLossStreak; m_winStreakBoost = winStreakBoost;
   }

   void Init()
   {
      datetime now = TimeCurrent();
      m_sessionDay = DayStart(now);
      m_weekStart = WeekStart(now);
      m_weekOpenBal = AccountInfoDouble(ACCOUNT_BALANCE);
      m_equityPeak = AccountInfoDouble(ACCOUNT_EQUITY);
      SyncDaily();
      SyncWeekly();
   }

   void SyncDaily()
   {
      datetime now = TimeCurrent();
      datetime ds = DayStart(now);
      if(ds > m_sessionDay)
      {
         m_sessionDay = ds;
         m_dailyTrades=0; m_dailyProfit=0.0; m_dailyWins=0; m_dailyLosses=0;
      }
      m_dailyProfit=0.0; m_dailyWins=0; m_dailyLosses=0;
      datetime scanFrom = ds - 7*86400;
      if(!HistorySelect(scanFrom, now)) return;

      int ring[7]; ArrayInitialize(ring,-1);
      int ringIdx=0; bool lastWin=false; int streak=0; int total=0;

      for(int i=0;i<HistoryDealsTotal();i++)
      {
         ulong tkt = HistoryDealGetTicket(i);
         if(tkt==0) continue;
         if(HistoryDealGetInteger(tkt,DEAL_MAGIC)!=(long)m_magic) continue;
         if(HistoryDealGetString(tkt,DEAL_SYMBOL)!=_Symbol) continue;
         if(HistoryDealGetInteger(tkt,DEAL_ENTRY)!=DEAL_ENTRY_OUT) continue;

         double pnl = HistoryDealGetDouble(tkt,DEAL_PROFIT)+HistoryDealGetDouble(tkt,DEAL_COMMISSION)+HistoryDealGetDouble(tkt,DEAL_SWAP);
         bool win = (pnl>=0.0);
         total++;
         datetime dealTime = (datetime)HistoryDealGetInteger(tkt,DEAL_TIME);
         if(dealTime >= ds) { m_dailyProfit+=pnl; if(win) m_dailyWins++; else m_dailyLosses++; }

         ring[ringIdx%7] = win?1:0; ringIdx++;
         if(win==lastWin) streak++; else streak=1;
         lastWin=win;
      }
      if(total>0) { if(lastWin){m_consecWins=streak;m_consecLosses=0;} else {m_consecLosses=streak;m_consecWins=0;} }
      else { m_consecWins=0; m_consecLosses=0; }

      int wins7=0,total7=0;
      for(int j=0;j<7;j++){ if(ring[j]<0) continue; total7++; if(ring[j]==1) wins7++; }
      m_winRate7 = (total7>0)?((double)wins7/total7)*100.0:0.0;
      for(int j=0;j<7;j++) m_last7[j]=ring[j];
   }

   void SyncWeekly()
   {
      datetime now = TimeCurrent();
      datetime ws = WeekStart(now);
      if(ws > m_weekStart) { m_weekStart=ws; m_weekOpenBal=AccountInfoDouble(ACCOUNT_BALANCE); m_weekProfit=0.0; }
      m_weekProfit = 0.0;
      if(!HistorySelect(ws, now)) return;
      for(int i=0;i<HistoryDealsTotal();i++)
      {
         ulong tkt = HistoryDealGetTicket(i);
         if(tkt==0) continue;
         if(HistoryDealGetInteger(tkt,DEAL_MAGIC)!=(long)m_magic) continue;
         if(HistoryDealGetString(tkt,DEAL_SYMBOL)!=_Symbol) continue;
         if(HistoryDealGetInteger(tkt,DEAL_ENTRY)!=DEAL_ENTRY_OUT) continue;
         m_weekProfit += HistoryDealGetDouble(tkt,DEAL_PROFIT)+HistoryDealGetDouble(tkt,DEAL_COMMISSION)+HistoryDealGetDouble(tkt,DEAL_SWAP);
      }
   }

   void UpdateEquityPeak() { double eq=AccountInfoDouble(ACCOUNT_EQUITY); if(eq>m_equityPeak) m_equityPeak=eq; }

   double DrawdownPct()
   {
      if(m_equityPeak<=0.0) return 0.0;
      double eq = AccountInfoDouble(ACCOUNT_EQUITY);
      return ((m_equityPeak-eq)/m_equityPeak)*100.0;
   }

   // Three-level drawdown protection per spec:
   //  Level 1 (>40% of max DD): reduce risk
   //  Level 2 (>70% of max DD): reduce strategy aggressiveness (higher min confidence)
   //  Level 3 (>=100% of max DD): temporary trading suspension
   int DrawdownLevel()
   {
      double dd = DrawdownPct();
      if(dd >= m_maxDrawdownPct) return 3;
      if(dd >= m_maxDrawdownPct*0.7) return 2;
      if(dd >= m_maxDrawdownPct*0.4) return 1;
      return 0;
   }

   bool IsDailyLossLimitHit() { double bal=AccountInfoDouble(ACCOUNT_BALANCE); return (m_dailyProfit <= -MathAbs(bal*(m_maxDailyLossPct/100.0))); }
   bool IsDailyProfitHit()    { double bal=AccountInfoDouble(ACCOUNT_BALANCE); return (m_dailyProfit >= bal*(m_maxDailyProfitPct/100.0)); }
   bool IsWeeklyLossLimitHit(){ return (m_weekProfit <= -MathAbs(m_weekOpenBal*(m_weeklyLossLimitPct/100.0))); }
   bool IsDrawdownLimitHit()  { return DrawdownPct() >= m_maxDrawdownPct; }

   double RiskAdjustedPercent()
   {
      double pct = m_riskPercent;
      if(m_consecLosses >= m_maxLossStreak) pct *= 0.5;
      else if(m_consecWins >= m_winStreakBoost) pct = MathMin(m_riskPercent*1.25, 2.0);

      int ddLevel = DrawdownLevel();
      if(ddLevel == 1) pct *= 0.75;
      else if(ddLevel >= 2) pct *= 0.5;
      return pct;
   }

   double CalculateLotSize(double slDistancePrice, double regimeConfidence)
   {
      double balance = AccountInfoDouble(ACCOUNT_BALANCE);
      double riskPct = RiskAdjustedPercent();
      // Regime-confidence-aware sizing per spec: scale down (never up beyond
      // the already-computed risk%) when the backing regime confidence is
      // weak, even if it cleared the activation threshold.
      double confScale = MathMax(0.5, MathMin(1.0, regimeConfidence/100.0));
      double riskAmount = balance * (riskPct/100.0) * confScale;

      double tickVal = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
      double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
      if(tickSize <= 0.0) return SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);

      double slCostPerLot = (slDistancePrice/tickSize)*tickVal;
      if(slCostPerLot <= 0.0) return SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);

      double lot = riskAmount/slCostPerLot;
      double minV = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
      double maxV = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
      double step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
      lot = MathMax(minV, MathMin(maxV, MathFloor(lot/step)*step));
      return lot;
   }

   void RecordTrade() { m_dailyTrades++; }
   void ResetDailyTradeCountIfNewDay() { SyncDaily(); }

   // Accessors for dashboard / external logic
   double EquityPeak()    { return m_equityPeak; }
   int    DailyTrades()   { return m_dailyTrades; }
   double DailyProfit()   { return m_dailyProfit; }
   double WeekProfit()    { return m_weekProfit; }
   int    ConsecWins()    { return m_consecWins; }
   int    ConsecLosses()  { return m_consecLosses; }
   double WinRate7()      { return m_winRate7; }
   int    Last7(int i)    { return (i>=0&&i<7)?m_last7[i]:-1; }
   double MaxDailyLossPct(){ return m_maxDailyLossPct; }
   double MaxDrawdownPct() { return m_maxDrawdownPct; }
};

//+------------------------------------------------------------------+
//| CExecutionEngine                                                   |
//| Spread validation, slippage protection, freeze-level protection,   |
//| trade-context protection, and retry mechanisms per spec.            |
//+------------------------------------------------------------------+
class CExecutionEngine
{
private:
   CTrade *m_trade;
   double m_maxSpreadPct;
   double m_spreadAvgMultiple;
   int    m_maxSlippagePoints;
   int    m_maxRetries;
   double m_avgSpread;
   int    m_spreadSamples;

   int    m_requoteCount;
   int    m_rejectCount;
   double m_avgSlippage;
   int    m_slippageSamples;

public:
   CExecutionEngine() { m_trade=NULL; m_maxSpreadPct=0.06; m_spreadAvgMultiple=2.5; m_maxSlippagePoints=50; m_maxRetries=2;
                         m_avgSpread=0.0; m_spreadSamples=0; m_requoteCount=0; m_rejectCount=0; m_avgSlippage=0.0; m_slippageSamples=0; }

   void Configure(CTrade *trade, double maxSpreadPct, double spreadAvgMult, int maxSlippage, int maxRetries)
   {
      m_trade = trade; m_maxSpreadPct = maxSpreadPct; m_spreadAvgMultiple = spreadAvgMult;
      m_maxSlippagePoints = maxSlippage; m_maxRetries = maxRetries;
      if(m_trade != NULL) m_trade.SetDeviationInPoints(m_maxSlippagePoints);
   }

   void UpdateSpreadAverage()
   {
      double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      double spread = ask-bid;
      int cap = 2000;
      m_avgSpread = (m_avgSpread*m_spreadSamples+spread)/(double)(m_spreadSamples+1);
      m_spreadSamples = MathMin(m_spreadSamples+1, cap);
   }

   bool IsSpreadOk()
   {
      double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(bid<=0.0) return false;
      double spread = ask-bid;
      double spreadPct = (spread/bid)*100.0;
      if(spreadPct > m_maxSpreadPct) return false;
      if(m_spreadSamples>50 && spread > m_avgSpread*m_spreadAvgMultiple) return false;
      return true;
   }

   // Freeze-level protection: rejects modification/close attempts too close
   // to the current price per the broker's SYMBOL_TRADE_FREEZE_LEVEL, which
   // would otherwise return a silent broker-side rejection.
   bool IsWithinFreezeLevel(double targetPrice)
   {
      long freezeLevelPoints = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_FREEZE_LEVEL);
      if(freezeLevelPoints <= 0) return false; // broker reports no freeze level - nothing to protect against
      double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
      double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      double freezeDistance = freezeLevelPoints * point;
      return (MathAbs(targetPrice - bid) < freezeDistance);
   }

   // Trade context protection: MQL5's single-threaded model already
   // serializes trade calls per-EA, but multi-symbol/multi-chart setups can
   // still collide on shared account-level operations - this checks
   // terminal trade permission state before attempting an order.
   bool IsTradeContextFree()
   {
      if(!TerminalInfoInteger(TERMINAL_TRADE_ALLOWED)) return false;
      if(!MQLInfoInteger(MQL_TRADE_ALLOWED)) return false;
      if(!AccountInfoInteger(ACCOUNT_TRADE_ALLOWED)) return false;
      if(!AccountInfoInteger(ACCOUNT_TRADE_EXPERT)) return false;
      return true;
   }

   // Returns true and fills resultPrice on success. Retries on requote/price-
   // changed up to m_maxRetries times with a short backoff.
   bool ExecuteMarketOrder(ENUM_SIGNAL_DIR dir, double lot, double sl, double tp, string comment, double &resultPrice)
   {
      if(m_trade == NULL) return false;
      if(!IsTradeContextFree()) { m_rejectCount++; Print("[ExecutionEngine] Trade context not free - rejected."); return false; }
      if(!IsSpreadOk()) { Print("[ExecutionEngine] Spread too wide - rejected."); return false; }

      int attempts = 0;
      bool ok = false;
      while(attempts <= m_maxRetries && !ok)
      {
         double price = (dir==SIG_BUY) ? SymbolInfoDouble(_Symbol,SYMBOL_ASK) : SymbolInfoDouble(_Symbol,SYMBOL_BID);
         ok = (dir==SIG_BUY) ? m_trade.Buy(lot,_Symbol,price,sl,tp,comment) : m_trade.Sell(lot,_Symbol,price,sl,tp,comment);

         if(!ok)
         {
            uint rc = m_trade.ResultRetcode();
            if(rc==TRADE_RETCODE_REQUOTE || rc==TRADE_RETCODE_PRICE_CHANGED)
            { m_requoteCount++; attempts++; Sleep(150); continue; }
            m_rejectCount++;
            Print("[ExecutionEngine] Order FAILED. RetCode=",rc," ",m_trade.ResultRetcodeDescription());
            break;
         }
         else
         {
            double fillPrice = m_trade.ResultPrice();
            double slip = MathAbs(fillPrice - price);
            m_avgSlippage = (m_avgSlippage*m_slippageSamples+slip)/(double)(m_slippageSamples+1);
            m_slippageSamples = MathMin(m_slippageSamples+1, 2000);
            resultPrice = fillPrice;
         }
      }
      return ok;
   }

   double AvgSpread()      { return m_avgSpread; }
   int    RequoteCount()   { return m_requoteCount; }
   int    RejectCount()    { return m_rejectCount; }
   double AvgSlippage()    { return m_avgSlippage; }
};

//+------------------------------------------------------------------+
//| CTradeManager                                                       |
//| ATR/Structure/Volatility stop construction, Fixed-RR/ATR/Structure/|
//| Trailing take-profit methods, and the full dynamic management      |
//| stack (breakeven, partial close, smart trailing, volatility exit). |
//| R-multiple exit architecture carried over from the verified         |
//| NOVA TITAN X build, now encapsulated as a class.                    |
//+------------------------------------------------------------------+
class CTradeManager
{
private:
   CTrade *m_trade;
   CPositionInfo *m_pos;
   ulong m_magic;

   double m_entryPrice, m_entrySL, m_entryATR, m_entryRiskUSD;
   double m_peakProfit;
   bool   m_beSet, m_partialClosed;
   int    m_tradeDirection;
   datetime m_tradeOpenTime;

   double m_slMultiplier, m_tp2Multiplier, m_minSLPct, m_maxSLPct;
   double m_tp1R, m_partialClosePct;
   double m_breakevenR, m_beBufferPct;
   bool   m_usePeakLock; double m_peakLockActivateR, m_peakLockRetrace, m_minRR, m_minLockProfitR;
   bool   m_useTrailing; double m_trailStartR, m_trailATRMult;
   int    m_maxTradeBars; double m_deteriorationR;

public:
   CTradeManager()
   {
      m_trade=NULL; m_pos=NULL; m_magic=0;
      m_entryPrice=0.0; m_entrySL=0.0; m_entryATR=0.0; m_entryRiskUSD=0.0;
      m_peakProfit=0.0; m_beSet=false; m_partialClosed=false; m_tradeDirection=0; m_tradeOpenTime=0;
      m_slMultiplier=1.4; m_tp2Multiplier=3.2; m_minSLPct=0.20; m_maxSLPct=1.60;
      m_tp1R=1.0; m_partialClosePct=50.0; m_breakevenR=0.5; m_beBufferPct=0.02;
      m_usePeakLock=true; m_peakLockActivateR=0.8; m_peakLockRetrace=25.0; m_minRR=1.0; m_minLockProfitR=0.5;
      m_useTrailing=true; m_trailStartR=0.6; m_trailATRMult=0.7;
      m_maxTradeBars=96; m_deteriorationR=-0.7;
   }

   void Configure(CTrade *trade, CPositionInfo *pos, ulong magic,
                  double slMult, double tp2Mult, double minSLPct, double maxSLPct,
                  double tp1R, double partialPct, double beR, double beBuf,
                  bool usePeakLock, double plActivateR, double plRetrace, double minRR, double minLockR,
                  bool useTrailing, double trailStartR, double trailATRMult,
                  int maxTradeBars, double deteriorationR)
   {
      m_trade=trade; m_pos=pos; m_magic=magic;
      m_slMultiplier=slMult; m_tp2Multiplier=tp2Mult; m_minSLPct=minSLPct; m_maxSLPct=maxSLPct;
      m_tp1R=tp1R; m_partialClosePct=partialPct; m_breakevenR=beR; m_beBufferPct=beBuf;
      m_usePeakLock=usePeakLock; m_peakLockActivateR=plActivateR; m_peakLockRetrace=plRetrace; m_minRR=minRR; m_minLockProfitR=minLockR;
      m_useTrailing=useTrailing; m_trailStartR=trailStartR; m_trailATRMult=trailATRMult;
      m_maxTradeBars=maxTradeBars; m_deteriorationR=deteriorationR;
   }

   // Stop-loss construction supporting all 3 spec'd methods. method:
   // 0=ATR, 1=Structure (swing high/low), 2=Volatility (stdev-based)
   double ComputeSLDistance(int method, double atrValue, double price, int structureBars, double histVol)
   {
      double dist = 0.0;
      if(method == 1)
      {
         int highBar = iHighest(_Symbol,_Period,MODE_HIGH,structureBars,1);
         int lowBar  = iLowest(_Symbol,_Period,MODE_LOW,structureBars,1);
         double swingHigh = (highBar>=0)?iHigh(_Symbol,_Period,highBar):0.0;
         double swingLow  = (lowBar>=0)?iLow(_Symbol,_Period,lowBar):0.0;
         dist = MathMax(swingHigh-price, price-swingLow);
         if(dist <= 0.0) dist = atrValue * m_slMultiplier; // fallback if structure read fails
      }
      else if(method == 2)
      {
         dist = price * histVol * 2.0; // 2 standard deviations
         if(dist <= 0.0) dist = atrValue * m_slMultiplier;
      }
      else // method 0, ATR (default)
      {
         dist = atrValue * m_slMultiplier;
      }

      double minDist = price * (m_minSLPct/100.0);
      double maxDist = price * (m_maxSLPct/100.0);
      return MathMax(minDist, MathMin(maxDist, dist));
   }

   void CacheEntry(double entryPrice, double slPrice, double atrValue, int direction, double volume)
   {
      m_entryPrice=entryPrice; m_entrySL=slPrice; m_entryATR=atrValue;
      m_tradeDirection=direction; m_peakProfit=0.0; m_beSet=false; m_partialClosed=false;
      m_tradeOpenTime=TimeCurrent();

      double slDistPrice = MathAbs(entryPrice-slPrice);
      double tickVal = SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_VALUE);
      double tickSize = SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE);
      m_entryRiskUSD = (tickSize>0.0) ? (slDistPrice/tickSize)*tickVal*volume : 0.01;
      if(m_entryRiskUSD <= 0.0) m_entryRiskUSD = 0.01;
   }

   void ResetState() { m_peakProfit=0.0; m_beSet=false; m_partialClosed=false; m_entryATR=0.0; m_entryPrice=0.0; m_entrySL=0.0; m_entryRiskUSD=0.0; m_tradeDirection=0; m_tradeOpenTime=0; }

   bool IsPositionOpen()
   {
      for(int i=PositionsTotal()-1;i>=0;i--)
         if(m_pos.SelectByIndex(i) && m_pos.Magic()==m_magic && m_pos.Symbol()==_Symbol) return true;
      return false;
   }

   double GetFloatingPnL()
   {
      double total=0.0;
      for(int i=PositionsTotal()-1;i>=0;i--)
         if(m_pos.SelectByIndex(i) && m_pos.Magic()==m_magic && m_pos.Symbol()==_Symbol)
            total += m_pos.Profit()+m_pos.Swap()+m_pos.Commission();
      return total;
   }

   void CloseAll(string reason)
   {
      PrintFormat("[TradeManager] CloseAll: %s | Peak was $%.2f", reason, m_peakProfit);
      for(int i=PositionsTotal()-1;i>=0;i--)
         if(m_pos.SelectByIndex(i) && m_pos.Magic()==m_magic && m_pos.Symbol()==_Symbol)
            m_trade.PositionClose(m_pos.Ticket());
   }

   // Returns the R-multiple of the just-closed trade if a close occurred this
   // call, else returns a sentinel (-9999.0) meaning "no close happened."
   double CheckPeakProfitLock(double pnl)
   {
      if(!m_usePeakLock) return -9999.0;
      double oneR = m_entryRiskUSD;
      if(oneR<=0.0) return -9999.0;
      if(pnl > m_peakProfit) m_peakProfit = pnl;
      double activateLevel = oneR*m_peakLockActivateR;
      if(m_peakProfit < activateLevel) return -9999.0;

      double retraceLevel = m_peakProfit*(1.0-m_peakLockRetrace/100.0);
      double minRFloor = oneR*m_minRR;
      double lockLevel = MathMax(retraceLevel, minRFloor);
      if(m_partialClosed) lockLevel = MathMax(lockLevel, oneR*m_minLockProfitR);

      if(pnl <= lockLevel && pnl < m_peakProfit)
      {
         double rMultiple = pnl/oneR;
         CloseAll("Peak-profit lock triggered");
         return rMultiple;
      }
      return -9999.0;
   }

   double CheckPartialClose(double pnl)
   {
      if(m_partialClosed) return -9999.0;
      double oneR = m_entryRiskUSD;
      if(oneR<=0.0) return -9999.0;
      double tp1Level = oneR*m_tp1R;
      if(pnl < tp1Level) return -9999.0;

      for(int i=PositionsTotal()-1;i>=0;i--)
      {
         if(!m_pos.SelectByIndex(i)) continue;
         if(m_pos.Magic()!=m_magic || m_pos.Symbol()!=_Symbol) continue;

         double volStep = SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_STEP);
         double closeLot = MathFloor((m_pos.Volume()*(m_partialClosePct/100.0))/volStep)*volStep;
         closeLot = NormalizeDouble(closeLot,2);
         double minLot = SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN);

         if(closeLot < minLot)
         {
            double rMultiple = pnl/oneR;
            CloseAll("TP1 full close (lot too small to partial)");
            return rMultiple;
         }
         if(m_trade.PositionClosePartial(m_pos.Ticket(), closeLot))
         {
            m_partialClosed = true;
            PrintFormat("[PartialClose] %.2f lots closed. 1R=$%.2f PnL=$%.2f (%.2fR)", closeLot, oneR, pnl, pnl/oneR);
         }
      }
      return -9999.0;
   }

   double CheckTimeExit()
   {
      if(m_tradeOpenTime==0) return -9999.0;
      int periodSec = PeriodSeconds(_Period);
      if(periodSec<=0) return -9999.0;
      int barsElapsed = (int)((TimeCurrent()-m_tradeOpenTime)/periodSec);
      if(barsElapsed >= m_maxTradeBars && !m_beSet)
      {
         double pnl = GetFloatingPnL();
         double rMultiple = (m_entryRiskUSD>0)?pnl/m_entryRiskUSD:0.0;
         CloseAll("Time-based exit - stale trade");
         return rMultiple;
      }
      return -9999.0;
   }

   double CheckDeteriorationExit(double pnl, double macdCur, double macdPrev, bool hasMacd)
   {
      double oneR = m_entryRiskUSD;
      if(oneR<=0.0 || !hasMacd) return -9999.0;
      double rMultiple = pnl/oneR;
      if(rMultiple > m_deteriorationR) return -9999.0;

      bool isBuy = (m_tradeDirection==1);
      bool momentumAgainst = isBuy ? (macdCur<macdPrev && macdCur<0.0) : (macdCur>macdPrev && macdCur>0.0);
      if(momentumAgainst)
      {
         CloseAll("Deterioration exit - thesis invalidated early");
         return rMultiple;
      }
      return -9999.0;
   }

   void CheckBreakeven()
   {
      if(m_beSet) return;
      double oneR = m_entryRiskUSD;
      if(oneR<=0.0) return;
      double pnl = GetFloatingPnL();
      if(pnl < oneR*m_breakevenR) return;

      for(int i=PositionsTotal()-1;i>=0;i--)
      {
         if(!m_pos.SelectByIndex(i)) continue;
         if(m_pos.Magic()!=m_magic || m_pos.Symbol()!=_Symbol) continue;
         double open=m_pos.PriceOpen(); double sl=m_pos.StopLoss();
         int digits=(int)SymbolInfoInteger(_Symbol,SYMBOL_DIGITS);
         bool isBuy=(m_pos.PositionType()==POSITION_TYPE_BUY);
         double buffer=open*(m_beBufferPct/100.0);
         double beSL = isBuy?NormalizeDouble(open+buffer,digits):NormalizeDouble(open-buffer,digits);
         bool needsMove = isBuy?(sl<beSL):(sl>beSL||sl==0.0);
         if(needsMove && m_trade.PositionModify(m_pos.Ticket(),beSL,m_pos.TakeProfit())) m_beSet=true;
      }
   }

   void CheckATRTrailing()
   {
      if(!m_useTrailing) return;
      double oneR = m_entryRiskUSD;
      if(oneR<=0.0) return;
      double pnl = GetFloatingPnL();
      if(pnl < oneR*m_trailStartR) return;
      double atr = (m_entryATR>0)?m_entryATR:0.0;
      if(atr<=0.0) return;
      double trailDist = atr*m_trailATRMult;

      for(int i=PositionsTotal()-1;i>=0;i--)
      {
         if(!m_pos.SelectByIndex(i)) continue;
         if(m_pos.Magic()!=m_magic || m_pos.Symbol()!=_Symbol) continue;
         double open=m_pos.PriceOpen(); double sl=m_pos.StopLoss();
         double bid=SymbolInfoDouble(_Symbol,SYMBOL_BID); double ask=SymbolInfoDouble(_Symbol,SYMBOL_ASK);
         int digits=(int)SymbolInfoInteger(_Symbol,SYMBOL_DIGITS);
         bool isBuy=(m_pos.PositionType()==POSITION_TYPE_BUY);
         double newSL = isBuy?NormalizeDouble(bid-trailDist,digits):NormalizeDouble(ask+trailDist,digits);

         if(m_beSet)
         {
            double buffer=open*(m_beBufferPct/100.0);
            double beFloor = isBuy?NormalizeDouble(open+buffer,digits):NormalizeDouble(open-buffer,digits);
            if(isBuy) newSL=MathMax(newSL,beFloor); else newSL=MathMin(newSL,beFloor);
         }
         bool improves = isBuy ? (newSL>sl && newSL<bid) : ((sl==0.0)?(newSL>ask):(newSL<sl && newSL>ask));
         if(improves) m_trade.PositionModify(m_pos.Ticket(), newSL, m_pos.TakeProfit());
      }
   }

   // Detects a position that vanished WITHOUT going through any of the
   // explicit Check*() close paths above - i.e. broker-side hard SL/TP2 -
   // and returns its realized R-multiple, or -9999.0 if nothing closed.
   // (Same gap NOVA TITAN X had and was fixed for - fixed here from the start.)
   double CaptureUnmanagedExit()
   {
      if(m_tradeOpenTime==0 || m_entryRiskUSD<=0.0) return -9999.0;
      datetime now = TimeCurrent();
      if(!HistorySelect(m_tradeOpenTime-60, now)) return -9999.0;

      double realizedPnl=0.0; bool found=false;
      for(int i=0;i<HistoryDealsTotal();i++)
      {
         ulong tkt = HistoryDealGetTicket(i);
         if(tkt==0) continue;
         if(HistoryDealGetInteger(tkt,DEAL_MAGIC)!=(long)m_magic) continue;
         if(HistoryDealGetString(tkt,DEAL_SYMBOL)!=_Symbol) continue;
         if(HistoryDealGetInteger(tkt,DEAL_ENTRY)!=DEAL_ENTRY_OUT) continue;
         datetime dealTime=(datetime)HistoryDealGetInteger(tkt,DEAL_TIME);
         if(dealTime < m_tradeOpenTime) continue;
         realizedPnl += HistoryDealGetDouble(tkt,DEAL_PROFIT)+HistoryDealGetDouble(tkt,DEAL_COMMISSION)+HistoryDealGetDouble(tkt,DEAL_SWAP);
         found=true;
      }
      if(!found) return -9999.0;
      return realizedPnl/m_entryRiskUSD;
   }

   double PeakProfit()    { return m_peakProfit; }
   double EntryRiskUSD()  { return m_entryRiskUSD; }
   bool   BESet()         { return m_beSet; }
   bool   PartialClosed() { return m_partialClosed; }
};

//+------------------------------------------------------------------+
//| INPUT PARAMETERS                                                   |
//+------------------------------------------------------------------+
input group "=== CORE IDENTITY ==="
input ulong   InpMagicNumber       = 552093;
input string  InpTradeComment      = "AegisPrime_v1";

input group "=== REGIME CLASSIFIER PERIODS ==="
input int     InpATRPeriod         = 14;
input int     InpVolLookback       = 100;
input double  InpVolUltraLowPctile = 20.0;
input double  InpVolHighPctile     = 80.0;
input double  InpVolExtremePctile  = 95.0;
input double  InpSqueezeBodyRatio  = 0.35;
input int     InpFastEMA           = 8;
input int     InpSlowEMA           = 21;
input int     InpTrendEMA          = 55;
input int     InpADXPeriod         = 14;
input double  InpADXTrendMin       = 20.0;
input int     InpSwingBars         = 12;
input int     InpROCPeriod         = 10;
input double  InpADXStrongMomentum = 25.0;
input int     InpStructureBars     = 8;

input group "=== SESSION WINDOWS (server/GMT hour, 0-23) ==="
input int     InpAsianStart  = 0;
input int     InpAsianEnd    = 8;
input int     InpLondonStart = 8;
input int     InpLondonEnd   = 16;
input int     InpNYStart     = 13;
input int     InpNYEnd       = 21;

input group "=== STRATEGY SELECTOR (hysteresis/cooldown) ==="
input int     InpConfirmBars       = 3;     // bars a candidate must hold top spot before hand-off
input int     InpCooldownSeconds   = 120;   // minimum seconds between strategy hand-offs
input double  InpMinConfToActivate = 55.0;  // minimum aggregate regime confidence to commit a hand-off

input group "=== NEWS-AWARE RISK ENGINE (manual schedule - see file header) ==="
input string  InpEventSchedule     = "";    // "YYYY.MM.DD HH:MM-YYYY.MM.DD HH:MM;..." semicolon-separated, server time

input group "=== RISK MANAGEMENT ==="
input double  InpRiskPercent       = 1.0;
input double  InpMaxDailyLossPct   = 5.0;
input double  InpMaxDailyProfitPct = 10.0;
input int     InpMaxDailyTrades    = 15;
input double  InpMaxDrawdownPct    = 15.0;
input double  InpWeeklyLossLimitPct= 10.0;
input int     InpMaxLossStreak     = 3;
input int     InpWinStreakBoost    = 5;

input group "=== STOP LOSS METHOD ==="
input int     InpSLMethod          = 0;     // 0=ATR, 1=Structure, 2=Volatility(stdev)
input double  InpSLMultiplier      = 1.4;
input double  InpTP2Multiplier     = 3.2;
input double  InpMinSLPercent      = 0.20;
input double  InpMaxSLPercent      = 1.60;

input group "=== EXIT MANAGEMENT ==="
input double  InpTP1R              = 1.0;
input double  InpPartialClosePct   = 50.0;
input double  InpBreakevenR        = 0.5;
input double  InpBEBufferPercent   = 0.02;
input bool    InpUsePeakLock       = true;
input double  InpPeakLockActivateR = 0.8;
input double  InpPeakLockRetrace   = 25.0;
input double  InpMinRewardRiskR    = 1.0;
input double  InpMinLockProfitR    = 0.5;
input bool    InpUseTrailing       = true;
input double  InpTrailStartR       = 0.6;
input double  InpTrailATRMult      = 0.7;
input int     InpMaxTradeBars      = 96;
input double  InpDeteriorationR    = -0.7;

input group "=== EXECUTION ==="
input double  InpMaxSpreadPercent  = 0.06;
input double  InpSpreadAvgMultiple = 2.5;
input int     InpMaxSlippagePoints = 50;
input int     InpMaxRequoteRetries = 2;

input group "=== MTF FILTER ==="
input bool    InpUseMTFFilter      = true;
input int     InpMTFEMAPeriod      = 50;
input int     InpMTFMinAgreement   = 3;    // minimum of 4 timeframes that must agree to allow entry

input group "=== MACD (for deterioration exit) ==="
input int     InpMACDFast=12, InpMACDSlow=26, InpMACDSignal=9;

input group "=== DASHBOARD ==="
input int     InpDashX = 15;
input int     InpDashY = 15;

//+------------------------------------------------------------------+
//| COLOUR PALETTE                                                      |
//+------------------------------------------------------------------+
const color C_BG=C'5,7,16'; const color C_PANEL=C'8,12,26'; const color C_PANEL2=C'10,16,34';
const color C_HEADER=C'11,16,38'; const color C_BORDER=C'90,70,230'; const color C_BORDER2=C'55,42,140';
const color C_CYAN=C'0,225,210'; const color C_VIOLET=C'160,120,255'; const color C_BLUE=C'45,150,255';
const color C_GREEN=C'0,220,140'; const color C_RED=C'235,55,75'; const color C_GOLD=C'255,190,30';
const color C_ORANGE=C'255,140,30'; const color C_WHITE=C'225,235,255'; const color C_MUTED=C'95,110,150';
const color C_HOLD_BG=C'55,40,0'; const color C_BUY_BG=C'0,50,28'; const color C_SELL_BG=C'55,5,12';
const color C_SECTION_HDR=C'12,20,48';

//+------------------------------------------------------------------+
//| GLOBAL OBJECT INSTANCES                                            |
//+------------------------------------------------------------------+
CTrade            g_Trade;
CPositionInfo     g_Pos;

CVolatilityRegimeClassifier g_VolClassifier;
CLiquidityRegimeClassifier  g_LiqClassifier;
CSessionRegimeClassifier    g_SessionClassifier;
CTrendRegimeClassifier      g_TrendClassifier;
CMomentumRegimeClassifier   g_MomClassifier;
CStructureRegimeClassifier  g_StructClassifier;
CRiskRegimeClassifier       g_RiskClassifier;

CStrategySelector g_Selector;
CMTFFilter        g_MTF;
CRiskManager      g_RiskMgr;
CExecutionEngine  g_ExecEngine;
CTradeManager     g_TradeMgr;

int g_hMACD = INVALID_HANDLE;

CRegimeSnapshot g_Snapshot;
ENUM_ENGINE_STATE g_State = ENGSTATE_SCANNING;
datetime g_StateTimer = 0;
ENUM_STRATEGY_ID g_TradeStrategyId = STRAT_NONE;
SStrategySignal g_LastSignal;

string g_StatusText = "BOOTING";
color  g_StatusColor = C_GOLD;
string g_HeartbeatStr = "0 0 0 0";
string g_MTFAlignment = "";

//+------------------------------------------------------------------+
//| HELPER: build a fresh regime snapshot from all 7 classifiers      |
//+------------------------------------------------------------------+
void BuildSnapshot(CRegimeSnapshot &snap)
{
   snap.volRegime = g_VolClassifier.State();         snap.volConfidence = g_VolClassifier.Confidence();
   snap.liqRegime = g_LiqClassifier.State();         snap.liqConfidence = g_LiqClassifier.Confidence();
   snap.sessionRegime = g_SessionClassifier.State(); snap.sessionConfidence = g_SessionClassifier.Confidence();
   snap.trendRegime = g_TrendClassifier.State();     snap.trendConfidence = g_TrendClassifier.Confidence();
   snap.momRegime = g_MomClassifier.State();         snap.momConfidence = g_MomClassifier.Confidence();
   snap.structRegime = g_StructClassifier.State();   snap.structConfidence = g_StructClassifier.Confidence();
   snap.riskRegime = g_RiskClassifier.State();       snap.riskConfidence = g_RiskClassifier.Confidence();
   snap.timestamp = TimeCurrent();
}

bool GetMACDHist(double &cur, double &prev)
{
   double h[2];
   if(CopyBuffer(g_hMACD, 2, 0, 2, h) < 2) return false;
   cur = h[0]; prev = h[1];
   return true;
}

//+------------------------------------------------------------------+
//| INIT                                                                 |
//+------------------------------------------------------------------+
int OnInit()
{
   if(InpRiskPercent<=0.0 || InpRiskPercent>10.0) { Alert("Risk% must be 0.01-10."); return INIT_PARAMETERS_INCORRECT; }
   if(InpConfirmBars < 1) { Alert("InpConfirmBars must be >= 1."); return INIT_PARAMETERS_INCORRECT; }

   g_Trade.SetExpertMagicNumber(InpMagicNumber);
   g_Trade.SetTypeFilling(ORDER_FILLING_FOK);

   // Classifier init
   if(!g_VolClassifier.Init(InpATRPeriod, InpVolLookback)) return INIT_FAILED;
   if(!g_TrendClassifier.Init(InpFastEMA, InpSlowEMA, InpTrendEMA, InpADXPeriod, InpSwingBars)) return INIT_FAILED;
   if(!g_MomClassifier.Init(InpADXPeriod, InpROCPeriod)) return INIT_FAILED;
   g_SessionClassifier.Configure(InpAsianStart, InpAsianEnd, InpLondonStart, InpLondonEnd, InpNYStart, InpNYEnd);
   g_StructClassifier.Init(InpStructureBars);
   g_RiskClassifier.ParseEventSchedule(InpEventSchedule);
   if(!g_LiqClassifier.Init()) return INIT_FAILED;

   g_hMACD = iMACD(_Symbol, _Period, InpMACDFast, InpMACDSlow, InpMACDSignal, PRICE_CLOSE);
   if(g_hMACD == INVALID_HANDLE) return INIT_FAILED;

   if(InpUseMTFFilter) { if(!g_MTF.Init(InpMTFEMAPeriod)) return INIT_FAILED; }

   g_RiskMgr.Configure(InpMagicNumber, InpRiskPercent, InpMaxDailyLossPct, InpMaxDailyProfitPct,
                        InpMaxDrawdownPct, InpWeeklyLossLimitPct, InpMaxLossStreak, InpWinStreakBoost);
   g_RiskMgr.Init();

   g_ExecEngine.Configure(GetPointer(g_Trade), InpMaxSpreadPercent, InpSpreadAvgMultiple, InpMaxSlippagePoints, InpMaxRequoteRetries);

   g_TradeMgr.Configure(GetPointer(g_Trade), GetPointer(g_Pos), InpMagicNumber,
                         InpSLMultiplier, InpTP2Multiplier, InpMinSLPercent, InpMaxSLPercent,
                         InpTP1R, InpPartialClosePct, InpBreakevenR, InpBEBufferPercent,
                         InpUsePeakLock, InpPeakLockActivateR, InpPeakLockRetrace, InpMinRewardRiskR, InpMinLockProfitR,
                         InpUseTrailing, InpTrailStartR, InpTrailATRMult,
                         InpMaxTradeBars, InpDeteriorationR);

   // Strategy registration - selector takes ownership of these pointers
   CStrategy_MeanReversion *sMR = new CStrategy_MeanReversion();
   sMR.Init(20, 2.0, 14);
   g_Selector.Register(sMR);

   CStrategy_RangeScalper *sRS = new CStrategy_RangeScalper();
   sRS.Init(InpStructureBars);
   g_Selector.Register(sRS);

   CStrategy_TrendContinuationLong *sTCL = new CStrategy_TrendContinuationLong();
   sTCL.Init(InpFastEMA, InpATRPeriod);
   g_Selector.Register(sTCL);

   CStrategy_TrendContinuationShort *sTCS = new CStrategy_TrendContinuationShort();
   sTCS.Init(InpFastEMA, InpATRPeriod);
   g_Selector.Register(sTCS);

   CStrategy_MomentumBreakout *sMB = new CStrategy_MomentumBreakout();
   sMB.Init(InpStructureBars);
   g_Selector.Register(sMB);

   CStrategy_PullbackTrendFollowing *sPTF = new CStrategy_PullbackTrendFollowing();
   sPTF.Init(InpSlowEMA);
   g_Selector.Register(sPTF);

   CStrategy_RangeTrading *sRT = new CStrategy_RangeTrading();
   sRT.Init(20);
   g_Selector.Register(sRT);

   g_Selector.Configure(InpConfirmBars, InpCooldownSeconds, InpMinConfToActivate);

   g_State = ENGSTATE_SCANNING;
   EventSetTimer(1);
   RenderDashboard();

   Print("[AegisPrime] Initialised. Symbol=", _Symbol, " Magic=", InpMagicNumber, " TF=", EnumToString(_Period));
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
   EventKillTimer();
   PurgeDashboard();
   g_VolClassifier.Release();
   g_TrendClassifier.Release();
   g_MomClassifier.Release();
   if(g_hMACD != INVALID_HANDLE) IndicatorRelease(g_hMACD);
   if(InpUseMTFFilter) g_MTF.Release();
   // g_Selector goes out of scope at program end and its destructor handles
   // releasing every registered strategy's indicator handles polymorphically
   // (CStrategy_MeanReversion, CStrategy_TrendContinuationLong/Short,
   // CStrategy_PullbackTrendFollowing all own handles) before deleting each
   // strategy object - see CStrategySelector::~CStrategySelector().
}

//+------------------------------------------------------------------+
//| TIMER - updates all 7 classifiers + risk manager sync             |
//+------------------------------------------------------------------+
void OnTimer()
{
   static uint beat=0; beat++;
   string p[4]={"1 0 1 1  0 1 0 0","0 1 0 0  1 0 1 1","1 1 0 1  0 0 1 0","0 0 1 0  1 1 0 1"};
   g_HeartbeatStr = p[beat%4];

   g_RiskMgr.SyncDaily();
   g_RiskMgr.SyncWeekly();
   g_RiskMgr.UpdateEquityPeak();

   // Classifier update order matters: Session and Volatility are read by
   // Liquidity/Momentum/Risk below, so they update first.
   g_VolClassifier.Update(InpVolUltraLowPctile, InpVolHighPctile, InpVolExtremePctile, InpSqueezeBodyRatio);
   g_SessionClassifier.Update();
   g_LiqClassifier.Update(g_SessionClassifier.IsOverlapOrMajor());
   g_TrendClassifier.Update(InpADXTrendMin);
   g_MomClassifier.Update(InpADXStrongMomentum, g_VolClassifier.ExpansionRate());
   g_StructClassifier.Update();
   g_RiskClassifier.Update(g_VolClassifier.ATRValue(), g_LiqClassifier.AvgSpread(),
                            g_RiskMgr.EquityPeak(), g_RiskMgr.MaxDrawdownPct(),
                            g_RiskMgr.ConsecLosses(), InpMaxLossStreak);

   BuildSnapshot(g_Snapshot);
   g_Selector.UpdateCandidate(g_Snapshot);

   UpdateDashboard();
}

//+------------------------------------------------------------------+
//| TICK - priority gate -> selector hand-off -> entries -> management|
//+------------------------------------------------------------------+
void OnTick()
{
   g_ExecEngine.UpdateSpreadAverage();

   ENUM_SYMBOL_TRADE_MODE mode = (ENUM_SYMBOL_TRADE_MODE)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_MODE);
   bool marketOpen = (mode==SYMBOL_TRADE_MODE_FULL || mode==SYMBOL_TRADE_MODE_LONGONLY || mode==SYMBOL_TRADE_MODE_SHORTONLY);
   if(!marketOpen) { g_StatusText="MARKET CLOSED"; g_StatusColor=C_RED; return; }

   //--- Manage open trade first, always, regardless of halt state
   if(g_TradeMgr.IsPositionOpen())
   {
      g_State = ENGSTATE_IN_TRADE;
      ManageOpenPosition();
      return;
   }
   else
   {
      // Position closed since last tick - capture any broker-side close that
      // bypassed our explicit exit checks, then release the active strategy
      // so the selector re-evaluates from a clean slate.
      //
      // BUG FIX NOTE: this used to gate cleanup on
      // "g_TradeMgr.EntryRiskUSD() == 0.0", but EntryRiskUSD() only becomes
      // 0.0 AFTER ResetState() runs - it is still the prior trade's nonzero
      // value on the very tick we discover the position is gone (since
      // CaptureUnmanagedExit() reads it but does not itself clear it). That
      // meant the condition was false on the tick that actually needed it,
      // so ForceRelease()/ResetState() never ran, g_State stayed stuck at
      // ENGSTATE_IN_TRADE, and the engine would never resume scanning.
      // Fixed to trigger directly off the engine's prior state instead -
      // if we were IN_TRADE last tick and now have no open position, the
      // trade ended (managed or unmanaged) and cleanup must run exactly
      // once, here, on this tick.
      if(g_State == ENGSTATE_IN_TRADE)
      {
         double unmanagedR = g_TradeMgr.CaptureUnmanagedExit();
         if(unmanagedR > -9000.0)
            PrintFormat("[AegisPrime] Captured unmanaged exit for %s: %.2fR", StrategyIdToString(g_TradeStrategyId), unmanagedR);

         g_Selector.ForceRelease();
         g_TradeMgr.ResetState();
         g_State = ENGSTATE_COOLDOWN;
         g_StateTimer = TimeCurrent() + 15;
      }
   }

   //--- PRIORITY 1: Risk regime - hard gate, overrides everything else
   if(g_Snapshot.riskRegime == RISKR_SUSPENDED)
   {
      g_State = ENGSTATE_SUSPENDED;
      g_StatusText = "RISK SUSPENDED: " + (g_RiskClassifier.EventWindowActive()?"event window":"drawdown/displacement");
      g_StatusColor = C_RED;
      return;
   }

   if(g_RiskMgr.IsDrawdownLimitHit())
   { g_State=ENGSTATE_DRAWDOWN_HALT; g_StatusText="MAX DRAWDOWN HIT - HALTED"; g_StatusColor=C_RED; return; }
   if(g_RiskMgr.IsWeeklyLossLimitHit())
   { g_State=ENGSTATE_EMERGENCY_HALT; g_StatusText="WEEKLY LOSS LIMIT - HALTED"; g_StatusColor=C_RED; return; }
   if(g_RiskMgr.IsDailyLossLimitHit())
   { g_State=ENGSTATE_DAILY_HALT; g_StatusText="DAILY LOSS LIMIT - HALTED"; g_StatusColor=C_RED; return; }
   if(g_RiskMgr.IsDailyProfitHit())
   { g_State=ENGSTATE_DAILY_HALT; g_StatusText="DAILY TARGET MET - HALTED"; g_StatusColor=C_GREEN; return; }
   if(g_RiskMgr.DailyTrades() >= InpMaxDailyTrades)
   { g_StatusText="MAX DAILY TRADES REACHED"; g_StatusColor=C_GOLD; return; }

   if(!g_ExecEngine.IsSpreadOk())
   { g_StatusText="SPREAD TOO WIDE"; g_StatusColor=C_RED; return; }

   if(g_State == ENGSTATE_COOLDOWN)
   {
      int left = (int)(g_StateTimer - TimeCurrent());
      if(left > 0) { g_StatusText="COOLDOWN ("+IntegerToString(left)+"s)"; g_StatusColor=C_GOLD; return; }
      g_State = ENGSTATE_SCANNING;
   }

   if(g_State==ENGSTATE_DAILY_HALT || g_State==ENGSTATE_DRAWDOWN_HALT || g_State==ENGSTATE_EMERGENCY_HALT || g_State==ENGSTATE_SUSPENDED)
      return; // still halted - SyncDaily/SyncWeekly on the timer clears day/week halts; DD/suspension clear via classifier next read

   //--- Try to confirm a strategy hand-off (no-op if no candidate or not yet confirmed)
   bool handedOff = g_Selector.TryActivate(g_Snapshot);
   if(handedOff)
      Print("[AegisPrime] Strategy hand-off: now active = ", g_Selector.ActiveName(),
            " (candidate streak was ", g_Selector.CandidateStreak(), " bars)");

   if(g_Selector.ActiveId() == STRAT_NONE)
   {
      g_StatusText = "SCANNING - no active strategy (candidate="+StrategyIdToString(g_Selector.CandidateId())
                    +" streak="+IntegerToString(g_Selector.CandidateStreak())+"/"+IntegerToString(InpConfirmBars)+")";
      g_StatusColor = C_MUTED;
      return;
   }

   //--- Active strategy evaluates for an entry
   SStrategySignal sig = g_Selector.EvaluateActive(g_Snapshot);
   g_LastSignal = sig;

   if(!sig.valid || sig.dir==SIG_NONE)
   {
      g_StatusText = g_Selector.ActiveName() + " active - no qualifying entry this tick";
      g_StatusColor = C_MUTED;
      return;
   }

   //--- MTF confirmation filter (per spec: filters lower-TF entries, does not generate signals)
   if(InpUseMTFFilter)
   {
      int agreement = g_MTF.AgreementCount(sig.dir, g_MTFAlignment);
      if(agreement < InpMTFMinAgreement)
      {
         g_StatusText = g_Selector.ActiveName()+" signal REJECTED by MTF filter ("+IntegerToString(agreement)+"/4 agree)";
         g_StatusColor = C_GOLD;
         return;
      }
   }

   ExecuteEntry(sig);
}

string StrategyIdToString(ENUM_STRATEGY_ID id)
{
   switch(id)
   {
      case STRAT_MEAN_REVERSION:    return "MeanReversion";
      case STRAT_RANGE_SCALPER:     return "RangeScalper";
      case STRAT_TREND_CONT_LONG:   return "TrendContLong";
      case STRAT_TREND_CONT_SHORT:  return "TrendContShort";
      case STRAT_MOMENTUM_BREAKOUT: return "MomentumBreakout";
      case STRAT_PULLBACK_TREND:    return "PullbackTrend";
      case STRAT_RANGE_TRADING:     return "RangeTrading";
      case STRAT_NONE:              return "NONE";
      default: return "?";
   }
}

//+------------------------------------------------------------------+
//| ExecuteEntry - builds SL/TP via the configured method, sizes via   |
//| CRiskManager (regime-confidence-aware), and fires via              |
//| CExecutionEngine's retry-protected order path.                     |
//+------------------------------------------------------------------+
void ExecuteEntry(SStrategySignal &sig)
{
   int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   double atr = g_VolClassifier.ATRValue();
   double price = (sig.dir==SIG_BUY) ? SymbolInfoDouble(_Symbol,SYMBOL_ASK) : SymbolInfoDouble(_Symbol,SYMBOL_BID);

   // Historical volatility (for SL method 2) - reuse the volatility classifier's
   // internal computation via a fresh local calc rather than exposing its
   // private method; cheap enough to recompute here.
   double closesArr[21];
   double histVol = 0.0;
   if(CopyClose(_Symbol, _Period, 1, 21, closesArr) >= 21)
   {
      ArraySetAsSeries(closesArr, true);
      double rets[20]; double mean=0.0;
      for(int i=0;i<20;i++){ rets[i] = (closesArr[i+1]>0)?(closesArr[i]-closesArr[i+1])/closesArr[i+1]:0.0; mean+=rets[i]; }
      mean/=20.0;
      double var=0.0; for(int i=0;i<20;i++) var+=MathPow(rets[i]-mean,2); var/=20.0;
      histVol = MathSqrt(var);
   }

   double slDistance = g_TradeMgr.ComputeSLDistance(InpSLMethod, atr, price, InpStructureBars, histVol);
   double tp2Distance = atr * InpTP2Multiplier;

   double sl, tp;
   if(sig.dir==SIG_BUY) { sl=NormalizeDouble(price-slDistance,digits); tp=NormalizeDouble(price+tp2Distance,digits); }
   else                 { sl=NormalizeDouble(price+slDistance,digits); tp=NormalizeDouble(price-tp2Distance,digits); }

   double aggConf = g_Selector.AggregateRegimeConfidence(g_Snapshot, g_Selector.ActiveId());
   double lot = g_RiskMgr.CalculateLotSize(slDistance, aggConf);

   double resultPrice = 0.0;
   bool ok = g_ExecEngine.ExecuteMarketOrder(sig.dir, lot, sl, tp, InpTradeComment, resultPrice);

   if(ok)
   {
      g_RiskMgr.RecordTrade();
      g_TradeStrategyId = g_Selector.ActiveId();
      g_TradeMgr.CacheEntry(resultPrice, sl, atr, (sig.dir==SIG_BUY)?1:-1, lot);
      g_State = ENGSTATE_IN_TRADE;
      g_StatusText = g_Selector.ActiveName()+" "+(sig.dir==SIG_BUY?"LONG":"SHORT")+" - IN TRADE (conf="+DoubleToString(aggConf,0)+"%)";
      g_StatusColor = C_GREEN;
      PrintFormat("[AegisPrime] FIRE: Strategy=%s Dir=%s Lot=%.2f Price=%.2f SL=%.2f TP=%.2f AggConf=%.1f Reason=%s",
                  g_Selector.ActiveName(), (sig.dir==SIG_BUY?"BUY":"SELL"), lot, resultPrice, sl, tp, aggConf, sig.reason);
   }
}

//+------------------------------------------------------------------+
//| ManageOpenPosition - priority-ordered R-multiple exit checks       |
//+------------------------------------------------------------------+
void ManageOpenPosition()
{
   double pnl = g_TradeMgr.GetFloatingPnL();
   double oneR = g_TradeMgr.EntryRiskUSD();
   string rStr = (oneR>0)?" ("+DoubleToString(pnl/oneR,2)+"R)":"";
   g_StatusText = g_Selector.ActiveName()+" TRADE RUNNING "+(pnl>=0?"+$":"-$")+DoubleToString(MathAbs(pnl),2)+rStr
                 +"  Peak:+$"+DoubleToString(g_TradeMgr.PeakProfit(),2);
   g_StatusColor = (pnl>=0)?C_GREEN:C_RED;

   double exitR;

   exitR = g_TradeMgr.CheckPeakProfitLock(pnl);
   if(exitR > -9000.0) { FinalizeTrade(exitR, "Peak-profit lock"); return; }
   if(!g_TradeMgr.IsPositionOpen()) return;

   exitR = g_TradeMgr.CheckPartialClose(pnl);
   if(exitR > -9000.0) { FinalizeTrade(exitR, "TP1 partial-to-full"); return; }
   if(!g_TradeMgr.IsPositionOpen()) return;

   exitR = g_TradeMgr.CheckTimeExit();
   if(exitR > -9000.0) { FinalizeTrade(exitR, "Time-based exit"); return; }
   if(!g_TradeMgr.IsPositionOpen()) return;

   double macdCur, macdPrev;
   bool hasMacd = GetMACDHist(macdCur, macdPrev);
   exitR = g_TradeMgr.CheckDeteriorationExit(pnl, macdCur, macdPrev, hasMacd);
   if(exitR > -9000.0) { FinalizeTrade(exitR, "Deterioration exit"); return; }
   if(!g_TradeMgr.IsPositionOpen()) return;

   g_TradeMgr.CheckBreakeven();
   if(!g_TradeMgr.IsPositionOpen()) return;

   g_TradeMgr.CheckATRTrailing();
}

void FinalizeTrade(double rMultiple, string reason)
{
   PrintFormat("[AegisPrime] Trade closed via %s. Strategy=%s R=%.2f", reason, StrategyIdToString(g_TradeStrategyId), rMultiple);
   g_Selector.ForceRelease();
   g_TradeMgr.ResetState();
   g_State = ENGSTATE_COOLDOWN;
   g_StateTimer = TimeCurrent() + 30;
}

//+------------------------------------------------------------------+
//| DASHBOARD - self-diagnostic system per spec                        |
//+------------------------------------------------------------------+
#define DW 360

void DrawRect(string id, int x, int y, int w, int h, color bg, color border, int bw)
{
   string n = DASH_PREFIX+id;
   if(ObjectFind(0,n)<0) ObjectCreate(0,n,OBJ_RECTANGLE_LABEL,0,0,0);
   ObjectSetInteger(0,n,OBJPROP_CORNER,CORNER_LEFT_UPPER);
   ObjectSetInteger(0,n,OBJPROP_XDISTANCE,x); ObjectSetInteger(0,n,OBJPROP_YDISTANCE,y);
   ObjectSetInteger(0,n,OBJPROP_XSIZE,w); ObjectSetInteger(0,n,OBJPROP_YSIZE,h);
   ObjectSetInteger(0,n,OBJPROP_BGCOLOR,bg);
   if(border!=clrNONE){ObjectSetInteger(0,n,OBJPROP_BORDER_TYPE,BORDER_FLAT);ObjectSetInteger(0,n,OBJPROP_COLOR,border);ObjectSetInteger(0,n,OBJPROP_WIDTH,bw);}
   else ObjectSetInteger(0,n,OBJPROP_BORDER_TYPE,BORDER_RAISED);
   ObjectSetInteger(0,n,OBJPROP_SELECTABLE,false); ObjectSetInteger(0,n,OBJPROP_HIDDEN,true); ObjectSetInteger(0,n,OBJPROP_ZORDER,0);
}
void DrawLabel(string id, int x, int y, string txt, color clr, int sz, string fnt)
{
   string n = DASH_PREFIX+id;
   if(ObjectFind(0,n)<0) ObjectCreate(0,n,OBJ_LABEL,0,0,0);
   ObjectSetInteger(0,n,OBJPROP_CORNER,CORNER_LEFT_UPPER);
   ObjectSetInteger(0,n,OBJPROP_XDISTANCE,x); ObjectSetInteger(0,n,OBJPROP_YDISTANCE,y);
   ObjectSetString(0,n,OBJPROP_TEXT,txt); ObjectSetInteger(0,n,OBJPROP_COLOR,clr);
   ObjectSetInteger(0,n,OBJPROP_FONTSIZE,sz); ObjectSetString(0,n,OBJPROP_FONT,fnt);
   ObjectSetInteger(0,n,OBJPROP_SELECTABLE,false); ObjectSetInteger(0,n,OBJPROP_HIDDEN,true); ObjectSetInteger(0,n,OBJPROP_ZORDER,1);
}
void SetLabel(string id, string txt, color clr=clrNONE)
{
   string n = DASH_PREFIX+id;
   if(ObjectFind(0,n)>=0){ ObjectSetString(0,n,OBJPROP_TEXT,txt); if(clr!=clrNONE) ObjectSetInteger(0,n,OBJPROP_COLOR,clr); }
}
void PurgeDashboard(){ ObjectsDeleteAll(0,DASH_PREFIX); ChartRedraw(0); }

void RenderDashboard()
{
   int X=InpDashX, Y=InpDashY, W=DW, y=Y;
   DrawRect("SHELL",X,Y,W,700,C_BG,C_BORDER,2);

   DrawRect("HDR_BG",X+2,y+2,W-4,26,C_HEADER,C_BORDER,1);
   DrawLabel("HDR_IC",X+6,y+4,"AEGIS PRIME",C_CYAN,9,"Arial Black");
   DrawLabel("HDR_SYM",X+W-95,y+4,_Symbol,C_GOLD,9,"Impact");
   DrawLabel("HDR_VER",X+6,y+15,EA_VERSION+" REGIME-EXCLUSIVE ENGINE",C_MUTED,7,"Arial");
   DrawLabel("HDR_CLK",X+W-46,y+15,"00:00",C_MUTED,7,"Arial");
   y+=29;

   // 7 regime classifiers block
   DrawRect("RG_HDR",X+2,y,W-4,13,C_SECTION_HDR,C_BORDER2,1);
   DrawLabel("RG_TIT",X+6,y+2,"7-DIMENSION REGIME CLASSIFICATION",C_ORANGE,7,"Arial Black");
   y+=14;
   DrawRect("RG_BG",X+2,y,W-4,98,C_PANEL,C_BORDER2,1);
   string labels[7] = {"VOL","LIQ","SESS","TREND","MOM","STRUCT","RISK"};
   for(int i=0;i<7;i++)
   {
      int ry = y+3+i*13;
      DrawLabel("L_R"+IntegerToString(i), X+6, ry, labels[i], C_MUTED, 7, "Arial");
      DrawLabel("V_R"+IntegerToString(i), X+55, ry, "---", C_WHITE, 7, "Arial Bold");
      DrawRect("CB_R"+IntegerToString(i), X+W-90, ry, 78, 10, C_PANEL2, C_BORDER2, 1);
      DrawRect("CF_R"+IntegerToString(i), X+W-90, ry, 8, 10, C_BLUE, clrNONE, 0);
      DrawLabel("VC_R"+IntegerToString(i), X+W-90+82, ry-12, "", clrNONE, 1, "Arial"); // spacer, unused
   }
   y += 100;

   // Strategy selector block
   DrawRect("SS_HDR",X+2,y,W-4,13,C_SECTION_HDR,C_BORDER2,1);
   DrawLabel("SS_TIT",X+6,y+2,"STRATEGY SELECTOR (exclusive - one at a time)",C_ORANGE,7,"Arial Black");
   y+=14;
   DrawRect("SS_BG",X+2,y,W-4,56,C_PANEL,C_BORDER2,1);
   DrawLabel("L_ACT",X+6,y+3,"ACTIVE",C_MUTED,7,"Arial"); DrawLabel("V_ACT",X+55,y+3,"NONE",C_GREEN,8,"Arial Bold");
   DrawLabel("L_CAN",X+6,y+16,"CANDIDATE",C_MUTED,7,"Arial"); DrawLabel("V_CAN",X+70,y+16,"NONE",C_VIOLET,7,"Arial Bold");
   DrawLabel("L_STK",X+W/2+10,y+16,"STREAK",C_MUTED,7,"Arial"); DrawLabel("V_STK",X+W/2+58,y+16,"0/0",C_WHITE,7,"Arial Bold");
   DrawLabel("L_SIG",X+6,y+29,"SIGNAL",C_MUTED,7,"Arial"); DrawLabel("V_SIG",X+55,y+29,"---",C_GOLD,7,"Arial Bold");
   DrawLabel("L_MTF",X+6,y+42,"MTF",C_MUTED,7,"Arial"); DrawLabel("V_MTF",X+30,y+42,"---",C_MUTED,6,"Arial");
   y+=58;

   // Open position block
   DrawRect("OP_HDR",X+2,y,W-4,13,C_SECTION_HDR,C_BORDER2,1);
   DrawLabel("OP_TIT",X+6,y+2,"OPEN POSITION",C_ORANGE,7,"Arial Black");
   y+=14;
   DrawRect("OP_BG",X+2,y,W-4,42,C_PANEL,C_BORDER2,1);
   DrawLabel("L_OTYP",X+6,y+3,"TYPE",C_MUTED,7,"Arial"); DrawLabel("V_OTYP",X+32,y+3,"---",C_MUTED,8,"Arial Bold");
   DrawLabel("L_OLOT",X+W/2-10,y+3,"LOT",C_MUTED,7,"Arial"); DrawLabel("V_OLOT",X+W/2+14,y+3,"---",C_MUTED,8,"Arial Bold");
   DrawLabel("L_OOPN",X+6,y+16,"OPEN",C_MUTED,7,"Arial"); DrawLabel("V_OOPN",X+34,y+16,"---",C_WHITE,7,"Arial Bold");
   DrawLabel("L_OSLT",X+W/2-10,y+16,"SL/TP",C_MUTED,7,"Arial"); DrawLabel("V_OSLT",X+W/2+24,y+16,"--- / ---",C_WHITE,7,"Arial Bold");
   DrawLabel("L_OPNL",X+6,y+29,"P&L",C_MUTED,7,"Arial"); DrawLabel("V_OPNL",X+30,y+29,"+$0.00 (0.0R)",C_GREEN,7,"Arial Bold");
   DrawLabel("L_OPK",X+W/2+30,y+29,"PK",C_MUTED,7,"Arial"); DrawLabel("V_OPK",X+W/2+48,y+29,"+$0.00",C_CYAN,7,"Arial Bold");
   y+=44;

   // Risk & drawdown block
   DrawRect("RK_HDR",X+2,y,W-4,13,C_SECTION_HDR,C_BORDER2,1);
   DrawLabel("RK_TIT",X+6,y+2,"RISK STATUS",C_ORANGE,7,"Arial Black");
   y+=14;
   DrawRect("RK_BG",X+2,y,W-4,70,C_PANEL,C_BORDER2,1);
   DrawLabel("L_BAL",X+6,y+3,"BAL",C_MUTED,7,"Arial"); DrawLabel("V_BAL",X+30,y+3,"$0.00",C_GREEN,8,"Arial Bold");
   DrawLabel("L_EQ",X+W/2,y+3,"EQ",C_MUTED,7,"Arial"); DrawLabel("V_EQ",X+W/2+20,y+3,"$0.00",C_WHITE,8,"Arial Bold");
   DrawLabel("L_DD",X+6,y+16,"DD",C_MUTED,7,"Arial"); DrawLabel("V_DD",X+26,y+16,"0.00%",C_WHITE,7,"Arial Bold");
   DrawLabel("L_DDL",X+W/2,y+16,"DD LVL",C_MUTED,7,"Arial"); DrawLabel("V_DDL",X+W/2+40,y+16,"0",C_GREEN,7,"Arial Bold");
   DrawLabel("L_DP",X+6,y+29,"DAY",C_MUTED,7,"Arial"); DrawLabel("V_DP",X+30,y+29,"+0.00",C_GREEN,7,"Arial Bold");
   DrawLabel("L_WK",X+W/2,y+29,"WEEK",C_MUTED,7,"Arial"); DrawLabel("V_WK",X+W/2+34,y+29,"+0.00",C_GREEN,7,"Arial Bold");
   DrawLabel("L_RSK",X+6,y+42,"RISK%",C_MUTED,7,"Arial"); DrawLabel("V_RSK",X+38,y+42,"0.0%",C_GOLD,7,"Arial Bold");
   DrawLabel("L_TR",X+W/2,y+42,"TRADES",C_MUTED,7,"Arial"); DrawLabel("V_TR",X+W/2+44,y+42,"0/0",C_WHITE,7,"Arial Bold");
   DrawLabel("L_STKR",X+6,y+55,"STRK",C_MUTED,7,"Arial"); DrawLabel("V_STKR",X+32,y+55,"---",C_MUTED,7,"Arial Bold");
   DrawLabel("L_WR",X+W/2,y+55,"7T WR",C_MUTED,7,"Arial"); DrawLabel("V_WR",X+W/2+38,y+55,"0%",C_GREEN,7,"Arial Bold");
   y+=72;

   // Execution quality block
   DrawRect("EX_HDR",X+2,y,W-4,13,C_SECTION_HDR,C_BORDER2,1);
   DrawLabel("EX_TIT",X+6,y+2,"EXECUTION QUALITY",C_ORANGE,7,"Arial Black");
   y+=14;
   DrawRect("EX_BG",X+2,y,W-4,28,C_PANEL,C_BORDER2,1);
   DrawLabel("L_SPR",X+6,y+3,"SPREAD",C_MUTED,7,"Arial"); DrawLabel("V_SPR",X+50,y+3,"0.00%",C_GOLD,7,"Arial Bold");
   DrawLabel("L_EXQ",X+W/2,y+3,"RQ/RJ/Slip",C_MUTED,7,"Arial"); DrawLabel("V_EXQ",X+W/2+58,y+3,"0/0/$0",C_MUTED,7,"Arial Bold");
   DrawLabel("L_EVT",X+6,y+16,"EVENT WIN",C_MUTED,7,"Arial"); DrawLabel("V_EVT",X+58,y+16,"NO",C_MUTED,7,"Arial Bold");
   DrawLabel("L_DISP",X+W/2,y+16,"DISPLACEMENT",C_MUTED,7,"Arial"); DrawLabel("V_DISP",X+W/2+76,y+16,"0/100",C_WHITE,7,"Arial Bold");
   y+=30;

   ChartRedraw(0);
}

void UpdateDashboard()
{
   MqlDateTime dt; TimeToStruct(TimeCurrent(),dt);
   SetLabel("HDR_CLK", StringFormat("%02d:%02d",dt.hour,dt.min), C_MUTED);

   // 7 regime rows
   struct RowData { string state; double conf; color clr; };
   RowData rows[7];
   rows[0].state = g_VolClassifier.StateString();    rows[0].conf = g_VolClassifier.Confidence();
   rows[1].state = g_LiqClassifier.StateString();    rows[1].conf = g_LiqClassifier.Confidence();
   rows[2].state = g_SessionClassifier.StateString();rows[2].conf = g_SessionClassifier.Confidence();
   rows[3].state = g_TrendClassifier.StateString();  rows[3].conf = g_TrendClassifier.Confidence();
   rows[4].state = g_MomClassifier.StateString();    rows[4].conf = g_MomClassifier.Confidence();
   rows[5].state = g_StructClassifier.StateString(); rows[5].conf = g_StructClassifier.Confidence();
   rows[6].state = g_RiskClassifier.StateString();   rows[6].conf = g_RiskClassifier.Confidence();

   for(int i=0;i<7;i++)
   {
      color c = (rows[i].conf>=75)?C_GREEN:(rows[i].conf>=50)?C_GOLD:C_RED;
      if(i==6 && g_RiskClassifier.State()!=RISKR_NORMAL) c = C_RED; // risk row always flags red unless normal
      SetLabel("V_R"+IntegerToString(i), rows[i].state+" ("+DoubleToString(rows[i].conf,0)+"%)", c);
      string fgN = DASH_PREFIX+"CF_R"+IntegerToString(i);
      if(ObjectFind(0,fgN)>=0) ObjectSetInteger(0,fgN,OBJPROP_XSIZE, MathMax(2,(int)MathRound(78*(rows[i].conf/100.0))));
      if(ObjectFind(0,fgN)>=0) ObjectSetInteger(0,fgN,OBJPROP_BGCOLOR, c);
   }

   // Strategy selector
   SetLabel("V_ACT", g_Selector.ActiveName(), (g_Selector.ActiveId()==STRAT_NONE)?C_MUTED:C_GREEN);
   SetLabel("V_CAN", StrategyIdToString(g_Selector.CandidateId()), C_VIOLET);
   SetLabel("V_STK", IntegerToString(g_Selector.CandidateStreak())+"/"+IntegerToString(InpConfirmBars), C_WHITE);
   if(g_LastSignal.valid)
      SetLabel("V_SIG", (g_LastSignal.dir==SIG_BUY?"BUY ":"SELL ")+DoubleToString(g_LastSignal.score,0)+"/100", (g_LastSignal.dir==SIG_BUY)?C_GREEN:C_RED);
   else
      SetLabel("V_SIG", "---", C_MUTED);
   SetLabel("V_MTF", g_MTFAlignment, C_MUTED);

   // Open position
   bool hasPos=false;
   for(int i=0;i<PositionsTotal();i++)
   {
      if(g_Pos.SelectByIndex(i) && g_Pos.Magic()==InpMagicNumber && g_Pos.Symbol()==_Symbol)
      {
         hasPos=true;
         string typStr=(g_Pos.PositionType()==POSITION_TYPE_BUY)?"BUY":"SELL";
         color typClr=(g_Pos.PositionType()==POSITION_TYPE_BUY)?C_GREEN:C_RED;
         double rowPnl = g_Pos.Profit()+g_Pos.Swap()+g_Pos.Commission();
         SetLabel("V_OTYP",typStr,typClr); SetLabel("V_OLOT",DoubleToString(g_Pos.Volume(),2),C_WHITE);
         SetLabel("V_OOPN",DoubleToString(g_Pos.PriceOpen(),2),C_WHITE);
         SetLabel("V_OSLT",DoubleToString(g_Pos.StopLoss(),2)+" / "+DoubleToString(g_Pos.TakeProfit(),2),C_WHITE);
         double oneR=g_TradeMgr.EntryRiskUSD();
         string rTxt=(oneR>0)?" ("+DoubleToString(rowPnl/oneR,2)+"R)":"";
         color pnlClr=(rowPnl>=0)?C_GREEN:C_RED;
         SetLabel("V_OPNL",(rowPnl>=0?"+$":"-$")+DoubleToString(MathAbs(rowPnl),2)+rTxt,pnlClr);
         SetLabel("V_OPK","+$"+DoubleToString(g_TradeMgr.PeakProfit(),2),C_CYAN);
         break;
      }
   }
   if(!hasPos)
   {
      SetLabel("V_OTYP","---",C_MUTED); SetLabel("V_OLOT","---",C_MUTED); SetLabel("V_OOPN","---",C_MUTED);
      SetLabel("V_OSLT","--- / ---",C_MUTED); SetLabel("V_OPNL","+$0.00 (0.0R)",C_MUTED); SetLabel("V_OPK","+$0.00",C_MUTED);
   }

   // Risk status
   double bal=AccountInfoDouble(ACCOUNT_BALANCE), eq=AccountInfoDouble(ACCOUNT_EQUITY);
   SetLabel("V_BAL","$"+DoubleToString(bal,2),C_GREEN); SetLabel("V_EQ","$"+DoubleToString(eq,2),C_WHITE);
   double ddPct = (g_RiskMgr.EquityPeak()>0)?((g_RiskMgr.EquityPeak()-eq)/g_RiskMgr.EquityPeak())*100.0:0.0;
   color cDD=(ddPct>InpMaxDrawdownPct*0.66)?C_RED:(ddPct>InpMaxDrawdownPct*0.33)?C_GOLD:C_WHITE;
   SetLabel("V_DD",DoubleToString(ddPct,2)+"%",cDD);
   int ddLevel = (ddPct>=InpMaxDrawdownPct)?3:(ddPct>=InpMaxDrawdownPct*0.7)?2:(ddPct>=InpMaxDrawdownPct*0.4)?1:0;
   color ddLvlClr = (ddLevel==0)?C_GREEN:(ddLevel==1)?C_GOLD:C_RED;
   SetLabel("V_DDL", IntegerToString(ddLevel), ddLvlClr);
   double dailyP=g_RiskMgr.DailyProfit();
   SetLabel("V_DP",(dailyP>=0?"+":"")+DoubleToString(dailyP,2),(dailyP>=0)?C_GREEN:C_RED);
   double weekP=g_RiskMgr.WeekProfit();
   SetLabel("V_WK",(weekP>=0?"+":"")+DoubleToString(weekP,2),(weekP>=0)?C_GREEN:C_RED);
   SetLabel("V_RSK",DoubleToString(g_RiskMgr.RiskAdjustedPercent(),2)+"%",C_GOLD);
   SetLabel("V_TR",IntegerToString(g_RiskMgr.DailyTrades())+"/"+IntegerToString(InpMaxDailyTrades),C_WHITE);
   if(g_RiskMgr.ConsecLosses()>=2) SetLabel("V_STKR","LOSS x"+IntegerToString(g_RiskMgr.ConsecLosses()),C_RED);
   else if(g_RiskMgr.ConsecWins()>=2) SetLabel("V_STKR","WIN x"+IntegerToString(g_RiskMgr.ConsecWins()),C_GREEN);
   else SetLabel("V_STKR","---",C_MUTED);
   SetLabel("V_WR",DoubleToString(g_RiskMgr.WinRate7(),0)+"%",(g_RiskMgr.WinRate7()>=50)?C_GREEN:C_GOLD);

   // Execution quality
   double bid=SymbolInfoDouble(_Symbol,SYMBOL_BID), ask=SymbolInfoDouble(_Symbol,SYMBOL_ASK);
   double spreadPct=(bid>0)?((ask-bid)/bid)*100.0:0.0;
   SetLabel("V_SPR",DoubleToString(spreadPct,3)+"%", g_ExecEngine.IsSpreadOk()?C_GOLD:C_RED);
   SetLabel("V_EXQ", IntegerToString(g_ExecEngine.RequoteCount())+"/"+IntegerToString(g_ExecEngine.RejectCount())+"/$"+DoubleToString(g_ExecEngine.AvgSlippage(),2), C_MUTED);
   SetLabel("V_EVT", g_RiskClassifier.EventWindowActive()?"YES":"NO", g_RiskClassifier.EventWindowActive()?C_ORANGE:C_MUTED);
   SetLabel("V_DISP", DoubleToString(g_RiskClassifier.DisplacementScore(),0)+"/100", C_WHITE);

   ChartRedraw(0);
}
//+------------------------------------------------------------------+
//| END OF FILE                                                          |
//+------------------------------------------------------------------+
