# Overnight 2026-10-01, track typology_literature.
# Export WORD-TYPE tables (one row per orthographic type) from the leveled
# written corpora, keeping only the columns the typology analyses need.
# Read-only on data/; writes to output/overnight_2026-10-01/typology_literature/.
#
# Run (from 9-analyze):
#   LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8 Rscript --vanilla \
#     analyses/overnight/typology_literature/00_export_types.R
suppressPackageStartupMessages({ library(data.table) })
stopifnot(grepl("UTF-8", Sys.getlocale("LC_CTYPE"), ignore.case = TRUE))
out_dir <- "output/overnight_2026-10-01/typology_literature"
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

keep <- c("word_label", "word_label_IPA", "word_label_IPA_syllabified",
          "sN", "word_cat_6", "corpus_freq", "in_wordlist", "in_mono_corpus")

z <- as.data.table(readRDS("data/leveled/zheltov_annotated.rds"))
m <- as.data.table(readRDS("data/leveled/mono_annotated.rds"))
cat("zheltov syllable rows", nrow(z), " mono syllable rows", nrow(m), "\n")

zt <- unique(z[, intersect(keep, names(z)), with = FALSE], by = "word_label")
mt <- unique(m[, intersect(keep, names(m)), with = FALSE], by = "word_label")
rm(z, m); invisible(gc())
cat("zheltov types", nrow(zt), " mono types", nrow(mt),
    " mono in_wordlist", sum(mt$in_wordlist, na.rm = TRUE), "\n")

fwrite(zt, file.path(out_dir, "types_zheltov.csv"))
fwrite(mt, file.path(out_dir, "types_mono.csv"))
