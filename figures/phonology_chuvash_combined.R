pacman::p_load(
  tidyverse, scales, rcompanion, gmodels, vowels, graphics,
  ggplot2, ggpubr, phonR, hrbrthemes, viridis, forcats,
  patchwork, partykit, lme4, lmerTest, rstatix, cowplot,
  emmeans, ggh4x, arrow, purrr, stringr
)

# --- 1. GLOBAL SETTINGS & FUNCTIONS ---
VOWEL_LABELS_ARPABET <- c('AA', 'AH', 'EH', 'EY', 'IX', 'IY', 'UX', 'UW')
STRONG_VOWELS <- c("a", "i", "y", "e", "u", "ʉ")
WEAK_VOWELS   <- c("ø", "ɵ")

# Russian Loanword Filter Patterns
RUSSIAN_LATIN_SEQS <- c('ZH','ts','B','G','D','F','Z','O','Б','Г','Д','О','Ж','Ц','Ф','З','Ë','ё','Ё')
RUSSIAN_PATTERN    <- paste(sapply(RUSSIAN_LATIN_SEQS, stringr::fixed), collapse = "|")

# Palatal Contexts
PALATAL_SEGMENTS <- c("J","SH","ɕ","ɕː","tʃ","ʃː")
PALATAL_PATTERN  <- paste(PALATAL_SEGMENTS, collapse = "|")

# Helper function to remove outliers using IQR
remove_outliers <- function(df, cols) {
  for (col in cols) {
    df <- df %>%
      group_by(label, phon_stress) %>%
      mutate(
        Q1 = quantile(!!sym(col), 0.25, na.rm = TRUE),
        Q3 = quantile(!!sym(col), 0.75, na.rm = TRUE),
        IQR_val = Q3 - Q1,
        lower = Q1 - 1.5 * IQR_val,
        upper = Q3 + 1.5 * IQR_val
      ) %>%
      filter(!!sym(col) >= lower & !!sym(col) <= upper) %>%
      ungroup() %>%
      select(-Q1, -Q3, -IQR_val, -lower, -upper)
  }
  return(df)
}

# --- 2. LOAD & PROCESS ACOUSTIC DATA ---

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


only_vowels <- raw_data %>%
  filter(label %in% VOWEL_LABELS_ARPABET)

russian_loans <- only_vowels %>%
  filter(stringr::str_detect(stringr::str_to_upper(word), RUSSIAN_PATTERN))

# 3. Apply Outlier Removal
#df_final <- remove_outliers(df_clean, c('F1', 'F2', 'dur', 'intensity', 'f0'))

df_final <- df_clean %>%
  mutate(sidx = as.integer(sidx), sN = as.integer(sN))

# Load MFA data and pivot wide immediately
cluster_mfa <- read.csv("~/GitHub/phonology-chuvash/contour-clustering/output-mfa.csv")
cluster_vox <- read.csv("~/GitHub/phonology-chuvash/contour-clustering/output-vox.csv")
cluster_data <- bind_rows(cluster_mfa, cluster_vox)

combined_wide <- cluster_data %>%
  pivot_wider(
    id_cols = c(filename, interval_label, start, end, duration,
                jumpkilleffect, vowel_index, vowel_total,
                vowel_category, word_category, word_label),
    names_from  = stepnumber,
    values_from = c(f0, intensity),
    names_glue  = "{.value}_step{stepnumber}"
  ) %>%
  mutate(interval_label = stringr::str_replace_all(interval_label, c(
    "ɑ"="a", "IY"="i", "UX"="y", "EY"="e", 
    "ɛ"="ø", "ɯ"="ʉ", "UW"="u", "ʌ"="ɵ"
  )))

combined <- df_final %>%
  left_join(
    combined_wide,
    by = c(
      "file_name" = "filename",
      "sidx"      = "vowel_index",
      "sN"        = "vowel_total",
      "label"     = "interval_label"
    ),
    relationship = "many-to-many"
  ) %>%
  group_by(file_name, sidx, sN, label, time) %>%
  # prefer rows where time falls within [start, end], else take closest
  mutate(within_interval = time >= start & time <= end) %>%
  arrange(desc(within_interval), abs(time - start)) %>%
  slice(1) %>%
  ungroup() %>%
  select(-within_interval)

# --- 3. LOAD & PROCESS METADATA ---

# Load TSV (Social metadata)
df_raw_soc_vox <- read.delim("~/GitHub/phonology-chuvash/corpora/textgrids_commonvoice/cv_xpf_spkr17.tsv") %>%
  mutate(filename = str_sub(path, 1, -5))

# Load Parquet files (HuggingFace metadata)
parquet_files <- c(
  "C:/Users/profk/Downloads/train-00000-of-00003.parquet",
  "C:/Users/profk/Downloads/train-00001-of-00003.parquet",
  "C:/Users/profk/Downloads/train-00002-of-00003.parquet"
)

cv_metadata <- map_dfr(parquet_files, read_parquet) %>%
  mutate(
    filename = sprintf("utterance_%06d", row_number() - 1),
    speaker_id = na_if(as.character(client_id), "0"),
    gender = if_else(speaker_id == "177", "male_masculine", NA_character_)
  )

# --- 4. FINAL JOINS & CLEANUP ---

combined_final <- combined %>%
  left_join(df_raw_soc_vox, by = c("file_name" = "filename")) %>%
  left_join(cv_metadata, by = c("file_name" = "filename")) %>%
  # Consolidate duplicate columns and remove unwanted ones in one step
  mutate(
    sentence = coalesce(sentence.x, sentence.y),
    speaker_id = coalesce(as.character(speaker_id.x), as.character(speaker_id.y)),
    gender = coalesce(gender.x, gender.y),
    duration = as.numeric(duration)
  ) %>%
  select(
    -ends_with(".x"), 
    -ends_with(".y"),
    -group,
    -audio,
    -accents,
    -variant,
    -sentence_id,
    -sentence_domain,
    -up_votes,
    -down_votes,
    -segment,
    -speaker_num,
    -B1,
    -B2,
    -B3,
    -max_formant,
    -smooth_error,
    -rel_time,
    -prop_time,
    -id,
    -point_heuristic,
    -optimized,
    -jumpkilleffect
    )

intensity_cols <- paste0("intensity_step", 1:20)

combined_final <- combined_final %>%
  mutate(
    total_intensity = rowSums(across(all_of(intensity_cols)), na.rm = TRUE),
    peak_intensity = do.call(pmax, c(across(all_of(intensity_cols)), list(na.rm = TRUE)))
  ) %>%
  select(-all_of(intensity_cols)) %>%
  rename(median_intensity = intensity)

sentence_bounds <- combined_final %>%
  group_by(file_name) %>%
  summarise(sent_start = min(start), sent_end = max(end), .groups = "drop")

combined_final <- combined_final %>%
  left_join(sentence_bounds, by = "file_name") %>%
  mutate(
    word_prop = (start - sent_start) / pmax(0.001, (sent_end - sent_start)),
    
    # 1. Clean the sentence
    clean_sentence = sentence %>%
      str_to_lower() %>%
      str_replace_all("\\\\[nrt]", " ") %>% 
      str_replace_all("[\n\r\t]", " ") %>%
      str_replace_all("[—–]", " ") %>%
      str_replace_all("[^[:alnum:][:space:]-]", " ") %>% 
      str_squish(),
    
    # 2. Clean the label (keep hyphens)
    clean_label = word_label %>%
      str_to_lower() %>%
      str_remove_all("[^[:alnum:][:space:]-]"),
    
    sentence_words = str_split(clean_sentence, "\\s+"),
    wN = map_int(sentence_words, length),
    
    # 3. Matcher
    widx = pmap_int(
      list(sentence_words, clean_label, word_prop),
      function(words, label, prop) {
        # A. Exact Match
        positions <- which(words == label)
        
        # B. Hyphenated Sub-match (e.g., label 'пулна' in 'пулна-мӗн')
        if (length(positions) == 0) {
          positions <- which(str_detect(words, paste0("(^|-)", fixed(label), "(-|$)")))
        }
        
        # C. Handle "n" artifact (e.g., 'nҫывӑх' -> 'ҫывӑх')
        if (length(positions) == 0 && str_starts(label, "n")) {
          short_label <- substring(label, 2)
          positions <- which(words == short_label)
        }
        
        if (length(positions) == 0) return(NA_integer_)
        if (length(positions) == 1) return(positions[1])
        
        # Resolve ties with temporal proximity
        if (length(words) <= 1) return(positions[1])
        prop_positions <- (positions - 1) / (length(words) - 1)
        positions[which.min(abs(prop_positions - prop))]
      }
    ),
    
    phrase_position = case_when(
      widx == 1  ~ "initial",
      widx == wN ~ "final",
      is.na(widx) ~ NA_character_,
      TRUE       ~ "medial"
    )
  ) %>%
  select(-sentence_words, -clean_sentence, -clean_label, -sent_start, -sent_end, -word_prop)

clean_word_ids <- combined_final %>%
  mutate(word_id_new = paste(file_name, widx, sN, sep = "_")) %>%
  select(word_id_new, word_category) %>%
  distinct() %>%
  group_by(word_id_new) %>%
  filter(n_distinct(word_category) == 1) %>%
  pull(word_id_new) %>%
  unique()

combined_final <- combined_final %>%
  mutate(word_id = paste(file_name, widx, sN, sep = "_")) %>%
  filter(word_id %in% clean_word_ids)

# ── 1. Classify slope type per vowel ──────────────────────────────────────────

token_slopes <- combined_final %>%
  select(word_id, sidx, f0_step1, f0_step20) %>%
  mutate(across(c(f0_step1, f0_step20), as.numeric)) %>%
  group_by(word_id, sidx) %>%
  summarise(
    f0_step1  = mean(f0_step1,  na.rm = TRUE),
    f0_step20 = mean(f0_step20, na.rm = TRUE),
    .groups = "drop"
  ) %>%
  mutate(slope_type = case_when(
    (f0_step20 - f0_step1) > 1 ~ "Rising",
    (f0_step1 - f0_step20) > 1 ~ "Falling",
    TRUE                        ~ "Stable"
  ))

pitch_cols <- paste0("f0_step", 1:20)

combined_final <- combined_final %>%
  left_join(select(token_slopes, word_id, sidx, slope_type),
            by = c("word_id", "sidx")) %>%
  select(-all_of(pitch_cols))

### SKIP HERE TO MODELS ###

# ── 2. Predicted stress from stress_cat ───────────────────────────────────────

predicted_stress <- model_data %>%
  filter(sN %in% c(2, 3, 4, 5)) %>%
  filter(stress_cat == stress_rule_A & 
           stress_cat == stress_rule_B & 
           stress_cat == stress_rule_C & 
           stress_cat == stress_rule_D & 
           stress_cat == stress_rule_E & 
           stress_cat == stress_rule_F) %>%
  select(word_id, word_category, sN, phrase_position, sidx, stress_cat) %>%
  distinct() %>%
  group_by(word_id) %>%
  filter(n_distinct(sidx) == first(sN)) %>%  # complete words only
  summarise(
    word_category   = first(word_category),
    sN              = first(sN),
    phrase_position = first(phrase_position),
    predicted_sidx  = sidx[as.character(stress_cat) == "Stressed"][1],
    .groups = "drop"
  ) %>%
  mutate(predicted_stress = case_when(
    predicted_sidx == 1  ~ "Initial",
    predicted_sidx == sN ~ "Final",
    predicted_sidx == sN - 1 ~ "Penultimate",
    predicted_sidx == sN - 2 ~ "Ante-penultimate",
    TRUE                 ~ "Medial"
  ))

# ── 3. Observed stress from slope ─────────────────────────────────────────────

observed_slope <- model_data %>%
  filter(sN %in% c(2, 3, 4, 5)) %>%
  filter(stress_cat == stress_rule_A & 
           stress_cat == stress_rule_B & 
           stress_cat == stress_rule_C & 
           stress_cat == stress_rule_D & 
           stress_cat == stress_rule_E & 
           stress_cat == stress_rule_F) %>%
  select(word_id, word_category, sN, phrase_position, sidx, slope_type) %>%
  distinct() %>%
  group_by(word_id) %>%
  mutate(n_rising = sum(slope_type == "Rising")) %>%
  summarise(
    word_category   = first(word_category),
    sN              = first(sN),
    phrase_position = first(phrase_position),
    observed_sidx   = ifelse(
      first(n_rising) == 1,
      sidx[slope_type == "Rising"],
      NA_real_
    ),
    .groups = "drop"
  ) %>%
  mutate(observed_slope_stress = case_when(
    is.na(observed_sidx)  ~ "Neutral",
    observed_sidx == 1    ~ "Initial",
    observed_sidx == sN   ~ "Final",
    observed_sidx == sN - 1 ~ "Penultimate",
    observed_sidx == sN - 2 ~ "Ante-penultimate",
    TRUE                  ~ "Medial"
  ))

# ── 4. Observed stress from duration ──────────────────────────────────────────

observed_dur <- model_data %>%
  filter(sN %in% c(2, 3, 4, 5)) %>%
  filter(stress_cat == stress_rule_A & 
           stress_cat == stress_rule_B & 
           stress_cat == stress_rule_C & 
           stress_cat == stress_rule_D & 
           stress_cat == stress_rule_E & 
           stress_cat == stress_rule_F) %>%
  group_by(word_id, word_category, sN, phrase_position, sidx, duration) %>%
  summarise(.groups = "drop") %>%
  group_by(word_id) %>%
  mutate(max_dur = max(duration, na.rm = TRUE)) %>%
  summarise(
    word_category   = first(word_category),
    sN              = first(sN),
    phrase_position = first(phrase_position),
    n_max           = sum(duration == max_dur, na.rm = TRUE),
    longest_sidx    = ifelse(first(n_max) == 1,
                             sidx[duration == max_dur],
                             NA_real_),
    .groups = "drop"
  ) %>%
  mutate(observed_dur_stress = case_when(
    is.na(longest_sidx)   ~ "Neutral",
    longest_sidx == 1     ~ "Initial",
    longest_sidx == sN    ~ "Final",
    longest_sidx == sN - 1 ~ "Penultimate",
    longest_sidx == sN - 2 ~ "Ante-penultimate",
    TRUE                  ~ "Medial"
  ))

# ── 5. Observed stress from amplitude ─────────────────────────────────────────

observed_amp <- model_data %>%
  filter(sN %in% c(2, 3, 4, 5)) %>%
  filter(stress_cat == stress_rule_A & 
           stress_cat == stress_rule_B & 
           stress_cat == stress_rule_C & 
           stress_cat == stress_rule_D & 
           stress_cat == stress_rule_E & 
           stress_cat == stress_rule_F) %>%
  group_by(word_id, word_category, sN, phrase_position, sidx, total_intensity) %>%
  summarise(.groups = "drop") %>%
  group_by(word_id) %>%
  mutate(max_amp = max(total_intensity, na.rm = TRUE)) %>%
  summarise(
    word_category   = first(word_category),
    sN              = first(sN),
    phrase_position = first(phrase_position),
    n_max           = sum(total_intensity == max_amp, na.rm = TRUE),
    loudest_sidx    = ifelse(first(n_max) == 1,
                             sidx[total_intensity == max_amp],
                             NA_real_),
    .groups = "drop"
  ) %>%
  mutate(observed_amp_stress = case_when(
    is.na(loudest_sidx)   ~ "Neutral",
    loudest_sidx == 1     ~ "Initial",
    loudest_sidx == sN    ~ "Final",
    loudest_sidx == sN - 1 ~ "Penultimate",
    loudest_sidx == sN - 2 ~ "Ante-penultimate",
    TRUE                  ~ "Medial"
  ))

# ── 6. Join everything together ───────────────────────────────────────────────

stress_combined <- predicted_stress %>%
  left_join(select(observed_slope, word_id, observed_slope_stress), by = "word_id") %>%
  left_join(select(observed_dur,   word_id, observed_dur_stress),   by = "word_id") %>%
  left_join(select(observed_amp,   word_id, observed_amp_stress),   by = "word_id") %>%
  mutate(phrase_position = factor(phrase_position,
                                  levels = c("initial", "medial", "final")))

# ── 7. Plotting function with predicted stress overlay ────────────────────────

stress_levels <- c("Initial", "Medial", "Ante-penultimate", "Penultimate", "Final", "Neutral")

plot_stress_cue <- function(data, observed_col, cue_name, sN_val) {
  
  obs_dist <- data %>%
    filter(sN == sN_val) %>%
    rename(observed = {{ observed_col }}) %>%
    mutate(observed = factor(observed, levels = stress_levels)) %>%
    group_by(word_category, phrase_position, observed) %>%
    summarise(n = n(), .groups = "drop") %>%
    group_by(word_category, phrase_position) %>%
    mutate(pct = n / sum(n)) %>%
    ungroup()
  
  pred_dist <- data %>%
    filter(sN == sN_val) %>%
    group_by(word_category, phrase_position, predicted_stress) %>%
    summarise(n = n(), .groups = "drop") %>%
    group_by(word_category, phrase_position) %>%
    mutate(pct_predicted = n / sum(n)) %>%
    ungroup() %>%
    rename(observed = predicted_stress) %>%
    mutate(observed = factor(observed, levels = stress_levels))
  
  total_N <- data %>% filter(sN == sN_val) %>% nrow()
  
  ggplot(obs_dist, aes(x = phrase_position, y = pct, fill = observed)) +
    geom_col(position = "stack") +
    geom_point(data = pred_dist,
               aes(x = phrase_position, y = pct_predicted, fill = observed),
               position = position_stack(vjust = 0.5),
               shape = 23, size = 2, color = "white", show.legend = FALSE) +
    geom_text(aes(label = ifelse(pct > 0.03, scales::percent(pct, accuracy = 1), "")),
              position = position_stack(vjust = 0.5), size = 3) +
    facet_wrap(~ word_category) +
    scale_fill_manual(values = c(
      "Initial" = "#E69F00",
      "Medial"  = "#56B4E9",
      "Neutral" = "#999999",
      "Penultimate" = "red",
      "Ante-penultimate" = "purple",
      "Final"   = "#009E73"
    )) +
    scale_y_continuous(labels = scales::percent) +
    labs(
      title    = paste0(cue_name, " stress — ", sN_val, "-syllable words (N=", total_N, ")"),
      subtitle = "Diamonds show predicted stress position (from stress_cat)",
      x = "Phrase position", y = "Proportion", fill = "Observed stress"
    ) +
    theme_bw()
}

# ── 8. Generate and save all plots ────────────────────────────────────────────

plots <- list(
  slope_2 = plot_stress_cue(stress_combined, observed_slope_stress, "Slope",     2),
  slope_3 = plot_stress_cue(stress_combined, observed_slope_stress, "Slope",     3),
  slope_4 = plot_stress_cue(stress_combined, observed_slope_stress, "Slope",     4),
  slope_5 = plot_stress_cue(stress_combined, observed_slope_stress, "Slope",     5),
  dur_2   = plot_stress_cue(stress_combined, observed_dur_stress,   "Duration",  2),
  dur_3   = plot_stress_cue(stress_combined, observed_dur_stress,   "Duration",  3),
  dur_4   = plot_stress_cue(stress_combined, observed_dur_stress,   "Duration",  4),
  dur_5   = plot_stress_cue(stress_combined, observed_dur_stress,   "Duration",  5),
  amp_2   = plot_stress_cue(stress_combined, observed_amp_stress,   "Amplitude", 2),
  amp_3   = plot_stress_cue(stress_combined, observed_amp_stress,   "Amplitude", 3),
  amp_4   = plot_stress_cue(stress_combined, observed_amp_stress,   "Amplitude", 4),
  amp_5   = plot_stress_cue(stress_combined, observed_amp_stress,   "Amplitude", 5)
)

walk2(plots, names(plots), ~ggsave(
  paste0("stress_", .y, ".png"), .x, width = 12, height = 7, dpi = 150
))


# --- A. Stacked Violin Plots (Dur, F0, Intensity) ---
plot_metrics <- df_final %>%
  filter(phon_stress == "0", syl_pos == "med") %>%
  select(label, vowel_strength_type, duration, f0, intensity) %>%
  pivot_longer(cols = c(duration, f0, intensity), names_to = "metric", values_to = "value") %>%
  mutate(
    metric_label = case_when(
      metric == "duration" ~ "Duration (ms)",
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
p1 <- create_violin(plot_metrics, "duration", colors)
p2 <- create_violin(plot_metrics, "f0", colors)
p3 <- create_violin(plot_metrics, "intensity", colors)

combined_plot <- (p1 / p2 / p3) + plot_annotation(title = "Acoustic Properties of Medial Unstressed Vowels")
print(combined_plot)

# --- B. Vowel Space Plot (F1 vs F2) ---
# Calculate Means
vowel_means <- combined_final %>%
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


vowels_pkg_df <- combined_final %>%
  # 1. Ensure acoustic columns are numeric
  mutate(across(c(F1, F2, F3), as.numeric)) %>%
  filter(context_type == "Non-Palatal") %>%

  # 2. Add glide columns (filled with NA since you are using steady-state points)
  mutate(
    F1_glide = NA_real_,
    F2_glide = NA_real_,
    F3_glide = NA_real_
  ) %>%
  
  # 3. Select and rename to match the required format exactly
  select(
    speaker_id,
    vowel_id = label,
    context,
    F1,
    F2,
    F3,
    F1_glide,
    F2_glide,
    F3_glide
  ) %>%
  # 2. Crucial: Remove rows where speaker or vowel is missing
  filter(!is.na(speaker_id), !is.na(vowel_id)) %>%
  # Ensure vowel_id is a plain character vector
  mutate(vowel_id = as.character(vowel_id))

vowels_pkg_df <- as.data.frame(vowels_pkg_df)

means <- compute.means(vowels_pkg_df)

vowelplot(means, color="vowels", labels="vowels")

add.spread.vowelplot(means, color="vowels", sd.mult=1)

normed <- norm.lobanov(vowels_pkg_df)

normed.means <- compute.means(normed)

vowelplot(normed.means, color="vowels", labels="vowels")


### compare vowels
combined_final %>%
  group_by(word_id) %>%
  mutate(word_mean_dur = mean(duration),
         dur_ratio = duration / word_mean_dur) %>%
  ungroup() %>%
  group_by(label, stress_cat) %>%
  summarise(median_ratio = median(dur_ratio, na.rm = TRUE),
            n = n())

combined_final %>%
  group_by(word_id) %>%
  mutate(
    word_mean_dur = mean(duration),
    word_mean_int = mean(total_intensity),
    dur_ratio = duration / word_mean_dur,
    int_ratio = total_intensity / word_mean_int
  ) %>%
  ungroup() %>%
  filter(stress_cat == "Stressed") %>%
  filter(label %in% c("y", "ʉ", "ø", "ɵ", "a", "e", "i", "u")) %>%
  group_by(label) %>%
  summarise(
    median_dur_ratio = median(dur_ratio, na.rm = TRUE),
    median_int_ratio = median(int_ratio, na.rm = TRUE),
    n = n()
  )

combined_final %>%
  group_by(word_id) %>%
  filter(sN > 1) %>%  # exclude monosyllables
  filter(n() == sN[1]) %>%  # only words where we have measurements for all syllables
  mutate(
    length_cat = case_when(
      duration == max(duration) ~ "long",
      duration == min(duration) ~ "short",
      TRUE ~ "mid"
    )
  ) %>%
  ungroup() %>%
  filter(label %in% c("a", "e", "i", "u", "y", "ʉ", "ø", "ɵ")) %>%
  group_by(label, stress_cat, length_cat) %>%
  summarise(n = n(), .groups = "drop") %>%
  group_by(label, stress_cat) %>%
  mutate(prop = n / sum(n)) %>%
  arrange(label, stress_cat, length_cat)

combined_final %>%
  group_by(word_id) %>%
  filter(sN > 1) %>%
  filter(n() == sN[1]) %>%
  mutate(
    length_cat = case_when(
      duration == max(duration) ~ "long",
      duration == min(duration) ~ "short",
      TRUE ~ "mid"
    )
  ) %>%
  ungroup() %>%
  filter(label %in% c("a", "e", "i", "u", "y", "ʉ", "ø", "ɵ")) %>%
  group_by(label, stress_cat, length_cat) %>%
  summarise(n = n(), .groups = "drop") %>%
  group_by(label, stress_cat) %>%
  mutate(prop = n / sum(n)) %>%
  mutate(length_cat = factor(length_cat, levels = c("long", "mid", "short"))) %>%
  ggplot(aes(x = stress_cat, y = prop, fill = length_cat)) +
  geom_col(position = "stack") +
  facet_wrap(~label, nrow = 2) +
  scale_fill_manual(values = c("long" = "#2166ac", "mid" = "#d1e5f0", "short" = "#d6604d")) +
  labs(x = "Stress", y = "Proportion", fill = "Length category",
       title = "Duration distribution by vowel and stress") +
  theme_minimal()

valid_words <- combined_final %>%
  filter(sN > 1) %>%
  group_by(word_id) %>%
  filter(n() == sN[1]) %>%
  pull(word_id) %>%
  unique()

# then run the main pipeline
combined_final %>%
  filter(word_id %in% valid_words) %>%
  group_by(word_id) %>%
  filter(sum(stress_cat == "Stressed") == 1) %>%  # exactly one stressed vowel
  mutate(
    is_longest = duration == max(duration),
    stressed_label = label[stress_cat == "Stressed"][1]
  ) %>%
  ungroup() %>%
  group_by(word_category, stressed_label, sidx) %>%
  summarise(
    prop_longest = mean(is_longest, na.rm = TRUE),
    n = n(),
    .groups = "drop"
  ) %>%
  filter(word_category == "FF") %>%
  ggplot(aes(x = factor(sidx), y = prop_longest)) +
  geom_col(fill = "#2166ac") +
  facet_grid(stressed_label ~ word_category) +
  labs(x = "Syllable position", y = "Proportion longest",
       title = "Which syllable is longest by word category and stressed vowel quality") +
  theme_minimal()

combined_final %>%
  filter(word_id %in% valid_words) %>%
  group_by(word_id) %>%
  filter(sum(stress_cat == "Stressed") == 1) %>%
  mutate(
    is_longest = duration == max(duration),
    stressed_label = label[stress_cat == "Stressed"][1]
  ) %>%
  ungroup() %>%
  filter(stressed_label %in% c("i", "u", "ø", "ɵ", "y", "ʉ")) %>%
  filter(label == stressed_label) %>%
  mutate(stressed_label = factor(stressed_label, 
                                 levels = c("i", "u", "y", "ʉ", "ø", "ɵ"),
                                 labels = c("/i/ (strong)", "/u/ (strong)", 
                                            "/y/ (?)", "/ʉ/ (?)",
                                            "/ø/ (weak)", "/ɵ/ (weak)"))) %>%
  group_by(stressed_label, stress_cat) %>%
  summarise(prop_longest = mean(is_longest, na.rm = TRUE),
            n = n(),
            .groups = "drop") %>%
  ggplot(aes(x = stress_cat, y = prop_longest, fill = stress_cat)) +
  geom_col() +
  facet_wrap(~stressed_label, nrow = 1) +
  scale_fill_manual(values = c("Stressed" = "#2166ac", "Unstressed" = "#d6604d")) +
  labs(x = NULL, y = "Proportion longest in word",
       title = "Acoustic prominence of stressed vs unstressed vowels",
       subtitle = "High vowels as controls for intrinsic length") +
  theme_minimal() +
  theme(legend.position = "bottom")


combined_final %>%
  group_by(word_id) %>%
  filter(stress_cat == "Stressed") %>%
  slice(1) %>%  # one row per word
  ungroup() %>%
  count(label, word_label) %>%  # n here is frequency of that word in corpus
  group_by(label) %>%
  summarise(
    n_word_types = n(),           # how many distinct words
    n_word_tokens = sum(n),       # total tokens across corpus
    median_word_freq = median(n), # typical frequency of words stressed on this vowel
    .groups = "drop"
  ) %>%
  mutate(prop_types = n_word_types / sum(n_word_types),
         prop_tokens = n_word_tokens / sum(n_word_tokens)) %>%
  arrange(desc(n_word_types))

zheltov_corpus <- read.csv("~/GitHub/phonology-chuvash/wordlists/zheltov_corpus.csv")

zheltov_corpus %>%
  group_by(word) %>%
  filter(phon_stress == "1") %>%
  count(label) %>%
  ungroup() %>%
  count(label) %>%
  mutate(prop = n / sum(n)) %>%
  arrange(desc(n))


combined_final %>%
  filter(word_id %in% valid_words) %>%
  group_by(word_id) %>%
  filter(sum(stress_cat == "Stressed") == 1) %>%
  mutate(is_longest = duration == max(duration)) %>%
  ungroup() %>%
  filter(stress_cat == "Stressed") %>%
  filter(label %in% c("a", "e", "i", "u", "y", "ʉ", "ø", "ɵ")) %>%
  filter(!is.na(phrase_position)) %>%
  group_by(label, phrase_position) %>%
  summarise(
    prop_longest = mean(is_longest, na.rm = TRUE),
    n = n(),
    .groups = "drop"
  ) %>%
  mutate(label = factor(label, levels = c("a", "e", "i", "u", "y", "ʉ", "ø", "ɵ")),
         phrase_position = factor(phrase_position, levels = c("initial", "medial", "final"))) %>%
  ggplot(aes(x = phrase_position, y = prop_longest, fill = phrase_position)) +
  geom_col() +
  geom_text(aes(label = n), vjust = -0.3, size = 3) +
  facet_wrap(~label, nrow = 2) +
  scale_fill_manual(values = c("initial" = "#4dac26", "medial" = "#d1e5f0", "final" = "#d6604d")) +
  labs(x = "Phrase position", y = "Proportion longest in word",
       title = "When predicted stressed, how often is vowel longest in word?",
       subtitle = "By phrasal position") +
  theme_minimal() +
  theme(legend.position = "bottom")

combined_final %>%
  filter(word_id %in% valid_words) %>%
  group_by(word_id) %>%
  filter(sum(stress_cat == "Stressed") == 1) %>%
  filter(word_category == "FF") %>%
  filter(sN == 2) %>%  # disyllables only for clarity
  mutate(is_longest = duration == max(duration)) %>%
  summarise(
    v1_label = label[sidx == 1],
    v2_label = label[sidx == 2],
    longest_syl = ifelse(is_longest[sidx == 1], "V1 longest", "V2 longest")
  ) %>%
  ungroup() %>%
  group_by(v1_label, longest_syl) %>%
  summarise(n = n(), .groups = "drop") %>%
  group_by(v1_label) %>%
  mutate(prop = n / sum(n)) %>%
  filter(longest_syl == "V1 longest") %>%
  mutate(v1_label = factor(v1_label, levels = c("a", "e", "i", "u"))) %>%
  ggplot(aes(x = v1_label, y = prop)) +
  geom_col(fill = "#2166ac") +
  geom_text(aes(label = n), vjust = -0.3, size = 3) +
  labs(x = "V1 quality", y = "Proportion where V1 is longest",
       title = "In FF disyllables, does V1 quality predict V1 being longest?",
       subtitle = "Stress predicted on V2; high bars = stress not reflected in duration") +
  theme_minimal()

combined_final %>%
  filter(word_id %in% valid_words) %>%
  group_by(word_id) %>%
  filter(sum(stress_cat == "Stressed") == 1) %>%
  filter(word_category == "FF") %>%
  filter(sN == 2) %>%
  mutate(is_loudest = total_intensity == max(total_intensity)) %>%
  summarise(
    v1_label = label[sidx == 1],
    v2_label = label[sidx == 2],
    loudest_syl = ifelse(is_loudest[sidx == 1], "V1 loudest", "V2 loudest")
  ) %>%
  ungroup() %>%
  group_by(v1_label, loudest_syl) %>%
  summarise(n = n(), .groups = "drop") %>%
  group_by(v1_label) %>%
  mutate(prop = n / sum(n)) %>%
  filter(loudest_syl == "V1 loudest") %>%
  filter(!is.na(v1_label)) %>%
  mutate(v1_label = factor(v1_label, levels = c("a", "e", "i", "u", "y", "ʉ"))) %>%
  ggplot(aes(x = v1_label, y = prop)) +
  geom_col(fill = "#d6604d") +
  geom_text(aes(label = n), vjust = -0.3, size = 3) +
  labs(x = "V1 quality", y = "Proportion where V1 is loudest",
       title = "In FF disyllables, does V1 quality predict V1 being loudest?",
       subtitle = "If gradient persists with intensity, intrinsic length is not the explanation") +
  theme_minimal()

combined_final %>%
  filter(word_id %in% valid_words) %>%
  group_by(word_id) %>%
  filter(sum(stress_cat == "Stressed") == 1) %>%
  filter(word_category == "FF") %>%
  filter(sN == 2) %>%
  summarise(
    v1_label = label[sidx == 1],
    v2_label = label[sidx == 2],
    v1_slope = slope_type[sidx == 1],
    v2_slope = slope_type[sidx == 2],
    .groups = "drop"
  ) %>%
  filter(v1_slope == "rising",
         v2_slope %in% c("falling", "stable")) %>%
  filter(!is.na(v1_label), !is.na(v2_label)) %>%
  group_by(v1_label, v2_label) %>%
  summarise(n = n(), .groups = "drop") %>%
  group_by(v2_label) %>%
  mutate(prop = n / sum(n)) %>%
  ggplot(aes(x = v1_label, y = prop)) +
  geom_col(fill = "#2166ac") +
  geom_text(aes(label = n), vjust = -0.3, size = 3) +
  facet_wrap(~v2_label, labeller = label_both) +
  labs(x = "V1 quality", y = "Proportion of initially-rising words",
       title = "FF disyllables with rising V1, falling/stable V2",
       subtitle = "Does V1 quality predict initial pitch rise?") +
  theme_minimal()

ff_disyl <- combined_final %>%
  filter(word_id %in% valid_words) %>%
  group_by(word_id) %>%
  filter(sum(stress_cat == "Stressed") == 1) %>%
  filter(word_category == "FF", sN == 2) %>%
  summarise(
    v1_label = label[sidx == 1],
    v2_label = label[sidx == 2],
    v1_slope = slope_type[sidx == 1],
    v2_slope = slope_type[sidx == 2],
    phrase_position = phrase_position
  ) %>%
  ungroup()

# check what you have before filtering
table(ff_disyl$v1_slope, useNA = "always")
table(ff_disyl$v2_slope, useNA = "always")

ff_disyl %>%
  filter(v1_slope == "Rising",
         v2_slope %in% c("Falling", "Stable")) %>%
  filter(!is.na(v1_label), !is.na(v2_label)) %>%
  group_by(v1_label, v2_label) %>%
  summarise(n = n(), .groups = "drop") %>%
  group_by(v2_label) %>%
  mutate(prop = n / sum(n)) %>%
  ggplot(aes(x = v1_label, y = prop)) +
  geom_col(fill = "#2166ac") +
  geom_text(aes(label = n), vjust = -0.3, size = 3) +
  facet_wrap(~v2_label, labeller = label_both) +
  labs(x = "V1 quality", y = "Proportion of initially-rising words",
       title = "FF disyllables with rising V1, falling/stable V2",
       subtitle = "Does V1 quality predict initial pitch rise?") +
  theme_minimal()

ff_disyl %>%
  filter(!is.na(v1_label), !is.na(v2_label)) %>%
  filter(!is.na(v1_slope), !is.na(v2_slope)) %>%
  mutate(target_pattern = v1_slope == "Rising" & 
           v2_slope %in% c("Falling", "Stable")) %>%
  group_by(v1_label, v2_label) %>%
  summarise(
    prop_target = mean(target_pattern),
    n_total = n(),
    n_target = sum(target_pattern),
    .groups = "drop"
  ) %>%
  filter(n_total >= 25) %>%  # exclude sparse combinations
  ggplot(aes(x = v1_label, y = prop_target)) +
  geom_col(fill = "#2166ac") +
  geom_text(aes(label = n_total), vjust = -0.3, size = 3) +
  facet_wrap(~v2_label, labeller = label_both) +
  labs(x = "V1 quality", y = "Proportion with rising V1, falling/stable V2",
       title = "How often does each V1/V2 pair show initially-rising pattern?",
       subtitle = "Denominator = all words with that V1/V2 combination") +
  theme_minimal()


ff_disyl %>%
  filter(!is.na(v1_label), !is.na(v2_label)) %>%
  filter(!is.na(v1_slope), !is.na(v2_slope)) %>%
  filter(phrase_position == "initial") %>%
  mutate(
    initial_stress_pattern = v1_slope == "Rising" & v2_slope %in% c("Falling", "Stable"),
    final_stress_pattern = v1_slope %in% c("Falling", "Stable") & v2_slope == "Rising"
  ) %>%
  filter(initial_stress_pattern | final_stress_pattern) %>%  # only clear cases
  mutate(pattern = ifelse(initial_stress_pattern, "Initial", "Final")) %>%
  group_by(v1_label, v2_label) %>%
  filter(n() >= 0) %>%
  summarise(
    prop_initial = mean(pattern == "Initial"),
    n_total = n(),
    .groups = "drop"
  ) %>%
  ggplot(aes(x = v1_label, y = prop_initial)) +
  geom_col(fill = "#2166ac") +
  geom_hline(yintercept = 0.5, linetype = "dashed", color = "red") +
  geom_text(aes(label = n_total), vjust = -0.3, size = 3) +
  facet_wrap(~v2_label, labeller = label_both) +
  labs(x = "V1 quality", y = "Proportion showing initial stress pattern",
       title = "Initial vs. final stress pattern by V1/V2 quality",
       subtitle = "Denominator = words showing either clear initial or final pitch pattern") +
  theme_minimal()

mono_coda_baseline <- combined_final %>%
  filter(sN == 1) %>%
  filter(syl_open_closed == "closed") %>%
  filter(label %in% c("a", "e", "i", "u", "y", "ʉ", "ø", "ɵ")) %>%
  group_by(label) %>%
  summarise(
    baseline_dur = median(duration),
    baseline_int = median(total_intensity),
    n = n(),
    .groups = "drop"
  )

mono_coda_baseline

combined_final %>%
  left_join(mono_coda_baseline %>% 
              select(label, baseline_dur, baseline_int), 
            by = "label") %>%
  mutate(
    dur_normalized = duration / baseline_dur,
    int_normalized = total_intensity / baseline_int
  )

combined_final %>%
  filter(word_id %in% valid_words) %>%
  left_join(mono_coda_baseline %>% 
              select(label, baseline_dur, baseline_int), 
            by = "label") %>%
  mutate(
    dur_normalized = duration / baseline_dur,
    int_normalized = total_intensity / baseline_int
  ) %>%
  group_by(word_id) %>%
  filter(sum(stress_cat == "Stressed") == 1) %>%
  filter(sN == 2) %>%
  ungroup() %>%
  filter(label %in% c("a", "e", "i", "u", "y", "ʉ", "ø", "ɵ")) %>%
  group_by(label, stress_cat) %>%
  summarise(
    median_dur_norm = median(dur_normalized, na.rm = TRUE),
    median_int_norm = median(int_normalized, na.rm = TRUE),
    n = n(),
    .groups = "drop"
  ) %>%
  pivot_longer(cols = c(median_dur_norm, median_int_norm),
               names_to = "measure", values_to = "value") %>%
  mutate(measure = recode(measure,
                          "median_dur_norm" = "Duration (normalized)",
                          "median_int_norm" = "Intensity (normalized)")) %>%
  ggplot(aes(x = stress_cat, y = value, fill = stress_cat)) +
  geom_col() +
  geom_hline(yintercept = 1, linetype = "dashed", color = "black") +
  facet_grid(measure ~ label, scales = "free_y") +
  scale_fill_manual(values = c("Stressed" = "#2166ac", "Unstressed" = "#d6604d")) +
  labs(x = NULL, y = "Normalized value (1 = monosyllable baseline)",
       title = "Normalized duration and intensity by vowel and stress",
       subtitle = "Controlling for intrinsic vowel properties") +
  theme_minimal() +
  theme(legend.position = "bottom")

mono_coda_baseline_clean <- combined_final %>%
  filter(sN == 1) %>%
  filter(syl_open_closed == "closed") %>%
  filter(total_intensity >= 300) %>%  # apply floor
  filter(label %in% c("a", "e", "i", "u", "y", "ʉ", "ø", "ɵ")) %>%
  group_by(label) %>%
  summarise(
    baseline_dur = median(duration),
    baseline_int = median(total_intensity),
    n = n(),
    .groups = "drop"
  )

mono_coda_baseline_clean

combined_final %>%
  filter(word_id %in% valid_words) %>%
  left_join(mono_coda_baseline_clean %>% 
              select(label, baseline_dur, baseline_int), 
            by = "label") %>%
  mutate(
    dur_normalized = duration / baseline_dur,
    int_normalized = total_intensity / baseline_int
  ) %>%
  group_by(word_id) %>%
  filter(sum(stress_cat == "Stressed") == 1) %>%
  filter(sN == 2) %>%
  ungroup() %>%
  filter(label %in% c("a", "e", "i", "u", "y", "ʉ", "ø", "ɵ")) %>%
  group_by(label, stress_cat) %>%
  summarise(
    median_dur_norm = median(dur_normalized, na.rm = TRUE),
    median_int_norm = median(int_normalized, na.rm = TRUE),
    n = n(),
    .groups = "drop"
  ) %>%
  pivot_longer(cols = c(median_dur_norm, median_int_norm),
               names_to = "measure", values_to = "value") %>%
  mutate(measure = recode(measure,
                          "median_dur_norm" = "Duration (normalized)",
                          "median_int_norm" = "Intensity (normalized)")) %>%
  ggplot(aes(x = stress_cat, y = value, fill = stress_cat)) +
  geom_col() +
  geom_hline(yintercept = 1, linetype = "dashed", color = "black") +
  facet_grid(measure ~ label, scales = "free_y") +
  scale_fill_manual(values = c("Stressed" = "#2166ac", "Unstressed" = "#d6604d")) +
  labs(x = NULL, y = "Normalized value (1 = monosyllable baseline)",
       title = "Normalized duration and intensity by vowel and stress",
       subtitle = "Controlling for intrinsic vowel properties") +
  theme_minimal() +
  theme(legend.position = "bottom")

### START HERE FOR MODELS
## MODELS that predict duration and amplitude

library(dplyr)

library(dplyr)

# Define the Vowel sets
high_vowels_ipa <- c('i','u','y','ʉ')
mid_vowels_ipa <- c('e','ø', 'ɵ')
low_vowels_ipa <- c('a')
strong_vowels_a <- c('ʉ','a','i','u','y','e')
reduced_vowels_a <- c('ø', 'ɵ')
strong_vowels_b <- c('a','i','u','y','e')
reduced_vowels_b <- c('ʉ', 'ø', 'ɵ')
strong_vowels_c <- c('a','i','u','e')
reduced_vowels_c <- c('y','ʉ', 'ø', 'ɵ')

valid_words <- combined_final %>%
  filter(sN > 1) %>%
  group_by(word_id) %>%
  filter(n() == sN[1]) %>%
  pull(word_id) %>%
  unique()

model_data <- combined_final %>%
  # 1. Create Vowel Height and Type columns
  mutate(
    vowel_height = case_when(
      label %in% high_vowels_ipa ~ "high",
      label %in% mid_vowels_ipa ~ "mid",
      label %in% low_vowels_ipa ~ "low",
      TRUE ~ NA_character_
    ),
    vowel_type_a = case_when(
      label %in% strong_vowels_a  ~ "strong",
      label %in% reduced_vowels_a ~ "reduced",
      TRUE                      ~ "other"
    ),
    vowel_type_b = case_when(
      label %in% strong_vowels_b  ~ "strong",
      label %in% reduced_vowels_b ~ "reduced",
      TRUE                      ~ "other"
    ),
    vowel_type_c = case_when(
      label %in% strong_vowels_c  ~ "strong",
      label %in% reduced_vowels_c ~ "reduced",
      TRUE                      ~ "other"
    ),
    #stress_rule_A = stress_cat
  ) %>%
  # 2. Apply Rule A Logic per word token
  filter(word_id %in% valid_words) %>%
  group_by(word_id) %>%
  mutate(
    # Identify which sidx is the "target" for stress under Rule B
    # If there are strong vowels, take the max sidx of those.
    # Otherwise, take the min sidx (initial vowel).
    target_sidx = if(any(vowel_type_a == "strong")) {
      max(sidx[vowel_type_a == "strong"], na.rm = TRUE)
    } else {
      min(sidx, na.rm = TRUE)
    },
    
    # Assign stress based on whether the current row's sidx matches the target
    stress_rule_A = if_else(sidx == target_sidx, "Stressed", "Unstressed")
  ) %>%
  ungroup() %>%
  # 2. Apply Rule B Logic per word token
  filter(word_id %in% valid_words) %>%
  group_by(word_id) %>%
  mutate(
    # Identify which sidx is the "target" for stress under Rule B
    # If there are strong vowels, take the max sidx of those.
    # Otherwise, take the min sidx (initial vowel).
    target_sidx = if(any(vowel_type_b == "strong")) {
      max(sidx[vowel_type_b == "strong"], na.rm = TRUE)
    } else {
      min(sidx, na.rm = TRUE)
    },
    
    # Assign stress based on whether the current row's sidx matches the target
    stress_rule_B = if_else(sidx == target_sidx, "Stressed", "Unstressed")
  ) %>%
  ungroup() %>%
  # 2. Apply Rule C Logic per word token
  filter(word_id %in% valid_words) %>%
  group_by(word_id) %>%
  mutate(
    # Identify which sidx is the "target" for stress under Rule B
    # If there are strong vowels, take the max sidx of those.
    # Otherwise, take the min sidx (initial vowel).
    target_sidx = if(any(vowel_type_c == "strong")) {
      max(sidx[vowel_type_c == "strong"], na.rm = TRUE)
    } else {
      min(sidx, na.rm = TRUE)
    },
    
    # Assign stress based on whether the current row's sidx matches the target
    stress_rule_C = if_else(sidx == target_sidx, "Stressed", "Unstressed")
  ) %>%
  ungroup() %>%
  # 3. Final cleaning and factoring
  mutate(
    vowel_height = factor(vowel_height, levels = c("high", "mid", "low")),
    stress_rule_A = factor(stress_rule_A, levels = c("Unstressed", "Stressed")),
    stress_rule_B = factor(stress_rule_B, levels = c("Unstressed", "Stressed")),
    stress_rule_C = factor(stress_rule_C, levels = c("Unstressed", "Stressed")),
    vowel_position = factor(context, levels = c("initial", "internal", "final")),
    syllable_structure = factor(syl_open_closed, levels = c("open", "closed")),
    phrase_position = factor(phrase_position, levels = c("initial", "medial", "final"))
  ) %>%
  select(-target_sidx) # Clean up temporary column

# 1. Log-transform duration for better model fit
model_data <- model_data %>%
  mutate(log_duration = log(duration))

# Add word frequency
word_freq <- model_data %>%
  count(word, name = "word_freq") %>%
  mutate(log_word_freq = log(word_freq))

model_data <- model_data %>%
  left_join(word_freq, by = "word")

parquet_file <- "C:/Users/profk/Downloads/train-00000-of-00001.parquet"

chuvash_mono <- map_dfr(parquet_file, read_parquet)

library(tidytext)

# Tokenize the monolingual corpus
mono_freq <- chuvash_mono %>%
  unnest_tokens(word, chv) %>%
  count(word, name = "corpus_freq") %>%
  mutate(log_corpus_freq = log(corpus_freq))

# Check coverage - how many of your words appear in the corpus?
your_words <- model_data %>% distinct(word_label)

your_words %>%
  left_join(mono_freq, by = c("word_label" = "word")) %>%
  summarise(
    n_total = n(),
    n_matched = sum(!is.na(corpus_freq)),
    n_missing = sum(is.na(corpus_freq)),
    pct_coverage = mean(!is.na(corpus_freq)) * 100
  )

# Check what the missing words look like
your_words %>%
  left_join(mono_freq, by = c("word_label" = "word")) %>%
  filter(is.na(corpus_freq)) %>%
  head(20)

# Use add-one smoothing for missing words (treat as frequency 1)
model_data <- model_data %>%
  left_join(mono_freq %>% select(word, log_corpus_freq), by = "word") %>%
  mutate(log_corpus_freq = if_else(is.na(log_corpus_freq), log(1), log_corpus_freq))

m_dur_freq_test <- lmer(log_duration ~ stress_rule_E + vowel_height + 
                          vowel_position + phrase_position + syllable_structure + 
                          log_corpus_freq + log_speech_rate +
                          (1 | speaker_id) + (1 | word), 
                        data = model_data, REML = FALSE)

#The bottom line is that (1 | word) already captures word-level frequency effects and everything else idiosyncratic to individual words. Any word-level frequency measure will be redundant with it. You can drop frequency entirely from your models — it's not adding anything meaningful and the rank deficiency is a sign the model is over-specified in that dimension. The word random effect is doing that job more flexibly than any single frequency covariate could.

# Add speech rate
all_vowels <- c(
  # Cyrillic
  "а", "А", "ӑ", "Ӑ", "е", "Е", "ё", "Ё", "ӗ", "Ӗ",
  "и", "И", "о", "О", "у", "У", "ӱ", "ӳ", "Ӳ",
  "ы", "Ы", "э", "Э", "ю", "Ю", "я", "Я",
  # Latin/non-standard that represent vowels
  "a", "A", "ă", "Ă", "e", "E", "è", "ĕ", "Ĕ",
  "i", "I", "o", "u", "y", "ÿ"
)

count_vowels <- function(text) {
  chars <- strsplit(text, "")[[1]]
  sum(chars %in% all_vowels)
}

model_data <- model_data %>%
  mutate(n_vowels_transcript = sapply(sentence, count_vowels))

utterance_durations_1 <- read.csv("~/GitHub/phonology-chuvash/scripts/extract file durations/utterance_durations_mfa.csv")
utterance_durations_2 <- read.csv("~/GitHub/phonology-chuvash/scripts/extract file durations/utterance_durations_vox.csv")

utterance_durations <- bind_rows(utterance_durations_1, utterance_durations_2) %>%
  distinct(file_name, .keep_all = TRUE)

utterance_rate <- model_data %>%
  left_join(utterance_durations, by = "file_name") %>%
  group_by(file_name) %>%
  summarise(
    utt_duration = first(duration_seconds),
    n_vowels_transcript = first(n_vowels_transcript),
    speech_rate = n_vowels_transcript / utt_duration,
    log_speech_rate = log(speech_rate),
    .groups = "drop"
  )

model_data <- model_data %>%
  #select(-log_speech_rate) %>%
  left_join(utterance_rate %>% select(file_name, log_speech_rate), 
            by = "file_name")

# Test "stressless" weak words
model_data <- model_data %>%
  mutate(
    stress_rule_D = if_else(stress_rule_A == "Stressed" & vowel_type_a == "reduced",
                            "Unstressed", as.character(stress_rule_A)),
    stress_rule_E = if_else(stress_rule_B == "Stressed" & vowel_type_b == "reduced",
                            "Unstressed", as.character(stress_rule_B)),
    stress_rule_F = if_else(stress_rule_C == "Stressed" & vowel_type_c == "reduced",
                            "Unstressed", as.character(stress_rule_C)),
    stress_rule_D = factor(stress_rule_D, levels = c("Unstressed", "Stressed")),
    stress_rule_E = factor(stress_rule_E, levels = c("Unstressed", "Stressed")),
    stress_rule_F = factor(stress_rule_F, levels = c("Unstressed", "Stressed"))
  )

df_conflict <- model_data %>%
  filter(stress_rule_A != stress_cat)

model_data <- model_data %>%
  filter(stress_rule_A == stress_cat)

# Find cases where Rule A, Rule B, and Rule C assign stress differently
df_conflict <- model_data %>%
  filter(!(stress_rule_A == stress_rule_B & 
             stress_rule_B == stress_rule_C &
             stress_rule_C == stress_rule_D &
             stress_rule_D == stress_rule_E &
             stress_rule_E == stress_rule_F))

# Check how many tokens we have for this 'horse race'
table(df_conflict$stress_rule_B, df_conflict$label)

library(lme4)
library(lmerTest) # This gives us p-values

# ---------------------------------------------------------
# DURATION MODELS
# ---------------------------------------------------------

m_dur_A <- lmer(log_duration ~ stress_rule_A + vowel_height + 
                  #vowel_type_a + 
                  vowel_position + phrase_position + syllable_structure + 
                  #log_word_freq + 
                  log_speech_rate +
                  (1 | speaker_id) + (1 | word), 
                data = model_data, REML = FALSE)

m_dur_B <- lmer(log_duration ~ stress_rule_B + vowel_height + 
                  #vowel_type_b + 
                  vowel_position + phrase_position + syllable_structure + 
                  #log_word_freq + 
                  log_speech_rate +
                  (1 | speaker_id) + (1 | word), 
                data = model_data, REML = FALSE)

m_dur_C <- lmer(log_duration ~ stress_rule_C + vowel_height + 
                  #vowel_type_c + 
                  vowel_position + phrase_position + syllable_structure + 
                  #log_word_freq + 
                  log_speech_rate +
                  (1 | speaker_id) + (1 | word), 
                data = model_data, REML = FALSE)

m_dur_D <- lmer(log_duration ~ stress_rule_D + vowel_height + 
                  #vowel_type_a + 
                  vowel_position + phrase_position + syllable_structure + 
                  #log_word_freq + 
                  log_speech_rate +
                  (1 | speaker_id) + (1 | word), 
                data = model_data, REML = FALSE)

m_dur_E <- lmer(log_duration ~ stress_rule_E + vowel_height + 
                  #vowel_type_b + 
                  vowel_position + phrase_position + syllable_structure + 
                  #log_word_freq + 
                  log_speech_rate +
                  (1 | speaker_id) + (1 | word), 
                data = model_data, REML = FALSE)

m_dur_F <- lmer(log_duration ~ stress_rule_F + vowel_height + 
                  #vowel_type_c + 
                  vowel_position + phrase_position + syllable_structure + 
                  #log_word_freq + 
                  log_speech_rate +
                  (1 | speaker_id) + (1 | word), 
                data = model_data, REML = FALSE)

anova(m_dur_A, m_dur_B, m_dur_C, m_dur_D, m_dur_E, m_dur_F)
# ---------------------------------------------------------
# AMPLITUDE MODELS
# ---------------------------------------------------------

m_amp_A <- lmer(total_intensity ~ stress_rule_A + vowel_height + 
                  #vowel_type_a + 
                  vowel_position + phrase_position + syllable_structure + 
                  #log_word_freq + 
                  log_speech_rate +
                  (1 | speaker_id) + (1 | word), 
                data = model_data, REML = FALSE)

m_amp_B <- lmer(total_intensity ~ stress_rule_B + vowel_height + 
                  #vowel_type_b + 
                  vowel_position + phrase_position + syllable_structure + 
                  #log_word_freq + 
                  log_speech_rate +
                  (1 | speaker_id) + (1 | word), 
                data = model_data, REML = FALSE)

m_amp_C <- lmer(total_intensity ~ stress_rule_C + vowel_height + 
                  #vowel_type_c + 
                  vowel_position + phrase_position + syllable_structure + 
                  #log_word_freq + 
                  log_speech_rate +
                  (1 | speaker_id) + (1 | word), 
                data = model_data, REML = FALSE)

m_amp_D <- lmer(total_intensity ~ stress_rule_D + vowel_height + 
                  #vowel_type_a + 
                  vowel_position + phrase_position + syllable_structure + 
                  #log_word_freq + 
                  log_speech_rate +
                  (1 | speaker_id) + (1 | word), 
                data = model_data, REML = FALSE)

m_amp_E <- lmer(total_intensity ~ stress_rule_E + vowel_height + 
                  #vowel_type_b + 
                  vowel_position + phrase_position + syllable_structure + 
                  #log_word_freq + 
                  log_speech_rate +
                  (1 | speaker_id) + (1 | word), 
                data = model_data, REML = FALSE)

m_amp_E <- lmer(total_intensity ~ stress_rule_E + vowel_height + 
                  vowel_position + phrase_position + syllable_structure + 
                  #log_word_freq + 
                  log_speech_rate +
                  (1 | speaker_id) + (1 | word), 
                data = model_data, REML = FALSE,
                control = lmerControl(optimizer = "bobyqa",
                                      optCtrl = list(maxfun = 2e5)))

m_amp_F <- lmer(total_intensity ~ stress_rule_F + vowel_height + 
                  #vowel_type_c + 
                  vowel_position + phrase_position + syllable_structure + 
                  #log_word_freq + 
                  log_speech_rate +
                  (1 | speaker_id) + (1 | word), 
                data = model_data, REML = FALSE)

anova(m_amp_A, m_amp_B, m_amp_C, m_amp_D, m_amp_E, m_amp_F)

# Model for the conflict subset only
m_dur_conflict_A <- lmer(log_duration ~ stress_rule_A + vowel_height + 
                           #vowel_type_a + 
                  vowel_position + phrase_position + syllable_structure + 
                    #log_word_freq + 
                    log_speech_rate +
                    (1 | speaker_id) + (1 | word), 
                data = df_conflict, REML = FALSE)

m_dur_conflict_B <- lmer(log_duration ~ stress_rule_B + vowel_height + 
                           #vowel_type_b + 
                  vowel_position + phrase_position + syllable_structure + 
                    #log_word_freq + 
                    log_speech_rate +
                    (1 | speaker_id) + (1 | word), 
                data = df_conflict, REML = FALSE)

m_dur_conflict_C <- lmer(log_duration ~ stress_rule_C + vowel_height + 
                           #vowel_type_c + 
                  vowel_position + phrase_position + syllable_structure + 
                    #log_word_freq + 
                    log_speech_rate +
                    (1 | speaker_id) + (1 | word), 
                data = df_conflict, REML = FALSE)

m_dur_conflict_D <- lmer(log_duration ~ stress_rule_D + vowel_height + 
                           #vowel_type_a + 
                  vowel_position + phrase_position + syllable_structure + 
                    #log_word_freq + 
                    log_speech_rate +
                    (1 | speaker_id) + (1 | word), 
                data = df_conflict, REML = FALSE)

m_dur_conflict_E <- lmer(log_duration ~ stress_rule_E + vowel_height + 
                           #vowel_type_b + 
                  vowel_position + phrase_position + syllable_structure + 
                    #log_word_freq + 
                    log_speech_rate +
                    (1 | speaker_id) + (1 | word), 
                data = df_conflict, REML = FALSE)

m_dur_conflict_F <- lmer(log_duration ~ stress_rule_F + vowel_height + 
                           #vowel_type_c + 
                  vowel_position + phrase_position + syllable_structure + 
                    #log_word_freq + 
                    log_speech_rate +
                    (1 | speaker_id) + (1 | word), 
                data = df_conflict, REML = FALSE)

anova(m_dur_conflict_A, m_dur_conflict_B, m_dur_conflict_C, m_dur_conflict_D, m_dur_conflict_E, m_dur_conflict_F)
# ---------------------------------------------------------
# AMPLITUDE MODELS
# ---------------------------------------------------------

m_amp_conflict_A <- lmer(total_intensity ~ stress_rule_A + vowel_height + 
                           #vowel_type_a + 
                  vowel_position + phrase_position + syllable_structure + 
                    #log_word_freq + 
                    log_speech_rate +
                    (1 | speaker_id) + (1 | word), 
                data = df_conflict, REML = FALSE)

m_amp_conflict_B <- lmer(total_intensity ~ stress_rule_B + vowel_height + 
                           #vowel_type_b + 
                  vowel_position + phrase_position + syllable_structure + 
                    #log_word_freq + 
                    log_speech_rate +
                    (1 | speaker_id) + (1 | word), 
                data = df_conflict, REML = FALSE)

m_amp_conflict_C <- lmer(total_intensity ~ stress_rule_C + vowel_height + 
                           #vowel_type_c + 
                  vowel_position + phrase_position + syllable_structure + 
                    #log_word_freq + 
                    log_speech_rate +
                    (1 | speaker_id) + (1 | word), 
                data = df_conflict, REML = FALSE)

m_amp_conflict_D <- lmer(total_intensity ~ stress_rule_D + vowel_height + 
                           #vowel_type_a + 
                  vowel_position + phrase_position + syllable_structure + 
                    #log_word_freq + 
                    log_speech_rate +
                    (1 | speaker_id) + (1 | word), 
                data = df_conflict, REML = FALSE)

m_amp_conflict_E <- lmer(total_intensity ~ stress_rule_E + vowel_height + 
                           #vowel_type_b + 
                  vowel_position + phrase_position + syllable_structure + 
                    #log_word_freq + 
                    log_speech_rate +
                    (1 | speaker_id) + (1 | word), 
                data = df_conflict, REML = FALSE)

m_amp_conflict_F <- lmer(total_intensity ~ stress_rule_F + vowel_height + 
                           #vowel_type_c + 
                  vowel_position + phrase_position + syllable_structure + 
                    #log_word_freq + 
                    log_speech_rate +
                    (1 | speaker_id) + (1 | word), 
                data = df_conflict, REML = FALSE)

anova(m_amp_conflict_A, m_amp_conflict_B, m_amp_conflict_C, m_amp_conflict_D, m_amp_conflict_E, m_amp_conflict_F)


summary(m_dur_E)
summary(m_amp_E)
summary(m_dur_conflict_E)
summary(m_amp_conflict_E)

library(jtools)
summ(m_dur_conflict_E)
summ(m_amp_conflict_E)

library(modelsummary)
modelsummary(m_dur_E, output = "latex")
modelsummary(m_amp_E, output = "latex")
modelsummary(m_dur_conflict_E, output = "latex")
modelsummary(m_amp_conflict_E, output = "latex")

library(texreg)

model_list <- list(m_dur_E, m_amp_E, m_dur_conflict_E, m_amp_conflict_E)

latex_output <- texreg(model_list,
                       caption = "Predicting duration and amplitude",
                       label = "tab:lmer_results",
                       booktabs = TRUE,
                       dcolumn = TRUE,
                       use.packages = FALSE)

# Print the output to the console
cat(latex_output)


df_cleanest <- remove_outliers(combined_final, c('F1', 'F2', 'duration', 'median_intensity', 'f0'))

quality_means <- df_cleanest %>%
  filter(context_type == "Non-Palatal") #%>% 
  #filter(syl_pos == "med") %>% 
  #filter(phon_stress == "0") %>% 
  #filter(gender == "male_masculine") %>%
  #filter(phrase_position == "initial")

with(quality_means, plotVowels(F1, F2, label, plot.tokens = FALSE, pch.tokens = label, 
                               cex.tokens = 1.2, alpha.tokens = 0.2, plot.means = TRUE, pch.means = label, 
                               cex.means = 2, var.col.by = label, family = "Charis SIL", pretty = TRUE, 
                               ellipse.line=TRUE, xlim = c(3200, 600), ylim = c(1000, 200), xlab="F2 (Hz.)", ylab="F1 (Hz.)"))


