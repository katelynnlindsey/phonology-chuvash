# chuvash-fave.py
# -*- coding: utf-8 -*-
import os
import sys
import concurrent.futures
from tqdm import tqdm

import pandas as pd
import re

# --- Directory Paths ---
base_corpus_path = r"C:\Users\profk\Documents\GitHub\phonology-chuvash\test"
corpora = ["test-mfa", "test-vox"]

# Regex to capture base label and optional bracketed attributes
ATTR_RE = re.compile(r'^(?P<label>[^\s\[]+)(?:\s*\[(?P<attrs>[^\]]+)\])?$')

def parse_label_attrs(lab):
    """
    Returns (label, attrs_dict) where label is like EH1 and attrs_dict contains keys like sidx,sN,pos,oc (if present).
    """
    if not isinstance(lab, str):
        return lab, {}
    m = ATTR_RE.match(lab.strip())
    if not m:
        return lab.strip(), {}
    base = m.group('label')
    attrs = {}
    attrs_text = m.group('attrs')
    if attrs_text:
        # attrs_text format: sidx=1/sN=2/pos=initial/oc=closed
        for part in attrs_text.split('/'):
            if '=' in part:
                k, v = part.split('=', 1)
                attrs[k] = v
    return base, attrs

def postprocess_points_csv(csv_path):
    """
    Read the CSV written by write_data(... which=['points'], separate=False), parse the 'label'
    column to extract bracketed attributes, and add columns:
      - label (base label, e.g. EH1)
      - sidx (int or NaN)
      - sN (int or NaN)
      - syl_pos (string or NaN)
      - syl_open_closed (string or NaN)
    Overwrites the original CSV.
    """
    try:
        df = pd.read_csv(csv_path)
    except Exception as e:
        print(f"Warning: failed to read {csv_path} for postprocessing: {e}", file=sys.stderr)
        return

    if 'label' not in df.columns:
        # nothing to do
        return

    bases = []
    sidxs = []
    sNs = []
    poss = []
    ocs = []
    for lab in df['label'].astype(str).tolist():
        base, attrs = parse_label_attrs(lab)
        bases.append(base)
        # sidx and sN might be numeric; attempt int conversion, else None
        sidx_val = attrs.get('sidx')
        try:
            sidxs.append(int(sidx_val) if sidx_val is not None and str(sidx_val).isdigit() else None)
        except Exception:
            sidxs.append(None)
        sN_val = attrs.get('sN') or attrs.get('SN')  # tolerate capitalization
        try:
            sNs.append(int(sN_val) if sN_val is not None and str(sN_val).isdigit() else None)
        except Exception:
            sNs.append(None)
        poss.append(attrs.get('pos'))
        ocs.append(attrs.get('oc'))

    # Replace label with base and add new columns
    df['label'] = bases
    df['sidx'] = sidxs
    df['sN'] = sNs
    df['syl_pos'] = poss
    df['syl_open_closed'] = ocs

    # Overwrite CSV (if you prefer writing a new file, change path)
    try:
        df.to_csv(csv_path, index=False)
    except Exception as e:
        print(f"Warning: failed to write postprocessed CSV to {csv_path}: {e}", file=sys.stderr)

# --- Function to process a single audio/TextGrid pair ---
def process_single_pair(args):
    # Import inside function helps on Windows when using ProcessPoolExecutor
    from new_fave import fave_audio_textgrid, write_data

    audio_path, recoded_tg_path, base_name, output_dir = args
    try:
        speakers_output = fave_audio_textgrid(
            audio_path=audio_path,
            textgrid_path=recoded_tg_path,
            speakers="all",
            labelset_parser="cmu_parser",
            point_heuristic="fave",
            ft_config="default"
        )

        if speakers_output is None:
            print(f"fave_audio_textgrid returned None for {base_name}; skipping", file=sys.stderr)
            return False

        write_data(
            speakers_output,
            destination=output_dir,
            which=["points"],
            separate=False
        )

        # Post-process the created points CSV to split label attributes into columns
        csv_path = os.path.join(output_dir, f"{base_name}_points.csv")
        if os.path.exists(csv_path):
            postprocess_points_csv(csv_path)
        else:
            print(f"Warning: expected points CSV '{os.path.basename(csv_path)}' not found after write_data.", file=sys.stderr)

        return True
    except Exception as e:
        print(f"Error processing '{base_name}': {e}. Skipping.", file=sys.stderr)
        return False

if __name__ == '__main__':
    for corpus in corpora:
        corpus_dir = os.path.join(base_corpus_path, corpus)
        audio_input_dir = os.path.join(corpus_dir, "converted_audio")
        textgrid_input_dir = os.path.join(corpus_dir, "recoded_textgrids")
        output_results_dir = os.path.join(corpus_dir, "fave_output")

        print(f"\nStarting fave-extract processing for corpus '{corpus}'")
        print(f"TextGrids in: {textgrid_input_dir}")
        print(f"Audio files from: {audio_input_dir}")
        print(f"Results will be saved to: {output_results_dir}")

        if not os.path.isdir(textgrid_input_dir):
            print(f"Warning: textgrid input dir '{textgrid_input_dir}' does not exist. Skipping corpus '{corpus}'.", file=sys.stderr)
            continue
        if not os.path.isdir(audio_input_dir):
            print(f"Warning: audio input dir '{audio_input_dir}' does not exist. Skipping corpus '{corpus}'.", file=sys.stderr)
            continue

        os.makedirs(output_results_dir, exist_ok=True)

        all_potential_files = []
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
            print(f"No valid audio-TextGrid pairs found for fave-extract in corpus '{corpus}'. Skipping.", file=sys.stderr)
            continue

        tasks_to_submit = []
        skipped_count = 0
        for audio_path, recoded_tg_path, base_name in all_potential_files:
            expected_output_file = os.path.join(output_results_dir, f"{base_name}_points.csv")
            if os.path.exists(expected_output_file):
                print(f"Skipping fave-extract for '{base_name}': Output '{os.path.basename(expected_output_file)}' already exists.")
                skipped_count += 1
            else:
                tasks_to_submit.append((audio_path, recoded_tg_path, base_name, output_results_dir))

        max_workers = os.cpu_count() or 1
        # Optionally reduce parallelism to avoid resource limits:
        max_workers = min(max_workers, 4)

        print(f"Found {len(all_potential_files)} audio-TextGrid pairs for consideration.")
        print(f"{skipped_count} files skipped because output already exists.")
        print(f"{len(tasks_to_submit)} files will be processed using {max_workers} parallel processes.")

        if not tasks_to_submit:
            print("No new files to process for this corpus.")
            continue

        successful_count = 0
        failures = []
        with concurrent.futures.ProcessPoolExecutor(max_workers=max_workers) as executor:
            results_iterator = tqdm(
                executor.map(process_single_pair, tasks_to_submit),
                total=len(tasks_to_submit),
                desc=f"Processing {corpus}"
            )
            for i, success in enumerate(results_iterator):
                if success:
                    successful_count += 1
                else:
                    # record failed base name for later report
                    failures.append(tasks_to_submit[i][2])

        print(f"Finished processing {successful_count} new audio-TextGrid pairs successfully for corpus '{corpus}'.")
        print(f"Total files now processed (new + skipped) for corpus '{corpus}': {successful_count + skipped_count}")
        print(f"All fave-extract results saved to: {output_results_dir}")
        if failures:
            print(f"Failed files for corpus '{corpus}': {len(failures)}. Example failures: {failures[:10]}", file=sys.stderr)