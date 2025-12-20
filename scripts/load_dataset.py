from datasets import load_dataset, DatasetDict

def load_chuvash_dataset():
    """
    Loads the Chuvash Common Voice dataset locally.
    Returns a DatasetDict.
    """
    # Load Chuvash dataset
    ds = load_dataset("alexantonov/chuvash_voice")

    # Keep only relevant columns
    ds = ds.remove_columns(["path", "locale", "client_id"])  # keep 'audio' and 'sentence'

    return ds

if __name__ == "__main__":
    dataset = load_chuvash_dataset()
    print(dataset)
    print(dataset["train"][0])
