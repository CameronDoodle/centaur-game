class_name AnimationHints
extends RefCounted

## Matches locomotion clip names by last path segment (`Walk`, `Armature|Walk`,
## `Man_Walk` when the hint is `Walk`) and keeps the chosen clip looping while
## that intent lasts. Trailing rest holds (Kenney Walk pads a stride out to 2.67s)
## are wrapped in software via seek so exported builds never mutate imported
## AnimationLibrary resources.
## Web `play()` may reject the list string (`HumanArmature|Man_Walk`); resolve a
## key `has_animation()` accepts, retry if a first tick had an empty list, and
## only then host a duplicate on a sibling `LocomotionPlayer`.

const SIBLING_NAME := "LocomotionPlayer"

var _player: AnimationPlayer
var _imported: AnimationPlayer
var _hints: PackedStringArray = PackedStringArray()
var _loop_end: float = 0.0


static func clip_leaf(clip_name: String) -> String:
	var slash := clip_name.rfind("/")
	var pipe := clip_name.rfind("|")
	var sep := maxi(slash, pipe)
	if sep < 0:
		return clip_name
	return clip_name.substr(sep + 1)


static func matches(clip_name: String, hint: String) -> bool:
	var leaf := clip_leaf(clip_name)
	if leaf == hint:
		return true
	return not hint.is_empty() and leaf == "Man_" + hint


static func find_clip(player: AnimationPlayer, hints: PackedStringArray) -> String:
	if player == null:
		return ""
	for hint in hints:
		for candidate in player.get_animation_list():
			if matches(candidate, hint):
				return candidate
	return ""


static func playable_key(player: AnimationPlayer, clip: String) -> String:
	if player == null or clip.is_empty():
		return ""
	var slash := clip.replace("|", "/")
	var leaf := clip_leaf(clip)
	for candidate in [clip, slash, leaf]:
		if player.has_animation(candidate):
			return candidate
	return clip


static func trailing_hold_start(animation: Animation) -> float:
	if animation == null:
		return 0.0
	var hold_start := 0.0
	var found_hold := false
	for track_index in animation.get_track_count():
		var key_count := animation.track_get_key_count(track_index)
		if key_count < 2:
			continue
		var last_index := key_count - 1
		var last_time := animation.track_get_key_time(track_index, last_index)
		if last_time < animation.length - 0.08:
			continue
		var last_value = animation.track_get_key_value(track_index, last_index)
		var changed_index := last_index - 1
		while changed_index >= 0 and _values_match(
			animation.track_get_key_value(track_index, changed_index),
			last_value
		):
			changed_index -= 1
		if changed_index < 0 or changed_index >= last_index - 1:
			continue
		var start := animation.track_get_key_time(track_index, changed_index + 1)
		if animation.length - start < animation.length * 0.25:
			continue
		if not found_hold or start > hold_start:
			hold_start = start
		found_hold = true
	if not found_hold:
		return animation.length
	return hold_start


func play_looped(player: AnimationPlayer, hints: PackedStringArray) -> String:
	_imported = player
	_bind(player)
	_hints = PackedStringArray(hints)
	return _restart()


func tick() -> void:
	if _hints.is_empty():
		return
	if _player == null or not is_instance_valid(_player):
		return
	if not _player.is_playing():
		_restart()
		return
	if _loop_end <= 0.0:
		return
	if _player.current_animation_position >= _loop_end:
		_player.seek(0.0, true)


func _bind(player: AnimationPlayer) -> void:
	if _player == player:
		return
	_unbind_player()
	_player = player
	if _player == null or not is_instance_valid(_player):
		_player = null
		return
	if not _player.animation_finished.is_connected(_on_animation_finished):
		_player.animation_finished.connect(_on_animation_finished)


func _unbind_player() -> void:
	if _player and is_instance_valid(_player) and _player.animation_finished.is_connected(_on_animation_finished):
		_player.animation_finished.disconnect(_on_animation_finished)
	_player = null
	_loop_end = 0.0


func _record_loop_end(player: AnimationPlayer, clip: String) -> void:
	_loop_end = 0.0
	if player == null or clip.is_empty():
		return
	var animation := _animation_named(player, clip)
	if animation == null:
		return
	var hold_start := trailing_hold_start(animation)
	var needs_trim := (
		hold_start >= 0.2
		and hold_start + 0.05 < animation.length
		and hold_start <= animation.length * 0.9
	)
	_loop_end = hold_start if needs_trim else animation.length


func _restart() -> String:
	var source := _imported if _imported and is_instance_valid(_imported) else _player
	if source == null or not is_instance_valid(source):
		return ""
	var clip := find_clip(source, _hints)
	if clip.is_empty():
		return ""
	var key := playable_key(source, clip)
	if source.active:
		_bind(source)
		_record_loop_end(source, key)
		source.play(key)
		if source.is_playing():
			return key
	return _play_on_sibling(source, clip, key)


func _play_on_sibling(imported: AnimationPlayer, clip: String, key: String) -> String:
	var sibling := _ensure_sibling(imported)
	if sibling == null:
		return ""
	var leaf := clip_leaf(clip)
	if leaf.is_empty():
		return ""
	if not _install_sibling_clip(imported, sibling, clip, key, leaf):
		return ""
	imported.active = false
	_bind(sibling)
	_record_loop_end(sibling, leaf)
	sibling.play(leaf)
	return leaf if sibling.is_playing() else ""


func _ensure_sibling(imported: AnimationPlayer) -> AnimationPlayer:
	var parent := imported.get_parent()
	if parent == null:
		return null
	var existing := parent.get_node_or_null(SIBLING_NAME) as AnimationPlayer
	if existing:
		return existing
	var sibling := AnimationPlayer.new()
	sibling.name = SIBLING_NAME
	sibling.root_node = imported.root_node
	sibling.callback_mode_process = imported.callback_mode_process
	parent.add_child(sibling)
	return sibling


func _install_sibling_clip(
	imported: AnimationPlayer,
	sibling: AnimationPlayer,
	clip: String,
	key: String,
	leaf: String
) -> bool:
	if sibling.has_animation(leaf):
		return true
	var animation := _animation_named(imported, key)
	if animation == null:
		animation = _animation_named(imported, clip)
	if animation == null:
		return false
	var library: AnimationLibrary
	if sibling.has_animation_library(""):
		library = sibling.get_animation_library("")
	else:
		library = AnimationLibrary.new()
		sibling.add_animation_library("", library)
	library.add_animation(leaf, animation.duplicate())
	return sibling.has_animation(leaf)


func _animation_named(player: AnimationPlayer, clip: String) -> Animation:
	if player == null or clip.is_empty():
		return null
	if player.has_animation(clip):
		return player.get_animation(clip)
	return null


func _on_animation_finished(_anim_name: StringName) -> void:
	if _hints.is_empty():
		return
	if _player == null or not is_instance_valid(_player):
		return
	if _player.is_playing():
		return
	_restart()


static func _values_match(a, b) -> bool:
	if a == b:
		return true
	if typeof(a) != typeof(b):
		return false
	if a is Vector3:
		return a.is_equal_approx(b)
	if a is Vector2:
		return a.is_equal_approx(b)
	if a is Quaternion:
		return a.is_equal_approx(b)
	if a is Transform3D:
		return a.is_equal_approx(b)
	if a is Basis:
		return a.is_equal_approx(b)
	if a is Color:
		return a.is_equal_approx(b)
	if typeof(a) == TYPE_FLOAT:
		return is_equal_approx(a, b)
	return false
