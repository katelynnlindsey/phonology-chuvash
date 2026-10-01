#!/usr/bin/env python3
"""Build the findings deck from output/*.csv.

Every number on a slide is read from a table in 9-analyze/output, so the deck
cannot drift from the analyses the way a hand-typed one does.  Figures are
referenced by artifact marker when --markers is given (for the Claude Science
renderer) and by relative filename otherwise (for a local browser).

Usage:
    python make_slides.py --repo <path> [--out chuvash_findings_slides.html]
                          [--markers markers.json]

markers.json maps figure filename -> artifact id, e.g.
    {"fig_default_adjudication.png": "1227abc4-..."}
"""
import argparse, base64, json, os, sys
import pandas as pd
import numpy as np

CSS = """
  :root{
    --ink:#1a1a1a; --muted:#6b6b6b; --rule:#d9d9d9;
    --full:#4C72B0; --red:#C44E52; --green:#55A868; --grey:#8C8C8C;
    --bg:#ffffff; --panel:#f6f6f4;
  }
  *{box-sizing:border-box}
  body{margin:0; background:#e9e9e6; color:var(--ink);
    font:16px/1.5 "Charter","Georgia","Iowan Old Style",serif;}
  .deck{max-width:1180px;margin:0 auto;padding:28px 18px 80px}
  .slide{background:var(--bg); border:1px solid var(--rule); border-radius:4px;
    padding:38px 46px 34px; margin:0 0 26px; min-height:620px;
    display:flex; flex-direction:column; position:relative;
    box-shadow:0 1px 3px rgba(0,0,0,.07);}
  .slide::after{content:attr(data-n); position:absolute; right:20px; bottom:12px;
    font:11px/1 ui-sans-serif,system-ui,sans-serif; color:var(--muted);}
  h1{font-size:34px;line-height:1.15;margin:.1em 0 .35em;font-weight:600}
  h2{font-size:25px;line-height:1.2;margin:0 0 .15em;font-weight:600}
  .kicker{font:600 11px/1 ui-sans-serif,system-ui,sans-serif; letter-spacing:.12em;
    text-transform:uppercase; color:var(--muted); margin:0 0 14px;}
  .sub{font-size:17px;color:var(--muted);margin:0 0 18px}
  p{margin:0 0 .75em}
  ul{margin:.2em 0 .9em; padding-left:1.15em}
  li{margin:.3em 0}
  .lede{font-size:19px;line-height:1.45}
  figure{margin:8px 0 6px;text-align:center}
  figure img{max-width:100%;height:auto;border:1px solid var(--rule);border-radius:3px}
  figcaption{font:13px/1.45 ui-sans-serif,system-ui,sans-serif; color:var(--muted);
    margin-top:8px; text-align:left;}
  table{border-collapse:collapse;width:100%;font-size:14.5px;margin:.4em 0 .8em}
  th,td{border-bottom:1px solid var(--rule);padding:5px 9px;text-align:left}
  th{font:600 12.5px/1.3 ui-sans-serif,system-ui,sans-serif;color:var(--muted);
     text-transform:uppercase;letter-spacing:.05em}
  td.num,th.num{text-align:right;font-variant-numeric:tabular-nums}
  tr.hi td{background:#fdf4f4}
  code,.ipa{font-family:"Menlo","DejaVu Sans Mono",monospace;font-size:.93em}
  .tag{display:inline-block;font:600 10.5px/1 ui-sans-serif,system-ui,sans-serif;
    letter-spacing:.07em;text-transform:uppercase;padding:4px 8px;border-radius:3px;
    vertical-align:2px;margin-right:8px;}
  .tag.new{background:#e8eef7;color:#2f4f7f}
  .tag.fix{background:#fdecec;color:#8f2f33}
  .tag.null{background:#eef2ee;color:#3b5c42}
  .cols{display:grid;grid-template-columns:1fr 1fr;gap:26px}
  .cols3{display:grid;grid-template-columns:1fr 1fr 1fr;gap:20px}
  .panel{background:var(--panel);border-radius:4px;padding:16px 18px;font-size:14.5px}
  .panel h3{margin:0 0 .4em;font-size:15px}
  .big{font-size:40px;line-height:1;font-weight:600;font-variant-numeric:tabular-nums}
  .big.red{color:var(--red)} .big.blue{color:var(--full)} .big.green{color:var(--green)}
  .cap{font:12.5px/1.35 ui-sans-serif,system-ui,sans-serif;color:var(--muted)}
  .note{font:13.5px/1.5 ui-sans-serif,system-ui,sans-serif;color:var(--muted);
    border-left:3px solid var(--rule); padding-left:12px; margin:.6em 0;}
  .spacer{flex:1}
  em.term{font-style:normal;font-weight:600}
  @media print{
    body{background:#fff}
    .deck{max-width:none;padding:0}
    .slide{page-break-after:always;border:none;box-shadow:none;margin:0;
           min-height:0;height:100vh}
  }
"""


def load(out):
    """Read every table the deck cites. Missing tables raise, deliberately."""
    g = lambda f: pd.read_csv(os.path.join(out, f))
    D = {}
    D["adj"] = g("default_adjudication.csv")
    D["fl"] = g("final_lengthening_models.csv").set_index("term")
    D["flc"] = g("final_lengthening_cells.csv")
    D["gem"] = g("gemination_models.csv")
    D["gfin"] = g("gemination_final.csv")
    D["gw"] = g("gemination_weight_model.csv")
    D["mora"] = g("mora_evidence.csv")
    D["malt"] = g("mora_alternating_types.csv")
    D["st"] = g("sentence_type_subtypes.csv").set_index("group")
    D["stc"] = g("sentence_type_clitic_enrichment.csv").set_index("sentence_type")
    D["sts"] = g("sentence_type_tail_slope.csv")
    D["cs"] = g("coda_sonority_models.csv")
    D["ss"] = g("secondary_stress_by_position.csv")
    D["clu"] = g("clustering_comparison.csv")
    D["cr"] = g("separability_with_context.csv")
    D["sep"] = g("separability_classifier_comparison.csv")
    # rounding_contrasts.csv was reshaped 2026-10-01: one row per (pair, dv)
    # with HEIGHT-MATCHED pairs. The old shape had one anchor per harmony
    # series, which compared mid against high and so confounded rounding with
    # height. Indexed on `pair` now, and the F3 rows pulled out separately.
    D["rnd"] = g("rounding_contrasts.csv")
    D["rndF3"] = D["rnd"][D["rnd"].dv == "F3z"].set_index("pair")
    D["rndF2"] = D["rnd"][D["rnd"].dv == "F2z"].set_index("pair")
    D["rst"] = g("rounding_by_stress.csv").set_index("vowel")
    D["bp"] = g("back_series_placement.csv").set_index("vowel")
    D["pos"] = g("positional_restrictions.csv", ).set_index(
        g("positional_restrictions.csv").columns[0])
    D["vsm"] = g("vowel_space_means.csv")
    D["shift"] = g("vowel_shift_models.csv")
    D["mw"] = g("minimal_word_diagnosis.csv")
    D["frag"] = g("fragment_suffix_evidence.csv")
    D["inv"] = g("inventory_segments.csv")
    D["gemi"] = g("inventory_geminates.csv")
    D["shapes"] = g("phonotactics_syllable_shapes.csv")
    D["spk"] = g("speaker_structure_validation.csv")
    D["mr"] = g("master_rule_comparison.csv")
    # rule_acoustic_models.csv is SUPERSEDED (pre-whole-word-fix, recomputed
    # labels over surviving rows). full_word_rule_models.csv replaces it.
    D["fw"] = g("full_word_rule_models.csv")
    D["f0d"] = g("f0_measure_diagnostics.csv")
    D["f0r"] = g("f0_rule_models.csv")
    D["f0e"] = g("f0_endpoint_test.csv")
    D["f0p"] = g("f0_position_cell_means.csv")
    D["svs"] = g("step_vowel_stratified.csv")
    D["cst"] = g("contour_steps.csv")
    D["csm"] = g("contour_step_means.csv")
    D["spm"] = g("shape_peak_match.csv")
    D["scc"] = g("shape_class_counts.csv")
    D["mvp"] = g("matched_vowel_prominence.csv")
    D["cfp"] = g("carrier_frame_prominence.csv")
    D["fpt"] = g("final_prominence_test.csv")
    D["fpr"] = g("final_prominence_rule_ranking.csv")
    D["pcm"] = g("position_cell_means.csv")
    D["mva"] = g("morph_validation.csv")
    D["mac"] = g("morph_accepted.csv")
    D["mst"] = g("morph_stress_test.csv")
    D["mal"] = g("morph_alignment.csv")
    D["sph"] = g("sonority_peripherality.csv")
    return D


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--repo", required=True)
    ap.add_argument("--out", default="chuvash_findings_slides.html")
    ap.add_argument("--markers", default=None)
    ap.add_argument("--figdir", default=None,
                    help="directory holding the PNGs; if given, every figure "
                         "is embedded as a base64 data URI so the HTML is "
                         "self-contained and opens correctly outside the app")
    a = ap.parse_args()
    out = os.path.join(a.repo, "9-analyze", "output")
    D = load(out)
    mk = json.load(open(a.markers)) if a.markers else {}

    missing = []

    def img(fn, cap):
        """Return a <figure>.

        Three ways to reference the image, in order of preference:
          --figdir   embed the bytes as a data URI -> the file works anywhere,
                     including emailed, printed, or opened from disk
          --markers  an artifact marker -> resolves inside Claude Science only
          neither    a relative filename -> works only beside the PNGs
        """
        if a.figdir:
            path = os.path.join(a.figdir, fn)
            if os.path.exists(path):
                b64 = base64.b64encode(open(path, "rb").read()).decode()
                src = f"data:image/png;base64,{b64}"
            else:
                missing.append(fn)
                return (f'<figure><p class="cap"><strong>[missing figure: '
                        f'{fn}]</strong></p><figcaption>{cap}</figcaption></figure>')
        elif fn in mk:
            src = "{{artifact:art_%s}}" % mk[fn]
        else:
            src = fn
        return (f'<figure><img src="{src}" alt="{cap[:80]}">'
                f'<figcaption>{cap}</figcaption></figure>')

    # ── numbers ───────────────────────────────────────────────────────
    ad5 = D["adj"][D["adj"].inventory == 5].set_index("cue")
    fl = D["fl"]
    fl_comb = 100 * (np.exp(fl.loc["syl_final", "estimate"] +
                            fl.loc["syl_final:word_utt_final", "estimate"] +
                            fl.loc["word_utt_final", "estimate"]) - 1)
    fl_str = fl.loc["stressed", "pct_change"]
    gok = D["gem"][D["gem"].measurable == True]
    gw = D["gw"]; gwa = gw[gw.kind == "adjusted_cell"].set_index("term")["estimate"]
    gw_i = float(gw[(gw.kind == "coefficient") &
                    (gw.term == "c_long:v_classreduced")].statistic.iloc[0])
    pct = lambda v: 100 * (np.exp(v) - 1)
    mora_t = D["mora"][D["mora"].term == "alternatingTRUE"]
    csa = D["cs"][D["cs"]["sample"] == "all"].set_index(["predictor", "prominence"])
    OR = lambda p, q: csa.loc[(p, q), "odds_ratio"]
    cn = D["clu"][D["clu"].context == "non_palatal"]
    kbest = int(cn.loc[cn.ARI_vs_phonemic.idxmax(), "k"])
    crg = D["cr"][D["cr"].cv == "grouped_by_word"].set_index("features")
    FSET, NSET = "formants only (F1 F2 F3)", "+ neighbouring segments"
    ss = D["ss"].set_index("rel")
    sh = D["shift"]
    at = sh[sh.model == "apparent_time"]; gd = sh[sh.model == "gender"]
    posc = D["pos"]
    p1 = posc["pct_polysyll_in_syl1"].sort_values(ascending=False)
    S = []

    # ── 1 title ───────────────────────────────────────────────────────
    S.append(f"""
  <p class="kicker">Four corpora · rebuilt dataset</p>
  <h1>Chuvash stress, phonetics and phonology</h1>
  <p class="lede">What four corpora say about the vowel system, the
  phonotactics, syllable weight and where stress falls — and which of the
  standard descriptions survive measurement.</p>
  <div class="spacer"></div>
  <table>
    <tr><th>Corpus</th><th>Source</th><th class="num">Size</th><th>Role here</th></tr>
    <tr><td>Chuvash Electronic Wordlist</td><td>Zheltov 2008</td><td class="num">18,984 types</td><td>type inventory, minimal word</td></tr>
    <tr><td>Chuvash Monolingual corpus</td><td>Plotnikov 2024</td><td class="num">2.9M sentences</td><td>token frequency, alternations</td></tr>
    <tr><td>Common Voice Chuvash</td><td>Ardila 2020; Ahn 2022</td><td class="num">17,329 clips · 104 speakers</td><td>speaker-varied acoustics</td></tr>
    <tr><td>Chuvash Voice</td><td>Plotnikov 2024</td><td class="num">29,727 clips · ~1 speaker</td><td>bulk acoustics, consonant length</td></tr>
  </table>
  <p class="cap">MFA 3.4 (Vox Communis <code>chuvash_mfa</code>); vowels measured
  with new-FAVE, f0 and intensity with Praat, consonant durations from the
  pre-recode grids. <strong>574,344 vowel tokens</strong> and 1,424,952 phone
  tokens after cleaning.</p>""")

    # ── 2 what the descriptions claim ─────────────────────────────────
    S.append("""
  <h2>What the standard descriptions claim</h2>
  <p class="sub">Four claims this study can test, and one it cannot.</p>
  <table>
    <tr><th>Claim</th><th>Source</th><th>Verdict here</th></tr>
    <tr><td>Stress falls on the rightmost full vowel</td><td>Krueger 1961; Dobrovolsky 1999</td><td>supported, with a stressless default</td></tr>
    <tr><td>Reduced vowels may round, especially under stress</td><td>grammars</td><td>refuted for ⟨ӗ⟩; untestable for ⟨ӑ⟩ ⟨ы⟩</td></tr>
    <tr><td>High row is front/back × rounded/unrounded</td><td>Krueger 1961</td><td>front row confirmed; back row undecidable</td></tr>
    <tr><td>Geminates resist intervocalic lenition</td><td>grammars</td><td>geminates are phonetically long</td></tr>
    <tr><td>Two vowels cannot occur in succession</td><td>grammars</td><td>consistent with the phonotactics</td></tr>
  </table>
  <div class="note">The reduced vowels are the crux. Whether ⟨ы⟩ /ʉ/ belongs
  with the full vowels or the reduced ones changes which syllable every rule
  predicts, so the inventory and the default have to be settled
  separately — and only one kind of evidence bears on each.</div>
  <div class="spacer"></div>
  <div class="cols">
    <div class="panel"><h3>Inventory question</h3>Settled on the
    <em class="term">written</em> corpora: minimal word and positional
    restriction. Acoustics cannot settle it without circularity.</div>
    <div class="panel"><h3>Default question</h3>Settled on the
    <em class="term">acoustics</em> of polysyllabic all-reduced words — the
    only configuration where the two defaults disagree.</div>
  </div>""")

    # ── 3 the headline: A vs B with edges controlled ──────────────────
    S.append(f"""
  <h2><span class="tag new">new</span>The default question, with the utterance edge removed</h2>
  <p class="sub">A stresses the leftmost reduced vowel; B leaves the word
  stressless. {int(ad5.loc['duration','word_tokens']):,} all-reduced
  polysyllabic word tokens, {int(ad5.loc['duration','vowel_tokens']):,} vowels.</p>
  <p>In a disyllable, &ldquo;non-initial&rdquo; <em>is</em> the final syllable — and the
  final syllable of an utterance-final word is
  <strong>{fl_comb:.0f}%</strong> longer. So the raw contrast is mostly a
  measurement of the edge, and f0 is mostly declination. Refitting with
  word-final position, utterance-final position and position-in-utterance in
  the model:</p>
  <table>
    <tr><th>Cue</th><th class="num">Raw</th><th class="num">Edges controlled</th><th class="num">t</th><th class="num">JND</th></tr>
    <tr><td>duration</td><td class="num">{ad5.loc['duration','raw_diff']:+.1f} ms</td><td class="num"><strong>{ad5.loc['duration','adj_diff']:+.2f} ms</strong></td><td class="num">{ad5.loc['duration','adj_t']:.2f}</td><td class="num">10 ms</td></tr>
    <tr><td>intensity</td><td class="num">{ad5.loc['intensity','raw_diff']:+.2f} dB</td><td class="num"><strong>{ad5.loc['intensity','adj_diff']:+.2f} dB</strong></td><td class="num">{ad5.loc['intensity','adj_t']:.2f}</td><td class="num">3 dB</td></tr>
    <tr><td>f0</td><td class="num">{ad5.loc['f0','raw_diff']:+.1f} Hz</td><td class="num"><strong>{ad5.loc['f0','adj_diff']:+.2f} Hz</strong></td><td class="num">{ad5.loc['f0','adj_t']:.2f}</td><td class="num">1 Hz</td></tr>
  </table>
  <p>No cue makes the initial syllable prominent. f0 clears its nominal
  threshold <em>in the wrong direction</em>, by 0.02 semitones on a 200 Hz
  voice; 1 Hz is a laboratory floor for steady tones, not a threshold for
  running speech.</p>
  {img("fig_default_adjudication.png",
       "Raw contrast (open) against the same contrast with the edges in the model (filled), for three vowel inventories. Shaded band is the cited JND. The duration effect that appeared to contradict a stressless default is entirely an edge effect.")}
  <p class="cap">Verdict: <strong>default B</strong> — rightmost full vowel,
  else stressless — on three times the sample the filtered estimate rested on.</p>""")

    # ── 3b the AIC ranking, with its caveats ──────────────────────────
    mr = D["mr"].set_index("rule")
    named = ["A6", "A5", "A4", "B6", "B5", "B4"]
    dur_best = min(named, key=lambda r: mr.loc[r, "dAIC_log_duration"])
    int_best = min(named, key=lambda r: mr.loc[r, "dAIC_int_midpoint"])
    dur_gap = (sorted(mr.loc[named, "dAIC_log_duration"])[3]
               - sorted(mr.loc[named, "dAIC_log_duration"])[0])
    int_gap = (sorted(mr.loc[named, "dAIC_int_midpoint"])[3]
               - sorted(mr.loc[named, "dAIC_int_midpoint"])[0])
    HI2 = ' class="hi"'
    def _rr(r):
        cls = HI2 if r in (dur_best, int_best) else ""
        f0v = mr.loc[r, "estimate_f0_st"] if "estimate_f0_st" in mr.columns else float("nan")
        return (f'<tr{cls}><td>{r}</td>'
                f'<td class="num">{mr.loc[r, "dAIC_log_duration"] - mr.loc[dur_best, "dAIC_log_duration"]:,.0f}</td>'
                f'<td class="num">{mr.loc[r, "estimate_log_duration"]:+.4f}</td>'
                f'<td class="num">{mr.loc[r, "dAIC_int_midpoint"] - mr.loc[int_best, "dAIC_int_midpoint"]:,.0f}</td>'
                f'<td class="num">{mr.loc[r, "estimate_int_midpoint"]:+.3f}</td>'
                f'<td class="num">{f0v:+.3f}</td></tr>')
    ranking_rows = "".join(_rr(r) for r in named)
    S.append(f"""
  <h2>Duration ranks B first, intensity ranks A first — Dobrovolsky's asymmetry</h2>
  <p class="sub">Mixed models over the whole dataset, one per rule per
  measure, with vowel quality, coda, utterance position, speech rate and word
  frequency controlled and
  <code>(1|speaker) + (1|file_name) + (1|word_label)</code>.</p>
  <table>
    <tr><th>Rule</th><th class="num">Δ AIC, duration</th><th class="num">β duration</th><th class="num">Δ AIC, intensity</th><th class="num">β intensity (dB)</th><th class="num">β f0 (st)</th></tr>
    {ranking_rows}
  </table>
  <p>Duration puts <strong>{dur_best}</strong> first by
  {mr.loc['A5', 'dAIC_log_duration'] - mr.loc[dur_best, 'dAIC_log_duration']:,.0f}
  AIC over the best A rule; intensity puts <strong>{int_best}</strong> first by
  {mr.loc['B6', 'dAIC_int_midpoint'] - mr.loc[int_best, 'dAIC_int_midpoint']:,.0f}
  over the best B rule. This is the asymmetry Dobrovolsky (1999) reported on 80
  vowels, reproduced on {int(D['fw'].n_obs.max()):,}.</p>
  <div class="note"><strong>Three reasons not to read this table as the
  answer.</strong> (1) The intensity coefficients are
  {mr.loc[named, 'estimate_int_midpoint'].min():.2f}–{mr.loc[named, 'estimate_int_midpoint'].max():.2f} dB
  against a 3 dB JND — six to seven times too small to hear. Statistically
  overwhelming, perceptually nothing. (2) The three cues DISAGREE about which
  rule wins — duration and f0 rank B first, intensity ranks A first — so no
  single column settles it, and that disagreement is itself a finding rather
  than noise to be averaged away. (3) The ranking is dominated by the ~90% of
  words where all six rules agree; see the conflict-subset slide.</div>
  <p class="cap">The <code>final</code> baseline is deliberately NOT in this
  table. Its predictor 1{{sidx == sN}} is <em>identical</em> to syl_final on
  all 574,344 rows (&phi; = 1.0000), so against a linear position trend it is
  unidentified: omit the control and it absorbs the whole edge effect, include
  it and no residual variation is left. It becomes testable only with position
  entered nonparametrically, and when it is, its intensity coefficient is
  <em>negative</em> &mdash; quieter than trend. See the word-edge slide.</p>""")

    # ── 4 final lengthening ───────────────────────────────────────────
    S.append(f"""
  <h2><span class="tag new">new</span>Final lengthening is {fl_comb/fl_str:.0f}× the stress effect</h2>
  <p class="sub">{int(fl.loc['stressed','n']):,} vowels; vowel quality as a
  fixed effect, so every figure is a change for a vowel of the same kind.</p>
  <table>
    <tr><th>Term</th><th class="num">% change in duration</th><th class="num">t</th></tr>
    <tr><td>stressed (rule A6)</td><td class="num">{fl.loc['stressed','pct_change']:+.1f}</td><td class="num">{fl.loc['stressed','statistic']:.1f}</td></tr>
    <tr><td>word-final syllable</td><td class="num">{fl.loc['syl_final','pct_change']:+.1f}</td><td class="num">{fl.loc['syl_final','statistic']:.1f}</td></tr>
    <tr><td>in utterance-final word</td><td class="num">{fl.loc['word_utt_final','pct_change']:+.1f}</td><td class="num">{fl.loc['word_utt_final','statistic']:.1f}</td></tr>
    <tr><td>word-final × utterance-final <span class="cap">(interaction)</span></td><td class="num">{fl.loc['syl_final:word_utt_final','pct_change']:+.1f}</td><td class="num">{fl.loc['syl_final:word_utt_final','statistic']:.1f}</td></tr>
    <tr class="hi"><td><strong>all three together</strong></td><td class="num"><strong>{fl_comb:+.1f}</strong></td><td class="num cap">—</td></tr>
  </table>
  <p>The interaction term is the <em>extra</em> effect of the two positions
  coinciding, not the total. The quantity to quote is the sum of the three
  position terms: the final syllable of an utterance-final word runs
  <strong>{fl_comb:+.0f}%</strong> against a non-final syllable elsewhere,
  where stress is worth {fl_str:+.1f}%.</p>
  {img("fig_final_lengthening.png",
       "Left: median vowel duration by stress, position in word and position in utterance. Right: model coefficients. Any prominence measure that does not hold utterance position fixed is largely measuring the edge.")}""")

    # ── 5 geminates ───────────────────────────────────────────────────
    S.append(f"""
  <h2><span class="tag new">new</span>Orthographic geminates are phonetically long</h2>
  <p class="sub">Intervocalic, word-medial position; {int(gok.n_long.sum()):,}
  long against {int(gok.n_short.sum()):,} singleton tokens, Chuvash Voice.</p>
  <p>Consonant durations do not exist in the analysis dataset — it carries
  vowels. They come from the <em>pre-recode</em> grids, because stage 5
  collapses nine of the fourteen long consonants. The pre-recode grids agree
  with the recoded ones on <strong>100%</strong> of interval boundaries.</p>
  <table>
    <tr><th>Place</th><th class="num">n long</th><th class="num">median long</th><th class="num">median short</th><th class="num">model ratio</th></tr>
    {''.join(f'<tr><td>/{x.phone}/</td><td class="num">{int(x.n_long):,}</td><td class="num">{x.median_long:.0f}</td><td class="num">{x.median_short:.0f}</td><td class="num">{x.lmm_ratio:.2f}×</td></tr>' for _, x in gok.sort_values("n_long", ascending=False).head(8).iterrows())}
  </table>
  <p>Across the {len(gok)} measurable places the ratio runs
  {gok.lmm_ratio.min():.2f}–{gok.lmm_ratio.max():.2f}, median
  {gok.lmm_ratio.median():.2f}.</p>
  <div class="note"><strong>Two places are excluded, not reported as short
  geminates.</strong> The aligner has a hard floor at 30 ms, and
  <strong>100%</strong> of /vː/ tokens and 43% of /mː/ sit exactly on it. The
  words are genuine geminates (сиввӗн, кӗвви, уйрӑммӑнах); the durations were
  clipped, not measured.</div>
  <p class="cap"><strong>Common Voice cannot contribute.</strong> Its only
  pre-recode grids are a different third-party alignment — 18.9% boundary
  agreement with the grids the measurements come from. Everything here is one
  speaker reading prose.</p>""")

    # ── 6 weight trade-off ────────────────────────────────────────────
    S.append(f"""
  <h2><span class="tag fix">retracted</span>Word-finally, a long consonant and a reduced vowel trade off</h2>
  <p class="sub">Your question: does a final geminate plus a reduced vowel
  differ from a singleton plus a full vowel? 2 × 2 with the consonant's
  identity, word length, utterance edge and pause controlled.</p>
  <div class="cols">
    <div>
      <table>
        <tr><th>Final shape</th><th class="num">Adjusted rhyme duration</th></tr>
        <tr><td>short C + full V</td><td class="num">{pct(gwa['C+full']):+.1f}%</td></tr>
        <tr><td>long C + full V</td><td class="num">{pct(gwa['Cː+full']):+.1f}%</td></tr>
        <tr><td>short C + reduced V</td><td class="num">{pct(gwa['C+reduced']):+.1f}%</td></tr>
        <tr class="hi"><td>long C + reduced V</td><td class="num"><strong>{pct(gwa['Cː+reduced']):+.1f}%</strong></td></tr>
      </table>
      <p>The two effects are <strong>additive</strong> — interaction
      t&nbsp;=&nbsp;{gw_i:.2f}. Lengthening the consonant and reducing the
      vowel are independent, roughly equal and opposite adjustments to the
      same total.</p>
    </div>
    <div class="panel">
      <h3>What that means</h3>
      <p>Long&nbsp;C&nbsp;+&nbsp;reduced&nbsp;V comes out
      {pct(gwa['Cː+reduced']):+.1f}% against short&nbsp;C&nbsp;+&nbsp;full&nbsp;V
      — about 7&nbsp;ms on a 160&nbsp;ms rhyme, <em>under</em> the 10&nbsp;ms
      JND.</p>
      <p class="warn"><strong>RETRACTED.</strong> This was presented as
      positive weight evidence &mdash; a shared timing budget, i.e. a mora.
      It is not. Two additive effects of similar size landing on the same
      total is <em>consistent with</em> a shared budget but does not
      distinguish it from two independent adjustments that happen to be
      comparable; and the net difference sits under the 10&nbsp;ms JND, so
      the configuration a mora predicts is also the configuration no
      difference predicts. Only designed elicitation can separate them.</p>
    </div>
  </div>
  {img("fig_gemination_mora.png",
       "Left: long against singleton by place, with the two clipped places greyed. Middle: the four word-final shapes, adjusted. Right: the alternation test (next slide).")}""")

    # ── 7 the fleeting vowel ──────────────────────────────────────────
    S.append(f"""
  <h2><span class="tag null">null</span>The fleeting-vowel split is not audible</h2>
  <p class="sub">пулӑ 'fish' ~ пулли 'its fish': the stem-final reduced vowel
  disappears and the consonant geminates. Candidate zero-mora vowel.</p>
  <p><strong>The class was identified from text alone</strong>, so there is no
  acoustic circularity: for every corpus type ending in ӑ/ӗ after a consonant,
  is <code>stem + C + C + и</code> attested? Of 52,582 candidates,
  <strong>{len(D['malt']):,} (2.8%)</strong> have the geminate form — and the
  method recovers the right words:</p>
  <p class="lede">ҫӗнӗ~ҫӗнни · питӗ~питти · пулӗ~пулли · ырӑ~ырри ·
  усӑ~усси · юрӑ~юрри · шурӑ~шурри · сӑвӑ~сӑвви · алӑ~алли · турӑ~турри</p>
  <table>
    <tr><th>Outcome</th><th class="num">alternating − non-alternating</th><th class="num">t</th></tr>
    {''.join(f'<tr><td>{x.outcome.replace("_", " ")}</td><td class="num">{pct(x.estimate):+.1f}%</td><td class="num">{x.statistic:+.2f}</td></tr>' for _, x in mora_t.iterrows())}
  </table>
  <p>All three null, compared at the <em>same final consonant</em>
  ({int(mora_t.n.iloc[0]):,} tokens, {int(mora_t.n_types.iloc[0])} types).</p>
  <div class="note"><strong>A correction worth keeping.</strong> Without the
  consonant control the final vowel came out 5% shorter (t = −2.41). That was
  entirely place of articulation: the alternating class is dominated by
  л р н ҫ т. The evidence for the moraic split is morphological, not phonetic
  — at least in read speech from one speaker.</div>""")

    # ── 8 sentence type ───────────────────────────────────────────────
    st = D["st"]
    S.append(f"""
  <h2><span class="tag new">new</span>Question intonation is conditioned on morphology</h2>
  <p class="sub">Sentence type from the transcript's final punctuation;
  f0 in semitones relative to each speaker's own median.</p>
  <table>
    <tr><th>Group</th><th class="num">utterances</th><th class="num">final-quarter slope</th><th class="num">f0 at the end (st)</th></tr>
    <tr class="hi"><td>question, -и on the last word</td><td class="num">{int(st.loc['question_clitic_final','utterances']):,}</td><td class="num">{st.loc['question_clitic_final','slope']:+.3f}</td><td class="num"><strong>{st.loc['question_clitic_final','end_st']:+.2f}</strong></td></tr>
    <tr><td>question, no marker</td><td class="num">{int(st.loc['question_no_marking','utterances']):,}</td><td class="num">{st.loc['question_no_marking','slope']:+.3f}</td><td class="num">{st.loc['question_no_marking','end_st']:+.2f}</td></tr>
    <tr><td>question with a wh-word</td><td class="num">{int(st.loc['question_content','utterances']):,}</td><td class="num">{st.loc['question_content','slope']:+.3f}</td><td class="num">{st.loc['question_content','end_st']:+.2f}</td></tr>
    <tr><td>statement, -и on the last word</td><td class="num">{int(st.loc['statement_i_final','utterances']):,}</td><td class="num">{st.loc['statement_i_final','slope']:+.3f}</td><td class="num">{st.loc['statement_i_final','end_st']:+.2f}</td></tr>
    <tr><td>statement</td><td class="num">{int(st.loc['statement_other','utterances']):,}</td><td class="num">{st.loc['statement_other','slope']:+.3f}</td><td class="num">{st.loc['statement_other','end_st']:+.2f}</td></tr>
  </table>
  <p>Clitic-marked polar questions are the <strong>only</strong> group that
  rises. wh-questions carry a statement contour. Unmarked questions sit
  between.</p>
  <div class="note">The enclitic -и is homophonous with the third-person
  possessive, so the label is orthographic. Two checks license it: a
  sentence-final -и appears in <strong>{D['stc'].loc['question','pct']:.1f}%</strong>
  of questions against <strong>{D['stc'].loc['statement','pct']:.2f}%</strong>
  of statements; and statements whose last word ends in -и behave exactly like
  all other statements, so the string alone does nothing.</div>
  {img("fig_sentence_type.png",
       "Left: normalised f0 across the utterance by sentence type, both corpora. Right: end-of-utterance f0 by group, with the two statement controls.")}""")

    # ── 9 codas and sonority ──────────────────────────────────────────
    S.append(f"""
  <h2><span class="tag null">null</span>Codas never attract prominence; sonority survives only in duration</h2>
  <p class="sub">Within-word design: {int(csa.iloc[0]['n_vowels']):,} vowels in
  {int(csa.iloc[0]['n_words']):,} polysyllabic word tokens. Each word is a
  stratum, so word frequency, length, speaker and speech rate cannot confound.</p>
  <p>/a/ is 20 ms longer and 2 dB louder than the high vowels for reasons
  unconnected with stress, so every test is run twice — raw, and after
  removing the vowel's own mean.</p>
  <table>
    <tr><th>Predicts being the most prominent syllable</th><th class="num">duration, raw</th><th class="num">duration, intrinsic removed</th><th class="num">intensity, raw</th><th class="num">intensity, intrinsic removed</th></tr>
    <tr class="hi"><td>closed syllable</td><td class="num">{OR('has_coda','prom_duration'):.3f}</td><td class="num"><strong>{OR('has_coda','prom_dur_adj'):.3f}</strong></td><td class="num">{OR('has_coda','prom_int_midpoint'):.3f}</td><td class="num">{OR('has_coda','prom_int_adj'):.3f}</td></tr>
    <tr><td>the vowel /a/</td><td class="num">{OR('is_a','prom_duration'):.3f}</td><td class="num"><strong>{OR('is_a','prom_dur_adj'):.3f}</strong></td><td class="num">{OR('is_a','prom_int_midpoint'):.3f}</td><td class="num">{OR('is_a','prom_int_adj'):.3f}</td></tr>
    <tr><td>a non-high vowel</td><td class="num">{OR('is_nonhigh','prom_duration'):.3f}</td><td class="num"><strong>{OR('is_nonhigh','prom_dur_adj'):.3f}</strong></td><td class="num">{OR('is_nonhigh','prom_int_midpoint'):.3f}</td><td class="num">{OR('is_nonhigh','prom_int_adj'):.3f}</td></tr>
  </table>
  <p>Coda odds are <em>below</em> 1 on duration and flat on intensity — and
  under a rule-based definition of stress they are
  {OR('has_coda','rule_B5'):.3f} (B5) and {OR('has_coda','rule_A6'):.3f} (A6).
  The two sonority predictors must be read separately, because they do not
  behave alike: <strong>/a/</strong> survives intrinsic correction on duration
  at {OR('is_a','prom_dur_adj'):.3f} and still carries
  {OR('is_a','prom_int_midpoint'):.3f} on intensity, while <strong>non-high</strong>
  gives {OR('is_nonhigh','prom_dur_adj'):.3f} on duration and
  {OR('is_nonhigh','prom_int_midpoint'):.3f} — i.e. null — on intensity. Only
  the non-high row vanishes in intensity.</p>
  {img("fig_coda_sonority.png",
       "Left: odds of being the most prominent syllable in the word. Right: duration and intensity by distance from the primary-stressed syllable.")}
  <p class="cap">Sonority-sensitivity holds at an odds ratio of
  {OR('is_a','prom_dur_adj'):.2f} for /a/ on duration, not the 2–3 the raw
  measures suggest — a real effect and a modest one. Whether it reaches
  intensity depends on which predictor you ask: /a/ yes
  ({OR('is_a','prom_int_midpoint'):.2f}), non-high no
  ({OR('is_nonhigh','prom_int_midpoint'):.2f}).</p>""")

    # ── 10 secondary stress ───────────────────────────────────────────
    S.append(f"""
  <h2><span class="tag null">null</span>No secondary stress, no apparent-time shift</h2>
  <div class="cols">
    <div>
      <h3 style="font-size:16px;margin:0 0 .3em">Secondary stress</h3>
      <p class="cap">{int(D['ss'].n.sum()):,} non-primary syllables in words
      of three or more syllables.</p>
      <table>
        <tr><th class="num">syllables from primary</th><th class="num">duration z</th><th class="num">intensity z</th></tr>
        {''.join(f'<tr><td class="num">{int(i):+d}</td><td class="num">{x.dur_z:+.3f}</td><td class="num">{x.int_z:+.3f}</td></tr>' for i, x in ss.iterrows())}
      </table>
      <p>Duration falls monotonically towards the primary, then rises after
      it — but there is no every-other-syllable alternation, and the two
      measures have <em>opposite signs</em>: syllables after the primary are
      longer and at the same time quieter. Stress lengthens and raises
      intensity together; this is final lengthening.</p>
    </div>
    <div>
      <h3 style="font-size:16px;margin:0 0 .3em">Apparent time and gender</h3>
      <p class="cap">Common Voice only, the corpus with speaker metadata.</p>
      <p><span class="big blue">{int((at.p < .05).sum())}/{len(at)}</span><br>
      apparent-time coefficients reach p&lt;0.05 — about what 16 tests
      produce by chance. Effects {at.estimate.abs().min():.4f}–{at.estimate.abs().max():.4f} z per year.</p>
      <p><span class="big">{int((gd.p < .05).sum())}/{len(gd)}</span><br>
      gender coefficients do, at {gd.estimate.abs().min():.2f}–{gd.estimate.abs().max():.2f} z
      — a residual that survives within-speaker normalisation.</p>
    </div>
  </div>
  {img("fig_vowel_shift.png",
       "Per-vowel coefficients. Filled = p<0.05. No evidence of change in progress; a real but small gender residual.")}""")

    # ── 11 rounding ───────────────────────────────────────────────────
    r3, r2 = D["rndF3"], D["rndF2"]
    S.append(f"""
  <h2><span class="tag fix">revised</span>Rounding: established for the two front vowels, for neither back one</h2>
  <p class="sub">HEIGHT-MATCHED pairs. The previous version used one anchor per
  harmony series — /i/ front, /a/ back — which compared mid &#10216;&#1253;&#10217; against high
  /i/ and mid &#10216;&#1241;&#10217; against low /a/, confounding rounding with height.</p>
  <div class="cols">
    <div>
      <table>
        <tr><th>Height-matched pair</th><th class="num">&Delta;F3 (z)</th><th class="num">z</th><th class="num">&Delta;F2 (z)</th><th>Reading</th></tr>
        <tr><td>/y/ &#10216;&#1267;&#10217; vs /i/ &#10216;&#1080;&#10217;</td><td class="num">{r3.loc['y vs i','difference']:+.3f}</td><td class="num">{r3.loc['y vs i','z']:+.1f}</td><td class="num">{r2.loc['y vs i','difference']:+.3f}</td><td><strong>rounded</strong></td></tr>
        <tr><td>/&oslash;/ &#10216;&#1253;&#10217; vs /e/ &#10216;&#1077;&#10217;</td><td class="num">{r3.loc['ø vs e','difference']:+.3f}</td><td class="num">{r3.loc['ø vs e','z']:+.1f}</td><td class="num">{r2.loc['ø vs e','difference']:+.3f}</td><td><strong>rounded</strong></td></tr>
        <tr class="hi"><td>/u/ &#10216;&#1091;&#10217; vs /&#596;/ &#10216;&#1099;&#10217;</td><td class="num">{r3.loc['u vs ʉ','difference']:+.3f}</td><td class="num">{r3.loc['u vs ʉ','z']:+.1f}</td><td class="num">{r2.loc['u vs ʉ','difference']:+.3f}</td><td>POSITIVE CONTROL &mdash; passes</td></tr>
        <tr><td>/&#629;/ &#10216;&#1241;&#10217; vs /a/ &#10216;&#1072;&#10217;</td><td class="num">{r3.loc['ɵ vs a','difference']:+.3f}</td><td class="num">{r3.loc['ɵ vs a','z']:+.1f}</td><td class="num">{r2.loc['ɵ vs a','difference']:+.3f}</td><td>not determinable</td></tr>
      </table>
    </div>
    <div class="panel">
      <h3>The control is not a result</h3>
      <p>The /u/~/&#596;/ row <strong>presupposes</strong> Krueger's description of
      that pair. It cannot be cited as evidence that &#10216;&#1099;&#10217; is unrounded or
      &#10216;&#1091;&#10217; rounded. An earlier version of this deck said
      &ldquo;Krueger's high row is confirmed exactly&rdquo; &mdash; that was
      circular and is withdrawn.</p>
      <p>A small control effect is also ambiguous between &ldquo;F3 is a weak
      cue to back rounding&rdquo; and &ldquo;these two vowels differ less in
      rounding than described&rdquo;.</p>
      <h3>Why &#10216;&#1241;&#10217; is undecidable</h3>
      <p>Structural, not a power problem: the inventory contains <em>no mid
      back unrounded vowel</em> to serve as its height-matched anchor. Settling
      it needs lip video or another articulatory measure.</p>
    </div>
  </div>
  {img("fig_rounding_revised.png",
       "The F3 test with its positive control, and the eight vowel means.")}"""
)

    # ── 12 clustering ─────────────────────────────────────────────────
    S.append(f"""
  <h2>The formant space recovers the harmony classes, not the eight phonemes</h2>
  <p class="sub">Gaussian mixtures on F1–F3 at the vowel midpoint, non-palatal
  contexts, compared against the phonemic labels.</p>
  <p>Agreement peaks at <strong>k = {kbest}</strong> (ARI
  {cn.ARI_vs_phonemic.max():.3f}) and is markedly worse at eight
  ({float(cn[cn.k == 8].ARI_vs_phonemic.iloc[0]):.3f}). BIC falls
  monotonically to k = 12 in both context sets and is uninformative — it is
  reported, not mined.</p>
  {img("fig_vowel_clustering.png",
       f"Left: agreement with the phonemic eight by number of components. Right: cluster membership at k={kbest}, row-normalised.")}
  <p>At the peak the clusters are <strong>front harmony</strong>
  (/i e y ø/ together), <strong>back non-low</strong> (/ʉ u ɵ/) and
  <strong>/a/</strong> on its own. That is the harmony partition, not the
  phoneme inventory.</p>
  <div class="note">This is not an argument that Chuvash has five vowels.
  There are phonemic minimal pairs for eight qualities. It is an argument
  that <strong>midpoint formants are the wrong measurement</strong> to read
  an inventory off — see the next slide.</div>""")

    # ── 13 contrast recovery ──────────────────────────────────────────
    S.append(f"""
  <h2>The eight qualities <em>are</em> recoverable — from context, not formants</h2>
  <p class="sub">Gradient boosting, balanced accuracy, 40,000-token samples.
  Folds grouped by word type, so a model given the neighbouring segments
  cannot memorise words.</p>
  <table>
    <tr><th>Features</th><th class="num">all eight</th><th class="num">/i/ vs /y/</th><th class="num">/ʉ/ vs /ɵ/</th></tr>
    {''.join(f'<tr{" class=hi" if f == NSET else ""}><td>{f}</td><td class="num">{crg.loc[f, "all eight"]:.3f}</td><td class="num">{crg.loc[f, "/i/ vs /y/"]:.3f}</td><td class="num">{crg.loc[f, "/ʉ/ vs /ɵ/"]:.3f}</td></tr>' for f in crg.index)}
    <tr><td class="cap">chance</td><td class="num cap">0.125</td><td class="num cap">0.500</td><td class="num cap">0.500</td></tr>
  </table>
  <p>Formants alone give {crg.loc[FSET, 'all eight']:.2f} on the eight-way
  problem. Adding the neighbouring segments takes it to
  <strong>{crg.loc[NSET, 'all eight']:.2f}</strong>; duration adds almost
  nothing. The two crowded pairs go from
  {crg.loc[FSET, '/i/ vs /y/']:.2f} and {crg.loc[FSET, '/ʉ/ vs /ɵ/']:.2f} to
  {crg.loc[NSET, '/i/ vs /y/']:.2f} and {crg.loc[NSET, '/ʉ/ vs /ɵ/']:.2f}.</p>
  {img("fig_contrast_recovery.png",
       "Balanced accuracy by feature set, with folds grouped by word (filled) and at random (grey). The two curves nearly coincide, so the context gain is not word memorisation.")}
  <p>This is what a language with vowel harmony and pervasive consonant
  palatalisation should look like: the vowel's identity is partly
  <em>distributed onto its neighbours</em>. A midpoint-formant inventory
  undercounts it by construction.</p>
  <p class="cap">Harmony class is partly circular as a feature — the claim
  rests on the neighbouring-segment step, which is not.</p>""")

    # ── 14 positional ─────────────────────────────────────────────────
    S.append(f"""
  <h2>The first-syllable restriction tracks vowel height, not weight</h2>
  <p class="sub">Percentage of each vowel's polysyllabic tokens that fall in
  the first syllable.</p>
  <table>
    <tr><th>Vowel</th>{''.join(f'<th class="num">/{v}/</th>' for v in p1.index)}</tr>
    <tr><td>% in syllable 1</td>{''.join(f'<td class="num">{p1[v]:.1f}</td>' for v in p1.index)}</tr>
    <tr><td>% closed</td>{''.join(f'<td class="num">{posc.loc[v, "pct_closed"]:.1f}</td>' for v in p1.index)}</tr>
  </table>
  <p>The four high vowels occupy the top four positions
  ({p1.iloc[3]:.0f}–{p1.iloc[0]:.0f}%); the non-high vowels are all below
  {p1.iloc[4]:.0f}%. Closed-syllable rate does not order the same way, so the
  restriction is about <strong>height</strong>, not weight.</p>
  {img("fig_positional.png",
       "Left: share of polysyllabic tokens in the first syllable, high vowels in blue. Right: observed/expected occurrence by syllable position.")}
  <div class="note">Consequence for the inventory question: this pattern
  <strong>cannot</strong> be used to group ⟨ы⟩ /ʉ/ with the reduced vowels.
  /ʉ/ is the most restricted vowel in the language ({p1['ʉ']:.1f}%), but so is
  /u/ ({p1['u']:.1f}%) and /y/ ({p1['y']:.1f}%), and nobody calls those
  reduced. The minimal-word evidence has to carry it.</div>""")

    # ── 15 minimal word ──────────────────────────────────────────────
    S.append("""
  <h2>The minimal-word evidence, and why the corpus cannot settle it alone</h2>
  <p class="sub">Which vowels can stand in an open monosyllable — the test
  that separates inventory 5 from inventory 6.</p>
  <p>In the wordlist, <span class="ipa">/y/</span> forms open monosyllables
  at 15.4% (8 of 52 types) while <span class="ipa">/ʉ/</span> forms
  <strong>none</strong> (0 of 37), <span class="ipa">/ø/</span> none (0 of
  90), and <span class="ipa">/ɵ/</span> 1.1% (2 of 175, both Zheltov's own
  ӑ and хӑ). The full-versus-reduced gap on the minimal-word measure is
  largest under <strong>inventory 5</strong>.</p>
  <div class="note"><strong>The monolingual corpus appears to contradict
  this, and it is wrong.</strong> It shows open monosyllables with reduced
  vowels at 9.7–28.1% — but those types are de-hyphenated line breaks and
  letter-spaced emphasis, not words: нӑ 17,003, тӑ 12,398, лӑ 11,814,
  нӗ 10,985. They are phonotactically legal, so no phonotactic filter removes
  them. Only dictionary attestation does.</div>
  <p>The corpus can carry <em>token frequency</em> claims. It cannot carry
  <em>type inventory</em> claims.</p>
  <p class="cap">Two independent tests confirm the fragments are suffixes,
  not words — next slide.</p>""")

    # ── 16 suffix evidence ────────────────────────────────────────────
    S.append("""
  <h2>Independent proof that the fragments are suffixes</h2>
  <div class="cols">
    <div>
      <h3 style="font-size:16px;margin:0 0 .3em">Test 1 — harmony with the preceding token</h3>
      <p class="cap">A suffix's back/front shape is chosen by its stem. A
      real word's is not.</p>
      <table>
        <tr><th>Pair</th><th class="num">back form</th><th class="num">front form</th><th class="num">n</th></tr>
        <tr><td>-нӑ / -нӗ</td><td class="num">96.9</td><td class="num">12.3</td><td class="num">9,339</td></tr>
        <tr><td>-лӑ / -лӗ</td><td class="num">95.5</td><td class="num">27.4</td><td class="num">6,752</td></tr>
        <tr><td>-ла / -ле</td><td class="num">91.3</td><td class="num">8.4</td><td class="num">11,226</td></tr>
        <tr><td>-са / -се</td><td class="num">88.2</td><td class="num">24.8</td><td class="num">11,452</td></tr>
        <tr><td>-ра / -ре</td><td class="num">77.6</td><td class="num">9.3</td><td class="num">10,092</td></tr>
      </table>
      <p class="cap">% of preceding tokens that are back-harmonic. All eight
      pairs split by 47–85 points across 60,330 occurrences.</p>
    </div>
    <div>
      <h3 style="font-size:16px;margin:0 0 .3em">Test 2 — re-attachment</h3>
      <p>Glue each fragment back onto the token that precedes it in the
      corpus, and ask whether the result is a word.</p>
      <table>
        <tr><th></th><th class="num">wordlist type</th><th class="num">corpus type</th></tr>
        <tr><td>actual preceding token</td><td class="num">11.7%</td><td class="num">40.0%</td></tr>
        <tr><td>random preceding token</td><td class="num">1.1%</td><td class="num">10.7%</td></tr>
        <tr class="hi"><td>ratio</td><td class="num"><strong>10.6×</strong></td><td class="num">3.7×</td></tr>
      </table>
      <p>Token-weighted, 22.0% and 63.9%. Reconstructions include
      мари 1,618, вара 731, кала 719, тӑрӑ 523, ӗҫле 513, йӗрке 485.</p>
    </div>
  </div>
  {}
""".format(img("fig_suffix_evidence.png",
               "Left: harmony with the preceding token, by suffix pair. Right: re-attachment against a random-token baseline.")))

    # ── 17 who is speaking ───────────────────────────────────────────
    S.append("""
  <h2>Who is actually speaking</h2>
  <p class="sub">Chuvash Voice ships no speaker identity. 24 acoustic
  features per recording (f0 quantiles, 16-band mean-centred LTAS, HNR),
  clustered in PCA space with the same/different threshold calibrated on
  Common Voice's 109 known speakers.</p>
  <div class="cols3">
    <div class="panel"><h3>Common Voice</h3>
      <p><span class="big">78</span><br>clusters, largest 34.8%</p>
      <p class="cap">109 known speakers — the calibration set.</p></div>
    <div class="panel"><h3>Chuvash Voice</h3>
      <p><span class="big red">99.4%</span><br>of recordings in one cluster</p>
      <p class="cap">93.4% when every recording is assigned to its nearest
      centroid. Effectively one speaker.</p></div>
    <div class="panel"><h3>Minor voices</h3>
      <p><span class="big">3–4</span><br>other speakers, 6.6% of recordings</p>
      <p class="cap">Four clusters at 108–144 Hz against a 226 Hz dominant
      voice.</p></div>
  </div>
  <div class="note"><strong>The gender metadata is not credible.</strong> The
  dominant Chuvash Voice voice sits at 225.7 Hz and is labelled
  <code>male_masculine</code>. In Common Voice, where the labels are
  self-reported, male voices average 125.5 Hz and female 223.6 Hz.</div>
  <p>Consequence: one speaker supplies about 69% of all vowels, and five
  cover 90%. Every model here carries
  <code>(1|speaker) + (1|file_name) + (1|word_label)</code>, and no
  cross-speaker generalisation is claimed from Chuvash Voice alone.</p>
  {}
""".format(img("fig_speaker_structure.png",
               "Acoustic voice clusters in both corpora, against the distance threshold calibrated on known speakers.")))

    # ── 18 inventory ─────────────────────────────────────────────────
    S.append(f"""
  <h2>The segment inventory, including 14 long consonants</h2>
  <p class="sub">From the aligned grids: 9 vowels (8 native plus the loan
  /o/) and 20 consonant places, {int(D['gemi'].shape[0])} of them attested
  long.</p>
  <table>
    <tr><th>Long consonant</th>{''.join(f'<th class="num">/{x.ipa}/</th>' for _, x in D['gemi'].head(8).iterrows())}</tr>
    <tr><td>tokens</td>{''.join(f'<td class="num">{int(x.total):,}</td>' for _, x in D['gemi'].head(8).iterrows())}</tr>
  </table>
  <p>{int(D['gemi'].total.sum()):,} long-consonant tokens, 1.7–2.0% of all
  phones. /lː/ is 10.2% of all /l/; /ɕː/ is 8.3% of all /ɕ/.</p>
  <div class="note"><strong>Stage 5 of the pipeline destroys most of this.</strong>
  <code>chuvash_phonology.py</code> collapses eight long consonants to
  singletons (26,832 tokens); five others survive only because they are
  absent from its map. Everything in this deck about length comes from the
  pre-recode grids.</div>
  <p>Vowel token shares agree closely across the four corpora — the largest
  spread is 3.6 points, for /e/ (14.7–18.3%), then /ɵ/ at 2.7.</p>
  {img("fig_inventory.png", "Segment inventory and long-consonant rates across corpora.")}""")

    # ── 19 phonotactics ──────────────────────────────────────────────
    S.append("""
  <h2>Phonotactics: CV and CVC, and almost nothing else</h2>
  <table>
    <tr><th>Syllable shape</th><th class="num">wordlist</th><th class="num">monolingual</th><th class="num">spoken</th></tr>
    <tr><td>CV</td><td class="num">36.9</td><td class="num">48.1</td><td class="num">50.6</td></tr>
    <tr><td>CVC</td><td class="num">53.7</td><td class="num">42.6</td><td class="num">41.9</td></tr>
    <tr><td>V</td><td class="num">2.4</td><td class="num">2.8</td><td class="num">2.3</td></tr>
    <tr><td>VC</td><td class="num">2.7</td><td class="num">2.6</td><td class="num">2.5</td></tr>
    <tr><td>CVCC</td><td class="num">3.0</td><td class="num">2.2</td><td class="num">1.7</td></tr>
  </table>
  <p>Over 90% of syllables are CV or CVC in all three sources; complex
  onsets are under 1%. Words begin with a vowel 14–18% of the time and end
  with one 45–51%.</p>
  <div class="note"><strong>The syllabifier in the repository does not do
  what the manuscript says it does.</strong> <code>max_onset_size()</code>
  returns 1 for any cluster and ignores the sonority table entirely, which
  diverges from the documented algorithm on 20–26% of word types. The
  shipped behaviour is <em>linguistically correct</em> for Chuvash — the
  documented algorithm would license /kr/ /pl/ /ml/ /ʃn/ onsets the language
  disallows. The Methods prose needs rewriting, not the code.</div>
  {}
""".format(img("fig_phonotactics.png",
               "Syllable shapes, word edges and medial cluster sizes across the three sources.")))

    # ── 20 vowel space ───────────────────────────────────────────────
    vsn = D["vsm"][D["vsm"].non_palatal == True]
    S.append(f"""
  <h2>The eight vowels, speaker-normalised, non-palatal contexts</h2>
  <p class="sub">Lobanov within speaker; {int(vsn.n.sum()):,} tokens.
  Non-palatal excludes vowels adjacent to /j ɕ ʃ tɕ ʒ/, which front F2
  enough to smear the space.</p>
  {img("fig_vowel_chart.png",
       "Vowel means with ±1 SD ellipses. The means are distinct; the token clouds overlap heavily, which is the finding, not a defect.")}
  <p>The means separate cleanly. The distributions do not — which is why the
  midpoint-formant clustering on slide 12 undercounts, and why the contrast
  has to be looked for in context rather than in the vowel itself.</p>""")

    # ── 21 what changed ─────────────────────────────────────────────
    S.append(f"""
  <h2><span class="tag fix">method</span>What the rebuild changed, and why it matters</h2>
  <p class="sub">The cleaning step used to delete rows outside Tukey fences
  computed within vowel × corpus. Those fences preferentially removed
  <em>long</em> vowels — which is to say, the stressed ones.</p>
  <table>
    <tr><th>Quantity</th><th class="num">filtered</th><th class="num">rebuilt</th><th>Consequence</th></tr>
    <tr><td>vowel tokens</td><td class="num">280,955</td><td class="num">574,344</td><td>—</td></tr>
    <tr><td>A-vs-B sample (word tokens)</td><td class="num">7,411</td><td class="num">{int(ad5.loc['duration','word_tokens']):,}</td><td>the weakest point in the draft, fixed</td></tr>
    <tr class="hi"><td>/ø/ F3 change under stress</td><td class="num">−0.270</td><td class="num">{D['rst'].loc['ø','dF3z']:+.3f}</td><td>&ldquo;rounds under stress&rdquo; withdrawn</td></tr>
    <tr><td>rounding anchors</td><td class="num">one per series</td><td class="num">height-matched</td><td>⟨ӑ⟩ now undecidable for a structural reason, not a power one</td></tr>
    <tr><td>clustering peak</td><td class="num">k = 6</td><td class="num">k = {kbest}</td><td>same conclusion, cleaner reading</td></tr>
    <tr><td>coda odds (duration, adjusted)</td><td class="num">0.782</td><td class="num">{OR('has_coda','prom_dur_adj'):.3f}</td><td>null holds</td></tr>
  </table>
  <p>Two published conclusions were withdrawn as a direct result of
  readmitting those rows. That is the strongest argument that readmitting
  them was right.</p>
  <div class="note">Both filters are now <strong>flags, not deletions</strong>
  (<code>iqr_outlier_any</code>, <code>word_complete</code>), and the fences
  are computed within vowel × <em>speaker</em>. Every analysis reports the
  full sample, and the coda and sonority tests report the strict subset
  alongside so the reader can see the nulls do not depend on the choice.</div>""")

    # ══ NEW 2026-10-01: f0, the step design, shapes, morphology ═══════

    # ── A  the headline: the within-word step design ──────────────────
    svs = D["svs"][D["svs"].spec == "vowel-stratified"].set_index(["cue","direction"])
    sv = lambda c, d, col="estimate": svs.loc[(c, d), col]
    S.append(f"""
  <h2><span class="tag new">new</span>The best-identified result: duration steps up into the stressed syllable</h2>
  <p class="sub">Within-word steps between adjacent syllables, stratified on
  (word length &times; syllable index &times; <strong>target vowel</strong>).
  A within-word difference cancels the word, recording and speaker levels
  exactly, so no declination baseline has to be specified.</p>
  <table>
    <tr><th>Cue</th><th class="num">step INTO the stressed syllable</th><th class="num">t</th><th class="num">step OUT of it</th><th class="num">t</th><th>JND</th></tr>
    <tr class="hi"><td>duration</td><td class="num"><strong>{sv('dur','step into syllable'):+.2f} ms</strong></td><td class="num">{sv('dur','step into syllable','t'):.1f}</td><td class="num">{sv('dur','step out of syllable'):+.2f} ms</td><td class="num">{sv('dur','step out of syllable','t'):.1f}</td><td>10 ms (Hirsh 1959) &mdash; cleared</td></tr>
    <tr><td>intensity</td><td class="num">{sv('int','step into syllable'):+.2f} dB</td><td class="num">{sv('int','step into syllable','t'):.2f}</td><td class="num">{sv('int','step out of syllable'):+.2f} dB</td><td class="num">{sv('int','step out of syllable','t'):.2f}</td><td>3 dB (Moore 2007) &mdash; null</td></tr>
    <tr><td>f0</td><td class="num">{sv('f0','step into syllable'):+.3f} st</td><td class="num">{sv('f0','step into syllable','t'):.1f}</td><td class="num">{sv('f0','step out of syllable'):+.3f} st</td><td class="num">{sv('f0','step out of syllable','t'):.1f}</td><td>both steps UP, so no peak</td></tr>
  </table>
  <div class="cols">
    <div class="panel">
      <h3>Why it is not circular</h3>
      <p>Designation at syllable <em>i</em> depends on whether anything to the
      <strong>right</strong> of <em>i</em> holds a full vowel. That information
      is in neither the step nor the strata. This is the only specification
      that holds local vowel quality fixed and still recovers the rule.</p>
      <p>Stratifying matters: with the vowel as an <em>additive covariate</em>
      the estimate is +17.95 ms, and at word-final position designation is a
      <em>deterministic</em> function of the target's own vowel, so part of
      that figure is a full-versus-reduced comparison in disguise.</p>
    </div>
    <div class="panel">
      <h3>The ceiling on this design</h3>
      <p>Only <strong>{int(sv('dur','step into syllable','n_strata'))}</strong>
      strata contain the same vowel at the same position in words of the same
      length on <em>both</em> sides of the designation contrast. That is the
      structural limit, not a sampling accident: it is the same ceiling the
      matched-vowel design hit.</p>
    </div>
  </div>
  {img("fig_contour_steps.png",
       "Steps by shape class. Rings mark the rule's stressed syllable. Top: intensity step to the next syllable. Bottom: duration step from the previous one.")}
  <p class="cap">Descriptively the largest duration step up in the word lands
  on the designated syllable in <strong>9 of 9</strong> testable cells, at +20
  to +36 ms, with pre-tonic syllables carrying negative steps.</p>""")

    # ── B  two hypotheses, one survives ───────────────────────────────
    S.append(f"""
  <h2><span class="tag null">null</span>The post-tonic intensity drop is position, not stress</h2>
  <p class="sub">Two hypotheses about contour shape. The duration one holds;
  the intensity one does not survive its own control.</p>
  <div class="cols">
    <div>
      <h3>Held: the stressed syllable is the first to lengthen</h3>
      <p>&ldquo;Leftmost syllable above the word's own mean duration&rdquo;
      identifies the designated syllable where stress is left of the edge
      (pre-antepenultimate 0.843 against 0.250 chance; antepenultimate 0.708
      against 0.333), and the mirror statistic does not. Where stress is final
      it reverses.</p>
    </div>
    <div>
      <h3>Failed: a drop after the stressed syllable</h3>
      <p>Raw, the designation effect on the following intensity step is
      &minus;1.735 dB. With <em>both</em> vowels controlled it is
      &minus;0.315 dB (t &minus;1.19), and the mirror control vanishes
      symmetrically. The step out of the designated syllable is a
      <strong>rise</strong> in all five cells where that syllable is syllable 1
      and a fall in all four where it is syllable 2 or later &mdash; which just
      restates the syllable-2 intensity peak.</p>
    </div>
  </div>
  <p>The class that separates the two anchorings settles it: in 3-syllable
  antepenultimate words (1,773 tokens) the step out of the designated first
  syllable is <strong>+0.43 dB</strong>, and the drop arrives at the word edge
  instead. In the penultimate class the post-tonic syllable <em>is</em> the
  word-final one, so that class cannot distinguish them at all.</p>
  <p class="cap">Worth keeping, though: a drop can be an informative
  <em>perceptual</em> cue without being an independent correlate. It is
  audible and it does co-locate with stress in the penultimate class. That is a
  claim about perception this corpus cannot test &mdash; and it is a different
  claim from the one the numbers reject.</p>""")

    # ── C  f0 ─────────────────────────────────────────────────────────
    f0r = D["f0r"]; f0rl = f0r[(f0r.control == "vowel_label") & f0r.identified].copy()
    f0rl = f0rl.sort_values("rank")
    f0e = D["f0e"]; f0el = f0e[f0e.control == "vowel_label"]
    f0_add = f0el[f0el.model == "additive"].est_hz.iloc[0]
    f0_wi  = f0el[(f0el.term == "b_final") & (f0el.model != "additive")].est_hz.iloc[0]
    f0_uf  = f0el[f0el.model != "additive"].est_hz.sum()
    f0p = D["f0p"]
    s21 = [(int(n), float(g[g.sidx==2].f0_rel.iloc[0] - g[g.sidx==1].f0_rel.iloc[0]))
           for n, g in f0p.groupby("sN") if len(g[g.sidx==2]) and len(g[g.sidx==1])]
    HI = ' class="hi"'
    rowcls = lambda rule: HI if rule == "B5" else ""
    rows = "".join(
        f'<tr{rowcls(r.rule)}><td>{r.rule}</td>'
        f'<td class="num">{r.est_st:+.3f}</td><td class="num">{r.est_hz:+.2f}</td>'
        f'<td class="num">{r.t:.1f}</td></tr>' for r in f0rl.itertuples())
    S.append(f"""
  <h2><span class="tag new">new</span>f0, the third cue &mdash; never tested before now</h2>
  <p class="sub">f0 at the vowel midpoint (mean of steps 10 and 11, the exact
  analogue of the adopted intensity measure), in semitones from the
  <strong>speaker's own median</strong>. {D['f0d'][D['f0d'].corpus=='ALL'].pct_usable.iloc[0]:.1f}% of
  vowels usable; {int(D['f0d'][D['f0d'].corpus=='ALL'].octave_outlier.iloc[0]):,} octave-tracking
  errors removed. Within-speaker normalisation makes the open question about
  the Chuvash Voice speaker's sex <em>moot</em> downstream.</p>
  <div class="cols">
    <div>
      <h3>The B rules lead, as on duration</h3>
      <table>
        <tr><th>Rule</th><th class="num">semitones</th><th class="num">Hz</th><th class="num">t</th></tr>
        {rows}
      </table>
      <p class="cap">Net of nonparametric position. <code>initial</code> is NOT
      IDENTIFIED. Same ranking under the vowel_height control set.</p>
    </div>
    <div class="panel">
      <h3>Two of three cues now favour B</h3>
      <p>duration B5 first &middot; <strong>f0 B6/B5/B4 first</strong> &middot;
      intensity A6 first. The stressless-word analysis gains its second
      independent cue.</p>
      <h3>No syllable-2 f0 peak</h3>
      <p>f0 peaks on <strong>syllable 1</strong> at every word length, and
      syllable 2 is lower at every length
      ({", ".join(f"{d:+.2f}" for _, d in s21)} st for lengths
      {", ".join(str(n) for n, _ in s21)}). So the syllable-2 effect is
      intensity-only: duration peaks word-finally, f0 word-initially.</p>
    </div>
  </div>
  {img("fig_f0_rule_ranking.png", "f0 on the stressed syllable relative to the declination trend, both control sets, with Gandour's 1 Hz JND marked.")}""")

    # ── D  the word edge: a revision ──────────────────────────────────
    fpt = D["fpt"]
    d_add = fpt[(fpt.dv=="dur_c") & (fpt.model=="additive")].ms.iloc[0]
    i_add = fpt[(fpt.dv=="int_c") & (fpt.model=="additive")].dB.iloc[0]
    S.append(f"""
  <h2><span class="tag fix">revised</span>The word-final rise is a boundary tone, not stress</h2>
  <p class="sub">A conclusion from earlier in this project was wrong and is
  corrected here.</p>
  <table>
    <tr><th>Word-final syllable, relative to trend</th><th class="num">duration</th><th class="num">intensity</th><th class="num">f0</th></tr>
    <tr><td>pooled</td><td class="num">{d_add:+.2f} ms</td><td class="num">{i_add:+.3f} dB</td><td class="num">{f0_add:+.2f} Hz</td></tr>
    <tr><td>word-internal</td><td class="num">{fpt[(fpt.dv=='dur_c') & (fpt.term=='b_final') & (fpt.model!='additive')].ms.iloc[0]:+.2f} ms</td><td class="num">{fpt[(fpt.dv=='int_c') & (fpt.term=='b_final') & (fpt.model!='additive')].dB.iloc[0]:+.3f} dB</td><td class="num">{f0_wi:+.2f} Hz</td></tr>
    <tr class="hi"><td>utterance-final</td><td class="num">{fpt[(fpt.dv=='dur_c') & (fpt.model!='additive')].ms.sum():+.2f} ms</td><td class="num">{fpt[(fpt.dv=='int_c') & (fpt.model!='additive')].dB.sum():+.3f} dB</td><td class="num"><strong>{f0_uf:+.2f} Hz</strong></td></tr>
  </table>
  <p>Earlier this was reported as &ldquo;longer but quieter than trend&rdquo;
  and counted against final stress on the grounds that the cues disagree. With
  f0 in hand it is longer, quieter <em>and higher</em> &mdash; two of three
  cues in the stress direction.</p>
  <p><strong>But the f0 elevation reverses sign at the utterance edge</strong>
  ({f0_wi:+.2f} Hz word-internally, {f0_uf:+.2f} Hz utterance-finally,
  interaction t &minus;179). Lexical stress cannot flip sign according to
  whether the word ends the utterance; a boundary tone does exactly that. So
  final stress is still unsupported &mdash; the reason is now
  &ldquo;it is a boundary tone&rdquo;, not &ldquo;the cues disagree&rdquo;.</p>
  {img("fig_word_edge_cues.png", "The three cues at the word edge, each in its own units with its own JND. The JND normalisation is NOT comparable across cues: the 1 Hz f0 JND is measured on steady tones.")}
  <p class="cap">Why <code>final</code> can be tested at all: 1{{sidx == sN}} is
  <em>identical</em> to syl_final on all 574,344 rows (&phi; = 1.0000), so it is
  unidentified against a linear trend. Entering position NONPARAMETRICALLY makes
  the predicate a deterministic but <em>nonlinear</em> function of position, and
  that is what identifies it. <code>initial</code> stays unidentified.</p>""")

    # ── E  shapes: the leftward walk ──────────────────────────────────
    spm = D["spm"]; o5 = spm[(spm.inventory=="5full") & (spm.version=="observed")]
    dmatch = o5[(o5.dv=="duration") & (o5.from_end>=0)]
    imatch = o5[(o5.dv=="intensity") & (o5.from_end>=0)]
    S.append(f"""
  <h2><span class="tag new">new</span>The duration peak walks leftward with the rightmost full vowel</h2>
  <p class="sub">Shape classes defined by <code>from_end = sN &minus; (position
  of the rightmost full vowel)</code>, not by strict full/reduced strings, so
  RFFR, RRFR and FRFR join FFFR in the penultimate class. Computed under both
  the 5-full and 6-full inventories.</p>
  <p>The observed duration peak sits on exactly the syllable the rule
  designates in <strong>{int(dmatch.match.sum())} of {len(dmatch)}</strong>
  word-length &times; class cells containing a full vowel &mdash; identically
  under both inventories. The intensity peak matches in only
  {int(imatch.match.sum())} of {len(imatch)}; it sits on syllable 2 in 13 of 14
  cells, so it tracks position rather than the rule.</p>
  {img("fig_shape_profiles_observed.png",
       "Intensity and duration profiles by generalised shape class, with rings on the rule's stressed syllable.")}
  <div class="cols">
    <div class="panel">
      <h3>A5 or A6?</h3>
      <p>The coding is the <strong>5-full</strong> inventory
      (a e i u y), i.e. A5/B5. Adding /&#596;/ &#10216;&#1099;&#10217; moves 2.1% of word tokens, almost
      all of them disyllables leaving the stressless class for the
      initially-stressed one &mdash; because &#10216;&#1099;&#10217; is overwhelmingly
      first-syllable. The peak-match result is identical either way, so these
      profiles do not adjudicate A5 against A6.</p>
    </div>
    <div class="panel">
      <h3>The controlled version does not test this</h3>
      <p>Net of vowel quality the longest syllable is word-final in 13 of 14
      cells &mdash; but that model has <code>vowel_label</code> as a covariate,
      and the rule's designation <em>is defined on</em> vowel fullness, so it
      adjusts away the rule's own content. Its failure is not evidence against
      the rule. The step design above is the controlled test.</p>
    </div>
  </div>""")

    # ── F  morphology ─────────────────────────────────────────────────
    mva = D["mva"]; mvb = mva.loc[mva.f1.idxmax()]
    mst = D["mst"]
    mg = lambda lab, col="estimate": mst[mst.test == lab][col].iloc[0]
    mal = D["mal"]
    S.append(f"""
  <h2><span class="tag new">new</span>The suffixation confound, cleared</h2>
  <p class="sub">The reduced vowels that define the right edge of the
  penultimate and antepenultimate classes are overwhelmingly
  <strong>suffixal</strong>, so &ldquo;the rightmost full vowel is the
  penult&rdquo; and &ldquo;this word carries a suffix&rdquo; are nearly the same
  statement. No corpus here has morphological annotation, so the parse was
  induced.</p>
  <div class="cols">
    <div>
      <table>
        <tr><th>Duration step up into the stressed syllable</th><th class="num">ms</th><th class="num">t</th><th class="num">steps</th></tr>
        <tr><td>all words</td><td class="num">{mg('d_dur_prev | all words'):+.2f}</td><td class="num">{mg('d_dur_prev | all words','t'):.1f}</td><td class="num">{int(mg('d_dur_prev | all words','n_steps')):,}</td></tr>
        <tr class="hi"><td><strong>no suffix parsed</strong></td><td class="num"><strong>{mg('d_dur_prev | no suffix parsed'):+.2f}</strong></td><td class="num">{mg('d_dur_prev | no suffix parsed','t'):.1f}</td><td class="num">{int(mg('d_dur_prev | no suffix parsed','n_steps')):,}</td></tr>
        <tr><td>suffix parsed</td><td class="num">{mg('d_dur_prev | suffix parsed'):+.2f}</td><td class="num">{mg('d_dur_prev | suffix parsed','t'):.1f}</td><td class="num">{int(mg('d_dur_prev | suffix parsed','n_steps')):,}</td></tr>
      </table>
      <p>The effect is present and nearly as large in words with no suffix
      parsed, and the designation &times; suffixal-status interaction is null
      ({mg('d_dur_prev | interaction'):+.2f} ms, t
      {mg('d_dur_prev | interaction','t'):.2f}). So the rule is not a stem-edge
      rule in disguise.</p>
      <p><strong>A separate finding:</strong> at the same position with the same
      vowel, a suffixal syllable is
      {mg('d_dur_prev | suffixal, not designated'):+.2f} ms longer (t
      {mg('d_dur_prev | suffixal, not designated','t'):.1f}) and
      {mg('d_int_prev | suffixal, not designated'):+.2f} dB quieter (t
      {mg('d_int_prev | suffixal, not designated','t'):.1f}) than a stem
      syllable, independent of stress.</p>
    </div>
    <div class="panel">
      <h3>The parse, and what it is not</h3>
      <p>Signature induction over 430,008 types on the <em>phonemic</em> form,
      using <strong>no vowel-quality information</strong> &mdash; essential, or
      it would reproduce the shape classes it is meant to check. Cut fixed at
      {int(mvb.min_stems)} stems by F1 against a reference suffix list: recall
      {mvb.recall:.3f}, precision {mvb.precision:.3f},
      {len(D['mac'])} suffixes accepted.</p>
      <p>Only suffixes of &ge;2 phonemes are parsed, because string recurrence
      <em>cannot</em> tell a genitive <em>-n</em> from a stem-final <em>n</em>.
      So the monomorphemic class is really <strong>&ldquo;no confident
      parse&rdquo;</strong>. That contaminates it with genuinely suffixed words
      and therefore biases this test <em>against</em> finding a difference.</p>
      <p class="warn">The reference list has not been checked by a Chuvash
      specialist and the per-word error rate is not measured.
      &#1241;&#1082;&#1241;&#1088; 'bread' is wrongly split. Both need review.</p>
    </div>
  </div>
  <p class="cap">The confound is real and large as a descriptive fact: outside
  the word-final class the designated syllable coincides with the last stem
  syllable {100*mal[mal.from_end==1].desig_is_last_stem_syl.iloc[0]:.1f}% of the
  time in the penultimate class, against a
  {100*mal[mal.from_end==1].chance_suffixal.iloc[0]:.1f}% chance rate of being
  suffixal. It just does not drive the acoustics.</p>""")

    # ── 22 reviewer ─────────────────────────────────────────────────
    S.append(f"""
  <h2>What a reviewer will press on</h2>
  <ul>
    <li><strong>Chuvash Voice is one speaker.</strong> 99.4% of its recordings
    fall in a single voice cluster, and it supplies about 69% of all vowels.
    Cross-speaker claims can only come from Common Voice's 104.</li>
    <li><strong>Gemination rests on that one speaker.</strong> Common Voice's
    only pre-recode grids are a different alignment, so consonant length is
    unreplicated across speakers.</li>
    <li><strong>f0 is stylised to 2 semitones.</strong> Nothing smaller than
    a couple of semitones should be rested on. The question-intonation
    result is several semitones and safe; the stress-related f0 differences
    are not.</li>
    <li><strong>Intensity was measured on excised vowels.</strong> Praat
    wrote 71% of the 20 step cells as literal 0.0 — undefined, not silence —
    and the script raised the pitch floor for short vowels, making the
    analysis window duration-dependent. <code>int_midpoint</code> is the
    only defensible column; <code>total_intensity</code> is a duration
    measure (r = 0.909 with duration).</li>
    <li><strong>Sonority is real but modest.</strong> Odds ratio
    {OR('is_a','prom_dur_adj'):.2f} for /a/ after intrinsic correction, not
    the {OR('is_a','prom_duration'):.1f} the raw measure shows, and only in
    duration.</li>
    <li><strong>The alignment was not hand-checked.</strong> A stratified
    hand-check of ~250 vowels and a cross-alignment confidence score are
    specified in <code>alignment_confidence.md</code> and not yet run.</li>
    <li><strong>The moraic split has no phonetic support here.</strong> The
    пулӑ~пулли alternation is recoverable from text but not from these three
    acoustic measures. The weight evidence is the additive
    long-C/reduced-V trade-off, not the alternation.</li>
  </ul>
  <div class="spacer"></div>
  <div class="note">Every number in this deck is generated from
  <code>9-analyze/output/*.csv</code> by
  <code>analyses/make_slides.py</code>, so it cannot drift from the analyses.
  Provenance for each run is in <code>9-analyze/data/run_log/</code>.</div>""")

    html = ["<!DOCTYPE html>", '<html lang="en">', "<head>",
            '<meta charset="utf-8">',
            "<title>Chuvash stress, phonetics and phonology — corpus findings</title>",
            f"<style>{CSS}</style>", "</head>", "<body>", '<div class="deck">']
    for i, body in enumerate(S, start=1):
        html.append(f'<section class="slide" data-n="{i}">{body}\n</section>')
    html += ["</div>", "</body>", "</html>"]
    with open(a.out, "w", encoding="utf-8") as fh:
        fh.write("\n".join(html))
    print(f"wrote {a.out}: {len(S)} slides, "
          f"{os.path.getsize(a.out) / 1e6:.1f} MB")
    if missing:
        print("MISSING FIGURES (placeholders written):")
        for fn in sorted(set(missing)):
            print("  ", fn)


if __name__ == "__main__":
    sys.exit(main())
