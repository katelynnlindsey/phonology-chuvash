import textgrid
import os
import codecs
import tempfile
import re
from pydub import AudioSegment
import shutil
import sys # <--- ADDED THIS IMPORT

# Define your IPA to ARPAbet mapping
ipa_to_arpabet_map = {
    'ʌ': 'AH', 'ɑ': 'AA', 'u': 'UW', 'y': 'UX', 'ɛ': 'EH', 'e': 'EY', 'o': 'OW', 'i': 'IY', 'ɯ': 'IX',
    'sil': 'SIL', 'v': 'V', 'j': 'Y', 'n': 'N', 'ʃ': 'SH', 'p': 'P', 'k': 'K', 'm': 'M', 'r': 'R',
    # Add any other IPA consonants you have that need specific ARPAbet mapping
}

# --- TextGrid Processing Function (unchanged for core logic, just verbosity) ---
def process_single_textgrid(input_tg_path, output_tg_path, mapping):
    temp_filepath = None
    try:
        content = None
        encodings_to_try = ['utf-8', 'latin-1', 'cp1252', 'iso-8859-1']
        
        for enc in encodings_to_try:
            try:
                with codecs.open(input_tg_path, 'r', encoding=enc) as f:
                    content = f.read()
                    if "File type" in content and "Object class" in content and ("text =" in content or "intervals:" in content):
                        break
                    else:
                        content = None
            except UnicodeDecodeError:
                content = None
            except Exception as e:
                print(f"Unexpected error during encoding trial for TG '{os.path.basename(input_tg_path)}' with {enc}: {e}", file=sys.stderr)
                content = None
        
        if not content:
            print(f"Warning: Could not reliably read TG '{os.path.basename(input_tg_path)}' with common encodings. Skipping TextGrid processing.", file=sys.stderr)
            return

        with tempfile.NamedTemporaryFile(mode='w', delete=False, encoding='utf-8', suffix='.TextGrid', newline='') as temp_file: 
            temp_file.write(content)
            temp_filepath = temp_file.name
        
        try:
            tg = textgrid.TextGrid.fromFile(temp_filepath)
        except Exception as e:
            print(f"Error: textgrid.TextGrid.fromFile() failed to parse temp TG '{os.path.basename(input_tg_path)}' ({temp_filepath}): {e}. Skipping TextGrid processing.", file=sys.stderr)
            return
        
        phones_tier = tg.getFirst('phones') 
        
        if phones_tier:
            for interval in phones_tier:
                original_label = interval.mark.strip()
                recoded_label = mapping.get(original_label, original_label)
                interval.mark = recoded_label
            # print(f"Recoded 'phones' tier in '{os.path.basename(input_tg_path)}'.") # Mute for less verbose batch output
        else:
            print(f"Warning: 'phones' tier not found in '{os.path.basename(input_tg_path)}'. No recoding performed for this TG.", file=sys.stderr)

        tg.write(output_tg_path) 
        # print(f"Saved recoded TextGrid to '{os.path.basename(output_tg_path)}'.") # Mute for less verbose batch output

    except Exception as e:
        print(f"An unexpected error occurred during TG processing '{os.path.basename(input_tg_path)}': {e}", file=sys.stderr)
    finally:
        if temp_filepath and os.path.exists(temp_filepath):
            os.remove(temp_filepath)

# --- Audio Processing Function (NEW) ---
def convert_or_copy_audio(input_audio_path, output_wav_path):
    base_name = os.path.basename(input_audio_path)
    output_base_name = os.path.basename(output_wav_path)

    if input_audio_path.lower().endswith(".mp3"):
        try:
            audio = AudioSegment.from_mp3(input_audio_path)
            # Ensure 16-bit, 1 channel (mono), 16000 Hz - standard for speech tools
            audio = audio.set_frame_rate(16000).set_channels(1).set_sample_width(2)
            audio.export(output_wav_path, format="wav")
            print(f"Converted '{base_name}' to '{output_base_name}'.")
            return True
        except Exception as e:
            print(f"Error converting MP3 '{base_name}' to WAV: {e}. Skipping audio conversion.", file=sys.stderr)
            return False
    elif input_audio_path.lower().endswith(".wav"):
        try:
            shutil.copy(input_audio_path, output_wav_path)
            # print(f"Copied existing WAV '{base_name}' to '{output_base_name}'.") # Mute for less verbose batch output
            return True
        except Exception as e:
            print(f"Error copying WAV '{base_name}': {e}. Skipping audio copy.", file=sys.stderr)
            return False
    else:
        print(f"Warning: Unsupported audio format for '{base_name}'. Skipping audio processing.", file=sys.stderr)
        return False

# --- Main Directory Processing Logic ---
base_corpus_path = "C:\\Users\\profk\\Documents\\GitHub\\phonology-chuvash\\corpora"
input_dir = os.path.join(base_corpus_path, "subcorpus")
output_recoded_tg_dir = os.path.join(base_corpus_path, "recoded_textgrids")
output_converted_audio_dir = os.path.join(base_corpus_path, "converted_audio") # New directory for prepared WAVs

# Create output directories if they don't exist
os.makedirs(output_recoded_tg_dir, exist_ok=True)
os.makedirs(output_converted_audio_dir, exist_ok=True)

print(f"Starting preparation process for files in: {input_dir}")
print(f"Recoded TextGrids will be saved to: {output_recoded_tg_dir}")
print(f"Converted/Copied audio will be saved to: {output_converted_audio_dir}")

processed_tgs_count = 0
processed_audio_count = 0
# Use sets to store base names of files that need processing or have been processed
all_basenames = set() # All unique base names (e.g., 'utterance_000000') found

# First pass: Identify all relevant base names (from TextGrids, MP3s, WAVs)
for filename in os.listdir(input_dir):
    name, ext = os.path.splitext(filename)
    if ext.lower() in [".textgrid", ".mp3", ".wav"]:
        all_basenames.add(name)

print(f"\nFound {len(all_basenames)} unique base names to process.")

# Second pass: Process TextGrids for each identified basename
print("\n--- Processing TextGrid files ---")
for base_name in sorted(list(all_basenames)): # Process in sorted order for consistency
    input_tg_path = os.path.join(input_dir, f"{base_name}.TextGrid")
    output_tg_path = os.path.join(output_recoded_tg_dir, f"{base_name}_arpabet.TextGrid")

    if not os.path.exists(input_tg_path):
        print(f"Warning: No TextGrid found for '{base_name}'. Skipping TextGrid recoding.", file=sys.stderr)
        continue # Skip to next basename if no TextGrid

    # print(f"Preparing TextGrid: {base_name}.TextGrid") # Muted for less verbose output
    process_single_textgrid(input_tg_path, output_tg_path, ipa_to_arpabet_map)
    processed_tgs_count += 1

print(f"\nFinished recoding {processed_tgs_count} TextGrids.")
print(f"Recoded TextGrids are in: {output_recoded_tg_dir}")

# Third pass: Process Audio Files (MP3 to WAV conversion / WAV copy) for each identified basename
print("\n--- Processing Audio files (MP3 to WAV conversion / WAV copy) ---")
for base_name in sorted(list(all_basenames)): # Process in sorted order for consistency
    original_mp3_path = os.path.join(input_dir, f"{base_name}.mp3")
    original_wav_path = os.path.join(input_dir, f"{base_name}.wav")
    
    target_output_wav_path = os.path.join(output_converted_audio_dir, f"{base_name}.wav")
    
    # Skip if WAV already exists in the converted_audio dir
    if os.path.exists(target_output_wav_path):
        # print(f"Skipping audio for '{base_name}': '{os.path.basename(target_output_wav_path)}' already exists in destination.") # Mute for less verbose output
        processed_audio_count += 1
        continue

    # Prioritize MP3 conversion if MP3 exists
    if os.path.exists(original_mp3_path):
        # print(f"Converting audio: {base_name}.mp3") # Muted for less verbose output
        if convert_or_copy_audio(original_mp3_path, target_output_wav_path):
            processed_audio_count += 1
    elif os.path.exists(original_wav_path):
        # print(f"Copying audio: {base_name}.wav") # Muted for less verbose output
        if convert_or_copy_audio(original_wav_path, target_output_wav_path):
            processed_audio_count += 1
    else:
        print(f"Warning: No MP3 or WAV audio found for base name '{base_name}'. Skipping audio processing.", file=sys.stderr)

print(f"\nFinished audio preparation for {processed_audio_count} files.")
print("\nmanual_recode_directory.py script finished.")
print(f"Prepared WAVs are in: {output_converted_audio_dir}")