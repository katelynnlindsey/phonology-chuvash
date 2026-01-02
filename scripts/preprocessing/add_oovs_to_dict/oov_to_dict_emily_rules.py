# oov_to_dict_emily_fixed.py
from pathlib import Path

# ========= CONFIGURE THESE =========
oov_file      = r"C:\Users\profk\Documents\oovs_found_chuvash_cv.txt"
original_dict = r"C:\Users\profk\Documents\chuvash_cv.dict"
output_dict   = r"C:\Users\profk\Documents\chuvash_with_oovs_emily_final.dict"
# ===================================

letter_to_phone = {
    'а': 'ɑ', 'ӑ': 'ʌ', 'е': 'e', 'ӗ': 'ɛ', 'и': 'i', 'ы': 'ɯ',
    'о': 'o', 'у': 'u', 'ӳ': 'y', 'э': 'e',
    'в': 'v', 'й': 'j', 'к': 'k', 'л': 'l', 'м': 'm', 'н': 'n',
    'п': 'p', 'р': 'r', 'с': 's', 'ҫ': 'ɕ', 'т': 't', 'х': 'χ',
    'ч': 'tʃ', 'ш': 'ʃ', 
	'д': 'd', 'з': 'z', 'ф': 'f', 'ь': '', 'б': 'b', 'ю': 'j u', 'г': 'ɡ', 'я': 'j ɑ', 'ц': 'ts', 'щ': 'ɕː', 'ж': 'ʐ', 'ъ': '', 'ё': 'j o', 'x': 'h', 
	'i': 'i', 'e': 'e', 's': 's', 'g': 'ɡ', 'o': 'o', 'n': 'n', 'm': 'm', 'r': 'r', 'u': 'u', 'a': 'ɑ', 'l': 'l', 'y': 'i', 't': 't', 'h': 'h', 'c': 'k', 'd': 'd',
	'0': '', '1': '', '2': '', '3': '', '4': '', '5': '', '6': '', '7': '', '8': '', '9': '', '-': '', '/': '', '(': '', ')':'', '_': '', '\'': ''
}

def phones_from_word(word):
    w = word.lower()
    phones = []
    i = 0

    # Word-initial jV
    if w.startswith('е'):
        phones.extend(['j', 'e'])
        i = 1
    elif w.startswith('ю'):
        phones.extend(['j', 'u'])
        i = 1
    elif w.startswith('я'):
        phones.extend(['j', 'ɑ'])
        i = 1

    while i < len(w):
        c = w[i]
        if c not in letter_to_phone:
            raise ValueError(f"Unmapped character: {c} in {word}")
        phones.append(letter_to_phone[c])
        i += 1

    # Gemination
    final = []
    j = 0
    while j < len(phones):
        if j + 1 < len(phones) and phones[j] == phones[j + 1]:
            final.append(phones[j] + 'ː')
            j += 2
        else:
            final.append(phones[j])
            j += 1

    return final


# Load OOVs
with open(oov_file, encoding="utf-8") as f:
    oovs = [line.strip() for line in f if line.strip()]

new_lines = []
for word in oovs:
    phones = phones_from_word(word)
    pron = ' '.join(phones)
    new_lines.append(f"{word}\t{pron}\n")

# Combine with original dict
with open(original_dict, encoding="utf-8") as f:
    original = f.read().rstrip("\n") + "\n"

Path(output_dict).write_text(original + "".join(new_lines), encoding="utf-8")

print("Dictionary created perfectly.")
print(f"Added {len(new_lines)} OOVs.")
