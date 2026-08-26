class_name EncounterDirector
extends Node

enum Phase { APPROACH, KNOCK, OPEN, RESOLVE, DONE }

signal encounter_finished(scored: bool, strike: bool)

var subject_presenter: SubjectPresenter
var hud: HUD
var audio_approach: AudioStreamPlayer
var audio_knock: AudioStreamPlayer
var audio_voice: AudioStreamPlayer

var phase: Phase = Phase.DONE
var current_subject: SubjectDef
var _input_locked: bool = false


func _ready() -> void:
	var parent := get_parent()
	subject_presenter = parent.get_node("SubjectPresenter") as SubjectPresenter
	hud = parent.get_node("HUD") as HUD
	audio_approach = parent.get_node("AudioApproach") as AudioStreamPlayer
	audio_knock = parent.get_node("AudioKnock") as AudioStreamPlayer
	audio_voice = parent.get_node("AudioVoice") as AudioStreamPlayer
	call_deferred("_bind_hud")


func _bind_hud() -> void:
	hud.peephole_pressed.connect(_on_peephole_pressed)
	hud.peephole_back_pressed.connect(_on_peephole_back_pressed)
	hud.question_pressed.connect(_on_question_pressed)
	hud.accept_pressed.connect(_on_accept_pressed)
	hud.reject_pressed.connect(_on_reject_pressed)
	hud.peephole_pose_changed.connect(_on_peephole_pose_changed)
	hud.peephole_pose_save_pressed.connect(_on_peephole_pose_save_pressed)


func start_encounter(subject: SubjectDef) -> void:
	current_subject = subject
	_input_locked = false
	subject_presenter.set_door_closed()
	subject_presenter.spawn_subject(subject)
	hud.hide_reveal()
	hud.clear_subtitle()
	hud.set_questions(subject.questions)
	hud.set_gate_actions_enabled(false)
	hud.set_peephole_mode(false)
	_set_phase(Phase.APPROACH)
	_play_approach()


func force_miss() -> void:
	if phase == Phase.DONE:
		return
	_input_locked = true
	hud.set_gate_actions_enabled(false)
	hud.set_peephole_mode(false)
	subject_presenter.exit_peephole()
	subject_presenter.clear_subject()
	subject_presenter.set_door_closed()
	_set_phase(Phase.DONE)


func _set_phase(new_phase: Phase) -> void:
	phase = new_phase
	print("[EncounterDirector] phase -> %s" % Phase.keys()[new_phase])


func _play_approach() -> void:
	if current_subject.approach_stream and audio_approach:
		audio_approach.stream = current_subject.approach_stream
		audio_approach.play()
		if not audio_approach.finished.is_connected(_on_approach_finished):
			audio_approach.finished.connect(_on_approach_finished, CONNECT_ONE_SHOT)
	else:
		_on_approach_finished()


func _on_approach_finished() -> void:
	if phase != Phase.APPROACH:
		return
	_set_phase(Phase.KNOCK)
	_play_knock()


func _play_knock() -> void:
	if current_subject.knock_stream and audio_knock:
		audio_knock.stream = current_subject.knock_stream
		audio_knock.play()
		if not audio_knock.finished.is_connected(_on_knock_finished):
			audio_knock.finished.connect(_on_knock_finished, CONNECT_ONE_SHOT)
	else:
		_on_knock_finished()


func _on_knock_finished() -> void:
	if phase != Phase.KNOCK:
		return
	_set_phase(Phase.OPEN)
	hud.set_gate_actions_enabled(true)


func _on_peephole_pressed() -> void:
	if phase != Phase.OPEN or _input_locked:
		return
	_input_locked = true
	hud.set_gate_actions_enabled(false)
	hud.play_blackout(
		func() -> void:
			subject_presenter.enter_peephole()
			hud.set_peephole_mode(true)
			var pose := subject_presenter.get_peephole_pose()
			hud.load_tuner_pose(pose.position, pose.rotation_degrees, pose.scale)
			hud.set_tuner_status("F8 toggles this panel."),
		func() -> void:
			_input_locked = false
	)


func _on_peephole_back_pressed() -> void:
	if phase != Phase.OPEN or _input_locked:
		return
	_input_locked = true
	hud.play_blackout(
		func() -> void:
			subject_presenter.exit_peephole()
			hud.set_peephole_mode(false)
			hud.set_gate_actions_enabled(true),
		func() -> void:
			_input_locked = false
	)


func _on_peephole_pose_changed(
	pose_position: Vector3,
	pose_rotation_degrees: Vector3,
	pose_scale: float
) -> void:
	subject_presenter.apply_peephole_pose(pose_position, pose_rotation_degrees, pose_scale)


func _on_peephole_pose_save_pressed() -> void:
	hud.set_tuner_status(subject_presenter.save_peephole_pose())


func _on_question_pressed(index: int) -> void:
	if phase != Phase.OPEN or _input_locked:
		return
	if index < 0 or index >= current_subject.questions.size():
		return
	var question := current_subject.questions[index]
	hud.set_subtitle(question.subtitle)
	if question.voice_stream and audio_voice:
		audio_voice.stream = question.voice_stream
		audio_voice.play()


func _on_accept_pressed() -> void:
	_resolve(true)


func _on_reject_pressed() -> void:
	_resolve(false)


func _resolve(accepted: bool) -> void:
	if phase != Phase.OPEN or _input_locked:
		return
	_input_locked = true
	hud.set_gate_actions_enabled(false)
	hud.set_peephole_mode(false)
	subject_presenter.exit_peephole()
	_set_phase(Phase.RESOLVE)
	var correct := _is_decision_correct(accepted)
	var scored := correct
	var strike := not correct
	print(
		"[EncounterDirector] %s | correct=%s" % [
			"Accept" if accepted else "Reject",
			str(correct)
		]
	)
	hud.show_reveal(current_subject.reveal_text)
	var on_resolve_done := func() -> void:
		subject_presenter.clear_subject()
		subject_presenter.set_door_closed()
		_set_phase(Phase.DONE)
		encounter_finished.emit(scored, strike)
	if accepted:
		subject_presenter.play_accept(on_resolve_done)
	else:
		subject_presenter.play_reject(on_resolve_done)


func _is_decision_correct(accepted: bool) -> bool:
	match current_subject.true_type:
		SubjectDef.TrueType.CENTAUR:
			return not accepted
		_:
			return accepted
