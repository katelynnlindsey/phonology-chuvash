# overnight/sociophonetics/01_extract_f0.R
# Adds f0_step10/f0_step11 (for f0_mid, as defined in analyses/f0_measure.R) keyed by
# word_id + sidx + start, to merge with cache/vowels_socio.parquet.
suppressPackageStartupMessages({library(data.table); library(arrow)})
A <- "/Users/kate/Documents/GitHub/phonology-chuvash/9-analyze"
OUT <- file.path(A, "output/overnight_2026-10-01/sociophonetics/cache")
v <- as.data.table(readRDS(file.path(A, "data/leveled/vowels_spoken_annotated.rds")))
v <- v[, .(word_id, sidx, start, f0_step10, f0_step11)]
gc()
cat("dup keys:", anyDuplicated(v[, .(word_id, sidx, start)]), "\n")
write_parquet(v, file.path(OUT, "f0_steps.parquet"))
cat("rows", nrow(v), "\n")
