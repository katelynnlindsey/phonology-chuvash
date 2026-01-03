import textgrid
import os
import codecs
import tempfile # For creating temporary files
import re # For encoding detection heuristic

# Define your IPA to ARPAbet mapping
ipa_to_arpabet_map = {
    'ʌ': 'AH', 'ɑ': 'AA', 'u': 'UW', 'y': 'UX', 'ɛ': 'EH', 'e': 'EY', 'o': 'OW', 'i': 'IY', 'ɯ': 'IX',
    'sil': 'SIL', 'v': 'V', 'j': 'Y', 'n': 'N', 'ʃ': 'SH', 'p': 'P', 'k': 'K', 'm': 'M', 'r': 'R',
    # Add any other IPA consonants you have that need specific ARPAbet mapping
}

def process_single_textgrid(input_tg_path, output_tg_path, mapping):
    """
    Reads a TextGrid, attempts to fix encoding, recodes its 'phones' tier, and saves.
    """
    temp_filepath = None # Initialize to None for cleanup in finally block
    try:
        # --- Step 1: Robustly read the TextGrid into a Unicode string ---
        content = None
        encodings_to_try = ['utf-8', 'latin-1', 'cp1252', 'iso-8859-1']
        
        for enc in encodings_to_try:
            try:
                with codecs.open(input_tg_path, 'r', encoding=enc) as f:
                    content = f.read()
                    if "File type" in content and "Object class" in content and ("text =" in content or "intervals:" in content):
                        break # Found a readable encoding
                    else:
                        content = None
            except UnicodeDecodeError:
                content = None
            except Exception as e:
                print(f"Unexpected error during encoding trial for '{os.path.basename(input_tg_path)}' with {enc}: {e}")
                content = None
        
        if not content:
            print(f"Warning: Could not reliably read '{os.path.basename(input_tg_path)}' with common encodings. Skipping.")
            return

        # --- Step 2: Write the content to a temporary UTF-8 file (CRITICAL FIX: newline='') ---
        # This ensures textgrid.TextGrid.fromFile() always reads a UTF-8 encoded file with consistent line endings
        
        # Use tempfile to create a temporary file that will be cleaned up
        with tempfile.NamedTemporaryFile(mode='w', delete=False, encoding='utf-8', suffix='.TextGrid', newline='') as temp_file: 
            temp_file.write(content)
            temp_filepath = temp_file.name # Get the path to the temporary file
        
        # --- Step 3: Read TextGrid from the temporary UTF-8 file ---
        # Added extra error handling for this specific step
        try:
            tg = textgrid.TextGrid.fromFile(temp_filepath)
        except Exception as e:
            print(f"Error: textgrid.TextGrid.fromFile() failed to parse temp file '{os.path.basename(input_tg_path)}' ({temp_filepath}): {e}. Skipping.")
            return
        
        # --- Step 4: Recode the 'phones' tier ---
        phones_tier = tg.getFirst('phones') 
        
        if phones_tier:
            for interval in phones_tier:
                original_label = interval.mark.strip()
                recoded_label = mapping.get(original_label, original_label)
                interval.mark = recoded_label
            print(f"Recoded 'phones' tier in '{os.path.basename(input_tg_path)}'.")
        else:
            print(f"Warning: 'phones' tier not found in '{os.path.basename(input_tg_path)}'. No recoding performed.")

        # --- Step 5: Save the recoded TextGrid as UTF-8 ---
        tg.write(output_tg_path) 
        print(f"Saved recoded TextGrid to '{os.path.basename(output_tg_path)}'.")

    except Exception as e:
        print(f"An unexpected error occurred during processing '{os.path.basename(input_tg_path)}': {e}")
    finally:
        # --- Step 6: Clean up the temporary file ---
        if temp_filepath and os.path.exists(temp_filepath):
            os.remove(temp_filepath)


# --- Directory Processing ---
base_corpus_path = "C:\\Users\\profk\\Documents\\GitHub\\phonology-chuvash\\corpora"
input_dir = os.path.join(base_corpus_path, "subcorpus")
output_recoded_dir = os.path.join(base_corpus_path, "recoded_textgrids")

# Create output directory if it doesn't exist
os.makedirs(output_recoded_dir, exist_ok=True)

print(f"Starting directory recoding process for TextGrids in: {input_dir}")
print(f"Recoded TextGrids will be saved to: {output_recoded_dir}")

processed_count = 0
for filename in os.listdir(input_dir):
    # Ensure we only process original TextGrid files, skipping temporary/test files
    if filename.endswith(".TextGrid") and \
       not filename.endswith("_fixed_utf8.TextGrid") and \
       not filename.endswith("_pre_recoded_arpabet.TextGrid") and \
       not filename.endswith("_recoded_final.TextGrid") and \
       not filename.endswith("_recoded_test.TextGrid") and \
       not filename.endswith("_arpabet.TextGrid"): 
        
        input_tg_path = os.path.join(input_dir, filename)
        
        base_name = os.path.splitext(filename)[0]
        output_tg_path = os.path.join(output_recoded_dir, f"{base_name}_arpabet.TextGrid")
        
        process_single_textgrid(input_tg_path, output_tg_path, ipa_to_arpabet_map)
        processed_count += 1

print(f"\nFinished recoding {processed_count} TextGrids.")
print(f"All recoded TextGrids are in: {output_recoded_dir}")