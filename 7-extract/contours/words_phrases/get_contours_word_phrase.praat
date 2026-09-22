form Get time-series F0 data (Word and Phrase level)
	text Sound_directory C:\Users\profk\Documents\GitHub\phonology-chuvash\extract\vox\to_process\
	sentence Sound_file_extension .mp3
	text TextGrid_directory C:\Users\profk\Documents\GitHub\phonology-chuvash\extract\vox\to_process\
	sentence TextGrid_file_extension .TextGrid
	text Output_file_words C:\Users\profk\Documents\GitHub\phonology-chuvash\contour-clustering\output-vox-words.csv
	text Output_file_phrases C:\Users\profk\Documents\GitHub\phonology-chuvash\contour-clustering\output-vox-phrases.csv
	sentence Tier2 words
	comment What is the desired duration range of the contour length (seconds)?
	positive Minimum_duration 0.0001
	positive Maximum_duration 100
	positive Number_of_measurement_points 20
	comment Pitch analysis parameters (filtered ac):
	positive Time_step 0.01
	positive Minimum_pitch_(Hz) 100
	positive Maximum_pitch_(Hz) 800
	positive Silence_threshold 0.09
	positive Voicing_threshold 0.5
	positive Octave_cost 0.055
	positive Octave_jump_cost 0.35
	positive Voiced_unvoiced_cost 0.14
	boolean Kill_octave_jumps 1
	positive Smoothing_bandwith_(Hz) 10
	positive Stylization_resolution_(ST) 2
endform

Create Strings as file list... list 'sound_directory$'*'sound_file_extension$'
numberOfFiles = Get number of strings
writeInfo: "--- Script Start ---"

# --- Setup output files ---
sep$ = ","

for ifile to numberOfFiles
	select Strings list
	strings_list_id = selected("Strings")
	filename$ = Get string... ifile
	Read from file... 'sound_directory$''filename$'
	soundname$ = selected$ ("Sound", 1)
	main_sound_id = selected("Sound")

	gridfile$ = "'textGrid_directory$''soundname$''textGrid_file_extension$'"

	if fileReadable (gridfile$)
		Read from file... 'gridfile$'
		main_textgrid_id = selected("TextGrid")

		call GetTier 'tier2$' word_tier_num
		wordsTier = word_tier_num

		if wordsTier = 0
			selectObject: main_textgrid_id
			Remove
			selectObject: main_sound_id
			Remove
			select Strings list
			continue
		endif

		numberOfWords = Get number of intervals... wordsTier

		# =====================================================
		# WORD-LEVEL LOOP
		# =====================================================
		for w from 1 to numberOfWords
			selectObject: main_textgrid_id
			word_label$ = Get label of interval... wordsTier w
			
			# Skip empty intervals (silence between words)
			if word_label$ <> ""
				wstart = Get starting point... wordsTier w
				wend = Get end point... wordsTier w
				wdur = wend - wstart

				if wdur > minimum_duration and wdur < maximum_duration
					call ExtractContourAndWrite 'main_sound_id' 'wstart' 'wend' 'wdur' 'word_label$' 'soundname$' 'w' 'output_file_words$'
				endif
			endif
		endfor

		# =====================================================
		# PHRASE-LEVEL: find first non-empty word start and
		# last non-empty word end, spanning the whole file
		# =====================================================
		selectObject: main_textgrid_id
		phrase_start = undefined
		phrase_end = undefined

		for w from 1 to numberOfWords
			selectObject: main_textgrid_id
			word_label$ = Get label of interval... wordsTier w
			if word_label$ <> ""
				wstart = Get starting point... wordsTier w
				wend = Get end point... wordsTier w
				if phrase_start = undefined
					phrase_start = wstart
				endif
				phrase_end = wend
			endif
		endfor

		if phrase_start <> undefined
			phrase_dur = phrase_end - phrase_start
			phrase_label$ = soundname$

			if phrase_dur > minimum_duration and phrase_dur < maximum_duration
				call ExtractContourAndWrite 'main_sound_id' 'phrase_start' 'phrase_end' 'phrase_dur' 'phrase_label$' 'soundname$' 1 'output_file_phrases$'
			endif
		endif

		nocheck selectObject: main_textgrid_id
		nocheck Remove
	endif

	nocheck selectObject: main_sound_id
	nocheck Remove

	nocheck select all
	nocheck minusObject: strings_list_id
	nocheck Remove
	select Strings list
endfor

select Strings list
Remove
writeInfo: "--- Script Finished ---"


# =====================================================
# PROCEDURE: Extract contour from a sound segment and
# write 20-point time series to the given output file
# =====================================================
procedure ExtractContourAndWrite sound_id start end dur label$ soundname$ index output_file$

	selectObject: sound_id
	Extract part: start, end, "rectangular", 1, "no"
	sound_part_id = selected("Sound")

	# --- Intensity ---
	selectObject: sound_part_id
	min_intensity_pitch = minimum_pitch
	required_duration = 6.4 / minimum_pitch
	if dur < required_duration
		min_intensity_pitch = 6.4 / dur + 1
	endif
	To Intensity: min_intensity_pitch, 0, "yes"
	intensity_id = selected("Intensity")

	# --- Pitch ---
	selectObject: sound_part_id
	min_pitch_for_sound = minimum_pitch
	required_pitch_duration = 3 / minimum_pitch
	if dur < required_pitch_duration
		min_pitch_for_sound = ceiling(3 / dur) + 1
	endif
	To Pitch (filtered autocorrelation): time_step, min_pitch_for_sound, maximum_pitch, 15, "no", 0.03, silence_threshold, voicing_threshold, octave_cost, octave_jump_cost, voiced_unvoiced_cost
	pitch_id = selected("Pitch")

	mchange = 0
	if kill_octave_jumps = 1
		morg = Get mean: 0, 0, "Hertz"
		Kill octave jumps
		moct = Get mean: 0, 0, "Hertz"
		if moct <> 0
			mchange = morg / moct
		else
			mchange = 0
		endif
	endif

	Smooth: smoothing_bandwith
	smooth_pitch_id = selected("Pitch")

	selectObject: smooth_pitch_id
	Interpolate
	interp_pitch_id = selected("Pitch")

	Down to PitchTier
	pitch_tier_id = selected("PitchTier")
	Stylize: stylization_resolution, "Semitones"

	# --- Write 20 measurement points ---
	measurestep = dur / (number_of_measurement_points + 1)
	step = measurestep
	stepnr = 1

	while stepnr <= number_of_measurement_points
		selectObject: pitch_tier_id
		value = Get value at time: step

		selectObject: intensity_id
		int_val = Get value at time: step, "Cubic"
		if int_val = undefined
			int_val = 0
		endif

		resultline$ = "'soundname$''sep$''label$''sep$''start''sep$''end''sep$''step''sep$''stepnr''sep$''value''sep$''int_val''sep$''dur''sep$''mchange''sep$''index''newline$'"
		fileappend "'output_file$'" 'resultline$'

		step = step + measurestep
		stepnr = stepnr + 1
	endwhile

	# --- Cleanup ---
	nocheck selectObject: pitch_tier_id
	nocheck Remove
	nocheck selectObject: interp_pitch_id
	nocheck Remove
	nocheck selectObject: smooth_pitch_id
	nocheck Remove
	nocheck selectObject: pitch_id
	nocheck Remove
	nocheck selectObject: intensity_id
	nocheck Remove
	nocheck selectObject: sound_part_id
	nocheck Remove

endproc


procedure GetTier name$ variable$
	numberOfTiers = Get number of tiers
	itier = 1
	repeat
		tier_name_in_grid$ = Get tier name... itier
		itier = itier + 1
	until tier_name_in_grid$ = name$ or itier > numberOfTiers
	if tier_name_in_grid$ <> name$
		'variable$' = 0
	else
		'variable$' = itier - 1
	endif
endproc
