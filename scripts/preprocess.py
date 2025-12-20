import librosa

# IPA transliteration mapping
IPA_MAPPING = {
    "ҫ": "ɕ", "в": "ʋ", "п": "p", "т": "t",
    "ч": "tɕ", "к": "k", "с": "s", "ш": "ʂ",
    "х": "χ", "м": "m", "н": "n", "л": "l",
    "й": "j", "р": "r", "и": "i", "ӳ": "y",
    "ы": "ʉ", "у": "u", "е": "e", "ӗ": "ø",
    "а": "ɑ", "ӑ": "ɔ", "о": "o", "ь": "ʲ",
    "я": "jɑ", "ю": "ju", "ё": "jɔ",
    "б": "b", "г": "ɡ", "д": "d", "ж": "ʐ",
    "з": "z", "щ": "ɕː", "э": "e", "ф": "f",
}

def transliterate_to_ipa(text):
    for k, v in IPA_MAPPING.items():
        text = text.replace(k, v)
    return text

def load_audio(path, sr=16000):
    """Load an audio file as a waveform at the given sampling rate."""
    waveform, _ = librosa.load(path, sr=sr)
    return waveform
