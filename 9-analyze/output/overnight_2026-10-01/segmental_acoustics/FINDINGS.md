# Segmental acoustics — findings (overnight 2026-10-01)

Scripts: `9-analyze/analyses/overnight/segmental_acoustics/` (`extract_voicing.py`, `build_tokens.py`,
`lenition_models.R`, `lenition_loans.R`, `geminate_timing.R`, `v1_context.R`, `timing_by_class.R`,
`fleeting_models.R`; the ad-hoc QC, mixture and figure code was run in the session kernel and is recorded
in `NOTEBOOK.md`). All files below are in this directory. CH = Chuvash Voice (models use the dominant
`voice_main` only, so CH results describe one reader); CV = Common Voice (~100 speakers, speaker
random effects). Every number here comes from a CSV in this directory.

**Data scope.** Every TextGrid in both corpora was measured (CV 17,023; CH 29,727; 2,084,544 phone
intervals). Files whose full vowels were voiced < 0.8 on average were dropped as misaligned:
12.4% of CV files and 1.0% of CH files (`file_alignment_qc.csv`). CV uses the `textgrids_VOX` alignment,
the only CV grids that keep geminates. That alignment is not the one behind the leveled-data CV vowel measures
(18.9% boundary agreement per `methods_weight_prosody.md`), so CV durations here will not match the leveled
CV vowel durations.

---

## Q1. Can closure voicing be measured reliably from these recordings?

**Answer.** Yes for Chuvash Voice. For Common Voice it works only after removing misaligned files.

**Key numbers** (`validation_by_class.csv`, % of intervals voiced at mid-interval, CH / CV): vowels
97.3 / 90.1, sonorants 93.6 / 87.2, loan /b d g/ between vowels 87.0 / 84.6, post-pause sibilants 2.3 / 4.8,
post-pause stops 6.1 / 16.2. Synthetic tests: about 1 frame of edge bleed with Praat AC pitch (12% of a 40-ms silent gap);
a voicing bar at −10 to −20 dB is detected, one at −30 dB is not (hence the sensitive setting and the threshold-free
low-band-energy measure were extracted as well). Hand check: 7 of 8 tokens matched the measure. The 8th was a CV word aligned into
digital silence, and that error is what led to the alignment QC.

**Confidence:** high (CH), medium (CV).
**Caveats.** MFA boundaries have 10-ms resolution and a 30-ms floor. The best-fitting grid shift is +10–20 ms in
both corpora, so boundaries run slightly early. A "stop" interval is closure plus burst; closure and
VOT were not separated.
**Files:** `validation_by_class.csv`, `file_alignment_qc.csv`, `handcheck/handcheck_grid.png`, `extraction/`.

---

## Q2. Are Chuvash obstruents voiced/lenis between voiced sounds and voiceless elsewhere? Is the lenition categorical, gradient or absent, and do geminates block it?

**Description being tested** (read in a draft PDF of the chapter; check against the published text before citing, especially the Kangasmaa-Minn 1998: 222 sub-citation). Savelyev (2020) says Chuvash has no voiced/voiceless obstruent opposition. In his
account all non-sonorants have semi-voiced allophones between vowels or after a sonorant before a vowel, and
voiceless allophones elsewhere (word-initially, before a sonorant, next to an obstruent). He also describes
geminates as voiceless.

**Answer.** The description holds in both corpora, at the level of individual speakers, for stops and fricatives alike.
- **Positional pattern (three tiers).** Model-adjusted mid-closure voiced fraction for stops, CH / CV
  (`lenition_emm.csv`):
  - *Lenited:* V_V 0.60 / 0.63 and R_V 0.51 / 0.61.
  - *Voiceless:* geminate 0.06 / 0.10, O_V 0.06 / 0.03, post-pause 0.07 / 0.14.
  - *Intermediate, not described in the literature:* V_R 0.16 / 0.28 and V_O 0.22 / 0.34 (before a consonant),
    and across word boundaries V#_V 0.32 / 0.43 and V_#V 0.30 / 0.39.
- **Speakers.** In CV, V_V > post-pause in 53/53 speakers (mean difference 0.465, 95% CI 0.414–0.516), V_V > geminate in 20/20
  (0.489, 0.419–0.559), V_V > O_V in 46/46, and R_V > V_R in 35/39 (`lenition_speaker_level.csv`).
- **Geminates block lenition actively.** With duration in the model, geminates are still −0.46 to −0.49 below V_V
  (stops, model B, `lenition_lmm.csv`). At matched duration they carry 30–39 ms less voicing into the
  closure than singletons (model E, `lenition_dur_models.csv`; fig. c). If geminate voicelessness were just an
  aerodynamic effect of length, voicing into closure would be the same for both.
- **Russian loans are exempt.** Among V_V stops, native words are 65.2% voiced against 22.3% for loan-spelled words (CH;
  6,584 vs 932 word types). In CV the figures are 73.6% and 41.3%. The LMM loan effect is −0.37 [−0.39, −0.35] in CH and −0.29 [−0.32, −0.27] in CV,
  and −0.32 / −0.23 at matched duration (`lenition_loan_models.csv`). Words with ≥15 tokens at or near 0% voiced (≤5%; учитель, капитан and Анюта at exactly 0%, председатель at 1.4%) are almost all
  loans and names (учитель, капитан, Анюта, председатель).
- **Categorical, gradient or absent?** Word-internally the rule behaves like a categorical (allophonic) rule. Its
  domain is sharp, R_V ≈ V_V, speech rate has no effect (+0.023 / −0.004 per SD), geminates and the Russian-loan
  stratum are exempt, and native words are bimodal at the word level. The *phonetic output* of the rule is
  graded, though, which fits the "semi-voiced" label. About 45–50% of V_V tokens are fully voiced. Voicing falls with
  closure duration (−0.10 per SD). Voicing decreases with place of articulation from front to back: p 75.7% > t 65.2% > k 56.3% > tʃ 31.8% (CH; `voicing_by_segment.csv`). The
  low-band energy of V_V stops sits 3.7 dB below voiced loan /b d g/ (`lenition_mixture_test.csv`).
  Across word boundaries and before consonants, voicing is **gradient**: a single intermediate distribution fits
  those positions much better than a mixture of the voiced and voiceless reference distributions (Δ log-likelihood
  per token −0.50 for V#_V and −0.78 for V_R, CH).

**Confidence:** high for the positional pattern, for geminate blocking, and for loan exemption. Medium for the
categorical-vs-gradient characterisation, because the mixture test cannot tell "mostly voiced category" from
"shifted unimodal" for V_V itself.
**Caveats.** The loan flag is orthographic and crude (any of о ё ф ц щ ъ б г д ж з). Because the V_V cell includes loans,
the adjusted means understate native lenition. CH is one reader of prose. In CV, the "speaker" variable is a Common Voice client ID.
The GLMMs use ≤4,000 tokens per position (subsample) and nAGQ = 0.
**Files:** `voicing_by_position.csv`, `lenition_lmm.csv`, `lenition_glmm.csv`, `lenition_emm.csv`,
`lenition_dur_models.csv`, `lenition_speaker_level.csv`, `lenition_mixture_test.csv`, `voicing_by_segment.csv`,
`lenition_loan_vs_native.csv`, `lenition_loan_models.csv`, `lenition_word_level_VV_stops.csv`, `figures/fig_lenition.png`.

**Bearing on the overnight hypothesis.** Savelyev (2020) explicitly attributes this distribution to a Mari
substratum: Mari historically had a similar voiced/voiceless distribution (he cites Kangasmaa-Minn 1998: 222).
The acoustics confirm that the Chuvash distribution is real and productive in native vocabulary. They cannot by themselves show
that it is areal. The direct test would be Mari acoustics with the same measure (see questions for Kate).

---

## Q3. Is Chuvash gemination quantity-sensitive like Finnic? Do vowels shorten before geminates (mora-sharing / compensatory shortening)?

**Answer.** Not in the Finnic (foot-isochrony) way, and there is no compensatory shortening. Vowels before geminates are slightly **longer**. Heterosyllabic clusters shorten the preceding vowel,
but geminates do not, and the vowel after a geminate is not shortened either.

**Key numbers** (`timing_by_class_models.csv`, % change vs the same vowel before a singleton, 95% CI; CH n = 117,755 /
192,464 tokens for obstruent / sonorant C; CV n = 37,020 / 62,974, ~100 speakers):
- V1 before an obstruent geminate: +5.7 [4.6, 6.9] CH, +3.3 [0.7, 6.0] CV.
- V1 before a sonorant geminate: +13.9 [12.9, 14.9] CH, +11.7 [9.5, 14.0] CV.
- V1 before an obstruent-initial cluster (VC.CV): −13.2 [−13.7, −12.7] CH, −9.1 [−10.3, −7.8] CV.
- V2 after a geminate: +2.4 [1.1, 3.8] / +4.6 [1.5, 7.8] (obstruent), +3.5 / +7.5 (sonorant). It is not shortened.
- The geminate consonant itself is +48% (CH) / +70% (CV) longer for obstruents (`geminate_timing_models.csv`).
  A reduced V1 shows no change before obstruent geminates (−0.2% [−3.6, 3.2] CH).

**Typological comparison** (literature; PBase has rule statements only, no durations):
- Italian shortens vowels before geminates (by up to 37% per the ICPhS 2019 review).
- Japanese lengthens them (Kawahara 2015; Kingston et al. 2009). Li & Kuang (2022) report the same lengthening for Sakha, a Turkic
  language, with V2 shorter after geminates, and cite lengthening for Finnish and Polish too.
- Estonian quantity is defined by foot isochrony: V2 is longest in Q1 and shortest in Q3 (Asu & Teras 2009; Lippus et al. 2013).

V1 lengthening does not discriminate on its own: Li & Kuang's review reports it for Japanese, Finnish and Polish as well as Sakha.
The diagnostic that is specific to Finnic quantity is the trade-off between the syllables of the foot (Estonian V2
shortening after a long first syllable), and Chuvash lacks it: V2 after a geminate is, if anything, longer. Chuvash geminates therefore
lengthen the consonant without any foot-level compensation. That is the Sakha/Japanese V1 pattern without Sakha's V2
shortening. Nothing durational was retrievable for Khanty tonight, so the Khanty comparison was **not assessed**.

**Confidence:** medium-high for the direction (both corpora agree, intervals exclude 0). Medium for the size of the
sonorant-geminate effect, because a vowel–sonorant boundary is where forced alignment is least precise.
**Caveats.** Geminate words are lexically special (kinship, emphatic and possessive forms such as пулли), so the
word random effect can absorb only part of that. /mː vː/ were excluded because they are clipped at the floor. One
CH model in `geminate_timing.R` reported a convergence warning, so the reported figures come from the per-class refits.
**Files:** `geminate_timing_models.csv`, `geminate_timing_cells.csv`, `v1_context_models.csv`,
`timing_by_class_models.csv`, `figures/fig_geminate_timing.png`.

---

## Q4. Does Chuvash show Mari-like reduced-vowel deletion (/ə/ → 0) in fast speech, and where?

**Answer.** Not as a frequent process in this read speech. The aligner floor is **30 ms** in both corpora, and
8.5% (CH) / 11.8% (CV) of ӑ/ӗ tokens sit on it. Their contexts look like gradient reduction: they are more
frequent in faster speech, in unstressed syllables, next to sonorants, and outside word-final position.

Where presence can be tested acoustically (between two voiceless obstruents), a vowel with no voicing anywhere in the C–V–C span is
rare even for reduced vowels: ӑ 0.47% [0.36, 0.62], ӗ 0.17%, against /a/ 0.08% (CH). The high vowel /i/ (0.58%) is as
susceptible as ӑ. The pattern looks like ordinary high/short-vowel devoicing (more likely when unstressed and in fast speech) more than a
reduced-vowel-specific deletion rule. Hand-checked tokens (кӑшкӑрса, пӑхма, кӗтсе) are genuinely voiceless, but
devoicing and deletion cannot be told apart with this measure.

**Key numbers** (`fleeting_models.csv`, `fleeting_TVT_by_vowel.csv`, `fleeting_floor_by_context.csv`):
- Voiceless span in T_V_T, CH (145 events / 76,288 tokens): reduced vs non-high full OR 4.51 [2.37, 8.57]; high
  full OR 3.33 [1.76, 6.29]; stressed OR 0.17 [0.07, 0.42]; +1 SD speech rate OR 1.33 [1.13, 1.57].
- Floor-length reduced vowels: speech rate OR 1.49 [1.46, 1.52] CH / 1.33 [1.27, 1.39] CV; stressed 0.22 / 0.54;
  after a sonorant 1.35 / 1.76; word-final 0.35 / 0.45; ӗ vs ӑ 0.84 [0.79, 0.90] CH (n.s. in CV).
- Common Voice is at the noise level for this test: 2.3–6.0% for *every* vowel, /a/ included.

**Confidence:** medium that deletion between voiceless consonants is rare (<1%) in CH read speech. **Not assessed**
for sonorant contexts, which are exactly where floor-length vowels concentrate and where a Mari-like syncope (a syllabic sonorant)
would occur: the intensity-peak test was not diagnostic there (`fleeting_RVR_intensity.csv`). **Not assessed** for spontaneous
or fast speech: both corpora are read speech.
**Caveats.** Being at the floor is not the same as being absent, since a 30-ms vowel can be fully present. PBase's Mari rule P8
(/e, ə/ → 0 next to /a/) was tried. Word-final reduced vowels before a vowel-initial word are at the floor 9–10% of the time vs 3.4%
before a consonant, but /a/ is not special, and the V–V boundary is the aligner's weakest point (`fleeting_hiatus_P8.csv`): inconclusive.
**Files:** `fleeting_tokens.csv.gz`, `fleeting_TVT_profile.csv`, `fleeting_TVT_by_vowel.csv`,
`fleeting_floor_by_context.csv`, `fleeting_models.csv`, `fleeting_RVR_intensity.csv`, `fleeting_hiatus_P8.csv`,
`handcheck/fleeting_handcheck_grid.png`, `figures/fig_fleeting.png`.

---

## Bibliography for this track (DOIs verified against CrossRef on 2026-10-01)

- Savelyev, A. 2020. Chuvash and the Bulgharic languages. In M. Robbeets & A. Savelyev (eds.), *The Oxford Guide to
  the Transeurasian Languages*. OUP. doi:10.1093/oso/9780198804628.003.0028. — The source of the lenition description
  tested in Q2. It also attributes the Chuvash voiced/voiceless distribution to a Mari substratum, citing Kangasmaa-Minn (1998: 222), and
  describes geminates as voiceless. (Read via the draft PDF on iling-ran.ru.)
- Li, F. & J. Kuang. 2022. On the phonetic realization and variation of consonant geminates in Sakha. *Proceedings of the
  LSA* 7(1). doi:10.3765/plsa.v7i1.5234. — Turkic comparison: vowels lengthen before geminates (Sakha; also
  Japanese, Finnish and Polish per their review), and V2 is shorter after a geminate.
- Asu, E. L. & P. Teras. 2009. Estonian. *Journal of the International Phonetic Association*. doi:10.1017/S002510030999017X. — Estonian quantity ratios
  2:3 / 3:2 / 2:1 and foot isochrony (the longer the first syllable, the shorter the second).
- Lippus, P., E. L. Asu, P. Teras & T. Tuisk. 2013. Quantity-related variation of duration, pitch and vowel quality in
  spontaneous Estonian. *Journal of Phonetics*. doi:10.1016/j.wocn.2012.09.005. — V2 is half-long after a short
  syllable and strongly shortened after an overlong one (per a secondary summary).
- Kawahara, S. 2015. The phonetics of sokuon, or geminate obstruents. In *Handbook of Japanese Phonetics and Phonology*.
  De Gruyter. doi:10.1515/9781614511984.43. — Japanese pre-geminate vowel lengthening; languages vary in direction.
- Kingston, J., S. Kawahara, D. Chambless, D. Mash & E. Brenner-Alsop. 2009. Contextual effects on the perception of
  duration. *Journal of Phonetics*. doi:10.1016/j.wocn.2009.03.007. — Japanese lengthens and Italian/Norwegian
  shorten vowels before geminates (as cited in a secondary source).
- Not DOI-verified / not read tonight: Kangasmaa-Minn, E. 1998. Mari. In D. Abondolo (ed.), *The Uralic Languages*.
  Routledge (no DOI found on CrossRef); Riese, Bradley & Guseva, *Mari: An Essential Grammar* (univie online textbook,
  consonant chapter; no DOI); Saarinen, S. 2022. Mari. *Oxford Guide to the Uralic Languages*,
  doi:10.1093/oso/9780198767664.003.0024 (DOI verified, content not read).
