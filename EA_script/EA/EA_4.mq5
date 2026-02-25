#property strict
#include <Trade/Trade.mqh>

CTrade trade;

// ===== Inputs =====
input long   MagicNumber      = 20260222;
input double FixedLot         = 0.01;

input int    SL_PTS           = 100;
input int    TP_PTS           = 1800;
input int    MAX_MINUTES      = 5;

input int    SL_TO_STOP       = 15;
input string STOP_MODE        = "session"; // "session" or "day"

input int    MinBodyPts       = 300;
input int    MaxPositions     = 2;

input bool   DebugMode        = true;

// ===== State =====
datetime g_lastM5             = 0;
int      g_slStreak           = 0;   // consecutive SLs (resets on any non-SL close)
string   g_blockKey           = "";
bool     g_blocked            = false;

ulong    g_lastDealTicket     = 0;   // last processed deal (SL or non-SL)

// =========================================
int hEma200;

bool IsNewBar(ENUM_TIMEFRAMES tf, datetime &last)
{
   datetime t = iTime(_Symbol, tf, 0);
   if(t != last)
   {
      last = t;
      return true;
   }
   return false;
}

// ===== SESSION LOGIC =====

string GetSession()
{
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);

   if(dt.hour < 8)  return "Asia";
   if(dt.hour < 16) return "Europe";
   return "America";
}

string GetBlockKey()
{
   string date = TimeToString(TimeCurrent(), TIME_DATE);

   if(STOP_MODE == "day")
      return date;

   return date + "_" + GetSession();
}

// ===== SIGNAL =====

string GetSignal()
{
   double close1 = iClose(_Symbol, PERIOD_M5, 1);
   double close2 = iClose(_Symbol, PERIOD_M5, 2);
   double open1  = iOpen(_Symbol, PERIOD_M5, 1);

   double buf[];
   if(CopyBuffer(hEma200, 0, 1, 1, buf) != 1)
      return "";

   double ema200 = buf[0];

   double body = MathAbs(close1 - open1);
   if(body < MinBodyPts * _Point)
      return "";

   if(close1 > ema200 && close1 > close2)
      return "BUY";

   if(close1 < ema200 && close1 < close2)
      return "SELL";

   return "";
}

// ===== STREAK-BASED SL COUNTER =====

void UpdateSLCounter()
{
   HistorySelect(TimeCurrent() - 7 * 24 * 3600, TimeCurrent());
   int total = HistoryDealsTotal();

   for(int i = total - 1; i >= 0; i--)
   {
      ulong deal = HistoryDealGetTicket(i);

      if(deal == g_lastDealTicket)
         break;  // already processed

      if(HistoryDealGetInteger(deal, DEAL_MAGIC) != MagicNumber)
         continue;

      // only care about closing deals (not entries)
      long dealEntry = HistoryDealGetInteger(deal, DEAL_ENTRY);
      if(dealEntry != DEAL_ENTRY_OUT)
         continue;

      long dealReason = HistoryDealGetInteger(deal, DEAL_REASON);

      if(dealReason == DEAL_REASON_SL)
      {
         g_slStreak++;

         if(DebugMode)
            Print("SL detected. Streak = ", g_slStreak);

         if(g_slStreak >= SL_TO_STOP)
         {
            g_blocked = true;

            if(DebugMode)
               Print("Trading BLOCKED for ", g_blockKey);
         }
      }
      else
      {
         // TP, time exit, manual — resets streak
         g_slStreak = 0;

         if(DebugMode)
            Print("Non-SL close. Streak reset.");
      }

      g_lastDealTicket = deal;
      break;
   }
}

// ===== COUNT OPEN POSITIONS =====

int CountPositions()
{
   int count = 0;
   for(int i = 0; i < PositionsTotal(); i++)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket > 0 && PositionSelectByTicket(ticket))
         if(PositionGetInteger(POSITION_MAGIC) == MagicNumber)
            count++;
   }
   return count;
}

// ===== POSITION MANAGEMENT =====

void ManagePositions()
{
   datetime now = TimeCurrent();

   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket)) continue;
      if(PositionGetInteger(POSITION_MAGIC) != MagicNumber) continue;

      datetime openTime = (datetime)PositionGetInteger(POSITION_TIME);
      int minutesOpen = (int)((now - openTime) / 60);

      if(MAX_MINUTES > 0 && minutesOpen >= MAX_MINUTES)
      {
         if(trade.PositionClose(ticket))
         {
            if(DebugMode)
               Print("Closed TIME exit");
         }
      }
   }
}

// ===== OPEN TRADE =====

void TryOpenTrade()
{
   if(g_blocked)
   {
      if(DebugMode)
         Print("Trading blocked due to SL streak.");
      return;
   }

   if(CountPositions() >= MaxPositions)
   {
      if(DebugMode)
         Print("Max positions reached: ", MaxPositions);
      return;
   }

   string side = GetSignal();
   if(side == "") return;

   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);

   double sl, tp;

   if(side == "BUY")
   {
      sl = ask - SL_PTS * _Point;
      tp = ask + TP_PTS * _Point;

      if(trade.Buy(FixedLot, _Symbol, 0, sl, tp))
         if(DebugMode)
            Print("BUY opened at ", ask, " | Streak = ", g_slStreak);
   }
   else
   {
      sl = bid + SL_PTS * _Point;
      tp = bid - TP_PTS * _Point;

      if(trade.Sell(FixedLot, _Symbol, 0, sl, tp))
         if(DebugMode)
            Print("SELL opened at ", bid, " | Streak = ", g_slStreak);
   }
}

// ===== MT5 EVENTS =====

int OnInit()
{
   hEma200 = iMA(_Symbol, PERIOD_M5, 200, 0, MODE_EMA, PRICE_CLOSE);
   trade.SetExpertMagicNumber(MagicNumber);
   g_lastM5   = iTime(_Symbol, PERIOD_M5, 0);
   g_blockKey = GetBlockKey();
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
   IndicatorRelease(hEma200);
}

void OnTick()
{
   ManagePositions();

   // Reset on new session/day
   string key = GetBlockKey();
   if(key != g_blockKey)
   {
      g_blockKey  = key;
      g_slStreak  = 0;
      g_blocked   = false;

      if(DebugMode)
         Print("New session/day. Reset SL streak.");
   }

   UpdateSLCounter();

   if(IsNewBar(PERIOD_M5, g_lastM5))
      TryOpenTrade();
}