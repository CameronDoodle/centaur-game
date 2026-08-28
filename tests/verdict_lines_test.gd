extends SceneTree

const MIN_TYPED_POOL_LINES := 4
const MIN_FLAT_POOL_LINES := 2
const HORSE_ONLY_MARKERS := ["poor horse", "that horse", "they just", "long face"]
const HUMAN_ONLY_MARKERS := ["poor guy", "he was", "he only", "now i feel bad"]


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var failures: PackedStringArray = []
	_test_flat_buckets(failures)
	_test_typed_buckets(failures)
	_test_missing_sfx(failures)
	if failures.is_empty():
		print("Verdict lines: all checks passed.")
		quit(0)
	else:
		for failure in failures:
			printerr(failure)
		print("Verdict lines: %d check(s) failed." % failures.size())
		quit(1)


func _test_flat_buckets(failures: PackedStringArray) -> void:
	_test_bucket(true, false, SubjectDef.TrueType.CENTAUR, MIN_FLAT_POOL_LINES, failures)
	_test_bucket(false, true, SubjectDef.TrueType.CENTAUR, MIN_FLAT_POOL_LINES, failures)


func _test_typed_buckets(failures: PackedStringArray) -> void:
	_test_bucket(true, true, SubjectDef.TrueType.HUMAN, MIN_TYPED_POOL_LINES, failures)
	_test_bucket(true, true, SubjectDef.TrueType.HORSE, MIN_TYPED_POOL_LINES, failures)
	_test_bucket(false, false, SubjectDef.TrueType.HUMAN, MIN_TYPED_POOL_LINES, failures)
	_test_bucket(false, false, SubjectDef.TrueType.HORSE, MIN_TYPED_POOL_LINES, failures)
	_test_typed_separation(true, true, failures)
	_test_typed_separation(false, false, failures)


func _test_bucket(
	accepted: bool,
	correct: bool,
	true_type: SubjectDef.TrueType,
	min_lines: int,
	failures: PackedStringArray
) -> void:
	if not VerdictPools.has_line(accepted, correct, true_type):
		failures.append(
			"Missing verdict bucket for accepted=%s correct=%s type=%s."
			% [accepted, correct, SubjectDef.TrueType.keys()[true_type]]
		)
		return
	var seen: Dictionary = {}
	for _i in 80:
		var verdict := VerdictPools.pick(accepted, correct, true_type)
		var text := str(verdict.get("text", ""))
		if text.is_empty():
			failures.append(
				"Empty verdict pick for accepted=%s correct=%s type=%s."
				% [accepted, correct, SubjectDef.TrueType.keys()[true_type]]
			)
			return
		seen[text] = true
	if seen.size() < min_lines:
		failures.append(
			"Expected at least %d verdict lines for accepted=%s correct=%s type=%s, saw %d."
			% [min_lines, accepted, correct, SubjectDef.TrueType.keys()[true_type], seen.size()]
		)


func _test_typed_separation(accepted: bool, correct: bool, failures: PackedStringArray) -> void:
	for _i in 40:
		var human := str(VerdictPools.pick(accepted, correct, SubjectDef.TrueType.HUMAN).get("text", "")).to_lower()
		var horse := str(VerdictPools.pick(accepted, correct, SubjectDef.TrueType.HORSE).get("text", "")).to_lower()
		for marker in HORSE_ONLY_MARKERS:
			if marker in human:
				failures.append("Human verdict looked horse-only: %s" % human)
				return
		for marker in HUMAN_ONLY_MARKERS:
			if marker in horse:
				failures.append("Horse verdict looked human-only: %s" % horse)
				return


func _test_missing_sfx(failures: PackedStringArray) -> void:
	var verdict := VerdictPools.pick(true, true, SubjectDef.TrueType.HUMAN)
	if not verdict.has("sfx"):
		failures.append("Verdict pick should include sfx key.")
		return
	if str(verdict.get("sfx", "missing")) != "":
		failures.append("Default verdict sfx should be empty when omitted from JSON.")
