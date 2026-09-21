# -*- coding: utf-8 -*-
"""
convert_audio.py  —  CONVERT stage
Converts MP3 files to 16 kHz mono 16-bit WAV (required by MFA and new-fave).
WAV files are copied unchanged.

Run this BEFORE forced alignment.

Input:   <corpus>/to_process/*.mp3  or  *.wav
Output:  <corpus>/converted_audio/*.wav

Usage:
    python convert_mp3_wav.py
"""

import os
import sys
import shutil
from pydub import AudioSegment

# ── Configuration — edit these paths ─────────────────────────────────────────
BASE_CORPUS_PATH = r"C:\Users\profk\Documents\GitHub\phonology-chuvash\1-raw_data"
CORPORA = ["common_voice_chuvash", "chuvash_voice"]


def convert_or_copy_audio(input_path: str, output_path: str) -> bool:
    """
    Convert MP3 → 16 kHz mono 16-bit WAV, or copy WAV unchanged.
    Returns True on success.
    """
    name = os.path.basename(input_path)

    if input_path.lower().endswith(".mp3"):
        try:
            audio = (AudioSegment.from_mp3(input_path)
                     .set_frame_rate(16000)
                     .set_channels(1)
                     .set_sample_width(2))
            audio.export(output_path, format='wav')
            return True
        except Exception as e:
            print(f"Error converting '{name}': {e}", file=sys.stderr)
            return False

    elif input_path.lower().endswith(".wav"):
        try:
            shutil.copy(input_path, output_path)
            return True
        except Exception as e:
            print(f"Error copying '{name}': {e}", file=sys.stderr)
            return False

    else:
        print(f"Warning: unsupported format for '{name}'. Skipping.", file=sys.stderr)
        return False


def process_corpus(corpus_dir: str) -> None:
    input_dir  = os.path.join(corpus_dir, "to_process")
    output_dir = os.path.join(corpus_dir, "converted_audio")
    os.makedirs(output_dir, exist_ok=True)

    if not os.path.isdir(input_dir):
        print(f"Warning: '{input_dir}' not found. Skipping.", file=sys.stderr)
        return

    basenames = {
        os.path.splitext(f)[0]
        for f in os.listdir(input_dir)
        if os.path.splitext(f)[1].lower() in ('.mp3', '.wav')
        and not f.startswith(('.', '__'))
    }
    print(f"  Found {len(basenames)} audio files.")

    done = 0
    for base in sorted(basenames):
        out = os.path.join(output_dir, f"{base}.wav")
        if os.path.exists(out):
            done += 1
            continue
        for ext in ('.mp3', '.wav'):
            src = os.path.join(input_dir, f"{base}{ext}")
            if os.path.exists(src):
                if convert_or_copy_audio(src, out):
                    done += 1
                break

    print(f"  Audio ready: {done} files → '{output_dir}'")


if __name__ == "__main__":
    for corpus in CORPORA:
        print(f"\n── Corpus: {corpus} ──")
        process_corpus(os.path.join(BASE_CORPUS_PATH, corpus))
    print("\nconvert_mp3_wav.py finished.")