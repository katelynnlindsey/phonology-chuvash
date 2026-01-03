from new_fave import fave_audio_textgrid, write_data
import os
import sys # For error output

# --- Directory Paths ---
base_corpus_path = "C:\\Users\\profk\\Documents\\GitHub\\phonology-chuvash\\corpora"
audio_input_dir = os.path.join(base_corpus_path, "converted_audio")   # NEW: Look for WAVs here
textgrid_input_dir = os.path.join(base_corpus_path, "recoded_textgrids") # Recoded TextGrids
output_results_dir = os.path.join(base_corpus_path, "fave_output")    # Final fave-extract output

# Create output directory if it doesn't exist
os.makedirs(output_results_dir, exist_ok=True)

print(f"Starting fave-extract processing for TextGrids in: {textgrid_input_dir}")
print(f"Audio files from: {audio_input_dir}")
print(f"Results will be saved to: {output_results_dir}")

processed_count = 0

# Collect successful TextGrid/Audio pairs to process
files_to_process = []
for filename in os.listdir(textgrid_input_dir):
    if filename.endswith("_arpabet.TextGrid"):
        recoded_tg_path = os.path.join(textgrid_input_dir, filename)
        base_name = filename.replace("_arpabet.TextGrid", "")
        audio_path = os.path.join(audio_input_dir, f"{base_name}.wav")
        
        if not os.path.exists(audio_path):
            print(f"Warning: Prepared audio file '{os.path.basename(audio_path)}' not found in '{audio_input_dir}' for TextGrid '{filename}'. Skipping this pair.", file=sys.stderr)
            continue
        
        files_to_process.append((audio_path, recoded_tg_path, base_name))

if not files_to_process:
    print("\nNo valid audio-TextGrid pairs found for fave-extract. Ensure preparation script ran successfully.", file=sys.stderr)
    sys.exit(0) # Exit cleanly if nothing to process

print(f"\nFound {len(files_to_process)} audio-TextGrid pairs to process.")

for audio_path, recoded_tg_path, base_name in files_to_process:
    print(f"Processing: {base_name}...")
    try:
        speakers_output = fave_audio_textgrid(
            audio_path = audio_path,
            textgrid_path = recoded_tg_path,
            speakers = "all",
            labelset_parser = "cmu_parser",
            point_heuristic = "fave",
            ft_config = "default"
        )
        
        write_data(
            speakers_output,
            destination = output_results_dir,
            separate=False 
        )
        # print(f"Successfully processed and wrote data for '{base_name}'.") # Mute for less verbose output during batch
        processed_count += 1

    except Exception as e:
        print(f"Error processing '{base_name}': {e}. Skipping to next file.", file=sys.stderr)
        continue

print(f"\nFinished processing {processed_count} audio-TextGrid pairs.")
print(f"All fave-extract results saved to: {output_results_dir}")
print("\nchuvash_fave_directory.py script finished.")