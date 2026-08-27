class_name DialoguePools
extends RefCounted

const LINES_PATH := "res://resources/dialogue/subject_lines.json"

static var _lines: Dictionary = {}
static var _loaded := false


static func pick(prompt_key: String, true_type: SubjectDef.TrueType) -> String:
	_ensure_loaded()
	if prompt_key.is_empty():
		return ""
	var prompt := _lines.get(prompt_key, {}) as Dictionary
	var type_key := _type_key(true_type)
	var pool: Array = prompt.get(type_key, [])
	if pool.is_empty():
		return ""
	return pool[randi() % pool.size()] as String


static func has_line(prompt_key: String, true_type: SubjectDef.TrueType) -> bool:
	_ensure_loaded()
	if prompt_key.is_empty():
		return false
	var prompt := _lines.get(prompt_key, {}) as Dictionary
	var pool: Array = prompt.get(_type_key(true_type), [])
	return not pool.is_empty()


static func _ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	if not FileAccess.file_exists(LINES_PATH):
		push_warning("DialoguePools: missing %s." % LINES_PATH)
		return
	var file := FileAccess.open(LINES_PATH, FileAccess.READ)
	if file == null:
		push_warning("DialoguePools: could not open %s." % LINES_PATH)
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if parsed is Dictionary:
		_lines = parsed
	else:
		push_warning("DialoguePools: invalid JSON in %s." % LINES_PATH)


static func _type_key(true_type: SubjectDef.TrueType) -> String:
	match true_type:
		SubjectDef.TrueType.HUMAN:
			return "human"
		SubjectDef.TrueType.HORSE:
			return "horse"
		SubjectDef.TrueType.CENTAUR:
			return "centaur"
		SubjectDef.TrueType.HORSE_CENTAUR:
			return "horse_centaur"
		SubjectDef.TrueType.HUMAN_CENTAUR:
			return "human_centaur"
		_:
			return ""
