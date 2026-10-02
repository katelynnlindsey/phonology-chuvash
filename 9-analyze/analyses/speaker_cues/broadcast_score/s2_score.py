# speaker_cues/broadcast_score/s2_score.py                              2026-10-02
#
# Composite broadcast-likeness score from s1 per-file metrics.
#   1. orient each of 9 metrics so that higher = more broadcast-like (Kate's description of voice_main:
#      fast, even rhythm, little f0 variance, very low boundary tones, possibly limited phonation)
#   2. winsorise at the 1st/99th percentile of scorable files (heavy tails: span rate on short spans,
#      f0_undef_share zero-inflated), z-score across ALL scorable files of both corpora
#   3. broadcast_score = mean of available oriented z (>= MIN_METRICS of 9 present, else NA)
#   4. pc1 = first principal component of the 9 oriented z (fitted on complete cases; files with a missing
#      metric are projected with that z set to 0 = pooled mean); sign fixed so corr(pc1, score) > 0
#   Same recipe on odd-word metrics -> broadcast_score_odd (and even-word -> split-half diagnostic).
import numpy as np, pandas as pd

B = "/Users/kate/Documents/GitHub/phonology-chuvash/9-analyze/"
OUT = B + "output/speaker_cues_2026-10-02/broadcast_score/"
RAW = "/Users/kate/Documents/GitHub/phonology-chuvash/1-raw_data/"
MIN_V, MIN_METRICS = 6, 6
ORIENT = {'f0_sd_nonfinal_st': -1, 'f0_range_nonfinal_st': -1}
ORIENT.update({'rate': +1, 'npvi_v': -1, 'cv_dur': -1, 'f0_sd_st': -1, 'f0_range_st': -1,
          'final_f0_rel': -1, 'final_int_rel': -1, 'vf_fullV': -1, 'f0_undef_share': +1})
M = [m for m in ORIENT if 'nonfinal' not in m]
# sensitivity: f0 variability measured without the utterance-final word (removes the mechanical coupling
# between a deep final fall and a large file f0 SD/range)
M_ALT = [m.replace('f0_sd_st', 'f0_sd_nonfinal_st').replace('f0_range_st', 'f0_range_nonfinal_st') for m in M]
VM = 'chv_voice_main'


def score(df, M=M):
    d = df[df.n_vowels >= MIN_V]
    Z = pd.DataFrame(index=df.index, columns=M, dtype=float)
    wins = {}
    for m in M:
        lo, hi = d[m].quantile([.01, .99])
        x = df[m].clip(lo, hi) * ORIENT[m]
        x[df.n_vowels < MIN_V] = np.nan
        mu, sd = x.mean(), x.std()
        Z[m] = (x - mu) / sd
        wins[m] = (lo, hi, mu, sd)
    nm = Z.notna().sum(1)
    s = Z.mean(1)
    s[nm < MIN_METRICS] = np.nan
    # PCA on complete cases
    cc = Z.dropna()
    C = np.corrcoef(cc.values.T)
    evals, evecs = np.linalg.eigh(C)
    o = np.argsort(evals)[::-1]
    evals, evecs = evals[o], evecs[:, o]
    load = evecs[:, 0]
    pc1 = Z.fillna(0).values @ load
    pc1 = pd.Series(pc1, index=df.index)
    pc1[nm < MIN_METRICS] = np.nan
    if np.corrcoef(pc1.dropna(), s[pc1.notna()])[0, 1] < 0:
        load, pc1 = -load, -pc1
    return Z, s, nm, pc1, load, evals, len(cc), wins


full = pd.read_csv(OUT + 's1_metrics_full.csv')
odd = pd.read_csv(OUT + 's1_metrics_odd.csv')
even = pd.read_csv(OUT + 's1_metrics_even.csv')

Zf, sf, nmf, pc1f, loadf, evf, ncc, winsf = score(full)
full['n_metrics'] = nmf
full['broadcast_score'] = sf
full['pc1'] = pc1f
Zo, so, nmo, pc1o, loado, evo, ncco, _ = score(odd)
Ze, se, nme, _, _, _, _, _ = score(even)
odd['broadcast_score_odd'] = so
odd['n_metrics_odd'] = nmo
even['broadcast_score_even'] = se
full = full.merge(odd[['file_name', 'broadcast_score_odd', 'n_metrics_odd', 'n_vowels']].rename(columns={'n_vowels': 'n_vowels_odd'}),
                  on='file_name', how='left')
full = full.merge(even[['file_name', 'broadcast_score_even']], on='file_name', how='left')
Za, sa, nma, pc1a, loada, eva, ncca, _ = score(full, M_ALT)
full['broadcast_score_alt'] = sa
full['pc1_alt'] = pc1a
pd.DataFrame({'metric': M_ALT, 'pc1_loading_alt': loada}).to_csv(OUT + 's2_pc1_loadings_alt.csv', index=False)
pd.DataFrame({'component': np.arange(1, len(eva) + 1), 'eigenvalue': eva, 'var_share': eva / eva.sum()}).to_csv(OUT + 's2_pca_eigenvalues_alt.csv', index=False)
Za.corr().round(3).to_csv(OUT + 's2_metric_intercorrelations_alt.csv')
full['broadcast_score_within_spk'] = full.broadcast_score - full.groupby('spk').broadcast_score.transform('mean')

# ---- PCA / weights table --------------------------------------------------------
pca = pd.DataFrame({'metric': M, 'orientation': [ORIENT[m] for m in M], 'pc1_loading': loadf,
                    'pc1_loading_odd': loado,
                    'r_with_score': [np.corrcoef(*full[[m, 'broadcast_score']].dropna().values.T)[0, 1] * ORIENT[m] for m in M],
                    'winsor_lo': [winsf[m][0] for m in M], 'winsor_hi': [winsf[m][1] for m in M]})
pca.to_csv(OUT + 's2_pc1_loadings.csv', index=False)
ev = pd.DataFrame({'component': np.arange(1, len(evf) + 1), 'eigenvalue': evf, 'var_share': evf / evf.sum()})
ev.to_csv(OUT + 's2_pca_eigenvalues.csv', index=False)

# ---- intercorrelations (oriented z, pairwise complete) ---------------------------------
Zf.corr().round(3).to_csv(OUT + 's2_metric_intercorrelations.csv')
Zf.corr(method='spearman').round(3).to_csv(OUT + 's2_metric_intercorrelations_spearman.csv')

sc = full[full.broadcast_score.notna()].copy()
med = sc.broadcast_score.median()

# ---- validation summary ---------------------------------------------------------------
def r(a, b, d=sc, method='pearson'):
    x = d[[a, b]].dropna()
    return x[a].corr(x[b], method=method), len(x)


def eta2(d, col, grp):
    d = d[[col, grp]].dropna()
    gm = d.groupby(grp)[col].transform('mean')
    return ((gm - d[col].mean()) ** 2).sum() / ((d[col] - d[col].mean()) ** 2).sum()


val = []
for lab, d in [('all', sc), ('chuvash_voice', sc[sc.corpus == 'chuvash_voice']),
               ('common_voice_chuvash', sc[sc.corpus == 'common_voice_chuvash']), ('voice_main', sc[sc.spk == VM]),
               ('CH_other_voices', sc[(sc.corpus == 'chuvash_voice') & (sc.spk != VM)])]:
    for a, b in [('broadcast_score', 'pc1'), ('broadcast_score', 'broadcast_score_odd'),
                 ('broadcast_score', 'broadcast_score_alt'), ('broadcast_score_alt', 'pc1_alt'),
                 ('broadcast_score_odd', 'broadcast_score_even')]:
        for meth in ['pearson', 'spearman']:
            rr, n = r(a, b, d, meth)
            val.append({'subset': lab, 'x': a, 'y': b, 'method': meth, 'r': rr, 'n_files': n})
vd = pd.DataFrame(val)
# Spearman-Brown corrected split-half reliability
sh = vd[(vd.x == 'broadcast_score_odd') & (vd.y == 'broadcast_score_even') & (vd.method == 'pearson')].copy()
sh['x'], sh['y'], sh['method'] = 'split_half', 'spearman_brown', 'pearson'
sh['r'] = 2 * sh.r / (1 + sh.r)
vd = pd.concat([vd, sh])
vd.to_csv(OUT + 's2_validation_correlations.csv', index=False)

# variance shares
vs = []
for lab, d in [('all', sc), ('chuvash_voice', sc[sc.corpus == 'chuvash_voice']), ('common_voice_chuvash', sc[sc.corpus == 'common_voice_chuvash'])]:
    for col in ['broadcast_score', 'broadcast_score_odd', 'broadcast_score_alt'] + M_ALT[3:5] + M:
        z = d.copy()
        vs.append({'subset': lab, 'variable': col, 'eta2_speaker': eta2(z, col, 'spk'),
                   'eta2_corpus': eta2(z, col, 'corpus') if lab == 'all' else np.nan,
                   'n_files': z[col].notna().sum(), 'n_speakers': z.loc[z[col].notna(), 'spk'].nunique()})
pd.DataFrame(vs).to_csv(OUT + 's2_variance_shares.csv', index=False)

# ---- distributions by corpus and speaker -----------------------------------------------
def wilson(k, n, z=1.96):
    if n == 0:
        return np.nan, np.nan
    p = k / n
    c = (p + z * z / (2 * n)) / (1 + z * z / n)
    h = z * np.sqrt(p * (1 - p) / n + z * z / (4 * n * n)) / (1 + z * z / n)
    return c - h, c + h


def summ(d):
    k = (d.broadcast_score > med).sum(); n = len(d)
    lo, hi = wilson(k, n)
    se = d.broadcast_score.std() / np.sqrt(n) if n > 1 else np.nan
    return pd.Series({'n_files': n, 'n_vowels': d.n_vowels.sum(), 'mean': d.broadcast_score.mean(),
                      'mean_ci_lo': d.broadcast_score.mean() - 1.96 * se, 'mean_ci_hi': d.broadcast_score.mean() + 1.96 * se,
                      'q10': d.broadcast_score.quantile(.1), 'q25': d.broadcast_score.quantile(.25),
                      'median': d.broadcast_score.median(), 'q75': d.broadcast_score.quantile(.75),
                      'q90': d.broadcast_score.quantile(.9), 'share_above_pooled_median': k / n,
                      'share_ci_lo': lo, 'share_ci_hi': hi, 'median_odd': d.broadcast_score_odd.median()})


bc = sc.groupby('corpus').apply(summ, include_groups=False).reset_index()
bc = pd.concat([bc, pd.DataFrame([dict(corpus='CH_voice_main', **summ(sc[sc.spk == VM])),
                                  dict(corpus='CH_other_voices', **summ(sc[(sc.corpus == 'chuvash_voice') & (sc.spk != VM)]))])])
bc['pooled_median'] = med
bc.to_csv(OUT + 's2_score_by_corpus.csv', index=False)
bs = sc.groupby(['spk', 'corpus']).apply(summ, include_groups=False).reset_index().sort_values('median', ascending=False)
bs['rank_by_median_among_spk_ge20files'] = np.nan
m20 = bs.n_files >= 20
bs.loc[m20, 'rank_by_median_among_spk_ge20files'] = bs.loc[m20, 'median'].rank(ascending=False)
bs.to_csv(OUT + 's2_score_by_speaker.csv', index=False)

# per-metric medians by group (raw units)
grp = np.where(sc.spk == VM, 'CH_voice_main', np.where(sc.corpus == 'chuvash_voice', 'CH_other_voices', 'CV'))
mg = sc.assign(group=grp).groupby('group')[M + ['pause_f0_rel', 'pause_int_rel', 'hnr']].median().T
mg.index.name = 'metric'
mg.to_csv(OUT + 's2_metric_medians_by_group.csv')

# ---- listening list -------------------------------------------------------------------
tsv = pd.read_csv(RAW + 'common_voice_chuvash/audio_metadata_Mozilla/cv_xpf_spkr17.tsv', sep='\t', quoting=3,
                  usecols=['path', 'sentence'])
tsv['file_name'] = tsv.path.str.replace('.mp3', '', regex=False)
tr = dict(zip(tsv.file_name, tsv.sentence))
for fn in full.loc[full.corpus == 'chuvash_voice', 'file_name']:
    try:
        tr[fn] = open(RAW + f'chuvash_voice/audio_transcripts/{fn}.lab', encoding='utf-8').read().strip()
    except FileNotFoundError:
        pass
full['has_digit'] = full.file_name.map(tr).fillna('').str.contains(r'\d')
sc = sc.merge(full[['file_name', 'has_digit']], on='file_name', how='left')
# eligibility: alignment QC pass, >= 10 vowels, all 9 metrics, and no numerals in the transcript
# (numeral transcripts score 0.45 lower, see s2b_content_check.csv -- most likely aligner mismatch)
el = sc[(sc.qc_pass == True) & (sc.n_vowels >= 10) & (sc.n_metrics == len(M)) & (~sc.has_digit)].copy()
top = el.nlargest(15, 'broadcast_score').assign(list='most_broadcast_like')
bot = el.nsmallest(15, 'broadcast_score').assign(list='least_broadcast_like')
ll = pd.concat([top, bot])
ll['rank_in_list'] = ll.groupby('list').cumcount() + 1


def transcript(fn, corpus):
    if corpus == 'chuvash_voice':
        try:
            return open(RAW + f'chuvash_voice/audio_transcripts/{fn}.lab', encoding='utf-8').read().strip()
        except FileNotFoundError:
            return ''
    t = tsv.loc[tsv.file_name == fn, 'sentence']
    return t.iloc[0] if len(t) else ''


ll['transcript'] = ll.file_name.map(tr)
ll['audio'] = np.where(ll.corpus == 'chuvash_voice', '1-raw_data/chuvash_voice/audio_transcripts/' + ll.file_name + '.wav',
                       'Common Voice clip ' + ll.file_name + '.mp3 (cv_xpf_spkr17.tsv path)')
ll['eligible_pool_n'] = len(el)
ll[['list', 'rank_in_list', 'file_name', 'corpus', 'spk', 'transcript', 'broadcast_score', 'pc1', 'n_vowels', 'audio', 'eligible_pool_n'] + M] \
    .to_csv(OUT + 'listening_list.csv', index=False)

# ---- per-metric split-half reliability (odd vs even words, both halves >= MIN_V vowels) ---------
oe = odd.merge(even, on='file_name', suffixes=('_o', '_e')).merge(full[['file_name', 'spk', 'corpus']], on='file_name')
oe = oe[(oe.n_vowels_o >= MIN_V) & (oe.n_vowels_e >= MIN_V)]
rows = []
for lab, d in [('all', oe), ('voice_main', oe[oe.spk == VM]),
               ('CH_other_voices', oe[(oe.corpus == 'chuvash_voice') & (oe.spk != VM)]),
               ('common_voice_chuvash', oe[oe.corpus == 'common_voice_chuvash'])]:
    for m in M + ['broadcast_score']:
        a, b = (m + '_o', m + '_e') if m != 'broadcast_score' else ('broadcast_score_odd', 'broadcast_score_even')
        x = d[[a, b]].dropna()
        rs = x[a].corr(x[b], method='spearman') if len(x) > 9 else np.nan
        se = 1 / np.sqrt(len(x) - 3) if len(x) > 9 else np.nan
        rows.append({'subset': lab, 'metric': m, 'n_files': len(x), 'r_spearman_odd_even': rs,
                     'ci_lo_fisher': np.tanh(np.arctanh(rs) - 1.96 * se) if pd.notna(rs) else np.nan,
                     'ci_hi_fisher': np.tanh(np.arctanh(rs) + 1.96 * se) if pd.notna(rs) else np.nan,
                     'spearman_brown_full_length': 2 * rs / (1 + rs) if pd.notna(rs) else np.nan})
pd.DataFrame(rows).to_csv(OUT + 's2_split_half_reliability.csv', index=False)

# ---- where voice_main falls on each metric among speakers with >= 20 scorable files -------------
spm = sc.groupby('spk').agg(n_files=('file_name', 'size'), **{m: (m, 'median') for m in M + ['broadcast_score']})
spm = spm[spm.n_files >= 20]
rk = []
for m in M + ['broadcast_score']:
    o = ORIENT.get(m, 1)
    x = spm[m] * o
    rk.append({'metric': m, 'orientation': o, 'voice_main_median': spm.loc[VM, m],
               'speaker_median_of_medians': spm[m].median(),
               'voice_main_rank_most_broadcast': int(x.rank(ascending=False)[VM]), 'n_speakers': len(spm),
               'voice_main_percentile_broadcast': ((x < x[VM]).sum() + 0.5 * ((x == x[VM]).sum() - 1)) / (len(x) - 1),  # mid-rank among the other speakers
               'n_speakers_tied_with_vm': int((x == x[VM]).sum() - 1)})
pd.DataFrame(rk).to_csv(OUT + 's2_voice_main_metric_ranks.csv', index=False)

# ---- required output -----------------------------------------------------------------
req = ['file_name', 'corpus', 'spk', 'n_vowels'] + M + ['broadcast_score', 'pc1', 'broadcast_score_odd']
aux = ['f0_sd_nonfinal_st', 'f0_range_nonfinal_st', 'broadcast_score_alt', 'pc1_alt', 'n_metrics', 'n_vowels_odd', 'n_metrics_odd', 'broadcast_score_even', 'broadcast_score_within_spk',
       'n_pairs', 'n_f0', 'n_fullV', 'n_internal_pauses', 'pause_f0_rel', 'pause_int_rel', 'hnr', 'qc_pass', 'best_shift', 'has_digit']
full[req + aux].to_csv(OUT + 'broadcast_score_by_file.csv', index=False)
print('scored files', sc.shape[0], 'of', len(full), '; complete-case PCA n', ncc, '; pooled median', round(med, 4))
print(pca.round(3).to_string())
print(ev.head(3).round(3).to_string())
print(vd[vd.method == 'pearson'].round(3).to_string())
print(bc.round(3).to_string())
