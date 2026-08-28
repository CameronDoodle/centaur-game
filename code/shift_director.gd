class_name ShiftDirector
extends Node

signal time_up

const WIN_HEADLINE := "You won!"
const SHIFT_COMPLETE_HEADLINE := "Shift complete."
const CHEAT_KEYS := [KEY_W, KEY_I, KEY_N]
const CHEAT_TIMEOUT := 2.0

@export var roster: ShiftRoster
@export var subject_catalog: SubjectCatalog

var encounter_director: EncounterDirector
var hud: HUD

var score: int = 0
var strikes_used: int = 0
var _shift_index: int = 0
var _queue: Array[SubjectDef] = []
var _subject_index: int = 0
var _time_remaining: float = 0.0
var _shift_active: bool = false
var _waiting_on_encounter: bool = false
var _win_active: bool = false
var _cheat_buffer: Array = []
var _cheat_last_key_time: float = 0.0

var _camera: PlayerCamera
var _title_path: TitlePath
var _title: Node


static func roll_queue(shift: ShiftDef, catalog: SubjectCatalog) -> Array[SubjectDef]:
	var queue: Array[SubjectDef] = []
	if shift == null or catalog == null:
		return queue
	var pool := shift.enabled_types()
	if pool.is_empty() or shift.subject_count <= 0:
		return queue
	var previous_type: SubjectDef.TrueType
	var has_previous := false
	for _i in shift.subject_count:
		var pick_pool := pool
		if has_previous and pool.size() > 1:
			pick_pool = pool.duplicate()
			pick_pool.erase(previous_type)
		var picked: SubjectDef.TrueType = pick_pool.pick_random()
		var subject := catalog.subject_for(picked)
		if subject == null:
			push_warning(
				"ShiftDirector: SubjectCatalog has no SubjectDef for %s."
				% SubjectDef.TrueType.keys()[picked]
			)
			continue
		queue.append(subject)
		previous_type = picked
		has_previous = true
	return queue


static func format_timer_text(seconds: float) -> String:
	var total_seconds := int(ceil(seconds))
	var minutes := total_seconds / 60
	var secs := total_seconds % 60
	return "%02d:%02d" % [minutes, secs]


static func build_next_shift_preview(shift: ShiftDef) -> String:
	if shift == null:
		return ""
	return "Next Shift\nTime: %s\nSubjects: %d\nStrikes allowed: %d" % [
		format_timer_text(shift.shift_timer_seconds),
		shift.subject_count,
		shift.strikes_allowed
	]


static func build_shift_summary(
	reason: String,
	score: int,
	strikes_used: int,
	strikes_allowed: int
) -> String:
	return "%s\n\nScore: %d\nStrikes: %d / %d" % [
		reason,
		score,
		strikes_used,
		strikes_allowed
	]


static func build_shift_end_summary(
	reason: String,
	score: int,
	strikes_used: int,
	strikes_allowed: int,
	has_next_shift: bool,
	next_shift: ShiftDef
) -> String:
	var summary := build_shift_summary(reason, score, strikes_used, strikes_allowed)
	if has_next_shift and next_shift != null:
		var preview := build_next_shift_preview(next_shift)
		if not preview.is_empty():
			summary += "\n\n" + preview
	return summary


static func end_shift_headline(succeeded: bool, has_next_shift: bool) -> String:
	if succeeded and not has_next_shift:
		return WIN_HEADLINE
	if succeeded:
		return SHIFT_COMPLETE_HEADLINE
	return ""


static func should_begin_win(succeeded: bool, has_next_shift: bool) -> bool:
	return succeeded and not has_next_shift


static func cheat_buffer_after_key(
	buffer: Array,
	key: Key,
	cheat_keys: Array = CHEAT_KEYS
) -> Array:
	if cheat_keys.is_empty():
		return []
	if key == cheat_keys[buffer.size()]:
		var next := buffer.duplicate()
		next.append(key)
		return next
	if key == cheat_keys[0]:
		return [key]
	return []


static func is_cheat_sequence(buffer: Array, cheat_keys: Array = CHEAT_KEYS) -> bool:
	return buffer == cheat_keys


func _ready() -> void:
	var parent := get_parent()
	encounter_director = parent.get_node("EncounterDirector") as EncounterDirector
	hud = parent.get_node("HUD") as HUD
	_camera = parent.get_node_or_null("Camera3D") as PlayerCamera
	_title_path = parent.get_node_or_null("world/spawn") as TitlePath
	_title = parent.get_node_or_null("Title")
	call_deferred("_bind_and_start")


func _bind_and_start() -> void:
	encounter_director.encounter_finished.connect(_on_encounter_finished)
	hud.summary_replay_pressed.connect(_start_shift)
	hud.summary_next_pressed.connect(_on_next_shift)


func _unhandled_input(event: InputEvent) -> void:
	if _win_active:
		return
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	var now := Time.get_ticks_msec() / 1000.0
	if not _cheat_buffer.is_empty() and now - _cheat_last_key_time > CHEAT_TIMEOUT:
		_cheat_buffer.clear()
	_cheat_last_key_time = now
	_cheat_buffer = cheat_buffer_after_key(_cheat_buffer, event.keycode)
	if is_cheat_sequence(_cheat_buffer):
		_cheat_buffer.clear()
		_begin_win()
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if not _shift_active:
		return
	if _time_remaining <= 0.0:
		return
	_time_remaining = maxf(_time_remaining - delta, 0.0)
	_update_hud_timer()
	if _time_remaining <= 0.0:
		_on_time_up()


func _current_shift() -> ShiftDef:
	if roster == null or roster.shifts.is_empty():
		return null
	if _shift_index < 0 or _shift_index >= roster.shifts.size():
		return null
	return roster.shifts[_shift_index]


func _has_next_shift() -> bool:
	if roster == null:
		return false
	return _shift_index < roster.shifts.size() - 1


func _start_shift() -> void:
	if _win_active:
		return
	var shift := _current_shift()
	if shift == null:
		push_warning("ShiftDirector: no Shift at roster index %d." % _shift_index)
		return
	if subject_catalog == null:
		push_warning("ShiftDirector: no subject_catalog assigned.")
		return
	if shift.enabled_types().is_empty():
		push_warning("ShiftDirector: Shift %d has no Subject types enabled." % (_shift_index + 1))
		return
	_queue = roll_queue(shift, subject_catalog)
	if _queue.is_empty():
		push_warning("ShiftDirector: rolled an empty Subject queue.")
		return
	score = 0
	strikes_used = 0
	_subject_index = 0
	_time_remaining = shift.shift_timer_seconds
	_shift_active = true
	_waiting_on_encounter = false
	hud.hide_summary()
	hud.hide_reveal()
	hud.show_session_chrome()
	_update_hud_shift()
	_update_hud_stats()
	_update_hud_timer()
	_start_next_encounter()


func _on_next_shift() -> void:
	if not _has_next_shift():
		return
	_shift_index += 1
	_start_shift()


func _start_next_encounter() -> void:
	if not _shift_active:
		return
	var shift := _current_shift()
	if shift == null:
		return
	if _subject_index >= _queue.size():
		_finish_shift_success()
		return
	if strikes_used >= shift.strikes_allowed:
		_end_shift("Out of strikes.", false)
		return
	if _time_remaining <= 0.0:
		_end_shift("Time is up.", false)
		return
	var subject := _queue[_subject_index]
	_subject_index += 1
	_update_hud_subject_progress()
	_waiting_on_encounter = true
	print(
		"[ShiftDirector] Shift %d / %d — subject %d / %d"
		% [_shift_index + 1, roster.shifts.size(), _subject_index, _queue.size()]
	)
	encounter_director.start_encounter(subject)


func _on_encounter_finished(scored: bool, strike: bool, skip_handoff_delay: bool = false) -> void:
	if not _shift_active:
		return
	var shift := _current_shift()
	if shift == null:
		return
	_waiting_on_encounter = false
	if scored:
		score += 1
	if strike:
		strikes_used += 1
	_update_hud_stats()
	if not skip_handoff_delay:
		await get_tree().create_timer(1.0).timeout
	if not _shift_active:
		return
	if strikes_used >= shift.strikes_allowed:
		_end_shift("Out of strikes.", false)
		return
	if _subject_index >= _queue.size():
		_finish_shift_success()
		return
	if _time_remaining <= 0.0:
		return
	_start_next_encounter()


func _on_time_up() -> void:
	if not _shift_active:
		return
	time_up.emit()
	var was_waiting := _waiting_on_encounter
	_shift_active = false
	_waiting_on_encounter = false
	if was_waiting:
		encounter_director.force_miss()
		strikes_used += 1
		_update_hud_stats()
	_end_shift("Time is up.", false)


func _finish_shift_success() -> void:
	if should_begin_win(true, _has_next_shift()):
		_begin_win()
	else:
		_end_shift(SHIFT_COMPLETE_HEADLINE, true)


func _begin_win() -> void:
	if _win_active:
		return
	_win_active = true
	_shift_active = false
	_waiting_on_encounter = false
	encounter_director.force_miss()
	if _title != null and _title.has_method("dismiss"):
		_title.dismiss()
	hud.hide_summary()
	hud.hide_reveal()
	hud.hide_session_chrome()
	hud.hide_investigation()
	hud.show_win()
	if _camera:
		_camera.look_out_window()
	if _title_path:
		_title_path.begin([
			SubjectDef.TrueType.HUMAN_CENTAUR,
			SubjectDef.TrueType.HORSE_CENTAUR,
		])
	print("[ShiftDirector] Win — %s" % WIN_HEADLINE)


func _end_shift(reason: String, succeeded: bool) -> void:
	_shift_active = false
	_waiting_on_encounter = false
	var shift := _current_shift()
	var strikes_allowed := 0
	if shift != null:
		strikes_allowed = shift.strikes_allowed
	var has_next := succeeded and _has_next_shift()
	var next_shift: ShiftDef = null
	if has_next:
		next_shift = roster.shifts[_shift_index + 1]
	var summary := build_shift_end_summary(
		reason,
		score,
		strikes_used,
		strikes_allowed,
		has_next,
		next_shift
	)
	print("[ShiftDirector] %s" % summary.replace("\n", " | "))
	var show_replay := not succeeded
	var show_next := has_next
	hud.show_summary(summary, show_replay, show_next)


func _update_hud_stats() -> void:
	var shift := _current_shift()
	var strikes_allowed := 0
	if shift != null:
		strikes_allowed = shift.strikes_allowed
	hud.set_score(score)
	hud.set_strikes(strikes_used, strikes_allowed)


func _update_hud_shift() -> void:
	var total := 0
	if roster != null:
		total = roster.shifts.size()
	hud.set_shift_progress(_shift_index + 1, total)


func _update_hud_subject_progress() -> void:
	hud.set_subject_progress(_subject_index, _queue.size())


func _update_hud_timer() -> void:
	hud.set_timer_text(format_timer_text(_time_remaining))
