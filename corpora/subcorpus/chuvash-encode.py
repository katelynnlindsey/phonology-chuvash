import codecs

input_file = "utterance_000000.TextGrid" # Your ORIGINAL TextGrid file
output_file = "utterance_000000_fixed_utf8.TextGrid"

encodings_to_try = ['utf-8', 'latin-1', 'cp1252', 'iso-8859-1']
content = None

print(f"Attempting to read '{input_file}' with various encodings...")

for enc in encodings_to_try:
    try:
        with codecs.open(input_file, 'r', encoding=enc) as f:
            content = f.read()
            # A more robust check for non-garbled content
            if "File type" in content and "Object class" in content:
                # Check for presence of expected IPA characters that are *not* garbled
                if 'ʌ' in content or 'ɑ' in content or 'ɛ' in content or 'ɯ' in content:
                    print(f"Successfully read with encoding: {enc}")
                    break
                elif 'text = "sil"' in content and 'text = "v"' in content: # Heuristic for simpler cases
                     print(f"Successfully read with encoding: {enc} (heuristic match)")
                     break
            content = None # Not the correct content, try next encoding
    except UnicodeDecodeError:
        print(f"Failed to read with encoding: {enc}")
        continue
    except Exception as e:
        print(f"An unexpected error occurred with encoding {enc}: {e}")
        continue

if content:
    print(f"Saving content to '{output_file}' as UTF-8.")
    with codecs.open(output_file, 'w', encoding='utf-8') as f:
        f.write(content)
    print("Verification of fixed UTF-8 file:")
    with codecs.open(output_file, 'r', encoding='utf-8') as f:
        lines = [next(f) for x in range(30)] # Read first 30 lines
        for line in lines:
            print(line, end='')
else:
    print("Could not successfully read the input file with any of the attempted encodings.")
    print("Please open the original TextGrid in a text editor like Notepad++ or VS Code to identify its encoding.")