class_name EncounterDirector
extends Node

enum Phase { APPROACH, KNOCK, OPEN, RESOLVE, DONE }

signal encounter_finished(scored: bool, strike: bool, skip_handoff_delay: bool)

var subject_presenter: SubjectPresenter
var hud: HUD
var dialogue_box: DialogueBox
var audio_approach: AudioStreamPlayer
var audio_knock: AudioStreamPlayer
var audio_voice: AudioStreamPlayer

const PLAYER_CAMERA_SCRIPT := preload("res://code/camera_3d.gd")

var phase: Phase = Phase.DONE
var current_subject: SubjectDef
var _input_locked: bool = false
var _approach_stream: AudioStream
var _knock_stream: AudioStream
var _question_subtitles: Array[String] = []
var _wrong_accept_join_remaining: int = 0
var _wrong_accept_join_scored: bool = false
var _wrong_accept_join_strike: bool = false


func _ready() -> void:
	var parent := get_parent()
	subject_presenter = parent.get_node("SubjectPresenter") as SubjectPresenter
	hud = parent.get_node("HUD") as HUD
	dialogue_box = parent.get_node("world/dialogue_box_marker/DialogueBox") as DialogueBox
	audio_approach = parent.get_node("AudioApproach") as AudioStreamPlayer
	audio_knock = parent.get_node("AudioKnock") as AudioStreamPlayer
	audio_voice = parent.get_node("AudioVoice") as AudioStreamPlayer
	_ensure_player_camera()
	call_deferred("_bind_hud")


func _bind_hud() -> void:
	hud.peephole_pressed.connect(_on_peephole_pressed)
	hud.peephole_back_pressed.connect(_on_peephole_back_pressed)
	hud.replay_approach_pressed.connect(_on_replay_approach_pressed)
	hud.replay_knock_pressed.connect(_on_replay_knock_pressed)
	if dialogue_box != null:
		dialogue_box.question_pressed.connect(_on_question_pressed)
	hud.accept_pressed.connect(_on_accept_pressed)
	hud.reject_pressed.connect(_on_reject_pressed)
	hud.peephole_pose_changed.connect(_on_peephole_pose_changed)
	hud.peephole_pose_save_pressed.connect(_on_peephole_pose_save_pressed)
	hud.skip_pressed.connect(_on_skip_pressed)


func start_encounter(subject: SubjectDef) -> void:
	current_subject = subject
	_input_locked = false
	subject_presenter.set_door_closed(false)
	subject_presenter.spawn_subject(subject)
	hud.hide_reveal()
	if dialogue_box != null:
		dialogue_box.clear_reply()
	_question_subtitles.clear()
	for question in subject.questions:
		var line := DialoguePools.pick(question.prompt_key, subject.true_type)
		if line.is_empty():
			line = question.subtitle
		_question_subtitles.append(line)
	if dialogue_box != null:
		dialogue_box.set_questions(subject.questions)
		dialogue_box.set_questions_enabled(false)
	hud.set_gate_actions_enabled(false)
	hud.set_peephole_mode(false)
	hud.set_skip_visible(false)
	_approach_stream = ClueSfx.pick(subject.approach_kind, true)
	var knock_kind := subject.knock_kind
	if subject.true_type == SubjectDef.TrueType.CENTAUR:
		knock_kind = SubjectDef.ClueKind.HUMAN if randi() % 2 == 0 else SubjectDef.ClueKind.HORSE
	_knock_stream = ClueSfx.pick(knock_kind, false)
	var has_approach := _approach_stream != null
	var has_knock := _knock_stream != null
	hud.show_investigation(has_approach, has_knock)
	if dialogue_box != null:
		dialogue_box.show_box()
	_set_phase(Phase.APPROACH)
	_play_approach()


func force_miss() -> void:
	if phase == Phase.DONE:
		return
	_input_locked = true
	_stop_encounter_audio()
	hud.set_skip_visible(false)
	hud.set_gate_actions_enabled(false)
	hud.hide_investigation()
	if dialogue_box != null:
		dialogue_box.hide_box()
	hud.set_peephole_mode(false)
	subject_presenter.exit_peephole()
	_call_camera("snap_to_rest")
	subject_presenter.clear_all_subjects()
	subject_presenter.set_door_closed()
	_set_phase(Phase.DONE)


func _set_phase(new_phase: Phase) -> void:
	phase = new_phase
	print("[EncounterDirector] phase -> %s" % Phase.keys()[new_phase])


func _play_approach() -> void:
	if _approach_stream and audio_approach:
		audio_approach.stream = _approach_stream
		audio_approach.play()
		if not audio_approach.finished.is_connected(_on_approach_finished):
			audio_approach.finished.connect(_on_approach_finished, CONNECT_ONE_SHOT)
		hud.set_clue_replay_playing(true, false)
	else:
		_on_approach_finished()


func _on_approach_finished() -> void:
	if phase != Phase.APPROACH:
		return
	_set_phase(Phase.KNOCK)
	_play_knock()


func _play_knock() -> void:
	if _knock_stream and audio_knock:
		audio_knock.stream = _knock_stream
		audio_knock.play()
		if not audio_knock.finished.is_connected(_on_knock_finished):
			audio_knock.finished.connect(_on_knock_finished, CONNECT_ONE_SHOT)
		hud.set_clue_replay_playing(false, true)
	else:
		_on_knock_finished()


func _on_knock_finished() -> void:
	if phase != Phase.KNOCK:
		return
	hud.set_clue_replay_playing(false, false)
	_set_phase(Phase.OPEN)
	hud.set_gate_actions_enabled(true)
	if dialogue_box != null:
		dialogue_box.set_questions_enabled(true)


func _on_skip_pressed() -> void:
	match phase:
		Phase.APPROACH:
			_stop_approach_audio()
			_on_approach_finished()
		Phase.KNOCK:
			_stop_knock_audio()
			_on_knock_finished()


func _stop_approach_audio() -> void:
	if audio_approach == null:
		return
	if audio_approach.finished.is_connected(_on_approach_finished):
		audio_approach.finished.disconnect(_on_approach_finished)
	if audio_approach.finished.is_connected(_on_replay_approach_finished):
		audio_approach.finished.disconnect(_on_replay_approach_finished)
	audio_approach.stop()


func _stop_knock_audio() -> void:
	if audio_knock == null:
		return
	if audio_knock.finished.is_connected(_on_knock_finished):
		audio_knock.finished.disconnect(_on_knock_finished)
	if audio_knock.finished.is_connected(_on_replay_knock_finished):
		audio_knock.finished.disconnect(_on_replay_knock_finished)
	audio_knock.stop()


func _stop_encounter_audio() -> void:
	_stop_approach_audio()
	_stop_knock_audio()
	hud.set_clue_replay_playing(false, false)


func _on_replay_approach_pressed() -> void:
	match phase:
		Phase.APPROACH:
			_stop_approach_audio()
			_set_phase(Phase.KNOCK)
			_play_knock()
		Phase.KNOCK:
			_stop_knock_audio()
			hud.set_clue_replay_playing(false, false)
			_set_phase(Phase.OPEN)
			hud.set_gate_actions_enabled(true)
			if dialogue_box != null:
				dialogue_box.set_questions_enabled(true)
			_replay_clue(true)
		Phase.OPEN:
			_replay_clue(true)


func _on_replay_knock_pressed() -> void:
	match phase:
		Phase.APPROACH:
			_stop_approach_audio()
			_set_phase(Phase.KNOCK)
			_play_knock()
		Phase.KNOCK:
			_stop_knock_audio()
			_on_knock_finished()
		Phase.OPEN:
			_replay_clue(false)


func _replay_clue(is_approach: bool) -> void:
	if phase != Phase.OPEN or _input_locked or subject_presenter.is_in_peephole():
		return
	var stream: AudioStream
	var player: AudioStreamPlayer
	var finished_handler: Callable
	if is_approach:
		player = audio_approach
		if player != null and player.playing:
			_stop_approach_audio()
			hud.set_clue_replay_playing(false, audio_knock.playing)
			return
		stream = _approach_stream
		finished_handler = _on_replay_approach_finished
		_stop_knock_audio()
		hud.set_clue_replay_playing(true, false)
	else:
		player = audio_knock
		if player != null and player.playing:
			_stop_knock_audio()
			hud.set_clue_replay_playing(audio_approach.playing, false)
			return
		stream = _knock_stream
		finished_handler = _on_replay_knock_finished
		_stop_approach_audio()
		hud.set_clue_replay_playing(false, true)
	if stream == null or player == null:
		hud.set_clue_replay_playing(false, false)
		return
	player.stream = stream
	player.play()
	if player.finished.is_connected(finished_handler):
		player.finished.disconnect(finished_handler)
	player.finished.connect(finished_handler, CONNECT_ONE_SHOT)


func _on_replay_approach_finished() -> void:
	if phase != Phase.OPEN:
		return
	hud.set_clue_replay_playing(false, audio_knock.playing)


func _on_replay_knock_finished() -> void:
	if phase != Phase.OPEN:
		return
	hud.set_clue_replay_playing(audio_approach.playing, false)


func _on_peephole_pressed() -> void:
	if phase != Phase.OPEN or _input_locked:
		return
	_input_locked = true
	hud.set_gate_actions_enabled(false)
	if dialogue_box != null:
		dialogue_box.set_questions_enabled(false)
		dialogue_box.hide_box()
	_call_camera("move_to_peephole")
	hud.play_blackout(
		func() -> void:
			subject_presenter.enter_peephole()
			hud.set_peephole_mode(true)
			var pose := subject_presenter.get_peephole_pose()
			hud.load_tuner_pose(pose.position, pose.rotation_degrees, pose.scale)
			hud.set_tuner_status("F8 toggles this panel."),
		func() -> void:
			_input_locked = false,
		_camera_move_duration()
	)


func _on_peephole_back_pressed() -> void:
	if phase != Phase.OPEN or _input_locked:
		return
	_input_locked = true
	hud.play_fade_from_black(
		func() -> void:
			hud.set_fisheye_enabled(false)
			subject_presenter.exit_peephole()
			hud.set_peephole_mode(false)
			hud.set_gate_actions_enabled(true)
			if dialogue_box != null:
				dialogue_box.show_box()
				dialogue_box.set_questions_enabled(true)
			_call_camera("return_to_rest"),
		func() -> void:
			_input_locked = false,
		_camera_move_duration()
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
	var subtitle := _question_subtitles[index] if index < _question_subtitles.size() else question.subtitle
	if dialogue_box != null:
		dialogue_box.set_reply(subtitle)


func _on_accept_pressed() -> void:
	_resolve(true)


func _on_reject_pressed() -> void:
	_resolve(false)


func _resolve(accepted: bool) -> void:
	if phase != Phase.OPEN or _input_locked:
		return
	_input_locked = true
	_stop_encounter_audio()
	hud.set_gate_actions_enabled(false)
	hud.hide_investigation()
	if dialogue_box != null:
		dialogue_box.hide_box()
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
	var verdict := VerdictPools.pick(accepted, correct, current_subject.true_type)
	hud.show_reveal(verdict.get("text", ""))
	_play_verdict_sfx(str(verdict.get("sfx", "")))
	if accepted:
		var wrong_accept := not correct
		if wrong_accept:
			_begin_wrong_accept_resolve(scored, strike)
		else:
			var on_passed_marker := func() -> void:
				hud.hide_reveal()
				_set_phase(Phase.DONE)
				encounter_finished.emit(scored, strike, true)
			subject_presenter.play_accept(Callable(), on_passed_marker)
		return
	var penalty := not correct
	var on_walk_done := func() -> void:
		if penalty:
			_end_reject_camera_follow(func() -> void:
				_finish_resolve(scored, strike, true)
			)
	var on_halfway := Callable()
	if not penalty:
		on_halfway = func() -> void:
			_set_phase(Phase.DONE)
			encounter_finished.emit(scored, strike, true)
	var walker := subject_presenter.play_reject(on_walk_done, on_halfway)
	if penalty:
		_begin_reject_camera_follow(walker)


func _finish_resolve(scored: bool, strike: bool, skip_handoff_delay: bool) -> void:
	subject_presenter.clear_subject()
	subject_presenter.set_door_closed()
	hud.hide_reveal()
	_call_camera("snap_to_rest")
	_set_phase(Phase.DONE)
	encounter_finished.emit(scored, strike, skip_handoff_delay)


func _begin_wrong_accept_resolve(scored: bool, strike: bool) -> void:
	_wrong_accept_join_scored = scored
	_wrong_accept_join_strike = strike
	_wrong_accept_join_remaining = 2
	_call_camera("snap_to_rest")
	var subject := subject_presenter.get_active_subject()
	var knock_delay := subject_presenter.wrong_accept_knock_delay()
	var join := Callable(self, "_on_wrong_accept_join_step")
	subject_presenter.play_accept_penalty(join)
	_play_wrong_accept_sequence(subject, knock_delay, join)


func _on_wrong_accept_join_step() -> void:
	if _wrong_accept_join_remaining <= 0:
		return
	_wrong_accept_join_remaining -= 1
	if _wrong_accept_join_remaining <= 0:
		_finish_resolve(_wrong_accept_join_scored, _wrong_accept_join_strike, true)


func _begin_reject_camera_follow(subject: Node3D) -> void:
	var camera := _ensure_player_camera()
	if camera != null and camera.has_method("begin_reject_follow"):
		camera.call("begin_reject_follow", subject)


func _end_reject_camera_follow(on_complete: Callable) -> void:
	var camera := _ensure_player_camera()
	if camera != null and camera.has_method("end_reject_follow"):
		camera.call("end_reject_follow", on_complete)
		return
	if on_complete.is_valid():
		on_complete.call()


func _play_wrong_accept_sequence(
	subject: Node3D,
	knock_delay: float,
	on_complete: Callable
) -> void:
	var camera := _ensure_player_camera()
	if camera == null:
		if on_complete.is_valid():
			on_complete.call()
		return
	if subject == null or not is_instance_valid(subject):
		subject = subject_presenter.get_active_subject()
	if camera.has_method("play_wrong_accept_sequence"):
		camera.call("play_wrong_accept_sequence", subject, knock_delay, on_complete)
		return
	if on_complete.is_valid():
		on_complete.call()


func _begin_wrong_accept_penalty(subject: Node3D = null) -> void:
	var camera := _ensure_player_camera()
	if camera == null or not camera.has_method("begin_wrong_accept_penalty"):
		return
	if subject == null or not is_instance_valid(subject):
		subject = subject_presenter.get_active_subject()
	camera.call("begin_wrong_accept_penalty", subject)


func _end_wrong_accept_penalty(on_complete: Callable) -> void:
	var camera := _ensure_player_camera()
	if camera != null and camera.has_method("end_wrong_accept_penalty"):
		camera.call("end_wrong_accept_penalty", on_complete)
		return
	if on_complete.is_valid():
		on_complete.call()


func _camera_move_duration() -> float:
	var camera := _ensure_player_camera()
	if camera != null and "peephole_move_duration" in camera:
		return float(camera.get("peephole_move_duration"))
	return hud.BLACKOUT_DURATION


func _call_camera(method: String) -> void:
	var camera := _ensure_player_camera()
	if camera != null and camera.has_method(method):
		camera.call(method)


func _ensure_player_camera() -> Camera3D:
	var camera := get_parent().get_node_or_null("Camera3D") as Camera3D
	if camera == null:
		return null
	if not camera.has_method("move_to_peephole"):
		camera.set_script(PLAYER_CAMERA_SCRIPT)
		if camera.has_method("capture_rest"):
			camera.capture_rest()
	return camera


func _is_decision_correct(accepted: bool) -> bool:
	if SubjectDef.is_banned(current_subject.true_type):
		return not accepted
	return accepted


func _play_verdict_sfx(path: String) -> void:
	if path.is_empty() or audio_voice == null:
		return
	if not ResourceLoader.exists(path):
		push_warning("EncounterDirector: missing verdict sfx %s." % path)
		return
	var stream := load(path) as AudioStream
	if stream == null:
		return
	audio_voice.stream = stream
	audio_voice.play()
