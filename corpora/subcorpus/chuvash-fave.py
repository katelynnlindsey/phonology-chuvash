from new_fave import fave_audio_textgrid, write_data
import os

# --- Directory Paths ---
base_corpus_path = "C:\\Users\\profk\\Documents\\GitHub\\phonology-chuvash\\corpora"
audio_input_dir = os.path.join(base_corpus_path, "subcorpus") # Original audio files
textgrid_input_dir = os.path.join(base_corpus_path, "recoded_textgrids") # Recoded TextGrids
output_results_dir = os.path.join(base_corpus_path, "fave_output") # Final fave-extract output

# Create output directory if it doesn't exist
os.makedirs(output_results_dir, exist_ok=True)

print(f"Starting fave-extract processing for TextGrids in: {textgrid_input_dir}")
print(f"Audio files from: {audio_input_dir}")
print(f"Results will be saved to: {output_results_dir}")

all_speakers_data = []
processed_count = 0

for filename in os.listdir(textgrid_input_dir):
    if filename.endswith("_arpabet.TextGrid"): # Look for your recoded TextGrids
        recoded_tg_path = os.path.join(textgrid_input_dir, filename)
        
        # Derive original base name (e.g., utterance_000000_arpabet.TextGrid -> utterance_000000)
        base_name = filename.replace("_arpabet.TextGrid", "")
        
        # Construct path to the original WAV file
        audio_path = os.path.join(audio_input_dir, f"{base_name}.wav")
        
        if not os.path.exists(audio_path):
            print(f"Warning: Corresponding audio file '{audio_path}' not found for '{filename}'. Skipping.")
            continue

        print(f"Processing: {base_name}")
        try:
            # Call fave_audio_textgrid for each pair
            speakers_output = fave_audio_textgrid(
                audio_path = audio_path,
                textgrid_path = recoded_tg_path,
                speakers = "all",
                # recode_rules is NOT needed here as TextGrid is pre-recoded
                labelset_parser = "cmu_parser",
                point_heuristic = "fave",
                ft_config = "default"
            )
            all_speakers_data.append(speakers_output)
            processed_count += 1

        except Exception as e:
            print(f"Error processing '{base_name}': {e}. Skipping to next file.")
            continue

if all_speakers_data:
    print(f"\nFinished processing {processed_count} audio-TextGrid pairs. Writing all collected data.")
    # Write all collected data to the final output directory
    write_data(
        all_speakers_data,
        destination = output_results_dir
    )
    print(f"All fave-extract results saved to: {output_results_dir}")
else:
    print("\nNo TextGrid files were successfully processed for fave-extract.")

print("\nchuvash_fave_directory.py script finished.")