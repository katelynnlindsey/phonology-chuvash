#!/usr/bin/env python3
"""Vowel-space analyses that sit downstream of vowel_space.R.

Reads output/vowels_normalised.csv (Lobanov-normalised formants, one row per
vowel token) and writes the rounding, clustering, separability, apparent-time
and positional tables.  Everything here was previously run ad hoc; it is a
script so the numbers in the manuscript can be regenerated from one command.

Design notes that matter for reading the output:

* Rounding is tested as a *within-series* F3 difference against an unrounded
  anchor (/i/ for the front series, /a/ for the back), not as a global F3-F2
  ordering and not as a regression conditioning on F2 — F2 is a mediator of
  rounding, so conditioning on it would absorb the effect being measured.

* Separability is reported from two learners on identical samples.  A
  quadratic discriminant asks whether the two clouds are separable by a
  smooth quadratic boundary; gradient boosting asks whether *any* structure
  in the three formants separates them.  The second is systematically
  higher, and reporting only the first would overstate merger.

* The context analysis is cross-validated two ways.  A random split lets the
  same word type appear in train and test, so a model given the neighbouring
  segments can partly memorise words; grouping the folds by word type
  removes that route.  The grouped figure is the defensible one.  Both are
  printed because the earlier ad hoc run used a random split.

Usage:  python vowel_features.py --repo <path>
"""
import argparse, os, sys, warnings
import numpy as np
import pandas as pd
from sklearn.discriminant_analysis import QuadraticDiscriminantAnalysis
from sklearn.ensemble import HistGradientBoostingClassifier
from sklearn.mixture import GaussianMixture
from sklearn.metrics import adjusted_rand_score, balanced_accuracy_score
from sklearn.model_selection import StratifiedKFold, GroupKFold

warnings.filterwarnings("ignore")
RNG = 0
FULL = ["a", "e", "i", "u", "y"]
EIGHT = ["a", "e", "i", "u", "y", "ø", "ɵ", "ʉ"]
FRONT_SERIES = ["i", "y", "e", "ø"]      # anchored on /i/
BACK_SERIES = ["a", "u", "ɵ", "ʉ"]       # anchored on /a/
BACK_HARMONY = set("аӑуы")


def load(out):
    v = pd.read_csv(os.path.join(out, "vowels_normalised.csv"),
                    low_memory=False)
    v = v[v.vowel_label.isin(EIGHT)].copy()
    v = v.dropna(subset=["F1z", "F2z", "F3z"])
    return v


# ── 1. Rounding ───────────────────────────────────────────────────────
def rounding(v, out):
    np_ = v[v.non_palatal == True]
    rows = []
    for series, anchor in (("front", "i"), ("back", "a")):
        mem = FRONT_SERIES if series == "front" else BACK_SERIES
        a = np_[np_.vowel_label == anchor]
        for vw in mem:
            if vw == anchor:
                continue
            s = np_[np_.vowel_label == vw]
            if len(s) < 200:
                continue
            d3 = s.F3z.mean() - a.F3z.mean()
            d2 = s.F2z.mean() - a.F2z.mean()
            se3 = np.hypot(s.F3z.sem(), a.F3z.sem())
            rows.append(dict(series=series, anchor=anchor, vowel=vw, n=len(s),
                             dF3z=round(d3, 4), dF2z=round(d2, 4),
                             z_dF3=round(d3 / se3, 2),
                             verdict=("rounded" if d3 < -0.15 else
                                      "unrounded" if d3 > -0.05 else
                                      "intermediate")))
    r = pd.DataFrame(rows)

    # Positive control.  /u/ is rounded in every description of Chuvash and
    # in every Turkic language, so the back-series test has to detect it.  If
    # /u/'s F3 is not lower than /a/'s, F3 has no sensitivity on the back
    # series and a positive dF3z for /ɵ/ or /ʉ/ is not evidence that they are
    # unrounded.  F3 lowering is primarily a *front*-rounding cue: for back
    # vowels the rounding gesture shows up in F2, which is also where
    # backness shows up, so the two cannot be separated with these measures.
    ctl = r[(r.series == "back") & (r.vowel == "u")]
    front_ok = bool((r[(r.series == "front") &
                       (r.vowel == "y")].dF3z < -0.15).all())
    back_power = bool(len(ctl) and (ctl.dF3z < -0.15).all())
    r["test_has_power"] = np.where(r.series == "front", front_ok, back_power)
    r.to_csv(os.path.join(out, "rounding_contrasts.csv"), index=False)
    print("\n== rounding: within-series F3 vs unrounded anchor ==")
    print(r.to_string(index=False))
    print(f"\npositive control /u/ vs /a/: dF3z = "
          f"{ctl.dF3z.iloc[0] if len(ctl) else float('nan'):+.4f}  ->  "
          f"F3 {'does' if back_power else 'does NOT'} detect rounding on the "
          f"back series")
    if not back_power:
        print("  => the back-series rows are uninformative about rounding; "
              "report the front series only")

    # Back series positioned against /u/ as well, since /a/ alone cannot
    # anchor it.  This is descriptive placement, not a rounding verdict.
    u = np_[np_.vowel_label == "u"]
    brows = []
    for vw in ["ɵ", "ʉ", "a"]:
        s = np_[np_.vowel_label == vw]
        if len(s) < 200:
            continue
        brows.append(dict(vowel=vw, n=len(s),
                          dF1z_vs_u=round(s.F1z.mean() - u.F1z.mean(), 4),
                          dF2z_vs_u=round(s.F2z.mean() - u.F2z.mean(), 4),
                          dF3z_vs_u=round(s.F3z.mean() - u.F3z.mean(), 4)))
    b = pd.DataFrame(brows)
    b.to_csv(os.path.join(out, "back_series_placement.csv"), index=False)
    print("\n== back series placed against /u/ (descriptive) ==")
    print(b.to_string(index=False))

    # Rounding under stress, for the grammars' claim that the reduced
    # vowels round when stressed.
    rows = []
    for vw in ["ø", "ɵ", "ʉ"]:
        s = np_[np_.vowel_label == vw]
        st = s[s.stress_rule_A6 == "Stressed"]
        un = s[s.stress_rule_A6 == "Unstressed"]
        if min(len(st), len(un)) < 200:
            continue
        d3 = st.F3z.mean() - un.F3z.mean()
        d2 = st.F2z.mean() - un.F2z.mean()
        se = np.hypot(st.F3z.sem(), un.F3z.sem())
        ser = "front" if vw == "ø" else "back"
        rows.append(dict(vowel=vw, series=ser,
                         n_stressed=len(st), n_unstressed=len(un),
                         dF3z=round(d3, 4), dF2z=round(d2, 4),
                         z_dF3=round(d3 / se, 2),
                         # F3 only diagnoses rounding on the front series
                         # (see the positive-control check above), so the
                         # back-series rows get a backness reading, not a
                         # rounding one.
                         rounding_reading=(
                             ("rounds under stress" if d3 < -0.1 else
                              "no rounding change") if ser == "front"
                             else "not determinable from F3"),
                         f2_reading=("lower F2 under stress" if d2 < -0.1 else
                                     "higher F2 under stress" if d2 > 0.1
                                     else "no F2 change")))
    rs = pd.DataFrame(rows)
    rs.to_csv(os.path.join(out, "rounding_by_stress.csv"), index=False)
    print("\n== rounding under stress (rule A6) ==")
    print(rs.to_string(index=False))


# ── 2. Clustering ─────────────────────────────────────────────────────
def clustering(v, out, n=60000):
    res = []
    for ctx, sub in (("non_palatal", v[v.non_palatal == True]), ("all", v)):
        s = sub.sample(min(n, len(sub)), random_state=RNG)
        X = s[["F1z", "F2z", "F3z"]].values
        y = s.vowel_label.values
        for k in range(2, 13):
            gm = GaussianMixture(k, covariance_type="full", random_state=RNG,
                                 n_init=2).fit(X)
            lab = gm.predict(X)
            res.append(dict(context=ctx, k=k, BIC=round(gm.bic(X), 1),
                            ARI_vs_phonemic=round(adjusted_rand_score(y, lab), 4),
                            n=len(s)))
    c = pd.DataFrame(res)
    c.to_csv(os.path.join(out, "clustering_comparison.csv"), index=False)
    print("\n== clustering: BIC and agreement with the phonemic eight ==")
    print(c.pivot(index="k", columns="context",
                  values="ARI_vs_phonemic").to_string())
    best = c[c.context == "non_palatal"].sort_values("ARI_vs_phonemic").iloc[-1]
    print(f"peak agreement at k={int(best.k)} (ARI {best.ARI_vs_phonemic})")

    # Which phonemes merge at the peak k: the confusion table.
    s = v[v.non_palatal == True].sample(min(n, (v.non_palatal == True).sum()),
                                        random_state=RNG)
    gm = GaussianMixture(int(best.k), covariance_type="full",
                         random_state=RNG, n_init=2).fit(
                             s[["F1z", "F2z", "F3z"]].values)
    s = s.assign(cluster=gm.predict(s[["F1z", "F2z", "F3z"]].values))
    conf = (pd.crosstab(s.vowel_label, s.cluster, normalize="index")
              .round(3).reindex(EIGHT))
    conf.to_csv(os.path.join(out, "clustering_confusion.csv"))
    print(f"\n== cluster membership at k={int(best.k)} (row-normalised) ==")
    print(conf.to_string())
    return int(best.k)


# ── 3. Pairwise separability, two learners, same samples ──────────────
def separability(v, out, n=20000):
    pairs = [("i", "y"), ("ʉ", "ɵ"), ("e", "ø"), ("u", "ʉ"), ("a", "e")]
    np_ = v[v.non_palatal == True]
    rows = []
    for p in pairs:
        s = np_[np_.vowel_label.isin(p)]
        if len(s) > n:
            s = s.sample(n, random_state=RNG)
        X = s[["F1z", "F2z", "F3z"]].values
        y = (s.vowel_label == p[1]).astype(int).values
        if y.sum() < 50 or (1 - y).sum() < 50:
            continue
        cv = StratifiedKFold(5, shuffle=True, random_state=RNG)
        sc = {}
        for name, mk in (("qda", lambda: QuadraticDiscriminantAnalysis()),
                         ("boosting",
                          lambda: HistGradientBoostingClassifier(
                              random_state=RNG))):
            accs = []
            for tr, te in cv.split(X, y):
                m = mk().fit(X[tr], y[tr])
                accs.append(balanced_accuracy_score(y[te], m.predict(X[te])))
            sc[name] = round(float(np.mean(accs)), 3)
        rows.append(dict(pair=f"{p[0]} vs {p[1]}", n=len(s),
                         qda=sc["qda"], boosting=sc["boosting"],
                         gain=round(sc["boosting"] - sc["qda"], 3)))
    d = pd.DataFrame(rows)
    d.to_csv(os.path.join(out, "separability_classifier_comparison.csv"),
             index=False)
    print("\n== pairwise separability, identical samples and formants ==")
    print(d.to_string(index=False))
    print("chance = 0.500")


# ── 4. Contrast recovery from context ─────────────────────────────────
def contrast_recovery(v, out, n=40000):
    np_ = v[v.non_palatal == True].dropna(subset=["pre_seg", "fol_seg"])
    s = np_.sample(min(n, len(np_)), random_state=RNG).copy()
    s["harm"] = s.word_label.astype(str).apply(
        lambda w: int(any(ch in BACK_HARMONY for ch in w)))
    for c in ("pre_seg", "fol_seg"):
        s[c + "_code"] = s[c].astype("category").cat.codes
    y = s.vowel_label.values
    groups = s.word_label.astype(str).values
    sets = {
        "formants only (F1 F2 F3)": ["F1z", "F2z", "F3z"],
        "+ duration": ["F1z", "F2z", "F3z", "log_duration"],
        "+ neighbouring segments": ["F1z", "F2z", "F3z", "log_duration",
                                    "pre_seg_code", "fol_seg_code"],
        "+ word harmony class": ["F1z", "F2z", "F3z", "log_duration",
                                 "pre_seg_code", "fol_seg_code", "harm"],
    }
    pair_masks = {"all eight": np.ones(len(s), bool),
                  "/i/ vs /y/": s.vowel_label.isin(["i", "y"]).values,
                  "/ʉ/ vs /ɵ/": s.vowel_label.isin(["ʉ", "ɵ"]).values}
    rows = []
    for fname, cols in sets.items():
        X = s[cols].values
        for split in ("random", "grouped_by_word"):
            rec = {"features": fname, "cv": split}
            for pname, mask in pair_masks.items():
                Xi, yi, gi = X[mask], y[mask], groups[mask]
                if len(np.unique(yi)) < 2 or len(yi) < 200:
                    rec[pname] = np.nan
                    continue
                if split == "random":
                    folds = StratifiedKFold(
                        5, shuffle=True, random_state=RNG).split(Xi, yi)
                else:
                    ng = min(5, len(np.unique(gi)))
                    folds = GroupKFold(ng).split(Xi, yi, gi)
                accs = []
                for tr, te in folds:
                    if len(np.unique(yi[tr])) < 2:
                        continue
                    m = HistGradientBoostingClassifier(
                        random_state=RNG).fit(Xi[tr], yi[tr])
                    accs.append(balanced_accuracy_score(yi[te],
                                                        m.predict(Xi[te])))
                rec[pname] = round(float(np.mean(accs)), 3) if accs else np.nan
            rec["n"] = len(s)
            rows.append(rec)
    d = pd.DataFrame(rows)
    d.to_csv(os.path.join(out, "separability_with_context.csv"), index=False)
    print("\n== contrast recovery (balanced accuracy; chance 0.125 / 0.500) ==")
    print(d.to_string(index=False))


# ── 5. Apparent time and gender ───────────────────────────────────────
def shift(v, out):
    import statsmodels.formula.api as smf
    rows = []
    cv = v[(v.corpus == "common_voice_chuvash") & v.age.notna()]
    agemap = {"teens": 15, "twenties": 25, "thirties": 35, "fourties": 45,
              "forties": 45, "fifties": 55, "sixties": 65, "seventies": 75}
    cv = cv.assign(age_num=cv.age.map(agemap)).dropna(subset=["age_num"])
    for vw in EIGHT:
        s = cv[cv.vowel_label == vw]
        if s.speaker.nunique() < 8:
            continue
        for dv in ("F1z", "F2z"):
            try:
                m = smf.mixedlm(f"{dv} ~ age_num", s, groups=s.speaker).fit()
                rows.append(dict(model="apparent_time", vowel=vw, dv=dv,
                                 term="age_num",
                                 estimate=round(m.params["age_num"], 5),
                                 z=round(m.tvalues["age_num"], 2),
                                 p=round(m.pvalues["age_num"], 4),
                                 n=len(s), speakers=s.speaker.nunique()))
            except Exception:
                pass
    cg = v[(v.corpus == "common_voice_chuvash") &
           v.gender.isin(["male_masculine", "female_feminine",
                          "male", "female"])]
    for vw in EIGHT:
        s = cg[cg.vowel_label == vw]
        if s.speaker.nunique() < 8:
            continue
        s = s.assign(fem=s.gender.str.startswith("female").astype(int))
        for dv in ("F1z", "F2z"):
            try:
                m = smf.mixedlm(f"{dv} ~ fem", s, groups=s.speaker).fit()
                rows.append(dict(model="gender", vowel=vw, dv=dv, term="fem",
                                 estimate=round(m.params["fem"], 4),
                                 z=round(m.tvalues["fem"], 2),
                                 p=round(m.pvalues["fem"], 4),
                                 n=len(s), speakers=s.speaker.nunique()))
            except Exception:
                pass
    d = pd.DataFrame(rows)
    d.to_csv(os.path.join(out, "vowel_shift_models.csv"), index=False)
    print("\n== apparent time and gender ==")
    for mdl in d.model.unique():
        sub = d[d.model == mdl]
        print(f"{mdl}: {int((sub.p < .05).sum())} of {len(sub)} coefficients p<0.05; "
              f"|estimate| range {sub.estimate.abs().min():.4f}-{sub.estimate.abs().max():.4f}")
    print(d.to_string(index=False))


# ── 6. Positional restriction ─────────────────────────────────────────
def positional(v, out):
    s = v.copy()
    s["pos"] = np.where(s.sN == 1, "only",
                np.where(s.sidx == 1, "initial",
                np.where(s.sidx == s.sN, "final", "medial")))
    obs = pd.crosstab(s.vowel_label, s.pos)
    exp = np.outer(obs.sum(1), obs.sum(0)) / obs.values.sum()
    oe = (obs / exp).round(3).reindex(EIGHT)
    poly = s[s.sN > 1]
    first = (poly.assign(f=(poly.sidx == 1).astype(int))
                 .groupby("vowel_label").f.mean().mul(100).round(1))
    closed = (s.assign(c=(s.syllable_coda.astype(str)
                          .str.lower().isin(["closed", "true", "1"])).astype(int))
                .groupby("vowel_label").c.mean().mul(100).round(1))
    d = oe.join(first.rename("pct_polysyll_in_syl1")).join(
        closed.rename("pct_closed")).join(
        s.vowel_label.value_counts().rename("n"))
    d.to_csv(os.path.join(out, "positional_restrictions.csv"))
    print("\n== positional restriction (observed/expected) ==")
    print(d.to_string())


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--repo", required=True)
    ap.add_argument("--only", default=None,
                    help="comma-separated subset of section names")
    a = ap.parse_args()
    out = os.path.join(a.repo, "9-analyze", "output")
    v = load(out)
    print(f"vowels_normalised.csv: {len(v):,} rows, "
          f"{int((v.non_palatal == True).sum()):,} non-palatal, "
          f"{v.speaker.nunique()} speakers")
    todo = (a.only.split(",") if a.only else
            ["rounding", "clustering", "separability", "context", "shift",
             "positional"])
    if "rounding" in todo:     rounding(v, out)
    if "clustering" in todo:   clustering(v, out)
    if "separability" in todo: separability(v, out)
    if "context" in todo:      contrast_recovery(v, out)
    if "shift" in todo:        shift(v, out)
    if "positional" in todo:   positional(v, out)
    print("\nvowel_features.py complete")


if __name__ == "__main__":
    sys.exit(main())
