extends SceneTree


func _initialize() -> void:
	var failures: PackedStringArray = []
	_test_choose_avoids_last(failures)
	_test_choose_prefers_unused(failures)
	_test_choose_reuses_when_used_exhausted(failures)
	_test_choose_allows_only_clip(failures)
	_test_pool_ids(failures)
	_test_wav_filter(failures)
	_test_pool_loads(failures)
	if failures.is_empty():
		print("ClueSfx: all checks passed.")
		quit(0)
	else:
		for failure in failures:
			printerr(failure)
		print("ClueSfx: %d check(s) failed." % failures.size())
		quit(1)


func _test_choose_avoids_last(failures: PackedStringArray) -> void:
	var paths: PackedStringArray = [
		"res://sfx/human_approach_1.wav",
		"res://sfx/human_approach_2.wav",
		"res://sfx/human_approach_3.wav",
	]
	for i in 40:
		var chosen := ClueSfx.choose_path(paths, paths[0])
		if chosen == paths[0]:
			failures.append("choose_path reused last clip %s." % paths[0])
			return
		if chosen not in paths:
			failures.append("choose_path returned unknown path %s." % chosen)
			return


func _test_choose_prefers_unused(failures: PackedStringArray) -> void:
	var paths: PackedStringArray = [
		"res://sfx/human_approach_1.wav",
		"res://sfx/human_approach_2.wav",
		"res://sfx/human_approach_3.wav",
	]
	var used := ["res://sfx/human_approach_1.wav"]
	for _i in 20:
		var chosen := ClueSfx.choose_path(paths, "", used)
		if chosen == used[0]:
			failures.append("choose_path should skip used clips when alternatives exist.")
			return


func _test_choose_reuses_when_used_exhausted(failures: PackedStringArray) -> void:
	var paths: PackedStringArray = [
		"res://sfx/human_knock_1.wav",
		"res://sfx/human_knock_2.wav",
	]
	var used := [paths[0], paths[1]]
	for _i in 20:
		var chosen := ClueSfx.choose_path(paths, paths[0], used)
		if chosen == paths[0]:
			failures.append("choose_path should avoid last clip when reusing exhausted pool.")
			return


func _test_choose_allows_only_clip(failures: PackedStringArray) -> void:
	var paths: PackedStringArray = ["res://sfx/horse_knock_1.wav"]
	var chosen := ClueSfx.choose_path(paths, paths[0])
	if chosen != paths[0]:
		failures.append("single-clip pool should still play that clip.")


func _test_pool_ids(failures: PackedStringArray) -> void:
	if ClueSfx.pool_id(SubjectDef.ClueKind.HUMAN, true) != &"human_approach":
		failures.append("human approach pool id mismatch.")
	if ClueSfx.pool_id(SubjectDef.ClueKind.HORSE, false) != &"horse_knock":
		failures.append("horse knock pool id mismatch.")


func _test_wav_filter(failures: PackedStringArray) -> void:
	if not ClueSfx.is_pool_wav("human_approach_1.wav", "human_approach_"):
		failures.append("should accept numbered wav in pool.")
	if ClueSfx.is_pool_wav("human_approach.mp3", "human_approach_"):
		failures.append("should ignore mp3 files.")
	if ClueSfx.is_pool_wav("human_knock_1.wav", "human_approach_"):
		failures.append("should ignore wavs from other pools.")


func _test_pool_loads(failures: PackedStringArray) -> void:
	for is_approach in [true, false]:
		for kind in [SubjectDef.ClueKind.HUMAN, SubjectDef.ClueKind.HORSE]:
			var stream := ClueSfx.pick(kind, is_approach)
			if stream == null:
				failures.append("pick(%s, %s) returned null." % [kind, is_approach])
				continue
			if not stream.resource_path.ends_with(".wav"):
				failures.append(
					"pick(%s, %s) path '%s' is not a .wav."
					% [kind, is_approach, stream.resource_path]
				)
