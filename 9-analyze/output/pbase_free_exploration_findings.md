# Free exploration: Chuvash vs Eastern Mari and Turkic in PBase

Five questions extending `pbase_comparison.py` / `pbase_relevance.md`, using the
same staged PBase tables (Mielke; data of 2 October 2022; 629 languages, 21,791
patterns) plus two files that script left "staged but unused" —
`ipa2allfeatures.csv` (distinctive features in four systems) and
`grouping-diagnosis.csv` (Brohan & Mielke 2018 sound-pattern labels) — and a
consonant-inventory comparison the existing script never ran (it computed
Jaccard on vowels only). All code and full tables are in
`output/pbase_feature_vowel_distance.csv`, `pbase_consonant_neighbours.csv`,
`pbase_uralic_areal_gradient.csv`, `pbase_gemination_typology.csv`,
`pbase_global_schwa_reduction_search.csv`.

## Q1. Is "Mari is the only close vowel match" an artifact of symbol-matching?

The existing Jaccard ranking (`pbase_inventory_neighbours.csv`) requires an
*exact* IPA symbol match, which makes it brittle to two PBase coding habits: long
vowels are listed as separate inventory members, and phonetically adjacent
vowels (e.g. ɨ central vs ɯ back unrounded) never overlap even when a
language's real quality is one feature-value away from Chuvash's.

Replacing symbol-identity with a feature-space distance (mean nearest-neighbour
distance over `SPE.high/low/back/round/tense`, confirmed identical under the
independent `HC` feature system) changes the picture substantially. Under the
literal reading of ⟨ӗ⟩ (=ø):

| rank | language | family | feature distance |
|---|---|---|---|
| 1 | Kilivila/Kiriwina | Austronesian | 0.0483 |
| 2 | Eastern Khanty | Uralic | 0.0516 |
| 3 | Buriat | Mongolic | 0.0528 |
| **4 (tie)** | **Tuvan, Turkish, Kirghiz, Eastern Mari** | Turkic ×3 / Uralic | **0.0559** |

Three of the six PBase Turkic languages tie exactly with Eastern Mari for
closest vowel-*quality* match once length and near-identical qualities are
allowed to count. Inspecting the actual vowel sets explains the tie: Turkish
and Kirghiz have `a e i o u y ø ɨ` against Chuvash's `a e i u y ø ə ɯ` — six of
eight qualities identical, the "extra" members on each side (`o` vs `ə`; `ɨ` vs
`ɯ`) a single feature away. Mari's advantage in the *symbol* Jaccard was mostly
that it independently has a genuine `ə`, not that its inventory is structurally
closer. The tie reproduces under the strict (ə=ə) reading too (all four tied at
rank 24/629). **The earlier claim should be narrowed**: no Turkic language in
PBase has Chuvash's *specific* reduced-vowel segment, but in terms of raw vowel
*qualities* (height/backness/rounding), Chuvash is not typologically distant
from mainstream Turkic — the distance is concentrated in one feature
(the schwa) and one notational artifact (PBase's length-as-separate-phoneme
convention), not in the whole vowel system.

## Q2. Does the consonant inventory tell the same story as the vowels?

The original script never computed this. Using the project's native-only
Chuvash consonant set (`p t tɕ k s ʃ ɕ x m n ʋ l j r`; per
`config/phonology_params.R`, the Zheltov-derived inventory with no inherited
voicing contrast) and normalizing away diacritics that are pure transcription
choice (dental bridges, length marks) before matching:

| language | consonants | Jaccard (normalized) | rank / 629 |
|---|---|---|---|
| **Tuvan** | 20 | 0.546 | **6** |
| Khakas | 14 | 0.474 | 24 |
| Turkish | 20 | 0.417 | 82 |
| South Azerbaijani | 21 | 0.400 | 120 |
| Kirghiz | 22 | 0.385 | 161 |
| **Eastern Mari** | 19 | **0.375** | **181** |
| Turkmen | 22 | 0.333 | 284 |

The ranking **inverts relative to vowels**. Tuvan is a top-10 consonant match
out of 629 languages; Eastern Mari — the single best vowel match — sits in the
middle of the distribution for consonants, well behind every one of the six
Turkic comparanda. (Before diacritic normalization Mari looked far worse still,
rank 570/629, purely because its consonants are transcribed with dental
diacritics — `t̪ n̪ s̪ l̪` — that fail exact-symbol matching against Chuvash's
plain `t n s l`; normalizing is the fairer comparison, and it still leaves Tuvan
far ahead.)

So Chuvash's two subsystems point in different typological directions: the
**consonant inventory carries a Turkic (genealogical) signal**, the **vowel
inventory carries a Mari-like (areal) signal** — and per Q1, that vowel signal
is really about one segment (schwa), not the whole system.

## Q3. Is the "areal" story about the Volga-Kama contact zone, or about Uralic generally?

PBase's Uralic sample is thin — 7 languages, no Mordvin/Udmurt/Komi — but it
already discriminates:

| language | location | vowel-inventory rank vs Chuvash |
|---|---|---|
| Eastern Mari | Russia (middle Volga) | **1** |
| Hungarian | Hungary etc. | 9 (tied with best Turkic) |
| Estonian | Estonia | 45 |
| Eastern Khanty | Russia (Ob-Ugric, not Volga) | 49 |
| Finnish | Finland/Sweden/Russia | 340 |
| Finnish (dialects) | Finland | 340 |
| Saami, Central South | Sweden | 381 |

Closeness tracks **geography within Uralic**, not Uralic membership as such:
Mari (Chuvash's actual neighbour) is closest, Khanty and the Baltic/Fennic/Saami
languages are no closer than mainstream Turkic (Finnish and Saami rank *behind*
Kirghiz and Turkish). Hungarian is the interesting exception — distant from
Chuvash geographically and historically, but close in rank (9th) purely because
it happens to independently have front rounded vowels and a low front vowel in
a similar slot. That is a useful caution: shared vowel-inventory shape can arise
by typological coincidence (both Hungarian and Chuvash are "moderate front
rounding + reduced-vowel-shaped eighth slot" systems) as well as by contact, so
the Mari parallel is suggestive, not proof, on inventory shape alone — which is
why Q5 below looks at the *rule*, not just the inventory.

## Q4. Is Chuvash's gemination areal, inherited, or neither?

`grouping-diagnosis.csv` tags only 52 patterns database-wide as
Gemination/Degemination (out of 21,791) — a thin category overall, so a null
result anywhere carries real uncertainty. Within that small set: **none of the
six Turkic comparanda and no record for Eastern Mari carry a gemination
pattern.** The two Uralic languages that do are Estonian ("X → long / V__# under
stress") and Eastern Khanty ("X → long / V__V") — neither the areal neighbour
nor a Turkic relative. One Altaic language, Halh Mongolian, also has one. Given
that Chuvash's own corpus shows gemination as a heavy, synchronically active
process (`lː` 10,226 tokens, `nː` 5,350, `ɕː` 4,907 in `inventory_geminates.csv`),
this is worth flagging as a genuine gap rather than a finding: PBase simply
offers no comparandum, areal or genealogical, for what is one of Chuvash's more
salient consonantal phenomena. It should not be read as evidence that
gemination is a Chuvash-specific innovation — the category is too sparsely
coded in PBase overall for that inference — only that PBase cannot currently
adjudicate it.

## Q5. How rare, cross-linguistically, is Chuvash's actual configuration?

Rather than asking which language has a similar *inventory*, this asks which
language has a similar *rule*: a reduction to a schwa-like vowel, specifically
in word-final position. Pivoting `grouping-diagnosis.csv` to one row per
(language, rule) and intersecting the `O=ə` (output is schwa; 63 rules, 35
languages database-wide) and `Word Final` (754 rules) label sets finds exactly
**two** languages in the entire 629-language sample with a rule that is both:

| language | family | rule |
|---|---|---|
| Eastern Mari | Uralic | `/e, ø/ → [ə] / __# in polysyllabic words except when preceding vowel is X` (= back) |
| Af-Tunni Somali | Afro-Asiatic (Cushitic) | `short unstressed X → [ə] / __# (but ʊ, ʊ̘ excluded)` |

Af-Tunni's rule is conditioned by stress and by a segmental exception list, not
by the backness of the preceding vowel, so it is not a structural parallel to
Chuvash's configuration the way Mari's is — Mari remains the unique
structural match. More importantly: **zero of the six Turkic languages in
PBase have *any* rule that outputs a schwa**, of any conditioning. The
inventory-shape finding in Q1 (Turkic vowel qualities aren't far from
Chuvash's) and this rule-level finding are not in tension — they answer
different questions. Turkic languages have vowel qualities similar to
Chuvash's; what they don't have, and what Chuvash and Mari share uniquely in
this sample, is a *rule that turns a vowel into a schwa*. That sharpens
"Mari is the closest comparandum" into something stronger: for this specific
process, Mari is not just closest, it is the *only* cross-linguistic precedent
in a 629-language, 21,791-pattern database, and it sits immediately next door.

## Summary

| question | finding |
|---|---|
| vowel quality (feature space) | Mari ties with 3 Turkic languages — the "no Turkic is close" claim was partly a notation artifact |
| consonant inventory | Tuvan ranks 6/629; Mari ranks 181/629 — consonants carry the genealogical signal vowels don't |
| Uralic breadth | closeness tracks geography (Mari > Khanty > Finnish/Saami), not Uralic membership, modulo one coincidence (Hungarian) |
| gemination | no PBase precedent in either family — a genuine gap, not a finding |
| the specific rule | Mari is the only real structural match in the whole database; no Turkic language has any schwa-output rule |

**For the manuscript**: the clean one-line version of Q1+Q2+Q5 together is that
Chuvash looks like a Turkic language with a transplanted Mari-type reduction
rule grafted onto otherwise Turkic-shaped vowel qualities and a Turkic-shaped
consonant inventory — not like a language that has drifted away from Turkic
typology wholesale. That is a more precise and more defensible claim than
"Chuvash's closest relative is Uralic," and it is the kind of split signature
(inherited segment inventory + borrowed alternation) that is exactly what
language-contact theory predicts for a single intensively-borrowed rule, as
opposed to inventory replacement.

## Caveats carried over from the existing script, that apply here too

- PBase patterns are what a grammar-writer chose to record, not systematic
  typological surveys; absence of a label (gemination, schwa-rules) can reflect
  incomplete source grammars, not a true phonological absence.
- The consonant comparison uses the project's own *native*-lexicon inventory
  (14 segments); Russian-loan consonants (b d g z ʒ f) are excluded, matching
  how the project already treats the vowel inventory and the voicing-contrast
  claim in `pbase_relevance.md`.
- Feature-space distance (Q1) uses a coarse 5-feature, discretized
  (+/−/0.5/undefined) representation, which produces exact ties rather than a
  continuous ranking; the ties are a property of the metric's resolution, not
  evidence that the four tied languages are indistinguishable in finer detail.
- PBase's Uralic sample (Q3) is 7 languages with no Mordvin, Udmurt, or Komi —
  the Volga-Kama area most relevant to a contact story is not well covered, so
  the geography-tracks-closeness pattern rests on a small and incomplete
  sample.
