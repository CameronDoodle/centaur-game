extends SceneTree

const PROMPT_KEYS := ["are_you_a_horse", "whats_your_name"]


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var failures: PackedStringArray = []
	_test_pool_and_count(failures)
	_test_type_coverage(failures)
	_test_balanced_extras(failures)
	_test_no_extras_when_count_equals_pool(failures)
	_test_no_consecutive_same_type(failures)
	_test_single_type_pool_allows_repeats(failures)
	_test_empty_pool(failures)
	_test_dialogue_uniqueness(failures)
	_test_sfx_uniqueness(failures)
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
	for plan in queue:
		if plan == null or plan.subject == null:
			failures.append("Queue contained a null EncounterPlan or SubjectDef.")
			continue
		if not allowed.has(plan.subject.true_type):
			failures.append(
				"Queue contained disallowed type %s."
				% SubjectDef.TrueType.keys()[plan.subject.true_type]
			)


func _test_type_coverage(failures: PackedStringArray) -> void:
	var shift := ShiftDef.new()
	shift.include_human = true
	shift.include_horse = true
	shift.include_centaur = true
	shift.include_human_centaur = false
	shift.include_horse_centaur = false
	shift.subject_count = 8
	var catalog := _make_catalog()
	for attempt in 16:
		var queue := ShiftDirector.roll_queue(shift, catalog)
		var seen := {}
		for plan in queue:
			seen[plan.subject.true_type] = true
		for true_type in shift.enabled_types():
			if not seen.has(true_type):
				failures.append(
					"Attempt %d: missing enabled type %s."
					% [attempt, SubjectDef.TrueType.keys()[true_type]]
				)
				break


func _test_balanced_extras(failures: PackedStringArray) -> void:
	var shift := ShiftDef.new()
	shift.include_human = true
	shift.include_horse = true
	shift.include_centaur = true
	shift.include_human_centaur = false
	shift.include_horse_centaur = false
	shift.subject_count = 8
	var catalog := _make_catalog()
	for attempt in 16:
		var counts := {}
		for true_type in shift.enabled_types():
			counts[true_type] = 0
		for plan in ShiftDirector.roll_queue(shift, catalog):
			counts[plan.subject.true_type] += 1
		var values := counts.values()
		var min_count: int = values[0]
		var max_count: int = values[0]
		for count in values:
			min_count = mini(min_count, count)
			max_count = maxi(max_count, count)
		if max_count - min_count > 1:
			failures.append(
				"Attempt %d: unbalanced extras (min=%d, max=%d)."
				% [attempt, min_count, max_count]
			)
			break


func _test_no_extras_when_count_equals_pool(failures: PackedStringArray) -> void:
	var shift := ShiftDef.new()
	shift.include_human = true
	shift.include_horse = true
	shift.include_centaur = false
	shift.include_human_centaur = false
	shift.include_horse_centaur = false
	shift.subject_count = 2
	var catalog := _make_catalog()
	for attempt in 16:
		var counts := {}
		for plan in ShiftDirector.roll_queue(shift, catalog):
			var true_type: SubjectDef.TrueType = plan.subject.true_type
			counts[true_type] = counts.get(true_type, 0) + 1
		if counts.size() != 2:
			failures.append("Attempt %d: expected exactly one of each type." % attempt)
			break
		for count in counts.values():
			if count != 1:
				failures.append("Attempt %d: extras present when count equals pool." % attempt)
				break


func _test_no_consecutive_same_type(failures: PackedStringArray) -> void:
	var shift := ShiftDef.new()
	shift.include_human = true
	shift.include_horse = true
	shift.include_centaur = true
	shift.include_human_centaur = false
	shift.include_horse_centaur = false
	shift.subject_count = 24
	var catalog := _make_catalog()
	for attempt in 32:
		var queue := ShiftDirector.roll_queue(shift, catalog)
		if queue.size() != shift.subject_count:
			failures.append(
				"Attempt %d: expected queue length %d, got %d."
				% [attempt, shift.subject_count, queue.size()]
			)
			continue
		for i in range(1, queue.size()):
			if queue[i].subject.true_type == queue[i - 1].subject.true_type:
				failures.append(
					"Attempt %d: consecutive %s at indices %d and %d."
					% [
						attempt,
						SubjectDef.TrueType.keys()[queue[i].subject.true_type],
						i - 1,
						i,
					]
				)
				break


func _test_single_type_pool_allows_repeats(failures: PackedStringArray) -> void:
	var shift := ShiftDef.new()
	shift.include_human = false
	shift.include_horse = false
	shift.include_centaur = true
	shift.include_human_centaur = false
	shift.include_horse_centaur = false
	shift.subject_count = 5
	var catalog := _make_catalog()
	var queue := ShiftDirector.roll_queue(shift, catalog)
	if queue.size() != 5:
		failures.append("Single-type pool should fill queue, got %d." % queue.size())
		return
	var all_centaur := true
	for plan in queue:
		if plan.subject.true_type != SubjectDef.TrueType.CENTAUR:
			all_centaur = false
			break
	if not all_centaur:
		failures.append("Single-type pool should only produce Centaur subjects.")


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


func _test_dialogue_uniqueness(failures: PackedStringArray) -> void:
	var shift := ShiftDef.new()
	shift.include_human = true
	shift.include_horse = false
	shift.include_centaur = false
	shift.include_human_centaur = false
	shift.include_horse_centaur = false
	shift.subject_count = 2
	var catalog := _make_catalog()
	for attempt in 16:
		var queue := ShiftDirector.roll_queue(shift, catalog)
		if queue.size() != 2:
			failures.append("Dialogue uniqueness: expected 2 Humans, got %d." % queue.size())
			return
		for prompt_index in PROMPT_KEYS.size():
			var first: String = queue[0].question_subtitles[prompt_index]
			var second: String = queue[1].question_subtitles[prompt_index]
			if first == second:
				failures.append(
					"Attempt %d: duplicate %s line '%s' for two Humans."
					% [attempt, PROMPT_KEYS[prompt_index], first]
				)
				return


func _test_sfx_uniqueness(failures: PackedStringArray) -> void:
	var shift := ShiftDef.new()
	shift.include_human = true
	shift.include_horse = false
	shift.include_centaur = false
	shift.include_human_centaur = false
	shift.include_horse_centaur = false
	shift.subject_count = 3
	var catalog := _make_catalog()
	for attempt in 16:
		var queue := ShiftDirector.roll_queue(shift, catalog)
		if queue.size() != 3:
			failures.append("SFX uniqueness: expected 3 Humans, got %d." % queue.size())
			return
		var approach_paths: Array[String] = []
		for plan in queue:
			if plan.approach_stream == null:
				failures.append("SFX uniqueness: missing approach stream.")
				return
			var path: String = plan.approach_stream.resource_path
			if path in approach_paths:
				failures.append(
					"Attempt %d: repeated human approach clip %s before pool exhausted."
					% [attempt, path]
				)
				return
			approach_paths.append(path)


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
	subject.approach_kind = SubjectDef.ClueKind.HUMAN
	subject.knock_kind = SubjectDef.ClueKind.HUMAN
	for prompt_key in PROMPT_KEYS:
		var question := QuestionDef.new()
		question.prompt_key = prompt_key
		subject.questions.append(question)
	return subject
