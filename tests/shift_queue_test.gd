extends SceneTree


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
	_test_encounter_questions(failures)
	_test_json_only_roll(failures)
	_test_type_filter(failures)
	_test_question_uniqueness(failures)
	_test_four_key_uniqueness(failures)
	_test_reply_uniqueness(failures)
	_test_sfx_uniqueness(failures)
	_test_human_centaur_no_lie_when_disabled(failures)
	_test_human_centaur_lies_with_full_chance(failures)
	_test_horse_centaur_lies_independently(failures)
	_test_horse_centaur_lies_with_full_chance(failures)
	_test_non_disguise_types_never_lie(failures)
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


func _test_encounter_questions(failures: PackedStringArray) -> void:
	var shift := ShiftDef.new()
	shift.include_human = true
	shift.include_horse = false
	shift.include_centaur = false
	shift.include_human_centaur = false
	shift.include_horse_centaur = false
	shift.subject_count = 1
	var catalog := _make_catalog()
	var plan := ShiftDirector.roll_queue(shift, catalog)[0]
	if plan.questions.size() != 2:
		failures.append("Human encounter should offer 2 questions, got %d." % plan.questions.size())
		return
	if plan.question_subtitles.size() != 2:
		failures.append("Human encounter should roll 2 replies, got %d." % plan.question_subtitles.size())
		return
	for question in plan.questions:
		if not DialoguePools.has_line(question.prompt_key, SubjectDef.TrueType.HUMAN):
			failures.append("Picked question %s is not applicable to Human." % question.prompt_key)


func _test_json_only_roll(failures: PackedStringArray) -> void:
	var shift := ShiftDef.new()
	shift.include_human = true
	shift.include_horse = false
	shift.include_centaur = false
	shift.include_human_centaur = false
	shift.include_horse_centaur = false
	shift.subject_count = 1
	var catalog := _make_catalog()
	catalog.questions = []
	var plan := ShiftDirector.roll_queue(shift, catalog)[0]
	var applicable := DialoguePools.applicable_keys(SubjectDef.TrueType.HUMAN)
	if plan.questions.size() != 2:
		failures.append(
			"JSON-only roll: expected 2 Human questions, got %d." % plan.questions.size()
		)
		return
	for question in plan.questions:
		if question.prompt_key not in applicable:
			failures.append(
				"JSON-only roll: %s is not in applicable_keys(HUMAN)." % question.prompt_key
			)


func _test_type_filter(failures: PackedStringArray) -> void:
	DialoguePools.load_lines({
		"human_only": {"human": ["Human line."]},
		"shared": {"human": ["Human shared."], "horse": ["*Neigh.*"]},
		"empty_horse": {"human": ["Human empty horse."], "horse": []},
		"solo_human": {"human": ["Solo."]},
	})
	var catalog := _make_catalog()
	catalog.questions = []
	var horse_shift := ShiftDef.new()
	horse_shift.include_human = false
	horse_shift.include_horse = true
	horse_shift.include_centaur = false
	horse_shift.include_human_centaur = false
	horse_shift.include_horse_centaur = false
	horse_shift.subject_count = 1
	var horse_plan := ShiftDirector.roll_queue(horse_shift, catalog)[0]
	for question in horse_plan.questions:
		if question.prompt_key == "human_only" or question.prompt_key == "solo_human":
			failures.append("Horse plan offered Human-only key %s." % question.prompt_key)
	if DialoguePools.has_line("empty_horse", SubjectDef.TrueType.HORSE):
		failures.append("empty_horse horse array should be inapplicable.")
	var solo_shift := ShiftDef.new()
	solo_shift.include_human = true
	solo_shift.include_horse = false
	solo_shift.include_centaur = false
	solo_shift.include_human_centaur = false
	solo_shift.include_horse_centaur = false
	solo_shift.subject_count = 1
	DialoguePools.load_lines({"only_one": {"human": ["Only."]}})
	var solo_plan := ShiftDirector.roll_queue(solo_shift, catalog)[0]
	if solo_plan.questions.size() != 1:
		failures.append(
			"One applicable key should yield 1 question, got %d." % solo_plan.questions.size()
		)
	DialoguePools.reload_production_lines()


func _test_four_key_uniqueness(failures: PackedStringArray) -> void:
	DialoguePools.load_lines({
		"fixture_q1": {"human": ["a"]},
		"fixture_q2": {"human": ["b"]},
		"fixture_q3": {"human": ["c"]},
		"fixture_q4": {"human": ["d"]},
	})
	var shift := ShiftDef.new()
	shift.include_human = true
	shift.include_horse = false
	shift.include_centaur = false
	shift.include_human_centaur = false
	shift.include_horse_centaur = false
	shift.subject_count = 3
	var catalog := _make_catalog()
	catalog.questions = []
	for attempt in 16:
		var queue := ShiftDirector.roll_queue(shift, catalog)
		if queue.size() != 3:
			failures.append("Four-key uniqueness: expected 3 Humans, got %d." % queue.size())
			DialoguePools.reload_production_lines()
			return
		var encounter_keys: Array = []
		for plan_index in queue.size():
			var plan: EncounterPlan = queue[plan_index]
			var keys: Array[String] = []
			for question in plan.questions:
				keys.append(question.prompt_key)
			if keys.size() >= 2 and keys[0] == keys[1]:
				failures.append(
					"Four-key attempt %d encounter %d: duplicate keys in one Encounter."
					% [attempt, plan_index]
				)
				DialoguePools.reload_production_lines()
				return
			encounter_keys.append(keys)
		var first: Array = encounter_keys[0]
		var second: Array = encounter_keys[1]
		for key in first:
			if key in second:
				failures.append(
					"Four-key attempt %d: encounters 1 and 2 share key %s." % [attempt, key]
				)
				DialoguePools.reload_production_lines()
				return
	DialoguePools.reload_production_lines()


func _test_question_uniqueness(failures: PackedStringArray) -> void:
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
			failures.append("Question uniqueness: expected 3 Humans, got %d." % queue.size())
			return
		for plan_index in queue.size():
			var plan: EncounterPlan = queue[plan_index]
			var keys: Array[String] = []
			for question in plan.questions:
				keys.append(question.prompt_key)
			if keys.size() >= 2 and keys[0] == keys[1]:
				failures.append(
					"Attempt %d encounter %d: duplicate question keys in one Encounter."
					% [attempt, plan_index]
				)
				return


func _test_reply_uniqueness(failures: PackedStringArray) -> void:
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
			failures.append("Reply uniqueness: expected 2 Humans, got %d." % queue.size())
			return
		for plan in queue:
			if plan.questions.size() != plan.question_subtitles.size():
				failures.append("Reply uniqueness: question and subtitle counts should match.")
				return
		var seen_by_prompt := {}
		for plan in queue:
			for i in plan.questions.size():
				var prompt_key := plan.questions[i].prompt_key
				if not seen_by_prompt.has(prompt_key):
					seen_by_prompt[prompt_key] = []
				var line: String = plan.question_subtitles[i]
				if line in seen_by_prompt[prompt_key]:
					failures.append(
						"Attempt %d: duplicate %s reply '%s' for two Humans."
						% [attempt, prompt_key, line]
					)
					return
				seen_by_prompt[prompt_key].append(line)


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


const LIE_TEST_LINES := {
	"are_you_a_horse": {
		"human": ["HUMAN_AH"],
		"horse": ["HORSE_AH"],
		"human_centaur": ["HC_AH"],
		"horse_centaur": ["HORSEC_AH"],
	},
	"whats_your_name": {
		"human": ["HUMAN_NAME"],
		"horse": ["HORSE_NAME"],
		"human_centaur": ["HC_NAME"],
		"horse_centaur": ["HORSEC_NAME"],
	},
}


func _load_lie_test_lines() -> void:
	DialoguePools.load_lines(LIE_TEST_LINES.duplicate(true))


func _human_centaur_lie_shift() -> ShiftDef:
	var shift := ShiftDef.new()
	shift.include_human = false
	shift.include_horse = false
	shift.include_centaur = false
	shift.include_human_centaur = true
	shift.include_horse_centaur = false
	shift.subject_count = 1
	return shift


func _horse_centaur_lie_shift() -> ShiftDef:
	var shift := ShiftDef.new()
	shift.include_human = false
	shift.include_horse = false
	shift.include_centaur = false
	shift.include_human_centaur = false
	shift.include_horse_centaur = true
	shift.subject_count = 1
	return shift


func _line_from_pool(prompt_key: String, true_type: SubjectDef.TrueType) -> Array:
	var prompt := LIE_TEST_LINES.get(prompt_key, {}) as Dictionary
	match true_type:
		SubjectDef.TrueType.HUMAN:
			return prompt.get("human", []) as Array
		SubjectDef.TrueType.HORSE:
			return prompt.get("horse", []) as Array
		SubjectDef.TrueType.HUMAN_CENTAUR:
			return prompt.get("human_centaur", []) as Array
		SubjectDef.TrueType.HORSE_CENTAUR:
			return prompt.get("horse_centaur", []) as Array
		_:
			return []


func _test_human_centaur_no_lie_when_disabled(failures: PackedStringArray) -> void:
	_load_lie_test_lines()
	var shift := _human_centaur_lie_shift()
	var plan := ShiftDirector.roll_queue(shift, _make_catalog())[0]
	if plan.is_lying:
		failures.append("Human Centaur with can-lie off should not lie.")
	if plan.lie_slot != -1:
		failures.append("Human Centaur with can-lie off should not set lie_slot.")
	for i in plan.question_subtitles.size():
		var prompt_key := plan.questions[i].prompt_key
		var line: String = plan.question_subtitles[i]
		if not _line_from_pool(prompt_key, SubjectDef.TrueType.HUMAN_CENTAUR).has(line):
			failures.append(
				"Human Centaur with can-lie off should use human_centaur pool, got '%s'." % line
			)
	DialoguePools.reload_production_lines()


func _test_human_centaur_lies_with_full_chance(failures: PackedStringArray) -> void:
	_load_lie_test_lines()
	var shift := _human_centaur_lie_shift()
	shift.human_centaur_can_lie = true
	shift.human_centaur_lie_chance = 1.0
	var plan := ShiftDirector.roll_queue(shift, _make_catalog())[0]
	if not plan.is_lying:
		failures.append("Human Centaur with chance 1 should lie.")
	if plan.lie_slot < 0 or plan.lie_slot >= plan.questions.size():
		failures.append("Human Centaur with chance 1 should set a valid lie_slot.")
	var human_lines := 0
	var disguise_lines := 0
	for i in plan.question_subtitles.size():
		var prompt_key := plan.questions[i].prompt_key
		var line: String = plan.question_subtitles[i]
		if _line_from_pool(prompt_key, SubjectDef.TrueType.HUMAN).has(line):
			human_lines += 1
		elif _line_from_pool(prompt_key, SubjectDef.TrueType.HUMAN_CENTAUR).has(line):
			disguise_lines += 1
		else:
			failures.append("Human Centaur lie test got unexpected line '%s'." % line)
	if human_lines != 1 or disguise_lines != 1:
		failures.append(
			"Human Centaur with chance 1 should have exactly one Human and one disguise line."
		)
	DialoguePools.reload_production_lines()


func _test_horse_centaur_lies_independently(failures: PackedStringArray) -> void:
	_load_lie_test_lines()
	var shift := ShiftDef.new()
	shift.include_human = false
	shift.include_horse = false
	shift.include_centaur = false
	shift.include_human_centaur = true
	shift.include_horse_centaur = true
	shift.subject_count = 2
	shift.human_centaur_can_lie = true
	shift.human_centaur_lie_chance = 1.0
	shift.horse_centaur_can_lie = false
	var queue := ShiftDirector.roll_queue(shift, _make_catalog())
	if queue.size() != 2:
		failures.append("Independent lie test expected 2 plans, got %d." % queue.size())
		return
	var hc_plan: EncounterPlan = null
	var horse_c_plan: EncounterPlan = null
	for plan in queue:
		if plan.subject.true_type == SubjectDef.TrueType.HUMAN_CENTAUR:
			hc_plan = plan
		elif plan.subject.true_type == SubjectDef.TrueType.HORSE_CENTAUR:
			horse_c_plan = plan
	if hc_plan == null or horse_c_plan == null:
		failures.append("Independent lie test missing Human Centaur or Horse Centaur plan.")
		return
	if not hc_plan.is_lying:
		failures.append("Human Centaur should lie when enabled at chance 1.")
	if horse_c_plan.is_lying:
		failures.append("Horse Centaur should not lie when can-lie is off.")
	if horse_c_plan.lie_slot != -1:
		failures.append("Horse Centaur with can-lie off should not set lie_slot.")
	for i in horse_c_plan.question_subtitles.size():
		var prompt_key := horse_c_plan.questions[i].prompt_key
		var line: String = horse_c_plan.question_subtitles[i]
		if not _line_from_pool(prompt_key, SubjectDef.TrueType.HORSE_CENTAUR).has(line):
			failures.append(
				"Horse Centaur with can-lie off should use horse_centaur pool, got '%s'." % line
			)
	DialoguePools.reload_production_lines()


func _test_horse_centaur_lies_with_full_chance(failures: PackedStringArray) -> void:
	_load_lie_test_lines()
	var shift := _horse_centaur_lie_shift()
	shift.horse_centaur_can_lie = true
	shift.horse_centaur_lie_chance = 1.0
	var plan := ShiftDirector.roll_queue(shift, _make_catalog())[0]
	if not plan.is_lying:
		failures.append("Horse Centaur with chance 1 should lie.")
	var horse_lines := 0
	var disguise_lines := 0
	for i in plan.question_subtitles.size():
		var prompt_key := plan.questions[i].prompt_key
		var line: String = plan.question_subtitles[i]
		if _line_from_pool(prompt_key, SubjectDef.TrueType.HORSE).has(line):
			horse_lines += 1
		elif _line_from_pool(prompt_key, SubjectDef.TrueType.HORSE_CENTAUR).has(line):
			disguise_lines += 1
		else:
			failures.append("Horse Centaur lie test got unexpected line '%s'." % line)
	if horse_lines != 1 or disguise_lines != 1:
		failures.append(
			"Horse Centaur with chance 1 should have exactly one Horse and one disguise line."
		)
	DialoguePools.reload_production_lines()


func _test_non_disguise_types_never_lie(failures: PackedStringArray) -> void:
	_load_lie_test_lines()
	var shift := ShiftDef.new()
	shift.include_human = true
	shift.include_horse = true
	shift.include_centaur = true
	shift.include_human_centaur = false
	shift.include_horse_centaur = false
	shift.subject_count = 3
	shift.human_centaur_can_lie = true
	shift.human_centaur_lie_chance = 1.0
	shift.horse_centaur_can_lie = true
	shift.horse_centaur_lie_chance = 1.0
	var queue := ShiftDirector.roll_queue(shift, _make_catalog())
	for plan in queue:
		if plan.is_lying:
			failures.append(
				"%s should never lie."
				% SubjectDef.TrueType.keys()[plan.subject.true_type]
			)
		if plan.lie_slot != -1:
			failures.append(
				"%s should not set lie_slot."
				% SubjectDef.TrueType.keys()[plan.subject.true_type]
			)
	DialoguePools.reload_production_lines()


func _make_catalog() -> SubjectCatalog:
	var catalog := SubjectCatalog.new()
	catalog.human = _stub_subject(SubjectDef.TrueType.HUMAN)
	catalog.horse = _stub_subject(SubjectDef.TrueType.HORSE)
	catalog.centaur = _stub_subject(SubjectDef.TrueType.CENTAUR)
	catalog.human_centaur = _stub_subject(SubjectDef.TrueType.HUMAN_CENTAUR)
	catalog.horse_centaur = _stub_subject(SubjectDef.TrueType.HORSE_CENTAUR)
	catalog.questions = _make_questions()
	return catalog


func _make_questions() -> Array[QuestionDef]:
	var questions: Array[QuestionDef] = []
	for prompt_key in ["are_you_a_horse", "whats_your_name"]:
		var question := QuestionDef.new()
		question.prompt_key = prompt_key
		questions.append(question)
	return questions


func _stub_subject(true_type: SubjectDef.TrueType) -> SubjectDef:
	var subject := SubjectDef.new()
	subject.true_type = true_type
	subject.approach_kind = SubjectDef.ClueKind.HUMAN
	subject.knock_kind = SubjectDef.ClueKind.HUMAN
	return subject
