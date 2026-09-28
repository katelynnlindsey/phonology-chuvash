# Deriving a sonority hierarchy for Chuvash without circularity

Answering: *knowing there are eight phonemic vowels, which is the most sonorous
phonetically? And do the most sonorous vowels align with the phonetic
correlates of stress in the spoken data and the phonological correlates in the
written data — or is that circular?*

Script `analyses/sonority_hierarchy.R`. Outputs `sonority_intrinsic.csv`,
`sonority_hierarchies.csv`, `sonority_rule_tests.csv`, `sonority_written.csv`.

## 1. The logic is sound. The current implementation is not.

The chain you describe — derive sonority from something independent, then test
whether it predicts stress — is a valid design, and it is the right one. It
fails only if the independent measure isn't independent. Two places it isn't.

**The obvious one.** Rank the vowels by intensity or duration and you have
ranked them by the two things this project uses as the phonetic correlates of
stress. Ask then whether sonorous vowels attract stress and the answer is built
in. Below, the intensity- and duration-derived hierarchies are computed anyway
and labelled `circular_for_this_outcome`, to show how much a circular
hierarchy flatters itself: the duration-derived hierarchy "predicts" duration
at +6.58%, half again the best honest number in the whole project.

**The one that matters, because it is inside rule SON already.** SON's tiers are

> a > e > {i y u} > {ø ɵ} > ʉ

On vowel height the eight vowels form **three** classes: /a/ low, /e ø ɵ/ mid,
/i y u ʉ/ high. SON cuts across that twice. It separates /e/ from /ø ɵ/, all
three of which are mid. And it puts /ʉ/ below /i y u/, all four of which are
high. Both cuts are exactly the full/reduced distinction — and in this project
full-versus-reduced is established *from stress behaviour*, via the
minimal-word asymmetry and the default adjudication. So SON's tier structure is
a height hierarchy refined by reducedness, and the refinement is the circular
part. It is not a phonetic sonority hierarchy, and the paper should not call it
one without the argument below.

## 2. Which vowel is the most sonorous phonetically?

Derived from a **rule-neutral unstressed set**: the 330,869 vowel tokens
(57.6% of the data, 30,143 word types) that *all six* stress rules agree are
unstressed. A ranking built only from tokens no rule calls stressed cannot
encode the stress pattern. Values are adjusted — vowel identity as a factor
with syllable-final, syllable-initial, closed-syllable, speaker and word-type
structure partialled out — and F1 and intensity are z-scored within speaker.

| vowel | n | height | adj F1 (z) | adj intensity (z) | adj log duration | SON tier |
|---|---|---|---|---|---|---|
| /a/ ⟨а⟩ | 108,489 | low | **+0.900** | **+0.366** | **4.564** | 1 |
| /ɵ/ ⟨ӑ⟩ | 53,199 | mid | **−0.167** | +0.061 | 4.328 | 4 |
| /ø/ ⟨ӗ⟩ | 55,977 | mid | **−0.475** | −0.130 | 4.485 | 4 |
| /e/ ⟨е⟩ | 46,239 | mid | −0.641 | +0.258 | 4.505 | 2 |
| /u/ ⟨у⟩ | 33,583 | high | −0.662 | −0.012 | 4.452 | 3 |
| /ʉ/ ⟨ы⟩ | 5,697 | high | −0.762 | −0.113 | 4.405 | 5 |
| /i/ ⟨и⟩ | 24,687 | high | −1.049 | −0.107 | 4.506 | 3 |
| /y/ ⟨ӳ⟩ | 2,998 | high | −1.142 | −0.163 | 4.458 | 3 |

**The most sonorous vowel is /a/, unambiguously — on all three measures.**
Beyond that the three measures disagree, and the disagreement is the finding.

**On aperture, which is the standard articulatory correlate of sonority, the
two reduced vowels are the second and third most sonorous vowels in the
language.** ⟨ӑ⟩ at −0.167 and ⟨ӗ⟩ at −0.475 are more open than /e/, and more
open than every high vowel. This is not a subtle margin: ⟨ӑ⟩ is 0.88 z more
open than /y/. F1 is also the one measure here that is *not* used anywhere in
this project as a correlate of stress, which is what makes it usable.

So an aperture-derived hierarchy is

> a > ɵ > ø > e > u > ʉ > i > y

and it inverts SON exactly where SON departs from height. Note also that
neither intensity nor duration groups the reduced vowels together: on intensity
⟨ӑ⟩ is 3rd but ⟨ӗ⟩ 7th; on duration ⟨ӗ⟩ is 4th but ⟨ӑ⟩ is **last**. Whatever
unites ⟨ӑ⟩ and ⟨ӗ⟩, no single phonetic scale measured here does it.

Spearman correlations with SON: duration +0.761, intensity +0.589, height
+0.377, aperture +0.184. **SON resembles the duration ranking most and the
aperture ranking least** — i.e. it resembles the circular one most.

## 3. Does the non-circular hierarchy predict stress?

Each hierarchy is turned into a stress rule by the same algorithm SON uses —
stress the rightmost vowel of the most sonorous tier the word contains — and
tested on the 61,630 polysyllabic word tokens (24.1%) where the five
hierarchies disagree. Model frame 145,077 vowels, 9,725 word types, with vowel
identity, word-final syllable, utterance-final word, their interaction and
speech rate controlled.

| hierarchy | duration β | % | ΔAIC | intensity β (dB) | ΔAIC | circular? |
|---|---|---|---|---|---|---|
| DUR | +0.0637 | **+6.58** | 0 | −0.032 | 28.5 | for duration |
| **SON** | +0.0453 | **+4.64** | 330 | **+0.224** | **0** | yes, §1 |
| INT | +0.0048 | +0.49 | 754 | +0.114 | 21.6 | for intensity |
| HEIGHT | −0.0009 | −0.09 | 758 | +0.176 | 13.1 | no |
| F1 (aperture) | −0.0057 | −0.57 | 753 | −0.021 | 28.8 | no |

**The two non-circular hierarchies do not predict duration at all.** Height
gives −0.09% and aperture −0.57%, both indistinguishable from zero and ~750
AIC behind. SON gives +4.64%.

Since SON is height plus the reducedness refinement, and **height on its own is
inert**, all of SON's duration power comes from the refinement. That is,
from the full/reduced contrast — which is rule B5's primitive, not a sonority
scale.

On intensity the ordering is different: SON first, then height, then the
circular intensity hierarchy. But every coefficient is 0.02–0.22 dB against a
3 dB just-noticeable difference, so intensity does not discriminate
perceptibly here and should not carry the argument.

## 4. The written corpora, where there are no acoustics at all

This is the other half of your question, and it is the cleaner test, because
the written data cannot contain a phonetic circularity. Two phonological
correlates from the Zheltov wordlist — the share of a vowel's syllables that
stand in an open monosyllable (the minimal-word diagnostic) and the share of
its polysyllabic tokens that are non-initial:

| vowel | % open monosyllable | % non-initial |
|---|---|---|
| /a/ | 0.06 | 70.8 |
| /e/ | 0.07 | 83.9 |
| /i/ | 0.19 | 52.0 |
| /u/ | 0.32 | 30.7 |
| /y/ | 0.77 | 28.6 |
| /ø/ | **0.00** | 63.9 |
| /ɵ/ | 0.02 | 68.8 |
| /ʉ/ | **0.00** | 10.2 |

Spearman ρ against each hierarchy (tier 1 = most sonorous, so a negative ρ
means *more sonorous → more of the property*):

| hierarchy | vs open monosyllables | vs non-initial |
|---|---|---|
| SON | **−0.562** | −0.577 |
| HEIGHT | +0.439 | **−0.861** |
| F1 (aperture) | +0.539 | −0.738 |

The two correlates pull apart, and informatively. On the **minimal-word**
correlate only SON has the right sign: the aperture hierarchy gets it backwards
(+0.539), because it ranks ⟨ӑ⟩ and ⟨ӗ⟩ near the top and those are precisely
the two vowels that never stand in an open monosyllable. On the **non-initial**
correlate height does best (−0.861) — which is the positional result already in
the paper, that the restriction tracks height and not weight.

## 5. So: is the logic circular?

**Your design is not circular. Rule SON, as currently specified, is.** And the
non-circular versions of it do not work. Three ways forward, in order of how
much they concede.

**(a) Rename the rule and keep the result.** What the data support is a rule
sensitive to the full/reduced contrast — which is B5 — and the evidence for the
contrast is the minimal-word asymmetry in the written corpora, which involves
no acoustics and no stress. That is a clean, non-circular argument, and it is
already the paper's core. SON then becomes a reformulation of B5 with the tier
mechanism doing the work of the full/reduced partition, and "sonority-sensitive"
should be dropped or heavily qualified, because the phonetic scale that would
justify it puts the reduced vowels near the top.

**(b) Argue that Chuvash sonority is not aperture.** Defensible — phonological
sonority scales are routinely language-particular and need not be reducible to
one acoustic dimension — but it costs the phonetic grounding the term was
supposed to buy, and the honest version has to say which dimension it *is*. On
this data no single measured dimension groups ⟨ӑ⟩ with ⟨ӗ⟩ and both below the
high vowels.

**(c) Find an independent measure that does order the vowels as SON needs.**
Candidates not tested here, in decreasing order of how likely I think they are
to work: perceptual loudness in sones rather than dB SPL; total periodic
energy over the vowel rather than midpoint intensity; F1 bandwidth or spectral
tilt; and the degree to which the vowel resists coarticulatory
undershoot — reduced vowels are typically more undershoot-prone, which would
give a principled reason for them to pattern below full vowels of the same
height. The last is the one I would try, and it can be measured on this corpus
as the vowel's formant distance from its own speaker-specific target as a
function of duration.

## 6. Limits

- The rule-neutral unstressed set is defined by the six full/reduced rules, so
  it inherits their vowel partition in deciding *which tokens* to include —
  though not in ranking the vowels, which is what matters here. A token that
  every rule calls unstressed is a conservative choice and the set is 57.6% of
  the data, so this is unlikely to drive the ranking; it has not been tested
  against an alternative definition.
- /y/ and /ʉ/ have 2,998 and 5,697 tokens against 108,489 for /a/. Their
  positions in the ranking are the least secure.
- Both intrinsic models reported a singular fit and a convergence warning
  (`negative eigenvalue`), which for a model this large with two crossed random
  effects usually means one variance component is at zero. The fixed effects
  are the quantity of interest and are stable, but the warning is real and the
  ranking should be re-checked with `spk` dropped before it goes in the paper.
- Chuvash Voice is one speaker and supplies most of the tokens, so "within
  speaker" normalisation is doing less work than the phrase suggests.
- Aperture is indexed by F1 alone. F1 is the standard proxy but it is not the
  same thing as sonority, and no articulatory data is available here.
