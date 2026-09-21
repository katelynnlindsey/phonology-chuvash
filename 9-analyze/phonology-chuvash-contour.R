# ==============================================================================
# PHASE 1: SETUP & LOAD
# ==============================================================================
library(tidyverse)
library(ggh4x)  # For colored facet strips
library(ggpubr) # For significance bars
library(dplyr)


# Load raw data
df_raw_f0  <- read.csv("~/GitHub/phonology-chuvash/contour-clustering/output-f0-disyll.csv")
df_raw_int <- read.csv("~/GitHub/phonology-chuvash/contour-clustering/output2-f0-int-disyll.csv")
df_raw_vox <- read.csv("~/GitHub/phonology-chuvash/contour-clustering/output-vox.csv")
combined_raw_df <- bind_rows(df_raw_f0, df_raw_int, df_raw_vox)

# helper function to avoid repeating code for both datasets
clean_phonology_data <- function(data) {
  data %>%
    separate(interval_label, 
             into = c("vowel", "syll_num", "vowel_cat", "word_cat", "token_cat"), 
             sep = ";", fill = "right") %>%
    mutate(
      f0 = as.numeric(as.character(f0)),
      # Extract number from syllable (ensure "1" not "1-FR")
      syll_num = as.numeric(str_extract(syll_num, "\\d+")),
      duration = end - start
    ) %>%
    # Remove Duration Outliers (IQR Method per Vowel)
    group_by(vowel) %>%
    mutate(
      Q1 = quantile(duration, 0.25, na.rm = TRUE),
      Q3 = quantile(duration, 0.75, na.rm = TRUE),
      upper = Q3 + (1.5 * IQR(duration, na.rm = TRUE)),
      lower = Q1 - (1.5 * IQR(duration, na.rm = TRUE))
    ) %>%
    filter(duration >= lower, duration <= upper) %>%
    ungroup()
}

# ==============================================================================
# PHASE 2: PROCESSING PIPELINE
# ==============================================================================

# ------------------------------------------------------------------------------
# A. PITCH (F0) PROCESSING
# ------------------------------------------------------------------------------

# 1. Clean Base F0 Data
df_f0_clean <- clean_phonology_data(combined_raw_df) %>%
  filter(!is.na(f0), f0 > 0, !is.na(syll_num))

# 2. Assign Unique Dyad IDs (Word Instances)
# Used for pairing V1 and V2 later
df_f0_clean <- df_f0_clean %>%
  arrange(filename, start) %>%
  group_by(filename) %>%
  mutate(word_instance = cumsum(syll_num == 1 & stepnumber == 1)) %>%
  mutate(dyad_id = paste(filename, word_instance, sep="_")) %>%
  ungroup()

# 3. Calculate Slope Type (Rising/Falling/Stable) per Token
# We look at Step 1 vs Step 20
token_slopes <- df_f0_clean %>%
  filter(stepnumber %in% c(1, 20)) %>%
  select(dyad_id, syll_num, stepnumber, f0) %>%
  pivot_wider(names_from = stepnumber, names_prefix = "step", 
              values_from = f0, values_fn = mean) %>%
  mutate(slope_type = case_when(
    (step20 - step1) > 1 ~ "Rising",
    (step1 - step20) > 1 ~ "Falling",
    TRUE           ~ "Stable"
  ))

# Join slope info back to main data
df_f0_slopes <- df_f0_clean %>%
  left_join(select(token_slopes, dyad_id, syll_num, slope_type), 
            by = c("dyad_id", "syll_num"))

# 4. Summary Stats for Contour Plots (Means & SDs)
df_f0_summary <- df_f0_slopes %>%
  group_by(token_cat, stepnumber, slope_type) %>%
  summarise(
    mean_f0 = mean(f0, na.rm = TRUE),
    sd_f0 = sd(f0, na.rm = TRUE),
    n = n(),
    .groups = "drop"
  )

# 5. Calculate Percentages for "Weighted" plots
df_f0_pcts <- df_f0_slopes %>%
  group_by(token_cat, slope_type) %>%
  summarise(n = n_distinct(dyad_id), .groups = "drop_last") %>%
  mutate(pct = n / sum(n)) %>%
  ungroup()

# Join percentages into summary for plotting line thickness
df_f0_summary <- df_f0_summary %>%
  left_join(select(df_f0_pcts, token_cat, slope_type, pct), 
            by = c("token_cat", "slope_type"))

# 6. Dyad Logic (Pairing V1 and V2 Slopes)
df_f0_dyads <- df_f0_slopes %>%
  group_by(dyad_id, word_cat) %>%
  filter(f0 > 200) %>%
  filter(n_distinct(syll_num) == 2) %>% # Ensure we have both syllables
  select(dyad_id, word_cat, syll_num, slope_type) %>%
  distinct() %>%
  pivot_wider(names_from = syll_num, values_from = slope_type, names_prefix = "s") %>%
  mutate(dyad_slope_cat = paste(s1, s2, sep = "-"))

# 7. Dyad Distribution Stats
df_dyad_dist <- df_f0_dyads %>%
  filter(word_cat %in% c("FF", "FR", "RF", "RR")) %>%
  group_by(word_cat, dyad_slope_cat) %>%
  summarise(count = n(), .groups = "drop") %>%
  group_by(word_cat) %>%
  mutate(percent = (count / sum(count)) * 100) %>%
  ungroup()

# ------------------------------------------------------------------------------
# B. INTENSITY PROCESSING
# ------------------------------------------------------------------------------

# 1. Clean Base Intensity Data & Filter Floor
df_int_clean <- clean_phonology_data(df_raw_int) %>%
  filter(!is.na(f0), f0 > 0, !is.na(syll_num))

# 2. Create Dyad IDs (Same logic as F0)
df_int_clean <- df_int_clean %>%
  arrange(filename, start) %>%
  group_by(filename) %>%
  mutate(word_instance = cumsum(syll_num == 1 & stepnumber == 1)) %>%
  mutate(dyad_id = paste(filename, word_instance, sep="_")) %>%
  ungroup()

# 3. Calculate Total Amplitude per Syllable
df_int_sums <- df_int_clean %>%
  group_by(dyad_id, word_cat, syll_num) %>%
  summarise(total_amp = sum(intensity, na.rm = TRUE), .groups = "drop") %>%
  filter(total_amp > 300, total_amp < 2000) # Apply Floor and Ceiling

# 4. Compare V1 vs V2 Intensity
df_int_dyads <- df_int_sums %>%
  group_by(dyad_id) %>%
  filter(n() == 2) %>% # Must have 2 syllables
  pivot_wider(names_from = syll_num, values_from = total_amp, names_prefix = "s") %>%
  mutate(amp_dyad_cat = case_when(
    (s1 - s2) > 60 ~ "High-Low",
    (s2 - s1) > 60 ~ "Low-High",
    TRUE    ~ "Equal (within 60 dB)"
  ))

# 5. Intensity Distribution Stats
df_int_dist <- df_int_dyads %>%
  filter(word_cat %in% c("FF", "FR", "RF", "RR")) %>%
  group_by(word_cat, amp_dyad_cat) %>%
  summarise(count = n(), .groups = "drop") %>%
  group_by(word_cat) %>%
  mutate(percent = (count / sum(count)) * 100) %>%
  ungroup()

df_median_diff <- df_int_sums %>%
  group_by(word_cat, syll_num) %>%
  summarise(median_amp = median(total_amp, na.rm = TRUE), .groups = "drop") %>%
  tidyr::pivot_wider(
    names_from  = syll_num,
    values_from = median_amp,
    names_prefix = "s"
  ) %>%
  mutate(
    median_diff = s2 - s1,  # V2 - V1
    label = sprintf("Δ = %.1f dB", median_diff)
  )

# 6. Duration
df_dur <- df_int_clean %>%
  group_by(dyad_id, word_cat, syll_num) %>%
  summarise(dur = first(duration), .groups = "drop")

# 7. Duration dyads
df_dur_dyads <- df_dur %>%
  group_by(dyad_id) %>%
  filter(n() == 2) %>% # Must have 2 syllables
  pivot_wider(names_from = syll_num, values_from = dur, names_prefix = "s") %>%
  mutate(dur_dyad_cat = case_when(
    (s1 - s2) > .01 ~ "Long-Short",
    (s2 - s1) > .01 ~ "Short-Long",
    TRUE    ~ "Equal (within 10 ms)"
  ))

df_dur_dist <- df_dur_dyads %>%
  filter(word_cat %in% c("FF", "FR", "RF", "RR")) %>%
  group_by(word_cat, dur_dyad_cat) %>%
  summarise(count = n(), .groups = "drop") %>%
  group_by(word_cat) %>%
  mutate(percent = (count / sum(count)) * 100) %>%
  ungroup()


# ==============================================================================
# PHASE 3: PLOTTING
# ==============================================================================

# Define Order
target_order <- c("F-1-FF", "F-1-FR", "R-1-RF", "R-1-RR", 
                  "F-2-FF", "R-2-FR", "F-2-RF", "R-2-RR")
target_dyad_order <- c("FF", "FR", "RF", "RR")

# Set factors
df_f0_summary$token_cat <- factor(df_f0_summary$token_cat, levels = target_order)

# ------------------------------------------------------------------------------
# PLOT 1: F0 Contours (Weighted by Occurrence)
# ------------------------------------------------------------------------------

# Calculate dominant slope for border colors
border_colors <- df_f0_pcts %>%
  group_by(token_cat) %>%
  slice_max(pct, n = 1) %>%
  mutate(color = case_when(
    slope_type == "Rising" ~ "red",
    slope_type == "Falling" ~ "blue",
    TRUE ~ "gold"
  )) %>%
  arrange(match(token_cat, target_order)) %>%
  pull(color)

# Generate Labels
plot_labels <- df_f0_pcts %>%
  group_by(token_cat) %>%
  summarise(
    label = paste0(
      "R:", round(pct[slope_type=="Rising"]*100), "% ",
      "F:", round(pct[slope_type=="Falling"]*100), "%"
    )
  ) %>%
  mutate(token_cat = factor(token_cat, levels = target_order))

ggplot(df_f0_summary, aes(x = stepnumber, y = mean_f0, color = slope_type, fill = slope_type)) +
  geom_ribbon(aes(ymin = mean_f0 - sd_f0, ymax = mean_f0 + sd_f0), alpha = 0.1, color = NA) +
  geom_line(aes(linewidth = pct)) +
  geom_text(data = plot_labels, aes(x = 10, y = Inf, label = label), 
            vjust = 2, size = 3, color = "black", inherit.aes = FALSE) +
  scale_color_manual(values = c("Rising" = "red", "Falling" = "blue", "Stable" = "gold")) +
  scale_fill_manual(values = c("Rising" = "red", "Falling" = "blue", "Stable" = "gold")) +
  scale_linewidth_continuous(range = c(0.5, 2.5)) +
  facet_wrap2(~token_cat, ncol = 4, 
              strip = strip_themed(
                background_x = elem_list_rect(color = border_colors, size = 2, fill = NA)
              )) +
  theme_minimal() +
  labs(title = "F0 Contours Weighted by Occurrence", y = "F0 (Hz)", x = "Time Step")

# ------------------------------------------------------------------------------
# PLOT 2: Distribution of F0 Slopes (Bar Chart)
# ------------------------------------------------------------------------------
ggplot(df_dyad_dist, aes(x = factor(word_cat, levels=target_dyad_order), y = percent, fill = dyad_slope_cat)) +
  geom_bar(stat = "identity", position = "stack", width = 0.7) +
  geom_text(aes(label = ifelse(percent > 5, paste0(round(percent), "%"), "")), 
            position = position_stack(vjust = 0.5), size = 3.5, color="white", fontface="bold") +
  scale_fill_brewer(palette = "Set1") +
  theme_minimal() +
  labs(title = "Distribution of Slope Combinations", x = "Word Category", y = "Percentage")

# ------------------------------------------------------------------------------
# PLOT 3: Amplitude Comparison (Significance)
# ------------------------------------------------------------------------------
# 2. Choose a y-position for the label in each facet
df_int_sums_max <- df_int_sums %>%
  group_by(word_cat) %>%
  summarise(y_pos = max(total_amp, na.rm = TRUE) * 1.05, .groups = "drop")

df_median_diff <- df_median_diff %>%
  left_join(df_int_sums_max, by = "word_cat")

ggplot(df_int_sums, aes(x = as.factor(syll_num), y = total_amp, fill = as.factor(syll_num))) +
  geom_boxplot(outlier.shape = NA) +
  facet_wrap(~word_cat) +
  stat_compare_means(
    comparisons = list(c("1", "2")),
    method = "t.test",
    label = "p.signif"
  ) +
  geom_text(
    data = df_median_diff,
    aes(x = 1.5, y = y_pos, label = label),
    inherit.aes = FALSE,
    size = 3.5
  ) +
  theme_minimal() +
  scale_fill_brewer(palette = "Set2") +
  labs(
    title = "Filtered Total Amplitude by Syllable",
    subtitle = "Filtered for duration outliers and amplitude floor > 300",
    x = "Syllable Number",
    y = "Total Amplitude (dB)",
    fill = "Syllable"
  )

# ------------------------------------------------------------------------------
# PLOT 4: Amplitude Dyad Distribution
# ------------------------------------------------------------------------------
ggplot(df_int_dist, aes(x = word_cat, y = percent, fill = amp_dyad_cat)) +
  geom_bar(stat = "identity", position = "stack", color = "white") +
  geom_text(aes(label = paste0(round(percent, 0), "%")), 
            position = position_stack(vjust = 0.5), 
            size = 4, fontface = "bold") +
  scale_fill_manual(values = c("High-Low" = "#fc8d62", "Low-High" = "#66c2a5", "Equal (within 60 dB)" = "grey")) +
  theme_minimal() +
  labs(
    title = "Amplitude Relationships by Word Category",
    subtitle = "Comparing Total Amplitude: V1 vs V2",
    x = "Linguistic Word Category",
    y = "Percentage of Dyads",
    fill = "Amplitude Dyad Category"
  )

# ------------------------------------------------------------------------------
# PLOT 5: Duration Dyad Distribution
# ------------------------------------------------------------------------------
ggplot(df_dur_dist, aes(x = word_cat, y = percent, fill = dur_dyad_cat)) +
  geom_bar(stat = "identity", position = "stack", color = "white") +
  geom_text(aes(label = paste0(round(percent, 0), "%")), 
            position = position_stack(vjust = 0.5), 
            size = 4, fontface = "bold") +
  scale_fill_manual(values = c("Long-Short" = "#fc8d62", "Short-Long" = "#66c2a5", "Equal (within 10 ms)" = "grey")) +
  theme_minimal() +
  labs(
    title = "Duration Relationships by Word Category",
    subtitle = "Comparing Duration: V1 vs V2",
    x = "Linguistic Word Category",
    y = "Percentage of Dyads",
    fill = "Duration Dyad Category"
  )


# ------------------------------------------------------------------------------
# PLOT 6: Acoustic Cue Dominance Distribution
# ------------------------------------------------------------------------------

# 1. Combine and Transform Data
df_final <- bind_rows(
  df_dyad_dist %>% mutate(Metric = "Pitch (f0) Slope", Cat = dyad_slope_cat),
  df_int_dist  %>% mutate(Metric = "Amplitude (Intensity)", Cat = amp_dyad_cat),
  df_dur_dist  %>% mutate(Metric = "Duration", Cat = dur_dyad_cat)
) %>%
  mutate(
    Stress_Side = case_when(
      Cat %in% c("Rising-Falling", "Rising-Stable", "High-Low", "Long-Short") ~ "V1",
      Cat %in% c("Falling-Rising", "Stable-Rising", "Low-High", "Short-Long") ~ "V2",
      TRUE ~ "Neutral"
    ),
    word_cat = factor(word_cat, levels = c("FF", "RF", "FR", "RR"))
  ) %>%
  filter(Stress_Side != "Neutral") %>%
  group_by(word_cat, Metric, Stress_Side) %>%
  summarize(percent = sum(percent, na.rm = TRUE), .groups = "drop")

# 2. Create the Final Plot
final <- ggplot(df_final, aes(x = word_cat, y = percent, fill = Stress_Side)) +
  geom_bar(stat = "identity", position = position_dodge(width = 0.8), width = 0.7) +
  facet_wrap(~Metric) +
  
  # Percentage labels on top
  geom_text(aes(label = paste0(round(percent), "%")), 
            position = position_dodge(width = 0.8), 
            vjust = -0.5, size = 3.5, fontface = "bold") +
  
  # V1/V2 labels inside the bars
  geom_text(aes(y = 5, label = Stress_Side), 
            position = position_dodge(width = 0.8), 
            color = "white", fontface = "bold", size = 3) +
  
  # Formatting
  scale_fill_manual(values = c("V1" = "#377eb8", "V2" = "#e41a1c")) +
  scale_y_continuous(limits = c(0, 100), breaks = seq(0, 100, 25)) +
  theme_minimal() +
  theme(
    legend.position = "none",
    strip.text = element_text(size = 12, face = "bold"),
    panel.grid.major.x = element_blank(),
    panel.grid.minor = element_blank()
  ) +
  labs(
    #title = "Acoustic Cue Dominance by Word Category",
    #subtitle = "V1 (Blue) vs V2 (Red): RR patterns with FR in pitch but not in duration or amplitude",
    x = "Word Category",
    y = "Percentage of Tokens"
  )

print(final)

ggsave("disyll_vowels.pdf",
       plot = final,
       width = 10,
       height = 8.5)

##
# 1. Update the mapping (ensure it has both IDs needed for the join)
dyad_mapping <- df_f0_dyads %>%
  select(dyad_id, word_cat, dyad_slope_cat)

# 2. Update the join to use BOTH columns in the 'by' argument
df_plot_contours <- df_f0_clean %>%
  # Joining by both avoids the word_cat.x / word_cat.y suffix issue
  inner_join(dyad_mapping, by = c("dyad_id", "word_cat")) %>%
  
  # Create the Global Timeline
  mutate(global_step = ifelse(syll_num == 1, stepnumber, stepnumber + 20)) %>%
  
  # Now word_cat will be found correctly
  mutate(
    word_cat = factor(word_cat, levels = c("FF", "RF", "FR", "RR")),
    dyad_slope_cat = factor(dyad_slope_cat)
  )

# 3. Calculate Summary (Means per step)
df_contour_summary <- df_plot_contours %>%
  group_by(word_cat, dyad_slope_cat, global_step, syll_num) %>%
  summarise(
    mean_f0 = mean(f0, na.rm = TRUE),
    se_f0 = sd(f0, na.rm = TRUE) / sqrt(n()),
    .groups = "drop"
  )

# 1. Reuse the summary data from the previous step
# (Ensure df_contour_summary exists from the previous run)

# 2. Create the Overlay Plot
ggplot(df_contour_summary, aes(x = global_step, y = mean_f0, 
                               color = word_cat, 
                               group = interaction(word_cat, syll_num))) +
  # Vertical line at the syllable boundary
  geom_vline(xintercept = 20.5, linetype = "dashed", color = "grey80") +
  
  # The f0 lines (one for each category)
  geom_line(linewidth = 1.2, alpha = 0.8) +
  
  # Error ribbons (optional, but good for showing if differences are significant)
  geom_ribbon(aes(ymin = mean_f0 - se_f0, ymax = mean_f0 + se_f0, fill = word_cat), 
              alpha = 0.15, color = NA) +
  
  # Facet by the acoustic shape only (the 4 columns)
  facet_wrap(~dyad_slope_cat, nrow = 1) +
  
  # Standardize the Hz range so the height is comparable
  scale_y_continuous(limits = c(200, 275), breaks = seq(150, 300, 25)) + 
  
  # Use a distinct color palette for the categories
  scale_color_brewer(palette = "Set1") +
  scale_fill_brewer(palette = "Set1") +
  
  theme_minimal() +
  theme(
    legend.position = "bottom",
    strip.text = element_text(face = "bold", size = 11),
    panel.grid.minor = element_blank(),
    panel.spacing = unit(1.5, "lines")
  ) +
  labs(
    title = "F0 Contour Comparison: Are RR and FR Identical?",
    subtitle = "V1 (Steps 1-20) and V2 (Steps 21-40) overlaid by Word Category",
    x = "Timeline (V1 followed by V2)",
    y = "Fundamental Frequency (Hz)",
    color = "Word Category",
    fill = "Word Category"
  )

##
# Merge the calculated percentages into the contour summary
df_plot_combined <- df_contour_summary %>%
  left_join(df_dyad_dist, by = c("word_cat", "dyad_slope_cat")) %>%
  # Create a label that includes the % for the legend/plot text
  mutate(label_text = paste0(round(percent, 1), "%"))

# This calculates the N for every word that had two syllables, 
# regardless of whether they were Rising, Falling, or Stable.
full_sample_n <- df_f0_dyads_pre_filter <- df_f0_slopes %>%
  group_by(dyad_id, word_cat) %>%
  filter(f0 > 200) %>%
  filter(n_distinct(syll_num) == 2) %>% 
  summarise(n = 1, .groups = "drop") %>%
  #group_by(word_cat) %>%
  summarise(Total_N = sum(n))

print(full_sample_n)

# 1. Summarize "Macro" Stats (V1 Rise/Fall, V2 Rise/Fall)
df_quadrant_stats <- df_dyad_dist %>%
  # Split "Rising-Falling" into s1="Rising", s2="Falling"
  separate(dyad_slope_cat, into = c("s1", "s2"), sep = "-", remove = FALSE) %>%
  group_by(word_cat) %>%
  summarise(
    # V1 Stats (Top/Bottom Left)
    v1_rise_pct = sum(percent[s1 == "Rising"]),
    v1_fall_pct = sum(percent[s1 == "Falling"]),
    
    # V2 Stats (Top/Bottom Right)
    v2_rise_pct = sum(percent[s2 == "Rising"]),
    v2_fall_pct = sum(percent[s2 == "Falling"])
  ) %>%
  # Reshape for plotting
  pivot_longer(cols = -word_cat, names_to = "metric", values_to = "pct") %>%
  mutate(
    # Create the text label (e.g., "R: 45%")
    label = paste0(ifelse(str_detect(metric, "rise"), "Rise: ", "Fall: "), 
                   round(pct, 1), "%"),
    
    # Set X Coordinates: V1 (Left) = 2, V2 (Right) = 22
    x = ifelse(str_detect(metric, "v1"), 1, 21),
    
    # Set Y Coordinates: Rise (Top) = 270, Fall (Bottom) = 205
    y = ifelse(str_detect(metric, "rise"), 272, 203),
    
    # Optional: Set a color helper (Grey for all, or match logic)
    color_group = "stats" 
  )

final2 <- ggplot(df_plot_combined, aes(x = global_step, y = mean_f0, 
                                       color = dyad_slope_cat, 
                                       group = dyad_slope_cat)) +
  
  facet_wrap(~word_cat, nrow = 1) +
  geom_vline(xintercept = 20.5, linetype = "dashed", color = "grey80") +
  
  # The Contours
  geom_line(aes(linewidth = percent/100), alpha = 0.8) +
  
  # Line End Labels
  geom_text(data = df_plot_combined %>% filter(global_step == 40),
            aes(label = label_text, x = 42), 
            hjust = 0, size = 3, fontface = "bold") +
  
  geom_text(data = df_quadrant_stats,
            aes(x = x, y = y, label = label),
            inherit.aes = FALSE,
            hjust = 0,
            size = 5, 
            color = "black",
            fontface = "italic") +

# Formatting
scale_linewidth_continuous(range = c(0.5, 2.5), guide = "none") + 
  scale_color_brewer(palette = "Set1", name = "Contour Shape") +
  scale_y_continuous(limits = c(200, 275)) +
  scale_x_continuous(expand = expansion(mult = c(0.05, 0.2))) +
  
  theme_minimal() +
  theme(legend.position = "bottom") +
  labs(y = "Mean F0 (Hz)", x = "Time Step")

print(final2)

ggsave("disyll_contours.pdf",
       plot = final2,
       width = 10,
       height = 8.5,
       device = cairo_pdf)

# Define a function to generate the plot
# Define all potential categories to keep colors consistent
all_potential_cats <- c("Falling-Falling", "Falling-Rising", "Rising-Falling", "Rising-Rising",
                        "Stable-Stable", "Stable-Falling", "Stable-Rising", "Falling-Stable", "Rising-Stable")

plot_presentation_slide <- function(data_input, title_text) {
  
  ggplot(data_input, aes(x = global_step, y = mean_f0, 
                         color = dyad_slope_cat, 
                         group = dyad_slope_cat)) +
    
    facet_wrap(~word_cat, nrow = 1) +
    geom_vline(xintercept = 20.5, linetype = "dashed", color = "grey80") +
    
    # 1. FIXED Linewidth: Lines stay the same thickness across all slides
    geom_line(linewidth = 1.3, alpha = 0.8) +
    
    # 2. Line Labels
    geom_text(data = data_input %>% filter(global_step == 40),
              aes(label = label_text, x = 42), 
              hjust = 0, size = 3, fontface = "bold", show.legend = FALSE) +
    
    # 3. Quadrant Stats (Always shown for context)
    geom_text(data = df_quadrant_stats,
              aes(x = x, y = y, label = label),
              inherit.aes = FALSE, hjust = 0, size = 3.5, 
              color = "grey60", fontface = "italic") +
    
    # 4. FIXED Color Scale: Forces colors to stay the same even when data is missing
    # We use 'limits' to ensure the color-to-category mapping never shifts.
    scale_color_brewer(palette = "Set1", 
                       name = "Contour Shape", 
                       limits = all_potential_cats, 
                       drop = FALSE) +
    
    # FIXED Coordinates: Ensures the 'camera' doesn't move between slides
    scale_y_continuous(limits = c(200, 275)) +
    scale_x_continuous(expand = expansion(mult = c(0.05, 0.2)), limits = c(0, 50)) +
    
    theme_minimal() +
    theme(
      legend.position = "bottom",
      panel.grid.minor = element_blank(),
      strip.text = element_text(face = "bold", size = 12)
    ) +
    labs(title = title_text, y = "Mean F0 (Hz)", x = "Time Step")
}

# Filter: Rank 1 by percent within each word category
data_slide1 <- df_plot_combined %>%
  group_by(word_cat) %>%
  filter(percent == max(percent)) %>% # Keeps only the top line
  ungroup()

a <- plot_presentation_slide(data_slide1, "Slide 1: Most Common Patterns per Category")

data_slide2 <- df_plot_combined %>%
  filter(dyad_slope_cat == "Falling-Falling")

b <- plot_presentation_slide(data_slide2, "Slide 2: The 'Falling-Falling' Contours")

# Filter: Starts with "Rising"
data_slide3 <- df_plot_combined %>%
  filter(str_starts(dyad_slope_cat, "Rising"))

c <- plot_presentation_slide(data_slide3, "Slide 3: Initial Rise (V1 Rising)")

# Filter: Starts with "Falling"
data_slide4 <- df_plot_combined %>%
  filter(str_starts(dyad_slope_cat, "Falling"))

d <- plot_presentation_slide(data_slide4, "Slide 4: Initial Fall (V1 Falling)")

# Filter: Ends with "Rising"
data_slide5 <- df_plot_combined %>%
  filter(str_ends(dyad_slope_cat, "Rising"))

e <- plot_presentation_slide(data_slide5, "Slide 5: Final Rise (V2 Rising)")

# Filter: Ends with "Falling"
data_slide6 <- df_plot_combined %>%
  filter(str_ends(dyad_slope_cat, "Falling"))

f <- plot_presentation_slide(data_slide6, "Slide 6: Final Fall (V2 Falling)")

print(a)
print(b)
print(c)
print(d)
print(e)
print(f)

# Example saving code
ggsave("slide1.png", plot = a, width = 10, height = 6)
ggsave("slide2.png", plot = b, width = 10, height = 6)
ggsave("slide3.png", plot = c, width = 10, height = 6)
ggsave("slide4.png", plot = d, width = 10, height = 6)
ggsave("slide5.png", plot = e, width = 10, height = 6)
ggsave("slide6.png", plot = f, width = 10, height = 6)

