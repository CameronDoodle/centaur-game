extends SceneTree


func _initialize() -> void:
	var failures: PackedStringArray = []
	_test_choose_line_prefers_unused(failures)
	_test_choose_line_reuses_when_exhausted(failures)
	if failures.is_empty():
		print("DialoguePools: all checks passed.")
		quit(0)
	else:
		for failure in failures:
			printerr(failure)
		print("DialoguePools: %d check(s) failed." % failures.size())
		quit(1)


func _test_choose_line_prefers_unused(failures: PackedStringArray) -> void:
	var pool := ["A", "B", "C"]
	for _i in 20:
		var chosen := DialoguePools.choose_line(pool, ["A"])
		if chosen == "A":
			failures.append("choose_line should skip excluded lines when alternatives exist.")
			return


func _test_choose_line_reuses_when_exhausted(failures: PackedStringArray) -> void:
	var pool := ["A", "B"]
	var chosen := DialoguePools.choose_line(pool, ["A", "B"])
	if chosen not in pool:
		failures.append("choose_line should reuse from pool when all lines are excluded.")
