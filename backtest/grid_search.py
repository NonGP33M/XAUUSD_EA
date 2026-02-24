import pandas as pd
import numpy as np
import time
from itertools import product

# ========= FILES =========
CAND_FILE = "./src_csv/xau_m5_candidates_ea0.csv"
M1_FILE   = "./src_csv/m1_master.csv"

POINT = 0.01
USD_PER_POINT = 0.01
START_BALANCE = 100.0
SPREAD_PTS = 8
SPREAD = SPREAD_PTS * POINT

START_ALL = "2026-01-01 00:00"
END_ALL   = "2026-02-20 23:59"

# ========= LOAD =========
cand = pd.read_csv(CAND_FILE)
cand.columns = cand.columns.str.strip()
cand["time"] = pd.to_datetime(cand["time"])
cand = cand.sort_values("time")

m1 = pd.read_csv(M1_FILE)
m1.columns = m1.columns.str.strip()
m1["time"] = pd.to_datetime(m1["time"])
m1 = m1.sort_values("time").set_index("time")

cand = cand[
    (cand["time"] >= START_ALL) &
    (cand["time"] <= END_ALL)
].copy()

def get_session(h):
    if 0 <= h < 8:
        return "Asia"
    elif 8 <= h < 16:
        return "Europe"
    else:
        return "America"

cand["hour"] = cand["time"].dt.hour
cand["session"] = cand["hour"].apply(get_session)
cand["date"] = cand["time"].dt.date

# ========= SIM =========
def simulate_one(t0, side, SL_PTS, TP_PTS, MAX_MINUTES, EARLY_MINUTES):

    t_entry = t0 + pd.Timedelta(minutes=4)
    if t_entry not in m1.index:
        return np.nan

    entry_close = float(m1.loc[t_entry]["close"])

    if side == "BUY":
        entry = entry_close + SPREAD/2
        sl = entry - SL_PTS*POINT
        tp = entry + TP_PTS*POINT
    else:
        entry = entry_close - SPREAD/2
        sl = entry + SL_PTS*POINT
        tp = entry - TP_PTS*POINT

    future = m1.loc[t_entry:].iloc[1:MAX_MINUTES+1]

    for i, (_, row) in enumerate(future.iterrows(), start=1):

        close_price = float(row["close"])
        bid = close_price - SPREAD/2
        ask = close_price + SPREAD/2

        if side == "BUY":
            if bid <= sl:
                return -SL_PTS
            if bid >= tp:
                return TP_PTS
        else:
            if ask >= sl:
                return -SL_PTS
            if ask <= tp:
                return TP_PTS

        if EARLY_MINUTES and i >= EARLY_MINUTES:
            profit = (bid-entry)/POINT if side=="BUY" else (entry-ask)/POINT
            if profit > 0:
                return profit

        if i >= MAX_MINUTES:
            profit = (bid-entry)/POINT if side=="BUY" else (entry-ask)/POINT
            return profit

    return np.nan


# ========= BACKTEST =========
def run_param_set(sl, tp, max_m, early_m, sl_stop):

    results = []
    sl_streak = {}
    session_blocked = set()

    for row in cand.itertuples():

        key = (row.date, row.session)

        if key in session_blocked:
            continue

        pts = simulate_one(row.time, row.side, sl, tp, max_m, early_m)

        if np.isnan(pts):
            continue

        pnl = pts * USD_PER_POINT

        if pts == -sl:
            sl_streak[key] = sl_streak.get(key, 0) + 1
        else:
            sl_streak[key] = 0

        if sl_streak[key] >= sl_stop:
            session_blocked.add(key)

        results.append(pnl)

    if len(results) == 0:
        return None

    pnl = np.array(results)
    equity = START_BALANCE + pnl.cumsum()
    dd = (np.maximum.accumulate(equity) - equity).max()

    return {
        "SL": sl,
        "TP": tp,
        "MAX": max_m,
        "EARLY": early_m,
        "STOP": sl_stop,
        "TotalPnL": pnl.sum(),
        "Winrate": (pnl > 0).mean(),
        "MaxDD": dd,
        "Trades": len(pnl),
        "Score": pnl.sum() / (dd + 1e-9)
    }


# ========= GRID =========
SL_LIST    = [500, 800, 1200, 1500, 1800]
TP_LIST    = [500, 800, 1200, 1500, 1800]
MAX_LIST   = [60]
EARLY_LIST = [15,60]
STOP_LIST  = [1, 2, 100]
# STOP_LIST  = [100]

total = len(SL_LIST)*len(TP_LIST)*len(MAX_LIST)*len(EARLY_LIST)*len(STOP_LIST)

grid_results = []
start = time.time()

for i, params in enumerate(product(SL_LIST, TP_LIST, MAX_LIST, EARLY_LIST, STOP_LIST), 1):

    res = run_param_set(*params)

    if res:
        grid_results.append(res)

    if i % 10 == 0 or i == total:
        elapsed = time.time() - start
        print(f"{i}/{total} done | {elapsed:.1f}s")

print("Finished.")

grid_df = pd.DataFrame(grid_results)
grid_df = grid_df.sort_values("Score", ascending=False)

print("\nTOP 10:")
print(grid_df.head(10))