class_name HUD
extends CanvasLayer

signal peephole_pressed
signal peephole_back_pressed
signal question_pressed(index: int)
signal accept_pressed
signal reject_pressed
signal summary_replay_pressed
signal peephole_pose_changed(position: Vector3, rotation_degrees: Vector3, pose_scale: float)
signal peephole_pose_save_pressed
signal skip_pressed

const BLACKOUT_DURATION := 0.22

@onready var timer_label: Label = %TimerLabel
@onready var score_label: Label = %ScoreLabel
@onready var strikes_label: Label = %StrikesLabel
@onready var subtitle_label: Label = %SubtitleLabel
@onready var reveal_panel: PanelContainer = %RevealPanel
@onready var reveal_label: Label = %RevealLabel
@onready var summary_panel: PanelContainer = %SummaryPanel
@onready var summary_label: Label = %SummaryLabel
@onready var gate_actions: VBoxContainer = %GateActions
@onready var peephole_actions: VBoxContainer = %PeepholeActions
@onready var question_buttons: VBoxContainer = %QuestionButtons
@onready var skip_button: Button = %SkipButton
@onready var peephole_button: Button = %PeepholeButton
@onready var accept_button: Button = %AcceptButton
@onready var reject_button: Button = %RejectButton
@onready var back_button: Button = %BackButton
@onready var replay_button: Button = %ReplayButton
@onready var fisheye_overlay: ColorRect = %FisheyeOverlay
@onready var fade_rect: ColorRect = %FadeRect
@onready var tuner_panel: PanelContainer = %PeepholeTuner
@onready var tuner_pos_x: SpinBox = %TunerPosX
@onready var tuner_pos_y: SpinBox = %TunerPosY
@onready var tuner_pos_z: SpinBox = %TunerPosZ
@onready var tuner_rot_x: SpinBox = %TunerRotX
@onready var tuner_rot_y: SpinBox = %TunerRotY
@onready var tuner_rot_z: SpinBox = %TunerRotZ
@onready var tuner_scale: SpinBox = %TunerScale
@onready var tuner_status: Label = %TunerStatus
@onready var tuner_save_button: Button = %TunerSaveButton

var _fade_tween: Tween
var _tuner_open: bool = false
var _syncing_tuner: bool = false


func _ready() -> void:
	skip_button.pressed.connect(func() -> void: skip_pressed.emit())
	peephole_button.pressed.connect(func() -> void: peephole_pressed.emit())
	back_button.pressed.connect(func() -> void: peephole_back_pressed.emit())
	accept_button.pressed.connect(func() -> void: accept_pressed.emit())
	reject_button.pressed.connect(func() -> void: reject_pressed.emit())
	replay_button.pressed.connect(func() -> void: summary_replay_pressed.emit())
	tuner_save_button.pressed.connect(func() -> void: peephole_pose_save_pressed.emit())
	for spin in [
		tuner_pos_x, tuner_pos_y, tuner_pos_z,
		tuner_rot_x, tuner_rot_y, tuner_rot_z,
		tuner_scale,
	]:
		spin.value_changed.connect(_on_tuner_value_changed)
	hide_reveal()
	hide_summary()
	set_peephole_mode(false)
	set_gate_actions_enabled(false)
	set_skip_visible(false)
	fade_rect.modulate.a = 0.0
	set_tuner_open(false)


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_1:
		if peephole_actions.visible:
			set_tuner_open(not _tuner_open)
			get_viewport().set_input_as_handled()


func play_blackout(on_black: Callable, on_complete: Callable = Callable()) -> void:
	if _fade_tween:
		_fade_tween.kill()
	fade_rect.visible = true
	fade_rect.modulate.a = 0.0
	_fade_tween = create_tween()
	_fade_tween.tween_property(fade_rect, "modulate:a", 1.0, BLACKOUT_DURATION)
	_fade_tween.tween_callback(func() -> void:
		if on_black.is_valid():
			on_black.call()
	)
	_fade_tween.tween_property(fade_rect, "modulate:a", 0.0, BLACKOUT_DURATION)
	_fade_tween.tween_callback(func() -> void:
		if on_complete.is_valid():
			on_complete.call()
	)


func set_timer_text(text: String) -> void:
	timer_label.text = text


func set_score(score: int) -> void:
	score_label.text = "Score: %d" % score


func set_strikes(strikes_used: int, strikes_allowed: int) -> void:
	strikes_label.text = "Strikes: %d / %d" % [strikes_used, strikes_allowed]


func set_subtitle(text: String) -> void:
	subtitle_label.text = text
	subtitle_label.visible = not text.is_empty()


func clear_subtitle() -> void:
	set_subtitle("")


func set_questions(questions: Array[QuestionDef]) -> void:
	for child in question_buttons.get_children():
		child.queue_free()
	for i in questions.size():
		var question := questions[i]
		var button := Button.new()
		button.text = question.button_label
		var index := i
		button.pressed.connect(func() -> void: question_pressed.emit(index))
		question_buttons.add_child(button)


func set_skip_visible(visible: bool, label: String = "") -> void:
	skip_button.visible = visible
	if not label.is_empty():
		skip_button.text = label


func set_gate_actions_enabled(enabled: bool) -> void:
	peephole_button.disabled = not enabled
	accept_button.disabled = not enabled
	reject_button.disabled = not enabled
	for child in question_buttons.get_children():
		if child is Button:
			child.disabled = not enabled


func set_peephole_mode(active: bool) -> void:
	gate_actions.visible = not active
	peephole_actions.visible = active
	fisheye_overlay.visible = active
	if not active:
		set_tuner_open(false)


func set_tuner_open(open: bool) -> void:
	_tuner_open = open
	tuner_panel.visible = open


func load_tuner_pose(position: Vector3, rotation_degrees: Vector3, pose_scale: float) -> void:
	_syncing_tuner = true
	tuner_pos_x.value = position.x
	tuner_pos_y.value = position.y
	tuner_pos_z.value = position.z
	tuner_rot_x.value = rotation_degrees.x
	tuner_rot_y.value = rotation_degrees.y
	tuner_rot_z.value = rotation_degrees.z
	tuner_scale.value = pose_scale
	_syncing_tuner = false


func set_tuner_status(text: String) -> void:
	tuner_status.text = text


func show_reveal(text: String) -> void:
	reveal_label.text = text
	reveal_panel.visible = true


func hide_reveal() -> void:
	reveal_panel.visible = false


func show_summary(text: String) -> void:
	summary_label.text = text
	summary_panel.visible = true
	set_gate_actions_enabled(false)
	set_peephole_mode(false)


func hide_summary() -> void:
	summary_panel.visible = false


func _on_tuner_value_changed(_value: float) -> void:
	if _syncing_tuner:
		return
	peephole_pose_changed.emit(
		Vector3(tuner_pos_x.value, tuner_pos_y.value, tuner_pos_z.value),
		Vector3(tuner_rot_x.value, tuner_rot_y.value, tuner_rot_z.value),
		tuner_scale.value
	)
