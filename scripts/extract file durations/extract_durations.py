import os
import soundfile as sf
import csv

audio_dir = r"C:\Users\profk\Documents\GitHub\phonology-chuvash\extract\vox\converted_audio"
output_csv = r"C:\Users\profk\Documents\GitHub\phonology-chuvash\scripts\utterance_durations_vox.csv"

with open(output_csv, "w", newline="") as f:
    writer = csv.writer(f)
    writer.writerow(["file_name", "duration_seconds"])
    
    for fname in os.listdir(audio_dir):
        if fname.endswith(".wav"):  # adjust if mp3 etc
            fpath = os.path.join(audio_dir, fname)
            try:
                info = sf.info(fpath)
                duration = info.duration
                # strip extension to match your file_name column in R
                file_name = os.path.splitext(fname)[0]
                writer.writerow([file_name, duration])
            except Exception as e:
                print(f"Failed on {fname}: {e}")

print("Done")