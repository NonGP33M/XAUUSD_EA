#property strict

input string InpFileName = "xau_m5_candidates_ea4.csv";
input int    InpLookbackCandles = 10;

input int    EMA_period = 200;
input double MinBodyPts = 300;

datetime g_lastM5 = 0;
int hEmaM5 = INVALID_HANDLE;
int g_fh   = INVALID_HANDLE;

// =============================================

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

// =============================================

int OnInit()
{
   hEmaM5 = iMA(_Symbol,PERIOD_M5,EMA_period,0,MODE_EMA,PRICE_CLOSE);
   if(hEmaM5==INVALID_HANDLE)
      return INIT_FAILED;

   g_fh = FileOpen(InpFileName,
                   FILE_WRITE|FILE_READ|FILE_CSV|FILE_ANSI|FILE_COMMON);

   if(g_fh==INVALID_HANDLE)
      return INIT_FAILED;

   if(FileSize(g_fh)==0)
   {
      FileWrite(g_fh,
      "time","side","spread_pts",
      "r1","r2","r3","r4","r5",
      "r6","r7","r8","r9","r10");
   }

   FileSeek(g_fh,0,SEEK_END);

   g_lastM5 = iTime(_Symbol,PERIOD_M5,0);

   return INIT_SUCCEEDED;
}

// =============================================

void OnDeinit(const int reason)
{
   if(hEmaM5!=INVALID_HANDLE)
      IndicatorRelease(hEmaM5);

   if(g_fh!=INVALID_HANDLE)
      FileClose(g_fh);
}

// =============================================

void OnTick()
{
   if(!IsNewBar(PERIOD_M5,g_lastM5))
      return;

   if(Bars(_Symbol,PERIOD_M5) < InpLookbackCandles+5)
      return;

   double close1 = iClose(_Symbol,PERIOD_M5,1);
   double close2 = iClose(_Symbol,PERIOD_M5,2);
   double open1  = iOpen(_Symbol,PERIOD_M5,1);

   double ema1 = BufValue(hEmaM5,1);
   if(ema1==EMPTY_VALUE)
      return;

   double bodyPts = MathAbs(close1-open1)/_Point;
   if(bodyPts < MinBodyPts)
      return;

   string side="";

   if(close1>ema1 && close1>close2)
      side="BUY";
   else if(close1<ema1 && close1<close2)
      side="SELL";

   if(side=="")
      return;

   int spread = (int)((SymbolInfoDouble(_Symbol,SYMBOL_ASK)
                     -SymbolInfoDouble(_Symbol,SYMBOL_BID))/_Point);

   double r[10];
   for(int k=1;k<=InpLookbackCandles;k++)
   {
      double c  = iClose(_Symbol,PERIOD_M5,k);
      double cp = iClose(_Symbol,PERIOD_M5,k+1);
      r[k-1] = (c-cp)/_Point;
   }

   datetime tm=iTime(_Symbol,PERIOD_M5,1);

   FileWrite(g_fh,
      TimeToString(tm,TIME_DATE|TIME_MINUTES),
      side,
      spread,
      r[0],r[1],r[2],r[3],r[4],
      r[5],r[6],r[7],r[8],r[9]);

   FileFlush(g_fh);
}