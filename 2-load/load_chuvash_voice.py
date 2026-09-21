from datasets import load_dataset, DatasetDict, concatenate_datasets, Audio
import pandas as pd
import matplotlib.pyplot as plt
import seaborn as sns
import os
import numpy as np
import re
from scipy import stats
from statsmodels.stats.multicomp import pairwise_tukeyhsd

# Load the Chuvash_voice dataset
chuvash_voice = DatasetDict()
chuvash_voice = load_dataset("alexantonov/chuvash_voice")
# Ensure audio is loaded at a consistent sampling rate
chuvash_voice = chuvash_voice.cast_column("audio", Audio(sampling_rate=16000))

print("Chuvash-Voice dataset loaded successfully.")
print(chuvash_voice)