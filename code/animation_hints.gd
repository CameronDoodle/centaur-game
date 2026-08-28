class_name AnimationHints
extends RefCounted

## Matches locomotion clip names by last path segment (`Walk`, `Armature|Walk`,
## `Armature/Walk`) and keeps the chosen clip looping while that intent lasts.
## Trailing rest holds (Kenney Walk pads a stride out to 2.67s) are trimmed so
## a loop does not freeze mid-path.

var _player: AnimationPlayer
var _hints: PackedStringArray = PackedStringArray()


static func clip_leaf(clip_name: String) -> String:
	var slash := clip_name.rfind("/")
	var pipe := clip_name.rfind("|")
	var sep := maxi(slash, pipe)
	if sep < 0:
		return clip_name
	return clip_name.substr(sep + 1)


static func matches(clip_name: String, hint: String) -> bool:
	return clip_leaf(clip_name) == hint


static func find_clip(player: AnimationPlayer, hints: PackedStringArray) -> String:
	if player == null:
		return ""
	for hint in hints:
		for candidate in player.get_animation_list():
			if matches(candidate, hint):
				return candidate
	return ""


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


static func ensure_looped(player: AnimationPlayer, clip: String) -> void:
	if player == null or clip.is_empty():
		return
	var animation := player.get_animation(clip)
	if animation == null:
		return
	var loop_end := trailing_hold_start(animation)
	var needs_trim := (
		loop_end >= 0.2
		and loop_end + 0.05 < animation.length
		and loop_end <= animation.length * 0.9
	)
	var needs_loop := animation.loop_mode != Animation.LOOP_LINEAR
	if not needs_loop and not needs_trim:
		return
	var local := animation.duplicate() as Animation
	if local == null:
		animation.loop_mode = Animation.LOOP_LINEAR
		return
	local.loop_mode = Animation.LOOP_LINEAR
	local.resource_local_to_scene = true
	if needs_trim:
		local.length = loop_end
	_replace_animation(player, clip, local)


func play_looped(player: AnimationPlayer, hints: PackedStringArray) -> String:
	_bind(player)
	_hints = PackedStringArray(hints)
	return _restart()


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


func _restart() -> String:
	if _player == null or not is_instance_valid(_player):
		return ""
	var clip := find_clip(_player, _hints)
	if clip.is_empty():
		return ""
	ensure_looped(_player, clip)
	_player.play(clip)
	return clip


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


static func _replace_animation(player: AnimationPlayer, clip: String, animation: Animation) -> void:
	for library_name in player.get_animation_library_list():
		var library := player.get_animation_library(library_name)
		if library == null:
			continue
		for anim_name in library.get_animation_list():
			var full := String(anim_name)
			if not String(library_name).is_empty():
				full = "%s/%s" % [library_name, anim_name]
			if full != clip:
				continue
			library.remove_animation(anim_name)
			library.add_animation(anim_name, animation)
			return
