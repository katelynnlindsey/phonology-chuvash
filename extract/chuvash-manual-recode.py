import textgrid
import os
import codecs
import tempfile
from pydub import AudioSegment
import shutil
import sys

# DEBUG: Print path of loaded textgrid module
print(f"DEBUG: 'textgrid' module loaded from: {textgrid.__file__}")

ipa_to_arpabet_map = {
    'ʌ': 'AH', 'ɑ': 'AA', 'u': 'UW', 'y': 'UX', 'ɛ': 'EH', 'e': 'EY', 'o': 'OW', 'i': 'IY', 'ɯ': 'IX',
    'sil': 'SIL', 'v': 'V', 'j': 'J', 'n': 'N', 'ʃ': 'SH', 'p': 'P', 'k': 'K', 'm': 'M', 'r': 'R',
    's': 'S', 't': 'T', 'd': 'D', 'l': 'L', 'z': 'Z', 'ŋ': 'NG', 'ð': 'DH', 'θ': 'TH', 'f': 'F',
    'w': 'W', 'h': 'HH', 'ʔ': 'Q', 'b': 'B', 'g': 'G', 'd͡ʒ': 'JH', 't͡ʃ': 'CH', 'ʒ': 'ZH', 'ɾ': 'DX',
}

STRONG_VOWELS_IPA = {'ɑ', 'u', 'y', 'e', 'o', 'i', 'ɯ'}
WEAK_VOWELS_IPA = {'ʌ', 'ɛ'}
ALL_VOWELS_IPA = STRONG_VOWELS_IPA.union(WEAK_VOWELS_IPA)

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

        if not isinstance(phones_tier, textgrid.IntervalTier):
            print(f"Warning: 'phones' tier in '{os.path.basename(input_tg_path)}' is not an IntervalTier ({type(phones_tier).__name__}). Skipping interval-based stress assignment. Only direct label recoding will occur.", file=sys.stderr)
            for interval in phones_tier:
                original_label = interval.mark.strip()
                recoded_label = mapping.get(original_label.lower(), original_label)
                interval.mark = recoded_label
            tg.write(output_tg_path)
            return

        phone_stress_assignments = {}
        for p_interval in phones_tier.intervals:
            original_label_ipa = p_interval.mark.strip().lower()
            interval_key = (p_interval.minTime, p_interval.maxTime)
            if original_label_ipa in ALL_VOWELS_IPA:
                phone_stress_assignments[interval_key] = '0'
            else:
                phone_stress_assignments[interval_key] = ''

        if not words_tier or not isinstance(words_tier, textgrid.IntervalTier):
            print(f"Warning: 'words' tier in '{os.path.basename(input_tg_path)}' not found or not an IntervalTier ({type(words_tier).__name__ if words_tier else 'None'}). Cannot assign word-level stress. Phones will only be ARPAbet (vowels default to 0 stress).", file=sys.stderr)
        else:
            for w_interval in words_tier.intervals:
                word_vowel_intervals = []
                for p_interval in phones_tier.intervals:
                    if p_interval.minTime >= w_interval.minTime and p_interval.maxTime <= w_interval.maxTime:
                        original_label_ipa = p_interval.mark.strip().lower()
                        if original_label_ipa in ALL_VOWELS_IPA:
                            word_vowel_intervals.append(p_interval)
                if not word_vowel_intervals:
                    continue
                strong_vowels_in_word = [v for v in word_vowel_intervals if v.mark.strip().lower() in STRONG_VOWELS_IPA]
                weak_vowels_in_word = [v for v in word_vowel_intervals if v.mark.strip().lower() in WEAK_VOWELS_IPA]
                if strong_vowels_in_word:
                    rightmost_strong_vowel = max(strong_vowels_in_word, key=lambda i: i.maxTime)
                    phone_stress_assignments[(rightmost_strong_vowel.minTime, rightmost_strong_vowel.maxTime)] = '1'
                elif weak_vowels_in_word:
                    leftmost_weak_vowel = min(weak_vowels_in_word, key=lambda i: i.minTime)
                    phone_stress_assignments[(leftmost_weak_vowel.minTime, leftmost_weak_vowel.maxTime)] = '2'

        for interval in phones_tier.intervals:
            original_label = interval.mark.strip()
            recoded_label = mapping.get(original_label.lower(), original_label)
            interval_key = (interval.minTime, interval.maxTime)
            stress_mark = phone_stress_assignments.get(interval_key, '')
            interval.mark = recoded_label + stress_mark

        tg.write(output_tg_path)

    except Exception as e:
        print(f"An unexpected error occurred during TG processing '{os.path.basename(input_tg_path)}': {e}", file=sys.stderr)
    finally:
        if temp_filepath and os.path.exists(temp_filepath):
            os.remove(temp_filepath)

def convert_or_copy_audio(input_audio_path, output_wav_path):
    base_name = os.path.basename(input_audio_path)
    output_base_name = os.path.basename(output_wav_path)

    if input_audio_path.lower().endswith(".mp3"):
        try:
            audio = AudioSegment.from_mp3(input_audio_path)
            audio = audio.set_frame_rate(16000).set_channels(1).set_sample_width(2)
            audio.export(output_wav_path, format='wav')
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

# --- Main Directory Processing for both corpora ---
base_corpus_path = r"C:\Users\profk\Documents\GitHub\phonology-chuvash\extract"
corpora = ["mfa", "vox"]

for corpus in corpora:
    corpus_dir = os.path.join(base_corpus_path, corpus)
    input_dir = os.path.join(corpus_dir, "to_process")
    output_recoded_tg_dir = os.path.join(corpus_dir, "recoded_textgrids")
    output_converted_audio_dir = os.path.join(corpus_dir, "converted_audio")

    os.makedirs(output_recoded_tg_dir, exist_ok=True)
    os.makedirs(output_converted_audio_dir, exist_ok=True)

    print(f"\nStarting preparation for corpus '{corpus}' in: {input_dir}")
    print(f"Recoded TextGrids will be saved to: {output_recoded_tg_dir}")
    print(f"Converted/Copied audio will be saved to: {output_converted_audio_dir}")

    processed_tgs_count = 0
    processed_audio_count = 0
    all_basenames = set()

    if not os.path.isdir(input_dir):
        print(f"Warning: input directory '{input_dir}' does not exist. Skipping corpus '{corpus}'.", file=sys.stderr)
        continue

    for filename in os.listdir(input_dir):
        name, ext = os.path.splitext(filename)
        if name.startswith('.') or name.startswith('__'):
            continue
        if ext.lower() in [".textgrid", ".mp3", ".wav"]:
            all_basenames.add(name)

    print(f"Found {len(all_basenames)} unique base names to process in corpus '{corpus}'.")

    for base_name in sorted(list(all_basenames)):
        input_tg_path = os.path.join(input_dir, f"{base_name}.TextGrid")
        output_tg_path = os.path.join(output_recoded_tg_dir, f"{base_name}_arpabet.TextGrid")
        if os.path.exists(output_tg_path):
            print(f"Skipping TextGrid '{base_name}.TextGrid': Recoded TextGrid already exists at '{os.path.basename(output_tg_path)}'.")
            processed_tgs_count += 1
        else:
            if not os.path.exists(input_tg_path):
                print(f"Warning: No TextGrid found for '{base_name}'. Skipping TextGrid recoding.", file=sys.stderr)
            else:
                process_single_textgrid(input_tg_path, output_tg_path, ipa_to_arpabet_map)
                processed_tgs_count += 1

    print(f"Finished recoding {processed_tgs_count} TextGrids for corpus '{corpus}'.")

    for base_name in sorted(list(all_basenames)):
        original_mp3_path = os.path.join(input_dir, f"{base_name}.mp3")
        original_wav_path = os.path.join(input_dir, f"{base_name}.wav")
        target_output_wav_path = os.path.join(output_converted_audio_dir, f"{base_name}.wav")

        if os.path.exists(target_output_wav_path):
            print(f"Skipping audio for '{base_name}': Prepared WAV already exists at '{os.path.basename(target_output_wav_path)}'.")
            processed_audio_count += 1
            continue

        if os.path.exists(original_mp3_path):
            if convert_or_copy_audio(original_mp3_path, target_output_wav_path):
                processed_audio_count += 1
        elif os.path.exists(original_wav_path):
            if convert_or_copy_audio(original_wav_path, target_output_wav_path):
                processed_audio_count += 1
        else:
            print(f"Warning: No MP3 or WAV audio found for base name '{base_name}'. Skipping audio processing.", file=sys.stderr)

    print(f"Finished audio preparation for {processed_audio_count} files in corpus '{corpus}'.")
    print(f"Prepared WAVs are in: {output_converted_audio_dir}")

print("\nmanual_recode_directory.py script finished.")