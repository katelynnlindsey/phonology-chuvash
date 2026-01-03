import pandas as pd
import os
import sys

# --- Define Paths ---
base_corpus_path = "C:\\Users\\profk\\Documents\\GitHub\\phonology-chuvash\\corpora"
fave_output_dir = os.path.join(base_corpus_path, "fave_output")
combined_csv_path = os.path.join(base_corpus_path, "all_chuvash_vowel_points.csv") # The master CSV

print(f"Starting data combination process from: {fave_output_dir}")
print(f"Combined data will be saved to: {combined_csv_path}")

all_points_dfs = []
processed_files_count = 0
skipped_files_count = 0

# Iterate through all files in the fave_output directory
for filename in os.listdir(fave_output_dir):
    if filename.endswith("_points.csv"):
        file_path = os.path.join(fave_output_dir, filename)
        
        try:
            df = pd.read_csv(file_path, encoding='utf-8')
            all_points_dfs.append(df)
            processed_files_count += 1
            # Optional: print(f"Loaded: {filename}")
        except pd.errors.EmptyDataError:
            print(f"Warning: {filename} is empty. Skipping.", file=sys.stderr)
            skipped_files_count += 1
        except Exception as e:
            print(f"Error reading {filename}: {e}. Skipping.", file=sys.stderr)
            skipped_files_count += 1

print(f"\nFinished attempting to load files. Successfully loaded {processed_files_count} files, skipped {skipped_files_count} files.")

if all_points_dfs:
    print(f"Concatenating {len(all_points_dfs)} DataFrames...")
    combined_df = pd.concat(all_points_dfs, ignore_index=True)
    print(f"Combined DataFrame created with {len(combined_df)} entries.")
    
    # Save the combined DataFrame to a new CSV file
    combined_df.to_csv(combined_csv_path, index=False, encoding='utf-8')
    print(f"Combined data successfully saved to: {combined_csv_path}")

    # Optional: Display some info about the combined data
    # print("\nCombined DataFrame Info:")
    # combined_df.info()
    # print("\nCombined DataFrame Head (first 5 rows):")
    # print(combined_df.head())

else:
    print("No '_points.csv' files were successfully loaded. Cannot create combined DataFrame.")

print("\nData combination script finished.")