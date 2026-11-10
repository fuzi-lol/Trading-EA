//+------------------------------------------------------------------+
//|                                    Institutional_XAUUSD_Scalper.mq5 |
//|                        Institutional Quant Architecture          |
//|                           Pure MQL5 Production Build             |
//+------------------------------------------------------------------+
#property copyright   "Institutional Quant Architecture"
#property link        ""
#property version     "1.0.0"
#property description "Institutional XAUUSD Scalping EA - SMC, AI Scoring, Glassmorphism UI, Multi-Timeframe"
#property strict

#include <Trade\Trade.mqh>
#include <Canvas\Canvas.mqh>
#include <Arrays\ArrayInt.mqh>
#include <Arrays\ArrayDouble.mqh>
#include <Arrays\ArrayString.mqh>
#include <String\String.mqh>

//=== INPUTS ===
input group "=== RISK & EXECUTION ==="
input double   RiskPercent           = 0.5;
input int      MaxTrades             = 1;
input double   MaxDailyDrawdownPct   = 2.0;
input double   MaxEquityDrawdownPct  = 5.0;
input int      MaxConsecutiveLoss    = 3;
input double   MinRR                 = 1.5;
input int      BreakEvenPoints       = 30;
input int      TrailStepPoints       = 15;
input int      TrailStopPoints       = 20;

input group "=== SMC & STRUCTURE ==="
input int      FVGPeriod             = 3;
input int      OBLookback            = 50;
input bool     UseLiquiditySweep     = true;
input bool     RequireCHoCH          = true;
input bool     RequireBOS            = true;

input group "=== SESSION & NEWS ==="
input bool     FilterAsianSession    = true;
input bool     UseSpreadProtection   = true;
input int      MaxAllowedSpreadPips  = 25;
input bool     UseVolatilitySpikeFilter = true;
input double   VolSpikeMultiplier    = 2.5;

input group "=== DASHBOARD ==="
input color    PanelBgColor          = clrBlack;
input int      GlassAlpha            = 180;
input color    AccentColor           = clrAqua;
input color    ProfitColor           = clrLime;
input color    LossColor             = clrRed;
input color    TextColor             = clrWhite;

//=== GLOBAL CONSTANTS ===
#define DASHBOARD_WIDTH_PCT   0.45
#define DASHBOARD_MARGIN      10
#define FEED_BUFFER_SIZE      50
#define TICK_HISTORY_SIZE     100

//=== ENUMS & STRUCTS ===
enum ENUM_DIRECTION { BUY, SELL, NONE };
enum ENUM_MARKET_STATE { TRENDING_BULL, TRENDING_BEAR, RANGING, CHOPPY, EXPLOSIVE };
enum ENUM_SESSION { ASIAN, LONDON, NY, OVERLAP, CLOSED };

struct S_AI_SCORE {
   double Trend          = 0;
   double Liquidity      = 0;
   double Momentum       = 0;
   double Structure      = 0;
   double Session        = 0;
   double SpreadVol      = 0;
   double Risk           = 0;
   double Total          = 0;
};

struct S_TRADE_INFO {
   ulong Ticket;
   double Entry;
   double SL;
   double TP;
   double Lot;
   datetime OpenTime;
   ENUM_DIRECTION Dir;
   double Confidence;
   string Reason;
};

//=== MAIN EA CLASS ===
class CInstitutionalXAUUSDScalper : public CObject
{
private:
   //--- Execution
   CTrade m_trade;
   double m_point, m_spread;
   int    m_digits;
   string m_symbol;
   
   //--- Market State
   ENUM_DIRECTION m_htf_trend;
   ENUM_MARKET_STATE m_market_state;
   ENUM_SESSION m_session;
   S_AI_SCORE m_score;
   
   //--- SMC Arrays (Cached)
   double m_high[], m_low[], m_close[], m_open[], m_volume[];
   int    m_last_bar_time = 0;
   int    m_tick_count = 0;
   datetime m_tick_timer = 0;
   double m_tick_acceleration = 0;
   
   //--- Risk & Prop Firm
   double m_daily_pnl = 0;
   double m_start_balance = 0;
   int    m_consecutive_losses = 0;
   bool   m_safe_mode = false;
   bool   m_news_freeze = false;
   datetime m_last_trade_time = 0;
   int    m_trades_today = 0;
   
   //--- Dashboard
   CCanvas *m_canvas;
   bool m_dashboard_initialized = false;
   int m_dashboard_w, m_dashboard_h;
   int m_feed_offset = 0;
   string m_feed_buffer[FEED_BUFFER_SIZE];
   int m_feed_index = 0;
   
   //--- Helpers
   bool CheckMarketConditions();
   void CalculateAITradeScore();
   void DetectSMCStructure(int tf_period);
   ENUM_DIRECTION DetectHTFTrend();
   ENUM_MARKET_STATE DetectMarketState();
   ENUM_SESSION GetTradingSession();
   double CalculateDynamicLot(double sl_points);
   void ExecuteTrade(ENUM_DIRECTION dir, double confidence);
   void ManageOpenPositions();
   void InitializeDashboard();
   void RenderDashboard();
   void LogAIReason(string msg, color c=clrWhite);
   void SendNotification(string msg, string type="INFO");
   
public:
   CInstitutionalXAUUSDScalper();
   ~CInstitutionalXAUUSDScalper();
   int OnInit();
   void OnDeinit(const int reason);
   void OnTick();
   void OnTimer();
};

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CInstitutionalXAUUSDScalper::CInstitutionalXAUUSDScalper()
{
   m_symbol = _Symbol;
   m_point = SymbolInfoDouble(m_symbol, SYMBOL_POINT);
   m_digits = (int)SymbolInfoInteger(m_symbol, SYMBOL_DIGITS);
   ArraySetAsSeries(m_high, true);
   ArraySetAsSeries(m_low, true);
   ArraySetAsSeries(m_close, true);
   ArraySetAsSeries(m_open, true);
   ArraySetAsSeries(m_volume, true);
}

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CInstitutionalXAUUSDScalper::~CInstitutionalXAUUSDScalper()
{
   if(m_canvas != NULL) delete m_canvas;
}

//+------------------------------------------------------------------+
//| OnInit                                                           |
//+------------------------------------------------------------------+
int CInstitutionalXAUUSDScalper::OnInit()
{
   m_start_balance = AccountInfoDouble(ACCOUNT_BALANCE);
   InitializeDashboard();
   EventSetTimer(1000);
   LogAIReason("Institutional XAUUSD Scalper Initialized. Awaiting market conditions.", clrAqua);
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| OnDeinit                                                         |
//+------------------------------------------------------------------+
void CInstitutionalXAUUSDScalper::OnDeinit(const int reason)
{
   EventKillTimer();
   ObjectsDeleteAll(0, "SCALPER_");
   if(m_canvas != NULL) delete m_canvas;
}

//+------------------------------------------------------------------+
//| OnTick                                                           |
//+------------------------------------------------------------------+
void CInstitutionalXAUUSDScalper::OnTick()
{
   //--- Tick acceleration tracking
   if(m_tick_timer != TimeCurrent()) {
      m_tick_count = 0;
      m_tick_timer = TimeCurrent();
   }
   m_tick_count++;
   m_tick_acceleration = m_tick_count;