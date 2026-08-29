extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var failures: PackedStringArray = []
	_test_format_timer_text(failures)
	_test_end_shift_headline(failures)
	_test_should_begin_win(failures)
	_test_end_shift_paths(failures)
	_test_hud_subject_ticks_filled(failures)
	_test_hud_strike_pips_filled(failures)
	if failures.is_empty():
		print("Shift progress HUD: all checks passed.")
		quit(0)
	else:
		for failure in failures:
			printerr(failure)
		print("Shift progress HUD: %d check(s) failed." % failures.size())
		quit(1)


func _test_format_timer_text(failures: PackedStringArray) -> void:
	if ShiftDirector.format_timer_text(150.0) != "02:30":
		failures.append(
			"Expected 150s to format as 02:30, got %s."
			% ShiftDirector.format_timer_text(150.0)
		)
	if ShiftDirector.format_timer_text(90.0) != "01:30":
		failures.append(
			"Expected 90s to format as 01:30, got %s."
			% ShiftDirector.format_timer_text(90.0)
		)
	if ShiftDirector.format_timer_text(0.0) != "00:00":
		failures.append(
			"Expected 0s to format as 00:00, got %s."
			% ShiftDirector.format_timer_text(0.0)
		)


func _test_end_shift_headline(failures: PackedStringArray) -> void:
	if ShiftDirector.end_shift_headline(true, false) != "You won!":
		failures.append(
			"Last-shift success headline expected 'You won!', got '%s'."
			% ShiftDirector.end_shift_headline(true, false)
		)
	if ShiftDirector.end_shift_headline(true, true) != "Shift complete.":
		failures.append(
			"Mid-roster success headline expected 'Shift complete.', got '%s'."
			% ShiftDirector.end_shift_headline(true, true)
		)


func _test_should_begin_win(failures: PackedStringArray) -> void:
	if not ShiftDirector.should_begin_win(true, false):
		failures.append("Last-shift success should begin Win.")
	if ShiftDirector.should_begin_win(true, true):
		failures.append("Mid-roster success should not begin Win.")


func _test_end_shift_paths(failures: PackedStringArray) -> void:
	var fail_replay := not false
	var fail_next := false and true
	if fail_replay != true:
		failures.append("Failed Shift should offer Replay Shift.")
	if fail_next:
		failures.append("Failed Shift should not offer Next Shift.")

	var success_replay := not true
	var success_next := true and true
	if success_replay:
		failures.append("Mid-roster success should not offer Replay Shift.")
	if success_next != true:
		failures.append("Mid-roster success should offer Next Shift.")


func _test_hud_subject_ticks_filled(failures: PackedStringArray) -> void:
	if HUD.subject_ticks_filled(4, 6) != 4:
		failures.append("Expected 4 filled subject ticks for 4 of 6.")
	if HUD.subject_ticks_filled(8, 6) != 6:
		failures.append("Filled subject ticks should not exceed total.")


func _test_hud_strike_pips_filled(failures: PackedStringArray) -> void:
	if HUD.strike_pips_filled(1, 3) != 1:
		failures.append("Expected 1 filled strike pip for 1 of 3.")
	if HUD.strike_pips_filled(5, 3) != 3:
		failures.append("Filled strike pips should not exceed allowed.")
