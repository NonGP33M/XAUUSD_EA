from fastapi import FastAPI, HTTPException
from pydantic import BaseModel

# Pydantic v2 uses field_validator; v1 uses validator.
# We'll support both by trying v2 first.
try:
    from pydantic import field_validator  # pydantic v2
    USE_V2 = True
except ImportError:
    from pydantic import validator as field_validator  # pydantic v1 fallback
    USE_V2 = False

import joblib
import numpy as np

BUNDLE_PATH = "./output/xgb_classifier_confirm.pkl"

bundle = joblib.load(BUNDLE_PATH)
model = bundle["model"]
thr = float(bundle.get("threshold", 0.5))

app = FastAPI()

class Features(BaseModel):
    spread_pts: float
    atr_pts: float
    r: list[float]
    body: list[float]
    upw: list[float]
    loww: list[float]

    if USE_V2:
        @field_validator("r", "body", "upw", "loww")
        @classmethod
        def must_be_len_10(cls, v):
            if len(v) != 10:
                raise ValueError("must have length 10")
            return v
    else:
        @field_validator("r", "body", "upw", "loww")
        def must_be_len_10(cls, v):
            if len(v) != 10:
                raise ValueError("must have length 10")
            return v

@app.get("/health")
def health():
    return {"ok": True, "threshold": thr}

@app.post("/score")
def score(f: Features):
    x = [f.spread_pts, f.atr_pts] + f.r + f.body + f.upw + f.loww
    if len(x) != 42:
        # should never happen if validation is correct, but keep it safe
        raise HTTPException(status_code=422, detail=f"feature length must be 42, got {len(x)}")

    X = np.array([x], dtype=float)

    # xgboost sklearn API
    proba = float(model.predict_proba(X)[0, 1])
    return {"proba": proba, "threshold": thr, "take": proba >= thr}