extends SceneTree

const PROMPT_KEYS := ["are_you_a_horse", "whats_your_name"]
const BANNED_TYPES := [
	SubjectDef.TrueType.CENTAUR,
	SubjectDef.TrueType.HORSE_CENTAUR,
	SubjectDef.TrueType.HUMAN_CENTAUR,
]
const ALLOWED_TYPES := [SubjectDef.TrueType.HUMAN, SubjectDef.TrueType.HORSE]
const HYBRID_TYPES := [
	SubjectDef.TrueType.CENTAUR,
	SubjectDef.TrueType.HORSE_CENTAUR,
	SubjectDef.TrueType.HUMAN_CENTAUR,
]


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var failures: PackedStringArray = []
	_test_human_centaur_roll(failures)
	_test_banned_scoring(failures)
	_test_dialogue_coverage(failures)
	if failures.is_empty():
		print("Subject behavior matrix: all checks passed.")
		quit(0)
	else:
		for failure in failures:
			printerr(failure)
		print("Subject behavior matrix: %d check(s) failed." % failures.size())
		quit(1)


func _test_human_centaur_roll(failures: PackedStringArray) -> void:
	for true_type in HYBRID_TYPES:
		var appearance := ModelCatalog.roll(true_type)
		if not appearance.has(ModelCatalog.HUMAN_KEY):
			failures.append("%s roll missing human_scene." % SubjectDef.TrueType.keys()[true_type])
		if not appearance.has(ModelCatalog.HORSE_KEY):
			failures.append("%s roll missing horse_scene." % SubjectDef.TrueType.keys()[true_type])


func _test_banned_scoring(failures: PackedStringArray) -> void:
	for true_type in BANNED_TYPES:
		if not SubjectDef.is_banned(true_type):
			failures.append("%s should be banned." % SubjectDef.TrueType.keys()[true_type])
	for true_type in ALLOWED_TYPES:
		if SubjectDef.is_banned(true_type):
			failures.append("%s should not be banned." % SubjectDef.TrueType.keys()[true_type])


func _test_dialogue_coverage(failures: PackedStringArray) -> void:
	for prompt_key in PROMPT_KEYS:
		for true_type in SubjectDef.TrueType.values():
			if not DialoguePools.has_line(prompt_key, true_type as SubjectDef.TrueType):
				failures.append(
					"Missing dialogue for %s / %s."
					% [prompt_key, SubjectDef.TrueType.keys()[true_type as int]]
				)
			var line := DialoguePools.pick(prompt_key, true_type as SubjectDef.TrueType)
			if line.is_empty():
				failures.append(
					"Empty dialogue pick for %s / %s."
					% [prompt_key, SubjectDef.TrueType.keys()[true_type as int]]
				)
