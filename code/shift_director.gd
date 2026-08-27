class_name ShiftDirector
extends Node

signal time_up

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


static func roll_queue(shift: ShiftDef, catalog: SubjectCatalog) -> Array[SubjectDef]:
	var queue: Array[SubjectDef] = []
	if shift == null or catalog == null:
		return queue
	var pool := shift.enabled_types()
	if pool.is_empty() or shift.subject_count <= 0:
		return queue
	for _i in shift.subject_count:
		var picked: SubjectDef.TrueType = pool.pick_random()
		var subject := catalog.subject_for(picked)
		if subject == null:
			push_warning(
				"ShiftDirector: SubjectCatalog has no SubjectDef for %s."
				% SubjectDef.TrueType.keys()[picked]
			)
			continue
		queue.append(subject)
	return queue


func _ready() -> void:
	var parent := get_parent()
	encounter_director = parent.get_node("EncounterDirector") as EncounterDirector
	hud = parent.get_node("HUD") as HUD
	call_deferred("_bind_and_start")


func _bind_and_start() -> void:
	encounter_director.encounter_finished.connect(_on_encounter_finished)
	hud.summary_replay_pressed.connect(_start_shift)
	hud.summary_next_pressed.connect(_on_next_shift)
	_start_shift()


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
		_end_shift("Shift complete.", true)
		return
	if strikes_used >= shift.strikes_allowed:
		_end_shift("Out of strikes.", false)
		return
	if _time_remaining <= 0.0:
		_end_shift("Time is up.", false)
		return
	var subject := _queue[_subject_index]
	_subject_index += 1
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
		_end_shift("Shift complete.", true)
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


func _end_shift(reason: String, succeeded: bool) -> void:
	_shift_active = false
	_waiting_on_encounter = false
	var shift := _current_shift()
	var strikes_allowed := 0
	if shift != null:
		strikes_allowed = shift.strikes_allowed
	var summary := "%s\n\nScore: %d\nStrikes: %d / %d" % [
		reason,
		score,
		strikes_used,
		strikes_allowed
	]
	print("[ShiftDirector] %s" % summary.replace("\n", " | "))
	var show_replay := not succeeded
	var show_next := succeeded and _has_next_shift()
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


func _update_hud_timer() -> void:
	var total_seconds := int(ceil(_time_remaining))
	var minutes := total_seconds / 60
	var seconds := total_seconds % 60
	hud.set_timer_text("%02d:%02d" % [minutes, seconds])
