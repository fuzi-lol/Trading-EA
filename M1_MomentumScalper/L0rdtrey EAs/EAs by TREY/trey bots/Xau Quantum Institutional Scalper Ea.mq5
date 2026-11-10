#property strict
#property version   "1.10"
#property description "XAUUSD institutional-style scalper"

#include <Trade/Trade.mqh>

// =========================
// Inputs
// =========================
input long            InpMagic                = 26052701;
input double          InpRiskPercent          = 0.80;   // keep small for tiny accounts
input double          InpMaxDailyLossPercent  = 5.00;
input int             InpMaxConsecutiveLosses = 3;
input int             InpMaxTradesPerDay      = 8;
input int             InpCooldownMinutes      = 15;
input int             InpMaxSpreadPoints      = 40;
input int             InpDeviationPoints      = 20;
input int             InpMinScore             = 80;
input int             InpSwingLookback        = 12;
input ENUM_TIMEFRAMES InpBiasTF               = PERIOD_H1;
input ENUM_TIMEFRAMES InpTrendTF              = PERIOD_M15;
input ENUM_TIMEFRAMES InpSignalTF             = PERIOD_M5;
input ENUM_TIMEFRAMES InpEntryTF              = PERIOD_M1;
input int             InpSessionStartHour     = 7;
input int             InpSessionEndHour       = 22;
input bool            InpUseNewsFilter        = false;
input bool            InpAllowBuy             = true;
input bool            InpAllowSell            = true;
input double          InpATR_SL_Mult          = 1.50;
input double          InpRR                   = 1.80;
input double          InpBE_RR                = 0.50;
input double          InpPartial_RR           = 1.00;
input double          InpPartialPct           = 0.70;
input double          InpTrailATRMult         = 1.20;
input int             InpMinADX               = 18;
input int             InpMinATRPoints         = 80;
input int             InpMaxATRPoints         = 2500;
input double          InpMinBodyRatio         = 0.45;
input bool            InpUseVolumeFilter      = true;
input double          InpVolumeMultiplier     = 1.20;
input bool            InpAllowReversalMode    = true;

// =========================
// Enums
// =========================
enum TrendBias
{
   TREND_NEUTRAL = 0,
   TREND_BULLISH = 1,
   TREND_BEARISH = -1
};

enum MomentumState
{
   MOMENTUM_NEUTRAL = 0,
   MOMENTUM_BULLISH = 1,
   MOMENTUM_BEARISH = -1
};

enum SweepSignal
{
   SWEEP_NONE = 0,
   SWEEP_BULLISH = 1,
   SWEEP_BEARISH = -1
};

// =========================
// Utilities
// =========================
static bool IsNewBar(const ENUM_TIMEFRAMES tf, datetime &last_bar)
{
   const datetime t = iTime(_Symbol, tf, 0);
   if(t <= 0)
      return false;
   if(t != last_bar)
   {
      last_bar = t;
      return true;
   }
   return false;
}

static datetime DayStart(const datetime t)
{
   MqlDateTime s;
   TimeToStruct(t, s);
   s.hour = 0;
   s.min = 0;
   s.sec = 0;
   return StructToTime(s);
}

static double NormalizeVolume(const string symbol, double vol)
{
   const double vmin  = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
   const double vmax  = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
   const double vstep = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);

   if(vmin <= 0.0 || vmax <= 0.0 || vstep <= 0.0)
      return 0.0;

   vol = MathMax(vmin, MathMin(vmax, vol));
   vol = MathFloor(vol / vstep) * vstep;

   int digits = 2;
   if(vstep >= 1.0)
      digits = 0;
   else
      digits = (int)MathRound(MathLog10(1.0 / vstep));

   return NormalizeDouble(vol, digits);
}

// =========================
// Risk Guard
// =========================
class CRiskGuard
{
private:
   string   m_symbol;
   long     m_magic;
   double   m_risk_percent;
   double   m_max_daily_loss_percent;
   int      m_max_consecutive_losses;
   int      m_max_trades_per_day;
   datetime m_day_start;
   double   m_day_start_equity;
   int      m_consecutive_losses;
   int      m_trades_today;
   datetime m_last_trade_time;

   void RefreshDayIfNeeded()
   {
      const datetime ds = DayStart(TimeCurrent());
      if(ds != m_day_start)
      {
         m_day_start = ds;
         m_day_start_equity = AccountInfoDouble(ACCOUNT_EQUITY);
         m_consecutive_losses = 0;
         m_trades_today = 0;
      }
   }

public:
   CRiskGuard()
   {
      m_symbol = "";
      m_magic = 0;
      m_risk_percent = 1.0;
      m_max_daily_loss_percent = 5.0;
      m_max_consecutive_losses = 3;
      m_max_trades_per_day = 8;
      m_day_start = 0;
      m_day_start_equity = 0.0;
      m_consecutive_losses = 0;
      m_trades_today = 0;
      m_last_trade_time = 0;
   }

   bool Init(const string symbol,
             const long magic,
             const double risk_percent,
             const double max_daily_loss_percent,
             const int max_consecutive_losses,
             const int max_trades_per_day)
   {
      m_symbol = symbol;
      m_magic = magic;
      m_risk_percent = risk_percent;
      m_max_daily_loss_percent = max_daily_loss_percent;
      m_max_consecutive_losses = max_consecutive_losses;
      m_max_trades_per_day = max_trades_per_day;
      RefreshDayIfNeeded();
      return true;
   }

   void RegisterTradeOpen()
   {
      RefreshDayIfNeeded();
      m_trades_today++;
      m_last_trade_time = TimeCurrent();
   }

   bool CooldownPassed(const int cooldown_minutes) const
   {
      if(m_last_trade_time == 0)
         return true;
      return ((TimeCurrent() - m_last_trade_time) >= cooldown_minutes * 60);
   }

   bool UpdateStats()
   {
      RefreshDayIfNeeded();

      if(!HistorySelect(m_day_start, TimeCurrent()))
         return false;

      m_consecutive_losses = 0;
      int trades = 0;

      const int total = HistoryDealsTotal();
      for(int i = total - 1; i >= 0; --i)
      {
         const ulong deal = HistoryDealGetTicket(i);
         if(deal == 0)
            continue;

         const string sym = HistoryDealGetString(deal, DEAL_SYMBOL);
         const long mg = (long)HistoryDealGetInteger(deal, DEAL_MAGIC);
         const ENUM_DEAL_ENTRY entry = (ENUM_DEAL_ENTRY)HistoryDealGetInteger(deal, DEAL_ENTRY);

         if(sym != m_symbol || mg != m_magic || entry != DEAL_ENTRY_OUT)
            continue;

         trades++;

         const double profit = HistoryDealGetDouble(deal, DEAL_PROFIT)
                             + HistoryDealGetDouble(deal, DEAL_SWAP)
                             + HistoryDealGetDouble(deal, DEAL_COMMISSION);

         if(profit < 0.0)
            m_consecutive_losses++;
         else
            break;
      }

      m_trades_today = trades;
      return true;
   }

   bool TradingAllowed()
   {
      RefreshDayIfNeeded();
      UpdateStats();

      const double equity = AccountInfoDouble(ACCOUNT_EQUITY);
      if(m_day_start_equity > 0.0)
      {
         const double dd_pct = ((m_day_start_equity - equity) / m_day_start_equity) * 100.0;
         if(dd_pct >= m_max_daily_loss_percent)
            return false;
      }

      if(m_consecutive_losses >= m_max_consecutive_losses)
         return false;

      if(m_trades_today >= m_max_trades_per_day)
         return false;

      return true;
   }

   double CalculateLotSize(const double stop_loss_points) const
   {
      if(stop_loss_points <= 0.0)
         return 0.0;

      const double equity = AccountInfoDouble(ACCOUNT_EQUITY);
      const double risk_money = equity * (m_risk_percent / 100.0);

      const double tick_value = SymbolInfoDouble(m_symbol, SYMBOL_TRADE_TICK_VALUE);
      const double tick_size  = SymbolInfoDouble(m_symbol, SYMBOL_TRADE_TICK_SIZE);
      const double point      = SymbolInfoDouble(m_symbol, SYMBOL_POINT);

      if(tick_value <= 0.0 || tick_size <= 0.0 || point <= 0.0)
         return 0.0;

      const double value_per_point_per_lot = tick_value * (point / tick_size);
      if(value_per_point_per_lot <= 0.0)
         return 0.0;

      double lots = risk_money / (stop_loss_points * value_per_point_per_lot);
      return NormalizeVolume(m_symbol, lots);
   }

   bool CheckMargin(const ENUM_ORDER_TYPE type, const double lots, const double price) const
   {
      double margin = 0.0;
      if(!OrderCalcMargin(type, m_symbol, lots, price, margin))
         return false;
      return (AccountInfoDouble(ACCOUNT_FREEMARGIN) > margin);
   }
};

// =========================
// Session Filter
// =========================
class CSessionFilter
{
public:
   bool IsAllowed(const int start_hour, const int end_hour) const
   {
      MqlDateTime s;
      TimeToStruct(TimeCurrent(), s);

      if(start_hour == end_hour)
         return true;

      if(start_hour < end_hour)
         return (s.hour >= start_hour && s.hour < end_hour);

      return (s.hour >= start_hour || s.hour < end_hour);
   }
};

// =========================
// Trend Engine
// =========================
class CTrendEngine
{
private:
   string m_symbol;
   int m_h1_ema200;
   int m_m15_ema20;
   int m_m15_ema50;
   int m_m5_ema20;
   int m_m5_ema50;
   int m_adx_m15;

   bool CopyOne(const int handle, double &v0, double &v1)
   {
      double b[2];
      ArraySetAsSeries(b, true);
      if(CopyBuffer(handle, 0, 0, 2, b) < 2)
         return false;
      v0 = b[0];
      v1 = b[1];
      return true;
   }

public:
   CTrendEngine()
   {
      m_symbol = "";
      m_h1_ema200 = INVALID_HANDLE;
      m_m15_ema20 = INVALID_HANDLE;
      m_m15_ema50 = INVALID_HANDLE;
      m_m5_ema20 = INVALID_HANDLE;
      m_m5_ema50 = INVALID_HANDLE;
      m_adx_m15 = INVALID_HANDLE;
   }

   bool Init(const string symbol)
   {
      m_symbol = symbol;
      m_h1_ema200 = iMA(m_symbol, PERIOD_H1, 200, 0, MODE_EMA, PRICE_CLOSE);
      m_m15_ema20 = iMA(m_symbol, PERIOD_M15, 20, 0, MODE_EMA, PRICE_CLOSE);
      m_m15_ema50 = iMA(m_symbol, PERIOD_M15, 50, 0, MODE_EMA, PRICE_CLOSE);
      m_m5_ema20  = iMA(m_symbol, PERIOD_M5, 20, 0, MODE_EMA, PRICE_CLOSE);
      m_m5_ema50  = iMA(m_symbol, PERIOD_M5, 50, 0, MODE_EMA, PRICE_CLOSE);
      m_adx_m15   = iADX(m_symbol, PERIOD_M15, 14);
      return (m_h1_ema200 != INVALID_HANDLE && m_m15_ema20 != INVALID_HANDLE &&
              m_m15_ema50 != INVALID_HANDLE && m_m5_ema20 != INVALID_HANDLE &&
              m_m5_ema50 != INVALID_HANDLE && m_adx_m15 != INVALID_HANDLE);
   }

   void Release()
   {
      if(m_h1_ema200 != INVALID_HANDLE) IndicatorRelease(m_h1_ema200);
      if(m_m15_ema20 != INVALID_HANDLE) IndicatorRelease(m_m15_ema20);
      if(m_m15_ema50 != INVALID_HANDLE) IndicatorRelease(m_m15_ema50);
      if(m_m5_ema20  != INVALID_HANDLE) IndicatorRelease(m_m5_ema20);
      if(m_m5_ema50  != INVALID_HANDLE) IndicatorRelease(m_m5_ema50);
      if(m_adx_m15   != INVALID_HANDLE) IndicatorRelease(m_adx_m15);
      m_h1_ema200 = m_m15_ema20 = m_m15_ema50 = m_m5_ema20 = m_m5_ema50 = m_adx_m15 = INVALID_HANDLE;
   }

   double ADX() const
   {
      double adx[1];
      ArraySetAsSeries(adx, true);
      if(CopyBuffer(m_adx_m15, 0, 0, 1, adx) < 1)
         return EMPTY_VALUE;
      return adx[0];
   }

   TrendBias GetBias() const
   {
      double ema_h1_0, ema_h1_1;
      double ema15_20_0, ema15_20_1;
      double ema15_50_0, ema15_50_1;
      double ema5_20_0, ema5_20_1;
      double ema5_50_0, ema5_50_1;

      if(!CopyOne(m_h1_ema200, ema_h1_0, ema_h1_1)) return TREND_NEUTRAL;
      if(!CopyOne(m_m15_ema20, ema15_20_0, ema15_20_1)) return TREND_NEUTRAL;
      if(!CopyOne(m_m15_ema50, ema15_50_0, ema15_50_1)) return TREND_NEUTRAL;
      if(!CopyOne(m_m5_ema20, ema5_20_0, ema5_20_1)) return TREND_NEUTRAL;
      if(!CopyOne(m_m5_ema50, ema5_50_0, ema5_50_1)) return TREND_NEUTRAL;

      MqlRates r[2];
      ArraySetAsSeries(r, true);
      if(CopyRates(m_symbol, PERIOD_M15, 0, 2, r) < 2)
         return TREND_NEUTRAL;

      const double price = r[0].close;
      const bool h1_bull  = price > ema_h1_0 && ema_h1_0 > ema_h1_1;
      const bool h1_bear  = price < ema_h1_0 && ema_h1_0 < ema_h1_1;
      const bool m15_bull = ema15_20_0 > ema15_50_0 && ema15_20_0 > ema15_20_1 && ema15_50_0 > ema15_50_1;
      const bool m15_bear = ema15_20_0 < ema15_50_0 && ema15_20_0 < ema15_20_1 && ema15_50_0 < ema15_50_1;
      const bool m5_bull  = ema5_20_0 > ema5_50_0 && ema5_20_0 > ema5_20_1;
      const bool m5_bear  = ema5_20_0 < ema5_50_0 && ema5_20_0 < ema5_20_1;

      if(h1_bull && m15_bull && m5_bull)
         return TREND_BULLISH;
      if(h1_bear && m15_bear && m5_bear)
         return TREND_BEARISH;
      return TREND_NEUTRAL;
   }
};

// =========================
// Momentum Engine
// =========================
class CMomentumEngine
{
private:
   string m_symbol;
   ENUM_TIMEFRAMES m_tf;
   int m_rsi;
   int m_macd;

public:
   CMomentumEngine()
   {
      m_symbol = "";
      m_tf = PERIOD_M5;
      m_rsi = INVALID_HANDLE;
      m_macd = INVALID_HANDLE;
   }

   bool Init(const string symbol, const ENUM_TIMEFRAMES tf, const int rsi_period = 14,
             const int macd_fast = 12, const int macd_slow = 26, const int macd_signal = 9)
   {
      m_symbol = symbol;
      m_tf = tf;
      m_rsi  = iRSI(m_symbol, m_tf, rsi_period, PRICE_CLOSE);
      m_macd = iMACD(m_symbol, m_tf, macd_fast, macd_slow, macd_signal, PRICE_CLOSE);
      return (m_rsi != INVALID_HANDLE && m_macd != INVALID_HANDLE);
   }

   void Release()
   {
      if(m_rsi  != INVALID_HANDLE) IndicatorRelease(m_rsi);
      if(m_macd != INVALID_HANDLE) IndicatorRelease(m_macd);
      m_rsi = m_macd = INVALID_HANDLE;
   }

   bool GetState(MomentumState &state) const
   {
      state = MOMENTUM_NEUTRAL;

      double rsi[3], macd_main[3], macd_signal[3];
      ArraySetAsSeries(rsi, true);
      ArraySetAsSeries(macd_main, true);
      ArraySetAsSeries(macd_signal, true);

      if(CopyBuffer(m_rsi, 0, 0, 3, rsi) < 3)
         return false;
      if(CopyBuffer(m_macd, 0, 0, 3, macd_main) < 3)
         return false;
      if(CopyBuffer(m_macd, 1, 0, 3, macd_signal) < 3)
         return false;

      const bool bull = (rsi[0] > 55.0 && macd_main[0] > macd_signal[0] && macd_main[0] > macd_main[1]);
      const bool bear = (rsi[0] < 45.0 && macd_main[0] < macd_signal[0] && macd_main[0] < macd_main[1]);

      if(bull) state = MOMENTUM_BULLISH;
      else if(bear) state = MOMENTUM_BEARISH;

      return true;
   }

   double RSI() const
   {
      double rsi[1];
      ArraySetAsSeries(rsi, true);
      if(CopyBuffer(m_rsi, 0, 0, 1, rsi) < 1)
         return EMPTY_VALUE;
      return rsi[0];
   }
};

// =========================
// Liquidity Sweep Detector
// =========================
class CLiquiditySweepDetector
{
private:
   bool BullCandle(const MqlRates &bar, const double min_body_ratio) const
   {
      const double range = bar.high - bar.low;
      if(range <= 0.0) return false;
      const double body = MathAbs(bar.close - bar.open);
      return (bar.close > bar.open && (body / range) >= min_body_ratio);
   }

   bool BearCandle(const MqlRates &bar, const double min_body_ratio) const
   {
      const double range = bar.high - bar.low;
      if(range <= 0.0) return false;
      const double body = MathAbs(bar.close - bar.open);
      return (bar.close < bar.open && (body / range) >= min_body_ratio);
   }

public:
   SweepSignal Detect(const string symbol, const ENUM_TIMEFRAMES tf, const int lookback, const double min_body_ratio) const
   {
      if(lookback < 3)
         return SWEEP_NONE;

      MqlRates r[];
      ArraySetAsSeries(r, true);
      if(CopyRates(symbol, tf, 0, lookback + 5, r) < lookback + 3)
         return SWEEP_NONE;

      double prev_low = r[2].low;
      double prev_high = r[2].high;
      for(int i = 3; i <= lookback + 1; ++i)
      {
         prev_low = MathMin(prev_low, r[i].low);
         prev_high = MathMax(prev_high, r[i].high);
      }

      const bool bull_sweep = (r[1].low < prev_low && r[1].close > prev_low && BullCandle(r[1], min_body_ratio));
      const bool bear_sweep = (r[1].high > prev_high && r[1].close < prev_high && BearCandle(r[1], min_body_ratio));

      if(bull_sweep) return SWEEP_BULLISH;
      if(bear_sweep) return SWEEP_BEARISH;
      return SWEEP_NONE;
   }
};

// =========================
// Volatility Filter
// =========================
class CVolatilityFilter
{
private:
   int m_atr;
   string m_symbol;
   ENUM_TIMEFRAMES m_tf;

public:
   CVolatilityFilter() { m_atr = INVALID_HANDLE; m_symbol = ""; m_tf = PERIOD_M5; }

   bool Init(const string symbol, const ENUM_TIMEFRAMES tf, const int atr_period = 14)
   {
      m_symbol = symbol;
      m_tf = tf;
      m_atr = iATR(m_symbol, m_tf, atr_period);
      return (m_atr != INVALID_HANDLE);
   }

   void Release()
   {
      if(m_atr != INVALID_HANDLE) IndicatorRelease(m_atr);
      m_atr = INVALID_HANDLE;
   }

   double ATR() const
   {
      double a[1];
      ArraySetAsSeries(a, true);
      if(CopyBuffer(m_atr, 0, 0, 1, a) < 1)
         return EMPTY_VALUE;
      return a[0];
   }

   bool IsTradeableATR(const int min_atr_points, const int max_atr_points) const
   {
      const double atr = ATR();
      if(atr == EMPTY_VALUE)
         return false;
      const double point = SymbolInfoDouble(m_symbol, SYMBOL_POINT);
      if(point <= 0.0)
         return false;
      const double atr_points = atr / point;
      return (atr_points >= min_atr_points && atr_points <= max_atr_points);
   }
};

// =========================
// AI Scoring Engine
// =========================
class CScoringEngine
{
public:
   int ScoreSetup(const TrendBias bias,
                  const MomentumState momentum,
                  const SweepSignal sweep,
                  const double adx,
                  const bool spread_ok,
                  const bool session_ok,
                  const bool news_ok,
                  const bool atr_ok,
                  const bool volume_ok,
                  const bool reversal_mode)
   {
      int score = 0;

      if(bias == TREND_BULLISH || bias == TREND_BEARISH)
         score += 15;

      if(adx >= InpMinADX)
         score += 10;

      if(spread_ok) score += 10;
      if(session_ok) score += 10;
      if(news_ok) score += 5;
      if(atr_ok) score += 10;
      if(volume_ok) score += 5;

      const bool trend_aligned =
         (bias == TREND_BULLISH && momentum == MOMENTUM_BULLISH && sweep == SWEEP_BULLISH) ||
         (bias == TREND_BEARISH && momentum == MOMENTUM_BEARISH && sweep == SWEEP_BEARISH);

      if(trend_aligned)
         score += 35;

      const bool reversal_aligned =
         reversal_mode &&
         ((sweep == SWEEP_BULLISH && momentum == MOMENTUM_BULLISH && bias != TREND_BEARISH) ||
          (sweep == SWEEP_BEARISH && momentum == MOMENTUM_BEARISH && bias != TREND_BULLISH));

      if(reversal_aligned)
         score += 25;

      if((bias == TREND_BULLISH && momentum == MOMENTUM_BEARISH) ||
         (bias == TREND_BEARISH && momentum == MOMENTUM_BULLISH))
         score -= 20;

      if(score < 0) score = 0;
      if(score > 100) score = 100;
      return score;
   }
};

// =========================
// Trade Manager
// =========================
class CTradeManager
{
private:
   CTrade m_trade;
   long   m_magic;
   int    m_deviation;
   ulong  m_partial_done[];

   bool WasPartialDone(const ulong ticket) const
   {
      for(int i = 0; i < ArraySize(m_partial_done); ++i)
         if(m_partial_done[i] == ticket)
            return true;
      return false;
   }

   void MarkPartialDone(const ulong ticket)
   {
      if(WasPartialDone(ticket))
         return;
      const int n = ArraySize(m_partial_done);
      ArrayResize(m_partial_done, n + 1);
      m_partial_done[n] = ticket;
   }

public:
   CTradeManager() { m_magic = 0; m_deviation = 20; ArrayResize(m_partial_done, 0); }

   bool Init(const long magic, const int deviation_points)
   {
      m_magic = magic;
      m_deviation = deviation_points;
      m_trade.SetExpertMagicNumber(m_magic);
      m_trade.SetDeviationInPoints(m_deviation);
      return true;
   }

   bool HasPosition(const string symbol) const
   {
      for(int i = PositionsTotal() - 1; i >= 0; --i)
      {
         const ulong ticket = PositionGetTicket(i);
         if(ticket == 0)
            continue;
         if(!PositionSelectByTicket(ticket))
            continue;

         const string ps = PositionGetString(POSITION_SYMBOL);
         const long pmag = (long)PositionGetInteger(POSITION_MAGIC);
         if(ps == symbol && pmag == m_magic)
            return true;
      }
      return false;
   }

   int PositionCount(const string symbol) const
   {
      int count = 0;
      for(int i = PositionsTotal() - 1; i >= 0; --i)
      {
         const ulong ticket = PositionGetTicket(i);
         if(ticket == 0)
            continue;
         if(!PositionSelectByTicket(ticket))
            continue;

         const string ps = PositionGetString(POSITION_SYMBOL);
         const long pmag = (long)PositionGetInteger(POSITION_MAGIC);
         if(ps == symbol && pmag == m_magic)
            count++;
      }
      return count;
   }

   bool OpenBuy(const string symbol, const double lots, const double sl, const double tp, const string comment)
   {
      m_trade.SetExpertMagicNumber(m_magic);
      m_trade.SetDeviationInPoints(m_deviation);
      m_trade.SetTypeFillingBySymbol(symbol);
      return m_trade.Buy(lots, symbol, 0.0, sl, tp, comment);
   }

   bool OpenSell(const string symbol, const double lots, const double sl, const double tp, const string comment)
   {
      m_trade.SetExpertMagicNumber(m_magic);
      m_trade.SetDeviationInPoints(m_deviation);
      m_trade.SetTypeFillingBySymbol(symbol);
      return m_trade.Sell(lots, symbol, 0.0, sl, tp, comment);
   }

   bool ManageOpenPositions(const string symbol,
                            const double atr_price,
                            const double breakeven_rr,
                            const double partial_rr,
                            const double partial_close_pct,
                            const double trail_atr_mult)
   {
      bool modified_any = false;
      const double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
      if(point <= 0.0)
         return false;

      for(int i = PositionsTotal() - 1; i >= 0; --i)
      {
         const ulong ticket = PositionGetTicket(i);
         if(ticket == 0)
            continue;
         if(!PositionSelectByTicket(ticket))
            continue;

         const string ps = PositionGetString(POSITION_SYMBOL);
         const long pmag = (long)PositionGetInteger(POSITION_MAGIC);
         if(ps != symbol || pmag != m_magic)
            continue;

         const ENUM_POSITION_TYPE type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
         const double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
         const double sl = PositionGetDouble(POSITION_SL);
         const double tp = PositionGetDouble(POSITION_TP);
         const double volume = PositionGetDouble(POSITION_VOLUME);
         const double bid = SymbolInfoDouble(symbol, SYMBOL_BID);
         const double ask = SymbolInfoDouble(symbol, SYMBOL_ASK);
         const double current = (type == POSITION_TYPE_BUY ? bid : ask);

         if(sl <= 0.0)
            continue;

         const double risk = MathAbs(open_price - sl);
         if(risk <= 0.0)
            continue;

         const double profit = (type == POSITION_TYPE_BUY ? (current - open_price) : (open_price - current));
         const double rr = profit / risk;

         double new_sl = sl;

         if(rr >= breakeven_rr)
         {
            if(type == POSITION_TYPE_BUY)
               new_sl = MathMax(new_sl, open_price);
            else
               new_sl = (new_sl == 0.0 ? open_price : MathMin(new_sl, open_price));
         }

         if(atr_price > 0.0 && rr >= partial_rr)
         {
            const double trail = atr_price * trail_atr_mult;
            if(type == POSITION_TYPE_BUY)
               new_sl = MathMax(new_sl, current - trail);
            else
               new_sl = (new_sl == 0.0 ? current + trail : MathMin(new_sl, current + trail));
         }

         if(new_sl > 0.0 && MathAbs(new_sl - sl) > (point * 2.0))
         {
            if(m_trade.PositionModify(symbol, new_sl, tp))
               modified_any = true;
         }

         if(rr >= partial_rr && !WasPartialDone(ticket))
         {
            double partial_volume = NormalizeVolume(symbol, volume * partial_close_pct);
            const double vmin = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
            if(partial_volume >= vmin && (volume - partial_volume) >= vmin)
            {
               if(m_trade.PositionClosePartial(symbol, partial_volume))
               {
                  MarkPartialDone(ticket);
                  modified_any = true;
               }
            }
         }
      }

      return modified_any;
   }
};

// =========================
// Global Objects
// =========================
CRiskGuard            g_risk;
CSessionFilter        g_session;
CTrendEngine          g_trend;
CMomentumEngine       g_momentum;
CLiquiditySweepDetector g_liquidity;
CVolatilityFilter     g_volatility;
CScoringEngine        g_scoring;
CTradeManager         g_trade;

int g_atr_handle_entry = INVALID_HANDLE;
datetime g_last_entry_bar = 0;

// =========================
// Extra Market Checks
// =========================
bool SpreadOK()
{
   const int spread_points = (int)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   return (spread_points > 0 && spread_points <= InpMaxSpreadPoints);
}

bool NewsOK()
{
   if(!InpUseNewsFilter)
      return true;

   // Wire this to a calendar API / manual blackout list if you have one.
   // Keeping it permissive here so the EA remains compile-ready and self-contained.
   return true;
}

bool VolumeSpikeOK(const string symbol, const ENUM_TIMEFRAMES tf, const double multiplier)
{
   if(!InpUseVolumeFilter)
      return true;

   MqlRates r[];
   ArraySetAsSeries(r, true);
   if(CopyRates(symbol, tf, 0, 12, r) < 12)
      return false;

   const long recent = r[1].tick_volume;
   double avg = 0.0;
   for(int i = 2; i <= 11; ++i)
      avg += (double)r[i].tick_volume;
   avg /= 10.0;

   if(avg <= 0.0)
      return false;

   return ((double)recent >= avg * multiplier);
}

bool GetATRPrice(const int handle, double &atr_out)
{
   atr_out = EMPTY_VALUE;
   double a[1];
   ArraySetAsSeries(a, true);
   if(CopyBuffer(handle, 0, 0, 1, a) < 1)
      return false;
   atr_out = a[0];
   return true;
}

bool GetSwingSLTP(const bool is_buy,
                  const ENUM_TIMEFRAMES tf,
                  const int lookback,
                  const double atr_price,
                  double &sl_out,
                  double &tp_out)
{
   sl_out = 0.0;
   tp_out = 0.0;

   MqlRates r[];
   ArraySetAsSeries(r, true);
   if(CopyRates(_Symbol, tf, 0, lookback + 5, r) < lookback + 3)
      return false;

   double swing_low = r[2].low;
   double swing_high = r[2].high;
   for(int i = 3; i <= lookback + 1; ++i)
   {
      swing_low = MathMin(swing_low, r[i].low);
      swing_high = MathMax(swing_high, r[i].high);
   }

   const int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(point <= 0.0)
      return false;

   if(is_buy)
   {
      const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      const double sl_struct = swing_low - (atr_price * 0.20);
      const double sl_atr = ask - (atr_price * InpATR_SL_Mult);
      const double sl = MathMin(sl_struct, sl_atr);
      const double risk = ask - sl;
      if(risk <= point * 5.0)
         return false;
      sl_out = NormalizeDouble(sl, digits);
      tp_out = NormalizeDouble(ask + (risk * InpRR), digits);
      return true;
   }
   else
   {
      const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      const double sl_struct = swing_high + (atr_price * 0.20);
      const double sl_atr = bid + (atr_price * InpATR_SL_Mult);
      const double sl = MathMax(sl_struct, sl_atr);
      const double risk = sl - bid;
      if(risk <= point * 5.0)
         return false;
      sl_out = NormalizeDouble(sl, digits);
      tp_out = NormalizeDouble(bid - (risk * InpRR), digits);
      return true;
   }
}

// =========================
// Trade Decision
// =========================
void TryOpenTrade()
{
   if(g_trade.HasPosition(_Symbol))
      return;

   if(!g_risk.TradingAllowed())
      return;

   if(!g_risk.CooldownPassed(InpCooldownMinutes))
      return;

   if(!SpreadOK() || !g_session.IsAllowed(InpSessionStartHour, InpSessionEndHour) || !NewsOK())
      return;

   const double adx = g_trend.ADX();
   const bool atr_tradeable = g_volatility.IsTradeableATR(InpMinATRPoints, InpMaxATRPoints);
   if(adx == EMPTY_VALUE || !atr_tradeable)
      return;

   const TrendBias bias = g_trend.GetBias();
   MomentumState momentum = MOMENTUM_NEUTRAL;
   if(!g_momentum.GetState(momentum))
      return;

   const SweepSignal sweep = g_liquidity.Detect(_Symbol, InpEntryTF, InpSwingLookback, InpMinBodyRatio);
   const bool volume_ok = VolumeSpikeOK(_Symbol, InpEntryTF, InpVolumeMultiplier);
   const bool spread_ok = SpreadOK();
   const bool session_ok = g_session.IsAllowed(InpSessionStartHour, InpSessionEndHour);
   const bool news_ok = NewsOK();
   const bool atr_ok = atr_tradeable;
   const bool reversal_mode = InpAllowReversalMode && bias == TREND_NEUTRAL;

   const int score = g_scoring.ScoreSetup(bias, momentum, sweep, adx, spread_ok, session_ok, news_ok, atr_ok, volume_ok, reversal_mode);
   if(score < InpMinScore)
      return;

   double atr_price = EMPTY_VALUE;
   if(!GetATRPrice(g_atr_handle_entry, atr_price) || atr_price == EMPTY_VALUE)
      return;

   const int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(point <= 0.0)
      return;

   // Trend-following mode
   if(bias == TREND_BULLISH && momentum == MOMENTUM_BULLISH && sweep == SWEEP_BULLISH && InpAllowBuy)
   {
      double sl, tp;
      if(!GetSwingSLTP(true, InpSignalTF, InpSwingLookback, atr_price, sl, tp))
         return;

      const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      const double sl_points = MathAbs(ask - sl) / point;
      const double lots = g_risk.CalculateLotSize(sl_points);
      if(lots <= 0.0)
         return;

      if(!g_risk.CheckMargin(ORDER_TYPE_BUY, lots, ask))
         return;

      if(g_trade.OpenBuy(_Symbol, lots, NormalizeDouble(sl, digits), NormalizeDouble(tp, digits), "XAU AI BUY"))
         g_risk.RegisterTradeOpen();
      return;
   }

   if(bias == TREND_BEARISH && momentum == MOMENTUM_BEARISH && sweep == SWEEP_BEARISH && InpAllowSell)
   {
      double sl, tp;
      if(!GetSwingSLTP(false, InpSignalTF, InpSwingLookback, atr_price, sl, tp))
         return;

      const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      const double sl_points = MathAbs(sl - bid) / point;
      const double lots = g_risk.CalculateLotSize(sl_points);
      if(lots <= 0.0)
         return;

      if(!g_risk.CheckMargin(ORDER_TYPE_SELL, lots, bid))
         return;

      if(g_trade.OpenSell(_Symbol, lots, NormalizeDouble(sl, digits), NormalizeDouble(tp, digits), "XAU AI SELL"))
         g_risk.RegisterTradeOpen();
      return;
   }

   // Reversal scalp mode when higher trend is neutral
   if(reversal_mode)
   {
      if(sweep == SWEEP_BULLISH && momentum == MOMENTUM_BULLISH && InpAllowBuy)
      {
         double sl, tp;
         if(!GetSwingSLTP(true, InpSignalTF, InpSwingLookback, atr_price, sl, tp))
            return;

         const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
         const double sl_points = MathAbs(ask - sl) / point;
         const double lots = g_risk.CalculateLotSize(sl_points);
         if(lots <= 0.0)
            return;

         if(!g_risk.CheckMargin(ORDER_TYPE_BUY, lots, ask))
            return;

         if(g_trade.OpenBuy(_Symbol, lots, NormalizeDouble(sl, digits), NormalizeDouble(tp, digits), "XAU REV BUY"))
            g_risk.RegisterTradeOpen();
         return;
      }

      if(sweep == SWEEP_BEARISH && momentum == MOMENTUM_BEARISH && InpAllowSell)
      {
         double sl, tp;
         if(!GetSwingSLTP(false, InpSignalTF, InpSwingLookback, atr_price, sl, tp))
            return;

         const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
         const double sl_points = MathAbs(sl - bid) / point;
         const double lots = g_risk.CalculateLotSize(sl_points);
         if(lots <= 0.0)
            return;

         if(!g_risk.CheckMargin(ORDER_TYPE_SELL, lots, bid))
            return;

         if(g_trade.OpenSell(_Symbol, lots, NormalizeDouble(sl, digits), NormalizeDouble(tp, digits), "XAU REV SELL"))
            g_risk.RegisterTradeOpen();
         return;
      }
   }
}

// =========================
// Main lifecycle
// =========================
int OnInit()
{
   if(_Symbol == "")
      return INIT_FAILED;

   if(!g_risk.Init(_Symbol, InpMagic, InpRiskPercent, InpMaxDailyLossPercent, InpMaxConsecutiveLosses, InpMaxTradesPerDay))
      return INIT_FAILED;

   if(!g_trend.Init(_Symbol))
      return INIT_FAILED;

   if(!g_momentum.Init(_Symbol, InpSignalTF, 14, 12, 26, 9))
      return INIT_FAILED;

   if(!g_volatility.Init(_Symbol, InpSignalTF, 14))
      return INIT_FAILED;

   if(!g_trade.Init(InpMagic, InpDeviationPoints))
      return INIT_FAILED;

   g_atr_handle_entry = iATR(_Symbol, InpSignalTF, 14);
   if(g_atr_handle_entry == INVALID_HANDLE)
      return INIT_FAILED;

   g_last_entry_bar = 0;
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
   g_trend.Release();
   g_momentum.Release();
   g_volatility.Release();
   if(g_atr_handle_entry != INVALID_HANDLE)
      IndicatorRelease(g_atr_handle_entry);
}

void OnTick()
{
   // Always manage open positions first.
   double atr_price = EMPTY_VALUE;
   if(GetATRPrice(g_atr_handle_entry, atr_price) && atr_price != EMPTY_VALUE)
      g_trade.ManageOpenPositions(_Symbol, atr_price, InpBE_RR, InpPartial_RR, InpPartialPct, InpTrailATRMult);

   // Only search for new entries on fresh entry-timeframe bar.
   if(IsNewBar(InpEntryTF, g_last_entry_bar))
      TryOpenTrade();
}
