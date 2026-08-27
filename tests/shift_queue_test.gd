extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var failures: PackedStringArray = []
	_test_pool_and_count(failures)
	_test_empty_pool(failures)
	if failures.is_empty():
		print("Shift queue generation: all checks passed.")
		quit(0)
	else:
		for failure in failures:
			printerr(failure)
		print("Shift queue generation: %d check(s) failed." % failures.size())
		quit(1)


func _test_pool_and_count(failures: PackedStringArray) -> void:
	var shift := ShiftDef.new()
	shift.include_human = true
	shift.include_horse = true
	shift.include_centaur = false
	shift.include_human_centaur = false
	shift.include_horse_centaur = false
	shift.subject_count = 12
	var catalog := _make_catalog()
	var queue := ShiftDirector.roll_queue(shift, catalog)
	if queue.size() != 12:
		failures.append("Expected queue length 12, got %d." % queue.size())
	var allowed := {
		SubjectDef.TrueType.HUMAN: true,
		SubjectDef.TrueType.HORSE: true,
	}
	for subject in queue:
		if subject == null:
			failures.append("Queue contained a null SubjectDef.")
			continue
		if not allowed.has(subject.true_type):
			failures.append(
				"Queue contained disallowed type %s."
				% SubjectDef.TrueType.keys()[subject.true_type]
			)


func _test_empty_pool(failures: PackedStringArray) -> void:
	var shift := ShiftDef.new()
	shift.include_human = false
	shift.include_horse = false
	shift.include_centaur = false
	shift.include_human_centaur = false
	shift.include_horse_centaur = false
	shift.subject_count = 8
	var queue := ShiftDirector.roll_queue(shift, _make_catalog())
	if not queue.is_empty():
		failures.append("Empty pool should produce an empty queue, got %d." % queue.size())


func _make_catalog() -> SubjectCatalog:
	var catalog := SubjectCatalog.new()
	catalog.human = _stub_subject(SubjectDef.TrueType.HUMAN)
	catalog.horse = _stub_subject(SubjectDef.TrueType.HORSE)
	catalog.centaur = _stub_subject(SubjectDef.TrueType.CENTAUR)
	catalog.human_centaur = _stub_subject(SubjectDef.TrueType.HUMAN_CENTAUR)
	catalog.horse_centaur = _stub_subject(SubjectDef.TrueType.HORSE_CENTAUR)
	return catalog


func _stub_subject(true_type: SubjectDef.TrueType) -> SubjectDef:
	var subject := SubjectDef.new()
	subject.true_type = true_type
	return subject
