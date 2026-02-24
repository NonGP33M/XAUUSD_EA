#property strict

// ===== INPUTS =====
input string InpFileName      = "m5_candidates_ea1.csv";
input int    InpLookback      = 10;

input int EMA_fast     = 50;
input int EMA_slow     = 200;
input int EMA_pullback = 20;
input int ATR_period   = 14;
input double MinBodyPts = 30;

// ===== GLOBAL =====
datetime g_lastBar = 0;
int g_file;

// Indicator handles
int hEMA20_M5;
int hEMAfast_M15;
int hEMAslow_M15;
int hEMAfast_H1;
int hEMAslow_H1;

// ===== UTIL =====
bool IsNewBar()
{
   datetime t = iTime(_Symbol, PERIOD_M5, 0);
   if(t != g_lastBar)
   {
      g_lastBar = t;
      return true;
   }
   return false;
}

double GetValue(int handle,int shift)
{
   double buf[];
   if(CopyBuffer(handle,0,shift,1,buf)!=1)
      return EMPTY_VALUE;
   return buf[0];
}

// ===== INIT =====
int OnInit()
{
   hEMA20_M5    = iMA(_Symbol,PERIOD_M5, EMA_pullback,0,MODE_EMA,PRICE_CLOSE);
   hEMAfast_M15 = iMA(_Symbol,PERIOD_M15,EMA_fast,0,MODE_EMA,PRICE_CLOSE);
   hEMAslow_M15 = iMA(_Symbol,PERIOD_M15,EMA_slow,0,MODE_EMA,PRICE_CLOSE);
   hEMAfast_H1  = iMA(_Symbol,PERIOD_H1, EMA_fast,0,MODE_EMA,PRICE_CLOSE);
   hEMAslow_H1  = iMA(_Symbol,PERIOD_H1, EMA_slow,0,MODE_EMA,PRICE_CLOSE);

   if(hEMA20_M5<0) return INIT_FAILED;

   g_file = FileOpen(InpFileName,
                     FILE_WRITE|FILE_CSV|FILE_ANSI|FILE_COMMON);

   if(g_file==INVALID_HANDLE)
      return INIT_FAILED;

   FileWrite(g_file,
      "time","side","spread_pts",
      "r1","r2","r3","r4","r5",
      "r6","r7","r8","r9","r10");

   return INIT_SUCCEEDED;
}

// ===== DEINIT =====
void OnDeinit(const int reason)
{
   if(g_file!=INVALID_HANDLE)
      FileClose(g_file);

   IndicatorRelease(hEMA20_M5);
   IndicatorRelease(hEMAfast_M15);
   IndicatorRelease(hEMAslow_M15);
   IndicatorRelease(hEMAfast_H1);
   IndicatorRelease(hEMAslow_H1);
}

// ===== MAIN =====
void OnTick()
{
   if(!IsNewBar()) return;

   // --- Trend
   double m15fast = GetValue(hEMAfast_M15,1);
   double m15slow = GetValue(hEMAslow_M15,1);
   double h1fast  = GetValue(hEMAfast_H1,1);
   double h1slow  = GetValue(hEMAslow_H1,1);

   bool bull = (m15fast>m15slow && h1fast>h1slow);
   bool bear = (m15fast<m15slow && h1fast<h1slow);

   if(!bull && !bear) return;

   // --- Pullback logic (EA1 correct version)
   double ema2   = GetValue(hEMA20_M5,2);
   double close2 = iClose(_Symbol,PERIOD_M5,2);
   double high1  = iHigh(_Symbol,PERIOD_M5,1);
   double low1   = iLow(_Symbol,PERIOD_M5,1);
   double open1  = iOpen(_Symbol,PERIOD_M5,1);
   double close1 = iClose(_Symbol,PERIOD_M5,1);

   double bodyPts = MathAbs(close1-open1)/_Point;
   if(bodyPts < MinBodyPts) return;

   bool buy  = bull && (close2<ema2) && (high1>iHigh(_Symbol,PERIOD_M5,2));
   bool sell = bear && (close2>ema2) && (low1<iLow(_Symbol,PERIOD_M5,2));

   if(!buy && !sell) return;

   string side = buy?"BUY":"SELL";

   // --- Spread
   int spread = (int)SymbolInfoInteger(_Symbol,SYMBOL_SPREAD);

   // --- Returns
   double r[10];
   for(int k=1;k<=InpLookback;k++)
   {
      double c  = iClose(_Symbol,PERIOD_M5,k);
      double cp = iClose(_Symbol,PERIOD_M5,k+1);
      r[k-1] = (c-cp)/_Point;
   }

   datetime tm = iTime(_Symbol,PERIOD_M5,1);

   FileWrite(g_file,
      TimeToString(tm,TIME_DATE|TIME_MINUTES),
      side,
      spread,
      r[0],r[1],r[2],r[3],r[4],
      r[5],r[6],r[7],r[8],r[9]);

   FileFlush(g_file);
}