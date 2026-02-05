library(tidyverse)
library(scales)
library(rcompanion)
library(gmodels)
library(vowels)
library(graphics)
library(gmodels)
library(ggplot2)
library(ggpubr)
library(phonR)
library(hrbrthemes)
library(viridis)
library(forcats)
library(patchwork)
library(partykit)

all_chuvash_vowel_points <- read.csv("~/GitHub/phonology-chuvash/extract/all_chuvash_vowel_points.csv", encoding="UTF-8")

all_chuvash_vowel_points$dur <- all_chuvash_vowel_points$dur*1000

#REMOVE NON-VOWELS
vowel_labels <- c('AA', 'AH', 'EH', 'EY', 'IX', 'IY', 'UX', 'UW')

df_vowels_only <- all_chuvash_vowel_points %>%
  filter(label %in% vowel_labels)

vowels_removed_count <- nrow(all_chuvash_vowel_points) - nrow(df_vowels_only)
print(paste(vowels_removed_count, "rows removed because 'label' was not identified as a vowel."))
print(paste("DataFrame shape after vowel filtering:", nrow(df_vowels_only), "rows,", ncol(df_vowels_only), "columns"))

df_vowels_only$label <- str_replace(df_vowels_only$label,"AA","a")
df_vowels_only$label <- str_replace(df_vowels_only$label,"IY","i")
df_vowels_only$label <- str_replace(df_vowels_only$label,"UX","y")
df_vowels_only$label <- str_replace(df_vowels_only$label,"EY","e")
df_vowels_only$label <- str_replace(df_vowels_only$label,"EH","ø")
df_vowels_only$label <- str_replace(df_vowels_only$label,"IX","ʉ")
df_vowels_only$label <- str_replace(df_vowels_only$label,"UW","u")
df_vowels_only$label <- str_replace(df_vowels_only$label,"AH","ɵ")

#REMOVE RUSSIAN LOANWORDS
russian_latin_sequences <- c('ZH','ts','B','G','D','F','Z','O','Б','Г','Д','О','Ж','Ц','Ф','З','Ë','ё','Ё')

russian_pattern <- paste(sapply(russian_latin_sequences, stringr::fixed), collapse = "|")

initial_rows_russian_filter <- nrow(df_vowels_only)

mask_russian_words <- stringr::str_detect(stringr::str_to_upper(df_vowels_only$word), russian_pattern)

df_no_russian <- df_vowels_only %>%
  filter(!mask_russian_words)

russian_rows_removed <- initial_rows_russian_filter - nrow(df_no_russian)
print(paste(russian_rows_removed, "rows removed due to specified Russian orthography in 'word' column."))
print(paste("DataFrame shape after Russian sequence filtering:", nrow(df_no_russian), "rows,", ncol(df_no_russian), "columns"))


# REMOVE OUTLIERS
filtered_df <- df_no_russian

outlier_columns <- c('F1', 'F2', 'dur', 'intensity', 'f0')


for (col in outlier_columns) {
  print(paste("Filtering outliers for column:", col))
    
  filtered_df <- filtered_df %>%
    group_by(label, phon_stress) %>%
    mutate(
      Q1 = quantile(!!sym(col), 0.25, na.rm = TRUE),
      Q3 = quantile(!!sym(col), 0.75, na.rm = TRUE),
      IQR = Q3 - Q1,
      lower_bound = Q1 - 1.5 * IQR,
      upper_bound = Q3 + 1.5 * IQR
    ) %>%
    filter(!!sym(col) >= lower_bound & !!sym(col) <= upper_bound) %>%
    ungroup() %>% # Ungroup after filtering to avoid issues in subsequent operations
    select(-Q1, -Q3, -IQR, -lower_bound, -upper_bound) # Remove temporary colum
}

# Calculate removed rows after all filters are applied
outlier_rows_removed <- nrow(df_no_russian) - nrow(filtered_df)
print(paste(outlier_rows_removed, " rows were identified as outliers and removed by IQR method.", sep = ""))
print(paste("Final Filtered DataFrame shape:", nrow(filtered_df), "rows,", ncol(filtered_df), "columns"))

total_rows_removed <- nrow(all_chuvash_vowel_points) - nrow(filtered_df)
print(paste("Total", total_rows_removed, "rows removed from the original DataFrame."))

# C-Tree for Duration
print(paste("DataFrame shape for ctree analysis:", nrow(filtered_df), "rows,", ncol(filtered_df), "columns"))
print("Columns available:")
print(colnames(filtered_df))

ctree_data <- filtered_df %>%
  mutate(
    label = as.factor(label),
    phon_stress = as.factor(phon_stress),
    syl_open_closed = as.factor(syl_open_closed),
    corpus = as.factor(corpus),
    pre_seg = as.factor(pre_seg),
    fol_seg = as.factor(fol_seg),
    syl_pos = as.factor(syl_pos)
  )

ctree_formula <- dur ~ label + phon_stress + F1 + syl_pos + syl_open_closed

chuvash_ctree_model_controlled <- ctree(ctree_formula, data = ctree_data,
                                        control = ctree_control(
                                          mincriterion = 0.99, # More stringent significance level (alpha = 0.01)
                                          minbucket = 3000,     # Min observations in terminal node
                                          maxdepth = 3        # Max depth of the tree
                                        ))

plot(chuvash_ctree_model_controlled, type = "simple", main = "Conditional Inference Tree for Chuvash Vowel Duration (Controlled)")

## F1xF2 plot

palatal_segments <- c("J","SH","ɕ","ɕː","tʃ","ʃː")
palatal_pattern <- paste(palatal_segments, collapse = "|")

non_palatal_data <- filtered_df %>%
  mutate(
    pre_is_palatal = str_detect(pre_seg, palatal_pattern),
    context_type = case_when(
      pre_is_palatal ~ "Palatal Context",
      TRUE ~ "Non-Palatal Context"
    )
  ) %>%
  filter(context_type == "Non-Palatal Context") %>%
  select(label, F1, F2,pre_seg,word)


with(non_palatal_data, plotVowels(F1, F2, label, output = "pdf", plot.tokens = FALSE, pch.tokens = label, 
                      cex.tokens = 1.2, alpha.tokens = 0.2, plot.means = TRUE, pch.means = label, 
                      cex.means = 2, var.col.by = label, family = "Charis SIL", pretty = TRUE, 
                      ellipse.line=TRUE, xlim = c(3200, 600), ylim = c(1000, 200), xlab="F2 (Hz.)", ylab="F1 (Hz.)"))


# DURATION plot
filtered_df %>% ggplot(aes(x=dur, y=label, fill=label)) + 
  geom_boxplot(notch=TRUE) +
  scale_fill_viridis(discrete = TRUE, alpha=0.6) +
  #geom_jitter(color="black", size=0.4, alpha=0.9) +
  theme_minimal() +
  theme(legend.position="none",plot.title=element_text(size=11)) +
  ggtitle("Chuvash vowel duration") +
  xlab("Duration (ms)") +
  ylab("Vowel")

# Violin plots for medial unstressed vowels
filtered_vowels_for_plots <- filtered_df %>%
  filter(phon_stress == "0", syl_pos == "med")

strong_vowels <- c("a", "i", "y", "e","ʉ","u")
weak_vowels <- c("ø", "ɵ")

filtered_vowels_for_plots <- filtered_vowels_for_plots %>%
  mutate(
    vowel_strength_type = case_when(
      label %in% strong_vowels ~ "Strong",
      label %in% weak_vowels  ~ "Weak",
      TRUE                     ~ "Undefined" # Catch any labels not classified
    ) %>% factor(levels = c("Weak", "Strong")) # Set factor levels for desired order in legend
  )

ordered_labels_dur <- filtered_vowels_for_plots %>%
  group_by(label) %>%
  summarise(mean_val = mean(dur, na.rm = TRUE)) %>%
  arrange(mean_val) %>%
  pull(label) # Extract just the ordered labels

ordered_labels_f0 <- filtered_vowels_for_plots %>%
  group_by(label) %>%
  summarise(mean_val = mean(f0, na.rm = TRUE)) %>%
  arrange(mean_val) %>%
  pull(label)

ordered_labels_intensity <- filtered_vowels_for_plots %>%
  group_by(label) %>%
  summarise(mean_val = mean(intensity, na.rm = TRUE)) %>%
  arrange(mean_val) %>%
  pull(label)

long_format_data <- filtered_vowels_for_plots %>%
  select(label, vowel_strength_type, dur, f0, intensity) %>%
  pivot_longer(
    cols = c(dur, f0, intensity),
    names_to = "measure_type",
    values_to = "value"
  ) %>%
  mutate(
    measure_type = factor(measure_type,
                          levels = c("dur", "f0", "intensity"),
                          labels = c("Duration (ms)", "f0 (Hz)", "Intensity (dB)"))
  )

plot_dur <- ggplot(filter(long_format_data, measure_type == "Duration (ms)"),
                   aes(x = factor(label, levels = ordered_labels_dur), y = value, fill = vowel_strength_type)) +
  geom_violin(trim = TRUE, scale = "width") +
  geom_boxplot(width = 0.15, fill = "white", alpha = 0.6, outlier.shape = NA) +
  labs(title = "Duration (ms)", x = NULL, y = "Duration (ms)") + # x=NULL removes 'Vowel' label
  theme_minimal() +
  theme(
    plot.title = element_text(hjust = 0.5, face = "bold", size = 14),
    axis.text.x = element_text(angle = 45, hjust = 1, size = 10, face = "bold"),
    axis.text.y = element_text(size = 10),
    legend.position = "none" # Hide legend for individual plots
  ) +
  scale_fill_manual(values = c("Weak" = "#FD8D3C", "Strong" = "#9ECAE1"))

# Plot for f0
plot_f0 <- ggplot(filter(long_format_data, measure_type == "f0 (Hz)"),
                  aes(x = factor(label, levels = ordered_labels_f0), y = value, fill = vowel_strength_type)) +
  geom_violin(trim = TRUE, scale = "width") +
  geom_boxplot(width = 0.15, fill = "white", alpha = 0.6, outlier.shape = NA) +
  labs(title = "f0 (Hz)", x = NULL, y = "f0 (Hz)") + # x=NULL removes 'Vowel' label
  theme_minimal() +
  theme(
    plot.title = element_text(hjust = 0.5, face = "bold", size = 14),
    axis.text.x = element_text(angle = 45, hjust = 1, size = 10, face = "bold"),
    axis.text.y = element_text(size = 10),
    legend.position = "none"
  ) +
  scale_fill_manual(values = c("Weak" = "#FD8D3C", "Strong" = "#9ECAE1"))

# Plot for Intensity
plot_intensity <- ggplot(filter(long_format_data, measure_type == "Intensity (dB)"),
                         aes(x = factor(label, levels = ordered_labels_intensity), y = value, fill = vowel_strength_type)) +
  geom_violin(trim = TRUE, scale = "width") +
  geom_boxplot(width = 0.15, fill = "white", alpha = 0.6, outlier.shape = NA) +
  labs(title = "Intensity (dB)", x = NULL, y = "Intensity (dB)") + # x=NULL removes 'Vowel' label
  theme_minimal() +
  theme(
    plot.title = element_text(hjust = 0.5, face = "bold", size = 14),
    axis.text.x = element_text(angle = 45, hjust = 1, size = 10, face = "bold"),
    axis.text.y = element_text(size = 10),
    legend.position = "none",
    legend.title = element_text(size = 11, face = "bold"),
    legend.text = element_text(size = 10)
  ) +
  scale_fill_manual(values = c("Weak" = "#FD8D3C", "Strong" = "#9ECAE1"), name = "Vowel Type")

combined_plots <- plot_dur / plot_f0 / plot_intensity + # Use '/' operator for vertical stacking
  plot_layout(ncol = 1) + # Explicitly set to 1 column for vertical stack (though '/' implies it)
  plot_annotation(theme = theme(plot.title = element_text(hjust = 0.5, face = "bold", size = 18))
  )

# Print the combined plot
print(combined_plots)

ggsave("chuvash_vowels.pdf",
       plot = combined_plots,
       width = 8.5,
       height = 10,
       device = cairo_pdf,
       family = "Charis SIL"
)


# Required packages
pkgs <- c("ggplot2","dplyr","tidyr","lme4","lmerTest","rstatix","cowplot","emmeans")
install_if_missing <- function(p) if (!requireNamespace(p, quietly = TRUE)) install.packages(p)
invisible(lapply(pkgs, install_if_missing))
library(ggplot2); library(dplyr); library(tidyr)
library(lme4); library(lmerTest); library(rstatix); library(cowplot); library(emmeans)

# Use your data frame name here
df <- filtered_df

# Quick data checks / standardization
# Ensure key columns exist and types are sensible
df <- df %>%
  mutate(
    dur = as.numeric(dur),
    f0 = as.numeric(f0),
    intensity = as.numeric(intensity),
    speaker = factor(speaker_num),   # or speaker if you have that
    word = factor(word),
    phon_stress = as.character(phon_stress) # adjust as needed
  )

# Create a stress factor "stressed"/"unstressed" if phon_stress is 0/1
if(all(df$phon_stress %in% c("0","1","0 ","1 "))) {
  df <- df %>% mutate(stress = factor(ifelse(trimws(phon_stress) %in% c("1"), "stressed", "unstressed"),
                                      levels = c("unstressed","stressed")))
} else if(!"stressed" %in% unique(df$phon_stress)) {
  # if phon_stress already uses other labels, adapt here as needed
  df <- df %>% mutate(stress = factor(phon_stress))
} else {
  df <- df %>% mutate(stress = factor(phon_stress, levels = c("unstressed","stressed")))
}

# You said "weak" and "strong" — if you have a column for that, use it; otherwise create it:
# Example: assume label or another column has markers for strength; replace with your logic.
# If you already have vowel_strength column, skip this.

strong_vowels <- c("a", "i", "y", "e","ʉ","u")
weak_vowels <- c("ø", "ɵ")

df <- df %>%
  mutate(
    vowel_strength_type = case_when(
      label %in% strong_vowels ~ "Strong",
      label %in% weak_vowels  ~ "Weak",
      TRUE                     ~ "Undefined" # Catch any labels not classified
    ) %>% factor(levels = c("Weak", "Strong")) # Set factor levels for desired order in legend
  )


# Subsets for comparisons
# 1) initial position, weak vowels
# Assume syl_pos or sidx/sN indicates position; using syl_pos (values like "initial","med","final")
initial_weak <- df %>% filter(syl_pos == "initial", vowel_strength_type == "Weak")

# 2) words that contain only weak vowels: you said you have many files; create word-level flag
# Identify words where every vowel token in that word is weak
words_weak_only <- df %>%
  group_by(word) %>%
  summarize(all_weak = all(vowel_strength_type == "Weak"), .groups = "drop") %>%
  filter(all_weak) %>%
  pull(word)

only_weak_words <- df %>% filter(word %in% words_weak_only, vowel_strength_type == "Weak")

# 3) strong vowels (stressed vs unstressed)
strong_vowel <- df %>% filter(vowel_strength_type == "Strong")

# A plotting helper
plot_metric_by_stress <- function(data, metric, title = NULL, palette = c("#66c2a5","#fc8d62")) {
  metric_sym <- rlang::sym(metric)
  # remove NA
  data2 <- data %>% filter(!is.na(!!metric_sym), !is.na(stress))
  if(nrow(data2) < 2) {
    message("Not enough data for ", title)
    return(NULL)
  }
  p <- ggplot(data2, aes(x = stress, y = !!metric_sym, fill = stress)) +
    geom_violin(trim = TRUE, alpha = 0.35) +
    geom_boxplot(width = 0.12, outlier.shape = NA, alpha = 0.7) +
    #geom_jitter(width = 0.15, alpha = 0.6, size = 1) +
    scale_fill_manual(values = palette) +
    theme_minimal(base_size = 13) +
    labs(title = title, x = "Stress", y = metric) +
    theme(legend.position = "none")
}

plot_metric_with_meddiff <- function(data, metric, title = NULL, palette = c("#66c2a5","#fc8d62"),
                                     label_fmt = function(x) sprintf("%.3f", x)) {
  # data: data.frame with columns 'stress' and metric column, stress has two levels: unstressed, stressed
  metric_sym <- rlang::sym(metric)
  data2 <- data %>% filter(!is.na(.data[[metric]]), !is.na(stress))
  if(nrow(data2) < 2) return(ggplot() + ggtitle("Not enough data"))
  # compute medians
  med_df <- data2 %>%
    group_by(stress) %>%
    summarise(med = median(.data[[metric]], na.rm = TRUE), .groups = "drop")
  # ensure ordering: unstressed first, stressed second
  med_un <- med_df$med[med_df$stress == "unstressed"]
  med_st  <- med_df$med[med_df$stress == "stressed"]
  # handle missing levels gracefully
  if(length(med_un) == 0 || length(med_st) == 0) {
    stop("stress factor must contain 'unstressed' and 'stressed' levels")
  }
  med_diff <- med_st - med_un
  # format label: customize for metric (e.g., dur in seconds -> ms)
  label_text <- label_fmt(med_diff)
  # y positions for connector and label
  ymax <- max(data2[[metric]], na.rm = TRUE)
  ymin <- min(data2[[metric]], na.rm = TRUE)
  y_connector <- max(med_un, med_st) + 0.03 * (ymax - ymin)   # connector slightly above higher median
  y_label <- y_connector + 0.02 * (ymax - ymin)
  # build plot
  ggplot(data2, aes(x = stress, y = .data[[metric]], fill = stress)) +
    geom_violin(trim = TRUE, alpha = 0.35, color = "black") +
    geom_boxplot(width = 0.12, outlier.shape = NA, alpha = 0.8) +
    stat_summary(fun = median, geom = "point", size = 2, color = "black") +
    scale_fill_manual(values = palette) +
    labs(title = title, y = metric, x = "Stress") +
    theme_minimal(base_size = 12) +
    theme(legend.position = "none") +
    # median connector
    geom_segment(aes(x = 1, xend = 2, y = med_un, yend = med_st), inherit.aes = FALSE, color = "black", size = 0.8) +
    # small vertical caps to make connector look like bracket
    geom_segment(aes(x = 1, xend = 1, y = med_un, yend = med_un + 0.01 * (ymax - ymin)), inherit.aes = FALSE, color = "black", size = 0.8) +
    geom_segment(aes(x = 2, xend = 2, y = med_st, yend = med_st + 0.01 * (ymax - ymin)), inherit.aes = FALSE, color = "black", size = 0.8) +
    # label showing median difference
    annotate("text", x = 1.5, y = y_label, label = paste0("Δ median = ", label_text), vjust = 0, size = 3.5)
}

# Make plots for each comparison and metric
p_init_dur <- plot_metric_with_meddiff(initial_weak, "dur", "Initial position, weak vowels: Duration (ms)")
p_onlyweak_dur <- plot_metric_with_meddiff(only_weak_words, "dur", "Only-weak words: Duration (ms)")
p_strong_dur <- plot_metric_with_meddiff(strong_vowel, "dur", "Strong vowels: Duration (ms)")

p_init_f0 <- plot_metric_with_meddiff(initial_weak, "f0", "Initial position, weak vowels: f0 (Hz)")
p_onlyweak_f0 <- plot_metric_with_meddiff(only_weak_words, "f0", "Only-weak words: f0 (Hz)")
p_strong_f0 <- plot_metric_with_meddiff(strong_vowel, "f0", "Strong vowels: f0 (Hz)")

p_init_int <- plot_metric_with_meddiff(initial_weak, "intensity", "Initial position, weak vowels: Intensity (dB)")
p_onlyweak_int <- plot_metric_with_meddiff(only_weak_words, "intensity", "Only-weak words: Intensity (dB)")
p_strong_int <- plot_metric_with_meddiff(strong_vowel, "intensity", "Strong vowels: Intensity (dB)")

# Example: show duration plots in one row (if running interactively)
plot_grid(p_init_dur, p_onlyweak_dur, p_strong_dur, nrow = 1)
plot_grid(p_init_dur, p_init_f0, p_init_int, nrow = 3)


top_row <- plot_grid(p_init_dur, p_onlyweak_dur, p_strong_dur, nrow = 1)
mid_row <- plot_grid(p_init_f0, p_onlyweak_f0, p_strong_f0, nrow = 1)
bot_row <- plot_grid(p_init_int, p_onlyweak_int, p_strong_int, nrow = 1)

full_plot <- plot_grid(top_row, mid_row, bot_row, ncol = 1, rel_heights = c(1,1,1))
print(full_plot)


# Required packages
pkgs <- c("dplyr","tidyr","ggplot2","rlang")
for(p in pkgs) if(!requireNamespace(p, quietly = TRUE)) install.packages(p)
library(dplyr); library(tidyr); library(ggplot2); library(rlang)

# Assume your main data.frame is df
# Ensure important columns exist and are correct type
df <- df %>%
  mutate(
    sN = as.integer(sN),             # number of syllables in word
    syl_pos = as.character(syl_pos), # e.g., "initial", "med", "final" or numeric index if you have one
    dur = as.numeric(dur),
    f0 = as.numeric(f0),
    intensity = as.numeric(intensity),
    word = as.character(word),
  )


# Next: identify syllable index within the word.
# If you have an explicit syllable index column (e.g., sidx), use that. Otherwise try to infer from prop_time or rel_time.
# Here I assume sidx or an index-like column exists; if not, replace with your syllable-index variable.
# We'll try to use sidx if present; otherwise assume syl_pos encodes position strings we can map.

if("sidx" %in% names(df)) {
  df <- df %>% mutate(syll_idx = as.integer(sidx))
} else {
  # attempt mapping from syl_pos strings like "initial","med","final" -> 1,2,...
  df <- df %>% mutate(syll_idx = case_when(
    tolower(syl_pos) %in% c("initial","onset","1","first","first_syll") ~ 1L,
    tolower(syl_pos) %in% c("med","middle","2","second") ~ 2L,
    tolower(syl_pos) %in% c("final","last","3","third") ~ 3L,
    TRUE ~ NA_integer_
  ))
}

# Filter to two-syllable words
df2 <- df %>% filter(!is.na(syll_idx), sN == 2)

# Keep only one token per syllable per word (if there are multiple tokens per syllable choose the vowel token you use).
# We'll compute median per word/syllable for dur, f0, intensity to robustly summarize the syllable's acoustic values.
word_syll_meds <- df2 %>%
  group_by(word, speaker, syll_idx, vowel_strength_type) %>%
  summarise(
    med_dur = median(dur, na.rm = TRUE),
    med_f0 = median(f0, na.rm = TRUE),
    med_intensity = median(intensity, na.rm = TRUE),
    n_tokens = n(),
    .groups = "drop"
  )

# We want one row per word with columns for syllable1 and syllable2 medians.
# Pivot wider so we have medians for syl1 and syl2 in the same row.
word_pair <- word_syll_meds %>%
  filter(syll_idx %in% c(1,2)) %>%
  select(word, speaker, syll_idx, vowel_strength_type, med_dur, med_f0, med_intensity) %>%
  pivot_wider(
    names_from = syll_idx,
    names_prefix = "syl",
    values_from = c(vowel_strength_type, med_dur, med_f0, med_intensity),
    names_sep = ""
  ) %>%
  # Only keep rows where both syllables present
  filter(!is.na(vowel_strength_typesyl1), !is.na(vowel_strength_typesyl2))

# Create sequence type: e.g. "WS", "SS", "SW", "WW"
word_pair <- word_pair %>%
  mutate(
    seq = paste0(substr(vowel_strength_typesyl1,1,1) %>% toupper(), substr(vowel_strength_typesyl2,1,1) %>% toupper())
  )

# Keep only the sequences of interest (WW, WS, SW, SS)
word_pair <- word_pair %>% filter(seq %in% c("WW","WS","SW","SS"))

# Compute median differences (syl2 - syl1) per metric and per seq
seq_summary <- word_pair %>%
  group_by(seq) %>%
  summarise(
    n_words = n(),
    med_dur_syl1 = median(med_dursyl1, na.rm = TRUE),
    med_dur_syl2 = median(med_dursyl2, na.rm = TRUE),
    med_dur_diff = median(med_dursyl2 - med_dursyl1, na.rm = TRUE),
    med_dur_pct = 100 * (med_dur_syl2 - med_dur_syl1) / med_dur_syl1,
    med_f0_syl1 = median(med_f0syl1, na.rm = TRUE),
    med_f0_syl2 = median(med_f0syl2, na.rm = TRUE),
    med_f0_diff = median(med_f0syl2 - med_f0syl1, na.rm = TRUE),
    med_f0_cents = median(1200 * log2(med_f0syl2 / med_f0syl1), na.rm = TRUE),
    med_int_syl1 = median(med_intensitysyl1, na.rm = TRUE),
    med_int_syl2 = median(med_intensitysyl2, na.rm = TRUE),
    med_int_diff = median(med_intensitysyl2 - med_intensitysyl1, na.rm = TRUE),
    .groups = "drop"
  )

# Print summary table
print(seq_summary)


# OPTIONAL: Visualize — paired medians for each sequence type (syl1 vs syl2)
plot_paired <- function(dfpair, metric_prefix, metric_label, units_label = "") {
  # metric_prefix like "med_dur" -> expects med_dursyl1, med_dursyl2 present
  m1 <- paste0(metric_prefix, "syl1")
  m2 <- paste0(metric_prefix, "syl2")
  ggplot(dfpair, aes(x = factor(1), y = .data[[m1]])) + # dummy plot to set up facets below
    geom_blank() +
    facet_wrap(~ seq, scales = "free_y") +
    theme_minimal() +
    labs(y = paste(metric_label, units_label), x = NULL) +
    # overlay paired points and connecting lines using the underlying data:
    geom_segment(data = dfpair, aes(x = 0.9, xend = 1.1, y = .data[[m1]], yend = .data[[m2]]),
                 color = "gray70", alpha = 0.4, inherit.aes = FALSE) +
    geom_point(data = dfpair, aes(x = 0.9, y = .data[[m1]]), color = "#66c2a5", size = 1.6) +
    geom_point(data = dfpair, aes(x = 1.1, y = .data[[m2]]), color = "#fc8d62", size = 1.6) +
    # add median markers per facet
    stat_summary(data = dfpair, aes(x = 0.9, y = .data[[m1]]), fun = median, geom = "point", color = "black", size = 3) +
    stat_summary(data = dfpair, aes(x = 1.1, y = .data[[m2]]), fun = median, geom = "point", color = "black", size = 3) +
    scale_x_continuous(breaks = c(0.9,1.1), labels = c("syl1","syl2"))
}

p_dur_pairs <- ggplot() # simpler to create separate small plots below if desired

word_pair <- word_pair %>% mutate(dur_diff = med_dursyl2 - med_dursyl1,
                                  f0_diff = med_f0syl2 - med_f0syl1,
                                  f0_diff_cents = 1200 * log2(med_f0syl2 / med_f0syl1),
                                  int_diff = med_intensitysyl2 - med_intensitysyl1)

med_labels_dur <- word_pair %>%
  group_by(seq) %>%
  summarise(med = median(dur_diff, na.rm = TRUE),
            ymax = max(dur_diff, na.rm = TRUE),
            ymin = min(dur_diff, na.rm = TRUE),
            .groups = "drop") %>%
  # position the label a bit above the max for that seq
  mutate(label_y = ymax + 0.05 * (ymax - ymin),
         label = sprintf("%.3f ms", med))

med_labels_f0 <- word_pair %>%
  group_by(seq) %>%
  summarise(med = median(f0_diff, na.rm = TRUE),
            ymax = max(f0_diff, na.rm = TRUE),
            ymin = min(f0_diff, na.rm = TRUE),
            .groups = "drop") %>%
  # position the label a bit above the max for that seq
  mutate(label_y = ymax + 0.05 * (ymax - ymin),
         label = sprintf("%.3f Hz", med))

med_labels_int <- word_pair %>%
  group_by(seq) %>%
  summarise(med = median(int_diff, na.rm = TRUE),
            ymax = max(int_diff, na.rm = TRUE),
            ymin = min(int_diff, na.rm = TRUE),
            .groups = "drop") %>%
  # position the label a bit above the max for that seq
  mutate(label_y = ymax + 0.05 * (ymax - ymin),
         label = sprintf("%.3f dB", med))

# Example: quick boxplot of median differences per sequence
SSdur <- ggplot(word_pair, aes(x = seq, y = med_dursyl2 - med_dursyl1)) +
  geom_boxplot() + theme_minimal() + labs(y = "Median dur (ms) difference: syl2 - syl1", x = "Sequence")
top <- SSdur + geom_text(data = med_labels_dur, aes(x = seq, y = label_y, label = label), inherit.aes = FALSE, size = 3)

SSf0 <- ggplot(word_pair, aes(x = seq, y = med_f0syl2 - med_f0syl1)) +
  geom_boxplot() + theme_minimal() + labs(y = "Median f0 difference (Hz): syl2 vs syl1", x = "Sequence")
mid <- SSf0 + geom_text(data = med_labels_f0, aes(x = seq, y = label_y, label = label), inherit.aes = FALSE, size = 3)

SSint <- ggplot(word_pair, aes(x = seq, y = med_intensitysyl2 - med_intensitysyl1)) +
  geom_boxplot() + theme_minimal() + labs(y = "Median intensity (dB) difference: syl2 - syl1", x = "Sequence")
bot <- SSint + geom_text(data = med_labels_int, aes(x = seq, y = label_y, label = label), inherit.aes = FALSE, size = 3)

plot_grid(top, mid, bot, nrow = 3)


# OPTIONAL: fit LMMs on word-level medians to test whether seq predicts the within-word median difference
# Example: dur difference as outcome

# LMM requires lme4
if(!"lme4" %in% installed.packages()) install.packages("lme4")
library(lme4)
# Random intercept for speaker, if present
m_dur_seq <- lmer(dur_diff ~ seq + (1 | speaker), data = word_pair, REML = FALSE)
summary(m_dur_seq)
anova(m_dur_seq)

m_f0_seq <- lmer(f0_diff ~ seq + (1 | speaker), data = word_pair, REML = FALSE)
summary(m_f0_seq)
anova(m_f0_seq)

m_int_seq <- lmer(int_diff ~ seq + (1 | speaker), data = word_pair, REML = FALSE)
summary(m_int_seq)
anova(m_int_seq)


# Required packages
pkgs <- c("ggplot2","dplyr","rlang")
for (p in pkgs) if (!requireNamespace(p, quietly = TRUE)) install.packages(p)
library(ggplot2); library(dplyr); library(rlang)

# --- Prepare data --------------------------------
# Use your data frame name (replace df below if needed)
# Ensure columns: f0 (numeric), syll_idx or syl_pos, vowel_strength (values 'weak'/'strong')

# Example canonicalization (adapt if your columns differ)
df <- df %>%
  mutate(
    f0 = as.numeric(f0),
    vowel_strength_type = ifelse(is.na(vowel_strength_type), "unknown", as.character(vowel_strength_type)),
    vowel_strength_type = factor(vowel_strength_type, levels = c("Weak","Strong")),
    # syllable index: prefer an existing numeric index; if not, map syl_pos strings
    syll_idx = if ("sidx" %in% names(df)) as.integer(sidx) else case_when(
      tolower(syl_pos) %in% c("initial","1","first") ~ 1L,
      tolower(syl_pos) %in% c("med","2","second") ~ 2L,
      tolower(syl_pos) %in% c("final","3","third","last") ~ 2L, # conservative fallback
      TRUE ~ NA_integer_
    )
  )

# Filter out NA f0
df_f0 <- df %>% filter(!is.na(f0))

# Create grouping variable:
# - "initial_weak": syll_idx == 1 & vowel_strength == "weak"
# - "initial_strong": syll_idx == 1 & vowel_strength == "strong"
# - "non_initial": syll_idx != 1 (any strength)
df_f0 <- df_f0 %>%
  mutate(group = case_when(
    !is.na(syll_idx) & syll_idx == 1 & vowel_strength_type == "Weak" ~ "initial_weak",
    !is.na(syll_idx) & syll_idx == 1 & vowel_strength_type == "Strong" ~ "initial_strong",
    !is.na(syll_idx) & syll_idx != 1 ~ "non_initial",
    TRUE ~ NA_character_
  )) %>%
  filter(!is.na(group)) %>%
  mutate(group = factor(group, levels = c("initial_weak","initial_strong","non_initial"),
                        labels = c("Initial: weak","Initial: strong","Non-initial")))

# Optional: if you prefer to aggregate to one value per syllable (e.g., median f0 per syllable),
# uncomment the following to compute per-word-syllable medians:
# df_f0 <- df_f0 %>%
#   group_by(word, syll_idx, group, speaker) %>%
#   summarise(med_f0 = median(f0, na.rm = TRUE), .groups = "drop") %>%
#   rename(f0 = med_f0)

# --- Compute medians & labels --------------------
medians <- df_f0 %>%
  group_by(group) %>%
  summarise(med_f0 = median(f0, na.rm = TRUE),
            mean_f0 = mean(f0, na.rm = TRUE),
            n = n(), .groups = "drop") %>%
  arrange(factor(group, levels = levels(df_f0$group)))

# Format median label text (Hz)
medians <- medians %>%
  mutate(med_label = paste0("median = ", sprintf("%.1f Hz", med_f0)))

# --- Plot ----------------------------------------
p <- ggplot(df_f0, aes(x = group, y = f0, fill = group)) +
  geom_violin(trim = TRUE, alpha = 0.35, color = "black") +
  geom_boxplot(width = 0.12, outlier.shape = NA, alpha = 0.85) +
  stat_summary(fun = median, geom = "point", size = 2, color = "black") +
  scale_fill_manual(values = c("#66c2a5", "#fc8d62", "#8da0cb")) +
  theme_minimal(base_size = 14) +
  labs(x = "", y = "F0 (Hz)") +
  theme(legend.position = "none")

# Add median labels above each violin
# compute y position slightly above max f0 for each group to place label
y_pos_df <- df_f0 %>%
  group_by(group) %>%
  summarise(ymax = max(f0, na.rm = TRUE), ymin = min(f0, na.rm = TRUE), .groups = "drop") %>%
  left_join(medians, by = "group") %>%
  mutate(label_y = ymax + 0.05 * (ymax - ymin))

p <- p + geom_text(data = y_pos_df, aes(x = group, y = label_y, label = med_label),
                   inherit.aes = FALSE, size = 3.6)

# Optionally add lines connecting medians (visual connector)
p <- p + geom_segment(data = medians,
                      aes(x = 1, xend = 2, y = med_f0[1], yend = med_f0[2]),
                      inherit.aes = FALSE, color = "black", size = 0.6, linetype = "solid") +
  geom_segment(data = medians,
               aes(x = 2, xend = 3, y = med_f0[2], yend = med_f0[3]),
               inherit.aes = FALSE, color = "black", size = 0.6, linetype = "solid")

# Print plot
print(p)

# --- Optional: statistical comparisons (LMM recommended) --------------
# Quick pairwise Wilcoxon (not accounting for clustering) for reference:
pairwise <- df_f0 %>%
  group_by(group) %>%
  summarise(n = n(), .groups = "drop")
pairwise_tests <- combn(levels(df_f0$group), 2, function(x) {
  g1 <- x[1]; g2 <- x[2]
  d1 <- df_f0$f0[df_f0$group == g1]
  d2 <- df_f0$f0[df_f0$group == g2]
  res <- wilcox.test(d1, d2)
  data.frame(g1 = g1, g2 = g2, p = res$p.value, median_diff = median(d2, na.rm = TRUE) - median(d1, na.rm = TRUE))
}, simplify = FALSE) %>% bind_rows()
print(pairwise_tests)

# For valid inference with repeated measures, fit LMMs (example)
# library(lme4); library(lmerTest)
# m <- lmer(f0 ~ group + (1|speaker) + (1|word), data = df_f0, REML = FALSE)
# summary(m)

library(dplyr)

# canonicalize column names (adapt if needed)
df3 <- df %>%
  mutate(
    label = as.character(label),
    vowel_strength = as.character(vowel_strength_type),
    # prefer sidx if present; else try to use syll_idx or syl_pos mapping
    syll_idx = if("sidx" %in% names(.)) as.integer(sidx) else if("syll_idx" %in% names(.)) as.integer(syll_idx) else NA_integer_
  )

# token counts
token_counts <- df3 %>%
  filter(label == "y") %>%
  group_by(syll_idx) %>%
  summarise(tokens = n(), .groups = "drop") %>%
  arrange(syll_idx)

token_counts

# WRITTEN CORPUS

zheltov_corpus <- read.csv("~/GitHub/phonology-chuvash/wordlists/zheltov_corpus.csv")

strong_vowels_regex <- "[аыуеиӳэяюоё]" # Regex to match any strong vowel
weak_vowels_regex <- "[ӑӗ]"           # Regex to match any weak vowel

get_vowel_sequence_R <- function(word_str) {
  if (is.na(word_str) || !is.character(word_str)) {
    return(NA_character_) # Handle NA or non-string inputs
  }
  
  # 1. Extract all vowels
  # We use str_extract_all and unlist to get a vector of all individual vowel characters
  all_vowels <- unlist(str_extract_all(word_str, paste0(strong_vowels_regex, "|", weak_vowels_regex)))
  
  if (length(all_vowels) == 0) {
    return("") # If no vowels found, return an empty string
  }
  
  # 2. Replace strong vowels with 'S' and weak vowels with 'W'
  vowel_sequence_list <- character(length(all_vowels))
  for (i in seq_along(all_vowels)) {
    char <- all_vowels[i]
    if (str_detect(char, strong_vowels_regex)) {
      vowel_sequence_list[i] <- 'S'
    } else if (str_detect(char, weak_vowels_regex)) {
      vowel_sequence_list[i] <- 'W'
    }
  }
  
  # 3. Join them into a single string
  return(paste0(vowel_sequence_list, collapse = ""))
}

zheltov_corpus <- zheltov_corpus %>%
  rowwise() %>% # Process row by row for string operations
  mutate(vowel_sequence = get_vowel_sequence_R(word)) %>%
  ungroup() # Remove rowwise grouping after mutation


strong_vowels <- c("a", "i", "y", "e", "u", "ʉ")
weak_vowels <- c("ø", "ɵ")

zheltov_corpus <- zheltov_corpus %>%
  mutate(
    vowel_strength_type = case_when(
      label %in% strong_vowels ~ "Strong",
      label %in% weak_vowels ~ "Weak",
      TRUE ~ "Other" # Catch any vowels not explicitly classified
    )
  ) %>%
  # Filter out "Other" if you are confident all vowels should be strong/weak
  filter(vowel_strength_type != "Other") %>%
  mutate(
    # FIRST: Convert the numeric 'phon_stress' (0 or 1) into descriptive strings
    phon_stress_description = case_when(
      phon_stress == 0 ~ "Unstressed",
      phon_stress == 1 ~ "Stressed",
      TRUE ~ NA_character_ # In case of unexpected values, though shouldn't happen
    ),
    # SECOND: Convert the new descriptive string column into a factor
    # Now the 'levels' of this factor are directly "Unstressed" and "Stressed"
    phon_stress = factor(phon_stress_description, levels = c("Unstressed", "Stressed")),
    
    # Also convert other columns to factors as before
    syl_open_closed = factor(syl_open_closed, levels = c("open", "closed")),
    vowel_strength_type = factor(vowel_strength_type, levels = c("Strong", "Weak"))
  )

df <- filtered_df

df <- df %>%
  mutate(
    vowel_strength_type = case_when(
      label %in% strong_vowels ~ "Strong",
      label %in% weak_vowels ~ "Weak",
      TRUE ~ "Other" # Catch any vowels not explicitly classified
    )
  ) %>%
  # Filter out "Other" if you are confident all vowels should be strong/weak
  filter(vowel_strength_type != "Other") %>%
  mutate(
    # FIRST: Convert the numeric 'phon_stress' (0 or 1) into descriptive strings
    phon_stress_description = case_when(
      phon_stress == 0 ~ "Unstressed",
      phon_stress == 1 ~ "Stressed",
      TRUE ~ NA_character_ # In case of unexpected values, though shouldn't happen
    ),
    # SECOND: Convert the new descriptive string column into a factor
    # Now the 'levels' of this factor are directly "Unstressed" and "Stressed"
    phon_stress = factor(phon_stress_description, levels = c("Unstressed", "Stressed")),
    
    # Also convert other columns to factors as before
    syl_open_closed = factor(syl_open_closed, levels = c("open", "closed")),
    vowel_strength_type = factor(vowel_strength_type, levels = c("Strong", "Weak"))
  )

token_counts <- zheltov_corpus %>%
  #filter(label == "ʉ") %>% #ʉ
  group_by(phon_stress,syl_open_closed,vowel_strength_type) %>%
  summarise(tokens = n(), .groups = "drop") %>%
  arrange(phon_stress)

token_counts

written_results <- zheltov_corpus %>%
  group_by(phon_stress_description, vowel_strength_type, syl_open_closed) %>%
  summarise(
    count = n(),
    .groups = 'drop' # Drop grouping after summarizing
  ) %>%
  group_by(phon_stress_description, vowel_strength_type) %>%
  mutate(
    percentage = (count / sum(count)) * 100
  )

spoken_results <- df %>%
  group_by(phon_stress_description, vowel_strength_type, syl_open_closed) %>%
  summarise(
    count = n(),
    .groups = 'drop' # Drop grouping after summarizing
  ) %>%
  group_by(phon_stress_description, vowel_strength_type) %>%
  mutate(
    percentage = (count / sum(count)) * 100
  )

# --- 4. Display the results ---
print("Percentage of open vs. closed syllables by stress and vowel strength:")
print(analysis_results)

ggplot(written_results, aes(x = vowel_strength_type, y = percentage, fill = syl_open_closed)) +
  geom_bar(stat = "identity", position = position_dodge(width = 0.8), width = 0.7) +
  facet_wrap(~ phon_stress_description, labeller = label_value) + 
  labs(
    title = "Percentage of Open vs. Closed Syllables by Vowel Strength and Stress",
    x = "Vowel Strength Type",
    y = "Percentage",
    fill = "Syllable Type"
  ) +
  theme_minimal() +
  scale_fill_manual(values = c("open" = "#4CAF50", "closed" = "#FFC107")) + # Custom colors
  geom_text(aes(label = sprintf("%.1f%%", percentage)), 
            position = position_dodge(width = 0.8), 
            vjust = -0.5, size = 3) + # Add percentage labels on bars
  theme(
    plot.title = element_text(hjust = 0.5), # Center title
    legend.position = "bottom" # Move legend to bottom
  )

ggplot(spoken_results, aes(x = vowel_strength_type, y = percentage, fill = syl_open_closed)) +
  geom_bar(stat = "identity", position = position_dodge(width = 0.8), width = 0.7) +
  facet_wrap(~ phon_stress_description, labeller = label_value) + 
  labs(
    title = "Percentage of Open vs. Closed Syllables by Vowel Strength and Stress",
    x = "Vowel Strength Type",
    y = "Percentage",
    fill = "Syllable Type"
  ) +
  theme_minimal() +
  scale_fill_manual(values = c("open" = "#4CAF50", "closed" = "#FFC107")) + # Custom colors
  geom_text(aes(label = sprintf("%.1f%%", percentage)), 
            position = position_dodge(width = 0.8), 
            vjust = -0.5, size = 3) + # Add percentage labels on bars
  theme(
    plot.title = element_text(hjust = 0.5), # Center title
    legend.position = "bottom" # Move legend to bottom
  )


coda_by_vowel_sequence <- zheltov_corpus %>%
  #filter(sN == "3") %>%
  group_by(syl_open_closed,syl_pos,phon_stress) %>%
  summarise(
    count = n(),
    .groups = 'drop' # Drop grouping after summarizing
  ) %>%
  group_by(syl_pos,phon_stress) %>%
  mutate(
    percentage = (count / sum(count)) * 100
  )

ggplot(coda_by_vowel_sequence, aes(x = phon_stress, y = percentage, fill = syl_open_closed)) +
  geom_bar(stat = "identity", position = position_dodge(width = 0.8), width = 0.7) +
  facet_wrap(~ syl_pos, labeller = label_value) + 
  labs(
    title = "Percentage of Open vs. Closed Syllables by Vowel Strength and Stress",
    x = "Vowel Strength Type",
    y = "Percentage",
    fill = "Syllable Type"
  ) +
  theme_minimal() +
  scale_fill_manual(values = c("open" = "#4CAF50", "closed" = "#FFC107")) + # Custom colors
  geom_text(aes(label = sprintf("%.1f%%", percentage)), 
            position = position_dodge(width = 0.8), 
            vjust = -0.5, size = 3) + # Add percentage labels on bars
  theme(
    plot.title = element_text(hjust = 0.5), # Center title
    legend.position = "bottom" # Move legend to bottom
  )

# PLOT stressed vs unstressed vowel means

palatal_segments <- c("J","SH","ɕ","ɕː","tʃ","ʃː")
palatal_pattern <- paste(palatal_segments, collapse = "|")

non_palatal_data <- filtered_df %>%
  mutate(
    pre_is_palatal = str_detect(pre_seg, palatal_pattern),
    context_type = case_when(
      pre_is_palatal ~ "Palatal Context",
      TRUE ~ "Non-Palatal Context"
    )
  ) %>%
  filter(context_type == "Non-Palatal Context") %>%
  select(label, F1, F2,pre_seg,word)

mean_vowel_acoustics <- df %>%
  mutate(
    pre_is_palatal = str_detect(pre_seg, palatal_pattern),
    context_type = case_when(
      pre_is_palatal ~ "Palatal Context",
      TRUE ~ "Non-Palatal Context"
    )
  ) %>%
  filter(context_type == "Non-Palatal Context") %>%
  group_by(label, vowel_strength_type, phon_stress) %>%
  summarise(
    mean_F1 = mean(F1, na.rm = TRUE),
    mean_F2 = mean(F2, na.rm = TRUE),
    .groups = 'drop'
  )

# --- 4. Create the Plot ---
vowel_plot <- ggplot(mean_vowel_acoustics, aes(x = mean_F2, y = mean_F1)) +
  # Connect stressed to unstressed means for each vowel
  geom_line(aes(group = label, color = label),
            arrow = arrow(length = unit(0.2, "cm"), ends = "last", type = "closed"),
            size = 0.8) +
  # Plot points for stressed and unstressed means
  geom_point(aes(shape = phon_stress, color = vowel_strength_type), size = 4) +
  # Add vowel labels, positioned relative to the overall mean of each vowel's points
  geom_text(data = mean_vowel_acoustics %>% group_by(vowel_strength_type) %>%
              summarise(x = mean(mean_F2), y = mean(mean_F1), .groups = 'drop'),
            aes(x = x, y = y, label = vowel_strength_type),
            nudge_y = -30, size = 4, fontface = "bold", color = "black") + # Adjust nudge_y for better placement
  
  # Reverse axes for standard vowel plot orientation
  scale_y_reverse(name = "F1 (Hz)") +
  scale_x_reverse(name = "F2 (Hz)") +
  
  # Customize colors and shapes
  scale_color_brewer(palette = "Paired", name = "Vowel Type") +
  scale_shape_manual(values = c("Stressed" = 19, "Unstressed" = 17), name = "Stress Status") + # Solid circle for stressed, solid triangle for unstressed
  
  # Add a title and theme
  labs(
    title = "Mean F1 and F2 for Stressed vs. Unstressed Chuvash Vowels",
    subtitle = "Lines show shift from stressed (circle) to unstressed (triangle) positions"
  ) +
  theme_minimal(base_size = 14) +
  theme(
    plot.title = element_text(hjust = 0.5, face = "bold"),
    plot.subtitle = element_text(hjust = 0.5),
    legend.position = "right",
    panel.grid.minor = element_blank(),
    panel.border = element_rect(colour = "black", fill=NA, size=1) # Add a border around the plot area
  )

# Print the plot
print(vowel_plot)

vowel_plot_revised <- ggplot(mean_vowel_acoustics, aes(x = mean_F2, y = mean_F1)) +
  # Lines connecting stressed to unstressed means for each vowel, colored by Vowel Strength Type
  geom_line(aes(group = label, color = label),
            arrow = arrow(length = unit(0.2, "cm"), ends = "last", type = "closed"),
            size = 0.8) +
  # Points for stressed and unstressed means, colored by Vowel Strength Type
  geom_point(aes(shape = phon_stress, color = vowel_strength_type), size = 4) +
  
  # Add individual vowel labels for *each* point (stressed and unstressed)
  # Nudge positions are adjusted to prevent overlap and make labels readable.
  geom_text(aes(label = label),
            nudge_x = ifelse(mean_vowel_acoustics$phon_stress == "Stressed", 50, -50),
            nudge_y = ifelse(mean_vowel_acoustics$phon_stress == "Stressed", 30, -30),
            size = 3.5, fontface = "bold", color = "black") + # Adjust size and style as needed
  
  # Reverse axes for standard vowel plot orientation
  scale_y_reverse(name = "F1 (Hz)") +
  scale_x_reverse(name = "F2 (Hz)") +
  
  # Customize colors for Vowel Strength Type (using light/dark blue as in your plot)
  scale_color_manual(values = c("Strong" = "#A6CEE3", "Weak" = "#1F78B4"), name = "Vowel Strength Type") +
  # Customize shapes for Stress Status
  scale_shape_manual(values = c("Stressed" = 19, "Unstressed" = 17), name = "Stress Status") + # Solid circle for stressed, solid triangle for unstressed
  
  # Add a title and theme
  labs(
    title = "Mean F1 and F2 for Stressed vs. Unstressed Chuvash Vowels",
    subtitle = "Arrows show shift from stressed (circle) to unstressed (triangle) positions"
  ) +
  theme_minimal(base_size = 14) +
  theme(
    plot.title = element_text(hjust = 0.5, face = "bold"),
    plot.subtitle = element_text(hjust = 0.5),
    legend.position = "right",
    panel.grid.minor = element_blank(),
    panel.border = element_rect(colour = "black", fill=NA, size=1) # Add a border around the plot area
  )

# Print the revised plot
print(vowel_plot_revised)


library(tidyverse)

# 1. Load your data (assuming it's in a csv called 'f0_data.csv')
df <- read.csv("~/GitHub/phonology-chuvash/contour-clustering/output.csv")

# 2. Split the interval_label into 5 separate columns
df_clean <- df %>%
  # Split the label into 5 parts
  separate(interval_label, 
           into = c("vowel", "syll_num", "vowel_cat", "word_cat", "token_cat"), 
           sep = ";", 
           fill = "right") %>%
  # FORCE f0 to be numeric (fixes the NA issue)
  mutate(f0 = as.numeric(as.character(f0))) %>%
  # Remove rows where f0 is missing or 0 (common in pitch tracking)
  filter(!is.na(f0), f0 > 0)

# 3. Calculate summary stats
df_summary <- df_clean %>%
  dplyr::group_by(token_cat, stepnumber) %>% 
  dplyr::summarise(
    mean_f0 = mean(f0, na.rm = TRUE),
    sd_f0 = sd(f0, na.rm = TRUE),
    n = n(),
    .groups = "drop"
  ) %>%
  group_by(token_cat) %>%
  mutate(facet_label = paste0(token_cat, " (n = ", max(n), ")")) %>%
  ungroup()

# NEW: Calculate the Delta (Difference) for each facet
df_delta <- df_summary %>%
  filter(stepnumber %in% c(1, 20)) %>%
  select(facet_label, stepnumber, mean_f0) %>%
  pivot_wider(names_from = stepnumber, names_prefix = "step", values_from = mean_f0) %>%
  mutate(diff_hz = round(step20 - step1, 1),
         label_text = paste0("Δ: ", diff_hz, " Hz"))

# NEW: Calculate the Grand Totals
total_n <- sum(df_summary$n) / 20 
total_dyad <- total_n / 2

# 4. Plotting
ggplot(df_summary, aes(x = stepnumber, y = mean_f0)) +
  geom_ribbon(aes(ymin = mean_f0 - sd_f0, ymax = mean_f0 + sd_f0), 
              fill = "gray80", alpha = 0.5) +
  geom_line(color = "blue", size = 1) +
  # ADD THE DELTA LABEL
  geom_label(data = df_delta, 
             aes(x = 10, y = Inf, label = label_text), 
             vjust = 1.5, size = 3.5, label.size = 0.25) +
  facet_wrap(~facet_label) + 
  theme_minimal() +
  labs(
    title = paste0("Mean F0 Contour (N = ", total_n, " vowels / ", total_dyad, " dyads)"),
    subtitle = "Delta (Δ) shows mean Hz change from Step 1 to Step 20",
    x = "Normalized Time (Step Number)",
    y = "F0 (Hz)"
  )
