# Kate Lindsey edited this script to work for her dataset. 
# Edits: target vowels only, disyllabic words only, and 
# custom label format: vowel;index;vowel_cat;word_cat
# Updated by Gemini to include Duration and Intensity columns and improved cleanup.

form Get time-series F0 data
	text Sound_directory C:\Users\profk\Documents\GitHub\phonology-chuvash\extract\vox\to_process\
	sentence Sound_file_extension .mp3
	text TextGrid_directory C:\Users\profk\Documents\GitHub\phonology-chuvash\extract\vox\to_process\
	sentence TextGrid_file_extension .TextGrid
	text Output_file C:\Users\profk\Documents\GitHub\phonology-chuvash\contour-clustering\output-vox.csv
	sentence Tier phones
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

if fileReadable (output_file$)
	pause The result file 'output_file$' already exists! Do you want to overwrite it?
	filedelete 'output_file$'
endif

sep$ = ","
titleline$ = "filename'sep$'interval_label'sep$'start'sep$'end'sep$'steptime'sep$'stepnumber'sep$'f0'sep$'intensity'sep$'duration'sep$'jumpkilleffect'sep$'vowel_index'sep$'vowel_total'sep$'vowel_category'sep$'word_category'sep$'word_label'newline$'"
fileappend "'output_file$'" 'titleline$'

for ifile to numberOfFiles
	select Strings list
	strings_list_id = selected("Strings")
	filename$ = Get string... ifile
	Read from file... 'sound_directory$''filename$'
	soundname$ = selected$ ("Sound", 1)
	# Capture the ID of the main sound to ensure we can remove it later
	main_sound_id = selected("Sound")
	
	gridfile$ = "'textGrid_directory$''soundname$''textGrid_file_extension$'"
	
	if fileReadable (gridfile$)
		Read from file... 'gridfile$'
		main_textgrid_id = selected("TextGrid")
		
		call GetTier 'tier$' phone_tier_num
		call GetTier 'tier2$' word_tier_num
		phonesTier = phone_tier_num
		wordsTier = word_tier_num

		if phonesTier = 0
			# CLEANUP: If tier not found, remove loaded objects and skip
			selectObject: main_textgrid_id
			Remove
			selectObject: main_sound_id
			Remove
			select Strings list
			continue 
		endif

		numberOfIntervals = Get number of intervals... phonesTier

		for interval to numberOfIntervals
			selectObject: main_textgrid_id
			label$ = Get label of interval... phonesTier interval
			
			# Check if it's a target vowel
			if label$ = "ɛ" or label$ = "i" or label$ = "ɑ" or label$ = "ʌ" or label$ = "u" or label$ = "y" or label$ = "ɯ" or label$ = "e"
				start = Get starting point... phonesTier interval
				end = Get end point... phonesTier interval
				dur = end - start

				if dur > minimum_duration and dur < maximum_duration
					word_label$ = ""
					vowel_index = 0
					total_vowels_in_word = 0
					current_vowel_cat$ = ""
					syll1_cat$ = ""
					syll2_cat$ = ""
					syll3_cat$ = ""
					syll4_cat$ = ""
					syll5_cat$ = ""
					syll6_cat$ = ""

					if wordsTier > 0
						numberOfWords = Get number of intervals... wordsTier
						foundWordFlag = 0
						
						for w from 1 to numberOfWords
							if foundWordFlag = 0
								local_wstart = Get starting point... wordsTier w
								local_wend = Get end point... wordsTier w
								if start >= local_wstart and end <= local_wend
									word_label$ = Get label of interval... wordsTier w
									foundWordFlag = 1
								endif
							endif
						endfor
						
						if foundWordFlag = 0
							for w from 1 to numberOfWords
								if foundWordFlag = 0
									local_wstart = Get starting point... wordsTier w
									local_wend = Get end point... wordsTier w
									if (start < local_wend and end > local_wstart)
										word_label$ = Get label of interval... wordsTier w
										foundWordFlag = 1
									endif
								endif
							endfor
						endif
						
						if foundWordFlag = 1
							numPhonesInWordRange = Get number of intervals... phonesTier
							count = 0
							for p to numPhonesInWordRange
								pstart = Get starting point... phonesTier p
								pend = Get end point... phonesTier p
								pmid = (pstart + pend) / 2
								if pmid >= local_wstart and pmid <= local_wend
									plabel$ = Get label of interval... phonesTier p
									if plabel$ = "ɛ" or plabel$ = "i" or plabel$ = "ɑ" or plabel$ = "ʌ" or plabel$ = "u" or plabel$ = "y" or plabel$ = "ɯ" or plabel$ = "e"
										count = count + 1
										
										# Identify Category for this specific vowel
										if plabel$ = "ɛ" or plabel$ = "ʌ"
											this_cat$ = "R"
										else
											this_cat$ = "F"
										endif

										# Track categories for word pattern
										
										if count = 1
											syll1_cat$ = this_cat$
										elsif count = 2
											syll2_cat$ = this_cat$
										elsif count = 3
											syll3_cat$ = this_cat$
										elsif count = 4
											syll4_cat$ = this_cat$
										elsif count = 5
											syll5_cat$ = this_cat$
										elsif count = 6
											syll6_cat$ = this_cat$
										endif

										# If this is the actual vowel we are currently processing
										if p = interval
											vowel_index = count
											current_vowel_cat$ = this_cat$
										endif
									endif
								endif
							endfor
							total_vowels_in_word = count
						endif
					endif

					# --- FILTER: More than 1 vowel ---
					if total_vowels_in_word > 0
						word_category$ = syll1_cat$ + syll2_cat$ + syll3_cat$ + syll4_cat$ + syll5_cat$ + syll6_cat$
						
						selectObject: main_sound_id
						Extract part: start, end, "rectangular", 1, "no"
						# Capture ID of the snippet
						sound_part_id = selected("Sound")
						
						selectObject: sound_part_id
						
						# Praat requires duration >= 6.4 / min_pitch for intensity.
						# If the vowel is very short, we must raise the min_pitch 
						# just for this calculation to prevent a crash.
						
						min_intensity_pitch = minimum_pitch
						required_duration = 6.4 / minimum_pitch
						
						if dur < required_duration
							# If too short, calculate the lowest pitch we can safely measure
							# consistently with this duration (plus a tiny safety margin)
							min_intensity_pitch = 6.4 / dur + 1
						endif

						# Now run intensity with the safe pitch floor
						To Intensity: min_intensity_pitch, 0, "yes"
						intensity_id = selected("Intensity")

						# --- PITCH ANALYSIS ---
						selectObject: sound_part_id

						# Dynamically raise min pitch floor if the sound is too short.
						# Praat requires duration >= 3 / min_pitch for autocorrelation analysis.
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
						
						measurestep = dur / (number_of_measurement_points + 1)
						step = measurestep
						stepnr = 1
						
						while stepnr <= number_of_measurement_points
							# 1. Get Pitch
							selectObject: pitch_tier_id
							value = Get value at time: step
							
							# 2. Get Intensity
							selectObject: intensity_id
							int_val = Get value at time: step, "Cubic"
							if int_val = undefined
								int_val = 0
							endif

							# 3. Write line (Added int_val and dur)
							resultline$ = "'soundname$''sep$''label$''sep$''start''sep$''end''sep$''step''sep$''stepnr''sep$''value''sep$''int_val''sep$''dur''sep$''mchange''sep$''vowel_index''sep$''total_vowels_in_word''sep$''current_vowel_cat$''sep$''word_category$''sep$''word_label$''newline$'"
							fileappend "'output_file$'" 'resultline$'
							
							step = step + measurestep
							stepnr = stepnr + 1
						endwhile
						
						# CLEANUP: Remove all temporary objects created in this interval
						# Using IDs is safer than names
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
					endif
				endif
			endif
		endfor
		
		# CLEANUP: Remove TextGrid for this file
		nocheck selectObject: main_textgrid_id
		nocheck Remove
	endif
	
	# CLEANUP: Remove Sound for this file
	nocheck selectObject: main_sound_id
	nocheck Remove
	
	# Reset selection to the file list for the next iteration
	nocheck select all
	nocheck minusObject: strings_list_id
	nocheck Remove
	select Strings list
endfor

Remove
writeInfo: "--- Script Finished ---"

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
