class_name VerdictPools
extends RefCounted

const LINES_PATH := "res://resources/dialogue/verdict_lines.json"

static var _lines: Dictionary = {}
static var _loaded := false


static func pick(accepted: bool, correct: bool, true_type: SubjectDef.TrueType) -> Dictionary:
	_ensure_loaded()
	var bucket_key := _bucket_key(accepted, correct)
	var bucket: Variant = _lines.get(bucket_key, null)
	var pool: Array = []
	if bucket is Dictionary:
		pool = bucket.get(_type_key(true_type), []) as Array
	elif bucket is Array:
		pool = bucket as Array
	if pool.is_empty():
		return {"text": "", "sfx": ""}
	return _normalize_entry(pool[randi() % pool.size()])


static func has_line(accepted: bool, correct: bool, true_type: SubjectDef.TrueType) -> bool:
	_ensure_loaded()
	var bucket_key := _bucket_key(accepted, correct)
	var bucket: Variant = _lines.get(bucket_key, null)
	if bucket is Dictionary:
		var pool: Array = bucket.get(_type_key(true_type), []) as Array
		return not pool.is_empty()
	if bucket is Array:
		return not (bucket as Array).is_empty()
	return false


static func _bucket_key(accepted: bool, correct: bool) -> String:
	if accepted:
		return "correct_accept" if correct else "incorrect_accept"
	return "correct_reject" if correct else "incorrect_reject"


static func _normalize_entry(entry: Variant) -> Dictionary:
	if entry is Dictionary:
		var dict := entry as Dictionary
		return {
			"text": str(dict.get("text", "")),
			"sfx": str(dict.get("sfx", "")),
		}
	if entry is String:
		return {"text": entry as String, "sfx": ""}
	return {"text": "", "sfx": ""}


static func _ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	if not FileAccess.file_exists(LINES_PATH):
		push_warning("VerdictPools: missing %s." % LINES_PATH)
		return
	var file := FileAccess.open(LINES_PATH, FileAccess.READ)
	if file == null:
		push_warning("VerdictPools: could not open %s." % LINES_PATH)
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if parsed is Dictionary:
		_lines = parsed
	else:
		push_warning("VerdictPools: invalid JSON in %s." % LINES_PATH)


static func _type_key(true_type: SubjectDef.TrueType) -> String:
	match true_type:
		SubjectDef.TrueType.HUMAN:
			return "human"
		SubjectDef.TrueType.HORSE:
			return "horse"
		_:
			return ""
