class_name ClueSfx
extends RefCounted

const SFX_DIR := "res://sfx"
const POOL_PREFIXES := {
	&"human_approach": "human_approach_",
	&"human_knock": "human_knock_",
	&"horse_approach": "horse_approach_",
	&"horse_knock": "horse_knock_",
}

static var _streams_by_pool: Dictionary = {}
static var _last_path_by_pool: Dictionary = {}


static func pool_id(kind: SubjectDef.ClueKind, is_approach: bool) -> StringName:
	var species := "human" if kind == SubjectDef.ClueKind.HUMAN else "horse"
	var cue := "approach" if is_approach else "knock"
	return StringName("%s_%s" % [species, cue])


static func pick(
	kind: SubjectDef.ClueKind,
	is_approach: bool,
	used: Array = []
) -> AudioStream:
	var id := pool_id(kind, is_approach)
	var streams := _streams_for(id)
	if streams.is_empty():
		push_warning("ClueSfx: no .wav clips in pool '%s'." % id)
		return null
	var last_path := str(_last_path_by_pool.get(id, ""))
	var chosen := _choose_stream(streams, last_path, used)
	if chosen != null:
		_last_path_by_pool[id] = chosen.resource_path
	return chosen


static func choose_path(
	paths: PackedStringArray,
	last_path: String = "",
	used: Array = []
) -> String:
	if paths.is_empty():
		return ""
	var candidates: PackedStringArray = []
	for path in paths:
		if path not in used:
			candidates.append(path)
	if candidates.is_empty():
		candidates = paths.duplicate()
	var options: PackedStringArray = []
	for path in candidates:
		if path != last_path:
			options.append(path)
	if options.is_empty():
		return candidates[0]
	return options[randi() % options.size()]


static func is_pool_wav(file_name: String, prefix: String) -> bool:
	var lower := file_name.to_lower()
	return lower.ends_with(".wav") and lower.begins_with(prefix)


static func _choose_stream(
	streams: Array[AudioStream],
	last_path: String,
	used: Array = []
) -> AudioStream:
	var paths: PackedStringArray = []
	var by_path: Dictionary = {}
	for stream in streams:
		if stream == null:
			continue
		paths.append(stream.resource_path)
		by_path[stream.resource_path] = stream
	var chosen_path := choose_path(paths, last_path, used)
	if chosen_path.is_empty():
		return null
	return by_path.get(chosen_path) as AudioStream


static func _streams_for(id: StringName) -> Array[AudioStream]:
	if _streams_by_pool.has(id):
		return _streams_by_pool[id] as Array[AudioStream]
	var prefix := str(POOL_PREFIXES.get(id, ""))
	var loaded: Array[AudioStream] = []
	if prefix.is_empty():
		_streams_by_pool[id] = loaded
		return loaded
	var names := ResourceLoader.list_directory(SFX_DIR)
	if names.is_empty():
		push_warning("ClueSfx: could not list %s." % SFX_DIR)
		_streams_by_pool[id] = loaded
		return loaded
	names.sort()
	for name in names:
		if name.ends_with("/"):
			continue
		var file_name := name.get_file()
		if file_name.ends_with(".remap"):
			file_name = file_name.trim_suffix(".remap")
		if not is_pool_wav(file_name, prefix):
			continue
		var stream := load("%s/%s" % [SFX_DIR, file_name]) as AudioStream
		if stream != null:
			loaded.append(stream)
	_streams_by_pool[id] = loaded
	return loaded
