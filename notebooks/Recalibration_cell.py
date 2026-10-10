# =====================================================================================================
# HOW TO USE (both notebooks)
#  1. Open maternal_mortality_models.ipynb (Model A) and maternal_smm_models.ipynb (Model B) with their kernels still alive
#     after Section 14.1 (needs y, y_oof, LABEL, np, pd, plt and display already defined).
#  2. Insert a NEW code cell right after the Section 14.1 cell, paste everything below the line, and run it. It takes seconds.
#     (Optionally add a markdown cell above it titled "14.2. Post-hoc recalibration (Platt / isotonic)".)
#  3. Send me the printed tables (or Table_Recalibration_<LABEL>.csv) and Fig_Recalibration_<LABEL>.png for both models.
# If the kernel was restarted, re-run Section 14.1 first (it creates y_oof with one extra stacking CV).
# =====================================================================================================
# 14.2. Post-hoc recalibration (Platt scaling and isotonic regression), evaluated out-of-sample
# Requires the objects from Section 14.1: y (full-cohort labels), y_oof (out-of-fold stacking probabilities) and LABEL.
# NO model is re-trained here: only a one-feature calibration map is fitted on the out-of-fold probabilities.
from sklearn.isotonic import IsotonicRegression
from sklearn.linear_model import LogisticRegression
from sklearn.model_selection import StratifiedKFold
from sklearn.metrics import brier_score_loss, roc_auc_score, average_precision_score
from sklearn.calibration import calibration_curve

N_REPEATS_CAL = 20      # repetitions of the calibration cross-validation (different fold assignments)
N_SPLITS_CAL = 5

def _logit(p, eps=1e-6):
    p = np.clip(np.asarray(p, dtype=float), eps, 1 - eps)
    return np.log(p / (1 - p))

def _ece_quantile(y_true, y_prob, n_bins=10):
    """Expected calibration error with equal-frequency bins."""
    y_true = np.asarray(y_true); y_prob = np.asarray(y_prob)
    bins = np.array_split(np.argsort(y_prob, kind="mergesort"), n_bins)
    return float(sum(len(b) / len(y_true) * abs(y_true[b].mean() - y_prob[b].mean()) for b in bins))

def _slope_intercept(y_true, y_prob):
    """Calibration slope and intercept: logistic regression of the outcome on logit(p). Ideal: slope 1, intercept 0."""
    lr = LogisticRegression(C=1e6, max_iter=2000).fit(_logit(y_prob).reshape(-1, 1), y_true)
    return float(lr.coef_[0, 0]), float(lr.intercept_[0])

def _fit_predict_calibrator(method, p_tr, y_tr, p_te):
    if method == "Platt":
        cal = LogisticRegression(C=1e6, max_iter=2000).fit(_logit(p_tr).reshape(-1, 1), y_tr)
        return cal.predict_proba(_logit(p_te).reshape(-1, 1))[:, 1]
    cal = IsotonicRegression(y_min=0.0, y_max=1.0, out_of_bounds="clip").fit(p_tr, y_tr)
    return cal.predict(p_te)

def _metrics(y_true, p):
    prev = y_true.mean()
    brier = brier_score_loss(y_true, p); brier_ref = brier_score_loss(y_true, np.full(len(y_true), prev))
    slope, intercept = _slope_intercept(y_true, p)
    return {"Brier": brier, "Brier skill": 1 - brier / brier_ref, "mean pred / prevalence": p.mean() / prev,
            "ECE (10 quantile bins)": _ece_quantile(y_true, p), "slope": slope, "intercept": intercept,
            "AUC": roc_auc_score(y_true, p), "AP": average_precision_score(y_true, p)}

y_arr = np.asarray(y).astype(int); p_raw = np.asarray(y_oof, dtype=float)
rows = {"Raw (class-weighted)": [_metrics(y_arr, p_raw)]}
examples = {}
for method in ["Platt", "Isotonic"]:
    rows[method] = []
    for r in range(N_REPEATS_CAL):
        skf_cal = StratifiedKFold(n_splits=N_SPLITS_CAL, shuffle=True, random_state=100 + r)
        p_cal = np.zeros(len(y_arr))
        for tr, te in skf_cal.split(p_raw.reshape(-1, 1), y_arr):
            p_cal[te] = _fit_predict_calibrator(method, p_raw[tr], y_arr[tr], p_raw[te])
        rows[method].append(_metrics(y_arr, p_cal))
        if r == 0:
            examples[method] = p_cal.copy()

summary = pd.DataFrame({k: pd.DataFrame(v).mean() for k, v in rows.items()}).T
summary_sd = pd.DataFrame({k: pd.DataFrame(v).std(ddof=1) if len(v) > 1 else pd.DataFrame(v).mean() * 0 for k, v in rows.items()}).T
print(f"Recalibration of the out-of-fold stacking probabilities -- {LABEL} -- N = {len(y_arr)}, events = {int(y_arr.sum())}, "
      f"prevalence = {y_arr.mean():.5f}")
print(f"Calibration maps fitted inside {N_SPLITS_CAL}-fold CV (repeated {N_REPEATS_CAL}x); mean over repetitions.\n")
display(summary.round(4))
print("\nSD across repetitions (variability of the calibration folds only):")
display(summary_sd.round(4))
summary.round(5).to_csv(f"Table_Recalibration_{LABEL}.csv")

# Rank-based metrics: each calibration map is monotonic, but maps differ between folds, so pooled AUC/AP can change slightly;
# isotonic regression also creates ties and can lose resolution.
fig, ax = plt.subplots(1, 2, figsize=(11, 4.6))
curves = {"Raw (class-weighted)": p_raw, "Platt": examples["Platt"], "Isotonic": examples["Isotonic"]}
for name, pp in curves.items():
    fp, mp = calibration_curve(y_arr, pp, n_bins=10, strategy="quantile")
    ok = (fp > 0) & (mp > 0)
    ax[0].plot(mp[ok], fp[ok], "o-", label=name)
lo = 1e-4
ax[0].plot([lo, 1], [lo, 1], "k--", label="perfect calibration")
ax[0].set_xscale("log"); ax[0].set_yscale("log")
ax[0].set_xlabel("Mean predicted probability"); ax[0].set_ylabel("Observed event rate")
ax[0].set_title("Reliability (log-log)"); ax[0].legend(fontsize=8)
ax[1].bar(summary.index, summary["Brier skill"], color=["#C44E52", "#4C72B0", "#DD8452"])
ax[1].axhline(0, color="k", linewidth=1)
ax[1].set_ylabel("Brier skill score (0 = prevalence-only model)"); ax[1].set_title("Brier skill after recalibration")
ax[1].tick_params(axis="x", rotation=15)
fig.suptitle(f"{LABEL}: post-hoc recalibration of out-of-fold stacking probabilities", weight="bold")
plt.tight_layout()
plt.savefig(f"Fig_Recalibration_{LABEL}.pdf", format="pdf", bbox_inches="tight")
plt.savefig(f"Fig_Recalibration_{LABEL}.png", format="png", dpi=300, bbox_inches="tight")
plt.show()
