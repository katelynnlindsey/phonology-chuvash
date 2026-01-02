# load_all_chuvash_WORKS.py
import parselmouth
import pandas as pd
from pathlib import Path
from tqdm import tqdm
import warnings
warnings.filterwarnings("ignore")

folders = {
    "chuvashvoice": Path(r"C:\Users\profk\Documents\GitHub\phonology-chuvash\corpora\textgrids_chuvashvoice"),
    "commonvoice":  Path(r"C:\Users\profk\Documents\GitHub\phonology-chuvash\corpora\textgrids_commonvoice"),
    "audiobook":    Path(r"C:\Users\profk\Documents\GitHub\phonology-chuvash\corpora\textgrids_audiobook"),
    "controlled":   Path(r"C:\Users\profk\Documents\GitHub\phonology-chuvash\corpora\textgrids_controlled"),
}

def extract_phones(tg_path):
    tg = parselmouth.read(str(tg_path))        # ← str() needed
    rows = []
    # Try different possible phone tier names
    phone_tier = None
    for name in ["phones", "phone", "Phone", "Phones", "MAU"]:
        try:
            phone_tier = tg.get_tier(name)
            break
        except:
            continue
    if phone_tier is None:
        return []  # no phone tier found
    
    for interval in phone_tier.intervals:
        ph = interval.text.strip()
        if ph and ph != "" and ph != "sil" and ph != "sp":  # skip silences
            rows.append({
                "file":   tg_path.stem,
                "source": "",               # will be filled later
                "start":  interval.xmin,
                "end":    interval.xmax,
                "dur":    interval.duration(),
                "phone":  ph,
            })
    return rows

print("Loading all TextGrids...")
all_phones = []
for source, folder in folders.items():
    files = list(folder.glob("*.TextGrid"))
    print(f"  → {source} ({len(files)} files)")
    for tg_file in tqdm(files, desc=source, leave=False):
        phones = extract_phones(tg_file)
        for p in phones:
            p["source"] = source
        all_phones.extend(phones)

df = pd.DataFrame(all_phones)
pkl_path = r"C:\Users\profk\Documents\GitHub\phonology-chuvash\chuvash_all_phones.pkl"
df.to_pickle(pkl_path)
print(f"\nDONE! Total phone segments: {len(df):,}")
print(f"Saved to: {pkl_path}")
print("\nBy source:")
print(df["source"].value_counts())
print("\nTop 10 phones:")
print(df["phone"].value_counts().head(10))