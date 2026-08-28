extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var failures: PackedStringArray = []
	_test_format_timer_text(failures)
	_test_build_next_shift_preview(failures)
	_test_build_next_shift_preview_null(failures)
	_test_end_shift_headline(failures)
	_test_should_begin_win(failures)
	_test_mid_roster_summary(failures)
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


func _test_build_next_shift_preview(failures: PackedStringArray) -> void:
	var shift := ShiftDef.new()
	shift.subject_count = 5
	shift.strikes_allowed = 3
	shift.shift_timer_seconds = 150.0
	var preview := ShiftDirector.build_next_shift_preview(shift)
	var expected := "Next Shift\nTime: 02:30\nSubjects: 5\nStrikes allowed: 3"
	if preview != expected:
		failures.append("Unexpected next-shift preview:\n%s" % preview)


func _test_build_next_shift_preview_null(failures: PackedStringArray) -> void:
	if ShiftDirector.build_next_shift_preview(null) != "":
		failures.append("Null ShiftDef should produce an empty preview.")


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


func _test_mid_roster_summary(failures: PackedStringArray) -> void:
	var next_shift := ShiftDef.new()
	next_shift.subject_count = 4
	next_shift.strikes_allowed = 2
	next_shift.shift_timer_seconds = 90.0
	var summary := ShiftDirector.build_shift_end_summary(
		"Shift complete.",
		5,
		1,
		3,
		true,
		next_shift
	)
	if not summary.begins_with("Shift complete."):
		failures.append("Mid-roster summary should start with 'Shift complete.'.")
	if not summary.contains("Next Shift"):
		failures.append("Mid-roster summary should include next-shift preview.")
