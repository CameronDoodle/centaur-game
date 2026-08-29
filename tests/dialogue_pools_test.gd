extends SceneTree

const PROMPT_KEYS := ["are_you_a_horse", "whats_your_name"]


func _initialize() -> void:
	var failures: PackedStringArray = []
	_test_choose_line_prefers_unused(failures)
	_test_choose_line_reuses_when_exhausted(failures)
	_test_has_line_missing_and_empty(failures)
	_test_applicable_keys(failures)
	_test_empty_type_inapplicable(failures)
	_test_json_only_type_filter(failures)
	_test_pick_keys_from_remaining(failures)
	_test_pick_keys_wraps_after_exhaustion(failures)
	_test_pick_keys_no_duplicates_in_one_pick(failures)
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


func _test_has_line_missing_and_empty(failures: PackedStringArray) -> void:
	if DialoguePools.has_line("are_you_a_horse", SubjectDef.TrueType.HUMAN):
		pass
	else:
		failures.append("are_you_a_horse should be applicable for Human.")
	if DialoguePools.has_line("__missing_prompt__", SubjectDef.TrueType.HUMAN):
		failures.append("Missing prompt key should be inapplicable.")


func _test_empty_type_inapplicable(failures: PackedStringArray) -> void:
	DialoguePools.load_lines({
		"empty_horse": {"human": ["Human line."], "horse": []},
		"missing_horse": {"human": ["Human only."]},
	})
	if DialoguePools.has_line("empty_horse", SubjectDef.TrueType.HORSE):
		failures.append("empty_horse should be inapplicable for Horse.")
	if DialoguePools.has_line("missing_horse", SubjectDef.TrueType.HORSE):
		failures.append("missing_horse should be inapplicable for Horse.")
	if DialoguePools.has_line("__missing_prompt__", SubjectDef.TrueType.HUMAN):
		failures.append("Missing prompt key should be inapplicable.")
	DialoguePools.reload_production_lines()


func _test_json_only_type_filter(failures: PackedStringArray) -> void:
	DialoguePools.load_lines({
		"are_you_a_horse": {"human": ["No."], "horse": ["*Neigh.*"]},
		"human_only": {"human": ["Khakis."]},
	})
	var human_keys := DialoguePools.applicable_keys(SubjectDef.TrueType.HUMAN)
	if "human_only" not in human_keys:
		failures.append("Human applicable_keys should include JSON-only human_only.")
	if "are_you_a_horse" not in human_keys:
		failures.append("Human applicable_keys should include are_you_a_horse.")
	var horse_keys := DialoguePools.applicable_keys(SubjectDef.TrueType.HORSE)
	if "human_only" in horse_keys:
		failures.append("Horse applicable_keys should exclude human_only.")
	if "are_you_a_horse" not in horse_keys:
		failures.append("Horse applicable_keys should include are_you_a_horse.")
	DialoguePools.reload_production_lines()


func _test_applicable_keys(failures: PackedStringArray) -> void:
	var keys := DialoguePools.applicable_keys(SubjectDef.TrueType.HUMAN)
	for prompt_key in PROMPT_KEYS:
		if prompt_key not in keys:
			failures.append("Human applicable_keys missing %s." % prompt_key)


func _test_pick_keys_from_remaining(failures: PackedStringArray) -> void:
	var pool: Array[String] = ["are_you_a_horse", "whats_your_name"]
	var picked := DialoguePools.pick_keys(pool, [], 2)
	if picked.size() != 2:
		failures.append("pick_keys should return 2 keys when pool has 2, got %d." % picked.size())
		return
	if picked[0] == picked[1]:
		failures.append("pick_keys should not duplicate keys in one pick.")


func _test_pick_keys_wraps_after_exhaustion(failures: PackedStringArray) -> void:
	var pool: Array[String] = ["are_you_a_horse", "whats_your_name"]
	var used: Array = ["are_you_a_horse", "whats_your_name"]
	var picked := DialoguePools.pick_keys(pool, used, 2)
	if picked.is_empty():
		failures.append("pick_keys should wrap and still return keys after exhaustion.")
		return
	if picked.size() != 2:
		failures.append("pick_keys should return 2 keys after wrap, got %d." % picked.size())


func _test_pick_keys_no_duplicates_in_one_pick(failures: PackedStringArray) -> void:
	var pool: Array[String] = ["are_you_a_horse", "whats_your_name"]
	for _attempt in 32:
		var picked := DialoguePools.pick_keys(pool, ["are_you_a_horse"], 2)
		if picked.size() != 2:
			failures.append("pick_keys with one used should still return 2 keys.")
			return
		if picked[0] == picked[1]:
			failures.append("pick_keys duplicated a key within one pick.")
			return
