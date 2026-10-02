#!/usr/bin/env python3
"""Per-speaker stress-rule comparison and cue profiles (speaker_cues/models/02_speaker_models.py).

For every speaker with >= MIN_TOK vowels (words of 2-6 syllables) in >= MIN_FILES recordings, fit per rule and cue
    DV_c ~ rule + syl1 + syl2 + word_final + utt_final_word + utt_final_syl
by OLS. DV_c is centred within recording, which absorbs any recording-level covariate, the broadcast score
included. SEs are cluster-robust by word type. Within a speaker every rule and cue is fitted on the same rows
(complete cases on all three DVs), so AIC differences between rules are comparable. The ΔAIC summed over the
three cues is a descriptive combined score.

Head-to-head A6 vs B5 test: DV_c ~ both + A6_only + B5_only + controls, where `both` = designated by both rules.
A6_only tokens (almost all: the first syllable of all-reduced words) are stressed under A6 and unstressed under
B5, so their coefficient is the direct test: > 0 supports A6, ≈ 0 supports B5.
Rule-win stability: 200 bootstrap resamples of recordings within speaker, for the summed ΔAIC(A6 - B5).

Outputs (output/speaker_cues_2026-10-02/models/):
    speaker_rule_fits.csv      one row per speaker x rule x cue (estimate, SE, CI, AIC, dAIC)
    speaker_head_to_head.csv   A6_only / B5_only / both coefficients per speaker x cue
    speaker_bootstrap.csv      bootstrap share of resamples in which B5 beats A6, per speaker
    speaker_summary.csv        one row per speaker: n, discriminating n, best rule per cue, cue profile
"""
from __future__ import annotations

import os
import sys

import numpy as np
import pandas as pd
import statsmodels.api as sm

BASE = "/Users/kate/Documents/GitHub/phonology-chuvash/9-analyze/output/speaker_cues_2026-10-02"
OUT = f"{BASE}/models"
MIN_TOK, MIN_FILES, MIN_DISC_H2H, N_BOOT = 200, 10, 30, 200
RULES = ["A6", "A5", "A4", "B6", "B5", "B4", "SON_F", "SON_A", "SON_B"]
CTRL = ["syl1", "syl2", "word_final", "utt_final_word", "utt_final_syl"]
CUES = {"duration": "dur_c", "intensity": "int_c", "f0": "f0_c"}
LOAN_EXCLUDE = "--exclude-loans" in sys.argv
VOWEL_CTRL = "--vowel-ctrl" in sys.argv   # adds vowel-identity dummies: appropriate for the A6-vs-B5 contrast,
                                           # whose disputed syllables are reduced vowels under both rules
TAG = ("_noloans" if LOAN_EXCLUDE else "") + ("_vowelctrl" if VOWEL_CTRL else "")


def load() -> pd.DataFrame:
    v = pd.read_parquet(f"{OUT}/cache/model_frame.parquet")
    v = v[(v.sN >= 2) & (v.sN <= 6)].copy()
    if LOAN_EXCLUDE:
        lf = pd.read_csv(f"{BASE}/loan_lexicon/loan_flags_by_word.csv", usecols=["word_label", "loan_combined"])
        v = v.merge(lf, on="word_label", how="left")
        v = v[v.loan_combined.fillna(0).astype(int) == 0].copy()
    v["dur_c"] = v.log_duration - v.groupby("file_name").log_duration.transform("mean")
    v["f0_c"] = v.f0_st - v.groupby("file_name").f0_st.transform("mean")
    v = v.dropna(subset=["dur_c", "int_c", "f0_c"])
    for r in RULES:
        v[r] = (v[f"stress_rule_{r}"] == "Stressed").astype(int)
    v["both"] = v.A6 & v.B5
    v["A6_only"] = (v.A6 == 1) & (v.B5 == 0)
    v["B5_only"] = (v.B5 == 1) & (v.A6 == 0)
    for c in ["both", "A6_only", "B5_only"]:
        v[c] = v[c].astype(int)
    if VOWEL_CTRL:
        vd = pd.get_dummies(v.vowel_label, prefix="v", drop_first=True).astype(int)
        CTRL.extend(vd.columns.tolist()); v = pd.concat([v, vd], axis=1)
    return v


def ols(d: pd.DataFrame, y: str, xs: list[str]):
    X = sm.add_constant(d[xs].astype(float), has_constant="add")
    keep = X.columns[X.std() > 0].tolist()
    keep = ["const"] + [k for k in keep if k != "const"]
    m = sm.OLS(d[y].values, X[keep]).fit(cov_type="cluster", cov_kwds={"groups": d.word_label.astype("category").cat.codes})
    return m


def aic_only(d: pd.DataFrame, y: str, xs: list[str]) -> float:
    X = sm.add_constant(d[xs].astype(float), has_constant="add").values
    beta, *_ = np.linalg.lstsq(X, d[y].values, rcond=None)
    rss = float(((d[y].values - X @ beta) ** 2).sum()); n = len(d); k = X.shape[1] + 1
    return n * np.log(rss / n) + 2 * k


def main() -> None:
    v = load()
    g = v.groupby("spk").agg(n=("dur_c", "size"), n_files=("file_name", "nunique"),
                             n_A6_only=("A6_only", "sum"), n_B5_only=("B5_only", "sum"))
    spks = g[(g.n >= MIN_TOK) & (g.n_files >= MIN_FILES)].index.tolist()
    print(f"{len(spks)} speakers pass n>={MIN_TOK}, files>={MIN_FILES}; rows {len(v)}", flush=True)
    fits, h2h, boot = [], [], []
    rng = np.random.default_rng(20261002)
    for s in spks:
        d = v[v.spk == s]
        for cue, y in CUES.items():
            for r in RULES:
                m = ols(d, y, [r] + CTRL)
                b = m.params.get(r, np.nan); se = m.bse.get(r, np.nan)
                fits.append(dict(spk=s, cue=cue, rule=r, estimate=b, se=se, lo=b - 1.96 * se, hi=b + 1.96 * se,
                                 p=m.pvalues.get(r, np.nan), AIC=m.aic, n=len(d)))
            if g.loc[s, "n_A6_only"] >= MIN_DISC_H2H:
                m = ols(d, y, ["both", "A6_only", "B5_only"] + CTRL)
                for t in ["both", "A6_only", "B5_only"]:
                    if t in m.params:
                        h2h.append(dict(spk=s, cue=cue, term=t, estimate=m.params[t], se=m.bse[t],
                                        lo=m.params[t] - 1.96 * m.bse[t], hi=m.params[t] + 1.96 * m.bse[t],
                                        p=m.pvalues[t], n_term=int(d[t].sum())))
        if g.loc[s, "n_A6_only"] >= MIN_DISC_H2H:
            files = d.file_name.unique(); idx = {f: np.where(d.file_name.values == f)[0] for f in files}
            wins = []
            for _ in range(N_BOOT):
                take = np.concatenate([idx[f] for f in rng.choice(files, len(files), replace=True)])
                db = d.iloc[take]
                tot = sum(aic_only(db, y, ["A6"] + CTRL) - aic_only(db, y, ["B5"] + CTRL) for y in CUES.values())
                wins.append(tot)
            wins = np.array(wins)
            boot.append(dict(spk=s, n_boot=N_BOOT, share_B5_beats_A6=float((wins > 0).mean()),
                             median_dAIC_A6_minus_B5=float(np.median(wins))))
        print(s, len(d), flush=True)
    F = pd.DataFrame(fits)
    F["dAIC"] = F.AIC - F.groupby(["spk", "cue"]).AIC.transform("min")
    F.to_csv(f"{OUT}/speaker_rule_fits{TAG}.csv", index=False)
    pd.DataFrame(h2h).to_csv(f"{OUT}/speaker_head_to_head{TAG}.csv", index=False)
    pd.DataFrame(boot).to_csv(f"{OUT}/speaker_bootstrap{TAG}.csv", index=False)
    # summary
    rows = []
    for s in spks:
        f = F[F.spk == s]
        row = dict(spk=s, n=int(g.loc[s, "n"]), n_files=int(g.loc[s, "n_files"]),
                   n_A6_only=int(g.loc[s, "n_A6_only"]), n_B5_only=int(g.loc[s, "n_B5_only"]))
        tot = f.groupby("rule").dAIC.sum()
        row["best_rule_combined"] = tot.idxmin()
        row["dAIC_A6_minus_B5_combined"] = float(tot["A6"] - tot["B5"])
        for cue in CUES:
            fc = f[f.cue == cue].set_index("rule")
            row[f"best_rule_{cue}"] = fc.AIC.idxmin()
            row[f"dAIC_A6_minus_B5_{cue}"] = float(fc.loc["A6", "AIC"] - fc.loc["B5", "AIC"])
            for r in ["A6", "B5"]:
                row[f"{cue}_{r}_est"] = fc.loc[r, "estimate"]; row[f"{cue}_{r}_lo"] = fc.loc[r, "lo"]
                row[f"{cue}_{r}_hi"] = fc.loc[r, "hi"]
        rows.append(row)
    S = pd.DataFrame(rows)
    S.to_csv(f"{OUT}/speaker_summary{TAG}.csv", index=False)
    print("done", len(S))


if __name__ == "__main__":
    main()
