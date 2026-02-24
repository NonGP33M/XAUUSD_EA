#property strict

input string InpFileName = "m5_candidates_ea0.csv";
input int    InpLookbackCandles = 10;

input int EMA_fast     = 50;
input int EMA_slow     = 200;
input int EMA_pullback = 20;

datetime g_lastM5 = 0;

int hEmaM5;
int hEmaM15_fast, hEmaM15_slow;
int hEmaH1_fast,  hEmaH1_slow;

int g_fh;

enum Trend { TR_NEUTRAL=0, TR_BULL=1, TR_BEAR=-1 };

bool IsNewBar(ENUM_TIMEFRAMES tf, datetime &last)
{
   datetime t=iTime(_Symbol,tf,0);
   if(t!=last){ last=t; return true; }
   return false;
}

double BufValue(int handle,int shift)
{
   double b[];
   if(CopyBuffer(handle,0,shift,1,b)!=1) return EMPTY_VALUE;
   return b[0];
}

Trend TrendByEMAs(int hFast,int hSlow)
{
   double fast=BufValue(hFast,1);
   double slow=BufValue(hSlow,1);
   if(fast==EMPTY_VALUE || slow==EMPTY_VALUE) return TR_NEUTRAL;
   if(fast>slow) return TR_BULL;
   if(fast<slow) return TR_BEAR;
   return TR_NEUTRAL;
}

int OnInit()
{
   hEmaM5=iMA(_Symbol,PERIOD_M5,EMA_pullback,0,MODE_EMA,PRICE_CLOSE);

   hEmaM15_fast=iMA(_Symbol,PERIOD_M15,EMA_fast,0,MODE_EMA,PRICE_CLOSE);
   hEmaM15_slow=iMA(_Symbol,PERIOD_M15,EMA_slow,0,MODE_EMA,PRICE_CLOSE);

   hEmaH1_fast=iMA(_Symbol,PERIOD_H1,EMA_fast,0,MODE_EMA,PRICE_CLOSE);
   hEmaH1_slow=iMA(_Symbol,PERIOD_H1,EMA_slow,0,MODE_EMA,PRICE_CLOSE);

   g_fh=FileOpen(InpFileName,
                 FILE_READ|FILE_WRITE|FILE_CSV|FILE_ANSI|FILE_COMMON);

   if(FileSize(g_fh)==0)
   {
      FileWrite(g_fh,
      "time","side","spread_pts",
      "ema1","ema2","c1","c2",
      "r1","r2","r3","r4","r5",
      "r6","r7","r8","r9","r10");
   }

   FileSeek(g_fh,0,SEEK_END);
   g_lastM5=iTime(_Symbol,PERIOD_M5,0);

   return INIT_SUCCEEDED;
}

void OnTick()
{
   if(!IsNewBar(PERIOD_M5,g_lastM5)) return;

   Trend t15=TrendByEMAs(hEmaM15_fast,hEmaM15_slow);
   Trend tH1=TrendByEMAs(hEmaH1_fast,hEmaH1_slow);

   if(t15==TR_NEUTRAL || t15!=tH1) return;

   double ema1=BufValue(hEmaM5,1);
   double ema2=BufValue(hEmaM5,2);

   if(ema1==EMPTY_VALUE || ema2==EMPTY_VALUE) return;

   double c1=iClose(_Symbol,PERIOD_M5,1);
   double c2=iClose(_Symbol,PERIOD_M5,2);

   bool buy  = (t15==TR_BULL) && (c2<ema2) && (c1>ema1);
   bool sell = (t15==TR_BEAR) && (c2>ema2) && (c1<ema1);

   if(!buy && !sell) return;

   string side = buy?"BUY":"SELL";

   int spread = (int)SymbolInfoInteger(_Symbol,SYMBOL_SPREAD);

   double r[10];
   for(int k=1;k<=InpLookbackCandles;k++)
   {
      double c=iClose(_Symbol,PERIOD_M5,k);
      double cp=iClose(_Symbol,PERIOD_M5,k+1);
      r[k-1]=(c-cp)/_Point;
   }

   datetime tm=iTime(_Symbol,PERIOD_M5,1);

   FileWrite(g_fh,
      TimeToString(tm,TIME_DATE|TIME_MINUTES),
      side,
      spread,
      ema1, ema2, c1, c2,
      r[0],r[1],r[2],r[3],r[4],
      r[5],r[6],r[7],r[8],r[9]);

   FileFlush(g_fh);
}

void OnDeinit(const int reason)
{
   if(g_fh!=INVALID_HANDLE) FileClose(g_fh);

   IndicatorRelease(hEmaM5);
   IndicatorRelease(hEmaM15_fast);
   IndicatorRelease(hEmaM15_slow);
   IndicatorRelease(hEmaH1_fast);
   IndicatorRelease(hEmaH1_slow);
}