#property strict
#include <Trade/Trade.mqh>

CTrade trade;

// ===== Inputs =====
input long   MagicNumber      = 20260222;
input double FixedLot         = 0.01;

input int    SL_PTS           = 1200;
input int    TP_PTS           = 1500;
input int    MAX_MINUTES      = 60;

input int    SL_TO_STOP       = 2;
input string STOP_MODE        = "session"; // "session" or "day"

input bool   DebugMode        = true;

// ===== State =====
datetime g_lastM5 = 0;

int      g_slCount   = 0;
string   g_blockKey  = "";
bool     g_blocked   = false;

ulong    g_lastSLDealTicket = 0;   // prevent double SL count

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

// ===== SIGNAL (REPLACE WITH YOUR REAL LOGIC) =====

string GetSignal()
{
   double close1 = iClose(_Symbol, PERIOD_M5, 1);
   double close2 = iClose(_Symbol, PERIOD_M5, 2);
   double open1  = iOpen(_Symbol, PERIOD_M5, 1);

   double buf[];
   if(CopyBuffer(hEma200,0,1,1,buf)!=1)
      return "";

   double ema200 = buf[0];

   double body = MathAbs(close1 - open1);
   if(body < 300 * _Point)
      return "";

   if(close1 > ema200 && close1 > close2)
      return "BUY";

   if(close1 < ema200 && close1 < close2)
      return "SELL";

   return "";
}

// ===== SAFE SL COUNTER =====

void UpdateSLCounter()
{
   HistorySelect(0, TimeCurrent());
   int total = HistoryDealsTotal();

   for(int i = total-1; i >= 0; i--)
   {
      ulong deal = HistoryDealGetTicket(i);

      if(deal == g_lastSLDealTicket)
         break;  // already processed

      if(HistoryDealGetInteger(deal, DEAL_MAGIC) != MagicNumber)
         continue;

      if(HistoryDealGetInteger(deal, DEAL_REASON) == DEAL_REASON_SL)
      {
         g_slCount++;
         g_lastSLDealTicket = deal;

         if(DebugMode)
            Print("SL detected. Count = ", g_slCount);

         if(g_slCount >= SL_TO_STOP)
         {
            g_blocked = true;

            if(DebugMode)
               Print("Trading BLOCKED for ", g_blockKey);
         }

         break;
      }
   }
}

// ===== POSITION MANAGEMENT =====

void ManagePositions()
{
   datetime now = TimeCurrent();

   for(int i = PositionsTotal()-1; i >= 0; i--)
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
         Print("Trading blocked due to SL limit.");
      return;
   }
   
    // ===== Only 1 position at a time =====
   for(int i=0;i<PositionsTotal();i++)
   {
      if(PositionGetTicket(i) > 0 &&
         PositionGetInteger(POSITION_MAGIC) == MagicNumber)
         return;
   }

   string side = GetSignal();
   if(side == "") return;

   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);

   double sl, tp;

   trade.SetExpertMagicNumber(MagicNumber);

   if(side == "BUY")
   {
      sl = ask - SL_PTS * _Point;
      tp = ask + TP_PTS * _Point;

      if(trade.Buy(FixedLot, _Symbol, 0, sl, tp))
         if(DebugMode)
            Print("BUY opened at ", ask);
   }
   else
   {
      sl = bid + SL_PTS * _Point;
      tp = bid - TP_PTS * _Point;

      if(trade.Sell(FixedLot, _Symbol, 0, sl, tp))
         if(DebugMode)
            Print("SELL opened at ", bid);
   }
}

// ===== MT5 EVENTS =====

int OnInit()
{
   hEma200 = iMA(_Symbol, PERIOD_M5, 200, 0, MODE_EMA, PRICE_CLOSE);
   trade.SetExpertMagicNumber(MagicNumber);
   g_lastM5 = iTime(_Symbol, PERIOD_M5, 0);
   g_blockKey = GetBlockKey();
   return INIT_SUCCEEDED;
}

void OnTick()
{
   ManagePositions();

   // Reset on new session/day
   string key = GetBlockKey();
   if(key != g_blockKey)
   {
      g_blockKey = key;
      g_slCount = 0;
      g_blocked = false;

      if(DebugMode)
         Print("New session/day. Reset SL counter.");
   }

   UpdateSLCounter();

   if(IsNewBar(PERIOD_M5, g_lastM5))
      TryOpenTrade();
}