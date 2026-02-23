import pandas as pd
import numpy as np
import joblib
from xgboost import XGBClassifier
from sklearn.metrics import roc_auc_score, accuracy_score

# ==============================
# LOAD DATA
# ==============================

df = pd.read_csv("./output/dataset_labeled_with_exit.csv")
df["time"] = pd.to_datetime(df["time"])
df = df.sort_values("time").reset_index(drop=True)

# ------------------------------
# TARGET: win / loss
# ------------------------------
df["target"] = (df["exit_points"] > 0).astype(int)

# ------------------------------
# FEATURES
# ------------------------------
feature_cols = ["spread_pts","atr_pts"] + \
               [f"r{i}" for i in range(1,11)] + \
               [f"{p}{i}" for i in range(1,11) for p in ["body","upw","loww"]]

X = df[feature_cols].astype(float)
y = df["target"]
points = df["exit_points"]

# ==============================
# TIME SERIES SPLIT (80/20)
# ==============================

split = int(len(df)*0.8)

X_train, X_test = X.iloc[:split], X.iloc[split:]
y_train, y_test = y.iloc[:split], y.iloc[split:]
points_train, points_test = points.iloc[:split], points.iloc[split:]

# ==============================
# MODEL
# ==============================

model = XGBClassifier(
    objective="binary:logistic",
    eval_metric="logloss",
    max_depth=3,
    learning_rate=0.03,
    n_estimators=600,
    subsample=0.8,
    colsample_bytree=0.8,
    random_state=42
)

model.fit(X_train, y_train)

# ==============================
# PREDICT PROBABILITY
# ==============================

proba_test = model.predict_proba(X_test)[:,1]

# ==============================
# THRESHOLD OPTIMIZATION
# ==============================

def evaluate_threshold(th):
    mask = proba_test >= th
    if mask.sum() == 0:
        return 0,0,0,0
    
    pts = points_test[mask]
    wins = pts[pts > 0]
    losses = pts[pts <= 0]

    win_rate = len(wins) / len(pts)
    avg_win = wins.mean() if len(wins)>0 else 0
    avg_loss = losses.mean() if len(losses)>0 else 0

    expectancy = win_rate*avg_win + (1-win_rate)*avg_loss
    net = pts.sum()
    
    return expectancy, net, win_rate, len(pts)

best_th = 0
best_exp = -1e9

for th in np.arange(0.5,0.9,0.01):
    exp, net, wr, ntr = evaluate_threshold(th)
    if exp > best_exp:
        best_exp = exp
        best_th = th

print("Best threshold:", round(best_th,2))

exp, net, wr, ntr = evaluate_threshold(best_th)

print("Test trades taken:", ntr)
print("Win rate:", wr)
print("Net points:", net)
print("Expectancy per trade:", exp)
print("AUC:", roc_auc_score(y_test, proba_test))

# ==============================
# SAVE MODEL
# ==============================

joblib.dump({
    "model": model,
    "feature_cols": feature_cols,
    "threshold": best_th
}, "./output/xgb_classifier_confirm.pkl")

print("Saved xgb_classifier_confirm.pkl")
