#property strict

input string InpFileName = "xau_m5_candidates_ea2.csv";
input int    InpLookbackCandles = 10;

datetime g_lastM5 = 0;
int g_fh;

bool IsNewBar()
{
   datetime t=iTime(_Symbol,PERIOD_M5,0);
   if(t!=g_lastM5){ g_lastM5=t; return true; }
   return false;
}

int OnInit()
{
   g_fh=FileOpen(InpFileName,
                 FILE_READ|FILE_WRITE|FILE_CSV|FILE_ANSI|FILE_COMMON);

   if(FileSize(g_fh)==0)
      FileWrite(g_fh,"time","side","spread_pts",
                "r1","r2","r3","r4","r5","r6","r7","r8","r9","r10");

   FileSeek(g_fh,0,SEEK_END);
   g_lastM5=iTime(_Symbol,PERIOD_M5,0);
   return INIT_SUCCEEDED;
}

void OnTick()
{
   if(!IsNewBar()) return;

   double c1=iClose(_Symbol,PERIOD_M5,1);
   double c2=iClose(_Symbol,PERIOD_M5,2);

   string side="";
   if(c1>c2) side="BUY";
   if(c1<c2) side="SELL";
   if(side=="") return;

   int spread=(int)SymbolInfoInteger(_Symbol,SYMBOL_SPREAD);

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
      r[0],r[1],r[2],r[3],r[4],
      r[5],r[6],r[7],r[8],r[9]);

   FileFlush(g_fh);
}