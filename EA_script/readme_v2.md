# XAUUSD M5 EA Research (EA0–EA4)

Test Period: 2026-01-02 → 2026-02-20  
Initial Balance: 100 USD  
Symbol: XAUUSD  
Execution: M5

---

# EA0 – M5 EMA Pullback (MTF Alignment, Early Exit)

## 1. Core Concept

Multi-timeframe EMA trend-following with M5 pullback entry.

Trend filter:

- M15 EMA(50/200)
- H1 EMA(50/200)
- Must align

Entry timeframe:

- M5
- Pullback trigger: EMA(20)

---

## 2. Entry Logic

BUY

- M15 = BULL
- H1 = BULL
- Previous M5 close < EMA(20)
- Current M5 close > EMA(20)

SELL

- M15 = BEAR
- H1 = BEAR
- Previous M5 close > EMA(20)
- Current M5 close < EMA(20)

---

## 3. Risk & Trade Management

- Risk: 1% balance
- SL / TP fixed
- MaxPositions = 10
- Spread ≤ 60
- Early exit: profit > 0 after 15 min
- Hard exit: 60 min

---

## 4. Best Result

SL = 1200  
TP = 1800  
MAX = 60  
EARLY = 15  
STOP = 1

PnL: +169.90  
Trades: 290  
Winrate: 78.62%  
MaxDD: 72.76  
Score: 2.33

Profile: stable, high accuracy, low expansion.

---

# EA1 – M5 Momentum Breakout (MTF + Body Filter)

## 1. Core Concept

Trend-following breakout with strength confirmation.

Trend filter:

- M15 EMA(50/200)
- H1 EMA(50/200)

Entry:

- M5 breakout
- EMA(20) pullback reference
- Body size filter

---

## 2. Entry Logic

BUY

- M15 = BULL
- H1 = BULL
- Previous low ≤ EMA(20)
- Current breaks previous high
- Body ≥ MinBodyPts

SELL

- M15 = BEAR
- H1 = BEAR
- Previous high ≥ EMA(20)
- Current breaks previous low
- Body ≥ MinBodyPts

---

## 3. Risk & Trade Management

- Risk: 1% balance
- SL / TP fixed
- MaxPositions = 10
- Spread ≤ 60
- Time exit: 60 min
- No effective early exit

---

## 4. Best Result

SL = 1200  
TP = 1500  
MAX = 60  
STOP = 1

PnL: +721.06  
Trades: 374  
Winrate: 58.02%  
MaxDD: 97.92  
Score: 7.36

Profile: real growth engine, controlled aggression.

---

# EA2 – Simple Momentum + SL Session Block

## 1. Core Concept

Raw M5 momentum with aggressive loss throttle.

- No EMA filter
- Fixed lot
- Session/day SL block

---

## 2. Entry Logic

BUY

- Close(1) > Close(2)

SELL

- Close(1) < Close(2)

Pure directional momentum.

---

## 3. Risk & Controls

- FixedLot = 0.10
- SL / TP fixed
- Time exit = 60 min
- SL_TO_STOP = 2
- STOP_MODE = session/day
- Block trading after SL threshold

---

## 4. Best Result

SL = 800  
TP = 1800  
MAX = 60  
STOP = 1

PnL: +648.63  
Trades: 302  
Winrate: 48.01%  
MaxDD: 80.01  
Score: 8.10

Profile: low accuracy, high asymmetry.

---

# EA3 – Pullback Reclaim + Session SL Cutoff

## 1. Core Concept

Refined pullback continuation with session loss throttle.

- M15 + H1 EMA(50/200)
- M5 EMA(20)
- Body filter
- Fixed lot
- Session SL cap

---

## 2. Entry Logic

BUY

- M15 = BULL
- H1 = BULL
- Candle(2) close < EMA(20)
- Candle(1) high > EMA(20)
- Body(2) ≥ MinBodyPts

SELL

- M15 = BEAR
- H1 = BEAR
- Candle(2) close > EMA(20)
- Candle(1) low < EMA(20)
- Body(2) ≥ MinBodyPts

Pullback → reclaim → continuation.

---

## 3. Risk & Controls

- FixedLot = 0.01
- SL / TP fixed
- MaxPositions = 10
- Spread filter
- Time exit = 60 min
- SessionSL_Limit = 2
- Stop trading after session loss cap

---

## 4. Structural Positioning

Balanced architecture:

- Cleaner than EA2
- More protected than EA1
- Less aggressive than EA2

Mid-aggression system.

---

# EA4 – EMA200 Momentum + Body Filter + Session Kill Switch

## 1. Core Concept

Momentum continuation with structural trend filter.

- EMA200 (M5)
- Strong body filter (≥ 300 pts)
- Fixed lot
- Session/day SL throttle
- One position only

---

## 2. Entry Logic

BUY

- Body ≥ 300 pts
- Close1 > Close2
- Close1 > EMA200

SELL

- Body ≥ 300 pts
- Close1 < Close2
- Close1 < EMA200

Continuation bias.

---

## 3. Risk & Controls

- FixedLot = 0.01
- SL / TP fixed
- Max time = 60 min
- 1 position
- SL_TO_STOP = 2
- STOP_MODE = session/day
- Loss counted via DEAL_REASON_SL

---

## 4. Best Result

SL = 800  
TP = 1800  
MAX = 60  
STOP = 1

PnL: +1833.45  
Trades: 425  
Winrate: 60.7%  
MaxDD: 74.91  
Score: 24.47

Profile: dominant asymmetry with controlled drawdown.

---

# Final Comparison (EA0–EA4)

| EA  | Style               | PnL      | Winrate | MaxDD | Score | Character |
| --- | ------------------- | -------- | ------- | ----- | ----- | --------- |
| EA0 | Pullback cross      | +169.9   | 78.6%   | 72.76 | 2.33  | Stable    |
| EA1 | Breakout momentum   | +721.06  | 58.0%   | 97.92 | 7.36  | Growth    |
| EA2 | Raw momentum        | +648.63  | 48.0%   | 80.01 | 8.10  | Asymmetry |
| EA3 | Pullback reclaim    | —        | —       | —     | —     | Balanced  |
| EA4 | EMA200 continuation | +1833.45 | 60.7%   | 74.91 | 24.47 | Leader    |

Blunt ranking:

1. EA4 – Clear flagship
2. EA2 – Strong asymmetry engine
3. EA1 – Reliable growth
4. EA3 – Structural middle ground
5. EA0 – Stable baseline
