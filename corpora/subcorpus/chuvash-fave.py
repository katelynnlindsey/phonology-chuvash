from new_fave import fave_audio_textgrid, write_data

speakers = fave_audio_textgrid(
    audio_path = "utterance_000000.wav",
    textgrid_path = "utterance_000000.TextGrid",
    speakers = "all",
    recode_rules = "chuvash-recode.yaml",
    labelset_parser = "cmu_parser",
    point_heuristic = "fave",
    ft_config = "default"
)

write_data(
    speakers, 
    destination = "output_dir"
)