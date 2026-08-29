class_name DialoguePools
extends RefCounted

const LINES_PATH := "res://resources/dialogue/subject_lines.json"

static var _lines: Dictionary = {}
static var _loaded := false


static func choose_line(pool: Array, exclude: Array = []) -> String:
	if pool.is_empty():
		return ""
	var available: Array = []
	for line in pool:
		if line not in exclude:
			available.append(line)
	if available.is_empty():
		return pool[randi() % pool.size()] as String
	return available[randi() % available.size()] as String


static func pick(
	prompt_key: String,
	true_type: SubjectDef.TrueType,
	exclude: Array = []
) -> String:
	_ensure_loaded()
	if prompt_key.is_empty():
		return ""
	var prompt := _lines.get(prompt_key, {}) as Dictionary
	var type_key := _type_key(true_type)
	var pool: Array = prompt.get(type_key, [])
	if pool.is_empty():
		return ""
	return choose_line(pool, exclude)


static func has_line(prompt_key: String, true_type: SubjectDef.TrueType) -> bool:
	_ensure_loaded()
	if prompt_key.is_empty():
		return false
	var prompt := _lines.get(prompt_key, {}) as Dictionary
	var pool: Array = prompt.get(_type_key(true_type), [])
	return not pool.is_empty()


static func applicable_keys(true_type: SubjectDef.TrueType) -> Array[String]:
	_ensure_loaded()
	var keys: Array[String] = []
	for prompt_key in _lines.keys():
		if has_line(prompt_key, true_type):
			keys.append(prompt_key)
	keys.sort()
	return keys


static func prompt_keys() -> Array[String]:
	_ensure_loaded()
	var keys: Array[String] = []
	for prompt_key in _lines.keys():
		keys.append(prompt_key)
	keys.sort()
	return keys


static func load_lines(data: Dictionary) -> void:
	_lines = data
	_loaded = true


static func reload_production_lines() -> void:
	_loaded = false
	_lines.clear()
	_ensure_loaded()


static func pick_keys(pool: Array[String], used: Array, count: int) -> Array[String]:
	if pool.is_empty() or count <= 0:
		return []
	var picked: Array[String] = []
	var used_keys: Array = used.duplicate()
	for _i in count:
		if pool.size() == 1 and not picked.is_empty():
			break
		var unused := _unused_keys(pool, used_keys, picked)
		if unused.is_empty():
			used_keys.clear()
			unused = _unused_keys(pool, used_keys, picked)
		if unused.is_empty():
			break
		var choice: String = unused[randi() % unused.size()]
		picked.append(choice)
		used_keys.append(choice)
	return picked


static func _unused_keys(
	pool: Array[String],
	used: Array,
	exclude_picked: Array[String]
) -> Array[String]:
	var unused: Array[String] = []
	for key in pool:
		if key in used:
			continue
		if key in exclude_picked:
			continue
		unused.append(key)
	return unused


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
