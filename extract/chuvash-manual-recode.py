# -*- coding: utf-8 -*-
import re
import textgrid
import os
import codecs
import tempfile
import shutil
import sys
from pydub import AudioSegment

# DEBUG: Print path of loaded textgrid module
# print(f"DEBUG: 'textgrid' module loaded from: {textgrid.__file__}", file=sys.stderr)

# --- 1. Vowel and Consonant Definitions (IPA to ARPAbet mapping is here) ---
# IMPORTANT: These IPA keys must EXACTLY match the IPA symbols in your input TextGrids.
# The values are ARPAbet for the output.
ipa_to_arpabet_map = {
    'ʌ': 'AH', 'ɑ': 'AA', 'u': 'UW', 'y': 'UX', 'ɛ': 'EH', 'e': 'EY', 'o': 'OW', 'i': 'IY', 'ɯ': 'IX',
    'sil': 'SIL', '<eps>': 'SIL', # Add <eps> for silence/empty intervals from MFA output
    'v': 'V', 'j': 'J', 'n': 'N', 'ʃ': 'SH', 'p': 'P', 'k': 'K', 'm': 'M', 'r': 'R',
    's': 'S', 't': 'T', 'd': 'D', 'l': 'L', 'z': 'Z', 'ŋ': 'NG', 'ð': 'DH', 'θ': 'TH', 'f': 'F',
    'w': 'W', 'h': 'HH', 'ʔ': 'Q', 'b': 'B', 'g': 'G', 'd͡ʒ': 'JH', 't͡ʃ': 'CH', 'ʒ': 'ZH', 'ɾ': 'DX',
    'tː': 'T', # Assuming geminates map to base consonant, adjust if needed
    'lː': 'L',
    'pː': 'P',
    'mː': 'M',
    'nː': 'N',
    'rː': 'R',
    'sː': 'S',
    'kː': 'K',
    'χ': 'HH' # Assuming your χ is mapped to HH, adjust if different
}

# Define strong/weak vowels using their *IPA symbols* as they appear in the input TextGrid 'phones' tier.
# This must be consistent with the *keys* in ipa_to_arpabet_map for vowels.
STRONG_VOWELS_IPA = {'ɑ', 'u', 'y', 'e', 'o', 'i', 'ɯ'}
WEAK_VOWELS_IPA = {'ʌ', 'ɛ'} # Based on your input: AH and EH are weak.
ALL_VOWELS_IPA = STRONG_VOWELS_IPA.union(WEAK_VOWELS_IPA)

# token-based consonant/vowel classes
VOWEL_TOKENS = ALL_VOWELS_IPA
CONSONANT_TOKENS = set([k for k in ipa_to_arpabet_map.keys() if k not in VOWEL_TOKENS and k not in ['sil', '<eps>']])


# Helper: get phone intervals wholly within a word interval, excluding silence/eps
def phones_within_interval(phones_tier, wmin, wmax):
    phones = []
    for p in phones_tier.intervals:
        phone_mark = p.mark.strip().lower()
        if phone_mark in ['sil', '<eps>']: # Skip explicit silence/epsilon phones
            continue
        if p.minTime >= wmin and p.maxTime <= wmax:
            phones.append(p)
    return phones


# Main processing function per TextGrid
def process_single_textgrid(input_tg_path, output_tg_path, mapping):
    temp_filepath = None
    try:
        # Robustly read TextGrid, handling encoding issues
        content = None
        encodings_to_try = ['utf-8', 'latin-1', 'cp1252', 'iso-8859-1']
        for enc in encodings_to_try:
            try:
                with codecs.open(input_tg_path, 'r', encoding=enc) as f:
                    content = f.read()
                    # Basic check for TextGrid format presence
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
        
        if not words_tier or not isinstance(words_tier, textgrid.IntervalTier):
            print(f"Warning: 'words' tier in '{os.path.basename(input_tg_path)}' not found or not an IntervalTier. Only basic recoding to ARPAbet will occur for 'phones' tier.", file=sys.stderr)
            # Perform basic recoding to ARPAbet for phones tier
            for interval in phones_tier.intervals:
                original_label = interval.mark.strip().lower()
                recoded_label = mapping.get(original_label, original_label)
                interval.mark = recoded_label
            tg.write(output_tg_path)
            return

        # --- Main Logic for Word-Level Processing (Syllable and Stress Annotation) ---
        for w_interval in words_tier.intervals:
            word_text_lower = w_interval.mark.strip().lower()
            # Skip empty or non-linguistic word intervals
            if word_text_lower in ['', 'sil', '<eps>']:
                w_interval.mark = mapping.get(word_text_lower, word_text_lower).upper() # Recode word tier itself
                continue 

            # Get phones strictly within this word interval, skipping silence/eps
            pintervals_in_word = phones_within_interval(phones_tier, w_interval.minTime, w_interval.maxTime)
            if not pintervals_in_word:
                # print(f"DEBUG: No linguistic phones found for word '{w_interval.mark}'", file=sys.stderr)
                w_interval.mark = mapping.get(word_text_lower, word_text_lower).upper() # Ensure words tier is ARPAbet
                continue
            
            # --- Syllable Identification (Each vowel is a syllable nucleus) ---
            vowel_syllable_info = [] # Stores dicts for each identified vowel-based syllable
            
            current_sidx = 0
            for p_idx, p_interval in enumerate(pintervals_in_word):
                phone_ipa = p_interval.mark.strip().lower()
                if phone_ipa in ALL_VOWELS_IPA:
                    current_sidx += 1 # 1-based syllable index
                    
                    # Determine oc_status: look at phones *following* this vowel
                    oc_determining_consonants_count = 0
                    look_ahead_idx = p_idx + 1
                    while look_ahead_idx < len(pintervals_in_word):
                        next_phone_ipa = pintervals_in_word[look_ahead_idx].mark.strip().lower()
                        if next_phone_ipa in ALL_VOWELS_IPA: # Next vowel starts new syllable
                            break 
                        elif next_phone_ipa in CONSONANT_TOKENS:
                            oc_determining_consonants_count += 1
                        look_ahead_idx += 1
                    
                    oc_status = 'open' # Default
                    # oc_status = 'closed' if (oc_determining_consonants_count >= 2) or \
                    #                            (oc_determining_consonants_count == 1 and look_ahead_idx == len(pintervals_in_word)) else 'open'
                    # Per your rule: "vowel preceding two consonants or a consonant and the end of the word will be oc=closed and a vowel preceding one consonant will be oc=open"
                    # This implies:
                    # - V CC -> closed
                    # - V C# -> closed
                    # - V C V -> open (C is onset of next syllable)
                    # - V # -> open
                    if oc_determining_consonants_count >= 2: # VCC
                        oc_status = 'closed'
                    elif oc_determining_consonants_count == 1 and look_ahead_idx == len(pintervals_in_word): # V C # (word final consonant)
                        oc_status = 'closed'
                    elif oc_determining_consonants_count == 1: # V C V (C is onset of next syllable)
                        oc_status = 'open' # This is the original meaning of open for VC
                    # If oc_determining_consonants_count == 0, it's V#, which is also open by this def
                    
                    vowel_syllable_info.append({
                        'sidx': current_sidx,
                        'phone_interval_obj': p_interval, # Store the actual interval object
                        'ipa': phone_ipa,
                        'arpabet': mapping.get(phone_ipa, phone_ipa),
                        'is_strong': phone_ipa in STRONG_VOWELS_IPA,
                        'oc_status': oc_status
                    })
            
            total_syllables_in_word = current_sidx # Total count of vowel-based syllables

            # --- Stress Assignment Logic ("Rightmost strong, else leftmost weak") ---
            stressed_syl_sidx = None # This will store the 1-based index of the stressed syllable
            
            strong_syl_sidx_candidates = sorted([v['sidx'] for v in vowel_syllable_info if v['is_strong']])
            weak_syl_sidx_candidates = sorted([v['sidx'] for v in vowel_syllable_info if not v['is_strong']])
            
            if strong_syl_sidx_candidates:
                stressed_syl_sidx = max(strong_syl_sidx_candidates) # Rightmost strong vowel's syllable
            elif weak_syl_sidx_candidates:
                stressed_syl_sidx = min(weak_syl_sidx_candidates) # Leftmost weak vowel's syllable (only if no strong)
            
            # --- Update `phones` tier and prepare `words` tier string ---
            word_arpabet_syllable_parts = [] # Collects ARPAbet phones+stress, then joined by '.' for words tier
            
            last_vowel_sidx = 0 # To group consonants with their following vowel's syllable
            
            for p_idx, p_interval in enumerate(pintervals_in_word):
                phone_ipa = p_interval.mark.strip().lower()
                recoded_arpabet_label = mapping.get(phone_ipa, phone_ipa)
                
                # Update phone interval mark
                if phone_ipa in ALL_VOWELS_IPA: # It's a vowel
                    v_info = next((v for v in vowel_syllable_info if v['phone_interval_obj'] == p_interval), None)
                    if v_info:
                        phone_stress_digit = '1' if v_info['sidx'] == stressed_syl_sidx else '0'
                        
                        # Determine current syllable position for attrs
                        current_syl_pos_attr = 'med'
                        if total_syllables_in_word == 1:
                            current_syl_pos_attr = 'initial' # Single syllable word
                        elif v_info['sidx'] == 1:
                            current_syl_pos_attr = 'initial'
                        elif v_info['sidx'] == total_syllables_in_word:
                            current_syl_pos_attr = 'final'
                        
                        p_interval.mark = f"{recoded_arpabet_label}{phone_stress_digit} [sidx={v_info['sidx']}/sN={total_syllables_in_word}/pos={current_syl_pos_attr}/oc={v_info['oc_status']}]"
                        last_vowel_sidx = v_info['sidx'] # Mark that we just processed a vowel
                    else: # Fallback if vowel_info somehow missing (shouldn't happen for identified vowels)
                         p_interval.mark = recoded_arpabet_label + '0' # Default to unstressed if no info
                         last_vowel_sidx = 0 # Reset if we can't find its info
                else: # It's a consonant
                    p_interval.mark = recoded_arpabet_label # Consonants get only ARPAbet label
                
                # For building the `words` tier string, we need to group phones into syllables
                # Simple rule: Consonants attach to the *following* vowel's syllable.
                # The first vowel starts the first syllable.
                
                if not word_arpabet_syllable_parts: # If this is the very first phone to add
                    word_arpabet_syllable_parts.append([recoded_arpabet_label])
                else:
                    # If this phone is a vowel, start a new syllable string entry
                    if phone_ipa in ALL_VOWELS_IPA:
                         word_arpabet_syllable_parts.append([recoded_arpabet_label])
                    # If this phone is a consonant, attach it to the LAST syllable string (the one with the previous vowel)
                    else:
                        word_arpabet_syllable_parts[-1].append(recoded_arpabet_label)
                        

            # --- Construct Final `words` Tier Mark ---
            word_display_str = ''
            if word_arpabet_syllable_parts:
                # Now, join the inner lists into syllable strings, handling the stress apostrophe
                final_syllable_strings = []
                for s_idx, syl_parts in enumerate(word_arpabet_syllable_parts):
                    syl_str = ''.join(syl_parts)
                    # The s_idx here is 0-based, corresponding to the 1-based stressed_syl_sidx
                    if stressed_syl_sidx is not None and (s_idx + 1) == stressed_syl_sidx:
                        # Find the first vowel in the syllable string to place apostrophe correctly
                        vowel_match = re.search(r'([A-Z]+[01])', syl_str) # Matches ARPAbet vowel + stress digit
                        if vowel_match:
                            syl_str = syl_str[:vowel_match.start()] + "'" + syl_str[vowel_match.start():]
                        else: # Fallback if no clear vowel found (shouldn't happen)
                            syl_str = "'" + syl_str # Just put at beginning
                    final_syllable_strings.append(syl_str)
                word_display_str = '.'.join(final_syllable_strings)
            else: # Fallback if no syllables were identified, keep original recoded word
                word_display_str = mapping.get(w_interval.mark.strip().lower(), w_interval.mark.strip().lower()).upper()


            w_interval.mark = word_display_str


        # --- Final cleanup for phones tier (for any phones not part of a word interval, like leading/trailing SIL) ---
        for interval in phones_tier.intervals:
            mark_lower = interval.mark.strip().lower()
            # If it's a raw IPA label that hasn't been processed into [sidx=...] format
            if '[' not in mark_lower and mark_lower in mapping: 
                interval.mark = mapping.get(mark_lower, mark_lower) # Just recode to ARPAbet
            elif '[' not in mark_lower and mark_lower in ALL_VOWELS_IPA: # Unprocessed vowel outside word intervals
                 interval.mark = mapping.get(mark_lower, mark_lower) + '0' # Default to unstressed 0
            elif mark_lower in ['sil', '<eps>']: # Ensure silence/eps intervals are correctly ARPAbet'd if they weren't skipped
                 interval.mark = mapping.get(mark_lower, mark_lower).upper()


        tg.write(output_tg_path)

    except Exception as e:
        print(f"An unexpected error occurred during TG processing '{os.path.basename(input_tg_path)}': {e}", file=sys.stderr)
        import traceback
        traceback.print_exc(file=sys.stderr)
    finally:
        if temp_filepath and os.path.exists(temp_filepath):
            os.remove(temp_filepath)

# --- Audio Conversion Utility (No Change) ---
def convert_or_copy_audio(input_audio_path, output_wav_path):
    base_name = os.path.basename(input_audio_path)
    output_base_name = os.path.basename(output_wav_path)

    if input_audio_path.lower().endswith(".mp3"):
        try:
            audio = AudioSegment.from_mp3(input_audio_path)
            audio = audio.set_frame_rate(16000).set_channels(1).set_sample_width(2)
            audio.export(output_wav_path, format='wav')
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

# --- Main Directory Processing for both corpora (No Change) ---
base_corpus_path = r"C:\Users\profk\Documents\GitHub\phonology-chuvash\extract"
corpora = ["mfa", "vox"] # Assuming 'mfa' is your Chuvash Voice and 'vox' is Common Voice

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
        if ext.lower() in [".textgrid", ".mp3", ".wav", ".TextGrid"]:
            all_basenames.add(name)

    print(f"Found {len(all_basenames)} unique base names to process in corpus '{corpus}'.")

    for base_name in sorted(list(all_basenames)):
        input_tg_path = os.path.join(input_dir, f"{base_name}.TextGrid")
        if not os.path.exists(input_tg_path): # Check for lowercase .textgrid if .TextGrid not found
            input_tg_path = os.path.join(input_dir, f"{base_name}.textgrid")
        output_tg_path = os.path.join(output_recoded_tg_dir, f"{base_name}_arpabet.TextGrid")
        
        # Check if output TG already exists and input TG exists
        if os.path.exists(output_tg_path):
            print(f"Skipping TextGrid '{base_name}': Recoded TextGrid already exists at '{os.path.basename(output_tg_path)}'.")
            processed_tgs_count += 1
        elif not os.path.exists(input_tg_path):
            print(f"Warning: No TextGrid found for '{base_name}'. Skipping TextGrid recoding.", file=sys.stderr)
        else:
            print(f"Processing TextGrid '{base_name}'...", file=sys.stderr)
            process_single_textgrid(input_tg_path, output_tg_path, ipa_to_arpabet_map)
            processed_tgs_count += 1

    print(f"Finished recoding {processed_tgs_count} TextGrids for corpus '{corpus}'.")

    # Audio processing remains largely the same
    for base_name in sorted(list(all_basenames)):
        original_mp3_path = os.path.join(input_dir, f"{base_name}.mp3")
        original_wav_path = os.path.join(input_dir, f"{base_name}.wav")
        target_output_wav_path = os.path.join(output_converted_audio_dir, f"{base_name}.wav")

        if os.path.exists(target_output_wav_path):
            # print(f"Skipping audio for '{base_name}': Prepared WAV already exists at '{os.path.basename(target_output_wav_path)}'.")
            processed_audio_count += 1
            continue

        if os.path.exists(original_mp3_path):
            if convert_or_copy_audio(original_mp3_path, target_output_wav_path):
                processed_audio_count += 1
        elif os.path.exists(original_wav_path):
            if convert_or_copy_audio(original_wav_path, target_output_wav_path):
                processed_audio_count += 1
        else:
            # print(f"Warning: No MP3 or WAV audio found for base name '{base_name}'. Skipping audio processing.", file=sys.stderr)
            pass # Suppress warning for missing audio if it's expected in some cases

    print(f"Finished audio preparation for {processed_audio_count} files in corpus '{corpus}'.")
    print(f"Prepared WAVs are in: {output_converted_audio_dir}")

print("\nmanual_recode_directory.py script finished.")