from datasets import load_dataset
import os
import requests

# Load the dataset
chuvash_voice = load_dataset("alexantonov/chuvash_voice")

# Choose the split (e.g., "train")
split = chuvash_voice["train"]

# Make a folder to save the audio files
os.makedirs("audio_files", exist_ok=True)

# Iterate through the dataset
for i, example in enumerate(split):
    audio_url = example["path"]  # this is the direct path/URL to the audio
    sentence = example["sentence"]  # text transcription

    # Save sentence as a text file
    text_path = os.path.join("audio_files", f"{i}.txt")
    with open(text_path, "w", encoding="utf-8") as f:
        f.write(sentence)

    # Download the audio
    audio_path = os.path.join("audio_files", f"{i}.mp3")  # adjust extension if needed
    r = requests.get(audio_url)
    with open(audio_path, "wb") as f:
        f.write(r.content)
