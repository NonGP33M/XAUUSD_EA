#property strict
#include <Trade/Trade.mqh>

CTrade trade;

// ===== Inputs =====
input long   MagicNumber      = 20260218;
input double RiskPct          = 0.01;
input int    MaxPositions     = 10;

input int    SL_PTS           = 1500;
input int    TP_PTS           = 1500;
input int    MAX_MINUTES      = 60;
input int    EARLY_MINUTES    = 15;

input int    EMA_fast         = 50;
input int    EMA_slow         = 200;
input int    EMA_pullback     = 20;

input int    MaxSpreadPoints  = 60;

input bool   DebugMode        = true;

// ===== State =====
datetime g_lastM5 = 0;

// indicator handles
int hEmaM5  = INVALID_HANDLE;
int hEmaM15_fast=INVALID_HANDLE, hEmaM15_slow=INVALID_HANDLE;
int hEmaH1_fast=INVALID_HANDLE,  hEmaH1_slow=INVALID_HANDLE;

enum Trend { TR_NEUTRAL=0, TR_BULL=1, TR_BEAR=-1 };

// ===== Helpers =====
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
  for(int i = PositionsTotal() - 1; i >= 0; i--)
  {
    ulong ticket = (ulong)PositionGetTicket(i);
    if(ticket == 0) continue;
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
  if(tickSize <= 0 || tickValue <= 0) return 0.0;

  double sl_price_dist = sl_points * _Point;
  double ticks = sl_price_dist / tickSize;
  double lossPerLot = ticks * tickValue;
  if(lossPerLot <= 0) return 0.0;

  double lot = riskCash / lossPerLot;

  double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
  double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
  double step   = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);

  lot = MathMax(minLot, MathMin(maxLot, lot));
  lot = MathFloor(lot/step)*step;
  return lot;
}

// ===== Trading =====
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

  if(DebugMode)
    Print("Trend M15=", t15, "  Trend H1=", tH1);

  if(t15==TR_NEUTRAL || t15!=tH1)
  {
    if(DebugMode) Print("Trend alignment FAILED");
    return;
  }

  double ema1 = BufValue(hEmaM5, 1);
  double ema2 = BufValue(hEmaM5, 2);
  double c1 = iClose(_Symbol, PERIOD_M5, 1);
  double c2 = iClose(_Symbol, PERIOD_M5, 2);

  if(DebugMode)
  {
    Print("M5 c2=", c2, " ema2=", ema2);
    Print("M5 c1=", c1, " ema1=", ema1);
  }

  bool buySignal  = (t15==TR_BULL) && (c2 < ema2) && (c1 > ema1);
  bool sellSignal = (t15==TR_BEAR) && (c2 > ema2) && (c1 < ema1);

  if(DebugMode)
    Print("BuySignal=", buySignal, "  SellSignal=", sellSignal);

  if(!buySignal && !sellSignal)
  {
    if(DebugMode) Print("No entry condition met");
    return;
  }

  double lot = CalcLotByRisk(SL_PTS);
  if(DebugMode) Print("Calculated lot=", lot);

  if(lot <= 0)
  {
    Print("Lot calc failed.");
    return;
  }

  trade.SetExpertMagicNumber(MagicNumber);
  trade.SetDeviationInPoints(20);

  double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
  double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);

  if(buySignal)
  {
    double sl = ask - SL_PTS * _Point;
    double tp = ask + TP_PTS * _Point;

    if(trade.Buy(lot, _Symbol, 0.0, sl, tp, "M5 BUY"))
      Print(">>> BUY OPENED lot=", lot);
    else
      Print("BUY FAILED err=", GetLastError());
  }
  else
  {
    double sl = bid + SL_PTS * _Point;
    double tp = bid - TP_PTS * _Point;

    if(trade.Sell(lot, _Symbol, 0.0, sl, tp, "M5 SELL"))
      Print(">>> SELL OPENED lot=", lot);
    else
      Print("SELL FAILED err=", GetLastError());
  }
}

void ManagePositions()
{
  datetime now = TimeCurrent();

  for(int i = PositionsTotal() - 1; i >= 0; i--)
  {
    ulong ticket = (ulong)PositionGetTicket(i);
    if(ticket == 0) continue;
    if(!PositionSelectByTicket(ticket)) continue;

    if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
    if((long)PositionGetInteger(POSITION_MAGIC) != MagicNumber) continue;

    datetime openTime = (datetime)PositionGetInteger(POSITION_TIME);
    double profit = PositionGetDouble(POSITION_PROFIT);
    int minutesOpen = (int)((now - openTime) / 60);

    if(EARLY_MINUTES > 0 && minutesOpen >= EARLY_MINUTES && profit > 0.0)
    {
      if(trade.PositionClose(ticket))
        Print("Closed EARLY_PROFIT ticket=", ticket, " mins=", minutesOpen, " profit=", profit);
      continue;
    }

    if(MAX_MINUTES > 0 && minutesOpen >= MAX_MINUTES)
    {
      if(trade.PositionClose(ticket))
        Print("Closed TIME_EXIT ticket=", ticket, " mins=", minutesOpen, " profit=", profit);
      continue;
    }
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

  if(hEmaM5==INVALID_HANDLE || hEmaM15_fast==INVALID_HANDLE || hEmaM15_slow==INVALID_HANDLE ||
     hEmaH1_fast==INVALID_HANDLE || hEmaH1_slow==INVALID_HANDLE)
  {
    Print("Failed to create indicator handles.");
    return INIT_FAILED;
  }

  g_lastM5 = (datetime)iTime(_Symbol, PERIOD_M5, 0);
  Print("EA init OK (NO ML). Symbol=", _Symbol, " Magic=", MagicNumber);
  return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
  if(hEmaM5!=INVALID_HANDLE) IndicatorRelease(hEmaM5);
  if(hEmaM15_fast!=INVALID_HANDLE) IndicatorRelease(hEmaM15_fast);
  if(hEmaM15_slow!=INVALID_HANDLE) IndicatorRelease(hEmaM15_slow);
  if(hEmaH1_fast!=INVALID_HANDLE) IndicatorRelease(hEmaH1_fast);
  if(hEmaH1_slow!=INVALID_HANDLE) IndicatorRelease(hEmaH1_slow);
}

void OnTick()
{
  ManagePositions();
  if(IsNewBar(PERIOD_M5, g_lastM5))
    TryOpenTrade();
}