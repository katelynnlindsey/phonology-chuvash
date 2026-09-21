# ==============================================================================
# SECTION 1: SETUP & LIBRARIES
# ==============================================================================
# Load all required libraries once at the top
pacman::p_load(
  tidyverse, scales, rcompanion, gmodels, vowels, graphics,
  ggplot2, ggpubr, phonR, hrbrthemes, viridis, forcats,
  patchwork, partykit, lme4, lmerTest, rstatix, cowplot, emmeans
)

# --- GLOBAL CONSTANTS ---
# Vowel Definitions
VOWEL_LABELS_ARPABET <- c('AA', 'AH', 'EH', 'EY', 'IX', 'IY', 'UX', 'UW')
STRONG_VOWELS <- c("a", "i", "y", "e", "u", "ʉ")
WEAK_VOWELS   <- c("ø", "ɵ")

# Russian Loanword Filter Patterns
RUSSIAN_LATIN_SEQS <- c('ZH','ts','B','G','D','F','Z','O','Б','Г','Д','О','Ж','Ц','Ф','З','Ë','ё','Ё')
RUSSIAN_PATTERN    <- paste(sapply(RUSSIAN_LATIN_SEQS, stringr::fixed), collapse = "|")

# Palatal Contexts
PALATAL_SEGMENTS <- c("J","SH","ɕ","ɕː","tʃ","ʃː")
PALATAL_PATTERN  <- paste(PALATAL_SEGMENTS, collapse = "|")


# ==============================================================================
# SECTION 2: DATA LOADING & CLEANING FUNCTIONS
# ==============================================================================

# Helper function to remove outliers using IQR
remove_outliers <- function(df, cols) {
  for (col in cols) {
    df <- df %>%
      group_by(label, phon_stress) %>%
      mutate(
        Q1 = quantile(!!sym(col), 0.25, na.rm = TRUE),
        Q3 = quantile(!!sym(col), 0.75, na.rm = TRUE),
        lower = Q1 - 1.5 * (Q3 - Q1),
        upper = Q3 + 1.5 * (Q3 - Q1)
      ) %>%
      filter(!!sym(col) >= lower & !!sym(col) <= upper) %>%
      ungroup() %>%
      select(-Q1, -Q3, -lower, -upper)
  }
  return(df)
}

# 1. Load Data
raw_data <- read.csv("~/GitHub/phonology-chuvash/extract/all_chuvash_vowel_points.csv", encoding="UTF-8")

# 2. Main Cleaning Pipeline
df_clean <- raw_data %>%
  # Fix Duration units (s -> ms)
  mutate(dur = dur * 1000) %>%
  
  # Filter only valid vowels
  filter(label %in% VOWEL_LABELS_ARPABET) %>%
  
  # Standardize Vowel Labels (ARPABET -> IPAish)
  mutate(label = stringr::str_replace_all(label, c(
    "AA"="a", "IY"="i", "UX"="y", "EY"="e", 
    "EH"="ø", "IX"="ʉ", "UW"="u", "AH"="ɵ"
  ))) %>%
  
  # Filter Russian Loanwords
  filter(!stringr::str_detect(stringr::str_to_upper(word), RUSSIAN_PATTERN)) %>%
  
  # Define Vowel Strength & Stress Factors
  mutate(
    vowel_strength_type = case_when(
      label %in% STRONG_VOWELS ~ "Strong",
      label %in% WEAK_VOWELS   ~ "Weak",
      TRUE ~ NA_character_
    ),
    vowel_strength_type = factor(vowel_strength_type, levels = c("Weak", "Strong")),
    
    # Clean Stress Labels
    phon_stress = as.character(trimws(phon_stress)),
    stress_cat = case_when(
      phon_stress == "1" ~ "Stressed",
      phon_stress == "0" ~ "Unstressed",
      TRUE ~ phon_stress
    ),
    stress_cat = factor(stress_cat, levels = c("Unstressed", "Stressed")),
    
    # Syllable Position / Context
    context_type = ifelse(str_detect(pre_seg, PALATAL_PATTERN), "Palatal", "Non-Palatal")
  ) %>%
  filter(!is.na(vowel_strength_type))

# 3. Apply Outlier Removal
df_final <- remove_outliers(df_clean, c('F1', 'F2', 'dur', 'intensity', 'f0'))

cat("Data Cleaning Complete.\n",
    "Original Rows:", nrow(raw_data), "\n",
    "Cleaned Rows: ", nrow(df_final), "\n")


# ==============================================================================
# SECTION 3: ACOUSTIC PLOTS (Violin & Formants)
# ==============================================================================

# --- A. Stacked Violin Plots (Dur, F0, Intensity) ---
plot_metrics <- df_final %>%
  filter(phon_stress == "0", syl_pos == "med") %>%
  select(label, vowel_strength_type, dur, f0, intensity) %>%
  pivot_longer(cols = c(dur, f0, intensity), names_to = "metric", values_to = "value") %>%
  mutate(
    metric_label = case_when(
      metric == "dur" ~ "Duration (ms)",
      metric == "f0" ~ "f0 (Hz)",
      metric == "intensity" ~ "Intensity (dB)"
    )
  )

# Function to generate individual metric plots
create_violin <- function(data, metric_name, fill_colors) {
  # Sort labels by mean value
  order <- data %>% 
    filter(metric == metric_name) %>% 
    group_by(label) %>% 
    summarise(m = mean(value, na.rm=TRUE)) %>% 
    arrange(m) %>% pull(label)
  
  ggplot(data %>% filter(metric == metric_name), 
         aes(x = factor(label, levels=order), y = value, fill = vowel_strength_type)) +
    geom_violin(trim = TRUE, scale = "width") +
    geom_boxplot(width = 0.15, fill = "white", alpha = 0.6, outlier.shape = NA) +
    scale_fill_manual(values = fill_colors) +
    labs(y = unique(data$metric_label[data$metric == metric_name]), x = NULL) +
    theme_minimal() +
    theme(legend.position = "none", axis.text.x = element_text(face="bold"))
}

colors <- c("Weak" = "#FD8D3C", "Strong" = "#9ECAE1")
p1 <- create_violin(plot_metrics, "dur", colors)
p2 <- create_violin(plot_metrics, "f0", colors)
p3 <- create_violin(plot_metrics, "intensity", colors)

combined_plot <- (p1 / p2 / p3) + plot_annotation(title = "Acoustic Properties of Medial Unstressed Vowels")
print(combined_plot)
# ggsave("chuvash_vowels.pdf", combined_plot, width = 8.5, height = 10, device = cairo_pdf)


# --- B. Vowel Space Plot (F1 vs F2) ---
# Calculate Means
vowel_means <- df_final %>%
  filter(context_type == "Non-Palatal") %>%
  group_by(label, stress_cat, vowel_strength_type) %>%
  summarise(F1 = mean(F1), F2 = mean(F2), .groups = "drop")

ggplot(vowel_means, aes(x = F2, y = F1)) +
  # Arrows connecting Stressed -> Unstressed
  geom_line(aes(group = label, color = vowel_strength_type),
            arrow = arrow(length = unit(0.2, "cm"), ends = "last", type = "closed"),
            linewidth = 0.8) +
  # Points
  geom_point(aes(shape = stress_cat, color = vowel_strength_type), size = 4) +
  # Labels
  geom_text(aes(label = label), 
            nudge_x = ifelse(vowel_means$stress_cat == "Stressed", 50, -50),
            nudge_y = ifelse(vowel_means$stress_cat == "Stressed", 30, -30),
            fontface = "bold") +
  scale_y_reverse() + scale_x_reverse() +
  scale_color_manual(values = c("Strong" = "#A6CEE3", "Weak" = "#1F78B4")) +
  theme_minimal() +
  labs(title = "Vowel Space Shift: Stressed to Unstressed", x = "F2 (Hz)", y = "F1 (Hz)")

quality_means <- df_final %>%
  filter(context_type == "Non-Palatal")

with(quality_means, plotVowels(F1, F2, label, plot.tokens = FALSE, pch.tokens = label, 
                                  cex.tokens = 1.2, alpha.tokens = 0.2, plot.means = TRUE, pch.means = label, 
                                  cex.means = 2, var.col.by = label, family = "Charis SIL", pretty = TRUE, 
                                  ellipse.line=TRUE, xlim = c(3200, 600), ylim = c(1000, 200), xlab="F2 (Hz.)", ylab="F1 (Hz.)"))

# ==============================================================================
# SECTION 3: DETAILED STRESS COMPARISONS (MEDIAN DIFF PLOTS)
# ==============================================================================

# 1. Define the Custom Plotting Function (with Median Difference Annotation)
plot_metric_with_meddiff <- function(data, metric, title = NULL, 
                                     palette = c("#66c2a5","#fc8d62"),
                                     label_fmt = function(x) sprintf("%.3f", x)) {
  
  # Dynamic conversion of string to symbol for ggplot
  metric_sym <- rlang::sym(metric)
  
  # Filter Data
  data2 <- data %>% filter(!is.na(!!metric_sym), !is.na(stress_cat))
  
  # Safety check
  if(nrow(data2) < 2) return(ggplot() + labs(title = "Not enough data") + theme_void())
  
  # Compute Medians
  med_df <- data2 %>%
    group_by(stress_cat) %>%
    summarise(med = median(!!metric_sym, na.rm = TRUE), .groups = "drop")
  
  # Extract values (Ensure strict order: Unstressed first, Stressed second)
  med_un <- med_df$med[med_df$stress_cat == "Unstressed"]
  med_st <- med_df$med[med_df$stress_cat == "Stressed"]
  
  if(length(med_un) == 0 || length(med_st) == 0) return(ggplot() + labs(title = "Missing Factor Level") + theme_void())
  
  # Calculate Difference and Y-positions for the annotation bracket
  med_diff <- med_st - med_un
  ymax <- max(data2[[metric]], na.rm = TRUE)
  ymin <- min(data2[[metric]], na.rm = TRUE)
  range_y <- ymax - ymin
  
  y_connector <- max(med_un, med_st) + 0.10 * range_y
  y_label     <- y_connector + 0.05 * range_y
  
  # Generate Plot
  ggplot(data2, aes(x = stress_cat, y = !!metric_sym, fill = stress_cat)) +
    geom_violin(trim = TRUE, alpha = 0.35, color = "black") +
    geom_boxplot(width = 0.12, outlier.shape = NA, alpha = 0.8) +
    stat_summary(fun = median, geom = "point", size = 2, color = "black") +
    scale_fill_manual(values = palette) +
    labs(title = title, y = metric, x = NULL) + # x label removed for cleanliness in grid
    theme_minimal(base_size = 11) +
    theme(legend.position = "none", plot.title = element_text(size = 10, face = "bold")) +
    
    # Draw Bracket (Unstressed=1, Stressed=2 on x-axis)
    geom_segment(aes(x = 1, xend = 2, y = med_un, yend = med_st), color = "black", linewidth = 0.5) +
    
    # Annotation Label
    annotate("text", x = 1.5, y = y_label, 
             label = paste0("Δ median = ", label_fmt(med_diff)), 
             vjust = 0, size = 3, fontface = "italic")
}

# 2. Create Specific Subsets based on your requirements
# Note: Uses 'df_final' from Section 2

# A. Initial Position + Weak Vowels
subset_initial_weak <- df_final %>% 
  filter(syl_pos == "initial", vowel_strength_type == "Weak")

# B. Words with ONLY Weak Vowels
words_weak_only_list <- df_final %>%
  group_by(word) %>%
  summarise(all_weak = all(vowel_strength_type == "Weak"), .groups = "drop") %>%
  filter(all_weak) %>%
  pull(word)

subset_only_weak_words <- df_final %>% 
  filter(word %in% words_weak_only_list, vowel_strength_type == "Weak")

# C. All Strong Vowels
subset_strong <- df_final %>% 
  filter(vowel_strength_type == "Strong")


# 3. Generate the 3x3 Grid of Plots

# --- Row 1: Duration ---
p1 <- plot_metric_with_meddiff(subset_initial_weak, "dur", "Initial Weak: Duration")
p2 <- plot_metric_with_meddiff(subset_only_weak_words, "dur", "Only-Weak Words: Duration")
p3 <- plot_metric_with_meddiff(subset_strong, "dur", "Strong Vowels: Duration")

# --- Row 2: F0 ---
p4 <- plot_metric_with_meddiff(subset_initial_weak, "f0", "Initial Weak: F0")
p5 <- plot_metric_with_meddiff(subset_only_weak_words, "f0", "Only-Weak Words: F0")
p6 <- plot_metric_with_meddiff(subset_strong, "f0", "Strong Vowels: F0")

# --- Row 3: Intensity ---
p7 <- plot_metric_with_meddiff(subset_initial_weak, "intensity", "Initial Weak: Intensity")
p8 <- plot_metric_with_meddiff(subset_only_weak_words, "intensity", "Only-Weak Words: Intensity")
p9 <- plot_metric_with_meddiff(subset_strong, "intensity", "Strong Vowels: Intensity")

# Combine using cowplot
stress_grid <- plot_grid(
  p1, p2, p3,
  p4, p5, p6,
  p7, p8, p9,
  nrow = 3, 
  labels = c("A", "", "", "B", "", "", "C", "", ""),
  rel_heights = c(1, 1, 1)
)

print(stress_grid)
# ggsave("stress_comparison_grid.png", stress_grid, width = 10, height = 8, bg = "white")


# ==============================================================================
# SECTION 4: SEQUENCE ANALYSIS (WW, WS, SW, SS)
# ==============================================================================

# 1. Prepare Data: Identify 2-Syllable Words & Calculate Medians
# Note: Uses 'df_final' from Section 2

# Filter for 2-syllable words only
df_seq_base <- df_final %>%
  filter(sN == 2) %>%
  # Create simple integer index if not present (assuming 'syl_pos' or 'sidx' exists)
  mutate(syll_idx = case_when(
    "sidx" %in% names(.) ~ as.integer(sidx),
    tolower(syl_pos) %in% c("initial","onset","1","first") ~ 1L,
    tolower(syl_pos) %in% c("final","last","2","second") ~ 2L,
    TRUE ~ NA_integer_
  )) %>%
  filter(!is.na(syll_idx))

# Calculate Medians per Syllable (Collapse multiple tokens)
word_syll_meds <- df_seq_base %>%
  group_by(word, speaker_num, syll_idx) %>%
  summarise(
    strength = first(vowel_strength_type), # Assumes strength constant per syllable slot
    med_dur = median(dur, na.rm = TRUE),
    med_f0  = median(f0, na.rm = TRUE),
    med_int = median(intensity, na.rm = TRUE),
    .groups = "drop"
  )

# Pivot Wider to get Syl1 vs Syl2 columns
word_pair <- word_syll_meds %>%
  pivot_wider(
    names_from = syll_idx,
    values_from = c(strength, med_dur, med_f0, med_int),
    names_sep = ""
  ) %>%
  # Filter for complete pairs
  filter(!is.na(strength1), !is.na(strength2)) %>%
  # Create Sequence Label (e.g., "WS", "SS")
  mutate(
    seq = paste0(substr(strength1,1,1), substr(strength2,1,1)), # "W" or "S"
    seq = toupper(seq)
  ) %>%
  filter(seq %in% c("WW", "WS", "SW", "SS"))

# 2. Calculate Differences (Syl2 - Syl1)
word_pair_diffs <- word_pair %>%
  mutate(
    diff_dur = med_dur2 - med_dur1,
    diff_f0  = med_f02 - med_f01,
    diff_int = med_int2 - med_int1
  )

# 3. Generate Summary Labels for Plotting
# Helper function to create median labels positioned above the data
create_labels <- function(data, col_name, suffix) {
  data %>%
    group_by(seq) %>%
    summarise(
      med_val = median(.data[[col_name]], na.rm = TRUE),
      ymax = max(.data[[col_name]], na.rm = TRUE),
      ymin = min(.data[[col_name]], na.rm = TRUE),
      .groups = "drop"
    ) %>%
    mutate(
      label_y = ymax + 0.1 * (ymax - ymin), # Position 10% above max
      label_txt = sprintf("%.1f %s", med_val, suffix)
    )
}

lbl_dur <- create_labels(word_pair_diffs, "diff_dur", "ms")
lbl_f0  <- create_labels(word_pair_diffs, "diff_f0", "Hz")
lbl_int <- create_labels(word_pair_diffs, "diff_int", "dB")

# 4. Plotting: Boxplots of Differences by Sequence Type

# Helper for consistent plotting
plot_seq_diff <- function(data, y_col, lbl_data, title, y_lab) {
  ggplot(data, aes(x = seq, y = .data[[y_col]], fill = seq)) +
    geom_boxplot(alpha = 0.6, outlier.shape = 1, outlier.alpha = 0.3) +
    geom_hline(yintercept = 0, linetype = "dashed", color = "gray50") + # Reference line at 0
    geom_text(data = lbl_data, aes(y = label_y, label = label_txt), 
              vjust = 0, fontface = "bold", size = 3.5) +
    scale_fill_brewer(palette = "Pastel1") +
    theme_minimal() +
    labs(title = title, x = NULL, y = y_lab) +
    theme(legend.position = "none", plot.title = element_text(size = 11, face="bold"))
}

# Generate plots
p_seq_dur <- plot_seq_diff(word_pair_diffs, "diff_dur", lbl_dur, 
                           "Duration Difference (S2 - S1)", "Δ Duration (ms)")

p_seq_f0  <- plot_seq_diff(word_pair_diffs, "diff_f0", lbl_f0, 
                           "F0 Difference (S2 - S1)", "Δ F0 (Hz)")

p_seq_int <- plot_seq_diff(word_pair_diffs, "diff_int", lbl_int, 
                           "Intensity Difference (S2 - S1)", "Δ Intensity (dB)")

# Combine into vertical stack
seq_grid <- plot_grid(p_seq_dur, p_seq_f0, p_seq_int, nrow = 3, align = "v")
print(seq_grid)
# ggsave("sequence_differences.png", seq_grid, width = 6, height = 10, bg="white")

# ==============================================================================
# SECTION 5: POSITIONAL F0 ANALYSIS (Initial vs. Non-Initial)
# ==============================================================================

# 1. Prepare Data for Grouping
# Uses df_final from Section 2
df_pos_f0 <- df_final %>%
  filter(!is.na(f0)) %>%
  # Ensure we have a numeric syllable index
  mutate(
    syll_idx = case_when(
      "sN" %in% names(.) ~ as.numeric(sN),
      "sidx" %in% names(.) ~ as.integer(sidx),
      # Fallback string matching
      tolower(syl_pos) %in% c("initial", "1", "first") ~ 1L,
      tolower(syl_pos) %in% c("med", "2", "second") ~ 2L,
      tolower(syl_pos) %in% c("final", "3", "last") ~ 3L,
      TRUE ~ NA_integer_
    )
  ) %>%
  # Create the 3 specific comparison groups
  mutate(group = case_when(
    syll_idx == 1 & vowel_strength_type == "Weak"   ~ "Initial: Weak",
    syll_idx == 1 & vowel_strength_type == "Strong" ~ "Initial: Strong",
    syll_idx > 1                                    ~ "Non-Initial",
    TRUE ~ NA_character_
  )) %>%
  filter(!is.na(group)) %>%
  # Set factor levels to control the order on the X-axis
  mutate(group = factor(group, levels = c("Initial: Weak", "Initial: Strong", "Non-Initial")))

# 2. Compute Medians for Plotting
pos_medians <- df_pos_f0 %>%
  group_by(group) %>%
  summarise(
    med_f0 = median(f0, na.rm = TRUE),
    ymax = max(f0, na.rm = TRUE),
    ymin = min(f0, na.rm = TRUE),
    n = n(),
    .groups = "drop"
  ) %>%
  mutate(
    label_txt = sprintf("%.1f Hz", med_f0),
    label_y = ymax + 0.05 * (ymax - ymin) # Position label slightly above max
  ) %>%
  arrange(group) # Critical: Sort by factor level so connector lines draw correctly

# 3. Plotting
# Define specific colors from your snippet
pos_colors <- c("Initial: Weak" = "#66c2a5", "Initial: Strong" = "#fc8d62", "Non-Initial" = "#8da0cb")

vb <- ggplot(df_pos_f0, aes(x = group, y = f0, fill = group)) +
  # Violin & Boxplot
  geom_violin(trim = TRUE, alpha = 0.35, color = "black") +
  geom_boxplot(width = 0.12, outlier.shape = NA, alpha = 0.85) +
  stat_summary(fun = median, geom = "point", size = 2, color = "black") +
  
  # Connect Medians with lines (Visualizing the trend)
  # Segment 1: Initial Weak -> Initial Strong
  geom_segment(aes(x = 1, xend = 2, 
                   y = pos_medians$med_f0[1], yend = pos_medians$med_f0[2]), 
               inherit.aes = FALSE, color = "black", linewidth = 0.6) +
  # Segment 2: Initial Strong -> Non-Initial
  geom_segment(aes(x = 2, xend = 3, 
                   y = pos_medians$med_f0[2], yend = pos_medians$med_f0[3]), 
               inherit.aes = FALSE, color = "black", linewidth = 0.6) +
  
  # Add Text Labels
  geom_text(data = pos_medians, aes(x = group, y = label_y, label = label_txt),
            inherit.aes = FALSE, size = 3.5, fontface = "bold") +
  
  # Formatting
  scale_fill_manual(values = pos_colors) +
  theme_minimal(base_size = 14) +
  theme(legend.position = "none") +
  labs(title = "F0 Distribution by Position & Strength",
       subtitle = "Lines connect median values",
       x = NULL, y = "F0 (Hz)")

print(vb)

# ==============================================================================
# SECTION 5: CORPUS COMPARISON (Written vs Spoken)
# ==============================================================================

# 1. Load Written Corpus
zheltov <- read.csv("~/GitHub/phonology-chuvash/wordlists/zheltov_corpus.csv") %>%
  mutate(
    vowel_strength_type = case_when(
      label %in% STRONG_VOWELS ~ "Strong",
      label %in% WEAK_VOWELS   ~ "Weak",
      TRUE ~ "Other"
    ),
    stress_cat = ifelse(phon_stress == 1, "Stressed", "Unstressed")
  ) %>%
  filter(vowel_strength_type %in% c("Strong", "Weak"))

# 2. Compare Syllable Structure (Open/Closed)
calc_pct <- function(df) {
  df %>%
    group_by(stress_cat, vowel_strength_type, syl_open_closed) %>%
    summarise(count = n(), .groups = "drop") %>%
    group_by(stress_cat, vowel_strength_type) %>%
    mutate(pct = count / sum(count))
}

written_stats <- calc_pct(zheltov) %>% mutate(Source = "Written")
spoken_stats  <- calc_pct(df_final) %>% mutate(Source = "Spoken")

# Combine and Plot
all_stats <- bind_rows(written_stats, spoken_stats)

ggplot(all_stats, aes(x = vowel_strength_type, y = pct, fill = syl_open_closed)) +
  geom_bar(stat = "identity", position = position_dodge()) +
  facet_grid(Source ~ stress_cat) +
  geom_text(aes(label = scales::percent(pct, accuracy = 1)), 
            position = position_dodge(0.9), vjust = -0.2, size = 3) +
  scale_fill_manual(values = c("open" = "#4CAF50", "closed" = "#FFC107")) +
  theme_minimal() +
  labs(title = "Open vs Closed Syllables: Written vs Spoken Corpus", y = "Percentage")

