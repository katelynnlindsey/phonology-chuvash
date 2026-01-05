import pandas as pd
import os
import sys

# --- Configuration ---
base_corpus_path = r"C:\Users\profk\Documents\GitHub\phonology-chuvash\test"
corpora = ["test-mfa", "test-vox"]   # subfolders to search
combined_csv_path = os.path.join(base_corpus_path, "all_chuvash_vowel_points.csv")  # output master CSV

print(f"Starting data combination from corpora: {corpora}")
print(f"Combined data will be saved to: {combined_csv_path}")

all_points_dfs = []
processed_files_count = 0
skipped_files_count = 0
not_found_count = 0
file_report = []  # collects (corpus, filepath, status, message)

for corpus in corpora:
    fave_output_dir = os.path.join(base_corpus_path, corpus, "fave_output")
    if not os.path.isdir(fave_output_dir):
        msg = f"fave_output directory not found for corpus '{corpus}': {fave_output_dir}"
        print(f"Warning: {msg}", file=sys.stderr)
        file_report.append((corpus, fave_output_dir, "missing", msg))
        not_found_count += 1
        continue

    for filename in sorted(os.listdir(fave_output_dir)):
        if filename.endswith("_points.csv"):
            file_path = os.path.join(fave_output_dir, filename)
            try:
                df = pd.read_csv(file_path, encoding='utf-8')
                df['corpus'] = corpus  # tag with source corpus
                all_points_dfs.append(df)
                processed_files_count += 1
                file_report.append((corpus, file_path, "loaded", "ok"))
            except pd.errors.EmptyDataError:
                msg = "empty file"
                print(f"Warning: {file_path} is empty. Skipping.", file=sys.stderr)
                skipped_files_count += 1
                file_report.append((corpus, file_path, "skipped", msg))
            except Exception as e:
                msg = str(e)
                print(f"Error reading {file_path}: {msg}. Skipping.", file=sys.stderr)
                skipped_files_count += 1
                file_report.append((corpus, file_path, "error", msg))

print(f"\nFinished loading. Files loaded: {processed_files_count}, skipped/errors: {skipped_files_count}, fave_output missing for {not_found_count} corpora.")

if all_points_dfs:
    combined_df = pd.concat(all_points_dfs, ignore_index=True)
    print(f"Combined DataFrame created with {len(combined_df)} rows from {len(all_points_dfs)} files.")
    try:
        combined_df.to_csv(combined_csv_path, index=False, encoding='utf-8')
        print(f"Combined CSV successfully written to: {combined_csv_path}")
    except Exception as e:
        print(f"Error writing combined CSV to {combined_csv_path}: {e}", file=sys.stderr)
else:
    print("No '_points.csv' files were successfully loaded. No combined CSV created.", file=sys.stderr)

# Optional: write a small CSV report of file statuses next to the combined CSV
report_path = os.path.join(base_corpus_path, "combine_report.csv")
try:
    report_df = pd.DataFrame(file_report, columns=["corpus", "filepath", "status", "message"])
    report_df.to_csv(report_path, index=False, encoding='utf-8')
    print(f"Report of file statuses written to: {report_path}")
except Exception as e:
    print(f"Could not write report CSV: {e}", file=sys.stderr)

print("\nData combination script finished.")