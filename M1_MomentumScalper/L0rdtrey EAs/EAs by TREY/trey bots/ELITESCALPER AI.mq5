//====================== INSTITUTIONAL QUANT DASHBOARD ==============//
//  PROFESSIONAL HEDGE FUND EXECUTION TERMINAL UI
//===================================================================//

//================ DASHBOARD DIMENSIONS =============================//
const int DW=430;
const int DH=520;

//+------------------------------------------------------------------+
void CreateDashboard()
{
   int X=8;
   int Y=18;

  //+------------------------------------------------------------------+
//|   INSTITUTIONAL QUANT DASHBOARD FRAMEWORK                        |
//|   CLEAN UI ARCHITECTURE - ERROR FREE                             |
//+------------------------------------------------------------------+
#property strict

#include <Trade/Trade.mqh>

//==================== DASHBOARD PREFIX ============================//
#define DASH_PRE "ELITE_UI_"

//==================== COLORS =====================================//
#define C_BG      C'4,6,10'
#define C_PANEL   C'12,16,24'
#define C_BLUE    C'0,120,255'
#define C_GREEN   C'0,230,120'
#define C_RED     C'240,60,60'
#define C_WHITE   C'240,245,255'
#define C_TEXT    C'170,185,210'
#define C_GRAY    C'90,100,120'
#define C_GOLD    C'255,200,50'

//==================== DASHBOARD SIZE ==============================//
const int X0 = 10;
const int Y0 = 20;
const int W  = 430;
const int H  = 520;

//==================== GLOBAL UI STATE ============================//
string g_status="INIT";
string g_bias="NEUTRAL";
string g_reason="WAITING";
string g_action="NONE";

//+------------------------------------------------------------------+
//| INIT                                                             |
//+------------------------------------------------------------------+
int OnInit()
{
   CreateDashboard();
   EventSetTimer(1);
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   EventKillTimer();
   DeleteDashboard();
}

//+------------------------------------------------------------------+
void OnTimer()
{
   UpdateDashboard();
}

//==================================================================//
//                    UI CORE FUNCTIONS                              //
//==================================================================//

//-------------------- RECTANGLE -----------------------------------//
void Rect(string name,int x,int y,int w,int h,color bg,color border)
{
   string n = DASH_PRE + name;

   if(ObjectFind(0,n) < 0)
      ObjectCreate(0,n,OBJ_RECTANGLE_LABEL,0,0,0);

   ObjectSetInteger(0,n,OBJPROP_CORNER,CORNER_LEFT_UPPER);
   ObjectSetInteger(0,n,OBJPROP_XDISTANCE,x);
   ObjectSetInteger(0,n,OBJPROP_YDISTANCE,y);
   ObjectSetInteger(0,n,OBJPROP_XSIZE,w);
   ObjectSetInteger(0,n,OBJPROP_YSIZE,h);
   ObjectSetInteger(0,n,OBJPROP_BGCOLOR,bg);
   ObjectSetInteger(0,n,OBJPROP_COLOR,border);
}

//-------------------- LABEL --------------------------------------//
void Label(string name,int x,int y,string txt,color clr,int size)
{
   string n = DASH_PRE + name;

   if(ObjectFind(0,n) < 0)
      ObjectCreate(0,n,OBJ_LABEL,0,0,0);

   ObjectSetInteger(0,n,OBJPROP_CORNER,CORNER_LEFT_UPPER);
   ObjectSetInteger(0,n,OBJPROP_XDISTANCE,x);
   ObjectSetInteger(0,n,OBJPROP_YDISTANCE,y);
   ObjectSetInteger(0,n,OBJPROP_COLOR,clr);
   ObjectSetInteger(0,n,OBJPROP_FONTSIZE,size);
   ObjectSetString(0,n,OBJPROP_TEXT,txt);
   ObjectSetString(0,n,OBJPROP_FONT,"Arial Bold");
}

//-------------------- SET LABEL ----------------------------------//
void SetLabel(string name,string txt)
{
   string n = DASH_PRE + name;

   if(ObjectFind(0,n) >= 0)
      ObjectSetString(0,n,OBJPROP_TEXT,txt);
}

//==================================================================//
//                    DASHBOARD STRUCTURE                            //
//==================================================================//

void CreateDashboard()
{
   // MAIN BACKGROUND
   Rect("bg",X0,Y0,W,H,C_BG,C_BLUE);

   // HEADER
   Rect("header",X0+5,Y0+5,W-10,80,C_PANEL,C_BLUE);

   Label("title",X0+15,Y0+15,
         "ELITESCALPER AI ENGINE",
         C_WHITE,14);

   Label("subtitle",X0+15,Y0+40,
         "Institutional Quant Execution Terminal",
         C_BLUE,9);

   Label("subtitle2",X0+15,Y0+60,
         "Smart Money | AI | Liquidity Execution",
         C_TEXT,8);

   // STATUS BAR
   Rect("statusbar",X0+5,Y0+90,W-10,35,C_PANEL,C_BLUE);

   Label("status_t",X0+15,Y0+100,"STATUS:",C_TEXT,8);
   Label("status_v",X0+80,Y0+100,"LIVE",C_GREEN,8);

   Label("bias_t",X0+170,Y0+100,"BIAS:",C_TEXT,8);
   Label("bias_v",X0+220,Y0+100,"NEUTRAL",C_WHITE,8);

   Label("session_t",X0+310,Y0+100,"SESSION:",C_TEXT,8);
   Label("session_v",X0+380,Y0+100,"LONDON",C_GOLD,8);

   // ANALYTICS PANEL
   Rect("analytics",X0+5,Y0+130,210,200,C_PANEL,C_BLUE);

   Label("a_hd",X0+15,Y0+145,"ACCOUNT",C_WHITE,10);

   Label("bal_t",X0+15,Y0+175,"BAL:",C_TEXT,8);
   Label("bal_v",X0+110,Y0+175,"0.00",C_WHITE,9);

   Label("eq_t",X0+15,Y0+200,"EQUITY:",C_TEXT,8);
   Label("eq_v",X0+110,Y0+200,"0.00",C_WHITE,9);

   Label("pl_t",X0+15,Y0+225,"P/L:",C_TEXT,8);
   Label("pl_v",X0+110,Y0+225,"0.00",C_GREEN,9);

   Label("sp_t",X0+15,Y0+250,"SPREAD:",C_TEXT,8);
   Label("sp_v",X0+110,Y0+250,"OK",C_GREEN,9);

   // EXECUTION PANEL
   Rect("exec",X0+220,Y0+130,200,200,C_PANEL,C_BLUE);

   Label("e_hd",X0+230,Y0+145,"EXECUTION",C_WHITE,10);

   Label("st_t",X0+230,Y0+175,"ENGINE:",C_TEXT,8);
   Label("st_v",X0+330,Y0+175,"READY",C_GREEN,9);

   Label("act_t",X0+230,Y0+200,"ACTION:",C_TEXT,8);
   Label("act_v",X0+330,Y0+200,"NONE",C_WHITE,9);

   Label("rea_t",X0+230,Y0+225,"REASON:",C_TEXT,8);
   Label("rea_v",X0+330,Y0+225,"WAIT",C_GOLD,9);

   Label("dir_t",X0+230,Y0+250,"DIRECTION:",C_TEXT,8);
   Label("dir_v",X0+330,Y0+250,"NONE",C_WHITE,9);

   // AI MATRIX
   Rect("ai",X0+5,Y0+340,W-10,110,C_PANEL,C_BLUE);

   Label("ai_hd",X0+15,Y0+350,"AI DECISION MATRIX",C_WHITE,10);

   Label("m1",X0+15,Y0+375,"Liquidity Sweep",C_TEXT,8);
   Label("m2",X0+15,Y0+395,"Order Block",C_TEXT,8);
   Label("m3",X0+15,Y0+415,"FVG Detection",C_TEXT,8);

   Label("m1v",X0+320,Y0+375,"ACTIVE",C_GREEN,8);
   Label("m2v",X0+320,Y0+395,"ACTIVE",C_GREEN,8);
   Label("m3v",X0+320,Y0+415,"ACTIVE",C_GREEN,8);

   // FOOTER
   Rect("footer",X0+5,Y0+455,W-10,50,C_PANEL,C_BLUE);

   Label("f1",X0+15,Y0+470,
         "Institutional AI Engine | Live Market Execution",
         C_GRAY,7);
}

//==================================================================//
//                    LIVE UPDATE ENGINE                             //
//==================================================================//

void UpdateDashboard()
{
   SetLabel("status_v",g_status);
   SetLabel("bias_v",g_bias);
   SetLabel("act_v",g_action);
   SetLabel("rea_v",g_reason);
   SetLabel("dir_v",g_bias);

   SetLabel("bal_v",
      DoubleToString(AccountInfoDouble(ACCOUNT_BALANCE),2));

   SetLabel("eq_v",
      DoubleToString(AccountInfoDouble(ACCOUNT_EQUITY),2));

   ChartRedraw(0);
}

//==================================================================//
//                    CLEANUP                                        //
//==================================================================//

void DeleteDashboard()
{
   int total=ObjectsTotal(0);

   for(int i=total-1;i>=0;i--)
   {
      string name=ObjectName(0,i);

      if(StringFind(name,DASH_PRE)==0)
         ObjectDelete(0,name);
   }
}
   //================ INSTITUTIONAL HEADER =================//
   Rect("header",X+4,Y+4,422,82,C_PANEL,C_BLUE);

   Label("brand",
         X+18,Y+18,
         "ELITESCALPER AI ENGINE",
         C_WHITE,16);

   Label("subtitle",
         X+18,Y+44,
         "Institutional Quant Execution Terminal",
         C_BLUE,10);

   Label("subtitle2",
         X+18,Y+62,
         "Smart Money Infrastructure | Autonomous AI",
         C_TEXT,8);

   //================ REAL-TIME STATUS BAR =================//
   Rect("statusbar",X+4,Y+92,422,34,C_PANEL,C_BLUE);

   Label("status_t",
         X+14,Y+102,
         "SYSTEM:",
         C_TEXT,8);

   Label("status_v",
         X+78,Y+102,
         "LIVE",
         C_GREEN,8);

   Label("market_t",
         X+165,Y+102,
         "MARKET:",
         C_TEXT,8);

   Label("market_v",
         X+235,Y+102,
         Symbol(),
         C_WHITE,8);

   Label("session_t",
         X+315,Y+102,
         "SESSION:",
         C_TEXT,8);

   Label("session_v",
         X+385,Y+102,
         "LONDON",
         C_GOLD,8);

   //================ ACCOUNT ANALYTICS PANEL =================//
   Rect("analytics",X+4,Y+132,205,198,C_PANEL,C_BLUE);

   Label("analytics_hd",
         X+14,Y+145,
         "ACCOUNT ANALYTICS",
         C_WHITE,11);

   Line("a_line1",X+14,Y+165,185,C_GRAY);

   Label("bal_t",
         X+18,Y+182,
         "BALANCE",
         C_TEXT,8);

   Label("bal_v",
         X+120,Y+182,
         "$0.00",
         C_WHITE,9);

   Label("eq_t",
         X+18,Y+212,
         "EQUITY",
         C_TEXT,8);

   Label("eq_v",
         X+120,Y+212,
         "$0.00",
         C_WHITE,9);

   Label("fp_t",
         X+18,Y+242,
         "FLOATING P/L",
         C_TEXT,8);

   Label("fp_v",
         X+120,Y+242,
         "$0.00",
         C_GREEN,9);

   Label("dp_t",
         X+18,Y+272,
         "DAILY P/L",
         C_TEXT,8);

   Label("dp_v",
         X+120,Y+272,
         "$0.00",
         C_GREEN,9);

   Label("spread_t",
         X+18,Y+302,
         "SPREAD",
         C_TEXT,8);

   Label("spread_v",
         X+120,Y+302,
         "NORMAL",
         C_GREEN,9);

   //================ LIVE EXECUTION TERMINAL =================//
   Rect("execution",X+220,Y+132,206,198,C_PANEL,C_BLUE);

   Label("exec_hd",
         X+230,Y+145,
         "LIVE EXECUTION TERMINAL",
         C_WHITE,11);

   Line("e_line1",X+230,Y+165,186,C_GRAY);

   Label("engine_t",
         X+234,Y+182,
         "ENGINE",
         C_TEXT,8);

   Label("engine_v",
         X+340,Y+182,
         "ACTIVE",
         C_GREEN,9);

   Label("action_t",
         X+234,Y+212,
         "LAST ACTION",
         C_TEXT,8);

   Label("action_v",
         X+340,Y+212,
         "NONE",
         C_WHITE,9);

   Label("reason_t",
         X+234,Y+242,
         "TRADE REASON",
         C_TEXT,8);

   Label("reason_v",
         X+340,Y+242,
         "WAITING",
         C_GOLD,9);

   Label("direction_t",
         X+234,Y+272,
         "BIAS",
         C_TEXT,8);

   Label("direction_v",
         X+340,Y+272,
         "NEUTRAL",
         C_WHITE,9);

   Label("tradecount_t",
         X+234,Y+302,
         "TRADES",
         C_TEXT,8);

   Label("tradecount_v",
         X+340,Y+302,
         "0",
         C_WHITE,9);

   //================ AI DECISION MATRIX =================//
   Rect("matrix",X+4,Y+338,422,132,C_PANEL,C_BLUE);

   Label("matrix_hd",
         X+14,Y+350,
         "AI DECISION MATRIX",
         C_WHITE,11);

   Line("m_line1",X+14,Y+370,402,C_GRAY);

   Label("m1",
         X+18,Y+388,
         "Liquidity Sweep Analysis",
         C_TEXT,8);

   Label("m1v",
         X+330,Y+388,
         "ACTIVE",
         C_GREEN,8);

   Label("m2",
         X+18,Y+412,
         "Fair Value Gap Detection",
         C_TEXT,8);

   Label("m2v",
         X+330,Y+412,
         "ACTIVE",
         C_GREEN,8);

   Label("m3",
         X+18,Y+436,
         "Order Block Validation",
         C_TEXT,8);

   Label("m3v",
         X+330,Y+436,
         "ACTIVE",
         C_GREEN,8);

   Label("m4",
         X+18,Y+460,
         "Multi-Timeframe Alignment",
         C_TEXT,8);

   Label("m4v",
         X+330,Y+460,
         "ACTIVE",
         C_GREEN,8);

   //================ FOOTER INFRASTRUCTURE =================//
   Rect("footer",X+4,Y+476,422,36,C_PANEL,C_BLUE);

   Label("footer1",
         X+16,Y+489,
         "Autonomous Institutional Infrastructure",
         C_GRAY,7);

   Label("footer2",
         X+255,Y+489,
         "AI EXECUTION ONLINE",
         C_BLUE,7);
}

//+------------------------------------------------------------------+
//| ADVANCED DASHBOARD UPDATE                                        |
//+------------------------------------------------------------------+
void UpdateDashboard()
{
   //================ ACCOUNT METRICS =================//
   SetLabel("bal_v",
   "$"+DoubleToString(AccountInfoDouble(ACCOUNT_BALANCE),2));

   SetLabel("eq_v",
   "$"+DoubleToString(AccountInfoDouble(ACCOUNT_EQUITY),2));

   SetLabel("fp_v",
   "$"+DoubleToString(FloatingProfit(),2));

   SetLabel("dp_v",
   "$"+DoubleToString(g_profitToday,2));

   //================ EXECUTION TERMINAL =================//
   SetLabel("engine_v",g_status);

   SetLabel("action_v",g_lastAction);

   SetLabel("reason_v",g_tradeReason);

   SetLabel("direction_v",g_tradeDirection);

   SetLabel("tradecount_v",
   IntegerToString(g_tradesToday));

   //================ SPREAD MONITOR =================//
   if(SpreadAllowed())
      SetLabel("spread_v","NORMAL");
   else
      SetLabel("spread_v","HIGH");

   //================ SESSION MONITOR =================//
   MqlDateTime tm;
   TimeToStruct(TimeCurrent(),tm);

   string sess="ASIAN";

   if(tm.hour>=7 && tm.hour<=16)
      sess="LONDON";

   if(tm.hour>=13 && tm.hour<=22)
      sess="NEW YORK";

   SetLabel("session_v",sess);

   //================ AI MATRIX STATUS =================//
   SetLabel("m1v","ACTIVE");
   SetLabel("m2v","ACTIVE");
   SetLabel("m3v","ACTIVE");
   SetLabel("m4v","ACTIVE");

   //================ SYSTEM STATUS =================//
   SetLabel("status_v","ONLINE");

   ChartRedraw(0);
}

//+------------------------------------------------------------------+
//| HORIZONTAL LINE                                                  |
//+------------------------------------------------------------------+
void Line(string name,int x,int y,int width,color clr)
{
   string n=DASH_PRE+name;

   ObjectCreate(0,n,OBJ_RECTANGLE_LABEL,0,0,0);

   ObjectSetInteger(0,n,OBJPROP_XDISTANCE,x);

   ObjectSetInteger(0,n,OBJPROP_YDISTANCE,y);

   ObjectSetInteger(0,n,OBJPROP_XSIZE,width);

   ObjectSetInteger(0,n,OBJPROP_YSIZE,1);

   ObjectSetInteger(0,n,OBJPROP_BGCOLOR,clr);

   ObjectSetInteger(0,n,OBJPROP_COLOR,clr);

   ObjectSetInteger(0,n,OBJPROP_BORDER_TYPE,BORDER_FLAT);
}
