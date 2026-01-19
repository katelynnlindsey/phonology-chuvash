library(dplyr)
library(stringr)
library(partykit) # For the ctree function
library(ggplot2)  # For plot visualization, if desired (ctree has its own plot method)

all_chuvash_vowel_points <- read.csv("~/GitHub/phonology-chuvash/extract/all_chuvash_vowel_points.csv", encoding="UTF-8")

#REMOVE NON-VOWELS
vowel_labels <- c('AA', 'AH', 'EH', 'EY', 'IX', 'IY', 'UX', 'UW')

df_vowels_only <- all_chuvash_vowel_points %>%
  filter(label %in% vowel_labels)

vowels_removed_count <- nrow(all_chuvash_vowel_points) - nrow(df_vowels_only)
print(paste(vowels_removed_count, "rows removed because 'label' was not identified as a vowel."))
print(paste("DataFrame shape after vowel filtering:", nrow(df_vowels_only), "rows,", ncol(df_vowels_only), "columns"))

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
  print(paste("\nFiltering outliers for column:", col))
    
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
