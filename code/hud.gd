class_name HUD
extends CanvasLayer

signal peephole_pressed
signal peephole_back_pressed
signal replay_approach_pressed
signal replay_knock_pressed
signal accept_pressed
signal reject_pressed
signal summary_replay_pressed
signal summary_next_pressed
signal peephole_pose_changed(position: Vector3, rotation_degrees: Vector3, pose_scale: float)
signal peephole_pose_save_pressed
signal skip_pressed

const BLACKOUT_DURATION := 0.75
const ICON_TINT := Color(0.95, 0.9, 0.82, 1)

@onready var shift_label: Label = %ShiftLabel
@onready var timer_label: Label = %TimerLabel
@onready var score_label: Label = %ScoreLabel
@onready var strikes_label: Label = %StrikesLabel
@onready var reveal_panel: PanelContainer = %RevealPanel
@onready var reveal_label: Label = %RevealLabel
@onready var summary_panel: PanelContainer = %SummaryPanel
@onready var summary_label: Label = %SummaryLabel
@onready var gate_actions: VBoxContainer = %GateActions
@onready var peephole_actions: VBoxContainer = %PeepholeActions
@onready var skip_button: Button = %SkipButton
@onready var accept_button: Button = %AcceptButton
@onready var reject_button: Button = %RejectButton
@onready var back_button: Button = %BackButton
@onready var replay_button: Button = %ReplayButton
@onready var next_button: Button = %NextButton
@onready var fisheye_overlay: ColorRect = %FisheyeOverlay
@onready var fade_rect: ColorRect = %FadeRect
@onready var door_overlay: Control = %DoorOverlay
@onready var peephole_hotspot: VBoxContainer = %PeepholeHotspot
@onready var knock_hotspot: VBoxContainer = %KnockHotspot
@onready var approach_hotspot: VBoxContainer = %ApproachHotspot
@onready var peephole_icon: TextureButton = %PeepholeIcon
@onready var knock_icon: TextureButton = %KnockIcon
@onready var knock_playback_fill: ColorRect = %KnockPlaybackFill
@onready var approach_icon: TextureButton = %ApproachIcon
@onready var approach_playback_fill: ColorRect = %ApproachPlaybackFill
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
var _door_overlay_visible: bool = false
var _gate_actions_enabled: bool = false
var _investigation_active: bool = false
var _clue_approach_visible: bool = false
var _clue_knock_visible: bool = false
var _approach_replay_disabled: bool = false
var _knock_replay_disabled: bool = false
var _peephole_marker: Marker3D
var _knock_marker: Marker3D
var _approach_marker: Marker3D
var _gate_camera: Camera3D
var _audio_approach: AudioStreamPlayer
var _audio_knock: AudioStreamPlayer


func _ready() -> void:
	skip_button.pressed.connect(func() -> void: skip_pressed.emit())
	peephole_icon.pressed.connect(func() -> void: peephole_pressed.emit())
	knock_icon.pressed.connect(func() -> void: replay_knock_pressed.emit())
	approach_icon.pressed.connect(func() -> void: replay_approach_pressed.emit())
	back_button.pressed.connect(func() -> void: peephole_back_pressed.emit())
	accept_button.pressed.connect(func() -> void: accept_pressed.emit())
	reject_button.pressed.connect(func() -> void: reject_pressed.emit())
	replay_button.pressed.connect(func() -> void: summary_replay_pressed.emit())
	next_button.pressed.connect(func() -> void: summary_next_pressed.emit())
	tuner_save_button.pressed.connect(func() -> void: peephole_pose_save_pressed.emit())
	for spin in [
		tuner_pos_x, tuner_pos_y, tuner_pos_z,
		tuner_rot_x, tuner_rot_y, tuner_rot_z,
		tuner_scale,
	]:
		spin.value_changed.connect(_on_tuner_value_changed)
	for icon in [peephole_icon, knock_icon, approach_icon]:
		icon.modulate = ICON_TINT
	var main := get_parent()
	if main:
		_peephole_marker = main.get_node_or_null("world/door_hotspot_peephole") as Marker3D
		_knock_marker = main.get_node_or_null("world/door_hotspot_knock") as Marker3D
		_approach_marker = main.get_node_or_null("world/door_hotspot_approach") as Marker3D
		_gate_camera = main.get_node_or_null("Camera3D") as Camera3D
		_audio_approach = main.get_node_or_null("AudioApproach") as AudioStreamPlayer
		_audio_knock = main.get_node_or_null("AudioKnock") as AudioStreamPlayer
	hide_reveal()
	hide_summary()
	_configure_mouse_passthrough()
	_raise_door_overlay()
	set_peephole_mode(false)
	set_gate_actions_enabled(false)
	set_skip_visible(false)
	set_door_overlay_visible(false)
	set_clue_replay_visible(false, false)
	fade_rect.modulate.a = 0.0
	set_tuner_open(false)
	_reset_approach_playback_fill()
	_reset_knock_playback_fill()


func _configure_mouse_passthrough() -> void:
	var margin := get_node_or_null("Margin") as Control
	if margin:
		margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var layout := get_node_or_null("Margin/Layout") as Control
	if layout:
		layout.mouse_filter = Control.MOUSE_FILTER_IGNORE
		for child_name in ["TopBar", "Spacer", "GateActions", "PeepholeActions"]:
			var child := layout.get_node_or_null(child_name) as Control
			if child:
				child.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for hotspot in [peephole_hotspot, knock_hotspot, approach_hotspot]:
		hotspot.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _raise_door_overlay() -> void:
	move_child(door_overlay, fade_rect.get_index())


func _process(_delta: float) -> void:
	_update_approach_playback_fill()
	_update_knock_playback_fill()
	if not _door_overlay_visible:
		return
	_update_door_hotspot(peephole_hotspot, _peephole_marker)
	_update_door_hotspot(knock_hotspot, _knock_marker)
	_update_door_hotspot(approach_hotspot, _approach_marker)


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_1:
		if peephole_actions.visible:
			set_tuner_open(not _tuner_open)
			get_viewport().set_input_as_handled()


func _update_door_hotspot(hotspot: VBoxContainer, marker: Marker3D) -> void:
	if hotspot == null or not hotspot.visible:
		return
	if marker == null or _gate_camera == null:
		hotspot.visible = false
		return
	var to_marker := marker.global_position - _gate_camera.global_position
	if -_gate_camera.global_transform.basis.z.dot(to_marker) <= 0.0:
		hotspot.visible = false
		return
	var screen_pos := _gate_camera.unproject_position(marker.global_position)
	hotspot.reset_size()
	var size := hotspot.size
	if size == Vector2.ZERO:
		size = hotspot.get_combined_minimum_size()
	hotspot.position = screen_pos - size * 0.5
	hotspot.visible = true


func play_blackout(
	on_black: Callable,
	on_complete: Callable = Callable(),
	duration: float = BLACKOUT_DURATION
) -> void:
	if _fade_tween:
		_fade_tween.kill()
	var fade_duration := duration if duration > 0.0 else BLACKOUT_DURATION
	fade_rect.visible = true
	fade_rect.modulate.a = 0.0
	_fade_tween = create_tween()
	_fade_tween.tween_property(fade_rect, "modulate:a", 1.0, fade_duration)
	_fade_tween.tween_callback(func() -> void:
		if on_black.is_valid():
			on_black.call()
	)
	_fade_tween.tween_property(fade_rect, "modulate:a", 0.0, fade_duration)
	_fade_tween.tween_callback(func() -> void:
		if on_complete.is_valid():
			on_complete.call()
	)


func play_fade_from_black(
	on_start: Callable = Callable(),
	on_complete: Callable = Callable(),
	duration: float = BLACKOUT_DURATION) -> void:
	if _fade_tween:
		_fade_tween.kill()
	var fade_duration := duration if duration > 0.0 else BLACKOUT_DURATION
	fade_rect.visible = true
	fade_rect.modulate.a = 1.0
	if on_start.is_valid():
		on_start.call()
	_fade_tween = create_tween()
	_fade_tween.tween_property(fade_rect, "modulate:a", 0.0, fade_duration)
	_fade_tween.tween_callback(func() -> void:
		if on_complete.is_valid():
			on_complete.call()
	)


func set_shift_progress(current: int, total: int) -> void:
	shift_label.text = "Shift %d / %d" % [current, total]


func set_timer_text(text: String) -> void:
	timer_label.text = text


func set_score(score: int) -> void:
	score_label.text = "Score: %d" % score


func set_strikes(strikes_used: int, strikes_allowed: int) -> void:
	strikes_label.text = "Strikes: %d / %d" % [strikes_used, strikes_allowed]


func set_skip_visible(visible: bool, label: String = "") -> void:
	skip_button.visible = visible
	if not label.is_empty():
		skip_button.text = label


func set_door_overlay_visible(visible: bool) -> void:
	_door_overlay_visible = visible
	door_overlay.visible = visible
	if not visible:
		peephole_hotspot.visible = false
		knock_hotspot.visible = false
		approach_hotspot.visible = false


func set_clue_replay_visible(approach: bool, knock: bool) -> void:
	_clue_approach_visible = approach
	_clue_knock_visible = knock
	approach_hotspot.visible = approach
	knock_hotspot.visible = knock
	_apply_clue_button_states()


func set_clue_replay_playing(approach_playing: bool, knock_playing: bool) -> void:
	_approach_replay_disabled = approach_playing
	_knock_replay_disabled = knock_playing
	_apply_clue_button_states()
	if not approach_playing:
		_reset_approach_playback_fill()
	if not knock_playing:
		_reset_knock_playback_fill()


func _update_approach_playback_fill() -> void:
	if not _approach_replay_disabled:
		return
	if _audio_approach == null or not _audio_approach.playing:
		_reset_approach_playback_fill()
		return
	var stream := _audio_approach.stream
	if stream == null:
		_reset_approach_playback_fill()
		return
	var length := stream.get_length()
	if length <= 0.0:
		_reset_approach_playback_fill()
		return
	var progress := clampf(_audio_approach.get_playback_position() / length, 0.0, 1.0)
	var icon_width := approach_icon.size.x
	approach_playback_fill.visible = true
	approach_playback_fill.offset_left = 0.0
	approach_playback_fill.offset_top = 0.0
	approach_playback_fill.offset_bottom = 0.0
	approach_playback_fill.offset_right = icon_width * progress


func _reset_approach_playback_fill() -> void:
	approach_playback_fill.visible = false
	approach_playback_fill.offset_right = 0.0


func _update_knock_playback_fill() -> void:
	if not _knock_replay_disabled:
		return
	if _audio_knock == null or not _audio_knock.playing:
		_reset_knock_playback_fill()
		return
	var stream := _audio_knock.stream
	if stream == null:
		_reset_knock_playback_fill()
		return
	var length := stream.get_length()
	if length <= 0.0:
		_reset_knock_playback_fill()
		return
	var progress := clampf(_audio_knock.get_playback_position() / length, 0.0, 1.0)
	var icon_width := knock_icon.size.x
	knock_playback_fill.visible = true
	knock_playback_fill.offset_left = 0.0
	knock_playback_fill.offset_top = 0.0
	knock_playback_fill.offset_bottom = 0.0
	knock_playback_fill.offset_right = icon_width * progress


func _reset_knock_playback_fill() -> void:
	knock_playback_fill.visible = false
	knock_playback_fill.offset_right = 0.0


func set_gate_actions_enabled(enabled: bool) -> void:
	_gate_actions_enabled = enabled
	peephole_icon.disabled = not enabled
	accept_button.disabled = not enabled
	reject_button.disabled = not enabled
	_apply_clue_button_states()


func _apply_clue_button_states() -> void:
	approach_icon.disabled = not _clue_approach_visible
	knock_icon.disabled = not _clue_knock_visible


func set_fisheye_enabled(enabled: bool) -> void:
	fisheye_overlay.visible = enabled


func set_peephole_mode(active: bool) -> void:
	gate_actions.visible = not active
	peephole_actions.visible = active
	set_fisheye_enabled(active)
	if active:
		set_door_overlay_visible(false)
		set_tuner_open(false)
	elif _investigation_active:
		set_door_overlay_visible(true)
		set_clue_replay_visible(_clue_approach_visible, _clue_knock_visible)
		peephole_hotspot.visible = true


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
	hide_investigation()


func hide_reveal() -> void:
	reveal_panel.visible = false


func show_summary(text: String, show_replay: bool = false, show_next: bool = false) -> void:
	hide_reveal()
	summary_label.text = text
	replay_button.visible = show_replay
	next_button.visible = show_next
	summary_panel.visible = true
	set_gate_actions_enabled(false)
	set_peephole_mode(false)
	hide_investigation()


func hide_summary() -> void:
	summary_panel.visible = false


func show_investigation(has_approach: bool, has_knock: bool) -> void:
	_investigation_active = true
	set_door_overlay_visible(true)
	set_clue_replay_visible(has_approach, has_knock)
	peephole_hotspot.visible = true


func hide_investigation() -> void:
	_investigation_active = false
	set_door_overlay_visible(false)


func _on_tuner_value_changed(_value: float) -> void:
	if _syncing_tuner:
		return
	peephole_pose_changed.emit(
		Vector3(tuner_pos_x.value, tuner_pos_y.value, tuner_pos_z.value),
		Vector3(tuner_rot_x.value, tuner_rot_y.value, tuner_rot_z.value),
		tuner_scale.value
	)
