# overnight/sociophonetics/s5_cue_weighting.py
# Step 5: per-speaker stress-cue slopes (duration, int_midpoint, f0_st) and their heterogeneity.
# Per speaker: OLS of the DV centred within file_name on is_stressed (A6 or B5) + vowel_label +
# syllable_coda + phrase_position + z_relpos, HC1 SEs. Heterogeneity: DerSimonian-Laird tau and I^2.
# Meta-regression of slopes on high-f0 voice (f0 >= 175 Hz) and age decade (CV metadata).
import pandas as pd, numpy as np, statsmodels.formula.api as smf
from scipy import stats
OUT = "/Users/kate/Documents/GitHub/phonology-chuvash/9-analyze/output/overnight_2026-10-01/sociophonetics"
d = pd.read_parquet(OUT + "/cache/model_data.parquet")
spk = pd.read_csv(OUT + "/s1_speaker_table.csv").set_index("spk")
for dv in ["log_duration", "int_midpoint", "f0_st"]:
    d[dv + "_c"] = d[dv] - d.groupby("file_name")[dv].transform("mean")
rows = []
for rule in ["A6", "B5"]:
    d["st"] = (d["stress_rule_" + rule] == "Stressed").astype(int)
    for s, g in d.groupby("spk"):
        ns, nu = g.st.sum(), (1 - g.st).sum()
        if ns < 30 or nu < 30 or g.file_name.nunique() < 5:
            continue
        for dv in ["log_duration", "int_midpoint", "f0_st"]:
            gg = g.dropna(subset=[dv + "_c"])
            try:
                m = smf.ols(f"{dv}_c ~ st + C(vowel_label) + C(syllable_coda) + C(phrase_position) + z_relpos", gg).fit(cov_type="HC1")
                rows.append(dict(rule=rule, spk=s, dv=dv, slope=m.params["st"], se=m.bse["st"], n_tokens=len(gg),
                                 n_stressed=int(gg.st.sum()), n_files=gg.file_name.nunique()))
            except Exception as e:
                print("fail", rule, s, dv, e)
sl = pd.DataFrame(rows)
sl = sl.join(spk[["corpus", "gender_metadata", "age_metadata", "f0_median_Hz"]], on="spk")
sl.to_csv(OUT + "/s5_speaker_slopes.csv", index=False)

def dl(y, se):
    w = 1 / se**2; mu = (w * y).sum() / w.sum(); Q = (w * (y - mu)**2).sum(); k = len(y)
    tau2 = max(0, (Q - (k - 1)) / (w.sum() - (w**2).sum() / w.sum()))
    ws = 1 / (se**2 + tau2); mur = (ws * y).sum() / ws.sum(); ser = np.sqrt(1 / ws.sum())
    return dict(k=k, mean_RE=mur, mean_RE_lo=mur - 1.96 * ser, mean_RE_hi=mur + 1.96 * ser, tau=np.sqrt(tau2),
                I2=max(0, (Q - (k - 1)) / Q) if Q > 0 else 0, Q_p=1 - stats.chi2.cdf(Q, k - 1),
                n_pos_sig=int(((y - 1.96 * se) > 0).sum()), n_neg_sig=int(((y + 1.96 * se) < 0).sum()),
                pred_interval_lo=mur - 1.96 * np.sqrt(tau2 + ser**2), pred_interval_hi=mur + 1.96 * np.sqrt(tau2 + ser**2))
het = []
agek = {"teens": 1, "twenties": 2, "thirties": 3, "fourties": 4, "fifties": 5}
for (rule, dv), g in sl.groupby(["rule", "dv"]):
    for scope, gg in [("all speakers", g), ("CV only", g[g.corpus == "common_voice_chuvash"])]:
        r = dict(rule=rule, dv=dv, scope=scope, **dl(gg.slope.values, gg.se.values))
        gg = gg.assign(highf0=(gg.f0_median_Hz >= 175).astype(int), age_dec=gg.age_metadata.map(agek), w=1 / (gg.se**2 + r["tau"]**2))
        m = smf.wls("slope ~ highf0", gg, weights=gg.w).fit()
        r.update(highf0_coef=m.params["highf0"], highf0_lo=m.conf_int().loc["highf0", 0], highf0_hi=m.conf_int().loc["highf0", 1], highf0_p=m.pvalues["highf0"])
        ga = gg.dropna(subset=["age_dec"])
        if len(ga) >= 8:
            m2 = smf.wls("slope ~ age_dec + highf0", ga, weights=ga.w).fit()
            r.update(n_age=len(ga), age_coef=m2.params["age_dec"], age_lo=m2.conf_int().loc["age_dec", 0], age_hi=m2.conf_int().loc["age_dec", 1], age_p=m2.pvalues["age_dec"])
        het.append(r)
het = pd.DataFrame(het); het.to_csv(OUT + "/s5_cue_heterogeneity.csv", index=False)
# cross-cue correlation of speaker slopes and three-cue agreement
for rule in ["A6", "B5"]:
    w = sl[sl.rule == rule].pivot(index="spk", columns="dv", values="slope").dropna()
    sw = sl[sl.rule == rule].pivot(index="spk", columns="dv", values="se").reindex(w.index)
    print(rule, "n speakers with all three:", len(w))
    print(w.corr(method="spearman").round(3))
    allpos = ((w - 1.96 * sw) > 0).all(1).sum(); allpos_pt = (w > 0).all(1).sum()
    print("all three positive (point):", allpos_pt, " all three sig positive:", allpos)
    w.assign(**{c + "_se": sw[c] for c in sw.columns}).to_csv(OUT + f"/s5_speaker_slopes_wide_{rule}.csv")
print(het[["rule", "dv", "scope", "k", "mean_RE", "mean_RE_lo", "mean_RE_hi", "tau", "I2", "n_pos_sig", "n_neg_sig", "highf0_coef", "highf0_p", "n_age", "age_coef", "age_lo", "age_hi", "age_p"]].round(3).to_string())
