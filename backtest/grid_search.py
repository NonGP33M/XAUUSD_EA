import pandas as pd
import numpy as np
import time
from itertools import product
from multiprocessing import Pool, cpu_count

# ========= FILES =========
CAND_FILE = "./src_csv/xau_m5_candidates_ea2.csv"
M1_FILE   = "./src_csv/m1_master.csv"

POINT         = 0.01
USD_PER_POINT = 0.01
START_BALANCE = 100.0
SPREAD_PTS    = 8
SPREAD        = SPREAD_PTS * POINT

START_ALL = "2026-02-01 00:00"
END_ALL   = "2026-02-20 23:59"

# ========= GRID =========
SL_LIST       = [500, 800, 1200, 1500, 2000]
TP_LIST       = [500, 800, 1200, 1500, 1800, 2000]
MAX_LIST      = [15, 30, 60, 120]
EARLY_LIST    = [15, 30, 60, 120]
STOP_LIST     = [1, 2, 4, 10]
MAX_POS_LIST  = [1, 2, 3, 4, 5]         # ← added to grid
FULL_TIME     = True

# ========= LOAD =========
print("Loading data...")

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
    if h < 8:    return "Asia"
    elif h < 16: return "Europe"
    else:        return "America"

cand["hour"]    = cand["time"].dt.hour
cand["session"] = cand["hour"].apply(get_session)
cand["date"]    = cand["time"].dt.date

# =========================================================
# PRE-COMPUTE: for each candidate, extract the full M1
# price arrays ONCE so simulate is just numpy operations
# =========================================================
MAX_LOOKFORWARD = max(MAX_LIST)  # longest window we'll ever need

print(f"Pre-computing {len(cand)} trade windows (MAX_LOOKFORWARD={MAX_LOOKFORWARD})...")

m1_close = m1["close"].values
m1_times = m1.index
m1_pos   = {t: i for i, t in enumerate(m1_times)}  # time → integer index (fast lookup)

# For each candidate store:
#   entry_price, side (1=BUY/-1=SELL), session_key, signal_time
#   + numpy array of bid/ask for next MAX_LOOKFORWARD minutes
records = []

for _, row in cand.iterrows():
    t0      = row["time"]
    side    = row["side"]
    t_entry = t0 + pd.Timedelta(minutes=4)

    if t_entry not in m1_pos:
        continue

    idx = m1_pos[t_entry]

    entry_close = m1_close[idx]
    if side == "BUY":
        entry = entry_close + SPREAD / 2
    else:
        entry = entry_close - SPREAD / 2

    # future closes: idx+1 .. idx+MAX_LOOKFORWARD
    end_idx  = min(idx + 1 + MAX_LOOKFORWARD, len(m1_close))
    future_c = m1_close[idx+1 : end_idx]
    future_t = m1_times[idx+1 : end_idx]

    if len(future_c) == 0:
        continue

    bid_arr = future_c - SPREAD / 2
    ask_arr = future_c + SPREAD / 2

    records.append({
        "time":      t0,
        "side":      1 if side == "BUY" else -1,
        "entry":     entry,
        "bid":       bid_arr,
        "ask":       ask_arr,
        "exit_t":    future_t,
        "session":   get_session(t0.hour),
        "date":      t0.date(),
    })

print(f"Valid candidates: {len(records)}")

# =========================================================
# FAST SIMULATE: numpy-only, no row iteration inside
# Returns (pts, exit_idx) for given SL/TP/MAX/EARLY params
# =========================================================
def simulate_vectorized(rec, SL_PTS, TP_PTS, MAX_MINUTES, EARLY_MINUTES):

    entry  = rec["entry"]
    side   = rec["side"]   # 1 or -1
    bid    = rec["bid"][:MAX_MINUTES]
    ask    = rec["ask"][:MAX_MINUTES]
    n      = len(bid)

    if n == 0:
        return np.nan, None

    sl_price = entry - side * SL_PTS * POINT
    tp_price = entry + side * TP_PTS * POINT

    if side == 1:  # BUY
        sl_hit = bid <= sl_price
        tp_hit = bid >= tp_price
    else:          # SELL
        sl_hit = ask >= sl_price
        tp_hit = ask <= tp_price

    # first SL / TP hit
    sl_idx = int(np.argmax(sl_hit)) if sl_hit.any() else n
    tp_idx = int(np.argmax(tp_hit)) if tp_hit.any() else n

    first_hit = min(sl_idx, tp_idx)

    # early exit check
    if not FULL_TIME:
        if EARLY_MINUTES and EARLY_MINUTES <= n:
            early_range = slice(EARLY_MINUTES - 1, first_hit)
            if side == 1:
                profit_arr = (bid[early_range] - entry) / POINT
            else:
                profit_arr = (entry - ask[early_range]) / POINT

            pos_mask = profit_arr > 0
            if pos_mask.any():
                early_i = int(np.argmax(pos_mask)) + (EARLY_MINUTES - 1)
                if early_i < first_hit:
                    exit_idx = early_i
                    pts = profit_arr[early_i - (EARLY_MINUTES - 1)]
                    return pts, rec["exit_t"][exit_idx]

    if first_hit >= n:
        # time exit
        if side == 1:
            pts = (bid[-1] - entry) / POINT
        else:
            pts = (entry - ask[-1]) / POINT
        return pts, rec["exit_t"][-1]

    if sl_idx <= tp_idx:
        return -SL_PTS, rec["exit_t"][sl_idx]
    else:
        return  TP_PTS, rec["exit_t"][tp_idx]


# =========================================================
# BACKTEST ENGINE
# =========================================================
def run_param_set(params):
    sl, tp, max_m, early_m, sl_stop, max_pos = params

    results     = []
    sl_streak   = {}
    blocked     = set()
    open_trades = []  # list of exit timestamps

    for rec in records:

        key = (rec["date"], rec["session"])

        if key in blocked:
            continue

        # remove expired trades
        t = rec["time"]
        open_trades = [et for et in open_trades if t <= et]

        if len(open_trades) >= max_pos:
            continue

        pts, exit_time = simulate_vectorized(rec, sl, tp, max_m, early_m)

        if np.isnan(pts):
            continue

        if exit_time is not None:
            open_trades.append(exit_time)

        pnl = pts * USD_PER_POINT

        if pts == -sl:
            sl_streak[key] = sl_streak.get(key, 0) + 1
        else:
            sl_streak[key] = 0

        if sl_streak[key] >= sl_stop:
            blocked.add(key)

        results.append(pnl)

    if len(results) == 0:
        return None

    pnl    = np.array(results)
    equity = START_BALANCE + pnl.cumsum()
    dd     = (np.maximum.accumulate(equity) - equity).max()
    
    if FULL_TIME:
        early_m = max_m

    return {
        "SL":       sl,
        "TP":       tp,
        "MAX":      max_m,
        "EARLY":    early_m,
        "STOP":     sl_stop,
        "MAX_POS":  max_pos,
        "TotalPnL": round(pnl.sum(), 2),
        "Winrate":  round((pnl > 0).mean(), 4),
        "MaxDD":    round(dd, 2),
        "Trades":   len(pnl),
        "Score":    round(pnl.sum() / (dd + 1e-9), 4),
    }


# =========================================================
# GRID SEARCH with multiprocessing
# =========================================================
all_params = list(product(SL_LIST, TP_LIST, MAX_LIST, EARLY_LIST, STOP_LIST, MAX_POS_LIST))
total      = len(all_params)
print(f"\nGrid size: {total} combinations")
print(f"CPUs: {cpu_count()}")

if __name__ == "__main__":

    start = time.time()

    with Pool(processes=cpu_count()) as pool:
        grid_results = []
        for i, res in enumerate(pool.imap_unordered(run_param_set, all_params, chunksize=10), 1):
            if res:
                grid_results.append(res)
            if i % 50 == 0 or i == total:
                elapsed = time.time() - start
                pct = i / total * 100
                print(f"{i}/{total} ({pct:.0f}%) | {elapsed:.1f}s")

    elapsed = time.time() - start
    print(f"\nFinished in {elapsed:.1f}s")

    grid_df = pd.DataFrame(grid_results)
    grid_df = grid_df.sort_values("Score", ascending=False).reset_index(drop=True)

    print("\n===== TOP 20 By Score =====")
    print(grid_df.head(20).to_string())

    grid_df = grid_df.sort_values("TotalPnL", ascending=False).reset_index(drop=True)
    print("\n===== TOP 20 By TotalPnL =====")
    print(grid_df.head(20).to_string())

