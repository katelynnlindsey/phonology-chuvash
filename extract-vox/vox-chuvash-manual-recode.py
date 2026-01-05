import textgrid
import os
import codecs
import tempfile
import re
from pydub import AudioSegment
import shutil
import sys

# DEBUG: Print path of loaded textgrid module
print(f"DEBUG: 'textgrid' module loaded from: {textgrid.__file__}")

# Define your IPA to ARPAbet mapping
ipa_to_arpabet_map = {
    'ʌ': 'AH', 'ɑ': 'AA', 'u': 'UW', 'y': 'UX', 'ɛ': 'EH', 'e': 'EY', 'o': 'OW', 'i': 'IY', 'ɯ': 'IX',
    'sil': 'SIL', 'v': 'V', 'j': 'J', 'n': 'N', 'ʃ': 'SH', 'p': 'P', 'k': 'K', 'm': 'M', 'r': 'R',
    's': 'S', 't': 'T', 'd': 'D', 'l': 'L', 'z': 'Z', 'ŋ': 'NG', 'ð': 'DH', 'θ': 'TH', 'f': 'F',
    'w': 'W', 'h': 'HH', 'ʔ': 'Q', 'b': 'B', 'g': 'G', 'd͡ʒ': 'JH', 't͡ʃ': 'CH', 'ʒ': 'ZH', 'ɾ': 'DX',
}

# Define strong and weak vowel sets (using original IPA labels for stress decision)
STRONG_VOWELS_IPA = {'ɑ', 'u', 'y', 'e', 'o', 'i', 'ɯ'}
WEAK_VOWELS_IPA = {'ʌ', 'ɛ'}
ALL_VOWELS_IPA = STRONG_VOWELS_IPA.union(WEAK_VOWELS_IPA)


# --- TextGrid Processing Function ---
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
        words_tier = tg.getFirst('words') 

        if not phones_tier:
            print(f"Warning: 'phones' tier not found in '{os.path.basename(input_tg_path)}'. No recoding or stress assignment performed.", file=sys.stderr)
            return
        
        # Ensure phones_tier is an IntervalTier. If not, interval-based stress won't work.
        if not isinstance(phones_tier, textgrid.IntervalTier):
            print(f"Warning: 'phones' tier in '{os.path.basename(input_tg_path)}' is not an IntervalTier ({type(phones_tier).__name__}). Skipping interval-based stress assignment. Only direct label recoding will occur.", file=sys.stderr)
            # Just recode marks for non-interval tiers and write the TG.
            for interval in phones_tier:
                original_label = interval.mark.strip()
                recoded_label = mapping.get(original_label.lower(), original_label)
                interval.mark = recoded_label
            tg.write(output_tg_path)
            return # Exit processing for this TextGrid
            
        # Dictionary to store assigned stress for each phone interval (using (minTime, maxTime) tuple as key)
        # Initialize all vowels with '0' (unstressed) and non-vowels with '' (no stress mark)
        phone_stress_assignments = {}
        for p_interval in phones_tier.intervals: # Access .intervals explicitly
            original_label_ipa = p_interval.mark.strip().lower()
            interval_key = (p_interval.minTime, p_interval.maxTime) # <--- Using minTime, maxTime
            if original_label_ipa in ALL_VOWELS_IPA:
                phone_stress_assignments[interval_key] = '0' # Default all vowels to unstressed '0'
            else:
                phone_stress_assignments[interval_key] = '' # Consonants, silence get no stress mark

        # Check words_tier type as well. If not an IntervalTier, word-level stress won't apply.
        if not words_tier or not isinstance(words_tier, textgrid.IntervalTier):
            print(f"Warning: 'words' tier in '{os.path.basename(input_tg_path)}' not found or not an IntervalTier ({type(words_tier).__name__ if words_tier else 'None'}). Cannot assign word-level stress. Phones will only be ARPAbet (vowels default to 0 stress).", file=sys.stderr)
            # No word-level stress logic applied, phones keep default '0' if vowel, '' if consonant
        else:
            # Process word by word for stress assignment
            for w_interval in words_tier.intervals: # Access .intervals explicitly
                word_vowel_intervals = [] # Store interval objects that are vowels within this word
                
                for p_interval in phones_tier.intervals: # Access .intervals explicitly
                    # Check if phone interval is within the word interval
                    # Using minTime/maxTime for comparison
                    if p_interval.minTime >= w_interval.minTime and p_interval.maxTime <= w_interval.maxTime: # <--- Using minTime, maxTime
                        original_label_ipa = p_interval.mark.strip().lower()
                        if original_label_ipa in ALL_VOWELS_IPA:
                            word_vowel_intervals.append(p_interval)
                
                if not word_vowel_intervals:
                    continue # No vowels in this word, skip stress logic

                strong_vowels_in_word = [v for v in word_vowel_intervals if v.mark.strip().lower() in STRONG_VOWELS_IPA]
                weak_vowels_in_word = [v for v in word_vowel_intervals if v.mark.strip().lower() in WEAK_VOWELS_IPA]
                
                if strong_vowels_in_word:
                    # Rule 1: Rightmost strong stress ('1')
                    rightmost_strong_vowel = max(strong_vowels_in_word, key=lambda i: i.maxTime) # <--- Using maxTime
                    phone_stress_assignments[(rightmost_strong_vowel.minTime, rightmost_strong_vowel.maxTime)] = '1' # <--- Using minTime, maxTime
                elif weak_vowels_in_word:
                    # Rule 2: Leftmost weak stress ('2')
                    leftmost_weak_vowel = min(weak_vowels_in_word, key=lambda i: i.minTime) # <--- Using minTime
                    phone_stress_assignments[(leftmost_weak_vowel.minTime, leftmost_weak_vowel.maxTime)] = '2' # <--- Using minTime, maxTime


        # Now, iterate through the phones tier to apply ARPAbet recoding AND stress marks
        for interval in phones_tier.intervals: # Access .intervals explicitly
            original_label = interval.mark.strip()
            
            # Get ARPAbet equivalent (default to original if not in map)
            recoded_label = mapping.get(original_label.lower(), original_label)
            
            # Get the assigned stress mark for this interval using its key
            interval_key = (interval.minTime, interval.maxTime) # <--- Using minTime, maxTime
            stress_mark = phone_stress_assignments.get(interval_key, '')
            
            # Construct the final label
            interval.mark = recoded_label + stress_mark

        tg.write(output_tg_path) 

    except Exception as e:
        print(f"An unexpected error occurred during TG processing '{os.path.basename(input_tg_path)}': {e}", file=sys.stderr)
    finally:
        if temp_filepath and os.path.exists(temp_filepath):
            os.remove(temp_filepath)

# --- Audio Processing Function (unchanged) ---
def convert_or_copy_audio(input_audio_path, output_wav_path):
    base_name = os.path.basename(input_audio_path)
    output_base_name = os.path.basename(output_wav_path)

    if input_audio_path.lower().endswith(".mp3"):
        try:
            audio = AudioSegment.from_mp3(input_audio_path)
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
            return True
        except Exception as e:
            print(f"Error copying WAV '{base_name}': {e}. Skipping audio copy.", file=sys.stderr)
            return False
    else:
        print(f"Warning: Unsupported audio format for '{base_name}'. Skipping audio processing.", file=sys.stderr)
        return False

# --- Main Directory Processing Logic ---
base_corpus_path = "C:\\Users\\profk\\Documents\\GitHub\\phonology-chuvash\\extract-vox"
input_dir = os.path.join(base_corpus_path, "to_process") # Adjusted for your test setup
output_recoded_tg_dir = os.path.join(base_corpus_path, "recoded_textgrids") # Adjusted for your test setup
output_converted_audio_dir = os.path.join(base_corpus_path, "converted_audio") # Adjusted for your test setup

os.makedirs(output_recoded_tg_dir, exist_ok=True)
os.makedirs(output_converted_audio_dir, exist_ok=True)

print(f"Starting preparation process for files in: {input_dir}")
print(f"Recoded TextGrids will be saved to: {output_recoded_tg_dir}")
print(f"Converted/Copied audio will be saved to: {output_converted_audio_dir}")

processed_tgs_count = 0
processed_audio_count = 0
all_basenames = set()

for filename in os.listdir(input_dir):
    name, ext = os.path.splitext(filename)
    # Skip hidden directories like '.ipynb_checkpoints' or '__pycache__'
    if name.startswith('.') or name.startswith('__'):
        continue
    if ext.lower() in [".textgrid", ".mp3", ".wav"]:
        all_basenames.add(name)

print(f"\nFound {len(all_basenames)} unique base names to process.")

print("\n--- Processing TextGrid files ---")
for base_name in sorted(list(all_basenames)):
    input_tg_path = os.path.join(input_dir, f"{base_name}.TextGrid")
    output_tg_path = os.path.join(output_recoded_tg_dir, f"{base_name}_arpabet.TextGrid")

    # --- NEW: Check if recoded TextGrid already exists ---
    if os.path.exists(output_tg_path):
        print(f"Skipping TextGrid '{base_name}.TextGrid': Recoded TextGrid already exists at '{os.path.basename(output_tg_path)}'.")
        processed_tgs_count += 1 # Count it as 'processed' as it's already done
        continue # Skip to the next basename

    if not os.path.exists(input_tg_path):
        print(f"Warning: No TextGrid found for '{base_name}'. Skipping TextGrid recoding.", file=sys.stderr)
        continue

    process_single_textgrid(input_tg_path, output_tg_path, ipa_to_arpabet_map)
    processed_tgs_count += 1

print(f"\nFinished recoding {processed_tgs_count} TextGrids.")
print(f"Recoded TextGrids are in: {output_recoded_tg_dir}")

print("\n--- Processing Audio files (MP3 to WAV conversion / WAV copy) ---")
for base_name in sorted(list(all_basenames)):
    original_mp3_path = os.path.join(input_dir, f"{base_name}.mp3")
    original_wav_path = os.path.join(input_dir, f"{base_name}.wav")
    
    target_output_wav_path = os.path.join(output_converted_audio_dir, f"{base_name}.wav")
    
    # --- EXISTING & ENHANCED: Check if converted WAV already exists ---
    if os.path.exists(target_output_wav_path):
        print(f"Skipping audio for '{base_name}': Prepared WAV already exists at '{os.path.basename(target_output_wav_path)}'.")
        processed_audio_count += 1 # Count it as 'processed' as it's already done
        continue # Skip to the next basename

    if os.path.exists(original_mp3_path):
        if convert_or_copy_audio(original_mp3_path, target_output_wav_path):
            processed_audio_count += 1
    elif os.path.exists(original_wav_path):
        if convert_or_copy_audio(original_wav_path, target_output_wav_path):
            processed_audio_count += 1
    else:
        print(f"Warning: No MP3 or WAV audio found for base name '{base_name}'. Skipping audio processing.", file=sys.stderr)

print(f"\nFinished audio preparation for {processed_audio_count} files.")
print("\nmanual_recode_directory.py script finished.")
print(f"Prepared WAVs are in: {output_converted_audio_dir}")