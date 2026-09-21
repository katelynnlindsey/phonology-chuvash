import pandas as pd
import os
import sys # Import sys to handle graceful exit

# Chuvash Vowel to IPA mapping (using your updated values)
vowel_ipa_map = {
    'а': 'a',
    'е': 'e',
    'и': 'i',
    'ă': 'ɵ', # Changed from 'ɐ'
    'ӗ': 'ø', # Changed from 'ɘ'
    'у': 'u',
    'ӳ': 'y',
    'о': 'o',
    'ы': 'ʉ',
    'ӑ': 'ɵ',
    'я': 'a',
    'ю': 'u',
    'э': 'e'
}

# List to store all vowel data
all_vowel_data = []

# --- Modified File Reading Section for Debugging ---
def process_wordlist_from_file_non_interactive(filename="wordlist.txt"):
    """Reads word data from a specified file without prompting the user."""
    
    # --- DEBUGGING LINES ---
    print(f"Script's current working directory: {os.getcwd()}")
    print(f"Files found in current directory: {os.listdir()}")
    print(f"Attempting to open file: {filename}")
    # --- END DEBUGGING LINES ---

    if not os.path.exists(filename):
        print(f"\nError: The input file '{filename}' was not found in the same directory as the script.")
        print("Please ensure:")
        print("1. The filename is spelled exactly correctly (including case: 'wordlist.txt').")
        print("2. There are no hidden extensions (e.g., 'wordlist.txt.txt').")
        print("3. The 'wordlist.txt' file is in the *exact same folder* as this Python script.")
        input("Press Enter to exit and check your files.") # Keep window open to see error
        sys.exit() # Use sys.exit() for a clean exit
    
    try:
        with open(filename, 'r', encoding='utf-8') as f:
            text_data = f.read()
        print(f"\nSuccessfully read data from '{filename}'.")
        return text_data
    except Exception as e:
        print(f"An unexpected error occurred while reading the file '{filename}': {e}")
        input("Press Enter to exit.") # Keep window open to see error
        sys.exit() # Terminate script execution

# Call the non-interactive function to get the text data
text_data_from_file = process_wordlist_from_file_non_interactive("new-wordlist.txt")


# Process each word from the file content
for line in text_data_from_file.strip().split('\n'):
    word_original = line.strip()
    if not word_original:
        continue

    syllables = word_original.split('.')
    sN = len(syllables) # Total number of syllables in the word

    for sidx, syllable_with_stress in enumerate(syllables):
        current_sidx = sidx + 1 # 1-based index

        # Determine syllable position
        if sN == 1:
            syl_pos = 'initial_final'
        elif current_sidx == 1:
            syl_pos = 'initial'
        elif current_sidx == sN:
            syl_pos = 'final'
        else:
            syl_pos = 'med'

        # Determine stress
        phon_stress = 1 if "'" in syllable_with_stress else 0

        # Remove stress mark for vowel and open/closed analysis
        cleaned_syllable = syllable_with_stress.replace("'", "")

        # Find the vowel and its IPA
        vowel_char = None
        vowel_ipa = None
        vowel_index_in_syllable = -1

        for char_idx, char in enumerate(cleaned_syllable):
            if char in vowel_ipa_map:
                vowel_char = char
                vowel_ipa = vowel_ipa_map[char]
                vowel_index_in_syllable = char_idx
                break # Assuming one vowel per syllable, take the first one found

        if vowel_char is None:
            print(f"Warning: No Chuvash vowel found in syllable '{syllable_with_stress}' of word '{word_original}'. This entry will be skipped.")
            continue # Skip this syllable if no vowel is found

        # Determine if syllable is open or closed
        if vowel_index_in_syllable == len(cleaned_syllable) - 1:
            syl_open_closed = 'open'
        else:
            syl_open_closed = 'closed'

        # Append data for this vowel
        all_vowel_data.append({
            'label': vowel_ipa,
            'word': word_original,
            'syllable': syllable_with_stress,
            'phon_stress': phon_stress,
            'sidx': current_sidx,
            'sN': sN,
            'syl_pos': syl_pos,
            'syl_open_closed': syl_open_closed,
            'corpus': 'zheltov'
        })

# Create a Pandas DataFrame
df = pd.DataFrame(all_vowel_data)

# Display the first few rows of the DataFrame
print("\n--- Generated DataFrame (first 5 rows) ---")
print(df.head())

# Prompt for the output filename
output_filename = input("\nEnter a filename to save the results as a CSV (e.g., 'chuvash_vowel_data.csv'): ")
try:
    df.to_csv(output_filename, index=False, encoding='utf-8')
    print(f"Data successfully saved to '{output_filename}'")
except Exception as e:
    print(f"Error saving data to CSV: {e}")

# This line keeps the command shell window open until you press Enter,
# allowing you to see all the output, including any error messages.
input("\nProcessing complete. Press Enter to exit.")