# speaker_cues/broadcast_score/s3_figure.py                             2026-10-02
# Figure: broadcast-score distributions by speaker (voice_main highlighted) + voice_main's
# percentile among speakers on each component metric. Run inside a kernel where the
# figure-style skill helpers (apply_figure_style, panel_letter, META_GREY) are loaded.
import numpy as np, pandas as pd, matplotlib as mpl, matplotlib.pyplot as plt
B = "/Users/kate/Documents/GitHub/phonology-chuvash/9-analyze/"
OUT = B + "output/speaker_cues_2026-10-02/broadcast_score/"
VM = 'chv_voice_main'
apply_figure_style(sizes=(8, 7, 6))
d = pd.read_csv(OUT + 'broadcast_score_by_file.csv')
d = d[d.broadcast_score.notna()]
cnt = d.groupby('spk').size()
keep = cnt[cnt >= 20].index
dd = d[d.spk.isin(keep)]
order = dd.groupby('spk').broadcast_score.median().sort_values().index.tolist()
pooled_med = d.broadcast_score.median()
rk = pd.read_csv(OUT + 's2_voice_main_metric_ranks.csv')

C_VM, C_CH, C_CV = '#c2185b', '#4a6fa5', '#9e9e9e'
col = {s: (C_VM if s == VM else C_CH if s.startswith('chv_') else C_CV) for s in order}

fig = plt.figure(figsize=(7.0, 6.2))
gs = fig.add_gridspec(1, 2, width_ratios=[1.35, 1], wspace=0.55)
ax = fig.add_subplot(gs[0])
data = [dd.loc[dd.spk == s, 'broadcast_score'].values for s in order]
bp = ax.boxplot(data, orientation='horizontal', widths=0.65, showfliers=False, patch_artist=True,
                medianprops=dict(color='black', lw=1.0), whiskerprops=dict(lw=0.7), capprops=dict(lw=0.7))
for patch, s in zip(bp['boxes'], order):
    patch.set_facecolor(col[s]); patch.set_alpha(0.95 if s == VM else 0.55); patch.set_edgecolor('black'); patch.set_linewidth(1.2 if s == VM else 0.5)
ax.axvline(pooled_med, color='black', ls='--', lw=0.7)
ax.set_yticks(range(1, len(order) + 1))
ax.set_yticklabels([s.replace('chv_', 'CH ').replace('cv_', 'CV ') + f' ({cnt[s]:,})' for s in order])
for t, s in zip(ax.get_yticklabels(), order):
    t.set_color(C_VM if s == VM else 'black')
    if s == VM:
        t.set_fontweight('bold')
ax.set_xlabel('Broadcast-likeness score\n(mean of 9 oriented z-scores; higher = more broadcast-like)')
ax.set_title('voice_main sits in the upper middle of speakers', loc='left')
ax.text(pooled_med, len(order) + 0.9, 'pooled median', ha='center', va='bottom', fontsize=7)
ax.set_ylim(0.3, len(order) + 1.6)
from matplotlib.patches import Patch
ax.legend(handles=[Patch(fc=C_VM, ec='black', label='Chuvash Voice voice_main'),
                   Patch(fc=C_CH, alpha=0.55, ec='black', label='Chuvash Voice, other voices'),
                   Patch(fc=C_CV, alpha=0.55, ec='black', label='Common Voice speakers')],
          loc='upper left', bbox_to_anchor=(-0.45, -0.13), ncol=1, frameon=False, fontsize=7)
ax.margins(x=0.04)

ax2 = fig.add_subplot(gs[1])
lab = {'rate': 'Speech rate (faster)', 'npvi_v': 'nPVI-V (lower)', 'cv_dur': 'Vowel-duration CV (lower)',
       'f0_sd_st': 'f0 SD (lower)', 'f0_range_st': 'f0 10–90% range (lower)',
       'final_f0_rel': 'Final-syllable f0 (lower)', 'final_int_rel': 'Final-syllable intensity (lower)',
       'vf_fullV': 'Full-vowel voicing (lower)', 'f0_undef_share': 'Undefined-f0 share (higher)',
       'broadcast_score': 'Composite score'}
rk = rk.iloc[::-1].reset_index(drop=True)
y = np.arange(len(rk))
pct = 100 * rk.voice_main_percentile_broadcast.values
for i, (p, m) in enumerate(zip(pct, rk.metric)):
    ax2.plot([50, p], [i, i], color=META_GREY if m != 'broadcast_score' else 'black', lw=1.0, zorder=1)
ax2.scatter(pct, y, s=[42 if m == 'broadcast_score' else 28 for m in rk.metric], color=C_VM, zorder=3,
            edgecolor='black', linewidth=0.5)
ax2.axvline(50, color='black', lw=0.7)
ax2.set_yticks(y); ax2.set_yticklabels([lab[m] for m in rk.metric])
ax2.set_xlim(-4, 104); ax2.set_xticks([0, 25, 50, 75, 100])
ax2.set_xlabel(f'voice_main mid-rank percentile among {int(rk.n_speakers.iloc[0]) - 1} other speakers\n(speaker medians; higher = more broadcast-like)')
ax2.set_title('Fast with low finals,\nbut not monotone or weakly voiced', loc='left')
ax2.margins(y=0.04)
panel_letter(ax, 'a'); panel_letter(ax2, 'b')
fig.savefig(OUT + 'fig_broadcast_score_by_speaker.png', dpi=300, bbox_inches='tight')
fig.savefig(OUT + 'fig_broadcast_score_by_speaker.pdf', bbox_inches='tight')
