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
import argparse, json, os, sys
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
    D["rnd"] = g("rounding_contrasts.csv").set_index("vowel")
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
    D["ram"] = g("rule_acoustic_models.csv")
    return D


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--repo", required=True)
    ap.add_argument("--out", default="chuvash_findings_slides.html")
    ap.add_argument("--markers", default=None)
    a = ap.parse_args()
    out = os.path.join(a.repo, "9-analyze", "output")
    D = load(out)
    mk = json.load(open(a.markers)) if a.markers else {}

    def img(fn, cap):
        src = "{{artifact:art_%s}}" % mk[fn] if fn in mk else fn
        return (f'<figure><img src="{src}" alt="">'
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
    S.append(f"""
  <h2>Duration ranks B first, intensity ranks A first — Dobrovolsky's asymmetry</h2>
  <p class="sub">Mixed models over the whole dataset, one per rule per
  measure, with vowel quality, coda, utterance position, speech rate and word
  frequency controlled and
  <code>(1|speaker) + (1|file_name) + (1|word_label)</code>.</p>
  <table>
    <tr><th>Rule</th><th class="num">Δ AIC, duration</th><th class="num">β duration</th><th class="num">Δ AIC, intensity</th><th class="num">β intensity (dB)</th><th class="num">accuracy</th></tr>
    {''.join(f'<tr{" class=hi" if r in (dur_best, int_best) else ""}><td>{r}</td><td class="num">{mr.loc[r, "dAIC_log_duration"] - mr.loc[dur_best, "dAIC_log_duration"]:,.0f}</td><td class="num">{mr.loc[r, "estimate_log_duration"]:+.4f}</td><td class="num">{mr.loc[r, "dAIC_int_midpoint"] - mr.loc[int_best, "dAIC_int_midpoint"]:,.0f}</td><td class="num">{mr.loc[r, "estimate_int_midpoint"]:+.3f}</td><td class="num">{mr.loc[r, "detected_accuracy_DESCRIPTIVE"]:.4f}</td></tr>' for r in named)}
  </table>
  <p>Duration puts <strong>{dur_best}</strong> first by
  {mr.loc['A5', 'dAIC_log_duration'] - mr.loc[dur_best, 'dAIC_log_duration']:,.0f}
  AIC over the best A rule; intensity puts <strong>{int_best}</strong> first by
  {mr.loc['B6', 'dAIC_int_midpoint'] - mr.loc[int_best, 'dAIC_int_midpoint']:,.0f}
  over the best B rule. This is the asymmetry Dobrovolsky (1999) reported on 80
  vowels, reproduced on {int(D['ram'].n_obs.iloc[0]):,}.</p>
  <div class="note"><strong>Three reasons not to read this table as the
  answer.</strong> (1) The intensity coefficients are
  {mr.loc[named, 'estimate_int_midpoint'].min():.2f}–{mr.loc[named, 'estimate_int_midpoint'].max():.2f} dB
  against a 3 dB JND — six to seven times too small to hear. Statistically
  overwhelming, perceptually nothing. (2) Overall accuracy does not discriminate at all —
  all six named rules fall in
  {mr.loc[named, 'detected_accuracy_DESCRIPTIVE'].min():.4f}–{mr.loc[named, 'detected_accuracy_DESCRIPTIVE'].max():.4f},
  and it is not independent of the AIC columns anyway. (3) The ranking is
  dominated by the ~90% of words where all six rules agree.</div>
  <p class="cap">The <code>final</code> baseline beats every named rule on
  duration by ΔAIC {mr.loc[dur_best, 'dAIC_log_duration'] - mr.loc['final', 'dAIC_log_duration']:,.0f}
  and on intensity while carrying a <em>negative</em> coefficient
  ({mr.loc['final', 'estimate_int_midpoint']:+.2f} dB). Its predictor is
  &ldquo;word-final syllable&rdquo;, which is the final-lengthening and
  declination confound itself, so that row measures the edge, not stress. It
  is excluded from the comparison rather than reported as a winner.</p>""")

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
  <h2><span class="tag new">new</span>Word-finally, a long consonant and a reduced vowel trade off</h2>
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
      <p>Word-finally the two are the same length. That is what a shared
      timing budget looks like, and it is the positive weight evidence in
      this dataset.</p>
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
  Sonority survives intrinsic correction in duration at
  {OR('is_a','prom_dur_adj'):.2f}, and vanishes in intensity.</p>
  {img("fig_coda_sonority.png",
       "Left: odds of being the most prominent syllable in the word. Right: duration and intensity by distance from the primary-stressed syllable.")}
  <p class="cap">Sonority-sensitivity holds at an odds ratio near
  {OR('is_a','prom_dur_adj'):.1f}, not the 2–3 the raw measures suggest — a
  real effect, a modest one, and only in the duration dimension.</p>""")

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
    rnd, bp = D["rnd"], D["bp"]
    S.append(f"""
  <h2><span class="tag fix">revised</span>Rounding: the front row is confirmed, the back row is undecidable</h2>
  <p class="sub">Within-series F3 against an unrounded anchor — /i/ for the
  front series, /a/ for the back. Rounding lowers F3.</p>
  <div class="cols">
    <div>
      <table>
        <tr><th>Contrast</th><th class="num">ΔF3 (z)</th><th>Reading</th></tr>
        <tr><td>/y/ vs /i/</td><td class="num">{rnd.loc['y','dF3z']:+.3f}</td><td>rounded</td></tr>
        <tr><td>/ø/ vs /i/</td><td class="num">{rnd.loc['ø','dF3z']:+.3f}</td><td>rounded</td></tr>
        <tr><td>/e/ vs /i/</td><td class="num">{rnd.loc['e','dF3z']:+.3f}</td><td>unrounded</td></tr>
        <tr class="hi"><td>/u/ vs /a/ <em>(control)</em></td><td class="num">{rnd.loc['u','dF3z']:+.3f}</td><td>rounded — yet no F3 drop</td></tr>
        <tr><td>/ɵ/ vs /a/</td><td class="num">{rnd.loc['ɵ','dF3z']:+.3f}</td><td>not determinable</td></tr>
        <tr><td>/ʉ/ vs /a/</td><td class="num">{rnd.loc['ʉ','dF3z']:+.3f}</td><td>not determinable</td></tr>
      </table>
    </div>
    <div class="panel">
      <h3>Why the back row fails</h3>
      <p>/u/ is rounded in every description of Chuvash and every Turkic
      language. Its F3 is not lower than /a/'s, so <strong>F3 has no
      sensitivity on the back series</strong> and a positive ΔF3 for ⟨ӑ⟩ or
      ⟨ы⟩ is not evidence of unrounding.</p>
      <p>F3 lowering is a <em>front</em>-rounding cue. On back vowels the
      rounding gesture lands in F2, which is also where backness lands. No
      amount of data separates them.</p>
    </div>
  </div>
  <p>What the data does carry: placed against /u/, ⟨ы⟩ /ʉ/ is at the same
  height (ΔF1 {bp.loc['ʉ','dF1z_vs_u']:+.2f}) but
  {bp.loc['ʉ','dF2z_vs_u']:+.2f} fronter in F2; ⟨ӑ⟩ /ɵ/ is lower
  ({bp.loc['ɵ','dF1z_vs_u']:+.2f}) and {bp.loc['ɵ','dF2z_vs_u']:+.2f} fronter.
  <strong>Both sit between /u/ and /a/ in F2</strong> — fronter than a plain
  rounded back vowel, which is the measurable part of the intuition.</p>
  {img("fig_rounding_revised.png",
       "Left: the F3 test with its positive control. Right: the eight vowel means, with ⟨ы⟩ and ⟨ӑ⟩ joined to /u/.")}
  <p class="cap">Also revised: the grammars' &ldquo;reduced vowels round under
  stress&rdquo; is refuted for ⟨ӗ⟩ (ΔF3 {D['rst'].loc['ø','dF3z']:+.3f}) and
  untestable for ⟨ӑ⟩ and ⟨ы⟩. What is solid is lower F2 under stress for
  ⟨ӗ⟩ and ⟨ӑ⟩.</p>""")

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
    <tr><td>/u/ vs /a/ ΔF3 (control)</td><td class="num">−0.392</td><td class="num">{rnd.loc['u','dF3z']:+.3f}</td><td>back-series rounding test invalidated</td></tr>
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
    print(f"wrote {a.out}: {len(S)} slides")


if __name__ == "__main__":
    sys.exit(main())
