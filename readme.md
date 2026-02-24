# 🤖 XAUUSD Expert Advisors (EA0 – EA4)

Collection of MT5 Expert Advisors for M5-based trading on XAUUSD.  
All EAs use `#property strict` and `CTrade` from `<Trade/Trade.mqh>`.

<p>&nbsp;</p>

# EA0 – MTF EMA Pullback (Risk-Based) 📐

## Concept

Multi-timeframe EMA trend-following with M5 pullback entry.

- Trend filter:
  - M15 EMA(50/200)
  - H1 EMA(50/200)
  - Must align (both bullish or bearish)
- Entry timeframe: M5
- Pullback trigger: EMA(20) cross
- Risk-based position sizing

## Entry Logic

### 🟢 BUY

- M15 trend = BULL
- H1 trend = BULL
- Previous M5 close below EMA20
- Current M5 close above EMA20

### 🔴 SELL

- M15 trend = BEAR
- H1 trend = BEAR
- Previous M5 close above EMA20
- Current M5 close below EMA20

## ⚙️ Risk & Management

- Lot size calculated from `RiskPct`
- SL / TP fixed in points
- Early profit close after `EARLY_MINUTES`
- Hard time exit after `MAX_MINUTES`
- Spread filter
- MaxPositions control

## Use Case

Baseline structured trend-pullback system with controlled risk.

<p>&nbsp;</p>

# EA1 – MTF Pullback + Momentum Break 💥

## Concept

EA0 upgraded with breakout + momentum confirmation.

Adds:

- Structure break (previous high/low)
- Candle body momentum filter (`MinBodyPts`)

## Entry Logic

### 🟢 BUY

- M15 & H1 trend aligned bullish
- Previous candle touches/pierces EMA20
- Current candle breaks previous high
- Body size ≥ `MinBodyPts`

### 🔴 SELL

- M15 & H1 trend aligned bearish
- Previous candle touches/pierces EMA20
- Current candle breaks previous low
- Body size ≥ `MinBodyPts`

## ⚙️ Risk & Management

- Risk-based lot sizing
- Early profit exit
- Time exit
- Spread filter
- MaxPositions control

## 🎛️ Tuning

- Lower `MinBodyPts` → more trades
- Raise `MinBodyPts` → fewer, stronger trades

## Use Case

Momentum-confirmed pullback entries. Cleaner than EA0.

<p>&nbsp;</p>

# EA2 – Simple Signal + SL Session Stop 🛡️

## Concept

Minimal signal logic + strict SL-based session/day shutdown.

Signal:

- If close(1) > close(2) → BUY
- If close(1) < close(2) → SELL

No trend filter.

## ⚙️ Risk & Management

- Fixed lot
- Fixed SL / TP
- Time exit (`MAX_MINUTES`)
- Stop trading after `SL_TO_STOP` losses
- Block per:
  - `"session"` (Asia/Europe/America)
  - `"day"`

## 🔑 Key Feature

Safe SL counter using deal history to avoid double counting.

## Use Case

Risk control experiment. Focused on capital protection.

<p>&nbsp;</p>

# EA3 – Structured MTF + Session SL Limit 🏗️

## Concept

Refined structured pullback with session-level loss control.

Features:

- M15 + H1 EMA alignment
- M5 EMA pullback
- Body momentum filter
- Fixed lot
- MaxPositions
- Session SL limiter (`SessionSL_Limit`)

## Entry Logic

Uses closed candle confirmation:

- Pullback into EMA
- Break continuation candle
- Body ≥ `MinBodyPts`

## ⚙️ Risk & Management

- Fixed SL / TP
- Time exit
- Stops trading after N losses per session
- SL detection via `OnTradeTransaction`

## Use Case

Controlled structured trading with built-in damage limiter.

<p>&nbsp;</p>

# EA4 – EMA200 Momentum + Session Block + 1 Position Only ⚡

## Concept

Simple but aggressive momentum system.

Signal rules:

- M5 EMA200 filter
- Large candle body (≥ 300 points)
- Close above EMA200 + bullish continuation → BUY
- Close below EMA200 + bearish continuation → SELL

## 🚧 Constraints

- Only 1 open position at a time
- Fixed lot
- SL session/day limiter
- Time exit
- Block after `SL_TO_STOP`

## ⚙️ Risk & Management

- Fixed SL / TP
- Session/day block reset
- Safe SL counter

## Use Case

High-momentum directional trades with strict shutdown logic.

<p>&nbsp;</p>

# 📊 Summary Comparison

| EA  | Trend Filter | Momentum Filter | Risk Model | SL Shutdown | Max Positions |
| --- | ------------ | --------------- | ---------- | ----------- | ------------- |
| EA0 | M15 + H1 EMA | Basic cross     | % Risk     | ❌          | ✅            |
| EA1 | M15 + H1 EMA | Body + Break    | % Risk     | ❌          | ✅            |
| EA2 | None         | None            | Fixed Lot  | ✅          | No limit      |
| EA3 | M15 + H1 EMA | Body Filter     | Fixed Lot  | ✅          | ✅            |
| EA4 | EMA200 (M5)  | Large Body      | Fixed Lot  | ✅          | 1 only        |

<p>&nbsp;</p>

# 📝 Notes

- Designed primarily for XAUUSD M5.
- All EAs include time-based exit ⏱️
- Spread filter used where relevant.
- SL shutdown logic prevents overtrading during bad conditions.

<p>&nbsp;</p>

**📈 Progression Path**

EA0 → Structure foundation  
EA1 → Momentum refinement  
EA2 → Capital protection experiment  
EA3 → Structured + session risk control  
EA4 → Momentum + strict discipline

<p>&nbsp;</p>
<p>&nbsp;</p>

---

<p>&nbsp;</p>
<p>&nbsp;</p>

# 📋 XAUUSD EA Backtest Report

Period tested: 2026-01-02 → 2026-02-20  
Initial balance: $100  
Timeframe: M5

---

# EA0 – MTF EMA Pullback (Structured Trend) 📐

## ✅ Best Configuration

SL = 1200  
TP = 1800  
MAX_MINUTES = 60  
EARLY_MINUTES = 15  
SL_TO_STOP = 1

## 📊 Results

End Balance: $269.90  
Total PnL: +169.90  
Trades: 290  
Winrate: 78.62% 🎯  
Max Drawdown: 72.76  
Score: 2.33

<div style="display:flex; gap:10px;">
  <img src="backtest_img/ea0_eq_curve_20260101-20260220.png" height="220">
  <img src="backtest_img/ea0_net_session_20260101-20260220.png" height="220">
  <img src="backtest_img/ea0_daily_pnl_20260101-20260220.png" height="220">
</div>

## 🗒️ Notes

- Very high winrate
- Controlled drawdown
- Low growth rate
- Defensive structure system

EA0 is stable but not explosive.

<p>&nbsp;</p>

# EA1 – MTF Pullback + Momentum Break 💥

## ✅ Best Configuration

SL = 1500  
TP = 1500  
MAX_MINUTES = 60  
EARLY_MINUTES = 60  
SL_TO_STOP = 1

## 📊 Results

End Balance: $1605.36  
Total PnL: +1505.36  
Trades: 546  
Winrate: 61.54%  
Max Drawdown: 125.74  
Score: 11.97

<div style="display:flex; gap:10px;">
  <img src="backtest_img/ea1_eq_curve_20260101-20260220.png" height="220">
  <img src="backtest_img/ea1_net_session_20260101-20260220.png" height="220">
  <img src="backtest_img/ea1_daily_pnl_20260101-20260220.png" height="220">
</div>

## Without SL Stop ⚠️

End Balance: $1301.40  
Trades: 1342  
Winrate: 36.58%  
Max DD: 228.53

## 🗒️ Notes

- Performs well only with SL_TO_STOP = 1
- Regime-sensitive
- Overtrades without stop limiter

EA1 needs shutdown logic to survive.

<p>&nbsp;</p>

# EA2 – Simple Directional Logic 🎲

## ✅ Best Configuration

SL = 500  
TP = 1800  
MAX_MINUTES = 60  
EARLY_MINUTES = 15  
SL_TO_STOP = 10

## 📊 Results

End Balance: $4426.69  
Total PnL: +4326.69  
Trades: 9246  
Winrate: 54.42%  
Max Drawdown: 271.65  
Score: 15.96

<div style="display:flex; gap:10px;">
  <img src="backtest_img/ea2_eq_curve_20260101-20260220.png" height="220">
  <img src="backtest_img/ea2_net_session_20260101-20260220.png" height="220">
  <img src="backtest_img/ea2_daily_pnl_20260101-20260220.png" height="220">
</div>

## 🗒️ Notes

- Extremely high trade frequency
- Small edge per trade
- Large exposure
- Likely fragile live (spread/slippage sensitive) ⚠️

High profit, high structural risk.

<p>&nbsp;</p>

# EA3 – Structured MTF + Session Stop 🏗️

## ✅ Best Configuration

SL = 1200  
TP = 1500  
MAX_MINUTES = 60  
EARLY_MINUTES = 60  
SL_TO_STOP = 1

## 📊 Results

End Balance: $821.06  
Total PnL: +721.06  
Trades: 374  
Winrate: 58.02%  
Max Drawdown: 97.92  
Score: 7.36

<div style="display:flex; gap:10px;">
  <img src="backtest_img/ea3_eq_curve_20260101-20260220.png" height="220">
  <img src="backtest_img/ea3_net_session_20260101-20260220.png" height="220">
  <img src="backtest_img/ea3_daily_pnl_20260101-20260220.png" height="220">
</div>

## 🗒️ Notes

- Balanced profile
- Controlled drawdown
- Moderate growth
- Structurally safer than EA1

EA3 is the most stable structured system.

<p>&nbsp;</p>

# EA4 – EMA200 Momentum Continuation ⚡

## ✅ Best Configuration

SL = 500  
TP = 1500  
MAX_MINUTES = 60  
EARLY_MINUTES = 60  
SL_TO_STOP = 1

## 📊 Results

End Balance: $1158.58  
Total PnL: +1058.58  
Trades: 273  
Winrate: 54.58%  
Max Drawdown: 37.26  
Score: 28.41 🏆

<div style="display:flex; gap:10px;">
  <img src="backtest_img/ea4_eq_curve_20260101-20260220.png" height="220">
  <img src="backtest_img/ea4_net_session_20260101-20260220.png" height="220">
  <img src="backtest_img/ea4_daily_pnl_20260101-20260220.png" height="220">
</div>

## 🗒️ Notes

- Strong asymmetry
- Very low drawdown
- Clean momentum behavior
- Performs well even with limited trades

EA4 shows highest risk efficiency in this period. 🥇

<p>&nbsp;</p>

# 🏁 Overall Summary

| EA  | PnL   | MaxDD | Winrate | Trades | Profile                         |
| --- | ----- | ----- | ------- | ------ | ------------------------------- |
| EA0 | +169  | 72    | 78% 🎯  | 290    | 🛡️ Defensive                    |
| EA1 | +1505 | 125   | 61%     | 546    | ⚡ Aggressive, regime-sensitive |
| EA2 | +4326 | 271   | 54%     | 9246   | 🎲 Overtrading, fragile         |
| EA3 | +721  | 97    | 58%     | 374    | ⚖️ Balanced                     |
| EA4 | +1058 | 37    | 54%     | 273    | 🏆 Best risk efficiency         |

---

# 🏁 Conclusion

🥇 Primary candidate: **EA4**  
🥈 Secondary stabilizer: **EA3**  
🧪 Experimental: EA1 (requires strict stop control)  
🛡️ Defensive baseline: EA0  
🎲 High-risk engine: EA2
