# Legacy analysis scripts — superseded, kept for reference

These four scripts predate the `config/` + `pipeline/` + `analyses/` structure.
They were moved here on 2026-09-25. **Nothing in the live pipeline reads them**,
and they do not read `config/phonology_params.R` — they are self-contained and
carry their own copies of the phonological assumptions.

| script | size | superseded by |
|---|---|---|
| `phonology_chuvash_combined.R` | 98 KB | the whole `pipeline/` + `analyses/` structure |
| `phonology-chuvash.R` | 44 KB | `pipeline/02_clean.R`–`04_annotate.R` |
| `phonology-chuvash-contour.R` | 24 KB | `7-extract/contours/` + `pipeline/01_load_raw.R` |
| `phonology-chuvash-fave.R` | 20 KB | `7-extract/vowel_points/` + `pipeline/01_load_raw.R` |

## Do not copy code out of these without checking it first

They are kept because they contain figure code and exploratory analyses that
have not all been ported yet. But they encode assumptions that have since been
found wrong or that have been renamed, and reusing them as-is would reintroduce
those problems:

- **Old rule naming.** They use `stress_rule_A`–`stress_rule_F` for what are now
  `A6 A5 A4 B6 B5 B4`. Critically, the old `stress_rule_B` meant *inventory 5
  with the leftmost-reduced default* — it is now `stress_rule_A5`, **not**
  `stress_rule_B5`. See `output/column_migration_2026-09-25.csv`.
- **`total_intensity` as the amplitude measure.** `phonology_chuvash_combined.R`
  fits `lmer(total_intensity ~ ...)` in several places. That variable is the sum
  of 20 per-step dB readings including undefined-coded-as-zero cells; it
  correlates with duration at r = 0.909 and is a duration measure. This is the
  source of the "162 dB" figure in the draft. Use the mean of
  `intensity_step10` and `intensity_step11` instead.
- **Their own `classify_vowel()`.** `phonology_chuvash_combined.R` defines a
  single-argument `classify_vowel(v)` that shadows the config function of the
  same name. If you source both, whichever comes last wins, silently.
- **Circular stress columns.** They filter on `stress_cat == stress_rule_A`,
  where `stress_cat` is itself derived from the active rule, so the comparison
  is tautological.

## If you need something from here

Port it into `analyses/` as a script that sources
`analyses/00_session_setup.R`, reads the current column names, and uses the
current intensity measure. Then delete the ported section from the legacy file
so it stops being a second source of truth.
