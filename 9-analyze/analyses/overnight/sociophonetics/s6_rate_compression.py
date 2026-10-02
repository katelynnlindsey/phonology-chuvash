# overnight/sociophonetics/s6_rate_compression.py
# RATE: log_span_rate = (n vowels - 1) / (last vowel end - first vowel start) per file (excludes clip-edge silence);
#       log_speech_rate = pipeline column (surviving vowels / whole clip duration). Run both.
# Step 6: do reduced vowels compress more than full vowels as speech rate rises?
# Per speaker (CV speakers, CH voice clusters): OLS log_duration ~ C(vowel_label) + rate_c * reduced
#   + stressed_A6 + C(phrase_position) + C(syllable_coda) + z_relpos, rate_c = log_speech_rate centred
#   within speaker (utterance-to-utterance tempo variation), HC1 SEs; non-outlier-duration rows.
# Elasticities: slope_full = d log dur / d log rate for full vowels; slope_reduced = slope_full + interaction.
# Heterogeneity (DerSimonian-Laird) and meta-regression of the interaction on voice group / age / corpus.
import sys
RATE = sys.argv[1] if len(sys.argv) > 1 else "log_span_rate"   # or log_speech_rate (pipeline: surviving vowels / clip duration)
import pandas as pd, numpy as np, statsmodels.formula.api as smf
from scipy import stats
OUT = "/Users/kate/Documents/GitHub/phonology-chuvash/9-analyze/output/overnight_2026-10-01/sociophonetics"
d = pd.read_parquet(OUT + "/cache/model_data.parquet")
d = d[~d.iqr_outlier_any & d.log_duration.notna() & d[RATE].notna()].copy()
d["reduced"] = (d.vowel_class == "reduced").astype(int)
d["stressed"] = (d.stress_rule_A6 == "Stressed").astype(int)
d["rate_c"] = d[RATE] - d.groupby("spk")[RATE].transform("mean")
spk = pd.read_csv(OUT + "/s1_speaker_table.csv").set_index("spk")
rows = []
for s, g in d.groupby("spk"):
    if g.reduced.sum() < 30 or (1 - g.reduced).sum() < 60 or g.file_name.nunique() < 8 or g.rate_c.std() < 0.05:
        continue
    m = smf.ols("log_duration ~ C(vowel_label) + rate_c * reduced + stressed + C(phrase_position) + C(syllable_coda) + z_relpos", g).fit(cov_type="HC1")
    V = m.cov_params()
    rows.append(dict(spk=s, n_tokens=len(g), n_reduced=int(g.reduced.sum()), n_files=g.file_name.nunique(), sd_rate=g.rate_c.std(),
                     slope_full=m.params["rate_c"], se_full=m.bse["rate_c"],
                     slope_reduced=m.params["rate_c"] + m.params["rate_c:reduced"],
                     se_reduced=np.sqrt(V.loc["rate_c", "rate_c"] + V.loc["rate_c:reduced", "rate_c:reduced"] + 2 * V.loc["rate_c", "rate_c:reduced"]),
                     interaction=m.params["rate_c:reduced"], se_int=m.bse["rate_c:reduced"]))
r = pd.DataFrame(rows).join(spk[["corpus", "gender_metadata", "age_metadata", "f0_median_Hz"]], on="spk")
r.to_csv(OUT + f"/s6_speaker_rate_slopes_{RATE}.csv", index=False)
def dl(y, se):
    w = 1 / se**2; mu = (w * y).sum() / w.sum(); Q = (w * (y - mu)**2).sum(); k = len(y)
    tau2 = max(0, (Q - (k - 1)) / (w.sum() - (w**2).sum() / w.sum())); ws = 1 / (se**2 + tau2)
    mur = (ws * y).sum() / ws.sum(); ser = np.sqrt(1 / ws.sum())
    return dict(k=k, mean_RE=mur, lo=mur - 1.96 * ser, hi=mur + 1.96 * ser, tau=np.sqrt(tau2), I2=max(0, (Q - (k - 1)) / Q),
                n_neg_sig=int(((y + 1.96 * se) < 0).sum()), n_pos_sig=int(((y - 1.96 * se) > 0).sum())), tau2
agek = {"teens": 1, "twenties": 2, "thirties": 3, "fourties": 4, "fifties": 5}
out = []
for scope, g in [("all speakers", r), ("CV only", r[r.corpus == "common_voice_chuvash"]), ("excluding voice_main", r[r.spk != "chv_voice_main"])]:
    for term, se in [("slope_full", "se_full"), ("slope_reduced", "se_reduced"), ("interaction", "se_int")]:
        res, tau2 = dl(g[term].values, g[se].values)
        row = dict(scope=scope, term=term, **res)
        if term == "interaction":
            gg = g.assign(highf0=(g.f0_median_Hz >= 175).astype(int), age_dec=g.age_metadata.map(agek),
                          is_ch=(g.corpus == "chuvash_voice").astype(int), w=1 / (g[se]**2 + tau2))
            m = smf.wls("interaction ~ highf0", gg, weights=gg.w).fit()
            row.update(highf0_coef=m.params["highf0"], highf0_lo=m.conf_int().loc["highf0", 0], highf0_hi=m.conf_int().loc["highf0", 1], highf0_p=m.pvalues["highf0"])
            ga = gg.dropna(subset=["age_dec"])
            if len(ga) >= 8:
                m2 = smf.wls("interaction ~ age_dec + highf0", ga, weights=ga.w).fit()
                row.update(n_age=len(ga), age_coef=m2.params["age_dec"], age_lo=m2.conf_int().loc["age_dec", 0], age_hi=m2.conf_int().loc["age_dec", 1], age_p=m2.pvalues["age_dec"])
            if scope == "all speakers":
                m3 = smf.wls("interaction ~ is_ch", gg, weights=gg.w).fit()
                row.update(CH_coef=m3.params["is_ch"], CH_lo=m3.conf_int().loc["is_ch", 0], CH_hi=m3.conf_int().loc["is_ch", 1], CH_p=m3.pvalues["is_ch"])
        out.append(row)
out = pd.DataFrame(out); out.to_csv(OUT + f"/s6_rate_compression_summary_{RATE}.csv", index=False)
print(out.round(3).to_string())
print(r[r.spk == "chv_voice_main"].round(3).to_string())
