pacman::p_load(
  tidyverse, scales, rcompanion, gmodels, vowels, graphics,
  ggplot2, ggpubr, phonR, hrbrthemes, viridis, forcats,
  patchwork, partykit, lme4, lmerTest, rstatix, cowplot,
  emmeans, ggh4x, arrow, purrr, stringr, data.table
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

words_long  <- read.csv("~/GitHub/phonology-chuvash/contour-clustering/output-words.csv")
phrases_long <- read.csv("~/GitHub/phonology-chuvash/contour-clustering/output-phrases.csv")

# ---- Vowel inventories ---------------------------------------------------

full_A    <- c("a", "e", "а", "ÿ", "е", "и", "у", "ӱ", "ӳ", "ы", "ю", "я")
reduced_A <- c("ă", "ĕ", "ӑ", "ӗ")

full_B    <- c("a", "e", "а", "ÿ", "е", "и", "у", "ӱ", "ӳ", "ю", "я")
reduced_B <- c("ă", "ĕ", "ӑ", "ӗ", "ы")

full_C    <- c("a", "e", "а", "е", "и", "у", "ю", "я")
reduced_C <- c("ă", "ĕ", "ӑ", "ӗ", "ы", "ӱ", "ӳ", "ÿ")

loan      <- c("o", "u", "ё", "о")  # same for all three rules

# ---- Helper: classify one character under a given rule -------------------

make_word_cat <- function(label, full, reduced) {
  chars <- strsplit(label, "")[[1]]
  cats <- ifelse(chars %in% full, "F",
                 ifelse(chars %in% reduced, "R",
                        ifelse(chars %in% loan, "L", NA_character_)))
  paste(cats[!is.na(cats)], collapse = "")
}

label_cats <- words_long %>%
  distinct(interval_label) %>%
  mutate(
    word_cat_A = sapply(interval_label, make_word_cat, full = full_A, reduced = reduced_A),
    word_cat_B = sapply(interval_label, make_word_cat, full = full_B, reduced = reduced_B),
    word_cat_C = sapply(interval_label, make_word_cat, full = full_C, reduced = reduced_C)
  )

# Drop any leftover columns from previous attempts
words_long <- words_long %>%
  select(-any_of(c("word_cat_A", "word_cat_B", "word_cat_C",
                   "word_cat_A.x", "word_cat_A.y",
                   "word_cat_B.x", "word_cat_B.y",
                   "word_cat_C.x", "word_cat_C.y")))

# Check label_cats looks right before joining
print(head(label_cats))

# Then rejoin
words_long <- words_long %>%
  left_join(label_cats, by = "interval_label")

word_metadata <- combined_final %>%
  select(file_name, word_label, speaker_id, phrase_position, widx) %>%
  distinct(file_name, word_label, .keep_all = TRUE) 

# 2. Join this unique mapping to words_long
words_long <- words_long %>%
  left_join(
    word_metadata,
    by = c("filename" = "file_name", "interval_label" = "word_label")
  )

words_long %>%
  filter(
    nchar(word_cat_A) == 2,          # disyllabic: exactly 2 vowels under Rule A
    phrase_position == "medial",
    widx == 2,
    !grepl("L", word_cat_A)          # no loan vowels
  ) %>%
  write_csv("output-words-disyllabic-medial-2.csv")

# ---- Pivot to wide -------------------------------------------------------
word_pivot_contour <- function(df) {
  df %>%
    # Keep only the columns needed to identify a unique segment + step
    select(filename, interval_label, start, end, duration,
           jumpkilleffect, interval_index, stepnumber, f0, intensity) %>%
    pivot_wider(
      id_cols     = c(filename, interval_label, start, end,
                      duration, jumpkilleffect, interval_index),
      names_from  = stepnumber,
      values_from = c(f0, intensity),
      names_glue  = "word_{.value}_step{stepnumber}"
    ) %>%
    # Sort columns so f0_step1…20 come before intensity_step1…20
    select(filename, interval_label, start, end, duration,
           jumpkilleffect, interval_index,
           matches("^word_f0_step\\d+$"),
           matches("^word_intensity_step\\d+$"))
}

phrase_pivot_contour <- function(df) {
  df %>%
    # Keep only the columns needed to identify a unique segment + step
    select(filename, interval_label, start, end, duration,
           jumpkilleffect, interval_index, stepnumber, f0, intensity) %>%
    pivot_wider(
      id_cols     = c(filename, interval_label, start, end,
                      duration, jumpkilleffect, interval_index),
      names_from  = stepnumber,
      values_from = c(f0, intensity),
      names_glue  = "phrase_{.value}_step{stepnumber}"
    ) %>%
    # Sort columns so f0_step1…20 come before intensity_step1…20
    select(filename, interval_label, start, end, duration,
           jumpkilleffect, interval_index,
           matches("^phrase_f0_step\\d+$"),
           matches("^phrase_intensity_step\\d+$"))
}

words_wide  <- word_pivot_contour(words_long)
phrases_wide <- phrase_pivot_contour(phrases_long)

words_wide <- words_wide %>%
  rename(word_interval_label = interval_label) %>%
  rename(word_duration = duration) %>%
  rename(word_start = start) %>%
  rename(word_end = end) %>%
  rename(word_jumpkilleffect = jumpkilleffect)

phrases_wide <- phrases_wide %>%
  rename(phrase_interval_label = interval_label) %>%
  rename(phrase_duration = duration) %>%
  rename(phrase_start = start) %>%
  rename(phrase_end = end) %>%
  rename(phrase_jumpkilleffect = jumpkilleffect)

combined_final <- setDT(combined_final) # change the data frame to a data table

words_wide <- setDT(words_wide) # change the data frame to a data table

combined_with_words <- combined_final[ # take table b
  words_wide, # join table a
  on = list(file_name = filename, start>=word_start, start<=word_end) # joining on these columns
] |> 
  setDF() # change it back to a data frame for comparison

combined_with_phrases <- combined_with_words %>%
   left_join(phrases_wide, by = c("file_name" = "filename"))

combined_final <- combined_with_phrases %>%
  filter(!is.na(label))

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


library(tidyverse)

# ============================================================
# VOWEL INVENTORIES
# (using Rule A as canonical for written corpus classification)
# ============================================================

full_vowels    <- c("а", "е","a", "e", "i","u","y")
reduced_vowels <- c("ø", "ɵ")
test_vowels <- c("ʉ")
loan_vowels    <- c("о", "ё", "o", "u")
all_vowels     <- c(full_vowels, reduced_vowels, test_vowels, loan_vowels)

classify_vowel <- function(v) {
  case_when(
    v %in% full_vowels    ~ "F",
    v %in% reduced_vowels ~ "R",
    v %in% test_vowels ~ "T",
    v %in% loan_vowels    ~ "L",
    TRUE                  ~ NA_character_
  )
}

# Helper: extract first vowel character from a syllable string
extract_vowel <- function(syl) {
  chars <- strsplit(syl, "")[[1]]
  vowel_chars <- chars[chars %in% all_vowels]
  if (length(vowel_chars) == 0) NA_character_ else vowel_chars[1]
}
extract_vowel <- Vectorize(extract_vowel)


# ============================================================
# ZHELTOV CORPUS ANALYSES
# ============================================================

# The Zheltov corpus has one row per syllable with columns:
#   label (vowel IPA), word, syllable, phon_stress, sidx, sN,
#   syl_pos, syl_open_closed, corpus

# --- Simplify syl_pos to initial / medial / final ----------
zheltov <- zheltov_corpus %>%
  mutate(
    vowel_cat = classify_vowel(label),
    position3 = case_when(
      syl_pos == "initial_final" ~ "initial",   # monosyllables: treat as initial
      str_detect(syl_pos, "initial") ~ "initial",
      str_detect(syl_pos, "final")   ~ "final",
      TRUE                           ~ "medial"
    )
  ) %>%
  filter(!is.na(vowel_cat), vowel_cat != "L")   # exclude loan vowels from main analyses


# ============================================================
# ANALYSIS 1: Positional distribution of vowel types
# ============================================================

# Observed counts
pos_counts <- zheltov %>%
  count(vowel_cat, position3) %>%
  group_by(vowel_cat) %>%
  mutate(
    total     = sum(n),
    observed  = n / total
  ) %>%
  ungroup()

# Expected counts: if vowel type and position were independent
pos_marginals <- zheltov %>%
  count(position3) %>%
  mutate(expected_prop = n / sum(n))

pos_distribution <- pos_counts %>%
  left_join(pos_marginals %>% select(position3, expected_prop), by = "position3") %>%
  mutate(
    observed_expected_ratio = observed / expected_prop,
    # Chi-square contribution per cell
    expected_n = total * expected_prop,
    chi_sq_contrib = (n - expected_n)^2 / expected_n
  )

cat("\n=== ANALYSIS 1: Positional distribution of vowel types ===\n")
print(pos_distribution %>%
        select(vowel_cat, position3, n, observed, expected_prop,
               observed_expected_ratio, chi_sq_contrib) %>%
        arrange(vowel_cat, position3))

# Chi-square test: are F and R vowels distributed differently across positions?
pos_matrix <- zheltov %>%
  filter(vowel_cat %in% c("F", "R")) %>%
  count(vowel_cat, position3) %>%
  pivot_wider(names_from = position3, values_from = n, values_fill = 0) %>%
  column_to_rownames("vowel_cat") %>%
  as.matrix()

cat("\nChi-square test (F vs R across positions):\n")
print(chisq.test(pos_matrix))


# ============================================================
# ANALYSIS 2: Vowel co-occurrence patterns — observed vs. expected
# ============================================================

# Get word_category (concatenation of F/R for each vowel in order)
# Use one row per word, reconstructing from syllable-level data

word_cats <- zheltov %>%
  filter(sN > 1) %>%                            # exclude monosyllables for now
  arrange(word, sidx) %>%
  group_by(word) %>%
  summarise(
    word_cat = paste(vowel_cat, collapse = ""),
    sN       = first(sN),
    .groups  = "drop"
  ) %>%
  filter(!str_detect(word_cat, "L"),            # exclude loan-containing words
         !str_detect(word_cat, "NA"))

# For disyllabic words: FR, RF, FF, RR
disyl <- word_cats %>%
  filter(sN == 2, nchar(word_cat) == 2)

# Observed frequencies
obs_disyl <- disyl %>%
  count(word_cat) %>%
  mutate(observed_prop = n / sum(n))

# Expected frequencies under independence:
# P(V1=F) * P(V2=F) etc., estimated from marginal vowel frequencies
v1_freq <- zheltov %>%
  filter(sN > 1) %>%
  group_by(word) %>%
  filter(sidx == min(sidx)) %>%
  ungroup() %>%
  count(vowel_cat) %>%
  filter(vowel_cat %in% c("F","R","T")) %>%
  mutate(prop = n / sum(n))

v2_freq <- zheltov %>%
  filter(sN > 1) %>%
  group_by(word) %>%
  filter(sidx == max(sidx)) %>%
  ungroup() %>%
  count(vowel_cat) %>%
  filter(vowel_cat %in% c("F","R","T")) %>%
  mutate(prop = n / sum(n))

expected_disyl <- crossing(
  v1 = c("F","R","T"),
  v2 = c("F","R","T")
) %>%
  mutate(
    word_cat      = paste0(v1, v2),
    p_v1          = v1_freq$prop[match(v1, v1_freq$vowel_cat)],
    p_v2          = v2_freq$prop[match(v2, v2_freq$vowel_cat)],
    expected_prop = p_v1 * p_v2
  )

cooccurrence <- obs_disyl %>%
  left_join(expected_disyl %>% select(word_cat, expected_prop), by = "word_cat") %>%
  mutate(
    observed_expected_ratio = observed_prop / expected_prop,
    expected_n              = sum(n) * expected_prop,
    chi_sq_contrib          = (n - expected_n)^2 / expected_n
  )

cat("\n=== ANALYSIS 2: Vowel co-occurrence in disyllabic words ===\n")
print(cooccurrence)

# Chi-square goodness of fit
chi_cooc <- sum(cooccurrence$chi_sq_contrib)
cat(sprintf("\nChi-square = %.2f, df = 3, p = %.4f\n",
            chi_cooc, pchisq(chi_cooc, df = 3, lower.tail = FALSE)))

# Also do for trisyllabic words (FFF, FFR, FRF, FRR, RFF, RFR, RRF, RRR)
trisyl <- word_cats %>%
  filter(sN == 3, nchar(word_cat) == 3)

obs_trisyl <- trisyl %>%
  count(word_cat) %>%
  mutate(observed_prop = n / sum(n)) %>%
  arrange(desc(n))

cat("\nTrisyllabic word category frequencies:\n")
print(obs_trisyl)

# Trisyllabic expected frequencies under independence
v1_freq_tri <- zheltov %>%
  filter(sN == 3) %>%
  group_by(word) %>%
  filter(sidx == 1) %>%
  ungroup() %>%
  count(vowel_cat) %>%
  filter(vowel_cat %in% c("F","R","T")) %>%
  mutate(prop = n / sum(n))

v2_freq_tri <- zheltov %>%
  filter(sN == 3) %>%
  group_by(word) %>%
  filter(sidx == 2) %>%
  ungroup() %>%
  count(vowel_cat) %>%
  filter(vowel_cat %in% c("F","R","T")) %>%
  mutate(prop = n / sum(n))

v3_freq_tri <- zheltov %>%
  filter(sN == 3) %>%
  group_by(word) %>%
  filter(sidx == 3) %>%
  ungroup() %>%
  count(vowel_cat) %>%
  filter(vowel_cat %in% c("F","R","T")) %>%
  mutate(prop = n / sum(n))

expected_trisyl <- crossing(
  v1 = c("F","R","T"),
  v2 = c("F","R","T"),
  v3 = c("F","R","T")
) %>%
  mutate(
    word_cat      = paste0(v1, v2, v3),
    p_v1          = v1_freq_tri$prop[match(v1, v1_freq_tri$vowel_cat)],
    p_v2          = v2_freq_tri$prop[match(v2, v2_freq_tri$vowel_cat)],
    p_v3          = v3_freq_tri$prop[match(v3, v3_freq_tri$vowel_cat)],
    expected_prop = p_v1 * p_v2 * p_v3
  )

trisyl_cooc <- obs_trisyl %>%
  left_join(expected_trisyl %>% select(word_cat, expected_prop), by = "word_cat") %>%
  mutate(
    observed_expected_ratio = observed_prop / expected_prop,
    expected_n              = sum(n) * expected_prop,
    chi_sq_contrib          = (n - expected_n)^2 / expected_n
  ) %>%
  arrange(desc(abs(observed_expected_ratio - 1)))

print(trisyl_cooc)

zheltov %>%
  filter(vowel_cat == "T") %>%
  mutate(
    position_label = case_when(
      sidx == 1  ~ "initial",
      sidx == sN ~ "final",
      TRUE       ~ paste0("medial-", sidx - 1)
    ),
    position_label = factor(position_label, 
                            levels = c("initial", "medial-1", "medial-2", 
                                       "medial-3", "medial-4", "final"))
  ) %>%
  count(position_label, .drop = FALSE) %>%
  ggplot(aes(x = position_label, y = n)) +
  geom_col() +
  labs(title = "Distribution of ʉ by absolute syllable position",
       x = "Position", y = "Count")

zheltov %>%
  filter(vowel_cat == "T", sN <= 5) %>%
  mutate(sN_label = paste0(sN, "-syllable words")) %>%
  count(sN_label, sidx) %>%
  ggplot(aes(x = factor(sidx), y = n)) +
  geom_col() +
  facet_wrap(~sN_label, scales = "free_x") +
  labs(title = "Distribution of ʉ by syllable position and word length",
       x = "Syllable index", y = "Count")

# What are the actual words with non-initial ʉ?
noninitial_T <- zheltov %>%
  filter(vowel_cat == "T", sidx > 1) %>%
  select(word, sidx, sN, label) %>%
  arrange(sN, sidx)

View(noninitial_T)

# ============================================================
# ANALYSIS 3: Minimal word shapes by vowel type
# ============================================================

monosyl <- zheltov_corpus %>%
  filter(sN == 1) %>%
  mutate(vowel_cat = classify_vowel(label)) %>%
  distinct(word, .keep_all = TRUE)   # one row per word

minimal_words <- monosyl %>%
  filter(!is.na(vowel_cat)) %>%
  count(vowel_cat, syl_open_closed) %>%
  group_by(vowel_cat) %>%
  mutate(
    total = sum(n),
    prop  = n / total
  ) %>%
  ungroup() %>%
  arrange(vowel_cat, syl_open_closed)

cat("\n=== ANALYSIS 3: Monosyllabic word shapes by vowel type ===\n")
print(minimal_words)

# Pivot for a clean table
minimal_wide <- minimal_words %>%
  select(vowel_cat, syl_open_closed, prop) %>%
  pivot_wider(names_from = syl_open_closed, values_from = prop, values_fill = 0) %>%
  left_join(
    monosyl %>% filter(!is.na(vowel_cat)) %>% count(vowel_cat, name = "total_words"),
    by = "vowel_cat"
  )

cat("\nPivoted summary:\n")
print(minimal_wide)

# Fisher's exact test: do R vowels require closed syllables more than F vowels?
if (all(c("open","closed") %in% colnames(minimal_words %>% pivot_wider(names_from=syl_open_closed, values_from=n, values_fill=0)))) {
  min_matrix <- monosyl %>%
    filter(!is.na(vowel_cat), vowel_cat %in% c("F","R")) %>%
    count(vowel_cat, syl_open_closed) %>%
    pivot_wider(names_from = syl_open_closed, values_from = n, values_fill = 0) %>%
    column_to_rownames("vowel_cat") %>%
    as.matrix()
  cat("\nFisher's exact test (F vs R: open vs closed monosyllables):\n")
  print(fisher.test(min_matrix))
}

# Analysis 1: positional distribution by individual vowel
zheltov %>%
  filter(!is.na(vowel_cat)) %>%
  count(label, position3) %>%
  group_by(label) %>%
  mutate(total = sum(n), prop = n / total) %>%
  ungroup() %>%
  left_join(pos_marginals %>% select(position3, expected_prop), by = "position3") %>%
  mutate(observed_expected_ratio = prop / expected_prop) %>%
  select(label, position3, n, prop, expected_prop, observed_expected_ratio) %>%
  arrange(label, position3) %>%
  pivot_wider(
    id_cols = label,
    names_from = position3,
    values_from = c(prop, observed_expected_ratio),
    names_glue = "{position3}_{.value}"
  ) %>%
  print()

# Analysis 2: co-occurrence — just get raw counts of each vowel bigram
zheltov %>%
  filter(sN == 2, !is.na(vowel_cat)) %>%
  filter(!str_detect(word, "-")) %>%    # exclude hyphenated compounds
  arrange(word, sidx) %>%
  group_by(word) %>%
  filter(n() == 2) %>%                  # safety check: exactly 2 rows per word
  summarise(bigram = paste(label, collapse = "-"), .groups = "drop") %>%
  count(bigram, sort = TRUE) %>%
  print(n = 40)

zheltov %>%
  filter(sN == 2, !is.na(vowel_cat)) %>%
  filter(!str_detect(word, "-")) %>%
  arrange(word, sidx) %>%
  group_by(word) %>%
  filter(n() == 2) %>%
  summarise(bigram = paste(label, collapse = "-"), .groups = "drop") %>%
  separate(bigram, into = c("v1", "v2"), sep = "-") %>%
  filter(v1 == "ʉ" | v2 == "ʉ") %>%
  mutate(ʉ_position = case_when(
    v1 == "ʉ" & v2 != "ʉ" ~ "initial",
    v2 == "ʉ" & v1 != "ʉ" ~ "final",
    v1 == "ʉ" & v2 == "ʉ" ~ "both"
  )) %>%
  count(ʉ_position)

zheltov %>%
  filter(sN == 2, !is.na(vowel_cat)) %>%
  filter(!str_detect(word, "-")) %>%
  arrange(word, sidx) %>%
  group_by(word) %>%
  filter(n() == 2) %>%
  summarise(bigram = paste(label, collapse = "-"), .groups = "drop") %>%
  separate(bigram, into = c("v1", "v2"), sep = "-") %>%
  filter(v2 == "ʉ", v1 != "ʉ") %>%
  count(v1, sort = TRUE)

# Analysis 3: minimal word shapes by individual vowel
zheltov_corpus %>%
  filter(sN == 1) %>%
  mutate(vowel_cat = classify_vowel(label)) %>%
  filter(!is.na(vowel_cat), vowel_cat != "L") %>%
  distinct(word, .keep_all = TRUE) %>%
  count(label, syl_open_closed) %>%
  group_by(label) %>%
  mutate(total = sum(n), prop = n / total) %>%
  ungroup() %>%
  pivot_wider(
    id_cols = c(label),
    names_from = syl_open_closed,
    values_from = prop,
    values_fill = 0
  ) %>%
  left_join(
    zheltov_corpus %>%
      filter(sN == 1) %>%
      mutate(vowel_cat = classify_vowel(label)) %>%
      filter(!is.na(vowel_cat), vowel_cat != "L") %>%
      distinct(word, .keep_all = TRUE) %>%
      count(label, name = "total_words"),
    by = "label"
  ) %>%
  arrange(desc(open)) %>%
  print()

# Get overall open/closed ratio across all monosyllables
overall_open_rate <- zheltov_corpus %>%
  filter(sN == 1) %>%
  mutate(vowel_cat = classify_vowel(label)) %>%
  filter(!is.na(vowel_cat), vowel_cat != "L") %>%
  distinct(word, .keep_all = TRUE) %>%
  summarise(open_rate = mean(syl_open_closed == "open")) %>%
  pull(open_rate)

# Now compute observed vs expected per vowel
zheltov_corpus %>%
  filter(sN == 1) %>%
  mutate(vowel_cat = classify_vowel(label)) %>%
  filter(!is.na(vowel_cat), vowel_cat != "L") %>%
  distinct(word, .keep_all = TRUE) %>%
  count(label, syl_open_closed) %>%
  group_by(label) %>%
  mutate(total = sum(n), observed_open = n / total) %>%
  ungroup() %>%
  filter(syl_open_closed == "open") %>%
  mutate(
    expected_open = overall_open_rate,
    oe_ratio = observed_open / expected_open
  ) %>%
  arrange(desc(oe_ratio)) %>%
  select(label, total, observed_open, expected_open, oe_ratio)

# ============================================================
# CHUVASH MONOLINGUAL CORPUS ANALYSES
# ============================================================
# chuvash_mono has one column: `chv` with raw sentences

# --- Tokenize into words and extract vowel sequences --------

# Define vowel pattern for extraction
vowel_pattern <- paste(
  c(full_vowels, reduced_vowels, loan_vowels),
  collapse = "|"
)

mono_words <- chuvash_mono %>%
  # Tokenize: split on whitespace and punctuation, lowercase
  mutate(chv = str_to_lower(chv)) %>%
  mutate(word = str_extract_all(chv, "[а-яёӑӗӱӳÿа-яa-z]+")) %>%
  unnest(word) %>%
  filter(nchar(word) > 0) %>%
  # Exclude words with loan characters (о, ё or Latin except a,e)
  filter(!str_detect(word, "[оёo]")) %>%
  distinct(word) %>%
  # Extract vowels in sequence
  mutate(
    vowels = map(word, function(w) {
      chars <- strsplit(w, "")[[1]]
      chars[chars %in% all_vowels]
    }),
    n_vowels = map_int(vowels, length),
    vowel_seq = map_chr(vowels, ~ paste(classify_vowel(.x), collapse = "")),
    vowel_seq = na_if(vowel_seq, ""),
  ) %>%
  filter(
    n_vowels > 0,
    !str_detect(vowel_seq, "NA"),
    !str_detect(vowel_seq, "L")
  )

cat("\n=== MONOLINGUAL CORPUS: word count after filtering ===\n")
cat(nrow(mono_words), "unique words\n")


# ============================================================
# ANALYSIS 1 (mono): Positional distribution
# ============================================================

mono_pos <- mono_words %>%
  filter(n_vowels >= 2) %>%   # need at least 2 syllables for position to vary
  mutate(
    first_vowel_cat = str_sub(vowel_seq, 1, 1),
    last_vowel_cat  = str_sub(vowel_seq, -1, -1),
    # All vowels in medial position (between first and last)
    medial_cats     = if_else(n_vowels > 2,
                              str_sub(vowel_seq, 2, n_vowels - 1),
                              NA_character_)
  )

# Count by position
first_counts  <- mono_pos %>% count(vowel_cat = first_vowel_cat, position3 = "initial")
last_counts   <- mono_pos %>% count(vowel_cat = last_vowel_cat,  position3 = "final")
medial_counts <- mono_pos %>%
  filter(!is.na(medial_cats)) %>%
  mutate(chars = strsplit(medial_cats, "")) %>%
  unnest(chars) %>%
  count(vowel_cat = chars, position3 = "medial")

mono_pos_dist <- bind_rows(first_counts, last_counts, medial_counts) %>%
  filter(vowel_cat %in% c("F","R")) %>%
  group_by(vowel_cat) %>%
  mutate(total = sum(n), prop = n / total) %>%
  ungroup()

# Expected marginals
mono_pos_marginals <- bind_rows(first_counts, last_counts, medial_counts) %>%
  filter(vowel_cat %in% c("F","R","T")) %>%
  group_by(position3) %>%
  summarise(n = sum(n)) %>%
  mutate(expected_prop = n / sum(n))

mono_pos_full <- mono_pos_dist %>%
  left_join(mono_pos_marginals %>% select(position3, expected_prop), by = "position3") %>%
  mutate(observed_expected_ratio = prop / expected_prop)

cat("\n=== ANALYSIS 1 (mono): Positional distribution ===\n")
print(mono_pos_full %>% arrange(vowel_cat, position3))


# ============================================================
# ANALYSIS 2 (mono): Vowel co-occurrence patterns
# ============================================================

mono_disyl <- mono_words %>%
  filter(n_vowels == 2, nchar(vowel_seq) == 2)

obs_mono_disyl <- mono_disyl %>%
  count(word_cat = vowel_seq) %>%
  mutate(observed_prop = n / sum(n))

cat("\n=== ANALYSIS 2 (mono): Disyllabic co-occurrence ===\n")
print(obs_mono_disyl %>% arrange(word_cat))

# Expected under independence
mono_v1 <- mono_words %>%
  filter(n_vowels >= 2) %>%
  mutate(v1 = str_sub(vowel_seq, 1, 1)) %>%
  count(v1) %>%
  filter(v1 %in% c("F","R")) %>%
  mutate(prop = n / sum(n))

mono_v2 <- mono_words %>%
  filter(n_vowels >= 2) %>%
  mutate(v2 = str_sub(vowel_seq, -1, -1)) %>%
  count(v2) %>%
  filter(v2 %in% c("F","R")) %>%
  mutate(prop = n / sum(n))

expected_mono_disyl <- crossing(v1 = c("F","R"), v2 = c("F","R")) %>%
  mutate(
    word_cat      = paste0(v1, v2),
    p_v1          = mono_v1$prop[match(v1, mono_v1$v1)],
    p_v2          = mono_v2$prop[match(v2, mono_v2$v2)],
    expected_prop = p_v1 * p_v2
  )

mono_cooc <- obs_mono_disyl %>%
  left_join(expected_mono_disyl %>% select(word_cat, expected_prop), by = "word_cat") %>%
  mutate(
    observed_expected_ratio = observed_prop / expected_prop,
    expected_n              = sum(n) * expected_prop,
    chi_sq_contrib          = (n - expected_n)^2 / expected_n
  )

cat("\nObserved vs. expected disyllabic word categories (mono corpus):\n")
print(mono_cooc)

chi_mono <- sum(mono_cooc$chi_sq_contrib)
cat(sprintf("\nChi-square = %.2f, df = 3, p = %.4f\n",
            chi_mono, pchisq(chi_mono, df = 3, lower.tail = FALSE)))

### plot vowels in mono syllables
library(tidyverse)

# Build position labels same way as before
vowel_pos <- zheltov %>%
  filter(!is.na(vowel_cat), vowel_cat != "L") %>%
  filter(!str_detect(word, "-")) %>%
  mutate(
    position_label = case_when(
      sidx == 1  ~ "initial",
      sidx == sN ~ "final",
      TRUE       ~ paste0("medial-", sidx - 1)
    ),
    position_label = factor(position_label,
                            levels = c("initial", "medial-1", "medial-2",
                                       "medial-3", "medial-4", "final"))
  )

# Compute O/E ratio per vowel x position
vowel_marginals <- vowel_pos %>%
  count(position_label) %>%
  mutate(expected_prop = n / sum(n))

heatmap_data <- vowel_pos %>%
  count(label, position_label, .drop = FALSE) %>%
  group_by(label) %>%
  mutate(total = sum(n), observed_prop = n / total) %>%
  ungroup() %>%
  left_join(vowel_marginals %>% select(position_label, expected_prop),
            by = "position_label") %>%
  mutate(
    oe_ratio = observed_prop / expected_prop,
    log_oe   = log2(oe_ratio + 0.001)   # log scale; +0.001 avoids log(0)
  ) %>%
  # Order vowels by sonority (low to high)
  mutate(label = factor(label, levels = c("a", "e", "ø", "ɵ", "i", "u", "y", "ʉ")))

# Plot
ggplot(heatmap_data, aes(x = position_label, y = label, fill = log_oe)) +
  geom_tile(color = "white", linewidth = 0.5) +
  geom_text(aes(label = sprintf("%.2f", oe_ratio)),
            size = 3, color = "white") +
  scale_fill_gradient2(
    low      = "#2166ac",   # blue = under-represented
    mid      = "grey85",
    high     = "#d6604d",   # red = over-represented
    midpoint = 0,           # log2(1) = 0, i.e. O/E = 1
    name     = "log₂(O/E)"
  ) +
  labs(
    title    = "Vowel distribution by word position (O/E ratios)",
    subtitle = "Red = over-represented, Blue = under-represented relative to chance",
    x        = "Position in word",
    y        = "Vowel"
  ) +
  theme_minimal(base_size = 13) +
  theme(
    axis.text.x  = element_text(angle = 30, hjust = 1),
    panel.grid   = element_blank()
  )

library(tidyverse)
library(patchwork)

# ============================================================
# ZHELTOV: open/closed monosyllables by vowel
# ============================================================

zheltov_mono_plot <- zheltov_corpus %>%
  filter(sN == 1) %>%
  mutate(vowel_cat = classify_vowel(label)) %>%
  filter(!is.na(vowel_cat), vowel_cat != "L") %>%
  filter(!str_detect(word, "-")) %>%
  distinct(word, .keep_all = TRUE) %>%
  # O/E ratio for open syllables per vowel
  mutate(overall_open = mean(syl_open_closed == "open")) %>%
  group_by(label) %>%
  summarise(
    n_open   = sum(syl_open_closed == "open"),
    n_closed = sum(syl_open_closed == "closed"),
    total    = n(),
    prop_open = n_open / total,
    .groups = "drop"
  ) %>%
  mutate(
    overall_open_rate = sum(n_open) / sum(total),
    oe_ratio = prop_open / overall_open_rate,
    label = factor(label, levels = c("a", "e", "ø", "ɵ", "i", "u", "y", "ʉ"))
  )

# Stacked bar: raw counts, colored by open/closed
p1 <- zheltov_corpus %>%
  filter(sN == 1) %>%
  mutate(vowel_cat = classify_vowel(label)) %>%
  filter(!is.na(vowel_cat), vowel_cat != "L") %>%
  filter(!str_detect(word, "-")) %>%
  distinct(word, .keep_all = TRUE) %>%
  mutate(label = factor(label, levels = c("a", "e", "ø", "ɵ", "i", "u", "y", "ʉ"))) %>%
  count(label, syl_open_closed) %>%
  group_by(label) %>%
  mutate(prop = n / sum(n)) %>%
  ungroup() %>%
  ggplot(aes(x = label, y = prop, fill = syl_open_closed)) +
  geom_col(width = 0.7) +
  geom_hline(yintercept = zheltov_mono_plot$overall_open_rate[1],
             linetype = "dashed", color = "black", linewidth = 0.5) +
  scale_fill_manual(
    values = c("open" = "#d6604d", "closed" = "#2166ac"),
    name   = "Syllable type"
  ) +
  scale_y_continuous(labels = scales::percent) +
  annotate("text", x = 0.6, y = zheltov_mono_plot$overall_open_rate[1] + 0.02,
           label = "expected", size = 3, hjust = 0) +
  labs(title = "Zheltov wordlist",
       x = "Vowel", y = "Proportion") +
  theme_minimal(base_size = 13) +
  theme(legend.position = "bottom", panel.grid.minor = element_blank())

# ============================================================
# CHUVASH MONO: open/closed monosyllables by vowel
# Monosyllabic tokens = words with exactly 1 vowel
# ============================================================

full_cyr <- c("и", "ӱ", "ӳ", "у", "е", "э", "ю", "я", "а")  # added э
reduced_cyr <- c("ӗ", "ӑ")
test_cyr    <- c("ы")
loan_cyr    <- c("о", "ё")
all_cyr     <- c(full_cyr, reduced_cyr, test_cyr, loan_cyr)

classify_cyr <- function(v) {
  case_when(
    v %in% full_cyr    ~ "F",
    v %in% reduced_cyr ~ "R",
    v %in% test_cyr    ~ "T",
    v %in% loan_cyr    ~ "L",
    TRUE               ~ NA_character_
  )
}

# Get valid Chuvash word forms from Zheltov
zheltov_words <- zheltov_corpus %>%
  distinct(word) %>%
  mutate(word = str_remove_all(word, "[.''`'\\s]"),  # strip dots, apostrophes, spaces
         word = str_to_lower(word)) %>%
  filter(nchar(word) > 0) %>%
  pull(word)

# Also pre-clean the corpus to remove hyphenated line breaks
mono_monosyl <- chuvash_mono %>%
  # Remove hyphenated line breaks (word- \n continuation)
  mutate(chv = str_remove_all(chv, "-\\s+")) %>%
  mutate(token = str_extract_all(chv, "[а-яёӑӗӱӳыҫӑӗА-ЯЁҪӐӖ]+")) %>%
  unnest(token) %>%
  mutate(token = str_to_lower(token)) %>%
  filter(nchar(token) > 0) %>%
  # Keep only tokens that appear in the Zheltov wordlist
  filter(token %in% zheltov_words) %>%
  mutate(
    chars         = str_split(token, ""),
    vowels        = map(chars, ~ .x[.x %in% all_cyr]),
    n_vowels      = map_int(vowels, length)
  ) %>%
  filter(n_vowels == 1) %>%
  mutate(
    vowel         = map_chr(vowels, 1),
    vowel_cat     = classify_cyr(vowel),
    last_char     = str_sub(token, -1, -1),
    syl_structure = if_else(last_char %in% all_cyr, "open", "closed")
  ) %>%
  filter(!is.na(vowel_cat), vowel_cat != "L")

overall_open_mono <- mean(mono_monosyl$syl_structure == "open")

p2 <- mono_monosyl %>%
  mutate(label = factor(vowel, levels = c("а", "е", "ø", "ӑ", "и", "у", "ӱ", "ы", "э", "ю", "я")),
         # Map Cyrillic to IPA labels for consistency with Zheltov plot
         label_ipa = case_when(
           vowel == "а" ~ "a",
           vowel == "е" ~ "e",
           vowel == "ӗ" ~ "ø",
           vowel == "ӑ" ~ "ɵ",
           vowel == "и" ~ "i",
           vowel == "у" ~ "u",
           vowel == "ӱ" ~ "y",
           vowel == "ы" ~ "ʉ",
           vowel == "ю" ~ "u",
           vowel == "ӳ" ~ "y",
           vowel == "я" ~ "a",
           vowel == "э" ~ "e",
           TRUE ~ vowel
         ),
         label_ipa = factor(label_ipa,
                            levels = c("a", "e", "ø", "ɵ", "i", "u", "y", "ʉ"))) %>%
  count(label_ipa, syl_structure) %>%
  group_by(label_ipa) %>%
  mutate(prop = n / sum(n)) %>%
  ungroup() %>%
  ggplot(aes(x = label_ipa, y = prop, fill = syl_structure)) +
  geom_col(width = 0.7) +
  geom_hline(yintercept = overall_open_mono,
             linetype = "dashed", color = "black", linewidth = 0.5) +
  scale_fill_manual(
    values = c("open" = "#d6604d", "closed" = "#2166ac"),
    name   = "Syllable type"
  ) +
  scale_y_continuous(labels = scales::percent) +
  annotate("text", x = 0.6, y = overall_open_mono + 0.02,
           label = "expected", size = 3, hjust = 0) +
  labs(title = "Chuvash monolingual corpus",
       x = "Vowel", y = "Proportion") +
  theme_minimal(base_size = 13) +
  theme(legend.position = "bottom", panel.grid.minor = element_blank())

# ============================================================
# COMBINE WITH PATCHWORK
# ============================================================

p1 + p2 +
  plot_layout(guides = "collect") &
  plot_annotation(
    title    = "Proportion of open vs. closed monosyllables by vowel",
    subtitle = "Dashed line = overall expected open rate"
  ) &
  theme(legend.position = "bottom")

# Compute order from Zheltov data (use as canonical ordering for both plots)
vowel_order <- zheltov_corpus %>%
  filter(sN == 1) %>%
  mutate(vowel_cat = classify_vowel(label)) %>%
  filter(!is.na(vowel_cat), vowel_cat != "L") %>%
  filter(!str_detect(word, "-")) %>%
  distinct(word, .keep_all = TRUE) %>%
  group_by(label) %>%
  summarise(prop_open = mean(syl_open_closed == "open"), .groups = "drop") %>%
  arrange(desc(prop_open)) %>%
  pull(label)



# y u i e a ɵ ø ʉ — ordered high-to-low open rate

# Helper to add percentage labels to bars
add_pct_labels <- function(df) {
  df %>%
    group_by(label_ipa) %>%
    mutate(
      pct_label = if_else(
        syl_structure == "open" & prop >= 0.01,   # only label if ≥1%
        scales::percent(prop, accuracy = 1),
        ""
      ),
      # Position label in middle of open segment
      label_y = if_else(syl_structure == "open", prop / 2, NA_real_)
    ) %>%
    ungroup()
}

# ---- Zheltov plot ----
zheltov_bar_data <- zheltov_corpus %>%
  filter(sN == 1) %>%
  mutate(vowel_cat = classify_vowel(label)) %>%
  filter(!is.na(vowel_cat), vowel_cat != "L") %>%
  filter(!str_detect(word, "-")) %>%
  distinct(word, .keep_all = TRUE) %>%
  mutate(label_ipa = factor(label, levels = vowel_order)) %>%
  count(label_ipa, syl_open_closed) %>%
  rename(syl_structure = syl_open_closed) %>%
  group_by(label_ipa) %>%
  mutate(prop = n / sum(n)) %>%
  ungroup() %>%
  add_pct_labels()

overall_open_zheltov <- zheltov_bar_data %>%
  filter(syl_structure == "open") %>%
  summarise(r = sum(n) / sum(zheltov_bar_data$n)) %>%
  pull(r)

p1 <- zheltov_bar_data %>%
  ggplot(aes(x = label_ipa, y = prop, fill = syl_structure)) +
  geom_col(width = 0.7) +
  geom_text(aes(y = label_y, label = pct_label),
            color = "white", size = 3, fontface = "bold") +
  geom_hline(yintercept = overall_open_zheltov,
             linetype = "dashed", color = "black", linewidth = 0.5) +
  annotate("text", x = 0.6, y = overall_open_zheltov + 0.015,
           label = "expected", size = 3, hjust = 0) +
  scale_fill_manual(values = c("open" = "#d6604d", "closed" = "#2166ac"),
                    name = "Syllable type") +
  scale_y_continuous(labels = scales::percent) +
  labs(title = "Zheltov wordlist", x = "Vowel", y = "Proportion") +
  theme_minimal(base_size = 13) +
  theme(legend.position = "bottom", panel.grid.minor = element_blank())

# ---- Monolingual corpus plot ----
# IPA mapping for mono corpus
ipa_map <- c(
  "а" = "a",
  "е" = "e",
  "э" = "e",  
  "ӗ" = "ø",
  "ӑ" = "ɵ",
  "и" = "i",
  "у" = "u",
  "ӱ" = "y",
  "ӳ" = "y",
  "ю" = "u",
  "я" = "a",
  "ы" = "ʉ"
)

mono_bar_data <- mono_monosyl %>%
  mutate(
    label_ipa = factor(ipa_map[vowel], levels = vowel_order)
  ) %>%
  filter(!is.na(label_ipa)) %>%
  count(label_ipa, syl_structure) %>%
  group_by(label_ipa) %>%
  mutate(prop = n / sum(n)) %>%
  ungroup() %>%
  add_pct_labels()

overall_open_mono <- mono_bar_data %>%
  filter(syl_structure == "open") %>%
  summarise(r = sum(n) / sum(mono_bar_data$n)) %>%
  pull(r)

p2 <- mono_bar_data %>%
  ggplot(aes(x = label_ipa, y = prop, fill = syl_structure)) +
  geom_col(width = 0.7) +
  geom_text(aes(y = label_y, label = pct_label),
            color = "white", size = 3, fontface = "bold") +
  geom_hline(yintercept = overall_open_mono,
             linetype = "dashed", color = "black", linewidth = 0.5) +
  annotate("text", x = 0.6, y = overall_open_mono + 0.015,
           label = "expected", size = 3, hjust = 0) +
  scale_fill_manual(values = c("open" = "#d6604d", "closed" = "#2166ac"),
                    name = "Syllable type") +
  scale_y_continuous(labels = scales::percent) +
  labs(title = "Chuvash monolingual corpus", x = "Vowel", y = "Proportion") +
  theme_minimal(base_size = 13) +
  theme(legend.position = "bottom", panel.grid.minor = element_blank())

# ---- Combine ----
p1 + p2 +
  plot_layout(guides = "collect") &
  plot_annotation(
    title    = "Proportion of open vs. closed monosyllables by vowel",
    subtitle = "Dashed line = overall expected open rate"
  ) &
  theme(legend.position = "bottom")

# Zheltov counts and proportions by vowel
zheltov_table <- zheltov_corpus %>%
  filter(sN == 1) %>%
  mutate(vowel_cat = classify_vowel(label)) %>%
  filter(!is.na(vowel_cat), vowel_cat != "L") %>%
  filter(!str_detect(word, "-")) %>%
  distinct(word, .keep_all = TRUE) %>%
  group_by(label) %>%
  summarise(
    n_open   = sum(syl_open_closed == "open"),
    n_closed = sum(syl_open_closed == "closed"),
    n_total  = n(),
    pct_open = round(n_open / n_total * 100, 1),
    .groups  = "drop"
  ) %>%
  mutate(label = factor(label, levels = vowel_order)) %>%
  arrange(label)

# Monolingual corpus counts and proportions by vowel
mono_table <- mono_monosyl %>%
  mutate(label_ipa = ipa_map[vowel]) %>%
  filter(!is.na(label_ipa)) %>%
  group_by(label_ipa) %>%
  summarise(
    n_open   = sum(syl_structure == "open"),
    n_closed = sum(syl_structure == "closed"),
    n_total  = n(),
    pct_open = round(n_open / n_total * 100, 1),
    .groups  = "drop"
  ) %>%
  mutate(label_ipa = factor(label_ipa, levels = vowel_order)) %>%
  arrange(label_ipa)

print(zheltov_table)
print(mono_table)
