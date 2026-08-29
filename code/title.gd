extends CanvasLayer

const FADE_DURATION := 0.75
const FLY_DURATION := 2.5

@onready var chrome: Control = %Chrome
@onready var start_button: Button = %StartButton
@onready var instructions: Control = %Instructions
@onready var okay_button: Button = %OkayButton

var _started: bool = false
var _camera: PlayerCamera
var _shift_director: ShiftDirector
var _hud: HUD
var _title_marker: Marker3D
var _title_path: TitlePath


func _ready() -> void:
	var main := get_parent()
	_camera = main.get_node_or_null("Camera3D") as PlayerCamera
	_shift_director = main.get_node_or_null("ShiftDirector") as ShiftDirector
	_hud = main.get_node_or_null("HUD") as HUD
	_title_marker = main.get_node_or_null("world/title_camera_marker") as Marker3D
	_title_path = main.get_node_or_null("world/spawn") as TitlePath
	start_button.pressed.connect(_on_start_pressed)
	okay_button.pressed.connect(_on_okay_pressed)
	if _hud:
		_hud.hide_session_chrome()
	if _camera and _title_marker:
		_camera.hold_at_marker(_title_marker)
	if _title_path:
		_title_path.begin()


func _on_start_pressed() -> void:
	if _started:
		return
	_started = true
	start_button.disabled = true
	var tween := create_tween()
	tween.tween_property(chrome, "modulate:a", 0.0, FADE_DURATION)
	tween.tween_callback(_show_instructions)


func _show_instructions() -> void:
	chrome.visible = false
	instructions.visible = true
	instructions.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(instructions, "modulate:a", 1.0, FADE_DURATION)


func _on_okay_pressed() -> void:
	okay_button.disabled = true
	var tween := create_tween()
	tween.tween_property(instructions, "modulate:a", 0.0, FADE_DURATION)
	tween.tween_callback(_begin_fly)


func _begin_fly() -> void:
	instructions.visible = false
	if _camera:
		_camera.fly_to_rest(FLY_DURATION, _on_fly_complete)
	else:
		_on_fly_complete()


func _on_fly_complete() -> void:
	if _title_path:
		_title_path.end()
	if _shift_director:
		_shift_director._start_shift()


func dismiss() -> void:
	_started = true
	chrome.visible = false
	chrome.modulate.a = 0.0
	instructions.visible = false
	instructions.modulate.a = 0.0
	if _title_path:
		_title_path.end()
