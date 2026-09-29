# PBase and the Chuvash corpus

PBase (Jeff Mielke; data as of 2 October 2022; CC BY-NC-SA 4.0) as staged in
`9-analyze/data/pbase/`, compared against this study's corpora by
`9-analyze/analyses/pbase_comparison.py`.

## 1. What PBase can and cannot do for this paper

PBase holds **21,791 phonological patterns over 629 languages**: 9,518 coded as
*Target* (the segment undergoing an alternation), 8,855 as *Trigger* (the
segment conditioning one), 3,150 as *Distribution* (a distributional
restriction), and 150 further rows in PASS variants. Three facts bound what it
can contribute.

**It records no stress patterns.** Of the 21,791 patterns, **zero** name stress
or accent in any of the four prosody fields (`I_prosody`, `O_prosody`,
`L_prosody`, `R_prosody`). The 759 non-empty `domain` values are segmental and
syllabic — `WF`, `WM`, `WI`, `sylF`, `sylI`, `in coda`, `if tautosyllabic`.
PBase therefore cannot adjudicate a stress rule, and nothing below should be
read as evidence for or against one. What it *can* do is place the segmental
phonology that the stress argument rests on — the reduced-vowel series, the
harmony system, gemination — in a typological frame.

**Chuvash is absent.** The six Turkic languages in PBase are South
Azerbaijani, Kirghiz, Turkish, Turkmen, Tuvan and Khakas, carrying 265 patterns
between them. Chuvash — the first Turkic language to split off, and the only
one with a reduced-vowel series — has no entry. A distributional profile drawn
from these corpora is therefore a contribution PBase does not currently hold,
and `pbase_chuvash_tests.csv` is in the right shape to become one.

**Its patterns are claims from grammars, not measurements.** A PBase row records
what a describer wrote. The Chuvash figures here are what 1,424,952 aligned
phones do. A mismatch can mean Chuvash differs, or that the two are counting
different things — a categorical statement in a grammar against a rate in a
corpus. Every test below therefore reports the corpus number and the PBase
claim side by side instead of a pass/fail verdict.

## 2. Chuvash's closest comparanda are not Turkic

Ranking all 629 PBase languages by vowel-inventory overlap with Chuvash
(`pbase_inventory_neighbours.csv`) depends on an unsettled transcription
choice: this study's config writes ⟨ӗ⟩ as /ø/, the MFA dictionary writes it ɛ,
and descriptions that group ⟨ӗ⟩ with ⟨ӑ⟩ as reduced vowels write both as
schwas. The table therefore carries both readings.

| reading of ⟨ӗ⟩ | closest language | family | Jaccard | nearest Turkic |
|---|---|---|---|---|
| /ø/ (literal) | **Eastern Mari (Cheremis)** | Uralic (Finno-Ugric) | 0.778 | Kirghiz, rank 9 |
| ə (strict) | Karo Batak / Albanian / Kombai (tied) | Austronesian / IE / TNG | 0.750 | Kirghiz, rank 63 |

Under either reading no Turkic language is close: the best, Kirghiz and Turkish
at 0.600, rank ninth. Tuvan and Khakas rank 340th and 379th, because PBase
codes their long vowels as separate inventory members. This is the expected
consequence of the fact the paper already argues from — Chuvash's reduced
vowels have no counterpart in mainstream Turkic — but it is worth stating with
a number rather than as an impression.

**Eastern Mari is the single closest inventory in the database, and it is
Chuvash's areal neighbour rather than a genetic relative.** Mari is spoken
immediately north of Chuvashia in the middle Volga, the two have been in
contact for centuries, and Mari shares seven of Chuvash's eight vowel qualities
including the schwa that the Turkic six lack. For a paper arguing that the
Chuvash reduced vowels behave unlike full vowels, the nearest typological
parallel being Uralic and adjacent rather than Turkic and inherited is a point
worth making.

## 3. The nine tests

`pbase_chuvash_tests.csv` restates each testable PBase claim from the Turkic six
and from Eastern Mari as a statement about Chuvash and measures it. Headline
results:

**P1 — non-initial vowel restriction (Tuvan, South Azerbaijani).** PBase records
for Tuvan that `i y ɨ u e a` and their long counterparts may occur after the
initial syllable, excluding the mid round vowels; Azari's list of vowels that
may be the second vowel of a word likewise excludes `ø o`. Chuvash restricts a
subset too, but a different one — the share of each vowel's polysyllabic tokens
sitting in the **first** syllable is /ʉ/ 94.6%, /u/ 89.6%, /y/ 80.4%, /i/
47.8%, then /ɵ/ 32.8%, /a/ 32.2%, /ø/ 31.9%, /e/ 15.3%. The four high vowels
take the top four slots. So a non-initial vowel restriction is a recurrent
property across this group of languages, but in Tuvan and Azari it tracks
rounding and in Chuvash it tracks **height** — and no PBase Turkic language
restricts by height.

*These figures come from the Python phone table and agree with the independent
R-pipeline figures in `positional_restrictions.csv` (30.5, 12.3, 47.2, 89.6,
80.9, 27.7, 29.2, 96.2) to within 1–4 points, which is a useful cross-check on
two extraction paths that share only the audio.*

**P3 — harmony (Tuvan, Turkish).** PBase states Tuvan and Turkish harmony
without exception: back vowels only in words with back vowels, front only with
front. In Chuvash **73.0% of polysyllabic word tokens** and 62.5% of types have
all their vowels in one backness class; treating /i/ as neutral raises this to
75.4% and 68.0%. Part of the residue is Russian loans and part is alignment
error, so the figure is an upper bound on genuine surface disharmony — but it is
a long way from the categorical statement PBase carries for the other Turkic
languages, and the paper should not describe Chuvash harmony as exceptionless.

**P4, P5 — word-edge consonant inventories (Khakas, Turkish).** Khakas is
recorded as excluding /d/ and /dʒ/ from word-final position. Chuvash excludes
**no** consonant from either edge: 18 consonants occur word-initially and 15
word-finally with n ≥ 50, and the rare initials are /ɡ/ and /ʒ/, both confined
to Russian loans. The Khakas statement has no Chuvash analogue because Chuvash
has no voicing contrast in the native lexicon. The Turkish claim — the initial
inventory is nearly the whole consonant inventory with a couple of lexically
restricted exceptions — holds in Chuvash with a different exception set.

**P6 — Mari's reduction rule as a Chuvash distribution.** This is the closest
analogue in PBase to the Chuvash configuration, and it is the Mari entry, not a
Turkic one. Mari is recorded as **/e, ø/ → [ə] word-finally in polysyllabic
words, except when the preceding vowel is back**. Chuvash has two reduced
vowels rather than one, and they stand in near-complementary distribution by the
same conditioning factor: of word-final reduced vowels in polysyllables,
**98.4% are ⟨ӗ⟩ /ø/ after a front vowel** (1.6% ⟨ӑ⟩), against **63.5% ⟨ӑ⟩ /ɵ/
after a back vowel** (36.5% ⟨ӗ⟩). Two things follow. The conditioning factor is
the same one Mari's describer identified. And the asymmetry is informative — the
front context is nearly categorical while the back context leaks at 36.5%,
which is the same directional asymmetry as the harmony residue in P3.

For scale: **32.0% of polysyllabic word tokens end in a reduced vowel**, and
⟨ӗ⟩ /ø/ is strongly final-biased (33.7% of its tokens are word-final, second
only to /e/ at 37.6%) while ⟨ӑ⟩ /ɵ/ is not (13.3%).

**P9 — word-final lengthening (Mari).** PBase records Mari as lengthening
`i y u o` word-finally — a segmental alternation restricted to four vowels. In
Chuvash the effect is positional and applies across the inventory: word-final
syllable +12.3%, rising to +51.6% in interaction with utterance-final position
(`final_lengthening_models.csv`). This is why the paper treats final
lengthening as a confound to be controlled rather than as a phonological rule,
and the contrast with Mari is a reason to say so explicitly.

## 4. A new test PBase suggested, and its result

Mari carries two patterns with no Chuvash counterpart yet tested:

- **`/ə/ → 0`** (two separate entries) — outright deletion of the schwa. This is
  the zero-mora behaviour the fleeting-vowel hypothesis predicts for a subset of
  Chuvash reduced vowels, documented in the adjacent language. It cannot be
  tested on these corpora: the aligner works from dictionary pronunciations, so
  a deleted vowel has no interval to measure, and the corpus-internal
  alternation test is confounded by morphology (see
  `minimal_word_diagnosis.md`). It needs the designed word list.

- **`/e, ə/ → 0 / __a, a__`** — the reduced vowel is lost beside /a/. This one
  *is* testable, and it bears directly on the sonority-sensitive analysis: if
  /a/ shortened its neighbours as well as attracting stress, /a/ would be a
  trigger as well as a target, which would be independent support.

**It does not hold.** For 157,038 reduced vowels in 20,438 polysyllabic word
types, duration was modelled on the sonority tier of the most sonorous
neighbouring vowel, with the reduced vowel's own identity, word-final position,
utterance-final position, word length in phones and syllable count as controls,
and standard errors clustered on word type
(`pbase_sonority_reduction.csv`). Raw medians look like a clean gradient — 50 ms
next to /a/ and /e/, 60 ms next to everything else, a 20% spread. Once syllable
count is in the model the gradient disappears and is not monotonic: relative to
an /a/ neighbour, /e/ −12.7% (t −5.4), high vowels −1.3% (t −0.4), reduced
vowels +2.2% (t +1.1), /ʉ/ −1.1% (t −0.2). The syllable-count terms are
enormous by comparison (+21.5% at two syllables rising to +1009% at ten), so the
raw pattern is that words containing /a/ are systematically shorter words.

This is the same confound as the raw initial-vs-non-initial comparison in
`default_adjudication.R` and the raw coda effect: a positional or lexical
covariate masquerading as a phonological one. The substantive conclusion is
worth stating in the paper — **Chuvash sonority sensitivity is about where
stress lands, not about a segmental reduction rule.** /a/ attracts stress
without shortening its neighbours beyond what word length explains.

## 5. How to use this in the manuscript

1. **Typological framing, with numbers.** "Chuvash's vowel inventory has no
   close counterpart among the Turkic languages documented in PBase (Mielke
   2008); its nearest match in a 629-language sample is Eastern Mari, a Uralic
   language in centuries-long contact with Chuvash." That is a defensible
   sentence and it is currently absent from the draft.
2. **Do not claim Chuvash harmony is exceptionless.** 73% of tokens, 62.5% of
   types. PBase's Turkic entries are categorical; Chuvash's corpus is not.
3. **The Mari parallel for the reduced vowels** (P6) gives the reduced-vowel
   analysis an external anchor, and frames it as a candidate areal feature of
   the Volga-Kama zone rather than an inherited Turkic one. Savelyev (2020) is
   already in your bibliography for the contact history. I also wrote
   "Róna-Tas (1997)" here, but that year is **mine, not sourced** — Róna-Tas
   appears in this session only as an uncited authority on vowel quality, and
   no bibtex key or year for him exists in the draft. Check the citation before
   using it. The same caution applies to my attributing PBase to "Mielke 2008"
   anywhere in these notes: the distributed `readme.txt` gives only "PBase data
   as of October 2, 2022" with no author-year, so the 2008 is an inference from
   the literature and not from the data release.
4. **The negative sonority-reduction result** (§4) belongs in the section that
   argues the sonority sensitivity is a stress-placement property. It rules out
   the obvious segmental alternative.
5. **Contributing back.** Chuvash's absence from PBase is a gap this corpus
   could fill. `pbase_chuvash_tests.csv` and `inventory_segments.csv` /
   `phonotactics_clusters.csv` already hold the distributional statements in
   close to PBase's format.

## 6. Limits

- PBase's Chuvash-relevant content is thin: 265 Turkic patterns and 45 Mari
  patterns, against 21,791 in total. Nine claims were testable here.
- Its `Target` and `Trigger` patterns need morphological alternations. These
  corpora have no morphological annotation, so most of the 18,373 alternation
  patterns are out of reach regardless of language.
- Inventory similarity was computed on vowels only, using unweighted Jaccard
  over IPA symbols. It takes PBase's `core inventory` transcriptions at face
  value and is sensitive to whether a describer coded length as separate
  inventory members — which is why Tuvan and Khakas rank so low.
- The comparison is with PBase's own transcriptions, not with re-analysed
  primary data from those languages.
- `pb_languages.csv` has three rows the parser skips on embedded quotes
  (Libyan Arabic, Zezuru Shona, and one further row); none is Turkic or Uralic.
- `ipa2allfeatures.csv` (distinctive features in four systems) and
  `grouping-diagnosis.csv` (Brohan & Mielke 2018 sound-pattern labels) are
  staged but unused here. The grouping labels are segmental — the only ones
  touching this paper's concerns are Vowel Lengthening (102 patterns),
  Gemination (50) and Degemination (2) — and none is stress-related.
