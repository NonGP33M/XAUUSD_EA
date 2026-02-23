import pandas as pd
import numpy as np

POINT = 0.01
SL_PTS = 1200
TP_PTS = 1500
EARLY_MINUTES = 15
MAX_HOLD_HOURS = 1
SPREAD_PTS_EST = 20  # optional estimate for net check

cand = pd.read_csv("./input/xau_m5_candidates.csv")
cand["time"] = pd.to_datetime(cand["time"])
cand = cand.sort_values("time")

m1 = pd.read_csv("./input/XAUUSDsc_M1.csv")
m1["time"] = pd.to_datetime(m1["time"])
m1 = m1.sort_values("time").set_index("time")

# IMPORTANT: keep only candidates we can label with available M1
m1_start, m1_end = m1.index.min(), m1.index.max()
cand = cand[(cand["time"] >= m1_start) & (cand["time"] <= m1_end)].copy()
print("candidates in M1 range:", len(cand))

def get_entry_close(t0):
    idx = m1.index.searchsorted(t0, side="right") - 1
    if idx < 0:
        return None
    return float(m1.iloc[idx]["close"])

def label_one(t0, side):
    entry = get_entry_close(t0)
    if entry is None:
        return (np.nan, None, np.nan)

    if side == "BUY":
        sl = entry - SL_PTS * POINT
        tp = entry + TP_PTS * POINT
    else:
        sl = entry + SL_PTS * POINT
        tp = entry - TP_PTS * POINT

    t_early = t0 + pd.Timedelta(minutes=EARLY_MINUTES)
    t_end   = t0 + pd.Timedelta(hours=MAX_HOLD_HOURS)

    window = m1.loc[t0:t_end]
    if window.empty:
        return (np.nan, None, np.nan)

    for t, bar in window.iterrows():
        h, l, c = float(bar["high"]), float(bar["low"]), float(bar["close"])

        if side == "BUY":
            if l <= sl:
                return (0, "SL", (sl - entry)/POINT)
            if h >= tp:
                return (1, "TP", (tp - entry)/POINT)
        else:
            if h >= sl:
                return (0, "SL", (entry - sl)/POINT)
            if l <= tp:
                return (1, "TP", (entry - tp)/POINT)

        if t >= t_early:
            pnl_pts = (c - entry)/POINT if side == "BUY" else (entry - c)/POINT
            if pnl_pts > 0:
                return (1, "EARLY_PROFIT", pnl_pts)

    return (np.nan, None, np.nan)

out = [label_one(t, s) for t, s in zip(cand["time"], cand["side"])]
cand["y"] = [o[0] for o in out]
cand["exit_reason"] = [o[1] for o in out]
cand["exit_points"] = [o[2] for o in out]

cand = cand.dropna(subset=["y"]).copy()
cand["y"] = cand["y"].astype(int)

cand.to_csv("./output/dataset_labeled_with_exit.csv", index=False)

print("labeled rows:", len(cand))
print("label counts:\n", cand["y"].value_counts())
print("exit_reason counts:\n", cand["exit_reason"].value_counts())
print("avg points win:", cand.loc[cand["y"]==1, "exit_points"].mean())
print("avg points loss:", cand.loc[cand["y"]==0, "exit_points"].mean())
net_points = cand["exit_points"].sum()
print("net points (gross):", net_points)

# optional spread realism check (rough)
net_after_spread = net_points - SPREAD_PTS_EST * len(cand)
print("net points after spread est:", net_after_spread)
print("avg points/trade after spread:", net_after_spread/len(cand))