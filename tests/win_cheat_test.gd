extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var failures: PackedStringArray = []
	_test_cheat_sequence_match(failures)
	_test_cheat_buffer_progression(failures)
	_test_cheat_buffer_wrong_key_clears(failures)
	_test_cheat_buffer_restart_on_w(failures)
	if failures.is_empty():
		print("Win cheat buffer: all checks passed.")
		quit(0)
	else:
		for failure in failures:
			printerr(failure)
		print("Win cheat buffer: %d check(s) failed." % failures.size())
		quit(1)


func _test_cheat_sequence_match(failures: PackedStringArray) -> void:
	if not ShiftDirector.is_cheat_sequence([KEY_W, KEY_I, KEY_N]):
		failures.append("W,I,N should match the cheat sequence.")
	if ShiftDirector.is_cheat_sequence([KEY_W, KEY_I]):
		failures.append("Partial sequence should not match.")
	if ShiftDirector.is_cheat_sequence([KEY_W, KEY_N, KEY_I]):
		failures.append("Wrong order should not match.")


func _test_cheat_buffer_progression(failures: PackedStringArray) -> void:
	var buffer: Array = []
	buffer = ShiftDirector.cheat_buffer_after_key(buffer, KEY_W)
	if buffer != [KEY_W]:
		failures.append("First W should start the cheat buffer.")
	buffer = ShiftDirector.cheat_buffer_after_key(buffer, KEY_I)
	if buffer != [KEY_W, KEY_I]:
		failures.append("I should extend the cheat buffer.")
	buffer = ShiftDirector.cheat_buffer_after_key(buffer, KEY_N)
	if not ShiftDirector.is_cheat_sequence(buffer):
		failures.append("N should complete the cheat sequence.")


func _test_cheat_buffer_wrong_key_clears(failures: PackedStringArray) -> void:
	var buffer := ShiftDirector.cheat_buffer_after_key([KEY_W], KEY_A)
	if not buffer.is_empty():
		failures.append("Wrong key after W should clear the cheat buffer.")


func _test_cheat_buffer_restart_on_w(failures: PackedStringArray) -> void:
	var buffer := ShiftDirector.cheat_buffer_after_key([KEY_W, KEY_I], KEY_W)
	if buffer != [KEY_W]:
		failures.append("W after partial progress should restart the cheat buffer.")
