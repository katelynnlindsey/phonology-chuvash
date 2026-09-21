# -*- coding: utf-8 -*-

import re

# --- Configuration ---
inpath = "wordlist.txt" # Your input file name
outpath = "new-wordlist.txt" # Your desired output file name

# Define all possible Chuvash vowels and consonants (from your previous scripts)
chuvash_vowels = u"аӑыуеӗиӳэяю"
foreign_vowels = u"оё"
all_chuvash_vowels = set(chuvash_vowels + foreign_vowels)

chuvash_consonants = u"ҫвйклмнпрстхчш"
foreign_consonants = u"бдгфцщжз"
consonant_modifier = u"ь" # 'ь' is a modifier, not a standalone consonant, but can be part of a consonant cluster

# For checking if a segment is composed *only* of consonants/modifiers and *no* vowels
all_possible_consonant_and_modifier_chars = set(chuvash_consonants + foreign_consonants + consonant_modifier)

def contains_chuvash_vowel(segment):
    """Checks if a segment contains any Chuvash vowel."""
    for char in segment:
        if char in all_chuvash_vowels:
            return True
    return False

def is_pure_consonant_segment_without_vowel(segment):
    """
    Checks if a segment consists solely of consonants/modifiers AND contains no Chuvash vowels.
    This identifies segments that are incorrectly split consonant clusters.
    """
    if not segment: # Empty segments are not consonant clusters
        return False
    if contains_chuvash_vowel(segment): # If it has a vowel, it's not a "pure consonant segment" to be merged
        return False
    
    # Check if all characters are indeed consonants or modifiers
    for char in segment:
        if char not in all_possible_consonant_and_modifier_chars:
            return False # Contains a non-consonant/modifier character
    
    return True # It's a non-empty segment, no vowels, and all chars are consonants/modifiers

def process_word(word_raw):
    """
    Processes a single word string to fix syllabification issues and period/apostrophe placement.
    """
    # 1. Initial cleaning: remove leading/trailing whitespace and convert to lowercase
    word = word_raw.strip().lower()

    if not word: # Skip truly empty lines
        return ""

    # 2. Rule: Any word with two or more periods together needs to become just one.
    word = re.sub(r'\.{2,}', '.', word)

    # 3. Rule: Any .s at the beginning or end of the word should then be removed.
    word = word.strip('.')

    if not word: # If word becomes empty after stripping periods (e.g., input was "..." or ".")
        return ""

    # Split the word into parts based on '.'
    parts = word.split('.')
    processed_parts = []
    i = 0

    while i < len(parts):
        current_part = parts[i]

        # Skip empty parts that might result from initial cleaning or splitting (e.g., "a..b" -> "a.b" -> ["a", "", "b"])
        if not current_part:
            i += 1
            continue

        # Check if current_part is a problematic consonant cluster (no vowels)
        if is_pure_consonant_segment_without_vowel(current_part):
            # Prioritize merging forward with the next part
            if i + 1 < len(parts):
                next_part = parts[i+1]
                
                # Ensure next_part is not empty before processing.
                if next_part:
                    # Rule: If a consonant cluster is followed by a syllable starting with an apostrophe,
                    # it needs to go after both the '.' and the '' (interpreted as: X.CC.'Y -> X.'CCY)
                    if next_part.startswith("'"):
                        # If current_part already has an apostrophe at the beginning (e.g., in ''врр'),
                        # we need to handle that. Remove leading apostrophe from current_part first.
                        effective_current_part = current_part.lstrip("'")
                        processed_parts.append("'" + effective_current_part + next_part[1:])
                    # Rule: If a consonant cluster is followed by a '.',
                    # it should go after the '.' (interpreted as: X.CC.Y -> X.CCY)
                    else:
                        processed_parts.append(current_part + next_part)
                    i += 2 # Skip current and next parts as they've been merged
                else: # next_part is empty, treat current_part as if it's at the end for merging backward
                    if processed_parts:
                        processed_parts[-1] += current_part
                    else: # Very unlikely: word is just a consonant cluster (e.g., "ск")
                        processed_parts.append(current_part)
                    i += 1
            else:
                # Consonant cluster at the very end of the word, merge backward
                if processed_parts:
                    processed_parts[-1] += current_part
                else: # Very unlikely: word is just a consonant cluster (e.g., "ск")
                    processed_parts.append(current_part)
                i += 1
        else:
            # Not a problematic consonant cluster, just add it as is
            processed_parts.append(current_part)
            i += 1

    # Join the processed parts with a single period as the syllable separator
    result = '.'.join(processed_parts)

    # Final strip just in case (though initial strip and careful joining should handle most cases)
    result = result.strip('.')
    
    return result

# --- Main script execution ---
if __name__ == "__main__":
    try:
        with open(inpath, "r", encoding="utf-8") as infile:
            with open(outpath, "w", encoding="utf-8") as outfile:
                for line in infile:
                    processed_line = process_word(line)
                    # Always write a newline, even if the processed_line is empty (to preserve line count)
                    outfile.write(processed_line + "\n")
        print(f"Successfully processed '{inpath}' and saved the output to '{outpath}'.")
    except FileNotFoundError:
        print(f"Error: Input file '{inpath}' not found. Please ensure the file exists and the path is correct.")
    except Exception as e:
        print(f"An unexpected error occurred: {e}")