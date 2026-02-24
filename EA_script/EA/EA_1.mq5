//---If performance drops:

//---Lower MinBodyPts to 15–20.
//---If too many trades: raise to 40–50.

#property strict
#include <Trade/Trade.mqh>

CTrade trade;

// ===== Inputs =====
input long   MagicNumber      = 20260222;
input double RiskPct          = 0.01;
input int    MaxPositions     = 10;

input int    SL_PTS           = 1200;
input int    TP_PTS           = 1500;
input int    MAX_MINUTES      = 60;
input int    EARLY_MINUTES    = 60;

input int    EMA_fast         = 50;
input int    EMA_slow         = 200;
input int    EMA_pullback     = 20;

input int    MaxSpreadPoints  = 60;
input double MinBodyPts       = 30;   // momentum filter

input bool   DebugMode        = true;

// ===== State =====
datetime g_lastM5 = 0;

int hEmaM5  = INVALID_HANDLE;
int hEmaM15_fast=INVALID_HANDLE, hEmaM15_slow=INVALID_HANDLE;
int hEmaH1_fast=INVALID_HANDLE,  hEmaH1_slow=INVALID_HANDLE;

enum Trend { TR_NEUTRAL=0, TR_BULL=1, TR_BEAR=-1 };

bool IsNewBar(ENUM_TIMEFRAMES tf, datetime &last)
{
   datetime t = (datetime)iTime(_Symbol, tf, 0);
   if(t != last) { last=t; return true; }
   return false;
}

double BufValue(int handle, int shift)
{
   double b[];
   if(CopyBuffer(handle, 0, shift, 1, b) != 1) return EMPTY_VALUE;
   return b[0];
}

Trend TrendByEMAs(int hFast, int hSlow)
{
   double fast = BufValue(hFast, 1);
   double slow = BufValue(hSlow, 1);
   if(fast==EMPTY_VALUE || slow==EMPTY_VALUE) return TR_NEUTRAL;
   if(fast > slow) return TR_BULL;
   if(fast < slow) return TR_BEAR;
   return TR_NEUTRAL;
}

bool SpreadOK()
{
   int spread = (int)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   return (spread > 0 && spread <= MaxSpreadPoints);
}

int CountMyPositions()
{
   int cnt = 0;
   for(int i = PositionsTotal()-1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket)) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if((long)PositionGetInteger(POSITION_MAGIC) != MagicNumber) continue;
      cnt++;
   }
   return cnt;
}

double CalcLotByRisk(int sl_points)
{
   if(sl_points <= 0) return 0.0;

   double balance  = AccountInfoDouble(ACCOUNT_BALANCE);
   double riskCash = balance * (RiskPct/100.0);

   double tickSize  = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   if(tickSize<=0 || tickValue<=0) return 0.0;

   double lossPerLot = (sl_points*_Point/tickSize) * tickValue;
   if(lossPerLot<=0) return 0.0;

   double lot = riskCash / lossPerLot;

   double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double step   = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);

   lot = MathMax(minLot, MathMin(maxLot, lot));
   lot = MathFloor(lot/step)*step;

   return lot;
}

void TryOpenTrade()
{
   if(DebugMode) Print("----- NEW M5 BAR -----");

   int spread = (int)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   if(DebugMode) Print("Spread=", spread);

   if(!SpreadOK()) 
   {
      if(DebugMode) Print("Spread NOT OK");
      return;
   }

   int posCount = CountMyPositions();
   if(DebugMode) Print("My positions=", posCount);

   if(posCount >= MaxPositions)
   {
      if(DebugMode) Print("MaxPositions reached");
      return;
   }

   Trend t15 = TrendByEMAs(hEmaM15_fast, hEmaM15_slow);
   Trend tH1 = TrendByEMAs(hEmaH1_fast,  hEmaH1_slow);

   if(DebugMode) Print("Trend M15=", t15, " Trend H1=", tH1);

   if(t15==TR_NEUTRAL || t15!=tH1)
   {
      if(DebugMode) Print("Trend alignment FAILED");
      return;
   }

   double ema_prev = BufValue(hEmaM5, 2);
   if(ema_prev==EMPTY_VALUE) return;

   double prev_low   = iLow(_Symbol, PERIOD_M5, 2);
   double prev_high  = iHigh(_Symbol, PERIOD_M5, 2);
   double cur_high   = iHigh(_Symbol, PERIOD_M5, 1);
   double cur_low    = iLow(_Symbol, PERIOD_M5, 1);
   double cur_open   = iOpen(_Symbol, PERIOD_M5, 1);
   double cur_close  = iClose(_Symbol, PERIOD_M5, 1);

   double bodyPts = MathAbs(cur_close - cur_open) / _Point;

   if(DebugMode)
   {
      Print("BodyPts=", bodyPts);
      Print("PrevLow=", prev_low, " PrevHigh=", prev_high);
      Print("CurLow=", cur_low, " CurHigh=", cur_high);
   }

   bool buySignal =
      (t15==TR_BULL) &&
      (prev_low <= ema_prev) &&
      (cur_high > prev_high) &&
      (bodyPts >= MinBodyPts);

   bool sellSignal =
      (t15==TR_BEAR) &&
      (prev_high >= ema_prev) &&
      (cur_low < prev_low) &&
      (bodyPts >= MinBodyPts);

   if(DebugMode) Print("Buy=", buySignal, " Sell=", sellSignal);

   if(!buySignal && !sellSignal) return;

   double lot = CalcLotByRisk(SL_PTS);
   if(DebugMode) Print("Lot=", lot);
   if(lot <= 0) return;

   trade.SetExpertMagicNumber(MagicNumber);
   trade.SetDeviationInPoints(20);

   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);

   if(buySignal)
   {
      double sl = ask - SL_PTS*_Point;
      double tp = ask + TP_PTS*_Point;

      if(trade.Buy(lot, _Symbol, 0, sl, tp))
         if(DebugMode) Print("BUY opened");
      else
         Print("BUY failed err=", GetLastError());
   }
   else
   {
      double sl = bid + SL_PTS*_Point;
      double tp = bid - TP_PTS*_Point;

      if(trade.Sell(lot, _Symbol, 0, sl, tp))
         if(DebugMode) Print("SELL opened");
      else
         Print("SELL failed err=", GetLastError());
   }
}

void ManagePositions()
{
   datetime now = TimeCurrent();

   for(int i=PositionsTotal()-1; i>=0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket)) continue;
      if(PositionGetString(POSITION_SYMBOL)!=_Symbol) continue;
      if((long)PositionGetInteger(POSITION_MAGIC)!=MagicNumber) continue;

      datetime openTime = (datetime)PositionGetInteger(POSITION_TIME);
      double profit = PositionGetDouble(POSITION_PROFIT);
      int minutesOpen = (int)((now-openTime)/60);

      if(EARLY_MINUTES>0 && minutesOpen>=EARLY_MINUTES && profit>0)
         trade.PositionClose(ticket);

      if(MAX_MINUTES>0 && minutesOpen>=MAX_MINUTES)
         trade.PositionClose(ticket);
   }
}

// ===== MT5 events =====
int OnInit()
{
   hEmaM5  = iMA(_Symbol, PERIOD_M5,  EMA_pullback, 0, MODE_EMA, PRICE_CLOSE);
   hEmaM15_fast = iMA(_Symbol, PERIOD_M15, EMA_fast, 0, MODE_EMA, PRICE_CLOSE);
   hEmaM15_slow = iMA(_Symbol, PERIOD_M15, EMA_slow, 0, MODE_EMA, PRICE_CLOSE);
   hEmaH1_fast  = iMA(_Symbol, PERIOD_H1,  EMA_fast, 0, MODE_EMA, PRICE_CLOSE);
   hEmaH1_slow  = iMA(_Symbol, PERIOD_H1,  EMA_slow, 0, MODE_EMA, PRICE_CLOSE);

   if(hEmaM5==INVALID_HANDLE || hEmaM15_fast==INVALID_HANDLE ||
      hEmaM15_slow==INVALID_HANDLE || hEmaH1_fast==INVALID_HANDLE ||
      hEmaH1_slow==INVALID_HANDLE)
      return INIT_FAILED;

   g_lastM5 = iTime(_Symbol, PERIOD_M5, 0);
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
   if(IsNewBar(PERIOD_M5, g_lastM5))
      TryOpenTrade();
}