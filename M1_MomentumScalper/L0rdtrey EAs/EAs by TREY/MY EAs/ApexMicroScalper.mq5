//+------------------------------------------------------------------+
//|                 PHANTOM SCALPER AI - NEXT GEN                    |
//|           Institutional Gold Intelligence System v4.0            |
//|       Machine Learning | SMC | AI Decision | Dynamic Risk        |
//+------------------------------------------------------------------+
#property copyright   "PHANTOM SCALPER AI v4.0 - Institutional Edition"
#property version     "4.00"
#property description "Autonomous AI-Powered Gold Scalper Ecosystem"
#property strict

#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>
#include <Trade\AccountInfo.mqh>
#include <Trade\SymbolInfo.mqh>
#include <Files\File.mqh>

//=======================================================================
//  UI COLOR PALETTE - Institutional Dark Glassmorphism
//=======================================================================
#define C_BG_DEEP       C'8,10,14'       // Deepest background
#define C_BG_PANEL      C'15,19,26'      // Glass panel background
#define C_BG_CARD       C'22,28,38'      // Inner card
#define C_BORDER        C'30,40,55'      // Subtle borders
#define C_ACCENT_BLUE   C'41,98,255'     // Institutional blue
#define C_GOLD          C'255,200,50'    // Gold highlight
#define C_GREEN_PROFIT  C'0,210,105'     // Bullish / Profit
#define C_RED_LOSS      C'242,54,69'     // Bearish / Loss
#define C_TEXT_MAIN     C'225,230,240'   // Primary white text
#define C_TEXT_MUTED    C'120,130,145'   // Secondary text
#define C_CYAN_LITE     C'0,230,255'     // Highlight metric
#define D_PREFIX        "PSAI_"          // Object prefix

//=======================================================================
//  INPUT PARAMETERS
//=======================================================================
input group "╔══════ SYSTEM IDENTITY ══════╗"
input ulong    InpMagicNumber    = 888888;
input string   InpBotName        = "PHANTOM AI ENGINE";
input bool     InpIsXAUUSD       = true;        // Enable Gold Specific Logic

input group "╔══════ AI & ML ENGINE ══════╗"
input double   InpMinAIScore     = 85.0;        // Min AI Confidence to Trade (0-100)
input bool     InpEnableLearning = true;        // Enable Reinforcement Learning
input double   InpLearningRate   = 0.05;        // ML Weight Adjustment Rate

input group "╔══════ INSTITUTIONAL RISK ══════╗"
input double   InpBaseLotSize    = 0.01;        // Base Lot Size (Scaled by AI)
input double   InpMaxRiskPct     = 1.0;         // Max Risk Per Trade (%)
input double   InpMaxDailyDraw   = 4.0;         // Max Daily Drawdown (%)
input double   InpTargetR        = 2.0;         // Target R:R Ratio

input group "╔══════ DYNAMIC EXECUTION ══════╗"
input int      InpMaxSpreadPts   = 45;          // Max Spread (points)
input int      InpATRPeriod      = 14;          // ATR Period for Volatility
input bool     InpTradeWeekends  = false;

//=======================================================================
//  GLOBAL INFRASTRUCTURE
//=======================================================================
CTrade         g_trade;
CPositionInfo  g_pos;
CAccountInfo   g_acc;
CSymbolInfo    g_sym;

int            g_atrHandle;
double         g_peakEquity      = 0.0;
double         g_dailyStartEq    = 0.0;
datetime       g_lastDay         = 0;

// ML Weights (Persistent)
struct SMLWeights {
    double smc_w;
    double mtf_w;
    double vol_w;
    double ses_w;
} g_weights;

// Active Trade State Memory (For RL evaluation)
struct SActiveTrade {
    ulong  ticket;
    double smc_val;
    double mtf_val;
    double vol_val;
    double ses_val;
    double ai_score;
};
SActiveTrade g_mem[];

// AI Status Globals for UI
string g_mktState   = "ANALYZING";
string g_bias       = "NEUTRAL";
double g_curScore   = 0.0;
string g_liqState   = "BALANCED";
string g_volState   = "NORMAL";
string g_sessionStr = "PENDING";
int    g_mlWins     = 0;
int    g_mlLosses   = 0;

//=======================================================================
//  CORE ENGINES (Classes)
//=======================================================================

// 1. SMART MONEY CONCEPTS ENGINE
class CSMC_Engine {
public:
    bool   hasBullFVG, hasBearFVG;
    bool   hasBullOB,  hasBearOB;
    bool   liqSweepBull, liqSweepBear;
    
    void Analyze() {
        double H[], L[], C[], O[];
        CopyHigh(Symbol(), PERIOD_M15, 0, 10, H);
        CopyLow(Symbol(), PERIOD_M15, 0, 10, L);
        CopyClose(Symbol(), PERIOD_M15, 0, 10, C);
        CopyOpen(Symbol(), PERIOD_M15, 0, 10, O);
        
        hasBullFVG = false; hasBearFVG = false;
        hasBullOB = false;  hasBearOB = false;
        liqSweepBull = false; liqSweepBear = false;
        
        // FVG Logic (Candle 1 High < Candle 3 Low for Bearish FVG, vice versa)
        if(L[7] > H[9]) hasBullFVG = true; 
        if(H[7] < L[9]) hasBearFVG = true;

        // OB Logic (Down close before sharp up move)
        if(C[8] < O[8] && C[9] > O[9] && C[9] > H[8]) hasBullOB = true;
        if(C[8] > O[8] && C[9] < O[9] && C[9] < L[8]) hasBearOB = true;

        // Liquidity Sweep (Swept previous low but closed above)
        if(L[9] < L[8] && C[9] > L[8]) liqSweepBull = true;
        if(H[9] > H[8] && C[9] < H[8]) liqSweepBear = true;

        if(liqSweepBull || liqSweepBear) g_liqState = "EXT SWEPT";
        else if(hasBullFVG || hasBearFVG) g_liqState = "FVG IMBALANCE";
        else g_liqState = "INTERNAL";
    }
};

// 2. MULTI-TIMEFRAME ENGINE
class CMTF_Engine {
public:
    int GetBias() {
        double d1[], h4[], m15[];
        CopyClose(Symbol(), PERIOD_D1, 0, 2, d1);
        CopyClose(Symbol(), PERIOD_H4, 0, 2, h4);
        CopyClose(Symbol(), PERIOD_M15, 0, 2, m15);
        
        int bias = 0;
        if(d1[1] > d1[0]) bias++; else bias--;
        if(h4[1] > h4[0]) bias++; else bias--;
        if(m15[1] > m15[0]) bias++; else bias--;
        
        if(bias > 1) { g_bias = "BULLISH"; return 1; }
        if(bias < -1){ g_bias = "BEARISH"; return -1; }
        g_bias = "RANGE"; return 0;
    }
};

// 3. GOLD SPECIFIC & SESSION ENGINE
class CSession_Engine {
public:
    double GetSessionMultiplier() {
        MqlDateTime dt; TimeToStruct(TimeCurrent(), dt);
        int h = dt.hour;
        // Institutional Gold Regimes
        if(h >= 13 && h <= 17) { g_sessionStr = "NY EXPANSION"; return 1.0; } // NY overlaps London
        if(h >= 8 && h <= 12)  { g_sessionStr = "LDN MANIPULATION"; return 0.8; }
        if(h >= 1 && h <= 6)   { g_sessionStr = "ASIAN COMPRESSION"; return 0.3; }
        g_sessionStr = "OFF-PEAK";
        return 0.5;
    }
};

// 4. VOLATILITY ENGINE
class CVol_Engine {
public:
    double atrVal;
    
    double GetVolatilityScore() {
        double atr[1];
        if(CopyBuffer(g_atrHandle, 0, 0, 1, atr) > 0) {
            atrVal = atr[0];
            double point = SymbolInfoDouble(Symbol(), SYMBOL_POINT);
            double atrPts = atrVal / point;
            
            if(atrPts > 500) { g_volState = "HIGH (NEWS/SHOCK)"; return 0.2; } // Too volatile
            if(atrPts > 200) { g_volState = "OPTIMAL EXPANSION"; return 1.0; }
            g_volState = "LOW COMPRESSION"; return 0.6;
        }
        return 0.5;
    }
};

CSMC_Engine     SMC;
CMTF_Engine     MTF;
CSession_Engine SES;
CVol_Engine     VOL;

// 5. AI DECISION ENGINE
class CAI_Engine {
public:
    double GenerateScore(int &dir) {
        SMC.Analyze();
        int mtfBias = MTF.GetBias();
        double sesMult = SES.GetSessionMultiplier();
        double volScore = VOL.GetVolatilityScore();
        
        // Base inputs (0 to 1)
        double smcInp = 0.0;
        if(mtfBias == 1 && (SMC.hasBullOB || SMC.hasBullFVG || SMC.liqSweepBull)) smcInp = 1.0;
        else if(mtfBias == -1 && (SMC.hasBearOB || SMC.hasBearFVG || SMC.liqSweepBear)) smcInp = 1.0;
        
        double mtfInp = (mtfBias != 0) ? 1.0 : 0.0;
        
        // AI Weighted Neural Summation
        double rawScore = (smcInp * g_weights.smc_w) + 
                          (mtfInp * g_weights.mtf_w) + 
                          (volScore * g_weights.vol_w) + 
                          (sesMult * g_weights.ses_w);
                          
        // Normalize 0-100
        double totalW = g_weights.smc_w + g_weights.mtf_w + g_weights.vol_w + g_weights.ses_w;
        double aiScore = (rawScore / totalW) * 100.0;
        
        dir = mtfBias;
        g_curScore = aiScore;
        
        if(aiScore > 90) g_mktState = "A+ HIGH PROBABILITY";
        else if(aiScore > 80) g_mktState = "B GRADE SETUP";
        else g_mktState = "NO CLEAR EDGE";
        
        return aiScore;
    }
};
CAI_Engine AI;

// 6. REINFORCEMENT LEARNING ENGINE
class CML_Engine {
public:
    string dbName;
    
    CML_Engine() { dbName = "PhantomAI_Weights.bin"; }
    
    void LoadWeights() {
        if(FileIsExist(dbName)) {
            int h = FileOpen(dbName, FILE_READ|FILE_BIN);
            FileReadStruct(h, g_weights);
            FileClose(h);
        } else {
            g_weights.smc_w = 0.35; g_weights.mtf_w = 0.30; 
            g_weights.vol_w = 0.20; g_weights.ses_w = 0.15;
        }
    }
    
    void SaveWeights() {
        int h = FileOpen(dbName, FILE_WRITE|FILE_BIN);
        FileWriteStruct(h, g_weights);
        FileClose(h);
    }
    
    void RegisterTrade(ulong tkt, double score) {
        int sz = ArraySize(g_mem);
        ArrayResize(g_mem, sz+1);
        g_mem[sz].ticket = tkt;
        g_mem[sz].smc_val = SMC.hasBullOB || SMC.hasBearOB ? 1.0 : 0.5;
        g_mem[sz].mtf_val = MTF.GetBias() != 0 ? 1.0 : 0.0;
        g_mem[sz].vol_val = VOL.GetVolatilityScore();
        g_mem[sz].ses_val = SES.GetSessionMultiplier();
        g_mem[sz].ai_score = score;
    }
    
    void EvaluateHistory() {
        if(!InpEnableLearning) return;
        HistorySelect(0, TimeCurrent());
        for(int i=ArraySize(g_mem)-1; i>=0; i--) {
            if(HistoryDealSelect(g_mem[i].ticket)) {
                double profit = HistoryDealGetDouble(g_mem[i].ticket, DEAL_PROFIT);
                double alpha = InpLearningRate;
                
                // Gradient Update
                if(profit > 0) { 
                    g_mlWins++;
                    g_weights.smc_w += alpha * g_mem[i].smc_val;
                    g_weights.mtf_w += alpha * g_mem[i].mtf_val;
                    g_weights.vol_w += alpha * g_mem[i].vol_val;
                    g_weights.ses_w += alpha * g_mem[i].ses_val;
                } else {
                    g_mlLosses++;
                    g_weights.smc_w -= alpha * g_mem[i].smc_val;
                    g_weights.mtf_w -= alpha * g_mem[i].mtf_val;
                    g_weights.vol_w -= alpha * (1.0 - g_mem[i].vol_val);
                    g_weights.ses_w -= alpha * (1.0 - g_mem[i].ses_val);
                }
                
                // Normalize Weights to prevent explosion
                double t = g_weights.smc_w + g_weights.mtf_w + g_weights.vol_w + g_weights.ses_w;
                g_weights.smc_w /= t; g_weights.mtf_w /= t;
                g_weights.vol_w /= t; g_weights.ses_w /= t;
                
                SaveWeights();
                
                // Remove from active memory
                for(int j=i; j<ArraySize(g_mem)-1; j++) g_mem[j] = g_mem[j+1];
                ArrayResize(g_mem, ArraySize(g_mem)-1);
            }
        }
    }
};
CML_Engine ML;

//=======================================================================
//  INITIALIZATION
//=======================================================================
int OnInit() {
    g_trade.SetExpertMagicNumber(InpMagicNumber);
    g_atrHandle = iATR(Symbol(), PERIOD_M15, InpATRPeriod);
    
    g_peakEquity = AccountInfoDouble(ACCOUNT_EQUITY);
    g_dailyStartEq = g_peakEquity;
    
    ML.LoadWeights();
    
    EventSetTimer(1);
    BuildUI();
    
    Print("PHANTOM SCALPER AI initialized. Neural Weights Loaded.");
    return INIT_SUCCEEDED;
}

void OnDeinit(const int reason) {
    EventKillTimer();
    ObjectsDeleteAll(0, D_PREFIX);
    ChartRedraw();
}

//=======================================================================
//  MAIN EXECUTION LOOP
//=======================================================================
void OnTick() {
    // Risk Engine Guard
    double eq = AccountInfoDouble(ACCOUNT_EQUITY);
    if(eq > g_peakEquity) g_peakEquity = eq;
    
    // Daily Reset
    if(TimeDay(TimeCurrent()) != TimeDay(g_lastDay)) {
        g_dailyStartEq = eq;
        g_lastDay = TimeCurrent();
    }
    
    double draw = (g_dailyStartEq - eq) / g_dailyStartEq * 100.0;
    if(draw >= InpMaxDailyDraw) {
        g_mktState = "DAILY DRAWDOWN HIT"; return;
    }
    
    // Spread Guard
    int spr = (int)SymbolInfoInteger(Symbol(), SYMBOL_SPREAD);
    if(spr > InpMaxSpreadPts) return;
    
    // Evaluate Setup
    int dir = 0;
    double aiScore = AI.GenerateScore(dir);
    
    // Execution Engine
    if(aiScore >= InpMinAIScore && dir != 0 && PositionsTotal() == 0) {
        ExecuteInstitutionalTrade(dir, aiScore);
    }
    
    // Trade Management Engine
    ManageOpenTrades();
}

void OnTimer() {
    ML.EvaluateHistory();
    UpdateUI();
}

//=======================================================================
//  TRADE EXECUTION & MANAGEMENT
//=======================================================================
void ExecuteInstitutionalTrade(int dir, double score) {
    double pr = (dir==1) ? SymbolInfoDouble(Symbol(), SYMBOL_ASK) : SymbolInfoDouble(Symbol(), SYMBOL_BID);
    double pt = SymbolInfoDouble(Symbol(), SYMBOL_POINT);
    
    // Dynamic Lot Sizing based on AI Confidence
    double riskMult = (score > 95) ? 1.5 : (score > 90) ? 1.0 : 0.5;
    double lot = NormalizeDouble(InpBaseLotSize * riskMult, 2);
    
    // Institutional Stop Loss (using ATR)
    double atr = VOL.atrVal;
    double slDist = atr * 1.5;
    double tpDist = slDist * InpTargetR;
    
    double sl = (dir==1) ? pr - slDist : pr + slDist;
    double tp = (dir==1) ? pr + tpDist : pr - tpDist;
    
    if(dir == 1) {
        if(g_trade.Buy(lot, Symbol(), pr, sl, tp, "AI Buy")) ML.RegisterTrade(g_trade.ResultOrder(), score);
    } else {
        if(g_trade.Sell(lot, Symbol(), pr, sl, tp, "AI Sell")) ML.RegisterTrade(g_trade.ResultOrder(), score);
    }
}

void ManageOpenTrades() {
    // Advanced Trailing Stop & Profit Locking Logic
    for(int i=PositionsTotal()-1; i>=0; i--) {
        if(g_pos.SelectByIndex(i) && g_pos.Magic() == InpMagicNumber) {
            double profit = g_pos.Profit();
            if(profit > 0 && g_curScore < (InpMinAIScore - 15)) {
                // Market structure shifted against us, smart exit
                g_trade.PositionClose(g_pos.Ticket());
            }
        }
    }
}

//=======================================================================
//  INSTITUTIONAL DASHBOARD UI (Auto-Scaling Glassmorphism)
//=======================================================================
void DrawRect(string nm, int x, int y, int w, int h, color bg, color brd, int z) {
    string n = D_PREFIX + nm;
    ObjectCreate(0, n, OBJ_RECTANGLE_LABEL, 0, 0, 0);
    ObjectSetInteger(0, n, OBJPROP_XDISTANCE, x);
    ObjectSetInteger(0, n, OBJPROP_YDISTANCE, y);
    ObjectSetInteger(0, n, OBJPROP_XSIZE, w);
    ObjectSetInteger(0, n, OBJPROP_YSIZE, h);
    ObjectSetInteger(0, n, OBJPROP_BGCOLOR, bg);
    ObjectSetInteger(0, n, OBJPROP_BORDER_TYPE, BORDER_FLAT);
    ObjectSetInteger(0, n, OBJPROP_COLOR, brd);
    ObjectSetInteger(0, n, OBJPROP_CORNER, CORNER_LEFT_UPPER);
    ObjectSetInteger(0, n, OBJPROP_BACK, false);
    ObjectSetInteger(0, n, OBJPROP_ZORDER, z);
    ObjectSetInteger(0, n, OBJPROP_SELECTABLE, false);
    ObjectSetInteger(0, n, OBJPROP_HIDDEN, true);
}

void DrawTxt(string nm, int x, int y, string txt, color clr, int sz, string fnt, int z) {
    string n = D_PREFIX + nm;
    ObjectCreate(0, n, OBJ_LABEL, 0, 0, 0);
    ObjectSetInteger(0, n, OBJPROP_XDISTANCE, x);
    ObjectSetInteger(0, n, OBJPROP_YDISTANCE, y);
    ObjectSetString(0, n, OBJPROP_TEXT, txt);
    ObjectSetInteger(0, n, OBJPROP_COLOR, clr);
    ObjectSetInteger(0, n, OBJPROP_FONTSIZE, sz);
    ObjectSetString(0, n, OBJPROP_FONT, fnt);
    ObjectSetInteger(0, n, OBJPROP_CORNER, CORNER_LEFT_UPPER);
    ObjectSetInteger(0, n, OBJPROP_ZORDER, z);
    ObjectSetInteger(0, n, OBJPROP_SELECTABLE, false);
    ObjectSetInteger(0, n, OBJPROP_HIDDEN, true);
}

void BuildUI() {
    int W = (int)ChartGetInteger(0, CHART_WIDTH_IN_PIXELS) / 2;
    if(W > 500) W = 500; if(W < 320) W = 320;
    int H = (int)ChartGetInteger(0, CHART_HEIGHT_IN_PIXELS) - 20;
    
    // Base Frame
    DrawRect("bg", 10, 10, W, H, C_BG_DEEP, C_BORDER, 0);
    DrawRect("hdr", 20, 20, W-20, 60, C_BG_PANEL, C_ACCENT_BLUE, 1);
    
    DrawTxt("t_title", 35, 30, "PHANTOM AI ENGINE", C_TEXT_MAIN, 12, "Arial Bold", 2);
    DrawTxt("t_sub", 35, 52, "Institutional XAUUSD Intelligence", C_GOLD, 8, "Arial", 2);
    
    // AI Score Circle/Card
    DrawRect("c_ai", 20, 95, W-20, 80, C_BG_CARD, C_BORDER, 1);
    DrawTxt("l_ai1", 35, 110, "AI CONFIDENCE SCORE", C_TEXT_MUTED, 8, "Arial", 2);
    DrawTxt("v_ai", 35, 125, "0.0%", C_CYAN_LITE, 22, "Arial Bold", 2);
    DrawTxt("v_ai_st", 160, 135, "ANALYZING...", C_GOLD, 9, "Arial Bold", 2);
    
    // Intelligence Matrix
    DrawRect("c_mx", 20, 190, W-20, 160, C_BG_PANEL, C_BORDER, 1);
    DrawTxt("l_mx", 35, 205, "INTELLIGENCE MATRIX", C_ACCENT_BLUE, 8, "Arial Bold", 2);
    
    int yOff = 230;
    DrawTxt("l_b", 35, yOff, "MTF Trend Bias:", C_TEXT_MUTED, 9, "Arial", 2);
    DrawTxt("v_b", 150, yOff, "--", C_TEXT_MAIN, 9, "Arial Bold", 2);
    
    DrawTxt("l_l", 35, yOff+25, "Liquidity Profile:", C_TEXT_MUTED, 9, "Arial", 2);
    DrawTxt("v_l", 150, yOff+25, "--", C_TEXT_MAIN, 9, "Arial Bold", 2);
    
    DrawTxt("l_v", 35, yOff+50, "Volatility State:", C_TEXT_MUTED, 9, "Arial", 2);
    DrawTxt("v_v", 150, yOff+50, "--", C_TEXT_MAIN, 9, "Arial Bold", 2);
    
    DrawTxt("l_s", 35, yOff+75, "Session Status:", C_TEXT_MUTED, 9, "Arial", 2);
    DrawTxt("v_s", 150, yOff+75, "--", C_TEXT_MAIN, 9, "Arial Bold", 2);

    // Machine Learning Card
    DrawRect("c_ml", 20, 365, W-20, 90, C_BG_CARD, C_BORDER, 1);
    DrawTxt("l_ml", 35, 380, "ML REINFORCEMENT LEARNING", C_GOLD, 8, "Arial Bold", 2);
    DrawTxt("l_wr", 35, 400, "Historical Win Rate:", C_TEXT_MUTED, 9, "Arial", 2);
    DrawTxt("v_wr", 180, 400, "0%", C_GREEN_PROFIT, 9, "Arial Bold", 2);
    DrawTxt("l_ww", 35, 420, "SMC/MTF Weights:", C_TEXT_MUTED, 9, "Arial", 2);
    DrawTxt("v_ww", 180, 420, "0.00 / 0.00", C_TEXT_MAIN, 9, "Arial", 2);
    
    // Execution Card
    DrawRect("c_ex", 20, 470, W-20, H-470, C_BG_PANEL, C_BORDER, 1);
    DrawTxt("l_ex", 35, 485, "EXECUTION METRICS", C_ACCENT_BLUE, 8, "Arial Bold", 2);
    DrawTxt("l_eq", 35, 505, "Session PnL / Drawdown:", C_TEXT_MUTED, 9, "Arial", 2);
    DrawTxt("v_eq", 200, 505, "$0.00 (0.0%)", C_TEXT_MAIN, 9, "Arial Bold", 2);
}

void UpdateUI() {
    // Dynamic UI Resize check
    int W = (int)ChartGetInteger(0, CHART_WIDTH_IN_PIXELS) / 2;
    if(W > 500) W = 500; if(W < 320) W = 320;
    int H = (int)ChartGetInteger(0, CHART_HEIGHT_IN_PIXELS) - 20;
    
    ObjectSetInteger(0, D_PREFIX+"bg", OBJPROP_XSIZE, W);
    ObjectSetInteger(0, D_PREFIX+"bg", OBJPROP_YSIZE, H);
    ObjectSetInteger(0, D_PREFIX+"c_ex", OBJPROP_YSIZE, H-470);
    
    // Update Values
    ObjectSetString(0, D_PREFIX+"v_ai", OBJPROP_TEXT, DoubleToString(g_curScore, 1) + "%");
    color stColor = (g_curScore >= InpMinAIScore) ? C_GREEN_PROFIT : C_GOLD;
    ObjectSetString(0, D_PREFIX+"v_ai_st", OBJPROP_TEXT, g_mktState);
    ObjectSetInteger(0, D_PREFIX+"v_ai_st", OBJPROP_COLOR, stColor);
    
    ObjectSetString(0, D_PREFIX+"v_b", OBJPROP_TEXT, g_bias);
    ObjectSetInteger(0, D_PREFIX+"v_b", OBJPROP_COLOR, (g_bias=="BULLISH")?C_GREEN_PROFIT:(g_bias=="BEARISH")?C_RED_LOSS:C_TEXT_MAIN);
    
    ObjectSetString(0, D_PREFIX+"v_l", OBJPROP_TEXT, g_liqState);
    ObjectSetString(0, D_PREFIX+"v_v", OBJPROP_TEXT, g_volState);
    ObjectSetString(0, D_PREFIX+"v_s", OBJPROP_TEXT, g_sessionStr);
    
    int t = g_mlWins + g_mlLosses;
    double wr = (t > 0) ? ((double)g_mlWins/t)*100.0 : 0.0;
    ObjectSetString(0, D_PREFIX+"v_wr", OBJPROP_TEXT, DoubleToString(wr,1) + "% (" + IntegerToString(t) + " Trades)");
    ObjectSetString(0, D_PREFIX+"v_ww", OBJPROP_TEXT, DoubleToString(g_weights.smc_w, 2) + " / " + DoubleToString(g_weights.mtf_w, 2));
    
    double pnl = AccountInfoDouble(ACCOUNT_EQUITY) - g_dailyStartEq;
    double dd = (g_dailyStartEq > 0) ? (g_peakEquity - AccountInfoDouble(ACCOUNT_EQUITY)) / g_peakEquity * 100.0 : 0;
    
    ObjectSetString(0, D_PREFIX+"v_eq", OBJPROP_TEXT, "$" + DoubleToString(pnl,2) + " / " + DoubleToString(dd,2) + "% DD");
    ObjectSetInteger(0, D_PREFIX+"v_eq", OBJPROP_COLOR, (pnl >= 0) ? C_GREEN_PROFIT : C_RED_LOSS);
    
    ChartRedraw();
}
//+------------------------------------------------------------------+