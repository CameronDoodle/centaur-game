class_name ShiftDirector
extends Node

signal time_up

@export var shift_def: ShiftDef

var encounter_director: EncounterDirector
var hud: HUD

var score: int = 0
var strikes_used: int = 0
var _subject_index: int = 0
var _time_remaining: float = 0.0
var _shift_active: bool = false
var _waiting_on_encounter: bool = false


func _ready() -> void:
	var parent := get_parent()
	encounter_director = parent.get_node("EncounterDirector") as EncounterDirector
	hud = parent.get_node("HUD") as HUD
	call_deferred("_bind_and_start")


func _bind_and_start() -> void:
	encounter_director.encounter_finished.connect(_on_encounter_finished)
	hud.summary_replay_pressed.connect(_start_shift)
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


func _start_shift() -> void:
	if shift_def == null:
		push_warning("ShiftDirector: no shift_def assigned.")
		return
	score = 0
	strikes_used = 0
	_subject_index = 0
	_time_remaining = shift_def.shift_timer_seconds
	_shift_active = true
	_waiting_on_encounter = false
	hud.hide_summary()
	hud.hide_reveal()
	_update_hud_stats()
	_update_hud_timer()
	_start_next_encounter()


func _start_next_encounter() -> void:
	if not _shift_active:
		return
	if _subject_index >= shift_def.subjects.size():
		_end_shift("Shift complete.")
		return
	if strikes_used >= shift_def.strikes_allowed:
		_end_shift("Out of strikes.")
		return
	if _time_remaining <= 0.0:
		_end_shift("Time is up.")
		return
	var subject := shift_def.subjects[_subject_index]
	_subject_index += 1
	_waiting_on_encounter = true
	print("[ShiftDirector] subject %d / %d" % [_subject_index, shift_def.subjects.size()])
	encounter_director.start_encounter(subject)


func _on_encounter_finished(scored: bool, strike: bool) -> void:
	if not _shift_active:
		return
	_waiting_on_encounter = false
	if scored:
		score += 1
	if strike:
		strikes_used += 1
	_update_hud_stats()
	await get_tree().create_timer(1.0).timeout
	if not _shift_active:
		return
	if strikes_used >= shift_def.strikes_allowed:
		_end_shift("Out of strikes.")
		return
	if _subject_index >= shift_def.subjects.size():
		_end_shift("Shift complete.")
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
	_end_shift("Time is up.")


func _end_shift(reason: String) -> void:
	_shift_active = false
	_waiting_on_encounter = false
	var summary := "%s\n\nScore: %d\nStrikes: %d / %d" % [
		reason,
		score,
		strikes_used,
		shift_def.strikes_allowed
	]
	print("[ShiftDirector] %s" % summary.replace("\n", " | "))
	hud.show_summary(summary)


func _update_hud_stats() -> void:
	hud.set_score(score)
	hud.set_strikes(strikes_used, shift_def.strikes_allowed)


func _update_hud_timer() -> void:
	var total_seconds := int(ceil(_time_remaining))
	var minutes := total_seconds / 60
	var seconds := total_seconds % 60
	hud.set_timer_text("%02d:%02d" % [minutes, seconds])
