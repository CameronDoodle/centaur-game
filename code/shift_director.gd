class_name ShiftDirector
extends Node

signal time_up

const WIN_HEADLINE := "You won!"
const SHIFT_COMPLETE_HEADLINE := "Shift complete."
const CHEAT_KEYS := [KEY_W, KEY_I, KEY_N]
const CHEAT_TIMEOUT := 2.0

const QUESTIONS_PER_ENCOUNTER := 2

@export var roster: ShiftRoster
@export var subject_catalog: SubjectCatalog

var encounter_director: EncounterDirector
var hud: HUD

var strikes_used: int = 0
var _shift_index: int = 0
var _queue: Array[EncounterPlan] = []
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


static func roll_queue(shift: ShiftDef, catalog: SubjectCatalog) -> Array[EncounterPlan]:
	var plans: Array[EncounterPlan] = []
	if shift == null or catalog == null:
		return plans
	var pool := shift.enabled_types()
	if pool.is_empty() or shift.subject_count <= 0:
		return plans
	var type_sequence := _build_type_sequence(shift, pool)
	var used_lines: Dictionary = {}
	var used_sfx: Dictionary = {}
	var used_questions: Dictionary = {}
	for true_type in type_sequence:
		var subject := catalog.subject_for(true_type)
		if subject == null:
			push_warning(
				"ShiftDirector: SubjectCatalog has no SubjectDef for %s."
				% SubjectDef.TrueType.keys()[true_type]
			)
			continue
		plans.append(
			_build_encounter_plan(shift, subject, catalog, used_lines, used_sfx, used_questions)
		)
	return plans


static func _build_type_sequence(
	shift: ShiftDef,
	pool: Array[SubjectDef.TrueType]
) -> Array[SubjectDef.TrueType]:
	if pool.size() == 1:
		var single: Array[SubjectDef.TrueType] = []
		for _i in shift.subject_count:
			single.append(pool[0])
		return single
	if shift.subject_count < pool.size():
		push_warning(
			"ShiftDirector: subject_count (%d) is less than enabled types (%d)."
			% [shift.subject_count, pool.size()]
		)
		var trimmed := pool.duplicate()
		trimmed.shuffle()
		trimmed.resize(shift.subject_count)
		return _shuffle_no_adjacent(trimmed)
	var counts: Dictionary = {}
	for true_type in pool:
		counts[true_type] = 0
	var sequence: Array[SubjectDef.TrueType] = []
	for true_type in pool:
		sequence.append(true_type)
		counts[true_type] = 1
	var remaining := shift.subject_count - pool.size()
	for _i in remaining:
		var min_count: int = counts[pool[0]]
		for true_type in pool:
			min_count = mini(min_count, counts[true_type])
		var candidates: Array[SubjectDef.TrueType] = []
		for true_type in pool:
			if counts[true_type] == min_count:
				candidates.append(true_type)
		var picked: SubjectDef.TrueType = candidates.pick_random()
		sequence.append(picked)
		counts[picked] += 1
	return _shuffle_no_adjacent(sequence)


static func _shuffle_no_adjacent(
	types: Array[SubjectDef.TrueType]
) -> Array[SubjectDef.TrueType]:
	if types.size() <= 1:
		return types
	var distinct := {}
	for true_type in types:
		distinct[true_type] = true
	if distinct.size() <= 1:
		return types
	var shuffled := types.duplicate()
	for _attempt in 64:
		shuffled.shuffle()
		_repair_adjacent_duplicates(shuffled)
		if not _has_adjacent_duplicates(shuffled):
			return shuffled
	push_warning("ShiftDirector: could not eliminate all adjacent duplicate types.")
	return shuffled


static func _has_adjacent_duplicates(types: Array[SubjectDef.TrueType]) -> bool:
	for i in range(1, types.size()):
		if types[i] == types[i - 1]:
			return true
	return false


static func _repair_adjacent_duplicates(types: Array[SubjectDef.TrueType]) -> void:
	for i in range(1, types.size()):
		if types[i] != types[i - 1]:
			continue
		for j in range(i + 1, types.size()):
			if types[j] == types[i]:
				continue
			if types[j] == types[i - 1]:
				continue
			if j < types.size() - 1 and types[j + 1] == types[i]:
				continue
			var tmp := types[i]
			types[i] = types[j]
			types[j] = tmp
			break


static func _build_encounter_plan(
	shift: ShiftDef,
	subject: SubjectDef,
	catalog: SubjectCatalog,
	used_lines: Dictionary,
	used_sfx: Dictionary,
	used_questions: Dictionary
) -> EncounterPlan:
	var plan := EncounterPlan.new()
	plan.subject = subject
	var type_id := subject.true_type as int
	if not used_questions.has(type_id):
		used_questions[type_id] = []
	var applicable_pool := DialoguePools.applicable_keys(subject.true_type)
	var question_count := mini(QUESTIONS_PER_ENCOUNTER, applicable_pool.size())
	var picked_keys := DialoguePools.pick_keys(
		applicable_pool,
		used_questions[type_id],
		question_count
	)
	for key in picked_keys:
		used_questions[type_id].append(key)
	var lie_chance := shift.lie_chance_for(subject.true_type) if shift != null else 0.0
	if lie_chance > 0.0 and not picked_keys.is_empty():
		plan.lie_slot = randi() % picked_keys.size()
		plan.is_lying = randf() < lie_chance
	var imitated_type := SubjectDef.imitated_type(subject.true_type)
	for i in picked_keys.size():
		var key: String = picked_keys[i]
		var question := _resolve_question(catalog.questions, key)
		plan.questions.append(question)
		var reply_type := subject.true_type
		if plan.is_lying and i == plan.lie_slot:
			reply_type = imitated_type
		var line_key := "%s|%d" % [question.prompt_key, reply_type as int]
		if not used_lines.has(line_key):
			used_lines[line_key] = []
		var exclude: Array = used_lines[line_key]
		var line := DialoguePools.pick(question.prompt_key, reply_type, exclude)
		if line.is_empty() and reply_type != subject.true_type:
			line_key = "%s|%d" % [question.prompt_key, subject.true_type as int]
			if not used_lines.has(line_key):
				used_lines[line_key] = []
			exclude = used_lines[line_key]
			line = DialoguePools.pick(question.prompt_key, subject.true_type, exclude)
		if line.is_empty():
			line = question.subtitle
		plan.question_subtitles.append(line)
		if not line.is_empty():
			exclude.append(line)
	var approach_id := ClueSfx.pool_id(subject.approach_kind, true)
	if not used_sfx.has(approach_id):
		used_sfx[approach_id] = []
	plan.approach_stream = ClueSfx.pick(
		subject.approach_kind,
		true,
		used_sfx[approach_id]
	)
	_track_sfx_path(used_sfx, approach_id, plan.approach_stream)
	var knock_kind := subject.knock_kind
	if subject.true_type == SubjectDef.TrueType.CENTAUR:
		knock_kind = (
			SubjectDef.ClueKind.HUMAN
			if randi() % 2 == 0
			else SubjectDef.ClueKind.HORSE
		)
	var knock_id := ClueSfx.pool_id(knock_kind, false)
	if not used_sfx.has(knock_id):
		used_sfx[knock_id] = []
	plan.knock_stream = ClueSfx.pick(knock_kind, false, used_sfx[knock_id])
	_track_sfx_path(used_sfx, knock_id, plan.knock_stream)
	return plan


static func _question_for_key(
	questions: Array[QuestionDef],
	prompt_key: String
) -> QuestionDef:
	for question in questions:
		if question.prompt_key == prompt_key:
			return question
	return null


static func _resolve_question(
	questions: Array[QuestionDef],
	prompt_key: String
) -> QuestionDef:
	var question := _question_for_key(questions, prompt_key)
	if question != null:
		return question
	question = QuestionDef.new()
	question.prompt_key = prompt_key
	question.button_label = prompt_key
	return question


static func _track_sfx_path(
	used_sfx: Dictionary,
	pool_id: StringName,
	stream: AudioStream
) -> void:
	if stream == null:
		return
	var path := stream.resource_path
	if path.is_empty():
		return
	var used: Array = used_sfx.get(pool_id, [])
	if path not in used:
		used.append(path)
	used_sfx[pool_id] = used


static func format_timer_text(seconds: float) -> String:
	var total_seconds := int(ceil(seconds))
	var minutes := total_seconds / 60
	var secs := total_seconds % 60
	return "%02d:%02d" % [minutes, secs]


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
	var plan := _queue[_subject_index]
	_subject_index += 1
	_update_hud_subject_progress()
	_waiting_on_encounter = true
	print(
		"[ShiftDirector] Shift %d / %d — subject %d / %d"
		% [_shift_index + 1, roster.shifts.size(), _subject_index, _queue.size()]
	)
	encounter_director.start_encounter(plan)


func _on_encounter_finished(strike: bool, skip_handoff_delay: bool = false) -> void:
	if not _shift_active:
		return
	var shift := _current_shift()
	if shift == null:
		return
	_waiting_on_encounter = false
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
	var has_next := succeeded and _has_next_shift()
	var next_shift: ShiftDef = null
	if has_next:
		next_shift = roster.shifts[_shift_index + 1]
	var log_parts: PackedStringArray = [reason]
	if has_next and next_shift != null:
		log_parts.append(
			"Time: %s" % format_timer_text(next_shift.shift_timer_seconds)
		)
		log_parts.append("Subjects: %d" % next_shift.subject_count)
		log_parts.append("Strikes: %d" % next_shift.strikes_allowed)
	print("[ShiftDirector] %s" % " | ".join(log_parts))
	var show_replay := not succeeded
	var show_next := has_next
	hud.show_summary(reason, show_replay, show_next, next_shift)


func _update_hud_stats() -> void:
	var shift := _current_shift()
	var strikes_allowed := 0
	if shift != null:
		strikes_allowed = shift.strikes_allowed
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
