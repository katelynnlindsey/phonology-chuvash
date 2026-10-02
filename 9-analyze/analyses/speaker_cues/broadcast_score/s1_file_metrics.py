# speaker_cues/broadcast_score/s1_file_metrics.py                       2026-10-02
#
# Per-recording (file_name) style metrics for the broadcast-likeness score, both corpora.
# Computed twice: on ALL retained words ("full") and on ODD word_token_idx words only ("odd",
# the cross-fitting split; stress effects can then be tested on even words). An 'even' run is made
# only as a split-half reliability diagnostic.
#
# Inputs (read-only, overnight 2026-10-01 caches):
#   sociophonetics/cache/vowels_socio.parquet   leveled vowels + spk key
#   sociophonetics/cache/model_data.parquet     f0_st (f0_mid in st re spk median, screened); row-aligned
#   sociophonetics/cache/f0_steps.parquet       raw f0_step10/11 (undefined-f0 share), merged on keys
#   segmental_acoustics/vowel_tokens.csv.gz     Praat AC voiced fraction per grid vowel
#   segmental_acoustics/file_alignment_qc.csv   per-file full-vowel voiced fraction (fullV_vf), qc_pass
#   output/speaker_structure.csv                CH per-file HNR (auxiliary; CH only)
#
# Metrics (per file; NA if < MIN_V vowels):
#   rate        full: (n-1)/(last vowel end - first vowel start) [vowels/s]  (= overnight log_span_rate)
#               odd : sum(vowels in odd words)/sum(odd word durations)  [within-word rate; see FINDINGS]
#   npvi_v      100*mean(|d_k-d_k+1|/mean(d_k,d_k+1)) over ADJACENT vowel pairs: same word & sidx+1, or
#               next word (widx+1), last->first syllable, no pause between (gap < PAUSE_S). odd: within-word only.
#   cv_dur      SD/mean of vowel duration
#   f0_sd_st, f0_range_st   SD and q90-q10 of screened f0_st (needs >= MIN_V f0 values)
#   f0_sd_nonfinal_st, f0_range_nonfinal_st   same without the utterance-final word (sensitivity)
#   final_f0_rel, final_int_rel   utterance-final syllable (widx==wN & sidx==sN) minus file median (st / dB)
#   pause_f0_rel, pause_int_rel   mean over internal pause-adjacent word-final syllables (auxiliary)
#   vf_fullV    mean mid-50% voiced fraction (vf_def_mid) of full vowels /a e i u y ɯ/ >= 50 ms
#   f0_undef_share   share of vowels with f0_step10 or f0_step11 undefined (raw, before screening)
import numpy as np, pandas as pd, sys

B = "/Users/kate/Documents/GitHub/phonology-chuvash/9-analyze/"
S = B + "output/overnight_2026-10-01/sociophonetics/cache/"
SEG = B + "output/overnight_2026-10-01/segmental_acoustics/"
OUT = B + "output/speaker_cues_2026-10-02/broadcast_score/"
MIN_V = 6
PAUSE_S = 0.150
FULL_PH = {"ɑ", "e", "i", "u", "y", "ɯ"}

cols = ['file_name', 'corpus', 'spk', 'word_id', 'word_label', 'sidx', 'sN', 'widx', 'wN', 'word_token_idx',
        'duration', 'int_midpoint', 'start', 'end', 'word_start', 'word_end']
v = pd.read_parquet(S + 'vowels_socio.parquet', columns=cols)
md = pd.read_parquet(S + 'model_data.parquet', columns=['file_name', 'sidx', 'int_midpoint', 'f0_st'])
assert (md.file_name.values == v.file_name.values).all() and (md.sidx.values == v.sidx.values).all()
v['f0_st'] = md.f0_st.values
del md
f0s = pd.read_parquet(S + 'f0_steps.parquet')
assert not f0s.duplicated(['word_id', 'sidx', 'start']).any()
n0 = len(v)
v = v.merge(f0s, on=['word_id', 'sidx', 'start'], how='left', validate='1:1')
assert len(v) == n0 == 574344
v['f0_undef'] = (v.f0_step10.isna() | v.f0_step11.isna()).astype(float)
v = v.sort_values(['file_name', 'start']).reset_index(drop=True)
v['odd'] = (v.word_token_idx % 2 == 1)

# ---- word table, pauses -------------------------------------------------------
w = (v.groupby(['file_name', 'widx'], as_index=False)
       .agg(word_label=('word_label', 'first'), word_start=('word_start', 'first'),
            word_end=('word_end', 'first'), wN=('wN', 'first'), wti=('word_token_idx', 'first')))
w = w.sort_values(['file_name', 'widx'])
nxt = w.groupby('file_name').shift(-1)
w['next_adjacent'] = (nxt.widx == w.widx + 1)
w['gap_next'] = np.where(w.next_adjacent, nxt.word_start - w.word_end, np.nan)
w['pause_after'] = w.next_adjacent & (w.gap_next >= PAUSE_S)
v = v.merge(w[['file_name', 'widx', 'gap_next', 'next_adjacent', 'pause_after']], on=['file_name', 'widx'], how='left')
v = v.sort_values(['file_name', 'start']).reset_index(drop=True)
v['word_final'] = v.sidx == v.sN
v['utt_final'] = (v.widx == v.wN) & v.word_final
v['pause_final'] = v.word_final & v.pause_after.fillna(False).astype(bool)

# ---- grid vowels (voicing) mapped onto leveled words ---------------------------
vt = pd.read_csv(SEG + 'vowel_tokens.csv.gz', usecols=['file_name', 'word_label', 'widx', 'phone', 'start', 'dur_ms', 'vf_def_mid'])
vw = (vt.groupby(['file_name', 'widx'], as_index=False).agg(word_label=('word_label', 'first'), st=('start', 'min'))
        .sort_values(['file_name', 'st']))
vw['occ'] = vw.groupby(['file_name', 'word_label']).cumcount()
lw = w.sort_values(['file_name', 'word_start']).copy()
lw['occ'] = lw.groupby(['file_name', 'word_label']).cumcount()
vw = vw.merge(lw[['file_name', 'word_label', 'occ', 'wti']], on=['file_name', 'word_label', 'occ'], how='left')
vt = vt.merge(vw[['file_name', 'widx', 'wti']], on=['file_name', 'widx'], how='left')
vt = vt[vt.phone.isin(FULL_PH) & (vt.dur_ms >= 50)]


def npvi(d, mask):
    a, b = d[:-1], d[1:]
    x = np.abs(a - b) / ((a + b) / 2)
    x = x[mask]
    return 100 * x.mean() if len(x) >= 3 else np.nan, len(x)


def file_metrics(g, mode):
    n = len(g)
    r = {'n_vowels': n}
    if n < MIN_V:
        return r
    d = g.duration.values
    if mode == 'full':
        r['rate'] = (n - 1) / (g.end.max() - g.start.min())
    else:
        ww = g.drop_duplicates('widx')
        r['rate'] = n / (ww.word_end - ww.word_start).sum()
    same = (g.widx.values[:-1] == g.widx.values[1:]) & (g.sidx.values[1:] == g.sidx.values[:-1] + 1)
    if mode == 'full':
        cross = ((g.widx.values[1:] == g.widx.values[:-1] + 1) & g.word_final.values[:-1] & (g.sidx.values[1:] == 1)
                 & (g.gap_next.values[:-1] < PAUSE_S))
        adj = same | cross
    else:
        adj = same
    r['npvi_v'], r['n_pairs'] = npvi(d, adj)
    r['cv_dur'] = d.std(ddof=1) / d.mean()
    f = g.f0_st.dropna()
    r['n_f0'] = len(f)
    if len(f) >= MIN_V:
        r['f0_sd_st'] = f.std(ddof=1)
        r['f0_range_st'] = f.quantile(.9) - f.quantile(.1)
        med_f0 = f.median()
    else:
        med_f0 = np.nan
    fn_ = g.loc[g.widx != g.wN, 'f0_st'].dropna()   # sensitivity: f0 variability without the utterance-final word
    if len(fn_) >= MIN_V:
        r['f0_sd_nonfinal_st'] = fn_.std(ddof=1)
        r['f0_range_nonfinal_st'] = fn_.quantile(.9) - fn_.quantile(.1)
    med_int = g.int_midpoint.median()
    fin = g[g.utt_final]
    if len(fin):
        r['final_f0_rel'] = fin.f0_st.iloc[-1] - med_f0
        r['final_int_rel'] = fin.int_midpoint.iloc[-1] - med_int
    pf = g[g.pause_final & ~g.utt_final]
    r['n_internal_pauses'] = len(pf)
    if len(pf):
        r['pause_f0_rel'] = (pf.f0_st - med_f0).mean()
        r['pause_int_rel'] = (pf.int_midpoint - med_int).mean()
    r['f0_undef_share'] = g.f0_undef.mean()
    return r


def run(mode):
    vv = v if mode == 'full' else (v[v.odd] if mode == 'odd' else v[~v.odd])
    rows = []
    for fn, g in vv.groupby('file_name', sort=False):
        r = file_metrics(g, mode)
        r['file_name'] = fn
        rows.append(r)
    res = pd.DataFrame(rows)
    vtt = vt if mode == 'full' else (vt[vt.wti % 2 == 1] if mode == 'odd' else vt[vt.wti % 2 == 0])
    vf = vtt.groupby('file_name').vf_def_mid.agg(vf_fullV='mean', n_fullV='size').reset_index()
    res = res.merge(vf, on='file_name', how='left')
    res.loc[res.n_vowels < MIN_V, ['vf_fullV']] = np.nan
    return res


if __name__ == '__main__':
    meta = v.groupby('file_name', as_index=False).agg(corpus=('corpus', 'first'), spk=('spk', 'first'))
    assert v.groupby('file_name').spk.nunique().max() == 1
    full = run('full')
    full = meta.merge(full, on='file_name')
    qc = pd.read_csv(SEG + 'file_alignment_qc.csv')[['file_name', 'fullV_vf', 'qc_pass', 'best_shift']]
    full = full.merge(qc, on='file_name', how='left')
    hnr = pd.read_csv(B + 'output/speaker_structure.csv')[['file_name', 'hnr']]
    full = full.merge(hnr, on='file_name', how='left')
    full.to_csv(OUT + 's1_metrics_full.csv', index=False)
    odd = run('odd')
    odd.to_csv(OUT + 's1_metrics_odd.csv', index=False)
    even = run('even')   # split-half reliability diagnostic only
    even.to_csv(OUT + 's1_metrics_even.csv', index=False)
    # internal-pause definition audit
    ws = w[w.next_adjacent]
    aud = pd.DataFrame({'adjacent_word_boundaries': [len(ws)],
                        'share_gap_ge_150ms': [(ws.gap_next >= PAUSE_S).mean()],
                        'share_gap_ge_100ms': [(ws.gap_next >= 0.100).mean()],
                        'share_gap_gt_0': [(ws.gap_next > 0.0001).mean()],
                        'vt_full_vowels_mapped_to_leveled_word': [vt.wti.notna().mean()]})
    aud.to_csv(OUT + 's1_pause_audit.csv', index=False)
    print(full.shape, odd.shape)
    print(aud.T)
