# Manuscript fixes — LaTeX and transcription

Every item below was verified against the draft source, not recalled. Line
numbers refer to the 892-line draft as supplied on 2026-09-25.

Numbers that need regenerating from the current pipeline are **not** here —
those are handled by `results_macros.tex` (see `draft_number_mapping.csv`).

---

## A. Will break or mis-render at compile time

### A1. `\begin{tablenotes}` with no `threeparttable` — line 310

`tab:min` closes its `tabular` then opens `tablenotes`:

```latex
309: \end{tabular}
310: \begin{tablenotes}
```

`tablenotes` is a `threeparttable` environment, and the draft never uses
`\begin{threeparttable}` anywhere (0 occurrences). As written this errors.
Either wrap the table:

```latex
\begin{threeparttable}
  \begin{tabular}{lrrrrrr} ... \end{tabular}
  \begin{tablenotes} ... \end{tablenotes}
\end{threeparttable}
```

or replace the two notes with a `\footnotesize` paragraph after `\end{tabular}`.

### A2. Two tables share the label `tab:stress-rules` — lines 173 and 416

- line 173: the two-rule version (A, B), in §"Acoustics of stress"
- line 416: the six-rule version (A–F), in §"Reanalysis of stress"

There are **two** `\ref{tab:stress-rules}` calls, at lines 412 and 430. LaTeX
resolves both to whichever definition comes last, so the reference at line 412 —
which is in the *two-rule* discussion — silently points at the six-rule table.

Fix: the two-rule table is a subset of the six-rule one. Delete the line-173
table, keep the line-416 one, and relabel it `tab:stress-rules-all`. Then check
both `\ref`s read correctly in context.

### A3. Two tables share the label `tab:harmony` — lines 337 and 370

- line 337: an **empty** table (`\begin{tabular}{clll}` with only `\\ \midrule`
  between the rules) captioned "Gemination alternations in nominals ending in
  reduced vowels"
- line 370: the real vowel-harmony distribution table

One `\ref{tab:harmony}` at line 365, in the vowel-harmony text, which resolves
to line 370 by luck of ordering. Fix: either populate the gemination table and
relabel it `tab:gemination`, or delete it — the examples in `covsubexamples`
immediately below already make the point.

### A4. `\botrule` vs `\bottomrule` — inconsistent

`\botrule` is used 8 times, `\bottomrule` in `tab:min`. `\botrule` is a
journal-class macro (`sn-jnl`-style), `\bottomrule` is `booktabs`. Pick one per
the *Language* class and use it throughout, or the tables will rule
inconsistently if they compile at all.

---

## B. Claims contradicted by the draft's own tables

### B1. The monolingual open-monosyllable range is wrong — line ~277 body text

The text says vowels /i y u e a/ permit open monosyllables at

> "17–52% in the monolingual corpus"

`tab:min`'s own %-Open column for those five vowels reads: /y/ 52.4, /u/ 17.4,
/i/ 43.6, /e/ **62.8**, /a/ 39.2. The range is **17–63%**, not 17–52%. The
upper bound was taken from /y/ and missed /e/.

The wordlist range in the same sentence ("4–15%") is correct: 3.7–14.8.

### B2. Figure `fig:vowels` n disagrees with its own caption

- body text (line 217): "the mean F1 and F2 values of **388,502** vowels"
- caption (line 259): "(n=**387,436** vowels)"

Same figure. One of these is from a different filtering pass; both need to come
from the same regenerated count.

### B3. `/ɵ/` is described as never occurring in open monosyllables

§"The minimal word" concludes that "/ø/, /ʉ/, and /ɵ/ require a consonant coda
to constitute a minimal word". But `tab:min` gives /ɵ/ at 1.1% (wordlist) and
1.7% (monolingual) — small but non-zero, and the text itself says so two
sentences earlier ("appears in open monosyllables at only 1% ... and 2%").
The generalisation in example `(\ref{minword})` is stated as categorical for all
three vowels. Either scope it to /ø/ and /ʉ/ and treat /ɵ/ as a strong
tendency, or say explicitly that the residual 1–2% are treated as exceptions
and show what they are.

---

## C. Transcription and gloss errors

### C1. `кимĕ` glossed 'chick' with the transcription of `чĕпĕ` — line 331

> `кимĕ` /t͡ʃøpø/ 'chick'

`кимĕ` is 'boat', and would be /kimø/. /t͡ʃøpø/ is `чĕпĕ` 'chick' — which is
what the examples at lines 348, 351 and 354 use. Fix: change the Cyrillic to
`чĕпĕ`, or keep `кимĕ` and change the gloss and transcription to 'boat' /kimø/.
The surrounding argument needs a word that alternates with a geminate, so
`чĕпĕ` (cf. /t͡ʃøpp-øm/ 'my chick') is the one that carries it.

### C2. `сула` given for /laʃa/ 'horse' — line 331

> `сула` /laʃa/ 'horse'

'horse' is `лаша`, as correctly written in example (1a) at line 6. `сула` is a
different word. Fix: `лаша`.

### C3. `/laʃa/` vs `/laša/` — inconsistent transcription of the same word

Line 6 (example 1a) has `laš\'a`; line 349 has `/la\textipa{S}a/`. Same word,
two conventions. Since §"Symbolic representations" commits to IPA, use
/laˈʃa/ throughout and drop the `š`.

---

## D. Internal inconsistencies in the vowel description

### D1. Backness is described three different ways

| source | /ʉ/ | /ɵ/ | /a/ | /u/ |
|---|---|---|---|---|
| `config/phonology_params.R` `VOWEL_BACKNESS` | back | back | **central** | back |
| draft §"General vowel acoustics" (line 399) | central | central | central | back |
| draft `tab:vowels` (phonological features) | [−front] | [−front] | [−front] | [−front] |

The config and the prose disagree about /ʉ/ and /ɵ/; the prose and `tab:vowels`
disagree about whether the relevant contrast is three-way (front/central/back,
phonetic) or two-way ([±front], phonological). Both can be true if stated as
such — phonetic backness from F2, phonological [±front] from harmony behaviour —
but the draft currently presents them as one fact described inconsistently.

Decide which is the phonological claim, make `VOWEL_BACKNESS` in the config
match it, and label the other table explicitly as phonetic.

### D2. `\textipa{0}` is probably not the intended glyph

The draft writes /ʉ/ as `\textipa{0}` throughout, and `tab:vowels1` states the
present analysis uses `\textbaru{}` for `ы`. In TIPA, `\textbaru` is ʉ;
`\textipa{0}` is not a documented TIPA shortcut and will not reliably produce
ʉ. Replace every `\textipa{0}` with `\textbaru{}` (or `\textipa{\textbaru}`)
and every `\textipa{8}` with the intended `ɵ` glyph, then check the rendered
PDF vowel-by-vowel against `tab:vowels1`.

### D3. Zheltov year

The draft cites `Zheltov2008` (31,403 words, modern literary Chuvash, 26
sources) — consistently, in 8 places. But `config/phonology_params.R`'s
`CORPORA` registry says "Zheltov (1875) wordlist". The config is wrong; fix it
there so the two never diverge in a methods description generated from it.

---

## E. Structural leftovers

The draft currently contains two parallel outlines: a written-through version
(§Introduction … §Conclusion, lines 1–~640) and a second skeleton of empty
section headings (§"Background: Stress, Prominence, and Sonority" onward,
~line 700+), plus a §"Notes" section of working notes and reviewer replies, and
several orphaned paragraphs after `\end{document}`.

Anything after `\end{document}` is **not compiled** — including the final
paragraphs on Dobrovolsky replication, `fig:ss`, `fig:dv`, `fig:dc`, `fig:f0`,
and the Tighe et al. comparison. If that material is meant to be in the paper it
has to move above `\end{document}`; at the moment it is invisible in the PDF.
