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
const PRESENTED_FACE_CASES := {
	SubjectDef.TrueType.HUMAN: SubjectDef.TrueType.HUMAN,
	SubjectDef.TrueType.HORSE: SubjectDef.TrueType.HORSE,
	SubjectDef.TrueType.CENTAUR: SubjectDef.TrueType.HUMAN,
	SubjectDef.TrueType.HORSE_CENTAUR: SubjectDef.TrueType.HORSE,
	SubjectDef.TrueType.HUMAN_CENTAUR: SubjectDef.TrueType.HUMAN,
}


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var failures: PackedStringArray = []
	_test_human_centaur_roll(failures)
	_test_banned_scoring(failures)
	_test_presented_face_type(failures)
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


func _test_presented_face_type(failures: PackedStringArray) -> void:
	for true_type in PRESENTED_FACE_CASES:
		var expected: SubjectDef.TrueType = PRESENTED_FACE_CASES[true_type]
		var actual := SubjectDef.presented_face_type(true_type)
		if actual != expected:
			failures.append(
				"%s presented_face_type should be %s, got %s."
				% [
					SubjectDef.TrueType.keys()[true_type],
					SubjectDef.TrueType.keys()[expected],
					SubjectDef.TrueType.keys()[actual],
				]
			)


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
