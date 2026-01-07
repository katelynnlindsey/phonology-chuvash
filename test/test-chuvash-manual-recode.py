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

# token-based consonant/vowel classes for syllabification decisions
VOWEL_TOKENS = ALL_VOWELS_IPA
CONSONANT_TOKENS = set([k for k in ipa_to_arpabet_map.keys() if k not in VOWEL_TOKENS and k != 'sil'])

# helper: get phone intervals wholly within a word interval
def phones_within_interval(phones_tier, wmin, wmax):
    phones = []
    for p in phones_tier.intervals:
        if p.minTime >= wmin and p.maxTime <= wmax:
            phones.append(p)
    return phones

# helper: build a list of token strings from phone intervals
def phone_tokens_from_intervals(intervals):
    tokens = [iv.mark.strip().lower() for iv in intervals]
    return tokens

# token-level partitioning adapted from your create_partitions
def create_partitions_tokens(token_list, left_env_pred, right_env_pred):
    results = []
    L = len(token_list)
    if L == 0:
        return [[]]
    any_match = False
    for cut in range(1, L):
        if left_env_pred(token_list[:cut]) and right_env_pred(token_list[cut:]):
            any_match = True
            break
    if not any_match:
        return [token_list]
    for i in range(1, L):
        Lpart = token_list[:i]
        Rpart = token_list[i:]
        if left_env_pred(Lpart) and right_env_pred(Rpart):
            results.append(Lpart)
            rest = create_partitions_tokens(Rpart, left_env_pred, right_env_pred)
            results += rest
            break
    return results

# small predicate helpers
def ends_with_vowel(tokens):
    return len(tokens) > 0 and tokens[-1] in VOWEL_TOKENS

def starts_with_vowel(tokens):
    return len(tokens) > 0 and tokens[0] in VOWEL_TOKENS

# main processing per TextGrid (enhanced with syllabification & annotation)
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

        # First pass: default stress assignment for vowels (0) and recode mapping later
        phone_stress_assignments = {}
        for p_interval in phones_tier.intervals:
            original_label_ipa = p_interval.mark.strip().lower()
            interval_key = (p_interval.minTime, p_interval.maxTime)
            if original_label_ipa in ALL_VOWELS_IPA:
                phone_stress_assignments[interval_key] = '0'
            else:
                phone_stress_assignments[interval_key] = ''

        # If words tier exists, syllabify and set stress
        if not words_tier or not isinstance(words_tier, textgrid.IntervalTier):
            print(f"Warning: 'words' tier in '{os.path.basename(input_tg_path)}' not found or not an IntervalTier ({type(words_tier).__name__ if words_tier else 'None'}). Cannot assign word-level stress or syllabification. Phones will only be ARPAbet (vowels default to 0 stress).", file=sys.stderr)
        else:
            for w_interval in words_tier.intervals:
                pintervals = phones_within_interval(phones_tier, w_interval.minTime, w_interval.maxTime)
                if not pintervals:
                    continue
                tokens = phone_tokens_from_intervals(pintervals)

                # apply partition passes (heuristic adaptation of your string-based rules)
                chunks = [tokens]

                def apply_pass(chunks, left_pred, right_pred):
                    newchunks = []
                    for ch in chunks:
                        parts = create_partitions_tokens(ch, left_pred, right_pred)
                        newchunks.extend(parts)
                    return newchunks

                # 1) vowel-vowel boundary
                chunks = apply_pass(chunks, lambda t: ends_with_vowel(t), lambda t: starts_with_vowel(t))
                # 2) two consonants before a consonant
                chunks = apply_pass(chunks, lambda t: len(t) >= 2 and t[-2] in CONSONANT_TOKENS and t[-1] in CONSONANT_TOKENS, lambda t: len(t) > 0 and t[0] in CONSONANT_TOKENS)
                # 3) consonant | consonant+vowel
                chunks = apply_pass(chunks, lambda t: len(t) > 0 and t[-1] in CONSONANT_TOKENS, lambda t: len(t) >= 2 and t[0] in CONSONANT_TOKENS and t[1] in VOWEL_TOKENS)
                # 4) vowel | consonant+vowel
                chunks = apply_pass(chunks, lambda t: ends_with_vowel(t), lambda t: len(t) >= 2 and t[0] in CONSONANT_TOKENS and t[1] in VOWEL_TOKENS)

                # map chunks back to original phone-interval objects
                syllable_intervals = []
                idx = 0
                for syl_tokens in chunks:
                    syl_len = len(syl_tokens)
                    syl_pints = pintervals[idx: idx + syl_len]
                    syllable_intervals.append(syl_pints)
                    idx += syl_len

                # determine stressed syllable using your strong/weak vowel rules
                syl_with_strong = []
                syl_with_weak = []
                for s_idx, syl in enumerate(syllable_intervals):
                    if any(iv.mark.strip().lower() in STRONG_VOWELS_IPA for iv in syl):
                        syl_with_strong.append((s_idx, syl))
                    elif any(iv.mark.strip().lower() in WEAK_VOWELS_IPA for iv in syl):
                        syl_with_weak.append((s_idx, syl))

                stressed_syl_index = None
                if syl_with_strong:
                    stressed_syl_index = max(idx for idx, _ in syl_with_strong)
                elif syl_with_weak:
                    stressed_syl_index = min(idx for idx, _ in syl_with_weak)

                total_sylls = len(syllable_intervals)
                for sidx, syl in enumerate(syllable_intervals):
                    for i, iv in enumerate(syl):
                        tok = iv.mark.strip()
                        tok_l = tok.lower()
                        is_vowel = tok_l in ALL_VOWELS_IPA
                        syl_pos = 'med'
                        if sidx == 0:
                            syl_pos = 'initial'
                        elif sidx == total_sylls - 1:
                            syl_pos = 'final'
                        syl_is_open = False
                        if len(syl) > 0 and syl[-1].mark.strip().lower() in ALL_VOWELS_IPA:
                            syl_is_open = True
                        open_closed = 'open' if syl_is_open else 'closed'
                        stress_digit = ''
                        if is_vowel:
                            key = (iv.minTime, iv.maxTime)
                            if stressed_syl_index is not None and sidx == stressed_syl_index:
                                stress_digit = '1'
                            else:
                                stress_digit = phone_stress_assignments.get((iv.minTime, iv.maxTime), '0')
                        else:
                            stress_digit = ''
                        recoded_label = mapping.get(tok_l, tok)
                        new_label = recoded_label + (stress_digit if stress_digit else '')
                        attrs = f"[sidx={sidx+1}/sN={total_sylls}/pos={syl_pos}/oc={open_closed}]"
                        if is_vowel:
                            iv.mark = new_label + " " + attrs
                        else:
                            iv.mark = new_label

                # update word label with syllabified phone tokens and apostrophe on stressed syllable
                syll_strings = ['.'.join([t for t in syl]) for syl in chunks]
                if stressed_syl_index is None:
                    stressed_syl_index = 0
                syll_strings[stressed_syl_index] = "'" + syll_strings[stressed_syl_index]
                word_display = '.'.join(syll_strings)
                w_interval.mark = word_display

        # finalize recoding for any phones not annotated above
        for interval in phones_tier.intervals:
            mark = interval.mark.strip()
            if mark == '':
                continue
            if '[' in mark and 'sidx=' in mark:
                continue
            original_label = mark
            recoded_label = ipa_to_arpabet_map.get(original_label.lower(), original_label)
            if original_label.lower() in ALL_VOWELS_IPA:
                interval.mark = recoded_label + phone_stress_assignments.get((interval.minTime, interval.maxTime), '0')
            else:
                interval.mark = recoded_label

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
base_corpus_path = r"C:\Users\profk\Documents\GitHub\phonology-chuvash\test"
corpora = ["test-mfa", "test-vox"]

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
        if not os.path.exists(input_tg_path):
            input_tg_path = os.path.join(input_dir, f"{base_name}.textgrid")
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