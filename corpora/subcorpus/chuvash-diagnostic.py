import codecs
import re
output_file_to_verify = "utterance_000000_pre_recoded_arpabet.TextGrid" # Note the new output filename
print(f"\n--- Verifying content of '{output_file_to_verify}' via Python ---")
try:
    with codecs.open(output_file_to_verify, 'r', encoding='utf-8') as f:
        content = f.read()
        phones_tier_pattern = re.compile(r'item \[\d+\]:\s*class = "IntervalTier"\s*name = "phones"(.*?)(?=\n\s*item \[\d+\]:|\Z)', re.DOTALL)
        phones_tier_match = phones_tier_pattern.search(content)
        
        if phones_tier_match:
            phones_tier_section = phones_tier_match.group(1)
            phone_labels = re.findall(r'text = "(.*?)"', phones_tier_section)
            
            if phone_labels:
                print("--- All phone labels in order (recoded test) ---")
                for p_label in phone_labels:
                    print(f"'{p_label}' (hex: {p_label.encode('utf-8').hex()})")
            else:
                print("Error: Could not extract any 'text' labels from the 'phones' tier section.")
        else:
            print("Error: Could not find the 'phones' tier named 'phones' in the TextGrid content.")
except Exception as e:
    print(f"An unexpected error occurred while reading or processing: {e}")