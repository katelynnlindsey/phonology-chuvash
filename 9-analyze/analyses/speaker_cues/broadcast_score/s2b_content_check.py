# speaker_cues/broadcast_score/s2b_content_check.py                     2026-10-02
# The least broadcast-like listening-list files contain numerals and Russian names. Check whether
# transcript content (digits; quotation marks or dashes; text length) shifts the score,
# i.e. whether the score partly measures text type / alignment of unspelled numerals.
import numpy as np, pandas as pd, re
B = "/Users/kate/Documents/GitHub/phonology-chuvash/9-analyze/"
OUT = B + "output/speaker_cues_2026-10-02/broadcast_score/"
RAW = "/Users/kate/Documents/GitHub/phonology-chuvash/1-raw_data/"
d = pd.read_csv(OUT + 'broadcast_score_by_file.csv')
tsv = pd.read_csv(RAW + 'common_voice_chuvash/audio_metadata_Mozilla/cv_xpf_spkr17.tsv', sep='\t', quoting=3, usecols=['path', 'sentence'])
tsv['file_name'] = tsv.path.str.replace('.mp3', '', regex=False)
tr = dict(zip(tsv.file_name, tsv.sentence))
for fn in d.loc[d.corpus == 'chuvash_voice', 'file_name']:
    try:
        tr[fn] = open(RAW + f'chuvash_voice/audio_transcripts/{fn}.lab', encoding='utf-8').read().strip()
    except FileNotFoundError:
        pass
d['transcript'] = d.file_name.map(tr)
d['has_digit'] = d.transcript.fillna('').str.contains(r'\d')
d['n_words_text'] = d.transcript.fillna('').str.split().str.len()
d['has_quote_or_dash'] = d.transcript.fillna('').str.contains('[«»—–]')
sc = d[d.broadcast_score.notna()]
rows = []
for lab, s in [('all', sc), ('voice_main', sc[sc.spk == 'chv_voice_main']), ('common_voice_chuvash', sc[sc.corpus == 'common_voice_chuvash'])]:
    for flag in ['has_digit', 'has_quote_or_dash']:
        a, b = s[s[flag]].broadcast_score, s[~s[flag]].broadcast_score
        diff = a.mean() - b.mean()
        se = np.sqrt(a.var() / len(a) + b.var() / len(b)) if len(a) > 1 else np.nan
        rows.append({'subset': lab, 'flag': flag, 'n_true': len(a), 'n_false': len(b), 'mean_true': a.mean(),
                     'mean_false': b.mean(), 'diff': diff, 'ci_lo': diff - 1.96 * se, 'ci_hi': diff + 1.96 * se})
    rr = s[['n_words_text', 'broadcast_score']].corr('spearman').iloc[0, 1]
    rows.append({'subset': lab, 'flag': 'spearman_r_text_length', 'n_true': len(s), 'diff': rr})
pd.DataFrame(rows).to_csv(OUT + 's2b_content_check.csv', index=False)
print(pd.DataFrame(rows).round(3).to_string())
