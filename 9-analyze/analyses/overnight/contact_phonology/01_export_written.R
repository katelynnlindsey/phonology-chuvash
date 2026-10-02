# Export written-corpus word types (pre-cleaning, so loans are still present) for the loan classifier.
suppressPackageStartupMessages({library(data.table); library(arrow)})
root <- "/Users/kate/Documents/GitHub/phonology-chuvash/9-analyze"
out <- file.path(root, "output/overnight_2026-10-01/contact_phonology/cache")
for (f in c("zheltov_raw", "mono_raw")) {
  d <- readRDS(file.path(root, "data/loaded", paste0(f, ".rds")))
  cat(f, nrow(d), "\n"); print(str(d))
  d <- as.data.table(d)
  write_parquet(d, file.path(out, paste0(f, ".parquet")))
}
for (f in c("zheltov_annotated", "mono_annotated")) {
  d <- readRDS(file.path(root, "data/leveled", paste0(f, ".rds")))
  cat(f, nrow(d), "\n"); print(names(d)); print(head(as.data.frame(d), 3))
}
