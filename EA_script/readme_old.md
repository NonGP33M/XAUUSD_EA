# EA Comparison (EA0 vs EA1 vs EA2)

---

# EA0

## Parameters

SL_PTS = 1200  
TP_PTS = 1800  
MAX_MINUTES = 60  
EARLY_MINUTES = 15

SL_TO_STOP = 2  
STOP_MODE = "session"

## Results

Start balance: 100  
End balance: 519.76  
Total PnL: +419.76

Total trades: 945  
Winrate: 79.0%  
Avg PnL: 0.44  
Max Drawdown: 160.94

## Algorithm

### Entry Logic

- Uses M5 candidate logic
- Trend-following directional filter
- Trade opens at M5 close
- One trade per signal

### Exit Logic

- Hard SL = 1200 points
- Hard TP = 1800 points
- Early management active after 15 minutes
- Forced close after 60 minutes

### Risk Control

- Stop trading after 2 SL in same session
- Reset next session

### Profile

- High winrate
- Smooth equity
- Controlled drawdown
- Stable session behavior

---

# EA1 (Best Performer)

## Parameters

SL_PTS = 1200  
TP_PTS = 1800  
MAX_MINUTES = 60  
EARLY_MINUTES = 15

SL_TO_STOP = 1  
STOP_MODE = "session"

## Results

Start balance: 100  
End balance: 1166.62  
Total PnL: +1066.62

Total trades: 1037  
Winrate: 83.7%  
Avg PnL: 1.03  
Max Drawdown: 82.39

## Algorithm

### Entry Logic

- Same M5 candidate structure as EA0
- Strong directional filter
- Trade opens at M5 close

### Exit Logic

- Hard SL = 1200
- Hard TP = 1800
- Early management active after 15 minutes
- Forced close at 60 minutes

### Risk Control

- Stop trading after 1 SL in session
- Very strict capital protection

### Profile

- Highest winrate
- Lowest drawdown
- Very smooth equity
- Strong BUY dominance in Asia/Europe
- Best risk-adjusted model

---

# EA2 (Aggressive RR Model)

## Parameters

SL_PTS = 800  
TP_PTS = 1800  
MAX_MINUTES = 60  
EARLY_MINUTES = 60

SL_TO_STOP = 1  
STOP_MODE = "session"

## Results

Start balance: 100  
End balance: 775.19  
Total PnL: +675.19

Total trades: 871  
Winrate: 46.3%  
Avg PnL: 0.77  
Max Drawdown: 424.85

## Algorithm

### Entry Logic

- Same M5 candidate logic
- No early management bias
- Pure RR structure

### Exit Logic

- Tight SL = 800
- Large TP = 1800
- Early logic effectively disabled (EARLY = 60)
- Forced close at 60 minutes

### Risk Control

- Stop after 1 SL per session

### Profile

- Lower winrate
- High volatility
- Large drawdown
- Equity unstable mid-period
- Performance driven by large winners

---

# Direct Comparison

| EA  | SL   | TP   | Early | SL Stop | Winrate | Max DD | PnL   | Stability |
| --- | ---- | ---- | ----- | ------- | ------- | ------ | ----- | --------- |
| EA0 | 1200 | 1800 | 15    | 2       | 79%     | 160    | +419  | Stable    |
| EA1 | 1200 | 1800 | 15    | 1       | 83.7%   | 82     | +1066 | Strongest |
| EA2 | 800  | 1800 | 60    | 1       | 46%     | 424    | +675  | Volatile  |

---

# Structural Conclusion

EA1 = Best capital efficiency  
EA0 = Safer fallback  
EA2 = High variance model

For live deployment → EA1 structure is superior.
