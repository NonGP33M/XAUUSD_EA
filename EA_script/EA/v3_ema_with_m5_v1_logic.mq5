#property strict
#include <Trade/Trade.mqh>

CTrade trade;

// ===== Inputs =====
input long   MagicNumber      = 20260222;
input double FixedLot         = 0.01;
input int    MaxPositions     = 10;

input int    SL_PTS           = 1200;
input int    TP_PTS           = 1800;
input int    MAX_MINUTES      = 60;

input int    EMA_fast         = 50;
input int    EMA_slow         = 200;
input int    EMA_pullback     = 20;
input int    ATR_period       = 14;

input int    MaxSpreadPoints  = 60;
input double MinBodyPts       = 30;

input int    SessionSL_Limit  = 2;   // stop trading after N SL hits per day

input bool   DebugMode        = true;

// ===== State =====
datetime g_lastM5 = 0;
int g_today  = -1;
int g_session = -1;
int g_sessionSL = 0;

int hEmaM5  = INVALID_HANDLE;
int hEmaM15_fast=INVALID_HANDLE, hEmaM15_slow=INVALID_HANDLE;
int hEmaH1_fast=INVALID_HANDLE,  hEmaH1_slow=INVALID_HANDLE;

enum Trend { TR_NEUTRAL=0, TR_BULL=1, TR_BEAR=-1 };

// ===================== UTILS =====================

bool IsNewBar(ENUM_TIMEFRAMES tf, datetime &last)
{
   datetime t=iTime(_Symbol,tf,0);
   if(t!=last)
   {
      last=t;
      return true;
   }
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

bool SpreadOK()
{
   int spread=(int)SymbolInfoInteger(_Symbol,SYMBOL_SPREAD);
   return (spread>0 && spread<=MaxSpreadPoints);
}

int CountMyPositions()
{
   int cnt=0;
   for(int i=PositionsTotal()-1;i>=0;i--)
   {
      ulong ticket=PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket)) continue;
      if(PositionGetString(POSITION_SYMBOL)!=_Symbol) continue;
      if((long)PositionGetInteger(POSITION_MAGIC)!=MagicNumber) continue;
      cnt++;
   }
   return cnt;
}

int GetSession()
{
   MqlDateTime tm;
   TimeToStruct(TimeCurrent(), tm);

   if(tm.hour < 8)      return 0;   // Asia
   else if(tm.hour <16) return 1;   // Europe
   else                 return 2;   // America
}

void ResetSessionIfNeeded()
{
   MqlDateTime tm;
   TimeToStruct(TimeCurrent(), tm);

   int today = tm.day;
   int session = GetSession();

   if(today != g_today || session != g_session)
   {
      g_today = today;
      g_session = session;
      g_sessionSL = 0;

      if(DebugMode)
         Print("New session detected. Reset SL counter.");
   }
}

// ===================== ENTRY =====================

void TryOpenTrade()
{
   if(DebugMode) Print("----- NEW M5 BAR -----");

   ResetSessionIfNeeded();

   if(g_sessionSL>=SessionSL_Limit)
   {
      if(DebugMode) Print("Session SL limit reached. No more trading.");
      return;
   }

   if(!SpreadOK())
   {
      if(DebugMode) Print("Spread NOT OK");
      return;
   }

   if(CountMyPositions()>=MaxPositions)
   {
      if(DebugMode) Print("MaxPositions reached");
      return;
   }

   Trend t15=TrendByEMAs(hEmaM15_fast,hEmaM15_slow);
   Trend tH1=TrendByEMAs(hEmaH1_fast,hEmaH1_slow);

   if(t15!=tH1 || t15==TR_NEUTRAL)
   {
      if(DebugMode) Print("Trend alignment failed");
      return;
   }

   // use CLOSED candle only
   double ema2=BufValue(hEmaM5,2);
   if(ema2==EMPTY_VALUE) return;

   double open2 = iOpen(_Symbol,PERIOD_M5,2);
   double close2= iClose(_Symbol,PERIOD_M5,2);
   double high1 = iHigh(_Symbol,PERIOD_M5,1);
   double low1  = iLow(_Symbol,PERIOD_M5,1);

   double bodyPts=MathAbs(close2-open2)/_Point;
   if(bodyPts<MinBodyPts)
   {
      if(DebugMode) Print("Body filter failed");
      return;
   }

   bool buy  = (t15==TR_BULL) && (close2<ema2) && (high1>ema2);
   bool sell = (t15==TR_BEAR) && (close2>ema2) && (low1<ema2);

   if(!buy && !sell) return;

   double lot=FixedLot;

   double minLot=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN);
   double maxLot=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MAX);
   double step=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_STEP);

   lot=MathMax(minLot,MathMin(maxLot,lot));
   lot=NormalizeDouble(MathFloor(lot/step)*step,2);

   trade.SetExpertMagicNumber(MagicNumber);
   trade.SetDeviationInPoints(20);

   double ask=SymbolInfoDouble(_Symbol,SYMBOL_ASK);
   double bid=SymbolInfoDouble(_Symbol,SYMBOL_BID);

   if(buy)
   {
      double sl=ask-SL_PTS*_Point;
      double tp=ask+TP_PTS*_Point;

      if(trade.Buy(lot,_Symbol,ask,sl,tp))
         if(DebugMode) Print("BUY opened");
   }
   else if(sell)
   {
      double sl=bid+SL_PTS*_Point;
      double tp=bid-TP_PTS*_Point;

      if(trade.Sell(lot,_Symbol,bid,sl,tp))
         if(DebugMode) Print("SELL opened");
   }
}

// ===================== MANAGEMENT =====================

void ManagePositions()
{
   datetime now=TimeCurrent();

   for(int i=PositionsTotal()-1;i>=0;i--)
   {
      ulong ticket=PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket)) continue;
      if(PositionGetString(POSITION_SYMBOL)!=_Symbol) continue;
      if((long)PositionGetInteger(POSITION_MAGIC)!=MagicNumber) continue;

      datetime openTime=(datetime)PositionGetInteger(POSITION_TIME);
      int minutesOpen=(int)((now-openTime)/60);

      if(MAX_MINUTES>0 && minutesOpen>=MAX_MINUTES)
      {
         if(DebugMode) Print("Time exit triggered");
         trade.PositionClose(ticket);
      }
   }
}

// ===== Detect SL hits =====
void OnTradeTransaction(const MqlTradeTransaction &trans,
                        const MqlTradeRequest &request,
                        const MqlTradeResult &result)
{
   if(trans.type==TRADE_TRANSACTION_DEAL_ADD)
   {
      ulong deal=trans.deal;
      if(HistoryDealSelect(deal))
      {
         if((long)HistoryDealGetInteger(deal,DEAL_MAGIC)!=MagicNumber) return;

         if(HistoryDealGetInteger(deal,DEAL_ENTRY)==DEAL_ENTRY_OUT)
         {
            double profit=HistoryDealGetDouble(deal,DEAL_PROFIT);

            if(profit<0)
            {
               g_sessionSL++;
               if(DebugMode)
                  Print("SL detected. Session SL count=",g_sessionSL);
            }
         }
      }
   }
}

// ===================== EVENTS =====================

int OnInit()
{
   hEmaM5=iMA(_Symbol,PERIOD_M5,EMA_pullback,0,MODE_EMA,PRICE_CLOSE);

   hEmaM15_fast=iMA(_Symbol,PERIOD_M15,EMA_fast,0,MODE_EMA,PRICE_CLOSE);
   hEmaM15_slow=iMA(_Symbol,PERIOD_M15,EMA_slow,0,MODE_EMA,PRICE_CLOSE);

   hEmaH1_fast=iMA(_Symbol,PERIOD_H1,EMA_fast,0,MODE_EMA,PRICE_CLOSE);
   hEmaH1_slow=iMA(_Symbol,PERIOD_H1,EMA_slow,0,MODE_EMA,PRICE_CLOSE);

   if(hEmaM5==INVALID_HANDLE ||
      hEmaM15_fast==INVALID_HANDLE ||
      hEmaM15_slow==INVALID_HANDLE ||
      hEmaH1_fast==INVALID_HANDLE ||
      hEmaH1_slow==INVALID_HANDLE)
      return INIT_FAILED;

   g_lastM5=iTime(_Symbol,PERIOD_M5,0);
   MqlDateTime tm;
   TimeToStruct(TimeCurrent(), tm);
   g_today = tm.day;

   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
   IndicatorRelease(hEmaM5);
   IndicatorRelease(hEmaM15_fast);
   IndicatorRelease(hEmaM15_slow);
   IndicatorRelease(hEmaH1_fast);
   IndicatorRelease(hEmaH1_slow);
}

void OnTick()
{
   ManagePositions();

   if(IsNewBar(PERIOD_M5,g_lastM5))
      TryOpenTrade();
}