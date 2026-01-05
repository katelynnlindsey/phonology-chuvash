import os
import sys
import concurrent.futures
from tqdm import tqdm

# Ensure new_fave is correctly installed in editable mode if you made local changes
from new_fave import fave_audio_textgrid, write_data

# --- Directory Paths ---
base_corpus_path = "C:\\Users\\profk\\Documents\\GitHub\\phonology-chuvash\\extract-vox\\"
audio_input_dir = os.path.join(base_corpus_path, "converted_audio")
textgrid_input_dir = os.path.join(base_corpus_path, "recoded_textgrids")
output_results_dir = os.path.join(base_corpus_path, "fave_output")

# Create output directory if it doesn't exist
os.makedirs(output_results_dir, exist_ok=True)

# --- Function to process a single audio/TextGrid pair ---
def process_single_pair(args):
    audio_path, recoded_tg_path, base_name, output_dir = args
    
    # Imports that are only needed inside the child process (optional, but good practice if issues arise)
    # from new_fave import fave_audio_textgrid, write_data 
    
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
            destination = output_dir,
            which = ["points"], # As requested, only output points
            separate=False 
        )
        return True # Indicate success
    except Exception as e:
        # It's good to log which file failed for easier debugging
        print(f"Error processing '{base_name}': {e}. Skipping.", file=sys.stderr)
        return False # Indicate failure


# --- Main execution block for multiprocessing ---
if __name__ == '__main__':
    print(f"Starting fave-extract processing for TextGrids in: {textgrid_input_dir}")
    print(f"Audio files from: {audio_input_dir}")
    print(f"Results will be saved to: {output_results_dir}")

    # Collect successful TextGrid/Audio pairs to process
    all_potential_files = [] # All files we might process or skip
    for filename in os.listdir(textgrid_input_dir):
        if filename.endswith("_arpabet.TextGrid"):
            recoded_tg_path = os.path.join(textgrid_input_dir, filename)
            base_name = filename.replace("_arpabet.TextGrid", "")
            audio_path = os.path.join(audio_input_dir, f"{base_name}.wav")
            
            if not os.path.exists(audio_path):
                print(f"Warning: Prepared audio file '{os.path.basename(audio_path)}' not found in '{audio_input_dir}' for TextGrid '{filename}'. Skipping this pair.", file=sys.stderr)
                continue
            
            all_potential_files.append((audio_path, recoded_tg_path, base_name))

    if not all_potential_files:
        print("\nNo valid audio-TextGrid pairs found for fave-extract. Ensure preparation script ran successfully.", file=sys.stderr)
        sys.exit(0)

    # Prepare tasks for parallel execution, now including the "skip if exists" logic
    tasks_to_submit = []
    skipped_count = 0

    for audio_path, recoded_tg_path, base_name in all_potential_files:
        # Determine the expected output path for points data
        # new-fave by default names output files as {file_name}_{output_type}.csv
        expected_output_file = os.path.join(output_results_dir, f"{base_name}_points.csv")
        
        if os.path.exists(expected_output_file):
            print(f"Skipping fave-extract for '{base_name}': Output '{os.path.basename(expected_output_file)}' already exists.")
            skipped_count += 1
        else:
            tasks_to_submit.append((audio_path, recoded_tg_path, base_name, output_results_dir))

    # --- Use ProcessPoolExecutor for parallel processing ---
    # Determine the number of CPU cores to use. os.cpu_count() is a good default.
    max_workers = os.cpu_count()
    if max_workers is None: # Fallback if os.cpu_count() can't determine it
        max_workers = 1
    
    print(f"\nFound {len(all_potential_files)} audio-TextGrid pairs for consideration.")
    print(f"{skipped_count} files skipped because output already exists.")
    print(f"{len(tasks_to_submit)} files will be processed using {max_workers} parallel processes.")

    if not tasks_to_submit:
        print("\nNo new files to process. Script finished.")
        sys.exit(0)

    successful_count = 0
    # The 'with' statement ensures proper shutdown of the process pool
    with concurrent.futures.ProcessPoolExecutor(max_workers=max_workers) as executor:
        # executor.map submits tasks and returns results in the order tasks were submitted.
        # tqdm wraps the executor.map to provide a live progress bar.
        results_iterator = tqdm(
            executor.map(process_single_pair, tasks_to_submit), # Use tasks_to_submit
            total=len(tasks_to_submit),                         # Total for tqdm is number of tasks submitted
            desc="Processing new files"
        )
        
        for success in results_iterator:
            if success:
                successful_count += 1

    print(f"\nFinished processing {successful_count} new audio-TextGrid pairs successfully.")
    print(f"Total files now processed (new + skipped): {successful_count + skipped_count}")
    print(f"All fave-extract results saved to: {output_results_dir}")
    print("\nchuvash_fave.py script finished.")